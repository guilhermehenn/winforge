# WinForge 4.0 — avaliação completa e sugestões (R35)

**Data:** 20/11/2026 · **Versão:** Build 4.0 em preparação, depois da R34 (ec46398)

**Pedido:** "Sem codar ainda: Faça uma avaliação completa do Avyra e sugira novas funcionalidades/tools úteis que se encaixariam bem para essa versão 4.0." O Avyra é o sistema da clínica, que não tem versão 4.0. A avaliação é do WinForge 4.0.

**Como foi feita:**
- a leitura do código, do mapa de funcionalidades, da documentação técnica, do histórico e das revisões de cada tela;
- a comparação com o Microsoft PC Manager, o CCleaner e o WinUtil, pelo que as fontes no fim descrevem;
- o que o Windows 11 mudou em 2026 e pode mudar o trabalho do WinForge, pela documentação da Microsoft.

Nada rodou num Windows de verdade, e nenhuma linha de código mudou.

## Resumo

- **O WinForge 4.0 cobre mais do que as ferramentas comparadas** e com mais cuidado: cada mudança tem volta, as leituras têm prazo e a tela diz o que não deu certo.
- **O maior risco é não ter rodado num Windows de verdade:** o roteiro de conferência tem 27 seções e 191 itens, todos por fazer.
- **Dois riscos novos de 2026:**
  - a **Proteção de Administrador** do Windows separa o perfil da conta elevada, e o WinForge roda a janela inteira elevado;
  - o **Controle Inteligente de Aplicativos** agora liga e desliga sem reinstalar o Windows, e bloqueia código sem assinatura. Os scripts do WinForge não são assinados.
- **Para a 4.0, quatro sugestões:** reconhecer a Proteção de Administrador, pôr prazo no Agendador da Manutenção agendada, conferir os certificados do Secure Boot (os de 2011 venceram entre junho e outubro de 2026) e mostrar se a recuperação do Windows está pronta. As duas primeiras são de robustez; as duas últimas seguem o tema da 4.0, "o WinForge avisa antes do problema".
- **Seis pequenas, se couber:** Windows ativado, integridade da memória, reparar o Instalador de Aplicativo, não atualizar um programa, a fila de impressão e a data e a hora.
- **O resto fica para a 4.1:** a principal é abrir a janela sem Administrador e elevar só as ações que pedem.

## 1. Avaliação

### 1.1 Placar

De 1 a 5, como na revisão da interface (R8).

| Olhar | Nota | Por quê |
|---|---|---|
| Cobertura de funções | 5 | 11 páginas e 102 itens (84 do próprio WinForge), 53 ajustes, o Verificar o PC com 11 etapas, o Otimizar com 20 e o monitor com 10 conferências |
| Segurança para o PC | 5 | Ponto de restauração, backup do valor de antes, Lixeira, prazo nas leituras, nada de `Invoke-Expression`, exclusões que não seguem atalhos de pasta, atualização com SHA-256 e volta ao que era |
| Honestidade | 5 | Nenhuma função falsa; cada faixa diz o que não deu e por quê |
| Interface | 4 | O visual do Windows 11, contraste alto, tamanho do texto e três idiomas; páginas longas e nada visto num PC |
| Robustez do código | 4 | Prazos, `finally`, travas e a reserva de cada caminho; restam a janela inteira elevada e o Agendador sem prazo na Manutenção agendada |
| Confiança para baixar | 2 | Scripts sem assinatura (I2), a licença por decidir (I1) e o aviso do Windows ao abrir |
| Pronto para anunciar | 2 | Nada rodou num Windows real; falta a revisão das traduções por quem fala inglês e espanhol |
| Documentação | 5 | Documentação técnica, histórico de cada revisão, roteiro de conferência e mapa de funcionalidades |

### 1.2 O que está forte

- **O caminho principal é claro:** a nota de saúde do Início leva ao Verificar o PC (que corrige num clique o que é seguro) e ao Otimizar (a manutenção completa, em ordem).
- **O WinForge avisa antes do problema:** o monitor, as telas azuis, a saúde dos discos, o teste de memória e a chave do BitLocker formam um tema fácil de contar.
- **O cuidado com o PC de quem usa:** cada revisão de tela passou pelo designer, pelo MVP Windows, pelo QA e pelo engenheiro (R13 a R28). O WinForge não força o que o Windows protege, e o que não pode desfazer, pergunta antes, com Não como padrão.
- **A entrada e a saída:** instalador, atualização com um clique, desinstalação limpa, pacote de suporte e a identidade por pasta na barra de tarefas (R34).
- **A base para crescer:** a tabela de navegação, o contrato de uma ação, a busca nos três idiomas e as traduções em gettext.

### 1.3 O que preocupa

| # | O quê | Evidência | Peso |
|---|---|---|---|
| P1 | **Nada rodou num Windows de verdade.** Todo o ciclo da 4.0 foi conferido fora do Windows. | O roteiro de conferência tem 27 seções e 191 itens por fazer; a documentação técnica, seção 22. | Alto |
| P2 | **A Proteção de Administrador muda o que a janela elevada enxerga.** A conta elevada passa a ser uma conta escondida do sistema, com perfil próprio: "Settings data for applications don't carry over across the regular (unelevated) and the elevated profiles", e as unidades de rede não aparecem. O WinForge compara o nome da conta elevada com o de quem está logado (`Test-WinForgeUserContextMismatch`): sendo outra conta, como a documentação descreve, ele trataria o caso como "outra conta" (a confirmar num PC). Os ajustes do perfil ficariam de fora, com uma orientação que a pessoa não consegue seguir: "abra o WinForge sem trocar de conta no pedido de Administrador". | A documentação da Microsoft: desligada por padrão, mas ligada por padrão desde outubro de 2026 em quem usa as linhas de base de segurança do Windows. O código: Core.psm1 e Tweaks.psm1. | Médio hoje, alto depois |
| P3 | **O Controle Inteligente de Aplicativos e os scripts sem assinatura.** Desde fevereiro de 2026, ele liga e desliga sem reinstalar o Windows. A documentação diz que "unknown, unsigned code" é bloqueado, mas não diz se isso vale para scripts do PowerShell. | Microsoft: Smart App Control; o histórico de recursos do Windows 11 em 2026. | Médio, a conferir num PC |
| P4 | **A Manutenção agendada fala com o Agendador de Tarefas sem prazo.** A R18 deu prazo à Inicialização e deixou esta para a revisão da Manutenção. | Schedule.psm1: `Get-ScheduledTask`, `Get-ScheduledTaskInfo`, `Register-ScheduledTask` e `Unregister-ScheduledTask` chamados direto, sem `Invoke-WinForgeCimCommand`. | Baixo |
| P5 | **A abertura nunca foi medida num PC.** A janela carrega os 38 módulos antes de aparecer. | M17; `logs\abertura.log` existe para medir. | A medir |
| P6 | **O tamanho:** cerca de 62 mil linhas de PowerShell, 1.262 funções nos módulos, e as conferências de cada revisão fora do repositório. | Documentação técnica, seção 22. | Baixo agora, cresce com o tempo |
| P7 | **Muita coisa na tela:** 102 itens em 11 páginas, para quem quer telas limpas e diretas. | O mapa de funcionalidades; a ideia I4 (duas camadas). | Baixo |

### 1.4 Comparação com o mercado

"—" quer dizer que a função não aparece nas fontes consultadas, e não que a ferramenta não a tenha.

| Função | WinForge 4.0 | PC Manager | CCleaner grátis | WinUtil |
|---|---|---|---|---|
| Verificação geral do PC | Verificar o PC | Verificação de saúde | Health Check | — |
| Limpeza | Rápida, personalizada, Downloads, componentes | Limpeza do armazenamento | Personalizada | — |
| O que abre com o Windows | Programas e tarefas agendadas | Inicialização | Programas, tarefas e menu de contexto | — |
| Desinstalar programas | Sim, com o winget | — | Sim | Sim, com o winget |
| Atualizar programas | Sim, com o winget | — | Só na versão paga | Sim, com o winget |
| Drivers | Pelo Windows Update | — | Só na versão paga | — |
| Reparar o Windows (DISM e SFC) | Sim | — | — | Sim |
| Rede e Windows Update | Reparo de rede, DNS e Corrigir o Windows Update | — | — | Reset da rede e do Windows Update |
| Ajustes com desfazer | 53, com backup do valor | — | — | Sim, com ponto de restauração |
| Avisos em segundo plano | Monitor na bandeja | — | — | — |
| Relatório e pacote de suporte | Sim | — | — | — |
| Apagar o espaço livre | Sim | — | Drive Wiper | — |
| Arquivos duplicados | Sim | — | Sim | — |
| Pontos de restauração antigos | — | — | Apaga | — |
| Extensões dos navegadores | — | — | Lista e remove | — |
| Reparar o winget | Só avisa que falta | — | — | Winget Repair |

O que só os outros têm, e o que a avaliação fez com cada um:
- **Reparar o winget** e **o menu de contexto:** viraram sugestões (N7 e N16).
- **Apagar pontos de restauração** e **as extensões dos navegadores:** ficaram de fora, com o motivo na seção 2.5.

## 2. Sugestões

### 2.1 O critério

Uma sugestão entra quando:
- **resolve algo real do PC de quem usa,** com o que o Windows documenta;
- **cabe numa tela que já existe,** com pouco texto;
- **não é função falsa:** o que o WinForge não consegue ler ou fazer de verdade não aparece;
- **tem volta,** ou só lê;
- **conversa com o resto:** a busca, o Verificar o PC, o monitor, o relatório e o Histórico de mudanças, onde fizer sentido.

**Para a 4.0, a regra é mais dura:** a 4.0 ainda não passou pelo PC, e cada função nova é mais um item no roteiro. Por isso a lista da 4.0 é curta e quase toda de leitura.

Tamanho: P = cabe numa revisão; M = duas ou três; G = um projeto.

### 2.2 Para a 4.0: recomendadas

| # | Sugestão | Onde entra | Tamanho | Risco |
|---|---|---|---|---|
| N1 | Reconhecer a Proteção de Administrador | Sobre o WinForge, Ajustes do Windows, Personalização e o resto que hoje diz "outra conta" | P | Baixo |
| N2 | O Agendador com prazo na Manutenção agendada | Manutenção > Manutenção agendada, o cartão do Início | P | Baixo |
| N3 | Os certificados do Secure Boot | Segurança > Auditoria de segurança, Diagnóstico > Sobre este PC, relatório | P | Baixo (só lê) |
| N4 | A recuperação do Windows pronta | Diagnóstico > Funcionamento do Windows (item novo), Verificar o PC | P a M | Baixo (só lê) |

**N1 · Reconhecer a Proteção de Administrador**
- **O problema:** com ela ligada, a janela elevada roda numa conta escondida do sistema, com perfil próprio. O WinForge veria "outra conta" e mandaria abrir "sem trocar de conta", o que não é possível.
- **A proposta:** reconhecer o caso e dizer a coisa certa. Por exemplo: "Com a Proteção de Administrador do Windows, os ajustes do seu perfil não podem ser feitos pelo WinForge aberto como Administrador." Onde houver, dar o caminho que funciona: as Configurações do Windows para os ajustes do perfil.
- **Como reconhecer:** pela política documentada ("User Account Control: Configure type of Admin Approval Mode"). O nome do valor no registro e o nome da conta elevada não estão na documentação: confirmar num PC com a proteção ligada antes de escrever o código.
- **Por que na 4.0:** sem isso, quem tiver a proteção ligada recebe uma instrução impossível em várias telas. A solução de verdade (N11) é grande e fica para a 4.1.

**N2 · O Agendador com prazo na Manutenção agendada**
- **O problema:** `Get-ScheduledTask`, `Get-ScheduledTaskInfo`, `Register-ScheduledTask` e `Unregister-ScheduledTask` são chamados sem prazo na Schedule.psm1. Com o Agendador de Tarefas travado, a tela fica parada, como a R18 achou na Inicialização.
- **A proposta:** o mesmo `Invoke-WinForgeCimCommand` com prazo que a Inicialização e a execução sem Administrador (R32) já usam, e "não foi possível ler" no lugar da espera.
- **Por que na 4.0:** é dívida conhecida, pequena e do mesmo tipo das que as revisões R12 a R19 fecharam.

**N3 · Os certificados do Secure Boot**
- **O problema:** os certificados de 2011 do Secure Boot venceram entre 24/06/2026 (o KEK) e 19/10/2026 (o que assina o carregador do Windows). O PC que não recebeu os de 2023 continua ligando e recebendo as atualizações comuns, mas "will no longer be able to receive new security protections for the early boot process". A Microsoft diz que a maioria recebe os novos sozinha, e que alguns PCs precisam de firmware do fabricante.
- **A proposta:** uma linha na Auditoria de segurança e em Sobre este PC: "Certificados do Secure Boot: atualizados" ou "ainda os de 2011". No segundo caso, o caminho: Windows Update e, se não resolver, as Ferramentas do fabricante (que já existem). Com o Secure Boot desligado ou no modo BIOS legado, a linha não aparece.
- **Como ler:** `Get-SecureBootUEFI` (só com Administrador), procurando "Windows UEFI CA 2023" no DB e o KEK de 2023. O suporte da Microsoft diz que os dois precisam estar atualizados.
- **Por que na 4.0:** é do tema "o WinForge avisa antes do problema", está no prazo de agora e só lê.

**N4 · A recuperação do Windows pronta**
- **O problema:** quando o PC não liga, o que salva é o Ambiente de Recuperação do Windows (WinRE). Com ele vêm a Recuperação rápida da máquina (que procura a correção no Windows Update), a Restauração pontual (julho de 2026) e a Reinstalação pela nuvem (novembro de 2026). Um WinRE desligado só aparece no dia em que faz falta.
- **A proposta:** um item "Recuperação do Windows", que diz numa tela só:
  - se o WinRE está ligado;
  - se a Recuperação rápida está ligada (`reagentc /getrecoverysettings`, que devolve XML);
  - se a Proteção do sistema está ligada no disco do Windows, e o ponto de restauração mais recente;
  - o botão para Configurações > Sistema > Recuperação, onde fica a Restauração pontual. A página de suporte dela não traz uma leitura do estado e aponta a documentação para empresas: se houver ali uma leitura documentada, a tela diz se ela está ligada; se não, só leva até ela.
- **No Verificar o PC:** o WinRE desligado vira ponto de atenção.
- **Cuidado:** a saída do `reagentc /info` sai no idioma do Windows. A leitura do estado do WinRE precisa de um caminho que não dependa do idioma, a decidir com o MVP Windows na implementação.

### 2.3 Para a 4.0: se couber

| # | Sugestão | Onde entra | Tamanho | Risco |
|---|---|---|---|---|
| N5 | Windows ativado (era M11) | Diagnóstico > Sobre este PC, relatório | P | Baixo (só lê) |
| N6 | A integridade da memória na auditoria | Segurança > Auditoria de segurança | P | Baixo (só lê) |
| N7 | Reparar o Instalador de Aplicativo (winget) | A faixa "Falta o Instalador de Aplicativo" | P | Baixo |
| N8 | Não atualizar este programa (era M6) | Atualizações > Atualizar programas (winget), o monitor | P a M | Baixo (tem volta) |
| N9 | Destravar a impressão | Reparo, grupo novo, ou Diagnóstico | P | Baixo |
| N10 | Acertar a data e a hora | Rede > Consertar e configurar | P | Baixo |

- **N5 · Windows ativado:** uma linha em Sobre este PC e no relatório. A leitura do licenciamento pelo WMI costuma ser lenta, por isso fica fora do Início.
- **N6 · A integridade da memória:** a proteção que o Windows passou a ligar em mais PCs nas atualizações (novembro de 2026). A auditoria diria se ela está ligada, com o caminho para Segurança do Windows > Segurança do dispositivo. Ela só lê: ligar a integridade da memória pode esbarrar em drivers antigos, e é escolha da pessoa.
- **N7 · Reparar o Instalador de Aplicativo:** onde hoje a faixa diz que falta o winget, um botão que roda o comando que a Microsoft indica para registrar o winget de novo (`Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe`). Se não resolver, a Microsoft Store abre na página do Instalador de Aplicativo. O WinUtil tem um Winget Repair.
- **N8 · Não atualizar este programa:** o `winget pin` tira um programa do `winget upgrade --all`; o tipo de bloqueio (`--blocking`) impede também a atualização pedida só para ele. Na lista de Atualizar programas, "Não atualizar"; numa linha embaixo, os que estão assim, com "Voltar a atualizar". O monitor e o Verificar o PC, que contam os programas com versão nova, deixam esses de fora. Entra no Histórico de mudanças, com desfazer.
- **N9 · Destravar a impressão:** a fila de impressão travada é uma queixa comum. A correção conhecida para o serviço Spooler, limpa a fila e liga o serviço de novo, com a pergunta antes, porque apaga o que estava esperando para imprimir. Validar o passo a passo com o MVP antes de escrever o código.
- **N10 · Acertar a data e a hora:** um relógio errado quebra os sites seguros e o Windows Update. A proposta pede ao Windows para sincronizar a hora agora (`w32tm /resync`), com o serviço de hora ligado. O Reparar rede e DNS, quando os sites seguros falham, pode apontar para aqui.

**Feito na R36 (20/11/2026):** N5 a N10 entraram na 4.0 (o detalhe está no [histórico](historico-4.0.md), R36). O que mudou da proposta:
- **N7:** o reparo é um item sem cartão em Programas, aberto pelo botão **Reparar** da faixa e pela busca. Com o winget respondendo, ele não mexe em nada.
- **N8:** virou um item próprio, **Atualizações > Manter programas na versão atual**, em vez de uma opção dentro da lista de Atualizar programas, que o Otimizar também usa. O marcador é o comum do winget, e não o `--blocking`: assim, quem quiser atualizar um programa marcado pelo nome, no próprio winget, consegue. Atualizar programas ganhou a linha de quantos ficaram de fora.
- **N9:** em **Reparo > Disco e dispositivos**. Só reiniciar o Spooler vem em destaque; esvaziar a fila é a segunda opção, que diz quantos documentos não serão impressos. Um Spooler desativado fica como está.
- **N10:** além do `w32tm /resync`, a hora é conferida num servidor da Microsoft. O Windows fora de domínio não corrige sozinho mais de 15 horas; aí, com a pessoa concordando, o relógio vai para a hora do servidor. O Reparar rede e DNS não aponta para aqui: ele não tem como saber se o erro dos sites seguros vem do relógio.

### 2.4 Para a 4.1 ou depois

| # | Sugestão | Por que depois | Tamanho |
|---|---|---|---|
| N11 | **A janela sem Administrador, com as ações elevadas à parte.** Resolve de vez a Proteção de Administrador, os ajustes do perfil com outra conta, as unidades de rede e os programas só da conta (a R32). De quebra, abrir o WinForge deixa de pedir o Administrador toda vez. É o que a Microsoft pede: "Only elevate apps you truly need to". | Muda a arquitetura da janela, das ações e do monitor. | G |
| F2 + I2 | **O inicializador .exe assinado, e o certificado.** O aviso do Windows passa a mostrar "WinForge" e o editor, e a assinatura responde ao Controle Inteligente de Aplicativos (P3). | Espera o certificado. | M |
| M3 + M4 | **O Otimizar com tudo o que pede a pessoa no começo, e o tempo estimado.** | Mexe no fluxo principal, que só deve mudar depois da conferência no PC. | M |
| M7 | **Desinstalar com os restos daquele programa.** | Grande; os restos já existem como item à parte. | M |
| F5 | **Configurar um PC novo:** restaurar o backup, remover os aplicativos que vêm com o PC, os ajustes recomendados, os essenciais e atualizar tudo. | Junta funções que já existem; depende da conferência delas no PC. | M |
| N12 | **O DNS criptografado (DoH)** junto da troca do DNS. Ideia da revisão da Rede (R22). | Mexe na rede de quem usa; pede o mesmo cuidado da troca de DNS. | M |
| N13 | **O tempo para ligar o PC, antes e depois** (F3 + F8). | Só com a medição confiável num PC com a Inicialização Rápida. | M |
| N14 | **Duas camadas:** o essencial à mostra, "Mostrar tudo" para o resto (I4). | Pede um teste com pessoas, como a arquitetura de páginas da R8. | M |
| N15 | **As conferências dentro do repositório,** para cada mudança rodar a mesma bateria. O README e o CHANGELOG continuam sem falar delas. | Organização do código, sem efeito para quem usa. | M |
| N16 | **O menu de contexto lento:** os itens que os programas põem no clique direito. O CCleaner lista e desliga. | Cada programa registra do seu jeito; desligar o errado quebra o programa. Pede estudo. | M |

### 2.5 Avaliadas e deixadas de fora

- **"Otimizador de desempenho" que adormece programas** (CCleaner pago) e **o "boost" automático:** o efeito é passageiro, e a própria crítica ao PC Manager diz isso ("rarely produces lasting performance gains"). Já estava em "Deixar de fora" no mapa de melhorias (limpador de memória automático).
- **Atualizador de drivers de outra empresa:** o WinForge usa o Windows Update e as ferramentas do próprio fabricante, o caminho seguro.
- **Desligar as atualizações do Windows** (WinUtil): deixa o PC sem as correções de segurança.
- **Criar uma imagem do Windows enxuta** (o Win11 Creator do WinUtil): é outro produto, para quem formata.
- **Apagar os pontos de restauração antigos** (CCleaner): tira a rede de segurança, e o Windows já apaga os mais velhos quando falta espaço.
- **Listar as extensões dos navegadores:** cada navegador e cada perfil guarda de um jeito; só listar renderia pouco, e remover é com o próprio navegador.
- **O Sysmon** que o Windows passou a trazer (março de 2026): é monitoração de segurança para empresas.
- **O teste de velocidade do próprio Windows** (março de 2026): o WinForge já tem o seu, que mede sem sair da janela.

## 3. Ordem proposta

1. **Robustez:** N2 e N1, antes de qualquer função nova.
2. **O tema da 4.0:** N3 e N4, cada um com a revisão de design, Windows e QA, como as telas da R13 à R28.
3. **Se couber:** N5 a N10, na ordem que o dono preferir. Cada um é pequeno e independente.
4. **A conferência num PC,** pelo roteiro, com as seções novas destas sugestões, um PC com a Proteção de Administrador ligada e outro com o Controle Inteligente de Aplicativos ligado.
5. **As decisões do dono antes de anunciar:** I1 (licença) e I2 (certificado). A revisão das traduções por quem fala inglês e espanhol.
6. **A 4.1:** N11 primeiro, porque muda a base em que o resto se apoia; depois F2 + I2 e o fluxo do Otimizar (M3 + M4).

## Fontes

- Microsoft:
  - [Administrator protection](https://learn.microsoft.com/en-us/windows/security/application-security/application-control/administrator-protection)
  - [Smart App Control](https://learn.microsoft.com/en-us/windows/apps/develop/smart-app-control/overview)
  - [Windows Secure Boot certificate expiration and CA updates](https://support.microsoft.com/help/5062710)
  - [Quick machine recovery](https://learn.microsoft.com/windows/configuration/quick-machine-recovery)
  - [Point-in-time restore for Windows](https://support.microsoft.com/windows/experience/backup-recovery/point-time-restore-for-windows)
  - [WinGet](https://learn.microsoft.com/ga-ie/windows/package-manager/winget/) e [o comando pin](https://learn.microsoft.com/en-us/windows/package-manager/winget/pinning)
- As mudanças do Windows 11 em 2026, mês a mês: [Pureinfotech](https://pureinfotech.com/windows-11-feature-history-2026)
- A Proteção de Administrador ligada pelas linhas de base de segurança: [Tech Community](https://techcommunity.microsoft.com/discussions/security-baselines/administrator-protection---default-enabled/4564564)
- Como conferir os certificados do Secure Boot: [Pureinfotech](https://pureinfotech.com/check-secure-boot-certificates-expiration-windows-11/)
- As outras ferramentas:
  - [o PC Manager, na WTOP](https://wtop.com/tech/2026/01/data-doctors-should-i-be-using-microsoft-pc-manager)
  - [o CCleaner, na PCWorld](https://www.pcworld.com/article/2909300/how-to-use-ccleaner-to-free-up-pc-storage-and-boost-performance.html)
  - [o WinUtil em 2026](https://christitus.com/winutil-in-2026/)
