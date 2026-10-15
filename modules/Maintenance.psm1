# Manutenção recomendada: um fluxo guiado em fases, para que o usuário decida tudo no começo e a parte
# demorada rode sem perguntas.
#
#   1. Preparação      avisos e confirmação
#   2. Plano           uma única lista com tudo o que pode ser feito (manual e automático)
#   3. Revisão manual  janelas do Windows para enxugar o PC (inicialização, programas, Downloads)
#   4. Detalhes        perguntas das etapas escolhidas (quais ajustes, quais atualizações)
#   5. Automática      sem perguntas, na ordem em que as etapas fazem sentido, com resumo
#   6. Atualizações    janelas do Windows Update e da Store, já com o PC limpo e reparado
#   7. Encerramento    CHKDSK offline, relatório e reinício (só se for necessário)


# ---------------------------------------------------------------------------
# Plano
# ---------------------------------------------------------------------------

function New-WinForgePlanItem {
    param (
        [string]$Id,
        [ValidateSet("Before", "Auto", "After")]
        [string]$Phase,
        [string]$Title,
        [string]$Description,
        [string]$Shortcut = "",
        [string]$Hint = ""
    )

    return [PSCustomObject]@{
        Id          = $Id
        Phase       = $Phase
        Kind        = $(if ($Phase -eq "Auto") { "Automático" } else { "Manual" })
        Title       = $Title
        Description = $Description
        Shortcut    = $Shortcut
        Hint        = $Hint
    }
}


function Get-WinForgeMaintenancePlanItems {
    # A ordem desta lista é a ordem de execução. Antes: enxugar o PC. Automático: proteger, consertar, limpar,
    # atualizar, verificar o antivírus (já com o PC limpo e atualizado), otimizar. Depois: o que depende do PC já limpo e reparado (Windows Update) e a revisão do que sobrou.
    return @(
        (New-WinForgePlanItem -Id "startup-apps" -Phase Before -Title "Revisar aplicativos de inicialização" `
            -Description "abre as Configurações do Windows" -Shortcut "StartupApps" `
            -Hint "Desative apenas o que você reconhece e não precisa abrir junto com o Windows."),
        (New-WinForgePlanItem -Id "installed-apps" -Phase Before -Title "Revisar aplicativos instalados" `
            -Description "abre as Configurações do Windows" -Shortcut "InstalledApps" `
            -Hint "Remova somente os aplicativos que você reconhece e não usa."),
        (New-WinForgePlanItem -Id "programs-features" -Phase Before -Title "Revisar Programas e Recursos" `
            -Description "painel clássico, para programas antigos" -Shortcut "ProgramsAndFeatures" `
            -Hint "Programas clássicos que não aparecem na lista anterior. Remova somente o que você reconhece."),
        (New-WinForgePlanItem -Id "downloads" -Phase Before -Title "Revisar a pasta Downloads" `
            -Description "abre a pasta no Explorador" -Shortcut "Downloads" `
            -Hint "Apague arquivos antigos ou desnecessários. A limpeza automática não toca nos Downloads."),

        (New-WinForgePlanItem -Id "restore-point" -Phase Auto -Title "Criar ponto de restauração" `
            -Description "registra o estado atual antes de qualquer mudança"),
        (New-WinForgePlanItem -Id "network" -Phase Auto -Title "Reparar rede e DNS" `
            -Description "só se o ping ou o DNS falharem; vem antes do que usa a internet"),
        (New-WinForgePlanItem -Id "cleanup" -Phase Auto -Title "Limpeza rápida" `
            -Description "temporários do usuário e do Windows e a Lixeira; libera espaço antes dos reparos"),
        (New-WinForgePlanItem -Id "repair" -Phase Auto -Title "Reparar o Windows (DISM + SFC)" `
            -Description "o DISM só repara se houver dano marcado"),
        (New-WinForgePlanItem -Id "chkdsk" -Phase Auto -Title "Verificar o sistema de arquivos (CHKDSK)" `
            -Description "online; o reparo offline só com sua confirmação ao final"),
        (New-WinForgePlanItem -Id "winget" -Phase Auto -Title "Atualizar programas (winget)" `
            -Description "você escolhe o que atualizar antes de começar"),
        (New-WinForgePlanItem -Id "drivers" -Phase Auto -Title "Detectar dispositivos e drivers" `
            -Description "procura hardware novo e drivers disponíveis"),
        (New-WinForgePlanItem -Id "security" -Phase Auto -Title "Verificação de segurança" `
            -Description "atualiza o antivírus e faz a verificação rápida do Windows Defender; leva alguns minutos"),
        (New-WinForgePlanItem -Id "optimize" -Phase Auto -Title "Otimizar a unidade do sistema" `
            -Description "TRIM em SSD ou desfragmentação em HDD; por último, depois das mudanças em disco"),
        (New-WinForgePlanItem -Id "tweaks" -Phase Auto -Title "Aplicar ajustes recomendados" `
            -Description "reversíveis; você escolhe quais antes de começar"),

        (New-WinForgePlanItem -Id "storage" -Phase After -Title "Ver o que o Windows ainda sugere limpar" `
            -Description "abre as Configurações de armazenamento" -Shortcut "Storage" `
            -Hint "Depois da limpeza automática, revise o que sobrou (por exemplo, arquivos de instalações antigas)."),
        (New-WinForgePlanItem -Id "windows-update" -Phase After -Title "Instalar atualizações do Windows" `
            -Description "abre o Windows Update" -Shortcut "WindowsUpdate" `
            -Hint "Instale as atualizações disponíveis. Fica por último para não competir com os reparos."),
        (New-WinForgePlanItem -Id "optional-updates" -Phase After -Title "Revisar atualizações opcionais e drivers" `
            -Description "abre as atualizações opcionais" -Shortcut "OptionalUpdates" `
            -Hint "Instale drivers opcionais somente quando forem pertinentes ao seu hardware ou a uma correção."),
        (New-WinForgePlanItem -Id "store-updates" -Phase After -Title "Atualizar aplicativos da Microsoft Store" `
            -Description "abre a Microsoft Store" -Shortcut "MicrosoftStore" `
            -Hint "Atualize os aplicativos instalados pela Microsoft Store.")
    )
}


# ---------------------------------------------------------------------------
# Fase 1: preparação
# ---------------------------------------------------------------------------

function Confirm-WinForgeMaintenancePreflight {
    $session = Get-WinForgeSessionInfo

    Write-Host "A manutenção recomendada segue estas fases:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "   1. Você escolhe tudo o que será feito, em uma única lista" -ForegroundColor Gray
    Write-Host "   2. Revisão manual de programas e Downloads (janelas do Windows)" -ForegroundColor Gray
    Write-Host "   3. Fase automática: sem perguntas, com resumo no final" -ForegroundColor Gray
    Write-Host "   4. Atualizações do Windows e reinício, só se for necessário" -ForegroundColor Gray
    Write-Host ""
    Write-WinForgeStatus -Type Warning -Message "Salve seu trabalho e feche os demais aplicativos, deixando somente o WinForge aberto."

    if ($session.UserMismatch) {
        Write-Host ""
        Write-WinForgeStatus -Type Warning -Message "O WinForge está elevado com outra conta. Temporários, Downloads e ajustes de usuário afetarão este perfil, não o do usuário logado."

        if (-not (Confirm-WinForgeAction "Deseja continuar mesmo assim?" -DefaultKey N)) {
            return $false
        }
    }

    if (Test-WinForgePendingReboot) {
        Write-Host ""
        Write-WinForgeStatus -Type Warning -Message "Há um reinício pendente. Reparos e instalações funcionam melhor depois de reiniciar."

        if (-not (Confirm-WinForgeAction "Deseja continuar sem reiniciar antes?" -DefaultKey N)) {
            return $false
        }
    }

    if (Test-WinForgeOnBattery) {
        Write-Host ""
        Write-WinForgeStatus -Type Warning -Message "O notebook está usando a bateria. Reparos e atualizações podem levar bastante tempo; conecte o carregador antes de continuar."

        if (-not (Confirm-WinForgeAction "Deseja continuar usando a bateria?" -DefaultKey N)) {
            return $false
        }
    }

    $freeBytes = Get-WinForgeSystemDriveFreeBytes

    if ((Get-WinForgeDiskSpaceLevel -FreeBytes $freeBytes) -eq "Critical") {
        Write-Host ""
        Write-WinForgeStatus -Type Warning -Message "O disco do Windows tem pouco espaço livre ($(Format-WinForgeBytes -Bytes $freeBytes)). O DISM e as atualizações precisam de espaço para trabalhar; a limpeza do plano ajuda, mas libere mais se puder."
    }

    Write-Host ""

    return (Confirm-WinForgeAction "Deseja começar a manutenção recomendada?" -DefaultKey S)
}


# ---------------------------------------------------------------------------
# Fase 2: plano
# ---------------------------------------------------------------------------

function Read-WinForgeMaintenancePlan {
    # Uma lista única, na ordem de execução. Devolve os Ids marcados, ou $null se o usuário cancelar ou não marcar nada.
    $items = @(Get-WinForgeMaintenancePlanItems)

    $options = @(
        foreach ($item in $items) {
            @{ Key = $item.Id; Label = $item.Title; Description = "$($item.Kind) - $($item.Description)"; Selected = $true }
        }
    )

    Write-WinForgeSection -Title "Plano da manutenção"
    Write-Host "A lista está na ordem de execução. Desmarque o que não quiser fazer." -ForegroundColor Yellow
    Write-Host ""

    $picked = Read-WinForgeMultiSelect -Message "Escolha o que a manutenção deve fazer" -Options $options

    if ($null -eq $picked) {
        return $null
    }

    # Mantém a ordem do plano, não a ordem em que as respostas chegaram.
    return @($items | Where-Object { @($picked) -contains $_.Id } | ForEach-Object { $_.Id })
}


# ---------------------------------------------------------------------------
# Fases 3 e 6: etapas manuais
# ---------------------------------------------------------------------------

function Invoke-WinForgeManualStep {
    # Abre a janela da etapa e espera o usuário. Devolve $false se ele pediu para pular as etapas restantes.
    param (
        [Parameter(Mandatory)]
        $Item,

        [int]$Number,
        [int]$Total
    )

    Write-WinForgeSection -Title "Etapa manual $Number de $Total - $($Item.Title)"

    if (-not [string]::IsNullOrWhiteSpace($Item.Hint)) {
        Write-Host $Item.Hint -ForegroundColor Yellow
        Write-Host ""
    }

    [void](Open-WinForgeShortcut -Name $Item.Shortcut)
    Write-Host ""

    $options = @(@{ Key = "C"; Label = "Continuar"; Accent = $true })

    if ($Number -lt $Total) {
        $options += @{ Key = "P"; Label = "Pular as etapas manuais restantes" }
    }

    $answer = Read-WinForgeChoice -Message "Conclua o que desejar na janela aberta e depois continue." `
        -TextPrompt "Conclua o que desejar na janela aberta e pressione ENTER$(if ($Number -lt $Total) { ' (P = pular as etapas manuais restantes)' })" `
        -DefaultKey "C" -Options $options

    return ($answer -ne "P")
}


function Invoke-WinForgeManualPhase {
    param (
        [Parameter(Mandatory)]
        [object[]]$Items
    )

    $steps = @($Items)

    for ($index = 0; $index -lt $steps.Count; $index++) {
        $continue = Invoke-WinForgeManualStep -Item $steps[$index] -Number ($index + 1) -Total $steps.Count

        if (-not $continue) {
            Write-Host ""
            Write-WinForgeStatus -Type Info -Message "Etapas manuais restantes puladas."
            break
        }
    }
}


# ---------------------------------------------------------------------------
# Fase 4: detalhes das etapas automáticas escolhidas
# ---------------------------------------------------------------------------

function Read-WinForgeMaintenanceDetails {
    param (
        [string[]]$AutoIds
    )

    $details = [PSCustomObject]@{
        TweakIds   = @()
        WingetPlan = $null
    }

    if ($AutoIds -contains "tweaks") {
        Write-WinForgeSection -Title "Aplicar ajustes recomendados"

        try {
            $tweakIds = Select-WinForgeRecommendedTweaks

            if ($null -ne $tweakIds) {
                $details.TweakIds = @($tweakIds)
            }
        }
        catch {
            Write-WinForgeStatus -Type Error -Message "Não foi possível montar a lista de ajustes: $($_.Exception.Message)"
        }
    }

    if ($AutoIds -contains "winget") {
        Write-WinForgeSection -Title "Atualizar programas (winget)"

        try {
            $details.WingetPlan = Get-WinForgeWingetUpgradePlan
        }
        catch {
            Write-WinForgeStatus -Type Error -Message "Não foi possível consultar o winget: $($_.Exception.Message)"
            $details.WingetPlan = [PSCustomObject]@{ Action = "Error"; Detail = $_.Exception.Message; Ids = @(); Packages = @() }
        }
    }

    return $details
}


function Confirm-WinForgeAutomaticPhase {
    param (
        [int]$StepCount
    )

    Write-Host ""
    Write-Host "A fase automática executa $StepCount etapa(s), altera o sistema e pode interromper a rede por instantes." -ForegroundColor Yellow
    Write-Host "Depois de confirmar, ela roda sem novas perguntas até o resumo final." -ForegroundColor DarkGray
    Write-Host ""

    if (Test-WinForgeGuiPrompts) {
        # Na interface gráfica o clique deliberado em um botão substitui a digitação da palavra de segurança.
        $start = Read-WinForgeChoice -Message "Iniciar a fase automática?" -Options @(
            @{ Key = "S"; Label = "Iniciar fase automática"; Accent = $true },
            @{ Key = "N"; Label = "Cancelar" }
        )

        return ($start -eq "S")
    }

    $typedText = Read-WinForgeText -Message "Digite WINFORGE para iniciar"
    return ($typedText.ToUpperInvariant() -eq "WINFORGE")
}


# ---------------------------------------------------------------------------
# Fase 5: etapas automáticas
# ---------------------------------------------------------------------------

function Invoke-WinForgeMaintenanceStepAction {
    param (
        [Parameter(Mandatory)]
        [string]$Id,

        [Parameter(Mandatory)]
        $Details
    )

    switch ($Id) {
        "restore-point" { Invoke-WinForgeRestorePoint -Embedded -PassThru }
        "network"       { Invoke-WinForgeNetworkRepair -Embedded -PassThru }
        "cleanup"       { Invoke-WinForgeQuickCleanup -Embedded -PassThru }
        "repair"        { Invoke-WinForgeDismAndSfc -CheckFirst -Embedded -PassThru }
        "chkdsk"        { Start-WinForgeChkdsk -DeferRepairPrompt -Embedded -PassThru }
        "winget" {
            Enter-WinForgeAction -Title "Atualizar programas (winget)" -Embedded

            if ($null -eq $Details.WingetPlan) {
                Write-WinForgeStatus -Type Info -Message "As atualizações do winget não foram revisadas nesta execução."
                New-WinForgeResult -Kind Skipped -Detail "não revisado"
            }
            else {
                Invoke-WinForgeWingetUpgradePlan -Plan $Details.WingetPlan
            }
        }
        "drivers"       { Invoke-WinForgeDeviceScan -Embedded -PassThru }
        "security"      { Invoke-WinForgeSecurityCheck -Embedded -PassThru }
        "optimize"      { Start-WinForgeDriveOptimization -Embedded -PassThru }
        "tweaks"        { Invoke-WinForgeRecommendedTweaks -Ids @($Details.TweakIds) -Embedded -PassThru }
        default         { throw "Etapa desconhecida: $Id" }
    }
}


function Invoke-WinForgeMaintenanceStep {
    # Roda uma etapa e devolve exatamente um WinForge.Result, aconteça o que acontecer dentro dela.
    param (
        [Parameter(Mandatory)]
        $Step,

        [Parameter(Mandatory)]
        $Details,

        [int]$Position,
        [int]$Total
    )

    Write-Host ""
    Write-WinForgeProgress -Current ($Position - 1) -Total $Total -Label "Próxima: $($Step.Title)"

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $result = $null

    try {
        $output = @(Invoke-WinForgeMaintenanceStepAction -Id $Step.Id -Details $Details)

        $results = @($output | Where-Object { $null -ne $_ -and $_.PSObject.TypeNames -contains "WinForge.Result" })
        $others = @($output | Where-Object { $null -ne $_ -and -not ($_.PSObject.TypeNames -contains "WinForge.Result") })

        # Texto ou objetos soltos de uma etapa aparecem na tela, mas nunca entram no resumo.
        if ($others.Count -gt 0) {
            $others | Out-Host
        }

        if ($results.Count -gt 0) {
            $result = $results[$results.Count - 1]
        }
        else {
            $result = New-WinForgeResult -Kind Ok
        }
    }
    catch {
        Write-Host ""
        Write-WinForgeStatus -Type Error -Message "Falha nesta etapa ($($Step.Title)): $($_.Exception.Message)"
        Write-Host "      O WinForge continuará para a próxima etapa." -ForegroundColor DarkGray
        $result = New-WinForgeResult -Kind Failed -Detail $_.Exception.Message
    }

    $stopwatch.Stop()

    $result.Etapa = $Step.Title
    $result.Duracao = Format-WinForgeDuration -Span $stopwatch.Elapsed
    Add-Member -InputObject $result -NotePropertyName "StepId" -NotePropertyValue $Step.Id -Force

    return $result
}


function Invoke-WinForgeAutomaticPhase {
    param (
        [Parameter(Mandatory)]
        [string[]]$StepIds,

        [Parameter(Mandatory)]
        $Details
    )

    $catalog = @(Get-WinForgeMaintenancePlanItems | Where-Object { $_.Phase -eq "Auto" })
    $steps = @($catalog | Where-Object { $StepIds -contains $_.Id })
    $results = @()

    # Impede que o Windows suspenda o PC no meio de DISM, SFC e CHKDSK.
    [void](Set-WinForgeKeepAwake -Enabled $true)

    try {
        $position = 0

        foreach ($step in $steps) {
            $position++
            $results += @(Invoke-WinForgeMaintenanceStep -Step $step -Details $Details -Position $position -Total $steps.Count)
        }
    }
    finally {
        [void](Set-WinForgeKeepAwake -Enabled $false)
    }

    Write-Host ""
    Write-WinForgeProgress -Current $steps.Count -Total $steps.Count -Label "Concluído"

    return @($results)
}


# ---------------------------------------------------------------------------
# Antes e depois
# ---------------------------------------------------------------------------

function Get-WinForgeMaintenanceSnapshot {
    # Uma foto do PC para comparar o começo com o fim da manutenção: espaço livre no disco do sistema e quantos
    # programas abrem junto com o Windows. O que não puder ser lido fica $null e some da comparação.
    $freeBytes = $null
    $startupItems = $null

    try {
        $space = Get-WinForgeSystemDriveSpace
        if ($null -ne $space) { $freeBytes = [int64]$space.FreeBytes }
    }
    catch {
        $freeBytes = $null
    }

    try {
        $startupItems = [int]@(Get-WinForgeStartupItems | Where-Object { $_.Enabled }).Count
    }
    catch {
        $startupItems = $null
    }

    return [PSCustomObject]@{ At = (Get-Date); FreeBytes = $freeBytes; StartupItems = $startupItems }
}


function Format-WinForgeSignedBytes {
    # "+11,5 GB" / "-2 GB"; menos de 1 MB de diferença conta como "sem mudança".
    param ([int64]$Delta)

    if ([math]::Abs($Delta) -lt 1MB) {
        return "sem mudança"
    }

    $sign = $(if ($Delta -gt 0) { "+" } else { "-" })

    return "$sign$(Format-WinForgeBytes -Bytes ([math]::Abs($Delta)))"
}


function Get-WinForgeSnapshotComparison {
    # As linhas "antes e depois" (Label e Text) entre duas fotos. Linha cujo dado falta em uma das fotos não aparece.
    param (
        $Before,
        $After
    )

    $rows = @()

    if ($null -eq $Before -or $null -eq $After) {
        return @()
    }

    if ($null -ne $Before.FreeBytes -and $null -ne $After.FreeBytes) {
        $rows += [PSCustomObject]@{
            Label = "Espaço livre no disco do sistema"
            Text  = "de $(Format-WinForgeBytes -Bytes $Before.FreeBytes) para $(Format-WinForgeBytes -Bytes $After.FreeBytes) ($(Format-WinForgeSignedBytes -Delta ([int64]$After.FreeBytes - [int64]$Before.FreeBytes)))"
        }
    }

    if ($null -ne $Before.StartupItems -and $null -ne $After.StartupItems) {
        $delta = [int]$After.StartupItems - [int]$Before.StartupItems
        $change = $(if ($delta -eq 0) { "sem mudança" } elseif ($delta -gt 0) { "+$delta" } else { "$delta" })

        $rows += [PSCustomObject]@{
            Label = "Programas que abrem com o Windows"
            Text  = "de $($Before.StartupItems) para $($After.StartupItems) ($change)"
        }
    }

    return @($rows)
}


# ---------------------------------------------------------------------------
# Resumo e encerramento
# ---------------------------------------------------------------------------

function Show-WinForgeMaintenanceSummary {
    param (
        [object[]]$Results,
        [datetime]$StartedAt,

        # Fotos do PC no começo e no fim da manutenção (Get-WinForgeMaintenanceSnapshot); sem elas não há comparação.
        $Before = $null,
        $After = $null
    )

    Write-WinForgeSection -Title "Resumo"

    # Só resultados formais de etapa compõem a tabela.
    $summaryResults = @($Results | Where-Object { $null -ne $_ -and $null -ne $_.PSObject.Properties["Etapa"] -and $null -ne $_.PSObject.Properties["Status"] })

    Write-WinForgeResultTable -Results $summaryResults
    Set-WinForgeLastMaintenance -Results $summaryResults -StartedAt $StartedAt -Before $Before -After $After

    $comparison = @(Get-WinForgeSnapshotComparison -Before $Before -After $After)

    if ($comparison.Count -gt 0) {
        Write-WinForgeSection -Title "Antes e depois"

        foreach ($row in $comparison) {
            Write-WinForgeKeyValue -Label $row.Label -Value $row.Text -LabelWidth 34
        }
    }

    $failed = @($summaryResults | Where-Object { $_.Kind -eq "Failed" })
    $warned = @($summaryResults | Where-Object { $_.Kind -eq "Warning" })

    Write-Host ""

    if ($failed.Count -gt 0) {
        Write-WinForgeStatus -Type Warning -Message "$($failed.Count) etapa(s) falharam e $($warned.Count) terminaram com ressalvas. Revise a saída acima ou o log."
    }
    elseif ($warned.Count -gt 0) {
        Write-WinForgeStatus -Type Warning -Message "$($warned.Count) etapa(s) terminaram com ressalvas."
    }
    else {
        Write-WinForgeStatus -Type Success -Message "Todas as etapas automáticas foram concluídas."
    }

    Write-WinForgeStatus -Type Info -Message "Tempo total: $(Format-WinForgeDuration -Span ((Get-Date) - $StartedAt))."

    $logPath = Get-WinForgeLogPath

    if (-not [string]::IsNullOrWhiteSpace($logPath)) {
        Write-WinForgeStatus -Type Info -Message "Log desta sessão: $logPath"
    }
}


function Test-WinForgeMaintenanceNeedsRestart {
    param (
        [object[]]$Results,
        [bool]$ChkdskScheduled
    )

    if ($ChkdskScheduled) {
        return $true
    }

    if (Test-WinForgePendingReboot) {
        return $true
    }

    foreach ($result in @($Results)) {
        if ($null -eq $result) { continue }

        # Os resets de Winsock e TCP/IP só valem após reiniciar.
        if ($result.StepId -eq "network" -and $result.Kind -in @("Ok", "Warning")) {
            return $true
        }

        # DISM, SFC e outras etapas avisam por Data quando uma correção só termina depois de reiniciar.
        if (Test-WinForgeResultFlag -Result $result -Name "RebootRequired") {
            return $true
        }
    }

    return $false
}


function Request-WinForgeRestart {
    param (
        [switch]$ChkdskScheduled
    )

    Write-WinForgeSection -Title "Reinicialização"
    Write-Host "Para concluir a manutenção, é recomendado reiniciar o Windows." -ForegroundColor Yellow

    if ($ChkdskScheduled) {
        Write-Host "O CHKDSK agendado será executado antes do Windows iniciar e pode demorar." -ForegroundColor Yellow
    }

    Write-Host "Antes de confirmar, salve seus arquivos e feche os demais aplicativos." -ForegroundColor Yellow
    Write-Host ""

    if (-not (Confirm-WinForgeAction "Deseja reiniciar o Windows agora?" -DefaultKey N)) {
        Write-WinForgeStatus -Type Info -Message "Reinicialização não iniciada. Reinicie depois para concluir a manutenção."
        return $false
    }

    $run = Invoke-WinForgeCapture -FilePath "shutdown.exe" -Arguments @("/r", "/t", "30", "/c", "Reinicialização solicitada pelo WinForge após a manutenção recomendada.")

    if ($run.ExitCode -ne 0) {
        Write-WinForgeStatus -Type Error -Message "Não foi possível agendar a reinicialização (código $($run.ExitCode)): $($run.Text.Trim())"
        return $false
    }

    Write-WinForgeStatus -Type Success -Message "O Windows reiniciará em 30 segundos."

    $answer = Read-WinForgeChoice -Message "Reinício agendado. Deseja cancelá-lo?" `
        -TextPrompt "Digite C para cancelar o reinício ou ENTER para aguardar" `
        -DefaultKey "A" -Options @(
            @{ Key = "A"; Label = "Aguardar o reinício"; Accent = $true },
            @{ Key = "C"; Label = "Cancelar o reinício" }
        )

    if ($answer -eq "C") {
        [void](Invoke-WinForgeCapture -FilePath "shutdown.exe" -Arguments @("/a"))
        Write-WinForgeStatus -Type Warning -Message "Reinício cancelado. Reinicie manualmente depois."
        return $false
    }

    return $true
}


function Invoke-WinForgeMaintenanceClosing {
    param (
        [object[]]$Results,
        $Details,
        [string[]]$StepIds
    )

    # O reparo offline do CHKDSK só é oferecido se a verificação rodou nesta manutenção.
    $chkdskScheduled = $false

    if ($StepIds -contains "chkdsk" -and (Test-WinForgeChkdskRepairPending)) {
        Write-WinForgeSection -Title "CHKDSK"
        Write-WinForgeStatus -Type Warning -Message "A verificação encontrou itens que exigem reparo offline na próxima inicialização."
        Write-Host "      Esse reparo pode levar de minutos a horas, principalmente em HDD." -ForegroundColor DarkGray
        Write-Host ""

        if (Confirm-WinForgeAction "Deseja agendar o reparo do CHKDSK para a próxima reinicialização?" -DefaultKey N) {
            $chkdskScheduled = [bool](Invoke-WinForgeScheduleChkdskRepair)
        }
    }

    if (@($Results).Count -gt 0) {
        Write-Host ""

        if (Confirm-WinForgeAction "Deseja salvar um relatório desta manutenção?" -DefaultKey S) {
            try {
                $report = Export-WinForgeReport
                Write-WinForgeStatus -Type Success -Message "Relatório salvo em: $($report.Html)"
            }
            catch {
                Write-WinForgeStatus -Type Warning -Message "Não foi possível salvar o relatório: $($_.Exception.Message)"
            }
        }
    }

    Write-Host ""

    if (Test-WinForgeMaintenanceNeedsRestart -Results $Results -ChkdskScheduled $chkdskScheduled) {
        $restarting = Request-WinForgeRestart -ChkdskScheduled:$chkdskScheduled

        if (-not $restarting) {
            Invoke-WinForgeExplorerRestartOffer -Results $Results -Details $Details
        }
    }
    else {
        Write-WinForgeStatus -Type Success -Message "Nenhuma reinicialização é necessária."
        Invoke-WinForgeExplorerRestartOffer -Results $Results -Details $Details
    }
}


function Invoke-WinForgeExplorerRestartOffer {
    # Extensões de arquivo e itens ocultos só aparecem quando o Explorador reinicia; sem reinício do Windows, oferece só isso.
    param (
        [object[]]$Results,
        $Details
    )

    $tweaksApplied = @($Results | Where-Object { $_.StepId -eq "tweaks" -and $_.Kind -in @("Ok", "Warning") }).Count -gt 0

    if (-not $tweaksApplied -or $null -eq $Details) {
        return
    }

    $needsExplorer = @(
        @($Details.TweakIds) |
            ForEach-Object { Get-WinForgeTweakById -Id $_ } |
            Where-Object { $null -ne $_ -and $_.RestartExplorer }
    ).Count -gt 0

    if ($needsExplorer -and (Confirm-WinForgeAction "Reiniciar o Explorador de Arquivos agora para ver os ajustes?" -DefaultKey S)) {
        try {
            Restart-WinForgeExplorerShell
            Write-WinForgeStatus -Type Success -Message "Explorador reiniciado."
        }
        catch {
            Write-WinForgeStatus -Type Error -Message "Não foi possível reiniciar o Explorador: $($_.Exception.Message)"
        }
    }
}


# ---------------------------------------------------------------------------
# Ação principal
# ---------------------------------------------------------------------------

function Invoke-WinForgeRecommendedMaintenance {
    Enter-WinForgeAction -Title "Manutenção recomendada"

    if (-not (Test-WinForgeElevation -Reason "A manutenção recomendada exige privilégios de Administrador.")) {
        Exit-WinForgeAction
        return
    }

    $cancelled = {
        Write-Host ""
        Write-WinForgeStatus -Type Warning -Message "Manutenção cancelada."
        Exit-WinForgeAction
    }

    # Fase 1: preparação
    if (-not (Confirm-WinForgeMaintenancePreflight)) {
        & $cancelled
        return
    }

    # Fase 2: plano
    $selected = Read-WinForgeMaintenancePlan

    # Cancelar a lista e não marcar nada são a mesma resposta: não há o que fazer.
    if ($null -eq $selected -or @($selected).Count -eq 0) {
        & $cancelled
        return
    }

    $items = @(Get-WinForgeMaintenancePlanItems)
    $beforeItems = @($items | Where-Object { $_.Phase -eq "Before" -and $selected -contains $_.Id })
    $afterItems = @($items | Where-Object { $_.Phase -eq "After" -and $selected -contains $_.Id })
    $autoIds = @($items | Where-Object { $_.Phase -eq "Auto" -and $selected -contains $_.Id } | ForEach-Object { $_.Id })

    $results = @()
    $details = $null

    # A foto do "antes" vem antes da revisão manual: desativar programas da inicialização também conta.
    $before = Get-WinForgeMaintenanceSnapshot

    # Fase 3: revisão manual (antes de decidir as atualizações, porque desinstalar muda a lista do winget)
    if ($beforeItems.Count -gt 0) {
        Write-WinForgeSection -Title "Revisão manual"
        Invoke-WinForgeManualPhase -Items $beforeItems
    }

    if ($autoIds.Count -gt 0) {
        # Fase 4: detalhes das etapas escolhidas
        $details = Read-WinForgeMaintenanceDetails -AutoIds $autoIds

        if (-not (Confirm-WinForgeAutomaticPhase -StepCount $autoIds.Count)) {
            & $cancelled
            return
        }

        # Fase 5: automática
        [void](Start-WinForgeLogging)
        $startedAt = Get-Date

        $results = @(Invoke-WinForgeAutomaticPhase -StepIds $autoIds -Details $details)
        Show-WinForgeMaintenanceSummary -Results $results -StartedAt $startedAt -Before $before -After (Get-WinForgeMaintenanceSnapshot)
    }

    # Fase 6: atualizações e revisão do que sobrou
    if ($afterItems.Count -gt 0) {
        Write-WinForgeSection -Title "Etapas manuais finais"
        Invoke-WinForgeManualPhase -Items $afterItems
    }

    # Fase 7: encerramento
    Invoke-WinForgeMaintenanceClosing -Results $results -Details $details -StepIds $autoIds

    Write-Host ""
    Write-WinForgeStatus -Type Success -Message "Manutenção recomendada finalizada."

    Exit-WinForgeAction
}


Export-ModuleMember -Function *
