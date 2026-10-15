#requires -Version 5.1
<#
.SYNOPSIS
    Assina digitalmente (Authenticode) todos os scripts do WinForge e gera SHA256SUMS.txt.

.DESCRIPTION
    Use com um certificado de assinatura de código emitido por uma autoridade confiável
    (ou com Azure Trusted Signing). Scripts assinados reduzem avisos do SmartScreen/Defender
    e permitem usar ExecutionPolicy AllSigned. Certificado autoassinado só funciona nos PCs
    onde ele for instalado como confiável.

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

$sumsPath = Join-Path $root "SHA256SUMS.txt"
Get-ChildItem -LiteralPath $root -Recurse -File |
    Where-Object { $_.Name -ne "SHA256SUMS.txt" -and $_.FullName -notmatch "[\\/]\.git[\\/]" } |
    ForEach-Object {
        $relative = $_.FullName.Substring($root.Length + 1)
        "{0}  {1}" -f (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLower(), $relative
    } | Set-Content -LiteralPath $sumsPath -Encoding ASCII

Write-Host "Hashes gravados em $sumsPath" -ForegroundColor Cyan
