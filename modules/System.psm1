function Set-HighPerformancePowerPlan {
    Show-Header "Definir Plano de Energia em Alto Desempenho"

    if (-not (Test-IsAdministrator)) {
        Write-Host "Privilégios de Administrador são necessários para alterar o plano de energia." -ForegroundColor Red
        Write-Host ""
        Pause
        return
    }

    Write-Host "Esta opção define o plano de energia ativo como Alto desempenho." -ForegroundColor Yellow
    Write-Host "Útil para desktops, PCs gamer e cenários onde estabilidade/desempenho importam mais que economia de energia." -ForegroundColor Cyan
    Write-Host ""

    $confirmed = Confirm-Action "Deseja definir o plano de energia como Alto desempenho?"

    if ($confirmed -eq $false) {
        Write-Host ""
        Write-Host "Operação cancelada." -ForegroundColor Yellow
        Write-Host ""
        Pause
        return
    }

    try {
        $success = Set-WinForgeHighPerformancePowerPlan

        Write-Host ""

        if ($success) {
            Write-Host "Plano de energia definido como Alto desempenho." -ForegroundColor Green
        }
        else {
            Write-Host "Não foi possível definir o plano de energia como Alto desempenho." -ForegroundColor Red
            Write-Host "Revise a saída do powercfg ou tente alterar manualmente nas configurações de energia." -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host ""
        Write-Host "Ocorreu um erro ao alterar o plano de energia:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }

    Write-Host ""
    Pause
}


function Disable-FastStartup {
    Show-Header "Desativar Inicialização Rápida"

    if (-not (Test-IsAdministrator)) {
        Write-Host "Privilégios de Administrador são necessários para desativar a Inicialização Rápida." -ForegroundColor Red
        Write-Host ""
        Pause
        return
    }

    Write-Host "Esta opção desativa a Inicialização Rápida do Windows." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "A Inicialização Rápida pode causar problemas de driver, desligamento, boot e inicialização de hardware." -ForegroundColor Cyan
    Write-Host ""

    $confirmed = Confirm-Action "Deseja desativar a Inicialização Rápida?"

    if ($confirmed -eq $false) {
        Write-Host ""
        Write-Host "Operação cancelada." -ForegroundColor Yellow
        Write-Host ""
        Pause
        return
    }

    try {
        Set-RegistryDWordValue `
            -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" `
            -Name "HiberbootEnabled" `
            -Value 0

        Write-Host ""
        Write-Host "Inicialização Rápida desativada." -ForegroundColor Green
    }
    catch {
        Write-Host ""
        Write-Host "Ocorreu um erro ao desativar a Inicialização Rápida:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }

    Write-Host ""
    Pause
}


function Disable-Hibernation {
    Show-Header "Desativar Hibernação"

    if (-not (Test-IsAdministrator)) {
        Write-Host "Privilégios de Administrador são necessários para desativar a hibernação." -ForegroundColor Red
        Write-Host ""
        Pause
        return
    }

    Write-Host "Esta opção desativa a hibernação do Windows." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Também remove o arquivo hiberfil.sys e, na prática, desativa a Inicialização Rápida dependente de hibernação." -ForegroundColor Cyan
    Write-Host "Recomendado principalmente para desktops e PCs gamer que não usam hibernação." -ForegroundColor Cyan
    Write-Host ""

    $confirmed = Confirm-Action "Deseja desativar a hibernação?"

    if ($confirmed -eq $false) {
        Write-Host ""
        Write-Host "Operação cancelada." -ForegroundColor Yellow
        Write-Host ""
        Pause
        return
    }

    try {
        powercfg.exe /hibernate off

        Write-Host ""
        Write-Host "Hibernação desativada." -ForegroundColor Green
    }
    catch {
        Write-Host ""
        Write-Host "Ocorreu um erro ao desativar a hibernação:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }

    Write-Host ""
    Pause
}


function Disable-AutomaticDisplayAndSleepTimeout {
    Show-Header "Desativar Desligamento de Tela e Suspensão"

    Write-Host "Esta opção evita que o Windows desligue a tela ou entre em suspensão automaticamente." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Configurações aplicadas:" -ForegroundColor Cyan
    Write-Host "Tela na tomada: Nunca"
    Write-Host "Tela na bateria: Nunca"
    Write-Host "Suspensão na tomada: Nunca"
    Write-Host "Suspensão na bateria: Nunca"
    Write-Host "Hibernação na tomada: Nunca"
    Write-Host "Hibernação na bateria: Nunca"
    Write-Host ""

    $confirmed = Confirm-Action "Deseja aplicar estas configurações de energia?"

    if ($confirmed -eq $false) {
        Write-Host ""
        Write-Host "Operação cancelada." -ForegroundColor Yellow
        Write-Host ""
        Pause
        return
    }

    try {
        powercfg.exe /change monitor-timeout-ac 0
        powercfg.exe /change monitor-timeout-dc 0
        powercfg.exe /change standby-timeout-ac 0
        powercfg.exe /change standby-timeout-dc 0
        powercfg.exe /change hibernate-timeout-ac 0
        powercfg.exe /change hibernate-timeout-dc 0

        Write-Host ""
        Write-Host "Desligamento automático de tela, suspensão e hibernação foram desativados." -ForegroundColor Green
    }
    catch {
        Write-Host ""
        Write-Host "Ocorreu um erro ao alterar configurações de energia:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }

    Write-Host ""
    Pause
}


function Disable-PciExpressLinkStatePowerManagement {
    Show-Header "Desativar Economia de Energia PCI Express"

    Write-Host "Esta opção desativa o Link State Power Management do PCI Express no plano de energia atual." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Pode ajudar em troubleshooting de GPU, PCIe, idle, tela, suspensão e instabilidade de vídeo." -ForegroundColor Cyan
    Write-Host ""

    $confirmed = Confirm-Action "Deseja aplicar esta configuração?"

    if ($confirmed -eq $false) {
        Write-Host ""
        Write-Host "Operação cancelada." -ForegroundColor Yellow
        Write-Host ""
        Pause
        return
    }

    try {
        powercfg.exe /setacvalueindex SCHEME_CURRENT SUB_PCIEXPRESS ASPM 0
        powercfg.exe /setdcvalueindex SCHEME_CURRENT SUB_PCIEXPRESS ASPM 0
        powercfg.exe /setactive SCHEME_CURRENT

        Write-Host ""
        Write-Host "Economia de energia PCI Express desativada." -ForegroundColor Green
    }
    catch {
        Write-Host ""
        Write-Host "Ocorreu um erro ao alterar configurações PCI Express:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }

    Write-Host ""
    Pause
}


function Disable-WindowsTipsAndSuggestions {
    Show-Header "Desativar Dicas e Sugestões do Windows"

    Write-Host "Esta opção desativa dicas, sugestões e telas de configuração sugerida para o usuário atual." -ForegroundColor Yellow
    Write-Host ""

    $confirmed = Confirm-Action "Deseja desativar dicas e sugestões do Windows?"

    if ($confirmed -eq $false) {
        Write-Host ""
        Write-Host "Operação cancelada." -ForegroundColor Yellow
        Write-Host ""
        Pause
        return
    }

    try {
        Set-RegistryDWordValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SoftLandingEnabled" -Value 0
        Set-RegistryDWordValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SystemPaneSuggestionsEnabled" -Value 0
        Set-RegistryDWordValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-338389Enabled" -Value 0
        Set-RegistryDWordValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-353698Enabled" -Value 0
        Set-RegistryDWordValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-310093Enabled" -Value 0
        Set-RegistryDWordValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement" -Name "ScoobeSystemSettingEnabled" -Value 0

        Write-Host ""
        Write-Host "Dicas e sugestões do Windows foram desativadas." -ForegroundColor Green
    }
    catch {
        Write-Host ""
        Write-Host "Ocorreu um erro ao desativar dicas e sugestões:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }

    Write-Host ""
    Pause
}


function Disable-XboxGameBar {
    Show-Header "Desativar Xbox Game Bar"

    Write-Host "Esta opção desativa Xbox Game Bar e recursos de captura/Game DVR." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Útil para reduzir overlays, captura em segundo plano e interferências em jogos." -ForegroundColor Cyan
    Write-Host ""

    $confirmed = Confirm-Action "Deseja desativar o Xbox Game Bar?"

    if ($confirmed -eq $false) {
        Write-Host ""
        Write-Host "Operação cancelada." -ForegroundColor Yellow
        Write-Host ""
        Pause
        return
    }

    try {
        Set-RegistryDWordValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" -Name "AppCaptureEnabled" -Value 0
        Set-RegistryDWordValue -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_Enabled" -Value 0
        Set-RegistryDWordValue -Path "HKCU:\Software\Microsoft\GameBar" -Name "ShowStartupPanel" -Value 0
        Set-RegistryDWordValue -Path "HKCU:\Software\Microsoft\GameBar" -Name "UseNexusForGameBarEnabled" -Value 0

        if (Test-IsAdministrator) {
            Set-RegistryDWordValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" -Name "AllowGameDVR" -Value 0
        }

        Get-Process -Name "GameBar", "GameBarFTServer", "GameBarPresenceWriter" -ErrorAction SilentlyContinue |
            Stop-Process -Force -ErrorAction SilentlyContinue

        Write-Host ""
        Write-Host "Xbox Game Bar e Game DVR foram desativados." -ForegroundColor Green
    }
    catch {
        Write-Host ""
        Write-Host "Ocorreu um erro ao desativar Xbox Game Bar:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }

    Write-Host ""
    Pause
}


function Enable-FileExtensions {
    Show-Header "Mostrar Extensões de Arquivos"

    Write-Host "Esta opção mostra extensões conhecidas no Explorador de Arquivos." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Exemplo: arquivo.exe, documento.pdf, imagem.png" -ForegroundColor Cyan
    Write-Host ""

    $confirmed = Confirm-Action "Deseja mostrar extensões de arquivos?"

    if ($confirmed -eq $false) {
        Write-Host ""
        Write-Host "Operação cancelada." -ForegroundColor Yellow
        Write-Host ""
        Pause
        return
    }

    try {
        Set-RegistryDWordValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideFileExt" -Value 0

        Write-Host ""
        Write-Host "Extensões de arquivos foram ativadas no Explorador de Arquivos." -ForegroundColor Green
        Write-Host ""

        $restartExplorer = Confirm-Action "Deseja reiniciar o Explorador de Arquivos agora para aplicar?"

        if ($restartExplorer) {
            Stop-Process -Name "explorer" -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 2
            Start-Process "explorer.exe"
        }
    }
    catch {
        Write-Host ""
        Write-Host "Ocorreu um erro ao ativar extensões de arquivos:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }

    Write-Host ""
    Pause
}


function Open-InstalledAppsManagement {
    param (
        [switch]$SkipHeader,
        [switch]$SkipPause
    )

    if (-not $SkipHeader) {
        Show-Header "Aplicativos Instalados"
    }

    try {
        Write-Host "Abrindo Aplicativos instalados do Windows..." -ForegroundColor Green
        Start-Process "ms-settings:appsfeatures"

        Write-Host "Abrindo Programas e Recursos clássico..." -ForegroundColor Green
        Start-Process -FilePath "control.exe" -ArgumentList "appwiz.cpl"

        Write-Host ""
        Write-Host "Revise os programas instalados e remova apenas o que você reconhece e não usa." -ForegroundColor Yellow
        Write-Host "Não remova drivers, runtimes, Visual C++, .NET, chipset, GPU ou componentes do sistema sem certeza." -ForegroundColor Yellow
    }
    catch {
        Write-Host ""
        Write-Host "Ocorreu um erro ao abrir a tela de aplicativos instalados:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }

    if (-not $SkipPause) {
        Write-Host ""
        Pause
    }
}


function Open-StartupAppsSettings {
    param (
        [switch]$SkipHeader,
        [switch]$SkipPause
    )

    if (-not $SkipHeader) {
        Show-Header "Aplicativos de Inicialização"
    }

    try {
        Write-Host "Abrindo aplicativos que iniciam com o Windows..." -ForegroundColor Green
        Write-Host ""
        Write-Host "Revise a lista e desative apenas o que você reconhece e não precisa iniciar junto com o Windows." -ForegroundColor Yellow

        Start-Process "ms-settings:startupapps"
    }
    catch {
        Write-Host ""
        Write-Host "Ocorreu um erro ao abrir os aplicativos de inicialização:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }

    if (-not $SkipPause) {
        Write-Host ""
        Pause
    }
}



Export-ModuleMember -Function *
