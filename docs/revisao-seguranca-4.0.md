# WinForge 4.0 — revisão da Segurança (R16)

**Data:** 19/11/2026 · **Versão:** Build 4.0 em preparação, depois da R15

**Pedido:** juntar quatro olhares para a tela e a função de Segurança:
- **Analista de UX/UI Sênior (designer):** revisa cada detalhe da interface e orienta o engenheiro.
- **Especialista Microsoft (MVP Windows):** confere se os comandos e as alterações no Windows são feitos da melhor forma disponível hoje, de modo seguro e robusto, e se fazem sentido e mudam o que devem no PC.
- **QA Sênior:** testa todas as funções da tela.
- **Engenheiro de Software Sênior:** aplica as correções.

**Resultado:** 10 achados, todos corrigidos.

| Olhar | Achados |
|---|---|
| Designer | 5: os nomes técnicos das ameaças, a faixa do antivírus sem leitura, o motivo errado na auditoria sem Administrador, o "ler" numa falha de criar a chave e o resumo que contradizia a faixa |
| MVP Windows | 2: as leituras do Defender e do firewall sem tempo-limite, e o nome da conta Convidado no comando que a desliga |
| QA | 3 novos: o lembrete da chave do BitLocker que nunca aparecia e dois textos em português nas telas em inglês e em espanhol. Os testes também acharam dois dos acima (D3 e M2). |
| Engenharia | Nenhum próprio: aplicou os 10. |

Nada rodou num Windows de verdade. As leituras e os comandos foram simulados, e o que só um PC mostra entrou no roteiro de conferência.

## A Segurança hoje

A página tem, de cima para baixo:
1. **Proteção:**
   - Estado da proteção, em destaque ("Ver a proteção");
   - Auditoria de segurança;
   - Chave de recuperação do BitLocker;
   - Atualizar assinaturas do antivírus.
2. **Procurar ameaças:**
   - Verificar vírus (atualiza e faz a verificação rápida);
   - Verificação completa de vírus;
   - Verificar uma pasta;
   - Segurança do Windows, que abre o aplicativo do Windows.

A chave, as assinaturas e as três verificações pedem Administrador e mostram o escudo.

Só três ações mudam o PC:
- atualizar as assinaturas, também no começo de cada verificação;
- as verificações, em que o Windows Defender age sozinho no que encontrar;
- criar uma chave de recuperação do BitLocker, com a pergunta antes.

O resto só lê. As mesmas leituras servem ao Início, ao Verificar o PC, ao monitor na bandeja e ao relatório.

## Designer (UX/UI)

| # | O que estava | Orientação | Como ficou |
|---|---|---|---|
| D1 | No Estado da proteção e na auditoria, as ameaças ativas apareciam com o nome técnico do Defender: "Trojan:Win32/Wacatac.H!ml e PUA:Win32/Presenoker". A verificação, para as mesmas ameaças, já mostra "Wacatac (trojan)". | A mesma ameaça com o mesmo nome, o que a pessoa lê. | O nome curto na linha, no ponto de atenção, na faixa e na auditoria. O nome completo, que se procura na internet, fica nos detalhes técnicos. |
| D2 | Com o antivírus sem leitura, a faixa do Estado da proteção dizia "Nenhum ponto de atenção no que foi lido", embora o que mais importa não tivesse sido visto. Com o firewall sem leitura, a frase mandava conferir na Segurança do Windows, mas a faixa não tinha o botão. Em inglês, a frase do que faltou começava em minúscula ("the antivirus could not be queried."). | O título diz o que faltou; quem manda conferir dá o botão; frase começa em maiúscula. | "Antivírus sem leitura", com o que fazer e o botão. O firewall sem leitura ganhou o botão, e a frase começa em maiúscula nos três idiomas. |
| D3 | Na auditoria sem Administrador, a criptografia dizia "Não verificada (esta edição do Windows pode não ter o BitLocker)", e as ameaças e o SMB 1.0, "Não foi possível consultar". O motivo era outro: o Windows nega essas leituras sem Administrador. | A linha diz o motivo de verdade. | As três dizem "Pede o WinForge aberto como Administrador". Com Administrador, ficam como antes. |
| D4 | Quando criar a chave de recuperação falhava (por exemplo, uma política da empresa que exige guardá-la no Active Directory), a tela dizia "Não foi possível ler o BitLocker". | A falha diz o que não deu. | A tela diz que não foi possível criar a chave de recuperação do disco, com o motivo, e a faixa diz que a chave não foi criada. |
| D5 | Numa ameaça já em quarentena que só esperava reiniciar, a faixa dizia "Reinicie o PC para o Windows Defender terminar a limpeza", mas o resumo mandava "escolher o que fazer" na Segurança do Windows, onde não há escolha. | O resumo e a faixa dizem a mesma coisa. | Quando falta só reiniciar, ou só a verificação completa, o resumo diz isso; a frase de escolher fica para o que pede escolha. |

**Conferido e mantido:**
- um destaque só na página, o Estado da proteção, e as descrições em até 60 letras nos três idiomas;
- o escudo nas cinco ações que pedem Administrador;
- as perguntas começam no lugar seguro:
  - a verificação completa, no Não;
  - a chave, em Voltar, com Salvar em destaque;
  - salvar a chave no próprio disco criptografado, no Não;
  - a verificação de uma pasta, em Cancelar, com Downloads em destaque;
- a chave aparece só na linha de segredo: nunca na faixa, no resumo ou no log;
- a faixa fica vermelha só quando o PC está sem proteção:
  - antivírus ou tempo real desligados;
  - ameaça ativa;
  - firewall desligado na rede pública;
  - um problema grave na auditoria.

## Especialista Microsoft (MVP Windows)

**O que mudou**

| # | O que estava | Por que não é o melhor | Como ficou |
|---|---|---|---|
| M1 | O estado do Defender (`Get-MpComputerStatus`), as ameaças (`Get-MpThreat`, `Get-MpThreatDetection`), as preferências (`Get-MpPreference`) e o firewall (`Get-NetFirewallProfile`) eram lidos sem tempo-limite. | São comandos sobre o WMI sem o `-OperationTimeoutSec` que as consultas diretas ao WMI ganharam na R12. Um WMI com defeito ou o serviço do Defender travado os deixam parados sem fim. Essas leituras alimentam o Estado da proteção, a auditoria, o Início, o Verificar o PC, o monitor e o relatório. | Rodam com `-AsJob`, que todos esses comandos têm, e esperam até 60 segundos. Passado o prazo, viram "não foi possível ler", como uma consulta ao WMI sem resposta, e o Parar também as interrompe. É o mesmo mecanismo que a R15 criou para os discos: agora fica no Core, com um nome geral (`Invoke-WinForgeCimCommand`). |
| M2 | O comando para desligar a conta Convidado vinha traduzido com a tela: "net user Convidado", "net user Guest", "net user Invitado". | O nome da conta segue o idioma em que o Windows foi instalado, e não o da tela do WinForge, e uma política pode tê-lo trocado. Com a tela em inglês num Windows em português, "net user Guest" responde que o usuário não existe. | O comando usa o nome real da conta neste Windows, lido pelo identificador que ela sempre tem (SID terminado em -501), e entre aspas. |

**Cada comando, conferido**

| Função | Como o WinForge faz | Veredito |
|---|---|---|
| Estado da proteção | O Defender por `Get-MpComputerStatus`: modo (ativo, passivo, desligado), tempo real, assinaturas (65535 = nunca atualizadas) e proteção contra adulterações. Outro antivírus ou firewall pela Central de Segurança (`root\SecurityCenter2`), contando só os ligados (bit 0x1000 de productState). O firewall por `Get-NetFirewallProfile -PolicyStore ActiveStore`, a política que vale de fato (a local somada à da empresa). As ameaças por `Get-MpThreat` (IsActive). As atualizações pendentes pelo Windows Update, em segundo plano e com prazo, sem as opcionais. | Certo, com o M1. |
| Auditoria de segurança | **Configurações do Windows:** UAC (EnableLUA; ConsentPromptBehaviorAdmin = 0 é "Nunca notificar"), SmartScreen (SmartScreenEnabled e a política EnableSmartScreen), Área de Trabalho Remota (fDenyTSConnections) e entrada automática (AutoAdminLogon e DefaultPassword, só para saber se há uma senha, que nunca aparece).<br>**Contas e recursos:** a conta Convidado (SID -501) e o SMB 1.0 (`Get-WindowsOptionalFeature SMB1Protocol`, o caminho que a Microsoft indica no Windows 10 e 11).<br>**Disco e inicialização:** o BitLocker (`Get-BitLockerVolume`) e o Secure Boot, com a mesma leitura do Diagnóstico.<br>**O suporte do Windows:** pelo catálogo, como no Diagnóstico.<br>**A nota:** um problema grave segura em 74 e um risco real em 89; sem o antivírus lido, não há nota. | Certo, com o M2. |
| Chave de recuperação do BitLocker | `Get-BitLockerVolume`, só as chaves de 48 números. `Add-BitLockerKeyProtector -RecoveryPasswordProtector` com o aviso calado, porque o próprio comando escreve a chave nova num aviso. A chave aparece só na linha de segredo, fora do log. O arquivo traz o que fazer com ele. Salvar no próprio disco criptografado pede confirmação. | Certo. |
| Atualizar assinaturas | `Update-MpSignature` pela ordem de fontes do PC. Se falhar, ou se as assinaturas continuarem com mais de 3 dias, faz uma segunda tentativa direto da Microsoft (`-UpdateSource MMPC`), só quando a ordem de fontes da empresa permite. Os erros comuns vêm explicados com o código; "confira a internet" só para erro de conexão. | Certo. |
| Verificações | `Start-MpScan` (QuickScan, FullScan, CustomScan) com o PC sem dormir. O Parar cancela também no Defender (`MpCmdRun -Scan -Cancel`). As detecções desta verificação são separadas pelo DetectionID lido antes de começar. O que o Defender ainda pede (reiniciar, completa, offline) vem de AdditionalActionsBitMask e ComputerState. A completa e a de uma pasta atualizam antes. | Certo. |
| Avisos da completa e de uma pasta | A completa avisa que pen drives ficam de fora quando DisableRemovableDriveScanning está ligado, o padrão do Windows, e avisa na bateria. A de uma pasta avisa quando o Defender não examina arquivos de rede. | Certo. |
| Segurança do Windows | `windowsdefender:`, `windowsdefender://threat` (vírus e ameaças) e `windowsdefender://network` (firewall). | Certo. |

**Conferido e mantido**
- **Atualizar assinaturas e verificar pedem Administrador.**
- **A verificação offline fica no aplicativo do Windows:** o `Start-MpWDOScan` reinicia o PC na hora, sem aviso.
- **`Update-MpSignature` e `Start-MpScan` sem tempo-limite:** são operações longas que a pessoa espera, com a barra de andamento, e o Parar interrompe a espera. Na verificação, o Parar cancela também no Defender.
- **O SMB 1.0 pelo recurso do Windows**, e não pela configuração do servidor de arquivos: é o que a Microsoft indica para o Windows 10 e 11.

## QA Sênior

**Como foi testado:** cada função da página rodou com o Windows simulado, nos três idiomas: 134 conferências em português e 142 em inglês e em espanhol (as 8 a mais conferem, em cada seção, que nenhum texto do português aparece na tela).
- **Estado da proteção (33):**
  - tudo certo;
  - o antivírus: desligado, outro antivírus ligado, passivo com um antivírus vencido, sem leitura e sem tempo real;
  - as assinaturas: com 10 dias e nunca atualizadas;
  - as ameaças: duas ativas e uma resolvida;
  - o firewall: desligado na rede pública (com o Domínio fora de um domínio), outro firewall ligado e sem leitura;
  - o Windows Update: 7 pendentes e sem resposta;
  - o destino de cada próximo passo;
  - o Defender que não responde e a leitura com `-AsJob`.
- **Auditoria (26):**
  - tudo certo;
  - UAC em "Nunca notificar", Convidado num Windows em português e em inglês, SMB 1.0, entrada automática com a senha gravada e Área de Trabalho Remota;
  - quatro estados do BitLocker e o BIOS legado;
  - sem Administrador e sem o antivírus lido;
  - o Windows 10 fora do ESU;
  - os tetos e a falta de nota.
- **Chave do BitLocker (12):**
  - nenhum disco e só esperando ativação;
  - mostrar (a chave só na linha de segredo);
  - salvar (o arquivo, o pendrive em destaque) e a pasta sem a letra do disco;
  - criar e desistir de salvar, e criar com falha;
  - sem Administrador e sem resposta.
- **Atualizar assinaturas (9):**
  - versão nova e já em dia;
  - a segunda tentativa pela Microsoft;
  - sem internet e a política sem a Microsoft;
  - assinaturas que continuam velhas;
  - outro antivírus e sem Administrador.
- **Verificar vírus (11):**
  - nada encontrado e uma ameaça em quarentena (a de antes não conta);
  - uma que pede ação e uma que pede reiniciar;
  - uma ameaça de antes ainda ativa;
  - outra verificação em andamento;
  - o antivírus sem atualizar e o antivírus desligado;
  - a linha do andamento com o tempo da última.
- **Verificação completa (4):** a pergunta no Não, o aviso da bateria e o dos pen drives, recusada e aceita.
- **Verificar uma pasta (17):**
  - Downloads em destaque;
  - o caminho sem unidade, com aspas e que não existe;
  - cancelar;
  - o caminho de rede;
  - o caminho colado;
  - o nome curto e o lugar da ameaça;
  - os erros de conexão.
- **A página (22):**
  - cada item existe e tem até 60 letras;
  - um destaque só;
  - o escudo nas cinco ações;
  - os três atalhos da Segurança do Windows.
- **Os textos:** nenhum marcador `{0}` sobrando, e nenhum texto do português na tela em inglês e em espanhol, conferido contra as traduções.

**Achados**

| # | Severidade | O que acontecia | Como ficou |
|---|---|---|---|
| Q1 | Média | Com o BitLocker ligado, a auditoria deveria lembrar de guardar a chave em Segurança > Chave de recuperação do BitLocker (o CHANGELOG promete isso desde a R4), mas o lembrete nunca aparecia: o ponto está em ordem, e os conselhos de pontos em ordem eram descartados. A conferência da R4 chamava a auditoria sem conferir o resultado. | Nos pontos que só informam (fora da nota), o conselho aparece também com tudo certo; nos que entram na nota, continua só para o que pede ação. |
| Q2 | Baixa | "Compartilhamento SMB 1.0" saía em português na auditoria em inglês e em espanhol. | Pela tradução, a mesma da tela de recursos do Windows. |
| Q3 | Baixa | Na Verificar uma pasta, a faixa dizia "verificado: D:\Fotos" em português nas telas em inglês e em espanhol. | "scanned:" e "analizado:". |
| Q4 | Baixa | O comando da conta Convidado com o nome da tela (é o M2). | Corrigido. |
| Q5 | Baixa | O motivo errado na auditoria sem Administrador (é o D3). | Corrigido. |

Cada conferência nova falha no código de antes e passa no de agora.

## Engenharia

**Por dentro**
- **Core.psm1:** `Invoke-WinForgeCimCommand` e `$script:WinForgeCimTimeoutSec` (60 segundos), vindos da Diagnostics.psm1, onde a R15 os criou como `Invoke-WinForgeStorageQuery`. O tempo esgotado vira `TimeoutException`: quem chama pode não tentar uma segunda consulta que travaria igual, como o firewall, que sem resposta não tenta mais a leitura local.
- **Diagnostics.psm1:** as partições, os contadores dos discos e os dispositivos pelo `Invoke-WinForgeCimCommand`.
- **Security.psm1, leituras:**
  - `Get-MpComputerStatus`, `Get-MpThreat`, `Get-MpThreatDetection`, `Get-MpPreference` e `Get-NetFirewallProfile` pelo `Invoke-WinForgeCimCommand`;
  - `Get-WinForgeThreatListText` (nova) dá os nomes curtos;
  - `Get-WinForgeGuestAccount` (no lugar de `Get-WinForgeGuestAccountEnabled`) devolve também o nome;
  - os fatos da auditoria ganham `GuestName` e `Administrator`.
- **Security.psm1, telas:**
  - `New-WinForgeAuditCheck` guarda o conselho dos pontos que só informam;
  - `Show-WinForgeSecurityStatus`: a faixa do antivírus sem leitura e o botão do firewall sem leitura;
  - `Get-WinForgeScanOutcome`: o resumo igual à faixa;
  - `Show-WinForgeBitLockerKey`: a falha de criar a chave à parte;
  - o título do SMB 1.0 e o "Verificado: {0}" pela tradução.
- **Traduções:** 5 novas, 5.187 ao todo.

**Conferido na nuvem**
- **As conferências da Segurança:** 134, 142 e 142, todas passando.
- **As de antes continuam passando:**
  - as 212, 224 e 224 do Diagnóstico, com o prazo dos discos agora no Core;
  - as 245, 247 e 252 da Manutenção e as 241 do Início nos três idiomas;
  - as 83 do QA geral, as 80 da R11 e as 60 da R12;
  - as 59 da R9 e as 52 da R10;
  - as 66 da QA, as 28 da integração e as 26 da R7;
  - as 84 ações rodando 336 vezes, com o mesmo resultado da R15;
  - o motor de instalação, a atualização simulada e o Setup de verdade (da R15 para esta), e o pacote de suporte;
  - as traduções (5.187/5.187), as 160 referências nos três idiomas e a busca dos 102 itens;
  - nenhuma chamada com parâmetro que não existe, nenhuma função sem uso e nenhum aviso novo do analisador.

## O que só um PC mostra

Isto entrou no roteiro de conferência:
- **o Estado da proteção e a auditoria num PC real**, com Administrador e sem ele: o antivírus, o firewall e as ameaças lidos como antes, no mesmo tempo. A leitura passou a rodar como trabalho (`-AsJob`): é a mudança mais sensível desta revisão. Sem Administrador, as três linhas que pedem Administrador dizem isso;
- **o lembrete da chave** na auditoria de um notebook com BitLocker;
- **a conta Convidado** ligada num Windows em português com a tela em inglês: o comando diz "Convidado" e funciona;
- **uma ameaça de teste** (o arquivo EICAR) numa pasta verificada por Verificar uma pasta: o nome curto na linha e o nome completo nos detalhes técnicos;
- **criar a chave** num PC de empresa que exige guardá-la no Active Directory, se houver um.

## Fontes
- [Get-MpComputerStatus (Microsoft Learn)](https://learn.microsoft.com/powershell/module/defender/get-mpcomputerstatus): com `-AsJob`.
- [Get-NetFirewallProfile (Microsoft Learn)](https://learn.microsoft.com/en-us/powershell/module/netsecurity/get-netfirewallprofile): com `-AsJob`; o ActiveStore é a política que vale de fato.
- [How to detect, enable and disable SMBv1, SMBv2, and SMBv3 in Windows (Microsoft Learn)](https://learn.microsoft.com/en-us/windows-server/storage/file-server/troubleshoot/detect-enable-and-disable-smbv1-v2-v3): `Get-WindowsOptionalFeature -Online -FeatureName SMB1Protocol`.
- [Well-known SIDs (Microsoft Learn)](https://learn.microsoft.com/en-ie/Windows/Win32/secauthz/well-known-sids): a conta Convidado termina em -501.
- [Accounts: Rename guest account (Microsoft Learn)](https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-10/security/threat-protection/security-policy-settings/accounts-rename-guest-account): uma política pode trocar o nome da conta.
