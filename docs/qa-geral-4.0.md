# WinForge 4.0 — QA geral (R11)

**Data:** 18/11/2026 · **Versão testada:** Build 4.0 em preparação, branch `b370`, depois da R10 (commit 8d72ad4)

**Pedido:** "Como um QA, faça testes envolvendo cada tela, opção, botão e interface do sistema. Faça testes de massa, de desempenho, de front, de back, de integração, de conferência de dados. Testes pontuais, gerais, tudo. Faça um relatório desses testes e passe para um Engenheiro de Software Sênior corrigi-los da melhor forma."

## Resumo

Nenhuma ação derrubou o WinForge. As 84 ações da navegação rodaram 504 vezes, no console e na janela, cancelando e aceitando cada pergunta, e nenhum erro escapou, nada travou e nenhuma tela de resultado ficou sem título ou com um próximo passo que não existe. Das 83 conferências de tela, código e dados, 80 passaram. As 3 que falharam viraram achados.

Saíram **5 achados (1 médio e 4 baixos) e 1 observação**. Nenhum é alto. O médio é de desempenho: em inglês e em espanhol, o WinForge leva meio segundo a mais para abrir.

| # | Severidade | Área | Achado |
|---|---|---|---|
| Q1 | Média | Desempenho | Em inglês e espanhol, abrir o WinForge leva cerca de 0,55 s a mais que em português, por causa da leitura do arquivo de tradução |
| Q2 | Baixa | Tela | Uma descrição em espanhol passa do que cabe na linha e termina em reticências; 35 descrições em inglês e espanhol passam de 60 letras, o limite que as em português seguem |
| Q3 | Baixa | Busca | 4 itens não têm palavras de busca; "reverter ajustes", "voltar ao normal" e "revert all" não acham Desfazer ajustes, e "logs" em espanhol não acha nada |
| Q4 | Baixa | Documentação | Duas entradas antigas do CHANGELOG falam de QA, testes automatizados e GitHub Actions |
| Q5 | Baixa | Tela | Com o menu Mais opções aberto, clicar de novo no botão fecha e reabre o menu, em vez de fechar (pela leitura do código; só um PC confirma) |
| O1 | Observação | Integração | O aviso de pouco espaço do monitor abre a Limpeza rápida; o Início e o Verificar o PC abrem a Limpeza personalizada |

## Como foi testado

Tudo rodou na nuvem, num Linux com PowerShell 7. **Nada rodou num Windows.** O que depende do Windows foi simulado ou conferido pela leitura do código, e o que só um PC mostra está no fim, para o roteiro de conferência.

- **Front (a janela):** a janela WPF não abre no Linux. Ela foi conferida de forma estática: o XAML, o código da janela pela árvore de sintaxe do PowerShell, os textos de cada tela nos três idiomas, as regras do teclado, o leitor de tela e o contraste das duas paletas.
- **Back (cada ação):** cada uma das 84 ações rodou num processo separado, com o Windows simulado:
  - As pastas do usuário, do Windows e as temporárias apontam para uma pasta descartável.
  - Tudo o que muda o PC foi bloqueado e anotado: apagar, registro, serviços, processos, tarefas, Defender, aplicativos, recursos do Windows, DNS e discos.
  - Programas externos e a internet não rodam.
  - As perguntas foram respondidas de dois jeitos: desistindo de tudo e aceitando tudo.
  - Cada ação rodou como no console e como dentro da janela (com o host da janela criado).
  - Na janela, a faixa de resultado que a pessoa veria foi montada e conferida: título, texto de estado e o botão de próximo passo.
- **Integração:** os caminhos entre as telas foram seguidos. Os destinos citados no código, os cartões do Início, os próximos passos, o histórico de manutenções, o diário de mudanças, a busca e as perguntas da janela foram conferidos. O espaço em disco simulado foi passado pelas três telas que falam dele.
- **Conferência de dados:** a tabela de navegação, os 53 ajustes do Windows, o catálogo de essenciais, as datas de suporte do Windows e as traduções.
- **Massa e bordas:**
  - 2.000 notas de saúde aleatórias, 3.000 tamanhos de arquivo e as bordas de datas e contagens;
  - 30 manutenções e 260 mudanças no histórico;
  - uma pergunta com 2.000 opções;
  - 30 buscas com entradas estranhas;
  - arquivos de dados estragados;
  - 23.040 combinações de teclas.
- **Desempenho:** o tempo de abrir, de montar a navegação, da busca, do Início, da nota de saúde, do resumo e das perguntas grandes.

## Cobertura em números

| O quê | Quantidade |
|---|---|
| Páginas e itens da navegação | 12 páginas, 102 itens (84 ações e 18 telas do Windows) |
| Execuções de ação, com o Windows simulado | 504: 84 ações × desistir/aceitar × console/janela, e a janela de novo, com a faixa de resultado conferida |
| Perguntas respondidas nessas execuções | 273 |
| Mudanças no PC bloqueadas e anotadas | 54 |
| Conferências de tela (front) | 26 |
| Conferências de código | 11, em 6.680 textos traduzidos e 33 formatos |
| Conferências de dados, integração e desempenho | 46 |
| Combinações de teclado | 23.040 |
| Blocos de evento da janela conferidos | 82 |
| Consultas de busca medidas | 157, nos três idiomas |

## Achados

### Q1 — Em inglês e espanhol, abrir o WinForge leva meio segundo a mais

- **Severidade:** média. Não quebra nada, mas é a primeira coisa que quem usa em inglês ou espanhol sente, toda vez que abre.
- **Onde:** `Read-WinForgeTextCatalog`, em `modules/Core.psm1`.
- **O que acontece:** a tradução é lida uma vez por processo, ao carregar os módulos. Para cada linha do arquivo (são mais de 10 mil), o leitor chama uma função para tirar as aspas. Chamar uma função do PowerShell é caro, e isso se repete milhares de vezes.
- **Evidência:** neste ambiente, carregar os módulos leva 0,69 a 0,73 s em português e 1,26 a 1,32 s em inglês ou espanhol. Ler o `en.po` leva de 750 a 950 ms, e o `es.po` de 410 a 500 ms. O monitor e a manutenção agendada também leem o arquivo ao abrir. No Windows PowerShell 5.1, que é mais lento para chamar funções, a diferença tende a ser maior.
- **Esperado:** abrir no mesmo tempo nos três idiomas, ou perto disso.
- **Correção proposta:** tirar as aspas na própria leitura e só chamar a função de decodificar quando a linha tiver barra invertida (`\n`, `\"`...), o que é raro. O protótipo leu os dois arquivos em 189 ms e 78 ms, com o dicionário idêntico. A troca precisa de uma conferência de equivalência com o leitor de hoje, nos arquivos reais e nos casos de borda: fuzzy, contexto, textos em várias linhas, barras e linhas sem aspas.

### Q2 — Descrições longas demais em inglês e espanhol

- **Severidade:** baixa.
- **Onde:** as traduções das descrições curtas dos itens (`lang/en.po` e `lang/es.po`).
- **O que acontece:** a descrição curta fica numa linha só, embaixo do nome do item. O que não cabe termina em reticências. Em português, todas têm até 60 letras.
- **Evidência:**
  - Em espanhol, a descrição de "Contraseña del Wi-Fi" tem 76 letras e passa do que cabe na janela no tamanho mínimo: "Muestra la contraseña de una red Wi-Fi guardada en este PC, solo en pantalla".
  - 12 descrições em inglês passam de 60 letras, com até 70.
  - 23 descrições em espanhol passam de 60 letras, com até 76.
  - Com o texto do Windows maior, cabem menos letras, e essas são as primeiras a cortar.
- **Esperado:** até 60 letras nos três idiomas, como em português.
- **Correção proposta:** reescrever as 35 traduções mais curtas, sem perder o sentido.

### Q3 — Itens que a busca não acha pelo jeito comum de pedir

- **Severidade:** baixa.
- **Onde:** a tabela de navegação (`modules/Navigation.psm1`), as palavras de busca (`-Keywords`).
- **O que acontece:** quatro itens não têm palavras de busca: Aplicar ajustes recomendados, Criar ponto de restauração, Desfazer ajustes do WinForge e Pasta de logs e relatórios. A busca só os acha pelas palavras do nome e da descrição.
- **Evidência:**
  - "reverter ajustes" e "voltar ao normal" não trazem Desfazer ajustes do WinForge.
  - Em inglês, "revert all" traz três ajustes soltos, e não Desfazer ajustes.
  - Em espanhol, "logs" não traz nada, embora a pasta se chame assim no Windows.
  - "backup do sistema" não traz o ponto de restauração.
- **Esperado:** cada item com palavras de busca, nos três idiomas, como os outros 98.
- **Correção proposta:** palavras para os quatro, traduzidas, sem roubar resultados de outros itens. Conferir antes e depois com as buscas acima e com as buscas que já existem.

### Q4 — O CHANGELOG antigo fala de QA, testes e GitHub Actions

- **Severidade:** baixa.
- **Onde:** `CHANGELOG.md`, Build 3.32 ("Uma rodada de QA em todos os fluxos...") e uma Build antiga, em "Correções de compatibilidade" ("removidos os testes automatizados e o workflow do GitHub Actions").
- **O que acontece:** a regra do projeto é que o README e o CHANGELOG não falem de testes nem de automação, e essas duas linhas são de antes da regra.
- **Esperado:** o mesmo conteúdo para quem usa, sem esses termos.
- **Correção proposta:** reescrever as duas frases.

### Q5 — Mais opções: clicar de novo no botão reabre o menu

- **Severidade:** baixa. Precisa de confirmação num PC.
- **Onde:** `Show-GuiMoreMenu` e o botão Mais opções, em `WinForge.Gui.ps1`.
- **O que acontece:** o menu é um `Popup` com `StaysOpen = $false`, que fecha com um clique fora dele. O botão que o abriu fica fora do menu. Um clique nele fecha o menu ao apertar o mouse e abre um menu novo ao soltar. É um comportamento conhecido do WPF.
- **Evidência:** leitura do código. A janela não abre no Linux.
- **Esperado:** o segundo clique no botão fecha o menu, como em qualquer menu do Windows.
- **Correção proposta:** enquanto o menu está aberto, o botão não recebe o clique (`IsHitTestVisible`), que é a solução padrão do WPF. O clique fecha o menu e para aí. Ao fechar, o botão volta ao normal.

### O1 — O monitor e o Início levam a limpezas diferentes

- **Tipo:** observação, sem defeito.
- **O que acontece:** com pouco espaço no disco, o aviso do monitor abre a Limpeza rápida, enquanto o Início e o Verificar o PC abrem a Limpeza personalizada.
- **Evidência:** a conferência D8 passou o mesmo espaço livre simulado pelas três telas, em 8 casos (de 0 a 150 GB livres, e uma leitura inválida). As três concordam em quando avisar.
- **Avaliação:** o texto do aviso diz o que o clique faz: "Clique para fazer uma limpeza rápida". Num aviso perto do relógio, uma ação direta faz sentido. Já o Início e o Verificar o PC mostram o que ocupa espaço e deixam escolher. **Recomendação:** manter.

## O que passou

**Tela (front)**
- Os 68 nomes que o script procura existem no XAML, e todo nome do XAML é usado.
- Os 15 estilos procurados e os recursos trocados pelo script existem, e não há estilo sem uso.
- As 121 páginas, itens e cartões do Início têm ícone que existe, e nenhum usa o ícone genérico.
- Os 82 blocos de evento usam só o que existe na hora do clique.
- Os títulos cabem na barra lateral e os nomes dos itens têm até 48 letras, nos três idiomas.
- As regras do teclado valem nas 23.040 combinações. Ctrl+1 abre o Início e Ctrl+0 a décima página.
- Os botões, inclusive os só com ícone, têm nome para o leitor de tela.
- Nas duas paletas, o texto passa de 4,5:1 e os contornos de controle passam de 3:1.

**Código**
- Os 6.680 textos traduzidos recebem o número certo de valores para os marcadores, e os 33 formatos têm valores suficientes.
- Todas as cores, níveis e tipos de botão usados pela janela existem, também no contraste alto.
- Os resultados, os estados e as faixas usam só tipos válidos.
- Toda pergunta tem padrão, e nenhuma que apaga vem com Sim como padrão.

**Ações (back), nas 504 execuções**
- Nenhum erro escapou e nada travou. A mais lenta levou 2,5 s, sem o Windows de verdade.
- Na janela, nenhuma faixa ficou sem título, e todo próximo passo leva a um item que existe.
- Os erros que aparecem por dentro são do Linux, não do WinForge, e todos caem no tratamento previsto:
  - `Registry.CurrentUser` vazio;
  - o tipo `Windows.Networking` do Windows;
  - a sobrecarga de `Mutex.OpenExisting`;
  - a leitura em segundo plano que depende do registro.

**Integração**
- Os 36 destinos citados no código existem, assim como os dos cartões do Início, dos próximos passos das telas azuis e dos passos de "Deixe o WinForge pronto".
- Com 30 manutenções, o histórico guarda as 20 últimas, e o Início e o histórico mostram o mesmo número liberado.
- Com 260 mudanças, ficam 200, e o Início conta certo as que têm desfazer.
- Um histórico, um diário ou preferências estragados não derrubam o Início.
- O espaço em disco simulado dá o mesmo veredito no Início, no Verificar o PC e no monitor.
- A busca aguenta 30 entradas estranhas e acha os ajustes pelo nome.
- As perguntas da janela montam o plano de cada tipo.

**Dados**
- Os Ids das páginas, dos 102 itens e dos 53 ajustes são únicos.
- Todo comando existe, assim como toda tela do Windows citada.
- Toda categoria de ajuste está numa página, e os perfis citam ajustes que existem.
- Os 19 essenciais têm Id do winget no formato certo, sem repetir.
- As datas de suporte das 11 versões do Windows são válidas e estão em ordem.
- As traduções têm os mesmos marcadores, espaços e quebras do português, e o português não usa "software".

## Desempenho

Medido neste ambiente, que não é um PC com Windows. Vale como comparação entre partes, não como o tempo que a pessoa verá.

| O quê | Tempo | Limite usado |
|---|---|---|
| Carregar os módulos, em português | 0,69 a 0,95 s | — |
| Carregar os módulos, em inglês ou espanhol | 1,26 a 1,32 s | **Q1** |
| Montar a navegação | 35 ms | 500 ms |
| Uma busca (média de 157) | 5,5 a 11,5 ms | 50 ms |
| Resumo do Início, com histórico e diário cheios | 7 a 10 ms | 150 ms |
| Nota de saúde | 0,7 ms | 5 ms |
| Ler 5.000 linhas do resumo | 250 a 315 ms | 3 s |
| Uma pergunta com 2.000 opções, na janela | 1 ms | 1 s |

## O que não dá para testar aqui

Isto vai para o roteiro de conferência num PC:
- a janela aberta de verdade: as telas, o mouse, o foco, as animações, os dois temas e o texto grande;
- o Mais opções da Q5, antes e depois da correção;
- o tempo de abrir em inglês e em espanhol no Windows PowerShell 5.1, antes e depois da Q1;
- as descrições em espanhol na janela no tamanho mínimo;
- as ações que mudam o PC, que aqui foram bloqueadas: limpar, ajustes, serviços, rede, programas e Defender;
- o que depende do Windows: registro, WMI, eventos, winget, Windows Update e BitLocker.

## Passagem para a engenharia

Ordem sugerida, da que mais pesa para a que menos pesa, com o cuidado de cada uma:
1. **Q1.** Trocar o leitor sem mudar o resultado. Conferir que o dicionário sai idêntico ao de hoje, nos dois arquivos reais e num arquivo de bordas. Medir antes e depois.
2. **Q3.** Palavras novas que não tirem outros itens do topo. Rodar as buscas de antes e as do achado nos três idiomas.
3. **Q2.** Traduções mais curtas, com o mesmo sentido e os mesmos termos do resto do WinForge. Uma frase usada em dois itens muda nos dois.
4. **Q5.** A solução padrão do WPF, sem mudar o teclado (Esc e as setas) nem o foco ao fechar.
5. **Q4.** Só o texto.
6. **O1.** Sem mudança.

Depois das correções, rodar de novo todas as conferências desta rodada e as das revisões anteriores, refazer o pacote e conferir a atualização da R10 para a nova.

## Resultado das correções

A engenharia corrigiu os cinco achados na mesma revisão (R11), e as conferências desta rodada foram refeitas depois.

| # | Como ficou | Conferido |
|---|---|---|
| Q1 | `Read-WinForgeTextCatalog` tira as aspas na própria leitura e só chama a função de decodificar numa linha com barra invertida | Os dicionários do `en.po` e do `es.po` saem idênticos aos de antes (5.199 textos cada), assim como os de um arquivo de bordas com fuzzy, contexto, várias linhas, barras, linhas sem aspas, entradas coladas e a última sem linha vazia, em CRLF e em LF. A leitura caiu de 680–950 ms para 80–200 ms. Carregar os módulos em inglês ou espanhol caiu de 1,26–1,32 s para 0,72–0,79 s; em português, 0,62–0,63 s |
| Q2 | As 35 descrições foram reescritas com até 60 letras. A de "Contraseña del Wi-Fi" ficou com 60 | Nenhuma descrição passa de 60 letras nos três idiomas |
| Q3 | Palavras de busca nos quatro itens, nos três idiomas. O ponto de restauração ganhou "proteção do sistema", o nome que o Windows usa | As buscas do achado trazem o item certo em primeiro lugar. Das 2.538 buscas comparadas antes e depois (cada nome, título e palavra de busca, nos três idiomas), 77 mudaram, e cada mudança foi revista. Duas palavras que tiravam outros itens do lugar saíram: "reset", em inglês, que continua levando a Restaurar este PC, e "erros", que continua levando aos diagnósticos |
| Q4 | As duas frases foram reescritas sem esses termos | O README e o CHANGELOG não falam mais de QA, testes automatizados nem GitHub Actions |
| Q5 | Enquanto o menu está aberto, o botão não recebe o mouse. Ele volta a receber ao fechar, antes de ganhar o foco | Conferido no código: a ordem das duas trocas, e Esc e o clique num item continuam fechando. **O clique de verdade só um PC confirma** |
| O1 | Sem mudança | — |

Depois das correções, passaram:
- as 83 conferências desta rodada (26 de tela, 11 de código e 46 de dados);
- as 80 conferências novas das correções nos três idiomas;
- as das revisões anteriores: as 59 da R9, as 52 da R10, as 66 e as 28 da primeira revisão de QA e as 26 da R7;
- o motor de instalação, a atualização simulada, o pacote de suporte, as traduções (5.199/5.199) e as 159 referências nos três idiomas;
- nenhuma chamada com parâmetro inexistente e nenhuma função sem uso (1.415 funções), e nenhum aviso novo do analisador do PowerShell.
