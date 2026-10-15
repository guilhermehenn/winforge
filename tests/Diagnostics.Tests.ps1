# Diagnósticos e relatórios: textos de tempo ligado e disco, eventos, saúde dos discos, reinício pendente e relatório.

BeforeAll {
    . (Join-Path $PSScriptRoot "TestSetup.ps1")
}

AfterAll {
    Remove-Variable WfReg, WfDrives, WfPartitionFails, WfPnp, WfEvents, WfEventCalls, WfPhysical, WfCounters -Scope Global -ErrorAction SilentlyContinue
    Remove-WinForgeTestData
}

Describe "Tempo ligado" {
    It "desconhecido quando o Windows não informa o boot (nulo ou data inválida)" {
        Get-WinForgeUptimeText -LastBootTime $null | Should -Be "Desconhecido"
        Get-WinForgeUptimeText -LastBootTime ([datetime]::MinValue) | Should -Be "Desconhecido"
    }

    It "formata <Name>" -ForEach @(
        @{ Name = "30 segundos"; Offset = [TimeSpan]::FromSeconds(30); Expected = "menos de 1 minuto" },
        @{ Name = "1 minuto"; Offset = [TimeSpan]::FromSeconds(75); Expected = "1 minuto" },
        @{ Name = "45 minutos"; Offset = [TimeSpan]::FromMinutes(45.5); Expected = "45 minutos" },
        @{ Name = "1 hora exata"; Offset = [TimeSpan]::FromMinutes(60.5); Expected = "1 hora" },
        @{ Name = "2 horas e 5 minutos"; Offset = [TimeSpan]::FromMinutes(125.5); Expected = "2 horas, 5 minutos" },
        @{ Name = "1 dia"; Offset = [TimeSpan]::FromHours(24.01); Expected = "1 dia" },
        @{ Name = "3 dias e 5 minutos"; Offset = ([TimeSpan]::FromDays(3) + [TimeSpan]::FromMinutes(5.5)); Expected = "3 dias, 5 minutos" },
        @{ Name = "relógio no futuro"; Offset = [TimeSpan]::FromHours(-2); Expected = "menos de 1 minuto" }
    ) {
        Get-WinForgeUptimeText -LastBootTime ((Get-Date) - $Offset) | Should -Be $Expected
    }
}

Describe "Tipo do disco" {
    It "classifica pelo barramento e pelo tipo de mídia" -ForEach @(
        @{ Bus = "NVMe"; Media = "SSD"; Expected = "NVMe" },
        @{ Bus = "SATA"; Media = "SSD"; Expected = "SSD" },
        @{ Bus = "SATA"; Media = "HDD"; Expected = "HDD" },
        @{ Bus = "USB"; Media = "Unspecified"; Expected = "USB" },
        @{ Bus = "SATA"; Media = "Unspecified"; Expected = "SATA" },
        @{ Bus = "RAID"; Media = "Unspecified"; Expected = "RAID" },
        @{ Bus = "Unknown"; Media = "Unspecified"; Expected = "Não disponível" },
        @{ Bus = $null; Media = $null; Expected = "Não disponível" }
    ) {
        Get-WinForgeDiskTypeText -Disk ([PSCustomObject]@{ BusType = $Bus; MediaType = $Media }) | Should -Be $Expected
    }

    It "sem disco ou sem propriedades: Não disponível" {
        Get-WinForgeDiskTypeText -Disk $null | Should -Be "Não disponível"
        Get-WinForgeDiskTypeText -Disk ([PSCustomObject]@{ Outra = 1 }) | Should -Be "Não disponível"
    }
}

Describe "Saúde do disco" {
    It "gera notas para disco com problemas e nenhuma para disco saudável" {
        $healthy = [PSCustomObject]@{ HealthStatus = "Healthy"; Wear = 5; Temperature = 38; ReadErrorsUncorrected = 0; WriteErrorsUncorrected = 0 }
        $failing = [PSCustomObject]@{ HealthStatus = "Warning"; Wear = 90; Temperature = 75; ReadErrorsUncorrected = 2; WriteErrorsUncorrected = 0 }

        @(Get-WinForgeDiskHealthNotes -Disk $healthy) | Should -HaveCount 0
        @(Get-WinForgeDiskHealthNotes -Disk $failing) | Should -HaveCount 4
    }

    It "respeita os limites: desgaste 80, temperatura 70" -ForEach @(
        @{ Wear = 79; Temp = 69; Count = 0 },
        @{ Wear = 80; Temp = 69; Count = 1 },
        @{ Wear = 79; Temp = 70; Count = 1 },
        @{ Wear = 80; Temp = 70; Count = 2 }
    ) {
        $disk = [PSCustomObject]@{ HealthStatus = "Healthy"; Wear = $Wear; Temperature = $Temp; ReadErrorsUncorrected = 0; WriteErrorsUncorrected = 0 }
        @(Get-WinForgeDiskHealthNotes -Disk $disk) | Should -HaveCount $Count
    }

    It "contadores ausentes (disco USB ou virtual) não geram nota nem erro" {
        $disk = [PSCustomObject]@{ HealthStatus = "Healthy"; Wear = $null; Temperature = $null; ReadErrorsUncorrected = $null; WriteErrorsUncorrected = $null }
        @(Get-WinForgeDiskHealthNotes -Disk $disk) | Should -HaveCount 0
    }

    It "estado vazio não vira alerta; estado diferente de Healthy vira" {
        @(Get-WinForgeDiskHealthNotes -Disk ([PSCustomObject]@{ HealthStatus = ""; Wear = $null; Temperature = $null; ReadErrorsUncorrected = $null; WriteErrorsUncorrected = $null })) | Should -HaveCount 0
        @(Get-WinForgeDiskHealthNotes -Disk ([PSCustomObject]@{ HealthStatus = "Unhealthy"; Wear = $null; Temperature = $null; ReadErrorsUncorrected = $null; WriteErrorsUncorrected = $null })) | Should -HaveCount 1
    }
}

Describe "Eventos" {
    It "agrupa eventos e coloca os que têm explicação primeiro" {
        $now = Get-Date
        $events = @(
            [PSCustomObject]@{ ProviderName = "Foo"; Id = 1; TimeCreated = $now },
            [PSCustomObject]@{ ProviderName = "Foo"; Id = 1; TimeCreated = $now },
            [PSCustomObject]@{ ProviderName = "Foo"; Id = 1; TimeCreated = $now },
            [PSCustomObject]@{ ProviderName = "Microsoft-Windows-Kernel-Power"; Id = 41; TimeCreated = $now }
        )

        $summary = @(ConvertTo-WinForgeEventSummary -Events $events)

        $summary[0].Provider | Should -Be "Microsoft-Windows-Kernel-Power"
        $summary[1].Count | Should -Be 3
    }

    It "o mesmo provedor com IDs diferentes forma grupos diferentes; mostra o último horário" {
        $old = (Get-Date).AddDays(-3)
        $new = (Get-Date).AddHours(-1)
        $events = @(
            [PSCustomObject]@{ ProviderName = "Foo"; Id = 1; TimeCreated = $old },
            [PSCustomObject]@{ ProviderName = "Foo"; Id = 1; TimeCreated = $new },
            [PSCustomObject]@{ ProviderName = "Foo"; Id = 2; TimeCreated = $old }
        )

        $summary = @(ConvertTo-WinForgeEventSummary -Events $events)

        $summary | Should -HaveCount 2
        ($summary | Where-Object { $_.Id -eq 1 }).Last | Should -Be $new
    }

    It "sem eventos, com nulos ou entrada nula: lista vazia" {
        @(ConvertTo-WinForgeEventSummary -Events @()) | Should -HaveCount 0
        @(ConvertTo-WinForgeEventSummary -Events $null) | Should -HaveCount 0
        @(ConvertTo-WinForgeEventSummary -Events @($null, $null)) | Should -HaveCount 0
    }

    It "limita a quantidade de grupos" {
        $now = Get-Date
        $events = @(1..30 | ForEach-Object { [PSCustomObject]@{ ProviderName = "P$_"; Id = $_; TimeCreated = $now } })
        @(ConvertTo-WinForgeEventSummary -Events $events -Top 5) | Should -HaveCount 5
    }

    It "explica os eventos conhecidos e deixa os demais sem dica" -ForEach @(
        @{ Provider = "Microsoft-Windows-Kernel-Power"; Id = 41; Hint = $true },
        @{ Provider = "Microsoft-Windows-WHEA-Logger"; Id = 17; Hint = $true },
        @{ Provider = "disk"; Id = 7; Hint = $true },
        @{ Provider = "Ntfs"; Id = 55; Hint = $true },
        @{ Provider = "Service Control Manager"; Id = 7001; Hint = $true },
        @{ Provider = "Service Control Manager"; Id = 7034; Hint = $true },
        @{ Provider = "Service Control Manager"; Id = 7040; Hint = $false },
        @{ Provider = "Foo[1]*"; Id = 5; Hint = $false },
        @{ Provider = ""; Id = 0; Hint = $false }
    ) {
        $text = Get-WinForgeEventHint -Provider $Provider -Id $Id

        if ($Hint) { $text | Should -Not -BeNullOrEmpty } else { $text | Should -BeNullOrEmpty }
    }
}

Describe "Reinício pendente" {
    It "detecta renomeação do computador e marca arquivos pendentes como sinal fraco" {
        $global:WfReg = @{
            "HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ActiveComputerName|ComputerName" = "PC-ANTIGO"
            "HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName|ComputerName"       = "PC-NOVO"
            "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager|PendingFileRenameOperations"  = @("\??\C:\a", "")
        }

        Set-TestStub -Name "Get-WinForgeRegistryValueOrNull" -Body {
            param ($Path, $Name)
            $key = "$Path|$Name"
            if ($global:WfReg.ContainsKey($key)) { $global:WfReg[$key] } else { $null }
        }

        try {
            $reasons = @(Get-WinForgePendingReboot)

            $rename = @($reasons | Where-Object { $_.Reason -like "Renomea*" })
            $files = @($reasons | Where-Object { $_.Reason -like "Arquivos aguardando*" })

            $rename | Should -HaveCount 1
            $rename[0].Strong | Should -BeTrue
            $files | Should -HaveCount 1
            $files[0].Strong | Should -BeFalse

            $global:WfReg.Clear()
            @(Get-WinForgePendingReboot | Where-Object { $_.Reason -like "Renomea*" -or $_.Reason -like "Arquivos aguardando*" }) | Should -HaveCount 0
        }
        finally { Clear-TestStubs }
    }

    It "nomes iguais ou ausentes não indicam renomeação" {
        $global:WfReg = @{
            "HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ActiveComputerName|ComputerName" = "PC"
            "HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName|ComputerName"       = "PC"
        }

        Set-TestStub -Name "Get-WinForgeRegistryValueOrNull" -Body {
            param ($Path, $Name)
            $key = "$Path|$Name"
            if ($global:WfReg.ContainsKey($key)) { $global:WfReg[$key] } else { $null }
        }

        try {
            @(Get-WinForgePendingReboot | Where-Object { $_.Reason -like "Renomea*" }) | Should -HaveCount 0
        }
        finally { Clear-TestStubs }
    }
}

Describe "Dispositivos com problema" {
    It "<Name>" -ForEach @(
        @{ Name = "código de problema real é problema"; Status = "Error"; Problem = "CM_PROB_FAILED_INSTALL"; Expected = $true },
        @{ Name = "código de problema sem status Error também"; Status = "Unknown"; Problem = "CM_PROB_FAILED_ADD"; Expected = $true },
        @{ Name = "dispositivo desativado é reportado (a tela separa depois)"; Status = "Error"; Problem = "CM_PROB_DISABLED"; Expected = $true },
        @{ Name = "status Degraded é problema"; Status = "Degraded"; Problem = $null; Expected = $true },
        @{ Name = "tudo OK não é problema"; Status = "OK"; Problem = "CM_PROB_NONE"; Expected = $false },
        @{ Name = "problema 0 não é problema"; Status = "OK"; Problem = 0; Expected = $false },
        @{ Name = "Unknown sem código não é problema"; Status = "Unknown"; Problem = $null; Expected = $false },
        @{ Name = "Unknown com CM_PROB_NONE não é problema"; Status = "Unknown"; Problem = "CM_PROB_NONE"; Expected = $false }
    ) {
        Test-WinForgePnpDeviceHasProblem -Device ([PSCustomObject]@{ Status = $Status; Problem = $Problem }) | Should -Be $Expected
    }
}

Describe "Discos e espaço livre" {
    BeforeAll {
        function script:Use-DiskStubs {
            param ([object[]]$Drives, [switch]$PartitionFails, [switch]$CimFails)

            $global:WfDrives = @($Drives)
            $global:WfPartitionFails = [bool]$PartitionFails

            Set-TestStub -Name "Get-CimInstance" -Body {
                [CmdletBinding()] param ([Parameter(Position = 0)][string]$ClassName, [string]$Filter)
                $global:WfDrives
            }
            Set-TestStub -Name "Get-Partition" -Body {
                [CmdletBinding()] param ($DriveLetter)
                if ($global:WfPartitionFails) { throw "sem partição" }
                [PSCustomObject]@{ DriveLetter = $DriveLetter }
            }
            Set-TestStub -Name "Get-Disk" -Body {
                [CmdletBinding()] param ([Parameter(ValueFromPipeline)]$InputObject)
                process { [PSCustomObject]@{ FriendlyName = "Disco do $($InputObject.DriveLetter)"; BusType = "NVMe"; MediaType = "SSD" } }
            }
            if ($CimFails) { Set-TestStub -Name "Get-CimInstance" -Body { [CmdletBinding()] param ([Parameter(Position = 0)][string]$ClassName, [string]$Filter) throw "WMI com defeito" } }
        }

        function script:New-Drive {
            param ([string]$Id, [double]$Free, [double]$Size)
            [PSCustomObject]@{ DeviceID = $Id; FreeSpace = [double]$Free; Size = [double]$Size }
        }
    }

    AfterEach { Clear-TestStubs; Clear-FakeReadHost }

    It "classifica cada unidade pela mesma regra da tela inicial: Ok, pouco espaço e crítico" {
        Use-DiskStubs -Drives @(
            (New-Drive "C:" (300GB) (500GB)),
            (New-Drive "D:" (40GB) (500GB)),
            (New-Drive "E:" (2GB) (100GB))
        )

        $disks = @(Get-WinForgeDiskSummary)

        (@($disks.Nivel) -join ",") | Should -Be "Ok,Low,Critical"
        $disks[0].Tipo | Should -Be "NVMe"
        $disks[0].Modelo | Should -Be "Disco do C"
        $disks[0].Uso | Should -Be "40%"
    }

    It "só avisa das unidades com pouco espaço e indica a página Limpeza" {
        Use-DiskStubs -Drives @((New-Drive "C:" (300GB) (500GB)), (New-Drive "D:" (40GB) (500GB)))
        Set-FakeReadHost -Answers @("")

        $text = Get-HostText { Show-WinForgeDisks }

        $text | Should -Match "A unidade D: está quase cheia"
        $text | Should -Not -Match "A unidade C: está quase cheia"
        $text | Should -Match ("página " + [regex]::Escape((Get-WinForgeNavPage -Id "cleanup").Title))
    }

    It "com todas as unidades saudáveis, não mostra aviso nenhum" {
        Use-DiskStubs -Drives @((New-Drive "C:" (300GB) (500GB)))
        Set-FakeReadHost -Answers @("")

        $text = Get-HostText { Show-WinForgeDisks }

        $text | Should -Not -Match "quase cheia"
        $text | Should -Not -Match "Limpeza"
    }

    It "unidade sem tamanho informado (virtual) não gera aviso nem divisão por zero" {
        Use-DiskStubs -Drives @((New-Drive "Z:" 0 0))

        $disk = @(Get-WinForgeDiskSummary)[0]

        $disk.Nivel | Should -Be "Unknown"
        $disk.Uso | Should -Be "Não disponível"
        $disk.Total | Should -Be "Não disponível"
    }

    It "sem associar a unidade a um disco, tipo e modelo ficam indisponíveis (nunca emprestados de outro disco)" {
        Use-DiskStubs -Drives @((New-Drive "C:" (300GB) (500GB))) -PartitionFails

        $disk = @(Get-WinForgeDiskSummary)[0]

        $disk.Tipo | Should -Be "Não disponível"
        $disk.Modelo | Should -Be "Não disponível"
        $disk.Nivel | Should -Be "Ok"
    }

    It "falha ao consultar o Windows vira mensagem, sem exceção" {
        Use-DiskStubs -Drives @() -CimFails
        Set-FakeReadHost -Answers @("")

        @(Get-WinForgeDiskSummary) | Should -HaveCount 0
        (Get-HostText { Show-WinForgeDisks }) | Should -Match "Não foi possível detectar informações de disco"
    }
}

Describe "Telas de diagnóstico" {
    AfterEach { Clear-TestStubs; Clear-FakeReadHost; Remove-Variable WinForgeGuiMode -Scope Global -ErrorAction SilentlyContinue }

    It "dispositivos: separa problemas reais dos desativados e explica que desativados podem ser intencionais" {
        $global:WfPnp = @(
            [PSCustomObject]@{ Status = "Error"; Class = "Net"; FriendlyName = "Placa de rede"; Problem = "CM_PROB_FAILED_INSTALL"; InstanceId = "A" },
            [PSCustomObject]@{ Status = "Error"; Class = "Display"; FriendlyName = "GPU integrada"; Problem = "CM_PROB_DISABLED"; InstanceId = "B" },
            [PSCustomObject]@{ Status = "OK"; Class = "USB"; FriendlyName = "Mouse"; Problem = "CM_PROB_NONE"; InstanceId = "C" }
        )
        Set-TestStub -Name "Get-PnpDevice" -Body { [CmdletBinding()] param ([switch]$PresentOnly) $global:WfPnp }
        Set-FakeReadHost -Answers @("")

        $text = Get-HostText { Show-WinForgeProblemDevices }

        $text | Should -Match "Problemas ativos"
        $text | Should -Match "Dispositivos desativados"
        $text | Should -Match "podem ser intencionais"
        $text | Should -Not -Match "Nenhum dispositivo presente com problema real"
    }

    It "dispositivos: sem problema nenhum, diz que está tudo bem e não cria a seção de desativados" {
        $global:WfPnp = @([PSCustomObject]@{ Status = "OK"; Class = "USB"; FriendlyName = "Mouse"; Problem = "CM_PROB_NONE"; InstanceId = "C" })
        Set-TestStub -Name "Get-PnpDevice" -Body { [CmdletBinding()] param ([switch]$PresentOnly) $global:WfPnp }
        Set-FakeReadHost -Answers @("")

        $text = Get-HostText { Show-WinForgeProblemDevices }

        $text | Should -Match "Nenhum dispositivo presente com problema real"
        $text | Should -Not -Match "Dispositivos desativados"
    }

    It "dispositivos: um erro do Windows vira mensagem, não exceção" {
        Set-TestStub -Name "Get-PnpDevice" -Body { [CmdletBinding()] param ([switch]$PresentOnly) throw "serviço PnP parado" }
        Set-FakeReadHost -Answers @("")

        (Get-HostText { Show-WinForgeProblemDevices }) | Should -Match "Ocorreu um erro ao consultar dispositivos PnP: serviço PnP parado"
    }

    It "eventos críticos: sem eventos, diz que não houve nenhum" {
        $global:WfEvents = @()
        Set-TestStub -Name "Get-WinEvent" -Body { [CmdletBinding()] param ($FilterHashtable, $MaxEvents) $global:WfEvents }
        Set-FakeReadHost -Answers @("")

        (Get-HostText { Show-WinForgeCriticalEvents }) | Should -Match "Nenhum evento crítico ou de erro nos últimos 7 dias"
    }

    It "eventos críticos: o Windows dizendo 'nenhum evento' (erro) é o caso comum e não vira falha" {
        Set-TestStub -Name "Get-WinEvent" -Body { [CmdletBinding()] param ($FilterHashtable, $MaxEvents) throw "No events were found that match the specified selection criteria." }
        Set-FakeReadHost -Answers @("")

        $text = Get-HostText { Show-WinForgeCriticalEvents }

        $text | Should -Match "Nenhum evento crítico"
        $text | Should -Not -Match "Ocorreu um erro|Não foi possível|\[ERRO\]|\[!\]"
    }

    It "eventos críticos: pede ao Windows o limite de leitura e o período de sete dias" {
        $global:WfEventCalls = New-Object System.Collections.ArrayList
        Set-TestStub -Name "Get-WinEvent" -Body {
            [CmdletBinding()] param ($FilterHashtable, $MaxEvents)
            [void]$global:WfEventCalls.Add([PSCustomObject]@{ Max = $MaxEvents; Start = $FilterHashtable.StartTime; Levels = ($FilterHashtable.Level -join ",") })
            @()
        }

        [void](Get-WinForgeRecentCriticalEvents -Days 7 -MaxEvents 500)

        $global:WfEventCalls[0].Max | Should -Be 500
        $global:WfEventCalls[0].Levels | Should -Be "1,2"
        ((Get-Date) - $global:WfEventCalls[0].Start).TotalDays | Should -BeGreaterThan 6.9
        ((Get-Date) - $global:WfEventCalls[0].Start).TotalDays | Should -BeLessThan 7.1
    }

    It "eventos críticos: mostra os 12 grupos mais relevantes e avisa quantos ficaram de fora" {
        $now = Get-Date
        $global:WfEvents = @(1..20 | ForEach-Object { [PSCustomObject]@{ ProviderName = "Origem$_"; Id = $_; TimeCreated = $now } })
        Set-TestStub -Name "Get-WinEvent" -Body { [CmdletBinding()] param ($FilterHashtable, $MaxEvents) $global:WfEvents }
        Set-FakeReadHost -Answers @("")

        $text = Get-HostText { Show-WinForgeCriticalEvents }

        $text | Should -Match "20 evento\(s\) de erro/crítico"
        $text | Should -Match "e mais 8 grupo\(s\)"
        $text | Should -Match "Visualizador de Eventos"
    }

    It "eventos críticos: ao chegar no limite de leitura, diz 'pelo menos' em vez de afirmar o total" {
        $now = Get-Date
        $global:WfEvents = @(1..3000 | ForEach-Object { [PSCustomObject]@{ ProviderName = "Barulhento"; Id = 1; TimeCreated = $now } })
        Set-TestStub -Name "Get-WinEvent" -Body { [CmdletBinding()] param ($FilterHashtable, $MaxEvents) $global:WfEvents }
        Set-FakeReadHost -Answers @("")

        $text = Get-HostText { Show-WinForgeCriticalEvents }

        $text | Should -Match "pelo menos 3000"
        $text | Should -Match "3000x"
    }

    It "eventos críticos: eventos conhecidos mostram a dica com o nome da tela certa" {
        $now = Get-Date
        $global:WfEvents = @([PSCustomObject]@{ ProviderName = "Ntfs"; Id = 55; TimeCreated = $now })
        Set-TestStub -Name "Get-WinEvent" -Body { [CmdletBinding()] param ($FilterHashtable, $MaxEvents) $global:WfEvents }
        Set-FakeReadHost -Answers @("")

        $text = Get-HostText { Show-WinForgeCriticalEvents }

        $text | Should -Match "Ntfs \(ID 55\)"
        $text | Should -Match ([regex]::Escape("$((Get-WinForgeNavPage -Id 'repair').Title) > $((Get-WinForgeNavItem -Id 'repair.chkdsk').Label)"))
    }

    It "saúde dos discos: lista o disco com alertas e o que está saudável" {
        $global:WfPhysical = @(
            [PSCustomObject]@{ FriendlyName = "SSD velho"; Size = 500GB; HealthStatus = "Warning"; BusType = "NVMe"; MediaType = "SSD" },
            [PSCustomObject]@{ FriendlyName = "HD novo"; Size = 1000GB; HealthStatus = "Healthy"; BusType = "SATA"; MediaType = "HDD" }
        )
        $global:WfCounters = @{ "SSD velho" = [PSCustomObject]@{ Temperature = 75; Wear = 85; PowerOnHours = 9000; ReadErrorsUncorrected = 0; WriteErrorsUncorrected = 0 } }

        Set-TestStub -Name "Get-PhysicalDisk" -Body { [CmdletBinding()] param () $global:WfPhysical }
        Set-TestStub -Name "Get-StorageReliabilityCounter" -Body {
            [CmdletBinding()] param ([Parameter(ValueFromPipeline)]$InputObject)
            process {
                if (-not $global:WfCounters.ContainsKey($InputObject.FriendlyName)) { throw "sem contadores" }
                $global:WfCounters[$InputObject.FriendlyName]
            }
        }
        Set-FakeReadHost -Answers @("")

        $text = Get-HostText { Show-WinForgeDiskHealth }

        $text | Should -Match "SSD velho"
        $text | Should -Match "Desgaste do SSD em 85%"
        $text | Should -Match "75 °C"
        $text | Should -Match "Estado do disco: Warning"
        $text | Should -Match "HD novo"
        $text | Should -Match "Nenhum alerta para este disco"
        $text | Should -Match "não substitui um teste SMART"
    }

    It "saúde dos discos: sem leitura possível, explica e não quebra" {
        Set-TestStub -Name "Get-PhysicalDisk" -Body { [CmdletBinding()] param () throw "sem acesso" }
        Set-FakeReadHost -Answers @("")

        (Get-HostText { Show-WinForgeDiskHealth }) | Should -Match "Não foi possível ler a saúde dos discos"
    }

    It "reinício pendente: <Name>" -ForEach @(
        @{ Name = "nada pendente"; Reg = @{}; Match = "Nenhum reinício pendente"; NotMatch = "Reinicie|fracos" },
        @{ Name = "só sinal fraco: provavelmente não é obrigatório"; Reg = @{ "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager|PendingFileRenameOperations" = @("\??\C:\a") }; Match = "Somente sinais fracos"; NotMatch = "Reinicie o Windows antes" },
        @{ Name = "sinal forte: manda reiniciar antes de reparos"; Reg = @{ "HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ActiveComputerName|ComputerName" = "A"; "HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName|ComputerName" = "B" }; Match = "Reinicie o Windows antes de reparos"; NotMatch = "fracos" }
    ) {
        $global:WfReg = $Reg
        Set-TestStub -Name "Get-WinForgeRegistryValueOrNull" -Body {
            param ($Path, $Name)
            $key = "$Path|$Name"
            if ($global:WfReg.ContainsKey($key)) { $global:WfReg[$key] } else { $null }
        }
        Set-FakeReadHost -Answers @("")

        $text = Get-HostText { Show-WinForgePendingReboot }

        $text | Should -Match $Match
        $text | Should -Not -Match $NotMatch
    }

    It "o título da tela aparece no console e some dentro da janela, que já o mostra no topo" {
        Set-TestStub -Name "Get-PhysicalDisk" -Body { [CmdletBinding()] param () throw "sem acesso" }
        Set-FakeReadHost -Answers @("", "")

        (Get-HostText { Show-WinForgeDiskHealth }) | Should -MatchExactly "(?m)^\s*Saúde dos discos\s*$"

        $global:WinForgeGuiMode = $true
        (Get-HostText { Show-WinForgeDiskHealth }) | Should -Not -MatchExactly "(?m)^\s*Saúde dos discos\s*$"
    }
}

Describe "Programas que abrem com o Windows" {
    BeforeEach {
        $global:WfRegistryKeys = @{}
        Set-TestStub -Name "Get-WinForgeRegistryValues" -Body {
            param ($Path)
            $values = [ordered]@{}
            if ($global:WfRegistryKeys.ContainsKey($Path)) { foreach ($key in $global:WfRegistryKeys[$Path].Keys) { $values[$key] = $global:WfRegistryKeys[$Path][$key] } }
            $values
        }
    }

    AfterEach {
        Clear-TestStubs
        Remove-Variable WfRegistryKeys -Scope Global -ErrorAction SilentlyContinue
    }

    It "junta as chaves Run (usuário, todos os usuários e 32 bits) e as pastas Inicializar" {
        $user = Join-Path $script:TestDataRoot "inicializar-usuario"
        $common = Join-Path $script:TestDataRoot "inicializar-todos"
        New-Item -ItemType Directory -Path $user, $common -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $user "Atalho.lnk") -Value "x"
        Set-Content -LiteralPath (Join-Path $user "desktop.ini") -Value "x"
        Set-Content -LiteralPath (Join-Path $common "Outro.lnk") -Value "x"

        $global:WfRegistryKeys["HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"] = @{ Chat = "c.exe"; Nuvem = "n.exe" }
        $global:WfRegistryKeys["HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"] = @{ Audio = "a.exe" }
        $global:WfRegistryKeys["HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run"] = @{ Legado = "l.exe" }

        $items = @(Get-WinForgeStartupItems -UserFolder $user -CommonFolder $common)

        $items | Should -HaveCount 6
        ($items.Name | Sort-Object) -join "," | Should -Be "Atalho.lnk,Audio,Chat,Legado,Nuvem,Outro.lnk"
        @($items | Where-Object { -not $_.Enabled }) | Should -HaveCount 0
        ($items | Where-Object { $_.Name -eq "desktop.ini" }) | Should -BeNullOrEmpty
    }

    It "o que foi desativado em Aplicativos de inicialização (primeiro byte ímpar) não conta como ativo" {
        $user = Join-Path $script:TestDataRoot "inicializar-usuario-2"
        New-Item -ItemType Directory -Path $user -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $user "Atalho.lnk") -Value "x"

        $approvedRoot = "Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved"
        $global:WfRegistryKeys["HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"] = @{ Chat = "c.exe"; Nuvem = "n.exe"; Antigo = "o.exe" }
        $global:WfRegistryKeys["HKCU:\$approvedRoot\Run"] = @{ Chat = [byte[]](3, 0, 0, 0); Nuvem = [byte[]](2, 0, 0, 0); Antigo = [byte[]](7, 0, 0, 0) }
        $global:WfRegistryKeys["HKCU:\$approvedRoot\StartupFolder"] = @{ "Atalho.lnk" = [byte[]](3, 0, 0, 0) }

        $items = @(Get-WinForgeStartupItems -UserFolder $user -CommonFolder "")

        ($items | Where-Object { $_.Enabled }).Name | Should -Be @("Nuvem")
        @($items | Where-Object { -not $_.Enabled }) | Should -HaveCount 3
    }

    It "pastas inexistentes, vazias ou sem registro: lista vazia e sem erro" {
        { $null = Get-WinForgeStartupItems -UserFolder (Join-Path $script:TestDataRoot "nao-existe") -CommonFolder "" } | Should -Not -Throw
        @(Get-WinForgeStartupItems -UserFolder "" -CommonFolder "") | Should -HaveCount 0
    }
}


Describe "Saúde da bateria" {
    BeforeAll {
        # Formato do relatório do "powercfg /batteryreport /xml": namespace próprio e as capacidades em mWh.
        $script:BatteryXml = @'
<?xml version="1.0" encoding="utf-8"?>
<BatteryReport xmlns="http://schemas.microsoft.com/battery/2012">
  <ReportInformation><ReportVersion>1.1</ReportVersion></ReportInformation>
  <Batteries>
    <Battery>
      <Id>DELL 1A2B3C</Id>
      <Manufacturer>SMP</Manufacturer>
      <Chemistry>LION</Chemistry>
      <DesignCapacity>57000</DesignCapacity>
      <FullChargeCapacity>45600</FullChargeCapacity>
      <CycleCount>312</CycleCount>
    </Battery>
  </Batteries>
</BatteryReport>
'@

        function script:Use-BatteryStubs {
            param ([string]$Xml = "", [int]$ExitCode = 0, [switch]$PowercfgThrows, $Wmi = $null, [switch]$NoBattery, [int]$Charge = 80, [int]$Status = 2)

            $global:WfBatteryXml = $Xml
            $global:WfBatteryExit = $ExitCode
            $global:WfBatteryThrows = [bool]$PowercfgThrows
            $global:WfBatteryWmi = $Wmi
            $global:WfBatteryNone = [bool]$NoBattery
            $global:WfBatteryCharge = $Charge
            $global:WfBatteryStatus = $Status
            $global:WfBatteryPaths = New-Object System.Collections.ArrayList

            Set-TestStub -Name "Invoke-WinForgeCapture" -Body {
                param ($FilePath, $Arguments, [switch]$Echo)

                if ($global:WfBatteryThrows) { throw "powercfg.exe não encontrado" }

                $path = $Arguments[($Arguments.IndexOf("/output") + 1)]
                [void]$global:WfBatteryPaths.Add($path)

                if ($global:WfBatteryXml) { Set-Content -LiteralPath $path -Value $global:WfBatteryXml -Encoding UTF8 }

                [PSCustomObject]@{ ExitCode = $global:WfBatteryExit; Lines = @(); Text = "" }
            }

            Set-TestStub -Name "Get-CimInstance" -Body {
                [CmdletBinding()]
                param ($ClassName, $Namespace)

                if ($ClassName -eq "Win32_Battery") {
                    if ($global:WfBatteryNone) { return @() }
                    return [PSCustomObject]@{ BatteryStatus = $global:WfBatteryStatus; EstimatedChargeRemaining = $global:WfBatteryCharge }
                }

                if ($Namespace -eq "root\wmi" -and $null -ne $global:WfBatteryWmi) { return $global:WfBatteryWmi[$ClassName] }

                throw "classe indisponível"
            }
        }
    }

    AfterEach {
        Clear-TestStubs
        Clear-FakeReadHost
        Remove-Variable WinForgeGuiMode, WfBatteryXml, WfBatteryExit, WfBatteryThrows, WfBatteryWmi, WfBatteryNone, WfBatteryCharge, WfBatteryStatus, WfBatteryPaths -Scope Global -ErrorAction SilentlyContinue
    }

    It "lê o relatório do powercfg: capacidades, ciclos e saúde em porcentagem" {
        $reading = @(ConvertFrom-WinForgeBatteryReport -Text $script:BatteryXml)

        $reading | Should -HaveCount 1
        $reading[0].DesignMwh | Should -Be 57000
        $reading[0].FullMwh | Should -Be 45600
        $reading[0].Cycles | Should -Be 312
        $reading[0].HealthPercent | Should -Be 80
        $reading[0].Name | Should -Match "SMP"
    }

    It "lê duas baterias, e um XML sem baterias devolve lista vazia" {
        $two = $script:BatteryXml -replace "</Batteries>", "<Battery><Id>B2</Id><DesignCapacity>30000</DesignCapacity><FullChargeCapacity>15000</FullChargeCapacity></Battery></Batteries>"

        @(ConvertFrom-WinForgeBatteryReport -Text $two) | Should -HaveCount 2
        @(ConvertFrom-WinForgeBatteryReport -Text "<BatteryReport><Batteries/></BatteryReport>") | Should -HaveCount 0
    }

    It "campos ausentes ou com texto viram nulo, sem dividir por zero" {
        $xml = "<BatteryReport><Batteries><Battery><Id>X</Id><DesignCapacity>0</DesignCapacity><FullChargeCapacity>abc</FullChargeCapacity></Battery></Batteries></BatteryReport>"
        $reading = @(ConvertFrom-WinForgeBatteryReport -Text $xml)

        $reading[0].FullMwh | Should -BeNullOrEmpty
        $reading[0].Cycles | Should -BeNullOrEmpty
        $reading[0].HealthPercent | Should -BeNullOrEmpty
    }

    It "XML inválido lança erro (quem chama cai no plano B)" {
        { ConvertFrom-WinForgeBatteryReport -Text "isto não é xml" } | Should -Throw
    }

    It "a saúde nunca passa de 100% (bateria nova com calibração generosa)" {
        (New-WinForgeBatteryReading -DesignMwh 50000 -FullMwh 53000).HealthPercent | Should -Be 100
    }

    It "avaliação do desgaste: <Health>% -> <Level>" -ForEach @(
        @{ Health = 100; Level = "Success" }, @{ Health = 80; Level = "Success" }, @{ Health = 79; Level = "Info" },
        @{ Health = 60; Level = "Info" }, @{ Health = 59; Level = "Warning" }, @{ Health = 20; Level = "Warning" },
        @{ Health = $null; Level = "Info" }
    ) {
        (Get-WinForgeBatteryAssessment -HealthPercent $Health).Level | Should -Be $Level
    }

    It "usa o powercfg, grava o relatório numa pasta temporária e apaga o arquivo depois" {
        Use-BatteryStubs -Xml $script:BatteryXml

        $found = Get-WinForgeBatteryReadings

        $found.Source | Should -Be "powercfg"
        @($found.Readings) | Should -HaveCount 1
        $global:WfBatteryPaths | Should -HaveCount 1
        Test-Path -LiteralPath $global:WfBatteryPaths[0] | Should -BeFalse
        Split-Path -Parent $global:WfBatteryPaths[0] | Should -Be ([System.IO.Path]::GetTempPath().TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar))
    }

    It "powercfg com erro, ausente ou com XML ilegível: cai no WMI" -ForEach @(
        @{ Case = "código de saída 1"; Xml = ""; ExitCode = 1; Throws = $false },
        @{ Case = "programa ausente"; Xml = ""; ExitCode = 0; Throws = $true },
        @{ Case = "XML ilegível"; Xml = "lixo"; ExitCode = 0; Throws = $false }
    ) {
        $wmi = @{
            BatteryStaticData          = @([PSCustomObject]@{ InstanceName = "ACPI\1"; DeviceName = "BAT0"; DesignedCapacity = 40000 })
            BatteryFullChargedCapacity = @([PSCustomObject]@{ InstanceName = "ACPI\1"; FullChargedCapacity = 30000 })
            BatteryCycleCount          = @([PSCustomObject]@{ InstanceName = "ACPI\1"; CycleCount = 150 })
        }
        Use-BatteryStubs -Xml $Xml -ExitCode $ExitCode -PowercfgThrows:$Throws -Wmi $wmi

        $found = Get-WinForgeBatteryReadings

        $found.Source | Should -Be "wmi"
        $found.Readings[0].HealthPercent | Should -Be 75
        $found.Readings[0].Cycles | Should -Be 150
    }

    It "ciclos zerados no WMI (o notebook não informa) viram nulo" {
        $wmi = @{
            BatteryStaticData          = @([PSCustomObject]@{ InstanceName = "A"; DeviceName = "BAT0"; DesignedCapacity = 40000 })
            BatteryFullChargedCapacity = @([PSCustomObject]@{ InstanceName = "A"; FullChargedCapacity = 40000 })
            BatteryCycleCount          = @([PSCustomObject]@{ InstanceName = "A"; CycleCount = 0 })
        }
        Use-BatteryStubs -ExitCode 1 -Wmi $wmi

        (Get-WinForgeBatteryReadings).Readings[0].Cycles | Should -BeNullOrEmpty
    }

    It "nem powercfg nem WMI: lista vazia e origem vazia" {
        Use-BatteryStubs -ExitCode 1

        $found = Get-WinForgeBatteryReadings

        @($found.Readings) | Should -HaveCount 0
        $found.Source | Should -Be ""
    }

    It "desktop: diz que não há bateria e nem chama o powercfg" {
        Use-BatteryStubs -NoBattery
        Set-FakeReadHost -Answers @("")

        $text = Get-HostText { Show-WinForgeBatteryHealth }

        $text | Should -Match "Saúde da bateria"
        $text | Should -Match "não tem bateria"
        $global:WfBatteryPaths | Should -HaveCount 0
    }

    It "notebook: mostra carga, situação, capacidade, saúde, ciclos e o veredito" {
        Use-BatteryStubs -Xml $script:BatteryXml -Charge 64 -Status 6
        Set-FakeReadHost -Answers @("")

        $text = Get-HostText { Show-WinForgeBatteryHealth }

        $text | Should -Match "64%"
        $text | Should -Match "Carregando"
        $text | Should -Match "57 Wh"
        $text | Should -Match "46 Wh"
        $text | Should -Match "80%"
        $text | Should -Match "312"
        $text | Should -Match "Bateria em bom estado"
    }

    It "bateria muito gasta mostra o aviso de troca" {
        $worn = $script:BatteryXml -replace "45600", "20000"
        Use-BatteryStubs -Xml $worn
        Set-FakeReadHost -Answers @("")

        $text = Get-HostText { Show-WinForgeBatteryHealth }

        $text | Should -Match "35%"
        $text | Should -Match "considerar a troca"
    }

    It "notebook que não informa a capacidade explica em vez de mostrar uma tela vazia" {
        Use-BatteryStubs -ExitCode 1
        Set-FakeReadHost -Answers @("")

        $text = Get-HostText { Show-WinForgeBatteryHealth }

        $text | Should -Match "não informou a capacidade"
    }

    It "o relatório ganha a seção Bateria em notebooks, e só neles" {
        Use-BatteryStubs -Xml $script:BatteryXml
        Set-TestStub -Name "Test-WinForgeLaptop" -Body { $true }

        $sections = @(Get-WinForgeReportSections)
        $battery = @($sections | Where-Object { $_.Title -eq "Bateria" })

        $battery | Should -HaveCount 1
        (($battery[0].Items | ForEach-Object { $_.Value }) -join " ") | Should -Match "46 Wh de 57 Wh"

        Set-TestStub -Name "Test-WinForgeLaptop" -Body { $false }
        @(Get-WinForgeReportSections | Where-Object { $_.Title -eq "Bateria" }) | Should -HaveCount 0
    }
}


Describe "Relatório" {
    It "escapa HTML nos valores, rótulos e títulos" {
        $sections = @(@{ Title = "Sistema <b>"; Items = @(@{ Label = "Nome & Cia"; Value = "<script>x</script> & y" }) })

        $html = ConvertTo-WinForgeHtmlReport -Sections $sections -Build "test"

        $html | Should -Match "&lt;script&gt;"
        $html | Should -Match "Nome &amp; Cia"
        $html | Should -Match "Sistema &lt;b&gt;"
        $html | Should -Not -Match "<script>x"
    }

    It "o relatório em texto lista seções e itens, sem quebrar com valores nulos" {
        $sections = @(
            @{ Title = "Sistema"; Items = @(@{ Label = "Computador"; Value = "PC-01" }, @{ Label = "Vazio"; Value = $null }) },
            @{ Title = "Vazia"; Items = @() }
        )

        $text = ConvertTo-WinForgeTextReport -Sections $sections -Build "x"

        $text | Should -Match "WinForge - Relatório \(build x\)"
        $text | Should -Match "Sistema\r?\n-------"
        $text | Should -Match "Computador\s+PC-01"
        $text | Should -Match "Vazia"
    }

    It "uma seção que falha vira um aviso e as demais continuam" {
        Set-TestStub -Name "Get-WinForgeDiskSummary" -Body { throw "WMI quebrado" }
        try {
            $sections = @(Get-WinForgeReportSections)

            ($sections.Title -join "|") | Should -Match "Sistema\|Hardware\|Discos\|Ajustes do Windows\|Eventos críticos"

            $disks = $sections | Where-Object { $_.Title -eq "Discos" }
            ($disks.Items | ForEach-Object { $_.Value }) -join " " | Should -Match "WMI quebrado"

            $system = $sections | Where-Object { $_.Title -eq "Sistema" }
            @($system.Items).Count | Should -BeGreaterThan 0
        }
        finally { Clear-TestStubs }
    }

    It "inclui a última manutenção quando existe" {
        Reset-LastMaintenanceMemory
        Set-WinForgeLastMaintenance -Results @((New-WinForgeResult -Kind Ok -Title "Limpeza")) -StartedAt (Get-Date)

        $sections = @(Get-WinForgeReportSections)

        @($sections | Where-Object { $_.Title -like "Última manutenção*" }) | Should -HaveCount 1
    }

    It "salva HTML e texto, criando a pasta (inclusive com colchetes no caminho)" {
        $directory = Join-Path ([IO.Path]::GetTempPath()) ("wf [relatorio] " + [guid]::NewGuid().ToString("N"))

        try {
            $report = Export-WinForgeReport -Directory $directory

            Test-Path -LiteralPath $report.Html | Should -BeTrue
            Test-Path -LiteralPath $report.Text | Should -BeTrue
            (Get-Content -LiteralPath $report.Html -Raw) | Should -Match "<h1>WinForge</h1>"
            (Get-Content -LiteralPath $report.Text -Raw) | Should -Match "WinForge - Relatório"
            (Split-Path -Leaf $report.Html) | Should -Match "^winforge-relatorio-[0-9]{8}-[0-9]{6}\.html$"
        }
        finally {
            Remove-Item -LiteralPath $directory -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
