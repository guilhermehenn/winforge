# Ponte entre as ações e a janela: limpeza do texto, linhas de progresso, planos de pergunta e execução de ações
# num runspace com o host gráfico (a janela em si não é testável fora do Windows).

BeforeAll {
    . (Join-Path $PSScriptRoot "TestSetup.ps1")
}

AfterAll {
    Remove-WinForgeTestData
}

Describe "Texto da janela" {
    It "remove caracteres de controle, NUL e sequências ANSI" {
        $raw = "S" + [char]0 + "F" + [char]0 + [char]27 + "[31mok" + [char]27 + "[0m"
        [WinForge.GuiHostUI]::Sanitize($raw) | Should -Be "SFok"
    }

    It "converte retorno de carro isolado em quebra de linha e CRLF em LF" {
        [WinForge.GuiHostUI]::Sanitize("10%`r20%") | Should -Be "10%`n20%"
        [WinForge.GuiHostUI]::Sanitize("linha`r`n") | Should -Be "linha`n"
        [WinForge.GuiHostUI]::Sanitize("`r`r") | Should -Be "`n`n"
    }

    It "preserva tabulação, acentos e emoji" {
        [WinForge.GuiHostUI]::Sanitize("a`tb ação é ñ 😀") | Should -Be "a`tb ação é ñ 😀"
    }

    It "remove BEL e backspace" {
        [WinForge.GuiHostUI]::Sanitize("a" + [char]7 + "b" + [char]8 + "c") | Should -Be "abc"
    }

    It "sequências incompletas não travam nem consomem o texto seguinte indevidamente" {
        [WinForge.GuiHostUI]::Sanitize([char]27 + "[31") | Should -Be ""
        [WinForge.GuiHostUI]::Sanitize("fim" + [char]27) | Should -Be "fim"
        [WinForge.GuiHostUI]::Sanitize([char]27 + "x") | Should -Be "x"
    }

    It "remove sequências de título da janela (OSC), terminadas em BEL ou em ESC barra" {
        [WinForge.GuiHostUI]::Sanitize("a" + [char]27 + "]0;Título" + [char]7 + "b") | Should -Be "ab"
        [WinForge.GuiHostUI]::Sanitize("a" + [char]27 + "]8;;http://x" + [char]27 + "\link" + [char]27 + "]8;;" + [char]27 + "\") | Should -Be "alink"
        [WinForge.GuiHostUI]::Sanitize([char]27 + "]0;sem fim") | Should -Be ""
    }

    It "texto nulo ou vazio dá vazio" {
        [WinForge.GuiHostUI]::Sanitize($null) | Should -Be ""
        [WinForge.GuiHostUI]::Sanitize("") | Should -Be ""
    }
}

Describe "Linhas de progresso" {
    It "reconhece linhas de progresso de DISM, winget e SFC" -ForEach @(
        @{ Text = "[==========================100.0%==========================]" },
        @{ Text = "[=                          2.0%                           ]" },
        @{ Text = "  45%" },
        @{ Text = "99,5%" },
        @{ Text = "Verification 45% complete." },
        @{ Text = "Verificação 12% concluída." },
        @{ Text = "  ██████████░░░░░░░░░░  50%" }
    ) {
        Test-WinForgeProgressLine -Text $Text | Should -BeTrue
    }

    It "não confunde linhas comuns com progresso" -ForEach @(
        @{ Text = "Uso do disco: livre" },
        @{ Text = "" },
        @{ Text = "   " },
        @{ Text = $null },
        @{ Text = "Concluído com sucesso." },
        @{ Text = "Espaço liberado: 45% do total em uso" },
        @{ Text = "100 itens" }
    ) {
        Test-WinForgeProgressLine -Text $Text | Should -BeFalse
    }

    It "reconhece setas giratórias" -ForEach @(@{ Text = "  \ " }, @{ Text = "-" }, @{ Text = "|" }, @{ Text = "/" }) {
        Test-WinForgeSpinnerLine -Text $Text | Should -BeTrue
    }

    It "texto comum não é seta giratória" -ForEach @(@{ Text = "texto" }, @{ Text = "--" }, @{ Text = "" }) {
        Test-WinForgeSpinnerLine -Text $Text | Should -BeFalse
    }
}

Describe "Plano das perguntas" {
    It "mostra Sim/Não para perguntas (S/N)" {
        $prompt = [PSCustomObject]@{ Kind = "line"; Label = "Deseja continuar? (S/N)"; Options = $null; DefaultKey = "" }
        $plan = Get-WinForgePromptPlan -Prompt $prompt

        $plan.ShowText | Should -BeFalse
        (($plan.Buttons | ForEach-Object Answer) -join ",") | Should -Be "S,N"
    }

    It "oferece Continuar e Pular nas etapas manuais" {
        $label = "Conclua o que desejar na janela aberta e pressione ENTER (P = pular as etapas manuais restantes)"
        $plan = Get-WinForgePromptPlan -Prompt ([PSCustomObject]@{ Kind = "line"; Label = $label; Options = $null; DefaultKey = "" })

        $plan.ShowText | Should -BeTrue
        (($plan.Buttons | ForEach-Object Answer) -join ",") | Should -Be ",P"
    }

    It "usa caixa de texto simples para perguntas abertas" {
        $plan = Get-WinForgePromptPlan -Prompt ([PSCustomObject]@{ Kind = "line"; Label = "Digite o ID do pacote"; Options = $null; DefaultKey = "" })

        $plan.ShowText | Should -BeTrue
        $plan.Buttons.Count | Should -Be 0
    }

    It "pedido de tecla vira um botão Continuar" {
        $plan = Get-WinForgePromptPlan -Prompt ([PSCustomObject]@{ Kind = "key"; Label = "Pressione"; Options = $null; DefaultKey = "" })

        $plan.Buttons | Should -HaveCount 1
        $plan.Buttons[0].Text | Should -Be "Continuar"
        $plan.ShowText | Should -BeFalse
    }

    It "a escolha padrão vira o botão destacado quando a opção não pede destaque" {
        $options = @(
            [PSCustomObject]@{ Key = "a"; Label = "A"; Description = ""; Accent = $false; Exit = $false },
            [PSCustomObject]@{ Key = "b"; Label = "B"; Description = ""; Accent = $false; Exit = $false }
        )
        $plan = Get-WinForgePromptPlan -Prompt ([PSCustomObject]@{ Kind = "choice"; Label = "?"; Options = $options; DefaultKey = "B" })

        $plan.Buttons[0].Accent | Should -BeFalse
        $plan.Buttons[1].Accent | Should -BeTrue
    }

    It "lista de marcação não gera botões (a janela monta os seus)" {
        $plan = Get-WinForgePromptPlan -Prompt ([PSCustomObject]@{ Kind = "multi"; Label = "?"; Options = @(); DefaultKey = "" })
        $plan.Buttons | Should -HaveCount 0
    }
}

Describe "Execução de ações na janela" {
    It "executa uma ação, responde às perguntas e captura a saída" {
        $result = Invoke-GuiProbe -Command "Test-GuiAsk" -Answers @{ "Deseja continuar?" = "S"; "Digite seu nome" = "Ana" }

        $result.Status | Should -Be "Completed"
        $result.Text | Should -Match "Resposta: True / Olá, Ana"
        $result.Text | Should -Match "fim"
    }

    It "o modo gráfico está ativo dentro da ação (perguntas viram botões, sem pausa de teclado)" {
        $result = Invoke-GuiProbe -Command "Test-GuiMode"
        $result.Text | Should -Match "modo=True"
    }

    It "interrompe uma ação em andamento" {
        (Invoke-GuiProbe -Command "Test-GuiSlow" -StopWhenOutputMatches "dormindo").Status | Should -Be "Stopped"
    }

    It "interrompe uma ação que aguarda resposta" {
        (Invoke-GuiProbe -Command "Test-GuiWait" -StopOnPrompt).Status | Should -Be "Stopped"
    }

    It "mostra a mensagem quando a ação lança erro" {
        $result = Invoke-GuiProbe -Command "Test-GuiThrow"
        $result.Text | Should -Match "explodiu"
    }

    It "um comando que não existe mostra erro em vez de travar" {
        $result = Invoke-GuiProbe -Command "Comando-Que-Nao-Existe"
        $result.Status | Should -Match "Completed|Failed"
        $result.Text | Should -Match "Comando-Que-Nao-Existe"
    }

    It "programas nativos têm a saída capturada e o código de saída devolvido" {
        $result = Invoke-GuiProbe -Command "Test-GuiNative"

        $result.Text | Should -Match "linha-nativa"
        $result.Text | Should -Match "codigo=4"
    }

    It "a saída de programas nativos respeita a ordem das mensagens" {
        $result = Invoke-GuiProbe -Command "Test-GuiOrder"

        $text = $result.Text
        $text.IndexOf("primeiro") | Should -BeLessThan $text.IndexOf("segundo")
        $text.IndexOf("segundo") | Should -BeLessThan $text.IndexOf("terceiro")
    }

    It "tabelas enviadas com Format-Table | Out-Host aparecem na janela, na ordem certa" {
        $result = Invoke-GuiProbe -Command "Test-GuiTable"

        $result.Text | Should -Match "Nome\s+Valor"
        $result.Text | Should -Match "alfa\s+1"
        $result.Text | Should -Match "beta\s+22"
        $result.Text.IndexOf("beta") | Should -BeLessThan $result.Text.IndexOf("depois da tabela")
    }

    It "avisos aparecem com o prefixo AVISO" {
        $result = Invoke-GuiProbe -Command "Test-GuiWarning"
        $result.Text | Should -Match "AVISO: cuidado com isto"
        $result.Text | Should -Match "depois do aviso"
    }

    It "o host entende PromptForChoice e devolve o índice escolhido" {
        $result = Invoke-GuiProbe -Command "Test-GuiHostChoice" -Answers @{ "Posso continuar?" = "0" }
        $result.Text | Should -Match "indice=0"

        $default = Invoke-GuiProbe -Command "Test-GuiHostChoice"
        $default.Text | Should -Match "indice=1"
    }

    It "a mesma sessão executa vários comandos em sequência, mantendo o estado" {
        $session = New-WinForgeGuiSession -ModuleRoot $script:GuiTestRoot -Modules @("Core", "Console", "Probe")
        $texts = @()

        try {
            foreach ($round in 1..3) {
                [void](Start-WinForgeGuiCommand -Session $session -Command "Test-GuiTwice")
                $deadline = (Get-Date).AddSeconds(60)
                $builder = New-Object System.Text.StringBuilder

                do {
                    $update = Read-WinForgeGuiUpdate -Session $session
                    foreach ($item in $update.Items) { [void]$builder.Append($item.Text) }
                    Start-Sleep -Milliseconds 30
                } while ($update.Status -eq "Running" -and (Get-Date) -lt $deadline)

                $update.Status | Should -Be "Completed"
                $texts += $builder.ToString()
            }

            $texts[0] | Should -Match "execucao=1"
            $texts[1] | Should -Match "execucao=2"
            $texts[2] | Should -Match "execucao=3"
        }
        finally { Close-WinForgeGuiSession -Session $session }
    }

    It "não inicia um segundo comando enquanto o primeiro roda" {
        $session = New-WinForgeGuiSession -ModuleRoot $script:GuiTestRoot -Modules @("Core", "Console", "Probe")

        try {
            Start-WinForgeGuiCommand -Session $session -Command "Test-GuiSlow" | Should -BeTrue
            Start-WinForgeGuiCommand -Session $session -Command "Test-GuiSlow" | Should -BeFalse

            Stop-WinForgeGuiCommand -Session $session
            $deadline = (Get-Date).AddSeconds(30)

            do {
                $update = Read-WinForgeGuiUpdate -Session $session
                Start-Sleep -Milliseconds 30
            } while ($update.Status -eq "Running" -and (Get-Date) -lt $deadline)

            $update.Status | Should -Be "Stopped"
        }
        finally { Close-WinForgeGuiSession -Session $session }
    }

    It "fechar a sessão durante uma ação não trava" {
        $session = New-WinForgeGuiSession -ModuleRoot $script:GuiTestRoot -Modules @("Core", "Console", "Probe")
        [void](Start-WinForgeGuiCommand -Session $session -Command "Test-GuiSlow")
        Start-Sleep -Milliseconds 500

        $watch = [System.Diagnostics.Stopwatch]::StartNew()
        Close-WinForgeGuiSession -Session $session
        $watch.Stop()

        $watch.Elapsed.TotalSeconds | Should -BeLessThan 20
    }

    It "parar sem nenhuma ação em andamento não faz nada" {
        $session = New-WinForgeGuiSession -ModuleRoot $script:GuiTestRoot -Modules @("Core", "Console", "Probe")

        try { { Stop-WinForgeGuiCommand -Session $session } | Should -Not -Throw }
        finally { Close-WinForgeGuiSession -Session $session }
    }
}

Describe "Botões de escolha e listas de marcação" {
    It "apresenta uma escolha como botões e devolve a opção clicada" {
        $result = Invoke-GuiProbe -Command "Test-GuiChoice" -Answers @{ "Escolha uma opção" = "2" }

        $result.Status | Should -Be "Completed"
        $result.Text | Should -Match "escolha=2"
        $script:LastGuiPrompt.Kind | Should -Be "choice"
        (($script:LastGuiPrompt.Options | ForEach-Object Label) -join "|") | Should -Be "Itens antigos|Tudo|Cancelar"
    }

    It "um clique em chave desconhecida cai na opção padrão" {
        $result = Invoke-GuiProbe -Command "Test-GuiChoice" -Answers @{ "Escolha uma opção" = "zzz" }
        $result.Text | Should -Match "escolha=1"
    }

    It "monta o plano com descrição, destaque e opção de sair" {
        $null = Invoke-GuiProbe -Command "Test-GuiChoice" -Answers @{ "Escolha uma opção" = "0" }
        $plan = Get-WinForgePromptPlan -Prompt $script:LastGuiPrompt

        $plan.ShowText | Should -BeFalse
        $plan.Buttons.Count | Should -Be 3
        $plan.Buttons[0].Accent | Should -BeTrue
        $plan.Buttons[0].Description | Should -Be "recomendado"
        $plan.Buttons[2].Exit | Should -BeTrue
    }

    It "usa Sim/Não em Confirm-WinForgeAction" {
        $yes = Invoke-GuiProbe -Command "Test-GuiConfirm" -Answers @{ "Quer mesmo?" = "S" }
        $no = Invoke-GuiProbe -Command "Test-GuiConfirm" -Answers @{ "Quer mesmo?" = "N" }

        $yes.Text | Should -Match "confirmou=True"
        $no.Text | Should -Match "confirmou=False"
    }

    It "devolve as chaves marcadas na lista" {
        $result = Invoke-GuiProbe -Command "Test-GuiMulti" -Answers @{ "Marque os itens" = "c" }

        $result.Text | Should -Match "marcados=c"
        $script:LastGuiPrompt.Kind | Should -Be "multi"
        (($script:LastGuiPrompt.Options | Where-Object Selected | ForEach-Object Key) -join ",") | Should -Be "b"
    }

    It "devolve nulo quando a lista é cancelada" {
        $result = Invoke-GuiProbe -Command "Test-GuiMulti" -Answers @{ "Marque os itens" = "CANCEL" }
        $result.Text | Should -Match "cancelado"
    }
}

Describe "Perguntas no console (sem interface gráfica)" {
    It "aceita a chave da opção, sem diferenciar maiúsculas, e ignora respostas inválidas" {
        try {
            Set-FakeReadHost -Answers "x", "B"
            Read-WinForgeChoice -Message "Escolha" -Options @(@{ Key = "a"; Label = "Um" }, @{ Key = "b"; Label = "Dois" }) | Should -Be "b"
        }
        finally { Clear-FakeReadHost }
    }

    It "usa a opção padrão quando a resposta é vazia" {
        try {
            Set-FakeReadHost -Answers ""
            Read-WinForgeChoice -Message "Escolha" -DefaultKey "C" -Options @(@{ Key = "C"; Label = "Continuar" }, @{ Key = "P"; Label = "Pular" }) | Should -Be "C"
        }
        finally { Clear-FakeReadHost }
    }

    It "desiste depois de muitas respostas inválidas em vez de repetir para sempre" {
        try {
            Set-FakeReadHost -Answers @("x", "y", "z", "w", "v", "u", "t", "s", "r", "q")
            { $null = Get-HostText { Read-WinForgeChoice -Message "Escolha" -Options @(@{ Key = "1"; Label = "Um" }) } } | Should -Throw -ExpectedMessage "*Nenhuma resposta válida*"
        }
        finally { Clear-FakeReadHost }
    }

    It "seleciona vários itens por números e intervalos" {
        try {
            Set-FakeReadHost -Answers "9", "1,3"
            $options = @(@{ Key = "a"; Label = "A" }, @{ Key = "b"; Label = "B" }, @{ Key = "c"; Label = "C" })
            ((Read-WinForgeMultiSelect -Message "Marque" -Options $options) -join ",") | Should -Be "a,c"
        }
        finally { Clear-FakeReadHost }
    }

    It "P mantém os itens pré-marcados" {
        try {
            Set-FakeReadHost -Answers "p"
            $options = @(@{ Key = "a"; Label = "A" }, @{ Key = "b"; Label = "B"; Selected = $true })
            ((Read-WinForgeMultiSelect -Message "Marque" -Options $options) -join ",") | Should -Be "b"
        }
        finally { Clear-FakeReadHost }
    }

    It "seleciona todos com T e cancela com resposta vazia" {
        $options = @(@{ Key = "a"; Label = "A" }, @{ Key = "b"; Label = "B" })

        try {
            Set-FakeReadHost -Answers "t"
            ((Read-WinForgeMultiSelect -Message "Marque" -Options $options) -join ",") | Should -Be "a,b"

            Set-FakeReadHost -Answers ""
            Read-WinForgeMultiSelect -Message "Marque" -Options $options | Should -BeNullOrEmpty
        }
        finally { Clear-FakeReadHost }
    }

    It "lista vazia devolve nulo sem perguntar nada" {
        try {
            Set-FakeReadHost -Answers "1"
            Read-WinForgeMultiSelect -Message "Marque" -Options @() | Should -BeNullOrEmpty
            $global:WfFakeAnswers.Count | Should -Be 1
        }
        finally { Clear-FakeReadHost }
    }

    It "Confirm-WinForgeAction aceita S, SIM, Y, N, NAO e o padrão, e recusa lixo" -ForEach @(
        @{ Answer = "s"; Default = ""; Expected = $true },
        @{ Answer = "SIM"; Default = ""; Expected = $true },
        @{ Answer = "y"; Default = ""; Expected = $true },
        @{ Answer = "n"; Default = ""; Expected = $false },
        @{ Answer = "nao"; Default = ""; Expected = $false },
        @{ Answer = "não"; Default = ""; Expected = $false },
        @{ Answer = ""; Default = "S"; Expected = $true },
        @{ Answer = ""; Default = "N"; Expected = $false },
        @{ Answer = "  s  "; Default = "N"; Expected = $true }
    ) {
        try {
            Set-FakeReadHost -Answers @($Answer)
            $params = @{ Message = "Pergunta" }
            if ($Default) { $params.DefaultKey = $Default }
            Confirm-WinForgeAction @params | Should -Be $Expected
        }
        finally { Clear-FakeReadHost }
    }

    It "Confirm-WinForgeAction sem resposta válida lança erro depois de algumas tentativas" {
        try {
            Set-FakeReadHost -Answers @("talvez", "quem sabe", "depois", "sei lá", "hmm", "ok", "uhm")
            { $null = Get-HostText { Confirm-WinForgeAction "Pergunta" } } | Should -Throw -ExpectedMessage "*Nenhuma resposta válida*"
        }
        finally { Clear-FakeReadHost }
    }
}
