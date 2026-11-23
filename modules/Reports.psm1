# Relatórios HTML e texto do estado do PC.


# ---------------------------------------------------------------------------
# Seções
# ---------------------------------------------------------------------------

function Get-WinForgeReportSystemItems {
    $os = Get-WinForgeCimOrNull -ClassName "Win32_OperatingSystem" | Select-Object -First 1

    $system = Get-WinForgeCimOrNull -ClassName "Win32_ComputerSystem" | Select-Object -First 1

    @{ Label = (Get-WinForgeText 'Computador'); Value = $(if ([string]::IsNullOrWhiteSpace($env:COMPUTERNAME)) { [Environment]::MachineName } else { $env:COMPUTERNAME }) }
    @{ Label = (Get-WinForgeText 'Usuário'); Value = $(if ([string]::IsNullOrWhiteSpace($env:USERNAME)) { [Environment]::UserName } else { $env:USERNAME }) }

    # Fabricante e modelo do PC, como em Sobre este PC: é o que um técnico pergunta primeiro (drivers, BIOS, garantia).
    $machine = Get-WinForgeMachineModelText -System $system

    if ($machine) { @{ Label = (Get-WinForgeText 'Fabricante e modelo'); Value = $machine } }

    if ($os) {
        # O mesmo texto do cartão Windows da tela inicial: "Windows 11 Pro 24H2 (build 26100)".
        $build = [int](Get-WinForgeJsonValue -Object $os -Name "BuildNumber" -Default 0)
        $windows = Get-WinForgeWindowsName -Caption ([string](Get-WinForgeJsonValue -Object $os -Name "Caption" -Default "")) -Build $build
        $version = Get-WinForgeWindowsDisplayVersion

        if ($version) { $windows += " $version" }
        if ($build -gt 0) { $windows += (Get-WinForgeText ' (build {0})' "$build") }

        @{ Label = (Get-WinForgeText 'Sistema operacional'); Value = $windows.Trim() }
        @{ Label = (Get-WinForgeText 'Tempo ligado'); Value = (Get-WinForgeUptimeText -LastBootTime $os.LastBootUpTime) }
    }
    else {
        @{ Label = (Get-WinForgeText 'Sistema operacional'); Value = (Get-WinForgeText 'Não foi possível ler') }
    }

    # O veredito da tela Suporte do Windows: num laudo, "este Windows ainda recebe correções?" é a primeira pergunta.
    try {
        $support = Get-WinForgeWindowsSupportStatus
        @{ Label = (Get-WinForgeText 'Suporte do Windows'); Value = $(if ($support.Text) { [string]$support.Text } else { (Get-WinForgeText 'Não foi possível conferir') }) }
    }
    catch {
        @{ Label = (Get-WinForgeText 'Suporte do Windows'); Value = (Get-WinForgeText 'Não foi possível conferir') }
    }

    # A ativação, como em Sobre este PC: é a pergunta seguinte de quem recebe o laudo.
    @{ Label = (Get-WinForgeText 'Ativação do Windows'); Value = (Get-WinForgeWindowsActivationText -State (Get-WinForgeWindowsActivation)) }

    # O mesmo veredito das telas: só os sinais fortes dizem "sim". Os fracos (arquivos esperando substituição) aparecem
    # em muitos PCs sem que o reinício seja necessário, e sozinhos não viram motivo.
    $pending = @(Get-WinForgePendingReboot)
    $strong = @($pending | Where-Object { $_.Strong })
    $rebootText = $(
        if ($strong.Count -gt 0) { ($strong | ForEach-Object { $_.Reason }) -join "; " }
        elseif ($pending.Count -gt 0) { (Get-WinForgeText 'Não (só sinais que aparecem em quase todo PC; reiniciar não é obrigatório)') }
        else { (Get-WinForgeText 'Não') }
    )
    @{ Label = (Get-WinForgeText 'Reinício pendente'); Value = $rebootText }
}


function Get-WinForgeReportHardwareItems {
    $items = @()
    $cpu = Get-WinForgeCimOrNull -ClassName "Win32_Processor" | Select-Object -First 1
    $memory = @(Get-WinForgeCimOrNull -ClassName "Win32_PhysicalMemory")
    $board = Get-WinForgeCimOrNull -ClassName "Win32_BaseBoard" | Select-Object -First 1
    $bios = Get-WinForgeCimOrNull -ClassName "Win32_BIOS" | Select-Object -First 1

    if ($cpu) {
        $items += @{ Label = (Get-WinForgeText 'Processador'); Value = ([string]$cpu.Name).Trim() }
    }

    if ($memory.Count -gt 0) {
        $totalRam = Format-WinForgeBytes -Bytes (($memory | Measure-Object -Property Capacity -Sum).Sum) -ZeroText "?"
        $memoryType = Convert-WinForgeMemoryType -Type ([int]($memory | Select-Object -First 1).SMBIOSMemoryType)
        $modules = Get-WinForgeMemoryModulesText -Modules $memory
        $items += @{ Label = (Get-WinForgeText 'Memória'); Value = "$totalRam $memoryType$(if ($modules) { " ($modules)" })" }
    }

    if ($board) {
        $items += @{ Label = (Get-WinForgeText 'Placa-mãe'); Value = "$($board.Manufacturer) $($board.Product)".Trim() }
    }

    if ($bios) {
        $items += @{ Label = "BIOS"; Value = $bios.SMBIOSBIOSVersion }
    }

    foreach ($gpu in @(Get-WinForgeCimOrNull -ClassName "Win32_VideoController" | Where-Object { -not [string]::IsNullOrWhiteSpace($_.Name) -and $_.Name -notmatch "Microsoft Basic|Remote|Parsec" })) {
        $items += @{ Label = (Get-WinForgeText 'Vídeo'); Value = ([string]$gpu.Name).Trim() }
    }

    if ($items.Count -eq 0) {
        $items += @{ Label = (Get-WinForgeText 'Hardware'); Value = (Get-WinForgeText 'Não foi possível ler') }
    }

    return $items
}


function Get-WinForgeReportDiskItems {
    $items = @()

    # As mesmas frases das telas Discos e espaço livre e Saúde dos discos. Uma leitura vazia vira uma linha que diz isso:
    # sem ela, o relatório parecia de um PC sem disco.
    $summary = @(Get-WinForgeDiskSummary)
    $healthList = @(Get-WinForgeDiskHealth)

    if ($summary.Count -eq 0) { $items += @{ Label = (Get-WinForgeText 'Unidades'); Value = (Get-WinForgeText 'Não foi possível ler') } }

    foreach ($disk in $summary) {
        $items += @{ Label = $disk.Unidade; Value = (Get-WinForgeDiskSummaryText -Disk $disk) }
    }

    if ($healthList.Count -eq 0) { $items += @{ Label = (Get-WinForgeText 'Saúde dos discos'); Value = (Get-WinForgeText 'Não foi possível ler (em alguns PCs, requer Administrador)') } }

    foreach ($health in $healthList) {
        $status = Get-WinForgeDiskHealthStatusText -Status $health.HealthStatus
        if ($status -eq (Get-WinForgeText 'Desconhecido')) { $status = (Get-WinForgeText 'Estado desconhecido') }

        $text = if ($health.Notes.Count -gt 0) { (Get-WinForgeText '{0}. Alertas: {1}' "$status" "$($health.Notes -join '; ')") }
        elseif ($health.CountersAvailable) { (Get-WinForgeText '{0}, sem alertas' "$status") }
        elseif ([bool](Get-WinForgeJsonValue -Object $health -Name "CountersTimedOut" -Default $false)) { (Get-WinForgeText '{0}; os contadores não vieram (o Windows não respondeu a tempo)' "$status") }
        else { (Get-WinForgeText '{0}, sem contadores de confiabilidade' "$status") }
        $drives = @(Get-WinForgeJsonValue -Object $health -Name "Drives" -Default @())
        $items += @{ Label = (Get-WinForgeText 'Saúde: {0}{1}' "$($health.Name)" "$(if ($drives.Count -gt 0) { " ($($drives -join ', '))" })"); Value = $text }
    }

    return $items
}


function Get-WinForgeReportTweakItems {
    $items = @()

    foreach ($tweak in @(Get-WinForgeTweakOverview)) {
        # Como na janela: o recurso do Windows e se ele está ativado ou desativado agora.
        $items += @{ Label = $tweak.Name; Value = (Get-WinForgeTweakSwitchState -Status $tweak.Status -Inverted ([bool]$tweak.Inverted)).Caption }
    }

    return $items
}


function Get-WinForgeReportEventItems {
    $items = @()
    $summary = @(ConvertTo-WinForgeEventSummary -Events @(Get-WinForgeRecentCriticalEvents -Days 7) -Top 10)

    if ($summary.Count -eq 0) {
        $items += @{ Label = (Get-WinForgeText 'Últimos 7 dias'); Value = (Get-WinForgeText 'Nenhum evento crítico ou de erro') }
    }

    foreach ($entry in $summary) {
        $value = Format-WinForgeEventOccurrences -Entry $entry
        if ($entry.Hint) { $value += " - $($entry.Hint)" }
        $items += @{ Label = (Get-WinForgeText '{0} (ID {1})' "$(Get-WinForgeEventProviderText -Provider $entry.Provider)" "$($entry.Id)"); Value = $value }
    }

    return $items
}


function Get-WinForgeReportStabilityItems {
    # As telas azuis dos últimos 90 dias e o último teste de memória, como em Diagnóstico > Telas azuis e Teste de memória.
    $items = @()
    $label = (Get-WinForgeText 'Telas azuis (90 dias)')

    try {
        $screens = @(Get-WinForgeBlueScreens -Days 90)

        if ($screens.Count -eq 0) {
            $items += @{ Label = $label; Value = (Get-WinForgeText 'Nenhuma') }
        }
        else {
            $about = Get-WinForgeBugCheckCauseText -Cause (Get-WinForgeBlueScreenMainCause -Screens $screens).Cause
            $latest = $screens[0]
            $code = "0x{0:X8}" -f [uint32]$latest.Code
            $count = Format-WinForgeCount -Count $screens.Count -One (Get-WinForgeText 'tela azul') -Many (Get-WinForgeText 'telas azuis')

            $items += @{ Label = $label; Value = (Get-WinForgeText '{0}; causa mais provável: {1}' "$count" "$($about.Cause)") }
            $items += @{ Label = (Get-WinForgeText 'A mais recente'); Value = (Get-WinForgeText '{0} ({1})' "$(Format-WinForgeDateTime -When $latest.When)" "$(if ($latest.Info.Name) { "$code $($latest.Info.Name)" } else { $code })") }
        }
    }
    catch {
        $items += @{ Label = $label; Value = (Get-WinForgeText 'Não foi possível ler') }
    }

    try {
        $memory = Get-WinForgeMemoryTestResult
        $value = $(if ($null -eq $memory) { (Get-WinForgeText 'nenhum no último ano') }
            elseif ($memory.Errors) { (Get-WinForgeText '{0}: {1}' "$(Format-WinForgeDateTime -When $memory.When)" "$(Get-WinForgeText 'encontrou erros na memória')") }
            else { (Get-WinForgeText '{0}: {1}' "$(Format-WinForgeDateTime -When $memory.When)" "$(Get-WinForgeText 'nenhum erro')") })

        $items += @{ Label = (Get-WinForgeText 'Último teste de memória'); Value = $value }
    }
    catch {
        Write-Verbose "Teste de memória: $($_.Exception.Message)"
    }

    return $items
}


function Get-WinForgeReportBatteryItems {
    $items = @()
    $info = Get-WinForgeBatteryInfo

    if (-not $info.Present) {
        return @(@{ Label = (Get-WinForgeText 'Bateria'); Value = (Get-WinForgeText 'Nenhuma bateria encontrada') })
    }

    $now = @()
    if ($null -ne $info.State.ChargePercent) { $now += "$($info.State.ChargePercent)%" }
    if ($info.State.State) { $now += $info.State.State }
    if ($now.Count -gt 0) { $items += @{ Label = (Get-WinForgeText 'Agora'); Value = ($now -join ", ") } }

    foreach ($reading in @($info.Readings)) {
        $label = $(if ($reading.Name) { $reading.Name } else { (Get-WinForgeText 'Bateria') })
        $assessment = Get-WinForgeBatteryAssessment -HealthPercent $reading.HealthPercent -Missing $(if ($null -ne $reading.DesignMwh -and $null -eq $reading.FullMwh) { "full" } else { "design" })

        $capacity = @()
        if ($null -ne $reading.FullMwh -and $null -ne $reading.DesignMwh -and -not [bool](Get-WinForgeJsonValue -Object $reading -Name "Relative" -Default $false)) {
            $capacity += (Get-WinForgeText '{0} de {1} de fábrica' "$(Format-WinForgeWattHours -MilliwattHours $reading.FullMwh)" "$(Format-WinForgeWattHours -MilliwattHours $reading.DesignMwh)")
        }
        if ($null -ne $reading.Cycles) { $capacity += (Format-WinForgeCount -Count ([int]$reading.Cycles) -One (Get-WinForgeText 'ciclo') -Many (Get-WinForgeText 'ciclos')) }

        $parts = @($assessment.Text) + @($capacity)
        $items += @{ Label = $label; Value = ($parts -join " | ") }
    }

    if (@($info.Readings).Count -eq 0) {
        $items += @{ Label = (Get-WinForgeText 'Capacidade'); Value = (Get-WinForgeText 'O Windows não informou a capacidade da bateria') }
    }

    return $items
}


function Get-WinForgeReportSecurityItems {
    # Sem a consulta ao Windows Update (a tela a faz à parte): ela vai até o serviço e deixaria o relatório lento.
    $status = Get-WinForgeSecurityStatus
    $antivirus = $status.Antivirus
    $items = @()

    # As mesmas linhas da tela Estado da proteção (sem a última verificação completa); "Situação" vira "Antivírus".
    foreach ($row in @(Get-WinForgeAntivirusRows -Antivirus $antivirus -Threats $status.Threats -Brief)) {
        $items += @{ Label = $(if ($row.Label -eq (Get-WinForgeText 'Situação')) { (Get-WinForgeText 'Antivírus') } else { $row.Label }); Value = $row.Value }
    }

    if ($null -eq $status.Firewall) {
        $items += @{ Label = (Get-WinForgeText 'Firewall'); Value = (Get-WinForgeText 'Não foi possível ler') }
    }
    else {
        $items += @{ Label = (Get-WinForgeText 'Firewall'); Value = ((@($status.Firewall) | ForEach-Object { $product = [string](Get-WinForgeJsonValue -Object $_ -Name "Product" -Default ""); "$(Get-WinForgeFirewallProfileName -Name $_.Name): $(if ($product) { (Get-WinForgeText 'protegido por {0}' "$product") } elseif ($_.Enabled) { (Get-WinForgeText 'ligado') } elseif (-not [bool](Get-WinForgeJsonValue -Object $_ -Name 'Applies' -Default $true)) { (Get-WinForgeText 'desligado (não vale para este PC, que não está num domínio)') } else { (Get-WinForgeText 'desligado') })" }) -join "; ") }
    }

    foreach ($finding in @($status.Findings | Where-Object { $_.Level -eq "Warning" })) {
        $items += @{ Label = (Get-WinForgeText 'Atenção'); Value = $finding.Text }
    }

    return $items
}


function Get-WinForgeReportMaintenanceItems {
    param (
        [Parameter(Mandatory)]
        $Maintenance
    )

    $items = @()

    foreach ($result in @($Maintenance.Results)) {
        $value = [string]$result.Status
        if ($result.PSObject.Properties.Name -contains "Duracao" -and $result.Duracao) { $value += " ($($result.Duracao))" }
        $items += @{ Label = $result.Etapa; Value = $value }
    }

    # Antes e depois (manutenções gravadas por versões antigas não têm as fotos).
    $before = $(if ($null -ne $Maintenance.PSObject.Properties["Before"]) { $Maintenance.Before } else { $null })
    $after = $(if ($null -ne $Maintenance.PSObject.Properties["After"]) { $Maintenance.After } else { $null })

    foreach ($row in @(Get-WinForgeSnapshotComparison -Before $before -After $after)) {
        $items += @{ Label = $row.Label; Value = $row.Text }
    }

    if ($null -ne $after -and $null -ne $Maintenance.PSObject.Properties["StartedAt"]) {
        $span = $after.At - $Maintenance.StartedAt

        if ($span.Ticks -gt 0) {
            $items += @{ Label = (Get-WinForgeText 'Duração'); Value = (Get-WinForgeText '{0} (das {1} às {2})' "$(Format-WinForgeDuration -Span $span)" "$(Format-WinForgeDateTime -When $Maintenance.StartedAt -Pattern 'HH:mm')" "$(Format-WinForgeDateTime -When $after.At -Pattern 'HH:mm')") }
        }
    }

    return $items
}


function New-WinForgeReportSection {
    # Uma seção que falha vira uma linha de aviso: o resto do relatório continua sendo gerado e salvo.
    param (
        [Parameter(Mandatory)]
        [string]$Title,

        [Parameter(Mandatory)]
        [scriptblock]$Build
    )

    try {
        $items = @(& $Build)
    }
    catch {
        $items = @(@{ Label = (Get-WinForgeText 'Não foi possível ler esta seção'); Value = $_.Exception.Message })
    }

    return @{ Title = $Title; Items = $items }
}


function Get-WinForgeReportAttentionItems {
    # O resumo do que pede atenção, no topo do relatório: a nota de saúde do Início e os pontos que descontam dela, para
    # quem vai ajudar ver o problema antes de ler as seções técnicas.
    $status = Get-WinForgeHomeStatus
    $health = $status.Health
    $items = @()

    if (Test-WinForgeHealthKnown -Health $health) {
        $items += @{ Label = (Get-WinForgeText 'Saúde do PC'); Value = (Get-WinForgeText '{0} de 100 ({1})' "$($health.Score)" "$($health.Label)") }
    }
    else {
        $items += @{ Label = (Get-WinForgeText 'Saúde do PC'); Value = (Get-WinForgeText 'Não foi possível avaliar') }
    }

    $issues = @($health.Issues | Where-Object { $null -ne $_ })

    foreach ($issue in $issues) {
        $items += @{ Label = $(if ($issue.Severe) { (Get-WinForgeText 'Grave') } else { (Get-WinForgeText 'Atenção') }); Value = [string]$issue.Text }
    }

    if ($issues.Count -eq 0) {
        $items += @{ Label = (Get-WinForgeText 'Pontos de atenção'); Value = (Get-WinForgeText 'Nenhum') }
    }

    $unread = @(Get-WinForgeJsonValue -Object $health -Name "Unread" -Default @())

    if ($unread.Count -gt 0) {
        $items += @{ Label = (Get-WinForgeText 'Não foi possível ler'); Value = ($unread -join ", ") }
    }

    foreach ($notice in @($status.Notices | Where-Object { $null -ne $_ })) {
        $items += @{ Label = (Get-WinForgeText 'Aviso'); Value = [string]$notice.Text }
    }

    return $items
}


function Get-WinForgeReportSections {
    $sections = @()

    $sections += New-WinForgeReportSection -Title (Get-WinForgeText 'Pontos de atenção') -Build { Get-WinForgeReportAttentionItems }
    $sections += New-WinForgeReportSection -Title (Get-WinForgeText 'Sistema') -Build { Get-WinForgeReportSystemItems }
    $sections += New-WinForgeReportSection -Title (Get-WinForgeText 'Hardware') -Build { Get-WinForgeReportHardwareItems }
    $sections += New-WinForgeReportSection -Title (Get-WinForgeText 'Discos') -Build { Get-WinForgeReportDiskItems }
    $sections += New-WinForgeReportSection -Title (Get-WinForgeText 'Ajustes do Windows e Personalização') -Build { Get-WinForgeReportTweakItems }
    $sections += New-WinForgeReportSection -Title (Get-WinForgeText 'Eventos críticos (7 dias)') -Build { Get-WinForgeReportEventItems }
    $sections += New-WinForgeReportSection -Title (Get-WinForgeText 'Telas azuis e memória') -Build { Get-WinForgeReportStabilityItems }

    $sections += New-WinForgeReportSection -Title (Get-WinForgeText 'Segurança') -Build { Get-WinForgeReportSecurityItems }

    if (Test-WinForgeLaptop) {
        $sections += New-WinForgeReportSection -Title (Get-WinForgeText 'Bateria') -Build { Get-WinForgeReportBatteryItems }
    }

    $maintenance = Get-WinForgeLastMaintenance

    if ($null -ne $maintenance) {
        $title = (Get-WinForgeText 'Última manutenção')

        try { $title += " ($(Format-WinForgeDateTime -When $maintenance.StartedAt))" } catch { }

        $sections += New-WinForgeReportSection -Title $title -Build { Get-WinForgeReportMaintenanceItems -Maintenance $maintenance }
    }

    return @($sections)
}


# ---------------------------------------------------------------------------
# Formatos
# ---------------------------------------------------------------------------

function ConvertTo-WinForgeTextReport {
    param (
        [Parameter(Mandatory)]
        [object[]]$Sections,

        [string]$Build = ""
    )

    $builder = New-Object System.Text.StringBuilder
    [void]$builder.AppendLine((Get-WinForgeText 'WinForge - Relatório (versão {0})' "$Build"))
    [void]$builder.AppendLine((Get-WinForgeText 'Gerado em {0}' "$(Format-WinForgeDateTime -When (Get-Date))"))

    foreach ($section in $Sections) {
        [void]$builder.AppendLine("")
        [void]$builder.AppendLine($section.Title)
        [void]$builder.AppendLine(("-" * $section.Title.Length))

        foreach ($item in $section.Items) {
            [void]$builder.AppendLine(("{0,-34} {1}" -f $item.Label, $item.Value))
        }
    }

    return $builder.ToString()
}


function ConvertTo-WinForgeHtmlReport {
    param (
        [Parameter(Mandatory)]
        [object[]]$Sections,

        [string]$Build = ""
    )

    $encode = { param($text) [System.Net.WebUtility]::HtmlEncode([string]$text) }
    $builder = New-Object System.Text.StringBuilder

    # O idioma da página é o da interface (o leitor de tela e o tradutor do navegador usam o atributo lang).
    $htmlLanguage = switch (Get-WinForgeLanguage) { "en" { "en" } "es" { "es" } default { "pt-BR" } }
    [void]$builder.AppendLine("<!doctype html><html lang=`"$htmlLanguage`"><head><meta charset=`"utf-8`">")
    [void]$builder.AppendLine("<meta name=`"viewport`" content=`"width=device-width, initial-scale=1`">")
    [void]$builder.AppendLine("<title>$(& $encode (Get-WinForgeText 'WinForge - Relatório'))</title><style>")
    [void]$builder.AppendLine(":root{--bg:#f6f8fa;--card:#fff;--text:#1f2328;--muted:#656d76;--line:#d8dee4;--accent:#0969da}")
    [void]$builder.AppendLine("@media (prefers-color-scheme:dark){:root{--bg:#0d1117;--card:#161b22;--text:#e6edf3;--muted:#8b949e;--line:#30363d;--accent:#58a6ff}}")
    [void]$builder.AppendLine("body{margin:0;background:var(--bg);color:var(--text);font:15px/1.5 Segoe UI,system-ui,sans-serif}")
    [void]$builder.AppendLine("main{max-width:860px;margin:0 auto;padding:24px 16px}h1{margin:0 0 4px;font-size:24px}")
    [void]$builder.AppendLine(".meta{color:var(--muted);margin-bottom:20px}section{background:var(--card);border:1px solid var(--line);border-radius:10px;padding:14px 18px;margin-bottom:14px}")
    [void]$builder.AppendLine("h2{margin:0 0 8px;font-size:16px;color:var(--accent)}dl{display:grid;grid-template-columns:minmax(140px,30%) 1fr;gap:4px 14px;margin:0}")
    [void]$builder.AppendLine("dt{color:var(--muted)}dd{margin:0;overflow-wrap:anywhere}@media (max-width:560px){dl{grid-template-columns:1fr}}")
    [void]$builder.AppendLine("</style></head><body><main>")
    [void]$builder.AppendLine("<h1>WinForge</h1><div class=`"meta`">$(& $encode (Get-WinForgeText 'Relatório gerado em {0} · versão {1}' "$(Format-WinForgeDateTime -When (Get-Date))" "$Build"))</div>")

    foreach ($section in $Sections) {
        [void]$builder.AppendLine("<section><h2>$(& $encode $section.Title)</h2><dl>")

        foreach ($item in $section.Items) {
            [void]$builder.AppendLine("<dt>$(& $encode $item.Label)</dt><dd>$(& $encode $item.Value)</dd>")
        }

        [void]$builder.AppendLine("</dl></section>")
    }

    [void]$builder.AppendLine("</main></body></html>")
    return $builder.ToString()
}


# ---------------------------------------------------------------------------
# Ações
# ---------------------------------------------------------------------------

function Export-WinForgeReport {
    param (
        [string]$Directory
    )

    if ([string]::IsNullOrWhiteSpace($Directory)) {
        $Directory = Join-Path (Get-WinForgeDataPath) "reports"
    }

    # Um erro de disco aqui (pasta que não pode ser criada, sem permissão, disco cheio) interrompe a exportação: sem o
    # -ErrorAction Stop o Set-Content só escreveria o erro e quem chama diria "relatório salvo" sobre arquivos que não existem.
    if (-not (Test-Path -LiteralPath $Directory -PathType Container)) {
        try {
            [void](New-Item -Path $Directory -ItemType Directory -Force -ErrorAction Stop)
        }
        catch {
            throw (Get-WinForgeText 'não foi possível criar a pasta dos relatórios ({0}): {1}' "$Directory" "$($_.Exception.Message.TrimEnd('.'))")
        }
    }

    $sections = @(Get-WinForgeReportSections)
    $build = Get-WinForgeBuild

    # O nome vem do horário de quando a coleta terminou; dois relatórios no mesmo segundo (o segundo clique enquanto o
    # primeiro salvava, ou o agendamento) ganham "-2", "-3": sem isso, um apagaria o outro.
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $base = "winforge-relatorio-$stamp"
    $suffix = 1

    while ((Test-Path -LiteralPath (Join-Path $Directory "$base.html")) -or (Test-Path -LiteralPath (Join-Path $Directory "$base.txt"))) {
        $suffix++
        $base = "winforge-relatorio-$stamp-$suffix"
    }

    $htmlPath = Join-Path $Directory "$base.html"
    $textPath = Join-Path $Directory "$base.txt"

    try {
        Set-Content -LiteralPath $htmlPath -Value (ConvertTo-WinForgeHtmlReport -Sections $sections -Build $build) -Encoding UTF8 -ErrorAction Stop
    }
    catch {
        throw (Get-WinForgeText 'não foi possível gravar o relatório em {0}: {1}' "${Directory}" "$($_.Exception.Message.TrimEnd('.'))")
    }

    # O HTML é o relatório; o texto é a cópia para colar num e-mail. Se só ele falhar, o HTML salvo continua valendo.
    $textProblem = ""

    try {
        Set-Content -LiteralPath $textPath -Value (ConvertTo-WinForgeTextReport -Sections $sections -Build $build) -Encoding UTF8 -ErrorAction Stop
    }
    catch {
        $textProblem = $_.Exception.Message.TrimEnd(".")
        $textPath = $null
    }

    return [PSCustomObject]@{ Html = $htmlPath; Text = $textPath; TextProblem = $textProblem }
}


function Open-WinForgeSavedReport {
    <#
    Pergunta o que fazer com um relatório que acabou de ser salvo (abrir, mostrar na pasta ou nada) e faz. Devolve "" ou,
    quando o Windows recusou, o que não foi possível com o motivo ("abrir o relatório: ..."); a mensagem já apareceu.
    #>
    param ([Parameter(Mandatory)][string]$Path)

    $next = Read-WinForgeChoice -Message (Get-WinForgeText 'O que deseja fazer com o relatório?') -DefaultKey "A" -ShowMenu -TextPrompt (Get-WinForgeText 'Opção (ENTER = abrir)') -Options @(
        @{ Key = "A"; Label = (Get-WinForgeText 'Abrir o relatório'); Accent = $true },
        @{ Key = "P"; Label = (Get-WinForgeText 'Mostrar na pasta') },
        @{ Key = "X"; Label = (Get-WinForgeText 'Agora não'); Exit = $true }
    )

    if ($next -notin @("A", "P")) { return "" }

    try {
        # Pelo Explorer, e não direto: com o WinForge como Administrador, o navegador abriria elevado também. O
        # Explorer já está aberto na sessão da pessoa e abre o arquivo no navegador padrão, sem privilégios.
        $arguments = $(if ($next -eq "P") { "/select,`"$Path`"" } else { "`"$Path`"" })
        Start-Process -FilePath "explorer.exe" -ArgumentList $arguments -ErrorAction Stop
    }
    catch {
        $what = $(if ($next -eq "P") { (Get-WinForgeText 'mostrar a pasta') } else { (Get-WinForgeText 'abrir o relatório') })
        Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'Não foi possível {0}: {1}' "${what}" "$($_.Exception.Message)")
        return "${what}: $($_.Exception.Message)"
    }

    return ""
}


function Invoke-WinForgeReport {
    $title = (Get-WinForgeText 'Exportar relatório')
    Enter-WinForgeAction -Title $title

    $result = $null

    try {
        # O andamento vai na barra: uma linha "Coletando..." ficaria no resumo depois do fim.
        Write-Progress -Activity $title -Status (Get-WinForgeText 'coletando sistema, discos, eventos e segurança')

        try {
            $report = Export-WinForgeReport
        }
        finally {
            Write-Progress -Activity $title -Completed
        }

        $textProblem = [string](Get-WinForgeJsonValue -Object $report -Name "TextProblem" -Default "")

        Write-Host ""

        if ($textProblem) {
            Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'Relatório HTML salvo; a cópia em texto não pôde ser gravada: {0}.' "${textProblem}")
            Write-WinForgeKeyValue -Label "HTML" -Value $report.Html
            $result = New-WinForgeResult -Kind Warning -Detail (Get-WinForgeText 'relatório salvo em HTML; a cópia em texto não pôde ser gravada')
        }
        else {
            Write-WinForgeStatus -Type Success -Message (Get-WinForgeText 'Relatório salvo.')
            Write-WinForgeKeyValue -Label "HTML" -Value $report.Html
            Write-WinForgeKeyValue -Label (Get-WinForgeText 'Texto') -Value $report.Text
            $result = New-WinForgeResult -Kind Ok -Detail (Get-WinForgeText 'relatório salvo em HTML e em texto')
        }

        Write-Host ""
        Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'O relatório traz o nome do PC e do usuário, o hardware e a segurança: confira antes de enviar a alguém.')

        $problem = Open-WinForgeSavedReport -Path $report.Html

        if ($problem) {
            $result = New-WinForgeResult -Kind Warning -Detail (Get-WinForgeText 'relatório salvo, mas não foi possível {0}' "$problem")
        }
    }
    catch {
        Write-Host ""
        Write-WinForgeStatus -Type Error -Message (Get-WinForgeText 'O relatório não foi salvo: {0}.' "$($_.Exception.Message.TrimEnd('.'))")
        $result = New-WinForgeResult -Kind Failed -Detail (Get-WinForgeText 'o relatório não foi salvo')
    }

    Exit-WinForgeAction -Result $result
}


# ---------------------------------------------------------------------------
# Verificação rápida (WinForge.Console.ps1 -Action Check)
# ---------------------------------------------------------------------------

function Get-WinForgeCheckLevel {
    <#
    O resultado único da verificação rápida. Critical: nota de saúde abaixo de 50, algum ponto de saúde de peso 25 ou
    mais (disco quase cheio, nenhum antivírus, ameaça ativa) ou um ponto grave da auditoria (Critical + Bad). Attention:
    qualquer outro ponto de saúde ou algum ponto da auditoria com risco real (Bad). Os pontos "Atenção" (Warn) da
    auditoria aparecem no relatório, mas não mudam o resultado: um PC com Área de Trabalho Remota ligada de propósito
    não deveria ficar sempre em Attention.
    #>
    param (
        $Health = $null,

        [object[]]$Attention = @()
    )

    $issues = @()
    $score = 100

    if ($null -ne $Health) {
        $issues = @($Health.Issues | Where-Object { $null -ne $_ })
        $score = [int]$Health.Score
    }

    $items = @($Attention | Where-Object { $null -ne $_ })

    if ($score -lt 50 -or @($issues | Where-Object { [int]$_.Weight -ge 25 }).Count -gt 0 -or @($items | Where-Object { $_.Status -eq "Bad" -and $_.Critical }).Count -gt 0) {
        return "Critical"
    }

    if ($issues.Count -gt 0 -or @($items | Where-Object { $_.Status -eq "Bad" }).Count -gt 0) {
        return "Attention"
    }

    return "Ok"
}


function Get-WinForgeCheckExitCode {
    # 0 = tudo em dia, 1 = há pontos de atenção, 2 = há algo crítico, 3 = não foi possível avaliar.
    param (
        [Parameter(Mandatory)]
        [ValidateSet("Ok", "Attention", "Critical", "Unknown")]
        [string]$Status
    )

    switch ($Status) {
        "Ok"        { return 0 }
        "Attention" { return 1 }
        "Critical"  { return 2 }
        default     { return 3 }
    }
}


function Get-WinForgeCheckReport {
    <#
    Uma leitura rápida e só de leitura do PC: a nota de saúde da tela inicial e a nota da auditoria de segurança, sem
    a consulta ao Windows Update (que leva até um minuto). Nunca lança erro: se a leitura inteira falhar, devolve
    Status Unknown e ExitCode 3 com o motivo em Error.
    #>
    $notes = @()

    try {
        $status = Get-WinForgeHomeStatus
        $health = $status.Health

        $facts = @()

        foreach ($fact in @($status.Facts | Where-Object { $_.Visible })) {
            $facts += [PSCustomObject]@{ Id = $fact.Id; Label = $fact.Label; Text = $fact.Text; Level = $fact.Level }
        }

        $issues = @()

        foreach ($issue in @($health.Issues)) {
            $issues += [PSCustomObject]@{ Id = $issue.Id; Text = $issue.Text; Weight = [int]$issue.Weight }
        }

        # O que entraria na nota de saúde, mas não pôde ser lido: a nota vale para o resto (como diz o Início).
        $unread = @(Get-WinForgeJsonValue -Object $health -Name "Unread" -Default @())

        if ($unread.Count -gt 0) {
            $notes += (Get-WinForgeText 'A nota de saúde não inclui o que não pôde ser lido: {0}.' "$($unread -join ', ')")
        }

        $security = $null
        $attention = @()

        try {
            $auditChecks = @(Get-WinForgeSecurityAuditChecks -Facts (Get-WinForgeSecurityAuditFacts))
            $grade = Get-WinForgeSecurityGrade -Checks $auditChecks

            foreach ($check in @($auditChecks | Where-Object { $_.Weight -gt 0 -and $_.Status -in "Warn", "Bad" })) {
                $attention += [PSCustomObject]@{
                    Id       = $check.Id
                    Title    = $check.Title
                    Status   = $check.Status
                    Critical = [bool]$check.Critical
                    Detail   = $check.Detail
                    Advice   = $check.Advice
                }
            }

            $security = [PSCustomObject]@{
                Grade         = $grade.Grade
                Score         = $grade.Score
                NoGradeReason = [string](Get-WinForgeJsonValue -Object $grade -Name "NoGradeReason" -Default "")
                Capped        = [bool]$grade.Capped
                Unverified    = @($auditChecks | Where-Object { $_.Weight -gt 0 -and $_.Status -eq "Unknown" }).Count
                Attention     = $attention
            }

            $notes += (Get-WinForgeText 'A consulta ao Windows Update foi pulada para a verificação ser rápida; rode Segurança > Auditoria de segurança para incluí-la.')
        }
        catch {
            $notes += (Get-WinForgeText 'Não foi possível fazer a auditoria de segurança: {0}' "$($_.Exception.Message)")
        }

        if (-not (Test-WinForgeAdministrator)) {
            $notes += (Get-WinForgeText 'Sem Administrador: pontos como a criptografia do disco não são verificados.')
        }

        $level = Get-WinForgeCheckLevel -Health $health -Attention $attention
        $problem = ""

        # Nada do que forma a nota foi lido: a nota 100 não quer dizer "tudo em dia". Sem nada grave vindo da auditoria, o
        # resultado é "não foi possível avaliar".
        if ($level -eq "Ok" -and -not (Test-WinForgeHealthKnown -Health $health)) {
            $level = "Unknown"
            $problem = (Get-WinForgeText 'nenhuma leitura da nota de saúde respondeu ({0})' "$($unread -join ', ')")
        }
        elseif ($level -eq "Ok" -and $unread.Count -gt 0) {
            # Parte da nota sem leitura (a nota já diz qual): "em dia" (código 0) prometeria o que não foi conferido.
            $level = "Attention"
        }
        elseif ($level -eq "Ok" -and $null -ne $security -and $security.NoGradeReason -eq "Antivirus") {
            # O antivírus não pôde ser verificado: a auditoria fica sem nota, e "em dia" também prometeria demais.
            $level = "Attention"
        }

        # As telas azuis dos últimos 30 dias (Diagnóstico > Telas azuis): informam, sem mudar o Status nem o ExitCode.
        $stability = $null

        try {
            $screens = @(Get-WinForgeBlueScreens -Days 30)
            $latest = $(if ($screens.Count -gt 0) {
                    [PSCustomObject]@{ At = $screens[0].When.ToString("o"); Code = ("0x{0:X8}" -f [uint32]$screens[0].Code); Name = [string]$screens[0].Info.Name; Cause = [string]$screens[0].Info.Cause }
                })
            $stability = [PSCustomObject]@{ Days = 30; BlueScreens = $screens.Count; Latest = $latest }
        }
        catch {
            Write-Verbose "Telas azuis: $($_.Exception.Message)"
        }

        return [PSCustomObject]@{
            Format        = "WinForge.Check"
            Version       = 2
            Build         = [string](Get-WinForgeBuild)
            CheckedAt     = (Get-Date).ToString("o")
            Administrator = [bool](Test-WinForgeAdministrator)
            Status        = $level
            ExitCode      = (Get-WinForgeCheckExitCode -Status $level)
            Health        = [PSCustomObject]@{ Score = [int]$health.Score; Label = $health.Label; Level = $health.Level; Issues = $issues; Unread = @($unread) }
            Security      = $security
            Stability     = $stability
            Facts         = $facts
            Notes         = $notes
            Error         = $problem
        }
    }
    catch {
        return [PSCustomObject]@{
            Format        = "WinForge.Check"
            Version       = 2
            Build         = [string](Get-WinForgeBuild)
            CheckedAt     = (Get-Date).ToString("o")
            Administrator = $false
            Status        = "Unknown"
            ExitCode      = (Get-WinForgeCheckExitCode -Status "Unknown")
            Health        = $null
            Security      = $null
            Stability     = $null
            Facts         = @()
            Notes         = @()
            Error         = $_.Exception.Message
        }
    }
}


function ConvertTo-WinForgeCheckJson {
    param (
        [Parameter(Mandatory)]
        $Report
    )

    return ($Report | ConvertTo-Json -Depth 6)
}


function Show-WinForgeCheckReport {
    param (
        [Parameter(Mandatory)]
        $Report
    )

    Write-WinForgeSection -Title (Get-WinForgeText 'Verificação rápida do WinForge (versão {0})' "$($Report.Build)")

    if ($Report.Status -eq "Unknown") {
        Write-WinForgeStatus -Type Error -Message (Get-WinForgeText 'Não foi possível avaliar o PC: {0}' "$($Report.Error)")
        Write-WinForgeKeyValue -Label (Get-WinForgeText 'Código de saída') -Value ([string]$Report.ExitCode)
        return
    }

    Write-WinForgeKeyValue -Label (Get-WinForgeText 'Saúde do PC') -Value (Get-WinForgeText '{0} de 100 ({1})' "$($Report.Health.Score)" "$($Report.Health.Label)")

    foreach ($issue in @($Report.Health.Issues)) {
        Write-WinForgeStatus -Type $(if ($issue.Weight -ge 25) { "Error" } else { "Warning" }) -Message $issue.Text
    }

    if (@($Report.Health.Issues).Count -eq 0) {
        $unread = @(Get-WinForgeJsonValue -Object $Report.Health -Name "Unread" -Default @())
        Write-WinForgeStatus -Type Success -Message $(if ($unread.Count -gt 0) { (Get-WinForgeText 'Nenhum ponto de atenção no que foi lido.') } else { (Get-WinForgeText 'Nenhum ponto de atenção na saúde do PC.') })
    }

    if ($null -ne $Report.Security) {
        if ($null -eq $Report.Security.Score) {
            $reason = [string](Get-WinForgeJsonValue -Object $Report.Security -Name "NoGradeReason" -Default "")
            $why = switch ($reason) {
                "Antivirus" { (Get-WinForgeText 'sem nota: o antivírus não pôde ser verificado') }
                "Coverage" { (Get-WinForgeText 'sem nota: menos da metade dos pontos pôde ser verificada') }
                default { (Get-WinForgeText 'sem nota: não foi possível calcular') }
            }

            Write-WinForgeKeyValue -Label (Get-WinForgeText 'Segurança') -Value $why -Level Warn
        }
        else {
            Write-WinForgeKeyValue -Label (Get-WinForgeText 'Segurança') -Value (Get-WinForgeText '{0} de 100 · {1}' "$($Report.Security.Score)" "$($Report.Security.Grade)")
        }

        foreach ($item in @($Report.Security.Attention)) {
            Write-WinForgeStatus -Type $(if ($item.Status -eq "Bad") { "Error" } else { "Warning" }) -Message "$($item.Title): $($item.Detail)"
        }
    }

    foreach ($note in @($Report.Notes)) {
        Write-Host "  $note" -ForegroundColor DarkGray
    }

    $text = switch ($Report.Status) {
        "Ok"        { (Get-WinForgeText 'Tudo em dia') }
        "Attention" { (Get-WinForgeText 'Há pontos de atenção') }
        default     { (Get-WinForgeText 'Há algo crítico') }
    }

    Write-WinForgeKeyValue -Label (Get-WinForgeText 'Resultado') -Value (Get-WinForgeText '{0} (código de saída {1})' "$text" "$($Report.ExitCode)")
}


# ---------------------------------------------------------------------------
# Pacote de suporte (Sobre o WinForge > Pacote de suporte)
# ---------------------------------------------------------------------------

function Copy-WinForgeSharedFile {
    # Copia um arquivo que outro processo pode estar gravando (o log da janela aberta): lê com o compartilhamento total.
    param ([Parameter(Mandatory)][string]$From, [Parameter(Mandatory)][string]$To)

    $folder = Split-Path -Parent $To
    if (-not (Test-Path -LiteralPath $folder)) { [void](New-Item -ItemType Directory -Path $folder -Force -ErrorAction Stop) }

    $source = New-Object System.IO.FileStream ($From, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, ([System.IO.FileShare]::ReadWrite -bor [System.IO.FileShare]::Delete))

    try {
        $target = [System.IO.File]::Create($To)
        try { $source.CopyTo($target) } finally { $target.Dispose() }
    }
    finally {
        $source.Dispose()
    }
}


function Get-WinForgeSupportInfoText {
    # As versões, em texto, para quem vai ajudar: WinForge, Windows, PowerShell, .NET, idioma e se abriu como Administrador.
    $culture = [System.Globalization.CultureInfo]::InvariantCulture
    $lines = New-Object System.Collections.Generic.List[string]
    $windows = ""
    $netRelease = ""

    try {
        $current = Get-ItemProperty -LiteralPath "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -ErrorAction Stop
        $windows = "$(Get-WinForgeWindowsName -Caption ([string](Get-WinForgeJsonValue -Object $current -Name 'ProductName' -Default '')) -Build (Get-WinForgeWindowsBuild)) $(Get-WinForgeWindowsDisplayVersion) (build $(Get-WinForgeWindowsBuild).$([string](Get-WinForgeJsonValue -Object $current -Name 'UBR' -Default '')))"
    }
    catch {
        $windows = "?"
    }

    try { $netRelease = [string](Get-WinForgeRegistryValueOrNull -Path "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full" -Name "Release") } catch { $netRelease = "" }

    $installed = $(try { if (Test-WinForgeInstalledHere) { "yes" } else { "no" } } catch { "?" })

    # Em inglês e sem tradução: é para quem dá suporte, e o arquivo é o mesmo em qualquer idioma da tela.
    $lines.Add("WinForge Build $(Get-WinForgeBuild)")
    $lines.Add("Created: $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss', $culture))")
    $lines.Add("Folder: $(Get-WinForgeAppRoot)")
    $lines.Add("Installed (Apps): $installed")
    $lines.Add("Language: $(Get-WinForgeLanguage) (preference $(Get-WinForgeLanguagePreference); Windows $([System.Globalization.CultureInfo]::CurrentUICulture.Name))")
    $lines.Add("Windows: $windows")
    $lines.Add("64-bit Windows: $([Environment]::Is64BitOperatingSystem); 64-bit process: $([Environment]::Is64BitProcess)")
    $lines.Add("PowerShell: $($PSVersionTable.PSVersion) ($($PSVersionTable.PSEdition))")
    $lines.Add(".NET Framework release: $netRelease")
    $lines.Add("Administrator: $(Test-WinForgeAdministrator)")
    $lines.Add("Window: $(Test-WinForgeGuiMode)")

    return ($lines -join "`r`n")
}


function New-WinForgeSupportPackage {
    <#
    Junta num zip, na pasta Downloads, o que ajuda alguém a entender um problema do WinForge: as versões (info.txt), os
    logs mais recentes e o tempo de abertura, a verificação rápida do PC (check.json), o último relatório, o histórico de
    mudanças e de manutenção e as preferências. Não entram backups (que podem ter senhas de Wi-Fi), cópias de ajustes nem
    arquivos pessoais. Devolve um WinForge.Result.
    #>
    $title = (Get-WinForgeText 'Pacote de suporte')

    Enter-WinForgeAction -Title $title

    $final = $null
    $staging = Join-Path ([System.IO.Path]::GetTempPath()) ("WinForge-support-{0}" -f [guid]::NewGuid().ToString("N"))

    try {
        Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Junta num zip os logs, a verificação rápida do PC, o último relatório e as versões. Não leva backups, senhas nem arquivos pessoais.')
        Write-Host ""

        # Elevado com a conta de outro Administrador, a pasta Downloads seria a dessa conta.
        $folder = $(if (Test-WinForgeUserContextMismatch) { Join-Path (Get-WinForgeDataPath) "support" } else { Get-WinForgeDownloadsPath })
        if (-not (Test-Path -LiteralPath $folder)) { [void](New-Item -ItemType Directory -Path $folder -Force -ErrorAction Stop) }

        [void](New-Item -ItemType Directory -Path $staging -Force -ErrorAction Stop)
        $data = Get-WinForgeDataPath
        $included = @()

        Write-WinForgeStatus -Type Running -Message (Get-WinForgeText 'Lendo as versões e conferindo o PC...')
        [System.IO.File]::WriteAllText((Join-Path $staging "info.txt"), (Get-WinForgeSupportInfoText), (New-Object System.Text.UTF8Encoding $true))
        $included += (Get-WinForgeText 'versões')

        try {
            [System.IO.File]::WriteAllText((Join-Path $staging "check.json"), (ConvertTo-WinForgeCheckJson -Report (Get-WinForgeCheckReport)), (New-Object System.Text.UTF8Encoding $false))
            $included += (Get-WinForgeText 'verificação rápida do PC')
        }
        catch {
            Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'A verificação rápida do PC ficou de fora: {0}' "$(([string]$_.Exception.Message).TrimEnd('.'))")
        }

        # Os 10 logs mais recentes, o tempo de abertura e as partes da janela que não puderam ser mostradas.
        $logs = Join-Path $data "logs"
        $logFiles = @()

        if (Test-Path -LiteralPath $logs -PathType Container) {
            $logFiles = @(Get-ChildItem -LiteralPath $logs -Filter "winforge-*.log" -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 10)
            $logFiles += @(Get-ChildItem -LiteralPath $logs -Filter "abertura.log" -File -ErrorAction SilentlyContinue)
            $logFiles += @(Get-ChildItem -LiteralPath $logs -Filter "janela.log" -File -ErrorAction SilentlyContinue)
        }

        # A linha "Leva" conta só o que foi copiado (um log em uso por outro programa fica de fora).
        $copied = 0

        foreach ($file in $logFiles) {
            try { Copy-WinForgeSharedFile -From $file.FullName -To (Join-Path (Join-Path $staging "logs") $file.Name); $copied++ } catch { Write-Verbose "Log: $($_.Exception.Message)" }
        }

        if ($copied -gt 0) { $included += (Format-WinForgeCount -Count $copied -One (Get-WinForgeText 'log') -Many (Get-WinForgeText 'logs')) }

        # O último relatório (HTML e texto), se houver.
        $reports = Join-Path $data "reports"

        if (Test-Path -LiteralPath $reports -PathType Container) {
            $latest = @(Get-ChildItem -LiteralPath $reports -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -in @(".html", ".txt") } | Sort-Object LastWriteTime -Descending | Select-Object -First 2)

            $copied = 0

            foreach ($file in $latest) {
                try { Copy-WinForgeSharedFile -From $file.FullName -To (Join-Path (Join-Path $staging "report") $file.Name); $copied++ } catch { Write-Verbose "Relatório: $($_.Exception.Message)" }
            }

            if ($copied -gt 0) { $included += (Get-WinForgeText 'último relatório') }
        }

        # Os históricos (mudanças e manutenções) e as preferências (as da janela e as do monitor), quando existem.
        $state = @{ History = $false; Settings = $false }

        foreach ($entry in @(
                @{ Path = (Get-WinForgeChangeJournalPath); Kind = "History" },
                @{ Path = (Get-WinForgeMaintenanceHistoryPath); Kind = "History" },
                @{ Path = (Get-WinForgeSettingsPath); Kind = "Settings" },
                @{ Path = (Join-Path $data "agent.json"); Kind = "Settings" }
            )) {
            if (Test-Path -LiteralPath $entry.Path -PathType Leaf) {
                try { Copy-WinForgeSharedFile -From $entry.Path -To (Join-Path (Join-Path $staging "state") (Split-Path -Leaf $entry.Path)); $state[$entry.Kind] = $true } catch { Write-Verbose "Estado: $($_.Exception.Message)" }
            }
        }

        if ($state.History) { $included += (Get-WinForgeText 'históricos') }
        if ($state.Settings) { $included += (Get-WinForgeText 'preferências') }

        $stamp = (Get-Date).ToString("yyyyMMdd-HHmm", [System.Globalization.CultureInfo]::InvariantCulture)
        $path = Join-Path $folder (Get-WinForgeText 'WinForge-suporte-{0}.zip' "$stamp")

        if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force -ErrorAction Stop }

        Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
        [System.IO.Compression.ZipFile]::CreateFromDirectory($staging, $path)

        Write-Host ""
        Write-WinForgeStatus -Type Success -Message (Get-WinForgeText 'Pacote de suporte salvo: {0}' "$path")
        Write-WinForgeKeyValue -Label (Get-WinForgeText 'Leva') -Value (Join-WinForgeList -Items $included)
        Write-WinForgeStatus -Type Info -Notice -Message (Get-WinForgeText 'Os logs mostram o nome do PC e caminhos de pastas; confira o zip antes de mandar.')

        $final = Set-WinForgeResultView -Result (New-WinForgeResult -Kind Ok -Detail (Get-WinForgeText 'pacote salvo em {0}' "$path") -Title $title) `
            -Headline (Get-WinForgeText 'Pacote de suporte salvo') -Note (Get-WinForgeText '{0} está em {1}. Mande esse arquivo a quem vai ajudar.' "$(Split-Path -Leaf $path)" "$folder")

        if (Confirm-WinForgeAction -Message (Get-WinForgeText 'Mostrar o arquivo na pasta?') -DefaultKey S -YesLabel (Get-WinForgeText 'Mostrar') -NoLabel (Get-WinForgeText 'Agora não')) {
            try { Start-Process -FilePath "explorer.exe" -ArgumentList "/select,`"$path`"" -ErrorAction Stop } catch { Write-Verbose "Explorador: $($_.Exception.Message)" }
        }
    }
    catch {
        Write-WinForgeStatus -Type Error -Message (Get-WinForgeText 'Não foi possível criar o pacote de suporte: {0}' "$(([string]$_.Exception.Message).TrimEnd('.'))")
        $final = Set-WinForgeResultView -Result (New-WinForgeResult -Kind Failed -Detail ([string]$_.Exception.Message).TrimEnd('.') -Title $title) `
            -Headline (Get-WinForgeText 'O pacote de suporte não foi criado') -Note (Format-WinForgeReasonNote -Text $_.Exception.Message)
    }
    finally {
        Remove-WinForgeFolder -Path $staging -Quiet
    }

    Exit-WinForgeAction -Result $final
}


Export-ModuleMember -Function *
