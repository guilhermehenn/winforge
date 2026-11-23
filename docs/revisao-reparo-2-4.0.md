# WinForge 4.0 — segunda revisão do Reparo (R44)

**Data:** 21/11/2026 · **Versão:** Build 4.0 em preparação, depois da R43

**Pedido:** revisar a tela e a função Reparo com cinco olhares:
- **Analista de Produto Sênior:** avalia o todo.
- **Engenheiro de Software Sênior:** revisa o código, refatora, segue as boas práticas, tira o que não serve e melhora o desempenho.
- **Designer Sênior, com um Especialista em UX/UI:** revisam a tela, os botões, os textos e os fluxos; o engenheiro aplica.
- **MVP Windows:** confere se o Reparo segue as práticas da Microsoft, se cada função faz da melhor forma o que promete e se é robusto e estável.
- **QA Sênior:** testa tudo o que dá para testar, o óbvio e o que não é; o engenheiro aplica.

**De onde partiu:** a primeira revisão do Reparo (R19) foi antes do Destravar a impressão (R36), do desenho novo (R37) e da revisão de UX (R38). Esta olhou a página inteira de hoje, as sete ações dela e o que elas usam de outras páginas: ligar e parar serviços (o mesmo do Corrigir o Windows Update e do Acertar a data e a hora) e o resultado pelo código de saída (o mesmo da limpeza dos componentes do Windows).

**Resultado:** 10 achados, todos corrigidos.

| Olhar | Achados |
|---|---|
| Produto | 2: o reparo completo numa bateria, sem aviso e com Sim como padrão; e o Otimizar a unidade prometendo um disco mais rápido, quando o Windows já faz isso toda semana |
| Engenharia | 2: um parâmetro que ninguém lia no resultado pelo código de saída; e o disco de cada unidade do CHKDSK lido duas vezes por unidade |
| Designer e UX/UI | 3: os botões Sim e Não nas sete perguntas; o Destravar a impressão com o mesmo ícone do SFC; e as ações de disco separadas pelas de dispositivos |
| MVP Windows | 1: ligar um serviço esperava sem limite, e um Spooler de Impressão preso em "Iniciando" parava a tela |
| QA | 2: o Spooler parado era "reiniciado" na tela inteira; e um serviço ainda "Parando" ficava desligado |

Nada rodou num Windows de verdade. A conferência foi feita na nuvem: a página com as funções de verdade da janela sobre o WPF simulado, e as ações com o Windows simulado (o DISM, o SFC, o CHKDSK, o defrag, o pnputil, os discos e os barramentos, a bateria e os serviços, com os estados de um serviço de verdade) e, no Destravar a impressão, a pasta da fila de verdade. O que só um PC mostra entrou no roteiro de conferência (§35).

## O Reparo hoje

De cima para baixo:
1. **Arquivos do Windows:** Reparar o Windows (DISM + SFC), em destaque; Reparar imagem e componentes (DISM); Verificar arquivos do sistema (SFC).
2. **Disco e dispositivos** (na ordem nova): Verificar o sistema de arquivos (CHKDSK); Otimizar a unidade do sistema; Detectar dispositivos e drivers; Destravar a impressão.
3. **Ferramentas do Windows:** Restauração do Sistema e Recuperação, que abrem as do Windows.

As sete ações pedem Administrador e mostram o escudo.

## Analista de Produto

| # | O que estava | Por que importa | Como ficou |
|---|---|---|---|
| P1 | O Reparar o Windows (DISM + SFC) sozinho, num notebook na bateria, perguntava "Iniciar o reparo agora?" com Sim como padrão e sem aviso. O mesmo reparo dentro do Otimizar já avisa da bateria e começa no Não. | O reparo leva de 20 a 60 minutos (mais num HD). A carga pode acabar no meio, com o Windows trocando arquivos do sistema. | Na bateria, o resumo diz "Ligue o carregador: o reparo pode levar até uma hora." e a pergunta começa no Não ("Cancelar"), como no Otimizar. Na tomada, carregada ou num desktop, nada muda. Dentro do Otimizar, o aviso continua sendo o dele, uma vez só. |
| P2 | O Otimizar a unidade dizia "Deixa o disco mais rápido; o Windows escolhe o jeito certo". | O Windows já otimiza as unidades sozinho uma vez por semana. Rodar de novo raramente muda o que a pessoa sente, e a frase prometia o contrário. | "O que o Windows já faz toda semana, feito agora", e no detalhe "(o TRIM num SSD, desfragmentar num HD)". As palavras de busca ficaram: "desfragmentar", "trim" e "defrag" continuam trazendo a ação. |

**Conferido e mantido:**
- **O reparo completo em destaque,** com o DISM antes do SFC, como a Microsoft manda, e o DISM e o SFC sozinhos logo abaixo, para quem sabe o que quer.
- **A pergunta do DISM e do SFC no Sim:** consertam os arquivos do Windows e não tocam nos da pessoa. O reparo do disco agendado continua com pergunta à parte, no Não.
- **Destravar a impressão** com o reiniciar em destaque e o apagar a fila em vermelho, com a conta dos documentos que não serão impressos (R36).
- **Uma faixa no alto com o reinício pendente** ficou de fora: a leitura que a página teria não vê tudo o que o DISM vê, e a faixa poderia dizer "nada pendente" com o reparo recusando logo depois. O reparo já confere antes de começar e diz "Reinicie antes de reparar".

## Engenheiro de Software

| # | O que estava | Como ficou |
|---|---|---|
| E1 | `Get-WinForgeExitCodeResult` recebia o texto da saída (`-OutputText`) e não o lia ("existe só para ter a mesma assinatura"). Quatro chamadas passavam o texto à toa, uma delas na Limpeza. O cabeçalho do módulo dizia que o Reparo era "DISM, SFC, CHKDSK e otimização" e que "todas as ações" aceitam `-Embedded`, e o Destravar a impressão não aceita. | O parâmetro saiu, e as quatro chamadas passam só o código. O cabeçalho cita as seis ações do módulo e diz quais entram no Otimizar. |
| E2 | Na lista de unidades do CHKDSK, cada unidade além da do Windows pedia ao Windows a partição e o disco (`Test-WinForgeDriveExternal`), dois trabalhos com prazo de 60 segundos cada. Com o armazenamento sem responder, cada unidade esperava o prazo: com três discos além do do Windows, a lista levava três minutos para aparecer. | `Get-WinForgeExternalDriveLetters` (nova) lê as partições e os discos uma vez, para todas as unidades, e devolve as que estão num disco externo (USB, FireWire, SD ou MMC). São dois pedidos no máximo, e nenhum quando só há a unidade do Windows; com o armazenamento sem responder, a lista espera um prazo só, qualquer que seja o número de discos. `Test-WinForgeDriveExternal` saiu. |

**Por dentro:**
- **Repair.psm1:**
  - `Get-WinForgeExitCodeResult` só com o código; o cabeçalho do módulo;
  - `Get-WinForgeChkdskDrives` com `Get-WinForgeExternalDriveLetters` (nova);
  - a bateria e o verbo em `Invoke-WinForgeDismAndSfc`; o verbo nas outras perguntas;
  - `Reset-WinForgePrintQueue` com o Spooler parado (Q1).
- **WindowsUpdate.psm1:** `Start-WinForgeService` com prazo (M1 e Q2), usado no Destravar a impressão, no Corrigir o Windows Update e no Acertar a data e a hora.
- **Cleanup.psm1:** o analisador da limpeza dos componentes declara só o código, e a chamada a `Get-WinForgeExitCodeResult` vai sem o texto.
- **GuiDesign.psm1 e Navigation.psm1:** o ícone do Destravar a impressão, a ordem do grupo e a frase do Otimizar a unidade.
- **Traduções:** 5.584 textos (16 novos e 2 que saíram de uso). O número de funções não mudou (1.290): entrou uma e saiu uma.

## Designer e Especialista em UX/UI

| # | O que estava | Orientação | Como ficou |
|---|---|---|---|
| D1 | As sete perguntas da página tinham os botões Sim e Não. É a UX21 da revisão de UX, aplicada nesta página. | Os botões dizem o que fazem, como a Microsoft orienta ("Use specific responses to the main instruction or content as button text"). | Reparar o Windows e o DISM: "Reparar" e "Cancelar". O SFC e o CHKDSK: "Verificar" e "Cancelar". O reparo do disco: "Agendar" e "Agora não". Otimizar a unidade: "Otimizar" e "Cancelar". Detectar dispositivos: "Procurar" e "Cancelar". Destravar a impressão: "Reiniciar" (ou "Ligar", Q1) e "Cancelar". O padrão de cada pergunta não mudou (fora o reparo completo na bateria, P1), e o menu de texto continua com S/N. |
| D2 | O Destravar a impressão tinha o ícone de documento, o mesmo do Verificar arquivos do sistema (SFC), duas linhas acima. | Um ícone por ação na página. | O ícone de lista, a fila de impressão. Nenhum ícone se repete na página. |
| D3 | No grupo Disco e dispositivos, as duas ações de disco ficavam separadas: CHKDSK, Detectar dispositivos, Destravar a impressão e, por último, Otimizar a unidade. | A ordem segue o nome do grupo. | CHKDSK e Otimizar a unidade, depois Detectar dispositivos e Destravar a impressão. |

**Conferido e mantido:**
- **As descrições** cabem em 60 letras nos três idiomas, e a página tem um destaque só.
- **As faixas de cada ação,** revistas na R19 (as falhas do DISM e do SFC, o reinício, o agendamento recusado, a otimização que falha), e as do Destravar a impressão (R36).
- **A lista de unidades do CHKDSK:** a do Windows em destaque e como padrão, o disco externo dito ("disco externo (USB)"), e a escolha valendo como a confirmação.

## MVP Windows

| # | O que estava | Por que importa | Como ficou |
|---|---|---|---|
| M1 | `Start-WinForgeService` ligava o serviço com o `Start-Service`, que espera o serviço sair de "Iniciando" sem limite de tempo. | O Spooler de Impressão fica preso em "Iniciando" com um driver de impressora com defeito, justo o caso de quem usa o Destravar a impressão: a tela parava em "ligando o Spooler de Impressão" até alguém clicar em Parar. O mesmo valia para o Corrigir o Windows Update e o Acertar a data e a hora. A Microsoft espera com prazo no exemplo dela de como ligar um serviço ("Do not wait longer than the wait hint"). | O pedido vai direto ao Windows (`ServiceController.Start`) e a espera tem prazo: 30 segundos, o mesmo do parar. Passado o prazo, o erro diz "continua ligando depois de 30 segundos"; um serviço que cai ao ligar dá "parou logo depois de ligar" em poucos segundos, sem esperar o prazo inteiro; um pausado é continuado, porque o Windows recusa ligar um pausado. No Destravar a impressão, a faixa diz "O Spooler de Impressão não ligou" e pede reiniciar o PC. |

**Conferido**, com as fontes no fim:
- **O DISM antes do SFC:** "You should run DISM prior to running the System File Checker." É a ordem do reparo completo, com os mesmos comandos (`DISM.exe /Online /Cleanup-image /Restorehealth` e `sfc /scannow`).
- **Não interromper:** a Microsoft pede para não fechar a janela até a verificação chegar a 100%. O resumo diz para não desligar o PC, e o PC não dorme no meio (o pedido de manter acordado vale até o fim).
- **A otimização semanal:** "By default, Windows automatically optimizes your drives once a week", e os SSDs são "trimmed". O `/O` deixa o Windows escolher, como antes; a frase nova (P2) diz isso.
- **Esperar um serviço parar antes de ligá-lo** e esperar enquanto ele está "Iniciando", como no exemplo da Microsoft ("Wait for the service to stop before attempting to start it"). O Q2 nasceu daí.
- **O restante da R19 continua valendo:** o CHKDSK online (`/scan`) e o reparo agendado com o `chkntfs /C` e o `fsutil dirty set`, os códigos do CHKDSK e do DISM, e a leitura dos dispositivos e dos discos com prazo.
- **Robusto:** toda espera da página tem prazo (60 segundos para os discos e os dispositivos, 30 para parar e para ligar um serviço), e sem resposta a tela diz o que faltou.

## QA Sênior

**Como foi testado:** uma bateria nova do Reparo, 92 conferências em cada idioma.
- **A página (A):** a ordem do grupo, na lista e na janela; o ícone de cada ação, sem repetição; a frase do Otimizar a unidade e a antiga fora; as descrições em 60 letras; a busca por "trim", "defrag" e "desfragmentar".
- **Os botões (B):** as sete perguntas, cada uma com o verbo, o Cancelar e o padrão; cancelar não roda nada; o Enter não agenda o reparo do disco; a pergunta na janela de verdade; e uma leitura do código que confere que nenhuma pergunta do módulo ficou sem o verbo.
- **A bateria (C):** descarregando e baixa (aviso e Não), na tomada, carregada e num desktop (sem aviso e Sim), com Sim na bateria (o reparo roda) e dentro do Otimizar (sem pergunta nem aviso de novo).
- **O código de saída (D):** 0, 3010, 5, 0x800F081F e um código do DISM sem frase própria; a faixa da otimização que falha.
- **O CHKDSK com vários discos (E):** a do Windows, um disco interno, um USB, um cartão SD e um exFAT; uma partição sem letra num disco USB; o Windows num disco USB; só a unidade do Windows; o armazenamento sem responder; o reparo agendado num disco externo.
- **Ligar um serviço (F):** já ligado, parado, pausado, preso em "Iniciando", caindo ao ligar, desativado, inexistente, ainda "Parando" (que para depois ou não para) e já iniciando por outro; o Destravar a impressão com o Spooler preso.
- **O Spooler parado (G):** sem e com documentos, cancelar, apagar e ligar, um arquivo da fila que não sai, e o Fax, que depende do Spooler (parado fica parado; ligado volta a ligar).
- **Os textos (K)** nos três idiomas.

**Achados**

| # | O que estava | Como ficou |
|---|---|---|
| Q1 | Com o Spooler de Impressão parado (a tela mostra "Parado", em amarelo), a pergunta era "Reiniciar o Spooler de Impressão agora?", as opções "Reiniciar o Spooler" e "Apagar a fila e reiniciar", e a faixa e o Histórico de mudanças diziam "Spooler de Impressão reiniciado". Nada foi reiniciado: o Spooler foi ligado. | Com ele parado, a tela diz "ligar" do começo ao fim: "Ligar o Spooler de Impressão agora?", com "Ligar" e "Cancelar"; "Ligar o Spooler" e "Apagar a fila e ligar"; "Opção (ENTER = só ligar)"; a faixa "Spooler de Impressão ligado"; no Histórico, "fila esvaziada (2 documentos) e Spooler de Impressão ligado". Com ele ligado, tudo como antes. |
| Q2 | Um serviço ainda "Parando" (quando o pedido de parar passa dos 30 segundos, no Corrigir o Windows Update e no Destravar a impressão) recusa o pedido de ligar. O `Start-Service` de antes falhava, e o serviço ficava desligado quando terminava de parar; a primeira versão do M1 também não o ligava. | `Start-WinForgeService` espera ele parar e então pede para ligar, dentro do mesmo prazo. Se ele não terminar de parar, o erro diz "continua parando depois de 30 segundos". Um serviço que outro programa já está ligando é esperado, sem pedido repetido. |

Os testes também acharam os do produto (P1 e P2), os do designer (D1 a D3) e o do MVP (M1).

**As baterias antigas que simulam estes comandos:** a do Reparo (R19) e a das Atualizações (R20) imitavam o Windows com as chamadas que o código fazia. Duas trocas: o `Get-Partition` e o `Get-Disk` simulados respondem também sem filtro (todas as unidades de uma vez, E2), e os serviços simulados ganharam os métodos `Start`, `Continue` e `Refresh` (M1). Uma conferência da R20 contava os pedidos de ligar depois de um serviço que não para; os outros nem chegam a parar, e o código novo não pede para ligar o que já está ligado. Ela passou a conferir que todos terminam ligados. As duas adaptadas passam também no código de antes (114 e 112).

**Contra o código de antes (R43):** cada conferência das correções falha (36), e as 56 do que foi mantido passam (as perguntas que já começavam no Sim, a lista de unidades do CHKDSK, o Spooler ligado, o Fax que volta, os serviços já ligados, parados ou desativados). Com o Spooler preso em "Iniciando", a tela de antes só termina quando a simulação desiste, em 45 segundos; no Windows, não terminaria.

**37 defeitos de propósito,** e as conferências pegam todos: a ordem do grupo, o ícone e a frase antigos; cada pergunta sem o verbo ou com o verbo de outra, o reparo do disco com Sim como padrão e o `Invoke-WinForgeTool` sem repassar o verbo; a bateria sem o aviso, sem o Não como padrão ou lida ao contrário; o texto de volta no resultado pelo código e o 3010 virando falha; o cartão SD fora dos externos, os discos lidos mesmo só com a unidade do Windows, a do Windows marcada como externa e a partição sem letra na lista; o prazo maior, a queda percebida só no fim do prazo, o pausado recebendo o pedido de ligar, o pedido repetido a cada queda, o serviço parando ou já ligando recebendo o pedido, a frase de "ligando" no serviço parando e o Spooler com um prazo maior; e o Spooler parado tratado como ligado na pergunta, nas opções, no botão, na faixa, no Histórico e na ressalva, e os dependentes sem voltar. Na primeira rodada, um defeito não foi aplicado (o texto procurado estava errado) e três foram pegos por uma falha da própria conferência (a parte da bateria usava uma função da parte dos botões); corrigidos os dois, as conferências de verdade pegaram os quatro.

**Nada do que funcionava quebrou:** as baterias das 14 páginas revistas, com os mesmos números da R43 (a do Reparo da R19, 114, 121 e 121, e a das Atualizações da R20, 112, 119 e 119, depois da adaptação acima; a Rede com a mesma conferência antiga); a das seis funções novas da R36 (257 em cada idioma), que passa pelo Destravar a impressão e pelo Acertar a data e a hora; a do Início da R40 (115), a da Manutenção da R41 (67), a da Limpeza da R42 (97) e a do Desempenho da R43 (94) em cada idioma; a da Manutenção da R14 (243, 245 e 250) e a do Início da R13 (241); as mensagens da janela (72 em cada idioma); instalar, atualizar com um clique, o pacote de suporte e o Setup de verdade, da R43 para esta; nenhuma função sem uso (1.508, uma nova e uma que saiu). O PSScriptAnalyzer continua com 247 avisos: saiu o do parâmetro que ninguém lia (E1) e entrou um do mesmo tipo, o texto no analisador da busca de dispositivos, que recebe os valores pela posição e só usa o código e o último. O analisador da limpeza dos componentes passou a declarar só o código.

## O que só um PC mostra

Isto entrou no roteiro de conferência (§35):
- **Os botões** das sete perguntas nos três idiomas, sem cortar o texto, e a do reparo do disco sem botão em destaque (o padrão é o Não).
- **O reparo completo num notebook** na bateria e na tomada: o aviso e o padrão.
- **Destravar a impressão com o Spooler parado** (`net stop spooler` antes): a pergunta, a faixa e o Histórico dizendo "ligado"; e, se der para provocar, com o Spooler preso em "Iniciando" (uma impressora com driver com defeito), a tela terminando em 30 segundos.
- **O CHKDSK com um disco externo pela USB e um cartão de memória:** a lista no mesmo tempo de antes, ou menos, e o externo dito.
- **O Corrigir o Windows Update** com um serviço que demora a parar.
- **A página:** a ordem nova do grupo e o ícone do Destravar a impressão nos dois temas.

## Fontes
- [Use the System File Checker tool to repair missing or corrupted system files](https://support.microsoft.com/help/929833) (Microsoft): "You should run DISM prior to running the System File Checker.", os comandos `DISM.exe /Online /Cleanup-image /Restorehealth` e `sfc /scannow`, e "Do not close this Command Prompt window until the verification is 100% complete."
- [Defragment/optimize your PC drives](https://support.microsoft.com/en-us/help/17126/) (Microsoft): "By default, Windows automatically optimizes your drives once a week", e os SSDs são "trimmed".
- [Starting a Service](https://learn.microsoft.com/windows/win32/services/starting-a-service) (Microsoft): "Wait for the service to stop before attempting to start it.", "Check the status until the service is no longer start pending." e "Do not wait longer than the wait hint."
- [ServiceController.WaitForStatus](https://learn.microsoft.com/en-us/dotnet/api/system.serviceprocess.servicecontroller.waitforstatus) (Microsoft): sem prazo, "Infinitely waits for the service to reach the specified status."; com prazo, o erro de tempo esgotado.
- [StartServiceW function](https://learn.microsoft.com/en-us/windows/win32/api/winsvc/nf-winsvc-startservicew) (Microsoft): o pedido de ligar um serviço que não está parado volta com "An instance of the service is already running."
- [Dialog controls](https://learn.microsoft.com/windows/apps/design/controls/dialogs-and-flyouts/dialogs) (Microsoft): "Use specific responses to the main instruction or content as button text".
