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
        default { return "Desconhecido" }
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

    # Placas dedicadas conhecidas nunca são tratadas como integradas, mesmo que o nome contenha "Graphics".
    if ($name -match "\b(GeForce|Quadro|RTX|GTX|Radeon\s+(RX|Pro|VII)|Arc\s+(A|B)[0-9]|Intel\(R\)\s+Arc)\b") {
        return $false
    }

    $integratedPatterns = @(
        "^AMD Radeon\(TM\) Graphics$",
        "^AMD Radeon Graphics$",
        "^AMD Radeon\s*(\(TM\)\s*)?[0-9]{3,4}M(\s+Graphics)?$",    # Radeon 680M / 780M / 890M
        "^AMD Radeon\s*(\(TM\)\s*)?Vega\s+[0-9]+(\s+Graphics)?$",  # Vega 8 / Vega 11
        "Intel\(R\).*(UHD|Iris|HD|Xe)\b.*Graphics",
        "Intel\(R\)\s+Graphics",                                    # Core Ultra: "Intel(R) Graphics"
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
            }
        }

        if (@($candidates).Count -eq 0) {
            return $null
        }

        $bestCandidate = $candidates |
            Sort-Object -Property Memory -Descending |
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
    # anunciada pelo módulo (Speed) versus velocidade em uso (ConfiguredClockSpeed).
    try {
        if ($null -eq $MemoryModules -or @($MemoryModules).Count -eq 0) {
            return "Desconhecido"
        }

        $memoryTypeCode = ($MemoryModules | Select-Object -First 1).SMBIOSMemoryType
        $memoryType = Convert-WinForgeMemoryType -Type $memoryTypeCode

        if ($memoryType -like "LPDDR*") {
            return "Não se aplica (memória LPDDR soldada)"
        }

        $configured = ($MemoryModules | Measure-Object -Property ConfiguredClockSpeed -Maximum).Maximum
        $rated = ($MemoryModules | Measure-Object -Property Speed -Maximum).Maximum

        if ($null -eq $configured -or $configured -le 0) {
            return "Desconhecido"
        }

        $jedecMax = switch ($memoryType) {
            "DDR5" { 5600 }
            "DDR4" { 3200 }
            "DDR3" { 1866 }
            default { 0 }
        }

        if ($jedecMax -eq 0) {
            return "Desconhecido"
        }

        if ($configured -gt $jedecMax) {
            return "Indicativo: ativado ($configured MHz, acima do padrão JEDEC)"
        }

        if ($null -ne $rated -and $rated -gt $configured) {
            return "Indicativo: desativado (módulo anuncia $rated MHz, em uso $configured MHz)"
        }

        return "Padrão JEDEC / indeterminado ($configured MHz)"
    }
    catch {
        return "Desconhecido"
    }
}


Export-ModuleMember -Function *
