#requires -Version 5.1
<#
.SYNOPSIS
    WinForge no terminal: menus de texto para manutenção, diagnóstico e ajustes do Windows.

.DESCRIPTION
    A versão com janela é WinForge.Gui.ps1 (abra pelo WinForge.cmd). As duas usam os mesmos módulos e a mesma
    tabela de navegação (modules\Navigation.psm1), então oferecem as mesmas ações na mesma ordem.

.PARAMETER Action
    Menu     - abre o menu interativo (padrão).
    Report   - gera o relatório HTML/TXT e termina.
    Shortcut - cria o atalho do WinForge (com o ícone) na Área de Trabalho e termina. Não pede Administrador.
    ScheduledMaintenance - o que a tarefa da Manutenção agendada executa: limpa os temporários do usuário com mais de
               7 dias, salva o relatório e termina, sem perguntas e sem pedir Administrador (uma tarefa em segundo plano não pode
               esperar por um pedido de elevação).
    Check    - verificação rápida e só de leitura: nota de saúde e nota de segurança (sem a consulta ao Windows Update).
               Não pede Administrador, não grava log e não pergunta nada, então serve para tarefas e scripts. O código
               de saída diz o resultado: 0 tudo em dia, 1 pontos de atenção, 2 algo crítico, 3 não foi possível avaliar.

.PARAMETER Json
    Somente com -Action Check: escreve o resultado como JSON (UTF-8) em vez do texto, e nada mais na saída.

.PARAMETER ReportDirectory
    Pasta de saída do relatório (somente com -Action Report). Padrão: %LOCALAPPDATA%\WinForge\reports.

.PARAMETER PauseAtEnd
    Espera uma tecla antes de fechar. É passado automaticamente quando o script se reabre como Administrador,
    para que a janela nova não suma antes de o resultado ser lido.
#>
[CmdletBinding()]
param (
    [string]$Action = "Menu",

    [string]$ReportDirectory,

    [switch]$Json,

    [switch]$PauseAtEnd
)

$ErrorActionPreference = "Continue"

# A ação é conferida aqui, e não com ValidateSet: um nome errado ("-Action Relatorio") recebe a lista em português, e
# não o erro em inglês do PowerShell. Maiúsculas e minúsculas não importam.
$knownActions = @("Menu", "Report", "Shortcut", "ScheduledMaintenance", "Check")
$matchedAction = @($knownActions | Where-Object { $_ -ieq $Action })

if ($matchedAction.Count -eq 0) {
    Write-Host "Ação desconhecida: '$Action'. Use -Action Menu, Report, Shortcut, ScheduledMaintenance ou Check." -ForegroundColor Red
    exit 1
}

$Action = $matchedAction[0]

if ($Json -and $Action -ne "Check") {
    Write-Host "O -Json só vale com -Action Check (a verificação rápida)." -ForegroundColor Red
    exit 1
}

# --- Módulos (lista em modules\Modules.psd1) ---------------------------------------------------------
$moduleRoot = Join-Path $PSScriptRoot "modules"
$manifestPath = Join-Path $moduleRoot "Modules.psd1"

if (-not (Test-Path -LiteralPath $manifestPath)) {
    Write-Host "Arquivo de módulos não encontrado: $manifestPath" -ForegroundColor Red
    Write-Host "Extraia o WinForge por completo antes de executar." -ForegroundColor Yellow
    exit 1
}

try {
    $manifest = Import-PowerShellDataFile -LiteralPath $manifestPath -ErrorAction Stop

    foreach ($name in (@($manifest.Common) + @($manifest.Console))) {
        $modulePath = Join-Path $moduleRoot "$name.psm1"

        if (-not (Test-Path -LiteralPath $modulePath)) {
            throw "Módulo obrigatório não encontrado: $modulePath"
        }

        try {
            Import-Module -Name $modulePath -Force -DisableNameChecking -Global -ErrorAction Stop
        }
        catch {
            # Caminhos com colchetes são lidos como curinga pelo Import-Module; escapar resolve.
            Import-Module -Name ([System.Management.Automation.WildcardPattern]::Escape($modulePath)) -Force -DisableNameChecking -Global -ErrorAction Stop
        }
    }
}
catch {
    Write-Host "Não foi possível carregar o WinForge: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Initialize-WinForgeEnvironment

# --- Administrador -----------------------------------------------------------------------------------
# Uma pasta de relatório relativa ("-ReportDirectory .\saida") vale a partir de onde o comando foi digitado: o .cmd
# entra na pasta do WinForge e a reabertura como Administrador começa em System32, então o caminho vira absoluto aqui.
if (-not [string]::IsNullOrWhiteSpace($ReportDirectory) -and -not [System.IO.Path]::IsPathRooted($ReportDirectory)) {
    $callerFolder = $(if ($env:WINFORGE_CALLER_DIR) { $env:WINFORGE_CALLER_DIR } else { (Get-Location).ProviderPath })
    $ReportDirectory = [System.IO.Path]::GetFullPath((Join-Path $callerFolder $ReportDirectory))
}

$relaunchArguments = @()

if ($Action -ne "Menu") {
    $relaunchArguments += "-Action $Action"
}

if (-not [string]::IsNullOrWhiteSpace($ReportDirectory)) {
    $relaunchArguments += "-ReportDirectory $(ConvertTo-WinForgeCommandLineArgument -Value $ReportDirectory)"
}

if ($Action -eq "Report") {
    $relaunchArguments += "-PauseAtEnd"
}

# O atalho é criado pela pessoa que executa (a Área de Trabalho dela); elevar poderia usar o perfil de outro usuário.
# A manutenção agendada roda em segundo plano com o usuário logado e sem elevação, então não há quem aprove o pedido.
# A verificação rápida só lê e é feita para scripts: reabrir como Administrador abriria outra janela e perderia a saída.
if ($Action -notin "Shortcut", "ScheduledMaintenance", "Check") {
    Restart-WinForgeAsAdministrator -ScriptPath $PSCommandPath -ExtraArguments $relaunchArguments
}

# --- Execução ----------------------------------------------------------------------------------------
$exitCode = 0

# A verificação rápida não grava log: a saída precisa ficar limpa e uma tarefa que roda sempre não deve encher a pasta.
if ($Action -ne "Check") {
    [void](Start-WinForgeLogging)
}

try {
    if ($Action -eq "Report") {
        Write-Host "Gerando relatório..." -ForegroundColor Cyan

        $report = Export-WinForgeReport -Directory $ReportDirectory
        Write-Host "HTML : $($report.Html)" -ForegroundColor Green

        # O HTML vale sozinho; a cópia em texto que não pôde ser gravada é avisada, sem esconder o HTML salvo.
        if ($report.Text) { Write-Host "Texto: $($report.Text)" -ForegroundColor Green }
        else { Write-Host "Texto: não foi gravado ($($report.TextProblem))" -ForegroundColor Yellow }

        if ($PauseAtEnd) {
            Write-Host ""
            Wait-WinForgeKey -Message "Pressione qualquer tecla para fechar..."
        }
    }
    elseif ($Action -eq "ScheduledMaintenance") {
        $scheduled = @(Invoke-WinForgeScheduledMaintenance) | Select-Object -Last 1

        if ($scheduled.Kind -eq "Failed") {
            $exitCode = 1
        }
    }
    elseif ($Action -eq "Check") {
        $check = Get-WinForgeCheckReport

        if ($Json) {
            Write-Output (ConvertTo-WinForgeCheckJson -Report $check)
        }
        else {
            Show-WinForgeCheckReport -Report $check
        }

        $exitCode = [int]$check.ExitCode
    }
    elseif ($Action -eq "Shortcut") {
        $shortcut = New-WinForgeAppShortcut -Location Desktop -Embedded -PassThru

        if ($shortcut.Kind -eq "Failed") {
            $exitCode = 1
        }
    }
    else {
        # Sem isto, a janela do terminal se chamaria "Administrador: C:\Windows\System32\...\powershell.exe".
        try { $Host.UI.RawUI.WindowTitle = "WinForge" } catch { Write-Verbose "Título da janela: $($_.Exception.Message)" }

        Show-WinForgeMainMenu
    }
}
catch {
    $exitCode = 1
    Write-Host ""
    $failure = $_.Exception.Message
    try { $failure = ConvertTo-WinForgeReadableError -Text $failure } catch { }
    Write-Host "O WinForge encontrou um erro e precisa fechar: $failure" -ForegroundColor Red

    # Aberto pelo WinForge-Console.cmd (WINFORGE_FROM_CMD), quem pausa é o .cmd, uma vez só.
    if (($PauseAtEnd -or $Action -eq "Menu") -and $env:WINFORGE_FROM_CMD -ne "1") {
        Wait-WinForgeKey -Message "Pressione qualquer tecla para fechar..."
    }
}
finally {
    Stop-WinForgeLogging
}

exit $exitCode
