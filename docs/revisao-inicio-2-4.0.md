# WinForge 4.0 — segunda revisão do Início (R40)

**Data:** 21/11/2026 · **Versão:** Build 4.0 em preparação, depois da R39

**Pedido:** revisar a tela e a função Início com cinco olhares:
- **Analista de Produto Sênior:** avalia o todo.
- **Engenheiro de Software Sênior:** revisa o código, refatora, segue as boas práticas, tira o que não serve e melhora o desempenho.
- **Designer Sênior, com um Especialista em UX/UI:** revisam a tela, os botões, os textos e os fluxos; o engenheiro aplica.
- **MVP Windows:** confere se o Início segue as práticas da Microsoft, se cada função faz da melhor forma o que promete e se é robusto e estável.
- **QA Sênior:** testa tudo o que dá para testar, o óbvio e o que não é; o engenheiro aplica.

**De onde partiu:** depois da R39, o dono mandou o print do Início e da Manutenção com "Tudo igual". A R39 corrigiu a causa do Início pela metade (a fonte dos títulos recusada pelo WPF), e esta revisão começou por entender por que o print não mudou.

**Resultado:** 14 achados, todos corrigidos.

| Olhar | Achados |
|---|---|
| Produto | 2: abrir o WinForge de outra pasta com uma janela aberta mostrava a janela antiga sem dizer nada (a causa provável do "Tudo igual"); e uma parte do Início que o Windows recusava sumia sem aviso, nem na tela nem no log |
| Engenharia | 6: a fonte dos títulos dependia de o WPF achar o recurso na hora em que o texto entra na tela; cada parte entrava aos pedaços; o Agendador de Tarefas consultado na thread da janela; a nota montada duas vezes por visita; o resumo do histórico em três peças soltas; um caractere de controle num comentário |
| Designer e UX/UI | 3: o "quase cheio" (e o "pouco espaço") no cartão do disco empurrava os três cartões para um embaixo do outro; a faixa inclinada atravessava a lista de pontos de atenção; "Agora não" refazia a página e jogava o foco do teclado para o começo da janela |
| MVP Windows | 1: o Narrador lia a frase da nota de novo a cada visita ao Início |
| QA | 2: o foco do teclado sumia quando a nota era refeita no fim da leitura; e "Ler de novo" pelo teclado perdia o foco para sempre |

Nada rodou num Windows de verdade. A conferência foi feita na nuvem, com as funções de verdade da janela sobre um WPF simulado, conferido contra o perfil do Windows PowerShell 5.1. O que só um PC mostra entrou no roteiro de conferência (§31).

## O Início hoje

De cima para baixo, numa visita comum:
1. **Um aviso no alto,** só quando alguma parte não pôde ser mostrada (novo).
2. **Avisos da leitura,** como o WinForge aberto com a conta de outro Administrador.
3. **A nota de saúde:** "Saúde do PC", a frase, Verificar o PC e Otimizar, a nota de 0 a 100 com os dez traços, a hora da leitura com o botão de ler de novo e, com pontos de atenção, a lista deles com o botão de cada um.
4. **Seu PC:** os cartões Disco do sistema, Proteção e Sistema e a linha da última manutenção, do reinício pendente e da bateria.
5. **Histórico neste PC:** o que as manutenções liberaram, quantas foram feitas e as mudanças anotadas, só o que já aconteceu.
6. **A configuração inicial,** enquanto faltar um dos três passos.

A leitura do PC roda em 7 etapas, fora da thread da janela, e cada cartão aparece quando a etapa dele termina. A leitura vale 30 segundos: voltar ao Início nesse tempo mostra a mesma, sem ler de novo.

## Analista de Produto

| # | O que estava | Por que importa | Como ficou |
|---|---|---|---|
| P1 | A janela do WinForge é uma por conta do Windows, e não uma por pasta. Com uma janela aberta, abrir o WinForge de outra pasta só trazia a janela aberta para a frente, sem dizer nada. Quem extraiu a versão nova numa pasta e abriu continuava vendo a antiga. | É a causa mais provável do "Tudo igual" depois da R39: a correção estava na pasta nova, e a janela na tela era a da pasta antiga. | A janela aberta diz que é de outra pasta: "Esta janela é de outra pasta do WinForge", com a pasta de onde a pessoa abriu e a da janela, e os botões **Fechar esta janela** e **Continuar aqui** (o foco começa no Continuar aqui). Fechar passa pelo caminho de sempre, que pergunta quando há uma ação rodando. Da mesma pasta, nada muda. |
| P2 | Uma parte do Início que o WPF recusava ao entrar na tela sumia sem aviso, e nada ia para o log. | Foi assim que o defeito da R39 passou por duas revisões: na tela não havia erro, e o Pacote de suporte não trazia pista. | A parte que falha fica de fora inteira; um aviso no alto diz qual ("Parte do Início não pôde ser mostrada: Seu PC. O motivo vai no Pacote de suporte (Sobre o WinForge).") e o motivo do WPF vai para `logs\janela.log`, que o Pacote de suporte leva. O resto da página aparece. |

**Conferido e mantido:**
- **O Otimizar em destaque quando não há pontos de atenção:** é o caminho principal do WinForge, não cria urgência falsa e mostra o plano antes de mudar qualquer coisa.
- **A ordem da página:** a nota (o que fazer agora), Seu PC (o estado), o histórico (o que o WinForge já fez) e a configuração inicial, por último, porque é feita uma vez.
- **O Início não muda nada no PC:** os cartões só levam às telas; quem muda são os botões da nota e dos pontos.

## Engenheiro de Software

| # | O que estava | Como ficou |
|---|---|---|
| E1 | A fonte dos títulos entrava em cada texto por uma referência ao recurso `DisplayFont`, que o WPF resolve quando o texto entra na tela. Foi nesse momento que a fonte embrulhada da R39 derrubava as partes. | `Set-GuiDisplayFont` põe a fonte direto na propriedade do texto (`$script:DisplayFontFamily`, feita por `Set-GuiTypography`), com o desenho ideal da letra. A fonte deixa de depender do dicionário de recursos na hora de entrar na tela. O recurso continua para o XAML. |
| E2 | Cada parte entrava controle por controle no painel da página. Com uma falha no meio, sobravam pedaços: o traço do histórico sem os números, como no print da R39. | Cada parte é uma peça só (a nota; Seu PC com o título, os cartões e a linha; o histórico com o título, o traço e os números; a configuração inicial), e `Add-GuiHomePart` a põe na tela inteira ou a deixa de fora inteira, com o aviso e o log (`Add-WinForgeWindowProblem`, no Core.psm1). |
| E3 | A configuração inicial perguntava ao Agendador de Tarefas, pela COM, na thread da janela, a cada visita ao Início. Um Agendador lento segurava a janela. | A etapa da manutenção agendada, que já roda fora da janela e com prazo, devolve também se o passo está feito (`ScheduleSetup`), e a faixa aparece quando ela chega. A consulta na janela saiu. A faixa só é refeita quando os passos ou o Administrador mudam. |
| E4 | A nota de saúde era montada duas vezes por visita: a de "Lendo" e, logo depois, a da leitura guardada. | Uma vez, no fim da montagem da página, já com o que mostrar. |
| E5 | `New-GuiValueSummary` devolvia três peças soltas (o título, o traço e os números). | Uma peça só, que entra inteira. |
| E6 | Um comentário tinha um caractere de controle (BEL) no lugar de `\a`, em `logs\abertura.log`. | Corrigido. |

**Por dentro:**
- **WinForge.Gui.ps1:** `Set-GuiDisplayFont`, `Add-GuiHomePart`, `Show-GuiHomeProblem`, `Update-GuiSetupCard`, `Close-GuiSetupCard`, `Get-GuiHeroBandHeight`, `Get-GuiHomeFocusKey`, `Get-GuiHomeHealthFocus`, `Restore-GuiHomeHealthFocus`, `Test-GuiRequestFromOtherFolder`, `Show-GuiOtherFolderMessage` e `Receive-GuiWindowRequest` (novas); `New-GuiSetupCard -Checklist`; `Set-GuiHomeStamp` guarda o foco do botão de ler de novo; `Show-GuiHomeResult` põe a hora antes da nota e não anuncia mais.
- **Core.psm1:** `Add-WinForgeWindowProblem` grava o log da janela (a data, a versão e a parte numa linha, cada motivo numa linha só, sem caracteres de controle, as 200 linhas mais recentes); uma falha ao gravar não muda nada na tela.
- **Home.psm1:** `ScheduleSetup` em `Read-WinForgeHomeSchedule`; `Get-WinForgeSetupChecklist -ScheduleDone`, sem consultar o Agendador; o cartão do disco sem o complemento.
- **GuiHost.psm1:** o pedido de outra abertura leva a pasta e a identidade de quem abriu (`Root` e `App`); a janela limpa a pasta (uma linha só, até 260 letras) e só aceita uma identidade no formato do WinForge.
- **Reports.psm1:** o Pacote de suporte leva o `janela.log`.
- **Schedule.psm1:** saiu a consulta ao Agendador que a janela fazia, sem outro uso.
- **Traduções:** 5.563 textos; o " · quase cheio" saiu de uso.

## Designer e Especialista em UX/UI

| # | O que estava | Orientação | Como ficou |
|---|---|---|---|
| D1 | Com o disco quase cheio, o cartão dizia "de 237 GB · quase cheio" (com pouco espaço, "· pouco espaço"). O complemento mais largo empurrava os três cartões para um embaixo do outro, e a página ficava duas vezes mais comprida justo quando pede atenção. | O estado já está dito em outros lugares; o cartão não precisa repetir. | "de 237 GB". O aviso continua no valor e na barra amarelos, no "99% em uso" e no ponto da nota ("O disco do sistema está quase cheio", com Liberar espaço). Os três cartões ficam lado a lado. |
| D2 | Com pontos de atenção, a faixa inclinada da nota descia pelo cartão inteiro e atravessava a lista, com os botões dos pontos metade sobre ela. | A faixa acompanha a nota, não a lista. | A faixa vai só até o traço acima da lista; sem pontos, continua no cartão inteiro. |
| D3 | "Agora não", na configuração inicial, refazia a página inteira (e, passados 30 segundos da leitura, lia o PC de novo), e o foco do teclado voltava ao começo da janela. | Fechar uma faixa não deve mexer no resto da página. | A faixa sai no lugar, sem refazer a página, e o foco vai para o que vem antes dela. |

**Orientação aplicada também:** o aviso de parte faltando (P2) diz só a parte e onde está o motivo, numa linha numa janela comum. A mensagem de outra pasta (P1) segue as regras das mensagens da janela: a frase em destaque com até 60 letras, os verbos nos botões e a resposta segura como padrão.

**Conferido e mantido:**
- **A nota com dois caminhos,** Verificar o PC e Otimizar, e um destaque só.
- **Os valores que diminuem até caber,** sem cortar e sem reticências.
- **A barra cinza no lugar do valor** enquanto um cartão lê, em vez de "Lendo...".
- **O histórico só com o que já aconteceu.**

## MVP Windows

| # | O que estava | Por que importa | Como ficou |
|---|---|---|---|
| M1 | O Narrador lia a frase da nota de novo a cada volta ao Início com a leitura guardada. | O anúncio é para o que mudou sem a pessoa pedir; repetir a cada visita é ruído. | O anúncio sai só quando uma leitura termina (também a que falhou). |

**Conferido e mantido**, com as fontes no fim:
- **A fonte direto na propriedade (E1):** a Microsoft diz que um `DynamicResource` adia a busca do recurso até o valor ser preciso, o que pode acontecer depois de a página carregar. É nesse momento, longe de quem montou o controle, que uma recusa aparecia. Posta direto, a fonte é conferida quando o texto é montado.
- **Uma janela por conta:** o mutex `Local\WinForge.Window.<SID>` fica no espaço da sessão, como a Microsoft descreve para o prefixo `Local\`; cada sessão do Windows tem a sua janela, e as contas não se misturam.
- **O pedido de outra pasta não abre nada:** o `window-request.json` fica numa pasta em que qualquer programa da conta grava. A janela, que em geral roda como Administrador, só mostra a pasta (numa linha, com limite) e nunca abre o caminho que vem no pedido; a pessoa fecha e abre o WinForge que quiser.
- **O foco do teclado:** quando a nota é refeita, o foco volta ao mesmo botão, pelo `Keyboard.FocusedElement` e pelo que o botão abre; "Agora não" passa o foco com `MoveFocus`, como a Microsoft mostra. Um botão desligado não recebe o foco (a Microsoft diz que `Focusable` e `IsEnabled` precisam ser verdadeiros), então o foco vai para o primeiro botão ligado da nota.
- **O Agendador fora da janela (E3):** a mesma leitura do Agendador que a etapa já fazia, com o prazo dela. A consulta COM na thread da janela saiu.

## QA Sênior

**Como foi testado:** uma bateria nova do Início, com as funções de verdade da janela sobre o WPF simulado: 115 conferências em cada idioma.
- **A fonte dos títulos (A):** guardada como `FontFamily`, posta direto em cada título e no número da nota, com o desenho ideal da letra; sem a fonte, o título fica com a da janela, sem erro; nenhum texto do script pega a fonte pelo recurso. Com o recurso estragado como na R38, o Início inteiro aparece, sem aviso nem log, e o destaque das nove páginas também.
- **Cada parte inteira (B):** a ordem e o conteúdo de cada peça; Seu PC, o histórico e a nota recusados, um de cada vez e juntos, ficam de fora inteiros, sem pedaços, e o resto aparece; um aviso só, com as partes; o log com a data, a versão, a parte e o motivo, cada linha limpa e com limite, as 200 mais recentes; uma falha ao gravar o log; o Pacote de suporte com o log.
- **A configuração inicial (C):** o agendamento desta pasta, de outra pasta, sem o script e sem tarefa; a lista sem consultar o Agendador; a faixa esperando a etapa, aparecendo com ela, refeita só quando algo muda, saindo com os três passos; a leitura guardada com e sem o agendamento (uma de antes desta versão); a etapa que falhou.
- **Agora não (D):** fecha de vez, sai no lugar, sem refazer a página nem ler o PC, com o foco no que vem antes; uma etapa que chega depois não a traz de volta.
- **O foco do teclado (E):** no Otimizar, no botão de um ponto, num ponto resolvido, num cartão, no botão de ler de novo ligado e desligado; ler de novo pelo teclado, com o foco passado pelo Windows a um elemento de cima e a nenhum; a pessoa levando o foco a um cartão no meio da leitura; uma visita nova.
- **O Narrador e a nota uma vez (F):** a volta ao Início não anuncia; a leitura que termina, e a que falha, anunciam; a nota montada uma vez, também na primeira visita; a leitura guardada que não pode ser mostrada fica em "Lendo".
- **A faixa inclinada (G):** nos dois temas, sem e com pontos, o lado inclinado acompanhando a altura nova; no contraste alto, sem faixa.
- **O disco cheio (H):** quase cheio e com pouco espaço, o complemento, a frase e o ponto da nota; os três cartões lado a lado na janela de abertura.
- **Outra pasta (J):** o pedido com a pasta e a identidade; a pasta comprida, com quebra de linha e com caracteres de controle; uma identidade fora do formato; um pedido de uma versão anterior; a mesma pasta escrita de outro jeito; a mensagem, os dois botões e o padrão; a ação do pedido que não roda; o relógio dos pedidos que volta só com a janela aberta; da mesma pasta, a ação do monitor como antes.
- **Os textos (K):** os textos novos nos três idiomas, nenhum sem tradução.

**Achados**

| # | O que estava | Como ficou |
|---|---|---|
| Q1 | Com o foco do teclado no Otimizar (ou no botão de um ponto) durante a leitura, a nota refeita no fim levava o foco embora, e o Tab recomeçava do alto da janela. | O foco volta ao mesmo botão na nota nova; se o ponto foi resolvido, ao primeiro botão dela. Com o foco fora da nota, nada muda. |
| Q2 | "Ler de novo" pelo teclado: o botão é desligado durante a leitura, e um botão desligado perde o foco. No fim, ninguém o devolvia. A nota também nascia com o botão ainda desligado. | A hora e o botão vêm antes da nota (ela nasce com o botão ligado), e o foco volta a ele no fim da leitura. Uma vez só, e só se a pessoa não levou o foco a outro lugar. |

Os testes também acharam os do produto (P2), os do designer (D1 a D3) e o do MVP (M1).

**Contra o código de antes (853abc3):** cada conferência das correções falha, e as que conferem o que foi mantido passam. Na fonte dos títulos, 14 de 17 falham; no foco, 7 de 11; no Narrador, 3 de 6; na faixa, 4 de 9; no disco, 3 de 6. As partes inteiras, a configuração inicial, o Agora não e a outra pasta param logo no começo, porque as funções novas não existem.

**29 defeitos de propósito,** e as conferências pegam todos: a fonte de volta pelo recurso; a parte sem proteção; Seu PC e o histórico em pedaços; sem o aviso; sem o log; o log sem limpar as linhas; a faixa refeita sempre; o agendamento de outra pasta contando como feito; o Agendador lido de novo na janela; o Agora não refazendo a página ou sem levar o foco; o foco que não volta, que vai para um botão desligado, que não é anotado, que vale para sempre, que é puxado de qualquer lugar e que passa a uma visita nova; a nota nascendo com o botão desligado; o anúncio a cada visita; a faixa no cartão inteiro; o complemento do disco de volta; a nota montada duas vezes; outra pasta não percebida; a pasta do pedido sem limpar; a mensagem começando no Fechar; o pedido sem a identidade; a ação rodando de outra pasta; o relógio dos pedidos voltando com a janela fechada.

**Nada do que funcionava quebrou:** as baterias das 14 páginas revistas, do Início da R13, da Manutenção e as gerais, com os mesmos números da R39; as da R37 e da R39 nas cópias que trocam só o que descreve o desenho de antes; as mensagens da janela, com a conta em 19; instalar, atualizar e o Setup de verdade da R39 para esta. O PSScriptAnalyzer tem 3 avisos a mais, todos do botão Agora não, que recebe o clique como os outros 43 botões da janela (`param ($sender, $eventArgs)`).

**O WPF simulado** ganhou o que esta revisão usa (o foco do teclado, `MoveFocus`, `Decorator`, `IsKeyboardFocused`) e foi conferido de novo contra o perfil do Windows PowerShell 5.1 do PSScriptAnalyzer: 83 tipos, 2.661 membros, nenhum que o Windows PowerShell não tenha. Como no Windows, um elemento desligado não recebe o foco.

## O que só um PC mostra

Isto entrou no roteiro de conferência (§31):
- **A mensagem de outra pasta,** com o WinForge aberto de duas pastas.
- **O Início inteiro,** com o disco quase cheio e os três cartões lado a lado.
- **O aviso e o log,** se alguma parte faltar.
- **A configuração inicial** aparecendo com a leitura, sem segurar a janela.
- **O teclado e o Narrador** na nota de saúde e no Agora não.
- **A faixa inclinada** só atrás da nota, com pontos de atenção.

## Fontes
- [DynamicResource Markup Extension](https://learn.microsoft.com/en-us/dotnet/desktop/wpf/advanced/dynamicresource-markup-extension) (Microsoft): o `DynamicResource` adia a busca do recurso "until the requested resource value is actually required", o que "may potentially be after the XAML page is loaded".
- [Focus overview (WPF)](https://learn.microsoft.com/dotnet/desktop/wpf/advanced/focus-overview) (Microsoft): `Keyboard.FocusedElement` é o elemento com o foco do teclado; `MoveFocus` com um `TraversalRequest` passa o foco na direção pedida.
- [UIElement.Focus](https://learn.microsoft.com/en-us/dotnet/api/system.windows.uielement.focus?redirectedfrom=MSDN&view=windowsdesktop-11.0) (Microsoft): "To be focusable, Focusable and IsEnabled must both be true."
- [Kernel object namespaces](https://learn.microsoft.com/windows/win32/termserv/kernel-object-namespaces) (Microsoft): o prefixo `Local\` cria o objeto no espaço da sessão, e as sessões não interferem umas nas outras.
