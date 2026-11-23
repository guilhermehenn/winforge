# Limpeza: temporários, Lixeira, Downloads e componentes do Windows.
# Toda exclusão passa por Remove-WinForgeItem, que nunca segue atalhos de pasta (junções e links simbólicos).

$script:WinForgeProgressStopwatch = $null

# Temporários mais novos que isto ficam: um instalador ou uma atualização em andamento pode precisar deles entre um passo
# e outro (sem prendê-los), e apagá-los quebraria a instalação. A Limpeza de Disco do Windows usa 7 dias; a limpeza à mão
# fica com um dia, que libera quase tudo do mesmo jeito.
$script:WinForgeTempMinAgeHours = 24
$script:WinForgeRecycleBinCapacityCache = @{}


# ---------------------------------------------------------------------------
# Conta
# ---------------------------------------------------------------------------

function Write-WinForgeOtherAccountNotice {
    <#
    Com o WinForge aberto com outra conta (o pedido de Administrador respondido com a senha de outra pessoa), o que é de
    cada conta (temporários, Lixeira, AppData, registro do usuário) é o dessa conta, não o de quem está usando o Windows:
    um aviso antes da pergunta (Test-WinForgeUserContextMismatch). What diz o quê ("os temporários e a Lixeira"), em
    português (a chave da tradução): o artigo do começo faz a frase concordar, e o espanhol tem o mesmo gênero e número
    em todos os textos usados. Devolve $true quando avisou.
    #>
    param ([Parameter(Mandatory)][string]$What)

    if (-not (Test-WinForgeUserContextMismatch)) { return $false }

    $account = $(if (-not [string]::IsNullOrWhiteSpace($env:USERNAME)) { $env:USERNAME } else { [Environment]::UserName })

    $predicate = switch (($What.Trim() -split ' ', 2)[0].ToLowerInvariant()) {
        "as" { (Get-WinForgeText 'são as dessa conta, não as') }
        "a" { (Get-WinForgeText 'é a dessa conta, não a') }
        "o" { (Get-WinForgeText 'é o dessa conta, não o') }
        default { (Get-WinForgeText 'são os dessa conta, não os') }
    }

    Write-WinForgeStatus -Type Warning -Notice -Message (Get-WinForgeText 'O WinForge está aberto com outra conta ({0}): {1} {2} de quem está usando o Windows.' "$account" "$(Get-WinForgeText $What)" "$predicate")
    return $true
}


function Get-WinForgeDriveType {
    # O tipo da unidade de uma raiz como "C:\" (Fixed, Removable, Network, CDRom...), ou "" quando não dá para saber.
    param (
        [Parameter(Mandatory)]
        [string]$Root
    )

    try {
        return [string](New-Object System.IO.DriveInfo -ArgumentList $Root).DriveType
    }
    catch {
        return ""
    }
}


function Get-WinForgeRecycleBinCapacity {
    <#
    Como a Lixeira de uma unidade fixa ("C:\\") está configurada para o usuário: Nuke (verdadeiro = ela não guarda nada,
    apaga na hora) e MaxBytes (o limite; um item maior que ele é apagado em definitivo pelo Windows, sem perguntar, já que o
    envio é feito sem as janelas de confirmação). Lê a política (NoRecycleFiles, RecycleBinSize), a configuração da
    unidade (BitBucket\Volume\{GUID}: NukeOnDelete e MaxCapacity em MB) e, sem nada disso, usa o padrão do Windows:
    10% dos primeiros 40 GB da unidade e 5% do resto. Um limite configurado em zero vale como "apaga na hora". O GUID
    da unidade vem do mountvol e, sem ele, do WMI; sem nenhum dos dois, vale o mais cauteloso das unidades configuradas
    (qualquer uma que apaga na hora, o menor limite). MaxBytes 0 = não deu para saber. Fica guardado por dois minutos:
    uma limpeza manda centenas de itens para a Lixeira, e a resposta não muda no meio dela.
    #>
    param (
        [Parameter(Mandatory)]
        [string]$Root
    )

    $now = Get-Date
    $cached = $script:WinForgeRecycleBinCapacityCache[$Root]

    if ($null -ne $cached -and ($now - $cached.At).TotalMinutes -lt 2) { return $cached.Capacity }

    $policy = "Software\Microsoft\Windows\CurrentVersion\Policies\Explorer"
    $nuke = $false
    $percent = $null
    $number = 0

    foreach ($hive in @("HKLM:", "HKCU:")) {
        if ([string](Get-WinForgeRegistryValueOrNull -Path "$hive\$policy" -Name "NoRecycleFiles") -eq "1") { $nuke = $true }
        if ($null -eq $percent -and [int]::TryParse([string](Get-WinForgeRegistryValueOrNull -Path "$hive\$policy" -Name "RecycleBinSize"), [ref]$number)) { $percent = $number }
    }

    $maxMegabytes = $null

    if ($null -ne $percent -and $percent -le 0) { $nuke = $true }

    if (-not $nuke) {
        $letter = $Root.TrimEnd([char[]]@('\', '/'))
        $guid = $(if ($letter -match '^[A-Za-z]:$') { Get-WinForgeVolumeGuid -Letter $letter } else { "" })
        $volumes = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\BitBucket\Volume"
        $buckets = $(if ($guid) { @("$volumes\$guid") } else { @(Get-ChildItem -LiteralPath $volumes -ErrorAction SilentlyContinue | ForEach-Object { $_.PSPath }) })

        foreach ($bucket in $buckets) {
            if ([string](Get-WinForgeRegistryValueOrNull -Path $bucket -Name "NukeOnDelete") -eq "1") { $nuke = $true }

            if ([int]::TryParse([string](Get-WinForgeRegistryValueOrNull -Path $bucket -Name "MaxCapacity"), [ref]$number)) {
                if ($null -eq $maxMegabytes -or $number -lt $maxMegabytes) { $maxMegabytes = $number }
            }
        }

        if ($null -eq $percent -and $null -ne $maxMegabytes -and $maxMegabytes -le 0) { $nuke = $true }
    }

    $maxBytes = [int64]0

    if (-not $nuke) {
        if ($null -ne $maxMegabytes -and $null -eq $percent) {
            $maxBytes = [int64]$maxMegabytes * 1MB
        }
        else {
            $total = [int64]0
            try { $total = [int64](New-Object System.IO.DriveInfo -ArgumentList $Root).TotalSize } catch { $total = [int64]0 }

            if ($total -gt 0 -and $null -ne $percent) { $maxBytes = [int64]($total * [Math]::Min(100, [Math]::Max(0, $percent)) / 100) }
            elseif ($total -gt 0) { $maxBytes = [int64]([Math]::Min($total, [int64]40GB) * 0.10 + [Math]::Max([int64]0, $total - [int64]40GB) * 0.05) }
        }
    }

    $capacity = [PSCustomObject]@{ Nuke = $nuke; MaxBytes = $maxBytes }
    $script:WinForgeRecycleBinCapacityCache[$Root] = @{ At = $now; Capacity = $capacity }

    return $capacity
}


function Get-WinForgeVolumeGuid {
    # O {GUID} do volume de uma letra ("C:"), que nomeia a configuração da Lixeira dele no registro; "" sem resposta.
    # Primeiro o mountvol (rápido e sem WMI); depois o WMI, com tempo limite (um WMI estragado não segura a limpeza).
    param ([Parameter(Mandatory)][string]$Letter)

    $pattern = '\{[0-9A-Fa-f-]{36}\}'

    try {
        $match = [regex]::Match([string](Invoke-WinForgeCapture -FilePath "mountvol.exe" -Arguments @("$Letter\", "/L")).Text, $pattern)
        if ($match.Success) { return $match.Value }
    }
    catch {
        Write-Verbose "mountvol: $($_.Exception.Message)"
    }

    try {
        $volume = @(Get-CimInstance -ClassName Win32_Volume -Filter "DriveLetter = '$Letter'" -OperationTimeoutSec 15 -ErrorAction Stop) | Select-Object -First 1
        $match = [regex]::Match([string]$volume.DeviceID, $pattern)
        if ($match.Success) { return $match.Value }
    }
    catch {
        Write-Verbose "Win32_Volume: $($_.Exception.Message)"
    }

    return ""
}


function Get-WinForgeRecycleBinProblem {
    <#
    Por que um item NÃO iria para a Lixeira, ou "" quando ele vai. Pastas de rede (\\servidor\pasta), unidades de rede
    mapeadas, pendrives e cartões de memória não têm Lixeira: nelas o Windows apaga em definitivo, sem perguntar (o envio
    é feito sem as janelas de confirmação). Só unidades fixas passam; o que não dá para identificar também fica de fora.
    #>
    param (
        [AllowEmptyString()]
        [string]$Path
    )

    $text = ([string]$Path).Trim()

    if ([string]::IsNullOrWhiteSpace($text)) {
        return (Get-WinForgeText 'não fica numa unidade que o WinForge consiga identificar')
    }

    if ($text.StartsWith("\\") -or $text.StartsWith("//")) {
        return (Get-WinForgeText 'fica numa pasta de rede, que não tem Lixeira')
    }

    try {
        $root = [IO.Path]::GetPathRoot([IO.Path]::GetFullPath($text))
    }
    catch {
        $root = ""
    }

    if ([string]::IsNullOrWhiteSpace($root) -or $root.StartsWith("\\")) {
        return (Get-WinForgeText 'não fica numa unidade que o WinForge consiga identificar')
    }

    $drive = $root.TrimEnd([char[]]@('\', '/'))
    if ([string]::IsNullOrEmpty($drive)) { $drive = $root }

    switch (Get-WinForgeDriveType -Root $root) {
        "Fixed" {
            if ((Get-WinForgeRecycleBinCapacity -Root $root).Nuke) { return (Get-WinForgeText 'fica em {0}, onde a Lixeira está configurada para apagar na hora' "$drive") }
            return ""
        }
        "Network" { return (Get-WinForgeText 'fica numa unidade de rede ({0}), que não tem Lixeira' "$drive") }
        "Removable" { return (Get-WinForgeText 'fica num pendrive ou cartão de memória ({0}), que não tem Lixeira' "$drive") }
        "CDRom" { return (Get-WinForgeText 'fica num CD ou DVD ({0}), que não tem Lixeira' "$drive") }
    }

    return (Get-WinForgeText 'fica numa unidade sem Lixeira ou que não foi possível identificar ({0})' "$drive")
}


function Test-WinForgeRecycleBinLimitExceeded {
    <#
    Se algum dos itens (objetos com Path e o tamanho em bytes na propriedade SizeProperty) passa do limite da Lixeira da
    unidade dele (Get-WinForgeRecycleBinCapacity). O aviso "um item maior que o limite fica onde está" só aparece antes
    da pergunta quando vale para algum item; o resumo do fim diz quais ficaram.
    #>
    param (
        [AllowEmptyCollection()][object[]]$Items = @(),
        [string]$SizeProperty = "SizeBytes"
    )

    foreach ($item in @($Items)) {
        $path = ""

        try {
            $path = [string](Get-WinForgeJsonValue -Object $item -Name "Path" -Default "")
            if ([string]::IsNullOrWhiteSpace($path)) { continue }

            $size = [int64](Get-WinForgeJsonValue -Object $item -Name $SizeProperty -Default 0)
            $limit = [int64](Get-WinForgeRecycleBinCapacity -Root ([IO.Path]::GetPathRoot([IO.Path]::GetFullPath($path)))).MaxBytes

            if ($limit -gt 0 -and $size -gt $limit) { return $true }
        }
        catch {
            Write-Verbose "Limite da Lixeira de ${path}: $($_.Exception.Message)"
        }
    }

    return $false
}


function Move-WinForgeItemToRecycleBin {
    <#
    Envia o item para a Lixeira. Recusa (lança erro) o que fica numa unidade sem Lixeira ou com a Lixeira desligada, e o
    que é maior que o limite dela: sem as janelas de confirmação, o Windows apagaria o item em definitivo enquanto a tela
    diz que ele foi para a Lixeira. SizeBytes: o tamanho, quando quem chama já mediu; sem ele, é medido aqui.
    #>
    param (
        [Parameter(Mandatory)]
        [string]$Path,

        [switch]$IsDirectory,

        [int64]$SizeBytes = -1
    )

    $problem = Get-WinForgeRecycleBinProblem -Path $Path

    if ($problem) {
        throw (Get-WinForgeText '{0}; o Windows apagaria em definitivo, então ficou onde estava' "$problem")
    }

    $limit = [int64](Get-WinForgeRecycleBinCapacity -Root ([IO.Path]::GetPathRoot([IO.Path]::GetFullPath($Path)))).MaxBytes

    if ($limit -gt 0) {
        if ($SizeBytes -lt 0) {
            $SizeBytes = $(if ($IsDirectory) { [int64](Get-WinForgePathStats -Path $Path).Size } else { [int64](Get-Item -LiteralPath $Path -Force -ErrorAction Stop).Length })
        }

        if ($SizeBytes -gt $limit) {
            throw (Get-WinForgeText 'tem {0} e passa do limite da Lixeira desta unidade ({1}): o Windows apagaria em definitivo, então ficou onde estava' "$(Format-WinForgeBytes -Bytes $SizeBytes)" "$(Format-WinForgeBytes -Bytes $limit)")
        }
    }

    Add-Type -AssemblyName Microsoft.VisualBasic -ErrorAction Stop

    if ($IsDirectory) {
        [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory(
            $Path,
            [Microsoft.VisualBasic.FileIO.UIOption]::OnlyErrorDialogs,
            [Microsoft.VisualBasic.FileIO.RecycleOption]::SendToRecycleBin)
    }
    else {
        [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile(
            $Path,
            [Microsoft.VisualBasic.FileIO.UIOption]::OnlyErrorDialogs,
            [Microsoft.VisualBasic.FileIO.RecycleOption]::SendToRecycleBin)
    }
}


function Write-WinForgeCleanupProgress {
    # Barra de progresso com limite de frequência: milhares de itens não precisam de milhares de atualizações.
    param (
        [string]$Activity,
        [int]$Current,
        [int]$Total,
        [switch]$Completed
    )

    if ($Completed) {
        Write-Progress -Activity $Activity -Completed
        $script:WinForgeProgressStopwatch = $null
        return
    }

    if ($null -eq $script:WinForgeProgressStopwatch) {
        $script:WinForgeProgressStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    }
    elseif ($script:WinForgeProgressStopwatch.ElapsedMilliseconds -lt 250 -and $Current -lt $Total) {
        return
    }

    $script:WinForgeProgressStopwatch.Restart()

    $percent = 0
    if ($Total -gt 0) { $percent = [Math]::Min(100, [int](($Current * 100) / $Total)) }

    Write-Progress -Activity $Activity -Status (Get-WinForgeText '{0} de {1}' "$(Format-WinForgeNumber -Value $Current)" "$(Format-WinForgeNumber -Value $Total)") -PercentComplete $percent
}


function Get-WinForgeFolderListing {
    <#
    Lista o primeiro nível de uma pasta. Readable = $false quando o Windows não deixa listar (sem permissão, caminho em
    uso): nesse caso não dá para saber se a pasta está vazia, e quem chama não pode dizer "nada para limpar".
    -ExcludeShellMetadata deixa de fora desktop.ini e Thumbs.db.
    #>
    param (
        [Parameter(Mandatory)]
        [string]$Path,

        [switch]$ExcludeShellMetadata
    )

    try {
        $items = @(Get-ChildItem -LiteralPath $Path -Force -ErrorAction Stop)
    }
    catch {
        return [PSCustomObject]@{ Path = $Path; Readable = $false; Reason = $_.Exception.Message; Items = @() }
    }

    if ($ExcludeShellMetadata) {
        $items = @($items | Where-Object { -not (Test-WinForgeShellMetadata -Item $_) })
    }

    return [PSCustomObject]@{ Path = $Path; Readable = $true; Reason = ""; Items = $items }
}


function Measure-WinForgeFolderItems {
    <#
    Mede os itens de uma listagem numa única passada pela árvore: arquivo pelo próprio tamanho, pasta somando o conteúdo.
    Um atalho de pasta (junção ou link simbólico) vale como o atalho, com tamanho zero, e não como a pasta de destino.
    LastActivity é quando o item chegou ou foi alterado pela última vez, olhando também dentro das pastas. A criação
    conta porque copiar um arquivo, ou extrair um .zip, mantém a data de alteração original: um arquivo copiado ontem de
    um pen drive pode ter data de alteração de 2019 e não é "antigo" na pasta Downloads.
    A regra de percurso é a de Get-WinForgePathStats (não seguir atalhos, ignorar o que não abre), mas atribuindo cada
    arquivo ao item de primeiro nível a que pertence: chamar Get-WinForgePathStats uma vez por pasta custa vários
    milissegundos de preparação cada, e uma pasta Temp tem milhares de subpastas.
    #>
    param (
        [object[]]$Items = @(),

        [switch]$ExcludeShellMetadata
    )

    $list = @($Items)
    $sizes = New-Object "int64[]" $list.Count
    $newest = New-Object "datetime[]" $list.Count
    $pending = New-Object "System.Collections.Generic.Stack[object]"
    $shellNames = @("desktop.ini", "Thumbs.db")

    for ($index = 0; $index -lt $list.Count; $index++) {
        $item = $list[$index]

        if (-not $item.PSIsContainer) {
            if (-not ($ExcludeShellMetadata -and $item.Name -in $shellNames)) {
                $sizes[$index] = [int64]$item.Length
            }
        }
        elseif (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -eq 0) {
            $pending.Push(@($item.FullName, $index))
        }
    }

    while ($pending.Count -gt 0) {
        $frame = $pending.Pop()
        $owner = [int]$frame[1]

        try {
            $directory = New-Object System.IO.DirectoryInfo -ArgumentList ([string]$frame[0])

            foreach ($entry in $directory.EnumerateFileSystemInfos()) {
                try {
                    if ($entry -is [System.IO.DirectoryInfo]) {
                        if (($entry.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -eq 0) {
                            $pending.Push(@($entry.FullName, $owner))
                        }
                    }
                    elseif (-not ($ExcludeShellMetadata -and $entry.Name -in $shellNames)) {
                        $sizes[$owner] += [int64]$entry.Length

                        # Sem chamar função aqui: este laço passa por cada arquivo de uma pasta Temp inteira.
                        if ($entry.LastWriteTime -gt $newest[$owner]) { $newest[$owner] = $entry.LastWriteTime }
                        if ($entry.CreationTime -gt $newest[$owner]) { $newest[$owner] = $entry.CreationTime }
                    }
                }
                catch {
                    # Item removido ou inacessível durante a leitura.
                }
            }
        }
        catch {
            # Pasta inacessível: segue com as demais.
        }
    }

    return @(
        for ($index = 0; $index -lt $list.Count; $index++) {
            $item = $list[$index]

            # Uma pasta antiga com arquivo novo dentro não é "antiga".
            $lastActivity = $newest[$index]
            if ($item.LastWriteTime -gt $lastActivity) { $lastActivity = $item.LastWriteTime }
            if ($item.CreationTime -gt $lastActivity) { $lastActivity = $item.CreationTime }

            [PSCustomObject]@{
                Item         = $item
                Path         = $item.FullName
                Name         = $item.Name
                IsDirectory  = [bool]$item.PSIsContainer
                LastActivity = $lastActivity
                SizeBytes    = $sizes[$index]
            }
        }
    )
}


function Get-WinForgeFolderSize {
    # Tamanho da pasta, ou $null quando ela não pôde ser lida (que é diferente de uma pasta vazia, que vale 0).
    param (
        [Parameter(Mandatory)]
        [string]$Path,

        [switch]$ExcludeShellMetadata
    )

    $listing = Get-WinForgeFolderListing -Path $Path -ExcludeShellMetadata:$ExcludeShellMetadata

    if (-not $listing.Readable) {
        return $null
    }

    $total = [int64]0

    foreach ($entry in @(Measure-WinForgeFolderItems -Items $listing.Items -ExcludeShellMetadata:$ExcludeShellMetadata)) {
        $total += [int64]$entry.SizeBytes
    }

    return $total
}


function Clear-WinForgeFolderContents {
    <#
    Esvazia uma pasta (mantendo a pasta) e devolve o balanço. Cada item é medido uma vez, antes de ser apagado: o espaço
    liberado é o dos itens que saíram e, de uma pasta que ficou pela metade, só o que de fato sumiu. Entries é a medição
    que quem chama já fez (Measure-WinForgeFolderItems); sem ela, a pasta é listada e medida aqui. Lança erro se a pasta
    não puder ser lida.
    #>
    param (
        [Parameter(Mandatory)]
        [string]$Path,

        [string]$Activity = (Get-WinForgeText 'Limpeza'),

        [object[]]$Entries,

        # Itens com atividade mais recente que isto (em horas) ficam, e são contados em Recent. 0 = sem limite.
        [int]$MinAgeHours = 0
    )

    if (-not $PSBoundParameters.ContainsKey("Entries")) {
        $listing = Get-WinForgeFolderListing -Path $Path

        if (-not $listing.Readable) {
            throw (Get-WinForgeText 'Não foi possível ler a pasta: {0}' "$($listing.Reason)")
        }

        $Entries = @(Measure-WinForgeFolderItems -Items $listing.Items)
    }

    $recent = 0

    if ($MinAgeHours -gt 0) {
        $all = @($Entries)
        $Entries = @(Select-WinForgeItemsOlderThan -Entries $all -Cutoff (Get-Date).AddHours(-$MinAgeHours))
        $recent = $all.Count - $Entries.Count
    }

    $removed = 0
    $skipped = 0
    $position = 0
    $sizeBefore = [int64]0
    $freed = [int64]0
    $total = @($Entries).Count

    foreach ($entry in @($Entries)) {
        $position++
        $sizeBefore += [int64]$entry.SizeBytes
        Write-WinForgeCleanupProgress -Activity $Activity -Current $position -Total $total

        try {
            Remove-WinForgeItem -Path $entry.Path
            $removed++
            $freed += [int64]$entry.SizeBytes
        }
        catch {
            if ($null -eq (Get-Item -LiteralPath $entry.Path -Force -ErrorAction SilentlyContinue)) {
                # Sumiu sozinho enquanto a limpeza andava (temporários vivem pouco): não estava em uso, só não há mais o que tirar.
                continue
            }

            $skipped++

            # Pasta que ficou pela metade: conta só o que saiu dela.
            $freed += Get-WinForgeFreedFromPartial -Entry $entry
        }
    }

    Write-WinForgeCleanupProgress -Activity $Activity -Current 0 -Total 0 -Completed

    return [PSCustomObject]@{
        Removed    = $removed
        Skipped    = $skipped
        Recent     = $recent
        SizeBefore = $sizeBefore
        Freed      = $freed
    }
}


function Test-WinForgeCleanupTargetSafe {
    <#
    Trava de segurança das limpezas de temporários. Uma variável TEMP mal configurada (apontando para a raiz do disco,
    para o perfil ou para o Windows) faria a "limpeza" apagar o que não é temporário. Recusa a raiz de uma unidade e
    qualquer pasta que seja, ou que contenha, o perfil do usuário, o Windows, Arquivos de Programas ou ProgramData.
    #>
    param (
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $false
    }

    $separators = [char[]]@([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)

    try {
        $full = [IO.Path]::GetFullPath($Path)
    }
    catch {
        return $false
    }

    $trimmed = $full.TrimEnd($separators)
    $root = [IO.Path]::GetPathRoot($full)

    if ([string]::IsNullOrEmpty($trimmed) -or $trimmed -eq $root.TrimEnd($separators)) {
        return $false
    }

    $protected = @($env:USERPROFILE, $env:WINDIR, $env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:ProgramData, $env:SystemDrive)

    foreach ($candidate in $protected) {
        if ([string]::IsNullOrWhiteSpace($candidate)) { continue }

        # "C:" (como em SystemDrive) significaria "a pasta atual da unidade C"; o que se quer proteger é a raiz.
        if ($candidate -match "^[A-Za-z]:$") { $candidate += "\" }

        try {
            $protectedPath = [IO.Path]::GetFullPath($candidate).TrimEnd($separators)
        }
        catch {
            continue
        }

        if ([string]::IsNullOrEmpty($protectedPath)) { continue }

        $isSame = [string]::Equals($protectedPath, $trimmed, [StringComparison]::OrdinalIgnoreCase)
        $containsProtected = $protectedPath.StartsWith($trimmed + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)

        if ($isSame -or $containsProtected) {
            return $false
        }
    }

    return $true
}


function Get-WinForgePersonalFolders {
    # As pastas pessoais do usuário, onde estiverem (o Windows pode tê-las levado para outro disco ou para o OneDrive).
    # -ExcludeDownloads: sem a Downloads (a trava da própria Downloads compara com as outras).
    param (
        [switch]$ExcludeDownloads
    )

    $folders = @(
        foreach ($name in @("Desktop", "MyDocuments", "MyPictures", "MyMusic", "MyVideos", "Favorites")) {
            try { [Environment]::GetFolderPath($name) } catch { }
        }
        if (-not $ExcludeDownloads) { (Get-WinForgeDownloadsPath) }
        $env:OneDrive
    )

    return @($folders | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
}


function Get-WinForgePathRelation {
    <#
    Como um caminho se relaciona com outro, pelo texto completo e sem diferenciar maiúsculas (como o Windows): Same (a
    mesma pasta), Inside (fica dentro da outra), Contains (contém a outra) ou None. Caminho vazio ou que não dá para
    entender = None.
    #>
    param (
        [AllowEmptyString()][string]$Path,
        [AllowEmptyString()][string]$Other
    )

    if ([string]::IsNullOrWhiteSpace($Path) -or [string]::IsNullOrWhiteSpace($Other)) {
        return "None"
    }

    $separators = [char[]]@([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)

    try {
        $first = [IO.Path]::GetFullPath($Path).TrimEnd($separators)
        $second = [IO.Path]::GetFullPath($Other).TrimEnd($separators)
    }
    catch {
        return "None"
    }

    if ([string]::IsNullOrEmpty($first) -or [string]::IsNullOrEmpty($second)) { return "None" }

    $separator = [string][IO.Path]::DirectorySeparatorChar

    if ([string]::Equals($first, $second, [StringComparison]::OrdinalIgnoreCase)) { return "Same" }
    if ($first.StartsWith($second + $separator, [StringComparison]::OrdinalIgnoreCase)) { return "Inside" }
    if ($second.StartsWith($first + $separator, [StringComparison]::OrdinalIgnoreCase)) { return "Contains" }

    return "None"
}


function Test-WinForgeOneDrivePath {
    # Se o caminho é a pasta do OneDrive (pessoal ou corporativo) ou fica dentro dela: o que muda ali muda em todos os PCs
    # da pessoa, e o que falta neste PC pode existir em outro.
    param (
        [AllowEmptyString()][string]$Path
    )

    foreach ($cloud in @($env:OneDrive, $env:OneDriveConsumer, $env:OneDriveCommercial)) {
        if ((Get-WinForgePathRelation -Path $Path -Other $cloud) -in @("Same", "Inside")) {
            return $true
        }
    }

    return $false
}


function Test-WinForgeTempFolderSafe {
    <#
    A trava das pastas de temporários: a de Test-WinForgeCleanupTargetSafe e, além dela, nada que seja ou fique dentro de
    uma pasta pessoal. Uma variável TEMP apontando para Documentos (ou para uma pasta dentro dela) faria a limpeza dos
    temporários apagar os documentos; a trava geral só recusava a raiz do disco e as pastas que contêm o perfil.
    Também recusa o que é (ou contém) a pasta de dados dos programas (AppData Local e Roaming), o perfil público, a pasta
    dos usuários e a pasta de dados do WinForge (esta, nem por dentro: é onde fica o que desfaz as mudanças). Uma TEMP
    apontando para %LOCALAPPDATA% apagaria em definitivo as configurações de todos os programas.
    -RequireTempName (as pastas TEMP do usuário e do Windows): só aceita uma pasta chamada Temp ou Tmp, ou a subpasta
    numerada de uma delas (o Windows usa Temp\2, Temp\3... nas sessões de Área de Trabalho Remota). Uma TEMP apontando
    para D:\Dados passaria nas outras travas e seria esvaziada.
    #>
    param (
        [string]$Path,

        [string[]]$PersonalFolders = @(Get-WinForgePersonalFolders),

        [switch]$RequireTempName
    )

    if (-not (Test-WinForgeCleanupTargetSafe -Path $Path)) {
        return $false
    }

    $separators = [char[]]@([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
    $full = [IO.Path]::GetFullPath($Path).TrimEnd($separators)

    foreach ($folder in @($PersonalFolders)) {
        if ([string]::IsNullOrWhiteSpace($folder)) { continue }

        try {
            $personal = [IO.Path]::GetFullPath($folder).TrimEnd($separators)
        }
        catch {
            continue
        }

        if ([string]::Equals($personal, $full, [StringComparison]::OrdinalIgnoreCase) -or
            $full.StartsWith($personal + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
            return $false
        }
    }

    $dataPath = ""
    try { $dataPath = [string](Get-WinForgeDataPath) } catch { $dataPath = "" }

    $usersRoot = ""
    if (-not [string]::IsNullOrWhiteSpace($env:USERPROFILE)) {
        try { $usersRoot = [string][IO.Path]::GetDirectoryName($env:USERPROFILE.TrimEnd($separators)) } catch { $usersRoot = "" }
    }

    foreach ($folder in @($env:LOCALAPPDATA, $env:APPDATA, $dataPath, $env:USERPROFILE, $env:PUBLIC, $usersRoot)) {
        if ((Get-WinForgePathRelation -Path $full -Other $folder) -in @("Same", "Contains")) {
            return $false
        }
    }

    if ((Get-WinForgePathRelation -Path $full -Other $dataPath) -eq "Inside") {
        return $false
    }

    if ($RequireTempName) {
        $tempNames = @("Temp", "Tmp")
        $leaf = [IO.Path]::GetFileName($full)
        $parentLeaf = ""
        try { $parentLeaf = [IO.Path]::GetFileName([IO.Path]::GetDirectoryName($full)) } catch { $parentLeaf = "" }

        $isTemp = ($leaf -in $tempNames) -or ($leaf -match '^[0-9]+$' -and $parentLeaf -in $tempNames)

        if (-not $isTemp) {
            return $false
        }
    }

    return $true
}


function Test-WinForgeDownloadsFolderSafe {
    <#
    A trava da pasta Downloads: a geral (raiz do disco, perfil, Windows, programas) e, além dela, nada que seja ou
    contenha outra pasta pessoal. O Windows deixa redirecionar Downloads para qualquer lugar; apontando para Documentos,
    para a Área de Trabalho ou para a raiz do OneDrive, "Tudo" limparia essas pastas. Ficar DENTRO de outra pasta
    pessoal (Documentos\Downloads) não é problema: o que se limpa é só o conteúdo da própria Downloads.
    #>
    param (
        [string]$Path,

        # As outras pastas pessoais: a própria Downloads fica de fora da lista, senão ela recusaria a si mesma.
        [string[]]$PersonalFolders = @(Get-WinForgePersonalFolders -ExcludeDownloads)
    )

    if (-not (Test-WinForgeCleanupTargetSafe -Path $Path)) {
        return $false
    }

    foreach ($folder in @($PersonalFolders)) {
        if ((Get-WinForgePathRelation -Path $Path -Other $folder) -in @("Same", "Contains")) {
            return $false
        }
    }

    return $true
}


function Get-WinForgeMinAgeText {
    # "um dia", "2 dias", "6 horas": a idade mínima como a tela diz antes da limpeza ("os de menos de um dia ficam").
    param ([Parameter(Mandatory)][int]$Hours)

    if ($Hours -eq 24) { return (Get-WinForgeText 'um dia') }
    if ($Hours -gt 0 -and $Hours % 24 -eq 0) { return (Format-WinForgeCount -Count ($Hours / 24) -One (Get-WinForgeText 'dia') -Many (Get-WinForgeText 'dias')) }

    return (Format-WinForgeCount -Count $Hours -One (Get-WinForgeText 'hora') -Many (Get-WinForgeText 'horas'))
}


function Invoke-WinForgeFolderCleanup {
    <#
    Uma parte de outra limpeza (a Limpeza rápida e o Acelerar agora): esvazia uma pasta de temporários, sem pergunta (a
    pergunta é a de quem chama), e devolve o WinForge.Result com Data.FreedBytes. Warning quer dizer uma coisa só: havia o
    que limpar, mas nada saiu, porque estava tudo em uso (o Acelerar agora diz isso, e não "nenhum temporário").
    #>
    param (
        [Parameter(Mandatory)]
        [string]$Title,

        # Vazio quando a variável de ambiente que localiza a pasta não existe: a ação explica em vez de falhar.
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Path,

        # Itens mais novos que isto (em horas) ficam; 0 = limpa tudo.
        [int]$MinAgeHours = 0
    )

    Enter-WinForgeAction -Title $Title -Embedded

    $result = $null

    try {
        if ([string]::IsNullOrWhiteSpace($Path)) {
            Write-WinForgeStatus -Type Error -Message (Get-WinForgeText 'Não foi possível localizar a pasta a limpar (variável de ambiente ausente).')
            $result = New-WinForgeResult -Kind Failed -Detail (Get-WinForgeText 'pasta não localizada')
        }
        elseif (-not (Test-WinForgeTempFolderSafe -Path $Path -RequireTempName)) {
            # Uma pasta de temporários precisa se chamar Temp e não pode ser uma raiz de disco, conter o perfil, o Windows ou
            # os dados dos programas (AppData), nem ficar numa pasta pessoal ou na pasta do WinForge.
            Write-WinForgeStatus -Type Error -Message (Get-WinForgeText 'Pasta recusada por segurança: {0}' "$Path")
            Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Ela não parece uma pasta de temporários: verifique a variável de ambiente TEMP.')
            $result = New-WinForgeResult -Kind Failed -Detail (Get-WinForgeText 'pasta recusada por segurança')
        }
        elseif (-not (Test-Path -LiteralPath $Path -PathType Container)) {
            Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'Pasta não encontrada: {0}' "$Path")
            $result = New-WinForgeResult -Kind Skipped -Detail (Get-WinForgeText 'pasta não encontrada') -Data @{ FreedBytes = [int64]0 }
        }
        else {
            $listing = Get-WinForgeFolderListing -Path $Path

            if (-not $listing.Readable) {
                # Sem conseguir listar, "vazia" seria um palpite: a pasta pode estar cheia e só não ser permitida.
                Write-WinForgeStatus -Type Error -Message (Get-WinForgeText 'Não foi possível ler a pasta: {0}' "$($listing.Reason)")
                Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Se a pasta for do sistema, feche o WinForge, abra de novo e aceite o aviso do Windows.')
                $result = New-WinForgeResult -Kind Failed -Detail (Get-WinForgeText 'pasta ilegível')
            }
            else {
                Write-Progress -Activity $Title -Status (Get-WinForgeText 'medindo a pasta')
                $all = @(Measure-WinForgeFolderItems -Items $listing.Items)
                Write-Progress -Activity $Title -Completed

                # Só o que passou do tempo mínimo entra na conta: o resto fica, e a tela diz quanto.
                $entries = $(if ($MinAgeHours -gt 0) { @(Select-WinForgeItemsOlderThan -Entries $all -Cutoff (Get-Date).AddHours(-$MinAgeHours)) } else { $all })
                $recent = $all.Count - @($entries).Count

                $totalBytes = [int64]0
                foreach ($entry in @($entries)) { $totalBytes += [int64]$entry.SizeBytes }

                Write-WinForgeKeyValue -Label (Get-WinForgeText 'Pasta') -Value $Path
                Write-WinForgeKeyValue -Label (Get-WinForgeText 'Itens a limpar') -Value (Format-WinForgeNumber -Value @($entries).Count)
                Write-WinForgeKeyValue -Label (Get-WinForgeText 'Tamanho estimado') -Value (Format-WinForgeBytes -Bytes $totalBytes)
                if ($recent -gt 0) { Write-WinForgeKeyValue -Label (Get-WinForgeText 'Ficam (recentes)') -Value (Get-WinForgeText '{0} de menos de {1}' "$(Format-WinForgeCount -Count $recent -One (Get-WinForgeText 'item') -Many (Get-WinForgeText 'itens'))" "$(Get-WinForgeMinAgeText -Hours $MinAgeHours)") }
                Write-Host ""

                if (@($entries).Count -eq 0) {
                    # O que é recente pode ser de um programa ou de uma instalação em andamento: fica.
                    Write-WinForgeStatus -Type Success -Message $(if ($recent -gt 0) { (Get-WinForgeText 'Não há nada para limpar: o que está na pasta é recente.') } else { (Get-WinForgeText 'Não há nada para limpar nesta pasta.') })
                    $result = New-WinForgeResult -Kind Ok -Detail (Get-WinForgeText 'nada a limpar') -Data @{ FreedBytes = [int64]0 }
                }
                else {
                    # O andamento vai na barra de progresso (Clear-WinForgeFolderContents); uma linha "Limpando..."
                    # ficaria no resumo como se a limpeza ainda estivesse em curso. Os recentes, que ficam, já foram
                    # contados acima ("Ficam (recentes)").
                    $outcome = Clear-WinForgeFolderContents -Path $Path -Activity $Title -Entries @($entries)

                    # Itens em uso são esperados; mas se NADA saiu, a limpeza não aconteceu e "concluída" seria mentira.
                    $nothingRemoved = ($outcome.Removed -eq 0 -and $outcome.Skipped -gt 0)

                    if ($nothingRemoved) {
                        Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'Nenhum item pôde ser removido.')
                    }
                    else {
                        Write-WinForgeStatus -Type Success -Message (Get-WinForgeText 'Limpeza concluída.')
                    }

                    Write-WinForgeKeyValue -Label (Get-WinForgeText 'Itens removidos') -Value (Format-WinForgeNumber -Value $outcome.Removed)
                    if ($outcome.Skipped -gt 0) { Write-WinForgeKeyValue -Label (Get-WinForgeText 'Em uso (ficaram)') -Value (Format-WinForgeNumber -Value $outcome.Skipped) }
                    Write-WinForgeKeyValue -Label (Get-WinForgeText 'Espaço liberado') -Value (Format-WinForgeBytes -Bytes $outcome.Freed)

                    if ($nothingRemoved) {
                        Write-Host ""
                        Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Os itens estavam em uso: feche os programas e tente de novo.')
                    }
                    elseif ($outcome.Skipped -gt 0) {
                        Write-Host ""
                        Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Os itens em uso ficaram; isso é esperado.')
                    }

                    $detail = (Get-WinForgeText 'liberou {0}' "$(Format-WinForgeBytes -Bytes $outcome.Freed)")
                    if ($outcome.Skipped -gt 0) { $detail += (Get-WinForgeText '; {0} em uso' "$($outcome.Skipped)") }

                    $kind = $(if ($nothingRemoved) { "Warning" } else { "Ok" })
                    if ($nothingRemoved) { $detail = (Get-WinForgeText 'nenhum item removido; {0} em uso' "$($outcome.Skipped)") }

                    $result = New-WinForgeResult -Kind $kind -Detail $detail -Data @{ FreedBytes = [int64]$outcome.Freed }
                }
            }
        }
    }
    catch {
        Write-WinForgeStatus -Type Error -Message (Get-WinForgeText 'Ocorreu um erro na limpeza: {0}' "$($_.Exception.Message)")
        $result = New-WinForgeResult -Kind Failed -Detail $_.Exception.Message
    }

    $result.Etapa = $Title
    Exit-WinForgeAction -Embedded -Result $result

    return $result
}


function Get-WinForgeUserTempPath {
    # A pasta Temp do usuário, ou "" quando nem TEMP nem LOCALAPPDATA existem.
    if (-not [string]::IsNullOrWhiteSpace($env:TEMP)) {
        return $env:TEMP
    }

    if ([string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
        return ""
    }

    return (Join-Path $env:LOCALAPPDATA "Temp")
}


function Get-WinForgeWindowsTempPath {
    # A pasta Temp do Windows, ou "" quando nem WINDIR nem SystemRoot existem.
    $windows = $(if (-not [string]::IsNullOrWhiteSpace($env:WINDIR)) { $env:WINDIR } else { $env:SystemRoot })

    if ([string]::IsNullOrWhiteSpace($windows)) {
        return ""
    }

    return (Join-Path $windows "Temp")
}


function Clear-WinForgeUserTemp {
    # Os temporários do usuário, como parte da Limpeza rápida e do Acelerar agora; devolve o WinForge.Result.
    return (Invoke-WinForgeFolderCleanup -Title (Get-WinForgeText 'Limpar temporários do usuário') -Path (Get-WinForgeUserTempPath) -MinAgeHours $script:WinForgeTempMinAgeHours)
}


function Clear-WinForgeWindowsTemp {
    # Os temporários do Windows, como parte da Limpeza rápida; devolve o WinForge.Result.
    return (Invoke-WinForgeFolderCleanup -Title (Get-WinForgeText 'Limpar temporários do Windows') -Path (Get-WinForgeWindowsTempPath) -MinAgeHours $script:WinForgeTempMinAgeHours)
}


# ---------------------------------------------------------------------------
# Lixeira
# ---------------------------------------------------------------------------

function Set-WinForgeRecycleBinNext {
    <#
    A faixa de uma ferramenta que mandou itens para a Lixeira (Downloads, duplicados, restos de programas): o título diz
    quantos foram, a frase diz que o espaço só volta ao esvaziá-la, e o botão Esvaziar a Lixeira leva direto à tela que
    faz isso (antes, só o texto apontava o caminho). Numa ressalva (alguns itens ficaram), o título e a frase continuam os
    da ressalva, que dizem o que ficou, e só o botão entra: o que foi para a Lixeira também espera ser esvaziado. Devolve
    o próprio resultado.
    #>
    param (
        [Parameter(Mandatory)]
        $Result,

        [int]$Count,
        [int64]$Bytes = 0,
        [string]$One = (Get-WinForgeText 'item'),
        [string]$Many = (Get-WinForgeText 'itens')
    )

    if ([string]$Result.Kind -notin @("Ok", "Warning") -or $Count -le 0) { return $Result }

    if ([string]$Result.Kind -eq "Warning") {
        return (Set-WinForgeResultView -Result $Result -Next "cleanup.recycle-bin" -NextLabel (Get-WinForgeText 'Esvaziar a Lixeira'))
    }

    $note = $(if ($Bytes -gt 0) { (Get-WinForgeText '{0} voltam ao disco ao esvaziar a Lixeira.' "$(Format-WinForgeBytes -Bytes $Bytes)") } else { (Get-WinForgeText 'O espaço volta ao disco ao esvaziar a Lixeira.') })

    return (Set-WinForgeResultView -Result $Result -Headline (Get-WinForgeText '{0} na Lixeira' "$(Format-WinForgeCount -Count $Count -One $One -Many $Many)") -Note $note -Next "cleanup.recycle-bin" -NextLabel (Get-WinForgeText 'Esvaziar a Lixeira'))
}


function Get-WinForgeCleanupZeroNote {
    <#
    A frase da faixa de uma limpeza que terminou sem espaço liberado: o que saiu estava vazio (pastas e arquivos de 0
    bytes) ou, com uma parte que não pôde ser medida (Unmeasured, os nomes dela), o espaço não pôde ser medido.
    #>
    param ([AllowEmptyCollection()][string[]]$Unmeasured = @())

    if (@($Unmeasured).Count -gt 0) { return (Get-WinForgeText 'O espaço liberado não pôde ser medido.') }

    return (Get-WinForgeText 'O que saiu estava vazio: o espaço livre não mudou.')
}


function Get-WinForgeRecycleBinFolders {
    <#
    As pastas da Lixeira do usuário: cada unidade guarda a sua em "<unidade>\$Recycle.Bin\<SID do usuário>". Só as que
    existem (o Windows cria a pasta na primeira exclusão). $null quando não dá para saber o usuário.
    #>
    try {
        $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    }
    catch {
        return $null
    }

    $folders = @(
        foreach ($drive in [IO.DriveInfo]::GetDrives()) {
            try {
                if ($drive.DriveType -in @([IO.DriveType]::Fixed, [IO.DriveType]::Removable) -and $drive.IsReady) {
                    $candidate = Join-Path (Join-Path $drive.RootDirectory.FullName '$Recycle.Bin') $sid
                    if (Test-Path -LiteralPath $candidate -PathType Container) { $candidate }
                }
            }
            catch {
                # Unidade que some ou não responde (leitor de cartão vazio): fica de fora.
            }
        }
    )

    return , $folders
}


function Get-WinForgeRecycleBinContents {
    <#
    O que está na Lixeira do usuário, em todas as unidades: Count (itens) e SizeBytes. Cada item apagado é um "$R..."
    (o arquivo, ou a pasta inteira) acompanhado de um "$I..." de dados, que não conta. Medir pelo disco não depende do
    Shell do Windows, que não responde em algumas sessões. $null quando não dá para ler a Lixeira.
    #>
    param (
        [string[]]$Folders
    )

    if (-not $PSBoundParameters.ContainsKey("Folders")) {
        $found = Get-WinForgeRecycleBinFolders

        if ($null -eq $found) {
            return $null
        }

        $Folders = @($found)
    }

    $count = 0
    $size = [int64]0
    $read = 0

    foreach ($folder in @($Folders)) {
        $listing = Get-WinForgeFolderListing -Path $folder

        if (-not $listing.Readable) {
            continue
        }

        $read++
        $items = @($listing.Items | Where-Object { $_.Name -like '$R*' })
        $count += $items.Count

        foreach ($entry in @(Measure-WinForgeFolderItems -Items $items)) {
            $size += [int64]$entry.SizeBytes
        }
    }

    # Pastas que existem e nenhuma abriu: não dá para dizer que a Lixeira está vazia.
    if (@($Folders).Count -gt 0 -and $read -eq 0) {
        return $null
    }

    return [PSCustomObject]@{ Count = $count; SizeBytes = $size }
}


function Format-WinForgeRecycleBinText {
    # "3 itens, 50 MB" ou "vazia".
    param (
        [Parameter(Mandatory)]
        $Contents
    )

    if ([int]$Contents.Count -eq 0) {
        return (Get-WinForgeText 'vazia')
    }

    return "$(Format-WinForgeCount -Count ([int]$Contents.Count) -One (Get-WinForgeText 'item') -Many (Get-WinForgeText 'itens')), $(Format-WinForgeBytes -Bytes $Contents.SizeBytes)"
}


function Test-WinForgeRecycleBinEmptyError {
    # O Windows responde de formas diferentes a esvaziar uma Lixeira que já está vazia. O código do erro (arquivo ou
    # caminho não encontrado: 0x80070002 e 0x80070003) vale em qualquer idioma; o texto cobre inglês e português.
    param (
        [string]$Message,

        [int]$HResult = 0
    )

    if ($HResult -in @(-2147024894, -2147024893)) {
        return $true
    }

    return (
        $Message -match "cannot find the file specified" -or
        $Message -match "cannot find the path specified" -or
        $Message -match "não pode encontrar o arquivo especificado" -or
        $Message -match "não foi possível localizar (o arquivo|o caminho) especificado" -or
        $Message -match "O sistema não pode encontrar" -or
        $Message -match "El sistema no puede encontrar"
    )
}


function Clear-WinForgeRecycleBin {
    param (
        [switch]$Embedded,
        [switch]$PassThru,

        # O que quem chama já mediu na Lixeira (Count e SizeBytes): evita percorrê-la de novo.
        $Contents = $null
    )

    $title = (Get-WinForgeText 'Esvaziar a Lixeira')

    Enter-WinForgeAction -Title $title -Embedded:$Embedded

    $result = $null

    try {
        if ($null -eq $Contents) {
            Write-Progress -Activity $title -Status (Get-WinForgeText 'medindo o que está na Lixeira')
            $Contents = Get-WinForgeRecycleBinContents
            Write-Progress -Activity $title -Completed
        }

        if ($null -ne $Contents -and [int]$Contents.Count -eq 0) {
            Write-WinForgeStatus -Type Success -Message (Get-WinForgeText 'A Lixeira já está vazia.')
            $result = New-WinForgeResult -Kind Ok -Detail (Get-WinForgeText 'já estava vazia') -Data @{ FreedBytes = [int64]0; AlreadyEmpty = $true }
        }
        else {
            if ($null -ne $Contents) {
                Write-WinForgeKeyValue -Label (Get-WinForgeText 'Na Lixeira') -Value (Format-WinForgeRecycleBinText -Contents $Contents)
            }
            else {
                Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Não foi possível medir a Lixeira; ela será esvaziada mesmo assim.')
            }

            if (-not $Embedded) {
                # Um aviso antes da pergunta, que na janela fica no resumo, acima dos botões. Não é ressalva do resultado.
                Write-WinForgeStatus -Type Warning -Notice -Message (Get-WinForgeText 'Esvazia a Lixeira de todas as unidades: os itens são removidos em definitivo.')
                Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Para salvar algo antes, abra a Lixeira e use Restaurar.')
                [void](Write-WinForgeOtherAccountNotice -What 'a Lixeira')
                Write-Host ""
            }

            if (-not $Embedded -and -not (Confirm-WinForgeAction (Get-WinForgeText 'Deseja esvaziar a Lixeira?') -DefaultKey N -Danger -YesLabel (Get-WinForgeText 'Esvaziar') -NoLabel (Get-WinForgeText 'Cancelar'))) {
                Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'Operação cancelada.')
                $result = New-WinForgeResult -Kind Skipped -Detail (Get-WinForgeText 'cancelado pelo usuário')
            }
            else {
                try {
                    Write-Progress -Activity $title -Status (Get-WinForgeText 'esvaziando')

                    try {
                        Clear-RecycleBin -Force -ErrorAction Stop
                    }
                    finally {
                        Write-Progress -Activity $title -Completed
                    }

                    Write-WinForgeStatus -Type Success -Message (Get-WinForgeText 'Lixeira esvaziada.')

                    # O espaço liberado é o que foi medido antes (o Windows esvazia a Lixeira inteira de uma vez).
                    if ($null -ne $Contents) {
                        Write-WinForgeKeyValue -Label (Get-WinForgeText 'Espaço liberado') -Value (Format-WinForgeBytes -Bytes $Contents.SizeBytes)
                        $result = New-WinForgeResult -Kind Ok -Detail (Get-WinForgeText 'liberou {0}' "$(Format-WinForgeBytes -Bytes $Contents.SizeBytes)") -Data @{ FreedBytes = [int64]$Contents.SizeBytes }
                    }
                    else {
                        $result = New-WinForgeResult -Kind Ok -Detail (Get-WinForgeText 'Lixeira esvaziada')
                    }
                }
                catch {
                    if (Test-WinForgeRecycleBinEmptyError -Message $_.Exception.Message -HResult $_.Exception.HResult) {
                        Write-WinForgeStatus -Type Success -Message (Get-WinForgeText 'A Lixeira já estava vazia.')
                        $result = New-WinForgeResult -Kind Ok -Detail (Get-WinForgeText 'já estava vazia') -Data @{ FreedBytes = [int64]0; AlreadyEmpty = $true }
                    }
                    else {
                        Write-WinForgeStatus -Type Error -Message (Get-WinForgeText 'Falha ao esvaziar a Lixeira: {0}' "$($_.Exception.Message)")
                        $result = New-WinForgeResult -Kind Failed -Detail $_.Exception.Message
                    }
                }
            }
        }
    }
    catch {
        Write-WinForgeStatus -Type Error -Message (Get-WinForgeText 'Ocorreu um erro ao esvaziar a Lixeira: {0}' "$($_.Exception.Message)")
        $result = New-WinForgeResult -Kind Failed -Detail $_.Exception.Message
    }

    # Sozinha, a faixa diz quanto voltou ao disco, como a Limpeza rápida ("6 MB liberados"); vazia, "Nada para limpar".
    # Com o que estava nela sem tamanho (arquivos de 0 bytes) ou sem medida, diz que foi esvaziada e por que o espaço não
    # aparece. Dentro de outra limpeza, quem chama faz a própria faixa.
    if (-not $Embedded -and [string]$result.Kind -eq "Ok") {
        $binFreed = Get-WinForgeResultData -Result $result -Name "FreedBytes"

        if ([bool](Get-WinForgeResultData -Result $result -Name "AlreadyEmpty")) {
            [void](Set-WinForgeResultView -Result $result -Headline (Get-WinForgeText 'Nada para limpar') -Note (Get-WinForgeText 'A Lixeira já está vazia.'))
        }
        elseif ($null -ne $binFreed -and [int64]$binFreed -gt 0) {
            [void](Set-WinForgeResultView -Result $result -Headline (Get-WinForgeText '{0} liberados' "$(Format-WinForgeBytes -Bytes ([int64]$binFreed))") -Note (Get-WinForgeText 'Lixeira esvaziada.'))
        }
        elseif ($null -eq $binFreed) {
            [void](Set-WinForgeResultView -Result $result -Headline (ConvertTo-WinForgeHeadline -Text (Get-WinForgeText 'Lixeira esvaziada')) -Note (Get-WinForgeText 'O espaço liberado não pôde ser medido.'))
        }
        else {
            [void](Set-WinForgeResultView -Result $result -Headline (ConvertTo-WinForgeHeadline -Text (Get-WinForgeText 'Lixeira esvaziada')) -Note (Get-WinForgeCleanupZeroNote))
        }
    }

    $result.Etapa = $title
    Exit-WinForgeAction -Embedded:$Embedded -Result $result

    if ($PassThru) {
        return $result
    }
}


# ---------------------------------------------------------------------------
# Limpeza rápida (temporários + Lixeira)
# ---------------------------------------------------------------------------

function Measure-WinForgeTempCleanup {
    <#
    Quanto a Limpeza rápida tiraria dos temporários do usuário e do Windows, para dizer antes da pergunta: Bytes e Count do
    que passou do tempo mínimo (o que é recente fica), e Unknown quando uma pasta não pôde ser lida (a soma vira só o que
    foi medido). As regras da limpeza: uma pasta que não parece de temporários ou que não existe não entra (a etapa dela diz
    por quê), e a mesma pasta nas duas variáveis conta uma vez.
    #>
    $bytes = [int64]0
    $count = 0
    $unknown = $false
    $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    $cutoff = (Get-Date).AddHours(-$script:WinForgeTempMinAgeHours)

    foreach ($path in @((Get-WinForgeUserTempPath), (Get-WinForgeWindowsTempPath))) {
        if ([string]::IsNullOrWhiteSpace($path) -or -not $seen.Add(([string]$path).TrimEnd('\', '/'))) { continue }
        if (-not (Test-WinForgeTempFolderSafe -Path $path -RequireTempName)) { continue }
        if (-not (Test-Path -LiteralPath $path -PathType Container)) { continue }

        $listing = Get-WinForgeFolderListing -Path $path

        if (-not $listing.Readable) {
            $unknown = $true
            continue
        }

        foreach ($entry in @(Select-WinForgeItemsOlderThan -Entries @(Measure-WinForgeFolderItems -Items $listing.Items) -Cutoff $cutoff)) {
            $bytes += [int64]$entry.SizeBytes
            $count++
        }
    }

    return [PSCustomObject]@{ Bytes = $bytes; Count = $count; Unknown = $unknown }
}


function Invoke-WinForgeQuickCleanup {
    param (
        [switch]$Embedded,
        [switch]$PassThru,

        # Deixa a Lixeira como está (no Otimizar, quando a pessoa não confirmou esvaziá-la).
        [switch]$SkipRecycleBin
    )

    $title = (Get-WinForgeText 'Limpeza rápida')

    Enter-WinForgeAction -Title $title -Embedded:$Embedded

    $result = $null

    try {
        $proceed = $true
        $binContents = $null
        $nothing = $false

        if (-not $Embedded) {
            # O que vai acontecer, antes da pergunta: na janela, isto é o que aparece acima dos botões. Os temporários de
            # menos de um dia e os arquivos em uso ficam.
            Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Limpa os temporários do usuário e do Windows; seus arquivos pessoais não são tocados.')
            [void](Write-WinForgeOtherAccountNotice -What $(if ($SkipRecycleBin) { 'os temporários do usuário' } else { 'os temporários do usuário e a Lixeira' }))

            # O que sai, medido antes da pergunta: a pessoa confirma sabendo quanto, e sem nada para tirar nem há pergunta.
            Write-Progress -Activity $title -Status (Get-WinForgeText 'medindo os temporários')
            $tempEstimate = Measure-WinForgeTempCleanup

            if (-not $SkipRecycleBin) {
                Write-Progress -Activity $title -Status (Get-WinForgeText 'medindo o que está na Lixeira')
                $binContents = Get-WinForgeRecycleBinContents
            }

            Write-Progress -Activity $title -Completed

            $tempText = $(
                if ($tempEstimate.Count -gt 0) { "$(Format-WinForgeBytes -Bytes $tempEstimate.Bytes -ZeroText '0 B') · $(Format-WinForgeCount -Count $tempEstimate.Count -One (Get-WinForgeText 'item') -Many (Get-WinForgeText 'itens'))$(if ($tempEstimate.Unknown) { (Get-WinForgeText ' (uma pasta não pôde ser medida)') })" }
                elseif ($tempEstimate.Unknown) { (Get-WinForgeText 'não foi possível medir') }
                else { (Get-WinForgeText 'nada para limpar') }
            )
            Write-WinForgeKeyValue -Label (Get-WinForgeText 'Temporários') -Value $tempText

            $binEmpty = ($null -ne $binContents -and [int]$binContents.Count -eq 0)
            if (-not $SkipRecycleBin) {
                Write-WinForgeKeyValue -Label (Get-WinForgeText 'Na Lixeira') -Value $(if ($null -eq $binContents) { (Get-WinForgeText 'não foi possível medir') } elseif ($binEmpty) { (Get-WinForgeText 'vazia') } else { Format-WinForgeRecycleBinText -Contents $binContents })
            }

            $nothing = ($tempEstimate.Count -eq 0 -and -not $tempEstimate.Unknown -and ($SkipRecycleBin -or $binEmpty))

            if ($nothing) {
                # Nada a tirar: sem pergunta, e sem um "Tudo certo: liberou 0 B" depois de um Sim.
                Write-Host ""
                Write-WinForgeStatus -Type Success -Message (Get-WinForgeText 'Não há nada para limpar: os temporários estão vazios ou são recentes{0}.' "$(if (-not $SkipRecycleBin) { (Get-WinForgeText ', e a Lixeira está vazia') })")
                $proceed = $false
            }
            elseif ($SkipRecycleBin -or $binEmpty) {
                Write-Host ""
                $proceed = Confirm-WinForgeAction (Get-WinForgeText 'Limpar os temporários agora?') -DefaultKey S -YesLabel (Get-WinForgeText 'Limpar') -NoLabel (Get-WinForgeText 'Cancelar')
            }
            else {
                # O que está na Lixeira antes de esvaziá-la: é o único passo que não tem volta, e a pessoa escolhe. O padrão
                # (ENTER e o botão em destaque) é o que tem volta: só os temporários.
                Write-Host ""

                $choice = Read-WinForgeChoice -Message (Get-WinForgeText 'O que deseja limpar?') -DefaultKey "S" -ShowMenu -TextPrompt (Get-WinForgeText 'Opção (ENTER = só os temporários)') -Options @(
                    @{ Key = "S"; Label = (Get-WinForgeText 'Só os temporários'); Description = (Get-WinForgeText 'a Lixeira fica como está'); Accent = $true },
                    @{ Key = "T"; Label = (Get-WinForgeText 'Temporários e Lixeira'); Description = (Get-WinForgeText 'o que está na Lixeira é apagado em definitivo, sem volta'); Danger = $true },
                    @{ Key = "X"; Label = (Get-WinForgeText 'Cancelar'); Exit = $true }
                )

                $proceed = ($choice -in @("T", "S"))
                if ($choice -eq "S") { $SkipRecycleBin = $true }
            }
        }

        if ($nothing) {
            $result = New-WinForgeResult -Kind Skipped -Detail (Get-WinForgeText 'nada para limpar') -Data @{ FreedBytes = [int64]0 }
            [void](Set-WinForgeResultView -Result $result -Headline (Get-WinForgeText 'Nada para limpar') -Note (Get-WinForgeText 'Os temporários estão vazios ou são recentes{0}.' "$(if (-not $SkipRecycleBin) { (Get-WinForgeText ', e a Lixeira está vazia') })"))
        }
        elseif (-not $proceed) {
            Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'Operação cancelada.')
            $result = New-WinForgeResult -Kind Skipped -Detail (Get-WinForgeText 'cancelado pelo usuário')
        }
        else {
            # Cada parte com o nome que a frase do total usa.
            $steps = @(
                @{ Name = (Get-WinForgeText 'os temporários do usuário'); Result = (Clear-WinForgeUserTemp) },
                @{ Name = (Get-WinForgeText 'os temporários do Windows'); Result = (Clear-WinForgeWindowsTemp) }
            )

            # Sem a Lixeira (a escolha da pessoa), nada é dito: ela ficou como estava. Medida vazia, também não entra: a
            # pergunta foi só dos temporários, e uma seção "Esvaziar a Lixeira" no resumo pareceria algo que não foi pedido.
            if (-not $SkipRecycleBin -and -not ($null -ne $binContents -and [int]$binContents.Count -eq 0)) {
                $steps += @{ Name = (Get-WinForgeText 'a Lixeira'); Result = (Clear-WinForgeRecycleBin -Embedded -PassThru -Contents $binContents) }
            }
            $parts = @($steps | ForEach-Object { $_.Result })

            $failed = @($parts | Where-Object { $_.Kind -eq "Failed" })
            $warned = @($parts | Where-Object { $_.Kind -eq "Warning" })

            # Cada parte conta o que liberou; a soma dá o balanço da limpeza inteira, com a Lixeira (medida antes de ser
            # esvaziada). Uma parte que não soube medir fica de fora, e a tela diz isso.
            $freed = [int64]0
            $unmeasured = @()

            foreach ($step in $steps) {
                $partFreed = Get-WinForgeResultData -Result $step.Result -Name "FreedBytes"

                if ($null -ne $partFreed) { $freed += [int64]$partFreed }
                elseif ($step.Result.Kind -ne "Failed") { $unmeasured += $step.Name }
            }

            $freedText = Format-WinForgeBytes -Bytes $freed

            Write-WinForgeSection -Title (Get-WinForgeText 'Resumo')
            Write-WinForgeKeyValue -Label (Get-WinForgeText 'Espaço liberado') -Value $freedText

            if ($unmeasured.Count -gt 0) {
                Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'O total não inclui {0}: não foi possível medir antes de limpar.' "$(Join-WinForgeList -Items $unmeasured)")
            }

            $data = @{ FreedBytes = $freed }

            if ($failed.Count -eq 0 -and $warned.Count -eq 0) {
                $result = New-WinForgeResult -Kind Ok -Detail (Get-WinForgeText 'liberou {0}' "$freedText") -Data $data

                # Na janela, a faixa diz quanto e de onde, e o resumo (as mesmas contas, parte por parte) fica nos detalhes.
                if (-not $Embedded -and $freed -gt 0) {
                    # A Lixeira entra na frase só quando havia algo nela (vazia, o passo dela não tirou nada).
                    $binCleaned = (-not $SkipRecycleBin -and -not ($null -ne $binContents -and [int]$binContents.Count -eq 0))
                    $what = $(if ($binCleaned) { (Get-WinForgeText 'Temporários do usuário e do Windows, e a Lixeira.') } else { (Get-WinForgeText 'Temporários do usuário e do Windows.') })
                    if ($unmeasured.Count -gt 0) { $what += (Get-WinForgeText ' O total não inclui {0}.' "$(Join-WinForgeList -Items $unmeasured)") }
                    [void](Set-WinForgeResultView -Result $result -Headline (Get-WinForgeText '{0} liberados' "$freedText") -Note $what -HideSummary:($unmeasured.Count -eq 0))
                }
                elseif (-not $Embedded) {
                    # Nada liberado com a limpeza feita: o que saiu eram pastas e arquivos vazios (ou o que saiu não pôde ser
                    # medido). Antes, a faixa dizia "Tudo certo" e "Liberou 0 B".
                    [void](Set-WinForgeResultView -Result $result -Headline (Get-WinForgeText 'Limpeza concluída') -Note (Get-WinForgeCleanupZeroNote -Unmeasured $unmeasured))
                }
            }
            elseif ($failed.Count -lt $parts.Count) {
                # Uma parte fica com ressalva quando nada saiu dela porque estava tudo em uso; falha quando não pôde ser
                # limpa (pasta ilegível, recusada). O detalhe diz quais, e não "1 de 3 partes falhou".
                $warnedNames = @($steps | Where-Object { $_.Result.Kind -eq "Warning" } | ForEach-Object { [string]$_.Name })
                $failedNames = @($steps | Where-Object { $_.Result.Kind -eq "Failed" } | ForEach-Object { [string]$_.Name })

                $detail = $(if ($failedNames.Count -eq 0) { (Get-WinForgeText '{0} com itens em uso; liberou {1}' "$(Join-WinForgeList -Items $warnedNames)" "$freedText") } else { (Get-WinForgeText 'liberou {0}; com problema: {1}' "$freedText" "$(Join-WinForgeList -Items @($failedNames + $warnedNames))") })
                $result = New-WinForgeResult -Kind Warning -Detail $detail -Data $data

                # Na janela, a faixa diz quanto saiu e o que ficou para trás (antes, "Concluído com ressalvas" e a conta das partes).
                if (-not $Embedded) {
                    $notes = @()
                    if ($failedNames.Count -gt 0) { $notes += (Get-WinForgeText 'Não foi possível limpar {0}.' "$(Join-WinForgeList -Items $failedNames)") }
                    if ($warnedNames.Count -gt 0) { $notes += (Get-WinForgeText 'Itens em uso ficaram: feche os programas e tente de novo.') }

                    [void](Set-WinForgeResultView -Result $result -Headline $(if ($freed -gt 0) { (Get-WinForgeText '{0} liberados' "$freedText") } else { (Get-WinForgeText 'Nada foi liberado') }) -Note ($notes -join " "))
                }
            }
            else {
                $result = New-WinForgeResult -Kind Failed -Detail (Get-WinForgeText 'todas as partes falharam') -Data $data
            }
        }
    }
    catch {
        Write-WinForgeStatus -Type Error -Message (Get-WinForgeText 'Ocorreu um erro na limpeza: {0}' "$($_.Exception.Message)")
        $result = New-WinForgeResult -Kind Failed -Detail $_.Exception.Message
    }

    $result.Etapa = $title
    Exit-WinForgeAction -Embedded:$Embedded -Result $result

    if ($PassThru) {
        return $result
    }
}


# ---------------------------------------------------------------------------
# Downloads
# ---------------------------------------------------------------------------

function Get-WinForgeKnownFolderPath {
    # Onde fica uma pasta pessoal do Windows pelo nome do .NET (MyDocuments, MyPictures...), mesmo levada para outro
    # disco ou para o OneDrive. "" quando o Windows não diz.
    param ([Parameter(Mandatory)][string]$Name)

    try { return [string][Environment]::GetFolderPath($Name) } catch { return "" }
}


function Get-WinForgeDownloadsPath {
    $registryPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders"
    $downloadsValueName = "{374DE290-123F-4565-9164-39C4925E467B}"

    $configuredPath = Get-WinForgeRegistryValueOrNull -Path $registryPath -Name $downloadsValueName

    if (-not [string]::IsNullOrWhiteSpace([string]$configuredPath)) {
        return [Environment]::ExpandEnvironmentVariables([string]$configuredPath)
    }

    # Usa o caminho padrão quando o perfil não possui um redirecionamento registrado.
    $profilePath = $env:USERPROFILE

    if ([string]::IsNullOrWhiteSpace($profilePath)) {
        $profilePath = [Environment]::GetFolderPath("UserProfile")
    }

    return (Join-Path $profilePath "Downloads")
}


function Test-WinForgeShellMetadata {
    param (
        [Parameter(Mandatory)]
        [System.IO.FileSystemInfo]$Item
    )

    # Metadados criados pelo shell não representam conteúdo pessoal do usuário.
    return (-not $Item.PSIsContainer -and $Item.Name -in @("desktop.ini", "Thumbs.db"))
}


function Select-WinForgeItemsOlderThan {
    # Entries: objetos com a propriedade LastActivity. Itens exatamente no limite ficam de fora (só "mais antigos que").
    param (
        [object[]]$Entries,
        [datetime]$Cutoff
    )

    # Uma lista nula (função que devolveu "nada") entraria no pipeline como UM item nulo, e $null -lt data é verdadeiro.
    return @($Entries | Where-Object { $null -ne $_ -and $_.LastActivity -lt $Cutoff })
}


function Read-WinForgeDaysThreshold {
    <#
    Há quantos dias (desde que foi baixado ou alterado pela última vez). Na interface gráfica oferece valores prontos;
    "Outro valor" (e o console) pedem o número digitado, de novo quando ele é inválido. Retorna $null depois de três
    valores inválidos.
    #>
    $question = (Get-WinForgeText 'Remover o que foi baixado ou alterado há mais de quantos dias?')

    if (Test-WinForgeGuiPrompts) {
        $key = Read-WinForgeChoice -Message $question -DefaultKey "30" -Options @(
            @{ Key = "7"; Label = (Get-WinForgeText '7 dias') },
            @{ Key = "15"; Label = (Get-WinForgeText '15 dias') },
            @{ Key = "30"; Label = (Get-WinForgeText '30 dias'); Description = (Get-WinForgeText 'recomendado'); Accent = $true },
            @{ Key = "60"; Label = (Get-WinForgeText '60 dias') },
            @{ Key = "90"; Label = (Get-WinForgeText '90 dias') },
            @{ Key = "180"; Label = (Get-WinForgeText '180 dias') },
            @{ Key = "365"; Label = (Get-WinForgeText '1 ano') },
            @{ Key = "other"; Label = (Get-WinForgeText 'Outro valor...') }
        )

        if ($key -ne "other") {
            return [int]$key
        }
    }

    # Um valor errado (uma letra, um zero) pede de novo, até três vezes, em vez de encerrar a ação.
    for ($attempt = 1; $attempt -le 3; $attempt++) {
        $prompt = $(if ($attempt -eq 1) { (Get-WinForgeText '{0} (ENTER = 30)' "$question") } else { (Get-WinForgeText 'Digite um número de dias, por exemplo 45 (ENTER = 30)') })
        $daysText = Read-WinForgeText -Message $prompt

        if ([string]::IsNullOrWhiteSpace($daysText)) {
            return 30
        }

        # [0-9] e não \d: \d aceita dígitos de outros alfabetos, que [int] não converte.
        $daysText = $daysText.Trim()

        if ($daysText -match "^[0-9]{1,5}$" -and [int]$daysText -ge 1) {
            return [int]$daysText
        }

        if ($attempt -lt 3) {
            Write-WinForgeStatus -Type Warning -Notice -Message (Get-WinForgeText 'Valor inválido: digite só o número de dias (1 ou mais), por exemplo 45.')
        }
    }

    return $null
}


function Show-WinForgeDownloadsPreview {
    <#
    Os maiores itens que serão limpos, um por linha "nome : tamanho · data": na janela, essas linhas aparecem no resumo,
    acima da pergunta do que fazer com eles (durante uma pergunta de escolha os detalhes técnicos ficam recolhidos).
    #>
    param (
        [Parameter(Mandatory)]
        [object[]]$Selected,

        [int]$Top = 15
    )

    Write-WinForgeSection -Title (Get-WinForgeText 'O que será limpo (maiores primeiro)')

    foreach ($entry in @($Selected | Sort-Object SizeBytes -Descending | Select-Object -First $Top)) {
        $nameText = [string]$entry.Name
        if ($entry.IsDirectory) { $nameText += [IO.Path]::DirectorySeparatorChar }

        if ($nameText.Length -gt 50) {
            $nameText = $nameText.Substring(0, 47) + "..."
        }

        Write-WinForgeKeyValue -Label $nameText -Value "$(Format-WinForgeBytes -Bytes $entry.SizeBytes -ZeroText '0 B') · $(Format-WinForgeDateTime -When $entry.LastActivity -Pattern 'dd/MM/yyyy')"
    }

    if ($Selected.Count -gt $Top) {
        Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'E mais {0}.' "$(Format-WinForgeCount -Count ($Selected.Count - $Top) -One (Get-WinForgeText 'item menor') -Many (Get-WinForgeText 'itens menores'))")
    }
}


function Test-WinForgeItemInUse {
    <#
    Verdadeiro quando outro programa está com o arquivo (ou algum arquivo dentro da pasta) aberto. Mandar um item assim
    para a Lixeira faz o Windows abrir a janela "Arquivo em uso", que pararia a limpeza esperando alguém responder; o
    item é deixado de lado antes disso. Um arquivo que não abre por falta de permissão também conta: não sairia.
    #>
    param (
        [Parameter(Mandatory)]
        [string]$Path,

        [switch]$IsDirectory
    )

    $files = New-Object "System.Collections.Generic.List[string]"

    # Um arquivo só na nuvem (OneDrive com arquivos sob demanda) não está aberto aqui; abri-lo para conferir faria o
    # Windows baixá-lo inteiro. Offline (0x1000) e RecallOnDataAccess (0x400000) marcam esses arquivos.
    $cloudOnly = 0x1000 -bor 0x400000

    if ($IsDirectory) {
        # Um atalho de pasta (junção ou link simbólico) sai como atalho, sem tocar no destino: o que está aberto lá não
        # o prende. Percorrer o destino seria trabalho à toa (pode ser um disco inteiro) e deixaria o atalho para trás.
        $root = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue

        if ($null -ne $root -and ($root.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            return $false
        }

        $pending = New-Object "System.Collections.Generic.Stack[string]"
        $pending.Push($Path)

        while ($pending.Count -gt 0) {
            try {
                foreach ($entry in (New-Object System.IO.DirectoryInfo -ArgumentList $pending.Pop()).EnumerateFileSystemInfos()) {
                    if ($entry -is [System.IO.DirectoryInfo]) {
                        if (($entry.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -eq 0) {
                            $pending.Push($entry.FullName)
                        }
                    }
                    elseif (([int]$entry.Attributes -band $cloudOnly) -eq 0) {
                        $files.Add($entry.FullName)
                    }
                }
            }
            catch {
                # Subpasta que não abre: a remoção dela vai falhar e ser contada, sem janela do Windows.
            }
        }
    }
    else {
        $single = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
        if ($null -eq $single -or ([int]$single.Attributes -band $cloudOnly) -eq 0) { $files.Add($Path) }
    }

    foreach ($file in $files) {
        try {
            [System.IO.File]::Open($file, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::None).Dispose()
        }
        catch {
            return $true
        }
    }

    return $false
}


function Get-WinForgeFreedFromPartial {
    # Quanto saiu de uma pasta que não pôde ser removida inteira: o tamanho medido antes menos o que ficou.
    param (
        [Parameter(Mandatory)]
        $Entry
    )

    if (-not $Entry.IsDirectory -or -not (Test-Path -LiteralPath $Entry.Path)) {
        return [int64]0
    }

    $left = [int64](Get-WinForgePathStats -Path $Entry.Path).Size

    return [Math]::Max([int64]0, [int64]$Entry.SizeBytes - $left)
}


function Clear-WinForgeDownloads {
    $title = (Get-WinForgeText 'Limpar a pasta Downloads')

    Enter-WinForgeAction -Title $title

    # Uma saída só, no fim: cada caminho deixa aqui o resultado que a faixa mostra.
    $result = $null

    try {
        $downloadsPath = Get-WinForgeDownloadsPath
        $listing = $null

        if (-not (Test-Path -LiteralPath $downloadsPath -PathType Container)) {
            Write-WinForgeStatus -Type Error -Message (Get-WinForgeText 'Pasta Downloads não encontrada: {0}' "$downloadsPath")
            $result = New-WinForgeResult -Kind Failed -Detail (Get-WinForgeText 'pasta Downloads não encontrada')
        }
        # A pasta Downloads pode ser redirecionada pelo Windows para qualquer lugar. Se apontar para a raiz de um disco, para
        # o perfil ou para outra pasta pessoal (Documentos, a raiz do OneDrive), "Tudo" apagaria muito mais que downloads.
        elseif (-not (Test-WinForgeDownloadsFolderSafe -Path $downloadsPath)) {
            Write-WinForgeStatus -Type Error -Message (Get-WinForgeText 'Pasta recusada por segurança: {0}' "$downloadsPath")
            Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Ela é uma raiz de disco, contém o seu perfil ou outra pasta pessoal. Confira onde a pasta Downloads está definida.')
            $result = New-WinForgeResult -Kind Failed -Detail (Get-WinForgeText 'pasta recusada por segurança')
        }
        else {
            $listing = Get-WinForgeFolderListing -Path $downloadsPath -ExcludeShellMetadata

            if (-not $listing.Readable) {
                # Sem conseguir listar, "já está vazia" seria um palpite.
                Write-WinForgeStatus -Type Error -Message (Get-WinForgeText 'Não foi possível ler a pasta Downloads: {0}' "$($listing.Reason)")
                $result = New-WinForgeResult -Kind Failed -Detail (Get-WinForgeText 'pasta ilegível')
            }
        }

        if ($null -eq $result) {
            # O aviso das outras telas da Limpeza (antes, "Elevado com outra conta ... do usuário logado").
            [void](Write-WinForgeOtherAccountNotice -What 'a pasta Downloads')

            $allItems = @($listing.Items)

            Write-WinForgeKeyValue -Label (Get-WinForgeText 'Pasta') -Value $downloadsPath
            Write-WinForgeKeyValue -Label (Get-WinForgeText 'Itens na pasta') -Value (Format-WinForgeNumber -Value $allItems.Count)
            Write-Host ""

            if ($allItems.Count -eq 0) {
                Write-WinForgeStatus -Type Success -Message (Get-WinForgeText 'A pasta Downloads já está vazia.')
                $result = New-WinForgeResult -Kind Ok -Detail (Get-WinForgeText 'a pasta já estava vazia')
                [void](Set-WinForgeResultView -Result $result -Headline (Get-WinForgeText 'Nada para limpar') -Note (Get-WinForgeText 'A pasta Downloads já está vazia.'))
            }
        }

        $selected = @()
        $days = $null

        if ($null -eq $result) {
            $mode = Read-WinForgeChoice -Message (Get-WinForgeText 'O que deseja limpar?') -ShowMenu -Options @(
                @{ Key = "1"; Label = (Get-WinForgeText 'O que é mais antigo'); Description = (Get-WinForgeText 'recomendado: você escolhe há quantos dias'); Accent = $true },
                @{ Key = "2"; Label = (Get-WinForgeText 'Tudo'); Description = (Get-WinForgeText '{0}, de qualquer data' "$(if ($allItems.Count -eq 1) { (Get-WinForgeText 'o único item da pasta') } else { (Get-WinForgeText 'todos os {0} itens da pasta' "$($allItems.Count)") })") },
                @{ Key = "0"; Label = (Get-WinForgeText 'Cancelar'); Exit = $true }
            )

            if ($mode -ne "1" -and $mode -ne "2") {
                Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'Limpeza cancelada.')
                $result = New-WinForgeResult -Kind Skipped -Detail (Get-WinForgeText 'cancelado pelo usuário')
            }
            elseif ($mode -eq "1") {
                $days = Read-WinForgeDaysThreshold

                if ($null -eq $days) {
                    Write-WinForgeStatus -Type Error -Message (Get-WinForgeText 'Valor inválido: informe um número inteiro de dias (1 ou mais). Nada foi apagado.')
                    $result = New-WinForgeResult -Kind Failed -Detail (Get-WinForgeText 'número de dias inválido')
                }
            }
        }

        if ($null -eq $result) {
            # Medir e datar pode levar um tempo numa pasta grande; o andamento vai na barra, não numa linha do resumo.
            Write-Progress -Activity (Get-WinForgeText 'Analisando a pasta Downloads') -Status (Get-WinForgeText 'medindo os itens')
            $entries = @(Measure-WinForgeFolderItems -Items $allItems -ExcludeShellMetadata)
            Write-Progress -Activity (Get-WinForgeText 'Analisando a pasta Downloads') -Completed

            # @() e não $(): com um item só, $() devolveria o item solto, sem .Count de lista.
            $selected = @(if ($null -ne $days) { Select-WinForgeItemsOlderThan -Entries $entries -Cutoff (Get-Date).AddDays(-$days) } else { $entries })

            if ($selected.Count -eq 0) {
                $daysText = Format-WinForgeCount -Count $days -One (Get-WinForgeText 'dia') -Many (Get-WinForgeText 'dias')
                Write-WinForgeStatus -Type Success -Message (Get-WinForgeText 'Nada foi baixado ou alterado há mais de {0}; não há o que limpar.' "$daysText")
                $result = New-WinForgeResult -Kind Ok -Detail (Get-WinForgeText 'nada com mais de {0}' "$daysText")
                [void](Set-WinForgeResultView -Result $result -Headline (Get-WinForgeText 'Nada para limpar') -Note (Get-WinForgeText 'Nada foi baixado ou alterado há mais de {0}.' "$daysText"))
            }
        }

        if ($null -eq $result) {
            $selectedBytes = [int64]0
            foreach ($entry in $selected) { $selectedBytes += [int64]$entry.SizeBytes }

            $itemsText = Format-WinForgeCount -Count $selected.Count -One (Get-WinForgeText 'item') -Many (Get-WinForgeText 'itens')

            Show-WinForgeDownloadsPreview -Selected $selected

            Write-Host ""
            Write-WinForgeKeyValue -Label (Get-WinForgeText 'Itens a limpar') -Value (Format-WinForgeNumber -Value $selected.Count)
            Write-WinForgeKeyValue -Label (Get-WinForgeText 'Espaço que ocupam') -Value (Format-WinForgeBytes -Bytes $selectedBytes)
            Write-Host ""

            # Sem Lixeira na unidade (pendrive, unidade de rede, Lixeira desligada), o Windows apagaria em definitivo o que
            # fosse "para a Lixeira": a opção nem aparece, e a tela diz por quê antes da pergunta. Antes, a pessoa escolhia
            # a Lixeira, ouvia que nada tinha saído e precisava começar de novo. Com Lixeira, um item maior que o limite
            # dela ficaria onde está: dito antes da escolha, a pessoa decide entre deixá-lo e a exclusão permanente.
            $binProblem = Get-WinForgeRecycleBinProblem -Path $downloadsPath
            $destinations = @()

            if ($binProblem) {
                Write-WinForgeStatus -Type Warning -Notice -Message (Get-WinForgeText 'A pasta Downloads {0}: o que sair dela não tem volta.' "$binProblem")
                Write-Host ""
            }
            else {
                if (Test-WinForgeRecycleBinLimitExceeded -Items $selected) {
                    Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Itens maiores que o limite da Lixeira ficam onde estão: o Windows os apagaria em definitivo.')
                    Write-Host ""
                }

                $destinations += @{ Key = "L"; Label = (Get-WinForgeText 'Enviar para a Lixeira'); Description = (Get-WinForgeText 'recomendado: dá para recuperar'); Accent = $true }
            }

            $destinations += @{ Key = "P"; Label = (Get-WinForgeText 'Excluir permanentemente'); Description = (Get-WinForgeText 'não dá para recuperar'); Danger = $true }
            $destinations += @{ Key = "0"; Label = (Get-WinForgeText 'Cancelar'); Exit = $true }

            $destination = Read-WinForgeChoice -Message $(if ($selected.Count -eq 1) { (Get-WinForgeText 'O que fazer com este item?') } else { (Get-WinForgeText 'O que fazer com estes {0}?' "$itemsText") }) -ShowMenu -Options $destinations

            if ($destination -ne "P" -and ($destination -ne "L" -or $binProblem)) {
                Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'Limpeza cancelada.')
                $result = New-WinForgeResult -Kind Skipped -Detail (Get-WinForgeText 'cancelado pelo usuário')
            }
            else {
                $permanent = ($destination -eq "P")

                if ($permanent) {
                    Write-Host ""
                    # Aviso antes da pergunta, não resultado: não conta como ressalva, senão toda exclusão que deu certo
                    # terminaria como "Concluído com ressalvas".
                    Write-WinForgeStatus -Type Warning -Notice -Message $(if ($selected.Count -eq 1) { (Get-WinForgeText 'O item será removido permanentemente e não poderá ser recuperado.') } else { (Get-WinForgeText 'Os itens serão removidos permanentemente e não poderão ser recuperados.') })

                    if (-not (Confirm-WinForgeAction $(if ($selected.Count -eq 1) { (Get-WinForgeText 'Confirma a exclusão permanente de 1 item?') } else { (Get-WinForgeText 'Confirma a exclusão permanente de {0}?' "$itemsText") }) -DefaultKey N -Danger -YesLabel (Get-WinForgeText 'Excluir') -NoLabel (Get-WinForgeText 'Cancelar'))) {
                        Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'Limpeza cancelada.')
                        $result = New-WinForgeResult -Kind Skipped -Detail (Get-WinForgeText 'cancelado pelo usuário')
                    }
                }

                if ($null -eq $result) {
                    $result = Invoke-WinForgeDownloadsRemoval -Selected $selected -Permanent:$permanent
                }
            }
        }
    }
    catch {
        Write-WinForgeStatus -Type Error -Message (Get-WinForgeText 'Falha ao limpar Downloads: {0}' "$($_.Exception.Message)")
        $result = New-WinForgeResult -Kind Failed -Detail $_.Exception.Message
    }

    $result.Etapa = $title
    Exit-WinForgeAction -Result $result
}


function Invoke-WinForgeDownloadsRemoval {
    <#
    Manda os itens escolhidos para a Lixeira (ou os exclui de vez) e mostra o balanço. Um item só conta como removido se
    deixou de existir; um arquivo aberto por outro programa nem é enviado à Lixeira (o Windows abriria a janela "Arquivo
    em uso" e a limpeza ficaria parada esperando resposta). Devolve o WinForge.Result da tela.
    #>
    param (
        [Parameter(Mandatory)]
        [object[]]$Selected,

        [switch]$Permanent
    )

    Write-Host ""

    $done = 0
    $skipped = 0
    $tooBig = 0
    $limit = [int64]0
    $bytes = [int64]0
    $position = 0
    $activity = (Get-WinForgeText 'Limpar a pasta Downloads')

    foreach ($entry in $Selected) {
        $position++
        Write-WinForgeCleanupProgress -Activity $activity -Current $position -Total $Selected.Count

        # Maior que o limite da Lixeira, o Windows apagaria em definitivo, sem perguntar: o item fica, e o balanço diz por quê.
        if (-not $Permanent) {
            try { $limit = [int64](Get-WinForgeRecycleBinCapacity -Root ([IO.Path]::GetPathRoot([IO.Path]::GetFullPath([string]$entry.Path)))).MaxBytes } catch { $limit = [int64]0 }

            if ($limit -gt 0 -and [int64]$entry.SizeBytes -gt $limit) {
                $tooBig++
                continue
            }
        }

        try {
            # Na exclusão permanente não há janela do Windows: o que estiver em uso simplesmente fica.
            if (-not $Permanent -and (Test-WinForgeItemInUse -Path $entry.Path -IsDirectory:$entry.IsDirectory)) {
                throw (Get-WinForgeText 'em uso')
            }

            if ($Permanent) {
                Remove-WinForgeItem -Path $entry.Path
            }
            else {
                Move-WinForgeItemToRecycleBin -Path $entry.Path -IsDirectory:$entry.IsDirectory -SizeBytes ([int64]$entry.SizeBytes)
            }

            # Get-Item -Force e não Test-Path: um atalho quebrado "não existe" para o Test-Path, mas continua na pasta.
            if ($null -ne (Get-Item -LiteralPath $entry.Path -Force -ErrorAction SilentlyContinue)) {
                throw (Get-WinForgeText 'o item continua na pasta')
            }

            $done++
            $bytes += [int64]$entry.SizeBytes
        }
        catch {
            if ($null -eq (Get-Item -LiteralPath $entry.Path -Force -ErrorAction SilentlyContinue)) {
                # Já não está na pasta (saiu apesar do erro, ou alguém o tirou antes): não há o que contar como ignorado.
                continue
            }

            $skipped++

            # De uma pasta que não saiu inteira, conta só o que saiu dela.
            $bytes += Get-WinForgeFreedFromPartial -Entry $entry
        }
    }

    Write-WinForgeCleanupProgress -Activity $activity -Current 0 -Total 0 -Completed

    $bytesText = Format-WinForgeBytes -Bytes $bytes

    if ($done -eq 0 -and $tooBig -gt 0 -and $skipped -eq 0) {
        Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'Nenhum item foi para a Lixeira: todos passam do limite dela.')
    }
    elseif ($done -eq 0) {
        Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'Nenhum item foi removido: estavam em uso ou não puderam ser removidos.')
    }
    else {
        Write-WinForgeStatus -Type Success -Message (Get-WinForgeText 'Limpeza concluída.')
    }

    if ($Permanent) {
        Write-WinForgeKeyValue -Label (Get-WinForgeText 'Itens excluídos') -Value (Format-WinForgeNumber -Value $done)
        Write-WinForgeKeyValue -Label (Get-WinForgeText 'Espaço liberado') -Value $bytesText
    }
    else {
        Write-WinForgeKeyValue -Label (Get-WinForgeText 'Itens enviados à Lixeira') -Value (Format-WinForgeNumber -Value $done)
        Write-WinForgeKeyValue -Label (Get-WinForgeText 'Tamanho na Lixeira') -Value $bytesText
    }

    if ($skipped + $tooBig -gt 0) {
        Write-WinForgeKeyValue -Label (Get-WinForgeText 'Itens ignorados') -Value (Format-WinForgeNumber -Value ($skipped + $tooBig))
    }

    if ($tooBig -gt 0) {
        Write-Host ""
        # O Windows apagaria em definitivo o que passa do limite da Lixeira: fica, e a saída é a exclusão permanente.
        Write-WinForgeStatus -Type Warning -Message $(if ($tooBig -eq 1) { (Get-WinForgeText '1 item passa do limite da Lixeira ({0}) e ficou; para tirá-lo, use Excluir permanentemente.' "$(Format-WinForgeBytes -Bytes $limit)") } else { (Get-WinForgeText '{0} itens passam do limite da Lixeira ({1}) e ficaram; para tirá-los, use Excluir permanentemente.' "$tooBig" "$(Format-WinForgeBytes -Bytes $limit)") })
    }

    if ($skipped -gt 0 -and $done -gt 0) {
        Write-Host ""
        Write-WinForgeStatus -Type Warning -Message $(if ($skipped -eq 1) { (Get-WinForgeText '1 item estava em uso ou não pôde ser removido; feche o programa que o usa e tente de novo.') } else { (Get-WinForgeText '{0} itens estavam em uso ou não puderam ser removidos; feche os programas que os usam e tente de novo.' "$skipped") })
    }

    if (-not $Permanent -and $done -gt 0) {
        Write-Host ""
        Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'O espaço só volta quando a Lixeira for esvaziada (Limpeza > Esvaziar a Lixeira).')
    }

    if ($done -eq 0) {
        return New-WinForgeResult -Kind Warning -Detail $(if ($skipped -eq 0 -and $tooBig -gt 0) { (Get-WinForgeText 'nenhum item foi removido: passam do limite da Lixeira') } else { (Get-WinForgeText 'nenhum item foi removido: estavam em uso') })
    }

    # Mandar para a Lixeira não libera espaço no disco; só a exclusão permanente libera.
    $detail = $(if ($Permanent) { (Get-WinForgeText '{0}, liberou {1}' "$(Format-WinForgeCount -Count $done -One (Get-WinForgeText 'item excluído') -Many (Get-WinForgeText 'itens excluídos'))" "$bytesText") } else { (Get-WinForgeText '{0} à Lixeira ({1})' "$(Format-WinForgeCount -Count $done -One (Get-WinForgeText 'item enviado') -Many (Get-WinForgeText 'itens enviados'))" "$bytesText") })
    $freed = $(if ($Permanent) { $bytes } else { [int64]0 })

    if ($skipped + $tooBig -gt 0) {
        $partial = New-WinForgeResult -Kind Warning -Detail "$detail; $(Format-WinForgeCount -Count ($skipped + $tooBig) -One (Get-WinForgeText 'ficou') -Many (Get-WinForgeText 'ficaram'))" -Data @{ FreedBytes = $freed }

        # O que foi para a Lixeira também espera ser esvaziado: o botão da faixa leva até lá.
        if (-not $Permanent) { [void](Set-WinForgeRecycleBinNext -Result $partial -Count $done -Bytes $bytes) }

        return $partial
    }

    $okResult = New-WinForgeResult -Kind Ok -Detail $detail -Data @{ FreedBytes = $freed }

    # Na Lixeira, o espaço ainda não voltou: o botão da faixa esvazia a Lixeira. Na exclusão permanente, a faixa diz quanto
    # voltou ao disco, como as outras limpezas, e que não passou pela Lixeira.
    if (-not $Permanent) { [void](Set-WinForgeRecycleBinNext -Result $okResult -Count $done -Bytes $bytes) }
    elseif ($bytes -gt 0) {
        [void](Set-WinForgeResultView -Result $okResult -Headline (Get-WinForgeText '{0} liberados' "$bytesText") -Note (Get-WinForgeText '{0}, sem passar pela Lixeira.' "$(Format-WinForgeCount -Count $done -One (Get-WinForgeText 'item excluído') -Many (Get-WinForgeText 'itens excluídos'))"))
    }
    else {
        # Pastas e arquivos vazios: a faixa diz quantos saíram e que o espaço não muda (antes, "Tudo certo" e "liberou 0 B").
        [void](Set-WinForgeResultView -Result $okResult -Headline (Format-WinForgeCount -Count $done -One (Get-WinForgeText 'item excluído') -Many (Get-WinForgeText 'itens excluídos')) -Note (Get-WinForgeCleanupZeroNote))
    }

    return $okResult
}


# ---------------------------------------------------------------------------
# Pastas pessoais (etapa do Otimizar)
# ---------------------------------------------------------------------------

function Get-WinForgeReviewFolders {
    # As pastas pessoais que o Otimizar sugere organizar, na ordem. Shortcut é o atalho que abre a pasta e diz onde ela
    # fica (Get-WinForgeShortcutFolderPath); Clean, a ação do WinForge que limpa a pasta além de abri-la.
    return @(
        [PSCustomObject]@{ Shortcut = "Downloads"; Label = (Get-WinForgeText 'Downloads'); Clean = "Clear-WinForgeDownloads" },
        [PSCustomObject]@{ Shortcut = "Documents"; Label = (Get-WinForgeText 'Documentos'); Clean = "" },
        [PSCustomObject]@{ Shortcut = "Pictures"; Label = (Get-WinForgeText 'Imagens'); Clean = "" }
    )
}


function Invoke-WinForgeFolderReview {
    <#
    A etapa das pastas pessoais do Otimizar: uma pasta por vez (Downloads, Documentos e Imagens), com o tamanho e o que
    dá para fazer nela. Na Downloads, limpar com o WinForge (prévia, filtro por idade, Lixeira); em todas, abrir no
    Explorador para organizar à mão ou procurar arquivos duplicados. Nada sai da pasta sem a pessoa escolher. Uma pasta
    vazia ou que não existe passa direto. Devolve um WinForge.Result que diz o que foi feito em cada pasta.
    #>
    param (
        [switch]$Embedded,
        [switch]$PassThru
    )

    $title = (Get-WinForgeText 'Organizar Downloads, Documentos e Imagens')

    Enter-WinForgeAction -Title $title -Embedded:$Embedded

    $notes = @()
    $problems = 0
    # O que mudou de fato: limpar ou procurar duplicados e desistir no meio ("nada mudou") não conta.
    $done = 0
    $final = $null

    try {
        [void](Write-WinForgeOtherAccountNotice -What 'as pastas pessoais (Downloads, Documentos e Imagens)')

        $folders = @(Get-WinForgeReviewFolders)
        $position = 0

        foreach ($folder in $folders) {
            $position++
            $path = Get-WinForgeShortcutFolderPath -Name $folder.Shortcut

            Write-WinForgeSection -Title (Get-WinForgeText '{0} ({1} de {2})' "$($folder.Label)" "$position" "$($folders.Count)")

            if ([string]::IsNullOrWhiteSpace($path) -or -not (Test-Path -LiteralPath $path -PathType Container)) {
                Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Pasta não encontrada.')
                continue
            }

            Write-Progress -Activity (Get-WinForgeText 'Medindo a pasta {0}' "$($folder.Label)") -Status $path

            try { $stats = Get-WinForgePathStats -Path $path -ExcludeShellMetadata }
            finally { Write-Progress -Activity (Get-WinForgeText 'Medindo a pasta {0}' "$($folder.Label)") -Completed }

            Write-WinForgeKeyValue -Label (Get-WinForgeText 'Pasta') -Value $path

            if ([int64]$stats.Files -eq 0) {
                Write-WinForgeKeyValue -Label (Get-WinForgeText 'Conteúdo') -Value (Get-WinForgeText 'vazia')
                continue
            }

            Write-WinForgeKeyValue -Label (Get-WinForgeText 'Conteúdo') -Value (Get-WinForgeText '{0} em {1}' "$(Format-WinForgeBytes -Bytes ([int64]$stats.Size) -ZeroText '0 B')" "$(Format-WinForgeCount -Count ([int64]$stats.Files) -One (Get-WinForgeText 'arquivo') -Many (Get-WinForgeText 'arquivos'))")
            Write-Host ""

            $options = @()
            $keys = @()

            if ($folder.Clean) {
                $options += @{ Key = "L"; Label = (Get-WinForgeText 'Limpar com o WinForge'); Description = (Get-WinForgeText 'o que você escolher vai para a Lixeira'); Accent = $true }
                $keys += "L"
            }

            $options += @{ Key = "A"; Label = (Get-WinForgeText 'Abrir no Explorador'); Description = (Get-WinForgeText 'você organiza à mão'); Accent = (-not $folder.Clean) }
            $options += @{ Key = "D"; Label = (Get-WinForgeText 'Procurar arquivos duplicados'); Description = (Get-WinForgeText 'cópias iguais; você escolhe o que vai para a Lixeira') }
            $options += @{ Key = "P"; Label = (Get-WinForgeText 'Pular esta pasta') }
            $keys += @("A", "D", "P")

            if ($position -lt $folders.Count) {
                $options += @{ Key = "X"; Label = (Get-WinForgeText 'Pular as pastas restantes'); Exit = $true }
                $keys += "X"
            }

            $keyText = (Get-WinForgeText '{0} ou {1}' "$(@($keys | Select-Object -First ($keys.Count - 1)) -join ', ')" "$($keys[$keys.Count - 1])")
            $answer = Read-WinForgeChoice -Message (Get-WinForgeText 'O que fazer com a pasta {0}?' "$($folder.Label)") -Options $options -DefaultKey "P" -ShowMenu `
                -TextPrompt (Get-WinForgeText 'Opção ({0}; ENTER = pular esta pasta)' "$keyText")

            if ($answer -ieq "X") {
                Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'As pastas restantes ficaram como estão.')
                break
            }

            if (($answer -ieq "L" -and $folder.Clean) -or $answer -ieq "D") {
                $result = $(if ($answer -ieq "D") { Invoke-WinForgeNestedAction -Command "Find-WinForgeDuplicateFiles" -Arguments @{ Path = $path } } else { Invoke-WinForgeNestedAction -Command $folder.Clean })
                $notes += "$($folder.Label): $(Get-WinForgeFolderReviewNote -Result $result)"
                if ($result.Kind -eq "Failed") { $problems++ } elseif ($result.Kind -ne "Skipped") { $done++ }
            }
            elseif ($answer -ieq "A") {
                if (Open-WinForgeShortcut -Name $folder.Shortcut) {
                    Write-Host ""
                    [void](Read-WinForgeChoice -Message (Get-WinForgeText 'Organize a pasta na janela aberta e depois continue.') -Options @(@{ Key = "C"; Label = (Get-WinForgeText 'Continuar'); Accent = $true }) `
                            -DefaultKey "C" -TextPrompt (Get-WinForgeText 'Organize a pasta na janela aberta e pressione ENTER'))
                    $notes += (Get-WinForgeText '{0}: aberta no Explorador' "$($folder.Label)")
                    $done++
                }
                else {
                    # Open-WinForgeShortcut já disse o motivo na tela; o resumo diz qual pasta não abriu.
                    $notes += (Get-WinForgeText '{0}: não abriu no Explorador' "$($folder.Label)")
                    $problems++
                }
            }
        }

        if ($problems -gt 0) {
            $final = New-WinForgeResult -Kind Warning -Detail ($notes -join "; ") -Title $title
        }
        elseif ($done -eq 0) {
            $final = New-WinForgeResult -Kind Skipped -Detail (Get-WinForgeText 'nenhuma pasta foi mexida') -Title $title
        }
        else {
            $final = New-WinForgeResult -Kind Ok -Detail ($notes -join "; ") -Title $title
        }
    }
    catch {
        Write-WinForgeStatus -Type Error -Message (Get-WinForgeText 'Não foi possível revisar as pastas: {0}.' "$($_.Exception.Message.TrimEnd('.'))")
        $final = New-WinForgeResult -Kind Failed -Detail $_.Exception.Message.TrimEnd('.') -Title $title
    }

    if ($PassThru) { $final }
    Exit-WinForgeAction -Embedded:$Embedded -Result $final
}


function Get-WinForgeFolderReviewNote {
    # O que uma ação fez numa pasta, para a linha do resumo: o detalhe dela ("12 arquivos enviados para a Lixeira") ou,
    # sem detalhe, o desfecho. Desistir no meio vira "nada mudou".
    param ([Parameter(Mandatory)]$Result)

    $detail = [string](Get-WinForgeJsonValue -Object $Result -Name "Detail" -Default "")

    if ([string]$Result.Kind -eq "Skipped" -and ([string]::IsNullOrWhiteSpace($detail) -or (Test-WinForgeCanceledText -Text $detail))) {
        return (Get-WinForgeText 'nada mudou')
    }

    if (-not [string]::IsNullOrWhiteSpace($detail)) { return $detail }

    return $(if ([string]$Result.Kind -eq "Ok") { (Get-WinForgeText 'concluído') } else { [string]$Result.Status })
}


# ---------------------------------------------------------------------------
# Componentes do Windows
# ---------------------------------------------------------------------------

function Invoke-WinForgeComponentCleanup {
    param (
        [switch]$Embedded,
        [switch]$PassThru
    )

    # O DISM não diz quanto liberou: o espaço livre do disco do Windows antes e depois diz (outro programa gravando ao
    # mesmo tempo mexe na conta, por isso "cerca de"). Sem uma das leituras, fica o resultado do DISM.
    $before = [int64](Get-WinForgeSystemDriveFreeBytes)

    # Só o código: o texto da saída e o resto do que o Invoke-WinForgeTool passa ficam em $args.
    $parser = {
        param ($ExitCode)

        # Com a manutenção dos componentes esperando um reinício (0x800F0806 é o CBS_E_PENDING; 0x800F082F e o 3017
        # aparecem no mesmo caso), o DISM recusa a limpeza: o que resolve é reiniciar, e a tela diz isso, e não só o código.
        $code = Format-WinForgeExitCode -ExitCode $ExitCode

        if ($code -in @("0x800F0806", "0x800F082F", "3017")) {
            return (New-WinForgeResult -Kind Failed -Detail (Get-WinForgeText 'o Windows espera um reinício para terminar outra instalação, e os componentes só são limpos depois disso — erro {0}' "$code") -Data @{ RebootRequired = $true; Notes = @((Get-WinForgeText 'Reinicie o PC e rode a limpeza de novo.')) })
        }

        $result = Get-WinForgeExitCodeResult -ExitCode $ExitCode
        $after = [int64](Get-WinForgeSystemDriveFreeBytes)

        if ($result.Kind -eq "Ok" -and $before -ge 0 -and $after -ge 0) {
            $freed = $after - $before

            if ($freed -lt 50MB) {
                $result = New-WinForgeResult -Kind Ok -Detail (Get-WinForgeText 'quase nada a liberar') -Data @{ FreedBytes = [int64]0 }
            }
            else {
                $result = New-WinForgeResult -Kind Ok -Detail (Get-WinForgeText 'liberou cerca de {0}' "$(Format-WinForgeBytes -Bytes $freed)") -Data @{ FreedBytes = [int64]$freed }
            }
        }

        $result
    }.GetNewClosure()

    # A faixa: quanto voltou ao disco (medido no espaço livre, por isso "cerca de") ou, com quase nada, que o Windows já
    # faz essa limpeza sozinho (a tarefa StartComponentCleanup, quando o PC está parado).
    $view = {
        param ($Result)

        if ([string]$Result.Kind -ne "Ok") { return }

        $componentsFreed = Get-WinForgeResultData -Result $Result -Name "FreedBytes"

        if ($null -ne $componentsFreed -and [int64]$componentsFreed -gt 0) {
            Set-WinForgeResultView -Result $Result -Headline (Get-WinForgeText 'Cerca de {0} liberados' "$(Format-WinForgeBytes -Bytes ([int64]$componentsFreed))") -Note (Get-WinForgeText 'Medido pelo espaço livre do disco do Windows, antes e depois da limpeza.')
        }
        elseif ($null -ne $componentsFreed) {
            Set-WinForgeResultView -Result $Result -Headline (ConvertTo-WinForgeHeadline -Text (Get-WinForgeText 'quase nada a liberar')) -Note (Get-WinForgeText 'O Windows já faz esta limpeza sozinho, de tempos em tempos.')
        }
    }

    # Com uma atualização esperando o reinício, o DISM recusaria a limpeza depois de minutos (0x800F0806): sozinha, a
    # ação não roda e oferece reiniciar. No Otimizar, quem confere isso é o Otimizar.
    $pending = @{
        Note            = (Get-WinForgeText 'O Windows espera um reinício para terminar uma atualização: os componentes só podem ser limpos depois de reiniciar.')
        Detail          = (Get-WinForgeText 'o Windows espera um reinício para terminar uma atualização; a limpeza só roda depois de reiniciar')
        Headline        = (Get-WinForgeText 'Reinicie antes de limpar')
        Reason          = (Get-WinForgeText 'Reiniciar agora deixa o Windows pronto para a limpeza.')
        Comment         = (Get-WinForgeText 'Reinicialização solicitada pelo WinForge antes da limpeza dos componentes do Windows (DISM).')
        DeclinedMessage = (Get-WinForgeText 'Reinicialização não iniciada. Depois de reiniciar, rode a limpeza de novo.')
    }

    Invoke-WinForgeTool `
        -Title (Get-WinForgeText 'Limpar componentes do Windows (WinSxS)') `
        -FilePath "dism.exe" `
        -Arguments @("/Online", "/Cleanup-Image", "/StartComponentCleanup") `
        -Description @((Get-WinForgeText 'Remove versões antigas de componentes do Windows, em 5 a 30 minutos.')) `
        -Warnings @((Get-WinForgeText 'Não apaga nada seu, e as atualizações recentes continuam podendo ser desinstaladas.')) `
        -Question (Get-WinForgeText 'Limpar os componentes agora?') `
        -YesLabel (Get-WinForgeText 'Limpar') -NoLabel (Get-WinForgeText 'Cancelar') `
        -ResultParser $parser `
        -ResultView $view `
        -NeedsServicing -ServicingText $pending `
        -Embedded:$Embedded -PassThru:$PassThru
}


# ---------------------------------------------------------------------------
# Análise de espaço e limpeza personalizada
# ---------------------------------------------------------------------------

function Get-WinForgeBrowserCachePaths {
    # Pastas de cache (nunca cookies, senhas nem histórico) do Edge, do Chrome, do Brave e do Vivaldi, em todos os perfis,
    # do Opera e do Opera GX e do Firefox. Só devolve as que existem.
    param (
        [string]$LocalAppData = $env:LOCALAPPDATA
    )

    if ([string]::IsNullOrWhiteSpace($LocalAppData)) {
        return @()
    }

    $paths = @()

    $chromium = @(
        (Join-Path $LocalAppData "Microsoft\Edge\User Data"),
        (Join-Path $LocalAppData "Google\Chrome\User Data"),
        (Join-Path $LocalAppData "BraveSoftware\Brave-Browser\User Data"),
        (Join-Path $LocalAppData "Vivaldi\User Data")
    )

    foreach ($root in $chromium) {
        if (-not (Test-Path -LiteralPath $root -PathType Container)) { continue }

        $profiles = @(Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq "Default" -or $_.Name -like "Profile *" })

        foreach ($browserProfile in $profiles) {
            foreach ($relative in @("Cache\Cache_Data", "Code Cache")) {
                $candidate = Join-Path $browserProfile.FullName $relative

                if (Test-Path -LiteralPath $candidate -PathType Container) {
                    $paths += $candidate
                }
            }
        }
    }

    # O Opera guarda o perfil em AppData\Roaming e o cache, sem pastas de perfil, em AppData\Local.
    foreach ($opera in @("Opera Software\Opera Stable", "Opera Software\Opera GX Stable")) {
        foreach ($relative in @("Cache\Cache_Data", "Code Cache")) {
            $candidate = Join-Path (Join-Path $LocalAppData $opera) $relative

            if (Test-Path -LiteralPath $candidate -PathType Container) {
                $paths += $candidate
            }
        }
    }

    $firefoxRoot = Join-Path $LocalAppData "Mozilla\Firefox\Profiles"

    if (Test-Path -LiteralPath $firefoxRoot -PathType Container) {
        foreach ($browserProfile in @(Get-ChildItem -LiteralPath $firefoxRoot -Directory -ErrorAction SilentlyContinue)) {
            $candidate = Join-Path $browserProfile.FullName "cache2"

            if (Test-Path -LiteralPath $candidate -PathType Container) {
                $paths += $candidate
            }
        }
    }

    return @($paths)
}


function Get-WinForgeShaderCachePaths {
    # Caches de sombreadores (shaders) do DirectX e dos drivers de vídeo NVIDIA e AMD. Jogos e o próprio Windows recriam
    # tudo sozinhos; o primeiro carregamento de cada jogo depois da limpeza fica mais lento. Só as que existem.
    param (
        [string]$LocalAppData = $env:LOCALAPPDATA
    )

    if ([string]::IsNullOrWhiteSpace($LocalAppData)) { return @() }

    return @(
        foreach ($relative in @("D3DSCache", "NVIDIA\DXCache", "NVIDIA\GLCache", "AMD\DxCache", "AMD\DxcCache", "AMD\GLCache", "AMD\VkCache")) {
            $candidate = Join-Path $LocalAppData $relative
            if (Test-Path -LiteralPath $candidate -PathType Container) { $candidate }
        }
    )
}


function Get-WinForgeMemoryDumpFile {
    # O despejo completo da última tela azul (MEMORY.DMP, na pasta do Windows): costuma ter vários GB, e a Limpeza de Disco
    # do Windows também o oferece. "" quando não se sabe onde fica o Windows.
    param (
        [string]$Windows = $(if (-not [string]::IsNullOrWhiteSpace($env:WINDIR)) { $env:WINDIR } else { $env:SystemRoot })
    )

    if ([string]::IsNullOrWhiteSpace($Windows)) { return "" }

    return (Join-Path $Windows "MEMORY.DMP")
}


function Get-WinForgeCrashDumpPaths {
    # Despejos de memória: o dos programas que travaram (do usuário) e os pequenos da tela azul (do Windows).
    param (
        [string]$LocalAppData = $env:LOCALAPPDATA,
        [string]$Windows = $(if (-not [string]::IsNullOrWhiteSpace($env:WINDIR)) { $env:WINDIR } else { $env:SystemRoot })
    )

    return @(
        if (-not [string]::IsNullOrWhiteSpace($LocalAppData)) { Join-Path $LocalAppData "CrashDumps" }
        if (-not [string]::IsNullOrWhiteSpace($Windows)) { Join-Path $Windows "Minidump" }
    )
}


function New-WinForgeCleanupTarget {
    param (
        [string]$Id,
        [string]$Label,
        [string]$Description,
        [string[]]$Paths = @(),
        [string[]]$Files = @(),
        [int]$MinAgeHours = 0,
        [switch]$RecycleBin,
        [switch]$Admin,
        [switch]$Selected
    )

    return [PSCustomObject]@{
        Id          = $Id
        Label       = $Label
        Description = $Description
        Paths       = @($Paths | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })

        # Arquivos soltos (o MEMORY.DMP, que fica na pasta do Windows e não numa pasta própria).
        Files       = @($Files | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })

        # Itens mais novos que isto (em horas) ficam: os temporários de uma instalação em andamento.
        MinAgeHours = $MinAgeHours
        RecycleBin  = [bool]$RecycleBin
        Admin       = [bool]$Admin
        Selected    = [bool]$Selected
        Size        = $null
        Unreadable  = 0

        # Só da Lixeira: o que a medição encontrou (Count e SizeBytes), para esvaziar sem medir de novo.
        BinContents = $null
    }
}


function Get-WinForgeCleanupTargets {
    # O que a limpeza personalizada sabe esvaziar. Selected = vem marcado (temporários e relatórios, que o Windows
    # recria sozinho); caches de navegador e Lixeira ficam por conta de quem escolhe. Size é preenchido por
    # Measure-WinForgeCleanupTarget.
    $windows = $(if (-not [string]::IsNullOrWhiteSpace($env:WINDIR)) { $env:WINDIR } else { $env:SystemRoot })
    $programData = $env:ProgramData

    $errorReports = @()
    if (-not [string]::IsNullOrWhiteSpace($programData)) {
        $errorReports += (Join-Path $programData "Microsoft\Windows\WER\ReportArchive")
        $errorReports += (Join-Path $programData "Microsoft\Windows\WER\ReportQueue")
    }

    $deliveryCache = @()
    if (-not [string]::IsNullOrWhiteSpace($windows)) {
        $deliveryCache += (Join-Path $windows "ServiceProfiles\NetworkService\AppData\Local\Microsoft\Windows\DeliveryOptimization\Cache")
    }

    return @(
        (New-WinForgeCleanupTarget -Id "user-temp" -Label (Get-WinForgeText 'Temporários do usuário') -Selected -MinAgeHours $script:WinForgeTempMinAgeHours `
            -Description (Get-WinForgeText 'O que os programas deixam na sua pasta Temp') -Paths @(Get-WinForgeUserTempPath)),
        (New-WinForgeCleanupTarget -Id "windows-temp" -Label (Get-WinForgeText 'Temporários do Windows') -Admin -Selected -MinAgeHours $script:WinForgeTempMinAgeHours `
            -Description (Get-WinForgeText 'A pasta Temp do sistema') -Paths @(Get-WinForgeWindowsTempPath)),
        (New-WinForgeCleanupTarget -Id "error-reports" -Label (Get-WinForgeText 'Relatórios de erro do Windows') -Admin -Selected `
            -Description (Get-WinForgeText 'Cópias de falhas de programas') -Paths $errorReports),
        (New-WinForgeCleanupTarget -Id "delivery-optimization" -Label (Get-WinForgeText 'Cache da Otimização de Entrega') -Admin -Selected `
            -Description (Get-WinForgeText 'Partes de atualizações; o Windows baixa de novo se precisar') -Paths $deliveryCache),
        (New-WinForgeCleanupTarget -Id "browser-cache" -Label (Get-WinForgeText 'Cache dos navegadores') `
            -Description (Get-WinForgeText 'Senhas, cookies e histórico ficam; as páginas abrem mais devagar na primeira vez') `
            -Paths @(Get-WinForgeBrowserCachePaths)),
        (New-WinForgeCleanupTarget -Id "shader-cache" -Label (Get-WinForgeText 'Cache de sombreadores dos jogos') `
            -Description (Get-WinForgeText 'O primeiro carregamento de cada jogo fica mais lento') `
            -Paths @(Get-WinForgeShaderCachePaths)),
        (New-WinForgeCleanupTarget -Id "crash-dumps" -Label (Get-WinForgeText 'Despejos de memória de falhas') -Admin `
            -Description (Get-WinForgeText 'Só servem para investigar travamentos e telas azuis') `
            -Paths @(Get-WinForgeCrashDumpPaths) -Files @(Get-WinForgeMemoryDumpFile)),
        (New-WinForgeCleanupTarget -Id "recycle-bin" -Label (Get-WinForgeText 'Lixeira') -RecycleBin `
            -Description (Get-WinForgeText 'O que está nela é removido em definitivo'))
    )
}


function Measure-WinForgeCleanupTarget {
    <#
    Soma o tamanho das pastas do alvo; para a Lixeira, o que estiver nas pastas dela. Unreadable conta as pastas que
    existem e não puderam ser lidas (sem permissão). Size fica nulo quando não dá para medir: a Lixeira ilegível, ou só
    havia pastas ilegíveis. Assim a tela não afirma "nada acumulado" sobre o que não conseguiu olhar.
    #>
    param (
        [Parameter(Mandatory)]
        $Target
    )

    if ($Target.RecycleBin) {
        $Target.BinContents = Get-WinForgeRecycleBinContents
        $Target.Size = $(if ($null -ne $Target.BinContents) { [int64]$Target.BinContents.SizeBytes } else { $null })
        return $Target
    }

    $total = [int64]0
    $unreadable = 0
    $minAge = [int](Get-WinForgeJsonValue -Object $Target -Name "MinAgeHours" -Default 0)

    foreach ($path in @($Target.Paths)) {
        if (-not (Test-Path -LiteralPath $path -PathType Container)) { continue }

        if ($minAge -gt 0) {
            # Só o que a limpeza vai tirar: o recente fica, e prometer o tamanho dele seria prometer demais.
            $listing = Get-WinForgeFolderListing -Path $path -ExcludeShellMetadata

            if (-not $listing.Readable) { $unreadable++; continue }

            foreach ($entry in @(Select-WinForgeItemsOlderThan -Entries @(Measure-WinForgeFolderItems -Items $listing.Items -ExcludeShellMetadata) -Cutoff (Get-Date).AddHours(-$minAge))) {
                $total += [int64]$entry.SizeBytes
            }

            continue
        }

        $size = Get-WinForgeFolderSize -Path $path -ExcludeShellMetadata

        if ($null -eq $size) { $unreadable++ } else { $total += $size }
    }

    foreach ($file in @(Get-WinForgeJsonValue -Object $Target -Name "Files" -Default @())) {
        try {
            $item = Get-Item -LiteralPath $file -Force -ErrorAction Stop
            if (-not $item.PSIsContainer) { $total += [int64]$item.Length }
        }
        catch {
            # Arquivo que não existe é o normal; um que existe e não abriu conta como ilegível.
            if (Test-Path -LiteralPath $file) { $unreadable++ }
        }
    }

    $Target.Unreadable = $unreadable
    $Target.Size = $(if ($unreadable -gt 0 -and $total -eq 0) { $null } else { $total })

    return $Target
}


function Get-WinForgeUserFolderSizes {
    # As pastas de primeiro nível do perfil do usuário com o tamanho de cada uma, da maior para a menor.
    param (
        [string]$ProfilePath = $env:USERPROFILE,

        [int]$Top = 8
    )

    if ([string]::IsNullOrWhiteSpace($ProfilePath) -or -not (Test-Path -LiteralPath $ProfilePath -PathType Container)) {
        return @()
    }

    $folders = @(Get-ChildItem -LiteralPath $ProfilePath -Directory -Force -ErrorAction SilentlyContinue |
            Where-Object { -not ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) })

    # Somar um perfil inteiro pode levar minutos: a barra diz em que pasta a soma está.
    $activity = (Get-WinForgeText 'Somando o tamanho das pastas do perfil')
    $position = 0

    $rows = @(
        foreach ($folder in $folders) {
            $position++
            Write-Progress -Activity $activity -Status (Get-WinForgeText '{0} ({1} de {2})' "$($folder.Name)" "$position" "$($folders.Count)") -PercentComplete ([int](($position - 1) * 100 / $folders.Count))
            [PSCustomObject]@{ Name = $folder.Name; Path = $folder.FullName; Size = [int64](Get-WinForgePathStats -Path $folder.FullName).Size }
        }
    )

    Write-Progress -Activity $activity -Completed

    return @($rows | Sort-Object -Property Size -Descending | Select-Object -First $Top)
}


function Get-WinForgeSystemSpaceFiles {
    # Arquivos e pastas grandes do sistema que a pessoa costuma querer conhecer. Size nulo = não existe (Unreadable falso)
    # ou existe e não pôde ser lido (Unreadable verdadeiro).
    $drive = $(if (-not [string]::IsNullOrWhiteSpace($env:SystemDrive)) { $env:SystemDrive } else { "C:" })
    $driveRoot = $drive.TrimEnd([char]92, [char]47) + [IO.Path]::DirectorySeparatorChar
    $windows = $(if (-not [string]::IsNullOrWhiteSpace($env:WINDIR)) { $env:WINDIR } else { Join-Path $driveRoot "Windows" })

    $entries = @(
        @{ Label = (Get-WinForgeText 'Hibernação (hiberfil.sys)'); Path = (Join-Path $driveRoot "hiberfil.sys"); Folder = $false; Hint = (Get-WinForgeText 'sai com o ajuste Desativar hibernação, na página Ajustes do Windows') },
        @{ Label = (Get-WinForgeText 'Memória virtual (pagefile.sys)'); Path = (Join-Path $driveRoot "pagefile.sys"); Folder = $false; Hint = (Get-WinForgeText 'o Windows cuida dele; não mexa sem motivo') },
        @{ Label = (Get-WinForgeText 'Arquivo de troca (swapfile.sys)'); Path = (Join-Path $driveRoot "swapfile.sys"); Folder = $false; Hint = (Get-WinForgeText 'o Windows cuida dele') },
        @{ Label = (Get-WinForgeText 'Windows anterior (Windows.old)'); Path = (Join-Path $driveRoot "Windows.old"); Folder = $true; Hint = (Get-WinForgeText 'remova em Limpeza > Configurações de armazenamento (Arquivos temporários, Instalações anteriores do Windows)') },
        @{ Label = (Get-WinForgeText 'Downloads do Windows Update'); Path = (Join-Path $windows "SoftwareDistribution\Download"); Folder = $true; Hint = (Get-WinForgeText 'o Windows apaga depois de instalar as atualizações') },
        @{ Label = (Get-WinForgeText 'Despejo de tela azul (MEMORY.DMP)'); Path = (Join-Path $windows "MEMORY.DMP"); Folder = $false; Hint = (Get-WinForgeText 'sai em Limpeza > Limpeza personalizada (Despejos de memória de falhas)') }
    )

    return @(
        foreach ($entry in $entries) {
            $size = $null
            $unreadable = $false

            try {
                if ($entry.Folder) {
                    if (Test-Path -LiteralPath $entry.Path -PathType Container) {
                        $size = Get-WinForgeFolderSize -Path $entry.Path

                        # A pasta existe e não pôde ser lida (Windows.old e SoftwareDistribution pedem Administrador).
                        $unreadable = ($null -eq $size)
                    }
                }
                else {
                    $file = Get-Item -LiteralPath $entry.Path -Force -ErrorAction Stop
                    $size = [int64]$file.Length
                }
            }
            catch {
                # Arquivo que não existe é normal (sem hibernação, sem Windows.old); que existe e não abriu, não.
                $size = $null
                $unreadable = [bool](Test-Path -LiteralPath $entry.Path)
            }

            [PSCustomObject]@{ Label = $entry.Label; Path = $entry.Path; Size = $size; Unreadable = $unreadable; Hint = $entry.Hint }
        }
    )
}


function Measure-WinForgeCleanupTargets {
    # Todos os alvos da limpeza personalizada, medidos, com a barra dizendo qual está sendo medido.
    $targets = @(Get-WinForgeCleanupTargets)
    $activity = (Get-WinForgeText 'Medindo o que pode ser liberado')
    $position = 0

    $measured = @(
        foreach ($target in $targets) {
            $position++
            Write-Progress -Activity $activity -Status (Get-WinForgeText '{0} ({1} de {2})' "$($target.Label)" "$position" "$($targets.Count)") -PercentComplete ([int](($position - 1) * 100 / $targets.Count))
            Measure-WinForgeCleanupTarget -Target $target
        }
    )

    Write-Progress -Activity $activity -Completed

    return $measured
}


function Test-WinForgeCleanupTargetAvailable {
    # Entra na lista o que tem algo dentro e o que não pôde ser medido (sem tamanho); só o que está vazio fica de fora.
    # A Lixeira conta pelos itens: arquivos vazios apagados também ocupam lugar nela.
    param (
        [Parameter(Mandatory)]
        $Target
    )

    if ($null -eq $Target.Size) { return $true }
    if ($Target.Size -gt 0) { return $true }

    return ($Target.RecycleBin -and $null -ne $Target.BinContents -and [int]$Target.BinContents.Count -gt 0)
}


function Show-WinForgeSpaceAnalysis {
    $title = (Get-WinForgeText 'Analisar uso de espaço')
    Enter-WinForgeAction -Title $title

    $result = $null

    try {
        # O que não pôde ser medido é dito no fim; "nada acumulado" só vale para o que de fato foi olhado.
        $unmeasured = New-Object System.Collections.Generic.List[string]
        $headline = ""
        $diskLevel = ""
        $sum = [int64]0

        Write-WinForgeSection -Title (Get-WinForgeText 'Disco do sistema')

        $space = Get-WinForgeSystemDriveSpace

        if ($null -ne $space -and $space.TotalBytes -gt 0) {
            $headline = (Get-WinForgeText '{0} livres de {1}' "$(Format-WinForgeBytes -Bytes $space.FreeBytes -ZeroText '0 B')" "$(Format-WinForgeBytes -Bytes $space.TotalBytes)")
            $diskLevel = Get-WinForgeDiskSpaceLevel -FreeBytes $space.FreeBytes -TotalBytes $space.TotalBytes
            $used = [int64]$space.TotalBytes - [int64]$space.FreeBytes
            $percent = [int][Math]::Round(($used * 100.0) / $space.TotalBytes, [MidpointRounding]::AwayFromZero)

            Write-WinForgeKeyValue -Label (Get-WinForgeText 'Tamanho') -Value (Format-WinForgeBytes -Bytes $space.TotalBytes)
            Write-WinForgeKeyValue -Label (Get-WinForgeText 'Em uso') -Value "$(Format-WinForgeBytes -Bytes $used -ZeroText '0 B') ($percent%)"
            Write-WinForgeKeyValue -Label (Get-WinForgeText 'Livre') -Value (Format-WinForgeBytes -Bytes $space.FreeBytes -ZeroText '0 B')

            # A regra da tela inicial e da Manutenção. Um aviso sobre o disco, não sobre a análise: não conta no desfecho.
            switch ($diskLevel) {
                "Critical" { Write-WinForgeStatus -Type Warning -Notice -Message (Get-WinForgeText 'O disco do sistema está quase cheio: o Windows precisa de espaço livre para se atualizar.') }
                "Low" { Write-WinForgeStatus -Type Warning -Notice -Message (Get-WinForgeText 'Pouco espaço livre no disco do sistema.') }
            }
        }
        else {
            Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'Não foi possível ler o tamanho do disco do sistema.')
        }

        Write-WinForgeSection -Title (Get-WinForgeText 'O que a limpeza pode liberar')

        $targets = @(Measure-WinForgeCleanupTargets)
        $withSize = @($targets | Where-Object { $null -ne $_.Size -and $_.Size -gt 0 } | Sort-Object -Property Size -Descending)

        foreach ($target in @($targets | Where-Object { $null -eq $_.Size -or $_.Unreadable -gt 0 })) {
            $unmeasured.Add($target.Label)
        }

        if ($withSize.Count -eq 0) {
            if ($unmeasured.Count -eq 0) {
                Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Não há temporários, relatórios nem caches acumulados.')
            }
        }
        else {
            foreach ($target in $withSize) {
                Write-WinForgeKeyValue -Label $target.Label -Value (Format-WinForgeBytes -Bytes $target.Size) -LabelWidth 36
            }

            foreach ($target in $withSize) { $sum += [int64]$target.Size }

            Write-Host ""

            # Com itens sem medir, o total é só o piso do que dá para liberar.
            $lead = $(if ($unmeasured.Count -gt 0) { (Get-WinForgeText 'Pelo menos') } else { (Get-WinForgeText 'Até') })
            Write-WinForgeStatus -Type Info -Message (Get-WinForgeText '{0} {1} podem ser liberados em Limpeza > Limpeza personalizada.' "$lead" "$(Format-WinForgeBytes -Bytes $sum)")
        }

        Write-WinForgeSection -Title (Get-WinForgeText 'Maiores pastas do seu perfil')

        $folders = @(Get-WinForgeUserFolderSizes)
        $filled = @($folders | Where-Object { $_.Size -gt 0 })

        if ($folders.Count -eq 0) {
            Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'Não foi possível ler as pastas do perfil.')
        }
        elseif ($filled.Count -eq 0) {
            Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'As pastas do perfil estão vazias.')
        }
        else {
            foreach ($folder in $filled) {
                Write-WinForgeKeyValue -Label $folder.Name -Value (Format-WinForgeBytes -Bytes $folder.Size) -LabelWidth 36
            }
        }

        Write-WinForgeSection -Title (Get-WinForgeText 'Arquivos grandes do sistema')

        $shown = 0

        foreach ($entry in @(Get-WinForgeSystemSpaceFiles)) {
            if ($entry.Unreadable) {
                Write-WinForgeKeyValue -Label $entry.Label -Value (Get-WinForgeText 'não foi possível medir') -LabelWidth 36
                $unmeasured.Add($entry.Label)
                $shown++
                continue
            }

            if ($null -eq $entry.Size) { continue }

            $line = Format-WinForgeBytes -Bytes $entry.Size -ZeroText "0 B"
            if ($entry.Hint) { $line += " · $($entry.Hint)" }

            Write-WinForgeKeyValue -Label $entry.Label -Value $line -LabelWidth 36
            $shown++
        }

        if ($shown -eq 0) {
            Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Nenhum arquivo grande do sistema foi encontrado.')
        }

        Write-Host ""

        if ($unmeasured.Count -gt 0) {
            # Sem Administrador isso é esperado (Windows.old, SoftwareDistribution e a pasta Temp do sistema não deixam ler);
            # como Administrador, é um problema de verdade.
            $isAdmin = Test-WinForgeAdministrator
            $type = $(if ($isAdmin) { "Warning" } else { "Info" })

            Write-WinForgeStatus -Type $type -Message (Get-WinForgeText 'Não foi possível medir: {0}.' "$(Join-WinForgeList -Items @($unmeasured))")

            if (-not $isAdmin) {
                Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Para incluir as pastas do sistema, feche o WinForge, abra de novo e aceite o aviso do Windows.')
            }
        }

        # Os tamanhos são estimativas: arquivos sem permissão de leitura não entram na soma.

        # A faixa da janela: o espaço livre como título (amarelo com pouco espaço), o que a limpeza libera embaixo e o botão
        # para a Limpeza personalizada, que é onde se escolhe o que tirar. Antes, a análise terminava sem faixa.
        $lead = $(if ($unmeasured.Count -gt 0) { (Get-WinForgeText 'Pelo menos') } else { (Get-WinForgeText 'Até') })
        $note = $(if ($sum -gt 0) { (Get-WinForgeText '{0} {1} podem ser liberados na Limpeza personalizada.' "$lead" "$(Format-WinForgeBytes -Bytes $sum)") } elseif ($unmeasured.Count -eq 0) { (Get-WinForgeText 'Não há temporários, relatórios nem caches acumulados.') } else { "" })
        if ($unmeasured.Count -gt 0) { $note = ((Get-WinForgeText '{0} Não foi possível medir: {1}.' "$note" "$(Join-WinForgeList -Items @($unmeasured))")).Trim() }

        # Sem o disco do sistema, ou sem medir o que um Administrador mede, é ressalva (como os avisos da tela).
        $kind = $(if (-not $headline -or ($unmeasured.Count -gt 0 -and (Test-WinForgeAdministrator))) { "Warning" } else { "Ok" })
        $result = New-WinForgeResult -Kind $kind -Detail $(if ($headline) { $headline } else { (Get-WinForgeText 'disco do sistema não lido') }) -Data @{ CleanableBytes = $sum }

        # Sem a leitura do disco, o título diz isso, e o resto da faixa (o que a limpeza libera e o botão) continua valendo.
        $tone = $(if ($diskLevel -in @("Critical", "Low")) { "Warn" } elseif ($kind -eq "Warning") { "Warn" } else { "" })
        [void](Set-WinForgeResultView -Result $result -Headline $(if ($headline) { $headline } else { (ConvertTo-WinForgeHeadline -Text (Get-WinForgeText 'disco do sistema não lido')) }) -Note $note -Tone $tone `
                -Next $(if ($sum -gt 0) { "cleanup.custom" } else { "" }) -NextLabel $(if ($sum -gt 0) { (Get-WinForgeText 'Abrir a Limpeza personalizada') } else { "" }))
    }
    catch {
        Write-WinForgeStatus -Type Error -Message (Get-WinForgeText 'Ocorreu um erro ao analisar o espaço: {0}' "$($_.Exception.Message)")
        $result = New-WinForgeResult -Kind Failed -Detail $_.Exception.Message
    }

    $result.Etapa = $title
    Exit-WinForgeAction -Result $result
}


function Invoke-WinForgeCustomCleanup {
    $title = (Get-WinForgeText 'Limpeza personalizada')

    Enter-WinForgeAction -Title $title

    # Uma saída só, no fim: cada caminho deixa aqui o resultado que a faixa mostra.
    $result = $null

    try {
        if (-not (Test-WinForgeElevation -Reason (Get-WinForgeText 'A limpeza personalizada exige privilégios de Administrador.'))) {
            $result = New-WinForgeResult -Kind Failed -Detail (Get-WinForgeText 'requer Administrador')
        }

        $available = @()

        if ($null -eq $result) {
            $available = @(Measure-WinForgeCleanupTargets | Where-Object { Test-WinForgeCleanupTargetAvailable -Target $_ })

            if ($available.Count -eq 0) {
                Write-WinForgeStatus -Type Success -Message (Get-WinForgeText 'Não há nada acumulado para limpar.')
                $result = New-WinForgeResult -Kind Skipped -Detail (Get-WinForgeText 'não há nada acumulado') -Data @{ FreedBytes = [int64]0 }
                [void](Set-WinForgeResultView -Result $result -Headline (Get-WinForgeText 'Nada para limpar') -Note (Get-WinForgeText 'Não há temporários, relatórios nem caches acumulados.'))
            }
        }

        $chosen = @()

        if ($null -eq $result) {
            # Antes da lista: na janela, a pergunta de marcar deixa os detalhes técnicos recolhidos, e esta linha fica no resumo.
            Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Suas pastas pessoais não são tocadas.')
            [void](Write-WinForgeOtherAccountNotice -What 'os temporários do usuário, os caches dos navegadores e a Lixeira')
            Write-Host ""

            $options = @(
                foreach ($target in $available) {
                    $sizeText = $(if ($null -ne $target.Size) { Format-WinForgeBytes -Bytes $target.Size -ZeroText "0 B" } else { (Get-WinForgeText 'tamanho desconhecido') })
                    @{ Key = $target.Id; Label = "$($target.Label) · $sizeText"; Description = $target.Description; Selected = $target.Selected }
                }
            )

            $picked = @(Read-WinForgeMultiSelect -Message (Get-WinForgeText 'Escolha o que deseja limpar') -Options $options)
            $chosen = @($available | Where-Object { $picked -contains $_.Id })

            if ($chosen.Count -eq 0) {
                Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'Nada foi marcado; nenhuma limpeza foi feita.')
                $result = New-WinForgeResult -Kind Skipped -Detail (Get-WinForgeText 'nada marcado')
            }
        }

        if ($null -eq $result) {
            $estimate = [int64]0
            $unknown = 0

            foreach ($target in $chosen) {
                if ($null -ne $target.Size) { $estimate += [int64]$target.Size } else { $unknown++ }
            }

            # Com algo sem tamanho conhecido, o que foi medido é o mínimo; sem nada medido, não há número a dar.
            $sizeText = $(
                if ($unknown -eq $chosen.Count) { "" }
                elseif ($unknown -gt 0) { (Get-WinForgeText ' (pelo menos {0})' "$(Format-WinForgeBytes -Bytes $estimate -ZeroText '0 B')") }
                else { (Get-WinForgeText ' (cerca de {0})' "$(Format-WinForgeBytes -Bytes $estimate -ZeroText '0 B')") }
            )
            $what = $(if ($chosen.Count -eq 1) { (Get-WinForgeText 'o item marcado') } else { (Get-WinForgeText 'os {0} itens marcados' "$($chosen.Count)") })

            # A Lixeira e os despejos de memória não voltam (o resto o Windows e os programas recriam): com eles marcados, um
            # aviso antes da pergunta, e Não como padrão.
            $chosenIds = @($chosen | ForEach-Object { [string]$_.Id })
            $binChosen = ($chosenIds -contains "recycle-bin")
            $dumpsChosen = ($chosenIds -contains "crash-dumps")
            # Frases inteiras (e não pedaços juntados): a concordância muda de um idioma para outro.
            $noReturnText = $(
                if ($binChosen -and $dumpsChosen) { (Get-WinForgeText 'O que está na Lixeira e os despejos de memória de falhas são apagados em definitivo, sem volta.') }
                elseif ($binChosen) { (Get-WinForgeText 'O que está na Lixeira é apagado em definitivo, sem volta.') }
                elseif ($dumpsChosen) { (Get-WinForgeText 'Os despejos de memória de falhas são apagados em definitivo, sem volta.') }
                else { "" }
            )

            Write-Host ""

            if ($noReturnText) {
                Write-WinForgeStatus -Type Warning -Notice -Message $noReturnText
            }

            if (-not (Confirm-WinForgeAction (Get-WinForgeText 'Limpar {0}{1}?' "$what" "${sizeText}") -DefaultKey $(if ($noReturnText) { "N" } else { "S" }) -Danger:([bool]$noReturnText) -YesLabel (Get-WinForgeText 'Limpar') -NoLabel (Get-WinForgeText 'Cancelar'))) {
                Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'Limpeza cancelada.')
                $result = New-WinForgeResult -Kind Skipped -Detail (Get-WinForgeText 'cancelado pelo usuário')
            }
            else {
                $result = Invoke-WinForgeCleanupTargets -Targets $chosen

                # A faixa diz quanto voltou ao disco e de onde, como a Limpeza rápida (antes, "Concluído" e "liberou X"). Sem
                # nada liberado, diz por quê: o que saiu estava vazio, ou não pôde ser medido.
                $customFreed = [int64](Get-WinForgeResultData -Result $result -Name "FreedBytes")
                $customUnmeasured = @(Get-WinForgeResultData -Result $result -Name "Unmeasured" | Where-Object { $_ })

                if ([string]$result.Kind -eq "Ok" -and $customFreed -gt 0) {
                    $note = "$(Join-WinForgeList -Items @($chosen | ForEach-Object { [string]$_.Label }))."
                    if ($customUnmeasured.Count -gt 0) { $note += (Get-WinForgeText ' O total não inclui {0}.' "$(Join-WinForgeList -Items $customUnmeasured)") }
                    [void](Set-WinForgeResultView -Result $result -Headline (Get-WinForgeText '{0} liberados' "$(Format-WinForgeBytes -Bytes $customFreed)") -Note $note)
                }
                elseif ([string]$result.Kind -eq "Ok") {
                    [void](Set-WinForgeResultView -Result $result -Headline (Get-WinForgeText 'Limpeza concluída') -Note (Get-WinForgeCleanupZeroNote -Unmeasured $customUnmeasured))
                }
            }
        }
    }
    catch {
        Write-WinForgeStatus -Type Error -Message (Get-WinForgeText 'Ocorreu um erro na limpeza: {0}' "$($_.Exception.Message)")
        $result = New-WinForgeResult -Kind Failed -Detail $_.Exception.Message
    }

    $result.Etapa = $title
    Exit-WinForgeAction -Result $result
}


function Invoke-WinForgeCleanupTargets {
    <#
    Limpa os alvos escolhidos na limpeza personalizada, um por seção, e mostra o balanço. A Lixeira é esvaziada com o que
    a medição já encontrou (sem percorrê-la de novo) e o que ela liberou entra no total. Devolve o WinForge.Result.
    #>
    param (
        [Parameter(Mandatory)]
        [object[]]$Targets,

        # Sem a seção Resumo no fim: quem chama (a Verificação do PC) mostra o próprio resumo.
        [switch]$NoSummary
    )

    $freed = [int64]0
    $skippedItems = 0
    $problems = New-Object System.Collections.Generic.List[string]

    # O que foi limpo sem medida (a Lixeira que não pôde ser medida, o cache que o Windows esvaziou numa pasta ilegível):
    # o total não o inclui, e a faixa diz isso em vez de "nada foi liberado".
    $unmeasured = New-Object System.Collections.Generic.List[string]

    foreach ($target in $Targets) {
        if ($target.RecycleBin) {
            # Esvaziar a Lixeira escreve o próprio título de seção.
            $part = Clear-WinForgeRecycleBin -Embedded -PassThru -Contents $target.BinContents
            $partFreed = Get-WinForgeResultData -Result $part -Name "FreedBytes"

            if ($null -ne $partFreed) { $freed += [int64]$partFreed }
            elseif ($part.Kind -ne "Failed") { $unmeasured.Add($target.Label) }
            if ($part.Kind -eq "Failed") { $problems.Add($target.Label) }
            continue
        }

        Write-WinForgeSection -Title $target.Label

        $targetFreed = [int64]0
        $removed = 0
        $skipped = 0
        $errors = 0

        # A Otimização de Entrega tem um comando próprio para esvaziar o cache (Delete-DeliveryOptimizationCache): o
        # serviço tira os arquivos e atualiza o que sabe deles. Apagar por fora deixa o serviço contando com o que sumiu.
        # Sem o comando (Windows antigo) ou com erro nele, vale a limpeza da pasta.
        if ($target.Id -eq "delivery-optimization" -and (Get-Command -Name "Delete-DeliveryOptimizationCache" -ErrorAction SilentlyContinue)) {
            # Medido antes e depois. Sem a pasta no lugar de sempre (uma política pode tê-la mudado) ou sem leitura, o
            # que saiu não é conhecido, e "Liberou 0 B" seria mentira.
            $measured = $true
            $before = [int64]0

            foreach ($path in @($target.Paths)) {
                $size = $(if (Test-Path -LiteralPath $path -PathType Container) { Get-WinForgeFolderSize -Path $path } else { $null })
                if ($null -eq $size) { $measured = $false } else { $before += $size }
            }

            try {
                [void](Delete-DeliveryOptimizationCache -Force -ErrorAction Stop)

                $after = [int64]0
                foreach ($path in @($target.Paths)) { $size = Get-WinForgeFolderSize -Path $path; if ($null -ne $size) { $after += $size } }

                if ($measured) {
                    $targetFreed = [Math]::Max([int64]0, $before - $after)
                    $freed += $targetFreed
                    Write-WinForgeStatus -Type Success -Message (Get-WinForgeText 'Liberou {0}.' "$(Format-WinForgeBytes -Bytes $targetFreed -ZeroText '0 B')")
                }
                else {
                    Write-WinForgeStatus -Type Success -Message (Get-WinForgeText 'O Windows esvaziou o cache; o espaço liberado não pôde ser medido.')
                    $unmeasured.Add($target.Label)
                }

                continue
            }
            catch {
                # Sem o comando do Windows, a pasta é limpa diretamente, logo abaixo: para a pessoa, o resultado é o mesmo.
                Write-Verbose "O comando do Windows não esvaziou o cache ($($_.Exception.Message.TrimEnd('.'))); a pasta é limpa diretamente."
            }
        }

        foreach ($path in @($target.Paths)) {
            if (-not (Test-Path -LiteralPath $path -PathType Container)) { continue }

            # As pastas TEMP vêm de variáveis de ambiente que podem estar erradas: precisam se chamar Temp. As outras
            # (caches, relatórios) são caminhos fixos montados pelo WinForge.
            if (-not (Test-WinForgeTempFolderSafe -Path $path -RequireTempName:($target.Id -in @("user-temp", "windows-temp")))) {
                Write-WinForgeStatus -Type Error -Message (Get-WinForgeText 'Pasta recusada por segurança: {0}' "$path")
                $errors++
                continue
            }

            try {
                $outcome = Clear-WinForgeFolderContents -Path $path -Activity $target.Label -MinAgeHours ([int](Get-WinForgeJsonValue -Object $target -Name "MinAgeHours" -Default 0))
                $targetFreed += [int64]$outcome.Freed
                $removed += [int]$outcome.Removed
                $skipped += [int]$outcome.Skipped
            }
            catch {
                Write-WinForgeStatus -Type Error -Message "${path}: $($_.Exception.Message)"
                $errors++
            }
        }

        foreach ($file in @(Get-WinForgeJsonValue -Object $target -Name "Files" -Default @())) {
            $item = Get-Item -LiteralPath $file -Force -ErrorAction SilentlyContinue
            if ($null -eq $item -or $item.PSIsContainer) { continue }

            $size = [int64]$item.Length

            try {
                Remove-WinForgeItem -Path $file
                $targetFreed += $size
                $removed++
            }
            catch {
                if ($null -ne (Get-Item -LiteralPath $file -Force -ErrorAction SilentlyContinue)) { $skipped++ }
            }
        }

        $freed += $targetFreed

        if ($removed -eq 0 -and $skipped -gt 0) {
            # Tudo em uso: não houve limpeza, e "liberou 0 B" em verde esconderia isso.
            $hint = $(if ($target.Id -eq "browser-cache") { (Get-WinForgeText 'feche os navegadores e tente de novo') } else { (Get-WinForgeText 'feche os programas abertos e tente de novo') })
            Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'Nenhum item pôde ser removido: estavam em uso; {0}.' "$hint")
            $problems.Add($target.Label)
        }
        elseif ($errors -gt 0) {
            if ($removed -gt 0) { Write-WinForgeStatus -Type Success -Message (Get-WinForgeText 'Liberou {0} no que pôde ser limpo.' "$(Format-WinForgeBytes -Bytes $targetFreed -ZeroText '0 B')") }
            $problems.Add($target.Label)
        }
        else {
            Write-WinForgeStatus -Type Success -Message (Get-WinForgeText 'Liberou {0}.' "$(Format-WinForgeBytes -Bytes $targetFreed -ZeroText '0 B')")

            # Alguns itens em uso numa parte que foi limpa são o normal; uma parte em que nada saiu já teve o seu aviso.
            $skippedItems += $skipped
        }
    }

    $freedText = Format-WinForgeBytes -Bytes $freed -ZeroText "0 B"

    if (-not $NoSummary) {
        Write-WinForgeSection -Title (Get-WinForgeText 'Resumo')
        Write-WinForgeKeyValue -Label (Get-WinForgeText 'Espaço liberado') -Value $freedText
    }

    if ($skippedItems -gt 0) {
        Write-WinForgeStatus -Type Info -Message (Get-WinForgeText '{0}; isso é esperado.' "$(if ($skippedItems -eq 1) { (Get-WinForgeText '1 item em uso ficou') } else { (Get-WinForgeText '{0} itens em uso ficaram' "$skippedItems") })")
    }

    $data = @{ FreedBytes = $freed; Unmeasured = @($unmeasured) }

    if ($problems.Count -gt 0 -and $freed -eq 0) {
        return New-WinForgeResult -Kind Warning -Detail (Get-WinForgeText 'nada foi liberado; com problema: {0}' "$(Join-WinForgeList -Items @($problems))") -Data $data
    }

    if ($problems.Count -gt 0) {
        return New-WinForgeResult -Kind Warning -Detail (Get-WinForgeText 'liberou {0}; com problema: {1}' "$freedText" "$(Join-WinForgeList -Items @($problems))") -Data $data
    }

    return New-WinForgeResult -Kind Ok -Detail (Get-WinForgeText 'liberou {0}' "$freedText") -Data $data
}


function Get-WinForgeCleanupPageStatus {
    <#
    O resumo no alto da página Limpeza: o espaço livre no disco do Windows, com a regra de "pouco espaço" da tela inicial.
    Cada linha tem Label, Text, Level (Normal | Warn | Muted) e Opens. Só lê o tamanho da unidade, que é imediato.
    Com pouco espaço, a linha é um botão que abre a Limpeza personalizada (Opens): o mesmo caminho do "Liberar espaço" do
    Início, da Verificação do PC e do aviso do monitor, porque ela mede tudo o que dá para tirar e já vem com o que o
    Windows refaz sozinho marcado. Antes, a faixa dizia "comece pela Limpeza rápida", que só tira os temporários.
    #>
    $space = $null

    try {
        $space = Get-WinForgeSystemDriveSpace
    }
    catch {
        $space = $null
    }

    if ($null -eq $space -or $space.TotalBytes -le 0) {
        return @([PSCustomObject]@{ Label = (Get-WinForgeText 'Disco do sistema'); Text = (Get-WinForgeText 'não foi possível ler'); Level = "Muted"; Opens = "" })
    }

    $text = (Get-WinForgeText '{0} livres de {1}' "$(Format-WinForgeBytes -Bytes $space.FreeBytes -ZeroText '0 B')" "$(Format-WinForgeBytes -Bytes $space.TotalBytes)")
    $level = "Normal"
    $opens = ""

    switch (Get-WinForgeDiskSpaceLevel -FreeBytes $space.FreeBytes -TotalBytes $space.TotalBytes) {
        "Critical" { $text += (Get-WinForgeText ' · quase cheio'); $level = "Warn"; $opens = "cleanup.custom" }
        "Low" { $text += (Get-WinForgeText ' · pouco espaço'); $level = "Warn"; $opens = "cleanup.custom" }
    }

    return @([PSCustomObject]@{ Label = (Get-WinForgeText 'Disco do sistema'); Text = $text; Level = $level; Opens = $opens })
}


Export-ModuleMember -Function *
