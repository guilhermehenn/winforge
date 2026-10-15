# Núcleo e console: seleção numerada, formatação, linha de comando, histórico, perguntas e programas nativos.

BeforeAll {
    . (Join-Path $PSScriptRoot "TestSetup.ps1")
}

AfterAll {
    Remove-WinForgeTestData
}

Describe "Seleção numerada" {
    It "aceita números e intervalos" {
        (ConvertTo-WinForgeSelectionIndexes -InputText "1, 3-5, 3" -Maximum 10) -join "," | Should -Be "1,3,4,5"
    }

    It "aceita espaço, ponto e vírgula e hífen com espaços" -ForEach @(
        @{ Text = "1 3 5"; Expected = "1,3,5" },
        @{ Text = "1;2"; Expected = "1,2" },
        @{ Text = "2 - 4"; Expected = "2,3,4" },
        @{ Text = " 1 ,, 2 "; Expected = "1,2" },
        @{ Text = "10"; Expected = "10" }
    ) {
        (ConvertTo-WinForgeSelectionIndexes -InputText $Text -Maximum 10) -join "," | Should -Be $Expected
    }

    It "rejeita número fora da lista, inclusive zero" -ForEach @(
        @{ Text = "11" }, @{ Text = "0" }, @{ Text = "1,0" }, @{ Text = "9-11" }
    ) {
        { ConvertTo-WinForgeSelectionIndexes -InputText $Text -Maximum 10 } | Should -Throw
    }

    It "rejeita intervalo invertido, texto e formatos incompletos" -ForEach @(
        @{ Text = "5-2" }, @{ Text = "abc" }, @{ Text = "1-" }, @{ Text = "-3" }, @{ Text = "1.5" }, @{ Text = "1/2" }
    ) {
        { ConvertTo-WinForgeSelectionIndexes -InputText $Text -Maximum 10 } | Should -Throw
    }

    It "não confunde dígitos de outros alfabetos com números" {
        # \d aceitaria estes dígitos e [int] falharia com uma mensagem técnica.
        $arabic = [string][char]0x0661
        $fullWidth = [string][char]0xFF11

        { ConvertTo-WinForgeSelectionIndexes -InputText $arabic -Maximum 10 } | Should -Throw -ExpectedMessage "*não é um número*"
        { ConvertTo-WinForgeSelectionIndexes -InputText $fullWidth -Maximum 10 } | Should -Throw -ExpectedMessage "*não é um número*"
    }

    It "não expande intervalos enormes antes de validar" {
        $watch = [Diagnostics.Stopwatch]::StartNew()
        { ConvertTo-WinForgeSelectionIndexes -InputText "1-999999999" -Maximum 10 } | Should -Throw
        $watch.Elapsed.TotalSeconds | Should -BeLessThan 2
    }

    It "rejeita números com mais de 9 dígitos sem estourar" {
        { ConvertTo-WinForgeSelectionIndexes -InputText "99999999999999999999" -Maximum 10 } | Should -Throw -ExpectedMessage "*não é um número*"
    }

    It "devolve vazio para entrada em branco e erro quando não há itens" {
        ConvertTo-WinForgeSelectionIndexes -InputText "  " -Maximum 10 | Should -BeNullOrEmpty
        ConvertTo-WinForgeSelectionIndexes -InputText $null -Maximum 10 | Should -BeNullOrEmpty
        ConvertTo-WinForgeSelectionIndexes -InputText " , ; " -Maximum 10 | Should -BeNullOrEmpty
        { ConvertTo-WinForgeSelectionIndexes -InputText "1" -Maximum 0 } | Should -Throw
    }
}

Describe "Argumentos de linha de comando" {
    It "mantém valores simples e protege espaços" {
        ConvertTo-WinForgeCommandLineArgument -Value "abc" | Should -Be "abc"
        ConvertTo-WinForgeCommandLineArgument -Value "C:\Meus Relatorios" | Should -Be '"C:\Meus Relatorios"'
        ConvertTo-WinForgeCommandLineArgument -Value "" | Should -Be '""'
    }

    It "duplica a barra final para não escapar a aspa de fechamento" {
        ConvertTo-WinForgeCommandLineArgument -Value 'C:\Meus Relatorios\' | Should -Be '"C:\Meus Relatorios\\"'
    }

    It "escapa aspas embutidas" {
        ConvertTo-WinForgeCommandLineArgument -Value 'a "b" c' | Should -Be '"a \"b\" c"'
    }

    It "devolve o valor original ao ser lido pelas regras do Windows (CommandLineToArgvW)" -ForEach @(
        @{ Value = 'C:\Pasta Com Espaco\' },
        @{ Value = 'a "b" c' },
        @{ Value = 'x\\"y' },
        @{ Value = 'C:\simples' },
        @{ Value = 'D:\' },
        @{ Value = 'com\\barras\\ e espaço' },
        @{ Value = '' }
    ) {
        $line = "-Action Report -ReportDirectory " + (ConvertTo-WinForgeCommandLineArgument -Value $Value) + " -PauseAtEnd"
        $parsed = @(Split-WindowsCommandLine -Line $line)

        $parsed | Should -HaveCount 5
        $parsed[3] | Should -BeExactly $Value
        $parsed[4] | Should -Be "-PauseAtEnd"
    }
}

Describe "Formatação" {
    It "formata durações" {
        Format-WinForgeDuration -Span ([TimeSpan]::FromSeconds(42)) | Should -Be "42s"
        Format-WinForgeDuration -Span ([TimeSpan]::FromSeconds(125)) | Should -Be "2min 05s"
        Format-WinForgeDuration -Span ([TimeSpan]::FromMinutes(75)) | Should -Be "1h 15min"
        Format-WinForgeDuration -Span ([TimeSpan]::Zero) | Should -Be "0s"
    }

    It "trata duração negativa (relógio ajustado) como zero" {
        Format-WinForgeDuration -Span ([TimeSpan]::FromSeconds(-30)) | Should -Be "0s"
    }

    It "formata tamanhos" {
        Format-WinForgeBytes -Bytes 512 | Should -Be "512 B"
        Format-WinForgeBytes -Bytes 1KB | Should -Be "1 KB"
        Format-WinForgeBytes -Bytes 1.5GB | Should -Match "^1[.,]5 GB$"
        Format-WinForgeBytes -Bytes 2TB | Should -Match "^2 TB$"
    }

    It "usa o texto de zero para valores nulos, inválidos ou negativos" -ForEach @(
        @{ Value = $null }, @{ Value = "abc" }, @{ Value = -5 }, @{ Value = 0 }, @{ Value = [double]::NaN }
    ) {
        Format-WinForgeBytes -Bytes $Value -ZeroText "?" | Should -Be "?"
    }

    It "não falha com valores gigantes" {
        { Format-WinForgeBytes -Bytes ([double]::MaxValue) } | Should -Not -Throw
        { Format-WinForgeBytes -Bytes ([double]::PositiveInfinity) } | Should -Not -Throw
    }
}

Describe "Tempo relativo" {
    BeforeAll { $script:Now = [datetime]"2026-10-14 12:00:00" }

    It "<Name>" -ForEach @(
        @{ Name = "menos de um minuto é agora há pouco"; Ago = [TimeSpan]::FromSeconds(30); Expected = "agora há pouco" },
        @{ Name = "um horário no futuro (relógio ajustado) também"; Ago = [TimeSpan]::FromMinutes(-5); Expected = "agora há pouco" },
        @{ Name = "1 minuto no singular"; Ago = [TimeSpan]::FromSeconds(61); Expected = "há 1 minuto" },
        @{ Name = "minutos"; Ago = [TimeSpan]::FromMinutes(45); Expected = "há 45 minutos" },
        @{ Name = "1 hora no singular"; Ago = [TimeSpan]::FromMinutes(61); Expected = "há 1 hora" },
        @{ Name = "horas"; Ago = [TimeSpan]::FromHours(23); Expected = "há 23 horas" },
        @{ Name = "1 dia no singular"; Ago = [TimeSpan]::FromHours(25); Expected = "há 1 dia" },
        @{ Name = "dias"; Ago = [TimeSpan]::FromDays(29); Expected = "há 29 dias" },
        @{ Name = "1 mês no singular"; Ago = [TimeSpan]::FromDays(31); Expected = "há 1 mês" },
        @{ Name = "meses"; Ago = [TimeSpan]::FromDays(200); Expected = "há 6 meses" },
        @{ Name = "1 ano no singular"; Ago = [TimeSpan]::FromDays(366); Expected = "há 1 ano" },
        @{ Name = "anos"; Ago = [TimeSpan]::FromDays(800); Expected = "há 2 anos" }
    ) {
        Format-WinForgeRelativeTime -When ($script:Now - $Ago) -Now $script:Now | Should -Be $Expected
    }
}

Describe "Nível de espaço em disco" {
    It "<Name>" -ForEach @(
        @{ Name = "sem dados (valor negativo) é Unknown"; Free = -1; Total = 500GB; Expected = "Unknown" },
        @{ Name = "sem dados (nulo) é Unknown"; Free = $null; Total = 500GB; Expected = "Unknown" },
        @{ Name = "texto que não é número é Unknown"; Free = "abc"; Total = 500GB; Expected = "Unknown" },
        @{ Name = "menos de 5 GB é Critical, mesmo num disco pequeno"; Free = 4GB; Total = 30GB; Expected = "Critical" },
        @{ Name = "zero livre é Critical"; Free = 0; Total = 500GB; Expected = "Critical" },
        @{ Name = "exatamente 5 GB livres em disco grande é Low (abaixo de 10%)"; Free = 5GB; Total = 500GB; Expected = "Low" },
        @{ Name = "9% livres é Low"; Free = 90GB; Total = 1000GB; Expected = "Low" },
        @{ Name = "10% livres é Ok"; Free = 100GB; Total = 1000GB; Expected = "Ok" },
        @{ Name = "disco pequeno com 8 GB livres (mais de 10%) é Ok"; Free = 8GB; Total = 32GB; Expected = "Ok" },
        @{ Name = "total desconhecido, mas com mais de 5 GB livres, é Ok"; Free = 50GB; Total = 0; Expected = "Ok" }
    ) {
        Get-WinForgeDiskSpaceLevel -FreeBytes $Free -TotalBytes $Total | Should -Be $Expected
    }

    It "lê o espaço total e livre da unidade do Windows e devolve nulo quando não há" {
        $original = $env:SystemRoot

        try {
            $env:SystemRoot = [IO.Path]::GetTempPath()
            $space = Get-WinForgeSystemDriveSpace

            $space.FreeBytes | Should -BeGreaterThan 0
            $space.TotalBytes | Should -BeGreaterOrEqual $space.FreeBytes

            $env:SystemRoot = ""
            Get-WinForgeSystemDriveSpace | Should -BeNullOrEmpty
        }
        finally { $env:SystemRoot = $original }
    }
}

Describe "Dados do resultado de uma etapa" {
    It "lê fatos de Data e devolve nulo para o que não existe" {
        $result = New-WinForgeResult -Kind Ok -Data @{ FreedBytes = 2048; RebootRequired = $true }

        Get-WinForgeResultData -Result $result -Name "FreedBytes" | Should -Be 2048
        Get-WinForgeResultData -Result $result -Name "Inexistente" | Should -BeNullOrEmpty
        Test-WinForgeResultFlag -Result $result -Name "RebootRequired" | Should -BeTrue
        Test-WinForgeResultFlag -Result $result -Name "Inexistente" | Should -BeFalse
    }

    It "não falha com resultado nulo, sem Data ou com Data de outro tipo" {
        Get-WinForgeResultData -Result $null -Name "X" | Should -BeNullOrEmpty
        Get-WinForgeResultData -Result ([PSCustomObject]@{ Kind = "Ok" }) -Name "X" | Should -BeNullOrEmpty
        Get-WinForgeResultData -Result ([PSCustomObject]@{ Data = "texto" }) -Name "X" | Should -BeNullOrEmpty
        Test-WinForgeResultFlag -Result $null -Name "X" | Should -BeFalse
    }

    It "um resultado sem dados tem Data vazio, e cada resultado tem o seu (não compartilham a mesma tabela)" {
        $first = New-WinForgeResult -Kind Ok
        $second = New-WinForgeResult -Kind Ok

        $first.Data.Count | Should -Be 0
        $first.Data["X"] = 1
        $second.Data.ContainsKey("X") | Should -BeFalse
    }
}

Describe "Versão" {
    It "tem o formato número.número" {
        Get-WinForgeBuild | Should -Match "^[0-9]+\.[0-9]+$"
    }
}

Describe "Sessão e ambiente" {
    It "lê a sessão sem lançar erro, mesmo quando o sistema não responde" {
        { Get-WinForgeSessionInfo -Refresh } | Should -Not -Throw

        $session = Get-WinForgeSessionInfo
        $session.IsLaptop | Should -BeOfType ([bool])
        $session.WindowsLabel | Should -Not -BeNullOrEmpty
    }

    It "reconhece o notebook na bateria (descarregando, baixa, crítica) e ignora tomada e carregamento" -ForEach @(
        @{ Status = 1; Expected = $true },
        @{ Status = 4; Expected = $true },
        @{ Status = 5; Expected = $true },
        @{ Status = 2; Expected = $false },
        @{ Status = 3; Expected = $false },
        @{ Status = 6; Expected = $false },
        @{ Status = 7; Expected = $false }
    ) {
        $global:WfBatteryStatus = $Status
        Set-TestStub -Name "Get-CimInstance" -Body {
            [CmdletBinding()]
            param ([Parameter(Position = 0)][string]$ClassName)
            [PSCustomObject]@{ BatteryStatus = $global:WfBatteryStatus }
        }

        try { Test-WinForgeOnBattery | Should -Be $Expected }
        finally {
            Remove-Item Function:\global:Get-CimInstance -ErrorAction SilentlyContinue
            Remove-Variable WfBatteryStatus -Scope Global -ErrorAction SilentlyContinue
        }
    }

    It "desktop (sem bateria) ou sistema sem resposta nunca contam como bateria" {
        try {
            Set-TestStub -Name "Get-CimInstance" -Body {
                [CmdletBinding()]
                param ([Parameter(Position = 0)][string]$ClassName)
            }
            Test-WinForgeOnBattery | Should -BeFalse

            Set-TestStub -Name "Get-CimInstance" -Body {
                [CmdletBinding()]
                param ([Parameter(Position = 0)][string]$ClassName)
                throw "sem resposta"
            }
            Test-WinForgeOnBattery | Should -BeFalse
        }
        finally { Remove-Item Function:\global:Get-CimInstance -ErrorAction SilentlyContinue }
    }

    It "espaço livre da unidade do Windows: lê o SystemRoot e devolve -1 quando não há" {
        $original = $env:SystemRoot

        try {
            $env:SystemRoot = [IO.Path]::GetTempPath()
            Get-WinForgeSystemDriveFreeBytes | Should -BeGreaterThan 0

            $env:SystemRoot = ""
            Get-WinForgeSystemDriveFreeBytes | Should -Be -1
        }
        finally { $env:SystemRoot = $original }
    }

    It "o modo janela só vale quando o executor o ativa, e a leitura nunca falha" {
        Remove-Variable WinForgeGuiMode -Scope Global -ErrorAction SilentlyContinue

        try {
            Test-WinForgeGuiMode | Should -BeFalse

            $global:WinForgeGuiMode = $true
            Test-WinForgeGuiMode | Should -BeTrue

            $global:WinForgeGuiMode = $false
            Test-WinForgeGuiMode | Should -BeFalse
        }
        finally { Remove-Variable WinForgeGuiMode -Scope Global -ErrorAction SilentlyContinue }
    }

    It "monta o caminho de dados dentro de LOCALAPPDATA" {
        Get-WinForgeDataPath | Should -Be (Join-Path $env:LOCALAPPDATA "WinForge")
        Test-Path -LiteralPath (Get-WinForgeDataPath) | Should -BeTrue
    }

    It "liga e desliga o log sem abrir dois registros" {
        { Stop-WinForgeLogging } | Should -Not -Throw
        { Stop-WinForgeLogging } | Should -Not -Throw
    }
}

Describe "Última manutenção" {
    It "devolve nulo quando nunca rodou" {
        Reset-LastMaintenanceMemory
        Remove-Item -LiteralPath (Join-Path (Get-WinForgeDataPath) "last-maintenance.json") -Force -ErrorAction SilentlyContinue

        Get-WinForgeLastMaintenance | Should -BeNullOrEmpty
    }

    It "sobrevive a um novo início da janela (lê do disco)" {
        $started = Get-Date "2026-03-04T10:20:30"
        $results = @(
            [PSCustomObject]@{ Etapa = "Limpeza"; Status = "OK"; Kind = "Ok"; Duracao = "5s" },
            [PSCustomObject]@{ Etapa = "Rede"; Status = "Falhou (x)"; Kind = "Failed"; Duracao = "1s" }
        )

        Set-WinForgeLastMaintenance -Results $results -StartedAt $started
        Reset-LastMaintenanceMemory

        $last = Get-WinForgeLastMaintenance
        $last | Should -Not -BeNullOrEmpty
        $last.StartedAt.Year | Should -Be 2026
        $last.StartedAt.Minute | Should -Be 20
        @($last.Results) | Should -HaveCount 2
        @($last.Results)[1].Kind | Should -Be "Failed"
    }

    It "ignora um arquivo corrompido ou vazio" -ForEach @(
        @{ Content = "{ isto não é json" }, @{ Content = "" }, @{ Content = "[1,2" }, @{ Content = '{"StartedAt":"data inválida","Results":[]}' }
    ) {
        Reset-LastMaintenanceMemory
        Set-Content -LiteralPath (Join-Path (Get-WinForgeDataPath) "last-maintenance.json") -Value $Content -Encoding UTF8

        { Get-WinForgeLastMaintenance } | Should -Not -Throw
        Get-WinForgeLastMaintenance | Should -BeNullOrEmpty
    }

    It "guarda as fotos do antes e do depois, e elas sobrevivem a um novo início" {
        $start = Get-Date "2026-03-04T10:00:00"
        $before = [PSCustomObject]@{ At = $start; FreeBytes = [int64]50GB; StartupItems = 18 }
        $after = [PSCustomObject]@{ At = $start.AddMinutes(40); FreeBytes = [int64]61GB; StartupItems = $null }

        Set-WinForgeLastMaintenance -Results @() -StartedAt $start -Before $before -After $after
        Reset-LastMaintenanceMemory

        $last = Get-WinForgeLastMaintenance

        $last.Before.FreeBytes | Should -Be 50GB
        $last.Before.StartupItems | Should -Be 18
        $last.After.At.Minute | Should -Be 40
        $last.After.FreeBytes | Should -Be 61GB
        $last.After.StartupItems | Should -BeNullOrEmpty
    }

    It "arquivo de versão antiga, sem as fotos, continua legível" {
        Reset-LastMaintenanceMemory
        Set-Content -LiteralPath (Join-Path (Get-WinForgeDataPath) "last-maintenance.json") -Encoding UTF8 -Value '{"StartedAt":"2026-03-04T10:20:30.0000000","Results":[{"Etapa":"A","Status":"OK","Kind":"Ok","Duracao":"1s"}]}'

        $last = Get-WinForgeLastMaintenance

        @($last.Results) | Should -HaveCount 1
        $last.Before | Should -BeNullOrEmpty
        $last.After | Should -BeNullOrEmpty
    }

    It "foto ilegível no arquivo vira nula, sem perder o resto da manutenção" {
        Reset-LastMaintenanceMemory
        Set-Content -LiteralPath (Join-Path (Get-WinForgeDataPath) "last-maintenance.json") -Encoding UTF8 -Value '{"StartedAt":"2026-03-04T10:20:30.0000000","Before":{"At":"lixo","FreeBytes":1},"Results":[]}'

        $last = Get-WinForgeLastMaintenance

        $last | Should -Not -BeNullOrEmpty
        $last.Before | Should -BeNullOrEmpty
    }

    It "lê os valores de uma chave do registro (simulada) e devolve vazio para chave inexistente" {
        (Get-WinForgeRegistryValues -Path "HKCU:\Software\WinForgeChaveQueNaoExiste").Count | Should -Be 0
    }

    It "aceita uma lista de resultados vazia" {
        Set-WinForgeLastMaintenance -Results @() -StartedAt (Get-Date)
        Reset-LastMaintenanceMemory

        { Get-WinForgeLastMaintenance } | Should -Not -Throw
    }
}

Describe "Programas nativos" {
    It "captura saída e código de saída" {
        $result = Invoke-WinForgeCapture -FilePath $script:HostExe -Arguments @("-NoProfile", "-NonInteractive", "-Command", "Write-Output um; Write-Output dois; exit 3")

        $result.ExitCode | Should -Be 3
        $result.Lines | Should -HaveCount 2
        $result.Text | Should -Be "um`ndois"
    }

    It "lança erro com código diferente de zero, a menos que seja ignorado" {
        { Invoke-WinForgeNative -FilePath $script:HostExe -Arguments @("-NoProfile", "-NonInteractive", "-Command", "exit 5") } | Should -Throw -ExpectedMessage "*código 5*"
        { Invoke-WinForgeNative -FilePath $script:HostExe -Arguments @("-NoProfile", "-NonInteractive", "-Command", "exit 5") -IgnoreExitCode } | Should -Not -Throw
    }

    It "devolve o código de saída com -PassThru" {
        Invoke-WinForgeNative -FilePath $script:HostExe -Arguments @("-NoProfile", "-NonInteractive", "-Command", "exit 7") -IgnoreExitCode -PassThru | Should -Be 7
        Invoke-WinForgeNative -FilePath $script:HostExe -Arguments @("-NoProfile", "-NonInteractive", "-Command", "exit 0") -PassThru | Should -Be 0
    }

    It "não herda o código de saída de uma chamada anterior" {
        [void](Invoke-WinForgeCapture -FilePath $script:HostExe -Arguments @("-NoProfile", "-NonInteractive", "-Command", "exit 9"))
        $second = Invoke-WinForgeCapture -FilePath $script:HostExe -Arguments @("-NoProfile", "-NonInteractive", "-Command", "exit 0")

        $second.ExitCode | Should -Be 0
    }

    It "lança erro claro para um programa que não existe" {
        { Invoke-WinForgeCapture -FilePath "programa-que-nao-existe-winforge" } | Should -Throw
    }
}

Describe "Perguntas no console (sem interface gráfica)" {
    It "aceita a chave da opção e ignora respostas inválidas" {
        Set-FakeReadHost -Answers "x", "2"

        Read-WinForgeChoice -Message "Escolha" -Options @(@{ Key = "1"; Label = "Um" }, @{ Key = "2"; Label = "Dois" }) | Should -Be "2"
    }

    It "usa a opção padrão quando a resposta é vazia" {
        Set-FakeReadHost -Answers ""

        Read-WinForgeChoice -Message "Escolha" -DefaultKey "C" -Options @(@{ Key = "C"; Label = "Continuar" }, @{ Key = "P"; Label = "Pular" }) | Should -Be "C"
    }

    It "ignora maiúsculas e espaços na escolha" {
        Set-FakeReadHost -Answers "  p "

        Read-WinForgeChoice -Message "Escolha" -Options @(@{ Key = "C"; Label = "Continuar" }, @{ Key = "P"; Label = "Pular" }) | Should -Be "P"
    }

    It "desiste depois de muitas respostas inválidas (entrada encerrada não gera laço infinito)" {
        Set-FakeReadHost -Answers @()

        { Read-WinForgeChoice -Message "Escolha" -Options @(@{ Key = "1"; Label = "Um" }) } | Should -Throw -ExpectedMessage "*Nenhuma resposta válida*"
    }

    It "seleciona vários itens por números e intervalos" {
        Set-FakeReadHost -Answers "9", "1,3"

        $options = @(@{ Key = "a"; Label = "A" }, @{ Key = "b"; Label = "B" }, @{ Key = "c"; Label = "C" })
        (Read-WinForgeMultiSelect -Message "Marque" -Options $options) -join "," | Should -Be "a,c"
    }

    It "aceita seleção com espaços" {
        Set-FakeReadHost -Answers "1 3"

        $options = @(@{ Key = "a"; Label = "A" }, @{ Key = "b"; Label = "B" }, @{ Key = "c"; Label = "C" })
        (Read-WinForgeMultiSelect -Message "Marque" -Options $options) -join "," | Should -Be "a,c"
    }

    It "seleciona todos com T, mantém os marcados com P e cancela com resposta vazia" {
        $options = @(@{ Key = "a"; Label = "A"; Selected = $true }, @{ Key = "b"; Label = "B" })

        Set-FakeReadHost -Answers "t"
        (Read-WinForgeMultiSelect -Message "Marque" -Options $options) -join "," | Should -Be "a,b"

        Set-FakeReadHost -Answers "p"
        (Read-WinForgeMultiSelect -Message "Marque" -Options $options) -join "," | Should -Be "a"

        Set-FakeReadHost -Answers ""
        Read-WinForgeMultiSelect -Message "Marque" -Options $options | Should -BeNullOrEmpty
    }

    It "devolve nulo, sem erro, quando a lista de opções está vazia" {
        { Read-WinForgeMultiSelect -Message "Marque" -Options @() } | Should -Not -Throw
        Read-WinForgeMultiSelect -Message "Marque" -Options @() | Should -BeNullOrEmpty
    }

    It "entende Sim e Não em vários formatos" -ForEach @(
        @{ Answer = "s"; Expected = $true }, @{ Answer = "SIM"; Expected = $true }, @{ Answer = "y"; Expected = $true },
        @{ Answer = " n "; Expected = $false }, @{ Answer = "não"; Expected = $false }, @{ Answer = "NAO"; Expected = $false }
    ) {
        Set-FakeReadHost -Answers $Answer

        Confirm-WinForgeAction "Quer?" | Should -Be $Expected
    }

    It "usa a resposta padrão quando só se aperta ENTER" {
        Set-FakeReadHost -Answers ""
        Confirm-WinForgeAction "Quer?" -DefaultKey N | Should -BeFalse

        Set-FakeReadHost -Answers ""
        Confirm-WinForgeAction "Quer?" -DefaultKey S | Should -BeTrue
    }

    It "não assume resposta quando não há padrão e a entrada acabou" {
        Set-FakeReadHost -Answers @()

        { Confirm-WinForgeAction "Quer?" } | Should -Throw -ExpectedMessage "*Nenhuma resposta válida*"
    }

    It "lê texto livre sem espaços nas pontas" {
        Set-FakeReadHost -Answers "  Google.Chrome  "

        Read-WinForgeText -Message "ID" | Should -Be "Google.Chrome"
    }

    It "trata entrada encerrada como texto vazio (desistência)" {
        Set-FakeReadHost -Answers @()

        Read-WinForgeText -Message "ID" | Should -Be ""
    }
}

Describe "Mensagens do console" {
    It "monta a tabela de resultados com status, duração e sem falhar com lista vazia" {
        $results = @(
            (New-WinForgeResult -Kind Ok -Title "Limpeza"),
            (New-WinForgeResult -Kind Failed -Detail "erro" -Title "Rede")
        )
        $results[0].Duracao = "5s"

        $text = Get-HostText { Write-WinForgeResultTable -Results $results }
        $text | Should -Match "Limpeza"
        $text | Should -Match "Falhou \(erro\)"

        { Write-WinForgeResultTable -Results @() } | Should -Not -Throw
    }

    It "cria resultados com status coerente com o tipo" {
        (New-WinForgeResult -Kind Ok).Status | Should -Be "OK"
        (New-WinForgeResult -Kind Skipped -Detail "x").Status | Should -Be "Ignorado (x)"
        (New-WinForgeResult -Kind Warning -Detail "y").Status | Should -Be "Atenção (y)"
        (New-WinForgeResult -Kind Failed).Status | Should -Be "Falhou"
        (New-WinForgeResult -Kind Ok).PSObject.TypeNames | Should -Contain "WinForge.Result"
    }

    It "o cabeçalho da ação aparece no console e não se repete dentro da janela (o botão já mostra o título)" {
        Remove-Variable WinForgeGuiMode -Scope Global -ErrorAction SilentlyContinue

        try {
            (Get-HostText { Enter-WinForgeAction -Title "Limpeza rápida" }) | Should -Match "Limpeza rápida"

            $global:WinForgeGuiMode = $true
            (Get-HostText { Enter-WinForgeAction -Title "Limpeza rápida" }) | Should -Not -Match "Limpeza rápida"
        }
        finally { Remove-Variable WinForgeGuiMode -Scope Global -ErrorAction SilentlyContinue }
    }

    It "dentro de um fluxo (Embedded) a ação abre só uma seção, no console e na janela" {
        try {
            (Get-HostText { Enter-WinForgeAction -Title "Reparar rede e DNS" -Embedded }) | Should -Match "Reparar rede e DNS"

            $global:WinForgeGuiMode = $true
            (Get-HostText { Enter-WinForgeAction -Title "Reparar rede e DNS" -Embedded }) | Should -Match "Reparar rede e DNS"
        }
        finally { Remove-Variable WinForgeGuiMode -Scope Global -ErrorAction SilentlyContinue }
    }

    It "usa glifos ASCII quando WINFORGE_ASCII=1" {
        $previous = $env:WINFORGE_ASCII
        $env:WINFORGE_ASCII = "1"
        try {
            (Get-WinForgeGlyphs).H | Should -Be "-"
        }
        finally {
            $env:WINFORGE_ASCII = $previous
        }
    }

    It "limita a largura do console a valores razoáveis" {
        (Get-WinForgeConsoleWidth) | Should -BeGreaterThan 59
        (Get-WinForgeConsoleWidth) | Should -BeLessThan 97
    }
}

Describe "Execução em segundo plano com tempo limite" {
    BeforeAll { Import-AllWinForgeModules }

    It "devolve o que o bloco escreveu e recebe os argumentos" {
        $run = Invoke-WinForgeInBackground -ScriptBlock { param ($a, $b) $a + $b; "fim" } -ArgumentList @(2, 3) -TimeoutSeconds 20

        $run.Completed | Should -BeTrue
        $run.TimedOut | Should -BeFalse
        $run.Error | Should -Be ""
        @($run.Output) | Should -Be @(5, "fim")
    }

    It "bloco sem saída é concluído com lista vazia" {
        $run = Invoke-WinForgeInBackground -ScriptBlock { $null = 1 } -TimeoutSeconds 20

        $run.Completed | Should -BeTrue
        @($run.Output) | Should -HaveCount 0
    }

    It "erro terminante no bloco vira Error, sem lançar exceção para quem chamou" {
        $run = Invoke-WinForgeInBackground -ScriptBlock { throw "COM indisponível" } -TimeoutSeconds 20

        $run.Completed | Should -BeFalse
        $run.TimedOut | Should -BeFalse
        $run.Error | Should -Match "COM indisponível"
    }

    It "bloco que não termina a tempo é abandonado, e quem chamou volta logo" {
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        $run = Invoke-WinForgeInBackground -ScriptBlock { Start-Sleep -Seconds 30 } -TimeoutSeconds 1
        $stopwatch.Stop()

        $run.Completed | Should -BeFalse
        $run.TimedOut | Should -BeTrue
        $stopwatch.Elapsed.TotalSeconds | Should -BeLessThan 10
    }
}
