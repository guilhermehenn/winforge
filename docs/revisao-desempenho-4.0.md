# WinForge 4.0 — revisão do Desempenho (R18)

**Data:** 19/11/2026 · **Versão:** Build 4.0 em preparação, depois da R17

**Pedido:** juntar quatro olhares para a tela e a função de Desempenho:
- **Analista de UX/UI Sênior (designer):** revisa cada detalhe da interface e orienta o engenheiro.
- **Especialista Microsoft (MVP Windows):** confere se os comandos e as alterações no Windows são feitos da melhor forma disponível hoje, de modo seguro e robusto, e se fazem sentido e mudam o que devem no PC.
- **QA Sênior:** testa todas as funções da tela.
- **Engenheiro de Software Sênior:** aplica as correções.

**Resultado:** 10 achados, todos corrigidos.

| Olhar | Achados |
|---|---|
| Designer | 7: o "0 B" dos temporários que não foram apagados, o "0 B de temporários" no resumo, o Acelerar agora amarelo com as duas partes falhando, a faixa de Liberar memória que dizia só "Não foi concluído", o "ficou aberto" depois de a pessoa dizer Não, o "você não mudou nada" depois do Não na revisão do Otimizar e a lista da inicialização sem as tarefas, sem aviso |
| MVP Windows | 2: o Agendador de Tarefas consultado sem prazo e o pedido de acesso do esvaziamento da memória maior que o necessário |
| QA | 1 novo: o desfazer de uma tarefa no Histórico de mudanças, com o Agendador sem resposta, dizia "item de inicialização desconhecido". Os testes também acharam sete dos acima (D1, D2, D3, D5, D6, D7 e M1). |
| Engenharia | Nenhum próprio: aplicou os 10. |

Nada rodou num Windows de verdade. O Windows (a memória, os processos, o registro, o Agendador de Tarefas e o WMI) foi simulado; um processo de verdade foi aberto e fechado na nuvem, para conferir o fechamento sem janela. O que só um PC mostra entrou no roteiro de conferência.

## O Desempenho hoje

A página tem, de cima para baixo:
1. **O resumo:** a memória em uso e há quanto tempo o PC está ligado.
2. **Deixar o PC mais leve:**
   - Acelerar agora, em destaque ("Acelerar");
   - Programas pesando agora;
   - Liberar memória.
3. **Para o PC continuar leve:**
   - Gerenciar inicialização;
   - Gerenciador de Tarefas, que abre o do Windows.

Nada da página pede Administrador para abrir. Sem ele, a inicialização mostra só os itens da conta e diz quantos ficaram de fora.

O que cada ação muda:
- **Acelerar agora e Liberar memória:** tiram da memória o que os programas abertos não estão usando agora. Nada se perde: o que eles voltarem a usar volta para a memória. O Acelerar agora também apaga os temporários do usuário com mais de 24 horas, como a Limpeza rápida.
- **Programas pesando agora:** só mede; fechar é escolha da pessoa, com a pergunta no Não. Encerrar à força um programa sem janela tem uma pergunta à parte, também no Não.
- **Gerenciar inicialização:** desativa ou reativa como o Gerenciador de Tarefas e as Configurações fazem, sem apagar nada, e fica no Histórico de mudanças, com o desfazer.

## Designer (UX/UI)

| # | O que estava | Orientação | Como ficou |
|---|---|---|---|
| D1 | No Acelerar agora, com os temporários recusados (a pasta apontando para um lugar que não é de temporários, por exemplo), o resumo dizia "Temporários apagados: 0 B" e "3 GB de memória e 0 B de temporários liberados". | O que não foi feito não vira "0 B". | "Temporários apagados: não foi possível apagar", em amarelo, e "3 GB de memória liberados; os temporários não foram apagados". |
| D2 | Sem temporários para apagar, o resumo dizia "512 MB de memória e 0 B de temporários liberados" ou "a memória não foi liberada; 0 B de temporários apagados". | Só o que diz algo. | "512 MB de memória liberados; a memória continua alta (91%)" e "a memória não foi liberada; nenhum temporário para apagar". |
| D3 | Com a memória e os temporários recusados, o Acelerar agora terminava em amarelo, "Concluído com ressalvas". | Nada feito é vermelho. | Vermelho, "A memória não foi liberada", com o motivo dos temporários na frase. |
| D4 | Quando o Windows recusava liberar a memória, a faixa de Liberar memória dizia só "Não foi concluído". | A faixa diz o que não aconteceu. | "A memória não foi liberada" e "O Windows não atendeu ao pedido.", como no Acelerar agora. |
| D5 | Em Programas pesando agora, marcar só programas sem janela e responder Não ao "Encerrar à força?" terminava em amarelo: "ficou aberto: OBS Studio". | Dizer Não é desistir. | "Operação cancelada", como no Não da pergunta de antes. Com outro programa junto, ele fecha, e a faixa diz qual ficou aberto, como antes. |
| D6 | Na revisão do que abre com o Windows (o Otimizar), desmarcar um item e responder Não, ou cancelar a lista, terminava em "Nada foi mudado: você não mudou nada". | Desistir é cancelar; "você não mudou nada" é para a lista confirmada sem diferença. | "Operação cancelada". No resumo do Otimizar, a etapa diz "nada mudou", como nas outras telas com escolha. |
| D7 | Com o Agendador de Tarefas sem resposta, Gerenciar inicialização mostrava a lista sem as tarefas agendadas, como se fosse tudo. | Faltar uma leitura é dito na tela. | Uma linha amarela antes da conta: "As tarefas agendadas não puderam ser lidas: o Windows não respondeu em 60 segundos." O resto da lista funciona. |

**Conferido e mantido:**
- um destaque só na página, o Acelerar agora, e as descrições em até 60 letras nos três idiomas;
- as perguntas começam no lugar seguro: "Quer fechar algum programa?" em Concluir, "Fechar …?" e "Encerrar à força …?" no Não, "O que deseja fazer?" da inicialização em Cancelar, e a revisão do Otimizar no Não quando algo deixa de abrir;
- as listas de fechar e de desativar vêm desmarcadas; a da revisão vem com o que abre hoje marcado;
- o que é do Windows, de hardware ou antivírus vem dito no próprio item ("do Windows; melhor deixar ligado");
- só olhar a lista dos que pesam não tem veredito: a janela termina sem a faixa "Tudo certo";
- a memória folgada não aparece em verde, e "0 B" não aparece como conquista.

## Especialista Microsoft (MVP Windows)

**O que mudou**

| # | O que estava | Por que não é o melhor | Como ficou |
|---|---|---|---|
| M1 | Gerenciar inicialização lia as tarefas com `Get-ScheduledTask` e as ligava e desligava com `Enable-ScheduledTask` e `Disable-ScheduledTask`, sem prazo. O mesmo valia para o desfazer no Histórico de mudanças e para a revisão do Otimizar. | Esses comandos falam com o Agendador de Tarefas pelo WMI e não têm tempo-limite. Um WMI com defeito ou um Agendador travado deixava a tela parada sem fim. Os três aceitam `-AsJob`, como os do Defender, do firewall e dos discos, que já rodam com prazo. | Os três rodam pelo `Invoke-WinForgeCimCommand`, com `-AsJob` e espera de até 60 segundos. Sem resposta, a lista segue sem as tarefas, com o aviso do D7; o desfazer diz que as tarefas não puderam ser lidas. |
| M2 | O esvaziamento da memória abria cada processo com `PROCESS_QUERY_INFORMATION` e `PROCESS_SET_QUOTA`. | A Microsoft documenta que o `EmptyWorkingSet` pede a consulta completa ou a limitada, mais a de cota. Pedir mais acesso do que o necessário não ajuda em nada. | `PROCESS_QUERY_LIMITED_INFORMATION` e `PROCESS_SET_QUOTA`: o mínimo documentado. Os processos esvaziados são os mesmos. |

**Cada comando, conferido**

| Função | Como o WinForge faz | Veredito |
|---|---|---|
| Resumo da página | Uma leitura do `Win32_OperatingSystem`, com prazo de 15 segundos: a memória em uso (`TotalVisibleMemorySize` menos `FreePhysicalMemory`; amarelo a partir de 85%) e o tempo ligado (amarelo a partir de 7 dias). Um início "no futuro" (o relógio acertado depois de ligar) tira a linha. | Certo. Com a Inicialização Rápida, desligar não zera o tempo ligado; só reiniciar zera, e a frase pede reiniciar. |
| Liberar memória | `EmptyWorkingSet` (psapi) em cada processo da sessão da pessoa, menos o próprio WinForge. Os serviços do Windows e os programas de outras contas ficam como estão. A memória é medida antes e depois, com 1,5 segundo entre as duas. | Certo, com o M2 e o D4. |
| Acelerar agora | Liberar memória e os temporários do usuário com mais de 24 horas (a mesma limpeza da Limpeza rápida). As duas partes são independentes. | Certo, com o D1, o D2 e o D3. |
| Programas pesando agora | Duas leituras dos processos da sessão, com 1,5 segundo entre elas: o processador, pelo tempo de uso dividido pelos núcleos, como o Gerenciador de Tarefas; a memória, pelo conjunto de trabalho privado (`Win32_PerfRawData_PerfProc_Process`, 5 segundos). Os processos do Windows, de instalação e do WinForge não entram na lista de fechar. Fechar é como clicar no X: a janela principal recebe o pedido de fechar (a moldura, num aplicativo da Store), com até 5 segundos de espera. Os processos sem janela do programa saem só depois, pela família do processo pai. `Stop-Process -Force` só num programa sem janela, depois da pergunta à parte. Antes de agir, confere que o número do processo ainda é o do medido (pela hora de início). | Certo, com o D5. |
| Gerenciar inicialização | As chaves Run (do usuário, de todos os usuários e de 32 bits) e as pastas Inicializar: o valor de 12 bytes em `StartupApproved` (02 ligado; 03 e a hora, desligado), o mesmo do Gerenciador de Tarefas, sem apagar a entrada. Os aplicativos da Store: o `State` da tarefa de inicialização (1, desativado pela pessoa; 2, ativado); 3 e 4 são de política e ficam como estão. As tarefas agendadas de outros fabricantes que só rodam ao entrar no Windows ou ao ligar o PC: `Disable-ScheduledTask` e `Enable-ScheduledTask`. Depois de cada mudança, o estado é lido de novo, e só conta o que o Windows manteve. | Certo, com o M1 e o D7. |
| Gerenciador de Tarefas | `taskmgr.exe`. | Certo. |

**Conferido e mantido**
- **O cache de arquivos não é esvaziado:** ele já conta como memória disponível. Jogá-lo fora só faria o Windows ler de novo do disco o que estava pronto. A tela diz que o efeito de liberar some aos poucos.
- **Desativar não apaga:** a entrada Run e o atalho ficam, e o item continua no Gerenciador de Tarefas e nas Configurações, de onde também pode ser reativado.
- **As tarefas que rodam em outros horários ficam fora da lista** (a maioria dos atualizadores): desativar a tarefa pararia também as atualizações do programa.
- **O aplicativo da Store desativado com 1**, o mesmo que as Configurações gravam: ele não consegue se religar sozinho.
- **Encerrar à força só com a pergunta à parte, no Não:** é como encerrar pelo Gerenciador de Tarefas, e o que não foi salvo pode ser perdido.

## QA Sênior

**Como foi testado:** cada função da página rodou com o Windows simulado, nos três idiomas: 96 conferências em português e 102 em inglês e em espanhol. As 6 a mais conferem, em cada seção, que nenhum texto do português aparece na tela.
- **Acelerar agora (14):**
  - o normal, com memória e temporários;
  - o PC já leve;
  - só os temporários pesando;
  - a memória ainda alta;
  - a memória recusada, os temporários recusados e os dois recusados;
  - sem a medida do Windows;
  - sem temporários;
  - outra conta.
- **Liberar memória (12):** o normal, a memória folgada, a memória ainda alta, o Windows recusando, sem a medida, o "quase nada" e o acesso pedido ao Windows.
- **Programas pesando agora (21):**
  - só olhar;
  - fechar dois, com Não e com Sim;
  - um sem janela, com Não e com Sim;
  - um sem janela junto de outro, com Não;
  - um que não fechou;
  - só programas do Windows;
  - sem leitura dos processos;
  - a memória alta;
  - os processos desta sessão medidos de verdade;
  - um processo de verdade sem janela: fica sem o "à força", sai com ele, e o mesmo número depois não é fechado.
- **Gerenciar inicialização (25):**
  - cancelar;
  - a lista de desativar, com quem publica e o conselho;
  - quais tarefas entram;
  - desativar três (uma chave Run, uma tarefa e um aplicativo da Store);
  - reativar;
  - o Windows sem manter a mudança;
  - sem Administrador;
  - outra conta;
  - nada abrindo com o Windows;
  - o Agendador sem resposta;
  - a revisão do Otimizar: sem mudar nada, com Não, cancelada e aplicada;
  - o desfazer, com o Agendador sem resposta e respondendo.
- **O resumo da página (5):** normal, a memória alta com 9 dias ligado, sem leitura, um início "no futuro" e o prazo da leitura.
- **A página (13):** cada item existe e tem até 60 letras, um destaque só, nada pedindo Administrador e o atalho do Gerenciador de Tarefas.
- **Os textos:** nenhum marcador `{0}` sobrando e nenhum texto do português na tela em inglês e em espanhol.

**Achados**

| # | Severidade | O que acontecia | Como ficou |
|---|---|---|---|
| Q1 | Baixa | O desfazer de uma tarefa no Histórico de mudanças, com o Agendador sem resposta, esperava sem fim e, quando ele falhava, dizia "item de inicialização desconhecido". | Para em até 60 segundos e diz "as tarefas agendadas não puderam ser lidas", com o motivo. |
| Q2 | Média | A inicialização parada sem fim com o Agendador sem resposta (é o M1). | Corrigido. |
| Q3 | Baixa | Os "0 B" do Acelerar agora (são o D1 e o D2). | Corrigido. |
| Q4 | Baixa | O Acelerar agora amarelo sem nada feito (é o D3). | Corrigido. |
| Q5 | Baixa | O "ficou aberto" depois do Não (é o D5). | Corrigido. |
| Q6 | Baixa | O "você não mudou nada" depois do Não (é o D6). | Corrigido. |

Cada conferência nova falha no código de antes e passa no de agora.

## Engenharia

**Por dentro**
- **Performance.psm1:**
  - `Initialize-WinForgeMemoryNative`: o acesso `0x1000 | 0x0100`;
  - `Invoke-WinForgeMemoryOptimization`: a faixa da falha;
  - `Invoke-WinForgeBoost`: os temporários recusados no resumo, o detalhe sem "0 B" e o vermelho com as duas partes falhando;
  - `Show-WinForgeHeavyProcesses`: o Não ao "à força", com todos os marcados sem janela, é cancelar.
- **Startup.psm1:**
  - `Get-WinForgeStartupTasks`, `Get-WinForgeStartupItemEnabled` e `Set-WinForgeStartupItemEnabled` falam com o Agendador pelo `Invoke-WinForgeCimCommand`;
  - `Get-WinForgeStartupTasksProblem` (nova) diz por que a última leitura falhou;
  - `Set-WinForgeStartupItems` mostra o aviso e separa o cancelar do "não mudou nada";
  - `Read-WinForgeStartupReview` devolve uma lista vazia quando nada muda e `$null` quando a pessoa desiste.
- **Journal.psm1:** o desfazer da inicialização diz o motivo do Agendador.
- **Traduções:** 5 novas e 1 que saiu de uso; 5.202 ao todo.

**Conferido na nuvem**
- **As conferências do Desempenho:** 96, 102 e 102, todas passando.
- **As 84 ações rodaram de novo 336 vezes** com o Windows simulado: nenhum erro escapou, e o resultado é o mesmo da R17, fora o resumo do Acelerar agora sem o "0 B de temporários".
- **As de antes continuam passando:**
  - as 178, 187 e 187 da Limpeza, as 134, 142 e 142 da Segurança e as 212, 224 e 224 do Diagnóstico;
  - as 245, 247 e 252 da Manutenção, com a revisão do que abre com o Windows no Otimizar, e as 241 do Início nos três idiomas;
  - as 83 do QA geral, as 80 da R11 e as 60 da R12;
  - as 59 da R9 e as 52 da R10;
  - as 66 da QA, as 28 da integração e as 26 da R7;
  - o motor de instalação, a atualização simulada e o Setup de verdade (da R17 para esta), e o pacote de suporte;
  - as traduções (5.202/5.202), as 160 referências nos três idiomas e a busca dos 102 itens;
  - nenhuma chamada com parâmetro que não existe, nenhuma função sem uso e nenhum aviso novo do analisador.

**Fora desta tela:** a Manutenção agendada (Manutenção) também fala com o Agendador de Tarefas sem prazo. Fica para quando a Manutenção for revista de novo.

## O que só um PC mostra

Isto entrou no roteiro de conferência:
- **Gerenciar inicialização com tarefas agendadas:** a lista com as tarefas de outros fabricantes, desativar uma e conferir no Agendador de Tarefas, e reativar pelo Histórico de mudanças. É a mudança mais sensível desta revisão: as tarefas agora são lidas e mudadas por um trabalho do próprio WinForge (`-AsJob`), como o Defender, o firewall e os discos.
- **Liberar memória e Acelerar agora:** a faixa com quanto saiu, como antes. O acesso pedido ao Windows mudou para o mínimo documentado; o número deve ficar parecido.
- **Programas pesando agora:** marcar só um programa sem janela (perto do relógio, por exemplo) e responder Não: termina em "Operação cancelada".
- **A revisão do Otimizar:** desmarcar um item e responder Não: a etapa diz "nada mudou".

## Fontes
- [EmptyWorkingSet function (Microsoft Learn)](https://learn.microsoft.com/en-us/windows/win32/api/psapi/nf-psapi-emptyworkingset): o processo precisa do acesso `PROCESS_QUERY_INFORMATION` ou `PROCESS_QUERY_LIMITED_INFORMATION` e do `PROCESS_SET_QUOTA`.
- [Get-ScheduledTask (Microsoft Learn)](https://learn.microsoft.com/en-us/powershell/module/ScheduledTasks/Get-ScheduledTask): o comando aceita `-AsJob` e `-CimSession`.
- [Disable-ScheduledTask (Microsoft Learn)](https://learn.microsoft.com/en-us/powershell/module/scheduledtasks/disable-scheduledtask): o comando aceita `-AsJob`.
- [StartupTaskState Enum (Microsoft Learn)](https://learn.microsoft.com/en-us/uwp/api/windows.applicationmodel.startuptaskstate): 0 desativado, 1 desativado pela pessoa (só ela religa), 2 ativado, 3 desativado por política, 4 ativado por política.
- [Win32_OperatingSystem class (Microsoft Learn)](https://learn.microsoft.com/windows/win32/cimwin32prov/win32-operatingsystem): `FreePhysicalMemory`, a memória física sem uso e disponível, e `TotalVisibleMemorySize`, a memória física que o Windows enxerga.
