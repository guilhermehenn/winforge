# WinForge 4.0 — segunda revisão da Personalização (R53)

**Data:** 22/11/2026 · **Versão:** Build 4.0 em preparação, depois da R52

**Pedido:** revisar a tela e a função Personalização com cinco olhares:
- **Analista de Produto Sênior:** avalia o todo.
- **Engenheiro de Software Sênior:** revisa o código, refatora, segue as boas práticas, tira o que não serve e melhora o desempenho.
- **Designer Sênior, com um Especialista em UX/UI:** revisam a tela, os botões, os textos e os fluxos; o engenheiro aplica.
- **MVP Windows:** confere se a Personalização segue as práticas da Microsoft, se cada função faz da melhor forma o que promete e se é robusta e estável.
- **QA Sênior:** testa tudo o que dá para testar, o óbvio e o que não é; o engenheiro aplica.

**De onde partiu:** a primeira revisão da Personalização (R24) foi antes do desenho novo (R37), da revisão de UX (R38) e da chave na própria linha (R52). A R52 já deu à Personalização o resumo do alto, as linhas cinza enquanto ela lê e a chave que muda na linha, porque as duas páginas de ajustes dividem a mesma tela. Esta olhou o que é só dela: a cor de destaque, a tela de bloqueio, os 18 ajustes e o que eles dividem com os Ajustes do Windows (a linha de cada chave e as linhas de ação dentro dos grupos).

**Resultado:** 10 achados, todos corrigidos.

| Olhar | Achados |
|---|---|
| Produto | 2: a cor de destaque mudando o Windows sem desfazer; e as teclas do idioma, nos Ajustes do Windows, com a mesma falta |
| Engenharia | 2: a cor gravada em dois lugares, com a pergunta e a gravação juntas; e a chave na própria linha presa às chaves, sem servir a outra linha |
| Designer e UX/UI | 3: a cor escolhida pelo nome numa tela à parte (a UX19 da R38, para a cor); as linhas de ação com o texto começando em outro lugar (a UX13); e as frases das chaves passando de 60 letras (a UX15) |
| MVP Windows | 1: os Widgets mudando todas as contas do PC sem a página dizer |
| QA | 2: o Modo escuro na própria linha perdendo o foco do teclado e o aviso ao leitor de tela; e a página de ajustes voltando ao alto quando o tema muda |

Nada rodou num Windows de verdade. A conferência foi feita na nuvem com o Windows simulado da R23 (o registro, o Explorador, os avisos aos programas, a sessão e o diário do Histórico) e com a janela simulada da R37. O que só um PC mostra entrou no roteiro de conferência (§43).

## A Personalização hoje

No alto, **Personalização do Windows** (abre a tela de fundo, os temas, as cores e as fontes nas Configurações) e **Atualizar estado**; abaixo, o resumo (Mudanças) e as chaves por categoria:
- **Barra de tarefas e Iniciar (9):** barra à esquerda, finalizar tarefa, pesquisa, Visão de Tarefas, segundos no relógio, Widgets, botão do Copilot (até o Windows 11 23H2), agrupar os botões e recomendações no Iniciar;
- **Área de trabalho (2):** a Lixeira e Este Computador;
- **Cores e transparência (4):** modo escuro, transparência, a cor no Iniciar e na barra e nas barras de título, e a linha **Cor de destaque**, agora com as amostras;
- **Tela de bloqueio (3):** clima e notícias, notificações e dicas, e a linha **Tela de bloqueio do Windows**, que abre a página dela nas Configurações.

No Windows 10, aparecem as 11 chaves que existem nele. Os Widgets pedem Administrador e mostram o escudo.

## Analista de Produto

| # | O que estava | Por que importa | Como ficou |
|---|---|---|---|
| P1 | Escolher a cor de destaque anotava "Cor de destaque: Verde" no Histórico de mudanças, mas sem o desfazer. A cor de antes se perdia, e uma cor escolhida nas Configurações (fora das oito do WinForge) não tinha como voltar. | É a única mudança da Personalização sem volta. Todas as chaves guardam o valor de antes, e a página promete o mesmo. | O Histórico guarda a cor de antes inteira (os sete valores que o Windows grava) e a escolhida. Desfazer devolve a de antes, inclusive a automática, a personalizada e um perfil novo, sem valores. Se a cor foi trocada depois (nas Configurações ou de novo pelo WinForge), fica como está, e a tela diz. Com o modo escuro e a cor no Iniciar e na barra, o Histórico oferece o Explorador. Elevado com outra conta, não desfaz, porque seria o perfil dela. |
| P2 | As teclas que trocam o idioma do teclado, nos Ajustes do Windows, tinham a mesma falta. A R24 revisou essa linha junto com a cor, e o código é o mesmo. | O mesmo de P1. | O mesmo desfazer: as teclas de antes voltam, e o Windows as relê na hora. |

**Conferido e mantido:**
- **Sem destaque na página:** o botão do alto leva ao que o WinForge não faz (papel de parede, temas, fontes).
- **As oito cores principais e a Automática,** com o azul do Windows 11 primeiro (R24).
- **A cor de destaque e a tela de bloqueio dentro dos grupos delas,** como as Configurações do Windows mostram a cor de destaque na página de Cores.

## Engenheiro de Software

| # | O que estava | Como ficou |
|---|---|---|
| E1 | `Set-WinForgeAccentColor` juntava a pergunta e sete gravações soltas. As teclas do idioma gravavam os três valores do mesmo jeito, e nenhum dos dois guardava o que havia antes. | Uma especificação por escolha (`Get-WinForgeChoiceSpec`: os valores, os caminhos, os tipos e a ordem do Windows, com a escolha automática por último). Um gravador para a escolha, o desfazer e as teclas (`Write-WinForgeChoiceValues`) e um leitor do que havia antes (`Read-WinForgeChoiceValues`). Um desfazer (`Undo-WinForgeChoiceChange`) que confere o que vem do diário pelo tipo de cada valor (`ConvertFrom-WinForgeChoiceValues`). A cor aceita `-Color`, a escolha da linha, sem a pergunta. `Get-WinForgeAccentColorKey` diz qual das escolhas é a de agora, e `Get-WinForgeAccentColorState` só a põe por extenso. |
| E2 | A chave na própria linha (R52) só servia às chaves: a linha guardava a chave e o ajuste. | A linha guardada diz o tipo (`Kind`). A da cor usa o mesmo caminho da chave: "Alterando…", o fim e a página refeita no meio. O foco e o aviso ao leitor de tela ficam numa função só (`Send-GuiTweakRowNews`), que serve também à página refeita pelo tema (Q1). |

**Por dentro:**
- **Tweaks.psm1:** `Get-WinForgeAccentColorKey`, `Get-WinForgeChoiceSpec`, `Read-WinForgeChoiceValues`, `ConvertFrom-WinForgeChoiceValues`, `Write-WinForgeChoiceValues` e `Undo-WinForgeChoiceChange` (novas); `Set-WinForgeAccentColor` com `-Color`, o desfazer e o `Quiet`; `Set-WinForgeKeyboardLanguageHotkey` com o desfazer; `Short` em `Get-WinForgeTweakSwitchLabels` e no catálogo; `Description` (a curta) e `Detail` (a inteira) em `Get-WinForgeTweakOverview`; os textos dos Widgets.
- **Journal.psm1:** os desfazeres `accent-color` e `keyboard-hotkeys`.
- **Navigation.psm1:** a busca leva à linha da cor (`WinForgeSearchRowItems`).
- **WinForge.Gui.ps1:** `New-GuiAccentRow`, `Update-GuiAccentRow`, `Invoke-GuiAccentChoice` e `Send-GuiTweakRowNews` (novas); `New-GuiActionRow` com `-NoIcon`; a frase curta e a inteira em `New-GuiTweakRow`; o foco e a rolagem quando o tema refaz a página.
- **MainWindow.xaml:** os estilos `ColorSwatch` e `ColorSwatchSelected`.
- **Traduções:** 5.765 textos (61 novos e 2 que saíram de uso). Entraram seis funções nos módulos (1.328) e quatro na janela (200).

## Designer e Especialista em UX/UI

| # | O que estava | Orientação | Como ficou |
|---|---|---|---|
| D1 | Para trocar a cor de destaque, a pessoa abria a linha, ia para a tela de execução, escolhia o nome numa lista (sem ver a cor), lia o resultado e clicava em Voltar. A busca por "cor de destaque" levava à mesma pergunta. | A cor é escolhida vendo a cor, na página, como as chaves desde a R52 (a UX19 da R38). | A linha mostra "Agora: Azul" e, embaixo, as oito cores em círculos e a **Automática**. A cor de agora tem um anel, que não depende só da cor para ser visto. Um clique troca a cor na própria linha ("Alterando…" e "Agora: Verde"); a cor que já está marcada não faz nada. O foco volta para a amostra marcada, e o leitor de tela ouve "Cor de destaque: Verde". O Tab entra no grupo na cor marcada e sai de uma vez; as setas andam pelas amostras. A tela de execução só abre quando há algo a ler: a pergunta do Explorador (com o modo escuro e a cor na barra) e a Automática (a cor só muda com o papel de parede). Com outra cor escolhida nas Configurações, nenhuma amostra fica marcada. Elevado com outra conta, "Outra conta", com as amostras desligadas. A busca leva à linha, destacada. No menu de texto, a pergunta continua. |
| D2 | Nas linhas de ação dentro dos grupos de ajustes (Cor de destaque, Tela de bloqueio do Windows e, nos Ajustes do Windows, as teclas do idioma e as notificações), o texto começava depois de um ícone, e o das chaves, na borda (a UX13 da R38). | O texto começa no mesmo lugar em todo o cartão. | Essas linhas ficam sem o ícone do assunto. A seta ou o ícone de "abre fora" continuam no fim. |
| D3 | A frase embaixo de cada chave passava de 60 letras em 48 dos 53 ajustes em português (50 em espanhol), com média de 71 a 88 letras conforme a página e o idioma (a UX15 da R38). Em espanhol, quebrava em duas linhas e deixava cada linha de uma altura. | A mesma regra das ações: uma frase curta na linha e a inteira na dica e no leitor de tela. | Cada ajuste tem a frase curta, com até 60 letras nos três idiomas e sem ponto no fim, como as das ações ("Ajuda a perceber arquivos disfarçados"). A inteira aparece ao passar o mouse, e o leitor de tela a ouve. Vale para as duas páginas, que dividem a linha. A busca continua achando pela frase inteira. |

**Conferido e mantido:**
- **A chave nunca mostra um estado que o Windows não tem** (R23 e R52): a linha da cor também é lida de novo no fim.
- **O nome de cada cor no leitor de tela e na dica:** a amostra não depende só da cor.
- **As perguntas no menu de texto,** com S/N e a lista numerada das cores.

## MVP Windows

| # | O que estava | Por que importa | Como ficou |
|---|---|---|---|
| M1 | A chave dos Widgets dizia "O painel de notícias e clima e o botão dele na barra de tarefas.", como as outras da página, que só mudam a conta de quem usa. | Ela grava a política `AllowNewsAndInterests`, que a Microsoft documenta só para o computador ("Scope: Device"): desligada, os Widgets saem de todas as contas do PC. | A frase curta diz "Notícias e clima na barra; vale para todas as contas", e a inteira e a descrição dizem o mesmo. O escudo continua. A política não mudou (a R24 conferiu que é o caminho documentado). |

**Conferido**, com as fontes no fim:
- **A cor gravada é a mesma que as Configurações gravam** (R24), e o desfazer devolve exatamente os valores de antes, pelos caminhos e tipos fixos do WinForge. Do diário, que fica onde qualquer programa da conta grava, só vêm os dados: uma paleta de outro tamanho, um número que não é número ou uma tecla fora de 1 a 4 fazem o desfazer ser recusado, e um caminho posto no diário é ignorado.
- **"Show accent color on Start and taskbar" só existe com o modo do Windows escuro ou personalizado,** e a cor automática vem da tela de fundo, como a Microsoft descreve. Por isso a cor escolhida com o modo claro muda na linha e não reinicia o Explorador: o que falta para pintar o Iniciar e a barra são as duas chaves logo acima.
- **Os programas são avisados da cor nova e da desfeita** (`WM_SETTINGCHANGE` com "ImmersiveColorSet", por `SendMessageTimeout` com `SMTO_ABORTIFHUNG`): uma janela travada não prende o WinForge.
- **A chave muda na própria linha** porque a Microsoft orienta usar a chave para o que vale logo depois que a pessoa a muda (R52). A cor segue a mesma regra.
- **O restante da R24 continua valendo:** cada chave grava o que as Configurações gravam, guarda o valor de antes e anota no Histórico; o que o Windows protege não é forçado.

## QA Sênior

**Como foi testado:** uma bateria nova da Personalização, 93 conferências em português e 99 em inglês e em espanhol (nos outros dois, mais uma por seção: nenhuma palavra solta em português na tela).
- **A cor pela linha (A):** a pergunta do menu de texto; a cor dada pela amostra, sem a pergunta; os sete valores e a ordem do Windows; o Histórico com a cor de antes e a escolhida; a cor na linha com o modo claro; a pergunta do Explorador com o modo escuro e a cor na barra; a Automática; uma cor que não existe; outra conta; a cor de agora como escolha (a Automática, uma das oito, o azul do Windows 10, outra cor e sem leitura).
- **O desfazer da cor (B):** do diário em JSON, valor por valor; o Explorador oferecido ou não; a cor trocada depois; a Automática desfeita depois de o Windows refazer as cores e desligada depois; um perfil novo; outra conta; seis jeitos de dados mexidos no diário; um caminho posto no diário; e o Histórico de mudanças de verdade, que anota com o desfazer, desfaz e marca como desfeita.
- **As teclas do idioma (C):** o desfazer, as trocadas depois, uma tecla fora de 1 a 4, um texto no lugar da tecla e o caminho pelo Histórico.
- **A frase curta (D):** os 53 ajustes com até 60 letras em cada idioma, sem ponto no fim; a lista com a curta e a inteira; a inteira com até 100 letras; os Widgets; a busca pela frase inteira.
- **A busca e o código (E):** a busca pela cor leva à linha; o Idioma e os atalhos como antes; um lugar só para gravar; a especificação; o diário só com as chaves conhecidas.
- **A janela (K, N, L e M):** a linha da cor (as nove escolhas, a ordem, o anel, o leitor de tela, o teclado, a dica, outra cor, a Automática, sem leitura e outra conta); as linhas de ação sem o ícone nas duas páginas, a frase curta e a inteira na dica e no leitor de tela; a cor mudando na linha (Alterando…, Agora: Verde, o foco, o aviso, a cor já marcada, uma escolha que não existe, a Automática com a tela de execução, a volta destacada, a página refeita no meio); e o Modo escuro na linha com o tema da janela trocando.
- **Os textos** nos três idiomas.

**Achados**

| # | O que estava | Como ficou |
|---|---|---|
| Q1 | Com a aparência do WinForge em Automático, ligar o Modo escuro na própria linha troca o tema da janela, e a página é refeita. O foco do teclado, que a linha tinha acabado de devolver à chave, ficava na chave que saiu da tela, e o aviso ao leitor de tela ia para uma linha que não existia mais. | Quando o tema troca, o foco e o aviso ficam guardados e vão para a linha nova quando a lista fica pronta. Se a pessoa abre outra página antes, o pendente sai. |
| Q2 | O tema trocado com uma página de ajustes aberta (pelo Modo escuro ou nas Configurações) levava a página ao alto. A rolagem voltava ainda com as linhas cinza, mais curtas, e a lista chegava depois. | A rolagem volta quando a lista fica pronta, como no Atualizar estado. |

Os testes também acharam os do produto (P1 e P2), os da engenharia (E1 e E2), os do designer (D1 a D3) e o do MVP (M1).

**Contra o código de antes (R52):** 69 conferências falham, cada uma de uma correção. As que passam conferem o que foi mantido (a pergunta do menu de texto, outra conta sem gravar, a cor por extenso, a frase inteira com até 100 letras, a busca pela frase inteira, o Idioma e os atalhos, as linhas sem a frase inteira, a chave sem troca de tema) e os marcadores de texto. Duas conferências da rolagem só falharam no código de antes depois de a bateria imitar o WPF: com as linhas cinza na tela, a página é curta, e a rolagem não passa do alto.

**45 defeitos de propósito,** e as conferências pegam todos: a cor dada ignorada; a cor e a Automática sem o desfazer; a cor nunca na linha, e na linha com a pergunta do Explorador; outra cor lida como sem leitura e o azul do Windows 10 sem nome; o desfazer passando por cima de uma cor mais nova, gravando a escolhida, com outra conta, sem avisar os programas, sem o Explorador e sem a cor de agora como identidade; a paleta de qualquer tamanho, um número que não é número, um número grande demais e a cor de antes pela metade; o Histórico sem o caminho da cor; as teclas sem o desfazer, sem avisar o Windows e com qualquer tecla; a frase curta fora do ajuste, a lista com a inteira e sem ela, os Widgets sem as contas e uma curta longa demais; a busca levando à pergunta; as linhas de ação com o ícone; a chave sem a inteira na dica e no leitor de tela; a cor como linha de ação, sem a marca, com o Tab fora dela, ligada com outra conta, trocando a cor que já está marcada, aceitando qualquer escolha, abrindo a tela de execução e sem a leitura nova; o foco no grupo e não na cor; o "Agora" no leitor de tela; e, no tema, o foco pendente ausente e esquecido, a rolagem perdida, o pendente valendo em outra página e o foco dentro da linha sem contar.

**Nada do que funcionava quebrou:** as baterias das 14 páginas revistas, com os mesmos números da R52; a das seis funções novas da R36 (257 em cada idioma); as das segundas revisões do Início ao Ajustes do Windows, com os mesmos números; a da Manutenção da R14 e a do Início da R13; as mensagens da janela (72 em cada idioma); instalar, atualizar com um clique, o pacote de suporte e o Setup de verdade, da R52 para esta; nenhuma função sem uso. A conferência dos nomes do XAML pegou um nome sem uso no estilo novo da amostra (o do anel), que saiu. O PSScriptAnalyzer mostra 243 avisos: os três a mais são dos dois tipos que todos os cliques da janela já têm (o nome `$sender`/`$eventArgs` e o `$eventArgs` sem uso), do clique da amostra, que segue o padrão do arquivo.

## O que só um PC mostra

Isto entrou no roteiro de conferência (§43):
- **A cor de destaque na própria linha:** as amostras nos dois temas e no contraste alto, o anel, o mouse, o teclado (o Tab e as setas) e o Narrador; a cor nova no Windows e nos programas abertos.
- **Desfazer a cor pelo Histórico de mudanças,** com uma cor personalizada antes, e com o modo escuro e a cor na barra.
- **O Modo escuro na própria linha com a aparência Automática:** o foco, o Narrador e a rolagem.
- **As frases curtas** nos três idiomas, a 900 de largura, e a frase inteira ao passar o mouse.
- **Os Widgets** desligados numa conta, conferidos em outra.

## Fontes
- [Personalize your Colors in Windows (Suporte da Microsoft)](https://support.microsoft.com/en-us/help/4531350): "Show accent color on Start and taskbar" só com o modo do Windows escuro ou personalizado; a cor automática a partir da tela de fundo.
- [Policy CSP - NewsAndInterests (Microsoft Learn)](https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-newsandinterests): `AllowNewsAndInterests`, "Scope: Device", em `SOFTWARE\Policies\Microsoft\Dsh`, valendo para os Widgets inteiros.
- [Toggle switches (Microsoft Learn)](https://learn.microsoft.com/en-sg/windows/apps/design/controls/toggles): a chave para o que vale logo depois da mudança.
- As da R24 e da R38 continuam valendo: os valores das cores, a tela de bloqueio e os botões das caixas de diálogo.
