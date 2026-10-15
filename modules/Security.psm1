# Segurança: o estado da proteção do Windows (antivírus, firewall, atualizações pendentes, ameaças) e a verificação
# do Windows Defender. Tudo usa os comandos do próprio Windows (Get-MpComputerStatus, Update-MpSignature, Start-MpScan).
#
# Quando outro antivírus protege o PC, o Defender fica desligado ou em modo passivo: o WinForge diz isso e não
# tenta verificar, em vez de fingir que o PC foi checado.


# ---------------------------------------------------------------------------
# Leitura tolerante
# ---------------------------------------------------------------------------

function Get-WinForgeMpValue {
    # Propriedade de um objeto do Defender, ou $Default. Versões diferentes do Windows expõem conjuntos diferentes de
    # propriedades, e acessar uma que não existe derrubaria a tela sob Set-StrictMode.
    param (
        $Object,

        [Parameter(Mandatory)]
        [string]$Name,

        $Default = $null
    )

    if ($null -eq $Object) {
        return $Default
    }

    $property = $Object.PSObject.Properties[$Name]

    if ($null -eq $property -or $null -eq $property.Value) {
        return $Default
    }

    return $property.Value
}


function ConvertTo-WinForgeMpDate {
    # O Defender usa datas antigas (1601, 1970) para "nunca aconteceu". Qualquer data antes de 2000 vira $null.
    param ($Value)

    if ($Value -isnot [datetime] -or ([datetime]$Value).Year -lt 2000) {
        return $null
    }

    return [datetime]$Value
}


function Get-WinForgeOtherAntivirus {
    # Nomes dos antivírus registrados na Central de Segurança que não são o Defender. Vazio também quando não dá para ler.
    try {
        $products = @(Get-CimInstance -Namespace "root\SecurityCenter2" -ClassName "AntiVirusProduct" -ErrorAction Stop)
    }
    catch {
        return @()
    }

    return @(
        $products |
            ForEach-Object { [string](Get-WinForgeMpValue -Object $_ -Name "displayName" -Default "") } |
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
    antivírus identificado), Off (desligado e sem outro antivírus) ou Unavailable (não foi possível ler).
    #>
    $computerStatus = $null

    try {
        $computerStatus = Get-MpComputerStatus -ErrorAction Stop
    }
    catch {
        $computerStatus = $null
    }

    $others = @(Get-WinForgeOtherAntivirus)

    $status = [PSCustomObject]@{
        Mode              = "Unavailable"
        RealTime          = $null
        SignaturesUpdated = $null
        SignatureAgeDays  = $null
        SignatureVersion  = ""
        LastQuickScan     = $null
        LastFullScan      = $null
        Others            = $others
    }

    if ($null -eq $computerStatus) {
        if ($others.Count -gt 0) { $status.Mode = "Other" }

        return $status
    }

    $serviceOn = [bool](Get-WinForgeMpValue -Object $computerStatus -Name "AMServiceEnabled" -Default $true)
    $antivirusOn = [bool](Get-WinForgeMpValue -Object $computerStatus -Name "AntivirusEnabled" -Default $false)
    $runningMode = [string](Get-WinForgeMpValue -Object $computerStatus -Name "AMRunningMode" -Default "")
    $passive = ($runningMode -match 'Passive|EDR Block')

    if (-not $serviceOn -or -not $antivirusOn -or $passive) {
        if ($others.Count -gt 0) { $status.Mode = "Other" }
        elseif ($passive) { $status.Mode = "Passive" }
        else { $status.Mode = "Off" }
    }
    else {
        $status.Mode = "Active"
    }

    $status.RealTime = [bool](Get-WinForgeMpValue -Object $computerStatus -Name "RealTimeProtectionEnabled" -Default $false)
    $status.SignatureVersion = [string](Get-WinForgeMpValue -Object $computerStatus -Name "AntivirusSignatureVersion" -Default "")
    $status.LastQuickScan = ConvertTo-WinForgeMpDate -Value (Get-WinForgeMpValue -Object $computerStatus -Name "QuickScanEndTime")
    $status.LastFullScan = ConvertTo-WinForgeMpDate -Value (Get-WinForgeMpValue -Object $computerStatus -Name "FullScanEndTime")
    $status.SignaturesUpdated = ConvertTo-WinForgeMpDate -Value (Get-WinForgeMpValue -Object $computerStatus -Name "AntivirusSignatureLastUpdated")

    if ($null -ne $status.SignaturesUpdated) {
        $status.SignatureAgeDays = [int][math]::Max(0, [math]::Floor(((Get-Date) - $status.SignaturesUpdated).TotalDays))
    }

    return $status
}


function Get-WinForgeFirewallStatus {
    # Um item por perfil de rede (Domain, Private, Public) com Enabled. $null quando não foi possível ler.
    try {
        $profiles = @(Get-NetFirewallProfile -ErrorAction Stop)
    }
    catch {
        return $null
    }

    if ($profiles.Count -eq 0) {
        return $null
    }

    return @(
        foreach ($firewallProfile in $profiles) {
            [PSCustomObject]@{
                Name    = [string](Get-WinForgeMpValue -Object $firewallProfile -Name "Name" -Default "")
                Enabled = ([string](Get-WinForgeMpValue -Object $firewallProfile -Name "Enabled" -Default "") -eq "True")
            }
        }
    )
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
        $name = [string](Get-WinForgeMpValue -Object $threat -Name "ThreatName" -Default "")

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
            Where-Object { [bool](Get-WinForgeMpValue -Object $_ -Name "IsActive" -Default $false) } |
            ForEach-Object {
                $name = [string](Get-WinForgeMpValue -Object $_ -Name "ThreatName" -Default "")
                if ([string]::IsNullOrWhiteSpace($name)) { $name = "ameaça $(Get-WinForgeMpValue -Object $_ -Name 'ThreatID' -Default '?')" }
                $name
            } |
            Select-Object -Unique
    )
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
        "Off"         { $findings += [PSCustomObject]@{ Level = "Warning"; Text = "O antivírus do Windows está desligado e nenhum outro antivírus foi encontrado. Ligue-o em Segurança do Windows." } }
        "Unavailable" { $findings += [PSCustomObject]@{ Level = "Warning"; Text = "Não foi possível ler o estado do antivírus. Confira em Segurança do Windows." } }
        "Passive"     { $findings += [PSCustomObject]@{ Level = "Info"; Text = "O Windows Defender está em modo passivo: outro antivírus deve estar protegendo este PC." } }
        "Other"       { $findings += [PSCustomObject]@{ Level = "Info"; Text = "Outro antivírus protege este PC ($($Antivirus.Others -join ', ')); o Windows Defender fica de reserva." } }
        "Active" {
            if ($Antivirus.RealTime -eq $false) {
                $findings += [PSCustomObject]@{ Level = "Warning"; Text = "A proteção em tempo real está desligada. Ligue-a em Segurança do Windows." }
            }
        }
    }

    if ($Antivirus.Mode -eq "Active" -and $null -ne $Antivirus.SignatureAgeDays) {
        if ($Antivirus.SignatureAgeDays -gt 7) {
            $findings += [PSCustomObject]@{ Level = "Warning"; Text = "As assinaturas do antivírus têm $($Antivirus.SignatureAgeDays) dias. Use Segurança > Atualizar assinaturas do antivírus." }
        }
        elseif ($Antivirus.SignatureAgeDays -gt 3) {
            $findings += [PSCustomObject]@{ Level = "Info"; Text = "As assinaturas do antivírus têm $($Antivirus.SignatureAgeDays) dias; o normal é atualizarem todo dia." }
        }
    }

    if ($null -ne $Threats -and @($Threats).Count -gt 0) {
        $findings += [PSCustomObject]@{ Level = "Warning"; Text = "$(@($Threats).Count) ameaça(s) ativa(s): $(@($Threats) -join ', '). Abra a Segurança do Windows para ver as ações." }
    }

    if ($null -eq $Firewall) {
        $findings += [PSCustomObject]@{ Level = "Info"; Text = "Não foi possível ler o estado do firewall." }
    }
    else {
        $off = @($Firewall | Where-Object { -not $_.Enabled } | ForEach-Object { Get-WinForgeFirewallProfileName -Name $_.Name })

        if ($off.Count -gt 0) {
            $findings += [PSCustomObject]@{ Level = "Warning"; Text = "O firewall está desligado em: $($off -join ', '). Ligue-o em Segurança do Windows." }
        }
    }

    if ($null -ne $Updates -and $Updates.Count -gt 0) {
        $findings += [PSCustomObject]@{ Level = "Warning"; Text = "$($Updates.Count) atualização(ões) do Windows pendente(s). Use Atualizações > Windows Update." }
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
        "Other"       { return "Outro antivírus em uso: $($Antivirus.Others -join ', ')" }
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

    $text = "$($Antivirus.SignaturesUpdated.ToString('dd/MM/yyyy HH:mm')) ($(Format-WinForgeRelativeTime -When $Antivirus.SignaturesUpdated))"

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

    return "$(([datetime]$When).ToString('dd/MM/yyyy HH:mm')) ($(Format-WinForgeRelativeTime -When ([datetime]$When)))"
}


function Show-WinForgeSecurityStatus {
    Enter-WinForgeAction -Title "Estado da proteção"

    try {
        Write-WinForgeStatus -Type Running -Message "Consultando o antivírus e o firewall..."

        $status = Get-WinForgeSecurityStatus
        $antivirus = $status.Antivirus

        Write-WinForgeSection -Title "Antivírus"
        Write-WinForgeKeyValue -Label "Situação" -Value (Get-WinForgeAntivirusModeText -Antivirus $antivirus)

        if ($antivirus.Mode -in "Active", "Passive", "Other") {
            Write-WinForgeKeyValue -Label "Assinaturas" -Value (Get-WinForgeSignatureText -Antivirus $antivirus)
        }

        if ($antivirus.Mode -eq "Active") {
            Write-WinForgeKeyValue -Label "Última verificação rápida" -Value (Get-WinForgeScanDateText -When $antivirus.LastQuickScan)
            Write-WinForgeKeyValue -Label "Última verificação completa" -Value (Get-WinForgeScanDateText -When $antivirus.LastFullScan)
        }

        if ($null -ne $status.Threats) {
            Write-WinForgeKeyValue -Label "Ameaças ativas" -Value $(if (@($status.Threats).Count -eq 0) { "Nenhuma" } else { @($status.Threats) -join ", " })
        }

        Write-WinForgeSection -Title "Firewall"

        if ($null -eq $status.Firewall) {
            Write-WinForgeKeyValue -Label "Situação" -Value "Não foi possível ler"
        }
        else {
            foreach ($firewallProfile in @($status.Firewall)) {
                Write-WinForgeKeyValue -Label (Get-WinForgeFirewallProfileName -Name $firewallProfile.Name) -Value $(if ($firewallProfile.Enabled) { "Ligado" } else { "Desligado" })
            }
        }

        # O que já se sabe aparece antes; a consulta ao Windows Update, que pode demorar, vem por último.
        Write-WinForgeSection -Title "Windows Update"
        Write-WinForgeStatus -Type Running -Message "Consultando o Windows Update (pode levar até um minuto)..."
        Write-Progress -Activity "Windows Update" -Status "Procurando atualizações pendentes"

        try {
            $updates = Get-WinForgePendingWindowsUpdates
        }
        finally {
            Write-Progress -Activity "Windows Update" -Completed
        }

        if ($null -eq $updates) {
            Write-WinForgeKeyValue -Label "Atualizações pendentes" -Value "Não foi possível consultar (o Windows Update demorou ou está indisponível)"
        }
        elseif ($updates.Count -eq 0) {
            Write-WinForgeKeyValue -Label "Atualizações pendentes" -Value "Nenhuma"
        }
        else {
            Write-WinForgeKeyValue -Label "Atualizações pendentes" -Value $updates.Count

            foreach ($title in @($updates.Titles | Select-Object -First 5)) {
                Write-Host "      $title" -ForegroundColor DarkGray
            }

            if ($updates.Count -gt 5) {
                Write-Host "      ... e mais $($updates.Count - 5)." -ForegroundColor DarkGray
            }
        }

        Write-WinForgeSection -Title "Resumo"

        $findings = @(Get-WinForgeSecurityFindings -Antivirus $antivirus -Firewall $status.Firewall -Updates $updates -Threats $status.Threats)
        $warnings = @($findings | Where-Object { $_.Level -eq "Warning" })

        if ($warnings.Count -eq 0) {
            Write-WinForgeStatus -Type Success -Message "Nenhum ponto de atenção na proteção do PC."
        }

        foreach ($finding in $findings) {
            Write-WinForgeStatus -Type $finding.Level -Message $finding.Text
        }
    }
    catch {
        Write-WinForgeStatus -Type Error -Message "Ocorreu um erro ao consultar a proteção do PC: $($_.Exception.Message)"
    }

    Exit-WinForgeAction
}


# ---------------------------------------------------------------------------
# Assinaturas e verificação
# ---------------------------------------------------------------------------

function Test-WinForgeDefenderReady {
    <#
    Confere se dá para usar o Defender agora: Administrador, comandos disponíveis e o Defender sendo quem protege o PC.
    Devolve Ready e, quando não está pronto, o Result que a ação deve devolver (já com a explicação na tela).
    #>
    if (-not (Test-WinForgeElevation -Reason "Esta ação exige privilégios de Administrador.")) {
        return [PSCustomObject]@{ Ready = $false; Result = (New-WinForgeResult -Kind Failed -Detail "requer Administrador") }
    }

    $antivirus = Get-WinForgeAntivirusStatus

    switch ($antivirus.Mode) {
        "Active" {
            return [PSCustomObject]@{ Ready = $true; Result = $null }
        }
        "Other" {
            Write-WinForgeStatus -Type Info -Message "Outro antivírus protege este PC ($($antivirus.Others -join ', ')); o Windows Defender está desligado ou em modo passivo."
            Write-Host "      Use o outro antivírus para verificar o PC." -ForegroundColor DarkGray
            return [PSCustomObject]@{ Ready = $false; Result = (New-WinForgeResult -Kind Skipped -Detail "outro antivírus em uso") }
        }
        "Passive" {
            Write-WinForgeStatus -Type Info -Message "O Windows Defender está em modo passivo, então outro antivírus deve estar protegendo este PC."
            return [PSCustomObject]@{ Ready = $false; Result = (New-WinForgeResult -Kind Skipped -Detail "Defender em modo passivo") }
        }
        "Off" {
            Write-WinForgeStatus -Type Warning -Message "O antivírus do Windows está desligado e nenhum outro antivírus foi encontrado."
            Write-Host "      Abra Segurança do Windows para ligar a proteção." -ForegroundColor DarkGray
            return [PSCustomObject]@{ Ready = $false; Result = (New-WinForgeResult -Kind Warning -Detail "antivírus desligado") }
        }
        default {
            Write-WinForgeStatus -Type Warning -Message "Os comandos do Windows Defender não estão disponíveis neste Windows."
            return [PSCustomObject]@{ Ready = $false; Result = (New-WinForgeResult -Kind Skipped -Detail "Defender indisponível") }
        }
    }
}


function Invoke-WinForgeSignatureUpdate {
    # Atualiza as assinaturas do Defender e devolve um WinForge.Result. Não abre nem fecha a ação (quem chama faz isso).
    # -AssumeReady pula a conferência de Test-WinForgeDefenderReady quando quem chama já a fez.
    param (
        [switch]$AssumeReady
    )

    if (-not $AssumeReady) {
        $ready = Test-WinForgeDefenderReady

        if (-not $ready.Ready) {
            return $ready.Result
        }
    }

    $before = (Get-WinForgeAntivirusStatus).SignatureVersion

    Write-WinForgeCommand -Command "Update-MpSignature"
    Write-WinForgeStatus -Type Running -Message "Baixando as assinaturas mais recentes do antivírus..."

    Write-Progress -Activity "Windows Defender" -Status "Baixando as assinaturas do antivírus"

    try {
        Update-MpSignature -ErrorAction Stop
    }
    catch {
        Write-WinForgeStatus -Type Error -Message "Não foi possível atualizar as assinaturas: $($_.Exception.Message)"
        Write-Host "      Confira a conexão com a internet; se o problema continuar, use Atualizações > Windows Update." -ForegroundColor DarkGray
        return (New-WinForgeResult -Kind Failed -Detail "falha ao baixar as assinaturas")
    }
    finally {
        Write-Progress -Activity "Windows Defender" -Completed
    }

    $after = Get-WinForgeAntivirusStatus

    if ($after.SignatureAgeDays -gt 3) {
        Write-WinForgeStatus -Type Warning -Message "O Windows concluiu a atualização, mas as assinaturas continuam com $($after.SignatureAgeDays) dias ($(Get-WinForgeSignatureText -Antivirus $after))."
        return (New-WinForgeResult -Kind Warning -Detail "assinaturas ainda antigas" -Data @{ SignatureVersion = $after.SignatureVersion })
    }

    $changed = $(if ($before -and $after.SignatureVersion -and $before -ne $after.SignatureVersion) { " (antes: $before)" } else { "" })
    Write-WinForgeStatus -Type Success -Message "Assinaturas em dia: $(Get-WinForgeSignatureText -Antivirus $after)$changed."

    return (New-WinForgeResult -Kind Ok -Data @{ SignatureVersion = $after.SignatureVersion })
}


function Get-WinForgeScanDetections {
    # Ameaças detectadas desde $Since: um item por ameaça, com Name e Resources. $null se o Windows não deixou consultar.
    param (
        [Parameter(Mandatory)]
        [datetime]$Since
    )

    try {
        $detections = @(Get-MpThreatDetection -ErrorAction Stop)
    }
    catch {
        return $null
    }

    $recent = @(
        $detections | Where-Object {
            $when = Get-WinForgeMpValue -Object $_ -Name "InitialDetectionTime"
            $when -is [datetime] -and $when -ge $Since
        }
    )

    $found = @()

    foreach ($group in @($recent | Group-Object -Property { [string](Get-WinForgeMpValue -Object $_ -Name "ThreatID" -Default "") })) {
        $first = $group.Group | Select-Object -First 1
        $resources = @($group.Group | ForEach-Object { Get-WinForgeMpValue -Object $_ -Name "Resources" -Default @() } | ForEach-Object { $_ } | Select-Object -Unique)

        $found += [PSCustomObject]@{
            Name      = Get-WinForgeThreatName -ThreatId (Get-WinForgeMpValue -Object $first -Name "ThreatID")
            Resources = @($resources)
        }
    }

    # A vírgula impede que uma lista vazia vire $null ao sair da função ($null significa "não foi possível consultar").
    return , @($found)
}


function Invoke-WinForgeDefenderScan {
    <#
    Roda uma verificação do Defender (Quick, Full ou Custom com -Path) e devolve um WinForge.Result. Data traz ScanType
    e ThreatCount. Não abre nem fecha a ação (quem chama faz isso).
    #>
    param (
        [Parameter(Mandatory)]
        [ValidateSet("Quick", "Full", "Custom")]
        [string]$Type,

        [string]$Path = "",

        # Pula a conferência de Test-WinForgeDefenderReady quando quem chama já a fez.
        [switch]$AssumeReady
    )

    if (-not $AssumeReady) {
        $ready = Test-WinForgeDefenderReady

        if (-not $ready.Ready) {
            return $ready.Result
        }
    }

    $scanType = switch ($Type) {
        "Quick"  { "QuickScan" }
        "Full"   { "FullScan" }
        "Custom" { "CustomScan" }
    }

    $arguments = @{ ScanType = $scanType }
    $command = "Start-MpScan -ScanType $scanType"

    if ($Type -eq "Custom") {
        if (-not (Test-Path -LiteralPath $Path)) {
            Write-WinForgeStatus -Type Error -Message "Pasta ou arquivo não encontrado: $Path"
            return (New-WinForgeResult -Kind Failed -Detail "caminho não encontrado")
        }

        $arguments["ScanPath"] = $Path
        $command += " -ScanPath `"$Path`""
    }

    switch ($Type) {
        "Quick"  { Write-Host "Examina os locais onde as ameaças mais aparecem; costuma levar de 2 a 15 minutos." -ForegroundColor Yellow }
        "Full"   { Write-Host "Examina todos os arquivos; pode levar de uma hora a várias horas, e o PC fica mais lento." -ForegroundColor Yellow }
        "Custom" { Write-Host "Examina somente: $Path" -ForegroundColor Yellow }
    }

    Write-Host "O Windows Defender cuida sozinho do que encontrar (quarentena ou remoção)." -ForegroundColor Cyan
    Write-Host "Se você parar esta tela, a verificação pode continuar em segundo plano; confira em Segurança do Windows." -ForegroundColor DarkGray
    Write-Host ""
    Write-WinForgeCommand -Command $command
    Write-Host ""
    Write-WinForgeStatus -Type Running -Message "Verificando. Isto não mostra porcentagem; aguarde até a mensagem final."

    $startedAt = (Get-Date).AddMinutes(-1)

    # Sem porcentagem: o Defender só responde quando termina. A barra indeterminada mostra que ainda está trabalhando.
    Write-Progress -Activity "Windows Defender" -Status "Verificação em andamento"

    try {
        Start-MpScan @arguments -ErrorAction Stop
    }
    catch {
        Write-WinForgeStatus -Type Error -Message "A verificação não foi concluída: $($_.Exception.Message)"
        return (New-WinForgeResult -Kind Failed -Detail $_.Exception.Message -Data @{ ScanType = $Type })
    }
    finally {
        Write-Progress -Activity "Windows Defender" -Completed
    }

    Write-Host ""
    $detections = Get-WinForgeScanDetections -Since $startedAt

    if ($null -eq $detections) {
        Write-WinForgeStatus -Type Warning -Message "A verificação terminou, mas não foi possível consultar o resultado. Confira em Segurança do Windows."
        return (New-WinForgeResult -Kind Warning -Detail "resultado não consultado" -Data @{ ScanType = $Type })
    }

    if (@($detections).Count -eq 0) {
        # Uma ameaça de antes, ainda sem solução, não aparece como "nova": dizer só "nenhuma ameaça" seria enganoso.
        $leftover = Get-WinForgeActiveThreats

        if ($null -ne $leftover -and @($leftover).Count -gt 0) {
            Write-WinForgeStatus -Type Warning -Message "Verificação concluída: nenhuma ameaça nova, mas o Windows Defender ainda tem $(@($leftover).Count) ameaça(s) ativa(s) de antes: $(@($leftover) -join ', ')."
            Write-Host "      Abra a Segurança do Windows, em Proteção contra vírus e ameaças, para ver as ações." -ForegroundColor DarkGray

            return (New-WinForgeResult -Kind Warning -Detail "$(@($leftover).Count) ameaça(s) ativa(s) de antes" -Data @{ ScanType = $Type; ThreatCount = 0; ActiveThreats = @($leftover).Count })
        }

        Write-WinForgeStatus -Type Success -Message "Verificação concluída: nenhuma ameaça encontrada."
        return (New-WinForgeResult -Kind Ok -Data @{ ScanType = $Type; ThreatCount = 0 })
    }

    Write-WinForgeStatus -Type Warning -Message "Verificação concluída: $(@($detections).Count) ameaça(s) encontrada(s)."

    foreach ($detection in @($detections)) {
        Write-Host "      $($detection.Name)" -ForegroundColor Yellow

        foreach ($resource in @($detection.Resources | Select-Object -First 3)) {
            Write-Host "        $resource" -ForegroundColor DarkGray
        }
    }

    Write-Host ""
    Write-Host "      Veja o que o Windows fez com cada uma no aplicativo Segurança do Windows, em Proteção contra vírus e ameaças." -ForegroundColor DarkGray

    return (New-WinForgeResult -Kind Warning -Detail "$(@($detections).Count) ameaça(s) encontrada(s)" -Data @{ ScanType = $Type; ThreatCount = @($detections).Count })
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
    Exit-WinForgeAction -Embedded:$Embedded

    if ($PassThru) {
        return $result
    }
}


function Start-WinForgeQuickScan {
    param (
        [switch]$Embedded,
        [switch]$PassThru
    )

    Enter-WinForgeAction -Title "Verificação rápida" -Embedded:$Embedded

    $result = $null

    try {
        $result = Invoke-WinForgeDefenderScan -Type Quick
    }
    catch {
        Write-WinForgeStatus -Type Error -Message "Ocorreu um erro na verificação: $($_.Exception.Message)"
        $result = New-WinForgeResult -Kind Failed -Detail $_.Exception.Message
    }

    $result.Etapa = "Verificação rápida"
    Exit-WinForgeAction -Embedded:$Embedded

    if ($PassThru) {
        return $result
    }
}


function Start-WinForgeFullScan {
    param (
        [switch]$Embedded,
        [switch]$PassThru
    )

    Enter-WinForgeAction -Title "Verificação completa" -Embedded:$Embedded

    $result = $null

    try {
        if (-not $Embedded -and -not (Confirm-WinForgeAction "A verificação completa pode levar horas. Deseja começar agora?" -DefaultKey N)) {
            Write-WinForgeStatus -Type Warning -Message "Operação cancelada."
            $result = New-WinForgeResult -Kind Skipped -Detail "cancelado pelo usuário"
        }
        else {
            $result = Invoke-WinForgeDefenderScan -Type Full
        }
    }
    catch {
        Write-WinForgeStatus -Type Error -Message "Ocorreu um erro na verificação: $($_.Exception.Message)"
        $result = New-WinForgeResult -Kind Failed -Detail $_.Exception.Message
    }

    $result.Etapa = "Verificação completa"
    Exit-WinForgeAction -Embedded:$Embedded

    if ($PassThru) {
        return $result
    }
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

    $options += @{ Key = "O"; Label = "Outra pasta ou arquivo"; Description = "Você informa o caminho, por exemplo D:\Fotos ou o arquivo baixado" }
    $options += @{ Key = "C"; Label = "Cancelar"; Exit = $true }

    $choice = Read-WinForgeChoice -Message "O que deseja verificar?" -Options $options -DefaultKey "C" -ShowMenu

    switch ($choice) {
        "D" { return $downloads }
        "A" { return $desktop }
        "O" { return ([string](Read-WinForgeText -Message "Cole o caminho da pasta ou do arquivo (ENTER cancela)")).Trim().Trim('"') }
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
        $path = [string](Select-WinForgeScanTarget)

        if ([string]::IsNullOrWhiteSpace($path)) {
            Write-WinForgeStatus -Type Warning -Message "Operação cancelada."
            $result = New-WinForgeResult -Kind Skipped -Detail "cancelado pelo usuário"
        }
        else {
            $result = Invoke-WinForgeDefenderScan -Type Custom -Path $path
        }
    }
    catch {
        Write-WinForgeStatus -Type Error -Message "Ocorreu um erro na verificação: $($_.Exception.Message)"
        $result = New-WinForgeResult -Kind Failed -Detail $_.Exception.Message
    }

    $result.Etapa = "Verificar uma pasta"
    Exit-WinForgeAction -Embedded:$Embedded

    if ($PassThru) {
        return $result
    }
}


function Invoke-WinForgeSecurityCheck {
    <#
    A etapa de segurança da Manutenção recomendada: atualiza as assinaturas e faz a verificação rápida. O resultado é o
    da verificação; se só a atualização falhou, vira ressalva (a verificação rodou com assinaturas antigas).
    #>
    param (
        [switch]$Embedded,
        [switch]$PassThru
    )

    Enter-WinForgeAction -Title "Verificação de segurança" -Embedded:$Embedded

    $result = $null

    try {
        $ready = Test-WinForgeDefenderReady

        if (-not $ready.Ready) {
            # Nada a verificar: o motivo já está na tela.
            $result = $ready.Result
        }
        else {
            $update = Invoke-WinForgeSignatureUpdate -AssumeReady
            Write-Host ""

            $result = Invoke-WinForgeDefenderScan -Type Quick -AssumeReady

            if ($update.Kind -in @("Failed", "Warning") -and $result.Kind -eq "Ok") {
                $result = New-WinForgeResult -Kind Warning -Detail "nenhuma ameaça, mas as assinaturas não foram atualizadas" -Data $result.Data
            }
        }
    }
    catch {
        Write-WinForgeStatus -Type Error -Message "Ocorreu um erro na verificação de segurança: $($_.Exception.Message)"
        $result = New-WinForgeResult -Kind Failed -Detail $_.Exception.Message
    }

    $result.Etapa = "Verificação de segurança"
    Exit-WinForgeAction -Embedded:$Embedded

    if ($PassThru) {
        return $result
    }
}


Export-ModuleMember -Function *
