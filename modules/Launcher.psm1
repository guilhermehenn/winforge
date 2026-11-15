# O próprio WinForge no Windows: ícone, identidade na barra de tarefas e os atalhos (.lnk) que abrem a janela.
# O trabalho de baixo nível (COM e API do shell) fica em Shell.psm1; aqui estão as decisões: o que o atalho executa,
# qual ícone usa e onde é criado.

$script:WinForgeAppId = "WinForge.App"
$script:WinForgeAppRoot = Split-Path -Parent $PSScriptRoot
$script:WinForgeShortcutFileName = "WinForge.lnk"
# Quem, além das contas de confiança, pode alterar os arquivos do WinForge (lido uma vez: Get-WinForgeAppFolderWriters).
$script:WinForgeAppFolderWriters = $null
# Se a janela está com a conta de outro Administrador (uma consulta ao WMI; o resumo é refeito a cada troca de tema).
$script:WinForgeAccountMismatch = $null


function Get-WinForgeAppRoot {
    # Pasta onde o WinForge está instalado (a que contém WinForge.Gui.ps1, modules, assets...).
    return $script:WinForgeAppRoot
}


function Test-WinForgeIconFile {
    # Confere o cabeçalho de um arquivo .ico (reservado 0, tipo 1 = ícone, ao menos uma imagem). Pega o arquivo vazio,
    # cortado por um download interrompido ou que não é um ícone; o Windows mostraria um ícone em branco.
    param (
        [Parameter(Mandatory)]
        [string]$Path
    )

    try {
        $stream = [System.IO.File]::OpenRead($Path)

        try {
            $header = New-Object byte[] 6

            if ($stream.Read($header, 0, 6) -ne 6) {
                return $false
            }
        }
        finally {
            $stream.Dispose()
        }

        return ($header[0] -eq 0 -and $header[1] -eq 0 -and $header[2] -eq 1 -and $header[3] -eq 0 -and ($header[4] -ne 0 -or $header[5] -ne 0))
    }
    catch {
        return $false
    }
}


function Get-WinForgeIconPath {
    # Caminho do ícone (assets\WinForge.ico) ou $null se o arquivo não estiver na pasta ou não for um ícone válido.
    param (
        [string]$Root = (Get-WinForgeAppRoot)
    )

    $path = Join-Path (Join-Path $Root "assets") "WinForge.ico"

    if ((Test-Path -LiteralPath $path -PathType Leaf) -and (Test-WinForgeIconFile -Path $path)) {
        return $path
    }

    return $null
}


function Get-WinForgePowerShellPath {
    # O Windows PowerShell 5.1: o mesmo que os arquivos .cmd usam e que existe em todo Windows 10/11.
    if (-not [string]::IsNullOrEmpty($env:SystemRoot)) {
        $path = $env:SystemRoot
        foreach ($part in "System32", "WindowsPowerShell", "v1.0", "powershell.exe") {
            $path = Join-Path $path $part
        }

        if (Test-Path -LiteralPath $path -PathType Leaf) {
            return $path
        }
    }

    return "powershell.exe"
}


function Get-WinForgeLaunchDefinition {
    <#
    Descreve como abrir a janela do WinForge: programa, argumentos, pasta de trabalho e ícone. É a mesma linha que o
    WinForge.cmd usa; a janela se reabre sozinha como Administrador, então o atalho não precisa pedir isso.
    #>
    param (
        [string]$Root = (Get-WinForgeAppRoot)
    )

    $guiScript = Join-Path $Root "WinForge.Gui.ps1"

    if (-not (Test-Path -LiteralPath $guiScript -PathType Leaf)) {
        throw "O arquivo WinForge.Gui.ps1 não foi encontrado em '$Root'. Extraia a pasta inteira do WinForge antes de criar o atalho."
    }

    $executable = Get-WinForgePowerShellPath
    $icon = Get-WinForgeIconPath -Root $Root

    # Sem o arquivo do ícone, o atalho mostra o ícone do PowerShell em vez de ficar sem nenhum.
    $iconLocation = "$executable,0"

    if ($null -ne $icon) {
        $iconLocation = "$icon,0"
    }

    return [PSCustomObject]@{
        Executable       = $executable
        Arguments        = "-NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File $(ConvertTo-WinForgeCommandLineArgument -Value $guiScript)"
        WorkingDirectory = $Root
        IconLocation     = $iconLocation
        HasIcon          = ($null -ne $icon)
        Description      = "WinForge - manutenção, reparo e diagnóstico do Windows"
        AppId            = $script:WinForgeAppId
    }
}


function Get-WinForgeShortcutLocation {
    # Onde o atalho pode ser criado, na ordem em que aparecem para a pessoa. Só entram pastas que este Windows informa.
    $places = @(
        @{ Id = "Desktop"; Label = "Área de Trabalho" },
        @{ Id = "StartMenu"; Label = "Menu Iniciar" }
    )

    foreach ($place in $places) {
        $folder = Get-WinForgeSpecialFolder -Name $place.Id

        if ([string]::IsNullOrWhiteSpace($folder)) {
            continue
        }

        [PSCustomObject]@{
            Id     = $place.Id
            Label  = $place.Label
            Folder = $folder
            Path   = Join-Path $folder $script:WinForgeShortcutFileName
        }
    }
}


function Get-WinForgeShortcutPlaceText {
    # O lugar do atalho numa frase: "na Área de Trabalho", "no Menu Iniciar".
    param (
        [Parameter(Mandatory)]
        $Place
    )

    switch ([string]$Place.Id) {
        "Desktop"   { return "na Área de Trabalho" }
        "StartMenu" { return "no Menu Iniciar" }
        default     { return "em $($Place.Label)" }
    }
}


function Initialize-WinForgeAppIdentity {
    # Chamado pela janela antes de aparecer: o processo passa a se chamar WinForge para o Windows, e o botão da barra
    # de tarefas deixa de ser agrupado com o PowerShell. Devolve $true se o Windows aceitou.
    return (Set-WinForgeProcessAppId -AppId $script:WinForgeAppId)
}


function Set-WinForgeWindowIdentity {
    # Chamado pela janela depois de criada: o "Fixar na barra de tarefas" passa a abrir o WinForge, com o ícone dele.
    param (
        [Parameter(Mandatory)]
        [IntPtr]$Handle,

        [string]$Root = (Get-WinForgeAppRoot)
    )

    try {
        $launch = Get-WinForgeLaunchDefinition -Root $Root
    }
    catch {
        return $false
    }

    $command = "$(ConvertTo-WinForgeCommandLineArgument -Value $launch.Executable) $($launch.Arguments)"

    return (Set-WinForgeWindowRelaunch -Handle $Handle -AppId $launch.AppId -Command $command -IconResource $launch.IconLocation -DisplayName "WinForge")
}


function New-WinForgeAppShortcut {
    <#
    Cria o atalho do WinForge, com o ícone, na Área de Trabalho e/ou no Menu Iniciar. Sem -Location, pergunta onde.
    Se o atalho já existir, é atualizado (por exemplo, depois de mover a pasta do WinForge).
    #>
    param (
        [ValidateSet("Desktop", "StartMenu")]
        [string[]]$Location,

        [switch]$Embedded,
        [switch]$PassThru
    )

    $title = "Criar atalho do WinForge"

    Enter-WinForgeAction -Title $title -Embedded:$Embedded

    $result = New-WinForgeResult -Kind Skipped -Title $title
    $ready = $false

    try {
        $launch = Get-WinForgeLaunchDefinition
        $places = @(Get-WinForgeShortcutLocation)

        if ($places.Count -eq 0) {
            throw "O Windows não informou a Área de Trabalho nem o Menu Iniciar deste usuário."
        }

        $ready = $true
    }
    catch {
        Write-WinForgeStatus -Type Error -Message $_.Exception.Message
        $result = New-WinForgeResult -Kind Failed -Detail "atalho não criado" -Title $title
    }

    # Elevado com a conta de outro Administrador, a Área de Trabalho e o Menu Iniciar seriam os dessa conta.
    if ($ready -and (Test-WinForgeUserContextMismatch)) {
        $ready = $false
        Write-WinForgeStatus -Type Warning -Message "O WinForge está aberto com a conta de outro Administrador: o atalho iria para a Área de Trabalho dessa conta. Para criar o atalho na sua conta, $(Get-WinForgeUnelevatedHint)."
        $result = New-WinForgeResult -Kind Warning -Detail "com a conta de outro Administrador, o atalho não foi criado" -Title $title
    }

    if ($ready) {
        Show-WinForgeFolderWritersNotice
    }

    if ($ready) {
        # @($null) teria um item; por isso "sem -Location" é testado pelos parâmetros recebidos.
        if ($PSBoundParameters.ContainsKey("Location")) {
            $chosen = @($Location)
        }
        else {
            $chosen = @(Select-WinForgeShortcutLocation -Places $places)
        }

        $selected = @($places | Where-Object { $chosen -contains $_.Id })

        if ($selected.Count -eq 0) {
            if ($chosen.Count -eq 0) {
                Write-WinForgeStatus -Type Info -Message "Nenhum atalho foi criado."
                $result = New-WinForgeResult -Kind Skipped -Detail "cancelado pelo usuário" -Title $title
            }
            else {
                # Pediram um lugar que este Windows não informou (por exemplo, sem o Menu Iniciar do usuário).
                Write-WinForgeStatus -Type Error -Message "Este Windows não informou a pasta do lugar pedido para o atalho."
                $result = New-WinForgeResult -Kind Failed -Detail "o lugar pedido não está disponível neste Windows" -Title $title
            }
        }
        else {
            $result = New-WinForgeShortcutFiles -Places $selected -Launch $launch
        }
    }

    if ($PassThru) { $result }
    Exit-WinForgeAction -Embedded:$Embedded -Result $result
}


function Select-WinForgeShortcutLocation {
    # Pergunta onde criar o atalho. Devolve os Ids escolhidos, ou nada se a pessoa cancelar.
    param (
        [Parameter(Mandatory)]
        [object[]]$Places
    )

    if ($Places.Count -eq 1) {
        return @($Places[0].Id)
    }

    $options = @()
    $position = 0

    # O que cada lugar é, e não a pasta (C:\Users\...\Start Menu\Programs não diz nada a quem não a conhece).
    $about = @{ Desktop = "O ícone fica na tela, junto dos seus arquivos"; StartMenu = "O WinForge entra na lista de programas do botão Iniciar" }

    foreach ($place in $Places) {
        $position++
        $description = $(if ($about.ContainsKey([string]$place.Id)) { $about[[string]$place.Id] } else { [string]$place.Folder })
        $options += @{ Key = [string]$position; Label = $place.Label; Description = $description; Accent = ($position -eq 1) }
    }

    $options += @{ Key = "A"; Label = "Os dois"; Description = (@($Places | ForEach-Object { [string]$_.Label }) -join " e ") }
    $options += @{ Key = "0"; Label = "Cancelar"; Exit = $true }

    $answer = Read-WinForgeChoice -Message "Onde você quer o atalho do WinForge?" -Options $options -ShowMenu

    if ($answer -eq "0") {
        return @()
    }

    if ($answer -eq "A") {
        return @($Places | ForEach-Object { $_.Id })
    }

    # Qualquer outra resposta que não seja o número de um lugar da lista é tratada como cancelamento.
    $index = 0

    if ([int]::TryParse([string]$answer, [ref]$index) -and $index -ge 1 -and $index -le $Places.Count) {
        return @($Places[$index - 1].Id)
    }

    return @()
}


function New-WinForgeShortcutFiles {
    # Grava o atalho em cada lugar escolhido e mostra o resultado. Um lugar com erro não impede os outros.
    param (
        [Parameter(Mandatory)]
        [object[]]$Places,

        [Parameter(Mandatory)]
        $Launch
    )

    $created = 0
    $updated = 0
    $failed = 0
    $appIdMissing = $false
    $createdIds = @()

    foreach ($place in $Places) {
        $existed = Test-Path -LiteralPath $place.Path -PathType Leaf

        try {
            if (-not (Test-Path -LiteralPath $place.Folder -PathType Container)) {
                throw "A pasta '$($place.Folder)' não existe."
            }

            $saved = Save-WinForgeShortcutFile -Path $place.Path -Target $Launch.Executable -Arguments $Launch.Arguments `
                -WorkingDirectory $Launch.WorkingDirectory -IconLocation $Launch.IconLocation -Description $Launch.Description -AppId $Launch.AppId

            # Proteção contra ransomware ou antivírus podem bloquear a gravação sem o COM reclamar.
            if (-not (Test-Path -LiteralPath $place.Path -PathType Leaf)) {
                throw "o Windows não gravou o arquivo (a proteção contra ransomware ou um antivírus pode ter bloqueado a pasta)."
            }

            $created++
            $createdIds += [string]$place.Id

            if ($existed) { $updated++ }

            $verb = if ($existed) { "atualizado" } else { "criado" }
            Write-WinForgeStatus -Type Success -Message "Atalho $verb $(Get-WinForgeShortcutPlaceText -Place $place)."
            Write-Host "      $($place.Path)" -ForegroundColor DarkGray

            if (-not $saved.AppIdSet) { $appIdMissing = $true }
        }
        catch {
            $failed++
            Write-WinForgeStatus -Type Error -Message "Não foi possível criar o atalho $(Get-WinForgeShortcutPlaceText -Place $place): $($_.Exception.Message)"
        }
    }

    if ($created -gt 0) {
        Write-Host ""

        # O Explorador guarda o ícone de cada atalho: sem este aviso, um atalho regravado continuaria com o ícone antigo.
        if (Initialize-WinForgeShellInterop) {
            try { [WinForge.ShellIdentity]::RefreshIcons() } catch { Write-Verbose "Ícones: $($_.Exception.Message)" }
        }

        if (-not $Launch.HasIcon) {
            Write-WinForgeStatus -Type Warning -Message "O arquivo assets\WinForge.ico não foi encontrado; o atalho usa o ícone do PowerShell."
        }

        if ($appIdMissing) {
            Write-WinForgeStatus -Type Warning -Message "O Windows não aceitou o identificador da barra de tarefas: fixado na barra, o atalho pode aparecer como PowerShell."
        }

        # No Windows 11, a opção fica em 'Mostrar mais opções' (Área de Trabalho) ou em 'Mais' (Menu Iniciar). Mover a pasta do WinForge quebra o atalho: é criar de novo.
        Write-WinForgeStatus -Type Info -Message "Para fixar na barra de tarefas: botão direito no atalho, 'Fixar na barra de tarefas' (no Windows 11, dentro de 'Mostrar mais opções' ou de 'Mais')."
    }

    if ($created -eq 0) {
        return (New-WinForgeResult -Kind Failed -Detail "nenhum atalho criado" -Title "Criar atalho do WinForge")
    }

    if ($failed -gt 0) {
        return (New-WinForgeResult -Kind Warning -Detail "$(Format-WinForgeCount -Count $created -One 'atalho criado' -Many 'atalhos criados'), $failed com erro" -Title "Criar atalho do WinForge")
    }

    # Diz onde o atalho ficou, para a faixa de resultado responder a pergunta "onde ele foi parar?".
    $where = (@($createdIds | ForEach-Object { if ($_ -eq "StartMenu") { "no Menu Iniciar" } else { "na Área de Trabalho" } }) -join " e ")
    $verbDone = $(if ($updated -eq $created) { "atualizado" } elseif ($updated -eq 0) { "criado" } else { "gravado" })

    # Um atalho sem o ícone ou sem o identificador da barra de tarefas funciona, mas não é o que a pessoa espera ver.
    $caveats = @()

    if (-not $Launch.HasIcon) { $caveats += "está com o ícone do PowerShell" }

    if ($appIdMissing) { $caveats += "o botão pode aparecer como PowerShell ao ser fixado na barra de tarefas" }

    if ($caveats.Count -gt 0) {
        return (New-WinForgeResult -Kind Warning -Detail "atalho $verbDone $where, mas $($caveats -join '; ')" -Title "Criar atalho do WinForge")
    }

    # A faixa da janela: o que foi feito no título; onde ficou e como fixar na frase.
    $headline = $(if ($created -gt 1) { "Atalhos $($verbDone)s" } else { "Atalho $verbDone" })
    $pinHint = $(if ($created -gt 1) { "clique num deles com o botão direito" } else { "clique nele com o botão direito" })
    $whereText = $where.Substring(0, 1).ToUpperInvariant() + $where.Substring(1)

    return (Set-WinForgeResultView -Result (New-WinForgeResult -Kind Ok -Detail "atalho $verbDone $where" -Title "Criar atalho do WinForge") `
            -Headline $headline -Note "$whereText. Para fixar na barra de tarefas, $pinHint.")
}


function Get-WinForgeAppFolderWriters {
    <#
    As contas, além da sua, dos Administradores e do sistema, que podem alterar os arquivos do WinForge (a mesma conta do
    agendamento: Get-WinForgeScheduleUntrustedWriters). A janela roda esses arquivos como Administrador: numa pasta que
    outras contas do PC alteram (C:\WinForge criada direto no disco, onde os "Usuários autenticados" podem modificar),
    qualquer uma delas passaria a rodar código como Administrador. Lido uma vez por processo; permissões que não puderam
    ser lidas não entram (não é um alarme).
    #>
    if ($null -ne $script:WinForgeAppFolderWriters) { return $script:WinForgeAppFolderWriters }

    $writers = @()

    try {
        if (Get-Command -Name Get-WinForgeScheduleUntrustedWriters -ErrorAction SilentlyContinue) {
            $writers = @(Get-WinForgeScheduleUntrustedWriters -Root (Get-WinForgeAppRoot) | Where-Object { [string]$_ -notmatch '^não foi possível' })
        }
    }
    catch {
        $writers = @()
    }

    $script:WinForgeAppFolderWriters = $writers
    return $writers
}


function Show-WinForgeFolderWritersNotice {
    # O aviso de Criar atalho quando outras contas podem alterar os arquivos do WinForge (Get-WinForgeAppFolderWriters).
    $writers = @(Get-WinForgeAppFolderWriters)

    if ($writers.Count -eq 0) { return }

    Write-WinForgeStatus -Type Warning -Notice -Message "Outras contas deste PC ($($writers -join ', ')) podem alterar os arquivos do WinForge, que roda como Administrador: se mais alguém usa este PC, extraia o WinForge de novo em Arquivos de Programas e crie o atalho de lá."
    Write-Host ""
}


function Get-WinForgeShortcutState {
    # Cada lugar do atalho (Área de Trabalho, Menu Iniciar) com Exists e Current (o atalho abre esta pasta do WinForge;
    # um atalho que não pôde ser lido conta como desta pasta, para não acusar à toa).
    $script = Join-Path (Get-WinForgeAppRoot) "WinForge.Gui.ps1"

    foreach ($place in @(Get-WinForgeShortcutLocation)) {
        $exists = Test-Path -LiteralPath $place.Path -PathType Leaf
        $current = $true

        if ($exists) {
            $target = $null
            try { $target = Get-WinForgeShortcutTarget -Path $place.Path } catch { $target = $null }

            if ($null -ne $target -and [string]$target.Arguments -and ([string]$target.Arguments).IndexOf($script, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
                $current = $false
            }
        }

        [PSCustomObject]@{ Id = $place.Id; Label = $place.Label; Path = $place.Path; Exists = $exists; Current = $current }
    }
}


function Show-WinForgeAbout {
    # Tela "Versão e pastas": o que está aberto, onde está instalado e onde ficam os logs, os relatórios e os atalhos.
    Enter-WinForgeAction -Title "Versão e pastas"

    $dataPath = Get-WinForgeDataPath

    Write-WinForgeSection -Title "WinForge"
    Write-WinForgeKeyValue -Label "Versão" -Value "Build $(Get-WinForgeBuild)"
    Write-WinForgeKeyValue -Label "Instalado em" -Value (Get-WinForgeAppRoot)
    Write-WinForgeKeyValue -Label "PowerShell" -Value "$($PSVersionTable.PSVersion) ($($PSVersionTable.PSEdition))"
    Write-WinForgeKeyValue -Label "Administrador" -Value $(if (Test-WinForgeAdministrator) { "Sim" } else { "Não" })

    Write-WinForgeSection -Title "Pastas"
    Write-WinForgeKeyValue -Label "Logs e relatórios" -Value $dataPath

    $logPath = Get-WinForgeLogPath

    if (-not [string]::IsNullOrWhiteSpace($logPath)) {
        Write-WinForgeKeyValue -Label "Log desta sessão" -Value $logPath
    }

    Write-WinForgeSection -Title "Atalho"

    $iconMissing = ($null -eq (Get-WinForgeIconPath))

    if ($iconMissing) {
        Write-WinForgeStatus -Type Warning -Message "O arquivo assets\WinForge.ico não foi encontrado; os atalhos usam o ícone do PowerShell."
    }

    foreach ($place in @(Get-WinForgeShortcutState)) {
        $text = $(if (-not $place.Exists) { "Sem atalho" } elseif ($place.Current) { "Atalho criado" } else { "Atalho de outra pasta do WinForge; crie de novo" })
        Write-WinForgeKeyValue -Label $place.Label -Value $text
    }

    # É uma tela de leitura: sem problema, não há faixa de resultado; com o ícone faltando, a faixa diz exatamente isso.
    if ($iconMissing) {
        Exit-WinForgeAction -Result (New-WinForgeResult -Kind Warning -Detail "o ícone assets\WinForge.ico não foi encontrado" -Title "Versão e pastas")
    }
    else {
        Exit-WinForgeAction
    }
}


function Get-WinForgeAboutPageStatus {
    <#
    O resumo no alto da página Sobre o WinForge: a versão, onde o atalho já existe (e se ele abre esta pasta), o ícone,
    se a janela está como Administrador e, quando é o caso, a conta e as permissões da pasta. Cada linha tem Label, Text e
    Level (Normal | Warn | Muted). Só lê o que é local, sem consultar a internet; cada linha que não puder ser lida vira
    "não foi possível ler" sozinha, em vez de derrubar a página.
    #>
    $rows = @()

    try {
        $rows += [PSCustomObject]@{ Label = "Versão"; Text = "Build $(Get-WinForgeBuild)"; Level = "Normal" }
    }
    catch {
        $rows += [PSCustomObject]@{ Label = "Versão"; Text = "não foi possível ler"; Level = "Muted" }
    }

    try {
        $places = @(Get-WinForgeShortcutState)
        $with = @($places | Where-Object { $_.Exists -and $_.Current } | ForEach-Object { [string]$_.Label })
        $stale = @($places | Where-Object { $_.Exists -and -not $_.Current } | ForEach-Object { [string]$_.Label })

        if ($places.Count -eq 0) {
            $rows += [PSCustomObject]@{ Label = "Atalho"; Text = "o Windows não informou as pastas do atalho"; Level = "Muted" }
        }
        elseif ($stale.Count -gt 0) {
            # O atalho de uma cópia antiga (outra pasta) abriria a versão velha.
            $rows += [PSCustomObject]@{ Label = "Atalho"; Text = "o de $($stale -join ' e ') abre outra pasta do WinForge; use Criar atalho do WinForge"; Level = "Warn" }
        }
        elseif ($with.Count -eq 0) {
            $rows += [PSCustomObject]@{ Label = "Atalho"; Text = "ainda não criado; use Criar atalho do WinForge"; Level = "Muted" }
        }
        else {
            $rows += [PSCustomObject]@{ Label = "Atalho"; Text = ($with -join " e "); Level = "Normal" }
        }
    }
    catch {
        $rows += [PSCustomObject]@{ Label = "Atalho"; Text = "não foi possível ler"; Level = "Muted" }
    }

    # O ícone na sua própria linha: uma falha ao conferi-lo não vira uma segunda linha "Atalho".
    try {
        if ($null -eq (Get-WinForgeIconPath)) {
            $rows += [PSCustomObject]@{ Label = "Ícone"; Text = "o arquivo do ícone (assets\WinForge.ico) não foi encontrado; extraia a pasta inteira do WinForge de novo"; Level = "Warn" }
        }
    }
    catch {
        Write-Verbose "Ícone: $($_.Exception.Message)"
    }

    try {
        # O WinForge abre sempre como Administrador; sem ele, a pessoa recusou o aviso do Windows ao abrir.
        if (Test-WinForgeAdministrator) {
            $rows += [PSCustomObject]@{ Label = "Administrador"; Text = "esta janela está aberta como Administrador"; Level = "Normal" }
        }
        else {
            $rows += [PSCustomObject]@{ Label = "Administrador"; Text = "esta janela está sem Administrador; as ações que alteram o sistema pedem a permissão de novo"; Level = "Warn" }
        }
    }
    catch {
        $rows += [PSCustomObject]@{ Label = "Administrador"; Text = "não foi possível ler"; Level = "Muted" }
    }

    try {
        # Uma consulta só por processo: a conta da janela não muda enquanto ela está aberta.
        if ($null -eq $script:WinForgeAccountMismatch) { $script:WinForgeAccountMismatch = [bool](Test-WinForgeUserContextMismatch) }

        if ($script:WinForgeAccountMismatch) {
            $rows += [PSCustomObject]@{ Label = "Conta"; Text = "o WinForge está aberto com a conta de outro Administrador; atalhos, pastas e o monitor são os dessa conta"; Level = "Warn" }
        }
    }
    catch {
        Write-Verbose "Conta: $($_.Exception.Message)"
    }

    $writers = @(Get-WinForgeAppFolderWriters)

    if ($writers.Count -gt 0) {
        $rows += [PSCustomObject]@{ Label = "Pasta"; Text = "outras contas deste PC podem alterar os arquivos do WinForge; se mais alguém usa o PC, extraia o WinForge de novo em Arquivos de Programas"; Level = "Warn" }
    }

    return $rows
}


Export-ModuleMember -Function *
