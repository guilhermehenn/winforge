# Relatórios HTML e texto do estado do PC.


# ---------------------------------------------------------------------------
# Seções
# ---------------------------------------------------------------------------

function Get-WinForgeReportSystemItems {
    $os = Get-WinForgeCimOrNull -ClassName "Win32_OperatingSystem" | Select-Object -First 1

    $system = Get-WinForgeCimOrNull -ClassName "Win32_ComputerSystem" | Select-Object -First 1

    @{ Label = "Computador"; Value = $(if ([string]::IsNullOrWhiteSpace($env:COMPUTERNAME)) { [Environment]::MachineName } else { $env:COMPUTERNAME }) }
    @{ Label = "Usuário"; Value = $(if ([string]::IsNullOrWhiteSpace($env:USERNAME)) { [Environment]::UserName } else { $env:USERNAME }) }

    # Fabricante e modelo do PC, como em Sobre este PC: é o que um técnico pergunta primeiro (drivers, BIOS, garantia).
    $machine = Get-WinForgeMachineModelText -System $system

    if ($machine) { @{ Label = "Fabricante e modelo"; Value = $machine } }

    if ($os) {
        # O mesmo texto do cartão Windows da tela inicial: "Windows 11 Pro 24H2 (build 26100)".
        $build = [int](Get-WinForgeJsonValue -Object $os -Name "BuildNumber" -Default 0)
        $windows = Get-WinForgeWindowsName -Caption ([string](Get-WinForgeJsonValue -Object $os -Name "Caption" -Default "")) -Build $build
        $version = Get-WinForgeWindowsDisplayVersion

        if ($version) { $windows += " $version" }
        if ($build -gt 0) { $windows += " (build $build)" }

        @{ Label = "Sistema operacional"; Value = $windows.Trim() }
        @{ Label = "Tempo ligado"; Value = (Get-WinForgeUptimeText -LastBootTime $os.LastBootUpTime) }
    }
    else {
        @{ Label = "Sistema operacional"; Value = "Não foi possível ler" }
    }

    # O veredito da tela Suporte do Windows: num laudo, "este Windows ainda recebe correções?" é a primeira pergunta.
    try {
        $support = Get-WinForgeWindowsSupportStatus
        @{ Label = "Suporte do Windows"; Value = $(if ($support.Text) { [string]$support.Text } else { "Não foi possível conferir" }) }
    }
    catch {
        @{ Label = "Suporte do Windows"; Value = "Não foi possível conferir" }
    }

    # O mesmo veredito das telas: só os sinais fortes dizem "sim". Os fracos (arquivos esperando substituição) aparecem
    # em muitos PCs sem que o reinício seja necessário, e sozinhos não viram motivo.
    $pending = @(Get-WinForgePendingReboot)
    $strong = @($pending | Where-Object { $_.Strong })
    $rebootText = $(
        if ($strong.Count -gt 0) { ($strong | ForEach-Object { $_.Reason }) -join "; " }
        elseif ($pending.Count -gt 0) { "Não (só sinais que aparecem em quase todo PC; reiniciar não é obrigatório)" }
        else { "Não" }
    )
    @{ Label = "Reinício pendente"; Value = $rebootText }
}


function Get-WinForgeReportHardwareItems {
    $items = @()
    $cpu = Get-WinForgeCimOrNull -ClassName "Win32_Processor" | Select-Object -First 1
    $memory = @(Get-WinForgeCimOrNull -ClassName "Win32_PhysicalMemory")
    $board = Get-WinForgeCimOrNull -ClassName "Win32_BaseBoard" | Select-Object -First 1
    $bios = Get-WinForgeCimOrNull -ClassName "Win32_BIOS" | Select-Object -First 1

    if ($cpu) {
        $items += @{ Label = "Processador"; Value = ([string]$cpu.Name).Trim() }
    }

    if ($memory.Count -gt 0) {
        $totalRam = Format-WinForgeBytes -Bytes (($memory | Measure-Object -Property Capacity -Sum).Sum) -ZeroText "?"
        $memoryType = Convert-WinForgeMemoryType -Type ([int]($memory | Select-Object -First 1).SMBIOSMemoryType)
        $modules = Get-WinForgeMemoryModulesText -Modules $memory
        $items += @{ Label = "Memória"; Value = "$totalRam $memoryType$(if ($modules) { " ($modules)" })" }
    }

    if ($board) {
        $items += @{ Label = "Placa-mãe"; Value = "$($board.Manufacturer) $($board.Product)".Trim() }
    }

    if ($bios) {
        $items += @{ Label = "BIOS"; Value = $bios.SMBIOSBIOSVersion }
    }

    foreach ($gpu in @(Get-WinForgeCimOrNull -ClassName "Win32_VideoController" | Where-Object { -not [string]::IsNullOrWhiteSpace($_.Name) -and $_.Name -notmatch "Microsoft Basic|Remote|Parsec" })) {
        $items += @{ Label = "Vídeo"; Value = ([string]$gpu.Name).Trim() }
    }

    if ($items.Count -eq 0) {
        $items += @{ Label = "Hardware"; Value = "Não foi possível ler" }
    }

    return $items
}


function Get-WinForgeReportDiskItems {
    $items = @()

    # As mesmas frases das telas Discos e espaço livre e Saúde dos discos. Uma leitura vazia vira uma linha que diz isso:
    # sem ela, o relatório parecia de um PC sem disco.
    $summary = @(Get-WinForgeDiskSummary)
    $healthList = @(Get-WinForgeDiskHealth)

    if ($summary.Count -eq 0) { $items += @{ Label = "Unidades"; Value = "Não foi possível ler" } }

    foreach ($disk in $summary) {
        $items += @{ Label = $disk.Unidade; Value = (Get-WinForgeDiskSummaryText -Disk $disk) }
    }

    if ($healthList.Count -eq 0) { $items += @{ Label = "Saúde dos discos"; Value = "Não foi possível ler (em alguns PCs, requer Administrador)" } }

    foreach ($health in $healthList) {
        $status = Get-WinForgeDiskHealthStatusText -Status $health.HealthStatus
        if ($status -eq "Desconhecido") { $status = "Estado desconhecido" }

        $text = if ($health.Notes.Count -gt 0) { "$status. Alertas: $($health.Notes -join '; ')" }
        elseif ($health.CountersAvailable) { "$status, sem alertas" }
        else { "$status, sem contadores de confiabilidade" }
        $drives = @(Get-WinForgeJsonValue -Object $health -Name "Drives" -Default @())
        $items += @{ Label = "Saúde: $($health.Name)$(if ($drives.Count -gt 0) { " ($($drives -join ', '))" })"; Value = $text }
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
        $items += @{ Label = "Últimos 7 dias"; Value = "Nenhum evento crítico ou de erro" }
    }

    foreach ($entry in $summary) {
        $value = Format-WinForgeEventOccurrences -Entry $entry
        if ($entry.Hint) { $value += " - $($entry.Hint)" }
        $items += @{ Label = "$(Get-WinForgeEventProviderText -Provider $entry.Provider) (ID $($entry.Id))"; Value = $value }
    }

    return $items
}


function Get-WinForgeReportBatteryItems {
    $items = @()
    $info = Get-WinForgeBatteryInfo

    if (-not $info.Present) {
        return @(@{ Label = "Bateria"; Value = "Nenhuma bateria encontrada" })
    }

    $now = @()
    if ($null -ne $info.State.ChargePercent) { $now += "$($info.State.ChargePercent)%" }
    if ($info.State.State) { $now += $info.State.State }
    if ($now.Count -gt 0) { $items += @{ Label = "Agora"; Value = ($now -join ", ") } }

    foreach ($reading in @($info.Readings)) {
        $label = $(if ($reading.Name) { $reading.Name } else { "Bateria" })
        $assessment = Get-WinForgeBatteryAssessment -HealthPercent $reading.HealthPercent -Missing $(if ($null -ne $reading.DesignMwh -and $null -eq $reading.FullMwh) { "full" } else { "design" })

        $capacity = @()
        if ($null -ne $reading.FullMwh -and $null -ne $reading.DesignMwh -and -not [bool](Get-WinForgeJsonValue -Object $reading -Name "Relative" -Default $false)) {
            $capacity += "$(Format-WinForgeWattHours -MilliwattHours $reading.FullMwh) de $(Format-WinForgeWattHours -MilliwattHours $reading.DesignMwh) de fábrica"
        }
        if ($null -ne $reading.Cycles) { $capacity += (Format-WinForgeCount -Count ([int]$reading.Cycles) -One "ciclo" -Many "ciclos") }

        $parts = @($assessment.Text) + @($capacity)
        $items += @{ Label = $label; Value = ($parts -join " | ") }
    }

    if (@($info.Readings).Count -eq 0) {
        $items += @{ Label = "Capacidade"; Value = "O Windows não informou a capacidade da bateria" }
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
        $items += @{ Label = $(if ($row.Label -eq "Situação") { "Antivírus" } else { $row.Label }); Value = $row.Value }
    }

    if ($null -eq $status.Firewall) {
        $items += @{ Label = "Firewall"; Value = "Não foi possível ler" }
    }
    else {
        $items += @{ Label = "Firewall"; Value = ((@($status.Firewall) | ForEach-Object { $product = [string](Get-WinForgeJsonValue -Object $_ -Name "Product" -Default ""); "$(Get-WinForgeFirewallProfileName -Name $_.Name): $(if ($product) { "protegido por $product" } elseif ($_.Enabled) { 'ligado' } elseif (-not [bool](Get-WinForgeJsonValue -Object $_ -Name 'Applies' -Default $true)) { 'desligado (não vale para este PC, que não está num domínio)' } else { 'desligado' })" }) -join "; ") }
    }

    foreach ($finding in @($status.Findings | Where-Object { $_.Level -eq "Warning" })) {
        $items += @{ Label = "Atenção"; Value = $finding.Text }
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
            $items += @{ Label = "Duração"; Value = "$(Format-WinForgeDuration -Span $span) (das $(Format-WinForgeDateTime -When $Maintenance.StartedAt -Pattern 'HH:mm') às $(Format-WinForgeDateTime -When $after.At -Pattern 'HH:mm'))" }
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
        $items = @(@{ Label = "Não foi possível ler esta seção"; Value = $_.Exception.Message })
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
        $items += @{ Label = "Saúde do PC"; Value = "$($health.Score) de 100 ($($health.Label))" }
    }
    else {
        $items += @{ Label = "Saúde do PC"; Value = "Não foi possível avaliar" }
    }

    $issues = @($health.Issues | Where-Object { $null -ne $_ })

    foreach ($issue in $issues) {
        $items += @{ Label = $(if ($issue.Severe) { "Grave" } else { "Atenção" }); Value = [string]$issue.Text }
    }

    if ($issues.Count -eq 0) {
        $items += @{ Label = "Pontos de atenção"; Value = "Nenhum" }
    }

    $unread = @(Get-WinForgeJsonValue -Object $health -Name "Unread" -Default @())

    if ($unread.Count -gt 0) {
        $items += @{ Label = "Não foi possível ler"; Value = ($unread -join ", ") }
    }

    foreach ($notice in @($status.Notices | Where-Object { $null -ne $_ })) {
        $items += @{ Label = "Aviso"; Value = [string]$notice.Text }
    }

    return $items
}


function Get-WinForgeReportSections {
    $sections = @()

    $sections += New-WinForgeReportSection -Title "Pontos de atenção" -Build { Get-WinForgeReportAttentionItems }
    $sections += New-WinForgeReportSection -Title "Sistema" -Build { Get-WinForgeReportSystemItems }
    $sections += New-WinForgeReportSection -Title "Hardware" -Build { Get-WinForgeReportHardwareItems }
    $sections += New-WinForgeReportSection -Title "Discos" -Build { Get-WinForgeReportDiskItems }
    $sections += New-WinForgeReportSection -Title "Ajustes do Windows e Personalização" -Build { Get-WinForgeReportTweakItems }
    $sections += New-WinForgeReportSection -Title "Eventos críticos (7 dias)" -Build { Get-WinForgeReportEventItems }

    $sections += New-WinForgeReportSection -Title "Segurança" -Build { Get-WinForgeReportSecurityItems }

    if (Test-WinForgeLaptop) {
        $sections += New-WinForgeReportSection -Title "Bateria" -Build { Get-WinForgeReportBatteryItems }
    }

    $maintenance = Get-WinForgeLastMaintenance

    if ($null -ne $maintenance) {
        $title = "Última manutenção"

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
    [void]$builder.AppendLine("WinForge - Relatório (build $Build)")
    [void]$builder.AppendLine("Gerado em $(Format-WinForgeDateTime -When (Get-Date))")

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

    [void]$builder.AppendLine("<!doctype html><html lang=`"pt-BR`"><head><meta charset=`"utf-8`">")
    [void]$builder.AppendLine("<meta name=`"viewport`" content=`"width=device-width, initial-scale=1`">")
    [void]$builder.AppendLine("<title>WinForge - Relatório</title><style>")
    [void]$builder.AppendLine(":root{--bg:#f6f8fa;--card:#fff;--text:#1f2328;--muted:#656d76;--line:#d8dee4;--accent:#0969da}")
    [void]$builder.AppendLine("@media (prefers-color-scheme:dark){:root{--bg:#0d1117;--card:#161b22;--text:#e6edf3;--muted:#8b949e;--line:#30363d;--accent:#58a6ff}}")
    [void]$builder.AppendLine("body{margin:0;background:var(--bg);color:var(--text);font:15px/1.5 Segoe UI,system-ui,sans-serif}")
    [void]$builder.AppendLine("main{max-width:860px;margin:0 auto;padding:24px 16px}h1{margin:0 0 4px;font-size:24px}")
    [void]$builder.AppendLine(".meta{color:var(--muted);margin-bottom:20px}section{background:var(--card);border:1px solid var(--line);border-radius:10px;padding:14px 18px;margin-bottom:14px}")
    [void]$builder.AppendLine("h2{margin:0 0 8px;font-size:16px;color:var(--accent)}dl{display:grid;grid-template-columns:minmax(140px,30%) 1fr;gap:4px 14px;margin:0}")
    [void]$builder.AppendLine("dt{color:var(--muted)}dd{margin:0;overflow-wrap:anywhere}@media (max-width:560px){dl{grid-template-columns:1fr}}")
    [void]$builder.AppendLine("</style></head><body><main>")
    [void]$builder.AppendLine("<h1>WinForge</h1><div class=`"meta`">Relatório gerado em $(& $encode (Format-WinForgeDateTime -When (Get-Date))) &middot; build $(& $encode $Build)</div>")

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
            throw "não foi possível criar a pasta dos relatórios ($Directory): $($_.Exception.Message.TrimEnd('.'))"
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
        throw "não foi possível gravar o relatório em ${Directory}: $($_.Exception.Message.TrimEnd('.'))"
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

    $next = Read-WinForgeChoice -Message "O que deseja fazer com o relatório?" -DefaultKey "A" -ShowMenu -TextPrompt "Opção (ENTER = abrir)" -Options @(
        @{ Key = "A"; Label = "Abrir o relatório"; Accent = $true },
        @{ Key = "P"; Label = "Mostrar na pasta" },
        @{ Key = "X"; Label = "Agora não"; Exit = $true }
    )

    if ($next -notin @("A", "P")) { return "" }

    try {
        # Pelo Explorer, e não direto: com o WinForge como Administrador, o navegador abriria elevado também. O
        # Explorer já está aberto na sessão da pessoa e abre o arquivo no navegador padrão, sem privilégios.
        $arguments = $(if ($next -eq "P") { "/select,`"$Path`"" } else { "`"$Path`"" })
        Start-Process -FilePath "explorer.exe" -ArgumentList $arguments -ErrorAction Stop
    }
    catch {
        $what = $(if ($next -eq "P") { "mostrar a pasta" } else { "abrir o relatório" })
        Write-WinForgeStatus -Type Warning -Message "Não foi possível ${what}: $($_.Exception.Message)"
        return "${what}: $($_.Exception.Message)"
    }

    return ""
}


function Invoke-WinForgeReport {
    $title = "Exportar relatório"
    Enter-WinForgeAction -Title $title

    $result = $null

    try {
        # O andamento vai na barra: uma linha "Coletando..." ficaria no resumo depois do fim.
        Write-Progress -Activity $title -Status "coletando sistema, discos, eventos e segurança"

        try {
            $report = Export-WinForgeReport
        }
        finally {
            Write-Progress -Activity $title -Completed
        }

        $textProblem = [string](Get-WinForgeJsonValue -Object $report -Name "TextProblem" -Default "")

        Write-Host ""

        if ($textProblem) {
            Write-WinForgeStatus -Type Warning -Message "Relatório HTML salvo; a cópia em texto não pôde ser gravada: ${textProblem}."
            Write-WinForgeKeyValue -Label "HTML" -Value $report.Html
            $result = New-WinForgeResult -Kind Warning -Detail "relatório salvo em HTML; a cópia em texto não pôde ser gravada"
        }
        else {
            Write-WinForgeStatus -Type Success -Message "Relatório salvo."
            Write-WinForgeKeyValue -Label "HTML" -Value $report.Html
            Write-WinForgeKeyValue -Label "Texto" -Value $report.Text
            $result = New-WinForgeResult -Kind Ok -Detail "relatório salvo em HTML e em texto"
        }

        Write-Host ""
        Write-WinForgeStatus -Type Info -Message "O relatório traz o nome do PC e do usuário, o hardware e a segurança: confira antes de enviar a alguém."

        $problem = Open-WinForgeSavedReport -Path $report.Html

        if ($problem) {
            $result = New-WinForgeResult -Kind Warning -Detail "relatório salvo, mas não foi possível $problem"
        }
    }
    catch {
        Write-Host ""
        Write-WinForgeStatus -Type Error -Message "O relatório não foi salvo: $($_.Exception.Message.TrimEnd('.'))."
        $result = New-WinForgeResult -Kind Failed -Detail "o relatório não foi salvo"
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
            $notes += "A nota de saúde não inclui o que não pôde ser lido: $($unread -join ', ')."
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

            $notes += "A consulta ao Windows Update foi pulada para a verificação ser rápida; rode Segurança > Auditoria de segurança para incluí-la."
        }
        catch {
            $notes += "Não foi possível fazer a auditoria de segurança: $($_.Exception.Message)"
        }

        if (-not (Test-WinForgeAdministrator)) {
            $notes += "Sem Administrador: pontos como a criptografia do disco não são verificados."
        }

        $level = Get-WinForgeCheckLevel -Health $health -Attention $attention
        $problem = ""

        # Nada do que forma a nota foi lido: a nota 100 não quer dizer "tudo em dia". Sem nada grave vindo da auditoria, o
        # resultado é "não foi possível avaliar".
        if ($level -eq "Ok" -and -not (Test-WinForgeHealthKnown -Health $health)) {
            $level = "Unknown"
            $problem = "nenhuma leitura da nota de saúde respondeu ($($unread -join ', '))"
        }
        elseif ($level -eq "Ok" -and $unread.Count -gt 0) {
            # Parte da nota sem leitura (a nota já diz qual): "em dia" (código 0) prometeria o que não foi conferido.
            $level = "Attention"
        }
        elseif ($level -eq "Ok" -and $null -ne $security -and $security.NoGradeReason -eq "Antivirus") {
            # O antivírus não pôde ser verificado: a auditoria fica sem nota, e "em dia" também prometeria demais.
            $level = "Attention"
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

    Write-WinForgeSection -Title "Verificação rápida do WinForge (Build $($Report.Build))"

    if ($Report.Status -eq "Unknown") {
        Write-WinForgeStatus -Type Error -Message "Não foi possível avaliar o PC: $($Report.Error)"
        Write-WinForgeKeyValue -Label "Código de saída" -Value ([string]$Report.ExitCode)
        return
    }

    Write-WinForgeKeyValue -Label "Saúde do PC" -Value "$($Report.Health.Score) de 100 ($($Report.Health.Label))"

    foreach ($issue in @($Report.Health.Issues)) {
        Write-WinForgeStatus -Type $(if ($issue.Weight -ge 25) { "Error" } else { "Warning" }) -Message $issue.Text
    }

    if (@($Report.Health.Issues).Count -eq 0) {
        $unread = @(Get-WinForgeJsonValue -Object $Report.Health -Name "Unread" -Default @())
        Write-WinForgeStatus -Type Success -Message $(if ($unread.Count -gt 0) { "Nenhum ponto de atenção no que foi lido." } else { "Nenhum ponto de atenção na saúde do PC." })
    }

    if ($null -ne $Report.Security) {
        if ($null -eq $Report.Security.Score) {
            $reason = [string](Get-WinForgeJsonValue -Object $Report.Security -Name "NoGradeReason" -Default "")
            $why = switch ($reason) {
                "Antivirus" { "sem nota: o antivírus não pôde ser verificado" }
                "Coverage" { "sem nota: menos da metade dos pontos pôde ser verificada" }
                default { "sem nota: não foi possível calcular" }
            }

            Write-WinForgeKeyValue -Label "Segurança" -Value $why -Level Warn
        }
        else {
            Write-WinForgeKeyValue -Label "Segurança" -Value "$($Report.Security.Score) de 100 · $($Report.Security.Grade)"
        }

        foreach ($item in @($Report.Security.Attention)) {
            Write-WinForgeStatus -Type $(if ($item.Status -eq "Bad") { "Error" } else { "Warning" }) -Message "$($item.Title): $($item.Detail)"
        }
    }

    foreach ($note in @($Report.Notes)) {
        Write-Host "  $note" -ForegroundColor DarkGray
    }

    $text = switch ($Report.Status) {
        "Ok"        { "Tudo em dia" }
        "Attention" { "Há pontos de atenção" }
        default     { "Há algo crítico" }
    }

    Write-WinForgeKeyValue -Label "Resultado" -Value "$text (código de saída $($Report.ExitCode))"
}


Export-ModuleMember -Function *
