function Clear-UserTempFiles {
    Show-Header "Limpar Temporários do Usuário"

    $tempPath = Join-Path $env:LOCALAPPDATA "Temp"

    if (-not (Test-Path $tempPath)) {
        Write-Host "A pasta temporária do usuário não foi encontrada:" -ForegroundColor Red
        Write-Host $tempPath -ForegroundColor Yellow
        Write-Host ""
        Pause
        return
    }

    try {
        $items = Get-ChildItem -Path $tempPath -Force -ErrorAction SilentlyContinue
        $itemCount = @($items).Count

        $sizeBeforeBytes = Get-FolderSizeInBytes -Path $tempPath
        $sizeBeforeText = Convert-WinForgeCleanupBytesToText -Bytes $sizeBeforeBytes

        Write-Host "O WinForge limpará arquivos temporários do perfil do usuário atual." -ForegroundColor Yellow
        Write-Host ""
        Write-WinForgeKeyValue -Label "Pasta" -Value $tempPath
        Write-WinForgeKeyValue -Label "Itens encontrados" -Value $itemCount
        Write-WinForgeKeyValue -Label "Tamanho estimado" -Value $sizeBeforeText
        Write-Host ""
        Write-Host "Arquivos em uso serão ignorados automaticamente." -ForegroundColor Yellow
        Write-Host "Pastas pessoais como Área de Trabalho, Documentos, Downloads e Imagens não serão tocadas." -ForegroundColor Yellow
        Write-Host ""

        if ($itemCount -eq 0) {
            Write-Host "Não há arquivos temporários do usuário para limpar." -ForegroundColor Green
            Write-Host ""
            Pause
            return
        }

        $confirmed = Confirm-Action "Deseja limpar estes arquivos?"

        if ($confirmed -eq $false) {
            Write-Host ""
            Write-Host "Limpeza cancelada." -ForegroundColor Yellow
            Pause
            return
        }

        Write-Host ""
        Write-Host "Limpando arquivos temporários do usuário..." -ForegroundColor Green
        Write-Host ""

        $deletedItems = 0
        $skippedItems = 0

        foreach ($item in $items) {
            try {
                Remove-Item -Path $item.FullName -Recurse -Force -ErrorAction Stop
                $deletedItems++
            }
            catch {
                $skippedItems++
            }
        }

        $remainingItems = @(Get-ChildItem -Path $tempPath -Force -ErrorAction SilentlyContinue).Count

        $sizeAfterBytes = Get-FolderSizeInBytes -Path $tempPath
        $sizeAfterText = Convert-WinForgeCleanupBytesToText -Bytes $sizeAfterBytes

        $cleanedBytes = $sizeBeforeBytes - $sizeAfterBytes

        if ($cleanedBytes -lt 0) {
            $cleanedBytes = 0
        }

        $cleanedText = Convert-WinForgeCleanupBytesToText -Bytes $cleanedBytes

        Write-WinForgeStatus -Type Success -Message "Limpeza concluída."
        Write-WinForgeKeyValue -Label "Itens removidos" -Value $deletedItems
        Write-WinForgeKeyValue -Label "Itens ignorados" -Value $skippedItems
        Write-WinForgeKeyValue -Label "Itens restantes" -Value $remainingItems
        Write-WinForgeKeyValue -Label "Espaço antes" -Value $sizeBeforeText
        Write-WinForgeKeyValue -Label "Espaço depois" -Value $sizeAfterText
        Write-WinForgeKeyValue -Label "Espaço liberado" -Value $cleanedText

        if ($skippedItems -gt 0) {
            Write-Host ""
            Write-Host "Alguns itens foram ignorados porque provavelmente estão em uso pelo Windows ou por aplicativos abertos." -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "Ocorreu um erro ao limpar temporários do usuário:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }

    Write-Host ""
    Pause
}


function Clear-WindowsTempFiles {
    Show-Header "Limpar Temporários do Windows"

    $tempPath = Join-Path $env:WINDIR "Temp"

    if (-not (Test-Path $tempPath)) {
        Write-Host "A pasta temporária do Windows não foi encontrada:" -ForegroundColor Red
        Write-Host $tempPath -ForegroundColor Yellow
        Write-Host ""
        Pause
        return
    }

    try {
        $items = Get-ChildItem -Path $tempPath -Force -ErrorAction SilentlyContinue
        $itemCount = @($items).Count

        $sizeBeforeBytes = Get-FolderSizeInBytes -Path $tempPath
        $sizeBeforeText = Convert-WinForgeCleanupBytesToText -Bytes $sizeBeforeBytes

        Write-Host "O WinForge limpará arquivos temporários da pasta Temp do Windows." -ForegroundColor Yellow
        Write-Host ""
        Write-WinForgeKeyValue -Label "Pasta" -Value $tempPath
        Write-WinForgeKeyValue -Label "Itens encontrados" -Value $itemCount
        Write-WinForgeKeyValue -Label "Tamanho estimado" -Value $sizeBeforeText
        Write-Host ""
        Write-Host "Arquivos em uso serão ignorados automaticamente." -ForegroundColor Yellow
        Write-Host "Pastas como Prefetch, SoftwareDistribution e WinSxS não serão tocadas." -ForegroundColor Yellow
        Write-Host ""

        if ($itemCount -eq 0) {
            Write-Host "Não há arquivos temporários do Windows para limpar." -ForegroundColor Green
            Write-Host ""
            Pause
            return
        }

        $confirmed = Confirm-Action "Deseja limpar estes arquivos?"

        if ($confirmed -eq $false) {
            Write-Host ""
            Write-Host "Limpeza cancelada." -ForegroundColor Yellow
            Pause
            return
        }

        Write-Host ""
        Write-Host "Limpando arquivos temporários do Windows..." -ForegroundColor Green
        Write-Host ""

        $deletedItems = 0
        $skippedItems = 0

        foreach ($item in $items) {
            try {
                Remove-Item -Path $item.FullName -Recurse -Force -ErrorAction Stop
                $deletedItems++
            }
            catch {
                $skippedItems++
            }
        }

        $remainingItems = @(Get-ChildItem -Path $tempPath -Force -ErrorAction SilentlyContinue).Count

        $sizeAfterBytes = Get-FolderSizeInBytes -Path $tempPath
        $sizeAfterText = Convert-WinForgeCleanupBytesToText -Bytes $sizeAfterBytes

        $cleanedBytes = $sizeBeforeBytes - $sizeAfterBytes

        if ($cleanedBytes -lt 0) {
            $cleanedBytes = 0
        }

        $cleanedText = Convert-WinForgeCleanupBytesToText -Bytes $cleanedBytes

        Write-WinForgeStatus -Type Success -Message "Limpeza concluída."
        Write-WinForgeKeyValue -Label "Itens removidos" -Value $deletedItems
        Write-WinForgeKeyValue -Label "Itens ignorados" -Value $skippedItems
        Write-WinForgeKeyValue -Label "Itens restantes" -Value $remainingItems
        Write-WinForgeKeyValue -Label "Espaço antes" -Value $sizeBeforeText
        Write-WinForgeKeyValue -Label "Espaço depois" -Value $sizeAfterText
        Write-WinForgeKeyValue -Label "Espaço liberado" -Value $cleanedText

        if ($skippedItems -gt 0) {
            Write-Host ""
            Write-Host "Alguns itens foram ignorados porque provavelmente estão em uso pelo Windows ou por serviços em execução." -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "Ocorreu um erro ao limpar temporários do Windows:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }

    Write-Host ""
    Pause
}


function Clear-SystemRecycleBin {
    Show-Header "Esvaziar Lixeira"

    Write-Host "O WinForge esvaziará a Lixeira de todas as unidades." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Esta ação remove permanentemente os itens que estão atualmente na Lixeira." -ForegroundColor Red
    Write-Host ""

    $confirmed = Confirm-Action "Deseja esvaziar a Lixeira?"

    if ($confirmed -eq $false) {
        Write-Host ""
        Write-Host "Operação cancelada." -ForegroundColor Yellow
        Pause
        return
    }

    try {
        Clear-RecycleBin -Force -ErrorAction Stop

        Write-Host ""
        Write-Host "Lixeira esvaziada com sucesso." -ForegroundColor Green
    }
    catch {
        $message = $_.Exception.Message

        if (
            $message -match "cannot find the file specified" -or
            $message -match "cannot find the path specified" -or
            $message -match "não pode encontrar o arquivo especificado" -or
            $message -match "não foi possível localizar (o arquivo|o caminho) especificado"
        ) {
            Write-Host ""
            Write-Host "A Lixeira já está vazia ou nenhum dado de Lixeira foi encontrado." -ForegroundColor Green
        }
        else {
            Write-Host ""
            Write-Host "Ocorreu um erro ao esvaziar a Lixeira:" -ForegroundColor Red
            Write-Host $message -ForegroundColor Red
        }
    }

    Write-Host ""
    Pause
}


function Get-DownloadsFolderPath {
    $fallbackPath = Join-Path $env:USERPROFILE "Downloads"
    $registryPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders"
    $downloadsValueName = "{374DE290-123F-4565-9164-39C4925E467B}"

    try {
        $configuredPath = (Get-ItemProperty -Path $registryPath -Name $downloadsValueName -ErrorAction Stop).$downloadsValueName

        if (-not [string]::IsNullOrWhiteSpace($configuredPath)) {
            return [Environment]::ExpandEnvironmentVariables($configuredPath)
        }
    }
    catch {
        # Usa o caminho padrão quando o perfil não possui um redirecionamento registrado.
    }

    return $fallbackPath
}


function Test-WinForgeDownloadsShellMetadata {
    param (
        [Parameter(Mandatory)]
        [System.IO.FileSystemInfo]$Item
    )

    # Metadados criados pelo shell não representam conteúdo pessoal do usuário.
    return (-not $Item.PSIsContainer -and $Item.Name -in @("desktop.ini", "Thumbs.db"))
}


function Get-DownloadsCleanupItems {
    param (
        [Parameter(Mandatory)]
        [string]$Path
    )

    return @(
        Get-ChildItem -LiteralPath $Path -Force -ErrorAction SilentlyContinue |
            Where-Object { -not (Test-WinForgeDownloadsShellMetadata -Item $_) }
    )
}


function Get-WinForgeItemCollectionSizeInBytes {
    param (
        [object[]]$Items
    )

    [Int64]$totalBytes = 0

    foreach ($item in @($Items)) {
        if ($null -eq $item) {
            continue
        }

        if ($item.PSIsContainer) {
            $files = @(
                Get-ChildItem -LiteralPath $item.FullName -File -Recurse -Force -ErrorAction SilentlyContinue |
                    Where-Object { -not (Test-WinForgeDownloadsShellMetadata -Item $_) }
            )

            foreach ($file in $files) {
                try {
                    # Atualiza o FileInfo para evitar Length obsoleto em arquivos recém-criados.
                    $file.Refresh()
                    $totalBytes += [Int64]$file.Length
                }
                catch {
                    # Arquivos inacessíveis não interrompem a estimativa dos demais itens.
                }
            }

            continue
        }

        try {
            $file = Get-Item -LiteralPath $item.FullName -Force -ErrorAction Stop
            $file.Refresh()
            $totalBytes += [Int64]$file.Length
        }
        catch {
            # O item pode ter sido removido ou bloqueado entre a listagem e a leitura.
        }
    }

    return [Int64]$totalBytes
}


function Convert-WinForgeCleanupBytesToText {
    param (
        [object]$Bytes
    )

    try {
        $numericBytes = [double]$Bytes

        if ($numericBytes -le 0) {
            return "0 B"
        }

        if ($numericBytes -ge 1GB) {
            return "$([Math]::Round($numericBytes / 1GB, 2)) GB"
        }

        if ($numericBytes -ge 1MB) {
            return "$([Math]::Round($numericBytes / 1MB, 2)) MB"
        }

        if ($numericBytes -ge 1KB) {
            return "$([Math]::Round($numericBytes / 1KB, 2)) KB"
        }

        return "$([Math]::Round($numericBytes, 0)) B"
    }
    catch {
        return "0 B"
    }
}


function Clear-DownloadsFolder {
    Show-Header "Limpar Pasta Downloads"

    $downloadsPath = Get-DownloadsFolderPath

    if (-not (Test-Path -LiteralPath $downloadsPath -PathType Container)) {
        Write-WinForgeStatus -Type "Error" -Message "Pasta Downloads não encontrada: $downloadsPath"
        Write-Host ""
        Pause
        return
    }

    try {
        $items = @(Get-DownloadsCleanupItems -Path $downloadsPath)
        $itemCount = $items.Count
        $sizeBeforeBytes = Get-WinForgeItemCollectionSizeInBytes -Items $items
        $sizeBeforeText = Convert-WinForgeCleanupBytesToText -Bytes $sizeBeforeBytes

        Write-WinForgeKeyValue -Label "Pasta" -Value $downloadsPath
        Write-WinForgeKeyValue -Label "Itens encontrados" -Value $itemCount
        Write-WinForgeKeyValue -Label "Tamanho estimado" -Value $sizeBeforeText
        Write-Host ""

        if ($itemCount -eq 0) {
            Write-WinForgeStatus -Type "Success" -Message "A pasta Downloads já está vazia."
            Write-Host ""
            Pause
            return
        }

        Write-WinForgeStatus -Type "Warning" -Message "Todo o conteúdo será removido permanentemente."
        Write-Host ""

        if (-not (Confirm-Action "Deseja limpar a pasta Downloads?")) {
            Write-Host ""
            Write-WinForgeStatus -Type "Warning" -Message "Limpeza cancelada."
            Write-Host ""
            Pause
            return
        }

        Write-Host ""
        Write-WinForgeStatus -Type "Running" -Message "Limpando a pasta Downloads..."

        $deletedItems = 0
        $skippedItems = 0

        foreach ($item in $items) {
            try {
                Remove-Item -LiteralPath $item.FullName -Recurse -Force -ErrorAction Stop
                $deletedItems++
            }
            catch {
                $skippedItems++
            }
        }

        $remainingCleanupItems = @(Get-DownloadsCleanupItems -Path $downloadsPath)
        $remainingItems = $remainingCleanupItems.Count
        $sizeAfterBytes = Get-WinForgeItemCollectionSizeInBytes -Items $remainingCleanupItems
        $cleanedBytes = $sizeBeforeBytes - $sizeAfterBytes

        if ($cleanedBytes -lt 0) {
            $cleanedBytes = 0
        }

        $cleanedText = Convert-WinForgeCleanupBytesToText -Bytes $cleanedBytes

        Write-Host ""
        Write-WinForgeStatus -Type "Success" -Message "Limpeza concluída."
        Write-WinForgeKeyValue -Label "Itens removidos" -Value $deletedItems
        Write-WinForgeKeyValue -Label "Itens ignorados" -Value $skippedItems
        Write-WinForgeKeyValue -Label "Itens restantes" -Value $remainingItems
        Write-WinForgeKeyValue -Label "Espaço liberado" -Value $cleanedText

        if ($skippedItems -gt 0) {
            Write-Host ""
            Write-WinForgeStatus -Type "Warning" -Message "Alguns itens estavam em uso ou não puderam ser removidos."
        }
    }
    catch {
        Write-Host ""
        Write-WinForgeStatus -Type "Error" -Message "Falha ao limpar Downloads: $($_.Exception.Message)"
    }

    Write-Host ""
    Pause
}


function Open-StorageSettings {
    Show-Header "Configurações de Armazenamento"

    try {
        Write-Host "Abrindo configurações de armazenamento do Windows..." -ForegroundColor Green
        Start-Process "ms-settings:storagesense"
    }
    catch {
        Write-Host "Ocorreu um erro ao abrir as configurações de armazenamento:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }

    Write-Host ""
    Pause
}


function Open-DownloadsForManualCleanup {
    param (
        [switch]$SkipHeader,
        [switch]$SkipPause
    )

    if (-not $SkipHeader) {
        Show-Header "Limpeza Manual de Downloads"
    }

    $downloadsPath = Get-DownloadsFolderPath

    Write-Host "O WinForge abrirá sua pasta Downloads." -ForegroundColor Yellow
    Write-Host "Revise manualmente arquivos antigos, duplicados ou desnecessários." -ForegroundColor Yellow
    Write-Host "Nenhum arquivo será apagado automaticamente." -ForegroundColor Cyan
    Write-Host ""

    try {
        if (Test-Path -LiteralPath $downloadsPath -PathType Container) {
            Write-Host "Abrindo Downloads..." -ForegroundColor Green
            Start-Process -FilePath "explorer.exe" -ArgumentList "`"$downloadsPath`""
        }
        else {
            Write-Host "Pasta Downloads não encontrada: $downloadsPath" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host ""
        Write-Host "Ocorreu um erro ao abrir a pasta Downloads:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }

    if (-not $SkipPause) {
        Write-Host ""
        Pause
    }
}


Export-ModuleMember -Function *
