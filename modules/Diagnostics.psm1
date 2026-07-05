function Get-WinForgeUptimeText {
    param (
        [datetime]$LastBootTime
    )

    if ($null -eq $LastBootTime) {
        return "Desconhecido"
    }

    $uptime = New-TimeSpan -Start $LastBootTime -End (Get-Date)
    $parts = @()

    if ($uptime.Days -gt 0) {
        if ($uptime.Days -eq 1) { $parts += "1 dia" } else { $parts += "$($uptime.Days) dias" }
    }

    if ($uptime.Hours -gt 0) {
        if ($uptime.Hours -eq 1) { $parts += "1 hora" } else { $parts += "$($uptime.Hours) horas" }
    }

    if ($uptime.Minutes -gt 0 -or $parts.Count -eq 0) {
        if ($uptime.Minutes -eq 1) {
            $parts += "1 minuto"
        }
        elseif ($uptime.Minutes -le 0 -and $parts.Count -eq 0) {
            $parts += "menos de 1 minuto"
        }
        else {
            $parts += "$($uptime.Minutes) minutos"
        }
    }

    return ($parts -join ", ")
}




function Convert-WinForgeBytesToFriendlyText {
    param (
        [object]$Bytes
    )

    if ($null -eq $Bytes) {
        return "Não disponível"
    }

    try {
        $numericBytes = [double]$Bytes

        if ($numericBytes -le 0) {
            return "Não disponível"
        }

        if ($numericBytes -ge 1TB) {
            return "$([Math]::Round($numericBytes / 1TB, 2)) TB"
        }

        if ($numericBytes -ge 1GB) {
            return "$([Math]::Round($numericBytes / 1GB, 2)) GB"
        }

        if ($numericBytes -ge 1MB) {
            return "$([Math]::Round($numericBytes / 1MB, 2)) MB"
        }

        return "$([Math]::Round($numericBytes, 0)) B"
    }
    catch {
        return "Não disponível"
    }
}


function Get-WinForgeDiskTypeText {
    param (
        [object]$Disk
    )

    if ($null -eq $Disk) {
        return "Não disponível"
    }

    $busType = ""
    $mediaType = ""

    if ($Disk.PSObject.Properties.Name -contains "BusType" -and $null -ne $Disk.BusType) {
        $busType = $Disk.BusType.ToString()
    }

    if ($Disk.PSObject.Properties.Name -contains "MediaType" -and $null -ne $Disk.MediaType) {
        $mediaType = $Disk.MediaType.ToString()
    }

    if ($busType -match "NVMe") { return "NVMe" }
    if ($mediaType -match "SSD") { return "SSD" }
    if ($mediaType -match "HDD") { return "HDD" }
    if ($busType -match "USB") { return "USB" }
    if ($busType -match "SATA") { return "SATA" }

    if (-not [string]::IsNullOrWhiteSpace($mediaType) -and $mediaType -ne "Unspecified") {
        return $mediaType
    }

    if (-not [string]::IsNullOrWhiteSpace($busType) -and $busType -ne "Unknown") {
        return $busType
    }

    return "Não disponível"
}


function Get-WinForgeDiskSummary {
    $diskSummary = @()

    try {
        $logicalDisks = @(
            Get-CimInstance Win32_LogicalDisk -Filter "DriveType = 3" -ErrorAction Stop |
            Sort-Object DeviceID
        )

        foreach ($logicalDisk in $logicalDisks) {
            $driveId = $logicalDisk.DeviceID
            $driveLetter = $driveId.TrimEnd(":")
            $disk = $null
            $diskModel = "Não disponível"
            $diskType = "Não disponível"

            try {
                $partition = Get-Partition -DriveLetter $driveLetter -ErrorAction Stop | Select-Object -First 1

                if ($null -ne $partition) {
                    $disk = $partition | Get-Disk -ErrorAction Stop | Select-Object -First 1
                }

                if ($null -ne $disk) {
                    if (-not [string]::IsNullOrWhiteSpace($disk.FriendlyName)) {
                        $diskModel = $disk.FriendlyName
                    }

                    $diskType = Get-WinForgeDiskTypeText -Disk $disk
                }
            }
            catch {
                try {
                    $physicalDisk = Get-CimInstance Win32_DiskDrive -ErrorAction SilentlyContinue | Select-Object -First 1

                    if ($null -ne $physicalDisk) {
                        if (-not [string]::IsNullOrWhiteSpace($physicalDisk.Model)) {
                            $diskModel = $physicalDisk.Model
                        }

                        if (-not [string]::IsNullOrWhiteSpace($physicalDisk.MediaType)) {
                            if ($physicalDisk.MediaType -match "SSD") { $diskType = "SSD" }
                            elseif ($physicalDisk.MediaType -match "HDD|Fixed") { $diskType = "HDD" }
                            else { $diskType = $physicalDisk.MediaType }
                        }
                        elseif (-not [string]::IsNullOrWhiteSpace($physicalDisk.InterfaceType)) {
                            $diskType = $physicalDisk.InterfaceType
                        }
                    }
                }
                catch {
                    $diskModel = "Não disponível"
                    $diskType = "Não disponível"
                }
            }

            $totalBytes = $logicalDisk.Size
            $freeBytes = $logicalDisk.FreeSpace
            $usedBytes = $null
            $usagePercent = "Não disponível"

            if ($null -ne $totalBytes -and $totalBytes -gt 0) {
                $usedBytes = [double]$totalBytes - [double]$freeBytes
                $usagePercent = "$([Math]::Round(($usedBytes / [double]$totalBytes) * 100, 0))%"
            }

            $diskSummary += [PSCustomObject]@{
                Unidade = $driveId
                Tipo    = $diskType
                Modelo  = $diskModel
                Total   = Convert-WinForgeBytesToFriendlyText -Bytes $totalBytes
                Livre   = Convert-WinForgeBytesToFriendlyText -Bytes $freeBytes
                Usado   = Convert-WinForgeBytesToFriendlyText -Bytes $usedBytes
                Uso     = $usagePercent
            }
        }
    }
    catch {
        return @()
    }

    return @($diskSummary)
}


function Show-WinForgeDiskSummary {
    param (
        [switch]$IncludeSpeedTable
    )

    $disks = @(Get-WinForgeDiskSummary)

    if ($disks.Count -eq 0) {
        Write-Host "Não foi possível detectar informações de disco." -ForegroundColor Yellow
        return
    }

    $disks | Format-Table Unidade, Tipo, Modelo, Total, Livre, Usado, Uso -AutoSize | Out-Host

    if ($IncludeSpeedTable) {
        Write-Host ""
        Write-Host "Velocidade dos discos, se disponível:" -ForegroundColor Cyan
        Write-Host ""

        $disks |
            Select-Object `
                @{ Name = "Disco"; Expression = { $_.Modelo } },
                @{ Name = "Leitura"; Expression = { "Não disponível" } },
                @{ Name = "Escrita"; Expression = { "Não disponível" } } |
            Format-Table -AutoSize |
            Out-Host

        Write-Host "Observação: o WinForge não inventa velocidades. Leitura/escrita só serão exibidas quando houver fonte confiável." -ForegroundColor Yellow
    }
}


function Show-AboutThisPC {
    Show-Header "Sobre Este PC"

    try {
        $baseBoard = Get-CimInstance Win32_BaseBoard
        $bios = Get-CimInstance Win32_BIOS
        $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
        $memoryModules = @(Get-CimInstance Win32_PhysicalMemory)
        $gpuList = @(Get-CimInstance Win32_VideoController)
        $os = Get-CimInstance Win32_OperatingSystem

        $computerName = $env:COMPUTERNAME
        $userName = $env:USERNAME
        $motherboardManufacturer = $baseBoard.Manufacturer
        $motherboardModel = $baseBoard.Product
        $biosVersion = $bios.SMBIOSBIOSVersion

        try {
            $secureBootEnabled = Confirm-SecureBootUEFI -ErrorAction Stop
            if ($secureBootEnabled) { $secureBootStatus = "Ativado" } else { $secureBootStatus = "Desativado" }
        }
        catch {
            $secureBootStatus = "Indisponível / não suportado"
        }

        $cpuName = $cpu.Name.Trim()
        $cpuCurrentClockGHz = [Math]::Round($cpu.CurrentClockSpeed / 1000, 2)
        $cpuMaxClockGHz = [Math]::Round($cpu.MaxClockSpeed / 1000, 2)

        $totalRamBytes = ($memoryModules | Measure-Object -Property Capacity -Sum).Sum
        $totalRamGB = [Math]::Round($totalRamBytes / 1GB, 2)
        $moduleCount = @($memoryModules).Count

        $memoryTypeCode = ($memoryModules | Select-Object -First 1).SMBIOSMemoryType
        $memoryType = Convert-MemoryType -Type $memoryTypeCode

        $configuredSpeeds = @(
            $memoryModules |
            Select-Object -ExpandProperty ConfiguredClockSpeed -Unique |
            Where-Object { $_ -ne $null -and $_ -gt 0 }
        )

        if ($configuredSpeeds.Count -gt 0) {
            $ramClockText = ($configuredSpeeds -join " / ") + " MHz"
        }
        else {
            $ramClockText = "Desconhecido"
        }

        $expoXmpStatus = Get-ExpoXmpStatus -MemoryModules $memoryModules

        $validGpus = @(
            $gpuList | Where-Object {
                $_.Name -notmatch "Microsoft Basic" -and
                $_.Name -notmatch "Remote" -and
                $_.Name -notmatch "Parsec" -and
                -not [string]::IsNullOrWhiteSpace($_.Name)
            }
        )

        if ($validGpus.Count -eq 0) {
            $validGpus = $gpuList
        }

        $windowsName = $os.Caption
        $windowsVersion = $os.Version
        $windowsBuild = $os.BuildNumber

        $lastBootTime = $os.LastBootUpTime
        $pcUptimeText = "Desconhecido"
        $lastBootText = "Desconhecido"

        if ($null -ne $lastBootTime) {
            $pcUptimeText = Get-WinForgeUptimeText -LastBootTime $lastBootTime
            $lastBootText = $lastBootTime.ToString("dd/MM/yyyy HH:mm")
        }

        Write-Host "Sistema" -ForegroundColor Cyan
        Write-Host "Computador:          $computerName"
        Write-Host "Usuário:             $userName"
        Write-Host "Sistema Operacional: $windowsName"
        Write-Host "Versão:              $windowsVersion"
        Write-Host "Build:               $windowsBuild"
        Write-Host "Ligado há: $pcUptimeText | Inicializado em: $lastBootText"
        Write-Host ""

        Write-Host "Placa-mãe" -ForegroundColor Cyan
        Write-Host "Fabricante: $motherboardManufacturer"
        Write-Host "Modelo:     $motherboardModel"
        Write-Host ""

        Write-Host "BIOS / Secure Boot" -ForegroundColor Cyan
        Write-Host "Versão da BIOS: $biosVersion"
        Write-Host "Secure Boot:    $secureBootStatus"
        Write-Host ""

        Write-Host "Processador" -ForegroundColor Cyan
        Write-Host "CPU:          $cpuName"
        Write-Host "Clock atual:  $cpuCurrentClockGHz GHz"
        Write-Host "Clock máximo: $cpuMaxClockGHz GHz"
        Write-Host ""

        Write-Host "Memória" -ForegroundColor Cyan
        Write-Host "RAM total:              $totalRamGB GB"
        Write-Host "Módulos:                $moduleCount"
        Write-Host "Tipo:                   $memoryType"
        Write-Host "Velocidade configurada: $ramClockText"
        Write-Host "Status XMP/EXPO:        $expoXmpStatus"
        Write-Host ""

        Write-Host "Vídeo" -ForegroundColor Cyan

        foreach ($gpu in $validGpus) {
            $gpuName = $gpu.Name.Trim()
            $isIntegratedGpu = Test-IsIntegratedGpu -GpuName $gpuName

            if ($isIntegratedGpu) {
                Write-Host "GPU:  $gpuName"
                Write-Host "VRAM: Memória compartilhada / GPU integrada"
                Write-Host ""
                continue
            }

            $registryVramBytes = Get-RegistryGpuMemoryBytes -GpuName $gpuName

            if ($null -ne $registryVramBytes -and $registryVramBytes -gt 0) {
                $vramText = Convert-BytesToGBText -Bytes $registryVramBytes
            }
            elseif ($gpu.AdapterRAM -gt 0) {
                $vramText = Convert-BytesToGBText -Bytes ([UInt64]$gpu.AdapterRAM)
            }
            else {
                $vramText = "Desconhecido"
            }

            Write-Host "GPU:  $gpuName"
            Write-Host "VRAM: $vramText"
            Write-Host ""
        }

        Write-Host "Discos" -ForegroundColor Cyan
        Write-Host ""
        Show-WinForgeDiskSummary -IncludeSpeedTable
        Write-Host ""

        Write-Host "Nota: o status XMP/EXPO é inferido pela velocidade configurada da RAM." -ForegroundColor Yellow
        Write-Host "O Windows não expõe diretamente o estado do perfil de memória da BIOS." -ForegroundColor Yellow
    }
    catch {
        Write-Host "Ocorreu um erro ao ler as informações do sistema:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }

    Write-Host ""
    Pause
}

function Show-ProblemDevices {
    Show-Header "Dispositivos com Problema"

    try {
        $problemDevices = @(
            Get-PnpDevice -PresentOnly |
            Where-Object {
                $problemText = ""

                if ($null -ne $_.Problem) {
                    $problemText = $_.Problem.ToString()
                }

                $_.Status -ne "OK" -or
                (
                    -not [string]::IsNullOrWhiteSpace($problemText) -and
                    $problemText -notin @("0", "CM_PROB_NONE")
                )
            }
        )

        $realProblems = @(
            $problemDevices |
            Where-Object {
                $null -eq $_.Problem -or $_.Problem.ToString() -ne "CM_PROB_DISABLED"
            }
        )

        $disabledDevices = @(
            $problemDevices |
            Where-Object {
                $null -ne $_.Problem -and $_.Problem.ToString() -eq "CM_PROB_DISABLED"
            }
        )

        Write-Host "Dispositivos presentes com driver ausente, falha ou problema ativo:" -ForegroundColor Cyan
        Write-Host ""

        if ($realProblems.Count -eq 0) {
            Write-Host "Nenhum dispositivo presente com problema real foi encontrado." -ForegroundColor Green
        }
        else {
            $realProblems |
                Select-Object Status, Class, FriendlyName, Problem, InstanceId |
                Format-Table -AutoSize
        }

        Write-Host ""

        if ($disabledDevices.Count -gt 0) {
            Write-Host "Dispositivos desativados detectados:" -ForegroundColor Yellow
            Write-Host ""

            $disabledDevices |
                Select-Object Status, Class, FriendlyName, Problem, InstanceId |
                Format-Table -AutoSize

            Write-Host ""
            Write-Host "Dispositivos desativados podem ser intencionais. Exemplo: GPU integrada desativada manualmente." -ForegroundColor Yellow
        }

        Write-Host ""
        Write-Host "Observação:" -ForegroundColor Yellow
        Write-Host "Esta verificação mostra erros ativos de dispositivo/driver, mas não garante que todos os drivers estejam na versão mais recente." -ForegroundColor Yellow
    }
    catch {
        Write-Host "Ocorreu um erro ao consultar dispositivos PnP:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }

    Write-Host ""
    Pause
}


function Invoke-DISMRestoreHealth {
    Invoke-DiagnosticCommand `
        -Title "Reparar Imagem do Windows" `
        -FilePath "dism.exe" `
        -Arguments @("/Online", "/Cleanup-Image", "/RestoreHealth") `
        -Description @(
            "Verifica e repara a imagem/componentes do Windows.",
            "Útil quando atualizações, componentes ou arquivos do sistema podem estar corrompidos."
        ) `
        -Warnings @(
            "Esta operação pode levar vários minutos.",
            "Arquivos pessoais não serão removidos."
        )
}


function Invoke-SFCScannow {
    Invoke-DiagnosticCommand `
        -Title "Verificar e Reparar Arquivos do Sistema" `
        -FilePath "sfc.exe" `
        -Arguments @("/scannow") `
        -Description @(
            "Verifica arquivos protegidos do sistema Windows.",
            "Se arquivos corrompidos forem encontrados, o Windows tentará repará-los."
        ) `
        -Warnings @(
            "Esta operação pode levar vários minutos.",
            "Arquivos pessoais não serão removidos."
        )
}


function Invoke-DISMAndSFC {
    Show-Header "Reparar Windows"

    Write-Host "O WinForge executará a sequência recomendada de reparo:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "1. Reparar imagem do Windows" -ForegroundColor Cyan
    Write-Host "2. Verificar e reparar arquivos do sistema" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Arquivos pessoais não serão removidos." -ForegroundColor Yellow
    Write-Host ""

    $confirmed = Confirm-Action "Deseja iniciar o reparo do Windows?"

    if ($confirmed -eq $false) {
        Write-Host ""
        Write-Host "Operação cancelada." -ForegroundColor Yellow
        Write-Host ""
        Pause
        return
    }

    $dismSuccess = Invoke-DiagnosticCommand `
        -Title "Etapa 1 - Reparar Imagem do Windows" `
        -FilePath "dism.exe" `
        -Arguments @("/Online", "/Cleanup-Image", "/RestoreHealth") `
        -Description @("Reparando a imagem/componentes do Windows.") `
        -Warnings @("Isto pode levar vários minutos.") `
        -SkipConfirmation `
        -NoClear `
        -NoPause

    if ($dismSuccess -eq $false) {
        Write-Host ""
        Write-Host "A primeira etapa não foi concluída com sucesso." -ForegroundColor Yellow
        Write-Host "A verificação de arquivos do sistema ainda será executada." -ForegroundColor Yellow
        Write-Host ""
    }

    $sfcSuccess = Invoke-DiagnosticCommand `
        -Title "Etapa 2 - Verificar e Reparar Arquivos do Sistema" `
        -FilePath "sfc.exe" `
        -Arguments @("/scannow") `
        -Description @("Verificando arquivos protegidos do sistema.") `
        -Warnings @("Isto pode levar vários minutos.") `
        -SkipConfirmation `
        -NoClear `
        -NoPause

    Write-Host ""
    Write-Host "Resumo do reparo" -ForegroundColor Cyan
    Write-Host ""

    if ($dismSuccess) { Write-Host "Imagem do Windows: concluída com sucesso" -ForegroundColor Green } else { Write-Host "Imagem do Windows: finalizada com alertas ou erros" -ForegroundColor Yellow }
    if ($sfcSuccess) { Write-Host "Arquivos do sistema: concluído com sucesso" -ForegroundColor Green } else { Write-Host "Arquivos do sistema: finalizado com alertas ou erros" -ForegroundColor Yellow }

    Write-Host ""
    Pause
}



function Invoke-CHKDSKScan {
    Show-Header "Verificar Disco com CHKDSK"

    $drive = $env:SystemDrive

    Write-Host "Esta opção verifica erros no sistema de arquivos e no disco do sistema." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Comando inicial:" -ForegroundColor Cyan
    Write-Host "chkdsk.exe $drive /scan"
    Write-Host ""
    Write-Host "A verificação online mantém a saída visível e não usa /R." -ForegroundColor Yellow
    Write-Host "Se o Windows indicar reparo pendente, o WinForge perguntará antes de agendar verificação no próximo reinício." -ForegroundColor Yellow
    Write-Host ""

    $confirmed = Confirm-Action "Deseja verificar o disco com CHKDSK?"

    if ($confirmed -eq $false) {
        Write-Host ""
        Write-Host "Operação cancelada." -ForegroundColor Yellow
        Write-Host ""
        Pause
        return
    }

    try {
        Write-Host ""
        $chkdskOutput = chkdsk.exe $drive /scan 2>&1
        $chkdskOutput | ForEach-Object { Write-Host $_ }
        $exitCode = $LASTEXITCODE
        $outputText = $chkdskOutput -join "`n"

        Write-Host ""

        if ($exitCode -eq 0) {
            Write-Host "CHKDSK finalizado sem erros críticos reportados." -ForegroundColor Green
        }
        else {
            Write-Host "CHKDSK finalizou com código de saída: $exitCode" -ForegroundColor Yellow
            Write-Host "Revise a saída acima." -ForegroundColor Yellow
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
            Write-Host "O CHKDSK indicou que pode haver verificação ou reparo pendente para o próximo reinício." -ForegroundColor Yellow
            Write-Host ""

            $scheduleConfirmed = Confirm-Action "Deseja agendar a verificação do disco para a próxima reinicialização?"

            if ($scheduleConfirmed) {
                Write-Host ""
                Write-Host "Comando: chkntfs.exe /C $drive" -ForegroundColor DarkCyan
                chkntfs.exe /C $drive
                Write-Host "Verificação agendada. Reinicie o Windows para executar." -ForegroundColor Green
            }
            else {
                Write-Host ""
                Write-Host "Agendamento não realizado." -ForegroundColor Yellow
            }
        }
    }
    catch {
        Write-Host ""
        Write-Host "Ocorreu um erro ao executar CHKDSK:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }

    Write-Host ""
    Pause
}


function Show-DiskInformation {
    Show-Header "Informações de Disco"

    try {
        Write-Host "Volumes e discos" -ForegroundColor Cyan
        Write-Host ""
        Show-WinForgeDiskSummary -IncludeSpeedTable
    }
    catch {
        Write-Host "Ocorreu um erro ao consultar informações de disco:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }

    Write-Host ""
    Pause
}

function Show-StartupInformation {
    Show-Header "Informações de Inicialização"

    try {
        $os = Get-CimInstance Win32_OperatingSystem
        $lastBootTime = $os.LastBootUpTime

        if ($null -ne $lastBootTime) {
            Write-Host "Ligado há: $(Get-WinForgeUptimeText -LastBootTime $lastBootTime) | Inicializado em: $($lastBootTime.ToString('dd/MM/yyyy HH:mm'))" -ForegroundColor Cyan
        }
        else {
            Write-Host "Inicialização: Desconhecida" -ForegroundColor Yellow
        }

        Write-Host ""
        Write-Host "Inicialização Rápida" -ForegroundColor Cyan

        $fastStartupPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power"
        $fastStartupValue = $null

        try {
            $fastStartupValue = (Get-ItemProperty -Path $fastStartupPath -Name "HiberbootEnabled" -ErrorAction Stop).HiberbootEnabled
        }
        catch {
            $fastStartupValue = $null
        }

        if ($fastStartupValue -eq 1) { Write-Host "Status: Ativada" }
        elseif ($fastStartupValue -eq 0) { Write-Host "Status: Desativada" }
        else { Write-Host "Status: Desconhecido" }

        Write-Host ""
        Write-Host "Hibernação / modos de energia" -ForegroundColor Cyan
        powercfg.exe /a
    }
    catch {
        Write-Host "Ocorreu um erro ao consultar informações de inicialização:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }

    Write-Host ""
    Pause
}


function Open-ReliabilityMonitor {
    Show-Header "Monitor de Confiabilidade"

    try {
        Write-Host "Abrindo Monitor de Confiabilidade..." -ForegroundColor Green
        Write-Host ""
        Write-Host "Use esta ferramenta para revisar crashes, falhas de aplicativos, falhas do Windows e LiveKernelEvents." -ForegroundColor Yellow

        Start-Process -FilePath "perfmon.exe" -ArgumentList "/rel"
    }
    catch {
        Write-Host "Ocorreu um erro ao abrir o Monitor de Confiabilidade:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }

    Write-Host ""
    Pause
}


Export-ModuleMember -Function *
