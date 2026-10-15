# Reparo: interpretação das saídas do DISM, SFC e CHKDSK e o fluxo de cada ferramenta.
# As ferramentas do Windows são funções de teste (dism.exe, sfc.exe...) e a captura de saída é simulada.

BeforeAll {
    . (Join-Path $PSScriptRoot "TestSetup.ps1")

    function script:Use-RepairStubs {
        # $global:WfOutput: texto/código que cada comando "devolve", por linha de comando.
        $global:WfLog = New-Object System.Collections.ArrayList
        $global:WfAdmin = $true
        $global:WfOutput = @{}
        $script:OriginalSystemDrive = $env:SystemDrive
        $env:SystemDrive = "C:"

        foreach ($tool in "dism.exe", "sfc.exe", "chkdsk.exe", "defrag.exe", "pnputil.exe", "fsutil.exe", "chkntfs.exe") {
            Set-TestStub -Name $tool -Body {}
        }

        Set-TestStub -Name "Test-WinForgeAdministrator" -Body { [bool]$global:WfAdmin }
        Set-TestStub -Name "Invoke-WinForgeCapture" -Body {
            param ([string]$FilePath, [string[]]$Arguments, [switch]$Echo)
            $line = ($FilePath + " " + ($Arguments -join " ")).Trim()
            [void]$global:WfLog.Add($line)

            $reply = $global:WfOutput[$line]

            if ($null -eq $reply) { $reply = @{ ExitCode = 0; Text = "" } }
            if ($reply -is [scriptblock]) { & $reply }

            [PSCustomObject]@{ ExitCode = [int]$reply.ExitCode; Text = [string]$reply.Text; Lines = @() }
        }
    }

    function script:Clear-RepairStubs {
        $env:SystemDrive = $script:OriginalSystemDrive
        Clear-TestStubs
    }

    function script:Get-Calls {
        # Só as chamadas de ferramenta (sem barras de progresso e afins).
        @($global:WfLog | ForEach-Object { $_ })
    }
}

AfterAll {
    Remove-Variable WfLog, WfAdmin, WfOutput -Scope Global -ErrorAction SilentlyContinue
    Remove-WinForgeTestData
}

Describe "DISM: precisa reparar?" {
    It "não repara quando nenhum dano foi detectado (inglês e português)" -ForEach @(
        @{ Text = "No component store corruption detected." },
        @{ Text = "Nenhuma corrupção do repositório de componentes foi detectada." },
        @{ Text = "nenhuma corrupção de repositório de componentes detectada" }
    ) {
        Test-WinForgeDismRepairNeeded -ExitCode 0 -OutputText $Text | Should -BeFalse
    }

    It "repara quando o repositório é reparável ou está corrompido" -ForEach @(
        @{ Text = "The component store is repairable." },
        @{ Text = "O repositório de componentes é reparável." },
        @{ Text = "The component store is corrupted" },
        @{ Text = "O repositório de componentes está corrompido." }
    ) {
        Test-WinForgeDismRepairNeeded -ExitCode 0 -OutputText $Text | Should -BeTrue
    }

    It "sem texto reconhecido, decide pelo código de saída" {
        Test-WinForgeDismRepairNeeded -ExitCode 5 -OutputText "" | Should -BeTrue
        Test-WinForgeDismRepairNeeded -ExitCode 0 -OutputText "" | Should -BeFalse
        Test-WinForgeDismRepairNeeded -ExitCode 0 -OutputText "algum texto em outro idioma" | Should -BeFalse
    }
}

Describe "SFC: resultado" {
    It "<Name>" -ForEach @(
        @{ Name = "sem violações: Ok"; Code = 0; Text = "Windows Resource Protection did not find any integrity violations."; Kind = "Ok" },
        @{ Name = "reparou com êxito: Ok com detalhe"; Code = 0; Text = "Windows Resource Protection found corrupt files and successfully repaired them."; Kind = "Ok" },
        @{ Name = "reparou com êxito em português"; Code = 0; Text = "A Proteção de Recursos do Windows encontrou arquivos corrompidos e os reparou com êxito."; Kind = "Ok" },
        @{ Name = "não conseguiu corrigir: ressalva (mesmo com código 0)"; Code = 0; Text = "Windows Resource Protection found corrupt files but was unable to fix some of them."; Kind = "Warning" },
        @{ Name = "não conseguiu corrigir em português"; Code = 0; Text = "A Proteção de Recursos do Windows encontrou arquivos corrompidos, mas não pôde corrigir alguns deles."; Kind = "Warning" },
        @{ Name = "reparo pendente: ressalva"; Code = 0; Text = "There is a system repair pending which requires reboot to complete."; Kind = "Warning" },
        @{ Name = "código diferente de zero sem texto: falha"; Code = 5; Text = ""; Kind = "Failed" }
    ) {
        (Get-WinForgeSfcResult -ExitCode $Code -OutputText $Text).Kind | Should -Be $Kind
    }

    It "o reparo pendente pede reinício no texto do resultado (a Manutenção lê isso)" {
        (Get-WinForgeSfcResult -ExitCode 0 -OutputText "There is a system repair pending").Status | Should -Match "reinicie"
    }
}

Describe "Código de saída padrão" {
    It "0 é Ok, 3010 é ressalva com pedido de reinício, outros são falha" {
        (Get-WinForgeExitCodeResult -ExitCode 0).Kind | Should -Be "Ok"
        (Get-WinForgeExitCodeResult -ExitCode 3010).Kind | Should -Be "Warning"
        (Get-WinForgeExitCodeResult -ExitCode 3010).Status | Should -Match "reinicie"
        (Get-WinForgeExitCodeResult -ExitCode 1).Kind | Should -Be "Failed"
        (Get-WinForgeExitCodeResult -ExitCode -2146498529).Kind | Should -Be "Failed"
    }
}

Describe "Pedido de reinício nos dados do resultado" {
    It "<Name>" -ForEach @(
        @{ Name = "SFC com reparo pendente pede reinício"; Result = { Get-WinForgeSfcResult -ExitCode 0 -OutputText "There is a system repair pending" }; Expected = $true },
        @{ Name = "SFC que não conseguiu corrigir não pede reinício (reiniciar não resolve)"; Result = { Get-WinForgeSfcResult -ExitCode 0 -OutputText "unable to fix some of them" }; Expected = $false },
        @{ Name = "SFC sem violações não pede"; Result = { Get-WinForgeSfcResult -ExitCode 0 -OutputText "did not find any integrity violations" }; Expected = $false },
        @{ Name = "código 3010 pede reinício"; Result = { Get-WinForgeExitCodeResult -ExitCode 3010 }; Expected = $true },
        @{ Name = "código 0 não pede"; Result = { Get-WinForgeExitCodeResult -ExitCode 0 }; Expected = $false },
        @{ Name = "falha comum não pede"; Result = { Get-WinForgeExitCodeResult -ExitCode 5 }; Expected = $false }
    ) {
        Test-WinForgeResultFlag -Result (& $Result) -Name "RebootRequired" | Should -Be $Expected
    }
}

Describe "CHKDSK: reparo offline necessário?" {
    It "códigos 0, 1 e 2 sem texto de reparo não exigem reparo offline" -ForEach @(@{ Code = 0 }, @{ Code = 1 }, @{ Code = 2 }) {
        Test-WinForgeChkdskRepairRequired -ExitCode $Code -OutputText "" | Should -BeFalse
    }

    It "código 3 ou maior exige reparo" -ForEach @(@{ Code = 3 }, @{ Code = 8 }) {
        Test-WinForgeChkdskRepairRequired -ExitCode $Code -OutputText "" | Should -BeTrue
    }

    It "textos de reparo offline exigem reparo mesmo com código baixo" -ForEach @(
        @{ Text = "Run spotfix offline repair" },
        @{ Text = "Offline repair is required." },
        @{ Text = "Será necessário o reparo offline" },
        @{ Text = "A verificação ocorrerá na próxima reinicialização." },
        @{ Text = "ocorrera na proxima reinicializacao" }
    ) {
        Test-WinForgeChkdskRepairRequired -ExitCode 0 -OutputText $Text | Should -BeTrue
    }
}

Describe "Executor de ferramentas" {
    It "sem Administrador não executa nada e informa o motivo" {
        Use-RepairStubs
        $global:WfAdmin = $false
        try {
            $result = Invoke-WinForgeTool -Title "Teste" -FilePath "dism.exe" -Arguments @("/x") -Embedded -PassThru

            $result.Kind | Should -Be "Failed"
            $result.Status | Should -Match "Administrador"
            $result.Etapa | Should -Be "Teste"
            Get-Calls | Should -HaveCount 0
        }
        finally { Clear-RepairStubs }
    }

    It "comando inexistente vira falha com mensagem clara" {
        Use-RepairStubs
        try {
            $result = Invoke-WinForgeTool -Title "Teste" -FilePath "ferramenta-que-nao-existe.exe" -Embedded -PassThru

            $result.Kind | Should -Be "Failed"
            $result.Status | Should -Match "não encontrado"
        }
        finally { Clear-RepairStubs }
    }

    It "interpreta o código de saída com o analisador informado e o padrão" {
        Use-RepairStubs
        try {
            $global:WfOutput["dism.exe /x"] = @{ ExitCode = 3010; Text = "" }
            (Invoke-WinForgeTool -Title "A" -FilePath "dism.exe" -Arguments @("/x") -Embedded -PassThru).Kind | Should -Be "Warning"

            $global:WfOutput["dism.exe /x"] = @{ ExitCode = 7; Text = "" }
            (Invoke-WinForgeTool -Title "A" -FilePath "dism.exe" -Arguments @("/x") -Embedded -PassThru).Kind | Should -Be "Failed"

            $parser = { param ($code, $text) New-WinForgeResult -Kind Warning -Detail "analisador próprio: $code" }
            $custom = Invoke-WinForgeTool -Title "A" -FilePath "dism.exe" -Arguments @("/x") -ResultParser $parser -Embedded -PassThru
            $custom.Status | Should -Match "analisador próprio: 7"
        }
        finally { Clear-RepairStubs }
    }

    It "uma exceção na execução vira falha, não derruba o chamador" {
        Use-RepairStubs
        Set-TestStub -Name "Invoke-WinForgeCapture" -Body { throw "processo não iniciou" }
        try {
            $result = Invoke-WinForgeTool -Title "A" -FilePath "dism.exe" -Embedded -PassThru

            $result.Kind | Should -Be "Failed"
            $result.Status | Should -Match "processo não iniciou"
        }
        finally { Clear-RepairStubs }
    }

    It "fora da Manutenção pergunta antes, e recusar não executa" {
        Use-RepairStubs
        try {
            Set-FakeReadHost -Answers @("N", "")
            $result = Invoke-WinForgeTool -Title "A" -FilePath "dism.exe" -Arguments @("/x") -PassThru

            $result.Kind | Should -Be "Skipped"
            Get-Calls | Should -HaveCount 0
        }
        finally { Clear-FakeReadHost; Clear-RepairStubs }
    }

    It "sem -PassThru não devolve nada ao pipeline" {
        Use-RepairStubs
        try {
            $output = @(Invoke-WinForgeTool -Title "A" -FilePath "dism.exe" -Arguments @("/x") -Embedded)
            $output | Should -HaveCount 0
        }
        finally { Clear-RepairStubs }
    }
}

Describe "DISM + SFC" {
    It "com verificação prévia e sem dano, pula o RestoreHealth e roda o SFC" {
        Use-RepairStubs
        $global:WfOutput["dism.exe /Online /Cleanup-Image /CheckHealth"] = @{ ExitCode = 0; Text = "No component store corruption detected." }
        $global:WfOutput["sfc.exe /scannow"] = @{ ExitCode = 0; Text = "Windows Resource Protection did not find any integrity violations." }
        try {
            $result = Invoke-WinForgeDismAndSfc -CheckFirst -Embedded -PassThru

            ((Get-Calls) -join "|") | Should -Be "dism.exe /Online /Cleanup-Image /CheckHealth|sfc.exe /scannow"
            $result.Kind | Should -Be "Ok"
            $result.Etapa | Should -Match "DISM \+ SFC"
        }
        finally { Clear-RepairStubs }
    }

    It "com dano marcado, roda o RestoreHealth antes do SFC" {
        Use-RepairStubs
        $global:WfOutput["dism.exe /Online /Cleanup-Image /CheckHealth"] = @{ ExitCode = 0; Text = "The component store is repairable." }
        try {
            $result = Invoke-WinForgeDismAndSfc -CheckFirst -Embedded -PassThru

            ((Get-Calls) -join "|") | Should -Be "dism.exe /Online /Cleanup-Image /CheckHealth|dism.exe /Online /Cleanup-Image /RestoreHealth|sfc.exe /scannow"
            $result.Kind | Should -Be "Ok"
        }
        finally { Clear-RepairStubs }
    }

    It "sem verificação prévia, sempre repara a imagem" {
        Use-RepairStubs
        try {
            [void](Invoke-WinForgeDismAndSfc -Embedded -PassThru)
            ((Get-Calls) -join "|") | Should -Be "dism.exe /Online /Cleanup-Image /RestoreHealth|sfc.exe /scannow"
        }
        finally { Clear-RepairStubs }
    }

    It "se o DISM falha, o SFC roda mesmo assim e o resultado é falha" {
        Use-RepairStubs
        $global:WfOutput["dism.exe /Online /Cleanup-Image /RestoreHealth"] = @{ ExitCode = 5; Text = "" }
        try {
            $result = Invoke-WinForgeDismAndSfc -Embedded -PassThru

            Get-Calls | Should -Contain "sfc.exe /scannow"
            $result.Kind | Should -Be "Failed"
        }
        finally { Clear-RepairStubs }
    }

    It "SFC que não consegue corrigir deixa uma ressalva (e não sucesso)" {
        Use-RepairStubs
        $global:WfOutput["sfc.exe /scannow"] = @{ ExitCode = 0; Text = "Windows Resource Protection found corrupt files but was unable to fix some of them." }
        try {
            (Invoke-WinForgeDismAndSfc -Embedded -PassThru).Kind | Should -Be "Warning"
        }
        finally { Clear-RepairStubs }
    }

    It "o pedido de reinício de uma das ferramentas vale para o reparo inteiro" -ForEach @(
        @{ Name = "DISM com 3010"; Key = "dism.exe /Online /Cleanup-Image /RestoreHealth"; Reply = @{ ExitCode = 3010; Text = "" }; Expected = $true },
        @{ Name = "SFC com reparo pendente"; Key = "sfc.exe /scannow"; Reply = @{ ExitCode = 0; Text = "There is a system repair pending which requires reboot" }; Expected = $true },
        @{ Name = "tudo certo"; Key = "sfc.exe /scannow"; Reply = @{ ExitCode = 0; Text = "did not find any integrity violations" }; Expected = $false },
        @{ Name = "SFC que não corrige (reiniciar não ajuda)"; Key = "sfc.exe /scannow"; Reply = @{ ExitCode = 0; Text = "unable to fix" }; Expected = $false }
    ) {
        Use-RepairStubs
        $global:WfOutput[$Key] = $Reply
        try {
            $result = Invoke-WinForgeDismAndSfc -Embedded -PassThru

            Test-WinForgeResultFlag -Result $result -Name "RebootRequired" | Should -Be $Expected
        }
        finally { Clear-RepairStubs }
    }

    It "o resumo lista o DISM e o SFC com os nomes das telas" {
        Use-RepairStubs
        try {
            $text = Get-HostText { [void](Invoke-WinForgeDismAndSfc -Embedded -PassThru) }

            $text | Should -Match "Resumo do reparo"
            $text | Should -Match ([regex]::Escape((Get-WinForgeNavItem -Id "repair.dism").Label))
            $text | Should -Match ([regex]::Escape((Get-WinForgeNavItem -Id "repair.sfc").Label))
        }
        finally { Clear-RepairStubs }
    }

    It "sem Administrador não executa nada" {
        Use-RepairStubs
        $global:WfAdmin = $false
        try {
            $result = Invoke-WinForgeDismAndSfc -Embedded -PassThru

            $result.Kind | Should -Be "Failed"
            Get-Calls | Should -HaveCount 0
        }
        finally { Clear-RepairStubs }
    }

    It "recusar a pergunta (fora da Manutenção) não executa nada" {
        Use-RepairStubs
        try {
            Set-FakeReadHost -Answers @("n", "")
            $result = Invoke-WinForgeDismAndSfc -PassThru

            $result.Kind | Should -Be "Skipped"
            Get-Calls | Should -HaveCount 0
        }
        finally { Clear-FakeReadHost; Clear-RepairStubs }
    }
}

Describe "CHKDSK" {
    It "verificação limpa: usa /scan, que não exige reiniciar" {
        Use-RepairStubs
        try {
            $result = Start-WinForgeChkdsk -Embedded -PassThru

            ((Get-Calls) -join "|") | Should -Be "chkdsk.exe C: /scan"
            $result.Kind | Should -Be "Ok"
            Test-WinForgeChkdskRepairPending | Should -BeFalse
        }
        finally { Clear-RepairStubs }
    }

    It "código 2 vira ressalva; código 1 (corrigiu erros) continua Ok" {
        Use-RepairStubs
        try {
            $global:WfOutput["chkdsk.exe C: /scan"] = @{ ExitCode = 2; Text = "" }
            (Start-WinForgeChkdsk -Embedded -PassThru).Kind | Should -Be "Warning"

            $global:WfOutput["chkdsk.exe C: /scan"] = @{ ExitCode = 1; Text = "" }
            (Start-WinForgeChkdsk -Embedded -PassThru).Kind | Should -Be "Ok"
        }
        finally { Clear-RepairStubs }
    }

    It "reparo offline necessário na Manutenção: só marca como pendente, sem agendar nem perguntar" {
        Use-RepairStubs
        $global:WfOutput["chkdsk.exe C: /scan"] = @{ ExitCode = 3; Text = "Please run chkdsk /spotfix" }
        try {
            $result = Start-WinForgeChkdsk -DeferRepairPrompt -Embedded -PassThru

            $result.Kind | Should -Be "Warning"
            Test-WinForgeChkdskRepairPending | Should -BeTrue
            Get-Calls | Should -HaveCount 1
        }
        finally { Clear-RepairStubs }
    }

    It "uma nova verificação limpa zera o pendente da anterior" {
        Use-RepairStubs
        try {
            $global:WfOutput["chkdsk.exe C: /scan"] = @{ ExitCode = 3; Text = "" }
            [void](Start-WinForgeChkdsk -DeferRepairPrompt -Embedded -PassThru)
            Test-WinForgeChkdskRepairPending | Should -BeTrue

            $global:WfOutput["chkdsk.exe C: /scan"] = @{ ExitCode = 0; Text = "" }
            [void](Start-WinForgeChkdsk -Embedded -PassThru)
            Test-WinForgeChkdskRepairPending | Should -BeFalse
        }
        finally { Clear-RepairStubs }
    }

    It "fora da Manutenção, agenda o reparo apenas se o usuário confirmar" {
        Use-RepairStubs
        $global:WfOutput["chkdsk.exe C: /scan"] = @{ ExitCode = 3; Text = "" }
        try {
            # S = iniciar verificação | N = não agendar | ENTER = pressionar uma tecla
            Set-FakeReadHost -Answers @("S", "N", "")
            $declined = Start-WinForgeChkdsk -PassThru

            $declined.Kind | Should -Be "Warning"
            $declined.Status | Should -Match "não agendado"
            Get-Calls | Should -Not -Contain "fsutil.exe dirty set C:"

            $global:WfLog.Clear()

            # S = iniciar | S = agendar | ENTER
            Set-FakeReadHost -Answers @("S", "S", "")
            $accepted = Start-WinForgeChkdsk -PassThru

            $accepted.Status | Should -Match "agendado"
            ((Get-Calls) -join "|") | Should -Be "chkdsk.exe C: /scan|fsutil.exe dirty set C:|chkntfs.exe /C C:"
        }
        finally { Clear-FakeReadHost; Clear-RepairStubs }
    }

    It "só o reparo realmente agendado pede reinício nos dados do resultado" {
        Use-RepairStubs
        $global:WfOutput["chkdsk.exe C: /scan"] = @{ ExitCode = 3; Text = "" }
        try {
            Set-FakeReadHost -Answers @("S", "S", "")
            $scheduled = Start-WinForgeChkdsk -PassThru
            Test-WinForgeResultFlag -Result $scheduled -Name "RebootRequired" | Should -BeTrue

            Set-FakeReadHost -Answers @("S", "N", "")
            $declined = Start-WinForgeChkdsk -PassThru
            Test-WinForgeResultFlag -Result $declined -Name "RebootRequired" | Should -BeFalse

            $deferred = Start-WinForgeChkdsk -DeferRepairPrompt -Embedded -PassThru
            Test-WinForgeResultFlag -Result $deferred -Name "RebootRequired" | Should -BeFalse
        }
        finally { Clear-FakeReadHost; Clear-RepairStubs }
    }

    It "se o agendamento falha, o resultado é falha e o reparo não fica marcado como agendado" {
        Use-RepairStubs
        $global:WfOutput["chkdsk.exe C: /scan"] = @{ ExitCode = 3; Text = "" }
        $global:WfOutput["fsutil.exe dirty set C:"] = @{ ExitCode = 1; Text = "" }
        try {
            Set-FakeReadHost -Answers @("S", "S", "")
            $result = Start-WinForgeChkdsk -PassThru

            $result.Kind | Should -Be "Failed"
            Get-Calls | Should -Not -Contain "chkntfs.exe /C C:"
        }
        finally { Clear-FakeReadHost; Clear-RepairStubs }
    }

    It "sem Administrador não executa" {
        Use-RepairStubs
        $global:WfAdmin = $false
        try {
            (Start-WinForgeChkdsk -Embedded -PassThru).Kind | Should -Be "Failed"
            Get-Calls | Should -HaveCount 0
        }
        finally { Clear-RepairStubs }
    }
}

Describe "Nomes das ferramentas" {
    It "o resultado de cada ação da página de Reparo leva o mesmo nome do botão" {
        Use-RepairStubs
        try {
            foreach ($item in @((Get-WinForgeNavPage -Id "repair").Items)) {
                $result = & $item.Command -Embedded -PassThru

                $result.Etapa | Should -Be $item.Label
            }
        }
        finally { Clear-RepairStubs }
    }

    It "o resultado da Limpeza de componentes (DISM) leva o nome do botão" {
        Use-RepairStubs
        try {
            $item = Get-WinForgeNavItem -Id "cleanup.components"

            (& $item.Command -Embedded -PassThru).Etapa | Should -Be $item.Label
        }
        finally { Clear-RepairStubs }
    }
}

Describe "Telas de uma ferramenta" {
    It "mostra o que vai rodar, o comando exato, e só então pergunta (ENTER executa)" {
        Use-RepairStubs
        try {
            Set-FakeReadHost -Answers @("", "")
            $text = Get-HostText { [void](Invoke-WinForgeSfc -PassThru) }

            $text | Should -Match "Verifica os arquivos protegidos"
            $text | Should -Match "sfc.exe /scannow"
            $text | Should -Match "concluído com sucesso"
            (Get-Calls) | Should -Contain "sfc.exe /scannow"
        }
        finally { Clear-FakeReadHost; Clear-RepairStubs }
    }

    It "recusar a pergunta cancela sem rodar a ferramenta" {
        Use-RepairStubs
        try {
            Set-FakeReadHost -Answers @("n", "")
            $text = Get-HostText { [void](Invoke-WinForgeDism -PassThru) }

            $text | Should -Match "Operação cancelada"
            Get-Calls | Should -HaveCount 0
        }
        finally { Clear-FakeReadHost; Clear-RepairStubs }
    }

    It "dentro da janela o título da ferramenta não se repete na saída" {
        Use-RepairStubs
        $global:WinForgeGuiMode = $true
        try {
            Set-FakeReadHost -Answers @("", "")
            $text = Get-HostText { [void](Invoke-WinForgeSfc -PassThru) }

            # A saída começa direto pela descrição; o título já está no topo da janela.
            $text.TrimStart() | Should -Match "^Verifica os arquivos protegidos"
            $text | Should -Match "sfc.exe /scannow"
        }
        finally {
            Remove-Variable WinForgeGuiMode -Scope Global -ErrorAction SilentlyContinue
            Clear-FakeReadHost
            Clear-RepairStubs
        }
    }

    It "uma ferramenta que termina com ressalva mostra o motivo na mensagem final" {
        Use-RepairStubs
        $global:WfOutput["sfc.exe /scannow"] = @{ ExitCode = 0; Text = "found corrupt files but was unable to fix some of them" }
        try {
            $text = Get-HostText { [void](Invoke-WinForgeSfc -Embedded -PassThru) }

            $text | Should -Match "concluído com ressalvas: há arquivos corrompidos que não foram reparados"
        }
        finally { Clear-RepairStubs }
    }

    It "uma falha mostra o código de saída" {
        Use-RepairStubs
        $global:WfOutput["dism.exe /Online /Cleanup-Image /RestoreHealth"] = @{ ExitCode = 87; Text = "" }
        try {
            $text = Get-HostText { [void](Invoke-WinForgeDism -Embedded -PassThru) }

            $text | Should -Match "não foi concluído: código de saída 87"
        }
        finally { Clear-RepairStubs }
    }
}

Describe "Otimização e detecção de dispositivos" {
    It "a otimização usa /O (o Windows escolhe TRIM ou desfragmentação) na unidade do sistema" {
        Use-RepairStubs
        try {
            $result = Start-WinForgeDriveOptimization -Embedded -PassThru

            ((Get-Calls) -join "|") | Should -Be "defrag.exe C: /O /U /V"
            $result.Kind | Should -Be "Ok"
        }
        finally { Clear-RepairStubs }
    }

    It "a detecção de dispositivos pede um novo escaneamento ao Windows" {
        Use-RepairStubs
        try {
            [void](Invoke-WinForgeDeviceScan -Embedded -PassThru)
            ((Get-Calls) -join "|") | Should -Be "pnputil.exe /scan-devices"
        }
        finally { Clear-RepairStubs }
    }
}
