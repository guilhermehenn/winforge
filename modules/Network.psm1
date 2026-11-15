# Rede: reparo de DNS/IP, teste de ping, velocidade e informações dos adaptadores.

# O teste de velocidade atrás de um proxy que pede autenticação e não aceitou a conta do Windows.
$script:WinForgeProxyAuthProblem = "o proxy da rede pediu autenticação (HTTP 407) e não aceitou a conta do Windows; o teste não consegue passar por ele"


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


function New-WinForgeSpeedHttpClient {
    <#
    O HttpClient do teste de velocidade, pelo proxy do sistema e com a conta do Windows: numa rede de empresa o proxy
    pede autenticação, e o navegador passa por ele com a conta logada. Sem isso o teste parava num "407" sem explicação.
    #>
    param ([int]$TimeoutSeconds = 30)

    $handler = New-Object System.Net.Http.HttpClientHandler

    try {
        $proxy = [System.Net.WebRequest]::GetSystemWebProxy()

        if ($null -ne $proxy) {
            $proxy.Credentials = [System.Net.CredentialCache]::DefaultCredentials
            $handler.Proxy = $proxy
            $handler.UseProxy = $true
        }
    }
    catch {
        # Sem o proxy do sistema, segue com o padrão do HttpClient.
    }

    $client = [System.Net.Http.HttpClient]::new($handler)
    $client.Timeout = [TimeSpan]::FromSeconds($TimeoutSeconds)

    return $client
}


function Get-WinForgeSpeedProblem {
    # O motivo de uma medição ter falhado, para a pessoa: o proxy que pede autenticação (HTTP 407) vira uma frase; o resto
    # é a mensagem mais interna da exceção.
    param (
        [Parameter(Mandatory)]
        [System.Exception]$Exception
    )

    $message = Get-WinForgeInnerMessage -Exception $Exception
    $texts = New-Object System.Collections.ArrayList
    $current = $Exception

    while ($null -ne $current) {
        [void]$texts.Add([string]$current.Message)
        $current = $current.InnerException
    }

    # "(407) Proxy Authentication Required" (Windows PowerShell) ou "407 (Proxy Authentication Required)" (PowerShell 7).
    if (($texts -join " ") -match '(?i)\(407\)|\b407 \(|proxy authentication required') {
        return $script:WinForgeProxyAuthProblem
    }

    return $message
}


function Assert-WinForgeSpeedResponse {
    # Falha com uma frase quando o servidor (ou o proxy) não respondeu com sucesso.
    param ([Parameter(Mandatory)]$Response)

    if ([int]$Response.StatusCode -eq 407) {
        throw $script:WinForgeProxyAuthProblem
    }

    [void]$Response.EnsureSuccessStatusCode()
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
    $arguments = @{ ComputerName = $ComputerName; Count = $Count; ErrorAction = "SilentlyContinue" }

    # O PowerShell 7 espera 5 s por resposta: sem internet, três IPs com quatro pings cada deixavam a tela parada por mais de
    # um minuto. O Windows PowerShell 5.1 não tem esse parâmetro.
    if ((Get-Command -Name Test-Connection -ErrorAction SilentlyContinue).Parameters.ContainsKey("TimeoutSeconds")) {
        $arguments.TimeoutSeconds = 3
    }

    $replies = @(Test-Connection @arguments)

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


function Get-WinForgeWindowsInternetStatus {
    <#
    O que o próprio Windows diz da conexão (o teste dele passa pelo proxy configurado no PC): $true quando alguma rede
    conectada tem acesso à internet (IPv4Connectivity ou IPv6Connectivity = Internet), $false quando há redes e nenhuma
    tem, e $null quando não deu para saber.
    #>
    try {
        $profiles = @(Get-NetConnectionProfile -ErrorAction Stop | Where-Object { $null -ne $_ })
    }
    catch {
        return $null
    }

    foreach ($connection in $profiles) {
        foreach ($name in @("IPv4Connectivity", "IPv6Connectivity")) {
            $property = $connection.PSObject.Properties[$name]
            if ($null -ne $property -and [string]$property.Value -eq "Internet") { return $true }
        }
    }

    return $false
}


function Test-WinForgeNetworkConnected {
    <#
    Se o Windows está ligado a alguma rede (um perfil de conexão, com ou sem internet): $true, $false quando não há
    nenhuma (Wi-Fi desligado, cabo solto, modo avião) e $null quando não deu para saber.
    #>
    try {
        $profiles = @(Get-NetConnectionProfile -ErrorAction Stop | Where-Object { $null -ne $_ })
    }
    catch {
        # Sem nenhum perfil, a consulta pode responder com o erro de "nenhum objeto encontrado" em vez de uma lista vazia.
        if ([string]$_.Exception.Message -match 'MSFT_NetConnectionProfile') { return $false }

        return $null
    }

    return ($profiles.Count -gt 0)
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


function Test-WinForgeIpAddressText {
    # Verdadeiro só se o texto inteiro é um endereço IPv4 (quatro números) ou IPv6. Uma página HTML, uma mensagem de erro ou
    # um texto vazio dão falso.
    param (
        [string]$Text
    )

    $value = ([string]$Text).Trim()
    $parsed = $null

    if ($value -match '^[0-9]{1,3}(\.[0-9]{1,3}){3}$' -or ($value -match '^[0-9A-Fa-f:.]+$' -and $value.Contains(":"))) {
        return [System.Net.IPAddress]::TryParse($value, [ref]$parsed)
    }

    return $false
}


function Get-WinForgeProxySettings {
    <#
    O proxy do usuário, como o Windows o guarda (servidor manual e script de configuração automática). Text vem vazio
    quando não há nenhum, ou quando não deu para ler: na dúvida, nada a dizer. Um usuário e uma senha embutidos no
    endereço ("conta:senha@servidor") nunca vão para a tela: só o servidor.
    #>
    $server = ""
    $scriptUrl = ""

    try {
        $settings = Get-ItemProperty -LiteralPath "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -ErrorAction Stop

        if ([string](Get-WinForgeJsonValue -Object $settings -Name "ProxyEnable" -Default 0) -eq "1") {
            $server = ([string](Get-WinForgeJsonValue -Object $settings -Name "ProxyServer" -Default "")).Trim()
        }

        $scriptUrl = ([string](Get-WinForgeJsonValue -Object $settings -Name "AutoConfigURL" -Default "")).Trim()
    }
    catch {
        $server = ""
        $scriptUrl = ""
    }

    # Usuário e senha embutidos ("conta:senha@servidor", e a senha pode ter "@", "/" ou ";"): fica só o que vem depois do
    # último "@". No script, o endereço volta sem a conta e sem a consulta ("?..."), que às vezes leva uma chave de acesso.
    if ($server.Contains("@")) { $server = $server.Substring($server.LastIndexOf("@") + 1) }

    if ($scriptUrl) {
        $uri = $null

        if ([System.Uri]::TryCreate($scriptUrl, [System.UriKind]::Absolute, [ref]$uri)) {
            $scriptUrl = $uri.GetComponents([System.UriComponents]::SchemeAndServer -bor [System.UriComponents]::Path, [System.UriFormat]::Unescaped)
        }
        else {
            $scheme = $(if ($scriptUrl -match '^([A-Za-z][A-Za-z0-9+.-]*://)') { $Matches[1] } else { "" })
            if ($scriptUrl.Contains("@")) { $scriptUrl = $scheme + $scriptUrl.Substring($scriptUrl.LastIndexOf("@") + 1) }
            $scriptUrl = ($scriptUrl -split '\?')[0]
        }
    }
    $serverText = $(if ($server.Length -gt 60) { $server.Substring(0, 57) + "..." } else { $server })
    $scriptText = $(if ($scriptUrl.Length -gt 60) { $scriptUrl.Substring(0, 57) + "..." } else { $scriptUrl })
    $parts = @()
    if ($server) { $parts += "$serverText (manual)" }
    if ($scriptUrl) { $parts += "script de configuração ($scriptText)" }

    return [PSCustomObject]@{
        Server    = $server
        ScriptUrl = $scriptUrl
        Text      = ($parts -join " e ")
    }
}


function Get-WinForgePingVerdict {
    <#
    Conclusão do teste de conectividade. Results: objetos com Host e Loss (perda em %), e Resolved (opcional: o DNS do PC
    resolve o nome, mesmo que ele não responda ao ping). Separa os casos que pedem ações diferentes: nada responde (sem
    internet), os IPs respondem mas os nomes não resolvem (DNS), a conexão perde dados (instável: dois ou mais alvos com
    perda, ou um com perda de 50% ou mais) e tudo responde. Um alvo que não responde nada enquanto os outros respondem é só
    um servidor que ignora o ping, não um problema; nomes que resolvem mas não respondem ao ping também não.
    Devolve Level (Warning ou Success, para a última linha da tela), Message, Kind (Warning ou Ok), Detail (a faixa no
    console e no histórico) e, para a janela, Headline e Note (o título e a frase da faixa) e Next e NextLabel (o botão do
    que resolve: o reparo, quando ele resolve; nenhum quando o problema está fora do PC).
    #>
    param (
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Results
    )

    $answered = @($Results | Where-Object { [int]$_.Loss -lt 100 })
    $byAddress = @($Results | Where-Object { Test-WinForgeIpAddressText -Text ([string]$_.Host) })
    $byName = @($Results | Where-Object { -not (Test-WinForgeIpAddressText -Text ([string]$_.Host)) })
    $addressAnswered = @($byAddress | Where-Object { [int]$_.Loss -lt 100 }).Count
    $nameAnswered = @($byName | Where-Object { [int]$_.Loss -lt 100 }).Count
    $nameResolved = @($byName | Where-Object { $_.PSObject.Properties.Name -contains "Resolved" -and $_.Resolved }).Count
    $lossy = @($answered | Where-Object { [int]$_.Loss -gt 0 })
    $heavy = @($lossy | Where-Object { [int]$_.Loss -ge 50 })

    $verdict = {
        param ($Kind, $Message, $Detail, $Headline, $Note, $Next = "", $NextLabel = "")
        [PSCustomObject]@{
            Level = $(if ($Kind -eq "Ok") { "Success" } else { "Warning" }); Message = $Message; Kind = $Kind; Detail = $Detail
            Headline = $Headline; Note = $Note; Next = $Next; NextLabel = $NextLabel
        }
    }

    if ($answered.Count -eq 0) {
        return (& $verdict "Warning" "Nada respondeu: o PC está sem internet. Confira o Wi-Fi, o cabo e o roteador; se continuar, use Rede > Reparar rede e DNS." "nada respondeu; o PC está sem internet" `
                "Sem internet" "Nada respondeu. Confira o Wi-Fi, o cabo e o roteador; se estiver tudo ligado, repare a rede." "network.repair" "Reparar a rede")
    }

    if ($addressAnswered -gt 0 -and $byName.Count -gt 0 -and $nameAnswered -eq 0 -and $nameResolved -eq 0) {
        return (& $verdict "Warning" "A internet responde, mas os sites não abrem pelo nome: o problema é o DNS. Use Rede > Reparar rede e DNS ou Rede > Trocar o servidor DNS." "os sites não abrem pelo nome (problema de DNS)" `
                "Os sites não abrem pelo nome" "A internet responde, mas o DNS não. Reparar a rede costuma resolver; se não resolver, troque o servidor DNS." "network.repair" "Reparar a rede")
    }

    if ($lossy.Count -ge 2 -or $heavy.Count -gt 0) {
        return (& $verdict "Warning" "A conexão está instável, com perda de dados: aproxime o PC do roteador ou use cabo; se continuar, fale com a operadora." "a conexão está instável, com perda de dados" `
                "Conexão instável" "Há perda de dados: aproxime o PC do roteador ou use cabo; se continuar, fale com a operadora.")
    }

    if ($answered.Count -lt @($Results).Count) {
        return (& $verdict "Ok" "A internet está funcionando; alguns endereços não responderam, mas há servidores que ignoram o ping." "a internet está funcionando; alguns endereços ignoram o ping" `
                "A internet está funcionando" "Alguns endereços não responderam, mas há servidores que ignoram o ping.")
    }

    if ($lossy.Count -gt 0) {
        return (& $verdict "Ok" "A internet está respondendo bem; um dos testes perdeu um pouco de dados, o que é normal." "a internet está respondendo bem" `
                "A internet está funcionando" "Um dos testes perdeu um pouco de dados, o que é normal.")
    }

    return (& $verdict "Ok" "A internet está respondendo bem e sem perdas." "a internet está respondendo bem e sem perdas" "A internet está funcionando" "Respondeu bem, sem perda de dados.")
}


function Format-WinForgePingLine {
    # A linha de um alvo no resumo: "OK · média 12 ms (mín. 10, máx. 15)", "Instável · 25% de perda · média 30 ms" ou
    # "Sem resposta".
    param ([Parameter(Mandatory)]$Stats)

    $status = Get-WinForgePingStatusText -LossPercent ([int]$Stats.Loss)

    if ([int]$Stats.Loss -ge 100) { return $status }

    # Sem o tempo nas respostas ("-"), só a situação e a perda.
    $times = $(if ($Stats.Average -is [string]) { "" } else { "média $(Format-WinForgeNumber -Value $Stats.Average -Decimals 0) ms (mín. $(Format-WinForgeNumber -Value $Stats.Minimum -Decimals 0), máx. $(Format-WinForgeNumber -Value $Stats.Maximum -Decimals 0))" })
    if (-not $times) { return $(if ([int]$Stats.Loss -gt 0) { "$status · $($Stats.Loss)% de perda" } else { $status }) }

    if ([int]$Stats.Loss -gt 0) { return "$status · $($Stats.Loss)% de perda · $times" }

    return "$status · $times"
}


function Test-WinForgePing {
    Enter-WinForgeAction -Title "Testar conectividade (ping)"

    $final = New-WinForgeResult -Kind Failed -Detail "o teste não devolveu resultado"
    $targets = @(
        [PSCustomObject]@{ Name = "Cloudflare DNS"; Host = "1.1.1.1" },
        [PSCustomObject]@{ Name = "Google DNS"; Host = "8.8.8.8" },
        [PSCustomObject]@{ Name = "Quad9 DNS"; Host = "9.9.9.9" },
        [PSCustomObject]@{ Name = "Microsoft"; Host = "www.microsoft.com" },
        [PSCustomObject]@{ Name = "Google"; Host = "www.google.com" }
    )

    try {
        # Sem nenhuma rede (Wi-Fi desligado, cabo solto, modo avião), os cinco testes só confirmariam o óbvio, e o reparo, que a
        # faixa de "sem internet" oferece, não liga o Wi-Fi nem o cabo.
        if ($false -eq (Test-WinForgeNetworkConnected)) {
            Write-WinForgeStatus -Type Warning -Message "O PC não está ligado a nenhuma rede: ligue o Wi-Fi ou conecte o cabo (e confira o modo avião)."
            $final = Set-WinForgeResultView -Result (New-WinForgeResult -Kind Warning -Detail "o PC não está ligado a nenhuma rede") `
                -Headline "Nenhuma rede conectada" -Note "Ligue o Wi-Fi ou conecte o cabo; confira também o modo avião." -Next "NetworkSettings" -NextLabel "Abrir as configurações de rede"
            Exit-WinForgeAction -Result $final
            return
        }

        $results = @()
        $index = 0

        try {
            foreach ($target in $targets) {
                # O andamento vai para a barra de progresso: uma linha por alvo ficaria no resumo depois do fim.
                Write-Progress -Activity "Testando a conectividade" -Status "$($index + 1) de $($targets.Count): $($target.Name) ($($target.Host))" -PercentComplete ([int]($index * 100 / $targets.Count))
                $index++

                try {
                    $stats = Get-WinForgePingStats -ComputerName $target.Host -Count 4
                }
                catch {
                    $stats = [PSCustomObject]@{ Received = 0; Sent = 4; Loss = 100; Average = "-"; Minimum = "-"; Maximum = "-" }
                }

                $results += [PSCustomObject]@{ Name = $target.Name; Host = $target.Host; Loss = $stats.Loss; Resolved = $false; Stats = $stats }
            }
        }
        finally {
            Write-Progress -Activity "Testando a conectividade" -Completed
        }

        Write-WinForgeSection -Title "Resultado"

        # A cor de cada linha diz o que ela significa: vermelho sem resposta, amarelo com perda, verde sem perda.
        foreach ($row in $results) {
            $loss = [int]$row.Stats.Loss
            $level = $(if ($loss -ge 100) { "Bad" } elseif ($loss -gt 0) { "Warn" } else { "Ok" })
            Write-WinForgeKeyValue -Label "$($row.Name) ($($row.Host))" -Value (Format-WinForgePingLine -Stats $row.Stats) -LabelWidth 29 -Level $level
        }

        Write-Host ""

        # Um nome que não respondeu ao ping pode ser um ping bloqueado ou um DNS quebrado: só vale perguntar ao DNS quando algum
        # IP respondeu (sem nenhum, a conclusão é "nada responde" de qualquer jeito).
        if (@($results | Where-Object { (Test-WinForgeIpAddressText -Text $_.Host) -and [int]$_.Loss -lt 100 }).Count -gt 0) {
            foreach ($row in @($results | Where-Object { -not (Test-WinForgeIpAddressText -Text $_.Host) -and [int]$_.Loss -ge 100 })) {
                $row.Resolved = [bool](Test-WinForgeDnsResolution -Name $row.Host)
            }
        }

        # A conclusão é a última linha da tela; a faixa diz o mesmo em poucas palavras. O teste rodou até o fim, então um
        # problema encontrado (sem internet, DNS, conexão instável) é uma ressalva, não um "não foi concluído".
        $verdict = Get-WinForgePingVerdict -Results $results
        Write-WinForgeStatus -Type $verdict.Level -Message $verdict.Message
        $final = Set-WinForgeResultView -Result (New-WinForgeResult -Kind $verdict.Kind -Detail $verdict.Detail) -Headline $verdict.Headline -Note $verdict.Note `
            -Next $verdict.Next -NextLabel $verdict.NextLabel
    }
    catch {
        Write-WinForgeStatus -Type Error -Message "Ocorreu um erro no teste de ping: $($_.Exception.Message)"
        $final = New-WinForgeResult -Kind Failed -Detail $_.Exception.Message
    }

    Exit-WinForgeAction -Result $final
}


# ---------------------------------------------------------------------------
# Reparo de rede e DNS
# ---------------------------------------------------------------------------

function Get-WinForgeStaticIpConfiguration {
    <#
    Há configuração de IP feita à mão em algum adaptador? O "ipconfig /release" e o "netsh int ip reset" apagam endereços
    fixos de TODOS os adaptadores, então todos contam: com ou sem gateway (uma segunda placa numa rede interna não tem),
    ligados ou não, IPv4 e IPv6. Um adaptador conta como fixo quando tem um endereço posto à mão (PrefixOrigin Manual,
    qualquer família) ou o DHCP do IPv4 desligado. O loopback fica de fora (o Windows o configura assim). Devolve
    Static (há configuração fixa, ou não deu para saber), Unknown (a consulta falhou) e Interfaces (os nomes).
    O IPv6 não entra pelo DHCP desligado: ele se configura sozinho pelo roteador mesmo sem DHCPv6.
    Os filtros ficam aqui, e não nos parâmetros dos cmdlets: um filtro que não acha nada (nenhum endereço manual) vira
    erro de "objeto não encontrado", e um PC só com DHCP pareceria um PC que não pôde ser consultado.
    #>
    $names = New-Object System.Collections.ArrayList

    try {
        foreach ($address in @(Get-NetIPAddress -ErrorAction Stop)) {
            if ($null -eq $address -or [string]$address.PrefixOrigin -ne "Manual") { continue }
            $alias = [string]$address.InterfaceAlias
            if ($alias -like "Loopback*" -or [string]$address.InterfaceIndex -eq "1") { continue }
            if (-not $names.Contains($alias)) { [void]$names.Add($alias) }
        }

        foreach ($interface in @(Get-NetIPInterface -ErrorAction Stop)) {
            if ($null -eq $interface -or [string]$interface.AddressFamily -ne "IPv4" -or [string]$interface.Dhcp -ne "Disabled") { continue }
            $alias = [string]$interface.InterfaceAlias
            if ($alias -like "Loopback*" -or [string]$interface.InterfaceIndex -eq "1") { continue }
            if (-not $names.Contains($alias)) { [void]$names.Add($alias) }
        }
    }
    catch {
        # Sem saber, vale o lado seguro: o reparo deixa de fora o que apagaria uma configuração fixa.
        return [PSCustomObject]@{ Static = $true; Unknown = $true; Interfaces = @() }
    }

    return [PSCustomObject]@{ Static = ($names.Count -gt 0); Unknown = $false; Interfaces = @($names) }
}


function Test-WinForgeStaticIpConfigured {
    # Verdadeiro se algum adaptador tem IP fixo, ou se não deu para saber (veja Get-WinForgeStaticIpConfiguration).
    return [bool](Get-WinForgeStaticIpConfiguration).Static
}


function Get-WinForgeManualDnsAdapters {
    <#
    Os adaptadores (Ethernet e Wi-Fi ativos, como em Trocar o servidor DNS) com DNS posto à mão, mesmo com o DHCP ligado:
    um Pi-hole, um DNS de filtro para a família, o da empresa ou o que o próprio WinForge gravou. O "netsh int ip reset"
    refaz as chaves do TCP/IP em que esses servidores ficam, e eles se perderiam. Devolve Alias e Unknown (o DNS não pôde
    ser lido: conta junto, pelo lado seguro).
    #>
    return @(
        Get-WinForgeDnsAdapters | Where-Object { $null -ne $_ -and [string]$_.Mode -in @("Static", "Unknown") } | ForEach-Object {
            [PSCustomObject]@{ Alias = [string]$_.Alias; Unknown = ([string]$_.Mode -eq "Unknown") }
        }
    )
}


function Invoke-WinForgeNetworkDnsOnly {
    # O reparo de manutenção com a conexão em uso (Get-WinForgeNetworkHoldReason): só limpa o DNS, que não corta nada, e
    # diz por que o resto ficou de fora. Devolve o WinForge.Result da etapa.
    param (
        [string]$Title = "Reparar rede e DNS",
        [string]$Reason
    )

    try {
        $dns = Invoke-WinForgeNetworkCommand -Title "Limpar cache DNS" -FilePath "ipconfig.exe" -Arguments @("/flushdns")
    }
    finally {
        Write-Progress -Activity "Reparando a rede" -Completed
    }

    if ($dns.Kind -eq "Failed") {
        Write-WinForgeStatus -Type Warning -Message "O DNS não foi limpo; o resto do reparo ficou de fora porque $Reason."
        return (New-WinForgeResult -Kind Warning -Detail "o DNS não foi limpo ($Reason)" -Title $Title)
    }

    Write-WinForgeStatus -Type Success -Message "DNS limpo. O resto do reparo ficou de fora porque $Reason."
    return (New-WinForgeResult -Kind Ok -Detail "só o DNS foi limpo: $Reason" -Title $Title)
}


function Get-WinForgeNetworkHoldReason {
    <#
    O motivo para o reparo de manutenção não derrubar a conexão: o PC usado pela Área de Trabalho Remota ou uma VPN
    ligada (as do Windows, por Get-VpnConnection, e as de programas, pelo adaptador de rede deles: OpenVPN, WireGuard,
    AnyConnect, GlobalProtect, FortiClient e outras). "" quando nada impede. Sem como ler, não impede.
    #>
    if ([string]$env:SESSIONNAME -like "RDP-*") { return "o PC está sendo usado pela Área de Trabalho Remota" }

    if (Get-Command Get-VpnConnection -ErrorAction SilentlyContinue) {
        foreach ($scope in @($false, $true)) {
            try {
                $connections = $(if ($scope) { @(Get-VpnConnection -AllUserConnection -ErrorAction Stop) } else { @(Get-VpnConnection -ErrorAction Stop) })
                if (@($connections | Where-Object { [string]$_.ConnectionStatus -eq "Connected" }).Count -gt 0) { return "há uma VPN ligada" }
            }
            catch {
                continue
            }
        }
    }

    if (Get-Command Get-NetAdapter -ErrorAction SilentlyContinue) {
        try {
            $pattern = '(?i)TAP-Windows|Wintun|WireGuard|AnyConnect|OpenVPN|Fortinet|FortiClient|PANGP|GlobalProtect|Juniper|Pulse Secure|Ivanti|SonicWall|Check Point|Zscaler|NordLynx|ProtonVPN|Tailscale|ZeroTier|Hamachi|Cloudflare WARP|Cisco Secure Client'
            $vpn = @(Get-NetAdapter -ErrorAction Stop | Where-Object { [string]$_.Status -eq "Up" -and ([string]$_.InterfaceDescription -match $pattern -or [string]$_.Name -match $pattern) })
            if ($vpn.Count -gt 0) { return "há uma VPN ligada" }
        }
        catch {
            return ""
        }
    }

    return ""
}


function Get-WinForgeNetworkRepairCommands {
    param (
        [switch]$HasStaticIp,

        # DNS posto à mão em algum adaptador (Get-WinForgeManualDnsAdapters): o reset de TCP/IP fica de fora.
        [switch]$HasManualDns
    )

    # A ordem importa: o IP é liberado e renovado primeiro, a limpeza de DNS vem depois (já com o IP novo) e os
    # resets de Winsock/TCP-IP ficam por último porque só terminam de valer após reiniciar.
    # Com IP estático, release/renew e o reset de TCP/IP removeriam a configuração manual; com DNS posto à mão, o reset de
    # TCP/IP apagaria os servidores (o release/renew não mexe neles).
    $commands = @()

    if (-not $HasStaticIp) {
        $commands += [PSCustomObject]@{ Title = "Liberar endereço IP"; FilePath = "ipconfig.exe"; Arguments = @("/release"); NeedsRestart = $false }
        $commands += [PSCustomObject]@{ Title = "Renovar endereço IP"; FilePath = "ipconfig.exe"; Arguments = @("/renew"); NeedsRestart = $false }
    }

    $commands += [PSCustomObject]@{ Title = "Limpar cache DNS"; FilePath = "ipconfig.exe"; Arguments = @("/flushdns"); NeedsRestart = $false }
    $commands += [PSCustomObject]@{ Title = "Redefinir Winsock"; FilePath = "netsh.exe"; Arguments = @("winsock", "reset"); NeedsRestart = $true }

    if (-not $HasStaticIp -and -not $HasManualDns) {
        $commands += [PSCustomObject]@{ Title = "Redefinir TCP/IP"; FilePath = "netsh.exe"; Arguments = @("int", "ip", "reset"); NeedsRestart = $true }
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

    # O andamento vai para a barra de progresso; o resumo fica com uma linha por comando, a do resultado.
    Write-Progress -Activity "Reparando a rede" -Status $Title

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
        Write-WinForgeStatus -Type Warning -Message "Não deu certo: $Title (código $(Format-WinForgeExitCode -ExitCode $exitCode))."
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
    # -Embedded (dentro de um fluxo): não pergunta nada e só repara quando a rede não funciona. -Force (o Otimizar), junto
    # com -Embedded: repara mesmo com a rede funcionando, como manutenção; sem nenhuma rede conectada, continua de fora.
    param (
        [switch]$Embedded,
        [switch]$PassThru,
        [switch]$Force
    )

    $title = "Reparar rede e DNS"

    Enter-WinForgeAction -Title $title -Embedded:$Embedded

    if (-not (Test-WinForgeElevation -Reason "O reparo de rede exige privilégios de Administrador.")) {
        $early = New-WinForgeResult -Kind Failed -Detail "sem privilégios de Administrador" -Title $title
        if ($PassThru) { $early }
        Exit-WinForgeAction -Embedded:$Embedded -Result $early
        return
    }

    # IP fixo em algum adaptador (com os nomes, para o aviso).
    $staticIp = Get-WinForgeStaticIpConfiguration
    $hasStaticIp = [bool]$staticIp.Static
    # DNS posto à mão (com os nomes, para o aviso): o reset de TCP/IP o apagaria.
    $manualDns = @(Get-WinForgeManualDnsAdapters)
    $hasManualDns = ($manualDns.Count -gt 0)
    $final = New-WinForgeResult -Kind Ok -Title $title

    # O reparo refaz as configurações de rede do Windows, o que costuma resolver internet que não abre sites; o que ele faz
    # aparece em "O que o reparo faz", antes da pergunta.
    Write-WinForgeSection -Title "Diagnóstico rápido"
    Write-Progress -Activity $title -Status "testando a conexão"

    try { $connectivity = Test-WinForgeInternetConnectivity } finally { Write-Progress -Activity $title -Completed }
    Write-WinForgeKeyValue -Label "Acesso por IP (sem DNS)" -Value (Get-WinForgeIpReachText -Connectivity $connectivity) -LabelWidth 26
    Write-WinForgeKeyValue -Label "Resolução de DNS" -Value $(if ($connectivity.DnsOk) { "Funciona" } else { "Falhou" }) -LabelWidth 26

    # Um proxy configurado (por um programa ou pela empresa) explica a internet que só funciona em alguns programas, e
    # nenhum dos comandos do reparo o muda.
    $proxy = Get-WinForgeProxySettings
    if ($proxy.Text) { Write-WinForgeKeyValue -Label "Proxy" -Value $proxy.Text -LabelWidth 26 }

    # Quando os testes diretos falham, o que o Windows diz da conexão também conta (numa rede com proxy, o acesso direto
    # a 1.1.1.1 e 8.8.8.8 é bloqueado, mas a internet funciona).
    $windowsInternet = $null

    if (-not $connectivity.Ok) {
        $windowsInternet = Get-WinForgeWindowsInternetStatus

        if ($null -ne $windowsInternet) {
            Write-WinForgeKeyValue -Label "Conexão segundo o Windows" -Value $(if ($windowsInternet) { "Com acesso à internet" } else { "Sem acesso à internet" }) -LabelWidth 26
        }
    }

    # Dentro de um fluxo o reparo só roda se algo estiver quebrado, salvo com -Force (o Otimizar).
    if ($Embedded -and -not $Force -and $connectivity.Ok) {
        Write-WinForgeStatus -Type Success -Message "A conexão e o DNS funcionam; o reparo de rede não é necessário."

        $early = New-WinForgeResult -Kind Skipped -Detail "rede funcionando" -Title $title
        if ($PassThru) { $early }
        Exit-WinForgeAction -Embedded:$Embedded -Result $early
        return
    }

    # Sem ninguém olhando, o reparo (que derruba a conexão e redefine o Winsock) só roda quando nada indica que a rede
    # funciona: nomes que resolvem ou o Windows dizendo que há internet bastam para não mexer.
    if ($Embedded -and -not $Force -and ($connectivity.DnsOk -or $windowsInternet -eq $true)) {
        $evidence = $(if ($windowsInternet -eq $true) { "o Windows informa acesso à internet" } else { "os nomes de sites são resolvidos" })
        # Os servidores de teste não responderam direto: comum em redes com proxy ou firewall.
        Write-WinForgeStatus -Type Success -Message "A rede funciona ($evidence, comum em redes com proxy); o reparo não foi necessário."
        Write-WinForgeStatus -Type Info -Message "Se a internet estiver com problema, use Rede > Reparar rede e DNS."

        $early = New-WinForgeResult -Kind Skipped -Detail "a rede funciona ($evidence)" -Title $title
        if ($PassThru) { $early }
        Exit-WinForgeAction -Embedded:$Embedded -Result $early
        return
    }

    # Sem nenhuma rede conectada, não há o que reparar: os resets não ligam o Wi-Fi nem o cabo, podem atrapalhar uma VPN
    # e só pediriam um reinício à toa.
    if ($Embedded -and $false -eq (Test-WinForgeNetworkConnected)) {
        Write-WinForgeStatus -Type Info -Message "O PC não está ligado a nenhuma rede; o reparo de rede não foi executado."

        $early = New-WinForgeResult -Kind Skipped -Detail "nenhuma rede conectada" -Title $title
        if ($PassThru) { $early }
        Exit-WinForgeAction -Embedded:$Embedded -Result $early
        return
    }

    # Como manutenção (o Otimizar, com a rede funcionando), o reparo não derruba uma conexão que alguém está usando: com
    # uma VPN ligada ou o PC usado pela Área de Trabalho Remota, liberar o IP derrubaria a VPN ou a sessão no meio da parte
    # automática, e o reset do Winsock pode desfazer a VPN. Só o DNS é limpo, o que não corta nada.
    $hold = $(if ($Embedded -and $Force -and $connectivity.Ok) { Get-WinForgeNetworkHoldReason } else { "" })

    if (-not [string]::IsNullOrWhiteSpace($hold)) {
        $early = Invoke-WinForgeNetworkDnsOnly -Title $title -Reason $hold

        if ($PassThru) { $early }
        Exit-WinForgeAction -Embedded:$Embedded -Result $early
        return
    }

    # O que o reparo faz, em palavras; os comandos em si ficam nos detalhes técnicos.
    Write-WinForgeSection -Title "O que o reparo faz"
    $repairCommands = @(Get-WinForgeNetworkRepairCommands -HasStaticIp:$hasStaticIp -HasManualDns:$hasManualDns)

    if (@($repairCommands | Where-Object { $_.Title -eq "Renovar endereço IP" }).Count -gt 0) {
        Write-WinForgeStatus -Type Info -Notice -Message "Pede um endereço novo ao roteador."
    }

    Write-WinForgeStatus -Type Info -Notice -Message "Apaga a memória de endereços de sites (DNS)."
    $resets = $(if (@($repairCommands | Where-Object { $_.Title -eq "Redefinir TCP/IP" }).Count -gt 0) { "Winsock e TCP/IP" } else { "Winsock" })
    Write-WinForgeStatus -Type Info -Notice -Message "Refaz as configurações de rede do Windows ($resets); pede reiniciar."

    foreach ($command in $repairCommands) {
        Write-WinForgeCommand -Command "$($command.FilePath -replace '\.exe$', '') $($command.Arguments -join ' ')"
    }

    Write-Host ""

    if ($staticIp.Unknown) {
        Write-WinForgeStatus -Type Warning -Notice -Message "Não foi possível conferir se algum adaptador usa IP fixo: liberar/renovar IP e redefinir TCP/IP foram removidos para não apagar uma configuração manual."
    }
    elseif ($hasStaticIp) {
        Write-WinForgeStatus -Type Warning -Notice -Message "IP estático detectado ($(Join-WinForgeList -Items @($staticIp.Interfaces))): liberar/renovar IP e redefinir TCP/IP foram removidos para não apagar sua configuração."
    }

    # Com IP estático, o reset de TCP/IP já saiu, e o aviso acima já diz isso.
    if ($hasManualDns -and -not $hasStaticIp) {
        $fixed = @($manualDns | Where-Object { -not $_.Unknown } | ForEach-Object { $_.Alias })
        $unread = @($manualDns | Where-Object { $_.Unknown } | ForEach-Object { $_.Alias })
        $where = @()
        if ($fixed.Count -gt 0) { $where += "DNS fixo em $(Join-WinForgeList -Items $fixed)" }
        if ($unread.Count -gt 0) { $where += "DNS que não pôde ser lido em $(Join-WinForgeList -Items $unread)" }
        Write-WinForgeStatus -Type Warning -Notice -Message "$($where -join '; '): redefinir TCP/IP foi removido para não apagar esses servidores DNS."
    }

    Write-WinForgeStatus -Type Warning -Notice -Message "A conexão pode cair por alguns instantes. O reset do Winsock pode afetar VPN e alguns antivírus."

    # No Otimizar (-Embedded -Force), o reparo roda mesmo com a internet funcionando, como manutenção da rede: sem
    # pergunta, não há o que avisar.
    if ($connectivity.Ok) {
        if (-not ($Embedded -and $Force)) {
            Write-WinForgeStatus -Type Info -Message "A internet parece funcionar normalmente: só continue se tiver um problema de rede."
        }
    }
    elseif ($false -eq (Test-WinForgeNetworkConnected)) {
        # Sem nenhuma rede, o problema é o Wi-Fi desligado, o cabo solto ou o modo avião, e nenhum comando do reparo liga isso.
        Write-WinForgeStatus -Type Warning -Notice -Message "O PC não está ligado a nenhuma rede: ligue o Wi-Fi ou conecte o cabo; o reparo não faz isso."
    }
    else {
        Write-WinForgeStatus -Type Info -Notice -Message "A internet não está funcionando: o reparo é indicado."
    }

    if ($proxy.Text) {
        # Um proxy que não é da empresa, com a internet funcionando só em alguns programas, pode ter sido posto por um programa.
        Write-WinForgeStatus -Type Info -Message "Há um proxy configurado, que o reparo não muda: confira em Configurações, Rede e Internet, Proxy."
    }

    Write-Host ""

    # O reparo derruba a conexão e redefine o Winsock (o que pode afetar VPN e antivírus): a resposta padrão é sempre Não,
    # e o aviso acima diz quando ele é indicado. Na Manutenção, o usuário já confirmou.
    if (-not $Embedded -and -not (Confirm-WinForgeAction "Reparar a rede agora?" -DefaultKey N)) {
        Write-Host ""
        Write-WinForgeStatus -Type Warning -Message "Operação cancelada."

        $early = New-WinForgeResult -Kind Skipped -Detail "cancelado pelo usuário" -Title $title
        if ($PassThru) { $early }
        Exit-WinForgeAction -Embedded:$Embedded -Result $early
        return
    }

    try {
        $steps = @()
        $needsRestart = $false

        try {
            foreach ($command in (Get-WinForgeNetworkRepairCommands -HasStaticIp:$hasStaticIp -HasManualDns:$hasManualDns)) {
                $step = Invoke-WinForgeNetworkCommand -Title $command.Title -FilePath $command.FilePath -Arguments $command.Arguments
                $steps += $step

                # Só os resets de Winsock e TCP/IP pedem reinício, e só se tiverem funcionado.
                if ($command.NeedsRestart -and $step.Kind -ne "Failed") {
                    $needsRestart = $true
                }
            }
        }
        finally {
            Write-Progress -Activity "Reparando a rede" -Completed
        }

        $failedSteps = @($steps | Where-Object { $_.Kind -eq "Failed" })
        $restart = @{ RebootRequired = $needsRestart }

        if ($steps.Count -gt 0 -and $failedSteps.Count -eq $steps.Count) {
            # Nada foi executado com sucesso: conferir a conexão só faria esperar, e não há o que reiniciar.
            $final = New-WinForgeResult -Kind Failed -Detail "nenhum dos comandos funcionou" -Title $title
            Write-Host ""
            Write-WinForgeStatus -Type Error -Message "Nenhum comando do reparo funcionou."
        }
        else {
            Write-Progress -Activity $title -Status "conferindo se a conexão voltou (pode levar até um minuto)"

            try { $after = Wait-WinForgeInternet } finally { Write-Progress -Activity $title -Completed }

            Write-WinForgeSection -Title "Depois do reparo"
            Write-WinForgeKeyValue -Label "Acesso por IP (sem DNS)" -Value (Get-WinForgeIpReachText -Connectivity $after) -LabelWidth 26
            Write-WinForgeKeyValue -Label "Resolução de DNS" -Value $(if ($after.DnsOk) { "Funciona" } else { "Falhou" }) -LabelWidth 26
            Write-Host ""

            if ($failedSteps.Count -gt 0) {
                $failedText = $(if ($failedSteps.Count -eq 1) { "1 comando falhou" } else { "$($failedSteps.Count) comandos falharam" })
                $final = New-WinForgeResult -Kind Warning -Detail $failedText -Title $title -Data $restart
                Write-WinForgeStatus -Type Warning -Message "Reparo concluído com alertas: $failedText."
            }
            elseif (-not $after.Ok) {
                $final = New-WinForgeResult -Kind Warning -Detail "a conexão ainda não voltou" -Title $title -Data $restart
                Write-WinForgeStatus -Type Warning -Message "Os comandos foram executados, mas a conexão ainda não voltou.$(if ($needsRestart) { ' Depois de reiniciar, teste de novo.' } else { ' Reinicie o PC e teste de novo.' })"

                # Na janela, o que fazer agora: sem nenhuma rede, ligar o Wi-Fi ou o cabo (o botão abre as configurações de
                # rede); com a rede, reiniciar e testar de novo (o pedido de reinício já está na frase).
                if ($false -eq (Test-WinForgeNetworkConnected)) {
                    [void](Set-WinForgeResultView -Result $final -Headline "Nenhuma rede conectada" -Note "Ligue o Wi-Fi ou conecte o cabo; confira também o modo avião." `
                            -Next "NetworkSettings" -NextLabel "Abrir as configurações de rede")
                }
                else {
                    [void](Set-WinForgeResultView -Result $final -Headline "A conexão ainda não voltou" -Note "Reinicie o PC e teste de novo; se continuar, confira o roteador ou fale com a operadora.")
                }
            }
            else {
                $final = New-WinForgeResult -Kind Ok -Title $title -Data $restart
                Write-WinForgeStatus -Type Success -Message "Reparo concluído; a conexão está funcionando."
                [void](Set-WinForgeResultView -Result $final -Headline "Rede reparada" -Note "A conexão está funcionando.")
            }

            if ($needsRestart) {
                Write-WinForgeStatus -Type Info -Message "Reinicie o PC para o reparo terminar de valer."
            }
        }
    }
    catch {
        Write-Host ""
        Write-WinForgeStatus -Type Error -Message "Falha durante o reparo de rede: $($_.Exception.Message)"
        $final = New-WinForgeResult -Kind Failed -Detail $_.Exception.Message -Title $title
    }

    if ($PassThru) { $final }
    Exit-WinForgeAction -Embedded:$Embedded -Result $final
}


# ---------------------------------------------------------------------------
# Teste de velocidade
# ---------------------------------------------------------------------------

function Measure-WinForgeSpeedLatency {
    <#
    Latência até o servidor do teste, em ms: pedidos vazios na mesma conexão, e o primeiro só abre a conexão (resolver o
    nome, negociar o TLS) e não conta. De cada um sai o tempo que o próprio servidor gastou (cabeçalho Server-Timing do
    Cloudflare), como no teste dele: fica o tempo de ida e volta, o que pesa em jogos e chamadas de vídeo. Vale a mediana.
    Uma falha no meio encerra com as amostras que já havia; sem nenhuma, $null: a latência é um extra e nunca impede o
    download de seguir. Só o primeiro pedido, que abre a conexão, espera 10 s; os outros, 5 s.
    #>
    param (
        [Parameter(Mandatory)]$Client,
        [Parameter(Mandatory)][string]$BaseUrl,
        [int]$Samples = 3
    )

    $times = New-Object System.Collections.Generic.List[double]

    for ($i = 0; $i -le $Samples; $i++) {
        try {
            $watch = [System.Diagnostics.Stopwatch]::StartNew()
            $probe = $Client.GetAsync("${BaseUrl}?bytes=0", [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead)
            Wait-WinForgeTask -Task $probe -TimeoutSeconds $(if ($i -eq 0) { 10 } else { 5 })
            $watch.Stop()
            $answer = $probe.Result

            try {
                Assert-WinForgeSpeedResponse -Response $answer
                $serverMs = Get-WinForgeServerTimingMs -Response $answer
            }
            finally {
                $answer.Dispose()
            }

            if ($i -gt 0) { $times.Add([Math]::Max(0.0, $watch.Elapsed.TotalMilliseconds - $serverMs)) }
        }
        catch {
            break
        }
    }

    if ($times.Count -eq 0) { return $null }

    $sorted = @($times | Sort-Object)
    return [Math]::Round($sorted[[int][Math]::Floor($sorted.Count / 2)], 0)
}


function Get-WinForgeServerTimingMs {
    # O tempo que o servidor gastou com o pedido, em ms, do cabeçalho Server-Timing ("cfRequestDuration;dur=1.2"); 0 sem ele.
    param ([Parameter(Mandatory)]$Response)

    try {
        $values = $null

        if ($Response.Headers.TryGetValues("Server-Timing", [ref]$values)) {
            foreach ($value in @($values)) {
                $match = [regex]::Match([string]$value, 'cfRequestDuration;dur=([0-9]+(\.[0-9]+)?)')
                if ($match.Success) { return [double]::Parse($match.Groups[1].Value, [System.Globalization.CultureInfo]::InvariantCulture) }
            }
        }

        return 0
    }
    catch {
        return 0
    }
}


function Get-WinForgeSteadyMbps {
    <#
    A velocidade de um download depois do arranque da conexão, em Mbps. Toda conexão TCP começa devagar e acelera nos
    primeiros instantes; numa internet rápida, os 25 MB do teste chegam em menos de um segundo, e esse começo sozinho
    derrubava o resultado. O arranque acaba na primeira amostra com WarmupSeconds de transferência ou WarmupBytes recebidos;
    a velocidade é a do que veio depois. Quando o que veio depois é curto demais (menos de 0,1 s), ou nada veio, vale a conta
    inteira, como antes. Samples: objetos com Seconds (desde o início da transferência) e Bytes (total recebido até ali),
    em ordem.
    #>
    param (
        [AllowEmptyCollection()][object[]]$Samples = @(),
        [double]$WarmupSeconds = 0.25,
        [int64]$WarmupBytes = 5000000
    )

    $list = @($Samples | Where-Object { $null -ne $_ })
    if ($list.Count -eq 0) { return 0.0 }

    $last = $list[$list.Count - 1]
    $warm = @($list | Where-Object { [double]$_.Seconds -ge $WarmupSeconds -or [int64]$_.Bytes -ge $WarmupBytes }) | Select-Object -First 1

    if ($null -ne $warm -and ([double]$last.Seconds - [double]$warm.Seconds) -ge 0.1 -and [int64]$last.Bytes -gt [int64]$warm.Bytes) {
        return (Get-WinForgeMbps -Bytes ([int64]$last.Bytes - [int64]$warm.Bytes) -Seconds ([double]$last.Seconds - [double]$warm.Seconds))
    }

    return (Get-WinForgeMbps -Bytes ([int64]$last.Bytes) -Seconds ([double]$last.Seconds))
}


function Measure-WinForgeDownload {
    # Baixa dados do Cloudflare até o limite de bytes ou de tempo e devolve a velocidade em Mbps (a do trecho depois do
    # arranque da conexão: Get-WinForgeSteadyMbps). Bytes e Seconds são os do download inteiro.
    param (
        [int64]$MaxBytes = 25000000,
        [int]$MaxSeconds = 12,
        [string]$BaseUrl = "https://speed.cloudflare.com/__down"
    )

    $client = New-WinForgeSpeedHttpClient -TimeoutSeconds 30
    $response = $null
    $stream = $null

    try {
        $latency = Measure-WinForgeSpeedLatency -Client $client -BaseUrl $BaseUrl
        $request = $client.GetAsync("${BaseUrl}?bytes=$MaxBytes", [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead)
        Wait-WinForgeTask -Task $request -TimeoutSeconds 30
        $response = $request.Result
        Assert-WinForgeSpeedResponse -Response $response

        $streamTask = $response.Content.ReadAsStreamAsync()
        Wait-WinForgeTask -Task $streamTask -TimeoutSeconds 30
        $stream = $streamTask.Result

        # O relógio só corre a partir daqui: o tempo de resolver o nome, abrir a conexão e negociar o TLS não é velocidade da
        # internet, e numa conexão rápida (25 MB em um segundo) ele sozinho derrubava o resultado em um quinto ou mais.
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        # Blocos de até 256 KB: numa internet rápida, menos voltas no laço, que no PowerShell custam tempo.
        $buffer = New-Object byte[] 262144
        [int64]$total = 0
        $samples = New-Object System.Collections.Generic.List[object]

        while ($total -lt $MaxBytes -and $stopwatch.Elapsed.TotalSeconds -lt $MaxSeconds) {
            try {
                # Nunca além do limite de bytes, mesmo que o servidor mande mais do que o pedido.
                $read = $stream.ReadAsync($buffer, 0, [int][Math]::Min([int64]$buffer.Length, $MaxBytes - $total))
                Wait-WinForgeTask -Task $read -TimeoutSeconds 20
                $received = $read.Result
            }
            catch {
                # A conexão caiu no meio: o que já chegou vale como medição. Sem nenhum byte, é falha.
                if ($total -gt 0) { break }
                throw
            }

            if ($received -le 0) {
                break
            }

            $total += $received
            $samples.Add([PSCustomObject]@{ Seconds = $stopwatch.Elapsed.TotalSeconds; Bytes = $total })
        }

        $stopwatch.Stop()

        return [PSCustomObject]@{
            Bytes     = $total
            Seconds   = [Math]::Round($stopwatch.Elapsed.TotalSeconds, 2)
            Mbps      = Get-WinForgeSteadyMbps -Samples $samples.ToArray() -WarmupBytes ([Math]::Max([int64]1, [int64]($MaxBytes / 5)))
            LatencyMs = $latency
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
        [int]$MaxChunks = 12,
        [string]$Url = "https://speed.cloudflare.com/__up"
    )

    $client = New-WinForgeSpeedHttpClient -TimeoutSeconds 40

    try {
        $buffer = New-Object byte[] $ChunkBytes
        (New-Object System.Random).NextBytes($buffer)

        [int64]$total = 0
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

        for ($chunk = 0; $chunk -lt $MaxChunks -and $stopwatch.Elapsed.TotalSeconds -lt $MaxSeconds; $chunk++) {
            $content = [System.Net.Http.ByteArrayContent]::new($buffer)
            $response = $null

            try {
                $post = $client.PostAsync($Url, $content)
                Wait-WinForgeTask -Task $post -TimeoutSeconds 40
                $response = $post.Result
                Assert-WinForgeSpeedResponse -Response $response
                $total += $ChunkBytes
            }
            catch {
                # Um envio que falha depois de outros que deram certo encerra a medição com o que já foi enviado. Se o primeiro
                # já falha, o servidor não aceita o teste: é falha.
                if ($total -gt 0) { break }
                throw
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


function Format-WinForgeSpeedMbps {
    # "94 Mbps" a partir de 10, "8,5 Mbps" abaixo: casas decimais numa velocidade alta só atrapalham a leitura.
    param ([double]$Mbps)

    return "$(Format-WinForgeNumber -Value $Mbps -Decimals $(if ($Mbps -ge 10) { 0 } else { 1 })) Mbps"
}


function Get-WinForgeSpeedVerdict {
    <#
    O que a velocidade de download e a latência querem dizer no dia a dia. Devolve Lines: objetos com Type (Info ou
    Warning) e Message, na ordem da tela. A última linha sempre lembra que o teste com Wi-Fi mede menos que o contratado.
    #>
    param (
        [double]$DownloadMbps,
        $LatencyMs = $null
    )

    $lines = @()

    if ($DownloadMbps -lt 10) { $lines += [PSCustomObject]@{ Type = "Warning"; Message = "Internet lenta: vídeos em HD podem travar e downloads demoram." } }
    elseif ($DownloadMbps -lt 50) { $lines += [PSCustomObject]@{ Type = "Info"; Message = "Boa para vídeo em HD, aulas e chamadas de vídeo." } }
    elseif ($DownloadMbps -le 200) { $lines += [PSCustomObject]@{ Type = "Info"; Message = "Boa para vídeo em 4K e vários aparelhos ao mesmo tempo." } }
    else { $lines += [PSCustomObject]@{ Type = "Info"; Message = "Internet rápida." } }

    if ($null -ne $LatencyMs -and [double]$LatencyMs -gt 100) {
        $lines += [PSCustomObject]@{ Type = "Warning"; Message = "A latência está alta: jogos online e chamadas podem atrasar." }
    }

    $lines += [PSCustomObject]@{ Type = "Info"; Message = "Se você contratou mais que isso, repita o teste com cabo, perto do roteador; se continuar abaixo, fale com a operadora." }

    return [PSCustomObject]@{ Lines = @($lines) }
}


function Write-WinForgeSpeedVerdict {
    # Escreve as linhas de Get-WinForgeSpeedVerdict. São leitura do resultado, não o resultado: não mudam a faixa.
    param (
        [double]$DownloadMbps,
        $LatencyMs = $null
    )

    foreach ($line in (Get-WinForgeSpeedVerdict -DownloadMbps $DownloadMbps -LatencyMs $LatencyMs).Lines) {
        Write-WinForgeStatus -Type $line.Type -Notice -Message $line.Message
    }
}


function Test-WinForgeInternetSpeed {
    Enter-WinForgeAction -Title "Testar velocidade da internet"

    # Uma medida aproximada: não substitui o teste da operadora, mas mostra gargalos claros.
    Write-WinForgeStatus -Type Info -Message "Mede a latência e a velocidade até o servidor da Cloudflare mais próximo."

    # Numa conexão limitada (celular roteado, chip, rede marcada como limitada), os 35 MB saem da franquia: o padrão vira Não.
    $metered = Test-WinForgeMeteredConnection

    if ($metered) {
        Write-WinForgeStatus -Type Warning -Notice -Message "A conexão com a internet é limitada (plano de dados): o teste usa até cerca de 35 MB da sua franquia."
    }
    else {
        Write-WinForgeStatus -Type Info -Message "O teste usa até cerca de 35 MB de dados. Evite em conexões com franquia (4G/5G)."
    }

    Write-Host ""

    if (-not (Confirm-WinForgeAction "Iniciar o teste agora?" -DefaultKey $(if ($metered) { "N" } else { "S" }))) {
        Write-WinForgeStatus -Type Warning -Message "Operação cancelada."
        Exit-WinForgeAction -Result (New-WinForgeResult -Kind Skipped -Detail "cancelado pelo usuário")
        return
    }

    $final = New-WinForgeResult -Kind Ok

    try {
        Enable-WinForgeTls12
        Add-Type -AssemblyName System.Net.Http -ErrorAction SilentlyContinue

        $download = $null
        $upload = $null
        $downloadProblem = ""
        $uploadProblem = ""

        # Cada medição tem a sua falha: um upload recusado pelo servidor não pode jogar fora um download que deu certo. O
        # andamento fica na barra de progresso; na tela, só as falhas e o resultado.
        try {
            Write-Progress -Activity "Testando a velocidade" -Status "latência e download (até 15 s)" -PercentComplete 0

            try {
                $download = Measure-WinForgeDownload
            }
            catch {
                $downloadProblem = Get-WinForgeSpeedProblem -Exception $_.Exception
                Write-WinForgeStatus -Type Error -Message "O download falhou: $downloadProblem"
            }

            Write-Progress -Activity "Testando a velocidade" -Status "upload (até 8 s)" -PercentComplete 60

            try {
                $upload = Measure-WinForgeUpload
            }
            catch {
                $uploadProblem = Get-WinForgeSpeedProblem -Exception $_.Exception
                Write-WinForgeStatus -Type Error -Message "O upload falhou: $uploadProblem"
            }
        }
        finally {
            Write-Progress -Activity "Testando a velocidade" -Completed
        }

        if ($null -eq $download -and $null -eq $upload) {
            Write-WinForgeStatus -Type Info -Message "Verifique a conexão, o DNS, o firewall, a VPN ou um bloqueio do endereço de teste."
            $final = New-WinForgeResult -Kind Failed -Detail "não foi possível medir: $downloadProblem"
        }
        else {
            Write-WinForgeSection -Title "Resultado"

            $downloadText = "não foi possível medir"
            $uploadText = "não foi possível medir"
            $latency = $(if ($null -ne $download) { Get-WinForgeJsonValue -Object $download -Name "LatencyMs" -Default $null } else { $null })
            $latencyText = ""

            if ($null -ne $latency) {
                $latencyText = "$(Format-WinForgeNumber -Value $latency -Decimals 0) ms"
                Write-WinForgeKeyValue -Label "Latência" -Value $latencyText
            }

            # Vírgula decimal, como no resto do WinForge ("94 Mbps", "8,5 Mbps"). Quanto foi baixado e em quanto tempo fica
            # numa linha à parte, que a janela deixa só nos detalhes técnicos.
            if ($null -ne $download) {
                $downloadText = Format-WinForgeSpeedMbps -Mbps $download.Mbps
                Write-WinForgeKeyValue -Label "Download" -Value $downloadText
                Write-Host "      $(Format-WinForgeBytes -Bytes $download.Bytes) baixados em $(Format-WinForgeNumber -Value $download.Seconds -Decimals 2) s" -ForegroundColor DarkGray
            }
            else {
                Write-WinForgeKeyValue -Label "Download" -Value $downloadText
            }

            if ($null -ne $upload) {
                $uploadText = Format-WinForgeSpeedMbps -Mbps $upload.Mbps
                Write-WinForgeKeyValue -Label "Upload" -Value $uploadText
                Write-Host "      $(Format-WinForgeBytes -Bytes $upload.Bytes) enviados em $(Format-WinForgeNumber -Value $upload.Seconds -Decimals 2) s" -ForegroundColor DarkGray
            }
            else {
                Write-WinForgeKeyValue -Label "Upload" -Value $uploadText
            }

            # O que os números querem dizer, para quem não sabe se 40 Mbps é muito ou pouco.
            if ($null -ne $download -and $download.Mbps -gt 0) {
                Write-Host ""
                Write-WinForgeSpeedVerdict -DownloadMbps $download.Mbps -LatencyMs $latency
            }

            if ($null -eq $download) {
                $final = New-WinForgeResult -Kind Warning -Detail "o download falhou: $downloadProblem"
            }
            elseif ($null -eq $upload) {
                $final = New-WinForgeResult -Kind Warning -Detail "o upload falhou: $uploadProblem"
            }
            elseif ($download.Mbps -le 0 -or $upload.Mbps -le 0) {
                Write-Host ""
                Write-WinForgeStatus -Type Warning -Message "Uma das medições retornou zero. Repita o teste ou verifique a conexão."
                $final = New-WinForgeResult -Kind Warning -Detail "uma das medições retornou zero"
            }
            else {
                # Na ordem da tela: latência, download e upload.
                $final = New-WinForgeResult -Kind Ok -Detail "$(if ($latencyText) { "latência $latencyText, " })download $downloadText, upload $uploadText"

                # Na janela, o título traz o download; a frase, o upload, a latência e o que isso quer dizer (sem a dica de
                # repetir com cabo, que fica no resumo). Internet lenta ou latência alta deixam a faixa amarela.
                $reading = @((Get-WinForgeSpeedVerdict -DownloadMbps $download.Mbps -LatencyMs $latency).Lines)
                $meaning = @($reading | Select-Object -First ($reading.Count - 1))
                $slow = @($meaning | Where-Object { $_.Type -eq "Warning" }).Count -gt 0
                [void](Set-WinForgeResultView -Result $final -Headline "$downloadText de download" -Tone $(if ($slow) { "Warn" } else { "" }) `
                        -Note "Upload de $uploadText$(if ($latencyText) { " e latência de $latencyText" }). $(@($meaning | ForEach-Object { $_.Message }) -join ' ')")
            }
        }
    }
    catch {
        Write-Host ""
        Write-WinForgeStatus -Type Error -Message "O teste de velocidade falhou: $(Get-WinForgeSpeedProblem -Exception $_.Exception)"
        Write-WinForgeStatus -Type Info -Message "Verifique a conexão, o DNS, o firewall, a VPN ou um bloqueio do endereço de teste."
        $final = New-WinForgeResult -Kind Failed -Detail (Get-WinForgeSpeedProblem -Exception $_.Exception)
    }

    Exit-WinForgeAction -Result $final
}


# ---------------------------------------------------------------------------
# Informações de rede
# ---------------------------------------------------------------------------

function ConvertFrom-WinForgeWlanInterfaces {
    <#
    As interfaces Wi-Fi conectadas na saída de "netsh wlan show interfaces", em inglês ou em português. Cada linha é
    "Campo : valor" e uma interface começa no campo Name (Nome); o SSID só aparece quando ela está conectada. Os acentos
    podem chegar trocados (página de código do console): por isso "r.{1,3}dio" e os campos comparados pelo começo.
    #>
    param ([string[]]$Lines = @())

    $interfaces = New-Object System.Collections.Generic.List[object]
    $current = $null

    foreach ($line in $Lines) {
        $match = [regex]::Match([string]$line, '^\s+([^:]+?)\s*:\s*(.*)$')
        if (-not $match.Success) { continue }

        $key = $match.Groups[1].Value.Trim()
        $value = $match.Groups[2].Value.Trim()

        if ($key -in @("Name", "Nome")) {
            $current = [ordered]@{ Name = $value; Ssid = ""; Signal = $null; Radio = ""; Band = ""; Channel = "" }
            $interfaces.Add($current)
            continue
        }

        if ($null -eq $current) { continue }

        switch -Regex ($key) {
            '^SSID$' { $current.Ssid = $value }
            '^(Signal|Sinal)$' { if ($value -match '^([0-9]+)\s*%') { $current.Signal = [int]$Matches[1] } }
            '^(Radio type|Tipo de r.{1,3}dio)$' { $current.Radio = $value }
            '^(Band|Banda)$' { $current.Band = $value }
            '^(Channel|Canal)$' { $current.Channel = $value }
        }
    }

    return @($interfaces | Where-Object { $_.Ssid } | ForEach-Object { [PSCustomObject]$_ })
}


function Get-WinForgeWifiLinkText {
    # "802.11ax (Wi-Fi 6) · 5 GHz, canal 36", com o que o Windows informar (vazio sem nada).
    param ([Parameter(Mandatory)]$Wifi)

    $generation = switch -Regex ([string]$Wifi.Radio) {
        '802\.11be' { "Wi-Fi 7" }
        '802\.11ax' { $(if ([string]$Wifi.Band -match '^6') { "Wi-Fi 6E" } else { "Wi-Fi 6" }) }
        '802\.11ac' { "Wi-Fi 5" }
        '802\.11n' { "Wi-Fi 4" }
        default { "" }
    }

    $parts = @()
    if ($Wifi.Radio) { $parts += $(if ($generation) { "$($Wifi.Radio) ($generation)" } else { [string]$Wifi.Radio }) }

    $band = @(@([string]$Wifi.Band, $(if ($Wifi.Channel) { "canal $($Wifi.Channel)" })) | Where-Object { $_ }) -join ", "
    if ($band) { $parts += $band }

    return ($parts -join " · ")
}


function Get-WinForgeNetworkCategoryText {
    param ([string]$Category)

    switch ($Category) {
        "Public" { return "Pública" }
        "Private" { return "Privada" }
        "DomainAuthenticated" { return "Domínio (rede da empresa)" }
        default { return "" }
    }
}


function Show-WinForgeNetworkInfo {
    Enter-WinForgeAction -Title "Informações de rede"

    try {
        $activeAdapters = @(Get-NetAdapter -ErrorAction Stop | Where-Object { $_.Status -eq "Up" })

        # A configuração IP pode falhar por uma interface só (uma VPN ou um adaptador virtual sem DNS): os adaptadores, o
        # Wi-Fi e o proxy aparecem mesmo assim, e as seções dizem que o IP não pôde ser lido.
        $ipUnreadable = $false

        try {
            $ipConfigurations = @(Get-NetIPConfiguration -ErrorAction Stop | Where-Object { $_.IPv4Address -or $_.IPv6Address })
        }
        catch {
            $ipConfigurations = @()
            $ipUnreadable = $true
        }

        # Os extras (perfil da rede e detalhes do Wi-Fi) nunca derrubam a tela: sem eles, só não aparecem.
        $profiles = @()
        $wifiList = @()
        $wifiNeedsLocation = $false

        if ($activeAdapters.Count -gt 0) {
            try { $profiles = @(Get-NetConnectionProfile -ErrorAction Stop) } catch { $profiles = @() }

            try {
                $wlan = Invoke-WinForgeCapture -FilePath "netsh" -Arguments @("wlan", "show", "interfaces")
                $wifiList = @(ConvertFrom-WinForgeWlanInterfaces -Lines @($wlan.Lines))

                # Nas versões recentes do Windows 11, com a Localização desligada, a consulta não traz nada do Wi-Fi e só pede a
                # permissão (a mensagem cita "ms-settings:privacy-location").
                $wifiNeedsLocation = ($wifiList.Count -eq 0 -and [string]$wlan.Text -match 'privacy-location|WlanQueryInterface')
            }
            catch {
                $wifiList = @()
            }
        }
        else {
            Write-WinForgeSection -Title "Adaptadores"
            Write-WinForgeStatus -Type Warning -Message "Nenhum adaptador ativo encontrado (Wi-Fi desligado, cabo solto ou modo avião)."
        }

        $shownConfigs = New-Object System.Collections.Generic.List[object]

        # Uma seção por adaptador ativo, com tudo o que é dele junto: a placa, o Wi-Fi, a rede, o IP e o DNS.
        foreach ($adapter in $activeAdapters) {
            $name = [string]$adapter.Name
            Write-WinForgeSection -Title $name

            Write-WinForgeKeyValue -Label "Adaptador" -Value ([string](Get-WinForgeJsonValue -Object $adapter -Name "InterfaceDescription" -Default "")) -LabelWidth 18
            # O Windows escreve "866.7 Mbps"; no WinForge, a vírgula decimal ("866,7 Mbps").
            $linkSpeed = ([string](Get-WinForgeJsonValue -Object $adapter -Name "LinkSpeed" -Default "")) -replace '^([0-9]+)\.([0-9]+)(?= )', '$1,$2'
            Write-WinForgeKeyValue -Label "Velocidade do link" -Value $linkSpeed -LabelWidth 18
            Write-WinForgeKeyValue -Label "MAC" -Value ([string](Get-WinForgeJsonValue -Object $adapter -Name "MacAddress" -Default "")) -LabelWidth 18

            $wifi = @($wifiList | Where-Object { $_.Name -eq $name }) | Select-Object -First 1
            $weak = $false

            if ($null -ne $wifi) {
                $weak = $null -ne $wifi.Signal -and $wifi.Signal -lt 40
                Write-WinForgeKeyValue -Label "Rede Wi-Fi" -Value $wifi.Ssid -LabelWidth 18
                if ($null -ne $wifi.Signal) { Write-WinForgeKeyValue -Label "Sinal" -Value "$($wifi.Signal)%" -LabelWidth 18 -Level $(if ($weak) { "Warn" } else { "Normal" }) }
                $link = Get-WinForgeWifiLinkText -Wifi $wifi
                if ($link) { Write-WinForgeKeyValue -Label "Conexão Wi-Fi" -Value $link -LabelWidth 18 }
            }

            $netProfile = @($profiles | Where-Object { [string](Get-WinForgeJsonValue -Object $_ -Name "InterfaceAlias" -Default "") -eq $name }) | Select-Object -First 1

            # Privada (o PC aparece para os outros da rede) ou pública (fica oculto): o que o Windows decidiu ao conectar.
            if ($null -ne $netProfile) {
                $category = Get-WinForgeNetworkCategoryText -Category ([string](Get-WinForgeJsonValue -Object $netProfile -Name "NetworkCategory" -Default ""))
                if ($category) { Write-WinForgeKeyValue -Label "Tipo de rede" -Value $category -LabelWidth 18 }
            }

            $config = @($ipConfigurations | Where-Object { [string]$_.InterfaceAlias -eq $name }) | Select-Object -First 1

            if ($null -ne $config) {
                $shownConfigs.Add($config)
                Write-WinForgeNetworkConfig -Config $config
            }
            else {
                Write-WinForgeKeyValue -Label "IP" -Value $(if ($ipUnreadable) { "não foi possível ler" } else { "nenhum endereço" }) -LabelWidth 18
            }

            if ($weak) {
                Write-WinForgeStatus -Type Info -Message "O sinal do Wi-Fi está fraco: aproxime o PC do roteador ou use cabo."
            }
        }

        # Interfaces com IP sem um adaptador ativo na lista (uma VPN, por exemplo) também aparecem.
        foreach ($config in @($ipConfigurations | Where-Object { -not $shownConfigs.Contains($_) })) {
            Write-WinForgeSection -Title ([string]$config.InterfaceAlias)
            Write-WinForgeNetworkConfig -Config $config
        }

        if ($ipUnreadable) {
            Write-WinForgeStatus -Type Warning -Message "O Windows não informou a configuração IP (endereços, gateway e DNS)."
        }

        if ($wifiNeedsLocation) {
            Write-WinForgeStatus -Type Info -Message "Para ver a rede Wi-Fi e o sinal, ative a Localização em Configurações, Privacidade e segurança, Localização."
        }

        Write-WinForgeSection -Title "Internet"

        $proxy = Get-WinForgeProxySettings
        Write-WinForgeKeyValue -Label "Proxy" -Value $(if ($proxy.Text) { $proxy.Text } else { "nenhum" }) -LabelWidth 18

        if ($activeAdapters.Count -eq 0) {
            # Sem adaptador ativo a consulta só esperaria o tempo limite.
            Write-WinForgeStatus -Type Info -Message "Sem adaptador de rede ativo; a consulta do IP público foi ignorada."
        }
        else {
            try {
                Enable-WinForgeTls12
                $publicIp = ([string](Invoke-RestMethod -Uri "https://api.ipify.org" -TimeoutSec 5)).Trim()

                # Rede com página de login (Wi-Fi de hotel ou de aeroporto) responde com HTML em vez do endereço.
                if (Test-WinForgeIpAddressText -Text $publicIp) {
                    Write-WinForgeKeyValue -Label "IP público" -Value "$publicIp (consultado em api.ipify.org)" -LabelWidth 18
                }
                else {
                    Write-WinForgeStatus -Type Warning -Message "A consulta do IP público devolveu algo que não é um endereço IP (comum em Wi-Fi com página de login, como o de hotel)."
                }
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


function Test-WinForgeDnsPlaceholder {
    # Os endereços que o Windows põe como DNS IPv6 quando não há nenhum (fec0:0:0:ffff::1, ::2 e ::3): não respondem a nada.
    param ([string]$Address)

    return ([string]$Address -match '^fec0:0:0:ffff::[1-3](%.*)?$')
}


function Write-WinForgeNetworkConfig {
    # O IP, o gateway e o DNS de uma interface, nas linhas "Campo : valor" da seção dela.
    param ([Parameter(Mandatory)]$Config)

    $ipv4 = @(Get-WinForgeJsonValue -Object $Config -Name "IPv4Address" -Default @()) | ForEach-Object { $_.IPAddress }
    $ipv6 = @(Get-WinForgeJsonValue -Object $Config -Name "IPv6Address" -Default @()) | ForEach-Object { $_.IPAddress }
    $gateway = @(Get-WinForgeJsonValue -Object $Config -Name "IPv4DefaultGateway" -Default @()) | ForEach-Object { $_.NextHop }

    if (@($ipv4).Count -gt 0) { Write-WinForgeKeyValue -Label "IPv4" -Value (@($ipv4) -join ", ") -LabelWidth 18 }
    if (@($ipv6).Count -gt 0) { Write-WinForgeKeyValue -Label "IPv6" -Value (@($ipv6) -join ", ") -LabelWidth 18 }
    if (@($gateway).Count -gt 0) { Write-WinForgeKeyValue -Label "Gateway" -Value (@($gateway) -join ", ") -LabelWidth 18 }

    $index = Get-WinForgeJsonValue -Object $Config -Name "InterfaceIndex" -Default $null
    if ($null -eq $index) { return }

    # Cada família só com os endereços dela (um IPv4 nunca na linha do IPv6).
    foreach ($family in @(@{ Name = "IPv4"; Label = "DNS IPv4" }, @{ Name = "IPv6"; Label = "DNS IPv6" })) {
        $servers = @(
            Get-DnsClientServerAddress -InterfaceIndex $index -AddressFamily $family.Name -ErrorAction SilentlyContinue |
            ForEach-Object { $_.ServerAddresses } |
            Where-Object { $_ -and (([string]$_).Contains(":") -eq ($family.Name -eq "IPv6")) -and -not (Test-WinForgeDnsPlaceholder -Address $_) } |
            Select-Object -Unique
        )

        if ($servers.Count -gt 0) { Write-WinForgeKeyValue -Label $family.Label -Value ($servers -join ", ") -LabelWidth 18 }
    }
}


Export-ModuleMember -Function *
