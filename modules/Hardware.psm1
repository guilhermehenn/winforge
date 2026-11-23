# Hardware: identificação de memória e GPU.


function Convert-WinForgeMemoryType {
    param (
        [int]$Type
    )

    # Códigos SMBIOS (Win32_PhysicalMemory.SMBIOSMemoryType, campo "Memory Type" do tipo 17).
    # Atenção: o campo MemoryType (sem SMBIOS) usa outra numeração, na qual 20 é DDR e 21 é DDR2.
    switch ($Type) {
        18 { return "DDR" }
        19 { return "DDR2" }
        20 { return "DDR2 FB-DIMM" }
        24 { return "DDR3" }
        26 { return "DDR4" }
        27 { return "LPDDR" }
        28 { return "LPDDR2" }
        29 { return "LPDDR3" }
        30 { return "LPDDR4" }
        34 { return "DDR5" }
        35 { return "LPDDR5" }
        default { return (Get-WinForgeText 'Desconhecido') }
    }
}


function Test-WinForgeIntegratedGpu {
    param (
        [string]$GpuName
    )

    if ([string]::IsNullOrWhiteSpace($GpuName)) {
        return $false
    }

    $name = $GpuName.Trim()

    # Placas dedicadas conhecidas nunca são tratadas como integradas, mesmo que o nome contenha "Graphics". Da Intel, só
    # as Arc com modelo de série A ou B (A380, A770M, B580, Pro B60) são placas: "Intel(R) Arc(TM) Graphics" (Meteor
    # Lake, Arrow Lake), "Arc(TM) 140V/140T" (Lunar Lake, Arrow Lake H) e "Arc(TM) B370/B390" (Panther Lake) estão
    # dentro do processador.
    if ($name -match "\b(GeForce|Quadro|RTX|GTX|Radeon\s+(RX|Pro|VII))\b") {
        return $false
    }

    if ($name -match "\bArc(\(TM\))?\s+(Pro\s+)?[AB][0-9]{2,3}" -and $name -notmatch "\bArc(\(TM\))?\s+B3[0-9]{2}\b") {
        return $false
    }

    $integratedPatterns = @(
        "^AMD Radeon\(TM\) Graphics$",
        "^AMD Radeon Graphics$",
        "^AMD Radeon\s*(\(TM\)\s*)?[0-9]{3,4}M(\s+Graphics)?$",    # Radeon 680M / 780M / 890M
        "^AMD Radeon\s*(\(TM\)\s*)?Vega\s+[0-9]+(\s+Graphics)?$",  # Vega 8 / Vega 11
        "Intel\(R\).*(UHD|Iris|HD|Xe)\b.*Graphics",
        "Intel\(R\)\s+Graphics",                                    # Core Ultra: "Intel(R) Graphics"
        "Intel\(R\)\s+Arc(\(TM\))?\s+(Graphics|[0-9]{3}[VT]\b|B3[0-9]{2}\b)", # Core Ultra: Arc Graphics, 140V, B390
        "Intel.*Integrated"
    )

    foreach ($pattern in $integratedPatterns) {
        if ($name -match $pattern) {
            return $true
        }
    }

    return $false
}


function ConvertTo-WinForgeComparableName {
    param (
        [string]$Text
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return ""
    }

    return ($Text.ToLowerInvariant() -replace "[^a-z0-9]", "")
}


function ConvertTo-WinForgeUInt64 {
    param (
        [object]$Value
    )

    try {
        if ($null -eq $Value) {
            return $null
        }

        if ($Value -is [byte[]]) {
            if ($Value.Length -ge 8) {
                return [BitConverter]::ToUInt64($Value, 0)
            }

            if ($Value.Length -ge 4) {
                return [UInt64][BitConverter]::ToUInt32($Value, 0)
            }

            return $null
        }

        return [UInt64]$Value
    }
    catch {
        return $null
    }
}


function Get-WinForgeGpuMemoryBytes {
    param (
        [string]$GpuName
    )

    try {
        $videoKeys = Get-ChildItem -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Video" -ErrorAction SilentlyContinue
        $candidates = @()
        $normalizedGpuName = ConvertTo-WinForgeComparableName -Text $GpuName

        foreach ($key in $videoKeys) {
            $adapterPath = Join-Path $key.PSPath "0000"
            $adapter = Get-ItemProperty -Path $adapterPath -ErrorAction SilentlyContinue

            if ($null -eq $adapter) {
                continue
            }

            $adapterString = $adapter."HardwareInformation.AdapterString"

            if ($adapterString -is [byte[]]) {
                $adapterString = [System.Text.Encoding]::Unicode.GetString($adapterString).Trim([char]0)
            }

            if ([string]::IsNullOrWhiteSpace($adapterString)) {
                continue
            }

            $normalizedAdapterString = ConvertTo-WinForgeComparableName -Text $adapterString

            $isSameGpu =
                $normalizedGpuName -eq $normalizedAdapterString -or
                $normalizedGpuName.Contains($normalizedAdapterString) -or
                $normalizedAdapterString.Contains($normalizedGpuName)

            if (-not $isSameGpu) {
                continue
            }

            $memoryBytes = $null

            if ($adapter.PSObject.Properties.Name -contains "HardwareInformation.qwMemorySize") {
                $memoryBytes = ConvertTo-WinForgeUInt64 -Value $adapter."HardwareInformation.qwMemorySize"
            }
            elseif ($adapter.PSObject.Properties.Name -contains "HardwareInformation.MemorySize") {
                $memoryBytes = ConvertTo-WinForgeUInt64 -Value $adapter."HardwareInformation.MemorySize"
            }

            if ($null -eq $memoryBytes -or $memoryBytes -le 0) {
                continue
            }

            $candidates += [PSCustomObject]@{
                Name   = $adapterString
                Memory = $memoryBytes
                Exact  = ($normalizedGpuName -eq $normalizedAdapterString)
            }
        }

        if (@($candidates).Count -eq 0) {
            return $null
        }

        # O nome exato vem antes: uma entrada que só contém o nome pode ser de uma placa que já saiu do PC (uma RTX 4070
        # Ti SUPER de 16 GB trocada por uma RTX 4070 de 12 GB deixa a entrada antiga no Registro).
        $bestCandidate = $candidates |
            Sort-Object -Property @{ Expression = { [bool]$_.Exact }; Descending = $true }, @{ Expression = "Memory"; Descending = $true } |
            Select-Object -First 1

        return $bestCandidate.Memory
    }
    catch {
        return $null
    }
}


function Get-WinForgeExpoXmpStatus {
    param (
        [array]$MemoryModules
    )

    # O Windows não expõe o perfil XMP/EXPO. O resultado é um indicativo baseado em velocidade
    # anunciada pelo módulo (Speed) versus velocidade em uso (ConfiguredClockSpeed). As duas vêm em MT/s, a taxa de
    # transferência que o nome do módulo usa (DDR4-3200 = 3200 MT/s) e que o Gerenciador de Tarefas do Windows 11 mostra.
    try {
        if ($null -eq $MemoryModules -or @($MemoryModules).Count -eq 0) {
            return (Get-WinForgeText 'Desconhecido')
        }

        $memoryTypeCode = ($MemoryModules | Select-Object -First 1).SMBIOSMemoryType
        $memoryType = Convert-WinForgeMemoryType -Type $memoryTypeCode

        if ($memoryType -like "LPDDR*") {
            return (Get-WinForgeText 'Não se aplica (memória LPDDR soldada)')
        }

        $configured = ($MemoryModules | Measure-Object -Property ConfiguredClockSpeed -Maximum).Maximum
        $rated = ($MemoryModules | Measure-Object -Property Speed -Maximum).Maximum

        if ($null -eq $configured -or $configured -le 0) {
            return (Get-WinForgeText 'Desconhecido')
        }

        # Mais rápido do que o próprio módulo anuncia só acontece com um perfil (ou overclock manual) ligado na BIOS. É a
        # comparação mais segura, então vem primeiro: vale para qualquer tipo de memória.
        if ($null -ne $rated -and $rated -gt 0 -and $configured -gt $rated) {
            return (Get-WinForgeText 'Indicativo: ativado ({0} MT/s, acima dos {1} MT/s do módulo)' "$configured" "$rated")
        }

        # A maior velocidade padrão de cada geração (JEDEC): DDR5 vai até 8800 MT/s desde a revisão JESD79-5C (2024), DDR4
        # até 3200 e DDR3 até 2133. Acima disso, só com perfil XMP/EXPO.
        $jedecMax = switch ($memoryType) {
            "DDR5" { 8800 }
            "DDR4" { 3200 }
            "DDR3" { 2133 }
            default { 0 }
        }

        if ($jedecMax -gt 0 -and $configured -gt $jedecMax) {
            return (Get-WinForgeText 'Indicativo: ativado ({0} MT/s, acima da velocidade padrão)' "$configured")
        }

        # Abaixo do que o módulo anuncia: num notebook é o limite do fabricante (não há opção a ligar); num desktop pode ser
        # o perfil desligado, mas também o limite do processador ou da placa, ou módulos diferentes misturados.
        if ($null -ne $rated -and $rated -gt $configured) {
            if (Test-WinForgeLaptop) {
                return (Get-WinForgeText 'Não se aplica (notebook: em uso {0} MT/s, o que o fabricante definiu)' "$configured")
            }

            return (Get-WinForgeText 'Abaixo do que o módulo anuncia ({0} MT/s; em uso {1} MT/s): perfil XMP/EXPO desligado, ou limite do processador ou da placa' "$rated" "$configured")
        }

        if ($jedecMax -eq 0) {
            return (Get-WinForgeText 'Desconhecido')
        }

        return (Get-WinForgeText 'Velocidade padrão ({0} MT/s)' "$configured")
    }
    catch {
        return (Get-WinForgeText 'Desconhecido')
    }
}


Export-ModuleMember -Function *
