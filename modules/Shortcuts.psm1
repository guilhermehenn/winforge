# Atalhos para janelas do Windows (Configurações, Painel de Controle, consoles MMC), pastas e o site do WinForge.
# Uma única tabela serve às telas, ao console e às etapas com você do Otimizar.

$script:WinForgeShortcuts = [ordered]@{
    WindowsUpdate       = @{ Title = "Windows Update";                   File = "ms-settings:windowsupdate" }
    # A página Rede e Internet, onde se liga o Wi-Fi e se confere o cabo e o modo avião
    NetworkSettings     = @{ Title = (Get-WinForgeText 'Rede e Internet');                  File = "ms-settings:network-status" }
    OptionalUpdates     = @{ Title = (Get-WinForgeText 'Atualizações opcionais');           File = "ms-settings:windowsupdate-optionalupdates" }
    MicrosoftStore      = @{ Title = (Get-WinForgeText 'Atualizações da Microsoft Store');  File = "ms-windows-store://downloadsandupdates" }
    # storagesense é a página Armazenamento (os temporários, as instalações anteriores e a chave do Sensor); a página do
    # próprio Sensor de Armazenamento é storagepolicies.
    Storage             = @{ Title = (Get-WinForgeText 'Configurações de armazenamento');   File = "ms-settings:storagesense" }
    StartupApps         = @{ Title = (Get-WinForgeText 'Aplicativos de inicialização');     File = "ms-settings:startupapps" }
    InstalledApps       = @{ Title = (Get-WinForgeText 'Aplicativos instalados');           File = "ms-settings:appsfeatures" }
    Taskbar             = @{ Title = (Get-WinForgeText 'Configurações da barra de tarefas'); File = "ms-settings:taskbar" }
    Personalization     = @{ Title = (Get-WinForgeText 'Personalização do Windows');        File = "ms-settings:personalization" }
    LockScreen          = @{ Title = (Get-WinForgeText 'Tela de bloqueio do Windows');      File = "ms-settings:lockscreen" }
    Colors              = @{ Title = (Get-WinForgeText 'Cores do Windows');                 File = "ms-settings:colors" }
    Notifications       = @{ Title = (Get-WinForgeText 'Notificações e Não incomodar');     File = "ms-settings:notifications" }
    ProgramsAndFeatures = @{ Title = (Get-WinForgeText 'Programas e Recursos');             File = "control.exe"; Arguments = "appwiz.cpl" }
    DeviceManager       = @{ Title = (Get-WinForgeText 'Gerenciador de Dispositivos');      File = "mmc.exe"; Arguments = "devmgmt.msc" }
    Reliability         = @{ Title = (Get-WinForgeText 'Monitor de Confiabilidade');        File = "perfmon.exe"; Arguments = "/rel" }
    SystemRestore       = @{ Title = (Get-WinForgeText 'Restauração do Sistema');           File = "rstrui.exe" }
    Recovery            = @{ Title = (Get-WinForgeText 'Recuperação');                      File = "ms-settings:recovery" }
    WindowsSecurity     = @{ Title = (Get-WinForgeText 'Segurança do Windows');             File = "windowsdefender:" }
    # A página Proteção contra vírus e ameaças, onde ficam as ações que o Defender pede (reiniciar, verificação offline)
    WindowsSecurityThreats = @{ Title = (Get-WinForgeText 'Segurança do Windows');          File = "windowsdefender://threat" }
    # A página Firewall e proteção de rede, onde se liga o firewall de cada perfil
    WindowsSecurityFirewall = @{ Title = (Get-WinForgeText 'Segurança do Windows');         File = "windowsdefender://network" }
    TaskScheduler       = @{ Title = (Get-WinForgeText 'Agendador de Tarefas');             File = "mmc.exe"; Arguments = "taskschd.msc" }
    TaskManager         = @{ Title = (Get-WinForgeText 'Gerenciador de Tarefas');           File = "taskmgr.exe" }
    Downloads           = @{ Title = (Get-WinForgeText 'Pasta Downloads') }
    Documents           = @{ Title = (Get-WinForgeText 'Pasta Documentos') }
    Pictures            = @{ Title = (Get-WinForgeText 'Pasta Imagens') }
    LogFolder           = @{ Title = (Get-WinForgeText 'Pasta de logs e relatórios') }
    Website             = @{ Title = (Get-WinForgeText 'Site do WinForge') }
}


function Get-WinForgeShortcutFolderPath {
    # Onde fica a pasta pessoal de um atalho (Downloads, Documents, Pictures), mesmo levada para outro disco ou para o
    # OneDrive. "" para os outros atalhos ou quando o Windows não diz.
    param ([Parameter(Mandatory)][string]$Name)

    switch ($Name) {
        "Downloads" { return [string](Get-WinForgeDownloadsPath) }
        "Documents" { return [string](Get-WinForgeKnownFolderPath -Name "MyDocuments") }
        "Pictures" { return [string](Get-WinForgeKnownFolderPath -Name "MyPictures") }
    }

    return ""
}


# Por que a última abertura falhou: "Cancelled" quando a pessoa recusou o aviso do Windows (Controle de Conta de
# Usuário) de uma janela que pede Administrador, como a Restauração do Sistema; "" nos outros casos.
$script:WinForgeShortcutLastError = ""


function Get-WinForgeShortcutLastError {
    return [string]$script:WinForgeShortcutLastError
}


function Test-WinForgeUserCancelled {
    # Se o erro é o "operação cancelada pelo usuário" do Windows (código 1223, o aviso de Administrador recusado), no
    # próprio erro ou no de dentro. O código, e não o texto, que vem no idioma do Windows.
    param ($Exception)

    $current = $Exception
    $depth = 0

    while ($null -ne $current -and $depth -lt 4) {
        if ($null -ne $current.PSObject.Properties["NativeErrorCode"] -and [int]$current.NativeErrorCode -eq 1223) { return $true }

        $current = $(if ($null -ne $current.PSObject.Properties["InnerException"]) { $current.InnerException } else { $null })
        $depth++
    }

    return $false
}


function Open-WinForgeShortcut {
    <#
    Abre uma janela do Windows, uma pasta ou o site. Devolve $true se o Windows aceitou abrir; falhas (por exemplo, um
    painel que não existe nesta edição do Windows) viram uma mensagem e $false, nunca uma exceção.
    #>
    param (
        [Parameter(Mandatory)]
        [string]$Name,

        [switch]$Quiet
    )

    if (-not $script:WinForgeShortcuts.Contains($Name)) {
        throw "Atalho desconhecido: $Name"
    }

    $shortcut = $script:WinForgeShortcuts[$Name]
    $script:WinForgeShortcutLastError = ""

    try {
        switch ($Name) {
            { $_ -in @("Downloads", "Documents", "Pictures") } {
                $path = Get-WinForgeShortcutFolderPath -Name $Name

                if ([string]::IsNullOrWhiteSpace($path) -or -not (Test-Path -LiteralPath $path -PathType Container)) {
                    throw (Get-WinForgeText '{0} não encontrada: {1}' "$($shortcut.Title)" "$path")
                }

                Start-Process -FilePath "explorer.exe" -ArgumentList "`"$path`""
            }
            "LogFolder" {
                Start-Process -FilePath "explorer.exe" -ArgumentList "`"$(Get-WinForgeDataPath)`""
            }
            "Website" {
                # Pelo explorer.exe, que entrega a abertura ao Explorador da sessão: o navegador abre sem o Administrador da
                # janela; aberto direto daqui, ele herdaria a elevação.
                Start-Process -FilePath "explorer.exe" -ArgumentList "`"$(Get-WinForgeWebsiteUrl)`""
            }
            default {
                if ($shortcut.ContainsKey("Arguments")) {
                    Start-Process -FilePath $shortcut.File -ArgumentList $shortcut.Arguments
                }
                else {
                    Start-Process -FilePath $shortcut.File
                }
            }
        }

        if (-not $Quiet) {
            # "Abrindo: X", e não "X aberto": o nome pode ser feminino (a Recuperação, a Restauração do Sistema).
            Write-WinForgeStatus -Type Success -Message (Get-WinForgeText 'Abrindo: {0}.' "$($shortcut.Title)")
        }

        return $true
    }
    catch {
        # Recusar o aviso de Administrador é uma resposta, e não uma falha: nada de "pode não existir nesta edição".
        if (Test-WinForgeUserCancelled -Exception $_.Exception) {
            $script:WinForgeShortcutLastError = "Cancelled"
            if (-not $Quiet) { Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'A abertura de ''{0}'' foi cancelada no aviso do Windows.' "$($shortcut.Title)") }
            return $false
        }

        Write-WinForgeStatus -Type Error -Message (Get-WinForgeText 'Não foi possível abrir ''{0}'': {1}' "$($shortcut.Title)" "$($_.Exception.Message)")
        return $false
    }
}


Export-ModuleMember -Function *
