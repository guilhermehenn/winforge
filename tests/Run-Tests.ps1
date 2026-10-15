#requires -Version 5.1
<#
.SYNOPSIS
    Roda todos os testes do WinForge (arquivos *.Tests.ps1 desta pasta) com o Pester 5.

.DESCRIPTION
    Os testes não alteram o sistema: os dados vão para uma pasta temporária e os pontos de contato com o Windows
    são substituídos por funções de teste. Termina com código 1 se algum teste falhar.

.PARAMETER Name
    Roda só os arquivos cujo nome contém algum destes textos. Exemplo: -Name Core, Cleanup

.PARAMETER Output
    Nível de detalhe da saída do Pester (None, Normal, Detailed ou Diagnostic).

.PARAMETER Strict
    Roda os módulos com Set-StrictMode -Version Latest: variáveis não definidas e propriedades inexistentes viram
    erro. Serve para achar defeitos que o modo normal do PowerShell esconde.

.EXAMPLE
    .\tests\Run-Tests.ps1
    .\tests\Run-Tests.ps1 -Name Project -Output Detailed
    .\tests\Run-Tests.ps1 -Strict
#>
[CmdletBinding()]
param (
    [string[]]$Name = @(),

    [ValidateSet("None", "Normal", "Detailed", "Diagnostic")]
    [string]$Output = "Normal",

    [switch]$Strict
)

$pester = Get-Module -ListAvailable Pester |
    Where-Object { $_.Version -ge [version]"5.0.0" } |
    Sort-Object Version -Descending |
    Select-Object -First 1

if (-not $pester) {
    Write-Host "Pester 5 não encontrado. Instale com:" -ForegroundColor Yellow
    Write-Host "  Install-Module Pester -MinimumVersion 5.0 -Scope CurrentUser -Force -SkipPublisherCheck"
    exit 1
}

Import-Module $pester -Force

$files = @(Get-ChildItem -LiteralPath $PSScriptRoot -Filter "*.Tests.ps1" -File | Sort-Object Name)

if ($Name.Count -gt 0) {
    # Aceita -Name Core, Cleanup e também -Name "Core,Cleanup" (como chega quando o script é chamado com -File).
    $filters = @($Name | ForEach-Object { $_ -split "," } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    $files = @($files | Where-Object { $file = $_; @($filters | Where-Object { $file.Name -like "*$_*" }).Count -gt 0 })
}

if ($files.Count -eq 0) {
    Write-Host "Nenhum arquivo de testes encontrado." -ForegroundColor Yellow
    exit 1
}

$configuration = New-PesterConfiguration
$configuration.Run.Path = @($files | ForEach-Object { $_.FullName })
$configuration.Run.PassThru = $true
$configuration.Output.Verbosity = $Output

$previousStrict = $env:WINFORGE_TEST_STRICT

try {
    if ($Strict) { $env:WINFORGE_TEST_STRICT = "1" } else { $env:WINFORGE_TEST_STRICT = "" }

    $result = Invoke-Pester -Configuration $configuration
}
finally {
    $env:WINFORGE_TEST_STRICT = $previousStrict

    if (-not [string]::IsNullOrEmpty($env:WINFORGE_TEST_STRICT_ROOT)) {
        Remove-Item -LiteralPath $env:WINFORGE_TEST_STRICT_ROOT -Recurse -Force -ErrorAction SilentlyContinue
        $env:WINFORGE_TEST_STRICT_ROOT = ""
    }
}

if ($null -eq $result -or $result.FailedCount -gt 0 -or $result.FailedBlocksCount -gt 0 -or $result.FailedContainersCount -gt 0) {
    exit 1
}
