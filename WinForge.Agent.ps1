<#
.SYNOPSIS
    Monitor do WinForge na bandeja do Windows (perto do relógio).

.DESCRIPTION
    Fica de olho no PC e mostra um aviso quando algo pede atenção: pouco espaço no disco, proteção desligada, reinício
    pendente, manutenção atrasada, Windows sem suporte e programas desatualizados. Só lê; o menu do ícone abre o WinForge
    para acelerar, limpar ou verificar o PC. Ligue e desligue em Sobre o WinForge > Monitor na bandeja.
#>
[CmdletBinding()]
param ()

$ErrorActionPreference = "Continue"

# O monitor nunca roda como Administrador: com o UAC ligado, um monitor elevado (aberto de uma janela elevada sem passar
# pelo Explorador) fecha na hora, e quem o abriu diz que ele abre com o Windows. Com o UAC desligado, toda conta de
# Administrador já roda assim, e não há como abrir sem a elevação.
try {
    $principal = New-Object Security.Principal.WindowsPrincipal ([Security.Principal.WindowsIdentity]::GetCurrent())
    $lua = (Get-ItemProperty -LiteralPath "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "EnableLUA" -ErrorAction Stop).EnableLUA

    if ([int]$lua -ne 0 -and $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        exit 0
    }
}
catch {
    Write-Verbose "Monitor: $($_.Exception.Message)"
}

# Uma cópia só por sessão do Windows.
$createdNew = $false
$script:Mutex = New-Object System.Threading.Mutex($true, "Local\WinForge.Agent", [ref]$createdNew)

if (-not $createdNew) {
    exit 0
}

Add-Type -AssemblyName System.Windows.Forms, System.Drawing

$moduleRoot = Join-Path $PSScriptRoot "modules"

try {
    $manifest = Import-PowerShellDataFile -LiteralPath (Join-Path $moduleRoot "Modules.psd1") -ErrorAction Stop
    $script:AgentModules = @($manifest.Common)

    foreach ($name in $script:AgentModules) {
        $modulePath = Join-Path $moduleRoot "$name.psm1"

        try {
            Import-Module -Name $modulePath -Force -DisableNameChecking -Global -ErrorAction Stop
        }
        catch {
            Import-Module -Name ([System.Management.Automation.WildcardPattern]::Escape($modulePath)) -Force -DisableNameChecking -Global -ErrorAction Stop
        }
    }
}
catch {
    $script:Mutex.ReleaseMutex()
    exit 1
}

$script:StopSignal = New-Object System.Threading.EventWaitHandle($false, [System.Threading.EventResetMode]::AutoReset, (Get-WinForgeAgentStopEventName))
# Sem o estado guardado, é a primeira vez que o monitor abre neste usuário: um balão diz que ele está ali.
$script:FirstRun = -not (Test-Path -LiteralPath (Get-WinForgeAgentStatePath) -PathType Leaf)
$script:State = Read-WinForgeAgentState
$script:Alerts = @{}
# O que o clique no último balão abre (o Id de uma ação, "" = só a janela). $null: o balão só informa, e o clique não
# abre nada (sem isto, clicar no balão da pausa ou da pasta apagada repetia o aviso anterior).
$script:LastAction = $null
$script:Worker = $null
$script:WorkerHandle = $null
$script:WorkerIds = @()
$script:WorkerStarted = [datetime]::MinValue
$script:FirstReading = $false
$script:StateDirty = $false
$script:Closing = $false

# Uma leitura em segundo plano que passa disso (um winget travado, por exemplo) é abandonada: as outras conferências não
# podem ficar esperando por ela.
$script:WorkerTimeout = [TimeSpan]::FromMinutes(5)


function Open-AgentWindow {
    # Abre a janela do WinForge, opcionalmente já rodando uma ação (Id da navegação).
    param ([string]$Action = "")

    $gui = Join-Path $PSScriptRoot "WinForge.Gui.ps1"

    if (-not (Test-Path -LiteralPath $gui -PathType Leaf)) {
        $script:LastAction = $null
        $script:Notify.ShowBalloonTip(8000, "WinForge", "A pasta do WinForge mudou de lugar ou foi apagada. Abra o WinForge na pasta nova e ligue o monitor em Sobre o WinForge > Monitor na bandeja.", [System.Windows.Forms.ToolTipIcon]::Warning)
        return
    }

    $arguments = "-NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File $(ConvertTo-WinForgeCommandLineArgument -Value $gui)"
    if ($Action) { $arguments += " -Action $Action" }

    try {
        Start-Process -FilePath (Get-WinForgePowerShellPath) -ArgumentList $arguments -WindowStyle Hidden -ErrorAction Stop
    }
    catch {
        # O clique neste balão não pode repetir o aviso anterior.
        $script:LastAction = $null
        $script:Notify.ShowBalloonTip(5000, "WinForge", "O Windows não deixou abrir o WinForge agora. Tente de novo pelo atalho do WinForge.", [System.Windows.Forms.ToolTipIcon]::Error)
    }
}


function Update-AgentTooltip {
    # O texto ao passar o mouse (até 63 caracteres; o texto vem de Get-WinForgeAgentTooltip).
    $script:Notify.Text = Get-WinForgeAgentTooltip -Alerts @($script:Alerts.Values) -FirstReading $script:FirstReading -PausedUntil (Get-WinForgeAgentPausedUntil)
}


function Switch-AgentPause {
    # Pausar avisos por 24 horas / Retomar os avisos (menu do ícone). A pausa ganha um balão com até quando ela vai.
    if (Test-WinForgeAgentPaused) {
        Set-WinForgeAgentPause -Hours 0
    }
    else {
        Set-WinForgeAgentPause -Hours 24
        $until = Get-WinForgeAgentPausedUntil

        if ($null -ne $until) {
            $script:LastAction = $null
            $script:Notify.ShowBalloonTip(8000, "Avisos pausados", (Get-WinForgeAgentPauseNotice -Until $until), [System.Windows.Forms.ToolTipIcon]::Info)
        }
    }

    Update-AgentTooltip
}


function Show-AgentAlerts {
    <#
    Mostra no máximo um balão por volta (a cada 15 segundos), o mais grave primeiro: vários de uma vez se atropelavam, e o
    clique num balão antigo abria a tela do último. Os outros avisos abertos saem nas voltas seguintes. Clicar no balão
    abre a tela do aviso que ele mostra.
    #>
    $now = Get-Date
    $active = @($script:Alerts.Values | Sort-Object @{ Expression = { if ($_.Level -eq "Warning") { 0 } else { 1 } } })
    $due = @(Select-WinForgeAgentAlerts -Alerts $active -State $script:State -Now $now -Paused (Test-WinForgeAgentPaused -Now $now))

    if ($due.Count -gt 0) {
        $alert = $due[0]
        $script:State.Shown[$alert.Id] = $now
        $script:StateDirty = $true
        $script:LastAction = [string]$alert.Action
        $icon = $(if ($alert.Level -eq "Warning") { [System.Windows.Forms.ToolTipIcon]::Warning } else { [System.Windows.Forms.ToolTipIcon]::Info })
        $script:Notify.ShowBalloonTip(10000, $alert.Title, $alert.Text, $icon)
    }

    if ($script:StateDirty) {
        Save-WinForgeAgentState -State $script:State
        $script:StateDirty = $false
    }
}


function Stop-AgentIfFolderGone {
    <#
    A pasta do WinForge mudou de lugar ou foi apagada com o monitor aberto: tira a entrada de início que aponta para este
    script (ela só falharia a cada entrada no Windows), avisa e fecha alguns segundos depois (fechar na hora tiraria o
    ícone, e o aviso com ele). Uma entrada que já aponta para outra pasta (o monitor ligado de novo pela pasta nova) fica
    como está. Devolve se vai fechar.
    #>
    if (Test-Path -LiteralPath $PSCommandPath -PathType Leaf) { return $false }

    $script:Closing = $true

    try {
        [void](Remove-WinForgeAgentStaleEntry -ScriptPath $PSCommandPath)
    }
    catch {
        Write-Verbose "Monitor: $($_.Exception.Message)"
    }

    $script:LastAction = $null
    $script:Notify.ShowBalloonTip(8000, "WinForge", "A pasta do WinForge mudou de lugar ou foi apagada, e o monitor vai fechar. Para ligá-lo de novo, abra o WinForge na pasta nova e use Sobre o WinForge > Monitor na bandeja.", [System.Windows.Forms.ToolTipIcon]::Warning)

    $script:ExitTimer = New-Object System.Windows.Forms.Timer
    $script:ExitTimer.Interval = 8000
    $script:ExitTimer.Add_Tick({ $script:ExitTimer.Stop(); [System.Windows.Forms.Application]::Exit() })
    $script:ExitTimer.Start()

    return $true
}


function Set-AgentReadings {
    # Guarda o resultado das conferências: um aviso aberto fica na lista (o texto do ícone conta), um "tudo bem" o tira.
    param (
        [string[]]$Checked = @(),
        [object[]]$Alerts = @()
    )

    $now = Get-Date

    foreach ($id in $Checked) {
        $script:State.Checked[$id] = $now
        $script:Alerts.Remove($id)
        $script:StateDirty = $true
    }

    foreach ($alert in @($Alerts | Where-Object { $null -ne $_ })) { $script:Alerts[$alert.Id] = $alert }

    $script:FirstReading = $true
    Update-AgentTooltip
}


function Start-AgentHeavyChecks {
    # As leituras demoradas (proteção, winget, dados online) rodam em outro runspace: o menu do ícone continua respondendo.
    param ([string[]]$Ids)

    $shell = [powershell]::Create()
    [void]$shell.AddScript({
            param ($ModuleRoot, $Modules, $Ids)

            foreach ($name in $Modules) {
                $modulePath = Join-Path $ModuleRoot "$name.psm1"

                # Numa pasta com colchetes no nome, o Windows PowerShell 5.1 lê o caminho como curinga (como no início).
                try {
                    Import-Module -Name $modulePath -Force -DisableNameChecking -Global -ErrorAction Stop
                }
                catch {
                    Import-Module -Name ([System.Management.Automation.WildcardPattern]::Escape($modulePath)) -Force -DisableNameChecking -Global -ErrorAction Stop
                }
            }

            [PSCustomObject]@{ Checked = @($Ids); Alerts = @(foreach ($id in $Ids) { Get-WinForgeAgentReading -Id $id }) }
        })
    [void]$shell.AddArgument($moduleRoot)
    [void]$shell.AddArgument($script:AgentModules)
    [void]$shell.AddArgument($Ids)

    $script:Worker = $shell
    $script:WorkerIds = @($Ids)
    $script:WorkerStarted = Get-Date
    $script:WorkerHandle = $shell.BeginInvoke()
}


function Stop-AgentHeavyChecks {
    # Abandona a leitura em segundo plano e conta as conferências dela como feitas: a próxima tentativa só vem no
    # intervalo normal de cada uma, em vez de a cada volta do relógio.
    try { [void]$script:Worker.BeginStop($null, $null) } catch { Write-Verbose "Monitor: $($_.Exception.Message)" }
    try { $script:Worker.Dispose() } catch { Write-Verbose "Monitor: $($_.Exception.Message)" }

    $ids = @($script:WorkerIds)
    $script:Worker = $null
    $script:WorkerHandle = $null
    $script:WorkerIds = @()

    Set-AgentReadings -Checked $ids -Alerts @()
}


function Invoke-AgentTick {
    if ($script:StopSignal.WaitOne(0)) {
        [System.Windows.Forms.Application]::Exit()
        return
    }

    if ($script:Closing -or (Stop-AgentIfFolderGone)) { return }

    # Uma leitura em segundo plano terminou: os avisos dela entram agora. Se ela falhou (ou não trouxe nada), as
    # conferências contam como feitas mesmo assim: tentar de novo a cada volta só repetiria a falha.
    if ($null -ne $script:WorkerHandle -and $script:WorkerHandle.IsCompleted) {
        $output = $null

        try {
            $output = @($script:Worker.EndInvoke($script:WorkerHandle)) | Select-Object -Last 1
        }
        catch {
            Write-Verbose "Leitura em segundo plano falhou: $($_.Exception.Message)"
        }
        finally {
            $script:Worker.Dispose()
            $script:Worker = $null
            $script:WorkerHandle = $null
        }

        if ($null -ne $output) { Set-AgentReadings -Checked @($output.Checked) -Alerts @($output.Alerts) } else { Set-AgentReadings -Checked $script:WorkerIds -Alerts @() }
        $script:WorkerIds = @()
    }
    elseif ($null -ne $script:Worker -and ((Get-Date) - $script:WorkerStarted) -gt $script:WorkerTimeout) {
        Stop-AgentHeavyChecks
    }

    $due = @(Get-WinForgeAgentDueChecks -State $script:State)
    $light = @($due | Where-Object { -not $_.Heavy } | ForEach-Object { $_.Id })
    $heavy = @($due | Where-Object { $_.Heavy } | ForEach-Object { $_.Id })

    if ($light.Count -gt 0) {
        Set-AgentReadings -Checked $light -Alerts @(foreach ($id in $light) { Get-WinForgeAgentReading -Id $id })
    }

    if ($heavy.Count -gt 0 -and $null -eq $script:Worker) {
        Start-AgentHeavyChecks -Ids $heavy
    }

    Show-AgentAlerts

    # O texto do ícone acompanha o relógio: uma pausa que terminou deixa de aparecer sem esperar outra leitura.
    Update-AgentTooltip
}


# --- Ícone e menu ------------------------------------------------------------------------------------------
$script:Notify = New-Object System.Windows.Forms.NotifyIcon
$iconPath = Get-WinForgeIconPath -Root $PSScriptRoot
$script:Notify.Icon = $(if ($iconPath) { New-Object System.Drawing.Icon($iconPath) } else { [System.Drawing.SystemIcons]::Application })
$script:Notify.Text = "WinForge"

$script:Menu = New-Object System.Windows.Forms.ContextMenuStrip
$script:BoldFont = $null
$script:WarningImage = $null
try { $script:WarningImage = [System.Drawing.SystemIcons]::Warning.ToBitmap() } catch { Write-Verbose "Monitor: $($_.Exception.Message)" }


function Add-AgentMenuItem {
    # Um item do menu do ícone. Sem -OnClick, o clique abre a janela do WinForge com a ação -Action ("" = só a janela).
    param (
        [string]$Text,
        [string]$Action = "",
        [string]$Hint = "",
        [switch]$Bold,
        [switch]$Disabled,
        $Image = $null,
        [scriptblock]$OnClick = $null
    )

    $item = New-Object System.Windows.Forms.ToolStripMenuItem($Text)
    $item.Tag = $Action

    if ($Bold) {
        if ($null -eq $script:BoldFont) { $script:BoldFont = New-Object System.Drawing.Font($item.Font, [System.Drawing.FontStyle]::Bold) }
        $item.Font = $script:BoldFont
    }

    if ($Hint) { $item.ToolTipText = $Hint }
    if ($Disabled) { $item.Enabled = $false }
    if ($null -ne $Image) { $item.Image = $Image }

    if ($null -ne $OnClick) { $item.Add_Click($OnClick) }
    else { $item.Add_Click({ param ($sender, $eventArgs) Open-AgentWindow -Action ([string]$sender.Tag) }) }

    [void]$script:Menu.Items.Add($item)
}


function Update-AgentMenu {
    <#
    Monta o menu do ícone de novo a cada vez que ele abre: Abrir o WinForge; um item por aviso aberto (o mais grave
    primeiro, com o ícone de alerta), que abre a tela que resolve, ou "Nada pedindo atenção"; Verificar o PC, Acelerar
    agora e Limpeza rápida; pausar ou retomar; Configurar o monitor; e fechar, dizendo até quando.
    #>
    $old = @($script:Menu.Items)
    $script:Menu.Items.Clear()
    foreach ($entry in $old) { $entry.Dispose() }

    Add-AgentMenuItem -Text "Abrir o WinForge" -Bold

    $alerts = @(Get-WinForgeAgentSortedAlerts -Alerts @($script:Alerts.Values))

    if (-not $script:FirstReading) {
        Add-AgentMenuItem -Text "Conferindo o PC..." -Disabled
    }
    elseif ($alerts.Count -eq 0) {
        Add-AgentMenuItem -Text "Nada pedindo atenção" -Disabled
    }
    else {
        foreach ($alert in $alerts) {
            Add-AgentMenuItem -Text ([string]$alert.Title) -Action ([string]$alert.Action) -Hint ([string]$alert.Text) -Image $(if ($alert.Level -eq "Warning") { $script:WarningImage } else { $null })
        }
    }

    [void]$script:Menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))
    Add-AgentMenuItem -Text "Verificar o PC" -Action "maintenance.checkup"
    Add-AgentMenuItem -Text "Acelerar agora" -Action "performance.boost"
    Add-AgentMenuItem -Text "Limpeza rápida" -Action "cleanup.quick"
    [void]$script:Menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))

    Add-AgentMenuItem -Text $(if (Test-WinForgeAgentPaused) { "Retomar os avisos" } else { "Pausar avisos por 24 horas" }) -OnClick { Switch-AgentPause }
    Add-AgentMenuItem -Text "Configurar o monitor..." -Action "app.monitor"

    # Fechar só vale até a próxima entrada no Windows quando o monitor está ligado para abrir com ele.
    $enabled = $false
    try { $enabled = Test-WinForgeAgentEnabled } catch { Write-Verbose "Monitor: $($_.Exception.Message)" }

    Add-AgentMenuItem -Text $(if ($enabled) { "Fechar até a próxima entrada no Windows" } else { "Fechar o monitor" }) -OnClick { [System.Windows.Forms.Application]::Exit() }
}


Update-AgentMenu

$script:Menu.Add_Opening({
        param ($sender, $eventArgs)

        try { Update-AgentMenu } catch { Write-Verbose "Monitor: $($_.Exception.Message)" }

        # Um menu que estava vazio chega aqui com Cancel ligado; montado agora, ele abre.
        $eventArgs.Cancel = $false
    })

$script:Notify.ContextMenuStrip = $script:Menu
$script:Notify.Add_MouseClick({
        param ($sender, $eventArgs)
        if ($eventArgs.Button -eq [System.Windows.Forms.MouseButtons]::Left) { Open-AgentWindow }
    })
$script:Notify.Add_BalloonTipClicked({
        if ($null -ne $script:LastAction) { Open-AgentWindow -Action $script:LastAction }
    })
$script:Notify.Visible = $true
Update-AgentTooltip

# A primeira vez: o ícone costuma ir para a área dos ocultos, e o monitor ficaria calado até algo pedir atenção.
if ($script:FirstRun) {
    $script:LastAction = $null
    $script:Notify.ShowBalloonTip(10000, "Monitor do WinForge ligado", "O WinForge vai avisar aqui quando algo pedir atenção. Clique com o botão direito no ícone para ver as opções.", [System.Windows.Forms.ToolTipIcon]::Info)
    Save-WinForgeAgentState -State $script:State
}

# A primeira leitura espera um pouco (o Windows acabou de entrar); depois, uma volta a cada 15 segundos (cada
# conferência só roda quando chega a hora dela; a volta curta é para o pedido de fechar ser atendido logo).
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 90000
$timer.Add_Tick({
        $timer.Interval = 15000

        try { Invoke-AgentTick } catch { Write-Verbose "Monitor: $($_.Exception.Message)" }
    })
$timer.Start()

# O pedido de fechar (Sobre o WinForge > Monitor na bandeja > Desligar) é atendido em meio segundo, a tempo de o monitor
# sair sozinho, guardar o estado e tirar o ícone, antes de quem pediu desistir de esperar e encerrar o processo.
$stopTimer = New-Object System.Windows.Forms.Timer
$stopTimer.Interval = 500
$stopTimer.Add_Tick({
        if ($script:StopSignal.WaitOne(0)) { [System.Windows.Forms.Application]::Exit() }
    })
$stopTimer.Start()

try {
    [System.Windows.Forms.Application]::Run()
}
finally {
    $stopTimer.Stop()
    $timer.Stop()
    $script:Notify.Visible = $false
    $script:Notify.Dispose()
    if ($null -ne $script:Worker) { try { [void]$script:Worker.BeginStop($null, $null) } catch { } }
    $script:StopSignal.Dispose()
    $script:Mutex.ReleaseMutex()
    $script:Mutex.Dispose()
}
