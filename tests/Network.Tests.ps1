# Rede: medições, ping, comandos de reparo (e a proteção de IP estático) e o fluxo do reparo.
# Nada usa a rede nem altera adaptadores: Test-Connection, comandos nativos e esperas são substituídos.

BeforeAll {
    . (Join-Path $PSScriptRoot "TestSetup.ps1")

    $script:NetworkTestHost = "exemplo"
    $script:InvalidNetworkTestHost = "nome inválido!!"

    function script:Use-NetworkStubs {
        $global:WfLog = New-Object System.Collections.ArrayList
        $global:WfAdmin = $true
        $global:WfExit = @{}

        Set-TestStub -Name "Test-WinForgeAdministrator" -Body { [bool]$global:WfAdmin }
        Set-TestStub -Name "Start-Sleep" -Body { [CmdletBinding()] param ($Seconds, $Milliseconds) }
        # Sem resposta de ping: o reparo depende só de comandos (o DNS do teste não influencia o resultado).
        Set-TestStub -Name "Test-Connection" -Body { [CmdletBinding()] param ($ComputerName, $Count) }
        # Sem TCP e com DNS funcionando, a menos que o teste mude: nada aqui toca a rede de verdade.
        $global:WfTcp = $false
        $global:WfDns = $true
        $global:WfTcpCalls = New-Object System.Collections.ArrayList
        Set-TestStub -Name "Test-WinForgeTcpConnection" -Body {
            param ($ComputerName, $Port, $TimeoutMilliseconds)
            [void]$global:WfTcpCalls.Add("${ComputerName}:$Port")
            [bool]$global:WfTcp
        }
        Set-TestStub -Name "Test-WinForgeDnsResolution" -Body { param ($Name) [bool]$global:WfDns }
        Set-TestStub -Name "Invoke-WinForgeNative" -Body {
            param ([string]$FilePath, [string[]]$Arguments, [switch]$IgnoreExitCode, [switch]$PassThru)
            $line = ((Split-Path -Leaf $FilePath) + " " + ($Arguments -join " ")).Trim()
            [void]$global:WfLog.Add($line)
            if ($global:WfExit.ContainsKey($line)) { $global:WfExit[$line] } else { 0 }
        }
    }
}

AfterAll {
    Remove-Variable WfLog, WfAdmin, WfExit, WfReplies, WfTcp, WfDns, WfTcpCalls, WfPublicIp, WfAdapters -Scope Global -ErrorAction SilentlyContinue
    Remove-WinForgeTestData
}

Describe "Medição de velocidade" {
    It "calcula Mbps a partir de bytes e segundos" -ForEach @(
        @{ Bytes = 1000000; Seconds = 1; Expected = 8 },
        @{ Bytes = 12500000; Seconds = 1; Expected = 100 },
        @{ Bytes = 25000000; Seconds = 2; Expected = 100 },
        @{ Bytes = 1; Seconds = 1; Expected = 0 }
    ) {
        Get-WinForgeMbps -Bytes $Bytes -Seconds $Seconds | Should -Be $Expected
    }

    It "tempo desprezível, zero, negativo ou bytes inválidos dão 0 (sem divisão por zero)" -ForEach @(
        @{ Bytes = 1000000; Seconds = 0 },
        @{ Bytes = 1000000; Seconds = 0.04 },
        @{ Bytes = 1000000; Seconds = -3 },
        @{ Bytes = 0; Seconds = 5 },
        @{ Bytes = -100; Seconds = 5 }
    ) {
        Get-WinForgeMbps -Bytes $Bytes -Seconds $Seconds | Should -Be 0
    }

    It "pega a mensagem mais interna de uma exceção embrulhada" {
        $inner = [System.InvalidOperationException]::new("causa real")
        $middle = [System.Exception]::new("meio", $inner)
        $outer = [System.AggregateException]::new("uma ou mais", $middle)

        Get-WinForgeInnerMessage -Exception $outer | Should -Be "causa real"
        Get-WinForgeInnerMessage -Exception ([System.Exception]::new("simples")) | Should -Be "simples"
    }
}

Describe "Ping" {
    It "classifica pela perda de pacotes" -ForEach @(
        @{ Loss = 0; Expected = "OK" },
        @{ Loss = 1; Expected = "Instável" },
        @{ Loss = 25; Expected = "Instável" },
        @{ Loss = 99; Expected = "Instável" },
        @{ Loss = 100; Expected = "Sem resposta" },
        @{ Loss = 150; Expected = "Sem resposta" }
    ) {
        Get-WinForgePingStatusText -LossPercent $Loss | Should -Be $Expected
    }

    It "calcula perda e latência a partir das respostas recebidas (PowerShell 7: Latency)" {
        Set-TestStub -Name "Test-Connection" -Body {
            [CmdletBinding()] param ($ComputerName, $Count)
            foreach ($latency in 10, 20) { [PSCustomObject]@{ Status = "Success"; Latency = $latency } }
            [PSCustomObject]@{ Status = "TimedOut"; Latency = 0 }
            [PSCustomObject]@{ Status = "Success"; Latency = 30 }
        }
        try {
            $stats = Get-WinForgePingStats -ComputerName $script:NetworkTestHost -Count 4

            $stats.Received | Should -Be 3
            $stats.Sent | Should -Be 4
            $stats.Loss | Should -Be 25
            $stats.Average | Should -Be 20
            $stats.Minimum | Should -Be 10
            $stats.Maximum | Should -Be 30
        }
        finally { Clear-TestStubs }
    }

    It "aceita o formato do Windows PowerShell 5.1 (ResponseTime, sem Status)" {
        Set-TestStub -Name "Test-Connection" -Body {
            [CmdletBinding()] param ($ComputerName, $Count)
            foreach ($time in 4, 6) { [PSCustomObject]@{ ResponseTime = $time } }
        }
        try {
            $stats = Get-WinForgePingStats -ComputerName $script:NetworkTestHost -Count 2

            $stats.Loss | Should -Be 0
            $stats.Average | Should -Be 5
        }
        finally { Clear-TestStubs }
    }

    It "sem nenhuma resposta: perda de 100% e latências como traço" {
        Set-TestStub -Name "Test-Connection" -Body { [CmdletBinding()] param ($ComputerName, $Count) }
        try {
            $stats = Get-WinForgePingStats -ComputerName $script:NetworkTestHost -Count 4

            $stats.Received | Should -Be 0
            $stats.Loss | Should -Be 100
            $stats.Average | Should -Be "-"
        }
        finally { Clear-TestStubs }
    }

    It "respostas a mais do que o pedido não geram perda negativa" {
        Set-TestStub -Name "Test-Connection" -Body {
            [CmdletBinding()] param ($ComputerName, $Count)
            1..6 | ForEach-Object { [PSCustomObject]@{ Status = "Success"; Latency = 5 } }
        }
        try {
            $stats = Get-WinForgePingStats -ComputerName $script:NetworkTestHost -Count 4
            $stats.Loss | Should -Be 0
            $stats.Received | Should -Be 4
        }
        finally { Clear-TestStubs }
    }

    It "resposta com Status nulo conta como falha, sem lançar erro" {
        Set-TestStub -Name "Test-Connection" -Body {
            [CmdletBinding()] param ($ComputerName, $Count)
            [PSCustomObject]@{ Status = $null; Latency = 5 }
        }
        try {
            { Get-WinForgePingStats -ComputerName $script:NetworkTestHost -Count 1 } | Should -Not -Throw
            (Get-WinForgePingStats -ComputerName $script:NetworkTestHost -Count 1).Loss | Should -Be 100
        }
        finally { Clear-TestStubs }
    }

    It "a quantidade de pings fora de 1 a 50 é recusada" -ForEach @(@{ Count = 0 }, @{ Count = 51 }, @{ Count = -1 }) {
        { Get-WinForgePingStats -ComputerName $script:NetworkTestHost -Count $Count } | Should -Throw
    }
}

Describe "Conectividade" {
    It "ping que responde dispensa o teste por TCP" {
        Use-NetworkStubs
        Set-TestStub -Name "Test-Connection" -Body {
            [CmdletBinding()] param ($ComputerName, $Count)
            1..$Count | ForEach-Object { [PSCustomObject]@{ Status = "Success"; Latency = 9 } }
        }
        try {
            $connectivity = Test-WinForgeInternetConnectivity

            $connectivity.PingOk | Should -BeTrue
            $connectivity.ViaTcp | Should -BeFalse
            $connectivity.DnsOk | Should -BeTrue
            $connectivity.Ok | Should -BeTrue
            $global:WfTcpCalls | Should -HaveCount 0
        }
        finally { Clear-TestStubs }
    }

    It "ping bloqueado (ICMP) mas TCP na porta 443 funcionando: a internet conta como funcionando" {
        Use-NetworkStubs
        $global:WfTcp = $true
        try {
            $connectivity = Test-WinForgeInternetConnectivity

            $connectivity.PingOk | Should -BeTrue
            $connectivity.ViaTcp | Should -BeTrue
            $connectivity.Ok | Should -BeTrue
            # Parou no primeiro alvo que respondeu.
            @($global:WfTcpCalls) | Should -HaveCount 1
            $global:WfTcpCalls[0] | Should -Be "1.1.1.1:443"
        }
        finally { Clear-TestStubs }
    }

    It "nada responde: tenta os dois alvos por TCP e conclui que não há conexão" {
        Use-NetworkStubs
        try {
            $connectivity = Test-WinForgeInternetConnectivity

            $connectivity.PingOk | Should -BeFalse
            $connectivity.ViaTcp | Should -BeFalse
            $connectivity.Ok | Should -BeFalse
            (@($global:WfTcpCalls) -join ",") | Should -Be "1.1.1.1:443,8.8.8.8:443"
        }
        finally { Clear-TestStubs }
    }

    It "IP responde mas o DNS não: separa os dois problemas" {
        Use-NetworkStubs
        $global:WfTcp = $true
        $global:WfDns = $false
        try {
            $connectivity = Test-WinForgeInternetConnectivity

            $connectivity.PingOk | Should -BeTrue
            $connectivity.DnsOk | Should -BeFalse
            $connectivity.Ok | Should -BeFalse
        }
        finally { Clear-TestStubs }
    }

    It "erro no ping do primeiro alvo não impede o segundo" {
        Use-NetworkStubs
        $global:WfPingCalls = New-Object System.Collections.ArrayList
        Set-TestStub -Name "Test-Connection" -Body {
            [CmdletBinding()] param ($ComputerName, $Count)
            [void]$global:WfPingCalls.Add($ComputerName)
            if ($ComputerName -eq "1.1.1.1") { throw "falha de rede" }
            1..$Count | ForEach-Object { [PSCustomObject]@{ Status = "Success"; Latency = 12 } }
        }
        try {
            $connectivity = Test-WinForgeInternetConnectivity

            $connectivity.PingOk | Should -BeTrue
            (@($global:WfPingCalls) -join ",") | Should -Be "1.1.1.1,8.8.8.8"
        }
        finally {
            Clear-TestStubs
            Remove-Variable WfPingCalls -Scope Global -ErrorAction SilentlyContinue
        }
    }

    It "o texto do acesso por IP diz quando só o TCP funciona" {
        Get-WinForgeIpReachText -Connectivity ([PSCustomObject]@{ PingOk = $false; ViaTcp = $false }) | Should -Be "Sem resposta"
        Get-WinForgeIpReachText -Connectivity ([PSCustomObject]@{ PingOk = $true; ViaTcp = $false }) | Should -Be "Responde"
        Get-WinForgeIpReachText -Connectivity ([PSCustomObject]@{ PingOk = $true; ViaTcp = $true }) | Should -Match "ping está bloqueado"
    }

    It "o teste de TCP e o de DNS nunca lançam erro, mesmo com entrada inválida" {
        { Test-WinForgeTcpConnection -ComputerName $script:InvalidNetworkTestHost -Port 443 -TimeoutMilliseconds 300 } | Should -Not -Throw
        Test-WinForgeTcpConnection -ComputerName $script:InvalidNetworkTestHost -Port 443 -TimeoutMilliseconds 300 | Should -BeFalse
        { Test-WinForgeTcpConnection -ComputerName "127.0.0.1" -Port 70000 } | Should -Throw
        { Test-WinForgeDnsResolution -Name "nome inválido!!" } | Should -Not -Throw
        Test-WinForgeDnsResolution -Name "nome inválido!!" | Should -BeFalse
    }
}

Describe "Conclusão do teste de ping" {
    BeforeAll {
        function script:New-PingRows {
            param ([int[]]$Loss)
            $hosts = "1.1.1.1", "8.8.8.8", "9.9.9.9", "www.microsoft.com", "www.google.com"
            for ($i = 0; $i -lt $hosts.Count; $i++) { [PSCustomObject]@{ Host = $hosts[$i]; Loss = $Loss[$i] } }
        }
    }

    It "<Name>" -ForEach @(
        @{ Name = "tudo responde: sucesso"; Loss = @(0, 0, 0, 0, 0); Level = "Success"; Match = "Todos os alvos responderam" },
        @{ Name = "nada responde: erro, aponta cabo, Wi-Fi e roteador"; Loss = @(100, 100, 100, 100, 100); Level = "Error"; Match = "cabo/Wi-Fi" },
        @{ Name = "IPs respondem e nomes não: problema de DNS, indicando o reparo"; Loss = @(0, 0, 0, 100, 100); Level = "Warning"; Match = "Reparar rede e DNS" },
        @{ Name = "um alvo falha: ressalva sem alarme"; Loss = @(0, 100, 0, 0, 0); Level = "Warning"; Match = "Alguns alvos" },
        @{ Name = "perda parcial ainda conta como resposta"; Loss = @(25, 0, 0, 50, 0); Level = "Success"; Match = "Todos os alvos responderam" }
    ) {
        $verdict = Get-WinForgePingVerdict -Results @(New-PingRows -Loss $Loss)

        $verdict.Level | Should -Be $Level
        $verdict.Message | Should -Match $Match
    }

    It "sem resultados nenhum, é erro (nada respondeu)" {
        (Get-WinForgePingVerdict -Results @()).Level | Should -Be "Error"
    }

    It "a tela mostra a conclusão e o título do botão só aparece fora da janela" {
        Use-NetworkStubs
        Set-TestStub -Name "Test-Connection" -Body {
            [CmdletBinding()] param ($ComputerName, $Count)
            1..$Count | ForEach-Object { [PSCustomObject]@{ Status = "Success"; Latency = 5 } }
        }
        Set-FakeReadHost -Answers @("")
        try {
            $text = Get-HostText { Test-WinForgePing }
            $text | Should -Match "Testar conectividade \(ping\)"
            $text | Should -Match "Todos os alvos responderam"

            $global:WinForgeGuiMode = $true
            Set-FakeReadHost -Answers @("")
            $inWindow = Get-HostText { Test-WinForgePing }
            $inWindow | Should -Not -Match "Testar conectividade \(ping\)"
            $inWindow | Should -Match "Todos os alvos responderam"
        }
        finally {
            Remove-Variable WinForgeGuiMode -Scope Global -ErrorAction SilentlyContinue
            Clear-FakeReadHost
            Clear-TestStubs
        }
    }

    It "sem internet a tela conclui que nada respondeu, sem lançar erro" {
        Use-NetworkStubs
        Set-FakeReadHost -Answers @("")
        try {
            $text = Get-HostText { Test-WinForgePing }
            $text | Should -Match "Nenhum alvo respondeu"
        }
        finally { Clear-FakeReadHost; Clear-TestStubs }
    }
}

Describe "Informações de rede" {
    BeforeAll {
        function script:Use-InfoStubs {
            param ([object[]]$Adapters = @(), [string]$PublicIp = "203.0.113.7", [switch]$PublicIpFails)

            $global:WfAdapters = $Adapters
            $global:WfPublicIp = $PublicIp
            $global:WfLog = New-Object System.Collections.ArrayList
            $global:WfIpFails = [bool]$PublicIpFails

            Set-TestStub -Name "Get-NetAdapter" -Body { [CmdletBinding()] param () $global:WfAdapters }
            Set-TestStub -Name "Get-NetIPConfiguration" -Body { [CmdletBinding()] param () }
            Set-TestStub -Name "Get-DnsClientServerAddress" -Body { [CmdletBinding()] param ($InterfaceIndex, $AddressFamily) }
            Set-TestStub -Name "Invoke-RestMethod" -Body {
                [CmdletBinding()] param ($Uri, $TimeoutSec)
                [void]$global:WfLog.Add("ip-publico")
                if ($global:WfIpFails) { throw "sem internet" }
                $global:WfPublicIp
            }
        }
    }

    AfterAll { Remove-Variable WfIpFails -Scope Global -ErrorAction SilentlyContinue }

    It "sem adaptador ativo, não consulta o IP público e explica por quê" {
        Use-InfoStubs
        Set-FakeReadHost -Answers @("")
        try {
            $text = Get-HostText { Show-WinForgeNetworkInfo }

            $text | Should -Match "Nenhum adaptador ativo"
            $text | Should -Match "consulta do IP público foi ignorada"
            $global:WfLog | Should -HaveCount 0
        }
        finally { Clear-FakeReadHost; Clear-TestStubs }
    }

    It "com adaptador ativo, mostra o IP público" {
        Use-InfoStubs -Adapters @([PSCustomObject]@{ Name = "Ethernet"; InterfaceDescription = "Placa"; Status = "Up"; LinkSpeed = "1 Gbps"; MacAddress = "00-11-22" })
        Set-FakeReadHost -Answers @("")
        try {
            $text = Get-HostText { Show-WinForgeNetworkInfo }

            $text | Should -Match "203\.0\.113\.7"
            $global:WfLog | Should -Contain "ip-publico"
        }
        finally { Clear-FakeReadHost; Clear-TestStubs }
    }

    It "falha na consulta do IP público vira aviso, e o resto da tela continua" {
        Use-InfoStubs -Adapters @([PSCustomObject]@{ Name = "Wi-Fi"; InterfaceDescription = "Placa"; Status = "Up"; LinkSpeed = "300 Mbps"; MacAddress = "00-11-22" }) -PublicIpFails
        Set-FakeReadHost -Answers @("")
        try {
            $text = Get-HostText { Show-WinForgeNetworkInfo }

            $text | Should -Match "Não foi possível consultar o IP público"
            $text | Should -Not -Match "Ocorreu um erro"
        }
        finally { Clear-FakeReadHost; Clear-TestStubs }
    }

    It "adaptadores desligados não contam como ativos" {
        Use-InfoStubs -Adapters @([PSCustomObject]@{ Name = "Wi-Fi"; InterfaceDescription = "Placa"; Status = "Disconnected"; LinkSpeed = "0 bps"; MacAddress = "00-11-22" })
        Set-FakeReadHost -Answers @("")
        try {
            $text = Get-HostText { Show-WinForgeNetworkInfo }

            $text | Should -Match "Nenhum adaptador ativo"
            $global:WfLog | Should -HaveCount 0
        }
        finally { Clear-FakeReadHost; Clear-TestStubs }
    }

    It "um erro do Windows ao listar adaptadores vira mensagem, não exceção" {
        Use-InfoStubs
        Set-TestStub -Name "Get-NetAdapter" -Body { [CmdletBinding()] param () throw "serviço indisponível" }
        Set-FakeReadHost -Answers @("")
        try {
            # Se a função lançasse a exceção, o próprio teste falharia aqui.
            $text = Get-HostText { Show-WinForgeNetworkInfo }

            $text | Should -Match "Ocorreu um erro ao listar informações de rede: serviço indisponível"
        }
        finally { Clear-FakeReadHost; Clear-TestStubs }
    }
}

Describe "Comandos do reparo de rede" {
    It "com DHCP: libera, renova, limpa DNS, redefine Winsock e TCP/IP, nesta ordem" {
        $titles = @(Get-WinForgeNetworkRepairCommands | ForEach-Object { $_.Title })

        ($titles -join "|") | Should -Be "Liberar endereço IP|Renovar endereço IP|Limpar cache DNS|Redefinir Winsock|Redefinir TCP/IP"
    }

    It "com IP estático: remove tudo o que apagaria a configuração manual" {
        $commands = @(Get-WinForgeNetworkRepairCommands -HasStaticIp)
        $titles = @($commands | ForEach-Object { $_.Title })

        ($titles -join "|") | Should -Be "Limpar cache DNS|Redefinir Winsock"

        $text = ($commands | ForEach-Object { "$($_.FilePath) $($_.Arguments -join ' ')" }) -join "`n"
        $text | Should -Not -Match "release|renew|int ip reset"
    }

    It "usa só executáveis do sistema com extensão explícita" {
        foreach ($command in @(Get-WinForgeNetworkRepairCommands)) {
            $command.FilePath | Should -Match "^(ipconfig|netsh)\.exe$"
            @($command.Arguments).Count | Should -BeGreaterThan 0
        }
    }

    It "detecta IP estático só quando há gateway e o DHCP está desativado" {
        $global:WfNetCases = @(
            @{ Gateway = $true; Dhcp = "Disabled"; Expected = $true },
            @{ Gateway = $true; Dhcp = "Enabled"; Expected = $false },
            @{ Gateway = $false; Dhcp = "Disabled"; Expected = $false }
        )

        try {
            foreach ($case in $global:WfNetCases) {
                $global:WfNetCase = $case

                Set-TestStub -Name "Get-NetIPConfiguration" -Body {
                    [CmdletBinding()] param ()
                    [PSCustomObject]@{ InterfaceIndex = 7; IPv4DefaultGateway = $(if ($global:WfNetCase.Gateway) { [PSCustomObject]@{ NextHop = "192.168.0.1" } } else { $null }) }
                }
                Set-TestStub -Name "Get-NetIPInterface" -Body {
                    [CmdletBinding()] param ($InterfaceIndex, $AddressFamily)
                    [PSCustomObject]@{ Dhcp = $global:WfNetCase.Dhcp }
                }

                Test-WinForgeStaticIpConfigured | Should -Be $case.Expected
            }

            Set-TestStub -Name "Get-NetIPConfiguration" -Body { [CmdletBinding()] param () throw "sem acesso" }
            Test-WinForgeStaticIpConfigured | Should -BeFalse
        }
        finally {
            Clear-TestStubs
            Remove-Variable WfNetCases, WfNetCase -Scope Global -ErrorAction SilentlyContinue
        }
    }
}

Describe "Reparo de rede" {
    It "sem Administrador não executa comando algum" {
        Use-NetworkStubs
        $global:WfAdmin = $false
        try {
            $result = @(Invoke-WinForgeNetworkRepair -Embedded -PassThru)

            $result[-1].Kind | Should -Be "Failed"
            $global:WfLog | Should -HaveCount 0
        }
        finally { Clear-TestStubs }
    }

    It "executa os comandos na ordem certa e avisa que precisa reiniciar quando a conexão não volta" {
        Use-NetworkStubs
        Set-TestStub -Name "Get-NetIPConfiguration" -Body { [CmdletBinding()] param () }
        try {
            $result = @(Invoke-WinForgeNetworkRepair -Embedded -PassThru)

            ($global:WfLog -join "|") | Should -Be "ipconfig.exe /release|ipconfig.exe /renew|ipconfig.exe /flushdns|netsh.exe winsock reset|netsh.exe int ip reset"
            $result[-1].Kind | Should -Be "Warning"
            $result[-1].Status | Should -Match "reinicie"
        }
        finally { Clear-TestStubs }
    }

    It "com IP estático, nunca libera o IP nem redefine o TCP/IP" {
        Use-NetworkStubs
        Set-TestStub -Name "Get-NetIPConfiguration" -Body {
            [CmdletBinding()] param ()
            [PSCustomObject]@{ InterfaceIndex = 3; IPv4DefaultGateway = [PSCustomObject]@{ NextHop = "10.0.0.1" } }
        }
        Set-TestStub -Name "Get-NetIPInterface" -Body {
            [CmdletBinding()] param ($InterfaceIndex, $AddressFamily)
            [PSCustomObject]@{ Dhcp = "Disabled" }
        }
        try {
            [void](Invoke-WinForgeNetworkRepair -Embedded -PassThru)

            ($global:WfLog -join "|") | Should -Be "ipconfig.exe /flushdns|netsh.exe winsock reset"
        }
        finally { Clear-TestStubs }
    }

    It "um comando que falha vira ressalva no resultado, e os demais continuam" {
        Use-NetworkStubs
        Set-TestStub -Name "Get-NetIPConfiguration" -Body { [CmdletBinding()] param () }
        $global:WfExit["ipconfig.exe /release"] = 1
        try {
            $result = @(Invoke-WinForgeNetworkRepair -Embedded -PassThru)

            @($global:WfLog).Count | Should -Be 5
            $result[-1].Kind | Should -Be "Warning"
        }
        finally { Clear-TestStubs }
    }

    It "um comando que lança exceção vira etapa com falha, sem derrubar o reparo" {
        Use-NetworkStubs
        Set-TestStub -Name "Get-NetIPConfiguration" -Body { [CmdletBinding()] param () }
        Set-TestStub -Name "Invoke-WinForgeNative" -Body {
            param ([string]$FilePath, [string[]]$Arguments, [switch]$IgnoreExitCode, [switch]$PassThru)
            [void]$global:WfLog.Add("tentou:$FilePath")
            throw "arquivo não encontrado"
        }
        try {
            $result = @(Invoke-WinForgeNetworkRepair -Embedded -PassThru)

            @($global:WfLog).Count | Should -Be 5
            $result[-1].Kind | Should -Be "Warning"
            $result[-1].Status | Should -Match "comando\(s\) falharam"
        }
        finally { Clear-TestStubs }
    }

    It "resultado de um comando traz o título como etapa" {
        Use-NetworkStubs
        try {
            $result = Invoke-WinForgeNetworkCommand -Title "Limpar cache DNS" -FilePath "ipconfig.exe" -Arguments @("/flushdns")
            $result.Etapa | Should -Be "Limpar cache DNS"
            $result.Kind | Should -Be "Ok"

            $global:WfExit["ipconfig.exe /flushdns"] = 2
            (Invoke-WinForgeNetworkCommand -Title "Limpar cache DNS" -FilePath "ipconfig.exe" -Arguments @("/flushdns")).Kind | Should -Be "Failed"
        }
        finally { Clear-TestStubs }
    }

    It "dentro da Manutenção, rede funcionando: não executa nada e devolve Ignorado" {
        Use-NetworkStubs
        $global:WfTcp = $true
        Set-TestStub -Name "Get-NetIPConfiguration" -Body { [CmdletBinding()] param () }
        try {
            $result = @(Invoke-WinForgeNetworkRepair -Embedded -PassThru)

            $result[-1].Kind | Should -Be "Skipped"
            $global:WfLog | Should -HaveCount 0
            Test-WinForgeResultFlag -Result $result[-1] -Name "RebootRequired" | Should -BeFalse
        }
        finally { Clear-TestStubs }
    }

    It "sozinho, rede funcionando: a resposta padrão é Não e cancelar não executa nada" {
        Use-NetworkStubs
        $global:WfTcp = $true
        Set-TestStub -Name "Get-NetIPConfiguration" -Body { [CmdletBinding()] param () }
        # ENTER aceita o padrão (N), e o segundo ENTER é o "pressione uma tecla" do final
        Set-FakeReadHost -Answers @("", "")
        try {
            $text = Get-HostText { Invoke-WinForgeNetworkRepair }

            $text | Should -Match "Só continue se estiver com um problema"
            $text | Should -Match "Operação cancelada"
            $global:WfLog | Should -HaveCount 0
        }
        finally { Clear-FakeReadHost; Clear-TestStubs }
    }

    It "sozinho, sem conexão: a resposta padrão é Sim e o reparo roda" {
        Use-NetworkStubs
        Set-TestStub -Name "Get-NetIPConfiguration" -Body { [CmdletBinding()] param () }
        Set-FakeReadHost -Answers @("", "")
        try {
            $text = Get-HostText { Invoke-WinForgeNetworkRepair }

            @($global:WfLog).Count | Should -Be 5
            $text | Should -Match "Reinicie o Windows"
        }
        finally { Clear-FakeReadHost; Clear-TestStubs }
    }

    It "o diagnóstico diz quando o ping está bloqueado mas o TCP funciona" {
        Use-NetworkStubs
        $global:WfTcp = $true
        Set-TestStub -Name "Get-NetIPConfiguration" -Body { [CmdletBinding()] param () }
        try {
            $text = Get-HostText { [void](Invoke-WinForgeNetworkRepair -Embedded -PassThru) }

            $text | Should -Match "Acesso por IP \(sem DNS\)"
            $text | Should -Match "ping está bloqueado"
        }
        finally { Clear-TestStubs }
    }

    It "o resultado dos resets traz o aviso de reinício nos dados, e só quando houve reset" {
        Use-NetworkStubs
        Set-TestStub -Name "Get-NetIPConfiguration" -Body { [CmdletBinding()] param () }
        try {
            $result = @(Invoke-WinForgeNetworkRepair -Embedded -PassThru)
            Test-WinForgeResultFlag -Result $result[-1] -Name "RebootRequired" | Should -BeTrue

            $global:WfAdmin = $false
            $denied = @(Invoke-WinForgeNetworkRepair -Embedded -PassThru)
            Test-WinForgeResultFlag -Result $denied[-1] -Name "RebootRequired" | Should -BeFalse
        }
        finally { Clear-TestStubs }
    }

    It "reparo que dá certo (conexão volta) termina como Ok com aviso de reinício" {
        Use-NetworkStubs
        $script:calls = 0
        Set-TestStub -Name "Get-NetIPConfiguration" -Body { [CmdletBinding()] param () }
        # Primeiro diagnóstico: sem rede; depois dos comandos: o TCP responde.
        Set-TestStub -Name "Test-WinForgeTcpConnection" -Body {
            param ($ComputerName, $Port, $TimeoutMilliseconds)
            [void]$global:WfTcpCalls.Add("${ComputerName}:$Port")
            @($global:WfLog).Count -ge 5
        }
        try {
            $result = @(Invoke-WinForgeNetworkRepair -Embedded -PassThru)

            $result[-1].Kind | Should -Be "Ok"
            Test-WinForgeResultFlag -Result $result[-1] -Name "RebootRequired" | Should -BeTrue
        }
        finally { Clear-TestStubs }
    }
}
