# WinForge 4.0 — segunda revisão da Busca (R55)

**Data:** 22/11/2026 · **Versão:** Build 4.0 em preparação, depois da R54

**Pedido:** revisar a tela e a função Buscar com cinco olhares:
- **Analista de Produto Sênior:** avalia o todo.
- **Engenheiro de Software Sênior:** revisa o código, refatora, segue as boas práticas, tira o que não serve e melhora o desempenho.
- **Designer Sênior, com um Especialista em UX/UI:** revisam a tela, os botões, os textos e os fluxos; o engenheiro aplica.
- **MVP Windows:** confere se a Busca segue as práticas da Microsoft, se faz da melhor forma o que promete e se é robusta e estável.
- **QA Sênior:** testa tudo o que dá para testar, o óbvio e o que não é; o engenheiro aplica.

**De onde partiu:** a primeira revisão da Busca (R26) foi antes do desenho novo (R37) e da revisão de UX (R38), que deixou dois pontos para ela: a ordem de "limpar" (UX26) e a linha de cima dos ajustes (UX27). Depois dela, as segundas revisões das páginas trouxeram coisas novas para a busca achar, como a cor de destaque na própria linha (R53) e o aviso de versão nova do WinForge (R54). A busca acha os 106 itens, as 13 páginas, a Aparência e os ajustes que existem no Windows aberto (51 dos 53 no Windows 11 24H2), nos três idiomas.

**Resultado:** 10 achados, todos corrigidos.

| Olhar | Achados |
|---|---|
| Produto | 1: as buscas sobre o próprio WinForge ("atualizar winforge", "avisos do winforge", "winforge") traziam outra coisa primeiro |
| Engenharia | 2: a página de cada ajuste procurada de novo para cada um dos 51 na montagem do índice; e o comentário da ordenação prometendo um desempate que o código não fazia |
| Designer e UX/UI | 3: a página achada pelo nome sem o caminho recomendado dela logo depois (a UX26 da R38); "Ajustes do Windows > ajuste" na linha de cima (a UX27); e a dica da caixa com quatro frases, uma delas prometendo o que o Enter nem sempre faz |
| MVP Windows | 2: o leitor de tela lendo o sinal ">" da linha de cima; e a caixa sem dizer o atalho dela ao leitor de tela |
| QA | 2: em inglês, "tweaks" não achava a página Windows tweaks; e o singular de uma palavra valendo como começo de outra ("programas" trazendo o Programador de tareas, em espanhol) |

Nada rodou num Windows de verdade. A conferência foi feita na nuvem, com a busca de verdade sobre os ajustes de cada build (Windows 11 24H2 e 23H2, Windows 10) e com a janela simulada da R37. O que só um PC mostra entrou no roteiro de conferência (§45).

## A Busca hoje

- **A caixa,** no alto da barra lateral: Ctrl+K ou Ctrl+F levam a ela; vazia, mostra "Buscar" e a dica Ctrl K; com texto, o botão de limpar.
- **Enquanto a pessoa digita:** a busca começa na segunda letra, 140 ms depois da última tecla; o Enter não espera.
- **Os resultados,** numa lista de até 30, cada um com de onde vem em cima do nome. O primeiro fica em destaque, com a tecla Enter quando o Enter o abre.
- **A linha sob o título:** quantos resultados, se a busca foi corrigida ou só achou parte das palavras, e o que o Enter faz (abre ou só seleciona).
- **Sem resultado,** quatro buscas sugeridas, como botões: "pc lento", "sem espaço", "internet lenta" e "vírus".
- **O teclado:** a seta para baixo vai aos resultados, a seta para cima na primeira linha volta à caixa, e o Esc volta à página de onde a busca começou.

## Analista de Produto

| # | O que estava | Por que importa | Como ficou |
|---|---|---|---|
| P1 | As buscas sobre o próprio WinForge traziam outra coisa primeiro. "atualizar winforge" trazia **Manter programas na versão atual** (que segura as versões dos programas, o contrário do pedido), e o Enter a abria. "avisos do winforge" trazia a chave **Notificações** do Windows, que desliga os avisos de todos os programas. E "winforge" trazia **Desfazer ajustes do WinForge** (em inglês, a Aparência). | A atualização com um clique é o caminho de cada correção chegar a quem usa (R54), e o monitor é quem avisa. Quem procura o WinForge pelo nome deve chegar às coisas dele. | **Verificar nova versão** e **Monitor na bandeja** têm "winforge" nas palavras de busca, nos três idiomas. "atualizar winforge" e "nova versão do winforge" trazem Verificar nova versão; "avisos do winforge" e "notificações do winforge", o Monitor na bandeja; e "winforge", a página Sobre o WinForge, que o Enter abre (Q1). "atualizar" e "notificações" sozinhos continuam nas Atualizações e nas notificações do Windows. |

**Conferido e mantido:**
- **As quatro buscas sugeridas** continuam trazendo primeiro a ação certa, nos três idiomas.
- **O menu de texto sem busca:** ele é uma lista numerada por página, e o número leva direto ao item. A busca é da janela.
- **O Início pelo nome:** "início" o acha; "iniciar" continua fora dele, porque é de inicialização.

**Para depois:** "nota de saúde" acha só parte das palavras (a Saúde dos discos e a da bateria). A busca leva a páginas, a ações e a partes de página, e a nota é um quadro do Início que não tem um destino próprio. Vale quando o Início tiver um.

## Engenheiro de Software

| # | O que estava | Como ficou |
|---|---|---|
| E1 | Na montagem do índice, cada um dos 51 ajustes procurava de novo a página da categoria dele: `Get-WinForgeTweakPageId` percorre o mapa de páginas, e `Get-WinForgeNavPage` passa as 13 páginas por um `Where-Object`. Eram 102 procuras para 10 categorias, a cada montagem (a janela monta o índice logo depois de abrir). | A página e o título de cada categoria são procurados uma vez por montagem: 10 vezes, e não 51. Na nuvem, a parte dos ajustes passou a levar de 97 a 129 ms, contra 156 a 199 ms antes, e o índice inteiro, de 223 a 272 ms, contra 250 a 287 ms (medianas de oito montagens, em três rodadas). |
| E2 | O comentário de `Search-WinForgeNavigation` dizia que, num empate, vinha primeiro "o caminho recomendado da página", mas a ordenação nunca olhou o destaque (`Accent` nem entrava no índice). O desempate foi testado de verdade nas 4.175 buscas da comparação: ele punha na frente as ações pesadas, no lugar das que só olham. "reiniciar" passava a trazer Instalar atualizações do Windows antes do Reinício pendente, e "erro" e "azul", Reparar o Windows (DISM + SFC), que leva de 20 a 60 minutos. | O comentário diz o que o código faz: nos empates, as páginas, as ações, os atalhos do Windows e os ajustes, na ordem da barra lateral e de cada página, que vai do mais seguro ao que mexe mais fundo. O destaque passa à frente só onde a UX26 pede (D1). |

**Por dentro:**
- **Navigation.psm1:** `Accent` nas entradas do índice e nos resultados; o bônus do destaque da página achada (`WinForgeSearchHighlightBonus`); a página por qualquer palavra do título (`TitleWords` em `Get-WinForgeSearchPageIndex`); o singular como palavra inteira (`New-WinForgeSearchSpecs`); a categoria na linha de cima (`Get-WinForgeSearchContext`); a página de cada categoria guardada em `Get-WinForgeSearchTweakEntries`; "winforge" nas palavras de Verificar nova versão e do Monitor na bandeja.
- **WinForge.Gui.ps1:** o caminho falado com vírgulas em `New-GuiActionRow` (M1).
- **MainWindow.xaml:** a dica da caixa (D3) e o `AcceleratorKey` dela (M2).
- **Traduções:** 5.770 textos (3 novos e 4 que saíram de uso). Nenhuma função nova: 1.331 nos módulos e 201 na janela.

## Designer e Especialista em UX/UI

| # | O que estava | Orientação | Como ficou |
|---|---|---|---|
| D1 | A página achada pelo nome vinha primeiro, mas o caminho recomendado dela, não. "limpar" punha a **Limpeza rápida** em 5º, depois da pasta Downloads e de duas ações do grupo Avançado (a UX26). "atualizar" punha **Atualizar assinaturas do antivírus**, da Segurança, antes de **Instalar atualizações do Windows**; "programas", **Programas pesando agora**, do Desempenho, antes de **Instalar programas essenciais**; e "manutenção", a Manutenção agendada antes do **Otimizar**. O nome que começa com a palavra vale 17, e o destaque, que só tem o radical ("limpeza", de "limpar"), vale 9. | Quem busca o nome de uma página quer a página e, em seguida, o que ela recomenda: o mesmo destaque do alto da página. Um nome exato continua na frente. | O destaque da página achada pelo nome ganha 10 e vem logo depois dela: Limpeza e Limpeza rápida; Atualizações e Instalar atualizações do Windows; Programas e Instalar programas essenciais; Manutenção e Otimizar; Ajustes do Windows e Aplicar ajustes recomendados. O bônus fica abaixo dos 20 do nome exato, vale só para o destaque da página achada e não entra numa busca que achou só parte das palavras. |
| D2 | A linha de cima de cada ajuste achado dizia "Ajustes do Windows > ajuste" ou "Personalização > ajuste": a palavra "ajuste" repetia o que o nome da página já diz (a UX27). | A linha de cima diz onde o resultado está, como um caminho. | "Página > Grupo", o mesmo título do grupo na página: "Ajustes do Windows > Explorador", "Personalização > Cores e transparência". As linhas de ação dentro de um grupo (Cor de destaque, Tela de bloqueio do Windows, Teclas que trocam o idioma do teclado e Notificações e Não incomodar) também. |
| D3 | A dica da caixa tinha quatro frases (165 letras em português): "Buscar ações, atalhos e ajustes (Ctrl+K ou Ctrl+F). Enter abre o primeiro resultado; seta para baixo vai aos resultados; Esc volta. Ctrl+1 a Ctrl+0 abrem as páginas." O Enter nem sempre abre: numa busca corrigida, ou que achou só parte das palavras, com uma ação em primeiro, ele só seleciona, e a linha sob o título diz isso. E o Ctrl+1 a Ctrl+0 é de outra coisa: cada botão da barra lateral já diz o dele ("Limpeza (Ctrl+3)"). | Pouco texto, e só o que vale sempre. | "Buscar ações, atalhos e ajustes (Ctrl+K ou Ctrl+F). Seta para baixo vai aos resultados; Esc volta." (98 letras.) O que o Enter faz continua na linha sob o título, a cada busca. |

O desconto para o grupo Avançado, também proposto na UX26, ficou de fora. Com o destaque logo depois da página, "limpar" traz o Avançado depois da Limpeza rápida e da pasta Downloads, na ordem da página. Um desconto pequeno não mudaria nada; um grande poria o Avançado atrás de ações que nem têm a palavra no nome.

O caminho da linha de cima usa ">", como os caminhos do resto do WinForge ("Manutenção > Histórico de mudanças"), e não o "›" sugerido na R38.

**Conferido e mantido:**
- **O primeiro resultado em destaque,** com a tecla Enter só quando o Enter o abre.
- **A linha de cima pequena e apagada,** em cima do nome, e a frase curta embaixo.
- **"Ir para a página"** em cima de uma página, e o nome da página em cima da Aparência.
- **As buscas sugeridas como botões,** na tela sem resultado.

## MVP Windows

| # | O que estava | Por que importa | Como ficou |
|---|---|---|---|
| M1 | O leitor de tela ouvia a linha de cima como está na tela: "Modo escuro, Personalização > ajuste. Tema escuro…". Com a UX27, todo ajuste achado teria um ">". | No padrão, o JAWS, o NVDA e o VoiceOver leem o sinal ">" ("maior", em português). O caminho vira ruído no meio do nome. | O leitor de tela ouve o caminho com vírgulas: "Modo escuro, Personalização, Cores e transparência. Tema escuro…". Na tela, continua o ">". |
| M2 | A caixa não passava o atalho dela ao leitor de tela. Os botões das páginas passam ("Ctrl+3"), pela propriedade `AcceleratorKey`. | A Microsoft orienta mostrar o atalho de um controle na dica dele, e a Automação da Interface do Usuário tem uma propriedade para o atalho de cada elemento (`AcceleratorKey`), por onde o leitor de tela o conhece. | A caixa tem `AcceleratorKey` "Ctrl+K", como os botões das páginas têm o deles. A dica continua dizendo Ctrl+K e Ctrl+F. |

**Conferido**, com as fontes no fim:
- **Ctrl+F para achar:** é o atalho da Microsoft para achar numa janela, e o WinForge o aceita, com o Ctrl+K. Numa lista com filtro (as perguntas de marcar), o Ctrl+F vai ao filtro, como antes. O F3 da mesma tabela (o próximo resultado) é para achar dentro de um texto; na lista de resultados, as setas fazem isso.
- **O Enter na caixa envia a busca, e o Enter ou o clique num resultado o escolhe:** é o que a Microsoft descreve para uma caixa de busca com sugestões. No WinForge, o Enter na caixa abre o primeiro resultado quando ele achou o que foi digitado; numa busca corrigida ou parcial, só o seleciona.
- **Sem resultado, uma linha dizendo isso:** a Microsoft orienta mostrar que a busca rodou. O WinForge diz "Nada encontrado para '…'" e oferece quatro buscas.
- **Robustez:** um texto colado enorme usa só os primeiros 200 caracteres e 8 palavras; emoji, outros alfabetos e acentos decompostos não quebram a busca; o índice se monta de novo quando os ajustes ainda não tinham sido lidos (R26).

## QA Sênior

**Como foi testado:** uma bateria nova da Busca, 81 conferências em português, 92 em inglês e 90 em espanhol (nos outros dois, mais uma por seção, que procura palavras soltas em português na tela, e as do singular de cada idioma):
- **A ordem (A):** a página e o destaque dela em "limpar", "limpeza", "atualizar", "programas", "ajustes" e "manutenção"; o resto da página na ordem dela; cada item com nome de uma palavra só antes de qualquer outro item; o bônus abaixo do nome exato; nenhum bônus sem a página, numa busca parcial ou para o destaque de outra página; os empates como antes ("reiniciar", "lento").
- **A linha de cima (B):** cada ajuste do Windows 11 24H2 com a página e o grupo certos; nenhum "> ajuste"; as quatro linhas de ação dentro de um grupo; uma ação, uma página e a Aparência como antes; um item sem o campo do grupo.
- **A página por qualquer palavra do título (C):** "tweaks" e "tweak"; "winforge" em minúsculas e maiúsculas, com o Enter abrindo; "windows"; "sobre este pc" ainda em Sobre este PC (R26); o Início fora do radical e achado pelo nome; nada disso com mais de uma palavra; cada palavra de cada título.
- **As buscas sobre o WinForge (D):** oito buscas, de "atualizar winforge" a "idioma do winforge", e "atualizar" e "notificações" sozinhos sem mudar.
- **O singular (E):** "programas" sem o Programador de tareas e a Programación de GPU entre os oito primeiros, mas ainda achados (espanhol); "tasks" com as tarefas antes da barra de tarefas e "drives" com a unidade antes dos drivers (inglês); os plurais de cada palavra dos nomes achando o item.
- **A caixa (F):** a dica e o atalho para o leitor de tela; os botões das páginas como antes; Ctrl+K e Ctrl+F.
- **O índice (G):** a página de cada grupo procurada uma vez; cada ajuste na página certa; o destaque marcado só nos itens com ele; o Windows 10; o tempo de montar o índice e de seis buscas.
- **A janela (W):** "limpar" com a página e a Limpeza rápida, o destaque e o que o leitor de tela ouve do primeiro; a linha de cima de um ajuste e da Cor de destaque, na tela e no leitor de tela; nenhum ">" no que o leitor de tela ouve em quatro buscas; o clique num ajuste achado.
- **Os textos** nos três idiomas.

**Achados**

| # | O que estava | Como ficou |
|---|---|---|
| Q1 | Em inglês, "tweaks" (e "tweak") não achava a página **Windows tweaks**, e o Enter rodava **Tweak profiles**. A busca de uma palavra só olhava a primeira palavra do título ("windows"). Pelo mesmo motivo, "winforge" não achava **Sobre o WinForge** em nenhum idioma, e "windows" achava a página dos ajustes só em inglês. | A busca de uma palavra só acha a página por qualquer palavra do título, nos três idiomas. Com mais de uma palavra, continua pelo começo do título: "sobre este pc" segue em Sobre este PC. |
| Q2 | O singular de uma palavra ("programa", de "programas") valia como começo de outra, com quase o peso do nome. Em espanhol, "programas" trazia **Programador de tareas** e **Programación de GPU** em 4º e 5º, à frente de quase todos os itens da página Programas. Em inglês, "tasks" punha **Taskbar aligned to the left** junto das tarefas. | O singular vale como palavra inteira. No começo de outra palavra, vale como radical (9 no nome): "programas" ainda acha o Programador de tareas, mais abaixo. |

Os testes também acharam os do produto (P1), os da engenharia (E1 e E2), os do designer (D1 a D3) e os do MVP (M1 e M2).

**A ordem antes e depois:** 4.175 buscas comparadas, nos três idiomas (os nomes, as frases, as palavras de busca, os títulos, as listas da R26 e as desta revisão). O primeiro resultado mudou em 18, todas pelo pedido, fora duas: "add remove programs", em inglês, digitado na janela em português ou em espanhol, que só acha parte das palavras. Em português, ela troca os dois primeiros, ambos da página Programas; em espanhol, passa a trazer primeiro Mantenimiento programado (antes, Programas que pesan ahora; nenhum dos dois é o que a pessoa procura). Os três primeiros mudaram em 85.

**Contra o código de antes (R54):** falham 33 das 81 conferências em português, 36 das 92 em inglês e 36 das 90 em espanhol, cada uma de uma correção. As que passam conferem o que foi mantido (os empates, o Início, "sobre este pc", "desinstalar winforge", a linha de cima de uma ação e de uma página, os botões das páginas, o Ctrl+K e o Ctrl+F, cada ajuste na página certa) e os textos.

**23 defeitos de propósito,** e as conferências pegam todos: o destaque sem o bônus, com o bônus para qualquer página, grande demais e pequeno demais; o índice sem o destaque; o desempate a favor do destaque; a página só pela primeira palavra, o Início pelo radical e a página pelas palavras do título numa busca de várias palavras; a linha de cima com "ajuste" e as linhas de um grupo sem o grupo; o ">" no leitor de tela; Verificar nova versão e o Monitor sem "winforge", e a ordem em inglês; o singular como começo de outra palavra (em espanhol e em inglês) e sem o radical; todas as categorias juntas, a página procurada a cada ajuste e os ajustes sem a categoria na palavra de página; a dica de antes e a caixa sem o atalho para o leitor de tela.

**Nada do que funcionava quebrou:** as baterias das 14 páginas revistas, com os mesmos números da R54 (a da Busca da R26 depois da adaptação abaixo; a da Rede da R22 com a mesma conferência antiga do escudo); a das seis funções novas da R36 (257 em cada idioma); as das segundas revisões, do Início ao Sobre o WinForge, com os mesmos números; a do Explorador e da tela de bloqueio da R50; a da Manutenção da R14 e a do Início da R13; as mensagens da janela (72 em cada idioma); instalar, atualizar com um clique, o pacote de suporte e o Setup de verdade, da R54 para esta; cada nome e link citado na documentação técnica; nenhuma função sem uso; o PSScriptAnalyzer com os mesmos 243 avisos, nenhum novo. A bateria da Busca da R26 foi adaptada numa conferência, a da linha de cima de um ajuste (a página e o grupo, no lugar de "> ajuste"), com os mesmos 109, 98 e 101.

## O que só um PC mostra

Isto entrou no roteiro de conferência (§45):
- **A busca com o Narrador:** um ajuste achado ("modo escuro": "Modo escuro, Personalização, Cores e transparência") e o atalho da caixa.
- **A dica da caixa** nos três idiomas.
- **O Enter** em "limpar" (a página Limpeza), em "winforge" (Sobre o WinForge) e, em inglês, em "tweaks" (Windows tweaks).
- **A linha de cima numa janela estreita:** o caminho mais longo ("Ajustes do Windows > Privacidade e sugestões") termina em reticências se não couber.

## Fontes
- [Keyboard accelerators (Microsoft Learn)](https://learn.microsoft.com/en-us/windows/uwp/design/input/keyboard-accelerators): Ctrl+F para achar numa janela e F3 para o próximo resultado; os atalhos na dica de cada controle; atalhos iguais entre os programas do Windows.
- [AutomationProperties.AcceleratorKey (Microsoft Learn)](https://learn.microsoft.com/en-us/uwp/api/windows.ui.xaml.automation.automationproperties.acceleratorkey?view=winrt-26100): a propriedade com o atalho de cada elemento, para a Automação da Interface do Usuário.
- [Auto-suggest box (Microsoft Learn)](https://learn.microsoft.com/en-us/windows/apps/design/controls/auto-suggest-box): o Enter na caixa envia a busca; o Enter, o clique ou o toque num resultado o escolhe; sem resultado, uma linha dizendo isso.
- [How screen readers read special characters: an update (Eleven Ways)](https://elevenways.be/en/articles/screenreaders-special-characters): no padrão, o JAWS, o NVDA e o VoiceOver leem o sinal ">".
- As da R26 continuam valendo.
