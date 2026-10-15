# Rede: reparo de DNS/IP, teste de ping, velocidade e informações dos adaptadores.


# ---------------------------------------------------------------------------
# Utilidades
# ---------------------------------------------------------------------------

function Get-WinForgeMbps {
    # Megabits por segundo a partir de bytes e segundos; devolve 0 quando o tempo é desprezível.
    param (
        [double]$Bytes,
        [double]$Seconds
    )

    if ($Seconds -lt 0.05 -or $Bytes -le 0) {
        return 0.0
    }

    return [Math]::Round((($Bytes * 8) / 1000000) / $Seconds, 2)
}


function Get-WinForgeInnerMessage {
    # Exceções de tarefas assíncronas chegam embrulhadas em AggregateException.
    param (
        [Parameter(Mandatory)]
        [System.Exception]$Exception
    )

    $current = $Exception

    while ($null -ne $current.InnerException) {
        $current = $current.InnerException
    }

    return $current.Message
}


function Wait-WinForgeTask {
    # Espera uma Task em fatias curtas: o botão Parar (ou Ctrl+C) interrompe o teste sem esperar a rede.
    param (
        [Parameter(Mandatory)]
        $Task,

        [int]$TimeoutSeconds = 30
    )

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    while (-not $Task.Wait(250)) {
        if ($stopwatch.Elapsed.TotalSeconds -gt $TimeoutSeconds) {
            throw "Tempo esgotado ao aguardar a resposta do servidor."
        }
    }
}


# ---------------------------------------------------------------------------
# Conectividade e ping
# ---------------------------------------------------------------------------

function Get-WinForgePingStats {
    param (
        [Parameter(Mandatory)]
        [string]$ComputerName,

        [ValidateRange(1, 50)]
        [int]$Count = 4
    )

    # Um pacote perdido não deve marcar o alvo inteiro como falho: calcula perda e latência a partir das respostas
    # recebidas (compatível com Windows PowerShell 5.1, onde a latência é ResponseTime, e PowerShell 7, onde é Latency).
    $replies = @(Test-Connection -ComputerName $ComputerName -Count $Count -ErrorAction SilentlyContinue)

    $successful = @(
        $replies | Where-Object {
            $null -ne $_ -and (
                -not ($_.PSObject.Properties.Name -contains "Status") -or
                [string]$_.Status -eq "Success"
            )
        }
    )

    $latencies = @(
        $successful | ForEach-Object {
            if ($_.PSObject.Properties.Name -contains "Latency") { [double]$_.Latency }
            elseif ($_.PSObject.Properties.Name -contains "ResponseTime") { [double]$_.ResponseTime }
        } | Where-Object { $null -ne $_ }
    )

    $received = [Math]::Min($successful.Count, $Count)
    $lossPercent = [Math]::Round((($Count - $received) / $Count) * 100, 0)

    if ($latencies.Count -gt 0) {
        $measure = $latencies | Measure-Object -Average -Minimum -Maximum
        $average = [Math]::Round($measure.Average, 1)
        $minimum = [Math]::Round($measure.Minimum, 1)
        $maximum = [Math]::Round($measure.Maximum, 1)
    }
    else {
        $average = "-"; $minimum = "-"; $maximum = "-"
    }

    return [PSCustomObject]@{
        Received = $received
        Sent     = $Count
        Loss     = $lossPercent
        Average  = $average
        Minimum  = $minimum
        Maximum  = $maximum
    }
}


function Get-WinForgePingStatusText {
    param (
        [int]$LossPercent
    )

    if ($LossPercent -ge 100) { return "Sem resposta" }
    if ($LossPercent -gt 0) { return "Instável" }
    return "OK"
}


function Test-WinForgeInternetConnectivity {
    # Separa "sem rota" (acesso a IPs) de "sem DNS" (resolução de nomes): cada um aponta para um reparo diferente.
    # Redes e firewalls que bloqueiam o ping (ICMP) são comuns; por isso, se o ping falha, uma conexão TCP na porta 443
    # decide. Sem isso, uma rede saudável seria tratada como quebrada e a Manutenção redefiniria o Winsock sem motivo.
    $pingOk = $false
    $viaTcp = $false
    $targets = @("1.1.1.1", "8.8.8.8")

    foreach ($target in $targets) {
        try {
            $stats = Get-WinForgePingStats -ComputerName $target -Count 2

            if ($stats.Received -gt 0) {
                $pingOk = $true
                break
            }
        }
        catch {
            # Tenta o próximo alvo.
        }
    }

    if (-not $pingOk) {
        foreach ($target in $targets) {
            if (Test-WinForgeTcpConnection -ComputerName $target -Port 443) {
                $pingOk = $true
                $viaTcp = $true
                break
            }
        }
    }

    $dnsOk = Test-WinForgeDnsResolution -Name "www.microsoft.com"

    return [PSCustomObject]@{
        PingOk = $pingOk
        ViaTcp = $viaTcp
        DnsOk  = $dnsOk
        Ok     = ($pingOk -and $dnsOk)
    }
}


function Get-WinForgeIpReachText {
    # Texto do "acesso por IP direto" (sem DNS) para as telas de diagnóstico e de reparo.
    param (
        [Parameter(Mandatory)]
        $Connectivity
    )

    if (-not $Connectivity.PingOk) { return "Sem resposta" }
    if ($Connectivity.ViaTcp) { return "Responde (o ping está bloqueado, mas a conexão TCP funciona)" }

    return "Responde"
}


function Get-WinForgePingVerdict {
    <#
    Conclusão do teste de conectividade. Results: objetos com Host e Loss (perda em %). Separa três casos que pedem
    ações diferentes: nada responde (cabo, Wi-Fi, roteador), os IPs respondem mas os nomes não (DNS) e tudo responde.
    Devolve Level (Error, Warning, Success) e Message.
    #>
    param (
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Results
    )

    $addressPattern = '^[0-9]{1,3}(\.[0-9]{1,3}){3}$'
    $answered = @($Results | Where-Object { [int]$_.Loss -lt 100 })
    $byAddress = @($Results | Where-Object { [string]$_.Host -match $addressPattern })
    $byName = @($Results | Where-Object { [string]$_.Host -notmatch $addressPattern })
    $addressAnswered = @($byAddress | Where-Object { [int]$_.Loss -lt 100 }).Count
    $nameAnswered = @($byName | Where-Object { [int]$_.Loss -lt 100 }).Count

    if ($answered.Count -eq 0) {
        return [PSCustomObject]@{ Level = "Error"; Message = "Nenhum alvo respondeu. Verifique cabo/Wi-Fi, roteador e firewall." }
    }

    if ($addressAnswered -gt 0 -and $byName.Count -gt 0 -and $nameAnswered -eq 0) {
        return [PSCustomObject]@{ Level = "Warning"; Message = "Os endereços IP respondem, mas os nomes (www.microsoft.com, www.google.com) não: o problema é de DNS. Use 'Reparar rede e DNS'." }
    }

    if ($answered.Count -lt @($Results).Count) {
        return [PSCustomObject]@{ Level = "Warning"; Message = "Alguns alvos não responderam. Alguns servidores bloqueiam ICMP; compare com os demais." }
    }

    return [PSCustomObject]@{ Level = "Success"; Message = "Todos os alvos responderam." }
}


function Test-WinForgePing {
    Enter-WinForgeAction -Title "Testar conectividade (ping)"

    $targets = @(
        [PSCustomObject]@{ Name = "Cloudflare DNS"; Host = "1.1.1.1" },
        [PSCustomObject]@{ Name = "Google DNS"; Host = "8.8.8.8" },
        [PSCustomObject]@{ Name = "Quad9 DNS"; Host = "9.9.9.9" },
        [PSCustomObject]@{ Name = "Microsoft"; Host = "www.microsoft.com" },
        [PSCustomObject]@{ Name = "Google"; Host = "www.google.com" }
    )

    try {
        $results = @()
        $index = 0

        foreach ($target in $targets) {
            Write-WinForgeProgress -Current $index -Total $targets.Count -Label "Testando $($target.Name) [$($target.Host)]"
            $index++

            try {
                $stats = Get-WinForgePingStats -ComputerName $target.Host -Count 4
            }
            catch {
                $stats = [PSCustomObject]@{ Received = 0; Sent = 4; Loss = 100; Average = "-"; Minimum = "-"; Maximum = "-" }
            }

            $results += [PSCustomObject]@{
                Host   = $target.Host
                Loss   = $stats.Loss
                Linha  = [PSCustomObject]@{
                    "Alvo"       = $target.Name
                    "Host"       = $target.Host
                    "Status"     = Get-WinForgePingStatusText -LossPercent $stats.Loss
                    "Perda"      = "$($stats.Loss)%"
                    "Média (ms)" = $stats.Average
                    "Mín. (ms)"  = $stats.Minimum
                    "Máx. (ms)"  = $stats.Maximum
                }
            }
        }

        Write-WinForgeSection -Title "Resultado"
        $results | ForEach-Object { $_.Linha } | Format-Table -AutoSize | Out-Host

        $verdict = Get-WinForgePingVerdict -Results $results
        Write-WinForgeStatus -Type $verdict.Level -Message $verdict.Message
    }
    catch {
        Write-WinForgeStatus -Type Error -Message "Ocorreu um erro no teste de ping: $($_.Exception.Message)"
    }

    Exit-WinForgeAction
}


# ---------------------------------------------------------------------------
# Reparo de rede e DNS
# ---------------------------------------------------------------------------

function Test-WinForgeStaticIpConfigured {
    # Verdadeiro se alguma interface com gateway usa IPv4 estático (DHCP desativado).
    try {
        $configurations = @(Get-NetIPConfiguration -ErrorAction Stop | Where-Object { $_.IPv4DefaultGateway })

        foreach ($configuration in $configurations) {
            $interface = Get-NetIPInterface -InterfaceIndex $configuration.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue

            if ($null -ne $interface -and [string]$interface.Dhcp -eq "Disabled") {
                return $true
            }
        }
    }
    catch {
        # Sem informação: trata como DHCP.
    }

    return $false
}


function Get-WinForgeNetworkRepairCommands {
    param (
        [switch]$HasStaticIp
    )

    # A ordem importa: o IP é liberado e renovado primeiro, a limpeza de DNS vem depois (já com o IP novo) e os
    # resets de Winsock/TCP-IP ficam por último porque só terminam de valer após reiniciar.
    # Com IP estático, release/renew e o reset de TCP/IP removeriam a configuração manual.
    $commands = @()

    if (-not $HasStaticIp) {
        $commands += [PSCustomObject]@{ Title = "Liberar endereço IP"; FilePath = "ipconfig.exe"; Arguments = @("/release") }
        $commands += [PSCustomObject]@{ Title = "Renovar endereço IP"; FilePath = "ipconfig.exe"; Arguments = @("/renew") }
    }

    $commands += [PSCustomObject]@{ Title = "Limpar cache DNS"; FilePath = "ipconfig.exe"; Arguments = @("/flushdns") }
    $commands += [PSCustomObject]@{ Title = "Redefinir Winsock"; FilePath = "netsh.exe"; Arguments = @("winsock", "reset") }

    if (-not $HasStaticIp) {
        $commands += [PSCustomObject]@{ Title = "Redefinir TCP/IP"; FilePath = "netsh.exe"; Arguments = @("int", "ip", "reset") }
    }

    return @($commands)
}


function Invoke-WinForgeNetworkCommand {
    # Executa um comando de rede e devolve um WinForge.Result.
    param (
        [Parameter(Mandatory)]
        [string]$Title,

        [Parameter(Mandatory)]
        [string]$FilePath,

        [string[]]$Arguments = @()
    )

    Write-WinForgeStatus -Type Running -Message $Title

    try {
        $exitCode = Invoke-WinForgeNative -FilePath $FilePath -Arguments $Arguments -IgnoreExitCode -PassThru
    }
    catch {
        Write-WinForgeStatus -Type Error -Message "$Title falhou: $($_.Exception.Message)"
        $result = New-WinForgeResult -Kind Failed -Detail $_.Exception.Message
        $result.Etapa = $Title
        return $result
    }

    $result = Get-WinForgeExitCodeResult -ExitCode $exitCode
    $result.Etapa = $Title

    if ($result.Kind -eq "Ok") {
        Write-WinForgeStatus -Type Success -Message "$Title concluído."
    }
    else {
        Write-WinForgeStatus -Type Warning -Message "$Title finalizou com código $exitCode."
    }

    return $result
}


function Wait-WinForgeInternet {
    # Depois do reset o adaptador demora a voltar: tenta algumas vezes antes de concluir que ainda está sem internet.
    param (
        [int]$Attempts = 4,
        [int]$DelaySeconds = 3
    )

    $connectivity = $null

    for ($attempt = 1; $attempt -le $Attempts; $attempt++) {
        Start-Sleep -Seconds $DelaySeconds
        $connectivity = Test-WinForgeInternetConnectivity

        if ($connectivity.Ok) {
            break
        }
    }

    return $connectivity
}


function Invoke-WinForgeNetworkRepair {
    param (
        [switch]$Embedded,
        [switch]$PassThru
    )

    $title = "Reparar rede e DNS"

    Enter-WinForgeAction -Title $title -Embedded:$Embedded

    if (-not (Test-WinForgeElevation -Reason "O reparo de rede exige privilégios de Administrador.")) {
        if ($PassThru) { New-WinForgeResult -Kind Failed -Detail "sem privilégios de Administrador" -Title $title }
        Exit-WinForgeAction -Embedded:$Embedded
        return
    }

    $hasStaticIp = Test-WinForgeStaticIpConfigured
    $final = New-WinForgeResult -Kind Ok -Title $title

    Write-Host "Executa correções comuns de IP, DNS, Winsock e TCP/IP." -ForegroundColor Yellow

    Write-WinForgeSection -Title "Diagnóstico rápido"
    $connectivity = Test-WinForgeInternetConnectivity
    Write-WinForgeKeyValue -Label "Acesso por IP (sem DNS)" -Value (Get-WinForgeIpReachText -Connectivity $connectivity)
    Write-WinForgeKeyValue -Label "Resolução de DNS" -Value $(if ($connectivity.DnsOk) { "Funciona" } else { "Falhou" })

    # Dentro da Manutenção recomendada o reparo só roda se algo estiver quebrado.
    if ($Embedded -and $connectivity.Ok) {
        Write-WinForgeStatus -Type Success -Message "A conexão e o DNS funcionam. O reparo de rede não é necessário."

        if ($PassThru) { New-WinForgeResult -Kind Skipped -Detail "rede funcionando" -Title $title }
        Exit-WinForgeAction -Embedded:$Embedded
        return
    }

    Write-WinForgeSection -Title "Comandos que serão executados"

    foreach ($command in (Get-WinForgeNetworkRepairCommands -HasStaticIp:$hasStaticIp)) {
        Write-WinForgeCommand -Command "$($command.FilePath -replace '\.exe$', '') $($command.Arguments -join ' ')"
    }

    Write-Host ""

    if ($hasStaticIp) {
        Write-WinForgeStatus -Type Warning -Message "IP estático detectado: liberar/renovar IP e redefinir TCP/IP foram removidos para não apagar sua configuração."
    }

    Write-WinForgeStatus -Type Warning -Message "A conexão pode cair por alguns instantes. O reset do Winsock pode afetar VPN e alguns antivírus."

    if ($connectivity.Ok) {
        Write-WinForgeStatus -Type Info -Message "A internet parece funcionar normalmente. Só continue se estiver com um problema de rede."
    }

    Write-Host ""

    # Com a internet funcionando a resposta padrão é Não; com problema, Sim. Na Manutenção, o usuário já confirmou.
    $defaultKey = if ($connectivity.Ok) { "N" } else { "S" }

    if (-not $Embedded -and -not (Confirm-WinForgeAction "Deseja executar o reparo de rede e DNS?" -DefaultKey $defaultKey)) {
        Write-Host ""
        Write-WinForgeStatus -Type Warning -Message "Operação cancelada."

        if ($PassThru) { New-WinForgeResult -Kind Skipped -Detail "cancelado pelo usuário" -Title $title }
        Exit-WinForgeAction -Embedded:$Embedded
        return
    }

    try {
        $steps = @()

        foreach ($command in (Get-WinForgeNetworkRepairCommands -HasStaticIp:$hasStaticIp)) {
            $steps += (Invoke-WinForgeNetworkCommand -Title $command.Title -FilePath $command.FilePath -Arguments $command.Arguments)
        }

        Write-Host ""
        Write-WinForgeStatus -Type Running -Message "Verificando a conexão..."
        $after = Wait-WinForgeInternet

        Write-WinForgeKeyValue -Label "Acesso por IP (sem DNS)" -Value (Get-WinForgeIpReachText -Connectivity $after)
        Write-WinForgeKeyValue -Label "Resolução de DNS" -Value $(if ($after.DnsOk) { "Funciona" } else { "Falhou" })
        Write-Host ""

        $failedSteps = @($steps | Where-Object { $_.Kind -eq "Failed" })

        # Os resets de Winsock e TCP/IP só terminam de valer depois de reiniciar.
        $restart = @{ RebootRequired = $true }

        if ($failedSteps.Count -gt 0) {
            $final = New-WinForgeResult -Kind Warning -Detail "$($failedSteps.Count) comando(s) falharam" -Title $title -Data $restart
            Write-WinForgeStatus -Type Warning -Message "Reparo concluído com alertas. Revise os resultados acima."
        }
        elseif (-not $after.Ok) {
            $final = New-WinForgeResult -Kind Warning -Detail "sem conexão após o reparo; reinicie" -Title $title -Data $restart
            Write-WinForgeStatus -Type Warning -Message "Os comandos foram executados, mas a conexão ainda não voltou. Reinicie o Windows e teste novamente."
        }
        else {
            $final = New-WinForgeResult -Kind Ok -Title $title -Data $restart
            Write-WinForgeStatus -Type Success -Message "Reparo de rede e DNS concluído e a conexão está funcionando."
        }

        Write-WinForgeStatus -Type Info -Message "Reinicie o Windows para concluir os resets de Winsock e TCP/IP."
    }
    catch {
        Write-Host ""
        Write-WinForgeStatus -Type Error -Message "Falha durante o reparo de rede: $($_.Exception.Message)"
        $final = New-WinForgeResult -Kind Failed -Detail $_.Exception.Message -Title $title
    }

    if ($PassThru) { $final }
    Exit-WinForgeAction -Embedded:$Embedded
}


# ---------------------------------------------------------------------------
# Teste de velocidade
# ---------------------------------------------------------------------------

function Measure-WinForgeDownload {
    # Baixa dados do Cloudflare até o limite de bytes ou de tempo e devolve a velocidade em Mbps.
    param (
        [int64]$MaxBytes = 25000000,
        [int]$MaxSeconds = 12
    )

    $client = [System.Net.Http.HttpClient]::new()
    $client.Timeout = [TimeSpan]::FromSeconds(30)
    $response = $null
    $stream = $null

    try {
        $url = "https://speed.cloudflare.com/__down?bytes=$MaxBytes"
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

        $request = $client.GetAsync($url, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead)
        Wait-WinForgeTask -Task $request -TimeoutSeconds 30
        $response = $request.Result
        [void]$response.EnsureSuccessStatusCode()

        $streamTask = $response.Content.ReadAsStreamAsync()
        Wait-WinForgeTask -Task $streamTask -TimeoutSeconds 30
        $stream = $streamTask.Result

        $buffer = New-Object byte[] 65536
        [int64]$total = 0

        while ($total -lt $MaxBytes -and $stopwatch.Elapsed.TotalSeconds -lt $MaxSeconds) {
            $read = $stream.ReadAsync($buffer, 0, $buffer.Length)
            Wait-WinForgeTask -Task $read -TimeoutSeconds 20

            if ($read.Result -le 0) {
                break
            }

            $total += $read.Result
        }

        $stopwatch.Stop()

        return [PSCustomObject]@{
            Bytes   = $total
            Seconds = [Math]::Round($stopwatch.Elapsed.TotalSeconds, 2)
            Mbps    = Get-WinForgeMbps -Bytes $total -Seconds $stopwatch.Elapsed.TotalSeconds
        }
    }
    finally {
        if ($stream) { $stream.Dispose() }
        if ($response) { $response.Dispose() }
        $client.Dispose()
    }
}


function Measure-WinForgeUpload {
    # Envia blocos de 1 MB ao Cloudflare até o limite de tempo; conexões lentas fazem poucos envios, rápidas fazem vários.
    param (
        [int]$ChunkBytes = 1000000,
        [int]$MaxSeconds = 8,
        [int]$MaxChunks = 12
    )

    $client = [System.Net.Http.HttpClient]::new()
    $client.Timeout = [TimeSpan]::FromSeconds(40)

    try {
        $buffer = New-Object byte[] $ChunkBytes
        (New-Object System.Random).NextBytes($buffer)

        [int64]$total = 0
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

        for ($chunk = 0; $chunk -lt $MaxChunks -and $stopwatch.Elapsed.TotalSeconds -lt $MaxSeconds; $chunk++) {
            $content = [System.Net.Http.ByteArrayContent]::new($buffer)
            $response = $null

            try {
                $post = $client.PostAsync("https://speed.cloudflare.com/__up", $content)
                Wait-WinForgeTask -Task $post -TimeoutSeconds 40
                $response = $post.Result
                [void]$response.EnsureSuccessStatusCode()
                $total += $ChunkBytes
            }
            finally {
                $content.Dispose()
                if ($response) { $response.Dispose() }
            }
        }

        $stopwatch.Stop()

        return [PSCustomObject]@{
            Bytes   = $total
            Seconds = [Math]::Round($stopwatch.Elapsed.TotalSeconds, 2)
            Mbps    = Get-WinForgeMbps -Bytes $total -Seconds $stopwatch.Elapsed.TotalSeconds
        }
    }
    finally {
        $client.Dispose()
    }
}


function Test-WinForgeInternetSpeed {
    Enter-WinForgeAction -Title "Testar velocidade da internet"

    Write-Host "Mede a velocidade aproximada de download e upload com tráfego HTTP (Cloudflare)." -ForegroundColor Yellow
    Write-Host "Não substitui um teste profissional, mas ajuda a identificar gargalos claros." -ForegroundColor Cyan
    Write-Host ""
    Write-WinForgeStatus -Type Info -Message "O teste usa até cerca de 35 MB de dados. Evite em conexões limitadas (4G/5G com franquia)."
    Write-Host ""

    if (-not (Confirm-WinForgeAction "Deseja iniciar o teste de velocidade?" -DefaultKey S)) {
        Write-WinForgeStatus -Type Warning -Message "Teste cancelado."
        Exit-WinForgeAction
        return
    }

    try {
        Enable-WinForgeTls12
        Add-Type -AssemblyName System.Net.Http -ErrorAction SilentlyContinue

        Write-Host ""
        Write-WinForgeStatus -Type Running -Message "Testando download (até 12 s)..."

        $download = Measure-WinForgeDownload
        Write-WinForgeStatus -Type Success -Message "Download medido: $($download.Mbps) Mbps"

        Write-WinForgeStatus -Type Running -Message "Testando upload (até 8 s)..."

        $upload = Measure-WinForgeUpload
        Write-WinForgeStatus -Type Success -Message "Upload medido: $($upload.Mbps) Mbps"

        Write-WinForgeSection -Title "Resultado"
        Write-WinForgeKeyValue -Label "Download" -Value "$($download.Mbps) Mbps  ($(Format-WinForgeBytes -Bytes $download.Bytes) em $($download.Seconds) s)"
        Write-WinForgeKeyValue -Label "Upload" -Value "$($upload.Mbps) Mbps  ($(Format-WinForgeBytes -Bytes $upload.Bytes) em $($upload.Seconds) s)"

        if ($download.Mbps -le 0 -or $upload.Mbps -le 0) {
            Write-Host ""
            Write-WinForgeStatus -Type Warning -Message "Uma das medições retornou zero. Repita o teste ou verifique a conexão."
        }
    }
    catch {
        Write-Host ""
        Write-WinForgeStatus -Type Error -Message "O teste de velocidade falhou: $(Get-WinForgeInnerMessage -Exception $_.Exception)"
        Write-Host "      Verifique conexão, DNS, firewall, VPN ou bloqueio do endereço de teste." -ForegroundColor DarkGray
    }

    Exit-WinForgeAction
}


# ---------------------------------------------------------------------------
# Informações de rede
# ---------------------------------------------------------------------------

function Show-WinForgeNetworkInfo {
    Enter-WinForgeAction -Title "Informações de rede"

    try {
        Write-WinForgeSection -Title "Adaptadores ativos"

        $activeAdapters = @(
            Get-NetAdapter -ErrorAction Stop |
            Where-Object { $_.Status -eq "Up" } |
            Select-Object Name, InterfaceDescription, Status, LinkSpeed, MacAddress
        )

        if ($activeAdapters.Count -gt 0) {
            $activeAdapters | Format-Table -AutoSize | Out-Host
        }
        else {
            Write-WinForgeStatus -Type Warning -Message "Nenhum adaptador ativo encontrado."
        }

        Write-WinForgeSection -Title "Configuração IP"

        $ipConfigurations = @(
            Get-NetIPConfiguration -ErrorAction Stop |
            Where-Object { $_.IPv4Address -or $_.IPv6Address }
        )

        if ($ipConfigurations.Count -eq 0) {
            Write-WinForgeStatus -Type Warning -Message "Nenhuma interface com endereço IP."
        }

        foreach ($config in $ipConfigurations) {
            Write-Host ""
            Write-Host "  $($config.InterfaceAlias)" -ForegroundColor Yellow

            if ($config.IPv4Address) {
                Write-WinForgeKeyValue -Label "IPv4" -Value (@($config.IPv4Address | ForEach-Object { $_.IPAddress }) -join ", ") -LabelWidth 14
            }

            if ($config.IPv6Address) {
                Write-WinForgeKeyValue -Label "IPv6" -Value (@($config.IPv6Address | ForEach-Object { $_.IPAddress }) -join ", ") -LabelWidth 14
            }

            if ($config.IPv4DefaultGateway) {
                Write-WinForgeKeyValue -Label "Gateway" -Value (@($config.IPv4DefaultGateway | ForEach-Object { $_.NextHop }) -join ", ") -LabelWidth 14
            }

            $dnsServers = @(
                Get-DnsClientServerAddress -InterfaceIndex $config.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
                ForEach-Object { $_.ServerAddresses }
            )

            if ($dnsServers.Count -gt 0) {
                Write-WinForgeKeyValue -Label "DNS IPv4" -Value ($dnsServers -join ", ") -LabelWidth 14
            }
        }

        Write-WinForgeSection -Title "IP público"

        if ($activeAdapters.Count -eq 0) {
            # Sem adaptador ativo a consulta só esperaria o tempo limite.
            Write-WinForgeStatus -Type Info -Message "Sem adaptador de rede ativo; a consulta do IP público foi ignorada."
        }
        else {
            Write-Host "  Consulta api.ipify.org para descobrir o endereço visto pela internet." -ForegroundColor DarkGray

            try {
                Enable-WinForgeTls12
                $publicIp = Invoke-RestMethod -Uri "https://api.ipify.org" -TimeoutSec 8
                Write-WinForgeKeyValue -Label "Endereço" -Value ([string]$publicIp).Trim()
            }
            catch {
                Write-WinForgeStatus -Type Warning -Message "Não foi possível consultar o IP público (sem internet ou bloqueio)."
            }
        }
    }
    catch {
        Write-WinForgeStatus -Type Error -Message "Ocorreu um erro ao listar informações de rede: $($_.Exception.Message)"
    }

    Exit-WinForgeAction
}


Export-ModuleMember -Function *
