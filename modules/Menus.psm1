function Show-UpdateMenu {
    do {
        Show-Header "Atualizações"

        Write-WinForgeMenuItem -Key "1" -Label "Abrir Windows Update"
        Write-WinForgeMenuItem -Key "2" -Label "Abrir atualizações opcionais e drivers"
        Write-WinForgeMenuItem -Key "3" -Label "Abrir atualizações da Microsoft Store"
        Write-WinForgeMenuItem -Key "4" -Label "Atualizar softwares (winget)"
        Write-WinForgeMenuItem -Key "0" -Label "Voltar" -Exit
        Write-Host ""

        $choice = Read-Host "Selecione uma opção"

        switch ($choice) {
            "1" {
                Write-Host "`nAbrindo Windows Update..." -ForegroundColor Green
                Start-Process "ms-settings:windowsupdate"
                Pause
            }
            "2" {
                Write-Host "`nAbrindo atualizações opcionais e drivers..." -ForegroundColor Green
                Start-Process "ms-settings:windowsupdate-optionalupdates"
                Pause
            }
            "3" {
                Write-Host "`nAbrindo atualizações da Microsoft Store..." -ForegroundColor Green
                Start-Process "ms-windows-store://downloadsandupdates"
                Pause
            }
            "4" { Update-AllSoftware }
            "0" { return }
            default {
                Write-Host "`nOpção inválida." -ForegroundColor Red
                Pause
            }
        }
    } while ($choice -ne "0")
}


function Show-SoftwareMenu {
    do {
        Show-Header "Softwares"

        Write-WinForgeMenuItem -Key "1" -Label "Listar softwares instalados (winget)"
        Write-WinForgeMenuItem -Key "2" -Label "Atualizar softwares (winget)"
        Write-WinForgeMenuItem -Key "3" -Label "Buscar software (winget)"
        Write-WinForgeMenuItem -Key "4" -Label "Instalar software (winget)"
        Write-WinForgeMenuItem -Key "5" -Label "Desinstalar software (winget)"
        Write-WinForgeMenuItem -Key "6" -Label "Instalar softwares essenciais (winget)"
        Write-WinForgeMenuItem -Key "7" -Label "Abrir Programas e Recursos (Painel de Controle)"
        Write-WinForgeMenuItem -Key "8" -Label "Abrir Aplicativos instalados (Configurações do Windows)"
        Write-WinForgeMenuItem -Key "0" -Label "Voltar" -Exit
        Write-Host ""

        $choice = Read-Host "Selecione uma opção"

        switch ($choice) {
            "1" { Get-InstalledSoftware }
            "2" { Update-AllSoftware }
            "3" { Search-Software }
            "4" { Install-Software }
            "5" { Uninstall-Software }
            "6" { Show-EssentialSoftwareMenu }
            "7" { Open-ProgramsAndFeatures }
            "8" { Open-WindowsInstalledApps }
            "0" { return }
            default {
                Write-Host "`nOpção inválida." -ForegroundColor Red
                Pause
            }
        }
    } while ($choice -ne "0")
}


function Show-CleanupMenu {
    do {
        Show-Header "Limpeza"

        Write-WinForgeMenuItem -Key "1" -Label "Limpar pasta Downloads"
        Write-WinForgeMenuItem -Key "2" -Label "Limpar temporários do usuário"
        Write-WinForgeMenuItem -Key "3" -Label "Limpar temporários do Windows"
        Write-WinForgeMenuItem -Key "4" -Label "Esvaziar Lixeira"
        Write-WinForgeMenuItem -Key "5" -Label "Abrir configurações de armazenamento"
        Write-WinForgeMenuItem -Key "0" -Label "Voltar" -Exit
        Write-Host ""

        $choice = Read-Host "Selecione uma opção"

        switch ($choice) {
            "1" { Clear-DownloadsFolder }
            "2" { Clear-UserTempFiles }
            "3" { Clear-WindowsTempFiles }
            "4" { Clear-SystemRecycleBin }
            "5" { Open-StorageSettings }
            "0" { return }
            default {
                Write-Host "`nOpção inválida." -ForegroundColor Red
                Pause
            }
        }
    } while ($choice -ne "0")
}


function Show-RepairMenu {
    do {
        Show-Header "Reparo e Otimização"

        Write-WinForgeMenuItem -Key "1" -Label "Reparar Windows (DISM + SFC)" -Accent
        Write-WinForgeMenuItem -Key "2" -Label "Reparar imagem e componentes (DISM)"
        Write-WinForgeMenuItem -Key "3" -Label "Verificar e reparar arquivos (SFC)"
        Write-WinForgeMenuItem -Key "4" -Label "Verificar sistema de arquivos (CHKDSK)"
        Write-WinForgeMenuItem -Key "5" -Label "Otimizar unidade do sistema (SSD/HDD)"
        Write-WinForgeMenuItem -Key "0" -Label "Voltar" -Exit
        Write-Host ""

        $choice = Read-Host "Selecione uma opção"

        switch ($choice) {
            "1" { Invoke-DISMAndSFC }
            "2" { Invoke-DISMRestoreHealth }
            "3" { Invoke-SFCScannow }
            "4" { Invoke-CHKDSKScan }
            "5" { Invoke-DriveOptimization }
            "0" { return }
            default {
                Write-Host "`nOpção inválida." -ForegroundColor Red
                Pause
            }
        }
    } while ($choice -ne "0")
}


function Show-DiagnosticsMenu {
    do {
        Show-Header "Diagnósticos"

        Write-WinForgeMenuItem -Key "1" -Label "Ver informações de disco"
        Write-WinForgeMenuItem -Key "2" -Label "Ver informações de inicialização"
        Write-WinForgeMenuItem -Key "3" -Label "Verificar dispositivos e drivers com problema"
        Write-WinForgeMenuItem -Key "4" -Label "Abrir Gerenciador de Dispositivos"
        Write-WinForgeMenuItem -Key "5" -Label "Abrir Monitor de Confiabilidade"
        Write-WinForgeMenuItem -Key "0" -Label "Voltar" -Exit
        Write-Host ""

        $choice = Read-Host "Selecione uma opção"

        switch ($choice) {
            "1" { Show-DiskInformation }
            "2" { Show-StartupInformation }
            "3" { Show-ProblemDevices }
            "4" { Open-DeviceManager }
            "5" { Open-ReliabilityMonitor }
            "0" { return }
            default {
                Write-Host "`nOpção inválida." -ForegroundColor Red
                Pause
            }
        }
    } while ($choice -ne "0")
}


function Show-NetworkMenu {
    do {
        Show-Header "Rede"

        Write-WinForgeMenuItem -Key "1" -Label "Ver informações de rede"
        Write-WinForgeMenuItem -Key "2" -Label "Testar conectividade (ping)"
        Write-WinForgeMenuItem -Key "3" -Label "Testar velocidade da internet"
        Write-WinForgeMenuItem -Key "4" -Label "Reparar rede e DNS"
        Write-WinForgeMenuItem -Key "0" -Label "Voltar" -Exit
        Write-Host ""

        $choice = Read-Host "Selecione uma opção"

        switch ($choice) {
            "1" { Show-NetworkInformation }
            "2" { Test-NetworkPingTargets }
            "3" { Test-NetworkSpeed }
            "4" { Invoke-NetworkRepair }
            "0" { return }
            default {
                Write-Host "`nOpção inválida." -ForegroundColor Red
                Pause
            }
        }
    } while ($choice -ne "0")
}


function Show-PersonalizationMenu {
    do {
        # Lê o Registro a cada renderização; nenhum estado de personalização é armazenado em cache.
        $state = Get-WinForgePersonalizationState

        Show-Header "Personalização"
        Write-WinForgeSection "Estado atual"
        Write-WinForgePersonalizationStateLine -Label "Barra de tarefas" -Value $state.TaskbarAlignment
        Write-WinForgePersonalizationStateLine -Label "Modo de cores" -Value $state.Theme
        Write-WinForgePersonalizationStateLine -Label "Dicas na tela de bloqueio" -Value $state.LockScreenTips
        Write-WinForgePersonalizationStateLine -Label "Transparência" -Value $state.Transparency
        Write-Host ""

        $taskbarLabel = if ($state.TaskbarAlignment -eq "Centralizada") {
            "Alinhar barra de tarefas à esquerda"
        }
        elseif ($state.TaskbarAlignment -eq "À esquerda") {
            "Centralizar barra de tarefas"
        }
        else {
            "Alterar alinhamento da barra de tarefas (Windows 11)"
        }

        $themeLabel = if ($state.Theme -eq "Escuro") {
            "Ativar modo claro"
        }
        else {
            "Ativar modo escuro"
        }

        $lockScreenLabel = if ($state.LockScreenTipsEnabled) {
            "Desativar dicas e truques da tela de bloqueio"
        }
        else {
            "Ativar dicas e truques da tela de bloqueio"
        }

        $transparencyLabel = if ($state.TransparencyEnabled) {
            "Desativar efeitos de transparência"
        }
        else {
            "Ativar efeitos de transparência"
        }

        Write-WinForgeMenuItem -Key "1" -Label $taskbarLabel
        Write-WinForgeMenuItem -Key "2" -Label $themeLabel
        Write-WinForgeMenuItem -Key "3" -Label $lockScreenLabel
        Write-WinForgeMenuItem -Key "4" -Label $transparencyLabel
        Write-WinForgeMenuItem -Key "0" -Label "Voltar" -Exit
        Write-Host ""

        $choice = Read-Host "Selecione uma opção"

        switch ($choice) {
            "1" { Toggle-WinForgeTaskbarAlignment }
            "2" { Toggle-WinForgeColorMode }
            "3" { Toggle-WinForgeLockScreenTips }
            "4" { Toggle-WinForgeTransparencyEffects }
            "0" { return }
            default {
                Write-Host "`nOpção inválida." -ForegroundColor Red
                Pause
            }
        }
    } while ($choice -ne "0")
}


function Show-TweaksMenu {
    do {
        Show-Header "Ajustes do Windows"

        Write-WinForgeMenuItem -Key "1" -Label "Mostrar extensões de arquivos"
        Write-WinForgeMenuItem -Key "2" -Label "Mostrar arquivos e pastas ocultos"
        Write-WinForgeMenuItem -Key "3" -Label "Desativar Xbox Game Bar"
        Write-WinForgeMenuItem -Key "4" -Label "Desativar dicas e sugestões"
        Write-WinForgeMenuItem -Key "5" -Label "Ativar plano Alto desempenho"
        Write-WinForgeMenuItem -Key "6" -Label "Desativar economia de energia PCI Express"
        Write-WinForgeMenuItem -Key "7" -Label "Desativar suspensão e desligamento da tela"
        Write-WinForgeMenuItem -Key "8" -Label "Desativar Inicialização Rápida"
        Write-WinForgeMenuItem -Key "9" -Label "Desativar hibernação"
        Write-WinForgeMenuItem -Key "0" -Label "Voltar" -Exit
        Write-Host ""

        $choice = Read-Host "Selecione uma opção"

        switch ($choice) {
            "1" { Enable-FileExtensions }
            "2" { Enable-HiddenFiles }
            "3" { Disable-XboxGameBar }
            "4" { Disable-WindowsTipsAndSuggestions }
            "5" { Set-HighPerformancePowerPlan }
            "6" { Disable-PciExpressLinkStatePowerManagement }
            "7" { Disable-AutomaticDisplayAndSleepTimeout }
            "8" { Disable-FastStartup }
            "9" { Disable-Hibernation }
            "0" { return }
            default {
                Write-Host "`nOpção inválida." -ForegroundColor Red
                Pause
            }
        }
    } while ($choice -ne "0")
}


function Show-MainMenu {
    do {
        Show-Header "WinForge"

        Write-WinForgeMenuItem -Key "1" -Label "Manutenção recomendada" -Accent
        Write-WinForgeMenuItem -Key "2" -Label "Atualizações"
        Write-WinForgeMenuItem -Key "3" -Label "Softwares"
        Write-WinForgeMenuItem -Key "4" -Label "Limpeza"
        Write-WinForgeMenuItem -Key "5" -Label "Reparo e otimização"
        Write-WinForgeMenuItem -Key "6" -Label "Diagnósticos"
        Write-WinForgeMenuItem -Key "7" -Label "Rede"
        Write-WinForgeMenuItem -Key "8" -Label "Personalização"
        Write-WinForgeMenuItem -Key "9" -Label "Ajustes do Windows"
        Write-WinForgeMenuItem -Key "10" -Label "Sobre este PC"
        Write-WinForgeMenuItem -Key "0" -Label "Sair" -Exit
        Write-Host ""

        $choice = Read-Host "Selecione uma opção"

        switch ($choice) {
            "1" { Run-RecommendedMaintenance }
            "2" { Show-UpdateMenu }
            "3" { Show-SoftwareMenu }
            "4" { Show-CleanupMenu }
            "5" { Show-RepairMenu }
            "6" { Show-DiagnosticsMenu }
            "7" { Show-NetworkMenu }
            "8" { Show-PersonalizationMenu }
            "9" { Show-TweaksMenu }
            "10" { Show-AboutThisPC }
            "0" { Write-Host "`nSaindo do WinForge..." -ForegroundColor Yellow }
            default {
                Write-Host "`nOpção inválida." -ForegroundColor Red
                Pause
            }
        }
    } while ($choice -ne "0")
}


Export-ModuleMember -Function *
