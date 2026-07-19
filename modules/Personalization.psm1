function Get-WinForgeWindowsBuild {
    try {
        $operatingSystem = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
        return [int]$operatingSystem.BuildNumber
    }
    catch {
        return [int][Environment]::OSVersion.Version.Build
    }
}


function Test-WinForgeWindows11 {
    return (Get-WinForgeWindowsBuild) -ge 22000
}


function Get-WinForgeRegistryDWord {
    param (
        [string]$Path,
        [string]$Name,
        [int]$DefaultValue = 0
    )

    try {
        $item = Get-ItemProperty -Path $Path -Name $Name -ErrorAction Stop
        return [int]$item.$Name
    }
    catch {
        return $DefaultValue
    }
}


function Write-WinForgePersonalizationStateLine {
    param (
        [Parameter(Mandatory)]
        [string]$Label,

        [Parameter(Mandatory)]
        [string]$Value
    )

    Write-Host "  ${Label}: " -NoNewline -ForegroundColor DarkGray
    Write-Host $Value -ForegroundColor White
}


function Send-WinForgePersonalizationChange {
    param (
        [string]$Section = "ImmersiveColorSet"
    )

    # Notifica aplicações e o shell sobre alterações de personalização no HKCU.
    # Falhas na notificação não invalidam o valor já persistido no Registro.
    try {
        if (-not ("WinForge.PersonalizationNativeMethods" -as [type])) {
            Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

namespace WinForge
{
    public static class PersonalizationNativeMethods
    {
        [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
        public static extern IntPtr SendMessageTimeout(
            IntPtr hWnd,
            uint message,
            UIntPtr wParam,
            string lParam,
            uint flags,
            uint timeout,
            out UIntPtr result);
    }
}
"@
        }

        $broadcastHandle = [IntPtr]0xffff
        $settingChangeMessage = 0x001A
        $abortIfHung = 0x0002
        $result = [UIntPtr]::Zero

        [void][WinForge.PersonalizationNativeMethods]::SendMessageTimeout(
            $broadcastHandle,
            $settingChangeMessage,
            [UIntPtr]::Zero,
            $Section,
            $abortIfHung,
            5000,
            [ref]$result
        )
    }
    catch {
        # Algumas aplicações podem exigir reabertura para adotar o novo estado.
    }
}


function Get-WinForgePersonalizationState {
    $themePath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
    $contentPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
    $taskbarPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"

    $appsUseLightTheme = Get-WinForgeRegistryDWord -Path $themePath -Name "AppsUseLightTheme" -DefaultValue 1
    $systemUsesLightTheme = Get-WinForgeRegistryDWord -Path $themePath -Name "SystemUsesLightTheme" -DefaultValue 1
    $transparencyEnabled = Get-WinForgeRegistryDWord -Path $themePath -Name "EnableTransparency" -DefaultValue 1

    $lockScreenOverlayEnabled = Get-WinForgeRegistryDWord `
        -Path $contentPath `
        -Name "RotatingLockScreenOverlayEnabled" `
        -DefaultValue 1

    $lockScreenSubscriptionEnabled = Get-WinForgeRegistryDWord `
        -Path $contentPath `
        -Name "SubscribedContent-338387Enabled" `
        -DefaultValue 1

    $theme = if ($appsUseLightTheme -eq 0 -and $systemUsesLightTheme -eq 0) {
        "Escuro"
    }
    elseif ($appsUseLightTheme -eq 1 -and $systemUsesLightTheme -eq 1) {
        "Claro"
    }
    else {
        "Personalizado"
    }

    $taskbarAlignment = if (-not (Test-WinForgeWindows11)) {
        "Disponível somente no Windows 11"
    }
    else {
        $taskbarValue = Get-WinForgeRegistryDWord -Path $taskbarPath -Name "TaskbarAl" -DefaultValue 1

        if ($taskbarValue -eq 0) {
            "À esquerda"
        }
        else {
            "Centralizada"
        }
    }

    $lockScreenTipsEnabled = ($lockScreenOverlayEnabled -ne 0 -or $lockScreenSubscriptionEnabled -ne 0)

    return [PSCustomObject]@{
        TaskbarAlignment      = $taskbarAlignment
        Theme                 = $theme
        LockScreenTips        = $(if ($lockScreenTipsEnabled) { "Ativadas" } else { "Desativadas" })
        Transparency          = $(if ($transparencyEnabled -ne 0) { "Ativada" } else { "Desativada" })
        LockScreenTipsEnabled = $lockScreenTipsEnabled
        TransparencyEnabled   = ($transparencyEnabled -ne 0)
    }
}


function Toggle-WinForgeTaskbarAlignment {
    Show-Header "Alinhamento da Barra de Tarefas"

    if (-not (Test-WinForgeWindows11)) {
        Write-WinForgeStatus -Type "Warning" -Message "Esta opção está disponível somente no Windows 11."
        Write-Host ""
        Pause
        return
    }

    $path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    $currentValue = Get-WinForgeRegistryDWord -Path $path -Name "TaskbarAl" -DefaultValue 1
    $newValue = if ($currentValue -eq 0) { 1 } else { 0 }
    $newLabel = if ($newValue -eq 0) { "à esquerda" } else { "centralizada" }

    try {
        Set-RegistryDWordValue -Path $path -Name "TaskbarAl" -Value $newValue
        Restart-WinForgeExplorerShell

        Write-WinForgeStatus -Type "Success" -Message "Barra de tarefas alinhada $newLabel."
    }
    catch {
        Write-WinForgeStatus -Type "Error" -Message "Falha ao alterar o alinhamento: $($_.Exception.Message)"
    }

    Write-Host ""
    Pause
}


function Toggle-WinForgeColorMode {
    Show-Header "Modo Claro ou Escuro"

    $path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
    $appsUseLightTheme = Get-WinForgeRegistryDWord -Path $path -Name "AppsUseLightTheme" -DefaultValue 1
    $systemUsesLightTheme = Get-WinForgeRegistryDWord -Path $path -Name "SystemUsesLightTheme" -DefaultValue 1
    $isDarkMode = ($appsUseLightTheme -eq 0 -and $systemUsesLightTheme -eq 0)
    $newValue = if ($isDarkMode) { 1 } else { 0 }
    $newLabel = if ($newValue -eq 0) { "escuro" } else { "claro" }

    try {
        Set-RegistryDWordValue -Path $path -Name "AppsUseLightTheme" -Value $newValue
        Set-RegistryDWordValue -Path $path -Name "SystemUsesLightTheme" -Value $newValue
        Send-WinForgePersonalizationChange

        Write-WinForgeStatus -Type "Success" -Message "Modo $newLabel ativado."
        Write-WinForgeStatus -Type "Info" -Message "Alguns aplicativos podem precisar ser reabertos."
    }
    catch {
        Write-WinForgeStatus -Type "Error" -Message "Falha ao alterar o modo de cores: $($_.Exception.Message)"
    }

    Write-Host ""
    Pause
}


function Toggle-WinForgeLockScreenTips {
    Show-Header "Dicas da Tela de Bloqueio"

    $path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
    $state = Get-WinForgePersonalizationState
    $newValue = if ($state.LockScreenTipsEnabled) { 0 } else { 1 }
    $newLabel = if ($newValue -eq 0) { "desativadas" } else { "ativadas" }

    try {
        # Mantém sincronizados os dois valores usados pelo conteúdo informativo
        # exibido sobre a imagem da tela de bloqueio do usuário atual.
        Set-RegistryDWordValue -Path $path -Name "RotatingLockScreenOverlayEnabled" -Value $newValue
        Set-RegistryDWordValue -Path $path -Name "SubscribedContent-338387Enabled" -Value $newValue
        Send-WinForgePersonalizationChange -Section "ContentDeliveryManager"

        Write-WinForgeStatus -Type "Success" -Message "Dicas e truques da tela de bloqueio foram $newLabel."
    }
    catch {
        Write-WinForgeStatus -Type "Error" -Message "Falha ao alterar as dicas da tela de bloqueio: $($_.Exception.Message)"
    }

    Write-Host ""
    Pause
}


function Toggle-WinForgeTransparencyEffects {
    Show-Header "Efeitos de Transparência"

    $path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
    $currentValue = Get-WinForgeRegistryDWord -Path $path -Name "EnableTransparency" -DefaultValue 1
    $newValue = if ($currentValue -eq 0) { 1 } else { 0 }
    $newLabel = if ($newValue -eq 0) { "desativados" } else { "ativados" }

    try {
        Set-RegistryDWordValue -Path $path -Name "EnableTransparency" -Value $newValue
        Send-WinForgePersonalizationChange

        Write-WinForgeStatus -Type "Success" -Message "Efeitos de transparência foram $newLabel."
    }
    catch {
        Write-WinForgeStatus -Type "Error" -Message "Falha ao alterar a transparência: $($_.Exception.Message)"
    }

    Write-Host ""
    Pause
}


Export-ModuleMember -Function *
