# Limpeza: exclusão segura (sem seguir atalhos de pasta), trava de pastas protegidas, filtro por idade e Downloads.
# Tudo acontece em pastas temporárias criadas pelo teste; nenhuma pasta real do sistema é tocada.

BeforeAll {
    . (Join-Path $PSScriptRoot "TestSetup.ps1")

    $script:Sandbox = Join-Path ([IO.Path]::GetTempPath()) ("winforge-limpeza-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $script:Sandbox -Force | Out-Null

    function script:New-Dir {
        param ([string]$Name)
        $path = Join-Path $script:Sandbox $Name
        New-Item -ItemType Directory -Path $path -Force | Out-Null
        return $path
    }

    function script:New-File {
        param ([string]$Path, [string]$Content = "conteudo", [int]$AgeDays = 0)
        Set-Content -LiteralPath $Path -Value $Content -Encoding UTF8
        if ($AgeDays -gt 0) { (Get-Item -LiteralPath $Path -Force).LastWriteTime = (Get-Date).AddDays(-$AgeDays) }
        return $Path
    }

    function script:New-DirectoryLink {
        # Atalho de pasta: link simbólico (Linux, ou Windows com permissão) ou junção (Windows). $null se não for possível.
        param ([string]$Link, [string]$Target)

        foreach ($type in "SymbolicLink", "Junction") {
            try {
                New-Item -ItemType $type -Path $Link -Target $Target -ErrorAction Stop | Out-Null
                return $Link
            }
            catch { }
        }

        return $null
    }

    function script:Set-ModuleStub {
        # Substitui uma função DENTRO do módulo (para as chamadas entre funções do mesmo módulo, que o Set-TestStub
        # global não alcança). Clear-ModuleStubs recarrega os módulos.
        param ([string]$Module, [string]$Name, [scriptblock]$Body)

        $script:ModuleStubbed = $true
        & (Get-Module $Module) { param ($n, $b) Set-Item -Path "Function:\script:$n" -Value $b } $Name $Body
    }

    function script:Clear-ModuleStubs {
        if ($script:ModuleStubbed) {
            Import-AllWinForgeModules
            $script:ModuleStubbed = $false
        }
    }

    function script:Set-ProtectedEnvironment {
        # Ambiente fictício do "Windows" dentro da pasta de teste.
        $script:SavedEnv = @{
            USERPROFILE = $env:USERPROFILE; WINDIR = $env:WINDIR; ProgramFiles = $env:ProgramFiles
            ProgramData = $env:ProgramData; SystemDrive = $env:SystemDrive; TEMP = $env:TEMP
        }

        $env:USERPROFILE = Join-Path $script:Sandbox "Users/ana"
        $env:WINDIR = Join-Path $script:Sandbox "Windows"
        $env:ProgramFiles = Join-Path $script:Sandbox "Program Files"
        $env:ProgramData = Join-Path $script:Sandbox "ProgramData"
        $env:SystemDrive = $null
    }

    function script:Restore-ProtectedEnvironment {
        foreach ($name in $script:SavedEnv.Keys) {
            Set-Item -LiteralPath "Env:$name" -Value $script:SavedEnv[$name] -ErrorAction SilentlyContinue
            if ($null -eq $script:SavedEnv[$name]) { Remove-Item -LiteralPath "Env:$name" -ErrorAction SilentlyContinue }
        }
    }
}

AfterAll {
    Clear-ModuleStubs
    if (Test-Path -LiteralPath $script:Sandbox) { Remove-Item -LiteralPath $script:Sandbox -Recurse -Force -ErrorAction SilentlyContinue }
    Remove-Variable WfReg, WfMoved, WfParts, WfPartKinds, WfPartBytes, WfBinCount, WfClearError, WfBinCalls, WfFailName -Scope Global -ErrorAction SilentlyContinue
    Remove-WinForgeTestData
}

Describe "Remove-WinForgeItem" {
    It "remove arquivo comum e arquivo somente leitura" {
        $file = New-File (Join-Path (New-Dir "remover-arquivos") "a.txt")
        $readOnly = New-File (Join-Path (New-Dir "remover-arquivos") "b.txt")
        (Get-Item -LiteralPath $readOnly).IsReadOnly = $true

        Remove-WinForgeItem -Path $file
        Remove-WinForgeItem -Path $readOnly

        Test-Path -LiteralPath $file | Should -BeFalse
        Test-Path -LiteralPath $readOnly | Should -BeFalse
    }

    It "remove uma árvore de pastas com itens aninhados e ocultos" {
        $root = New-Dir "arvore"
        $deep = New-Dir "arvore/a/b/c"
        [void](New-File (Join-Path $deep "x.txt"))
        [void](New-File (Join-Path $root "a/y.txt"))
        [void](New-File (Join-Path $root ".oculto"))

        Remove-WinForgeItem -Path $root

        Test-Path -LiteralPath $root | Should -BeFalse
    }

    It "nomes com colchetes, espaços, acentos e aspas são tratados como texto literal" {
        $dir = New-Dir "nomes-estranhos"
        $names = @("a[1].txt", "com espaço.txt", "ação é ñ.txt", "it's.txt", "[abc]", "x`$y.txt")
        $paths = @()

        foreach ($name in $names) {
            $path = Join-Path $dir $name
            if ($name -eq "[abc]") { New-Item -ItemType Directory -Path $path | Out-Null } else { [void](New-File $path) }
            $paths += $path
        }

        foreach ($path in $paths) { Remove-WinForgeItem -Path $path }

        foreach ($path in $paths) { Test-Path -LiteralPath $path | Should -BeFalse }
    }

    It "um atalho de pasta é removido como atalho, sem apagar o conteúdo de destino" {
        $outside = New-Dir "fora-do-alvo"
        $precious = New-File (Join-Path $outside "precioso.txt") "não apague"
        $victim = New-Dir "limpar-com-atalho"
        $link = New-DirectoryLink -Link (Join-Path $victim "atalho") -Target $outside

        if ($null -eq $link) { return }   # sem permissão para criar atalhos neste ambiente

        Remove-WinForgeItem -Path $victim

        Test-Path -LiteralPath $victim | Should -BeFalse
        Test-Path -LiteralPath $precious | Should -BeTrue
    }

    It "caminho inexistente lança erro" {
        { Remove-WinForgeItem -Path (Join-Path $script:Sandbox "nao-existe") } | Should -Throw
    }
}

Describe "Esvaziar uma pasta" {
    It "esvazia mantendo a pasta e informa o balanço" {
        $dir = New-Dir "esvaziar"
        [void](New-File (Join-Path $dir "um.txt") ("x" * 1000))
        [void](New-File (Join-Path $dir "dois.txt") ("y" * 2000))
        [void](New-Dir "esvaziar/sub")
        [void](New-File (Join-Path $dir "sub/tres.txt") ("z" * 3000))

        $outcome = Clear-WinForgeFolderContents -Path $dir -Activity "teste"

        Test-Path -LiteralPath $dir | Should -BeTrue
        @(Get-ChildItem -LiteralPath $dir -Force) | Should -HaveCount 0
        $outcome.Removed | Should -Be 3
        $outcome.Skipped | Should -Be 0
        $outcome.Remaining | Should -Be 0
        $outcome.Freed | Should -BeGreaterThan 5000
    }

    It "não segue atalhos de pasta para fora" {
        $outside = New-Dir "fora-esvaziar"
        $precious = New-File (Join-Path $outside "precioso.txt")
        $dir = New-Dir "esvaziar-com-atalho"
        $link = New-DirectoryLink -Link (Join-Path $dir "atalho") -Target $outside

        if ($null -eq $link) { return }

        [void](Clear-WinForgeFolderContents -Path $dir -Activity "teste")

        Test-Path -LiteralPath $precious | Should -BeTrue
        @(Get-ChildItem -LiteralPath $dir -Force) | Should -HaveCount 0
    }

    It "pasta vazia: balanço zerado" {
        $outcome = Clear-WinForgeFolderContents -Path (New-Dir "ja-vazia") -Activity "teste"
        $outcome.Removed | Should -Be 0
        $outcome.Freed | Should -Be 0
    }
}

Describe "Trava de segurança das limpezas" {
    It "aceita as pastas de temporários e recusa raízes e pastas protegidas" {
        Set-ProtectedEnvironment
        try {
            $safe = @(
                (Join-Path $env:USERPROFILE "AppData/Local/Temp"),
                (Join-Path $env:WINDIR "Temp"),
                (Join-Path $script:Sandbox "Temp"),
                (Join-Path $script:Sandbox "Temp/")
            )

            foreach ($path in $safe) { Test-WinForgeCleanupTargetSafe -Path $path | Should -BeTrue }

            $unsafe = @(
                [IO.Path]::GetPathRoot($script:Sandbox),                  # raiz do disco
                $env:USERPROFILE,                                         # o próprio perfil
                ($env:USERPROFILE + [IO.Path]::DirectorySeparatorChar),   # perfil com barra final
                (Join-Path $script:Sandbox "Users"),                      # pasta que contém o perfil
                $script:Sandbox,                                          # ancestral de tudo
                $env:WINDIR,
                $env:ProgramFiles,
                $env:ProgramData,
                (Join-Path $env:USERPROFILE "Temp/..")                    # volta ao perfil
            )

            foreach ($path in $unsafe) { Test-WinForgeCleanupTargetSafe -Path $path | Should -BeFalse }

            # Maiúsculas/minúsculas diferentes continuam recusadas (Windows não diferencia).
            Test-WinForgeCleanupTargetSafe -Path $env:USERPROFILE.ToUpperInvariant() | Should -BeFalse
        }
        finally { Restore-ProtectedEnvironment }
    }

    It "recusa vazio, espaços e nulo" -ForEach @(@{ Path = "" }, @{ Path = "   " }, @{ Path = $null }) {
        Test-WinForgeCleanupTargetSafe -Path $Path | Should -BeFalse
    }

    It "a limpeza recusa a pasta protegida e não apaga nada" {
        Set-ProtectedEnvironment
        try {
            $profileDir = $env:USERPROFILE
            New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
            $documents = New-File (Join-Path $profileDir "importante.docx")

            $result = Invoke-WinForgeFolderCleanup -Title "Teste" -Path $profileDir -Embedded -PassThru

            $result.Kind | Should -Be "Failed"
            $result.Status | Should -Match "recusada"
            Test-Path -LiteralPath $documents | Should -BeTrue
        }
        finally { Restore-ProtectedEnvironment }
    }

    It "a limpeza de temporários do usuário recusa TEMP apontando para o perfil" {
        Set-ProtectedEnvironment
        try {
            New-Item -ItemType Directory -Path $env:USERPROFILE -Force | Out-Null
            $keep = New-File (Join-Path $env:USERPROFILE "foto.jpg")
            $env:TEMP = $env:USERPROFILE

            $result = Clear-WinForgeUserTemp -Embedded -PassThru

            $result.Kind | Should -Be "Failed"
            Test-Path -LiteralPath $keep | Should -BeTrue
        }
        finally { Restore-ProtectedEnvironment }
    }
}

Describe "Limpeza de uma pasta de temporários" {
    It "remove o conteúdo, informa o espaço e devolve Ok" {
        $dir = New-Dir "temp-ok"
        [void](New-File (Join-Path $dir "a.tmp") ("x" * 5000))
        [void](New-File (Join-Path (New-Dir "temp-ok/sub") "b.tmp") ("y" * 5000))

        $result = Invoke-WinForgeFolderCleanup -Title "Teste" -Path $dir -Embedded -PassThru

        $result.Kind | Should -Be "Ok"
        $result.Status | Should -Match "liberou"
        @(Get-ChildItem -LiteralPath $dir -Force) | Should -HaveCount 0
    }

    It "o resultado traz o espaço liberado como número (para a Limpeza rápida somar), sem depender do texto" {
        $dir = New-Dir "temp-bytes"
        [void](New-File (Join-Path $dir "a.tmp") ("x" * 4000))

        $result = Invoke-WinForgeFolderCleanup -Title "Teste" -Path $dir -Embedded -PassThru

        (Get-WinForgeResultData -Result $result -Name "FreedBytes") | Should -BeGreaterThan 0
        (Get-WinForgeResultData -Result $result -Name "FreedBytes") | Should -BeOfType ([int64])
    }

    It "no console o título abre a tela; dentro da janela ele não se repete" {
        $dir = New-Dir "temp-titulo"

        try {
            Set-FakeReadHost -Answers @("")   # "pressione uma tecla" do final
            (Get-HostText { [void](Invoke-WinForgeFolderCleanup -Title "Limpar temporários do usuário" -Path $dir -PassThru) }) | Should -Match "Limpar temporários do usuário"

            $global:WinForgeGuiMode = $true
            Set-FakeReadHost -Answers @("")
            (Get-HostText { [void](Invoke-WinForgeFolderCleanup -Title "Limpar temporários do usuário" -Path $dir -PassThru) }) | Should -Not -Match "Limpar temporários do usuário"
        }
        finally {
            Remove-Variable WinForgeGuiMode -Scope Global -ErrorAction SilentlyContinue
            Clear-FakeReadHost
        }
    }

    It "pasta inexistente é 'Ignorado'; pasta vazia é Ok sem trabalho" {
        (Invoke-WinForgeFolderCleanup -Title "Teste" -Path (Join-Path $script:Sandbox "nao-existe-mesmo") -Embedded -PassThru).Kind | Should -Be "Skipped"

        $result = Invoke-WinForgeFolderCleanup -Title "Teste" -Path (New-Dir "temp-vazia") -Embedded -PassThru
        $result.Kind | Should -Be "Ok"
        $result.Status | Should -Match "nada a limpar"
    }

    It "fora da Manutenção, recusar a pergunta não apaga nada" {
        $dir = New-Dir "temp-recusa"
        $file = New-File (Join-Path $dir "a.tmp")

        try {
            Set-FakeReadHost -Answers @("n", "")
            $result = Invoke-WinForgeFolderCleanup -Title "Teste" -Path $dir -PassThru

            $result.Kind | Should -Be "Skipped"
            Test-Path -LiteralPath $file | Should -BeTrue
        }
        finally { Clear-FakeReadHost }
    }

    It "a pasta de temporários do usuário vem de TEMP, ou de LOCALAPPDATA quando TEMP não existe" {
        $savedTemp = $env:TEMP

        try {
            $env:TEMP = Join-Path $script:Sandbox "meu-temp"
            Get-WinForgeUserTempPath | Should -Be $env:TEMP

            $env:TEMP = ""
            Get-WinForgeUserTempPath | Should -Be (Join-Path $env:LOCALAPPDATA "Temp")
        }
        finally { $env:TEMP = $savedTemp }
    }

    It "a pasta Temp do Windows vem de WINDIR, ou de SystemRoot quando WINDIR não existe" {
        $savedWindir = $env:WINDIR
        $savedRoot = $env:SystemRoot

        try {
            $env:WINDIR = Join-Path $script:Sandbox "win-a"
            $env:SystemRoot = Join-Path $script:Sandbox "win-b"
            Get-WinForgeWindowsTempPath | Should -Be (Join-Path $env:WINDIR "Temp")

            $env:WINDIR = ""
            Get-WinForgeWindowsTempPath | Should -Be (Join-Path $env:SystemRoot "Temp")

            $env:SystemRoot = ""
            Get-WinForgeWindowsTempPath | Should -Be ""
        }
        finally {
            $env:WINDIR = $savedWindir
            $env:SystemRoot = $savedRoot
        }
    }

    It "sem as variáveis que localizam a pasta, a limpeza explica e falha em vez de lançar erro" {
        $savedWindir = $env:WINDIR
        $savedRoot = $env:SystemRoot
        $savedTemp = $env:TEMP
        $savedLocal = $env:LOCALAPPDATA

        try {
            $env:WINDIR = ""
            $env:SystemRoot = ""
            $env:TEMP = ""
            $env:LOCALAPPDATA = ""

            Get-WinForgeUserTempPath | Should -Be ""

            $text = Get-HostText {
                $script:Windows = Clear-WinForgeWindowsTemp -PassThru
                $script:User = Clear-WinForgeUserTemp -PassThru
            }

            $script:Windows.Kind | Should -Be "Failed"
            $script:User.Kind | Should -Be "Failed"
            $script:User.Detail | Should -Match "não localizada"
            $text | Should -Match "não está definida"
        }
        finally {
            $env:WINDIR = $savedWindir
            $env:SystemRoot = $savedRoot
            $env:TEMP = $savedTemp
            $env:LOCALAPPDATA = $savedLocal
        }
    }
}

Describe "Filtro por idade" {
    It "seleciona só o que é mais antigo que o corte; o limite exato fica de fora" {
        $now = Get-Date
        $entries = @(
            [PSCustomObject]@{ Name = "antigo.zip"; LastActivity = $now.AddDays(-90) },
            [PSCustomObject]@{ Name = "novo.pdf"; LastActivity = $now.AddDays(-2) },
            [PSCustomObject]@{ Name = "limite.txt"; LastActivity = $now.AddDays(-30) }
        )

        $selected = @(Select-WinForgeItemsOlderThan -Entries $entries -Cutoff $now.AddDays(-30))

        $selected | Should -HaveCount 1
        $selected[0].Name | Should -Be "antigo.zip"
    }

    It "sem itens ou com lista nula: vazio" {
        @(Select-WinForgeItemsOlderThan -Entries @() -Cutoff (Get-Date)) | Should -HaveCount 0
        @(Select-WinForgeItemsOlderThan -Entries $null -Cutoff (Get-Date)) | Should -HaveCount 0
    }

    It "lê os dias digitados: <Typed> -> <Expected>" -ForEach @(
        @{ Typed = ""; Expected = 30 },
        @{ Typed = "   "; Expected = 30 },
        @{ Typed = "15"; Expected = 15 },
        @{ Typed = " 7 "; Expected = 7 },
        @{ Typed = "1"; Expected = 1 },
        @{ Typed = "99999"; Expected = 99999 },
        @{ Typed = "0"; Expected = $null },
        @{ Typed = "-5"; Expected = $null },
        @{ Typed = "abc"; Expected = $null },
        @{ Typed = "10 dias"; Expected = $null },
        @{ Typed = "1,5"; Expected = $null },
        @{ Typed = "100000"; Expected = $null },
        @{ Typed = ([string][char]0x0663 + [char]0x0665); Expected = $null }   # dígitos árabe-índicos: \d aceitaria
    ) {
        try {
            Set-FakeReadHost -Answers @($Typed)
            $days = Read-WinForgeDaysThreshold
            if ($null -eq $Expected) { $days | Should -BeNullOrEmpty } else { $days | Should -Be $Expected }
        }
        finally { Clear-FakeReadHost }
    }
}

Describe "Lixeira" {
    It "reconhece a mensagem de 'Lixeira já vazia' em inglês e português" -ForEach @(
        @{ Message = "Cannot find the file specified" },
        @{ Message = "The system cannot find the path specified" },
        @{ Message = "O sistema não pode encontrar o arquivo especificado." },
        @{ Message = "Não foi possível localizar o caminho especificado" }
    ) {
        Test-WinForgeRecycleBinEmptyError -Message $Message | Should -BeTrue
    }

    It "outras mensagens são erro de verdade" -ForEach @(
        @{ Message = "Acesso negado" }, @{ Message = "" }, @{ Message = $null }
    ) {
        Test-WinForgeRecycleBinEmptyError -Message $Message | Should -BeFalse
    }
}

Describe "Esvaziar a Lixeira" {
    BeforeEach {
        $global:WfBinCalls = New-Object System.Collections.ArrayList
        $global:WfBinCount = 3
        $global:WfClearError = $null

        Set-ModuleStub -Module Cleanup -Name "Get-WinForgeRecycleBinItemCount" -Body { $global:WfBinCount }
        Set-TestStub -Name "Clear-RecycleBin" -Body {
            [CmdletBinding()] param ([switch]$Force)
            [void]$global:WfBinCalls.Add("limpou")
            if ($null -ne $global:WfClearError) { throw $global:WfClearError }
        }
    }

    AfterEach {
        Clear-ModuleStubs
        Clear-TestStubs
        Clear-FakeReadHost
    }

    It "já vazia: não pergunta nada nem chama o Windows" {
        $global:WfBinCount = 0

        $result = Clear-WinForgeRecycleBin -Embedded -PassThru

        $result.Kind | Should -Be "Ok"
        $result.Status | Should -Match "já estava vazia"
        $global:WfBinCalls | Should -HaveCount 0
    }

    It "pergunta antes (resposta padrão: Não) e recusar não esvazia" {
        Set-FakeReadHost -Answers @("", "")

        $text = Get-HostText { $script:Result = Clear-WinForgeRecycleBin -PassThru }

        $script:Result.Kind | Should -Be "Skipped"
        $text | Should -Match "permanentemente"
        $text | Should -Match "Itens na Lixeira"
        $global:WfBinCalls | Should -HaveCount 0
    }

    It "confirmando, esvazia" {
        Set-FakeReadHost -Answers @("s", "")

        $text = Get-HostText { $script:Result = Clear-WinForgeRecycleBin -PassThru }

        $script:Result.Kind | Should -Be "Ok"
        $text | Should -Match "Lixeira esvaziada"
        $global:WfBinCalls | Should -HaveCount 1
    }

    It "dentro da Manutenção a decisão já foi tomada: não pergunta" {
        $result = Clear-WinForgeRecycleBin -Embedded -PassThru

        $result.Kind | Should -Be "Ok"
        $global:WfBinCalls | Should -HaveCount 1
    }

    It "o Windows dizendo que não há o que apagar conta como Lixeira vazia, não como erro" {
        $global:WfClearError = "Cannot find the file specified"

        $result = Clear-WinForgeRecycleBin -Embedded -PassThru

        $result.Kind | Should -Be "Ok"
        $result.Status | Should -Match "já estava vazia"
    }

    It "um erro de verdade (acesso negado) vira Falhou com o motivo" {
        $global:WfClearError = "Acesso negado"

        $result = Clear-WinForgeRecycleBin -Embedded -PassThru

        $result.Kind | Should -Be "Failed"
        $result.Status | Should -Match "Acesso negado"
    }

    It "sem saber quantos itens há, segue sem mostrar a contagem" {
        $global:WfBinCount = $null

        $text = Get-HostText { $script:Result = Clear-WinForgeRecycleBin -Embedded -PassThru }

        $script:Result.Kind | Should -Be "Ok"
        $text | Should -Not -Match "Itens na Lixeira"
        $global:WfBinCalls | Should -HaveCount 1
    }
}

Describe "Limpeza rápida" {
    BeforeEach {
        $global:WfParts = New-Object System.Collections.ArrayList
        $global:WfPartKinds = @{ user = "Ok"; windows = "Ok"; bin = "Ok" }
        $global:WfPartBytes = @{ user = 3MB; windows = 1MB; bin = 0 }

        Set-ModuleStub -Module Cleanup -Name "Clear-WinForgeUserTemp" -Body {
            param ([switch]$Embedded, [switch]$PassThru)
            [void]$global:WfParts.Add("user")
            New-WinForgeResult -Kind $global:WfPartKinds.user -Data @{ FreedBytes = [int64]$global:WfPartBytes.user }
        }
        Set-ModuleStub -Module Cleanup -Name "Clear-WinForgeWindowsTemp" -Body {
            param ([switch]$Embedded, [switch]$PassThru)
            [void]$global:WfParts.Add("windows")
            New-WinForgeResult -Kind $global:WfPartKinds.windows -Data @{ FreedBytes = [int64]$global:WfPartBytes.windows }
        }
        Set-ModuleStub -Module Cleanup -Name "Clear-WinForgeRecycleBin" -Body {
            param ([switch]$Embedded, [switch]$PassThru)
            [void]$global:WfParts.Add("bin")
            New-WinForgeResult -Kind $global:WfPartKinds.bin
        }
    }

    AfterEach {
        Clear-ModuleStubs
        Clear-FakeReadHost
        Remove-Variable WfPartKinds, WfPartBytes -Scope Global -ErrorAction SilentlyContinue
    }

    It "executa temporários do usuário, temporários do Windows e Lixeira, nesta ordem, e soma o espaço liberado" {
        $text = Get-HostText { $script:Result = Invoke-WinForgeQuickCleanup -Embedded -PassThru }

        (@($global:WfParts) -join ",") | Should -Be "user,windows,bin"
        $script:Result.Kind | Should -Be "Ok"
        (Get-WinForgeResultData -Result $script:Result -Name "FreedBytes") | Should -Be 4MB
        $text | Should -Match "Resumo"
        $text | Should -Match "Espaço liberado"
        $text | Should -Match "4 MB"
        $text | Should -Match "Lixeira não entra na conta"
    }

    It "uma parte que falha vira Atenção, e o espaço das outras continua somado" {
        $global:WfPartKinds.windows = "Failed"

        $result = Invoke-WinForgeQuickCleanup -Embedded -PassThru

        $result.Kind | Should -Be "Warning"
        $result.Status | Should -Match "1 de 3 partes falharam"
        (Get-WinForgeResultData -Result $result -Name "FreedBytes") | Should -Be 4MB
    }

    It "todas as partes falhando é Falhou" {
        $global:WfPartKinds = @{ user = "Failed"; windows = "Failed"; bin = "Failed" }

        $result = Invoke-WinForgeQuickCleanup -Embedded -PassThru

        $result.Kind | Should -Be "Failed"
        $result.Status | Should -Match "todas as partes falharam"
    }

    It "partes ignoradas (pasta inexistente) não são falha" {
        $global:WfPartKinds = @{ user = "Skipped"; windows = "Skipped"; bin = "Ok" }
        $global:WfPartBytes = @{ user = 0; windows = 0; bin = 0 }

        $result = Invoke-WinForgeQuickCleanup -Embedded -PassThru

        $result.Kind | Should -Be "Ok"
        (Get-WinForgeResultData -Result $result -Name "FreedBytes") | Should -Be 0
    }

    It "sozinha, pergunta antes: recusar não executa parte alguma" {
        Set-FakeReadHost -Answers @("n", "")

        $text = Get-HostText { $script:Result = Invoke-WinForgeQuickCleanup -PassThru }

        $script:Result.Kind | Should -Be "Skipped"
        $global:WfParts | Should -HaveCount 0
        $text | Should -Match "Documentos, Downloads e outros arquivos pessoais não são tocados"
    }

    It "sozinha, ENTER aceita o padrão (Sim) e executa" {
        Set-FakeReadHost -Answers @("", "")

        [void](Get-HostText { $script:Result = Invoke-WinForgeQuickCleanup -PassThru })

        $script:Result.Kind | Should -Be "Ok"
        $global:WfParts | Should -HaveCount 3
    }

    It "um erro inesperado numa das partes vira Falhou com a mensagem, sem derrubar a tela" {
        Set-ModuleStub -Module Cleanup -Name "Clear-WinForgeWindowsTemp" -Body {
            param ([switch]$Embedded, [switch]$PassThru)
            throw "disco desapareceu"
        }

        $result = Invoke-WinForgeQuickCleanup -Embedded -PassThru

        $result.Kind | Should -Be "Failed"
        $result.Status | Should -Match "disco desapareceu"
    }
}

Describe "Pasta Downloads: destino dos itens" {
    BeforeEach {
        $global:WfMoved = New-Object System.Collections.ArrayList
        $global:WfFailName = $null
        $script:Dir = New-Dir ("downloads-destino-" + [guid]::NewGuid().ToString("N").Substring(0, 6))
        $script:Old = New-File (Join-Path $script:Dir "antigo.zip") "x" -AgeDays 90
        $script:Old2 = New-File (Join-Path $script:Dir "antigo2.zip") "x" -AgeDays 60
        $script:Recent = New-File (Join-Path $script:Dir "novo.pdf") "x" -AgeDays 1

        $global:WfDownloads = $script:Dir
        Set-TestStub -Name "Get-WinForgeRegistryValueOrNull" -Body { $global:WfDownloads }

        # A Lixeira de verdade não existe aqui: o item é apagado e o caminho registrado.
        Set-ModuleStub -Module Cleanup -Name "Move-WinForgeItemToRecycleBin" -Body {
            param ([string]$Path, [switch]$IsDirectory)
            if ($global:WfFailName -and $Path -like "*$($global:WfFailName)") { throw "em uso" }
            [void]$global:WfMoved.Add((Split-Path -Leaf $Path))
            Remove-Item -LiteralPath $Path -Force
        }
    }

    AfterEach {
        Clear-ModuleStubs
        Clear-TestStubs
        Clear-FakeReadHost
        Remove-Variable WfDownloads -Scope Global -ErrorAction SilentlyContinue
    }

    It "para a Lixeira: não fala em espaço liberado, explica que o espaço só volta ao esvaziar e usa o nome da tela" {
        # 1 = mais antigos que N dias | 30 | L = Lixeira | ENTER final
        Set-FakeReadHost -Answers @("1", "30", "L", "")

        $text = Get-HostText { Clear-WinForgeDownloads }

        $text | Should -Match "Itens enviados à Lixeira"
        $text | Should -Match "Tamanho na Lixeira"
        $text | Should -Match "Esvaziar a Lixeira"
        $text | Should -Not -Match "Espaço liberado"
        (@($global:WfMoved) | Sort-Object) -join "," | Should -Be "antigo.zip,antigo2.zip"
        Test-Path -LiteralPath $script:Recent | Should -BeTrue
    }

    It "a dica cita a página e o item de menu que esvaziam a Lixeira, com os nomes da tabela de navegação" {
        $page = Get-WinForgeNavPage -Id "cleanup"
        $item = Get-WinForgeNavItem -Id "cleanup.recycle-bin"
        Set-FakeReadHost -Answers @("1", "30", "L", "")

        $text = Get-HostText { Clear-WinForgeDownloads }

        $text | Should -Match ([regex]::Escape("$($page.Title) > $($item.Label)"))
    }

    It "para a Lixeira, um item que falha é contado como ignorado e avisa" {
        $global:WfFailName = "antigo2.zip"
        Set-FakeReadHost -Answers @("1", "30", "L", "")

        $text = Get-HostText { Clear-WinForgeDownloads }

        $text | Should -Match "Itens ignorados\s+:\s+1"
        $text | Should -Match "Alguns itens estavam em uso"
        Test-Path -LiteralPath $script:Old2 | Should -BeTrue
        Test-Path -LiteralPath $script:Old | Should -BeFalse
    }

    It "tudo para a Lixeira leva também o que é recente" {
        Set-FakeReadHost -Answers @("2", "L", "")

        [void](Get-HostText { Clear-WinForgeDownloads })

        Test-Path -LiteralPath $script:Recent | Should -BeFalse
        $global:WfMoved | Should -HaveCount 3
    }

    It "nada mais antigo que o corte: avisa e não pergunta o destino" {
        Set-FakeReadHost -Answers @("1", "365", "")

        $text = Get-HostText { Clear-WinForgeDownloads }

        $text | Should -Match "Nenhum item corresponde ao critério"
        $global:WfMoved | Should -HaveCount 0
        Test-Path -LiteralPath $script:Old | Should -BeTrue
    }

    It "elevado com outra conta: avisa de quem é a pasta" {
        Set-TestStub -Name "Test-WinForgeUserContextMismatch" -Body { $true }
        Set-FakeReadHost -Answers @("0", "")

        (Get-HostText { Clear-WinForgeDownloads }) | Should -Match "Elevado com outra conta"
    }

    It "a prévia mostra os itens a remover e o total antes de pedir o destino" {
        Set-FakeReadHost -Answers @("1", "30", "0", "")

        $text = Get-HostText { Clear-WinForgeDownloads }

        $text | Should -Match "antigo.zip"
        $text | Should -Match "Itens selecionados\s+:\s+2"
        $text | Should -Match "Espaço a liberar"
        $text | Should -Match "Limpeza cancelada"
        $global:WfMoved | Should -HaveCount 0
    }
}

Describe "Pasta Downloads" {
    It "usa o caminho redirecionado do Registro (expandindo variáveis) ou o padrão do perfil" {
        $env:WF_TESTE_DISCO = $script:Sandbox
        Set-TestStub -Name "Get-WinForgeRegistryValueOrNull" -Body { "%WF_TESTE_DISCO%\Baixados" }
        try { Get-WinForgeDownloadsPath | Should -Be ($script:Sandbox + "\Baixados") }
        finally {
            Clear-TestStubs
            Remove-Item Env:WF_TESTE_DISCO -ErrorAction SilentlyContinue
        }

        $savedProfile = $env:USERPROFILE
        Set-TestStub -Name "Get-WinForgeRegistryValueOrNull" -Body { $null }
        try {
            $env:USERPROFILE = Join-Path $script:Sandbox "perfil"
            Get-WinForgeDownloadsPath | Should -Be (Join-Path $env:USERPROFILE "Downloads")

            # Sem a variável do perfil, usa a pasta do perfil informada pelo .NET em vez de falhar.
            $env:USERPROFILE = $null
            { Get-WinForgeDownloadsPath } | Should -Not -Throw
            Get-WinForgeDownloadsPath | Should -Match "Downloads$"
        }
        finally {
            Clear-TestStubs
            $env:USERPROFILE = $savedProfile
        }
    }

    It "ignora desktop.ini e Thumbs.db, mas não uma pasta com esse nome" {
        $dir = New-Dir "downloads-meta"
        [void](New-File (Join-Path $dir "desktop.ini"))
        [void](New-File (Join-Path $dir "Thumbs.db"))
        [void](New-File (Join-Path $dir "arquivo.zip"))
        [void](New-Dir "downloads-meta/desktop.ini.d")

        $names = @(Get-WinForgeDownloadsItems -Path $dir | ForEach-Object { $_.Name })

        $names | Should -Contain "arquivo.zip"
        $names | Should -Contain "desktop.ini.d"
        $names | Should -Not -Contain "desktop.ini"
        $names | Should -Not -Contain "Thumbs.db"
    }

    It "remove só o que é mais antigo que N dias, inclusive pastas antigas, e preserva pasta antiga com arquivo novo dentro" {
        $dir = New-Dir "downloads-fluxo"
        $oldFile = New-File (Join-Path $dir "antigo.zip") "x" -AgeDays 90
        $newFile = New-File (Join-Path $dir "novo.pdf") "x" -AgeDays 2
        $meta = New-File (Join-Path $dir "desktop.ini") "x" -AgeDays 400

        $oldDir = New-Dir "downloads-fluxo/pasta-antiga"
        [void](New-File (Join-Path $oldDir "a.txt") "x" -AgeDays 90)
        (Get-Item -LiteralPath $oldDir).LastWriteTime = (Get-Date).AddDays(-90)

        $mixedDir = New-Dir "downloads-fluxo/pasta-mista"
        [void](New-File (Join-Path $mixedDir "velho.txt") "x" -AgeDays 90)
        [void](New-File (Join-Path $mixedDir "recente.txt") "x" -AgeDays 1)
        (Get-Item -LiteralPath $mixedDir).LastWriteTime = (Get-Date).AddDays(-90)

        $global:WfDownloads = $dir
        Set-TestStub -Name "Get-WinForgeRegistryValueOrNull" -Body { $global:WfDownloads }

        try {
            # 1 = mais antigos que N dias | 30 | P = permanente | S = confirma | ENTER = pressionar uma tecla
            Set-FakeReadHost -Answers @("1", "30", "P", "S", "")
            $text = Get-HostText { Clear-WinForgeDownloads }

            $text | Should -Match "Itens selecionados"
            $text | Should -Match "Itens excluídos"
            $text | Should -Match "Espaço liberado"
            $text | Should -Not -Match "Tamanho na Lixeira"
            Test-Path -LiteralPath $oldFile | Should -BeFalse
            Test-Path -LiteralPath $oldDir | Should -BeFalse
            Test-Path -LiteralPath $newFile | Should -BeTrue
            Test-Path -LiteralPath $mixedDir | Should -BeTrue
            Test-Path -LiteralPath $meta | Should -BeTrue
        }
        finally {
            Clear-FakeReadHost
            Clear-TestStubs
            Remove-Variable WfDownloads -Scope Global -ErrorAction SilentlyContinue
        }
    }

    It "cancelar <Name> não apaga nada" -ForEach @(
        @{ Name = "no modo"; Answers = @("0", ""); Expected = "Limpeza cancelada" },
        @{ Name = "no destino"; Answers = @("2", "0", ""); Expected = "Limpeza cancelada" },
        @{ Name = "na confirmação da exclusão permanente"; Answers = @("2", "P", "N", ""); Expected = "Limpeza cancelada" },
        @{ Name = "com dias inválidos"; Answers = @("1", "abc", ""); Expected = "Valor inválido" }
    ) {
        $dir = New-Dir ("downloads-cancela-" + [guid]::NewGuid().ToString("N").Substring(0, 6))
        $file = New-File (Join-Path $dir "antigo.zip") "x" -AgeDays 90

        $global:WfDownloads = $dir
        Set-TestStub -Name "Get-WinForgeRegistryValueOrNull" -Body { $global:WfDownloads }

        try {
            Set-FakeReadHost -Answers $Answers
            $text = Get-HostText { Clear-WinForgeDownloads }

            $text | Should -Match $Expected
            Test-Path -LiteralPath $file | Should -BeTrue
        }
        finally {
            Clear-FakeReadHost
            Clear-TestStubs
            Remove-Variable WfDownloads -Scope Global -ErrorAction SilentlyContinue
        }
    }

    It "pasta Downloads inexistente ou vazia termina com mensagem, sem erro" {
        $global:WfDownloads = Join-Path $script:Sandbox "sem-downloads"
        Set-TestStub -Name "Get-WinForgeRegistryValueOrNull" -Body { $global:WfDownloads }

        try {
            Set-FakeReadHost -Answers @("")
            (Get-HostText { Clear-WinForgeDownloads }) | Should -Match "não encontrada"

            $global:WfDownloads = New-Dir "downloads-vazia"
            Set-FakeReadHost -Answers @("")
            (Get-HostText { Clear-WinForgeDownloads }) | Should -Match "já está vazia"
        }
        finally {
            Clear-FakeReadHost
            Clear-TestStubs
            Remove-Variable WfDownloads -Scope Global -ErrorAction SilentlyContinue
        }
    }
}
