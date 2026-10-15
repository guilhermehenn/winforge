# Manutenção agendada: uma tarefa do Agendador de Tarefas do Windows que, uma vez por mês, faz só o que é seguro
# sem ninguém olhando (limpa os temporários do usuário e salva um relatório). É opcional, começa desligada e some
# com um clique.
#
# Decisões de segurança:
#   - A tarefa roda SEM privilégios de Administrador, só com o usuário logado. Uma tarefa elevada que executa um
#     script numa pasta que o próprio usuário pode alterar (Downloads, Área de Trabalho) seria um atalho para qualquer
#     programa comum ganhar privilégios; sem elevação esse risco não existe, e não há pedido de UAC que travaria
#     uma tarefa em segundo plano.
#   - Não esvazia a Lixeira, não repara, não atualiza e não muda ajustes: isso exige a sua decisão na hora.

$script:WinForgeSchedulePath = "\WinForge\"
$script:WinForgeScheduleName = "Manutencao-Mensal"
$script:WinForgeScheduleDays = @(1, 15, 28)
$script:WinForgeScheduleHour = 12


# ---------------------------------------------------------------------------
# A tarefa
# ---------------------------------------------------------------------------

function Get-WinForgeScheduleUser {
    # Quem vai executar a tarefa: o usuário que está usando o PC. Se o WinForge foi elevado com outra conta, é o
    # usuário logado que importa (é a Área de Trabalho e os temporários dele que a limpeza deve tratar).
    $interactive = Get-WinForgeInteractiveUser

    if (-not [string]::IsNullOrWhiteSpace($interactive)) {
        return $interactive
    }

    try {
        return [Security.Principal.WindowsIdentity]::GetCurrent().Name
    }
    catch {
        return ""
    }
}


function Get-WinForgeScheduleCommand {
    # O programa e os argumentos que a tarefa executa: o mesmo PowerShell do WinForge.cmd, com o script do terminal.
    param (
        [string]$Root = (Get-WinForgeAppRoot)
    )

    $script = Join-Path $Root "WinForge.Console.ps1"

    if (-not (Test-Path -LiteralPath $script -PathType Leaf)) {
        throw "O arquivo WinForge.Console.ps1 não foi encontrado em '$Root'. Extraia a pasta inteira do WinForge antes de agendar."
    }

    return [PSCustomObject]@{
        Executable       = Get-WinForgePowerShellPath
        Arguments        = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File $(ConvertTo-WinForgeCommandLineArgument -Value $script) -Action ScheduledMaintenance"
        WorkingDirectory = $Root
    }
}


function New-WinForgeScheduleTaskXml {
    <#
    O XML da tarefa (esquema do Agendador de Tarefas): todo mês no dia escolhido, às 12h, com o usuário logado e sem
    elevação. Se o PC estiver desligado na hora, roda assim que for possível; não começa na bateria e para se passar
    a usar a bateria. A primeira execução é a partir de amanhã, para não disparar na hora em que é criada.
    #>
    param (
        [Parameter(Mandatory)][string]$Executable,
        [Parameter(Mandatory)][string]$Arguments,
        [Parameter(Mandatory)][string]$WorkingDirectory,
        [Parameter(Mandatory)][string]$UserId,

        [ValidateRange(1, 28)]
        [int]$DayOfMonth = 1,

        [datetime]$Start = ((Get-Date).Date.AddDays(1).AddHours($script:WinForgeScheduleHour))
    )

    $escape = { param ($text) [System.Security.SecurityElement]::Escape($text) }
    $startBoundary = $Start.ToString("yyyy-MM-dd'T'HH:mm:ss", [System.Globalization.CultureInfo]::InvariantCulture)
    $months = (@("January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December") | ForEach-Object { "<$_ />" }) -join ""
    $description = "Manutenção mensal do WinForge: limpa os temporários do usuário e salva um relatório. Não esvazia a Lixeira nem altera o sistema. Para remover, use o WinForge (Manutenção > Manutenção agendada) ou apague esta tarefa."

    return @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Author>WinForge</Author>
    <Description>$(& $escape $description)</Description>
  </RegistrationInfo>
  <Triggers>
    <CalendarTrigger>
      <StartBoundary>$startBoundary</StartBoundary>
      <Enabled>true</Enabled>
      <ScheduleByMonth>
        <DaysOfMonth><Day>$DayOfMonth</Day></DaysOfMonth>
        <Months>$months</Months>
      </ScheduleByMonth>
    </CalendarTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">
      <UserId>$(& $escape $UserId)</UserId>
      <LogonType>InteractiveToken</LogonType>
      <RunLevel>LeastPrivilege</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>true</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>true</StopIfGoingOnBatteries>
    <AllowHardTerminate>true</AllowHardTerminate>
    <StartWhenAvailable>true</StartWhenAvailable>
    <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <Enabled>true</Enabled>
    <Hidden>false</Hidden>
    <RunOnlyIfIdle>false</RunOnlyIfIdle>
    <WakeToRun>false</WakeToRun>
    <ExecutionTimeLimit>PT1H</ExecutionTimeLimit>
    <Priority>7</Priority>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>$(& $escape $Executable)</Command>
      <Arguments>$(& $escape $Arguments)</Arguments>
      <WorkingDirectory>$(& $escape $WorkingDirectory)</WorkingDirectory>
    </Exec>
  </Actions>
</Task>
"@
}


function ConvertTo-WinForgeScheduleResultText {
    # O código de resultado da última execução, em português.
    param ($Code)

    if ($null -eq $Code) {
        return ""
    }

    switch ([int64]$Code) {
        0       { return "terminou bem" }
        267009  { return "em execução agora" }
        267011  { return "ainda não executou" }
        267014  { return "foi interrompida" }
        default { return "terminou com o código 0x$(([int64]$Code).ToString('X'))" }
    }
}


function Get-WinForgeScheduleStatus {
    <#
    O estado da tarefa no Agendador de Tarefas. Installed é falso quando ela não existe (ou quando o Agendador não pôde
    ser consultado). Day é o dia do mês; LastRun e NextRun são $null quando não houve/não há execução marcada.
    #>
    $status = [PSCustomObject]@{ Installed = $false; Enabled = $false; Day = $null; LastRun = $null; LastResult = $null; NextRun = $null }

    try {
        $task = Get-ScheduledTask -TaskPath $script:WinForgeSchedulePath -TaskName $script:WinForgeScheduleName -ErrorAction Stop
    }
    catch {
        return $status
    }

    if ($null -eq $task) {
        return $status
    }

    $status.Installed = $true
    $status.Enabled = ([string]$task.State -ne "Disabled")

    try {
        $xml = New-Object System.Xml.XmlDocument
        $xml.LoadXml([string](Export-ScheduledTask -TaskPath $script:WinForgeSchedulePath -TaskName $script:WinForgeScheduleName -ErrorAction Stop))
        $day = $xml.SelectSingleNode("//*[local-name()='DaysOfMonth']/*[local-name()='Day']")

        if ($null -ne $day) { $status.Day = [int]$day.InnerText }
    }
    catch {
        # O dia é informação extra; a tarefa continua instalada.
    }

    try {
        $info = Get-ScheduledTaskInfo -TaskPath $script:WinForgeSchedulePath -TaskName $script:WinForgeScheduleName -ErrorAction Stop

        # O Agendador usa datas antigas (1999/2000) para "nunca".
        if ($info.LastRunTime -is [datetime] -and $info.LastRunTime.Year -ge 2001) { $status.LastRun = $info.LastRunTime }
        if ($info.NextRunTime -is [datetime] -and $info.NextRunTime.Year -ge 2001) { $status.NextRun = $info.NextRunTime }

        $status.LastResult = $info.LastTaskResult
    }
    catch {
        # Sem os detalhes da execução, mostra só que está agendada.
    }

    return $status
}


function Register-WinForgeScheduledMaintenance {
    # Cria (ou troca) a tarefa mensal. Devolve um WinForge.Result.
    param (
        [Parameter(Mandatory)]
        [ValidateRange(1, 28)]
        [int]$Day
    )

    if (-not (Test-WinForgeElevation -Reason "Criar a tarefa agendada exige privilégios de Administrador.")) {
        return (New-WinForgeResult -Kind Failed -Detail "requer Administrador")
    }

    try {
        $user = Get-WinForgeScheduleUser

        if ([string]::IsNullOrWhiteSpace($user)) {
            throw "Não foi possível descobrir qual usuário está usando o PC."
        }

        $command = Get-WinForgeScheduleCommand
        $xml = New-WinForgeScheduleTaskXml -Executable $command.Executable -Arguments $command.Arguments -WorkingDirectory $command.WorkingDirectory -UserId $user -DayOfMonth $Day

        [void](Register-ScheduledTask -Xml $xml -TaskPath $script:WinForgeSchedulePath -TaskName $script:WinForgeScheduleName -Force -ErrorAction Stop)
    }
    catch {
        Write-WinForgeStatus -Type Error -Message "Não foi possível criar a tarefa agendada: $($_.Exception.Message)"
        return (New-WinForgeResult -Kind Failed -Detail $_.Exception.Message)
    }

    Write-WinForgeStatus -Type Success -Message "Manutenção agendada para todo dia $Day, às $($script:WinForgeScheduleHour)h, com a conta $user."

    return (New-WinForgeResult -Kind Ok -Data @{ Day = $Day })
}


function Unregister-WinForgeScheduledMaintenance {
    # Apaga a tarefa. Devolve um WinForge.Result.
    if (-not (Test-WinForgeElevation -Reason "Remover a tarefa agendada exige privilégios de Administrador.")) {
        return (New-WinForgeResult -Kind Failed -Detail "requer Administrador")
    }

    try {
        Unregister-ScheduledTask -TaskPath $script:WinForgeSchedulePath -TaskName $script:WinForgeScheduleName -Confirm:$false -ErrorAction Stop
    }
    catch {
        Write-WinForgeStatus -Type Error -Message "Não foi possível remover a tarefa agendada: $($_.Exception.Message)"
        return (New-WinForgeResult -Kind Failed -Detail $_.Exception.Message)
    }

    Write-WinForgeStatus -Type Success -Message "Manutenção agendada removida. Nada mais vai rodar sozinho."

    return (New-WinForgeResult -Kind Ok)
}


# ---------------------------------------------------------------------------
# A execução (chamada pela tarefa, sem ninguém olhando)
# ---------------------------------------------------------------------------

function Get-WinForgeScheduledRunPath {
    return (Join-Path (Get-WinForgeDataPath) "scheduled-maintenance.json")
}


function Get-WinForgeScheduledRun {
    # O registro da última execução automática (quando, quanto liberou, onde está o relatório). $null se nunca rodou.
    try {
        $path = Get-WinForgeScheduledRunPath

        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            return $null
        }

        $document = Get-Content -LiteralPath $path -Raw -Encoding UTF8 -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop

        return [PSCustomObject]@{
            RunAt      = [datetime]::Parse([string]$document.RunAt, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind)
            Kind       = [string]$document.Kind
            FreedBytes = [int64]$document.FreedBytes
            Report     = [string]$document.Report
        }
    }
    catch {
        return $null
    }
}


function Invoke-WinForgeScheduledMaintenance {
    <#
    O que a tarefa agendada executa: limpa os temporários do usuário (e os do Windows, se por acaso estiver com
    privilégios de Administrador) e salva o relatório. Nunca pergunta nada, nunca esvazia a Lixeira. Devolve um
    WinForge.Result e grava o registro da execução.
    #>
    $runAt = Get-Date
    $parts = @()

    Write-WinForgeSection -Title "Manutenção agendada"

    $parts += Clear-WinForgeUserTemp -Embedded -PassThru

    if (Test-WinForgeAdministrator) {
        $parts += Clear-WinForgeWindowsTemp -Embedded -PassThru
    }

    $freed = [int64]0

    foreach ($part in $parts) {
        $partFreed = Get-WinForgeResultData -Result $part -Name "FreedBytes"
        if ($null -ne $partFreed) { $freed += [int64]$partFreed }
    }

    $reportPath = ""
    $reportFailed = $false

    try {
        $report = Export-WinForgeReport
        $reportPath = [string]$report.Html
        Write-WinForgeStatus -Type Success -Message "Relatório salvo em: $reportPath"
    }
    catch {
        $reportFailed = $true
        Write-WinForgeStatus -Type Warning -Message "Não foi possível salvar o relatório: $($_.Exception.Message)"
    }

    $failed = @($parts | Where-Object { $_.Kind -eq "Failed" })

    if ($failed.Count -eq 0 -and -not $reportFailed) {
        $result = New-WinForgeResult -Kind Ok -Detail "liberou $(Format-WinForgeBytes -Bytes $freed)" -Data @{ FreedBytes = $freed; Report = $reportPath }
    }
    else {
        $result = New-WinForgeResult -Kind Warning -Detail "parte do trabalho falhou" -Data @{ FreedBytes = $freed; Report = $reportPath }
    }

    try {
        $document = [ordered]@{
            RunAt      = $runAt.ToString("o", [System.Globalization.CultureInfo]::InvariantCulture)
            Kind       = $result.Kind
            FreedBytes = $freed
            Report     = $reportPath
        }

        Set-Content -LiteralPath (Get-WinForgeScheduledRunPath) -Value ($document | ConvertTo-Json) -Encoding UTF8 -ErrorAction Stop
    }
    catch {
        # O registro é um complemento da tela; a limpeza e o relatório já foram feitos.
    }

    $result.Etapa = "Manutenção agendada"

    return $result
}


# ---------------------------------------------------------------------------
# A tela
# ---------------------------------------------------------------------------

function Show-WinForgeScheduledMaintenance {
    Enter-WinForgeAction -Title "Manutenção agendada"

    try {
        Write-Host "Todo mês o Windows roda sozinho uma manutenção leve e salva um relatório. É opcional e você remove quando quiser." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Faz: limpa os temporários do seu usuário e salva o relatório na pasta de relatórios do WinForge." -ForegroundColor Cyan
        Write-Host "Não faz: esvaziar a Lixeira, reparar o Windows, atualizar programas ou mudar ajustes." -ForegroundColor Cyan
        Write-Host "Roda sem Administrador e só com você logado; se o PC estiver desligado no dia, roda quando for ligado." -ForegroundColor DarkGray

        $status = Get-WinForgeScheduleStatus

        Write-WinForgeSection -Title "Situação"

        if (-not $status.Installed) {
            Write-WinForgeKeyValue -Label "Agendamento" -Value "Não agendado"
        }
        else {
            $when = $(if ($null -ne $status.Day) { "todo dia $($status.Day), às $($script:WinForgeScheduleHour)h" } else { "mensal" })
            Write-WinForgeKeyValue -Label "Agendamento" -Value $(if ($status.Enabled) { "Ativo ($when)" } else { "Desativado no Agendador de Tarefas ($when)" })

            if ($null -ne $status.NextRun) {
                Write-WinForgeKeyValue -Label "Próxima execução" -Value $status.NextRun.ToString("dd/MM/yyyy HH:mm")
            }
        }

        $lastRun = Get-WinForgeScheduledRun

        if ($null -ne $lastRun) {
            Write-WinForgeKeyValue -Label "Última execução" -Value "$($lastRun.RunAt.ToString('dd/MM/yyyy HH:mm')) ($(Format-WinForgeRelativeTime -When $lastRun.RunAt)), liberou $(Format-WinForgeBytes -Bytes $lastRun.FreedBytes)"
        }
        elseif ($status.Installed -and $null -ne $status.LastRun) {
            Write-WinForgeKeyValue -Label "Última execução" -Value "$($status.LastRun.ToString('dd/MM/yyyy HH:mm')), $(ConvertTo-WinForgeScheduleResultText -Code $status.LastResult)"
        }
        elseif ($status.Installed) {
            Write-WinForgeKeyValue -Label "Última execução" -Value "Ainda não executou"
        }

        Write-Host ""

        $options = @()

        foreach ($day in $script:WinForgeScheduleDays) {
            $current = ($status.Installed -and $status.Day -eq $day)
            $label = $(if ($current) { "Todo dia $day (atual)" } else { "Todo dia $day" })

            $options += @{ Key = "D$day"; Label = $label; Accent = ($day -eq $script:WinForgeScheduleDays[0] -and -not $status.Installed) }
        }

        if ($status.Installed) {
            $options += @{ Key = "R"; Label = "Remover o agendamento" }
        }

        $options += @{ Key = "V"; Label = "Voltar"; Exit = $true }

        $message = $(if ($status.Installed) { "O que deseja fazer?" } else { "Em que dia do mês a manutenção deve rodar?" })
        $choice = Read-WinForgeChoice -Message $message -Options $options -DefaultKey "V" -ShowMenu

        Write-Host ""

        if ($choice -match '^D([0-9]+)$') {
            [void](Register-WinForgeScheduledMaintenance -Day ([int]$Matches[1]))
        }
        elseif ($choice -eq "R") {
            [void](Unregister-WinForgeScheduledMaintenance)
        }
    }
    catch {
        Write-WinForgeStatus -Type Error -Message "Ocorreu um erro na manutenção agendada: $($_.Exception.Message)"
    }

    Exit-WinForgeAction
}


Export-ModuleMember -Function *
