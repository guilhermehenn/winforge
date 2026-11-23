# Monitor na bandeja: um ícone perto do relógio que fica de olho no PC e avisa quando algo pede atenção.
#
# O monitor é o WinForge.Agent.ps1, na pasta do WinForge. Ele começa com o Windows (uma entrada em Run, do usuário) e só
# lê: espaço no disco, disco com sinais de falha, proteção, reinício pendente, manutenção, suporte do Windows, programas
# desatualizados e o resultado do teste de memória, quando ele foi pedido. Cada aviso
# aparece no máximo uma vez a cada tanto tempo (veja Get-WinForgeAgentChecks) e pode ser pausado por 24 horas no menu do
# ícone. Este módulo tem as regras (o que avisar e quando) e o liga/desliga; o script cuida do ícone.

$script:WinForgeAgentRunKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
$script:WinForgeAgentRunName = "WinForge Monitor"
# Onde o Gerenciador de Tarefas (aba Inicializar) marca uma entrada de Run como desativada.
$script:WinForgeAgentApprovedKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run"
$script:WinForgeAgentStopEvent = "Local\WinForge.Agent.Stop"
# Quanto tempo esperar o monitor aparecer depois de pedir a abertura.
$script:WinForgeAgentStartWaitSeconds = 8


function Get-WinForgeAgentActionIds {
    # As ações que o monitor pede à janela: as do menu do ícone e as dos avisos. A janela só roda estas quando o pedido
    # chega de outra abertura (Receive-WinForgeWindowRequest).
    # app.monitor (Configurar o monitor) e cleanup.custom (Limpeza personalizada, do aviso de pouco espaço) só mostram a
    # tela de escolha, e app.update (Verificar nova versão, do aviso da versão nova) só consulta e pergunta antes de
    # baixar: nada muda sem um clique nelas.
    return @("performance.boost", "cleanup.quick", "cleanup.custom", "maintenance.checkup", "diagnostics.pending-reboot", "security.status", "diagnostics.windows-support", "updates.winget", "app.monitor", "diagnostics.disk-health", "diagnostics.memory-test", "diagnostics.blue-screens", "app.update")
}


function Get-WinForgeAgentScriptPath {
    # O script do monitor desta pasta do WinForge (-Root: de outra, como a que o instalador acabou de atualizar).
    param ([string]$Root = (Get-WinForgeAppRoot))

    return (Join-Path $Root "WinForge.Agent.ps1")
}


function Get-WinForgeAgentStopEventName {
    return $script:WinForgeAgentStopEvent
}


function Get-WinForgeAgentCommandLine {
    # A linha que o Windows roda ao entrar: o PowerShell, oculto, com o script do monitor (-Root: o de outra pasta do
    # WinForge, como a que o instalador acabou de criar).
    param ([string]$Root = (Get-WinForgeAppRoot))

    $script = Get-WinForgeAgentScriptPath -Root $Root

    return "$(ConvertTo-WinForgeCommandLineArgument -Value (Get-WinForgePowerShellPath)) -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File $(ConvertTo-WinForgeCommandLineArgument -Value $script)"
}


function Get-WinForgeAgentRunState {
    <#
    Se o monitor começa com o Windows: On; Off (sem a entrada); Elsewhere (a entrada aponta para outra pasta do WinForge,
    ou para um script que não existe mais: a pasta mudou de lugar); Disabled (desativado no Gerenciador de Tarefas, aba
    Inicializar: o Windows não roda a entrada).
    #>
    $value = [string](Get-WinForgeRegistryValueOrNull -Path $script:WinForgeAgentRunKey -Name $script:WinForgeAgentRunName)

    if ([string]::IsNullOrWhiteSpace($value)) { return "Off" }

    $script = Get-WinForgeAgentScriptPath

    if ($value.IndexOf($script, [StringComparison]::OrdinalIgnoreCase) -lt 0 -or -not (Test-Path -LiteralPath $script -PathType Leaf)) {
        return "Elsewhere"
    }

    # O primeiro byte ímpar (03, 07) é "desativado"; par (02, 06) ou sem o valor, "ativado".
    $approved = Get-WinForgeRegistryValueOrNull -Path $script:WinForgeAgentApprovedKey -Name $script:WinForgeAgentRunName

    $first = $(if ($null -ne $approved) { @($approved)[0] } else { $null })

    if ($first -is [byte] -and ($first -band 1) -eq 1) { return "Disabled" }

    return "On"
}


function Test-WinForgeAgentEnabled {
    # Se o monitor de fato começa com o Windows (a entrada existe, aponta para esta pasta e não foi desativada).
    return ((Get-WinForgeAgentRunState) -eq "On")
}


function Get-WinForgeAgentProcesses {
    # Os processos do monitor que estão rodando agora nesta sessão do Windows (pela linha de comando). Lista vazia se não
    # der para ler. Os monitores de outras contas logadas (troca rápida de usuário) não são deste usuário: ligar, abrir e
    # desligar nunca mexem neles.
    try {
        $session = [System.Diagnostics.Process]::GetCurrentProcess().SessionId

        return @(Get-CimInstance -ClassName Win32_Process -Filter "Name = 'powershell.exe' OR Name = 'pwsh.exe'" -OperationTimeoutSec 15 -ErrorAction Stop |
                Where-Object { [string]$_.CommandLine -like "*WinForge.Agent.ps1*" -and [int](Get-WinForgeJsonValue -Object $_ -Name "SessionId" -Default $session) -eq $session })
    }
    catch {
        return @()
    }
}


function Test-WinForgeAgentStartBlocked {
    # Se o monitor não deve ser ligado nem aberto daqui: com a conta de outro Administrador, ele ficaria no perfil dessa
    # conta. Na janela elevada da própria conta, ele abre sem a elevação (Start-WinForgeAgent).
    return [bool](Test-WinForgeUserContextMismatch)
}


function Start-WinForgeAgent {
    <#
    Abre o monitor agora (o próprio script recusa uma segunda cópia) e devolve se ele apareceu em alguns segundos. O monitor
    nunca roda como Administrador: aberto direto da janela elevada, ele herdaria a elevação até o fim da sessão (e o "Abrir
    o WinForge" do menu abriria a janela elevada sem perguntar). Por isso, da janela elevada, ele abre por um atalho
    (monitor.lnk, na pasta de dados) entregue ao Explorador, que o abre na sessão da pessoa, sem elevação. Quem chama
    confere Test-WinForgeAgentStartBlocked. Uma falha ao pedir a abertura vira um erro em português. -Root: o monitor de
    outra pasta do WinForge (a que o instalador acabou de atualizar).
    #>
    param ([string]$Root = (Get-WinForgeAppRoot))

    $arguments = "-NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File $(ConvertTo-WinForgeCommandLineArgument -Value (Get-WinForgeAgentScriptPath -Root $Root))"

    try {
        if (Test-WinForgeAdministrator) {
            $link = Join-Path (Get-WinForgeDataPath) "monitor.lnk"
            [void](Save-WinForgeShortcutFile -Path $link -Target (Get-WinForgePowerShellPath) -Arguments $arguments -WorkingDirectory $Root -Description (Get-WinForgeText 'Monitor do WinForge'))
            Start-Process -FilePath "explorer.exe" -ArgumentList "`"$link`"" -ErrorAction Stop
        }
        else {
            Start-Process -FilePath (Get-WinForgePowerShellPath) -ArgumentList $arguments -WindowStyle Hidden -ErrorAction Stop
        }
    }
    catch {
        throw (Get-WinForgeText 'o Windows não deixou abrir o monitor agora')
    }

    # O Explorador abre o atalho por conta própria, um instante depois: confere por alguns segundos se o monitor apareceu e
    # continuou aberto por 2 segundos. Um monitor que abriu elevado (o Explorador não fez a troca) fecha sozinho logo no
    # começo (WinForge.Agent.ps1), e aí a tela diz que ele abre com o Windows, e não "ligado".
    $seen = 0

    for ($i = 0; $i -lt ($script:WinForgeAgentStartWaitSeconds * 2); $i++) {
        if (@(Get-WinForgeAgentProcesses).Count -gt 0) { $seen++ } else { $seen = 0 }
        if ($seen -ge 4) { return $true }
        Start-Sleep -Milliseconds 500
    }

    return $false
}


function Stop-WinForgeAgent {
    # Pede ao monitor que feche (pelo evento que ele escuta) e, se ele não fechar em alguns segundos, encerra o processo.
    try {
        $signal = [System.Threading.EventWaitHandle]::OpenExisting($script:WinForgeAgentStopEvent)
        [void]$signal.Set()
        $signal.Dispose()
    }
    catch {
        Write-Verbose "O monitor não estava escutando: $($_.Exception.Message)"
    }

    for ($i = 0; $i -lt 10; $i++) {
        if (@(Get-WinForgeAgentProcesses).Count -eq 0) { return $true }
        Start-Sleep -Milliseconds 500
    }

    foreach ($process in @(Get-WinForgeAgentProcesses)) {
        Stop-Process -Id ([int]$process.ProcessId) -Force -ErrorAction SilentlyContinue
    }

    # Um monitor aberto como Administrador não fecha a pedido de uma janela sem elevação: quem chama diz isso.
    return (@(Get-WinForgeAgentProcesses).Count -eq 0)
}


function Enable-WinForgeAgent {
    <#
    Grava a entrada em Run (e tira a marca de "desativado" do Gerenciador de Tarefas, se houver) e abre o monitor. Devolve
    "Open" (aberto agora, ou já estava), "Later" (pedido, mas o ícone não apareceu em alguns segundos: abre com o Windows),
    "Blocked" (com a conta de outro Administrador: só fica configurado) ou "StartFailed" (configurado, mas o Windows não
    deixou abrir agora). Sem conseguir gravar a entrada, lança um erro em português e nada muda.
    #>
    if (-not (Test-Path -LiteralPath (Get-WinForgeAgentScriptPath) -PathType Leaf)) {
        throw (Get-WinForgeText 'o arquivo WinForge.Agent.ps1 não está na pasta do WinForge')
    }

    # O Windows não roda uma entrada de Run com 260 caracteres ou mais.
    $line = Get-WinForgeAgentCommandLine

    if ($line.Length -ge 260) {
        throw (Get-WinForgeText 'o caminho da pasta do WinForge é longo demais para o Windows abrir o monitor sozinho; mova a pasta do WinForge para um caminho mais curto')
    }

    # -ErrorAction Stop nos dois: sem ele, uma chave que não pode ser criada só escrevia um erro do Windows (em inglês) na
    # tela, e a gravação seguinte falhava com outro.
    try {
        if (-not (Test-Path -LiteralPath $script:WinForgeAgentRunKey)) {
            [void](New-Item -Path $script:WinForgeAgentRunKey -Force -ErrorAction Stop)
        }

        Set-ItemProperty -LiteralPath $script:WinForgeAgentRunKey -Name $script:WinForgeAgentRunName -Value $line -Type String -ErrorAction Stop
    }
    catch {
        throw (Get-WinForgeText 'o Windows não deixou gravar a entrada que faz o monitor abrir com o Windows')
    }

    # Desativado antes no Gerenciador de Tarefas, o Windows continuaria sem rodar a entrada.
    try { Remove-WinForgeRegistryValue -Path $script:WinForgeAgentApprovedKey -Name $script:WinForgeAgentRunName } catch { Write-Verbose "Marca de inicialização: $($_.Exception.Message)" }

    # Um monitor aberto de outra pasta do WinForge (a cópia antiga) seguiria abrindo a janela antiga até sair do Windows.
    $running = @(Get-WinForgeAgentProcesses)
    $script = Get-WinForgeAgentScriptPath

    if ($running.Count -gt 0 -and @($running | Where-Object { ([string]$_.CommandLine).IndexOf($script, [StringComparison]::OrdinalIgnoreCase) -ge 0 }).Count -gt 0) { return "Open" }
    if (Test-WinForgeAgentStartBlocked) { return "Blocked" }
    if ($running.Count -gt 0) { [void](Stop-WinForgeAgent) }

    try {
        if (Start-WinForgeAgent) { return "Open" }
    }
    catch {
        return "StartFailed"
    }

    return "Later"
}


function Move-WinForgeAgentEntry {
    <#
    Faz a entrada de início do monitor abrir o da pasta Root quando ela abre o de outra pasta do WinForge (a extraída do
    zip, antes de instalar). A marca de desativado do Gerenciador de Tarefas fica como estava. Devolve se mudou; sem
    conseguir gravar, lança erro.
    #>
    param ([Parameter(Mandatory)][string]$Root)

    $value = [string](Get-WinForgeRegistryValueOrNull -Path $script:WinForgeAgentRunKey -Name $script:WinForgeAgentRunName)
    $script = Get-WinForgeAgentScriptPath -Root $Root

    if ([string]::IsNullOrWhiteSpace($value) -or $value -notmatch '(?i)WinForge\.Agent\.ps1') { return $false }
    if ($value.IndexOf($script, [StringComparison]::OrdinalIgnoreCase) -ge 0) { return $false }
    if (-not (Test-Path -LiteralPath $script -PathType Leaf)) { return $false }

    # O Windows não roda uma entrada de Run com 260 caracteres ou mais (Enable-WinForgeAgent).
    $line = Get-WinForgeAgentCommandLine -Root $Root
    if ($line.Length -ge 260) { return $false }

    Set-ItemProperty -LiteralPath $script:WinForgeAgentRunKey -Name $script:WinForgeAgentRunName -Value $line -Type String -ErrorAction Stop
    return $true
}


function Remove-WinForgeAgentStaleEntry {
    # Tira a entrada de início quando ela aponta para o script dado (a pasta antiga, que não existe mais). Devolve se tirou.
    # -RunKey: a chave Run de outra conta (a de quem usa o PC, com o WinForge elevado pela conta de outro Administrador).
    param (
        [Parameter(Mandatory)][string]$ScriptPath,
        [string]$RunKey = $script:WinForgeAgentRunKey
    )

    $value = [string](Get-WinForgeRegistryValueOrNull -Path $RunKey -Name $script:WinForgeAgentRunName)

    if ([string]::IsNullOrWhiteSpace($value) -or $value.IndexOf($ScriptPath, [StringComparison]::OrdinalIgnoreCase) -lt 0) { return $false }

    Remove-WinForgeRegistryValue -Path $RunKey -Name $script:WinForgeAgentRunName
    return $true
}


function Disable-WinForgeAgent {
    # Devolve se o monitor fechou (ele pode ter sido aberto como Administrador e não aceitar o pedido desta janela). Sem
    # conseguir remover a entrada em Run, lança um erro em português e não fecha o ícone.
    try {
        Remove-WinForgeRegistryValue -Path $script:WinForgeAgentRunKey -Name $script:WinForgeAgentRunName
    }
    catch {
        throw (Get-WinForgeText 'o Windows não deixou remover a entrada que faz o monitor abrir com o Windows')
    }

    try { Remove-WinForgeRegistryValue -Path $script:WinForgeAgentApprovedKey -Name $script:WinForgeAgentRunName } catch { Write-Verbose "Marca de inicialização: $($_.Exception.Message)" }

    return (Stop-WinForgeAgent)
}


# ---------------------------------------------------------------------------
# Regras dos avisos
# ---------------------------------------------------------------------------

function Get-WinForgeAgentChecks {
    # O que o monitor confere, de quanto em quanto tempo (minutos) e o intervalo mínimo entre dois avisos iguais (horas).
    # RepeatHours = 0: o aviso aparece uma vez por leitura que o traz (uma tela azul nova, um resultado do teste de memória,
    # uma versão nova do WinForge), e não de novo a cada volta. Heavy = leitura demorada, feita em segundo plano.
    return @(
        @{ Id = "disk"; EveryMinutes = 15; RepeatHours = 24; Heavy = $false },
        @{ Id = "reboot"; EveryMinutes = 60; RepeatHours = 24; Heavy = $false },
        @{ Id = "maintenance"; EveryMinutes = 360; RepeatHours = 168; Heavy = $false },
        @{ Id = "protection"; EveryMinutes = 60; RepeatHours = 12; Heavy = $true },
        @{ Id = "windows"; EveryMinutes = 1440; RepeatHours = 168; Heavy = $false },
        @{ Id = "programs"; EveryMinutes = 1440; RepeatHours = 72; Heavy = $true },
        @{ Id = "catalog"; EveryMinutes = 1440; RepeatHours = 0; Heavy = $true },
        @{ Id = "diskhealth"; EveryMinutes = 360; RepeatHours = 72; Heavy = $true },
        @{ Id = "memtest"; EveryMinutes = 30; RepeatHours = 0; Heavy = $false },
        @{ Id = "bluescreen"; EveryMinutes = 60; RepeatHours = 0; Heavy = $false },
        @{ Id = "winforge"; EveryMinutes = 360; RepeatHours = 0; Heavy = $true }
    )
}


function Get-WinForgeAgentStatePath {
    return (Join-Path (Get-WinForgeDataPath) "agent.json")
}


function Read-WinForgeAgentState {
    # Quando cada conferência rodou e cada aviso apareceu pela última vez ({ Checked = @{id=data}; Shown = @{id=data} }).
    $state = @{ Checked = @{}; Shown = @{} }

    try {
        $document = (Read-WinForgeStateFile -Path (Get-WinForgeAgentStatePath)).Document
        if ($null -eq $document) { return $state }

        foreach ($section in @("Checked", "Shown")) {
            $values = Get-WinForgeJsonValue -Object $document -Name $section -Default $null
            if ($null -eq $values) { continue }

            foreach ($property in $values.PSObject.Properties) {
                $at = [datetime]::MinValue
                if ([datetime]::TryParse([string]$property.Value, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind, [ref]$at)) {
                    $state[$section][$property.Name] = $at
                }
            }
        }
    }
    catch {
        Write-Verbose "Estado do monitor ilegível: $($_.Exception.Message)"
    }

    return $state
}


function Save-WinForgeAgentState {
    param ([Parameter(Mandatory)][hashtable]$State)

    try {
        $document = [ordered]@{}

        foreach ($section in @("Checked", "Shown")) {
            $values = [ordered]@{}
            foreach ($key in @($State[$section].Keys | Sort-Object)) { $values[$key] = ([datetime]$State[$section][$key]).ToString("o", [System.Globalization.CultureInfo]::InvariantCulture) }
            $document[$section] = $values
        }

        Write-WinForgeStateJson -Path (Get-WinForgeAgentStatePath) -InputObject $document -Depth 4
    }
    catch {
        Write-Verbose "Não foi possível salvar o estado do monitor: $($_.Exception.Message)"
    }
}


function Test-WinForgeAgentDue {
    # Se já passou o tempo desde a última vez (Last ausente = nunca). Uma data mais de um dia no futuro (o relógio estava
    # adiantado quando ela foi gravada) também conta como "na hora": senão o monitor ficaria calado até lá.
    param (
        $Last,
        [double]$Minutes,
        [datetime]$Now = (Get-Date)
    )

    if ($null -eq $Last -or [datetime]$Last -gt $Now.AddDays(1)) { return $true }

    return (($Now - [datetime]$Last).TotalMinutes -ge $Minutes)
}


function Get-WinForgeAgentPausedUntil {
    # Até quando os avisos estão pausados, ou $null. A pausa é de 24 horas: um fim mais longe que isso (gravado com o
    # relógio adiantado) não vale, para o monitor não ficar calado por anos.
    param ([datetime]$Now = (Get-Date))

    $until = [string](Get-WinForgeSetting -Name "AgentPausedUntil" -Default "")
    $at = [datetime]::MinValue

    if ([string]::IsNullOrWhiteSpace($until) -or -not [datetime]::TryParse($until, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind, [ref]$at)) { return $null }

    if ($at -le $Now -or $at -gt $Now.AddHours(25)) { return $null }

    return $at
}


function Test-WinForgeAgentPaused {
    param ([datetime]$Now = (Get-Date))

    return ($null -ne (Get-WinForgeAgentPausedUntil -Now $Now))
}


function Set-WinForgeAgentPause {
    # Pausa os avisos por algumas horas; Hours = 0 retoma.
    param ([int]$Hours = 24)

    $value = $(if ($Hours -gt 0) { (Get-Date).AddHours($Hours).ToString("o", [System.Globalization.CultureInfo]::InvariantCulture) } else { "" })
    [void](Set-WinForgeSetting -Name "AgentPausedUntil" -Value $value)
}


function Format-WinForgeAgentPauseEnd {
    # Até quando a pausa vai, como a pessoa diz: "hoje, às 18:40", "amanhã, às 14:30" (uma pausa de 24 horas sempre
    # termina amanhã; "até 14:30" sozinho parecia hoje). Mais longe que isso, com a data: "09/11, às 08:00".
    param (
        [Parameter(Mandatory)][datetime]$Until,
        [datetime]$Now = (Get-Date)
    )

    $time = Format-WinForgeDateTime -When $Until -Pattern 'HH:mm'

    if ($Until.Date -eq $Now.Date) { return (Get-WinForgeText 'hoje, às {0}' "$time") }
    if ($Until.Date -eq $Now.Date.AddDays(1)) { return (Get-WinForgeText 'amanhã, às {0}' "$time") }

    return (Get-WinForgeText '{0}, às {1}' "$(Format-WinForgeDateTime -When $Until -Pattern 'dd/MM')" "$time")
}


function Get-WinForgeAgentSortedAlerts {
    # Os avisos abertos na ordem em que o monitor os mostra: os mais graves (Warning) primeiro.
    param ([AllowEmptyCollection()][object[]]$Alerts = @())

    return @(@($Alerts | Where-Object { $null -ne $_ }) | Sort-Object @{ Expression = { if ($_.Level -eq "Warning") { 0 } else { 1 } } })
}


function Get-WinForgeAgentTooltip {
    <#
    O texto do ícone ao passar o mouse. O Windows corta em 63 caracteres: um texto maior termina em "...".
    Antes da primeira leitura, "conferindo o PC"; com avisos, o mais grave pelo nome e quantos mais há; pausado, até quando.
    #>
    param (
        [AllowEmptyCollection()][object[]]$Alerts = @(),
        [bool]$FirstReading = $true,
        $PausedUntil = $null,
        [datetime]$Now = (Get-Date)
    )

    $sorted = @(Get-WinForgeAgentSortedAlerts -Alerts $Alerts)

    $text = $(
        if ($null -ne $PausedUntil) { (Get-WinForgeText 'WinForge: avisos pausados até {0}' "$(Format-WinForgeAgentPauseEnd -Until ([datetime]$PausedUntil) -Now $Now)") }
        elseif (-not $FirstReading) { (Get-WinForgeText 'WinForge: conferindo o PC...') }
        elseif ($sorted.Count -eq 0) { (Get-WinForgeText 'WinForge: nada pedindo atenção') }
        elseif ($sorted.Count -eq 1) { "WinForge: $($sorted[0].Title)" }
        else { (Get-WinForgeText 'WinForge: {0} e mais {1}' "$($sorted[0].Title)" "$(Format-WinForgeCount -Count ($sorted.Count - 1) -One (Get-WinForgeText 'aviso') -Many (Get-WinForgeText 'avisos'))") }
    )

    if ($text.Length -gt 63) { $text = $text.Substring(0, 60).TrimEnd() + "..." }

    return $text
}


function Get-WinForgeAgentPauseNotice {
    # O balão que confirma a pausa: até quando e como retomar antes.
    param (
        [Parameter(Mandatory)][datetime]$Until,
        [datetime]$Now = (Get-Date)
    )

    return (Get-WinForgeText 'O WinForge volta a avisar {0}. Para retomar antes, use o menu do ícone.' "$(Format-WinForgeAgentPauseEnd -Until $Until -Now $Now)")
}


function New-WinForgeAgentAlert {
    # Quiet: o aviso fica no menu do ícone e no texto dele, sem balão (a versão nova do WinForge que o balão já mostrou).
    param (
        [Parameter(Mandatory)][string]$Id,
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][string]$Text,
        [string]$Action = "",
        [ValidateSet("Info", "Warning")][string]$Level = "Warning",
        [switch]$Quiet
    )

    return [PSCustomObject]@{ Id = $Id; Title = $Title; Text = $Text; Action = $Action; Level = $Level; Quiet = [bool]$Quiet }
}


function Get-WinForgeAgentReading {
    <#
    Lê uma das conferências e devolve o aviso que ela pede, ou $null se está tudo bem. Nunca lança erro: uma leitura que
    falha não avisa nada (o monitor não pode virar uma fonte de alarmes falsos).
    #>
    param ([Parameter(Mandatory)][string]$Id)

    try {
        switch ($Id) {
            "disk" {
                $space = Get-WinForgeSystemDriveSpace
                if ($null -eq $space) { return $null }

                $level = Get-WinForgeDiskSpaceLevel -FreeBytes $space.FreeBytes -TotalBytes $space.TotalBytes
                if ($level -notin @("Low", "Critical")) { return $null }

                # O disco pelo nome que a pessoa vê no Explorador (C:), e qual é: o do Windows. O clique abre a Limpeza
                # personalizada, como o "Liberar espaço" do Início: ela mede tudo o que dá para tirar, e não só os temporários.
                $drive = $(if ([string]$env:SystemRoot -match '^([A-Za-z]:)') { $Matches[1].ToUpperInvariant() } else { "C:" })

                return (New-WinForgeAgentAlert -Id "disk" -Title (Get-WinForgeText 'Pouco espaço no disco {0}' "$drive") -Text (Get-WinForgeText 'Restam {0} livres no disco do Windows ({1}). Clique para ver o que dá para apagar.' "$(Format-WinForgeBytes -Bytes $space.FreeBytes)" "$drive") -Action "cleanup.custom")
            }
            "reboot" {
                if (-not (Test-WinForgePendingReboot)) { return $null }

                return (New-WinForgeAgentAlert -Id "reboot" -Title (Get-WinForgeText 'Reinício pendente') -Text (Get-WinForgeText 'O Windows espera o PC reiniciar para terminar uma atualização ou mudança. Clique para ver o motivo.') -Action "diagnostics.pending-reboot" -Level Info)
            }
            "maintenance" {
                # A mesma conta do Início (Get-WinForgeLastCare): uma data no futuro não cala o lembrete. Registros que
                # existem, mas não puderam ser lidos, não viram "ainda não verificou": sem leitura, sem aviso.
                $latest = $null

                try { $latest = (Get-WinForgeLastCare -Strict).Latest }
                catch { return $null }

                if ($null -ne $latest -and ((Get-Date) - $latest).TotalDays -lt 30) { return $null }

                # Sem nenhuma verificação ainda, "faz mais de um mês" não seria verdade (como no Início: "ainda não verificado").
                $text = $(if ($null -eq $latest) { (Get-WinForgeText 'O WinForge ainda não verificou este PC. Clique para verificar.') } else { (Get-WinForgeText 'Faz mais de um mês sem verificação. Clique para verificar o PC.') })

                return (New-WinForgeAgentAlert -Id "maintenance" -Title (Get-WinForgeText 'Hora de cuidar do PC') -Text $text -Action "maintenance.checkup" -Level Info)
            }
            "protection" {
                $protection = Get-WinForgeSecurityStatus
                if ($null -eq $protection) { return $null }

                $antivirus = $protection.Antivirus

                if ($null -ne $protection.Threats -and @($protection.Threats).Count -gt 0) {
                    return (New-WinForgeAgentAlert -Id "protection" -Title (Get-WinForgeText 'Ameaça encontrada') -Text (Get-WinForgeText 'O antivírus encontrou uma ameaça que ainda está ativa. Clique para ver.') -Action "security.status")
                }

                if ($antivirus.Mode -eq "Off") {
                    return (New-WinForgeAgentAlert -Id "protection" -Title (Get-WinForgeText 'PC sem antivírus ativo') -Text (Get-WinForgeText 'Nenhum antivírus está protegendo o PC. Clique para ver.') -Action "security.status")
                }

                if ($antivirus.Mode -eq "Active" -and $antivirus.RealTime -eq $false) {
                    return (New-WinForgeAgentAlert -Id "protection" -Title (Get-WinForgeText 'Proteção em tempo real desligada') -Text (Get-WinForgeText 'O Windows Defender não está vigiando os arquivos abertos. Clique para ver.') -Action "security.status")
                }

                return $null
            }
            "windows" {
                $support = Get-WinForgeWindowsSupportStatus
                $issue = Get-WinForgeWindowsSupportIssue -Status $support

                if ($null -eq $issue -or $support.State -eq "Esu") { return $null }

                # Uma leitura que não confirmou o ESU não vira aviso: o monitor só avisa do que sabe.
                if ($support.State -eq "EsuAvailable" -and -not [bool](Get-WinForgeJsonValue -Object $support -Name "EsuChecked" -Default $true)) { return $null }

                # Sem atualizações de segurança (o ponto grave da nota) o título diz isso; perto do fim, só "Suporte do Windows".
                $title = $(if ([int]$issue.Weight -ge 20) { (Get-WinForgeText 'Windows sem atualizações de segurança') } else { (Get-WinForgeText 'Suporte do Windows') })

                return (New-WinForgeAgentAlert -Id "windows" -Title $title -Text (Get-WinForgeText '{0}. Clique para ver o que fazer.' "$($issue.Text)") -Action "diagnostics.windows-support")
            }
            "programs" {
                # Numa conexão limitada (plano de dados) ou na bateria, o monitor não consulta a internet por conta própria.
                if ((Test-WinForgeMeteredConnection) -or (Test-WinForgeOnBattery)) { return $null }
                if (-not (Test-WinForgeWinget)) { return $null }

                $upgrade = Invoke-WinForgeCapture -FilePath "winget" -Arguments @("upgrade", "--accept-source-agreements")

                if (Test-WinForgeWingetNoUpgradeOutput -OutputText $upgrade.Text -ExitCode $upgrade.ExitCode) { return $null }

                $count = @(ConvertFrom-WinForgeWingetTable -Lines $upgrade.Lines).Count
                if ($count -lt 3) { return $null }

                return (New-WinForgeAgentAlert -Id "programs" -Title (Get-WinForgeText 'Programas desatualizados') -Text (Get-WinForgeText '{0} versão nova. Clique para atualizar.' "$(Format-WinForgeCount -Count $count -One (Get-WinForgeText 'programa tem') -Many (Get-WinForgeText 'programas têm'))") -Action "updates.winget" -Level Info)
            }
            "catalog" {
                if ((Test-WinForgeMeteredConnection) -or (Test-WinForgeOnBattery)) { return $null }
                if (Test-WinForgeCatalogStale -Days 7) { [void](Update-WinForgeCatalog) }
                return $null
            }
            "diskhealth" {
                # Só o que diz que o disco pode falhar (Test-WinForgeDiskFailing); sem Administrador, os contadores de erro
                # e de desgaste não vêm, e valem o estado do Windows e a previsão do próprio disco.
                $disk = @(Get-WinForgeDiskHealth | Where-Object { Test-WinForgeDiskFailing -Disk $_ })[0]
                if ($null -eq $disk) { return $null }

                $drives = @(Get-WinForgeJsonValue -Object $disk -Name "Drives" -Default @())
                $name = $(if ($drives.Count -gt 0) { Get-WinForgeText '{0} ({1})' "$($disk.Name)" "$(Join-WinForgeList -Items $drives)" } else { [string]$disk.Name })

                return (New-WinForgeAgentAlert -Id "diskhealth" -Title (Get-WinForgeText 'Disco pode falhar') -Text (Get-WinForgeText '{0}: {1}. Faça backup dos seus arquivos e clique para ver.' "$name" "$(Get-WinForgeDiskFailingText -Disk $disk)") -Action "diagnostics.disk-health")
            }
            "winforge" {
                # Uma versão nova do WinForge: a consulta ao GitHub (a mesma de Verificar nova versão) é feita no máximo uma vez
                # a cada 20 horas, e nunca numa conexão limitada (plano de dados) ou na bateria; sem ela, vale a última
                # guardada. O balão aparece uma vez por versão; depois, o aviso só fica no menu do ícone, até a atualização.
                $checked = Get-WinForgeSettingDate -Name "UpdateCheckedAt"
                $stale = ($null -eq $checked -or $checked -gt (Get-Date).AddDays(1) -or ((Get-Date) - $checked).TotalHours -ge 20)

                if ($stale -and -not (Test-WinForgeMeteredConnection) -and -not (Test-WinForgeOnBattery)) {
                    Save-WinForgeUpdateCheck -Check (Get-WinForgeUpdateStatus)
                }

                $known = Get-WinForgeKnownUpdate
                if ($null -eq $known -or -not $known.Newer) { return $null }

                $announced = ([string](Get-WinForgeSetting -Name "UpdateAnnounced" -Default "") -eq [string]$known.Latest)
                if (-not $announced) { [void](Set-WinForgeSetting -Name "UpdateAnnounced" -Value ([string]$known.Latest)) }

                return (New-WinForgeAgentAlert -Id "winforge" -Title (Get-WinForgeText 'WinForge {0} disponível' "$($known.Latest)") -Text (Get-WinForgeText 'A versão {0} do WinForge foi publicada. Clique para ver o que mudou e atualizar.' "$($known.Latest)") -Action "app.update" -Level Info -Quiet:$announced)
            }
            "bluescreen" {
                # Uma tela azul nova (registrada depois da última que o monitor viu) vira aviso uma vez, com a causa
                # provável e o caminho para Diagnóstico > Telas azuis. A primeira leitura só marca onde a conta está:
                # telas azuis antigas não viram aviso.
                $latest = @(Get-WinForgeBlueScreens -Days 30) | Select-Object -First 1
                if ($null -eq $latest) { return $null }

                $seen = Get-WinForgeSettingDate -Name "BlueScreenSeenAt"
                $new = ($null -ne $seen -and $latest.When -gt $seen)

                if ($null -eq $seen -or $new) { [void](Set-WinForgeSetting -Name "BlueScreenSeenAt" -Value ($latest.When.ToString("o", [System.Globalization.CultureInfo]::InvariantCulture))) }
                if (-not $new) { return $null }

                $about = Get-WinForgeBugCheckCauseText -Cause ([string]$latest.Info.Cause)

                return (New-WinForgeAgentAlert -Id "bluescreen" -Title (Get-WinForgeText 'O PC teve uma tela azul') -Text (Get-WinForgeText 'Causa provável: {0}. Clique para ver o que fazer.' "$($about.Cause)") -Action "diagnostics.blue-screens")
            }
            "memtest" {
                # O resultado do Diagnóstico de Memória do Windows (o teste roda no reinício) aparece uma vez, quando chega
                # um novo. Com erros, o aviso vem mesmo que o teste tenha sido pedido por outra conta (o WinForge elevado
                # pela conta de outro Administrador guarda o pedido nas preferências dela); sem erros, só quando esta
                # conta pediu (Diagnóstico > Teste de memória). O primeiro resultado que o monitor vê sem pedido só marca
                # onde ele está: um teste antigo não vira aviso. Sem resultado em 14 dias, o pedido sai calado.
                $pending = Get-WinForgeMemoryTestPendingSince
                $result = Get-WinForgeMemoryTestResult -Days 60
                $seen = Get-WinForgeSettingDate -Name "MemoryTestSeenAt"

                if ($null -ne $pending -and ($null -eq $result -or $result.When -lt $pending) -and ((Get-Date) - $pending).TotalDays -gt 14) {
                    [void](Set-WinForgeSetting -Name "MemoryTestRequestedAt" -Value $null)
                }

                if ($null -eq $result) { return $null }

                $requested = ($null -ne $pending -and $result.When -ge $pending)
                $new = $(if ($null -ne $seen) { $result.When -gt $seen } else { $requested })

                if ($null -eq $seen -or $new) { [void](Set-WinForgeSetting -Name "MemoryTestSeenAt" -Value ($result.When.ToString("o", [System.Globalization.CultureInfo]::InvariantCulture))) }
                if (-not $new) { return $null }
                if ($requested) { [void](Set-WinForgeSetting -Name "MemoryTestRequestedAt" -Value $null) }

                if ($result.Errors) {
                    return (New-WinForgeAgentAlert -Id "memtest" -Title (Get-WinForgeText 'O teste de memória achou erros') -Text (Get-WinForgeText 'A memória (RAM) tem defeito: é a causa provável de telas azuis e travamentos. Clique para ver o que fazer.') -Action "diagnostics.memory-test")
                }

                if (-not $requested) { return $null }

                return (New-WinForgeAgentAlert -Id "memtest" -Title (Get-WinForgeText 'Teste de memória sem erros') -Text (Get-WinForgeText 'O Diagnóstico de Memória do Windows não achou problemas na RAM.') -Action "diagnostics.memory-test" -Level Info)
            }
        }
    }
    catch {
        Write-Verbose "Monitor, ${Id}: $($_.Exception.Message)"
    }

    return $null
}


function Get-WinForgeAgentDueChecks {
    # As conferências que já passaram da hora, separadas em leves (rodam na hora) e pesadas (em segundo plano).
    param (
        [Parameter(Mandatory)][hashtable]$State,
        [datetime]$Now = (Get-Date)
    )

    return @(Get-WinForgeAgentChecks | Where-Object { Test-WinForgeAgentDue -Last $State.Checked[$_.Id] -Minutes $_.EveryMinutes -Now $Now })
}


function Select-WinForgeAgentAlerts {
    # Dos avisos lidos, os que podem aparecer agora: não pausados e não repetidos antes do intervalo da conferência.
    param (
        [AllowEmptyCollection()][object[]]$Alerts = @(),
        [Parameter(Mandatory)][hashtable]$State,
        [datetime]$Now = (Get-Date),
        [bool]$Paused = $false
    )

    if ($Paused) { return @() }

    $checks = @{}
    foreach ($check in (Get-WinForgeAgentChecks)) { $checks[$check.Id] = $check }

    return @(
        foreach ($alert in @($Alerts | Where-Object { $null -ne $_ })) {
            if ([bool](Get-WinForgeJsonValue -Object $alert -Name "Quiet" -Default $false)) { continue }

            $repeat = $(if ($checks.ContainsKey($alert.Id)) { [double]$checks[$alert.Id].RepeatHours } else { 24 })
            $last = $State.Shown[$alert.Id]

            if ($repeat -le 0) {
                # Uma vez por leitura: o balão volta só se uma leitura mais nova que ele trouxe o aviso de novo.
                $read = $State.Checked[$alert.Id]
                if ($null -eq $last -or ($null -ne $read -and [datetime]$last -lt [datetime]$read)) { $alert }
                continue
            }

            if (Test-WinForgeAgentDue -Last $last -Minutes ($repeat * 60) -Now $Now) { $alert }
        }
    )
}


# ---------------------------------------------------------------------------
# Tela (Sobre o WinForge > Monitor na bandeja)
# ---------------------------------------------------------------------------

function Set-WinForgeMonitor {
    # -Choose On: liga direto, sem a tela de escolha (a configuração inicial, no fim do Início). Já ligado, ou com a
    # conta de outro Administrador, a tela de sempre aparece.
    param ([ValidateSet("", "On")][string]$Choose = "")

    $title = (Get-WinForgeText 'Monitor na bandeja')

    Enter-WinForgeAction -Title $title

    $final = New-WinForgeResult -Kind Ok -Title $title
    $answer = ""

    try {
        $runState = Get-WinForgeAgentRunState
        $enabled = ($runState -eq "On")
        $running = (@(Get-WinForgeAgentProcesses).Count -gt 0)
        $mismatch = Test-WinForgeAgentStartBlocked
        $pausedUntil = Get-WinForgeAgentPausedUntil

        $startText = switch ($runState) {
            "On" { (Get-WinForgeText 'sim') }
            "Elsewhere" { (Get-WinForgeText 'não: foi ligado de outra pasta do WinForge; Ligar o monitor passa a usar esta') }
            "Disabled" { (Get-WinForgeText 'não: desligado em Configurações, Aplicativos, Inicialização (ou no Gerenciador de Tarefas); Ligar o monitor religa') }
            default { (Get-WinForgeText 'não') }
        }

        Write-WinForgeKeyValue -Label (Get-WinForgeText 'Começa com o Windows') -Value $startText
        Write-WinForgeKeyValue -Label (Get-WinForgeText 'Aberto agora') -Value $(if ($running) { (Get-WinForgeText 'sim') } else { (Get-WinForgeText 'não') })
        if ($null -ne $pausedUntil) { Write-WinForgeKeyValue -Label (Get-WinForgeText 'Avisos') -Value (Get-WinForgeText 'pausados até {0}' "$(Format-WinForgeAgentPauseEnd -Until $pausedUntil)") }
        Write-Host ""

        # Os avisos: disco enchendo, proteção desligada, reinício ou manutenção faltando, Windows sem suporte e programas
        # desatualizados. Pelo menu do ícone dá para ver os avisos, verificar, acelerar e limpar o PC, ou pausar os avisos.
        Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'O monitor fica perto do relógio e avisa quando o PC precisa de cuidado; nada muda sem você clicar.')

        # Com a conta de outro Administrador, ligar gravaria o monitor no perfil dele: não oferece.
        if ($mismatch) {
            Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'O WinForge está aberto com a conta de outro Administrador. Para ligar ou desligar o monitor na sua conta, {0}.' "$(Get-WinForgeUnelevatedHint)")
        }

        Write-Host ""

        $options = @()

        if ($mismatch) {
            # Só informa.
        }
        elseif ($enabled) {
            $options += @{ Key = "D"; Label = (Get-WinForgeText 'Desligar o monitor'); Description = (Get-WinForgeText 'Fecha o ícone e não abre mais com o Windows') }
            if (-not $running) { $options += @{ Key = "A"; Label = (Get-WinForgeText 'Abrir agora'); Description = (Get-WinForgeText 'Ele está configurado, mas não está aberto') } }
        }
        else {
            $options += @{ Key = "L"; Label = (Get-WinForgeText 'Ligar o monitor'); Description = (Get-WinForgeText 'Abre agora e passa a abrir com o Windows'); Accent = $true }
            if ($running -or $runState -ne "Off") { $options += @{ Key = "D"; Label = (Get-WinForgeText 'Desligar o monitor'); Description = (Get-WinForgeText 'Fecha o ícone e tira a entrada que sobrou') } }
        }

        # A pausa (do menu do ícone) também se desfaz daqui.
        if ($null -ne $pausedUntil -and -not $mismatch) {
            $options += @{ Key = "R"; Label = (Get-WinForgeText 'Retomar os avisos'); Description = (Get-WinForgeText 'Os avisos voltam na próxima conferência') }
        }

        $options += @{ Key = "X"; Label = (Get-WinForgeText 'Voltar'); Exit = $true }

        $answer = $(if ($Choose -eq "On" -and -not $enabled -and -not $mismatch) { "L" } else { Read-WinForgeChoice -Message (Get-WinForgeText 'O que deseja fazer?') -Options $options -DefaultKey "X" -ShowMenu -TextPrompt (Get-WinForgeText 'Opção (0 ou Enter = voltar)') })

        switch ($answer) {
            "L" {
                $open = Enable-WinForgeAgent
                [void](Add-WinForgeChange -Action (Get-WinForgeText 'Monitor na bandeja') -Text (Get-WinForgeText 'ligado (abre com o Windows)'))

                if ($open -eq "Open") {
                    Write-WinForgeStatus -Type Success -Message (Get-WinForgeText 'Monitor ligado; se o ícone não aparecer, ele está na setinha (^) ao lado do relógio.')
                    $final = Set-WinForgeResultView -Result (New-WinForgeResult -Kind Ok -Detail (Get-WinForgeText 'monitor ligado') -Title $title) `
                        -Headline (Get-WinForgeText 'Monitor ligado') -Note (Get-WinForgeText 'Se o ícone não aparecer, ele está na setinha (^) ao lado do relógio.')
                }
                elseif ($open -eq "Later") {
                    Write-WinForgeStatus -Type Success -Message (Get-WinForgeText 'Monitor ligado; o ícone aparece em instantes ou na próxima entrada no Windows.')
                    $final = Set-WinForgeResultView -Result (New-WinForgeResult -Kind Ok -Detail (Get-WinForgeText 'monitor ligado; o ícone aparece em instantes ou na próxima entrada no Windows') -Title $title) `
                        -Headline (Get-WinForgeText 'Monitor ligado') -Note (Get-WinForgeText 'O ícone aparece em instantes ou na próxima entrada no Windows.')
                }
                else {
                    Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'Monitor ligado, mas o Windows não deixou abri-lo agora: ele abre sozinho na próxima vez que você entrar no Windows.')
                    $final = Set-WinForgeResultView -Result (New-WinForgeResult -Kind Warning -Detail (Get-WinForgeText 'monitor ligado, mas não abriu agora; abre na próxima entrada no Windows') -Title $title) `
                        -Headline (Get-WinForgeText 'Monitor ligado, mas não abriu agora') -Note (Get-WinForgeText 'Ele abre sozinho na próxima vez que você entrar no Windows.')
                }
            }
            "D" {
                $closed = Disable-WinForgeAgent
                [void](Add-WinForgeChange -Action (Get-WinForgeText 'Monitor na bandeja') -Text (Get-WinForgeText 'desligado'))

                if ($closed) {
                    Write-WinForgeStatus -Type Success -Message (Get-WinForgeText 'Monitor desligado.')
                    $final = Set-WinForgeResultView -Result (New-WinForgeResult -Kind Ok -Detail (Get-WinForgeText 'monitor desligado') -Title $title) `
                        -Headline (Get-WinForgeText 'Monitor desligado') -Note $(if ($running) { (Get-WinForgeText 'O ícone fechou e não abre mais com o Windows.') } else { (Get-WinForgeText 'Ele não abre mais com o Windows.') })
                }
                else {
                    Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'O monitor não abre mais com o Windows, mas o ícone aberto não fechou: feche pelo menu dele, em Fechar o monitor.')
                    $final = Set-WinForgeResultView -Result (New-WinForgeResult -Kind Warning -Detail (Get-WinForgeText 'o ícone aberto não fechou; feche pelo menu dele') -Title $title) `
                        -Headline (Get-WinForgeText 'O ícone do monitor não fechou') -Note (Get-WinForgeText 'Ele não abre mais com o Windows; feche o ícone pelo menu dele, em Fechar o monitor.')
                }
            }
            "A" {
                if (Start-WinForgeAgent) {
                    Write-WinForgeStatus -Type Success -Message (Get-WinForgeText 'Monitor aberto; se o ícone não aparecer, ele está na setinha (^) ao lado do relógio.')
                    $final = Set-WinForgeResultView -Result (New-WinForgeResult -Kind Ok -Detail (Get-WinForgeText 'monitor aberto') -Title $title) `
                        -Headline (Get-WinForgeText 'Monitor aberto') -Note (Get-WinForgeText 'Se o ícone não aparecer, ele está na setinha (^) ao lado do relógio.')
                }
                else {
                    Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'O ícone não apareceu agora; ele abre sozinho na próxima entrada no Windows.')
                    $final = Set-WinForgeResultView -Result (New-WinForgeResult -Kind Warning -Detail (Get-WinForgeText 'o ícone não apareceu agora; abre na próxima entrada no Windows') -Title $title) `
                        -Headline (Get-WinForgeText 'O ícone não apareceu agora') -Note (Get-WinForgeText 'Ele abre sozinho na próxima vez que você entrar no Windows.')
                }
            }
            "R" {
                Set-WinForgeAgentPause -Hours 0
                Write-WinForgeStatus -Type Success -Message (Get-WinForgeText 'Avisos retomados.')
                $final = Set-WinForgeResultView -Result (New-WinForgeResult -Kind Ok -Detail (Get-WinForgeText 'avisos retomados') -Title $title) `
                    -Headline (Get-WinForgeText 'Avisos retomados') -Note (Get-WinForgeText 'Eles voltam na próxima conferência do monitor.')
            }
            default {
                # Voltar sem mudar nada é "Cancelado", como nas outras telas de escolha; com a conta de outro Administrador não
                # havia o que escolher, então é "Nada a fazer", com o motivo.
                if ($mismatch) {
                    $final = New-WinForgeResult -Kind Skipped -Detail (Get-WinForgeText 'com a conta de outro Administrador, o monitor só muda com o WinForge aberto sem Administrador') -Title $title
                }
                else {
                    $final = New-WinForgeResult -Kind Skipped -Detail (Get-WinForgeText 'cancelado pelo usuário') -Title $title
                }
            }
        }
    }
    catch {
        Write-WinForgeStatus -Type Error -Message (Get-WinForgeText 'Não foi possível mudar o monitor: {0}.' "$($_.Exception.Message.TrimEnd('.'))")
        # O título diz o que não aconteceu (ligar, desligar, abrir); a frase, o porquê.
        $headline = switch ($answer) {
            "L" { (Get-WinForgeText 'O monitor não foi ligado') }
            "D" { (Get-WinForgeText 'O monitor não foi desligado') }
            "A" { (Get-WinForgeText 'O monitor não abriu') }
            default { (Get-WinForgeText 'Não foi possível mudar o monitor') }
        }
        $final = Set-WinForgeResultView -Result (New-WinForgeResult -Kind Failed -Detail $_.Exception.Message.TrimEnd('.') -Title $title) -Headline $headline -Note (Format-WinForgeReasonNote -Text $_.Exception.Message)
    }

    Exit-WinForgeAction -Result $final
}


Export-ModuleMember -Function *
