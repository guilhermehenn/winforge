# Diagnósticos somente leitura: sistema, discos, dispositivos, eventos e reinício pendente.


function Get-WinForgeUptimeText {
    # Nullable: o CIM devolve $null quando não sabe a data do boot, e um parâmetro [datetime] comum transformaria isso
    # em "0001-01-01" (ou recusaria o valor), o que gerava um tempo ligado absurdo ou derrubava o relatório.
    param (
        [Nullable[datetime]]$LastBootTime
    )

    if ($null -eq $LastBootTime -or $LastBootTime.Year -lt 2000) {
        return "Desconhecido"
    }

    $uptime = (Get-Date) - $LastBootTime

    # Relógio ajustado depois do boot pode dar tempo negativo.
    if ($uptime.TotalMinutes -lt 1) {
        return "menos de 1 minuto"
    }

    $parts = @()

    if ($uptime.Days -gt 0) {
        if ($uptime.Days -eq 1) { $parts += "1 dia" } else { $parts += "$($uptime.Days) dias" }
    }

    if ($uptime.Hours -gt 0) {
        if ($uptime.Hours -eq 1) { $parts += "1 hora" } else { $parts += "$($uptime.Hours) horas" }
    }

    if ($uptime.Minutes -gt 0 -or $parts.Count -eq 0) {
        if ($uptime.Minutes -eq 1) { $parts += "1 minuto" } else { $parts += "$($uptime.Minutes) minutos" }
    }

    return ($parts -join ", ")
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

            # Nível ("Ok", "Low", "Critical" ou "Unknown") segue a mesma regra da tela inicial e da Manutenção.
            $level = "Unknown"

            if ($null -ne $totalBytes -and $totalBytes -gt 0 -and $null -ne $freeBytes) {
                $level = Get-WinForgeDiskSpaceLevel -FreeBytes $freeBytes -TotalBytes $totalBytes
            }

            $diskSummary += [PSCustomObject]@{
                Unidade = $driveId
                Tipo    = $diskType
                Modelo  = $diskModel
                Total   = Format-WinForgeBytes -Bytes $totalBytes -ZeroText "Não disponível"
                Livre   = Format-WinForgeBytes -Bytes $freeBytes -ZeroText "0 B"
                Usado   = Format-WinForgeBytes -Bytes $usedBytes -ZeroText "0 B"
                Uso     = $usagePercent
                Nivel   = $level
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
        Write-WinForgeStatus -Type Warning -Message "Não foi possível detectar informações de disco."
        return
    }

    $disks | Format-Table Unidade, Tipo, Modelo, Total, Livre, Usado, Uso -AutoSize | Out-Host

    foreach ($disk in @($disks | Where-Object { $_.Nivel -in @("Low", "Critical") })) {
        Write-WinForgeStatus -Type Warning -Message "A unidade $($disk.Unidade) está quase cheia: $($disk.Livre) livres de $($disk.Total)."
    }

    if (@($disks | Where-Object { $_.Nivel -in @("Low", "Critical") }).Count -gt 0) {
        Write-WinForgeStatus -Type Info -Message "Para liberar espaço, use a página Limpeza."
    }
}


function Get-WinForgeCimOrNull {
    # Consulta CIM tolerante: uma classe indisponível (máquina virtual, WMI com defeito) não derruba a tela inteira.
    param (
        [Parameter(Mandatory)]
        [string]$ClassName
    )

    try {
        return @(Get-CimInstance -ClassName $ClassName -ErrorAction Stop)
    }
    catch {
        return @()
    }
}


function Show-WinForgeSystemInfo {
    Enter-WinForgeAction -Title "Sobre este PC"

    try {
        $baseBoard = Get-WinForgeCimOrNull -ClassName "Win32_BaseBoard" | Select-Object -First 1
        $bios = Get-WinForgeCimOrNull -ClassName "Win32_BIOS" | Select-Object -First 1
        $cpu = Get-WinForgeCimOrNull -ClassName "Win32_Processor" | Select-Object -First 1
        $memoryModules = @(Get-WinForgeCimOrNull -ClassName "Win32_PhysicalMemory")
        $gpuList = @(Get-WinForgeCimOrNull -ClassName "Win32_VideoController")
        $os = Get-WinForgeCimOrNull -ClassName "Win32_OperatingSystem" | Select-Object -First 1

        try {
            $secureBootEnabled = Confirm-SecureBootUEFI -ErrorAction Stop
            $secureBootStatus = $(if ($secureBootEnabled) { "Ativado" } else { "Desativado" })
        }
        catch {
            $secureBootStatus = "Indisponível / não suportado"
        }

        # RAM: a soma dos módulos; em máquinas virtuais a lista de módulos vem vazia e vale o total do sistema.
        $totalRamBytes = ($memoryModules | Measure-Object -Property Capacity -Sum).Sum

        if ($null -eq $totalRamBytes -or $totalRamBytes -le 0) {
            $computerSystem = Get-WinForgeCimOrNull -ClassName "Win32_ComputerSystem" | Select-Object -First 1
            $totalRamBytes = $(if ($computerSystem) { $computerSystem.TotalPhysicalMemory } else { $null })
        }

        $memoryTypeCode = ($memoryModules | Select-Object -First 1).SMBIOSMemoryType
        $memoryType = $(if ($memoryModules.Count -gt 0) { Convert-WinForgeMemoryType -Type ([int]$memoryTypeCode) } else { "Não disponível" })

        # ForEach-Object em vez de Select-Object -ExpandProperty: se a propriedade não existir nesta versão do Windows,
        # a tela continua em vez de falhar inteira.
        $configuredSpeeds = @(
            $memoryModules |
            ForEach-Object { $_.ConfiguredClockSpeed } |
            Where-Object { $null -ne $_ -and $_ -gt 0 } |
            Select-Object -Unique
        )

        $ramClockText = $(if ($configuredSpeeds.Count -gt 0) { ($configuredSpeeds -join " / ") + " MHz" } else { "Desconhecido" })

        $validGpus = @(
            $gpuList | Where-Object {
                -not [string]::IsNullOrWhiteSpace($_.Name) -and
                $_.Name -notmatch "Microsoft Basic" -and
                $_.Name -notmatch "Remote" -and
                $_.Name -notmatch "Parsec"
            }
        )

        if ($validGpus.Count -eq 0) {
            $validGpus = @($gpuList | Where-Object { -not [string]::IsNullOrWhiteSpace($_.Name) })
        }

        $lastBootTime = $(if ($os) { $os.LastBootUpTime } else { $null })
        $pcUptimeText = "Desconhecido"
        $lastBootText = "Desconhecido"

        if ($null -ne $lastBootTime) {
            $pcUptimeText = Get-WinForgeUptimeText -LastBootTime $lastBootTime
            $lastBootText = $lastBootTime.ToString("dd/MM/yyyy HH:mm")
        }

        Write-WinForgeSection -Title "Sistema"
        Write-WinForgeKeyValue -Label "Computador" -Value $env:COMPUTERNAME
        Write-WinForgeKeyValue -Label "Usuário" -Value $env:USERNAME
        Write-WinForgeKeyValue -Label "Sistema operacional" -Value $(if ($os) { $os.Caption } else { $null })
        Write-WinForgeKeyValue -Label "Versão" -Value $(if ($os) { $os.Version } else { $null })
        Write-WinForgeKeyValue -Label "Build" -Value $(if ($os) { $os.BuildNumber } else { $null })
        Write-WinForgeKeyValue -Label "Tempo ligado" -Value $pcUptimeText
        Write-WinForgeKeyValue -Label "Última inicialização" -Value $lastBootText
        Write-WinForgeKeyValue -Label "Reinício pendente" -Value $(if (Test-WinForgePendingReboot) { "Sim" } else { "Não" })

        Write-WinForgeSection -Title "Placa-mãe"
        Write-WinForgeKeyValue -Label "Fabricante" -Value $(if ($baseBoard) { $baseBoard.Manufacturer } else { $null })
        Write-WinForgeKeyValue -Label "Modelo" -Value $(if ($baseBoard) { $baseBoard.Product } else { $null })

        Write-WinForgeSection -Title "BIOS e segurança"
        Write-WinForgeKeyValue -Label "Versão da BIOS" -Value $(if ($bios) { $bios.SMBIOSBIOSVersion } else { $null })
        Write-WinForgeKeyValue -Label "Secure Boot" -Value $secureBootStatus

        Write-WinForgeSection -Title "Processador"
        Write-WinForgeKeyValue -Label "CPU" -Value $(if ($cpu) { ([string]$cpu.Name).Trim() } else { $null })
        Write-WinForgeKeyValue -Label "Clock atual" -Value $(if ($cpu -and $cpu.CurrentClockSpeed) { "$([Math]::Round($cpu.CurrentClockSpeed / 1000, 2)) GHz" } else { $null })
        Write-WinForgeKeyValue -Label "Clock máximo" -Value $(if ($cpu -and $cpu.MaxClockSpeed) { "$([Math]::Round($cpu.MaxClockSpeed / 1000, 2)) GHz" } else { $null })

        Write-WinForgeSection -Title "Memória"
        Write-WinForgeKeyValue -Label "RAM total" -Value (Format-WinForgeBytes -Bytes $totalRamBytes -ZeroText "Não disponível")
        Write-WinForgeKeyValue -Label "Módulos" -Value $(if ($memoryModules.Count -gt 0) { $memoryModules.Count } else { $null })
        Write-WinForgeKeyValue -Label "Tipo" -Value $memoryType
        Write-WinForgeKeyValue -Label "Velocidade configurada" -Value $ramClockText
        Write-WinForgeKeyValue -Label "Status XMP/EXPO" -Value (Get-WinForgeExpoXmpStatus -MemoryModules $memoryModules)

        Write-WinForgeSection -Title "Vídeo"

        foreach ($gpu in $validGpus) {
            $gpuName = ([string]$gpu.Name).Trim()

            if (Test-WinForgeIntegratedGpu -GpuName $gpuName) {
                $vramText = "Memória compartilhada / GPU integrada"
            }
            else {
                $registryVramBytes = Get-WinForgeGpuMemoryBytes -GpuName $gpuName

                # AdapterRAM é um valor de 32 bits e satura em 4 GB; o Registro só é consultado primeiro por isso.
                if ($null -ne $registryVramBytes -and $registryVramBytes -gt 0) {
                    $vramText = Format-WinForgeBytes -Bytes $registryVramBytes -ZeroText "Desconhecido"
                }
                else {
                    $vramText = Format-WinForgeBytes -Bytes $gpu.AdapterRAM -ZeroText "Desconhecido"
                }
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
        Write-WinForgeStatus -Type Error -Message "Ocorreu um erro ao ler as informações do sistema: $($_.Exception.Message)"
    }

    Exit-WinForgeAction
}


function Test-WinForgePnpDeviceHasProblem {
    # Um dispositivo tem problema quando o Windows registrou um código de problema ou o estado é Error/Degraded.
    # Status "Unknown" sem código de problema é comum em dispositivos de software e não indica defeito.
    param (
        [Parameter(Mandatory)]
        $Device
    )

    $problemText = ""

    if ($null -ne $Device.Problem) {
        $problemText = $Device.Problem.ToString()
    }

    $hasProblemCode = (-not [string]::IsNullOrWhiteSpace($problemText)) -and ($problemText -notin @("0", "CM_PROB_NONE"))
    $hasBadStatus = ([string]$Device.Status) -in @("Error", "Degraded")

    return ($hasProblemCode -or $hasBadStatus)
}


function Show-WinForgeProblemDevices {
    Enter-WinForgeAction -Title "Dispositivos com problema"

    try {
        $problemDevices = @(
            Get-PnpDevice -PresentOnly |
            Where-Object { Test-WinForgePnpDeviceHasProblem -Device $_ }
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
            Write-WinForgeStatus -Type Success -Message "Nenhum dispositivo presente com problema real foi encontrado."
        }
        else {
            $realProblems |
                Select-Object Status, Class, FriendlyName, Problem, InstanceId |
                Format-Table -AutoSize |
                Out-Host
        }

        Write-Host ""

        if ($disabledDevices.Count -gt 0) {
            Write-WinForgeSection -Title "Dispositivos desativados"

            $disabledDevices |
                Select-Object Status, Class, FriendlyName, Problem, InstanceId |
                Format-Table -AutoSize |
                Out-Host

            Write-Host ""
            Write-Host "Dispositivos desativados podem ser intencionais. Exemplo: GPU integrada desativada manualmente." -ForegroundColor Yellow
        }

        Write-Host ""
        Write-WinForgeStatus -Type Info -Message "A verificação mostra falhas ativas; não compara versões de drivers."
    }
    catch {
        Write-WinForgeStatus -Type Error -Message "Ocorreu um erro ao consultar dispositivos PnP: $($_.Exception.Message)"
    }

    Exit-WinForgeAction
}


function Show-WinForgeDisks {
    Enter-WinForgeAction -Title "Discos e espaço livre"

    try {
        Write-WinForgeSection -Title "Volumes e discos"
        Show-WinForgeDiskSummary
    }
    catch {
        Write-WinForgeStatus -Type Error -Message "Ocorreu um erro ao consultar informações de disco: $($_.Exception.Message)"
    }

    Exit-WinForgeAction
}


function Show-WinForgeStartupInfo {
    Enter-WinForgeAction -Title "Inicialização e energia"

    try {
        $os = Get-WinForgeCimOrNull -ClassName "Win32_OperatingSystem" | Select-Object -First 1
        $lastBootTime = $(if ($os) { $os.LastBootUpTime } else { $null })

        if ($null -ne $lastBootTime) {
            Write-WinForgeSection -Title "Inicialização"
            Write-WinForgeKeyValue -Label "Tempo ligado" -Value (Get-WinForgeUptimeText -LastBootTime $lastBootTime)
            Write-WinForgeKeyValue -Label "Última inicialização" -Value ($lastBootTime.ToString('dd/MM/yyyy HH:mm'))
        }
        else {
            Write-WinForgeStatus -Type Warning -Message "Inicialização: desconhecida."
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
            $exitCode = Invoke-WinForgeNative -FilePath "powercfg.exe" -Arguments @("/a") -IgnoreExitCode -PassThru

            if ($exitCode -ne 0) {
                Write-WinForgeStatus -Type Warning -Message "powercfg finalizou com código $exitCode."
            }
        }
        else {
            Write-WinForgeStatus -Type Warning -Message "powercfg.exe não foi encontrado."
        }
    }
    catch {
        Write-WinForgeStatus -Type Error -Message "Ocorreu um erro ao consultar informações de inicialização: $($_.Exception.Message)"
    }

    Exit-WinForgeAction
}


function Get-WinForgeStartupItems {
    <#
    Os programas que abrem junto com o Windows: as chaves Run (usuário e máquina) e as pastas Inicializar. Enabled é
    falso para o que a pessoa desativou em Configurações > Aplicativos de inicialização: o Windows mantém o item na
    lista e só marca em StartupApproved (primeiro byte ímpar = desativado).
    #>
    param (
        # Pastas Inicializar do usuário e de todos os usuários; o padrão são as do Windows.
        [string]$UserFolder = [Environment]::GetFolderPath("Startup"),
        [string]$CommonFolder = [Environment]::GetFolderPath("CommonStartup")
    )

    $approvedRoot = "Microsoft\Windows\CurrentVersion\Explorer\StartupApproved"
    $runKey = "Microsoft\Windows\CurrentVersion\Run"
    $items = @()

    $isDisabled = {
        param ($Approved, $Name)

        if (-not $Approved.Contains($Name)) { return $false }

        $bytes = @($Approved[$Name])

        return ($bytes.Count -gt 0 -and ([int]$bytes[0] -band 1) -eq 1)
    }

    $registrySources = @(
        @{ Source = "Registro (usuário)"; Path = "HKCU:\Software\$runKey"; Approved = "HKCU:\Software\$approvedRoot\Run" },
        @{ Source = "Registro (todos os usuários)"; Path = "HKLM:\SOFTWARE\$runKey"; Approved = "HKLM:\SOFTWARE\$approvedRoot\Run" },
        @{ Source = "Registro (32 bits)"; Path = "HKLM:\SOFTWARE\WOW6432Node\$runKey"; Approved = "HKLM:\SOFTWARE\$approvedRoot\Run32" }
    )

    foreach ($source in $registrySources) {
        $approved = Get-WinForgeRegistryValues -Path $source.Approved

        foreach ($name in @((Get-WinForgeRegistryValues -Path $source.Path).Keys)) {
            $items += [PSCustomObject]@{ Name = $name; Source = $source.Source; Enabled = -not (& $isDisabled $approved $name) }
        }
    }

    $folders = @(
        @{ Path = $UserFolder; Approved = "HKCU:\Software\$approvedRoot\StartupFolder" },
        @{ Path = $CommonFolder; Approved = "HKLM:\SOFTWARE\$approvedRoot\StartupFolder" }
    )

    foreach ($folder in $folders) {
        if ([string]::IsNullOrWhiteSpace($folder.Path) -or -not (Test-Path -LiteralPath $folder.Path -PathType Container)) {
            continue
        }

        $approved = Get-WinForgeRegistryValues -Path $folder.Approved

        foreach ($file in @(Get-ChildItem -LiteralPath $folder.Path -File -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne "desktop.ini" })) {
            $items += [PSCustomObject]@{ Name = $file.Name; Source = "Pasta Inicializar"; Enabled = -not (& $isDisabled $approved $file.Name) }
        }
    }

    return @($items)
}


function Get-WinForgePendingReboot {
    # Retorna uma lista de motivos. Strong = sinal confiável; PendingFileRenameOperations
    # aparece em muitas máquinas sem reinício realmente necessário.
    $reasons = @()

    if (Test-Path -LiteralPath "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending") {
        $reasons += [PSCustomObject]@{ Reason = "Atualização de componentes do Windows (CBS)"; Strong = $true }
    }

    if (Test-Path -LiteralPath "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired") {
        $reasons += [PSCustomObject]@{ Reason = "Windows Update"; Strong = $true }
    }

    $activeName = Get-WinForgeRegistryValueOrNull -Path "HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ActiveComputerName" -Name "ComputerName"
    $pendingName = Get-WinForgeRegistryValueOrNull -Path "HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName" -Name "ComputerName"

    if (-not [string]::IsNullOrWhiteSpace($activeName) -and -not [string]::IsNullOrWhiteSpace($pendingName) -and $activeName -ne $pendingName) {
        $reasons += [PSCustomObject]@{ Reason = "Renomeação do computador"; Strong = $true }
    }

    $fileRename = Get-WinForgeRegistryValueOrNull -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -Name "PendingFileRenameOperations"

    if ($null -ne $fileRename -and @($fileRename).Count -gt 0) {
        $reasons += [PSCustomObject]@{ Reason = "Arquivos aguardando substituição no próximo boot (pode ser falso positivo)"; Strong = $false }
    }

    return @($reasons)
}


function Test-WinForgePendingReboot {
    return (@(Get-WinForgePendingReboot | Where-Object { $_.Strong }).Count -gt 0)
}


function Get-WinForgePendingWindowsUpdates {
    <#
    Atualizações do Windows ainda não instaladas, pela API do Windows Update. Não conta as opcionais (drivers e
    prévias que o Windows só oferece na página de atualizações opcionais): essas não deixam o PC desprotegido.
    A consulta vai até o serviço, então roda em segundo plano com tempo limite, para que o botão Parar continue
    funcionando. Devolve Count e Titles, ou $null quando não foi possível consultar (inclusive por tempo esgotado).
    #>
    param (
        [int]$TimeoutSeconds = 90
    )

    $search = {
        $session = New-Object -ComObject "Microsoft.Update.Session"
        $searcher = $session.CreateUpdateSearcher()

        try {
            $found = $searcher.Search("IsInstalled=0 and IsHidden=0 and BrowseOnly=0")
        }
        catch {
            # Uma versão do Windows que não entenda BrowseOnly ainda responde à consulta simples.
            $found = $searcher.Search("IsInstalled=0 and IsHidden=0")
        }

        foreach ($update in $found.Updates) {
            [string]$update.Title
        }
    }

    try {
        $run = Invoke-WinForgeInBackground -ScriptBlock $search -TimeoutSeconds $TimeoutSeconds
    }
    catch {
        return $null
    }

    if (-not $run.Completed) {
        return $null
    }

    $titles = @($run.Output | ForEach-Object { [string]$_ })

    return [PSCustomObject]@{ Count = $titles.Count; Titles = @($titles) }
}


function Show-WinForgePendingReboot {
    Enter-WinForgeAction -Title "Reinício pendente"

    $reasons = @(Get-WinForgePendingReboot)

    if ($reasons.Count -eq 0) {
        Write-WinForgeStatus -Type Success -Message "Nenhum reinício pendente foi detectado."
    }
    else {
        foreach ($reason in $reasons) {
            $type = if ($reason.Strong) { "Warning" } else { "Info" }
            Write-WinForgeStatus -Type $type -Message $reason.Reason
        }

        Write-Host ""

        if (Test-WinForgePendingReboot) {
            Write-WinForgeStatus -Type Warning -Message "Reinicie o Windows antes de reparos, CHKDSK e instalações grandes."
        }
        else {
            Write-WinForgeStatus -Type Info -Message "Somente sinais fracos: o reinício provavelmente não é obrigatório."
        }
    }

    Exit-WinForgeAction
}


function Get-WinForgeDiskHealthNotes {
    param (
        [Parameter(Mandatory)]
        $Disk
    )

    $notes = @()

    if (-not [string]::IsNullOrWhiteSpace([string]$Disk.HealthStatus) -and [string]$Disk.HealthStatus -ne "Healthy") {
        $notes += "Estado do disco: $($Disk.HealthStatus)"
    }

    if ($null -ne $Disk.Wear -and [int]$Disk.Wear -ge 80) {
        $notes += "Desgaste do SSD em $($Disk.Wear)%"
    }

    if ($null -ne $Disk.Temperature -and [int]$Disk.Temperature -ge 70) {
        $notes += "Temperatura alta ($($Disk.Temperature) °C)"
    }

    if ($null -ne $Disk.ReadErrorsUncorrected -and [int64]$Disk.ReadErrorsUncorrected -gt 0) {
        $notes += "Erros de leitura não corrigidos: $($Disk.ReadErrorsUncorrected)"
    }

    if ($null -ne $Disk.WriteErrorsUncorrected -and [int64]$Disk.WriteErrorsUncorrected -gt 0) {
        $notes += "Erros de escrita não corrigidos: $($Disk.WriteErrorsUncorrected)"
    }

    return @($notes)
}


function Get-WinForgeDiskHealth {
    $result = @()

    try {
        $physicalDisks = @(Get-PhysicalDisk -ErrorAction Stop)
    }
    catch {
        return @()
    }

    foreach ($physicalDisk in $physicalDisks) {
        $counter = $null

        try {
            $counter = $physicalDisk | Get-StorageReliabilityCounter -ErrorAction Stop
        }
        catch {
            # Alguns discos (USB, virtuais) não expõem contadores de confiabilidade.
        }

        $disk = [PSCustomObject]@{
            Name                   = $physicalDisk.FriendlyName
            Type                   = (Get-WinForgeDiskTypeText -Disk $physicalDisk)
            SizeBytes              = $physicalDisk.Size
            HealthStatus           = $physicalDisk.HealthStatus
            Temperature            = $(if ($counter) { $counter.Temperature } else { $null })
            Wear                   = $(if ($counter) { $counter.Wear } else { $null })
            PowerOnHours           = $(if ($counter) { $counter.PowerOnHours } else { $null })
            ReadErrorsUncorrected  = $(if ($counter) { $counter.ReadErrorsUncorrected } else { $null })
            WriteErrorsUncorrected = $(if ($counter) { $counter.WriteErrorsUncorrected } else { $null })
        }

        $disk | Add-Member -NotePropertyName Notes -NotePropertyValue @(Get-WinForgeDiskHealthNotes -Disk $disk)
        $result += $disk
    }

    return @($result)
}


function Show-WinForgeDiskHealth {
    Enter-WinForgeAction -Title "Saúde dos discos"

    $disks = @(Get-WinForgeDiskHealth)

    if ($disks.Count -eq 0) {
        Write-WinForgeStatus -Type Warning -Message "Não foi possível ler a saúde dos discos (requer Windows 10/11 e, em alguns casos, Administrador)."
        Exit-WinForgeAction
        return
    }

    foreach ($disk in $disks) {
        Write-WinForgeSection -Title "$($disk.Name)  ($($disk.Type), $(Format-WinForgeBytes -Bytes $disk.SizeBytes -ZeroText "tamanho desconhecido"))"
        Write-WinForgeKeyValue -Label "Estado" -Value $disk.HealthStatus
        Write-WinForgeKeyValue -Label "Temperatura" -Value $(if ($null -ne $disk.Temperature) { "$($disk.Temperature) °C" } else { $null })
        Write-WinForgeKeyValue -Label "Desgaste (SSD)" -Value $(if ($null -ne $disk.Wear) { "$($disk.Wear)%" } else { $null })
        Write-WinForgeKeyValue -Label "Horas ligado" -Value $disk.PowerOnHours
        Write-WinForgeKeyValue -Label "Erros leitura/escrita" -Value $(if ($null -ne $disk.ReadErrorsUncorrected) { "$($disk.ReadErrorsUncorrected) / $($disk.WriteErrorsUncorrected)" } else { $null })

        Write-Host ""

        if ($disk.Notes.Count -eq 0) {
            Write-WinForgeStatus -Type Success -Message "Nenhum alerta para este disco."
        }
        else {
            foreach ($note in $disk.Notes) {
                Write-WinForgeStatus -Type Warning -Message $note
            }
        }
    }

    Write-Host ""
    Write-WinForgeStatus -Type Info -Message "Isto lê os contadores do Windows; não substitui um teste SMART completo do fabricante."
    Exit-WinForgeAction
}


# ---------------------------------------------------------------------------
# Saúde da bateria
# ---------------------------------------------------------------------------

function Get-WinForgeXmlChildNumber {
    # Número de um elemento filho, ignorando o namespace do XML (o relatório do powercfg usa um). Ausente ou texto = $null.
    param (
        [Parameter(Mandatory)]
        $Node,

        [Parameter(Mandatory)]
        [string]$Name
    )

    $child = $Node.SelectSingleNode("*[local-name()='$Name']")

    if ($null -eq $child) {
        return $null
    }

    $parsed = [int64]0

    if ([int64]::TryParse(([string]$child.InnerText).Trim(), [ref]$parsed)) {
        return $parsed
    }

    return $null
}


function Get-WinForgeXmlChildText {
    param (
        [Parameter(Mandatory)]
        $Node,

        [Parameter(Mandatory)]
        [string]$Name
    )

    $child = $Node.SelectSingleNode("*[local-name()='$Name']")

    if ($null -eq $child) {
        return ""
    }

    return ([string]$child.InnerText).Trim()
}


function New-WinForgeBatteryReading {
    # Capacidades em mWh, como o Windows informa. Saúde = capacidade atual / capacidade de projeto (no máximo 100%).
    param (
        [string]$Name = "",
        $DesignMwh = $null,
        $FullMwh = $null,
        $Cycles = $null
    )

    $health = $null

    if ($null -ne $DesignMwh -and $null -ne $FullMwh -and [double]$DesignMwh -gt 0 -and [double]$FullMwh -gt 0) {
        $health = [int][math]::Min(100, [math]::Round(([double]$FullMwh / [double]$DesignMwh) * 100))
    }

    return [PSCustomObject]@{
        Name          = $Name
        DesignMwh     = $DesignMwh
        FullMwh       = $FullMwh
        Cycles        = $Cycles
        HealthPercent = $health
    }
}


function ConvertFrom-WinForgeBatteryReport {
    <#
    Lê o XML de "powercfg /batteryreport /xml" e devolve uma leitura por bateria. Os nomes dos elementos são os do
    relatório (DesignCapacity, FullChargeCapacity, CycleCount) e a busca ignora o namespace. XML inválido lança erro;
    um XML sem baterias devolve lista vazia.
    #>
    param (
        [Parameter(Mandatory, ParameterSetName = "Text")]
        [string]$Text,

        # Com o caminho do arquivo, o próprio XmlDocument lê a codificação declarada (UTF-8 ou UTF-16).
        [Parameter(Mandatory, ParameterSetName = "Path")]
        [string]$Path
    )

    $document = New-Object System.Xml.XmlDocument

    if ($PSCmdlet.ParameterSetName -eq "Path") { $document.Load($Path) }
    else { $document.LoadXml($Text) }

    $readings = @()

    foreach ($node in @($document.SelectNodes("//*[local-name()='Batteries']/*[local-name()='Battery']"))) {
        $name = (Get-WinForgeXmlChildText -Node $node -Name "Manufacturer")
        $id = (Get-WinForgeXmlChildText -Node $node -Name "Id")

        if ($name -and $id -and $id -notlike "*$name*") { $name = "$name $id" }
        elseif (-not $name) { $name = $id }

        $readings += New-WinForgeBatteryReading `
            -Name $name `
            -DesignMwh (Get-WinForgeXmlChildNumber -Node $node -Name "DesignCapacity") `
            -FullMwh (Get-WinForgeXmlChildNumber -Node $node -Name "FullChargeCapacity") `
            -Cycles (Get-WinForgeXmlChildNumber -Node $node -Name "CycleCount")
    }

    return @($readings)
}


function Get-WinForgeBatteryWmiReadings {
    # Plano B quando o relatório do powercfg não está disponível: as classes de bateria do WMI (root\wmi).
    $static = @()
    $full = @()
    $cycles = @()

    try {
        $static = @(Get-CimInstance -Namespace "root\wmi" -ClassName "BatteryStaticData" -ErrorAction Stop)
        $full = @(Get-CimInstance -Namespace "root\wmi" -ClassName "BatteryFullChargedCapacity" -ErrorAction Stop)
        $cycles = @(Get-CimInstance -Namespace "root\wmi" -ClassName "BatteryCycleCount" -ErrorAction SilentlyContinue)
    }
    catch {
        return @()
    }

    $readings = @()

    foreach ($entry in $static) {
        $fullEntry = $full | Where-Object { $_.InstanceName -eq $entry.InstanceName } | Select-Object -First 1
        $cycleEntry = $cycles | Where-Object { $_.InstanceName -eq $entry.InstanceName } | Select-Object -First 1

        $readings += New-WinForgeBatteryReading `
            -Name ([string]$entry.DeviceName) `
            -DesignMwh $entry.DesignedCapacity `
            -FullMwh $(if ($fullEntry) { $fullEntry.FullChargedCapacity } else { $null }) `
            -Cycles $(if ($cycleEntry -and [int64]$cycleEntry.CycleCount -gt 0) { $cycleEntry.CycleCount } else { $null })
    }

    return @($readings)
}


function Get-WinForgeBatteryReadings {
    <#
    Capacidades das baterias do notebook. Primeiro tenta o relatório do powercfg (arquivo temporário, apagado ao final)
    e, se ele não trouxer baterias, o WMI. Devolve Readings e Source ("powercfg", "wmi" ou "").
    #>
    $readings = @()
    $source = ""

    $reportPath = Join-Path ([System.IO.Path]::GetTempPath()) ("winforge-bateria-" + [guid]::NewGuid().ToString("N") + ".xml")

    try {
        $run = Invoke-WinForgeCapture -FilePath "powercfg.exe" -Arguments @("/batteryreport", "/xml", "/output", $reportPath)

        if ($run.ExitCode -eq 0 -and (Test-Path -LiteralPath $reportPath)) {
            $readings = @(ConvertFrom-WinForgeBatteryReport -Path $reportPath)
            if ($readings.Count -gt 0) { $source = "powercfg" }
        }
    }
    catch {
        # powercfg ausente, sem permissão ou com XML ilegível: segue para o WMI.
        $readings = @()
    }
    finally {
        Remove-Item -LiteralPath $reportPath -Force -ErrorAction SilentlyContinue
    }

    if ($readings.Count -eq 0) {
        $readings = @(Get-WinForgeBatteryWmiReadings)
        if ($readings.Count -gt 0) { $source = "wmi" }
    }

    return [PSCustomObject]@{ Readings = @($readings); Source = $source }
}


function Get-WinForgeBatteryAssessment {
    # Regra prática sobre o desgaste: 80% ou mais está bom; de 60% a 79% a autonomia já caiu; abaixo de 60%, vale pensar
    # na troca. Level = Success | Info | Warning (o vocabulário de Write-WinForgeStatus).
    param (
        $HealthPercent
    )

    if ($null -eq $HealthPercent) {
        return [PSCustomObject]@{ Level = "Info"; Text = "O Windows não informou a capacidade de projeto; não dá para calcular o desgaste." }
    }

    if ([int]$HealthPercent -ge 80) {
        return [PSCustomObject]@{ Level = "Success"; Text = "Bateria em bom estado: segura $HealthPercent% da carga de quando era nova." }
    }

    if ([int]$HealthPercent -ge 60) {
        return [PSCustomObject]@{ Level = "Info"; Text = "Desgaste moderado: segura $HealthPercent% da carga original, então a autonomia já caiu." }
    }

    return [PSCustomObject]@{ Level = "Warning"; Text = "Desgaste alto: segura só $HealthPercent% da carga original. Vale considerar a troca da bateria." }
}


function Get-WinForgeBatteryState {
    # Carga e situação atuais, do Win32_Battery (código BatteryStatus: 1 descarregando, 2 na tomada, 3 cheia, 4 baixa,
    # 5 crítica, 6 a 9 carregando, 11 parcialmente carregada). Falha na consulta = $null.
    try {
        $battery = @(Get-CimInstance -ClassName "Win32_Battery" -ErrorAction Stop) | Select-Object -First 1
    }
    catch {
        return $null
    }

    if ($null -eq $battery) {
        return $null
    }

    $state = switch ([int]$battery.BatteryStatus) {
        { $_ -in 1, 4, 5 } { "Usando a bateria" }
        { $_ -in 6, 7, 8, 9 } { "Carregando" }
        { $_ -in 2, 3, 11 } { "Na tomada" }
        default { "" }
    }

    return [PSCustomObject]@{ ChargePercent = $battery.EstimatedChargeRemaining; State = $state }
}


function Get-WinForgeBatteryInfo {
    # Tudo o que a tela e o relatório mostram. Present = $false em desktops e máquinas sem bateria.
    $state = Get-WinForgeBatteryState

    if ($null -eq $state) {
        return [PSCustomObject]@{ Present = $false; State = $null; Readings = @(); Source = "" }
    }

    $found = Get-WinForgeBatteryReadings

    return [PSCustomObject]@{ Present = $true; State = $state; Readings = @($found.Readings); Source = $found.Source }
}


function Format-WinForgeWattHours {
    param ($Milliwatts)

    if ($null -eq $Milliwatts) {
        return $null
    }

    return "$([math]::Round([double]$Milliwatts / 1000)) Wh"
}


function Show-WinForgeBatteryHealth {
    Enter-WinForgeAction -Title "Saúde da bateria"

    try {
        $info = Get-WinForgeBatteryInfo

        if (-not $info.Present) {
            Write-WinForgeStatus -Type Info -Message "Este computador não tem bateria (ou o Windows não consegue enxergá-la)."
            Exit-WinForgeAction
            return
        }

        Write-WinForgeSection -Title "Agora"
        Write-WinForgeKeyValue -Label "Carga" -Value $(if ($null -ne $info.State.ChargePercent) { "$($info.State.ChargePercent)%" } else { $null })
        Write-WinForgeKeyValue -Label "Situação" -Value $info.State.State

        if (@($info.Readings).Count -eq 0) {
            Write-Host ""
            Write-WinForgeStatus -Type Warning -Message "O Windows não informou a capacidade da bateria. Alguns notebooks não expõem esses dados."
            Exit-WinForgeAction
            return
        }

        foreach ($reading in @($info.Readings)) {
            $title = "Capacidade"
            if (-not [string]::IsNullOrWhiteSpace($reading.Name)) { $title += ": $($reading.Name)" }

            Write-WinForgeSection -Title $title
            Write-WinForgeKeyValue -Label "De fábrica" -Value (Format-WinForgeWattHours -Milliwatts $reading.DesignMwh)
            Write-WinForgeKeyValue -Label "Hoje, carga completa" -Value (Format-WinForgeWattHours -Milliwatts $reading.FullMwh)
            Write-WinForgeKeyValue -Label "Saúde" -Value $(if ($null -ne $reading.HealthPercent) { "$($reading.HealthPercent)%" } else { $null })
            Write-WinForgeKeyValue -Label "Ciclos de carga" -Value $reading.Cycles

            $assessment = Get-WinForgeBatteryAssessment -HealthPercent $reading.HealthPercent

            Write-Host ""
            Write-WinForgeStatus -Type $assessment.Level -Message $assessment.Text
        }

        Write-Host ""
        Write-WinForgeStatus -Type Info -Message "A bateria perde capacidade com o uso e com o calor; isso é normal. O valor é uma estimativa do próprio Windows."
    }
    catch {
        Write-WinForgeStatus -Type Error -Message "Ocorreu um erro ao consultar a bateria: $($_.Exception.Message)"
    }

    Exit-WinForgeAction
}


function Get-WinForgeEventHint {
    param (
        [string]$Provider,
        [int]$Id
    )

    $key = "$Provider|$Id"

    switch -Wildcard ($key) {
        "Microsoft-Windows-Kernel-Power|41"          { return "Reinício inesperado: queda de energia, travamento ou superaquecimento." }
        "EventLog|6008"                               { return "Desligamento anterior inesperado." }
        "Microsoft-Windows-WHEA-Logger|*"             { return "Erro de hardware (CPU, memória ou PCIe). Pode indicar instabilidade ou overclock." }
        "disk|7"                                      { return "Bloco defeituoso no disco. Veja Diagnóstico > Saúde dos discos." }
        "disk|11"                                     { return "Erro de controlador/cabo de disco. Veja Diagnóstico > Saúde dos discos." }
        "disk|51"                                     { return "Erro de paginação em disco. Veja Diagnóstico > Saúde dos discos." }
        "disk|153"                                    { return "Operação de E/S repetida no disco. Veja Diagnóstico > Saúde dos discos." }
        "Ntfs|55"                                     { return "Corrupção no sistema de arquivos. Use Reparo > Verificar o sistema de arquivos (CHKDSK)." }
        "Ntfs|98"                                     { return "Volume NTFS com problema. Use Reparo > Verificar o sistema de arquivos (CHKDSK)." }
        "Microsoft-Windows-WER-SystemErrorReporting|1001" { return "Tela azul (BSOD) registrada." }
        "Display|4101"                                { return "O driver de vídeo parou de responder e foi recuperado." }
        "Service Control Manager|700?"                { return "Falha ao iniciar um serviço do Windows." }
        "Service Control Manager|7023"                { return "Um serviço terminou com erro." }
        "Service Control Manager|7031"                { return "Um serviço terminou inesperadamente." }
        "Service Control Manager|7034"                { return "Um serviço terminou inesperadamente." }
        default                                       { return "" }
    }
}


function ConvertTo-WinForgeEventSummary {
    param (
        [object[]]$Events,
        [int]$Top = 12
    )

    $groups = @($Events) | Where-Object { $null -ne $_ } | Group-Object -Property ProviderName, Id

    $summary = foreach ($group in $groups) {
        $first = $group.Group | Sort-Object TimeCreated -Descending | Select-Object -First 1

        [PSCustomObject]@{
            Count    = $group.Count
            Provider = [string]$first.ProviderName
            Id       = [int]$first.Id
            Last     = $first.TimeCreated
            Hint     = (Get-WinForgeEventHint -Provider ([string]$first.ProviderName) -Id ([int]$first.Id))
        }
    }

    return @($summary | Sort-Object @{ Expression = { if ($_.Hint) { 0 } else { 1 } } }, @{ Expression = "Count"; Descending = $true } | Select-Object -First $Top)
}


function Get-WinForgeRecentCriticalEvents {
    param (
        [int]$Days = 7,

        # Limite de leitura: um log muito barulhento não deve travar a tela. Quem mostra o total avisa se chegou nele.
        [int]$MaxEvents = 3000
    )

    try {
        $events = @(
            Get-WinEvent -FilterHashtable @{ LogName = "System"; Level = 1, 2; StartTime = (Get-Date).AddDays(-$Days) } `
                -MaxEvents $MaxEvents -ErrorAction Stop
        )
    }
    catch {
        # "No events were found" é o caso comum em sistemas saudáveis.
        $events = @()
    }

    return @($events)
}


function Show-WinForgeCriticalEvents {
    Enter-WinForgeAction -Title "Eventos críticos (7 dias)"

    Write-WinForgeStatus -Type Running -Message "Lendo o log do Sistema..."

    $maxEvents = 3000
    $shownGroups = 12

    $events = @(Get-WinForgeRecentCriticalEvents -Days 7 -MaxEvents $maxEvents)
    $groups = @(ConvertTo-WinForgeEventSummary -Events $events -Top ([int]::MaxValue))
    $summary = @($groups | Select-Object -First $shownGroups)

    Write-Host ""

    if ($summary.Count -eq 0) {
        Write-WinForgeStatus -Type Success -Message "Nenhum evento crítico ou de erro nos últimos 7 dias."
    }
    else {
        $total = "$($events.Count)"
        if ($events.Count -ge $maxEvents) { $total = "pelo menos $($events.Count) (limite de leitura)" }

        Write-WinForgeStatus -Type Info -Message "$total evento(s) de erro/crítico, agrupados por origem e ID:"
        Write-Host ""

        foreach ($item in $summary) {
            $color = if ($item.Hint) { "Yellow" } else { "Gray" }

            Write-Host ("  {0,4}x  " -f $item.Count) -ForegroundColor Cyan -NoNewline
            Write-Host ("{0} (ID {1})" -f $item.Provider, $item.Id) -ForegroundColor $color -NoNewline
            Write-Host ("  último: {0:dd/MM HH:mm}" -f $item.Last) -ForegroundColor DarkGray

            if ($item.Hint) {
                Write-Host "        $($item.Hint)" -ForegroundColor DarkYellow
            }
        }

        if ($groups.Count -gt $summary.Count) {
            Write-Host ""
            Write-Host "  ... e mais $($groups.Count - $summary.Count) grupo(s) menos relevantes. O Visualizador de Eventos mostra a lista completa." -ForegroundColor DarkGray
        }
    }

    Exit-WinForgeAction
}


Export-ModuleMember -Function *
