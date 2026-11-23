# WinForge 4.0 — segunda revisão da Manutenção (R41)

**Data:** 21/11/2026 · **Versão:** Build 4.0 em preparação, depois da R40

**Pedido:** revisar a tela e a função Manutenção com cinco olhares:
- **Analista de Produto Sênior:** avalia o todo.
- **Engenheiro de Software Sênior:** revisa o código, refatora, segue as boas práticas, tira o que não serve e melhora o desempenho.
- **Designer Sênior, com um Especialista em UX/UI:** revisam a tela, os botões, os textos e os fluxos; o engenheiro aplica.
- **MVP Windows:** confere se a Manutenção segue as práticas da Microsoft, se cada função faz da melhor forma o que promete e se é robusta e estável.
- **QA Sênior:** testa tudo o que dá para testar, o óbvio e o que não é; o engenheiro aplica.

**De onde partiu:** a primeira revisão da Manutenção (R14) foi antes do desenho novo (R37). O Otimizar e o Verificar o PC tiveram revisões próprias (R28 e R27). Esta olhou a página inteira de hoje e as funções que só ela tem: a manutenção agendada, o ponto de restauração, os dois históricos e a Restauração do Sistema.

**Resultado:** 7 achados, todos corrigidos.

| Olhar | Achados |
|---|---|
| Produto | 1: a manutenção agendada podia falhar todo mês sem o Início nem a tela dizerem nada |
| Engenharia | 2: o cartão antigo do alto, com quatro funções que só ele usava e um caso à parte na montagem da página; e a mesma leitura feita duas vezes na tela da manutenção agendada |
| Designer e UX/UI | 1: o cartão "Última manutenção" era do desenho antigo, de meia largura e colado no destaque |
| MVP Windows | 1: as consultas ao Agendador de Tarefas da manutenção agendada não tinham prazo, contra a regra do próprio WinForge |
| QA | 2: desfazer um ajuste pelo Histórico de mudanças não oferecia reiniciar o Explorador nem pedia o reinício do PC; e desfazer duas trocas de DNS de uma vez contava duas e anotava dois "Desfeito" |

Nada rodou num Windows de verdade. A conferência foi feita na nuvem: a página com as funções de verdade da janela sobre o WPF simulado, e as ações com o Windows simulado. O que só um PC mostra entrou no roteiro de conferência (§32).

## A Manutenção hoje

De cima para baixo:
1. **Última manutenção:** a faixa do alto (nova), com a mesma leitura do Início; o clique abre o Histórico de manutenções.
2. **Otimizar,** em destaque, com "Otimizar agora".
3. **Cuidar do PC:** Verificar o PC e Manutenção agendada.
4. **Se algo der errado:** Criar ponto de restauração, Histórico de mudanças e Restauração do Sistema (a janela do Windows).

O Histórico de manutenções e o Agendador de Tarefas não viram linha: chega-se a eles pela faixa, pelo Início e pela busca.

## Analista de Produto

| # | O que estava | Por que importa | Como ficou |
|---|---|---|---|
| P1 | O Início e a tela da manutenção agendada só viam uma falha pelo código que o Agendador de Tarefas guarda. No Windows 11, a tarefa abre o PowerShell pelo conhost, que não devolve o código de saída dele (o próprio código do WinForge já registrava isso). Uma execução em que nada funcionou ficava como "terminou bem". | É uma função que roda sem ninguém olhando: se ela falha e ninguém sabe, o PC deixa de ser cuidado sem aviso. A tela até mostrava "não funcionou" na linha da última execução, mas o Início não. | O registro que o próprio WinForge grava em cada execução também conta: quando ele diz que nada funcionou na execução mais recente, o Início mostra "A última manutenção agendada falhou", com o botão para a tela. Um registro de uma execução anterior, ou da tarefa de outra conta, não conta. |

**Conferido e mantido:**
- **A página com um destaque só (Otimizar)** e dois grupos pelo motivo: cuidar do PC e voltar atrás se algo der errado.
- **A manutenção agendada só faz o seguro:** apaga os temporários com mais de 7 dias e salva um relatório, sem Administrador; Lixeira, reparo, programas e ajustes ficam de fora.
- **O Histórico de manutenções e o Agendador fora da lista:** um pela faixa do alto, o outro pela busca.

## Engenheiro de Software

| # | O que estava | Como ficou |
|---|---|---|
| E1 | O alto da página era o único cartão do desenho antigo: `New-GuiMaintenanceFact`, que usava `New-GuiFactCard`, `Set-GuiFactCardText` e `Set-GuiCardWidth` (só ele os chamava), num caso à parte de `Show-GuiListPage`. | A Manutenção passa a ter a faixa das outras páginas: `Get-WinForgeMaintenancePageStatus` (Maintenance.psm1, nova) dá a linha, e `New-GuiPageStatus` a monta. Uma linha com destino (`Opens`) vira um botão com a seta. Saíram as quatro funções e o caso à parte: a janela tem 110 linhas e 4 funções a menos. |
| E2 | A tela da manutenção agendada lia duas vezes se o Agendador tinha respondido, por um caminho de "valor que pode faltar" que nunca falta. | Uma leitura só. |

**Por dentro:**
- **Schedule.psm1:** `Get-WinForgeScheduleStatus` lê a tarefa, o XML e a última execução por `Invoke-WinForgeCimCommand`, com prazo, e ganhou `RecordFailed`; `Register-WinForgeScheduledMaintenance` e `Unregister-WinForgeScheduledMaintenance` também passam por ele, e a remoção não espera um segundo prazo quando o primeiro esgotou.
- **Journal.psm1:** o desfazer de um ajuste diz se ele pede o Explorador ou o reinício do PC; `Show-WinForgeChangeHistory` oferece o Explorador uma vez, no fim, e não desfaz de novo uma mudança que outra da mesma lista já cobriu.
- **Maintenance.psm1:** `Get-WinForgeMaintenancePageStatus`.
- **WinForge.Gui.ps1:** `New-GuiPageStatus` com `Opens`; saíram `New-GuiMaintenanceFact`, `New-GuiFactCard`, `Set-GuiFactCardText` e `Set-GuiCardWidth`.
- **Traduções:** 5.564 textos (um novo, "a última execução não funcionou").

## Designer e Especialista em UX/UI

| # | O que estava | Orientação | Como ficou |
|---|---|---|---|
| D1 | No alto da página, o cartão "Última manutenção" era do desenho de antes do R37: meia largura, três linhas, a 4 pixels do destaque. As outras páginas (Limpeza, Desempenho e Sobre o WinForge) têm uma faixa de largura inteira, a 16 pixels. É a UX11 da revisão de UX (R38). | A mesma faixa das outras páginas, com a seta que abre o histórico. | "Última manutenção · Ainda não executada · o ideal é uma por mês", de ponta a ponta, na altura das outras faixas, na cor do estado (amarelo quando passou de um mês ou pediu atenção). A faixa inteira é um botão, como as linhas das listas, e o leitor de tela ouve para onde ela leva. |

**Conferido e mantido:**
- **Os textos das linhas** cabem numa linha nos três idiomas, e a frase inteira fica na dica.
- **As perguntas que custam algo começam no Não:** remover ou trocar o agendamento de outra conta, reiniciar o Explorador depois de desfazer (como em Ajustes do Windows).
- **As telas só de consulta** (os dois históricos e a manutenção agendada sem mudança) terminam sem faixa de resultado.
- **O quadrado laranja do destaque (UX12)** vale para todas as páginas e continua para a decisão da revisão de UX.

## MVP Windows

| # | O que estava | Por que importa | Como ficou |
|---|---|---|---|
| M1 | A manutenção agendada lia, criava e removia a tarefa chamando `Get-ScheduledTask`, `Export-ScheduledTask`, `Get-ScheduledTaskInfo`, `Register-ScheduledTask` e `Unregister-ScheduledTask` direto, sem prazo. A regra de engenharia do WinForge (seção 19 da documentação técnica) manda esses comandos passarem por `Invoke-WinForgeCimCommand`, e o Gerenciar inicialização e as execuções sem Administrador já passavam. | Esses comandos rodam sobre o WMI; um Agendador travado prendia a tela da manutenção agendada, a leitura do Início, o instalador e a desinstalação. A Microsoft documenta o `-AsJob` deles para "commands that take a long time to complete". | Os cinco passam por `Invoke-WinForgeCimCommand`, que roda o comando como trabalho, com 60 segundos de prazo. Sem resposta, a tela diz "não foi possível consultar o Agendador de Tarefas", sem nenhum dia em destaque, como no Agendador que recusa a consulta. |

**Conferido e mantido**, com as fontes no fim:
- **A tarefa mensal:** sem Administrador (`LeastPrivilege`, com o token da pessoa), todo mês às 12h; roda depois se o PC estava desligado (`StartWhenAvailable`); não começa na bateria e para se o notebook sai da tomada (`DisallowStartIfOnBatteries`, `StopIfGoingOnBatteries`); uma hora no máximo (`ExecutionTimeLimit`); prioridade abaixo do normal. Cada configuração é a que a Microsoft descreve.
- **No Windows 11, o PowerShell pelo `conhost --headless`,** para o Terminal não mostrar janela (R14). Por isso o código de saída não chega ao Agendador, e o registro do WinForge passa a contar (P1).
- **O ponto de restauração** pelo `Checkpoint-Computer`, conferido na lista de pontos, com o limite de um por dia desligado só durante a criação (R14 e R23).
- **A remoção da pasta `\WinForge\` do Agendador** continua pela COM, sem prazo: ela só roda depois de o Agendador responder à remoção da tarefa, e uma falha nela não muda o que a pessoa pediu.

## QA Sênior

**Como foi testado:** uma bateria nova da Manutenção, com a página montada pelas funções de verdade da janela sobre o WPF simulado e as ações com o Windows simulado: 67 conferências em cada idioma.
- **A faixa do alto (A):** a largura, a margem, uma linha só que abre o Histórico de manutenções, o rótulo de 160 e a frase, a seta, a altura igual à das outras faixas, o leitor de tela e o clique; o destaque e os grupos depois dela, sem o histórico e o Agendador na lista; a frase e a cor em seis situações (nunca feita, nunca feita com uma verificação recente, recente, antiga com etapas com atenção, data no futuro, leitura que falha e que lança erro); a Limpeza, o Desempenho e o Sobre o WinForge com a faixa de antes, sem botão; o código sem o cartão antigo.
- **O Agendador com prazo (B):** a leitura, a criação e a remoção pelos trabalhos com prazo; o mesmo estado de antes; sem a tarefa, com o acesso negado e com o Agendador travado (que para em um segundo de prazo, no teste); a tela com o Agendador travado; remover o que já não existe e remover com o Agendador travado; o código sem chamadas diretas.
- **O registro da execução mensal (C):** o Agendador dizendo "terminou bem" com o registro dizendo que nada funcionou; a execução certa; com ressalvas; o registro de uma execução anterior; a tarefa de outra conta; a tarefa recriada que ainda não rodou; a frase do problema; o ponto no Início; a linha da tela; o código de erro do Agendador, que continua valendo; sem registro.
- **Desfazer um ajuste (D):** o ajuste que pede o Explorador, o que pede o reinício do PC, o comum e o que foi alterado depois; pelo Histórico de mudanças, um e dois ajustes do Explorador, um comum, o Explorador que não reinicia e o "não" ao Explorador; o reinício do PC na faixa; sem marcar nada.
- **Mudanças que voltam juntas (E):** duas trocas de DNS desfeitas de uma vez.
- **Os textos (K):** o texto novo nos três idiomas.

**Achados**

| # | O que estava | Como ficou |
|---|---|---|
| Q1 | Desfazer, pelo Histórico de mudanças, um ajuste que só aparece com o Explorador reiniciado (as extensões dos arquivos, o menu do clique direito, a barra de tarefas) voltava o valor, mas nada mudava na tela e nada dizia por quê. Em Ajustes do Windows, o mesmo desfazer oferece reiniciar o Explorador. O ajuste que só vale depois de reiniciar o PC (o agendamento da placa de vídeo) também não pedia o reinício. | No fim, uma pergunta só: "Reiniciar o Explorador de Arquivos agora para ver a mudança?" (ou "as mudanças"). Com "não", a tela diz quando a mudança aparece; o Explorador que não reinicia vira ressalva. O ajuste que pede o reinício do PC põe o pedido na faixa. |
| Q2 | Marcar duas trocas de DNS e desfazer: a primeira volta o DNS ao de antes da primeira troca e tira as duas da lista; a segunda, já desfeita, dizia "o DNS já estava como antes", a faixa contava "2 mudanças desfeitas" e o histórico ganhava dois "Desfeito". | Uma mudança que outra da mesma lista já cobriu não é desfeita de novo, nem contada, nem anotada. |

Os testes também acharam os do produto (P1), do designer (D1) e do MVP (M1).

**Contra o código de antes (R40):** cada conferência das correções falha, e as que conferem o que foi mantido passam. No Agendador, 7 de 11 falham; no registro, 3 de 11; no desfazer, 8 de 16; nas mudanças que voltam juntas, 3 de 4. A faixa para logo no começo, porque a função nova não existe.

**26 defeitos de propósito,** e as conferências pegam todos: a leitura, o XML, a criação e a remoção da tarefa de volta ao comando direto; o prazo esgotado contando como "não agendada"; a remoção esperando um segundo prazo; o registro ignorado, valendo quando é de outra execução, de outra conta ou só com ressalvas, e sem o problema; o desfazer sem o Explorador, sem o reinício do PC e pedindo o Explorador sem nada ter voltado; a pergunta no singular para vários; o Explorador que não reinicia sem virar ressalva; a mudança já coberta desfeita de novo; a faixa sem levar ao histórico, levando a outro lugar, sem a seta, mais alta, sem o destino para o leitor de tela, sem o complemento ou com ele repetido e sem a cor do estado; e as outras páginas com botão.

**O WPF simulado** é o da R40, conferido contra o perfil do Windows PowerShell 5.1 (83 tipos): esta revisão não precisou de nada novo nele.

**Nada do que funcionava quebrou:** a bateria da Manutenção da R14 (243, 245 e 250), a do Início da R40 (115) e as das 14 páginas revistas, com os mesmos números; as mensagens da janela (72); instalar, atualizar e o Setup de verdade da R40 para esta; nenhum aviso novo do PSScriptAnalyzer (248) e nenhuma função sem uso (1.504).

## O que só um PC mostra

Isto entrou no roteiro de conferência (§32):
- **A faixa do alto,** nos dois temas, com o mouse, o teclado e o Narrador.
- **A manutenção agendada** com o Agendador de Tarefas parado, e uma execução que falha no Windows 11.
- **Desfazer pelo Histórico de mudanças** um ajuste do Explorador e duas trocas de DNS.

## Fontes
- [Get-ScheduledTask](https://learn.microsoft.com/en-us/powershell/module/scheduledtasks/get-scheduledtask) (Microsoft): o `-AsJob` "Runs the cmdlet as a background job. Use this parameter to run commands that take a long time to complete."
- [Settings (taskType) Element](https://learn.microsoft.com/en-au/windows/win32/taskschd/taskschedulerschema-settings-tasktype-element) (Microsoft): `StartWhenAvailable` ("can start the task at any time after its scheduled time has passed"), `DisallowStartIfOnBatteries`, `StopIfGoingOnBatteries`, `ExecutionTimeLimit` e `Priority`.
