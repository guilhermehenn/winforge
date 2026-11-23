# WinForge 4.0 — segunda revisão do Otimizar (R57)

**Data:** 22/11/2026 · **Versão:** Build 4.0 em preparação, depois da R56

**Pedido:** revisar a tela e a função Otimizar com cinco olhares:
- **Analista de Produto Sênior:** avalia o todo.
- **Engenheiro de Software Sênior:** revisa o código, refatora, segue as boas práticas, tira o que não serve e melhora o desempenho.
- **Designer Sênior, com um Especialista em UX/UI:** revisam as telas, os botões, os textos e os fluxos; o engenheiro aplica.
- **MVP Windows:** confere se o Otimizar segue as práticas da Microsoft, se cada etapa faz da melhor forma o que promete e se é robusto e estável.
- **QA Sênior:** testa tudo o que dá para testar, o óbvio e o que não é; o engenheiro aplica.

**De onde partiu:** a primeira revisão (R28) foi antes de cinco mudanças que tocam no Otimizar: o Gerenciar inicialização passou a morar no Desempenho (R43); a etapa do Windows Update passou a respeitar a pausa e a conexão limitada (R48); a revisão dos ajustes ficou sem a aparência e com o Explorador e a tela de bloqueio (R49 e R50); a página Programas e a restauração de um backup ganharam o reparo do Instalador de Aplicativo (R51); e o Verificar o PC passou a ler o winget em segundo plano, com prazo (R56).

**Resultado:** 11 achados, todos corrigidos.

| Olhar | Achados |
|---|---|
| Produto | 2: com a parte automática cancelada, o fim sugeria reiniciar mesmo sem nada pedindo; e, sem o winget, nenhuma oferta de reparo |
| Engenharia | 2: a pergunta do winget esperando a consulta inteira, parada; e o formato das respostas da parte automática escrito em dois lugares |
| Designer e UX/UI | 3: nas perguntas e no fim, o alto da janela repetindo a etapa que já tinha terminado; as perguntas do próprio Otimizar com Sim e Não; e a inicialização levando a Programas, e não ao Desempenho |
| MVP Windows | 2: numa conexão limitada, os programas, os navegadores e a Store baixavam sem perguntar; e a consulta do winget sem prazo |
| QA | 2: o ponto de restauração que falhava com um erro seguia sem perguntar; e, sem o winget, três avisos (dois em vermelho) e a pergunta da Microsoft Store no meio do Otimizar |

Nada rodou num Windows de verdade. A conferência foi feita na nuvem, com o Windows simulado da R28, a janela simulada da R37 e um winget falso de verdade no caminho do sistema, para a consulta em segundo plano e o prazo. O que só um PC mostra entrou no roteiro de conferência (§47).

## O Otimizar hoje

Abre do botão da nota do Início e da página Manutenção, e pede Administrador. São 20 etapas, numeradas na janela ("Etapa 8 de 20: Reparar o Windows (DISM + SFC)"), com a barra e o botão na barra de tarefas mostrando a execução inteira.

1. **Preparação:** uma linha para cada coisa que atrapalha (outra conta, reinício pendente, bateria, pouco espaço, os programas abertos), com **Continuar** e **Cancelar**.
2. **Com você, no começo:** o ponto de restauração (sem ele, por qualquer motivo, a pergunta "Continuar sem o ponto de restauração?", com **Cancelar** como padrão); sem o winget, a oferta de repará-lo; desinstalar programas e remover aplicativos do Windows. Aí a lista do winget começa a ser lida em segundo plano, enquanto você revisa o que abre com o Windows e as pastas.
3. **Antes da parte automática** (o alto da janela diz isso): numa conexão limitada, se atualiza os programas; o que atualizar no winget, já lido; os restos e a Lixeira. Depois, "Começar a parte automática?".
4. **A parte automática,** 14 etapas sem perguntas. Numa conexão limitada, com **Deixar para depois**, as três que baixam programas ficam de fora, dizendo isso.
5. **A revisão dos ajustes,** com você de volta.
6. **Para terminar:** o resumo, o reparo do disco (**Agendar** ou **Agora não**) e a sugestão de reiniciar. Com a parte automática cancelada, a sugestão só vem quando algo pede o reinício.

## Analista de Produto

| # | O que estava | Por que importa | Como ficou |
|---|---|---|---|
| P1 | Com a parte automática cancelada e algo mudado no começo (a inicialização, por exemplo), o fim dizia "Reinicie para o Windows começar do zero" e perguntava "Reiniciar o Windows agora?", mesmo sem nada pedindo o reinício. | Quem acabou de cancelar quer parar, e não recomeçar o PC. O Otimizar inteiro sugere reiniciar sempre porque atualizou e reparou o Windows; cancelado, nada disso rodou. | `Invoke-WinForgeMaintenanceClosing -OnlyWhenNeeded`: cancelada, a sugestão só vem quando algo pede o reinício (um programa desinstalado, o Windows esperando). O Explorador continua oferecido quando um ajuste só aparece depois dele. |
| P2 | Sem o winget (comum logo depois de formatar, até a Microsoft Store registrar o Instalador de Aplicativo), o Otimizar seguia sem desinstalar nem atualizar os programas, e nada dizia onde reparar. A restauração de um backup (R51) já oferece o reparo ali mesmo. | Desinstalar e atualizar são duas das 20 etapas, e o reparo resolve na hora na maior parte das vezes. | No começo, uma linha diz o que falta e por que importa, e a pergunta "Reparar o Instalador de Aplicativo agora?" vem com **Reparar** como padrão, pelo mesmo registro do **Reparar o Instalador de Aplicativo**. Reparado, a tela de desinstalar abre e a lista de atualizações sai normalmente. Sem reparar, uma linha diz onde repará-lo depois. Elevado com outra conta, não oferece (o registro valeria para ela). |

**Conferido e mantido:**
- **O plano inteiro, sem escolher etapas,** e a ordem dele (o reparo antes do Windows Update, a limpeza antes dos atalhos e dos restos).
- **O resumo, a faixa e o histórico** da R28: o título diz o que aconteceu, o botão leva à primeira etapa com problema.
- **O pouco espaço só como aviso:** a limpeza vem na parte automática, e parar antes não ajudaria.

**Para depois:** a tela **Atualizar programas** e o monitor na bandeja ainda leem o winget na hora, sem prazo. A consulta com prazo agora é uma só (`Start-WinForgeWingetUpgradeRead`), e dá para levá-la para lá numa próxima.

## Engenheiro de Software

| # | O que estava | Como ficou |
|---|---|---|
| E1 | A lista de atualizações do winget só começava a ser lida na pergunta dela, depois das telas da inicialização e das pastas. O `winget upgrade` depende da rede e, na primeira do dia, atualiza a lista da fonte; a pergunta ficava parada esperando. | A consulta começa em segundo plano logo depois dos programas (que mudam a lista) e corre enquanto você revisa a inicialização e as pastas. A consulta é a do Verificar o PC, que saiu do `Checkup.psm1` e foi para o `Software.psm1`: `Start-WinForgeWingetUpgradeRead` e `Receive-WinForgeWingetUpgradeRead`, usadas pelos dois. `Get-WinForgeWingetUpgradePlan -Read` recebe a consulta já começada e mostra nos detalhes técnicos o que o winget escreveu. Na nuvem, com um winget de 3 segundos e as duas telas levando 3, a pergunta esperou 0,1 segundo, contra 3,3 antes. O `finally` larga a consulta quando o Otimizar para antes dela. |
| E2 | O formato das respostas da parte automática (a lista do winget, a Lixeira, os restos) estava escrito duas vezes, no começo do Otimizar e nas perguntas. Um campo novo num lugar só quebraria o outro. | `New-WinForgeMaintenanceDetails`, usada pelos dois, com o campo novo da conexão limitada. As etapas leem o campo novo com valor padrão, e respostas no formato de antes continuam valendo. |

**Por dentro:**
- **Maintenance.psm1:** `New-WinForgeMaintenanceDetails`, `Repair-WinForgeMaintenanceWinget` e `Skip-WinForgeMeteredStep`, novas; `Read-WinForgeMaintenanceDetails` com a conexão limitada e a consulta adiantada (`-WingetRead`); `Invoke-WinForgeMaintenanceClosing -OnlyWhenNeeded`; o começo dividido em dois (os programas, depois a inicialização e as pastas), com a consulta no meio e o `finally`.
- **Software.psm1:** `Start-WinForgeWingetUpgradeRead` e `Receive-WinForgeWingetUpgradeRead`, novas (o prazo, `WinForgeWingetReadTimeoutSec`, 120 segundos); a espera sem a tarefa (o winget sumiu antes de começar) devolve "sem resposta", em vez de um erro de parâmetro.
- **Checkup.psm1:** sem `Start-WinForgeCheckupProgramsRead` e sem o prazo próprio; usa as duas de cima.
- **Console.psm1 e a janela:** `Write-WinForgePhase` ("[>>] título"), nova; `Get-WinForgeActivityEntry` reconhece a parte (`Phase`), e a janela a desenha como título, troca a frase em destaque e mantém a barra com a etapa anterior inteira (`RunStepDone`).
- **Traduções:** 5.794 textos (14 novos e 3 que saíram de uso). Cinco funções a mais nos módulos: 1.338; 201 na janela, sem mudança.

## Designer e Especialista em UX/UI

| # | O que estava | Orientação | Como ficou |
|---|---|---|---|
| D1 | Nas perguntas antes da parte automática, o alto da janela continuava dizendo "Etapa 5 de 20: Organizar Downloads, Documentos e Imagens", e, no resumo e na sugestão de reiniciar, "Etapa 20 de 20: Revisar os ajustes do Windows". As perguntas pareciam parte das pastas. | O alto da janela diz onde você está. | "Antes da parte automática" e "Para terminar" tomam o lugar da etapa, sem mudar a conta das 20, e a barra fica com a etapa anterior inteira. No resumo, as duas partes são títulos, como as etapas, e a pergunta leva só o que veio depois da parte. No menu de texto, a mesma linha. |
| D2 | As perguntas do próprio Otimizar vinham com Sim e Não: "Continuar mesmo assim?" (outra conta), "Continuar na bateria?", "Continuar sem o ponto de restauração?" e "Agendar o reparo do disco para a próxima reinicialização?". | Os botões dizem o que fazem (como nas outras telas desde a R38). | **Continuar** e **Cancelar**; **Continuar sem o ponto** e **Cancelar**; **Agendar** e **Agora não**. Os padrões não mudaram. |
| D3 | A etapa "Revisar o que abre com o Windows" levava a **Programas > Gerenciar inicialização**, e o "rode de novo em" do histórico também. A casa dela é o Desempenho desde a R43, e o Verificar o PC já leva para lá (R56). | Um lugar para cada coisa. | O botão da faixa e o histórico levam a **Desempenho > Gerenciar inicialização**. |

**Conferido e mantido:**
- **Uma pergunta por vez, antes da parte demorada,** e "Começar a parte automática?" com o tempo que ela leva.
- **A numeração "Etapa N de 20"** na ordem do plano, com a divisão nova do começo.
- **Cada caminho "Página > Item" dos textos novos** leva ao item certo, nos três idiomas.

## MVP Windows

| # | O que estava | Por que importa | Como ficou |
|---|---|---|---|
| M1 | Numa conexão limitada (chip, celular roteado, rede marcada como limitada), a etapa do Windows Update já esperava uma conexão sem limite (R48), mas o winget, os navegadores e a Microsoft Store baixavam sem perguntar. | Numa conexão limitada, o próprio Windows baixa só as atualizações prioritárias e pode pausar os downloads da Store. Os programas podem somar centenas de megabytes da franquia de alguém. | Antes das perguntas, uma linha diz que atualizar os programas, os navegadores e os aplicativos da Store pode consumir a franquia, e a pergunta "Atualizar os programas mesmo assim?" vem com **Deixar para depois** como padrão. Deixadas para depois, as três etapas dizem por quê, não baixam nada e ficam como ignoradas. O Windows Update segue a regra dele, como antes. |
| M2 | A lista do winget não tinha prazo: um winget que não responde (um proxy que segura a conexão, a fonte travada) deixava o Otimizar parado na pergunta, antes da parte automática, até o Parar. | Um fluxo de uma hora não pode ficar parado antes de começar. | O prazo da consulta (120 segundos, contados do começo dela); sem resposta, a linha "Não foi possível consultar o winget: o Instalador de Aplicativo não respondeu em 120 segundos.", a etapa do winget fica de fora, e as outras perguntas seguem. |

**Conferido**, com as fontes no fim:
- **A consulta:** a mesma `winget upgrade --accept-source-agreements` da tela Atualizar programas e do Verificar o PC, que só lista; os navegadores ficam com a etapa deles.
- **O reparo:** a Microsoft indica registrar de novo o Instalador de Aplicativo quando o winget ainda não aparece (`Add-AppxPackage -RegisterByFamilyName`), o que o reparo faz; o winget vem com o Instalador de Aplicativo no Windows 11, no 10 a partir da versão 1809 e no Windows Server 2025.
- **A conexão limitada:** o Windows baixa só as atualizações prioritárias e pode pausar os downloads da Microsoft Store; a leitura é a mesma da etapa do Windows Update (`Test-WinForgeMeteredConnection`).
- **Os comandos de cada etapa:** os da R14 e da R28, e os das segundas revisões de cada página.

## QA Sênior

**Como foi testado:** uma bateria nova do Otimizar, 97 conferências em português e 101 em inglês e em espanhol (nos outros dois, a que procura palavras soltas em português na tela):
- **A consulta do winget (A),** com um winget falso de verdade no caminho do sistema: sem o winget e sem a tarefa; os argumentos, as linhas e o código; a lista do Otimizar com a consulta adiantada (sem rodar o winget de novo, sem os navegadores, com o que ele escreveu nos detalhes técnicos); o prazo de 2 segundos (a espera para nele, e o winget é encerrado); a consulta que falha e a que não responde; sem a consulta adiantada, a de antes; o Verificar o PC lendo a mesma consulta, com o mesmo prazo.
- **As perguntas (B):** as respostas num lugar só; a conexão comum e a limitada (o aviso, a pergunta, o padrão, a ordem; deixar para depois e atualizar mesmo assim); sem etapas que baixam; só a Store; a consulta adiantada chegando à lista; sem o winget; o erro do winget com um ponto só.
- **As etapas (C):** sem o winget, reparar (a versão, a tela de desinstalar abrindo), agora não, o reparo que falha, o registro sem efeito, elevado com outra conta; com o winget; o winget sumindo depois; o winget, os navegadores e a Store numa conexão limitada e numa comum; respostas no formato de antes; a etapa do winget sem ele.
- **O fluxo inteiro (D):** a ordem (a consulta depois dos programas e antes da inicialização), a consulta recebida e largada, as 20 etapas numeradas, as duas partes no lugar certo; a consulta que não começa; o Otimizar parado nas perguntas (o `finally`); o ponto que falha com um erro (com e sem o sim), sem a Proteção do Sistema e criado; cancelada sem reinício, com reinício e com o Explorador; os rótulos das perguntas; a inicialização no Desempenho; o código.
- **A janela (G),** com o WPF simulado da R37: a marca "[>>]"; a frase em destaque, a barra (25% depois da etapa 5, também com a barra de uma ferramenta por cima), o leitor de tela, um título dentro da parte, a etapa seguinte, o fim em 100%; as partes como títulos no resumo; a pergunta levando só o que veio depois da parte; uma parte sem etapas numeradas; recomeçar.

**Achados**

| # | O que estava | Como ficou |
|---|---|---|
| Q1 | O ponto de restauração que falhava com um erro (o serviço de cópias de sombreamento desativado, por exemplo) virava uma etapa com falha, e o Otimizar seguia sem perguntar. Só o ponto não criado (a Proteção do Sistema desligada, o Windows recusando) perguntava. | Qualquer ponto que não ficou pronto pergunta "Continuar sem o ponto de restauração?", com **Cancelar** como padrão. Sem o sim, nada mais roda. |
| Q2 | Sem o winget, o Otimizar dizia que ele faltava três vezes: duas em vermelho, na tela de desinstalar e na lista de atualizações, e uma na etapa do winget. No meio, a tela de desinstalar perguntava se abria a Microsoft Store. Na janela, nada dizia onde reparar. | O aviso vem uma vez, no começo, com o reparo (P2); a lista de atualizações não repete; a etapa diz numa linha curta que foi ignorada. Nada em vermelho, e nenhuma pergunta da Store no meio do Otimizar. |

Os testes também acharam os do produto (P1 e P2), os da engenharia (E1 e E2), os do designer (D1 a D3) e os do MVP (M1 e M2).

**Contra o código de antes (R56):** das conferências que dá para rodar nele, falham 53 das 82 em português e 54 das 86 em inglês e em espanhol, cada uma de uma correção. As que passam conferem o que foi mantido: a conexão comum, com o winget, as etapas numeradas, o ponto criado e o não criado, o dia comum sugerindo reiniciar, a consulta que falha e os textos.

**45 defeitos de propósito,** e as conferências pegam todos: sem a pergunta da conexão limitada, com Atualizar como padrão, cada uma das três etapas baixando numa conexão limitada, a lista lida mesmo deixando para depois, sem dizer por que a etapa ficou de fora; sem o winget, a lista dizendo de novo; a consulta adiantada sem chegar à lista, sem começar, sem ser largada; os programas fora do começo; o erro do winget com ponto duplo; sem a oferta de reparo, com Agora não como padrão, oferecido com outra conta, reparado sem abrir a tela de desinstalar, sem dizer onde reparar depois; o ponto com erro sem perguntar e sem os rótulos; sem as duas partes; cancelada sugerindo reiniciar (na chamada e na regra) e sem o Explorador; os rótulos da preparação e do disco; a inicialização de volta a Programas (no botão e no histórico); as respostas sem o campo novo; a consulta sem aceitar o contrato da fonte, sem prazo, com 30 segundos, sem a tarefa, sem os detalhes técnicos, ignorada pela lista, o prazo esgotado como erro qualquer; na janela, as partes ignoradas, a barra voltando, a parte que não termina na etapa seguinte, o contexto da pergunta atravessando a parte, a parte como texto comum, "[>>]" lido como etapa, recomeçar sem esquecer a parte; e "Para terminar" sem tradução em inglês.

**Nada do que funcionava quebrou:** as baterias das 14 páginas revistas, com os mesmos números da R56 (a do Otimizar da R28 e a do Verificar o PC da R27 depois da adaptação abaixo; a da Rede da R22 com a mesma conferência antiga do escudo); a das seis funções novas da R36 (257 em cada idioma); as das segundas revisões, do Início ao Verificar o PC, com os mesmos números (a do Verificar o PC depois da adaptação abaixo); a da Manutenção da R14 (243, 245 e 250, depois da adaptação abaixo) e a do Início da R13 (241); as mensagens da janela (72); instalar, atualizar com um clique e o pacote de suporte; o PSScriptAnalyzer, com os mesmos 242 avisos; nenhuma função sem referência (entre 1.565) e nenhuma chamada a uma função que não existe.

**As baterias antigas adaptadas ao que mudou de propósito:** a do Otimizar da R28, com as perguntas simuladas recebendo a consulta adiantada, o winget presente nas perguntas e, nos dois casos em que tudo falha (o ponto também), o sim para seguir sem o ponto: 146, 151 e 151, como antes. A do Verificar o PC da R27 e a da R56, com a consulta pelo nome novo e o prazo no `Software.psm1`: 148, 149 e 149, e 163, 166 e 166, como antes. A da Manutenção da R14, no caso em que tudo falha (o ponto também), com o mesmo sim: 243, 245 e 250, como antes.

## O que só um PC mostra

Isto entrou no roteiro de conferência (§47):
- **A pergunta do winget** num PC real, depois de revisar a inicialização e as pastas: a lista já pronta; e sem internet, com a linha do prazo depois de 2 minutos.
- **Numa conexão limitada** (o celular roteado ou a rede marcada como limitada nas Configurações): o aviso, a pergunta e as três etapas deixadas para depois.
- **Sem o Instalador de Aplicativo** (o Windows Sandbox não tem o winget): a oferta de reparo, o reparo e a tela de desinstalar abrindo.
- **O alto da janela** nas perguntas e no fim: "Antes da parte automática" e "Para terminar", com a barra, e o Narrador lendo a parte.
- **Cancelar a parte automática** depois de mudar a inicialização: sem a sugestão de reiniciar.
- **O ponto de restauração com o serviço de cópias de sombreamento (VSS) desativado:** a pergunta para seguir sem ele.

## Fontes
- [Metered connections in Windows (Microsoft Support)](https://support.microsoft.com/en-us/windows/metered-connections-in-windows-7b33928f-a144-b265-97b6-f2e95a87c408): numa conexão limitada, o Windows Update baixa só as atualizações prioritárias, e os downloads da Microsoft Store podem ser pausados; os aplicativos que dependem da internet para se atualizar podem ficar limitados.
- [Use WinGet to install and manage applications (Microsoft Learn)](https://learn.microsoft.com/en-us/windows/package-manager/winget/): o winget vem com o Instalador de Aplicativo no Windows 11, no Windows 10 a partir da versão 1809 e no Windows Server 2025; quando ele ainda não aparece, a Microsoft indica `Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe`.
- As da R28 e da R56 continuam valendo.
