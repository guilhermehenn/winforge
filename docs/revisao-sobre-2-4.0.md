# WinForge 4.0 — segunda revisão do Sobre o WinForge (R54)

**Data:** 22/11/2026 · **Versão:** Build 4.0 em preparação, depois da R53

**Pedido:** revisar a tela e a função Sobre o WinForge com cinco olhares:
- **Analista de Produto Sênior:** avalia o todo.
- **Engenheiro de Software Sênior:** revisa o código, refatora, segue as boas práticas, tira o que não serve e melhora o desempenho.
- **Designer Sênior, com um Especialista em UX/UI:** revisam a tela, os botões, os textos e os fluxos; o engenheiro aplica.
- **MVP Windows:** confere se o Sobre o WinForge segue as práticas da Microsoft, se cada função faz da melhor forma o que promete e se é robusta e estável.
- **QA Sênior:** testa tudo o que dá para testar, o óbvio e o que não é; o engenheiro aplica.

**De onde partiu:** a primeira revisão do Sobre o WinForge (R25) foi antes do desenho novo (R37), da revisão de UX (R38) e das faixas do alto das outras páginas (R41 a R48). A página reúne o que é do próprio WinForge: a versão e as atualizações, o atalho, o monitor na bandeja, o pacote de suporte, a aparência e o idioma.

**Resultado:** 10 achados, todos corrigidos.

| Olhar | Achados |
|---|---|
| Produto | 1: a versão nova só aparece para quem abre a página e clica em Verificar nova versão |
| Engenharia | 2: cada atalho lido duas vezes pelo COM a cada vez que a página é desenhada; e a última versão consultada, perdida depois de cada consulta |
| Designer e UX/UI | 4: o subtítulo como lista de oito assuntos (a UX18 da R38); a Aparência e o Idioma pelo teclado, com uma parada do Tab em cada opção; as perguntas com Sim e Não (a UX21); e o resumo repetindo o que a barra lateral diz |
| MVP Windows | 1: o aviso de uma tela azul nova e o do teste de memória repetindo o balão a cada 15 segundos |
| QA | 2: o título "Avisos pausados" em português nos três idiomas (a UX25); e o atalho da outra conta no resumo, quando o WinForge está aberto com a conta de outro Administrador |

Nada rodou num Windows de verdade. A conferência foi feita na nuvem com o Windows simulado da R25 (o registro, as pastas e os arquivos do atalho, o instalador, a sessão, o GitHub e o monitor) e com a janela simulada da R37. O que só um PC mostra entrou no roteiro de conferência (§44).

## O Sobre o WinForge hoje

A página fica no rodapé da barra lateral. De cima para baixo:
- **O resumo:** a versão (e se há uma mais nova, pelo que a última consulta viu), onde está o atalho e a instalação; quando é o caso, o ícone que falta, a falta de Administrador, a conta de outro Administrador e as permissões da pasta.
- **Criar atalho do WinForge,** em destaque, quando falta o atalho (R25).
- **Aparência:** automática, clara ou escura, na hora.
- **Idioma:** automático, português, inglês ou espanhol, ao abrir de novo.
- **Versão e dados:** Versão e pastas, Verificar nova versão, Conferir dados online, Pasta de logs e relatórios e Pacote de suporte.
- **Integração com o Windows:** Criar atalho do WinForge (com o atalho pronto) e Monitor na bandeja.

## Analista de Produto

| # | O que estava | Por que importa | Como ficou |
|---|---|---|---|
| P1 | A versão nova só aparecia para quem abria Sobre o WinForge e clicava em Verificar nova versão. O resumo dizia só "4.0", sem dizer se era a mais recente. | A 4.0 é a versão para divulgar, e a atualização com um clique é o caminho de cada correção chegar a quem usa. Sem aviso, quase ninguém atualiza. O monitor já vai ao GitHub, uma vez por semana, pela lista de programas essenciais. | O monitor na bandeja confere a última versão publicada no máximo uma vez a cada 20 horas, nunca numa conexão limitada ou na bateria. Avisa com um balão uma vez por versão: "WinForge 4.1 disponível". O clique abre Verificar nova versão, que só consulta e pergunta antes de baixar. Depois do balão, o aviso fica no menu do ícone até a atualização. No alto da página, a linha Versão diz "4.0; a versão 4.1 está disponível", em amarelo, e leva a Verificar nova versão. Em dia, com uma consulta de até 30 dias, diz "4.0, a mais recente". Verificar nova versão guarda o que viu. Uma consulta sem internet não apaga o que já se sabia. |

**Conferido e mantido:**
- **A atualização continua pedida pela pessoa:** o monitor só avisa. Baixar e instalar continuam em Verificar nova versão, com as perguntas e a conferência do SHA-256 da R25.
- **Sem aviso de versão para quem não liga o monitor:** a página diz o que a última consulta viu, e o monitor é o passo da configuração inicial.
- **Versão e pastas,** com o que quem ajuda precisa saber (a pasta, o PowerShell, as pastas de dados e cada atalho).

## Engenheiro de Software

| # | O que estava | Como ficou |
|---|---|---|
| E1 | A página desenhada perguntava duas vezes por cada atalho (o resumo e o destaque de Criar atalho), e cada pergunta abria o `.lnk` pelo COM (`WScript.Shell`). O Início e a troca de tema perguntavam de novo. Só a identidade da barra de tarefas era guardada. | `Read-WinForgeShortcutCached` guarda o destino e a identidade de cada atalho enquanto o arquivo não muda, pela data e pelo tamanho. A página lê cada atalho uma vez; desenhada de novo, nenhuma leitura. Um atalho regravado é lido de novo, e um que não pôde ser lido não fica guardado. Substitui `Get-WinForgeShortcutAppIdCached`. |
| E2 | Cada consulta ao GitHub se perdia: o resultado de Verificar nova versão não ficava em lugar nenhum. | `Save-WinForgeUpdateCheck` guarda a última publicada e a hora, e é usada por Verificar nova versão e pelo monitor. `Get-WinForgeKnownUpdate` diz o que se sabe, sem internet, comparando com a versão aberta: depois de atualizar, a guardada deixa de ser nova sozinha. |

**Por dentro:**
- **Launcher.psm1:** `Get-WinForgeAboutShortcutRow` (nova, a linha do atalho fora do resumo) e `Read-WinForgeShortcutCached`; o resumo de `Get-WinForgeAboutPageStatus`. O menu de texto do Idioma tira os nomes dos idiomas da lista do cartão, e não de uma segunda lista.
- **AppUpdate.psm1:** `Save-WinForgeUpdateCheck` e `Get-WinForgeKnownUpdate` (novas); os verbos nas perguntas.
- **Agent.psm1:** a conferência `winforge`; os avisos `Quiet` (no menu, sem balão); o aviso de uma vez por leitura (M1); `app.update` nas ações que a janela aceita do monitor.
- **Reports.psm1:** o verbo na pergunta do pacote de suporte.
- **WinForge.Agent.ps1:** o título da pausa traduzido e a descrição das conferências.
- **WinForge.Gui.ps1:** `Set-GuiChoiceGroupKeyboard` (nova), para a Aparência, o Idioma e as amostras da cor de destaque; a Aparência marcada não refaz a página.
- **Navigation.psm1:** o subtítulo.
- **Traduções:** 5.771 textos (8 novos e 2 que saíram de uso). Entraram três funções nos módulos (1.331) e uma na janela (201).

## Designer e Especialista em UX/UI

| # | O que estava | Orientação | Como ficou |
|---|---|---|---|
| D1 | O subtítulo era uma lista: "Versão e atualizações, suporte, atalho, logs, monitor na bandeja, dados online, aparência e idioma." São oito assuntos, no maior subtítulo dos três idiomas (99 letras; 122 em espanhol). | Uma frase curta, como nas outras páginas (a UX18 da R38). | "A versão, o suporte e as preferências do WinForge." Até 60 letras nos três idiomas. |
| D2 | A Aparência e o Idioma tinham uma parada do Tab em cada opção (sete ao todo). Clicar na Aparência já marcada refazia a página e gravava de novo. As amostras da cor de destaque (R53) davam a volta do fim para o começo com as setas. | Cada um é um grupo de opções do Windows: o Tab entra na escolha marcada, e as setas andam pelas opções sem dar a volta. A escolha marcada não faz nada. | Os três grupos (Aparência, Idioma e as amostras da cor) seguem a mesma regra (`Set-GuiChoiceGroupKeyboard`), com o nome do grupo para o leitor de tela. A Aparência marcada não faz nada, como o Idioma e as amostras. |
| D3 | As perguntas da página diziam Sim e Não: baixar a versão nova, instalar agora, mostrar o arquivo baixado e mostrar o pacote de suporte. | O botão diz o que faz (a UX21 da R38), como nas outras páginas desde a R42. | **Baixar** e **Agora não**; **Instalar agora** e **Depois**; **Mostrar** e **Agora não** (nas duas). No menu de texto, continuam com S/N. |
| D4 | O resumo dizia "Administrador: esta janela está aberta como Administrador" sempre. A barra lateral já diz isso, logo abaixo de Sobre o WinForge. | O resumo diz o que a página não diz em outro lugar. | A linha do Administrador só aparece sem ele, em amarelo, com o que muda. Com o Administrador (o normal), o resumo tem a versão, o atalho e a instalação. |

**Conferido e mantido:**
- **A linha da versão nova como as das outras páginas:** o botão com a seta, o fundo sob o mouse e o leitor de tela dizendo para onde ela leva ("Abre: Verificar nova versão").
- **Criar atalho em destaque só quando falta o atalho** (R25).
- **Cada idioma escrito nele mesmo** no cartão Idioma.

## MVP Windows

| # | O que estava | Por que importa | Como ficou |
|---|---|---|---|
| M1 | Um aviso de uma vez do monitor (uma tela azul nova, o resultado do teste de memória) voltava a cada volta do relógio, a cada 15 segundos, até a conferência seguinte tirá-lo: até uma hora de balões repetidos, na tela e na central de notificações. O intervalo "0" queria dizer uma vez, mas era lido como "sempre". | A Microsoft orienta mostrar uma notificação de evento uma vez, quando ele acontece, e diz que notificações repetidas demais são o que mais incomoda. | O balão aparece uma vez por leitura que traz o aviso. Só uma leitura mais nova, com o aviso de novo (outra tela azul), mostra outro. Os avisos com intervalo (o disco, a proteção) continuam como estavam. A versão nova usa a mesma regra: um balão por versão, como a Microsoft orienta para uma tarefa opcional (no máximo uma vez por dia, até três vezes). |

**Conferido**, com as fontes no fim:
- **A consulta do monitor respeita a conexão limitada:** numa conexão limitada, a Microsoft orienta adiar o que não é urgente e não buscar dados por antecipação. O monitor não consulta o GitHub nem baixa a lista de programas numa conexão limitada ou na bateria, e a versão guardada continua valendo.
- **A versão da API do GitHub, sem o cabeçalho:** o GitHub recomenda dizer a versão da API (`X-GitHub-Api-Version`). Diz também que um pedido sem o cabeçalho usa a 2022-11-28 e passa à versão seguinte quando ela sai de uso, e que um pedido com uma versão encerrada recebe "410 Gone" (a 2022-11-28 vai até 10/03/2028). Uma cópia instalada não troca o próprio cabeçalho a tempo. Por isso o WinForge continua sem ele: a consulta não quebra quando a versão sai de uso. O que ele lê (`tag_name`, `assets`, `digest`, `html_url`, `published_at`, `body`) foi conferido na R25.
- **O teclado dos grupos:** a Microsoft descreve um grupo de opções assim: o Tab entra na escolha marcada (sem nenhuma, na primeira), as setas andam pelas opções e o grupo não dá a volta do fim para o começo. No WinForge, as setas só movem o foco, e Espaço ou Enter escolhe: escolher muda o tema na hora, troca a cor do Windows ou pergunta se reabre a janela.
- **O restante da R25 continua valendo:** o atalho com a identidade da barra de tarefas, a entrada em Run do monitor e o SHA-256 publicado pelo GitHub para cada arquivo.

## QA Sênior

**Como foi testado:** uma bateria nova do Sobre o WinForge, 81 conferências em português e 87 em inglês e em espanhol (nos outros dois, mais uma por seção: nenhuma palavra solta em português na tela).
- **O resumo (A):** o subtítulo; as três linhas com o Administrador; a versão sem consulta, com uma nova, com uma nova antiga, em dia, em dia há mais de 30 dias, com a data no futuro, mais velha que esta e com um valor que não se entende; sem o Administrador; com a conta de outro Administrador (sem a linha do atalho e sem ler os atalhos dela); o atalho desta pasta, o de outra pasta, sem o ícone e o atalho que não pôde ser lido.
- **O monitor (B):** a conferência na lista; a primeira consulta, guardada; o balão e o clique; a leitura seguinte sem consultar e sem balão; o aviso calado no menu e no texto do ícone; a consulta depois de 20 horas e a versão seguinte; a conexão limitada e a bateria; em dia; o GitHub fora do ar; depois de atualizar; os avisos de uma vez (a primeira volta, a seguinte, 59 minutos depois e uma leitura nova); os avisos com intervalo e a pausa; o título da pausa traduzido.
- **Verificar nova versão e o pacote de suporte (C):** os botões das quatro perguntas; a consulta guardada com a versão nova, em dia e sem internet; o resto do caminho como antes.
- **O código (D):** cada atalho lido uma vez, desenhada de novo sem leitura, o atalho regravado lido de novo, o que não pôde ser lido tentado de novo; o atalho de antes continua pedindo para ser atualizado; os nomes dos idiomas e o lugar só para a última versão.
- **A janela (K):** a Aparência e o Idioma como grupos (o Tab, as setas e o nome para o leitor de tela); as amostras da cor sem dar a volta; a Aparência marcada que não refaz a página e a outra que refaz; o subtítulo; o resumo sem a linha do Administrador e com ela; a linha da versão nova como botão, com o leitor de tela e o clique.
- **Os textos** nos três idiomas.

**Achados**

| # | O que estava | Como ficou |
|---|---|---|
| Q1 | O título do balão "Avisos pausados", quando a pessoa pausa os avisos pelo menu do ícone, estava escrito direto no `WinForge.Agent.ps1`, sem passar pela tradução: aparecia em português nos três idiomas (a UX25 da R38). | O título passa pela tradução. A bateria procura, no monitor, qualquer título de balão fora dela. |
| Q2 | Aberto com a conta de outro Administrador, o resumo dizia "Atalho: ainda não criado; use Criar atalho do WinForge", mas lia a Área de Trabalho e o Menu Iniciar dessa conta. E Criar atalho, nesse caso, não grava nada (o atalho iria para a outra conta). | Com outra conta, a linha do atalho sai, e os atalhos dessa conta nem são lidos. A linha Conta continua dizendo que atalhos, pastas e monitor são os dessa conta. |

Os testes também acharam os do produto (P1), os da engenharia (E1 e E2), os do designer (D1 a D4) e o do MVP (M1).

**Contra o código de antes (R53):** 47 das 81 conferências falham, cada uma de uma correção. As 34 que passam conferem o que foi mantido (a versão sozinha sem consulta, o Administrador e a Conta quando aparecem, o atalho, os avisos com intervalo, a pausa, o caminho de Verificar nova versão, o pacote de suporte) e os marcadores de texto.

**42 defeitos de propósito,** e as conferências pegam todos: a versão nova sem levar a Verificar nova versão e sem aparecer; "a mais recente" sem olhar a data e de anos atrás; a consulta com a data no futuro; qualquer versão diferente como nova; a linha do Administrador sempre; o atalho com outra conta; o atalho lido toda vez, nunca lido de novo, o que não pôde ser lido guardado e o destino e a identidade misturados; o idioma pelo código; Verificar nova versão sem guardar e apagando sem internet; os quatro botões sem o verbo; o monitor sem a conferência, com ela na volta do relógio, consultando na conexão limitada, na bateria, a cada leitura e nunca de novo; o balão a cada leitura e sem guardar a versão avisada; o aviso calado como balão; o aviso de uma vez a cada volta e nunca de novo; o clique sem destino e a janela recusando o pedido; "Avisos pausados" fora da tradução; o subtítulo como lista; a Aparência e o Idioma sem o teclado do grupo; as setas dando a volta; o Tab sempre na primeira; as amostras fora da regra; a Aparência marcada refazendo a página; e os grupos sem nome.

**Nada do que funcionava quebrou:** as baterias das 14 páginas revistas, com os mesmos números da R53; a das seis funções novas da R36 (257 em cada idioma); as das segundas revisões do Início à Personalização, com os mesmos números; a da Manutenção da R14 e a do Início da R13; as mensagens da janela (72 em cada idioma); instalar, atualizar com um clique, o pacote de suporte e o Setup de verdade, da R53 para esta; nenhuma função sem uso; o PSScriptAnalyzer com os mesmos 243 avisos, nenhum novo. Três baterias antigas foram adaptadas ao que mudou de propósito: a do Sobre o WinForge (R25), no resumo sem a linha do Administrador; a da Personalização (R53), nas amostras sem dar a volta; e a da Busca (R26), que passou a carregar a função nova do teclado dos grupos.

## O que só um PC mostra

Isto entrou no roteiro de conferência (§44):
- **O aviso da versão nova:** com uma versão de teste publicada, o balão uma vez, o clique abrindo Verificar nova versão e o aviso no menu do ícone; nada numa conexão limitada.
- **A linha da versão no resumo,** antes e depois de Verificar nova versão.
- **Um aviso de uma vez:** uma tela azul nova (numa máquina virtual, com o NotMyFault) vira um balão só.
- **A Aparência e o Idioma pelo teclado e com o Narrador.**
- **Os botões novos** nos três idiomas.

## Fontes
- [Notifications (Microsoft Learn, Windows desktop UX guidelines)](https://learn.microsoft.com/windows/win32/uxguide/mess-notif): um evento, uma vez; uma tarefa opcional, no máximo uma vez por dia, até três vezes; notificações repetidas demais são o que mais incomoda.
- [How to manage metered network cost constraints (Microsoft Learn)](https://learn.microsoft.com/en-us/previous-versions/windows/apps/hh750310(v=win.10)): numa conexão limitada, adiar o que não é urgente e não buscar dados por antecipação; em roaming, suspender o que é de fundo.
- [Radio buttons (Microsoft Learn)](https://learn.microsoft.com/en-my/windows/apps/develop/ui/controls/radio-button): o Tab entra na opção marcada; as setas andam pelas opções; o grupo não dá a volta.
- [API versions (GitHub Docs)](https://docs.github.com/en/rest/about-the-rest-api/api-versions): o cabeçalho `X-GitHub-Api-Version`, a versão padrão sem ele e o 410 de uma versão encerrada.
- As da R25 e da R38 continuam valendo: a entrada em Run, a identidade da barra de tarefas, a última versão publicada e o SHA-256 de cada arquivo.
