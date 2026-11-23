# WinForge 4.0 — segunda revisão da Segurança (R47)

**Data:** 21/11/2026 · **Versão:** Build 4.0 em preparação, depois da R46

**Pedido:** revisar a tela e a função Segurança com cinco olhares:
- **Analista de Produto Sênior:** avalia o todo.
- **Engenheiro de Software Sênior:** revisa o código, refatora, segue as boas práticas, tira o que não serve e melhora o desempenho.
- **Designer Sênior, com um Especialista em UX/UI:** revisam a tela, os botões, os textos e os fluxos; o engenheiro aplica.
- **MVP Windows:** confere se a Segurança segue as práticas da Microsoft, se cada função faz da melhor forma o que promete e se é robusta e estável.
- **QA Sênior:** testa tudo o que dá para testar, o óbvio e o que não é; o engenheiro aplica.

**De onde partiu:** a primeira revisão da Segurança (R16) foi antes do desenho novo (R37), da revisão de UX (R38) e das faixas no alto das páginas (R41 a R43). Esta olhou as oito telas da página e o que elas dividem com outras partes: a consulta ao Windows Update (a mesma do Verificar o PC) e a verificação rápida (que o Otimizar e o Início usam).

**Resultado:** 11 achados, todos corrigidos.

| Olhar | Achados |
|---|---|
| Produto | 2: o Defender esperando reiniciar o PC sem a tela oferecer; e a Verificar uma pasta sem os pendrives, para onde a verificação completa manda quem quer examiná-los |
| Engenharia | 2: o Windows Update esperando as outras leituras para começar, no Estado da proteção e na auditoria; e uma consulta a mais por ameaça, que com o Defender sem responder somava o prazo de novo a cada uma |
| Designer e UX/UI | 2: Sim e Não em duas perguntas; e o aviso dos "pen drives e discos USB", escrito diferente do resto do WinForge e mais largo do que a regra do Windows |
| MVP Windows | 1: a Área de Trabalho Remota lida só pela chave da tela do Windows, sem a política, que decide no lugar dela |
| QA | 4: a cópia da chave do BitLocker que não grava dizendo "não foi possível ler o BitLocker"; as assinaturas nunca atualizadas como "não foi possível ler" na auditoria; uma unidade de rede mapeada só como "não encontrada"; e os leitores de cartão vazios oferecidos como pendrives |

Nada rodou num Windows de verdade. A conferência foi feita na nuvem: as telas com o Windows simulado (o Defender, o firewall, o registro, as unidades, as contas e o BitLocker), a procura do Windows Update num runspace à parte, de verdade, e as tarefas em segundo plano do WinForge de verdade. O que só um PC mostra entrou no roteiro de conferência (§38).

## A Segurança hoje

A página continua com os mesmos oito itens, de cima para baixo:
1. **Proteção:** Estado da proteção, em destaque ("Ver a proteção"); Auditoria de segurança; Chave de recuperação do BitLocker; Atualizar assinaturas do antivírus.
2. **Procurar ameaças:** Verificar vírus (atualiza e faz a verificação rápida); Verificação completa de vírus; Verificar uma pasta (agora com os pendrives); Segurança do Windows.

A chave, as assinaturas e as três verificações pedem Administrador e mostram o escudo.

## Analista de Produto

| # | O que estava | Por que importa | Como ficou |
|---|---|---|---|
| P1 | Quando o Windows Defender só esperava reiniciar o PC para terminar a limpeza (uma ameaça posta em quarentena que pede o reinício, ou o próprio Defender pedindo), a verificação dizia "Reinicie o PC para o Windows Defender terminar a limpeza." e terminava ali, com o botão da Segurança do Windows. | Enquanto o PC não reinicia, a limpeza fica pela metade. O reparo da rede (R46), o Corrigir o Windows Update, os Recursos opcionais e o CHKDSK já oferecem o reinício ali mesmo. | As três verificações (a rápida, a completa e a de uma pasta) oferecem reiniciar, com "Reiniciar agora" e "Depois" e o Depois como padrão, só quando reiniciar é o único passo que falta. Se falta outra coisa (uma ameaça que pede ação, a verificação completa), não oferecem: reiniciar não resolveria. Dentro do Otimizar, não perguntam: o Otimizar oferece o reinício no fim, como antes. |
| P2 | A verificação completa avisa que deixa os pendrives de fora e manda usar a Verificar uma pasta. Lá, a pergunta só oferecia Downloads, a Área de Trabalho e "Outra pasta ou arquivo": era preciso digitar "E:". | O aviso mandava a pessoa a uma tela que não mostrava o que ela procurava. | A pergunta mostra os pendrives e cartões de memória conectados ("E: (KINGSTON)", "pendrive ou cartão de memória"), com as teclas de 1 a 9, entre a Área de Trabalho e "Outra pasta ou arquivo". O item da página diz "O Defender examina uma pasta, um arquivo ou um pendrive", e a busca por "pendrive" acha ele. |

**Conferido e mantido:**
- **Sem a faixa no alto da página,** ao contrário da Manutenção, da Limpeza, do Desempenho e da Rede: o estado da proteção vem do Defender e do firewall pelo WMI, uma leitura que pode levar segundos (e tem prazo de um minuto), e a faixa é lida na hora em que a página abre. O cartão Proteção do Início já mostra isso, lido em segundo plano, e o Estado da proteção, em destaque, mostra o resto.
- **O Estado da proteção e a Auditoria separados (R16):** o primeiro é o olhar rápido do dia a dia, com o que fazer em cada linha; a auditoria vai além (o UAC, o SmartScreen, as contas, o SMB 1.0, o BitLocker, o Secure Boot) e dá uma nota.
- **Um destaque só, o Estado da proteção,** e a verificação completa perguntando antes, com o Agora não como padrão.

## Engenheiro de Software

| # | O que estava | Como ficou |
|---|---|---|
| E1 | O Estado da proteção e a Auditoria de segurança liam o antivírus, o firewall e as ameaças (e, na auditoria, as contas, o SMB 1.0, o BitLocker e o Secure Boot), e só depois perguntavam ao Windows Update, a consulta mais demorada (até um minuto e meio). O tempo das leituras somava com o dele. | A procura do Windows Update começa antes das leituras e corre junto, num runspace à parte (`Start-WinForgePendingUpdatesSearch`, nova); depois, `Get-WinForgePendingWindowsUpdates -Search` recebe a resposta, com o prazo contado desde o começo. Se a tela para antes de pedir a resposta (um erro, o Parar), a procura é largada num `finally`. O Core ganhou as duas metades do `Invoke-WinForgeInBackground`, `Start-WinForgeInBackground` e `Receive-WinForgeInBackground`, e `Stop-WinForgeInBackground`; o `Invoke` passou a usar as duas, e quem já o usava não muda. Na bateria, com 1,5 segundo de leituras e 2 de Windows Update: o Estado da proteção foi de 3,5 para 2,1 segundos, e a auditoria, de 3,7 para 2,1. |
| E2 | Depois de uma verificação, os nomes das ameaças vinham de uma consulta só ao Defender; sem ela (o Defender sem responder), `Get-WinForgeThreatName` perguntava de novo, ameaça por ameaça, cada pergunta com o mesmo prazo de 60 segundos. A Chave do BitLocker lia as unidades removíveis por conta própria. | `Get-WinForgeThreatName` saiu: sem a consulta, a ameaça fica com o Id ("ameaça 2147735505"), numa consulta só. As unidades removíveis vêm de `Get-WinForgeRemovableDrives` (nova), a mesma para a chave e para a Verificar uma pasta. |

**Por dentro:**
- **Security.psm1:**
  - `Request-WinForgeScanRestart`, `Get-WinForgeRemovableDrives` e `Get-WinForgeMissingDriveNote` (novas); `Get-WinForgeThreatName` (saiu);
  - `Show-WinForgeSecurityStatus` e `Show-WinForgeSecurityAudit` (o Windows Update em paralelo); `Get-WinForgeSecurityAuditFacts` e `Get-WinForgeSecurityAuditChecks` (a política da Área de Trabalho Remota e as assinaturas nunca atualizadas); `Get-WinForgeScanOutcome` (`RestartNeeded`); `Get-WinForgeScanDetections`; `Write-WinForgeScanIntro`; `Test-WinForgeScanPath`; as três verificações; `Select-WinForgeScanTarget`, `Select-WinForgeBitLockerKeyFolder` e `Show-WinForgeBitLockerKey`.
- **Core.psm1:** `Start-WinForgeInBackground`, `Receive-WinForgeInBackground` e `Stop-WinForgeInBackground` (novas); `Invoke-WinForgeInBackground` usa as duas primeiras.
- **Diagnostics.psm1:** `Start-WinForgePendingUpdatesSearch` (nova) e `Get-WinForgePendingWindowsUpdates -Search`.
- **Navigation.psm1:** a Verificar uma pasta com os pendrives.
- **Traduções:** 5.631 textos (19 novos e 4 que saíram de uso). Entraram sete funções e saiu uma (1.305 nos módulos).

## Designer e Especialista em UX/UI

| # | O que estava | Orientação | Como ficou |
|---|---|---|---|
| D1 | Duas perguntas com Sim e Não: "Deseja começar a verificação completa agora?" e, ao salvar a chave do BitLocker no próprio disco com BitLocker, "Salvar aí mesmo assim?". É a UX21 da revisão de UX, aplicada nesta página. | Os botões dizem o que fazem, como a Microsoft orienta ("Use specific responses to the main instruction or content as button text"). | "Começar" e "Agora não" (o Agora não como padrão, como antes); "Salvar mesmo assim" e "Cancelar" (o Cancelar como padrão). No menu de texto, as perguntas continuam com S/N. |
| D2 | O aviso da verificação completa dizia "Pen drives e discos USB ficam de fora". O resto do WinForge escreve "pendrive", e a regra do Windows por trás do aviso fala de unidades removíveis, "such as flash drives". | O mesmo nome para a mesma coisa, e o aviso do tamanho da regra. | "Pendrives e cartões de memória ficam de fora; para eles, use Segurança > Verificar uma pasta." É o mesmo grupo de unidades que a Verificar uma pasta e a Chave do BitLocker oferecem ("pendrive ou cartão de memória"). |

**Conferido e mantido:**
- **Os ícones, as descrições em até 60 letras nos três idiomas** (a da Verificar uma pasta, nova, com 55), a ordem e os grupos da página.
- **As perguntas que mudam algo começam no lado que não muda,** e a chave do BitLocker continua fora da tela e do log, a não ser em "Mostrar na tela" (R16).
- **A faixa de cada verificação** diz o que foi achado e o próximo passo, com o nome curto da ameaça (R16).

## MVP Windows

| # | O que estava | Por que importa | Como ficou |
|---|---|---|---|
| M1 | A auditoria lia a Área de Trabalho Remota só pela chave que a tela do Windows grava (`fDenyTSConnections`, em `HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server`). Num PC com a política "Permitir que os usuários se conectem remotamente" (de grupo, ou do MDM da empresa), a auditoria podia dizer "Desligada" com a política ligando, ou "Ligada" com a política desligando; e, ligada pela política, mandava desligar no botão das Configurações, que a política trava. | A Microsoft diz que, sem a política configurada, vale a configuração do PC: configurada, ela decide. O valor da política fica em `HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services`, com o mesmo nome; 1 é desligada pela política. | A auditoria lê primeiro a política e, sem ela, a chave do PC. Ligada pela política: "Ligada por uma política: outros computadores podem tentar entrar neste", e o conselho de desligar a política no Editor de Política de Grupo ou pedir a quem cuida dos PCs. Desligada pela política: "Desligada por uma política", em ordem. Sem a política, como antes. |

**Conferido**, com as fontes no fim:
- **Os pendrives na Verificar uma pasta:** a regra do Windows que tira as unidades removíveis da verificação completa (`DisableRemovableDriveScanning`) não vale para as outras: "Windows Defender can still scan removable drives during quick scans or custom scans" (P2, D2).
- **A unidade de rede mapeada:** com o UAC, cada entrada no Windows tem duas sessões, e o mapeamento de uma unidade "are specific for a logon session and are not shared between logon sessions". O WinForge, aberto como Administrador, fica na outra sessão (Q3).
- **A segunda tentativa das assinaturas direto na Microsoft (R16):** sem a regra configurada, o Defender procura "in the default order of `MicrosoftUpdateServer | MMPC`", e o WinForge só vai ao MMPC quando ele está nessa ordem.
- **O restante da R16 continua valendo:** o prazo de cada leitura do Defender e do firewall; o modo passivo com outro antivírus; o firewall do perfil Domínio fora de um domínio; a conta Convidado pelo SID; a nota com os tetos; a chave fora do log.
- **Robusto:** a procura do Windows Update começada nunca fica rodando sozinha; uma ameaça sem nome não segura mais a tela; e as perguntas novas começam no lado que não muda nada.

## QA Sênior

**Como foi testado:** uma bateria nova da Segurança, 83 conferências em português e 84 em inglês e em espanhol (nestes dois, mais uma: nenhum texto em português na tela).
- **As tarefas em segundo plano (A):** o `Invoke` de antes (o resultado, o erro, o prazo); o `Start` que volta na hora; o `Receive` com o tempo de antes contando; o prazo desde o começo; o `Stop` numa tarefa rodando, numa terminada, numa já recebida e sem tarefa.
- **O Estado da proteção (B):** o antivírus e o Windows Update juntos, no tempo; as atualizações na tela; a procura recebida; um erro antes do Windows Update, com a procura largada; a procura que não começa; quem chama sem `-Search` e o prazo.
- **A Auditoria (C):** o Windows Update em paralelo, no tempo; um erro nas leituras; a Área de Trabalho Remota com a política ligando, desligando e sem ela, com a chave do PC dos dois jeitos; as assinaturas nunca atualizadas, na nota, no botão e no conselho; os fatos montados sem o campo novo.
- **As verificações (D):** a oferta de reiniciar na rápida, na completa e na de uma pasta; o Depois e o Reiniciar agora (o `shutdown /r /t 0`, com o motivo); o Otimizar; o Defender pedindo reiniciar, a completa ou os dois; a ameaça que pede ação; nada encontrado; as ameaças sem a consulta, com uma consulta só, e com ela.
- **A Verificar uma pasta (E):** o pendrive na pergunta; os leitores de cartão vazios (sem tamanho e com zero); escolher o pendrive; sem resposta do Windows; onze unidades; a unidade que não aparece, na tela e na faixa; a pasta que não existe numa unidade que existe; sem Administrador e caminhos de rede.
- **A verificação completa (F):** os botões, recusada, o aviso das unidades removíveis com a regra ligada e desligada.
- **A Chave do BitLocker (G):** onde salvar com o pendrive e os leitores vazios; só um leitor vazio; a cópia que não grava, com a chave existente e com a chave recém-criada; o motivo limpo; a chave fora da tela; a pergunta do próprio disco, com Cancelar e Salvar mesmo assim; a pasta numa unidade que não aparece.
- **A página e o código (H)** e **os textos** nos três idiomas.

**Achados**

| # | O que estava | Como ficou |
|---|---|---|
| Q1 | Na Chave do BitLocker, uma cópia que não podia ser gravada (o pendrive tirado no meio, protegido contra gravação ou cheio, a pasta sem permissão) terminava em "Não foi possível ler o BitLocker: …". | "Não foi possível salvar a cópia da chave: …", com o motivo do Windows numa frase, e a faixa "A cópia da chave não foi salva", "Confira se o pendrive está conectado e com espaço, ou escolha outra pasta.", com o botão "Tentar de novo". Com uma chave recém-criada, continua o aviso de chave sem cópia, com o botão de guardar. |
| Q2 | Com as assinaturas do antivírus nunca atualizadas, a auditoria dizia "Não foi possível ler a data da última atualização" e deixava o ponto de fora da nota, enquanto o Estado da proteção e o Início diziam "Nunca atualizadas". | "Nunca atualizadas", como risco real (a nota fica em até 89), com o botão para atualizar as assinaturas e o conselho. |
| Q3 | Na Verificar uma pasta, um caminho numa unidade de rede mapeada (Z:\Documentos) dava "Pasta ou arquivo não encontrado", sem dizer por quê: com o WinForge aberto como Administrador, o Windows não mostra as unidades mapeadas na sessão comum. O mesmo na pasta da Chave do BitLocker. | Quando nem a unidade aparece, a tela e a faixa explicam: "A unidade Z: não aparece para o WinForge. Se é uma unidade de rede, use o caminho da rede (`\\servidor\pasta`): aberto como Administrador, o WinForge não vê as unidades mapeadas." Uma pasta que não existe numa unidade que existe continua só "não encontrada". |
| Q4 | Na Chave do BitLocker, a pergunta de onde salvar oferecia cada unidade removível, com os leitores de cartão vazios: num PC com um leitor de cartão de várias entradas, um "pendrive" a mais para cada entrada vazia, e o primeiro em destaque, mesmo vazio. Escolhê-lo dava "A pasta não existe". | Só entram as unidades com um disco dentro (com tamanho); um leitor vazio fica de fora, ali e na Verificar uma pasta. |

Os testes também acharam os do produto (P1 e P2), os do designer (D1 e D2) e o do MVP (M1).

**A bateria antiga da Segurança (R16):** uma conferência pedia o texto antigo do aviso da verificação completa ("Pen drives e discos USB") e passou a pedir o novo. Com isso, os mesmos números da R46: 134, 142 e 142.

**Contra o código de antes (R46):** cada conferência das correções falha (51; duas seções param no meio, porque as funções novas não existem). Das 26 que passam, 25 conferem o que foi mantido (o `Invoke` de antes, o Windows Update sem resposta e o prazo dele, a Área de Trabalho Remota sem a política, a ameaça que pede ação e o Defender pedindo a completa sem a oferta, o Otimizar, o nome curto da ameaça, Downloads em destaque, a chave fora da tela, a página) e 1 é a dos marcadores de texto. Com 1,5 segundo de leituras e 2 de Windows Update simulados, o Estado da proteção levou 3,5 segundos no código de antes e 2,1 no de agora; a auditoria, 3,7 e 2,1.

**40 defeitos de propósito,** e as conferências pegam todos: o `Start` esperando o bloco, o prazo contado só do `Receive`, o `Stop` sem liberar a tarefa terminada e o `Receive` sem marcar a tarefa; o Estado da proteção sem a procura antes ou sem largá-la, e o `Get` começando outra procura; a auditoria esperando as leituras ou sem largar a procura; a política da Área de Trabalho Remota ignorada, com o conselho das Configurações ou desligada sem dizer; as assinaturas nunca atualizadas de volta a "sem leitura" ou só como ressalva; a oferta de reiniciar fora de cada uma das três verificações, dentro do Otimizar, com outro passo junto, para a ameaça que pede ação ou fora quando é o Defender que pede; o nome da ameaça perguntado de uma em uma; a pasta sem os pendrives, com o leitor vazio ou de tamanho zero, com mais de nove unidades e com o pendrive escolhido ignorado; a unidade que não aparece sem o aviso, com o aviso numa unidade que existe ou sem Administrador, e a faixa sem ele; a completa com Sim e Não e com o texto antigo; a cópia da chave que não grava como falha de leitura, sem o botão de tentar de novo e com o motivo embrulhado; a chave no próprio disco com Sim e Não; a pasta da chave sem o aviso da unidade e com o leitor vazio em destaque; e a Verificar uma pasta sem o pendrive na página. Na primeira rodada, um escapou (mais de nove unidades) por um erro da própria bateria, que só contava as teclas de um dígito; com a conta certa, ele foi pego.

**Nada do que funcionava quebrou:** as baterias das 14 páginas revistas, com os mesmos números da R46 (a da Segurança da R16 com 134, 142 e 142, depois da adaptação acima; a da Rede da R22 com a mesma conferência antiga do escudo); a das seis funções novas da R36 (257 em cada idioma); a do Início da R40 (115), a da Manutenção da R41 (67), a da Limpeza da R42 (97), a do Desempenho da R43 (94), a do Reparo da R44 (92), a do Diagnóstico da R45 (87) e a da Rede da R46 (128) em cada idioma; a da Manutenção da R14 (243, 245 e 250) e a do Início da R13 (241); as mensagens da janela (72 em cada idioma); instalar, atualizar com um clique, o pacote de suporte e o Setup de verdade, da R46 para esta; nenhuma função sem uso (1.523, sete novas e uma que saiu). O PSScriptAnalyzer ficou com 242 avisos, dois a menos que na R46 (os `catch` vazios de `Get-WinForgeThreatName` e da espera em segundo plano), e nenhum novo.

## O que só um PC mostra

Isto entrou no roteiro de conferência (§38):
- **O Estado da proteção e a Auditoria** no mesmo resultado de antes, em menos tempo (anote os segundos), e o Parar no meio.
- **A oferta de reiniciar** depois de uma verificação que deixa uma ameaça esperando o reinício (o arquivo de teste EICAR, se der).
- **Os pendrives** na Verificar uma pasta e na Chave do BitLocker, com um leitor de cartão vazio.
- **A unidade de rede mapeada** na Verificar uma pasta.
- **A cópia da chave num pendrive protegido contra gravação** (ou tirado na hora).
- **A Área de Trabalho Remota pela política,** num PC Pro.
- **Os botões novos** nos três idiomas.

## Fontes
- [Set-MpPreference](https://learn.microsoft.com/powershell/module/defender/set-mppreference) (Microsoft): `DisableRemovableDriveScanning`, "removable drives, such as flash drives, during a full scan", e "Windows Defender can still scan removable drives during quick scans or custom scans."; `SignatureFallbackOrder`, "the default order of `MicrosoftUpdateServer | MMPC`".
- [Policy CSP - RemoteDesktopServices](https://learn.microsoft.com/windows/client-management/mdm/policy-csp-remotedesktopservices) (Microsoft): AllowUsersToConnectRemotely, "If you don't configure this policy setting, Remote Desktop Services uses the Remote Desktop setting on the target computer to determine whether the remote connection is allowed.", com a chave `SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services`.
- [Troubleshoot an RDP general error in Azure VM](https://learn.microsoft.com/en-us/azure/virtual-machines/troubleshooting/troubleshoot-rdp-general-error) (Microsoft): `reg query "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" /v fDenyTSConnections`, "If this key value is set to 1 that means RDP is disabled by the policy."
- [Mapped drives are not available from an elevated prompt when UAC is configured to Prompt for credentials](https://learn.microsoft.com/en-us/troubleshoot/windows-client/networking/mapped-drives-not-available-from-elevated-command) (Microsoft): "When UAC is enabled, the system creates two logon sessions at user logon." e os mapeamentos "are specific for a logon session and are not shared between logon sessions."
- [Dialog controls](https://learn.microsoft.com/windows/apps/design/controls/dialogs-and-flyouts/dialogs) (Microsoft): "Use specific responses to the main instruction or content as button text".
