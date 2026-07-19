function Wait-RecommendedManualStep {
    param (
        [int]$StepNumber,
        [string]$Title,
        [string[]]$Description,
        [scriptblock]$Action
    )

    Write-WinForgeSection -Title "Etapa manual $StepNumber de 8 - $Title"

    foreach ($line in $Description) {
        Write-Host $line -ForegroundColor Yellow
    }

    Write-Host ""

    try {
        & $Action
        Write-WinForgeStatus -Type Success -Message "Janela aberta."
    }
    catch {
        Write-Host "Falha ao abrir esta etapa:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }

    Write-Host ""
    Read-Host "Conclua o que desejar na janela aberta e pressione ENTER para continuar"
}


function Confirm-RecommendedAutomaticActions {
    Write-Host ""
    Write-Host "A próxima fase altera o sistema e pode interromper a rede temporariamente." -ForegroundColor Yellow
    Write-Host ""

    $typedText = Read-Host "Digite WINFORGE para iniciar"

    if ($typedText.Trim().ToUpperInvariant() -ne "WINFORGE") {
        Write-Host "`nAções automáticas canceladas.`n" -ForegroundColor Yellow
        Pause
        return $false
    }

    return $true
}


function Invoke-RecommendedMaintenanceStep {
    param (
        [string]$Title,
        [scriptblock]$Action
    )

    Write-WinForgeSection -Title $Title

    try {
        # Mantém a saída operacional visível, mas impede que textos ou objetos
        # emitidos pela etapa contaminem a coleção usada no resumo final.
        & $Action | Out-Host

        Write-Host ""
        Write-WinForgeStatus -Type Success -Message "$Title concluído."

        return [PSCustomObject]@{
            Etapa  = $Title
            Status = "OK"
        }
    }
    catch {
        Write-Host ""
        Write-Host "Falha detectada nesta etapa: $Title" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        Write-Host ""
        Write-Host "O WinForge continuará para a próxima etapa." -ForegroundColor Yellow

        return [PSCustomObject]@{
            Etapa  = $Title
            Status = "Falhou"
        }
    }
}


function Clear-FolderContentsForMaintenance {
    param (
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        Write-Host "Pasta não encontrada: $Path" -ForegroundColor Yellow
        return
    }

    $items = @(Get-ChildItem -Path $Path -Force -ErrorAction SilentlyContinue)

    if ($items.Count -eq 0) {
        Write-Host "Nada para limpar em: $Path" -ForegroundColor Green
        return
    }

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

    Write-WinForgeKeyValue -Label "Pasta" -Value $Path
    Write-WinForgeKeyValue -Label "Itens removidos" -Value $deletedItems
    Write-WinForgeKeyValue -Label "Itens ignorados" -Value $skippedItems
}


function Invoke-RecommendedTweaks {
    Write-WinForgeSubStep "Plano de energia" "Definindo Alto desempenho."
    Set-WinForgeHighPerformancePowerPlan -ThrowOnFailure | Out-Null
    Write-WinForgeOk "Plano de energia definido como Alto desempenho."

    Write-WinForgeSubStep "Inicialização Rápida" "Desativando Hiberboot."
    Set-RegistryDWordValue `
        -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" `
        -Name "HiberbootEnabled" `
        -Value 0
    Write-WinForgeOk "Inicialização Rápida desativada."

    Write-WinForgeSubStep "Hibernação" "Desativando hibernação e removendo hiberfil.sys."
    Invoke-NativeCommandDirect -FilePath "powercfg.exe" -Arguments @("/hibernate", "off")
    Write-WinForgeOk "Hibernação desativada."

    Write-WinForgeSubStep "Tela e suspensão" "Configurando tela, suspensão e hibernação automática como Nunca."
    Invoke-NativeCommandDirect -FilePath "powercfg.exe" -Arguments @("/change", "monitor-timeout-ac", "0")
    Invoke-NativeCommandDirect -FilePath "powercfg.exe" -Arguments @("/change", "monitor-timeout-dc", "0")
    Invoke-NativeCommandDirect -FilePath "powercfg.exe" -Arguments @("/change", "standby-timeout-ac", "0")
    Invoke-NativeCommandDirect -FilePath "powercfg.exe" -Arguments @("/change", "standby-timeout-dc", "0")
    Invoke-NativeCommandDirect -FilePath "powercfg.exe" -Arguments @("/change", "hibernate-timeout-ac", "0")
    Invoke-NativeCommandDirect -FilePath "powercfg.exe" -Arguments @("/change", "hibernate-timeout-dc", "0")
    Write-WinForgeOk "Timeouts automáticos desativados."

    Write-WinForgeSubStep "PCI Express" "Desativando economia de energia PCI Express."
    Invoke-NativeCommandDirect -FilePath "powercfg.exe" -Arguments @("/setacvalueindex", "SCHEME_CURRENT", "SUB_PCIEXPRESS", "ASPM", "0")
    Invoke-NativeCommandDirect -FilePath "powercfg.exe" -Arguments @("/setdcvalueindex", "SCHEME_CURRENT", "SUB_PCIEXPRESS", "ASPM", "0")
    Invoke-NativeCommandDirect -FilePath "powercfg.exe" -Arguments @("/setactive", "SCHEME_CURRENT")
    Write-WinForgeOk "Economia de energia PCI Express desativada."

    Write-WinForgeSubStep "Dicas e sugestões" "Desativando sugestões do Windows para o usuário atual."
    Set-RegistryDWordValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SoftLandingEnabled" -Value 0
    Set-RegistryDWordValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SystemPaneSuggestionsEnabled" -Value 0
    Set-RegistryDWordValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-338389Enabled" -Value 0
    Set-RegistryDWordValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-353698Enabled" -Value 0
    Set-RegistryDWordValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-310093Enabled" -Value 0
    Set-RegistryDWordValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement" -Name "ScoobeSystemSettingEnabled" -Value 0
    Write-WinForgeOk "Dicas e sugestões desativadas."

    Write-WinForgeSubStep "Xbox Game Bar" "Desativando Game Bar, Game DVR e processos relacionados."
    Set-RegistryDWordValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" -Name "AppCaptureEnabled" -Value 0
    Set-RegistryDWordValue -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_Enabled" -Value 0
    Set-RegistryDWordValue -Path "HKCU:\Software\Microsoft\GameBar" -Name "ShowStartupPanel" -Value 0
    Set-RegistryDWordValue -Path "HKCU:\Software\Microsoft\GameBar" -Name "UseNexusForGameBarEnabled" -Value 0
    Set-RegistryDWordValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" -Name "AllowGameDVR" -Value 0

    Get-Process -Name "GameBar", "GameBarFTServer", "GameBarPresenceWriter" -ErrorAction SilentlyContinue |
        Stop-Process -Force -ErrorAction SilentlyContinue

    Write-WinForgeOk "Xbox Game Bar e Game DVR desativados."

    Write-WinForgeSubStep "Explorador de Arquivos" "Mostrando extensões de arquivos."
    Set-RegistryDWordValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideFileExt" -Value 0
    Write-WinForgeOk "Extensões de arquivos ativadas no Explorador de Arquivos."

    Write-Host ""
    Write-WinForgeWarn "Alguns ajustes podem exigir reinicialização, logoff ou reinício do Explorador de Arquivos."
}


function Invoke-RecommendedWingetUpdate {
    Write-WinForgeSubStep "winget" "Verificando atualizações e aguardando S, N ou um ou mais IDs."

    Invoke-WinForgeWingetUpgradeSelection -NoHeader -NoPause -ThrowOnFailure | Out-Null
}



function Invoke-RecommendedPnpScan {
    Write-WinForgeSubStep "Dispositivos e drivers" "Detectando dispositivos conectados e drivers disponíveis."
    Invoke-NativeCommandDirect -FilePath "pnputil.exe" -Arguments @("/scan-devices")
    Write-WinForgeOk "Detecção de dispositivos e drivers concluída."
}


function Invoke-RecommendedCleanup {
    $userTempPath = Join-Path $env:LOCALAPPDATA "Temp"
    $windowsTempPath = Join-Path $env:WINDIR "Temp"

    Write-WinForgeSubStep "Temporários do usuário" "Limpando arquivos temporários do perfil atual."
    Clear-FolderContentsForMaintenance -Path $userTempPath

    Write-WinForgeSubStep "Temporários do Windows" "Limpando arquivos temporários do Windows."
    Clear-FolderContentsForMaintenance -Path $windowsTempPath

    Write-WinForgeSubStep "Lixeira" "Esvaziando Lixeira."
    try {
        Clear-RecycleBin -Force -ErrorAction Stop
        Write-WinForgeOk "Lixeira esvaziada."
    }
    catch {
        $message = $_.Exception.Message

        if (
            $message -match "cannot find the file specified" -or
            $message -match "cannot find the path specified" -or
            $message -match "não pode encontrar o arquivo especificado" -or
            $message -match "não foi possível localizar (o arquivo|o caminho) especificado"
        ) {
            Write-WinForgeOk "Lixeira já estava vazia ou sem dados encontrados."
        }
        else {
            Write-WinForgeWarn "Falha ao esvaziar Lixeira: $message"
        }
    }
}


function Invoke-RecommendedNetworkRepair {
    Write-WinForgeSubStep "DNS" "Limpando cache DNS."
    Invoke-NativeCommandDirect -FilePath "ipconfig.exe" -Arguments @("/flushdns") -IgnoreExitCode

    Write-WinForgeSubStep "Endereço IP" "Liberando endereço IP atual."
    Invoke-NativeCommandDirect -FilePath "ipconfig.exe" -Arguments @("/release") -IgnoreExitCode

    Write-WinForgeSubStep "Endereço IP" "Renovando endereço IP."
    Invoke-NativeCommandDirect -FilePath "ipconfig.exe" -Arguments @("/renew") -IgnoreExitCode

    Write-WinForgeSubStep "Winsock" "Resetando catálogo Winsock."
    Invoke-NativeCommandDirect -FilePath "netsh.exe" -Arguments @("winsock", "reset") -IgnoreExitCode

    Write-WinForgeSubStep "TCP/IP" "Resetando pilha TCP/IP."
    Invoke-NativeCommandDirect -FilePath "netsh.exe" -Arguments @("int", "ip", "reset") -IgnoreExitCode

    Write-WinForgeOk "Reparo rápido de rede e DNS finalizado."
    Write-WinForgeWarn "Reinicialização recomendada após reparo de rede."
}


function Invoke-RecommendedDismAndSfc {
    $dismSuccess = Invoke-DiagnosticCommand `
        -Title "Reparar Imagem e Componentes do Windows" `
        -FilePath "dism.exe" `
        -Arguments @("/Online", "/Cleanup-Image", "/RestoreHealth") `
        -Description @("Executando DISM /RestoreHealth.") `
        -SkipConfirmation `
        -NoClear `
        -NoPause

    $sfcSuccess = Invoke-DiagnosticCommand `
        -Title "Verificar e Reparar Arquivos do Sistema" `
        -FilePath "sfc.exe" `
        -Arguments @("/scannow") `
        -Description @("Executando SFC /scannow.") `
        -SkipConfirmation `
        -NoClear `
        -NoPause

    if (-not $dismSuccess -or -not $sfcSuccess) {
        throw "DISM ou SFC finalizou com alertas. Revise a saída acima."
    }
}


function Invoke-RecommendedChkdskScan {
    Invoke-WinForgeChkdskScan `
        -SkipConfirmation `
        -NoClear `
        -NoPause `
        -ScheduleRepairAutomatically `
        -ThrowOnFailure | Out-Null
}


function Invoke-RecommendedDriveOptimization {
    Invoke-WinForgeDriveOptimization `
        -SkipConfirmation `
        -NoClear `
        -NoPause `
        -ThrowOnFailure | Out-Null
}


function Request-RestartAfterMaintenance {
    Write-WinForgeSection -Title "Reinicialização"
    Write-Host "Para aplicar completamente os ajustes, é recomendado reiniciar o Windows agora." -ForegroundColor Yellow
    Write-Host "Antes de confirmar, salve seus arquivos, feche os demais softwares abertos e deixe somente o WinForge aberto." -ForegroundColor Yellow
    Write-Host ""

    $confirmed = Confirm-Action "Deseja reiniciar o Windows agora?"

    if ($confirmed -eq $false) {
        Write-Host ""
        Write-Host "Reinicialização não iniciada. Reinicie manualmente depois para concluir a manutenção." -ForegroundColor Yellow
        return
    }

    try {
        Write-Host ""
        Write-Host "Reinicialização agendada para 15 segundos." -ForegroundColor Green
        Write-Host "Para cancelar antes do prazo, execute: shutdown /a" -ForegroundColor Yellow
        shutdown.exe /r /t 15 /c "Reinicialização solicitada pelo WinForge após manutenção recomendada."
    }
    catch {
        Write-Host ""
        Write-Host "Ocorreu um erro ao solicitar a reinicialização:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }
}


function Run-RecommendedMaintenance {
    Show-Header "Manutenção Recomendada"

    if (-not (Test-IsAdministrator)) {
        Write-Host "Execute o WinForge como Administrador." -ForegroundColor Red
        Write-Host ""
        Pause
        return
    }

    Write-Host "Etapas manuais: inicialização, desinstalação, Downloads e atualizações." -ForegroundColor Yellow
    Write-Host "Etapas automáticas: limpeza, reparos, CHKDSK, otimização, winget, drivers, rede e ajustes." -ForegroundColor Cyan
    Write-Host "O processo pode demorar e a rede pode cair temporariamente." -ForegroundColor Yellow
    Write-Host ""
    Write-WinForgeWarn "Salve seu trabalho e feche os demais aplicativos, deixando somente o WinForge aberto."
    Write-Host ""

    if (-not (Confirm-Action "Você fechou os demais aplicativos e deseja continuar?")) {
        Write-Host "`nManutenção cancelada.`n" -ForegroundColor Yellow
        Pause
        return
    }

    Show-Header "Manutenção Recomendada - Etapas Manuais"

    Wait-RecommendedManualStep `
        -StepNumber 1 `
        -Title "Aplicativos de inicialização" `
        -Description @("Desative apenas aplicativos que você reconhece e não precisa iniciar com o Windows.") `
        -Action { Open-StartupAppsSettings -SkipHeader -SkipPause }

    Wait-RecommendedManualStep `
        -StepNumber 2 `
        -Title "Programas e Recursos" `
        -Description @("Revise os programas clássicos e remova somente o que você reconhece.") `
        -Action { Open-ProgramsAndFeatures -SkipHeader -SkipPause }

    Wait-RecommendedManualStep `
        -StepNumber 3 `
        -Title "Aplicativos instalados" `
        -Description @("Revise os aplicativos do Windows e remova somente o que você reconhece.") `
        -Action { Open-WindowsInstalledApps -SkipHeader -SkipPause }

    Wait-RecommendedManualStep `
        -StepNumber 4 `
        -Title "Downloads" `
        -Description @("Remova manualmente arquivos antigos ou desnecessários.") `
        -Action { Open-DownloadsForManualCleanup -SkipHeader -SkipPause }

    Wait-RecommendedManualStep `
        -StepNumber 5 `
        -Title "Windows Update" `
        -Description @("Instale as atualizações disponíveis.") `
        -Action { Start-Process "ms-settings:windowsupdate" }

    Wait-RecommendedManualStep `
        -StepNumber 6 `
        -Title "Atualizações opcionais" `
        -Description @("Instale drivers opcionais somente quando forem pertinentes ao hardware ou a uma correção.") `
        -Action { Start-Process "ms-settings:windowsupdate-optionalupdates" }

    Wait-RecommendedManualStep `
        -StepNumber 7 `
        -Title "Microsoft Store" `
        -Description @("Atualize os aplicativos instalados pela Microsoft Store.") `
        -Action { Start-Process "ms-windows-store://downloadsandupdates" }

    Wait-RecommendedManualStep `
        -StepNumber 8 `
        -Title "Armazenamento" `
        -Description @("Revise arquivos temporários e recomendações de limpeza do Windows.") `
        -Action { Start-Process "ms-settings:storagesense" }

    Show-Header "Manutenção Recomendada - Ações Automáticas"

    if (-not (Confirm-RecommendedAutomaticActions)) {
        return
    }

    $maintenanceResults = @()
    $maintenanceResults += Invoke-RecommendedMaintenanceStep -Title "Limpar temporários e Lixeira" -Action { Invoke-RecommendedCleanup }
    $maintenanceResults += Invoke-RecommendedMaintenanceStep -Title "Reparar Windows (DISM + SFC)" -Action { Invoke-RecommendedDismAndSfc }
    $maintenanceResults += Invoke-RecommendedMaintenanceStep -Title "Verificar sistema de arquivos (CHKDSK)" -Action { Invoke-RecommendedChkdskScan }
    $maintenanceResults += Invoke-RecommendedMaintenanceStep -Title "Otimizar unidade do sistema" -Action { Invoke-RecommendedDriveOptimization }
    $maintenanceResults += Invoke-RecommendedMaintenanceStep -Title "Atualizar softwares (winget)" -Action { Invoke-RecommendedWingetUpdate }
    $maintenanceResults += Invoke-RecommendedMaintenanceStep -Title "Detectar dispositivos e drivers" -Action { Invoke-RecommendedPnpScan }
    $maintenanceResults += Invoke-RecommendedMaintenanceStep -Title "Reparar rede e DNS" -Action { Invoke-RecommendedNetworkRepair }
    $maintenanceResults += Invoke-RecommendedMaintenanceStep -Title "Aplicar ajustes recomendados" -Action { Invoke-RecommendedTweaks }

    Write-WinForgeSection -Title "Resumo"

    # Proteção adicional: somente resultados formais de etapa podem compor a tabela.
    $summaryResults = @(
        $maintenanceResults |
            Where-Object {
                $null -ne $_ -and
                $null -ne $_.PSObject.Properties["Etapa"] -and
                $null -ne $_.PSObject.Properties["Status"]
            }
    )

    $summaryResults |
        Select-Object Etapa, Status |
        Format-Table -AutoSize |
        Out-Host

    Write-Host ""
    Write-Host "Manutenção concluída. Reinicie o Windows para aplicar todas as alterações." -ForegroundColor Green

    Request-RestartAfterMaintenance

    Write-Host ""
    Pause
}


Export-ModuleMember -Function *
