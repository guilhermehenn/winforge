# WinForge 4.0 — revisão do Início (R13)

**Data:** 19/11/2026 · **Versão:** Build 4.0 em preparação, depois da R12

**Pedido:** juntar quatro olhares para a tela e a função de Início:
- **Analista de UX/UI Sênior (designer):** revisa cada detalhe da interface e orienta o engenheiro.
- **Especialista Microsoft (MVP Windows):** confere se os comandos e as alterações no Windows são feitos da melhor forma disponível hoje, de modo seguro e robusto, e se fazem sentido e mudam o que devem no PC.
- **QA Sênior:** testa todas as funções da tela.
- **Engenheiro de Software Sênior:** aplica as correções.

**Resultado:** 10 achados, todos corrigidos.

| Olhar | Achados |
|---|---|
| Designer | 4: um botão repetido, o anel da nota que não cresce com o texto, dois textos que não cabem e um espaçamento diferente |
| MVP Windows | 5: o Otimizar refazia a rede de quem não tem problema de rede, instalava drivers opcionais e limpava o registro; e dois textos não traduzidos |
| QA | 1 novo: as assinaturas nunca atualizadas apareciam de um jeito em cada tela. Os testes também acharam três dos acima (D2, D3 e M5). |

Nada rodou num Windows de verdade. As leituras foram simuladas, e o que só um PC mostra entrou no roteiro de conferência.

## O Início hoje

A tela tem, de cima para baixo:
1. **Os avisos de destaque.** Por exemplo, quando o WinForge foi aberto com outra conta.
2. **A nota de saúde:**
   - o anel com a nota, a frase do estado e a hora da leitura, com o botão de ler de novo (F5);
   - os botões **Verificar o PC** e **Otimizar**;
   - embaixo, um ponto de atenção por linha, cada um com o botão que o resolve.
3. **"Deixe o WinForge pronto"**, enquanto faltar o atalho, o monitor ou a manutenção mensal.
4. **Seu PC:** seis cartões (Disco do sistema, Proteção, Windows, Reinício pendente, Última manutenção e Bateria). Cada um leva à tela do assunto.
5. **Com o WinForge neste PC:** o espaço liberado, as manutenções feitas e as mudanças anotadas.

A leitura roda em sete etapas, num leitor em segundo plano: sessão, disco, reinício, manutenção, manutenção agendada, bateria e proteção. Cada cartão aparece assim que a etapa dele termina. Uma etapa que falha vira "Não foi possível ler" sem apagar as outras. Uma etapa presa é abandonada no tempo-limite.

A nota começa em 100 e cada ponto desconta o peso dele. Um ponto grave (peso 20 ou mais) segura a nota em 74. O que não pôde ser lido tira o verde.

O Início só lê o PC. Quem muda alguma coisa são os botões: o Otimizar (a manutenção completa), o Verificar o PC e o botão de cada ponto, que leva à tela que resolve.

## Designer (UX/UI)

| # | O que estava | Orientação | Como ficou |
|---|---|---|---|
| D1 | Com a manutenção atrasada (o ponto mais comum, que volta todo mês), a nota mostrava **dois botões "Verificar o PC"**: o da nota e o da linha do ponto, este em destaque. | Um botão por ação, e um destaque só. O ponto que se resolve com um botão da nota não ganha outro igual. Se ele é o mais pesado, o botão da nota fica em destaque. | `Get-WinForgeHealthActionPlan` decide os botões: qual fica em destaque e quais linhas têm botão próprio. A linha sem botão mantém a altura das outras. |
| D2 | O anel da nota tinha 124 px fixos, e o número cresce com o tamanho do texto do Windows. A 150%, o "100" encosta no anel; a 225%, passa por cima dele. | O anel cresce com o texto. | O anel acompanha o tamanho do texto do Windows. A espessura cresce mais devagar, para não pesar. |
| D3 | Dois textos não cabiam no cartão estreito (252 px):<br>• no Windows Server, "Windows Server 2022 Standard 21H2" terminava em reticências;<br>• em inglês, "3 items needing attention" também. | Cada texto do cartão numa linha, sem reticências na largura mínima, nos três idiomas. | "Windows Server 2022" no cartão, com a edição e a versão na dica. Em inglês, "3 items to check". Todos os textos dos cartões foram medidos nos três idiomas. |
| D4 | O título "Com o WinForge neste PC" tinha 24 px em cima e 10 embaixo; o "Seu PC", 22 e 12. | O mesmo ritmo entre as seções. | 22 e 12 nos dois. |

**Conferido e mantido:**
- um destaque por tela;
- o leitor de tela ouve a nota e cada cartão, e a frase nova da nota chega sozinha;
- a barra cinza no lugar do valor enquanto lê;
- o cartão da bateria só aparece em notebooks;
- a frase inteira na dica de cada cartão;
- a nota "parece bem" quando algo ficou sem leitura;
- os botões ao lado da frase na janela larga, embaixo dela na estreita.

## Especialista Microsoft (MVP Windows)

**As leituras do Início**

| Cartão | Fonte | Veredito |
|---|---|---|
| Disco do sistema | `DriveInfo.AvailableFreeSpace` da unidade do Windows | Certo: é o espaço livre para a conta, com cota, o mesmo do Explorador. Os limites de 10 e 20 GB acompanham o que uma atualização de versão pede. |
| Proteção | `Get-MpComputerStatus`, a Central de Segurança (`root\SecurityCenter2`, bit 0x1000 de `productState`) e `Get-NetFirewallProfile -PolicyStore ActiveStore` | Certo:<br>• o modo passivo e o "EDR Block" são reconhecidos;<br>• a idade 65535 é tratada como "nunca atualizado";<br>• o firewall vem com a política da empresa somada e com o firewall de outro fabricante;<br>• o perfil Domínio só conta num PC de domínio. |
| Windows | Win32_OperatingSystem (com o Registro de reserva), `DisplayVersion` e o catálogo de suporte | Certo. A atualização do mês foi conferida contra as notas da Microsoft: KB5127648, de 13/10/2026, nas builds 26100, 26200 e 26300.9711; KB5126657, de outubro de 2026, na 19045.7807. O atraso só conta 35 dias depois, o máximo que a pausa do Windows Update permite. |
| Reinício pendente | CBS (`RebootPending`, `PackagesPending`, `RebootInProgress`), `WindowsUpdate\Auto Update\RebootRequired`, `UpdateExeVolatile`, o nome novo do PC e a entrada num domínio | Certo. `PendingFileRenameOperations` e `Services\Pending` são sinais fracos e não pedem reinício sozinhos, o que evita o falso positivo mais comum. A tela de destino oferece reiniciar, com Não como padrão. |
| Última manutenção | Os arquivos do próprio WinForge | Certo. O monitor conta igual, e uma data no futuro não cala o lembrete. |
| Bateria | Win32_Battery e `root\wmi` (duas baterias) | Certo. O chassi decide se é notebook, e um nobreak USB não vira bateria. Achado M5: a situação "Carregando" não era traduzida. |

**Os botões que mudam o PC (o Otimizar)**

| # | O que o Otimizar fazia | Por que não é o melhor | Como ficou |
|---|---|---|---|
| M1 | A cada vez, mesmo com a internet funcionando, renovava o IP e redefinia o Winsock e o TCP/IP. | Esses comandos resolvem problemas de rede; a Microsoft os indica para isso. Num PC que funciona, não melhoram nada e pedem reinício. Também podem desfazer uma VPN de programa, um antivírus que filtra a rede e configurações postas à mão. | Com a internet funcionando, só o DNS é limpo, o que não corta nada. Funcionando quer dizer: os testes passam, os nomes de sites resolvem ou o Windows diz que há internet, como numa rede com proxy. O reparo inteiro fica para quando a internet falha. |
| M2 | Instalava sozinho os drivers opcionais do Windows Update. | A própria tela do Windows diz que eles servem para um problema específico; nos outros casos, as atualizações automáticas mantêm os drivers em dia. Num PC que funciona, um opcional pode trocar o driver do fabricante por um pior. A tela Atualizar drivers do próprio WinForge já os deixa desmarcados. | Ficam de fora, com o nome na lista do que ficou de fora e uma linha dizendo onde achá-los: Atualizações > Atualizar drivers. Os drivers que o Windows Update instala por conta própria continuam. |
| M3 | Limpava o registro em toda manutenção. | A Microsoft não dá suporte a limpadores de registro (KB 2563254), e a limpeza não deixa o PC mais rápido. A do WinForge é cuidadosa (só referências quebradas, com backup), mas não tem por que rodar sozinha todo mês. | Saiu do Otimizar. Continua em Limpeza > Limpar o registro e no Verificar o PC, desmarcada, para quem quiser. |
| M4 | "(firmware opcional)" aparecia em português na tela em inglês e em espanhol. | — | Traduzido. |
| M5 | "Carregando", da bateria, também. E a regra do cartão amarelo comparava o texto traduzido. | — | Traduzido. A leitura devolve também um código (`Charging`, `Battery`, `AC`) para a regra. |

**Conferido e mantido no Otimizar:**
- o ponto de restauração antes de tudo;
- o DISM e o SFC antes do Windows Update, e de fora com um reinício da manutenção pendente;
- a limpeza dos componentes sem `/ResetBase`, o que mantém o desinstalar atualizações;
- o CHKDSK em `/scan`, com o Windows aberto;
- a otimização do disco: TRIM no SSD, desfragmentação no HD;
- as prévias e uma versão nova do Windows de fora;
- tudo apresentado antes da parte automática, com confirmação.

**Desempenho:** a etapa da bateria perguntava de novo ao WMI se o PC é notebook, o que a etapa da sessão já tinha lido. Ela passou a usar essa leitura: são duas consultas a menos a cada leitura do Início.

## QA Sênior

**Como foi testado:** cada etapa do Início rodou com o Windows simulado, em 241 conferências por idioma, nos três idiomas:
- **sessão e suporte (15 casos):** Windows 11 em dia e atrasado, fim do suporte em breve e hoje, Windows 10 sem suporte, com o ESU disponível (conferido ou não) e com ESU, Windows Server, sem build, suporte que falhou, outra conta com e sem nome;
- **disco (10 casos):** de 0 a 3 TB livres, mais o valor negativo e o texto no lugar do número;
- **reinício:** sim, não e o Registro ilegível;
- **manutenção (12 casos):** nenhuma, verificação recente e antiga, em dia, com etapas pedindo atenção, atrasada, no futuro, registros com resultados nulos e o registro ilegível. Em cada caso, o monitor e o Início concordam;
- **proteção (15 casos):** o Defender ativo, sem tempo real, com assinaturas velhas e nunca atualizadas, com ameaça; um e três outros antivírus; modo passivo; desligado; sem leitura do antivírus, do firewall e das ameaças; tudo de uma vez. Em cada caso, o cartão conta o mesmo que a tela Estado da proteção;
- **bateria (7 casos):** desktop, notebook sem leitura, carregando, 10% fora da tomada, 15% na tomada, 10% carregando e 255%;
- **manutenção agendada (5 casos):** sem tarefa, em dia, desligada, de outra pasta e falhou;
- **a nota:** os limites (90, 75 e 50), o teto dos graves, nunca abaixo de zero, a leitura incompleta, a ordem dos pontos e "nada lido";
- **tudo junto:** os seis cartões, o JSON da verificação rápida e o destino de cada cartão e de cada ponto, que existe na navegação;
- **os textos:** cada valor e complemento dos cartões, medido na largura mínima nos três idiomas, e nada em português na tela em inglês e em espanhol.

**Achados**

| # | Severidade | O que acontecia | Como ficou |
|---|---|---|---|
| Q1 | Média | Com as assinaturas do Defender nunca atualizadas, o Início descontava da nota ("O antivírus nunca foi atualizado"), mas o cartão Proteção dizia "Protegido", em verde. A tela Estado da proteção não avisava, e o Verificar o PC dizia "em dia". | As três telas avisam, e o Verificar o PC oferece a correção, marcada. A linha Assinaturas diz "Nunca atualizadas", em vez de "Não foi possível ler". |
| Q2 | Baixa | "Carregando" em português na tela em inglês e em espanhol (é o M5). | Corrigido. |
| Q3 | Baixa | Os dois textos que não cabiam (D3). | Corrigido. |
| Q4 | Baixa | O anel a 150% e 225% (D2), pela leitura do código. | Corrigido; só um PC confirma. |

## Engenharia

**Por dentro**
- **Home.psm1:**
  - `Read-WinForgeHomeBattery` usa a leitura da sessão e o código da bateria;
  - `Get-WinForgeHomeWindowsShortName` encurta o Windows Server;
  - o cartão do Windows Server sai sem a versão ao lado.
- **GuiDesign.psm1:** `Get-WinForgeHealthActionPlan`.
- **WinForge.Gui.ps1:**
  - `New-GuiHealthButtons -PrimaryId`;
  - `Update-GuiHealthCard` com o plano de botões;
  - `New-GuiScoreRing` na escala do texto;
  - a margem do título "Com o WinForge neste PC".
- **Diagnostics.psm1:** `Get-WinForgeBatteryState` traduz "Carregando" e devolve `Code`.
- **Security.psm1:** o aviso das assinaturas nunca atualizadas e a linha "Nunca atualizadas".
- **Checkup.psm1:** a correção das assinaturas também quando elas nunca foram atualizadas.
- **Maintenance.psm1:**
  - o registro saiu do plano, com a etapa e `Invoke-WinForgeMaintenanceRegistry`;
  - as descrições novas da rede e do Windows Update.
- **Network.psm1:** no Otimizar, só o DNS com a rede funcionando.
- **WindowsUpdate.psm1:** no Otimizar, as opcionais de fora (drivers, prévias e firmware), com o aviso de onde achar os drivers.
- **Traduções:** 13 textos novos ou mudados, 5.204 ao todo.

**Conferido na nuvem**
- **As 241 conferências do Início nos três idiomas, todas passando.** Entre elas estão as das correções:
  - a bateria lida do Windows, com o código e o texto traduzido;
  - as assinaturas nunca atualizadas nas três telas;
  - o nome curto do Windows Server;
  - o plano de botões da nota (sem pontos, o mais pesado com e sem botão próprio, oito pontos com um destaque só);
  - o registro fora do Otimizar e Limpar o registro ainda na Limpeza;
  - a rede do Otimizar em cinco situações: funcionando, com proxy, o Windows dizendo que há internet, com VPN e falhando;
  - o Windows Update do Otimizar com seis atualizações (a do mês, o driver automático, o opcional, a prévia, o firmware e a versão nova): só as duas primeiras são instaladas.
- **Os textos dos cartões** medidos nos três idiomas, todos cabendo na largura mínima.
- **As de antes continuam passando:**
  - as 83 do QA geral, as 80 da R11 e as 60 da R12;
  - as 59 da R9 e as 52 da R10, com duas conferências de texto da R9 e da R10 adaptadas ao código novo dos botões (o que elas conferem, Verificar o PC antes do Otimizar na nota, continua valendo);
  - as 66 da QA, as 28 da integração e as 26 da R7;
  - as 84 ações rodando 336 vezes;
  - o motor de instalação, a atualização simulada e o Setup de verdade (da R12 para esta), e o pacote de suporte;
  - as traduções (5.204/5.204) e as 160 referências nos três idiomas;
  - nenhuma chamada com parâmetro que não existe e nenhuma função sem uso.

## O que só um PC mostra

Isto entrou no roteiro de conferência:
- **a nota com a manutenção atrasada:** um botão "Verificar o PC" só, em destaque;
- **o anel** com o texto do Windows a 150% e a 225%;
- **o Otimizar:**
  - com a internet funcionando, só o DNS é limpo e o PC não pede reinício por causa da rede;
  - com o Wi-Fi sem internet, o reparo inteiro;
  - num PC com driver opcional no Windows Update, ele aparece entre os que ficaram de fora e não é instalado;
- **a bateria carregando**, na tela em inglês;
- **um Windows com as assinaturas do Defender nunca atualizadas**, se houver um (uma instalação nova, sem internet).

## Fontes
- [KB5127648, 13 de outubro de 2026 (OS builds 26300.9711, 26200.9711 e 26100.9711)](https://support.microsoft.com/kb/5127648)
- [KB5126657 (build 19045.7807), a atualização ESU de outubro de 2026 do Windows 10](https://pureinfotech.com/kb5126657-windows-10-esu-october-2026-update/)
- [Microsoft support policy for the use of registry cleaning utilities (KB 2563254)](https://support.Microsoft.com/kb/2563254)
- [Should you install Windows 10's optional driver updates? (How-To Geek)](https://www.howtogeek.com/751889/should-you-install-windows-10s-optional-driver-updates)
- [Windows 10's new optional updates explained (Computerworld)](https://www.computerworld.com/article/3601870/windows-10-new-optional-updates-explained.html)
