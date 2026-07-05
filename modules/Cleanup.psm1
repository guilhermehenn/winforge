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
        $sizeBeforeMB = [Math]::Round($sizeBeforeBytes / 1MB, 2)

        Write-Host "O WinForge limpará arquivos temporários do perfil do usuário atual." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Pasta alvo:" -ForegroundColor Cyan
        Write-Host $tempPath
        Write-Host ""
        Write-Host "Itens encontrados: $itemCount" -ForegroundColor Cyan
        Write-Host "Tamanho estimado: $sizeBeforeMB MB" -ForegroundColor Cyan
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
        $sizeAfterMB = [Math]::Round($sizeAfterBytes / 1MB, 2)

        $cleanedBytes = $sizeBeforeBytes - $sizeAfterBytes

        if ($cleanedBytes -lt 0) {
            $cleanedBytes = 0
        }

        $cleanedMB = [Math]::Round($cleanedBytes / 1MB, 2)

        Write-Host "Limpeza concluída." -ForegroundColor Green
        Write-Host ""
        Write-Host "Itens removidos: $deletedItems" -ForegroundColor Cyan
        Write-Host "Itens ignorados: $skippedItems" -ForegroundColor Yellow
        Write-Host "Itens restantes: $remainingItems" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Espaço antes da limpeza:  $sizeBeforeMB MB" -ForegroundColor Cyan
        Write-Host "Espaço depois da limpeza: $sizeAfterMB MB" -ForegroundColor Cyan
        Write-Host "Espaço liberado:          $cleanedMB MB" -ForegroundColor Green

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
        $sizeBeforeMB = [Math]::Round($sizeBeforeBytes / 1MB, 2)

        Write-Host "O WinForge limpará arquivos temporários da pasta Temp do Windows." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Pasta alvo:" -ForegroundColor Cyan
        Write-Host $tempPath
        Write-Host ""
        Write-Host "Itens encontrados: $itemCount" -ForegroundColor Cyan
        Write-Host "Tamanho estimado: $sizeBeforeMB MB" -ForegroundColor Cyan
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
        $sizeAfterMB = [Math]::Round($sizeAfterBytes / 1MB, 2)

        $cleanedBytes = $sizeBeforeBytes - $sizeAfterBytes

        if ($cleanedBytes -lt 0) {
            $cleanedBytes = 0
        }

        $cleanedMB = [Math]::Round($cleanedBytes / 1MB, 2)

        Write-Host "Limpeza concluída." -ForegroundColor Green
        Write-Host ""
        Write-Host "Itens removidos: $deletedItems" -ForegroundColor Cyan
        Write-Host "Itens ignorados: $skippedItems" -ForegroundColor Yellow
        Write-Host "Itens restantes: $remainingItems" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Espaço antes da limpeza:  $sizeBeforeMB MB" -ForegroundColor Cyan
        Write-Host "Espaço depois da limpeza: $sizeAfterMB MB" -ForegroundColor Cyan
        Write-Host "Espaço liberado:          $cleanedMB MB" -ForegroundColor Green

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
            $message -match "The system cannot find the file specified"
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

    $downloadsPath = Join-Path $env:USERPROFILE "Downloads"

    Write-Host "O WinForge abrirá sua pasta Downloads." -ForegroundColor Yellow
    Write-Host "Revise manualmente arquivos antigos, duplicados ou desnecessários." -ForegroundColor Yellow
    Write-Host "Nenhum arquivo será apagado automaticamente." -ForegroundColor Cyan
    Write-Host ""

    try {
        if (Test-Path $downloadsPath) {
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
