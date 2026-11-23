# WinForge 4.0 — revisão da Manutenção (R14)

**Data:** 19/11/2026 · **Versão:** Build 4.0 em preparação, depois da R13

**Pedido:** juntar quatro olhares para a tela e a função de Manutenção:
- **Analista de UX/UI Sênior (designer):** revisa cada detalhe da interface e orienta o engenheiro.
- **Especialista Microsoft (MVP Windows):** confere se os comandos e as alterações no Windows são feitos da melhor forma disponível hoje, de modo seguro e robusto, e se fazem sentido e mudam o que devem no PC.
- **QA Sênior:** testa todas as funções da tela.
- **Engenheiro de Software Sênior:** aplica as correções.

**Resultado:** 8 achados, todos corrigidos.

| Olhar | Achados |
|---|---|
| Designer | 4: três números de espaço que pareciam se contradizer, o mesmo link com duas frases, um dia em destaque sem saber se há tarefa e o espanhol no masculino |
| MVP Windows | 2: o Verificar o PC amarelo por causa do registro, que o próprio WinForge não recomenda limpar; e a Store abrindo no meio do Otimizar |
| QA | 1 novo: uma etapa do Otimizar sem o "rode de novo em" no histórico. Os testes também acharam dois dos acima (M1 e D3). |
| Engenharia | 1: os textos das etapas do Otimizar que nenhuma tela mostrava |

Nada rodou num Windows de verdade. As leituras e os comandos foram simulados, e o que só um PC mostra entrou no roteiro de conferência.

## A Manutenção hoje

A página tem, de cima para baixo:
1. **O cartão Última manutenção**, o mesmo do Início. O clique abre o Histórico de manutenções.
2. **Otimizar**, em destaque, com o botão "Otimizar agora".
3. **Cuidar do PC:** Verificar o PC e Manutenção agendada.
4. **Se algo der errado:** Criar ponto de restauração, Histórico de mudanças e Restauração do Sistema (a janela do Windows).

O Histórico de manutenções e o Agendador de Tarefas não viram linha: chega-se a eles pelo cartão e pela busca.

**O Otimizar** tem 21 etapas, em ordem:
- **com a pessoa, no começo:** o ponto de restauração, desinstalar programas, remover aplicativos do Windows, o que abre com o Windows e as pastas Downloads, Documentos e Imagens;
- **as perguntas da parte automática:** o que atualizar no winget, que restos apagar e se a Lixeira é esvaziada;
- **sozinha, com o PC sem dormir:** antivírus, atualizações antecipadas, componentes do Windows, DISM e SFC, Windows Update, drivers, winget, navegadores, Store, limpeza, atalhos quebrados, restos de programas, rede, CHKDSK e otimização do disco;
- **com a pessoa, no fim:** a revisão dos ajustes do Windows. Depois vêm o resumo, o antes e depois e a sugestão de reiniciar.

**O Verificar o PC** lê o PC em 11 etapas e oferece corrigir, num clique, o que é seguro:
- **vem marcado:** temporários, atalhos quebrados e assinaturas velhas;
- **vem desmarcado:** o registro e o cache dos navegadores;
- **o resto** leva à tela de cada assunto.

**A Manutenção agendada** é uma tarefa mensal do Agendador de Tarefas, sem Administrador. Ela apaga os temporários com mais de 7 dias e salva um relatório.

## Designer (UX/UI)

| # | O que estava | Orientação | Como ficou |
|---|---|---|---|
| D1 | O Histórico de manutenções mostrava três números de espaço nas tendências: a variação média por manutenção, o que as manutenções liberaram e o espaço livre da primeira à última. Num histórico de teste, eram +1 GB, 12 GB e +1 GB: parecem se contradizer, porque a variação mistura o que a limpeza liberou com o que as atualizações ocuparam. | Um número para cada pergunta: quanto o WinForge liberou e como o disco andou. | Ficam "Liberado nas manutenções" (o mesmo número do Início) e "Espaço livre, da primeira à última". A variação de cada manutenção continua na linha dela, em "Últimas manutenções". |
| D2 | Uma etapa com problema na última manutenção e repetido nas anteriores aparecia duas vezes, cada uma com uma frase diferente para o mesmo link: "rode de novo em Atualizações > Instalar atualizações do Windows" e "abra Atualizações > Instalar atualizações do Windows e rode a etapa sozinha para ver o motivo". | A mesma ação, com as mesmas palavras. | As duas dizem "rode de novo em …". |
| D3 | Com o Agendador de Tarefas sem responder, a tela dizia "não foi possível consultar o Agendador de Tarefas", mas punha "Dia 1" em destaque, como numa tela sem tarefa. | Sem saber o estado, nada é a escolha recomendada. | Nenhum dia em destaque. Escolher um dia continua criando a tarefa. |
| D4 | Em espanhol, os estados da tarefa e da verificação estavam no masculino, embora "tarea" e "revisión" sejam femininos: "Tarea mensual: Activo", "Desactivado", "No programado"; "Última revisión: todavía no hecho". | Concordar com o nome do campo. | "Activa", "Desactivada", "No programada", "todavía no hecha" e "registrada". |

**Conferido e mantido:**
- um destaque por tela: o Otimizar na página, "Já fechei, começar" e "Começar" nas perguntas do Otimizar;
- as perguntas que podem custar algo começam no Não: reiniciar, continuar sem o ponto de restauração, continuar na bateria ou com outra conta, esvaziar a Lixeira, reiniciar o Explorador, agendar o reparo do disco e mexer na tarefa de outra conta;
- a faixa do Otimizar diz quais etapas tiveram problema quando são até duas, e quantas quando são mais;
- as telas só de consulta (os dois históricos e a Manutenção agendada sem mudança) terminam sem faixa de resultado;
- as descrições da página cabem em 60 letras nos três idiomas.

## Especialista Microsoft (MVP Windows)

**O que mudou**

| # | O que estava | Por que não é o melhor | Como ficou |
|---|---|---|---|
| M1 | No Verificar o PC, as referências quebradas do registro eram um ponto de atenção (amarelo), embora viessem desmarcadas. | A Microsoft não dá suporte a limpadores de registro (KB 2563254), e o WinForge já não as limpa no Otimizar (R13). Quase todo PC tem alguma: aceitar o que vinha marcado terminava sempre em "ainda pede atenção: Registro", que empurra a pessoa a limpar o que não precisa. | Viram informação: a linha mostra quantas são, e a correção continua na lista, desmarcada, para quem quiser. |
| M2 | Na parte automática do Otimizar, quando o Windows recusava o pedido de atualização da Store, a etapa abria a Microsoft Store por cima das outras. | A parte automática roda sem ninguém olhando; a etapa que dá certo já não abria a Store, justamente por isso. | No Otimizar, a etapa diz "abra a Store e clique em Obter atualizações". Pedida sozinha, em Atualizações, a página abre como antes. |

**Cada comando, conferido**

| Função | Como o WinForge faz | Veredito |
|---|---|---|
| Ponto de restauração | `Checkpoint-Computer` (MODIFY_SETTINGS), conferido na lista de pontos depois. O limite de um ponto por dia (`SystemRestorePointCreationFrequency`) fica em zero só durante a criação e volta ao que era. Respeita a política que desliga a Restauração do Sistema. Sem a Proteção do Sistema, oferece ligá-la (`Enable-ComputerRestore`): Não como padrão no Otimizar, Sim quando o ponto é pedido sozinho. | Certo. |
| Ponto e a Restauração pontual do Windows 11 | O Windows 11 ganhou a Restauração pontual, ligada por padrão em PCs que não são de empresa, com disco do sistema de 200 GB ou mais. Ela volta o disco inteiro, também os arquivos pessoais, e guarda os pontos por 72 horas. | O ponto do WinForge é o clássico, que não mexe nos arquivos pessoais e dura mais de 72 horas: continua sendo o certo antes de mudar o Windows. Há relatos de pessoas (não da Microsoft) de que, na 25H2, as duas funções dividem o espaço das cópias de sombra, que voltou a 2% do disco e apagou pontos antigos. Entrou no roteiro. |
| Preparação | Outra conta, reinício pendente (oferece reiniciar antes, com `shutdown /r /t 0`, sem `/f`), bateria, disco com menos de 10 GB e os programas abertos, pelo nome. | Certo: sem prazo, o Windows pergunta pelos arquivos sem salvar em vez de fechar à força. |
| O PC sem dormir | `SetThreadExecutionState` só durante a parte automática, fechado num `finally`, também quando uma etapa falha. | Certo. |
| Atualizações antecipadas | `IsContinuousInnovationOptedIn` = 0, com o valor de antes guardado para desfazer. Com a política da empresa (`SetAllowOptionalContent`), não mexe. | Certo: a opção traz as novidades antes de chegarem a todos; desligada, o Windows segue o ritmo normal, com as correções de segurança iguais. |
| Componentes, DISM e SFC | `DISM /StartComponentCleanup`, sem `/ResetBase` (o desinstalar atualizações continua). Depois, `DISM /RestoreHealth` e `sfc /scannow`. Ambos antes do Windows Update e de fora com um reinício da manutenção pendente (0x800F0806). | Certo. O reparo roda sempre, mesmo sem sinal de dano, uma decisão das builds 3.5x: custa tempo, não risco. |
| Store, navegadores e drivers | A Store pelo mesmo pedido do botão Obter atualizações (`UpdateScanMethod`, da ponte MDM). O Edge e o Chrome pelos atualizadores deles; o Firefox pelo winget, no idioma instalado. `pnputil /scan-devices` (Windows 10 2004 em diante). | Certo. A Store foi o achado M2. |
| CHKDSK e disco | `chkdsk /scan` com o Windows aberto. O reparo ao reiniciar, só com o sim, por `chkntfs /C` e `fsutil dirty set`. Depois, `defrag /O`, que escolhe TRIM no SSD e desfragmentação no HD. | Certo. O `chkdsk /spotfix` seria mais rápido no reinício, mas pede uma confirmação digitada; a marca de "sujo" é o caminho documentado sem perguntas. |
| Fim | Sempre sugere reiniciar (Não como padrão), dizendo quando é para concluir. Sem reiniciar, oferece o Explorador só quando um ajuste precisa dele. | Certo. |
| Manutenção agendada | Uma tarefa sem elevação (LeastPrivilege, com a conta logada):<br>• todo mês, às 12h;<br>• roda depois se o PC estava desligado;<br>• não começa na bateria e não acorda o PC;<br>• para em 1 hora.<br>No Windows 11, abre pelo `conhost --headless`, para o Terminal não mostrar janela. Recusa agendar de uma pasta que outras contas alteram. Só apaga o que está há mais de 7 dias numa pasta chamada Temp. | Certo. Os relatórios mensais não têm limite de quantidade, mas são um arquivo pequeno por mês: mantido. |
| Histórico de mudanças | O desfazer confere o que vem do diário: só os backups da pasta do WinForge, só os itens de inicialização que ele gerencia e só os recursos do catálogo. | Certo. |

## QA Sênior

**Como foi testado:** cada função da página rodou com o Windows simulado, nos três idiomas: 245 conferências em português, 247 em inglês e 252 em espanhol.
- **O plano do Otimizar:**
  - 21 etapas, sem repetir, cada uma com a sua ação;
  - a ordem: o ponto primeiro, o reparo antes do Windows Update, a limpeza antes do que vai para a Lixeira e a otimização do disco por último;
  - o registro fora;
  - o "rode de novo em …" de cada etapa leva a um item que existe.
- **O Otimizar de ponta a ponta, em 21 execuções:**
  - sem Administrador, e tudo certo;
  - programas abertos: começar assim mesmo, fechar e conferir de novo, ou cancelar;
  - reinício pendente: reiniciar antes, seguir ou recusar;
  - bateria, outra conta e disco quase cheio;
  - sem ponto de restauração: parar ou seguir;
  - a parte automática cancelada, com e sem mudanças;
  - uma etapa com erro, todas falhando e todas ignoradas;
  - o reinício necessário, o Explorador e o CHKDSK.

  Em cada uma: as etapas que rodaram, a ordem, o desfecho, as perguntas e a resposta padrão, o histórico (uma entrada por execução) e o PC voltando a poder dormir. Em inglês e em espanhol, também os nomes das etapas no resumo.
- **O desfecho:** oito combinações de etapas, o espaço ganho de 100 MB para cima e o reinício pendente.
- **O histórico de manutenções:**
  - vazio, com três manutenções (uma de perfil antigo) e o arquivo preso;
  - a ordem das seções e as tendências;
  - os nomes gravados em outro idioma.
- **O Verificar o PC (8 situações):**
  - tudo em dia;
  - o seguro corrigido;
  - as correções recusadas, uma correção que falha;
  - um ponto sem correção, com o botão para a tela dele;
  - uma etapa sem leitura e a maioria sem leitura;
  - o registro;
  - os 14 destinos, que existem.
- **A Manutenção agendada:**
  - o XML da tarefa: válido com caracteres especiais no nome da conta, cada configuração e os dias fora de 1 a 28;
  - o comando no Windows 10 e no 11;
  - os códigos de resultado do Agendador;
  - seis estados da tela (não agendada, ativa, desligada, script que sumiu, de outra conta e Agendador sem resposta);
  - criar, a pasta insegura, remover a da outra conta e remover;
  - a execução do mês: o temporário velho sai, o novo fica, uma TEMP fora de uma pasta Temp é recusada e o relatório que falha vira ressalva.
- **O ponto de restauração:** criado e conferido, a Proteção do Sistema desligada (pedido sozinho e no Otimizar) e a política.
- **O Histórico de mudanças:** vazio e só com mudanças sem desfazer.
- **Os textos:**
  - nenhum texto do português na tela em inglês e em espanhol, conferido contra as traduções;
  - nenhum marcador `{0}` sobrando.

**Achados**

| # | Severidade | O que acontecia | Como ficou |
|---|---|---|---|
| Q1 | Média | O Verificar o PC terminava "com ressalvas" pelo registro sempre que aceito como veio (é o M1). | Corrigido. |
| Q2 | Baixa | O dia em destaque com o Agendador sem resposta (é o D3). | Corrigido. |
| Q3 | Baixa | A etapa "Revisar os ajustes do Windows" não tinha o "rode de novo em" no histórico; o nome antigo dela, "Aplicar ajustes recomendados", tinha. | Leva a Ajustes do Windows > Aplicar ajustes recomendados. Três etapas continuam sem link, porque não existem sozinhas: organizar as pastas, as atualizações antecipadas e os navegadores. |

Cada conferência nova falha no código de antes e passa no de agora.

## Engenharia

| # | O que estava | Como ficou |
|---|---|---|
| E1 | Cada etapa do Otimizar tinha uma descrição e um tipo ("Com você" ou "Automático"), traduzidos nos três idiomas, que nenhuma tela mostra desde que o Otimizar passou a ser sempre o inteiro. As descrições que a R13 mudou também não apareciam. | Saíram. O que cada etapa faz ficou como comentário no código, ao lado dela. |
| E2 | Um comentário do Otimizar ainda falava do registro. | Atualizado. |

**Por dentro**
- **Maintenance.psm1:**
  - `New-WinForgePlanItem` só com Id, Phase, WithYou e Title;
  - `Get-WinForgeMaintenanceTrends` sem a média da variação, e com a etapa repetida usando "; rode de novo em {0}";
  - em `Get-WinForgeMaintenanceStepReference`, o nome "Revisar os ajustes do Windows".
- **Checkup.psm1:** `Get-WinForgeCheckupRegistry` devolve Info.
- **Software.psm1:** `Update-WinForgeStoreApps` só abre a Store fora do Otimizar.
- **Schedule.psm1:** `Show-WinForgeScheduledMaintenance` sem destaque quando o Agendador não responde.
- **Traduções:** 6 corrigidas em espanhol e 25 que saíram (22 do plano e 3 das tendências), 5.179 ao todo.

**Conferido na nuvem**
- **As conferências da Manutenção:** 245, 247 e 252, todas passando.
- **As de antes continuam passando:**
  - as 241 do Início nos três idiomas;
  - as 83 do QA geral, as 80 da R11 e as 60 da R12;
  - as 59 da R9 e as 52 da R10;
  - as 66 da QA, as 28 da integração e as 26 da R7;
  - as 84 ações rodando 336 vezes;
  - o motor de instalação, a atualização simulada e o Setup de verdade (da R13 para esta), e o pacote de suporte;
  - as traduções (5.179/5.179), as 160 referências nos três idiomas e a busca dos 102 itens;
  - nenhuma chamada com parâmetro que não existe, nenhuma função sem uso e nenhum aviso novo do analisador.

## O que só um PC mostra

Isto entrou no roteiro de conferência:
- **o Verificar o PC** num PC com referências quebradas no registro: a linha Registro como informação, desmarcada na lista, e o fim sem "ainda pede atenção: Registro" quando nada mais pede;
- **o Histórico de manutenções** depois de dois Otimizar: duas linhas de espaço, e a etapa repetida com "rode de novo em";
- **a Manutenção agendada em espanhol:** "Tarea mensual: Activa";
- **o ponto de restauração no Windows 11 25H2** com a Restauração pontual ligada: o ponto do Otimizar continua na Restauração do Sistema no dia seguinte, e o espaço das cópias de sombra (`vssadmin list shadowstorage`) não voltou sozinho a 2%.

## Fontes
- [Microsoft support policy for the use of registry cleaning utilities (KB 2563254)](https://support.Microsoft.com/kb/2563254)
- [Point-in-time restore for Windows (Microsoft Support)](https://support.microsoft.com/en-US/Windows/Experience/backup-recovery/point-time-restore-for-windows)
- [Windows 11 25H2: point-in-time restore seems to reset System Protection to 2% (Microsoft Tech Community, relato de pessoas)](https://techcommunity.microsoft.com/discussions/windows11/windows-11-25h2-point-in-time-restore-seems-to-reset-system-protection-to-2/4539095)
