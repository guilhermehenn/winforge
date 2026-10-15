# Manutenção recomendada: ordem do plano, isolamento de falhas por etapa, fases e fluxo completo.
# As ações reais (DISM, SFC, winget, reinício...) são substituídas por versões de teste que só registram a chamada.

BeforeAll {
    . (Join-Path $PSScriptRoot "TestSetup.ps1")

    $script:AutoStubNames = @(
        "Invoke-WinForgeRestorePoint", "Invoke-WinForgeNetworkRepair", "Invoke-WinForgeQuickCleanup",
        "Invoke-WinForgeDismAndSfc", "Start-WinForgeChkdsk", "Invoke-WinForgeDeviceScan",
        "Invoke-WinForgeSecurityCheck", "Start-WinForgeDriveOptimization"
    )

    function script:Use-MaintenanceStubs {
        # Cada ação vira um registro em $global:WfLog e devolve um resultado Ok. Nada toca no sistema.
        $global:WfLog = New-Object System.Collections.ArrayList
        $global:WfAdmin = $true
        $global:WfPendingReboot = $false
        $global:WfOnBattery = $false
        $global:WfFreeBytes = [int64]200GB

        foreach ($name in $script:AutoStubNames) {
            Set-TestStub -Name $name -Body ([scriptblock]::Create("[void]`$global:WfLog.Add('$name'); New-WinForgeResult -Kind Ok"))
        }

        Set-TestStub -Name "Invoke-WinForgeRecommendedTweaks" -Body {
            param ([string[]]$Ids, [switch]$Embedded, [switch]$PassThru)
            [void]$global:WfLog.Add("tweaks:" + (@($Ids) -join ","))
            New-WinForgeResult -Kind Ok
        }
        Set-TestStub -Name "Invoke-WinForgeWingetUpgradePlan" -Body {
            param ($Plan)
            [void]$global:WfLog.Add("winget:" + $Plan.Action)
            New-WinForgeResult -Kind Ok
        }
        Set-TestStub -Name "Select-WinForgeRecommendedTweaks" -Body { [void]$global:WfLog.Add("select-tweaks"); @("file-extensions") }
        Set-TestStub -Name "Get-WinForgeWingetUpgradePlan" -Body {
            [void]$global:WfLog.Add("winget-plan")
            [PSCustomObject]@{ Action = "All"; Ids = @(); Packages = @() }
        }
        Set-TestStub -Name "Open-WinForgeShortcut" -Body {
            param ([string]$Name, [switch]$Quiet)
            [void]$global:WfLog.Add("abrir:$Name")
            $true
        }
        Set-TestStub -Name "Set-WinForgeKeepAwake" -Body {
            param ([bool]$Enabled)
            [void]$global:WfLog.Add("awake:$Enabled")
            $true
        }
        Set-TestStub -Name "Test-WinForgeAdministrator" -Body { [bool]$global:WfAdmin }
        Set-TestStub -Name "Test-WinForgePendingReboot" -Body { [bool]$global:WfPendingReboot }
        Set-TestStub -Name "Test-WinForgeOnBattery" -Body { [bool]$global:WfOnBattery }
        Set-TestStub -Name "Get-WinForgeSystemDriveFreeBytes" -Body { [int64]$global:WfFreeBytes }
        Set-TestStub -Name "Start-WinForgeLogging" -Body { $true }
        Set-TestStub -Name "Restart-WinForgeExplorerShell" -Body { [void]$global:WfLog.Add("explorer-reiniciado") }
        Set-TestStub -Name "Invoke-WinForgeCapture" -Body {
            # Qualquer tentativa de executar um nativo (shutdown.exe, por exemplo) fica registrada e não executa.
            param ([string]$FilePath, [string[]]$Arguments)
            [void]$global:WfLog.Add("nativo:$FilePath")
            [PSCustomObject]@{ ExitCode = 0; Text = ""; Lines = @() }
        }
    }

    function script:New-Details {
        param ([string[]]$TweakIds = @(), $WingetPlan = $null)
        [PSCustomObject]@{ TweakIds = $TweakIds; WingetPlan = $WingetPlan }
    }

    function script:Get-AutoStep {
        param ([string]$Id)
        Get-WinForgeMaintenancePlanItems | Where-Object { $_.Id -eq $Id }
    }
}

AfterAll {
    Remove-Variable WfLog, WfAdmin, WfPendingReboot, WfOnBattery, WfFreeBytes -Scope Global -ErrorAction SilentlyContinue
    Remove-WinForgeTestData
}

Describe "Plano da manutenção" {
    It "tem IDs únicos e fases válidas" {
        $items = @(Get-WinForgeMaintenancePlanItems)

        ($items.Id | Select-Object -Unique) | Should -HaveCount $items.Count

        foreach ($item in $items) {
            $item.Phase | Should -Match "^(Before|Auto|After)$"
            $item.Title | Should -Not -BeNullOrEmpty
            $item.Description | Should -Not -BeNullOrEmpty
            $item.Id | Should -Match "^[a-z0-9][a-z0-9-]*$"
        }
    }

    It "agrupa as fases nesta ordem: revisão antes, automático, depois" {
        $phases = @(Get-WinForgeMaintenancePlanItems | ForEach-Object { $_.Phase })

        $firstAuto = $phases.IndexOf("Auto")
        $firstAfter = $phases.IndexOf("After")
        $lastBefore = $phases.LastIndexOf("Before")
        $lastAuto = $phases.LastIndexOf("Auto")

        $lastBefore | Should -BeLessThan $firstAuto
        $lastAuto | Should -BeLessThan $firstAfter
    }

    It "executa as etapas automáticas na ordem que faz sentido" {
        $auto = @(Get-WinForgeMaintenancePlanItems | Where-Object { $_.Phase -eq "Auto" } | ForEach-Object { $_.Id })

        ($auto -join ",") | Should -Be "restore-point,network,cleanup,repair,chkdsk,winget,drivers,security,optimize,tweaks"
    }

    It "garante as dependências entre etapas: proteger, limpar antes de reparar, otimizar por último entre as de disco" {
        $auto = @(Get-WinForgeMaintenancePlanItems | Where-Object { $_.Phase -eq "Auto" } | ForEach-Object { $_.Id })

        $auto[0] | Should -Be "restore-point"
        $auto.IndexOf("network") | Should -BeLessThan $auto.IndexOf("winget")
        $auto.IndexOf("cleanup") | Should -BeLessThan $auto.IndexOf("repair")
        $auto.IndexOf("repair") | Should -BeLessThan $auto.IndexOf("optimize")
        $auto.IndexOf("cleanup") | Should -BeLessThan $auto.IndexOf("optimize")
        $auto.IndexOf("winget") | Should -BeLessThan $auto.IndexOf("optimize")
        # O antivírus verifica o PC já limpo, reparado e com os programas atualizados.
        $auto.IndexOf("cleanup") | Should -BeLessThan $auto.IndexOf("security")
        $auto.IndexOf("winget") | Should -BeLessThan $auto.IndexOf("security")
    }

    It "deixa o Windows Update para depois dos reparos e as revisões de programas para antes" {
        $ids = @(Get-WinForgeMaintenancePlanItems | ForEach-Object { $_.Id })

        $ids.IndexOf("downloads") | Should -BeLessThan $ids.IndexOf("cleanup")
        $ids.IndexOf("installed-apps") | Should -BeLessThan $ids.IndexOf("winget")
        $ids.IndexOf("repair") | Should -BeLessThan $ids.IndexOf("windows-update")
        $ids.IndexOf("storage") | Should -BeLessThan $ids.IndexOf("windows-update")
    }

    It "etapas manuais têm atalho existente e orientação; automáticas não têm atalho" {
        $known = @(Get-WinForgeShortcutNames)

        foreach ($item in @(Get-WinForgeMaintenancePlanItems)) {
            if ($item.Phase -eq "Auto") {
                $item.Shortcut | Should -BeNullOrEmpty
                $item.Kind | Should -Be "Automático"
            }
            else {
                $known | Should -Contain $item.Shortcut
                $item.Hint | Should -Not -BeNullOrEmpty
                $item.Kind | Should -Be "Manual"
            }
        }
    }

    It "cada etapa automática usa o nome exato do item do menu lateral que faz a mesma coisa" {
        $map = [ordered]@{
            "restore-point" = "maintenance.restore-point"
            "network"       = "network.repair"
            "cleanup"       = "cleanup.quick"
            "repair"        = "repair.dism-sfc"
            "chkdsk"        = "repair.chkdsk"
            "winget"        = "updates.winget"
            "drivers"       = "repair.device-scan"
            "security"       = $null
            "optimize"      = "repair.optimize"
            "tweaks"        = "tweaks.recommended"
        }

        $auto = @(Get-WinForgeMaintenancePlanItems | Where-Object { $_.Phase -eq "Auto" })
        $auto | Should -HaveCount $map.Count

        foreach ($item in $auto) {
            $map.Keys | Should -Contain $item.Id

            # A etapa de segurança faz duas coisas (assinaturas e verificação rápida) e não tem um único item equivalente.
            if ($null -ne $map[$item.Id]) {
                $item.Title | Should -Be (Get-WinForgeNavItem -Id $map[$item.Id]).Label
            }
        }
    }

    It "cada etapa manual abre o mesmo atalho do item correspondente do menu lateral" {
        $map = [ordered]@{
            "startup-apps"      = "software.startup"
            "installed-apps"    = "software.installed-apps"
            "programs-features" = "software.programs-features"
            "storage"           = "cleanup.storage"
            "windows-update"    = "updates.windows"
            "optional-updates"  = "updates.optional"
            "store-updates"     = "updates.store"
        }

        foreach ($key in $map.Keys) {
            $planItem = @(Get-WinForgeMaintenancePlanItems | Where-Object { $_.Id -eq $key })[0]
            $navItem = Get-WinForgeNavItem -Id $map[$key]

            $navItem.Kind | Should -Be "Shortcut"
            $planItem.Shortcut | Should -Be $navItem.Shortcut
        }
    }

    It "o plano em lista segue a ordem de execução e devolve os marcados nessa ordem" {
        try {
            # 16 = Windows Update (depois), 5 = ponto de restauração, 7 = limpeza; espaços extras são tolerados.
            Set-FakeReadHost -Answers @("16, 5 ,7")
            $picked = @(Read-WinForgeMaintenancePlan)
            ($picked -join ",") | Should -Be "restore-point,cleanup,windows-update"
        }
        finally { Clear-FakeReadHost }
    }

    It "T marca tudo, ENTER cancela" {
        try {
            Set-FakeReadHost -Answers @("T")
            @(Read-WinForgeMaintenancePlan) | Should -HaveCount @(Get-WinForgeMaintenancePlanItems).Count

            Set-FakeReadHost -Answers @("")
            Read-WinForgeMaintenancePlan | Should -BeNullOrEmpty
        }
        finally { Clear-FakeReadHost }
    }
}

Describe "Ações das etapas automáticas" {
    It "toda etapa automática do plano tem uma ação correspondente" {
        Use-MaintenanceStubs
        try {
            foreach ($step in @(Get-WinForgeMaintenancePlanItems | Where-Object { $_.Phase -eq "Auto" })) {
                $details = New-Details -TweakIds @("file-extensions") -WingetPlan ([PSCustomObject]@{ Action = "All"; Ids = @(); Packages = @() })
                { $null = Invoke-WinForgeMaintenanceStepAction -Id $step.Id -Details $details } | Should -Not -Throw
            }

            $global:WfLog | Should -Contain "winget:All"
            $global:WfLog | Should -Contain "tweaks:file-extensions"
        }
        finally { Clear-TestStubs }
    }

    It "rejeita um Id desconhecido em vez de ignorar em silêncio" {
        { Invoke-WinForgeMaintenanceStepAction -Id "nao-existe" -Details (New-Details) } | Should -Throw -ExpectedMessage "*Etapa desconhecida*"
    }

    It "winget sem plano revisado vira 'Ignorado', não sucesso" {
        Use-MaintenanceStubs
        try {
            $result = @(Invoke-WinForgeMaintenanceStepAction -Id "winget" -Details (New-Details))
            $result[-1].Kind | Should -Be "Skipped"
        }
        finally { Clear-TestStubs }
    }
}

Describe "Uma etapa" {
    It "devolve exatamente um resultado, com título, duração e Id da etapa" {
        Use-MaintenanceStubs
        try {
            $result = @(Invoke-WinForgeMaintenanceStep -Step (Get-AutoStep "cleanup") -Details (New-Details) -Position 1 -Total 3)

            $result | Should -HaveCount 1
            $result[0].Kind | Should -Be "Ok"
            $result[0].Etapa | Should -Be (Get-AutoStep "cleanup").Title
            $result[0].StepId | Should -Be "cleanup"
            $result[0].Duracao | Should -Not -BeNullOrEmpty
        }
        finally { Clear-TestStubs }
    }

    It "uma exceção vira resultado 'Falhou' com a mensagem, sem derrubar o fluxo" {
        Use-MaintenanceStubs
        Set-TestStub -Name "Invoke-WinForgeQuickCleanup" -Body { throw "disco cheio" }
        try {
            $result = @(Invoke-WinForgeMaintenanceStep -Step (Get-AutoStep "cleanup") -Details (New-Details) -Position 1 -Total 1)

            $result | Should -HaveCount 1
            $result[0].Kind | Should -Be "Failed"
            $result[0].Status | Should -Match "disco cheio"
            $result[0].StepId | Should -Be "cleanup"
        }
        finally { Clear-TestStubs }
    }

    It "texto e objetos soltos da etapa não entram no resumo" {
        Use-MaintenanceStubs
        Set-TestStub -Name "Invoke-WinForgeQuickCleanup" -Body {
            "linha solta"
            [PSCustomObject]@{ Nome = "objeto qualquer" }
            New-WinForgeResult -Kind Warning -Detail "uma ressalva"
        }
        try {
            # O texto solto vai para a tela por Out-Host (que o teste não captura); aqui só importa o que sobra no pipeline.
            $captured = @(Invoke-WinForgeMaintenanceStep -Step (Get-AutoStep "cleanup") -Details (New-Details) -Position 1 -Total 1 6>$null)

            $captured | Should -HaveCount 1
            $captured[0].Kind | Should -Be "Warning"
            $captured[0].PSObject.TypeNames | Should -Contain "WinForge.Result"
        }
        finally { Clear-TestStubs }
    }

    It "sem resultado explícito conta como Ok" {
        Use-MaintenanceStubs
        Set-TestStub -Name "Invoke-WinForgeQuickCleanup" -Body { }
        try {
            $result = @(Invoke-WinForgeMaintenanceStep -Step (Get-AutoStep "cleanup") -Details (New-Details) -Position 1 -Total 1)
            $result | Should -HaveCount 1
            $result[0].Kind | Should -Be "Ok"
        }
        finally { Clear-TestStubs }
    }

    It "com vários resultados, vale o último" {
        Use-MaintenanceStubs
        Set-TestStub -Name "Invoke-WinForgeQuickCleanup" -Body {
            New-WinForgeResult -Kind Ok
            New-WinForgeResult -Kind Failed -Detail "último"
        }
        try {
            $result = @(Invoke-WinForgeMaintenanceStep -Step (Get-AutoStep "cleanup") -Details (New-Details) -Position 1 -Total 1)
            $result | Should -HaveCount 1
            $result[0].Kind | Should -Be "Failed"
        }
        finally { Clear-TestStubs }
    }
}

Describe "Fase automática" {
    It "executa na ordem do plano, não na ordem em que os Ids chegaram" {
        Use-MaintenanceStubs
        try {
            $results = @(Invoke-WinForgeAutomaticPhase -StepIds @("tweaks", "cleanup", "restore-point") -Details (New-Details -TweakIds @("file-extensions")))

            ($results.StepId -join ",") | Should -Be "restore-point,cleanup,tweaks"
            $order = @($global:WfLog | Where-Object { $_ -notlike "awake:*" })
            ($order -join "|") | Should -Be "Invoke-WinForgeRestorePoint|Invoke-WinForgeQuickCleanup|tweaks:file-extensions"
        }
        finally { Clear-TestStubs }
    }

    It "uma etapa que falha não impede as seguintes" {
        Use-MaintenanceStubs
        Set-TestStub -Name "Invoke-WinForgeNetworkRepair" -Body { throw "sem adaptador" }
        try {
            $results = @(Invoke-WinForgeAutomaticPhase -StepIds @("restore-point", "network", "cleanup") -Details (New-Details))

            $results | Should -HaveCount 3
            ($results.Kind -join ",") | Should -Be "Ok,Failed,Ok"
        }
        finally { Clear-TestStubs }
    }

    It "mantém o PC acordado durante a fase e libera ao final" {
        Use-MaintenanceStubs
        try {
            [void](Invoke-WinForgeAutomaticPhase -StepIds @("cleanup") -Details (New-Details))

            $awake = @($global:WfLog | Where-Object { $_ -like "awake:*" })
            ($awake -join ",") | Should -Be "awake:True,awake:False"
        }
        finally { Clear-TestStubs }
    }

    It "libera o PC mesmo se algo inesperado interromper a fase" {
        Use-MaintenanceStubs
        # Falha fora do tratamento por etapa: no desenho da barra de progresso.
        Set-TestStub -Name "Write-WinForgeProgress" -Body { throw "falha fora da etapa" }
        try {
            { Invoke-WinForgeAutomaticPhase -StepIds @("cleanup") -Details (New-Details) } | Should -Throw

            $awake = @($global:WfLog | Where-Object { $_ -like "awake:*" })
            ($awake -join ",") | Should -Be "awake:True,awake:False"
        }
        finally { Clear-TestStubs }
    }

    It "ignora Ids que não existem no plano" {
        Use-MaintenanceStubs
        try {
            $results = @(Invoke-WinForgeAutomaticPhase -StepIds @("cleanup", "inexistente") -Details (New-Details))
            $results | Should -HaveCount 1
        }
        finally { Clear-TestStubs }
    }
}

Describe "Resumo" {
    It "não falha sem nenhuma etapa executada" {
        Reset-LastMaintenanceMemory
        $text = Get-HostText { Show-WinForgeMaintenanceSummary -Results @() -StartedAt (Get-Date) }
        $text | Should -Match "Nenhuma etapa foi executada"
    }

    It "aponta falhas e ressalvas, e guarda o resultado para o relatório" {
        Reset-LastMaintenanceMemory
        $results = @(
            (New-WinForgeResult -Kind Ok -Title "A"),
            (New-WinForgeResult -Kind Failed -Detail "erro" -Title "B"),
            (New-WinForgeResult -Kind Warning -Detail "cuidado" -Title "C")
        )

        $text = Get-HostText { Show-WinForgeMaintenanceSummary -Results $results -StartedAt (Get-Date).AddMinutes(-2) }

        $text | Should -Match "1 etapa\(s\) falharam e 1 terminaram com ressalvas"
        @((Get-WinForgeLastMaintenance).Results) | Should -HaveCount 3
    }

    It "afirma sucesso total somente quando tudo foi Ok" {
        Reset-LastMaintenanceMemory
        $text = Get-HostText { Show-WinForgeMaintenanceSummary -Results @((New-WinForgeResult -Kind Ok -Title "A")) -StartedAt (Get-Date) }
        $text | Should -Match "Todas as etapas automáticas foram concluídas"
    }

    It "ignora objetos que não são resultados de etapa" {
        Reset-LastMaintenanceMemory
        $text = Get-HostText { Show-WinForgeMaintenanceSummary -Results @($null, "texto", [PSCustomObject]@{ X = 1 }, (New-WinForgeResult -Kind Ok -Title "A")) -StartedAt (Get-Date) }
        $text | Should -Match "Todas as etapas automáticas foram concluídas"
        @((Get-WinForgeLastMaintenance).Results) | Should -HaveCount 1
    }
}

Describe "Antes e depois" {
    AfterEach { Clear-TestStubs; Remove-Variable WfSpace, WfStartup, WfStartupFails -Scope Global -ErrorAction SilentlyContinue }

    BeforeAll {
        function script:New-Snapshot {
            param ($Free = $null, $Startup = $null, [datetime]$At = (Get-Date))
            [PSCustomObject]@{ At = $At; FreeBytes = $Free; StartupItems = $Startup }
        }
    }

    It "a foto lê o espaço livre do disco do sistema e conta só os itens ativos da inicialização" {
        $global:WfSpace = [PSCustomObject]@{ FreeBytes = [int64]120GB; TotalBytes = [int64]500GB }
        $global:WfStartup = @(
            [PSCustomObject]@{ Name = "A"; Source = "x"; Enabled = $true },
            [PSCustomObject]@{ Name = "B"; Source = "x"; Enabled = $false },
            [PSCustomObject]@{ Name = "C"; Source = "x"; Enabled = $true }
        )
        Set-TestStub -Name "Get-WinForgeSystemDriveSpace" -Body { $global:WfSpace }
        Set-TestStub -Name "Get-WinForgeStartupItems" -Body { $global:WfStartup }

        $snapshot = Get-WinForgeMaintenanceSnapshot

        $snapshot.FreeBytes | Should -Be 120GB
        $snapshot.StartupItems | Should -Be 2
        $snapshot.At | Should -BeOfType ([datetime])
    }

    It "o que não puder ser lido fica nulo, sem derrubar a manutenção" {
        Set-TestStub -Name "Get-WinForgeSystemDriveSpace" -Body { throw "unidade sumiu" }
        Set-TestStub -Name "Get-WinForgeStartupItems" -Body { throw "registro negado" }

        $snapshot = Get-WinForgeMaintenanceSnapshot

        $snapshot.FreeBytes | Should -BeNullOrEmpty
        $snapshot.StartupItems | Should -BeNullOrEmpty
    }

    It "nenhum item na inicialização é zero, não 'não lido'" {
        Set-TestStub -Name "Get-WinForgeSystemDriveSpace" -Body { $null }
        Set-TestStub -Name "Get-WinForgeStartupItems" -Body { @() }

        $snapshot = Get-WinForgeMaintenanceSnapshot

        $snapshot.StartupItems | Should -Be 0
        $snapshot.FreeBytes | Should -BeNullOrEmpty
    }

    It "compara espaço livre e inicialização, com o sinal da mudança" {
        $rows = @(Get-WinForgeSnapshotComparison -Before (New-Snapshot -Free 100GB -Startup 18) -After (New-Snapshot -Free 112GB -Startup 15))

        $rows | Should -HaveCount 2
        $rows[0].Label | Should -Be "Espaço livre no disco do sistema"
        $rows[0].Text | Should -Be "de 100 GB para 112 GB (+12 GB)"
        $rows[1].Label | Should -Be "Programas que abrem com o Windows"
        $rows[1].Text | Should -Be "de 18 para 15 (-3)"
    }

    It "espaço que diminuiu aparece com sinal negativo; variação menor que 1 MB e itens iguais viram 'sem mudança'" {
        $rows = @(Get-WinForgeSnapshotComparison -Before (New-Snapshot -Free 100GB -Startup 5) -After (New-Snapshot -Free 98GB -Startup 5))
        $rows[0].Text | Should -Be "de 100 GB para 98 GB (-2 GB)"
        $rows[1].Text | Should -Be "de 5 para 5 (sem mudança)"

        $same = @(Get-WinForgeSnapshotComparison -Before (New-Snapshot -Free 100GB) -After (New-Snapshot -Free ([int64]100GB + 500KB)))
        $same[0].Text | Should -Match "\(sem mudança\)"
    }

    It "itens a mais na inicialização aparecem com '+'" {
        $rows = @(Get-WinForgeSnapshotComparison -Before (New-Snapshot -Startup 3) -After (New-Snapshot -Startup 4))

        $rows | Should -HaveCount 1
        $rows[0].Text | Should -Be "de 3 para 4 (+1)"
    }

    It "linha cujo dado falta em uma das fotos não aparece; sem fotos, nenhuma linha" {
        @(Get-WinForgeSnapshotComparison -Before (New-Snapshot -Free 10GB) -After (New-Snapshot -Startup 3)) | Should -HaveCount 0
        @(Get-WinForgeSnapshotComparison -Before $null -After (New-Snapshot -Free 10GB -Startup 1)) | Should -HaveCount 0
        @(Get-WinForgeSnapshotComparison -Before (New-Snapshot -Free 10GB -Startup 1) -After $null) | Should -HaveCount 0
    }

    It "o resumo mostra o bloco 'Antes e depois' e guarda as fotos para o relatório" {
        Reset-LastMaintenanceMemory
        $before = New-Snapshot -Free 100GB -Startup 18 -At (Get-Date).AddMinutes(-30)
        $after = New-Snapshot -Free 110GB -Startup 16

        $text = Get-HostText { Show-WinForgeMaintenanceSummary -Results @((New-WinForgeResult -Kind Ok -Title "A")) -StartedAt (Get-Date).AddMinutes(-25) -Before $before -After $after }

        $text | Should -Match "Antes e depois"
        $text | Should -Match "de 100 GB para 110 GB \(\+10 GB\)"
        $text | Should -Match "de 18 para 16 \(-2\)"
        (Get-WinForgeLastMaintenance).Before.StartupItems | Should -Be 18
        (Get-WinForgeLastMaintenance).After.FreeBytes | Should -Be 110GB
    }

    It "sem fotos o resumo não mostra o bloco" {
        Reset-LastMaintenanceMemory

        $text = Get-HostText { Show-WinForgeMaintenanceSummary -Results @((New-WinForgeResult -Kind Ok -Title "A")) -StartedAt (Get-Date) }

        $text | Should -Not -Match "Antes e depois"
    }

    It "o relatório da última manutenção inclui o antes e depois e a duração da fase automática" {
        Reset-LastMaintenanceMemory
        $started = Get-Date "2026-03-04T10:00:00"

        Set-WinForgeLastMaintenance -Results @((New-WinForgeResult -Kind Ok -Title "Limpeza")) -StartedAt $started `
            -Before (New-Snapshot -Free 50GB -Startup 9 -At $started.AddMinutes(-5)) -After (New-Snapshot -Free 58GB -Startup 7 -At $started.AddMinutes(42))

        $section = Get-WinForgeReportSections | Where-Object { $_.Title -like "Última manutenção*" }
        $text = ($section.Items | ForEach-Object { "$($_.Label): $($_.Value)" }) -join "`n"

        $text | Should -Match "Espaço livre no disco do sistema: de 50 GB para 58 GB \(\+8 GB\)"
        $text | Should -Match "Programas que abrem com o Windows: de 9 para 7 \(-2\)"
        $text | Should -Match "Duração da fase automática: 42min 00s \(das 10:00 às 10:42\)"
    }

    It "o relatório de uma manutenção sem fotos (versão antiga) não ganha linhas vazias" {
        Reset-LastMaintenanceMemory
        Set-WinForgeLastMaintenance -Results @((New-WinForgeResult -Kind Ok -Title "Limpeza")) -StartedAt (Get-Date)

        $section = Get-WinForgeReportSections | Where-Object { $_.Title -like "Última manutenção*" }

        @($section.Items) | Should -HaveCount 1
    }

    It "na manutenção completa, a foto do 'antes' vem antes da revisão manual e a do 'depois' vem da fase automática" {
        Use-MaintenanceStubs
        $global:WfSpace = [PSCustomObject]@{ FreeBytes = [int64]100GB; TotalBytes = [int64]500GB }
        $global:WfStartup = @(1..10 | ForEach-Object { [PSCustomObject]@{ Name = "item$_"; Source = "x"; Enabled = $true } })
        Set-TestStub -Name "Get-WinForgeSystemDriveSpace" -Body { $global:WfSpace }
        Set-TestStub -Name "Get-WinForgeStartupItems" -Body { $global:WfStartup }
        # A revisão manual dos aplicativos de inicialização desativa 3 itens; a limpeza libera 5 GB.
        Set-TestStub -Name "Open-WinForgeShortcut" -Body {
            param ([string]$Name, [switch]$Quiet)
            if ($Name -eq "StartupApps") { $global:WfStartup = @($global:WfStartup | Select-Object -First 7) }
            $true
        }
        Set-TestStub -Name "Invoke-WinForgeQuickCleanup" -Body {
            param ([switch]$Embedded, [switch]$PassThru)
            $global:WfSpace = [PSCustomObject]@{ FreeBytes = [int64]105GB; TotalBytes = [int64]500GB }
            New-WinForgeResult -Kind Ok
        }
        try {
            Reset-LastMaintenanceMemory
            # S começar | plano: 1 (inicialização) e 7 (limpeza) | ENTER (revisão) | WINFORGE | N relatório | N reiniciar
            Set-FakeReadHost -Answers @("S", "1,7", "", "WINFORGE", "N", "N")
            $text = Get-HostText { Invoke-WinForgeRecommendedMaintenance }

            $text | Should -Match "de 100 GB para 105 GB \(\+5 GB\)"
            $text | Should -Match "de 10 para 7 \(-3\)"
        }
        finally { Clear-FakeReadHost; Clear-TestStubs }
    }
}


Describe "Reinício necessário" {
    It "decide pelo CHKDSK agendado, reinício pendente, reparo de rede ou reparo que pede reinício" {
        Use-MaintenanceStubs
        try {
            $ok = {
                param ($id, $kind, $reboot = $false)
                $r = New-WinForgeResult -Kind $kind -Data @{ RebootRequired = $reboot }
                Add-Member -InputObject $r -NotePropertyName StepId -NotePropertyValue $id -Force
                $r
            }

            Test-WinForgeMaintenanceNeedsRestart -Results @() -ChkdskScheduled $false | Should -BeFalse
            Test-WinForgeMaintenanceNeedsRestart -Results @() -ChkdskScheduled $true | Should -BeTrue

            Test-WinForgeMaintenanceNeedsRestart -Results @(& $ok "network" "Ok") -ChkdskScheduled $false | Should -BeTrue
            Test-WinForgeMaintenanceNeedsRestart -Results @(& $ok "network" "Warning") -ChkdskScheduled $false | Should -BeTrue
            Test-WinForgeMaintenanceNeedsRestart -Results @(& $ok "network" "Skipped") -ChkdskScheduled $false | Should -BeFalse
            Test-WinForgeMaintenanceNeedsRestart -Results @(& $ok "network" "Failed") -ChkdskScheduled $false | Should -BeFalse

            # O reparo avisa o reinício pelo dado estruturado, não por um texto de status.
            Test-WinForgeMaintenanceNeedsRestart -Results @(& $ok "repair" "Warning" $true) -ChkdskScheduled $false | Should -BeTrue
            Test-WinForgeMaintenanceNeedsRestart -Results @(& $ok "repair" "Warning") -ChkdskScheduled $false | Should -BeFalse
            Test-WinForgeMaintenanceNeedsRestart -Results @(& $ok "repair" "Ok") -ChkdskScheduled $false | Should -BeFalse

            Test-WinForgeMaintenanceNeedsRestart -Results @($null, (& $ok "cleanup" "Ok")) -ChkdskScheduled $false | Should -BeFalse

            $global:WfPendingReboot = $true
            Test-WinForgeMaintenanceNeedsRestart -Results @() -ChkdskScheduled $false | Should -BeTrue
        }
        finally { Clear-TestStubs }
    }
}

Describe "Etapas manuais" {
    It "abre a janela da etapa e continua com ENTER" {
        Use-MaintenanceStubs
        try {
            Set-FakeReadHost -Answers @("")
            $item = (Get-WinForgeMaintenancePlanItems | Where-Object { $_.Id -eq "startup-apps" })

            Invoke-WinForgeManualStep -Item $item -Number 1 -Total 3 | Should -BeTrue
            $global:WfLog | Should -Contain "abrir:StartupApps"
        }
        finally { Clear-FakeReadHost; Clear-TestStubs }
    }

    It "P pula as etapas restantes" {
        Use-MaintenanceStubs
        try {
            Set-FakeReadHost -Answers @("P")
            $items = @(Get-WinForgeMaintenancePlanItems | Where-Object { $_.Phase -eq "Before" })

            Invoke-WinForgeManualPhase -Items $items

            @($global:WfLog | Where-Object { $_ -like "abrir:*" }) | Should -HaveCount 1
        }
        finally { Clear-FakeReadHost; Clear-TestStubs }
    }

    It "na última etapa não existe 'pular': P é recusado e ENTER continua" {
        Use-MaintenanceStubs
        try {
            Set-FakeReadHost -Answers @("P", "")
            $item = (Get-WinForgeMaintenancePlanItems | Where-Object { $_.Id -eq "downloads" })

            Invoke-WinForgeManualStep -Item $item -Number 1 -Total 1 | Should -BeTrue
        }
        finally { Clear-FakeReadHost; Clear-TestStubs }
    }

    It "percorre todas as etapas quando o usuário só continua" {
        Use-MaintenanceStubs
        try {
            Set-FakeReadHost -Answers @("", "", "", "")
            $items = @(Get-WinForgeMaintenancePlanItems | Where-Object { $_.Phase -eq "Before" })

            Invoke-WinForgeManualPhase -Items $items

            (@($global:WfLog | Where-Object { $_ -like "abrir:*" }) -join ",") | Should -Be "abrir:StartupApps,abrir:InstalledApps,abrir:ProgramsAndFeatures,abrir:Downloads"
        }
        finally { Clear-FakeReadHost; Clear-TestStubs }
    }
}

Describe "Confirmação da fase automática" {
    It "no console exige digitar WINFORGE (sem diferenciar maiúsculas e espaços)" -ForEach @(
        @{ Typed = "WINFORGE"; Expected = $true },
        @{ Typed = "  winforge  "; Expected = $true },
        @{ Typed = "WinForge"; Expected = $true },
        @{ Typed = "sim"; Expected = $false },
        @{ Typed = ""; Expected = $false },
        @{ Typed = "WINFORG"; Expected = $false }
    ) {
        try {
            Set-FakeReadHost -Answers @($Typed)
            Confirm-WinForgeAutomaticPhase -StepCount 3 | Should -Be $Expected
        }
        finally { Clear-FakeReadHost }
    }

    It "entrada encerrada conta como não" {
        try {
            Set-FakeReadHost -Answers @()
            Confirm-WinForgeAutomaticPhase -StepCount 3 | Should -BeFalse
        }
        finally { Clear-FakeReadHost }
    }
}

Describe "Manutenção recomendada, do começo ao fim" {
    It "sem Administrador, para logo no início e não pergunta nada" {
        Use-MaintenanceStubs
        $global:WfAdmin = $false
        try {
            # A primeira resposta é consumida pelo "pressione uma tecla" do fim da ação; as outras não podem ser lidas.
            Set-FakeReadHost -Answers @("", "T", "WINFORGE")
            $text = Get-HostText { Invoke-WinForgeRecommendedMaintenance }

            $text | Should -Match "exige privilégios de Administrador"
            $global:WfFakeAnswers.Count | Should -Be 2
            @($global:WfLog | Where-Object { $_ -like "Invoke-*" }) | Should -HaveCount 0
        }
        finally { Clear-FakeReadHost; Clear-TestStubs }
    }

    It "recusar no preparo cancela sem executar nada" {
        Use-MaintenanceStubs
        try {
            Set-FakeReadHost -Answers @("N")
            $text = Get-HostText { Invoke-WinForgeRecommendedMaintenance }

            $text | Should -Match "Manutenção cancelada"
            $global:WfLog | Should -HaveCount 0
        }
        finally { Clear-FakeReadHost; Clear-TestStubs }
    }

    It "na bateria, pergunta antes de continuar e recusar cancela sem executar nada" {
        Use-MaintenanceStubs
        $global:WfOnBattery = $true
        try {
            Set-FakeReadHost -Answers @("N")
            $text = Get-HostText { Invoke-WinForgeRecommendedMaintenance }

            $text | Should -Match "usando a bateria"
            $text | Should -Match "Manutenção cancelada"
            $global:WfLog | Should -HaveCount 0
        }
        finally { Clear-FakeReadHost; Clear-TestStubs }
    }

    It "na bateria, aceitar segue para o preparo normal (e a pergunta de começar vem depois)" {
        Use-MaintenanceStubs
        $global:WfOnBattery = $true
        try {
            # S = continuar na bateria | N = não começar
            Set-FakeReadHost -Answers @("S", "N")
            $text = Get-HostText { Invoke-WinForgeRecommendedMaintenance }

            $text | Should -Match "usando a bateria"
            $text | Should -Match "Manutenção cancelada"
            $global:WfFakeAnswers.Count | Should -Be 0
        }
        finally { Clear-FakeReadHost; Clear-TestStubs }
    }

    It "avisa quando o disco do Windows está apertado, sem barrar a manutenção" {
        Use-MaintenanceStubs
        $global:WfFreeBytes = [int64]2GB
        try {
            Set-FakeReadHost -Answers @("N")
            $text = Get-HostText { Invoke-WinForgeRecommendedMaintenance }

            $text | Should -Match "pouco espaço livre \(2 GB\)"
            $global:WfFakeAnswers.Count | Should -Be 0
        }
        finally { Clear-FakeReadHost; Clear-TestStubs }
    }

    It "não avisa de espaço quando há folga, nem quando o espaço é desconhecido" {
        Use-MaintenanceStubs

        foreach ($free in @([int64]50GB, [int64]-1)) {
            $global:WfFreeBytes = $free
            try {
                Set-FakeReadHost -Answers @("N")
                $text = Get-HostText { Invoke-WinForgeRecommendedMaintenance }
                $text | Should -Not -Match "pouco espaço livre"
            }
            finally { Clear-FakeReadHost }
        }

        Clear-TestStubs
    }

    It "cancelar a lista ou não marcar nada cancela a manutenção" {
        Use-MaintenanceStubs
        try {
            Set-FakeReadHost -Answers @("S", "")
            $text = Get-HostText { Invoke-WinForgeRecommendedMaintenance }

            $text | Should -Match "Manutenção cancelada"
            $global:WfLog | Should -HaveCount 0
        }
        finally { Clear-FakeReadHost; Clear-TestStubs }
    }

    It "não digitar WINFORGE cancela antes de qualquer alteração" {
        Use-MaintenanceStubs
        try {
            Set-FakeReadHost -Answers @("S", "5,7", "nao")
            $text = Get-HostText { Invoke-WinForgeRecommendedMaintenance }

            $text | Should -Match "Manutenção cancelada"
            @($global:WfLog | Where-Object { $_ -like "Invoke-*" -or $_ -like "awake:*" }) | Should -HaveCount 0
        }
        finally { Clear-FakeReadHost; Clear-TestStubs }
    }

    It "executa só o que foi marcado e informa que não precisa reiniciar" {
        Use-MaintenanceStubs
        try {
            # S = começar; 5,7 = ponto de restauração e limpeza; WINFORGE; N = não salvar relatório
            Set-FakeReadHost -Answers @("S", "5,7", "WINFORGE", "N")
            $text = Get-HostText { Invoke-WinForgeRecommendedMaintenance }

            (@($global:WfLog | Where-Object { $_ -like "Invoke-*" }) -join ",") | Should -Be "Invoke-WinForgeRestorePoint,Invoke-WinForgeQuickCleanup"
            $text | Should -Match "Nenhuma reinicialização é necessária"
            $text | Should -Match "Manutenção recomendada finalizada"
        }
        finally { Clear-FakeReadHost; Clear-TestStubs }
    }

    It "o plano completo roda na ordem certa e nunca executa shutdown sem confirmação" {
        Use-MaintenanceStubs
        try {
            # S começar | T tudo | 4x ENTER (revisão antes) | WINFORGE | 4x ENTER (revisão depois)
            # N relatório | N reiniciar | N reiniciar o Explorador
            Set-FakeReadHost -Answers @("S", "T", "", "", "", "", "WINFORGE", "", "", "", "", "N", "N", "N")
            $text = Get-HostText { Invoke-WinForgeRecommendedMaintenance }

            $expected = @(
                "abrir:StartupApps", "abrir:InstalledApps", "abrir:ProgramsAndFeatures", "abrir:Downloads",
                "select-tweaks", "winget-plan",
                "awake:True",
                "Invoke-WinForgeRestorePoint", "Invoke-WinForgeNetworkRepair", "Invoke-WinForgeQuickCleanup",
                "Invoke-WinForgeDismAndSfc", "Start-WinForgeChkdsk", "winget:All", "Invoke-WinForgeDeviceScan",
                "Invoke-WinForgeSecurityCheck", "Start-WinForgeDriveOptimization", "tweaks:file-extensions",
                "awake:False",
                "abrir:Storage", "abrir:WindowsUpdate", "abrir:OptionalUpdates", "abrir:MicrosoftStore"
            )

            ($global:WfLog -join "|") | Should -Be ($expected -join "|")
            $global:WfLog | Should -Not -Contain "nativo:shutdown.exe"
            $text | Should -Match "Reinicialização não iniciada"
            $global:WfLog | Should -Not -Contain "explorer-reiniciado"
        }
        finally { Clear-FakeReadHost; Clear-TestStubs }
    }

    It "oferece reiniciar o Explorador depois dos ajustes e reinicia só com 'sim'" {
        Use-MaintenanceStubs
        try {
            # Apenas ajustes (item 14 do plano) | S começar | WINFORGE | N relatório | S Explorador
            Set-FakeReadHost -Answers @("S", "14", "WINFORGE", "N", "S")
            [void](Get-HostText { Invoke-WinForgeRecommendedMaintenance })

            $global:WfLog | Should -Contain "explorer-reiniciado"
        }
        finally { Clear-FakeReadHost; Clear-TestStubs }
    }

    It "mesmo com uma etapa falhando, termina, mostra o resumo e guarda o histórico" {
        Use-MaintenanceStubs
        Set-TestStub -Name "Invoke-WinForgeQuickCleanup" -Body { throw "falha simulada" }
        try {
            Reset-LastMaintenanceMemory
            Set-FakeReadHost -Answers @("S", "5,7", "WINFORGE", "N")
            $text = Get-HostText { Invoke-WinForgeRecommendedMaintenance }

            $text | Should -Match "falha simulada"
            $text | Should -Match "1 etapa\(s\) falharam"
            $text | Should -Match "Manutenção recomendada finalizada"
            (@((Get-WinForgeLastMaintenance).Results | ForEach-Object { $_.Kind }) -join ",") | Should -Be "Ok,Failed"
        }
        finally { Clear-FakeReadHost; Clear-TestStubs }
    }
}
