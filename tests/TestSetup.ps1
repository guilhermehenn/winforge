# Preparação comum dos testes (dot-source dentro do BeforeAll de cada arquivo *.Tests.ps1).
# Os testes não alteram o sistema: os dados do WinForge vão para uma pasta temporária e os pontos de contato com o
# Windows são substituídos por funções de teste.

$script:RepoRoot = Split-Path -Parent $PSScriptRoot
$script:ModuleRoot = Join-Path $script:RepoRoot "modules"
$script:StrictRoot = $null

if ($env:WINFORGE_TEST_STRICT -eq "1") {
    # Modo estrito: os módulos rodam com Set-StrictMode -Version Latest (copiados para uma pasta temporária com essa
    # linha no topo). Variáveis não definidas e propriedades inexistentes viram erro, e a suíte inteira precisa passar.
    # A cópia é uma só por execução (Run-Tests.ps1 a apaga no fim); caminhos diferentes carregariam módulos duplicados.
    if ([string]::IsNullOrEmpty($env:WINFORGE_TEST_STRICT_ROOT) -or -not (Test-Path -LiteralPath $env:WINFORGE_TEST_STRICT_ROOT)) {
        $env:WINFORGE_TEST_STRICT_ROOT = Join-Path ([IO.Path]::GetTempPath()) ("winforge-strict-" + [guid]::NewGuid().ToString("N"))
        New-Item -ItemType Directory -Path $env:WINFORGE_TEST_STRICT_ROOT -Force | Out-Null

        foreach ($file in (Get-ChildItem -LiteralPath $script:ModuleRoot -File)) {
            $target = Join-Path $env:WINFORGE_TEST_STRICT_ROOT $file.Name

            if ($file.Extension -eq ".psm1") {
                $content = "Set-StrictMode -Version Latest`r`n" + [IO.File]::ReadAllText($file.FullName)
                [IO.File]::WriteAllText($target, $content, (New-Object System.Text.UTF8Encoding($true)))
            }
            else {
                Copy-Item -LiteralPath $file.FullName -Destination $target
            }
        }
    }

    $script:StrictRoot = $env:WINFORGE_TEST_STRICT_ROOT
    $script:ModuleRoot = $script:StrictRoot
}

$script:Manifest = Import-PowerShellDataFile -LiteralPath (Join-Path $script:ModuleRoot "Modules.psd1")

# Dados isolados (backup de ajustes, histórico, relatórios).
$script:OriginalLocalAppData = $env:LOCALAPPDATA
$script:TestDataRoot = Join-Path ([IO.Path]::GetTempPath()) ("winforge-tests-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $script:TestDataRoot -Force | Out-Null
$env:LOCALAPPDATA = $script:TestDataRoot

$script:StubbedFunctions = @()

function script:Import-AllWinForgeModules {
    foreach ($name in (@($script:Manifest.Common) + @($script:Manifest.Console) + @($script:Manifest.Gui))) {
        Import-Module (Join-Path $script:ModuleRoot "$name.psm1") -Force -DisableNameChecking -Global
    }
}

function script:Set-TestStub {
    # Substitui uma função de OUTRO módulo (as chamadas entre módulos passam pelo escopo global).
    param ([string]$Name, [scriptblock]$Body)

    Set-Item -Path "Function:\global:$Name" -Value $Body
    $script:StubbedFunctions += $Name
}

function script:Clear-TestStubs {
    foreach ($name in $script:StubbedFunctions) {
        Remove-Item -Path "Function:\$name" -ErrorAction SilentlyContinue
    }

    if ($script:StubbedFunctions.Count -gt 0) {
        Import-AllWinForgeModules
    }

    $script:StubbedFunctions = @()
}

function script:Set-FakeReadHost {
    # Substitui o Read-Host por respostas prontas (o console real não é usado nos testes).
    # Quando as respostas acabam, devolve $null, como uma entrada redirecionada que terminou.
    param ([string[]]$Answers)

    $global:WfFakeAnswers = New-Object System.Collections.Queue
    foreach ($answer in $Answers) { $global:WfFakeAnswers.Enqueue($answer) }

    function global:Read-Host {
        param ([string]$Prompt)

        if ($global:WfFakeAnswers.Count -eq 0) { return $null }

        return $global:WfFakeAnswers.Dequeue()
    }
}

function script:Clear-FakeReadHost {
    Remove-Item Function:\global:Read-Host -ErrorAction SilentlyContinue
    Remove-Variable WfFakeAnswers -Scope Global -ErrorAction SilentlyContinue
}

function script:Get-HostText {
    # Roda um bloco e devolve tudo o que ele escreveu na tela (Write-Host) como texto.
    param ([scriptblock]$Script)

    return ((& $Script *>&1 | Out-String))
}

$script:HostExe = (Get-Process -Id $PID).Path

function script:Reset-LastMaintenanceMemory {
    & (Get-Module Core) { $script:WinForgeLastMaintenance = $null }
}

function script:Split-WindowsCommandLine {
    # Referência das regras do CommandLineToArgvW: barras só são especiais antes de aspas.
    param ([string]$Line)

    $arguments = New-Object System.Collections.Generic.List[string]
    $current = New-Object System.Text.StringBuilder
    $inQuotes = $false
    $started = $false
    $i = 0

    while ($i -lt $Line.Length) {
        $c = $Line[$i]

        if ($c -eq [char]92) {
            $count = 0
            while ($i -lt $Line.Length -and $Line[$i] -eq [char]92) { $count++; $i++ }

            if ($i -lt $Line.Length -and $Line[$i] -eq [char]34) {
                [void]$current.Append([string]::new([char]92, [int][Math]::Floor($count / 2)))

                if ($count % 2 -eq 1) {
                    [void]$current.Append([char]34)
                }
                else {
                    $inQuotes = -not $inQuotes
                }

                $started = $true
                $i++
            }
            else {
                [void]$current.Append([string]::new([char]92, $count))
                $started = $true
            }

            continue
        }

        if ($c -eq [char]34) {
            $inQuotes = -not $inQuotes
            $started = $true
        }
        elseif ([char]::IsWhiteSpace($c) -and -not $inQuotes) {
            if ($started) {
                $arguments.Add($current.ToString())
                [void]$current.Clear()
                $started = $false
            }
        }
        else {
            [void]$current.Append($c)
            $started = $true
        }

        $i++
    }

    if ($started) { $arguments.Add($current.ToString()) }

    return $arguments.ToArray()
}

Import-AllWinForgeModules
Initialize-WinForgeGuiHost

# Os cabeçalhos limpam a tela; nos testes isso só joga sequências de controle na saída do executor.
function global:Clear-Host { }

# --- Host gráfico: módulo de teste que roda dentro do runspace das ações ------------------------------------
$script:GuiTestRoot = Join-Path ([IO.Path]::GetTempPath()) ("winforge-gui-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $script:GuiTestRoot | Out-Null
Copy-Item (Join-Path $script:ModuleRoot "Core.psm1") $script:GuiTestRoot
Copy-Item (Join-Path $script:ModuleRoot "Console.psm1") $script:GuiTestRoot

Set-Content -Path (Join-Path $script:GuiTestRoot "Probe.psm1") -Encoding UTF8 -Value @'
function Test-GuiAsk {
    $ok = Confirm-WinForgeAction "Deseja continuar?"
    $name = Read-Host "Digite seu nome"
    Write-Host "Resposta: $ok / Olá, $name" -ForegroundColor Green
    Wait-WinForgeKey
    Write-Host "fim"
}
function Test-GuiSlow {
    Write-Host "dormindo"
    Start-Sleep -Seconds 30
}
function Test-GuiWait {
    $null = Read-Host "Pergunta sem resposta"
}
function Test-GuiThrow { throw "explodiu" }
function Test-GuiChoice {
    $key = Read-WinForgeChoice -Message "Escolha uma opção" -DefaultKey "1" -Options @(
        @{ Key = "1"; Label = "Itens antigos"; Description = "recomendado"; Accent = $true },
        @{ Key = "2"; Label = "Tudo" },
        @{ Key = "0"; Label = "Cancelar"; Exit = $true }
    )
    Write-Host "escolha=$key"
}
function Test-GuiMulti {
    $keys = Read-WinForgeMultiSelect -Message "Marque os itens" -Options @(
        @{ Key = "a"; Label = "Alfa" },
        @{ Key = "b"; Label = "Beta"; Description = "segundo"; Selected = $true },
        @{ Key = "c"; Label = "Gama" }
    )
    if ($null -eq $keys) { Write-Host "cancelado" } else { Write-Host ("marcados=" + (@($keys) -join ",")) }
}
function Test-GuiConfirm {
    $ok = Confirm-WinForgeAction "Quer mesmo?"
    Write-Host "confirmou=$ok"
}
function Test-GuiMode {
    Write-Host ("modo=" + (Test-WinForgeGuiMode))
}
function Test-GuiNative {
    $exe = (Get-Process -Id $PID).Path
    $code = Invoke-WinForgeNative -FilePath $exe -Arguments @("-NoProfile", "-NonInteractive", "-Command", "Write-Output linha-nativa; exit 4") -IgnoreExitCode -PassThru
    Write-Host "codigo=$code"
}
function Test-GuiWarning {
    Write-Warning "cuidado com isto"
    Write-Host "depois do aviso"
}
function Test-GuiHostChoice {
    $choices = [System.Management.Automation.Host.ChoiceDescription[]]@(
        (New-Object System.Management.Automation.Host.ChoiceDescription "&Sim", "confirma"),
        (New-Object System.Management.Automation.Host.ChoiceDescription "&Não", "recusa")
    )
    $index = $Host.UI.PromptForChoice("Título", "Posso continuar?", $choices, 1)
    Write-Host "indice=$index"
}
function Test-GuiOrder {
    Write-Host "primeiro"
    $exe = (Get-Process -Id $PID).Path
    Invoke-WinForgeNative -FilePath $exe -Arguments @("-NoProfile", "-NonInteractive", "-Command", "Write-Output segundo") -IgnoreExitCode
    Write-Host "terceiro"
}
function Test-GuiTable {
    [PSCustomObject]@{ Nome = "alfa"; Valor = 1 }, [PSCustomObject]@{ Nome = "beta"; Valor = 22 } | Format-Table -AutoSize | Out-Host
    Write-Host "depois da tabela"
}
function Test-GuiTwice {
    Write-Host "execucao=$([int]$global:WinForgeProbeCount + 1)"
    $global:WinForgeProbeCount = [int]$global:WinForgeProbeCount + 1
}
Export-ModuleMember -Function *
'@

function script:Invoke-GuiProbe {
    param ([string]$Command, [hashtable]$Answers = @{}, [string]$StopWhenOutputMatches = "", [switch]$StopOnPrompt)

    $session = New-WinForgeGuiSession -ModuleRoot $script:GuiTestRoot -Modules @("Core", "Console", "Probe")
    $text = New-Object System.Text.StringBuilder
    $prompts = New-Object System.Collections.ArrayList

    try {
        [void](Start-WinForgeGuiCommand -Session $session -Command $Command -Columns 90)
        $deadline = (Get-Date).AddSeconds(60)
        $status = "Running"
        $stopped = $false

        while ($status -eq "Running" -and (Get-Date) -lt $deadline) {
            $update = Read-WinForgeGuiUpdate -Session $session

            foreach ($item in $update.Items) {
                [void]$text.Append($item.Text)
                if ($item.NewLine) { [void]$text.Append("`n") }
            }

            if ($null -ne $update.Prompt -and -not $update.Prompt.Done.WaitOne(0)) {
                [void]$prompts.Add($update.Prompt.Label)
                $script:LastGuiPrompt = $update.Prompt

                if ($StopOnPrompt) {
                    Stop-WinForgeGuiCommand -Session $session
                }
                elseif ($update.Prompt.Kind -eq "multi") {
                    $answer = $Answers[$update.Prompt.Label]

                    if ($answer -eq "CANCEL") {
                        Complete-WinForgeGuiPrompt -Session $session -Prompt $update.Prompt
                    }
                    else {
                        Complete-WinForgeGuiPrompt -Session $session -Prompt $update.Prompt -Keys @($answer) -Accepted
                    }
                }
                else {
                    $answer = $Answers[$update.Prompt.Label]
                    if ($null -eq $answer) { $answer = "" }
                    Complete-WinForgeGuiPrompt -Session $session -Prompt $update.Prompt -Answer $answer
                }
            }

            if ($StopWhenOutputMatches -and -not $stopped -and $text.ToString() -match $StopWhenOutputMatches) {
                $stopped = $true
                Stop-WinForgeGuiCommand -Session $session
            }

            $status = $update.Status
            Start-Sleep -Milliseconds 50
        }

        return [PSCustomObject]@{ Status = $status; Text = $text.ToString(); Prompts = @($prompts) }
    }
    finally {
        Close-WinForgeGuiSession -Session $session
    }
}

function script:Remove-WinForgeTestData {
    Clear-TestStubs
    Clear-FakeReadHost
    Remove-Item Function:\global:Clear-Host -ErrorAction SilentlyContinue

    $env:LOCALAPPDATA = $script:OriginalLocalAppData

    foreach ($path in @($script:GuiTestRoot, $script:TestDataRoot)) {
        if ($path -and (Test-Path -LiteralPath $path)) {
            Remove-Item -LiteralPath $path -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
