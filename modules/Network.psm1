function Invoke-WinForgeNetworkCommand {
    param (
        [Parameter(Mandatory)]
        [string]$Title,

        [Parameter(Mandatory)]
        [string]$FilePath,

        [string[]]$Arguments = @()
    )

    Write-WinForgeStatus -Type Running -Message $Title
    & $FilePath @Arguments | Out-Host
    $exitCode = $LASTEXITCODE

    if ($exitCode -eq 0) {
        Write-WinForgeStatus -Type Success -Message "$Title concluído."
        return $true
    }

    Write-WinForgeStatus -Type Warning -Message "$Title finalizou com código $exitCode."
    return $false
}


function Invoke-NetworkRepair {
    Show-Header "Reparo Rápido de Rede e DNS"

    if (-not (Test-IsAdministrator)) {
        Write-WinForgeStatus -Type Error -Message "Privilégios de Administrador são necessários."
        Write-Host ""
        Pause
        return
    }

    Write-Host "Executa correções comuns de DNS, endereço IP, Winsock e TCP/IP." -ForegroundColor Yellow
    Write-WinForgeSection -Title "Comandos"
    Write-WinForgeCommand -Command "ipconfig /flushdns"
    Write-WinForgeCommand -Command "ipconfig /release"
    Write-WinForgeCommand -Command "ipconfig /renew"
    Write-WinForgeCommand -Command "netsh winsock reset"
    Write-WinForgeCommand -Command "netsh int ip reset"
    Write-Host ""
    Write-WinForgeWarn "A conexão pode cair temporariamente. Reinicie o Windows ao final."
    Write-Host ""

    if (-not (Confirm-Action "Deseja executar o reparo rápido de rede e DNS?")) {
        Write-Host ""
        Write-WinForgeStatus -Type Warning -Message "Operação cancelada."
        Write-Host ""
        Pause
        return
    }

    try {
        $results = @(
            Invoke-WinForgeNetworkCommand -Title "Limpar cache DNS" -FilePath "ipconfig.exe" -Arguments @("/flushdns")
            Invoke-WinForgeNetworkCommand -Title "Liberar endereço IP" -FilePath "ipconfig.exe" -Arguments @("/release")
            Invoke-WinForgeNetworkCommand -Title "Renovar endereço IP" -FilePath "ipconfig.exe" -Arguments @("/renew")
            Invoke-WinForgeNetworkCommand -Title "Redefinir Winsock" -FilePath "netsh.exe" -Arguments @("winsock", "reset")
            Invoke-WinForgeNetworkCommand -Title "Redefinir TCP/IP" -FilePath "netsh.exe" -Arguments @("int", "ip", "reset")
        )

        Write-Host ""

        if ($results -notcontains $false) {
            Write-WinForgeStatus -Type Success -Message "Reparo de rede e DNS concluído."
        }
        else {
            Write-WinForgeStatus -Type Warning -Message "Reparo concluído com alertas. Revise os resultados acima."
        }

        Write-WinForgeWarn "Reinicie o Windows para concluir os resets de rede."
    }
    catch {
        Write-Host ""
        Write-WinForgeStatus -Type Error -Message "Falha durante o reparo de rede."
        Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
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

    Write-WinForgeSection -Title "Resultado"
    $results |
        Select-Object `
            @{ Name = "Alvo"; Expression = { $_.Alvo } },
            @{ Name = "Host"; Expression = { $_.Host } },
            @{ Name = "Status"; Expression = { $_.Status } },
            @{ Name = "Média (ms)"; Expression = { $_.MediaMs } },
            @{ Name = "Mín. (ms)"; Expression = { $_.MinMs } },
            @{ Name = "Máx. (ms)"; Expression = { $_.MaxMs } } |
        Format-Table -AutoSize |
        Out-Host
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
    $uploadContent = $null
    $uploadResponse = $null

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

        Write-WinForgeStatus -Type Success -Message "Download medido: $downloadMbps Mbps"

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

        Write-WinForgeStatus -Type Success -Message "Upload medido: $uploadMbps Mbps"

        Write-WinForgeSection -Title "Resultado"
        Write-WinForgeKeyValue -Label "Download" -Value "$downloadMbps Mbps"
        Write-WinForgeKeyValue -Label "Upload" -Value "$uploadMbps Mbps"
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
        Write-WinForgeSection -Title "Adaptadores ativos"

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

        Write-WinForgeSection -Title "Configuração IP"

        $ipConfigurations = @(
            Get-NetIPConfiguration |
            Where-Object { $_.IPv4Address -or $_.IPv6Address }
        )

        foreach ($config in $ipConfigurations) {
            Write-Host ""
            Write-Host "  $($config.InterfaceAlias)" -ForegroundColor Yellow

            if ($config.IPv4Address) {
                Write-WinForgeKeyValue -Label "IPv4" -Value $config.IPv4Address.IPAddress -LabelWidth 14
            }

            if ($config.IPv6Address) {
                $ipv6List = ($config.IPv6Address | Select-Object -ExpandProperty IPAddress) -join ", "
                Write-WinForgeKeyValue -Label "IPv6" -Value $ipv6List -LabelWidth 14
            }

            if ($config.IPv4DefaultGateway) {
                Write-WinForgeKeyValue -Label "Gateway" -Value $config.IPv4DefaultGateway.NextHop -LabelWidth 14
            }

            $dnsServers = @(
                Get-DnsClientServerAddress -InterfaceIndex $config.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
                Select-Object -ExpandProperty ServerAddresses
            )

            if ($dnsServers.Count -gt 0) {
                Write-WinForgeKeyValue -Label "DNS IPv4" -Value ($dnsServers -join ', ') -LabelWidth 14
            }

            Write-Host ""
        }

        Write-WinForgeSection -Title "IP público"

        try {
            $publicIp = Invoke-RestMethod -Uri "https://api.ipify.org" -TimeoutSec 8
            Write-WinForgeKeyValue -Label "Endereço" -Value $publicIp
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
