function Wait-RecommendedManualStep {
    param (
        [int]$StepNumber,
        [string]$Title,
        [string[]]$Description,
        [scriptblock]$Action
    )

    Write-Host ""
    Write-Host "Etapa manual $StepNumber - $Title" -ForegroundColor Cyan
    Write-Host "------------------------------------" -ForegroundColor DarkGray

    foreach ($line in $Description) {
        Write-Host $line -ForegroundColor Yellow
    }

    Write-Host ""

    try {
        & $Action
        Write-Host "Janela aberta." -ForegroundColor Green
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
    Write-Host "A próxima fase executará ações automáticas no sistema." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Serão executados limpeza, reparos do Windows, CHKDSK, winget, PnP, rede e ajustes do sistema." -ForegroundColor Cyan
    Write-Host "A conexão de rede pode cair temporariamente." -ForegroundColor Yellow
    Write-Host "O processo pode demorar bastante." -ForegroundColor Yellow
    Write-Host ""

    $typedText = Read-Host "Digite WINFORGE para iniciar as ações automáticas"

    if ($typedText.Trim().ToUpperInvariant() -ne "WINFORGE") {
        Write-Host ""
        Write-Host "Texto inválido. Ações automáticas canceladas." -ForegroundColor Yellow
        Write-Host ""
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

    Write-Host ""
    Write-Host "==================================================" -ForegroundColor DarkCyan
    Write-Host " $Title" -ForegroundColor Cyan
    Write-Host "==================================================" -ForegroundColor DarkCyan

    try {
        & $Action

        Write-Host ""
        Write-Host "Concluído com sucesso: $Title" -ForegroundColor Green

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

    Write-Host "Pasta: $Path"
    Write-Host "Itens removidos: $deletedItems" -ForegroundColor Green
    Write-Host "Itens ignorados: $skippedItems" -ForegroundColor Yellow
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
    $wingetExists = Get-Command winget -ErrorAction SilentlyContinue

    if (-not $wingetExists) {
        throw "winget não foi encontrado. Atualização de softwares ignorada."
    }

    Write-WinForgeSubStep "winget" "Atualizando fontes."
    winget source update --accept-source-agreements

    $sourceExitCode = $LASTEXITCODE

    if ($sourceExitCode -ne 0) {
        Write-WinForgeWarn "Atualização de fontes do winget finalizou com código $sourceExitCode."
    }
    else {
        Write-WinForgeOk "Fontes do winget atualizadas."
    }

    Write-WinForgeSubStep "Softwares" "Verificando atualizações disponíveis via winget."
    Write-Host ""

    $upgradeOutput = winget upgrade --accept-source-agreements 2>&1
    $upgradeOutput | ForEach-Object { Write-Host $_ }

    $outputText = $upgradeOutput -join "`n"

    if (
        $outputText -match "No installed package found matching input criteria" -or
        $outputText -match "No available upgrade found" -or
        $outputText -match "Nenhuma atualização"
    ) {
        Write-Host ""
        Write-WinForgeOk "Nenhuma atualização via winget foi encontrada."
        return
    }

    Write-Host ""
    $confirmed = Confirm-Action "Deseja atualizar todos os softwares disponíveis via winget?"

    if ($confirmed -eq $false) {
        Write-Host ""
        Write-WinForgeWarn "Atualização via winget ignorada pelo usuário."
        return
    }

    Write-Host ""
    Write-Host "Atualizando softwares via winget..." -ForegroundColor Green
    Write-Host ""

    winget upgrade --all --accept-source-agreements --accept-package-agreements --disable-interactivity

    $upgradeExitCode = $LASTEXITCODE

    if ($upgradeExitCode -ne 0) {
        throw "winget upgrade finalizou com código $upgradeExitCode. Revise a saída acima para identificar qual software falhou."
    }

    Write-WinForgeOk "Softwares via winget atualizados."
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
            $message -match "The system cannot find the file specified"
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
        -Title "Reparar Imagem do Windows" `
        -FilePath "dism.exe" `
        -Arguments @("/Online", "/Cleanup-Image", "/RestoreHealth") `
        -Description @("Reparando a imagem/componentes do Windows.") `
        -SkipConfirmation `
        -NoClear `
        -NoPause

    $sfcSuccess = Invoke-DiagnosticCommand `
        -Title "Verificar e Reparar Arquivos do Sistema" `
        -FilePath "sfc.exe" `
        -Arguments @("/scannow") `
        -Description @("Verificando arquivos protegidos do sistema.") `
        -SkipConfirmation `
        -NoClear `
        -NoPause

    if (-not $dismSuccess -or -not $sfcSuccess) {
        throw "Reparo do Windows finalizou com alertas ou erros. Revise a saída acima."
    }

    Write-WinForgeOk "Reparo do Windows concluído."
}


function Invoke-RecommendedChkdskScan {
    $drive = $env:SystemDrive

    Write-WinForgeSubStep "CHKDSK" "Verifica erros no sistema de arquivos e no disco do sistema."
    Write-Host "Comando: chkdsk.exe $drive /scan" -ForegroundColor DarkCyan
    Write-Host "Esta etapa não usa /R e não agenda reparos sem confirmação explícita." -ForegroundColor Yellow
    Write-Host ""

    $confirmed = Confirm-Action "Deseja verificar o disco com CHKDSK agora?"

    if ($confirmed -eq $false) {
        Write-WinForgeWarn "CHKDSK ignorado pelo usuário."
        return
    }

    $chkdskOutput = chkdsk.exe $drive /scan 2>&1
    $chkdskOutput | ForEach-Object { Write-Host $_ }
    $exitCode = $LASTEXITCODE
    $outputText = $chkdskOutput -join "`n"

    if ($exitCode -eq 0) {
        Write-WinForgeOk "CHKDSK finalizado sem erros críticos reportados."
    }
    else {
        Write-WinForgeWarn "CHKDSK finalizou com código $exitCode. Revise a saída acima."
    }

    $needsScheduledCheck = (
        $outputText -match "spotfix" -or
        $outputText -match "offline" -or
        $outputText -match "next restart" -or
        $outputText -match "next time" -or
        $outputText -match "próxima reinicialização" -or
        $outputText -match "proxima reinicializacao" -or
        $outputText -match "reinicie"
    )

    if ($needsScheduledCheck) {
        Write-Host ""
        Write-WinForgeWarn "O CHKDSK indicou que pode haver verificação ou reparo pendente para o próximo reinício."
        Write-Host ""

        $scheduleConfirmed = Confirm-Action "Deseja agendar a verificação do disco para a próxima reinicialização?"

        if ($scheduleConfirmed) {
            Write-Host "Comando: chkntfs.exe /C $drive" -ForegroundColor DarkCyan
            chkntfs.exe /C $drive
            Write-WinForgeOk "Verificação de disco agendada. Reinicie o Windows para executar."
        }
        else {
            Write-WinForgeWarn "Agendamento de CHKDSK não realizado."
        }
    }
}


function Request-RestartAfterMaintenance {
    Write-Host ""
    Write-Host "Reinicialização" -ForegroundColor Cyan
    Write-Host ""
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
        Write-Host "Privilégios de Administrador são necessários para a manutenção recomendada." -ForegroundColor Red
        Write-Host ""
        Pause
        return
    }

    Write-Host "A manutenção recomendada será dividida em duas fases." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Fase 1 - Etapas manuais assistidas:" -ForegroundColor Cyan
    Write-Host "- Abrir aplicativos que iniciam com o Windows"
    Write-Host "- Abrir Aplicativos instalados e Programas e Recursos"
    Write-Host "- Abrir Downloads para limpeza manual"
    Write-Host "- Abrir Windows Update"
    Write-Host "- Abrir atualizações opcionais"
    Write-Host "- Abrir atualizações da Microsoft Store"
    Write-Host "- Abrir configurações de armazenamento"
    Write-Host ""
    Write-Host "Fase 2 - Ações automáticas:" -ForegroundColor Cyan
    Write-Host "- Limpar temporários do usuário, temporários do Windows e Lixeira"
    Write-Host "- Reparar Windows com DISM + SFC"
    Write-Host "- Verificar disco com CHKDSK"
    Write-Host "- Atualizar softwares via winget"
    Write-Host "- Detectar dispositivos e drivers"
    Write-Host "- Executar reparo rápido de rede e DNS"
    Write-Host "- Aplicar ajustes de energia, estabilidade, Explorer e Xbox Game Bar"
    Write-Host ""
    Write-Host "Importante:" -ForegroundColor Yellow
    Write-Host "As etapas automáticas podem demorar bastante."
    Write-Host "A conexão de rede pode cair temporariamente durante o reparo de rede."
    Write-Host "Uma reinicialização do Windows é recomendada ao final."
    Write-Host ""

    $confirmed = Confirm-Action "Deseja iniciar a manutenção recomendada?"

    if ($confirmed -eq $false) {
        Write-Host ""
        Write-Host "Manutenção recomendada cancelada." -ForegroundColor Yellow
        Write-Host ""
        Pause
        return
    }

    Show-Header "Manutenção Recomendada - Etapas Manuais"

    Wait-RecommendedManualStep `
        -StepNumber 1 `
        -Title "Aplicativos que iniciam com o Windows" `
        -Description @(
            "A tela de aplicativos de inicialização será aberta.",
            "Desative apenas softwares que você reconhece e não precisa iniciar junto com o Windows.",
            "Não desative itens de segurança, drivers, sincronização ou ferramentas essenciais sem certeza."
        ) `
        -Action { Open-StartupAppsSettings -SkipHeader -SkipPause }

    Wait-RecommendedManualStep `
        -StepNumber 2 `
        -Title "Aplicativos instalados" `
        -Description @(
            "Serão abertas a tela moderna de Aplicativos instalados e o painel clássico de Programas e Recursos.",
            "Revise a lista e desinstale apenas o que você realmente reconhece e não usa.",
            "Não remova drivers, runtimes, Visual C++, .NET, chipset, GPU ou componentes do sistema sem certeza."
        ) `
        -Action { Open-InstalledAppsManagement -SkipHeader -SkipPause }

    Wait-RecommendedManualStep `
        -StepNumber 3 `
        -Title "Downloads" `
        -Description @(
            "A pasta Downloads será aberta.",
            "Revise manualmente arquivos antigos, duplicados ou desnecessários.",
            "O WinForge não apagará automaticamente nenhum arquivo dessa pasta."
        ) `
        -Action { Open-DownloadsForManualCleanup -SkipHeader -SkipPause }

    Wait-RecommendedManualStep `
        -StepNumber 4 `
        -Title "Windows Update" `
        -Description @(
            "O Windows Update será aberto.",
            "Procure atualizações disponíveis e instale o que fizer sentido."
        ) `
        -Action { Start-Process "ms-settings:windowsupdate" }

    Wait-RecommendedManualStep `
        -StepNumber 5 `
        -Title "Atualizações opcionais e drivers" `
        -Description @(
            "A tela de atualizações opcionais será aberta.",
            "Drivers opcionais podem aparecer aqui.",
            "Instale apenas drivers que façam sentido para o seu hardware ou que estejam corrigindo um problema real."
        ) `
        -Action { Start-Process "ms-settings:windowsupdate-optionalupdates" }

    Wait-RecommendedManualStep `
        -StepNumber 6 `
        -Title "Atualizações da Microsoft Store" `
        -Description @(
            "A Microsoft Store será aberta na tela de downloads e atualizações.",
            "Atualize aplicativos instalados pela Store."
        ) `
        -Action { Start-Process "ms-windows-store://downloadsandupdates" }

    Wait-RecommendedManualStep `
        -StepNumber 7 `
        -Title "Configurações de armazenamento" `
        -Description @(
            "As configurações de armazenamento do Windows serão abertas.",
            "Revise arquivos temporários, recomendações de limpeza e uso de disco."
        ) `
        -Action { Start-Process "ms-settings:storagesense" }

    Show-Header "Manutenção Recomendada - Ações Automáticas"

    Write-Host "As etapas manuais foram concluídas." -ForegroundColor Green
    Write-Host ""
    Write-Host "Agora o WinForge executará as ações automáticas da manutenção recomendada." -ForegroundColor Yellow
    Write-Host ""

    $confirmedAutomaticActions = Confirm-RecommendedAutomaticActions

    if ($confirmedAutomaticActions -eq $false) {
        return
    }

    $maintenanceResults = @()

    $maintenanceResults += Invoke-RecommendedMaintenanceStep -Title "Limpar temporários e Lixeira" -Action { Invoke-RecommendedCleanup }
    $maintenanceResults += Invoke-RecommendedMaintenanceStep -Title "Reparar Windows (DISM + SFC)" -Action { Invoke-RecommendedDismAndSfc }
    $maintenanceResults += Invoke-RecommendedMaintenanceStep -Title "Verificar disco com CHKDSK" -Action { Invoke-RecommendedChkdskScan }
    $maintenanceResults += Invoke-RecommendedMaintenanceStep -Title "Atualizar softwares via winget" -Action { Invoke-RecommendedWingetUpdate }
    $maintenanceResults += Invoke-RecommendedMaintenanceStep -Title "Detectar dispositivos e drivers" -Action { Invoke-RecommendedPnpScan }
    $maintenanceResults += Invoke-RecommendedMaintenanceStep -Title "Reparo rápido de rede e DNS" -Action { Invoke-RecommendedNetworkRepair }
    $maintenanceResults += Invoke-RecommendedMaintenanceStep -Title "Aplicar ajustes recomendados" -Action { Invoke-RecommendedTweaks }

    Write-Host ""
    Write-Host "Resumo da manutenção recomendada" -ForegroundColor Cyan
    Write-Host ""

    $maintenanceResults | Format-Table -AutoSize

    Write-Host ""
    Write-Host "Manutenção recomendada finalizada." -ForegroundColor Green
    Write-Host ""
    Write-Host "Recomendação final:" -ForegroundColor Yellow
    Write-Host "Reinicie o Windows para aplicar completamente ajustes de energia, rede, hibernação, Explorer e reparos do sistema." -ForegroundColor Yellow

    Request-RestartAfterMaintenance

    Write-Host ""
    Pause
}


Export-ModuleMember -Function *
