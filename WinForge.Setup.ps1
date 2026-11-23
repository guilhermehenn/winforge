#requires -Version 5.1
<#
.SYNOPSIS
    Instala, atualiza ou desinstala o WinForge.

.DESCRIPTION
    Aberto pelo WinForge-Setup.cmd, na pasta extraída do zip: instala o WinForge em Arquivos de Programas, com o atalho no
    Menu Iniciar e a entrada em Aplicativos instalados (de onde ele se desinstala). Com o WinForge já instalado, atualiza
    a mesma pasta, guardando os arquivos anteriores para voltar ao que era se algo falhar. Aberto da pasta instalada,
    oferece desinstalar.

.PARAMETER Uninstall
    Desinstala o WinForge (é o que Configurações > Aplicativos roda).

.PARAMETER Update
    Uso interno (Sobre o WinForge > Verificar nova versão): espera o WinForge fechar (-WaitProcessId, números separados
    por vírgula), troca os arquivos da pasta -Target pelos desta pasta e abre o WinForge de novo (-Reopen Gui ou
    Console). Sem janela e sem perguntas; o resultado fica para o WinForge mostrar ao abrir.

.PARAMETER Target
    A pasta do WinForge. Ao instalar, o padrão é a pasta já instalada ou, sem ela, Arquivos de Programas\WinForge.
#>
[CmdletBinding()]
param (
    [switch]$Uninstall,

    [switch]$Update,

    [string]$Target = "",

    [string]$WaitProcessId = "",

    [ValidateSet("", "Gui", "Console")]
    [string]$Reopen = "",

    [switch]$Relaunched,

    [switch]$FromTemp
)

$ErrorActionPreference = "Continue"

# --- Atualização sem os módulos -------------------------------------------------------------------------
function Invoke-WinForgeSetupUpdateFallback {
    <#
    O modo -Update quando os módulos da versão nova não carregam (um arquivo bloqueado pelo antivírus, por exemplo) ou
    quando a troca nem chega a começar (Cause = Error, um erro inesperado): nada foi trocado. Espera o WinForge fechar,
    grava o resultado que ele mostra ao abrir (sem os textos traduzidos, a frase vem daqui, na língua escolhida no
    WinForge ou na do Windows) e abre de novo a cópia de sempre, na mesma versão.
    #>
    param ([ValidateSet("Load", "Error")][string]$Cause = "Load")

    $ids = @("$WaitProcessId" -split ',' | ForEach-Object { $number = 0; if ([int]::TryParse(([string]$_).Trim(), [ref]$number) -and $number -gt 0) { $number } })
    $deadline = (Get-Date).AddSeconds(120)

    while ((Get-Date) -lt $deadline -and @($ids | Where-Object { $null -ne (Get-Process -Id $_ -ErrorAction SilentlyContinue) }).Count -gt 0) {
        Start-Sleep -Milliseconds 500
    }

    $readBuild = {
        param ([string]$Folder)

        try {
            $match = [regex]::Match([System.IO.File]::ReadAllText((Join-Path (Join-Path $Folder "modules") "Core.psm1")), '\$script:WinForgeBuild\s*=\s*"([0-9.]+)"')
            if ($match.Success) { return $match.Groups[1].Value }
        }
        catch {
            Write-Verbose "Versão: $($_.Exception.Message)"
        }

        return ""
    }

    $data = Join-Path $env:LOCALAPPDATA "WinForge"

    try {
        $language = ""

        try {
            $settings = [System.IO.File]::ReadAllText((Join-Path $data "settings.json")) | ConvertFrom-Json
            $language = [string]$settings.Language
        }
        catch {
            $language = ""
        }

        if ($language -notin @("pt", "en", "es")) { $language = [string][System.Globalization.CultureInfo]::CurrentUICulture.TwoLetterISOLanguageName }

        $reason = switch ($language) {
            "pt" { if ($Cause -eq "Error") { "o instalador da versão nova parou com um erro inesperado" } else { "o instalador da versão nova não conseguiu carregar os arquivos dele" } }
            "es" { if ($Cause -eq "Error") { "el instalador de la versión nueva se detuvo por un error inesperado" } else { "el instalador de la versión nueva no pudo cargar sus archivos" } }
            default { if ($Cause -eq "Error") { "the new version's installer stopped with an unexpected error" } else { "the new version's installer could not load its files" } }
        }

        $folder = Join-Path $data "update"
        if (-not (Test-Path -LiteralPath $folder)) { [void](New-Item -ItemType Directory -Path $folder -Force -ErrorAction Stop) }

        $document = [ordered]@{ From = (& $readBuild $Target); To = (& $readBuild $PSScriptRoot); Ok = $false; Error = $reason; RollbackFailed = $false; At = (Get-Date).ToString("o", [System.Globalization.CultureInfo]::InvariantCulture) }
        [System.IO.File]::WriteAllText((Join-Path $folder "result.json"), (ConvertTo-Json -InputObject $document), (New-Object System.Text.UTF8Encoding($true)))
    }
    catch {
        Write-Verbose "Resultado: $($_.Exception.Message)"
    }

    try {
        if ($Reopen -eq "Console" -and (Test-Path -LiteralPath (Join-Path $Target "WinForge-Console.cmd") -PathType Leaf)) {
            Start-Process -FilePath (Join-Path $Target "WinForge-Console.cmd") -WorkingDirectory $Target -ErrorAction Stop
        }
        elseif ($Reopen -eq "Gui" -and (Test-Path -LiteralPath (Join-Path $Target "WinForge.Gui.ps1") -PathType Leaf)) {
            $gui = Join-Path $Target "WinForge.Gui.ps1"
            Start-Process -FilePath (Join-Path $PSHOME "powershell.exe") -ArgumentList "-NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File `"$gui`" -Page app" -WindowStyle Hidden -WorkingDirectory $Target -ErrorAction Stop
        }
    }
    catch {
        Write-Verbose "Abrir o WinForge: $($_.Exception.Message)"
    }
}


# --- Módulos -------------------------------------------------------------------------------------------
$moduleRoot = Join-Path $PSScriptRoot "modules"

try {
    $manifest = Import-PowerShellDataFile -LiteralPath (Join-Path $moduleRoot "Modules.psd1") -ErrorAction Stop

    foreach ($name in @($manifest.Common)) {
        $modulePath = Join-Path $moduleRoot "$name.psm1"

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
    # Na atualização, sem janela: o WinForge de antes abre de novo, com o motivo.
    if ($Update) {
        Invoke-WinForgeSetupUpdateFallback
        exit 1
    }

    # Ainda sem os textos traduzidos: o aviso sai nos três idiomas do WinForge.
    Write-Host ""
    Write-Host "  Faltam arquivos do WinForge nesta pasta. Extraia o WinForge.zip inteiro (Extrair tudo) e abra o"
    Write-Host "  WinForge-Setup.cmd da pasta nova."
    Write-Host ""
    Write-Host "  Some WinForge files are missing from this folder. Extract the whole WinForge.zip (Extract all) and"
    Write-Host "  open WinForge-Setup.cmd from the new folder."
    Write-Host ""
    Write-Host "  Faltan archivos de WinForge en esta carpeta. Extrae todo el WinForge.zip (Extraer todo) y abre"
    Write-Host "  WinForge-Setup.cmd en la carpeta nueva."
    Write-Host ""
    [void](Read-Host "  Enter")

    exit 1
}

Set-WinForgeConsoleEncoding


# --- Atualização (sem janela) ----------------------------------------------------------------------------
if ($Update) {
    [void](Start-WinForgeLogging)

    $ids = @($WaitProcessId -split ',' | ForEach-Object { $number = 0; if ([int]::TryParse(([string]$_).Trim(), [ref]$number)) { $number } })
    $ok = $false

    try {
        $ok = Install-WinForgeUpdatePackage -Source $PSScriptRoot -Target $Target -WaitProcessId $ids -Reopen $Reopen
    }
    catch {
        # A troca trata os próprios erros e sempre abre o WinForge de novo; um erro que chega aqui veio antes dela começar.
        # Sem isto, o WinForge que fechou para a atualização não voltava a abrir.
        Write-Verbose "Atualização: $($_.Exception.Message)"
        Stop-WinForgeLogging
        Invoke-WinForgeSetupUpdateFallback -Cause Error
        exit 1
    }

    Stop-WinForgeLogging
    exit $(if ($ok) { 0 } else { 1 })
}


# --- Administrador -------------------------------------------------------------------------------------
function Wait-WinForgeSetupKey {
    Write-Host ""
    Wait-WinForgeKey -Message (Get-WinForgeText 'Pressione qualquer tecla para fechar...')
}

if (-not (Test-WinForgeAdministrator)) {
    $arguments = "-NoProfile -ExecutionPolicy Bypass -File $(ConvertTo-WinForgeCommandLineArgument -Value $PSCommandPath) -Relaunched"
    if ($Uninstall) { $arguments += " -Uninstall" }
    if ($Target) { $arguments += " -Target $(ConvertTo-WinForgeCommandLineArgument -Value $Target)" }

    $elevated = $false

    if (-not $Relaunched) {
        try {
            Start-Process -FilePath (Get-WinForgePowerShellPath) -ArgumentList $arguments -Verb RunAs -ErrorAction Stop
            $elevated = $true
        }
        catch {
            $elevated = $false
        }
    }

    if ($elevated) { exit 0 }

    Write-Host ""
    Write-WinForgeStatus -Type Error -Message $(if ($Uninstall) { (Get-WinForgeText 'Desinstalar o WinForge pede a permissão de Administrador, e o pedido do Windows foi recusado.') } else { (Get-WinForgeText 'Instalar o WinForge pede a permissão de Administrador, e o pedido do Windows foi recusado.') })
    Wait-WinForgeSetupKey
    exit 1
}

[void](Start-WinForgeLogging)

try { $Host.UI.RawUI.WindowTitle = "WinForge" } catch { Write-Verbose "Título da janela: $($_.Exception.Message)" }


function Wait-WinForgeSetupCopiesClosed {
    # Antes de mexer nos arquivos, a janela e o menu desta pasta precisam estar fechados (o monitor o Setup fecha sozinho).
    param ([Parameter(Mandatory)][string]$Root)

    while ($true) {
        $open = @(Get-WinForgeRunningCopies -Root $Root | Where-Object { $_.Kind -ne "Agent" })
        if ($open.Count -eq 0) { return $true }

        Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'O WinForge está aberto. Feche a janela (ou o menu) do WinForge para continuar.')

        if (-not (Confirm-WinForgeAction -Message (Get-WinForgeText 'Já fechou?') -DefaultKey S)) { return $false }
    }
}


function Invoke-WinForgeSetupUninstall {
    param ([Parameter(Mandatory)][string]$Root)

    Show-WinForgeHeader (Get-WinForgeText 'Desinstalar o WinForge')

    if (-not (Test-WinForgePackageFolder -Root $Root)) {
        Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'Não há um WinForge nesta pasta: {0}' "$Root")
        return 1
    }

    Write-WinForgeKeyValue -Label (Get-WinForgeText 'Pasta') -Value $Root
    Write-WinForgeKeyValue -Label (Get-WinForgeText 'Versão') -Value "$(Get-WinForgePackageBuild -Root $Root)"
    Write-Host ""
    Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Os ajustes do Windows que o WinForge aplicou continuam. Para voltar ao que era antes, use Ajustes do Windows > Desfazer ajustes do WinForge antes de desinstalar.')
    Write-Host ""

    if (-not (Confirm-WinForgeAction -Message (Get-WinForgeText 'Desinstalar o WinForge?') -DefaultKey N)) {
        Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Nada foi desinstalado.')
        return 0
    }

    # A mesma pasta que a desinstalação apaga (Uninstall-WinForge).
    $data = "%LOCALAPPDATA%\WinForge"
    try { $data = Join-Path (Get-WinForgeLocalAppDataPath) "WinForge" } catch { Write-Verbose "Pasta de dados: $($_.Exception.Message)" }

    $removeData = Confirm-WinForgeAction -Message (Get-WinForgeText 'Apagar também os dados do WinForge (históricos, relatórios, logs e backups em {0})?' "$data") -DefaultKey N

    if (-not (Wait-WinForgeSetupCopiesClosed -Root $Root)) {
        Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Nada foi desinstalado.')
        return 0
    }

    Write-WinForgeStatus -Type Running -Message (Get-WinForgeText 'Desinstalando...')
    $outcome = Uninstall-WinForge -Root $Root -RemoveData:$removeData
    Write-Host ""

    foreach ($step in @($outcome.Steps)) { Write-WinForgeStatus -Type Success -Message $step }
    foreach ($problem in @($outcome.Problems)) { Write-WinForgeStatus -Type Warning -Message $problem }

    Write-Host ""

    if ($outcome.Ok) {
        Write-WinForgeStatus -Type Success -Message (Get-WinForgeText 'WinForge desinstalado.')
        return 0
    }

    Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'O WinForge foi desinstalado em parte; o que ficou está acima.')
    return 1
}


function Invoke-WinForgeSetupInstall {
    param ([Parameter(Mandatory)][string]$Source, [Parameter(Mandatory)][string]$Root)

    Show-WinForgeHeader (Get-WinForgeText 'Instalar o WinForge')

    $build = Get-WinForgePackageBuild -Root $Source
    $current = $(if (Test-WinForgePackageFolder -Root $Root) { Get-WinForgePackageBuild -Root $Root } else { "" })

    Write-WinForgeKeyValue -Label (Get-WinForgeText 'Versão') -Value "$build"
    Write-WinForgeKeyValue -Label (Get-WinForgeText 'Pasta') -Value $Root
    if ($current) { Write-WinForgeKeyValue -Label (Get-WinForgeText 'Instalada agora') -Value "$current" }
    Write-Host ""

    $newVersion = ConvertTo-WinForgeVersion -Text $build
    $oldVersion = ConvertTo-WinForgeVersion -Text $current

    if ($null -ne $newVersion -and $null -ne $oldVersion -and $oldVersion -gt $newVersion) {
        Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'A pasta já tem uma versão mais nova ({0}).' "$current")
        $go = Confirm-WinForgeAction -Message (Get-WinForgeText 'Instalar a versão {0} por cima mesmo assim?' "$build") -DefaultKey N
    }
    elseif ($current) {
        $go = Confirm-WinForgeAction -Message (Get-WinForgeText 'Atualizar o WinForge para a versão {0}?' "$build") -DefaultKey S
    }
    else {
        $go = Confirm-WinForgeAction -Message (Get-WinForgeText 'Instalar o WinForge?') -DefaultKey S
    }

    if (-not $go) {
        Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Nada foi instalado.')
        return 0
    }

    if (-not (Wait-WinForgeSetupCopiesClosed -Root $Root)) {
        Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Nada foi instalado.')
        return 0
    }

    Write-WinForgeStatus -Type Running -Message (Get-WinForgeText 'Copiando os arquivos...')

    $agentWasOpen = (@(Get-WinForgeRunningCopies -Root $Root | Where-Object { $_.Kind -eq "Agent" }).Count -gt 0)
    if ($agentWasOpen) { [void](Stop-WinForgeAgent) }

    $outcome = Install-WinForgeFiles -Source $Source -Target $Root -BackupFolder (Join-Path (Get-WinForgeUpdateFolder) "anterior")

    if (-not $outcome.Ok) {
        if ($outcome.RollbackFailed) {
            Write-WinForgeStatus -Type Error -Message (Get-WinForgeText 'Não foi possível instalar ({0}), e alguns arquivos não voltaram sozinhos. A cópia dos arquivos anteriores está em {1}.' "$($outcome.Error)" "$($outcome.BackupFolder)")
        }
        elseif ($current) {
            Write-WinForgeStatus -Type Error -Message (Get-WinForgeText 'Não foi possível instalar ({0}). Nada mudou: o WinForge continua na versão {1}.' "$($outcome.Error)" "$current")
        }
        else {
            Write-WinForgeStatus -Type Error -Message (Get-WinForgeText 'Não foi possível instalar: {0}.' "$($outcome.Error)")
        }

        if ($agentWasOpen) { try { [void](Start-WinForgeAgent -Root $Root) } catch { Write-Verbose "Monitor: $($_.Exception.Message)" } }
        return 1
    }

    try {
        Register-WinForgeInstall -Root $Root -Build $build
    }
    catch {
        Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'O WinForge não entrou em Aplicativos instalados: {0}' "$(([string]$_.Exception.Message).TrimEnd('.'))")
    }

    # O atalho do Menu Iniciar sempre; o da Área de Trabalho na primeira instalação, se a pessoa quiser (numa
    # atualização, o que já existe é regravado, para continuar abrindo esta pasta).
    foreach ($place in @(Get-WinForgeCommonShortcutPaths)) {
        $exists = Test-Path -LiteralPath $place.Path -PathType Leaf

        if ($place.Id -eq "Desktop" -and -not $exists) {
            if ($current) { continue }
            if (-not (Confirm-WinForgeAction -Message (Get-WinForgeText 'Criar também um atalho na Área de Trabalho?') -DefaultKey S)) { continue }
        }

        try {
            Save-WinForgeInstallShortcut -Path $place.Path -Root $Root
        }
        catch {
            Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'Não foi possível criar o atalho {0}: {1}' "$(if ($place.Id -eq 'Desktop') { (Get-WinForgeText 'na Área de Trabalho') } else { (Get-WinForgeText 'no Menu Iniciar') })" "$(([string]$_.Exception.Message).TrimEnd('.'))")
        }
    }

    # Os atalhos desta conta que abriam a pasta extraída passam a abrir a instalada; onde o instalador já pôs o atalho para
    # todos os usuários, o desta conta sai (ficaria repetido no Menu Iniciar ou na Área de Trabalho).
    foreach ($place in @(Get-WinForgeShortcutLocation)) {
        if (Test-WinForgeShortcutOpens -Path $place.Path -Root $Source) {
            try {
                if (Test-WinForgeInstallerShortcut -Id $place.Id -Root $Root) { Remove-Item -LiteralPath $place.Path -Force -ErrorAction Stop }
                else { Save-WinForgeInstallShortcut -Path $place.Path -Root $Root }
            }
            catch {
                Write-Verbose "Atalho: $($_.Exception.Message)"
            }
        }
    }

    # O monitor e a manutenção mensal que abriam outra pasta do WinForge (a extraída do zip) passam a abrir a instalada:
    # as atualizações trocam só ela, e a outra pasta pode ser apagada. Com a conta de outro Administrador, o monitor é o
    # da conta de quem usa o PC (a entrada dele não está aqui) e fica como está.
    if (-not (Test-WinForgeUserContextMismatch)) {
        try {
            if (Move-WinForgeAgentEntry -Root $Root) {
                Write-WinForgeStatus -Type Success -Message (Get-WinForgeText 'O monitor na bandeja passa a abrir da pasta instalada.')
                $agentScript = Get-WinForgeAgentScriptPath -Root $Root

                if (@(Get-WinForgeAgentProcesses | Where-Object { ([string]$_.CommandLine).IndexOf($agentScript, [StringComparison]::OrdinalIgnoreCase) -lt 0 }).Count -gt 0) {
                    [void](Stop-WinForgeAgent)
                    $agentWasOpen = $true
                }
            }
        }
        catch {
            Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'O monitor na bandeja continua abrindo da pasta antiga ({0}); para trocar, use Sobre o WinForge > Monitor na bandeja.' "$(([string]$_.Exception.Message).TrimEnd('.'))")
        }
    }

    try {
        $schedule = Get-WinForgeScheduleStatus
        $console = Join-Path $Root "WinForge.Console.ps1"

        if ($schedule.Installed -and $schedule.Enabled -and -not $schedule.OtherUser -and $schedule.ScriptPath -and
            (Split-Path -Leaf $schedule.ScriptPath) -ieq "WinForge.Console.ps1" -and -not (Test-WinForgeSchedulePathSame -Path $schedule.ScriptPath -Other $console)) {
            $day = $(if ($null -ne $schedule.Day -and [int]$schedule.Day -ge 1 -and [int]$schedule.Day -le 28) { [int]$schedule.Day } else { 1 })
            Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'A manutenção mensal rodava o WinForge de outra pasta; ela passa a rodar o da pasta instalada.')
            [void](Register-WinForgeScheduledMaintenance -Day $day -Root $Root)
        }
    }
    catch {
        Write-Verbose "Manutenção mensal: $($_.Exception.Message)"
    }

    if ($agentWasOpen) { try { [void](Start-WinForgeAgent -Root $Root) } catch { Write-Verbose "Monitor: $($_.Exception.Message)" } }

    Write-Host ""
    Write-WinForgeStatus -Type Success -Message $(if ($current) { (Get-WinForgeText 'WinForge atualizado para a versão {0}.' "$build") } else { (Get-WinForgeText 'WinForge instalado em {0}.' "$Root") })
    Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Ele está no Menu Iniciar e em Configurações > Aplicativos, de onde também se desinstala.')

    if (-not (Test-WinForgePathInside -Path $Source -Folder $Root)) {
        Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'A pasta extraída do zip já pode ser apagada: {0}' "$Source")
    }

    Write-Host ""

    if (Confirm-WinForgeAction -Message (Get-WinForgeText 'Abrir o WinForge agora?') -DefaultKey S) {
        # Pelo Explorador, o WinForge abre na sessão da pessoa (e pede o Administrador ele mesmo), e não herda a elevação
        # deste instalador, que pode ser de outra conta.
        try { Start-Process -FilePath "explorer.exe" -ArgumentList "`"$(Join-Path $Root 'WinForge.cmd')`"" -ErrorAction Stop } catch { Open-WinForgeCopy -Root $Root -Kind Gui }
        return -1
    }

    return 0
}


# --- Execução ------------------------------------------------------------------------------------------
$exitCode = 0
$source = Get-WinForgeFullPath -Path $PSScriptRoot

try {
    $registration = Get-WinForgeInstallRegistration

    if ($Uninstall) {
        $root = $(if ($Target) { Get-WinForgeFullPath -Path $Target } elseif ($null -ne $registration) { $registration.Location } else { $source })

        # O Setup da pasta instalada não apaga a própria pasta enquanto roda dela: uma cópia na pasta temporária continua.
        if (-not $FromTemp -and (Test-WinForgePathInside -Path $source -Folder $root)) {
            $temp = Join-Path ([System.IO.Path]::GetTempPath()) ("WinForge-uninstall-{0}" -f [guid]::NewGuid().ToString("N"))

            foreach ($relative in @(Get-WinForgePackageFiles -Root $source)) { Copy-WinForgeFile -From (Join-Path $source $relative) -To (Join-Path $temp $relative) }

            $arguments = "-NoProfile -ExecutionPolicy Bypass -File $(ConvertTo-WinForgeCommandLineArgument -Value (Join-Path $temp 'WinForge.Setup.ps1')) -Uninstall -Target $(ConvertTo-WinForgeCommandLineArgument -Value $root) -FromTemp -Relaunched"
            Start-Process -FilePath (Get-WinForgePowerShellPath) -ArgumentList $arguments -WorkingDirectory $temp -ErrorAction Stop
            Stop-WinForgeLogging
            exit 0
        }

        $exitCode = Invoke-WinForgeSetupUninstall -Root $root
    }
    else {
        $root = $(if ($Target) { Get-WinForgeFullPath -Path $Target } elseif ($null -ne $registration -and (Test-WinForgePackageFolder -Root $registration.Location)) { $registration.Location } else { Join-Path $env:ProgramFiles "WinForge" })

        if (Test-WinForgeSamePath -Path $source -Other $root) {
            # Aberto da pasta instalada: não há o que copiar; a única coisa a fazer daqui é desinstalar.
            Show-WinForgeHeader "WinForge"
            Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'O WinForge já está instalado nesta pasta. Para atualizar, use Sobre o WinForge > Verificar nova versão.')
            Write-Host ""

            if (Confirm-WinForgeAction -Message (Get-WinForgeText 'Desinstalar o WinForge?') -DefaultKey N) {
                $arguments = "-NoProfile -ExecutionPolicy Bypass -File $(ConvertTo-WinForgeCommandLineArgument -Value $PSCommandPath) -Uninstall -Relaunched"
                Start-Process -FilePath (Get-WinForgePowerShellPath) -ArgumentList $arguments -ErrorAction Stop
                Stop-WinForgeLogging
                exit 0
            }
        }
        else {
            $exitCode = Invoke-WinForgeSetupInstall -Source $source -Root $root
        }
    }
}
catch {
    $exitCode = 1
    Write-Host ""
    Write-WinForgeStatus -Type Error -Message (Get-WinForgeText 'O instalador encontrou um erro: {0}' "$(ConvertTo-WinForgeReadableError -Text $_.Exception.Message)")
}

Stop-WinForgeLogging

# A cópia da pasta temporária que desinstalou sai depois que este processo fechar.
if ($FromTemp -and $source -like "$([System.IO.Path]::GetTempPath().TrimEnd('\'))*") {
    try {
        Start-Process -FilePath "cmd.exe" -ArgumentList "/c timeout /t 3 /nobreak >nul & rmdir /s /q `"$source`"" -WindowStyle Hidden -ErrorAction Stop
    }
    catch {
        Write-Verbose "Pasta temporária: $($_.Exception.Message)"
    }
}

# -1: o WinForge foi aberto; a janela do instalador fecha sem esperar.
if ($exitCode -ne -1) { Wait-WinForgeSetupKey }

exit $(if ($exitCode -eq -1) { 0 } else { $exitCode })
