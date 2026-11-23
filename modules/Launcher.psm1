# O próprio WinForge no Windows: ícone, identidade na barra de tarefas e os atalhos (.lnk) que abrem a janela.
# O trabalho de baixo nível (COM e API do shell) fica em Shell.psm1; aqui estão as decisões: o que o atalho executa,
# qual ícone usa e onde é criado.

# O começo do identificador da barra de tarefas; cada pasta do WinForge completa com o dela (Get-WinForgeAppId).
$script:WinForgeAppIdPrefix = "WinForge.App"
$script:WinForgeAppIds = @{}
# O que foi lido de cada atalho (o destino e o identificador), com a data e o tamanho do arquivo (Read-WinForgeShortcutCached).
$script:WinForgeShortcutReads = @{}
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
        throw (Get-WinForgeText 'O arquivo WinForge.Gui.ps1 não foi encontrado em ''{0}''. Extraia a pasta inteira do WinForge antes de criar o atalho.' "$Root")
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
        Description      = (Get-WinForgeText 'WinForge - manutenção, reparo e diagnóstico do Windows')
        AppId            = (Get-WinForgeAppId -Root $Root)
    }
}


function Get-WinForgeAppId {
    <#
    O identificador do WinForge na barra de tarefas (AppUserModelID) da pasta Root: "WinForge.App." e 16 letras do
    SHA-256 do caminho da pasta. A janela, o processo e os atalhos desta pasta usam o mesmo.

    Um por pasta, e não um só para todas as cópias: o Windows junta as janelas de mesmo identificador e guarda, para ele,
    o ícone e o comando de um atalho ou de um item fixado na barra de tarefas. Com um identificador só, a janela de uma
    pasta pegava o ícone de outra, e o de uma pasta já apagada aparecia em branco. Atualizar no lugar mantém a pasta, e com
    ela o identificador.

    O caminho é o mesmo de qualquer jeito que a pasta seja aberta: completo, sem a barra do fim, em maiúsculas (o Windows
    não diferencia) e, numa unidade de rede mapeada (Z:), como \\servidor\pasta, que é como a execução elevada a abre (a
    unidade mapeada não existe para ela; veja Get-GuiLaunchScriptPath). Faz parte do contrato com as versões futuras: outro
    cálculo daria outro identificador à mesma pasta, e os atalhos dela deixariam de se juntar à janela.
    #>
    param (
        [string]$Root = (Get-WinForgeAppRoot)
    )

    if ($script:WinForgeAppIds.ContainsKey($Root)) { return $script:WinForgeAppIds[$Root] }

    $path = [string]$Root

    try { $path = [System.IO.Path]::GetFullPath($path) } catch { $path = [string]$Root }

    if ($path -match '^([A-Za-z]):\\') {
        $drive = $Matches[1]

        try {
            $display = [string](Get-PSDrive -Name $drive -PSProvider FileSystem -ErrorAction Stop).DisplayRoot
            if ($display -match '^\\\\[^\\]') { $path = $display.TrimEnd('\') + $path.Substring(2) }
        }
        catch {
            Write-Verbose "Unidade ${drive}: sem a unidade, vale o caminho como veio ($($_.Exception.Message))"
        }
    }

    $path = $path.TrimEnd('\').ToUpperInvariant()
    $sha = [System.Security.Cryptography.SHA256]::Create()

    try {
        $hash = $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($path))
    }
    finally {
        $sha.Dispose()
    }

    $id = "$($script:WinForgeAppIdPrefix).$(-join @($hash[0..7] | ForEach-Object { $_.ToString('X2') }))"
    $script:WinForgeAppIds[$Root] = $id

    return $id
}


function Get-WinForgeShortcutLocation {
    # Onde o atalho pode ser criado, na ordem em que aparecem para a pessoa. Só entram pastas que este Windows informa.
    $places = @(
        @{ Id = "Desktop"; Label = (Get-WinForgeText 'Área de Trabalho') },
        @{ Id = "StartMenu"; Label = (Get-WinForgeText 'Menu Iniciar') }
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
        "Desktop"   { return (Get-WinForgeText 'na Área de Trabalho') }
        "StartMenu" { return (Get-WinForgeText 'no Menu Iniciar') }
        default     { return (Get-WinForgeText 'em {0}' "$($Place.Label)") }
    }
}


function Initialize-WinForgeAppIdentity {
    # Chamado pela janela antes de aparecer: o processo passa a se chamar WinForge (o desta pasta) para o Windows, e o
    # botão da barra de tarefas deixa de ser agrupado com o PowerShell. Devolve $true se o Windows aceitou.
    return (Set-WinForgeProcessAppId -AppId (Get-WinForgeAppId))
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

    $title = (Get-WinForgeText 'Criar atalho do WinForge')

    Enter-WinForgeAction -Title $title -Embedded:$Embedded

    $result = New-WinForgeResult -Kind Skipped -Title $title
    $ready = $false

    try {
        $launch = Get-WinForgeLaunchDefinition
        $places = @(Get-WinForgeShortcutLocation)

        if ($places.Count -eq 0) {
            throw (Get-WinForgeText 'O Windows não informou a Área de Trabalho nem o Menu Iniciar deste usuário.')
        }

        $ready = $true
    }
    catch {
        Write-WinForgeStatus -Type Error -Message $_.Exception.Message
        $result = Set-WinForgeResultView -Result (New-WinForgeResult -Kind Failed -Detail (Get-WinForgeText 'atalho não criado') -Title $title) `
            -Headline (Get-WinForgeText 'O atalho não foi criado') -Note (Format-WinForgeReasonNote -Text $_.Exception.Message)
    }

    # Elevado com a conta de outro Administrador, a Área de Trabalho e o Menu Iniciar seriam os dessa conta.
    if ($ready -and (Test-WinForgeUserContextMismatch)) {
        $ready = $false
        $why = (Get-WinForgeText 'O WinForge está aberto com a conta de outro Administrador: o atalho iria para a Área de Trabalho dessa conta. Para criar o atalho na sua conta, {0}.' "$(Get-WinForgeUnelevatedHint)")
        Write-WinForgeStatus -Type Warning -Message $why
        $result = Set-WinForgeResultView -Result (New-WinForgeResult -Kind Warning -Detail (Get-WinForgeText 'com a conta de outro Administrador, o atalho não foi criado') -Title $title) `
            -Headline (Get-WinForgeText 'O atalho não foi criado') -Note $why
    }

    # Com o WinForge instalado, o atalho do instalador (para todos os usuários) já abre esta pasta: um desta conta no mesmo
    # lugar apareceria repetido. Esses lugares saem da escolha, e um atalho repetido desta conta que abria o WinForge sai.
    if ($ready) {
        $covered = @($places | Where-Object { $place = $_; try { [bool](Test-WinForgeInstallerShortcut -Id $place.Id) } catch { $false } })

        if ($covered.Count -gt 0) {
            $coveredIds = @($covered | ForEach-Object { [string]$_.Id })

            foreach ($place in $covered) {
                if (Test-WinForgeShortcutIsWinForge -Path $place.Path) {
                    try { Remove-Item -LiteralPath $place.Path -Force -ErrorAction Stop } catch { Write-Verbose "Atalho repetido: $($_.Exception.Message)" }
                }
            }

            $coveredText = (Get-WinForgeText 'O atalho do WinForge instalado já está {0}, para todos os usuários.' "$(Join-WinForgeList -Items @($covered | ForEach-Object { Get-WinForgeShortcutPlaceText -Place $_ }))")
            Write-WinForgeStatus -Type Info -Message $coveredText
            $places = @($places | Where-Object { $coveredIds -notcontains [string]$_.Id })
            if ($PSBoundParameters.ContainsKey("Location")) { $Location = @($Location | Where-Object { $coveredIds -notcontains $_ }) }

            if ($places.Count -eq 0 -or ($PSBoundParameters.ContainsKey("Location") -and @($Location).Count -eq 0)) {
                $ready = $false
                $result = Set-WinForgeResultView -Result (New-WinForgeResult -Kind Ok -Detail (Get-WinForgeText 'o atalho do WinForge instalado já existe') -Title $title) `
                    -Headline (Get-WinForgeText 'O atalho já existe') -Note $coveredText
            }
        }
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
                Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Nenhum atalho foi criado.')
                $result = New-WinForgeResult -Kind Skipped -Detail (Get-WinForgeText 'cancelado pelo usuário') -Title $title
            }
            else {
                # Pediram um lugar que este Windows não informou (por exemplo, sem o Menu Iniciar do usuário).
                $why = (Get-WinForgeText 'Este Windows não informou a pasta do lugar pedido para o atalho.')
                Write-WinForgeStatus -Type Error -Message $why
                $result = Set-WinForgeResultView -Result (New-WinForgeResult -Kind Failed -Detail (Get-WinForgeText 'o lugar pedido não está disponível neste Windows') -Title $title) `
                    -Headline (Get-WinForgeText 'O atalho não foi criado') -Note $why
            }
        }
        else {
            $result = New-WinForgeShortcutFiles -Places $selected -Launch $launch
        }
    }

    if ($PassThru) { $result }
    Exit-WinForgeAction -Embedded:$Embedded -Result $result
}


function Test-WinForgeShortcutIsWinForge {
    # Se o atalho abre o WinForge (de qualquer pasta): só um atalho assim é tirado quando repete o do instalador.
    param ([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $false }

    try {
        $target = Get-WinForgeShortcutTarget -Path $Path
        return ($null -ne $target -and [string]$target.Arguments -match '(?i)WinForge\.Gui\.ps1')
    }
    catch {
        return $false
    }
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
    $about = @{ Desktop = (Get-WinForgeText 'O ícone fica na tela, junto dos seus arquivos'); StartMenu = (Get-WinForgeText 'O WinForge entra na lista de programas do botão Iniciar') }

    foreach ($place in $Places) {
        $position++
        $description = $(if ($about.ContainsKey([string]$place.Id)) { $about[[string]$place.Id] } else { [string]$place.Folder })
        $options += @{ Key = [string]$position; Label = $place.Label; Description = $description; Accent = ($position -eq 1) }
    }

    $options += @{ Key = "A"; Label = (Get-WinForgeText 'Os dois'); Description = (Join-WinForgeList -Items @($Places | ForEach-Object { [string]$_.Label })) }
    $options += @{ Key = "0"; Label = (Get-WinForgeText 'Cancelar'); Exit = $true }

    $answer = Read-WinForgeChoice -Message (Get-WinForgeText 'Onde você quer o atalho do WinForge?') -Options $options -ShowMenu

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
    $failures = @()

    foreach ($place in $Places) {
        $existed = Test-Path -LiteralPath $place.Path -PathType Leaf

        try {
            if (-not (Test-Path -LiteralPath $place.Folder -PathType Container)) {
                throw (Get-WinForgeText 'A pasta ''{0}'' não existe.' "$($place.Folder)")
            }

            $saved = Save-WinForgeShortcutFile -Path $place.Path -Target $Launch.Executable -Arguments $Launch.Arguments `
                -WorkingDirectory $Launch.WorkingDirectory -IconLocation $Launch.IconLocation -Description $Launch.Description -AppId $Launch.AppId

            # Proteção contra ransomware ou antivírus podem bloquear a gravação sem o COM reclamar.
            if (-not (Test-Path -LiteralPath $place.Path -PathType Leaf)) {
                throw (Get-WinForgeText 'o Windows não gravou o arquivo (a proteção contra ransomware ou um antivírus pode ter bloqueado a pasta).')
            }

            $created++
            $createdIds += [string]$place.Id

            if ($existed) { $updated++ }

            $verb = if ($existed) { (Get-WinForgeText 'atualizado') } else { (Get-WinForgeText 'criado') }
            Write-WinForgeStatus -Type Success -Message (Get-WinForgeText 'Atalho {0} {1}.' "$verb" "$(Get-WinForgeShortcutPlaceText -Place $place)")
            Write-Host "      $($place.Path)" -ForegroundColor DarkGray

            if (-not $saved.AppIdSet) { $appIdMissing = $true }
        }
        catch {
            $failed++
            # A mesma frase na tela e na faixa, com o motivo legível (sem o embrulho do PowerShell).
            $why = ([string](ConvertTo-WinForgeReadableError -Text ([string]$_.Exception.Message))).Trim().TrimEnd('.')
            $failures += "$(Get-WinForgeText 'Não foi possível criar o atalho {0}: {1}' "$(Get-WinForgeShortcutPlaceText -Place $place)" "$why")."
            Write-WinForgeStatus -Type Error -Message $failures[-1]
        }
    }

    if ($created -gt 0) {
        Write-Host ""

        # O Explorador guarda o ícone de cada atalho: sem este aviso, um atalho regravado continuaria com o ícone antigo.
        if (Initialize-WinForgeShellInterop) {
            try { [WinForge.ShellIdentity]::RefreshIcons() } catch { Write-Verbose "Ícones: $($_.Exception.Message)" }
        }

        if (-not $Launch.HasIcon) {
            Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'O arquivo assets\WinForge.ico não foi encontrado; o atalho usa o ícone do PowerShell.')
        }

        if ($appIdMissing) {
            Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'O Windows não aceitou o identificador da barra de tarefas: fixado na barra, o atalho pode aparecer como PowerShell.')
        }

        # No Windows 11, a opção fica em 'Mostrar mais opções' (Área de Trabalho) ou em 'Mais' (Menu Iniciar). Mover a pasta do WinForge quebra o atalho: é criar de novo.
        Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Para fixar na barra de tarefas: botão direito no atalho, ''Fixar na barra de tarefas'' (no Windows 11, dentro de ''Mostrar mais opções'' ou de ''Mais'').')
    }

    if ($created -eq 0) {
        # A faixa diz que nada foi criado e, de cada lugar, o porquê.
        return (Set-WinForgeResultView -Result (New-WinForgeResult -Kind Failed -Detail (Get-WinForgeText 'nenhum atalho criado') -Title (Get-WinForgeText 'Criar atalho do WinForge')) `
                -Headline (Get-WinForgeText 'O atalho não foi criado') -Note ($failures -join ' '))
    }

    # Diz onde o atalho ficou, para a faixa de resultado responder a pergunta "onde ele foi parar?".
    $where = Join-WinForgeList -Items @($createdIds | ForEach-Object { if ($_ -eq "StartMenu") { (Get-WinForgeText 'no Menu Iniciar') } else { (Get-WinForgeText 'na Área de Trabalho') } })
    # Frases inteiras por verbo (atualizado, criado ou gravado): o particípio concorda diferente em cada idioma.
    $verb = $(if ($updated -eq $created) { "updated" } elseif ($updated -eq 0) { "created" } else { "written" })
    $doneText = @{
        updated = @{ One = (Get-WinForgeText 'Atalho atualizado'); Many = (Get-WinForgeText 'Atalhos atualizados'); Where = (Get-WinForgeText 'atalho atualizado {0}' "$where"); But = (Get-WinForgeText 'atalho atualizado {0}, mas {1}' "$where" "{0}"); Only = (Get-WinForgeText 'Atalho atualizado só {0}' "$where") }
        created = @{ One = (Get-WinForgeText 'Atalho criado'); Many = (Get-WinForgeText 'Atalhos criados'); Where = (Get-WinForgeText 'atalho criado {0}' "$where"); But = (Get-WinForgeText 'atalho criado {0}, mas {1}' "$where" "{0}"); Only = (Get-WinForgeText 'Atalho criado só {0}' "$where") }
        written = @{ One = (Get-WinForgeText 'Atalho gravado'); Many = (Get-WinForgeText 'Atalhos gravados'); Where = (Get-WinForgeText 'atalho gravado {0}' "$where"); But = (Get-WinForgeText 'atalho gravado {0}, mas {1}' "$where" "{0}"); Only = (Get-WinForgeText 'Atalho gravado só {0}' "$where") }
    }[$verb]

    if ($failed -gt 0) {
        # O título diz onde o atalho ficou; a frase, onde não ficou e por quê.
        return (Set-WinForgeResultView -Result (New-WinForgeResult -Kind Warning -Detail (Get-WinForgeText '{0}, {1} com erro' "$(Format-WinForgeCount -Count $created -One (Get-WinForgeText 'atalho criado') -Many (Get-WinForgeText 'atalhos criados'))" "$failed") -Title (Get-WinForgeText 'Criar atalho do WinForge')) `
                -Headline $doneText.Only -Note ($failures -join ' '))
    }

    # Um atalho sem o ícone ou sem o identificador da barra de tarefas funciona, mas não é o que a pessoa espera ver. Na
    # faixa, cada ressalva vai com a frase inteira que a tela mostrou.
    $caveats = @()
    $caveatNotes = @()

    if (-not $Launch.HasIcon) {
        $caveats += (Get-WinForgeText 'está com o ícone do PowerShell')
        $caveatNotes += (Get-WinForgeText 'O arquivo assets\WinForge.ico não foi encontrado; o atalho usa o ícone do PowerShell.')
    }

    if ($appIdMissing) {
        $caveats += (Get-WinForgeText 'o botão pode aparecer como PowerShell ao ser fixado na barra de tarefas')
        $caveatNotes += (Get-WinForgeText 'O Windows não aceitou o identificador da barra de tarefas: fixado na barra, o atalho pode aparecer como PowerShell.')
    }

    # A faixa da janela: o que foi feito no título; onde ficou e como fixar na frase.
    $headline = $(if ($created -gt 1) { $doneText.Many } else { $doneText.One })
    $pinHint = $(if ($created -gt 1) { (Get-WinForgeText 'clique num deles com o botão direito') } else { (Get-WinForgeText 'clique nele com o botão direito') })
    $whereText = $where.Substring(0, 1).ToUpperInvariant() + $where.Substring(1)

    if ($caveats.Count -gt 0) {
        return (Set-WinForgeResultView -Result (New-WinForgeResult -Kind Warning -Detail ($doneText.But.Replace("{0}", ($caveats -join '; '))) -Title (Get-WinForgeText 'Criar atalho do WinForge')) `
                -Headline $headline -Note "$whereText. $($caveatNotes -join ' ')")
    }

    return (Set-WinForgeResultView -Result (New-WinForgeResult -Kind Ok -Detail $doneText.Where -Title (Get-WinForgeText 'Criar atalho do WinForge')) `
            -Headline $headline -Note (Get-WinForgeText '{0}. Para fixar na barra de tarefas, {1}.' "$whereText" "$pinHint"))
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
            $writers = @(Get-WinForgeScheduleUntrustedWriters -Root (Get-WinForgeAppRoot) | Where-Object { [string]$_ -notlike (Get-WinForgeText 'não foi possível conferir as permissões de {0}' '*') })
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

    Write-WinForgeStatus -Type Warning -Notice -Message (Get-WinForgeText 'Outras contas deste PC ({0}) podem alterar os arquivos do WinForge, que roda como Administrador: se mais alguém usa este PC, extraia o WinForge de novo em Arquivos de Programas e crie o atalho de lá.' "$($writers -join ', ')")
    Write-Host ""
}


function Get-WinForgeShortcutState {
    <#
    Cada lugar do atalho (Área de Trabalho, Menu Iniciar) com Exists e Current (o atalho abre esta pasta do WinForge;
    um atalho que não pôde ser lido conta como desta pasta, para não acusar à toa). Sem um atalho desta conta, o do
    instalador (para todos os usuários) no mesmo lugar conta como atalho desta pasta, com Common.

    Com -Identity, Outdated diz se o atalho desta conta que abre esta pasta tem outro identificador da barra de tarefas
    (Get-WinForgeAppId): um atalho de antes do identificador por pasta, ou sem nenhum. Ele abre o WinForge, mas, fixado na
    barra, ficaria ao lado da janela, e não junto. Um identificador que não pôde ser lido não acusa. Sem -Identity (o
    Início, que não espera por isso), Outdated é sempre $false.
    #>
    param ([switch]$Identity)

    $script = Join-Path (Get-WinForgeAppRoot) "WinForge.Gui.ps1"
    $appId = $(if ($Identity) { Get-WinForgeAppId } else { "" })

    foreach ($place in @(Get-WinForgeShortcutLocation)) {
        $exists = Test-Path -LiteralPath $place.Path -PathType Leaf
        $current = $true
        $common = $false
        $outdated = $false

        if (-not $exists) {
            try { $common = [bool](Test-WinForgeInstallerShortcut -Id $place.Id) } catch { $common = $false }
        }

        if ($exists) {
            $target = Read-WinForgeShortcutCached -Path $place.Path -Kind Target

            if ($null -ne $target -and [string]$target.Arguments -and ([string]$target.Arguments).IndexOf($script, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
                $current = $false
            }

            # Só o atalho que, lido, abre esta pasta: o de outra pasta já pede Criar atalho de novo (o identificador dele é
            # o daquela pasta), e um que não pôde ser lido não acusa.
            if ($Identity -and $null -ne $target -and ([string]$target.Arguments).IndexOf($script, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
                $saved = Read-WinForgeShortcutCached -Path $place.Path -Kind AppId
                $outdated = ($null -ne $saved -and -not [string]::Equals([string]$saved, $appId, [StringComparison]::OrdinalIgnoreCase))
            }
        }

        [PSCustomObject]@{ Id = $place.Id; Label = $place.Label; Path = $place.Path; Exists = ($exists -or $common); Current = $current; Common = $common; Outdated = $outdated }
    }
}


function Read-WinForgeShortcutCached {
    <#
    O destino (Target: Get-WinForgeShortcutTarget) ou o identificador da barra de tarefas (AppId: Get-WinForgeShortcutAppId)
    de um atalho, lido uma vez enquanto o arquivo não muda. Cada leitura abre o atalho pelo COM, e a página Sobre o WinForge
    pergunta duas vezes a cada vez que é desenhada (o resumo e o destaque), o Início também, e a troca de tema a desenha de
    novo. Um atalho regravado (Criar atalho do WinForge) muda a data e o tamanho, e é lido de novo. $null se não foi
    possível ler; o que não pôde ser lido não fica guardado, e a próxima vez tenta de novo.
    #>
    param (
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][ValidateSet("Target", "AppId")][string]$Kind
    )

    $stamp = ""

    try {
        $file = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
        $stamp = "$($file.LastWriteTimeUtc.Ticks)|$($file.Length)"
    }
    catch {
        return $null
    }

    $key = "$Kind|$Path"
    $known = $script:WinForgeShortcutReads[$key]
    if ($null -ne $known -and $known.Stamp -eq $stamp) { return $known.Value }

    $value = $null

    try {
        $value = $(if ($Kind -eq "Target") { Get-WinForgeShortcutTarget -Path $Path } else { Get-WinForgeShortcutAppId -Path $Path })
    }
    catch {
        $value = $null
    }

    if ($null -ne $value) { $script:WinForgeShortcutReads[$key] = @{ Stamp = $stamp; Value = $value } }

    return $value
}


function Test-WinForgeAppShortcutNeeded {
    <#
    Se a página Sobre o WinForge põe Criar atalho em destaque: falta o atalho desta pasta (desta conta ou do instalador),
    um deles abre outra pasta do WinForge ou o desta conta precisa ser atualizado (o identificador da barra de tarefas de
    antes). Com o atalho pronto, ele é uma linha como as outras. Com a conta de outro Administrador (o atalho iria para
    essa conta) ou sem as pastas do atalho, criar não daria certo: sem destaque. Sem conseguir ler, fica em destaque, como
    antes.
    #>
    try {
        # A mesma consulta do resumo do alto (Get-WinForgeAboutPageStatus): a conta da janela não muda enquanto ela está aberta.
        if ($null -eq $script:WinForgeAccountMismatch) { $script:WinForgeAccountMismatch = [bool](Test-WinForgeUserContextMismatch) }
        if ($script:WinForgeAccountMismatch) { return $false }

        $places = @(Get-WinForgeShortcutState -Identity)
    }
    catch {
        return $true
    }

    if ($places.Count -eq 0) { return $false }
    if (@($places | Where-Object { $_.Exists -and (-not $_.Current -or $_.Outdated) }).Count -gt 0) { return $true }

    return (@($places | Where-Object { $_.Exists }).Count -eq 0)
}


function Set-WinForgeInterfaceLanguage {
    <#
    Sobre o WinForge > Idioma, pelo menu de texto (na janela, o cartão Idioma da página faz o mesmo): como o Windows,
    português, inglês ou espanhol. A escolha fica guardada e vale na próxima vez que o WinForge abrir; o -Language do
    WinForge-Console.cmd, quando usado, passa na frente dela só naquela execução.
    #>
    $title = (Get-WinForgeText 'Idioma')

    Enter-WinForgeAction -Title $title

    $current = Get-WinForgeLanguagePreference
    $choices = @(Get-WinForgeLanguageChoices)
    $inUse = Get-WinForgeLanguage

    # Os nomes vêm das escolhas do cartão Idioma (cada idioma escrito nele mesmo), e não de uma segunda lista.
    Write-WinForgeKeyValue -Label (Get-WinForgeText 'Escolhido') -Value ([string](@($choices | Where-Object { $_.Id -eq $current })[0].Label))
    Write-WinForgeKeyValue -Label (Get-WinForgeText 'Em uso agora') -Value ([string](@($choices | Where-Object { $_.Id -eq $inUse })[0].Label))
    Write-Host ""

    $options = @()
    $position = 1

    foreach ($choice in $choices) {
        $options += @{ Key = "$position"; Label = [string]$choice.Label; Description = $(if ($choice.Id -eq $current) { (Get-WinForgeText 'a escolha atual') } else { "" }) }
        $position++
    }

    $options += @{ Key = "0"; Label = (Get-WinForgeText 'Voltar'); Exit = $true }

    $answer = Read-WinForgeChoice -Message (Get-WinForgeText 'Em que idioma o WinForge deve abrir?') -Options $options -DefaultKey "0" -ShowMenu

    $index = 0
    if (-not [int]::TryParse([string]$answer, [ref]$index) -or $index -lt 1 -or $index -gt $choices.Count) {
        Exit-WinForgeAction -Result (New-WinForgeResult -Kind Skipped -Detail (Get-WinForgeText 'nada mudou') -Title $title)
        return
    }

    $chosen = $choices[$index - 1]

    if ([string]$chosen.Id -eq $current) {
        Exit-WinForgeAction -Result (New-WinForgeResult -Kind Skipped -Detail (Get-WinForgeText 'o idioma escolhido já era esse') -Title $title)
        return
    }

    if (-not (Set-WinForgeLanguagePreference -Language ([string]$chosen.Id))) {
        $failed = New-WinForgeResult -Kind Failed -Detail (Get-WinForgeText 'não foi possível guardar a escolha do idioma') -Title $title
        Exit-WinForgeAction -Result (Set-WinForgeResultView -Result $failed -Headline (Get-WinForgeText 'O idioma não mudou') -Note (Format-WinForgeReasonNote -Text $failed.Detail))
        return
    }

    $result = New-WinForgeResult -Kind Ok -Detail (Get-WinForgeText 'idioma escolhido: {0}; vale quando o WinForge abrir de novo' "$($chosen.Label)") -Title $title
    Exit-WinForgeAction -Result (Set-WinForgeResultView -Result $result -Headline (Get-WinForgeText 'Idioma escolhido: {0}' "$($chosen.Label)") -Note (Get-WinForgeText 'Vale quando o WinForge abrir de novo.'))
}


function Show-WinForgeAbout {
    # Tela "Versão e pastas": o que está aberto, de que pasta (instalada ou só extraída: a linha Instalação diz) e onde
    # ficam os logs, os relatórios e os atalhos.
    Enter-WinForgeAction -Title (Get-WinForgeText 'Versão e pastas')

    $dataPath = Get-WinForgeDataPath

    Write-WinForgeSection -Title "WinForge"
    Write-WinForgeKeyValue -Label (Get-WinForgeText 'Versão') -Value "$(Get-WinForgeBuild)"
    Write-WinForgeKeyValue -Label (Get-WinForgeText 'Pasta do WinForge') -Value (Get-WinForgeAppRoot)

    try { Write-WinForgeKeyValue -Label (Get-WinForgeText 'Instalação') -Value (Get-WinForgeInstallStateText).Text } catch { Write-Verbose "Instalação: $($_.Exception.Message)" }
    Write-WinForgeKeyValue -Label "PowerShell" -Value "$($PSVersionTable.PSVersion) ($($PSVersionTable.PSEdition))"
    Write-WinForgeKeyValue -Label (Get-WinForgeText 'Administrador') -Value $(if (Test-WinForgeAdministrator) { (Get-WinForgeText 'Sim') } else { (Get-WinForgeText 'Não') })

    Write-WinForgeSection -Title (Get-WinForgeText 'Pastas')
    Write-WinForgeKeyValue -Label (Get-WinForgeText 'Logs e relatórios') -Value $dataPath

    $logPath = Get-WinForgeLogPath

    if (-not [string]::IsNullOrWhiteSpace($logPath)) {
        Write-WinForgeKeyValue -Label (Get-WinForgeText 'Log desta sessão') -Value $logPath
    }

    Write-WinForgeSection -Title (Get-WinForgeText 'Atalho')

    $iconMissing = ($null -eq (Get-WinForgeIconPath))

    if ($iconMissing) {
        Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'O arquivo assets\WinForge.ico não foi encontrado; os atalhos usam o ícone do PowerShell.')
    }

    foreach ($place in @(Get-WinForgeShortcutState -Identity)) {
        $text = $(if (-not $place.Exists) { (Get-WinForgeText 'Sem atalho') } elseif ($place.Common) { (Get-WinForgeText 'Atalho do instalador, para todos os usuários') } elseif (-not $place.Current) { (Get-WinForgeText 'Atalho de outra pasta do WinForge; crie de novo') } elseif ($place.Outdated) { (Get-WinForgeText 'Atalho precisa ser atualizado; crie de novo') } else { (Get-WinForgeText 'Atalho criado') })
        Write-WinForgeKeyValue -Label $place.Label -Value $text
    }

    # É uma tela de leitura: sem problema, não há faixa de resultado; com o ícone faltando, a faixa diz exatamente isso.
    if ($iconMissing) {
        $missing = New-WinForgeResult -Kind Warning -Detail (Get-WinForgeText 'o ícone assets\WinForge.ico não foi encontrado') -Title (Get-WinForgeText 'Versão e pastas')
        Exit-WinForgeAction -Result (Set-WinForgeResultView -Result $missing -Headline (Get-WinForgeText 'O ícone do WinForge não foi encontrado') `
                -Note (Get-WinForgeText 'Os atalhos usam o ícone do PowerShell até você extrair a pasta inteira do WinForge de novo.'))
    }
    else {
        Exit-WinForgeAction
    }
}


function Get-WinForgeAboutShortcutRow {
    # A linha Atalho do resumo de Sobre o WinForge: onde o atalho desta pasta já existe, ou o que falta nele.
    try {
        $places = @(Get-WinForgeShortcutState -Identity)
        $with = @($places | Where-Object { $_.Exists -and $_.Current } | ForEach-Object { [string]$_.Label })
        $stale = @($places | Where-Object { $_.Exists -and -not $_.Current } | ForEach-Object { [string]$_.Label })
        $outdated = @($places | Where-Object { $_.Exists -and $_.Current -and $_.Outdated } | ForEach-Object { [string]$_.Label })

        if ($places.Count -eq 0) {
            return [PSCustomObject]@{ Label = (Get-WinForgeText 'Atalho'); Text = (Get-WinForgeText 'o Windows não informou as pastas do atalho'); Level = "Muted" }
        }

        if ($stale.Count -gt 0) {
            # O atalho de uma cópia antiga (outra pasta) abriria a versão velha.
            return [PSCustomObject]@{ Label = (Get-WinForgeText 'Atalho'); Text = (Get-WinForgeText 'o de {0} abre outra pasta do WinForge; use Criar atalho do WinForge' "$(Join-WinForgeList -Items $stale)"); Level = "Warn" }
        }

        if ($outdated.Count -gt 0) {
            # Abre esta pasta, com o identificador da barra de tarefas de antes: fixado, ficaria ao lado da janela.
            return [PSCustomObject]@{ Label = (Get-WinForgeText 'Atalho'); Text = (Get-WinForgeText 'o de {0} precisa ser atualizado; use Criar atalho do WinForge' "$(Join-WinForgeList -Items $outdated)"); Level = "Warn" }
        }

        if ($with.Count -eq 0) {
            return [PSCustomObject]@{ Label = (Get-WinForgeText 'Atalho'); Text = (Get-WinForgeText 'ainda não criado; use Criar atalho do WinForge'); Level = "Muted" }
        }

        return [PSCustomObject]@{ Label = (Get-WinForgeText 'Atalho'); Text = (Join-WinForgeList -Items $with); Level = "Normal" }
    }
    catch {
        return [PSCustomObject]@{ Label = (Get-WinForgeText 'Atalho'); Text = (Get-WinForgeText 'não foi possível ler'); Level = "Muted" }
    }
}


function Get-WinForgeAboutPageStatus {
    <#
    O resumo no alto da página Sobre o WinForge: a versão (e o que o WinForge sabe da última publicada), onde o atalho já
    existe (e se ele abre esta pasta), a instalação, o ícone e, quando é o caso, a falta de Administrador, a conta e as
    permissões da pasta. Cada linha tem Label, Text, Level (Normal | Warn | Muted) e, a da versão nova, Opens (Verificar
    nova versão). Só lê o que é local, sem consultar a internet: a última publicada é a da última consulta (Verificar nova
    versão ou o monitor). Cada linha que não puder ser lida vira "não foi possível ler" sozinha, em vez de derrubar a página.
    #>
    $rows = @()

    try {
        $build = "$(Get-WinForgeBuild)"
        $known = $null
        try { $known = Get-WinForgeKnownUpdate } catch { $known = $null }

        if ($null -ne $known -and $known.Newer) {
            $rows += [PSCustomObject]@{ Label = (Get-WinForgeText 'Versão'); Text = (Get-WinForgeText '{0}; a versão {1} está disponível' "$build" "$($known.Latest)"); Level = "Warn"; Opens = "app.update" }
        }
        elseif ($null -ne $known -and $known.Fresh -and $known.Current) {
            $rows += [PSCustomObject]@{ Label = (Get-WinForgeText 'Versão'); Text = (Get-WinForgeText '{0}, a mais recente' "$build"); Level = "Normal" }
        }
        else {
            $rows += [PSCustomObject]@{ Label = (Get-WinForgeText 'Versão'); Text = $build; Level = "Normal" }
        }
    }
    catch {
        $rows += [PSCustomObject]@{ Label = (Get-WinForgeText 'Versão'); Text = (Get-WinForgeText 'não foi possível ler'); Level = "Muted" }
    }

    # Uma consulta só por processo: a conta da janela não muda enquanto ela está aberta.
    $mismatch = $false
    try {
        if ($null -eq $script:WinForgeAccountMismatch) { $script:WinForgeAccountMismatch = [bool](Test-WinForgeUserContextMismatch) }
        $mismatch = [bool]$script:WinForgeAccountMismatch
    }
    catch {
        Write-Verbose "Conta: $($_.Exception.Message)"
    }

    # Com a conta de outro Administrador, a Área de Trabalho e o Menu Iniciar seriam os dessa conta, onde Criar atalho não
    # grava: a linha Conta diz isso, e o atalho não aparece como "ainda não criado".
    if (-not $mismatch) { $rows += Get-WinForgeAboutShortcutRow }

    # Instalado (desinstala por Configurações > Aplicativos) ou aberto da pasta extraída (instala pelo WinForge-Setup.cmd).
    try {
        $install = Get-WinForgeInstallStateText
        $rows += [PSCustomObject]@{ Label = (Get-WinForgeText 'Instalação'); Text = $install.Text; Level = $install.Level }
    }
    catch {
        $rows += [PSCustomObject]@{ Label = (Get-WinForgeText 'Instalação'); Text = (Get-WinForgeText 'não foi possível ler'); Level = "Muted" }
    }

    # O ícone na sua própria linha: uma falha ao conferi-lo não vira uma segunda linha "Atalho".
    try {
        if ($null -eq (Get-WinForgeIconPath)) {
            $rows += [PSCustomObject]@{ Label = (Get-WinForgeText 'Ícone'); Text = (Get-WinForgeText 'o arquivo do ícone (assets\WinForge.ico) não foi encontrado; extraia a pasta inteira do WinForge de novo'); Level = "Warn" }
        }
    }
    catch {
        Write-Verbose "Ícone: $($_.Exception.Message)"
    }

    try {
        # O WinForge abre sempre como Administrador, e a barra lateral já diz isso: a linha só aparece sem ele (a pessoa
        # recusou o aviso do Windows ao abrir), com o que muda.
        if (-not (Test-WinForgeAdministrator)) {
            $rows += [PSCustomObject]@{ Label = (Get-WinForgeText 'Administrador'); Text = (Get-WinForgeText 'esta janela está sem Administrador; as ações que alteram o sistema pedem a permissão de novo'); Level = "Warn" }
        }
    }
    catch {
        $rows += [PSCustomObject]@{ Label = (Get-WinForgeText 'Administrador'); Text = (Get-WinForgeText 'não foi possível ler'); Level = "Muted" }
    }

    if ($mismatch) {
        $rows += [PSCustomObject]@{ Label = (Get-WinForgeText 'Conta'); Text = (Get-WinForgeText 'o WinForge está aberto com a conta de outro Administrador; atalhos, pastas e o monitor são os dessa conta'); Level = "Warn" }
    }

    $writers = @(Get-WinForgeAppFolderWriters)

    if ($writers.Count -gt 0) {
        $rows += [PSCustomObject]@{ Label = (Get-WinForgeText 'Pasta'); Text = (Get-WinForgeText 'outras contas deste PC podem alterar os arquivos do WinForge; se mais alguém usa o PC, extraia o WinForge de novo em Arquivos de Programas'); Level = "Warn" }
    }

    return $rows
}


Export-ModuleMember -Function *
