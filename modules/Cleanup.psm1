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
    um aviso antes da pergunta (Test-WinForgeUserContextMismatch). What diz o quê ("os temporários e a Lixeira"); o
    artigo do começo faz a frase concordar. Devolve $true quando avisou.
    #>
    param ([Parameter(Mandatory)][string]$What)

    if (-not (Test-WinForgeUserContextMismatch)) { return $false }

    $account = $(if (-not [string]::IsNullOrWhiteSpace($env:USERNAME)) { $env:USERNAME } else { [Environment]::UserName })

    $predicate = switch (($What.Trim() -split ' ', 2)[0].ToLowerInvariant()) {
        "as" { "são as dessa conta, não as" }
        "a" { "é a dessa conta, não a" }
        "o" { "é o dessa conta, não o" }
        default { "são os dessa conta, não os" }
    }

    Write-WinForgeStatus -Type Warning -Notice -Message "O WinForge está aberto com outra conta ($account): $What $predicate de quem está usando o Windows."
    return $true
}


# ---------------------------------------------------------------------------
# Exclusão segura
# ---------------------------------------------------------------------------

function Remove-WinForgeItem {
    <#
    Remove um arquivo ou pasta. Atalhos de pasta (junção/link simbólico) são removidos como atalho, sem tocar no
    conteúdo de destino: o Windows PowerShell 5.1 pode seguir o link em Remove-Item -Recurse e apagar o que está fora
    da pasta limpa. Em pastas, apaga o que for possível e lança erro se algum item continuar em uso.
    #>
    param (
        [Parameter(Mandatory)]
        [string]$Path
    )

    $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop

    if (-not $item.PSIsContainer) {
        if ($item.IsReadOnly) {
            $item.IsReadOnly = $false
        }

        $item.Delete()
        return
    }

    if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
        $item.Delete()
        return
    }

    $failed = $false

    foreach ($child in @($item.EnumerateFileSystemInfos())) {
        try {
            Remove-WinForgeItem -Path $child.FullName
        }
        catch {
            $failed = $true
        }
    }

    if ($failed) {
        throw "Há itens em uso em '$($item.Name)'."
    }

    if (($item.Attributes -band [System.IO.FileAttributes]::ReadOnly) -ne 0) {
        $item.Attributes = $item.Attributes -band (-bnot [System.IO.FileAttributes]::ReadOnly)
    }

    $item.Delete()
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
        return "não fica numa unidade que o WinForge consiga identificar"
    }

    if ($text.StartsWith("\\") -or $text.StartsWith("//")) {
        return "fica numa pasta de rede, que não tem Lixeira"
    }

    try {
        $root = [IO.Path]::GetPathRoot([IO.Path]::GetFullPath($text))
    }
    catch {
        $root = ""
    }

    if ([string]::IsNullOrWhiteSpace($root) -or $root.StartsWith("\\")) {
        return "não fica numa unidade que o WinForge consiga identificar"
    }

    $drive = $root.TrimEnd([char[]]@('\', '/'))
    if ([string]::IsNullOrEmpty($drive)) { $drive = $root }

    switch (Get-WinForgeDriveType -Root $root) {
        "Fixed" {
            if ((Get-WinForgeRecycleBinCapacity -Root $root).Nuke) { return "fica em $drive, onde a Lixeira está configurada para apagar na hora" }
            return ""
        }
        "Network" { return "fica numa unidade de rede ($drive), que não tem Lixeira" }
        "Removable" { return "fica num pendrive ou cartão de memória ($drive), que não tem Lixeira" }
        "CDRom" { return "fica num CD ou DVD ($drive), que não tem Lixeira" }
    }

    return "fica numa unidade sem Lixeira ou que não foi possível identificar ($drive)"
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
        throw "$problem; o Windows apagaria em definitivo, então ficou onde estava"
    }

    $limit = [int64](Get-WinForgeRecycleBinCapacity -Root ([IO.Path]::GetPathRoot([IO.Path]::GetFullPath($Path)))).MaxBytes

    if ($limit -gt 0) {
        if ($SizeBytes -lt 0) {
            $SizeBytes = $(if ($IsDirectory) { [int64](Get-WinForgePathStats -Path $Path).Size } else { [int64](Get-Item -LiteralPath $Path -Force -ErrorAction Stop).Length })
        }

        if ($SizeBytes -gt $limit) {
            throw "tem $(Format-WinForgeBytes -Bytes $SizeBytes) e passa do limite da Lixeira desta unidade ($(Format-WinForgeBytes -Bytes $limit)): o Windows apagaria em definitivo, então ficou onde estava"
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

    Write-Progress -Activity $Activity -Status "$(Format-WinForgeNumber -Value $Current) de $(Format-WinForgeNumber -Value $Total)" -PercentComplete $percent
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

        [string]$Activity = "Limpando",

        [object[]]$Entries,

        # Itens com atividade mais recente que isto (em horas) ficam, e são contados em Recent. 0 = sem limite.
        [int]$MinAgeHours = 0
    )

    if (-not $PSBoundParameters.ContainsKey("Entries")) {
        $listing = Get-WinForgeFolderListing -Path $Path

        if (-not $listing.Readable) {
            throw "Não foi possível ler a pasta: $($listing.Reason)"
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

    if ($Hours -eq 24) { return "um dia" }
    if ($Hours -gt 0 -and $Hours % 24 -eq 0) { return (Format-WinForgeCount -Count ($Hours / 24) -One "dia" -Many "dias") }

    return (Format-WinForgeCount -Count $Hours -One "hora" -Many "horas")
}


function Invoke-WinForgeFolderCleanup {
    param (
        [Parameter(Mandatory)]
        [string]$Title,

        # Vazio quando a variável de ambiente que localiza a pasta não existe: a ação explica em vez de falhar.
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Path,

        [string[]]$Notes = @(),

        # Itens mais novos que isto (em horas) ficam; 0 = limpa tudo.
        [int]$MinAgeHours = 0,

        [switch]$Embedded,
        [switch]$PassThru
    )

    Enter-WinForgeAction -Title $Title -Embedded:$Embedded

    $result = $null

    try {
        if ([string]::IsNullOrWhiteSpace($Path)) {
            Write-WinForgeStatus -Type Error -Message "Não foi possível localizar a pasta a limpar (variável de ambiente ausente)."
            $result = New-WinForgeResult -Kind Failed -Detail "pasta não localizada"
        }
        elseif (-not (Test-WinForgeTempFolderSafe -Path $Path -RequireTempName)) {
            # Uma pasta de temporários precisa se chamar Temp e não pode ser uma raiz de disco, conter o perfil, o Windows ou
            # os dados dos programas (AppData), nem ficar numa pasta pessoal ou na pasta do WinForge.
            Write-WinForgeStatus -Type Error -Message "Pasta recusada por segurança: $Path"
            Write-WinForgeStatus -Type Info -Message "Ela não parece uma pasta de temporários: verifique a variável de ambiente TEMP."
            $result = New-WinForgeResult -Kind Failed -Detail "pasta recusada por segurança"
        }
        elseif (-not (Test-Path -LiteralPath $Path -PathType Container)) {
            Write-WinForgeStatus -Type Warning -Message "Pasta não encontrada: $Path"
            $result = New-WinForgeResult -Kind Skipped -Detail "pasta não encontrada" -Data @{ FreedBytes = [int64]0 }
        }
        else {
            $listing = Get-WinForgeFolderListing -Path $Path

            if (-not $listing.Readable) {
                # Sem conseguir listar, "vazia" seria um palpite: a pasta pode estar cheia e só não ser permitida.
                Write-WinForgeStatus -Type Error -Message "Não foi possível ler a pasta: $($listing.Reason)"
                Write-WinForgeStatus -Type Info -Message "Se a pasta for do sistema, feche o WinForge, abra de novo e aceite o aviso do Windows."
                $result = New-WinForgeResult -Kind Failed -Detail "pasta ilegível"
            }
            else {
                Write-Progress -Activity $Title -Status "medindo a pasta"
                $all = @(Measure-WinForgeFolderItems -Items $listing.Items)
                Write-Progress -Activity $Title -Completed

                # Só o que passou do tempo mínimo entra na conta: o resto fica, e a tela diz quanto.
                $entries = $(if ($MinAgeHours -gt 0) { @(Select-WinForgeItemsOlderThan -Entries $all -Cutoff (Get-Date).AddHours(-$MinAgeHours)) } else { $all })
                $recent = $all.Count - @($entries).Count

                $totalBytes = [int64]0
                foreach ($entry in @($entries)) { $totalBytes += [int64]$entry.SizeBytes }

                Write-WinForgeKeyValue -Label "Pasta" -Value $Path
                Write-WinForgeKeyValue -Label "Itens a limpar" -Value (Format-WinForgeNumber -Value @($entries).Count)
                Write-WinForgeKeyValue -Label "Tamanho estimado" -Value (Format-WinForgeBytes -Bytes $totalBytes)
                if ($recent -gt 0) { Write-WinForgeKeyValue -Label "Ficam (recentes)" -Value "$(Format-WinForgeCount -Count $recent -One 'item' -Many 'itens') de menos de $(Get-WinForgeMinAgeText -Hours $MinAgeHours)" }
                Write-Host ""

                if (@($entries).Count -eq 0) {
                    # O que é recente pode ser de um programa ou de uma instalação em andamento: fica.
                    Write-WinForgeStatus -Type Success -Message $(if ($recent -gt 0) { "Não há nada para limpar: o que está na pasta é recente." } else { "Não há nada para limpar nesta pasta." })
                    $result = New-WinForgeResult -Kind Ok -Detail "nada a limpar" -Data @{ FreedBytes = [int64]0 }
                }
                else {
                    # As notas vão antes da pergunta e, na janela, aparecem no resumo: durante uma pergunta de Sim e Não
                    # os detalhes técnicos ficam recolhidos. Dentro da Limpeza rápida (sem pergunta) não se repetem.
                    if (-not $Embedded) {
                        foreach ($note in $Notes) { Write-WinForgeStatus -Type Info -Message $note }
                        if ($Notes.Count -gt 0) { Write-Host "" }
                    }

                    if (-not $Embedded -and -not (Confirm-WinForgeAction "Deseja limpar estes arquivos?" -DefaultKey S)) {
                        Write-WinForgeStatus -Type Warning -Message "Limpeza cancelada."
                        $result = New-WinForgeResult -Kind Skipped -Detail "cancelado pelo usuário"
                    }
                    else {
                        # O andamento vai na barra de progresso (Clear-WinForgeFolderContents); uma linha "Limpando..."
                        # ficaria no resumo como se a limpeza ainda estivesse em curso.
                        # Os recentes, que ficam, já foram contados antes da pergunta ("Ficam (recentes)").
                        $outcome = Clear-WinForgeFolderContents -Path $Path -Activity $Title -Entries @($entries)

                        # Itens em uso são esperados; mas se NADA saiu, a limpeza não aconteceu e "concluída" seria mentira.
                        $nothingRemoved = ($outcome.Removed -eq 0 -and $outcome.Skipped -gt 0)

                        if ($nothingRemoved) {
                            Write-WinForgeStatus -Type Warning -Message "Nenhum item pôde ser removido."
                        }
                        else {
                            Write-WinForgeStatus -Type Success -Message "Limpeza concluída."
                        }

                        Write-WinForgeKeyValue -Label "Itens removidos" -Value (Format-WinForgeNumber -Value $outcome.Removed)
                        if ($outcome.Skipped -gt 0) { Write-WinForgeKeyValue -Label "Em uso (ficaram)" -Value (Format-WinForgeNumber -Value $outcome.Skipped) }
                        Write-WinForgeKeyValue -Label "Espaço liberado" -Value (Format-WinForgeBytes -Bytes $outcome.Freed)

                        if ($nothingRemoved) {
                            Write-Host ""
                            Write-WinForgeStatus -Type Info -Message "Os itens estavam em uso: feche os programas e tente de novo."
                        }
                        elseif ($outcome.Skipped -gt 0) {
                            Write-Host ""
                            Write-WinForgeStatus -Type Info -Message "Os itens em uso ficaram; isso é esperado."
                        }

                        $detail = "liberou $(Format-WinForgeBytes -Bytes $outcome.Freed)"
                        if ($outcome.Skipped -gt 0) { $detail += "; $($outcome.Skipped) em uso" }

                        $kind = $(if ($nothingRemoved) { "Warning" } else { "Ok" })
                        if ($nothingRemoved) { $detail = "nenhum item removido; $($outcome.Skipped) em uso" }

                        $result = New-WinForgeResult -Kind $kind -Detail $detail -Data @{ FreedBytes = [int64]$outcome.Freed }
                    }
                }
            }
        }
    }
    catch {
        Write-WinForgeStatus -Type Error -Message "Ocorreu um erro na limpeza: $($_.Exception.Message)"
        $result = New-WinForgeResult -Kind Failed -Detail $_.Exception.Message
    }

    $result.Etapa = $Title
    Exit-WinForgeAction -Embedded:$Embedded -Result $result

    if ($PassThru) {
        return $result
    }
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
    param (
        [switch]$Embedded,
        [switch]$PassThru
    )

    Invoke-WinForgeFolderCleanup `
        -Title "Limpar temporários do usuário" `
        -Path (Get-WinForgeUserTempPath) `
        -MinAgeHours $script:WinForgeTempMinAgeHours `
        -Notes @("Arquivos em uso e os de menos de um dia ficam.") `
        -Embedded:$Embedded -PassThru:$PassThru
}


function Clear-WinForgeWindowsTemp {
    param (
        [switch]$Embedded,
        [switch]$PassThru
    )

    Invoke-WinForgeFolderCleanup `
        -Title "Limpar temporários do Windows" `
        -Path (Get-WinForgeWindowsTempPath) `
        -MinAgeHours $script:WinForgeTempMinAgeHours `
        -Notes @("Arquivos em uso e os de menos de um dia ficam.") `
        -Embedded:$Embedded -PassThru:$PassThru
}


# ---------------------------------------------------------------------------
# Lixeira
# ---------------------------------------------------------------------------

function Set-WinForgeRecycleBinNext {
    <#
    A faixa de uma ferramenta que mandou itens para a Lixeira (Downloads, duplicados, restos de programas): o título diz
    quantos foram, a frase diz que o espaço só volta ao esvaziá-la, e o botão Esvaziar a Lixeira leva direto à tela que
    faz isso (antes, só o texto apontava o caminho). Só no resultado sem ressalvas; devolve o próprio resultado.
    #>
    param (
        [Parameter(Mandatory)]
        $Result,

        [int]$Count,
        [int64]$Bytes = 0,
        [string]$One = "item",
        [string]$Many = "itens"
    )

    if ([string]$Result.Kind -ne "Ok" -or $Count -le 0) { return $Result }

    $note = $(if ($Bytes -gt 0) { "$(Format-WinForgeBytes -Bytes $Bytes) voltam ao disco ao esvaziar a Lixeira." } else { "O espaço volta ao disco ao esvaziar a Lixeira." })

    return (Set-WinForgeResultView -Result $Result -Headline "$(Format-WinForgeCount -Count $Count -One $One -Many $Many) na Lixeira" -Note $note -Next "cleanup.recycle-bin" -NextLabel "Esvaziar a Lixeira")
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
        return "vazia"
    }

    return "$(Format-WinForgeCount -Count ([int]$Contents.Count) -One 'item' -Many 'itens'), $(Format-WinForgeBytes -Bytes $Contents.SizeBytes)"
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
        $Message -match "O sistema não pode encontrar"
    )
}


function Clear-WinForgeRecycleBin {
    param (
        [switch]$Embedded,
        [switch]$PassThru,

        # O que quem chama já mediu na Lixeira (Count e SizeBytes): evita percorrê-la de novo.
        $Contents = $null
    )

    $title = "Esvaziar a Lixeira"

    Enter-WinForgeAction -Title $title -Embedded:$Embedded

    $result = $null

    try {
        if ($null -eq $Contents) {
            Write-Progress -Activity $title -Status "medindo o que está na Lixeira"
            $Contents = Get-WinForgeRecycleBinContents
            Write-Progress -Activity $title -Completed
        }

        if ($null -ne $Contents -and [int]$Contents.Count -eq 0) {
            Write-WinForgeStatus -Type Success -Message "A Lixeira já está vazia."
            $result = New-WinForgeResult -Kind Ok -Detail "já estava vazia" -Data @{ FreedBytes = [int64]0 }
        }
        else {
            if ($null -ne $Contents) {
                Write-WinForgeKeyValue -Label "Na Lixeira" -Value (Format-WinForgeRecycleBinText -Contents $Contents)
            }
            else {
                Write-WinForgeStatus -Type Info -Message "Não foi possível medir a Lixeira; ela será esvaziada mesmo assim."
            }

            if (-not $Embedded) {
                # Um aviso antes da pergunta, que na janela fica no resumo, acima dos botões. Não é ressalva do resultado.
                Write-WinForgeStatus -Type Warning -Notice -Message "Esvazia a Lixeira de todas as unidades: os itens são removidos em definitivo."
                Write-WinForgeStatus -Type Info -Message "Para salvar algo antes, abra a Lixeira e use Restaurar."
                [void](Write-WinForgeOtherAccountNotice -What "a Lixeira")
                Write-Host ""
            }

            if (-not $Embedded -and -not (Confirm-WinForgeAction "Deseja esvaziar a Lixeira?" -DefaultKey N)) {
                Write-WinForgeStatus -Type Warning -Message "Operação cancelada."
                $result = New-WinForgeResult -Kind Skipped -Detail "cancelado pelo usuário"
            }
            else {
                try {
                    Write-Progress -Activity $title -Status "esvaziando"

                    try {
                        Clear-RecycleBin -Force -ErrorAction Stop
                    }
                    finally {
                        Write-Progress -Activity $title -Completed
                    }

                    Write-WinForgeStatus -Type Success -Message "Lixeira esvaziada."

                    # O espaço liberado é o que foi medido antes (o Windows esvazia a Lixeira inteira de uma vez).
                    if ($null -ne $Contents) {
                        Write-WinForgeKeyValue -Label "Espaço liberado" -Value (Format-WinForgeBytes -Bytes $Contents.SizeBytes)
                        $result = New-WinForgeResult -Kind Ok -Detail "liberou $(Format-WinForgeBytes -Bytes $Contents.SizeBytes)" -Data @{ FreedBytes = [int64]$Contents.SizeBytes }
                    }
                    else {
                        $result = New-WinForgeResult -Kind Ok -Detail "Lixeira esvaziada"
                    }
                }
                catch {
                    if (Test-WinForgeRecycleBinEmptyError -Message $_.Exception.Message -HResult $_.Exception.HResult) {
                        Write-WinForgeStatus -Type Success -Message "A Lixeira já estava vazia."
                        $result = New-WinForgeResult -Kind Ok -Detail "já estava vazia" -Data @{ FreedBytes = [int64]0 }
                    }
                    else {
                        Write-WinForgeStatus -Type Error -Message "Falha ao esvaziar a Lixeira: $($_.Exception.Message)"
                        $result = New-WinForgeResult -Kind Failed -Detail $_.Exception.Message
                    }
                }
            }
        }
    }
    catch {
        Write-WinForgeStatus -Type Error -Message "Ocorreu um erro ao esvaziar a Lixeira: $($_.Exception.Message)"
        $result = New-WinForgeResult -Kind Failed -Detail $_.Exception.Message
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

    $title = "Limpeza rápida"

    Enter-WinForgeAction -Title $title -Embedded:$Embedded

    $result = $null

    try {
        $proceed = $true
        $binContents = $null
        $nothing = $false

        if (-not $Embedded) {
            # O que vai acontecer, antes da pergunta: na janela, isto é o que aparece acima dos botões. Os temporários de
            # menos de um dia e os arquivos em uso ficam.
            Write-WinForgeStatus -Type Info -Message "Limpa os temporários do usuário e do Windows; seus arquivos pessoais não são tocados."
            [void](Write-WinForgeOtherAccountNotice -What $(if ($SkipRecycleBin) { "os temporários do usuário" } else { "os temporários do usuário e a Lixeira" }))

            # O que sai, medido antes da pergunta: a pessoa confirma sabendo quanto, e sem nada para tirar nem há pergunta.
            Write-Progress -Activity $title -Status "medindo os temporários"
            $tempEstimate = Measure-WinForgeTempCleanup

            if (-not $SkipRecycleBin) {
                Write-Progress -Activity $title -Status "medindo o que está na Lixeira"
                $binContents = Get-WinForgeRecycleBinContents
            }

            Write-Progress -Activity $title -Completed

            $tempText = $(
                if ($tempEstimate.Count -gt 0) { "$(Format-WinForgeBytes -Bytes $tempEstimate.Bytes -ZeroText '0 B') · $(Format-WinForgeCount -Count $tempEstimate.Count -One 'item' -Many 'itens')$(if ($tempEstimate.Unknown) { ' (uma pasta não pôde ser medida)' })" }
                elseif ($tempEstimate.Unknown) { "não foi possível medir" }
                else { "nada para limpar" }
            )
            Write-WinForgeKeyValue -Label "Temporários" -Value $tempText

            $binEmpty = ($null -ne $binContents -and [int]$binContents.Count -eq 0)
            if (-not $SkipRecycleBin) {
                Write-WinForgeKeyValue -Label "Na Lixeira" -Value $(if ($null -eq $binContents) { "não foi possível medir" } elseif ($binEmpty) { "vazia" } else { Format-WinForgeRecycleBinText -Contents $binContents })
            }

            $nothing = ($tempEstimate.Count -eq 0 -and -not $tempEstimate.Unknown -and ($SkipRecycleBin -or $binEmpty))

            if ($nothing) {
                # Nada a tirar: sem pergunta, e sem um "Tudo certo: liberou 0 B" depois de um Sim.
                Write-Host ""
                Write-WinForgeStatus -Type Success -Message "Não há nada para limpar: os temporários estão vazios ou são recentes$(if (-not $SkipRecycleBin) { ', e a Lixeira está vazia' })."
                $proceed = $false
            }
            elseif ($SkipRecycleBin -or $binEmpty) {
                Write-Host ""
                $proceed = Confirm-WinForgeAction "Limpar os temporários agora?" -DefaultKey S
            }
            else {
                # O que está na Lixeira antes de esvaziá-la: é o único passo que não tem volta, e a pessoa escolhe. O padrão
                # (ENTER e o botão em destaque) é o que tem volta: só os temporários.
                Write-Host ""

                $choice = Read-WinForgeChoice -Message "O que deseja limpar?" -DefaultKey "S" -ShowMenu -TextPrompt "Opção (ENTER = só os temporários)" -Options @(
                    @{ Key = "S"; Label = "Só os temporários"; Description = "a Lixeira fica como está"; Accent = $true },
                    @{ Key = "T"; Label = "Temporários e Lixeira"; Description = "o que está na Lixeira é apagado em definitivo, sem volta" },
                    @{ Key = "X"; Label = "Cancelar"; Exit = $true }
                )

                $proceed = ($choice -in @("T", "S"))
                if ($choice -eq "S") { $SkipRecycleBin = $true }
            }
        }

        if ($nothing) {
            $result = New-WinForgeResult -Kind Skipped -Detail "nada para limpar" -Data @{ FreedBytes = [int64]0 }
            [void](Set-WinForgeResultView -Result $result -Headline "Nada para limpar" -Note "Os temporários estão vazios ou são recentes$(if (-not $SkipRecycleBin) { ', e a Lixeira está vazia' }).")
        }
        elseif (-not $proceed) {
            Write-WinForgeStatus -Type Warning -Message "Operação cancelada."
            $result = New-WinForgeResult -Kind Skipped -Detail "cancelado pelo usuário"
        }
        else {
            # Cada parte com o nome que a frase do total usa.
            $steps = @(
                @{ Name = "os temporários do usuário"; Result = (Clear-WinForgeUserTemp -Embedded -PassThru) },
                @{ Name = "os temporários do Windows"; Result = (Clear-WinForgeWindowsTemp -Embedded -PassThru) }
            )

            # Sem a Lixeira (a escolha da pessoa), nada é dito: ela ficou como estava.
            if (-not $SkipRecycleBin) {
                $steps += @{ Name = "a Lixeira"; Result = (Clear-WinForgeRecycleBin -Embedded -PassThru -Contents $binContents) }
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

            Write-WinForgeSection -Title "Resumo"
            Write-WinForgeKeyValue -Label "Espaço liberado" -Value $freedText

            if ($unmeasured.Count -gt 0) {
                Write-WinForgeStatus -Type Info -Message "O total não inclui $(Join-WinForgeList -Items $unmeasured): não foi possível medir antes de limpar."
            }

            $data = @{ FreedBytes = $freed }

            if ($failed.Count -eq 0 -and $warned.Count -eq 0) {
                $result = New-WinForgeResult -Kind Ok -Detail "liberou $freedText" -Data $data

                # Na janela, a faixa diz quanto e de onde, e o resumo (as mesmas contas, parte por parte) fica nos detalhes.
                if (-not $Embedded -and $freed -gt 0) {
                    # A Lixeira entra na frase só quando havia algo nela (vazia, o passo dela não tirou nada).
                    $binCleaned = (-not $SkipRecycleBin -and -not ($null -ne $binContents -and [int]$binContents.Count -eq 0))
                    $what = "Temporários do usuário e do Windows$(if ($binCleaned) { ', e a Lixeira' })."
                    if ($unmeasured.Count -gt 0) { $what += " O total não inclui $(Join-WinForgeList -Items $unmeasured)." }
                    [void](Set-WinForgeResultView -Result $result -Headline "$freedText liberados" -Note $what -HideSummary:($unmeasured.Count -eq 0))
                }
            }
            elseif ($failed.Count -eq 0) {
                # Uma parte só fica com ressalva quando nada saiu dela porque estava tudo em uso: a faixa diz qual.
                $warnedNames = @($steps | Where-Object { $_.Result.Kind -eq "Warning" } | ForEach-Object { [string]$_.Name })
                $result = New-WinForgeResult -Kind Warning -Detail "$(Join-WinForgeList -Items $warnedNames) com itens em uso; liberou $freedText" -Data $data
            }
            elseif ($failed.Count -lt $parts.Count) {
                $detail = "$($failed.Count) de $($parts.Count) partes $(if ($failed.Count -eq 1) { 'falhou' } else { 'falharam' })"
                if ($warned.Count -gt 0) { $detail += "; $($warned.Count) com ressalvas" }

                $result = New-WinForgeResult -Kind Warning -Detail "$detail; liberou $freedText" -Data $data
            }
            else {
                $result = New-WinForgeResult -Kind Failed -Detail "todas as partes falharam" -Data $data
            }
        }
    }
    catch {
        Write-WinForgeStatus -Type Error -Message "Ocorreu um erro na limpeza: $($_.Exception.Message)"
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
    $question = "Remover o que foi baixado ou alterado há mais de quantos dias?"

    if (Test-WinForgeGuiPrompts) {
        $key = Read-WinForgeChoice -Message $question -DefaultKey "30" -Options @(
            @{ Key = "7"; Label = "7 dias" },
            @{ Key = "15"; Label = "15 dias" },
            @{ Key = "30"; Label = "30 dias"; Description = "recomendado"; Accent = $true },
            @{ Key = "60"; Label = "60 dias" },
            @{ Key = "90"; Label = "90 dias" },
            @{ Key = "180"; Label = "180 dias" },
            @{ Key = "365"; Label = "1 ano" },
            @{ Key = "other"; Label = "Outro valor..." }
        )

        if ($key -ne "other") {
            return [int]$key
        }
    }

    # Um valor errado (uma letra, um zero) pede de novo, até três vezes, em vez de encerrar a ação.
    for ($attempt = 1; $attempt -le 3; $attempt++) {
        $prompt = $(if ($attempt -eq 1) { "$question (ENTER = 30)" } else { "Digite um número de dias, por exemplo 45 (ENTER = 30)" })
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
            Write-WinForgeStatus -Type Warning -Notice -Message "Valor inválido: digite só o número de dias (1 ou mais), por exemplo 45."
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

    Write-WinForgeSection -Title "O que será limpo (maiores primeiro)"

    foreach ($entry in @($Selected | Sort-Object SizeBytes -Descending | Select-Object -First $Top)) {
        $nameText = [string]$entry.Name
        if ($entry.IsDirectory) { $nameText += [IO.Path]::DirectorySeparatorChar }

        if ($nameText.Length -gt 50) {
            $nameText = $nameText.Substring(0, 47) + "..."
        }

        Write-WinForgeKeyValue -Label $nameText -Value "$(Format-WinForgeBytes -Bytes $entry.SizeBytes -ZeroText '0 B') · $(Format-WinForgeDateTime -When $entry.LastActivity -Pattern 'dd/MM/yyyy')"
    }

    if ($Selected.Count -gt $Top) {
        Write-WinForgeStatus -Type Info -Message "E mais $(Format-WinForgeCount -Count ($Selected.Count - $Top) -One 'item menor' -Many 'itens menores')."
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
    $title = "Limpar a pasta Downloads"

    Enter-WinForgeAction -Title $title

    # Uma saída só, no fim: cada caminho deixa aqui o resultado que a faixa mostra.
    $result = $null

    try {
        $downloadsPath = Get-WinForgeDownloadsPath
        $listing = $null

        if (-not (Test-Path -LiteralPath $downloadsPath -PathType Container)) {
            Write-WinForgeStatus -Type Error -Message "Pasta Downloads não encontrada: $downloadsPath"
            $result = New-WinForgeResult -Kind Failed -Detail "pasta Downloads não encontrada"
        }
        # A pasta Downloads pode ser redirecionada pelo Windows para qualquer lugar. Se apontar para a raiz de um disco, para
        # o perfil ou para outra pasta pessoal (Documentos, a raiz do OneDrive), "Tudo" apagaria muito mais que downloads.
        elseif (-not (Test-WinForgeDownloadsFolderSafe -Path $downloadsPath)) {
            Write-WinForgeStatus -Type Error -Message "Pasta recusada por segurança: $downloadsPath"
            Write-WinForgeStatus -Type Info -Message "Ela é uma raiz de disco, contém o seu perfil ou outra pasta pessoal. Confira onde a pasta Downloads está definida."
            $result = New-WinForgeResult -Kind Failed -Detail "pasta recusada por segurança"
        }
        else {
            $listing = Get-WinForgeFolderListing -Path $downloadsPath -ExcludeShellMetadata

            if (-not $listing.Readable) {
                # Sem conseguir listar, "já está vazia" seria um palpite.
                Write-WinForgeStatus -Type Error -Message "Não foi possível ler a pasta Downloads: $($listing.Reason)"
                $result = New-WinForgeResult -Kind Failed -Detail "pasta ilegível"
            }
        }

        if ($null -eq $result) {
            if (Test-WinForgeUserContextMismatch) {
                Write-WinForgeStatus -Type Warning -Notice -Message "Elevado com outra conta: esta é a pasta Downloads de $env:USERNAME, não a do usuário logado."
            }

            $allItems = @($listing.Items)

            Write-WinForgeKeyValue -Label "Pasta" -Value $downloadsPath
            Write-WinForgeKeyValue -Label "Itens na pasta" -Value (Format-WinForgeNumber -Value $allItems.Count)
            Write-Host ""

            if ($allItems.Count -eq 0) {
                Write-WinForgeStatus -Type Success -Message "A pasta Downloads já está vazia."
                $result = New-WinForgeResult -Kind Ok -Detail "a pasta já estava vazia"
            }
        }

        $selected = @()
        $days = $null

        if ($null -eq $result) {
            $mode = Read-WinForgeChoice -Message "O que deseja limpar?" -ShowMenu -Options @(
                @{ Key = "1"; Label = "O que é mais antigo"; Description = "recomendado: você escolhe há quantos dias"; Accent = $true },
                @{ Key = "2"; Label = "Tudo"; Description = "$(if ($allItems.Count -eq 1) { 'o único item da pasta' } else { "todos os $($allItems.Count) itens da pasta" }), de qualquer data" },
                @{ Key = "0"; Label = "Cancelar"; Exit = $true }
            )

            if ($mode -ne "1" -and $mode -ne "2") {
                Write-WinForgeStatus -Type Warning -Message "Limpeza cancelada."
                $result = New-WinForgeResult -Kind Skipped -Detail "cancelado pelo usuário"
            }
            elseif ($mode -eq "1") {
                $days = Read-WinForgeDaysThreshold

                if ($null -eq $days) {
                    Write-WinForgeStatus -Type Error -Message "Valor inválido: informe um número inteiro de dias (1 ou mais). Nada foi apagado."
                    $result = New-WinForgeResult -Kind Failed -Detail "número de dias inválido"
                }
            }
        }

        if ($null -eq $result) {
            # Medir e datar pode levar um tempo numa pasta grande; o andamento vai na barra, não numa linha do resumo.
            Write-Progress -Activity "Analisando a pasta Downloads" -Status "medindo os itens"
            $entries = @(Measure-WinForgeFolderItems -Items $allItems -ExcludeShellMetadata)
            Write-Progress -Activity "Analisando a pasta Downloads" -Completed

            # @() e não $(): com um item só, $() devolveria o item solto, sem .Count de lista.
            $selected = @(if ($null -ne $days) { Select-WinForgeItemsOlderThan -Entries $entries -Cutoff (Get-Date).AddDays(-$days) } else { $entries })

            if ($selected.Count -eq 0) {
                Write-WinForgeStatus -Type Success -Message "Nada foi baixado ou alterado há mais de $(Format-WinForgeCount -Count $days -One 'dia' -Many 'dias'); não há o que limpar."
                $result = New-WinForgeResult -Kind Ok -Detail "nada com mais de $(Format-WinForgeCount -Count $days -One 'dia' -Many 'dias')"
            }
        }

        if ($null -eq $result) {
            $selectedBytes = [int64]0
            foreach ($entry in $selected) { $selectedBytes += [int64]$entry.SizeBytes }

            $itemsText = Format-WinForgeCount -Count $selected.Count -One "item" -Many "itens"

            Show-WinForgeDownloadsPreview -Selected $selected

            Write-Host ""
            Write-WinForgeKeyValue -Label "Itens a limpar" -Value (Format-WinForgeNumber -Value $selected.Count)
            Write-WinForgeKeyValue -Label "Espaço que ocupam" -Value (Format-WinForgeBytes -Bytes $selectedBytes)
            Write-Host ""

            $destination = Read-WinForgeChoice -Message "O que fazer com $(if ($selected.Count -eq 1) { 'este item' } else { "estes $itemsText" })?" -ShowMenu -Options @(
                @{ Key = "L"; Label = "Enviar para a Lixeira"; Description = "recomendado: dá para recuperar"; Accent = $true },
                @{ Key = "P"; Label = "Excluir permanentemente"; Description = "não dá para recuperar" },
                @{ Key = "0"; Label = "Cancelar"; Exit = $true }
            )

            if ($destination -ne "L" -and $destination -ne "P") {
                Write-WinForgeStatus -Type Warning -Message "Limpeza cancelada."
                $result = New-WinForgeResult -Kind Skipped -Detail "cancelado pelo usuário"
            }
            else {
                $permanent = ($destination -eq "P")

                if ($permanent) {
                    Write-Host ""
                    # Aviso antes da pergunta, não resultado: não conta como ressalva, senão toda exclusão que deu certo
                    # terminaria como "Concluído com ressalvas".
                    Write-WinForgeStatus -Type Warning -Notice -Message $(if ($selected.Count -eq 1) { "O item será removido permanentemente e não poderá ser recuperado." } else { "Os itens serão removidos permanentemente e não poderão ser recuperados." })

                    if (-not (Confirm-WinForgeAction "Confirma a exclusão permanente de $(if ($selected.Count -eq 1) { '1 item' } else { $itemsText })?" -DefaultKey N)) {
                        Write-WinForgeStatus -Type Warning -Message "Limpeza cancelada."
                        $result = New-WinForgeResult -Kind Skipped -Detail "cancelado pelo usuário"
                    }
                }
                else {
                    $binProblem = Get-WinForgeRecycleBinProblem -Path $downloadsPath

                    if ($binProblem) {
                        # Sem Lixeira na unidade, o Windows apagaria tudo em definitivo; "enviados à Lixeira" seria mentira.
                        Write-WinForgeStatus -Type Error -Message "A pasta Downloads ${binProblem}: o Windows apagaria os itens em definitivo. Nada foi removido."
                        Write-WinForgeStatus -Type Info -Message "Se é isso o que você quer, abra de novo e escolha Excluir permanentemente."
                        $result = New-WinForgeResult -Kind Failed -Detail "a pasta Downloads $binProblem"
                    }
                    elseif (Test-WinForgeRecycleBinLimitExceeded -Items $selected) {
                        Write-WinForgeStatus -Type Info -Message "Itens maiores que o limite da Lixeira ficam onde estão: o Windows os apagaria em definitivo."
                    }
                }

                if ($null -eq $result) {
                    $result = Invoke-WinForgeDownloadsRemoval -Selected $selected -Permanent:$permanent
                }
            }
        }
    }
    catch {
        Write-WinForgeStatus -Type Error -Message "Falha ao limpar Downloads: $($_.Exception.Message)"
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
    $activity = "Limpando Downloads"

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
                throw "em uso"
            }

            if ($Permanent) {
                Remove-WinForgeItem -Path $entry.Path
            }
            else {
                Move-WinForgeItemToRecycleBin -Path $entry.Path -IsDirectory:$entry.IsDirectory -SizeBytes ([int64]$entry.SizeBytes)
            }

            # Get-Item -Force e não Test-Path: um atalho quebrado "não existe" para o Test-Path, mas continua na pasta.
            if ($null -ne (Get-Item -LiteralPath $entry.Path -Force -ErrorAction SilentlyContinue)) {
                throw "o item continua na pasta"
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
        Write-WinForgeStatus -Type Warning -Message "Nenhum item foi para a Lixeira: todos passam do limite dela."
    }
    elseif ($done -eq 0) {
        Write-WinForgeStatus -Type Warning -Message "Nenhum item foi removido: estavam em uso ou não puderam ser removidos."
    }
    else {
        Write-WinForgeStatus -Type Success -Message "Limpeza concluída."
    }

    if ($Permanent) {
        Write-WinForgeKeyValue -Label "Itens excluídos" -Value (Format-WinForgeNumber -Value $done)
        Write-WinForgeKeyValue -Label "Espaço liberado" -Value $bytesText
    }
    else {
        Write-WinForgeKeyValue -Label "Itens enviados à Lixeira" -Value (Format-WinForgeNumber -Value $done)
        Write-WinForgeKeyValue -Label "Tamanho na Lixeira" -Value $bytesText
    }

    Write-WinForgeKeyValue -Label "Itens ignorados" -Value ($skipped + $tooBig)

    if ($tooBig -gt 0) {
        Write-Host ""
        # O Windows apagaria em definitivo o que passa do limite da Lixeira: fica, e a saída é a exclusão permanente.
        Write-WinForgeStatus -Type Warning -Message "$(Format-WinForgeCount -Count $tooBig -One 'item passa' -Many 'itens passam') do limite da Lixeira ($(Format-WinForgeBytes -Bytes $limit)) e $(if ($tooBig -eq 1) { 'ficou' } else { 'ficaram' }); para $(if ($tooBig -eq 1) { 'tirá-lo' } else { 'tirá-los' }), use Excluir permanentemente."
    }

    if ($skipped -gt 0 -and $done -gt 0) {
        Write-Host ""
        Write-WinForgeStatus -Type Warning -Message $(if ($skipped -eq 1) { "1 item estava em uso ou não pôde ser removido; feche o programa que o usa e tente de novo." } else { "$skipped itens estavam em uso ou não puderam ser removidos; feche os programas que os usam e tente de novo." })
    }

    if (-not $Permanent -and $done -gt 0) {
        Write-Host ""
        Write-WinForgeStatus -Type Info -Message "O espaço só volta quando a Lixeira for esvaziada (Limpeza > Esvaziar a Lixeira)."
    }

    if ($done -eq 0) {
        return New-WinForgeResult -Kind Warning -Detail $(if ($skipped -eq 0 -and $tooBig -gt 0) { "nenhum item foi removido: passam do limite da Lixeira" } else { "nenhum item foi removido: estavam em uso" })
    }

    # Mandar para a Lixeira não libera espaço no disco; só a exclusão permanente libera.
    $detail = $(if ($Permanent) { "$(Format-WinForgeCount -Count $done -One 'item excluído' -Many 'itens excluídos'), liberou $bytesText" } else { "$(Format-WinForgeCount -Count $done -One 'item enviado' -Many 'itens enviados') à Lixeira ($bytesText)" })
    $freed = $(if ($Permanent) { $bytes } else { [int64]0 })

    if ($skipped + $tooBig -gt 0) {
        return New-WinForgeResult -Kind Warning -Detail "$detail; $(Format-WinForgeCount -Count ($skipped + $tooBig) -One 'ficou' -Many 'ficaram')" -Data @{ FreedBytes = $freed }
    }

    $okResult = New-WinForgeResult -Kind Ok -Detail $detail -Data @{ FreedBytes = $freed }

    # Na Lixeira, o espaço ainda não voltou: o botão da faixa esvazia a Lixeira.
    if (-not $Permanent) { [void](Set-WinForgeRecycleBinNext -Result $okResult -Count $done -Bytes $bytes) }

    return $okResult
}


# ---------------------------------------------------------------------------
# Pastas pessoais (etapa do Otimizar)
# ---------------------------------------------------------------------------

function Get-WinForgeReviewFolders {
    # As pastas pessoais que o Otimizar sugere organizar, na ordem. Shortcut é o atalho que abre a pasta e diz onde ela
    # fica (Get-WinForgeShortcutFolderPath); Clean, a ação do WinForge que limpa a pasta além de abri-la.
    return @(
        [PSCustomObject]@{ Shortcut = "Downloads"; Label = "Downloads"; Clean = "Clear-WinForgeDownloads" },
        [PSCustomObject]@{ Shortcut = "Documents"; Label = "Documentos"; Clean = "" },
        [PSCustomObject]@{ Shortcut = "Pictures"; Label = "Imagens"; Clean = "" }
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

    $title = "Organizar Downloads, Documentos e Imagens"

    Enter-WinForgeAction -Title $title -Embedded:$Embedded

    $notes = @()
    $problems = 0
    $final = $null

    try {
        [void](Write-WinForgeOtherAccountNotice -What "as pastas pessoais (Downloads, Documentos e Imagens)")

        $folders = @(Get-WinForgeReviewFolders)
        $position = 0

        foreach ($folder in $folders) {
            $position++
            $path = Get-WinForgeShortcutFolderPath -Name $folder.Shortcut

            Write-WinForgeSection -Title "$($folder.Label) ($position de $($folders.Count))"

            if ([string]::IsNullOrWhiteSpace($path) -or -not (Test-Path -LiteralPath $path -PathType Container)) {
                Write-WinForgeStatus -Type Info -Message "Pasta não encontrada."
                continue
            }

            Write-Progress -Activity "Medindo a pasta $($folder.Label)" -Status $path

            try { $stats = Get-WinForgePathStats -Path $path -ExcludeShellMetadata }
            finally { Write-Progress -Activity "Medindo a pasta $($folder.Label)" -Completed }

            Write-WinForgeKeyValue -Label "Pasta" -Value $path

            if ([int64]$stats.Files -eq 0) {
                Write-WinForgeKeyValue -Label "Conteúdo" -Value "vazia"
                continue
            }

            Write-WinForgeKeyValue -Label "Conteúdo" -Value "$(Format-WinForgeBytes -Bytes ([int64]$stats.Size) -ZeroText '0 B') em $(Format-WinForgeCount -Count ([int64]$stats.Files) -One 'arquivo' -Many 'arquivos')"
            Write-Host ""

            $options = @()
            $keys = @()

            if ($folder.Clean) {
                $options += @{ Key = "L"; Label = "Limpar com o WinForge"; Description = "o que você escolher vai para a Lixeira"; Accent = $true }
                $keys += "L"
            }

            $options += @{ Key = "A"; Label = "Abrir no Explorador"; Description = "você organiza à mão"; Accent = (-not $folder.Clean) }
            $options += @{ Key = "D"; Label = "Procurar arquivos duplicados"; Description = "cópias iguais; você escolhe o que vai para a Lixeira" }
            $options += @{ Key = "P"; Label = "Pular esta pasta" }
            $keys += @("A", "D", "P")

            if ($position -lt $folders.Count) {
                $options += @{ Key = "X"; Label = "Pular as pastas restantes"; Exit = $true }
                $keys += "X"
            }

            $keyText = (@($keys | Select-Object -First ($keys.Count - 1)) -join ", ") + " ou " + $keys[$keys.Count - 1]
            $answer = Read-WinForgeChoice -Message "O que fazer com a pasta $($folder.Label)?" -Options $options -DefaultKey "P" -ShowMenu `
                -TextPrompt "Opção ($keyText; ENTER = pular esta pasta)"

            if ($answer -ieq "X") {
                Write-WinForgeStatus -Type Info -Message "As pastas restantes ficaram como estão."
                break
            }

            if ($answer -ieq "L" -and $folder.Clean) {
                $result = Invoke-WinForgeNestedAction -Command $folder.Clean
                $notes += "$($folder.Label): $(Get-WinForgeFolderReviewNote -Result $result)"
                if ($result.Kind -eq "Failed") { $problems++ }
            }
            elseif ($answer -ieq "D") {
                $result = Invoke-WinForgeNestedAction -Command "Find-WinForgeDuplicateFiles" -Arguments @{ Path = $path }
                $notes += "$($folder.Label): $(Get-WinForgeFolderReviewNote -Result $result)"
                if ($result.Kind -eq "Failed") { $problems++ }
            }
            elseif ($answer -ieq "A") {
                if (Open-WinForgeShortcut -Name $folder.Shortcut) {
                    Write-Host ""
                    [void](Read-WinForgeChoice -Message "Organize a pasta na janela aberta e depois continue." -Options @(@{ Key = "C"; Label = "Continuar"; Accent = $true }) `
                            -DefaultKey "C" -TextPrompt "Organize a pasta na janela aberta e pressione ENTER")
                    $notes += "$($folder.Label): aberta no Explorador"
                }
                else {
                    $problems++
                }
            }
        }

        if ($notes.Count -eq 0 -and $problems -eq 0) {
            $final = New-WinForgeResult -Kind Skipped -Detail "nenhuma pasta foi mexida" -Title $title
        }
        elseif ($problems -gt 0) {
            $final = New-WinForgeResult -Kind Warning -Detail $(if ($notes.Count -gt 0) { $notes -join "; " } else { "a pasta não abriu" }) -Title $title
        }
        else {
            $final = New-WinForgeResult -Kind Ok -Detail ($notes -join "; ") -Title $title
        }
    }
    catch {
        Write-WinForgeStatus -Type Error -Message "Não foi possível revisar as pastas: $($_.Exception.Message.TrimEnd('.'))."
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

    if ([string]$Result.Kind -eq "Skipped" -and ([string]::IsNullOrWhiteSpace($detail) -or $detail -match "(?i)cancelad")) {
        return "nada mudou"
    }

    if (-not [string]::IsNullOrWhiteSpace($detail)) { return $detail }

    return $(if ([string]$Result.Kind -eq "Ok") { "concluído" } else { [string]$Result.Status })
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

    $parser = {
        param ($ExitCode, $Text)

        $result = Get-WinForgeExitCodeResult -ExitCode $ExitCode -OutputText $Text
        $after = [int64](Get-WinForgeSystemDriveFreeBytes)

        if ($result.Kind -eq "Ok" -and $before -ge 0 -and $after -ge 0) {
            $freed = $after - $before

            if ($freed -lt 50MB) {
                $result = New-WinForgeResult -Kind Ok -Detail "quase nada a liberar" -Data @{ FreedBytes = [int64]0 }
            }
            else {
                $result = New-WinForgeResult -Kind Ok -Detail "liberou cerca de $(Format-WinForgeBytes -Bytes $freed)" -Data @{ FreedBytes = [int64]$freed }
            }
        }

        $result
    }.GetNewClosure()

    Invoke-WinForgeTool `
        -Title "Limpar componentes do Windows (WinSxS)" `
        -FilePath "dism.exe" `
        -Arguments @("/Online", "/Cleanup-Image", "/StartComponentCleanup") `
        -Description @("Remove versões antigas de componentes do Windows, em 5 a 30 minutos.") `
        -Warnings @("Não apaga nada seu, e as atualizações recentes continuam podendo ser desinstaladas.") `
        -Question "Limpar os componentes agora?" `
        -ResultParser $parser `
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
        (New-WinForgeCleanupTarget -Id "user-temp" -Label "Temporários do usuário" -Selected -MinAgeHours $script:WinForgeTempMinAgeHours `
            -Description "O que os programas deixam na sua pasta Temp" -Paths @(Get-WinForgeUserTempPath)),
        (New-WinForgeCleanupTarget -Id "windows-temp" -Label "Temporários do Windows" -Admin -Selected -MinAgeHours $script:WinForgeTempMinAgeHours `
            -Description "A pasta Temp do sistema" -Paths @(Get-WinForgeWindowsTempPath)),
        (New-WinForgeCleanupTarget -Id "error-reports" -Label "Relatórios de erro do Windows" -Admin -Selected `
            -Description "Cópias de falhas de programas" -Paths $errorReports),
        (New-WinForgeCleanupTarget -Id "delivery-optimization" -Label "Cache da Otimização de Entrega" -Admin -Selected `
            -Description "Partes de atualizações; o Windows baixa de novo se precisar" -Paths $deliveryCache),
        (New-WinForgeCleanupTarget -Id "browser-cache" -Label "Cache dos navegadores" `
            -Description "Senhas, cookies e histórico ficam; as páginas abrem mais devagar na primeira vez" `
            -Paths @(Get-WinForgeBrowserCachePaths)),
        (New-WinForgeCleanupTarget -Id "shader-cache" -Label "Cache de sombreadores dos jogos" `
            -Description "O primeiro carregamento de cada jogo fica mais lento" `
            -Paths @(Get-WinForgeShaderCachePaths)),
        (New-WinForgeCleanupTarget -Id "crash-dumps" -Label "Despejos de memória de falhas" -Admin `
            -Description "Só servem para investigar travamentos e telas azuis" `
            -Paths @(Get-WinForgeCrashDumpPaths) -Files @(Get-WinForgeMemoryDumpFile)),
        (New-WinForgeCleanupTarget -Id "recycle-bin" -Label "Lixeira" -RecycleBin `
            -Description "O que está nela é removido em definitivo")
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
    $activity = "Somando o tamanho das pastas do perfil"
    $position = 0

    $rows = @(
        foreach ($folder in $folders) {
            $position++
            Write-Progress -Activity $activity -Status "$($folder.Name) ($position de $($folders.Count))" -PercentComplete ([int](($position - 1) * 100 / $folders.Count))
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
        @{ Label = "Hibernação (hiberfil.sys)"; Path = (Join-Path $driveRoot "hiberfil.sys"); Folder = $false; Hint = "sai com o ajuste Desativar hibernação, na página Ajustes do Windows" },
        @{ Label = "Memória virtual (pagefile.sys)"; Path = (Join-Path $driveRoot "pagefile.sys"); Folder = $false; Hint = "o Windows cuida dele; não mexa sem motivo" },
        @{ Label = "Arquivo de troca (swapfile.sys)"; Path = (Join-Path $driveRoot "swapfile.sys"); Folder = $false; Hint = "o Windows cuida dele" },
        @{ Label = "Windows anterior (Windows.old)"; Path = (Join-Path $driveRoot "Windows.old"); Folder = $true; Hint = "remova em Limpeza > Configurações de armazenamento (Arquivos temporários, Instalações anteriores do Windows)" },
        @{ Label = "Downloads do Windows Update"; Path = (Join-Path $windows "SoftwareDistribution\Download"); Folder = $true; Hint = "o Windows apaga depois de instalar as atualizações" },
        @{ Label = "Despejo de tela azul (MEMORY.DMP)"; Path = (Join-Path $windows "MEMORY.DMP"); Folder = $false; Hint = "sai em Limpeza > Limpeza personalizada (Despejos de memória de falhas)" }
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
    $activity = "Medindo o que pode ser liberado"
    $position = 0

    $measured = @(
        foreach ($target in $targets) {
            $position++
            Write-Progress -Activity $activity -Status "$($target.Label) ($position de $($targets.Count))" -PercentComplete ([int](($position - 1) * 100 / $targets.Count))
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
    $title = "Analisar uso de espaço"
    Enter-WinForgeAction -Title $title

    $result = $null

    try {
        # O que não pôde ser medido é dito no fim; "nada acumulado" só vale para o que de fato foi olhado.
        $unmeasured = New-Object System.Collections.Generic.List[string]
        $headline = ""
        $diskLevel = ""
        $sum = [int64]0

        Write-WinForgeSection -Title "Disco do sistema"

        $space = Get-WinForgeSystemDriveSpace

        if ($null -ne $space -and $space.TotalBytes -gt 0) {
            $headline = "$(Format-WinForgeBytes -Bytes $space.FreeBytes -ZeroText '0 B') livres de $(Format-WinForgeBytes -Bytes $space.TotalBytes)"
            $diskLevel = Get-WinForgeDiskSpaceLevel -FreeBytes $space.FreeBytes -TotalBytes $space.TotalBytes
            $used = [int64]$space.TotalBytes - [int64]$space.FreeBytes
            $percent = [int][Math]::Round(($used * 100.0) / $space.TotalBytes, [MidpointRounding]::AwayFromZero)

            Write-WinForgeKeyValue -Label "Tamanho" -Value (Format-WinForgeBytes -Bytes $space.TotalBytes)
            Write-WinForgeKeyValue -Label "Em uso" -Value "$(Format-WinForgeBytes -Bytes $used -ZeroText '0 B') ($percent%)"
            Write-WinForgeKeyValue -Label "Livre" -Value (Format-WinForgeBytes -Bytes $space.FreeBytes -ZeroText '0 B')

            # A regra da tela inicial e da Manutenção. Um aviso sobre o disco, não sobre a análise: não conta no desfecho.
            switch ($diskLevel) {
                "Critical" { Write-WinForgeStatus -Type Warning -Notice -Message "O disco do sistema está quase cheio: o Windows precisa de espaço livre para se atualizar." }
                "Low" { Write-WinForgeStatus -Type Warning -Notice -Message "Pouco espaço livre no disco do sistema." }
            }
        }
        else {
            Write-WinForgeStatus -Type Warning -Message "Não foi possível ler o tamanho do disco do sistema."
        }

        Write-WinForgeSection -Title "O que a limpeza pode liberar"

        $targets = @(Measure-WinForgeCleanupTargets)
        $withSize = @($targets | Where-Object { $null -ne $_.Size -and $_.Size -gt 0 } | Sort-Object -Property Size -Descending)

        foreach ($target in @($targets | Where-Object { $null -eq $_.Size -or $_.Unreadable -gt 0 })) {
            $unmeasured.Add($target.Label)
        }

        if ($withSize.Count -eq 0) {
            if ($unmeasured.Count -eq 0) {
                Write-WinForgeStatus -Type Info -Message "Não há temporários, relatórios nem caches acumulados."
            }
        }
        else {
            foreach ($target in $withSize) {
                Write-WinForgeKeyValue -Label $target.Label -Value (Format-WinForgeBytes -Bytes $target.Size) -LabelWidth 36
            }

            foreach ($target in $withSize) { $sum += [int64]$target.Size }

            Write-Host ""

            # Com itens sem medir, o total é só o piso do que dá para liberar.
            $lead = $(if ($unmeasured.Count -gt 0) { "Pelo menos" } else { "Até" })
            Write-WinForgeStatus -Type Info -Message "$lead $(Format-WinForgeBytes -Bytes $sum) podem ser liberados em Limpeza > Limpeza personalizada."
        }

        Write-WinForgeSection -Title "Maiores pastas do seu perfil"

        $folders = @(Get-WinForgeUserFolderSizes)
        $filled = @($folders | Where-Object { $_.Size -gt 0 })

        if ($folders.Count -eq 0) {
            Write-WinForgeStatus -Type Warning -Message "Não foi possível ler as pastas do perfil."
        }
        elseif ($filled.Count -eq 0) {
            Write-WinForgeStatus -Type Info -Message "As pastas do perfil estão vazias."
        }
        else {
            foreach ($folder in $filled) {
                Write-WinForgeKeyValue -Label $folder.Name -Value (Format-WinForgeBytes -Bytes $folder.Size) -LabelWidth 36
            }
        }

        Write-WinForgeSection -Title "Arquivos grandes do sistema"

        $shown = 0

        foreach ($entry in @(Get-WinForgeSystemSpaceFiles)) {
            if ($entry.Unreadable) {
                Write-WinForgeKeyValue -Label $entry.Label -Value "não foi possível medir" -LabelWidth 36
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
            Write-WinForgeStatus -Type Info -Message "Nenhum arquivo grande do sistema foi encontrado."
        }

        Write-Host ""

        if ($unmeasured.Count -gt 0) {
            # Sem Administrador isso é esperado (Windows.old, SoftwareDistribution e a pasta Temp do sistema não deixam ler);
            # como Administrador, é um problema de verdade.
            $isAdmin = Test-WinForgeAdministrator
            $type = $(if ($isAdmin) { "Warning" } else { "Info" })

            Write-WinForgeStatus -Type $type -Message "Não foi possível medir: $(Join-WinForgeList -Items @($unmeasured))."

            if (-not $isAdmin) {
                Write-WinForgeStatus -Type Info -Message "Para incluir as pastas do sistema, feche o WinForge, abra de novo e aceite o aviso do Windows."
            }
        }

        # Os tamanhos são estimativas: arquivos sem permissão de leitura não entram na soma.

        # A faixa da janela: o espaço livre como título (amarelo com pouco espaço), o que a limpeza libera embaixo e o botão
        # para a Limpeza personalizada, que é onde se escolhe o que tirar. Antes, a análise terminava sem faixa.
        $lead = $(if ($unmeasured.Count -gt 0) { "Pelo menos" } else { "Até" })
        $note = $(if ($sum -gt 0) { "$lead $(Format-WinForgeBytes -Bytes $sum) podem ser liberados na Limpeza personalizada." } elseif ($unmeasured.Count -eq 0) { "Não há temporários, relatórios nem caches acumulados." } else { "" })
        if ($unmeasured.Count -gt 0) { $note = ("$note Não foi possível medir: $(Join-WinForgeList -Items @($unmeasured)).").Trim() }

        # Sem o disco do sistema, ou sem medir o que um Administrador mede, é ressalva (como os avisos da tela).
        $kind = $(if (-not $headline -or ($unmeasured.Count -gt 0 -and (Test-WinForgeAdministrator))) { "Warning" } else { "Ok" })
        $result = New-WinForgeResult -Kind $kind -Detail $(if ($headline) { $headline } else { "disco do sistema não lido" }) -Data @{ CleanableBytes = $sum }

        if ($headline) {
            $tone = $(if ($diskLevel -in @("Critical", "Low")) { "Warn" } elseif ($kind -eq "Warning") { "Warn" } else { "" })
            [void](Set-WinForgeResultView -Result $result -Headline $headline -Note $note -Tone $tone `
                    -Next $(if ($sum -gt 0) { "cleanup.custom" } else { "" }) -NextLabel $(if ($sum -gt 0) { "Abrir a Limpeza personalizada" } else { "" }))
        }
    }
    catch {
        Write-WinForgeStatus -Type Error -Message "Ocorreu um erro ao analisar o espaço: $($_.Exception.Message)"
        $result = New-WinForgeResult -Kind Failed -Detail $_.Exception.Message
    }

    $result.Etapa = $title
    Exit-WinForgeAction -Result $result
}


function Invoke-WinForgeCustomCleanup {
    $title = "Limpeza personalizada"

    Enter-WinForgeAction -Title $title

    # Uma saída só, no fim: cada caminho deixa aqui o resultado que a faixa mostra.
    $result = $null

    try {
        if (-not (Test-WinForgeElevation -Reason "A limpeza personalizada exige privilégios de Administrador.")) {
            $result = New-WinForgeResult -Kind Failed -Detail "requer Administrador"
        }

        $available = @()

        if ($null -eq $result) {
            $available = @(Measure-WinForgeCleanupTargets | Where-Object { Test-WinForgeCleanupTargetAvailable -Target $_ })

            if ($available.Count -eq 0) {
                Write-WinForgeStatus -Type Success -Message "Não há nada acumulado para limpar."
                $result = New-WinForgeResult -Kind Skipped -Detail "não há nada acumulado" -Data @{ FreedBytes = [int64]0 }
                [void](Set-WinForgeResultView -Result $result -Headline "Nada para limpar" -Note "Não há temporários, relatórios nem caches acumulados.")
            }
        }

        $chosen = @()

        if ($null -eq $result) {
            # Antes da lista: na janela, a pergunta de marcar deixa os detalhes técnicos recolhidos, e esta linha fica no resumo.
            Write-WinForgeStatus -Type Info -Message "Suas pastas pessoais não são tocadas."
            [void](Write-WinForgeOtherAccountNotice -What "os temporários do usuário, os caches dos navegadores e a Lixeira")
            Write-Host ""

            $options = @(
                foreach ($target in $available) {
                    $sizeText = $(if ($null -ne $target.Size) { Format-WinForgeBytes -Bytes $target.Size -ZeroText "0 B" } else { "tamanho desconhecido" })
                    @{ Key = $target.Id; Label = "$($target.Label) · $sizeText"; Description = $target.Description; Selected = $target.Selected }
                }
            )

            $picked = @(Read-WinForgeMultiSelect -Message "Escolha o que deseja limpar" -Options $options)
            $chosen = @($available | Where-Object { $picked -contains $_.Id })

            if ($chosen.Count -eq 0) {
                Write-WinForgeStatus -Type Warning -Message "Nada foi marcado; nenhuma limpeza foi feita."
                $result = New-WinForgeResult -Kind Skipped -Detail "nada marcado"
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
                elseif ($unknown -gt 0) { " (pelo menos $(Format-WinForgeBytes -Bytes $estimate -ZeroText '0 B'))" }
                else { " (cerca de $(Format-WinForgeBytes -Bytes $estimate -ZeroText '0 B'))" }
            )
            $what = $(if ($chosen.Count -eq 1) { "o item marcado" } else { "os $($chosen.Count) itens marcados" })

            # A Lixeira e os despejos de memória não voltam (o resto o Windows e os programas recriam): com eles marcados, um
            # aviso antes da pergunta, e Não como padrão.
            $chosenIds = @($chosen | ForEach-Object { [string]$_.Id })
            $noReturn = @()
            if ($chosenIds -contains "recycle-bin") { $noReturn += "o que está na Lixeira" }
            if ($chosenIds -contains "crash-dumps") { $noReturn += "os despejos de memória de falhas" }

            Write-Host ""

            if ($noReturn.Count -gt 0) {
                $noReturnText = Join-WinForgeList -Items $noReturn
                $verb = $(if ($noReturn.Count -gt 1 -or $noReturn[0] -like "os *") { "são apagados" } else { "é apagado" })
                Write-WinForgeStatus -Type Warning -Notice -Message "$($noReturnText.Substring(0, 1).ToUpperInvariant())$($noReturnText.Substring(1)) $verb em definitivo, sem volta."
            }

            if (-not (Confirm-WinForgeAction "Limpar $what${sizeText}?" -DefaultKey $(if ($noReturn.Count -gt 0) { "N" } else { "S" }))) {
                Write-WinForgeStatus -Type Warning -Message "Limpeza cancelada."
                $result = New-WinForgeResult -Kind Skipped -Detail "cancelado pelo usuário"
            }
            else {
                $result = Invoke-WinForgeCleanupTargets -Targets $chosen
            }
        }
    }
    catch {
        Write-WinForgeStatus -Type Error -Message "Ocorreu um erro na limpeza: $($_.Exception.Message)"
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

    foreach ($target in $Targets) {
        if ($target.RecycleBin) {
            # Esvaziar a Lixeira escreve o próprio título de seção.
            $part = Clear-WinForgeRecycleBin -Embedded -PassThru -Contents $target.BinContents
            $partFreed = Get-WinForgeResultData -Result $part -Name "FreedBytes"

            if ($null -ne $partFreed) { $freed += [int64]$partFreed }
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
                    Write-WinForgeStatus -Type Success -Message "Liberou $(Format-WinForgeBytes -Bytes $targetFreed -ZeroText '0 B')."
                }
                else {
                    Write-WinForgeStatus -Type Success -Message "O Windows esvaziou o cache; o espaço liberado não pôde ser medido."
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
                Write-WinForgeStatus -Type Error -Message "Pasta recusada por segurança: $path"
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
            $hint = $(if ($target.Id -eq "browser-cache") { "feche os navegadores e tente de novo" } else { "feche os programas abertos e tente de novo" })
            Write-WinForgeStatus -Type Warning -Message "Nenhum item pôde ser removido: estavam em uso; $hint."
            $problems.Add($target.Label)
        }
        elseif ($errors -gt 0) {
            if ($removed -gt 0) { Write-WinForgeStatus -Type Success -Message "Liberou $(Format-WinForgeBytes -Bytes $targetFreed -ZeroText '0 B') no que pôde ser limpo." }
            $problems.Add($target.Label)
        }
        else {
            Write-WinForgeStatus -Type Success -Message "Liberou $(Format-WinForgeBytes -Bytes $targetFreed -ZeroText '0 B')."

            # Alguns itens em uso numa parte que foi limpa são o normal; uma parte em que nada saiu já teve o seu aviso.
            $skippedItems += $skipped
        }
    }

    $freedText = Format-WinForgeBytes -Bytes $freed -ZeroText "0 B"

    if (-not $NoSummary) {
        Write-WinForgeSection -Title "Resumo"
        Write-WinForgeKeyValue -Label "Espaço liberado" -Value $freedText
    }

    if ($skippedItems -gt 0) {
        Write-WinForgeStatus -Type Info -Message "$(if ($skippedItems -eq 1) { '1 item em uso ficou' } else { "$skippedItems itens em uso ficaram" }); isso é esperado."
    }

    $data = @{ FreedBytes = $freed }

    if ($problems.Count -gt 0 -and $freed -eq 0) {
        return New-WinForgeResult -Kind Warning -Detail "nada foi liberado; com problema: $(Join-WinForgeList -Items @($problems))" -Data $data
    }

    if ($problems.Count -gt 0) {
        return New-WinForgeResult -Kind Warning -Detail "liberou $freedText; com problema: $(Join-WinForgeList -Items @($problems))" -Data $data
    }

    return New-WinForgeResult -Kind Ok -Detail "liberou $freedText" -Data $data
}


function Get-WinForgeCleanupPageStatus {
    <#
    O resumo no alto da página Limpeza: o espaço livre no disco do Windows, com a regra de "pouco espaço" da tela inicial.
    Cada linha tem Label, Text e Level (Normal | Warn | Muted). Só lê o tamanho da unidade, que é imediato.
    #>
    $space = $null

    try {
        $space = Get-WinForgeSystemDriveSpace
    }
    catch {
        $space = $null
    }

    if ($null -eq $space -or $space.TotalBytes -le 0) {
        return @([PSCustomObject]@{ Label = "Disco do sistema"; Text = "não foi possível ler"; Level = "Muted" })
    }

    $text = "$(Format-WinForgeBytes -Bytes $space.FreeBytes -ZeroText '0 B') livres de $(Format-WinForgeBytes -Bytes $space.TotalBytes)"
    $level = "Normal"

    switch (Get-WinForgeDiskSpaceLevel -FreeBytes $space.FreeBytes -TotalBytes $space.TotalBytes) {
        "Critical" { $text += " · espaço crítico; comece pela Limpeza rápida"; $level = "Warn" }
        "Low" { $text += " · pouco espaço"; $level = "Warn" }
    }

    return @([PSCustomObject]@{ Label = "Disco do sistema"; Text = $text; Level = $level })
}


Export-ModuleMember -Function *
