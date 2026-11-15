# Ferramentas de limpeza que mexem em arquivos da pessoa: atalhos quebrados, arquivos duplicados, restos de programas
# removidos e o apagamento do espaço livre. Tudo o que é removido vai para a Lixeira (dá para voltar atrás por ela), nada
# vem marcado quando o arquivo pode ser da pessoa, e cada remoção fica no Histórico de mudanças.


# ---------------------------------------------------------------------------
# Atalhos quebrados
# ---------------------------------------------------------------------------

function Get-WinForgeShortcutFolders {
    # Onde ficam os atalhos que a pessoa vê: a Área de Trabalho e o Menu Iniciar, dela e de todos os usuários (estes pedem
    # Administrador para remover).
    $folders = @()

    foreach ($entry in @(
            @{ Name = "Desktop"; Label = "Área de Trabalho"; Admin = $false; Recurse = $false },
            @{ Name = "CommonDesktopDirectory"; Label = "Área de Trabalho (todos os usuários)"; Admin = $true; Recurse = $false },
            @{ Name = "Programs"; Label = "Menu Iniciar"; Admin = $false; Recurse = $true },
            @{ Name = "CommonPrograms"; Label = "Menu Iniciar (todos os usuários)"; Admin = $true; Recurse = $true }
        )) {
        $path = ""
        try { $path = [string][Environment]::GetFolderPath($entry.Name) } catch { $path = "" }

        if ($path -and (Test-Path -LiteralPath $path -PathType Container)) {
            $folders += [PSCustomObject]@{ Path = $path; Label = $entry.Label; Admin = $entry.Admin; Recurse = $entry.Recurse }
        }
    }

    return @($folders)
}


function Find-WinForgeBrokenShortcuts {
    # Atalhos (.lnk) cujo destino é um caminho num disco fixo do PC que não existe mais (pendrive, HD externo e unidade de
    # rede não contam: Test-WinForgeLocalPathMissing). Atalhos sem destino de arquivo (aplicativos da Store) e os
    # anunciados do Windows Installer (Test-WinForgeAdvertisedShortcut) ficam de fora. Devolve Path, Name, Target,
    # Location, Admin e Synced: o atalho está numa pasta do OneDrive, que vai para todos os PCs da pessoa; o programa
    # pode estar instalado só no outro PC, e mandar o atalho para a Lixeira aqui o apagaria lá também.
    # O atalho guarda o destino relativo a %ProgramFiles% de quem o criou, e o Windows o devolve com o %ProgramFiles% de
    # quem lê: o atalho que um instalador de 32 bits criou para "Program Files (x86)" chega a este PowerShell de 64 bits
    # como "Program Files". Por isso o destino só falta quando não existe nem na tradução de 32 bits (-Wow64), como no
    # registro; sem isso, atalhos que funcionam iriam para a Lixeira.
    param (
        [object[]]$Folders = @(Get-WinForgeShortcutFolders)
    )

    $found = @()
    $windows = $(if (-not [string]::IsNullOrWhiteSpace($env:WINDIR)) { $env:WINDIR } else { $env:SystemRoot })
    $installerCache = $(if ($windows) { $windows.TrimEnd('\') + "\Installer" } else { "" })

    foreach ($folder in $Folders) {
        $files = @(Get-ChildItem -LiteralPath $folder.Path -Filter "*.lnk" -File -Recurse:([bool]$folder.Recurse) -Force -ErrorAction SilentlyContinue)

        foreach ($file in $files) {
            if (Test-WinForgeAdvertisedShortcut -Path $file.FullName) { continue }

            $link = Get-WinForgeShortcutTarget -Path $file.FullName

            if ($null -eq $link -or [string]::IsNullOrWhiteSpace($link.TargetPath)) { continue }
            if ($installerCache -and ([string]$link.TargetPath).StartsWith($installerCache + "\", [StringComparison]::OrdinalIgnoreCase)) { continue }
            if (-not (Test-WinForgeLocalPathMissing -Path $link.TargetPath -Wow64)) { continue }

            $found += [PSCustomObject]@{
                Path     = $file.FullName
                Name     = [IO.Path]::GetFileNameWithoutExtension($file.Name)
                Target   = [string]$link.TargetPath
                Location = $folder.Label
                Admin    = [bool]$folder.Admin
                Synced   = (Test-WinForgeOneDrivePath -Path $file.FullName)
            }
        }
    }

    return @($found)
}


function Remove-WinForgeBrokenShortcuts {
    $title = "Remover atalhos quebrados"

    Enter-WinForgeAction -Title $title

    $final = New-WinForgeResult -Kind Ok -Title $title

    try {
        Write-Progress -Activity $title -Status "conferindo os atalhos da Área de Trabalho e do Menu Iniciar"

        try {
            $broken = @(Find-WinForgeBrokenShortcuts)
        }
        finally {
            Write-Progress -Activity $title -Completed
        }

        if ($broken.Count -eq 0) {
            Write-WinForgeStatus -Type Success -Message "Nenhum atalho quebrado na Área de Trabalho nem no Menu Iniciar."
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Ok -Detail "nenhum atalho quebrado" -Title $title)
            return
        }

        $isAdmin = Test-WinForgeAdministrator
        $usable = @($broken | Where-Object { $isAdmin -or -not $_.Admin })
        $locked = $broken.Count - $usable.Count

        foreach ($group in @($broken | Group-Object -Property Location)) {
            Write-WinForgeKeyValue -Label $group.Name -Value (Format-WinForgeCount -Count $group.Count -One "atalho quebrado" -Many "atalhos quebrados") -LabelWidth 36
        }

        Write-Host ""

        if ($locked -gt 0) {
            Write-WinForgeStatus -Type Info -Message "$(Format-WinForgeCount -Count $locked -One 'atalho é' -Many 'atalhos são') de todos os usuários: para removê-$(if ($locked -eq 1) { 'lo' } else { 'los' }), feche o WinForge, abra de novo e aceite o aviso do Windows."
        }

        if ($usable.Count -eq 0) {
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Warning -Detail "os atalhos quebrados exigem Administrador" -Title $title)
            return
        }

        # Os atalhos vão para a Lixeira (a pergunta já diz), e dá para devolver qualquer um por lá.
        [void](Write-WinForgeOtherAccountNotice -What "os atalhos pessoais da Área de Trabalho e do Menu Iniciar")

        $synced = @($usable | Where-Object { $_.Synced }).Count

        # Um atalho do OneDrive pode ser de um programa instalado em outro PC da pessoa.
        if ($synced -gt 0) {
            Write-WinForgeStatus -Type Info -Message "$(Format-WinForgeCount -Count $synced -One 'atalho fica no OneDrive e vem desmarcado' -Many 'atalhos ficam no OneDrive e vêm desmarcados'): o que sai daqui sai dos seus outros PCs."
        }

        Write-Host ""

        $options = @(
            for ($i = 0; $i -lt $usable.Count; $i++) {
                $where = $(if ($usable[$i].Synced) { "$($usable[$i].Location), no OneDrive" } else { $usable[$i].Location })
                @{ Key = [string]$i; Label = $usable[$i].Name; Description = "$where · apontava para $($usable[$i].Target)"; Selected = (-not $usable[$i].Synced) }
            }
        )

        $picked = Read-WinForgeMultiSelect -Message "Marque os atalhos que devem ir para a Lixeira" -Options $options

        if ($null -eq $picked -or @($picked).Count -eq 0) {
            Write-WinForgeStatus -Type Warning -Message "Operação cancelada."
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Skipped -Detail "cancelado pelo usuário" -Title $title)
            return
        }

        $chosen = @(foreach ($key in @($picked)) { $usable[[int]$key] })
        $removed = @()
        $failed = @()

        try {
            foreach ($shortcut in $chosen) {
                try {
                    # Um item aberto por outro programa faria o Windows mostrar a janela "Arquivo em uso", que pararia a
                    # ação esperando resposta (às vezes atrás da janela do WinForge): ele fica de fora antes disso.
                    if (Test-WinForgeItemInUse -Path $shortcut.Path) { throw "está aberto em outro programa; feche-o e tente de novo" }

                    Move-WinForgeItemToRecycleBin -Path $shortcut.Path
                    $removed += $shortcut.Name
                }
                catch {
                    $failed += $shortcut.Name
                    Write-WinForgeStatus -Type Error -Message "$($shortcut.Name): $($_.Exception.Message.TrimEnd('.'))."
                }
            }
        }
        finally {
            # No finally: parar a ação no meio não deixa sem anotação o que já foi para a Lixeira.
            if ($removed.Count -gt 0) {
                [void](Add-WinForgeChange -Action "Atalhos quebrados" -Text "$(Join-WinForgeList -Items $removed) $(if ($removed.Count -eq 1) { 'foi' } else { 'foram' }) para a Lixeira")
            }
        }

        if ($removed.Count -gt 0) {
            Write-WinForgeStatus -Type Success -Message "$(Format-WinForgeCount -Count $removed.Count -One 'atalho foi' -Many 'atalhos foram') para a Lixeira."
        }

        if ($failed.Count -eq 0) { $final = New-WinForgeResult -Kind Ok -Detail (Format-WinForgeCount -Count $removed.Count -One "atalho removido" -Many "atalhos removidos") -Title $title }
        elseif ($removed.Count -eq 0) { $final = New-WinForgeResult -Kind Failed -Detail "nenhum atalho foi removido: $(Join-WinForgeList -Items $failed)" -Title $title }
        else { $final = New-WinForgeResult -Kind Warning -Detail "$($failed.Count) de $($chosen.Count) não foram removidos: $(Join-WinForgeList -Items $failed)" -Title $title }
    }
    catch {
        Write-WinForgeStatus -Type Error -Message "Não foi possível conferir os atalhos: $($_.Exception.Message.TrimEnd('.'))."
        $final = New-WinForgeResult -Kind Failed -Detail $_.Exception.Message.TrimEnd('.') -Title $title
    }

    Exit-WinForgeAction -Result $final
}


# ---------------------------------------------------------------------------
# Arquivos duplicados
# ---------------------------------------------------------------------------

function Get-WinForgeProgramFolderNames {
    # Nomes de pasta que guardam programas e jogos em qualquer unidade (D:\Program Files, a biblioteca da Steam...): ali um
    # arquivo repetido é de propósito, e tirar uma das cópias quebra o programa.
    return @("Program Files", "Program Files (x86)", "ProgramData", "WindowsApps", "ModifiableWindowsApps", "XboxGames",
        "SteamLibrary", "steamapps", "Epic Games", "GOG Games")
}


function Get-WinForgeFileDigest {
    <#
    O SHA-256 de um arquivo, lido em blocos de 1 MB: entre um bloco e outro o botão Parar funciona (o Get-FileHash, num
    arquivo de 50 GB, só devolve no fim). -Sample: só os primeiros e os últimos 64 KB, para separar depressa arquivos do
    mesmo tamanho que não são iguais; os que empatam na amostra ainda passam pela conta do arquivo inteiro.
    #>
    param (
        [Parameter(Mandatory)][string]$Path,
        [switch]$Sample
    )

    $sha = [System.Security.Cryptography.SHA256]::Create()
    $stream = $null

    try {
        $stream = New-Object System.IO.FileStream -ArgumentList $Path, ([IO.FileMode]::Open), ([IO.FileAccess]::Read), ([IO.FileShare]::ReadWrite), 65536
        $buffer = New-Object byte[] 1048576
        $length = [int64]$stream.Length

        if ($Sample) {
            $edge = [int][Math]::Min([int64]65536, $length)
            $positions = @([int64]0)
            if ($length -gt 2 * 65536) { $positions += ($length - 65536) }

            foreach ($position in $positions) {
                [void]$stream.Seek($position, [IO.SeekOrigin]::Begin)
                $filled = 0

                while ($filled -lt $edge) {
                    $read = $stream.Read($buffer, $filled, $edge - $filled)
                    if ($read -le 0) { break }
                    $filled += $read
                }

                [void]$sha.TransformBlock($buffer, 0, $filled, $null, 0)
            }
        }
        else {
            while (($read = $stream.Read($buffer, 0, $buffer.Length)) -gt 0) {
                [void]$sha.TransformBlock($buffer, 0, $read, $null, 0)
            }
        }

        [void]$sha.TransformFinalBlock((New-Object byte[] 0), 0, 0)

        return ([BitConverter]::ToString($sha.Hash) -replace '-', '')
    }
    finally {
        if ($null -ne $stream) { $stream.Dispose() }
        $sha.Dispose()
    }
}


function Find-WinForgeDuplicateGroups {
    <#
    Arquivos com o mesmo conteúdo numa pasta (e subpastas): primeiro pelo tamanho, depois por uma amostra (o começo e o
    fim) e, por último, pelo SHA-256 do arquivo inteiro, só dos que empatam até ali. Arquivos menores que MinBytes, ocultos ou do sistema ficam de fora. Cada grupo: Size, Hash, Keep (o que
    foi criado primeiro, que fica; uma cópia feita no Explorador mantém a data de modificação do original, mas ganha a de
    criação do dia em que foi copiada), Copies (os outros) e Stamps (a data de modificação de cada um, para conferir
    antes de mover). Truncated = parou no limite de arquivos; Links = itens que ficaram de fora por serem atalhos de
    pasta ou arquivos do OneDrive (os que estão só na nuvem seriam baixados um a um para comparar).
    O percurso não entra em atalhos de pasta (junções e links simbólicos): o Get-ChildItem -Recurse do Windows PowerShell
    5.1 entra, e o mesmo arquivo apareceria duas vezes, por dois caminhos; a "cópia" enviada à Lixeira seria o próprio
    original. Pastas ocultas e do sistema, e as de programas e jogos (Get-WinForgeProgramFolderNames), também ficam de
    fora, e a contagem para assim que chega ao limite (sem listar a árvore inteira antes).
    #>
    param (
        [Parameter(Mandatory)][string]$Path,
        [int64]$MinBytes = 1MB,
        [int]$MaxFiles = 100000
    )

    $hidden = [IO.FileAttributes]::Hidden -bor [IO.FileAttributes]::System
    $link = [IO.FileAttributes]::ReparsePoint
    $programFolders = @(Get-WinForgeProgramFolderNames)
    $bySize = New-Object "System.Collections.Generic.Dictionary[long, System.Collections.Generic.List[object]]"
    $pending = New-Object "System.Collections.Generic.Stack[string]"
    $scanned = 0
    $links = 0
    $truncated = $false

    $pending.Push($Path)

    while ($pending.Count -gt 0 -and -not $truncated) {
        try {
            $directory = New-Object System.IO.DirectoryInfo -ArgumentList $pending.Pop()

            foreach ($entry in $directory.EnumerateFileSystemInfos()) {
                try {
                    if (($entry.Attributes -band $hidden) -ne 0) { continue }

                    if (($entry.Attributes -band $link) -ne 0) {
                        $links++
                        continue
                    }

                    if ($entry -is [System.IO.DirectoryInfo]) {
                        if ($programFolders -notcontains $entry.Name) { $pending.Push($entry.FullName) }
                        continue
                    }

                    if ($entry.Length -lt $MinBytes) { continue }

                    $length = [int64]$entry.Length
                    $bucket = $null

                    if (-not $bySize.TryGetValue($length, [ref]$bucket)) {
                        $bucket = New-Object System.Collections.Generic.List[object]
                        $bySize.Add($length, $bucket)
                    }

                    $bucket.Add($entry)
                    $scanned++

                    if ($scanned -ge $MaxFiles) {
                        $truncated = $true
                        break
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

    $sameSize = @($bySize.Values | Where-Object { $_.Count -gt 1 })
    $toHash = 0
    foreach ($bucket in $sameSize) { $toHash += $bucket.Count }

    $groups = New-Object System.Collections.Generic.List[object]
    $hashed = 0

    foreach ($bucket in $sameSize) {
        # Primeiro uma amostra (o começo e o fim de cada arquivo), que separa quase todos os que só têm o mesmo tamanho;
        # a conta do arquivo inteiro fica para os que empatam nela.
        $samples = @{}

        foreach ($file in $bucket) {
            $hashed++

            if ($hashed % 10 -eq 1) {
                Write-Progress -Activity "Procurando arquivos duplicados" -Status "comparando $(Format-WinForgeNumber -Value $hashed) de $(Format-WinForgeNumber -Value $toHash)" -PercentComplete ([int](($hashed - 1) * 100 / [Math]::Max(1, $toHash)))
            }

            try {
                $sample = Get-WinForgeFileDigest -Path $file.FullName -Sample
            }
            catch {
                continue
            }

            if (-not $samples.ContainsKey($sample)) { $samples[$sample] = New-Object System.Collections.Generic.List[object] }
            $samples[$sample].Add($file)
        }

        $hashes = @{}

        foreach ($candidates in @($samples.Values | Where-Object { $_.Count -gt 1 })) {
            foreach ($file in $candidates) {
                Write-Progress -Activity "Procurando arquivos duplicados" -Status "conferindo o conteúdo de $($file.Name)" -PercentComplete ([int](($hashed - 1) * 100 / [Math]::Max(1, $toHash)))

                try {
                    $hash = Get-WinForgeFileDigest -Path $file.FullName
                }
                catch {
                    continue
                }

                if (-not $hashes.ContainsKey($hash)) { $hashes[$hash] = New-Object System.Collections.Generic.List[object] }
                $hashes[$hash].Add($file)
            }
        }

        foreach ($hash in $hashes.Keys) {
            $same = @($hashes[$hash] | Sort-Object -Property CreationTimeUtc, LastWriteTimeUtc, FullName)
            if ($same.Count -lt 2) { continue }

            $stamps = @{}
            foreach ($file in $same) { $stamps[$file.FullName] = [int64]$file.LastWriteTimeUtc.Ticks }

            $groups.Add([PSCustomObject]@{
                    Size   = [int64]$same[0].Length
                    Hash   = $hash
                    Keep   = $same[0].FullName
                    Copies = @($same | Select-Object -Skip 1 | ForEach-Object { $_.FullName })
                    Stamps = $stamps
                })
        }
    }

    Write-Progress -Activity "Procurando arquivos duplicados" -Completed

    return [PSCustomObject]@{
        Groups    = @($groups | Sort-Object -Property @{ Expression = { [int64]$_.Size * $_.Copies.Count }; Descending = $true })
        Scanned   = $scanned
        Truncated = $truncated
        Links     = $links
    }
}


function Test-WinForgeDuplicateFolderSafe {
    <#
    Onde a busca de duplicados pode acontecer: a trava geral (raiz do disco, o perfil inteiro, as pastas que contêm o
    Windows ou os programas) e, além dela, nada que seja, contenha ou fique dentro do Windows, de Arquivos de Programas,
    de ProgramData ou dos dados dos programas (AppData Local e Roaming), nem dentro de uma pasta de programas ou jogos
    de outra unidade (Get-WinForgeProgramFolderNames). Ali um arquivo repetido costuma ser de propósito (cada programa
    com a sua cópia), e tirar um deles quebra o programa.
    #>
    param (
        [string]$Path
    )

    if (-not (Test-WinForgeCleanupTargetSafe -Path $Path)) {
        return $false
    }

    foreach ($protected in @($env:WINDIR, $env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:ProgramW6432, $env:ProgramData, $env:LOCALAPPDATA, $env:APPDATA)) {
        if ((Get-WinForgePathRelation -Path $Path -Other $protected) -ne "None") {
            return $false
        }
    }

    $names = @(Get-WinForgeProgramFolderNames)

    foreach ($segment in ([string]$Path).Split([char[]]@('\', '/'), [StringSplitOptions]::RemoveEmptyEntries)) {
        if ($names -contains $segment) { return $false }
    }

    return $true
}


function Get-WinForgeFolderLinkTarget {
    <#
    Para onde aponta a pasta, quando ela (ou uma pasta acima dela) é um atalho de pasta (junção ou link simbólico): a
    trava de cima olha o texto do caminho, e D:\Fotos apontando para C:\Program Files passaria por ela. "" quando nenhuma
    é atalho. As pastas do OneDrive também têm a marca de atalho, mas não apontam para lugar nenhum: não contam.
    #>
    param (
        [string]$Path
    )

    $current = [string]$Path

    while (-not [string]::IsNullOrWhiteSpace($current)) {
        $item = Get-Item -LiteralPath $current -Force -ErrorAction SilentlyContinue

        if ($null -ne $item -and ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            $target = @($item.Target | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) }) | Select-Object -First 1
            if ($target) { return [string]$target }
        }

        $parent = Split-Path -Parent $current
        if ([string]::IsNullOrWhiteSpace($parent) -or $parent -eq $current) { break }
        $current = $parent
    }

    return ""
}


function Select-WinForgeDuplicateFolder {
    # A pasta onde procurar: as mais comuns em botões, ou um caminho digitado (devolvido como foi digitado, mesmo que não
    # exista: quem chama diz que não encontrou, em vez de tratar como cancelado). "" = cancelou.
    $options = @()
    $known = @(
        @{ Key = "D"; Label = "Downloads"; Path = $(try { [string](Get-WinForgeDownloadsPath) } catch { "" }) },
        @{ Key = "I"; Label = "Imagens"; Path = $(try { [string][Environment]::GetFolderPath("MyPictures") } catch { "" }) },
        @{ Key = "M"; Label = "Documentos"; Path = $(try { [string][Environment]::GetFolderPath("MyDocuments") } catch { "" }) },
        @{ Key = "A"; Label = "Área de Trabalho"; Path = $(try { [string][Environment]::GetFolderPath("Desktop") } catch { "" }) }
    )

    foreach ($entry in $known) {
        if ($entry.Path -and (Test-Path -LiteralPath $entry.Path -PathType Container)) {
            $options += @{ Key = $entry.Key; Label = $entry.Label; Description = $entry.Path; Accent = ($options.Count -eq 0) }
        }
    }

    $options += @{ Key = "O"; Label = "Outra pasta"; Description = "por exemplo D:\Fotos" }
    $options += @{ Key = "C"; Label = "Cancelar"; Exit = $true }

    [void](Write-WinForgeOtherAccountNotice -What "as pastas pessoais (Downloads, Imagens, Documentos, Área de Trabalho)")

    $choice = Read-WinForgeChoice -Message "Onde procurar?" -Options $options -DefaultKey "C" -ShowMenu

    if ($choice -eq "O") {
        return [string](ConvertTo-WinForgeScanPath -Text (Read-WinForgeText -Message "Cole o caminho da pasta (ENTER cancela)"))
    }

    $match = @($known | Where-Object { $_.Key -eq $choice }) | Select-Object -First 1

    return $(if ($null -ne $match) { [string]$match.Path } else { "" })
}


function Find-WinForgeDuplicateFiles {
    # -Path: a pasta já escolhida (a etapa das pastas pessoais do Otimizar); sem ele, a tela pergunta onde procurar.
    param (
        [string]$Path = ""
    )

    $title = "Encontrar arquivos duplicados"

    Enter-WinForgeAction -Title $title

    $final = New-WinForgeResult -Kind Ok -Title $title

    try {
        $path = $(if ([string]::IsNullOrWhiteSpace($Path)) { Select-WinForgeDuplicateFolder } else { $Path })

        if ([string]::IsNullOrWhiteSpace($path)) {
            Write-WinForgeStatus -Type Warning -Message "Operação cancelada."
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Skipped -Detail "cancelado pelo usuário" -Title $title)
            return
        }

        # Um caminho digitado que não existe não é desistência: a faixa diz que a pasta não foi encontrada.
        if (-not (Test-Path -LiteralPath $path -PathType Container)) {
            Write-WinForgeStatus -Type Error -Message "Pasta não encontrada: $path"
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Failed -Detail "pasta não encontrada" -Title $title)
            return
        }

        if (-not (Test-WinForgeDuplicateFolderSafe -Path $path)) {
            # Ficam de fora a raiz do disco, o perfil inteiro e as pastas do Windows, dos programas e jogos e dos dados dos
            # programas (AppData e ProgramData).
            Write-WinForgeStatus -Type Error -Message "Por segurança, o WinForge não procura duplicados nesta pasta: escolha uma pasta sua, como Downloads ou Imagens."
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Failed -Detail "pasta recusada por segurança" -Title $title)
            return
        }

        $linkTarget = Get-WinForgeFolderLinkTarget -Path $path

        if ($linkTarget) {
            Write-WinForgeStatus -Type Error -Message "A pasta $path é um atalho para $linkTarget (ou fica dentro de um): escolha a pasta de verdade."
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Failed -Detail "a pasta é um atalho para outra pasta" -Title $title)
            return
        }

        # As cópias vão para a Lixeira; numa unidade sem Lixeira o Windows as apagaria em definitivo. Melhor avisar antes
        # de comparar tudo do que recusar cada cópia no fim.
        $binProblem = Get-WinForgeRecycleBinProblem -Path $path

        if ($binProblem) {
            Write-WinForgeStatus -Type Error -Message "A pasta $path ${binProblem}: o Windows apagaria as cópias em definitivo, sem passar pela Lixeira."
            Write-WinForgeStatus -Type Info -Message "Procure os duplicados numa pasta do disco do PC, ou apague as cópias à mão sabendo que não terão volta."
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Failed -Detail "a pasta $binProblem" -Title $title)
            return
        }

        Write-Progress -Activity "Procurando arquivos duplicados" -Status "listando os arquivos de $path"
        $scan = Find-WinForgeDuplicateGroups -Path $path

        Write-WinForgeKeyValue -Label "Pasta" -Value $path
        Write-WinForgeKeyValue -Label "Arquivos de 1 MB ou mais" -Value (Format-WinForgeNumber -Value $scan.Scanned)

        if ($scan.Truncated) {
            Write-WinForgeStatus -Type Info -Message "A pasta tem arquivos demais; só os primeiros $(Format-WinForgeNumber -Value $scan.Scanned) foram comparados. Escolha uma pasta menor para ver o resto."
        }

        $groups = @($scan.Groups)

        if ($scan.Links -gt 0) {
            Write-WinForgeStatus -Type Info -Message "$(Format-WinForgeCount -Count $scan.Links -One 'item ficou' -Many 'itens ficaram') de fora (atalhos de pasta e arquivos do OneDrive)."
        }

        if ($groups.Count -eq 0) {
            Write-Host ""
            Write-WinForgeStatus -Type Success -Message "Nenhum arquivo duplicado$(if ($scan.Links -gt 0) { ' no que foi comparado' })."
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Ok -Detail "nenhum duplicado" -Title $title)
            return
        }

        $wasted = [int64]0
        $copies = 0
        foreach ($group in $groups) { $wasted += [int64]$group.Size * $group.Copies.Count; $copies += $group.Copies.Count }

        Write-WinForgeKeyValue -Label "Cópias repetidas" -Value (Format-WinForgeNumber -Value $copies)
        Write-WinForgeKeyValue -Label "Espaço ocupado por elas" -Value (Format-WinForgeBytes -Bytes $wasted)
        Write-Host ""
        Write-WinForgeStatus -Type Info -Message "O arquivo mais antigo de cada grupo fica de fora da lista; nada vem marcado."
        if (Test-WinForgeRecycleBinLimitExceeded -Items @($groups | ForEach-Object { [PSCustomObject]@{ Path = [string]$_.Keep; Size = [int64]$_.Size } }) -SizeProperty "Size") {
            Write-WinForgeStatus -Type Info -Message "Uma cópia maior que o limite da Lixeira fica onde está: o Windows a apagaria em definitivo."
        }

        Write-Host ""

        $entries = New-Object System.Collections.Generic.List[object]
        foreach ($group in $groups) {
            foreach ($copy in $group.Copies) {
                $entries.Add([PSCustomObject]@{ Path = $copy; Size = $group.Size; Keep = $group.Keep; Stamp = [int64]$group.Stamps[$copy]; KeepStamp = [int64]$group.Stamps[$group.Keep] })
            }
        }

        $shown = @($entries | Select-Object -First 300)

        if ($entries.Count -gt $shown.Count) {
            # Os grupos vêm dos que mais ocupam: a lista mostra as maiores cópias, e a pessoa precisa saber que há mais.
            Write-WinForgeStatus -Type Info -Message "Só as $($shown.Count) maiores de $(Format-WinForgeNumber -Value $entries.Count) cópias aparecem; depois de limpar, procure de novo."
        }
        $base = $path.TrimEnd('\') + '\'
        $relative = { param ($Full) $(if ($Full.StartsWith($base, [StringComparison]::OrdinalIgnoreCase)) { $Full.Substring($base.Length) } else { $Full }) }

        $options = @(
            for ($i = 0; $i -lt $shown.Count; $i++) {
                @{ Key = [string]$i; Label = (& $relative $shown[$i].Path); Description = "$(Format-WinForgeBytes -Bytes $shown[$i].Size) · igual a $(& $relative $shown[$i].Keep)"; Selected = $false }
            }
        )

        $picked = Read-WinForgeMultiSelect -Message "Marque as cópias que devem ir para a Lixeira" -Options $options

        if ($null -eq $picked -or @($picked).Count -eq 0) {
            Write-WinForgeStatus -Type Warning -Message "Operação cancelada."
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Skipped -Detail "cancelado pelo usuário" -Title $title)
            return
        }

        $chosen = @(foreach ($key in @($picked)) { $shown[[int]$key] })
        $question = "Enviar $(Format-WinForgeCount -Count $chosen.Count -One 'cópia' -Many 'cópias') para a Lixeira?"

        # São arquivos pessoais (fotos, documentos): Não como padrão, como nos restos de programas.
        if (-not (Confirm-WinForgeAction -Message $question -DefaultKey "N")) {
            Write-WinForgeStatus -Type Warning -Message "Operação cancelada."
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Skipped -Detail "cancelado pelo usuário" -Title $title)
            return
        }

        $freed = [int64]0
        $moved = 0
        $failed = @()

        try {
            foreach ($entry in $chosen) {
                try {
                    # A cópia só sai se os dois arquivos continuam como na busca: o que fica, lá e com o mesmo tamanho;
                    # os dois, com a mesma data de modificação. Entre a busca e agora um deles pode ter sido apagado,
                    # movido ou alterado (um disco virtual ou uma caixa do Outlook muda por dentro sem mudar de tamanho),
                    # e aí a "cópia" seria a única versão que sobrou.
                    $kept = Get-Item -LiteralPath $entry.Keep -Force -ErrorAction SilentlyContinue
                    $copy = Get-Item -LiteralPath $entry.Path -Force -ErrorAction SilentlyContinue

                    if ([string]::Equals([string]$entry.Keep, [string]$entry.Path, [StringComparison]::OrdinalIgnoreCase) -or
                        $null -eq $kept -or $kept.PSIsContainer -or [int64]$kept.Length -ne [int64]$entry.Size -or
                        [int64]$kept.LastWriteTimeUtc.Ticks -ne [int64]$entry.KeepStamp) {
                        throw "o arquivo que ficaria ($(& $relative $entry.Keep)) sumiu ou mudou; esta cópia ficou onde estava"
                    }

                    if ($null -eq $copy -or [int64]$copy.Length -ne [int64]$entry.Size -or [int64]$copy.LastWriteTimeUtc.Ticks -ne [int64]$entry.Stamp) {
                        throw "mudou depois da busca e pode não ser mais igual; ficou onde estava"
                    }

                    if (Test-WinForgeItemInUse -Path $entry.Path) { throw "está aberto em outro programa; feche-o e tente de novo" }

                    Move-WinForgeItemToRecycleBin -Path $entry.Path -SizeBytes ([int64]$entry.Size)
                    $freed += [int64]$entry.Size
                    $moved++
                }
                catch {
                    $failed += [IO.Path]::GetFileName($entry.Path)
                    Write-WinForgeStatus -Type Error -Message "$([IO.Path]::GetFileName($entry.Path)): $($_.Exception.Message.TrimEnd('.'))."
                }
            }
        }
        finally {
            # No finally: parar a ação no meio não deixa sem anotação o que já foi para a Lixeira.
            if ($moved -gt 0) {
                [void](Add-WinForgeChange -Action "Arquivos duplicados" -Text "$(Format-WinForgeCount -Count $moved -One 'cópia' -Many 'cópias') de $path $(if ($moved -eq 1) { 'foi' } else { 'foram' }) para a Lixeira")
            }
        }

        if ($moved -gt 0) {
            Write-WinForgeStatus -Type Success -Message "$(Format-WinForgeCount -Count $moved -One 'cópia foi' -Many 'cópias foram') para a Lixeira ($(Format-WinForgeBytes -Bytes $freed)). O espaço só volta ao esvaziar a Lixeira (Limpeza > Esvaziar a Lixeira)."
        }

        $data = @{ FreedBytes = $freed }

        if ($failed.Count -eq 0) {
            $final = New-WinForgeResult -Kind Ok -Detail "$(Format-WinForgeCount -Count $moved -One 'cópia enviada' -Many 'cópias enviadas') para a Lixeira" -Title $title -Data $data
            [void](Set-WinForgeRecycleBinNext -Result $final -Count $moved -Bytes $freed -One "cópia" -Many "cópias")
        }
        elseif ($moved -eq 0) { $final = New-WinForgeResult -Kind Failed -Detail "nenhuma cópia foi para a Lixeira" -Title $title }
        else { $final = New-WinForgeResult -Kind Warning -Detail "$($failed.Count) de $($chosen.Count) não foram para a Lixeira" -Title $title -Data $data }
    }
    catch {
        Write-Progress -Activity "Procurando arquivos duplicados" -Completed
        Write-WinForgeStatus -Type Error -Message "Não foi possível procurar duplicados: $($_.Exception.Message.TrimEnd('.'))."
        $final = New-WinForgeResult -Kind Failed -Detail $_.Exception.Message.TrimEnd('.') -Title $title
    }

    Exit-WinForgeAction -Result $final
}


# ---------------------------------------------------------------------------
# Restos de programas desinstalados
# ---------------------------------------------------------------------------

function Test-WinForgeGenericLeftoverName {
    <#
    Verdadeiro para um nome que não identifica um programa: pastas do Windows e de fabricantes (Windows, Microsoft...,
    Common Files, Intel, NVIDIA), nomes de uso geral (Update, Programs, Packages), idiomas (pt-BR), arquiteturas (x64),
    números e nomes com menos de 4 letras. Uma pasta com um nome assim existe em muitos PCs e é de outros programas ou
    do próprio Windows: nunca vira "resto".
    #>
    param (
        [AllowEmptyString()][string]$Name
    )

    $text = ([string]$Name).Trim()

    if ($text.Length -lt 4) { return $true }
    if ($text -match '[\\/:*?"<>|]' -or $text -match '^[.]+$') { return $true }
    if ($text -match '^[0-9 ._-]+$') { return $true }
    if ($text -match '^[a-z]{2}(-[a-z0-9]{2,4}){0,2}$') { return $true }
    if ($text -match '^(Windows|Microsoft)') { return $true }
    if ($text -match '^[0-9]{2} ?-?bits?$') { return $true }

    $generic = @(
        "Common Files", "Programs", "Program Files", "Packages", "Package Cache", "Update", "Updates", "Updater",
        "Intel", "AMD", "NVIDIA", "NVIDIA Corporation", "Realtek", "Google", "Mozilla", "Adobe", "Apple", "Oracle", "Java",
        "Office", "x64", "x86", "amd64", "arm64", "win32", "win64", "Temp", "Cache", "Caches", "Data", "Logs", "Config",
        "Settings", "Tools", "Apps", "Application", "Applications", "Plugins", "Extensions", "Installer", "Installers",
        "Setup", "Uninstall", "Launcher", "Common", "Shared", "System", "System32", "SysWOW64", "Internet Explorer",
        "Reference Assemblies", "MSBuild", "dotnet", "Crashpad", "CrashDumps", "Default", "Users", "Public",
        "User Data", "Local", "Roaming", "LocalLow", "Fonts", "Drivers", "Runtime", "Runtimes", "Framework", "Client",
        "Server", "Service", "Services", "Helper", "Help", "Support", "Desktop", "Documents", "Downloads",
        # Canais e edições: a última parte de muitos IDs do winget (Google.Chrome.Beta, Ubisoft.Connect, Amazon.Games).
        "Beta", "Preview", "Canary", "Nightly", "Insider", "Insiders", "Stable", "Release", "Community", "Portable",
        "Edition", "Lite", "Free", "Plus", "Professional", "Enterprise", "Standard", "Ultimate", "Home", "Classic",
        "Games", "Connect", "Player", "Reader", "Browser", "Editor", "Viewer", "Manager", "Agent", "Assistant", "Driver",
        "Mobile", "Online", "Studio"
    )

    return ($generic -contains $text)
}


function Test-WinForgeProtectedLeftoverParent {
    # Pastas de primeiro nível em que nada vira "resto": as do Windows e da Microsoft (Microsoft, Windows Defender,
    # Microsoft Office...), Common Files, WindowsApps e Packages. Lá dentro, uma subpasta com o nome de um programa
    # removido costuma ser de um componente do sistema ou compartilhada por vários programas.
    param (
        [AllowEmptyString()][string]$Name
    )

    $text = ([string]$Name).Trim()

    if ($text -match '^(Windows|Microsoft)') { return $true }

    return (@("Common Files", "WindowsApps", "Packages", "Package Cache") -contains $text)
}


function Get-WinForgeLeftoverNames {
    <#
    Os nomes de pasta que um programa desinstalado costuma deixar: o nome sem a versão e o que vem entre parênteses
    ("Mozilla Firefox (x64 pt-BR)" vira "Mozilla Firefox"; "Programa 2.4.1" vira "Programa") e a última parte do ID do
    winget que identifica o programa ("Mozilla.Firefox" e "Mozilla.Firefox.pt-BR" viram "Firefox").
    Só uma versão com ponto (2.4.1, v3.0) é cortada, e o que vem depois dela: "Windows 11 Installation Assistant" e
    "Microsoft 365 Apps" continuam inteiros (cortar no primeiro número deixaria "Windows" e "Microsoft"). Nomes genéricos
    (Test-WinForgeGenericLeftoverName) ficam de fora: casariam com pastas do Windows e de outros programas.
    #>
    param (
        [string]$Name,
        [string]$Id
    )

    $names = @()
    $clean = ([regex]::Replace([string]$Name, '\([^)]*\)', '')).Trim()
    $clean = ([regex]::Replace($clean, '\s+v?[0-9]+([.][0-9]+)+([ -].*)?$', '')).Trim()

    if (-not (Test-WinForgeGenericLeftoverName -Name $clean)) { $names += $clean }

    if (-not [string]::IsNullOrWhiteSpace($Id)) {
        # A última parte que não é idioma, número ou arquitetura ("Python.Python.3.12" -> "Python"); a primeira é o
        # fabricante e fica de fora.
        $parts = @(([string]$Id).Split('.') | Select-Object -Skip 1)
        [array]::Reverse($parts)

        foreach ($part in $parts) {
            if (-not (Test-WinForgeGenericLeftoverName -Name $part)) {
                $names += $part.Trim()
                break
            }
        }
    }

    return @($names | Select-Object -Unique)
}


function Get-WinForgeLeftoverRoots {
    # As pastas onde os programas se instalam e guardam dados. Admin = remover ali pede Administrador; Data = é onde os
    # programas guardam configurações, perfis e arquivos salvos (o AppData), e a tela avisa.
    $roots = @()

    foreach ($entry in @(
            @{ Path = $env:ProgramFiles; Admin = $true; Data = $false },
            @{ Path = ${env:ProgramFiles(x86)}; Admin = $true; Data = $false },
            @{ Path = $env:ProgramData; Admin = $true; Data = $false },
            @{ Path = $env:LOCALAPPDATA; Admin = $false; Data = $true },
            @{ Path = $env:APPDATA; Admin = $false; Data = $true }
        )) {
        if ($entry.Path -and (Test-Path -LiteralPath $entry.Path -PathType Container)) {
            $roots += [PSCustomObject]@{ Path = [string]$entry.Path; Admin = $entry.Admin; Data = $entry.Data }
        }
    }

    return @($roots | Sort-Object -Property Path -Unique)
}


function Get-WinForgeInstalledProgramNames {
    # Os nomes dos programas instalados (DisplayName nas chaves de desinstalação) e dos aplicativos da Store (também os
    # que o winget instala pela Store), para não apontar como resto a pasta de um programa que continua instalado (ou
    # foi instalado de novo, por outro caminho).
    $names = @()

    foreach ($root in @(Get-WinForgeRegistryRoots -Category "uninstall")) {
        foreach ($key in @(Get-ChildItem -LiteralPath $root -ErrorAction SilentlyContinue)) {
            $value = [string](Get-ItemProperty -LiteralPath $key.PSPath -Name DisplayName -ErrorAction SilentlyContinue).DisplayName
            if ($value) { $names += $value }
        }
    }

    try {
        $names += @(Get-AppxPackage -ErrorAction Stop | ForEach-Object { [string]$_.Name } | Where-Object { $_ })
    }
    catch {
        Write-Verbose "Aplicativos da Store ilegíveis: $($_.Exception.Message)"
    }

    return @($names)
}


function Find-WinForgeLeftoverFolders {
    <#
    Pastas que ficaram de programas desinstalados pelo WinForge: com o nome exato do programa (ou da parte do ID do winget
    que o identifica), no primeiro ou no segundo nível das pastas de programas e de dados, desde que nenhum programa
    instalado tenha esse nome. Nomes genéricos não entram (Get-WinForgeLeftoverNames), e nada dentro das pastas do
    Windows e da Microsoft, de Common Files, WindowsApps e Packages é proposto. No segundo nível, um nome tirado do ID
    só vale dentro da pasta do fabricante (a primeira parte do ID): "Firefox" em Mozilla\Firefox, mas não em
    OutraEmpresa\Firefox. Devolve Path, Program, Size, Admin e Data.
    Cada raiz é listada uma vez só (o primeiro e o segundo nível), e não uma vez por programa e por nome.
    #>
    param (
        [object[]]$Programs = @(Get-WinForgeSetting -Name "UninstalledPrograms" -Default @()),
        [object[]]$Roots = @(Get-WinForgeLeftoverRoots),
        [string[]]$Installed = @(Get-WinForgeInstalledProgramNames)
    )

    $found = @()
    $seen = @{}

    # Os nomes do primeiro e do segundo nível de cada raiz, uma listagem só: nome -> caminhos (com a pasta de cima).
    $levels = @{}

    foreach ($root in $Roots) {
        $first = @{}
        $second = @{}

        # Atalhos de pasta (junções) ficam de fora: mandar um para a Lixeira pode levar junto a pasta para onde ele aponta.
        $link = [IO.FileAttributes]::ReparsePoint

        foreach ($folder in @(Get-ChildItem -LiteralPath $root.Path -Directory -Force -ErrorAction SilentlyContinue)) {
            if (($folder.Attributes -band $link) -ne 0) { continue }

            $first[$folder.Name] = $folder.FullName

            if (Test-WinForgeProtectedLeftoverParent -Name $folder.Name) { continue }

            foreach ($child in @(Get-ChildItem -LiteralPath $folder.FullName -Directory -Force -ErrorAction SilentlyContinue)) {
                if (($child.Attributes -band $link) -ne 0) { continue }
                if (-not $second.ContainsKey($child.Name)) { $second[$child.Name] = @() }
                $second[$child.Name] += [PSCustomObject]@{ Path = $child.FullName; Parent = $folder.Name }
            }
        }

        $levels[$root.Path] = @{ First = $first; Second = $second }
    }

    foreach ($program in @($Programs | Where-Object { $null -ne $_ })) {
        $programName = [string](Get-WinForgeJsonValue -Object $program -Name "Name" -Default "")
        $programId = [string](Get-WinForgeJsonValue -Object $program -Name "Id" -Default "")
        $candidates = @(Get-WinForgeLeftoverNames -Name $programName -Id $programId)
        $fromName = @(Get-WinForgeLeftoverNames -Name $programName)
        $publisher = $(if ($programId.Contains('.')) { ($programId.Split('.')[0] -replace '[^A-Za-z0-9]', '') } else { "" })

        foreach ($candidate in $candidates) {
            # Comparação de texto pura: com -like, colchetes e asteriscos do nome virariam curinga.
            $stillInstalled = $false

            foreach ($installedName in @($Installed)) {
                if (([string]$installedName).IndexOf($candidate, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
                    $stillInstalled = $true
                    break
                }
            }

            if ($stillInstalled) { continue }

            $byIdOnly = ($fromName -notcontains $candidate)

            foreach ($root in $Roots) {
                $level = $levels[$root.Path]
                $paths = @()

                if ($level.First.ContainsKey($candidate)) { $paths += $level.First[$candidate] }

                if ($level.Second.ContainsKey($candidate)) {
                    foreach ($entry in @($level.Second[$candidate])) {
                        $parent = ([string]$entry.Parent) -replace '[^A-Za-z0-9]', ''

                        if ($byIdOnly -and ([string]::IsNullOrEmpty($publisher) -or ($parent.IndexOf($publisher, [StringComparison]::OrdinalIgnoreCase) -lt 0 -and $publisher.IndexOf($parent, [StringComparison]::OrdinalIgnoreCase) -lt 0) -or $parent.Length -lt 3)) { continue }

                        $paths += $entry.Path
                    }
                }

                foreach ($path in $paths) {
                    if ($seen.ContainsKey($path)) { continue }
                    if (-not (Test-WinForgeCleanupTargetSafe -Path $path)) { continue }

                    $seen[$path] = $true
                    $found += [PSCustomObject]@{ Path = $path; Program = $programName; Size = [int64](Get-WinForgePathStats -Path $path).Size; Admin = [bool]$root.Admin; Data = [bool](Get-WinForgeJsonValue -Object $root -Name "Data" -Default $false) }
                }
            }
        }
    }

    return @($found)
}


function Select-WinForgeProgramLeftovers {
    <#
    Procura os restos dos programas desinstalados pelo WinForge e pergunta quais pastas vão para a Lixeira, sem mexer em
    nada. Devolve Chosen (as pastas marcadas) e Result: quando não há o que escolher (nenhum programa, nenhum resto, só
    pastas que pedem Administrador) ou a pessoa desistiu, o WinForge.Result com que a busca termina; senão, $null.
    #>
    param (
        [string]$Title = "Restos de programas desinstalados"
    )

    $end = {
        param ($Result)
        return [PSCustomObject]@{ Chosen = @(); Result = $Result }
    }

    $programs = @(Get-WinForgeSetting -Name "UninstalledPrograms" -Default @())

    # Num PowerShell de 32 bits, as entradas de Aplicativos instalados de 64 bits ficam invisíveis: a pasta de um
    # programa ainda instalado pareceria resto.
    if (Test-WinForgeRegistryViewMismatch) {
        Write-WinForgeStatus -Type Error -Message "Não é possível procurar os restos agora: $(Get-WinForgeRegistryViewMismatchText)."
        return (& $end (New-WinForgeResult -Kind Failed -Detail "PowerShell de 32 bits" -Title $Title))
    }

    if ($programs.Count -eq 0) {
        # Nada foi procurado: "Nada a fazer", e não "Tudo certo".
        Write-WinForgeStatus -Type Info -Message "O WinForge procura restos só dos programas desinstalados por ele, em Programas > Desinstalar programas; nenhum foi desinstalado por lá ainda."
        return (& $end (New-WinForgeResult -Kind Skipped -Detail "nenhum programa desinstalado pelo WinForge" -Title $Title))
    }

    Write-Progress -Activity $Title -Status "procurando pastas com o nome dos programas desinstalados"

    try {
        $leftovers = @(Find-WinForgeLeftoverFolders -Programs $programs)
    }
    finally {
        Write-Progress -Activity $Title -Completed
    }

    Write-WinForgeKeyValue -Label "Programas conferidos" -Value $programs.Count

    if ($leftovers.Count -eq 0) {
        Write-Host ""
        Write-WinForgeStatus -Type Success -Message "Nenhuma pasta ficou para trás."
        return (& $end (New-WinForgeResult -Kind Ok -Detail "nenhum resto encontrado" -Title $Title))
    }

    $isAdmin = Test-WinForgeAdministrator
    $usable = @($leftovers | Where-Object { $isAdmin -or -not $_.Admin })
    $total = [int64]0
    foreach ($item in $leftovers) { $total += [int64]$item.Size }

    Write-WinForgeKeyValue -Label "Pastas encontradas" -Value $leftovers.Count
    Write-WinForgeKeyValue -Label "Espaço" -Value (Format-WinForgeBytes -Bytes $total -ZeroText "0 B")
    Write-Host ""

    if ($usable.Count -lt $leftovers.Count) {
        Write-WinForgeStatus -Type Info -Message "Pastas em Arquivos de Programas e ProgramData pedem Administrador: para incluí-las, feche o WinForge, abra de novo e aceite o aviso do Windows."
    }

    if ($usable.Count -eq 0) {
        return (& $end (New-WinForgeResult -Kind Warning -Detail "as pastas encontradas exigem Administrador" -Title $Title))
    }

    # O que for marcado vai para a Lixeira (a pergunta diz).
    Write-WinForgeStatus -Type Info -Message "Nada vem marcado: confira cada pasta."

    if (Test-WinForgeRecycleBinLimitExceeded -Items $usable -SizeProperty "Size") {
        Write-WinForgeStatus -Type Info -Message "Uma pasta maior que o limite da Lixeira fica onde está: o Windows a apagaria em definitivo."
    }

    if (@($usable | Where-Object { [bool](Get-WinForgeJsonValue -Object $_ -Name "Data" -Default $false) }).Count -gt 0) {
        Write-WinForgeStatus -Type Info -Message "As pastas do AppData guardam configurações e arquivos salvos do programa (perfis, partidas, conversas): confira antes de marcar."
        [void](Write-WinForgeOtherAccountNotice -What "as pastas do AppData")
    }

    Write-Host ""

    $options = @(
        for ($i = 0; $i -lt $usable.Count; $i++) {
            $kind = $(if ([bool](Get-WinForgeJsonValue -Object $usable[$i] -Name "Data" -Default $false)) { " · dados do programa" } else { "" })
            @{ Key = [string]$i; Label = $usable[$i].Path; Description = "de $($usable[$i].Program) · $(Format-WinForgeBytes -Bytes $usable[$i].Size -ZeroText '0 B')$kind"; Selected = $false }
        }
    )

    $picked = Read-WinForgeMultiSelect -Message "Marque as pastas que devem ir para a Lixeira" -Options $options

    if ($null -eq $picked -or @($picked).Count -eq 0) {
        return (& $end (New-WinForgeResult -Kind Skipped -Detail "cancelado pelo usuário" -Title $Title))
    }

    return [PSCustomObject]@{ Chosen = @(foreach ($key in @($picked)) { $usable[[int]$key] }); Result = $null }
}


function Remove-WinForgeProgramLeftovers {
    # Manda para a Lixeira as pastas escolhidas em Select-WinForgeProgramLeftovers, anota no Histórico de mudanças e
    # devolve o WinForge.Result.
    param (
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Items,

        [string]$Title = "Restos de programas desinstalados"
    )

    $moved = @()
    $failed = @()

    try {
        foreach ($item in $Items) {
            try {
                # Sem isto, um arquivo aberto faria o Windows mostrar a janela "Arquivo em uso" e a ação ficaria parada.
                if (Test-WinForgeItemInUse -Path $item.Path -IsDirectory) { throw "há arquivos em uso nesta pasta; feche o programa que os usa e tente de novo" }

                Move-WinForgeItemToRecycleBin -Path $item.Path -IsDirectory -SizeBytes ([int64](Get-WinForgeJsonValue -Object $item -Name "Size" -Default 0))
                $moved += $item
                Write-WinForgeStatus -Type Success -Message "$($item.Path): na Lixeira."
            }
            catch {
                $failed += $item
                Write-WinForgeStatus -Type Error -Message "$($item.Path): $($_.Exception.Message.TrimEnd('.'))."
            }
        }
    }
    finally {
        # No finally: parar a ação no meio não deixa sem anotação o que já foi para a Lixeira.
        if ($moved.Count -gt 0) {
            [void](Add-WinForgeChange -Action "Restos de programas" -Text "$(Join-WinForgeList -Items @($moved | ForEach-Object { $_.Path })) $(if ($moved.Count -eq 1) { 'foi' } else { 'foram' }) para a Lixeira")
        }
    }

    if ($moved.Count -gt 0) {
        Write-WinForgeStatus -Type Info -Message "O espaço só volta ao esvaziar a Lixeira (Limpeza > Esvaziar a Lixeira)."
    }

    if ($failed.Count -eq 0) {
        $movedBytes = [int64]0
        foreach ($item in $moved) { $movedBytes += [int64](Get-WinForgeJsonValue -Object $item -Name "Size" -Default 0) }

        return (Set-WinForgeRecycleBinNext -Result (New-WinForgeResult -Kind Ok -Detail "$(Format-WinForgeCount -Count $moved.Count -One 'pasta enviada' -Many 'pastas enviadas') para a Lixeira" -Title $Title) -Count $moved.Count -Bytes $movedBytes -One "pasta" -Many "pastas")
    }
    if ($moved.Count -eq 0) { return (New-WinForgeResult -Kind Failed -Detail "nenhuma pasta foi para a Lixeira (talvez estejam em uso)" -Title $Title) }

    return (New-WinForgeResult -Kind Warning -Detail "$($failed.Count) de $(@($Items).Count) não foram para a Lixeira" -Title $Title)
}


function Find-WinForgeProgramLeftovers {
    $title = "Restos de programas desinstalados"

    Enter-WinForgeAction -Title $title

    $final = New-WinForgeResult -Kind Ok -Title $title

    try {
        $selection = Select-WinForgeProgramLeftovers -Title $title

        if ($null -ne $selection.Result) {
            if ([string]$selection.Result.Detail -eq "cancelado pelo usuário") { Write-WinForgeStatus -Type Warning -Message "Operação cancelada." }
            Exit-WinForgeAction -Result $selection.Result
            return
        }

        $chosen = @($selection.Chosen)
        $question = Get-WinForgeSelectionQuestion -Verb "Enviar para a Lixeira" -Names @($chosen | ForEach-Object { Split-Path -Leaf $_.Path }) -Many "pastas" -Limit 2

        if (-not (Confirm-WinForgeAction -Message $question -DefaultKey "N")) {
            Write-WinForgeStatus -Type Warning -Message "Operação cancelada."
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Skipped -Detail "cancelado pelo usuário" -Title $title)
            return
        }

        $final = Remove-WinForgeProgramLeftovers -Items $chosen -Title $title
    }
    catch {
        Write-WinForgeStatus -Type Error -Message "Não foi possível procurar os restos: $($_.Exception.Message.TrimEnd('.'))."
        $final = New-WinForgeResult -Kind Failed -Detail $_.Exception.Message.TrimEnd('.') -Title $title
    }

    Exit-WinForgeAction -Result $final
}


# ---------------------------------------------------------------------------
# Apagar o espaço livre
# ---------------------------------------------------------------------------

function Get-WinForgeCipherLeftoverPath {
    # A pasta que o cipher /w cria na raiz da unidade ("C:" -> "C:\EFSTMPWP") e enche até ocupar todo o espaço livre.
    param ([Parameter(Mandatory)][string]$Drive)

    return "$($Drive.TrimEnd('\'))\EFSTMPWP"
}


function Remove-WinForgeCipherLeftover {
    <#
    Apaga a pasta EFSTMPWP que um cipher /w interrompido (botão Parar, erro) deixa na unidade: os arquivos dela ocupam o
    espaço livre inteiro e só o cipher, se terminasse, os tiraria. Devolve $true quando a pasta não existe mais.
    #>
    param ([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) { return $true }

    try {
        Remove-WinForgeItem -Path $Path
    }
    catch {
        Write-Verbose "EFSTMPWP: $($_.Exception.Message)"
    }

    return -not (Test-Path -LiteralPath $Path)
}


function Get-WinForgeWipeDriveText {
    <#
    A descrição de uma unidade na escolha de Apagar o espaço livre: "a do Windows · SSD · 120 GB livres de 476 GB". O tipo
    do disco vem como o Diagnóstico mostra (Get-WinForgeDriveMediaText); sem ele, a descrição fica sem o tipo.
    #>
    param ([Parameter(Mandatory)]$Drive)

    $id = [string]$Drive.DeviceID
    $parts = @()

    try {
        if ($id -ieq (Get-WinForgeSystemDriveLetter)) { $parts += "a do Windows" }
    }
    catch {
        Write-Verbose "Unidade do Windows: $($_.Exception.Message)"
    }

    try {
        $media = Get-WinForgeDriveMediaText -Drive $id
        if ($media -in @("SSD", "NVMe")) { $parts += "SSD" }
        elseif ($media -eq "HDD") { $parts += "HD" }
    }
    catch {
        Write-Verbose "Tipo do disco de ${id}: $($_.Exception.Message)"
    }

    $parts += "$(Format-WinForgeBytes -Bytes ([int64]$Drive.FreeSpace)) livres de $(Format-WinForgeBytes -Bytes ([int64]$Drive.Size))"

    return ($parts -join " · ")
}


function Clear-WinForgeFreeSpace {
    $title = "Apagar o espaço livre"

    Enter-WinForgeAction -Title $title

    $final = New-WinForgeResult -Kind Ok -Title $title

    try {
        if (-not (Test-WinForgeElevation -Reason "Apagar o espaço livre exige privilégios de Administrador.")) {
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Failed -Detail "requer Administrador" -Title $title)
            return
        }

        $drives = @(Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DriveType=3" -ErrorAction Stop | Where-Object { $_.DeviceID } | Sort-Object -Property DeviceID)

        if ($drives.Count -eq 0) {
            Write-WinForgeStatus -Type Error -Message "Nenhuma unidade local foi encontrada."
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Failed -Detail "nenhuma unidade local" -Title $title)
            return
        }

        # Uma gravação anterior interrompida deixa a pasta EFSTMPWP enchendo o disco: oferece tirá-la antes de tudo. Não
        # é apagada sem perguntar: pode ser de um cipher que a pessoa está rodando agora em outra janela.
        foreach ($leftover in @($drives | ForEach-Object { Get-WinForgeCipherLeftoverPath -Drive ([string]$_.DeviceID) } | Where-Object { Test-Path -LiteralPath $_ -PathType Container })) {
            $leftoverSize = [int64](Get-WinForgePathStats -Path $leftover).Size

            Write-WinForgeStatus -Type Warning -Message "Uma gravação do espaço livre que não terminou deixou a pasta $leftover ocupando $(Format-WinForgeBytes -Bytes $leftoverSize -ZeroText '0 B')."

            if (Confirm-WinForgeAction -Message "Apagar a pasta $leftover agora?" -DefaultKey "S") {
                if (Remove-WinForgeCipherLeftover -Path $leftover) {
                    Write-WinForgeStatus -Type Success -Message "Pasta $leftover apagada; o espaço voltou."
                }
                else {
                    Write-WinForgeStatus -Type Error -Message "A pasta $leftover não saiu inteira (algum arquivo em uso). Feche outras janelas que estejam apagando o espaço livre e tente de novo."
                }
            }

            Write-Host ""
        }

        # Serve antes de vender ou doar o PC. O disco é preenchido por inteiro e depois liberado. Num SSD, o próprio Windows
        # já descarta o que foi apagado, e a gravação extra só desgasta o disco.
        Write-WinForgeStatus -Type Info -Message "Grava por cima do espaço livre para que o que já foi apagado não possa ser recuperado; nenhum arquivo é apagado."
        Write-WinForgeStatus -Type Info -Message "Leva horas e enche o disco até o fim: feche os outros programas. Num SSD, use só se precisar (desgasta o disco)."
        Write-Host ""

        # Cada unidade diz se é a do Windows e se é SSD ou HD: o aviso acima vale diferente para cada uma.
        Write-Progress -Activity $title -Status "lendo o tipo dos discos"

        try {
            $options = @(
                foreach ($drive in $drives) {
                    @{ Key = [string]$drive.DeviceID; Label = [string]$drive.DeviceID; Description = (Get-WinForgeWipeDriveText -Drive $drive) }
                }
            )
        }
        finally {
            Write-Progress -Activity $title -Completed
        }

        $options += @{ Key = "X"; Label = "Cancelar"; Exit = $true }

        $answer = [string](Read-WinForgeChoice -Message "Qual unidade?" -Options $options -DefaultKey "X" -ShowMenu)
        $drive = @($drives | Where-Object { [string]$_.DeviceID -eq $answer }) | Select-Object -First 1

        if ($null -eq $drive) {
            Write-WinForgeStatus -Type Warning -Message "Operação cancelada."
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Skipped -Detail "cancelado pelo usuário" -Title $title)
            return
        }

        if (-not (Confirm-WinForgeAction -Message "Apagar o espaço livre de $($drive.DeviceID) agora? O disco fica cheio até terminar." -DefaultKey "N")) {
            Write-WinForgeStatus -Type Warning -Message "Operação cancelada."
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Skipped -Detail "cancelado pelo usuário" -Title $title)
            return
        }

        Write-Progress -Activity $title -Status "gravando por cima do espaço livre de $($drive.DeviceID) (pode levar horas)"

        $leftover = Get-WinForgeCipherLeftoverPath -Drive ([string]$drive.DeviceID)
        $exitCode = $null

        # São horas gravando: com o PC suspenso no meio, o cipher para e o disco fica cheio até ele voltar.
        $keepAwake = $false

        try {
            $keepAwake = [bool](Set-WinForgeKeepAwake -Enabled $true)
            $exitCode = Invoke-WinForgeNative -FilePath "cipher.exe" -Arguments @("/w:$($drive.DeviceID)\") -IgnoreExitCode -PassThru
        }
        finally {
            if ($keepAwake) { [void](Set-WinForgeKeepAwake -Enabled $false) }
            Write-Progress -Activity $title -Completed

            # Interrompido (botão Parar) ou com erro, o cipher não chega a tirar a pasta de preenchimento, e o disco fica
            # cheio. Isto roda também quando a ação é parada; se algum arquivo ainda estiver preso, a próxima abertura
            # desta tela oferece apagar o que sobrou.
            if ($exitCode -ne 0) { [void](Remove-WinForgeCipherLeftover -Path $leftover) }
        }

        if ($exitCode -eq 0) {
            Write-WinForgeStatus -Type Success -Message "Espaço livre de $($drive.DeviceID) apagado."
            $final = New-WinForgeResult -Kind Ok -Detail "espaço livre de $($drive.DeviceID) apagado" -Title $title
        }
        else {
            Write-WinForgeStatus -Type Error -Message "A gravação terminou com erro (código $exitCode)."

            if (Test-Path -LiteralPath $leftover) {
                Write-WinForgeStatus -Type Warning -Message "A pasta $leftover ficou para trás ocupando espaço; abra esta tela de novo para apagá-la."
            }

            $final = New-WinForgeResult -Kind Failed -Detail "a gravação terminou com erro (código $exitCode)" -Title $title
        }
    }
    catch {
        Write-WinForgeStatus -Type Error -Message "Não foi possível apagar o espaço livre: $($_.Exception.Message.TrimEnd('.'))."
        $final = New-WinForgeResult -Kind Failed -Detail $_.Exception.Message.TrimEnd('.') -Title $title
    }

    Exit-WinForgeAction -Result $final
}


Export-ModuleMember -Function *
