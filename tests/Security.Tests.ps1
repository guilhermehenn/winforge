# Segurança: estado da proteção, assinaturas e verificação do Windows Defender.
# Os comandos do Defender (Get-MpComputerStatus, Start-MpScan...), o firewall e o Windows Update são substituídos por
# versões de teste que registram a chamada: nenhuma verificação de verdade é feita.

BeforeAll {
    . (Join-Path $PSScriptRoot "TestSetup.ps1")

    function script:New-MpStatus {
        param (
            [bool]$Service = $true,
            [bool]$Enabled = $true,
            [bool]$RealTime = $true,
            [string]$Mode = "Normal",
            [double]$SignatureDays = 0.5,
            [string]$Version = "1.421.100.0"
        )

        [PSCustomObject]@{
            AMServiceEnabled              = $Service
            AntivirusEnabled              = $Enabled
            RealTimeProtectionEnabled     = $RealTime
            AMRunningMode                 = $Mode
            AntivirusSignatureLastUpdated = (Get-Date).AddDays(-$SignatureDays)
            AntivirusSignatureVersion     = $Version
            QuickScanEndTime              = (Get-Date).AddDays(-2)
            FullScanEndTime               = [datetime]"1601-01-01"
        }
    }

    function script:Use-DefenderStubs {
        param (
            $Status = $null,
            [string[]]$OtherAntivirus = @(),
            $Firewall = $null,
            $Threats = @(),
            $Detections = @(),
            [switch]$NoStatus,
            [switch]$DetectionsFail,
            [switch]$UpdateFails,
            [switch]$ScanFails,
            [switch]$NotAdmin,
            $Updates = $null
        )

        if ($null -eq $Status) { $Status = New-MpStatus }

        $global:WfLog = New-Object System.Collections.ArrayList
        $global:WfMpStatus = $Status
        $global:WfMpNoStatus = [bool]$NoStatus
        $global:WfOtherAv = @($OtherAntivirus)
        $global:WfFirewall = $Firewall
        $global:WfThreats = @($Threats)
        $global:WfDetections = @($Detections)
        $global:WfDetectionsFail = [bool]$DetectionsFail
        $global:WfUpdateFails = [bool]$UpdateFails
        $global:WfScanFails = [bool]$ScanFails
        $global:WfAdmin = -not $NotAdmin
        $global:WfWindowsUpdates = $Updates

        Set-TestStub -Name "Test-WinForgeAdministrator" -Body { [bool]$global:WfAdmin }
        Set-TestStub -Name "Get-MpComputerStatus" -Body {
            [CmdletBinding()] param ()
            if ($global:WfMpNoStatus) { throw "Defender não instalado" }
            $global:WfMpStatus
        }
        Set-TestStub -Name "Get-CimInstance" -Body {
            [CmdletBinding()] param ($Namespace, $ClassName)
            @($global:WfOtherAv | ForEach-Object { [PSCustomObject]@{ displayName = $_ } })
        }
        Set-TestStub -Name "Get-NetFirewallProfile" -Body {
            [CmdletBinding()] param ()
            if ($null -eq $global:WfFirewall) { throw "módulo NetSecurity ausente" }
            $global:WfFirewall
        }
        Set-TestStub -Name "Get-MpThreat" -Body {
            [CmdletBinding()] param ($ThreatID)
            if ($PSBoundParameters.ContainsKey("ThreatID")) {
                return [PSCustomObject]@{ ThreatID = $ThreatID; ThreatName = "Virus:DOS/EICAR_Test_File"; IsActive = $false }
            }
            $global:WfThreats
        }
        Set-TestStub -Name "Get-MpThreatDetection" -Body {
            [CmdletBinding()] param ()
            if ($global:WfDetectionsFail) { throw "acesso negado" }
            $global:WfDetections
        }
        Set-TestStub -Name "Update-MpSignature" -Body {
            [CmdletBinding()] param ()
            [void]$global:WfLog.Add("Update-MpSignature")
            if ($global:WfUpdateFails) { throw "0x80072EE7 sem conexão" }
        }
        Set-TestStub -Name "Start-MpScan" -Body {
            [CmdletBinding()] param ($ScanType, $ScanPath)
            [void]$global:WfLog.Add("Start-MpScan:$ScanType" + $(if ($ScanPath) { ":$ScanPath" } else { "" }))
            if ($global:WfScanFails) { throw "o serviço do Defender não respondeu" }
        }
        Set-TestStub -Name "Get-WinForgePendingWindowsUpdates" -Body { $global:WfWindowsUpdates }
        Set-TestStub -Name "Wait-WinForgeKey" -Body { }
    }

    function script:Reset-DefenderTest {
        Clear-TestStubs
        Clear-FakeReadHost
        Remove-Variable WfLog, WfMpStatus, WfMpNoStatus, WfOtherAv, WfFirewall, WfThreats, WfDetections, WfDetectionsFail, WfUpdateFails, WfScanFails, WfAdmin, WfWindowsUpdates, WinForgeGuiMode -Scope Global -ErrorAction SilentlyContinue
    }

    function script:New-Firewall {
        param ([bool]$Domain = $true, [bool]$Private = $true, [bool]$Public = $true)

        @(
            [PSCustomObject]@{ Name = "Domain"; Enabled = $(if ($Domain) { "True" } else { "False" }) },
            [PSCustomObject]@{ Name = "Private"; Enabled = $(if ($Private) { "True" } else { "False" }) },
            [PSCustomObject]@{ Name = "Public"; Enabled = $(if ($Public) { "True" } else { "False" }) }
        )
    }

    function script:New-FirewallStatus {
        # A forma que Get-WinForgeFirewallStatus devolve (Enabled já é booleano).
        param ([bool]$Domain = $true, [bool]$Private = $true, [bool]$Public = $true)

        @(
            [PSCustomObject]@{ Name = "Domain"; Enabled = $Domain },
            [PSCustomObject]@{ Name = "Private"; Enabled = $Private },
            [PSCustomObject]@{ Name = "Public"; Enabled = $Public }
        )
    }

    function script:New-Detection {
        param ([long]$Id = 2147519003, [datetime]$When = (Get-Date), [string[]]$Resources = @("file:_C:\Temp\eicar.com"))

        [PSCustomObject]@{ ThreatID = $Id; InitialDetectionTime = $When; Resources = $Resources }
    }
}

AfterAll {
    Remove-WinForgeTestData
}

Describe "Estado do antivírus" {
    AfterEach { Reset-DefenderTest }

    It "Defender ligado, com proteção em tempo real: ativo, com versão, data das assinaturas e das verificações" {
        Use-DefenderStubs

        $status = Get-WinForgeAntivirusStatus

        $status.Mode | Should -Be "Active"
        $status.RealTime | Should -BeTrue
        $status.SignatureVersion | Should -Be "1.421.100.0"
        $status.SignatureAgeDays | Should -Be 0
        $status.LastQuickScan | Should -Not -BeNullOrEmpty
    }

    It "datas de 'nunca aconteceu' (1601) viram nulo" {
        Use-DefenderStubs

        (Get-WinForgeAntivirusStatus).LastFullScan | Should -BeNullOrEmpty
    }

    It "<Case>: modo <Mode>" -ForEach @(
        @{ Case = "modo passivo, sem outro antivírus identificado"; Mode = "Passive"; Status = { New-MpStatus -Mode "Passive Mode" }; Others = @() },
        @{ Case = "modo passivo com outro antivírus"; Mode = "Other"; Status = { New-MpStatus -Mode "Passive Mode" }; Others = @("Avast Antivirus") },
        @{ Case = "serviço parado com outro antivírus"; Mode = "Other"; Status = { New-MpStatus -Service $false }; Others = @("Kaspersky") },
        @{ Case = "antivírus desligado sem outro"; Mode = "Off"; Status = { New-MpStatus -Enabled $false }; Others = @() },
        @{ Case = "EDR em bloqueio"; Mode = "Passive"; Status = { New-MpStatus -Mode "EDR Block Mode" }; Others = @() }
    ) {
        Use-DefenderStubs -Status (& $Status) -OtherAntivirus $Others

        (Get-WinForgeAntivirusStatus).Mode | Should -Be $Mode
    }

    It "o próprio Defender registrado na Central de Segurança não conta como 'outro antivírus'" {
        Use-DefenderStubs -OtherAntivirus @("Windows Defender", "Microsoft Defender Antivirus", "Norton 360")

        (Get-WinForgeAntivirusStatus).Others | Should -Be @("Norton 360")
    }

    It "comando do Defender indisponível: não lido, ou outro antivírus se houver um registrado" {
        Use-DefenderStubs -NoStatus
        (Get-WinForgeAntivirusStatus).Mode | Should -Be "Unavailable"

        Use-DefenderStubs -NoStatus -OtherAntivirus @("Bitdefender")
        (Get-WinForgeAntivirusStatus).Mode | Should -Be "Other"
    }

    It "objeto sem as propriedades mais novas (Windows antigo) não derruba a leitura" {
        Use-DefenderStubs -Status ([PSCustomObject]@{ AMServiceEnabled = $true; AntivirusEnabled = $true })

        $status = Get-WinForgeAntivirusStatus

        $status.Mode | Should -Be "Active"
        $status.SignaturesUpdated | Should -BeNullOrEmpty
        $status.SignatureAgeDays | Should -BeNullOrEmpty
    }
}

Describe "Firewall e ameaças" {
    AfterEach { Reset-DefenderTest }

    It "lê os três perfis e converte o 'True'/'False' do Windows" {
        Use-DefenderStubs -Firewall (New-Firewall -Public $false)

        $profiles = @(Get-WinForgeFirewallStatus)

        $profiles | Should -HaveCount 3
        ($profiles | Where-Object { $_.Name -eq "Public" }).Enabled | Should -BeFalse
        ($profiles | Where-Object { $_.Name -eq "Domain" }).Enabled | Should -BeTrue
    }

    It "firewall ilegível devolve nulo" {
        Use-DefenderStubs

        Get-WinForgeFirewallStatus | Should -BeNullOrEmpty
    }

    It "ameaças ativas: só as marcadas como ativas, sem repetir o nome" {
        Use-DefenderStubs -Threats @(
            [PSCustomObject]@{ ThreatID = 1; ThreatName = "Trojan:Win32/Exemplo"; IsActive = $true },
            [PSCustomObject]@{ ThreatID = 2; ThreatName = "Trojan:Win32/Exemplo"; IsActive = $true },
            [PSCustomObject]@{ ThreatID = 3; ThreatName = "Adware:Win32/Antigo"; IsActive = $false }
        )

        @(Get-WinForgeActiveThreats) | Should -Be @("Trojan:Win32/Exemplo")
    }

    It "sem ameaças a lista é vazia (e não nula); com erro de leitura é nula" {
        Use-DefenderStubs

        $none = Get-WinForgeActiveThreats
        $null -ne $none | Should -BeTrue
        @($none) | Should -HaveCount 0

        Set-TestStub -Name "Get-MpThreat" -Body { [CmdletBinding()] param ($ThreatID) throw "negado" }
        Get-WinForgeActiveThreats | Should -BeNullOrEmpty
    }
}

Describe "Pontos de atenção" {
    AfterEach { Reset-DefenderTest }

    It "tudo em ordem: nenhum ponto de atenção" {
        Use-DefenderStubs
        $antivirus = Get-WinForgeAntivirusStatus

        @(Get-WinForgeSecurityFindings -Antivirus $antivirus -Firewall (New-FirewallStatus) -Updates ([PSCustomObject]@{ Count = 0; Titles = @() }) -Threats @()) | Should -HaveCount 0
    }

    It "assinaturas: <Days> dias -> <Level>" -ForEach @(
        @{ Days = 2; Level = $null }, @{ Days = 3.4; Level = $null }, @{ Days = 5; Level = "Info" },
        @{ Days = 7.5; Level = "Info" }, @{ Days = 8; Level = "Warning" }, @{ Days = 30; Level = "Warning" }
    ) {
        Use-DefenderStubs -Status (New-MpStatus -SignatureDays $Days)
        $antivirus = Get-WinForgeAntivirusStatus

        $findings = @(Get-WinForgeSecurityFindings -Antivirus $antivirus -Firewall (New-FirewallStatus))

        if ($null -eq $Level) { $findings | Should -HaveCount 0 }
        else {
            $findings | Should -HaveCount 1
            $findings[0].Level | Should -Be $Level
            $findings[0].Text | Should -Match "assinaturas"
        }
    }

    It "tempo real desligado, firewall desligado, atualizações e ameaças: avisos antes das informações" {
        Use-DefenderStubs -Status (New-MpStatus -RealTime $false -SignatureDays 5)
        $antivirus = Get-WinForgeAntivirusStatus

        $findings = @(Get-WinForgeSecurityFindings -Antivirus $antivirus -Firewall (New-FirewallStatus -Public $false -Private $false) `
                -Updates ([PSCustomObject]@{ Count = 3; Titles = @("a", "b", "c") }) -Threats @("Trojan:Win32/Exemplo"))

        $findings | Should -HaveCount 5
        ($findings.Level -join ",") | Should -Be "Warning,Warning,Warning,Warning,Info"
        ($findings.Text -join " ") | Should -Match "tempo real"
        ($findings.Text -join " ") | Should -Match "Rede privada, Rede pública"
        ($findings.Text -join " ") | Should -Match "3 atualização"
        ($findings.Text -join " ") | Should -Match "Trojan:Win32/Exemplo"
    }

    It "outro antivírus em uso é só informação; antivírus desligado é aviso" {
        Use-DefenderStubs -Status (New-MpStatus -Service $false) -OtherAntivirus @("Avast")
        $other = @(Get-WinForgeSecurityFindings -Antivirus (Get-WinForgeAntivirusStatus) -Firewall (New-FirewallStatus))

        $other | Should -HaveCount 1
        $other[0].Level | Should -Be "Info"
        $other[0].Text | Should -Match "Avast"

        Use-DefenderStubs -Status (New-MpStatus -Enabled $false)
        $off = @(Get-WinForgeSecurityFindings -Antivirus (Get-WinForgeAntivirusStatus) -Firewall (New-FirewallStatus))

        $off[0].Level | Should -Be "Warning"
        $off[0].Text | Should -Match "desligado"
    }

    It "firewall ilegível vira informação, não aviso" {
        Use-DefenderStubs
        $findings = @(Get-WinForgeSecurityFindings -Antivirus (Get-WinForgeAntivirusStatus) -Firewall $null)

        $findings | Should -HaveCount 1
        $findings[0].Level | Should -Be "Info"
    }
}

Describe "Tela Estado da proteção" {
    AfterEach { Reset-DefenderTest }

    It "PC protegido: mostra antivírus, firewall e atualizações e diz que não há ponto de atenção" {
        Use-DefenderStubs -Firewall (New-Firewall) -Updates ([PSCustomObject]@{ Count = 0; Titles = @() })
        Set-FakeReadHost -Answers @("")

        $text = Get-HostText { Show-WinForgeSecurityStatus }

        $text | Should -Match "Estado da proteção"
        $text | Should -Match "Windows Defender ativo, com proteção em tempo real"
        $text | Should -Match "1\.421\.100\.0"
        $text | Should -Match "Rede pública[\s:]+Ligado"
        $text | Should -Match "Atualizações pendentes[\s:]+Nenhuma"
        $text | Should -Match "Última verificação completa[\s:]+Nunca"
        $text | Should -Match "Nenhum ponto de atenção"
    }

    It "lista as atualizações pendentes (até cinco) e os avisos" {
        $titles = @(1..7 | ForEach-Object { "Atualização $_" })
        Use-DefenderStubs -Firewall (New-Firewall -Public $false) -Updates ([PSCustomObject]@{ Count = 7; Titles = $titles })
        Set-FakeReadHost -Answers @("")

        $text = Get-HostText { Show-WinForgeSecurityStatus }

        $text | Should -Match "Atualização 5"
        $text | Should -Not -Match "Atualização 6"
        $text | Should -Match "e mais 2"
        $text | Should -Match "Rede pública[\s:]+Desligado"
        $text | Should -Match "firewall está desligado"
        $text | Should -Not -Match "Nenhum ponto de atenção"
    }

    It "tudo ilegível (Windows sem Defender, sem NetSecurity, sem Windows Update): diz o que não conseguiu em vez de falhar" {
        Use-DefenderStubs -NoStatus
        Set-FakeReadHost -Answers @("")

        $text = Get-HostText { Show-WinForgeSecurityStatus }

        $text | Should -Match "Não foi possível ler"
        $text | Should -Match "Não foi possível consultar"
        $text | Should -Not -Match "Ocorreu um erro"
    }

    It "o Windows Update (a parte lenta) vem depois do antivírus e do firewall, e o resumo o leva em conta" {
        Use-DefenderStubs -Firewall (New-Firewall) -Updates ([PSCustomObject]@{ Count = 3; Titles = @("A", "B", "C") })
        Set-FakeReadHost -Answers @("")

        $text = Get-HostText { Show-WinForgeSecurityStatus }

        $text.IndexOf("Antivírus") | Should -BeLessThan $text.IndexOf("Firewall")
        $text.IndexOf("Firewall") | Should -BeLessThan $text.IndexOf("Consultando o Windows Update")
        $text.IndexOf("Consultando o Windows Update") | Should -BeLessThan $text.IndexOf("Resumo")
        $text | Should -Match "3 atualização\(ões\) do Windows pendente"
    }

    It "consulta do Windows Update que não responde: diz que não foi possível e não acusa atualização pendente" {
        Use-DefenderStubs -Firewall (New-Firewall) -Updates $null
        Set-FakeReadHost -Answers @("")

        $text = Get-HostText { Show-WinForgeSecurityStatus }

        $text | Should -Match "demorou ou está indisponível"
        $text | Should -Not -Match "pendente\(s\)"
        $text | Should -Match "Nenhum ponto de atenção"
    }

    It "com outro antivírus mostra o nome dele e não promete verificações do Defender" {
        Use-DefenderStubs -Status (New-MpStatus -Service $false) -OtherAntivirus @("Kaspersky Internet Security") -Firewall (New-Firewall)
        Set-FakeReadHost -Answers @("")

        $text = Get-HostText { Show-WinForgeSecurityStatus }

        $text | Should -Match "Outro antivírus em uso: Kaspersky Internet Security"
        $text | Should -Not -Match "Última verificação rápida"
    }
}

Describe "Atualizações pendentes do Windows" {
    AfterEach { Reset-DefenderTest }

    It "conta os títulos devolvidos pela consulta em segundo plano" {
        Set-TestStub -Name "Invoke-WinForgeInBackground" -Body {
            param ($ScriptBlock, $ArgumentList, $TimeoutSeconds)
            $global:WfBackground = @{ Script = $ScriptBlock.ToString(); Timeout = $TimeoutSeconds }
            [PSCustomObject]@{ Completed = $true; TimedOut = $false; Output = @("Atualização 1", "Atualização 2"); Error = "" }
        }

        $result = Get-WinForgePendingWindowsUpdates

        $result.Count | Should -Be 2
        $result.Titles | Should -Be @("Atualização 1", "Atualização 2")
        $global:WfBackground.Timeout | Should -BeGreaterThan 0
        $global:WfBackground.Script | Should -Match "IsInstalled=0"
        $global:WfBackground.Script | Should -Match "BrowseOnly=0"
        Remove-Variable WfBackground -Scope Global -ErrorAction SilentlyContinue
    }

    It "nenhuma atualização é zero, não 'não foi possível'" {
        Set-TestStub -Name "Invoke-WinForgeInBackground" -Body {
            param ($ScriptBlock, $ArgumentList, $TimeoutSeconds)
            [PSCustomObject]@{ Completed = $true; TimedOut = $false; Output = @(); Error = "" }
        }

        $result = Get-WinForgePendingWindowsUpdates

        $result | Should -Not -BeNullOrEmpty
        $result.Count | Should -Be 0
    }

    It "tempo esgotado, erro ou exceção: devolve nulo" -ForEach @(
        @{ Case = "tempo esgotado"; Body = { [PSCustomObject]@{ Completed = $false; TimedOut = $true; Output = @(); Error = "" } } },
        @{ Case = "erro do Windows Update"; Body = { [PSCustomObject]@{ Completed = $false; TimedOut = $false; Output = @(); Error = "0x8024402C" } } },
        @{ Case = "exceção"; Body = { throw "falha ao criar o runspace" } }
    ) {
        Set-TestStub -Name "Invoke-WinForgeInBackground" -Body $Body

        Get-WinForgePendingWindowsUpdates | Should -BeNullOrEmpty
    }
}

Describe "Atualizar assinaturas" {
    AfterEach { Reset-DefenderTest }

    It "atualiza e confirma com a versão" {
        Use-DefenderStubs

        $text = Get-HostText { $script:Result = Update-WinForgeDefenderSignatures -PassThru }

        $global:WfLog | Should -Contain "Update-MpSignature"
        $script:Result.Kind | Should -Be "Ok"
        $script:Result.Etapa | Should -Be "Atualizar assinaturas do antivírus"
        $text | Should -Match "Assinaturas em dia"
    }

    It "sem Administrador não chama o Defender" {
        Use-DefenderStubs -NotAdmin

        [void](Get-HostText { $script:Result = Update-WinForgeDefenderSignatures -PassThru })

        $global:WfLog | Should -HaveCount 0
        $script:Result.Kind | Should -Be "Failed"
        $script:Result.Detail | Should -Match "Administrador"
    }

    It "com outro antivírus explica e ignora, sem tentar atualizar" {
        Use-DefenderStubs -Status (New-MpStatus -Service $false) -OtherAntivirus @("Avast")

        $text = Get-HostText { $script:Result = Update-WinForgeDefenderSignatures -PassThru }

        $global:WfLog | Should -HaveCount 0
        $script:Result.Kind | Should -Be "Skipped"
        $text | Should -Match "Avast"
    }

    It "antivírus desligado vira ressalva com a instrução, sem tentar atualizar" {
        Use-DefenderStubs -Status (New-MpStatus -Enabled $false)

        $text = Get-HostText { $script:Result = Update-WinForgeDefenderSignatures -PassThru }

        $global:WfLog | Should -HaveCount 0
        $script:Result.Kind | Should -Be "Warning"
        $text | Should -Match "desligado"
    }

    It "falha de rede vira 'Falhou' com a causa e o caminho alternativo" {
        Use-DefenderStubs -UpdateFails

        $text = Get-HostText { $script:Result = Update-WinForgeDefenderSignatures -PassThru }

        $script:Result.Kind | Should -Be "Failed"
        $text | Should -Match "0x80072EE7"
        $text | Should -Match "Atualizações > Windows Update"
    }

    It "atualização que não rejuvenesce as assinaturas vira ressalva, não sucesso" {
        Use-DefenderStubs -Status (New-MpStatus -SignatureDays 12)

        $text = Get-HostText { $script:Result = Update-WinForgeDefenderSignatures -PassThru }

        $script:Result.Kind | Should -Be "Warning"
        $text | Should -Match "continuam com 12 dias"
    }
}

Describe "Verificação do Windows Defender" {
    AfterEach { Reset-DefenderTest }

    It "rápida: pede QuickScan e, sem detecções, termina bem" {
        Use-DefenderStubs

        $text = Get-HostText { $script:Result = Start-WinForgeQuickScan -PassThru }

        $global:WfLog | Should -Be @("Start-MpScan:QuickScan")
        $script:Result.Kind | Should -Be "Ok"
        $script:Result.Etapa | Should -Be "Verificação rápida"
        (Get-WinForgeResultData -Result $script:Result -Name "ThreatCount") | Should -Be 0
        $text | Should -Match "nenhuma ameaça encontrada"
    }

    It "ameaça detectada durante a verificação: ressalva com nome e arquivo" {
        Use-DefenderStubs -Detections @((New-Detection -When (Get-Date).AddSeconds(5)))

        $text = Get-HostText { $script:Result = Start-WinForgeQuickScan -PassThru }

        $script:Result.Kind | Should -Be "Warning"
        (Get-WinForgeResultData -Result $script:Result -Name "ThreatCount") | Should -Be 1
        $text | Should -Match "1 ameaça\(s\) encontrada"
        $text | Should -Match "Virus:DOS/EICAR_Test_File"
        $text | Should -Match "eicar\.com"
        $text | Should -Match "Segurança do Windows"
    }

    It "detecção antiga (de antes da verificação) não conta" {
        Use-DefenderStubs -Detections @((New-Detection -When (Get-Date).AddDays(-3)))

        [void](Get-HostText { $script:Result = Start-WinForgeQuickScan -PassThru })

        $script:Result.Kind | Should -Be "Ok"
    }

    It "nenhuma ameaça nova, mas uma de antes ainda ativa: ressalva, não 'nenhuma ameaça encontrada'" {
        $old = [PSCustomObject]@{ ThreatID = 77; ThreatName = "Trojan:Win32/Antigo"; IsActive = $true }
        Use-DefenderStubs -Threats @($old)

        $text = Get-HostText { $script:Result = Start-WinForgeQuickScan -PassThru }

        $script:Result.Kind | Should -Be "Warning"
        $script:Result.Detail | Should -Match "ativa\(s\) de antes"
        (Get-WinForgeResultData -Result $script:Result -Name "ThreatCount") | Should -Be 0
        (Get-WinForgeResultData -Result $script:Result -Name "ActiveThreats") | Should -Be 1
        $text | Should -Match "nenhuma ameaça nova"
        $text | Should -Match "Trojan:Win32/Antigo"
        $text | Should -Not -Match "nenhuma ameaça encontrada"
    }

    It "ameaça de antes já resolvida (inativa) não atrapalha o 'nenhuma ameaça encontrada'" {
        $solved = [PSCustomObject]@{ ThreatID = 78; ThreatName = "Trojan:Win32/Resolvido"; IsActive = $false }
        Use-DefenderStubs -Threats @($solved)

        [void](Get-HostText { $script:Result = Start-WinForgeQuickScan -PassThru })

        $script:Result.Kind | Should -Be "Ok"
    }

    It "duas detecções da mesma ameaça contam uma vez" {
        Use-DefenderStubs -Detections @((New-Detection -Id 5), (New-Detection -Id 5), (New-Detection -Id 6))

        [void](Get-HostText { $script:Result = Start-WinForgeQuickScan -PassThru })

        (Get-WinForgeResultData -Result $script:Result -Name "ThreatCount") | Should -Be 2
    }

    It "não conseguir consultar o resultado é ressalva, nunca 'nenhuma ameaça'" {
        Use-DefenderStubs -DetectionsFail

        $text = Get-HostText { $script:Result = Start-WinForgeQuickScan -PassThru }

        $script:Result.Kind | Should -Be "Warning"
        $text | Should -Not -Match "nenhuma ameaça encontrada"
        $text | Should -Match "não foi possível consultar o resultado"
    }

    It "falha do Defender durante a verificação vira 'Falhou' com a mensagem" {
        Use-DefenderStubs -ScanFails

        $text = Get-HostText { $script:Result = Start-WinForgeQuickScan -PassThru }

        $script:Result.Kind | Should -Be "Failed"
        $text | Should -Match "o serviço do Defender não respondeu"
    }

    It "sem Administrador, com outro antivírus ou sem Defender: nenhuma verificação é iniciada" -ForEach @(
        @{ Setup = { Use-DefenderStubs -NotAdmin }; Kind = "Failed" },
        @{ Setup = { Use-DefenderStubs -Status (New-MpStatus -Service $false) -OtherAntivirus @("Avast") }; Kind = "Skipped" },
        @{ Setup = { Use-DefenderStubs -NoStatus }; Kind = "Skipped" },
        @{ Setup = { Use-DefenderStubs -Status (New-MpStatus -Enabled $false) }; Kind = "Warning" }
    ) {
        & $Setup

        [void](Get-HostText { $script:Result = Start-WinForgeQuickScan -PassThru })

        $global:WfLog | Should -HaveCount 0
        $script:Result.Kind | Should -Be $Kind
    }

    It "completa: pergunta antes (padrão Não) e só roda com 'sim'" {
        Use-DefenderStubs
        Set-FakeReadHost -Answers @("")

        [void](Get-HostText { $script:Result = Start-WinForgeFullScan -PassThru })

        $global:WfLog | Should -HaveCount 0
        $script:Result.Kind | Should -Be "Skipped"

        Set-FakeReadHost -Answers @("S")
        [void](Get-HostText { $script:Result = Start-WinForgeFullScan -PassThru })

        $global:WfLog | Should -Be @("Start-MpScan:FullScan")
        $script:Result.Kind | Should -Be "Ok"
    }

    It "completa dentro de um fluxo (-Embedded) não pergunta de novo" {
        Use-DefenderStubs
        Set-FakeReadHost -Answers @()

        [void](Get-HostText { $script:Result = Start-WinForgeFullScan -Embedded -PassThru })

        $global:WfLog | Should -Be @("Start-MpScan:FullScan")
    }

    It "pasta: 'Outra pasta' pede o caminho e usa CustomScan, tirando aspas e espaços" {
        $folder = Join-Path $script:TestDataRoot "pasta com espaço"
        New-Item -ItemType Directory -Path $folder -Force | Out-Null
        Use-DefenderStubs
        Set-FakeReadHost -Answers @("O", "  `"$folder`"  ")

        [void](Get-HostText { $script:Result = Start-WinForgeFolderScan -PassThru })

        $global:WfLog | Should -Be @("Start-MpScan:CustomScan:$folder")
        $script:Result.Kind | Should -Be "Ok"
        $script:Result.Etapa | Should -Be "Verificar uma pasta"
    }

    It "pasta: Downloads é um botão, sem digitar o caminho" {
        $downloads = Join-Path $script:TestDataRoot "Downloads-teste"
        New-Item -ItemType Directory -Path $downloads -Force | Out-Null
        Use-DefenderStubs
        Set-TestStub -Name "Get-WinForgeDownloadsPath" -Body { $global:WfDownloads }
        $global:WfDownloads = $downloads
        Set-FakeReadHost -Answers @("D")

        $text = Get-HostText { $script:Result = Start-WinForgeFolderScan -PassThru }

        $global:WfLog | Should -Be @("Start-MpScan:CustomScan:$downloads")
        $text | Should -Match "Downloads"
        $script:Result.Kind | Should -Be "Ok"
        Remove-Variable WfDownloads -Scope Global -ErrorAction SilentlyContinue
    }

    It "pasta: sem a pasta Downloads, a opção não aparece (e escolhê-la cancela)" {
        Use-DefenderStubs
        Set-TestStub -Name "Get-WinForgeDownloadsPath" -Body { Join-Path $script:TestDataRoot "nao-existe-downloads" }
        Set-FakeReadHost -Answers @("D", "")

        $text = Get-HostText { $script:Result = Start-WinForgeFolderScan -PassThru }

        $script:Result.Kind | Should -Be "Skipped"
        $global:WfLog | Should -HaveCount 0
        $text | Should -Match "Outra pasta ou arquivo"
        $text | Should -Not -Match "\[\s*D\]"
    }

    It "pasta: Cancelar (e ENTER, que é o padrão) não chama o Defender" {
        Use-DefenderStubs
        Set-FakeReadHost -Answers @("C")

        [void](Get-HostText { $script:Result = Start-WinForgeFolderScan -PassThru })

        $script:Result.Kind | Should -Be "Skipped"

        Set-FakeReadHost -Answers @("")
        [void](Get-HostText { $script:Result = Start-WinForgeFolderScan -PassThru })

        $script:Result.Kind | Should -Be "Skipped"
        $global:WfLog | Should -HaveCount 0
    }

    It "pasta: caminho digitado vazio cancela; caminho que não existe falha sem chamar o Defender" {
        Use-DefenderStubs
        Set-FakeReadHost -Answers @("O", "")

        [void](Get-HostText { $script:Result = Start-WinForgeFolderScan -PassThru })

        $script:Result.Kind | Should -Be "Skipped"

        Set-FakeReadHost -Answers @("O", (Join-Path $script:TestDataRoot "nao-existe"))
        $text = Get-HostText { $script:Result = Start-WinForgeFolderScan -PassThru }

        $script:Result.Kind | Should -Be "Failed"
        $text | Should -Match "não encontrad"
        $global:WfLog | Should -HaveCount 0
    }
}

Describe "Etapa de segurança da manutenção" {
    AfterEach { Reset-DefenderTest }

    It "atualiza as assinaturas e depois faz a verificação rápida" {
        Use-DefenderStubs

        [void](Get-HostText { $script:Result = Invoke-WinForgeSecurityCheck -Embedded -PassThru })

        $global:WfLog | Should -Be @("Update-MpSignature", "Start-MpScan:QuickScan")
        $script:Result.Kind | Should -Be "Ok"
        $script:Result.Etapa | Should -Be "Verificação de segurança"
    }

    It "se só a atualização falhar, a verificação roda e o resultado vira ressalva" {
        Use-DefenderStubs -UpdateFails

        [void](Get-HostText { $script:Result = Invoke-WinForgeSecurityCheck -Embedded -PassThru })

        $global:WfLog | Should -Be @("Update-MpSignature", "Start-MpScan:QuickScan")
        $script:Result.Kind | Should -Be "Warning"
        $script:Result.Detail | Should -Match "assinaturas não foram atualizadas"
    }

    It "ameaça encontrada: ressalva com a contagem em Data" {
        Use-DefenderStubs -Detections @((New-Detection -When (Get-Date).AddSeconds(5)))

        [void](Get-HostText { $script:Result = Invoke-WinForgeSecurityCheck -Embedded -PassThru })

        $script:Result.Kind | Should -Be "Warning"
        (Get-WinForgeResultData -Result $script:Result -Name "ThreatCount") | Should -Be 1
    }

    It "falha da verificação continua sendo 'Falhou' (a atualização boa não esconde)" {
        Use-DefenderStubs -ScanFails

        [void](Get-HostText { $script:Result = Invoke-WinForgeSecurityCheck -Embedded -PassThru })

        $script:Result.Kind | Should -Be "Failed"
    }

    It "com outro antivírus: ignorada de uma vez, sem atualizar nem verificar" {
        Use-DefenderStubs -Status (New-MpStatus -Mode "Passive Mode") -OtherAntivirus @("Avast")

        [void](Get-HostText { $script:Result = Invoke-WinForgeSecurityCheck -Embedded -PassThru })

        $global:WfLog | Should -HaveCount 0
        $script:Result.Kind | Should -Be "Skipped"
    }

    It "uma exceção inesperada vira resultado 'Falhou', não derruba a manutenção" {
        Use-DefenderStubs
        Set-TestStub -Name "Get-MpComputerStatus" -Body { [CmdletBinding()] param () throw "WMI quebrado" }
        Set-TestStub -Name "Test-WinForgeElevation" -Body { throw "falha inesperada" }

        [void](Get-HostText { $script:Result = Invoke-WinForgeSecurityCheck -Embedded -PassThru })

        $script:Result.Kind | Should -Be "Failed"
        $script:Result.Detail | Should -Match "falha inesperada"
    }
}

Describe "Relatório" {
    AfterEach { Reset-DefenderTest }

    It "a seção Segurança resume o antivírus, o firewall e os avisos, sem consultar o Windows Update" {
        Use-DefenderStubs -Firewall (New-Firewall -Public $false)
        Set-TestStub -Name "Get-WinForgePendingWindowsUpdates" -Body { [void]$global:WfLog.Add("consultou-windows-update"); $null }

        $section = Get-WinForgeReportSections | Where-Object { $_.Title -eq "Segurança" }
        $text = ($section.Items | ForEach-Object { "$($_.Label): $($_.Value)" }) -join "`n"

        $text | Should -Match "Antivírus: Windows Defender ativo"
        $text | Should -Match "Rede pública: desligado"
        $text | Should -Match "Atenção: O firewall está desligado"
        $global:WfLog | Should -Not -Contain "consultou-windows-update"
    }
}
