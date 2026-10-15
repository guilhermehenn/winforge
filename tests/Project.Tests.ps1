# Verificações estáticas do projeto inteiro: sintaxe, codificação dos arquivos, estrutura dos módulos, uso correto
# das funções entre módulos (nomes e parâmetros), chamadas a programas nativos e a ligação entre janela e XAML.
# Nada aqui executa as ações: o código é apenas lido e analisado.

BeforeAll {
    $script:Root = Split-Path -Parent $PSScriptRoot
    $script:Utf8 = New-Object System.Text.UTF8Encoding($false)

    function script:Get-RelativeName {
        param ([string]$Path)

        return $Path.Substring($script:Root.Length).TrimStart([char]92, [char]47).Replace([char]92, [char]47)
    }

    function script:Get-FileBytes {
        param ([string]$Path)

        return [System.IO.File]::ReadAllBytes($Path)
    }

    function script:Test-HasBom {
        param ([byte[]]$Bytes)

        return ($Bytes.Length -ge 3 -and $Bytes[0] -eq 0xEF -and $Bytes[1] -eq 0xBB -and $Bytes[2] -eq 0xBF)
    }

    function script:Test-HasLoneLineFeed {
        # Há LF sem CR antes? (a codificação do projeto é CRLF)
        param ([byte[]]$Bytes)

        for ($i = 0; $i -lt $Bytes.Length; $i++) {
            if ($Bytes[$i] -eq 10 -and ($i -eq 0 -or $Bytes[$i - 1] -ne 13)) { return $true }
        }

        return $false
    }

    $all = Get-ChildItem -LiteralPath $script:Root -Recurse -File -Force |
        Where-Object { (Get-RelativeName $_.FullName) -notmatch '^(\.git|node_modules)/' }

    $script:AllFiles = @($all | Sort-Object FullName)
    $script:ScriptFiles = @($script:AllFiles | Where-Object { $_.Extension -in ".ps1", ".psm1", ".psd1" })
    $script:ProductFiles = @($script:ScriptFiles | Where-Object { (Get-RelativeName $_.FullName) -notlike "tests/*" -and $_.Extension -ne ".psd1" })
    $script:ModuleFiles = @($script:ProductFiles | Where-Object { $_.Extension -eq ".psm1" })
    $script:EntryFiles = @($script:ProductFiles | Where-Object { $_.Extension -eq ".ps1" })

    $script:ParsedByPath = @{}
    foreach ($file in $script:ScriptFiles) {
        $text = $script:Utf8.GetString((Get-FileBytes $file.FullName)).TrimStart([char]0xFEFF)
        $tokens = $null
        $errors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseInput($text, [ref]$tokens, [ref]$errors)

        $script:ParsedByPath[$file.FullName] = [PSCustomObject]@{
            File   = $file
            Name   = Get-RelativeName $file.FullName
            Text   = $text
            Ast    = $ast
            Errors = @($errors)
        }
    }

    function script:Find-Ast {
        param ([System.Management.Automation.Language.Ast]$Ast, [scriptblock]$Predicate)

        return @($Ast.FindAll($Predicate, $true))
    }

    function script:Get-ParamInfo {
        # Lista dos parâmetros de uma função: nome, apelidos, posição, obrigatório, switch.
        param ([System.Management.Automation.Language.FunctionDefinitionAst]$Function)

        $parameters = $null

        if ($Function.Parameters) { $parameters = $Function.Parameters }
        elseif ($Function.Body.ParamBlock) { $parameters = $Function.Body.ParamBlock.Parameters }

        $isAdvanced = $false
        $usesParameterSets = $false

        if ($Function.Body.ParamBlock) {
            foreach ($attribute in $Function.Body.ParamBlock.Attributes) {
                if ($attribute.TypeName.Name -eq "CmdletBinding") { $isAdvanced = $true }
            }
        }

        $list = @()

        foreach ($parameter in @($parameters)) {
            if ($null -eq $parameter) { continue }

            $info = [PSCustomObject]@{
                Name        = $parameter.Name.VariablePath.UserPath
                Aliases     = @()
                Position    = -1
                Mandatory   = $false
                IsSwitch    = ($parameter.StaticType.FullName -eq "System.Management.Automation.SwitchParameter")
                FromPipe    = $false
                FromRemain  = $false
            }

            foreach ($attribute in $parameter.Attributes) {
                $attributeName = $attribute.TypeName.Name

                if ($attributeName -eq "Alias") {
                    $info.Aliases = @($attribute.PositionalArguments | ForEach-Object { [string]$_.Value })
                }
                elseif ($attributeName -eq "Parameter") {
                    $isAdvanced = $true

                    foreach ($named in $attribute.NamedArguments) {
                        $value = $true
                        if (-not $named.ExpressionOmitted) { $value = ($named.Argument.Extent.Text -ne '$false') }

                        switch ($named.ArgumentName) {
                            "Mandatory" { $info.Mandatory = $value }
                            "ValueFromPipeline" { $info.FromPipe = $value }
                            "ValueFromPipelineByPropertyName" { if ($value) { $info.FromPipe = $true } }
                            "ValueFromRemainingArguments" { $info.FromRemain = $value }
                            "Position" { $info.Position = [int]$named.Argument.Value }
                            "ParameterSetName" { $usesParameterSets = $true }
                        }
                    }
                }
            }

            $list += $info
        }

        return [PSCustomObject]@{
            Name              = $Function.Name
            Parameters        = $list
            IsAdvanced        = $isAdvanced
            UsesParameterSets = $usesParameterSets
        }
    }

    # Tabela de todas as funções do produto (módulos e scripts de entrada, em qualquer profundidade).
    $script:Functions = @{}
    $script:FunctionLocations = @{}

    foreach ($file in $script:ProductFiles) {
        $parsed = $script:ParsedByPath[$file.FullName]
        $definitions = Find-Ast $parsed.Ast { param ($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] }

        foreach ($definition in $definitions) {
            $key = $definition.Name.ToLowerInvariant()

            if (-not $script:Functions.ContainsKey($key)) {
                $script:Functions[$key] = Get-ParamInfo $definition
                $script:FunctionLocations[$key] = @()
            }

            $script:FunctionLocations[$key] += "$($parsed.Name):$($definition.Extent.StartLineNumber)"
        }
    }

    $script:CommonParameters = @(
        "Verbose", "Debug", "ErrorAction", "WarningAction", "InformationAction", "ErrorVariable", "WarningVariable",
        "InformationVariable", "OutVariable", "OutBuffer", "PipelineVariable", "WhatIf", "Confirm"
    )

    $script:XamlText = [System.IO.File]::ReadAllText((Join-Path $script:Root "gui/MainWindow.xaml"))
    $script:GuiText = $script:ParsedByPath[(Join-Path $script:Root "WinForge.Gui.ps1")].Text

    # Nomes (x:Name) dos elementos da janela, sem as partes internas de modelos (ControlTemplate), que têm escopo próprio.
    $script:XamlNames = @()
    try {
        $xamlDocument = New-Object System.Xml.XmlDocument
        $xamlDocument.LoadXml($script:XamlText)
        $xamlNamespaces = New-Object System.Xml.XmlNamespaceManager($xamlDocument.NameTable)
        $xamlNamespaces.AddNamespace("x", "http://schemas.microsoft.com/winfx/2006/xaml")
        $script:XamlNames = @($xamlDocument.SelectNodes("//*[@x:Name and not(ancestor::*[local-name()='ControlTemplate'])]", $xamlNamespaces) |
            ForEach-Object { $_.GetAttribute("Name", "http://schemas.microsoft.com/winfx/2006/xaml") })
    }
    catch { }

    function script:Get-CommandCalls {
        param ($Parsed)

        return (Find-Ast $Parsed.Ast { param ($node) $node -is [System.Management.Automation.Language.CommandAst] })
    }

    function script:Get-ParameterProblems {
        # Parâmetros nomeados de uma chamada a função do projeto que a função não declara (nem por apelido ou prefixo).
        param ($Call, [string]$Where)

        $name = $Call.GetCommandName()
        if (-not $name) { return }

        $function = $script:Functions[$name.ToLowerInvariant()]
        if ($null -eq $function) { return }

        $accepted = @()
        foreach ($parameter in $function.Parameters) { $accepted += $parameter.Name; $accepted += $parameter.Aliases }
        if ($function.IsAdvanced) { $accepted += $script:CommonParameters }

        foreach ($element in $Call.CommandElements) {
            if ($element -isnot [System.Management.Automation.Language.CommandParameterAst]) { continue }

            $used = $element.ParameterName
            $exact = @($accepted | Where-Object { $_ -ieq $used })
            $prefix = @($accepted | Where-Object { $_ -like "$used*" } | Select-Object -Unique)

            if ($exact.Count -eq 0 -and $prefix.Count -eq 0) {
                "$Where $name não tem o parâmetro -$used"
            }
            elseif ($exact.Count -eq 0 -and $prefix.Count -gt 1) {
                "$Where $name -$used é ambíguo"
            }
        }
    }

    function script:Format-Violations {
        param ([object[]]$Items)

        return (@($Items | Where-Object { $_ }) -join "`n")
    }
}


Describe "Arquivos" {
    It "todos os scripts e módulos têm sintaxe válida" {
        $problems = foreach ($parsed in $script:ParsedByPath.Values) {
            foreach ($parseError in $parsed.Errors) {
                "$($parsed.Name):$($parseError.Extent.StartLineNumber): $($parseError.Message)"
            }
        }

        Format-Violations $problems | Should -BeNullOrEmpty
    }

    It "scripts, módulos e manifestos são UTF-8 com BOM e quebra de linha CRLF" {
        $problems = foreach ($file in $script:ScriptFiles) {
            $bytes = Get-FileBytes $file.FullName
            $name = Get-RelativeName $file.FullName

            if (-not (Test-HasBom $bytes)) { "$name : sem BOM (o Windows PowerShell 5.1 leria os acentos errado)" }
            if (Test-HasLoneLineFeed $bytes) { "$name : tem quebra de linha LF (deve ser CRLF)" }
        }

        Format-Violations $problems | Should -BeNullOrEmpty
    }

    It "arquivos .cmd são ASCII puro, com CRLF e sem BOM" {
        $problems = foreach ($file in ($script:AllFiles | Where-Object { $_.Extension -eq ".cmd" })) {
            $bytes = Get-FileBytes $file.FullName
            $name = Get-RelativeName $file.FullName

            if (Test-HasBom $bytes) { "$name : tem BOM" }
            if (Test-HasLoneLineFeed $bytes) { "$name : tem quebra de linha LF" }
            if (@($bytes | Where-Object { $_ -gt 127 }).Count -gt 0) { "$name : tem caracteres fora de ASCII" }
        }

        Format-Violations $problems | Should -BeNullOrEmpty
    }

    It "demais arquivos de texto têm CRLF e não têm BOM" {
        $extensions = ".md", ".yml", ".yaml", ".xaml", ".json", ".txt", ".svg", ".editorconfig", ".gitattributes", ".gitignore"

        $problems = foreach ($file in $script:AllFiles) {
            if ($file.Name -eq "LICENSE") { continue }
            if ($file.Extension -notin $extensions) { continue }

            $bytes = Get-FileBytes $file.FullName
            $name = Get-RelativeName $file.FullName

            if (Test-HasBom $bytes) { "$name : tem BOM" }
            if (Test-HasLoneLineFeed $bytes) { "$name : tem quebra de linha LF" }
        }

        Format-Violations $problems | Should -BeNullOrEmpty
    }

    It "não há arquivos temporários, de backup ou lixo de sistema" {
        $problems = foreach ($file in $script:AllFiles) {
            if ($file.Name -match '(\.bak|\.orig|\.tmp|\.rej|~)$' -or $file.Name -in "Thumbs.db", ".DS_Store", "desktop.ini") {
                Get-RelativeName $file.FullName
            }
        }

        Format-Violations $problems | Should -BeNullOrEmpty
    }

    It "os módulos listados em Modules.psd1 existem e todo .psm1 está listado" {
        $manifest = Import-PowerShellDataFile -LiteralPath (Join-Path $script:Root "modules/Modules.psd1")
        $listed = @($manifest.Common) + @($manifest.Console) + @($manifest.Gui)
        $present = @($script:ModuleFiles | ForEach-Object { $_.BaseName })

        $problems = @()
        foreach ($name in $listed) { if ($name -notin $present) { "Listado mas não existe: $name.psm1" } }
        foreach ($name in $present) { if ($name -notin $listed) { "Existe mas não está em Modules.psd1: $name.psm1" } }
        foreach ($name in $listed) { if (@($listed | Where-Object { $_ -eq $name }).Count -gt 1) { "Listado mais de uma vez: $name" } }

        Format-Violations $problems | Should -BeNullOrEmpty
    }

    It "os iniciadores .cmd apontam para scripts que existem" {
        $problems = foreach ($file in ($script:AllFiles | Where-Object { $_.Extension -eq ".cmd" })) {
            $text = [System.IO.File]::ReadAllText($file.FullName)

            foreach ($match in [regex]::Matches($text, '%~dp0([A-Za-z0-9._-]+\.ps1)')) {
                $target = Join-Path $file.DirectoryName $match.Groups[1].Value
                if (-not (Test-Path -LiteralPath $target)) { "$($file.Name) aponta para $($match.Groups[1].Value), que não existe" }
            }
        }

        Format-Violations $problems | Should -BeNullOrEmpty
    }

    It "cada iniciador .cmd tem uma única responsabilidade: janela ou terminal" {
        $gui = [System.IO.File]::ReadAllText((Join-Path $script:Root "WinForge.cmd"))
        $console = [System.IO.File]::ReadAllText((Join-Path $script:Root "WinForge-Console.cmd"))

        $gui | Should -Match 'WinForge\.Gui\.ps1'
        $gui | Should -Not -Match 'WinForge\.Console\.ps1'
        $console | Should -Match 'WinForge\.Console\.ps1'
        $console | Should -Not -Match 'WinForge\.Gui\.ps1'
    }

    It "a versão (build) do README e do CHANGELOG é a do código" {
        $core = $script:ParsedByPath[(Join-Path $script:Root "modules/Core.psm1")].Text
        $match = [regex]::Match($core, '\$script:WinForgeBuild\s*=\s*"([^"]+)"')
        $match.Success | Should -BeTrue

        $build = $match.Groups[1].Value
        $readme = [System.IO.File]::ReadAllText((Join-Path $script:Root "README.md"))
        $readme | Should -Match ([regex]::Escape($build))

        $changelogPath = Join-Path $script:Root "CHANGELOG.md"
        if (Test-Path -LiteralPath $changelogPath) {
            [System.IO.File]::ReadAllText($changelogPath) | Should -Match ([regex]::Escape($build))
        }
    }

    It "o executor de testes roda todos os arquivos *.Tests.ps1" {
        $runner = [System.IO.File]::ReadAllText((Join-Path $script:Root "tests/Run-Tests.ps1"))
        $runner | Should -Match '\*\.Tests\.ps1'
        $runner | Should -Not -Match 'WinForge\.Tests\.ps1'
    }
}


Describe "Módulos" {
    It "cada módulo termina exportando todas as funções" {
        $problems = foreach ($file in $script:ModuleFiles) {
            $parsed = $script:ParsedByPath[$file.FullName]
            $statements = @($parsed.Ast.EndBlock.Statements)
            $last = $statements[$statements.Count - 1]

            $ok = ($last -is [System.Management.Automation.Language.PipelineAst]) -and
                  ($last.Extent.Text -match '^Export-ModuleMember\s+-Function\s+\*$')

            if (-not $ok) { "$($parsed.Name) : o último comando deve ser 'Export-ModuleMember -Function *'" }
        }

        Format-Violations $problems | Should -BeNullOrEmpty
    }

    It "no nível superior de um módulo só há funções, variáveis do módulo e a exportação" {
        $problems = foreach ($file in $script:ModuleFiles) {
            $parsed = $script:ParsedByPath[$file.FullName]

            foreach ($statement in @($parsed.Ast.EndBlock.Statements)) {
                if ($statement -is [System.Management.Automation.Language.FunctionDefinitionAst]) { continue }

                if ($statement -is [System.Management.Automation.Language.AssignmentStatementAst]) {
                    $target = $statement.Left
                    if ($target -is [System.Management.Automation.Language.ConvertExpressionAst]) { $target = $target.Child }

                    if ($target -is [System.Management.Automation.Language.VariableExpressionAst] -and $target.VariablePath.IsScript) { continue }
                }

                if ($statement.Extent.Text -match '^Export-ModuleMember\s+-Function\s+\*$') { continue }

                "$($parsed.Name):$($statement.Extent.StartLineNumber): $($statement.Extent.Text.Split([char]10)[0].Trim())"
            }
        }

        Format-Violations $problems | Should -BeNullOrEmpty
    }

    It "os nomes de função são únicos em todo o projeto" {
        $problems = foreach ($key in $script:FunctionLocations.Keys) {
            if ($script:FunctionLocations[$key].Count -gt 1) {
                "$key definida em: $($script:FunctionLocations[$key] -join ', ')"
            }
        }

        Format-Violations $problems | Should -BeNullOrEmpty
    }

    It "funções dos módulos usam verbo aprovado do PowerShell e o prefixo WinForge" {
        $approved = @((Get-Verb).Verb)

        $problems = foreach ($file in $script:ModuleFiles) {
            $parsed = $script:ParsedByPath[$file.FullName]

            foreach ($statement in @($parsed.Ast.EndBlock.Statements)) {
                if ($statement -isnot [System.Management.Automation.Language.FunctionDefinitionAst]) { continue }

                $parts = $statement.Name.Split("-", 2)

                if ($parts.Count -ne 2 -or $parts[0] -notin $approved) {
                    "$($parsed.Name): $($statement.Name) não usa verbo aprovado"
                }
                elseif ($parts[1] -notlike "WinForge*") {
                    "$($parsed.Name): $($statement.Name) não usa o prefixo WinForge"
                }
            }
        }

        Format-Violations $problems | Should -BeNullOrEmpty
    }

    It "Read-Host só é usado no módulo Console (todo o resto pergunta por Read-WinForge*)" {
        $problems = foreach ($file in $script:ProductFiles) {
            $parsed = $script:ParsedByPath[$file.FullName]
            if ($file.Name -eq "Console.psm1") { continue }

            foreach ($call in (Get-CommandCalls $parsed)) {
                if ($call.GetCommandName() -eq "Read-Host") { "$($parsed.Name):$($call.Extent.StartLineNumber)" }
            }
        }

        Format-Violations $problems | Should -BeNullOrEmpty
    }

    It "exit só aparece em Core.psm1 (reabrir como administrador) e nos scripts de entrada" {
        $problems = foreach ($file in $script:ModuleFiles) {
            $parsed = $script:ParsedByPath[$file.FullName]
            if ($file.Name -eq "Core.psm1") { continue }

            foreach ($node in (Find-Ast $parsed.Ast { param ($n) $n -is [System.Management.Automation.Language.ExitStatementAst] })) {
                "$($parsed.Name):$($node.Extent.StartLineNumber)"
            }
        }

        Format-Violations $problems | Should -BeNullOrEmpty
    }

    It "nenhum Invoke-Expression nem Pause" {
        $problems = foreach ($file in $script:ProductFiles) {
            $parsed = $script:ParsedByPath[$file.FullName]

            foreach ($call in (Get-CommandCalls $parsed)) {
                if ($call.GetCommandName() -in "Invoke-Expression", "iex", "pause") { "$($parsed.Name):$($call.Extent.StartLineNumber) $($call.GetCommandName())" }
            }
        }

        Format-Violations $problems | Should -BeNullOrEmpty
    }

    It "nenhum apelido de cmdlet (use o nome completo)" {
        $aliases = @(
            "gci", "ls", "dir", "gc", "cat", "type", "%", "?", "where", "select", "sort", "group", "measure", "ft", "fl", "fw",
            "echo", "write", "iwr", "irm", "curl", "wget", "sleep", "cd", "pwd", "cp", "copy", "mv", "move", "rm", "del", "erase",
            "rmdir", "rd", "kill", "ps", "gps", "gsv", "sv", "gv", "ni", "si", "gi", "ri", "rni", "ren", "oh", "cls", "clear",
            "gm", "gl", "tee", "diff", "compare", "sls", "foreach", "gcm", "sasv", "spsv", "saps", "start", "ac", "sc", "gp", "sp"
        )

        $problems = foreach ($file in $script:ProductFiles) {
            $parsed = $script:ParsedByPath[$file.FullName]

            foreach ($call in (Get-CommandCalls $parsed)) {
                $name = $call.GetCommandName()
                if ($name -and $name.ToLowerInvariant() -in $aliases -and -not $script:Functions.ContainsKey($name.ToLowerInvariant())) {
                    "$($parsed.Name):$($call.Extent.StartLineNumber) usa o apelido '$name'"
                }
            }
        }

        Format-Violations $problems | Should -BeNullOrEmpty
    }

    It "expressões regulares usam [0-9] em vez de \d" {
        $operators = "Imatch", "Cmatch", "Inotmatch", "Cnotmatch", "Ireplace", "Creplace", "Isplit", "Csplit"

        $problems = foreach ($file in $script:ProductFiles) {
            $parsed = $script:ParsedByPath[$file.FullName]

            $binary = Find-Ast $parsed.Ast {
                param ($n)
                ($n -is [System.Management.Automation.Language.BinaryExpressionAst]) -and ($n.Operator.ToString() -in $operators)
            }

            foreach ($node in $binary) {
                $strings = @(Find-Ast $node.Right { param ($s) $s -is [System.Management.Automation.Language.StringConstantExpressionAst] -or $s -is [System.Management.Automation.Language.ExpandableStringExpressionAst] })

                foreach ($string in $strings) {
                    if ($string.Extent.Text -match '\\d') { "$($parsed.Name):$($node.Extent.StartLineNumber) $($node.Extent.Text.Split([char]10)[0].Trim())" }
                }
            }

            $members = Find-Ast $parsed.Ast {
                param ($n)
                ($n -is [System.Management.Automation.Language.InvokeMemberExpressionAst]) -and $n.Static -and
                ($n.Expression -is [System.Management.Automation.Language.TypeExpressionAst]) -and
                ($n.Expression.TypeName.Name -in "regex", "System.Text.RegularExpressions.Regex")
            }

            foreach ($node in $members) {
                if ($node.Extent.Text -match '\\d') { "$($parsed.Name):$($node.Extent.StartLineNumber) $($node.Extent.Text.Split([char]10)[0].Trim())" }
            }
        }

        Format-Violations $problems | Should -BeNullOrEmpty
    }

    It "scriptblocks com GetNewClosure() não usam variáveis `$script:" {
        $problems = foreach ($file in $script:ProductFiles) {
            $parsed = $script:ParsedByPath[$file.FullName]

            $closures = Find-Ast $parsed.Ast {
                param ($n)
                ($n -is [System.Management.Automation.Language.InvokeMemberExpressionAst]) -and ($n.Member.Value -eq "GetNewClosure") -and
                ($n.Expression -is [System.Management.Automation.Language.ScriptBlockExpressionAst])
            }

            foreach ($closure in $closures) {
                $variables = Find-Ast $closure.Expression { param ($v) ($v -is [System.Management.Automation.Language.VariableExpressionAst]) -and $v.VariablePath.IsScript }

                foreach ($variable in $variables) { "$($parsed.Name):$($variable.Extent.StartLineNumber) $($variable.Extent.Text)" }
            }
        }

        Format-Violations $problems | Should -BeNullOrEmpty
    }

    It "nenhuma atribuição a variáveis automáticas ou somente leitura" {
        $reserved = @(
            "home", "host", "pid", "pshome", "pwd", "args", "input", "true", "false", "null", "psitem", "_", "foreach", "switch",
            "this", "error", "profile", "myinvocation", "psboundparameters", "pscommandpath", "psscriptroot", "psversiontable",
            "shellid", "stacktrace", "iscoreclr", "iswindows", "islinux", "ismacos", "psculture", "psuiculture", "pscmdlet"
        )

        $problems = foreach ($file in $script:ProductFiles) {
            $parsed = $script:ParsedByPath[$file.FullName]

            foreach ($node in (Find-Ast $parsed.Ast { param ($n) $n -is [System.Management.Automation.Language.AssignmentStatementAst] })) {
                $target = $node.Left
                if ($target -is [System.Management.Automation.Language.ConvertExpressionAst]) { $target = $target.Child }

                if ($target -is [System.Management.Automation.Language.VariableExpressionAst] -and $target.VariablePath.UserPath.ToLowerInvariant() -in $reserved) {
                    "$($parsed.Name):$($node.Extent.StartLineNumber) atribui a `$$($target.VariablePath.UserPath)"
                }
            }

            foreach ($node in (Find-Ast $parsed.Ast { param ($n) $n -is [System.Management.Automation.Language.ParameterAst] })) {
                if ($node.Name.VariablePath.UserPath.ToLowerInvariant() -in $reserved) {
                    "$($parsed.Name):$($node.Extent.StartLineNumber) parâmetro com nome reservado `$$($node.Name.VariablePath.UserPath)"
                }
            }

            foreach ($node in (Find-Ast $parsed.Ast { param ($n) $n -is [System.Management.Automation.Language.ForEachStatementAst] })) {
                if ($node.Variable.VariablePath.UserPath.ToLowerInvariant() -in $reserved) {
                    "$($parsed.Name):$($node.Extent.StartLineNumber) foreach com variável reservada"
                }
            }
        }

        Format-Violations $problems | Should -BeNullOrEmpty
    }
}


Describe "Programas nativos" {
    It "dism, sfc, chkdsk, winget etc. só são chamados por Invoke-WinForgeNative / Invoke-WinForgeCapture" {
        $natives = @(
            "dism", "sfc", "chkdsk", "defrag", "powercfg", "netsh", "ipconfig", "winget", "pnputil", "schtasks", "wmic", "reg",
            "net", "net1", "sc", "taskkill", "tasklist", "bcdedit", "cleanmgr", "vssadmin", "wevtutil", "ping", "nslookup",
            "tracert", "systeminfo", "fsutil", "diskpart", "bitsadmin", "certutil", "robocopy", "xcopy", "cmd", "powershell",
            "pwsh", "msiexec", "gpupdate", "w32tm", "takeown", "icacls", "attrib", "cscript", "wscript", "mshta", "rundll32",
            "explorer", "mountvol", "manage-bde", "lodctr", "esentutl", "wuauclt", "usoclient", "mdsched", "perfmon"
        )

        $problems = foreach ($file in $script:ProductFiles) {
            $parsed = $script:ParsedByPath[$file.FullName]

            foreach ($call in (Get-CommandCalls $parsed)) {
                $name = $call.GetCommandName()
                if (-not $name) { continue }

                $bare = $name.ToLowerInvariant() -replace '\.(exe|com)$', ''
                if ($bare -in $natives -and -not $script:Functions.ContainsKey($bare)) {
                    "$($parsed.Name):$($call.Extent.StartLineNumber) chama '$name' diretamente"
                }
            }
        }

        Format-Violations $problems | Should -BeNullOrEmpty
    }

    It "o operador & com texto fixo (caminho de programa) só aparece em Core.psm1" {
        $problems = foreach ($file in $script:ProductFiles) {
            $parsed = $script:ParsedByPath[$file.FullName]
            if ($file.Name -eq "Core.psm1") { continue }

            foreach ($call in (Get-CommandCalls $parsed)) {
                if ($call.InvocationOperator -ne [System.Management.Automation.Language.TokenKind]::Ampersand) { continue }

                $first = $call.CommandElements[0]
                if ($first -is [System.Management.Automation.Language.StringConstantExpressionAst] -or
                    $first -is [System.Management.Automation.Language.ExpandableStringExpressionAst]) {
                    "$($parsed.Name):$($call.Extent.StartLineNumber) $($call.Extent.Text.Split([char]10)[0].Trim())"
                }
            }
        }

        Format-Violations $problems | Should -BeNullOrEmpty
    }
}


Describe "Chamadas entre funções" {
    It "todo comando com nome WinForge que o código chama está definido" {
        $problems = foreach ($file in $script:ProductFiles) {
            $parsed = $script:ParsedByPath[$file.FullName]

            foreach ($call in (Get-CommandCalls $parsed)) {
                $name = $call.GetCommandName()

                if ($name -and $name -match '^[A-Za-z]+-WinForge' -and -not $script:Functions.ContainsKey($name.ToLowerInvariant())) {
                    "$($parsed.Name):$($call.Extent.StartLineNumber) chama '$name', que não existe"
                }
            }
        }

        Format-Violations $problems | Should -BeNullOrEmpty
    }

    It "as funções chamadas por nome em textos (tabela de navegação, plano, atalhos) existem" {
        $problems = foreach ($file in $script:ProductFiles) {
            $parsed = $script:ParsedByPath[$file.FullName]

            $strings = Find-Ast $parsed.Ast { param ($n) $n -is [System.Management.Automation.Language.StringConstantExpressionAst] }

            foreach ($string in $strings) {
                if ($string.StringConstantType -ne [System.Management.Automation.Language.StringConstantType]::DoubleQuoted -and
                    $string.StringConstantType -ne [System.Management.Automation.Language.StringConstantType]::SingleQuoted) { continue }

                if ($string.Value -match '^(Show|Invoke|Start|Get|Update|Repair|Clear|Export|Open|Install|Set|Test|New|Read|Write|Confirm|Enter|Wait|Stop|Close|Complete|Add|Remove|Restart|Format|Initialize|Resolve|Select|Edit|Use|Save|Restore|Find|ConvertTo|Out)-WinForge[A-Za-z]+$') {
                    if (-not $script:Functions.ContainsKey($string.Value.ToLowerInvariant())) {
                        "$($parsed.Name):$($string.Extent.StartLineNumber) texto '$($string.Value)' parece nome de função, mas ela não existe"
                    }
                }
            }
        }

        Format-Violations $problems | Should -BeNullOrEmpty
    }

    It "os parâmetros nomeados usados nas chamadas existem nas funções do projeto" {
        $problems = foreach ($file in $script:ProductFiles) {
            $parsed = $script:ParsedByPath[$file.FullName]

            foreach ($call in (Get-CommandCalls $parsed)) {
                Get-ParameterProblems -Call $call -Where "$($parsed.Name):$($call.Extent.StartLineNumber)"
            }
        }

        Format-Violations $problems | Should -BeNullOrEmpty
    }

    It "comandos montados em texto (executados pela janela) chamam funções e parâmetros que existem" {
        $problems = foreach ($file in $script:ProductFiles) {
            $parsed = $script:ParsedByPath[$file.FullName]

            $strings = Find-Ast $parsed.Ast {
                param ($n)
                ($n -is [System.Management.Automation.Language.StringConstantExpressionAst]) -or
                ($n -is [System.Management.Automation.Language.ExpandableStringExpressionAst])
            }

            foreach ($string in $strings) {
                $text = [string]$string.Value
                if ($text -notmatch '^\s*[A-Z][a-z]+-WinForge[A-Za-z]+(\s|$)') { continue }

                $where = "$($parsed.Name):$($string.Extent.StartLineNumber) (texto)"
                $inner = [System.Management.Automation.Language.Parser]::ParseInput($text, [ref]$null, [ref]$null)

                foreach ($call in (Get-CommandCalls ([PSCustomObject]@{ Ast = $inner }))) {
                    $name = $call.GetCommandName()

                    if ($name -and -not $script:Functions.ContainsKey($name.ToLowerInvariant()) -and $name -match '-WinForge') {
                        "$where chama '$name', que não existe"
                    }

                    Get-ParameterProblems -Call $call -Where $where
                }
            }
        }

        Format-Violations $problems | Should -BeNullOrEmpty
    }

    It "chamadas fornecem todos os parâmetros obrigatórios (senão o PowerShell perguntaria no terminal)" {
        $problems = foreach ($file in $script:ProductFiles) {
            $parsed = $script:ParsedByPath[$file.FullName]

            foreach ($call in (Get-CommandCalls $parsed)) {
                $name = $call.GetCommandName()
                if (-not $name) { continue }

                $function = $script:Functions[$name.ToLowerInvariant()]
                if ($null -eq $function -or $function.UsesParameterSets) { continue }

                # Chamadas em pipeline (a partir do 2º comando) podem receber o valor pelo pipeline.
                $parent = $call.Parent
                $isDownstream = $false
                if ($parent -is [System.Management.Automation.Language.PipelineAst] -and $parent.PipelineElements.Count -gt 1 -and $parent.PipelineElements[0] -ne $call) { $isDownstream = $true }

                # Chamadas com @splat podem trazer qualquer parâmetro.
                $hasSplat = @($call.CommandElements | Where-Object { $_ -is [System.Management.Automation.Language.VariableExpressionAst] -and $_.Splatted }).Count -gt 0
                if ($hasSplat) { continue }

                $named = @()
                $positional = 0
                $elements = @($call.CommandElements | Select-Object -Skip 1)
                $i = 0

                while ($i -lt $elements.Count) {
                    $element = $elements[$i]

                    if ($element -is [System.Management.Automation.Language.CommandParameterAst]) {
                        $used = $element.ParameterName
                        $match = $function.Parameters | Where-Object { $_.Name -ieq $used -or $_.Aliases -contains $used } | Select-Object -First 1
                        if (-not $match) { $match = $function.Parameters | Where-Object { $_.Name -like "$used*" } | Select-Object -First 1 }

                        if ($match) { $named += $match.Name }

                        if ($null -eq $element.Argument -and $match -and -not $match.IsSwitch) { $i++ }
                    }
                    else {
                        $positional++
                    }

                    $i++
                }

                $remaining = @($function.Parameters | Where-Object { $_.Name -notin $named })
                $withPosition = @($remaining | Where-Object { $_.Position -ge 0 })
                $ordered = if ($withPosition.Count -gt 0) { @($withPosition | Sort-Object Position) } else { @($remaining | Where-Object { -not $_.IsSwitch }) }
                $supplied = @($ordered | Select-Object -First $positional | ForEach-Object { $_.Name })

                foreach ($parameter in $function.Parameters) {
                    if (-not $parameter.Mandatory) { continue }
                    if ($parameter.Name -in $named -or $parameter.Name -in $supplied) { continue }
                    if ($isDownstream -and $parameter.FromPipe) { continue }
                    if ($parameter.FromRemain) { continue }

                    "$($parsed.Name):$($call.Extent.StartLineNumber) $name sem o parâmetro obrigatório -$($parameter.Name)"
                }
            }
        }

        Format-Violations $problems | Should -BeNullOrEmpty
    }

    It "funções com -Embedded também aceitam -PassThru (o plano de manutenção usa os dois)" {
        $problems = foreach ($key in $script:Functions.Keys) {
            $names = @($script:Functions[$key].Parameters | ForEach-Object { $_.Name })

            # Enter/Exit-WinForgeAction só abrem e fecham o cabeçalho da ação; não têm resultado para devolver.
            if ($key -in "enter-winforgeaction", "exit-winforgeaction") { continue }

            if ("Embedded" -in $names -and "PassThru" -notin $names) {
                "$key aceita -Embedded mas não -PassThru"
            }
        }

        Format-Violations $problems | Should -BeNullOrEmpty
    }
}


Describe "Textos" {
    BeforeAll {
        function script:Get-CommandParameterText {
            # Valor de texto de um parâmetro nomeado de uma chamada (-Title "x"), ou $null.
            param ($Call, [string]$Name)

            $elements = @($Call.CommandElements)

            for ($i = 0; $i -lt $elements.Count; $i++) {
                if ($elements[$i] -is [System.Management.Automation.Language.CommandParameterAst] -and $elements[$i].ParameterName -ieq $Name) {
                    $value = if ($null -ne $elements[$i].Argument) { $elements[$i].Argument } elseif ($i + 1 -lt $elements.Count) { $elements[$i + 1] } else { $null }

                    if ($value -is [System.Management.Automation.Language.StringConstantExpressionAst]) { return $value.Value }
                }
            }

            return $null
        }

        # Páginas e itens da tabela de navegação, lidos do código: título da página -> rótulos dos itens.
        $script:NavLabelsByPage = [ordered]@{}
        $navigationParsed = $script:ParsedByPath[(Join-Path $script:Root "modules/Navigation.psm1")]

        foreach ($page in (Find-Ast $navigationParsed.Ast { param ($n) $n -is [System.Management.Automation.Language.CommandAst] -and $n.GetCommandName() -eq "New-WinForgeNavPage" })) {
            $title = Get-CommandParameterText -Call $page -Name "Title"
            $labels = @(
                Find-Ast $page { param ($n) $n -is [System.Management.Automation.Language.CommandAst] -and $n.GetCommandName() -eq "New-WinForgeNavItem" } |
                    ForEach-Object { Get-CommandParameterText -Call $_ -Name "Label" }
            )

            if ($title) { $script:NavLabelsByPage[$title] = $labels }
        }
    }

    It "a tabela de navegação foi lida (páginas e itens)" {
        $script:NavLabelsByPage.Count | Should -BeGreaterThan 8
        ($script:NavLabelsByPage.Values | ForEach-Object { $_.Count } | Measure-Object -Sum).Sum | Should -BeGreaterThan 30
    }

    It "referências 'Página > Item' nas mensagens usam os nomes reais do menu lateral" {
        $problems = foreach ($file in $script:ProductFiles) {
            if ((Get-RelativeName $file.FullName) -eq "modules/Navigation.psm1") { continue }

            $parsed = $script:ParsedByPath[$file.FullName]
            $strings = Find-Ast $parsed.Ast {
                param ($n)
                $n -is [System.Management.Automation.Language.StringConstantExpressionAst] -or $n -is [System.Management.Automation.Language.ExpandableStringExpressionAst]
            }

            foreach ($string in $strings) {
                $value = [string]$string.Value

                # Só frases de uma linha; o resto (código C# embutido, por exemplo) não é texto para a pessoa.
                # (Instruções do próprio Windows, como "clique direito > Executar como administrador", começam em minúscula.)
                if ($value -match "[\r\n]" -or $value -cnotmatch '\b[A-ZÀ-Ý]\p{L}*\)? > [A-ZÀ-Ý]') { continue }

                $found = $false

                foreach ($title in $script:NavLabelsByPage.Keys) {
                    $position = $value.IndexOf("$title > ", [System.StringComparison]::Ordinal)
                    if ($position -lt 0) { continue }

                    $found = $true
                    $rest = $value.Substring($position + $title.Length + 3)
                    $valid = @($script:NavLabelsByPage[$title] | Where-Object { $rest.StartsWith($_, [System.StringComparison]::Ordinal) })

                    if ($valid.Count -eq 0) {
                        "$($parsed.Name):$($string.Extent.StartLineNumber) '$title > ...' não é um item da página: $value"
                    }
                }

                if (-not $found) {
                    "$($parsed.Name):$($string.Extent.StartLineNumber) referência a uma página que não existe no menu lateral: $value"
                }
            }
        }

        Format-Violations $problems | Should -BeNullOrEmpty
    }

    It "os textos da interface dizem 'programas', nunca 'softwares'" {
        $problems = foreach ($file in $script:ProductFiles) {
            $parsed = $script:ParsedByPath[$file.FullName]
            $strings = Find-Ast $parsed.Ast { param ($n) $n -is [System.Management.Automation.Language.StringConstantExpressionAst] -or $n -is [System.Management.Automation.Language.ExpandableStringExpressionAst] }

            foreach ($string in $strings) {
                $value = [string]$string.Value

                # Caminhos do registro (HKLM:\SOFTWARE\...) e identificadores (software.find) não são texto para a pessoa.
                if ($value -match '^HK[A-Z]{2}:' -or $value -match '^[a-z][a-z0-9.-]*$') { continue }

                if ($value -match '(?i)\bsoftwares?\b') {
                    "$($parsed.Name):$($string.Extent.StartLineNumber) usa 'software' em um texto: $value"
                }
            }
        }

        Format-Violations $problems | Should -BeNullOrEmpty
    }
}

Describe "Janela" {
    It "o XAML é um XML bem formado" {
        $xml = New-Object System.Xml.XmlDocument
        { $xml.LoadXml($script:XamlText) } | Should -Not -Throw
    }

    It "os nomes de elementos do XAML são únicos (partes internas de modelos têm escopo próprio)" {
        $duplicated = @($script:XamlNames | Group-Object | Where-Object { $_.Count -gt 1 } | ForEach-Object { $_.Name })

        Format-Violations $duplicated | Should -BeNullOrEmpty
    }

    It "todo FindName() do script da janela existe no XAML" {
        $problems = foreach ($match in [regex]::Matches($script:GuiText, 'FindName\("([^"]+)"\)')) {
            if ($match.Groups[1].Value -notin $script:XamlNames) { "FindName('$($match.Groups[1].Value)') não existe no XAML" }
        }

        Format-Violations $problems | Should -BeNullOrEmpty
    }

    It "todo FindResource() e StaticResource apontam para um estilo declarado" {
        $keys = @([regex]::Matches($script:XamlText, 'x:Key="([^"]+)"') | ForEach-Object { $_.Groups[1].Value })

        $problems = @()
        foreach ($match in [regex]::Matches($script:GuiText, 'FindResource\("([^"]+)"\)')) {
            if ($match.Groups[1].Value -notin $keys) { $problems += "FindResource('$($match.Groups[1].Value)') não existe no XAML" }
        }
        foreach ($match in [regex]::Matches($script:XamlText, '\{(?:Static|Dynamic)Resource\s+([A-Za-z0-9_]+)\}')) {
            if ($match.Groups[1].Value -notin $keys) { $problems += "Recurso '$($match.Groups[1].Value)' não declarado" }
        }

        Format-Violations $problems | Should -BeNullOrEmpty
    }

    It "cada ajuste do Windows é uma chave liga/desliga (ToggleButton com o estilo SwitchToggle), não um botão Aplicar/Desfazer" {
        $script:XamlText | Should -Match 'x:Key="SwitchToggle"\s+TargetType="ToggleButton"'
        $script:GuiText | Should -Match 'System\.Windows\.Controls\.Primitives\.ToggleButton'
        $script:GuiText | Should -Match 'FindResource\("SwitchToggle"\)'
        $script:GuiText | Should -Match 'Get-WinForgeTweakSwitchState'
        $script:GuiText | Should -Not -Match '\$actionText'
    }

    It "o script da janela carrega o XAML da pasta gui" {
        $script:GuiText | Should -Match 'gui'
        $script:GuiText | Should -Match 'MainWindow\.xaml'
    }

    It "todo elemento nomeado do XAML é usado pelo script (sem controles órfãos)" {
        $problems = foreach ($name in $script:XamlNames) {
            if ($script:GuiText -notmatch ('FindName\("' + [regex]::Escape($name) + '"\)')) { "Elemento '$name' não é usado pelo script" }
        }

        Format-Violations $problems | Should -BeNullOrEmpty
    }
}


Describe "Ícone" {
    It "assets/WinForge.ico é um arquivo de ícone válido, com os tamanhos que o Windows usa" {
        $bytes = Get-FileBytes (Join-Path $script:Root "assets/WinForge.ico")

        # ICONDIR: reservado (0), tipo (1 = ícone) e quantidade de imagens; depois uma entrada de 16 bytes por imagem.
        [BitConverter]::ToUInt16($bytes, 0) | Should -Be 0
        [BitConverter]::ToUInt16($bytes, 2) | Should -Be 1

        $count = [BitConverter]::ToUInt16($bytes, 4)
        $count | Should -BeGreaterOrEqual 4

        $sizes = @()
        $problems = @()

        for ($i = 0; $i -lt $count; $i++) {
            $entry = 6 + 16 * $i
            $width = if ($bytes[$entry] -eq 0) { 256 } else { [int]$bytes[$entry] }
            $height = if ($bytes[$entry + 1] -eq 0) { 256 } else { [int]$bytes[$entry + 1] }
            $length = [BitConverter]::ToUInt32($bytes, $entry + 8)
            $offset = [BitConverter]::ToUInt32($bytes, $entry + 12)

            $sizes += $width

            if ($width -ne $height) { $problems += "${width}x${height}: a imagem não é quadrada" }

            if ($offset + $length -gt $bytes.Length) {
                $problems += "${width}px: a imagem passa do fim do arquivo"
                continue
            }

            # Cada imagem é um PNG completo ou um bitmap (cabeçalho BITMAPINFOHEADER de 40 bytes) com altura dobrada (máscara).
            $isPng = ($bytes[$offset] -eq 0x89 -and $bytes[$offset + 1] -eq 0x50 -and $bytes[$offset + 2] -eq 0x4E -and $bytes[$offset + 3] -eq 0x47)
            $isBitmap = ([BitConverter]::ToUInt32($bytes, $offset) -eq 40)

            if (-not ($isPng -or $isBitmap)) { $problems += "${width}px: formato de imagem desconhecido" }

            if ($isBitmap -and [BitConverter]::ToInt32($bytes, $offset + 8) -ne ($height * 2)) {
                $problems += "${width}px: a altura do bitmap deveria ser o dobro (imagem + máscara)"
            }
        }

        foreach ($required in 16, 32, 48, 256) {
            if ($required -notin $sizes) { $problems += "falta o tamanho ${required}px" }
        }

        Format-Violations $problems | Should -BeNullOrEmpty
    }

    It "assets/WinForge.svg é um SVG bem formado e quadrado (a fonte editável do ícone)" {
        $xml = New-Object System.Xml.XmlDocument
        $xml.Load((Join-Path $script:Root "assets/WinForge.svg"))

        $xml.DocumentElement.LocalName | Should -Be "svg"

        $box = @($xml.DocumentElement.GetAttribute("viewBox") -split "\s+")
        $box | Should -HaveCount 4
        $box[2] | Should -Be $box[3]
    }

    It "a janela, o atalho e a barra de tarefas usam o ícone da pasta assets" {
        $launcher = $script:ParsedByPath[(Join-Path $script:Root "modules/Launcher.psm1")].Text
        $launcher | Should -Match '"assets"'
        $launcher | Should -Match 'WinForge\.ico'

        $script:GuiText | Should -Match 'Get-WinForgeIconPath'
        $script:GuiText | Should -Match 'Initialize-WinForgeAppIdentity'
        $script:GuiText | Should -Match 'Set-WinForgeWindowIdentity'
    }
}
