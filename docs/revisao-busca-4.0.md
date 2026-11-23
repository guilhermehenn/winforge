# WinForge 4.0 — revisão da Busca (R26)

**Data:** 20/11/2026 · **Versão:** Build 4.0 em preparação, depois da R25

**Pedido:** juntar quatro olhares para a tela e a função de Buscar:
- **Analista de UX/UI Sênior (designer):** revisa cada detalhe da interface e orienta o engenheiro.
- **Especialista Microsoft (MVP Windows):** confere se os comandos e as alterações no Windows são feitos da melhor forma disponível hoje, de modo seguro e robusto, e se fazem sentido e mudam o que devem no PC.
- **QA Sênior:** testa todas as funções da tela.
- **Engenheiro de Software Sênior:** aplica as correções.

**Resultado:** 13 achados, todos corrigidos.

| Olhar | Achados |
|---|---|
| Designer | 3: o Idioma achado na busca abria a pergunta do menu de texto, e não o cartão; "sem espaço", uma das buscas sugeridas, trazia primeiro um relatório e o Apagar o espaço livre; a dica da caixa falava de cartões |
| MVP Windows | 4: os comandos que os técnicos digitam (eventvwr, winver), os nomes do Windows (Visualizador de Eventos, Restaurar PC, Restablecer este equipo), os aplicativos que o WinForge remove (Office, Copilot, Outlook) e "copia de seguridad" não achavam a tela certa |
| QA | 6: em inglês, a correção de digitação nunca funcionava; a busca mostrava o que a página tira; o cartão Idioma podia mostrar a escolha antiga; "about this pc" trazia outra página; "desinstalar winforge" trazia os restos de programas; e as buscas do jeito que a pessoa fala ("desligar a telemetria", "pc lenta", "no hay sonido") |
| Engenharia | Nenhum próprio: aplicou os 13. |

A busca só lê: ela não muda nada no Windows. O que ela abre são as ações e os atalhos das páginas, revistos nas R13 a R25. Nada rodou num Windows de verdade. A janela foi simulada, com os elementos dela trocados por objetos simples. O que só um PC mostra entrou no roteiro de conferência.

## A Busca hoje

A caixa fica no alto da barra lateral, com a dica "Buscar" e a tecla Ctrl K. Ctrl+K e Ctrl+F levam até ela. A busca começa na segunda letra e espera a pessoa parar de digitar um instante (140 ms). Os resultados tomam o lugar da página, numa lista:
- **No alto:** o título Busca e o resumo, que diz:
  - quantos resultados há (até 30 na tela);
  - se a busca foi corrigida ("você digitou…") ou achou só parte das palavras;
  - o que o Enter faz.
- **Cada linha:** de onde o resultado vem (a página, ou "Página > ajuste"), o nome e a descrição. A primeira linha tem o fundo de destaque e, quando o Enter a abre, a tecla Enter.
- **Sem resultado:** "Busque pelo que está acontecendo com o PC ou pelo nome do que procura" e quatro buscas que funcionam, como botões: pc lento, sem espaço, internet lenta, vírus.

O que ela acha:
- **As ações e os atalhos** de todas as páginas, pelo nome, pela descrição, pela frase inteira e por palavras-chave. Inclui os que ficam fora dos cartões, como o Histórico de manutenções e o Idioma.
- **As páginas,** pelo título.
- **A Aparência e o Idioma** de Sobre o WinForge, que são cartões da página, e não ações.
- **Os ajustes do Windows** que existem neste Windows (pela build), que levam à página deles, com o ajuste em destaque.

Como ela acha:
- **As palavras:** sem acento e sem maiúsculas. As palavras de ligação ("o", "meu", "the", "el") não contam.
- **As formas:** o plural e o radical ("limpar" acha "Limpeza"), os sinônimos ("consertar" acha "Reparar") e "wi-fi" igual a "wifi".
- **A correção de digitação:** "limpesa" vira "limpeza". Numa busca corrigida, ou que achou só parte das palavras, com uma ação em primeiro, o Enter só seleciona: nada roda por um palpite.
- **Repetidos:** a mesma ação em duas páginas aparece uma vez.

O teclado:
- Enter abre o primeiro resultado (quando a tecla é solta, e só uma vez); a seta para baixo vai aos resultados, e a seta para cima, da primeira linha, volta à caixa.
- Esc volta à página de onde a busca começou. Com texto e a busca ainda por aparecer, Esc só esvazia a caixa.
- Ctrl+1 a Ctrl+0 abrem as páginas. Com AltGr (Ctrl+Alt, no teclado ABNT2), nada abre.

## Designer (UX/UI)

| # | O que estava | Orientação | Como ficou |
|---|---|---|---|
| D1 | Achado na busca, o Idioma rodava a ação do menu de texto: uma pergunta na tela de execução, sem a oferta de reabrir o WinForge no idioma novo. A Aparência, achada do mesmo jeito, leva ao cartão dela. | O mesmo caminho dos dois: a busca leva ao cartão da página, onde a escolha já mostra o que está marcado. | "Idioma" abre Sobre o WinForge com o foco na escolha marcada do cartão Idioma, como a Aparência. O menu de texto continua com a pergunta. |
| D2 | "sem espaço", uma das quatro buscas sugeridas na tela sem resultado, trazia primeiro Discos e espaço livre (um relatório) e, em terceiro, Apagar o espaço livre, que não libera espaço. | A sugestão leva ao que resolve. | Limpeza rápida primeiro, também em "no space" e "sin espacio". |
| D3 | A dica da caixa dizia "seta para baixo vai aos cartões". Desde a R9, os resultados são uma lista. | A palavra da tela. | "…vai aos resultados", nos três idiomas. |

**Conferido e mantido:**
- **o resumo:** diz quantos resultados há, se a busca foi corrigida ou parcial e o que o Enter faz, e o leitor de tela o anuncia a cada busca;
- **a primeira linha em destaque,** com a tecla Enter só quando o Enter a abre;
- **"Página > ajuste"** acima de um ajuste, para ele não parecer uma ação que roda ao clicar;
- **as quatro buscas sugeridas,** do jeito que a pessoa diria, cada uma trazendo a ação certa em primeiro;
- **o limpar da caixa** fora da ordem do Tab, como nas caixas de busca do Windows: pelo teclado, o Esc faz o mesmo.

## Especialista Microsoft (MVP Windows)

A busca não muda nada no Windows. O que conta aqui é se ela entende o nome que a pessoa conhece do Windows e leva à tela certa.

| # | O que estava | Por que importa | Como ficou |
|---|---|---|---|
| M1 | "eventvwr" e "winver", os comandos que técnicos digitam, não achavam nada. "visualizador de eventos", "event viewer" e "visor de eventos" achavam os Eventos críticos só por parte das palavras. | É como o Windows chama o Visualizador de Eventos (EventVwr.exe, pela Microsoft) e a janela da versão. Os Eventos críticos leem os mesmos registros, e Sobre este PC mostra a versão. | Os quatro levam aos Eventos críticos, e "winver" a Sobre este PC. |
| M2 | "restaurar pc" e "restaurar este pc" traziam primeiro Restaurar a partir de um backup. Em espanhol, "restablecer este equipo" achava só por parte das palavras. | A Microsoft chama a opção de "Restaurar PC" nas Configurações em português, e de "Restablecer PC" e "Restablecer este equipo" em espanhol. É a Recuperação do WinForge que leva até ela. | Os nomes da Microsoft trazem a Recuperação primeiro, nos três idiomas. |
| M3 | "office", "copilot" e "outlook" não achavam Remover aplicativos do Windows ("copilot" só trazia o Recall). | São os aplicativos dessa lista, com o nome que o Menu Iniciar mostra: o Microsoft 365 Copilot (o antigo Office), o Copilot e o Outlook novo. | Os três levam a Remover aplicativos do Windows. |
| M4 | Em espanhol, "copia de seguridad" não trazia a Copia antes de formatear. | É como o espanhol chama o backup; a tela se chama só "Copia". | Traz primeiro. |

**Conferido e mantido**
- **Os ajustes na busca são os deste Windows:** no Windows 10, nenhum só do Windows 11; o Recall, da 24H2 em diante; o botão do Copilot, só até a 23H2.
- **O índice é montado uma vez,** um pouco depois de a janela aparecer, e cada tecla só compara textos prontos (5 a 20 ms). Um texto colado enorme vale pelos primeiros 200 caracteres e 8 palavras.
- **Nada roda por um palpite:** numa busca corrigida ou parcial com uma ação em primeiro, o Enter só seleciona; uma página ou um ajuste abrem, porque só levam a uma página.

## QA Sênior

**Como foi testado:** a busca rodou nos três idiomas, com a build do Windows e a janela simuladas: 109 conferências em português, 98 em inglês e 101 em espanhol.
- **O texto digitado:**
  - acentos, maiúsculas, texto colado com acento solto e caractere invisível, pontuação;
  - uma letra, só símbolos, um texto colado de 5 mil caracteres (sem travar), emoji e outro alfabeto, palavra repetida, texto sem sentido e repetidos;
  - o vocabulário e três erros de digitação em cada idioma.
- **O resumo:** 1, 4 e 45 resultados, sem resultado, uma letra, corrigida e parcial, e uma busca longa abreviada sem partir um emoji.
- **O Enter:** abre, ou só seleciona numa busca corrigida ou parcial.
- **As teclas:** Ctrl+K e Ctrl+F, o filtro de uma lista, AltGr, Ctrl+1 e Ctrl+0, Esc em quatro situações e F5.
- **O que vem primeiro:** 40 buscas em português, 25 em inglês e 28 em espanhol, do jeito que a pessoa digita.
  - Os sintomas ("pc lento", "tela azul"), os nomes do WinForge e os do Windows ("Gerenciador de Tarefas", "Teclas de Aderência").
  - Os comandos ("eventvwr", "winver").
  - As quatro buscas sugeridas.
- **Cada nome acha a si mesmo:** cada ação, atalho e página (pelo destino, quando a mesma ação está em duas páginas) e cada ajuste do Windows.
- **A build:** o Windows 11 23H2 e o Windows 10.
- **A tela de resultados, com a janela simulada:**
  - o título, o resumo, a primeira linha e de onde vem cada uma;
  - com outro antivírus, sem bateria, num notebook e antes de o Início ler o PC;
  - as páginas Segurança e Diagnóstico com os mesmos itens tirados;
  - sem resultado (as quatro sugestões), uma letra, mais de 30 resultados e uma busca corrigida;
  - o Idioma e a Aparência levando aos cartões, uma ação rodando, e o cartão Idioma depois de a escolha mudar fora dele.
- **A caixa:** a dica e o nome para o leitor de tela nos três idiomas, e o limite de 200 letras igual ao da busca.
- **Os textos:** nenhum marcador `{0}` sobrando e nenhum texto do português na tela em inglês e em espanhol.
- **A pontuação, antes e depois:** todos os nomes, descrições, palavras-chave e títulos, mais as buscas desta revisão (1.355 em português, 1.268 em inglês e 1.362 em espanhol), comparados com o código de antes.
  - Em português, mudou o primeiro resultado de 13. Em espanhol, de 14. Cada mudança é uma das correções, ou uma busca em outro idioma.
  - Em inglês, mudou o de 25: as correções e 18 buscas em português ou em espanhol, que agora passam pela correção de digitação, como já passavam nos outros dois idiomas.

**Achados**

| # | O que estava | Como ficou |
|---|---|---|
| Q1 | Em inglês, a correção de digitação nunca funcionava: "defnder" e "cleanpu" não achavam nada. O índice em inglês tem a palavra "keys" (de "Sticky keys"), e o vocabulário da correção, guardado com as palavras como chaves, devolvia o peso dela no lugar da lista de palavras: ficava com uma palavra só. | O vocabulário lê as chaves de um jeito que nenhuma palavra esconde. "defnder" vira "defender", "cleanpu" vira "cleanup". |
| Q2 | A busca mostrava o que a página tira: a Saúde da bateria num PC sem bateria, e as ações do Windows Defender (Verificar vírus e as outras) com outro antivírus protegendo o PC. | A busca tira o mesmo, pela mesma regra das páginas, e o resumo conta só o que aparece. |
| Q3 | O cartão Idioma mostrava a escolha de quando a janela abriu. Mudada pelo menu de texto (ou pela busca, antes de D1), a marcada era a antiga, e clicar nela não fazia nada. | O cartão relê a escolha guardada cada vez que aparece. |
| Q4 | "about this pc", em inglês, trazia a página About WinForge antes de About this PC: a busca de uma palavra só ("about", sem as de ligação) achava a página pelo começo do título. | A página pelo começo do título só numa busca de uma palavra de fato. About this PC vem primeiro. |
| Q5 | "desinstalar winforge" (e "uninstall winforge") trazia primeiro Restos de programas. | Versão e pastas primeiro: é onde a tela diz como desinstalar. |
| Q6 | Buscas do jeito que a pessoa fala achavam só parte das palavras, ou outra coisa: "desligar a telemetria", "ligar o modo escuro", "apagar notificaciones", "no hay sonido", "restaurar este pc". Em espanhol, "pc lenta" e "pc congelada" (a PC, no feminino, como na América Latina) não traziam o Otimizar nem o Acelerar. | Ligar e desligar valem como ativar e desativar (apagar e encender em espanhol), e cada ajuste é achado por eles. "este" e "hay" são palavras de ligação, e "lenta" e "congelada" estão nas palavras-chave em espanhol. |

As 65 conferências das correções falham no código de antes e passam no de agora.

## Engenharia

**Por dentro**
- **Navigation.psm1:**
  - `Test-WinForgeNavItemHidden` (nova): o que a janela tira das páginas e da busca neste PC;
  - `Get-WinForgeSearchCardItem` leva o Idioma ao cartão (`WinForgeSearchCardSections`);
  - o vocabulário da correção com `get_Keys()`;
  - a página pelo começo do título só numa busca de uma palavra;
  - as palavras de ligação ("este", "hay") e os sinônimos (ligar e desligar; apagar e encender; o feminino em espanhol);
  - os verbos de chave nos ajustes, com o menor peso;
  - as palavras-chave de Versão e pastas, dos Eventos críticos, de Sobre este PC, da Recuperação, de Remover aplicativos do Windows e da Limpeza rápida.
- **WinForge.Gui.ps1:**
  - `Get-GuiHiddenItemState` (nova): o que o Início leu;
  - `Show-GuiListPage` e `Show-GuiSearchResults` tiram os mesmos itens;
  - `Invoke-GuiNavItem` leva o foco à escolha do cartão Idioma;
  - `New-GuiLanguageCard` relê a escolha guardada.
- **gui/MainWindow.xaml:** a dica da caixa.
- **Traduções:** 8 novas e 7 que saíram de uso, mais três palavras-chave revistas em espanhol; 5.347 ao todo.

**Conferido na nuvem**
- **As conferências novas da Busca, todas passando:** 109 em português, 98 em inglês e 101 em espanhol.

  Cada conferência das correções falha no código de antes e passa no de agora.
- **As 84 ações rodaram de novo 336 vezes** com o Windows simulado: nenhum erro escapou, e o resultado é o mesmo da R25.
- **As de antes continuam passando:**
  - as 164, 169 e 169 do Sobre o WinForge, cuja simulação da página passou a carregar a função nova da janela (`Get-GuiHiddenItemState`);
  - as 265, 270 e 270 da Personalização, as 412, 422 e 422 dos Ajustes do Windows, as 144, 153 e 153 da Rede, as 106, 115 e 115 dos Programas, as 110, 117 e 117 das Atualizações, as 112, 119 e 119 do Reparo, as 96, 102 e 102 do Desempenho, as 178, 187 e 187 da Limpeza, as 134, 142 e 142 da Segurança e as 212, 224 e 224 do Diagnóstico;
  - as 245, 247 e 252 da Manutenção e as 241 do Início nos três idiomas;
  - as 83 do QA geral, as 80 da R11 (com as buscas que não podiam mudar) e as 60 da R12;
  - as 59 da R9 e as 52 da R10;
  - as 66 da QA, as 28 da integração e as 26 da R7;
  - o motor de instalação, a atualização simulada e o Setup de verdade (da R25 para esta), e o pacote de suporte;
  - as traduções (5.347/5.347), as 159 referências nos três idiomas e a busca dos 102 itens;
  - nenhuma chamada com parâmetro que não existe, nenhuma função sem uso e nenhum aviso novo do analisador.

## O que só um PC mostra

Isto entrou no roteiro de conferência:
- **O Idioma pela busca:** o foco na escolha marcada do cartão, e a oferta de reabrir ao escolher outro.
- **A busca num PC de mesa e com outro antivírus:** sem a Saúde da bateria e sem as ações do Defender.
- **A busca em inglês com um erro de digitação:** a correção e o resumo.
- **A sugestão "sem espaço":** a Limpeza rápida primeiro.
- **O cartão Idioma depois de mudar o idioma pelo menu de texto.**

## Fontes
- [Windows Event Log — Event Viewer](https://learn.microsoft.com/es-es/previous-versions/aa382610(v=vs.85)) (Microsoft): o Visualizador de Eventos é o EventVwr.exe.
- [Restaurar o computador](https://support.microsoft.com/pt-BR/windows/experience/backup-recovery/reset-your-pc) (Microsoft, em português): o botão "Restaurar PC" nas Configurações.
- [Restablecer el PC](https://support.microsoft.com/es-es/windows/restablecer-el-pc-0ef73740-b927-549b-b7c9-e6f2b48d275e) (Microsoft, em espanhol): "Restablecer PC" nas Configurações e "Restablecer este equipo" na recuperação.
