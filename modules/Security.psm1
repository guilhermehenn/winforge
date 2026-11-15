# Segurança: o estado da proteção do Windows (antivírus, firewall, atualizações pendentes, ameaças) e a verificação
# do Windows Defender. Tudo usa os comandos do próprio Windows (Get-MpComputerStatus, Update-MpSignature, Start-MpScan).
#
# Quando outro antivírus protege o PC, o Defender fica desligado ou em modo passivo: o WinForge diz isso e não
# tenta verificar, em vez de fingir que o PC foi checado.


# Quanto esperar antes de ler de novo o fim da verificação, quando o registro ainda não chegou (Get-WinForgeScanFinish).
$script:WinForgeScanFinishRetrySeconds = 2


# ---------------------------------------------------------------------------
# Leitura tolerante
# ---------------------------------------------------------------------------

# As propriedades dos objetos do Defender são lidas com Get-WinForgeJsonValue (Core): versões diferentes do Windows
# expõem conjuntos diferentes de propriedades, e acessar uma que não existe derrubaria a tela sob Set-StrictMode.

function ConvertTo-WinForgeMpDate {
    # O Defender usa datas antigas (1601, 1970) para "nunca aconteceu". Qualquer data antes de 2000 vira $null.
    param ($Value)

    if ($Value -isnot [datetime] -or ([datetime]$Value).Year -lt 2000) {
        return $null
    }

    return [datetime]$Value
}


function Get-WinForgeOtherAntivirus {
    <#
    Nomes dos antivírus registrados na Central de Segurança que não são o Defender e estão com a proteção em tempo real
    ligada; $null quando a consulta falha. Um antivírus só registrado (vencido, desligado) não protege: o bit 0x1000 de
    productState é o "ligado" que a própria Central de Segurança mostra. E "não consegui perguntar" não é "não há outro
    antivírus": com o Defender desligado, a diferença é entre "não foi possível ler" e "PC desprotegido".
    #>
    try {
        $products = @(Get-CimInstance -Namespace "root\SecurityCenter2" -ClassName "AntiVirusProduct" -ErrorAction Stop)
    }
    catch {
        return $null
    }

    # A vírgula impede que uma lista vazia vire $null ao sair da função ($null significa "não foi possível ler").
    return , @(
        $products |
            Where-Object { ([int64](Get-WinForgeJsonValue -Object $_ -Name "productState" -Default 0) -band 0x1000) -ne 0 } |
            ForEach-Object { [string](Get-WinForgeJsonValue -Object $_ -Name "displayName" -Default "") } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) -and $_ -notmatch '(?i)^(windows|microsoft) defender' } |
            Select-Object -Unique
    )
}


# ---------------------------------------------------------------------------
# Estado
# ---------------------------------------------------------------------------

function Get-WinForgeAntivirusStatus {
    <#
    Mode: Active (o Defender protege), Other (outro antivírus protege), Passive (Defender em modo passivo sem outro
    antivírus identificado), Off (desligado e sem outro antivírus ligado) ou Unavailable (não foi possível ler: o
    Defender não respondeu, ou ele não protege e a Central de Segurança não pôde ser consultada). DefenderRead diz se o
    Defender respondeu, para separar os dois casos de Unavailable. QuickScanMinutes é quanto a última verificação rápida
    levou ($null quando o Windows não diz).
    #>
    $computerStatus = $null

    try {
        $computerStatus = Get-MpComputerStatus -ErrorAction Stop
    }
    catch {
        $computerStatus = $null
    }

    $status = [PSCustomObject]@{
        Mode              = "Unavailable"
        DefenderRead      = ($null -ne $computerStatus)
        RealTime          = $null
        SignaturesUpdated = $null
        SignatureAgeDays  = $null
        SignaturesNeverUpdated = $false
        SignatureVersion  = ""
        TamperProtected   = $null
        LastQuickScan     = $null
        LastFullScan      = $null
        QuickScanMinutes  = $null
        Others            = @()
    }

    if ($null -eq $computerStatus) {
        # Os outros antivírus só importam quando o Defender não é quem protege: com ele ativo, a consulta à Central de
        # Segurança (WMI) seria trabalho perdido.
        $others = Get-WinForgeOtherAntivirus
        if ($null -ne $others) { $status.Others = @($others) }

        if ($status.Others.Count -gt 0) { $status.Mode = "Other" }

        return $status
    }

    $serviceOn = [bool](Get-WinForgeJsonValue -Object $computerStatus -Name "AMServiceEnabled" -Default $true)
    $antivirusOn = [bool](Get-WinForgeJsonValue -Object $computerStatus -Name "AntivirusEnabled" -Default $false)
    $runningMode = [string](Get-WinForgeJsonValue -Object $computerStatus -Name "AMRunningMode" -Default "")
    $passive = ($runningMode -match 'Passive|EDR Block')

    if (-not $serviceOn -or -not $antivirusOn -or $passive) {
        $others = Get-WinForgeOtherAntivirus
        if ($null -ne $others) { $status.Others = @($others) }

        if ($status.Others.Count -gt 0) { $status.Mode = "Other" }
        elseif ($null -eq $others) { $status.Mode = "Unavailable" }
        elseif ($passive) { $status.Mode = "Passive" }
        else { $status.Mode = "Off" }
    }
    else {
        $status.Mode = "Active"
    }

    $status.RealTime = [bool](Get-WinForgeJsonValue -Object $computerStatus -Name "RealTimeProtectionEnabled" -Default $false)
    $status.SignatureVersion = [string](Get-WinForgeJsonValue -Object $computerStatus -Name "AntivirusSignatureVersion" -Default "")

    $tamper = Get-WinForgeJsonValue -Object $computerStatus -Name "IsTamperProtected"

    if ($null -ne $tamper) {
        $status.TamperProtected = [bool]$tamper
    }

    $status.LastQuickScan = ConvertTo-WinForgeMpDate -Value (Get-WinForgeJsonValue -Object $computerStatus -Name "QuickScanEndTime")

    # Quanto a última verificação rápida levou: a linha do andamento da próxima diz isso (Get-WinForgeScanDurationText).
    $quickStart = ConvertTo-WinForgeMpDate -Value (Get-WinForgeJsonValue -Object $computerStatus -Name "QuickScanStartTime")

    if ($null -ne $quickStart -and $null -ne $status.LastQuickScan -and $status.LastQuickScan -gt $quickStart) {
        $minutes = [int][Math]::Ceiling(($status.LastQuickScan - $quickStart).TotalMinutes)
        if ($minutes -ge 1 -and $minutes -le 120) { $status.QuickScanMinutes = $minutes }
    }
    $status.LastFullScan = ConvertTo-WinForgeMpDate -Value (Get-WinForgeJsonValue -Object $computerStatus -Name "FullScanEndTime")
    $status.SignaturesUpdated = ConvertTo-WinForgeMpDate -Value (Get-WinForgeJsonValue -Object $computerStatus -Name "AntivirusSignatureLastUpdated")

    if ($null -ne $status.SignaturesUpdated) {
        $status.SignatureAgeDays = [int][math]::Max(0, [math]::Floor(((Get-Date) - $status.SignaturesUpdated).TotalDays))
    }
    elseif ([string](Get-WinForgeJsonValue -Object $computerStatus -Name "AntivirusSignatureAge" -Default "") -eq "65535") {
        # Sem data e com a idade em 65535: é como o Defender diz que as assinaturas nunca foram atualizadas (as que vêm
        # com o Windows, de meses atrás).
        $status.SignaturesNeverUpdated = $true
    }

    return $status
}


function Get-WinForgeOtherFirewall {
    <#
    Nomes dos firewalls de outros fabricantes registrados na Central de Segurança e ligados (o mesmo bit 0x1000 de
    productState do antivírus); $null quando a consulta falha. Norton, McAfee, Kaspersky, ESET e outros desligam o
    firewall do Windows e se registram ali, e a própria Segurança do Windows mostra o PC protegido.
    #>
    try {
        $products = @(Get-CimInstance -Namespace "root\SecurityCenter2" -ClassName "FirewallProduct" -ErrorAction Stop)
    }
    catch {
        return $null
    }

    # A vírgula impede que uma lista vazia vire $null ao sair da função ($null significa "não foi possível ler").
    return , @(
        $products |
            Where-Object { ([int64](Get-WinForgeJsonValue -Object $_ -Name "productState" -Default 0) -band 0x1000) -ne 0 } |
            ForEach-Object { [string](Get-WinForgeJsonValue -Object $_ -Name "displayName" -Default "") } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) -and $_ -notmatch '(?i)^(windows|microsoft)( defender)? firewall|firewall do windows' } |
            Select-Object -Unique
    )
}


function Get-WinForgeFirewallStatus {
    # Um item por perfil de rede (Domain, Private, Public) com Enabled (protegido), Product e Applies (o perfil vale para
    # este PC). $null quando não foi possível ler.
    # ActiveStore é o que vale de fato: a configuração local somada à da política de grupo (GPO) e do MDM da empresa. Sem
    # ela, o Get-NetFirewallProfile lê só a local, que pode dizer "desligado" num PC em que a política liga o firewall (ou
    # o contrário). Se o parâmetro não for aceito, fica a leitura local, melhor que nenhuma.
    try {
        $profiles = @(Get-NetFirewallProfile -PolicyStore ActiveStore -ErrorAction Stop)
    }
    catch {
        try {
            $profiles = @(Get-NetFirewallProfile -ErrorAction Stop)
        }
        catch {
            return $null
        }
    }

    if ($profiles.Count -eq 0) {
        return $null
    }

    $status = @(
        foreach ($firewallProfile in $profiles) {
            [PSCustomObject]@{
                Name    = [string](Get-WinForgeJsonValue -Object $firewallProfile -Name "Name" -Default "")
                Enabled = ([string](Get-WinForgeJsonValue -Object $firewallProfile -Name "Enabled" -Default "") -eq "True")
                Product = ""
                Applies = $true
            }
        }
    )

    # Com o firewall do Windows desligado num perfil, um firewall de outro fabricante ligado protege esse perfil: sem
    # olhar para ele, a tela, a auditoria e o Início acusariam "firewall desligado" num PC protegido. Os perfis ficam
    # como protegidos (Enabled) e Product diz por quem. Sem resposta da Central de Segurança, vale o que o Windows disse.
    if (@($status | Where-Object { -not $_.Enabled }).Count -gt 0) {
        $others = Get-WinForgeOtherFirewall

        if ($null -ne $others -and @($others).Count -gt 0) {
            $names = Join-WinForgeList -Items @($others)

            foreach ($entry in $status) {
                if (-not $entry.Enabled) {
                    $entry.Enabled = $true
                    $entry.Product = $names
                }
            }
        }
    }

    # O perfil Domínio só entra em uso num PC que faz parte de um domínio de empresa: num PC de casa, ele desligado não
    # deixa nenhuma rede sem firewall. Sem conseguir ler, vale como se valesse (melhor um aviso a mais que um a menos).
    $domainOff = @($status | Where-Object { $_.Name -eq "Domain" -and -not $_.Enabled })

    if ($domainOff.Count -gt 0) {
        $system = @(Get-WinForgeCimOrNull -ClassName "Win32_ComputerSystem") | Select-Object -First 1
        $partOfDomain = Get-WinForgeJsonValue -Object $system -Name "PartOfDomain" -Default $null

        if ($partOfDomain -is [bool] -and -not $partOfDomain) {
            foreach ($entry in $domainOff) { $entry.Applies = $false }
        }
    }

    return $status
}


function Get-WinForgeFirewallGaps {
    # Os perfis em que nenhuma rede deste PC fica protegida: desligados e em uso (Get-WinForgeFirewallStatus). A tela, a
    # auditoria, o Início e o Verificar o PC contam por aqui.
    param ($Firewall)

    return @(@($Firewall) | Where-Object { $null -ne $_ -and -not $_.Enabled -and [bool](Get-WinForgeJsonValue -Object $_ -Name "Applies" -Default $true) })
}


function Get-WinForgeFirewallOtherProduct {
    # O firewall de outro fabricante que protege algum perfil (Get-WinForgeFirewallStatus), ou "".
    param ($Firewall)

    foreach ($entry in @($Firewall)) {
        $product = [string](Get-WinForgeJsonValue -Object $entry -Name "Product" -Default "")
        if ($product) { return $product }
    }

    return ""
}


function Get-WinForgeFirewallProfileName {
    param ([string]$Name)

    switch ($Name) {
        "Domain"  { return "Domínio" }
        "Private" { return "Rede privada" }
        "Public"  { return "Rede pública" }
        default   { return $Name }
    }
}


function Get-WinForgeThreatName {
    # Nome legível de uma ameaça pelo Id; se o Windows não souber, "ameaça <Id>".
    param ($ThreatId)

    try {
        $threat = Get-MpThreat -ThreatID $ThreatId -ErrorAction Stop | Select-Object -First 1
        $name = [string](Get-WinForgeJsonValue -Object $threat -Name "ThreatName" -Default "")

        if (-not [string]::IsNullOrWhiteSpace($name)) {
            return $name
        }
    }
    catch {
        # Cai no texto genérico abaixo.
    }

    return "ameaça $ThreatId"
}


function Get-WinForgeActiveThreats {
    # Ameaças que o Defender ainda considera ativas. $null quando não foi possível ler.
    try {
        $threats = @(Get-MpThreat -ErrorAction Stop)
    }
    catch {
        return $null
    }

    # A vírgula impede que uma lista vazia vire $null ao sair da função ($null significa "não foi possível ler").
    return , @(
        $threats |
            Where-Object { [bool](Get-WinForgeJsonValue -Object $_ -Name "IsActive" -Default $false) } |
            ForEach-Object {
                $name = [string](Get-WinForgeJsonValue -Object $_ -Name "ThreatName" -Default "")
                if ([string]::IsNullOrWhiteSpace($name)) { $name = "ameaça $(Get-WinForgeJsonValue -Object $_ -Name 'ThreatID' -Default '?')" }
                $name
            } |
            Select-Object -Unique
    )
}


function New-WinForgeSecurityFinding {
    # Um ponto de atenção. Id identifica o assunto (a tela e os testes não dependem do texto); Short é o nome curto com
    # que a faixa de resultado lista os pontos ("2 ameaças ativas").
    param (
        [Parameter(Mandatory)]
        [string]$Id,

        [Parameter(Mandatory)]
        [ValidateSet("Warning", "Info")]
        [string]$Level,

        [Parameter(Mandatory)]
        [string]$Text,

        [string]$Short = ""
    )

    return [PSCustomObject]@{ Id = $Id; Level = $Level; Text = $Text; Short = $Short }
}


function Get-WinForgeSecurityNextStep {
    <#
    O botão da faixa de resultado para um ponto de atenção (da tela Estado da proteção ou da auditoria), pelo Id: Next é
    o atalho do Windows ou o item do WinForge que resolve, e Label, o texto do botão; $null quando nenhum lugar resolve
    com um clique (a conta Convidado, a entrada automática, o UAC). Os do antivírus e do firewall abrem direto a página
    certa da Segurança do Windows.
    #>
    param ([AllowEmptyString()][string]$Id)

    $open = "Abrir a Segurança do Windows"

    switch -Regex ($Id) {
        '^(antivirus|realtime|tamper|threats)'  { return [PSCustomObject]@{ Next = "WindowsSecurityThreats"; Label = $open } }
        '^firewall'                             { return [PSCustomObject]@{ Next = "WindowsSecurityFirewall"; Label = $open } }
        '^smartscreen$'                         { return [PSCustomObject]@{ Next = "WindowsSecurity"; Label = $open } }
        '^signatures'                           { return [PSCustomObject]@{ Next = "security.signatures"; Label = "Atualizar as assinaturas" } }
        '^updates$'                             { return [PSCustomObject]@{ Next = "updates.install"; Label = "Instalar as atualizações" } }
        '^windows-support$'                     { return [PSCustomObject]@{ Next = "diagnostics.windows-support"; Label = "Ver o suporte do Windows" } }
        '^smb1$'                                { return [PSCustomObject]@{ Next = "software.features"; Label = "Abrir os recursos do Windows" } }
    }

    return $null
}


function ConvertTo-WinForgeHeadline {
    # A primeira letra em maiúscula, para um texto curto virar o título da faixa ("antivírus desligado" -> "Antivírus desligado").
    param ([AllowEmptyString()][string]$Text)

    $value = ([string]$Text).Trim()
    if ($value.Length -eq 0) { return "" }

    return $value.Substring(0, 1).ToUpperInvariant() + $value.Substring(1)
}


function Get-WinForgeSecurityFindings {
    <#
    Os pontos de atenção da proteção, do mais importante ao menos. Level = Warning (agir) ou Info (saber).
    Updates e Threats nulos significam "não foi possível consultar" (ou "não consultado").
    #>
    param (
        [Parameter(Mandatory)]
        $Antivirus,

        $Firewall = $null,
        $Updates = $null,
        $Threats = $null
    )

    $findings = @()

    switch ($Antivirus.Mode) {
        "Off"         { $findings += New-WinForgeSecurityFinding -Id "antivirus-off" -Level Warning -Short "antivírus desligado" -Text "O antivírus do Windows está desligado e nenhum outro está ligado. Ligue-o em Segurança > Segurança do Windows." }
        "Unavailable" { $findings += New-WinForgeSecurityFinding -Id "antivirus-unreadable" -Level Warning -Short "antivírus sem leitura" -Text "Não foi possível ler o estado do antivírus. Confira em Segurança > Segurança do Windows." }
        "Passive"     { $findings += New-WinForgeSecurityFinding -Id "antivirus-passive" -Level Warning -Short "Defender em modo passivo" -Text "O Windows Defender está em modo passivo e nenhum outro antivírus ligado foi identificado: o PC pode estar desprotegido. Confira em Segurança > Segurança do Windows." }
        "Other"       { $findings += New-WinForgeSecurityFinding -Id "antivirus-other" -Level Info -Text "Outro antivírus protege este PC ($(Join-WinForgeList -Items @($Antivirus.Others))); o Windows Defender fica de reserva." }
        "Active" {
            if ($Antivirus.RealTime -eq $false) {
                $findings += New-WinForgeSecurityFinding -Id "realtime-off" -Level Warning -Short "proteção em tempo real desligada" -Text "A proteção em tempo real está desligada. Ligue-a em Segurança > Segurança do Windows."
            }
        }
    }

    if ($Antivirus.Mode -eq "Active" -and $null -ne $Antivirus.SignatureAgeDays) {
        $days = [int]$Antivirus.SignatureAgeDays

        if ($days -gt 7) {
            $findings += New-WinForgeSecurityFinding -Id "signatures-old" -Level Warning -Short "assinaturas com $days dias" -Text "As assinaturas do antivírus têm $days dias. Use Segurança > Atualizar assinaturas do antivírus."
        }
        elseif ($days -gt 3) {
            $findings += New-WinForgeSecurityFinding -Id "signatures-aging" -Level Info -Text "As assinaturas do antivírus têm $days dias; o normal é atualizarem todo dia."
        }
    }

    if ($null -ne $Threats -and @($Threats).Count -gt 0) {
        $count = Format-WinForgeCount -Count @($Threats).Count -One "ameaça ativa" -Many "ameaças ativas"
        $findings += New-WinForgeSecurityFinding -Id "threats" -Level Warning -Short $count -Text "${count}: $(Join-WinForgeList -Items @($Threats)). Abra Segurança > Segurança do Windows para ver as ações."
    }

    if ($null -eq $Firewall) {
        $findings += New-WinForgeSecurityFinding -Id "firewall-unreadable" -Level Info -Text "Não foi possível ler o estado do firewall."
    }
    else {
        $off = @(Get-WinForgeFirewallGaps -Firewall $Firewall | ForEach-Object { Get-WinForgeFirewallProfileName -Name $_.Name })

        if ($off.Count -gt 0) {
            $where = Join-WinForgeList -Items $off
            $findings += New-WinForgeSecurityFinding -Id "firewall-off" -Level Warning -Short "firewall desligado ($where)" -Text "O firewall está desligado em: $where. Ligue-o em Segurança > Segurança do Windows."
        }

        $otherFirewall = Get-WinForgeFirewallOtherProduct -Firewall $Firewall

        if ($otherFirewall) {
            $findings += New-WinForgeSecurityFinding -Id "firewall-other" -Level Info -Text "Outro firewall protege este PC ($otherFirewall); o firewall do Windows fica desligado."
        }
    }

    if ($null -ne $Updates -and $Updates.Count -gt 0) {
        $findings += New-WinForgeSecurityFinding -Id "updates" -Level Warning -Short (Format-WinForgeCount -Count $Updates.Count -One "atualização pendente" -Many "atualizações pendentes") `
            -Text "$(Format-WinForgeCount -Count $Updates.Count -One 'atualização do Windows pendente' -Many 'atualizações do Windows pendentes'). Use Atualizações > Instalar atualizações do Windows."
    }

    # Avisos primeiro, mantendo a ordem em que foram encontrados dentro de cada grupo.
    return @(@($findings | Where-Object { $_.Level -eq "Warning" }) + @($findings | Where-Object { $_.Level -ne "Warning" }))
}


function Get-WinForgeSecurityStatus {
    # A parte rápida do estado da proteção (antivírus, firewall e ameaças), que a tela e o relatório mostram. As
    # atualizações pendentes ficam de fora: a consulta vai até o serviço do Windows Update e demora, então a tela as
    # busca depois (Get-WinForgePendingWindowsUpdates) e o relatório nem espera por elas. Findings já vem sem elas.
    $antivirus = Get-WinForgeAntivirusStatus
    $firewall = Get-WinForgeFirewallStatus
    $threats = Get-WinForgeActiveThreats

    return [PSCustomObject]@{
        Antivirus = $antivirus
        Firewall  = $firewall
        Threats   = $threats
        Findings  = @(Get-WinForgeSecurityFindings -Antivirus $antivirus -Firewall $firewall -Threats $threats)
    }
}


function Get-WinForgeAntivirusModeText {
    param ([Parameter(Mandatory)]$Antivirus)

    switch ($Antivirus.Mode) {
        "Active"      { return $(if ($Antivirus.RealTime -eq $false) { "Windows Defender ligado, sem proteção em tempo real" } else { "Windows Defender ativo, com proteção em tempo real" }) }
        "Other"       { return "Outro antivírus em uso: $(Join-WinForgeList -Items @($Antivirus.Others))" }
        "Passive"     { return "Windows Defender em modo passivo" }
        "Off"         { return "Desligado" }
        default       { return "Não foi possível ler" }
    }
}


function Get-WinForgeSignatureText {
    param ([Parameter(Mandatory)]$Antivirus)

    if ($null -eq $Antivirus.SignaturesUpdated) {
        return $null
    }

    $text = "$(Format-WinForgeDateTime -When $Antivirus.SignaturesUpdated) ($(Format-WinForgeRelativeTime -When $Antivirus.SignaturesUpdated))"

    if ($Antivirus.SignatureVersion) {
        $text += ", versão $($Antivirus.SignatureVersion)"
    }

    return $text
}


function Get-WinForgeScanDateText {
    param ($When)

    if ($null -eq $When) {
        return "Nunca"
    }

    return "$(Format-WinForgeDateTime -When ([datetime]$When)) ($(Format-WinForgeRelativeTime -When ([datetime]$When)))"
}


function Get-WinForgeAntivirusRows {
    <#
    As linhas do antivírus (Label e Value) que a tela Estado da proteção e o relatório mostram, na mesma ordem e com os
    mesmos textos. Assinaturas e verificações são do Windows Defender: aparecem quando ele protege o PC (ou está em modo
    passivo sem outro antivírus identificado), e não ao lado do nome de outro antivírus, que tem as dele. As ameaças que
    o Defender guarda só aparecem, com outro antivírus, se houver alguma. -Brief deixa de fora a verificação completa.
    #>
    param (
        [Parameter(Mandatory)]
        $Antivirus,

        $Threats = $null,

        [switch]$Brief
    )

    $rows = New-Object System.Collections.Generic.List[object]
    # Level pinta o valor na tela (verde, amarelo, vermelho); o relatório usa só o texto.
    $modeLevel = switch ($Antivirus.Mode) { "Active" { $(if ($Antivirus.RealTime -eq $false) { "Warn" } else { "Ok" }) } "Other" { "Ok" } "Passive" { "Warn" } "Off" { "Bad" } default { "Normal" } }
    $rows.Add([PSCustomObject]@{ Label = "Situação"; Value = (Get-WinForgeAntivirusModeText -Antivirus $Antivirus); Level = $modeLevel })

    if ($Antivirus.Mode -in "Active", "Passive") {
        $signatures = Get-WinForgeSignatureText -Antivirus $Antivirus
        $age = Get-WinForgeJsonValue -Object $Antivirus -Name "SignatureAgeDays" -Default $null
        $rows.Add([PSCustomObject]@{ Label = "Assinaturas"; Value = $(if ($signatures) { $signatures } else { "Não foi possível ler" }); Level = $(if ($null -ne $age -and [int]$age -gt 7) { "Warn" } else { "Normal" }) })
    }

    if ($Antivirus.Mode -eq "Active") {
        $rows.Add([PSCustomObject]@{ Label = "Última verificação rápida"; Value = (Get-WinForgeScanDateText -When $Antivirus.LastQuickScan); Level = "Normal" })

        if (-not $Brief) {
            $rows.Add([PSCustomObject]@{ Label = "Última verificação completa"; Value = (Get-WinForgeScanDateText -When $Antivirus.LastFullScan); Level = "Normal" })
        }
    }

    if ($null -ne $Threats) {
        $list = @($Threats)

        if ($Antivirus.Mode -ne "Other") {
            # "Nenhuma" em verde só com o Defender examinando: desligado (ou sem tempo real, em modo passivo, sem leitura),
            # a lista vazia não quer dizer que o PC está limpo, só que nada foi registrado.
            $watching = ($Antivirus.Mode -eq "Active" -and $Antivirus.RealTime -ne $false)
            $none = $(if ($watching) { "Nenhuma" } elseif ($Antivirus.Mode -eq "Off") { "Nenhuma registrada (com o antivírus desligado, nada está sendo examinado)" } else { "Nenhuma registrada" })
            $rows.Add([PSCustomObject]@{ Label = "Ameaças ativas"; Value = $(if ($list.Count -eq 0) { $none } else { Join-WinForgeList -Items $list }); Level = $(if ($list.Count -gt 0) { "Bad" } elseif ($watching) { "Ok" } else { "Normal" }) })
        }
        elseif ($list.Count -gt 0) {
            $rows.Add([PSCustomObject]@{ Label = "Ameaças no Defender"; Value = (Join-WinForgeList -Items $list); Level = "Warn" })
        }
    }
    elseif ($Antivirus.Mode -eq "Active") {
        # Com outro antivírus no lugar, o Defender não responder é esperado; com ele ativo, é uma lacuna a dizer.
        $rows.Add([PSCustomObject]@{ Label = "Ameaças ativas"; Value = "Não foi possível consultar"; Level = "Normal" })
    }

    return $rows.ToArray()
}


function Show-WinForgeSecurityStatus {
    $title = "Estado da proteção"

    Enter-WinForgeAction -Title $title

    $result = $null

    try {
        # "Última verificação completa" tem 27 letras: com o tamanho padrão da coluna (24), os dois pontos saíam tortos.
        $labelWidth = 28

        # O andamento vai na barra: uma linha "Consultando..." ficaria no resumo como se a consulta continuasse.
        Write-Progress -Activity $title -Status "consultando o antivírus e o firewall"

        try {
            $status = Get-WinForgeSecurityStatus
        }
        finally {
            Write-Progress -Activity $title -Completed
        }

        $antivirus = $status.Antivirus

        Write-WinForgeSection -Title "Antivírus"

        foreach ($row in @(Get-WinForgeAntivirusRows -Antivirus $antivirus -Threats $status.Threats)) {
            Write-WinForgeKeyValue -LabelWidth $labelWidth -Label $row.Label -Value $row.Value -Level $row.Level
        }

        Write-WinForgeSection -Title "Firewall"

        if ($null -eq $status.Firewall) {
            Write-WinForgeKeyValue -LabelWidth $labelWidth -Label "Situação" -Value "Não foi possível ler"
        }
        else {
            foreach ($firewallProfile in @($status.Firewall)) {
                $product = [string](Get-WinForgeJsonValue -Object $firewallProfile -Name "Product" -Default "")
                $applies = [bool](Get-WinForgeJsonValue -Object $firewallProfile -Name "Applies" -Default $true)
                # O perfil Domínio só vale para um PC num domínio de empresa.
                $value = $(if ($product) { "Protegido por $product" } elseif ($firewallProfile.Enabled) { "Ligado" } elseif (-not $applies) { "Desligado (não vale para este PC)" } else { "Desligado" })
                $level = $(if ($firewallProfile.Enabled) { "Ok" } elseif (-not $applies) { "Normal" } else { "Bad" })
                Write-WinForgeKeyValue -LabelWidth $labelWidth -Label (Get-WinForgeFirewallProfileName -Name $firewallProfile.Name) -Value $value -Level $level
            }
        }

        # O que já se sabe aparece antes; a consulta ao Windows Update, que pode demorar, vem por último.
        Write-WinForgeSection -Title "Windows Update"
        Write-Progress -Activity "Windows Update" -Status "procurando atualizações pendentes (pode levar até um minuto e meio)"

        try {
            $updates = Get-WinForgePendingWindowsUpdates
        }
        finally {
            Write-Progress -Activity "Windows Update" -Completed
        }

        if ($null -eq $updates) {
            Write-WinForgeKeyValue -LabelWidth $labelWidth -Label "Atualizações pendentes" -Value "Não foi possível consultar (o Windows Update demorou ou está indisponível)"
        }
        elseif ($updates.Count -eq 0) {
            Write-WinForgeKeyValue -LabelWidth $labelWidth -Label "Atualizações pendentes" -Value "Nenhuma" -Level Ok
        }
        else {
            Write-WinForgeKeyValue -LabelWidth $labelWidth -Label "Atualizações pendentes" -Value $updates.Count -Level Warn

            # Os nomes como mensagens: na janela, entram no resumo (linhas soltas só apareceriam nos detalhes técnicos).
            foreach ($updateTitle in @($updates.Titles | Select-Object -First 5)) {
                Write-WinForgeStatus -Type Info -Message $updateTitle
            }

            if ($updates.Count -gt 5) {
                Write-WinForgeStatus -Type Info -Message "E mais $(Format-WinForgeCount -Count ($updates.Count - 5) -One 'atualização' -Many 'atualizações')."
            }
        }

        Write-WinForgeSection -Title "Resumo"

        $findings = @(Get-WinForgeSecurityFindings -Antivirus $antivirus -Firewall $status.Firewall -Updates $updates -Threats $status.Threats)

        # O que não pôde ser lido não conta como "em ordem": dizer que não há ponto de atenção sem ter olhado seria
        # enganoso. Também não é um problema do PC: a faixa o diz à parte, depois dos pontos de atenção. O antivírus sem
        # leitura tem a própria mensagem (sem ele, nem se sabe se o PC está protegido); o resto vai numa frase só.
        $antivirusUnread = ($antivirus.Mode -eq "Unavailable")
        $unread = @()
        if ($null -eq $status.Firewall) { $unread += "o firewall" }
        if ($null -eq $status.Threats -and $antivirus.Mode -eq "Active") { $unread += "as ameaças ativas" }
        if ($null -eq $updates) { $unread += "o Windows Update" }

        $problems = @($findings | Where-Object { $_.Level -eq "Warning" -and $_.Id -ne "antivirus-unreadable" })
        $unreadText = Join-WinForgeList -Items $unread
        $check = $(if ($null -eq $status.Firewall) { " Confira em Segurança > Segurança do Windows." } else { "" })

        if ($problems.Count -eq 0 -and -not $antivirusUnread -and $unread.Count -eq 0) {
            Write-WinForgeStatus -Type Success -Message "Nenhum ponto de atenção na proteção do PC."
        }
        elseif ($problems.Count -eq 0 -and -not $antivirusUnread) {
            Write-WinForgeStatus -Type Warning -Message "Nenhum ponto de atenção no que foi lido, mas não foi possível consultar $unreadText.$check"
        }

        # A falta de leitura do firewall já está na frase acima (ou na abaixo): não repete.
        foreach ($finding in @($findings | Where-Object { $_.Id -ne "firewall-unreadable" })) {
            Write-WinForgeStatus -Type $finding.Level -Message $finding.Text
        }

        if (($problems.Count -gt 0 -or $antivirusUnread) -and $unread.Count -gt 0) {
            Write-WinForgeStatus -Type Info -Message "Também não foi possível consultar $unreadText.$check"
        }

        if ($antivirusUnread) {
            $unread = @("o antivírus") + $unread
            $unreadText = Join-WinForgeList -Items $unread
        }

        # A faixa diz o que foi encontrado, e não só a última mensagem.
        if ($problems.Count -gt 0) {
            $detail = "$(Format-WinForgeCount -Count $problems.Count -One 'ponto de atenção' -Many 'pontos de atenção'): $(Join-WinForgeList -Items @($problems | ForEach-Object { $_.Short }))"
            if ($unread.Count -gt 0) { $detail += "; não foi possível consultar $unreadText" }

            $result = New-WinForgeResult -Kind Warning -Detail $detail
        }
        elseif ($unread.Count -gt 0) {
            $result = New-WinForgeResult -Kind Warning -Detail "nenhum ponto de atenção no que foi lido; não foi possível consultar $unreadText"
        }
        else {
            $result = New-WinForgeResult -Kind Ok -Detail "nenhum ponto de atenção"
        }

        # A faixa da janela: o título diz o que pede ação (um ponto pelo nome, vários pela conta), em vermelho quando o PC
        # está sem proteção (antivírus ou tempo real desligado, ameaça ativa, firewall desligado na rede pública), e o
        # botão leva aonde se resolve o mais grave. Antes, era sempre o amarelo de "Concluído com ressalvas", com todos os
        # pontos numa frase só.
        $publicOff = ($null -ne $status.Firewall -and @(Get-WinForgeFirewallGaps -Firewall $status.Firewall | Where-Object { $_.Name -eq "Public" }).Count -gt 0)
        # Com outro antivírus no lugar, as ameaças que o Defender guarda são ressalva (quem decide é o outro), como na auditoria.
        $severe = @($problems | Where-Object { $_.Id -in @("antivirus-off", "realtime-off") -or ($_.Id -eq "threats" -and $antivirus.Mode -ne "Other") -or ($_.Id -eq "firewall-off" -and $publicOff) })
        # Select-Object em vez de [0]: sem nenhum ponto, a lista vem vazia (e, com Set-StrictMode, o índice dá erro).
        $first = @(@($severe) + @($problems) + @($findings | Where-Object { $_.Id -eq "antivirus-unreadable" })) | Select-Object -First 1
        $step = $(if ($null -ne $first) { Get-WinForgeSecurityNextStep -Id $first.Id } else { $null })
        $unreadNote = $(if ($unread.Count -gt 0) { "Não foi possível consultar $unreadText." } else { "" })

        if ($problems.Count -eq 1) {
            $headline = ConvertTo-WinForgeHeadline -Text $problems[0].Short
            $note = (@([string]$problems[0].Text, $unreadNote) | Where-Object { $_ }) -join " "
        }
        elseif ($problems.Count -gt 1) {
            $headline = Format-WinForgeCount -Count $problems.Count -One "ponto de atenção" -Many "pontos de atenção"
            $note = (@("$(ConvertTo-WinForgeHeadline -Text (Join-WinForgeList -Items @($problems | ForEach-Object { $_.Short }))).", $unreadNote) | Where-Object { $_ }) -join " "
        }
        elseif ($unread.Count -gt 0) {
            $headline = "Nenhum ponto de atenção no que foi lido"
            $note = $unreadNote
        }
        else {
            $headline = "Nenhum ponto de atenção"
            $note = "Antivírus, firewall e atualizações do Windows em ordem."
        }

        $tone = $(if ($severe.Count -gt 0) { "Bad" } elseif ($problems.Count -gt 0 -or $unread.Count -gt 0) { "Warn" } else { "" })
        [void](Set-WinForgeResultView -Result $result -Headline $headline -Note $note -Tone $tone -Next $(if ($null -ne $step) { $step.Next } else { "" }) -NextLabel $(if ($null -ne $step) { $step.Label } else { "" }))
    }
    catch {
        Write-WinForgeStatus -Type Error -Message "Ocorreu um erro ao consultar a proteção do PC: $($_.Exception.Message)"
        $result = New-WinForgeResult -Kind Failed -Detail $_.Exception.Message
    }

    $result.Etapa = $title
    Exit-WinForgeAction -Result $result
}


# ---------------------------------------------------------------------------
# Assinaturas e verificação
# ---------------------------------------------------------------------------

function Test-WinForgeDefenderReady {
    <#
    Confere se dá para usar o Defender agora: Administrador, comandos disponíveis e o Defender sendo quem protege o PC.
    Devolve Ready e, quando não está pronto, o Result que a ação deve devolver (já com a explicação na tela e o título da
    faixa da janela). Antivirus é o estado lido na conferência ($null se parou antes, por falta de Administrador), para
    quem chama não ler de novo.
    Sem nada verificado, o resultado diz o estado do PC, como Estado da proteção e o Início: com outro antivírus no lugar
    é "Ignorado" (é com ele); o Defender desligado é falha (o PC está sem antivírus); em modo passivo ou sem resposta é
    ressalva (o PC pode estar desprotegido).
    #>
    if (-not (Test-WinForgeElevation -Reason "Esta ação exige privilégios de Administrador.")) {
        return [PSCustomObject]@{ Ready = $false; Result = (New-WinForgeResult -Kind Failed -Detail "requer Administrador"); Antivirus = $null }
    }

    $antivirus = Get-WinForgeAntivirusStatus
    $open = "Abrir a Segurança do Windows"
    $result = $null

    switch ([string]$antivirus.Mode) {
        "Active" {
            return [PSCustomObject]@{ Ready = $true; Result = $null; Antivirus = $antivirus }
        }
        "Other" {
            # Com outro antivírus, o Defender fica desligado ou em modo passivo: verificar e atualizar é com o outro.
            $names = @($antivirus.Others | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
            $list = Join-WinForgeList -Items $names

            if ($names.Count -gt 1) {
                Write-WinForgeStatus -Type Info -Message "Outros antivírus protegem este PC ($list): use um deles para verificar o PC."
                $headline = "Outros antivírus protegem este PC"
                $note = "Use um deles para verificar o PC: $list."
            }
            elseif ($names.Count -eq 1) {
                Write-WinForgeStatus -Type Info -Message "Outro antivírus protege este PC ($list): use-o para verificar o PC."
                $headline = "Outro antivírus protege este PC"
                $note = "Use o $list para verificar o PC."
            }
            else {
                Write-WinForgeStatus -Type Info -Message "Outro antivírus protege este PC: use-o para verificar o PC."
                $headline = "Outro antivírus protege este PC"
                $note = "Use-o para verificar o PC."
            }

            $result = Set-WinForgeResultView -Result (New-WinForgeResult -Kind Skipped -Detail "outro antivírus em uso") -Headline $headline -Note $note
        }
        "Passive" {
            Write-WinForgeStatus -Type Warning -Message "O Windows Defender está em modo passivo e nenhum outro antivírus ligado foi encontrado. Confira em Segurança > Segurança do Windows."
            $result = Set-WinForgeResultView -Result (New-WinForgeResult -Kind Warning -Detail "o Windows Defender está em modo passivo") `
                -Headline "O Windows Defender está em modo passivo" -Note "Nenhum outro antivírus ligado foi encontrado: o PC pode estar sem proteção." `
                -Tone Warn -Next "WindowsSecurityThreats" -NextLabel $open
        }
        "Off" {
            Write-WinForgeStatus -Type Error -Message "O antivírus do Windows está desligado e nenhum outro está ligado. Ligue-o em Segurança > Segurança do Windows."
            $result = Set-WinForgeResultView -Result (New-WinForgeResult -Kind Failed -Detail "o antivírus está desligado") `
                -Headline "Antivírus desligado" -Note "Nenhum antivírus protege o PC. Ligue o Windows Defender na Segurança do Windows." `
                -Tone Bad -Next "WindowsSecurityThreats" -NextLabel $open
        }
        default {
            if ([bool](Get-WinForgeJsonValue -Object $antivirus -Name "DefenderRead" -Default $false)) {
                # O Defender respondeu (desligado ou passivo), mas a Central de Segurança não: não dá para dizer se outro
                # antivírus protege o PC, e "o serviço não respondeu" seria falso.
                Write-WinForgeStatus -Type Warning -Message "O Windows Defender não está protegendo o PC, e não foi possível ver se outro antivírus está. Confira em Segurança > Segurança do Windows."
                $result = Set-WinForgeResultView -Result (New-WinForgeResult -Kind Warning -Detail "não foi possível confirmar qual antivírus protege o PC") `
                    -Headline "Não foi possível confirmar a proteção" -Note "O Windows Defender não está protegendo o PC, e não foi possível ver se outro antivírus está." `
                    -Tone Warn -Next "WindowsSecurityThreats" -NextLabel $open
            }
            else {
                # Os comandos do Defender podem faltar neste Windows; o mais comum é o serviço parado.
                Write-WinForgeStatus -Type Warning -Message "O Windows Defender não respondeu. Confira a proteção em Segurança > Segurança do Windows."
                $result = Set-WinForgeResultView -Result (New-WinForgeResult -Kind Warning -Detail "o Windows Defender não respondeu") `
                    -Headline "O Windows Defender não respondeu" -Note "Confira a proteção na Segurança do Windows." `
                    -Tone Warn -Next "WindowsSecurityThreats" -NextLabel $open
            }
        }
    }

    return [PSCustomObject]@{ Ready = $false; Result = $result; Antivirus = $antivirus }
}


function Test-WinForgeMmpcFallback {
    # Se o Defender pode baixar as assinaturas direto da Microsoft (MMPC) quando o caminho normal falha. Sem nada
    # configurado, a ordem de fontes do Windows termina no MMPC; uma empresa que o tirou da lista tem os motivos dela.
    $order = [string](Get-WinForgeDefenderPreference -Name "SignatureFallbackOrder")

    return ([string]::IsNullOrWhiteSpace($order) -or $order -match '(?i)\bMMPC\b')
}


function Invoke-WinForgeSignatureUpdate {
    <#
    Atualiza as assinaturas do Defender e devolve um WinForge.Result. Não abre nem fecha a ação (quem chama faz isso).
    -AssumeReady pula a conferência de Test-WinForgeDefenderReady quando quem chama já a fez; -Current traz então o
    estado do antivírus que essa conferência leu (sem ele, é lido aqui). Quando a atualização não dá certo, Data.Caveat é
    a frase que explica isso na faixa do Verificar vírus.
    #>
    param (
        [switch]$AssumeReady,
        $Current = $null
    )

    if (-not $AssumeReady) {
        $ready = Test-WinForgeDefenderReady

        if (-not $ready.Ready) {
            return $ready.Result
        }

        $Current = $ready.Antivirus
    }

    if ($null -eq $Current) {
        $Current = Get-WinForgeAntivirusStatus
    }

    $before = [string]$Current.SignatureVersion

    Write-WinForgeSection -Title "Atualização do antivírus"
    Write-WinForgeCommand -Command "Update-MpSignature"

    # O andamento vai na barra: uma linha "Baixando..." ficaria no resumo depois de terminado.
    Write-Progress -Activity "Windows Defender" -Status "baixando as assinaturas mais recentes"

    $failure = $null
    $after = $null

    try {
        try {
            [void](Update-MpSignature -ErrorAction Stop)
        }
        catch {
            $failure = $_
        }

        if ($null -eq $failure) {
            $after = Get-WinForgeAntivirusStatus
        }

        # Pelo caminho normal (o Windows Update), a atualização falha com o Windows Update desligado ou quebrado, e o
        # próprio Defender só tenta a Microsoft depois de 7 dias sem assinaturas novas. Uma segunda tentativa, direto da
        # Microsoft, resolve esses casos; só o resultado final aparece.
        $stale = ($null -ne $after -and $null -ne $after.SignatureAgeDays -and [int]$after.SignatureAgeDays -gt 3)

        if (($null -ne $failure -or $stale) -and (Test-WinForgeMmpcFallback)) {
            Write-WinForgeCommand -Command "Update-MpSignature -UpdateSource MMPC"

            try {
                [void](Update-MpSignature -UpdateSource MMPC -ErrorAction Stop)
                $failure = $null
                $after = Get-WinForgeAntivirusStatus
            }
            catch {
                Write-Host "      A segunda tentativa, direto da Microsoft, também falhou: $(Get-WinForgeDefenderErrorText -ErrorRecord $_)." -ForegroundColor DarkGray
            }
        }
    }
    finally {
        Write-Progress -Activity "Windows Defender" -Completed
    }

    if ($null -ne $failure) {
        $info = Get-WinForgeDefenderErrorInfo -ErrorRecord $failure
        Write-WinForgeStatus -Type Error -Message "O antivírus não foi atualizado: $($info.Full)."

        # "Confira a internet" só quando o erro é de conexão: com outro motivo, despistaria.
        if ($info.Network) {
            Write-WinForgeStatus -Type Info -Message "Confira a conexão com a internet e tente de novo."
        }

        return (New-WinForgeResult -Kind Failed -Detail "o antivírus não foi atualizado: $($info.Text)" -Data @{ Caveat = "O antivírus não foi atualizado: $($info.Text)." })
    }

    if ($null -eq $after.SignatureAgeDays) {
        # O Windows não devolveu a data das assinaturas: sem ela não dá para dizer "em dia".
        Write-WinForgeStatus -Type Warning -Message "O Windows não informou a data das assinaturas; confira em Segurança > Segurança do Windows."
        return (New-WinForgeResult -Kind Warning -Detail "não foi possível confirmar a data das assinaturas" -Data @{ SignatureVersion = $after.SignatureVersion; Caveat = "Não foi possível confirmar se o antivírus está atualizado." })
    }

    if ($after.SignatureAgeDays -gt 3) {
        Write-WinForgeStatus -Type Warning -Message "O antivírus continua desatualizado: as assinaturas têm $($after.SignatureAgeDays) dias."
        Write-Host "      Assinaturas: $(Get-WinForgeSignatureText -Antivirus $after)." -ForegroundColor DarkGray
        return (New-WinForgeResult -Kind Warning -Detail "as assinaturas continuam com $($after.SignatureAgeDays) dias" -Data @{ SignatureVersion = $after.SignatureVersion; Caveat = "As assinaturas do antivírus continuam com $($after.SignatureAgeDays) dias." })
    }

    $changed = ($before -and $after.SignatureVersion -and $before -ne $after.SignatureVersion)
    $same = ($before -and $before -eq $after.SignatureVersion)

    # A linha do resumo é curta; a data e as versões ficam nos detalhes técnicos.
    Write-WinForgeStatus -Type Success -Message $(if ($same) { "O antivírus já estava atualizado." } else { "Antivírus atualizado." })
    Write-Host "      Assinaturas: $(Get-WinForgeSignatureText -Antivirus $after)$(if ($changed) { "; antes: $before" })." -ForegroundColor DarkGray

    # A faixa diz se veio algo novo: com as assinaturas já em dia, o Windows não baixa nada, e isso também é "em dia".
    $detail = $(
        if ($changed) { "assinaturas atualizadas agora" }
        elseif ($same) { "as assinaturas já estavam em dia" }
        else { "assinaturas em dia" }
    )

    return (New-WinForgeResult -Kind Ok -Detail $detail -Data @{ SignatureVersion = $after.SignatureVersion })
}


function Get-WinForgeThreatStatusText {
    <#
    O que o Defender fez com uma ameaça (ThreatStatusID de Get-MpThreatDetection), em poucas palavras, e Resolved, se ela
    já não oferece risco. 2 limpa, 3 em quarentena, 4 removida e 6 bloqueada estão resolvidas; 5 é a ameaça que alguém
    permitiu; 1 (detectada), as falhas (101 a 107) e o que o Defender não informou pedem ação.
    #>
    param ($StatusId)

    $id = -1
    if ($null -ne $StatusId) { [void][int]::TryParse([string]$StatusId, [ref]$id) }

    switch ($id) {
        2 { return [PSCustomObject]@{ Text = "limpa"; Resolved = $true } }
        3 { return [PSCustomObject]@{ Text = "em quarentena"; Resolved = $true } }
        4 { return [PSCustomObject]@{ Text = "removida"; Resolved = $true } }
        6 { return [PSCustomObject]@{ Text = "bloqueada"; Resolved = $true } }
        5 { return [PSCustomObject]@{ Text = "liberada por alguém"; Resolved = $false } }
        { $_ -in 101, 102, 103, 104, 105, 107 } { return [PSCustomObject]@{ Text = "não resolvida"; Resolved = $false } }
        1 { return [PSCustomObject]@{ Text = "pede ação"; Resolved = $false } }
        default { return [PSCustomObject]@{ Text = "situação desconhecida"; Resolved = $false } }
    }
}


function Get-WinForgeDefenderNeeds {
    <#
    O que o Windows Defender ainda pede para terminar o serviço, pelos bits que ele publica: Reboot, OfflineScan,
    FullScan e Manual. DetectionMask é o AdditionalActionsBitMask de uma detecção (4 verificação completa, 8 reiniciar, 16
    ação manual, 32768 verificação offline; um bit desconhecido conta como ação manual); ComputerState é o do PC inteiro,
    de Get-MpComputerStatus (1 verificação completa, 2 reiniciar, 4 ação manual, 8 verificação offline).
    #>
    param (
        [int64]$DetectionMask = 0,
        [int64]$ComputerState = 0
    )

    $needs = @()

    if (($DetectionMask -band 8) -ne 0 -or ($ComputerState -band 2) -ne 0) { $needs += "Reboot" }
    if (($DetectionMask -band 32768) -ne 0 -or ($ComputerState -band 8) -ne 0) { $needs += "OfflineScan" }
    if (($DetectionMask -band 4) -ne 0 -or ($ComputerState -band 1) -ne 0) { $needs += "FullScan" }
    if (($DetectionMask -band 16) -ne 0 -or ($ComputerState -band 4) -ne 0 -or ($DetectionMask -band (-bnot [int64]32796)) -ne 0) { $needs += "Manual" }

    # Quem chama põe a lista em @(...): nenhuma é uma lista vazia.
    return $needs
}


function Get-WinForgeDefenderNeedText {
    # O que completa "o Windows Defender pede ...": "para reiniciar o PC", "a verificação completa"...
    param ([AllowEmptyCollection()][string[]]$Needs = @())

    $texts = @(
        foreach ($need in @($Needs)) {
            switch ($need) {
                "Reboot" { "para reiniciar o PC" }
                "OfflineScan" { "a verificação offline" }
                "FullScan" { "a verificação completa" }
                default { "uma ação sua" }
            }
        }
    )

    return (Join-WinForgeList -Items @($texts | Select-Object -Unique))
}


function Get-WinForgeThreatShortName {
    <#
    O nome de uma ameaça como a pessoa lê: "Trojan:Win32/Wacatac.H!ml" vira "Wacatac (trojan)". O nome completo do
    Windows Defender, o que se procura na internet, fica nos detalhes técnicos. Fora desse formato, o nome como veio.
    #>
    param ([AllowEmptyString()][string]$Name)

    if ($Name -notmatch '^(?<category>[A-Za-z]+):[^/:]+/(?<family>[^.!/]+)') { return $Name }

    $family = $Matches["family"]
    $category = $Matches["category"]

    $kind = switch -Regex ($category) {
        '^(?i)ransom' { "ransomware"; break }
        '^(?i)(trojanspy|spyware|pws|keylogger)$' { "spyware"; break }
        '^(?i)trojan' { "trojan"; break }
        '^(?i)backdoor$' { "backdoor"; break }
        '^(?i)worm$' { "worm"; break }
        '^(?i)virus$' { "vírus"; break }
        '^(?i)(pua|softwarebundler|app$)' { "programa indesejado"; break }
        '^(?i)behavior$' { "comportamento suspeito"; break }
        '^(?i)(hacktool|virtool)$' { "ferramenta de invasão"; break }
        '^(?i)exploit$' { "exploit"; break }
        '^(?i)(adware|browsermodifier)$' { "adware"; break }
        default { "" }
    }

    if ($kind) { return "$family ($kind)" }

    return $family
}


function Get-WinForgeDetectionIds {
    <#
    Os DetectionID das detecções que o Windows Defender já guarda. Lidos antes de uma verificação, separam o que ela achou
    do que já estava lá, sem depender do relógio (um ajuste da hora ou o horário de verão no meio dela). $null quando não
    foi possível ler.
    #>
    try {
        $all = @(Get-MpThreatDetection -ErrorAction Stop)
    }
    catch {
        return $null
    }

    # A vírgula impede que uma lista vazia vire $null ao sair da função ($null significa "não foi possível ler").
    return , @($all | ForEach-Object { [string](Get-WinForgeJsonValue -Object $_ -Name "DetectionID" -Default "") } | Where-Object { $_ })
}


function Get-WinForgeScanDetections {
    <#
    O que a verificação achou: Found, um item por ameaça detectada por ela (ThreatID, Name, ShortName, Resources, Status,
    Resolved e Needs, o que o Defender ainda pede), e Leftover, as ameaças de antes que o Defender ainda considera ativas
    (sem as achadas agora). $null se o Windows não deixou consultar.
    Waiting diz que o Defender já agiu e só espera um passo do PC (Needs).
    Uma detecção é desta verificação quando o DetectionID dela não estava em Known (lido antes de começar). Sem o
    DetectionID, vale a hora da detecção (InitialDetectionTime, comparada em UTC): a última mudança de uma detecção antiga
    também pode ser alguém limpando-a na Segurança do Windows, e ela não foi achada por esta verificação.
    #>
    param (
        [Parameter(Mandatory)]
        [datetime]$Since,

        [AllowNull()]
        [AllowEmptyCollection()]
        [string[]]$Known = $null
    )

    try {
        $detections = @(Get-MpThreatDetection -ErrorAction Stop)
    }
    catch {
        return $null
    }

    $sinceUtc = $Since.ToUniversalTime()

    $recent = @(
        $detections | Where-Object {
            $detectionId = [string](Get-WinForgeJsonValue -Object $_ -Name "DetectionID" -Default "")

            if ($null -ne $Known -and $detectionId) { return ($Known -notcontains $detectionId) }

            $when = Get-WinForgeJsonValue -Object $_ -Name "InitialDetectionTime" -Default $null
            return ($when -is [datetime] -and $when.ToUniversalTime() -ge $sinceUtc)
        }
    )

    # Os nomes e as ameaças ainda ativas numa consulta só; sem ela, os nomes vêm um a um e as de antes ficam sem leitura.
    $names = @{}
    $active = @()
    $threatsRead = $false

    try {
        foreach ($threat in @(Get-MpThreat -ErrorAction Stop)) {
            $id = [string](Get-WinForgeJsonValue -Object $threat -Name "ThreatID" -Default "")
            $name = [string](Get-WinForgeJsonValue -Object $threat -Name "ThreatName" -Default "")
            if ($id -and $name) { $names[$id] = $name }

            if ([bool](Get-WinForgeJsonValue -Object $threat -Name "IsActive" -Default $false)) { $active += $threat }
        }

        $threatsRead = $true
    }
    catch {
        $threatsRead = $false
    }

    # A mais recente de cada ameaça diz o que o Defender fez por último.
    $lastChange = {
        param ($Detection)

        $latest = $null

        foreach ($field in @("InitialDetectionTime", "LastThreatStatusChangeTime", "RemediationTime")) {
            $when = Get-WinForgeJsonValue -Object $Detection -Name $field -Default $null
            if ($when -is [datetime] -and ($null -eq $latest -or $when -gt $latest)) { $latest = $when }
        }

        $latest
    }

    $found = @()

    foreach ($group in @($recent | Group-Object -Property { [string](Get-WinForgeJsonValue -Object $_ -Name "ThreatID" -Default "") })) {
        $latest = $group.Group | Sort-Object -Property { & $lastChange $_ } -Descending | Select-Object -First 1
        $resources = @($group.Group | ForEach-Object { Get-WinForgeJsonValue -Object $_ -Name "Resources" -Default @() } | ForEach-Object { $_ } | Select-Object -Unique)
        $threatId = [string](Get-WinForgeJsonValue -Object $latest -Name "ThreatID" -Default "")
        $status = Get-WinForgeThreatStatusText -StatusId (Get-WinForgeJsonValue -Object $latest -Name "ThreatStatusID" -Default $null)

        # Resolvida pela situação, mas com a ação mal-sucedida ou com outra ação pedida (reiniciar, verificação completa
        # ou offline): ainda não está resolvida, e a linha diz o que falta.
        $actionOk = Get-WinForgeJsonValue -Object $latest -Name "ActionSuccess" -Default $null
        $mask = 0L
        [void][int64]::TryParse([string](Get-WinForgeJsonValue -Object $latest -Name "AdditionalActionsBitMask" -Default 0), [ref]$mask)
        $needs = @(Get-WinForgeDefenderNeeds -DetectionMask $mask)
        $waiting = $false

        if ($status.Resolved -and $actionOk -eq $false) {
            $status = [PSCustomObject]@{ Text = "não resolvida"; Resolved = $false }
        }
        elseif ($status.Resolved -and $needs.Count -gt 0) {
            # O Defender agiu e só espera um passo do PC: reiniciar, a verificação completa ou a offline.
            $status = [PSCustomObject]@{ Text = "pede $(Get-WinForgeDefenderNeedText -Needs $needs)"; Resolved = $false }
            $waiting = $true
        }

        $name = $(if ($names.ContainsKey($threatId)) { $names[$threatId] } else { Get-WinForgeThreatName -ThreatId $threatId })

        $found += [PSCustomObject]@{
            ThreatID  = $threatId
            Name      = $name
            ShortName = (Get-WinForgeThreatShortName -Name $name)
            Resources = @($resources)
            Status    = $status.Text
            Resolved  = [bool]$status.Resolved
            Needs     = @($needs)
            Waiting   = $waiting
        }
    }

    # Uma ameaça de antes, ainda ativa, não aparece como detecção nova: dizer só "nenhuma ameaça" (ou "resolvida") seria
    # enganoso. As achadas agora não entram duas vezes.
    $foundIds = @($found | ForEach-Object { [string]$_.ThreatID })
    $leftover = @()

    if ($threatsRead) {
        foreach ($threat in $active) {
            $id = [string](Get-WinForgeJsonValue -Object $threat -Name "ThreatID" -Default "")
            if ($id -and $foundIds -contains $id) { continue }

            $name = [string](Get-WinForgeJsonValue -Object $threat -Name "ThreatName" -Default "")
            if ([string]::IsNullOrWhiteSpace($name)) { $name = "ameaça $(if ($id) { $id } else { '?' })" }

            $leftover += [PSCustomObject]@{
                ThreatID  = $id
                Name      = $name
                ShortName = (Get-WinForgeThreatShortName -Name $name)
                Resources = @(Get-WinForgeJsonValue -Object $threat -Name "Resources" -Default @() | ForEach-Object { $_ })
                Status    = "ativa desde antes"
                Resolved  = $false
                Needs     = @()
                Waiting   = $false
            }
        }
    }

    return [PSCustomObject]@{ Found = @($found); Leftover = @($leftover) }
}


function ConvertTo-WinForgeThreatResourceText {
    <#
    Onde a ameaça estava, como o Defender guarda ("file:_C:\pasta\arquivo.exe", "containerfile:_..."): sem o prefixo do
    tipo, que não diz nada para a pessoa. Um arquivo baixado ("webfile:_C:\...|https://site/a.exe|pid:123,...") fica só
    com o caminho; um processo ou um comportamento ("process:_pid:4321,ProcessStart:...", "behavior:_pid:4321:7378...")
    vira "programa em execução (processo 4321)".
    #>
    param ([AllowEmptyString()][string]$Resource)

    $text = [string]$Resource

    if ($text -match '^(?i)(process|behavior):_pid:([0-9]+)') { return "programa em execução (processo $($Matches[2]))" }

    $text = ($text -replace '^(?i)[a-z]+:_', '')
    if ($text.Contains("|")) { $text = $text.Substring(0, $text.IndexOf("|")) }

    return $text.Trim()
}


function Write-WinForgeThreatLine {
    <#
    Uma linha curta por ameaça no resumo: o nome legível, o que o Defender fez e o arquivo ("Wacatac (trojan) · em
    quarentena · setup.exe e mais 2"). O nome completo e os caminhos inteiros vão para os detalhes técnicos. A resolvida
    tem o ícone de feito; a que ainda pede ação, o de erro.
    #>
    param ([Parameter(Mandatory)]$Threat)

    $places = @($Threat.Resources | ForEach-Object { ConvertTo-WinForgeThreatResourceText -Resource ([string]$_) } | Where-Object { $_ } | Select-Object -Unique)
    $line = "$($Threat.ShortName) · $($Threat.Status)"

    if ($places.Count -gt 0) {
        $first = [string]$places[0]

        # Só o nome do arquivo (as barras do Windows, também quando o texto vem de outro sistema).
        if ($first -notmatch '^programa em execução') {
            $segments = @($first -split '[\\/]' | Where-Object { $_ })
            if ($segments.Count -gt 0) { $first = [string]$segments[$segments.Count - 1] }
        }

        $line += " · $first"
        if ($places.Count -gt 1) { $line += " e mais $($places.Count - 1)" }
    }

    Write-WinForgeStatus -Type $(if ($Threat.Resolved) { "Success" } else { "Error" }) -Message $line

    if ($places.Count -gt 0 -or $Threat.ShortName -ne $Threat.Name) {
        Write-Host "      $($Threat.Name)$(if ($places.Count -gt 0) { ': ' + ($places -join '; ') })" -ForegroundColor DarkGray
    }
}


function Write-WinForgeScanIntro {
    # O que a verificação faz e quanto demora, quando isso não cabe na linha do andamento. Vem antes de começar (na
    # completa, antes da pergunta): na janela, estas mensagens ficam no resumo, acima dos botões. Na rápida, o tempo vai
    # na linha do andamento (Get-WinForgeScanDurationText).
    param (
        [Parameter(Mandatory)]
        [ValidateSet("Quick", "Full", "Custom")]
        [string]$Type,

        [string]$Path = ""
    )

    # O Defender cuida sozinho do que encontrar (quarentena ou remoção): a pessoa só age depois, se alguma ameaça ainda
    # pedir ação.
    switch ($Type) {
        "Full" {
            Write-WinForgeStatus -Type Info -Message "Examina todos os arquivos: leva horas e deixa o PC mais lento."

            # Por padrão, a completa não entra em pen drives e discos USB: quem espera que eles sejam examinados precisa saber.
            if ((Get-WinForgeDefenderPreference -Name "DisableRemovableDriveScanning") -eq $true) {
                Write-WinForgeStatus -Type Info -Message "Pen drives e discos USB ficam de fora; para eles, use Segurança > Verificar uma pasta."
            }
        }
        "Custom" { Write-WinForgeStatus -Type Info -Message "Examina somente: $Path" }
    }
}


function Get-WinForgeScanDurationText {
    # A linha do andamento da verificação, que não tem porcentagem: quanto a rápida levou da última vez neste PC (o estado
    # do antivírus lido na conferência, quando o Windows diz), ou quanto costuma levar.
    param (
        [Parameter(Mandatory)]
        [string]$Type,

        [string]$Path = "",

        $Antivirus = $null
    )

    switch ($Type) {
        "Full" { return "pode levar horas" }
        "Custom" { return "examinando $Path" }
    }

    $minutes = Get-WinForgeJsonValue -Object $Antivirus -Name "QuickScanMinutes" -Default $null

    if ($null -ne $minutes) { return "a última levou cerca de $minutes min" }

    return "costuma levar de 2 a 15 minutos"
}


function Get-WinForgeDefenderErrorCode {
    # O código HRESULT de um erro do Defender ("0x80072EE7"), ou "". Os cmdlets do Defender o põem no identificador do erro
    # ("HRESULT 0x80070002,Update-MpSignature"), e não na mensagem, que é só "a atualização terminou com erros".
    param ([Parameter(Mandatory)]$ErrorRecord)

    $texts = @()
    if ($ErrorRecord -is [System.Management.Automation.ErrorRecord]) { $texts += [string]$ErrorRecord.FullyQualifiedErrorId; $texts += [string]$ErrorRecord.Exception.Message }
    elseif ($ErrorRecord -is [System.Exception]) { $texts += [string]$ErrorRecord.Message }
    else { $texts += [string]$ErrorRecord }

    foreach ($text in $texts) {
        if ($text -match '0x([0-9A-Fa-f]{8})') { return "0x$($Matches[1].ToUpperInvariant())" }
    }

    return ""
}


function Test-WinForgeDefenderNetworkError {
    # Se o erro é de conexão com a internet: só então "confira a internet" ajuda. Um erro sem código não é tomado como de
    # conexão (um acesso negado também chega sem código).
    param ([Parameter(Mandatory)]$ErrorRecord)

    return ((Get-WinForgeDefenderErrorCode -ErrorRecord $ErrorRecord) -in @("0x80072EE7", "0x8024402C", "0x80072EFD", "0x80072EFE", "0x80072EE2", "0x8024401C"))
}


function Get-WinForgeDefenderErrorInfo {
    <#
    Um erro do Defender em português, para os códigos mais comuns ao baixar assinaturas ou verificar: Text é a frase
    ("o PC não encontrou o servidor, sem internet ou sem DNS"), Full a frase com o código ("... (erro 0x80072EE7)"), Code
    o código e Network se é de conexão. Sem código conhecido, a mensagem do Windows como veio.
    #>
    param ([Parameter(Mandatory)]$ErrorRecord)

    $exception = $(if ($ErrorRecord -is [System.Management.Automation.ErrorRecord]) { $ErrorRecord.Exception } elseif ($ErrorRecord -is [System.Exception]) { $ErrorRecord } else { $null })
    $message = $(if ($null -ne $exception) { [string]$exception.Message } else { [string]$ErrorRecord })
    $code = Get-WinForgeDefenderErrorCode -ErrorRecord $ErrorRecord

    $text = switch ($code) {
        "0x80072EE7" { "o PC não encontrou o servidor, sem internet ou sem DNS" }
        "0x8024402C" { "o PC não encontrou o servidor, sem internet, sem DNS ou com o proxy errado" }
        "0x80072EFD" { "não foi possível conectar ao servidor, sem internet ou com um firewall ou proxy bloqueando" }
        "0x80072EFE" { "a conexão com o servidor caiu" }
        "0x80072EE2" { "a conexão com o servidor esgotou o tempo" }
        "0x8024401C" { "o servidor de atualizações demorou demais para responder" }
        "0x80244022" { "o servidor de atualizações está sobrecarregado; tente mais tarde" }
        "0x8024401B" { "o proxy pede usuário e senha" }
        "0x80072F8F" { "a conexão segura com o servidor falhou; confira a data e a hora do PC" }
        "0x80072F78" { "o servidor respondeu com dados inválidos" }
        "0x80070652" { "outra instalação está em andamento; tente de novo em alguns minutos" }
        "0x80070422" { "um serviço de que a atualização precisa, geralmente o Windows Update, está desativado" }
        "0x80240022" { "o Windows Update não conseguiu instalar a atualização" }
        "0x8024402F" { "o Windows Update encontrou erros no pacote da atualização" }
        "0x800106BA" { "o serviço do Windows Defender não iniciou" }
        "0x8007139F" { "o Windows Defender não está pronto: desligado ou substituído por outro antivírus" }
        "0x800704EC" { "uma política do Windows bloqueia o Windows Defender" }
        "0x80070005" { "o Windows negou o acesso" }
        "0x80508018" { "a verificação foi interrompida antes do fim" }
        "0x80508007" { "faltou memória para o Windows Defender" }
        "0x8050800C" { "o Windows Defender teve um erro interno; reinicie o PC e tente de novo" }
        "0x80508023" { "a ameaça não está mais no lugar, ou algo impediu a verificação" }
        "0x80508031" { "o Windows Defender está desatualizado; atualize o Windows" }
        default { "" }
    }

    if ($text) {
        return [PSCustomObject]@{ Text = $text; Full = "$text (erro $code)"; Code = $code; Network = (Test-WinForgeDefenderNetworkError -ErrorRecord $ErrorRecord) }
    }

    $message = (ConvertTo-WinForgeReadableError -Text $message).Trim().TrimEnd(".")
    $full = $message
    if ($code -and $message -notmatch [regex]::Escape($code.Substring(2))) { $full += " (erro $code)" }

    return [PSCustomObject]@{ Text = $message; Full = $full; Code = $code; Network = (Test-WinForgeDefenderNetworkError -ErrorRecord $ErrorRecord) }
}


function Get-WinForgeDefenderErrorText {
    # O erro do Defender em português, com o código: "frase (erro 0x80072EE7)" (Get-WinForgeDefenderErrorInfo).
    param ([Parameter(Mandatory)]$ErrorRecord)

    return [string](Get-WinForgeDefenderErrorInfo -ErrorRecord $ErrorRecord).Full
}


function Get-WinForgeDefenderPreference {
    # Uma preferência do Defender (Get-MpPreference), ou $null quando não foi possível ler.
    param ([Parameter(Mandatory)][string]$Name)

    try {
        return (Get-WinForgeJsonValue -Object (Get-MpPreference -ErrorAction Stop) -Name $Name -Default $null)
    }
    catch {
        return $null
    }
}


function Test-WinForgeNetworkPath {
    # Se o caminho está na rede: \\servidor\pasta, ou uma unidade mapeada (Z:).
    param ([AllowEmptyString()][string]$Path)

    # \\?\C:\... e \\.\ são caminhos locais escritos do jeito longo, não pastas de rede.
    if ($Path -match '^[\\/]{2}(?![?.][\\/])') { return $true }

    try {
        $root = [System.IO.Path]::GetPathRoot($Path)
        if ([string]::IsNullOrWhiteSpace($root)) { return $false }

        return ((New-Object System.IO.DriveInfo($root)).DriveType -eq [System.IO.DriveType]::Network)
    }
    catch {
        return $false
    }
}


function Test-WinForgeNetworkScanSkipped {
    # Se o Defender vai pular os arquivos deste caminho: ele está na rede e o Defender não examina arquivos de rede
    # (DisableScanningNetworkFiles, ligado por padrão). Sem ler a preferência, não afirma nada.
    param ([AllowEmptyString()][string]$Path)

    if (-not (Test-WinForgeNetworkPath -Path $Path)) { return $false }

    return ((Get-WinForgeDefenderPreference -Name "DisableScanningNetworkFiles") -eq $true)
}


function Get-WinForgeMpCmdRunPath {
    # O MpCmdRun.exe do Defender: a pasta de plataforma mais nova (Windows atual) ou a antiga, em Arquivos de Programas.
    $candidates = @()

    try {
        $platform = Join-Path $env:ProgramData "Microsoft\Windows Defender\Platform"

        if (Test-Path -LiteralPath $platform -PathType Container) {
            $candidates += @(
                Get-ChildItem -LiteralPath $platform -Directory -ErrorAction Stop |
                    Sort-Object { try { [version]($_.Name -replace '[^0-9.].*$', '') } catch { [version]"0.0" } } -Descending |
                    ForEach-Object { Join-Path $_.FullName "MpCmdRun.exe" }
            )
        }
    }
    catch {
        # Sem a pasta de plataforma, vale o caminho clássico.
    }

    $candidates += (Join-Path $env:ProgramFiles "Windows Defender\MpCmdRun.exe")

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
    }

    return $null
}


function Stop-WinForgeDefenderScan {
    # Pede ao Defender que cancele a verificação rápida ou completa em andamento (MpCmdRun -Scan -Cancel). O Parar
    # interrompe o Start-MpScan, mas não a verificação, que roda no próprio Defender: sem isto, ela continuaria escondida,
    # consumindo o PC. Devolve se o Defender aceitou o pedido; melhor esforço.
    $path = Get-WinForgeMpCmdRunPath

    if ($null -eq $path) { return $false }

    try {
        $run = Invoke-WinForgeCapture -FilePath $path -Arguments @("-Scan", "-Cancel")
        return ($run.ExitCode -eq 0)
    }
    catch {
        return $false
    }
}


function Write-WinForgeScanStopped {
    # Depois do Parar: cancela a verificação no Defender e diz o que aconteceu. A de uma pasta não tem como ser cancelada
    # por fora (o pedido do MpCmdRun vale para a rápida e a completa, e cancelaria outra que estivesse rodando).
    param ([Parameter(Mandatory)][string]$Type)

    if ($Type -eq "Custom") {
        Write-WinForgeStatus -Type Warning -Message "Verificação interrompida; o Windows Defender pode continuar examinando a pasta até o fim."
        return
    }

    if (Stop-WinForgeDefenderScan) {
        Write-WinForgeStatus -Type Warning -Message "Verificação cancelada."
    }
    else {
        Write-WinForgeStatus -Type Warning -Message "Verificação interrompida; o Windows Defender pode continuar até o fim. Confira em Segurança > Segurança do Windows."
    }
}


function Get-WinForgeScanFinish {
    <#
    O que o Windows Defender registrou depois da verificação. Confirmed: $true quando o fim da rápida (ou da completa)
    registrado é de depois do começo desta; $false quando o último fim registrado é de antes, ou seja, esta não chegou ao
    fim (cancelada por fora, por exemplo); $null quando não dá para saber (a verificação de uma pasta não deixa registro,
    ou o Windows não respondeu). Needs: o que o Defender ainda pede ao PC inteiro (ComputerState).
    #>
    param (
        [Parameter(Mandatory)][string]$Type,
        [Parameter(Mandatory)][datetime]$Since
    )

    $field = switch ($Type) { "Quick" { "QuickScanEndTime" } "Full" { "FullScanEndTime" } default { "" } }
    $confirmed = $null
    $state = 0L

    for ($attempt = 0; $attempt -lt 2; $attempt++) {
        $status = $null

        try {
            $status = Get-MpComputerStatus -ErrorAction Stop
        }
        catch {
            $status = $null
        }

        if ($null -eq $status) { break }

        [void][int64]::TryParse([string](Get-WinForgeJsonValue -Object $status -Name "ComputerState" -Default 0), [ref]$state)

        if (-not $field) { break }

        $end = ConvertTo-WinForgeMpDate -Value (Get-WinForgeJsonValue -Object $status -Name $field)
        if ($null -eq $end) { break }

        # Uma folga de segundos para o relógio; o fim de verdade é sempre depois do começo.
        $confirmed = ($end.ToUniversalTime() -ge $Since.ToUniversalTime().AddSeconds(-5))

        # O registro pode chegar um instante depois de o Start-MpScan voltar: confere mais uma vez antes de duvidar.
        if ($confirmed -or $attempt -gt 0) { break }

        Start-Sleep -Seconds $script:WinForgeScanFinishRetrySeconds
    }

    return [PSCustomObject]@{ Confirmed = $confirmed; Needs = @(Get-WinForgeDefenderNeeds -ComputerState $state) }
}


function ConvertTo-WinForgeScanFailure {
    # O resultado de um Start-MpScan que falhou. Uma verificação do próprio Windows já em andamento (a agendada, ou uma
    # aberta na Segurança do Windows) não é defeito: é ressalva, e basta verificar de novo quando ela terminar.
    param (
        [Parameter(Mandatory)]$ErrorRecord,
        [Parameter(Mandatory)][string]$Type
    )

    $message = $(if ($ErrorRecord -is [System.Management.Automation.ErrorRecord]) { [string]$ErrorRecord.Exception.Message } else { [string]$ErrorRecord })

    if ($message -match '(?i)scan is already in progress|verifica\S* j\S* est\S* em andamento') {
        Write-WinForgeStatus -Type Warning -Message "Já havia uma verificação do Windows Defender em andamento; verifique de novo quando ela terminar."
        return (Set-WinForgeResultView -Result (New-WinForgeResult -Kind Warning -Detail "outra verificação do Windows Defender já estava em andamento" -Data @{ ScanType = $Type }) `
            -Headline "Já havia uma verificação em andamento" -Note "Verifique de novo quando ela terminar." -Tone Warn)
    }

    $info = Get-WinForgeDefenderErrorInfo -ErrorRecord $ErrorRecord
    Write-WinForgeStatus -Type Error -Message "A verificação não foi concluída: $($info.Full)."

    return (New-WinForgeResult -Kind Failed -Detail $info.Text -Data @{ ScanType = $Type })
}


function Get-WinForgeScanOutcome {
    <#
    Escreve o que a verificação achou (uma linha curta por ameaça) e devolve o WinForge.Result, com o título da faixa da
    janela. Do mais grave ao mais leve: ameaças que pedem ação (vermelho, com o botão para a Segurança do Windows), o
    Defender pedindo mais um passo ao PC (reiniciar, verificação completa ou offline), a verificação sem registro de fim,
    ameaças achadas e já resolvidas, e nada encontrado.
    #>
    param (
        [Parameter(Mandatory)][string]$Type,
        [string]$Path = "",
        [Parameter(Mandatory)]$Scan,
        [Parameter(Mandatory)]$Finish,
        [bool]$NetworkNote = $false
    )

    $found = @($Scan.Found)
    $leftover = @($Scan.Leftover)
    $pendingFound = @($found | Where-Object { -not [bool]$_.Resolved })
    $pendingCount = $pendingFound.Count + $leftover.Count
    $unconfirmed = ($Finish.Confirmed -eq $false)
    $open = "Abrir a Segurança do Windows"
    $data = @{ ScanType = $Type; ThreatCount = $found.Count; PendingThreats = $pendingCount; ActiveThreats = $leftover.Count }

    foreach ($threat in @($found) + @($leftover)) {
        Write-WinForgeThreatLine -Threat $threat
    }

    if ($unconfirmed) {
        Write-WinForgeStatus -Type Warning -Message "O Windows Defender não registrou o fim da verificação; ela pode ter sido interrompida."
    }

    $foundText = Format-WinForgeCount -Count $found.Count -One "ameaça encontrada" -Many "ameaças encontradas"
    $unconfirmedText = "o Windows Defender não confirmou o fim da verificação"

    if ($pendingCount -gt 0) {
        Write-WinForgeStatus -Type Info -Message "Escolha o que fazer com $(if ($pendingCount -eq 1) { 'ela' } else { 'elas' }) em Segurança > Segurança do Windows."

        $parts = @()
        if ($found.Count -gt 0) { $parts += $foundText } else { $parts += "nenhuma ameaça nova" }
        if ($pendingFound.Count -gt 0) { $parts += (Format-WinForgeCount -Count $pendingFound.Count -One "ainda pede ação" -Many "ainda pedem ação") }
        if ($leftover.Count -gt 0) { $parts += (Format-WinForgeCount -Count $leftover.Count -One "ameaça de antes ainda ativa" -Many "ameaças de antes ainda ativas") }
        if ($unconfirmed) { $parts += $unconfirmedText }

        # O que falta, quando o Defender já agiu em todas as pendentes e elas só esperam o mesmo passo do PC: reiniciar,
        # ou a verificação completa.
        $needs = @($pendingFound | ForEach-Object { @($_.Needs) } | Select-Object -Unique)
        $allNeed = ($leftover.Count -eq 0 -and @($pendingFound | Where-Object { -not [bool]$_.Waiting }).Count -eq 0)
        $note = "O Windows Defender não resolveu sozinho."
        $next = "WindowsSecurityThreats"
        $nextLabel = $open

        if ($allNeed -and $needs.Count -eq 1 -and $needs[0] -eq "Reboot") {
            $note = "Reinicie o PC para o Windows Defender terminar a limpeza."
        }
        elseif ($allNeed -and $needs.Count -eq 1 -and $needs[0] -eq "FullScan") {
            $note = "O Windows Defender pede a verificação completa."
            $next = "security.full-scan"
            $nextLabel = "Fazer a verificação completa"
        }

        $result = New-WinForgeResult -Kind Warning -Detail ($parts -join "; ") -Data $data
        return (Set-WinForgeResultView -Result $result -Headline (Format-WinForgeCount -Count $pendingCount -One "ameaça pede ação" -Many "ameaças pedem ação") `
            -Note $note -Tone Bad -Next $next -NextLabel $nextLabel)
    }

    $resolvedText = "$foundText; $(if ($found.Count -eq 1) { 'resolvida' } else { 'todas resolvidas' }) pelo Windows Defender"
    $needs = @($Finish.Needs)

    if ($needs.Count -gt 0) {
        # Nada pendente, mas o Defender ainda pede um passo ao PC (reiniciar depois de limpar, a verificação completa).
        $needText = Get-WinForgeDefenderNeedText -Needs $needs
        Write-WinForgeStatus -Type Warning -Message "O Windows Defender pede $needText. Veja em Segurança > Segurança do Windows."

        $parts = @($(if ($found.Count -gt 0) { $resolvedText } else { "nenhuma ameaça encontrada" }), "o Windows Defender pede $needText")
        if ($unconfirmed) { $parts += $unconfirmedText }

        $fullScanOnly = ($needs.Count -eq 1 -and $needs[0] -eq "FullScan")
        $result = New-WinForgeResult -Kind Warning -Detail ($parts -join "; ") -Data $data

        return (Set-WinForgeResultView -Result $result -Headline $(if ($needs.Count -eq 1) { "O Windows Defender pede $needText" } else { "O Windows Defender pede mais um passo" }) `
            -Note $(if ($found.Count -gt 0) { "$(Format-WinForgeCount -Count $found.Count -One 'ameaça encontrada e resolvida' -Many 'ameaças encontradas e resolvidas')." } else { "Nenhuma ameaça encontrada nesta verificação." }) `
            -Tone Warn -Next $(if ($fullScanOnly) { "security.full-scan" } else { "WindowsSecurityThreats" }) -NextLabel $(if ($fullScanOnly) { "Fazer a verificação completa" } else { $open }))
    }

    if ($unconfirmed) {
        $result = New-WinForgeResult -Kind Warning -Detail "$(if ($found.Count -gt 0) { $resolvedText } else { 'nenhuma ameaça encontrada' }); $unconfirmedText" -Data $data
        return (Set-WinForgeResultView -Result $result -Headline "A verificação pode ter parado antes do fim" -Note "Verifique de novo para ter certeza." -Tone Warn)
    }

    if ($found.Count -gt 0) {
        $result = New-WinForgeResult -Kind Ok -Detail $resolvedText -Data $data
        return (Set-WinForgeResultView -Result $result -Headline (Format-WinForgeCount -Count $found.Count -One "ameaça resolvida" -Many "ameaças resolvidas") `
            -Note "O Windows Defender já cuidou $(if ($found.Count -eq 1) { 'dela' } else { 'delas' }); o histórico fica na Segurança do Windows.")
    }

    if ($NetworkNote) {
        Write-WinForgeStatus -Type Warning -Message "Verificação concluída: nenhuma ameaça encontrada, mas os arquivos de rede podem não ter sido examinados."
        $result = New-WinForgeResult -Kind Warning -Detail "nenhuma ameaça encontrada; os arquivos de rede podem não ter sido examinados" -Data $data
        return (Set-WinForgeResultView -Result $result -Headline "Nenhum vírus encontrado" -Note "Mas os arquivos de rede podem não ter sido examinados." -Tone Warn)
    }

    Write-WinForgeStatus -Type Success -Message "Verificação concluída: nenhuma ameaça encontrada."

    $note = switch ($Type) {
        "Quick" { "Verificação rápida concluída." }
        "Full" { "Verificação completa concluída." }
        default { "Verificado: $Path" }
    }

    # A faixa diz tudo: o resumo só repetiria.
    return (Set-WinForgeResultView -Result (New-WinForgeResult -Kind Ok -Detail "nenhuma ameaça encontrada" -Data $data) -Headline "Nenhum vírus encontrado" -Note $note -HideSummary)
}


function Test-WinForgeScanPath {
    <#
    Confere o caminho da verificação de uma pasta antes de qualquer trabalho: $null quando ele serve; senão, escreve o
    motivo e devolve o resultado de falha. Um caminho sem a unidade ("Fotos", ".\Downloads", "\Fotos", "C:") seria
    procurado a partir da pasta do WinForge (ou da unidade atual), e não onde a pessoa pensou: pede o caminho completo,
    com a unidade ou de rede.
    #>
    param ([AllowEmptyString()][string]$Path)

    $complete = ($Path -match '^[A-Za-z]:[\\/]' -or $Path -match '^[\\/]{2}[^\\/]' -or ([System.IO.Path]::DirectorySeparatorChar -eq '/' -and $Path.StartsWith('/')))

    if (-not $complete) {
        Write-WinForgeStatus -Type Error -Message "Informe o caminho completo, com a unidade (por exemplo, D:\Fotos): $Path"
        return (New-WinForgeResult -Kind Failed -Detail "caminho incompleto")
    }

    if (-not (Test-Path -LiteralPath $Path)) {
        Write-WinForgeStatus -Type Error -Message "Pasta ou arquivo não encontrado: $Path"
        return (New-WinForgeResult -Kind Failed -Detail "caminho não encontrado")
    }

    return $null
}


function Invoke-WinForgeDefenderScan {
    <#
    Roda uma verificação do Defender (Quick, Full ou Custom com -Path) e devolve um WinForge.Result, já com o título da
    faixa da janela. Data traz ScanType, ThreatCount (as achadas por esta verificação), PendingThreats (as que ainda pedem
    ação, inclusive as de antes) e ActiveThreats (as de antes ainda ativas). Não abre nem fecha a ação (quem chama faz
    isso).
    #>
    param (
        [Parameter(Mandatory)]
        [ValidateSet("Quick", "Full", "Custom")]
        [string]$Type,

        [string]$Path = "",

        # Pula a conferência de Test-WinForgeDefenderReady quando quem chama já a fez; -Current traz então o estado do
        # antivírus que ela leu (para a linha do andamento dizer quanto a última rápida levou).
        [switch]$AssumeReady,

        $Current = $null,

        # Quem chama já mostrou o que a verificação faz (a completa mostra antes de perguntar se pode começar).
        [switch]$SkipIntro
    )

    if (-not $AssumeReady) {
        $ready = Test-WinForgeDefenderReady

        if (-not $ready.Ready) {
            return $ready.Result
        }

        $Current = $ready.Antivirus
    }

    $scanType = switch ($Type) {
        "Quick"  { "QuickScan" }
        "Full"   { "FullScan" }
        "Custom" { "CustomScan" }
    }

    $arguments = @{ ScanType = $scanType }
    $command = "Start-MpScan -ScanType $scanType"

    $networkNote = $false

    if ($Type -eq "Custom") {
        $invalid = Test-WinForgeScanPath -Path $Path
        if ($null -ne $invalid) { return $invalid }

        $arguments["ScanPath"] = $Path
        $command += " -ScanPath `"$Path`""
        $networkNote = (Test-WinForgeNetworkScanSkipped -Path $Path)
    }

    # O título da fase: na janela, é a frase em destaque enquanto a verificação roda.
    Write-WinForgeSection -Title $(switch ($Type) { "Quick" { "Verificação rápida" } "Full" { "Verificação completa" } default { "Verificação da pasta" } })

    if (-not $SkipIntro) {
        Write-WinForgeScanIntro -Type $Type -Path $Path
    }

    if ($networkNote) {
        Write-WinForgeStatus -Type Warning -Message "O Windows Defender está configurado para não examinar arquivos de rede: verifique esta pasta no PC onde ela está."
    }

    Write-WinForgeCommand -Command $command

    # O que o Defender já tinha registrado: separa o que esta verificação achou do que já estava lá.
    $known = Get-WinForgeDetectionIds
    $estimate = Get-WinForgeScanDurationText -Type $Type -Path $Path -Antivirus $Current

    # Nenhuma verificação pode parar no meio porque o Windows suspendeu o PC: nem a completa (horas), nem a rápida, que
    # num notebook na bateria passa do tempo de suspensão.
    $awake = [bool](Set-WinForgeKeepAwake -Enabled $true)

    # Sem porcentagem: o Defender só responde quando termina. A barra indeterminada mostra que ainda está trabalhando, e a
    # linha diz quanto costuma levar (uma linha "Verificando..." ficaria no resumo depois do fim).
    Write-Progress -Activity "Windows Defender" -Status $estimate

    $finished = $false
    $scanStart = Get-Date

    try {
        [void](Start-MpScan @arguments -ErrorAction Stop)
        $finished = $true
    }
    catch {
        $finished = $true
        return (ConvertTo-WinForgeScanFailure -ErrorRecord $_ -Type $Type)
    }
    finally {
        Write-Progress -Activity "Windows Defender" -Completed

        if ($awake) { [void](Set-WinForgeKeepAwake -Enabled $false) }

        # Sem ter terminado nem falhado, quem interrompeu foi a pessoa (Parar): o Defender seguiria varrendo sozinho.
        if (-not $finished) {
            try {
                Write-WinForgeScanStopped -Type $Type
            }
            catch {
                # O fluxo já está sendo encerrado; nada mais a fazer.
            }
        }
    }

    $finish = Get-WinForgeScanFinish -Type $Type -Since $scanStart
    $scan = Get-WinForgeScanDetections -Since $scanStart.AddSeconds(-5) -Known $known

    if ($null -eq $scan) {
        Write-WinForgeStatus -Type Warning -Message "A verificação terminou, mas não foi possível consultar o resultado. Confira em Segurança > Segurança do Windows."
        return (Set-WinForgeResultView -Result (New-WinForgeResult -Kind Warning -Detail "resultado não consultado" -Data @{ ScanType = $Type }) `
            -Headline "Não foi possível ler o resultado" -Note "A verificação terminou, mas o Windows não deixou consultar o que ela achou." `
            -Tone Warn -Next "WindowsSecurityThreats" -NextLabel "Abrir a Segurança do Windows")
    }

    return (Get-WinForgeScanOutcome -Type $Type -Path $Path -Scan $scan -Finish $finish -NetworkNote $networkNote)
}


# ---------------------------------------------------------------------------
# Ações
# ---------------------------------------------------------------------------

function Update-WinForgeDefenderSignatures {
    param (
        [switch]$Embedded,
        [switch]$PassThru
    )

    Enter-WinForgeAction -Title "Atualizar assinaturas do antivírus" -Embedded:$Embedded

    $result = $null

    try {
        $result = Invoke-WinForgeSignatureUpdate
    }
    catch {
        Write-WinForgeStatus -Type Error -Message "Ocorreu um erro ao atualizar as assinaturas: $($_.Exception.Message)"
        $result = New-WinForgeResult -Kind Failed -Detail $_.Exception.Message
    }

    $result.Etapa = "Atualizar assinaturas do antivírus"
    Exit-WinForgeAction -Embedded:$Embedded -Result $result

    if ($PassThru) {
        return $result
    }
}


function Start-WinForgeFullScan {
    param (
        [switch]$Embedded,
        [switch]$PassThru
    )

    Enter-WinForgeAction -Title "Verificação completa de vírus" -Embedded:$Embedded

    $result = $null

    try {
        # Antes de perguntar: sem Administrador ou sem o Defender protegendo, perguntar "deseja começar?" seria à toa.
        $ready = Test-WinForgeDefenderReady

        if (-not $ready.Ready) {
            $result = $ready.Result
        }
        else {
            # O que a verificação faz antes da pergunta: na janela, fica no resumo, acima dos botões.
            Write-WinForgeScanIntro -Type Full

            # Horas de disco e processador esgotam a bateria de um notebook (e a verificação recomeça do zero).
            if (Test-WinForgeOnBattery) {
                Write-WinForgeStatus -Type Warning -Notice -Message "O notebook está na bateria: conecte o carregador, a verificação completa pode levar horas."
            }

            Write-Host ""

            if (-not $Embedded -and -not (Confirm-WinForgeAction "Deseja começar a verificação completa agora?" -DefaultKey N)) {
                Write-WinForgeStatus -Type Warning -Message "Operação cancelada."
                $result = New-WinForgeResult -Kind Skipped -Detail "cancelado pelo usuário"
            }
            else {
                # Horas de verificação com as assinaturas de dias atrás deixariam passar o que surgiu nesse meio-tempo: o
                # antivírus é atualizado antes, como no Verificar vírus (o Start-MpScan não atualiza nada antes de começar).
                $update = Invoke-WinForgeSignatureUpdate -AssumeReady -Current $ready.Antivirus
                $scan = Invoke-WinForgeDefenderScan -Type Full -AssumeReady -Current $ready.Antivirus -SkipIntro
                $result = Join-WinForgeSecurityCheckResult -Update $update -Scan $scan
            }
        }
    }
    catch {
        Write-WinForgeStatus -Type Error -Message "Ocorreu um erro na verificação: $($_.Exception.Message)"
        $result = New-WinForgeResult -Kind Failed -Detail $_.Exception.Message
    }

    $result.Etapa = "Verificação completa de vírus"
    Exit-WinForgeAction -Embedded:$Embedded -Result $result

    if ($PassThru) {
        return $result
    }
}


function ConvertTo-WinForgeScanPath {
    # O caminho como a pessoa o cola: sem espaços nas pontas, sem aspas (duplas, do "Copiar como caminho", ou simples),
    # com variáveis como %USERPROFILE% já resolvidas e "E:" como a raiz da unidade (E:\). Vazio quando não há nada.
    param ($Text)

    $path = ([string]$Text).Trim().Trim('"', "'").Trim()

    if ($path.Contains("%")) {
        $path = [Environment]::ExpandEnvironmentVariables($path)
    }

    # Só a letra da unidade ("E:", um pen drive) é a raiz dela: sem a barra, valeria a pasta atual daquela unidade.
    if ($path -match '^[A-Za-z]:$') {
        $path += "\"
    }

    return $path
}


function Select-WinForgeScanTarget {
    # Pergunta o que verificar: as pastas mais comuns em botões, ou um caminho digitado. Devolve o caminho, ou "" quando
    # a pessoa cancela.
    $options = @()
    $downloads = ""
    $desktop = ""

    try { $downloads = [string](Get-WinForgeDownloadsPath) } catch { $downloads = "" }
    try { $desktop = [string][Environment]::GetFolderPath("Desktop") } catch { $desktop = "" }

    if ($downloads -and (Test-Path -LiteralPath $downloads -PathType Container)) {
        $options += @{ Key = "D"; Label = "Downloads"; Description = $downloads; Accent = $true }
    }

    if ($desktop -and (Test-Path -LiteralPath $desktop -PathType Container)) {
        $options += @{ Key = "A"; Label = "Área de Trabalho"; Description = $desktop }
    }

    $options += @{ Key = "O"; Label = "Outra pasta ou arquivo"; Description = "por exemplo D:\Fotos" }
    $options += @{ Key = "C"; Label = "Cancelar"; Exit = $true }

    $choice = Read-WinForgeChoice -Message "O que deseja verificar?" -Options $options -DefaultKey "C" -ShowMenu

    switch ($choice) {
        "D" { return $downloads }
        "A" { return $desktop }
        "O" { return (ConvertTo-WinForgeScanPath -Text (Read-WinForgeText -Message "Cole o caminho da pasta ou do arquivo (ENTER cancela)")) }
        default { return "" }
    }
}


function Start-WinForgeFolderScan {
    param (
        [switch]$Embedded,
        [switch]$PassThru
    )

    Enter-WinForgeAction -Title "Verificar uma pasta" -Embedded:$Embedded

    $result = $null

    try {
        # Antes de perguntar o que verificar: sem Administrador ou sem o Defender protegendo, a pergunta seria à toa.
        $ready = Test-WinForgeDefenderReady

        if (-not $ready.Ready) {
            $result = $ready.Result
        }
        else {
            $path = [string](Select-WinForgeScanTarget)
            $invalid = $(if ([string]::IsNullOrWhiteSpace($path)) { $null } else { Test-WinForgeScanPath -Path $path })

            if ([string]::IsNullOrWhiteSpace($path)) {
                Write-WinForgeStatus -Type Warning -Message "Operação cancelada."
                $result = New-WinForgeResult -Kind Skipped -Detail "cancelado pelo usuário"
            }
            elseif ($null -ne $invalid) {
                # O caminho errado é dito antes de atualizar o antivírus: a atualização seria trabalho à toa.
                $result = $invalid
            }
            else {
                # Quem verifica um arquivo baixado agora quer as assinaturas de hoje: o antivírus é atualizado antes.
                $update = Invoke-WinForgeSignatureUpdate -AssumeReady -Current $ready.Antivirus
                $scan = Invoke-WinForgeDefenderScan -Type Custom -Path $path -AssumeReady -Current $ready.Antivirus
                $result = Join-WinForgeSecurityCheckResult -Update $update -Scan $scan
            }
        }
    }
    catch {
        Write-WinForgeStatus -Type Error -Message "Ocorreu um erro na verificação: $($_.Exception.Message)"
        $result = New-WinForgeResult -Kind Failed -Detail $_.Exception.Message
    }

    $result.Etapa = "Verificar uma pasta"
    Exit-WinForgeAction -Embedded:$Embedded -Result $result

    if ($PassThru) {
        return $result
    }
}


function Join-WinForgeSecurityCheckResult {
    <#
    O resultado de uma verificação feita depois de atualizar o antivírus (o Verificar vírus, a completa e a de uma
    pasta): o da verificação, com a atualização junto quando ela não deu certo (a verificação rodou com as assinaturas
    de antes, e o Otimizar e o histórico precisam saber disso). A cor é a pior das duas: nada encontrado com o antivírus
    sem atualizar fica amarelo, e a faixa diz por quê.
    #>
    param (
        [Parameter(Mandatory)]$Update,
        [Parameter(Mandatory)]$Scan
    )

    if ([string]$Update.Kind -eq "Ok") {
        if ([string]$Scan.Kind -eq "Ok" -and [int](Get-WinForgeResultData -Result $Scan -Name "ThreatCount") -eq 0 -and $Scan.Data -is [System.Collections.IDictionary]) {
            # A da pasta continua dizendo o que foi examinado ("verificado: D:\Fotos").
            $scanNote = ([string](Get-WinForgeResultData -Result $Scan -Name "Note")).Trim()

            $Scan.Data["Note"] = switch ([string](Get-WinForgeResultData -Result $Scan -Name "ScanType")) {
                "Full" { "Antivírus atualizado e verificação completa concluída." }
                "Custom" { $(if ($scanNote) { "Antivírus atualizado; " + $scanNote.Substring(0, 1).ToLowerInvariant() + $scanNote.Substring(1) } else { "Antivírus atualizado e pasta verificada." }) }
                default { "Antivírus atualizado e verificação rápida concluída." }
            }
        }

        return $Scan
    }

    $data = @{}

    if ($Scan.Data -is [System.Collections.IDictionary]) {
        foreach ($key in @($Scan.Data.Keys)) { $data[$key] = $Scan.Data[$key] }
    }

    $kind = $(if ([string]$Scan.Kind -eq "Failed") { "Failed" } else { "Warning" })
    $detail = (@([string]$Scan.Detail, [string]$Update.Detail) | Where-Object { $_ }) -join "; "
    $result = New-WinForgeResult -Kind $kind -Detail $detail -Data $data

    if ([string]$Scan.Kind -eq "Ok") {
        # O resumo mostra a linha da atualização que não deu certo: ele não fica escondido.
        $headline = [string](Get-WinForgeResultData -Result $Scan -Name "Headline")
        [void](Set-WinForgeResultView -Result $result -Headline $(if ($headline) { $headline } else { "Nenhum vírus encontrado" }) `
            -Note ([string](Get-WinForgeResultData -Result $Update -Name "Caveat")) -Tone Warn)
    }
    elseif ([string]$Scan.Kind -eq "Failed") {
        # Os dois motivos juntos dariam uma frase longa demais para a faixa: ela diz o da verificação, e que a atualização
        # também não deu certo; o detalhe (o Otimizar e o histórico) continua com os dois.
        $reason = ([string]$Scan.Detail).Trim().TrimEnd(".").Trim()
        if ($reason) { $reason = $reason.Substring(0, 1).ToUpperInvariant() + $reason.Substring(1) + ". " }

        [void](Set-WinForgeResultView -Result $result -Headline "A verificação não foi concluída" -Note "${reason}O antivírus também não foi atualizado." -Tone Bad)
    }

    return $result
}


function Invoke-WinForgeSecurityCheck {
    <#
    Verificar vírus (o botão do Início, Segurança > Verificar vírus e a etapa do Otimizar): atualiza as assinaturas e faz
    a verificação rápida. O resultado é o da verificação; a atualização que não deu certo entra junto e deixa o resultado
    pelo menos com ressalva (a verificação rodou com as assinaturas de antes).
    #>
    param (
        [switch]$Embedded,
        [switch]$PassThru
    )

    Enter-WinForgeAction -Title "Verificar vírus" -Embedded:$Embedded

    $result = $null

    try {
        $ready = Test-WinForgeDefenderReady

        if (-not $ready.Ready) {
            # Nada a verificar: o motivo já está na tela.
            $result = $ready.Result
        }
        else {
            $update = Invoke-WinForgeSignatureUpdate -AssumeReady -Current $ready.Antivirus
            $scan = Invoke-WinForgeDefenderScan -Type Quick -AssumeReady -Current $ready.Antivirus
            $result = Join-WinForgeSecurityCheckResult -Update $update -Scan $scan
        }
    }
    catch {
        Write-WinForgeStatus -Type Error -Message "Ocorreu um erro na verificação de vírus: $($_.Exception.Message)"
        $result = New-WinForgeResult -Kind Failed -Detail $_.Exception.Message
    }

    $result.Etapa = "Verificar vírus"
    Exit-WinForgeAction -Embedded:$Embedded -Result $result

    if ($PassThru) {
        return $result
    }
}


# ---------------------------------------------------------------------------
# Auditoria de segurança (somente leitura)
# ---------------------------------------------------------------------------

function Get-WinForgeGuestAccountEnabled {
    # A conta Convidado tem sempre o SID terminado em -501, qualquer que seja o idioma do Windows. $null = não foi possível ler.
    try {
        $guest = @(Get-LocalUser -ErrorAction Stop | Where-Object { $_.SID.Value -like "*-501" } | Select-Object -First 1)

        # Sem a conta Convidado (removida da imagem do Windows), não há o que entrar sem senha.
        if ($guest.Count -eq 0) {
            return $false
        }

        return [bool]$guest[0].Enabled
    }
    catch {
        return $null
    }
}


function Get-WinForgeSmb1State {
    <#
    O SMB 1.0, o protocolo antigo de compartilhamento de arquivos (usado por ataques como o WannaCry): "On" quando o
    recurso do Windows está ligado (ou liga no próximo reinício), "Off" quando está desligado ou nem existe neste
    Windows, e $null quando não foi possível ler (a consulta pede Administrador). É o recurso de "Ativar ou desativar
    recursos do Windows" (SMB1Protocol), o caminho que a Microsoft indica para conferir o SMB 1.0 no Windows 10 e 11.
    #>
    try {
        $feature = @(Get-WindowsOptionalFeature -Online -FeatureName "SMB1Protocol" -ErrorAction Stop) | Select-Object -First 1
    }
    catch {
        return $null
    }

    if ($null -eq $feature) { return "Off" }

    return $(if ([string](Get-WinForgeJsonValue -Object $feature -Name "State" -Default "") -in @("Enabled", "EnablePending")) { "On" } else { "Off" })
}


function Get-WinForgeBitLockerState {
    <#
    O disco do sistema: "On" (criptografado e protegido), "Suspended" (criptografado, com chave de proteção, mas com a
    proteção suspensa: a chave fica gravada no disco, como depois de uma atualização da BIOS), "Encrypting" (ainda
    criptografando, ou com a criptografia pausada), "Pending" (criptografado, mas sem nenhuma chave de proteção: a
    criptografia do dispositivo esperando ativação), "Off" (sem criptografia) ou $null quando não dá para saber (sem
    Administrador, edição sem BitLocker...). Os estados vêm pelos nomes do módulo BitLocker.
    #>
    try {
        $drive = if ([string]::IsNullOrWhiteSpace($env:SystemDrive)) { "C:" } else { $env:SystemDrive }
        $volume = Get-BitLockerVolume -MountPoint $drive -ErrorAction Stop
        $protection = [string](Get-WinForgeJsonValue -Object $volume -Name "ProtectionStatus" -Default "")
        $volumeStatus = [string](Get-WinForgeJsonValue -Object $volume -Name "VolumeStatus" -Default "")
        $protectors = @(Get-WinForgeJsonValue -Object $volume -Name "KeyProtector" -Default @() | Where-Object { $null -ne $_ })

        if ($protection -in @("On", "1")) { return "On" }
        if ($protection -notin @("Off", "0")) { return $null }

        # Proteção "Off" vale para um disco sem criptografia, um ainda criptografando e um criptografado com a proteção
        # suspensa ou esperando ativação: o estado do volume e as chaves desempatam.
        switch ($volumeStatus) {
            "FullyDecrypted" { return "Off" }
            "FullyEncrypted" { return $(if ($protectors.Count -gt 0) { "Suspended" } else { "Pending" }) }
            { $_ -in @("EncryptionInProgress", "EncryptionSuspended") } { return "Encrypting" }
            { $_ -in @("DecryptionInProgress", "DecryptionSuspended") } { return "Off" }
        }

        # Sem o estado do volume, a proteção desligada vale como sem criptografia.
        return "Off"
    }
    catch {
        # Sem resposta: fica como "não verificado".
    }

    return $null
}


function Get-WinForgeSecurityAuditFacts {
    <#
    Lê, sem alterar nada, o que a auditoria avalia. Cada leitura que falha vira $null ("não verificado"), nunca erro.
    As atualizações pendentes (que demoram) vêm de fora, por -Updates.
    #>
    param (
        $Updates = $null
    )

    $system = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
    $winlogon = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"

    $uac = Get-WinForgeRegistryValueOrNull -Path $system -Name "EnableLUA"
    # O nível "Nunca notificar" do UAC deixa EnableLUA em 1 e zera ConsentPromptBehaviorAdmin: os programas ganham
    # Administrador sem perguntar.
    $uacPrompt = Get-WinForgeRegistryValueOrNull -Path $system -Name "ConsentPromptBehaviorAdmin"
    $denyRdp = Get-WinForgeRegistryValueOrNull -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections"
    # O Secure Boot com a mesma leitura do Diagnóstico (Sobre este PC): o modo de inicialização, o Registro (legível sem
    # Administrador) e, sem ele, a consulta do Windows. "Legacy" = o Windows iniciou no modo BIOS legado.
    $secureBootState = [string](Get-WinForgeSecureBootState)
    $secureBoot = $(
        if ($secureBootState -eq "On") { $true }
        elseif ($secureBootState -eq "Off") { $false }
        elseif ($secureBootState -eq "Legacy") { "Legacy" }
        else { $null }
    )
    $explorerSmartScreen = Get-WinForgeRegistryValueOrNull -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" -Name "SmartScreenEnabled"
    # Ligado de forma explícita (Warn ou RequireAdmin, ou a política em 1); sem nenhum dos dois, vale o padrão do Windows.
    $smartScreenSet = ([string]$explorerSmartScreen -in @("Warn", "RequireAdmin"))
    $policySmartScreen = Get-WinForgeRegistryValueOrNull -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "EnableSmartScreen"
    $autoLogon = Get-WinForgeRegistryValueOrNull -Path $winlogon -Name "AutoAdminLogon"
    $storedPassword = Get-WinForgeRegistryValueOrNull -Path $winlogon -Name "DefaultPassword"
    $currentVersion = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"

    return [PSCustomObject]@{
        Antivirus        = Get-WinForgeAntivirusStatus
        Firewall         = Get-WinForgeFirewallStatus
        Threats          = Get-WinForgeActiveThreats
        Updates          = $Updates
        UacEnabled       = $(if ($null -eq $uac) { $null } else { [int]$uac -ne 0 })
        UacNeverNotify   = ($null -ne $uacPrompt -and [string]$uacPrompt -eq "0")
        SmartScreenOff   = ($explorerSmartScreen -eq "Off" -or ($null -ne $policySmartScreen -and [int]$policySmartScreen -eq 0))
        SmartScreenSet   = ($smartScreenSet -or ($null -ne $policySmartScreen -and [string]$policySmartScreen -eq "1"))
        RdpEnabled       = $(if ($null -eq $denyRdp) { $null } else { [int]$denyRdp -eq 0 })
        GuestEnabled     = Get-WinForgeGuestAccountEnabled
        AutoLogon        = ([string]$autoLogon -eq "1")
        PasswordStored   = (-not [string]::IsNullOrEmpty([string]$storedPassword))
        BitLocker        = Get-WinForgeBitLockerState
        Smb1             = Get-WinForgeSmb1State
        SecureBoot       = $secureBoot
        WindowsBuild     = Get-WinForgeWindowsBuild
        WindowsRevision  = Get-WinForgeWindowsRevision
        WindowsEdition   = Get-WinForgeWindowsEditionId
        WindowsVersion   = [string](Get-WinForgeRegistryValueOrNull -Path $currentVersion -Name "DisplayVersion")
        Now              = Get-Date
    }
}


function New-WinForgeAuditCheck {
    <#
    Um ponto da auditoria. Status: Ok, Warn (merece atenção), Bad (risco real) ou Unknown (não foi possível verificar).
    Weight 0 = só informa e não entra na nota. Critical = um Bad aqui deixa a nota em no máximo 74.
    #>
    param (
        [Parameter(Mandatory)]
        [string]$Id,

        [Parameter(Mandatory)]
        [string]$Title,

        [Parameter(Mandatory)]
        [ValidateSet("Ok", "Warn", "Bad", "Unknown")]
        [string]$Status,

        [int]$Weight = 0,
        [string]$Detail = "",
        [string]$Advice = "",
        [switch]$Critical
    )

    return [PSCustomObject]@{
        Id       = $Id
        Title    = $Title
        Status   = $Status
        Weight   = $Weight
        Detail   = $Detail
        Advice   = $(if ($Status -in "Warn", "Bad") { $Advice } else { "" })
        Critical = [bool]$Critical
    }
}


function Get-WinForgeWindowsSupportCheck {
    <#
    O ponto "Suporte do Windows" da auditoria: se esta versão ainda recebe correções de segurança. A resposta é a mesma da
    tela Diagnóstico > Suporte do Windows e do Início (Get-WinForgeWindowsSupportStatus): as datas vêm do catálogo, a
    edição passa pela mesma regra (sem ela, vale o prazo de Home e Pro, o mais curto) e o ESU do Windows 10 é conferido
    pela build instalada. Sem suporte é risco real (Bad); acabando em breve ou no ESU, ressalva (Warn).
    #>
    param (
        [Parameter(Mandatory)]
        $Facts
    )

    $title = "Suporte do Windows"
    $build = [int]$Facts.WindowsBuild
    $edition = [string](Get-WinForgeJsonValue -Object $Facts -Name "WindowsEdition" -Default "")
    $displayVersion = [string](Get-WinForgeJsonValue -Object $Facts -Name "WindowsVersion" -Default "")

    if ($build -lt 10240) {
        return (New-WinForgeAuditCheck -Id "windows-support" -Title $title -Status Unknown -Weight 15 -Detail "Não foi possível identificar a versão")
    }

    try {
        $status = Get-WinForgeWindowsSupportStatus -Build $build -EditionId $edition -Revision (Get-WinForgeJsonValue -Object $Facts -Name "WindowsRevision") -Today ([datetime]$Facts.Now).Date
    }
    catch {
        return (New-WinForgeAuditCheck -Id "windows-support" -Title $title -Status Unknown -Weight 15 -Detail "Não foi possível conferir as datas de suporte")
    }

    $label = [string]$status.Product
    if ($status.Class -eq "Ltsc") { $label += $(if ($edition -match '^IoT') { " (IoT Enterprise LTSC)" } else { " (LTSC)" }) }

    $endText = $(if ($status.EndDate -is [datetime]) { Format-WinForgeDateTime -When $status.EndDate -Pattern "dd/MM/yyyy" } else { "" })
    $advice = ([string]$status.Advice).TrimEnd(".")

    switch ([string]$status.State) {
        "Supported" {
            return (New-WinForgeAuditCheck -Id "windows-support" -Title $title -Status Ok -Weight 15 -Detail "${label}: correções de segurança até $endText")
        }
        "EndingSoon" {
            return (New-WinForgeAuditCheck -Id "windows-support" -Title $title -Status Warn -Weight 15 -Detail $(if ([int]$status.DaysLeft -le 0) { "${label}: as correções de segurança terminam hoje ($endText)" } else { "${label}: as correções de segurança acabam em $endText ($(Get-WinForgeSupportDaysText -Days $status.DaysLeft))" }) -Advice $advice)
        }
        "Esu" {
            return (New-WinForgeAuditCheck -Id "windows-support" -Title $title -Status Warn -Weight 15 -Detail "${label}: correções pelo programa ESU$(if ($status.EsuEnd -is [datetime]) { " até $(Format-WinForgeDateTime -When $status.EsuEnd -Pattern 'dd/MM/yyyy')" } else { ' da organização' }); o suporte normal acabou em $endText" -Advice $advice)
        }
        "EsuAvailable" {
            if (-not [bool]$status.EsuChecked) {
                # Sem a build instalada, não dá para dizer se o PC está no ESU: fica como não verificado.
                return (New-WinForgeAuditCheck -Id "windows-support" -Title $title -Status Unknown -Weight 15 -Detail "${label}: o suporte gratuito terminou em $endText e não foi possível conferir o programa ESU")
            }

            return (New-WinForgeAuditCheck -Id "windows-support" -Title $title -Status Bad -Weight 15 -Detail "${label}: o suporte gratuito terminou em $endText, e nenhuma correção do programa ESU foi instalada" -Advice $advice)
        }
        "Ended" {
            $since = $(if ($endText) { "a última correção de segurança saiu em $endText" } else { "sem correções de segurança" })
            return (New-WinForgeAuditCheck -Id "windows-support" -Title $title -Status Bad -Weight 15 -Detail "${label}: $since" -Advice $advice)
        }
    }

    # Fora da lista de datas (Windows 11 mais novo que ela, prévia do Insider): o nome, sem prometer prazo.
    $unknownLabel = $(if ($displayVersion) { "Windows 11 versão $displayVersion" } else { $label })

    return (New-WinForgeAuditCheck -Id "windows-support" -Title $title -Status Unknown -Weight 15 -Detail "${unknownLabel}: versão fora da lista de datas do WinForge")
}


function Get-WinForgeSecurityAuditChecks {
    # Transforma o que foi lido (Get-WinForgeSecurityAuditFacts) nos pontos da auditoria, do mais importante ao menos.
    param (
        [Parameter(Mandatory)]
        $Facts
    )

    $checks = @()
    $antivirus = $Facts.Antivirus

    # Antivírus
    switch ($antivirus.Mode) {
        "Active" {
            $checks += New-WinForgeAuditCheck -Id "antivirus" -Title "Antivírus" -Status Ok -Weight 30 -Detail "Windows Defender ativo"
        }
        "Other" {
            $checks += New-WinForgeAuditCheck -Id "antivirus" -Title "Antivírus" -Status Ok -Weight 30 -Detail "Outro antivírus protege o PC ($(Join-WinForgeList -Items @($antivirus.Others)))"
        }
        "Passive" {
            $checks += New-WinForgeAuditCheck -Id "antivirus" -Title "Antivírus" -Status Warn -Weight 30 -Detail "O Windows Defender está em modo passivo e nenhum outro antivírus ligado foi identificado" `
                -Advice "Confirme em Segurança > Segurança do Windows se há outro antivírus ativo; sem ele, o PC fica desprotegido"
        }
        "Off" {
            $checks += New-WinForgeAuditCheck -Id "antivirus" -Title "Antivírus" -Status Bad -Weight 30 -Critical -Detail "Desligado e nenhum outro antivírus ligado foi encontrado" `
                -Advice "Ligue o antivírus em Segurança > Segurança do Windows"
        }
        default {
            $checks += New-WinForgeAuditCheck -Id "antivirus" -Title "Antivírus" -Status Unknown -Weight 30 -Detail "Não foi possível ler o estado"
        }
    }

    if ($antivirus.Mode -eq "Active") {
        if ($antivirus.RealTime -eq $false) {
            $checks += New-WinForgeAuditCheck -Id "realtime" -Title "Proteção em tempo real" -Status Bad -Weight 15 -Critical -Detail "Desligada" `
                -Advice "Ligue a proteção em tempo real em Segurança > Segurança do Windows"
        }
        elseif ($antivirus.RealTime -eq $true) {
            $checks += New-WinForgeAuditCheck -Id "realtime" -Title "Proteção em tempo real" -Status Ok -Weight 15 -Detail "Ligada"
        }

        $tamper = Get-WinForgeJsonValue -Object $antivirus -Name "TamperProtected"

        if ($tamper -eq $false) {
            $checks += New-WinForgeAuditCheck -Id "tamper" -Title "Proteção contra adulterações" -Status Warn -Weight 5 -Detail "Desligada" `
                -Advice "Ligue-a em Segurança > Segurança do Windows; ela impede que vírus desliguem o antivírus"
        }
        elseif ($tamper -eq $true) {
            $checks += New-WinForgeAuditCheck -Id "tamper" -Title "Proteção contra adulterações" -Status Ok -Weight 5 -Detail "Ligada"
        }

        $age = Get-WinForgeJsonValue -Object $antivirus -Name "SignatureAgeDays"

        if ($null -eq $age) {
            # Sem a data das assinaturas, o ponto não some da conta em silêncio: fica como não verificado, e a tela diz.
            $checks += New-WinForgeAuditCheck -Id "signatures" -Title "Assinaturas do antivírus" -Status Unknown -Weight 10 -Detail "Não foi possível ler a data da última atualização"
        }
        else {
            if ($age -gt 7) {
                $checks += New-WinForgeAuditCheck -Id "signatures" -Title "Assinaturas do antivírus" -Status Bad -Weight 10 -Detail "Têm $age dias" `
                    -Advice "Use Segurança > Atualizar assinaturas do antivírus"
            }
            elseif ($age -gt 3) {
                $checks += New-WinForgeAuditCheck -Id "signatures" -Title "Assinaturas do antivírus" -Status Warn -Weight 10 -Detail "Têm $age dias; o normal é atualizarem todo dia" `
                    -Advice "Use Segurança > Atualizar assinaturas do antivírus"
            }
            else {
                $checks += New-WinForgeAuditCheck -Id "signatures" -Title "Assinaturas do antivírus" -Status Ok -Weight 10 -Detail $(
                    # "há 12 horas", e não "hoje": atualizadas às 23h de ontem, às 8h ainda têm menos de um dia.
                    $updated = Get-WinForgeJsonValue -Object $antivirus -Name "SignaturesUpdated"
                    if ($updated -is [datetime]) { "Atualizadas $(Format-WinForgeRelativeTime -When $updated -Now ([datetime]$Facts.Now))" }
                    elseif ($age -le 0) { "Atualizadas há menos de um dia" }
                    else { "Atualizadas há $(Format-WinForgeCount -Count $age -One 'dia' -Many 'dias')" }
                )
            }
        }
    }

    # Ameaças ativas: como na tela Estado da proteção, a lista do Defender só é avaliada quando ele protege o PC. Com
    # outro antivírus no lugar, o Defender não responder é o esperado (não é "sem verificar"), e o que ele ainda guarda
    # é ressalva: quem decide é o outro antivírus.
    if ($null -ne $Facts.Threats -and @($Facts.Threats).Count -gt 0) {
        $threatList = "$(@($Facts.Threats).Count): $(Join-WinForgeList -Items @($Facts.Threats))"

        if ($antivirus.Mode -eq "Other") {
            $checks += New-WinForgeAuditCheck -Id "threats" -Title "Ameaças no Defender" -Status Warn -Weight 20 -Detail $threatList `
                -Advice "Abra Segurança > Segurança do Windows e confira as ameaças que o Defender ainda guarda; confirme também no outro antivírus"
        }
        else {
            $checks += New-WinForgeAuditCheck -Id "threats" -Title "Ameaças ativas" -Status Bad -Weight 20 -Critical -Detail $threatList `
                -Advice "Abra Segurança > Segurança do Windows e aplique as ações indicadas para cada ameaça"
        }
    }
    elseif ($antivirus.Mode -eq "Active") {
        if ($null -eq $Facts.Threats) {
            $checks += New-WinForgeAuditCheck -Id "threats" -Title "Ameaças ativas" -Status Unknown -Weight 20 -Detail "Não foi possível consultar"
        }
        else {
            $checks += New-WinForgeAuditCheck -Id "threats" -Title "Ameaças ativas" -Status Ok -Weight 20 -Detail "Nenhuma"
        }
    }

    # Firewall
    if ($null -eq $Facts.Firewall) {
        $checks += New-WinForgeAuditCheck -Id "firewall" -Title "Firewall" -Status Unknown -Weight 20 -Detail "Não foi possível ler"
    }
    else {
        $off = @(Get-WinForgeFirewallGaps -Firewall $Facts.Firewall)
        $unused = @($Facts.Firewall | Where-Object { -not $_.Enabled -and -not [bool](Get-WinForgeJsonValue -Object $_ -Name "Applies" -Default $true) })

        $otherFirewall = Get-WinForgeFirewallOtherProduct -Firewall $Facts.Firewall

        if ($off.Count -eq 0 -and $otherFirewall) {
            $checks += New-WinForgeAuditCheck -Id "firewall" -Title "Firewall" -Status Ok -Weight 20 -Detail "Outro firewall protege o PC ($otherFirewall)"
        }
        elseif ($off.Count -eq 0 -and $unused.Count -gt 0) {
            $checks += New-WinForgeAuditCheck -Id "firewall" -Title "Firewall" -Status Ok -Weight 20 -Detail "Ligado nas redes privada e pública (o perfil Domínio, desligado, não vale para este PC)"
        }
        elseif ($off.Count -eq 0) {
            $checks += New-WinForgeAuditCheck -Id "firewall" -Title "Firewall" -Status Ok -Weight 20 -Detail "Ligado em todos os perfis de rede"
        }
        else {
            $names = @($off | ForEach-Object { Get-WinForgeFirewallProfileName -Name $_.Name })
            $publicOff = @($off | Where-Object { $_.Name -eq "Public" }).Count -gt 0

            $checks += New-WinForgeAuditCheck -Id "firewall" -Title "Firewall" -Status $(if ($publicOff) { "Bad" } else { "Warn" }) -Weight 20 -Critical:$publicOff `
                -Detail "Desligado em: $(Join-WinForgeList -Items $names)" -Advice "Ligue o firewall em Segurança > Segurança do Windows"
        }
    }

    # Controle de Conta de Usuário
    if ($null -eq $Facts.UacEnabled) {
        $checks += New-WinForgeAuditCheck -Id "uac" -Title "Controle de Conta de Usuário (UAC)" -Status Unknown -Weight 15 -Detail "Não foi possível ler"
    }
    elseif ($Facts.UacEnabled -and [bool](Get-WinForgeJsonValue -Object $Facts -Name "UacNeverNotify" -Default $false)) {
        $checks += New-WinForgeAuditCheck -Id "uac" -Title "Controle de Conta de Usuário (UAC)" -Status Bad -Weight 15 -Critical -Detail "No nível 'Nunca notificar': os programas ganham Administrador sem perguntar" `
            -Advice "Procure 'Alterar configurações de Controle de Conta de Usuário' no menu Iniciar e escolha um nível acima de 'Nunca notificar'"
    }
    elseif ($Facts.UacEnabled) {
        $checks += New-WinForgeAuditCheck -Id "uac" -Title "Controle de Conta de Usuário (UAC)" -Status Ok -Weight 15 -Detail "Ligado"
    }
    else {
        $checks += New-WinForgeAuditCheck -Id "uac" -Title "Controle de Conta de Usuário (UAC)" -Status Bad -Weight 15 -Critical -Detail "Desligado" `
            -Advice "Procure 'Alterar configurações de Controle de Conta de Usuário' no menu Iniciar, escolha um nível acima de 'Nunca notificar' e reinicie o PC"
    }

    # SmartScreen
    if ($Facts.SmartScreenOff) {
        $checks += New-WinForgeAuditCheck -Id "smartscreen" -Title "SmartScreen" -Status Warn -Weight 5 -Detail "Desligado" `
            -Advice "Ligue-o em Segurança > Segurança do Windows; ele avisa sobre programas e sites perigosos"
    }
    elseif ([bool](Get-WinForgeJsonValue -Object $Facts -Name "SmartScreenSet" -Default $false)) {
        $checks += New-WinForgeAuditCheck -Id "smartscreen" -Title "SmartScreen" -Status Ok -Weight 5 -Detail "Ligado"
    }
    else {
        # Nada gravado: vale o padrão do Windows, que é ligado.
        $checks += New-WinForgeAuditCheck -Id "smartscreen" -Title "SmartScreen" -Status Ok -Weight 5 -Detail "Ligado (o padrão do Windows)"
    }

    # Atualizações pendentes
    if ($null -eq $Facts.Updates) {
        $checks += New-WinForgeAuditCheck -Id "updates" -Title "Atualizações do Windows" -Status Unknown -Weight 10 -Detail "Não foi possível consultar o Windows Update"
    }
    elseif ($Facts.Updates.Count -gt 0) {
        $checks += New-WinForgeAuditCheck -Id "updates" -Title "Atualizações do Windows" -Status Warn -Weight 10 -Detail (Format-WinForgeCount -Count $Facts.Updates.Count -One "pendente" -Many "pendentes") `
            -Advice "Use Atualizações > Instalar atualizações do Windows"
    }
    else {
        $checks += New-WinForgeAuditCheck -Id "updates" -Title "Atualizações do Windows" -Status Ok -Weight 10 -Detail "Nenhuma pendente"
    }

    # Versão do Windows ainda recebe correções?
    $checks += Get-WinForgeWindowsSupportCheck -Facts $Facts

    # Área de Trabalho Remota
    if ($null -eq $Facts.RdpEnabled) {
        $checks += New-WinForgeAuditCheck -Id "rdp" -Title "Área de Trabalho Remota" -Status Unknown -Weight 10 -Detail "Não foi possível ler"
    }
    else {
        if ($Facts.RdpEnabled) {
            $checks += New-WinForgeAuditCheck -Id "rdp" -Title "Área de Trabalho Remota" -Status Warn -Weight 10 -Detail "Ligada: outros computadores podem tentar entrar neste" `
                -Advice "Se você não usa o acesso remoto, desligue-o em Configurações, Sistema, Área de Trabalho Remota"
        }
        else {
            $checks += New-WinForgeAuditCheck -Id "rdp" -Title "Área de Trabalho Remota" -Status Ok -Weight 10 -Detail "Desligada"
        }
    }

    # Conta Convidado
    if ($null -eq $Facts.GuestEnabled) {
        $checks += New-WinForgeAuditCheck -Id "guest" -Title "Conta Convidado" -Status Unknown -Weight 8 -Detail "Não foi possível ler"
    }
    else {
        if ($Facts.GuestEnabled) {
            $checks += New-WinForgeAuditCheck -Id "guest" -Title "Conta Convidado" -Status Warn -Weight 8 -Detail "Ligada: permite entrar sem senha" `
                -Advice "No menu Iniciar, procure Prompt de Comando, escolha Executar como administrador e digite: net user Convidado /active:no"
        }
        else {
            $checks += New-WinForgeAuditCheck -Id "guest" -Title "Conta Convidado" -Status Ok -Weight 8 -Detail "Desativada"
        }
    }

    # SMB 1.0: só entra quando foi lido (os fatos montados à mão por outra parte do WinForge podem não trazê-lo).
    if ($null -ne $Facts.PSObject.Properties["Smb1"]) {
        $smbTitle = "Compartilhamento SMB 1.0"

        if ($null -eq $Facts.Smb1) {
            $checks += New-WinForgeAuditCheck -Id "smb1" -Title $smbTitle -Status Unknown -Weight 8 -Detail "Não foi possível ler"
        }
        elseif ([string]$Facts.Smb1 -eq "On") {
            $checks += New-WinForgeAuditCheck -Id "smb1" -Title $smbTitle -Status Warn -Weight 8 -Detail "Ligado: protocolo antigo e inseguro de arquivos em rede, usado por ataques como o WannaCry" `
                -Advice "Se nenhum equipamento antigo (scanner, NAS) precisa dele, desligue-o em Programas > Recursos opcionais do Windows"
        }
        else {
            $checks += New-WinForgeAuditCheck -Id "smb1" -Title $smbTitle -Status Ok -Weight 8 -Detail "Desligado"
        }
    }

    # Entrada automática no Windows
    if ($Facts.AutoLogon -and $Facts.PasswordStored) {
        $checks += New-WinForgeAuditCheck -Id "autologon" -Title "Entrada automática" -Status Bad -Weight 8 -Detail "Ligada, com a senha gravada em texto no registro" `
            -Advice "No menu Iniciar, digite netplwiz, pressione Enter e marque 'Os usuários devem digitar um nome de usuário e uma senha para usar este computador'; depois troque a senha dessa conta"
    }
    elseif ($Facts.AutoLogon) {
        $checks += New-WinForgeAuditCheck -Id "autologon" -Title "Entrada automática" -Status Warn -Weight 8 -Detail "Ligada: quem ligar o PC entra sem senha" `
            -Advice "Se o PC sai de casa: no menu Iniciar, digite netplwiz, pressione Enter e marque 'Os usuários devem digitar um nome de usuário e uma senha para usar este computador'"
    }
    else {
        $checks += New-WinForgeAuditCheck -Id "autologon" -Title "Entrada automática" -Status Ok -Weight 8 -Detail "Desligada"
    }

    # Só informam (não entram na nota)
    if ($null -eq $Facts.BitLocker) {
        $checks += New-WinForgeAuditCheck -Id "bitlocker" -Title "Criptografia do disco" -Status Unknown -Detail "Não verificada (esta edição do Windows pode não ter o BitLocker)"
    }
    elseif ($Facts.BitLocker -eq "On") {
        $checks += New-WinForgeAuditCheck -Id "bitlocker" -Title "Criptografia do disco" -Status Ok -Detail "Ligada no disco do sistema"
    }
    elseif ($Facts.BitLocker -eq "Suspended") {
        # A proteção costuma ficar suspensa depois de uma atualização da BIOS.
        $checks += New-WinForgeAuditCheck -Id "bitlocker" -Title "Criptografia do disco" -Status Warn -Detail "Criptografado, mas com a proteção suspensa: a chave fica gravada no disco" `
            -Advice "Retome a proteção no Painel de Controle, em Criptografia de Unidade de Disco BitLocker (ou em Criptografia do dispositivo)"
    }
    elseif ($Facts.BitLocker -eq "Encrypting") {
        $checks += New-WinForgeAuditCheck -Id "bitlocker" -Title "Criptografia do disco" -Status Ok -Detail "Criptografando o disco do sistema; a proteção liga quando terminar"
    }
    elseif ($Facts.BitLocker -eq "Pending") {
        $checks += New-WinForgeAuditCheck -Id "bitlocker" -Title "Criptografia do disco" -Status Warn -Detail "O disco do sistema está preparado, mas a criptografia espera ativação" `
            -Advice "Ligue-a em Configurações, Privacidade e segurança, Criptografia do dispositivo; ela guarda a chave de recuperação na sua conta Microsoft"
    }
    else {
        $checks += New-WinForgeAuditCheck -Id "bitlocker" -Title "Criptografia do disco" -Status Warn -Detail "Desligada no disco do sistema" `
            -Advice "Em notebooks, a criptografia protege seus arquivos se o PC for perdido ou roubado"
    }

    if ($null -eq $Facts.SecureBoot) {
        $checks += New-WinForgeAuditCheck -Id "secureboot" -Title "Inicialização segura (Secure Boot)" -Status Unknown -Detail "Não verificada"
    }
    elseif ([string]$Facts.SecureBoot -eq "Legacy") {
        $checks += New-WinForgeAuditCheck -Id "secureboot" -Title "Inicialização segura (Secure Boot)" -Status Warn -Detail "Indisponível: o Windows iniciou no modo BIOS legado" `
            -Advice "Ela pede o modo UEFI, trabalho para um técnico"
    }
    elseif ($Facts.SecureBoot -eq $true) {
        $checks += New-WinForgeAuditCheck -Id "secureboot" -Title "Inicialização segura (Secure Boot)" -Status Ok -Detail "Ligada"
    }
    else {
        $checks += New-WinForgeAuditCheck -Id "secureboot" -Title "Inicialização segura (Secure Boot)" -Status Warn -Detail "Desligada" `
            -Advice "Ligue-a na configuração da placa-mãe (UEFI); ela impede vírus de carregar antes do Windows"
    }

    return @($checks)
}


function Get-WinForgeSecurityGrade {
    <#
    A nota da auditoria, de 0 a 100, com as mesmas faixas da nota de saúde do Início (Grade): Ótima de 90, Boa de 75,
    Pede atenção de 50, senão Crítica. Ok vale o peso inteiro, Warn metade e Bad zero; o que não pôde ser verificado
    (Unknown) e o que só informa (peso 0) ficam fora da conta.
    Sem nota ("?", Score nulo) quando menos da metade do peso pôde ser verificada (NoGradeReason = "Coverage"): uma nota
    alta tirada só da conta Convidado e da entrada automática diria que o PC está protegido sem ter olhado o antivírus.
    Pelo mesmo motivo, também não há nota quando o próprio antivírus não pôde ser verificado (NoGradeReason =
    "Antivirus"), mesmo com o resto lido: sem saber se há um antivírus ativo, nenhuma nota diz se o PC está protegido.
    Unverified diz quantos pontos com peso ficaram de fora; Verified e Total, quantos pontos com peso existem e quantos
    foram lidos. Dois tetos evitam uma nota alta com um problema real: qualquer ponto em Bad deixa a nota em no máximo 89
    (fora de Ótima), e um problema grave (Critical + Bad: antivírus, tempo real, ameaças, firewall público ou UAC) em no
    máximo 74 (fora do verde), como um ponto grave no Início. Cap é o teto aplicado (74, 89 ou nulo) e Capped diz se ele
    baixou a nota.
    #>
    param (
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Checks
    )

    $weighted = @($Checks | Where-Object { $_.Weight -gt 0 })
    $scored = @($weighted | Where-Object { $_.Status -ne "Unknown" })
    $unverified = $weighted.Count - $scored.Count
    $totalWeight = 0
    $possible = 0
    $earned = 0.0

    foreach ($check in $weighted) { $totalWeight += $check.Weight }

    foreach ($check in $scored) {
        $possible += $check.Weight

        switch ($check.Status) {
            "Ok"   { $earned += $check.Weight }
            "Warn" { $earned += $check.Weight / 2 }
        }
    }

    $antivirusUnknown = (@($weighted | Where-Object { $_.Id -eq "antivirus" -and $_.Status -eq "Unknown" }).Count -gt 0)
    $noGradeReason = $(if ($possible -eq 0 -or ($possible * 2) -lt $totalWeight) { "Coverage" } elseif ($antivirusUnknown) { "Antivirus" } else { "" })

    if ($noGradeReason) {
        return [PSCustomObject]@{ Score = $null; Grade = "?"; Cap = $null; Capped = $false; Scored = $scored.Count; Unverified = $unverified; Verified = $scored.Count; Total = $weighted.Count; NoGradeReason = $noGradeReason }
    }

    $score = [int][math]::Round(100 * $earned / $possible, [MidpointRounding]::AwayFromZero)
    $cap = $null

    if (@($scored | Where-Object { $_.Critical -and $_.Status -eq "Bad" }).Count -gt 0) {
        $cap = 74
    }
    elseif (@($scored | Where-Object { $_.Status -eq "Bad" }).Count -gt 0) {
        $cap = 89
    }

    $capped = ($null -ne $cap -and $score -gt $cap)

    if ($capped) { $score = [int]$cap }

    $grade = Get-WinForgeSecurityGradeLabel -Score $score

    return [PSCustomObject]@{ Score = $score; Grade = $grade; Cap = $cap; Capped = $capped; Scored = $scored.Count; Unverified = $unverified; Verified = $scored.Count; Total = $weighted.Count; NoGradeReason = "" }
}


function Get-WinForgeSecurityGradeLabel {
    # A faixa de uma nota de 0 a 100, a mesma da nota de saúde do Início: as duas notas do WinForge falam a mesma língua.
    param ([int]$Score)

    if ($Score -ge 90) { return "Ótima" }
    if ($Score -ge 75) { return "Boa" }
    if ($Score -ge 50) { return "Pede atenção" }

    return "Crítica"
}


function Format-WinForgeSecurityGrade {
    # "84 de 100 · Boa" (a nota com a faixa), como a tela e a linha de comando mostram.
    param ([Parameter(Mandatory)]$Grade)

    if ($null -eq $Grade.Score) { return "sem nota" }

    return "$($Grade.Score) de 100 · $($Grade.Grade)"
}


function Get-WinForgeSecurityAuditStatusType {
    param ([Parameter(Mandatory)][string]$Status)

    switch ($Status) {
        "Ok"    { return "Success" }
        "Warn"  { return "Warning" }
        "Bad"   { return "Error" }
        default { return "Info" }
    }
}


function Show-WinForgeSecurityAudit {
    <#
    Confere vários pontos da proteção do PC e dá uma nota. Só lê: nada é ligado, desligado ou alterado.
    #>
    param (
        [switch]$Embedded,
        [switch]$PassThru
    )

    $title = "Auditoria de segurança"

    Enter-WinForgeAction -Title $title -Embedded:$Embedded

    $result = $null

    try {
        # A auditoria só lê as configurações do PC: nada é alterado (por isso não há pergunta antes).
        # O andamento vai na barra: linhas "Consultando..." ficariam no resumo depois do fim.
        Write-Progress -Activity $title -Status "consultando o antivírus, o firewall e as configurações do Windows"

        try {
            $facts = Get-WinForgeSecurityAuditFacts
            Write-Progress -Activity $title -Status "consultando o Windows Update (pode levar até um minuto e meio)"
            $facts.Updates = Get-WinForgePendingWindowsUpdates
        }
        finally {
            Write-Progress -Activity $title -Completed
        }

        $checks = @(Get-WinForgeSecurityAuditChecks -Facts $facts)
        $grade = Get-WinForgeSecurityGrade -Checks $checks
        $unverifiedChecks = @($checks | Where-Object { $_.Weight -gt 0 -and $_.Status -eq "Unknown" })

        Write-WinForgeSection -Title "Nota"

        # Por que não há nota: o antivírus sem leitura, ou menos da metade da proteção verificada.
        $noGradeAntivirus = ([string](Get-WinForgeJsonValue -Object $grade -Name "NoGradeReason" -Default "") -eq "Antivirus")
        $coverage = $(
            if ($noGradeAntivirus) { "o antivírus não pôde ser verificado" }
            elseif ($grade.Verified -eq 0) { "nenhum ponto pôde ser verificado" }
            else { "só $($grade.Verified) de $($grade.Total) pontos puderam ser verificados" }
        )

        if ($null -eq $grade.Score) {
            # O motivo já está na linha da nota: a nota precisa do antivírus verificado (sem saber se há um ativo, ela
            # diria mais do que foi visto) e de pelo menos metade da proteção verificada.
            Write-WinForgeKeyValue -Label "Nota de segurança" -Value "Sem nota: $coverage"
            Write-WinForgeStatus -Type Warning -Message "Não puderam ser verificados: $(Join-WinForgeList -Items @($unverifiedChecks | ForEach-Object { $_.Title }))."
        }
        else {
            $noteText = Format-WinForgeSecurityGrade -Grade $grade

            if ($unverifiedChecks.Count -gt 0) {
                $noteText += ", sem $(Format-WinForgeCount -Count $unverifiedChecks.Count -One 'ponto que não pôde ser verificado' -Many 'pontos que não puderam ser verificados')"
            }

            Write-WinForgeKeyValue -Label "Nota de segurança" -Value $noteText

            if ($unverifiedChecks.Count -gt 0) {
                Write-WinForgeStatus -Type Warning -Message "Ficaram de fora: $(Join-WinForgeList -Items @($unverifiedChecks | ForEach-Object { $_.Title }))."
            }

            if ($grade.Capped -and [int]$grade.Cap -eq 74) {
                Write-WinForgeStatus -Type Warning -Message "A nota ficou em no máximo 74 por causa de um problema grave na proteção do PC."
            }
            elseif ($grade.Capped) {
                Write-WinForgeStatus -Type Warning -Message "A nota ficou em no máximo 89 porque há pelo menos um ponto com risco real."
            }
        }

        $scoredChecks = @($checks | Where-Object { $_.Weight -gt 0 })
        $infoChecks = @($checks | Where-Object { $_.Weight -eq 0 })

        # O que fazer vem como mensagem logo abaixo do ponto: na janela, fica no resumo (os detalhes técnicos ficam
        # recolhidos quando há faixa de resultado).
        Write-WinForgeSection -Title "Pontos verificados"

        # O que pede ação primeiro (risco real, depois atenção), depois o que não pôde ser verificado e, por último, o que
        # está em ordem; dentro de cada grupo, a ordem de importância.
        $order = @{ "Bad" = 0; "Warn" = 1; "Unknown" = 2; "Ok" = 3 }
        $position = 0
        $scoredChecks = @($scoredChecks | ForEach-Object { [PSCustomObject]@{ Check = $_; Rank = $order[[string]$_.Status]; Position = $position++ } } | Sort-Object -Property Rank, Position | ForEach-Object { $_.Check })

        foreach ($check in $scoredChecks) {
            Write-WinForgeStatus -Type (Get-WinForgeSecurityAuditStatusType -Status $check.Status) -Message "$($check.Title): $($check.Detail)"

            if (-not [string]::IsNullOrWhiteSpace($check.Advice)) {
                Write-WinForgeStatus -Type Info -Message "O que fazer: $($check.Advice)."
            }
        }

        if ($infoChecks.Count -gt 0) {
            Write-WinForgeSection -Title "Só para saber (não entram na nota)"

            foreach ($check in $infoChecks) {
                Write-WinForgeStatus -Type $(if ($check.Status -eq "Ok") { "Success" } else { "Info" }) -Message "$($check.Title): $($check.Detail)"

                if (-not [string]::IsNullOrWhiteSpace($check.Advice)) {
                    Write-WinForgeStatus -Type Info -Message "$($check.Advice)."
                }
            }
        }

        # Sem Administrador, algumas leituras são negadas pelo Windows (as ameaças guardadas e o BitLocker, por exemplo).
        if (@($checks | Where-Object { $_.Status -eq "Unknown" }).Count -gt 0 -and -not (Test-WinForgeAdministrator)) {
            Write-Host ""
            Write-WinForgeStatus -Type Info -Message "Alguns pontos só podem ser verificados com o WinForge aberto como Administrador."
        }

        $attention = @($checks | Where-Object { $_.Weight -gt 0 -and $_.Status -in "Warn", "Bad" })
        $attentionText = Format-WinForgeCount -Count $attention.Count -One "ponto de atenção" -Many "pontos de atenção"
        $unverifiedNote = $(if ($grade.Unverified -gt 0) { "; $($grade.Unverified) sem verificar" } else { "" })
        $data = @{ Grade = $grade.Grade; Score = $grade.Score }

        if ($null -eq $grade.Score) {
            $detail = "sem nota: $coverage"
            if ($attention.Count -gt 0) { $detail += "; $attentionText" }

            $result = New-WinForgeResult -Kind Warning -Detail $detail -Data $data
        }
        elseif ($attention.Count -eq 0 -and $grade.Unverified -eq 0) {
            $result = New-WinForgeResult -Kind Ok -Detail "nota $(Format-WinForgeSecurityGrade -Grade $grade); nenhum ponto de atenção" -Data $data
        }
        elseif ($attention.Count -eq 0) {
            # Nenhum problema nos pontos lidos, mas um "tudo certo" só vale se tudo o que pesa na nota foi lido.
            $result = New-WinForgeResult -Kind Warning -Detail "nota $(Format-WinForgeSecurityGrade -Grade $grade); nenhum ponto de atenção no que foi lido$unverifiedNote" -Data $data
        }
        else {
            $result = New-WinForgeResult -Kind Warning -Detail "nota $(Format-WinForgeSecurityGrade -Grade $grade); $attentionText$unverifiedNote" -Data $data
        }

        # A faixa da janela: a nota como título; embaixo, os pontos que pedem ação, pelo nome. Vermelho com um problema
        # grave (o que segura a nota em 74) ou nota abaixo de 50; o botão leva aonde se resolve o primeiro da lista.
        $sortedAttention = @($scoredChecks | Where-Object { $_.Status -in "Warn", "Bad" })
        $step = $null

        foreach ($check in $sortedAttention) {
            $step = Get-WinForgeSecurityNextStep -Id $check.Id
            if ($null -ne $step) { break }
        }

        $headline = $(if ($null -eq $grade.Score) { "Sem nota de segurança" } else { "Nota $($grade.Score) de 100 · $($grade.Grade)" })
        $noteParts = @()
        if ($null -eq $grade.Score) { $noteParts += "$(ConvertTo-WinForgeHeadline -Text $coverage)." }
        if ($sortedAttention.Count -gt 0) { $noteParts += "$(ConvertTo-WinForgeHeadline -Text $attentionText): $(Join-WinForgeList -Items @($sortedAttention | ForEach-Object { $_.Title }))." }
        if ($grade.Unverified -gt 0 -and $null -ne $grade.Score) { $noteParts += "$(ConvertTo-WinForgeHeadline -Text (Format-WinForgeCount -Count $grade.Unverified -One 'ponto não pôde ser verificado' -Many 'pontos não puderam ser verificados'))." }
        if ($noteParts.Count -eq 0) { $noteParts += "Nenhum ponto de atenção." }

        $severe = (@($scoredChecks | Where-Object { $_.Critical -and $_.Status -eq "Bad" }).Count -gt 0) -or ($null -ne $grade.Score -and [int]$grade.Score -lt 50)
        $tone = $(if ($severe) { "Bad" } elseif ($sortedAttention.Count -gt 0 -or $grade.Unverified -gt 0 -or $null -eq $grade.Score) { "Warn" } else { "" })

        [void](Set-WinForgeResultView -Result $result -Headline $headline -Note ($noteParts -join " ") -Tone $tone -Next $(if ($null -ne $step) { $step.Next } else { "" }) -NextLabel $(if ($null -ne $step) { $step.Label } else { "" }))
    }
    catch {
        Write-WinForgeStatus -Type Error -Message "Ocorreu um erro na auditoria de segurança: $($_.Exception.Message)"
        $result = New-WinForgeResult -Kind Failed -Detail $_.Exception.Message
    }

    $result.Etapa = $title
    Exit-WinForgeAction -Embedded:$Embedded -Result $result

    if ($PassThru) {
        return $result
    }
}


Export-ModuleMember -Function *
