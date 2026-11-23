# Gerenciar o que abre junto com o Windows, sem sair do WinForge. Desativar aqui é exatamente o que o Gerenciador de
# Tarefas e as Configurações fazem, então o item continua listado neles e pode ser reativado em qualquer lugar:
# - chaves Run e pastas Inicializar: o valor binário de 12 bytes em StartupApproved (a entrada Run e o atalho ficam
#   intactos; nada é apagado);
# - aplicativos da Store (Teams, Spotify, WhatsApp...): o State da tarefa de inicialização do pacote (1 = desativado
#   pela pessoa, 2 = ativado), como as Configurações gravam;
# - tarefas agendadas de outros fabricantes que só rodam ao entrar no Windows ou ao ligar o PC: desativadas no
#   Agendador de Tarefas, de onde também podem ser reativadas.
# O que sobrou de um programa desinstalado (a entrada Run ou o atalho cujo programa não existe mais, ou o Update.exe do
# Squirrel sem o programa: Get-WinForgeStartupItems -Leftovers) não abre nada; desativar não mudaria nada, e o item sai
# da inicialização (Remove-WinForgeStartupLeftover). É o único caso em que algo é apagado aqui.
# Depois de cada mudança, o estado é lido de novo no Windows: só conta como feito o que o Windows manteve. A lista mostra
# só o que o WinForge consegue mudar agora (veja Set-WinForgeStartupItems); o texto na tela fica curto de propósito.

# Códigos gravados no histórico de mudanças (não aparecem na tela): ficam em português em qualquer idioma.
$script:WinForgeStartupTaskSource = "Tarefa agendada"
$script:WinForgeStartupAppSource = "Aplicativo da Store"

# Por que a última leitura do Agendador de Tarefas (Get-WinForgeStartupTasks) falhou; vazio quando leu.
$script:WinForgeStartupTasksProblem = ""


function New-WinForgeStartupApprovedValue {
    # Os 12 bytes de StartupApproved: primeiro byte 02 = ativado; 03 = desativado, seguido da hora (FILETIME, 8 bytes)
    # em que foi desativado.
    param (
        [Parameter(Mandatory)]
        [bool]$Enabled,

        [datetime]$At = [datetime]::UtcNow
    )

    $bytes = New-Object byte[] 12

    if ($Enabled) {
        $bytes[0] = 2
        return , $bytes
    }

    $bytes[0] = 3
    $stamp = [BitConverter]::GetBytes([int64]$At.ToUniversalTime().ToFileTimeUtc())

    for ($i = 0; $i -lt 8; $i++) {
        $bytes[4 + $i] = $stamp[$i]
    }

    return , $bytes
}


function Set-WinForgeStartupItemEnabled {
    # Liga ou desliga um item (objeto de Get-WinForgeStartupItems). Itens de todos os usuários pedem Administrador.
    param (
        [Parameter(Mandatory)]
        $Item,

        [Parameter(Mandatory)]
        [bool]$Enabled
    )

    if ($Item.Scope -eq "Machine" -and -not (Test-WinForgeAdministrator)) {
        throw (Get-WinForgeText 'este item vale para todos os usuários e exige Administrador')
    }

    # Elevado com outra conta, o HKCU, a pasta Inicializar e as tarefas "da própria conta" são os dessa conta, não os da
    # pessoa logada: mudar ali seria mexer no perfil errado.
    if ($Item.Scope -eq "User" -and (Test-WinForgeStartupOtherAccount)) {
        throw (Get-WinForgeText 'este item vale só para uma conta, e o WinForge está elevado com outra conta')
    }

    if ([string]$Item.Source -eq $script:WinForgeStartupTaskSource) {
        $taskPath = [string](Get-WinForgeJsonValue -Object $Item -Name "TaskPath" -Default "\")
        $taskName = [string](Get-WinForgeJsonValue -Object $Item -Name "TaskName" -Default $Item.Name)

        # Com prazo (Invoke-WinForgeCimCommand): o Agendador de Tarefas sem resposta deixava a tela parada sem fim.
        [void](Invoke-WinForgeCimCommand -Name $(if ($Enabled) { "Enable-ScheduledTask" } else { "Disable-ScheduledTask" }) -Parameters @{ TaskPath = $taskPath; TaskName = $taskName })

        return
    }

    if ([string]$Item.Source -eq $script:WinForgeStartupAppSource) {
        $path = [string]$Item.ApprovedPath

        if (-not (Test-WinForgeStartupAppPath -Path $path)) {
            throw (Get-WinForgeText 'não foi possível localizar onde o Windows guarda o estado deste item')
        }

        # Confere antes de gravar: a tarefa pode ter sumido (o aplicativo foi desinstalado) ou passado para uma política
        # (3 e 4), que só o administrador muda; gravar por cima disso seria um ajuste de mentira.
        $current = Get-WinForgeRegistryValueOrNull -Path $path -Name "State"

        if ($null -eq $current) { throw (Get-WinForgeText 'o Windows não tem mais este item') }
        if (-not ($current -is [int]) -or @(0, 1, 2) -notcontains [int]$current) { throw (Get-WinForgeText 'uma política do Windows controla este item') }

        # 1 = desativado pela pessoa, o mesmo que o Gerenciador de Tarefas grava: o aplicativo não consegue se religar
        # sozinho. 2 = ativado.
        Set-WinForgeRegistryDWord -Path $path -Name "State" -Value $(if ($Enabled) { 2 } else { 1 })

        return
    }

    if ([string]::IsNullOrWhiteSpace($Item.ApprovedPath)) {
        throw (Get-WinForgeText 'não foi possível localizar onde o Windows guarda o estado deste item')
    }

    Set-WinForgeRegistryBinary -Path $Item.ApprovedPath -Name $Item.Name -Value (New-WinForgeStartupApprovedValue -Enabled $Enabled)
}


function Remove-WinForgeStartupLeftover {
    <#
    Tira da inicialização um item que sobrou de um programa desinstalado (de Get-WinForgeStartupItems -Leftovers): o valor
    da chave Run, só se ainda for o mesmo comando e o programa continuar fora do PC, ou o atalho da pasta Inicializar, que
    vai para a Lixeira; e a marca de liga/desliga dele em StartupApproved, para o Gerenciador de Tarefas e as
    Configurações não mostrarem mais nada. Um item que já não está lá conta como tirado. Lança erro com o motivo quando ele
    fica.
    #>
    param ([Parameter(Mandatory)]$Item)

    if ($Item.Scope -eq "Machine" -and -not (Test-WinForgeAdministrator)) {
        throw (Get-WinForgeText 'este item vale para todos os usuários e exige Administrador')
    }

    if ($Item.Scope -eq "User" -and (Test-WinForgeStartupOtherAccount)) {
        throw (Get-WinForgeText 'este item vale só para uma conta, e o WinForge está elevado com outra conta')
    }

    $name = [string]$Item.Name

    if ([string]$Item.Source -eq "Pasta Inicializar") {
        $path = [string]$Item.Command

        # Só um atalho direto na pasta Inicializar do Windows de onde ele veio (a da conta, ou a de todos os usuários).
        $cut = $path.LastIndexOf('\')
        $folder = $(if ($cut -gt 0) { $path.Substring(0, $cut) } else { "" })
        $known = @(Get-WinForgeStartupFolders | Where-Object { $_.Scope -eq [string]$Item.Scope -and -not [string]::IsNullOrWhiteSpace([string]$_.Path) })

        if ([IO.Path]::GetExtension($path) -ine ".lnk" -or @($known | Where-Object { [string]::Equals(([string]$_.Path).TrimEnd('\'), $folder, [StringComparison]::OrdinalIgnoreCase) }).Count -eq 0) {
            throw (Get-WinForgeText 'o item não é um atalho da pasta Inicializar')
        }

        if (Test-Path -LiteralPath $path -PathType Leaf) {
            # Confere de novo antes de tirar: o programa pode ter voltado desde a leitura.
            if (-not (Get-WinForgeStartupLeftoverReason -Command $path -Shortcut)) { throw (Get-WinForgeText 'o programa voltou ao PC; o item ficou') }

            Move-WinForgeItemToRecycleBin -Path $path
        }
    }
    else {
        # Só as chaves Run que a lista lê.
        $key = [string](Get-WinForgeJsonValue -Object $Item -Name "RunKey" -Default "")
        $run = "Microsoft\Windows\CurrentVersion\Run"

        if (@("HKCU:\Software\$run", "HKLM:\SOFTWARE\$run", "HKLM:\SOFTWARE\WOW6432Node\$run") -notcontains $key) {
            throw (Get-WinForgeText 'não foi possível localizar onde o Windows guarda este item')
        }

        $values = Get-WinForgeRegistryValues -Path $key

        if ($values.Contains($name)) {
            # Só sai o mesmo comando que a lista mostrou, e ainda sem o programa.
            if ([string]$values[$name] -cne [string]$Item.Command) { throw (Get-WinForgeText 'o item mudou desde a leitura; ficou como está') }
            if (-not (Get-WinForgeStartupLeftoverReason -Command ([string]$values[$name]))) { throw (Get-WinForgeText 'o programa voltou ao PC; o item ficou') }

            Remove-ItemProperty -LiteralPath $key -Name $name -ErrorAction Stop
        }
    }

    # A marca de liga/desliga do item: sozinha, ela não aparece em lugar nenhum, e uma que não sai não muda o resultado.
    $approvedPath = [string]$Item.ApprovedPath

    if ($approvedPath -and (Get-WinForgeRegistryValues -Path $approvedPath).Contains($name)) {
        try {
            Remove-ItemProperty -LiteralPath $approvedPath -Name $name -ErrorAction Stop
        }
        catch {
            Write-Verbose "StartupApproved de ${name}: $($_.Exception.Message)"
        }
    }
}


function Get-WinForgeStartupFolders {
    # As pastas Inicializar do Windows: a da conta (Scope User) e a de todos os usuários (Machine).
    return @(
        [PSCustomObject]@{ Scope = "User"; Path = [Environment]::GetFolderPath("Startup") }
        [PSCustomObject]@{ Scope = "Machine"; Path = [Environment]::GetFolderPath("CommonStartup") }
    )
}


function Test-WinForgeStartupLeftoverGone {
    # Se um item que sobrou (de Get-WinForgeStartupItems -Leftovers) saiu de fato da inicialização: o atalho não está
    # mais na pasta, ou o valor não está mais na chave Run.
    param ([Parameter(Mandatory)]$Item)

    if ([string]$Item.Source -eq "Pasta Inicializar") { return (-not (Test-Path -LiteralPath ([string]$Item.Command))) }

    return (-not (Get-WinForgeRegistryValues -Path ([string](Get-WinForgeJsonValue -Object $Item -Name "RunKey" -Default ""))).Contains([string]$Item.Name))
}


function Get-WinForgeStartupLeftoverText {
    # A descrição curta de um item que sobrou, na lista de tirar: o que falta ("steam.exe não existe mais", ou que só
    # sobrou o Update.exe) e "todos os usuários" quando vale para o PC inteiro.
    param ([Parameter(Mandatory)]$Item)

    $parts = @()

    if ([string](Get-WinForgeJsonValue -Object $Item -Name "Leftover" -Default "") -eq "launcher") {
        $parts += (Get-WinForgeText 'só sobrou o Update.exe; o programa foi desinstalado')
    }
    else {
        $file = Get-WinForgeStartupFileName -Item $Item
        $parts += $(if ($file) { (Get-WinForgeText '{0} não existe mais' "$file") } else { (Get-WinForgeText 'o programa não existe mais') })
    }

    if ($Item.Scope -eq "Machine") { $parts += (Get-WinForgeText 'todos os usuários') }

    return ($parts -join " · ")
}


function Remove-WinForgeStartupLeftovers {
    <#
    Tira da inicialização os itens que sobraram de programas desinstalados (os marcados na lista), confere cada um no
    Windows e anota no Histórico de mudanças, sem desfazer: o item não abria nada, e o programa, se voltar a ser instalado,
    põe o dele de novo. Devolve o WinForge.Result, com a faixa.
    #>
    param (
        [object[]]$Items = @(),
        [Parameter(Mandatory)][string]$Title
    )

    $removed = @()
    $problems = @()

    foreach ($item in @($Items)) {
        $label = Get-WinForgeStartupDisplayName -Item $item

        try {
            Remove-WinForgeStartupLeftover -Item $item

            if (Test-WinForgeStartupLeftoverGone -Item $item) {
                $removed += $label
                Write-WinForgeStatus -Type Success -Message (Get-WinForgeText '{0}: removido da inicialização.' "$label")
            }
            else {
                $problems += [PSCustomObject]@{ Name = $label; Detail = (Get-WinForgeText 'o Windows não manteve a mudança') }
                Write-WinForgeStatus -Type Error -Message (Get-WinForgeText '{0}: o Windows não manteve a mudança.' "$label")
            }
        }
        catch {
            $problems += [PSCustomObject]@{ Name = $label; Detail = $_.Exception.Message.TrimEnd('.') }
            Write-WinForgeStatus -Type Error -Message "${label}: $($_.Exception.Message.TrimEnd('.'))."
        }
    }

    Write-Host ""

    if ($removed.Count -gt 0) {
        $text = $(if ($removed.Count -eq 1) { (Get-WinForgeText '{0} removido (o programa não estava mais no PC)' "$($removed[0])") } else { (Get-WinForgeText '{0} itens removidos (os programas não estavam mais no PC): {1}' "$($removed.Count)" "$(Join-WinForgeList -Items $removed)") })
        [void](Add-WinForgeChange -Action (Get-WinForgeText 'Inicialização') -Text $text)
    }

    $total = @($Items).Count
    $names = Join-WinForgeList -Items @($problems | ForEach-Object { $_.Name })

    if ($problems.Count -eq 0) {
        $detail = $(if ($removed.Count -eq 1) { (Get-WinForgeText '1 item removido da inicialização') } else { (Get-WinForgeText '{0} itens removidos da inicialização' "$($removed.Count)") })
        $final = New-WinForgeResult -Kind Ok -Detail $detail -Title $Title
        $headline = $(if ($removed.Count -eq 1) { (Get-WinForgeText '{0} removido da inicialização' "$($removed[0])") } else { $detail })
        $note = $(if ($removed.Count -eq 1) { (Get-WinForgeText 'Ele não abria nada: o programa não estava mais no PC.') } else { (Get-WinForgeText 'Eles não abriam nada: os programas não estavam mais no PC.') })
        return (Set-WinForgeResultView -Result $final -Headline $headline -Note $note)
    }

    if ($removed.Count -eq 0) {
        $detail = $(if ($total -eq 1) { (Get-WinForgeText '{0} não foi removido: {1}' "$names" "$($problems[0].Detail)") } else { (Get-WinForgeText 'nenhum item foi removido: {0}' "$names") })
        return (New-WinForgeResult -Kind Failed -Detail $detail -Title $Title)
    }

    $verbText = $(if ($problems.Count -eq 1) { (Get-WinForgeText 'não foi removido') } else { (Get-WinForgeText 'não foram removidos') })
    return (New-WinForgeResult -Kind Warning -Detail (Get-WinForgeText '{0} de {1} {2}: {3}' "$($problems.Count)" "$total" "${verbText}" "$names") -Title $Title)
}


function Test-WinForgeStartupAppPath {
    # Se o caminho é a chave de uma tarefa de inicialização de aplicativo da Store (SystemAppData\<família>\<tarefa>) da
    # conta. O Histórico de mudanças guarda o caminho num arquivo que qualquer programa da conta grava: só isto é aceito.
    param ([AllowEmptyString()][string]$Path)

    $root = "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\SystemAppData\"
    $text = [string]$Path

    if (-not $text.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) { return $false }

    return ($text.Substring($root.Length) -match '^[^\\]+\\[^\\]+$')
}


function Test-WinForgeStartupOtherAccount {
    # Se o WinForge está elevado com uma conta diferente da que está logada no Windows.
    try {
        return [bool](Get-WinForgeJsonValue -Object (Get-WinForgeSessionInfo) -Name "UserMismatch" -Default $false)
    }
    catch {
        return $false
    }
}


function Get-WinForgeStartupItemEnabled {
    <#
    Lê no Windows se um item está ligado, procurando só ele: a tarefa pelo caminho e pelo nome (duas tarefas podem ter o
    mesmo nome em pastas diferentes), o aplicativo da Store pela chave da tarefa dele e os demais pelo valor deles em
    StartupApproved (as pastas Inicializar do usuário e de todos os usuários têm a mesma origem, "Pasta Inicializar").
    $null quando não dá para ler.
    #>
    param (
        [Parameter(Mandatory)]
        $Item
    )

    if ([string]$Item.Source -eq $script:WinForgeStartupTaskSource) {
        $taskPath = [string](Get-WinForgeJsonValue -Object $Item -Name "TaskPath" -Default "\")
        $taskName = [string](Get-WinForgeJsonValue -Object $Item -Name "TaskName" -Default $Item.Name)

        try {
            $task = @(Invoke-WinForgeCimCommand -Name "Get-ScheduledTask" -Parameters @{ TaskPath = $taskPath; TaskName = $taskName }) | Select-Object -First 1
        }
        catch {
            return $null
        }

        if ($null -eq $task) {
            return $null
        }

        return ([string]$task.State -ne "Disabled")
    }

    # Aplicativo da Store: o State da tarefa (2 = ativado, 4 = ativado por política; o resto não abre).
    if ([string]$Item.Source -eq $script:WinForgeStartupAppSource) {
        if (-not (Test-WinForgeStartupAppPath -Path ([string]$Item.ApprovedPath))) { return $null }

        $state = Get-WinForgeRegistryValueOrNull -Path ([string]$Item.ApprovedPath) -Name "State"

        if (-not ($state -is [int])) { return $null }

        return (@(2, 4) -contains [int]$state)
    }

    if ([string]::IsNullOrWhiteSpace([string]$Item.ApprovedPath)) {
        return $null
    }

    # Sem valor em StartupApproved, o Windows considera o item ligado; primeiro byte ímpar = desligado.
    $approved = Get-WinForgeRegistryValues -Path $Item.ApprovedPath
    $name = [string]$Item.Name

    if (-not $approved.Contains($name)) {
        return $true
    }

    $bytes = @($approved[$name])

    return -not ($bytes.Count -gt 0 -and ([int]$bytes[0] -band 1) -eq 1)
}


function Get-WinForgeStartupAccountKind {
    <#
    De quem é uma conta de tarefa agendada (o dono da tarefa ou o usuário de um gatilho de logon): "Current" (a conta
    que roda o WinForge), "Other" (outra pessoa deste PC ou do domínio: SID S-1-5-21-...) ou "Shared" (vazio, SYSTEM,
    serviços, grupos como Usuários).
    #>
    param (
        [AllowEmptyString()][string]$Account,
        [AllowEmptyString()][string]$User,
        [AllowEmptyString()][string]$Sid
    )

    $text = ([string]$Account).Trim()

    if (-not $text) { return "Shared" }

    if (($Sid -and $text -eq $Sid) -or ($User -and ($text -eq $User -or $text.EndsWith("\$User", [System.StringComparison]::OrdinalIgnoreCase)))) {
        return "Current"
    }

    $accountSid = $text

    if ($text -notmatch '^S-1-[0-9-]+$') {
        try {
            $accountSid = (New-Object System.Security.Principal.NTAccount -ArgumentList $text).Translate([System.Security.Principal.SecurityIdentifier]).Value
        }
        catch {
            $accountSid = ""
        }
    }

    if ($accountSid -like "S-1-5-21-*") {
        return $(if ($Sid -and $accountSid -eq $Sid) { "Current" } else { "Other" })
    }

    return "Shared"
}


function Get-WinForgeStartupTasks {
    <#
    As tarefas agendadas que não são do Windows e rodam ao entrar no Windows (gatilho de logon) ou ao ligar o PC (gatilho
    de inicialização), no formato dos itens de Get-WinForgeStartupItems, com TaskPath e TaskName. Sem acesso ao
    Agendador, nenhuma. Ficam de fora:
    - as da pasta \Microsoft\: são do próprio Windows;
    - as que também rodam em outros horários (todo dia, a cada hora...), como a maioria dos atualizadores: desativar a
      tarefa pararia tudo, não só a inicialização, e o programa deixaria de se atualizar. Já desativadas, continuam na
      lista, para poderem ser reativadas (também pelo Histórico de mudanças);
    - as de outra pessoa do PC (dona da tarefa ou única conta dos gatilhos de logon): mexer seria mudar o perfil dela;
    - as que abrem um arquivo que com certeza não existe mais: não abrem nada.
    Gatilhos desligados não contam. Quando o Agendador não responde, o motivo fica em Get-WinForgeStartupTasksProblem:
    a tela diz que as tarefas faltaram, em vez de mostrar a lista sem elas como se fosse tudo.
    #>
    $script:WinForgeStartupTasksProblem = ""

    if ($null -eq (Get-Command -Name "Get-ScheduledTask" -ErrorAction SilentlyContinue)) { return @() }

    try {
        # Com prazo (Invoke-WinForgeCimCommand): o Agendador de Tarefas sem resposta deixava a tela parada sem fim.
        $tasks = @(Invoke-WinForgeCimCommand -Name "Get-ScheduledTask")
    }
    catch {
        $script:WinForgeStartupTasksProblem = ([string]$_.Exception.Message).Trim().TrimEnd('.')
        return @()
    }

    $user = [string]$env:USERNAME
    $sid = ""

    try { $sid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value } catch { $sid = "" }

    $items = @()

    foreach ($task in $tasks) {
        if ($null -eq $task) { continue }

        $path = [string]$task.TaskPath

        if ($path -like "\Microsoft\*") { continue }

        $atStart = @()
        $otherTriggers = 0
        $othersOnly = $true

        foreach ($trigger in @($task.Triggers | Where-Object { $null -ne $_ })) {
            if (-not [bool](Get-WinForgeJsonValue -Object $trigger -Name "Enabled" -Default $true)) { continue }

            $class = ""
            try { $class = [string]$trigger.CimClass.CimClassName } catch { $class = "" }

            if ($class -ne "MSFT_TaskLogonTrigger" -and $class -ne "MSFT_TaskBootTrigger") {
                $otherTriggers++
                continue
            }

            $atStart += $trigger

            # Um gatilho de logon só de outra pessoa não abre nada quando esta conta entra.
            $triggerUser = [string](Get-WinForgeJsonValue -Object $trigger -Name "UserId" -Default "")

            if ($class -eq "MSFT_TaskBootTrigger" -or (Get-WinForgeStartupAccountKind -Account $triggerUser -User $user -Sid $sid) -ne "Other") {
                $othersOnly = $false
            }
        }

        if ($atStart.Count -eq 0 -or $othersOnly) { continue }

        $state = [string]$task.State

        if ($otherTriggers -gt 0 -and $state -ne "Disabled") { continue }

        $owner = ""
        try { $owner = [string]$task.Principal.UserId } catch { $owner = "" }
        $ownerKind = Get-WinForgeStartupAccountKind -Account $owner -User $user -Sid $sid

        if ($ownerKind -eq "Other") { continue }

        $action = @($task.Actions | Where-Object { $null -ne $_ -and -not [string]::IsNullOrWhiteSpace([string](Get-WinForgeJsonValue -Object $_ -Name "Execute" -Default "")) }) | Select-Object -First 1
        $execute = $(if ($null -ne $action) { ([string]$action.Execute).Trim() } else { "" })
        $command = $(if ($null -ne $action) { ("$execute $([string](Get-WinForgeJsonValue -Object $action -Name 'Arguments' -Default ''))").Trim() } else { "" })

        if ($execute -and (Test-WinForgeStartupTargetMissing -Command ('"' + $execute.Trim('"') + '"'))) { continue }

        # Tarefa da própria conta: a pessoa consegue ligar e desligar sem Administrador; as demais pedem.
        $scope = $(if ($ownerKind -eq "Current") { "User" } else { "Machine" })

        $items += [PSCustomObject]@{
            Name = [string]$task.TaskName; Source = $script:WinForgeStartupTaskSource; Enabled = ($state -ne "Disabled")
            Command = $command; Scope = $scope; ApprovedPath = ""; TaskPath = $path; TaskName = [string]$task.TaskName
        }
    }

    return @($items)
}


function Get-WinForgeStartupTasksProblem {
    # Por que a última leitura das tarefas agendadas (Get-WinForgeStartupTasks) falhou; vazio quando leu.
    return [string]$script:WinForgeStartupTasksProblem
}


function Get-WinForgeStartupPublisher {
    # Quem publica o programa de um item (CompanyName do executável): "Google LLC", "Microsoft Corporation". Vazio se não
    # der para saber. Atalhos da pasta Inicializar são seguidos até o programa.
    param ([Parameter(Mandatory)]$Item)

    try {
        $command = [string]$Item.Command

        if ([string]$Item.Source -eq "Pasta Inicializar" -and $command -like "*.lnk") {
            $link = Get-WinForgeShortcutTarget -Path $command
            $command = $(if ($null -ne $link) { [string]$link.TargetPath } else { "" })
        }

        $path = Get-WinForgeCommandTargetPath -Command $command

        if ([string]::IsNullOrWhiteSpace($path) -or -not (Test-Path -LiteralPath $path -PathType Leaf)) { return "" }

        return ([string](Get-Item -LiteralPath $path -ErrorAction Stop).VersionInfo.CompanyName).Trim()
    }
    catch {
        return ""
    }
}


function Get-WinForgeStartupAdvice {
    <#
    O conselho que vai na descrição de um item quando a pessoa escolhe o que desativar: "antivírus; deixe ligado", "do
    Windows; melhor deixar ligado" (o programa fica na pasta do Windows) ou "do hardware do PC; na dúvida, deixe ligado"
    (som, touchpad, vídeo: os fabricantes mais comuns). "" para os outros.
    #>
    param ([Parameter(Mandatory)]$Item)

    $publisher = [string](Get-WinForgeJsonValue -Object $Item -Name "Publisher" -Default "")
    $name = [string](Get-WinForgeJsonValue -Object $Item -Name "Name" -Default "")
    $who = "$publisher $name"

    if ($who -match '(?i)\b(Avast|AVG|Kaspersky|Norton|NortonLifeLock|Gen Digital|McAfee|ESET|Bitdefender|Avira|Trend Micro|Sophos|Malwarebytes|Panda Security|F-Secure|Webroot)\b') {
        return (Get-WinForgeText 'antivírus; deixe ligado')
    }

    $windows = $(if (-not [string]::IsNullOrWhiteSpace($env:WINDIR)) { $env:WINDIR } else { [string]$env:SystemRoot })
    $command = ([Environment]::ExpandEnvironmentVariables([string](Get-WinForgeJsonValue -Object $Item -Name "Command" -Default ""))).Trim().TrimStart('"')

    if (-not [string]::IsNullOrWhiteSpace($windows) -and $command.StartsWith($windows.TrimEnd('\') + '\', [System.StringComparison]::OrdinalIgnoreCase)) {
        return (Get-WinForgeText 'do Windows; melhor deixar ligado')
    }

    if ($publisher -match '(?i)\b(Realtek|Synaptics|ELAN|Intel|NVIDIA|Advanced Micro Devices|AMD|Dolby|Conexant|Cirrus Logic|Waves|Alps)\b') {
        return (Get-WinForgeText 'do hardware do PC; na dúvida, deixe ligado')
    }

    return ""
}


function Get-WinForgeStartupEntries {
    # Tudo o que abre com o Windows para a tela Gerenciar inicialização: os itens das chaves Run, das pastas Inicializar e
    # dos aplicativos da Store, as tarefas agendadas de logon e de inicialização e, em cada um, quem publica o programa
    # (Publisher; o dos aplicativos da Store já vem do manifesto do pacote).
    $entries = @(@(Get-WinForgeStartupItems) + @(Get-WinForgeStartupTasks) | Where-Object { $null -ne $_ })

    foreach ($entry in $entries) {
        if ([string](Get-WinForgeJsonValue -Object $entry -Name "Publisher" -Default "")) { continue }

        $entry | Add-Member -NotePropertyName Publisher -NotePropertyValue (Get-WinForgeStartupPublisher -Item $entry) -Force
    }

    return @($entries)
}


function ConvertTo-WinForgeStartupUndoItem {
    # O que o Histórico de mudanças guarda de um item para devolvê-lo ao estado de antes (Enabled = como estava).
    param (
        [Parameter(Mandatory)]$Item,
        [Parameter(Mandatory)][bool]$Enabled
    )

    return [ordered]@{
        Name         = [string]$Item.Name
        Source       = [string]$Item.Source
        Scope        = [string]$Item.Scope
        ApprovedPath = [string]$Item.ApprovedPath
        TaskPath     = [string](Get-WinForgeJsonValue -Object $Item -Name "TaskPath" -Default "")
        TaskName     = [string](Get-WinForgeJsonValue -Object $Item -Name "TaskName" -Default "")
        Enabled      = $Enabled
    }
}


function Test-WinForgeStartupUndoable {
    <#
    Se o desfazer do Histórico de mudanças sabe devolver este item (o de ConvertTo-WinForgeStartupUndoItem). Chaves Run,
    pastas Inicializar e tarefas, sim; um aplicativo da Store só quando o desfazer (Test-WinForgeStartupUndoItem) aceitar
    a chave dele. Perguntar ao desfazer, em vez de supor, evita anotar um desfazer que depois falharia.
    #>
    param ([Parameter(Mandatory)]$Undo)

    if ([string]$Undo["Source"] -ne $script:WinForgeStartupAppSource) { return $true }

    try {
        return [bool](Test-WinForgeStartupUndoItem -Item ([PSCustomObject]$Undo))
    }
    catch {
        return $false
    }
}


function Get-WinForgeStartupJournalText {
    # O texto da linha do Histórico de mudanças (Items: Name e Enabled, o estado novo): "Chat desativado", "2 itens
    # desativados: Chat e Nuvem" ou "1 desativado (Chat) e 1 reativado (Antigo)".
    param ([object[]]$Items = @())

    $off = @($Items | Where-Object { -not $_.Enabled } | ForEach-Object { [string]$_.Name })
    $on = @($Items | Where-Object { $_.Enabled } | ForEach-Object { [string]$_.Name })
    $all = @($off) + @($on)

    if ($all.Count -eq 1) { return $(if ($on.Count -gt 0) { (Get-WinForgeText '{0} reativado' "$($all[0])") } else { (Get-WinForgeText '{0} desativado' "$($all[0])") }) }
    if ($off.Count -gt 0 -and $on.Count -gt 0) { return (Get-WinForgeStartupChangeText -Off $off -On $on -Names) }

    return $(if ($on.Count -gt 0) { (Get-WinForgeText '{0} itens reativados: {1}' "$($all.Count)" "$(Join-WinForgeList -Items $all)") } else { (Get-WinForgeText '{0} itens desativados: {1}' "$($all.Count)" "$(Join-WinForgeList -Items $all)") })
}


function Get-WinForgeStartupFileName {
    # O arquivo que um item abre ("steam.exe"), para a lista dizer o que é quando não se sabe quem publica. "" sem
    # comando e nos itens da pasta Inicializar (o nome do item já é o do arquivo, ou o do atalho).
    param ([Parameter(Mandatory)]$Item)

    $command = ([string](Get-WinForgeJsonValue -Object $Item -Name "Command" -Default "")).Trim()

    if (-not $command -or [string]$Item.Source -eq "Pasta Inicializar") { return "" }

    $target = Get-WinForgeCommandTargetPath -Command $command

    if (-not $target) {
        $target = $(if ($command.StartsWith('"')) { ($command.Substring(1) -split '"', 2)[0] } else { ($command -split '\s+', 2)[0] })
    }

    return ([string]($target -split '[\\/]')[-1]).Trim()
}


function Get-WinForgeStartupDisplayName {
    # O nome de um item como a tela mostra. O de um atalho da pasta Inicializar vem sem o ".lnk", que o Windows nunca mostra
    # (no Explorador, o atalho do Spotify se chama "Spotify"). Name continua o nome do arquivo: é com ele que o Windows
    # guarda o liga/desliga em StartupApproved.
    param ([Parameter(Mandatory)]$Item)

    $name = [string]$Item.Name

    if ([string]$Item.Source -eq "Pasta Inicializar" -and $name.Length -gt 4 -and $name.EndsWith(".lnk", [System.StringComparison]::OrdinalIgnoreCase)) {
        return $name.Substring(0, $name.Length - 4)
    }

    return $name
}


function New-WinForgeStartupChoices {
    <#
    As opções da lista de marcar de Gerenciar inicialização, uma por item, com o nome que a tela mostra
    (Get-WinForgeStartupDisplayName) e a descrição curta (Get-WinForgeStartupOptionText); Key é a posição do item em
    $Items. -Review (a revisão do Otimizar): o que abre hoje vem marcado, com o conselho de deixar ligado o que é do
    Windows, de hardware ou antivírus. Sem ela, nada vem marcado, e o conselho vai em todos com -Advice (a lista de
    desativar).
    #>
    param (
        [object[]]$Items = @(),
        [bool]$IsAdmin = $true,
        [switch]$Review,
        [switch]$Advice
    )

    return @(
        for ($i = 0; $i -lt $Items.Count; $i++) {
            $on = ($Review -and [bool]$Items[$i].Enabled)
            @{ Key = [string]$i; Label = (Get-WinForgeStartupDisplayName -Item $Items[$i]); Description = (Get-WinForgeStartupOptionText -Item $Items[$i] -IsAdmin $IsAdmin -Advice:($Advice -or $on)); Selected = $on }
        }
    )
}


function Get-WinForgeStartupOptionText {
    # A descrição curta de um item na lista de marcar: quem publica (ou o arquivo que abre), "todos os usuários" quando
    # vale para o PC inteiro e, quando pedido (-Advice), o conselho de deixar ligado o que é do Windows, de hardware ou
    # antivírus. De onde o item abre (chave Run, pasta, tarefa) fica fora da tela: não ajuda a decidir.
    param (
        [Parameter(Mandatory)]$Item,
        [bool]$IsAdmin = $true,
        [switch]$Advice
    )

    $parts = @()
    $publisher = [string](Get-WinForgeJsonValue -Object $Item -Name "Publisher" -Default "")

    if ($publisher) { $parts += $publisher }
    else {
        $file = Get-WinForgeStartupFileName -Item $Item
        if ($file) { $parts += $file }
    }

    if ($Item.Scope -eq "Machine") { $parts += (Get-WinForgeText 'todos os usuários') }
    if ($Item.Scope -eq "Machine" -and -not $IsAdmin) { $parts += (Get-WinForgeText 'exige Administrador') }

    if ($Advice) {
        $text = Get-WinForgeStartupAdvice -Item $Item
        if ($text) { $parts = @($text) + $parts }
    }

    return ($parts -join " · ")
}


function Get-WinForgeStartupChangeText {
    # "2 desativados e 1 reativado" (com -Names, também os nomes: "2 desativados (A e B) e 1 reativado (C)").
    param (
        [string[]]$Off = @(),
        [string[]]$On = @(),
        [switch]$Names
    )

    $parts = @()

    foreach ($side in @(@{ Items = @($Off | Where-Object { $_ }); One = (Get-WinForgeText 'desativado'); Many = (Get-WinForgeText 'desativados') }, @{ Items = @($On | Where-Object { $_ }); One = (Get-WinForgeText 'reativado'); Many = (Get-WinForgeText 'reativados') })) {
        if ($side.Items.Count -eq 0) { continue }

        $text = Format-WinForgeCount -Count $side.Items.Count -One $side.One -Many $side.Many
        if ($Names) { $text += " ($(Join-WinForgeList -Items $side.Items))" }
        $parts += $text
    }

    return (Join-WinForgeList -Items $parts)
}


function Read-WinForgeStartupSide {
    <#
    O jeito da tela Gerenciar inicialização: primeiro se é para desativar, reativar ou tirar o que sobrou de programas
    desinstalados (Leftovers), depois a lista daquele lado: para desativar e reativar, com nada marcado; o que sobrou, já
    marcado (não abre nada). Devolve as mudanças (Item e Enabled, o estado pedido; ou Item e Remove) ou $null quando a
    pessoa desiste.
    #>
    param (
        [object[]]$Enabled = @(),
        [object[]]$Disabled = @(),
        [object[]]$Leftovers = @(),
        [bool]$IsAdmin = $true
    )

    $options = @()

    # Com o que sobrou, tirar é o recomendado: não abre nada e só ocupa a lista do Windows.
    if ($Enabled.Count -gt 0) {
        $options += @{ Key = "D"; Label = (Get-WinForgeText 'Desativar itens'); Description = (Get-WinForgeText 'o que não precisa abrir com o Windows'); Accent = ($Leftovers.Count -eq 0) }
    }

    if ($Disabled.Count -gt 0) {
        $options += @{ Key = "R"; Label = (Get-WinForgeText 'Reativar itens'); Description = (Get-WinForgeText 'o que foi desativado') }
    }

    if ($Leftovers.Count -gt 0) {
        $options += @{ Key = "L"; Label = (Get-WinForgeText 'Remover o que sobrou'); Accent = $true
            Description = $(if ($Leftovers.Count -eq 1) { (Get-WinForgeText '1 item de um programa que não está mais no PC') } else { (Get-WinForgeText '{0} itens de programas que não estão mais no PC' "$($Leftovers.Count)") }) }
    }

    $options += @{ Key = "X"; Label = (Get-WinForgeText 'Cancelar'); Exit = $true }

    $answer = Read-WinForgeChoice -Message (Get-WinForgeText 'O que deseja fazer?') -Options $options -DefaultKey "X" -ShowMenu `
        -TextPrompt $(if ($Leftovers.Count -gt 0) { (Get-WinForgeText 'Opção (D, R, L ou X; ENTER = cancelar)') } else { (Get-WinForgeText 'Opção (D, R ou X; ENTER = cancelar)') })

    if ($answer -ieq "L" -and $Leftovers.Count -gt 0) {
        $choices = @(
            for ($i = 0; $i -lt $Leftovers.Count; $i++) {
                @{ Key = [string]$i; Label = (Get-WinForgeStartupDisplayName -Item $Leftovers[$i]); Description = (Get-WinForgeStartupLeftoverText -Item $Leftovers[$i]); Selected = $true }
            }
        )

        $picked = Read-WinForgeMultiSelect -Message (Get-WinForgeText 'Marque o que deve sair da inicialização') -Options $choices -ConfirmLabel (Get-WinForgeText 'Remover')

        if ($null -eq $picked -or @($picked).Count -eq 0) {
            return $null
        }

        return @(foreach ($key in @($picked)) { [PSCustomObject]@{ Item = $Leftovers[[int]$key]; Remove = $true } })
    }

    $targetEnabled = $null
    $pool = @()

    if ($answer -ieq "D" -and $Enabled.Count -gt 0) {
        $targetEnabled = $false
        $pool = @($Enabled)
    }
    elseif ($answer -ieq "R" -and $Disabled.Count -gt 0) {
        $targetEnabled = $true
        $pool = @($Disabled)
    }

    if ($null -eq $targetEnabled) {
        return $null
    }

    # Na hora de desativar, o que é do Windows, de hardware ou antivírus vem dito no próprio item: é o que faz falta.
    $choices = @(New-WinForgeStartupChoices -Items $pool -IsAdmin $IsAdmin -Advice:(-not $targetEnabled))

    # Sem pergunta depois da lista: o botão dela diz o que vai acontecer ("Desativar (2)"), e não "Confirmar".
    $message = $(if ($targetEnabled) { (Get-WinForgeText 'Marque os itens que devem voltar a abrir com o Windows') } else { (Get-WinForgeText 'Marque os itens que NÃO devem mais abrir com o Windows') })
    $picked = Read-WinForgeMultiSelect -Message $message -Options $choices -ConfirmLabel $(if ($targetEnabled) { (Get-WinForgeText 'Reativar') } else { (Get-WinForgeText 'Desativar') })

    if ($null -eq $picked -or @($picked).Count -eq 0) {
        return $null
    }

    return @(foreach ($key in @($picked)) { [PSCustomObject]@{ Item = $pool[[int]$key]; Enabled = $targetEnabled } })
}


function Read-WinForgeStartupReview {
    <#
    A revisão do Otimizar: uma lista só, com o que abre hoje já marcado. Desmarcar desativa, marcar reativa. Antes de
    mudar, a tela diz o que deixa de abrir e o que volta, e pergunta. Devolve as mudanças (Item e Enabled), uma lista
    vazia quando a lista confirmada não muda nada, ou $null quando a pessoa desiste (a lista cancelada ou o Não).
    #>
    param (
        [object[]]$Items = @(),
        [bool]$IsAdmin = $true
    )

    $pool = @($Items)

    # No menu de texto não há o que desmarcar: os números digitados são a lista inteira do que fica marcado. O conselho
    # de deixar ligado o antivírus, o que é do Windows e os drivers vem no próprio item, não numa linha à parte.
    if (Test-WinForgeGuiPrompts) {
        Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Marcado abre com o Windows. Desmarque o que não precisa abrir junto.')
    }
    else {
        Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Com * é o que abre hoje. Digite os números de tudo o que deve abrir com o Windows: o que ficar de fora deixa de abrir. P deixa como está.')
    }

    $choices = @(New-WinForgeStartupChoices -Items $pool -IsAdmin $IsAdmin -Review)

    # Sem "Marcar todos": reativaria de uma vez tudo o que a pessoa já tinha desativado. Desmarcar tudo é uma resposta
    # (nada abre com o Windows): a lista volta vazia, e não $null.
    $picked = Read-WinForgeMultiSelect -Message (Get-WinForgeText 'O que deve abrir junto com o Windows') -Options $choices -NoSelectAll -AllowNone

    if ($null -eq $picked) {
        return $null
    }

    $changes = @(
        for ($i = 0; $i -lt $pool.Count; $i++) {
            $want = (@($picked) -contains [string]$i)
            if ($want -ne [bool]$pool[$i].Enabled) { [PSCustomObject]@{ Item = $pool[$i]; Enabled = $want } }
        }
    )

    if ($changes.Count -eq 0) {
        return , @()
    }

    $off = @($changes | Where-Object { -not $_.Enabled } | ForEach-Object { Get-WinForgeStartupDisplayName -Item $_.Item })
    $on = @($changes | Where-Object { $_.Enabled } | ForEach-Object { Get-WinForgeStartupDisplayName -Item $_.Item })

    Write-Host ""
    if ($off.Count -gt 0) { Write-WinForgeKeyValue -Label (Get-WinForgeText 'Deixam de abrir') -Value (Join-WinForgeList -Items $off) }
    if ($on.Count -gt 0) { Write-WinForgeKeyValue -Label (Get-WinForgeText 'Voltam a abrir') -Value (Join-WinForgeList -Items $on) }
    Write-Host ""

    # Com algo deixando de abrir, a resposta padrão é Não: um número trocado no menu de texto não desativa a lista. O Não
    # deixa tudo como está, sozinho ou dentro do Otimizar.
    if (-not (Confirm-WinForgeAction (Get-WinForgeText 'Aplicar estas mudanças na inicialização?') -DefaultKey $(if ($off.Count -gt 0) { "N" } else { "S" }) -YesLabel (Get-WinForgeText 'Aplicar') -NoLabel (Get-WinForgeText 'Deixar como está'))) {
        return $null
    }

    return @($changes)
}


function Set-WinForgeStartupItems {
    <#
    Desativa ou reativa o que abre com o Windows. Sozinha, pergunta primeiro se é para desativar ou reativar e lista só
    os itens daquele lado. Com -Review (a etapa do Otimizar), mostra uma lista só, com o que abre hoje já marcado: o que
    for desmarcado deixa de abrir, e o que for marcado volta a abrir.
    #>
    param (
        [switch]$Review
    )

    $title = (Get-WinForgeText 'Gerenciar inicialização')

    if ($Review) {
        $title = (Get-WinForgeText 'Revisar o que abre com o Windows')
    }

    Enter-WinForgeAction -Title $title

    $final = New-WinForgeResult -Kind Ok -Title $title

    try {
        Write-Progress -Activity $title -Status (Get-WinForgeText 'lendo o que abre com o Windows')

        try {
            $items = @(Get-WinForgeStartupEntries | Sort-Object -Property Name)

            # O que sobrou de programas desinstalados: só na tela sozinha, que pode tirar (a revisão do Otimizar só liga e
            # desliga).
            $leftovers = $(if ($Review) { @() } else { @(Get-WinForgeStartupItems -Leftovers | Sort-Object -Property Name) })
        }
        finally {
            Write-Progress -Activity $title -Completed
        }

        # O Agendador de Tarefas sem resposta: a lista vem sem as tarefas, e a tela diz isso. É um aviso sobre a leitura,
        # que não conta no desfecho.
        $tasksProblem = Get-WinForgeStartupTasksProblem

        if ($tasksProblem) {
            Write-WinForgeStatus -Type Warning -Notice -Message (Get-WinForgeText 'As tarefas agendadas não puderam ser lidas: {0}.' "$tasksProblem")
        }

        # A lista mostra só o que o WinForge consegue mudar agora, para nenhuma marca ser de enfeite:
        # - elevado com outra conta, os itens de uma conta só (HKCU, pasta Inicializar, tarefas e aplicativos da conta) são
        #   os dessa conta, não os da pessoa logada: mudar ali seria mexer no perfil errado;
        # - sem Administrador, os de todos os usuários (HKLM, pasta Inicializar comum, tarefas do sistema) não podem ser
        #   gravados.
        # Nos dois casos, uma linha diz o que ficou de fora.
        $isAdmin = Test-WinForgeAdministrator
        $hidden = ""

        if (Test-WinForgeStartupOtherAccount) {
            if (@(@($items) + @($leftovers) | Where-Object { $_.Scope -eq "User" }).Count -gt 0) {
                $hidden = (Get-WinForgeText 'o WinForge está elevado com outra conta')
                $user = [string](Get-WinForgeJsonValue -Object (Get-WinForgeSessionInfo) -Name "User" -Default "")
                Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'O WinForge está elevado com outra conta ({0}): só aparecem os itens de todos os usuários.' "$user")
            }

            $items = @($items | Where-Object { $_.Scope -ne "User" })
            $leftovers = @($leftovers | Where-Object { $_.Scope -ne "User" })
        }

        if (-not $isAdmin) {
            $machine = @(@($items) + @($leftovers) | Where-Object { $_.Scope -eq "Machine" }).Count

            if ($machine -gt 0) {
                $hidden = (Get-WinForgeText 'os itens que abrem com o Windows exigem Administrador')
                Write-WinForgeStatus -Type Info -Message (Get-WinForgeText '{0} com o WinForge aberto como Administrador.' "$(Format-WinForgeCount -Count $machine -One (Get-WinForgeText 'item de todos os usuários só aparece') -Many (Get-WinForgeText 'itens de todos os usuários só aparecem'))")
            }

            $items = @($items | Where-Object { $_.Scope -ne "Machine" })
            $leftovers = @($leftovers | Where-Object { $_.Scope -ne "Machine" })
        }

        if ($items.Count -eq 0 -and $leftovers.Count -eq 0) {
            if ($hidden) {
                Exit-WinForgeAction -Result (New-WinForgeResult -Kind Skipped -Detail $hidden -Title $title)
                return
            }

            Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Nenhum programa está configurado para abrir junto com o Windows.')
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Skipped -Detail (Get-WinForgeText 'nenhum programa abre com o Windows') -Title $title)
            return
        }

        $enabled = @($items | Where-Object { $_.Enabled })
        $disabled = @($items | Where-Object { -not $_.Enabled })

        # Desativar não remove o programa (ele continua instalado, e o item continua no Gerenciador de Tarefas e em
        # Configurações, Aplicativos, Inicialização, de onde também pode ser reativado); a tela não precisa explicar isso.
        Write-WinForgeKeyValue -Label (Get-WinForgeText 'Abrem com o Windows') -Value $enabled.Count
        Write-WinForgeKeyValue -Label (Get-WinForgeText 'Desativados') -Value $disabled.Count
        if ($leftovers.Count -gt 0) { Write-WinForgeKeyValue -Label (Get-WinForgeText 'Restos de programas desinstalados') -Value $leftovers.Count -Level Warn }
        Write-Host ""

        if ($Review) {
            $changes = Read-WinForgeStartupReview -Items $items -IsAdmin $isAdmin

            # Desistir (a lista cancelada ou o Não na pergunta) é cancelar; a lista confirmada sem diferença, não mudar nada.
            if ($null -eq $changes) {
                Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'Operação cancelada.')
                Exit-WinForgeAction -Result (New-WinForgeResult -Kind Skipped -Detail (Get-WinForgeText 'cancelado pelo usuário') -Title $title)
                return
            }

            if (@($changes).Count -eq 0) {
                Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Nada foi mudado.')
                Exit-WinForgeAction -Result (New-WinForgeResult -Kind Skipped -Detail (Get-WinForgeText 'você não mudou nada') -Title $title)
                return
            }
        }
        else {
            $changes = Read-WinForgeStartupSide -Enabled $enabled -Disabled $disabled -Leftovers $leftovers -IsAdmin $isAdmin

            if ($null -eq $changes) {
                Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'Operação cancelada.')
                Exit-WinForgeAction -Result (New-WinForgeResult -Kind Skipped -Detail (Get-WinForgeText 'cancelado pelo usuário') -Title $title)
                return
            }

            # Tirar o que sobrou é outro caminho: apaga, em vez de ligar e desligar, e não tem desfazer.
            $remove = @(@($changes) | Where-Object { [bool](Get-WinForgeJsonValue -Object $_ -Name "Remove" -Default $false) })

            if ($remove.Count -gt 0) {
                Exit-WinForgeAction -Result (Remove-WinForgeStartupLeftovers -Items @($remove | ForEach-Object { $_.Item }) -Title $title)
                return
            }
        }

        $changed = 0
        $problems = @()
        $doneItems = @()
        $changedOff = @()
        $changedOn = @()

        foreach ($change in @($changes)) {
            $item = $change.Item
            $targetEnabled = [bool]$change.Enabled

            # O nome da tela, nas mensagens, na faixa e no Histórico; o desfazer guarda o do arquivo (Name).
            $label = Get-WinForgeStartupDisplayName -Item $item

            try {
                Set-WinForgeStartupItemEnabled -Item $item -Enabled $targetEnabled

                # Confere no Windows se o estado deste item (e não de outro com o mesmo nome) mudou de fato.
                $after = Get-WinForgeStartupItemEnabled -Item $item

                if ($null -ne $after -and [bool]$after -eq $targetEnabled) {
                    $changed++
                    $undo = ConvertTo-WinForgeStartupUndoItem -Item $item -Enabled (-not $targetEnabled)
                    $doneItems += [PSCustomObject]@{ Name = $label; Enabled = $targetEnabled; Undo = $undo; Undoable = (Test-WinForgeStartupUndoable -Undo $undo) }
                    if ($targetEnabled) { $changedOn += $label } else { $changedOff += $label }
                    Write-WinForgeStatus -Type Success -Message $(if ($targetEnabled) { (Get-WinForgeText '{0}: reativado.' "$label") } else { (Get-WinForgeText '{0}: desativado.' "$label") })
                }
                else {
                    $problems += [PSCustomObject]@{ Name = $label; Detail = (Get-WinForgeText 'o Windows não manteve a mudança') }
                    Write-WinForgeStatus -Type Error -Message (Get-WinForgeText '{0}: o Windows não manteve a mudança.' "$label")
                }
            }
            catch {
                $problems += [PSCustomObject]@{ Name = $label; Detail = $_.Exception.Message.TrimEnd('.') }
                Write-WinForgeStatus -Type Error -Message "${label}: $($_.Exception.Message.TrimEnd('.'))."
            }
        }

        Write-Host ""

        # "off" (desativar) ou "on" (reativar) quando a lista foi de um lado só (sempre, sem -Review); "mixed" quando a
        # revisão desativou uns e reativou outros. Cada frase vem inteira, para traduzir com a concordância certa.
        $sides = @(@($changes) | ForEach-Object { [bool]$_.Enabled } | Select-Object -Unique)
        $mode = $(if ($sides.Count -gt 1) { "mixed" } elseif ($sides.Count -eq 1 -and $sides[0]) { "on" } else { "off" })

        if ($changed -gt 0) {
            # O que o Histórico de mudanças sabe desfazer vai numa linha com o desfazer; o resto (um item que o desfazer
            # recusaria, como um aplicativo da Store fora das chaves conhecidas), numa linha só de registro: um desfazer que
            # deixasse parte para trás diria que voltou tudo sem ter voltado.
            $undoable = @($doneItems | Where-Object { $_.Undoable })
            $plain = @($doneItems | Where-Object { -not $_.Undoable })

            if ($undoable.Count -gt 0) {
                [void](Add-WinForgeChange -Action (Get-WinForgeText 'Inicialização') -Text (Get-WinForgeStartupJournalText -Items $undoable) -Undo @{ Kind = "startup"; Items = @($undoable | ForEach-Object { $_.Undo }) })
            }

            if ($plain.Count -gt 0) {
                [void](Add-WinForgeChange -Action (Get-WinForgeText 'Inicialização') -Text (Get-WinForgeStartupJournalText -Items $plain))
            }

            $when = (Get-WinForgeText 'Vale a partir da próxima vez que você entrar no Windows')
            Write-WinForgeStatus -Type Info -Message $(if ($undoable.Count -gt 0) { (Get-WinForgeText '{0}. Para desfazer, use Manutenção > Histórico de mudanças.' "$when") } else { "$when." })
        }

        $total = @($changes).Count
        $names = Join-WinForgeList -Items @($problems | ForEach-Object { $_.Name })

        if ($problems.Count -eq 0) {
            # A faixa diz o que mudou ("2 itens desativados"), em vez de só "Concluído com sucesso". Na janela, o título
            # leva o nome quando é um item só ("Spotify desativado"), e a frase diz quando vale.
            $detail = $(
                if ($mode -eq "mixed") { Get-WinForgeStartupChangeText -Off $changedOff -On $changedOn }
                elseif ($mode -eq "on") { $(if ($changed -eq 1) { (Get-WinForgeText '1 item reativado') } else { (Get-WinForgeText '{0} itens reativados' "$changed") }) }
                else { $(if ($changed -eq 1) { (Get-WinForgeText '1 item desativado') } else { (Get-WinForgeText '{0} itens desativados' "$changed") }) }
            )
            $final = New-WinForgeResult -Kind Ok -Detail $detail -Title $title
            $single = [string](@($changedOff) + @($changedOn) | Select-Object -First 1)
            $headline = $(
                if ($mode -eq "mixed" -or $changed -ne 1) { $detail }
                elseif ($mode -eq "on") { (Get-WinForgeText '{0} reativado' "$single") }
                else { (Get-WinForgeText '{0} desativado' "$single") }
            )
            [void](Set-WinForgeResultView -Result $final -Headline $headline -Note (Get-WinForgeText 'Vale a partir da próxima vez que você entrar no Windows.'))
        }
        elseif ($changed -eq 0) {
            $detail = $(
                if ($total -eq 1) {
                    switch ($mode) {
                        "on" { (Get-WinForgeText '{0} não foi reativado: {1}' "$names" "$($problems[0].Detail)") }
                        "off" { (Get-WinForgeText '{0} não foi desativado: {1}' "$names" "$($problems[0].Detail)") }
                        default { (Get-WinForgeText '{0} não foi mudado: {1}' "$names" "$($problems[0].Detail)") }
                    }
                }
                else {
                    switch ($mode) {
                        "on" { (Get-WinForgeText 'nenhum item foi reativado: {0}' "$names") }
                        "off" { (Get-WinForgeText 'nenhum item foi desativado: {0}' "$names") }
                        default { (Get-WinForgeText 'nenhum item foi mudado: {0}' "$names") }
                    }
                }
            )
            $final = New-WinForgeResult -Kind Failed -Detail $detail -Title $title
        }
        else {
            $verbText = $(
                switch ($mode) {
                    "on" { $(if ($problems.Count -eq 1) { (Get-WinForgeText 'não foi reativado') } else { (Get-WinForgeText 'não foram reativados') }) }
                    "off" { $(if ($problems.Count -eq 1) { (Get-WinForgeText 'não foi desativado') } else { (Get-WinForgeText 'não foram desativados') }) }
                    default { $(if ($problems.Count -eq 1) { (Get-WinForgeText 'não foi mudado') } else { (Get-WinForgeText 'não foram mudados') }) }
                }
            )
            $final = New-WinForgeResult -Kind Warning -Detail (Get-WinForgeText '{0} de {1} {2}: {3}' "$($problems.Count)" "$total" "${verbText}" "$names") -Title $title
        }
    }
    catch {
        Write-WinForgeStatus -Type Error -Message (Get-WinForgeText 'Ocorreu um erro: {0}' "$($_.Exception.Message)")
        $final = New-WinForgeResult -Kind Failed -Detail $_.Exception.Message -Title $title
    }

    Exit-WinForgeAction -Result $final
}


Export-ModuleMember -Function *
