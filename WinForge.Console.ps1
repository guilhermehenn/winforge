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
    ScheduledMaintenance - o que a tarefa da Manutenção agendada executa: limpa os temporários do usuário, salva o
               relatório e termina, sem perguntas e sem pedir Administrador (uma tarefa em segundo plano não pode
               esperar por um pedido de elevação).

.PARAMETER ReportDirectory
    Pasta de saída do relatório (somente com -Action Report). Padrão: %LOCALAPPDATA%\WinForge\reports.

.PARAMETER PauseAtEnd
    Espera uma tecla antes de fechar. É passado automaticamente quando o script se reabre como Administrador,
    para que a janela nova não suma antes de o resultado ser lido.
#>
[CmdletBinding()]
param (
    [ValidateSet("Menu", "Report", "Shortcut", "ScheduledMaintenance")]
    [string]$Action = "Menu",

    [string]$ReportDirectory,

    [switch]$PauseAtEnd
)

$ErrorActionPreference = "Continue"

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
if ($Action -notin "Shortcut", "ScheduledMaintenance") {
    Restart-WinForgeAsAdministrator -ScriptPath $PSCommandPath -ExtraArguments $relaunchArguments
}

# --- Execução ----------------------------------------------------------------------------------------
$exitCode = 0
[void](Start-WinForgeLogging)

try {
    if ($Action -eq "Report") {
        Write-Host "Gerando relatório..." -ForegroundColor Cyan

        $report = Export-WinForgeReport -Directory $ReportDirectory
        Write-Host "HTML : $($report.Html)" -ForegroundColor Green
        Write-Host "Texto: $($report.Text)" -ForegroundColor Green

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
    elseif ($Action -eq "Shortcut") {
        $shortcut = New-WinForgeAppShortcut -Location Desktop -Embedded -PassThru

        if ($shortcut.Kind -eq "Failed") {
            $exitCode = 1
        }
    }
    else {
        Show-WinForgeMainMenu
    }
}
catch {
    $exitCode = 1
    Write-Host ""
    Write-Host "O WinForge encontrou um erro e precisa fechar: $($_.Exception.Message)" -ForegroundColor Red

    if ($PauseAtEnd -or $Action -eq "Menu") {
        Wait-WinForgeKey -Message "Pressione qualquer tecla para fechar..."
    }
}
finally {
    Stop-WinForgeLogging
}

exit $exitCode
