function Invoke-NetworkRepair {
    Show-Header "Reparo Rápido de Rede e DNS"

    if (-not (Test-IsAdministrator)) {
        Write-Host "Privilégios de Administrador são necessários para reparar rede e DNS." -ForegroundColor Red
        Write-Host ""
        Pause
        return
    }

    Write-Host "Esta opção executa um reparo rápido para problemas comuns de rede, DNS e pilha TCP/IP." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Comandos executados:" -ForegroundColor Cyan
    Write-Host "ipconfig /flushdns"
    Write-Host "ipconfig /release"
    Write-Host "ipconfig /renew"
    Write-Host "netsh winsock reset"
    Write-Host "netsh int ip reset"
    Write-Host ""
    Write-Host "A conexão pode cair temporariamente durante o processo." -ForegroundColor Yellow
    Write-Host "Reiniciar o Windows é recomendado após o reparo." -ForegroundColor Yellow
    Write-Host ""

    $confirmed = Confirm-Action "Deseja executar o reparo rápido de rede e DNS?"

    if ($confirmed -eq $false) {
        Write-Host ""
        Write-Host "Operação cancelada." -ForegroundColor Yellow
        Write-Host ""
        Pause
        return
    }

    try {
        Write-Host ""
        Write-Host "Limpando cache DNS..." -ForegroundColor Green
        ipconfig.exe /flushdns

        Write-Host ""
        Write-Host "Liberando endereço IP..." -ForegroundColor Green
        ipconfig.exe /release

        Write-Host ""
        Write-Host "Renovando endereço IP..." -ForegroundColor Green
        ipconfig.exe /renew

        Write-Host ""
        Write-Host "Resetando Winsock..." -ForegroundColor Green
        netsh.exe winsock reset

        Write-Host ""
        Write-Host "Resetando pilha TCP/IP..." -ForegroundColor Green
        netsh.exe int ip reset

        Write-Host ""
        Write-Host "Reparo rápido de rede e DNS concluído." -ForegroundColor Green
        Write-Host "Reinicie o Windows para aplicar completamente os resets de rede." -ForegroundColor Yellow
    }
    catch {
        Write-Host ""
        Write-Host "Ocorreu um erro durante o reparo de rede:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }

    Write-Host ""
    Pause
}


function Test-NetworkPingTargets {
    Show-Header "Teste de Ping"

    $targets = @(
        [PSCustomObject]@{ Name = "Cloudflare DNS"; Host = "1.1.1.1" },
        [PSCustomObject]@{ Name = "Google DNS"; Host = "8.8.8.8" },
        [PSCustomObject]@{ Name = "Quad9 DNS"; Host = "9.9.9.9" },
        [PSCustomObject]@{ Name = "Microsoft"; Host = "www.microsoft.com" },
        [PSCustomObject]@{ Name = "Google"; Host = "www.google.com" }
    )

    $results = @()

    foreach ($target in $targets) {
        Write-Host "Testando $($target.Name) [$($target.Host)]..." -ForegroundColor Cyan

        try {
            $pingResult = Test-Connection -ComputerName $target.Host -Count 4 -ErrorAction Stop

            $latencies = @(
                $pingResult | ForEach-Object {
                    if ($_.PSObject.Properties.Name -contains "Latency") {
                        $_.Latency
                    }
                    elseif ($_.PSObject.Properties.Name -contains "ResponseTime") {
                        $_.ResponseTime
                    }
                    else {
                        $null
                    }
                } | Where-Object { $null -ne $_ }
            )

            if ($latencies.Count -gt 0) {
                $averageLatency = [Math]::Round(($latencies | Measure-Object -Average).Average, 2)
                $minLatency = [Math]::Round(($latencies | Measure-Object -Minimum).Minimum, 2)
                $maxLatency = [Math]::Round(($latencies | Measure-Object -Maximum).Maximum, 2)
            }
            else {
                $averageLatency = "N/A"
                $minLatency = "N/A"
                $maxLatency = "N/A"
            }

            $results += [PSCustomObject]@{
                Alvo    = $target.Name
                Host    = $target.Host
                Status  = "OK"
                MediaMs = $averageLatency
                MinMs   = $minLatency
                MaxMs   = $maxLatency
            }
        }
        catch {
            $results += [PSCustomObject]@{
                Alvo    = $target.Name
                Host    = $target.Host
                Status  = "Falhou"
                MediaMs = "-"
                MinMs   = "-"
                MaxMs   = "-"
            }
        }
    }

    Write-Host ""
    $results | Format-Table -AutoSize
    Write-Host ""
    Write-Host "Observação: alguns servidores podem bloquear ICMP/ping. Falha em um alvo isolado nem sempre indica problema local." -ForegroundColor Yellow
    Write-Host ""
    Pause
}


function Test-NetworkSpeed {
    Show-Header "Teste de Velocidade da Internet"

    Write-Host "Este teste mede velocidade aproximada de download e upload usando tráfego HTTP." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Não substitui um teste profissional, mas ajuda a identificar gargalos claros." -ForegroundColor Cyan
    Write-Host ""

    Add-Type -AssemblyName System.Net.Http -ErrorAction SilentlyContinue

    $client = [System.Net.Http.HttpClient]::new()
    $client.Timeout = [TimeSpan]::FromSeconds(60)

    try {
        $downloadBytes = 25000000
        $uploadBytesLength = 10000000

        Write-Host ""
        Write-Host "Testando download..." -ForegroundColor Green

        $downloadUrl = "https://speed.cloudflare.com/__down?bytes=$downloadBytes"
        $downloadStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        $downloadData = $client.GetByteArrayAsync($downloadUrl).GetAwaiter().GetResult()
        $downloadStopwatch.Stop()

        $downloadMbps = [Math]::Round((($downloadData.Length * 8) / 1000000) / $downloadStopwatch.Elapsed.TotalSeconds, 2)

        Write-Host "Download aproximado: $downloadMbps Mbps" -ForegroundColor Cyan

        Write-Host ""
        Write-Host "Testando upload..." -ForegroundColor Green

        $uploadBuffer = New-Object byte[] $uploadBytesLength
        $random = [System.Random]::new()
        $random.NextBytes($uploadBuffer)

        $uploadContent = [System.Net.Http.ByteArrayContent]::new($uploadBuffer)
        $uploadUrl = "https://speed.cloudflare.com/__up"

        $uploadStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        $uploadResponse = $client.PostAsync($uploadUrl, $uploadContent).GetAwaiter().GetResult()
        $uploadResponse.EnsureSuccessStatusCode() | Out-Null
        $uploadStopwatch.Stop()

        $uploadMbps = [Math]::Round((($uploadBytesLength * 8) / 1000000) / $uploadStopwatch.Elapsed.TotalSeconds, 2)

        Write-Host "Upload aproximado:   $uploadMbps Mbps" -ForegroundColor Cyan

        Write-Host ""
        Write-Host "Resultado" -ForegroundColor Cyan
        Write-Host "Download: $downloadMbps Mbps"
        Write-Host "Upload:   $uploadMbps Mbps"
    }
    catch {
        Write-Host ""
        Write-Host "O teste de velocidade falhou:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        Write-Host ""
        Write-Host "Verifique conexão, DNS, firewall, VPN ou bloqueio do endpoint de teste." -ForegroundColor Yellow
    }
    finally {
        if ($uploadContent) {
            $uploadContent.Dispose()
        }

        if ($uploadResponse) {
            $uploadResponse.Dispose()
        }

        $client.Dispose()
    }

    Write-Host ""
    Pause
}


function Show-NetworkInformation {
    Show-Header "Informações de Rede"

    try {
        Write-Host "Adaptadores ativos" -ForegroundColor Cyan
        Write-Host ""

        $activeAdapters = @(
            Get-NetAdapter |
            Where-Object { $_.Status -eq "Up" } |
            Select-Object Name, InterfaceDescription, Status, LinkSpeed, MacAddress
        )

        if ($activeAdapters.Count -gt 0) {
            $activeAdapters | Format-Table -AutoSize
        }
        else {
            Write-Host "Nenhum adaptador ativo encontrado." -ForegroundColor Yellow
        }

        Write-Host ""
        Write-Host "Configuração IP" -ForegroundColor Cyan
        Write-Host ""

        $ipConfigurations = @(
            Get-NetIPConfiguration |
            Where-Object { $_.IPv4Address -or $_.IPv6Address }
        )

        foreach ($config in $ipConfigurations) {
            Write-Host "Interface: $($config.InterfaceAlias)" -ForegroundColor Yellow

            if ($config.IPv4Address) {
                Write-Host "IPv4:      $($config.IPv4Address.IPAddress)"
            }

            if ($config.IPv6Address) {
                $ipv6List = ($config.IPv6Address | Select-Object -ExpandProperty IPAddress) -join ", "
                Write-Host "IPv6:      $ipv6List"
            }

            if ($config.IPv4DefaultGateway) {
                Write-Host "Gateway:   $($config.IPv4DefaultGateway.NextHop)"
            }

            $dnsServers = @(
                Get-DnsClientServerAddress -InterfaceIndex $config.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
                Select-Object -ExpandProperty ServerAddresses
            )

            if ($dnsServers.Count -gt 0) {
                Write-Host "DNS IPv4:  $($dnsServers -join ', ')"
            }

            Write-Host ""
        }

        Write-Host "IP público" -ForegroundColor Cyan
        Write-Host ""

        try {
            $publicIp = Invoke-RestMethod -Uri "https://api.ipify.org" -TimeoutSec 8
            Write-Host "IP público: $publicIp"
        }
        catch {
            Write-Host "Não foi possível consultar o IP público." -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "Ocorreu um erro ao listar informações de rede:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }

    Write-Host ""
    Pause
}


Export-ModuleMember -Function *
