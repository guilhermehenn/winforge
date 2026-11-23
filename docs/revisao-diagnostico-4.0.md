# WinForge 4.0 — revisão do Diagnóstico (R15)

**Data:** 19/11/2026 · **Versão:** Build 4.0 em preparação, depois da R14

**Pedido:** juntar quatro olhares para a tela e a função de Diagnóstico:
- **Analista de UX/UI Sênior (designer):** revisa cada detalhe da interface e orienta o engenheiro.
- **Especialista Microsoft (MVP Windows):** confere se os comandos e as leituras do Windows são feitos da melhor forma disponível hoje, de modo seguro e robusto, e se fazem sentido e leem o que devem no PC.
- **QA Sênior:** testa todas as funções da tela.
- **Engenheiro de Software Sênior:** aplica as correções.

**Resultado:** 7 achados, todos corrigidos.

| Olhar | Achados |
|---|---|
| Designer | 4: duas categorias de dispositivo em português na tela em inglês e em espanhol, o "Cancelado" por cima do resultado do teste de memória, a falha de leitura das Telas azuis sem orientação e o mesmo fato dito com duas frases |
| MVP Windows | 2: as leituras de disco e de dispositivos sem tempo-limite, e oito códigos de tela azul comuns sem nome nem causa |
| QA | 1 novo: em inglês e em espanhol, um disco só quente pedia backup. Os testes também acharam dois dos acima (D1 e D2). |
| Engenharia | Nenhum próprio: aplicou os 7. |

Nada rodou num Windows de verdade. As leituras foram simuladas, e o que só um PC mostra entrou no roteiro de conferência.

## O Diagnóstico hoje

A página só lê o PC: nada nela muda o Windows, fora reiniciar (quando a pessoa pede) e agendar o teste de memória na ferramenta do próprio Windows. De cima para baixo:
1. **Visão geral:** Sobre este PC (em destaque, "Ver detalhes"), Suporte do Windows e Exportar relatório.
2. **Hardware:** Discos e espaço livre, Saúde dos discos (com o escudo), Dispositivos com problema, Saúde da bateria (só aparece com bateria) e Teste de memória (com o escudo).
3. **Funcionamento do Windows:** Eventos críticos (7 dias), Telas azuis, Reinício pendente e Tempo ligado e energia.
4. **Ferramentas do Windows:** Monitor de Confiabilidade e Gerenciador de Dispositivos, que abrem a janela do Windows.

As mesmas leituras servem a outras partes: a saúde dos discos ao Verificar o PC, ao relatório e ao monitor na bandeja; as telas azuis e o teste de memória também ao monitor.

## Designer (UX/UI)

| # | O que estava | Orientação | Como ficou |
|---|---|---|---|
| D1 | Em Dispositivos com problema, cada dispositivo leva a categoria entre parênteses. Duas estavam escritas direto no código, sem tradução: em inglês, "Leitor de digital (Biometria)" e "Porta COM (Portas)". | Tudo o que a tela mostra passa pela tradução. | "Biometrics" e "Ports" em inglês; "Biometría" e "Puertos" em espanhol. |
| D2 | No Teste de memória, quem lia o último resultado e respondia Não terminava em "Cancelado". Com um teste recente sem erros, o Não é o padrão: o Enter dava "Operação cancelada". Com erros no último teste, a faixa escondia os erros que a tela acabara de mostrar. | Dizer Não depois de ler o resultado é ficar com ele, e não desistir. A faixa conta o que a tela mostrou. | Com erros no último teste, a faixa é a ressalva dos erros, com o que fazer. Com um teste recente sem erros, termina como as telas de consulta. Sem teste nenhum, Não continua sendo cancelar. |
| D3 | Sem conseguir ler o log do Sistema, as Telas azuis punham na faixa só a mensagem crua do Windows (no teste, "log indisponível"), sem dizer o que fazer. Os Eventos críticos, na mesma situação, dizem que isso não quer dizer que não haja eventos e onde conferir. | A mesma falha, a mesma resposta nas duas telas. | A tela diz "Isto não quer dizer que não haja telas azuis. Abra o Visualizador de Eventos (eventvwr.msc) para conferir.", e a faixa traz a frase inteira: "Não foi possível ler o log do Sistema: …". |
| D4 | O tempo ligado com a Inicialização Rápida era explicado com duas frases diferentes: "O tempo ligado conta desde o último Reiniciar: com a Inicialização Rápida ligada, Desligar não zera a conta." em Sobre este PC, e "Com a Inicialização Rápida ligada, desligar o PC não zera o tempo ligado: só Reiniciar faz o Windows começar do zero." em Tempo ligado e energia. | O mesmo fato, com as mesmas palavras. | As duas telas usam a segunda frase, que diz também o que fazer. |

**Conferido e mantido:**
- um destaque só na página, o Sobre este PC;
- as descrições cabem em 60 letras nos três idiomas;
- as telas só de consulta (Sobre este PC, a bateria com desgaste moderado, um disco sem contadores) terminam sem faixa de resultado;
- reiniciar, no Reinício pendente, começa no Não; o Teste de memória começa no Sim, menos com um teste recente sem erros;
- a Saúde dos discos termina lembrando que o programa do fabricante faz um teste mais completo;
- num desktop, a bateria que o Windows vê é a de um nobreak, e a tela diz isso em vez de dar um desgaste;
- cada leitura que não responde vira "não foi possível ler", e nunca "nenhum problema".

## Especialista Microsoft (MVP Windows)

**O que mudou**

| # | O que estava | Por que não é o melhor | Como ficou |
|---|---|---|---|
| M1 | Os discos físicos (`Get-PhysicalDisk`), as partições (`Get-Partition`), os contadores de cada disco (`Get-StorageReliabilityCounter`) e os dispositivos (`Get-PnpDevice`) eram lidos sem tempo-limite. | Todas as outras consultas do WinForge ao WMI param em até 15 segundos (R12). Essas não têm o `-OperationTimeoutSec`, e um disco morrendo ou uma controladora travada as deixam paradas sem fim, justo no PC que mais precisa da Saúde dos discos. O `Get-PhysicalDisk` é um script do módulo de armazenamento, sem prazo e sem `-AsJob`. | Os discos físicos vêm de `MSFT_PhysicalDisk` (as mesmas instâncias que o `Get-PhysicalDisk` devolve) pelo `Get-CimInstance` com `-OperationTimeoutSec 60`. As partições, os contadores e os dispositivos rodam com `-AsJob`, que esses três têm, e a espera vai até 60 segundos; passado o prazo, a consulta é largada sem esperar por ela. São 60, e não 15: a primeira consulta aos discos pode precisar ligar o serviço de armazenamento, o que num HD lento demora. Lido assim, o tipo do disco pode vir como código (MediaType 4 = SSD, BusType 17 = NVMe), e a tela entende os dois jeitos. |
| M2 | Oito códigos de tela azul comuns caíam em "causa desconhecida", com o reparo do Windows como próximo passo: 0xC000021A, 0x24, 0x9C, 0xC4, 0xFC, 0x10E, 0x113 e 0x12B. | A causa provável deles é conhecida e muda o que fazer: 0x12B e 0x9C apontam para a memória e o hardware, 0x10E e 0x113 para o driver de vídeo, 0x24 para o disco. | Cada um com o nome e a causa: STATUS_SYSTEM_PROCESS_TERMINATED (arquivos do Windows), NTFS_FILE_SYSTEM (disco), MACHINE_CHECK_EXCEPTION (hardware), DRIVER_VERIFIER_DETECTED_VIOLATION e ATTEMPTED_EXECUTE_OF_NOEXECUTE_MEMORY (driver), VIDEO_MEMORY_MANAGEMENT_INTERNAL e VIDEO_DXGKRNL_FATAL_ERROR (driver de vídeo) e FAULTY_HARDWARE_CORRUPTED_PAGE (memória, que a Microsoft manda conferir com o Diagnóstico de Memória). |

**Cada leitura, conferida**

| Função | Como o WinForge faz | Veredito |
|---|---|---|
| Sobre este PC | WMI com tempo-limite: placa-mãe, BIOS, processador, módulos de memória, vídeo, sistema e computador. A memória de vídeo vem do Registro (`HardwareInformation.qwMemorySize`), porque o `AdapterRAM` do WMI para em 4 GB. O Secure Boot vem do Registro (`UEFISecureBootEnabled`, legível sem Administrador), com o modo de início (`PEFirmwareType`) antes, para não chamar de "desligado" um PC que iniciou no BIOS legado; `Confirm-SecureBootUEFI` fica de reserva. | Certo. |
| Suporte do Windows | As datas vêm do catálogo do WinForge, por edição (Home e Pro, Enterprise e Education, LTSC e IoT LTSC). No Windows 10 22H2, a revisão instalada diz se as atualizações estendidas (ESU) estão chegando. Os requisitos do Windows 11: processador da lista, TPM 2.0, UEFI com Secure Boot disponível (não precisa estar ligado), 4 GB instalados, 64 GB de disco e 64 bits. | Certo. As datas conferem com hoje: o ESU de casa do Windows 10 vai até 12/10/2027 (a Microsoft estendeu mais um ano); o Windows 11 24H2 Home e Pro acabou em 13/10/2026, e a tela manda atualizar o Windows 11, e não procurar o ESU; o 23H2 Enterprise acabou em 10/11/2026. |
| Exportar relatório | HTML e texto na pasta do WinForge, com as mesmas leituras das telas. | Certo: sem senhas nem a chave do BitLocker. |
| Discos e espaço livre | `Win32_LogicalDisk` com tempo-limite; o tipo e o modelo de cada unidade pelas partições e pelo disco físico (M1). As regras de pouco espaço são as mesmas do Início. | Certo, com o M1. |
| Saúde dos discos | O estado que o Windows dá ao disco (`HealthStatus`) e a previsão de falha do próprio disco (`OperationalStatus` "Predictive Failure", ou 5); com Administrador, os contadores: temperatura, desgaste, horas ligado e erros não corrigidos. Valores impossíveis de adaptadores USB são descartados. Temperatura alta: 55 °C num HD, 70 °C num SSD, 60 °C sem tipo. | Certo, com o M1. |
| Dispositivos com problema | `Get-PnpDevice -PresentOnly` e o código do Gerenciador de Dispositivos. Desativados (22 e 29) ficam à parte, sem alarme; o 14 pede reiniciar. | Certo, com o M1. |
| Saúde da bateria | `powercfg /batteryreport /xml` (capacidade de fábrica, de hoje e ciclos), com o WMI de `root\wmi` de reserva. | Certo. |
| Teste de memória | Abre o `mdsched.exe`, a ferramenta do Windows, e lê o resultado no log do Sistema (`MemoryDiagnostics-Results`). | Certo. |
| Eventos críticos | O log do Sistema, críticos e erros dos últimos 7 dias, mais três avisos que importam (disco 51 e 153, vídeo 4101), até 3.000 eventos. Os erros que aparecem em quase todo PC (DCOM 10016, por exemplo) são agrupados como comuns. | Certo. |
| Telas azuis | O registro que o Windows grava ao voltar da tela azul (`WER-SystemErrorReporting` 1001) e o `Kernel-Power` 41 com o código, dos últimos 90 dias, contando cada travamento uma vez. O 41 sem código (queda de energia, botão segurado) não conta. | Certo, com o M2. |
| Reinício pendente | Sinais fortes: as chaves da CBS e do Windows Update, o `UpdateExeVolatile`, o novo nome do PC e a entrada num domínio. Sinais fracos, que sozinhos não pedem reinício: `PendingFileRenameOperations` e os serviços do Windows Update pendentes. Reinicia com `shutdown /r /t 0`, sem `/f`. | Certo: sem `/f`, o Windows pergunta pelos arquivos sem salvar. |
| Tempo ligado e energia | `LastBootUpTime`, a Inicialização Rápida (`HiberbootEnabled`, sem efeito com a hibernação desligada) e `powercfg /a`. | Certo. |
| Ferramentas do Windows | `perfmon /rel` e `devmgmt.msc`. | Certo. |

## QA Sênior

**Como foi testado:** cada função da página rodou com o Windows simulado, nos três idiomas: 212 conferências em português e 224 em inglês e em espanhol (as 12 a mais conferem, em cada seção, que nenhum texto do português aparece na tela).
- **Sobre este PC (16):**
  - o PC, o modelo, o Windows e a versão;
  - os módulos, o tipo e a velocidade da memória;
  - a memória de vídeo pelo Registro, e "4 GB ou mais" sem ele;
  - o driver básico de vídeo;
  - a máquina virtual sem módulos;
  - o WMI parado;
  - o Secure Boot com BIOS legado;
  - o modelo de fábrica de três fabricantes.
- **Suporte do Windows (39):**
  - 11 situações, do Windows 11 25H2 ao Windows Server, com o estado, a frase e o que fazer;
  - 13 combinações dos requisitos do Windows 11;
  - a tela num Windows 10 fora do ESU.
- **Discos e espaço livre (16):**
  - o tipo e o modelo de cada unidade, pelo nome e pelo código;
  - a unidade sem tamanho;
  - o pouco espaço no disco do Windows e num de dados;
  - sem o disco físico e com o WMI parado.
- **Saúde dos discos (31):**
  - sete discos: saudável, quente, gasto, com previsão de falha, com erros, USB sem contadores e com valores impossíveis;
  - em cada um, o que a tela diz, o conselho de backup só quando há risco de perder dados, e a faixa;
  - sem Administrador e sem resposta;
  - os códigos do WMI, também no monitor;
  - os contadores que não respondem, que respondem e que dão erro.
- **Dispositivos com problema (11):**
  - nenhum, três com problema e um desativado;
  - os códigos 28 e 14;
  - as categorias no idioma da tela;
  - o serviço sem resposta;
  - a consulta que não volta e a que volta.
- **Saúde da bateria (14):**
  - o desgaste bom, o moderado e o alto;
  - sem a capacidade de fábrica e sem ciclos;
  - o nobreak num desktop, sem bateria, e o WMI no lugar do powercfg.
- **Teste de memória (8):**
  - sem teste;
  - o teste recente sem erros e com erros;
  - o Não em cada caso;
  - sem o `mdsched.exe`.
- **Eventos críticos (8):**
  - nenhum, só os comuns, três sérios (o reinício inesperado contado uma vez), o limite de leitura e o log ilegível.
- **Telas azuis (27):**
  - nenhuma;
  - o 1001 e o 41 do mesmo travamento;
  - o 41 sem código;
  - os oito códigos novos, um 0x1000xxxx (que tem o nome do 0x0000xxxx) e um código desconhecido, com nome, causa e destino;
  - as frases de cada causa;
  - o log ilegível.
- **Reinício pendente (6):**
  - nenhum e só sinal fraco;
  - um sinal forte, recusado e aceito (`shutdown /r /t 0`, sem `/f`).
- **Tempo ligado e energia (6):** a Inicialização Rápida com e sem a hibernação; o tempo ligado de menos de um minuto, sem data e com o início "no futuro" (relógio atrasado).
- **A página (30):**
  - cada item existe;
  - as descrições têm até 60 letras;
  - um destaque só.
- **Os textos:** nenhum marcador `{0}` sobrando, e nenhum texto do português na tela em inglês e em espanhol, conferido contra as traduções.

**Achados**

| # | Severidade | O que acontecia | Como ficou |
|---|---|---|---|
| Q1 | Média | Em inglês e em espanhol, um disco só quente (sem outro alerta) pedia "faça backup dos arquivos importantes deste disco", em vez de "confira a ventilação". A tela separava a nota da temperatura pelo começo "Temperatura", que só existe em português. | A nota é comparada inteira, no idioma da tela. |
| Q2 | Baixa | As categorias Biometria e Portas em português (é o D1). | Corrigido. |
| Q3 | Baixa | O "Cancelado" no Teste de memória (é o D2). | Corrigido. |

Cada conferência nova falha no código de antes e passa no de agora.

## Engenharia

**Por dentro**
- **Diagnostics.psm1:**
  - `Invoke-WinForgeStorageQuery`, novo: roda o comando com `-AsJob` e espera até `$script:WinForgeStorageTimeoutSec` (60 segundos). Passado o prazo, pede a parada sem esperar por ela, como o `Invoke-WinForgeInBackground` faz. Um comando sem `-AsJob` roda direto. O `Invoke-WinForgeInBackground` não serviu: num runspace novo, o módulo do comando seria carregado de novo a cada consulta, e o resultado voltaria com os tipos daquele runspace.
  - `Get-WinForgeDiskSummary` e `Get-WinForgeDiskHealth` leem `MSFT_PhysicalDisk` pelo `Get-CimInstance`, dentro do `try` que já existia; as partições e os contadores, pelo `Invoke-WinForgeStorageQuery`.
  - `Get-WinForgeDiskTypeText` entende os códigos de MediaType e BusType.
  - `Show-WinForgeProblemDevices`: o `Get-PnpDevice` pelo `Invoke-WinForgeStorageQuery`.
  - `Get-WinForgeDeviceName`: Biometria e Portas pela tradução.
  - `Show-WinForgeDiskHealth`: a nota da temperatura comparada inteira.
  - `Get-WinForgeBugCheckInfo`: os oito códigos.
  - `Show-WinForgeBlueScreens`: a orientação do log ilegível, e a faixa sai do aviso.
  - `Start-WinForgeMemoryTest`: o Não depois de um teste lido não é cancelamento.
  - `Show-WinForgeSystemInfo`: a frase do tempo ligado.
- **Fora desta tela:** `Test-WinForgeDriveExternal` (Repair.psm1, a escolha da unidade do CHKDSK) ainda lê `Get-Partition | Get-Disk` sem tempo-limite. Fica para a revisão do Reparo, onde o `Invoke-WinForgeStorageQuery` serve.
- **Traduções:** 4 novas e 1 que saiu, 5.182 ao todo.

**Conferido na nuvem**
- **As conferências do Diagnóstico:** 212, 224 e 224, todas passando.
- **As de antes continuam passando:**
  - as 245, 247 e 252 da Manutenção;
  - as 241 do Início nos três idiomas;
  - as 83 do QA geral, as 80 da R11 e as 60 da R12 (que confere o tempo-limite e o `try` de cada consulta ao WMI, agora 42);
  - as 59 da R9 e as 52 da R10;
  - as 66 da QA, as 28 da integração e as 26 da R7;
  - as 84 ações rodando 336 vezes, com o mesmo resultado da R14, fora a faixa nova das Telas azuis;
  - o motor de instalação, a atualização simulada e o Setup de verdade (da R14 para esta), e o pacote de suporte;
  - as traduções (5.182/5.182), as 160 referências nos três idiomas e a busca dos 102 itens;
  - nenhuma chamada com parâmetro que não existe, nenhuma função sem uso e nenhum aviso novo do analisador.

## O que só um PC mostra

Isto entrou no roteiro de conferência:
- **a Saúde dos discos e Discos e espaço livre num PC real**, com Administrador: o tipo de cada disco (SSD, HDD ou NVMe) igual ao do Gerenciador de Tarefas, e a temperatura, o desgaste e as horas aparecendo. Num pendrive ou num HD externo, a tela diz que o disco não expõe contadores. É a mudança mais sensível desta revisão: a leitura passou do `Get-PhysicalDisk` para o WMI;
- **o tempo das duas telas**, que não pode ter ficado maior;
- **Dispositivos com problema** num PC com um dispositivo sem driver ou desativado, em inglês: a categoria no idioma da tela;
- **o Teste de memória** respondendo Não depois de um teste: a faixa não diz "Cancelado";
- **uma tela azul real** com um dos códigos novos, se houver.

## Fontes
- [MSFT_PhysicalDisk class (Microsoft Learn)](https://learn.microsoft.com/en-us/windows-hardware/drivers/storage/msft-physicaldisk): os códigos de MediaType, BusType e HealthStatus.
- [Get-PhysicalDisk (Microsoft Learn)](https://learn.microsoft.com/en-us/powershell/module/storage/get-physicaldisk): sem `-AsJob`.
- [Get-StorageReliabilityCounter](https://learn.microsoft.com/en-us/powershell/module/storage/get-storagereliabilitycounter), [Get-Partition](https://learn.microsoft.com/en-us/powershell/module/storage/get-partition) e [Get-PnpDevice](https://learn.microsoft.com/en-us/powershell/module/pnpdevice/get-pnpdevice) (Microsoft Learn): com `-AsJob`.
- [Bug check 0x12B: FAULTY_HARDWARE_CORRUPTED_PAGE](https://learn.microsoft.com/en-us/windows-hardware/drivers/debugger/bug-check-0x12b---faulty-hardware-corrupted-page) e [Bug check 0x113: VIDEO_DXGKRNL_FATAL_ERROR](https://learn.microsoft.com/en-in/windows-hardware/drivers/debugger/bug-check-0x113---video-dxgkrnl-fatal-error) (Microsoft Learn).
- [Microsoft extends free Windows 10 security updates (Help Net Security)](https://www.helpnetsecurity.com/2026/06/26/microsoft-windows-10-free-security-updates-esu-program/) e [Tom's Hardware](https://tomshardware.com/software/windows/microsoft-extends-free-windows-10-security-updates-for-a-second-year): o ESU de casa do Windows 10 até outubro de 2027.
