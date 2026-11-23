# Diagnóstico: o que o PC é e como ele está (sistema, discos, dispositivos, bateria, eventos, telas azuis, teste de memória,
# tempo ligado e reinício pendente) e a lista do que abre com o Windows (Gerenciar inicialização). Só lê o PC: reiniciar e o
# teste de memória ficam com as ferramentas do Windows, quando a pessoa pede.


function Get-WinForgeUptimeText {
    # Nullable: o CIM devolve $null quando não sabe a data do boot, e um parâmetro [datetime] comum transformaria isso
    # em "0001-01-01" (ou recusaria o valor), o que gerava um tempo ligado absurdo ou derrubava o relatório.
    param (
        [Nullable[datetime]]$LastBootTime
    )

    if ($null -eq $LastBootTime -or $LastBootTime.Year -lt 2000) {
        return (Get-WinForgeText 'Desconhecido')
    }

    # Em UTC: a conta com a hora local erra uma hora quando o horário de verão começa ou termina no meio.
    $uptime = (Get-Date).ToUniversalTime() - ([datetime]$LastBootTime).ToUniversalTime()

    # Um boot "no futuro" (relógio atrasado depois de ligar) não tem tempo ligado que se possa dizer.
    if ($uptime.TotalMinutes -lt -5) {
        return (Get-WinForgeText 'Desconhecido')
    }

    if ($uptime.TotalMinutes -lt 1) {
        return (Get-WinForgeText 'menos de 1 minuto')
    }

    $parts = @()

    if ($uptime.Days -gt 0) {
        if ($uptime.Days -eq 1) { $parts += (Get-WinForgeText '1 dia') } else { $parts += (Get-WinForgeText '{0} dias' "$($uptime.Days)") }
    }

    if ($uptime.Hours -gt 0) {
        if ($uptime.Hours -eq 1) { $parts += (Get-WinForgeText '1 hora') } else { $parts += (Get-WinForgeText '{0} horas' "$($uptime.Hours)") }
    }

    if ($uptime.Minutes -gt 0 -or $parts.Count -eq 0) {
        if ($uptime.Minutes -eq 1) { $parts += (Get-WinForgeText '1 minuto') } else { $parts += (Get-WinForgeText '{0} minutos' "$($uptime.Minutes)") }
    }

    # "2 dias, 3 horas e 5 minutos".
    return (Join-WinForgeList -Items $parts)
}


function Test-WinForgeLongUptime {
    <#
    Se o PC está ligado há uma semana ou mais desde o último início: o Desempenho mostra a linha em amarelo, e Tempo ligado e
    energia oferece reiniciar. Em UTC, como Get-WinForgeUptimeText (a hora local erra uma hora na troca do horário de
    verão). Sem a hora do início, ou com um início "no futuro", $false.
    #>
    param ([Nullable[datetime]]$LastBootTime)

    if ($null -eq $LastBootTime -or $LastBootTime.Year -lt 2000) {
        return $false
    }

    return (((Get-Date).ToUniversalTime() - ([datetime]$LastBootTime).ToUniversalTime()).TotalDays -ge 7)
}


function Get-WinForgeDiskTypeText {
    param (
        [object]$Disk
    )

    if ($null -eq $Disk) {
        return (Get-WinForgeText 'Não disponível')
    }

    $busType = ""
    $mediaType = ""

    if ($Disk.PSObject.Properties.Name -contains "BusType" -and $null -ne $Disk.BusType) {
        $busType = $Disk.BusType.ToString()
    }

    if ($Disk.PSObject.Properties.Name -contains "MediaType" -and $null -ne $Disk.MediaType) {
        $mediaType = $Disk.MediaType.ToString()
    }

    # Lido do WMI sem o módulo de armazenamento carregado, o tipo vem como o código de MSFT_PhysicalDisk, e não como o
    # nome.
    $mediaNames = @{ "0" = "Unspecified"; "3" = "HDD"; "4" = "SSD"; "5" = "SCM" }
    $busNames = @{
        "0" = "Unknown"; "1" = "SCSI"; "2" = "ATAPI"; "3" = "ATA"; "4" = "1394"; "5" = "SSA"; "6" = "Fibre Channel"; "7" = "USB"
        "8" = "RAID"; "9" = "iSCSI"; "10" = "SAS"; "11" = "SATA"; "12" = "SD"; "13" = "MMC"; "15" = "File Backed Virtual"
        "16" = "Storage Spaces"; "17" = "NVMe"
    }

    if ($mediaNames.ContainsKey($mediaType)) { $mediaType = $mediaNames[$mediaType] }
    if ($busNames.ContainsKey($busType)) { $busType = $busNames[$busType] }

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

    return (Get-WinForgeText 'Não disponível')
}


function Get-WinForgePartitionLetters {
    <#
    As unidades com letra e o disco de cada uma, de uma leitura só das partições (Get-Partition, com prazo): Drive ("C:") e
    Disk (o número do disco, como texto). As partições sem letra (a de recuperação, a do boot) ficam de fora; a letra vem
    como um caractere, e "sem letra" é o caractere zero. Um erro do Windows, inclusive o tempo esgotado
    (TimeoutException), sobe para quem chama. Usada por Discos e espaço livre, Saúde dos discos e a lista do CHKDSK.
    #>
    foreach ($partition in @(Invoke-WinForgeCimCommand -Name "Get-Partition")) {
        if ($null -eq $partition) { continue }

        $letter = ([string](Get-WinForgeJsonValue -Object $partition -Name "DriveLetter" -Default "")).Trim([char]0).Trim()
        $disk = [string](Get-WinForgeJsonValue -Object $partition -Name "DiskNumber" -Default "")

        if ($letter -match '^[A-Za-z]$' -and $disk -match '^[0-9]+$') {
            [PSCustomObject]@{ Drive = "$($letter.ToUpperInvariant()):"; Disk = $disk }
        }
    }
}


function Get-WinForgeDiskSummary {
    # Só a consulta fica no try: uma falha na conta de uma unidade não pode virar "não foi possível detectar" para todas.
    try {
        $logicalDisks = @(
            Get-CimInstance Win32_LogicalDisk -Filter "DriveType = 3" -OperationTimeoutSec 15 -ErrorAction Stop |
            Sort-Object DeviceID
        )
    }
    catch {
        return @()
    }

    # Tipo e modelo vêm do disco físico (MSFT_PhysicalDisk tem MediaType: SSD ou HDD; o Get-Disk não tem). Cada consulta
    # é feita uma vez só: as partições dizem a letra e o número do disco, e o número é o DeviceId do disco físico.
    $diskNumberByLetter = @{}
    $physicalByNumber = @{}

    try {
        foreach ($partition in @(Get-WinForgePartitionLetters)) {
            $diskNumberByLetter[$partition.Drive.TrimEnd(":")] = $partition.Disk
        }
    }
    catch {
        # Sem partições lidas: tipo e modelo ficam indisponíveis.
    }

    if ($diskNumberByLetter.Count -gt 0) {
        try {
            # MSFT_PhysicalDisk, o que o Get-PhysicalDisk devolve, mas com prazo (veja Get-WinForgeDiskHealth).
            foreach ($physicalDisk in @(Get-CimInstance -Namespace "root/Microsoft/Windows/Storage" -ClassName "MSFT_PhysicalDisk" -OperationTimeoutSec 60 -ErrorAction Stop)) {
                $physicalByNumber[[string]$physicalDisk.DeviceId] = $physicalDisk
            }
        }
        catch {
            # Idem: nunca empresta o disco físico de outra unidade.
        }
    }

    # A unidade do Windows segue a regra em gigabytes; as outras, a da porcentagem. Quem mostra a lista (a dica da Limpeza)
    # usa a mesma marca, em vez de comparar a letra de novo.
    $systemDrive = $(if ([string]::IsNullOrWhiteSpace($env:SystemDrive)) { "C:" } else { ([string]$env:SystemDrive).TrimEnd("\") })
    $diskSummary = @()

    foreach ($logicalDisk in $logicalDisks) {
        $driveId = [string]$logicalDisk.DeviceID

        # Uma entrada sem letra não teria como ser mostrada; ela não pode derrubar a lista das outras.
        if ([string]::IsNullOrWhiteSpace($driveId)) {
            continue
        }

        $driveLetter = $driveId.TrimEnd(":").ToUpperInvariant()
        $isSystem = ($driveId -eq $systemDrive)
        $disk = $null
        $diskModel = (Get-WinForgeText 'Não disponível')
        $diskType = (Get-WinForgeText 'Não disponível')

        # Só o disco desta unidade: associar o primeiro disco físico a todas daria dados errados com vários discos.
        if ($diskNumberByLetter.ContainsKey($driveLetter) -and $physicalByNumber.ContainsKey($diskNumberByLetter[$driveLetter])) {
            $disk = $physicalByNumber[$diskNumberByLetter[$driveLetter]]
        }

        if ($null -ne $disk) {
            if (-not [string]::IsNullOrWhiteSpace([string]$disk.FriendlyName)) {
                $diskModel = ([string]$disk.FriendlyName).Trim()
            }

            $diskType = Get-WinForgeDiskTypeText -Disk $disk
        }

        $totalBytes = $logicalDisk.Size
        $freeBytes = $logicalDisk.FreeSpace
        $known = ($null -ne $totalBytes -and [double]$totalBytes -gt 0 -and $null -ne $freeBytes)
        $usedBytes = $null
        $usedPercent = $null
        $level = "Unknown"

        # Sem o espaço livre, "0 B livres" e "100% usado" seriam inventados: o uso fica desconhecido.
        $freePercent = $null

        if ($known) {
            $usedBytes = [Math]::Max([double]0, [double]$totalBytes - [double]$freeBytes)

            # O livre arredonda para baixo: "pouco espaço (menos de 10% livre)" não pode dizer "10% livre"; e com espaço
            # livre de verdade, o uso não chega a "100%".
            $freePercent = [int][Math]::Min(100, [Math]::Floor(([Math]::Max([double]0, [double]$freeBytes) / [double]$totalBytes) * 100))
            $usedPercent = 100 - $freePercent
            if ($usedPercent -ge 100 -and [double]$freeBytes -gt 0) { $usedPercent = 99 }

            # Nível ("Ok", "Low", "Critical" ou "Unknown") segue a mesma regra da tela inicial e da Manutenção; numa
            # unidade que não é a do sistema, só a porcentagem conta.
            $level = Get-WinForgeDiskSpaceLevel -FreeBytes $freeBytes -TotalBytes $totalBytes -System $isSystem
        }

        $diskSummary += [PSCustomObject]@{
            Unidade    = $driveId
            Tipo       = $diskType
            Modelo     = $diskModel
            Total      = Format-WinForgeBytes -Bytes $totalBytes -ZeroText (Get-WinForgeText 'Não disponível')
            Livre      = $(if ($known) { Format-WinForgeBytes -Bytes $freeBytes -ZeroText "0 B" } else { (Get-WinForgeText 'Não disponível') })
            Usado      = $(if ($known) { Format-WinForgeBytes -Bytes $usedBytes -ZeroText "0 B" } else { (Get-WinForgeText 'Não disponível') })
            Uso        = $(if ($null -ne $usedPercent) { "$usedPercent%" } else { (Get-WinForgeText 'Não disponível') })
            UsoPercent = $usedPercent
            LivrePercent = $freePercent
            Nivel      = $level
            Sistema    = $isSystem
        }
    }

    return @($diskSummary)
}


function Get-WinForgeDiskSummaryText {
    # Uma unidade numa linha, igual na tela e no relatório: "477 GB livres de 931 GB (49% usado) · NVMe · Samsung SSD 980".
    # Tipo e modelo que o Windows não informou ficam de fora.
    param (
        [Parameter(Mandatory)]
        $Disk
    )

    $text = $(if ($null -ne $Disk.UsoPercent) { (Get-WinForgeText '{0} livres de {1} ({2}% usado)' "$($Disk.Livre)" "$($Disk.Total)" "$($Disk.UsoPercent)") } else { (Get-WinForgeText 'espaço livre desconhecido') })

    foreach ($part in @($Disk.Tipo, $Disk.Modelo)) {
        if (-not [string]::IsNullOrWhiteSpace([string]$part) -and [string]$part -ne (Get-WinForgeText 'Não disponível')) {
            $text += " · $part"
        }
    }

    return $text
}


function Get-WinForgeLowDiskText {
    # A frase de uma unidade com pouco espaço, a mesma na tela e na faixa: "A unidade C: está quase cheia: só 6 GB livres de
    # 476 GB." ou "A unidade D: está com pouco espaço: 40 GB livres de 931 GB (4% livre)."
    param ([Parameter(Mandatory)]$Disk)

    if ($Disk.Nivel -eq "Critical") {
        return (Get-WinForgeText 'A unidade {0} está quase cheia: só {1} livres de {2}.' "$($Disk.Unidade)" "$($Disk.Livre)" "$($Disk.Total)")
    }

    $freePercent = Get-WinForgeJsonValue -Object $Disk -Name "LivrePercent" -Default (100 - [int]$Disk.UsoPercent)

    return (Get-WinForgeText 'A unidade {0} está com pouco espaço: {1} livres de {2} ({3} livre).' "$($Disk.Unidade)" "$($Disk.Livre)" "$($Disk.Total)" "$(if ([int]$freePercent -lt 1) { (Get-WinForgeText 'menos de 1%') } else { "$freePercent%" })")
}


function Show-WinForgeDiskSummary {
    # Cada unidade é uma linha "rótulo : valor", que a janela mostra também no resumo (uma tabela ficaria só nos detalhes).
    # -PassThru devolve as unidades com pouco espaço (como Get-WinForgeDiskSummary), para a faixa de resultado de quem chama.
    param (
        [switch]$PassThru
    )

    $disks = @(Get-WinForgeDiskSummary)

    if ($disks.Count -eq 0) {
        Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'Não foi possível detectar informações de disco.')
        return
    }

    foreach ($disk in $disks) {
        Write-WinForgeKeyValue -Label $disk.Unidade -Value (Get-WinForgeDiskSummaryText -Disk $disk)
    }

    $lowDisks = @($disks | Where-Object { $_.Nivel -in @("Low", "Critical") })

    if ($PassThru) {
        foreach ($disk in $lowDisks) { $disk }
    }

    if ($lowDisks.Count -eq 0) {
        return
    }

    Write-Host ""

    # As mesmas palavras da tela inicial. No disco do Windows, "quase cheia" abaixo de 10 GB livres e "pouco espaço" abaixo
    # de 20 GB; nas outras unidades, abaixo de 5% e de 10% livres.
    foreach ($disk in $lowDisks) {
        Write-WinForgeStatus -Type Warning -Message (Get-WinForgeLowDiskText -Disk $disk)
    }

    # A Limpeza trabalha no disco do Windows (temporários, caches); numa unidade de dados ela libera pouco (a Lixeira, a
    # pasta Downloads se ela estiver lá). A marca vem da lista (Sistema), com a mesma regra que decidiu o nível. O conselho é
    # o mesmo do Início, da Verificação do PC e da faixa da Limpeza: a Limpeza personalizada, que mede tudo o que dá para
    # tirar.
    $systemLow = @($lowDisks | Where-Object { [bool](Get-WinForgeJsonValue -Object $_ -Name "Sistema" -Default $false) })
    $otherLow = @($lowDisks | Where-Object { -not [bool](Get-WinForgeJsonValue -Object $_ -Name "Sistema" -Default $false) })

    if ($systemLow.Count -gt 0) {
        Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Para liberar espaço no disco do Windows, use Limpeza > Limpeza personalizada.')
    }

    if ($otherLow.Count -gt 0) {
        Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Em {0}, a Limpeza do WinForge libera pouco (ela cuida do disco do Windows): mova ou apague arquivos grandes que você não usa.' "$(Join-WinForgeList -Items @($otherLow | ForEach-Object { $_.Unidade }))")
    }
}


function Get-WinForgeCimOrNull {
    # Consulta CIM tolerante: uma classe indisponível (máquina virtual, WMI com defeito) não derruba a tela inteira.
    param (
        [Parameter(Mandatory)]
        [string]$ClassName
    )

    try {
        return @(Get-CimInstance -ClassName $ClassName -OperationTimeoutSec 15 -ErrorAction Stop)
    }
    catch {
        return @()
    }
}


function Get-WinForgeSecureBootState {
    <#
    O estado do Secure Boot: "On", "Off", "Legacy" (o Windows iniciou no modo BIOS legado), "NoAdmin" (a consulta pediu
    Administrador) ou "Unknown". A tela (Get-WinForgeSecureBootText) e a auditoria de segurança partem daqui.
    O Registro (SecureBoot\State) é legível sem Administrador; Confirm-SecureBootUEFI fica de reserva e, sem
    Administrador, recusa a consulta (acesso negado), o que antes aparecia como "não suportado" num PC com o Secure Boot
    ligado. Num PC com BIOS legado (sem UEFI) o cmdlet responde que a plataforma não tem suporte.
    #>
    # O tipo de firmware vem antes: com o Windows iniciado no modo BIOS legado, o valor do Secure Boot pode existir (em 0)
    # e "desligado" sugeriria uma opção que não está ao alcance. PEFirmwareType: 1 = BIOS legado, 2 = UEFI. É o modo em
    # que o Windows iniciou, e não o que a placa suporta: muitos PCs têm UEFI desligado (CSM).
    $firmware = Get-WinForgeRegistryValueOrNull -Path "HKLM:\SYSTEM\CurrentControlSet\Control" -Name "PEFirmwareType"

    if ($null -ne $firmware -and [string]$firmware -eq "1") {
        return "Legacy"
    }

    $state = Get-WinForgeRegistryValueOrNull -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\State" -Name "UEFISecureBootEnabled"

    if ($null -ne $state -and [string]$state -in @("0", "1")) {
        return $(if ([int]$state -eq 1) { "On" } else { "Off" })
    }

    try {
        return $(if (Confirm-SecureBootUEFI -ErrorAction Stop) { "On" } else { "Off" })
    }
    catch {
        if ($_.Exception -is [System.PlatformNotSupportedException]) { return "Legacy" }
        if ($_.Exception -is [System.UnauthorizedAccessException]) { return "NoAdmin" }

        return "Unknown"
    }
}


function Get-WinForgeSecureBootText {
    # O estado do Secure Boot como a tela Sobre este PC o mostra (Get-WinForgeSecureBootState).
    switch (Get-WinForgeSecureBootState) {
        "On" { return (Get-WinForgeText 'Ativado') }
        "Off" { return (Get-WinForgeText 'Desativado') }
        "Legacy" { return (Get-WinForgeText 'Indisponível (o Windows iniciou no modo BIOS legado)') }
        "NoAdmin" { return (Get-WinForgeText 'Não verificado (requer Administrador)') }
        default { return (Get-WinForgeText 'Desconhecido') }
    }
}


function Get-WinForgeWindowsActivation {
    <#
    A ativação do Windows, lida no licenciamento do próprio Windows (SoftwareLicensingProduct): o produto do Windows
    (ApplicationID 55c92734-d682-4d71-983e-d6ec3f16059f) com uma chave instalada (PartialProductKey). "Licensed"
    (ativado), "Grace" (ainda não ativado, dentro do prazo do Windows para ativar: LicenseStatus 2, 3, 4 ou 6),
    "Unlicensed" (não ativado: 0 ou 5) ou "Unknown" (sem resposta, ou nenhum produto com chave). Com mais de um produto
    com chave, vale o ativado. A consulta leva alguns segundos: fica em Sobre este PC e no relatório, fora do Início.
    #>
    try {
        $products = @(Get-CimInstance -ClassName "SoftwareLicensingProduct" -Filter "ApplicationID='55c92734-d682-4d71-983e-d6ec3f16059f' AND PartialProductKey IS NOT NULL" -OperationTimeoutSec 30 -ErrorAction Stop)
    }
    catch {
        return "Unknown"
    }

    $statuses = @($products | Where-Object { $null -ne $_ } | ForEach-Object { [string](Get-WinForgeJsonValue -Object $_ -Name "LicenseStatus" -Default "") })

    if ($statuses -contains "1") { return "Licensed" }
    if (@($statuses | Where-Object { $_ -in @("2", "3", "4", "6") }).Count -gt 0) { return "Grace" }
    if (@($statuses | Where-Object { $_ -in @("0", "5") }).Count -gt 0) { return "Unlicensed" }

    return "Unknown"
}


function Get-WinForgeWindowsActivationText {
    # A ativação como Sobre este PC e o relatório a mostram (Get-WinForgeWindowsActivation).
    param ([string]$State)

    switch ($State) {
        "Licensed" { return (Get-WinForgeText 'Ativado') }
        "Grace" { return (Get-WinForgeText 'Não ativado (ainda no prazo para ativar)') }
        "Unlicensed" { return (Get-WinForgeText 'Não ativado') }
        default { return (Get-WinForgeText 'Não foi possível conferir') }
    }
}


function Get-WinForgeMemoryModulesText {
    # "2 × 16 GB" quando os módulos são iguais; "8 GB + 16 GB" quando não são. Sem capacidade informada = $null.
    param (
        [object[]]$Modules = @()
    )

    $sizes = @(
        foreach ($module in @($Modules)) {
            $capacity = [double](Get-WinForgeJsonValue -Object $module -Name "Capacity" -Default 0)
            if ($capacity -gt 0) { Format-WinForgeBytes -Bytes $capacity }
        }
    )

    if ($sizes.Count -eq 0) {
        return $null
    }

    if (@($sizes | Select-Object -Unique).Count -eq 1) {
        return "$($sizes.Count) × $($sizes[0])"
    }

    return ($sizes -join " + ")
}


function Get-WinForgeMachineModelText {
    <#
    Fabricante e modelo do PC ("Dell Inc. Inspiron 15 3520"), o que um técnico pergunta primeiro (drivers, BIOS,
    garantia), a partir do Win32_ComputerSystem. Os textos de fábrica vazios ("System Product Name", "To Be Filled By
    O.E.M.", o "All Series" das placas ASUS) não dizem nada: sem um modelo de verdade, "" (num PC montado, a placa-mãe
    identifica). A Lenovo põe no Model o tipo da máquina ("20XWCTO1WW") e o nome no SystemFamily ("ThinkPad X1 Carbon
    Gen 9"): os dois aparecem. O fabricante não se repete quando o modelo já começa por ele ("HP Laptop 15").
    #>
    param ($System)

    if ($null -eq $System) { return "" }

    $placeholder = '^(To Be Filled By O\.E\.M\.|System manufacturer|System Product Name|System Version|Default string|O\.E\.M\.|OEM|Not Applicable|Not Specified|None|Unknown|Undefined|All Series|Type1ProductConfigId|Base Board Product Name|x\.x)$'
    $clean = { param ($value) $text = ([string]$value -replace '\s+', ' ').Trim(); $(if ($text -and $text -notmatch $placeholder) { $text } else { "" }) }

    $maker = & $clean (Get-WinForgeJsonValue -Object $System -Name "Manufacturer" -Default "")
    $model = & $clean (Get-WinForgeJsonValue -Object $System -Name "Model" -Default "")
    $family = & $clean (Get-WinForgeJsonValue -Object $System -Name "SystemFamily" -Default "")

    if ($maker -match '^lenovo$') {
        $maker = "Lenovo"
        if ($family -and $family -notmatch '^lenovo$') { $model = $(if ($model -and $model -ne $family) { "$family ($model)" } else { $family }) }
    }

    if (-not $model) { return "" }
    if (-not $maker -or $model.StartsWith($maker, [System.StringComparison]::OrdinalIgnoreCase)) { return $model }

    return "$maker $model"
}


function Show-WinForgeSystemInfo {
    Enter-WinForgeAction -Title (Get-WinForgeText 'Sobre este PC')

    try {
        # O Win32_OperatingSystem e o Win32_Processor existem em todo Windows: sem resposta dos dois, o WMI não está
        # respondendo, e as outras leituras (cada uma com o seu prazo, mais a ativação e os discos) só atrasariam o aviso em
        # minutos. A tela fica com o que não depende dele.
        $os = Get-WinForgeCimOrNull -ClassName "Win32_OperatingSystem" | Select-Object -First 1
        $processors = @(Get-WinForgeCimOrNull -ClassName "Win32_Processor")
        $wmiDown = ($null -eq $os -and $processors.Count -eq 0)
        $cpu = $processors | Select-Object -First 1
        $baseBoard = $null
        $bios = $null
        $memoryModules = @()
        $gpuList = @()
        $computerSystem = $null

        if (-not $wmiDown) {
            $baseBoard = Get-WinForgeCimOrNull -ClassName "Win32_BaseBoard" | Select-Object -First 1
            $bios = Get-WinForgeCimOrNull -ClassName "Win32_BIOS" | Select-Object -First 1
            $memoryModules = @(Get-WinForgeCimOrNull -ClassName "Win32_PhysicalMemory")
            $gpuList = @(Get-WinForgeCimOrNull -ClassName "Win32_VideoController")
            $computerSystem = Get-WinForgeCimOrNull -ClassName "Win32_ComputerSystem" | Select-Object -First 1
        }

        # RAM: a soma dos módulos; em máquinas virtuais a lista de módulos vem vazia e vale o total do sistema.
        $totalRamBytes = $null

        if ($memoryModules.Count -gt 0) {
            $totalRamBytes = ($memoryModules | Measure-Object -Property Capacity -Sum).Sum
        }

        if ($null -eq $totalRamBytes -or $totalRamBytes -le 0) {
            $totalRamBytes = $(if ($computerSystem) { Get-WinForgeJsonValue -Object $computerSystem -Name "TotalPhysicalMemory" -Default $null } else { $null })
        }

        $memoryType = (Get-WinForgeText 'Não disponível')

        if ($memoryModules.Count -gt 0) {
            $memoryType = Convert-WinForgeMemoryType -Type ([int]$memoryModules[0].SMBIOSMemoryType)
        }

        # ForEach-Object em vez de Select-Object -ExpandProperty: se a propriedade não existir nesta versão do Windows,
        # a tela continua em vez de falhar inteira.
        $configuredSpeeds = @(
            $memoryModules |
            ForEach-Object { $_.ConfiguredClockSpeed } |
            Where-Object { $null -ne $_ -and $_ -gt 0 } |
            Select-Object -Unique
        )

        # MT/s, a unidade que o Gerenciador de Tarefas do Windows 11 passou a usar: é a taxa do nome do módulo (DDR4-3200),
        # não o clock em MHz (a metade dela).
        $ramClockText = $(if ($configuredSpeeds.Count -gt 0) { ($configuredSpeeds -join " / ") + " MT/s" } else { (Get-WinForgeText 'Desconhecido') })
        $xmpText = Get-WinForgeExpoXmpStatus -MemoryModules $memoryModules

        # Núcleos e processadores lógicos de todos os processadores (placas com dois soquetes). MaxClockSpeed é a
        # frequência base: o WMI não informa o turbo, e o "clock atual" dele costuma repetir a base, por isso não aparece.
        $coreCount = [int](($processors | ForEach-Object { [int](Get-WinForgeJsonValue -Object $_ -Name "NumberOfCores" -Default 0) } | Measure-Object -Sum).Sum)
        $threadCount = [int](($processors | ForEach-Object { [int](Get-WinForgeJsonValue -Object $_ -Name "NumberOfLogicalProcessors" -Default 0) } | Measure-Object -Sum).Sum)
        $coresText = $null

        if ($coreCount -gt 0) {
            $coresText = Format-WinForgeCount -Count $coreCount -One (Get-WinForgeText 'núcleo') -Many (Get-WinForgeText 'núcleos')
            if ($threadCount -gt 0) { $coresText += ", " + (Format-WinForgeCount -Count $threadCount -One (Get-WinForgeText 'processador lógico') -Many (Get-WinForgeText 'processadores lógicos')) }
        }

        $baseClock = $(if ($cpu) { [double](Get-WinForgeJsonValue -Object $cpu -Name "MaxClockSpeed" -Default 0) } else { 0 })
        $baseClockText = $(if ($baseClock -gt 0) { "$(Format-WinForgeNumber -Value ($baseClock / 1000) -Decimals 2) GHz" } else { $null })

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
        $pcUptimeText = (Get-WinForgeText 'Desconhecido')
        $lastBootText = (Get-WinForgeText 'Desconhecido')

        if ($null -ne $lastBootTime) {
            $pcUptimeText = Get-WinForgeUptimeText -LastBootTime $lastBootTime
            $lastBootText = Format-WinForgeDateTime -When $lastBootTime
        }

        # Sem nenhuma resposta do WMI, todos os campos viriam "Não disponível" e a tela pareceria só incompleta.
        if ($wmiDown) {
            Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'O Windows não respondeu às consultas de hardware (WMI): os dados abaixo estão incompletos. Reiniciar o serviço Instrumentação de Gerenciamento do Windows pode resolver.')
        }

        # O mesmo nome e a mesma versão da tela inicial ("Windows 11 Pro", 24H2), e não a legenda do WMI com "Microsoft"
        # nem a versão do núcleo (10.0.26100), que não diz nada a quem usa.
        $build = $(if ($os) { [int](Get-WinForgeJsonValue -Object $os -Name "BuildNumber" -Default 0) } else { 0 })
        $windowsName = $(if ($os) { Get-WinForgeWindowsName -Caption ([string](Get-WinForgeJsonValue -Object $os -Name "Caption" -Default "")) -Build $build } else { "" })
        $computer = $(if ([string]::IsNullOrWhiteSpace($env:COMPUTERNAME)) { [Environment]::MachineName } else { $env:COMPUTERNAME })
        $user = $(if ([string]::IsNullOrWhiteSpace($env:USERNAME)) { [Environment]::UserName } else { $env:USERNAME })

        Write-WinForgeSection -Title (Get-WinForgeText 'Sistema')
        Write-WinForgeKeyValue -Label (Get-WinForgeText 'Computador') -Value $computer
        Write-WinForgeKeyValue -Label (Get-WinForgeText 'Usuário') -Value $user

        # Num PC montado, os textos de fábrica ficam vazios e a seção Placa-mãe identifica o PC: a linha não aparece.
        $machine = Get-WinForgeMachineModelText -System $computerSystem
        if ($machine) { Write-WinForgeKeyValue -Label (Get-WinForgeText 'Fabricante e modelo') -Value $machine }

        Write-WinForgeKeyValue -Label (Get-WinForgeText 'Windows') -Value $windowsName
        Write-WinForgeKeyValue -Label (Get-WinForgeText 'Versão') -Value (Get-WinForgeWindowsDisplayVersion)
        Write-WinForgeKeyValue -Label (Get-WinForgeText 'Build') -Value $(if ($build -gt 0) { $build } else { $null })

        # Com o Windows não ativado, a linha seguinte diz onde ativar.
        $activation = $(if ($wmiDown) { "Unknown" } else { Get-WinForgeWindowsActivation })
        Write-WinForgeKeyValue -Label (Get-WinForgeText 'Ativação') -Value (Get-WinForgeWindowsActivationText -State $activation) -Level $(if ($activation -in @("Grace", "Unlicensed")) { "Warn" } else { "Normal" })
        if ($activation -in @("Grace", "Unlicensed")) { Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Para ativar, abra Configurações e procure por Ativação.') }

        Write-WinForgeKeyValue -Label (Get-WinForgeText 'Tempo ligado') -Value $pcUptimeText
        Write-WinForgeKeyValue -Label (Get-WinForgeText 'Última inicialização') -Value $lastBootText

        # Um tempo ligado de dias num PC que a pessoa desliga toda noite parece erro: é a Inicialização Rápida. A frase é a
        # mesma de Tempo ligado e energia.
        if ($null -ne $lastBootTime -and ((Get-Date).ToUniversalTime() - ([datetime]$lastBootTime).ToUniversalTime()).TotalDays -ge 1 -and (Get-WinForgeFastStartupText) -eq (Get-WinForgeText 'Ativada')) {
            Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Com a Inicialização Rápida ligada, desligar o PC não zera o tempo ligado: só Reiniciar faz o Windows começar do zero.')
        }

        $rebootPending = Test-WinForgePendingReboot
        Write-WinForgeKeyValue -Label (Get-WinForgeText 'Reinício pendente') -Value $(if ($rebootPending) { (Get-WinForgeText 'Sim') } else { (Get-WinForgeText 'Não') }) -Level $(if ($rebootPending) { "Warn" } else { "Normal" })

        # Sem o WMI, só o que vem do Registro: as seções de hardware seriam uma lista de "Não disponível".
        if ($wmiDown) {
            Write-WinForgeSection -Title (Get-WinForgeText 'BIOS e segurança')
            Write-WinForgeKeyValue -Label (Get-WinForgeText 'Secure Boot') -Value (Get-WinForgeSecureBootText)
            Exit-WinForgeAction
            return
        }

        Write-WinForgeSection -Title (Get-WinForgeText 'Placa-mãe')
        Write-WinForgeKeyValue -Label (Get-WinForgeText 'Fabricante') -Value $(if ($baseBoard) { $baseBoard.Manufacturer } else { $null })
        Write-WinForgeKeyValue -Label (Get-WinForgeText 'Modelo') -Value $(if ($baseBoard) { $baseBoard.Product } else { $null })

        Write-WinForgeSection -Title (Get-WinForgeText 'BIOS e segurança')
        Write-WinForgeKeyValue -Label (Get-WinForgeText 'Versão da BIOS') -Value $(if ($bios) { $bios.SMBIOSBIOSVersion } else { $null })
        Write-WinForgeKeyValue -Label (Get-WinForgeText 'Secure Boot') -Value (Get-WinForgeSecureBootText)

        Write-WinForgeSection -Title (Get-WinForgeText 'Processador')
        Write-WinForgeKeyValue -Label "CPU" -Value $(if ($cpu) { ([string]$cpu.Name).Trim() } else { $null })
        Write-WinForgeKeyValue -Label (Get-WinForgeText 'Núcleos') -Value $coresText
        Write-WinForgeKeyValue -Label (Get-WinForgeText 'Frequência base') -Value $baseClockText

        Write-WinForgeSection -Title (Get-WinForgeText 'Memória')
        Write-WinForgeKeyValue -Label (Get-WinForgeText 'RAM total') -Value (Format-WinForgeBytes -Bytes $totalRamBytes -ZeroText (Get-WinForgeText 'Não disponível'))
        Write-WinForgeKeyValue -Label (Get-WinForgeText 'Módulos') -Value (Get-WinForgeMemoryModulesText -Modules $memoryModules)
        Write-WinForgeKeyValue -Label (Get-WinForgeText 'Tipo') -Value $memoryType
        Write-WinForgeKeyValue -Label (Get-WinForgeText 'Velocidade configurada') -Value $ramClockText
        Write-WinForgeKeyValue -Label "XMP/EXPO" -Value $xmpText

        # A nota fica junto do valor que ela explica (antes ia para o fim da tela, depois dos discos).
        # Os textos de Get-WinForgeExpoXmpStatus que são dedução (no idioma da tela): o começo de cada um, antes do número.
        $deduced = @('Indicativo: ativado ({0} MT/s, acima dos {1} MT/s do módulo)', 'Indicativo: ativado ({0} MT/s, acima da velocidade padrão)', 'Velocidade padrão ({0} MT/s)') |
            ForEach-Object { (Get-WinForgeText $_).Split('{')[0] }
        if (@($deduced | Where-Object { $_ -and $xmpText.StartsWith($_, [System.StringComparison]::Ordinal) }).Count -gt 0) {
            Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'XMP/EXPO é deduzido da velocidade em uso; o Windows não informa o perfil escolhido na BIOS.')
        }

        Write-WinForgeSection -Title (Get-WinForgeText 'Vídeo')

        if ($validGpus.Count -eq 0) {
            Write-WinForgeKeyValue -Label "GPU" -Value $null
        }

        $gpuNumber = 0

        foreach ($gpu in $validGpus) {
            # Uma linha em branco entre uma placa e outra; depois da última, a próxima seção já abre com a sua.
            if ($gpuNumber -gt 0) { Write-Host "" }
            $gpuNumber++

            $gpuName = ([string]$gpu.Name).Trim()

            if (Test-WinForgeIntegratedGpu -GpuName $gpuName) {
                $vramText = (Get-WinForgeText 'Memória compartilhada / GPU integrada')
            }
            else {
                $registryVramBytes = Get-WinForgeGpuMemoryBytes -GpuName $gpuName

                # AdapterRAM é um valor de 32 bits e satura em 4 GB; o Registro só é consultado primeiro por isso.
                if ($null -ne $registryVramBytes -and $registryVramBytes -gt 0) {
                    $vramText = Format-WinForgeBytes -Bytes $registryVramBytes -ZeroText (Get-WinForgeText 'Desconhecido')
                }
                elseif ($null -ne $gpu.AdapterRAM -and [double]$gpu.AdapterRAM -ge 4293918720) {
                    # O valor de 32 bits do WMI para em 4 GB: uma placa de 8 ou 12 GB também aparece assim.
                    $vramText = (Get-WinForgeText '4 GB ou mais')
                }
                else {
                    $vramText = Format-WinForgeBytes -Bytes $gpu.AdapterRAM -ZeroText (Get-WinForgeText 'Desconhecido')
                }
            }

            Write-WinForgeKeyValue -Label "GPU" -Value $gpuName
            Write-WinForgeKeyValue -Label (Get-WinForgeText 'Memória de vídeo') -Value $vramText
        }

        # O adaptador básico só sobra na lista quando não há outra placa: a de verdade está sem o driver do fabricante
        # (imagem sem aceleração, resolução errada, um monitor só). Um aviso só, mesmo com duas placas sem driver.
        if (@($validGpus | Where-Object { [string]$_.Name -match "Microsoft Basic Display" }).Count -gt 0) {
            Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'A placa de vídeo está sem o driver do fabricante (o Windows usa o driver básico). Instale-o em Atualizações > Atualizar drivers.')
        }

        Write-WinForgeSection -Title (Get-WinForgeText 'Discos')
        Show-WinForgeDiskSummary
    }
    catch {
        Write-WinForgeStatus -Type Error -Message (Get-WinForgeText 'Ocorreu um erro ao ler as informações do sistema: {0}' "$($_.Exception.Message)")
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

    # O mesmo código que a tela mostra (ConfigManagerErrorCode, com Problem de reserva): duas leituras diferentes
    # deixariam um dispositivo na lista com "sem código".
    # Um nome de problema que a tabela não conhece (de uma versão mais nova do Windows) também conta.
    $code = Get-WinForgeDeviceProblemCode -Device $Device
    $problem = [string](Get-WinForgeJsonValue -Object $Device -Name "Problem" -Default "")
    $unknownProblem = (-not [string]::IsNullOrWhiteSpace($problem)) -and ($problem -notin @("0", "CM_PROB_NONE"))
    $hasBadStatus = ([string](Get-WinForgeJsonValue -Object $Device -Name "Status" -Default "")) -in @("Error", "Degraded")

    return (([int]$code -gt 0) -or $unknownProblem -or $hasBadStatus)
}


function Get-WinForgeDeviceProblemCode {
    # O código do Gerenciador de Dispositivos (28 = driver não instalado...). Get-PnpDevice traz o número em
    # ConfigManagerErrorCode e o nome (CM_PROB_FAILED_INSTALL) em Problem; vale o que vier. Sem código = 0.
    param (
        [Parameter(Mandatory)]
        $Device
    )

    $number = 0
    $raw = [string](Get-WinForgeJsonValue -Object $Device -Name "ConfigManagerErrorCode" -Default "")

    if ([int]::TryParse($raw, [ref]$number) -and $number -gt 0) {
        return $number
    }

    $problem = [string](Get-WinForgeJsonValue -Object $Device -Name "Problem" -Default "")

    if ([int]::TryParse($problem, [ref]$number)) {
        return [Math]::Max(0, $number)
    }

    $byName = @{
        CM_PROB_NOT_CONFIGURED = 1; CM_PROB_OUT_OF_MEMORY = 3; CM_PROB_FAILED_START = 10; CM_PROB_NORMAL_CONFLICT = 12
        CM_PROB_NEED_RESTART = 14; CM_PROB_REINSTALL = 18; CM_PROB_REGISTRY = 19; CM_PROB_WILL_BE_REMOVED = 21
        CM_PROB_DISABLED = 22; CM_PROB_DEVICE_NOT_THERE = 24; CM_PROB_FAILED_INSTALL = 28; CM_PROB_HARDWARE_DISABLED = 29
        CM_PROB_FAILED_ADD = 31; CM_PROB_DISABLED_SERVICE = 32; CM_PROB_FAILED_DRIVER_ENTRY = 37
        CM_PROB_DRIVER_FAILED_PRIOR_UNLOAD = 38; CM_PROB_DRIVER_FAILED_LOAD = 39; CM_PROB_DRIVER_SERVICE_KEY_INVALID = 40
        CM_PROB_LEGACY_SERVICE_NO_DEVICES = 41; CM_PROB_DUPLICATE_DEVICE = 42; CM_PROB_FAILED_POST_START = 43
        CM_PROB_HALTED = 44; CM_PROB_PHANTOM = 45; CM_PROB_HELD_FOR_EJECT = 47; CM_PROB_DRIVER_BLOCKED = 48
        CM_PROB_UNSIGNED_DRIVER = 52
    }

    if ($byName.ContainsKey($problem)) {
        return [int]$byName[$problem]
    }

    return 0
}


function Get-WinForgeDeviceProblemText {
    # O problema de um dispositivo em português, com o código que o Gerenciador de Dispositivos mostra (para quem vai
    # procurar ajuda): "o driver não está instalado (código 28)".
    param (
        [Parameter(Mandatory)]
        $Device
    )

    $code = Get-WinForgeDeviceProblemCode -Device $Device

    $texts = @{
        1 = (Get-WinForgeText 'o dispositivo não está configurado corretamente'); 3 = (Get-WinForgeText 'faltou memória ou o driver está corrompido')
        10 = (Get-WinForgeText 'o dispositivo não consegue iniciar'); 12 = (Get-WinForgeText 'falta de recursos livres (conflito com outro dispositivo)')
        14 = (Get-WinForgeText 'o dispositivo só funciona depois de reiniciar o PC'); 18 = (Get-WinForgeText 'os drivers precisam ser reinstalados')
        19 = (Get-WinForgeText 'a configuração no Registro está incompleta ou danificada'); 21 = (Get-WinForgeText 'o Windows está removendo o dispositivo')
        22 = (Get-WinForgeText 'desativado'); 24 = (Get-WinForgeText 'ausente, com defeito ou sem todos os drivers'); 28 = (Get-WinForgeText 'o driver não está instalado')
        29 = (Get-WinForgeText 'desativado pelo firmware (BIOS/UEFI)'); 31 = (Get-WinForgeText 'o Windows não consegue carregar o driver')
        32 = (Get-WinForgeText 'o serviço do driver está desativado'); 37 = (Get-WinForgeText 'o driver não conseguiu iniciar')
        38 = (Get-WinForgeText 'uma cópia anterior do driver ainda está na memória'); 39 = (Get-WinForgeText 'o driver está corrompido ou ausente')
        40 = (Get-WinForgeText 'a configuração do driver no Registro está errada'); 41 = (Get-WinForgeText 'o driver carregou, mas não encontrou o hardware')
        42 = (Get-WinForgeText 'há um dispositivo duplicado em uso'); 43 = (Get-WinForgeText 'o Windows parou o dispositivo porque ele informou um problema')
        44 = (Get-WinForgeText 'um programa ou serviço desligou o dispositivo'); 45 = (Get-WinForgeText 'o dispositivo não está conectado')
        47 = (Get-WinForgeText 'preparado para remoção segura e ainda conectado'); 48 = (Get-WinForgeText 'o driver foi bloqueado por ter problemas conhecidos com o Windows')
        52 = (Get-WinForgeText 'o Windows não consegue verificar a assinatura digital do driver')
    }

    if ($code -gt 0) {
        $text = $(if ($texts.ContainsKey($code)) { $texts[$code] } else { (Get-WinForgeText 'problema informado pelo Windows') })
        return (Get-WinForgeText '{0} (código {1})' "$text" "$code")
    }

    switch ([string](Get-WinForgeJsonValue -Object $Device -Name "Status" -Default "")) {
        "Degraded" { return (Get-WinForgeText 'funcionando com problemas (estado degradado)') }
        default { return (Get-WinForgeText 'o Windows marca o dispositivo com erro') }
    }
}


function Get-WinForgeDeviceName {
    # Nome para a pessoa: o nome amigável e, entre parênteses, a categoria em português ("Rede", "Vídeo"...).
    param (
        [Parameter(Mandatory)]
        $Device
    )

    $name = ""

    foreach ($field in @("FriendlyName", "Name", "InstanceId")) {
        $name = ([string](Get-WinForgeJsonValue -Object $Device -Name $field -Default "")).Trim()
        if ($name) { break }
    }

    if (-not $name) { $name = (Get-WinForgeText 'Dispositivo sem nome') }

    $classes = @{
        Net = (Get-WinForgeText 'Rede'); Display = (Get-WinForgeText 'Vídeo'); MEDIA = (Get-WinForgeText 'Som e vídeo'); AudioEndpoint = (Get-WinForgeText 'Áudio'); Bluetooth = (Get-WinForgeText 'Bluetooth')
        Camera = (Get-WinForgeText 'Câmera'); Image = (Get-WinForgeText 'Câmera ou scanner'); USB = "USB"; HIDClass = (Get-WinForgeText 'Dispositivo de entrada'); Keyboard = (Get-WinForgeText 'Teclado')
        Mouse = (Get-WinForgeText 'Mouse'); Monitor = (Get-WinForgeText 'Monitor'); Printer = (Get-WinForgeText 'Impressora'); DiskDrive = (Get-WinForgeText 'Disco'); HDC = (Get-WinForgeText 'Controladora de disco')
        SCSIAdapter = (Get-WinForgeText 'Controladora de armazenamento'); System = (Get-WinForgeText 'Sistema'); Battery = (Get-WinForgeText 'Bateria'); Biometric = (Get-WinForgeText 'Biometria')
        SoftwareDevice = (Get-WinForgeText 'Dispositivo virtual'); Ports = (Get-WinForgeText 'Portas'); SmartCardReader = (Get-WinForgeText 'Leitor de cartão')
    }

    $class = ([string](Get-WinForgeJsonValue -Object $Device -Name "Class" -Default "")).Trim()

    if (-not $class) { return $name }

    $classText = $(if ($classes.ContainsKey($class)) { $classes[$class] } else { $class })

    return "$name ($classText)"
}


function Show-WinForgeProblemDevices {
    Enter-WinForgeAction -Title (Get-WinForgeText 'Dispositivos com problema')

    try {
        # -ErrorAction Stop: na janela, um erro comum da consulta (o serviço do WMI parado) só seria escrito, a lista
        # viria vazia e a tela diria "nenhum dispositivo com problema" sem ter olhado.
        $problemDevices = @(
            Invoke-WinForgeCimCommand -Name "Get-PnpDevice" -Parameters @{ PresentOnly = $true } |
            Where-Object { Test-WinForgePnpDeviceHasProblem -Device $_ }
        )

        # Desativado (código 22, pelo Gerenciador; 29, pelo firmware ou pela BIOS) é uma escolha de alguém, não um defeito:
        # fica numa seção à parte, sem alarme.
        $realProblems = @($problemDevices | Where-Object { (Get-WinForgeDeviceProblemCode -Device $_) -notin @(22, 29) })
        $disabledDevices = @($problemDevices | Where-Object { (Get-WinForgeDeviceProblemCode -Device $_) -in @(22, 29) })

        Write-WinForgeSection -Title (Get-WinForgeText 'Problemas ativos')

        if ($realProblems.Count -eq 0) {
            Write-WinForgeStatus -Type Success -Message (Get-WinForgeText 'Nenhum dispositivo com problema.')
        }
        else {
            # Cada dispositivo numa linha de aviso: a janela as mostra no resumo (uma tabela ficaria só nos detalhes). O
            # identificador do Windows vai embaixo, em cinza, para quem precisar pesquisar.
            Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText '{0} com problema ativo:' "$(Format-WinForgeCount -Count $realProblems.Count -One (Get-WinForgeText 'dispositivo') -Many (Get-WinForgeText 'dispositivos'))")

            foreach ($device in $realProblems) {
                Write-WinForgeStatus -Type Warning -Message "$(Get-WinForgeDeviceName -Device $device): $(Get-WinForgeDeviceProblemText -Device $device)."

                $instance = [string](Get-WinForgeJsonValue -Object $device -Name "InstanceId" -Default "")
                if ($instance) { Write-Host "      $instance" -ForegroundColor DarkGray }
            }

            Write-Host ""

            # Código 14: o dispositivo só volta a funcionar depois de reiniciar (o Gerenciador não resolve).
            if (@($realProblems | Where-Object { (Get-WinForgeDeviceProblemCode -Device $_) -eq 14 }).Count -gt 0) {
                Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Reinicie o PC: o Windows pede o reinício para terminar de preparar um dispositivo.')
            }

            Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Para tentar resolver, use Reparo > Detectar dispositivos e drivers e depois Atualizações > Atualizar drivers.')
            Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Se continuar, abra Diagnóstico > Gerenciador de Dispositivos, clique com o botão direito no dispositivo e escolha Atualizar driver. Se ele não aparecer lá, ligue Mostrar dispositivos ocultos, no menu Exibir.')
        }

        if ($disabledDevices.Count -gt 0) {
            Write-WinForgeSection -Title (Get-WinForgeText 'Dispositivos desativados')

            foreach ($device in $disabledDevices) {
                Write-WinForgeStatus -Type Info -Message (Get-WinForgeDeviceName -Device $device)
            }

            Write-Host ""
            Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Dispositivos desativados podem ser intencionais, como uma placa de vídeo integrada desligada de propósito; para religar, use Diagnóstico > Gerenciador de Dispositivos.')
        }

        # Sem problema ativo, a dica de onde procurar drivers mais novos (com problema, ela já está no que fazer acima).
        if ($realProblems.Count -eq 0) {
            Write-Host ""
            Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Isto mostra os dispositivos com erro agora; para procurar drivers mais novos, use Atualizações > Atualizar drivers.')
        }

        # A faixa de resultado diz a contagem (a última linha de aviso seria a de um dispositivo qualquer) e leva ao primeiro
        # passo que a tela dá, a busca de dispositivos. Com só o código 14 (reinício pendente), o que resolve é reiniciar.
        $result = $(if ($realProblems.Count -gt 0) {
                New-WinForgeResult -Kind Warning -Detail (Get-WinForgeText '{0} com problema ativo' "$(Format-WinForgeCount -Count $realProblems.Count -One (Get-WinForgeText 'dispositivo') -Many (Get-WinForgeText 'dispositivos'))")
            }
            else {
                New-WinForgeResult -Kind Ok -Detail (Get-WinForgeText 'nenhum dispositivo com problema ativo')
            })

        if (@($realProblems | Where-Object { (Get-WinForgeDeviceProblemCode -Device $_) -ne 14 }).Count -gt 0) {
            [void](Set-WinForgeResultView -Result $result -Next "repair.device-scan" -NextLabel (Get-WinForgeText 'Detectar dispositivos'))
        }
    }
    catch {
        Write-WinForgeStatus -Type Error -Message (Get-WinForgeText 'Não foi possível consultar os dispositivos: {0}' "$($_.Exception.Message)")
        $result = $null
    }

    Exit-WinForgeAction -Result $result
}


function Show-WinForgeDisks {
    Enter-WinForgeAction -Title (Get-WinForgeText 'Discos e espaço livre')

    $result = $null

    try {
        Write-WinForgeSection -Title (Get-WinForgeText 'Volumes e discos')
        $lowDisks = @(Show-WinForgeDiskSummary -PassThru)

        # Com uma unidade só, a frase dela é a da faixa; com várias, a faixa cita todas (e não só a última). Com o disco do
        # Windows entre elas, o botão da faixa abre a Limpeza personalizada, como o "Liberar espaço" do Início.
        if ($lowDisks.Count -gt 0) {
            $detail = $(if ($lowDisks.Count -eq 1) { (Get-WinForgeLowDiskText -Disk $lowDisks[0]).TrimEnd(".") } else { (Get-WinForgeText 'pouco espaço em {0}' "$(Join-WinForgeList -Items @($lowDisks | ForEach-Object { [string]$_.Unidade }))") })
            $result = New-WinForgeResult -Kind Warning -Detail $detail

            if (@($lowDisks | Where-Object { [bool](Get-WinForgeJsonValue -Object $_ -Name "Sistema" -Default $false) }).Count -gt 0) {
                [void](Set-WinForgeResultView -Result $result -Next "cleanup.custom" -NextLabel (Get-WinForgeText 'Liberar espaço'))
            }
        }
    }
    catch {
        Write-WinForgeStatus -Type Error -Message (Get-WinForgeText 'Ocorreu um erro ao consultar informações de disco: {0}' "$($_.Exception.Message)")
    }

    Exit-WinForgeAction -Result $result
}


function Get-WinForgeFastStartupText {
    # A Inicialização Rápida guarda o estado em HiberbootEnabled, que continua em 1 mesmo depois de desligar a
    # hibernação; mas ela usa o arquivo de hibernação, então sem a hibernação não tem efeito.
    $fast = Get-WinForgeRegistryValueOrNull -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" -Name "HiberbootEnabled"

    if ($null -eq $fast -or ([string]$fast -notin @("0", "1"))) {
        return (Get-WinForgeText 'Desconhecido')
    }

    if ([int]$fast -eq 0) {
        return (Get-WinForgeText 'Desativada')
    }

    if ((Get-WinForgeHibernationText) -eq (Get-WinForgeText 'Desativada')) {
        return (Get-WinForgeText 'Sem efeito: a hibernação está desligada, e a Inicialização Rápida depende dela')
    }

    return (Get-WinForgeText 'Ativada')
}


function Get-WinForgeHibernationText {
    # A hibernação (HibernateEnabled): é dela que a Inicialização Rápida depende.
    $hibernate = Get-WinForgeRegistryValueOrNull -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Power" -Name "HibernateEnabled"

    switch ([string]$hibernate) {
        "1" { return (Get-WinForgeText 'Ativada') }
        "0" { return (Get-WinForgeText 'Desativada') }
        default { return (Get-WinForgeText 'Desconhecido') }
    }
}


function Show-WinForgeStartupInfo {
    Enter-WinForgeAction -Title (Get-WinForgeText 'Tempo ligado e energia')

    $result = $null

    try {
        $os = Get-WinForgeCimOrNull -ClassName "Win32_OperatingSystem" | Select-Object -First 1
        $lastBootTime = $(if ($os) { $os.LastBootUpTime } else { $null })

        Write-WinForgeSection -Title (Get-WinForgeText 'Inicialização')

        if ($null -ne $lastBootTime) {
            Write-WinForgeKeyValue -Label (Get-WinForgeText 'Tempo ligado') -Value (Get-WinForgeUptimeText -LastBootTime $lastBootTime)
            Write-WinForgeKeyValue -Label (Get-WinForgeText 'Última inicialização') -Value (Format-WinForgeDateTime -When $lastBootTime)
        }
        else {
            Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'Inicialização: desconhecida (o Windows não informou quando o PC foi ligado).')
        }

        $fastStartup = Get-WinForgeFastStartupText

        Write-WinForgeSection -Title (Get-WinForgeText 'Inicialização Rápida')
        Write-WinForgeKeyValue -Label (Get-WinForgeText 'Situação') -Value $fastStartup

        if ($fastStartup -eq (Get-WinForgeText 'Ativada')) {
            Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Com a Inicialização Rápida ligada, desligar o PC não zera o tempo ligado: só Reiniciar faz o Windows começar do zero.')
        }

        # O que a pessoa costuma procurar aqui ("o PC demora para ligar"): a causa mais comum são os programas que abrem
        # junto com o Windows.
        Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Se o PC demora para ligar, veja o que abre junto com o Windows em Desempenho > Gerenciar inicialização.')

        Write-WinForgeSection -Title (Get-WinForgeText 'Hibernação e modos de energia')
        Write-WinForgeKeyValue -Label (Get-WinForgeText 'Hibernação') -Value (Get-WinForgeHibernationText)

        # A lista de modos de energia (suspensão, hibernação...) é a do powercfg, no idioma do Windows.
        if (Get-Command "powercfg.exe" -ErrorAction SilentlyContinue) {
            Write-Host ""
            $exitCode = Invoke-WinForgeNative -FilePath "powercfg.exe" -Arguments @("/a") -IgnoreExitCode -PassThru

            if ($exitCode -ne 0) {
                Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'Não foi possível listar os modos de energia (powercfg finalizou com código {0}).' "$exitCode")
            }
        }
        else {
            Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'Não foi possível listar os modos de energia: powercfg.exe não foi encontrado.')
        }

        # Ligado há uma semana ou mais, a faixa do Desempenho traz a pessoa para cá: o que resolve é reiniciar, e a tela
        # oferece (com Não como padrão, e sem fechar nada à força), como Reinício pendente.
        if (Test-WinForgeLongUptime -LastBootTime $lastBootTime) {
            try {
                if (Request-WinForgeRestart -Reason (Get-WinForgeText 'O PC está ligado há {0}: reiniciar deixa o Windows mais leve.' "$(Get-WinForgeUptimeText -LastBootTime $lastBootTime)") -Comment (Get-WinForgeText 'Reinicialização solicitada pelo WinForge (PC ligado há uma semana ou mais).') -DeclinedMessage (Get-WinForgeText 'O PC não foi reiniciado. Reinicie quando puder.')) {
                    $result = New-WinForgeResult -Kind Ok -Detail (Get-WinForgeText 'o Windows está reiniciando')
                }
            }
            catch {
                Write-WinForgeStatus -Type Error -Message (Get-WinForgeText 'Não foi possível pedir o reinício: {0}.' "$($_.Exception.Message.TrimEnd('.'))")
            }
        }
    }
    catch {
        Write-WinForgeStatus -Type Error -Message (Get-WinForgeText 'Não foi possível ler o tempo ligado e a energia: {0}' "$($_.Exception.Message)")
    }

    Exit-WinForgeAction -Result $result
}


function Test-WinForgeStartupTargetMissing {
    <#
    Se um item de inicialização abre um arquivo que com certeza não existe mais (num disco fixo): aí nada abre com o
    Windows, e o item não entra na lista (a Limpeza do registro remove as entradas Run quebradas). -Shortcut: Command é
    um atalho (.lnk), e o que conta é o destino dele. Na dúvida (sem caminho completo, rede, pendrive, atalho sem destino
    como os da Store e os anunciados do Windows Installer), o arquivo conta como existente.
    #>
    param (
        [AllowEmptyString()][string]$Command,
        [switch]$Shortcut
    )

    try {
        if ($Shortcut) {
            $link = Get-WinForgeShortcutTarget -Path $Command
            $target = $(if ($null -ne $link) { [string]$link.TargetPath } else { "" })
        }
        else {
            # Sem aspas, um caminho com espaços sem extensão no fim não é reconhecido: fica como "não sei".
            $target = Get-WinForgeCommandTargetPath -Command $Command
        }

        if ([string]::IsNullOrWhiteSpace($target)) { return $false }

        # -Wow64: um programa de 32 bits pode ter gravado o caminho de System32 que, para ele, é o SysWOW64.
        return [bool](Test-WinForgeLocalPathMissing -Path $target -Wow64)
    }
    catch {
        return $false
    }
}


function Test-WinForgeStartupLauncherOrphan {
    <#
    Se um item de inicialização abre o Update.exe de um programa instalado pelo Squirrel (o instalador de muitos programas
    feitos em Electron, como o Discord, o Slack e o FACEIT) e o programa não está mais na pasta. O item abre
    "Update.exe --processStart Programa.exe", e o Update.exe abre o Programa.exe da pasta app-<versão> mais nova; ao
    desinstalar, o Squirrel apaga as pastas app-* e deixa o Update.exe, que estava em uso, e a entrada que o programa pôs
    na inicialização fica sem abrir nada. Arguments: os argumentos de um atalho, que ficam fora do Command. Na dúvida (outro
    comando, o Update.exe que não existe, a pasta que não dá para ler, um disco que não é fixo), falso.
    #>
    param (
        [AllowEmptyString()][string]$Command,
        [AllowEmptyString()][string]$Arguments = ""
    )

    try {
        $target = Get-WinForgeCommandTargetPath -Command $Command

        if ([string]::IsNullOrWhiteSpace($target)) { return $false }
        if ((($target.Trim().Trim('"')) -split '[\\/]')[-1] -ine "Update.exe") { return $false }

        # O programa que o Update.exe abre: --processStart "Programa.exe" (ou --processStart=Programa.exe), só o nome.
        $match = [regex]::Match("$Command $Arguments", '(?i)--processStart(?:AndWait)?(?:=|\s+)(?:"([^"]+)"|([^\s"]+))')

        if (-not $match.Success) { return $false }

        $exe = $(if ($match.Groups[1].Success) { $match.Groups[1].Value } else { $match.Groups[2].Value }).Trim()

        if ($exe -notmatch '^[^\\/:*?"<>|]+\.exe$') { return $false }

        $updater = [Environment]::ExpandEnvironmentVariables($target.Trim().Trim('"'))

        if ($updater -notmatch '^[A-Za-z]:\\' -or $updater -match '[%"<>|*?]') { return $false }
        if ((Get-WinForgeDriveType -Root $updater.Substring(0, 3)) -ne "Fixed") { return $false }
        if (-not (Test-Path -LiteralPath $updater -PathType Leaf)) { return $false }

        $folder = $updater.Substring(0, $updater.LastIndexOf('\'))

        if ($folder.Length -le 2) { return $false }

        # O programa ainda está lá: numa pasta app-<versão>, na pasta current (as versões novas do Squirrel) ou como o
        # lançador na própria pasta.
        if (Test-Path -LiteralPath "$folder\$exe" -PathType Leaf) { return $false }
        if (Test-Path -LiteralPath "$folder\current\$exe" -PathType Leaf) { return $false }

        foreach ($app in @(Get-ChildItem -LiteralPath $folder -Directory -Filter "app-*" -Force -ErrorAction Stop)) {
            if (Test-Path -LiteralPath "$(([string]$app.FullName).TrimEnd('\'))\$exe" -PathType Leaf) { return $false }
        }

        return $true
    }
    catch {
        return $false
    }
}


function Get-WinForgeStartupLeftoverReason {
    <#
    Por que um item de inicialização não abre mais nada: "missing" (o arquivo que ele abre não existe mais,
    Test-WinForgeStartupTargetMissing) ou "launcher" (sobrou só o Update.exe do Squirrel,
    Test-WinForgeStartupLauncherOrphan). "" quando abre, e na dúvida. -Shortcut: Command é um atalho (.lnk), e o que conta
    é o destino dele, com os argumentos.
    #>
    param (
        [AllowEmptyString()][string]$Command,
        [switch]$Shortcut
    )

    if (Test-WinForgeStartupTargetMissing -Command $Command -Shortcut:$Shortcut) { return "missing" }

    if ($Shortcut) {
        $link = Get-WinForgeShortcutTarget -Path $Command

        if ($null -eq $link -or [string]::IsNullOrWhiteSpace([string]$link.TargetPath)) { return "" }
        if (Test-WinForgeStartupLauncherOrphan -Command ('"' + ([string]$link.TargetPath).Trim().Trim('"') + '"') -Arguments ([string]$link.Arguments)) { return "launcher" }

        return ""
    }

    if (Test-WinForgeStartupLauncherOrphan -Command $Command) { return "launcher" }

    return ""
}


function Test-WinForgeStartupUserVariable {
    <#
    Se o comando de um valor Run, como está gravado (sem expandir), usa uma pasta da conta (%LOCALAPPDATA%, %APPDATA%,
    %USERPROFILE%...): numa chave de todos os usuários, cada conta tem a sua, e a que o WinForge vê é só a da conta dele.
    Sem conseguir ler, verdadeiro: na dúvida, o item não é dado como sobra.
    #>
    param (
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Name
    )

    try {
        $key = Get-Item -LiteralPath $Path -ErrorAction Stop
        $raw = [string]$key.GetValue($Name, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
    }
    catch {
        return $true
    }

    return ($raw -match '(?i)%(USERPROFILE|APPDATA|LOCALAPPDATA|HOMEPATH|HOMEDRIVE|HOMESHARE|USERNAME|USERDOMAIN|TEMP|TMP|ONEDRIVE\w*)%')
}


function Get-WinForgeStartupAppStates {
    <#
    O liga/desliga das tarefas de inicialização de aplicativos empacotados (Store, MSIX) que o Windows já registrou na
    conta: HKCU\Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\SystemAppData\
    <família do pacote>\<TaskId>, DWORD State, com os números de Windows.ApplicationModel.StartupTaskState: 0 desativada
    (pelo próprio aplicativo), 1 desativada pela pessoa (Gerenciador de Tarefas ou Configurações; o aplicativo não
    consegue se religar), 2 ativada, 3 desativada por política, 4 ativada por política. Devolve Family, TaskId, State e
    Path (a chave, como HKCU:\...). Lido pelo .NET, sem o provedor do PowerShell: SystemAppData tem centenas de chaves.
    Sem acesso (ou fora do Windows), nenhuma.
    #>
    $relative = "Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\SystemAppData"
    $states = @()
    $root = $null

    try {
        $root = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($relative)

        if ($null -eq $root) { return @() }

        foreach ($family in @($root.GetSubKeyNames())) {
            $familyKey = $null

            # Uma chave sem permissão de leitura não derruba as outras.
            try {
                $familyKey = $root.OpenSubKey($family)

                if ($null -eq $familyKey) { continue }

                foreach ($taskId in @($familyKey.GetSubKeyNames())) {
                    $taskKey = $null

                    try {
                        $taskKey = $familyKey.OpenSubKey($taskId)

                        if ($null -ne $taskKey -and @($taskKey.GetValueNames()) -contains "State" -and [string]$taskKey.GetValueKind("State") -eq "DWord") {
                            $states += [PSCustomObject]@{ Family = $family; TaskId = $taskId; State = [int]$taskKey.GetValue("State"); Path = "HKCU:\$relative\$family\$taskId" }
                        }
                    }
                    catch {
                        # Sem acesso a esta tarefa: fica de fora.
                    }
                    finally {
                        if ($null -ne $taskKey) { $taskKey.Close() }
                    }
                }
            }
            catch {
                # Sem acesso a este pacote: fica de fora.
            }
            finally {
                if ($null -ne $familyKey) { $familyKey.Close() }
            }
        }
    }
    catch {
        return @()
    }
    finally {
        if ($null -ne $root) { $root.Close() }
    }

    return @($states)
}


function Get-WinForgeStartupPackagedApps {
    <#
    Os aplicativos empacotados (Store, MSIX: Teams, Spotify, WhatsApp...) que têm tarefa de inicialização, no formato dos
    itens de Get-WinForgeStartupItems, com Publisher. ApprovedPath é a chave da tarefa, onde o Windows guarda o State.

    Só entra o que dá para ligar e desligar como as Configurações fazem: a tarefa que o Windows já registrou na conta,
    com State 0, 1 ou 2, de um pacote instalado para a conta que declara essa tarefa no manifesto (uma chave que sobrou
    de um aplicativo desinstalado não entra). State 3 e 4 são de política (quem decide é o administrador) e ficam de
    fora; uma tarefa ainda não registrada (o aplicativo nunca foi aberto) não abre com o Windows e também fica de fora.
    Sem o Get-AppxPackage, nenhum.
    #>
    $items = @()
    $startNames = $null

    foreach ($state in @(Get-WinForgeStartupAppStates)) {
        if (@(0, 1, 2) -notcontains [int]$state.State) { continue }

        $family = [string]$state.Family
        $cut = $family.LastIndexOf("_")

        if ($cut -lt 1) { continue }

        try {
            $package = @(Get-AppxPackage -Name $family.Substring(0, $cut) -ErrorAction Stop | Where-Object { $null -ne $_ -and [string]$_.PackageFamilyName -eq $family }) | Select-Object -First 1

            if ($null -eq $package) { continue }

            $manifest = Get-AppxPackageManifest -Package ([string]$package.PackageFullName) -ErrorAction Stop
        }
        catch {
            continue
        }

        if ($null -eq $manifest) { continue }

        # A tarefa no manifesto: uap5:StartupTask (ou desktop:StartupTask, nos pacotes de programas clássicos).
        $taskNode = $null

        foreach ($node in @($manifest.SelectNodes("//*[local-name()='Extension'][@Category='windows.startupTask']/*[local-name()='StartupTask']"))) {
            if ([string]$node.GetAttribute("TaskId") -eq [string]$state.TaskId) {
                $taskNode = $node
                break
            }
        }

        if ($null -eq $taskNode) { continue }

        # O nome que o Gerenciador de Tarefas mostra é o DisplayName da tarefa; quando ele é um recurso traduzido
        # (ms-resource:), vale o nome do aplicativo no menu Iniciar e, sem ele, o nome do pacote.
        $name = ([string]$taskNode.GetAttribute("DisplayName")).Trim()

        if ([string]::IsNullOrWhiteSpace($name) -or $name -like "ms-resource:*") {
            if ($null -eq $startNames) {
                $startNames = @{}

                try {
                    foreach ($app in @(Get-StartApps -ErrorAction Stop)) {
                        if ($null -ne $app -and -not [string]::IsNullOrWhiteSpace([string]$app.AppID)) { $startNames[[string]$app.AppID] = [string]$app.Name }
                    }
                }
                catch {
                    # Sem o menu Iniciar, o nome do pacote.
                }
            }

            $application = $taskNode.ParentNode.ParentNode.ParentNode
            $appId = $(if ($application -is [System.Xml.XmlElement]) { "$family!" + [string]$application.GetAttribute("Id") } else { "" })
            $name = $(if ($appId -and $startNames.ContainsKey($appId) -and $startNames[$appId]) { $startNames[$appId] } else { [string]$package.Name })
        }

        $publisherNode = $manifest.SelectSingleNode("//*[local-name()='Properties']/*[local-name()='PublisherDisplayName']")
        $publisher = $(if ($null -ne $publisherNode) { ([string]$publisherNode.InnerText).Trim() } else { "" })

        if ($publisher -like "ms-resource:*") { $publisher = "" }

        $items += [PSCustomObject]@{
            Name = $name; Source = "Aplicativo da Store"; Enabled = ([int]$state.State -eq 2)
            Command = ""; Scope = "User"; ApprovedPath = [string]$state.Path; Publisher = $publisher
        }
    }

    return @($items)
}


function Get-WinForgeStartupItems {
    <#
    Os programas que abrem junto com o Windows, os mesmos do Gerenciador de Tarefas (Aplicativos de inicialização) e de
    Configurações, Aplicativos, Inicialização: as chaves Run (usuário, todos os usuários e 32 bits), as pastas
    Inicializar (usuário e todos os usuários) e os aplicativos da Store com tarefa de inicialização. Enabled é falso
    para o que foi desativado ali: o Windows mantém o item e só marca o liga/desliga (StartupApproved, primeiro byte
    ímpar = desativado; nos aplicativos da Store, o State da tarefa). Scope: User (só esta conta) ou Machine (todos os
    usuários, pede Administrador); ApprovedPath: onde o Windows guarda o liga/desliga do item.

    Ficam de fora, de propósito:
    - RunOnce: roda uma vez só (em geral, o fim de uma instalação) e não tem liga/desliga; tirar seria apagar, e apagar
      estraga a instalação. O Gerenciador de Tarefas também não mostra.
    - As chaves Run de Policies\Explorer: são de política; o Windows não deixa desativar.
    - Valores vazios ou que não são texto.
    - O que sobrou de um programa desinstalado (Get-WinForgeStartupLeftoverReason): o arquivo não existe mais, ou só
      sobrou o Update.exe do Squirrel. Não abre nada; o Gerenciador de Tarefas mostra, mas ligar ou desligar não muda nada.
    - Num PowerShell de 32 bits num Windows de 64 bits, as chaves Run de todos os usuários: o Windows troca a de 64 bits
      pela de 32 por baixo, e a lista sairia repetida, com o liga/desliga gravado no lugar errado.

    -Leftovers: o contrário, só o que sobrou (das chaves Run e das pastas Inicializar), com Leftover ("missing" ou
    "launcher"), para Gerenciar inicialização tirar. Numa chave de todos os usuários, só o que não usa uma pasta da conta
    (Test-WinForgeStartupUserVariable). Os aplicativos da Store não entram: o de um pacote desinstalado já fica de fora.
    Cada item traz também RunKey, a chave Run de onde veio (vazia nos da pasta Inicializar).
    #>
    param (
        # Pastas Inicializar do usuário e de todos os usuários; o padrão são as do Windows.
        [string]$UserFolder = [Environment]::GetFolderPath("Startup"),
        [string]$CommonFolder = [Environment]::GetFolderPath("CommonStartup"),

        [switch]$Leftovers
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
        @{ Source = "Registro (usuário)"; Scope = "User"; Path = "HKCU:\Software\$runKey"; Approved = "HKCU:\Software\$approvedRoot\Run" }
    )

    if (-not (Test-WinForgeRegistryViewMismatch)) {
        $registrySources += @(
            @{ Source = "Registro (todos os usuários)"; Scope = "Machine"; Path = "HKLM:\SOFTWARE\$runKey"; Approved = "HKLM:\SOFTWARE\$approvedRoot\Run" },
            @{ Source = "Registro (32 bits)"; Scope = "Machine"; Path = "HKLM:\SOFTWARE\WOW6432Node\$runKey"; Approved = "HKLM:\SOFTWARE\$approvedRoot\Run32" }
        )
    }

    foreach ($source in $registrySources) {
        $approved = Get-WinForgeRegistryValues -Path $source.Approved
        $commands = Get-WinForgeRegistryValues -Path $source.Path

        foreach ($name in @($commands.Keys)) {
            $command = $commands[$name]

            if (-not ($command -is [string]) -or [string]::IsNullOrWhiteSpace($command)) { continue }

            $leftover = Get-WinForgeStartupLeftoverReason -Command $command

            if ([bool]$leftover -ne [bool]$Leftovers) { continue }
            if ($Leftovers -and $source.Scope -eq "Machine" -and (Test-WinForgeStartupUserVariable -Path $source.Path -Name $name)) { continue }

            # Command: o que o Windows executa; Scope e ApprovedPath dizem onde o Windows guarda o liga/desliga do item.
            $items += [PSCustomObject]@{
                Name = $name; Source = $source.Source; Enabled = -not (& $isDisabled $approved $name)
                Command = $command; Scope = $source.Scope; ApprovedPath = $source.Approved; RunKey = $source.Path; Leftover = $leftover
            }
        }
    }

    $folders = @(
        @{ Path = $UserFolder; Scope = "User"; Approved = "HKCU:\Software\$approvedRoot\StartupFolder" },
        @{ Path = $CommonFolder; Scope = "Machine"; Approved = "HKLM:\SOFTWARE\$approvedRoot\StartupFolder" }
    )
    $seenFolders = @()

    foreach ($folder in $folders) {
        if ([string]::IsNullOrWhiteSpace($folder.Path) -or -not (Test-Path -LiteralPath $folder.Path -PathType Container)) {
            continue
        }

        # A mesma pasta nos dois lugares entraria duas vezes, cada uma com um liga/desliga.
        $folderKey = $folder.Path.TrimEnd('\', '/')

        if ($seenFolders -contains $folderKey) { continue }

        $seenFolders += $folderKey
        $approved = Get-WinForgeRegistryValues -Path $folder.Approved

        foreach ($file in @(Get-ChildItem -LiteralPath $folder.Path -File -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne "desktop.ini" })) {
            $leftover = $(if ($file.Extension -ieq ".lnk") { Get-WinForgeStartupLeftoverReason -Command $file.FullName -Shortcut } else { "" })

            if ([bool]$leftover -ne [bool]$Leftovers) { continue }

            $items += [PSCustomObject]@{
                Name = $file.Name; Source = "Pasta Inicializar"; Enabled = -not (& $isDisabled $approved $file.Name)
                Command = $file.FullName; Scope = $folder.Scope; ApprovedPath = $folder.Approved; RunKey = ""; Leftover = $leftover
            }
        }
    }

    if (-not $Leftovers) { $items += @(Get-WinForgeStartupPackagedApps) }

    return @($items)
}


function Get-WinForgePendingReboot {
    # Retorna uma lista de motivos. Strong = sinal confiável; PendingFileRenameOperations
    # aparece em muitas máquinas sem reinício realmente necessário.
    $reasons = @()

    # A manutenção dos componentes (CBS) esperando o reinício: as chaves dela e o pending.xml, a mesma leitura que segura o
    # DISM e o SFC (Test-WinForgeServicingRebootPending). Com o pending.xml lido só lá, esta tela dizia "nenhum reinício
    # pendente" enquanto o Reparo pedia para reiniciar antes de reparar.
    if (Test-WinForgeServicingRebootPending) {
        $reasons += [PSCustomObject]@{ Reason = (Get-WinForgeText 'Uma atualização do Windows termina de instalar no reinício'); Strong = $true }
    }

    if (Test-Path -LiteralPath "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired") {
        $reasons += [PSCustomObject]@{ Reason = (Get-WinForgeText 'Windows Update: uma atualização instalada espera o reinício'); Strong = $true }
    }

    # Um serviço do Windows Update esperando o reinício para se registrar: sinal fraco (a chave pode sobrar vazia, ou com
    # um item antigo, e um reinício não a limpa sempre). Só com algo dentro.
    if (@(Get-ChildItem -LiteralPath "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Services\Pending" -ErrorAction SilentlyContinue).Count -gt 0) {
        $reasons += [PSCustomObject]@{ Reason = (Get-WinForgeText 'Windows Update: um serviço de atualização espera o reinício para se registrar (sinal fraco)'); Strong = $false }
    }

    # Um instalador de atualização que marcou o volume para terminar no reinício (UpdateExeVolatile com Flags diferente de 0).
    $volatile = Get-WinForgeRegistryValueOrNull -Path "HKLM:\SOFTWARE\Microsoft\Updates" -Name "UpdateExeVolatile"

    if ($null -ne $volatile -and [string]$volatile -match '^[0-9]+$' -and [int64]$volatile -ne 0) {
        $reasons += [PSCustomObject]@{ Reason = (Get-WinForgeText 'Um instalador de atualização termina o trabalho no reinício'); Strong = $true }
    }

    $activeName = Get-WinForgeRegistryValueOrNull -Path "HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ActiveComputerName" -Name "ComputerName"
    $pendingName = Get-WinForgeRegistryValueOrNull -Path "HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName" -Name "ComputerName"

    if (-not [string]::IsNullOrWhiteSpace($activeName) -and -not [string]::IsNullOrWhiteSpace($pendingName) -and $activeName -ne $pendingName) {
        $reasons += [PSCustomObject]@{ Reason = (Get-WinForgeText 'Renomeação do computador: o nome {0} vale depois do reinício' "$pendingName"); Strong = $true }
    }

    # Entrar num domínio (ou trocar de domínio) só vale depois do reinício.
    $netlogon = "HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon"

    if ((Test-Path -LiteralPath "$netlogon\JoinDomain") -or (Test-Path -LiteralPath "$netlogon\AvoidSpnSet")) {
        $reasons += [PSCustomObject]@{ Reason = (Get-WinForgeText 'Entrada num domínio: vale depois do reinício'); Strong = $true }
    }

    $fileRename = Get-WinForgeRegistryValueOrNull -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -Name "PendingFileRenameOperations"

    if ($null -ne $fileRename -and @($fileRename).Count -gt 0) {
        $reasons += [PSCustomObject]@{ Reason = (Get-WinForgeText 'Arquivos aguardando substituição no próximo reinício (sinal fraco: aparece em muitos PCs sem que o reinício seja necessário)'); Strong = $false }
    }

    return @($reasons)
}


function Test-WinForgePendingReboot {
    return (@(Get-WinForgePendingReboot | Where-Object { $_.Strong }).Count -gt 0)
}


function Test-WinForgeServicingRebootPending {
    <#
    Se a manutenção dos componentes do Windows (CBS) espera um reinício: só aí o DISM recusa a limpeza e o reparo
    (0x800F0806) e o SFC também. Um driver do Windows Update esperando o reinício, um nome novo do PC ou a entrada num
    domínio não atrapalham o DISM e o SFC, e não seguram essas etapas. Pelas chaves da CBS e pelo pending.xml, em que a
    instalação de uma atualização deixa o que o Windows termina ao desligar ou reiniciar. Reinício pendente
    (Get-WinForgePendingReboot) parte daqui, com os outros motivos.
    #>
    $cbs = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing"

    # Caminhos montados como texto: o Join-Path recusa (com erro na tela) uma unidade que não existe.
    foreach ($key in @("RebootPending", "PackagesPending", "RebootInProgress")) {
        if (Test-Path -LiteralPath "$cbs\$key" -ErrorAction SilentlyContinue) { return $true }
    }

    $windows = [string]$env:windir
    if ([string]::IsNullOrWhiteSpace($windows)) { return $false }

    return [bool](Test-Path -LiteralPath ($windows.TrimEnd("\") + "\WinSxS\pending.xml") -PathType Leaf -ErrorAction SilentlyContinue)
}


# A procura das atualizações pendentes (Get-WinForgePendingWindowsUpdates), que roda num runspace à parte: não enxerga as
# funções do WinForge.
$script:WinForgePendingUpdatesSearch = {
    $session = New-Object -ComObject "Microsoft.Update.Session"
    $searcher = $session.CreateUpdateSearcher()

    try {
        $found = $searcher.Search("IsInstalled=0 and IsHidden=0 and BrowseOnly=0")
    }
    catch {
        # Uma versão do Windows que não entenda BrowseOnly (0x80240032, critério inválido) ainda responde à consulta
        # simples. Outro erro (sem internet, serviço parado) sobe: repetir dobraria a espera e contaria as opcionais.
        # O erro do COM chega embrulhado (MethodInvocationException): o código está na exceção de dentro.
        if ([string]$_.Exception.Message -notmatch '80240032' -and $_.Exception.GetBaseException().HResult -ne 0x80240032) { throw }

        $found = $searcher.Search("IsInstalled=0 and IsHidden=0")
    }

    foreach ($update in $found.Updates) {
        [string]$update.Title
    }
}


function Start-WinForgePendingUpdatesSearch {
    <#
    Começa a procurar as atualizações pendentes em segundo plano, sem esperar: a consulta ao Windows Update é a mais
    demorada do Estado da proteção e da auditoria, e as outras leituras correm enquanto ela anda. A resposta vem por
    Get-WinForgePendingWindowsUpdates -Search; quem não chegar a pedi-la larga a procura (Stop-WinForgeInBackground).
    $null quando não deu para começar.
    #>
    try {
        return (Start-WinForgeInBackground -ScriptBlock $script:WinForgePendingUpdatesSearch)
    }
    catch {
        return $null
    }
}


function Get-WinForgePendingWindowsUpdates {
    <#
    Atualizações do Windows ainda não instaladas, pela API do Windows Update. Não conta as opcionais (drivers e
    prévias que o Windows só oferece na página de atualizações opcionais): essas não deixam o PC desprotegido.
    A consulta vai até o serviço, então roda em segundo plano com tempo limite, para que o botão Parar continue
    funcionando. Devolve Count e Titles, ou $null quando não foi possível consultar (inclusive por tempo esgotado).
    -Search recebe a procura já começada (Start-WinForgePendingUpdatesSearch), e o prazo conta desde o começo dela; sem
    ele, a procura começa aqui.
    #>
    param (
        [int]$TimeoutSeconds = 90,

        $Search = $null
    )

    if ($null -eq $Search) { $Search = Start-WinForgePendingUpdatesSearch }
    if ($null -eq $Search) { return $null }

    try {
        $run = Receive-WinForgeInBackground -Task $Search -TimeoutSeconds $TimeoutSeconds
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
    Enter-WinForgeAction -Title (Get-WinForgeText 'Reinício pendente')

    $reasons = @(Get-WinForgePendingReboot)
    $result = $null

    if ($reasons.Count -eq 0) {
        Write-WinForgeStatus -Type Success -Message (Get-WinForgeText 'Nenhum reinício pendente foi detectado.')
        $result = New-WinForgeResult -Kind Ok -Detail (Get-WinForgeText 'nenhum reinício pendente')
    }
    else {
        # Os sinais fracos (arquivos esperando substituição, um serviço do Windows Update por registrar) aparecem em quase
        # todo PC e não pedem nada: numa linha só, em vez de um motivo técnico cada um.
        $strong = @($reasons | Where-Object { $_.Strong })
        $weak = @($reasons | Where-Object { -not $_.Strong })

        foreach ($reason in $strong) {
            Write-WinForgeStatus -Type Warning -Message "$($reason.Reason)."
        }

        if ($weak.Count -gt 0 -and $strong.Count -gt 0) {
            Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Também há sinais que aparecem em quase todo PC; sozinhos, eles não pedem reinício.')
        }

        Write-Host ""

        # Os mesmos motivos já lidos acima: Test-WinForgePendingReboot leria o Registro de novo.
        if (@($reasons | Where-Object { $_.Strong }).Count -gt 0) {
            Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'Reinicie o Windows antes de reparos, CHKDSK e instalações grandes.')

            # O ponto de atenção do Início e o aviso do monitor trazem a pessoa aqui: o que resolve é reiniciar, então a
            # tela oferece (com Não como padrão, e sem fechar nada à força), em vez de só explicar.
            try {
                if (Request-WinForgeRestart -Reason (Get-WinForgeText 'Reiniciar agora conclui o que está esperando o reinício.') -Comment (Get-WinForgeText 'Reinicialização solicitada pelo WinForge (reinício pendente).') -DeclinedMessage (Get-WinForgeText 'O PC não foi reiniciado. Reinicie quando puder.')) {
                    $result = New-WinForgeResult -Kind Ok -Detail (Get-WinForgeText 'o Windows está reiniciando')
                }
                else {
                    $result = New-WinForgeResult -Kind Warning -Detail (Get-WinForgeText 'reinício pendente; reinicie quando puder')
                }
            }
            catch {
                Write-WinForgeStatus -Type Error -Message (Get-WinForgeText 'Não foi possível pedir o reinício: {0}.' "$($_.Exception.Message.TrimEnd('.'))")
                $result = New-WinForgeResult -Kind Warning -Detail (Get-WinForgeText 'reinício pendente; reinicie pelo menu Iniciar')
            }
        }
        else {
            Write-WinForgeStatus -Type Success -Message (Get-WinForgeText 'Há só sinais que aparecem em quase todo PC: reiniciar não é obrigatório agora.')
            $result = New-WinForgeResult -Kind Ok -Detail (Get-WinForgeText 'nenhum reinício necessário')
        }
    }

    Exit-WinForgeAction -Result $result
}


function Get-WinForgeDiskHealthStatusText {
    # O estado geral que o Windows dá ao disco (HealthStatus), em português. Vem como nome (Healthy) ou como número (0).
    param (
        $Status
    )

    switch ([string]$Status) {
        { $_ -in @("Healthy", "0") } { return (Get-WinForgeText 'Saudável') }
        { $_ -in @("Warning", "1") } { return (Get-WinForgeText 'Atenção') }
        { $_ -in @("Unhealthy", "2") } { return (Get-WinForgeText 'Com defeito') }
        { $_ -in @("Unknown", "5", "") } { return (Get-WinForgeText 'Desconhecido') }
        default { return [string]$Status }
    }
}


function Get-WinForgeDiskHealthNotes {
    # Os alertas de um disco. Temperatura alta: 70 °C num SSD, 55 °C num HD (que trabalha mais frio) e 60 °C quando o
    # Windows não diz o tipo (um HD atrás de um controlador RAID, por exemplo). Desgaste só vale para SSD: num HD o
    # contador fica em zero.
    param (
        [Parameter(Mandatory)]
        $Disk
    )

    # Cada campo pelo nome, com padrão: um disco montado por outra parte (o relatório, um teste) pode não trazer todos.
    $notes = @()
    $type = [string](Get-WinForgeJsonValue -Object $Disk -Name "Type" -Default "")
    $healthStatus = Get-WinForgeJsonValue -Object $Disk -Name "HealthStatus" -Default ""
    $wear = Get-WinForgeJsonValue -Object $Disk -Name "Wear" -Default $null
    $temperature = Get-WinForgeJsonValue -Object $Disk -Name "Temperature" -Default $null
    $readErrors = Get-WinForgeJsonValue -Object $Disk -Name "ReadErrorsUncorrected" -Default $null
    $writeErrors = Get-WinForgeJsonValue -Object $Disk -Name "WriteErrorsUncorrected" -Default $null
    $isHdd = ($type -eq "HDD")
    $isSsd = ($type -in @("SSD", "NVMe"))

    # A previsão de falha do próprio disco (SMART), que o Windows mostra em OperationalStatus: "Predictive Failure", ou 5
    # quando vem como número. É o aviso mais direto de que o disco está no fim, e diz mais que o estado de atenção.
    $predictive = (@(@(Get-WinForgeJsonValue -Object $Disk -Name "OperationalStatus" -Default @()) | Where-Object { ([string]$_).Trim() -in @("Predictive Failure", "5") }).Count -gt 0)

    if ($predictive) { $notes += (Get-WinForgeText 'O próprio disco avisa que pode falhar em breve (SMART)') }

    switch (Get-WinForgeDiskHealthStatusText -Status $healthStatus) {
        (Get-WinForgeText 'Saudável') { }
        (Get-WinForgeText 'Desconhecido') { }
        (Get-WinForgeText 'Atenção') { if (-not $predictive) { $notes += (Get-WinForgeText 'O Windows marca este disco com estado de atenção') } }
        (Get-WinForgeText 'Com defeito') { $notes += (Get-WinForgeText 'O Windows marca este disco como com defeito') }
        default { $notes += (Get-WinForgeText 'Estado do disco: {0}' "$healthStatus") }
    }

    if (-not $isHdd -and $null -ne $wear -and [int]$wear -ge 80) {
        $notes += (Get-WinForgeText 'Desgaste {0} em {1}% da vida útil estimada' "$(if ($isSsd) { (Get-WinForgeText 'do SSD') } else { (Get-WinForgeText 'do disco') })" "$wear")
    }

    if ($null -ne $temperature -and [int]$temperature -ge $(if ($isHdd) { 55 } elseif ($isSsd) { 70 } else { 60 })) {
        $notes += (Get-WinForgeText 'Temperatura alta ({0} °C)' "$temperature")
    }

    if ($null -ne $readErrors -and [int64]$readErrors -gt 0) {
        $notes += (Get-WinForgeText 'Erros de leitura não corrigidos: {0}' "$readErrors")
    }

    if ($null -ne $writeErrors -and [int64]$writeErrors -gt 0) {
        $notes += (Get-WinForgeText 'Erros de escrita não corrigidos: {0}' "$writeErrors")
    }

    return @($notes)
}


function Test-WinForgeDiskFailing {
    <#
    Se o disco dá sinais de que pode falhar (o que o monitor na bandeja avisa): a previsão de falha do próprio disco
    (SMART), o estado de atenção ou de defeito que o Windows dá a ele, erros de leitura ou de escrita não corrigidos e, num
    SSD, 90% ou mais da vida útil gasta. Temperatura alta não entra: ela passa e não quer dizer que o disco vai falhar.
    #>
    param ([Parameter(Mandatory)]$Disk)

    return ((Get-WinForgeDiskFailingText -Disk $Disk) -ne "")
}


function Get-WinForgeDiskFailingText {
    # O sinal de falha mais forte do disco, numa frase curta ("" quando não há; veja Test-WinForgeDiskFailing).
    param ([Parameter(Mandatory)]$Disk)

    $status = [string](Get-WinForgeJsonValue -Object $Disk -Name "HealthStatus" -Default "")
    $type = [string](Get-WinForgeJsonValue -Object $Disk -Name "Type" -Default "")
    $wear = Get-WinForgeJsonValue -Object $Disk -Name "Wear" -Default $null
    $readErrors = Get-WinForgeJsonValue -Object $Disk -Name "ReadErrorsUncorrected" -Default $null
    $writeErrors = Get-WinForgeJsonValue -Object $Disk -Name "WriteErrorsUncorrected" -Default $null

    if (@(@(Get-WinForgeJsonValue -Object $Disk -Name "OperationalStatus" -Default @()) | Where-Object { ([string]$_).Trim() -in @("Predictive Failure", "5") }).Count -gt 0) {
        return (Get-WinForgeText 'o próprio disco avisa que pode falhar em breve')
    }

    if ($status -in @("Unhealthy", "2", "Warning", "1")) { return (Get-WinForgeText 'o Windows marca o disco com problema') }
    if (($null -ne $readErrors -and [int64]$readErrors -gt 0) -or ($null -ne $writeErrors -and [int64]$writeErrors -gt 0)) { return (Get-WinForgeText 'o disco teve erros de leitura ou de escrita') }
    if ($type -in @("SSD", "NVMe") -and $null -ne $wear -and [int]$wear -ge 90) { return (Get-WinForgeText 'o SSD está no fim da vida útil') }

    return ""
}


function Get-WinForgeDiskHealth {
    $result = @()

    try {
        # Os discos físicos: as instâncias de MSFT_PhysicalDisk, as mesmas que o Get-PhysicalDisk devolve, lidas com prazo,
        # como as outras leituras do WMI. O Get-PhysicalDisk é um script do módulo de armazenamento sem prazo nem -AsJob, e
        # um disco morrendo o deixava parado sem fim. Sem o módulo de armazenamento carregado, MediaType, BusType e
        # HealthStatus vêm como número: Get-WinForgeDiskTypeText e Get-WinForgeDiskHealthStatusText leem os dois jeitos.
        $physicalDisks = @(Get-CimInstance -Namespace "root/Microsoft/Windows/Storage" -ClassName "MSFT_PhysicalDisk" -OperationTimeoutSec 60 -ErrorAction Stop)
    }
    catch {
        return @()
    }

    # Na ordem do Gerenciamento de Disco (disco 0, 1, 2...): o Windows devolve os discos em qualquer ordem, e a tela
    # mudava de uma vez para outra. Sem número, no fim.
    $physicalDisks = @($physicalDisks | Sort-Object -Property @{ Expression = { $number = 0; if ([int]::TryParse([string](Get-WinForgeJsonValue -Object $_ -Name "DeviceId" -Default ""), [ref]$number)) { $number } else { [int]::MaxValue } } })

    # As letras de cada disco, numa consulta só (uma por disco custava uma ida ao serviço de armazenamento cada).
    $lettersByDisk = @{}

    # Com o serviço de armazenamento sem resposta (o prazo de uma leitura acabou), as outras leituras dele travariam igual,
    # cada uma por mais 60 segundos: as que faltam não são feitas, e os discos ficam com o estado geral (que já veio).
    $silent = $false

    try {
        foreach ($partition in @(Get-WinForgePartitionLetters)) {
            if (-not $lettersByDisk.ContainsKey($partition.Disk)) { $lettersByDisk[$partition.Disk] = @() }
            $lettersByDisk[$partition.Disk] += $partition.Drive
        }
    }
    catch {
        # Sem as partições, os discos ficam sem as letras.
        if ($_.Exception -is [System.TimeoutException]) { $silent = $true }
    }

    foreach ($physicalDisk in $physicalDisks) {
        $counter = $null
        $timedOut = $silent

        if (-not $silent) {
            try {
                $counter = @(Invoke-WinForgeCimCommand -Name "Get-StorageReliabilityCounter" -Parameters @{ PhysicalDisk = $physicalDisk })[0]
            }
            catch {
                # Alguns discos (USB, virtuais) não expõem contadores de confiabilidade; o tempo esgotado é outra coisa.
                if ($_.Exception -is [System.TimeoutException]) { $silent = $true; $timedOut = $true }
            }
        }

        $name = ([string]$physicalDisk.FriendlyName).Trim()
        $field = { param ($property) if ($counter -and $counter.PSObject.Properties[$property]) { $counter.$property } else { $null } }

        # Valores fora do possível são o que alguns adaptadores USB informam quando não sabem: 0 °C sem sensor, 128 ou
        # 255 °C, milhões de horas, desgaste acima de 100%. Mostrá-los seria inventar um dado (e um alerta). Um SSD
        # esquentando de verdade passa dos 100 °C: até 127 vale.
        $rawTemperature = & $field "Temperature"
        $temperature = $(if ($null -ne $rawTemperature -and [double]$rawTemperature -ge 1 -and [double]$rawTemperature -le 127) { [int]$rawTemperature } else { $null })
        $rawHours = & $field "PowerOnHours"
        # Zero hora num disco em uso é o "não sei" do adaptador, não um disco novo.
        $hours = $(if ($null -ne $rawHours -and [double]$rawHours -gt 0 -and [double]$rawHours -lt 150000) { $rawHours } else { $null })
        $rawWear = & $field "Wear"
        $wear = $(if ($null -ne $rawWear -and [double]$rawWear -ge 0 -and [double]$rawWear -le 100) { [int]$rawWear } else { $null })
        $readErrors = & $field "ReadErrorsUncorrected"
        $writeErrors = & $field "WriteErrorsUncorrected"
        $type = Get-WinForgeDiskTypeText -Disk $physicalDisk

        # Só num SSD o desgaste em zero quer dizer "novo"; num disco de tipo desconhecido, zero é o que um HD informa.
        if ($type -notin @("SSD", "NVMe") -and $wear -eq 0) { $wear = $null }

        # Os contadores só contam como lidos quando trazem algum dado: um objeto vazio (comum em gavetas USB e em
        # controladores RAID) não pode virar "Nenhum alerta".
        $reported = ($null -ne $temperature -or $null -ne $hours -or $null -ne $wear -or ($null -ne $readErrors -and [double]$readErrors -gt 0) -or ($null -ne $writeErrors -and [double]$writeErrors -gt 0))

        # As letras das unidades deste disco: "faça backup deste disco" precisa dizer qual é (C:, D:). Sem o número do
        # disco, nada: um valor vazio não pode virar o disco 0.
        $deviceId = [string](Get-WinForgeJsonValue -Object $physicalDisk -Name "DeviceId" -Default "")
        $drives = $(if ($deviceId -match '^[0-9]+$' -and $lettersByDisk.ContainsKey($deviceId)) { @($lettersByDisk[$deviceId] | Sort-Object -Unique) } else { @() })

        $disk = [PSCustomObject]@{
            Name                   = $(if ($name) { $name } else { (Get-WinForgeText 'Disco sem nome') })
            Type                   = $type
            SizeBytes              = $physicalDisk.Size
            HealthStatus           = $physicalDisk.HealthStatus
            OperationalStatus      = @(@(Get-WinForgeJsonValue -Object $physicalDisk -Name "OperationalStatus" -Default @()) | Where-Object { $null -ne $_ } | ForEach-Object { [string]$_ })
            Drives                 = @($drives)
            CountersAvailable      = $reported
            CountersTimedOut       = ($timedOut -and -not $reported)
            Temperature            = $temperature
            Wear                   = $wear
            PowerOnHours           = $hours
            ReadErrorsUncorrected  = $readErrors
            WriteErrorsUncorrected = $writeErrors
        }

        $disk | Add-Member -NotePropertyName Notes -NotePropertyValue @(Get-WinForgeDiskHealthNotes -Disk $disk)
        $result += $disk
    }

    return @($result)
}


function Show-WinForgeDiskHealth {
    Enter-WinForgeAction -Title (Get-WinForgeText 'Saúde dos discos')

    $disks = @(Get-WinForgeDiskHealth)

    if ($disks.Count -eq 0) {
        Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'Não foi possível ler a saúde dos discos: o Windows não respondeu. Tente de novo; se continuar, reinicie o PC.')
        Exit-WinForgeAction
        return
    }

    $isAdmin = Test-WinForgeAdministrator

    foreach ($disk in $disks) {
        $isHdd = ($disk.Type -eq "HDD")
        $status = Get-WinForgeDiskHealthStatusText -Status $disk.HealthStatus
        $drives = @(Get-WinForgeJsonValue -Object $disk -Name "Drives" -Default @())
        $errorText = { param ($value) if ($null -ne $value) { [string][int64]$value } else { (Get-WinForgeText 'não informado') } }

        Write-WinForgeSection -Title "$($disk.Name) ($($disk.Type), $(Format-WinForgeBytes -Bytes $disk.SizeBytes -ZeroText (Get-WinForgeText 'tamanho desconhecido')))"
        if ($drives.Count -gt 0) { Write-WinForgeKeyValue -Label (Get-WinForgeText 'Unidades') -Value ($drives -join ", ") }
        Write-WinForgeKeyValue -Label (Get-WinForgeText 'Estado') -Value $status -Level $(switch ($status) { (Get-WinForgeText 'Saudável') { "Ok" } (Get-WinForgeText 'Atenção') { "Warn" } (Get-WinForgeText 'Com defeito') { "Bad" } default { "Normal" } })
        Write-WinForgeKeyValue -Label (Get-WinForgeText 'Temperatura') -Value $(if ($null -ne $disk.Temperature) { "$($disk.Temperature) °C" } else { $null })
        Write-WinForgeKeyValue -Label (Get-WinForgeText 'Desgaste') -Value $(if ($isHdd) { (Get-WinForgeText 'Não se aplica (HDD)') } elseif ($null -ne $disk.Wear) { (Get-WinForgeText '{0}% da vida útil estimada' "$($disk.Wear)") } else { $null })
        Write-WinForgeKeyValue -Label (Get-WinForgeText 'Horas ligado') -Value $(if ($null -eq $disk.PowerOnHours) { $null } elseif ([double]$disk.PowerOnHours -eq 1) { (Get-WinForgeText '1 hora') } else { (Get-WinForgeText '{0} horas' "$(Format-WinForgeNumber -Value ([double]$disk.PowerOnHours))") })
        Write-WinForgeKeyValue -Label (Get-WinForgeText 'Erros não corrigidos') -Value $(if ($null -ne $disk.ReadErrorsUncorrected -or $null -ne $disk.WriteErrorsUncorrected) { (Get-WinForgeText '{0} de leitura, {1} de escrita' "$(& $errorText $disk.ReadErrorsUncorrected)" "$(& $errorText $disk.WriteErrorsUncorrected)") } else { $null })

        Write-Host ""

        if ($disk.Notes.Count -gt 0) {
            foreach ($note in $disk.Notes) {
                Write-WinForgeStatus -Type Warning -Message "$note."
            }

            # Estado ruim, erros ou desgaste: o que fazer antes de qualquer outra coisa é guardar os arquivos. A nota da
            # temperatura é comparada inteira, no idioma da tela (o começo "Temperatura" só existe em português).
            $heatNote = $(if ($null -ne $disk.Temperature) { (Get-WinForgeText 'Temperatura alta ({0} °C)' "$($disk.Temperature)") } else { "" })

            if (@($disk.Notes | Where-Object { [string]$_ -ne $heatNote }).Count -gt 0) {
                Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Faça backup dos arquivos importantes deste disco{0}.' "$(if ($drives.Count -gt 0) { " ($(Join-WinForgeList -Items $drives))" })")
            }
            else {
                Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Confira a ventilação do gabinete ou do notebook.')
            }
        }
        elseif ($disk.CountersAvailable) {
            Write-WinForgeStatus -Type Success -Message (Get-WinForgeText 'Nenhum alerta para este disco.')
        }
        elseif ([bool](Get-WinForgeJsonValue -Object $disk -Name "CountersTimedOut" -Default $false)) {
            # O Windows não respondeu: dizer que o disco "não expõe contadores" (como num USB) seria um palpite errado. A
            # frase vem uma vez, no fim, para todos os discos nessa situação.
        }
        elseif ($status -eq (Get-WinForgeText 'Desconhecido')) {
            Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Este disco não informou o estado nem os contadores de confiabilidade; não há como avaliá-lo por aqui.')
        }
        elseif ($isAdmin) {
            # Sem contadores só o estado geral foi avaliado; "nenhum alerta" prometeria mais do que a leitura fez.
            Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Este disco não expõe contadores de confiabilidade (comum em discos USB e virtuais); só o estado geral foi avaliado.')
        }
        else {
            Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Os contadores deste disco não puderam ser lidos (exigem Administrador, e discos USB e virtuais nem sempre os têm); só o estado geral foi avaliado.')
        }
    }

    Write-Host ""

    $late = @($disks | Where-Object { $_.Notes.Count -eq 0 -and [bool](Get-WinForgeJsonValue -Object $_ -Name "CountersTimedOut" -Default $false) })

    if ($late.Count -gt 0) {
        Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'O Windows não respondeu a tempo sobre os contadores de {0}: só o estado geral foi avaliado. Tente de novo; se continuar, reinicie o PC.' "$(Join-WinForgeList -Items @($late | ForEach-Object { $_.Name }))")
    }

    Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Isto lê o que o próprio Windows sabe do disco; o programa do fabricante do disco faz um teste mais completo.')

    # A faixa de resultado: quantos discos têm alerta, ou que nenhum tem (e se algum foi avaliado só pelo estado geral).
    $alerted = @($disks | Where-Object { $_.Notes.Count -gt 0 })
    $partial = @($disks | Where-Object { $_.Notes.Count -eq 0 -and -not $_.CountersAvailable })
    $result = $null

    if ($alerted.Count -gt 0) {
        $names = @($alerted | ForEach-Object { $letters = @(Get-WinForgeJsonValue -Object $_ -Name "Drives" -Default @()); if ($letters.Count -gt 0) { "$($_.Name) ($($letters -join ', '))" } else { $_.Name } })
        $result = New-WinForgeResult -Kind Warning -Detail (Get-WinForgeText '{0} com alerta: {1}' "$(Format-WinForgeCount -Count $alerted.Count -One (Get-WinForgeText 'disco') -Many (Get-WinForgeText 'discos'))" "$(Join-WinForgeList -Items $names)")
    }
    elseif ($partial.Count -eq 0) {
        $result = New-WinForgeResult -Kind Ok -Detail (Get-WinForgeText 'nenhum alerta {0}' "$(if ($disks.Count -eq 1) { (Get-WinForgeText 'no disco') } else { (Get-WinForgeText 'nos {0} discos' "$($disks.Count)") })")
    }
    elseif ($partial.Count -lt $disks.Count) {
        $result = New-WinForgeResult -Kind Ok -Detail (Get-WinForgeText 'nenhum alerta; {0} só pelo estado geral' "$(Format-WinForgeCount -Count $partial.Count -One (Get-WinForgeText 'disco foi avaliado') -Many (Get-WinForgeText 'discos foram avaliados'))")
    }

    Exit-WinForgeAction -Result $result
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
        $Cycles = $null,

        # O relatório marca quando as capacidades não estão em mWh (RelativeCapacity): a saúde continua valendo (é uma
        # razão), mas "Wh" seria um número sem sentido.
        [bool]$Relative = $false
    )

    # 0 e 4294967295 (0xFFFFFFFF) são o que muitos firmwares informam quando não sabem a capacidade: valem como "não
    # informado", senão viram uma saúde de 0% ou uma conta absurda.
    $unknownCapacity = { param ($value) $null -eq $value -or [double]$value -le 0 -or [double]$value -ge 4294967295 }

    if (& $unknownCapacity $DesignMwh) { $DesignMwh = $null }
    if (& $unknownCapacity $FullMwh) { $FullMwh = $null }

    $health = $null

    if ($null -ne $DesignMwh -and $null -ne $FullMwh) {
        # [double] nos dois lados: com um inteiro na frente, o PowerShell escolheria o Min de Int32 e truncaria a conta.
        $health = [int][math]::Min([double]100, [math]::Round(([double]$FullMwh / [double]$DesignMwh) * 100))
    }

    # Muitos notebooks informam 0 ciclos quando o firmware não conta: mostrar "0" seria dizer que a bateria é nova.
    $cycleCount = $null
    $parsedCycles = [int64]0

    if ($null -ne $Cycles -and [int64]::TryParse(([string]$Cycles).Trim(), [ref]$parsedCycles) -and $parsedCycles -gt 0) {
        $cycleCount = $parsedCycles
    }

    return [PSCustomObject]@{
        Name          = $Name
        DesignMwh     = $DesignMwh
        FullMwh       = $FullMwh
        Cycles        = $cycleCount
        HealthPercent = $health
        Relative      = $Relative
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

        # O identificador sozinho já diz o fabricante quando o contém ("SMP-1234"); com duas baterias do mesmo fabricante,
        # ficar só com o fabricante as deixaria iguais. IndexOf em vez de -like: [ ] e * no nome seriam curingas.
        if ($name -and $id) {
            if ($id.IndexOf($name, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) { $name = $id }
            else { $name = "$name $id" }
        }
        elseif (-not $name) { $name = $id }

        $readings += New-WinForgeBatteryReading `
            -Name $name `
            -DesignMwh (Get-WinForgeXmlChildNumber -Node $node -Name "DesignCapacity") `
            -FullMwh (Get-WinForgeXmlChildNumber -Node $node -Name "FullChargeCapacity") `
            -Cycles (Get-WinForgeXmlChildNumber -Node $node -Name "CycleCount") `
            -Relative ([string](Get-WinForgeXmlChildText -Node $node -Name "RelativeCapacity") -in @("1", "true"))
    }

    return @($readings)
}


function Get-WinForgeBatteryWmiReadings {
    # Plano B quando o relatório do powercfg não está disponível: as classes de bateria do WMI (root\wmi).
    $static = @()
    $full = @()
    $cycles = @()

    try {
        $static = @(Get-CimInstance -Namespace "root\wmi" -ClassName "BatteryStaticData" -OperationTimeoutSec 15 -ErrorAction Stop)
        $full = @(Get-CimInstance -Namespace "root\wmi" -ClassName "BatteryFullChargedCapacity" -OperationTimeoutSec 15 -ErrorAction Stop)
        $cycles = @(Get-CimInstance -Namespace "root\wmi" -ClassName "BatteryCycleCount" -OperationTimeoutSec 15 -ErrorAction SilentlyContinue)
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
            -Cycles $(if ($cycleEntry) { $cycleEntry.CycleCount } else { $null })
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
        $HealthPercent,

        # Qual capacidade faltou, quando a saúde não pôde ser calculada: "design" (a de fábrica) ou "full" (a de hoje).
        [ValidateSet("design", "full")][string]$Missing = "design"
    )

    if ($null -eq $HealthPercent) {
        $what = $(if ($Missing -eq "full") { (Get-WinForgeText 'a capacidade de hoje') } else { (Get-WinForgeText 'a capacidade de fábrica') })
        return [PSCustomObject]@{ Level = "Info"; Text = (Get-WinForgeText 'O Windows não informou {0}; não dá para calcular o desgaste.' "$what") }
    }

    if ([int]$HealthPercent -ge 80) {
        return [PSCustomObject]@{ Level = "Success"; Text = (Get-WinForgeText 'Bateria em bom estado: segura {0}% da carga de quando era nova.' "$HealthPercent") }
    }

    if ([int]$HealthPercent -ge 60) {
        return [PSCustomObject]@{ Level = "Info"; Text = (Get-WinForgeText 'Desgaste moderado: segura {0}% da carga original, então a autonomia já caiu.' "$HealthPercent") }
    }

    return [PSCustomObject]@{ Level = "Warning"; Text = (Get-WinForgeText 'Desgaste alto: segura só {0}% da carga original. Vale considerar a troca da bateria.' "$HealthPercent") }
}


function ConvertTo-WinForgeBatteryPercent {
    # A carga, de 0 a 100. Alguns drivers informam 255 (ou outro valor fora da faixa) quando não sabem: vira $null.
    param (
        $Value
    )

    $number = 0

    if ($null -ne $Value -and [int]::TryParse(([string]$Value).Trim(), [ref]$number) -and $number -ge 0 -and $number -le 100) {
        return $number
    }

    return $null
}


function Get-WinForgeBatteryState {
    # Carga e situação atuais, do Win32_Battery (código BatteryStatus: 1 descarregando, 2 na tomada, 3 cheia, 4 baixa,
    # 5 crítica, 6 a 9 carregando, 11 parcialmente carregada). Com duas baterias (alguns ThinkPad), a carga é a média das
    # duas e a situação é a de quem trabalha: carregando ou usando a bateria vence "na tomada". State é o texto e Code a
    # situação para comparar (Charging, Battery, AC ou ""), que não depende do idioma. Falha na consulta = $null.
    try {
        $batteries = @(Get-CimInstance -ClassName "Win32_Battery" -OperationTimeoutSec 15 -ErrorAction Stop | Where-Object { $null -ne $_ })
    }
    catch {
        return $null
    }

    if ($batteries.Count -eq 0) {
        return $null
    }

    $codes = @($batteries | ForEach-Object { [int]$_.BatteryStatus })
    $state = ""
    $code = ""

    if (@($codes | Where-Object { $_ -in 6, 7, 8, 9 }).Count -gt 0) { $state = (Get-WinForgeText 'Carregando'); $code = "Charging" }
    elseif (@($codes | Where-Object { $_ -in 1, 4, 5 }).Count -gt 0) { $state = (Get-WinForgeText 'Usando a bateria'); $code = "Battery" }
    elseif (@($codes | Where-Object { $_ -in 2, 3, 11 }).Count -gt 0) { $state = (Get-WinForgeText 'Na tomada'); $code = "AC" }

    $charges = @($batteries | ForEach-Object { ConvertTo-WinForgeBatteryPercent -Value $_.EstimatedChargeRemaining } | Where-Object { $null -ne $_ })
    $charge = $(if ($charges.Count -gt 0) { [int][math]::Round((($charges | Measure-Object -Average).Average)) } else { $null })

    # Com duas baterias de tamanhos diferentes, a média simples erra (uma de 23 Wh cheia e uma de 72 Wh em 20% não são
    # 60%): a carga do conjunto é o que resta somado sobre o total somado, quando o Windows informa os dois.
    if ($batteries.Count -gt 1) {
        try {
            $remaining = [double]0
            $full = [double]0
            foreach ($item in @(Get-CimInstance -Namespace "root\wmi" -ClassName "BatteryStatus" -OperationTimeoutSec 15 -ErrorAction Stop)) { $remaining += [double](Get-WinForgeJsonValue -Object $item -Name "RemainingCapacity" -Default 0) }
            foreach ($item in @(Get-CimInstance -Namespace "root\wmi" -ClassName "BatteryFullChargedCapacity" -OperationTimeoutSec 15 -ErrorAction Stop)) { $full += [double](Get-WinForgeJsonValue -Object $item -Name "FullChargedCapacity" -Default 0) }

            if ($remaining -ge 0 -and $full -gt 0 -and $remaining -le $full * 1.05) {
                $charge = [int][math]::Min(100, [math]::Round(($remaining / $full) * 100))
            }
        }
        catch {
            # Fica a média.
        }
    }

    return [PSCustomObject]@{ ChargePercent = $charge; State = $state; Code = $code; Count = $batteries.Count }
}


function Get-WinForgeBatteryInfo {
    # Tudo o que a tela e o relatório mostram. Present = $false em desktops e máquinas sem bateria; Ups = $true num
    # computador de mesa em que o Windows vê uma bateria (um nobreak USB): ela não é a bateria de um notebook.
    $state = Get-WinForgeBatteryState

    if ($null -eq $state) {
        return [PSCustomObject]@{ Present = $false; Ups = $false; State = $null; Readings = @(); Source = "" }
    }

    if (-not (Test-WinForgeLaptop)) {
        return [PSCustomObject]@{ Present = $false; Ups = $true; State = $null; Readings = @(); Source = "" }
    }

    $found = Get-WinForgeBatteryReadings

    return [PSCustomObject]@{ Present = $true; Ups = $false; State = $state; Readings = @($found.Readings); Source = $found.Source }
}


function Format-WinForgeWattHours {
    # mWh em Wh, com uma casa ("45,6 Wh"): uma bateria de 50 Wh perdendo 0,4 Wh não pode parecer igual.
    param ($MilliwattHours)

    if ($null -eq $MilliwattHours) {
        return $null
    }

    return "$(Format-WinForgeNumber -Value ([math]::Round([double]$MilliwattHours / 1000, 1)) -Decimals 1) Wh"
}


function Show-WinForgeBatteryHealth {
    Enter-WinForgeAction -Title (Get-WinForgeText 'Saúde da bateria')

    # Uma saída só (Exit-WinForgeAction no fim): sair de dentro do try faria um erro na espera da tecla ser tratado
    # como erro da bateria, com uma segunda espera.
    $result = $null

    try {
        $info = Get-WinForgeBatteryInfo

        if (-not $info.Present -and [bool](Get-WinForgeJsonValue -Object $info -Name "Ups" -Default $false)) {
            Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Este PC se identifica como um computador de mesa: a bateria que o Windows enxerga deve ser a de um nobreak (UPS). O estado dela fica no programa do fabricante do nobreak.')
        }
        elseif (-not $info.Present) {
            Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Este computador não tem bateria (ou o Windows não consegue enxergá-la).')
        }
        else {
            Write-WinForgeSection -Title (Get-WinForgeText 'Agora')
            Write-WinForgeKeyValue -Label (Get-WinForgeText 'Carga') -Value $(if ($null -ne $info.State.ChargePercent) { "$($info.State.ChargePercent)%" } else { $null })
            Write-WinForgeKeyValue -Label (Get-WinForgeText 'Situação') -Value $info.State.State

            $readings = @($info.Readings)

            if ($readings.Count -eq 0) {
                Write-Host ""
                Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'O Windows não informou a capacidade da bateria. Alguns notebooks não expõem esses dados.')
            }
            else {
                $levels = @()

                foreach ($reading in $readings) {
                    $title = (Get-WinForgeText 'Capacidade')
                    if (-not [string]::IsNullOrWhiteSpace($reading.Name)) { $title += ": $($reading.Name)" }

                    Write-WinForgeSection -Title $title

                    if (-not [bool](Get-WinForgeJsonValue -Object $reading -Name "Relative" -Default $false)) {
                        Write-WinForgeKeyValue -Label (Get-WinForgeText 'Capacidade de fábrica') -Value (Format-WinForgeWattHours -MilliwattHours $reading.DesignMwh)
                        Write-WinForgeKeyValue -Label (Get-WinForgeText 'Capacidade hoje') -Value (Format-WinForgeWattHours -MilliwattHours $reading.FullMwh)
                    }

                    Write-WinForgeKeyValue -Label (Get-WinForgeText 'Saúde') -Value $(if ($null -ne $reading.HealthPercent) { "$($reading.HealthPercent)%" } else { $null })
                    Write-WinForgeKeyValue -Label (Get-WinForgeText 'Ciclos de carga') -Value $(if ($null -ne $reading.Cycles) { Format-WinForgeNumber -Value ([double]$reading.Cycles) } else { $null })

                    $assessment = Get-WinForgeBatteryAssessment -HealthPercent $reading.HealthPercent -Missing $(if ($null -ne $reading.DesignMwh -and $null -eq $reading.FullMwh) { "full" } else { "design" })
                    $levels += $assessment.Level

                    Write-Host ""
                    Write-WinForgeStatus -Type $assessment.Level -Message $assessment.Text
                }

                Write-Host ""
                Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'A bateria perde capacidade com o uso e com o calor; isso é normal. O valor é uma estimativa do próprio Windows.')

                # A faixa: o pior veredito entre as baterias. Desgaste moderado ou desconhecido não tem veredito.
                $worst = @($readings | Where-Object { $null -ne $_.HealthPercent } | Sort-Object { [int]$_.HealthPercent } | Select-Object -First 1)

                if ($levels -contains "Warning") {
                    $result = New-WinForgeResult -Kind Warning -Detail (Get-WinForgeText 'desgaste alto: a bateria segura só {0}% da carga original' "$($worst[0].HealthPercent)")
                }
                elseif (@($levels | Where-Object { $_ -ne "Success" }).Count -eq 0) {
                    $result = New-WinForgeResult -Kind Ok -Detail (Get-WinForgeText 'bateria em bom estado ({0}% da carga de quando era nova)' "$($worst[0].HealthPercent)")
                }
            }
        }
    }
    catch {
        Write-WinForgeStatus -Type Error -Message (Get-WinForgeText 'Ocorreu um erro ao consultar a bateria: {0}' "$($_.Exception.Message)")
        $result = $null
    }

    Exit-WinForgeAction -Result $result
}


function Get-WinForgeEventHint {
    param (
        [string]$Provider,
        [int]$Id
    )

    # O NTFS aparece com os dois nomes, conforme a versão do Windows.
    $key = "$(([string]$Provider) -replace '^Microsoft-Windows-Ntfs$', 'Ntfs')|$Id"

    switch -Wildcard ($key) {
        "Microsoft-Windows-Kernel-Power|41"          { return (Get-WinForgeText 'Reinício inesperado: o PC desligou sem passar pelo Windows (botão de ligar segurado, queda de energia, travamento ou superaquecimento).') }
        "EventLog|6008"                               { return (Get-WinForgeText 'Reinício inesperado: o Windows não foi desligado direito da última vez (queda de energia, travamento ou botão de ligar segurado).') }
        "Microsoft-Windows-WHEA-Logger|*"             { return (Get-WinForgeText 'O processador, a memória ou uma placa informou um erro de hardware. Se voltar a acontecer, pode ser calor, uma peça com defeito ou uma configuração acelerada (overclock).') }
        "disk|7"                                      { return (Get-WinForgeText 'O disco tem uma parte com defeito (setor danificado). Faça backup e veja Diagnóstico > Saúde dos discos.') }
        "disk|11"                                     { return (Get-WinForgeText 'Falha na ligação com o disco (cabo ou controladora). Veja Diagnóstico > Saúde dos discos.') }
        "disk|51"                                     { return (Get-WinForgeText 'O disco demorou a responder. Veja Diagnóstico > Saúde dos discos.') }
        "disk|153"                                    { return (Get-WinForgeText 'O disco precisou repetir uma leitura. Veja Diagnóstico > Saúde dos discos.') }
        "Ntfs|55"                                     { return (Get-WinForgeText 'Corrupção no sistema de arquivos: o Windows achou dados danificados no disco. Use Reparo > Verificar o sistema de arquivos (CHKDSK).') }
        "Ntfs|98"                                     { return (Get-WinForgeText 'O Windows achou erro na organização do disco. Use Reparo > Verificar o sistema de arquivos (CHKDSK).') }
        "Microsoft-Windows-WER-SystemErrorReporting|1001" { return (Get-WinForgeText 'Tela azul registrada (o Windows parou com um erro grave e reiniciou). A causa provável está em Diagnóstico > Telas azuis.') }
        "Display|4101"                                { return (Get-WinForgeText 'O driver de vídeo parou de responder e foi recuperado.') }
        "Service Control Manager|700?"                { return (Get-WinForgeText 'Falha ao iniciar um serviço do Windows.') }
        "Service Control Manager|7023"                { return (Get-WinForgeText 'Um serviço terminou com erro.') }
        "Service Control Manager|7031"                { return (Get-WinForgeText 'Um serviço terminou inesperadamente.') }
        "Service Control Manager|7034"                { return (Get-WinForgeText 'Um serviço terminou inesperadamente.') }
        # Erros que quase todo PC registra e que, sem explicação, pareciam defeito: um componente do Windows que demorou
        # a responder (DCOM), uma conexão segura recusada por um site ou serviço (Schannel) e uma atualização que falhou
        # (o Windows Update tenta de novo sozinho).
        "Microsoft-Windows-DistributedCOM|*"          { return (Get-WinForgeText 'Um componente do Windows (DCOM) não respondeu a tempo ou não pôde iniciar.') }
        "Schannel|*"                                  { return (Get-WinForgeText 'Uma conexão segura (TLS) com um site ou serviço foi recusada.') }
        "Microsoft-Windows-WindowsUpdateClient|20"    { return (Get-WinForgeText 'Uma atualização do Windows não foi instalada.') }
        default                                       { return "" }
    }
}


function Get-WinForgeEventNote {
    # O que vem depois de uma causa conhecida que não pede atenção: quase sempre, que ela é comum e não tem consequência;
    # na atualização que falhou, o que fazer se ela continuar falhando.
    param ([string]$Provider, [int]$Id)

    if ("$Provider|$Id" -eq "Microsoft-Windows-WindowsUpdateClient|20") { return (Get-WinForgeText 'o Windows tenta de novo; se continuar, use Atualizações > Corrigir o Windows Update') }

    return (Get-WinForgeText 'comum e quase sempre sem consequência')
}


function Test-WinForgeEventHintSerious {
    <#
    Se a causa conhecida de um grupo de eventos pede atenção. Serviços que falham ao iniciar ou param (7000 a 7034), o
    driver de vídeo que se recuperou sozinho (4101), o DCOM, as conexões seguras recusadas (Schannel) e a atualização que
    falhou (o Windows Update tenta de novo) aparecem na maioria dos PCs saudáveis: a tela os explica, sem alarme.
    #>
    param (
        [string]$Provider,
        [int]$Id
    )

    if ([string]$Provider -in @("Service Control Manager", "Microsoft-Windows-DistributedCOM", "Schannel", "Microsoft-Windows-WindowsUpdateClient")) { return $false }
    if ([string]$Provider -eq "Display" -and $Id -eq 4101) { return $false }

    return [bool](Get-WinForgeEventHint -Provider $Provider -Id $Id)
}


function Get-WinForgeEventCause {
    # O que um grupo de eventos conta como causa, para não contar duas vezes o mesmo acontecimento: um desligamento
    # inesperado registra o Kernel-Power 41 e o EventLog 6008 juntos.
    param ([string]$Provider, [int]$Id)

    if (("$Provider|$Id") -in @("Microsoft-Windows-Kernel-Power|41", "EventLog|6008")) { return "desligamento-inesperado" }

    return "$Provider|$Id"
}


function Get-WinForgeEventCauseName {
    # O nome curto de uma causa séria, para a frase do veredito ("2 problemas sérios: reinício inesperado e tela azul").
    # Os eventos do mesmo assunto têm o mesmo nome (os quatro do disco são "erro de disco") e contam uma vez.
    param ([string]$Provider, [int]$Id)

    $key = "$(([string]$Provider) -replace '^Microsoft-Windows-Ntfs$', 'Ntfs')|$Id"

    switch -Wildcard ($key) {
        "Microsoft-Windows-Kernel-Power|41" { return (Get-WinForgeText 'reinício inesperado') }
        "EventLog|6008" { return (Get-WinForgeText 'reinício inesperado') }
        "Microsoft-Windows-WHEA-Logger|*" { return (Get-WinForgeText 'erro de hardware') }
        "disk|*" { return (Get-WinForgeText 'erro de disco') }
        "Ntfs|*" { return (Get-WinForgeText 'erro no sistema de arquivos') }
        "Microsoft-Windows-WER-SystemErrorReporting|1001" { return (Get-WinForgeText 'tela azul') }
    }

    return (Get-WinForgeEventCause -Provider $Provider -Id $Id)
}


function Get-WinForgeEventProviderText {
    # A origem de um evento sem o prefixo "Microsoft-Windows-", que só alonga a linha ("Kernel-Power", "DistributedCOM").
    param (
        [AllowEmptyString()][string]$Provider = ""
    )

    $text = ($Provider -replace '^Microsoft-Windows-', '').Trim()

    return $(if ($text) { $text } else { (Get-WinForgeText 'Origem desconhecida') })
}


function Format-WinForgeEventOccurrences {
    # "1 vez, em 23/10 05:37" ou "3 vezes, a última em 23/10 05:37" (a tela e o relatório usam a mesma frase).
    param (
        [Parameter(Mandatory)]
        $Entry
    )

    $count = [int]$Entry.Count
    $times = $(if ($count -eq 1) { (Get-WinForgeText '1 vez') } else { (Get-WinForgeText '{0} vezes' "$(Format-WinForgeNumber -Value $count)") })

    if (-not ($Entry.Last -is [datetime])) {
        return $times
    }

    $when = Format-WinForgeDateTime -When $Entry.Last -Pattern (Get-WinForgeText 'dd/MM HH:mm')

    return $(if ($count -eq 1) { (Get-WinForgeText '{0}, em {1}' "$times" "$when") } else { (Get-WinForgeText '{0}, a última em {1}' "$times" "$when") })
}


function ConvertTo-WinForgeEventSummary {
    <#
    Agrupa os eventos por origem e ID numa passada só: contagem, horário do mais recente e dica. Primeiro vêm os grupos
    com dica (causa conhecida), depois os mais frequentes e, no empate, os mais recentes.
    #>
    param (
        [object[]]$Events,
        [int]$Top = 12
    )

    $byKey = [ordered]@{}

    foreach ($event in @($Events)) {
        if ($null -eq $event) {
            continue
        }

        $id = [int]$event.Id
        $key = "$($event.ProviderName)|$id"
        $entry = $byKey[$key]

        if ($null -eq $entry) {
            $byKey[$key] = [PSCustomObject]@{ Count = 1; Provider = [string]$event.ProviderName; Id = $id; Last = $event.TimeCreated; Hint = "" }
            continue
        }

        $entry.Count++

        if ($event.TimeCreated -gt $entry.Last) {
            $entry.Last = $event.TimeCreated
            $entry.Provider = [string]$event.ProviderName
        }
    }

    $summary = @($byKey.Values)

    foreach ($entry in $summary) {
        $entry.Hint = Get-WinForgeEventHint -Provider $entry.Provider -Id $entry.Id
        Add-Member -InputObject $entry -NotePropertyName Serious -NotePropertyValue (Test-WinForgeEventHintSerious -Provider $entry.Provider -Id $entry.Id) -Force
    }

    # Primeiro o que pede atenção, depois o que tem explicação, depois o resto; em cada parte, os mais frequentes.
    return @($summary |
        Sort-Object @{ Expression = { if ($_.Serious) { 0 } elseif ($_.Hint) { 1 } else { 2 } } }, @{ Expression = "Count"; Descending = $true }, @{ Expression = "Last"; Descending = $true } |
        Select-Object -First $Top)
}


function Read-WinForgeEventLog {
    <#
    Lê um log do Windows com uma consulta XPath, do mais novo para o mais antigo, até MaxEvents registros. Devolve só
    ProviderName, Id e TimeCreated: o Get-WinEvent monta o texto de cada evento (a parte lenta, que consulta as DLLs de
    mensagens de cada origem) mesmo quando ninguém o usa. Log sem eventos devolve lista vazia; falha de leitura é lançada.
    #>
    param (
        [Parameter(Mandatory)][string]$LogName,
        [Parameter(Mandatory)][string]$XPath,
        [int]$MaxEvents = 3000
    )

    $query = New-Object System.Diagnostics.Eventing.Reader.EventLogQuery($LogName, [System.Diagnostics.Eventing.Reader.PathType]::LogName, $XPath)
    $query.ReverseDirection = $true

    $reader = New-Object System.Diagnostics.Eventing.Reader.EventLogReader($query)
    $events = New-Object System.Collections.Generic.List[object]

    try {
        while ($events.Count -lt $MaxEvents) {
            $record = $reader.ReadEvent()

            if ($null -eq $record) { break }

            # Cada registro guarda um identificador do Windows: liberado já, e não quando o coletor de lixo passar.
            try {
                $events.Add([PSCustomObject]@{ ProviderName = [string]$record.ProviderName; Id = [int]$record.Id; TimeCreated = $record.TimeCreated; RecordId = $record.RecordId })
            }
            finally {
                $record.Dispose()
            }
        }
    }
    finally {
        $reader.Dispose()
    }

    # Sem a vírgula: com ela, a lista chegava a quem chama como um item só (uma lista dentro da lista), e a tela
    # contava um evento sem nome com o log vazio.
    return $events.ToArray()
}


function Get-WinForgeRecentCriticalEvents {
    <#
    Eventos de nível Crítico e Erro do log do Sistema nos últimos dias. Log sem eventos devolve lista vazia; qualquer
    outra falha de leitura (serviço do log parado, acesso negado, RPC) é lançada, para quem chama não confundir "não consegui
    ler" com "não há nada".
    #>
    param (
        [int]$Days = 7,

        # Limite de leitura: um log muito barulhento não deve travar a tela. Quem mostra o total avisa se chegou nele.
        [int]$MaxEvents = 3000
    )

    # Nível 1 = Crítico, 2 = Erro; timediff conta, em milissegundos, quanto tempo faz que o evento aconteceu. Do nível
    # Aviso (3), só os que dizem algo do hardware: o disco que repetiu ou não conseguiu paginar (51, 153) e o driver de
    # vídeo que parou e voltou (4101). Sem eles, um disco começando a falhar passava por "nenhum evento".
    $window = [int64]([TimeSpan]::FromDays($Days).TotalMilliseconds)
    $warnings = "(Level=3 and ((Provider[@Name='disk'] and (EventID=51 or EventID=153)) or (Provider[@Name='Display'] and EventID=4101)))"
    $xpath = "*[System[((Level=1 or Level=2) or $warnings) and TimeCreated[timediff(@SystemTime) <= $window]]]"

    # Desembrulha uma lista que chegue dentro de outra (um item só que é a lista inteira).
    $events = @(Read-WinForgeEventLog -LogName "System" -XPath $xpath -MaxEvents $MaxEvents | ForEach-Object { $_ })

    # Um serviço com defeito pode encher o limite de leitura em poucas horas e empurrar para fora o desligamento
    # inesperado de ontem: com o limite cheio, uma segunda leitura, curta, só das origens que têm causa conhecida.
    if ($events.Count -ge $MaxEvents) {
        $known = "Provider[@Name='Microsoft-Windows-Kernel-Power' or @Name='EventLog' or @Name='Microsoft-Windows-WHEA-Logger' or @Name='disk' or @Name='Ntfs' or @Name='Microsoft-Windows-Ntfs' or @Name='Microsoft-Windows-WER-SystemErrorReporting' or @Name='Display']"
        $knownXPath = "*[System[$known and ((Level=1 or Level=2) or $warnings) and TimeCreated[timediff(@SystemTime) <= $window]]]"
        $seen = @{}

        foreach ($event in $events) {
            $recordId = Get-WinForgeJsonValue -Object $event -Name "RecordId" -Default $null
            if ($null -ne $recordId) { $seen[[string]$recordId] = $true }
        }

        $extra = @(Read-WinForgeEventLog -LogName "System" -XPath $knownXPath -MaxEvents 500 | ForEach-Object { $_ } | Where-Object {
                $recordId = Get-WinForgeJsonValue -Object $_ -Name "RecordId" -Default $null
                $null -eq $recordId -or -not $seen.ContainsKey([string]$recordId)
            })

        $events = @($events) + @($extra)
    }

    return @($events)
}


function Show-WinForgeCriticalEvents {
    $title = (Get-WinForgeText 'Eventos críticos (7 dias)')
    Enter-WinForgeAction -Title $title

    $maxEvents = 3000
    $shownGroups = 12

    # O andamento vai na barra: uma linha "Lendo..." ficaria no resumo depois do fim.
    Write-Progress -Activity $title -Status (Get-WinForgeText 'lendo os registros de erro do Windows')

    try {
        $events = @(Get-WinForgeRecentCriticalEvents -Days 7 -MaxEvents $maxEvents | ForEach-Object { $_ })
    }
    catch {
        Write-Progress -Activity $title -Completed
        Write-Host ""
        Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'Não foi possível ler o log do Sistema: {0}' "$($_.Exception.Message)")
        Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Isto não quer dizer que não haja eventos. Abra o Visualizador de Eventos (eventvwr.msc) para conferir.')
        Exit-WinForgeAction
        return
    }

    Write-Progress -Activity $title -Completed

    $groups = @(ConvertTo-WinForgeEventSummary -Events $events -Top ([int]::MaxValue))
    $summary = @($groups | Select-Object -First $shownGroups)
    $result = $null

    Write-Host ""

    if ($summary.Count -eq 0) {
        Write-WinForgeStatus -Type Success -Message (Get-WinForgeText 'Nenhum evento crítico ou de erro nos últimos 7 dias.')
        $result = New-WinForgeResult -Kind Ok -Detail (Get-WinForgeText 'nenhum evento crítico ou de erro nos últimos 7 dias')
    }
    else {
        # Os avisos lidos (disco 51 e 153, vídeo 4101) contam à parte: não são erros.
        $warningCount = @($events | Where-Object { ("$($_.ProviderName)|$($_.Id)") -in @("disk|51", "disk|153", "Display|4101") }).Count
        $errorCount = $events.Count - $warningCount
        $parts = @()
        if ($errorCount -gt 0) { $parts += $(if ($errorCount -eq 1) { (Get-WinForgeText '1 evento de erro ou crítico') } else { (Get-WinForgeText '{0} eventos de erro ou críticos' "$(Format-WinForgeNumber -Value $errorCount)") }) }
        if ($warningCount -gt 0) { $parts += $(if ($warningCount -eq 1) { (Get-WinForgeText '1 aviso do disco ou do vídeo') } else { (Get-WinForgeText '{0} avisos do disco ou do vídeo' "$(Format-WinForgeNumber -Value $warningCount)") }) }
        $total = Join-WinForgeList -Items $parts
        if ($events.Count -ge $maxEvents) { $total = (Get-WinForgeText 'Pelo menos {0} (limite de leitura)' "$total") }

        # O que pede atenção, contado e dito por causa: o desligamento inesperado (41 e 6008 juntos) conta uma vez, e os
        # erros do disco também.
        $causes = @($groups | Where-Object { $_.Serious } | ForEach-Object { Get-WinForgeEventCauseName -Provider $_.Provider -Id $_.Id } | Select-Object -Unique)

        if ($causes.Count -gt 0) {
            $knownText = "$(Format-WinForgeCount -Count $causes.Count -One (Get-WinForgeText 'problema sério') -Many (Get-WinForgeText 'problemas sérios')): $(Join-WinForgeList -Items $causes)"
            Write-WinForgeStatus -Type Warning -Message "${knownText}."
            $result = New-WinForgeResult -Kind Warning -Detail $knownText

            # O botão da faixa leva ao que a explicação manda ver, pela ordem do mais grave: a tela azul (a causa provável
            # dela), os erros do disco (a saúde dele), o sistema de arquivos (o CHKDSK) e o erro de hardware (o teste de
            # memória). O desligamento inesperado não tem tela que resolva: sem botão.
            $serious = @($groups | Where-Object { $_.Serious } | ForEach-Object { "$(([string]$_.Provider) -replace '^Microsoft-Windows-Ntfs$', 'Ntfs')|$($_.Id)" })
            $next = $(
                if ($serious -contains "Microsoft-Windows-WER-SystemErrorReporting|1001") { @("diagnostics.blue-screens", (Get-WinForgeText 'Ver as telas azuis')) }
                elseif (@($serious | Where-Object { $_ -like "disk|*" }).Count -gt 0) { @("diagnostics.disk-health", (Get-WinForgeText 'Ver a saúde dos discos')) }
                elseif (@($serious | Where-Object { $_ -like "Ntfs|*" }).Count -gt 0) { @("repair.chkdsk", (Get-WinForgeText 'Verificar o disco')) }
                elseif (@($serious | Where-Object { $_ -like "Microsoft-Windows-WHEA-Logger|*" }).Count -gt 0) { @("diagnostics.memory-test", (Get-WinForgeText 'Testar a memória')) }
                else { @() }
            )

            if ($next.Count -eq 2) {
                [void](Set-WinForgeResultView -Result $result -Next $next[0] -NextLabel $next[1])
            }
        }
        else {
            # Quase todo PC registra erros assim toda semana: sem uma conclusão, "120 erros" faria a pessoa achar que o PC
            # está quebrado.
            $count = Format-WinForgeNumber -Value $events.Count
            $common = $(
                if ($events.Count -ge $maxEvents) { (Get-WinForgeText 'pelo menos {0} erros comuns do Windows' "$count") }
                elseif ($events.Count -eq 1) { (Get-WinForgeText '1 erro comum do Windows') }
                else { (Get-WinForgeText '{0} erros comuns do Windows' "$count") }
            )
            Write-WinForgeStatus -Type Success -Message (Get-WinForgeText 'Nenhum problema sério nos últimos 7 dias. Os erros abaixo aparecem em quase todo PC e não pedem nada.')
            $result = New-WinForgeResult -Kind Ok -Detail (Get-WinForgeText 'nenhum problema sério; {0}' "$common")
        }

        Write-WinForgeStatus -Type Info -Message (Get-WinForgeText '{0} nos últimos 7 dias, em {1}.' "$total" "$(Format-WinForgeCount -Count $groups.Count -One (Get-WinForgeText 'grupo') -Many (Get-WinForgeText 'grupos'))")

        # Cada grupo numa linha que a janela também mostra no resumo: o de causa conhecida vira um aviso com a explicação;
        # os outros, uma linha "origem (ID) : quantas vezes". O desligamento inesperado registra dois eventos (Kernel-Power
        # 41 e EventLog 6008): os dois viram uma linha só, com a contagem do que tiver mais registros.
        Write-WinForgeSection -Title (Get-WinForgeText 'Eventos por origem')

        $shutdown = @($summary | Where-Object { (Get-WinForgeEventCause -Provider $_.Provider -Id $_.Id) -eq "desligamento-inesperado" })
        $shutdownShown = $false

        foreach ($item in $summary) {
            $provider = Get-WinForgeEventProviderText -Provider $item.Provider
            $times = Format-WinForgeEventOccurrences -Entry $item

            if ($shutdown.Count -gt 1 -and @($shutdown) -contains $item) {
                if ($shutdownShown) { continue }
                $shutdownShown = $true

                $main = @($shutdown | Sort-Object -Property @{ Expression = { [int]$_.Count }; Descending = $true }, @{ Expression = { [int]$_.Id -ne 41 } })[0]
                $ids = @($shutdown | Sort-Object -Property @{ Expression = { [int]$_.Id -ne 41 } } | ForEach-Object { "$(Get-WinForgeEventProviderText -Provider $_.Provider), ID $($_.Id)" }) -join "; "
                Write-WinForgeStatus -Type Warning -Message "$((Get-WinForgeEventHint -Provider 'Microsoft-Windows-Kernel-Power' -Id 41)) $(Format-WinForgeEventOccurrences -Entry $main) ($ids)."
                continue
            }

            if ($item.Hint -and [bool](Get-WinForgeJsonValue -Object $item -Name "Serious" -Default $true)) {
                Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText '{0} {1} ({2}, ID {3}).' "$($item.Hint)" "$times" "$provider" "$($item.Id)")
            }
            elseif ($item.Hint) {
                Write-WinForgeStatus -Type Info -Message (Get-WinForgeText '{0} {1} ({2}, ID {3}); {4}.' "$($item.Hint)" "$times" "$provider" "$($item.Id)" "$(Get-WinForgeEventNote -Provider $item.Provider -Id $item.Id)")
            }
            else {
                Write-WinForgeKeyValue -Label (Get-WinForgeText '{0} (ID {1})' "$provider" "$($item.Id)") -Value $times
            }
        }

        if ($groups.Count -gt $summary.Count) {
            Write-Host ""
            Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Mais {0}; o Visualizador de Eventos (eventvwr.msc) mostra a lista completa.' "$(Format-WinForgeCount -Count ($groups.Count - $summary.Count) -One (Get-WinForgeText 'grupo menos relevante') -Many (Get-WinForgeText 'grupos menos relevantes'))")
        }
    }

    Exit-WinForgeAction -Result $result
}


# ---------------------------------------------------------------------------
# Telas azuis (Diagnóstico > Telas azuis) e teste de memória (Diagnóstico > Teste de memória)
# ---------------------------------------------------------------------------

function Read-WinForgeEventRecords {
    # Como Read-WinForgeEventLog, com o nível e os valores de cada registro (Values, como texto): o código de uma tela
    # azul vem nos valores, e não no texto do evento, que muda com o idioma do Windows.
    param (
        [Parameter(Mandatory)][string]$LogName,
        [Parameter(Mandatory)][string]$XPath,
        [int]$MaxEvents = 200
    )

    $query = New-Object System.Diagnostics.Eventing.Reader.EventLogQuery($LogName, [System.Diagnostics.Eventing.Reader.PathType]::LogName, $XPath)
    $query.ReverseDirection = $true

    $reader = New-Object System.Diagnostics.Eventing.Reader.EventLogReader($query)
    $events = New-Object System.Collections.Generic.List[object]

    try {
        while ($events.Count -lt $MaxEvents) {
            $record = $reader.ReadEvent()

            if ($null -eq $record) { break }

            try {
                $values = @(@($record.Properties) | ForEach-Object { [string]$_.Value })
                $events.Add([PSCustomObject]@{ ProviderName = [string]$record.ProviderName; Id = [int]$record.Id; Level = [int]$record.Level; TimeCreated = $record.TimeCreated; Values = $values })
            }
            finally {
                $record.Dispose()
            }
        }
    }
    finally {
        $reader.Dispose()
    }

    return $events.ToArray()
}


function Get-WinForgeBugCheckInfo {
    <#
    O que costuma causar uma tela azul, pelo código (o "stop code" do Windows): Name (o nome do código), Cause (memory,
    driver, video, disk, system, hardware ou unknown) e Next (o item do WinForge que ajuda). Os códigos mais comuns em PCs
    de casa; um código fora da lista fica com a causa desconhecida e o reparo do Windows como próximo passo.
    #>
    param ([Parameter(Mandatory)][uint32]$Code)

    $table = @{
        "0000000A" = @("IRQL_NOT_LESS_OR_EQUAL", "driver")
        "00000019" = @("BAD_POOL_HEADER", "driver")
        "0000001A" = @("MEMORY_MANAGEMENT", "memory")
        "0000001E" = @("KMODE_EXCEPTION_NOT_HANDLED", "driver")
        "00000024" = @("NTFS_FILE_SYSTEM", "disk")
        "0000003B" = @("SYSTEM_SERVICE_EXCEPTION", "driver")
        "0000004E" = @("PFN_LIST_CORRUPT", "memory")
        "00000050" = @("PAGE_FAULT_IN_NONPAGED_AREA", "memory")
        "0000007A" = @("KERNEL_DATA_INPAGE_ERROR", "disk")
        "0000007B" = @("INACCESSIBLE_BOOT_DEVICE", "disk")
        "0000007E" = @("SYSTEM_THREAD_EXCEPTION_NOT_HANDLED", "driver")
        "0000007F" = @("UNEXPECTED_KERNEL_MODE_TRAP", "hardware")
        "0000009C" = @("MACHINE_CHECK_EXCEPTION", "hardware")
        "0000009F" = @("DRIVER_POWER_STATE_FAILURE", "driver")
        "000000BE" = @("ATTEMPTED_WRITE_TO_READONLY_MEMORY", "driver")
        "000000C2" = @("BAD_POOL_CALLER", "driver")
        "000000C4" = @("DRIVER_VERIFIER_DETECTED_VIOLATION", "driver")
        "000000C5" = @("DRIVER_CORRUPTED_EXPOOL", "driver")
        "000000D1" = @("DRIVER_IRQL_NOT_LESS_OR_EQUAL", "driver")
        "000000EF" = @("CRITICAL_PROCESS_DIED", "system")
        "000000F4" = @("CRITICAL_OBJECT_TERMINATION", "disk")
        "000000FC" = @("ATTEMPTED_EXECUTE_OF_NOEXECUTE_MEMORY", "driver")
        "00000101" = @("CLOCK_WATCHDOG_TIMEOUT", "hardware")
        "0000010E" = @("VIDEO_MEMORY_MANAGEMENT_INTERNAL", "video")
        "00000113" = @("VIDEO_DXGKRNL_FATAL_ERROR", "video")
        "00000116" = @("VIDEO_TDR_FAILURE", "video")
        "00000117" = @("VIDEO_TDR_TIMEOUT_DETECTED", "video")
        "00000119" = @("VIDEO_SCHEDULER_INTERNAL_ERROR", "video")
        "00000124" = @("WHEA_UNCORRECTABLE_ERROR", "hardware")
        "0000012B" = @("FAULTY_HARDWARE_CORRUPTED_PAGE", "memory")
        "00000133" = @("DPC_WATCHDOG_VIOLATION", "driver")
        "00000139" = @("KERNEL_SECURITY_CHECK_FAILURE", "driver")
        "00000154" = @("UNEXPECTED_STORE_EXCEPTION", "disk")
        "000001CA" = @("SYNTHETIC_WATCHDOG_TIMEOUT", "hardware")
        "C000021A" = @("STATUS_SYSTEM_PROCESS_TERMINATED", "system")
    }

    $key = "{0:X8}" -f $Code

    # Os códigos 0x1000xxxx são os 0x0000xxxx com mais parâmetros (0x1000007E é o 0x7E).
    if (-not $table.ContainsKey($key) -and ($Code -band 0x10000000)) { $key = "{0:X8}" -f ($Code -band 0x0FFFFFFF) }
    $entry = $(if ($table.ContainsKey($key)) { $table[$key] } else { @("", "unknown") })
    $next = switch ($entry[1]) {
        "memory" { "diagnostics.memory-test" }
        "hardware" { "diagnostics.memory-test" }
        "driver" { "updates.drivers" }
        "video" { "updates.drivers" }
        "disk" { "diagnostics.disk-health" }
        default { "repair.dism-sfc" }
    }

    return [PSCustomObject]@{ Code = $Code; Name = $entry[0]; Cause = $entry[1]; Next = $next }
}


function Get-WinForgeBugCheckCauseText {
    # A causa provável numa frase curta, e o que fazer.
    param ([Parameter(Mandatory)][string]$Cause)

    switch ($Cause) {
        "memory" { return [PSCustomObject]@{ Cause = (Get-WinForgeText 'a memória (RAM)'); Advice = (Get-WinForgeText 'Faça o teste de memória do Windows.') } }
        "hardware" { return [PSCustomObject]@{ Cause = (Get-WinForgeText 'o hardware: memória, processador ou superaquecimento'); Advice = (Get-WinForgeText 'Faça o teste de memória; se o PC estiver com overclock, desfaça.') } }
        "driver" { return [PSCustomObject]@{ Cause = (Get-WinForgeText 'um driver'); Advice = (Get-WinForgeText 'Atualize os drivers, principalmente os de rede, vídeo e chipset.') } }
        "video" { return [PSCustomObject]@{ Cause = (Get-WinForgeText 'o driver da placa de vídeo'); Advice = (Get-WinForgeText 'Atualize o driver de vídeo.') } }
        "disk" { return [PSCustomObject]@{ Cause = (Get-WinForgeText 'o disco ou a ligação com ele'); Advice = (Get-WinForgeText 'Confira a saúde dos discos e faça backup.') } }
        "system" { return [PSCustomObject]@{ Cause = (Get-WinForgeText 'arquivos do Windows danificados'); Advice = (Get-WinForgeText 'Repare os arquivos do Windows.') } }
        default { return [PSCustomObject]@{ Cause = (Get-WinForgeText 'não identificada pelo código'); Advice = (Get-WinForgeText 'Repare os arquivos do Windows e atualize os drivers.') } }
    }
}


function Get-WinForgeBlueScreens {
    <#
    As telas azuis dos últimos Days dias, da mais nova para a mais antiga: When, Code (número) e Info
    (Get-WinForgeBugCheckInfo). Vêm do registro que o Windows grava ao voltar de uma tela azul (WER, 1001) e, sem ele,
    do reinício inesperado com o código da tela azul (Kernel-Power 41). As duas leituras do mesmo travamento contam uma
    vez: o 1001 sai depois do 41 daquele reinício e antes do próximo 41, com o mesmo código, mesmo que demore (dump
    grande, PC lento, a pessoa demorando a entrar).
    #>
    param ([int]$Days = 90)

    $window = [int64]([TimeSpan]::FromDays($Days).TotalMilliseconds)
    $found = @()

    $wer = @(Read-WinForgeEventRecords -LogName "System" -XPath "*[System[Provider[@Name='Microsoft-Windows-WER-SystemErrorReporting'] and EventID=1001 and TimeCreated[timediff(@SystemTime) <= $window]]]" | ForEach-Object { $_ })

    foreach ($event in $wer) {
        # O primeiro valor é "0x0000009f (0x..., 0x..., ...)": o código vem antes do parêntese.
        $text = [string](@($event.Values) | Select-Object -First 1)
        $match = [regex]::Match($text, '0x([0-9A-Fa-f]{1,8})')

        if ($match.Success) { $found += [PSCustomObject]@{ When = $event.TimeCreated; Code = [Convert]::ToUInt32($match.Groups[1].Value, 16) } }
    }

    $power = @(Read-WinForgeEventRecords -LogName "System" -XPath "*[System[Provider[@Name='Microsoft-Windows-Kernel-Power'] and EventID=41 and TimeCreated[timediff(@SystemTime) <= $window]]]" | ForEach-Object { $_ })

    # Cada reinício inesperado (41), do mais antigo ao mais novo. BugcheckCode é o primeiro valor do evento; zero é um
    # desligamento sem tela azul (energia, botão), que só marca onde um reinício começa.
    $boots = @(@(
            foreach ($event in $power) {
                $value = 0L
                if (-not [int64]::TryParse([string](@($event.Values) | Select-Object -First 1), [ref]$value) -or $value -lt 0 -or $value -gt [uint32]::MaxValue) { $value = 0L }
                [PSCustomObject]@{ When = $event.TimeCreated; Code = [uint32]$value }
            }
        ) | Sort-Object When)

    $reports = @($found | Sort-Object When)
    $used = New-Object 'System.Collections.Generic.HashSet[int]'

    for ($i = 0; $i -lt $boots.Count; $i++) {
        $boot = $boots[$i]
        if ($boot.Code -eq 0) { continue }

        # O 1001 deste travamento: com o mesmo código, depois deste reinício (com folga para o relógio) e antes do próximo.
        $from = $boot.When.AddMinutes(-15)
        $until = $(if ($i + 1 -lt $boots.Count) { $boots[$i + 1].When } else { [datetime]::MaxValue })
        $match = -1

        for ($j = 0; $j -lt $reports.Count; $j++) {
            if ($used.Contains($j)) { continue }

            if ([uint32]$reports[$j].Code -eq $boot.Code -and $reports[$j].When -ge $from -and $reports[$j].When -lt $until) {
                $match = $j
                break
            }
        }

        if ($match -ge 0) { [void]$used.Add($match) } else { $found += $boot }
    }

    return @($found | Sort-Object When -Descending | ForEach-Object { [PSCustomObject]@{ When = $_.When; Code = $_.Code; Info = (Get-WinForgeBugCheckInfo -Code $_.Code) } })
}


function Get-WinForgeBlueScreenMainCause {
    # A causa mais frequente das telas azuis (empate: a da mais recente), como Get-WinForgeBugCheckInfo. $null sem nenhuma.
    param ([object[]]$Screens = @())

    if (@($Screens).Count -eq 0) { return $null }

    $counts = @{}
    foreach ($screen in $Screens) { $counts[$screen.Info.Cause] = 1 + [int]$counts[$screen.Info.Cause] }
    $most = [int](@($counts.Values) | Measure-Object -Maximum).Maximum

    return @(@($Screens | Sort-Object When -Descending) | Where-Object { [int]$counts[$_.Info.Cause] -eq $most })[0].Info
}


function Show-WinForgeBlueScreens {
    $title = (Get-WinForgeText 'Telas azuis')
    Enter-WinForgeAction -Title $title

    $final = $null

    try {
        Write-Progress -Activity $title -Status (Get-WinForgeText 'lendo os registros de erro do Windows')
        $screens = @(Get-WinForgeBlueScreens -Days 90)
        Write-Progress -Activity $title -Completed
        Write-Host ""

        if ($screens.Count -eq 0) {
            Write-WinForgeStatus -Type Success -Message (Get-WinForgeText 'Nenhuma tela azul nos últimos 90 dias.')
            $final = Set-WinForgeResultView -Result (New-WinForgeResult -Kind Ok -Detail (Get-WinForgeText 'nenhuma tela azul em 90 dias') -Title $title) `
                -Headline (Get-WinForgeText 'Nenhuma tela azul em 90 dias') -Note (Get-WinForgeText 'O Windows não registrou nenhuma parada com erro grave nesse período.')
        }
        else {
            Write-WinForgeSection -Title (Get-WinForgeText 'Últimos 90 dias')

            # Um código por linha, com quantas vezes e a última, como nos Eventos críticos: o mesmo travamento repetido
            # dez vezes eram dez linhas com a mesma causa e o mesmo conselho. A causa vem embaixo do primeiro código que a
            # tem, uma vez só. Do código mais recente ao mais antigo.
            $explained = @{}

            foreach ($group in @($screens | Group-Object -Property { [uint32]$_.Code } | Sort-Object -Property @{ Expression = { @($_.Group | Sort-Object When -Descending)[0].When }; Descending = $true } | Select-Object -First 15)) {
                $latest = @($group.Group | Sort-Object When -Descending)[0]
                $about = Get-WinForgeBugCheckCauseText -Cause $latest.Info.Cause
                $times = Format-WinForgeEventOccurrences -Entry ([PSCustomObject]@{ Count = $group.Count; Last = $latest.When })

                Write-WinForgeKeyValue -Label ("0x{0:X8}" -f [uint32]$latest.Code) -Value $(if ($latest.Info.Name) { "$($latest.Info.Name) · $times" } else { $times }) -LabelWidth 12

                if (-not $explained.ContainsKey([string]$latest.Info.Cause)) {
                    $explained[[string]$latest.Info.Cause] = $true
                    Write-WinForgeStatus -Type Info -Notice -Message (Get-WinForgeText 'Causa provável: {0}. {1}' "$($about.Cause)" "$($about.Advice)")
                }
            }

            # A causa mais frequente decide o próximo passo da faixa (empate: a da tela azul mais recente).
            $main = Get-WinForgeBlueScreenMainCause -Screens $screens
            $about = Get-WinForgeBugCheckCauseText -Cause $main.Cause
            $item = Get-WinForgeNavItem -Id $main.Next
            $count = Format-WinForgeCount -Count $screens.Count -One (Get-WinForgeText 'tela azul') -Many (Get-WinForgeText 'telas azuis')

            Write-Host ""
            Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText '{0} em 90 dias. Causa mais provável: {1}.' "$count" "$($about.Cause)")

            $final = Set-WinForgeResultView -Result (New-WinForgeResult -Kind Warning -Detail (Get-WinForgeText '{0} em 90 dias; causa mais provável: {1}' "$count" "$($about.Cause)") -Title $title) `
                -Headline (Get-WinForgeText '{0} em 90 dias' "$count") -Note (Get-WinForgeText 'Causa mais provável: {0}. {1}' "$($about.Cause)" "$($about.Advice)") `
                -Next $main.Next -NextLabel $(if ($null -ne $item) { [string]$item.Label } else { "" })
        }
    }
    catch {
        Write-Progress -Activity $title -Completed
        Write-Host ""
        Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'Não foi possível ler o log do Sistema: {0}' "$($_.Exception.Message)")
        Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Isto não quer dizer que não haja telas azuis. Abra o Visualizador de Eventos (eventvwr.msc) para conferir.')

        # A faixa sai do aviso acima, como nos Eventos críticos: a frase inteira, e não só a mensagem crua do Windows.
        $final = $null
    }

    Exit-WinForgeAction -Result $final
}


function Get-WinForgeMemoryTestResult {
    <#
    O resultado mais recente do Diagnóstico de Memória do Windows (o teste roda no reinício e o Windows grava o resultado
    no log do Sistema ao voltar): When e Errors (o teste achou erros: o evento 1202, ou um evento de erro ou de aviso), ou
    $null sem teste nos últimos Days dias.
    #>
    param ([int]$Days = 365)

    $window = [int64]([TimeSpan]::FromDays($Days).TotalMilliseconds)
    $record = @(Read-WinForgeEventRecords -LogName "System" -XPath "*[System[Provider[@Name='Microsoft-Windows-MemoryDiagnostics-Results'] and TimeCreated[timediff(@SystemTime) <= $window]]]" -MaxEvents 1 | ForEach-Object { $_ })[0]

    if ($null -eq $record) { return $null }

    return [PSCustomObject]@{ When = $record.TimeCreated; Errors = ($record.Id -in @(1102, 1202) -or $record.Level -in @(1, 2, 3)) }
}


function Get-WinForgeSettingDate {
    # Uma data guardada nas preferências (no formato "o"), ou $null.
    param ([Parameter(Mandatory)][string]$Name)

    $value = Get-WinForgeSetting -Name $Name -Default ""
    $when = [datetime]::MinValue

    if ($value -is [datetime]) { return $value }
    if ([datetime]::TryParse([string]$value, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind, [ref]$when)) { return $when }

    return $null
}


function Get-WinForgeMemoryTestPendingSince {
    # Quando o teste de memória foi pedido pelo WinForge e ainda não teve resultado, ou $null.
    return (Get-WinForgeSettingDate -Name "MemoryTestRequestedAt")
}


function Start-WinForgeMemoryTest {
    $title = (Get-WinForgeText 'Teste de memória')
    Enter-WinForgeAction -Title $title

    $final = $null

    try {
        $last = $null
        try { $last = Get-WinForgeMemoryTestResult } catch { $last = $null }

        Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'O Diagnóstico de Memória do Windows testa a memória (RAM) no reinício: leva uns 15 minutos, e o PC volta sozinho para o Windows no fim. O WinForge lê o resultado depois.')
        Write-Host ""

        if ($null -ne $last) {
            Write-WinForgeKeyValue -Label (Get-WinForgeText 'Último teste') -Value (Format-WinForgeDateTime -When $last.When)
            Write-WinForgeKeyValue -Label (Get-WinForgeText 'Resultado') -Value $(if ($last.Errors) { (Get-WinForgeText 'encontrou erros na memória') } else { (Get-WinForgeText 'nenhum erro') }) -Level $(if ($last.Errors) { "Bad" } else { "Ok" })
            Write-Host ""

            if ($last.Errors) {
                Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'Erros na memória causam telas azuis e travamentos. Leve o PC a um técnico ou troque o pente de memória com defeito (testando um pente de cada vez).')
                Write-Host ""
            }
        }

        $pending = Get-WinForgeMemoryTestPendingSince

        if ($null -ne $pending -and ($null -eq $last -or $last.When -lt $pending)) {
            Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'O teste foi pedido em {0} e ainda não rodou: ele roda no próximo reinício, se você escolheu reiniciar depois.' "$(Format-WinForgeDateTime -When $pending)")
            Write-Host ""
        }

        # Com um teste recente sem erros (o aviso do monitor traz para cá), Enter não abre a ferramenta de novo.
        $recent = ($null -ne $last -and -not $last.Errors -and ((Get-Date) - $last.When).TotalDays -le 30)

        if (-not (Confirm-WinForgeAction -Message (Get-WinForgeText 'Abrir o Diagnóstico de Memória do Windows?') -DefaultKey $(if ($recent) { "N" } else { "S" }) -YesLabel (Get-WinForgeText 'Abrir') -NoLabel (Get-WinForgeText 'Agora não'))) {
            # Com um teste já lido, dizer "não" é ficar com o que a tela mostrou, e não uma desistência: a faixa sai do
            # que foi mostrado (os erros do último teste continuam como ressalva). Sem teste, é um cancelamento.
            $final = $(if ($null -ne $last -and ($last.Errors -or $recent)) { $null } else { New-WinForgeResult -Kind Skipped -Detail (Get-WinForgeText 'cancelado pelo usuário') -Title $title })
        }
        else {
            $tool = Join-Path $env:SystemRoot "System32\mdsched.exe"

            if (-not (Test-Path -LiteralPath $tool -PathType Leaf)) { throw (Get-WinForgeText 'o Diagnóstico de Memória do Windows (mdsched.exe) não está neste Windows') }

            Start-Process -FilePath $tool -ErrorAction Stop
            [void](Set-WinForgeSetting -Name "MemoryTestRequestedAt" -Value ((Get-Date).ToString("o", [System.Globalization.CultureInfo]::InvariantCulture)))

            Write-WinForgeStatus -Type Success -Message (Get-WinForgeText 'Na janela do Windows, escolha Reiniciar agora e verificar (salve o que estiver aberto antes) ou Verificar na próxima vez que eu iniciar o computador.')
            $final = Set-WinForgeResultView -Result (New-WinForgeResult -Kind Ok -Detail (Get-WinForgeText 'Diagnóstico de Memória aberto; o resultado aparece depois do reinício') -Title $title) `
                -Headline (Get-WinForgeText 'Escolha quando testar') -Note (Get-WinForgeText 'O teste roda no reinício. Com o monitor na bandeja ligado, o resultado aparece sozinho; senão, abra esta tela de novo.')
        }
    }
    catch {
        Write-WinForgeStatus -Type Error -Message (Get-WinForgeText 'Não foi possível abrir o teste de memória: {0}' "$(([string]$_.Exception.Message).TrimEnd('.'))")
        $final = New-WinForgeResult -Kind Failed -Detail ([string]$_.Exception.Message).TrimEnd('.') -Title $title
    }

    Exit-WinForgeAction -Result $final
}


Export-ModuleMember -Function *
