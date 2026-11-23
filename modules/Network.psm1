# Rede: o que o Windows diz da conexão (a faixa da página), o teste de conectividade (ping), o reparo de rede e DNS, o
# teste de velocidade e as informações dos adaptadores. A troca do DNS, o Wi-Fi (relatório e senha) e o relógio ficam em
# NetworkTools.psm1.

# O teste de velocidade atrás de um proxy que pede autenticação e não aceitou a conta do Windows.
$script:WinForgeProxyAuthProblem = (Get-WinForgeText 'o proxy da rede pediu autenticação (HTTP 407) e não aceitou a conta do Windows; o teste não consegue passar por ele')


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
            throw (Get-WinForgeText 'Tempo esgotado ao aguardar a resposta do servidor.')
        }
    }
}


# ---------------------------------------------------------------------------
# Conectividade e ping
# ---------------------------------------------------------------------------

function Get-WinForgePingReplies {
    <#
    Pinga os endereços todos ao mesmo tempo, Count vezes cada, uma rodada por segundo, como o ping do Windows. Devolve uma
    tabela com, para cada endereço, os tempos de ida e volta (ms) das respostas que voltaram. Usa a classe Ping do .NET
    (pedidos de eco ICMP), a mesma nos dois PowerShell: cada pedido espera até TimeoutMilliseconds, e um nome que não vira
    endereço, uma falha no envio ou um tempo esgotado contam como pacote perdido. Antes, o Test-Connection pingava um
    endereço depois do outro (cerca de 4 s por endereço com a internet funcionando, e mais sem ela), e cada versão do
    PowerShell devolvia as respostas de um jeito. Activity: o andamento das rodadas na barra de progresso; quem chama a
    encerra.
    #>
    param (
        [Parameter(Mandatory)]
        [string[]]$ComputerName,

        [ValidateRange(1, 50)]
        [int]$Count = 4,

        [ValidateRange(500, 10000)]
        [int]$TimeoutMilliseconds = 2000,

        [string]$Activity = ""
    )

    $replies = @{}
    foreach ($name in $ComputerName) { $replies[$name] = New-Object System.Collections.Generic.List[double] }

    for ($round = 0; $round -lt $Count; $round++) {
        if ($Activity) { Write-Progress -Activity $Activity -Status (Get-WinForgeText 'pacote {0} de {1}' "$($round + 1)" "$Count") -PercentComplete ([int]($round * 100 / $Count)) }

        $clock = [System.Diagnostics.Stopwatch]::StartNew()
        $sent = New-Object System.Collections.Generic.List[object]

        try {
            foreach ($name in $ComputerName) {
                # Um Ping por pedido: a mesma instância não aceita dois envios ao mesmo tempo.
                $entry = [PSCustomObject]@{ Name = $name; Ping = (New-Object System.Net.NetworkInformation.Ping); Task = $null }
                $sent.Add($entry)

                try {
                    $entry.Task = $entry.Ping.SendPingAsync($name, $TimeoutMilliseconds)
                }
                catch {
                    # Um nome que não vira endereço pode falhar já no envio: é um pacote perdido, como os outros.
                    Write-Verbose "Ping para ${name}: $($_.Exception.Message)"
                }
            }

            foreach ($entry in $sent) {
                if ($null -eq $entry.Task) { continue }

                try {
                    Wait-WinForgeTask -Task $entry.Task -TimeoutSeconds ([int][Math]::Ceiling($TimeoutMilliseconds / 1000) + 3)
                    $reply = $entry.Task.Result
                    if ($null -ne $reply -and [string]$reply.Status -eq "Success") { $replies[$entry.Name].Add([double]$reply.RoundtripTime) }
                }
                catch {
                    # Sem resposta (o nome não resolve, a rede recusou o envio): pacote perdido.
                    Write-Verbose "Ping para $($entry.Name): $($_.Exception.Message)"
                }
            }
        }
        finally {
            foreach ($entry in $sent) { $entry.Ping.Dispose() }
        }

        # Uma rodada por segundo: o que sobra do segundo é a espera até a próxima.
        $rest = 1000 - [int]$clock.ElapsedMilliseconds
        if ($round -lt $Count - 1 -and $rest -gt 0) { Start-Sleep -Milliseconds $rest }
    }

    return $replies
}


function ConvertTo-WinForgePingStats {
    # A perda (em %) e os tempos (média, mínimo e máximo, em ms) de um endereço, a partir dos tempos das respostas que
    # voltaram (Get-WinForgePingReplies) e de quantos pacotes foram enviados. Sem resposta, os tempos ficam "-": um
    # pacote perdido não marca o endereço inteiro como falho.
    param (
        [AllowEmptyCollection()]
        [object[]]$Latencies = @(),

        [ValidateRange(1, 50)]
        [int]$Sent = 4
    )

    $times = @($Latencies | Where-Object { $null -ne $_ } | ForEach-Object { [double]$_ })
    $received = [Math]::Min($times.Count, $Sent)
    $lossPercent = [Math]::Round((($Sent - $received) / $Sent) * 100, 0)

    if ($times.Count -gt 0) {
        $measure = $times | Measure-Object -Average -Minimum -Maximum
        $average = [Math]::Round($measure.Average, 1)
        $minimum = [Math]::Round($measure.Minimum, 1)
        $maximum = [Math]::Round($measure.Maximum, 1)
    }
    else {
        $average = "-"; $minimum = "-"; $maximum = "-"
    }

    return [PSCustomObject]@{
        Received = $received
        Sent     = $Sent
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

    if ($LossPercent -ge 100) { return (Get-WinForgeText 'Sem resposta') }
    if ($LossPercent -gt 0) { return (Get-WinForgeText 'Instável') }
    return "OK"
}


function Test-WinForgeInternetConnectivity {
    # Separa "sem rota" (acesso a IPs) de "sem DNS" (resolução de nomes): cada um aponta para um reparo diferente.
    # Redes e firewalls que bloqueiam o ping (ICMP) são comuns; por isso, se o ping falha, uma conexão TCP na porta 443
    # decide. Sem isso, uma rede saudável seria tratada como quebrada e a Manutenção redefiniria o Winsock sem motivo.
    $pingOk = $false
    $viaTcp = $false
    $targets = @("1.1.1.1", "8.8.8.8")

    # Os dois ao mesmo tempo: basta um responder.
    try {
        $replies = Get-WinForgePingReplies -ComputerName $targets -Count 2
        $pingOk = (@($targets | Where-Object { @($replies[$_] | Where-Object { $null -ne $_ }).Count -gt 0 }).Count -gt 0)
    }
    catch {
        $pingOk = $false
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


function Get-WinForgeInternetConnection {
    <#
    O que o próprio Windows diz da conexão agora: o indicador de conectividade dele, o mesmo do ícone de rede da barra de
    tarefas, lido pela API do Windows (Windows.Networking.Connectivity), na hora e sem o WMI. Devolve Level e Name.
    Level: Internet (com internet), Limited (acesso limitado: em geral, um Wi-Fi que pede login numa página, como o de
    hotel e aeroporto; às vezes, um proxy no caminho), Local (ligado a uma rede, sem internet), None (nenhuma rede) ou ""
    (não deu para saber). Name: a rede, como a pessoa a conhece ("Wi-Fi Casa", "Cabo de rede", "Rede celular").
    A Microsoft avisa que é um indício: quem confirma é o teste de conectividade, para onde a faixa da página leva.
    #>
    try {
        $network = [Windows.Networking.Connectivity.NetworkInformation, Windows.Networking.Connectivity, ContentType=WindowsRuntime]
        $connection = $network::GetInternetConnectionProfile()

        # Sem a conexão preferida (o Windows a devolve vazia quando está desconectado), vale a melhor das ativas.
        if ($null -eq $connection) {
            $rank = @{ "LocalAccess" = 1; "ConstrainedInternetAccess" = 2; "InternetAccess" = 3 }
            $connection = @(
                @($network::GetConnectionProfiles()) | Where-Object { $null -ne $_ -and $rank.ContainsKey([string]$_.GetNetworkConnectivityLevel()) } |
                    Sort-Object -Property @{ Expression = { $rank[[string]$_.GetNetworkConnectivityLevel()] } } -Descending
            ) | Select-Object -First 1
        }

        if ($null -eq $connection) { return [PSCustomObject]@{ Level = "None"; Name = "" } }

        $level = switch ([string]$connection.GetNetworkConnectivityLevel()) {
            "InternetAccess" { "Internet" }
            "ConstrainedInternetAccess" { "Limited" }
            "LocalAccess" { "Local" }
            default { "None" }
        }

        # O nome que a pessoa reconhece: o da rede Wi-Fi (sem a Localização, no Windows 11 recente, pode vir vazio), o cabo
        # ou a rede celular.
        $name = ""

        try {
            if ([bool]$connection.IsWlanConnectionProfile) {
                $ssid = ""
                try { $ssid = [string]$connection.WlanConnectionProfileDetails.GetConnectedSsid() } catch { $ssid = "" }
                if (-not $ssid) { $ssid = [string]$connection.ProfileName }
                $name = $(if ($ssid) { (Get-WinForgeText 'Wi-Fi {0}' "$ssid") } else { "Wi-Fi" })
            }
            elseif ([bool]$connection.IsWwanConnectionProfile) { $name = (Get-WinForgeText 'Rede celular') }
            elseif ([int]$connection.NetworkAdapter.IanaInterfaceType -eq 6) { $name = (Get-WinForgeText 'Cabo de rede') }
            else { $name = [string]$connection.ProfileName }
        }
        catch {
            $name = [string]$connection.ProfileName
        }

        return [PSCustomObject]@{ Level = $level; Name = $name.Trim() }
    }
    catch {
        Write-Verbose "Conexão segundo o Windows: $($_.Exception.Message)"
        return [PSCustomObject]@{ Level = ""; Name = "" }
    }
}


function Get-WinForgeNetworkPageStatus {
    <#
    O resumo no alto da página Rede: a conexão, como o Windows a vê agora (Get-WinForgeInternetConnection, na hora, sem o
    WMI). Cada linha tem Label, Text, Level (Normal | Warn | Muted) e Opens. Sem internet, com o acesso limitado (um
    Wi-Fi que pede login) ou sem rede, a linha fica em amarelo e abre o Testar conectividade, que confirma o problema e
    leva ao que resolve (o reparo, as configurações de rede ou a página de login da rede).
    #>
    $connection = Get-WinForgeInternetConnection
    $name = $(if ([string]$connection.Name) { [string]$connection.Name } else { (Get-WinForgeText 'Conectado') })
    $row = [PSCustomObject]@{ Label = (Get-WinForgeText 'Conexão'); Text = (Get-WinForgeText 'não foi possível ler'); Level = "Muted"; Opens = "" }

    switch ([string]$connection.Level) {
        "Internet" { $row.Text = (Get-WinForgeText '{0} · com internet' "$name"); $row.Level = "Normal" }
        "Limited" { $row.Text = (Get-WinForgeText '{0} · acesso limitado (a rede pode pedir login)' "$name"); $row.Level = "Warn"; $row.Opens = "network.ping" }
        "Local" { $row.Text = (Get-WinForgeText '{0} · sem internet' "$name"); $row.Level = "Warn"; $row.Opens = "network.ping" }
        "None" { $row.Text = (Get-WinForgeText 'nenhuma rede conectada'); $row.Level = "Warn"; $row.Opens = "network.ping" }
    }

    return @($row)
}


function Set-WinForgeNoNetworkView {
    # A faixa de quando o PC não está ligado a nenhuma rede (Wi-Fi desligado, cabo solto, modo avião): o que fazer e o
    # botão das configurações de rede. A mesma no teste de conectividade, no de velocidade, nas informações e no reparo.
    # Devolve o próprio resultado.
    param ([Parameter(Mandatory)]$Result)

    return (Set-WinForgeResultView -Result $Result -Headline (Get-WinForgeText 'Nenhuma rede conectada') -Note (Get-WinForgeText 'Ligue o Wi-Fi ou conecte o cabo; confira também o modo avião.') `
            -Next "NetworkSettings" -NextLabel (Get-WinForgeText 'Abrir as configurações de rede'))
}


function Get-WinForgeIpReachText {
    # Texto do "acesso por IP direto" (sem DNS) para as telas de diagnóstico e de reparo.
    param (
        [Parameter(Mandatory)]
        $Connectivity
    )

    if (-not $Connectivity.PingOk) { return (Get-WinForgeText 'Sem resposta') }
    if ($Connectivity.ViaTcp) { return (Get-WinForgeText 'Responde (o ping está bloqueado, mas a conexão TCP funciona)') }

    return (Get-WinForgeText 'Responde')
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
    if ($server) { $parts += (Get-WinForgeText '{0} (manual)' "$serverText") }
    if ($scriptUrl) { $parts += (Get-WinForgeText 'script de configuração ({0})' "$scriptText") }

    return [PSCustomObject]@{
        Server    = $server
        ScriptUrl = $scriptUrl
        Text      = (Join-WinForgeList -Items $parts)
    }
}


function Get-WinForgePingVerdict {
    <#
    Conclusão do teste de conectividade. Results: objetos com Host e Loss (perda em %), e Resolved (opcional: o DNS do PC
    resolve o nome, mesmo que ele não responda ao ping). Separa os casos que pedem ações diferentes: nada responde (sem
    internet), os IPs respondem mas os nomes não resolvem (DNS), a conexão perde dados (instável: dois ou mais alvos com
    perda, ou um com perda de 50% ou mais) e tudo responde. Um alvo que não responde nada enquanto os outros respondem é só
    um servidor que ignora o ping, não um problema; nomes que resolvem mas não respondem ao ping também não. -Limited (o
    Windows diz que a rede limita o acesso: em geral, um Wi-Fi que pede login numa página): o "sem internet" e o "DNS"
    viram o que a pessoa precisa fazer, entrar na página da rede; o reparo não resolve isso.
    Devolve Level (Warning ou Success, para a última linha da tela), Message, Kind (Warning ou Ok), Detail (a faixa no
    console e no histórico) e, para a janela, Headline e Note (o título e a frase da faixa) e Next e NextLabel (o botão do
    que resolve: o reparo, quando ele resolve; nenhum quando o problema está fora do PC).
    #>
    param (
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Results,

        [switch]$Limited
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

    $dnsBroken = ($addressAnswered -gt 0 -and $byName.Count -gt 0 -and $nameAnswered -eq 0 -and $nameResolved -eq 0)

    if ($Limited -and ($answered.Count -eq 0 -or $dnsBroken)) {
        return (& $verdict "Warning" (Get-WinForgeText 'O Windows indica que a rede limita o acesso: em geral, um Wi-Fi que pede login numa página (hotel, aeroporto, café). Abra o navegador e entre na página da rede; o reparo não resolve isso.') (Get-WinForgeText 'a rede limita o acesso (pode pedir login numa página)') `
                (Get-WinForgeText 'A rede limita o acesso') (Get-WinForgeText 'Comum em Wi-Fi de hotel, aeroporto e café: abra o navegador e entre na página de login da rede.'))
    }

    if ($answered.Count -eq 0) {
        return (& $verdict "Warning" (Get-WinForgeText 'Nada respondeu: o PC está sem internet. Confira o Wi-Fi, o cabo e o roteador; se continuar, use Rede > Reparar rede e DNS.') (Get-WinForgeText 'nada respondeu; o PC está sem internet') `
                (Get-WinForgeText 'Sem internet') (Get-WinForgeText 'Nada respondeu. Confira o Wi-Fi, o cabo e o roteador; se estiver tudo ligado, repare a rede.') "network.repair" (Get-WinForgeText 'Reparar a rede'))
    }

    if ($dnsBroken) {
        return (& $verdict "Warning" (Get-WinForgeText 'A internet responde, mas os sites não abrem pelo nome: o problema é o DNS. Use Rede > Reparar rede e DNS ou Rede > Trocar o servidor DNS.') (Get-WinForgeText 'os sites não abrem pelo nome (problema de DNS)') `
                (Get-WinForgeText 'Os sites não abrem pelo nome') (Get-WinForgeText 'A internet responde, mas o DNS não. Reparar a rede costuma resolver; se não resolver, troque o servidor DNS.') "network.repair" (Get-WinForgeText 'Reparar a rede'))
    }

    if ($lossy.Count -ge 2 -or $heavy.Count -gt 0) {
        return (& $verdict "Warning" (Get-WinForgeText 'A conexão está instável, com perda de dados: aproxime o PC do roteador ou use cabo; se continuar, fale com a operadora.') (Get-WinForgeText 'a conexão está instável, com perda de dados') `
                (Get-WinForgeText 'Conexão instável') (Get-WinForgeText 'Há perda de dados: aproxime o PC do roteador ou use cabo; se continuar, fale com a operadora.'))
    }

    if ($answered.Count -lt @($Results).Count) {
        return (& $verdict "Ok" (Get-WinForgeText 'A internet está funcionando; alguns endereços não responderam, mas há servidores que ignoram o ping.') (Get-WinForgeText 'a internet está funcionando; alguns endereços ignoram o ping') `
                (Get-WinForgeText 'A internet está funcionando') (Get-WinForgeText 'Alguns endereços não responderam, mas há servidores que ignoram o ping.'))
    }

    if ($lossy.Count -gt 0) {
        return (& $verdict "Ok" (Get-WinForgeText 'A internet está respondendo bem; um dos testes perdeu um pouco de dados, o que é normal.') (Get-WinForgeText 'a internet está respondendo bem') `
                (Get-WinForgeText 'A internet está funcionando') (Get-WinForgeText 'Um dos testes perdeu um pouco de dados, o que é normal.'))
    }

    return (& $verdict "Ok" (Get-WinForgeText 'A internet está respondendo bem e sem perdas.') (Get-WinForgeText 'a internet está respondendo bem e sem perdas') (Get-WinForgeText 'A internet está funcionando') (Get-WinForgeText 'Respondeu bem, sem perda de dados.'))
}


function Format-WinForgePingLine {
    # A linha de um alvo no resumo: "OK · média 12 ms (mín. 10, máx. 15)", "Instável · 25% de perda · média 30 ms" ou
    # "Sem resposta".
    param ([Parameter(Mandatory)]$Stats)

    $status = Get-WinForgePingStatusText -LossPercent ([int]$Stats.Loss)

    if ([int]$Stats.Loss -ge 100) { return $status }

    # Sem o tempo nas respostas ("-"), só a situação e a perda.
    $times = $(if ($Stats.Average -is [string]) { "" } else { (Get-WinForgeText 'média {0} ms (mín. {1}, máx. {2})' "$(Format-WinForgeNumber -Value $Stats.Average -Decimals 0)" "$(Format-WinForgeNumber -Value $Stats.Minimum -Decimals 0)" "$(Format-WinForgeNumber -Value $Stats.Maximum -Decimals 0)") })
    if (-not $times) { return $(if ([int]$Stats.Loss -gt 0) { (Get-WinForgeText '{0} · {1}% de perda' "$status" "$($Stats.Loss)") } else { $status }) }

    if ([int]$Stats.Loss -gt 0) { return (Get-WinForgeText '{0} · {1}% de perda · {2}' "$status" "$($Stats.Loss)" "$times") }

    return "$status · $times"
}


function Test-WinForgePing {
    Enter-WinForgeAction -Title (Get-WinForgeText 'Testar conectividade (ping)')

    $final = New-WinForgeResult -Kind Failed -Detail (Get-WinForgeText 'o teste não devolveu resultado')
    $targets = @(
        [PSCustomObject]@{ Name = (Get-WinForgeText 'Cloudflare DNS'); Host = "1.1.1.1" },
        [PSCustomObject]@{ Name = "Google DNS"; Host = "8.8.8.8" },
        [PSCustomObject]@{ Name = (Get-WinForgeText 'Quad9 DNS'); Host = "9.9.9.9" },
        [PSCustomObject]@{ Name = "Microsoft"; Host = "www.microsoft.com" },
        [PSCustomObject]@{ Name = "Google"; Host = "www.google.com" }
    )

    try {
        # Sem nenhuma rede (Wi-Fi desligado, cabo solto, modo avião), os cinco testes só confirmariam o óbvio, e o reparo, que a
        # faixa de "sem internet" oferece, não liga o Wi-Fi nem o cabo.
        if ($false -eq (Test-WinForgeNetworkConnected)) {
            Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'O PC não está ligado a nenhuma rede: ligue o Wi-Fi ou conecte o cabo (e confira o modo avião).')
            $final = Set-WinForgeNoNetworkView -Result (New-WinForgeResult -Kind Warning -Detail (Get-WinForgeText 'o PC não está ligado a nenhuma rede'))
            Exit-WinForgeAction -Result $final
            return
        }

        # Os cinco endereços ao mesmo tempo, quatro pacotes cada; o andamento vai para a barra de progresso (uma linha por
        # alvo ficaria no resumo depois do fim).
        try {
            $replies = Get-WinForgePingReplies -ComputerName @($targets | ForEach-Object { $_.Host }) -Count 4 -Activity (Get-WinForgeText 'Testando a conectividade')
        }
        finally {
            Write-Progress -Activity (Get-WinForgeText 'Testando a conectividade') -Completed
        }

        $results = @(
            foreach ($target in $targets) {
                $stats = ConvertTo-WinForgePingStats -Latencies @($replies[$target.Host]) -Sent 4
                [PSCustomObject]@{ Name = $target.Name; Host = $target.Host; Loss = $stats.Loss; Resolved = $false; Stats = $stats }
            }
        )

        # Um nome que não respondeu ao ping pode ser um ping bloqueado ou um DNS quebrado: só vale perguntar ao DNS quando algum
        # IP respondeu (sem nenhum, a conclusão é "nada responde" de qualquer jeito).
        if (@($results | Where-Object { (Test-WinForgeIpAddressText -Text $_.Host) -and [int]$_.Loss -lt 100 }).Count -gt 0) {
            foreach ($row in @($results | Where-Object { -not (Test-WinForgeIpAddressText -Text $_.Host) -and [int]$_.Loss -ge 100 })) {
                $row.Resolved = [bool](Test-WinForgeDnsResolution -Name $row.Host)
            }
        }

        Write-WinForgeSection -Title (Get-WinForgeText 'Resultado')

        # A cor de cada linha diz o que ela significa: vermelho sem resposta, amarelo com perda, verde sem perda. Um site cujo
        # nome funciona e que só não responde ao ping não é problema (a conclusão diz o mesmo): sem vermelho.
        foreach ($row in $results) {
            $loss = [int]$row.Stats.Loss

            if ($loss -ge 100 -and $row.Resolved) {
                Write-WinForgeKeyValue -Label "$($row.Name) ($($row.Host))" -Value (Get-WinForgeText 'Não responde ao ping (normal em alguns servidores)') -LabelWidth 29
                continue
            }

            $level = $(if ($loss -ge 100) { "Bad" } elseif ($loss -gt 0) { "Warn" } else { "Ok" })
            Write-WinForgeKeyValue -Label "$($row.Name) ($($row.Host))" -Value (Format-WinForgePingLine -Stats $row.Stats) -LabelWidth 29 -Level $level
        }

        Write-Host ""

        # Com algo sem resposta, o Windows pode saber o motivo: uma rede que limita o acesso (um Wi-Fi que pede login numa
        # página). O reparo não resolve isso, e a faixa não o oferece.
        $limited = $false
        if (@($results | Where-Object { [int]$_.Loss -ge 100 }).Count -gt 0) { $limited = ([string](Get-WinForgeInternetConnection).Level -eq "Limited") }

        # A conclusão é a última linha da tela; a faixa diz o mesmo em poucas palavras. O teste rodou até o fim, então um
        # problema encontrado (sem internet, DNS, conexão instável) é uma ressalva, não um "não foi concluído".
        $verdict = Get-WinForgePingVerdict -Results $results -Limited:$limited
        Write-WinForgeStatus -Type $verdict.Level -Message $verdict.Message
        $final = Set-WinForgeResultView -Result (New-WinForgeResult -Kind $verdict.Kind -Detail $verdict.Detail) -Headline $verdict.Headline -Note $verdict.Note `
            -Next $verdict.Next -NextLabel $verdict.NextLabel
    }
    catch {
        Write-WinForgeStatus -Type Error -Message (Get-WinForgeText 'Ocorreu um erro no teste de ping: {0}' "$($_.Exception.Message)")
        $final = New-WinForgeResult -Kind Failed -Detail $_.Exception.Message
    }

    Exit-WinForgeAction -Result $final
}


# ---------------------------------------------------------------------------
# Reparo de rede e DNS
# ---------------------------------------------------------------------------

function Get-WinForgeStaticIpConfiguration {
    <#
    Há configuração de IP feita à mão em algum adaptador? O "netsh int ip reset" apaga endereços fixos de TODOS os
    adaptadores, então todos contam: com ou sem gateway (uma segunda placa numa rede interna não tem), ligados ou não,
    IPv4 e IPv6. Um adaptador conta como fixo quando tem um endereço posto à mão (PrefixOrigin Manual, qualquer família)
    ou o DHCP do IPv4 desligado. O loopback fica de fora (o Windows o configura assim). Devolve Static (há configuração
    fixa, ou não deu para saber), Unknown (a consulta falhou), Interfaces (os nomes) e Dhcp (algum adaptador conectado
    pega o IPv4 do roteador).
    O "ipconfig /release" e o "/renew" só mexem nos adaptadores com IP automático (DHCP), como diz a documentação da
    Microsoft: um IP fixo em outro adaptador (o do VirtualBox, o do WSL) não os impede. Sem nenhum adaptador automático
    conectado, eles não teriam o que fazer.
    O IPv6 não entra pelo DHCP desligado: ele se configura sozinho pelo roteador mesmo sem DHCPv6.
    Os filtros ficam aqui, e não nos parâmetros dos cmdlets: um filtro que não acha nada (nenhum endereço manual) vira
    erro de "objeto não encontrado", e um PC só com DHCP pareceria um PC que não pôde ser consultado.
    #>
    $names = New-Object System.Collections.ArrayList
    $dhcp = $false

    try {
        foreach ($address in @(Get-NetIPAddress -ErrorAction Stop)) {
            if ($null -eq $address -or [string]$address.PrefixOrigin -ne "Manual") { continue }
            $alias = [string]$address.InterfaceAlias
            if ($alias -like "Loopback*" -or [string]$address.InterfaceIndex -eq "1") { continue }
            if (-not $names.Contains($alias)) { [void]$names.Add($alias) }
        }

        foreach ($interface in @(Get-NetIPInterface -ErrorAction Stop)) {
            if ($null -eq $interface -or [string]$interface.AddressFamily -ne "IPv4") { continue }
            $alias = [string]$interface.InterfaceAlias
            if ($alias -like "Loopback*" -or [string]$interface.InterfaceIndex -eq "1") { continue }

            # Um adaptador automático conectado (sem o estado da conexão, conta como conectado): há o que renovar.
            if ([string]$interface.Dhcp -eq "Enabled") {
                if ([string](Get-WinForgeJsonValue -Object $interface -Name "ConnectionState" -Default "Connected") -ne "Disconnected") { $dhcp = $true }
                continue
            }

            if ([string]$interface.Dhcp -ne "Disabled") { continue }
            if (-not $names.Contains($alias)) { [void]$names.Add($alias) }
        }
    }
    catch {
        # Sem saber, vale o lado seguro: o reparo deixa de fora o que apagaria uma configuração fixa, e não renova o IP.
        return [PSCustomObject]@{ Static = $true; Unknown = $true; Interfaces = @(); Dhcp = $false }
    }

    return [PSCustomObject]@{ Static = ($names.Count -gt 0); Unknown = $false; Interfaces = @($names); Dhcp = $dhcp }
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
        [string]$Title = (Get-WinForgeText 'Reparar rede e DNS'),
        [string]$Reason
    )

    try {
        $dns = Invoke-WinForgeNetworkCommand -Title (Get-WinForgeText 'Limpar cache DNS') -FilePath "ipconfig.exe" -Arguments @("/flushdns")
    }
    finally {
        Write-Progress -Activity (Get-WinForgeText 'Reparando a rede') -Completed
    }

    if ($dns.Kind -eq "Failed") {
        Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'O DNS não foi limpo; o resto do reparo ficou de fora porque {0}.' "$Reason")
        return (New-WinForgeResult -Kind Warning -Detail (Get-WinForgeText 'o DNS não foi limpo ({0})' "$Reason") -Title $Title)
    }

    Write-WinForgeStatus -Type Success -Message (Get-WinForgeText 'DNS limpo. O resto do reparo ficou de fora porque {0}.' "$Reason")
    return (New-WinForgeResult -Kind Ok -Detail (Get-WinForgeText 'só o DNS foi limpo: {0}' "$Reason") -Title $Title)
}


function Get-WinForgeNetworkHoldReason {
    <#
    O motivo para o reparo de manutenção não derrubar a conexão: o PC usado pela Área de Trabalho Remota ou uma VPN
    ligada (as do Windows, por Get-VpnConnection, e as de programas, pelo adaptador de rede deles: OpenVPN, WireGuard,
    AnyConnect, GlobalProtect, FortiClient e outras). "" quando nada impede. Sem como ler, não impede.
    #>
    if ([string]$env:SESSIONNAME -like "RDP-*") { return (Get-WinForgeText 'o PC está sendo usado pela Área de Trabalho Remota') }

    if (Get-Command Get-VpnConnection -ErrorAction SilentlyContinue) {
        foreach ($scope in @($false, $true)) {
            try {
                $connections = $(if ($scope) { @(Get-VpnConnection -AllUserConnection -ErrorAction Stop) } else { @(Get-VpnConnection -ErrorAction Stop) })
                if (@($connections | Where-Object { [string]$_.ConnectionStatus -eq "Connected" }).Count -gt 0) { return (Get-WinForgeText 'há uma VPN ligada') }
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
            if ($vpn.Count -gt 0) { return (Get-WinForgeText 'há uma VPN ligada') }
        }
        catch {
            return ""
        }
    }

    return ""
}


function Get-WinForgeNetworkRepairCommands {
    param (
        # IP fixo em algum adaptador (Get-WinForgeStaticIpConfiguration): o reset de TCP/IP fica de fora.
        [switch]$HasStaticIp,

        # DNS posto à mão em algum adaptador (Get-WinForgeManualDnsAdapters): o reset de TCP/IP fica de fora.
        [switch]$HasManualDns,

        # Nenhum adaptador conectado pega o IP do roteador, ou não deu para saber: liberar e renovar ficam de fora.
        [switch]$NoDhcp
    )

    # A ordem importa: o IP é liberado e renovado primeiro, a limpeza de DNS vem depois (já com o IP novo) e os
    # resets de Winsock/TCP-IP ficam por último porque só terminam de valer após reiniciar.
    # O release/renew só mexe nos adaptadores com IP automático (um IP fixo continua como está); o reset de TCP/IP apaga o
    # IP e o DNS postos à mão em todos os adaptadores.
    # Id diz qual é cada um (release, renew, flushdns, winsock, ipreset), sem depender do título traduzido.
    $commands = @()

    if (-not $NoDhcp) {
        $commands += [PSCustomObject]@{ Id = "release"; Title = (Get-WinForgeText 'Liberar endereço IP'); FilePath = "ipconfig.exe"; Arguments = @("/release"); NeedsRestart = $false }
        $commands += [PSCustomObject]@{ Id = "renew"; Title = (Get-WinForgeText 'Renovar endereço IP'); FilePath = "ipconfig.exe"; Arguments = @("/renew"); NeedsRestart = $false }
    }

    $commands += [PSCustomObject]@{ Id = "flushdns"; Title = (Get-WinForgeText 'Limpar cache DNS'); FilePath = "ipconfig.exe"; Arguments = @("/flushdns"); NeedsRestart = $false }
    $commands += [PSCustomObject]@{ Id = "winsock"; Title = (Get-WinForgeText 'Redefinir Winsock'); FilePath = "netsh.exe"; Arguments = @("winsock", "reset"); NeedsRestart = $true }

    if (-not $HasStaticIp -and -not $HasManualDns) {
        $commands += [PSCustomObject]@{ Id = "ipreset"; Title = (Get-WinForgeText 'Redefinir TCP/IP'); FilePath = "netsh.exe"; Arguments = @("int", "ip", "reset"); NeedsRestart = $true }
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
    Write-Progress -Activity (Get-WinForgeText 'Reparando a rede') -Status $Title

    try {
        $exitCode = Invoke-WinForgeNative -FilePath $FilePath -Arguments $Arguments -IgnoreExitCode -PassThru
    }
    catch {
        Write-WinForgeStatus -Type Error -Message (Get-WinForgeText '{0} falhou: {1}' "$Title" "$($_.Exception.Message)")
        $result = New-WinForgeResult -Kind Failed -Detail $_.Exception.Message
        $result.Etapa = $Title
        return $result
    }

    $result = Get-WinForgeExitCodeResult -ExitCode $exitCode
    $result.Etapa = $Title

    if ($result.Kind -eq "Ok") {
        Write-WinForgeStatus -Type Success -Message (Get-WinForgeText '{0} concluído.' "$Title")
    }
    else {
        Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'Não deu certo: {0} (código {1}).' "$Title" "$(Format-WinForgeExitCode -ExitCode $exitCode)")
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
    # com -Embedded: com a rede funcionando, limpa o DNS, como manutenção; o resto do reparo (renovar o IP, redefinir o
    # Winsock e o TCP/IP) é para quando a internet falha, como a Microsoft indica: num PC que funciona ele não melhora
    # nada, pede reinício e pode desfazer uma VPN, um antivírus que filtra a rede ou configurações postas à mão. Sem
    # nenhuma rede conectada, o reparo continua de fora. Numa rede que limita o acesso (um Wi-Fi que pede login numa página),
    # nenhum comando do reparo faz o login: dentro de um fluxo, só o DNS é limpo; sozinho, a tela diz isso antes de perguntar.
    # Sozinho, quando o Winsock ou o TCP/IP foram refeitos, oferece reiniciar (Depois como padrão).
    param (
        [switch]$Embedded,
        [switch]$PassThru,
        [switch]$Force
    )

    $title = (Get-WinForgeText 'Reparar rede e DNS')

    Enter-WinForgeAction -Title $title -Embedded:$Embedded

    if (-not (Test-WinForgeElevation -Reason (Get-WinForgeText 'O reparo de rede exige privilégios de Administrador.'))) {
        $early = New-WinForgeResult -Kind Failed -Detail (Get-WinForgeText 'sem privilégios de Administrador') -Title $title
        if ($PassThru) { $early }
        Exit-WinForgeAction -Embedded:$Embedded -Result $early
        return
    }

    # IP fixo em algum adaptador (com os nomes, para o aviso).
    $staticIp = Get-WinForgeStaticIpConfiguration
    $hasStaticIp = [bool]$staticIp.Static
    # Liberar e renovar o IP só quando algum adaptador conectado o pega do roteador (sem saber, não).
    $noDhcp = ([bool]$staticIp.Unknown -or -not [bool](Get-WinForgeJsonValue -Object $staticIp -Name "Dhcp" -Default $true))
    # DNS posto à mão (com os nomes, para o aviso): o reset de TCP/IP o apagaria.
    $manualDns = @(Get-WinForgeManualDnsAdapters)
    $hasManualDns = ($manualDns.Count -gt 0)
    $final = New-WinForgeResult -Kind Ok -Title $title

    # O reparo refaz as configurações de rede do Windows, o que costuma resolver internet que não abre sites; o que ele faz
    # aparece em "O que o reparo faz", antes da pergunta.
    Write-WinForgeSection -Title (Get-WinForgeText 'Diagnóstico rápido')
    Write-Progress -Activity $title -Status (Get-WinForgeText 'testando a conexão')

    try { $connectivity = Test-WinForgeInternetConnectivity } finally { Write-Progress -Activity $title -Completed }
    Write-WinForgeKeyValue -Label (Get-WinForgeText 'Acesso por IP (sem DNS)') -Value (Get-WinForgeIpReachText -Connectivity $connectivity) -LabelWidth 26
    Write-WinForgeKeyValue -Label (Get-WinForgeText 'Resolução de DNS') -Value $(if ($connectivity.DnsOk) { (Get-WinForgeText 'Funciona') } else { (Get-WinForgeText 'Falhou') }) -LabelWidth 26

    # Um proxy configurado (por um programa ou pela empresa) explica a internet que só funciona em alguns programas, e
    # nenhum dos comandos do reparo o muda.
    $proxy = Get-WinForgeProxySettings
    if ($proxy.Text) { Write-WinForgeKeyValue -Label (Get-WinForgeText 'Proxy') -Value $proxy.Text -LabelWidth 26 }

    # Quando os testes diretos falham, o que o Windows diz da conexão também conta (numa rede com proxy, o acesso direto
    # a 1.1.1.1 e 8.8.8.8 é bloqueado, mas a internet funciona).
    $windowsInternet = $null
    $limited = $false

    if (-not $connectivity.Ok) {
        # O Windows sabe quando a rede limita o acesso (em geral, um Wi-Fi que pede login numa página).
        $limited = ([string](Get-WinForgeInternetConnection).Level -eq "Limited")
        $windowsInternet = Get-WinForgeWindowsInternetStatus

        if ($null -ne $windowsInternet) {
            Write-WinForgeKeyValue -Label (Get-WinForgeText 'Conexão segundo o Windows') -Value $(if ($windowsInternet) { (Get-WinForgeText 'Com acesso à internet') } else { (Get-WinForgeText 'Sem acesso à internet') }) -LabelWidth 26
        }
    }

    # Dentro de um fluxo, o reparo só roda se algo estiver quebrado; no Otimizar (-Force), com a rede funcionando, o DNS é
    # limpo (mais abaixo).
    if ($Embedded -and -not $Force -and $connectivity.Ok) {
        Write-WinForgeStatus -Type Success -Message (Get-WinForgeText 'A conexão e o DNS funcionam; o reparo de rede não é necessário.')

        $early = New-WinForgeResult -Kind Skipped -Detail (Get-WinForgeText 'rede funcionando') -Title $title
        if ($PassThru) { $early }
        Exit-WinForgeAction -Embedded:$Embedded -Result $early
        return
    }

    # Sem ninguém olhando, o reparo (que derruba a conexão e redefine o Winsock) só roda quando nada indica que a rede
    # funciona: nomes que resolvem ou o Windows dizendo que há internet bastam para não mexer.
    if ($Embedded -and -not $Force -and ($connectivity.DnsOk -or $windowsInternet -eq $true)) {
        $evidence = $(if ($windowsInternet -eq $true) { (Get-WinForgeText 'o Windows informa acesso à internet') } else { (Get-WinForgeText 'os nomes de sites são resolvidos') })
        # Os servidores de teste não responderam direto: comum em redes com proxy ou firewall.
        Write-WinForgeStatus -Type Success -Message (Get-WinForgeText 'A rede funciona ({0}, comum em redes com proxy); o reparo não foi necessário.' "$evidence")
        Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Se a internet estiver com problema, use Rede > Reparar rede e DNS.')

        $early = New-WinForgeResult -Kind Skipped -Detail (Get-WinForgeText 'a rede funciona ({0})' "$evidence") -Title $title
        if ($PassThru) { $early }
        Exit-WinForgeAction -Embedded:$Embedded -Result $early
        return
    }

    # Sem nenhuma rede conectada, não há o que reparar: os resets não ligam o Wi-Fi nem o cabo, podem atrapalhar uma VPN
    # e só pediriam um reinício à toa.
    if ($Embedded -and $false -eq (Test-WinForgeNetworkConnected)) {
        Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'O PC não está ligado a nenhuma rede; o reparo de rede não foi executado.')

        $early = New-WinForgeResult -Kind Skipped -Detail (Get-WinForgeText 'nenhuma rede conectada') -Title $title
        if ($PassThru) { $early }
        Exit-WinForgeAction -Embedded:$Embedded -Result $early
        return
    }

    # Como manutenção (o Otimizar), com a rede funcionando, só o DNS é limpo, o que não corta nada. Funciona quando os
    # testes passam, quando os nomes de sites resolvem ou quando o Windows diz que há internet (numa rede com proxy, o
    # acesso direto aos servidores de teste é bloqueado). Com a VPN ou a Área de Trabalho Remota, o motivo é esse.
    $hold = ""

    if ($Embedded -and $limited) {
        # Sem ninguém olhando, numa rede que pede login: renovar o IP e refazer o Winsock não fazem o login, e pediriam um
        # reinício à toa.
        $hold = (Get-WinForgeText 'a rede limita o acesso (pode pedir login numa página)')
    }
    elseif ($Embedded -and $Force -and ($connectivity.Ok -or $connectivity.DnsOk -or $windowsInternet -eq $true)) {
        $hold = Get-WinForgeNetworkHoldReason
        if ([string]::IsNullOrWhiteSpace($hold)) { $hold = (Get-WinForgeText 'a internet funciona') }
    }
    elseif ($Embedded) {
        # Sem ninguém para confirmar, o reparo completo também não derruba a Área de Trabalho Remota (numa rede local, ela
        # funciona mesmo com a internet fora) nem uma VPN: fica a limpeza do DNS, e o motivo.
        $hold = Get-WinForgeNetworkHoldReason
    }

    if (-not [string]::IsNullOrWhiteSpace($hold)) {
        $early = Invoke-WinForgeNetworkDnsOnly -Title $title -Reason $hold

        if ($PassThru) { $early }
        Exit-WinForgeAction -Embedded:$Embedded -Result $early
        return
    }

    # O que o reparo faz, em palavras; os comandos em si ficam nos detalhes técnicos.
    Write-WinForgeSection -Title (Get-WinForgeText 'O que o reparo faz')
    $repairCommands = @(Get-WinForgeNetworkRepairCommands -HasStaticIp:$hasStaticIp -HasManualDns:$hasManualDns -NoDhcp:$noDhcp)
    $commandIds = @($repairCommands | ForEach-Object { [string]$_.Id })

    if ($commandIds -contains "renew") {
        Write-WinForgeStatus -Type Info -Notice -Message (Get-WinForgeText 'Pede um endereço novo ao roteador.')
    }

    Write-WinForgeStatus -Type Info -Notice -Message (Get-WinForgeText 'Apaga a memória de endereços de sites (DNS).')
    $resets = $(if ($commandIds -contains "ipreset") { (Get-WinForgeText 'Winsock e TCP/IP') } else { "Winsock" })
    Write-WinForgeStatus -Type Info -Notice -Message (Get-WinForgeText 'Refaz as configurações de rede do Windows ({0}); pede reiniciar.' "$resets")

    foreach ($command in $repairCommands) {
        Write-WinForgeCommand -Command "$($command.FilePath -replace '\.exe$', '') $($command.Arguments -join ' ')"
    }

    Write-Host ""

    if ($staticIp.Unknown) {
        Write-WinForgeStatus -Type Warning -Notice -Message (Get-WinForgeText 'Não foi possível conferir se algum adaptador usa IP fixo: liberar/renovar IP e redefinir TCP/IP foram removidos para não apagar uma configuração manual.')
    }
    elseif ($hasStaticIp -and $noDhcp) {
        Write-WinForgeStatus -Type Warning -Notice -Message (Get-WinForgeText 'IP fixo em {0}: liberar/renovar IP e redefinir TCP/IP ficaram de fora (o IP fixo não vem do roteador, e o reset o apagaria).' "$(Join-WinForgeList -Items @($staticIp.Interfaces))")
    }
    elseif ($hasStaticIp) {
        # O IP fixo de outro adaptador (o do VirtualBox, o do WSL) não impede renovar o IP dos automáticos.
        Write-WinForgeStatus -Type Warning -Notice -Message (Get-WinForgeText 'IP fixo em {0}: redefinir TCP/IP ficou de fora para não apagar essa configuração; liberar e renovar o IP só mexem nos adaptadores automáticos.' "$(Join-WinForgeList -Items @($staticIp.Interfaces))")
    }

    # Com IP estático, o reset de TCP/IP já saiu, e o aviso acima já diz isso.
    if ($hasManualDns -and -not $hasStaticIp) {
        $fixed = @($manualDns | Where-Object { -not $_.Unknown } | ForEach-Object { $_.Alias })
        $unread = @($manualDns | Where-Object { $_.Unknown } | ForEach-Object { $_.Alias })
        $where = @()
        if ($fixed.Count -gt 0) { $where += (Get-WinForgeText 'DNS fixo em {0}' "$(Join-WinForgeList -Items $fixed)") }
        if ($unread.Count -gt 0) { $where += (Get-WinForgeText 'DNS que não pôde ser lido em {0}' "$(Join-WinForgeList -Items $unread)") }
        # A frase começa pelo nome do que foi achado: em inglês ele vem em minúscula ("static DNS on Wi-Fi").
        $whereText = $where -join '; '
        $whereText = $whereText.Substring(0, 1).ToUpper() + $whereText.Substring(1)
        Write-WinForgeStatus -Type Warning -Notice -Message (Get-WinForgeText '{0}: redefinir TCP/IP foi removido para não apagar esses servidores DNS.' "$whereText")
    }

    # Pela Área de Trabalho Remota ou por uma VPN, a pessoa perde justamente a conexão por onde está: o aviso vem antes da
    # pergunta.
    if (-not $Embedded) {
        if ([string]$env:SESSIONNAME -like "RDP-*") {
            Write-WinForgeStatus -Type Warning -Notice -Message (Get-WinForgeText 'Este PC está sendo usado pela Área de Trabalho Remota: o reparo derruba a conexão, e o acesso remoto pode não voltar sozinho.')
        }
        elseif (-not [string]::IsNullOrWhiteSpace((Get-WinForgeNetworkHoldReason))) {
            Write-WinForgeStatus -Type Warning -Notice -Message (Get-WinForgeText 'Há uma VPN ligada: o reparo pode desconectá-la.')
        }
    }

    Write-WinForgeStatus -Type Warning -Notice -Message (Get-WinForgeText 'A conexão pode cair por alguns instantes. O reset do Winsock pode afetar VPN e alguns antivírus.')

    # Com a internet funcionando, só a tela do reparo chega aqui (dentro de um fluxo, ele parou antes): a pergunta vem a seguir.
    if ($connectivity.Ok) {
        Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'A internet parece funcionar normalmente: só continue se tiver um problema de rede.')
    }
    elseif ($false -eq (Test-WinForgeNetworkConnected)) {
        # Sem nenhuma rede, o problema é o Wi-Fi desligado, o cabo solto ou o modo avião, e nenhum comando do reparo liga isso.
        Write-WinForgeStatus -Type Warning -Notice -Message (Get-WinForgeText 'O PC não está ligado a nenhuma rede: ligue o Wi-Fi ou conecte o cabo; o reparo não faz isso.')
    }
    elseif ($limited) {
        # Numa rede que pede login, "o reparo é indicado" mandaria a pessoa para o caminho errado.
        Write-WinForgeStatus -Type Warning -Notice -Message (Get-WinForgeText 'O Windows indica que a rede limita o acesso (em geral, um Wi-Fi que pede login numa página, como o de hotel e aeroporto): o reparo não resolve isso. Abra o navegador e entre na página da rede.')
    }
    elseif ($windowsInternet -eq $true -or $connectivity.DnsOk) {
        # Os testes diretos falham numa rede com proxy ou firewall que os bloqueia, e a internet funciona assim mesmo: o
        # reparo não é indicado só por eles.
        $evidence = $(if ($windowsInternet -eq $true) { (Get-WinForgeText 'o Windows informa acesso à internet') } else { (Get-WinForgeText 'os nomes de sites são resolvidos') })
        Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Os testes diretos falharam, mas {0} (comum em redes com proxy ou firewall): só continue se os sites não abrirem.' "$evidence")
    }
    else {
        Write-WinForgeStatus -Type Info -Notice -Message (Get-WinForgeText 'A internet não está funcionando: o reparo é indicado.')
    }

    if ($proxy.Text) {
        # Um proxy que não é da empresa, com a internet funcionando só em alguns programas, pode ter sido posto por um programa.
        Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Há um proxy configurado, que o reparo não muda: confira em Configurações, Rede e Internet, Proxy.')
    }

    Write-Host ""

    # O reparo derruba a conexão e redefine o Winsock (o que pode afetar VPN e antivírus): a resposta padrão é sempre Não,
    # e o aviso acima diz quando ele é indicado. Na Manutenção, o usuário já confirmou.
    if (-not $Embedded -and -not (Confirm-WinForgeAction (Get-WinForgeText 'Reparar a rede agora?') -DefaultKey N -YesLabel (Get-WinForgeText 'Reparar') -NoLabel (Get-WinForgeText 'Cancelar'))) {
        Write-Host ""
        Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'Operação cancelada.')

        $early = New-WinForgeResult -Kind Skipped -Detail (Get-WinForgeText 'cancelado pelo usuário') -Title $title
        if ($PassThru) { $early }
        Exit-WinForgeAction -Embedded:$Embedded -Result $early
        return
    }

    try {
        $steps = @()
        $needsRestart = $false

        try {
            foreach ($command in $repairCommands) {
                $step = Invoke-WinForgeNetworkCommand -Title $command.Title -FilePath $command.FilePath -Arguments $command.Arguments
                $steps += $step

                # Só os resets de Winsock e TCP/IP pedem reinício, e só se tiverem funcionado.
                if ($command.NeedsRestart -and $step.Kind -ne "Failed") {
                    $needsRestart = $true
                }
            }
        }
        finally {
            Write-Progress -Activity (Get-WinForgeText 'Reparando a rede') -Completed
        }

        $failedSteps = @($steps | Where-Object { $_.Kind -eq "Failed" })
        $restart = @{ RebootRequired = $needsRestart }

        # O que rodou entra no Histórico de mudanças (o Winsock e o TCP/IP refeitos mudam a pilha de rede do Windows).
        $ran = @($steps | Where-Object { $_.Kind -ne "Failed" } | ForEach-Object { [string]$_.Etapa })
        if ($ran.Count -gt 0) { [void](Add-WinForgeChange -Action $title -Text (Join-WinForgeList -Items $ran)) }

        if ($steps.Count -gt 0 -and $failedSteps.Count -eq $steps.Count) {
            # Nada foi executado com sucesso: conferir a conexão só faria esperar, e não há o que reiniciar.
            $final = New-WinForgeResult -Kind Failed -Detail (Get-WinForgeText 'nenhum dos comandos funcionou') -Title $title
            [void](Set-WinForgeResultView -Result $final -Headline (Get-WinForgeText 'O reparo não funcionou') -Note (Get-WinForgeText 'Nenhum comando funcionou; o código de cada um está no resumo.'))
            Write-Host ""
            Write-WinForgeStatus -Type Error -Message (Get-WinForgeText 'Nenhum comando do reparo funcionou.')
        }
        else {
            Write-Progress -Activity $title -Status (Get-WinForgeText 'conferindo se a conexão voltou (pode levar até um minuto)')

            try { $after = Wait-WinForgeInternet } finally { Write-Progress -Activity $title -Completed }

            Write-WinForgeSection -Title (Get-WinForgeText 'Depois do reparo')
            Write-WinForgeKeyValue -Label (Get-WinForgeText 'Acesso por IP (sem DNS)') -Value (Get-WinForgeIpReachText -Connectivity $after) -LabelWidth 26
            Write-WinForgeKeyValue -Label (Get-WinForgeText 'Resolução de DNS') -Value $(if ($after.DnsOk) { (Get-WinForgeText 'Funciona') } else { (Get-WinForgeText 'Falhou') }) -LabelWidth 26
            Write-Host ""

            if ($failedSteps.Count -gt 0) {
                $failedText = $(if ($failedSteps.Count -eq 1) { (Get-WinForgeText '1 comando falhou') } else { (Get-WinForgeText '{0} comandos falharam' "$($failedSteps.Count)") })
                $final = New-WinForgeResult -Kind Warning -Detail $failedText -Title $title -Data $restart
                Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'Reparo concluído com alertas: {0}.' "$failedText")

                # Na janela, o título diz se a conexão voltou (o que a pessoa quer saber); a frase, o que não deu certo.
                $failedNames = Join-WinForgeList -Items @($failedSteps | ForEach-Object { [string]$_.Etapa })
                [void](Set-WinForgeResultView -Result $final -Headline $(if ($after.Ok) { (Get-WinForgeText 'A conexão está funcionando') } else { (Get-WinForgeText 'A conexão ainda não voltou') }) `
                        -Note $(if ($failedSteps.Count -eq 1) { (Get-WinForgeText '{0} não deu certo; o código está no resumo.' "$failedNames") } else { (Get-WinForgeText '{0} não deram certo; os códigos estão no resumo.' "$failedNames") }))
            }
            elseif (-not $after.Ok) {
                $final = New-WinForgeResult -Kind Warning -Detail (Get-WinForgeText 'a conexão ainda não voltou') -Title $title -Data $restart
                Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'Os comandos foram executados, mas a conexão ainda não voltou.{0}' "$(if ($needsRestart) { (Get-WinForgeText ' Depois de reiniciar, teste de novo.') } else { (Get-WinForgeText ' Reinicie o PC e teste de novo.') })")

                # Na janela, o que fazer agora: sem nenhuma rede, ligar o Wi-Fi ou o cabo (o botão abre as configurações de
                # rede); com a rede, reiniciar e testar de novo (o pedido de reinício já está na frase).
                if ($false -eq (Test-WinForgeNetworkConnected)) {
                    [void](Set-WinForgeNoNetworkView -Result $final)
                }
                else {
                    [void](Set-WinForgeResultView -Result $final -Headline (Get-WinForgeText 'A conexão ainda não voltou') -Note (Get-WinForgeText 'Reinicie o PC e teste de novo; se continuar, confira o roteador ou fale com a operadora.'))
                }
            }
            else {
                $final = New-WinForgeResult -Kind Ok -Title $title -Data $restart
                Write-WinForgeStatus -Type Success -Message (Get-WinForgeText 'Reparo concluído; a conexão está funcionando.')
                [void](Set-WinForgeResultView -Result $final -Headline (Get-WinForgeText 'Rede reparada') -Note (Get-WinForgeText 'A conexão está funcionando.'))
            }

            if ($needsRestart -and $Embedded) {
                Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Reinicie o PC para o reparo terminar de valer.')
            }
            elseif ($needsRestart) {
                # O Winsock e o TCP/IP refeitos só terminam de valer depois de reiniciar, como a Microsoft indica: a tela oferece
                # ali mesmo (Depois como padrão), como o Corrigir o Windows Update.
                Request-WinForgeRestartOffer -Reason (Get-WinForgeText 'Reiniciar agora termina o reparo da rede.') `
                    -Comment (Get-WinForgeText 'Reinicialização solicitada pelo WinForge após o reparo de rede.') `
                    -DeclinedMessage (Get-WinForgeText 'O PC não foi reiniciado. O reparo termina de valer quando você reiniciar.') `
                    -Fallback (Get-WinForgeText 'Reinicie o PC para o reparo terminar de valer.')
            }
        }
    }
    catch {
        Write-Host ""
        Write-WinForgeStatus -Type Error -Message (Get-WinForgeText 'Falha durante o reparo de rede: {0}' "$($_.Exception.Message)")
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
        [string]$Url = "https://speed.cloudflare.com/__up",
        [string]$WarmupUrl = "https://speed.cloudflare.com/__down?bytes=0"
    )

    $client = New-WinForgeSpeedHttpClient -TimeoutSeconds 40

    try {
        # A conexão abre antes do relógio, como no download: resolver o nome, abrir a conexão e negociar o TLS não é
        # velocidade de envio, e numa internet rápida esse tempo, todo no primeiro envio, derrubava o resultado. Um pedido
        # vazio ao mesmo servidor deixa a conexão aberta para os envios. Se ele falhar, os envios tentam do mesmo jeito
        # (e dizem o erro deles).
        try {
            $warm = $client.GetAsync($WarmupUrl, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead)
            Wait-WinForgeTask -Task $warm -TimeoutSeconds 10
            $warm.Result.Dispose()
        }
        catch {
            Write-Verbose "Abertura da conexão do upload: $($_.Exception.Message)"
        }

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

    if ($DownloadMbps -lt 10) { $lines += [PSCustomObject]@{ Type = "Warning"; Message = (Get-WinForgeText 'Internet lenta: vídeos em HD podem travar e downloads demoram.') } }
    elseif ($DownloadMbps -lt 50) { $lines += [PSCustomObject]@{ Type = "Info"; Message = (Get-WinForgeText 'Boa para vídeo em HD, aulas e chamadas de vídeo.') } }
    elseif ($DownloadMbps -le 200) { $lines += [PSCustomObject]@{ Type = "Info"; Message = (Get-WinForgeText 'Boa para vídeo em 4K e vários aparelhos ao mesmo tempo.') } }
    else { $lines += [PSCustomObject]@{ Type = "Info"; Message = (Get-WinForgeText 'Internet rápida.') } }

    if ($null -ne $LatencyMs -and [double]$LatencyMs -gt 100) {
        $lines += [PSCustomObject]@{ Type = "Warning"; Message = (Get-WinForgeText 'A latência está alta: jogos online e chamadas podem atrasar.') }
    }

    $lines += [PSCustomObject]@{ Type = "Info"; Message = (Get-WinForgeText 'Se você contratou mais que isso, repita o teste com cabo, perto do roteador; se continuar abaixo, fale com a operadora.') }

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
    Enter-WinForgeAction -Title (Get-WinForgeText 'Testar velocidade da internet')

    # Sem nenhuma rede, perguntar e medir só terminaria num erro técnico ("host desconhecido"): a faixa diz o que fazer,
    # como no teste de conectividade.
    if ($false -eq (Test-WinForgeNetworkConnected)) {
        Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'O PC não está ligado a nenhuma rede: ligue o Wi-Fi ou conecte o cabo (e confira o modo avião).')
        Exit-WinForgeAction -Result (Set-WinForgeNoNetworkView -Result (New-WinForgeResult -Kind Warning -Detail (Get-WinForgeText 'o PC não está ligado a nenhuma rede')))
        return
    }

    # Uma medida aproximada: não substitui o teste da operadora, mas mostra gargalos claros.
    Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Mede a latência e a velocidade até o servidor da Cloudflare mais próximo.')

    # Numa conexão limitada (celular roteado, chip, rede marcada como limitada), os 35 MB saem da franquia: o padrão vira Não.
    $metered = Test-WinForgeMeteredConnection

    if ($metered) {
        Write-WinForgeStatus -Type Warning -Notice -Message (Get-WinForgeText 'A conexão com a internet é limitada (plano de dados): o teste usa até cerca de 35 MB da sua franquia.')
    }
    else {
        Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'O teste usa até cerca de 35 MB de dados. Evite em conexões com franquia (4G/5G).')
    }

    Write-Host ""

    if (-not (Confirm-WinForgeAction (Get-WinForgeText 'Iniciar o teste agora?') -DefaultKey $(if ($metered) { "N" } else { "S" }) -YesLabel (Get-WinForgeText 'Testar') -NoLabel (Get-WinForgeText 'Cancelar'))) {
        Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'Operação cancelada.')
        Exit-WinForgeAction -Result (New-WinForgeResult -Kind Skipped -Detail (Get-WinForgeText 'cancelado pelo usuário'))
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
            Write-Progress -Activity (Get-WinForgeText 'Testando a velocidade') -Status (Get-WinForgeText 'latência e download (até 15 s)') -PercentComplete 0

            try {
                $download = Measure-WinForgeDownload
            }
            catch {
                $downloadProblem = Get-WinForgeSpeedProblem -Exception $_.Exception
                Write-WinForgeStatus -Type Error -Message (Get-WinForgeText 'O download falhou: {0}' "$downloadProblem")
            }

            Write-Progress -Activity (Get-WinForgeText 'Testando a velocidade') -Status (Get-WinForgeText 'upload (até 8 s)') -PercentComplete 60

            try {
                $upload = Measure-WinForgeUpload
            }
            catch {
                $uploadProblem = Get-WinForgeSpeedProblem -Exception $_.Exception
                Write-WinForgeStatus -Type Error -Message (Get-WinForgeText 'O upload falhou: {0}' "$uploadProblem")
            }
        }
        finally {
            Write-Progress -Activity (Get-WinForgeText 'Testando a velocidade') -Completed
        }

        if ($null -eq $download -and $null -eq $upload) {
            Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Verifique a conexão, o DNS, o firewall, a VPN ou um bloqueio do endereço de teste.')
            $final = Set-WinForgeSpeedFailureView -Result (New-WinForgeResult -Kind Failed -Detail (Get-WinForgeText 'não foi possível medir: {0}' "$downloadProblem")) -Problem $downloadProblem
        }
        else {
            Write-WinForgeSection -Title (Get-WinForgeText 'Resultado')

            $downloadText = (Get-WinForgeText 'não foi possível medir')
            $uploadText = (Get-WinForgeText 'não foi possível medir')
            $latency = $(if ($null -ne $download) { Get-WinForgeJsonValue -Object $download -Name "LatencyMs" -Default $null } else { $null })
            $latencyText = ""

            if ($null -ne $latency) {
                $latencyText = "$(Format-WinForgeNumber -Value $latency -Decimals 0) ms"
                Write-WinForgeKeyValue -Label (Get-WinForgeText 'Latência') -Value $latencyText
            }

            # Vírgula decimal, como no resto do WinForge ("94 Mbps", "8,5 Mbps"). Quanto foi baixado e em quanto tempo fica
            # numa linha à parte, que a janela deixa só nos detalhes técnicos.
            if ($null -ne $download) {
                $downloadText = Format-WinForgeSpeedMbps -Mbps $download.Mbps
                Write-WinForgeKeyValue -Label (Get-WinForgeText 'Download') -Value $downloadText
                Write-Host (Get-WinForgeText '      {0} baixados em {1} s' "$(Format-WinForgeBytes -Bytes $download.Bytes)" "$(Format-WinForgeNumber -Value $download.Seconds -Decimals 2)") -ForegroundColor DarkGray
            }
            else {
                Write-WinForgeKeyValue -Label (Get-WinForgeText 'Download') -Value $downloadText
            }

            if ($null -ne $upload) {
                $uploadText = Format-WinForgeSpeedMbps -Mbps $upload.Mbps
                Write-WinForgeKeyValue -Label (Get-WinForgeText 'Upload') -Value $uploadText
                Write-Host (Get-WinForgeText '      {0} enviados em {1} s' "$(Format-WinForgeBytes -Bytes $upload.Bytes)" "$(Format-WinForgeNumber -Value $upload.Seconds -Decimals 2)") -ForegroundColor DarkGray
            }
            else {
                Write-WinForgeKeyValue -Label (Get-WinForgeText 'Upload') -Value $uploadText
            }

            # O que os números querem dizer, para quem não sabe se 40 Mbps é muito ou pouco.
            if ($null -ne $download -and $download.Mbps -gt 0) {
                Write-Host ""
                Write-WinForgeSpeedVerdict -DownloadMbps $download.Mbps -LatencyMs $latency
            }

            if ($null -eq $download) {
                # Na janela, o título diz que o download não foi medido; a frase, o upload e o motivo.
                $final = New-WinForgeResult -Kind Warning -Detail (Get-WinForgeText 'o download falhou: {0}' "$downloadProblem")
                [void](Set-WinForgeResultView -Result $final -Headline (Get-WinForgeText 'O download não foi medido') `
                        -Note (Get-WinForgeText 'Upload de {0}; o download falhou: {1}.' "$uploadText" "$(([string]$downloadProblem).Trim().TrimEnd('.'))"))
            }
            elseif ($null -eq $upload) {
                # O download, o número que mais importa, continua no título; a frase diz que o upload não foi medido.
                $final = New-WinForgeResult -Kind Warning -Detail (Get-WinForgeText 'o upload falhou: {0}' "$uploadProblem")
                [void](Set-WinForgeResultView -Result $final -Headline (Get-WinForgeText '{0} de download' "$downloadText") `
                        -Note (Get-WinForgeText 'O upload não foi medido: {0}.' "$(([string]$uploadProblem).Trim().TrimEnd('.'))"))
            }
            elseif ($download.Mbps -le 0 -or $upload.Mbps -le 0) {
                Write-Host ""
                Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'Uma das medições retornou zero. Repita o teste ou verifique a conexão.')
                $final = New-WinForgeResult -Kind Warning -Detail (Get-WinForgeText 'uma das medições retornou zero')
            }
            else {
                # Na ordem da tela: latência, download e upload.
                $final = New-WinForgeResult -Kind Ok -Detail (Get-WinForgeText '{0}download {1}, upload {2}' "$(if ($latencyText) { (Get-WinForgeText 'latência {0}, ' "$latencyText") })" "$downloadText" "$uploadText")

                # Na janela, o título traz o download; a frase, o upload, a latência e o que isso quer dizer (sem a dica de
                # repetir com cabo, que fica no resumo). Internet lenta ou latência alta deixam a faixa amarela.
                $reading = @((Get-WinForgeSpeedVerdict -DownloadMbps $download.Mbps -LatencyMs $latency).Lines)
                $meaning = @($reading | Select-Object -First ($reading.Count - 1))
                $slow = @($meaning | Where-Object { $_.Type -eq "Warning" }).Count -gt 0
                [void](Set-WinForgeResultView -Result $final -Headline (Get-WinForgeText '{0} de download' "$downloadText") -Tone $(if ($slow) { "Warn" } else { "" }) `
                        -Note (Get-WinForgeText 'Upload de {0}{1}. {2}' "$uploadText" "$(if ($latencyText) { (Get-WinForgeText ' e latência de {0}' "$latencyText") })" "$(@($meaning | ForEach-Object { $_.Message }) -join ' ')"))
            }
        }
    }
    catch {
        Write-Host ""
        Write-WinForgeStatus -Type Error -Message (Get-WinForgeText 'O teste de velocidade falhou: {0}' "$(Get-WinForgeSpeedProblem -Exception $_.Exception)")
        Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Verifique a conexão, o DNS, o firewall, a VPN ou um bloqueio do endereço de teste.')
        $problem = Get-WinForgeSpeedProblem -Exception $_.Exception
        $final = Set-WinForgeSpeedFailureView -Result (New-WinForgeResult -Kind Failed -Detail $problem) -Problem $problem
    }

    Exit-WinForgeAction -Result $final
}


function Set-WinForgeSpeedFailureView {
    # A faixa do teste que não mediu nada: o motivo e, quando ele não é o proxy que pede autenticação, o botão do teste de
    # conectividade, que diz se a internet responde. Devolve o próprio resultado.
    param (
        [Parameter(Mandatory)]$Result,
        [string]$Problem = ""
    )

    $reason = ([string]$Problem).Trim().TrimEnd('.')
    $headline = (Get-WinForgeText 'Não foi possível medir a velocidade')

    if (-not $reason) {
        return (Set-WinForgeResultView -Result $Result -Headline $headline -Note (Get-WinForgeText 'Verifique a conexão, o DNS, o firewall, a VPN ou um bloqueio do endereço de teste.'))
    }

    $note = "$($reason.Substring(0, 1).ToUpper())$($reason.Substring(1))."

    if ($Problem -eq $script:WinForgeProxyAuthProblem) {
        return (Set-WinForgeResultView -Result $Result -Headline $headline -Note $note)
    }

    return (Set-WinForgeResultView -Result $Result -Headline $headline -Note $note -Next "network.ping" -NextLabel (Get-WinForgeText 'Testar a conexão'))
}


# ---------------------------------------------------------------------------
# Informações de rede
# ---------------------------------------------------------------------------

function ConvertFrom-WinForgeWlanInterfaces {
    <#
    As interfaces Wi-Fi conectadas na saída de "netsh wlan show interfaces", em inglês, português ou espanhol. Cada linha
    é "Campo : valor" e uma interface começa no campo Name (Nome, Nombre); o SSID só aparece quando ela está conectada. Os acentos
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

        if ($key -in @("Name", "Nome", "Nombre")) {
            $current = [ordered]@{ Name = $value; Ssid = ""; Signal = $null; Radio = ""; Band = ""; Channel = "" }
            $interfaces.Add($current)
            continue
        }

        if ($null -eq $current) { continue }

        switch -Regex ($key) {
            '^SSID$' { $current.Ssid = $value }
            '^(Signal|Sinal|Se.{1,3}al)$' { if ($value -match '^([0-9]+)\s*%') { $current.Signal = [int]$Matches[1] } }
            '^(Radio type|Tipo de r.{1,3}dio|Tipo de radio)$' { $current.Radio = $value }
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
        '802\.11ax' { $(if ([string]$Wifi.Band -match '^6') { (Get-WinForgeText 'Wi-Fi 6E') } else { "Wi-Fi 6" }) }
        '802\.11ac' { "Wi-Fi 5" }
        '802\.11n' { "Wi-Fi 4" }
        default { "" }
    }

    $parts = @()
    if ($Wifi.Radio) { $parts += $(if ($generation) { "$($Wifi.Radio) ($generation)" } else { [string]$Wifi.Radio }) }

    $band = @(@([string]$Wifi.Band, $(if ($Wifi.Channel) { (Get-WinForgeText 'canal {0}' "$($Wifi.Channel)") })) | Where-Object { $_ }) -join ", "
    if ($band) { $parts += $band }

    return ($parts -join " · ")
}


function Get-WinForgeNetworkCategoryText {
    param ([string]$Category)

    switch ($Category) {
        # Com o que o Windows quer dizer com cada um: "pública" numa rede de casa assusta quem não sabe que é o mais seguro.
        "Public" { return (Get-WinForgeText 'Pública (o PC não aparece para os outros aparelhos da rede)') }
        "Private" { return (Get-WinForgeText 'Privada (o PC aparece para os outros aparelhos da rede)') }
        "DomainAuthenticated" { return (Get-WinForgeText 'Domínio (rede da empresa)') }
        default { return "" }
    }
}


function Show-WinForgeNetworkInfo {
    Enter-WinForgeAction -Title (Get-WinForgeText 'Informações de rede')

    # Uma tela de informação não tem faixa; só a de quando não há rede nenhuma (o que fazer, com o botão das configurações).
    $final = $null

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
            Write-WinForgeSection -Title (Get-WinForgeText 'Adaptadores')
            Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'Nenhum adaptador ativo encontrado (Wi-Fi desligado, cabo solto ou modo avião).')
            $final = Set-WinForgeNoNetworkView -Result (New-WinForgeResult -Kind Warning -Detail (Get-WinForgeText 'o PC não está ligado a nenhuma rede'))
        }

        $shownConfigs = New-Object System.Collections.Generic.List[object]

        # Uma seção por adaptador ativo, com tudo o que é dele junto: a placa, o Wi-Fi, a rede, o IP e o DNS.
        foreach ($adapter in $activeAdapters) {
            $name = [string]$adapter.Name
            Write-WinForgeSection -Title $name

            Write-WinForgeKeyValue -Label (Get-WinForgeText 'Adaptador') -Value ([string](Get-WinForgeJsonValue -Object $adapter -Name "InterfaceDescription" -Default "")) -LabelWidth 18
            # O Windows escreve "866.7 Mbps"; no WinForge, a vírgula decimal ("866,7 Mbps").
            $linkSpeed = ([string](Get-WinForgeJsonValue -Object $adapter -Name "LinkSpeed" -Default "")) -replace '^([0-9]+)\.([0-9]+)(?= )', '$1,$2'
            Write-WinForgeKeyValue -Label (Get-WinForgeText 'Velocidade do link') -Value $linkSpeed -LabelWidth 18
            Write-WinForgeKeyValue -Label "MAC" -Value ([string](Get-WinForgeJsonValue -Object $adapter -Name "MacAddress" -Default "")) -LabelWidth 18

            $wifi = @($wifiList | Where-Object { $_.Name -eq $name }) | Select-Object -First 1
            $weak = $false

            if ($null -ne $wifi) {
                $weak = $null -ne $wifi.Signal -and $wifi.Signal -lt 40
                Write-WinForgeKeyValue -Label (Get-WinForgeText 'Rede Wi-Fi') -Value $wifi.Ssid -LabelWidth 18
                if ($null -ne $wifi.Signal) { Write-WinForgeKeyValue -Label (Get-WinForgeText 'Sinal') -Value "$($wifi.Signal)%" -LabelWidth 18 -Level $(if ($weak) { "Warn" } else { "Normal" }) }
                $link = Get-WinForgeWifiLinkText -Wifi $wifi
                if ($link) { Write-WinForgeKeyValue -Label (Get-WinForgeText 'Conexão Wi-Fi') -Value $link -LabelWidth 18 }
            }

            $netProfile = @($profiles | Where-Object { [string](Get-WinForgeJsonValue -Object $_ -Name "InterfaceAlias" -Default "") -eq $name }) | Select-Object -First 1

            # Privada (o PC aparece para os outros da rede) ou pública (fica oculto): o que o Windows decidiu ao conectar.
            if ($null -ne $netProfile) {
                $category = Get-WinForgeNetworkCategoryText -Category ([string](Get-WinForgeJsonValue -Object $netProfile -Name "NetworkCategory" -Default ""))
                if ($category) { Write-WinForgeKeyValue -Label (Get-WinForgeText 'Tipo de rede') -Value $category -LabelWidth 18 }
            }

            $config = @($ipConfigurations | Where-Object { [string]$_.InterfaceAlias -eq $name }) | Select-Object -First 1

            if ($null -ne $config) {
                $shownConfigs.Add($config)
                Write-WinForgeNetworkConfig -Config $config
            }
            else {
                Write-WinForgeKeyValue -Label "IP" -Value $(if ($ipUnreadable) { (Get-WinForgeText 'não foi possível ler') } else { (Get-WinForgeText 'nenhum endereço') }) -LabelWidth 18
            }

            if ($weak) {
                Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'O sinal do Wi-Fi está fraco: aproxime o PC do roteador ou use cabo.')
            }
        }

        # Interfaces com IP sem um adaptador ativo na lista (uma VPN, por exemplo) também aparecem.
        foreach ($config in @($ipConfigurations | Where-Object { -not $shownConfigs.Contains($_) })) {
            Write-WinForgeSection -Title ([string]$config.InterfaceAlias)
            Write-WinForgeNetworkConfig -Config $config
        }

        if ($ipUnreadable) {
            Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'O Windows não informou a configuração IP (endereços, gateway e DNS).')
        }

        if ($wifiNeedsLocation) {
            Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Para ver a rede Wi-Fi e o sinal, ative a Localização em Configurações, Privacidade e segurança, Localização.')
        }

        Write-WinForgeSection -Title (Get-WinForgeText 'Internet')

        $proxy = Get-WinForgeProxySettings
        Write-WinForgeKeyValue -Label (Get-WinForgeText 'Proxy') -Value $(if ($proxy.Text) { $proxy.Text } else { (Get-WinForgeText 'nenhum') }) -LabelWidth 18

        if ($activeAdapters.Count -eq 0) {
            # Sem adaptador ativo a consulta só esperaria o tempo limite.
            Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Sem adaptador de rede ativo; a consulta do IP público foi ignorada.')
        }
        else {
            try {
                Enable-WinForgeTls12
                $publicIp = ([string](Invoke-RestMethod -Uri "https://api.ipify.org" -TimeoutSec 5)).Trim()

                # Rede com página de login (Wi-Fi de hotel ou de aeroporto) responde com HTML em vez do endereço.
                if (Test-WinForgeIpAddressText -Text $publicIp) {
                    Write-WinForgeKeyValue -Label (Get-WinForgeText 'IP público') -Value (Get-WinForgeText '{0} (consultado em api.ipify.org)' "$publicIp") -LabelWidth 18
                }
                else {
                    Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'A consulta do IP público devolveu algo que não é um endereço IP (comum em Wi-Fi com página de login, como o de hotel).')
                }
            }
            catch {
                Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'Não foi possível consultar o IP público (sem internet ou bloqueio).')
            }
        }
    }
    catch {
        Write-WinForgeStatus -Type Error -Message (Get-WinForgeText 'Ocorreu um erro ao listar informações de rede: {0}' "$($_.Exception.Message)")
        $final = $null
    }

    Exit-WinForgeAction -Result $final
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

    if (@($ipv4).Count -gt 0) { Write-WinForgeKeyValue -Label (Get-WinForgeText 'IPv4') -Value (@($ipv4) -join ", ") -LabelWidth 18 }
    if (@($ipv6).Count -gt 0) { Write-WinForgeKeyValue -Label (Get-WinForgeText 'IPv6') -Value (@($ipv6) -join ", ") -LabelWidth 18 }
    if (@($gateway).Count -gt 0) { Write-WinForgeKeyValue -Label (Get-WinForgeText 'Gateway') -Value (@($gateway) -join ", ") -LabelWidth 18 }

    $index = Get-WinForgeJsonValue -Object $Config -Name "InterfaceIndex" -Default $null
    if ($null -eq $index) { return }

    # Cada família só com os endereços dela (um IPv4 nunca na linha do IPv6), e o provedor quando é um conhecido ("1.1.1.1,
    # 1.0.0.1 (Cloudflare)"): depois de uma troca pelo WinForge, a pessoa reconhece o que escolheu.
    foreach ($family in @(@{ Name = "IPv4"; Label = (Get-WinForgeText 'DNS IPv4') }, @{ Name = "IPv6"; Label = (Get-WinForgeText 'DNS IPv6') })) {
        $servers = @(
            Get-DnsClientServerAddress -InterfaceIndex $index -AddressFamily $family.Name -ErrorAction SilentlyContinue |
            ForEach-Object { $_.ServerAddresses } |
            Where-Object { $_ -and (([string]$_).Contains(":") -eq ($family.Name -eq "IPv6")) -and -not (Test-WinForgeDnsPlaceholder -Address $_) } |
            Select-Object -Unique
        )

        if ($servers.Count -eq 0) { continue }

        $provider = Get-WinForgeDnsProviderName -Servers $servers
        Write-WinForgeKeyValue -Label $family.Label -Value $(if ($provider) { "$($servers -join ', ') ($provider)" } else { $servers -join ", " }) -LabelWidth 18
    }
}


Export-ModuleMember -Function *
