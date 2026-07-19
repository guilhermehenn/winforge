#requires -Version 5.1

$ErrorActionPreference = "Continue"

try {
    $utf8Encoding = New-Object System.Text.UTF8Encoding -ArgumentList $false
    [Console]::InputEncoding = $utf8Encoding
    [Console]::OutputEncoding = $utf8Encoding
    $global:OutputEncoding = $utf8Encoding
    chcp.com 65001 | Out-Null
}
catch {
    # A configuração de codificação é opcional; a inicialização deve continuar em terminais restritos.
}

$moduleRoot = Join-Path $PSScriptRoot "modules"
$requiredModules = @(
    "Core.psm1",
    "Software.psm1",
    "Cleanup.psm1",
    "Diagnostics.psm1",
    "Network.psm1",
    "System.psm1",
    "Personalization.psm1",
    "Maintenance.psm1",
    "Menus.psm1"
)

foreach ($moduleName in $requiredModules) {
    $modulePath = Join-Path $moduleRoot $moduleName

    if (-not (Test-Path $modulePath)) {
        Write-Host "Módulo obrigatório não encontrado: $modulePath" -ForegroundColor Red
        Pause
        exit 1
    }

    Import-Module $modulePath -Force -DisableNameChecking
}

Restart-AsAdministratorIfNeeded -ScriptPath $PSCommandPath

Initialize-WinForgeEnvironment
Initialize-Winget | Out-Null

Show-MainMenu
