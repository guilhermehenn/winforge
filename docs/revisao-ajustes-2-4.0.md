# WinForge 4.0 — segunda revisão dos Ajustes do Windows (R52)

**Data:** 22/11/2026 · **Versão:** Build 4.0 em preparação, depois da R51

**Pedido:** revisar a tela e a função Ajustes do Windows com cinco olhares:
- **Analista de Produto Sênior:** avalia o todo.
- **Engenheiro de Software Sênior:** revisa o código, refatora, segue as boas práticas, tira o que não serve e melhora o desempenho.
- **Designer Sênior, com um Especialista em UX/UI:** revisam a tela, os botões, os textos e os fluxos; o engenheiro aplica.
- **MVP Windows:** confere se os Ajustes seguem as práticas da Microsoft, se cada função faz da melhor forma o que promete e se é robusta e estável.
- **QA Sênior:** testa tudo o que dá para testar, o óbvio e o que não é; o engenheiro aplica.

**De onde partiu:** a primeira revisão dos Ajustes (R23) foi antes do desenho novo (R37), da revisão de UX (R38) e das faixas no alto das páginas (R41 a R48). A R49 e a R50 mexeram só no que a revisão do Otimizar mostra. Esta olhou a página inteira: as ações, as chaves e o que elas dividem com a Personalização (a mesma tela de chaves), o Otimizar (a revisão dos ajustes) e o Backup antes de formatar (a lista dos ajustes aplicados).

**Resultado:** 12 achados, todos corrigidos.

| Olhar | Achados |
|---|---|
| Produto | 3: Aplicar ajustes recomendados pedindo Administrador para mudar só o perfil do usuário, e aplicando no perfil de outra conta; elevado com outra conta, os perfis, a importação, a exportação, o backup e a lista lendo ou mudando o perfil dessa conta; e o perfil Trabalho ligando os segundos no relógio |
| Engenharia | 2: um modo de Aplicar ajustes recomendados que ninguém chamava, com o que só ele usava; e o ajuste procurado pelo Id percorrendo o catálogo, com a regra de outra conta escrita só num lugar |
| Designer e UX/UI | 4: a chave saindo da página (a UX19 da R38); Sim e Não nas perguntas (a UX21); o parágrafo no alto (a UX14); e o "Lendo..." escrito (a UX16) |
| MVP Windows | 2: o plano Alto desempenho oferecido nos PCs com Modern Standby, que não o permitem; e a web na busca sem dizer que tira também as buscas recentes do Explorador |
| QA | 1: a chave da Inicialização Rápida ligando a hibernação junto sem dizer isso na faixa |

Nada rodou num Windows de verdade. A conferência foi feita na nuvem com o Windows simulado da R23 (o registro, o `powercfg`, a Restauração do Sistema, o Explorador, a sessão e a build) e com a janela simulada da R37. O que só um PC mostra entrou no roteiro de conferência (§42).

## Os Ajustes do Windows hoje

A página tem, no alto, **Aplicar ajustes recomendados** (em destaque), **Mais opções** (Perfis de ajustes, Criar ponto de restauração, Exportar ajustes aplicados, Importar ajustes e Desfazer ajustes do WinForge) e **Atualizar estado**. Abaixo, agora, o resumo da página e as chaves por categoria: Explorador, Privacidade e sugestões, Windows Update, Notificações e teclado (com as linhas Teclas que trocam o idioma do teclado e Notificações e Não incomodar), Jogos e Energia e desempenho (com os avançados recolhidos).

Perfis, Criar ponto, Importar e Desfazer pedem Administrador e mostram o escudo. Aplicar ajustes recomendados deixou de pedir (P1).

## Analista de Produto

| # | O que estava | Por que importa | Como ficou |
|---|---|---|---|
| P1 | Aplicar ajustes recomendados pedia Administrador. Os quatro recomendados (extensões de arquivos, dicas e sugestões, dicas da tela de bloqueio e ID de publicidade) só mudam o perfil do usuário, como as Configurações do Windows. | Numa conta sem Administrador, o pedido leva à senha de outra conta. Com ela, o WinForge roda como essa conta e os quatro iam para o perfil dela, e não para o da pessoa; sem ela, nada era aplicado. A ação em destaque da página falhava justamente para quem mais precisa dela. | Não pede mais Administrador, e o escudo saiu. Sem Administrador, aplica no perfil da pessoa: o ponto de restauração, que pede Administrador, fica de fora, e a tela diz que cada ajuste se desfaz pela chave dele. Com Administrador, o ponto continua oferecido. Elevado com outra conta, para antes de perguntar qualquer coisa: "Os ajustes recomendados valem para a sua conta", com a conta e o caminho (abrir o WinForge de novo e recusar o pedido de Administrador). |
| P2 | Elevado com outra conta, só a revisão do Otimizar e as chaves deixavam de fora os ajustes do perfil do usuário. Os perfis e a importação os aplicavam no perfil dessa conta; Exportar e o Backup antes de formatar levavam os ajustes dela; a lista mostrava o estado dela; e a linha das teclas do idioma lia o teclado dela. | O que se lê e o que se muda tem de ser do perfil de quem usa o PC. Um backup com os ajustes de outra conta seria restaurado no perfil errado depois de formatar. | Uma regra só, em todos esses lugares: elevado com outra conta, os ajustes do perfil do usuário ficam de fora, com um aviso de quantos. O Essencial, que só tem ajustes do perfil, para com a faixa que diz por quê e por onde aplicar. Na lista, a linha diz **Outra conta** e a chave fica desligada, com a dica do motivo; o resumo do alto mostra só essa linha, em amarelo; no menu de texto, um traço no lugar do estado e uma linha no alto. |
| P3 | O perfil Trabalho, "menos distrações", ligava os segundos no relógio da barra de tarefas. | Os segundos são gosto, e um relógio que muda a cada segundo distrai. O Windows vem sem eles também pelo custo: uma atividade periódica não deixa o processador descansar. | O Trabalho fica com o Essencial, sem Widgets e sem web na busca, o menu de contexto clássico e, onde existe, sem o botão do Copilot. A chave dos segundos continua na Personalização. |

**Conferido e mantido:**
- **Um destaque só,** Aplicar ajustes recomendados, e os quatro recomendados de sempre, que ninguém deixa de querer.
- **Os cinco perfis pelo nome** (Essencial, Trabalho, Jogos, Privacidade e Notebook), cada um só com ajustes do catálogo.
- **O Desfazer ajustes do WinForge com Cancelar como padrão** (R23) e a importação com a lista para a pessoa escolher.

## Engenheiro de Software

| # | O que estava | Como ficou |
|---|---|---|
| E1 | Aplicar ajustes recomendados tinha um modo para rodar dentro do Otimizar (`-Ids`, `-Embedded`, `-PassThru`) que ninguém chama: o Otimizar usa a revisão dos ajustes. O `-Unattended` do lote só servia a esse modo. `Test-WinForgeTweakValueAtTarget` recebia `Path`, `Name`, `Target` e `Kind`, que nenhuma chamada usava sem a alteração do catálogo. | O modo, o `-Unattended` e os quatro parâmetros saíram. A conferência do desfazer recebe só a alteração do catálogo. |
| E2 | `Get-WinForgeTweakById` percorria o catálogo inteiro a cada chamada, e o desfazer, a importação, os perfis e o Histórico procuram um ajuste por vez. A regra de outra conta (P2) estava escrita só na revisão do Otimizar. | Um índice por Id, montado junto com o catálogo: 1.060 buscas em 62 ms, eram 954 ms. A regra virou `Get-WinForgeTweaksForSession`, usada nos seis lugares de P2. |

**Por dentro:**
- **Tweaks.psm1:**
  - `Get-WinForgeTweaksForSession` e `Get-WinForgeTweaksPageStatus` (novas);
  - o índice em `Get-WinForgeTweakCatalog` e `Get-WinForgeTweakById`;
  - `NotOnModernStandby` em `New-WinForgeTweak`, no Alto desempenho e em `Test-WinForgeTweakAvailable` (M1);
  - `OtherAccount` em `Get-WinForgeTweakOverview`; `Get-WinForgeTweakActionState` vazio com outra conta;
  - `Invoke-WinForgeRecommendedTweaks` sem Administrador e com a parada de outra conta; `Invoke-WinForgeTweakBatch` com o ponto só com Administrador;
  - `Invoke-WinForgeTweakProfile`, `Invoke-WinForgeTweakImportFile`, `Get-WinForgeAppliedTweakIds`, `Select-WinForgeRecommendedTweaks` e `Invoke-WinForgeTweakReview` pela regra de outra conta;
  - o Trabalho sem os segundos; a descrição da web na busca;
  - `Note` no relatório do desfazer, com a hibernação da Inicialização Rápida (Q1);
  - `Quiet` na chave (D1) e os botões (D2).
- **Core.psm1:** `Test-WinForgeModernStandby` (nova).
- **Console.psm1:** `Quiet` em `Set-WinForgeResultView` e no desfecho.
- **Navigation.psm1:** Aplicar ajustes recomendados sem o escudo.
- **Menus.psm1:** o traço e a linha de outra conta no menu de texto.
- **WinForge.Gui.ps1:** a chave na própria linha (`Test-GuiInPlaceHere`, `Test-GuiQuietOutcome`, `Set-GuiTweakRowBusy`, `Update-GuiTweakRow`), o resumo (`Set-GuiTweaksStatus`) e o esqueleto (`New-GuiTweaksSkeleton`), novas; saiu `Get-GuiTweaksHintText`.
- **Traduções:** 5.706 textos (30 novos e 6 que saíram de uso). Entraram três funções nos módulos (1.322) e seis na janela, que perdeu uma (196).

## Designer e Especialista em UX/UI

| # | O que estava | Orientação | Como ficou |
|---|---|---|---|
| D1 | Cada chave abria a tela de execução: a pessoa lia "Modo escuro: ativado", clicava em Voltar e a página lia de novo todos os ajustes. Eram duas trocas de tela para cada uma das chaves de Ajustes e Personalização (a UX19 da R38). | A Microsoft orienta usar a chave para opções de dois estados que valem logo depois que a pessoa a muda. | A chave muda na própria linha. Durante a ação, a linha diz **Alterando…** e a chave não aceita outro clique. No fim, a linha mostra o estado lido de novo só daquele ajuste, o foco do teclado volta para a chave, o leitor de tela ouve como o recurso ficou e o resumo do alto é refeito. A tela de execução abre quando há algo a ler: uma pergunta (o Explorador, o notebook, o estado não identificado), o que ficou como estava, o que foi feito junto, o que falta para a mudança aparecer, o reinício ou uma falha. Em outra página, uma chave sem nada a ler não deixa faixa; com falha, a faixa espera em **Ver resultado**. |
| D2 | Sim e Não nas perguntas da página e Confirmar nas listas (a UX21 da R38, já aplicada nas outras páginas). | Os botões dizem o que fazem. | **Criar o ponto** e **Aplicar sem ele**; **Aplicar mesmo assim** e **Cancelar**; **Reiniciar agora** e **Depois** (o Explorador); **Mostrar** e **Agora não** (a exportação); **Ativar** ou **Desativar** e **Cancelar** (a chave), com **Ativar mesmo assim** ou **Desativar mesmo assim** no aviso do notebook; **Abrir** e **Agora não** (a configuração protegida); **Desfazer todos** e **Cancelar**; **Aplicar**, **Desfazer** ou **Aplicar e desfazer** e **Deixar como está** (a revisão do Otimizar); **Aplicar** nas listas. O lado seguro de cada pergunta não mudou. No menu de texto, continuam com S/N. |
| D3 | Abaixo dos botões, um parágrafo: "Cada chave mostra como o Windows está agora: ligue para ativar e desligue para desativar. O WinForge guarda o valor de antes. Mudados pelo WinForge nesta página: 0." Era a única página sem o resumo do alto (a UX14 da R38). | O mesmo jeito em todas as páginas; a instrução já está na dica de cada chave. | O resumo, como nas outras páginas: **Recomendados · 2 de 4 em uso**, que leva a Aplicar ajustes recomendados (ou **todos em uso**, sem destino), e **Mudanças · 3 ajustes desta página mudados pelo WinForge**, que leva ao Histórico de mudanças (ou **nenhum**, discreto). Um ajuste que a pessoa mudou depois não conta como do WinForge. Na Personalização, só Mudanças. O parágrafo saiu. |
| D4 | Enquanto lia o Windows, a página escrevia "Lendo o estado atual dos ajustes..." (a UX16 da R38). | Esqueletos, como no Início desde a R9. | Um cartão com linhas-esqueleto do tamanho das linhas de ajuste; o leitor de tela ouve "Lendo o estado atual dos ajustes...". Vale também para a Personalização. |

**Conferido e mantido:**
- **A chave nunca mostra um estado que o Windows não tem** (R23): no fim, a linha é lida de novo, e cada mudança continua indo para o Histórico de mudanças.
- **As ações da página,** como Aplicar ajustes recomendados, continuam na tela de execução: elas perguntam e aplicam vários de uma vez.
- **As perguntas começam no lado seguro** (R23): sem o ponto e no notebook, no Cancelar; Desfazer todos, no Cancelar.

## MVP Windows

| # | O que estava | Por que importa | Como ficou |
|---|---|---|---|
| M1 | O plano Alto desempenho aparecia em todo PC. | A Microsoft diz que os PCs com Modern Standby só permitem o plano Equilibrado ou os derivados dele. Lá, o Alto desempenho não vem na lista, e a chave criaria uma cópia dele e a ativaria, contra a regra desses PCs. | O WinForge lê se o PC usa o Modern Standby (`GetPwrCapabilities`, o campo `AoAc`, "the system supports the S0 low power idle model"), uma vez por sessão. Nesses PCs, o Alto desempenho sai da página, do Otimizar, do perfil Jogos e da importação. Sem conseguir ler, nada some. Os outros ajustes de energia continuam. |
| M2 | "Desativar resultados da web na busca do Iniciar" dizia só "mostra só o que está no PC, sem sugestões do Bing". | A política que o ajuste grava (`DisableSearchBoxSuggestions`, do usuário) é, para a Microsoft, "Turn off display of recent search entries in the File Explorer search box": ela também faz o Explorador deixar de sugerir as buscas recentes. A pessoa precisa saber disso antes. | "A busca do Iniciar fica só no PC, sem o Bing; o Explorador deixa de sugerir as buscas recentes." A dica da chave diz o mesmo. A política não mudou. |

**Conferido**, com as fontes no fim:
- **A leitura do Modern Standby:** o `AoAc` vem depois de 20 campos de um byte em `SYSTEM_POWER_CAPABILITIES`, então é o byte 20.
- **A web na busca:** a política vale do Windows 10 2004 com a KB5005101 e do Windows 11 21H2 em diante, só para o usuário, em `Software\Policies\Microsoft\Windows\Explorer`, como o catálogo grava.
- **Os segundos no relógio:** Raymond Chen explica que uma atividade periódica impede o processador de entrar num estado de baixo consumo, e que os timers não essenciais devem ter pelo menos um minuto.
- **O ponto de restauração** continua só com Administrador, porque é assim que o Windows o cria.
- **O restante da R23 continua valendo:** cada chave grava o que as Configurações do Windows gravam (ou a política, nos que dizem "Permitir"), guarda o valor de antes e anota no Histórico; o ponto de restauração antes do lote é criado na hora, mesmo com um de horas atrás.
- **Robusto:** a regra de outra conta vale para tudo o que lê ou muda o perfil do usuário; uma chave que falha abre o resultado, e a página lê de novo ao voltar; uma falha no resumo do alto deixa a página sem ele, e não sem as chaves.

## QA Sênior

**Como foi testado:** uma bateria nova dos Ajustes, 137 conferências em português e 147 em inglês e em espanhol (nos outros dois, mais uma por seção: nenhuma palavra solta em português na tela).
- **Aplicar ajustes recomendados (A):** sem Administrador (a lista, os quatro no perfil, nenhum ponto tentado, nada gravado no sistema), com Administrador (o ponto oferecido e criado), com outra conta (para antes da lista, nada gravado), já aplicados e cancelado.
- **Outra conta (B):** os perfis, o Essencial, a importação, a exportação, o Backup antes de formatar, a lista, a linha das teclas do idioma, o menu de texto e a revisão do Otimizar; e tudo igual com a própria conta.
- **Os perfis (C):** o Trabalho sem os segundos, com o resto, e os outros como eram.
- **O Modern Standby (D):** o Alto desempenho fora da página, do Otimizar e do perfil Jogos, os outros de energia mantidos, sem Modern Standby como antes, o byte do `AoAc` e a leitura fora do Windows.
- **A web na busca (E):** a descrição, a dica, o tamanho e a política.
- **Quando a chave termina na linha (F):** aplicar e desfazer sem nada a dizer, com o valor guardado e sem ele; o que ficou como estava, a hibernação, a cor sem o modo escuro, o agendamento de GPU, o valor que o Windows não manteve, a falha e o Explorador.
- **Os botões (G)** de cada pergunta e lista, nos casos de cada uma.
- **O código (H):** o que saiu, o índice e a velocidade.
- **O resumo do alto (I):** nada aplicado, três e quatro recomendados, os mudados pelo WinForge e os que a pessoa mudou depois, a Personalização e outra conta.
- **A janela (K e L):** o esqueleto e a leitura; o resumo logo abaixo dos botões; a linha de outra conta; a chave mudando na linha (Alterando…, o estado lido de novo, o foco, o leitor de tela, o resumo refeito); a tela de execução quando há algo a ler, uma pergunta ou uma falha; outra página com e sem falha; a página refeita durante a ação.
- **Os textos** nos três idiomas.

**Achado**

| # | O que estava | Como ficou |
|---|---|---|
| Q1 | Ligar a chave da Inicialização Rápida com a hibernação desligada liga a hibernação junto, porque uma precisa da outra. A frase ficava só no texto da tela de execução, e a faixa dizia apenas "Inicialização Rápida: ativado". Com a chave mudando na linha (D1), nem o texto apareceria. | O desfazer devolve o que fez a mais, e a faixa diz: "A Inicialização Rápida precisa da hibernação: a hibernação foi ativada também." Por isso, essa chave abre a tela de execução. |

Os testes também acharam os do produto (P1 a P3), os da engenharia (E1 e E2), os do designer (D1 a D4) e os do MVP (M1 e M2).

**As baterias antigas, adaptadas ao que mudou de propósito:**
- **A dos Ajustes (R23):** "o escudo nas ações que mudam o sistema" esperava Aplicar ajustes recomendados com o escudo, e "recomendados sem Administrador: nada muda" esperava a falha. Agora esperam os quatro outros com o escudo e os quatro recomendados aplicados sem o ponto. Com isso, os mesmos 412, 422 e 422.
- **A do Explorador e da tela de bloqueio (R50):** a conferência dos perfis esperava os segundos no Trabalho; agora espera o Trabalho sem eles. Os mesmos 101 em cada idioma.

**Contra o código de antes (R51):** das 137 conferências, 100 falham, cada uma de uma correção. As 37 que passam conferem o que foi mantido (os outros pedidos de Administrador, os perfis que não mudaram, os outros ajustes de energia, a política da web na busca, tudo com a própria conta) e os marcadores de texto.

**46 defeitos de propósito,** e as conferências pegam todos: os recomendados pedindo Administrador de novo, tentando o ponto sem ele, sem a frase do ponto e seguindo com outra conta; a regra de outra conta desligada, e esquecida nos perfis, no Essencial, na importação, na exportação, na lista, nas teclas do idioma e no menu de texto; os segundos de volta no Trabalho; o Modern Standby ignorado, o Alto desempenho sem a marca e o byte errado; a descrição antiga da web na busca; a chave sempre na tela de execução, e na linha mesmo com o que ficou como estava, com a hibernação, com o que falta para a cor, com reinício ou com ressalva; o desfecho sem o `Quiet`; Sim e Não de volta no Explorador, no ponto, no Desfazer todos e na revisão, e sem o verbo na lista e no notebook; a chave sem o `-InPlace`, a faixa por cima da linha, a linha sem a leitura nova, sem o foco, sem o resumo refeito, desligada depois e ligada com outra conta; o esqueleto que fica, o resumo fora do lugar, sem os recomendados, contando o que a pessoa mudou e ignorando outra conta; o índice trocado pela lista. O do foco só foi pego depois de a bateria imitar o WPF, que tira o foco de uma chave desligada.

**Nada do que funcionava quebrou:** as baterias das 14 páginas revistas, com os mesmos números da R51 (a dos Ajustes da R23 depois da adaptação acima; a da Rede da R22 com a mesma conferência antiga do escudo); a das seis funções novas da R36 (257 em cada idioma); a do Início da R40 (115), a da Manutenção da R41 (67), a da Limpeza da R42 (97), a do Desempenho da R43 (94), a do Reparo da R44 (92), a do Diagnóstico da R45 (87), a da Rede da R46 (128) e a do Explorador e da tela de bloqueio da R50 (101) em cada idioma, a da Segurança da R47 e a das Atualizações da R48 (83, 84 e 84), e a dos Programas da R51 (75, 87 e 87); a da Manutenção da R14 (243, 245 e 250) e a do Início da R13 (241); as mensagens da janela (72 em cada idioma); instalar, atualizar com um clique, o pacote de suporte e o Setup de verdade, da R51 para esta; nenhuma função sem uso (1.544, nove novas e uma que saiu). O PSScriptAnalyzer ficou com 240 avisos, nenhum novo: saiu o do `Id` de `Get-WinForgeTweakById`, que a análise não via ser usado dentro do filtro antigo.

## O que só um PC mostra

Isto entrou no roteiro de conferência (§42):
- **A chave mudando na linha,** em Ajustes e na Personalização: o Alterando…, o tempo, o foco, o Narrador; e as que abrem a tela (a Inicialização Rápida com a hibernação desligada, o agendamento de GPU, o Explorador).
- **Aplicar ajustes recomendados numa conta sem Administrador,** sem o pedido do Windows, e os quatro no perfil da pessoa.
- **O WinForge elevado com outra conta:** as linhas Outra conta, o resumo em amarelo, o Essencial, Exportar e o menu de texto.
- **Um notebook com Modern Standby** (o `powercfg /a` mostra "Standby (S0 Low Power Idle)"): o Alto desempenho fora da página; num desktop, ele continua.
- **O resumo do alto e o esqueleto** nos três idiomas, e a caixa de busca do Explorador sem as buscas recentes depois de desativar a web na busca.

## Fontes
- [Power Policy Settings (Microsoft Learn)](https://learn.microsoft.com/windows/win32/power/power-policy-settings): os PCs com Modern Standby só permitem o plano Equilibrado ou os derivados dele.
- [SYSTEM_POWER_CAPABILITIES (Microsoft Learn)](https://learn.microsoft.com/windows/win32/api/winnt/ns-winnt-system_power_capabilities): o campo `AoAc`, "the system supports the S0 low power idle model", e a ordem dos campos.
- [Policy CSP - ADMX_WindowsExplorer (Microsoft Learn)](https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-admx-windowsexplorer): `DisableSearchBoxSuggestions`, "Turn off display of recent search entries in the File Explorer search box", do usuário, as versões do Windows.
- [Toggle switches (Microsoft Learn)](https://learn.microsoft.com/en-sg/windows/apps/design/controls/toggles): "Use a toggle switch for binary operations that take effect right after the user flips the toggle switch."
- [Now that computers have more than 4MB of memory, can we get seconds on the taskbar? (Raymond Chen, The Old New Thing)](https://devblogs.microsoft.com/oldnewthing/20220411-00/?p=106456): a atividade periódica que não deixa o processador descansar.
- As da R23 e da R38 continuam valendo: o ponto de restauração, as políticas e os botões das caixas de diálogo.
