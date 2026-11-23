# Rede: a troca do servidor DNS (com como desfazer), o Wi-Fi (o relatório do Windows e a senha das redes salvas) e o
# relógio (Acertar a data e a hora).
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
            Description = (Get-WinForgeText 'Rápido e focado em privacidade (1.1.1.1)')
            Servers     = @("1.1.1.1", "1.0.0.1", "2606:4700:4700::1111", "2606:4700:4700::1001")
        },
        [PSCustomObject]@{
            Id          = "google"
            Name        = "Google"
            Description = (Get-WinForgeText 'Muito disponível e estável (8.8.8.8)')
            Servers     = @("8.8.8.8", "8.8.4.4", "2001:4860:4860::8888", "2001:4860:4860::8844")
        },
        [PSCustomObject]@{
            Id          = "quad9"
            Name        = "Quad9"
            Description = (Get-WinForgeText 'Bloqueia sites maliciosos conhecidos (9.9.9.9)')
            Servers     = @("9.9.9.9", "149.112.112.112", "2620:fe::fe", "2620:fe::9")
        },
        [PSCustomObject]@{
            # Filtra conteúdo: é escolha de quem quer o bloqueio, nunca a sugestão em destaque.
            Id          = "cloudflare-familia"
            Name        = (Get-WinForgeText 'Cloudflare para famílias')
            Description = (Get-WinForgeText 'Bloqueia sites adultos e maliciosos (1.1.1.3)')
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


function Get-WinForgeDnsProviderName {
    # O provedor conhecido (Get-WinForgeDnsProviders) de uma lista de servidores DNS, pelo primeiro endereço dela:
    # "Cloudflare" para 1.1.1.1 e 1.0.0.1. Vazio quando não é de nenhum.
    param ([AllowEmptyCollection()][string[]]$Servers = @())

    $first = Get-WinForgeDnsPrimaryServer -Servers $Servers
    if ([string]::IsNullOrWhiteSpace($first)) { return "" }

    foreach ($provider in @(Get-WinForgeDnsProviders)) {
        if (@($provider.Servers | Where-Object { $_ -eq $first.Trim() }).Count -gt 0) { return [string]$provider.Name }
    }

    return ""
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
    return (Get-WinForgeText 'sem resposta deste PC')
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

    $servers = if (@($Adapter.Servers).Count -gt 0) { @($Adapter.Servers) -join ", " } else { (Get-WinForgeText 'nenhum') }

    # Um fixo de um provedor conhecido diz qual ("Fixo (Cloudflare): 1.1.1.1, ..."): depois de uma troca pelo WinForge, a
    # pessoa reconhece o que escolheu.
    $provider = $(if ($Adapter.Mode -eq "Static") { Get-WinForgeDnsProviderName -Servers @($Adapter.Servers) } else { "" })

    switch ($Adapter.Mode) {
        "Automatic" { return (Get-WinForgeText 'Automático (do roteador): {0}' "$servers") }
        "Static"    { return $(if ($provider) { (Get-WinForgeText 'Fixo ({0}): {1}' "$provider" "$servers") } else { (Get-WinForgeText 'Fixo: {0}' "$servers") }) }
        default     { return $servers }
    }
}


function Test-WinForgeDnsAlready {
    <#
    Se o adaptador (Get-WinForgeDnsAdapters) já usa o DNS escolhido: sem endereços, o automático nas duas famílias; com
    eles, os mesmos endereços fixos, na mesma ordem, no IPv4 e no IPv6. Trocar para o que já está em uso não muda nada, e
    anotaria uma mudança no Histórico de mudanças.
    #>
    param (
        [Parameter(Mandatory)]$Adapter,
        [AllowEmptyCollection()][string[]]$Servers = @()
    )

    if (@($Servers).Count -eq 0) { return ([string]$Adapter.Mode -eq "Automatic") }

    $same = {
        param ($Mode, $Current, $Wanted)
        if (@($Wanted).Count -eq 0) { return ([string]$Mode -eq "Automatic") }
        $have = @(@($Current) | Where-Object { $_ } | ForEach-Object { ([string]$_).Trim().ToLowerInvariant() }) -join ","
        $want = @(@($Wanted) | ForEach-Object { ([string]$_).Trim().ToLowerInvariant() }) -join ","
        return ([string]$Mode -eq "Static" -and $have -eq $want)
    }

    $v4 = @($Servers | Where-Object { -not ([string]$_).Contains(":") })
    $v6 = @($Servers | Where-Object { ([string]$_).Contains(":") })

    return ((& $same $Adapter.V4Mode $Adapter.V4Servers $v4) -and (& $same $Adapter.V6Mode $Adapter.V6Servers $v6))
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
                throw (Get-WinForgeText 'o backup do DNS de antes existe, mas não pôde ser lido agora ({0}); para não perdê-lo, nada foi alterado. Tente de novo em instantes.' "$(Get-WinForgeDnsBackupPath)")
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
    $title = (Get-WinForgeText 'Trocar o servidor DNS')

    Enter-WinForgeAction -Title $title

    $final = New-WinForgeResult -Kind Ok -Title $title

    try {
        if (-not (Test-WinForgeElevation -Reason (Get-WinForgeText 'Trocar o DNS exige privilégios de Administrador.'))) {
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Failed -Detail (Get-WinForgeText 'requer Administrador') -Title $title)
            return
        }

        $adapters = @(Get-WinForgeDnsAdapters)

        if ($adapters.Count -eq 0) {
            # Como no teste de conectividade: sem Wi-Fi nem cabo, não é um erro do WinForge, é ligar um deles.
            Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'Nenhum adaptador de rede ativo (Ethernet ou Wi-Fi) foi encontrado.')
            Exit-WinForgeAction -Result (Set-WinForgeResultView -Result (New-WinForgeResult -Kind Warning -Detail (Get-WinForgeText 'sem adaptador ativo') -Title $title) `
                    -Headline (Get-WinForgeText 'Nenhum Wi-Fi ou cabo conectado') -Note (Get-WinForgeText 'Ligue o Wi-Fi ou conecte o cabo; confira também o modo avião.') `
                    -Next "NetworkSettings" -NextLabel (Get-WinForgeText 'Abrir as configurações de rede'))
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
            @($currentServers | ForEach-Object { [PSCustomObject]@{ Server = $_; Label = (Get-WinForgeText 'DNS atual ({0})' "$_"); Public = $false } }) +
            @($providers | ForEach-Object { [PSCustomObject]@{ Server = $_.Servers[0]; Label = "$($_.Name) ($($_.Servers[0]))"; Public = $true } })
        )
        $publicMisses = 0

        try {
            for ($i = 0; $i -lt $targets.Count; $i++) {
                $target = $targets[$i]
                if ($target.Public -and $publicMisses -ge 2) { break }

                # Um público que já foi medido como DNS atual de um adaptador (o 8.8.8.8, por exemplo) conta do mesmo jeito.
                if (-not $latency.ContainsKey($target.Server)) {
                    Write-Progress -Activity (Get-WinForgeText 'Medindo o tempo de resposta do DNS') -Status $target.Label -PercentComplete ([int](100 * $i / $targets.Count))
                    $latency[$target.Server] = Measure-WinForgeDnsLatency -Server $target.Server
                }

                if ($target.Public) { $publicMisses = $(if ($null -eq $latency[$target.Server]) { $publicMisses + 1 } else { 0 }) }
            }
        }
        finally {
            Write-Progress -Activity (Get-WinForgeText 'Medindo o tempo de resposta do DNS') -Completed
        }

        $measured = @($latency.Values | Where-Object { $null -ne $_ }).Count -gt 0
        $suggestion = Get-WinForgeDnsSuggestion -Providers $providers -Latency $latency -Current $currentServers

        # Num PC do domínio de uma empresa, o DNS dela é o que acha os servidores da empresa (o login, as pastas e as
        # impressoras da rede), e um DNS público não os conhece: nada fica em destaque, e o aviso diz por quê.
        $system = @(Get-WinForgeCimOrNull -ClassName "Win32_ComputerSystem") | Select-Object -First 1

        if ($null -ne $system -and [bool](Get-WinForgeJsonValue -Object $system -Name "PartOfDomain" -Default $false)) {
            $suggestion = [PSCustomObject]@{ Index = -1; Reason = "Domain"; BestMs = $null; CurrentMs = $null }
        }

        Write-WinForgeSection -Title (Get-WinForgeText 'DNS atual')

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
                Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Um DNS mais rápido abre as páginas com menos espera.')
            }
            "Blocked" {
                Write-WinForgeStatus -Type Warning -Notice -Message (Get-WinForgeText 'Nenhum DNS público respondeu: a rede parece bloquear DNS externo, e trocar pode deixar o PC sem sites. Mantenha o atual.')
            }
            "Domain" {
                Write-WinForgeStatus -Type Warning -Notice -Message (Get-WinForgeText 'Este PC faz parte do domínio de uma empresa: o DNS dela é o que encontra os servidores da empresa, e trocá-lo pode impedir o login e o acesso à rede. Mantenha o atual.')
            }
            "CurrentFast" {
                Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'O DNS atual já é tão rápido quanto o melhor da lista ({0} ms): trocar não deixa as páginas mais rápidas.' "$($suggestion.CurrentMs)")
            }
            default {
                Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Quanto menor o tempo, mais rápido. Em destaque, o mais rápido entre os que não filtram conteúdo.')
            }
        }

        $options = @()

        for ($i = 0; $i -lt $providers.Count; $i++) {
            $provider = $providers[$i]
            $time = Get-WinForgeDnsLatencyText -Latency $latency -Server $provider.Servers[0] -Measured $measured
            $description = $(if ($time) { "$($provider.Description) · $time" } else { $provider.Description })
            $options += @{ Key = [string]($i + 1); Label = $provider.Name; Description = $description; Accent = ($i -eq $suggestion.Index) }
        }

        $options += @{ Key = "A"; Label = (Get-WinForgeText 'Automático'); Description = (Get-WinForgeText 'O DNS do roteador ou da operadora') }
        $options += @{ Key = "X"; Label = (Get-WinForgeText 'Cancelar'); Exit = $true }

        $answer = Read-WinForgeChoice -Message (Get-WinForgeText 'Qual DNS usar?') -Options $options -DefaultKey "X" -ShowMenu `
            -TextPrompt (Get-WinForgeText 'DNS (número, A = automático, X = cancelar; ENTER = cancelar)')

        $servers = $null
        $choiceName = ""

        if ($answer -ieq "A") {
            $servers = @()
            $choiceName = (Get-WinForgeText 'Automático')
        }
        elseif ($answer -match "^[0-9]+$" -and [int]$answer -ge 1 -and [int]$answer -le $providers.Count) {
            $provider = $providers[[int]$answer - 1]
            $servers = @($provider.Servers)
            $choiceName = $provider.Name
        }

        if ($null -eq $servers) {
            Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'Operação cancelada. Nada foi alterado.')
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Skipped -Detail (Get-WinForgeText 'cancelado pelo usuário') -Title $title)
            return
        }

        # Um adaptador cujo DNS atual não pôde ser lido não é trocado: sem saber o que havia, não haveria como desfazer.
        $changeable = @($adapters | Where-Object { $_.Mode -ne "Unknown" })
        $changed = @()
        $errors = @()
        $notChanged = @()

        foreach ($adapter in @($adapters | Where-Object { $_.Mode -eq "Unknown" })) {
            $notChanged += $adapter.Alias
            Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText '{0}: não foi possível ler o DNS que ele usa agora; para poder desfazer depois, ele não foi alterado.' "$($adapter.Alias)")
        }

        if ($changeable.Count -eq 0) {
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Failed -Detail (Get-WinForgeText 'nenhum adaptador foi alterado: o DNS atual não pôde ser lido') -Title $title)
            return
        }

        # O que já usa o DNS escolhido fica como está: sem backup, sem troca e sem nada no Histórico de mudanças.
        $changeable = @($changeable | Where-Object { -not (Test-WinForgeDnsAlready -Adapter $_ -Servers $servers) })

        if ($changeable.Count -eq 0) {
            $headline = $(if ($servers.Count -eq 0) { (Get-WinForgeText 'Este PC já usa o DNS automático') } else { (Get-WinForgeText 'Este PC já usa {0}' "$choiceName") })
            Write-WinForgeStatus -Type Info -Message (Get-WinForgeText '{0}: nada mudou.' "$headline")
            $kept = $(if ($notChanged.Count -eq 1) { (Get-WinForgeText '1 adaptador não foi alterado ({0})' "$($notChanged[0])") } else { (Get-WinForgeText '{0} adaptadores não foram alterados ({1})' "$($notChanged.Count)" "$($notChanged -join ', ')") })
            $final = $(if ($notChanged.Count -gt 0) {
                    Set-WinForgeResultView -Result (New-WinForgeResult -Kind Warning -Detail $kept -Title $title) -Headline $headline -Note (Get-WinForgeText '{0}; o motivo está no resumo.' "$($kept.Substring(0, 1).ToUpper())$($kept.Substring(1))")
                }
                else {
                    Set-WinForgeResultView -Result (New-WinForgeResult -Kind Skipped -Detail (Get-WinForgeText 'o DNS escolhido já estava em uso') -Title $title) -Headline $headline -Note (Get-WinForgeText 'Nada mudou.')
                })
            Exit-WinForgeAction -Result $final
            return
        }

        Save-WinForgeDnsBackup -Adapters $changeable
        Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Para voltar ao DNS de antes, use Rede > Desfazer a troca de DNS.')

        foreach ($adapter in $changeable) {
            try {
                Set-WinForgeAdapterDns -Adapter $adapter -Servers $servers
                $changed += $adapter
                Write-WinForgeStatus -Type Success -Message (Get-WinForgeText '{0}: DNS {1}' "$($adapter.Alias)" "$choiceName")
            }
            catch {
                $errors += "$($adapter.Alias): $($_.Exception.Message)"
                $notChanged += $adapter.Alias
                Write-WinForgeStatus -Type Error -Message (Get-WinForgeText '{0}: não foi possível trocar ({1})' "$($adapter.Alias)" "$($_.Exception.Message)")
            }
        }

        if ($changed.Count -eq 0) {
            $final = New-WinForgeResult -Kind Failed -Detail (Get-WinForgeText 'nenhum adaptador foi alterado') -Title $title
        }
        else {
            Write-Progress -Activity $title -Status (Get-WinForgeText 'conferindo se o novo DNS resolve nomes')

            try { $working = Test-WinForgeDnsWorking } finally { Write-Progress -Activity $title -Completed }

            if ($working) {
                Write-WinForgeStatus -Type Success -Message (Get-WinForgeText 'O novo DNS está funcionando.')
                [void](Add-WinForgeChange -Action "DNS" -Text $(if ($servers.Count -eq 0) { (Get-WinForgeText 'DNS automático') } else { (Get-WinForgeText 'trocado para {0}' "$choiceName") }) -Undo @{ Kind = "dns" })
                # Com um adaptador de fora, o título ainda diz qual DNS ficou; a frase, qual não mudou.
                $headline = $(if ($servers.Count -eq 0) { (Get-WinForgeText 'DNS automático') } else { (Get-WinForgeText 'DNS trocado para {0}' "$choiceName") })
                $partial = $(if ($notChanged.Count -eq 1) { (Get-WinForgeText '1 adaptador não foi alterado ({0})' "$($notChanged[0])") } else { (Get-WinForgeText '{0} adaptadores não foram alterados ({1})' "$($notChanged.Count)" "$($notChanged -join ', ')") })

                $final = if ($notChanged.Count -gt 0) {
                    Set-WinForgeResultView -Result (New-WinForgeResult -Kind Warning -Detail $partial -Title $title) -Headline $headline `
                        -Note (Get-WinForgeText '{0}; o motivo está no resumo.' "$($partial.Substring(0, 1).ToUpper())$($partial.Substring(1))")
                }
                else {
                    # Na janela, o título diz qual DNS ficou; a frase, como voltar (ou, no automático, de onde ele vem).
                    Set-WinForgeResultView -Result (New-WinForgeResult -Kind Ok -Detail $(if ($servers.Count -eq 0) { (Get-WinForgeText 'DNS automático') } else { "DNS $choiceName" }) -Title $title) `
                        -Headline $(if ($servers.Count -eq 0) { (Get-WinForgeText 'DNS automático') } else { (Get-WinForgeText 'DNS trocado para {0}' "$choiceName") }) `
                        -Note $(if ($servers.Count -eq 0) { (Get-WinForgeText 'O DNS vem do roteador ou da operadora.') } else { (Get-WinForgeText 'O novo DNS está funcionando. Para voltar ao de antes, use Desfazer a troca de DNS.') })
                }
            }
            else {
                Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'O novo DNS não funcionou neste PC; voltando ao de antes.')

                # Volta ao DNS de logo antes desta troca (o que estava em uso e resolvia nomes), lido no começo da ação, e
                # não ao original guardado no backup: depois de uma troca que deu certo, o original pode ser justamente o
                # DNS que não funcionava, e a volta deixaria o PC sem resolver nomes. O backup continua com o original,
                # para o "Desfazer a troca de DNS".
                $undo = Restore-WinForgeDnsFromBackup -Backup @($changed) -Adapters $adapters

                if ($undo.Failed.Count -eq 0 -and $undo.Unknown.Count -eq 0) {
                    Write-WinForgeStatus -Type Success -Message (Get-WinForgeText 'O DNS de antes foi restaurado.')
                    $final = Set-WinForgeResultView -Result (New-WinForgeResult -Kind Warning -Detail (Get-WinForgeText 'o novo DNS não resolveu nomes; desfeito') -Title $title) `
                        -Headline (Get-WinForgeText 'O novo DNS não funcionou') -Note (Get-WinForgeText 'O DNS de antes foi restaurado; a rede pode estar bloqueando DNS externo.')
                }
                else {
                    $problems = @($undo.Failed) + @($undo.Unknown | ForEach-Object { (Get-WinForgeText '{0}: o DNS de antes não é conhecido (escolha Automático em Rede > Trocar o servidor DNS)' "${_}") })
                    Write-WinForgeStatus -Type Error -Message (Get-WinForgeText 'Não foi possível restaurar tudo: {0}. Use Rede > Desfazer a troca de DNS.' "$($problems -join '; ')")
                    $final = Set-WinForgeResultView -Result (New-WinForgeResult -Kind Failed -Detail (Get-WinForgeText 'o novo DNS não resolveu nomes e a restauração falhou') -Title $title) `
                        -Headline (Get-WinForgeText 'O DNS de antes não voltou') -Note (Get-WinForgeText 'O novo DNS não funcionou, e o de antes não pôde ser restaurado: use Desfazer a troca de DNS.') `
                        -Next "network.dns-undo" -NextLabel (Get-WinForgeText 'Desfazer a troca de DNS')
                }
            }
        }
    }
    catch {
        Write-WinForgeStatus -Type Error -Message (Get-WinForgeText 'Não foi possível trocar o DNS: {0}' "$($_.Exception.Message)")
        $final = New-WinForgeResult -Kind Failed -Detail $_.Exception.Message -Title $title
    }

    Exit-WinForgeAction -Result $final
}


function Undo-WinForgeDnsChange {
    $title = (Get-WinForgeText 'Desfazer a troca de DNS')

    Enter-WinForgeAction -Title $title

    $final = New-WinForgeResult -Kind Ok -Title $title

    try {
        if (-not (Test-WinForgeElevation -Reason (Get-WinForgeText 'Desfazer a troca de DNS exige privilégios de Administrador.'))) {
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Failed -Detail (Get-WinForgeText 'requer Administrador') -Title $title)
            return
        }

        $read = Read-WinForgeDnsBackup -Status

        if ($read.Status -eq "Unreadable") {
            # Dizer "não há o que desfazer" seria falso: o backup existe, só não pôde ser lido agora.
            Write-WinForgeStatus -Type Error -Message (Get-WinForgeText 'O backup do DNS de antes existe, mas não pôde ser lido agora ({0}). Nada foi alterado; tente de novo em instantes.' "$(Get-WinForgeDnsBackupPath)")
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Failed -Detail (Get-WinForgeText 'o backup do DNS não pôde ser lido') -Title $title)
            return
        }

        $backup = @($read.Entries)

        if ($backup.Count -eq 0) {
            Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'O WinForge não trocou o DNS neste PC: não há o que desfazer.')
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Skipped -Detail (Get-WinForgeText 'nenhuma troca para desfazer') -Title $title)
            return
        }

        Write-WinForgeSection -Title (Get-WinForgeText 'DNS de antes')

        foreach ($entry in $backup) {
            Write-WinForgeKeyValue -Label $(if ($entry.Alias) { $entry.Alias } else { $entry.Guid }) -Value (Get-WinForgeDnsModeText -Adapter $entry)
        }

        Write-Host ""

        $undo = Restore-WinForgeDnsFromBackup -Backup $backup -Adapters @(Get-WinForgeDnsAdapters)

        foreach ($name in $undo.Missing) {
            Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText '{0} não está ativo agora; o DNS dele não foi restaurado.' "$name")
        }

        foreach ($problem in $undo.Failed) {
            Write-WinForgeStatus -Type Error -Message $problem
        }

        foreach ($name in $undo.Unknown) {
            Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText '{0} ficou como está (o DNS de antes não era conhecido); se precisar, escolha Automático em Rede > Trocar o servidor DNS.' "$name")
        }

        $restoredText = $(if ($undo.Restored -eq 1) { (Get-WinForgeText '1 adaptador voltou ao DNS de antes') } else { (Get-WinForgeText '{0} adaptadores voltaram ao DNS de antes' "$($undo.Restored)") })

        if ($undo.Restored -gt 0) {
            Write-WinForgeStatus -Type Success -Message "$restoredText."
            Clear-DnsClientCache -ErrorAction SilentlyContinue
        }

        if ($undo.Failed.Count -eq 0 -and $undo.Missing.Count -eq 0) {
            # Os desconhecidos não têm como voltar: guardar o backup só repetiria o mesmo aviso.
            Remove-WinForgeDnsBackup
            Set-WinForgeChangesUndone -Kind "dns" -Key "Kind" -Value "dns"

            if ($undo.Unknown.Count -gt 0) {
                $verb = $(if ($undo.Unknown.Count -eq 1) { (Get-WinForgeText 'não foi alterado') } else { (Get-WinForgeText 'não foram alterados') })
                $final = Set-WinForgeResultView -Result (New-WinForgeResult -Kind Warning -Detail (Get-WinForgeText '{0}; {1} {2} (o DNS de antes não era conhecido)' "$restoredText" "$(Join-WinForgeList -Items @($undo.Unknown))" "$verb") -Title $title) `
                    -Headline $(if ($undo.Restored -gt 0) { (Get-WinForgeText 'DNS de antes restaurado em parte') } else { (Get-WinForgeText 'O DNS de antes não voltou') }) `
                    -Note (Get-WinForgeText '{0} {1}: o DNS de antes não era conhecido.' "$(Join-WinForgeList -Items @($undo.Unknown))" "$verb")
            }
            else {
                $final = Set-WinForgeResultView -Result (New-WinForgeResult -Kind Ok -Detail $restoredText -Title $title) -Headline (Get-WinForgeText 'DNS de antes restaurado') -Note "$restoredText."
            }
        }
        else {
            Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'O backup foi mantido para você tentar de novo.')

            # Na janela, o título diz se o DNS de antes voltou; a frase, o que fazer com o resto.
            if ($undo.Restored -gt 0) {
                $final = Set-WinForgeResultView -Result (New-WinForgeResult -Kind Warning -Detail (Get-WinForgeText 'restauração parcial: {0}' "$restoredText") -Title $title) `
                    -Headline (Get-WinForgeText 'DNS de antes restaurado em parte') -Note (Get-WinForgeText '{0}; o que faltou está no resumo.' "$($restoredText.Substring(0, 1).ToUpper())$($restoredText.Substring(1))")
            }
            elseif ($undo.Failed.Count -gt 0) {
                $final = Set-WinForgeResultView -Result (New-WinForgeResult -Kind Failed -Detail (Get-WinForgeText 'nenhum adaptador foi restaurado') -Title $title) `
                    -Headline (Get-WinForgeText 'O DNS de antes não voltou') -Note (Get-WinForgeText 'O motivo está no resumo; o backup foi mantido para tentar de novo.')
            }
            else {
                # Só faltam adaptadores desligados (Wi-Fi apagado, cabo fora): não é um erro, é ligá-los e repetir.
                $missing = Join-WinForgeList -Items @($undo.Missing)
                $final = Set-WinForgeResultView -Result (New-WinForgeResult -Kind Warning -Detail (Get-WinForgeText 'nenhum adaptador do backup está ativo agora; ligue-os e repita') -Title $title) `
                    -Headline (Get-WinForgeText 'O DNS de antes não voltou') `
                    -Note $(if (@($undo.Missing).Count -eq 1) { (Get-WinForgeText 'O adaptador {0} não está ativo agora: ligue-o e repita; o backup foi mantido.' "$missing") } else { (Get-WinForgeText 'Os adaptadores {0} não estão ativos agora: ligue-os e repita; o backup foi mantido.' "$missing") })
            }
        }
    }
    catch {
        Write-WinForgeStatus -Type Error -Message (Get-WinForgeText 'Não foi possível desfazer: {0}' "$($_.Exception.Message)")
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
    $title = (Get-WinForgeText 'Relatório de Wi-Fi')

    Enter-WinForgeAction -Title $title

    $final = New-WinForgeResult -Kind Ok -Title $title

    try {
        if (-not (Test-WinForgeElevation -Reason (Get-WinForgeText 'O relatório de Wi-Fi exige privilégios de Administrador.'))) {
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Failed -Detail (Get-WinForgeText 'requer Administrador') -Title $title)
            return
        }

        $source = Get-WinForgeWifiReportSource
        $startedAt = Get-Date

        Write-Progress -Activity $title -Status (Get-WinForgeText 'o Windows está gerando o relatório (leva alguns segundos)')

        try { $run = Invoke-WinForgeCapture -FilePath "netsh" -Arguments @("wlan", "show", "wlanreport") } finally { Write-Progress -Activity $title -Completed }

        $fresh = (Test-Path -LiteralPath $source -PathType Leaf) -and ((Get-Item -LiteralPath $source).LastWriteTime -ge $startedAt.AddSeconds(-5))

        if (-not $fresh) {
            Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'O Windows não gerou o relatório (código {0}). Este PC pode não ter Wi-Fi, ou o serviço de Wi-Fi está parado.' "$($run.ExitCode)")
            Exit-WinForgeAction -Result (Set-WinForgeResultView -Result (New-WinForgeResult -Kind Skipped -Detail (Get-WinForgeText 'o Windows não gerou o relatório') -Title $title) `
                    -Headline (Get-WinForgeText 'Relatório não gerado') -Note (Get-WinForgeText 'Este PC pode não ter Wi-Fi, ou o serviço de Wi-Fi está parado.'))
            return
        }

        # Na pasta dos outros relatórios, a que Sobre o WinForge > Pasta de logs e relatórios abre.
        $folder = Join-Path (Get-WinForgeDataPath) "reports"
        [void](New-Item -ItemType Directory -Path $folder -Force -ErrorAction Stop)
        $target = Join-Path $folder "Relatorio-WiFi-$((Get-Date).ToString('yyyy-MM-dd-HHmm', [System.Globalization.CultureInfo]::InvariantCulture)).html"
        Copy-Item -LiteralPath $source -Destination $target -Force -ErrorAction Stop

        Write-WinForgeStatus -Type Success -Message (Get-WinForgeText 'Relatório gerado.')
        Write-WinForgeKeyValue -Label (Get-WinForgeText 'Arquivo') -Value $target
        $final = Set-WinForgeResultView -Result (New-WinForgeResult -Kind Ok -Detail (Get-WinForgeText 'relatório salvo') -Title $title) -Headline (Get-WinForgeText 'Relatório do Wi-Fi gerado') -Note (Get-WinForgeText 'Salvo em {0}.' "$target")
        # O resumo no alto mostra as sessões de Wi-Fi dos últimos dias. Quedas repetidas no mesmo horário costumam vir do
        # roteador, do canal ou da distância.
        Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Como ler: as barras vermelhas são quedas, com o motivo logo abaixo.')
        Write-Host ""

        if (Confirm-WinForgeAction -Message (Get-WinForgeText 'Abrir o relatório agora?') -DefaultKey "S" -YesLabel (Get-WinForgeText 'Abrir') -NoLabel (Get-WinForgeText 'Agora não')) {
            try {
                # Pelo explorer.exe, que entrega a abertura ao Explorador da sessão: o navegador abre sem os privilégios de
                # Administrador desta ação (aberto direto daqui, ele herdaria a elevação).
                Start-Process -FilePath "explorer.exe" -ArgumentList "`"$target`"" -ErrorAction Stop
            }
            catch {
                Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'Não foi possível abrir o relatório: {0}' "$($_.Exception.Message)")
                $final = Set-WinForgeResultView -Result (New-WinForgeResult -Kind Ok -Detail (Get-WinForgeText 'relatório salvo; não foi possível abri-lo') -Title $title) `
                    -Headline (Get-WinForgeText 'Relatório do Wi-Fi gerado') -Note (Get-WinForgeText 'Salvo em {0}; não foi possível abri-lo daqui.' "$target")
            }
        }
    }
    catch {
        Write-WinForgeStatus -Type Error -Message (Get-WinForgeText 'Não foi possível gerar o relatório de Wi-Fi: {0}' "$($_.Exception.Message)")
        $final = New-WinForgeResult -Kind Failed -Detail $_.Exception.Message -Title $title
    }

    Exit-WinForgeAction -Result $final
}


# ---------------------------------------------------------------------------
# Senha do Wi-Fi (Rede > Senha do Wi-Fi)
# ---------------------------------------------------------------------------

function Test-WinForgeWifiAdapter {
    # Se o PC tem um adaptador de Wi-Fi (ligado ou desligado): $true, $false, ou $null quando não dá para saber.
    try {
        $adapters = @(Get-NetAdapter -Physical -ErrorAction Stop)
        return (@($adapters | Where-Object { [string](Get-WinForgeJsonValue -Object $_ -Name "PhysicalMediaType" -Default "") -match '802\.11' -or [string](Get-WinForgeJsonValue -Object $_ -Name "NdisPhysicalMedium" -Default "") -eq "9" }).Count -gt 0)
    }
    catch {
        return $null
    }
}


function Read-WinForgeWifiProfiles {
    <#
    As redes Wi-Fi salvas neste PC, com a senha: Name (o nome do perfil), Ssid, Key (a senha; vazia numa rede aberta ou
    de empresa, que não guarda senha) e Kind (Personal, Open, Enterprise ou Unreadable: uma rede com senha que o Windows
    não entregou em texto). O Windows exporta os perfis em XML, que não
    muda com o idioma; os arquivos, com as senhas em texto, ficam numa pasta temporária só o tempo de ler e saem na hora.
    Pede Administrador (sem ele, o Windows não entrega as senhas). Lança erro quando o Windows não exporta.
    #>
    $folder = Join-Path ([System.IO.Path]::GetTempPath()) ("WinForge-wifi-{0}" -f [guid]::NewGuid().ToString("N"))
    $profiles = @()

    [void](New-Item -ItemType Directory -Path $folder -Force -ErrorAction Stop)

    try {
        # Sem o argumento folder=, o netsh grava na pasta atual: assim um caminho com espaços não vira problema de aspas.
        Push-Location -LiteralPath $folder

        try { $run = Invoke-WinForgeCapture -FilePath "netsh" -Arguments @("wlan", "export", "profile", "key=clear") }
        finally { Pop-Location }

        $files = @(Get-ChildItem -LiteralPath $folder -Filter "*.xml" -File -ErrorAction SilentlyContinue)

        if ($run.ExitCode -ne 0 -and $files.Count -eq 0) {
            $reason = @($run.Lines | ForEach-Object { ([string]$_).Trim() } | Where-Object { $_ }) | Select-Object -First 2
            throw (Get-WinForgeText 'o Windows não entregou as redes Wi-Fi ({0}); se o PC tem Wi-Fi, confira se ele está ligado' "$((@($reason) -join ' ').TrimEnd('.'))")
        }

        foreach ($file in $files) {
            try {
                [xml]$xml = [System.IO.File]::ReadAllText($file.FullName, [System.Text.Encoding]::UTF8)
                $namespace = New-Object System.Xml.XmlNamespaceManager $xml.NameTable
                $namespace.AddNamespace("w", $xml.DocumentElement.NamespaceURI)

                $name = [string]$xml.SelectSingleNode("/w:WLANProfile/w:name", $namespace).InnerText
                $ssidNode = $xml.SelectSingleNode("/w:WLANProfile/w:SSIDConfig/w:SSID/w:name", $namespace)
                $authNode = $xml.SelectSingleNode("//w:authEncryption/w:authentication", $namespace)
                $keyNode = $xml.SelectSingleNode("//w:sharedKey/w:keyMaterial", $namespace)
                $protectedNode = $xml.SelectSingleNode("//w:sharedKey/w:protected", $namespace)
                $auth = $(if ($null -ne $authNode) { [string]$authNode.InnerText } else { "" })
                $hasKey = ($null -ne $keyNode -and -not [string]::IsNullOrEmpty([string]$keyNode.InnerText))
                $cipher = ($null -ne $protectedNode -and ([string]$protectedNode.InnerText).Trim() -ieq "true")

                # Pela senha guardada, e não só pela autenticação: uma rede WEP antiga usa a autenticação "open" com senha.
                # Uma senha que o Windows entrega ainda cifrada (protected) não é a senha da rede.
                $kind = $(if ($hasKey -and $cipher) { "Unreadable" }
                    elseif ($hasKey) { "Personal" }
                    elseif ($auth -match '^(open|OWE)$') { "Open" }
                    elseif ($auth -match '(?i)PSK|SAE') { "Unreadable" }
                    else { "Enterprise" })

                $profiles += [PSCustomObject]@{
                    Name = $name
                    Ssid = $(if ($null -ne $ssidNode -and $ssidNode.InnerText) { [string]$ssidNode.InnerText } else { $name })
                    Key  = $(if ($kind -eq "Personal") { [string]$keyNode.InnerText } else { "" })
                    Kind = $kind
                }
            }
            catch {
                Write-Verbose "Perfil Wi-Fi: $($_.Exception.Message)"
            }
        }
    }
    finally {
        Remove-WinForgeFolder -Path $folder -Quiet
    }

    # Com dois adaptadores de Wi-Fi (o do notebook e um USB), o Windows exporta cada rede uma vez por adaptador
    # ("Wi-Fi-Casa.xml" e "Wi-Fi 2-Casa.xml"): cada rede aparece uma vez, a que tem a senha primeiro.
    $rank = @{ "Personal" = 0; "Unreadable" = 1; "Enterprise" = 2; "Open" = 3 }
    $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::Ordinal)
    $unique = @(
        foreach ($item in @($profiles | Sort-Object -Property @{ Expression = { $rank[[string]$_.Kind] } })) {
            if ($seen.Add([string]$item.Ssid)) { $item }
        }
    )

    return @($unique | Sort-Object Ssid)
}


function Show-WinForgeWifiPassword {
    $title = (Get-WinForgeText 'Senha do Wi-Fi')
    Enter-WinForgeAction -Title $title

    $final = $null

    try {
        if (-not (Test-WinForgeElevation -Reason (Get-WinForgeText 'Ver a senha do Wi-Fi exige privilégios de Administrador.'))) {
            $final = New-WinForgeResult -Kind Failed -Detail (Get-WinForgeText 'requer Administrador') -Title $title
        }
        else {
            $profiles = @()
            $noWifi = $false

            try {
                $profiles = @(Read-WinForgeWifiProfiles)
            }
            catch {
                # Sem adaptador de Wi-Fi, o Windows não entrega rede nenhuma: não é um erro.
                if ((Test-WinForgeWifiAdapter) -eq $false) { $noWifi = $true } else { throw }
            }

            if ($noWifi) {
                Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Este PC não tem adaptador de Wi-Fi: sem ele, o Windows não mostra as redes salvas.')
                $final = Set-WinForgeResultView -Result (New-WinForgeResult -Kind Skipped -Detail (Get-WinForgeText 'este PC não tem Wi-Fi') -Title $title) `
                    -Headline (Get-WinForgeText 'Este PC não tem Wi-Fi') -Note (Get-WinForgeText 'Sem adaptador de Wi-Fi, não há redes salvas para mostrar.')
            }
            elseif ($profiles.Count -eq 0) {
                Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Nenhuma rede Wi-Fi salva neste PC (ou ele não tem Wi-Fi).')
                $final = Set-WinForgeResultView -Result (New-WinForgeResult -Kind Skipped -Detail (Get-WinForgeText 'nenhuma rede Wi-Fi salva') -Title $title) `
                    -Headline (Get-WinForgeText 'Nenhuma rede Wi-Fi salva') -Note (Get-WinForgeText 'O Windows guarda a senha de uma rede quando o PC se conecta a ela.')
            }
            else {
                # A rede conectada agora vem primeiro e já marcada.
                $connected = ""

                try {
                    $wlan = Invoke-WinForgeCapture -FilePath "netsh" -Arguments @("wlan", "show", "interfaces")
                    $connected = [string](@(ConvertFrom-WinForgeWlanInterfaces -Lines @($wlan.Lines)) | Select-Object -First 1 -ExpandProperty Ssid -ErrorAction SilentlyContinue)
                }
                catch {
                    $connected = ""
                }

                $ordered = @($profiles | Where-Object { $connected -and $_.Ssid -ceq $connected }) + @($profiles | Where-Object { -not ($connected -and $_.Ssid -ceq $connected) })
                $options = @()
                $position = 0

                foreach ($profile in $ordered) {
                    $position++
                    $about = switch ($profile.Kind) {
                        "Open" { (Get-WinForgeText 'rede aberta, sem senha') }
                        "Enterprise" { (Get-WinForgeText 'rede de empresa: a senha é a da sua conta, e não fica guardada') }
                        "Unreadable" { (Get-WinForgeText 'o Windows não entregou a senha desta rede') }
                        default { $(if ($connected -and $profile.Ssid -ceq $connected) { (Get-WinForgeText 'conectada agora') } else { "" }) }
                    }

                    # O destaque marca a rede conectada; sem nenhuma, a primeira da lista é só a primeira em ordem alfabética.
                    $options += @{ Key = [string]$position; Label = $profile.Ssid; Description = $about; Accent = ($position -eq 1 -and $connected -and $profile.Ssid -ceq $connected) }
                }

                $options += @{ Key = "0"; Label = (Get-WinForgeText 'Voltar'); Exit = $true }

                $answer = Read-WinForgeChoice -Message (Get-WinForgeText 'De qual rede?') -Options $options -DefaultKey "1" -ShowMenu
                $index = 0

                if (-not ([int]::TryParse([string]$answer, [ref]$index)) -or $index -lt 1 -or $index -gt $ordered.Count) {
                    $final = New-WinForgeResult -Kind Skipped -Detail (Get-WinForgeText 'cancelado pelo usuário') -Title $title
                }
                else {
                    $chosen = $ordered[$index - 1]
                    Write-Host ""
                    Write-WinForgeKeyValue -Label (Get-WinForgeText 'Rede') -Value $chosen.Ssid

                    if ($chosen.Kind -eq "Personal") {
                        Write-WinForgeSecret -Label (Get-WinForgeText 'Senha') -Value $chosen.Key
                        Write-Host ""
                        Write-WinForgeStatus -Type Info -Notice -Message (Get-WinForgeText 'A senha aparece só na tela: ela não vai para o log do WinForge.')

                        $final = Set-WinForgeResultView -Result (New-WinForgeResult -Kind Ok -Detail (Get-WinForgeText 'senha mostrada na tela') -Title $title) `
                            -Headline (Get-WinForgeText 'Senha de {0}' "$($chosen.Ssid)") -Note (Get-WinForgeText 'A senha está no resumo, abaixo; ela não vai para o log do WinForge.')
                    }
                    elseif ($chosen.Kind -eq "Unreadable") {
                        Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'O Windows não entregou a senha desta rede em texto: ela não pode ser mostrada daqui.')
                        $final = Set-WinForgeResultView -Result (New-WinForgeResult -Kind Skipped -Detail (Get-WinForgeText 'o Windows não entregou a senha desta rede') -Title $title) `
                            -Headline (Get-WinForgeText 'A senha de {0} não pôde ser mostrada' "$($chosen.Ssid)") -Note (Get-WinForgeText 'O Windows não a entregou em texto.')
                    }
                    else {
                        $text = $(if ($chosen.Kind -eq "Open") { (Get-WinForgeText 'Esta rede é aberta: não tem senha.') } else { (Get-WinForgeText 'Esta é uma rede de empresa: entra com o usuário e a senha da sua conta, e o Windows não guarda uma senha da rede.') })
                        Write-WinForgeStatus -Type Info -Message $text
                        $final = New-WinForgeResult -Kind Skipped -Detail $(if ($chosen.Kind -eq "Open") { (Get-WinForgeText 'rede aberta, sem senha') } else { (Get-WinForgeText 'rede de empresa, sem senha guardada') }) -Title $title

                        # Na janela, o título diz que não há senha a mostrar (e não "Nada a fazer"); a frase, por quê.
                        [void](Set-WinForgeResultView -Result $final `
                                -Headline $(if ($chosen.Kind -eq "Open") { (Get-WinForgeText '{0} não tem senha' "$($chosen.Ssid)") } else { (Get-WinForgeText '{0} não guarda senha' "$($chosen.Ssid)") }) `
                                -Note $(if ($chosen.Kind -eq "Open") { (Get-WinForgeText 'É uma rede aberta.') } else { (Get-WinForgeText 'É uma rede de empresa: entra com o usuário e a senha da sua conta.') }))
                    }
                }
            }
        }
    }
    catch {
        Write-WinForgeStatus -Type Error -Message (Get-WinForgeText 'Não foi possível ler as redes Wi-Fi: {0}.' "$(([string]$_.Exception.Message).TrimEnd('.'))")
        $final = New-WinForgeResult -Kind Failed -Detail ([string]$_.Exception.Message).TrimEnd('.') -Title $title
    }

    Exit-WinForgeAction -Result $final
}



# ---------------------------------------------------------------------------
# Acertar a data e a hora
# ---------------------------------------------------------------------------

function Get-WinForgeClockOffset {
    <#
    Quanto o relógio do PC está adiantado (positivo) ou atrasado (negativo), em segundos, pela hora do servidor do teste
    de internet do próprio Windows (www.msftconnecttest.com, o do indicador de conexão): o cabeçalho Date da resposta, mais
    o Age de uma cópia guardada no caminho. HTTP, e não HTTPS: com o relógio muito errado, o HTTPS recusa o certificado do
    servidor. A resposta só vale com o texto que a Microsoft documenta para esse teste ("Microsoft Connect Test"): um
    portal de Wi-Fi no meio do caminho não conta. $null sem resposta. A medida tem um a dois segundos de folga.
    #>
    $response = $null

    try {
        $request = [System.Net.HttpWebRequest]::Create("http://www.msftconnecttest.com/connecttest.txt")
        $request.Timeout = 8000
        $request.ReadWriteTimeout = 8000
        $request.AllowAutoRedirect = $false
        $request.CachePolicy = New-Object System.Net.Cache.RequestCachePolicy([System.Net.Cache.RequestCacheLevel]::NoCacheNoStore)
        $request.Proxy = [System.Net.WebRequest]::GetSystemWebProxy()
        $request.Proxy.Credentials = [System.Net.CredentialCache]::DefaultCredentials

        $sent = [DateTime]::UtcNow
        $response = $request.GetResponse()
        $received = [DateTime]::UtcNow

        $reader = New-Object System.IO.StreamReader($response.GetResponseStream())
        try { $body = $reader.ReadToEnd() } finally { $reader.Dispose() }

        if ([int]$response.StatusCode -ne 200 -or ([string]$body).Trim() -ne "Microsoft Connect Test") { return $null }

        $server = [DateTime]::ParseExact(([string]$response.Headers["Date"]).Trim(), "r", [System.Globalization.CultureInfo]::InvariantCulture, ([System.Globalization.DateTimeStyles]::AdjustToUniversal -bor [System.Globalization.DateTimeStyles]::AssumeUniversal))
        $age = 0
        if ([int]::TryParse([string]$response.Headers["Age"], [ref]$age) -and $age -gt 0) { $server = $server.AddSeconds($age) }

        # A hora do servidor é a do meio da ida e volta; o Date corta a fração do segundo (meio segundo, em média).
        $local = $sent.AddTicks([long](($received - $sent).Ticks / 2))

        return [double](($local - $server).TotalSeconds - 0.5)
    }
    catch {
        return $null
    }
    finally {
        if ($null -ne $response) { $response.Close() }
    }
}


function Get-WinForgeClockOffsetText {
    # "Certo", "3min 05s adiantado", "4 dias atrasado". Até 10 segundos é "certo": a medida tem um a dois de folga.
    param ([double]$Seconds)

    $abs = [Math]::Abs($Seconds)

    if ($abs -le 10) { return (Get-WinForgeText 'Certo') }

    $amount = $(if ($abs -ge 172800) { Format-WinForgeCount -Count ([int][Math]::Floor($abs / 86400)) -One (Get-WinForgeText 'dia') -Many (Get-WinForgeText 'dias') } else { Format-WinForgeDuration -Span ([TimeSpan]::FromSeconds($abs)) })

    if ($Seconds -gt 0) { return (Get-WinForgeText '{0} adiantado' "$amount") }

    return (Get-WinForgeText '{0} atrasado' "$amount")
}


function Write-WinForgeClockState {
    # A hora do PC, o fuso (só uma vez na tela: -NoZone no "antes") e, quando foi medido, quanto o relógio está fora da
    # hora certa.
    param (
        $Offset = $null,
        [switch]$NoZone
    )

    Write-WinForgeKeyValue -Label (Get-WinForgeText 'Hora no PC') -Value (Format-WinForgeDateTime -When (Get-Date))
    if (-not $NoZone) { Write-WinForgeKeyValue -Label (Get-WinForgeText 'Fuso horário') -Value ([string][System.TimeZoneInfo]::Local.DisplayName) }
    Write-WinForgeKeyValue -Label (Get-WinForgeText 'Relógio') -Value $(if ($null -eq $Offset) { (Get-WinForgeText 'Não foi possível medir (sem resposta do servidor da Microsoft)') } else { Get-WinForgeClockOffsetText -Seconds $Offset }) `
        -Level $(if ($null -ne $Offset -and [Math]::Abs([double]$Offset) -gt 10) { "Warn" } else { "Normal" })
}


function Invoke-WinForgeTimeResync {
    # "w32tm /resync"; sem sucesso, de novo com /rediscover, que redetecta a rede e as fontes de hora antes de sincronizar.
    # Devolve o resultado da última tentativa (ExitCode, Lines e Text).
    Write-WinForgeCommand -Command "w32tm /resync"
    $run = Invoke-WinForgeCapture -FilePath "w32tm.exe" -Arguments @("/resync") -Echo

    if ($run.ExitCode -ne 0) {
        Write-WinForgeCommand -Command "w32tm /resync /rediscover"
        $run = Invoke-WinForgeCapture -FilePath "w32tm.exe" -Arguments @("/resync", "/rediscover") -Echo
    }

    return $run
}


function Get-WinForgeTimeSource {
    # De onde o Windows pega a hora ("time.windows.com", o servidor do domínio), sem as opções do fim (",0x9"); vazio
    # quando o w32tm não respondeu.
    try {
        $run = Invoke-WinForgeCapture -FilePath "w32tm.exe" -Arguments @("/query", "/source")
    }
    catch {
        return ""
    }

    if ($run.ExitCode -ne 0) { return "" }

    $line = [string](@($run.Lines | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) }) | Select-Object -First 1)

    return (($line.Trim()) -replace ',0x[0-9A-Fa-f]+$', '')
}


function Sync-WinForgeTime {
    <#
    Acertar a data e a hora: pede ao serviço Horário do Windows para sincronizar agora (w32tm /resync), e confere o
    resultado na hora de um servidor da Microsoft (Get-WinForgeClockOffset), sem depender só do código de saída do w32tm.
    O Windows não acerta sozinho um relógio muito errado: num PC fora de domínio, o padrão é corrigir no máximo 15 horas
    para mais ou para menos (MaxPosPhaseCorrection e MaxNegPhaseCorrection); acima disso, ele só registra um evento. Com
    o relógio ainda errado depois de sincronizar, e a pessoa concordando, o relógio vai para a hora do servidor e o
    Windows sincroniza de novo. Num PC de domínio, a hora vem do domínio, e o WinForge não a muda por fora. Um serviço
    desativado não é ligado, e o Windows configurado para não sincronizar (Type = NoSync, nos parâmetros do Horário do
    Windows) fica como está: nos dois casos, a tela diz isso e só oferece pôr o relógio na hora do servidor.
    #>
    $title = (Get-WinForgeText 'Acertar a data e a hora')

    Enter-WinForgeAction -Title $title

    $final = New-WinForgeResult -Kind Ok -Title $title

    try {
        if (-not (Test-WinForgeElevation -Reason (Get-WinForgeText 'Acertar a data e a hora exige privilégios de Administrador.'))) {
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Failed -Detail (Get-WinForgeText 'requer Administrador') -Title $title)
            return
        }

        $state = Get-WinForgeServiceState -Name "W32Time"

        if ($null -eq $state -or [bool]$state.Missing) {
            $text = $(if ($null -eq $state) { (Get-WinForgeText 'o Windows não respondeu sobre o serviço Horário do Windows') } else { (Get-WinForgeText 'o serviço Horário do Windows não existe neste Windows') })
            Write-WinForgeStatus -Type Error -Message "$(ConvertTo-WinForgeHeadline -Text $text)."
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Failed -Detail $text -Title $title)
            return
        }

        $system = @(Get-WinForgeCimOrNull -ClassName "Win32_ComputerSystem") | Select-Object -First 1
        $domain = ($null -ne $system -and [bool](Get-WinForgeJsonValue -Object $system -Name "PartOfDomain" -Default $false))
        $disabled = ($state.StartType -eq "Disabled")
        $noSource = ([string](Get-WinForgeRegistryValueOrNull -Path "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Parameters" -Name "Type") -eq "NoSync")

        Write-Progress -Activity $title -Status (Get-WinForgeText 'conferindo a hora')
        try { $before = Get-WinForgeClockOffset } finally { Write-Progress -Activity $title -Completed }

        Write-WinForgeSection -Title (Get-WinForgeText 'Antes')
        Write-WinForgeClockState -Offset $before -NoZone
        Write-Host ""

        $synced = $false
        $setDirect = $false

        if ($disabled) {
            Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'O serviço Horário do Windows está desativado: o relógio não se acerta sozinho. O WinForge não liga um serviço desativado.')
        }
        elseif ($noSource) {
            Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'O Windows está configurado para não sincronizar o relógio. A sincronização automática fica em Configurações > Hora e idioma > Data e hora.')
        }
        else {
            Write-Progress -Activity $title -Status (Get-WinForgeText 'sincronizando o relógio')

            try {
                # O serviço costuma ficar parado até ser chamado; ligá-lo é o que o próprio Windows faz para sincronizar.
                if ($state.Status -ne "Running") { Start-WinForgeService -Name "W32Time" }
                $synced = ((Invoke-WinForgeTimeResync).ExitCode -eq 0)
            }
            catch {
                Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'O serviço Horário do Windows não respondeu: {0}.' "$(([string]$_.Exception.Message).Trim().TrimEnd('.'))")
            }
            finally {
                Write-Progress -Activity $title -Completed
            }
        }

        $after = Get-WinForgeClockOffset

        # Fora de domínio, com o relógio ainda errado e a hora do servidor lida, a pessoa decide se o relógio vai para ela.
        if ($null -ne $after -and [Math]::Abs([double]$after) -gt 10 -and -not $domain) {
            Write-Host ""
            Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'O relógio continua errado: {0}.' "$((Get-WinForgeClockOffsetText -Seconds $after).ToLower())")

            if (Confirm-WinForgeAction -Message (Get-WinForgeText 'Pôr o relógio na hora do servidor da Microsoft agora?') -DefaultKey "S" -YesLabel (Get-WinForgeText 'Acertar') -NoLabel (Get-WinForgeText 'Agora não')) {
                try {
                    [void](Set-Date -Date ((Get-Date).AddSeconds(-[double]$after)) -ErrorAction Stop)
                    $setDirect = $true

                    # Com o relógio perto da hora certa, o Windows consegue sincronizar e acertar os segundos.
                    if (-not $disabled -and -not $noSource) { $synced = ((Invoke-WinForgeTimeResync).ExitCode -eq 0) -or $synced }
                }
                catch {
                    Write-WinForgeStatus -Type Error -Message (Get-WinForgeText 'O Windows não deixou mudar o relógio: {0}.' "$(([string]$_.Exception.Message).Trim().TrimEnd('.'))")
                }

                $after = Get-WinForgeClockOffset
            }
        }

        $source = $(if ($synced) { Get-WinForgeTimeSource } else { "" })

        Write-Host ""
        Write-WinForgeSection -Title (Get-WinForgeText 'Agora')
        Write-WinForgeClockState -Offset $after
        if ($source) { Write-WinForgeKeyValue -Label (Get-WinForgeText 'Servidor de hora') -Value $source }

        if ($synced -or $setDirect) {
            [void](Add-WinForgeChange -Action $title -Text $(if ($setDirect) { (Get-WinForgeText 'relógio posto na hora do servidor da Microsoft') } elseif ($source) { (Get-WinForgeText 'relógio sincronizado com {0}' "$source") } else { (Get-WinForgeText 'relógio sincronizado') }))
        }

        $right = ($null -ne $after -and [Math]::Abs([double]$after) -le 10)
        $zone = (Get-WinForgeText 'Fuso horário: {0}.' "$([System.TimeZoneInfo]::Local.DisplayName)")
        $noSync = $(
            if ($disabled) { (Get-WinForgeText 'O serviço Horário do Windows está desativado: com o tempo, o relógio volta a errar.') }
            elseif ($noSource) { (Get-WinForgeText 'O Windows está configurado para não sincronizar o relógio: com o tempo, ele volta a errar. A sincronização automática fica em Configurações > Hora e idioma > Data e hora.') }
            else { (Get-WinForgeText 'O Windows não recebeu a hora do servidor dele. Confira a internet; uma rede que bloqueia a porta UDP 123 também impede.') }
        )

        if ($right -and $synced) {
            $final = New-WinForgeResult -Kind Ok -Detail $(if ($source) { (Get-WinForgeText 'relógio certo, sincronizado com {0}' "$source") } else { (Get-WinForgeText 'relógio certo e sincronizado') }) -Title $title
            [void](Set-WinForgeResultView -Result $final -Headline (Get-WinForgeText 'O relógio está certo') -Note $(if ($source) { (Get-WinForgeText 'Sincronizado com {0}.' "$source") } else { $zone }))
        }
        elseif ($right) {
            Write-WinForgeStatus -Type Warning -Message $noSync
            $final = New-WinForgeResult -Kind Warning -Detail (Get-WinForgeText 'o relógio está certo, mas o Windows não sincronizou') -Title $title
            [void](Set-WinForgeResultView -Result $final -Headline (Get-WinForgeText 'O relógio está certo, mas não sincroniza') -Note $noSync)
        }
        elseif ($null -ne $after) {
            $offText = (Get-WinForgeClockOffsetText -Seconds $after).ToLower()
            # Num PC de domínio, o Windows acerta aos poucos pela hora do domínio, que é quem manda ali.
            $hint = $(if ($domain) { (Get-WinForgeText 'Neste PC de empresa, a hora vem do domínio, e o Windows a acerta aos poucos: confira em alguns minutos e, se continuar, fale com o suporte de TI.') } elseif (-not $synced) { $noSync } else { (Get-WinForgeText 'Acerte em Configurações > Hora e idioma > Data e hora.') })
            Write-WinForgeStatus -Type Info -Message $hint
            $final = New-WinForgeResult -Kind $(if ($domain -and $synced) { "Warning" } else { "Failed" }) -Detail (Get-WinForgeText 'o relógio continua errado: {0}' "$offText") -Title $title
            [void](Set-WinForgeResultView -Result $final -Headline (Get-WinForgeText 'O relógio continua errado') -Note "$(ConvertTo-WinForgeHeadline -Text $offText). $hint")
        }
        elseif ($synced) {
            # Sem a hora do servidor da Microsoft para conferir, vale o que o Windows respondeu.
            $final = New-WinForgeResult -Kind Ok -Detail (Get-WinForgeText 'o Windows sincronizou o relógio') -Title $title
            [void](Set-WinForgeResultView -Result $final -Headline (Get-WinForgeText 'O Windows sincronizou o relógio') -Note $zone)
        }
        else {
            Write-WinForgeStatus -Type Info -Message $noSync
            $final = New-WinForgeResult -Kind Failed -Detail $(if ($disabled) { (Get-WinForgeText 'o serviço Horário do Windows está desativado') } elseif ($noSource) { (Get-WinForgeText 'o Windows está configurado para não sincronizar o relógio') } else { (Get-WinForgeText 'o Windows não recebeu a hora do servidor') }) -Title $title
            [void](Set-WinForgeResultView -Result $final -Headline (Get-WinForgeText 'O relógio não foi sincronizado') -Note $noSync)
        }
    }
    catch {
        Write-WinForgeStatus -Type Error -Message (Get-WinForgeText 'Não foi possível acertar a data e a hora: {0}.' "$($_.Exception.Message.TrimEnd('.'))")
        $final = New-WinForgeResult -Kind Failed -Detail $_.Exception.Message.TrimEnd('.') -Title $title
    }

    Exit-WinForgeAction -Result $final
}

Export-ModuleMember -Function *
