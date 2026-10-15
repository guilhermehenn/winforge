# Ajustes do Windows: catálogo, backup dos valores originais, aplicar/desfazer e ponto de restauração.
# O registro, o powercfg e o Checkpoint-Computer são substituídos por versões de teste: nada toca no sistema.

BeforeAll {
    . (Join-Path $PSScriptRoot "TestSetup.ps1")

    function script:Get-BackupFilePath { return (Join-Path (Get-WinForgeDataPath) "tweak-backup.json") }

    function script:Reset-BackupFiles {
        Get-ChildItem -LiteralPath (Get-WinForgeDataPath) -Filter "tweak-backup.json*" -ErrorAction SilentlyContinue |
            Remove-Item -Force -ErrorAction SilentlyContinue
    }

    function script:Use-RegistryStub {
        # Registro em memória: chave "Caminho|Nome" -> valor inteiro. Ausente = valor não existe.
        $global:WfReg = @{}

        Set-TestStub -Name "Get-WinForgeRegistryValueOrNull" -Body {
            param ($Path, $Name)
            $key = "$Path|$Name"
            if ($global:WfReg.ContainsKey($key)) { $global:WfReg[$key] } else { $null }
        }
        Set-TestStub -Name "Set-WinForgeRegistryDWord" -Body {
            param ($Path, $Name, $Value)
            $global:WfReg["$Path|$Name"] = [int]$Value
        }
        Set-TestStub -Name "Remove-WinForgeRegistryValue" -Body {
            param ($Path, $Name)
            $global:WfReg.Remove("$Path|$Name")
        }
        Set-TestStub -Name "Test-WinForgeAdministrator" -Body { $true }
        Set-TestStub -Name "Test-WinForgeWindows11" -Body { $true }
    }

    function script:Use-RestorePointStubs {
        # Sequência = números devolvidos pelas consultas ao Get-ComputerRestorePoint (0 = nenhum ponto existe).
        param ([int[]]$Sequences, [switch]$CheckpointWarns, [string]$CheckpointError = "", [switch]$QueryFails)

        $global:WfSeq = New-Object System.Collections.Queue
        foreach ($value in $Sequences) { $global:WfSeq.Enqueue($value) }
        $global:WfCheckpointWarns = [bool]$CheckpointWarns
        $global:WfCheckpointError = $CheckpointError
        $global:WfQueryFails = [bool]$QueryFails

        Set-TestStub -Name "Get-ComputerRestorePoint" -Body {
            [CmdletBinding()] param ()
            if ($global:WfQueryFails) { throw "sem acesso" }
            $number = $global:WfSeq.Dequeue()
            if ($number -gt 0) { [PSCustomObject]@{ SequenceNumber = $number } }
        }
        Set-TestStub -Name "Checkpoint-Computer" -Body {
            [CmdletBinding()] param ($Description, $RestorePointType)
            if ($global:WfCheckpointError) { throw $global:WfCheckpointError }
            if ($global:WfCheckpointWarns) { Write-Warning "Um ponto foi criado nas últimas 24 horas." }
        }
    }

    function script:Use-TweakFlowStubs {
        # Administrador, sessão (notebook ou não), Explorador e Proteção do Sistema de mentira, tudo registrado em $global:WfLog.
        param ([switch]$Laptop, [switch]$EnableFails)

        $global:WfLog = New-Object System.Collections.ArrayList
        $global:WfLaptop = [bool]$Laptop
        $global:WfEnabled = $null
        $global:WfEnableFails = [bool]$EnableFails

        Set-TestStub -Name "Test-WinForgeElevation" -Body { param ($Reason) $true }
        Set-TestStub -Name "Get-WinForgeSessionInfo" -Body {
            param ([switch]$Refresh)
            [PSCustomObject]@{ IsAdmin = $true; User = "PC\usuario"; UserMismatch = $false; IsLaptop = $global:WfLaptop; WindowsLabel = "Windows 11"; WindowsBuild = 22631 }
        }
        Set-TestStub -Name "Restart-WinForgeExplorerShell" -Body { [void]$global:WfLog.Add("explorer-reiniciado") }
        Set-TestStub -Name "Enable-ComputerRestore" -Body {
            [CmdletBinding()] param ($Drive)
            if ($global:WfEnableFails) { throw "acesso negado" }
            $global:WfEnabled = $Drive
            $global:WfCheckpointError = ""
        }
    }

    function script:New-FakeTweak {
        # Ajuste de teste: o "sistema" é uma tabela global; as falhas são programáveis.
        param (
            [string]$Id = "fake",
            [switch]$FailApply,
            [switch]$FailRevert,
            [switch]$FailCapture,
            [switch]$RequiresAdmin,
            [switch]$Windows11Only
        )

        $global:WfFake = @{ Value = 0; Reverted = $null; FailApply = [bool]$FailApply; FailRevert = [bool]$FailRevert; FailCapture = [bool]$FailCapture }

        New-WinForgeTweak -Id $Id -Category "Explorador" -Name "Ajuste de teste" -Description "teste" `
            -RequiresAdmin:$RequiresAdmin -Windows11Only:$Windows11Only `
            -Capture {
                if ($global:WfFake.FailCapture) { throw "falha ao capturar" }
                @{ Value = $global:WfFake.Value }
            } `
            -Apply {
                $global:WfFake.Value = 1
                if ($global:WfFake.FailApply) { throw "falha ao aplicar" }
            } `
            -Revert {
                param ($Saved)
                if ($global:WfFake.FailRevert) { throw "falha ao desfazer" }
                $global:WfFake.Reverted = $Saved
                $global:WfFake.Value = $(if ($null -eq $Saved) { 0 } else { [int]$Saved.Value })
            } `
            -Test { $global:WfFake.Value -eq 1 }
    }
}

AfterAll {
    Reset-BackupFiles
    Remove-Variable WfFake, WfReg, WfSeq, WfEnabled, WfEnableFails, WfLog, WfLaptop, WfCheckpointWarns, WfCheckpointError, WfQueryFails -Scope Global -ErrorAction SilentlyContinue
    Remove-WinForgeTestData
}

Describe "Catálogo de ajustes" {
    It "tem IDs únicos, válidos para a janela, e todas as operações definidas" {
        $catalog = @(Get-WinForgeTweakCatalog)
        $catalog.Count | Should -BeGreaterThan 8
        ($catalog.Id | Select-Object -Unique) | Should -HaveCount $catalog.Count

        foreach ($tweak in $catalog) {
            $tweak.Id | Should -Match "^[a-z0-9][a-z0-9-]*$"
            $tweak.Name | Should -Not -BeNullOrEmpty
            $tweak.Description | Should -Not -BeNullOrEmpty
            $tweak.Apply | Should -Not -BeNullOrEmpty
            $tweak.Revert | Should -Not -BeNullOrEmpty
            $tweak.Test | Should -Not -BeNullOrEmpty
            $tweak.Capture | Should -Not -BeNullOrEmpty
        }
    }

    It "usa só categorias conhecidas e na ordem de exibição" {
        $categories = @(Get-WinForgeTweakCategories)

        foreach ($tweak in @(Get-WinForgeTweakCatalog)) {
            $categories | Should -Contain $tweak.Category
        }

        $order = @(Get-WinForgeTweakCatalog | ForEach-Object { $categories.IndexOf($_.Category) })
        $sorted = @($order | Sort-Object)
        ($order -join ",") | Should -Be ($sorted -join ",")
    }

    It "marca como risco para notebook os ajustes de energia e explica o risco" {
        $risky = @(Get-WinForgeTweakCatalog | Where-Object { $_.LaptopRisk })
        $risky.Id | Should -Contain "high-performance"
        $risky.Id | Should -Contain "hibernation"
        $risky.Id | Should -Contain "no-sleep-timeouts"

        foreach ($tweak in $risky) {
            $tweak.Warning | Should -Not -BeNullOrEmpty
        }
    }

    It "busca por Id e devolve nulo para Id inexistente" {
        (Get-WinForgeTweakById -Id "dark-mode").Id | Should -Be "dark-mode"
        Get-WinForgeTweakById -Id "nao-existe" | Should -BeNullOrEmpty
        Get-WinForgeTweakById -Id "" | Should -BeNullOrEmpty
    }

    It "monta a visão geral sem lançar erro e com o estado de cada ajuste" {
        { Get-WinForgeTweakOverview } | Should -Not -Throw

        foreach ($item in @(Get-WinForgeTweakOverview)) {
            $item.Status | Should -Match "^(Aplicado|Padrão|Desconhecido)$"
            $item.Category | Should -Not -BeNullOrEmpty
        }
    }
}

Describe "Ajustes de registro do catálogo" {
    It "aplicam, guardam o original, desfazem e voltam ao padrão sem backup" {
        Use-RegistryStub
        Reset-BackupFiles
        try {
            $registryTweaks = @(Get-WinForgeTweakCatalog | Where-Object { @($_.Changes).Count -gt 0 })
            $registryTweaks.Count | Should -BeGreaterThan 5

            foreach ($tweak in $registryTweaks) {
                # Estado inicial: padrão do Windows (valor de Default, ou ausente).
                $global:WfReg.Clear()
                foreach ($change in $tweak.Changes) {
                    if ($null -ne $change.Default) { $global:WfReg["$($change.Path)|$($change.Name)"] = [int]$change.Default }
                }

                (Get-WinForgeTweakStatus -Tweak $tweak) | Should -Be "Padrão"

                Invoke-WinForgeTweakApply -Tweak $tweak
                (Get-WinForgeTweakStatus -Tweak $tweak) | Should -Be "Aplicado"
                (Read-WinForgeTweakBackup).Contains($tweak.Id) | Should -BeTrue

                # Aplicar de novo não pode trocar o "original" pelo valor já aplicado.
                Invoke-WinForgeTweakApply -Tweak $tweak
                (Invoke-WinForgeTweakRevert -Tweak $tweak) | Should -BeTrue
                (Get-WinForgeTweakStatus -Tweak $tweak) | Should -Be "Padrão"

                foreach ($change in $tweak.Changes) {
                    $key = "$($change.Path)|$($change.Name)"
                    if ($null -ne $change.Default) { $global:WfReg[$key] | Should -Be ([int]$change.Default) }
                    else { $global:WfReg.ContainsKey($key) | Should -BeFalse }
                }

                (Read-WinForgeTweakBackup).Contains($tweak.Id) | Should -BeFalse

                # Desfazer sem backup (ajuste feito fora do WinForge) usa os padrões do Windows e não falha.
                foreach ($change in $tweak.Changes) { $global:WfReg["$($change.Path)|$($change.Name)"] = [int]$change.Value }
                (Get-WinForgeTweakStatus -Tweak $tweak) | Should -Be "Aplicado"
                (Invoke-WinForgeTweakRevert -Tweak $tweak) | Should -BeFalse
                (Get-WinForgeTweakStatus -Tweak $tweak) | Should -Be "Padrão"
            }
        }
        finally {
            Clear-TestStubs
            Reset-BackupFiles
        }
    }

    It "têm padrão (Default) definido em todas as alterações, para poder desfazer sem backup" {
        foreach ($tweak in @(Get-WinForgeTweakCatalog | Where-Object { @($_.Changes).Count -gt 0 })) {
            foreach ($change in $tweak.Changes) {
                $change.Path | Should -Match "^HK(CU|LM):\\"
                $change.Name | Should -Not -BeNullOrEmpty
                ($null -ne $change.Value) | Should -BeTrue
            }
        }
    }
}

Describe "Backup dos ajustes" {
    It "grava e lê de volta, inclusive valores nulos e listas de um item" {
        Reset-BackupFiles
        $backup = [ordered]@{
            "um"   = [ordered]@{ AppliedAt = "2026-01-01T10:00:00"; Original = @([ordered]@{ Path = "HKCU:\x"; Name = "n"; Value = $null }) }
            "dois" = [ordered]@{ AppliedAt = "2026-01-01T10:00:01"; Original = @([ordered]@{ Path = "HKCU:\y"; Name = "m"; Value = 5 }, [ordered]@{ Path = "HKCU:\y"; Name = "o"; Value = 0 }) }
        }

        Save-WinForgeTweakBackup -Backup $backup
        $read = Read-WinForgeTweakBackup

        $read.Keys | Should -HaveCount 2
        @($read["um"].Original)[0].Value | Should -BeNullOrEmpty
        @($read["dois"].Original) | Should -HaveCount 2
        @($read["dois"].Original)[0].Value | Should -Be 5
        Reset-BackupFiles
    }

    It "não deixa arquivo temporário para trás e remove o arquivo quando o backup fica vazio" {
        Reset-BackupFiles
        Save-WinForgeTweakBackup -Backup ([ordered]@{ "a" = [ordered]@{ AppliedAt = "x"; Original = @() } })

        Test-Path -LiteralPath (Get-BackupFilePath) | Should -BeTrue
        Test-Path -LiteralPath ((Get-BackupFilePath) + ".tmp") | Should -BeFalse

        Save-WinForgeTweakBackup -Backup ([ordered]@{})
        Test-Path -LiteralPath (Get-BackupFilePath) | Should -BeFalse
    }

    It "devolve backup vazio quando o arquivo não existe ou está vazio" {
        Reset-BackupFiles
        (Read-WinForgeTweakBackup).Count | Should -Be 0

        Set-Content -LiteralPath (Get-BackupFilePath) -Value "   " -Encoding UTF8
        (Read-WinForgeTweakBackup).Count | Should -Be 0
        Reset-BackupFiles
    }

    It "guarda uma cópia do arquivo corrompido em vez de sobrescrevê-lo" -ForEach @(
        @{ Content = "{ isto não é json" },
        @{ Content = "[1, 2, 3]" },
        @{ Content = '"texto"' },
        @{ Content = "42" },
        @{ Content = "null" }
    ) {
        Reset-BackupFiles
        Set-Content -LiteralPath (Get-BackupFilePath) -Value $Content -Encoding UTF8

        $read = Read-WinForgeTweakBackup

        $read.Count | Should -Be 0
        Test-Path -LiteralPath (Get-BackupFilePath) | Should -BeFalse
        @(Get-ChildItem -LiteralPath (Get-WinForgeDataPath) -Filter "tweak-backup.json.corrupt-*") | Should -HaveCount 1
        Reset-BackupFiles
    }
}

Describe "Aplicar e desfazer um ajuste" {
    It "aplica, guarda o original e desfaz com o valor guardado" {
        Reset-BackupFiles
        $tweak = New-FakeTweak
        $global:WfFake.Value = 0

        Invoke-WinForgeTweakApply -Tweak $tweak
        $global:WfFake.Value | Should -Be 1
        (Read-WinForgeTweakBackup).Contains("fake") | Should -BeTrue

        (Invoke-WinForgeTweakRevert -Tweak $tweak) | Should -BeTrue
        $global:WfFake.Value | Should -Be 0
        (Read-WinForgeTweakBackup).Contains("fake") | Should -BeFalse
    }

    It "desfazer sem backup não falha, usa os padrões e avisa com $false" {
        Reset-BackupFiles
        $tweak = New-FakeTweak
        $global:WfFake.Value = 1

        (Invoke-WinForgeTweakRevert -Tweak $tweak) | Should -BeFalse
        $global:WfFake.Reverted | Should -BeNullOrEmpty
    }

    It "se a aplicação falha, desfaz o que mudou e não deixa backup de algo que não foi aplicado" {
        Reset-BackupFiles
        $tweak = New-FakeTweak -FailApply
        $global:WfFake.Value = 0

        { Invoke-WinForgeTweakApply -Tweak $tweak } | Should -Throw -ExpectedMessage "*falha ao aplicar*"

        $global:WfFake.Value | Should -Be 0
        (Read-WinForgeTweakBackup).Contains("fake") | Should -BeFalse
    }

    It "se a captura falha, nada é aplicado" {
        Reset-BackupFiles
        $tweak = New-FakeTweak -FailCapture
        $global:WfFake.Value = 0

        { Invoke-WinForgeTweakApply -Tweak $tweak } | Should -Throw -ExpectedMessage "*falha ao capturar*"
        $global:WfFake.Value | Should -Be 0
        (Read-WinForgeTweakBackup).Contains("fake") | Should -BeFalse
    }

    It "se a aplicação falha, o backup anterior do mesmo ajuste é preservado" {
        Reset-BackupFiles
        $tweak = New-FakeTweak
        $global:WfFake.Value = 7
        Invoke-WinForgeTweakApply -Tweak $tweak

        # O usuário desfez por fora e a nova tentativa falha: o backup antigo (original = 7) deve continuar valendo.
        $global:WfFake.Value = 0
        $global:WfFake.FailApply = $true

        { Invoke-WinForgeTweakApply -Tweak $tweak } | Should -Throw
        (Read-WinForgeTweakBackup).Contains("fake") | Should -BeTrue
        Reset-BackupFiles
    }

    It "se desfazer falha, o backup continua disponível para uma nova tentativa" {
        Reset-BackupFiles
        $tweak = New-FakeTweak
        Invoke-WinForgeTweakApply -Tweak $tweak
        $global:WfFake.FailRevert = $true

        { Invoke-WinForgeTweakRevert -Tweak $tweak } | Should -Throw -ExpectedMessage "*falha ao desfazer*"
        (Read-WinForgeTweakBackup).Contains("fake") | Should -BeTrue

        $global:WfFake.FailRevert = $false
        (Invoke-WinForgeTweakRevert -Tweak $tweak) | Should -BeTrue
        Reset-BackupFiles
    }

    It "aplicar duas vezes mantém o original da primeira vez" {
        Reset-BackupFiles
        $tweak = New-FakeTweak
        $global:WfFake.Value = 3

        Invoke-WinForgeTweakApply -Tweak $tweak
        Invoke-WinForgeTweakApply -Tweak $tweak
        [void](Invoke-WinForgeTweakRevert -Tweak $tweak)

        $global:WfFake.Value | Should -Be 3
    }

    It "aplicar um ajuste já aplicado fora do WinForge não inventa um original" {
        Reset-BackupFiles
        $tweak = New-FakeTweak
        $global:WfFake.Value = 1   # já aplicado, sem backup

        Invoke-WinForgeTweakApply -Tweak $tweak

        (Read-WinForgeTweakBackup).Contains("fake") | Should -BeFalse
    }

    It "exige Administrador para ajustes de sistema" {
        if (Test-WinForgeAdministrator) { return }

        $tweak = New-FakeTweak -RequiresAdmin
        { Invoke-WinForgeTweakApply -Tweak $tweak } | Should -Throw -ExpectedMessage "*Administrador*"
        { Invoke-WinForgeTweakRevert -Tweak $tweak } | Should -Throw -ExpectedMessage "*Administrador*"
    }

    It "recusa ajustes exclusivos do Windows 11 em outras versões" {
        if (Test-WinForgeWindows11) { return }

        $tweak = New-FakeTweak -Windows11Only
        { Invoke-WinForgeTweakApply -Tweak $tweak } | Should -Throw -ExpectedMessage "*não está disponível*"
    }

    It "classifica o estado como Desconhecido quando o teste do ajuste falha" {
        $tweak = New-WinForgeTweak -Id "quebrado" -Category "Explorador" -Name "q" -Description "q" `
            -Capture { } -Apply { } -Revert { param ($s) } -Test { throw "sem acesso" }

        Get-WinForgeTweakStatus -Tweak $tweak | Should -Be "Desconhecido"
    }

    It "um ajuste desconhecido na lista não interrompe os demais" {
        Reset-BackupFiles
        $summary = Invoke-WinForgeTweakSet -Ids @("id-que-nao-existe")

        @($summary.Results) | Should -HaveCount 1
        @($summary.Results)[0].Kind | Should -Be "Failed"
        $summary.NeedsExplorerRestart | Should -BeFalse
    }
}

Describe "Consulta do powercfg" {
    It "lê AC e CC pelos valores hexadecimais, em qualquer idioma" {
        $lines = @(
            "Índice de Configuração de Energia Possível: 0x00000000",
            "Índice de Configuração de Energia CA Atual: 0x0000012c",
            "Índice de Configuração de Energia CC Atual: 0x00000000"
        )
        $setting = ConvertFrom-WinForgePowerQuery -Lines $lines
        $setting.AC | Should -Be 300
        $setting.DC | Should -Be 0
    }

    It "lê valores máximos de 32 bits sem estourar" {
        $setting = ConvertFrom-WinForgePowerQuery -Lines @("Current AC Power Setting Index: 0xffffffff", "Current DC Power Setting Index: 0x0000000a")
        $setting.AC | Should -Be 4294967295
        $setting.DC | Should -Be 10
    }

    It "retorna nulo sem valores, com um único valor ou com entrada nula" -ForEach @(
        @{ Lines = @("nada aqui") }, @{ Lines = @("só um: 0x00000001") }, @{ Lines = @() }, @{ Lines = $null }
    ) {
        ConvertFrom-WinForgePowerQuery -Lines $Lines | Should -BeNullOrEmpty
    }

    It "ignora hexadecimais malformados" {
        ConvertFrom-WinForgePowerQuery -Lines @("0xZZZZZZZZ", "0x123") | Should -BeNullOrEmpty
    }
}

Describe "Ponto de restauração" {
    It "confirma a criação quando a sequência aumenta" {
        Use-RestorePointStubs -Sequences 5, 6
        try { (New-WinForgeRestorePoint).Kind | Should -Be "Ok" } finally { Clear-TestStubs }
    }

    It "avisa quando o Windows não criou um ponto novo (limite de 24 horas)" {
        Use-RestorePointStubs -Sequences 5, 5 -CheckpointWarns
        try {
            $result = New-WinForgeRestorePoint
            $result.Kind | Should -Be "Warning"
            $result.Status | Should -Match "já havia um ponto recente"
        }
        finally { Clear-TestStubs }
    }

    It "trata a primeira criação (nenhum ponto antes) como sucesso" {
        Use-RestorePointStubs -Sequences 0, 1
        try { (New-WinForgeRestorePoint).Kind | Should -Be "Ok" } finally { Clear-TestStubs }
    }

    It "não afirma sucesso quando há aviso e a consulta não funciona" {
        Use-RestorePointStubs -Sequences 1, 1 -QueryFails -CheckpointWarns
        try { (New-WinForgeRestorePoint).Kind | Should -Be "Warning" } finally { Clear-TestStubs }
    }

    It "aceita sucesso quando a consulta não funciona mas o comando terminou limpo" {
        Use-RestorePointStubs -Sequences 1, 1 -QueryFails
        try { (New-WinForgeRestorePoint).Kind | Should -Be "Ok" } finally { Clear-TestStubs }
    }

    It "devolve aviso 'não criado' quando a Proteção do Sistema está desativada" {
        Use-RestorePointStubs -Sequences 1, 1 -CheckpointError "System Restore is disabled on this drive."
        try {
            $result = New-WinForgeRestorePoint
            $result.Kind | Should -Be "Warning"
            $result.Status | Should -Match "não criado"
        }
        finally { Clear-TestStubs }
    }
}


Describe "Criar ponto de restauração, fluxo" {
    AfterEach { Clear-TestStubs; Clear-FakeReadHost }

    It "sem Administrador, falha logo e não tenta criar nada" {
        Use-TweakFlowStubs
        Use-RestorePointStubs -Sequences 1, 2
        Set-TestStub -Name "Test-WinForgeElevation" -Body { param ($Reason) $false }
        Set-FakeReadHost -Answers @("")

        [void](Get-HostText { $script:rp = Invoke-WinForgeRestorePoint -PassThru })

        $script:rp.Kind | Should -Be "Failed"
        $script:rp.Status | Should -Match "requer Administrador"
    }

    It "criado de primeira: não pergunta nada além do 'continuar'" {
        Use-TweakFlowStubs
        Use-RestorePointStubs -Sequences 5, 6
        Set-FakeReadHost -Answers @("")

        $text = Get-HostText { $script:rp = Invoke-WinForgeRestorePoint -PassThru }

        $script:rp.Kind | Should -Be "Ok"
        $text | Should -Match "Ponto de restauração criado"
        $text | Should -Not -Match "Proteção do Sistema"
    }

    It "Proteção do Sistema desligada: aceitar liga, tenta de novo e conclui" {
        Use-TweakFlowStubs
        Use-RestorePointStubs -Sequences 1, 1, 2 -CheckpointError "System Restore is disabled on this drive."
        Set-FakeReadHost -Answers @("S", "")

        $text = Get-HostText { $script:rp = Invoke-WinForgeRestorePoint -PassThru }

        $global:WfEnabled | Should -Not -BeNullOrEmpty
        $script:rp.Kind | Should -Be "Ok"
        $text | Should -Match "A Proteção do Sistema está desativada nesta unidade"
        $text | Should -Match "Proteção do Sistema ativada"
    }

    It "Proteção do Sistema desligada: a resposta padrão é não ativar, e o aviso permanece" {
        Use-TweakFlowStubs
        Use-RestorePointStubs -Sequences 1, 1 -CheckpointError "System Restore is disabled on this drive."
        Set-FakeReadHost -Answers @("", "")

        [void](Get-HostText { $script:rp = Invoke-WinForgeRestorePoint -PassThru })

        $global:WfEnabled | Should -BeNullOrEmpty
        $script:rp.Kind | Should -Be "Warning"
        $script:rp.Status | Should -Match "não criado"
    }

    It "se não for possível ativar a Proteção do Sistema, mostra o motivo e mantém o aviso" {
        Use-TweakFlowStubs -EnableFails
        Use-RestorePointStubs -Sequences 1, 1 -CheckpointError "System Restore is disabled on this drive."
        Set-FakeReadHost -Answers @("S", "")

        $text = Get-HostText { $script:rp = Invoke-WinForgeRestorePoint -PassThru }

        $script:rp.Kind | Should -Be "Warning"
        $text | Should -Match "Não foi possível ativar a Proteção do Sistema: acesso negado"
    }

    It "dentro da Manutenção (-Embedded) nunca pergunta, mesmo sem a Proteção do Sistema" {
        Use-TweakFlowStubs
        Use-RestorePointStubs -Sequences 1, 1 -CheckpointError "System Restore is disabled on this drive."

        $text = Get-HostText { $script:rp = Invoke-WinForgeRestorePoint -Embedded -PassThru }

        $global:WfEnabled | Should -BeNullOrEmpty
        $script:rp.Kind | Should -Be "Warning"
        $text | Should -Not -Match "Deseja ativar"
    }
}

Describe "Aplicar ajustes recomendados, fluxo" {
    BeforeEach { Reset-BackupFiles }
    AfterEach { Clear-TestStubs; Clear-FakeReadHost }

    It "com ponto de restauração criado, aplica e só então oferece reiniciar o Explorador" {
        Use-RegistryStub
        Use-TweakFlowStubs
        Use-RestorePointStubs -Sequences 5, 6
        # S = criar ponto; N = não reiniciar o Explorador; ENTER = continuar
        Set-FakeReadHost -Answers @("S", "N", "")

        $text = Get-HostText { $script:rt = Invoke-WinForgeRecommendedTweaks -Ids @("file-extensions") -PassThru }

        $script:rt.Kind | Should -Be "Ok"
        $global:WfReg["HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced|HideFileExt"] | Should -Be 0
        $global:WfLog | Should -Not -Contain "explorer-reiniciado"
        $text | Should -Match "1 ajuste\(s\) aplicado\(s\), 0 com problema"
        $text | Should -Match ([regex]::Escape("Ajustes do Windows > Desfazer ajustes do WinForge"))
    }

    It "aceitar reiniciar o Explorador reinicia" {
        Use-RegistryStub
        Use-TweakFlowStubs
        Use-RestorePointStubs -Sequences 5, 6
        Set-FakeReadHost -Answers @("S", "S", "")

        [void](Get-HostText { $script:rt = Invoke-WinForgeRecommendedTweaks -Ids @("file-extensions") -PassThru })

        $global:WfLog | Should -Contain "explorer-reiniciado"
    }

    It "dispensar o ponto de restauração aplica direto, sem falar de Proteção do Sistema" {
        Use-RegistryStub
        Use-TweakFlowStubs
        Use-RestorePointStubs -Sequences 5, 6 -CheckpointError "System Restore is disabled on this drive."
        Set-FakeReadHost -Answers @("N", "N", "")

        $text = Get-HostText { $script:rt = Invoke-WinForgeRecommendedTweaks -Ids @("file-extensions") -PassThru }

        $script:rt.Kind | Should -Be "Ok"
        $text | Should -Not -Match "Proteção do Sistema"
    }

    It "ponto de restauração não criado: por padrão os ajustes NÃO são aplicados" {
        Use-RegistryStub
        Use-TweakFlowStubs
        Use-RestorePointStubs -Sequences 1, 1 -CheckpointError "System Restore is disabled on this drive."
        # S = criar ponto; ENTER = não ativar a proteção; ENTER = não aplicar mesmo assim; ENTER = continuar
        Set-FakeReadHost -Answers @("S", "", "", "")

        $text = Get-HostText { $script:rt = Invoke-WinForgeRecommendedTweaks -Ids @("file-extensions") -PassThru }

        $script:rt.Kind | Should -Be "Skipped"
        $script:rt.Status | Should -Match "sem ponto de restauração"
        $global:WfReg.Count | Should -Be 0
        $text | Should -Match "Ajustes não aplicados"
    }

    It "ponto de restauração não criado: o usuário pode aplicar mesmo assim" {
        Use-RegistryStub
        Use-TweakFlowStubs
        Use-RestorePointStubs -Sequences 1, 1 -CheckpointError "System Restore is disabled on this drive."
        # S = criar ponto; ENTER = não ativar; S = aplicar mesmo assim; N = Explorador; ENTER = continuar
        Set-FakeReadHost -Answers @("S", "", "S", "N", "")

        [void](Get-HostText { $script:rt = Invoke-WinForgeRecommendedTweaks -Ids @("file-extensions") -PassThru })

        $script:rt.Kind | Should -Be "Ok"
        $global:WfReg["HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced|HideFileExt"] | Should -Be 0
    }

    It "dentro da Manutenção (-Embedded) aplica os Ids recebidos sem perguntar nada" {
        Use-RegistryStub
        Use-TweakFlowStubs

        $text = Get-HostText { $script:rt = Invoke-WinForgeRecommendedTweaks -Ids @("file-extensions") -Embedded -PassThru }

        $script:rt.Kind | Should -Be "Ok"
        $global:WfLog | Should -Not -Contain "explorer-reiniciado"
        $text | Should -Not -Match "Deseja|ponto de restauração"
    }

    It "sem nenhum Id, informa e devolve 'Ignorado'" {
        Use-RegistryStub
        Use-TweakFlowStubs
        Set-FakeReadHost -Answers @("")

        $text = Get-HostText { $script:rt = Invoke-WinForgeRecommendedTweaks -Ids @() -PassThru }

        $script:rt.Kind | Should -Be "Skipped"
        $text | Should -Match "Nenhum ajuste a aplicar"
    }

    It "um Id desconhecido vira falha daquele ajuste e o resumo reflete isso" {
        Use-RegistryStub
        Use-TweakFlowStubs

        $text = Get-HostText { $script:rt = Invoke-WinForgeRecommendedTweaks -Ids @("nao-existe", "file-extensions") -Embedded -PassThru }

        $script:rt.Kind | Should -Be "Warning"
        $text | Should -Match "Ajuste desconhecido: nao-existe"
        $text | Should -Match "1 ajuste\(s\) aplicado\(s\), 1 com problema"
    }
}

Describe "Alternar um ajuste, fluxo" {
    BeforeEach { Reset-BackupFiles }
    AfterEach { Clear-TestStubs; Clear-FakeReadHost }

    It "aplica com confirmação e explica como desfazer" {
        Use-RegistryStub
        Use-TweakFlowStubs
        $tweak = New-FakeTweak
        Set-FakeReadHost -Answers @("S", "")

        $text = Get-HostText { Invoke-WinForgeTweakToggle -Tweak $tweak }

        $global:WfFake.Value | Should -Be 1
        $text | Should -Match "Estado atual\s+:\s+Padrão do Windows"
        $text | Should -Match "Ajuste aplicado"
        $text | Should -Match "para desfazer, abra este ajuste de novo"
    }

    It "já aplicado: pergunta se quer desfazer e desfaz" {
        Use-RegistryStub
        Use-TweakFlowStubs
        $tweak = New-FakeTweak
        $global:WfFake.Value = 1
        Set-FakeReadHost -Answers @("S", "")

        $text = Get-HostText { Invoke-WinForgeTweakToggle -Tweak $tweak }

        $global:WfFake.Value | Should -Be 0
        $text | Should -Match "Estado atual\s+:\s+Aplicado"
        $text | Should -Match "Ajuste desfeito"
        $text | Should -Match "Não havia backup deste ajuste"
    }

    It "responder não cancela sem alterar nada" {
        Use-RegistryStub
        Use-TweakFlowStubs
        $tweak = New-FakeTweak
        Set-FakeReadHost -Answers @("N", "")

        $text = Get-HostText { Invoke-WinForgeTweakToggle -Tweak $tweak }

        $global:WfFake.Value | Should -Be 0
        $text | Should -Match "Operação cancelada"
    }

    It "na janela (-AlreadyConfirmed) o clique no botão já confirma: nenhuma pergunta extra" {
        Use-RegistryStub
        Use-TweakFlowStubs
        $tweak = New-FakeTweak
        Set-FakeReadHost -Answers @("")

        $text = Get-HostText { Invoke-WinForgeTweakToggle -Tweak $tweak -AlreadyConfirmed }

        $global:WfFake.Value | Should -Be 1
        $text | Should -Not -Match "Deseja aplicar"
    }

    It "em notebook, ajuste que gasta bateria continua pedindo confirmação mesmo vindo da janela" {
        Use-RegistryStub
        Use-TweakFlowStubs -Laptop
        $global:WfFake = @{ Value = 0 }
        $tweak = New-WinForgeTweak -Id "gasta-bateria" -Category "Energia e desempenho" -Name "Ajuste que gasta bateria" -Description "teste" `
            -LaptopRisk -Warning "Em notebook, gasta mais bateria." `
            -Capture { @{ Value = $global:WfFake.Value } } -Apply { $global:WfFake.Value = 1 } `
            -Revert { param ($Saved) $global:WfFake.Value = 0 } -Test { $global:WfFake.Value -eq 1 }
        Set-FakeReadHost -Answers @("N", "")

        $text = Get-HostText { Invoke-WinForgeTweakToggle -Tweak $tweak -AlreadyConfirmed }

        $global:WfFake.Value | Should -Be 0
        $text | Should -Match "Em notebook, gasta mais bateria"
        $text | Should -Match "Operação cancelada"
    }

    It "o ajuste que o Windows não mantém é avisado em vez de declarado aplicado" {
        Use-RegistryStub
        Use-TweakFlowStubs
        $global:WfFake = @{ Value = 0 }
        $tweak = New-WinForgeTweak -Id "politica" -Category "Explorador" -Name "Ajuste imposto por política" -Description "teste" `
            -Capture { @{ Value = $global:WfFake.Value } } -Apply { } `
            -Revert { param ($Saved) } -Test { $global:WfFake.Value -eq 1 }
        Set-FakeReadHost -Answers @("S", "")

        $text = Get-HostText { Invoke-WinForgeTweakToggle -Tweak $tweak }

        $text | Should -Match "o Windows não o manteve"
        $text | Should -Not -Match "Ajuste aplicado\."
    }

    It "uma falha ao aplicar vira mensagem, sem exceção" {
        Use-RegistryStub
        Use-TweakFlowStubs
        $tweak = New-FakeTweak -FailApply
        Set-FakeReadHost -Answers @("S", "")

        (Get-HostText { Invoke-WinForgeTweakToggle -Tweak $tweak }) | Should -Match "Falha ao alterar o ajuste: falha ao aplicar"
    }
}

Describe "Desfazer ajustes do WinForge, fluxo" {
    BeforeEach { Reset-BackupFiles }
    AfterEach { Clear-TestStubs; Clear-FakeReadHost }

    It "sem backups, informa e não pergunta nada" {
        Use-RegistryStub
        Use-TweakFlowStubs
        Set-FakeReadHost -Answers @("")

        $text = Get-HostText { Invoke-WinForgeRevertAllTweaks }

        $text | Should -Match "Não há ajustes do WinForge com backup para desfazer"
        $text | Should -Not -Match "Deseja desfazer"
    }

    It "só backups de ajustes desconhecidos: explica e não desfaz nada" {
        Use-RegistryStub
        Use-TweakFlowStubs
        Save-WinForgeTweakBackup -Backup ([ordered]@{ "ajuste-de-outra-versao" = [ordered]@{ AppliedAt = "2026-01-01T10:00:00"; Original = @{ Value = 1 } } })
        Set-FakeReadHost -Answers @("")

        $text = Get-HostText { Invoke-WinForgeRevertAllTweaks }

        $text | Should -Match "ajuste-de-outra-versao"
        $text | Should -Match "Nada foi desfeito"
        $text | Should -Not -Match "Deseja desfazer"
        (Read-WinForgeTweakBackup).Contains("ajuste-de-outra-versao") | Should -BeTrue
    }

    It "a resposta padrão é não desfazer" {
        Use-RegistryStub
        Use-TweakFlowStubs
        Invoke-WinForgeTweakApply -Tweak (Get-WinForgeTweakById -Id "dark-mode")
        Set-FakeReadHost -Answers @("", "")

        $text = Get-HostText { Invoke-WinForgeRevertAllTweaks }

        $text | Should -Match "Operação cancelada"
        (Get-WinForgeTweakStatus -Tweak (Get-WinForgeTweakById -Id "dark-mode")) | Should -Be "Aplicado"
    }

    It "desfaz todos, lista os nomes, limpa o backup e oferece o Explorador só se algum precisou" {
        Use-RegistryStub
        Use-TweakFlowStubs
        Invoke-WinForgeTweakApply -Tweak (Get-WinForgeTweakById -Id "dark-mode")
        Invoke-WinForgeTweakApply -Tweak (Get-WinForgeTweakById -Id "file-extensions")
        # S = desfazer todos; S = reiniciar o Explorador; ENTER = continuar
        Set-FakeReadHost -Answers @("S", "S", "")

        $text = Get-HostText { Invoke-WinForgeRevertAllTweaks }

        $text | Should -Match "Mostrar extensões de arquivos"
        $text | Should -Match "Modo escuro"
        $text | Should -Match "2 ajuste\(s\) desfeito\(s\)"
        (Get-WinForgeTweakStatus -Tweak (Get-WinForgeTweakById -Id "dark-mode")) | Should -Be "Padrão"
        (Get-WinForgeTweakStatus -Tweak (Get-WinForgeTweakById -Id "file-extensions")) | Should -Be "Padrão"
        (Read-WinForgeTweakBackup).Count | Should -Be 0
        $global:WfLog | Should -Contain "explorer-reiniciado"
    }

    It "sem ajustes que exijam o Explorador, não pergunta sobre ele" {
        Use-RegistryStub
        Use-TweakFlowStubs
        Invoke-WinForgeTweakApply -Tweak (Get-WinForgeTweakById -Id "dark-mode")
        Set-FakeReadHost -Answers @("S", "")

        $text = Get-HostText { Invoke-WinForgeRevertAllTweaks }

        $text | Should -Not -Match "Explorador"
        $global:WfLog | Should -Not -Contain "explorer-reiniciado"
    }

    It "se um ajuste não puder ser desfeito, avisa, mantém o backup dele e não declara sucesso total" {
        Use-RegistryStub
        Use-TweakFlowStubs
        Invoke-WinForgeTweakApply -Tweak (Get-WinForgeTweakById -Id "dark-mode")
        # Desfazer restaura o original: grava de volta o valor ou, se ele não existia, remove o que o WinForge criou.
        Set-TestStub -Name "Set-WinForgeRegistryDWord" -Body { param ($Path, $Name, $Value) throw "chave bloqueada" }
        Set-TestStub -Name "Remove-WinForgeRegistryValue" -Body { param ($Path, $Name) throw "chave bloqueada" }
        Set-FakeReadHost -Answers @("S", "")

        $text = Get-HostText { Invoke-WinForgeRevertAllTweaks }

        $text | Should -Match "Modo escuro: .*chave bloqueada"
        $text | Should -Match "1 ajuste\(s\) não puderam ser desfeitos"
        $text | Should -Not -Match "ajuste\(s\) desfeito\(s\)\."
        (Read-WinForgeTweakBackup).Contains("dark-mode") | Should -BeTrue
    }
}

Describe "Página Ajustes do Windows" {
    It "as ações da página usam os mesmos nomes dos títulos que abrem" {
        $page = Get-WinForgeNavPage -Id "tweaks"
        $expected = @{
            "tweaks.recommended"    = "Aplicar ajustes recomendados"
            "tweaks.restore-point"  = "Criar ponto de restauração"
            "tweaks.revert-all"     = "Desfazer ajustes do WinForge"
        }

        foreach ($id in $expected.Keys) {
            $item = $page.Items | Where-Object { $_.Id -eq $id }
            $item.Label | Should -Be $expected[$id]
        }
    }

    It "todas as categorias do catálogo aparecem na visão geral, na ordem de exibição" {
        Use-RegistryStub
        try {
            $overview = @(Get-WinForgeTweakOverview)
            $order = @(Get-WinForgeTweakCategories)
            $seen = @($overview | ForEach-Object { $_.Category } | Select-Object -Unique)

            ($seen -join ",") | Should -Be (($order | Where-Object { $seen -contains $_ }) -join ",")
        }
        finally { Clear-TestStubs }
    }
}


Describe "Chave liga/desliga dos ajustes" {
    It "<Status>: a chave fica <Chave>, com o texto '<Texto>'" -ForEach @(
        @{ Status = "Aplicado";     Chave = "ligada";    On = $true;  Texto = "Aplicado";         Nivel = "Ok" },
        @{ Status = "Padrão";       Chave = "desligada"; On = $false; Texto = "Padrão";           Nivel = "Muted" },
        @{ Status = "Desconhecido"; Chave = "desligada"; On = $false; Texto = "Não identificado"; Nivel = "Warn" },
        @{ Status = "";             Chave = "desligada"; On = $false; Texto = "Padrão";           Nivel = "Muted" }
    ) {
        $state = Get-WinForgeTweakSwitchState -Status $Status

        $state.IsOn | Should -Be $On
        $state.Caption | Should -Be $Texto
        $state.Level | Should -Be $Nivel
    }

    It "todo estado que a visão geral devolve tem uma chave definida" {
        Use-RegistryStub
        try {
            foreach ($tweak in @(Get-WinForgeTweakOverview)) {
                $state = Get-WinForgeTweakSwitchState -Status $tweak.Status
                $state.Level | Should -Match "^(Ok|Warn|Muted)$"
                $state.Caption | Should -Not -BeNullOrEmpty
            }
        }
        finally { Clear-TestStubs }
    }
}
