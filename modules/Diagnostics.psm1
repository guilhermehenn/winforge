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
                # Não associa o primeiro disco físico a todas as unidades. Em sistemas
                # com múltiplos discos, essa inferência produziria dados incorretos.
                $diskModel = "Não disponível"
                $diskType = "Não disponível"
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
    $disks = @(Get-WinForgeDiskSummary)

    if ($disks.Count -eq 0) {
        Write-Host "Não foi possível detectar informações de disco." -ForegroundColor Yellow
        return
    }

    $disks | Format-Table Unidade, Tipo, Modelo, Total, Livre, Usado, Uso -AutoSize | Out-Host
}


function Show-AboutThisPC {
    Show-Header "Sobre este PC"

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

        Write-WinForgeSection -Title "Sistema"
        Write-WinForgeKeyValue -Label "Computador" -Value $computerName
        Write-WinForgeKeyValue -Label "Usuário" -Value $userName
        Write-WinForgeKeyValue -Label "Sistema operacional" -Value $windowsName
        Write-WinForgeKeyValue -Label "Versão" -Value $windowsVersion
        Write-WinForgeKeyValue -Label "Build" -Value $windowsBuild
        Write-WinForgeKeyValue -Label "Tempo ligado" -Value $pcUptimeText
        Write-WinForgeKeyValue -Label "Última inicialização" -Value $lastBootText

        Write-WinForgeSection -Title "Placa-mãe"
        Write-WinForgeKeyValue -Label "Fabricante" -Value $motherboardManufacturer
        Write-WinForgeKeyValue -Label "Modelo" -Value $motherboardModel

        Write-WinForgeSection -Title "BIOS e segurança"
        Write-WinForgeKeyValue -Label "Versão da BIOS" -Value $biosVersion
        Write-WinForgeKeyValue -Label "Secure Boot" -Value $secureBootStatus

        Write-WinForgeSection -Title "Processador"
        Write-WinForgeKeyValue -Label "CPU" -Value $cpuName
        Write-WinForgeKeyValue -Label "Clock atual" -Value "$cpuCurrentClockGHz GHz"
        Write-WinForgeKeyValue -Label "Clock máximo" -Value "$cpuMaxClockGHz GHz"

        Write-WinForgeSection -Title "Memória"
        Write-WinForgeKeyValue -Label "RAM total" -Value "$totalRamGB GB"
        Write-WinForgeKeyValue -Label "Módulos" -Value $moduleCount
        Write-WinForgeKeyValue -Label "Tipo" -Value $memoryType
        Write-WinForgeKeyValue -Label "Velocidade configurada" -Value $ramClockText
        Write-WinForgeKeyValue -Label "Status XMP/EXPO" -Value $expoXmpStatus

        Write-WinForgeSection -Title "Vídeo"

        foreach ($gpu in $validGpus) {
            $gpuName = $gpu.Name.Trim()
            $isIntegratedGpu = Test-IsIntegratedGpu -GpuName $gpuName

            if ($isIntegratedGpu) {
                Write-WinForgeKeyValue -Label "GPU" -Value $gpuName
                Write-WinForgeKeyValue -Label "VRAM" -Value "Memória compartilhada / GPU integrada"
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

            Write-WinForgeKeyValue -Label "GPU" -Value $gpuName
            Write-WinForgeKeyValue -Label "VRAM" -Value $vramText
            Write-Host ""
        }

        Write-WinForgeSection -Title "Discos"
        Show-WinForgeDiskSummary
        Write-Host ""

        Write-WinForgeStatus -Type Info -Message "XMP/EXPO é inferido pela velocidade configurada; o Windows não expõe o perfil da BIOS diretamente."
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

        Write-WinForgeSection -Title "Problemas ativos"

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
            Write-WinForgeSection -Title "Dispositivos desativados"

            $disabledDevices |
                Select-Object Status, Class, FriendlyName, Problem, InstanceId |
                Format-Table -AutoSize

            Write-Host ""
            Write-Host "Dispositivos desativados podem ser intencionais. Exemplo: GPU integrada desativada manualmente." -ForegroundColor Yellow
        }

        Write-Host ""
        Write-WinForgeStatus -Type Info -Message "A verificação mostra falhas ativas; não compara versões de drivers."
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
        -Title "Reparar Imagem e Componentes do Windows" `
        -FilePath "dism.exe" `
        -Arguments @("/Online", "/Cleanup-Image", "/RestoreHealth") `
        -Description @("Repara a imagem de componentes usada pelo Windows.") `
        -Warnings @("Pode levar vários minutos. Arquivos pessoais não serão removidos.")
}


function Invoke-SFCScannow {
    Invoke-DiagnosticCommand `
        -Title "Verificar e Reparar Arquivos do Sistema" `
        -FilePath "sfc.exe" `
        -Arguments @("/scannow") `
        -Description @("Verifica arquivos protegidos do Windows e tenta reparar inconsistências.") `
        -Warnings @("Pode levar vários minutos. Arquivos pessoais não serão removidos.")
}


function Invoke-DISMAndSFC {
    Show-Header "Reparar Windows"

    Write-Host "Serão executados DISM e SFC, nesta ordem." -ForegroundColor Yellow
    Write-Host "Arquivos pessoais não serão removidos." -ForegroundColor Cyan
    Write-Host ""

    if (-not (Confirm-Action "Deseja iniciar o reparo?")) {
        Write-Host "`nOperação cancelada.`n" -ForegroundColor Yellow
        Pause
        return
    }

    $dismSuccess = Invoke-DiagnosticCommand `
        -Title "Etapa 1 - Reparar Imagem e Componentes do Windows" `
        -FilePath "dism.exe" `
        -Arguments @("/Online", "/Cleanup-Image", "/RestoreHealth") `
        -Description @("Executando DISM /RestoreHealth.") `
        -SkipConfirmation `
        -NoClear `
        -NoPause

    if (-not $dismSuccess) {
        Write-Host "`nDISM finalizou com alertas. O SFC será executado mesmo assim.`n" -ForegroundColor Yellow
    }

    $sfcSuccess = Invoke-DiagnosticCommand `
        -Title "Etapa 2 - Verificar e Reparar Arquivos do Sistema" `
        -FilePath "sfc.exe" `
        -Arguments @("/scannow") `
        -Description @("Executando SFC /scannow.") `
        -SkipConfirmation `
        -NoClear `
        -NoPause

    Write-Host ""
    Write-Host "Resumo" -ForegroundColor Cyan

    if ($dismSuccess) {
        Write-Host "DISM: OK" -ForegroundColor Green
    }
    else {
        Write-Host "DISM: verificar saída" -ForegroundColor Yellow
    }

    if ($sfcSuccess) {
        Write-Host "SFC:  OK" -ForegroundColor Green
    }
    else {
        Write-Host "SFC:  verificar saída" -ForegroundColor Yellow
    }

    Write-Host ""
    Pause
}


function Test-WinForgeChkdskRepairRequired {
    param (
        [int]$ExitCode,
        [string]$OutputText
    )

    # CHKDSK usa códigos de saída independentes do idioma do Windows.
    if ($ExitCode -ge 2) {
        return $true
    }

    return (
        $OutputText -match "spotfix" -or
        $OutputText -match "offline repair" -or
        $OutputText -match "reparo offline" -or
        $OutputText -match "next restart" -or
        $OutputText -match "próxima reinicialização" -or
        $OutputText -match "proxima reinicializacao"
    )
}


function Set-WinForgeChkdskStartupRepair {
    param (
        [string]$Drive,
        [switch]$ThrowOnFailure
    )

    try {
        foreach ($command in @("fsutil.exe", "chkntfs.exe")) {
            if (-not (Get-Command $command -ErrorAction SilentlyContinue)) {
                throw "Comando não encontrado: $command"
            }
        }

        # Marca o volume como pendente e agenda o Autochk no próximo boot.
        & fsutil.exe dirty set $Drive
        if ($LASTEXITCODE -ne 0) {
            throw "Não foi possível marcar a unidade para reparo. Código: $LASTEXITCODE."
        }

        & chkntfs.exe /C $Drive
        if ($LASTEXITCODE -ne 0) {
            throw "Não foi possível agendar o CHKDSK. Código: $LASTEXITCODE."
        }

        Write-Host "Reparo agendado para a próxima reinicialização." -ForegroundColor Green
        return $true
    }
    catch {
        if ($ThrowOnFailure) {
            throw
        }

        Write-Host "Falha ao agendar o reparo: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}


function Invoke-WinForgeChkdskScan {
    param (
        [switch]$SkipConfirmation,
        [switch]$NoClear,
        [switch]$NoPause,
        [switch]$ScheduleRepairAutomatically,
        [switch]$ThrowOnFailure
    )

    if (-not $NoClear) {
        Show-Header "Verificar Sistema de Arquivos da Unidade"
    }
    else {
        Write-WinForgeSubStep "CHKDSK" "Verificando o sistema de arquivos da unidade do Windows."
    }

    if (-not (Test-IsAdministrator)) {
        $message = "Privilégios de Administrador são necessários para executar o CHKDSK."
        if ($ThrowOnFailure) { throw $message }
        Write-Host $message -ForegroundColor Red
        if (-not $NoPause) { Write-Host ""; Pause }
        return $false
    }

    if (-not (Get-Command "chkdsk.exe" -ErrorAction SilentlyContinue)) {
        $message = "Comando não encontrado: chkdsk.exe"
        if ($ThrowOnFailure) { throw $message }
        Write-Host $message -ForegroundColor Red
        if (-not $NoPause) { Write-Host ""; Pause }
        return $false
    }

    $drive = $env:SystemDrive
    $arguments = @($drive, "/scan")

    Write-WinForgeKeyValue -Label "Unidade" -Value $drive
    Write-WinForgeKeyValue -Label "Modo" -Value "Verificação online"
    Write-WinForgeCommand -Command "chkdsk.exe $($arguments -join ' ')"
    Write-Host ""

    if (-not $SkipConfirmation -and -not (Confirm-Action "Deseja iniciar a verificação?")) {
        Write-Host "`nOperação cancelada." -ForegroundColor Yellow
        if (-not $NoPause) { Write-Host ""; Pause }
        return $false
    }

    try {
        $output = chkdsk.exe @arguments 2>&1
        $output | ForEach-Object { Write-Host $_ }
        $exitCode = $LASTEXITCODE
        $outputText = $output -join "`n"

        Write-Host ""
        switch ($exitCode) {
            0 { Write-Host "Nenhum erro foi encontrado." -ForegroundColor Green }
            1 { Write-Host "Erros foram encontrados e corrigidos." -ForegroundColor Green }
            2 { Write-Host "Foram encontrados itens que exigem reparo adicional." -ForegroundColor Yellow }
            3 { Write-Host "A unidade não pôde ser verificada ou reparada completamente." -ForegroundColor Yellow }
            default { Write-Host "CHKDSK finalizou com código $exitCode." -ForegroundColor Yellow }
        }

        $repairRequired = Test-WinForgeChkdskRepairRequired -ExitCode $exitCode -OutputText $outputText

        if ($repairRequired) {
            Write-Host ""
            Write-Host "O Windows precisa concluir o reparo durante a inicialização." -ForegroundColor Yellow

            $scheduleRepair = $ScheduleRepairAutomatically
            if (-not $ScheduleRepairAutomatically) {
                $scheduleRepair = Confirm-Action "Deseja agendar o reparo para a próxima reinicialização?"
            }

            if ($scheduleRepair) {
                Set-WinForgeChkdskStartupRepair -Drive $drive -ThrowOnFailure:$ThrowOnFailure | Out-Null
            }
            else {
                Write-Host "Reparo não agendado." -ForegroundColor Yellow
            }
        }

        if ($ThrowOnFailure -and $exitCode -gt 1 -and -not $repairRequired) {
            throw "CHKDSK finalizou com código $exitCode."
        }

        return ($exitCode -le 1 -or $repairRequired)
    }
    catch {
        if ($ThrowOnFailure) {
            throw
        }

        Write-Host "`nErro ao executar CHKDSK: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
    finally {
        if (-not $NoPause) {
            Write-Host ""
            Pause
        }
    }
}


function Invoke-CHKDSKScan {
    Invoke-WinForgeChkdskScan | Out-Null
}


function Invoke-WinForgeDriveOptimization {
    param (
        [switch]$SkipConfirmation,
        [switch]$NoClear,
        [switch]$NoPause,
        [switch]$ThrowOnFailure
    )

    if (-not $NoClear) {
        Show-Header "Otimizar Unidade do Sistema"
    }
    else {
        Write-WinForgeSubStep "Otimização" "Aplicando a operação adequada ao tipo de mídia."
    }

    if (-not (Test-IsAdministrator)) {
        $message = "Privilégios de Administrador são necessários para otimizar a unidade."
        if ($ThrowOnFailure) { throw $message }
        Write-Host $message -ForegroundColor Red
        if (-not $NoPause) { Write-Host ""; Pause }
        return $false
    }

    if (-not (Get-Command "defrag.exe" -ErrorAction SilentlyContinue)) {
        $message = "Comando não encontrado: defrag.exe"
        if ($ThrowOnFailure) { throw $message }
        Write-Host $message -ForegroundColor Red
        if (-not $NoPause) { Write-Host ""; Pause }
        return $false
    }

    $drive = $env:SystemDrive
    $arguments = @($drive, "/O", "/U", "/V")

    # /O delega ao Windows a escolha correta: retrim/otimização para SSD e desfragmentação para HDD.
    Write-WinForgeKeyValue -Label "Unidade" -Value $drive
    Write-WinForgeKeyValue -Label "Modo" -Value "Automático para SSD/HDD"
    Write-WinForgeCommand -Command "defrag.exe $($arguments -join ' ')"
    Write-Host ""

    if (-not $SkipConfirmation -and -not (Confirm-Action "Deseja iniciar a otimização?")) {
        Write-Host "`nOperação cancelada." -ForegroundColor Yellow
        if (-not $NoPause) { Write-Host ""; Pause }
        return $false
    }

    try {
        & defrag.exe @arguments
        $exitCode = $LASTEXITCODE
        Write-Host ""

        if ($exitCode -eq 0) {
            Write-Host "Otimização concluída." -ForegroundColor Green
            return $true
        }

        $message = "A otimização finalizou com código $exitCode."
        if ($ThrowOnFailure) { throw $message }
        Write-Host $message -ForegroundColor Yellow
        return $false
    }
    catch {
        if ($ThrowOnFailure) {
            throw
        }

        Write-Host "`nErro ao otimizar a unidade: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
    finally {
        if (-not $NoPause) {
            Write-Host ""
            Pause
        }
    }
}


function Invoke-DriveOptimization {
    Invoke-WinForgeDriveOptimization | Out-Null
}

function Show-DiskInformation {
    Show-Header "Informações de Disco"

    try {
        Write-WinForgeSection -Title "Volumes e discos"
        Show-WinForgeDiskSummary
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
            Write-WinForgeSection -Title "Inicialização"
            Write-WinForgeKeyValue -Label "Tempo ligado" -Value (Get-WinForgeUptimeText -LastBootTime $lastBootTime)
            Write-WinForgeKeyValue -Label "Última inicialização" -Value ($lastBootTime.ToString('dd/MM/yyyy HH:mm'))
        }
        else {
            Write-Host "Inicialização: Desconhecida" -ForegroundColor Yellow
        }

        Write-WinForgeSection -Title "Inicialização Rápida"

        $fastStartupPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power"
        $fastStartupValue = $null

        try {
            $fastStartupValue = (Get-ItemProperty -Path $fastStartupPath -Name "HiberbootEnabled" -ErrorAction Stop).HiberbootEnabled
        }
        catch {
            $fastStartupValue = $null
        }

        if ($fastStartupValue -eq 1) { Write-WinForgeKeyValue -Label "Status" -Value "Ativada" }
        elseif ($fastStartupValue -eq 0) { Write-WinForgeKeyValue -Label "Status" -Value "Desativada" }
        else { Write-WinForgeKeyValue -Label "Status" -Value "Desconhecido" }

        Write-WinForgeSection -Title "Hibernação e modos de energia"

        if (Get-Command "powercfg.exe" -ErrorAction SilentlyContinue) {
            & powercfg.exe /a

            if ($LASTEXITCODE -ne 0) {
                Write-WinForgeStatus -Type Warning -Message "powercfg finalizou com código $LASTEXITCODE."
            }
        }
        else {
            Write-WinForgeStatus -Type Warning -Message "powercfg.exe não foi encontrado."
        }
    }
    catch {
        Write-Host "Ocorreu um erro ao consultar informações de inicialização:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }

    Write-Host ""
    Pause
}


function Open-DeviceManager {
    Show-Header "Gerenciador de Dispositivos"

    try {
        Write-WinForgeStatus -Type Running -Message "Abrindo Gerenciador de Dispositivos..."
        Start-Process -FilePath "mmc.exe" -ArgumentList "devmgmt.msc"
        Write-WinForgeOk "Gerenciador de Dispositivos aberto."
    }
    catch {
        Write-WinForgeStatus -Type Error -Message "Não foi possível abrir o Gerenciador de Dispositivos."
        Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
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
