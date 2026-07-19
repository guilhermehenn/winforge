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
        Write-WinForgeStatus -Type Error -Message "Privilégios de Administrador são necessários."
        Write-Host ""
        Pause
        return
    }

    Write-Host "Esta opção desativa a hibernação e remove o arquivo hiberfil.sys." -ForegroundColor Yellow
    Write-Host "A Inicialização Rápida dependente de hibernação também será desativada." -ForegroundColor Cyan
    Write-Host ""

    if (-not (Confirm-Action "Deseja desativar a hibernação?")) {
        Write-Host ""
        Write-WinForgeStatus -Type Warning -Message "Operação cancelada."
        Write-Host ""
        Pause
        return
    }

    try {
        Invoke-NativeCommandDirect -FilePath "powercfg.exe" -Arguments @("/hibernate", "off")
        Write-Host ""
        Write-WinForgeStatus -Type Success -Message "Hibernação desativada."
    }
    catch {
        Write-Host ""
        Write-WinForgeStatus -Type Error -Message "Falha ao desativar a hibernação."
        Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
    }

    Write-Host ""
    Pause
}


function Disable-AutomaticDisplayAndSleepTimeout {
    Show-Header "Desativar Desligamento de Tela e Suspensão"

    Write-Host "Esta opção configura tela, suspensão e hibernação automática como Nunca." -ForegroundColor Yellow
    Write-Host "A configuração será aplicada tanto na tomada quanto na bateria." -ForegroundColor Cyan
    Write-Host ""

    if (-not (Confirm-Action "Deseja aplicar estas configurações de energia?")) {
        Write-Host ""
        Write-WinForgeStatus -Type Warning -Message "Operação cancelada."
        Write-Host ""
        Pause
        return
    }

    try {
        $commands = @(
            @("/change", "monitor-timeout-ac", "0"),
            @("/change", "monitor-timeout-dc", "0"),
            @("/change", "standby-timeout-ac", "0"),
            @("/change", "standby-timeout-dc", "0"),
            @("/change", "hibernate-timeout-ac", "0"),
            @("/change", "hibernate-timeout-dc", "0")
        )

        foreach ($arguments in $commands) {
            Invoke-NativeCommandDirect -FilePath "powercfg.exe" -Arguments $arguments
        }

        Write-Host ""
        Write-WinForgeStatus -Type Success -Message "Timeouts automáticos de energia desativados."
    }
    catch {
        Write-Host ""
        Write-WinForgeStatus -Type Error -Message "Falha ao alterar as configurações de energia."
        Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
    }

    Write-Host ""
    Pause
}


function Disable-PciExpressLinkStatePowerManagement {
    Show-Header "Desativar Economia de Energia PCI Express"

    Write-Host "Esta opção desativa o Link State Power Management do PCI Express no plano atual." -ForegroundColor Yellow
    Write-Host "Pode ser útil em diagnósticos de instabilidade de GPU ou dispositivos PCIe." -ForegroundColor Cyan
    Write-Host ""

    if (-not (Confirm-Action "Deseja aplicar esta configuração?")) {
        Write-Host ""
        Write-WinForgeStatus -Type Warning -Message "Operação cancelada."
        Write-Host ""
        Pause
        return
    }

    try {
        Invoke-NativeCommandDirect -FilePath "powercfg.exe" -Arguments @("/setacvalueindex", "SCHEME_CURRENT", "SUB_PCIEXPRESS", "ASPM", "0")
        Invoke-NativeCommandDirect -FilePath "powercfg.exe" -Arguments @("/setdcvalueindex", "SCHEME_CURRENT", "SUB_PCIEXPRESS", "ASPM", "0")
        Invoke-NativeCommandDirect -FilePath "powercfg.exe" -Arguments @("/setactive", "SCHEME_CURRENT")

        Write-Host ""
        Write-WinForgeStatus -Type Success -Message "Economia de energia PCI Express desativada."
    }
    catch {
        Write-Host ""
        Write-WinForgeStatus -Type Error -Message "Falha ao alterar a configuração PCI Express."
        Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
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
            Restart-WinForgeExplorerShell
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


function Enable-HiddenFiles {
    Show-Header "Mostrar Arquivos e Pastas Ocultos"

    Write-Host "Esta opção exibe itens ocultos no Explorador de Arquivos." -ForegroundColor Yellow
    Write-Host "Arquivos protegidos do sistema continuam ocultos." -ForegroundColor DarkGray
    Write-Host ""

    if (-not (Confirm-Action "Deseja mostrar arquivos e pastas ocultos?")) {
        Write-Host ""
        Write-WinForgeStatus -Type "Warning" -Message "Operação cancelada."
        Write-Host ""
        Pause
        return
    }

    try {
        Set-RegistryDWordValue `
            -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" `
            -Name "Hidden" `
            -Value 1

        Write-Host ""
        Write-WinForgeStatus -Type "Success" -Message "Arquivos e pastas ocultos foram habilitados."
        Write-Host ""

        if (Confirm-Action "Deseja reiniciar o Explorador de Arquivos agora para aplicar?") {
            Restart-WinForgeExplorerShell
        }
    }
    catch {
        Write-Host ""
        Write-WinForgeStatus -Type "Error" -Message "Falha ao alterar a exibição: $($_.Exception.Message)"
    }

    Write-Host ""
    Pause
}


function Open-ProgramsAndFeatures {
    param (
        [switch]$SkipHeader,
        [switch]$SkipPause
    )

    if (-not $SkipHeader) {
        Show-Header "Programas e Recursos"
    }

    try {
        Write-Host "Abrindo Programas e Recursos pelo Painel de Controle..." -ForegroundColor Green
        Start-Process -FilePath "control.exe" -ArgumentList "appwiz.cpl"

        Write-Host ""
        Write-Host "Remova somente programas que você reconhece e não utiliza." -ForegroundColor Yellow
    }
    catch {
        Write-Host ""
        Write-Host "Ocorreu um erro ao abrir Programas e Recursos:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }

    if (-not $SkipPause) {
        Write-Host ""
        Pause
    }
}


function Open-WindowsInstalledApps {
    param (
        [switch]$SkipHeader,
        [switch]$SkipPause
    )

    if (-not $SkipHeader) {
        Show-Header "Aplicativos Instalados do Windows"
    }

    try {
        Write-Host "Abrindo Aplicativos instalados do Windows..." -ForegroundColor Green
        Start-Process "ms-settings:appsfeatures"

        Write-Host ""
        Write-Host "Remova somente aplicativos que você reconhece e não utiliza." -ForegroundColor Yellow
    }
    catch {
        Write-Host ""
        Write-Host "Ocorreu um erro ao abrir Aplicativos instalados:" -ForegroundColor Red
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
