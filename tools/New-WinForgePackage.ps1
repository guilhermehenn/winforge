#requires -Version 5.1
<#
.SYNOPSIS
    Monta o WinForge.zip de uma versão, como ele é publicado.

.DESCRIPTION
    - Leva só os arquivos que o WinForge instala, troca e desinstala (Get-WinForgePackageFiles, do Install.psm1): os da
      raiz (WinForge*.cmd, WinForge.*.ps1, README*.md, CHANGELOG.md e LICENSE) e as pastas modules, gui, lang e assets,
      dentro de uma pasta WinForge. As ferramentas, a pasta docs e os arquivos do git ficam de fora.
    - O CHANGELOG.md do zip traz as cinco builds mais recentes e o link para o histórico completo, no GitHub.
    - O SHA256SUMS.txt do zip é feito dos arquivos como eles estão no zip (com o CHANGELOG curto), e não da pasta.
    - No fim, mostra o SHA-256 do zip, que vai na página da versão: é ele que Verificar nova versão confere.

    Para uma versão assinada, rode antes o tools\Sign-WinForge.ps1: as assinaturas ficam dentro dos scripts.

.PARAMETER Destination
    O zip a gravar. Padrão: dist\WinForge.zip, na pasta do repositório (fora do git, pelo .gitignore).

.EXAMPLE
    .\tools\New-WinForgePackage.ps1
#>
[CmdletBinding()]
param (
    [string]$Destination
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$root = Split-Path -Parent $PSScriptRoot

# O que é do WinForge numa pasta vem do mesmo lugar que o instalador usa: o zip leva exatamente o que ele troca.
Import-Module (Join-Path $root "modules/Core.psm1") -Force -DisableNameChecking -WarningAction SilentlyContinue
Import-Module (Join-Path $root "modules/Install.psm1") -Force -DisableNameChecking -WarningAction SilentlyContinue

if ([string]::IsNullOrWhiteSpace($Destination)) { $Destination = Join-Path (Join-Path $root "dist") "WinForge.zip" }
$Destination = [System.IO.Path]::GetFullPath($Destination)

# Arquivos que o Windows cria sozinho numa pasta (miniaturas, aparência da pasta) e o SHA256SUMS.txt de uma assinatura
# antiga, que é refeito abaixo com o conteúdo do zip.
$skip = @("Thumbs.db", "desktop.ini", "SHA256SUMS.txt")
$files = @(Get-WinForgePackageFiles -Root $root | Where-Object { $skip -notcontains [System.IO.Path]::GetFileName($_) })

if ($files.Count -eq 0 -or $files -notcontains "CHANGELOG.md") { throw "A pasta $root não tem os arquivos do WinForge." }

function Get-WinForgePackageChangelog {
    # O CHANGELOG do zip: até a quinta build ("## Build ..."), e depois o link para as anteriores. Com cinco ou menos,
    # inteiro.
    param ([Parameter(Mandatory)][string]$Text)

    $heads = @([regex]::Matches($Text, '(?m)^## Build '))

    if ($heads.Count -le 5) { return $Text }

    $footer = "As builds anteriores estão no histórico completo: https://github.com/guilhermehenn/winforge/blob/main/CHANGELOG.md`r`n"

    return ($Text.Substring(0, $heads[5].Index).TrimEnd("`r", "`n") + "`r`n`r`n---`r`n`r`n" + $footer)
}

$utf8 = New-Object System.Text.UTF8Encoding $false
$sha = [System.Security.Cryptography.SHA256]::Create()
$sums = New-Object System.Collections.Generic.List[string]
$folder = Split-Path -Parent $Destination

if (-not (Test-Path -LiteralPath $folder)) { [void](New-Item -ItemType Directory -Path $folder) }
if (Test-Path -LiteralPath $Destination) { Remove-Item -LiteralPath $Destination -Force }

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$zip = [System.IO.Compression.ZipFile]::Open($Destination, [System.IO.Compression.ZipArchiveMode]::Create)

try {
    foreach ($relative in $files) {
        $path = Join-Path $root $relative
        $bytes = [System.IO.File]::ReadAllBytes($path)
        # No zip, a barra é sempre "/": com "\", alguns programas de descompactar criariam nomes com a barra no meio.
        $name = $relative.Replace('\', '/')

        if ($name -eq "CHANGELOG.md") { $bytes = $utf8.GetBytes((Get-WinForgePackageChangelog -Text $utf8.GetString($bytes))) }

        $entry = $zip.CreateEntry("WinForge/$name", [System.IO.Compression.CompressionLevel]::Optimal)
        $entry.LastWriteTime = (Get-Item -LiteralPath $path).LastWriteTime
        $stream = $entry.Open()
        try { $stream.Write($bytes, 0, $bytes.Length) } finally { $stream.Dispose() }

        $sums.Add(("{0}  {1}" -f ([System.BitConverter]::ToString($sha.ComputeHash($bytes)) -replace '-', '').ToLowerInvariant(), $name))
    }

    $entry = $zip.CreateEntry("WinForge/SHA256SUMS.txt", [System.IO.Compression.CompressionLevel]::Optimal)
    $bytes = [System.Text.Encoding]::ASCII.GetBytes((($sums -join "`r`n") + "`r`n"))
    $stream = $entry.Open()
    try { $stream.Write($bytes, 0, $bytes.Length) } finally { $stream.Dispose() }
}
finally {
    $zip.Dispose()
    $sha.Dispose()
}

$hash = (Get-FileHash -LiteralPath $Destination -Algorithm SHA256).Hash.ToLowerInvariant()

Write-Host ("WinForge {0}: {1} arquivos em {2}" -f (Get-WinForgeBuild), ($files.Count + 1), $Destination) -ForegroundColor Green
Write-Host ("SHA-256 do zip (vai na página da versão): {0}" -f $hash) -ForegroundColor Cyan

[PSCustomObject]@{ Path = $Destination; Files = ($files.Count + 1); Sha256 = $hash; Build = (Get-WinForgeBuild) }
