# Rede: troca rápida do servidor DNS (com como desfazer) e relatório de Wi-Fi.
#
# A troca de DNS guarda, antes de mexer, o DNS original de cada adaptador em dns-backup.json. "Desfazer a troca de
# DNS" devolve exatamente o que havia (automático ou os endereços fixos que a pessoa já usava), separado por família:
# o IPv4 e o IPv6 de um adaptador podem ser um fixo e o outro automático. Se depois da troca o PC deixar de resolver
# nomes, a própria ação desfaz sozinha.


# ---------------------------------------------------------------------------
# Provedores
# ---------------------------------------------------------------------------

function Get-WinForgeDnsProviders {
    # Servidores públicos conhecidos: endereços IPv4 e IPv6 publicados pelos próprios provedores.
    return @(
        [PSCustomObject]@{
            Id          = "cloudflare"
            Name        = "Cloudflare"
            Description = "Rápido e focado em privacidade (1.1.1.1)"
            Servers     = @("1.1.1.1", "1.0.0.1", "2606:4700:4700::1111", "2606:4700:4700::1001")
        },
        [PSCustomObject]@{
            Id          = "google"
            Name        = "Google"
            Description = "Muito disponível e estável (8.8.8.8)"
            Servers     = @("8.8.8.8", "8.8.4.4", "2001:4860:4860::8888", "2001:4860:4860::8844")
        },
        [PSCustomObject]@{
            Id          = "quad9"
            Name        = "Quad9"
            Description = "Bloqueia sites maliciosos conhecidos (9.9.9.9)"
            Servers     = @("9.9.9.9", "149.112.112.112", "2620:fe::fe", "2620:fe::9")
        },
        [PSCustomObject]@{
            # Filtra conteúdo: é escolha de quem quer o bloqueio, nunca a sugestão em destaque.
            Id          = "cloudflare-familia"
            Name        = "Cloudflare para famílias"
            Description = "Bloqueia sites adultos e maliciosos (1.1.1.3)"
            Servers     = @("1.1.1.3", "1.0.0.3", "2606:4700:4700::1113", "2606:4700:4700::1003")
            Filters     = $true
        }
    )
}


function Measure-WinForgeDnsLatency {
    <#
    Tempo de resposta de um servidor DNS, em ms: a mediana de consultas feitas direto a ele (sem o cache do Windows nem o
    arquivo hosts). $null quando ele não responde deste PC (rede que bloqueia DNS externo, sem internet) ou quando o
    Windows não consegue consultar um servidor específico. O primeiro nome sem resposta já basta: insistir só faria
    esperar o tempo limite outra vez.
    #>
    param (
        [Parameter(Mandatory)][string]$Server,
        [string[]]$Names = @("www.google.com", "www.microsoft.com", "www.wikipedia.org")
    )

    $times = New-Object System.Collections.Generic.List[double]

    foreach ($name in $Names) {
        try {
            $watch = [System.Diagnostics.Stopwatch]::StartNew()
            [void](Resolve-DnsName -Name $name -Server $Server -Type A -DnsOnly -NoHostsFile -QuickTimeout -ErrorAction Stop)
            $watch.Stop()
            $times.Add($watch.Elapsed.TotalMilliseconds)
        }
        catch {
            if ($times.Count -eq 0) { return $null }
        }
    }

    $sorted = @($times | Sort-Object)
    return [int][Math]::Round($sorted[[int][Math]::Floor($sorted.Count / 2)])
}


function Get-WinForgeDnsPrimaryServer {
    # O servidor que o Windows consulta primeiro: o primeiro IPv4 da lista (o IPv6 pode nem ter rota), ou o primeiro.
    param ([AllowEmptyCollection()][string[]]$Servers = @())

    $list = @($Servers | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $v4 = @($list | Where-Object { -not $_.Contains(":") })

    if ($v4.Count -gt 0) { return $v4[0] }
    if ($list.Count -gt 0) { return $list[0] }
    return $null
}


function Get-WinForgeDnsLatencyText {
    # "12 ms" para quem respondeu; "sem resposta deste PC" para quem foi consultado e não respondeu, e só quando outros
    # responderam (sem nenhuma resposta, a medição inteira não aconteceu e nada é dito). Quem não foi consultado: vazio.
    param (
        [hashtable]$Latency,
        [string]$Server,
        [bool]$Measured
    )

    if (-not $Measured -or [string]::IsNullOrWhiteSpace($Server) -or -not $Latency.ContainsKey($Server)) { return "" }
    if ($null -ne $Latency[$Server]) { return "$($Latency[$Server]) ms" }
    return "sem resposta deste PC"
}


function Get-WinForgeDnsSuggestion {
    <#
    Qual opção vai em destaque no menu, pelo tempo medido: Index (-1 = nenhuma) e Reason. Sem medição, a primeira, como
    sempre. Um provedor que filtra conteúdo nunca é sugerido. Para o destaque não pular entre execuções por 1 ou 2 ms, o
    primeiro medido só perde para um claramente mais rápido (mais de 5 ms e mais de 20%). Nenhum destaque quando nenhum
    provedor respondeu (a rede bloqueia DNS externo: trocar deixaria o PC sem resolver nomes) ou quando o DNS atual já é
    tão rápido quanto o melhor deles (o roteador costuma responder do cache em poucos ms). Com adaptadores de DNS
    diferentes, vale o mais lento: a troca vale para todos, e ajuda se ajudar a algum.
    #>
    param (
        [Parameter(Mandatory)][object[]]$Providers,
        [Parameter(Mandatory)][AllowEmptyCollection()][hashtable]$Latency,
        [AllowEmptyCollection()][string[]]$Current = @()
    )

    $measured = @($Latency.Values | Where-Object { $null -ne $_ }).Count -gt 0
    if (-not $measured) { return [PSCustomObject]@{ Index = 0; Reason = "NotMeasured"; BestMs = $null; CurrentMs = $null } }

    $index = -1
    $best = $null

    for ($i = 0; $i -lt $Providers.Count; $i++) {
        if ([bool](Get-WinForgeJsonValue -Object $Providers[$i] -Name "Filters" -Default $false)) { continue }

        $ms = $Latency[[string]$Providers[$i].Servers[0]]
        if ($null -eq $ms) { continue }

        if ($null -eq $best -or ($ms -lt $best - 5 -and $ms -lt $best * 0.8)) {
            $best = $ms
            $index = $i
        }
    }

    if ($null -eq $best) { return [PSCustomObject]@{ Index = -1; Reason = "Blocked"; BestMs = $null; CurrentMs = $null } }

    $currentTimes = @($Current | Where-Object { $_ } | ForEach-Object { $Latency[[string]$_] } | Where-Object { $null -ne $_ } | Sort-Object -Descending)

    if ($currentTimes.Count -gt 0 -and $currentTimes[0] -le $best + [Math]::Max(5.0, $best * 0.1)) {
        return [PSCustomObject]@{ Index = -1; Reason = "CurrentFast"; BestMs = $best; CurrentMs = $currentTimes[0] }
    }

    return [PSCustomObject]@{ Index = $index; Reason = "Fastest"; BestMs = $best; CurrentMs = $null }
}


function Format-WinForgeDnsModeLatency {
    # "Automático (do roteador): 192.168.0.1, fe80::1" vira "... 192.168.0.1 (4 ms), fe80::1": o tempo ao lado do servidor
    # medido, e não no fim, onde pareceria valer para a lista toda.
    param (
        [string]$Text,
        [string]$Server,
        [string]$Value
    )

    if ([string]::IsNullOrEmpty($Value) -or [string]::IsNullOrEmpty($Server)) { return $Text }

    $pattern = '(?<![0-9A-Fa-f:.])' + [regex]::Escape($Server) + '(?![0-9A-Fa-f:.])'
    return ([regex]::new($pattern)).Replace($Text, "$Server ($Value)", 1)
}


function Get-WinForgeDnsBackupPath {
    return (Join-Path (Get-WinForgeDataPath) "dns-backup.json")
}


# ---------------------------------------------------------------------------
# Adaptadores e backup
# ---------------------------------------------------------------------------

function ConvertTo-WinForgeDnsServerList {
    # Os endereços de um valor NameServer do registro ("8.8.8.8,8.8.4.4", ou separados por espaço). Lista vazia sem valor.
    param ($Value)

    if ($null -eq $Value) { return @() }

    return @(@($Value) | ForEach-Object { [string]$_ -split '[,\s]+' } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}


function Get-WinForgeDnsAdapters {
    <#
    Os adaptadores físicos ativos (Ethernet e Wi-Fi) com o DNS de cada um: Guid, Alias, Index, Servers (os que estão em
    uso, IPv4 e IPv6, para mostrar) e Mode (Automatic = vem do roteador/DHCP, Static = endereços fixos em alguma família,
    Unknown = não deu para saber). Por família, o que foi configurado à mão (é o que se devolve ao desfazer): V4Mode e
    V4Servers, do NameServer de Tcpip, e V6Mode e V6Servers, do NameServer de Tcpip6. Os servidores que vêm do roteador
    (DHCP, ou anúncio do roteador no IPv6) não são fixos e não entram nessas listas. VPNs e adaptadores virtuais ficam de
    fora.
    #>
    try {
        $adapters = @(Get-NetAdapter -Physical -ErrorAction Stop | Where-Object { $_.Status -eq "Up" })
    }
    catch {
        return @()
    }

    return @(
        foreach ($adapter in $adapters) {
            $servers = @(
                Get-DnsClientServerAddress -InterfaceIndex $adapter.InterfaceIndex -ErrorAction SilentlyContinue |
                    ForEach-Object { $_.ServerAddresses } |
                    Where-Object { -not [string]::IsNullOrWhiteSpace($_) -and -not (Test-WinForgeDnsPlaceholder -Address $_) }
            )

            $guid = [string]$adapter.InterfaceGuid
            $v4 = Get-WinForgeRegistryValueOrNull -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$guid" -Name "NameServer"
            $v6 = Get-WinForgeRegistryValueOrNull -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters\Interfaces\$guid" -Name "NameServer"
            $v4Servers = @(ConvertTo-WinForgeDnsServerList -Value $v4)
            $v6Servers = @(ConvertTo-WinForgeDnsServerList -Value $v6)

            # O NameServer do IPv4 existe em todo adaptador com TCP/IP (vazio quando é automático): sem ele, não dá para
            # saber. O do IPv6 só existe quando alguém pôs endereços fixos.
            $v4Mode = $(if ($null -eq $v4) { "Unknown" } elseif ($v4Servers.Count -gt 0) { "Static" } else { "Automatic" })
            $v6Mode = $(if ($v6Servers.Count -gt 0) { "Static" } else { "Automatic" })

            $mode = $(if ($v4Mode -eq "Unknown") { "Unknown" } elseif ($v4Mode -eq "Static" -or $v6Mode -eq "Static") { "Static" } else { "Automatic" })

            [PSCustomObject]@{
                Guid      = $guid
                Alias     = [string]$adapter.Name
                Index     = [int]$adapter.InterfaceIndex
                Servers   = @($servers)
                Mode      = $mode
                V4Mode    = $v4Mode
                V4Servers = @($v4Servers)
                V6Mode    = $v6Mode
                V6Servers = @($v6Servers)
            }
        }
    )
}


function Get-WinForgeDnsModeText {
    param ([Parameter(Mandatory)]$Adapter)

    $servers = if (@($Adapter.Servers).Count -gt 0) { @($Adapter.Servers) -join ", " } else { "nenhum" }

    switch ($Adapter.Mode) {
        "Automatic" { return "Automático (do roteador): $servers" }
        "Static"    { return "Fixo: $servers" }
        default     { return $servers }
    }
}


function ConvertFrom-WinForgeDnsBackupEntry {
    <#
    Uma entrada do backup (lida do JSON) com o modo e os servidores de cada família. $null sem Guid.
    O backup antigo (versão 1) só tinha um modo para o adaptador e os servidores em uso, IPv4 e IPv6 misturados, sem
    dizer quais eram fixos. Dele, "Static" devolve como fixos os endereços IPv4 (que é o que a pessoa costuma configurar) e
    deixa o IPv6 no automático: fixar endereços IPv6 que podiam vir do roteador seria pior do que perder um IPv6 fixo.
    "Unknown" continua desconhecido.
    #>
    param ($Entry)

    $guid = [string](Get-WinForgeJsonValue -Object $Entry -Name "Guid" -Default "")

    if ([string]::IsNullOrWhiteSpace($guid)) { return $null }

    $mode = [string](Get-WinForgeJsonValue -Object $Entry -Name "Mode" -Default "Unknown")
    $servers = @(@(Get-WinForgeJsonValue -Object $Entry -Name "Servers" -Default @()) | ForEach-Object { [string]$_ } | Where-Object { $_ })
    $v4Mode = [string](Get-WinForgeJsonValue -Object $Entry -Name "V4Mode" -Default "")

    if ($v4Mode) {
        $v4Servers = @(@(Get-WinForgeJsonValue -Object $Entry -Name "V4Servers" -Default @()) | ForEach-Object { [string]$_ } | Where-Object { $_ })
        $v6Mode = [string](Get-WinForgeJsonValue -Object $Entry -Name "V6Mode" -Default "Unknown")
        $v6Servers = @(@(Get-WinForgeJsonValue -Object $Entry -Name "V6Servers" -Default @()) | ForEach-Object { [string]$_ } | Where-Object { $_ })
    }
    elseif ($mode -eq "Automatic") {
        $v4Mode = "Automatic"; $v4Servers = @(); $v6Mode = "Automatic"; $v6Servers = @()
    }
    elseif ($mode -eq "Static") {
        $v4Servers = @($servers | Where-Object { $_ -notlike "*:*" })
        $v6Servers = @()
        $v6Mode = "Automatic"
        $v4Mode = $(if ($v4Servers.Count -gt 0) { "Static" } else { "Automatic" })

        # Sem nenhum IPv4 na lista, o que era fixo só podia ser o IPv6.
        if ($v4Servers.Count -eq 0) {
            $v6Servers = @($servers | Where-Object { $_ -like "*:*" })
            if ($v6Servers.Count -gt 0) { $v6Mode = "Static" }
        }
    }
    else {
        $v4Mode = "Unknown"; $v4Servers = @(); $v6Mode = "Unknown"; $v6Servers = @()
    }

    return [PSCustomObject]@{
        Guid      = $guid
        Alias     = [string](Get-WinForgeJsonValue -Object $Entry -Name "Alias" -Default "")
        Mode      = $mode
        Servers   = @($servers)
        V4Mode    = $v4Mode
        V4Servers = @($v4Servers)
        V6Mode    = $v6Mode
        V6Servers = @($v6Servers)
    }
}


function Read-WinForgeDnsBackup {
    <#
    O backup do DNS original: lista de Guid, Alias, Mode, Servers e o modo e os servidores de cada família (V4Mode,
    V4Servers, V6Mode, V6Servers). Vazio quando não existe, está estragado sem cópia anterior ou é de outro formato.
    -Status devolve Status (o de Read-WinForgeStateFile: "Unreadable" = existe, mas não deu para ler agora) e Entries.
    #>
    param ([switch]$Status)

    $read = [PSCustomObject]@{ Status = "Unreadable"; Document = $null }

    try {
        $read = Read-WinForgeStateFile -Path (Get-WinForgeDnsBackupPath)
    }
    catch {
        # Fica como ilegível: quem grava desiste.
    }

    $entries = @()
    $document = $read.Document

    if ($null -ne $document -and [string](Get-WinForgeJsonValue -Object $document -Name "Format" -Default "") -eq "WinForge.DnsBackup") {
        $entries = @(
            foreach ($entry in @(Get-WinForgeJsonValue -Object $document -Name "Adapters" -Default @())) {
                $converted = ConvertFrom-WinForgeDnsBackupEntry -Entry $entry
                if ($null -ne $converted) { $converted }
            }
        )
    }

    if ($Status) {
        return [PSCustomObject]@{ Status = [string]$read.Status; Entries = @($entries) }
    }

    return @($entries)
}


function Save-WinForgeDnsBackup {
    <#
    Guarda o DNS atual dos adaptadores que ainda não têm backup. O que já foi guardado nunca é sobrescrito: o backup é
    sempre o DNS de ANTES da primeira troca, mesmo que a pessoa troque de provedor várias vezes. Gravação atômica, dentro
    da trava dos arquivos de estado. Um backup que existe mas não pôde ser lido faz a função lançar erro sem gravar nada
    (gravar por cima perderia o DNS original): quem chama não troca o DNS.
    #>
    param (
        [Parameter(Mandatory)]
        [object[]]$Adapters
    )

    [void](Invoke-WinForgeStateLock -ScriptBlock {
            $current = Read-WinForgeDnsBackup -Status

            if ($current.Status -eq "Unreadable") {
                throw "o backup do DNS de antes existe, mas não pôde ser lido agora ($(Get-WinForgeDnsBackupPath)); para não perdê-lo, nada foi alterado. Tente de novo em instantes."
            }

            $existing = @($current.Entries)
            $entries = @($existing)

            foreach ($adapter in $Adapters) {
                if (@($existing | Where-Object { $_.Guid -eq $adapter.Guid }).Count -eq 0) {
                    $entries += [PSCustomObject]@{
                        Guid      = $adapter.Guid
                        Alias     = $adapter.Alias
                        Mode      = $adapter.Mode
                        Servers   = @($adapter.Servers)
                        V4Mode    = [string](Get-WinForgeJsonValue -Object $adapter -Name "V4Mode" -Default "Unknown")
                        V4Servers = @(Get-WinForgeJsonValue -Object $adapter -Name "V4Servers" -Default @())
                        V6Mode    = [string](Get-WinForgeJsonValue -Object $adapter -Name "V6Mode" -Default "Unknown")
                        V6Servers = @(Get-WinForgeJsonValue -Object $adapter -Name "V6Servers" -Default @())
                    }
                }
            }

            $document = [ordered]@{
                Format   = "WinForge.DnsBackup"
                Version  = 2
                SavedAt  = (Get-Date).ToString("o", [System.Globalization.CultureInfo]::InvariantCulture)
                Adapters = @($entries | ForEach-Object {
                        [ordered]@{
                            Guid      = $_.Guid
                            Alias     = $_.Alias
                            Mode      = $_.Mode
                            Servers   = @($_.Servers)
                            V4Mode    = $_.V4Mode
                            V4Servers = @($_.V4Servers)
                            V6Mode    = $_.V6Mode
                            V6Servers = @($_.V6Servers)
                        }
                    })
            }

            Write-WinForgeStateJson -Path (Get-WinForgeDnsBackupPath) -InputObject $document -Depth 5
        })
}


function Remove-WinForgeDnsBackup {
    # Apaga o backup depois de desfeito, com a cópia anterior que a gravação atômica guarda (.bak): sem ela, um backup
    # estragado no futuro poderia voltar com o DNS de uma troca antiga.
    $path = Get-WinForgeDnsBackupPath

    Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath "$path.bak" -Force -ErrorAction SilentlyContinue
}


function Set-WinForgeAdapterDns {
    # Define os servidores do adaptador; sem endereços, volta ao automático.
    param (
        [Parameter(Mandatory)]
        $Adapter,

        [string[]]$Servers = @()
    )

    if (@($Servers).Count -eq 0) {
        Set-DnsClientServerAddress -InterfaceIndex $Adapter.Index -ResetServerAddresses -ErrorAction Stop
    }
    else {
        Set-DnsClientServerAddress -InterfaceIndex $Adapter.Index -ServerAddresses @($Servers) -ErrorAction Stop
    }
}


function Test-WinForgeDnsWorking {
    # Depois de uma troca, o DNS novo precisa resolver nomes de verdade. Tenta duas vezes, com uma pausa.
    param (
        [string[]]$Names = @("www.microsoft.com", "www.google.com")
    )

    for ($attempt = 0; $attempt -lt 2; $attempt++) {
        Clear-DnsClientCache -ErrorAction SilentlyContinue

        foreach ($name in $Names) {
            if (Test-WinForgeDnsResolution -Name $name) {
                return $true
            }
        }

        Start-Sleep -Seconds 2
    }

    return $false
}


function Restore-WinForgeDnsFromBackup {
    <#
    Devolve cada adaptador do backup ao DNS original: primeiro as duas famílias voltam ao automático
    (-ResetServerAddresses) e depois só as famílias que eram fixas recebem os endereços delas. Assim um IPv4 fixo não
    leva junto, como fixos, os servidores IPv6 que vinham do roteador. Devolve Restored (quantos voltaram), Missing
    (adaptadores do backup que não estão ativos agora), Failed (os que deram erro) e Unknown (os que não foram tocados
    porque o DNS de antes não pôde ser lido na hora do backup).
    #>
    param (
        [Parameter(Mandatory)]
        [object[]]$Backup,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Adapters
    )

    $restored = 0
    $missing = @()
    $failed = @()
    $unknown = @()

    foreach ($entry in $Backup) {
        $name = $(if ($entry.Alias) { $entry.Alias } else { $entry.Guid })
        $adapter = @($Adapters) | Where-Object { $_.Guid -eq $entry.Guid } | Select-Object -First 1

        if ($null -eq $adapter) {
            $missing += $name
            continue
        }

        # Sem saber o que havia, qualquer escolha seria um palpite (fixar os servidores em uso, ou o automático).
        $v4Mode = [string](Get-WinForgeJsonValue -Object $entry -Name "V4Mode" -Default "Unknown")
        $v6Mode = [string](Get-WinForgeJsonValue -Object $entry -Name "V6Mode" -Default "Unknown")

        if ($v4Mode -notin @("Automatic", "Static") -or $v6Mode -notin @("Automatic", "Static")) {
            $unknown += $name
            continue
        }

        $static = @()
        if ($v4Mode -eq "Static") { $static += @(Get-WinForgeJsonValue -Object $entry -Name "V4Servers" -Default @()) }
        if ($v6Mode -eq "Static") { $static += @(Get-WinForgeJsonValue -Object $entry -Name "V6Servers" -Default @()) }
        $static = @($static | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | ForEach-Object { ([string]$_).Trim() })

        # O backup fica numa pasta em que qualquer programa da conta grava, e o desfazer roda como Administrador: só
        # endereços IP de verdade viram servidores DNS. Um texto qualquer deixa o adaptador sem tocar.
        $parsed = $null
        if (@($static | Where-Object { -not [System.Net.IPAddress]::TryParse($_, [ref]$parsed) }).Count -gt 0) {
            $unknown += $name
            continue
        }

        try {
            Set-WinForgeAdapterDns -Adapter $adapter

            if ($static.Count -gt 0) {
                Set-WinForgeAdapterDns -Adapter $adapter -Servers $static
            }

            $restored++
        }
        catch {
            $failed += "$($adapter.Alias): $($_.Exception.Message)"
        }
    }

    return [PSCustomObject]@{ Restored = $restored; Missing = @($missing); Failed = @($failed); Unknown = @($unknown) }
}


# ---------------------------------------------------------------------------
# Trocar e desfazer
# ---------------------------------------------------------------------------

function Set-WinForgeDnsProvider {
    $title = "Trocar o servidor DNS"

    Enter-WinForgeAction -Title $title

    $final = New-WinForgeResult -Kind Ok -Title $title

    try {
        if (-not (Test-WinForgeElevation -Reason "Trocar o DNS exige privilégios de Administrador.")) {
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Failed -Detail "requer Administrador" -Title $title)
            return
        }

        $adapters = @(Get-WinForgeDnsAdapters)

        if ($adapters.Count -eq 0) {
            Write-WinForgeStatus -Type Error -Message "Nenhum adaptador de rede ativo (Ethernet ou Wi-Fi) foi encontrado."
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Failed -Detail "sem adaptador ativo" -Title $title)
            return
        }

        $providers = @(Get-WinForgeDnsProviders)

        # O tempo de resposta do DNS atual e de cada opção, medido agora deste PC: é ele que diz qual DNS abre os sites
        # mais rápido aqui, e não a fama do provedor. Um por servidor (dois adaptadores com o mesmo DNS medem uma vez).
        # Dois públicos seguidos sem resposta indicam uma rede que bloqueia DNS externo: os outros não são consultados,
        # para o menu não esperar o tempo limite de cada um.
        $latency = @{}
        $currentServers = @($adapters | ForEach-Object { Get-WinForgeDnsPrimaryServer -Servers @($_.Servers) } | Where-Object { $_ } | Select-Object -Unique)
        $targets = @(
            @($currentServers | ForEach-Object { [PSCustomObject]@{ Server = $_; Label = "DNS atual ($_)"; Public = $false } }) +
            @($providers | ForEach-Object { [PSCustomObject]@{ Server = $_.Servers[0]; Label = "$($_.Name) ($($_.Servers[0]))"; Public = $true } })
        )
        $publicMisses = 0

        try {
            for ($i = 0; $i -lt $targets.Count; $i++) {
                $target = $targets[$i]
                if ($target.Public -and $publicMisses -ge 2) { break }

                # Um público que já foi medido como DNS atual de um adaptador (o 8.8.8.8, por exemplo) conta do mesmo jeito.
                if (-not $latency.ContainsKey($target.Server)) {
                    Write-Progress -Activity "Medindo o tempo de resposta do DNS" -Status $target.Label -PercentComplete ([int](100 * $i / $targets.Count))
                    $latency[$target.Server] = Measure-WinForgeDnsLatency -Server $target.Server
                }

                if ($target.Public) { $publicMisses = $(if ($null -eq $latency[$target.Server]) { $publicMisses + 1 } else { 0 }) }
            }
        }
        finally {
            Write-Progress -Activity "Medindo o tempo de resposta do DNS" -Completed
        }

        $measured = @($latency.Values | Where-Object { $null -ne $_ }).Count -gt 0
        $suggestion = Get-WinForgeDnsSuggestion -Providers $providers -Latency $latency -Current $currentServers

        Write-WinForgeSection -Title "DNS atual"

        foreach ($adapter in $adapters) {
            $primary = Get-WinForgeDnsPrimaryServer -Servers @($adapter.Servers)
            $text = Format-WinForgeDnsModeLatency -Text (Get-WinForgeDnsModeText -Adapter $adapter) -Server $primary -Value (Get-WinForgeDnsLatencyText -Latency $latency -Server $primary -Measured $measured)
            Write-WinForgeKeyValue -Label $adapter.Alias -Value $text
        }

        Write-Host ""

        # O DNS traduz nomes de sites em endereços; os tempos são medidos agora, deste PC. Uma rede que bloqueia DNS externo
        # (comum em empresas e escolas) deixaria o PC sem abrir sites com outro DNS. Com o atual já tão rápido quanto o
        # melhor, trocar só vale por outro motivo (o filtro para famílias, por exemplo).
        switch ($suggestion.Reason) {
            "NotMeasured" {
                Write-WinForgeStatus -Type Info -Message "Um DNS mais rápido abre as páginas com menos espera."
            }
            "Blocked" {
                Write-WinForgeStatus -Type Warning -Notice -Message "Nenhum DNS público respondeu: a rede parece bloquear DNS externo, e trocar pode deixar o PC sem sites. Mantenha o atual."
            }
            "CurrentFast" {
                Write-WinForgeStatus -Type Info -Message "O DNS atual já é tão rápido quanto o melhor da lista ($($suggestion.CurrentMs) ms): trocar não deixa as páginas mais rápidas."
            }
            default {
                Write-WinForgeStatus -Type Info -Message "Quanto menor o tempo, mais rápido. Em destaque, o mais rápido entre os que não filtram conteúdo."
            }
        }

        $options = @()

        for ($i = 0; $i -lt $providers.Count; $i++) {
            $provider = $providers[$i]
            $time = Get-WinForgeDnsLatencyText -Latency $latency -Server $provider.Servers[0] -Measured $measured
            $description = $(if ($time) { "$($provider.Description) · $time" } else { $provider.Description })
            $options += @{ Key = [string]($i + 1); Label = $provider.Name; Description = $description; Accent = ($i -eq $suggestion.Index) }
        }

        $options += @{ Key = "A"; Label = "Automático"; Description = "O DNS do roteador ou da operadora" }
        $options += @{ Key = "X"; Label = "Cancelar"; Exit = $true }

        $answer = Read-WinForgeChoice -Message "Qual DNS usar?" -Options $options -DefaultKey "X" -ShowMenu `
            -TextPrompt "DNS (número, A = automático, X = cancelar; ENTER = cancelar)"

        $servers = $null
        $choiceName = ""

        if ($answer -ieq "A") {
            $servers = @()
            $choiceName = "Automático"
        }
        elseif ($answer -match "^[0-9]+$" -and [int]$answer -ge 1 -and [int]$answer -le $providers.Count) {
            $provider = $providers[[int]$answer - 1]
            $servers = @($provider.Servers)
            $choiceName = $provider.Name
        }

        if ($null -eq $servers) {
            Write-WinForgeStatus -Type Warning -Message "Operação cancelada. Nada foi alterado."
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Skipped -Detail "cancelado pelo usuário" -Title $title)
            return
        }

        # Um adaptador cujo DNS atual não pôde ser lido não é trocado: sem saber o que havia, não haveria como desfazer.
        $changeable = @($adapters | Where-Object { $_.Mode -ne "Unknown" })
        $changed = @()
        $errors = @()
        $notChanged = @()

        foreach ($adapter in @($adapters | Where-Object { $_.Mode -eq "Unknown" })) {
            $notChanged += $adapter.Alias
            Write-WinForgeStatus -Type Warning -Message "$($adapter.Alias): não foi possível ler o DNS que ele usa agora; para poder desfazer depois, ele não foi alterado."
        }

        if ($changeable.Count -eq 0) {
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Failed -Detail "nenhum adaptador foi alterado: o DNS atual não pôde ser lido" -Title $title)
            return
        }

        Save-WinForgeDnsBackup -Adapters $changeable
        Write-WinForgeStatus -Type Info -Message "Para voltar ao DNS de antes, use Rede > Desfazer a troca de DNS."

        foreach ($adapter in $changeable) {
            try {
                Set-WinForgeAdapterDns -Adapter $adapter -Servers $servers
                $changed += $adapter
                Write-WinForgeStatus -Type Success -Message "$($adapter.Alias): DNS $choiceName"
            }
            catch {
                $errors += "$($adapter.Alias): $($_.Exception.Message)"
                $notChanged += $adapter.Alias
                Write-WinForgeStatus -Type Error -Message "$($adapter.Alias): não foi possível trocar ($($_.Exception.Message))"
            }
        }

        if ($changed.Count -eq 0) {
            $final = New-WinForgeResult -Kind Failed -Detail "nenhum adaptador foi alterado" -Title $title
        }
        else {
            Write-Progress -Activity $title -Status "conferindo se o novo DNS resolve nomes"

            try { $working = Test-WinForgeDnsWorking } finally { Write-Progress -Activity $title -Completed }

            if ($working) {
                Write-WinForgeStatus -Type Success -Message "O novo DNS está funcionando."
                [void](Add-WinForgeChange -Action "DNS" -Text $(if ($servers.Count -eq 0) { "DNS automático" } else { "trocado para $choiceName" }) -Undo @{ Kind = "dns" })
                $final = if ($notChanged.Count -eq 1) {
                    New-WinForgeResult -Kind Warning -Detail "1 adaptador não foi alterado ($($notChanged[0]))" -Title $title
                }
                elseif ($notChanged.Count -gt 1) {
                    New-WinForgeResult -Kind Warning -Detail "$($notChanged.Count) adaptadores não foram alterados ($($notChanged -join ', '))" -Title $title
                }
                else {
                    # Na janela, o título diz qual DNS ficou; a frase, como voltar (ou, no automático, de onde ele vem).
                    Set-WinForgeResultView -Result (New-WinForgeResult -Kind Ok -Detail $(if ($servers.Count -eq 0) { "DNS automático" } else { "DNS $choiceName" }) -Title $title) `
                        -Headline $(if ($servers.Count -eq 0) { "DNS automático" } else { "DNS trocado para $choiceName" }) `
                        -Note $(if ($servers.Count -eq 0) { "O DNS vem do roteador ou da operadora." } else { "O novo DNS está funcionando. Para voltar ao de antes, use Desfazer a troca de DNS." })
                }
            }
            else {
                Write-WinForgeStatus -Type Warning -Message "O novo DNS não funcionou neste PC; voltando ao de antes."

                # Volta ao DNS de logo antes desta troca (o que estava em uso e resolvia nomes), lido no começo da ação, e
                # não ao original guardado no backup: depois de uma troca que deu certo, o original pode ser justamente o
                # DNS que não funcionava, e a volta deixaria o PC sem resolver nomes. O backup continua com o original,
                # para o "Desfazer a troca de DNS".
                $undo = Restore-WinForgeDnsFromBackup -Backup @($changed) -Adapters $adapters

                if ($undo.Failed.Count -eq 0 -and $undo.Unknown.Count -eq 0) {
                    Write-WinForgeStatus -Type Success -Message "O DNS de antes foi restaurado."
                    $final = Set-WinForgeResultView -Result (New-WinForgeResult -Kind Warning -Detail "o novo DNS não resolveu nomes; desfeito" -Title $title) `
                        -Headline "O novo DNS não funcionou" -Note "O DNS de antes foi restaurado; a rede pode estar bloqueando DNS externo."
                }
                else {
                    $problems = @($undo.Failed) + @($undo.Unknown | ForEach-Object { "${_}: o DNS de antes não é conhecido (escolha Automático em Rede > Trocar o servidor DNS)" })
                    Write-WinForgeStatus -Type Error -Message "Não foi possível restaurar tudo: $($problems -join '; '). Use Rede > Desfazer a troca de DNS."
                    $final = New-WinForgeResult -Kind Failed -Detail "o novo DNS não resolveu nomes e a restauração falhou" -Title $title
                }
            }
        }
    }
    catch {
        Write-WinForgeStatus -Type Error -Message "Não foi possível trocar o DNS: $($_.Exception.Message)"
        $final = New-WinForgeResult -Kind Failed -Detail $_.Exception.Message -Title $title
    }

    Exit-WinForgeAction -Result $final
}


function Undo-WinForgeDnsChange {
    $title = "Desfazer a troca de DNS"

    Enter-WinForgeAction -Title $title

    $final = New-WinForgeResult -Kind Ok -Title $title

    try {
        if (-not (Test-WinForgeElevation -Reason "Desfazer a troca de DNS exige privilégios de Administrador.")) {
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Failed -Detail "requer Administrador" -Title $title)
            return
        }

        $read = Read-WinForgeDnsBackup -Status

        if ($read.Status -eq "Unreadable") {
            # Dizer "não há o que desfazer" seria falso: o backup existe, só não pôde ser lido agora.
            Write-WinForgeStatus -Type Error -Message "O backup do DNS de antes existe, mas não pôde ser lido agora ($(Get-WinForgeDnsBackupPath)). Nada foi alterado; tente de novo em instantes."
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Failed -Detail "o backup do DNS não pôde ser lido" -Title $title)
            return
        }

        $backup = @($read.Entries)

        if ($backup.Count -eq 0) {
            Write-WinForgeStatus -Type Info -Message "O WinForge não trocou o DNS neste PC: não há o que desfazer."
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Skipped -Detail "nenhuma troca para desfazer" -Title $title)
            return
        }

        Write-WinForgeSection -Title "DNS de antes"

        foreach ($entry in $backup) {
            Write-WinForgeKeyValue -Label $(if ($entry.Alias) { $entry.Alias } else { $entry.Guid }) -Value (Get-WinForgeDnsModeText -Adapter $entry)
        }

        Write-Host ""

        $undo = Restore-WinForgeDnsFromBackup -Backup $backup -Adapters @(Get-WinForgeDnsAdapters)

        foreach ($name in $undo.Missing) {
            Write-WinForgeStatus -Type Warning -Message "$name não está ativo agora; o DNS dele não foi restaurado."
        }

        foreach ($problem in $undo.Failed) {
            Write-WinForgeStatus -Type Error -Message $problem
        }

        foreach ($name in $undo.Unknown) {
            Write-WinForgeStatus -Type Warning -Message "$name ficou como está (o DNS de antes não era conhecido); se precisar, escolha Automático em Rede > Trocar o servidor DNS."
        }

        $restoredText = $(if ($undo.Restored -eq 1) { "1 adaptador voltou ao DNS de antes" } else { "$($undo.Restored) adaptadores voltaram ao DNS de antes" })

        if ($undo.Restored -gt 0) {
            Write-WinForgeStatus -Type Success -Message "$restoredText."
            Clear-DnsClientCache -ErrorAction SilentlyContinue
        }

        if ($undo.Failed.Count -eq 0 -and $undo.Missing.Count -eq 0) {
            # Os desconhecidos não têm como voltar: guardar o backup só repetiria o mesmo aviso.
            Remove-WinForgeDnsBackup
            Set-WinForgeChangesUndone -Kind "dns" -Key "Kind" -Value "dns"

            if ($undo.Unknown.Count -gt 0) {
                $verb = $(if ($undo.Unknown.Count -eq 1) { "não foi alterado" } else { "não foram alterados" })
                $final = New-WinForgeResult -Kind Warning -Detail "$restoredText; $(Join-WinForgeList -Items @($undo.Unknown)) $verb (o DNS de antes não era conhecido)" -Title $title
            }
            else {
                $final = Set-WinForgeResultView -Result (New-WinForgeResult -Kind Ok -Detail $restoredText -Title $title) -Headline "DNS de antes restaurado" -Note "$restoredText."
            }
        }
        else {
            Write-WinForgeStatus -Type Info -Message "O backup foi mantido para você tentar de novo."

            if ($undo.Restored -gt 0) {
                $final = New-WinForgeResult -Kind Warning -Detail "restauração parcial: $restoredText" -Title $title
            }
            elseif ($undo.Failed.Count -gt 0) {
                $final = New-WinForgeResult -Kind Failed -Detail "nenhum adaptador foi restaurado" -Title $title
            }
            else {
                # Só faltam adaptadores desligados (Wi-Fi apagado, cabo fora): não é um erro, é ligá-los e repetir.
                $final = New-WinForgeResult -Kind Warning -Detail "nenhum adaptador do backup está ativo agora; ligue-os e repita" -Title $title
            }
        }
    }
    catch {
        Write-WinForgeStatus -Type Error -Message "Não foi possível desfazer: $($_.Exception.Message)"
        $final = New-WinForgeResult -Kind Failed -Detail $_.Exception.Message -Title $title
    }

    Exit-WinForgeAction -Result $final
}


# ---------------------------------------------------------------------------
# Relatório de Wi-Fi
# ---------------------------------------------------------------------------

function Get-WinForgeWifiReportSource {
    # Onde o Windows grava o relatório mais recente do Wi-Fi.
    $programData = if ([string]::IsNullOrWhiteSpace($env:ProgramData)) { "C:\ProgramData" } else { $env:ProgramData }

    return (Join-Path $programData "Microsoft\Windows\WlanReport\wlan-report-latest.html")
}


function Show-WinForgeWifiReport {
    $title = "Relatório de Wi-Fi"

    Enter-WinForgeAction -Title $title

    $final = New-WinForgeResult -Kind Ok -Title $title

    try {
        if (-not (Test-WinForgeElevation -Reason "O relatório de Wi-Fi exige privilégios de Administrador.")) {
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Failed -Detail "requer Administrador" -Title $title)
            return
        }

        $source = Get-WinForgeWifiReportSource
        $startedAt = Get-Date

        Write-Progress -Activity $title -Status "o Windows está gerando o relatório (leva alguns segundos)"

        try { $run = Invoke-WinForgeCapture -FilePath "netsh" -Arguments @("wlan", "show", "wlanreport") } finally { Write-Progress -Activity $title -Completed }

        $fresh = (Test-Path -LiteralPath $source -PathType Leaf) -and ((Get-Item -LiteralPath $source).LastWriteTime -ge $startedAt.AddSeconds(-5))

        if (-not $fresh) {
            Write-WinForgeStatus -Type Info -Message "O Windows não gerou o relatório (código $($run.ExitCode)). Este PC pode não ter Wi-Fi, ou o serviço de Wi-Fi está parado."
            Exit-WinForgeAction -Result (Set-WinForgeResultView -Result (New-WinForgeResult -Kind Skipped -Detail "o Windows não gerou o relatório" -Title $title) `
                    -Headline "Relatório não gerado" -Note "Este PC pode não ter Wi-Fi, ou o serviço de Wi-Fi está parado.")
            return
        }

        # Na pasta dos outros relatórios, a que Sobre o WinForge > Pasta de logs e relatórios abre.
        $folder = Join-Path (Get-WinForgeDataPath) "reports"
        [void](New-Item -ItemType Directory -Path $folder -Force -ErrorAction Stop)
        $target = Join-Path $folder "Relatorio-WiFi-$((Get-Date).ToString('yyyy-MM-dd-HHmm', [System.Globalization.CultureInfo]::InvariantCulture)).html"
        Copy-Item -LiteralPath $source -Destination $target -Force -ErrorAction Stop

        Write-WinForgeStatus -Type Success -Message "Relatório gerado."
        Write-WinForgeKeyValue -Label "Arquivo" -Value $target
        $final = Set-WinForgeResultView -Result (New-WinForgeResult -Kind Ok -Detail "relatório salvo" -Title $title) -Headline "Relatório do Wi-Fi gerado" -Note "Salvo em $target."
        # O resumo no alto mostra as sessões de Wi-Fi dos últimos dias. Quedas repetidas no mesmo horário costumam vir do
        # roteador, do canal ou da distância.
        Write-WinForgeStatus -Type Info -Message "Como ler: as barras vermelhas são quedas, com o motivo logo abaixo."
        Write-Host ""

        if (Confirm-WinForgeAction -Message "Abrir o relatório agora?" -DefaultKey "S") {
            try {
                # Pelo explorer.exe, que entrega a abertura ao Explorador da sessão: o navegador abre sem os privilégios de
                # Administrador desta ação (aberto direto daqui, ele herdaria a elevação).
                Start-Process -FilePath "explorer.exe" -ArgumentList "`"$target`"" -ErrorAction Stop
            }
            catch {
                Write-WinForgeStatus -Type Warning -Message "Não foi possível abrir o relatório: $($_.Exception.Message)"
                $final = Set-WinForgeResultView -Result (New-WinForgeResult -Kind Ok -Detail "relatório salvo; não foi possível abri-lo" -Title $title) `
                    -Headline "Relatório do Wi-Fi gerado" -Note "Salvo em $target; não foi possível abri-lo daqui."
            }
        }
    }
    catch {
        Write-WinForgeStatus -Type Error -Message "Não foi possível gerar o relatório de Wi-Fi: $($_.Exception.Message)"
        $final = New-WinForgeResult -Kind Failed -Detail $_.Exception.Message -Title $title
    }

    Exit-WinForgeAction -Result $final
}


Export-ModuleMember -Function *
