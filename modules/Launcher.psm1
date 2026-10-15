# O próprio WinForge no Windows: ícone, identidade na barra de tarefas e os atalhos (.lnk) que abrem a janela.
# O trabalho de baixo nível (COM e API do shell) fica em Shell.psm1; aqui estão as decisões: o que o atalho executa,
# qual ícone usa e onde é criado.

$script:WinForgeAppId = "WinForge.App"
$script:WinForgeAppRoot = Split-Path -Parent $PSScriptRoot
$script:WinForgeShortcutFileName = "WinForge.lnk"


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
            Write-WinForgeStatus -Type Info -Message "Nenhum atalho foi criado."
        }
        else {
            $result = New-WinForgeShortcutFiles -Places $selected -Launch $launch
        }
    }

    if ($PassThru) { $result }
    Exit-WinForgeAction -Embedded:$Embedded
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

    foreach ($place in $Places) {
        $position++
        $options += @{ Key = [string]$position; Label = $place.Label; Description = $place.Folder; Accent = ($position -eq 1) }
    }

    $options += @{ Key = "A"; Label = "Os dois"; Description = "Todos os lugares acima" }
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
    $failed = 0
    $appIdMissing = $false

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
            $verb = if ($existed) { "atualizado" } else { "criado" }
            Write-WinForgeStatus -Type Success -Message "Atalho $verb em $($place.Label): $($place.Path)"

            if (-not $saved.AppIdSet) { $appIdMissing = $true }
        }
        catch {
            $failed++
            Write-WinForgeStatus -Type Error -Message "Não foi possível criar o atalho em $($place.Label): $($_.Exception.Message)"
        }
    }

    if ($created -gt 0) {
        Write-Host ""

        if (-not $Launch.HasIcon) {
            Write-WinForgeStatus -Type Warning -Message "O arquivo assets\WinForge.ico não foi encontrado; o atalho usa o ícone do PowerShell."
        }

        if ($appIdMissing) {
            Write-WinForgeStatus -Type Warning -Message "O Windows não aceitou o identificador da barra de tarefas. O atalho funciona, mas ao fixá-lo na barra o botão pode aparecer como PowerShell."
        }

        Write-WinForgeStatus -Type Info -Message "Para fixar na barra de tarefas: clique no atalho com o botão direito e escolha 'Fixar na barra de tarefas'."
        Write-WinForgeStatus -Type Info -Message "Se você mover a pasta do WinForge, crie o atalho de novo."
    }

    if ($created -eq 0) {
        return (New-WinForgeResult -Kind Failed -Detail "nenhum atalho criado" -Title "Criar atalho do WinForge")
    }

    if ($failed -gt 0) {
        return (New-WinForgeResult -Kind Warning -Detail "$created criado(s), $failed com erro" -Title "Criar atalho do WinForge")
    }

    return (New-WinForgeResult -Kind Ok -Title "Criar atalho do WinForge")
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

    if ($null -eq (Get-WinForgeIconPath)) {
        Write-WinForgeStatus -Type Warning -Message "O arquivo assets\WinForge.ico não foi encontrado; os atalhos usam o ícone do PowerShell."
    }

    foreach ($place in @(Get-WinForgeShortcutLocation)) {
        $exists = Test-Path -LiteralPath $place.Path -PathType Leaf
        Write-WinForgeKeyValue -Label $place.Label -Value $(if ($exists) { "Atalho criado" } else { "Sem atalho" })
    }

    Exit-WinForgeAction
}


Export-ModuleMember -Function *
