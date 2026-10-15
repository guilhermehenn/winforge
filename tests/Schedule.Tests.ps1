# Manutenção agendada: o XML da tarefa, o estado no Agendador de Tarefas, criar/remover e a execução sem perguntas.
# O Agendador de Tarefas (Register-ScheduledTask e companhia) é substituído por versões de teste: nada é agendado de verdade.

BeforeAll {
    . (Join-Path $PSScriptRoot "TestSetup.ps1")

    function script:Use-ScheduleStubs {
        param (
            [switch]$NotAdmin,
            [switch]$RegisterFails,
            [switch]$UnregisterFails,
            [string]$InteractiveUser = "PC-DA-CASA\maria",
            $Installed = $null
        )

        $global:WfLog = New-Object System.Collections.ArrayList
        $global:WfXml = ""
        $global:WfAdmin = -not $NotAdmin
        $global:WfRegisterFails = [bool]$RegisterFails
        $global:WfUnregisterFails = [bool]$UnregisterFails
        $global:WfInteractive = $InteractiveUser
        $global:WfInstalled = $Installed

        # No modo estrito os módulos rodam de uma cópia em outra pasta; a pasta do WinForge é simulada para o teste valer nos dois.
        $appRoot = Join-Path $script:TestDataRoot "WinForge instalado"
        New-Item -ItemType Directory -Path $appRoot -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $appRoot "WinForge.Console.ps1") -Value "x"
        $global:WfAppRoot = $appRoot

        Set-TestStub -Name "Get-WinForgeAppRoot" -Body { $global:WfAppRoot }
        Set-TestStub -Name "Test-WinForgeAdministrator" -Body { [bool]$global:WfAdmin }
        Set-TestStub -Name "Get-WinForgeInteractiveUser" -Body { $global:WfInteractive }
        Set-TestStub -Name "Wait-WinForgeKey" -Body { }
        Set-TestStub -Name "Register-ScheduledTask" -Body {
            [CmdletBinding()] param ($Xml, $TaskPath, $TaskName, [switch]$Force)
            if ($global:WfRegisterFails) { throw "Acesso negado" }
            $global:WfXml = $Xml
            [void]$global:WfLog.Add("register:${TaskPath}${TaskName}:force=$([bool]$Force)")
        }
        Set-TestStub -Name "Unregister-ScheduledTask" -Body {
            [CmdletBinding()] param ($TaskPath, $TaskName, $Confirm)
            if ($global:WfUnregisterFails) { throw "Tarefa não encontrada" }
            [void]$global:WfLog.Add("unregister:${TaskPath}${TaskName}:confirm=$Confirm")
        }
        Set-TestStub -Name "Get-ScheduledTask" -Body {
            [CmdletBinding()] param ($TaskPath, $TaskName)
            if ($null -eq $global:WfInstalled) { throw "Não existe tarefa com esse nome" }
            [PSCustomObject]@{ State = $global:WfInstalled.State }
        }
        Set-TestStub -Name "Export-ScheduledTask" -Body {
            [CmdletBinding()] param ($TaskPath, $TaskName)
            "<Task xmlns=`"http://schemas.microsoft.com/windows/2004/02/mit/task`"><Triggers><CalendarTrigger><ScheduleByMonth><DaysOfMonth><Day>$($global:WfInstalled.Day)</Day></DaysOfMonth></ScheduleByMonth></CalendarTrigger></Triggers></Task>"
        }
        Set-TestStub -Name "Get-ScheduledTaskInfo" -Body {
            [CmdletBinding()] param ($TaskPath, $TaskName)
            [PSCustomObject]@{ LastRunTime = $global:WfInstalled.LastRun; NextRunTime = $global:WfInstalled.NextRun; LastTaskResult = $global:WfInstalled.Result }
        }
    }

    function script:New-InstalledTask {
        param ([int]$Day = 15, [string]$State = "Ready", $LastRun = [datetime]"1999-11-30", $NextRun = $null, [int]$Result = 267011)

        if ($null -eq $NextRun) { $NextRun = (Get-Date).Date.AddDays(10).AddHours(12) }

        [PSCustomObject]@{ Day = $Day; State = $State; LastRun = $LastRun; NextRun = $NextRun; Result = $Result }
    }

    function script:Use-RunStubs {
        param ([switch]$Admin, [switch]$UserTempFails, [switch]$ReportFails)

        $global:WfLog = New-Object System.Collections.ArrayList
        $global:WfAdmin = [bool]$Admin
        $global:WfUserTempFails = [bool]$UserTempFails
        $global:WfReportFails = [bool]$ReportFails

        Set-TestStub -Name "Test-WinForgeAdministrator" -Body { [bool]$global:WfAdmin }
        Set-TestStub -Name "Clear-WinForgeUserTemp" -Body {
            param ([switch]$Embedded, [switch]$PassThru)
            [void]$global:WfLog.Add("temp-do-usuario")
            if ($global:WfUserTempFails) { return (New-WinForgeResult -Kind Failed -Detail "pasta recusada") }
            New-WinForgeResult -Kind Ok -Data @{ FreedBytes = [int64]300MB }
        }
        Set-TestStub -Name "Clear-WinForgeWindowsTemp" -Body {
            param ([switch]$Embedded, [switch]$PassThru)
            [void]$global:WfLog.Add("temp-do-windows")
            New-WinForgeResult -Kind Ok -Data @{ FreedBytes = [int64]200MB }
        }
        Set-TestStub -Name "Clear-WinForgeRecycleBin" -Body { [void]$global:WfLog.Add("LIXEIRA"); New-WinForgeResult -Kind Ok }
        Set-TestStub -Name "Invoke-WinForgeQuickCleanup" -Body { [void]$global:WfLog.Add("LIMPEZA-RAPIDA"); New-WinForgeResult -Kind Ok }
        Set-TestStub -Name "Export-WinForgeReport" -Body {
            if ($global:WfReportFails) { throw "disco cheio" }
            [void]$global:WfLog.Add("relatorio")
            [PSCustomObject]@{ Html = "C:\relatorios\winforge.html"; Text = "C:\relatorios\winforge.txt" }
        }
    }

    function script:Reset-ScheduleTest {
        Clear-TestStubs
        Clear-FakeReadHost
        Remove-Variable WfLog, WfXml, WfAdmin, WfRegisterFails, WfUnregisterFails, WfInteractive, WfInstalled, WfAppRoot, WfUserTempFails, WfReportFails, WinForgeGuiMode -Scope Global -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath (Get-WinForgeScheduledRunPath) -Force -ErrorAction SilentlyContinue
    }

    function script:New-TaskXmlForTest {
        param ([int]$Day = 1, [string]$Executable = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe", [string]$Arguments = "-File x.ps1", [string]$WorkingDirectory = "C:\WinForge", [string]$User = "PC\maria", $Start = [datetime]"2026-11-02T12:00:00")

        [xml](New-WinForgeScheduleTaskXml -Executable $Executable -Arguments $Arguments -WorkingDirectory $WorkingDirectory -UserId $User -DayOfMonth $Day -Start $Start)
    }
}

AfterAll {
    Remove-WinForgeTestData
}

Describe "XML da tarefa" {
    It "agenda todo mês no dia escolhido, às 12h, a partir da data de início" {
        $xml = New-TaskXmlForTest -Day 15

        $xml.Task.Triggers.CalendarTrigger.StartBoundary | Should -Be "2026-11-02T12:00:00"
        $xml.Task.Triggers.CalendarTrigger.ScheduleByMonth.DaysOfMonth.Day | Should -Be "15"
        @($xml.Task.Triggers.CalendarTrigger.ScheduleByMonth.Months.ChildNodes) | Should -HaveCount 12
        $xml.Task.Triggers.CalendarTrigger.Enabled | Should -Be "true"
    }

    It "por padrão a primeira execução é de amanhã em diante, nunca na hora de criar" {
        $xml = [xml](New-WinForgeScheduleTaskXml -Executable "p.exe" -Arguments "a" -WorkingDirectory "C:\w" -UserId "PC\maria")
        $start = [datetime]$xml.Task.Triggers.CalendarTrigger.StartBoundary

        $start | Should -BeGreaterThan (Get-Date)
        $start.Hour | Should -Be 12
    }

    It "roda sem elevação, com o usuário logado" {
        $xml = New-TaskXmlForTest -User "PC-DA-CASA\maria"

        $xml.Task.Principals.Principal.UserId | Should -Be "PC-DA-CASA\maria"
        $xml.Task.Principals.Principal.LogonType | Should -Be "InteractiveToken"
        $xml.Task.Principals.Principal.RunLevel | Should -Be "LeastPrivilege"
    }

    It "se o PC estava desligado roda depois, não começa nem continua na bateria, e tem prazo de uma hora" {
        $settings = (New-TaskXmlForTest).Task.Settings

        $settings.StartWhenAvailable | Should -Be "true"
        $settings.DisallowStartIfOnBatteries | Should -Be "true"
        $settings.StopIfGoingOnBatteries | Should -Be "true"
        $settings.WakeToRun | Should -Be "false"
        $settings.MultipleInstancesPolicy | Should -Be "IgnoreNew"
        $settings.ExecutionTimeLimit | Should -Be "PT1H"
    }

    It "o comando, os argumentos e a pasta de trabalho chegam intactos, mesmo com &, aspas e < no caminho" {
        $arguments = '-File "C:\Users\Zé & Cia\<WinForge>\WinForge.Console.ps1" -Action ScheduledMaintenance'
        $xml = New-TaskXmlForTest -Arguments $arguments -WorkingDirectory 'C:\Users\Zé & Cia\<WinForge>' -User 'DOMINIO\ana&bia'

        $xml.Task.Actions.Exec.Arguments | Should -Be $arguments
        $xml.Task.Actions.Exec.WorkingDirectory | Should -Be 'C:\Users\Zé & Cia\<WinForge>'
        $xml.Task.Principals.Principal.UserId | Should -Be 'DOMINIO\ana&bia'
    }

    It "descreve o que a tarefa faz e como removê-la" {
        $description = (New-TaskXmlForTest).Task.RegistrationInfo.Description

        $description | Should -Match "não esvazia a Lixeira"
        $description | Should -Match "Manutenção agendada"
    }

    It "só aceita os dias de 1 a 28 (existem em todos os meses)" -ForEach @(@{ Day = 0 }, @{ Day = 29 }, @{ Day = 31 }, @{ Day = -1 }) {
        { New-WinForgeScheduleTaskXml -Executable "p.exe" -Arguments "a" -WorkingDirectory "C:\w" -UserId "u" -DayOfMonth $Day } | Should -Throw
    }
}

Describe "Comando da tarefa" {
    It "executa o script do terminal com a ação ScheduledMaintenance, escondido e com o caminho entre aspas" {
        $root = Join-Path $script:TestDataRoot "pasta com espaço"
        New-Item -ItemType Directory -Path $root -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $root "WinForge.Console.ps1") -Value "x"

        $command = Get-WinForgeScheduleCommand -Root $root

        $command.Arguments | Should -Match "-WindowStyle Hidden"
        $command.Arguments | Should -Match "-ExecutionPolicy Bypass"
        $command.Arguments | Should -Match ('-File "' + [regex]::Escape((Join-Path $root "WinForge.Console.ps1")) + '"')
        $command.Arguments | Should -Match "-Action ScheduledMaintenance$"
        $command.WorkingDirectory | Should -Be $root
        $command.Executable | Should -Match "powershell"
    }

    It "pasta sem o script falha com uma mensagem clara, em vez de criar uma tarefa quebrada" {
        { Get-WinForgeScheduleCommand -Root (Join-Path $script:TestDataRoot "vazia") } | Should -Throw -ExpectedMessage "*WinForge.Console.ps1*"
    }

    It "o script do terminal aceita a ação e não pede Administrador para ela" {
        $text = Get-Content -LiteralPath (Join-Path $script:RepoRoot "WinForge.Console.ps1") -Raw

        $text | Should -Match '\[ValidateSet\([^)]*"ScheduledMaintenance"'
        $text | Should -Match '-notin "Shortcut", "ScheduledMaintenance"'
    }
}

Describe "Estado da tarefa" {
    AfterEach { Reset-ScheduleTest }

    It "sem tarefa: não instalada" {
        Use-ScheduleStubs

        $status = Get-WinForgeScheduleStatus

        $status.Installed | Should -BeFalse
        $status.Day | Should -BeNullOrEmpty
    }

    It "com tarefa: dia, próxima execução e resultado da última" {
        $next = (Get-Date).Date.AddDays(5).AddHours(12)
        Use-ScheduleStubs -Installed (New-InstalledTask -Day 28 -LastRun (Get-Date).AddDays(-20) -NextRun $next -Result 0)

        $status = Get-WinForgeScheduleStatus

        $status.Installed | Should -BeTrue
        $status.Enabled | Should -BeTrue
        $status.Day | Should -Be 28
        $status.NextRun | Should -Be $next
        $status.LastRun | Should -Not -BeNullOrEmpty
        $status.LastResult | Should -Be 0
    }

    It "datas de 'nunca' do Agendador (1999) viram nulo" {
        Use-ScheduleStubs -Installed (New-InstalledTask -LastRun ([datetime]"1999-11-30") -NextRun ([datetime]"1999-11-30"))

        $status = Get-WinForgeScheduleStatus

        $status.LastRun | Should -BeNullOrEmpty
        $status.NextRun | Should -BeNullOrEmpty
    }

    It "tarefa desativada no Agendador aparece como não habilitada" {
        Use-ScheduleStubs -Installed (New-InstalledTask -State "Disabled")

        $status = Get-WinForgeScheduleStatus

        $status.Installed | Should -BeTrue
        $status.Enabled | Should -BeFalse
    }

    It "códigos de resultado em português" -ForEach @(
        @{ Code = 0; Text = "terminou bem" }, @{ Code = 267011; Text = "ainda não executou" },
        @{ Code = 267009; Text = "em execução agora" }, @{ Code = 2147942402; Text = "código 0x80070002" }
    ) {
        ConvertTo-WinForgeScheduleResultText -Code $Code | Should -Match $Text
    }
}

Describe "Criar e remover" {
    AfterEach { Reset-ScheduleTest }

    It "cria a tarefa no dia escolhido, para o usuário logado e substituindo a anterior" {
        Use-ScheduleStubs

        $text = Get-HostText { $script:Result = Register-WinForgeScheduledMaintenance -Day 15 }

        $script:Result.Kind | Should -Be "Ok"
        $global:WfLog | Should -Be @("register:\WinForge\Manutencao-Mensal:force=True")
        ([xml]$global:WfXml).Task.Triggers.CalendarTrigger.ScheduleByMonth.DaysOfMonth.Day | Should -Be "15"
        ([xml]$global:WfXml).Task.Principals.Principal.UserId | Should -Be "PC-DA-CASA\maria"
        ([xml]$global:WfXml).Task.Principals.Principal.RunLevel | Should -Be "LeastPrivilege"
        $text | Should -Match "todo dia 15"
    }

    It "sem usuário logado identificado usa a conta atual" {
        Use-ScheduleStubs -InteractiveUser ""

        [void](Get-HostText { $script:Result = Register-WinForgeScheduledMaintenance -Day 1 })

        if ($script:Result.Kind -eq "Ok") {
            ([xml]$global:WfXml).Task.Principals.Principal.UserId | Should -Not -BeNullOrEmpty
        }
        else {
            $script:Result.Detail | Should -Match "usuário"
        }
    }

    It "sem Administrador não cria nada" {
        Use-ScheduleStubs -NotAdmin

        [void](Get-HostText { $script:Result = Register-WinForgeScheduledMaintenance -Day 1 })

        $script:Result.Kind | Should -Be "Failed"
        $global:WfLog | Should -HaveCount 0
    }

    It "falha do Agendador vira 'Falhou' com a causa, sem exceção" {
        Use-ScheduleStubs -RegisterFails

        $text = Get-HostText { $script:Result = Register-WinForgeScheduledMaintenance -Day 1 }

        $script:Result.Kind | Should -Be "Failed"
        $text | Should -Match "Acesso negado"
    }

    It "remove a tarefa sem pedir confirmação do Windows" {
        Use-ScheduleStubs

        $text = Get-HostText { $script:Result = Unregister-WinForgeScheduledMaintenance }

        $script:Result.Kind | Should -Be "Ok"
        $global:WfLog | Should -Be @("unregister:\WinForge\Manutencao-Mensal:confirm=False")
        $text | Should -Match "Nada mais vai rodar sozinho"
    }

    It "remover sem Administrador ou com erro do Agendador falha com mensagem" {
        Use-ScheduleStubs -NotAdmin
        [void](Get-HostText { $script:Result = Unregister-WinForgeScheduledMaintenance })
        $script:Result.Kind | Should -Be "Failed"
        $global:WfLog | Should -HaveCount 0

        Reset-ScheduleTest
        Use-ScheduleStubs -UnregisterFails
        $text = Get-HostText { $script:Result = Unregister-WinForgeScheduledMaintenance }
        $script:Result.Kind | Should -Be "Failed"
        $text | Should -Match "Tarefa não encontrada"
    }
}

Describe "Execução agendada" {
    AfterEach { Reset-ScheduleTest }

    It "sem privilégios: limpa só os temporários do usuário e salva o relatório" {
        Use-RunStubs

        [void](Get-HostText { $script:Result = Invoke-WinForgeScheduledMaintenance })

        $global:WfLog | Should -Be @("temp-do-usuario", "relatorio")
        $script:Result.Kind | Should -Be "Ok"
        (Get-WinForgeResultData -Result $script:Result -Name "FreedBytes") | Should -Be 300MB
    }

    It "nunca esvazia a Lixeira, nem como Administrador" {
        Use-RunStubs -Admin

        [void](Get-HostText { $script:Result = Invoke-WinForgeScheduledMaintenance })

        $global:WfLog | Should -Not -Contain "LIXEIRA"
        $global:WfLog | Should -Not -Contain "LIMPEZA-RAPIDA"
        $global:WfLog | Should -Contain "temp-do-windows"
        (Get-WinForgeResultData -Result $script:Result -Name "FreedBytes") | Should -Be 500MB
    }

    It "limpeza que falha ou relatório que falha vira ressalva, e o resto continua" {
        Use-RunStubs -UserTempFails

        [void](Get-HostText { $script:Result = Invoke-WinForgeScheduledMaintenance })
        $script:Result.Kind | Should -Be "Warning"
        $global:WfLog | Should -Contain "relatorio"

        Reset-ScheduleTest
        Use-RunStubs -ReportFails
        $text = Get-HostText { $script:Result = Invoke-WinForgeScheduledMaintenance }
        $script:Result.Kind | Should -Be "Warning"
        $text | Should -Match "disco cheio"
        $global:WfLog | Should -Contain "temp-do-usuario"
    }

    It "grava o registro da execução, que a tela lê depois" {
        Use-RunStubs

        [void](Get-HostText { $script:Result = Invoke-WinForgeScheduledMaintenance })
        $run = Get-WinForgeScheduledRun

        $run.Kind | Should -Be "Ok"
        $run.FreedBytes | Should -Be 300MB
        $run.Report | Should -Be "C:\relatorios\winforge.html"
        ((Get-Date) - $run.RunAt).TotalMinutes | Should -BeLessThan 2
    }

    It "registro inexistente ou corrompido: nunca rodou" -ForEach @(@{ Content = $null }, @{ Content = "{ lixo" }, @{ Content = '{"RunAt":"data inválida"}' }) {
        Remove-Item -LiteralPath (Get-WinForgeScheduledRunPath) -Force -ErrorAction SilentlyContinue
        if ($null -ne $Content) { Set-Content -LiteralPath (Get-WinForgeScheduledRunPath) -Value $Content -Encoding UTF8 }

        Get-WinForgeScheduledRun | Should -BeNullOrEmpty
    }

    It "não pergunta nada: nenhuma leitura do teclado" {
        Use-RunStubs
        Set-FakeReadHost -Answers @()

        { Get-HostText { $script:Result = Invoke-WinForgeScheduledMaintenance } } | Should -Not -Throw
    }
}

Describe "Tela Manutenção agendada" {
    AfterEach { Reset-ScheduleTest }

    It "não agendada: explica o que faz e o que não faz, e oferece os três dias" {
        Use-ScheduleStubs
        Set-FakeReadHost -Answers @("V")

        $text = Get-HostText { Show-WinForgeScheduledMaintenance }

        $text | Should -Match "Manutenção agendada"
        $text | Should -Match "Não agendado"
        $text | Should -Match "esvaziar a Lixeira"
        $text | Should -Match "Todo dia 1\b"
        $text | Should -Match "Todo dia 15"
        $text | Should -Match "Todo dia 28"
        $text | Should -Not -Match "Remover o agendamento"
        $global:WfLog | Should -HaveCount 0
    }

    It "escolher um dia cria a tarefa" {
        Use-ScheduleStubs
        Set-FakeReadHost -Answers @("D15")

        $text = Get-HostText { Show-WinForgeScheduledMaintenance }

        $global:WfLog | Should -Be @("register:\WinForge\Manutencao-Mensal:force=True")
        ([xml]$global:WfXml).Task.Triggers.CalendarTrigger.ScheduleByMonth.DaysOfMonth.Day | Should -Be "15"
        $text | Should -Match "agendada para todo dia 15"
    }

    It "ENTER (sem escolher) não agenda nada" {
        Use-ScheduleStubs
        Set-FakeReadHost -Answers @("")

        [void](Get-HostText { Show-WinForgeScheduledMaintenance })

        $global:WfLog | Should -HaveCount 0
    }

    It "agendada: mostra dia, próxima execução e última execução, e marca o dia atual" {
        Use-ScheduleStubs -Installed (New-InstalledTask -Day 28)
        Set-FakeReadHost -Answers @("V")
        $run = [ordered]@{ RunAt = (Get-Date).AddDays(-3).ToString("o"); Kind = "Ok"; FreedBytes = [int64]1536MB; Report = "C:\r.html" }
        Set-Content -LiteralPath (Get-WinForgeScheduledRunPath) -Value ($run | ConvertTo-Json) -Encoding UTF8

        $text = Get-HostText { Show-WinForgeScheduledMaintenance }

        $text | Should -Match "Ativo \(todo dia 28, às 12h\)"
        $text | Should -Match "Próxima execução"
        $text | Should -Match "há 3 dias\), liberou 1\.5 GB"
        $text | Should -Match "Todo dia 28 \(atual\)"
        $text | Should -Match "Remover o agendamento"
    }

    It "agendada mas nunca executou: diz isso" {
        Use-ScheduleStubs -Installed (New-InstalledTask)
        Set-FakeReadHost -Answers @("V")

        (Get-HostText { Show-WinForgeScheduledMaintenance }) | Should -Match "Ainda não executou"
    }

    It "R remove o agendamento" {
        Use-ScheduleStubs -Installed (New-InstalledTask)
        Set-FakeReadHost -Answers @("r")

        [void](Get-HostText { Show-WinForgeScheduledMaintenance })

        $global:WfLog | Should -Be @("unregister:\WinForge\Manutencao-Mensal:confirm=False")
    }

    It "trocar o dia de uma tarefa existente recria a tarefa com o novo dia" {
        Use-ScheduleStubs -Installed (New-InstalledTask -Day 1)
        Set-FakeReadHost -Answers @("D28")

        [void](Get-HostText { Show-WinForgeScheduledMaintenance })

        ([xml]$global:WfXml).Task.Triggers.CalendarTrigger.ScheduleByMonth.DaysOfMonth.Day | Should -Be "28"
    }

    It "sem Administrador a escolha mostra o motivo e não cria nada" {
        Use-ScheduleStubs -NotAdmin
        Set-FakeReadHost -Answers @("D1")

        $text = Get-HostText { Show-WinForgeScheduledMaintenance }

        $text | Should -Match "exige privilégios de Administrador"
        $global:WfLog | Should -HaveCount 0
    }
}
