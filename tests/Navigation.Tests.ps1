# Navegação (a tabela única das páginas e ações) e os menus do console que a usam.

BeforeAll {
    . (Join-Path $PSScriptRoot "TestSetup.ps1")

    function script:Use-MenuStubs {
        # Registra o que o menu executaria, sem executar de verdade.
        $global:WfLog = New-Object System.Collections.ArrayList

        Set-TestStub -Name "Open-WinForgeShortcut" -Body {
            param ([string]$Name, [switch]$Quiet)
            [void]$global:WfLog.Add("abrir:$Name")
            $true
        }
        Set-TestStub -Name "Invoke-WinForgeTweakToggle" -Body {
            param ($Tweak, [switch]$AlreadyConfirmed)
            [void]$global:WfLog.Add("toggle:" + $Tweak.Id)
        }
        Set-TestStub -Name "Invoke-WinForgeRecommendedTweaks" -Body { [void]$global:WfLog.Add("recomendados") }
        Set-TestStub -Name "Invoke-WinForgeRestorePoint" -Body { [void]$global:WfLog.Add("ponto-de-restauracao") }
        Set-TestStub -Name "Invoke-WinForgeRevertAllTweaks" -Body { [void]$global:WfLog.Add("desfazer-tudo") }
        Set-TestStub -Name "Invoke-WinForgeRecommendedMaintenance" -Body { [void]$global:WfLog.Add("manutencao") }
        Set-TestStub -Name "Show-WinForgeSystemInfo" -Body { [void]$global:WfLog.Add("sobre") }
        Set-TestStub -Name "New-WinForgeAppShortcut" -Body { [void]$global:WfLog.Add("atalho-do-winforge") }
        Set-TestStub -Name "Show-WinForgeAbout" -Body { [void]$global:WfLog.Add("versao-e-pastas") }
    }

    function script:Get-NavActionTitle {
        # Os títulos que a função passa para Enter-WinForgeAction (ou para os executores que o repassam), lidos do
        # código: uma string literal, ou uma variável que recebe uma string literal na própria função.
        param ([Parameter(Mandatory)][string]$Command)

        $ast = (Get-Command -Name $Command -CommandType Function).ScriptBlock.Ast
        $carriers = @("Enter-WinForgeAction", "Invoke-WinForgeTool", "Invoke-WinForgeFolderCleanup")
        $calls = $ast.FindAll({ param ($n) $n -is [System.Management.Automation.Language.CommandAst] -and $n.GetCommandName() -in $carriers }, $true)
        $titles = @()

        foreach ($call in $calls) {
            $elements = $call.CommandElements

            for ($i = 0; $i -lt $elements.Count - 1; $i++) {
                if ($elements[$i] -isnot [System.Management.Automation.Language.CommandParameterAst] -or $elements[$i].ParameterName -ne "Title") { continue }

                $value = $elements[$i + 1]

                if ($value -is [System.Management.Automation.Language.StringConstantExpressionAst]) {
                    $titles += $value.Value
                }
                elseif ($value -is [System.Management.Automation.Language.ExpandableStringExpressionAst] -and $value.NestedExpressions.Count -eq 0) {
                    $titles += $value.Value
                }
                elseif ($value -is [System.Management.Automation.Language.VariableExpressionAst]) {
                    $name = $value.VariablePath.UserPath
                    $assignment = $ast.FindAll({
                            param ($n)
                            $n -is [System.Management.Automation.Language.AssignmentStatementAst] -and
                            $n.Left -is [System.Management.Automation.Language.VariableExpressionAst] -and
                            $n.Left.VariablePath.UserPath -eq $name
                        }, $true) | Select-Object -First 1

                    if ($null -ne $assignment -and $assignment.Right.Expression -is [System.Management.Automation.Language.StringConstantExpressionAst]) {
                        $titles += $assignment.Right.Expression.Value
                    }
                }
            }
        }

        return $titles
    }

    function script:Set-NavigationForTest {
        # Troca a tabela em memória (e a restaura depois com Reset-NavigationForTest).
        param ($Pages)
        & (Get-Module Navigation) { param ($p) $script:WinForgeNavigation = $p } $Pages
    }

    function script:Reset-NavigationForTest {
        & (Get-Module Navigation) { $script:WinForgeNavigation = $null }
    }
}

AfterAll {
    Reset-NavigationForTest
    Remove-Variable WfLog -Scope Global -ErrorAction SilentlyContinue
    Remove-WinForgeTestData
}

Describe "Tabela de navegação" {
    It "não tem nenhum problema: funções existem, atalhos são conhecidos, Ids são únicos" {
        @(Test-WinForgeNavigation) | Should -HaveCount 0
    }

    It "mantém a ordem das páginas: manutenção, diagnóstico, segurança, limpeza, reparo, atualizações, programas, rede, ajustes e, por fim, o próprio WinForge" {
        (@(Get-WinForgeNavigation).Id -join ",") | Should -Be "maintenance,diagnostics,security,cleanup,repair,updates,software,network,tweaks,app"
    }

    It "a página do próprio WinForge fica no rodapé e oferece versão, atalho e pasta de logs" {
        $page = Get-WinForgeNavPage -Id "app"

        $page.Title | Should -Be "Sobre o WinForge"
        $page.Placement | Should -Be "Footer"
        (@($page.Items.Id) -join ",") | Should -Be "app.about,app.shortcut,app.logs"
        (Get-WinForgeNavItem -Id "app.about").Command | Should -Be "Show-WinForgeAbout"
        (Get-WinForgeNavItem -Id "app.shortcut").Command | Should -Be "New-WinForgeAppShortcut"
        (Get-WinForgeNavItem -Id "app.logs").Shortcut | Should -Be "LogFolder"
    }

    It "a página Segurança vem depois do Diagnóstico: estado, assinaturas, três verificações e o aplicativo do Windows" {
        $page = Get-WinForgeNavPage -Id "security"

        $page.Title | Should -Be "Segurança"
        (@(Get-WinForgeNavigation).Id | Select-Object -Skip 1 -First 2) -join "," | Should -Be "diagnostics,security"
        (@($page.Items.Id) -join ",") | Should -Be "security.status,security.signatures,security.quick-scan,security.full-scan,security.folder-scan,security.windows-security"
        @($page.Items | Where-Object { $_.Accent }).Id | Should -Be "security.status"
        (Get-WinForgeNavItem -Id "security.windows-security").Shortcut | Should -Be "WindowsSecurity"
    }

    It "a Manutenção junta o caminho guiado, a rede de segurança (criar o ponto e voltar a ele) e a manutenção agendada" {
        $page = Get-WinForgeNavPage -Id "maintenance"

        (@($page.Items.Id) -join ",") | Should -Be "maintenance.recommended,maintenance.restore-point,maintenance.restore,maintenance.schedule,maintenance.task-scheduler"
        (Get-WinForgeNavItem -Id "maintenance.restore").Shortcut | Should -Be "SystemRestore"
        (Get-WinForgeNavItem -Id "maintenance.schedule").Command | Should -Be "Show-WinForgeScheduledMaintenance"
        (Get-WinForgeNavItem -Id "maintenance.task-scheduler").Shortcut | Should -Be "TaskScheduler"
    }

    It "o Diagnóstico oferece a Saúde da bateria logo depois da Saúde dos discos" {
        $ids = @((Get-WinForgeNavPage -Id "diagnostics").Items.Id)

        $ids.IndexOf("diagnostics.battery") | Should -Be ($ids.IndexOf("diagnostics.disk-health") + 1)
        (Get-WinForgeNavItem -Id "diagnostics.battery").Command | Should -Be "Show-WinForgeBatteryHealth"
    }

    It "só a página do WinForge fica no rodapé, e as demais ficam na lista principal" {
        $footer = @(Get-WinForgeNavigation | Where-Object { $_.Placement -eq "Footer" })

        $footer | Should -HaveCount 1
        $footer[0].Id | Should -Be "app"
        (Get-WinForgeNavigation)[-1].Id | Should -Be "app"
        @(Get-WinForgeNavigation | Where-Object { $_.Placement -ne "Footer" }) | Should -HaveCount 9
    }

    It "a página de ajustes tem as três ações da barra: recomendados (destaque), ponto de restauração e desfazer tudo" {
        $page = Get-WinForgeNavPage -Id "tweaks"

        $page.Title | Should -Be "Ajustes do Windows"
        (@($page.Items.Id) -join ",") | Should -Be "tweaks.recommended,tweaks.restore-point,tweaks.revert-all"
        @($page.Items | Where-Object { $_.Accent }).Id | Should -Be "tweaks.recommended"
    }

    It "tem título, resumo e itens em toda página; a lista de ajustes é montada do catálogo" {
        foreach ($page in @(Get-WinForgeNavigation)) {
            $page.Title | Should -Not -BeNullOrEmpty
            $page.Summary | Should -Not -BeNullOrEmpty

            # Na página de ajustes os itens são a barra de ações; a lista de ajustes vem do catálogo.
            @($page.Items).Count | Should -BeGreaterThan 0
        }

        @(Get-WinForgeNavigation | Where-Object { $_.Kind -eq "Tweaks" }) | Should -HaveCount 1
    }

    It "cada item tem rótulo curto e descrição, sem repetir rótulo na mesma página" {
        foreach ($page in @(Get-WinForgeNavigation)) {
            foreach ($item in $page.Items) {
                $item.Label | Should -Not -BeNullOrEmpty
                $item.Label.Length | Should -BeLessThan 45
                $item.Description | Should -Not -BeNullOrEmpty
            }

            (@($page.Items.Label) | Select-Object -Unique) | Should -HaveCount @($page.Items).Count
        }
    }

    It "o rótulo de cada ação é igual ao título que ela mostra ao abrir (o botão clicado e a tela têm o mesmo nome)" {
        $problems = @()

        foreach ($page in @(Get-WinForgeNavigation)) {
            foreach ($item in @($page.Items | Where-Object { $_.Kind -eq "Action" })) {
                $titles = @(Get-NavActionTitle -Command $item.Command)

                if ($titles -notcontains $item.Label) {
                    $problems += "$($item.Id): rótulo '$($item.Label)', títulos da tela: [$($titles -join ' | ')]"
                }
            }
        }

        $problems | Should -HaveCount 0
    }

    It "o rótulo de cada atalho é o nome da janela do Windows que ele abre" {
        foreach ($page in @(Get-WinForgeNavigation)) {
            foreach ($item in @($page.Items | Where-Object { $_.Kind -eq "Shortcut" })) {
                $item.Label | Should -Be (Get-WinForgeShortcutTitle -Name $item.Shortcut)
            }
        }
    }

    It "descrições de atalhos começam com 'Abre' e as demais não (quem lê sabe que vai sair do WinForge)" {
        foreach ($page in @(Get-WinForgeNavigation)) {
            foreach ($item in $page.Items) {
                if ($item.Kind -eq "Shortcut") {
                    $item.Description | Should -Match '^Abre '
                }
                else {
                    $item.Description | Should -Not -Match '^Abre '
                }
            }
        }
    }

    It "o texto que a pessoa lê diz 'programas', nunca 'software', e usa o nome das telas do Windows" {
        foreach ($page in @(Get-WinForgeNavigation)) {
            "$($page.Title) $($page.Summary)" | Should -Not -Match '(?i)\bsoftwares?\b'

            foreach ($item in $page.Items) {
                "$($item.Label) $($item.Description)" | Should -Not -Match '(?i)\bsoftwares?\b'
            }
        }
    }

    It "as descrições são frases curtas, sem ponto final" {
        foreach ($page in @(Get-WinForgeNavigation)) {
            foreach ($item in $page.Items) {
                $item.Description.Length | Should -BeLessThan 120
                $item.Description | Should -Not -Match '\.$'
            }
        }
    }

    It "destaca no máximo um item por página" {
        foreach ($page in @(Get-WinForgeNavigation)) {
            @($page.Items | Where-Object { $_.Accent }).Count | Should -BeLessThan 2
        }
    }

    It "as ações podem ser chamadas sem argumentos (a janela e o menu chamam assim)" {
        foreach ($page in @(Get-WinForgeNavigation)) {
            foreach ($item in @($page.Items | Where-Object { $_.Kind -eq "Action" })) {
                $command = Get-Command -Name $item.Command -CommandType Function

                $mandatory = @($command.Parameters.Values | Where-Object {
                        $_.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] -and $_.Mandatory }
                    })

                $mandatory | Should -HaveCount 0
            }
        }
    }

    It "o Kind do item vem do atalho: com atalho é Shortcut, sem atalho é Action" {
        $action = New-WinForgeNavItem -Id "x.a" -Label "A" -Description "d" -Command "Get-Date"
        $shortcut = New-WinForgeNavItem -Id "x.b" -Label "B" -Description "d" -Shortcut "Storage"

        $action.Kind | Should -Be "Action"
        $shortcut.Kind | Should -Be "Shortcut"
        $shortcut.Accent | Should -BeFalse
    }

    It "busca página e item por Id e devolve nulo quando não existe" {
        (Get-WinForgeNavPage -Id "cleanup").Title | Should -Be "Limpeza"
        (Get-WinForgeNavItem -Id "cleanup.quick").Command | Should -Be "Invoke-WinForgeQuickCleanup"
        Get-WinForgeNavPage -Id "nada" | Should -BeNullOrEmpty
        Get-WinForgeNavItem -Id "nada.nada" | Should -BeNullOrEmpty
    }

    It "a tela inicial oferece atalhos para itens que existem" {
        $homeActions = @(Get-WinForgeHomeActions)

        $homeActions | Should -HaveCount 4
        foreach ($item in $homeActions) { $item | Should -Not -BeNullOrEmpty }
        $homeActions[0].Id | Should -Be "maintenance.recommended"
    }

    It "o Test-WinForgeNavigation acusa Id repetido, função inexistente e atalho desconhecido" {
        try {
            Set-NavigationForTest -Pages @(
                (New-WinForgeNavPage -Id "p" -Title "P" -Summary "s" -Items @(
                    (New-WinForgeNavItem -Id "p.1" -Label "um" -Description "d" -Command "Funcao-Que-Nao-Existe"),
                    (New-WinForgeNavItem -Id "p.1" -Label "dois" -Description "d" -Command "Get-Date"),
                    (New-WinForgeNavItem -Id "p.3" -Label "tres" -Description "d" -Shortcut "AtalhoInventado")
                )),
                (New-WinForgeNavPage -Id "p" -Title "P2" -Summary "s")
            )

            $problems = @(Test-WinForgeNavigation)

            ($problems -join "`n") | Should -Match "Função inexistente em 'p.1'"
            ($problems -join "`n") | Should -Match "Id de item repetido: p.1"
            ($problems -join "`n") | Should -Match "Atalho desconhecido em 'p.3'"
            ($problems -join "`n") | Should -Match "Id de página repetido: p"
        }
        finally { Reset-NavigationForTest }
    }

    It "o Test-WinForgeNavigation acusa descrição de atalho que não começa com 'Abre'" {
        try {
            Set-NavigationForTest -Pages @(
                (New-WinForgeNavPage -Id "p" -Title "P" -Summary "s" -Items @(
                    (New-WinForgeNavItem -Id "p.1" -Label "um" -Description "Mostra a loja" -Shortcut "MicrosoftStore")
                ))
            )

            (@(Test-WinForgeNavigation) -join "`n") | Should -Match "deveria começar com 'Abre'"
        }
        finally { Reset-NavigationForTest }
    }

    It "o tipo de página e o lugar dela só aceitam valores conhecidos" {
        { New-WinForgeNavPage -Id "p" -Title "P" -Summary "s" -Placement Lateral } | Should -Throw
        { New-WinForgeNavPage -Id "p" -Title "P" -Summary "s" -Kind Outro } | Should -Throw
        (New-WinForgeNavPage -Id "p" -Title "P" -Summary "s").Placement | Should -Be "Main"
    }
}

Describe "Tela inicial" {
    BeforeAll {
        function script:Use-HomeStubs {
            param (
                [object]$Session = [PSCustomObject]@{ IsAdmin = $true; User = "PC\ana"; UserMismatch = $false; IsLaptop = $false; WindowsLabel = "Windows 11"; WindowsBuild = 22631 },
                [object]$Space = [PSCustomObject]@{ FreeBytes = 300GB; TotalBytes = 500GB },
                [object]$Reboot = $false,
                [object]$Last = $null
            )

            $global:WfHome = @{ Session = $Session; Space = $Space; Reboot = $Reboot; Last = $Last }

            Set-TestStub -Name "Get-WinForgeSessionInfo" -Body {
                param ([switch]$Refresh)
                if ($global:WfHome.Session -is [string]) { throw $global:WfHome.Session }
                $global:WfHome.Session
            }
            Set-TestStub -Name "Get-WinForgeSystemDriveSpace" -Body { $global:WfHome.Space }
            Set-TestStub -Name "Test-WinForgePendingReboot" -Body {
                if ($global:WfHome.Reboot -is [string]) { throw $global:WfHome.Reboot }
                [bool]$global:WfHome.Reboot
            }
            Set-TestStub -Name "Get-WinForgeLastMaintenance" -Body {
                if ($global:WfHome.Last -is [string]) { throw $global:WfHome.Last }
                $global:WfHome.Last
            }
        }

        function script:Get-HomeFact {
            param ([Parameter(Mandatory)]$Status, [Parameter(Mandatory)][string]$Id)

            return (@($Status.Facts | Where-Object { $_.Id -eq $Id }) | Select-Object -First 1)
        }

        function script:New-LastRun {
            param ([double]$DaysAgo, [string[]]$Kinds = @("Ok", "Ok"))

            [PSCustomObject]@{
                StartedAt = (Get-Date).AddDays(-$DaysAgo)
                Results   = @($Kinds | ForEach-Object { New-WinForgeResult -Kind $_ -Title "Etapa" })
            }
        }
    }

    AfterAll { Remove-Variable WfHome -Scope Global -ErrorAction SilentlyContinue }

    It "mostra os seis fatos na ordem da tela, cada um com o rótulo da tabela" {
        Use-HomeStubs
        try {
            $status = Get-WinForgeHomeStatus
            $labels = Get-WinForgeHomeFactLabels

            (@($status.Facts.Id) -join ",") | Should -Be (@($labels.Keys) -join ",")

            foreach ($fact in $status.Facts) {
                $fact.Label | Should -Be $labels[$fact.Id]
                $fact.Text | Should -Not -BeNullOrEmpty
            }

            $status.Notices | Should -HaveCount 0
        }
        finally { Clear-TestStubs }
    }

    It "Windows, computador e usuário vêm da sessão; notebook e desktop se distinguem" {
        Use-HomeStubs -Session ([PSCustomObject]@{ IsAdmin = $true; User = "PC\ana"; UserMismatch = $false; IsLaptop = $true; WindowsLabel = "Windows 10"; WindowsBuild = 19045 })
        try {
            $status = Get-WinForgeHomeStatus

            (Get-HomeFact $status "windows").Text | Should -Be "Windows 10 (build 19045)"
            (Get-HomeFact $status "computer").Text | Should -Match "Notebook"
            (Get-HomeFact $status "user").Text | Should -Be "PC\ana"
        }
        finally { Clear-TestStubs }
    }

    It "usuário elevado com outra conta gera um aviso, sem apagar os fatos" {
        Use-HomeStubs -Session ([PSCustomObject]@{ IsAdmin = $true; User = "PC\admin"; UserMismatch = $true; IsLaptop = $false; WindowsLabel = "Windows 11"; WindowsBuild = 22631 })
        try {
            $status = Get-WinForgeHomeStatus

            @($status.Notices) | Should -HaveCount 1
            $status.Notices[0].Level | Should -Be "Warn"
            $status.Notices[0].Text | Should -Match "PC\\admin"
            @($status.Facts) | Should -HaveCount 6
        }
        finally { Clear-TestStubs }
    }

    It "sem ler a sessão, o Windows fica como não lido e o resto continua" {
        Use-HomeStubs -Session "sem resposta"
        try {
            $status = Get-WinForgeHomeStatus

            (Get-HomeFact $status "windows").Text | Should -Be "Não foi possível ler"
            (Get-HomeFact $status "windows").Level | Should -Be "Muted"
            @($status.Facts) | Should -HaveCount 6
            (Get-HomeFact $status "disk").Level | Should -Be "Normal"
        }
        finally { Clear-TestStubs }
    }

    It "disco do sistema: <Name>" -ForEach @(
        @{ Name = "espaço confortável"; Free = 300GB; Total = 500GB; Level = "Normal"; Match = "livres de"; NotMatch = "pouco|crítico" },
        @{ Name = "menos de 10% livres avisa"; Free = 40GB; Total = 500GB; Level = "Warn"; Match = "pouco espaço"; NotMatch = "crítico" },
        @{ Name = "menos de 5 GB livres é crítico"; Free = 3GB; Total = 500GB; Level = "Warn"; Match = "espaço crítico"; NotMatch = "pouco espaço" }
    ) {
        Use-HomeStubs -Space ([PSCustomObject]@{ FreeBytes = $Free; TotalBytes = $Total })
        try {
            $fact = Get-HomeFact (Get-WinForgeHomeStatus) "disk"

            $fact.Level | Should -Be $Level
            $fact.Text | Should -Match $Match
            $fact.Text | Should -Not -Match $NotMatch
        }
        finally { Clear-TestStubs }
    }

    It "disco do sistema ilegível vira texto neutro, não erro" {
        Use-HomeStubs -Space $null
        try {
            $fact = Get-HomeFact (Get-WinForgeHomeStatus) "disk"

            $fact.Text | Should -Be "Não foi possível ler"
            $fact.Level | Should -Be "Muted"
        }
        finally { Clear-TestStubs }
    }

    It "reinício pendente: sim avisa, não confirma, erro fica neutro" -ForEach @(
        @{ Reboot = $true; Level = "Warn"; Match = "^Sim" },
        @{ Reboot = $false; Level = "Ok"; Match = "^Não$" },
        @{ Reboot = "falhou"; Level = "Muted"; Match = "Não foi possível ler" }
    ) {
        Use-HomeStubs -Reboot $Reboot
        try {
            $fact = Get-HomeFact (Get-WinForgeHomeStatus) "reboot"

            $fact.Level | Should -Be $Level
            $fact.Text | Should -Match $Match
        }
        finally { Clear-TestStubs }
    }

    It "última manutenção: nunca executada" {
        Use-HomeStubs -Last $null
        try {
            $fact = Get-HomeFact (Get-WinForgeHomeStatus) "maintenance"

            $fact.Text | Should -Be "Ainda não executada"
            $fact.Level | Should -Be "Muted"
        }
        finally { Clear-TestStubs }
    }

    It "última manutenção recente e sem problemas mostra há quanto tempo, em tom normal" {
        Use-HomeStubs -Last (New-LastRun -DaysAgo 3)
        try {
            $fact = Get-HomeFact (Get-WinForgeHomeStatus) "maintenance"

            $fact.Text | Should -Match "^há 3 dias \("
            $fact.Text | Should -Not -Match "atenção|mês"
            $fact.Level | Should -Be "Normal"
        }
        finally { Clear-TestStubs }
    }

    It "última manutenção com ressalvas ou falhas conta quantas etapas pedem atenção" {
        Use-HomeStubs -Last (New-LastRun -DaysAgo 1 -Kinds @("Ok", "Warning", "Failed", "Skipped"))
        try {
            $fact = Get-HomeFact (Get-WinForgeHomeStatus) "maintenance"

            $fact.Text | Should -Match "2 com atenção"
            $fact.Level | Should -Be "Warn"
        }
        finally { Clear-TestStubs }
    }

    It "última manutenção com mais de um mês lembra de repetir" {
        Use-HomeStubs -Last (New-LastRun -DaysAgo 45)
        try {
            $fact = Get-HomeFact (Get-WinForgeHomeStatus) "maintenance"

            $fact.Text | Should -Match "já passou de um mês"
            $fact.Level | Should -Be "Warn"
        }
        finally { Clear-TestStubs }
    }

    It "histórico ilegível fica neutro" {
        Use-HomeStubs -Last "arquivo corrompido"
        try {
            $fact = Get-HomeFact (Get-WinForgeHomeStatus) "maintenance"

            $fact.Text | Should -Be "Não foi possível ler"
            $fact.Level | Should -Be "Muted"
        }
        finally { Clear-TestStubs }
    }

    It "todo fato tem um nível conhecido, mesmo quando tudo falha" {
        Use-HomeStubs -Session "x" -Space $null -Reboot "x" -Last "x"
        try {
            $status = Get-WinForgeHomeStatus

            @($status.Facts) | Should -HaveCount 6
            foreach ($fact in $status.Facts) { $fact.Level | Should -BeIn @("Normal", "Ok", "Warn", "Muted") }
        }
        finally { Clear-TestStubs }
    }
}

Describe "Menus do console" {
    It "a leitura da opção devolve nulo quando a entrada acaba, em vez de repetir para sempre" {
        try {
            Set-FakeReadHost -Answers @()
            $options = @(@{ Key = "1"; Label = "Um" }, @{ Key = "0"; Label = "Sair" })

            $null = Get-HostText { $script:Key = Read-WinForgeMenuKey -Options $options }

            $script:Key | Should -BeNullOrEmpty
        }
        finally { Clear-FakeReadHost }
    }

    It "o menu principal sai com 0 e também quando a entrada acaba" -ForEach @(
        @{ Answers = @("0") },
        @{ Answers = @() }
    ) {
        try {
            Set-FakeReadHost -Answers $Answers
            $text = Get-HostText { Show-WinForgeMainMenu }

            $text | Should -Match "Saindo do WinForge"
        }
        finally { Clear-FakeReadHost }
    }

    It "lista as páginas na ordem da tabela, com o rótulo da opção de sair" {
        try {
            Set-FakeReadHost -Answers @("0")
            $text = Get-HostText { Show-WinForgeMainMenu }

            # O resumo de cada página só aparece no próprio item do menu (o título também aparece no cabeçalho).
            # Cada resumo precisa ser encontrado depois do anterior, na ordem da tabela.
            $position = -1
            $outOfOrder = @()

            foreach ($page in @(Get-WinForgeNavigation)) {
                $found = $text.IndexOf($page.Summary, $position + 1, [StringComparison]::Ordinal)

                if ($found -lt 0) { $outOfOrder += $page.Id } else { $position = $found }
            }

            $outOfOrder | Should -HaveCount 0
            $text | Should -Match "Sair"
        }
        finally { Clear-FakeReadHost }
    }

    It "entrar numa página e voltar não executa nada" {
        Use-MenuStubs
        try {
            Set-FakeReadHost -Answers @("2", "0", "0")
            $text = Get-HostText { Show-WinForgeMainMenu }

            $text | Should -Match "Sobre este PC"
            $global:WfLog | Should -HaveCount 0
        }
        finally { Clear-FakeReadHost; Clear-TestStubs }
    }

    It "o número escolhido dentro da página executa o item certo" {
        Use-MenuStubs
        try {
            # 1 = Manutenção, 1 = Manutenção recomendada, 0 = voltar, 0 = sair
            Set-FakeReadHost -Answers @("1", "1", "0", "0")
            [void](Get-HostText { Show-WinForgeMainMenu })
            ($global:WfLog -join ",") | Should -Be "manutencao"

            # 2 = Diagnóstico, 1 = Sobre este PC
            $global:WfLog.Clear()
            Set-FakeReadHost -Answers @("2", "1", "0", "0")
            [void](Get-HostText { Show-WinForgeMainMenu })
            ($global:WfLog -join ",") | Should -Be "sobre"
        }
        finally { Clear-FakeReadHost; Clear-TestStubs }
    }

    It "a última página do menu (Sobre o WinForge) mostra a versão e cria o atalho" {
        Use-MenuStubs
        try {
            $number = @(Get-WinForgeNavigation).Count

            # 1 = Versão e pastas, 2 = Criar atalho do WinForge
            Set-FakeReadHost -Answers @([string]$number, "2", "0", "0")
            [void](Get-HostText { Show-WinForgeMainMenu })
            ($global:WfLog -join ",") | Should -Be "atalho-do-winforge"

            $global:WfLog.Clear()
            Set-FakeReadHost -Answers @([string]$number, "1", "0", "0")
            [void](Get-HostText { Show-WinForgeMainMenu })
            ($global:WfLog -join ",") | Should -Be "versao-e-pastas"
        }
        finally { Clear-FakeReadHost; Clear-TestStubs }
    }

    It "itens de atalho abrem a janela do Windows" {
        Use-MenuStubs
        try {
            $diagnostics = Get-WinForgeNavPage -Id "diagnostics"
            $number = [array]::IndexOf(@($diagnostics.Items.Id), "diagnostics.device-manager") + 1

            Set-FakeReadHost -Answers @("2", [string]$number, "", "0", "0")
            [void](Get-HostText { Show-WinForgeMainMenu })

            $global:WfLog | Should -Contain "abrir:DeviceManager"
        }
        finally { Clear-FakeReadHost; Clear-TestStubs }
    }

    It "opção inválida não executa nada e o menu continua funcionando" {
        Use-MenuStubs
        try {
            Set-FakeReadHost -Answers @("99", "abc", "0")
            $text = Get-HostText { Show-WinForgeMainMenu }

            $text | Should -Match "Opção inválida"
            $global:WfLog | Should -HaveCount 0
        }
        finally { Clear-FakeReadHost; Clear-TestStubs }
    }

    It "um erro dentro de uma ação vira mensagem e o menu continua" {
        function global:Test-NavBoom { throw "falhou de propósito" }
        try {
            $item = New-WinForgeNavItem -Id "t.boom" -Label "Quebra" -Description "d" -Command "Test-NavBoom"
            Set-FakeReadHost -Answers @("")   # "pressione uma tecla"
            $text = Get-HostText { Invoke-WinForgeNavItem -Item $item }

            $text | Should -Match "Ocorreu um erro em 'Quebra': falhou de propósito"
        }
        finally { Clear-FakeReadHost; Remove-Item Function:\global:Test-NavBoom -ErrorAction SilentlyContinue }
    }

    It "o menu de ajustes numera os ajustes na ordem do catálogo e aplica o escolhido" {
        Use-MenuStubs
        try {
            $overview = @(Get-WinForgeTweakOverview)

            Set-FakeReadHost -Answers @("2", "0")
            $text = Get-HostText { Show-WinForgeTweaksMenu }

            ($global:WfLog -join ",") | Should -Be ("toggle:" + $overview[1].Id)

            # Os nomes das ações vêm da tabela de navegação, os mesmos dos botões da janela.
            foreach ($item in (Get-WinForgeNavPage -Id "tweaks").Items) {
                $text | Should -Match ([regex]::Escape($item.Label))
            }
        }
        finally { Clear-FakeReadHost; Clear-TestStubs }
    }

    It "R, P e D do menu de ajustes chamam recomendados, ponto de restauração e desfazer tudo" {
        Use-MenuStubs
        try {
            Set-FakeReadHost -Answers @("r", "P", "d", "0")
            [void](Get-HostText { Show-WinForgeTweaksMenu })

            ($global:WfLog -join ",") | Should -Be "recomendados,ponto-de-restauracao,desfazer-tudo"
        }
        finally { Clear-FakeReadHost; Clear-TestStubs }
    }

    It "o menu de ajustes sai com a entrada encerrada" {
        try {
            Set-FakeReadHost -Answers @()
            { $null = Get-HostText { Show-WinForgeTweaksMenu } } | Should -Not -Throw
        }
        finally { Clear-FakeReadHost }
    }
}
