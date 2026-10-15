# Hardware: tipo de memória, GPU integrada, indicativo de XMP/EXPO e conversões de valores do Windows.

BeforeAll {
    . (Join-Path $PSScriptRoot "TestSetup.ps1")

    function script:New-MemoryModule {
        param ([int]$Type, [int]$Configured, [int]$Rated)
        [PSCustomObject]@{ SMBIOSMemoryType = $Type; ConfiguredClockSpeed = $Configured; Speed = $Rated }
    }
}

AfterAll {
    Remove-WinForgeTestData
}

Describe "GPU integrada" {
    It "reconhece <Name> como integrada" -ForEach @(
        @{ Name = "Intel(R) UHD Graphics 630" },
        @{ Name = "Intel(R) Iris(R) Xe Graphics" },
        @{ Name = "Intel(R) HD Graphics 4600" },
        @{ Name = "Intel(R) Graphics" },
        @{ Name = "AMD Radeon(TM) Graphics" },
        @{ Name = "AMD Radeon Graphics" },
        @{ Name = "AMD Radeon 780M Graphics" },
        @{ Name = "AMD Radeon(TM) 680M" },
        @{ Name = "AMD Radeon(TM) Vega 8 Graphics" },
        @{ Name = "  Intel(R) UHD Graphics  " }
    ) {
        Test-WinForgeIntegratedGpu -GpuName $Name | Should -BeTrue
    }

    It "não trata <Name> como integrada" -ForEach @(
        @{ Name = "NVIDIA GeForce RTX 4070" },
        @{ Name = "NVIDIA GeForce MX450" },
        @{ Name = "NVIDIA Quadro T1000" },
        @{ Name = "AMD Radeon RX 7800 XT" },
        @{ Name = "AMD Radeon RX 6600M" },
        @{ Name = "AMD Radeon Pro W7800" },
        @{ Name = "Intel(R) Arc(TM) A770 Graphics" },
        @{ Name = "Intel(R) Arc(TM) B580 Graphics" }
    ) {
        Test-WinForgeIntegratedGpu -GpuName $Name | Should -BeFalse
    }

    It "nome vazio ou nulo não é integrada" -ForEach @(
        @{ Name = "" }, @{ Name = "   " }, @{ Name = $null }
    ) {
        Test-WinForgeIntegratedGpu -GpuName $Name | Should -BeFalse
    }
}

Describe "Tipo de memória (códigos SMBIOS)" {
    It "mapeia <Code> para <Expected>" -ForEach @(
        @{ Code = 18; Expected = "DDR" },
        @{ Code = 19; Expected = "DDR2" },
        @{ Code = 20; Expected = "DDR2 FB-DIMM" },
        @{ Code = 24; Expected = "DDR3" },
        @{ Code = 26; Expected = "DDR4" },
        @{ Code = 27; Expected = "LPDDR" },
        @{ Code = 28; Expected = "LPDDR2" },
        @{ Code = 29; Expected = "LPDDR3" },
        @{ Code = 30; Expected = "LPDDR4" },
        @{ Code = 34; Expected = "DDR5" },
        @{ Code = 35; Expected = "LPDDR5" }
    ) {
        Convert-WinForgeMemoryType -Type $Code | Should -Be $Expected
    }

    It "códigos desconhecidos, reservados, zero e negativos viram 'Desconhecido'" -ForEach @(
        @{ Code = 0 }, @{ Code = 21 }, @{ Code = 25 }, @{ Code = 999 }, @{ Code = -1 }
    ) {
        Convert-WinForgeMemoryType -Type $Code | Should -Be "Desconhecido"
    }
}

Describe "Indicativo de XMP/EXPO" {
    It "DDR5 abaixo da velocidade anunciada: desativado" {
        Get-WinForgeExpoXmpStatus -MemoryModules @(New-MemoryModule 34 4800 6000) | Should -Match "desativado"
    }

    It "DDR5 acima do padrão JEDEC: ativado" {
        Get-WinForgeExpoXmpStatus -MemoryModules @(New-MemoryModule 34 6000 6000) | Should -Match "ativado"
    }

    It "DDR4 em 3600 MHz: ativado; em 2133 anunciado 3200: desativado; em 3200 anunciado 3200: padrão" {
        Get-WinForgeExpoXmpStatus -MemoryModules @(New-MemoryModule 26 3600 3600) | Should -Match "ativado"
        Get-WinForgeExpoXmpStatus -MemoryModules @(New-MemoryModule 26 2133 3200) | Should -Match "desativado"
        Get-WinForgeExpoXmpStatus -MemoryModules @(New-MemoryModule 26 3200 3200) | Should -Match "Padrão JEDEC"
    }

    It "o limite JEDEC exato (DDR5 5600) não conta como ativado" {
        Get-WinForgeExpoXmpStatus -MemoryModules @(New-MemoryModule 34 5600 5600) | Should -Match "Padrão JEDEC"
    }

    It "LPDDR não se aplica" {
        Get-WinForgeExpoXmpStatus -MemoryModules @(New-MemoryModule 35 6400 6400) | Should -Match "Não se aplica"
        Get-WinForgeExpoXmpStatus -MemoryModules @(New-MemoryModule 30 4266 4266) | Should -Match "Não se aplica"
    }

    It "sem módulos, tipo desconhecido ou velocidade zero: Desconhecido" {
        Get-WinForgeExpoXmpStatus -MemoryModules @() | Should -Be "Desconhecido"
        Get-WinForgeExpoXmpStatus -MemoryModules $null | Should -Be "Desconhecido"
        Get-WinForgeExpoXmpStatus -MemoryModules @(New-MemoryModule 999 3200 3200) | Should -Be "Desconhecido"
        Get-WinForgeExpoXmpStatus -MemoryModules @(New-MemoryModule 26 0 3200) | Should -Be "Desconhecido"
    }

    It "usa o maior valor entre módulos diferentes" {
        $modules = @((New-MemoryModule 26 2666 3200), (New-MemoryModule 26 3600 3600))
        Get-WinForgeExpoXmpStatus -MemoryModules $modules | Should -Match "ativado"
    }

    It "objetos sem as propriedades esperadas não geram erro" {
        { Get-WinForgeExpoXmpStatus -MemoryModules @([PSCustomObject]@{ Foo = 1 }) } | Should -Not -Throw
        Get-WinForgeExpoXmpStatus -MemoryModules @([PSCustomObject]@{ Foo = 1 }) | Should -Be "Desconhecido"
    }
}

Describe "Conversões" {
    It "ConvertTo-WinForgeUInt64 aceita números, texto numérico e bytes do Registro" {
        ConvertTo-WinForgeUInt64 -Value 4294967296 | Should -Be 4294967296
        ConvertTo-WinForgeUInt64 -Value "123" | Should -Be 123
        ConvertTo-WinForgeUInt64 -Value ([BitConverter]::GetBytes([UInt64]8589934592)) | Should -Be 8589934592
        ConvertTo-WinForgeUInt64 -Value ([BitConverter]::GetBytes([UInt32]2147483648)) | Should -Be 2147483648
    }

    It "ConvertTo-WinForgeUInt64 devolve nulo para valores inválidos" -ForEach @(
        @{ Value = $null }, @{ Value = "texto" }, @{ Value = -5 }, @{ Value = [byte[]]@(1, 2) }
    ) {
        ConvertTo-WinForgeUInt64 -Value $Value | Should -BeNullOrEmpty
    }

    It "o nome comparável ignora maiúsculas, espaços e símbolos" {
        ConvertTo-WinForgeComparableName -Text "NVIDIA GeForce RTX 4070 (Super)" | Should -Be "nvidiageforcertx4070super"
        ConvertTo-WinForgeComparableName -Text $null | Should -Be ""
        ConvertTo-WinForgeComparableName -Text "   " | Should -Be ""
    }
}
