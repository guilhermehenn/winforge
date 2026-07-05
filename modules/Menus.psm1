function Show-UpdateMenu {
    do {
        Show-Header "Atualizações"

        Write-Host "[1] Abrir Windows Update"
        Write-Host "[2] Abrir atualizações opcionais e drivers"
        Write-Host "[3] Abrir atualizações da Microsoft Store"
        Write-Host "[4] Atualizar softwares via winget"
        Write-Host "[5] Verificar dispositivos/drivers com problema"
        Write-Host "[0] Voltar"
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
            "5" { Show-ProblemDevices }
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

        Write-Host "[1] Listar softwares instalados"
        Write-Host "[2] Buscar software"
        Write-Host "[3] Instalar software"
        Write-Host "[4] Desinstalar software"
        Write-Host "[5] Softwares essenciais"
        Write-Host "[0] Voltar"
        Write-Host ""

        $choice = Read-Host "Selecione uma opção"

        switch ($choice) {
            "1" { Get-InstalledSoftware }
            "2" { Search-Software }
            "3" { Install-Software }
            "4" { Uninstall-Software }
            "5" { Show-EssentialSoftwareMenu }
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

        Write-Host "[1] Abrir Downloads para limpeza manual"
        Write-Host "[2] Abrir configurações de armazenamento"
        Write-Host "[3] Limpar temporários do usuário"
        Write-Host "[4] Limpar temporários do Windows"
        Write-Host "[5] Esvaziar Lixeira"
        Write-Host "[0] Voltar"
        Write-Host ""

        $choice = Read-Host "Selecione uma opção"

        switch ($choice) {
            "1" { Open-DownloadsForManualCleanup }
            "2" { Open-StorageSettings }
            "3" { Clear-UserTempFiles }
            "4" { Clear-WindowsTempFiles }
            "5" { Clear-SystemRecycleBin }
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

        Write-Host "[1] Reparar Windows (DISM + SFC)"
        Write-Host "[2] Reparar imagem do Windows"
        Write-Host "[3] Verificar e reparar arquivos do sistema"
        Write-Host "[4] Verificar disco com CHKDSK"
        Write-Host "[5] Ver informações de disco"
        Write-Host "[6] Ver informações de rede"
        Write-Host "[7] Ver informações de inicialização"
        Write-Host "[8] Abrir Monitor de Confiabilidade"
        Write-Host "[0] Voltar"
        Write-Host ""

        $choice = Read-Host "Selecione uma opção"

        switch ($choice) {
            "1" { Invoke-DISMAndSFC }
            "2" { Invoke-DISMRestoreHealth }
            "3" { Invoke-SFCScannow }
            "4" { Invoke-CHKDSKScan }
            "5" { Show-DiskInformation }
            "6" { Show-NetworkInformation }
            "7" { Show-StartupInformation }
            "8" { Open-ReliabilityMonitor }
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

        Write-Host "[1] Mostrar informações de rede"
        Write-Host "[2] Testar ping em servidores conhecidos"
        Write-Host "[3] Testar velocidade aproximada da internet"
        Write-Host "[4] Reparo rápido de rede e DNS"
        Write-Host "[0] Voltar"
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


function Show-TweaksMenu {
    do {
        Show-Header "Ajustes"

        Write-Host "[1] Mostrar extensões de arquivos no Explorador de Arquivos"
        Write-Host "[2] Desativar Xbox Game Bar"
        Write-Host "[3] Desativar dicas e sugestões do Windows"
        Write-Host "[4] Definir plano de energia em Alto desempenho"
        Write-Host "[5] Desativar economia de energia PCI Express"
        Write-Host "[6] Desativar desligamento automático de tela e suspensão"
        Write-Host "[7] Desativar Inicialização Rápida"
        Write-Host "[8] Desativar hibernação"
        Write-Host "[0] Voltar"
        Write-Host ""

        $choice = Read-Host "Selecione uma opção"

        switch ($choice) {
            "1" { Enable-FileExtensions }
            "2" { Disable-XboxGameBar }
            "3" { Disable-WindowsTipsAndSuggestions }
            "4" { Set-HighPerformancePowerPlan }
            "5" { Disable-PciExpressLinkStatePowerManagement }
            "6" { Disable-AutomaticDisplayAndSleepTimeout }
            "7" { Disable-FastStartup }
            "8" { Disable-Hibernation }
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

        Write-Host "[1] Manutenção recomendada"
        Write-Host "[2] Atualizações"
        Write-Host "[3] Softwares"
        Write-Host "[4] Limpeza"
        Write-Host "[5] Diagnósticos"
        Write-Host "[6] Rede"
        Write-Host "[7] Ajustes"
        Write-Host "[8] Sobre este PC"
        Write-Host "[0] Sair"
        Write-Host ""

        $choice = Read-Host "Selecione uma opção"

        switch ($choice) {
            "1" { Run-RecommendedMaintenance }
            "2" { Show-UpdateMenu }
            "3" { Show-SoftwareMenu }
            "4" { Show-CleanupMenu }
            "5" { Show-DiagnosticsMenu }
            "6" { Show-NetworkMenu }
            "7" { Show-TweaksMenu }
            "8" { Show-AboutThisPC }
            "0" { Write-Host "`nSaindo do WinForge..." -ForegroundColor Yellow }
            default {
                Write-Host "`nOpção inválida." -ForegroundColor Red
                Pause
            }
        }
    } while ($choice -ne "0")
}


Export-ModuleMember -Function *
