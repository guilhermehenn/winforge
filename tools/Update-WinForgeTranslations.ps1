#requires -Version 5.1
<#
.SYNOPSIS
    Atualiza as traduções do WinForge (lang\*.po) com os textos atuais do código.

.DESCRIPTION
    O WinForge usa o texto em português como chave, como no gettext. Este script lê os textos da interface (as chamadas
    de Get-WinForgeText e Get-WinForgeContextText com texto fixo, os parâmetros que recebem texto da interface, os
    atributos visíveis do XAML e o catálogo de programas) e grava o modelo tools\WinForge.pot. Depois junta o modelo em
    cada lang\*.po: as traduções existentes ficam, os textos novos entram sem tradução (o WinForge mostra o português
    até alguém traduzir) e os que saíram do código vão para o fim do arquivo como obsoletos (#~), para reaproveitar.

    Abra o .po num editor de traduções (o Poedit, por exemplo) para preencher o que falta. Os comentários "#." dizem o
    que entra em cada {0}, {1}... Uma tradução com marcadores diferentes do português não quebra nada (vale o
    português), mas aparece no aviso do fim.

.EXAMPLE
    .\tools\Update-WinForgeTranslations.ps1
#>
[CmdletBinding()]
param ()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$root = Split-Path -Parent $PSScriptRoot
$utf8 = New-Object System.Text.UTF8Encoding $false
$eot = [string][char]4

# Parâmetros que recebem texto da interface sem passar por Get-WinForgeText na chamada (a função traduz por dentro).
$parameterTexts = @(
    @{ Command = "Write-WinForgeOtherAccountNotice"; Parameter = "What"; Note = "começa com o artigo: a frase concorda com ele (gênero e número)" },
    @{ Command = "Format-WinForgeDateTime"; Parameter = "Pattern"; Note = "padrão de data (Format-WinForgeDateTime)" }
)

# Funções cujo primeiro argumento é texto da interface.
$firstArgumentTexts = @{ "Get-WinForgeStartupText" = "mensagem de início (antes dos módulos)" }

# Textos que o código usa sem escrever na chamada (o padrão de Format-WinForgeDateTime).
$fixedTexts = @(@{ Text = "dd/MM/yyyy HH:mm"; Where = "modules/Core.psm1"; Note = "padrão de data (Format-WinForgeDateTime)" })

$entries = New-Object 'System.Collections.Generic.Dictionary[string,object]' ([System.StringComparer]::Ordinal)
$order = New-Object System.Collections.Generic.List[string]


function Add-Text {
    param ([string]$Key, [string]$Where, [string]$Note = "")

    if ([string]::IsNullOrEmpty($Key)) { return }

    if (-not $entries.ContainsKey($Key)) {
        $entries[$Key] = [PSCustomObject]@{ Places = (New-Object System.Collections.Generic.List[string]); Notes = (New-Object System.Collections.Generic.List[string]) }
        $order.Add($Key)
    }

    $entry = $entries[$Key]

    if ($entry.Places.Count -lt 4 -and -not $entry.Places.Contains($Where)) { $entry.Places.Add($Where) }
    if ($Note -and $entry.Notes.Count -lt 3 -and -not $entry.Notes.Contains($Note)) { $entry.Notes.Add($Note) }
}


function Get-ArgumentNote {
    # "{0} = "$x" | {1} = ..." a partir dos argumentos da chamada, para quem traduz saber o que entra em cada marcador.
    param ($Elements)

    $parts = @()

    for ($i = 0; $i -lt $Elements.Count; $i++) {
        $text = ($Elements[$i].Extent.Text -replace '\s+', ' ')

        if ($text.Length -gt 90) { $text = $text.Substring(0, 90) }

        $parts += "{$i} = $text"
    }

    return ($parts -join " | ")
}


function Test-InsideTranslation {
    # Se o texto já está dentro de um Get-WinForgeText (ou Get-WinForgeContextText) dentro do argumento.
    param ($Node, $Stop)

    $parent = $Node.Parent

    while ($null -ne $parent -and $parent -ne $Stop) {
        if ($parent -is [System.Management.Automation.Language.CommandAst] -and @("Get-WinForgeText", "Get-WinForgeContextText") -contains $parent.GetCommandName()) { return $true }

        $parent = $parent.Parent
    }

    return $false
}


# Os scripts: os módulos e os scripts de entrada, nessa ordem.
$files = @(Get-ChildItem -LiteralPath (Join-Path $root "modules") -Filter "*.psm1" -File | Sort-Object Name) + @(Get-ChildItem -LiteralPath $root -Filter "WinForge.*.ps1" -File | Sort-Object Name)

foreach ($file in $files) {
    $tokens = $null
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors)

    if ($errors.Count -gt 0) { throw "$($file.Name): $($errors[0].Message)" }

    $relative = if ($file.Directory.Name -eq "modules") { "modules/$($file.Name)" } else { $file.Name }

    foreach ($command in $ast.FindAll({ param ($node) $node -is [System.Management.Automation.Language.CommandAst] }, $true)) {
        $name = $command.GetCommandName()
        $elements = @($command.CommandElements)
        $where = "${relative}:$($command.Extent.StartLineNumber)"

        if ($name -eq "Get-WinForgeText") {
            if ($elements.Count -ge 2 -and $elements[1] -is [System.Management.Automation.Language.StringConstantExpressionAst]) {
                Add-Text -Key $elements[1].Value -Where $where -Note (Get-ArgumentNote -Elements @($elements | Select-Object -Skip 2))
            }

            continue
        }

        if ($name -eq "Get-WinForgeContextText") {
            if ($elements.Count -ge 3 -and $elements[1] -is [System.Management.Automation.Language.StringConstantExpressionAst] -and $elements[2] -is [System.Management.Automation.Language.StringConstantExpressionAst]) {
                $note = "contexto: $($elements[1].Value)"
                $arguments = Get-ArgumentNote -Elements @($elements | Select-Object -Skip 3)

                if ($arguments) { $note = "$note | $arguments" }

                Add-Text -Key ($elements[1].Value + $eot + $elements[2].Value) -Where $where -Note $note
            }

            continue
        }

        if ($firstArgumentTexts.ContainsKey([string]$name)) {
            if ($elements.Count -ge 2 -and $elements[1] -is [System.Management.Automation.Language.StringConstantExpressionAst]) {
                Add-Text -Key $elements[1].Value -Where $where -Note $firstArgumentTexts[[string]$name]
            }

            continue
        }

        foreach ($spec in @($parameterTexts | Where-Object { $_.Command -eq $name })) {
            for ($i = 1; $i -lt $elements.Count - 1; $i++) {
                if (-not ($elements[$i] -is [System.Management.Automation.Language.CommandParameterAst] -and $elements[$i].ParameterName -eq $spec.Parameter)) { continue }

                $argument = $elements[$i + 1]
                $strings = $argument.FindAll({ param ($node) $node -is [System.Management.Automation.Language.StringConstantExpressionAst] -and $node.StringConstantType -ne "BareWord" }, $true)

                foreach ($string in $strings) {
                    if (Test-InsideTranslation -Node $string -Stop $command) { continue }

                    Add-Text -Key $string.Value -Where $where -Note $spec.Note
                }
            }
        }
    }
}

foreach ($fixed in $fixedTexts) { Add-Text -Key $fixed.Text -Where $fixed.Where -Note $fixed.Note }

# O XAML: os mesmos atributos que a janela traduz ao carregar.
$xamlFiles = @(Get-ChildItem -LiteralPath $root -Filter "*.xaml" -File -Recurse | Where-Object { $_.FullName -notmatch '[\\/](tools|catalog|\.git)[\\/]' } | Sort-Object FullName)

foreach ($xaml in $xamlFiles) {
    $text = [System.IO.File]::ReadAllText($xaml.FullName, [System.Text.Encoding]::UTF8)

    foreach ($match in [regex]::Matches($text, '(?<=\s)(Text|Content|ToolTip|Header|Title|AutomationProperties\.Name)="([^"]*)"')) {
        $value = [System.Net.WebUtility]::HtmlDecode($match.Groups[2].Value)

        if (-not $value -or $value.StartsWith("{") -or $value -notmatch '\p{L}') { continue }

        $line = ($text.Substring(0, $match.Index) -split "`n").Count
        Add-Text -Key $value -Where "$($xaml.Name):$line" -Note "XAML $($match.Groups[1].Value)"
    }
}

# O catálogo de programas (o embutido e o publicado): categorias e descrições aparecem traduzidas na tela.
Import-Module (Join-Path $root "modules\Core.psm1") -Force -DisableNameChecking
Import-Module (Join-Path $root "modules\Catalog.psm1") -Force -DisableNameChecking

foreach ($program in @((Get-WinForgeBuiltInCatalog).Essentials)) {
    Add-Text -Key ([string]$program.Categoria) -Where "catalog:embutido" -Note "categoria do catálogo"
    Add-Text -Key ([string]$program.Descricao) -Where "catalog:embutido" -Note "descrição de programa ($($program.Nome))"
}

$published = Join-Path $root "catalog\catalog.json"

if (Test-Path -LiteralPath $published) {
    $document = [System.IO.File]::ReadAllText($published, [System.Text.Encoding]::UTF8) | ConvertFrom-Json

    foreach ($program in @($document.Essentials)) {
        Add-Text -Key ([string]$program.Categoria) -Where "catalog.json" -Note "categoria do catálogo"
        Add-Text -Key ([string]$program.Descricao) -Where "catalog.json" -Note "descrição de programa ($($program.Nome))"
    }
}


function ConvertTo-PoLines {
    # Um campo do .po: uma linha só, ou, com quebras de linha, uma linha por trecho (como o gettext grava).
    param ([string]$Field, [string]$Text, [string]$Prefix = "")

    $escaped = $Text.Replace('\', '\\').Replace('"', '\"').Replace("`t", '\t').Replace("`r", '\r').Replace("`n", "\n`n")
    $parts = @($escaped -split "`n" | Where-Object { $_.Length -gt 0 })

    if ($parts.Count -eq 0) { return @("$Prefix$Field `"`"") }
    if ($parts.Count -eq 1) { return @("$Prefix$Field `"$($parts[0])`"") }

    $lines = @("$Prefix$Field `"`"")

    foreach ($part in $parts) { $lines += "$Prefix`"$part`"" }

    return $lines
}


function ConvertFrom-PoText {
    # O texto entre aspas de uma linha do .po, com os escapes decodificados.
    param ([string]$Line)

    $start = $Line.IndexOf('"')
    $end = $Line.LastIndexOf('"')

    if ($start -lt 0 -or $end -le $start) { return "" }

    $text = $Line.Substring($start + 1, $end - $start - 1)
    $builder = New-Object System.Text.StringBuilder
    $i = 0

    while ($i -lt $text.Length) {
        $ch = $text[$i]

        if ($ch -eq '\' -and ($i + 1) -lt $text.Length) {
            $next = $text[$i + 1]

            if ($next -ceq 'n') { [void]$builder.Append([char]10) }
            elseif ($next -ceq 't') { [void]$builder.Append([char]9) }
            elseif ($next -ceq 'r') { [void]$builder.Append([char]13) }
            else { [void]$builder.Append($next) }

            $i += 2
            continue
        }

        [void]$builder.Append($ch)
        $i++
    }

    return $builder.ToString()
}


function Read-PoFile {
    # As entradas de um .po (ativas e obsoletas), com os comentários de quem traduz e as marcas (#,), e o cabeçalho.
    param ([string]$Path)

    $result = [PSCustomObject]@{
        Comments = (New-Object System.Collections.Generic.List[string])
        Header = ""
        Entries = (New-Object 'System.Collections.Generic.Dictionary[string,object]' ([System.StringComparer]::Ordinal))
        Order = (New-Object System.Collections.Generic.List[string])
    }

    if (-not (Test-Path -LiteralPath $Path)) { return $result }

    $lines = [System.IO.File]::ReadAllLines($Path, [System.Text.Encoding]::UTF8)
    $current = $null
    $field = ""
    $seenEntry = $false

    $flush = {
        if ($null -ne $current -and $null -ne $current.Id) {
            if ($current.Id.Length -eq 0 -and $null -eq $current.Context) { $result.Header = $current.Text }
            else {
                $key = if ($null -ne $current.Context) { $current.Context + $eot + $current.Id } else { $current.Id }

                if (-not $result.Entries.ContainsKey($key)) { $result.Order.Add($key) }

                $result.Entries[$key] = $current
            }
        }
    }

    foreach ($raw in ($lines + @(""))) {
        $line = $raw.Trim()
        $obsolete = $false

        if ($line.StartsWith("#~")) {
            $obsolete = $true
            $line = $line.Substring(2).Trim()
        }

        $starts = $line.StartsWith("msgctxt ") -or ($line.StartsWith("msgid ") -and $field -ne "ctxt")

        if ($line.Length -eq 0 -or ($field -eq "str" -and ($starts -or ($line.StartsWith("#") -and -not $obsolete)))) {
            & $flush
            $current = $null
            $field = ""
        }

        if ($line.Length -eq 0) { continue }

        if ($null -eq $current) {
            $current = [PSCustomObject]@{ Context = $null; Id = $null; Text = ""; Flags = ""; Translator = (New-Object System.Collections.Generic.List[string]); Obsolete = $obsolete }
        }

        if ($obsolete) { $current.Obsolete = $true }

        if ($line.StartsWith("#")) {
            if ($line.StartsWith("#,")) { $current.Flags = $line.Substring(2).Trim() }
            elseif ($line -eq "#" -or $line.StartsWith("# ")) {
                if (-not $seenEntry) { $result.Comments.Add($raw.TrimEnd()) }
                else { $current.Translator.Add($raw.TrimEnd()) }
            }

            continue
        }

        $seenEntry = $true

        if ($line.StartsWith("msgctxt ")) { $current.Context = ConvertFrom-PoText -Line $line; $field = "ctxt"; continue }
        if ($line.StartsWith("msgid ")) { $current.Id = ConvertFrom-PoText -Line $line; $field = "id"; continue }
        if ($line.StartsWith("msgstr ")) { $current.Text = ConvertFrom-PoText -Line $line; $field = "str"; continue }

        if ($line.StartsWith('"')) {
            $piece = ConvertFrom-PoText -Line $line

            if ($field -eq "ctxt") { $current.Context += $piece }
            elseif ($field -eq "id") { $current.Id += $piece }
            elseif ($field -eq "str") { $current.Text += $piece }
        }
    }

    return $result
}


function Get-Placeholders {
    param ([string]$Text)

    return ((@([regex]::Matches($Text, '\{[0-9]+\}') | ForEach-Object { $_.Value }) | Sort-Object) -join ",")
}


function Write-PoFile {
    param ([string]$Path, [string[]]$Comments, [string]$Header, $Existing)

    $out = New-Object System.Collections.Generic.List[string]
    $warnings = @()
    $translated = 0

    foreach ($comment in $Comments) { $out.Add($comment) }

    foreach ($line in (ConvertTo-PoLines -Field "msgid" -Text "")) { $out.Add($line) }
    foreach ($line in (ConvertTo-PoLines -Field "msgstr" -Text $Header)) { $out.Add($line) }

    foreach ($key in $order) {
        $entry = $entries[$key]
        $context = $null
        $id = $key

        # IndexOf com um caractere compara byte a byte; com um texto, a cultura ignoraria o caractere 4.
        $split = $key.IndexOf([char]4)

        if ($split -ge 0) {
            $context = $key.Substring(0, $split)
            $id = $key.Substring($split + 1)
        }

        $old = $null

        if ($null -ne $Existing -and $Existing.Entries.ContainsKey($key)) { $old = $Existing.Entries[$key] }

        $out.Add("")

        if ($null -ne $old) { foreach ($comment in $old.Translator) { $out.Add($comment) } }
        foreach ($note in $entry.Notes) { $out.Add("#. $($note -replace '[\r\n]+', ' ')") }

        $out.Add("#: $($entry.Places -join ' ')")

        $text = ""

        if ($null -ne $old) {
            $text = $old.Text

            if ($old.Flags) { $out.Add("#, $($old.Flags)") }
            if ($text.Length -gt 0 -and $old.Flags -notmatch 'fuzzy') { $translated++ }
            if ($text.Length -gt 0 -and (Get-Placeholders -Text $text) -ne (Get-Placeholders -Text $id)) { $warnings += $id }
        }

        if ($null -ne $context) { foreach ($line in (ConvertTo-PoLines -Field "msgctxt" -Text $context)) { $out.Add($line) } }
        foreach ($line in (ConvertTo-PoLines -Field "msgid" -Text $id)) { $out.Add($line) }
        foreach ($line in (ConvertTo-PoLines -Field "msgstr" -Text $text)) { $out.Add($line) }
    }

    # O que saiu do código e tinha tradução fica no fim como obsoleto: volta sozinho se o texto voltar.
    $obsolete = 0

    if ($null -ne $Existing) {
        foreach ($key in $Existing.Order) {
            if ($entries.ContainsKey($key)) { continue }

            $old = $Existing.Entries[$key]

            if ($old.Text.Length -eq 0) { continue }

            $obsolete++
            $out.Add("")

            if ($null -ne $old.Context) { foreach ($line in (ConvertTo-PoLines -Field "msgctxt" -Text $old.Context -Prefix "#~ ")) { $out.Add($line) } }
            foreach ($line in (ConvertTo-PoLines -Field "msgid" -Text $old.Id -Prefix "#~ ")) { $out.Add($line) }
            foreach ($line in (ConvertTo-PoLines -Field "msgstr" -Text $old.Text -Prefix "#~ ")) { $out.Add($line) }
        }
    }

    [System.IO.File]::WriteAllText($Path, (($out -join "`r`n") + "`r`n"), $utf8)

    return [PSCustomObject]@{ Translated = $translated; Obsolete = $obsolete; Warnings = $warnings }
}


$templateHeader = "Project-Id-Version: WinForge`nMIME-Version: 1.0`nContent-Type: text/plain; charset=UTF-8`nContent-Transfer-Encoding: 8bit`n"
$templateComments = @("# Textos da interface do WinForge: o modelo das traduções (lang\*.po).", "# Gerado por tools\Update-WinForgeTranslations.ps1; não edite à mão.")

[void](Write-PoFile -Path (Join-Path $PSScriptRoot "WinForge.pot") -Comments $templateComments -Header $templateHeader -Existing $null)
Write-Host "Modelo: $($order.Count) textos em tools\WinForge.pot" -ForegroundColor Cyan

$languageFolder = Join-Path $root "lang"

foreach ($po in @(Get-ChildItem -LiteralPath $languageFolder -Filter "*.po" -File -ErrorAction SilentlyContinue | Sort-Object Name)) {
    $existing = Read-PoFile -Path $po.FullName
    $header = $existing.Header

    if (-not $header) { $header = $templateHeader + "Language: $($po.BaseName)`n" }

    $summary = Write-PoFile -Path $po.FullName -Comments @($existing.Comments) -Header $header -Existing $existing
    $missing = $order.Count - $summary.Translated

    Write-Host "$($po.Name): $($summary.Translated) traduzidos, $missing sem tradução, $($summary.Obsolete) obsoletos" -ForegroundColor $(if ($missing -gt 0) { "Yellow" } else { "Green" })

    foreach ($id in $summary.Warnings) { Write-Host "  marcadores diferentes do português: $id" -ForegroundColor Red }
}
