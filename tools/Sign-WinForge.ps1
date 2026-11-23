#requires -Version 5.1
<#
.SYNOPSIS
    Assina digitalmente (Authenticode) todos os scripts do WinForge.

.DESCRIPTION
    Use com um certificado de assinatura de código emitido por uma autoridade confiável
    (ou com Azure Trusted Signing). Scripts assinados reduzem avisos do SmartScreen/Defender
    e permitem usar ExecutionPolicy AllSigned. Certificado autoassinado só funciona nos PCs
    onde ele for instalado como confiável.

    Depois de assinar, monte o zip com o tools\New-WinForgePackage.ps1: é ele que grava o SHA256SUMS.txt, a partir dos
    arquivos como eles ficam no zip (com o CHANGELOG curto). Um SHA256SUMS.txt feito da pasta listaria também as
    ferramentas e os documentos, que não vão para o PC, e o CHANGELOG inteiro.

.EXAMPLE
    $cert = Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert | Select-Object -First 1
    .\tools\Sign-WinForge.ps1 -Certificate $cert
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate,

    [string]$TimestampServer = "http://timestamp.digicert.com"
)

$root = Split-Path -Parent $PSScriptRoot
$files = Get-ChildItem -LiteralPath $root -Recurse -File -Include *.ps1, *.psm1, *.psd1 |
    Where-Object { $_.FullName -notmatch "[\\/]\.git[\\/]" }

foreach ($file in $files) {
    $result = Set-AuthenticodeSignature -FilePath $file.FullName -Certificate $Certificate -TimestampServer $TimestampServer -HashAlgorithm SHA256

    if ($result.Status -eq "Valid") {
        Write-Host "[OK] $($file.Name)" -ForegroundColor Green
    }
    else {
        Write-Host "[FALHA] $($file.Name): $($result.StatusMessage)" -ForegroundColor Red
    }
}

Write-Host "Agora monte o zip: .\tools\New-WinForgePackage.ps1 (ele grava o SHA256SUMS.txt)." -ForegroundColor Cyan
