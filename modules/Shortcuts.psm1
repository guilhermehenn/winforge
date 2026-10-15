# Atalhos para janelas do Windows (Configurações, Painel de Controle, consoles MMC).
# Uma única tabela serve às telas, ao console e às etapas manuais da Manutenção recomendada.

$script:WinForgeShortcuts = [ordered]@{
    WindowsUpdate       = @{ Title = "Windows Update";                   File = "ms-settings:windowsupdate" }
    OptionalUpdates     = @{ Title = "Atualizações opcionais e drivers"; File = "ms-settings:windowsupdate-optionalupdates" }
    MicrosoftStore      = @{ Title = "Atualizações da Microsoft Store";  File = "ms-windows-store://downloadsandupdates" }
    Storage             = @{ Title = "Configurações de armazenamento";   File = "ms-settings:storagesense" }
    StartupApps         = @{ Title = "Aplicativos de inicialização";     File = "ms-settings:startupapps" }
    InstalledApps       = @{ Title = "Aplicativos instalados";           File = "ms-settings:appsfeatures" }
    ProgramsAndFeatures = @{ Title = "Programas e Recursos";             File = "control.exe"; Arguments = "appwiz.cpl" }
    DeviceManager       = @{ Title = "Gerenciador de Dispositivos";      File = "mmc.exe"; Arguments = "devmgmt.msc" }
    Reliability         = @{ Title = "Monitor de Confiabilidade";        File = "perfmon.exe"; Arguments = "/rel" }
    SystemRestore       = @{ Title = "Restauração do Sistema";           File = "rstrui.exe" }
    WindowsSecurity     = @{ Title = "Segurança do Windows";             File = "windowsdefender:" }
    TaskScheduler       = @{ Title = "Agendador de Tarefas";             File = "mmc.exe"; Arguments = "taskschd.msc" }
    Downloads           = @{ Title = "Pasta Downloads" }
    LogFolder           = @{ Title = "Pasta de logs e relatórios" }
}


function Get-WinForgeShortcutNames {
    return @($script:WinForgeShortcuts.Keys)
}


function Open-WinForgeShortcut {
    <#
    Abre uma janela do Windows. Devolve $true se o Windows aceitou abrir; falhas (por exemplo, um painel que não existe
    nesta edição do Windows) viram uma mensagem e $false, nunca uma exceção.
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

    try {
        switch ($Name) {
            "Downloads" {
                $path = Get-WinForgeDownloadsPath

                if (-not (Test-Path -LiteralPath $path -PathType Container)) {
                    throw "Pasta Downloads não encontrada: $path"
                }

                Start-Process -FilePath "explorer.exe" -ArgumentList "`"$path`""
            }
            "LogFolder" {
                Start-Process -FilePath "explorer.exe" -ArgumentList "`"$(Get-WinForgeDataPath)`""
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
            Write-WinForgeStatus -Type Success -Message "$($shortcut.Title) aberto."
        }

        return $true
    }
    catch {
        Write-WinForgeStatus -Type Error -Message "Não foi possível abrir '$($shortcut.Title)': $($_.Exception.Message)"
        return $false
    }
}


Export-ModuleMember -Function *
