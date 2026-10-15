# Limpeza: temporários, Lixeira, Downloads e componentes do Windows.
# Toda exclusão passa por Remove-WinForgeItem, que nunca segue atalhos de pasta (junções e links simbólicos).

$script:WinForgeProgressStopwatch = $null


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


function Move-WinForgeItemToRecycleBin {
    param (
        [Parameter(Mandatory)]
        [string]$Path,

        [switch]$IsDirectory
    )

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

    Write-Progress -Activity $Activity -Status "$Current de $Total" -PercentComplete $percent
}


function Clear-WinForgeFolderContents {
    # Esvazia uma pasta (mantendo a pasta) e devolve o balanço.
    param (
        [Parameter(Mandatory)]
        [string]$Path,

        [string]$Activity = "Limpando"
    )

    $items = @(Get-ChildItem -LiteralPath $Path -Force -ErrorAction SilentlyContinue)
    $sizeBefore = [int64](Get-WinForgePathStats -Path $Path).Size
    $removed = 0
    $skipped = 0
    $position = 0

    foreach ($item in $items) {
        $position++
        Write-WinForgeCleanupProgress -Activity $Activity -Current $position -Total $items.Count

        try {
            Remove-WinForgeItem -Path $item.FullName
            $removed++
        }
        catch {
            $skipped++
        }
    }

    Write-WinForgeCleanupProgress -Activity $Activity -Current 0 -Total 0 -Completed

    $remaining = @(Get-ChildItem -LiteralPath $Path -Force -ErrorAction SilentlyContinue).Count
    $sizeAfter = [int64](Get-WinForgePathStats -Path $Path).Size

    return [PSCustomObject]@{
        Removed    = $removed
        Skipped    = $skipped
        Remaining  = $remaining
        SizeBefore = $sizeBefore
        SizeAfter  = $sizeAfter
        Freed      = [Math]::Max([int64]0, $sizeBefore - $sizeAfter)
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


function Invoke-WinForgeFolderCleanup {
    param (
        [Parameter(Mandatory)]
        [string]$Title,

        # Vazio quando a variável de ambiente que localiza a pasta não existe: a ação explica em vez de falhar.
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Path,

        [string[]]$Notes = @(),

        [switch]$Embedded,
        [switch]$PassThru
    )

    Enter-WinForgeAction -Title $Title -Embedded:$Embedded

    $result = $null

    try {
        if ([string]::IsNullOrWhiteSpace($Path)) {
            Write-WinForgeStatus -Type Error -Message "Não foi possível localizar a pasta a limpar: a variável de ambiente que a indica não está definida."
            $result = New-WinForgeResult -Kind Failed -Detail "pasta não localizada"
        }
        elseif (-not (Test-WinForgeCleanupTargetSafe -Path $Path)) {
            Write-WinForgeStatus -Type Error -Message "Pasta recusada por segurança: $Path"
            Write-Host "      Ela é uma raiz de disco ou contém o seu perfil ou o Windows. Verifique a variável de ambiente TEMP." -ForegroundColor DarkGray
            $result = New-WinForgeResult -Kind Failed -Detail "pasta recusada por segurança"
        }
        elseif (-not (Test-Path -LiteralPath $Path -PathType Container)) {
            Write-WinForgeStatus -Type Warning -Message "Pasta não encontrada: $Path"
            $result = New-WinForgeResult -Kind Skipped -Detail "pasta não encontrada"
        }
        else {
            $itemCount = @(Get-ChildItem -LiteralPath $Path -Force -ErrorAction SilentlyContinue).Count
            $stats = Get-WinForgePathStats -Path $Path

            Write-WinForgeKeyValue -Label "Pasta" -Value $Path
            Write-WinForgeKeyValue -Label "Itens encontrados" -Value $itemCount
            Write-WinForgeKeyValue -Label "Tamanho estimado" -Value (Format-WinForgeBytes -Bytes $stats.Size)
            Write-Host ""

            if ($itemCount -eq 0) {
                Write-WinForgeStatus -Type Success -Message "Não há nada para limpar nesta pasta."
                $result = New-WinForgeResult -Kind Ok -Detail "nada a limpar"
            }
            else {
                foreach ($note in $Notes) { Write-Host $note -ForegroundColor Yellow }
                if ($Notes.Count -gt 0) { Write-Host "" }

                if (-not $Embedded -and -not (Confirm-WinForgeAction "Deseja limpar estes arquivos?" -DefaultKey S)) {
                    Write-WinForgeStatus -Type Warning -Message "Limpeza cancelada."
                    $result = New-WinForgeResult -Kind Skipped -Detail "cancelado pelo usuário"
                }
                else {
                    Write-WinForgeStatus -Type Running -Message "Limpando..."
                    $outcome = Clear-WinForgeFolderContents -Path $Path -Activity $Title

                    Write-WinForgeStatus -Type Success -Message "Limpeza concluída."
                    Write-WinForgeKeyValue -Label "Itens removidos" -Value $outcome.Removed
                    Write-WinForgeKeyValue -Label "Itens ignorados" -Value $outcome.Skipped
                    Write-WinForgeKeyValue -Label "Espaço liberado" -Value (Format-WinForgeBytes -Bytes $outcome.Freed)

                    if ($outcome.Skipped -gt 0) {
                        Write-Host ""
                        Write-WinForgeStatus -Type Info -Message "Itens ignorados estavam em uso pelo Windows ou por aplicativos abertos; isso é esperado."
                    }

                    $detail = "liberou $(Format-WinForgeBytes -Bytes $outcome.Freed)"
                    if ($outcome.Skipped -gt 0) { $detail += "; $($outcome.Skipped) em uso" }

                    $result = New-WinForgeResult -Kind Ok -Detail $detail -Data @{ FreedBytes = [int64]$outcome.Freed }
                }
            }
        }
    }
    catch {
        Write-WinForgeStatus -Type Error -Message "Ocorreu um erro na limpeza: $($_.Exception.Message)"
        $result = New-WinForgeResult -Kind Failed -Detail $_.Exception.Message
    }

    $result.Etapa = $Title
    Exit-WinForgeAction -Embedded:$Embedded

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
        -Notes @(
            "Arquivos em uso serão ignorados automaticamente.",
            "Pastas pessoais (Área de Trabalho, Documentos, Downloads, Imagens) não são tocadas."
        ) `
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
        -Notes @(
            "Arquivos em uso serão ignorados automaticamente.",
            "Pastas como Prefetch, SoftwareDistribution e WinSxS não são tocadas."
        ) `
        -Embedded:$Embedded -PassThru:$PassThru
}


# ---------------------------------------------------------------------------
# Lixeira
# ---------------------------------------------------------------------------

function Get-WinForgeRecycleBinItemCount {
    # $null quando o Windows não informa (sem Shell.Application, sessão sem shell).
    try {
        $shell = New-Object -ComObject Shell.Application
        $bin = $shell.Namespace(0xA)

        return @($bin.Items()).Count
    }
    catch {
        return $null
    }
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
        [switch]$PassThru
    )

    $title = "Esvaziar a Lixeira"

    Enter-WinForgeAction -Title $title -Embedded:$Embedded

    $result = $null

    try {
        $count = Get-WinForgeRecycleBinItemCount

        if ($count -eq 0) {
            Write-WinForgeStatus -Type Success -Message "A Lixeira já está vazia."
            $result = New-WinForgeResult -Kind Ok -Detail "já estava vazia"
        }
        else {
            if ($null -ne $count) {
                Write-WinForgeKeyValue -Label "Itens na Lixeira" -Value $count
                Write-Host ""
            }

            if (-not $Embedded) {
                Write-Host "Esvazia a Lixeira de todas as unidades. Os itens serão removidos permanentemente." -ForegroundColor Yellow
                Write-Host ""
            }

            if (-not $Embedded -and -not (Confirm-WinForgeAction "Deseja esvaziar a Lixeira?" -DefaultKey N)) {
                Write-WinForgeStatus -Type Warning -Message "Operação cancelada."
                $result = New-WinForgeResult -Kind Skipped -Detail "cancelado pelo usuário"
            }
            else {
                try {
                    Clear-RecycleBin -Force -ErrorAction Stop
                    Write-WinForgeStatus -Type Success -Message "Lixeira esvaziada."
                    $result = New-WinForgeResult -Kind Ok
                }
                catch {
                    if (Test-WinForgeRecycleBinEmptyError -Message $_.Exception.Message -HResult $_.Exception.HResult) {
                        Write-WinForgeStatus -Type Success -Message "A Lixeira já estava vazia ou sem dados encontrados."
                        $result = New-WinForgeResult -Kind Ok -Detail "já estava vazia"
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
    Exit-WinForgeAction -Embedded:$Embedded

    if ($PassThru) {
        return $result
    }
}


# ---------------------------------------------------------------------------
# Limpeza rápida (temporários + Lixeira)
# ---------------------------------------------------------------------------

function Invoke-WinForgeQuickCleanup {
    param (
        [switch]$Embedded,
        [switch]$PassThru
    )

    $title = "Limpeza rápida"

    Enter-WinForgeAction -Title $title -Embedded:$Embedded

    $result = $null

    try {
        $proceed = $true

        if (-not $Embedded) {
            Write-Host "Limpa os temporários do seu usuário e do Windows e esvazia a Lixeira." -ForegroundColor Yellow
            Write-Host "Documentos, Downloads e outros arquivos pessoais não são tocados." -ForegroundColor Yellow
            Write-Host ""

            $proceed = Confirm-WinForgeAction "Deseja continuar?" -DefaultKey S
        }

        if (-not $proceed) {
            Write-WinForgeStatus -Type Warning -Message "Operação cancelada."
            $result = New-WinForgeResult -Kind Skipped -Detail "cancelado pelo usuário"
        }
        else {
            $parts = @(
                (Clear-WinForgeUserTemp -Embedded -PassThru),
                (Clear-WinForgeWindowsTemp -Embedded -PassThru),
                (Clear-WinForgeRecycleBin -Embedded -PassThru)
            )

            $failed = @($parts | Where-Object { $_.Kind -eq "Failed" })

            # Cada parte conta o que liberou; a soma dá o balanço da limpeza inteira (a Lixeira não informa tamanho).
            $freed = [int64]0

            foreach ($part in $parts) {
                $partFreed = Get-WinForgeResultData -Result $part -Name "FreedBytes"
                if ($null -ne $partFreed) { $freed += [int64]$partFreed }
            }

            Write-WinForgeSection -Title "Resumo"
            Write-WinForgeKeyValue -Label "Espaço liberado" -Value (Format-WinForgeBytes -Bytes $freed)
            Write-WinForgeStatus -Type Info -Message "O total considera os temporários; o conteúdo da Lixeira não entra na conta."

            $data = @{ FreedBytes = $freed }

            if ($failed.Count -eq 0) {
                $result = New-WinForgeResult -Kind Ok -Data $data
            }
            elseif ($failed.Count -lt $parts.Count) {
                $result = New-WinForgeResult -Kind Warning -Detail "$($failed.Count) de $($parts.Count) partes falharam" -Data $data
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
    Exit-WinForgeAction -Embedded:$Embedded

    if ($PassThru) {
        return $result
    }
}


# ---------------------------------------------------------------------------
# Downloads
# ---------------------------------------------------------------------------

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


function Get-WinForgeDownloadsItems {
    param (
        [Parameter(Mandatory)]
        [string]$Path
    )

    return @(
        Get-ChildItem -LiteralPath $Path -Force -ErrorAction SilentlyContinue |
            Where-Object { -not (Test-WinForgeShellMetadata -Item $_) }
    )
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
    Quantos dias sem alteração. Na interface gráfica oferece valores prontos; "Outro valor" (e o console)
    pedem o número digitado. Retorna $null se o valor for inválido ou se o usuário desistir.
    #>
    if (Test-WinForgeGuiPrompts) {
        $key = Read-WinForgeChoice -Message "Remover itens sem alteração há quantos dias?" -DefaultKey "30" -Options @(
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

    $daysText = Read-WinForgeText -Message "Remover itens sem alteração há quantos dias? (ENTER = 30)"

    if ([string]::IsNullOrWhiteSpace($daysText)) {
        return 30
    }

    # [0-9] e não \d: \d aceita dígitos de outros alfabetos, que [int] não converte.
    if ($daysText -notmatch "^[0-9]{1,5}$") {
        return $null
    }

    $days = [int]$daysText

    if ($days -lt 1) {
        return $null
    }

    return $days
}


function Show-WinForgeDownloadsPreview {
    param (
        [Parameter(Mandatory)]
        [object[]]$Selected,

        [int]$Top = 15
    )

    Write-WinForgeSection -Title "Prévia (maiores primeiro)"

    foreach ($entry in ($Selected | Sort-Object SizeBytes -Descending | Select-Object -First $Top)) {
        $suffix = if ($entry.IsDirectory) { "\" } else { "" }
        $nameText = ($entry.Name + $suffix)

        if ($nameText.Length -gt 44) {
            $nameText = $nameText.Substring(0, 41) + "..."
        }

        Write-Host ("  {0}  {1,10}  {2:dd/MM/yyyy}" -f $nameText.PadRight(44), (Format-WinForgeBytes -Bytes $entry.SizeBytes), $entry.LastActivity) -ForegroundColor Gray
    }

    if ($Selected.Count -gt $Top) {
        Write-Host "  ... e mais $($Selected.Count - $Top) item(ns)." -ForegroundColor DarkGray
    }
}


function Clear-WinForgeDownloads {
    Enter-WinForgeAction -Title "Limpar a pasta Downloads"

    try {
        $downloadsPath = Get-WinForgeDownloadsPath

        if (-not (Test-Path -LiteralPath $downloadsPath -PathType Container)) {
            Write-WinForgeStatus -Type Error -Message "Pasta Downloads não encontrada: $downloadsPath"
            Exit-WinForgeAction
            return
        }

        if (Test-WinForgeUserContextMismatch) {
            Write-WinForgeStatus -Type Warning -Message "Elevado com outra conta: esta é a pasta Downloads de $env:USERNAME, não a do usuário logado."
            Write-Host ""
        }

        $allItems = @(Get-WinForgeDownloadsItems -Path $downloadsPath)

        Write-WinForgeKeyValue -Label "Pasta" -Value $downloadsPath
        Write-WinForgeKeyValue -Label "Itens encontrados" -Value $allItems.Count
        Write-Host ""

        if ($allItems.Count -eq 0) {
            Write-WinForgeStatus -Type Success -Message "A pasta Downloads já está vazia."
            Exit-WinForgeAction
            return
        }

        $mode = Read-WinForgeChoice -Message "O que deseja limpar?" -ShowMenu -Options @(
            @{ Key = "1"; Label = "Itens mais antigos que N dias"; Description = "recomendado"; Accent = $true },
            @{ Key = "2"; Label = "Tudo" },
            @{ Key = "0"; Label = "Cancelar"; Exit = $true }
        )

        if ($mode -ne "1" -and $mode -ne "2") {
            Write-WinForgeStatus -Type Warning -Message "Limpeza cancelada."
            Exit-WinForgeAction
            return
        }

        $days = $null

        if ($mode -eq "1") {
            $days = Read-WinForgeDaysThreshold

            if ($null -eq $days) {
                Write-WinForgeStatus -Type Error -Message "Valor inválido. Informe um número inteiro de dias (1 ou mais). Operação cancelada."
                Exit-WinForgeAction
                return
            }
        }

        Write-WinForgeStatus -Type Running -Message "Analisando os itens..."

        $entries = @(
            foreach ($item in $allItems) {
                $stats = Get-WinForgePathStats -Path $item.FullName -ExcludeShellMetadata
                $lastActivity = $item.LastWriteTime

                if ($item.PSIsContainer -and $stats.Newest -gt $lastActivity) {
                    # Uma pasta antiga com arquivo novo dentro não é "antiga".
                    $lastActivity = $stats.Newest
                }

                [PSCustomObject]@{
                    Item         = $item
                    Name         = $item.Name
                    IsDirectory  = [bool]$item.PSIsContainer
                    LastActivity = $lastActivity
                    SizeBytes    = $stats.Size
                }
            }
        )

        if ($null -ne $days) {
            $selected = @(Select-WinForgeItemsOlderThan -Entries $entries -Cutoff (Get-Date).AddDays(-$days))
        }
        else {
            $selected = $entries
        }

        Write-Host ""

        if ($selected.Count -eq 0) {
            Write-WinForgeStatus -Type Success -Message "Nenhum item corresponde ao critério."
            Exit-WinForgeAction
            return
        }

        $selectedBytes = ($selected | Measure-Object -Property SizeBytes -Sum).Sum

        Show-WinForgeDownloadsPreview -Selected $selected

        Write-Host ""
        Write-WinForgeKeyValue -Label "Itens selecionados" -Value $selected.Count
        Write-WinForgeKeyValue -Label "Espaço a liberar" -Value (Format-WinForgeBytes -Bytes $selectedBytes)
        Write-Host ""

        $destination = Read-WinForgeChoice -Message "O que fazer com estes $($selected.Count) item(ns)?" -ShowMenu -Options @(
            @{ Key = "L"; Label = "Enviar para a Lixeira"; Description = "recomendado: dá para recuperar"; Accent = $true },
            @{ Key = "P"; Label = "Excluir permanentemente"; Description = "não dá para recuperar" },
            @{ Key = "0"; Label = "Cancelar"; Exit = $true }
        )

        if ($destination -ne "L" -and $destination -ne "P") {
            Write-WinForgeStatus -Type Warning -Message "Limpeza cancelada."
            Exit-WinForgeAction
            return
        }

        $permanent = ($destination -eq "P")

        if ($permanent) {
            Write-Host ""
            Write-WinForgeStatus -Type Warning -Message "Os itens serão removidos permanentemente e não poderão ser recuperados."

            if (-not (Confirm-WinForgeAction "Confirma a exclusão permanente de $($selected.Count) item(ns)?" -DefaultKey N)) {
                Write-WinForgeStatus -Type Warning -Message "Limpeza cancelada."
                Exit-WinForgeAction
                return
            }
        }
        else {
            Write-WinForgeStatus -Type Info -Message "Itens maiores que o limite da Lixeira podem ser excluídos em definitivo pelo Windows."
        }

        Write-Host ""

        $deletedItems = 0
        $skippedItems = 0
        $movedBytes = [int64]0
        $position = 0
        $activity = "Limpando Downloads"

        foreach ($entry in $selected) {
            $position++
            Write-WinForgeCleanupProgress -Activity $activity -Current $position -Total $selected.Count

            try {
                if ($permanent) {
                    Remove-WinForgeItem -Path $entry.Item.FullName
                }
                else {
                    Move-WinForgeItemToRecycleBin -Path $entry.Item.FullName -IsDirectory:$entry.IsDirectory
                }

                $deletedItems++
                $movedBytes += [int64]$entry.SizeBytes
            }
            catch {
                $skippedItems++
            }
        }

        Write-WinForgeCleanupProgress -Activity $activity -Current 0 -Total 0 -Completed

        Write-WinForgeStatus -Type Success -Message "Limpeza concluída."

        if ($permanent) {
            Write-WinForgeKeyValue -Label "Itens excluídos" -Value $deletedItems
            Write-WinForgeKeyValue -Label "Espaço liberado" -Value (Format-WinForgeBytes -Bytes $movedBytes)
        }
        else {
            Write-WinForgeKeyValue -Label "Itens enviados à Lixeira" -Value $deletedItems
            Write-WinForgeKeyValue -Label "Tamanho na Lixeira" -Value (Format-WinForgeBytes -Bytes $movedBytes)
        }

        Write-WinForgeKeyValue -Label "Itens ignorados" -Value $skippedItems

        if (-not $permanent -and $deletedItems -gt 0) {
            Write-Host ""
            Write-WinForgeStatus -Type Info -Message "O espaço só volta quando a Lixeira for esvaziada (Limpeza > Esvaziar a Lixeira)."
        }

        if ($skippedItems -gt 0) {
            Write-Host ""
            Write-WinForgeStatus -Type Warning -Message "Alguns itens estavam em uso ou não puderam ser removidos."
        }
    }
    catch {
        Write-WinForgeStatus -Type Error -Message "Falha ao limpar Downloads: $($_.Exception.Message)"
    }

    Exit-WinForgeAction
}


# ---------------------------------------------------------------------------
# Componentes do Windows
# ---------------------------------------------------------------------------

function Invoke-WinForgeComponentCleanup {
    param (
        [switch]$Embedded,
        [switch]$PassThru
    )

    Invoke-WinForgeTool `
        -Title "Limpar componentes do Windows (WinSxS)" `
        -FilePath "dism.exe" `
        -Arguments @("/Online", "/Cleanup-Image", "/StartComponentCleanup") `
        -Description @("Remove versões antigas de componentes substituídos por atualizações.") `
        -Warnings @("Operação segura e oficial; pode levar vários minutos. Não usa /ResetBase, então você ainda poderá desinstalar atualizações recentes.") `
        -Embedded:$Embedded -PassThru:$PassThru
}


Export-ModuleMember -Function *
