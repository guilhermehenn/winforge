# Programas (winget): leitura das tabelas, argumentos, códigos de saída e plano de atualização.

BeforeAll {
    . (Join-Path $PSScriptRoot "TestSetup.ps1")

    function script:Use-FakeWinget {
        # O módulo só precisa que exista um "winget" no PATH; a saída vem de um Invoke-WinForgeCapture de teste.
        $directory = Join-Path $script:TestDataRoot "fakebin"
        New-Item -ItemType Directory -Path $directory -Force | Out-Null

        if ($env:OS -eq "Windows_NT") {
            Set-Content -LiteralPath (Join-Path $directory "winget.cmd") -Value "@echo off"
        }
        else {
            $file = Join-Path $directory "winget"
            Set-Content -LiteralPath $file -Value "#!/bin/sh"
            & chmod +x $file
        }

        if ($env:PATH -notlike "*$directory*") {
            $env:PATH = $directory + [IO.Path]::PathSeparator + $env:PATH
        }
    }

    function script:Use-WingetScenario {
        # Winget de mentira: as consultas (source/upgrade/list/search) devolvem as tabelas dadas e as operações
        # (install/upgrade/uninstall) ficam registradas em $global:WfNative com o código de saída escolhido.
        param ([hashtable]$Tables = @{}, [int]$NativeExit = 0)

        Use-FakeWinget
        $global:WfTables = $Tables
        $global:WfNative = New-Object System.Collections.ArrayList
        $global:WfNativeExit = $NativeExit

        Set-TestStub -Name "Invoke-WinForgeCapture" -Body {
            param ($FilePath, $Arguments, [switch]$Echo)
            $verb = [string]$Arguments[0]
            $lines = if ($global:WfTables.ContainsKey($verb)) { @($global:WfTables[$verb]) } else { @() }
            [PSCustomObject]@{ ExitCode = 0; Lines = $lines; Text = ($lines -join "`n") }
        }

        Set-TestStub -Name "Invoke-WinForgeNative" -Body {
            param ($FilePath, $Arguments, [switch]$IgnoreExitCode, [switch]$PassThru)
            [void]$global:WfNative.Add(($Arguments -join " "))
            $global:WfNativeExit
        }
    }

    function script:Clear-WingetScenario {
        Clear-TestStubs
        Clear-FakeReadHost
        Remove-Variable WfTables, WfNative, WfNativeExit -Scope Global -ErrorAction SilentlyContinue
    }

    function script:Get-ParsedTable {
        param ([string[]]$Lines)
        return @(ConvertFrom-WinForgeWingetTable -Lines $Lines)
    }
}

AfterAll {
    Remove-WinForgeTestData
}

Describe "Lista de IDs do winget" {
    It "separa por vírgula, remove espaços e duplicados" {
        $ids = ConvertTo-WinForgeWingetPackageIdList -InputText "Google.Chrome, Notepad++.Notepad++, Google.Chrome"
        $ids | Should -HaveCount 2
        $ids[0] | Should -Be "Google.Chrome"
    }

    It "rejeita vírgula sem ID" -ForEach @(
        @{ Text = "A,,B" }, @{ Text = ",A" }, @{ Text = "A," }
    ) {
        { ConvertTo-WinForgeWingetPackageIdList -InputText $Text } | Should -Throw
    }

    It "rejeita opções do menu como ID" -ForEach @(
        @{ Text = "S" }, @{ Text = "n" }, @{ Text = "ID" }
    ) {
        { ConvertTo-WinForgeWingetPackageIdList -InputText $Text } | Should -Throw
    }

    It "rejeita IDs que parecem opções do winget ou injetam comandos" -ForEach @(
        @{ Text = "--source" }, @{ Text = "A.B;calc" }, @{ Text = "A.B|C" }, @{ Text = 'A.B"x' }, @{ Text = "A.B&C" }
    ) {
        { ConvertTo-WinForgeWingetPackageIdList -InputText $Text } | Should -Throw
    }

    It "rejeita ID com espaço no meio (provável nome em vez de ID)" {
        { ConvertTo-WinForgeWingetPackageIdList -InputText "Google Chrome" } | Should -Throw -ExpectedMessage "*espaços*"
    }

    It "devolve lista vazia para entrada em branco" {
        @(ConvertTo-WinForgeWingetPackageIdList -InputText "   ") | Should -HaveCount 0
        @(ConvertTo-WinForgeWingetPackageIdList -InputText $null) | Should -HaveCount 0
    }
}

Describe "Tabela do winget" {
    It "lê a tabela em inglês" {
        $lines = @(
            "Name            Id                  Version Available Source",
            "-----------------------------------------------------------",
            "Google Chrome   Google.Chrome       120.0   121.0     winget",
            "Notepad++       Notepad++.Notepad++ 8.5     8.6       winget",
            "2 upgrades available."
        )
        $result = Get-ParsedTable $lines
        $result | Should -HaveCount 2
        $result[1].Id | Should -Be "Notepad++.Notepad++"
        $result[0].Versao | Should -Be "120.0"
        $result[0].Disponivel | Should -Be "121.0"
        $result[0].Nome | Should -Be "Google Chrome"
    }

    It "lê a tabela em português (ID em maiúsculas e coluna Origem)" {
        $lines = @(
            "Nome            ID                  Versão  Disponível Origem",
            "-------------------------------------------------------------",
            "Google Chrome   Google.Chrome       120.0   121.0      winget",
            "Notepad++       Notepad++.Notepad++ 8.5     8.6        winget",
            "2 atualizações disponíveis."
        )
        $result = Get-ParsedTable $lines
        $result | Should -HaveCount 2
        $result[0].Id | Should -Be "Google.Chrome"
        $result[0].Fonte | Should -Be "winget"
    }

    It "lê resultados de busca (coluna Match) sem confundir versão" {
        $lines = @(
            "Name       Id               Version Match      Source",
            "-----------------------------------------------------",
            "VLC media  VideoLAN.VLC     3.0.20  Tag: video winget"
        )
        $result = Get-ParsedTable $lines
        $result | Should -HaveCount 1
        $result[0].Versao | Should -Be "3.0.20"
        $result[0].Fonte | Should -Be "winget"
    }

    It "ignora linhas soltas antes do cabeçalho (barra giratória do winget)" {
        $lines = @(
            "   - ", "   \ ", "   | ",
            "Name      Id         Version Available Source",
            "---------------------------------------------",
            "App Um    Pub.AppUm  1.0     2.0       winget"
        )
        (Get-ParsedTable $lines) | Should -HaveCount 1
    }

    It "para na linha em branco e ignora a segunda tabela de pacotes que exigem seleção explícita" {
        $lines = @(
            "Name      Id         Version Available Source",
            "---------------------------------------------",
            "App Um    Pub.AppUm  1.0     2.0       winget",
            "",
            "The following packages have an upgrade available, but require explicit targeting for upgrade:",
            "Name      Id         Version Available",
            "---------------------------------------------",
            "App Dois  Pub.AppDois 1.0    2.0"
        )
        $result = Get-ParsedTable $lines
        $result | Should -HaveCount 1
        $result[0].Id | Should -Be "Pub.AppUm"
    }

    It "lida com linhas mais curtas que o cabeçalho (sem coluna de origem)" {
        $lines = @(
            "Name      Id         Version Available Source",
            "---------------------------------------------",
            "App Um    Pub.AppUm  1.0"
        )
        $result = Get-ParsedTable $lines
        $result | Should -HaveCount 1
        $result[0].Disponivel | Should -Be ""
        $result[0].Fonte | Should -Be "?"
    }

    It "aceita versões com prefixo '>' e 'Unknown'" {
        $lines = @(
            "Name      Id         Version   Available Source",
            "-----------------------------------------------",
            "App Um    Pub.AppUm  > 1.0.0   2.0       winget",
            "App Dois  Pub.Dois   Unknown   3.0       winget"
        )
        $result = Get-ParsedTable $lines
        $result | Should -HaveCount 2
        $result[0].Versao | Should -Be "> 1.0.0"
        $result[1].Versao | Should -Be "Unknown"
    }

    It "mantém as colunas alinhadas em nomes com ideogramas (ocupam duas colunas)" {
        $wide = ([string][char]0x5FAE) + ([string][char]0x4FE1)   # dois ideogramas = 4 colunas de tela
        $header = "Name".PadRight(16) + "Id".PadRight(20) + "Version".PadRight(8) + "Available".PadRight(10) + "Source"
        $lines = @(
            $header,
            ("-" * 60),
            ($wide + (" " * 12) + "Tencent.WeChat".PadRight(20) + "3.9".PadRight(8) + "4.0".PadRight(10) + "winget"),
            ("Notepad++".PadRight(16) + "Notepad++.Notepad++".PadRight(20) + "8.5".PadRight(8) + "8.6".PadRight(10) + "winget")
        )

        $result = Get-ParsedTable $lines
        $result | Should -HaveCount 2
        $result[0].Nome | Should -Be $wide
        $result[0].Id | Should -Be "Tencent.WeChat"
        $result[0].Versao | Should -Be "3.9"
        $result[0].Disponivel | Should -Be "4.0"
        $result[0].Fonte | Should -Be "winget"
        $result[1].Id | Should -Be "Notepad++.Notepad++"
    }

    It "devolve vazio quando não há cabeçalho, quando é nulo ou quando só há texto" -ForEach @(
        @{ Lines = @("Nenhuma atualização disponível.") },
        @{ Lines = @() },
        @{ Lines = @("", "   ") },
        @{ Lines = @("Name Id") }
    ) {
        (Get-ParsedTable $Lines) | Should -HaveCount 0
    }

    It "aceita entrada nula" {
        { ConvertFrom-WinForgeWingetTable -Lines $null } | Should -Not -Throw
        @(ConvertFrom-WinForgeWingetTable -Lines $null) | Should -HaveCount 0
    }

    It "recorta colunas por posição sem estourar com índices fora do texto" {
        Get-WinForgeSafeSubstring -Text "abc" -Start 5 -End 9 | Should -Be ""
        Get-WinForgeSafeSubstring -Text "abc" -Start 1 -End 99 | Should -Be "bc"
        Get-WinForgeSafeSubstring -Text "abc" -Start 1 -End 0 | Should -Be "bc"
        Get-WinForgeSafeSubstring -Text "" -Start 0 -End 3 | Should -Be ""
        Get-WinForgeSafeSubstring -Text "abc" -Start -1 -End 3 | Should -Be ""
    }

    It "reconhece a saída de 'nenhuma atualização' em inglês e português" -ForEach @(
        @{ Text = "No installed package found matching input criteria." },
        @{ Text = "No available upgrade found." },
        @{ Text = "Nenhuma atualização disponível." },
        @{ Text = "Nenhum pacote instalado corresponde aos critérios." }
    ) {
        Test-WinForgeWingetNoUpgradeOutput -OutputText $Text | Should -BeTrue
    }

    It "não confunde uma tabela de atualizações com 'nenhuma atualização'" {
        Test-WinForgeWingetNoUpgradeOutput -OutputText "Name Id Version Available`nApp Pub.App 1 2" | Should -BeFalse
    }
}

Describe "Argumentos e códigos do winget" {
    It "usa --source winget apenas quando solicitado" {
        (Get-WinForgeWingetArguments -Operation Install -PackageId "7zip.7zip") -contains "--source" | Should -BeFalse
        (Get-WinForgeWingetArguments -Operation Install -PackageId "7zip.7zip" -WingetSourceOnly) -contains "--source" | Should -BeTrue
    }

    It "nunca deixa o winget esperar por resposta" -ForEach @(
        @{ Operation = "Install" }, @{ Operation = "Upgrade" }, @{ Operation = "UpgradeAll" }, @{ Operation = "Uninstall" }
    ) {
        $arguments = Get-WinForgeWingetArguments -Operation $Operation -PackageId "A.B"
        $arguments | Should -Contain "--disable-interactivity"
        $arguments | Should -Contain "--silent"
    }

    It "mantém o ID como um único argumento e usa correspondência exata" {
        $arguments = Get-WinForgeWingetArguments -Operation Uninstall -PackageId "Pub.Nome Com Espaco"
        $arguments | Should -Contain "Pub.Nome Com Espaco"
        $arguments | Should -Contain "-e"
        $arguments[0] | Should -Be "uninstall"
    }

    It "atualizar tudo não leva ID" {
        $arguments = Get-WinForgeWingetArguments -Operation UpgradeAll
        $arguments | Should -Contain "--all"
        $arguments | Should -Not -Contain "--id"
    }

    It "traduz códigos de saída conhecidos e desconhecidos" {
        (Get-WinForgeWingetExitResult -ExitCode 0).Kind | Should -Be "Ok"
        (Get-WinForgeWingetExitResult -ExitCode -1978335189).Kind | Should -Be "Ok"
        (Get-WinForgeWingetExitResult -ExitCode -1978335135).Status | Should -Match "já estava instalado"
        (Get-WinForgeWingetExitResult -ExitCode -1978335212).Kind | Should -Be "Failed"

        $unknown = Get-WinForgeWingetExitResult -ExitCode 5
        $unknown.Kind | Should -Be "Failed"
        $unknown.Status | Should -Match "0x00000005"
    }

    It "mostra o código negativo em hexadecimal de 32 bits" {
        (Get-WinForgeWingetExitResult -ExitCode -1978334972).Status | Should -Match "0x8A150104"
    }
}

Describe "Catálogo de programas essenciais" {
    It "tem IDs únicos e válidos para o winget" {
        $catalog = @(Get-WinForgeEssentialSoftwareCatalog)
        $catalog.Count | Should -BeGreaterThan 5

        $ids = @($catalog | ForEach-Object { $_.Id })
        ($ids | Select-Object -Unique) | Should -HaveCount $ids.Count

        foreach ($entry in $catalog) {
            $entry.Nome | Should -Not -BeNullOrEmpty
            { ConvertTo-WinForgeWingetPackageIdList -InputText $entry.Id } | Should -Not -Throw
        }
    }
}

Describe "Plano de atualização do winget" {
    It "devolve 'Unavailable' quando não há winget no PATH" {
        $savedPath = $env:PATH
        $env:PATH = Join-Path $script:TestDataRoot "vazio"
        try {
            $plan = Get-WinForgeWingetUpgradePlan
            $plan.Action | Should -Be "Unavailable"
            (Invoke-WinForgeWingetUpgradePlan -Plan $plan).Kind | Should -Be "Failed"
        }
        finally {
            $env:PATH = $savedPath
        }
    }

    It "reconhece 'nenhuma atualização' sem perguntar nada" {
        Use-FakeWinget
        Set-TestStub -Name "Invoke-WinForgeCapture" -Body {
            param ($FilePath, $Arguments, [switch]$Echo)
            [PSCustomObject]@{ ExitCode = 0; Lines = @("Nenhuma atualização disponível."); Text = "Nenhuma atualização disponível." }
        }
        try {
            $plan = Get-WinForgeWingetUpgradePlan
            $plan.Action | Should -Be "NoUpdates"
            (Invoke-WinForgeWingetUpgradePlan -Plan $plan).Status | Should -Match "nada a atualizar"
        }
        finally {
            Clear-TestStubs
        }
    }

    It "lê a tabela e devolve os IDs marcados" {
        Use-FakeWinget
        $table = @(
            "Name            Id                  Version Available Source",
            "-----------------------------------------------------------",
            "Google Chrome   Google.Chrome       120.0   121.0     winget",
            "Notepad++       Notepad++.Notepad++ 8.5     8.6       winget",
            "2 upgrades available."
        )
        $global:WfTable = $table
        Set-TestStub -Name "Invoke-WinForgeCapture" -Body {
            param ($FilePath, $Arguments, [switch]$Echo)
            [PSCustomObject]@{ ExitCode = 0; Lines = $global:WfTable; Text = ($global:WfTable -join "`n") }
        }
        Set-FakeReadHost -Answers "E", "2"
        try {
            $plan = Get-WinForgeWingetUpgradePlan
            $plan.Action | Should -Be "Ids"
            $plan.Ids | Should -Be @("Notepad++.Notepad++")
            $plan.Packages | Should -HaveCount 2
        }
        finally {
            Clear-FakeReadHost
            Clear-TestStubs
            Remove-Variable WfTable -Scope Global -ErrorAction SilentlyContinue
        }
    }

    It "voltar ao menu quando nada é marcado na lista" {
        Use-FakeWinget
        $global:WfTable = @(
            "Name            Id                  Version Available Source",
            "-----------------------------------------------------------",
            "Google Chrome   Google.Chrome       120.0   121.0     winget"
        )
        Set-TestStub -Name "Invoke-WinForgeCapture" -Body {
            param ($FilePath, $Arguments, [switch]$Echo)
            [PSCustomObject]@{ ExitCode = 0; Lines = $global:WfTable; Text = ($global:WfTable -join "`n") }
        }
        # E (escolher), ENTER vazio (cancela a lista), N (não atualizar)
        Set-FakeReadHost -Answers "E", "", "N"
        try {
            (Get-WinForgeWingetUpgradePlan).Action | Should -Be "None"
        }
        finally {
            Clear-FakeReadHost
            Clear-TestStubs
            Remove-Variable WfTable -Scope Global -ErrorAction SilentlyContinue
        }
    }

    It "falha com mensagem clara quando o winget não responde" {
        Use-FakeWinget
        Set-TestStub -Name "Invoke-WinForgeCapture" -Body {
            param ($FilePath, $Arguments, [switch]$Echo)
            [PSCustomObject]@{ ExitCode = 1; Lines = @(); Text = "" }
        }
        try {
            { Get-WinForgeWingetUpgradePlan } | Should -Throw -ExpectedMessage "*sem retornar detalhes*"
        }
        finally {
            Clear-TestStubs
        }
    }

    It "trata plano com ação desconhecida como falha (nunca como sucesso) e plano de erro como falha" {
        $unknown = Invoke-WinForgeWingetUpgradePlan -Plan ([PSCustomObject]@{ Action = "Inexistente" })
        $unknown.Kind | Should -Be "Failed"
        $unknown.Status | Should -Match "ação desconhecida no plano: Inexistente"
        (Invoke-WinForgeWingetUpgradePlan -Plan ([PSCustomObject]@{ Action = "Error"; Detail = "falhou" })).Kind | Should -Be "Failed"
        (Invoke-WinForgeWingetUpgradePlan -Plan ([PSCustomObject]@{ Action = "None" })).Kind | Should -Be "Skipped"
    }
}


Describe "Atualizar programas (winget), cenários" {
    BeforeAll {
        $script:UpgradeTable = @(
            "Name            Id                  Version Available Source",
            "-----------------------------------------------------------",
            "Google Chrome   Google.Chrome       120.0   121.0     winget",
            "Notepad++       Notepad++.Notepad++ 8.5     8.6       winget",
            "2 upgrades available."
        )
    }

    AfterEach { Clear-WingetScenario }

    It "S atualiza tudo com um único comando e informa a conclusão" {
        Use-WingetScenario -Tables @{ upgrade = $script:UpgradeTable }
        Set-FakeReadHost -Answers @("S", "")

        $text = Get-HostText { Update-WinForgeSoftware }

        @($global:WfNative) | Should -HaveCount 1
        $global:WfNative[0] | Should -BeLike "upgrade --all *--disable-interactivity*"
        $text | Should -Match "Atualização via winget finalizada"
    }

    It "explica o que a rotina não cobre e aponta para a página Atualizações" {
        Use-WingetScenario -Tables @{ upgrade = $script:UpgradeTable }
        Set-FakeReadHost -Answers @("N", "")

        $text = Get-HostText { Update-WinForgeSoftware }

        $text | Should -Match "apenas programas gerenciados pelo winget"
        $text | Should -Match ("página " + [regex]::Escape((Get-WinForgeNavPage -Id "updates").Title))
        $text | Should -Not -Match "BIOS"
    }

    It "E atualiza só o pacote marcado, por ID exato" {
        Use-WingetScenario -Tables @{ upgrade = $script:UpgradeTable }
        Set-FakeReadHost -Answers @("E", "2", "")

        [void](Get-HostText { Update-WinForgeSoftware })

        @($global:WfNative) | Should -HaveCount 1
        $global:WfNative[0] | Should -BeLike "upgrade --id Notepad++.Notepad++ -e *"
    }

    It "N não executa nada e avisa que não atualizou" {
        Use-WingetScenario -Tables @{ upgrade = $script:UpgradeTable }
        Set-FakeReadHost -Answers @("N", "")

        $text = Get-HostText { Update-WinForgeSoftware }

        @($global:WfNative) | Should -HaveCount 0
        $text | Should -Match "Atualização via winget não executada"
    }

    It "sem atualizações disponíveis, avisa e nem pergunta como continuar" {
        Use-WingetScenario -Tables @{ upgrade = @("Nenhuma atualização disponível.") }
        Set-FakeReadHost -Answers @("")

        $text = Get-HostText { Update-WinForgeSoftware }

        @($global:WfNative) | Should -HaveCount 0
        $text | Should -Match "Nenhuma atualização via winget foi encontrada"
        $text | Should -Not -Match "Atualizar todos os pacotes"
    }

    It "se o winget terminar com erro ao atualizar tudo, mostra o código em vez de dar sucesso" {
        Use-WingetScenario -Tables @{ upgrade = $script:UpgradeTable } -NativeExit 5
        Set-FakeReadHost -Answers @("S", "")

        $text = Get-HostText { Update-WinForgeSoftware }

        $text | Should -Match "O winget terminou com código 5"
        $text | Should -Not -Match "Atualização via winget finalizada"
    }

    It "sem winget instalado, explica como obter e não pergunta nada" {
        $savedPath = $env:PATH
        $env:PATH = Join-Path $script:TestDataRoot "vazio"
        try {
            Set-FakeReadHost -Answers @("")
            $text = Get-HostText { Update-WinForgeSoftware }
        }
        finally { $env:PATH = $savedPath; Clear-FakeReadHost }

        $text | Should -Match "O winget não foi encontrado"
        $text | Should -Match "Instalador de Aplicativo"
        $text | Should -Not -Match "Atualizar todos os pacotes"
    }

    It "um erro inesperado do winget vira mensagem, sem exceção" {
        Use-WingetScenario
        Set-TestStub -Name "Invoke-WinForgeCapture" -Body {
            param ($FilePath, $Arguments, [switch]$Echo)
            if ($Arguments[0] -eq "upgrade") { throw "winget travou" }
            [PSCustomObject]@{ ExitCode = 0; Lines = @(); Text = "" }
        }
        Set-FakeReadHost -Answers @("")

        (Get-HostText { Update-WinForgeSoftware }) | Should -Match "Ocorreu um erro ao atualizar programas via winget: winget travou"
    }
}

Describe "Resultado de várias operações do winget" {
    AfterEach { Clear-WingetScenario }

    It "todos certos: resultado Ok e tabela de resumo só quando há mais de um pacote" {
        Use-WingetScenario
        $two = @([PSCustomObject]@{ Id = "A.A"; Nome = "Alfa" }, [PSCustomObject]@{ Id = "B.B"; Nome = "Beta" })

        $text = Get-HostText { $script:r2 = Invoke-WinForgeWingetPackages -Operation Install -Packages $two }
        $script:r2.Kind | Should -Be "Ok"
        $text | Should -Match "Resumo"

        $one = @([PSCustomObject]@{ Id = "A.A"; Nome = "Alfa" })
        $text = Get-HostText { $script:r1 = Invoke-WinForgeWingetPackages -Operation Install -Packages $one }
        $script:r1.Kind | Should -Be "Ok"
        $text | Should -Not -Match "Resumo"
    }

    It "todos falhando: Failed; parte falhando é tratada pelo código de saída de cada pacote" {
        Use-WingetScenario -NativeExit 1
        $two = @([PSCustomObject]@{ Id = "A.A"; Nome = "Alfa" }, [PSCustomObject]@{ Id = "B.B"; Nome = "Beta" })

        [void](Get-HostText { $script:rf = Invoke-WinForgeWingetPackages -Operation Upgrade -Packages $two })

        $script:rf.Kind | Should -Be "Failed"
        $script:rf.Status | Should -Match "Alfa, Beta"
    }

    It "'já instalado' e 'já na versão mais recente' contam como sucesso" -ForEach @(
        @{ Code = -1978335135; Match = "já estava instalado" },
        @{ Code = -1978335189; Match = "já está na versão mais recente" }
    ) {
        Use-WingetScenario -NativeExit $Code
        $one = @([PSCustomObject]@{ Id = "A.A"; Nome = "Alfa" })

        $text = Get-HostText { $script:rk = Invoke-WinForgeWingetPackages -Operation Install -Packages $one }

        $script:rk.Kind | Should -Be "Ok"
        $text | Should -Match $Match
    }
}

Describe "Programas, cenários" {
    BeforeAll {
        $script:ListTable = @(
            "Name       Id                  Version Source",
            "----------------------------------------------",
            "Zeta App   Zeta.App            1.0     winget",
            "Alfa App   Alfa.App            2.0     winget"
        )
        $script:SearchTable = @(
            "Name        Id               Version Match      Source",
            "------------------------------------------------------",
            "Cool Tool   Vendor.CoolTool  3.1     Moniker: x winget",
            "Cool Tool 2 Vendor.CoolTool2 1.0     Tag: cool  winget"
        )
    }

    AfterEach { Clear-WingetScenario }

    It "listar: mostra a tabela do winget e indica o item certo para remover" {
        Use-WingetScenario
        Set-FakeReadHost -Answers @("")

        $text = Get-HostText { Show-WinForgeInstalledSoftware }

        @($global:WfNative) | Should -HaveCount 1
        $global:WfNative[0] | Should -BeLike "list *"
        $text | Should -Match ([regex]::Escape("Programas > Desinstalar programas"))
    }

    It "listar: avisa o código quando o winget termina com erro" {
        Use-WingetScenario -NativeExit 3
        Set-FakeReadHost -Answers @("")

        (Get-HostText { Show-WinForgeInstalledSoftware }) | Should -Match "O winget terminou com código 3"
    }

    It "instalar essenciais: instala só o marcado e restringe à fonte winget" {
        Use-WingetScenario
        $catalog = @(Get-WinForgeEssentialSoftwareCatalog | Sort-Object Categoria, Nome)
        Set-FakeReadHost -Answers @("1", "")

        [void](Get-HostText { Install-WinForgeEssentialSoftware })

        @($global:WfNative) | Should -HaveCount 1
        $global:WfNative[0] | Should -BeLike "install --id $($catalog[0].Id) -e *--source winget*"
    }

    It "instalar essenciais: sem marcar nada, não instala nada" {
        Use-WingetScenario
        Set-FakeReadHost -Answers @("", "")

        $text = Get-HostText { Install-WinForgeEssentialSoftware }

        @($global:WfNative) | Should -HaveCount 0
        $text | Should -Match "Nenhum programa selecionado"
    }

    It "buscar: termo vazio cancela sem consultar o winget" {
        Use-WingetScenario
        Set-FakeReadHost -Answers @("   ", "")

        $text = Get-HostText { Find-WinForgeSoftware }

        $text | Should -Match "Nenhum termo informado"
        @($global:WfNative) | Should -HaveCount 0
    }

    It "buscar: aspas e crases do termo são removidas antes de chegar ao winget" {
        Use-WingetScenario -Tables @{ search = $script:SearchTable }
        $global:WfSearchArgs = $null
        Set-TestStub -Name "Invoke-WinForgeCapture" -Body {
            param ($FilePath, $Arguments, [switch]$Echo)
            if ($Arguments[0] -eq "search") { $global:WfSearchArgs = @($Arguments) }
            [PSCustomObject]@{ ExitCode = 0; Lines = @(); Text = "" }
        }
        Set-FakeReadHost -Answers @('"cool`tool"', "")

        [void](Get-HostText { Find-WinForgeSoftware })

        $global:WfSearchArgs[2] | Should -Be "cool tool"
        Remove-Variable WfSearchArgs -Scope Global -ErrorAction SilentlyContinue
    }

    It "buscar: sem resultados, diz o termo procurado e não instala nada" {
        Use-WingetScenario -Tables @{ search = @("Nenhum pacote encontrado.") }
        Set-FakeReadHost -Answers @("xyzxyz", "")

        $text = Get-HostText { Find-WinForgeSoftware }

        $text | Should -Match "Nenhum pacote encontrado para 'xyzxyz'"
        @($global:WfNative) | Should -HaveCount 0
    }

    It "buscar: instala o resultado marcado, sem restringir a fonte" {
        Use-WingetScenario -Tables @{ search = $script:SearchTable }
        Set-FakeReadHost -Answers @("cool", "2", "")

        $text = Get-HostText { Find-WinForgeSoftware }

        @($global:WfNative) | Should -HaveCount 1
        $global:WfNative[0] | Should -BeLike "install --id Vendor.CoolTool2 -e *"
        $global:WfNative[0] | Should -Not -BeLike "*--source*"
        # A lista mostra todos os resultados antes de pedir a escolha.
        $text | Should -Match "Vendor\.CoolTool\s+-\s+3\.1"
        $text | Should -Match "Vendor\.CoolTool2\s+-\s+1\.0"
    }

    It "desinstalar: lista em ordem alfabética, pede confirmação e remove só o marcado" {
        Use-WingetScenario -Tables @{ list = $script:ListTable }
        # 1 = primeiro da lista ordenada (Alfa App); S confirma
        Set-FakeReadHost -Answers @("1", "S", "")

        $text = Get-HostText { Uninstall-WinForgeSoftware }

        @($global:WfNative) | Should -HaveCount 1
        $global:WfNative[0] | Should -BeLike "uninstall --id Alfa.App -e *"
        $text | Should -Match "Programas que serão desinstalados"
        $text | Should -Match "Alfa App"
    }

    It "desinstalar: a resposta padrão da confirmação é 'não'" {
        Use-WingetScenario -Tables @{ list = $script:ListTable }
        Set-FakeReadHost -Answers @("1", "", "")

        $text = Get-HostText { Uninstall-WinForgeSoftware }

        @($global:WfNative) | Should -HaveCount 0
        $text | Should -Match "Desinstalação cancelada"
    }

    It "desinstalar: sem marcar nada, não pergunta e não remove" {
        Use-WingetScenario -Tables @{ list = $script:ListTable }
        Set-FakeReadHost -Answers @("", "")

        $text = Get-HostText { Uninstall-WinForgeSoftware }

        @($global:WfNative) | Should -HaveCount 0
        $text | Should -Match "Nenhum programa selecionado"
        $text | Should -Not -Match "Deseja desinstalar"
    }

    It "desinstalar: lista ilegível vira aviso, não remoção" {
        Use-WingetScenario -Tables @{ list = @("Algo inesperado") }
        Set-FakeReadHost -Answers @("")

        $text = Get-HostText { Uninstall-WinForgeSoftware }

        @($global:WfNative) | Should -HaveCount 0
        $text | Should -Match "Não foi possível ler a lista de programas"
    }

    It "sem winget, as quatro telas explicam o motivo e não registram nenhuma operação" {
        $savedPath = $env:PATH
        $env:PATH = Join-Path $script:TestDataRoot "vazio"
        try {
            foreach ($action in @("Show-WinForgeInstalledSoftware", "Find-WinForgeSoftware", "Uninstall-WinForgeSoftware", "Install-WinForgeEssentialSoftware")) {
                Set-FakeReadHost -Answers @("", "")
                $text = Get-HostText { & $action }
                $text | Should -Match "O winget não foi encontrado" -Because $action
            }
        }
        finally { $env:PATH = $savedPath; Clear-FakeReadHost }
    }
}
