# O ícone e o atalho do WinForge: o que o atalho executa, onde é criado e a identidade na barra de tarefas.
# Os pontos de contato com o Windows (pastas especiais e gravação do .lnk) são substituídos por registros; só os
# testes marcados como "Windows" gravam um atalho de verdade, e apenas dentro de uma pasta temporária.

BeforeDiscovery {
    $script:OnWindows = ($PSVersionTable.PSEdition -eq "Desktop") -or ($PSVersionTable.PSObject.Properties["Platform"] -and $PSVersionTable.Platform -eq "Win32NT")
}

BeforeAll {
    . (Join-Path $PSScriptRoot "TestSetup.ps1")

    $script:Sandbox = Join-Path ([IO.Path]::GetTempPath()) ("winforge-atalho-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $script:Sandbox -Force | Out-Null

    $script:OriginalAppRoot = & (Get-Module Launcher) { $script:WinForgeAppRoot }
    $script:CmdFlags = "-NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File"

    function script:New-FakeInstall {
        # Pasta de instalação de mentira: WinForge.Gui.ps1 e, se pedido, assets\WinForge.ico.
        param ([string]$Name = "WinForge", [switch]$NoIcon, [switch]$NoGui)

        $root = Join-Path $script:Sandbox $Name
        New-Item -ItemType Directory -Path $root -Force | Out-Null

        if (-not $NoGui) {
            Set-Content -LiteralPath (Join-Path $root "WinForge.Gui.ps1") -Value "# janela"
        }

        if (-not $NoIcon) {
            $assets = Join-Path $root "assets"
            New-Item -ItemType Directory -Path $assets -Force | Out-Null

            # Cabeçalho mínimo de um .ico (reservado 0, tipo 1, uma imagem) seguido de bytes quaisquer.
            [IO.File]::WriteAllBytes((Join-Path $assets "WinForge.ico"), [byte[]](0, 0, 1, 0, 1, 0, 16, 16, 0, 0, 1, 0, 32, 0))
        }

        return $root
    }

    function script:Set-AppRootForTest {
        param ([string]$Root)
        & (Get-Module Launcher) { param ($r) $script:WinForgeAppRoot = $r } $Root
    }

    function script:Use-ShellStubs {
        # Pastas (Área de Trabalho e Menu Iniciar) dentro do sandbox e uma gravação de .lnk que só registra a chamada.
        param (
            [switch]$NoStartMenu,
            [string[]]$FailFor = @(),
            [bool]$AppIdSet = $true
        )

        $global:WfDesktop = Join-Path $script:Sandbox "Desktop"
        $global:WfStartMenu = Join-Path $script:Sandbox "Programs"
        $global:WfNoStartMenu = [bool]$NoStartMenu
        $global:WfFailFor = @($FailFor)
        $global:WfAppIdSet = $AppIdSet
        $global:WfSaved = New-Object System.Collections.ArrayList
        $global:WfSilentBlock = $false

        foreach ($folder in $global:WfDesktop, $global:WfStartMenu) {
            New-Item -ItemType Directory -Path $folder -Force | Out-Null
            Get-ChildItem -LiteralPath $folder -Force | Remove-Item -Force
        }

        Set-TestStub -Name "Get-WinForgeSpecialFolder" -Body {
            param ([string]$Name)

            if ($Name -eq "Desktop") { return $global:WfDesktop }
            if ($global:WfNoStartMenu) { return "" }
            return $global:WfStartMenu
        }

        Set-TestStub -Name "Save-WinForgeShortcutFile" -Body {
            param ([string]$Path, [string]$Target, [string]$Arguments, [string]$WorkingDirectory, [string]$IconLocation, [string]$Description, [string]$AppId)

            if ($global:WfFailFor | Where-Object { $Path -like "*$_*" }) { throw "Acesso negado." }
            if ($global:WfSilentBlock) { return [PSCustomObject]@{ Path = $Path; AppIdSet = $true } }

            [void]$global:WfSaved.Add([PSCustomObject]@{
                Path = $Path; Target = $Target; Arguments = $Arguments; WorkingDirectory = $WorkingDirectory
                IconLocation = $IconLocation; Description = $Description; AppId = $AppId
            })
            Set-Content -LiteralPath $Path -Value "lnk"

            return [PSCustomObject]@{ Path = $Path; AppIdSet = $global:WfAppIdSet }
        }
    }

    function script:Clear-ShellStubs {
        Clear-TestStubs
        Remove-Variable WfDesktop, WfStartMenu, WfNoStartMenu, WfFailFor, WfAppIdSet, WfSaved, WfSilentBlock -Scope Global -ErrorAction SilentlyContinue
        Set-AppRootForTest $script:OriginalAppRoot
    }
}

AfterAll {
    Clear-ShellStubs
    Remove-WinForgeTestData

    if (Test-Path -LiteralPath $script:Sandbox) {
        Remove-Item -LiteralPath $script:Sandbox -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe "O que o atalho executa" {
    It "abre a janela com a mesma linha do WinForge.cmd, apontando para o script e o ícone da pasta" {
        $root = New-FakeInstall -Name "Instalacao Normal"

        $launch = Get-WinForgeLaunchDefinition -Root $root

        $launch.Arguments | Should -BeLike "$script:CmdFlags *"
        $launch.WorkingDirectory | Should -Be $root
        $launch.IconLocation | Should -Be ("{0},0" -f (Join-Path (Join-Path $root "assets") "WinForge.ico"))
        $launch.HasIcon | Should -BeTrue
        $launch.AppId | Should -Be "WinForge.App"
        $launch.Executable | Should -BeLike "*powershell.exe"
    }

    It "usa os mesmos argumentos do WinForge.cmd (a janela se reabre sozinha como Administrador)" {
        $cmd = [IO.File]::ReadAllText((Join-Path $script:RepoRoot "WinForge.cmd"))

        $cmd | Should -Match ([regex]::Escape($script:CmdFlags))
    }

    It "o caminho do script chega inteiro ao PowerShell, com espaços, acentos, aspas simples, colchetes e outros símbolos: <Name>" -ForEach @(
        @{ Name = "Pasta com espaço" },
        @{ Name = "João's [WinForge] #1 (teste)" },
        @{ Name = "100% Área & Cia; `$ok" },
        @{ Name = "SemEspaco" }
    ) {
        $root = New-FakeInstall -Name $Name
        $script = Join-Path $root "WinForge.Gui.ps1"

        $launch = Get-WinForgeLaunchDefinition -Root $root
        $parsed = @(Split-WindowsCommandLine -Line $launch.Arguments)

        $parsed[-1] | Should -Be $script
        $parsed[-2] | Should -Be "-File"
        ($parsed[0..($parsed.Count - 3)] -join " ") | Should -Be ($script:CmdFlags -replace " -File$", "")
    }

    It "sem o arquivo do ícone, o atalho usa o ícone do PowerShell em vez de ficar sem nenhum" {
        $root = New-FakeInstall -Name "Sem Icone" -NoIcon

        $launch = Get-WinForgeLaunchDefinition -Root $root

        $launch.HasIcon | Should -BeFalse
        $launch.IconLocation | Should -Be "$($launch.Executable),0"
        Get-WinForgeIconPath -Root $root | Should -BeNullOrEmpty
    }

    It "um ícone vazio, cortado ou que não é ícone é tratado como ausente: <Case>" -ForEach @(
        @{ Case = "arquivo vazio"; Bytes = [byte[]]@() },
        @{ Case = "cortado no meio do cabeçalho"; Bytes = [byte[]](0, 0, 1, 0) },
        @{ Case = "texto qualquer"; Bytes = [Text.Encoding]::UTF8.GetBytes("isto não é um ícone") },
        @{ Case = "PNG renomeado para .ico"; Bytes = [byte[]](0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A) },
        @{ Case = "ícone sem nenhuma imagem"; Bytes = [byte[]](0, 0, 1, 0, 0, 0) }
    ) {
        $root = New-FakeInstall -Name "Icone Invalido"
        [IO.File]::WriteAllBytes((Join-Path (Join-Path $root "assets") "WinForge.ico"), $Bytes)

        Get-WinForgeIconPath -Root $root | Should -BeNullOrEmpty
        (Get-WinForgeLaunchDefinition -Root $root).HasIcon | Should -BeFalse
    }

    It "sem o WinForge.Gui.ps1 explica que a pasta precisa ser extraída por inteiro" {
        $root = New-FakeInstall -Name "Sem Janela" -NoGui

        { Get-WinForgeLaunchDefinition -Root $root } | Should -Throw -ExpectedMessage "*WinForge.Gui.ps1*Extraia a pasta inteira*"
    }

    It "o ícone do projeto existe onde o código o procura" {
        Get-WinForgeIconPath -Root $script:RepoRoot | Should -Not -BeNullOrEmpty
    }
}

Describe "Onde o atalho pode ser criado" {
    It "oferece Área de Trabalho e Menu Iniciar, nessa ordem, com o nome WinForge.lnk" {
        Use-ShellStubs
        try {
            $places = @(Get-WinForgeShortcutLocation)

            ($places.Id -join ",") | Should -Be "Desktop,StartMenu"
            ($places.Label -join ",") | Should -Be "Área de Trabalho,Menu Iniciar"
            $places[0].Folder | Should -Be $global:WfDesktop
            Split-Path -Leaf $places[0].Path | Should -Be "WinForge.lnk"
            Split-Path -Parent $places[1].Path | Should -Be $global:WfStartMenu
        }
        finally { Clear-ShellStubs }
    }

    It "ignora uma pasta que o Windows não informa" {
        Use-ShellStubs -NoStartMenu
        try {
            @((Get-WinForgeShortcutLocation).Id) | Should -Be @("Desktop")
        }
        finally { Clear-ShellStubs }
    }
}

Describe "Criar o atalho" {
    BeforeEach {
        Set-AppRootForTest (New-FakeInstall -Name "Instalacao")
    }

    AfterEach {
        Clear-ShellStubs
        Clear-FakeReadHost
    }

    It "na Área de Trabalho: grava o atalho com programa, argumentos, pasta, ícone e identificador" {
        Use-ShellStubs
        $text = Get-HostText { $script:Result = New-WinForgeAppShortcut -Location Desktop -Embedded -PassThru }

        $global:WfSaved | Should -HaveCount 1
        $saved = $global:WfSaved[0]
        $saved.Path | Should -Be (Join-Path $global:WfDesktop "WinForge.lnk")
        $saved.Target | Should -BeLike "*powershell.exe"
        $saved.Arguments | Should -BeLike "$script:CmdFlags *"
        $saved.WorkingDirectory | Should -Be (Get-WinForgeAppRoot)
        $saved.IconLocation | Should -BeLike "*WinForge.ico,0"
        $saved.AppId | Should -Be "WinForge.App"
        $saved.Description | Should -Not -BeNullOrEmpty

        $script:Result.Kind | Should -Be "Ok"
        $text | Should -Match "Atalho criado em Área de Trabalho"
        $text | Should -Match "Fixar na barra de tarefas"
    }

    It "nos dois lugares quando pedido" {
        Use-ShellStubs
        [void](Get-HostText { $script:Result = New-WinForgeAppShortcut -Location Desktop, StartMenu -Embedded -PassThru })

        @($global:WfSaved.Path) | Should -Be @((Join-Path $global:WfDesktop "WinForge.lnk"), (Join-Path $global:WfStartMenu "WinForge.lnk"))
        $script:Result.Kind | Should -Be "Ok"
    }

    It "se o atalho já existe, ele é atualizado (e não duplicado)" {
        Use-ShellStubs
        [void](Get-HostText { New-WinForgeAppShortcut -Location Desktop -Embedded })
        $text = Get-HostText { New-WinForgeAppShortcut -Location Desktop -Embedded }

        $text | Should -Match "Atalho atualizado em Área de Trabalho"
        @(Get-ChildItem -LiteralPath $global:WfDesktop -Filter "*.lnk") | Should -HaveCount 1
    }

    It "um lugar com erro não impede o outro e o resultado vira Atenção" {
        Use-ShellStubs -FailFor "Desktop"
        $text = Get-HostText { $script:Result = New-WinForgeAppShortcut -Location Desktop, StartMenu -Embedded -PassThru }

        $text | Should -Match "Não foi possível criar o atalho em Área de Trabalho: Acesso negado\."
        $text | Should -Match "Atalho criado em Menu Iniciar"
        $script:Result.Kind | Should -Be "Warning"
        $script:Result.Status | Should -Match "1 criado\(s\), 1 com erro"
    }

    It "se nenhum lugar funciona, o resultado é Falhou e nenhuma dica de fixar aparece" {
        Use-ShellStubs -FailFor "WinForge.lnk"
        $text = Get-HostText { $script:Result = New-WinForgeAppShortcut -Location Desktop -Embedded -PassThru }

        $script:Result.Kind | Should -Be "Failed"
        $text | Should -Not -Match "Fixar na barra de tarefas"
    }

    It "se o Windows diz que gravou mas o arquivo não aparece (proteção contra ransomware), conta como erro" {
        Use-ShellStubs
        $global:WfSilentBlock = $true
        $text = Get-HostText { $script:Result = New-WinForgeAppShortcut -Location Desktop -Embedded -PassThru }

        $text | Should -Match "não gravou o arquivo"
        $script:Result.Kind | Should -Be "Failed"
    }

    It "se a pasta de destino não existe, avisa e não tenta gravar" {
        Use-ShellStubs
        Remove-Item -LiteralPath $global:WfDesktop -Recurse -Force

        $text = Get-HostText { $script:Result = New-WinForgeAppShortcut -Location Desktop -Embedded -PassThru }

        $global:WfSaved | Should -HaveCount 0
        $text | Should -Match "não existe"
        $script:Result.Kind | Should -Be "Failed"
    }

    It "avisa quando o Windows não aceita o identificador da barra de tarefas, mas o atalho foi criado" {
        Use-ShellStubs -AppIdSet $false
        $text = Get-HostText { $script:Result = New-WinForgeAppShortcut -Location Desktop -Embedded -PassThru }

        $script:Result.Kind | Should -Be "Ok"
        $text | Should -Match "identificador da barra de tarefas"
    }

    It "avisa quando o arquivo do ícone não está na pasta" {
        Set-AppRootForTest (New-FakeInstall -Name "Instalacao Sem Icone" -NoIcon)
        Use-ShellStubs
        $text = Get-HostText { New-WinForgeAppShortcut -Location Desktop -Embedded }

        $text | Should -Match "WinForge\.ico não foi encontrado"
        $global:WfSaved[0].IconLocation | Should -BeLike "*powershell.exe,0"
    }

    It "sem o WinForge.Gui.ps1 não grava nada e explica o motivo" {
        Set-AppRootForTest (New-FakeInstall -Name "Instalacao Quebrada" -NoGui)
        Use-ShellStubs
        $text = Get-HostText { $script:Result = New-WinForgeAppShortcut -Location Desktop -Embedded -PassThru }

        $global:WfSaved | Should -HaveCount 0
        $text | Should -Match "Extraia a pasta inteira"
        $script:Result.Kind | Should -Be "Failed"
    }

    It "se o Windows não informa nenhuma pasta, avisa e não grava" {
        Set-TestStub -Name "Get-WinForgeSpecialFolder" -Body { param ([string]$Name) "" }
        $text = Get-HostText { $script:Result = New-WinForgeAppShortcut -Location Desktop -Embedded -PassThru }

        $text | Should -Match "não informou a Área de Trabalho"
        $script:Result.Kind | Should -Be "Failed"
    }

    It "sem -Location pergunta onde criar: <Answer> -> <Expected>" -ForEach @(
        @{ Answer = "1"; Expected = "Desktop" },
        @{ Answer = "2"; Expected = "StartMenu" },
        @{ Answer = "A"; Expected = "Desktop,StartMenu" }
    ) {
        Use-ShellStubs
        Set-FakeReadHost -Answers @($Answer)
        $text = Get-HostText { New-WinForgeAppShortcut -Embedded }

        $text | Should -Match "Área de Trabalho"
        $text | Should -Match "Menu Iniciar"

        $created = @($global:WfSaved | ForEach-Object { if ($_.Path -like "*Desktop*") { "Desktop" } else { "StartMenu" } })
        ($created -join ",") | Should -Be $Expected
    }

    It "uma resposta inesperada da pergunta (<Answer>) cancela em vez de dar erro" -ForEach @(
        @{ Answer = "" },
        @{ Answer = "7" },
        @{ Answer = "-1" },
        @{ Answer = "abc" }
    ) {
        Use-ShellStubs
        $global:WfAnswer = $Answer
        Set-TestStub -Name "Read-WinForgeChoice" -Body { param ([string]$Message, $Options, [string]$DefaultKey, [string]$TextPrompt, [switch]$ShowMenu) $global:WfAnswer }

        try {
            $text = Get-HostText { $script:Result = New-WinForgeAppShortcut -Embedded -PassThru }

            $global:WfSaved | Should -HaveCount 0
            $script:Result.Kind | Should -Be "Skipped"
            $text | Should -Match "Nenhum atalho foi criado"
        }
        finally { Remove-Variable WfAnswer -Scope Global -ErrorAction SilentlyContinue }
    }

    It "cancelar na pergunta não cria nada e o resultado é Ignorado" {
        Use-ShellStubs
        Set-FakeReadHost -Answers @("0")
        $text = Get-HostText { $script:Result = New-WinForgeAppShortcut -Embedded -PassThru }

        $global:WfSaved | Should -HaveCount 0
        $script:Result.Kind | Should -Be "Skipped"
        $text | Should -Match "Nenhum atalho foi criado"
    }

    It "com um único lugar disponível não pergunta nada" {
        Use-ShellStubs -NoStartMenu
        Set-FakeReadHost -Answers @()
        [void](Get-HostText { New-WinForgeAppShortcut -Embedded })

        $global:WfSaved | Should -HaveCount 1
        $global:WfSaved[0].Path | Should -Be (Join-Path $global:WfDesktop "WinForge.lnk")
    }

    It "só devolve o resultado quando recebe -PassThru" {
        Use-ShellStubs
        $output = @(& { New-WinForgeAppShortcut -Location Desktop -Embedded } *>&1 | Where-Object { $_.PSObject.TypeNames -contains "WinForge.Result" })

        $output | Should -HaveCount 0
    }
}

Describe "Versão e pastas" {
    BeforeEach {
        Set-AppRootForTest (New-FakeInstall -Name "Instalacao Sobre")
    }

    AfterEach {
        Clear-ShellStubs
        Clear-FakeReadHost
        & (Get-Module Core) { $script:WinForgeLogPath = $null }
        Remove-Variable WinForgeGuiMode -Scope Global -ErrorAction SilentlyContinue
    }

    It "mostra a versão, a pasta de instalação e a pasta de logs e relatórios" {
        Use-ShellStubs
        Set-FakeReadHost -Answers @("")

        $text = Get-HostText { Show-WinForgeAbout }

        $text | Should -Match "Versão e pastas"
        $text | Should -Match ("Build " + [regex]::Escape((Get-WinForgeBuild)))
        $text | Should -Match "Instalado em"
        $text | Should -Match ([regex]::Escape((Get-WinForgeAppRoot)))
        $text | Should -Match "Logs e relatórios"
        $text | Should -Match ([regex]::Escape((Get-WinForgeDataPath)))
        $text | Should -Match "PowerShell"
        $text | Should -Match "Administrador"
    }

    It "diz em quais lugares o atalho já existe" {
        Use-ShellStubs
        [void](Get-HostText { New-WinForgeAppShortcut -Location Desktop -Embedded })
        Set-FakeReadHost -Answers @("")

        $text = Get-HostText { Show-WinForgeAbout }

        $text | Should -Match "Área de Trabalho\s+:\s+Atalho criado"
        $text | Should -Match "Menu Iniciar\s+:\s+Sem atalho"
    }

    It "sem nenhum atalho, os dois lugares aparecem como sem atalho" {
        Use-ShellStubs
        Set-FakeReadHost -Answers @("")

        $text = Get-HostText { Show-WinForgeAbout }

        $text | Should -Match "Área de Trabalho\s+:\s+Sem atalho"
        $text | Should -Match "Menu Iniciar\s+:\s+Sem atalho"
    }

    It "um lugar que o Windows não informa fica de fora da lista" {
        Use-ShellStubs -NoStartMenu
        Set-FakeReadHost -Answers @("")

        $text = Get-HostText { Show-WinForgeAbout }

        $text | Should -Match "Área de Trabalho"
        $text | Should -Not -Match "Menu Iniciar"
    }

    It "avisa quando o arquivo do ícone não está na pasta" {
        Use-ShellStubs
        Set-AppRootForTest (New-FakeInstall -Name "Instalacao Sem Icone" -NoIcon)
        Set-FakeReadHost -Answers @("")

        (Get-HostText { Show-WinForgeAbout }) | Should -Match "WinForge.ico não foi encontrado"
    }

    It "com o ícone na pasta, não há aviso" {
        Use-ShellStubs
        Set-FakeReadHost -Answers @("")

        (Get-HostText { Show-WinForgeAbout }) | Should -Not -Match "não foi encontrado"
    }

    It "mostra o log da sessão só quando há um ativo" {
        Use-ShellStubs
        Set-FakeReadHost -Answers @("", "")

        (Get-HostText { Show-WinForgeAbout }) | Should -Not -Match "Log desta sessão"

        & (Get-Module Core) { $script:WinForgeLogPath = "C:\Logs\sessao.log" }
        (Get-HostText { Show-WinForgeAbout }) | Should -Match "Log desta sessão\s+:\s+C:\\Logs\\sessao.log"
    }

    It "dentro da janela não repete o título e não espera uma tecla" {
        Use-ShellStubs
        $global:WinForgeGuiMode = $true

        # Sem respostas prontas: se a tela esperasse uma tecla, o Read-Host de verdade travaria o teste.
        $text = Get-HostText { Show-WinForgeAbout }

        $text | Should -Not -Match "Versão e pastas"
        $text | Should -Match "Build"
    }
}

Describe "Identidade do WinForge na barra de tarefas" {
    BeforeEach {
        Set-AppRootForTest (New-FakeInstall -Name "Instalacao Identidade")
    }

    AfterEach { Clear-ShellStubs }

    It "o processo recebe o identificador WinForge.App" {
        $global:WfCalls = New-Object System.Collections.ArrayList
        Set-TestStub -Name "Set-WinForgeProcessAppId" -Body { param ([string]$AppId) [void]$global:WfCalls.Add($AppId); $true }

        try {
            Initialize-WinForgeAppIdentity | Should -BeTrue
            @($global:WfCalls) | Should -Be @("WinForge.App")
        }
        finally { Remove-Variable WfCalls -Scope Global -ErrorAction SilentlyContinue }
    }

    It "se o Windows recusa, o resultado é falso e nada é lançado" {
        Set-TestStub -Name "Set-WinForgeProcessAppId" -Body { param ([string]$AppId) $false }

        Initialize-WinForgeAppIdentity | Should -BeFalse
    }

    It "a janela recebe comando, ícone e nome para o 'Fixar na barra de tarefas'" {
        $global:WfRelaunch = $null
        Set-TestStub -Name "Set-WinForgeWindowRelaunch" -Body {
            param ([IntPtr]$Handle, [string]$AppId, [string]$Command, [string]$IconResource, [string]$DisplayName)
            $global:WfRelaunch = [PSCustomObject]@{ Handle = $Handle; AppId = $AppId; Command = $Command; Icon = $IconResource; Name = $DisplayName }
            $true
        }

        try {
            Set-WinForgeWindowIdentity -Handle ([IntPtr]42) | Should -BeTrue

            $global:WfRelaunch.Handle | Should -Be ([IntPtr]42)
            $global:WfRelaunch.AppId | Should -Be "WinForge.App"
            $global:WfRelaunch.Name | Should -Be "WinForge"
            $global:WfRelaunch.Icon | Should -BeLike "*WinForge.ico,0"
            $global:WfRelaunch.Command | Should -BeLike "*powershell.exe*$script:CmdFlags*WinForge.Gui.ps1*"
        }
        finally { Remove-Variable WfRelaunch -Scope Global -ErrorAction SilentlyContinue }
    }

    It "sem o WinForge.Gui.ps1 a identidade da janela é ignorada sem erro" {
        Set-AppRootForTest (New-FakeInstall -Name "Identidade Sem Janela" -NoGui)

        Set-WinForgeWindowIdentity -Handle ([IntPtr]42) | Should -BeFalse
    }
}

Describe "Ponte com o shell do Windows" {
    It "o código em C# compila" {
        Initialize-WinForgeShellInterop | Should -BeTrue
        ("WinForge.ShellIdentity" -as [type]) | Should -Not -BeNullOrEmpty
    }

    It "aceitar ou recusar o identificador do processo nunca lança erro" {
        { $script:Accepted = Set-WinForgeProcessAppId -AppId "WinForge.Teste" } | Should -Not -Throw
        $script:Accepted | Should -BeOfType [bool]
    }

    It "uma janela inexistente é recusada sem lançar erro" {
        { $script:Accepted = Set-WinForgeWindowRelaunch -Handle ([IntPtr]::Zero) -AppId "WinForge.Teste" -Command "x.exe" } | Should -Not -Throw
        $script:Accepted | Should -BeFalse
    }

    It "Get-WinForgeSpecialFolder aceita só os nomes conhecidos" {
        { Get-WinForgeSpecialFolder -Name "Desktop" } | Should -Not -Throw
        { Get-WinForgeSpecialFolder -Name "Inventada" } | Should -Throw
    }
}

Describe "Atalho de verdade (somente Windows)" -Skip:(-not $script:OnWindows) {
    It "grava um .lnk legível com programa, argumentos, ícone, descrição e identificador" {
        $path = Join-Path $script:Sandbox "Teste Real.lnk"
        $icon = Join-Path $script:RepoRoot "assets\WinForge.ico"

        $saved = Save-WinForgeShortcutFile -Path $path -Target (Get-WinForgePowerShellPath) -Arguments "-NoProfile" `
            -WorkingDirectory $script:RepoRoot -IconLocation "$icon,0" -Description "Teste do WinForge" -AppId "WinForge.App"

        Test-Path -LiteralPath $path | Should -BeTrue
        $saved.AppIdSet | Should -BeTrue

        $link = (New-Object -ComObject WScript.Shell).CreateShortcut($path)
        $link.TargetPath | Should -Be (Get-WinForgePowerShellPath)
        $link.Arguments | Should -Be "-NoProfile"
        $link.WorkingDirectory | Should -Be $script:RepoRoot
        $link.IconLocation | Should -Be "$icon,0"
        $link.Description | Should -Be "Teste do WinForge"
        $link.WindowStyle | Should -Be 7
    }

    It "a Área de Trabalho e o Menu Iniciar do usuário existem" {
        foreach ($name in "Desktop", "StartMenu") {
            Test-Path -LiteralPath (Get-WinForgeSpecialFolder -Name $name) -PathType Container | Should -BeTrue
        }
    }
}
