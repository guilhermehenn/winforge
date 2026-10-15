# Relatórios HTML e texto do estado do PC.


# ---------------------------------------------------------------------------
# Seções
# ---------------------------------------------------------------------------

function Get-WinForgeReportSystemItems {
    $os = Get-WinForgeCimOrNull -ClassName "Win32_OperatingSystem" | Select-Object -First 1

    @{ Label = "Computador"; Value = $env:COMPUTERNAME }
    @{ Label = "Usuário"; Value = $env:USERNAME }

    if ($os) {
        @{ Label = "Sistema operacional"; Value = "$($os.Caption) (build $($os.BuildNumber))" }
        @{ Label = "Tempo ligado"; Value = (Get-WinForgeUptimeText -LastBootTime $os.LastBootUpTime) }
    }
    else {
        @{ Label = "Sistema operacional"; Value = "Não foi possível ler" }
    }

    $pending = @(Get-WinForgePendingReboot)
    @{ Label = "Reinício pendente"; Value = $(if ($pending.Count -eq 0) { "Não" } else { ($pending | ForEach-Object { $_.Reason }) -join "; " }) }
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
        $items += @{ Label = "Memória"; Value = "$totalRam $memoryType, $($memory.Count) módulo(s)" }
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

    foreach ($disk in @(Get-WinForgeDiskSummary)) {
        $items += @{ Label = $disk.Unidade; Value = "$($disk.Tipo) - $($disk.Modelo) | $($disk.Usado) de $($disk.Total) ($($disk.Uso))" }
    }

    foreach ($health in @(Get-WinForgeDiskHealth)) {
        $text = if ($health.Notes.Count -eq 0) { "$($health.HealthStatus), sem alertas" } else { "$($health.HealthStatus): $($health.Notes -join '; ')" }
        $items += @{ Label = "Saúde: $($health.Name)"; Value = $text }
    }

    return $items
}


function Get-WinForgeReportTweakItems {
    $items = @()

    foreach ($tweak in @(Get-WinForgeTweakOverview)) {
        $items += @{ Label = $tweak.Name; Value = $tweak.Status }
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
        $value = "$($entry.Count)x, último em $($entry.Last.ToString('dd/MM HH:mm'))"
        if ($entry.Hint) { $value += " - $($entry.Hint)" }
        $items += @{ Label = "$($entry.Provider) (ID $($entry.Id))"; Value = $value }
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
        $assessment = Get-WinForgeBatteryAssessment -HealthPercent $reading.HealthPercent

        $capacity = @()
        if ($null -ne $reading.FullMwh -and $null -ne $reading.DesignMwh) {
            $capacity += "$(Format-WinForgeWattHours -Milliwatts $reading.FullMwh) de $(Format-WinForgeWattHours -Milliwatts $reading.DesignMwh) de fábrica"
        }
        if ($null -ne $reading.Cycles) { $capacity += "$($reading.Cycles) ciclos" }

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

    $items += @{ Label = "Antivírus"; Value = (Get-WinForgeAntivirusModeText -Antivirus $antivirus) }

    $signatures = Get-WinForgeSignatureText -Antivirus $antivirus
    if ($signatures) { $items += @{ Label = "Assinaturas"; Value = $signatures } }

    if ($antivirus.Mode -eq "Active") {
        $items += @{ Label = "Última verificação rápida"; Value = (Get-WinForgeScanDateText -When $antivirus.LastQuickScan) }
    }

    if ($null -ne $status.Threats) {
        $items += @{ Label = "Ameaças ativas"; Value = $(if (@($status.Threats).Count -eq 0) { "Nenhuma" } else { @($status.Threats) -join ", " }) }
    }

    if ($null -eq $status.Firewall) {
        $items += @{ Label = "Firewall"; Value = "Não foi possível ler" }
    }
    else {
        $items += @{ Label = "Firewall"; Value = ((@($status.Firewall) | ForEach-Object { "$(Get-WinForgeFirewallProfileName -Name $_.Name): $(if ($_.Enabled) { 'ligado' } else { 'desligado' })" }) -join "; ") }
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
            $items += @{ Label = "Duração da fase automática"; Value = "$(Format-WinForgeDuration -Span $span) (das $($Maintenance.StartedAt.ToString('HH:mm')) às $($after.At.ToString('HH:mm')))" }
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


function Get-WinForgeReportSections {
    $sections = @()

    $sections += New-WinForgeReportSection -Title "Sistema" -Build { Get-WinForgeReportSystemItems }
    $sections += New-WinForgeReportSection -Title "Hardware" -Build { Get-WinForgeReportHardwareItems }
    $sections += New-WinForgeReportSection -Title "Discos" -Build { Get-WinForgeReportDiskItems }
    $sections += New-WinForgeReportSection -Title "Ajustes do Windows" -Build { Get-WinForgeReportTweakItems }
    $sections += New-WinForgeReportSection -Title "Eventos críticos (7 dias)" -Build { Get-WinForgeReportEventItems }

    $sections += New-WinForgeReportSection -Title "Segurança" -Build { Get-WinForgeReportSecurityItems }

    if (Test-WinForgeLaptop) {
        $sections += New-WinForgeReportSection -Title "Bateria" -Build { Get-WinForgeReportBatteryItems }
    }

    $maintenance = Get-WinForgeLastMaintenance

    if ($null -ne $maintenance) {
        $title = "Última manutenção"

        try { $title += " ($($maintenance.StartedAt.ToString('dd/MM/yyyy HH:mm')))" } catch { }

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
    [void]$builder.AppendLine("Gerado em $((Get-Date).ToString('dd/MM/yyyy HH:mm'))")

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
    [void]$builder.AppendLine("<h1>WinForge</h1><div class=`"meta`">Relatório gerado em $(& $encode (Get-Date).ToString('dd/MM/yyyy HH:mm')) &middot; build $(& $encode $Build)</div>")

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

    if (-not (Test-Path -LiteralPath $Directory)) {
        New-Item -Path $Directory -ItemType Directory -Force | Out-Null
    }

    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $sections = @(Get-WinForgeReportSections)
    $build = Get-WinForgeBuild

    $htmlPath = Join-Path $Directory "winforge-relatorio-$stamp.html"
    $textPath = Join-Path $Directory "winforge-relatorio-$stamp.txt"

    Set-Content -LiteralPath $htmlPath -Value (ConvertTo-WinForgeHtmlReport -Sections $sections -Build $build) -Encoding UTF8
    Set-Content -LiteralPath $textPath -Value (ConvertTo-WinForgeTextReport -Sections $sections -Build $build) -Encoding UTF8

    return [PSCustomObject]@{ Html = $htmlPath; Text = $textPath }
}


function Invoke-WinForgeReport {
    Enter-WinForgeAction -Title "Exportar relatório"

    Write-WinForgeStatus -Type Running -Message "Coletando informações do sistema, discos e eventos..."

    try {
        $report = Export-WinForgeReport

        Write-Host ""
        Write-WinForgeStatus -Type Success -Message "Relatório salvo."
        Write-WinForgeKeyValue -Label "HTML" -Value $report.Html
        Write-WinForgeKeyValue -Label "Texto" -Value $report.Text
        Write-Host ""

        if (Confirm-WinForgeAction "Deseja abrir o relatório HTML agora?" -DefaultKey S) {
            try {
                Start-Process -FilePath $report.Html -ErrorAction Stop
            }
            catch {
                Write-WinForgeStatus -Type Warning -Message "Não foi possível abrir o relatório: $($_.Exception.Message)"
            }
        }
    }
    catch {
        Write-Host ""
        Write-WinForgeStatus -Type Error -Message "Falha ao gerar o relatório: $($_.Exception.Message)"
    }

    Exit-WinForgeAction
}


Export-ModuleMember -Function *
