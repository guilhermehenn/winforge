# WinForge 4.0 — histórico de revisões

Este arquivo registra cada alteração feita no ciclo da versão 4.0, da mais antiga para a mais nova. Cada alteração ganha uma entrada aqui até o pedido **"TERMINAR VERSÃO 4.0"**. O `CHANGELOG.md` diz o que mudou para quem usa. Aqui fica como cada mudança chegou lá: o pedido, o que mudou, onde mudou, como foi conferida e o que ainda falta ver num PC.

**Situação:** a Build 4.0 está em preparação e ainda não foi publicada. O trabalho fica na branch `b370`, só local: nada vai para o GitHub, e cada entrega vem pelo chat (o zip do WinForge e o código-fonte com o histórico do git). Nada deste ciclo rodou num Windows de verdade. A conferência foi feita na nuvem, com o Windows simulado onde precisava. O roteiro para conferir num PC fica no projeto WinForge do Claude, em `claude/roteiro-conferencia-4.0.md`.

| Revisão | Data | O quê | Commits |
|---|---|---|---|
| [R1](#r1--idiomas-português-inglês-e-espanhol) | 18/11/2026 | Idiomas: português, inglês e espanhol (saiu como Build 3.70) | 75200a0, abcb891, cfe0166, 0435316, 9dedf3b, 170fc15 |
| [R2](#r2--build-40-instalar-atualizar-com-um-clique-e-o-winforge-avisa-antes-do-problema) | 18/11/2026 | Build 4.0: instalar, atualizar com um clique e o WinForge avisa antes do problema | 679ce23, e72d23d |
| [R3](#r3--revisão-de-qa-das-novidades) | 18/11/2026 | Revisão de QA das novidades (sem mudança no código) | — |
| [R4](#r4--correções-da-revisão-de-qa) | 18/11/2026 | Correções da revisão de QA | 60a92cd |
| [R5](#r5--este-histórico-e-a-forma-de-entrega) | 18/11/2026 | Este histórico e a forma de entrega | 5f58b03 |
| [R6](#r6--mapa-de-funcionalidades-e-integração-entre-elas) | 18/11/2026 | Mapa de funcionalidades e integração entre elas | 57cdd2d |
| [R7](#r7--revisão-de-engenharia-do-código) | 18/11/2026 | Revisão de engenharia do código | 25f2496 |
| [R8](#r8--revisão-da-interface-design-produto-e-uxui) | 18/11/2026 | Revisão da interface (design, produto e UX/UI), sem mudança no programa | 8aaee13 |
| [R9](#r9--a-interface-nova-fases-1-e-2-da-revisão) | 18/11/2026 | A interface nova: fases 1 e 2 da revisão | bdcc46d |
| [R10](#r10--o-que-faltou-das-propostas-do-designer) | 18/11/2026 | O que faltou das propostas do designer | 8d72ad4 |
| [R11](#r11--qa-geral-e-as-correções) | 18/11/2026 | QA geral e as correções | 399c56d |
| [R12](#r12--segunda-revisão-de-engenharia-do-código) | 18/11/2026 | Segunda revisão de engenharia do código | c467f90 |
| [R13](#r13--o-início-com-design-windows-e-qa) | 19/11/2026 | O Início com design, Windows e QA | cacc3ba |
| [R14](#r14--a-manutenção-com-design-windows-e-qa) | 19/11/2026 | A Manutenção com design, Windows e QA | b324722 |
| [R15](#r15--o-diagnóstico-com-design-windows-e-qa) | 19/11/2026 | O Diagnóstico com design, Windows e QA | ee6869f |
| [R16](#r16--a-segurança-com-design-windows-e-qa) | 19/11/2026 | A Segurança com design, Windows e QA | 0570b7c |
| [R17](#r17--a-limpeza-com-design-windows-e-qa) | 19/11/2026 | A Limpeza com design, Windows e QA | b722bd6 |
| [R18](#r18--o-desempenho-com-design-windows-e-qa) | 19/11/2026 | O Desempenho com design, Windows e QA | 7510a7b |
| [R19](#r19--o-reparo-com-design-windows-e-qa) | 19/11/2026 | O Reparo com design, Windows e QA | 01febe8 |
| [R20](#r20--as-atualizações-com-design-windows-e-qa) | 19/11/2026 | As Atualizações com design, Windows e QA | d5f7b95 |
| [R21](#r21--os-programas-com-design-windows-e-qa) | 19/11/2026 | Os Programas com design, Windows e QA | 12f1e57 |
| [R22](#r22--a-rede-com-design-windows-e-qa) | 19/11/2026 | A Rede com design, Windows e QA | 48c0bbd |
| [R23](#r23--os-ajustes-do-windows-com-design-windows-e-qa) | 19/11/2026 | Os Ajustes do Windows com design, Windows e QA | 63b6f81 |
| [R24](#r24--a-personalização-com-design-windows-e-qa) | 19/11/2026 | A Personalização com design, Windows e QA | 915c697 |
| [R25](#r25--o-sobre-o-winforge-com-design-windows-e-qa) | 20/11/2026 | O Sobre o WinForge com design, Windows e QA | 7f66851 |
| [R26](#r26--a-busca-com-design-windows-e-qa) | 20/11/2026 | A Busca com design, Windows e QA | c624773 |
| [R27](#r27--o-verificar-o-pc-com-design-windows-e-qa) | 20/11/2026 | O Verificar o PC com design, Windows e QA | e94042f |
| [R28](#r28--o-otimizar-com-design-windows-e-qa) | 20/11/2026 | O Otimizar com design, Windows e QA | 92c60f4 |
| [R29](#r29--revisão-de-todos-os-arquivos) | 20/11/2026 | Revisão de todos os arquivos | 8c355d1 |
| [R30](#r30--documentação-técnica) | 20/11/2026 | Documentação técnica | 04c8365 |
| [R31](#r31--o-readme-nas-práticas-do-github) | 20/11/2026 | O README nas práticas do GitHub | bd4c3d3 |
| [R32](#r32--desinstalar-e-atualizar-programas-só-da-conta) | 20/11/2026 | Desinstalar e atualizar programas só da conta | 94f3aac |
| [R33](#r33--as-mensagens-da-janela-com-o-visual-do-winforge) | 20/11/2026 | As mensagens da janela com o visual do WinForge | c566d30 |
| [R34](#r34--o-ícone-do-winforge-na-barra-de-tarefas) | 20/11/2026 | O ícone do WinForge na barra de tarefas | ec46398 |
| [R35](#r35--avaliação-completa-e-sugestões-de-funções-novas) | 20/11/2026 | Avaliação completa e sugestões de funções novas (só documentação) | d91f6ce |
| [R36](#r36--seis-funções-novas-ativação-integridade-da-memória-winget-programas-na-versão-atual-impressão-e-relógio) | 20/11/2026 | Seis funções novas: ativação, integridade da memória, winget, programas na versão atual, impressão e relógio | be4776b |
| [R37](#r37--o-desenho-novo-do-winforge) | 21/11/2026 | O desenho novo do WinForge: o laranja da bigorna, títulos em negrito e o Início novo | b4f4662 |
| [R38](#r38--revisão-de-uxui) | 21/11/2026 | Revisão de UX/UI, sem mudança no programa | 822b035 |
| [R39](#r39--o-início-e-os-destaques-no-windows-de-verdade) | 21/11/2026 | O Início e os destaques no Windows de verdade | 853abc3 |
| [R40](#r40--segunda-revisão-do-início) | 21/11/2026 | Segunda revisão do Início: produto, código, design, Windows e QA | 9edd58a |
| [R41](#r41--segunda-revisão-da-manutenção) | 21/11/2026 | Segunda revisão da Manutenção: produto, código, design, Windows e QA | 95943aa |
| [R42](#r42--segunda-revisão-da-limpeza) | 21/11/2026 | Segunda revisão da Limpeza: produto, código, design, Windows e QA | 4ee0de9 |
| [R43](#r43--segunda-revisão-do-desempenho) | 21/11/2026 | Segunda revisão do Desempenho: produto, código, design, Windows e QA | a05efdd |
| [R44](#r44--segunda-revisão-do-reparo) | 21/11/2026 | Segunda revisão do Reparo: produto, código, design, Windows e QA | 4689784 |
| [R45](#r45--segunda-revisão-do-diagnóstico) | 21/11/2026 | Segunda revisão do Diagnóstico: produto, código, design, Windows e QA | b69d0f4 |
| [R46](#r46--segunda-revisão-da-rede) | 21/11/2026 | Segunda revisão da Rede: produto, código, design, Windows e QA | aa221d4 |
| [R47](#r47--segunda-revisão-da-segurança) | 21/11/2026 | Segunda revisão da Segurança: produto, código, design, Windows e QA | c1af423 |
| [R48](#r48--segunda-revisão-das-atualizações) | 21/11/2026 | Segunda revisão das Atualizações: produto, código, design, Windows e QA | 6126c1c |
| [R49](#r49--a-aparência-fora-da-revisão-do-otimizar) | 21/11/2026 | A aparência fora da revisão do Otimizar | 0f7b363 |
| [R50](#r50--o-explorador-e-a-tela-de-bloqueio-de-volta-à-revisão-do-otimizar) | 21/11/2026 | O Explorador e a tela de bloqueio de volta à revisão do Otimizar | 72c8bd7 |
| [R51](#r51--segunda-revisão-dos-programas) | 21/11/2026 | Segunda revisão dos Programas: produto, código, design, Windows e QA | eb5a3ce |
| [R52](#r52--segunda-revisão-dos-ajustes-do-windows) | 22/11/2026 | Segunda revisão dos Ajustes do Windows: produto, código, design, Windows e QA | 0cbd196 |
| [R53](#r53--segunda-revisão-da-personalização) | 22/11/2026 | Segunda revisão da Personalização: produto, código, design, Windows e QA | d920d9a |
| [R54](#r54--segunda-revisão-do-sobre-o-winforge) | 22/11/2026 | Segunda revisão do Sobre o WinForge: produto, código, design, Windows e QA | 725dd4f |
| [R55](#r55--segunda-revisão-da-busca) | 22/11/2026 | Segunda revisão da Busca: produto, código, design, Windows e QA | 0958da4 |
| [R56](#r56--segunda-revisão-do-verificar-o-pc) | 22/11/2026 | Segunda revisão do Verificar o PC: produto, código, design, Windows e QA | 3595e35 |
| [R57](#r57--segunda-revisão-do-otimizar) | 22/11/2026 | Segunda revisão do Otimizar: produto, código, design, Windows e QA | be410d8 |
| [R58](#r58--a-documentação-técnica-e-o-readme) | 22/11/2026 | A documentação técnica e o README nos três idiomas | b46d1fc |
| [R59](#r59--o-site-do-winforge-no-readme-e-no-programa) | 22/11/2026 | O site do WinForge no README, em Sobre o WinForge e em Aplicativos instalados | 2ef915f |
| [R60](#r60--a-cor-de-destaque-e-o-que-sobrou-na-inicialização) | 22/11/2026 | A cor de destaque abre as Cores do Windows, e Gerenciar inicialização tira o que sobrou de programas desinstalados | o commit desta entrada |

---

## R1 — Idiomas: português, inglês e espanhol

**Data:** 18/11/2026 · **Saiu como:** Build 3.70 · **Commits:** 75200a0, abcb891, cfe0166, 0435316, 9dedf3b, 170fc15

**Pedido:** item F10 do mapa de melhorias. O WinForge em português, inglês e espanhol, com troca de idioma. No automático, segue o idioma do Windows; num Windows em outro idioma, abre em inglês.

**O que mudou para quem usa**
- **A escolha do idioma:** um cartão **Sobre o WinForge > Idioma**, ao lado de Aparência, com Automático, Português, English e Español. Cada idioma aparece com o próprio nome, para quem não lê o idioma da tela achar o seu.
- **Segue o Windows:** no automático, o idioma de exibição do Windows decide; o português de Portugal recebe o do Brasil, e qualquer outro idioma recebe o inglês.
- **A troca:** com nenhuma ação rodando, o WinForge pergunta se reabre agora, na mesma página. Com uma ação em andamento, nada é interrompido, e a troca fica para a próxima abertura.
- **No terminal:** **Sobre o WinForge > Idioma** no menu guarda a escolha; `-Language pt`, `en` ou `es` vale só para aquela vez.
- **O que muda com o idioma:** a janela, o menu do terminal, o monitor na bandeja e as notificações, os relatórios (HTML e texto) e as mensagens. Também mudam as datas e números no formato do idioma, as listas com "and"/"y", o Sim ou não (Y/n, S/n) e a busca (Ctrl+K), com palavras e sinônimos de cada idioma. As referências "Página > Item" usam os nomes traduzidos.
- **Windows em espanhol:** o WinForge passa a ler as mensagens do DISM, do SFC, do CHKDSK e do winget em espanhol, como já lia em português e em inglês.
- **Arquivos e registros:** o backup antes de formatar mantém os nomes de sempre, para ser lido em qualquer idioma. Os estados guardados usam códigos e aparecem no idioma da tela, e o Histórico de mudanças guarda cada mudança no idioma em que foi feita.
- **README** em inglês e em espanhol. O CHANGELOG continua em português.

**Por dentro**
- **gettext:** o texto em português é a chave. As traduções ficam em `lang/en.po` e `lang/es.po` (4.816 textos nesta revisão), que editores como o Poedit abrem. Um texto sem tradução aparece em português.
- **Core.psm1:**
  - `Get-WinForgeText` e `Get-WinForgeContextText` (o `msgctxt`);
  - `Get-WinForgeLanguage` e `Resolve-WinForgeLanguage`: primeiro WINFORGE_LANG, depois a escolha guardada, depois o idioma do Windows;
  - formatos de data, número, tamanho e lista no idioma;
  - `Convert-WinForgeXamlText`, que traduz o XAML da janela;
  - comparações de texto que valem em qualquer idioma.
- **Todos os módulos:**
  - os textos da interface passam por `Get-WinForgeText`;
  - frases montadas por pedaços viraram frases inteiras, porque a ordem e a concordância mudam de um idioma para outro;
  - os estados gravados guardam códigos.
- **Navigation.psm1:** tabelas da busca por idioma e o item `app.language`.
- **WinForge.Gui.ps1:** o cartão Idioma.
- **Launcher.psm1 e WinForge.Console.ps1:** o idioma no terminal e `-Language`.
- **tools/Update-WinForgeTranslations.ps1:** extrai os textos do código, grava o modelo `tools/WinForge.pot` e junta nos `.po`. Os textos novos entram sem tradução, os removidos ficam como obsoletos, e ele avisa quando os marcadores de um texto diferem do português.

**Falta ver num PC:**
- a janela em inglês e em espanhol em vários tamanhos (textos longos podem cortar);
- a troca pelo cartão e a reabertura na mesma página;
- o menu do terminal, o monitor e as notificações em cada idioma;
- num Windows em espanhol: o DISM e o SFC, a verificação de disco e o winget;
- um Windows em outro idioma (francês, por exemplo), que deve abrir em inglês;
- o relatório HTML em inglês e em espanhol;
- a revisão das traduções por quem fala inglês e espanhol.

---

## R2 — Build 4.0: instalar, atualizar com um clique e o WinForge avisa antes do problema

**Data:** 18/11/2026 · **Commits:** 679ce23 (a build) e e72d23d (o CHANGELOG do zip com as cinco builds mais recentes)

**Pedido:** a proposta "WinForge 4.0" do mapa de melhorias, feita "da melhor forma possível, como um engenheiro de software sênior". Os itens são M1, F1, M2, F6, M18, M10, M14, M12 + M13 e F4.

**O que entrou**
- **F1 — Instalar e desinstalar:**
  - o `WinForge-Setup.cmd` instala em Arquivos de Programas\WinForge, tira a marca de "baixado da internet" e cria o atalho no Menu Iniciar (e na Área de Trabalho, se a pessoa quiser);
  - grava a entrada em Configurações > Aplicativos, de onde se desinstala;
  - com o WinForge já instalado, atualiza a mesma pasta; uma versão mais velha pede confirmação;
  - desinstalar fecha o monitor, tira a manutenção agendada, os atalhos, a entrada e os arquivos, e pergunta à parte se apaga os dados (padrão Não);
  - sem instalar continua valendo: o WinForge.cmd abre da pasta extraída.
- **M1 — Atualizar com um clique:**
  - **Sobre o WinForge > Verificar nova versão** baixa, confere o SHA-256 e pergunta "Instalar agora?";
  - o WinForge fecha, o instalador da versão nova troca os arquivos (com cópia de segurança, conferência por SHA-256 e volta ao que era numa falha) e o WinForge abre de novo na página Sobre, dizendo como terminou;
  - o zip é extraído com conferência de cada nome, e um pacote com versão diferente da página do GitHub é recusado.
- **M2 — Primeira abertura:** o cartão "Deixe o WinForge pronto" no Início, com três passos (atalho, monitor na bandeja e manutenção mensal). Cada passo tem o seu botão, e o cartão some quando os três ficam prontos ou com "Agora não".
- **M14 — Disco com sinais de falha:** o monitor na bandeja avisa e leva a **Diagnóstico > Saúde dos discos**.
- **M12 — Diagnóstico > Telas azuis:** as telas azuis dos últimos 90 dias, com o código, o nome, a causa provável e o que fazer. A faixa aponta o próximo passo da causa mais frequente.
- **M13 — Diagnóstico > Teste de memória:** mostra o último resultado e abre o Diagnóstico de Memória do Windows. O monitor avisa quando o resultado chega.
- **M10 — Segurança > Chave de recuperação do BitLocker:** salva uma cópia num arquivo (pendrives como opção), mostra a chave na tela ou cria uma num disco sem chave.
- **F4 — Rede > Senha do Wi-Fi:** lista as redes salvas, com a conectada primeiro, e mostra a senha da escolhida.
- **Fora do log:** a senha e a chave aparecem na tela, e o log grava "[fora do log]" no lugar.
- **F6 — Sobre o WinForge > Pacote de suporte:** um zip na pasta Downloads com versões, logs, a verificação rápida, o último relatório, os históricos e as preferências. Não leva backups, senhas nem arquivos pessoais.
- **M18 — Tempo de abertura:** cada abertura anota quanto levou em `logs\abertura.log`, para medir num PC.
- **Outras mudanças:**
  - README curto nos três idiomas;
  - o CHANGELOG do zip traz as cinco builds mais recentes;
  - as informações de Wi-Fi leem o Windows em espanhol;
  - "AVISO:" sai no idioma da tela.

**Ficou de fora:** F3 + F8 (o tempo para ligar, antes e depois) só entra com a medição confirmada num PC com a Inicialização Rápida ligada. I1 (licença) e I2 (certificado) são decisões do dono.

**Por dentro**
- **Install.psm1 (novo):**
  - a troca de arquivos (`Install-WinForgeFiles`) e a extração segura (`Expand-WinForgeReleasePackage`);
  - a entrada em Aplicativos (`Register-`, `Update-` e `Unregister-WinForgeInstall`);
  - as cópias abertas de uma pasta (`Get-WinForgeRunningCopies`);
  - a atualização (`Start-WinForgeUpdateInstall`, `Invoke-WinForgeUpdateInstall`) e a desinstalação (`Uninstall-WinForge`).
- **WinForge.Setup.ps1 e WinForge-Setup.cmd (novos):** instalar, desinstalar (rodando de uma cópia temporária) e, com `-Update -Target -WaitProcessId -Reopen`, a troca de arquivos da atualização, sem janela. Esse é o contrato com as versões futuras.
- **Core.psm1:** `Request-WinForgeAppExit`, `Write-WinForgeSecret` e `Add-WinForgeOpenTime`.
- **Os módulos de cada novidade:** Home (o cartão), Agent (as conferências `diskhealth` e `memtest`), Diagnostics (telas azuis, teste de memória e disco), Security (BitLocker), NetworkTools (Wi-Fi), Reports (pacote de suporte) e Navigation (os itens novos).
- **Traduções:** 5.045 textos.

**Conferido na nuvem:**
- o motor de instalação: instalação nova, atualização que mantém os arquivos da pessoa e tira os que saíram, volta ao que era numa falha no meio, zip com caminho para fora da pasta recusado e pasta que não é do WinForge recusada;
- a atualização da 3.70 para a 4.0, simulada de ponta a ponta;
- os segredos fora do log, a leitura dos códigos das telas azuis, o cartão, os textos do resultado da atualização e o conteúdo do pacote de suporte;
- as traduções (5.045/5.045), as 152 referências "Página > Item" iguais nos três idiomas e a busca achando os 102 itens nos três;
- o XAML, o BOM e o CRLF.

**Entregue:** `WinForge.zip` (56 arquivos).

---

## R3 — Revisão de QA das novidades

**Data:** 18/11/2026 · **Commits:** nenhum (só a revisão)

**Pedido:** uma revisão de QA sênior de todas as novidades da 4.0, do funcionamento delas e da integração com as demais opções.

**Resultado:** 18 achados (1 alto, 6 médios e 11 baixos) e 4 sugestões de integração. O relatório completo, com cada cenário, a evidência e o esperado, ficou no projeto WinForge do Claude, em `claude/qa-4.0.md`. Os principais:
- **A1 (alto):** na janela, a senha do Wi-Fi e a chave do BitLocker ficavam escondidas em "Detalhes técnicos", fechado, enquanto a faixa dizia "está no resumo, abaixo".
- **M1 e M2:** pelo menu de texto, a atualização dependia de uma tecla em 2 minutos e falhava sempre se o menu fosse aberto de um Prompt de Comando já aberto.
- **M3:** criar a chave do BitLocker e cancelar onde salvar dava "cancelado pelo usuário".
- **M4:** o Setup não levava o monitor nem a manutenção mensal para a pasta instalada.
- **M5:** se o instalador novo não carregasse, o WinForge fechava e não abria mais.
- **M6:** o CHANGELOG prometia que o monitor via erros e desgaste do disco, o que ele não lê sem Administrador.

---

## R4 — Correções da revisão de QA

**Data:** 18/11/2026 · **Commit:** 60a92cd

**Pedido:** aplicar as correções da revisão e entregar a versão corrigida. Ela continua Build 4.0, porque a 4.0 não foi publicada.

**O que mudou**

| Achado | Como ficou |
|---|---|
| A1 | O segredo sai como "rótulo : valor" (`WriteSecretValue` no host da janela), que o resumo mostra; o log grava o rótulo com "[fora do log]" |
| M1 | Com o pedido de saída, o fim da ação não pede tecla; o menu mostra a frase por 2 s e fecha |
| M2 | Só o cmd aberto com /c para o WinForge-Console.cmd é esperado (`Test-WinForgeMenuBatchHost`), com 2 s de folga antes da troca |
| M3 | A chave criada sem cópia termina em aviso, com o botão Guardar a chave |
| M4 | O Setup leva a entrada do monitor (`Move-WinForgeAgentEntry`, a marca de desativado fica) e a tarefa mensal (`Register-WinForgeScheduledMaintenance -Root`, no mesmo dia) para a pasta instalada; o cartão confere o script da tarefa (`Get-WinForgeScheduledMaintenanceScript`) |
| M5 | Sem os módulos, o Setup espera o WinForge fechar, grava o motivo na língua da pessoa e reabre a cópia de antes (`Invoke-WinForgeSetupUpdateFallback`) |
| M6 | O CHANGELOG diz o que o monitor vê; erros e desgaste aparecem no Verificar o PC e na Saúde dos discos |
| B1–B3 | Wi-Fi: a senha guardada decide o tipo (WEP mostra a senha, OWE é aberta); uma senha cifrada não aparece como senha; um PC sem adaptador recebe "Este PC não tem adaptador de Wi-Fi", sem erro |
| B4–B5 | BitLocker: a tela explica o "esperando ativação"; a pasta digitada precisa do caminho completo (até 3 tentativas) |
| B6 | Outra janela aberta é avisada antes de fechar |
| B7 | Desinstalar dá uma segunda tentativa a cada arquivo, apaga por último o que o desinstalador precisa e mantém a entrada em Aplicativos enquanto sobrar arquivo; "1 arquivo não pôde ser apagado" sai no singular |
| B8 | Desinstalar alcança o monitor e os atalhos de quem usa o PC quando o WinForge foi elevado por outra conta; o monitor avisa um teste de memória novo com erros mesmo sem o pedido na própria conta |
| B9 | Sem mudança: não dá para saber a escolha feita na janela do Windows sem algo que só um PC confirma. A frase da tela já ressalva, e o pedido sai sozinho em 14 dias |
| B10 | Com um teste de memória de até 30 dias sem erros, a pergunta de abrir de novo vem com Não |
| B11 | Cada tela azul conta uma vez, pareando o registro do reinício com o do Windows; os códigos 0x1000xxxx usam o nome e a causa dos 0x0000xxxx |
| Integração | A auditoria lembra de guardar a chave; o relatório ganha "Telas azuis e memória"; o Verificar o PC mostra o disco com sinais de falha; o `SHA256SUMS.txt` passa a ser arquivo do WinForge; o CHANGELOG e o README explicam a passagem da 3.70 |

**Conferido na nuvem:** 66 conferências novas, uma para cada correção, todas passando. As de antes também continuam passando: o motor de instalação, a atualização simulada, as traduções (5.075/5.075), as 156 referências "Página > Item" iguais nos três idiomas, a busca nos três idiomas, o XAML, o BOM e o CRLF.

**Falta ver num PC:** os casos novos entraram no roteiro de conferência. São eles:
- o menu de texto aberto de um Prompt de Comando, na atualização;
- instalar por cima de uma pasta extraída com o monitor e a manutenção ligados;
- desinstalar com um arquivo preso;
- a senha num desktop sem Wi-Fi;
- a senha e a chave no resumo da janela.

**Entregue:** `WinForge.zip` (56 arquivos) e `WinForge-codigo-fonte.zip` (o repositório com o histórico do git).

---

## R5 — Este histórico e a forma de entrega

**Data:** 18/11/2026 · **Commit:** 5f58b03

**Pedido:** nada vai para o GitHub, e tudo é entregue no chat para salvar localmente. A partir daqui, até o pedido "TERMINAR VERSÃO 4.0", cada alteração fica documentada num `.md`, com as revisões já feitas desde a opção de idioma.

**O que mudou**
- **docs/historico-4.0.md (novo):** este arquivo. Ele fica no código-fonte e não entra no `WinForge.zip`, que leva só os arquivos do programa.
- **Entrega:** a cada alteração, o `.md` atualizado e o código-fonte vêm pelo chat, e o `WinForge.zip` vem quando o programa muda.

---

## R6 — Mapa de funcionalidades e integração entre elas

**Data:** 18/11/2026 · **Commit:** 57cdd2d

**Pedido:** primeiro, mapear todas as funcionalidades do WinForge com a visão de um Analista de Produto Sênior. Depois, com a de um Engenheiro de Software Sênior, integrar essas funcionalidades ao sistema de forma robusta e sem quebrar o resto.

**O mapa:** está em `docs/funcionalidades-4.0.md`. São 11 páginas, 102 itens (84 do WinForge e 18 atalhos para o Windows) e 53 ajustes. O mapa também mostra os sistemas que ligam tudo (Início, busca, Verificar o PC, monitor, histórico, relatório, verificação rápida, pacote de suporte, próximo passo) e por onde cada sinal de saúde passa. No fim, lista as lacunas de integração, com o que foi feito e o que ficou para depois.

**O que mudou**
- **Telas azuis:** o monitor avisa uma tela azul nova, com a causa provável. O Verificar o PC ganhou a etapa das telas azuis dos últimos 30 dias, os Eventos críticos ganharam o botão para as Telas azuis, e a verificação rápida (`-Action Check -Json` e o pacote de suporte) passou a trazer `Stability`.
- **Backup antes de formatar:** avisa os discos além do Windows que têm BitLocker, porque no Windows novo eles só abrem com a chave de recuperação.
- **Histórico de mudanças:** passa a anotar a cor de destaque, as teclas que trocam o idioma do teclado, o reparo de rede, a manutenção agendada (criada ou removida), o CHKDSK que corrigiu ou agendou o reparo e o que voltou de um backup.
- **Instalação e atalho:**
  - o atalho do instalador (para todos os usuários) passa a contar como atalho desta pasta no Sobre o WinForge;
  - o Criar atalho do WinForge não repete o atalho do instalador e tira o repetido desta conta;
  - o Setup não deixa o atalho desta conta repetido;
  - o Sobre ganhou a linha "Instalação" (instalado ou sem instalar, e como desinstalar ou instalar).
- **Busca:** "bsod" e "reinicia sozinho" levam às Telas azuis, "probar ram" (espanhol) acha o Teste de memória e "desinstalar winforge" acha Versão e pastas.

**Ficou para depois, com o motivo no mapa:**
- a saúde do disco e as telas azuis no Início (pelo tempo de abertura);
- a saúde do disco na verificação rápida;
- o botão de próximo passo em Dispositivos com problema e em Discos e espaço livre;
- o desfazer da cor de destaque e das teclas;
- o backup dos arquivos pessoais.

**Por dentro**
- **Agent.psm1:** a conferência `bluescreen`, de hora em hora, com a marca `BlueScreenSeenAt` nas preferências.
- **Checkup.psm1:** a etapa `bluescreens` (`Get-WinForgeCheckupBlueScreens`).
- **Diagnostics.psm1:** o próximo passo nos Eventos críticos.
- **Reports.psm1:** `Stability` em `Get-WinForgeCheckReport`.
- **Backup.psm1:** `Get-WinForgeBackupBitLockerDrives`.
- **Install.psm1:** `Test-WinForgeInstallerShortcut` e `Get-WinForgeInstallStateText`.
- **Launcher.psm1:** `Common` em `Get-WinForgeShortcutState`, `Test-WinForgeShortcutIsWinForge`, a linha Instalação e o Criar atalho sem repetir.
- **WinForge.Setup.ps1:** o atalho desta conta sai onde o instalador já pôs o dele.
- **`Add-WinForgeChange`** em Tweaks, Network, Schedule, Repair e Backup.
- **Navigation.psm1:** palavras da busca.
- **Traduções:** 5.092 textos.

**Conferido na nuvem:**
- 28 conferências novas, todas passando: o aviso do monitor (marca, aviso único, ação liberada), a etapa do Verificar o PC, o botão dos Eventos críticos, o JSON, o aviso do BitLocker, o histórico da cor e das teclas, o atalho do instalador no estado, a escolha e o repetido, e a linha Instalação.
- As de antes continuam passando: as 66 das correções da QA, o motor de instalação, a atualização simulada, o pacote de suporte, as traduções (5.092/5.092), as 159 referências "Página > Item" iguais nos três idiomas, a busca achando os 102 itens nos três idiomas, o XAML, o BOM e o CRLF.

**Falta ver num PC:**
- o aviso de tela azul do monitor;
- a etapa nova do Verificar o PC;
- o atalho do instalador na página Sobre e no Criar atalho;
- o aviso do BitLocker no backup antes de formatar;
- as novas linhas do Histórico de mudanças.

**Entregue:** `WinForge.zip`, `WinForge-codigo-fonte.zip`, `historico-4.0.md` e `funcionalidades-4.0.md`.

---

## R7 — Revisão de engenharia do código

**Data:** 18/11/2026 · **Commit:** 25f2496

**Pedido:** revisar todo o código com a visão de um Engenheiro de Software Sênior. Tirar o que está claramente obsoleto ou mal otimizado, sem quebrar nada. Adotar boas práticas nas telas, nos botões, nas funções e nas execuções. Garantir que o WinForge seja robusto, seguro e confiável, e que não deixe o PC de quem usa parado ou estragado.

**Como foi revisado:** são cerca de 58 mil linhas (38 módulos, os 4 scripts de entrada e as ferramentas).
- O PSScriptAnalyzer, a análise estática padrão do PowerShell, rodou em todos os arquivos.
- Três varreduras foram feitas para esta revisão, sobre as 1.390 funções:
  - funções que ninguém chama;
  - funções com o mesmo nome em dois módulos;
  - cada chamada conferida contra os parâmetros da função chamada.
- Houve leitura dirigida do que mexe no PC: programas externos, serviços, Explorador, reinício, exclusões, registro, downloads, relatório HTML, monitor na bandeja e a janela fechada no meio de uma ação.

**O que foi achado e corrigido**

| Achado | Gravidade | Como ficou |
|---|---|---|
| **Atualizar com um clique não terminava.** A troca de arquivos (Install.psm1) e a instalação do Windows Update (WindowsUpdate.psm1) tinham o mesmo nome, `Invoke-WinForgeUpdateInstall`. Com todos os módulos carregados, como no Setup, vale o do último módulo carregado, o do Windows Update. O `WinForge.Setup.ps1 -Update` parava com "o parâmetro Source não existe": nenhum arquivo era trocado, e o WinForge, que tinha fechado para a atualização, não abria de novo. A conferência da atualização carregava só parte dos módulos e não pegava isso. | Grave | A troca passou a se chamar `Install-WinForgeUpdatePackage`. O Setup de verdade, num processo à parte, falhava antes da correção (saída 1, sem resultado) e funciona depois (saída 0, arquivos trocados, resultado Ok). |
| **Setup sem volta num erro inesperado.** Um erro antes de a troca começar terminava o Setup sem reabrir o WinForge. | Média | O Setup segue o mesmo caminho de quando os módulos não carregam (`Invoke-WinForgeSetupUpdateFallback -Cause Error`): grava o motivo na língua da pessoa e reabre a cópia de sempre, na mesma versão. |
| **Ajuste que falha no meio.** Quando aplicar um ajuste dava erro e nem desfazer a tentativa funcionava, o backup do valor de antes era apagado mesmo assim. Parte do ajuste podia ficar no PC sem ter como voltar pelo WinForge. | Média | O backup só sai quando o desfazer funcionou. Se não funcionou, ele fica, e a tela avisa que parte do ajuste pode ter ficado aplicada. |
| **Pasta de dados relativa.** Sem a variável LOCALAPPDATA (alguns acessos remotos abrem o PowerShell sem ela), a pasta de dados virava "WinForge" no diretório atual. Na desinstalação, "apagar também os dados" apagaria a pasta "WinForge" de onde o Setup estivesse aberto. | Baixa, mas apagaria o que não é do WinForge | `Get-WinForgeLocalAppDataPath`: vale a variável, depois a pasta que o Windows informa para a conta. Sem nenhuma das duas, dá erro em vez de usar um caminho relativo. A pergunta da desinstalação mostra a mesma pasta que ela apaga. |
| **Monitor que podia travar.** Ao abandonar uma leitura em segundo plano que passou de 5 minutos, o monitor esperava por ela. Uma consulta do Windows presa travaria o ícone na bandeja. | Baixa | A leitura é deixada de lado sem esperar e descartada depois de parar (`Clear-AgentAbandonedWorkers`), como a janela já fazia com as dela. |

**O que saiu, sem uso**
- `Get-WinForgeIconNames` (GuiDesign.psm1), `Test-WinForgeStaticIpConfigured` (Network.psm1) e `Test-WinForgeTextMatch` (Core.psm1). Nenhuma chamada em lugar nenhum, nem por nome montado em texto.
- `$event`, uma variável automática do PowerShell, deixou de servir de nome comum no teste de memória.
- Três `catch { }` vazios passaram a registrar o motivo (`Write-Verbose`): os dois do desfazer do ajuste e o da ação adiada da janela.

**Conferido e mantido como está**
- **Programas externos:** o Parar e o fechar da janela encerram também os programas que a ação abriu (o DismHost do DISM, o instalador que o winget abriu). O CHKDSK roda em `/scan`, que não pergunta nada. As ações do winget levam `--disable-interactivity`.
- **O PC volta ao que era:** os serviços do Windows Update voltam a ligar num `finally`. O apagar espaço livre tira a pasta de preenchimento mesmo quando é parado. O "não suspender" sai num `finally`.
- **Fechar a janela no meio de uma ação:** o WinForge pergunta antes. O fechamento espera a ação terminar de parar, de propósito, para esses `finally` rodarem antes de o processo sair. Isso ficou comentado no código, para ninguém trocar por um fechamento sem espera.
- **Explorador e reinício:** o Explorador só é aberto à mão se o Windows não o reabrir. O reinício sempre pergunta, com Não como padrão, e o `shutdown /r /t 0` deixa o Windows perguntar pelos arquivos sem salvar.
- **Exclusões:** as pastas apagadas inteiras são do próprio WinForge ou temporárias criadas por ele. A limpeza não segue atalhos de pasta (junções) e protege as pastas do perfil. A limpeza do registro só remove com backup.
- **Rede e relatório:** os downloads usam TLS 1.2, tempo-limite e SHA-256. O relatório HTML escapa todo o texto. Não há `Invoke-Expression` no WinForge.
- **Manutenção agendada:** limite de 1 hora, não começa na bateria e não acorda o PC.
- **Avisos do PSScriptAnalyzer que ficam:**
  - os 68 de parâmetro sem uso são assinaturas iguais de propósito (funções chamadas pelo mesmo contrato) ou usos dentro de blocos que a análise não enxerga;
  - os 72 `catch` vazios que restam têm o motivo escrito ao lado;
  - os 54 de variável automática são o `$sender` e o `$eventArgs` dos eventos da janela;
  - as 2 variáveis globais são a ponte entre a janela e as ações.

**Por dentro**
- **Install.psm1:** `Install-WinForgeUpdatePackage` (era `Invoke-WinForgeUpdateInstall`). A desinstalação usa `Get-WinForgeLocalAppDataPath`.
- **WinForge.Setup.ps1:** o nome novo, `Invoke-WinForgeSetupUpdateFallback -Cause Load|Error` e a pasta de dados da pergunta.
- **Core.psm1:** `Get-WinForgeLocalAppDataPath`, que `Get-WinForgeDataPath` passa a usar.
- **Tweaks.psm1:** `Invoke-WinForgeTweakApply` só tira o backup quando o desfazer da tentativa funcionou.
- **WinForge.Agent.ps1:** `Stop-AgentHeavyChecks` sem esperar e `Clear-AgentAbandonedWorkers` a cada volta do relógio.
- **Diagnostics.psm1, Network.psm1, GuiDesign.psm1, GuiHost.psm1 e WinForge.Gui.ps1:** o restante descrito acima.
- **Traduções:** 2 textos novos, 5.094 ao todo.

**Conferido na nuvem:**
- **26 conferências novas, todas passando:**
  - nenhum nome repetido entre os módulos;
  - as funções sem uso fora;
  - a pasta de dados sem a variável e com ela relativa;
  - o ajuste que falha, com e sem o desfazer funcionando;
  - o teste de memória com e sem erros;
  - o monitor parando uma leitura em 7 ms e descartando-a depois.
- **O Setup de verdade, num processo à parte:**
  - antes da correção, saída 1 e nenhum resultado;
  - depois, saída 0, arquivos trocados, resultado Ok e as notas da pessoa intactas;
  - com um erro antes da troca, o resultado traz o motivo em cada idioma.
- **As de antes continuam passando:**
  - as 66 das correções da QA e as 28 da integração;
  - o motor de instalação e a atualização simulada, agora com todos os módulos carregados, como no Setup, para um nome repetido aparecer;
  - o pacote de suporte e as traduções (5.094/5.094);
  - as 159 referências "Página > Item", iguais nos três idiomas, e a busca, que acha os 102 itens nos três idiomas;
  - o XAML, o BOM e o CRLF;
  - nenhuma chamada com um parâmetro que não existe.

**Falta ver num PC:**
- atualizar com um clique (já estava no roteiro; esta revisão é o que faz a troca funcionar);
- o aviso do ajuste que não pôde ser desfeito, difícil de provocar de propósito, fica só para quando acontecer.

**Entregue:** `WinForge.zip`, `WinForge-codigo-fonte.zip` e `historico-4.0.md`.

---

## R8 — Revisão da interface (design, produto e UX/UI)

**Data:** 18/11/2026 · **Commit:** 8aaee13 (só documentação; o programa não mudou)

**Pedido:** reunir quatro pessoas (um Gerente de Marketing Sênior, um Designer Sênior e um Analista de UX/UI Sênior; o quarto olhar ficou com um Gerente de Produto Sênior) e fazer uma revisão geral da interface. A comparação é com o melhor e mais bonito que existe hoje em design, produto e UX/UI.

**O resultado:** está em `docs/revisao-interface-4.0.md`, com cinco maquetes em `docs/revisao-interface/`. A revisão traz:
- um placar de 9 critérios;
- 30 achados, cada um com a sua proposta (ou com o motivo de manter): 6 de marketing, 6 de produto, 9 de design e 9 de UX/UI;
- o que não mudar;
- um plano em três fases.

**Os principais achados**
- **Nota alta:** confiança e honestidade (5), caminho principal e acessibilidade (4).
- **Nota baixa:** quantidade de texto, aparência nativa no Windows 11 e movimento (2).
- **Marca:** o azul dos botões é o da Apple (`#0071E3`), não o da bigorna do ícone (`#5B91FF`). A proposta é um azul derivado da bigorna, com o contraste conferido.
- **Texto:** 84 das 99 descrições visíveis passam de 60 caracteres, e o aviso de Administrador aparece escrito em até 37 cartões.
- **Sistema visual:** 13 tamanhos de fonte (a primeira versão desta entrada dizia 16; corrigido na R9), 8 raios de canto e 6 estilos de botão. A proposta usa a escala do Windows 11, cantos 4 e 8 e três estilos de botão.
- **Acessibilidade:** o contraste alto e o tamanho do texto do Windows não são seguidos.
- **Produto:** a barra lateral sem grupos, cinco blocos no Início, oito botões no alto de Ajustes do Windows e verbos demais para "cuidar do PC".

**Plano proposto**
- **Fase 1, rápida e de baixo risco:** a fonte e a escala, o escudo no lugar do aviso escrito, "Versão 4.0", os grupos na barra lateral, o "Mais opções" em Ajustes, o contraste alto, o tamanho do texto e o movimento sutil.
- **Fase 2, o visual novo:** as cores do Windows 11 com o azul da marca, as páginas em lista agrupada com descrições de uma linha e o Início novo.
- **Fase 3, estudo antes de decidir:** a Mica e a arquitetura de páginas, esta depois de um teste de árvore com pessoas.

**Como foi feita:** pela leitura do código da janela e pela navegação medida no próprio código. Também entraram as prévias das builds anteriores e as referências do Windows 11 e do Microsoft PC Manager, com as fontes citadas no documento. As maquetes foram feitas em HTML: a de "hoje" foi refeita a partir das cores e medidas do código, e as propostas usam os nomes reais da página Limpeza.

**O que não foi visto:** nada rodou num Windows de verdade. As maquetes usam a fonte Inter no lugar da Segoe UI.

**Entregue:** `revisao-interface-4.0.md`, as cinco maquetes, `historico-4.0.md` e `WinForge-codigo-fonte.zip`. O `WinForge.zip` não muda, porque o programa não mudou.

---

## R9 — A interface nova: fases 1 e 2 da revisão

**Data:** 18/11/2026 · **Commit:** bdcc46d

**Pedido:** "Pode codar como um engenheiro sênior todas as mudanças sugeridas". Entraram as fases 1 e 2 do plano da R8 (itens 1 a 11), na própria 4.0, que ainda não foi publicada. Os itens 12 a 14 ficaram de fora, pelos motivos do fim desta entrada.

**O que mudou, item por item**

| # | Item da R8 | Como ficou |
|---|---|---|
| 1 | Fonte e escala | A Segoe UI Variable no Windows 11, só quando o WPF tem o seminegrito de verdade; senão, a Segoe UI. Seis tamanhos (12, 14, 18, 20, 28 e 40), em recursos do XAML (`CaptionSize`, `BodySize`...) e em `$script:Type`. Nenhum tamanho escrito sobrou no XAML nem nos textos montados pelo script. |
| 2 | O escudo | "Pede Administrador ao executar" saiu dos cartões, das chaves de ajuste e dos botões: fica o escudo. A frase continua na dica e no nome que o leitor de tela ouve. |
| 3 | "Versão 4.0" | Na barra lateral, em Sobre o WinForge, no instalador, na atualização com um clique, no relatório e no título do menu de texto. As frases passaram a dizer "a versão {0}" com o número, e as traduções acompanham. O cabeçalho do log, técnico, continua com "Build". |
| 4 | Grupos na barra lateral | Cuidar, Consertar, Proteger e Configurar (`Get-WinForgeNavGroups`). Só a ordem da barra mudou; nomes, itens, referências "Página > Item", busca e menu de texto ficam iguais. Ctrl+1 a Ctrl+0 seguem a barra. |
| 5 | Ajustes do Windows | No alto: Aplicar ajustes recomendados, Mais opções (menu com as outras cinco ações, que abre com o teclado e devolve o foco ao botão) e Atualizar estado. As teclas do idioma e as notificações viraram linhas no grupo Notificações e teclado; em Personalização, a cor de destaque e a tela de bloqueio, nos grupos delas (`ListCategory`). |
| 6 | Contraste alto e tamanho do texto | Com um tema de contraste do Windows, a janela usa as cores do sistema (`Get-WinForgeHighContrastPalette`), e a barra de título volta às do Windows. O tamanho do texto do Windows (de 100% a 225%) multiplica a escala; os cartões do Início crescem junto. As duas coisas são relidas quando a janela volta a ficar ativa. |
| 7 | Movimento | A página entra aparecendo e subindo 8 pixels em 170 ms; a faixa de resultado, 6 pixels em 200 ms. Com os efeitos de animação do Windows desligados (`ClientAreaAnimation`), nada se move. Refazer a página no lugar (troca de tema) não anima. |
| 8 | Cores, cantos e botões | As cinzas do Windows 11 e o azul da bigorna (`#2B63D9` no claro, `#5B91FF` no escuro), com o texto conferido acima de 4,5:1 nos fundos de texto. Cantos 4 e 8 (os botões padrão, principal e de perigo ficaram com 8 por engano; corrigido na R10). Os botões ficam em três estilos (destaque, padrão e sutil); o de perigo continua definido, sem uso (passou a ser usado na R10). |
| 9 | Páginas em lista | O caminho recomendado em destaque no alto (`New-GuiHeroCard`) e o resto em listas agrupadas (`New-GuiActionRow`, `New-GuiRowGroup`), também nos resultados da busca. 87 descrições encurtadas para até 60 letras nos três idiomas; a frase inteira foi para `Detail` (dica, leitor de tela e busca). |
| 10 | Início novo | A nota de saúde primeiro; a faixa "Deixe o WinForge pronto" em uma linha, logo abaixo; "Seu PC"; e "Com o WinForge neste PC", que só aparece com algo anotado. "Por onde começar" saiu. Enquanto lê, cada cartão mostra uma barra cinza no lugar do valor. |
| 11 | Os dois caminhos | A nota traz Otimizar e Verificar o PC. Verificar vírus fica na Segurança, aonde o cartão Proteção leva. |

**O que precisou de decisão no caminho**
- **"Liberado nas manutenções" sem exagero.** A variação do espaço livre mistura o que as atualizações ocupam, e o próprio Histórico de manutenções a chama de "variação", não de "liberado". Por isso a entrada do histórico passou a guardar o que as etapas disseram ter liberado (`Freed`, a soma de `FreedBytes`; cada etapa devolve um resultado só, então nada conta duas vezes). O número vale a partir desta versão: as manutenções gravadas antes não têm essa medida, e o bloco do Início não mostra o espaço até haver uma. O Histórico de manutenções ganhou a mesma linha.
- **Mudanças anotadas:** o bloco mostra quantas mudanças o WinForge anotou e, delas, quantas ainda têm desfazer, sem um número zero na tela.
- **A barra lateral muda de ordem.** O plano dizia "sem mover páginas": nenhuma página mudou de nome, de itens ou de lugar no menu de texto e na busca. Na barra, porém, os grupos pedem as páginas juntas, e os atalhos Ctrl+número acompanham.
- **Datas:** a R8 tinha ficado com 19/11, o dia em UTC; no fuso do dono ainda era 18/11. A R8 e a revisão da interface foram corrigidas.
- **Correção da R8:** eram 13 tamanhos de fonte, e não 16 (18, 20 e 26 eram tamanhos de ícone). Corrigido aqui, na R8 e em `docs/revisao-interface-4.0.md`.

**Por dentro**
- **GuiDesign.psm1:** as paletas novas (as mesmas chaves de antes), as de contraste alto, a escala (`Get-WinForgeTypeRamp`, `Get-WinForgeTextScale`) e a ordem da barra (`Get-WinForgeNavGroups`, `Get-WinForgeNavOrder`).
- **MainWindow.xaml:** os recursos de fonte e tamanho, os estilos `RowButton`, `MenuItemButton`, `FocusRingSwitch` e `FocusRingInset`, os cantos novos e a busca com a linha embaixo, como nos campos do Windows 11. Saiu o `WideCardWidth`.
- **WinForge.Gui.ps1:** `Set-GuiTypography`, `Get-GuiThemeState` e o tema `Contrast`; as linhas, os grupos, o destaque, o menu Mais opções, o resumo do Início e `Start-GuiEntrance`. Saíram `New-GuiActionCard`, `New-GuiQuickActionCard` e `New-GuiNote`, sem uso.
- **Navigation.psm1:** `Detail` e `ListCategory`; a busca indexa também o `Detail`.
- **Home.psm1:** `Get-WinForgeHomeValueSummary`; saiu `Get-WinForgeHomeActions`. **Core.psm1:** `Freed` no histórico de manutenções. **Maintenance.psm1:** a linha Liberado nas manutenções.
- **Console, Launcher, Setup, Install, Reports e AppUpdate:** "versão" no lugar de "Build" nas frases.
- **Traduções:** 130 textos novos ou mudados, 5.187 ao todo.

**Conferido na nuvem**
- **59 conferências novas, todas passando** (58 em inglês e em espanhol, onde a das 60 letras não se aplica):
  - a escala nos tamanhos de 100%, 125%, 150% e fora da faixa, e o fator lido do registro;
  - nenhum tamanho escrito no XAML nem nos textos do script, e todo recurso usado definido;
  - as paletas com as mesmas chaves, a de contraste alto com as cores do sistema;
  - os grupos da barra: cada página uma vez, um título por grupo, página nova no fim;
  - nenhuma descrição acima de 60 letras, as 87 frases inteiras guardadas e achadas pela busca, e cada `ListCategory` numa categoria da página;
  - o resumo do Início sem histórico, com uma manutenção, com a mesma execução gravada de novo, com o histórico cheio, com mudanças com e sem desfazer, e com um histórico de antes da 4.0;
  - o código sem as funções que saíram, e nenhum "Build {0}" do WinForge na tela.
- **As de antes continuam passando:** as 66 das correções da QA, as 28 da integração e as 26 da R7; o motor de instalação e a atualização simulada; o pacote de suporte; as traduções (5.187/5.187); as 159 referências "Página > Item" nos três idiomas e a busca, que acha os 102 itens nos três idiomas; o XAML, o BOM e o CRLF; nenhuma chamada com um parâmetro que não existe, nenhuma função sem uso.

**O que não foi feito, e por quê**
- **12, capturas de tela para vender:** pedem o Windows de verdade, com a janela nova aberta; daqui não dá para tirar.
- **13, Mica:** troca a moldura da janela (`WindowChrome`) no PowerShell 5.1, com risco alto e sem como conferir daqui. Fica para um estudo num PC.
- **14, arquitetura de páginas:** juntar ou renomear páginas pede um teste de árvore com pessoas antes; mexe na busca, nas 159 referências, no menu de texto e nas traduções.

**Falta ver num PC** (entrou no roteiro): a fonte no Windows 11 e no 10; os dois temas e um tema de contraste; o tamanho do texto em 150% e 225%; o menu Mais opções com o mouse e com o teclado; as linhas, o destaque e o escudo nos três idiomas; a faixa "Deixe o WinForge pronto"; o bloco "Com o WinForge neste PC" depois de um Otimizar; o movimento, e as animações desligadas.

**Entregue:** `WinForge.zip`, `WinForge-codigo-fonte.zip` e `historico-4.0.md`.

---

## R10 — O que faltou das propostas do designer

**Data:** 18/11/2026 · **Commit:** 8d72ad4

**Pedido:** "Ficou faltando algo nas melhorias sugeridas inicialmente pelo designer sênior?". A conferência das propostas DS1 a DS9 e da maquete da Limpeza achou sete pontos, e a resposta foi "Pode fazer": todos, menos a Mica.

**O que mudou**

| Proposta | O que faltava | Como ficou |
|---|---|---|
| DS7, movimento | Os botões e a chave mudavam de estado na hora | Sob o mouse, o fundo dos botões, das linhas das listas, dos itens da barra lateral e do menu Mais opções entra e sai em 83 ms; a bolinha da chave cresce 2 px e o trilho clareia. Pressionar continua instantâneo, como no Windows. Com os efeitos de animação do Windows desligados, a duração vira zero antes de a janela ser montada (`Convert-WinForgeXamlMotion`). |
| DS6, o destaque | O cartão inteiro era clicável, com "Recomendado" | O destaque tem o botão principal da página com o verbo do que ele faz: Otimizar agora, Ver detalhes, Ver a proteção, Limpar agora, Acelerar, Reparar, Procurar atualizações, Escolher programas, Testar agora e Criar atalho (`ButtonText`), com o escudo quando pede Administrador. |
| DS2, contornos | Cinza sólido | O contorno dos cartões e os traços entre as linhas são translúcidos (preto a 10% no claro, branco a 7% no escuro): sobre o cartão, o mesmo cinza de antes. A borda da barra de título usa a cor já misturada (`ConvertTo-WinForgeOpaqueColor`). |
| DS2, detalhes técnicos | As cores do macOS (verde `#32D74B`, laranja `#FF9F0A`, cinzas `#8E8E93`...) | As do Windows 11 e as de estado do WinForge, todas acima de 4,5:1 sobre o fundo dos detalhes, o cartão e o cartão sob o mouse, nos dois temas. As cores iniciais do XAML passaram a ser as do tema claro. |
| DS1, entrelinha | A natural da fonte | A de cada tamanho da escala (12/16, 14/20, 18/24, 20/28, 28/36 e 40/52), nos textos montados pelo script e no subtítulo da página e na faixa de resultado, também multiplicada pelo tamanho do texto do Windows. |
| DS3, cantos | O seletor de Aparência e de Idioma com canto 6 | Canto 4 no trilho e 2 nas opções dentro dele (4 menos a folga de 2, para as curvas acompanharem). |
| DS4, perigo | O estilo existia, sem uso | O Sim de esvaziar a Lixeira, de excluir em definitivo da pasta Downloads, de apagar o espaço livre e da limpeza personalizada com a Lixeira ou os despejos vem no botão de perigo (contorno e texto vermelhos). As opções "Temporários e Lixeira" e "Excluir permanentemente" vêm com o título em vermelho. Todas continuam com Não como padrão. |
| Maquete do Início | Botões embaixo da frase, Otimizar primeiro | Verificar o PC e Otimizar ao lado da frase, nessa ordem; numa janela estreita, ou com o texto do Windows grande, eles descem para baixo da frase (`Set-GuiHealthLayout`). |

**Correção da R9:** os botões padrão, principal e de perigo tinham ficado com canto 8, e não 4, embora o comentário do XAML e a R9 dissessem 4. Agora são 4.

**O que precisou de decisão**
- **Só a opacidade é animada.** As transições trocam a opacidade de camadas por cima do fundo (`Hover` e `Press`). Animar a cor do pincel, que vem dos recursos do tema, pode dar erro no WPF quando o pincel está congelado; a opacidade não tem esse risco. As 22 transições têm os nomes conferidos em cada modelo.
- **A chave não anima o liga/desliga.** Na janela, a chave nunca muda no lugar: ela volta na hora ao estado real, e a lista é relida depois da ação. Uma bolinha deslizando só apareceria ao abrir a página, como se o ajuste mudasse sozinho. A transição ficou no mouse.
- **As animações seguem a opção do Windows de quando a janela abre.** A entrada das páginas lê a opção a cada página; a dos botões, ao abrir o WinForge. Trocar a opção com a janela aberta vale para os botões na próxima abertura.
- **O título da página (28/36)** fica como estava: a entrelinha natural da fonte nesse tamanho já passa de 36.

**Por dentro**
- **GuiDesign.psm1:** Line e SidebarLine translúcidos; a paleta dos detalhes técnicos; `Get-WinForgeLineRamp`, `Convert-WinForgeXamlMotion` e `ConvertTo-WinForgeOpaqueColor`.
- **MainWindow.xaml:** as camadas e transições em `NavButton`, `CardButton`, `PillButton`, `PrimaryButton`, `DangerButton`, `GhostButton`, `RowButton`, `MenuItemButton` e `SwitchToggle`; o canto 4 dos botões; o contorno vermelho do perigo; os recursos `BodyLineHeight` e `SubtitleLineHeight`.
- **WinForge.Gui.ps1:** a duração das transições antes de montar a janela, `$script:LineBySize`, `New-GuiHeroCard` com o botão, `Set-GuiHealthLayout`, o seletor com canto 4 e o perigo nas perguntas.
- **Navigation.psm1:** `ButtonText` nos dez destaques. **Console.psm1:** `Danger` nas opções e `-Danger` em `Confirm-WinForgeAction`. **GuiHost.psm1:** `Danger` no `GuiOption` e no plano da pergunta. **Cleanup.psm1 e CleanupTools.psm1:** as seis perguntas que apagam sem volta.
- **Traduções:** 9 textos novos, 5.196 ao todo.

**Conferido na nuvem**
- **52 conferências novas, todas passando nos três idiomas:**
  - os contornos translúcidos dando o mesmo cinza de antes, a cor sólida da barra de título e a cor inválida;
  - as 16 cores dos detalhes técnicos acima de 4,5:1 nos três fundos e nos dois temas, sem as do macOS;
  - as entrelinhas, a 100%, 125% e 150% e fora da faixa;
  - as 22 transições, que viram zero sem animações sem mudar mais nada;
  - os cantos dos botões e do seletor, o contorno e o contraste do perigo;
  - o `Danger` da opção ao plano da janela, o `Confirm -Danger` com e sem verbos, as seis perguntas e o Não como padrão em todas;
  - um verbo curto em cada destaque, nos três idiomas;
  - a ordem e o arranjo dos botões da nota.
- **O XAML:** em cada um dos 29 modelos, todo nome usado pelos gatilhos e pelas animações existe, e só a opacidade é animada.
- **As de antes continuam passando:** as 59 da R9, as 66 da QA, as 28 da integração e as 26 da R7; o motor de instalação, a atualização simulada e o Setup de verdade (da R9 para esta); o pacote de suporte; as traduções (5.196/5.196); as 159 referências nos três idiomas e a busca; nenhuma chamada com parâmetro que não existe, nenhuma função sem uso.

**Falta ver num PC** (entrou no roteiro): as transições sob o mouse e sem elas com as animações desligadas; a chave sob o mouse; os botões dos destaques nos três idiomas; os botões vermelhos das perguntas que apagam sem volta; a nota do Início numa janela larga e numa estreita, e com o texto a 225%; o contorno dos cartões nos dois temas.

**Entregue:** `WinForge.zip`, `WinForge-codigo-fonte.zip` e `historico-4.0.md`.

---

## R11 — QA geral e as correções

**Data:** 18/11/2026 · **Commit:** 399c56d

**Pedido:** "Como um QA, faça testes envolvendo cada tela, opção, botão e interface do sistema. Faça testes de massa, de desempenho, de front, de back, de integração, de conferência de dados. Testes pontuais, gerais, tudo. Faça um relatório desses testes e passe para um Engenheiro de Software Sênior corrigi-los da melhor forma."

**O teste:** o relatório completo está em `docs/qa-geral-4.0.md` e, no projeto WinForge do Claude, em `claude/qa-geral-4.0.md`. Foram:
- **504 execuções das 84 ações**, com o Windows simulado, no console e na janela, desistindo e aceitando cada pergunta. Tudo o que muda o PC foi bloqueado e anotado. Na janela, a faixa de resultado também foi conferida.
- **83 conferências** de tela, código, dados, integração e desempenho:
  - na tela: o XAML, o teclado em 23.040 combinações, o leitor de tela e o contraste;
  - no código: 6.680 textos traduzidos e 33 formatos;
  - nos dados: a navegação, os 53 ajustes, os essenciais, as datas do Windows e as traduções;
  - na integração e na massa: o histórico, a busca, as perguntas, o espaço em disco nas três telas e as bordas.

**Resultado:** nenhum erro escapou, nada travou e nenhuma faixa ficou sem título ou com um próximo passo que não existe. Saíram 5 achados (1 médio e 4 baixos) e 1 observação.

**O que mudou**

| Achado | O que era | Como ficou |
|---|---|---|
| Q1 (média) | Em inglês e espanhol, abrir levava cerca de 0,55 s a mais: a leitura da tradução chamava uma função a cada linha | `Read-WinForgeTextCatalog` tira as aspas na própria leitura e só chama `ConvertFrom-WinForgePoString` com barra invertida. O resultado é o mesmo, e carregar os módulos caiu de 1,26–1,32 s para 0,72–0,79 s (português: 0,62 s) |
| Q2 (baixa) | 35 descrições em inglês e espanhol passavam de 60 letras, e uma, em espanhol, terminava em reticências | Reescritas com até 60 letras |
| Q3 (baixa) | Quatro itens sem palavras de busca; "reverter ajustes", "voltar ao normal", "revert all" e "logs" (em espanhol) não achavam o item | Palavras nos três idiomas para `tweaks.recommended`, `tweaks.restore-point`, `tweaks.revert-all` e `app.logs`; o ponto de restauração (nas duas páginas) ganhou "proteção do sistema" |
| Q4 (baixa) | Duas entradas antigas do CHANGELOG falavam de QA, testes automatizados e GitHub Actions | Reescritas sem esses termos |
| Q5 (baixa) | Clicar de novo no Mais opções fechava e reabria o menu (pela leitura do código) | `Show-GuiMoreMenu` tira o mouse do botão enquanto o menu está aberto (`IsHitTestVisible`) e devolve ao fechar, antes do foco |
| O1 | O aviso de disco do monitor abre a Limpeza rápida; o Início e o Verificar o PC, a personalizada | Sem mudança: o aviso diz "Clique para fazer uma limpeza rápida", e as três telas concordam em quando avisar |

**O que precisou de decisão**
- **As palavras de busca não podem roubar lugar.** Cada busca possível foi comparada antes e depois: cada nome, título e palavra de busca, nos três idiomas, 2.538 ao todo. Das 77 que mudaram, duas pioravam e foram desfeitas:
  - "reset", em inglês, deixava de trazer Restaurar este PC;
  - "erros" trazia a pasta de logs no lugar dos diagnósticos.
- **"Proteção do sistema"** é o nome do Windows para os pontos de restauração. Com ele, "proteção" sozinho traz o ponto de restauração em segundo lugar, depois do Estado da proteção.
- **O Mais opções usa a solução padrão do WPF** (o botão fora do alcance do mouse enquanto o menu está aberto), e não um tempo de espera. Se o clique não chegasse ao botão, nada muda; se chegasse, ele não abre de novo. O teclado não muda.

**Por dentro**
- **Core.psm1:** `Read-WinForgeTextCatalog`.
- **Navigation.psm1:** `-Keywords` nos quatro itens; uma frase nova de palavras para os dois pontos de restauração.
- **WinForge.Gui.ps1:** `Show-GuiMoreMenu`.
- **CHANGELOG.md:** as duas frases antigas e as mudanças da 4.0.
- **Traduções:** 32 textos novos ou mudados (28 descrições e 4 frases de palavras), 5.199 ao todo.
- **docs/qa-geral-4.0.md:** o relatório, com o resultado das correções.

**Conferido na nuvem**
- **As conferências novas das correções, todas passando:** 26 em português e em espanhol e 28 em inglês.
  - o dicionário igual ao de antes nos dois arquivos reais e num de bordas, em CRLF e em LF, e o tempo;
  - as descrições até 60 letras;
  - as buscas do achado e as que não podiam mudar;
  - o CHANGELOG;
  - a ordem das trocas no Mais opções.
- **As 83 conferências do QA**, refeitas depois das correções: todas passando.
- **As de antes continuam passando:**
  - as 59 da R9, as 52 da R10, as 66 da QA e as 28 da integração, e as 26 da R7;
  - o motor de instalação, a atualização simulada e o Setup de verdade (da R10 para esta), e o pacote de suporte;
  - as traduções (5.199/5.199), as 159 referências nos três idiomas e a busca de cada nome;
  - nenhuma chamada com parâmetro que não existe e nenhuma função sem uso, e nenhum aviso novo do analisador.

**Falta ver num PC** (entrou no roteiro):
- o segundo clique no Mais opções;
- o tempo de abrir em inglês e em espanhol;
- as descrições em espanhol com a janela estreita.

**Entregue:** `WinForge.zip`, `WinForge-codigo-fonte.zip`, `historico-4.0.md` e `qa-geral-4.0.md`.

## R12 — Segunda revisão de engenharia do código

**Data:** 18/11/2026 · **Commit:** c467f90

**Pedido:** "Como um Engenheiro de Software Sênior, revise todos os código do sistema", com três objetivos:
- remover códigos claramente obsoletos ou mal otimizados, sem quebrar o sistema existente;
- adotar boas práticas no funcionamento das telas, botões, funções e execuções;
- garantir que o sistema seja robusto, seguro e confiável, e que não deixe o PC do cliente parado ou estragado.

**Como foi revisado:** são cerca de 60 mil linhas. A R7 já tinha revisto o que mexe no PC. Esta revisão leu o código novo desde então (R8 a R11, cerca de 2 mil linhas, quase tudo na janela) e o que a R7 não cobriu:
- o que roda como Administrador e onde ficam os arquivos que ele usa;
- as esperas sem fim: consultas ao Windows e programas externos;
- os recursos que ficam abertos (relógios da janela, leitores do log de eventos, runspaces do monitor);
- o que pesa no desempenho, e o código sem uso.

Também entraram varreduras novas sobre as 1.416 funções:
- **o que só existe no PowerShell 7:** toda a conferência roda no PowerShell 7, e uma chamada que não existe no Windows PowerShell 5.1 passaria nela e quebraria no PC;
- **o C# compilado pelo Add-Type:** no 5.1, ele aceita só o C# 5;
- **`break` e `continue` dentro de um `ForEach-Object`:** eles encerram o laço de fora, ou a ação inteira;
- **`$_` dentro de um `catch`:** ali ele é o erro, e não o item da lista;
- **listas que crescem com `+=` dentro de laços;**
- **estado gravado e nunca lido.**

**O que foi achado e corrigido**

| Achado | Gravidade | Como ficou |
|---|---|---|
| **Consultas ao WMI sem tempo-limite.** 34 das 40 não tinham. Num Windows com o WMI com defeito, comum em PCs antigos, uma consulta pode não responder nunca. Três lugares ficariam parados para sempre: o monitor na bandeja (as conferências leves rodam na mesma linha de execução do ícone, que congelaria), a atualização com um clique (o instalador confere as janelas abertas com o WinForge já fechado, que não abriria de novo) e as ações da janela, presas em "Em execução". | Média | `-OperationTimeoutSec` em todas: 15 s; 30 s nas que costumam demorar (as atualizações instaladas, os aplicativos da Microsoft Store); 60 s no pedido de atualizar os aplicativos da Store. Todas já estavam num `try`: o tempo esgotado vira "não deu para ler", como uma falha já virava. |
| **Pastas apagadas com `Remove-Item -Recurse`.** No Windows PowerShell 5.1, ele segue atalhos de pasta (junções) e apaga o conteúdo do outro lado. Oito pastas do WinForge eram apagadas assim: a do pacote da atualização, a cópia de antes, a de dados (na desinstalação, que roda como Administrador) e as temporárias do backup, do Wi-Fi e do pacote de suporte. Todas ficam onde qualquer programa da conta pode gravar: um atalho de pasta plantado ali faria o WinForge elevado apagar o que está do outro lado, até pastas do sistema. | Média (com o WinForge elevado) | `Remove-WinForgeFolder` apaga com `Remove-WinForgeItem`, que já protegia a limpeza: um atalho de pasta sai como atalho. `Remove-WinForgeItem` passou da Cleanup.psm1 para o Core.psm1, que todos carregam, inclusive o instalador. `Remove-Item -Recurse` ficou só em chaves do registro. |
| **Estado sem uso.** `$script:HomeStampBar` era gravado a cada nota de saúde e nunca lido. | Baixa | Saiu. |
| **Um relógio da janela ficava ligado ao fechar.** O fechamento parava 11 dos 12 relógios; o que ajusta a lista das perguntas ficava. | Baixa (sem efeito visível) | O fechamento para os 12. |

**Conferido e mantido como está**
- **Compatibilidade com o 5.1:** nada do PowerShell 7 no código, como sintaxe (`??`, `?.`, ternário, `&&`), parâmetros (`-AsHashtable`, `Split-Path -LeafBase`, `Sort-Object -Top`) ou APIs do .NET moderno. Os 10 blocos de C# usam só o C# 5.
- **Fluxo:** nenhum `break` ou `continue` escapa de um bloco de pipeline, e nenhum `catch` usa `$_` como o item da lista.
- **Programas externos:** as instalações do winget levam `--disable-interactivity`, e as leituras levam `--accept-source-agreements`. O Parar encerra o que a ação abriu (R7).
- **Log de eventos:** cada leitura tem limite de registros e libera cada registro na hora.
- **Downloads:** todos têm tempo-limite, TLS 1.2 e nenhum endereço `http://`. O endereço aberto no navegador vem da tabela fixa do WinForge, e nunca do catálogo online.
- **Arquivos que crescem:** ficam os 20 logs mais recentes e as 100 últimas aberturas.
- **Tarefa mensal:** roda com o menor privilégio, e o WinForge confere quem pode gravar no script dela.
- **Restos de programas:** nada vem marcado, só nomes exatos, nada dentro das pastas do Windows e da Microsoft, e tudo vai para a Lixeira.
- **Listas com `+=` em laços (189):** todas têm de dezenas a centenas de itens. Trocar não muda o tempo de nada que a pessoa espera.
- **Os eventos da janela de tamanho e de clique** são ligados a controles da própria página e saem com ela. O monitor descarta os itens do menu a cada abertura.
- **Nenhuma função sem uso** (1.416), nenhum nome repetido entre os módulos e nenhum código comentado.

**Riscos conhecidos, mantidos com o motivo**
- **O instalador elevado roda de uma pasta da conta.** Na atualização com um clique, ele vem do pacote em `%LOCALAPPDATA%\WinForge\update`; na desinstalação, de uma cópia temporária. Um programa malicioso que já rode com a conta poderia trocar os arquivos entre a cópia e o aviso do Administrador. Fechar isso pede outro desenho da atualização: a cópia instalada, protegida, prepararia a nova numa pasta só de Administradores. Esse desenho não dá para conferir daqui, e quem já roda com a conta tem caminhos mais simples, como pedir o Administrador por conta própria. Fica para quando houver um PC para testar.
- **Sem ler os processos (WMI com defeito), a atualização segue.** O WinForge que pediu já fechou, e isso é conferido pelo número do processo, sem o WMI. O monitor continua na versão de antes até a próxima entrada no Windows. Na desinstalação, o monitor sai sozinho quando a pasta some. Recusar deixaria esse PC sem atualizar.
- **O monitor importa os módulos a cada leitura pesada** (de hora em hora, em segundo plano). Um runspace sempre aberto pouparia 1 a 2 segundos de processador por hora, ao custo de memória fixa num programa que fica aberto o dia todo.

**Por dentro**
- **Core.psm1:** `Remove-WinForgeItem` (veio da Cleanup.psm1) e `Remove-WinForgeFolder`.
- **Install.psm1, Backup.psm1, NetworkTools.psm1 e Reports.psm1:** `Remove-WinForgeFolder` no lugar de `Remove-Item -Recurse`.
- **`-OperationTimeoutSec`:** em Agent, Backup, CleanupTools, Core, Diagnostics, Drivers, Install, Performance, Security, Software e WindowsSupport.
- **WinForge.Gui.ps1:** saiu `$script:HomeStampBar`; `PromptFitTimer` para ao fechar.
- **Traduções:** sem mudança, 5.199 textos.

**Conferido na nuvem**
- **20 conferências novas, todas passando nos três idiomas:**
  - as 40 consultas com tempo-limite, entre 5 e 60 s, todas num `try`;
  - o `Remove-Item -Recurse` só em chaves do registro;
  - uma pasta com subpastas, um arquivo só de leitura e um atalho para outra pasta: sai inteira, e o outro lado fica intacto;
  - um atalho passado direto sai como atalho;
  - a pasta ausente e o caminho vazio não dão erro;
  - um arquivo travado vira erro depois de o resto sair, e com `-Quiet` não vira;
  - a atualização refaz a pasta do pacote sem seguir um atalho plantado nela;
  - os 12 relógios param ao fechar;
  - as quatro varreduras (PowerShell 7, C# 5, fluxo e `catch`) sem achados.
- **As 84 ações rodaram de novo 336 vezes** com o Windows simulado: nenhum erro escapou e nada travou.
- **As de antes continuam passando:**
  - as 83 do QA geral e as 80 da R11;
  - as 59 da R9, as 52 da R10, as 66 da QA e as 28 da integração, e as 26 da R7;
  - o motor de instalação, a atualização simulada e o Setup de verdade (da R11 para esta), e o pacote de suporte;
  - as traduções (5.199/5.199), as 159 referências nos três idiomas e a busca de cada nome;
  - nenhuma chamada com parâmetro que não existe e nenhuma função sem uso, e nenhum aviso novo do analisador.

**Falta ver num PC** (entrou no roteiro):
- atualizar com um clique e desinstalar apagando os dados (o código que apaga as pastas mudou);
- um PC com o WMI lento ou com defeito, se houver um.

**Entregue:** `WinForge.zip`, `WinForge-codigo-fonte.zip` e `historico-4.0.md`.

---

## R13 — O Início com design, Windows e QA

**Data:** 19/11/2026 · **Commit:** cacc3ba

**Pedido:** juntar um Analista de UX/UI Sênior, um Especialista Microsoft (MVP Windows), um QA Sênior e um Engenheiro de Software Sênior para trabalhar na tela e na função de Início:
- o designer revisa cada detalhe da interface e orienta o engenheiro;
- o especialista confere se os comandos e as alterações no Windows são feitos da melhor forma disponível hoje, de modo seguro e robusto, e se fazem sentido e mudam o que devem no PC;
- o QA testa todas as funções da tela;
- o engenheiro aplica as correções.

**O relatório completo** está em `docs/revisao-inicio-4.0.md`: o mapa da tela, o que cada olhar viu, cada leitura do Windows com a fonte e o veredito, os testes e as fontes.

**O que mudou**

| Achado | Olhar | Como ficou |
|---|---|---|
| Com a manutenção atrasada, a nota mostrava dois botões "Verificar o PC", um deles em destaque. | Designer | Um botão por ação e um destaque só. O ponto que se resolve com um botão da nota não ganha outro igual, e o botão da nota fica em destaque quando esse ponto é o mais pesado. |
| O anel da nota não crescia com o texto do Windows: a 225%, o número passava por cima dele. | Designer | O anel acompanha o tamanho do texto. |
| "Windows Server 2022 Standard 21H2" e, em inglês, "3 items needing attention" terminavam em reticências no cartão estreito. | Designer | "Windows Server 2022" no cartão, com o resto na dica; "3 items to check". |
| Espaçamento do título "Com o WinForge neste PC" diferente do "Seu PC". | Designer | O mesmo nos dois. |
| O Otimizar renovava o IP e redefinia o Winsock e o TCP/IP toda vez, mesmo com a internet funcionando. Isso pede reinício e pode desfazer uma VPN de programa ou uma configuração posta à mão. | MVP | Com a internet funcionando, só o DNS é limpo. O reparo inteiro fica para quando a internet falha. |
| O Otimizar instalava os drivers opcionais do Windows Update. | MVP | Ficam de fora, na lista do que ficou de fora, com o caminho para achá-los (Atualizações > Atualizar drivers). |
| O Otimizar limpava o registro todo mês. A Microsoft não dá suporte a limpadores de registro (KB 2563254). | MVP | Saiu do Otimizar. Continua em Limpeza > Limpar o registro e no Verificar o PC, desmarcada. |
| "(firmware opcional)" e "Carregando", da bateria, em português nas telas em inglês e em espanhol. | MVP e QA | Traduzidos. A bateria devolve também um código, e a regra do cartão usa o código. |
| Com as assinaturas do Defender nunca atualizadas, o Início descontava da nota, mas o cartão Proteção dizia "Protegido", a tela Estado da proteção não avisava e o Verificar o PC dizia "em dia". | QA | As três telas avisam, e o Verificar o PC oferece a correção. |

Também saiu uma leitura repetida: a etapa da bateria perguntava de novo ao Windows se o PC é notebook, o que a etapa da sessão já tinha lido.

**Por dentro**
- **Home.psm1:** a bateria usa a leitura da sessão e o código; o nome curto do Windows Server.
- **GuiDesign.psm1:** `Get-WinForgeHealthActionPlan`, que decide os botões da nota.
- **WinForge.Gui.ps1:** `New-GuiHealthButtons -PrimaryId`, `Update-GuiHealthCard` com o plano de botões, o anel na escala do texto e a margem do título.
- **Diagnostics.psm1:** `Get-WinForgeBatteryState` devolve `Code` e traduz "Carregando".
- **Security.psm1 e Checkup.psm1:** as assinaturas nunca atualizadas.
- **Maintenance.psm1:** saíram a etapa do registro e `Invoke-WinForgeMaintenanceRegistry`; as descrições novas da rede e do Windows Update.
- **Network.psm1:** no Otimizar, só o DNS com a rede funcionando.
- **WindowsUpdate.psm1:** no Otimizar, as opcionais de fora, com o aviso dos drivers.
- **Traduções:** 13 textos novos ou mudados, 5.204 ao todo.

**Conferido na nuvem**
- **241 conferências do Início, todas passando nos três idiomas:** cada etapa da leitura em 15 casos de sessão e suporte, 10 de disco, 12 de manutenção, 15 de proteção, 7 de bateria e 5 de manutenção agendada; a nota; o destino de cada cartão e de cada ponto; e as correções acima, com a rede do Otimizar em cinco situações e o Windows Update do Otimizar com seis tipos de atualização.
- **Os textos dos cartões** medidos na largura mínima nos três idiomas, todos cabendo.
- **As 84 ações rodaram de novo 336 vezes** com o Windows simulado: nenhum erro escapou, e o resultado é o mesmo da R12.
- **As de antes continuam passando:**
  - as 83 do QA geral, as 80 da R11 e as 60 da R12;
  - as 59 da R9 e as 52 da R10. Duas conferências de texto delas foram adaptadas ao código novo dos botões da nota; o que elas conferem (Verificar o PC antes do Otimizar) continua valendo;
  - as 66 da QA, as 28 da integração e as 26 da R7;
  - o motor de instalação, a atualização simulada e o Setup de verdade (da R12 para esta), e o pacote de suporte;
  - as traduções (5.204/5.204), as 160 referências nos três idiomas e a busca de cada nome;
  - nenhuma chamada com parâmetro que não existe, nenhuma função sem uso e nenhum aviso novo do analisador.

**Falta ver num PC** (entrou no roteiro):
- a nota com a manutenção atrasada, com um botão "Verificar o PC" só;
- o anel com o texto do Windows a 150% e a 225%;
- o Otimizar com a internet funcionando (só o DNS, sem pedir reinício por causa da rede) e com o Wi-Fi sem internet (o reparo inteiro);
- um driver opcional no Windows Update, que fica de fora do Otimizar;
- a bateria carregando, na tela em inglês;
- as assinaturas do Defender nunca atualizadas, se houver um PC assim.

**Entregue:** `WinForge.zip`, `WinForge-codigo-fonte.zip`, `historico-4.0.md` e `revisao-inicio-4.0.md`.

---

## R14 — A Manutenção com design, Windows e QA

**Data:** 19/11/2026 · **Commit:** b324722

**Pedido:** juntar um Analista de UX/UI Sênior, um Especialista Microsoft (MVP Windows), um QA Sênior e um Engenheiro de Software Sênior para trabalhar na tela e na função de Manutenção:
- o designer revisa cada detalhe da interface e orienta o engenheiro;
- o especialista confere se os comandos e as alterações no Windows são feitos da melhor forma disponível hoje, de modo seguro e robusto, e se fazem sentido e mudam o que devem no PC;
- o QA testa todas as funções da tela;
- o engenheiro aplica as correções.

**O relatório completo** está em `docs/revisao-manutencao-4.0.md`: o mapa da página, o que cada olhar viu, cada comando do Windows com o veredito, os testes e as fontes.

**O que mudou**

| Achado | Olhar | Como ficou |
|---|---|---|
| O Verificar o PC terminava "com ressalvas: ainda pede atenção: Registro" sempre que aceito como veio. As referências quebradas do registro eram um ponto de atenção, embora viessem desmarcadas e o próprio WinForge não recomende limpá-las (KB 2563254). | MVP e QA | Viram informação; a correção continua na lista, desmarcada. |
| Na parte automática do Otimizar, a Microsoft Store abria por cima das outras etapas quando o Windows recusava o pedido de atualização. | MVP | No Otimizar, a etapa diz o que fazer depois; pedida sozinha, a página abre como antes. |
| O Histórico de manutenções mostrava três números de espaço nas tendências, que pareciam se contradizer. | Designer | Ficam "Liberado nas manutenções" e "Espaço livre, da primeira à última". |
| A mesma etapa com problema aparecia duas vezes no histórico, cada uma com uma frase diferente para o mesmo link. | Designer | As duas dizem "rode de novo em …". |
| Com o Agendador de Tarefas sem responder, a Manutenção agendada punha "Dia 1" em destaque, como se não houvesse tarefa. | Designer e QA | Nenhum dia em destaque. |
| Em espanhol, os estados da tarefa e da verificação estavam no masculino ("Tarea mensual: Activo"). | Designer | No feminino: "Activa", "Desactivada", "No programada", "todavía no hecha". |
| A etapa "Revisar os ajustes do Windows" não tinha o "rode de novo em" no histórico; o nome antigo dela tinha. | QA | Leva a Ajustes do Windows > Aplicar ajustes recomendados. |
| As etapas do Otimizar tinham uma descrição e um tipo traduzidos que nenhuma tela mostra desde que o Otimizar passou a ser sempre o inteiro (a R13 mudou duas dessas descrições, que também não apareciam). | Engenharia | Saíram; o que cada etapa faz ficou como comentário no código. |

**Conferido e mantido**, com o motivo no relatório:
- **o ponto de restauração clássico antes do Otimizar**, mesmo com a Restauração pontual nova do Windows 11: ela volta também os arquivos pessoais e guarda os pontos por 72 horas;
- **o DISM e o SFC sempre;**
- **o reparo do disco** pela marca de "sujo", e não pelo `/spotfix`, que pede uma confirmação digitada;
- **a tarefa mensal sem elevação;**
- **os relatórios mensais sem limite de quantidade:** um arquivo pequeno por mês.

**Por dentro**
- **Maintenance.psm1:** `New-WinForgePlanItem` só com Id, Phase, WithYou e Title; as tendências sem a média da variação; a frase da etapa repetida; o nome "Revisar os ajustes do Windows" nas referências; um comentário que falava do registro.
- **Checkup.psm1:** o registro como Info.
- **Software.psm1:** a Store só abre fora do Otimizar.
- **Schedule.psm1:** sem destaque quando o Agendador não responde.
- **Traduções:** 6 corrigidas em espanhol e 25 que saíram, 5.179 ao todo.
- **docs/funcionalidades-4.0.md:** o Histórico de manutenções abre também pelo cartão Última manutenção, e não só pela busca.

**Conferido na nuvem**
- **As conferências novas da Manutenção, todas passando:** 245 em português, 247 em inglês e 252 em espanhol.
  - O plano do Otimizar.
  - O Otimizar de ponta a ponta, em 21 execuções.
  - O desfecho e os dois históricos.
  - O Verificar o PC em 8 situações.
  - A Manutenção agendada: o XML, o comando, os códigos, seis estados da tela, criar, remover e a execução do mês.
  - O ponto de restauração.
  - Nenhum texto do português em inglês e em espanhol.

  Cada conferência das correções falha no código de antes e passa no de agora.
- **As 84 ações rodaram de novo 336 vezes** com o Windows simulado: nenhum erro escapou, e o resultado é o mesmo da R13.
- **As de antes continuam passando:**
  - as 241 do Início nos três idiomas;
  - as 83 do QA geral, as 80 da R11 e as 60 da R12;
  - as 59 da R9 e as 52 da R10, as 66 da QA, as 28 da integração e as 26 da R7;
  - o motor de instalação, a atualização simulada e o Setup de verdade (da R13 para esta), e o pacote de suporte;
  - as traduções (5.179/5.179), as 160 referências nos três idiomas e a busca de cada nome;
  - nenhuma chamada com parâmetro que não existe, nenhuma função sem uso e nenhum aviso novo do analisador.

**Falta ver num PC** (entrou no roteiro):
- o Verificar o PC com referências quebradas no registro;
- o Histórico de manutenções depois de dois Otimizar;
- a Manutenção agendada em espanhol;
- o ponto de restauração no Windows 11 25H2 com a Restauração pontual ligada.

**Entregue:** `WinForge.zip`, `WinForge-codigo-fonte.zip`, `historico-4.0.md` e `revisao-manutencao-4.0.md`.

---

## R15 — O Diagnóstico com design, Windows e QA

**Data:** 19/11/2026 · **Commit:** ee6869f

**Pedido:** juntar um Analista de UX/UI Sênior, um Especialista Microsoft (MVP Windows), um QA Sênior e um Engenheiro de Software Sênior para trabalhar na tela e na função de Diagnóstico:
- o designer revisa cada detalhe da interface e orienta o engenheiro;
- o especialista confere se os comandos e as alterações no Windows são feitos da melhor forma disponível hoje, de modo seguro e robusto, e se fazem sentido e mudam o que devem no PC;
- o QA testa todas as funções da tela;
- o engenheiro aplica as correções.

**O relatório completo** está em `docs/revisao-diagnostico-4.0.md`: o mapa da página, o que cada olhar viu, cada leitura do Windows com o veredito, os testes e as fontes.

**O que mudou**

| Achado | Olhar | Como ficou |
|---|---|---|
| Os discos físicos, as partições, os contadores de cada disco e os dispositivos eram lidos sem tempo-limite: um disco morrendo ou uma controladora travada deixavam a Saúde dos discos (e o Verificar o PC, o relatório e o monitor) esperando sem fim. | MVP | Os discos físicos vêm de `MSFT_PhysicalDisk` pelo WMI, com 60 segundos de prazo; as partições, os contadores e os dispositivos, com `-AsJob` e o mesmo prazo. O tipo do disco que vem como código vira o nome. |
| Oito códigos de tela azul comuns caíam em "causa desconhecida". | MVP | Cada um com o nome, a causa provável e o próximo passo. |
| Em inglês e em espanhol, um disco só quente pedia backup em vez de conferir a ventilação. | QA | A nota da temperatura é comparada inteira, no idioma da tela. |
| As categorias Biometria e Portas saíam em português na tela em inglês e em espanhol. | Designer e QA | Pela tradução. |
| No Teste de memória, dizer Não depois de ler o último resultado terminava em "Cancelado", mesmo sendo o padrão, e escondia os erros do último teste. | Designer e QA | Com erros, a faixa é a ressalva dos erros; com um teste recente sem erros, termina como as telas de consulta; sem teste, Não continua sendo cancelar. |
| Sem ler o log do Sistema, as Telas azuis punham na faixa só a mensagem crua do Windows, sem dizer onde conferir. | Designer | Como nos Eventos críticos: a orientação do Visualizador de Eventos e a frase inteira na faixa. |
| O tempo ligado com a Inicialização Rápida era explicado com duas frases diferentes em Sobre este PC e em Tempo ligado e energia. | Designer | A mesma frase nas duas. |

**Conferido e mantido**, com o motivo no relatório:
- **o Secure Boot pelo Registro**, legível sem Administrador, com o modo de início antes;
- **a memória de vídeo pelo Registro**, porque o WMI para em 4 GB;
- **o reinício sem `/f`** e o `PendingFileRenameOperations` como sinal fraco;
- **o Kernel-Power 41 sem código** fora da conta das telas azuis;
- **as datas do suporte do Windows**, que conferem com hoje (o ESU de casa do Windows 10 vai até 12/10/2027).

**Por dentro**
- **Diagnostics.psm1:** `Invoke-WinForgeStorageQuery` (novo); `MSFT_PhysicalDisk` pelo `Get-CimInstance` em `Get-WinForgeDiskSummary` e `Get-WinForgeDiskHealth`; os códigos em `Get-WinForgeDiskTypeText`; a temperatura em `Show-WinForgeDiskHealth`; Biometria e Portas em `Get-WinForgeDeviceName`; os oito códigos em `Get-WinForgeBugCheckInfo`; `Show-WinForgeBlueScreens`, `Start-WinForgeMemoryTest` e `Show-WinForgeSystemInfo`.
- **Fica para a revisão do Reparo:** a escolha da unidade do CHKDSK (`Test-WinForgeDriveExternal`) ainda lê `Get-Partition | Get-Disk` sem tempo-limite.
- **Traduções:** 4 novas e 1 que saiu, 5.182 ao todo.

**Conferido na nuvem**
- **As conferências novas do Diagnóstico, todas passando:** 212 em português e 224 em inglês e em espanhol.
  - Sobre este PC, o Suporte do Windows (11 situações e 13 combinações dos requisitos do Windows 11) e os discos (pelo nome e pelo código).
  - A Saúde dos discos com sete discos, sem Administrador, sem resposta e com os contadores que não respondem.
  - Os dispositivos, a bateria, o teste de memória, os eventos, as telas azuis (com os oito códigos novos), o reinício pendente, o tempo ligado e a página.
  - Nenhum texto do português em inglês e em espanhol.

  Cada conferência das correções falha no código de antes e passa no de agora.
- **As 84 ações rodaram de novo 336 vezes** com o Windows simulado: nenhum erro escapou, e o resultado é o mesmo da R14, fora a faixa nova das Telas azuis.
- **As de antes continuam passando:**
  - as 245, 247 e 252 da Manutenção e as 241 do Início nos três idiomas;
  - as 83 do QA geral, as 80 da R11 e as 60 da R12;
  - as 59 da R9 e as 52 da R10, as 66 da QA, as 28 da integração e as 26 da R7;
  - o motor de instalação, a atualização simulada e o Setup de verdade (da R14 para esta), e o pacote de suporte;
  - as traduções (5.182/5.182), as 160 referências nos três idiomas e a busca de cada nome;
  - nenhuma chamada com parâmetro que não existe, nenhuma função sem uso e nenhum aviso novo do analisador.

**Falta ver num PC** (entrou no roteiro):
- a Saúde dos discos e Discos e espaço livre num PC real, com o tipo de cada disco e os contadores, e num pendrive;
- o tempo dessas duas telas;
- Dispositivos com problema em inglês;
- o Teste de memória respondendo Não depois de um teste;
- uma tela azul real com um dos códigos novos, se houver.

**Entregue:** `WinForge.zip`, `WinForge-codigo-fonte.zip`, `historico-4.0.md` e `revisao-diagnostico-4.0.md`.

---

## R16 — A Segurança com design, Windows e QA

**Data:** 19/11/2026 · **Commit:** 0570b7c

**Pedido:** juntar um Analista de UX/UI Sênior, um Especialista Microsoft (MVP Windows), um QA Sênior e um Engenheiro de Software Sênior para trabalhar na tela e na função de Segurança:
- o designer revisa cada detalhe da interface e orienta o engenheiro;
- o especialista confere se os comandos e as alterações no Windows são feitos da melhor forma disponível hoje, de modo seguro e robusto, e se fazem sentido e mudam o que devem no PC;
- o QA testa todas as funções da tela;
- o engenheiro aplica as correções.

**O relatório completo** está em `docs/revisao-seguranca-4.0.md`: o mapa da página, o que cada olhar viu, cada comando do Windows com o veredito, os testes e as fontes.

**O que mudou**

| Achado | Olhar | Como ficou |
|---|---|---|
| O estado do Defender, as ameaças, as preferências e o firewall eram lidos sem tempo-limite: um WMI com defeito ou o Defender travado deixavam a tela (e o Início, o Verificar o PC, o monitor e o relatório) esperando sem fim. | MVP | Com `-AsJob` e 60 segundos de prazo, pelo mesmo mecanismo dos discos da R15, que passou para o Core com um nome geral. |
| O comando que desliga a conta Convidado vinha com o nome traduzido pela tela ("net user Guest"), que não existe num Windows em português. | MVP e QA | O comando usa o nome real da conta neste Windows. |
| A auditoria deveria lembrar de guardar a chave do BitLocker (desde a R4), mas o lembrete nunca aparecia. | QA | Aparece. |
| "Compartilhamento SMB 1.0" na auditoria e o "verificado:" da Verificar uma pasta saíam em português nas telas em inglês e em espanhol. | QA | Pela tradução. |
| As ameaças ativas apareciam com o nome técnico do Defender, enquanto a verificação já mostrava "Wacatac (trojan)". | Designer | O nome curto em todo lugar; o completo nos detalhes técnicos. |
| Com o antivírus sem leitura, a faixa dizia "Nenhum ponto de atenção no que foi lido"; o firewall sem leitura não tinha botão; em inglês, a frase do que faltou começava em minúscula. | Designer | "Antivírus sem leitura", o botão do firewall e a maiúscula. |
| Na auditoria sem Administrador, o BitLocker dizia que "esta edição pode não ter o BitLocker", e as ameaças e o SMB 1.0, "não foi possível consultar". | Designer e QA | "Pede o WinForge aberto como Administrador". |
| Uma falha ao criar a chave do BitLocker dizia "Não foi possível ler o BitLocker". | Designer e QA | Diz que a chave não foi criada, com o motivo. |
| Numa ameaça que só esperava reiniciar, o resumo mandava escolher o que fazer, e a faixa, reiniciar. | Designer e QA | O resumo diz o mesmo que a faixa. |

**Conferido e mantido**, com o motivo no relatório:
- **a verificação offline no aplicativo do Windows**, porque o `Start-MpWDOScan` reinicia o PC na hora;
- **`Update-MpSignature` e `Start-MpScan` sem tempo-limite:** são longos, a pessoa espera e o Parar interrompe a espera;
- **o SMB 1.0 pelo recurso do Windows**, o caminho que a Microsoft indica;
- **a segunda tentativa das assinaturas pela Microsoft** só quando a ordem de fontes da empresa permite.

**Por dentro**
- **Core.psm1:** `Invoke-WinForgeCimCommand` e `$script:WinForgeCimTimeoutSec`, vindos da Diagnostics.psm1 (eram `Invoke-WinForgeStorageQuery` na R15); o tempo esgotado vira `TimeoutException`.
- **Diagnostics.psm1:** as partições, os contadores e os dispositivos pelo `Invoke-WinForgeCimCommand`.
- **Security.psm1:**
  - as leituras do Defender e do firewall pelo `Invoke-WinForgeCimCommand`;
  - `Get-WinForgeThreatListText` (nova) e `Get-WinForgeGuestAccount` (no lugar de `Get-WinForgeGuestAccountEnabled`);
  - `GuestName` e `Administrator` nos fatos da auditoria;
  - o conselho dos pontos que só informam em `New-WinForgeAuditCheck`;
  - a faixa do Estado da proteção, o resumo da verificação e a falha de criar a chave;
  - o SMB 1.0 e o "Verificado: {0}" pela tradução.
- **Traduções:** 5 novas, 5.187 ao todo.

**Conferido na nuvem**
- **As conferências novas da Segurança, todas passando:** 134 em português e 142 em inglês e em espanhol.
  - O Estado da proteção em 16 situações e o destino de cada próximo passo.
  - A auditoria: tudo certo, cada ponto de atenção, quatro estados do BitLocker, sem Administrador, sem o antivírus lido e a nota.
  - A chave do BitLocker: mostrar, salvar, criar, criar com falha, sem Administrador e sem resposta.
  - As assinaturas: a segunda tentativa, os erros e outro antivírus.
  - As três verificações: o que o Defender encontrou, o que pede e as perguntas.
  - A página e os textos nos três idiomas.

  Cada conferência das correções falha no código de antes e passa no de agora.
- **As 84 ações rodaram de novo 336 vezes** com o Windows simulado: nenhum erro escapou, e o resultado é o mesmo da R15, fora a faixa nova do antivírus sem leitura.
- **As de antes continuam passando:**
  - as 212, 224 e 224 do Diagnóstico, as 245, 247 e 252 da Manutenção e as 241 do Início;
  - as 83 do QA geral, as 80 da R11 e as 60 da R12;
  - as 59 da R9 e as 52 da R10, as 66 da QA, as 28 da integração e as 26 da R7;
  - o motor de instalação, a atualização simulada e o Setup de verdade (da R15 para esta), e o pacote de suporte;
  - as traduções (5.187/5.187), as 160 referências nos três idiomas e a busca de cada nome;
  - nenhuma chamada com parâmetro que não existe, nenhuma função sem uso e nenhum aviso novo do analisador.

**Falta ver num PC** (entrou no roteiro):
- o Estado da proteção e a auditoria num PC real, com e sem Administrador, no mesmo tempo de antes;
- o lembrete da chave na auditoria de um notebook com BitLocker;
- a conta Convidado num Windows em português com a tela em inglês;
- o arquivo de teste EICAR numa pasta verificada;
- criar a chave num PC que exige guardá-la no Active Directory, se houver um.

**Entregue:** `WinForge.zip`, `WinForge-codigo-fonte.zip`, `historico-4.0.md` e `revisao-seguranca-4.0.md`.

---

## R17 — A Limpeza com design, Windows e QA

**Data:** 19/11/2026 · **Commit:** b722bd6

**Pedido:** juntar um Analista de UX/UI Sênior, um Especialista Microsoft (MVP Windows), um QA Sênior e um Engenheiro de Software Sênior para trabalhar na tela e na função de Limpeza:
- o designer revisa cada detalhe da interface e orienta o engenheiro;
- o especialista confere se os comandos e as alterações no Windows são feitos da melhor forma disponível hoje, de modo seguro e robusto, e se fazem sentido e mudam o que devem no PC;
- o QA testa todas as funções da tela;
- o engenheiro aplica as correções.

**O relatório completo** está em `docs/revisao-limpeza-4.0.md`: o mapa da página, o que cada olhar viu, cada comando do Windows com o veredito, os testes e as fontes.

**O que mudou**

| Achado | Olhar | Como ficou |
|---|---|---|
| Limpar componentes do Windows, sozinha, rodava o DISM mesmo com uma atualização esperando reinício: ele recusava depois de minutos (0x800F0806), e a tela dizia só o código. | MVP e QA | Confere antes, pelo mesmo teste do reparo: o DISM não roda, a tela diz por quê e a faixa oferece reiniciar. O 0x800F0806, se vier, diz que falta reiniciar. |
| Esvaziar a Lixeira, a Limpeza personalizada, a exclusão permanente dos Downloads e os componentes diziam só "Concluído"; a Lixeira vazia e os Downloads sem nada também. | Designer | "6 MB liberados" no título, como a Limpeza rápida, com o que foi limpo embaixo; "Cerca de 2 GB liberados" nos componentes; "Nada para limpar", com o porquê. |
| A ressalva da Limpeza rápida dizia "1 de 3 partes falhou", sem dizer qual. | Designer e QA | A faixa diz quanto saiu e qual parte não foi limpa, ou que itens em uso ficaram. |
| Com a pasta Downloads num pendrive, a tela oferecia a Lixeira e, escolhida, dizia que nada tinha saído. O aviso do limite da Lixeira vinha depois da escolha. | Designer e QA | Sem Lixeira, só a exclusão permanente aparece, com o porquê antes. O aviso do limite vem antes da escolha. |
| Uma ressalva nos Downloads, nos duplicados e nos restos tirava o botão Esvaziar a Lixeira. | Designer | O botão fica. |
| Na Limpeza rápida com a Lixeira vazia, o resumo ganhava a seção "Esvaziar a Lixeira". | Designer | Não ganha. |
| A análise de espaço sem o disco lido perdia o que a limpeza libera e o botão. | Designer | "Disco do sistema não lido", com os dois. |
| Limpar o registro dizia "Concluído", e o desfazer só aparecia no texto. | Designer | "3 referências removidas", com o botão Histórico de mudanças. |
| "Itens ignorados 0" nos Downloads. | Designer | A linha só aparece quando algum ficou. |
| A pergunta dos restos de programas dizia "os 3 pastas marcados" e "Firefox e Firefox". | QA | "Enviar 3 pastas para a Lixeira?". |
| A barra da limpeza dos Downloads dizia "Limpando Downloads" nas telas em inglês e em espanhol. | QA | Pela tradução. |
| Em inglês, "The Downloads folder it is on a USB drive...". | QA | Sem o "it". |

**Conferido e mantido**, com o motivo no relatório:
- **os componentes sem `/ResetBase`**, que impediria desinstalar as atualizações já instaladas;
- **o DISM e o cipher sem tempo-limite:** são longos, a pessoa espera e o Parar interrompe;
- **os despejos de memória pelos lugares padrão do Windows**, e não por um lugar trocado à mão;
- **duplicados, restos e atalhos sempre pela Lixeira**, recusados numa unidade sem Lixeira;
- **os temporários só com mais de 24 horas.**

**Por dentro**
- **Cleanup.psm1:**
  - `Set-WinForgeRecycleBinNext` aceita a ressalva (só o botão);
  - `Clear-WinForgeDownloads` confere a Lixeira e o limite antes da escolha;
  - `Invoke-WinForgeDownloadsRemoval`: a barra pela tradução e "Itens ignorados" só quando houver;
  - `Invoke-WinForgeQuickCleanup`: a Lixeira vazia fora das etapas e a ressalva com o nome das partes;
  - as faixas de `Clear-WinForgeRecycleBin`, `Invoke-WinForgeCustomCleanup`, `Show-WinForgeSpaceAnalysis` e da exclusão permanente;
  - `Invoke-WinForgeComponentCleanup`: o reinício pendente, o 0x800F0806 e a faixa.
- **Repair.psm1:** `Request-WinForgeRepairRestart` recebe os textos, com os do reparo como padrão, e `Invoke-WinForgeTool` ganha `-ServicingText`.
- **CleanupTools.psm1:** a pergunta dos restos e o botão da Lixeira na ressalva dos duplicados e dos restos.
- **RegistryCleaner.psm1:** a faixa com o botão Histórico de mudanças.
- **Traduções:** 18 novas e 7 que saíram de uso, 5.198 ao todo; em inglês, 7 motivos de "sem Lixeira" sem o "it".

**Conferido na nuvem**
- **As conferências novas da Limpeza, todas passando:** 178 em português e 187 em inglês e em espanhol.
  - A Limpeza rápida em 11 situações, a Lixeira em 7 e os Downloads em 14.
  - A análise de espaço, o resumo da página e a Limpeza personalizada, com o que não tem volta e a Otimização de Entrega.
  - Os atalhos, os duplicados com arquivos de verdade, os restos de programas e o registro.
  - Os componentes, com o reinício pendente, e o espaço livre.
  - A página e os textos nos três idiomas, incluída a barra de andamento.

  Cada conferência das correções falha no código de antes e passa no de agora.
- **As 84 ações rodaram de novo 336 vezes** com o Windows simulado: nenhum erro escapou, e o resultado é o mesmo da R16, fora a faixa nova de Esvaziar a Lixeira.
- **As de antes continuam passando:**
  - as 134, 142 e 142 da Segurança e as 212, 224 e 224 do Diagnóstico;
  - as 245, 247 e 252 da Manutenção, com o reparo do DISM e do SFC dizendo os mesmos textos de antes, e as 241 do Início;
  - as 83 do QA geral, as 80 da R11 e as 60 da R12;
  - as 59 da R9 e as 52 da R10, as 66 da QA, as 28 da integração e as 26 da R7;
  - o motor de instalação, a atualização simulada e o Setup de verdade (da R16 para esta), e o pacote de suporte;
  - as traduções (5.198/5.198), as 160 referências nos três idiomas e a busca de cada nome;
  - nenhuma chamada com parâmetro que não existe, nenhuma função sem uso e nenhum aviso novo do analisador.

**Falta ver num PC** (entrou no roteiro):
- Limpar componentes do Windows num PC com uma atualização esperando reinício, e de novo depois de reiniciar;
- a pasta Downloads num pendrive;
- as faixas de Esvaziar a Lixeira, com algo dentro e vazia, e da Limpeza personalizada;
- a Limpeza rápida com a Lixeira vazia;
- o botão Histórico de mudanças depois de Limpar o registro.

**Entregue:** `WinForge.zip`, `WinForge-codigo-fonte.zip`, `historico-4.0.md` e `revisao-limpeza-4.0.md`.

---

## R18 — O Desempenho com design, Windows e QA

**Data:** 19/11/2026 · **Commit:** 7510a7b

**Pedido:** juntar um Analista de UX/UI Sênior, um Especialista Microsoft (MVP Windows), um QA Sênior e um Engenheiro de Software Sênior para trabalhar na tela e na função de Desempenho:
- o designer revisa cada detalhe da interface e orienta o engenheiro;
- o especialista confere se os comandos e as alterações no Windows são feitos da melhor forma disponível hoje, de modo seguro e robusto, e se fazem sentido e mudam o que devem no PC;
- o QA testa todas as funções da tela;
- o engenheiro aplica as correções.

**O relatório completo** está em `docs/revisao-desempenho-4.0.md`: o mapa da página, o que cada olhar viu, cada comando do Windows com o veredito, os testes e as fontes.

**O que mudou**

| Achado | Olhar | Como ficou |
|---|---|---|
| Gerenciar inicialização lia, desativava e reativava as tarefas agendadas sem prazo, também no desfazer e no Otimizar: um Agendador de Tarefas travado deixava a tela parada sem fim. | MVP e QA | Os três comandos rodam com `-AsJob` e espera de até 60 segundos, como os do Defender e dos discos. Sem resposta, a lista segue sem as tarefas, com uma linha que diz isso. |
| O esvaziamento da memória pedia a cada programa mais acesso do que o necessário. | MVP | O mínimo que a Microsoft documenta para o `EmptyWorkingSet`. |
| O desfazer de uma tarefa, com o Agendador sem resposta, dizia "item de inicialização desconhecido". | QA | "As tarefas agendadas não puderam ser lidas", com o motivo. |
| No Acelerar agora, os temporários recusados apareciam como "0 B", e sem temporários o resumo dizia "0 B de temporários liberados". | Designer e QA | "Não foi possível apagar", em amarelo; sem temporários, eles saem da frase. |
| O Acelerar agora com a memória e os temporários recusados terminava em amarelo. | Designer e QA | Vermelho, "A memória não foi liberada", com o motivo dos temporários. |
| A falha de Liberar memória dizia só "Não foi concluído". | Designer | "A memória não foi liberada" e "O Windows não atendeu ao pedido.". |
| Em Programas pesando agora, o Não ao "Encerrar à força", com só programas sem janela marcados, terminava em "ficou aberto". | Designer e QA | "Operação cancelada". |
| Na revisão do Otimizar, o Não ou a lista cancelada terminavam em "você não mudou nada". | Designer e QA | Cancelar; no resumo do Otimizar, "nada mudou". |

**Conferido e mantido**, com o motivo no relatório:
- **o cache de arquivos do Windows não é esvaziado:** já conta como memória disponível;
- **desativar na inicialização não apaga nada**, como no Gerenciador de Tarefas e nas Configurações;
- **as tarefas que também rodam em outros horários ficam fora da lista**, para os programas continuarem se atualizando;
- **encerrar à força só com a pergunta à parte, no Não.**

**Por dentro**
- **Startup.psm1:** as tarefas pelo `Invoke-WinForgeCimCommand`; `Get-WinForgeStartupTasksProblem` (nova) e o aviso em `Set-WinForgeStartupItems`; `Read-WinForgeStartupReview` separa o cancelar do "não mudou nada".
- **Journal.psm1:** o desfazer da inicialização com o motivo do Agendador.
- **Performance.psm1:** o acesso do `EmptyWorkingSet`; as faixas de `Invoke-WinForgeMemoryOptimization` e `Invoke-WinForgeBoost`; o Não ao "à força" em `Show-WinForgeHeavyProcesses`.
- **Traduções:** 5 novas e 1 que saiu de uso, 5.202 ao todo.

**Conferido na nuvem**
- **As conferências novas do Desempenho, todas passando:** 96 em português e 102 em inglês e em espanhol.
  - O Acelerar agora em 10 situações e Liberar memória em 5.
  - Programas pesando agora em 10 situações, mais um processo de verdade aberto e fechado na nuvem.
  - Gerenciar inicialização em 9 situações, a revisão do Otimizar em 4 e o desfazer em 2.
  - O resumo da página, a página e os textos nos três idiomas.

  Cada conferência das correções falha no código de antes e passa no de agora.
- **As 84 ações rodaram de novo 336 vezes** com o Windows simulado: nenhum erro escapou, e o resultado é o mesmo da R17, fora o resumo do Acelerar agora sem o "0 B de temporários".
- **As de antes continuam passando:**
  - as 178, 187 e 187 da Limpeza, as 134, 142 e 142 da Segurança e as 212, 224 e 224 do Diagnóstico;
  - as 245, 247 e 252 da Manutenção, com a revisão do Otimizar, e as 241 do Início;
  - as 83 do QA geral, as 80 da R11 e as 60 da R12;
  - as 59 da R9 e as 52 da R10, as 66 da QA, as 28 da integração e as 26 da R7;
  - o motor de instalação, a atualização simulada e o Setup de verdade (da R17 para esta), e o pacote de suporte;
  - as traduções (5.202/5.202), as 160 referências nos três idiomas e a busca de cada nome;
  - nenhuma chamada com parâmetro que não existe, nenhuma função sem uso e nenhum aviso novo do analisador.

**Falta ver num PC** (entrou no roteiro):
- Gerenciar inicialização com uma tarefa agendada de outro fabricante: desativar, conferir no Agendador de Tarefas e desfazer pelo Histórico de mudanças;
- a faixa de Liberar memória e do Acelerar agora;
- marcar só um programa sem janela em Programas pesando agora e responder Não;
- a revisão do Otimizar respondendo Não.

**Fora desta tela:** a Manutenção agendada (Manutenção) também fala com o Agendador de Tarefas sem prazo. Fica para quando a Manutenção for revista de novo.

**Entregue:** `WinForge.zip`, `WinForge-codigo-fonte.zip`, `historico-4.0.md` e `revisao-desempenho-4.0.md`.

---

## R19 — O Reparo com design, Windows e QA

**Data:** 19/11/2026 · **Commit:** 01febe8

**Pedido:** juntar um Analista de UX/UI Sênior, um Especialista Microsoft (MVP Windows), um QA Sênior e um Engenheiro de Software Sênior para trabalhar na tela e na função de Reparo:
- o designer revisa cada detalhe da interface e orienta o engenheiro;
- o especialista confere se os comandos e as alterações no Windows são feitos da melhor forma disponível hoje, de modo seguro e robusto, e se fazem sentido e mudam o que devem no PC;
- o QA testa todas as funções da tela;
- o engenheiro aplica as correções.

**O relatório completo** está em `docs/revisao-reparo-4.0.md`: o mapa da página, o que cada olhar viu, cada comando do Windows com o veredito, os testes e as fontes.

**O que mudou**

| Achado | Olhar | Como ficou |
|---|---|---|
| A leitura dos dispositivos depois de Detectar dispositivos e drivers não tinha prazo: um WMI com defeito deixava a tela parada sem fim. | MVP e QA | Com `-AsJob` e até 60 segundos, como em Diagnóstico > Dispositivos com problema. |
| A lista de unidades do CHKDSK lia o disco de cada uma sem prazo (deixado pela R15 para esta revisão): um disco travado deixava a tela parada. | MVP e QA | Com `-AsJob` e até 60 segundos; sem resposta, a unidade aparece sem a marca de externa. |
| O código 2 do CHKDSK virava ressalva, embora a Microsoft o descreva como uma limpeza interna, e não um erro. | MVP | "Nenhum erro na unidade C:"; a etapa do Otimizar não fica mais amarela por isso. |
| As falhas conhecidas do DISM (os arquivos do reparo, uma política, o servidor da empresa) terminavam em "Não foi concluído", sem frase. | Designer e QA | "A imagem do Windows não foi reparada", com o que fazer, sozinho e no reparo completo. |
| O DISM esperando reinício terminava em "Não foi concluído", e o resumo dizia duas vezes para reiniciar. | Designer e QA | "Reinicie antes de reparar", com o conselho uma vez. |
| O DISM e o SFC sozinhos terminando no reinício diziam "Concluído com ressalvas"; o SFC que não rodou, "Não foi concluído". | Designer e QA | "Reinicie para concluir o reparo", "Reinicie e verifique de novo" e "O SFC não conseguiu rodar", com o que fazer. |
| O agendamento recusado do CHKDSK, a otimização que falhou e a busca de dispositivos com o 3010 tinham a faixa genérica. | Designer e QA | "A unidade C: precisa de reparo", "A unidade C: não foi otimizada" e "Reinicie para terminar a instalação". |

**Conferido e mantido**, com o motivo no relatório:
- **o DISM antes do SFC**, a ordem que a Microsoft indica;
- **o `/RestoreHealth` sem `/Source`:** o Windows Update é a fonte padrão;
- **o reparo do disco pela marca de "sujo"**, e não pelo `/spotfix`, que pede uma confirmação digitada no disco do Windows;
- **o CHKDSK com o Windows aberto só verifica;**
- **o `/O` no defrag:** o Windows escolhe entre o TRIM e a desfragmentação.

**Por dentro**
- **Repair.psm1:** `Set-WinForgeDismFailureView` (no lugar de `Set-WinForgeDismServiceView`) e `Set-WinForgeSfcFailureView` (nova); as faixas novas; `Test-WinForgeDriveExternal` e `Get-WinForgeDeviceScanRemaining` pelo `Invoke-WinForgeCimCommand`; o código 2 do CHKDSK.
- **Traduções:** 10 novas e 2 que saíram de uso, 5.210 ao todo.

**Conferido na nuvem**
- **As conferências novas do Reparo, todas passando:** 112 em português e 119 em inglês e em espanhol.
  - O reparo completo em 13 situações, mais 2 no Otimizar.
  - O DISM sozinho em 12 e o SFC sozinho em 7, com a leitura do CBS.log.
  - O CHKDSK em 13, mais 1 no Otimizar, com vários discos, um externo e um disco que não responde.
  - A otimização em 5 e a busca de dispositivos em 7.
  - A página e os textos nos três idiomas.

  Cada conferência das correções falha no código de antes e passa no de agora.
- **As 84 ações rodaram de novo 336 vezes** com o Windows simulado: nenhum erro escapou, e o resultado é o mesmo da R18.
- **As de antes continuam passando:**
  - as 96, 102 e 102 do Desempenho, as 178, 187 e 187 da Limpeza, as 134, 142 e 142 da Segurança e as 212, 224 e 224 do Diagnóstico;
  - as 245, 247 e 252 da Manutenção, com o DISM, o SFC e o CHKDSK do Otimizar, e as 241 do Início;
  - as 83 do QA geral, as 80 da R11 e as 60 da R12;
  - as 59 da R9 e as 52 da R10, as 66 da QA, as 28 da integração e as 26 da R7;
  - o motor de instalação, a atualização simulada e o Setup de verdade (da R18 para esta), e o pacote de suporte;
  - as traduções (5.210/5.210), as 160 referências nos três idiomas e a busca de cada nome;
  - nenhuma chamada com parâmetro que não existe, nenhuma função sem uso e nenhum aviso novo do analisador.

**Falta ver num PC** (entrou no roteiro):
- o CHKDSK num PC com mais de um disco e um externo pela USB, no mesmo tempo de antes;
- Detectar dispositivos com um dispositivo novo ligado;
- o DISM sem internet, se der para provocar;
- a otimização num SSD e num HD.

**Entregue:** `WinForge.zip`, `WinForge-codigo-fonte.zip`, `historico-4.0.md` e `revisao-reparo-4.0.md`.

---

## R20 — As Atualizações com design, Windows e QA

**Data:** 19/11/2026 · **Commit:** d5f7b95

**Pedido:** juntar um Analista de UX/UI Sênior, um Especialista Microsoft (MVP Windows), um QA Sênior e um Engenheiro de Software Sênior para trabalhar na tela e na função de Atualizações:
- o designer revisa cada detalhe da interface e orienta o engenheiro;
- o especialista confere se os comandos e as alterações no Windows são feitos da melhor forma disponível hoje, de modo seguro e robusto, e se fazem sentido e mudam o que devem no PC;
- o QA testa todas as funções da tela;
- o engenheiro aplica as correções.

**O relatório completo** está em `docs/revisao-atualizacoes-4.0.md`: o mapa da página, o que cada olhar viu, cada comando do Windows com o veredito, os testes e as fontes.

**O que mudou**

| Achado | Olhar | Como ficou |
|---|---|---|
| Uma versão nova do Windows vinha marcada na lista de **Instalar atualizações do Windows** quando o Windows Update a oferecia como comum. | MVP e QA | Desmarcada, com "versão nova do Windows" na linha; quem quer mudar de versão, marca. O Otimizar já a deixava de fora. |
| Sem o modo Administrador, **Atualizar aplicativos da Microsoft Store** fazia o pedido que a Microsoft documenta só para um prompt elevado e, na recusa, mostrava um aviso. | MVP e QA | Sem Administrador, a página de atualizações da Store abre direto, com "Clique em Obter atualizações". |
| As páginas da HP e do NVIDIA App abriam em português em qualquer idioma. | MVP e QA | A da HP escolhe o país e o idioma sozinha; a do NVIDIA App vai no idioma da tela. |
| Em inglês e em espanhol, o título de **Atualizar drivers** aparecia em português. | QA | Traduzido. |
| Em inglês, abrir a página de um fabricante dizia "Opening Open the NVIDIA App page in the browser." | QA | Cada ferramenta tem, no catálogo, o que abre, já traduzido. |
| O tempo esgotado das atualizações e dos drivers dava "Concluído com ressalvas", e a falta de espaço no disco, uma faixa sem botão. | Designer e QA | "O WinForge parou de acompanhar", com o botão "Ver o andamento"; a falta de espaço traz "Liberar espaço". |
| As falhas das **Ferramentas do fabricante** e a recusa da Store davam a faixa genérica; a ferramenta instalada não dizia como abrir. | Designer e QA | "O navegador não abriu", "A Microsoft Store não abriu", "A indicação pode estar incompleta", "A Microsoft Store não aceitou o pedido" e "Dell Command \| Update está instalado", cada um com o que fazer. |
| No **Corrigir o Windows Update**, "o serviço Serviço de Transferência..." nos três idiomas, e as falhas com a faixa genérica. | Designer e QA | Os nomes sem "Serviço" e uma faixa para cada caso: o serviço removido (com a Recuperação), sem responder (com o Reparar o Windows), desativado, que não parou, que não ligou de novo e o cache refeito em parte. |

**Conferido e mantido**, com o motivo no relatório:
- **o Corrigir o Windows Update com os passos da Microsoft** (parar os serviços, pôr de lado o DataStore, o Download e o catroot2, ligar de novo), sem apagar a fila do BITS, trocar as permissões dos serviços, registrar DLLs ou mexer no Winsock;
- **as políticas não mudam**, e o Windows Update Medic não é mexido;
- **os drivers pelo Windows Update primeiro**, com ponto de restauração antes e os opcionais desmarcados;
- **o winget atualizando um programa por vez**, com o Instalador de Aplicativo por último.

**Por dentro**
- **WindowsUpdate.psm1:** a versão nova do Windows desmarcada; `Set-WinForgeUpdateTimeoutView` (nova); a falta de espaço em `Get-WinForgeUpdateFixStep`; os nomes dos serviços e as faixas do Corrigir o Windows Update.
- **Drivers.psm1:** o título traduzido; o campo `Target`, a HP sem país fixo e o NVIDIA App no idioma da tela no catálogo; as faixas das Ferramentas do fabricante.
- **Software.psm1:** a Microsoft Store sem o modo Administrador e a faixa da recusa.
- **Traduções:** 38 novas e 4 que saíram de uso, 5.244 ao todo.

**Conferido na nuvem**
- **As conferências novas das Atualizações, todas passando:** 110 em português e 117 em inglês e em espanhol.
  - Instalar atualizações do Windows em 16 situações e Atualizar drivers em 6.
  - As Ferramentas do fabricante em 7, com Dell, Lenovo, HP, NVIDIA, um fabricante desconhecido e o Windows sem responder.
  - O Corrigir o Windows Update em 12, com as pastas do cache de verdade e uma que aponta para outro lugar.
  - O winget em 5 e a Microsoft Store em 5.
  - A página e os textos nos três idiomas.

  Cada conferência das correções falha no código de antes e passa no de agora.
- **As 84 ações rodaram de novo 336 vezes** com o Windows simulado: nenhum erro escapou, e o resultado é o mesmo da R19.
- **As de antes continuam passando:**
  - as 112, 119 e 119 do Reparo, as 96, 102 e 102 do Desempenho, as 178, 187 e 187 da Limpeza, as 134, 142 e 142 da Segurança e as 212, 224 e 224 do Diagnóstico;
  - as 245, 247 e 252 da Manutenção, com o Windows Update e a Store do Otimizar, e as 241 do Início. A conferência antiga da Store recusada, pedida sozinha, passou a rodar com Administrador: sem ele, a tela agora nem faz o pedido;
  - as 83 do QA geral, as 80 da R11 e as 60 da R12;
  - as 59 da R9 e as 52 da R10, as 66 da QA, as 28 da integração e as 26 da R7;
  - o motor de instalação, a atualização simulada e o Setup de verdade (da R19 para esta), e o pacote de suporte;
  - as traduções (5.244/5.244), as 159 referências nos três idiomas (a frase do tempo esgotado dos drivers agora é a mesma das atualizações) e a busca de cada nome;
  - nenhuma chamada com parâmetro que não existe, nenhuma função sem uso e nenhum aviso novo do analisador.

**Falta ver num PC** (entrou no roteiro):
- **Atualizar aplicativos da Microsoft Store** com o WinForge aberto sem o modo Administrador;
- uma versão nova do Windows oferecida, desmarcada na lista;
- as páginas da HP e do NVIDIA App com a tela em inglês;
- o **Corrigir o Windows Update** num PC sem problema e, se houver um, com um serviço desativado.

**Entregue:** `WinForge.zip`, `WinForge-codigo-fonte.zip`, `historico-4.0.md` e `revisao-atualizacoes-4.0.md`.

---

## R21 — Os Programas com design, Windows e QA

**Data:** 19/11/2026 · **Commit:** 12f1e57

**Pedido:** juntar um Analista de UX/UI Sênior, um Especialista Microsoft (MVP Windows), um QA Sênior e um Engenheiro de Software Sênior para trabalhar na tela e na função de Programas:
- o designer revisa cada detalhe da interface e orienta o engenheiro;
- o especialista confere se os comandos e as alterações no Windows são feitos da melhor forma disponível hoje, de modo seguro e robusto, e se fazem sentido e mudam o que devem no PC;
- o QA testa todas as funções da tela;
- o engenheiro aplica as correções.

**O relatório completo** está em `docs/revisao-programas-4.0.md`: o mapa da página, o que cada olhar viu, cada comando do Windows com o veredito, os testes e as fontes.

**O que mudou**

| Achado | Olhar | Como ficou |
|---|---|---|
| A restauração reinstalava os programas sem `--ignore-versions`: uma lista com versões faria o winget procurar as de antes. | MVP e QA | Com `--ignore-versions`: sempre a versão atual. |
| O antigo aplicativo do Office aparecia como "Microsoft 365 (atalho)", um nome que o Windows não mostra desde 2025. | MVP e QA | "Microsoft 365 Copilot (antigo Office)", com a descrição dos nomes que ele pode ter. |
| O Windows Sandbox dizia "só nas edições Pro e Enterprise", sem a Education. | MVP e QA | Com a Education, como a Microsoft lista. |
| Em inglês e em espanhol, a pergunta de ligar ou desligar um recurso começava em português ("Ligar SMB 1.0 file sharing?"). | QA | A pergunta inteira por idioma. |
| Nada instalado, desinstalado, removido ou ligado, a falta do winget, a busca sem resultado e a busca que falha davam a faixa genérica. | Designer e QA | Uma faixa para cada caso, com o nome e o motivo: "O programa não foi instalado", "Falta o Instalador de Aplicativo", "Nenhum programa encontrado", "O aplicativo não foi removido", "O recurso não mudou"… |
| O backup com ressalvas não dizia onde a pasta ficou; sem nada salvo, e a restauração com ressalvas ou sem nada, a faixa era genérica. | Designer e QA | "Backup salvo em parte", com onde está; "O backup não foi salvo"; "Backup restaurado em parte"; "Nada foi restaurado". |
| Os recursos que só terminam ao reiniciar não ofereciam o reinício. | Designer e QA | O reinício oferecido, com Não como padrão, como nas Atualizações. |
| Na restauração, a escolha do backup começava em Cancelar. | Designer e QA | O mais novo em destaque e como padrão; o que restaurar e a confirmação vêm depois. |
| Em inglês, "2 installed programs" ao lado de "1 program installed", e "7-Zip already is installed". | Designer | "2 programs installed" e "7-Zip is installed already". |

**Conferido e mantido**, com o motivo no relatório:
- **o winget um programa por vez**, só da fonte winget nos essenciais, e o desinstalar conferido pela lista;
- **o Edge, o Visual C++, o .NET e o WebView2 fora do desinstalar;**
- **os aplicativos do Windows removidos só para a conta de quem usa**, de uma lista curta, com os aposentados avisados;
- **o SMB 1.0 e o PowerShell 2.0 com o aviso e a pergunta no Não;**
- **o backup sem os arquivos pessoais**, com o LEIA-ME e o aviso das senhas do Wi-Fi.

**Por dentro**
- **Software.psm1:** `Get-WinForgeWingetMissingResult` (nova), também nas Ferramentas do fabricante (Drivers.psm1); o motivo do primeiro que falhou em `Invoke-WinForgeWingetPackages`; as faixas de `Set-WinForgeWingetPackagesView` e da busca.
- **PreinstalledApps.psm1:** o nome do Microsoft 365 Copilot e a faixa de nada removido.
- **WindowsFeatures.psm1:** a pergunta pela tradução, o Windows Sandbox, a faixa de nada mudado e o reinício oferecido.
- **Backup.psm1:** as faixas do backup e da restauração, o backup mais novo em destaque e o `--ignore-versions`.
- **Traduções:** 30 novas, 3 que saíram de uso e 2 corrigidas em inglês, 5.271 ao todo.

**Conferido na nuvem**
- **As conferências novas dos Programas, todas passando:** 106 em português e 115 em inglês e em espanhol.
  - Os essenciais em 7 situações, a busca em 5, a lista em 3 e o desinstalar em 6.
  - Remover aplicativos em 6 e os recursos opcionais em 7.
  - O backup em 6, com a pasta e os arquivos de verdade, e a restauração em 6.
  - A página, os catálogos e os textos nos três idiomas.

  Cada conferência das correções falha no código de antes e passa no de agora.
- **As 84 ações rodaram de novo 336 vezes** com o Windows simulado: nenhum erro escapou, e o resultado é o mesmo da R20, fora as faixas novas.
- **As de antes continuam passando:**
  - as 110, 117 e 117 das Atualizações, as 112, 119 e 119 do Reparo, as 96, 102 e 102 do Desempenho, as 178, 187 e 187 da Limpeza, as 134, 142 e 142 da Segurança e as 212, 224 e 224 do Diagnóstico;
  - as 245, 247 e 252 da Manutenção, com o desinstalar, os aplicativos e o winget do Otimizar, e as 241 do Início;
  - as 83 do QA geral, as 80 da R11 e as 60 da R12;
  - as 59 da R9 e as 52 da R10, as 66 da QA, as 28 da integração e as 26 da R7;
  - o motor de instalação, a atualização simulada e o Setup de verdade (da R20 para esta), e o pacote de suporte;
  - as traduções (5.271/5.271), as 159 referências nos três idiomas e a busca de cada nome;
  - nenhuma chamada com parâmetro que não existe, nenhuma função sem uso e nenhum aviso novo do analisador.

**Falta ver num PC** (entrou no roteiro):
- restaurar um backup num Windows recém-instalado, com o `winget import` novo;
- ligar o Windows Sandbox (numa edição Pro), com o reinício oferecido e a pergunta em inglês;
- o Microsoft 365 Copilot na lista de Remover aplicativos;
- um backup com o Wi-Fi desligado.

**Entregue:** `WinForge.zip`, `WinForge-codigo-fonte.zip`, `historico-4.0.md` e `revisao-programas-4.0.md`.

---

## R22 — A Rede com design, Windows e QA

**Data:** 19/11/2026 · **Commit:** 48c0bbd

**Pedido:** juntar um Analista de UX/UI Sênior, um Especialista Microsoft (MVP Windows), um QA Sênior e um Engenheiro de Software Sênior para trabalhar na tela e na função de Rede:
- o designer revisa cada detalhe da interface e orienta o engenheiro;
- o especialista confere se os comandos e as alterações no Windows são feitos da melhor forma disponível hoje, de modo seguro e robusto, e se fazem sentido e mudam o que devem no PC;
- o QA testa todas as funções da tela;
- o engenheiro aplica as correções.

**O relatório completo** está em `docs/revisao-rede-4.0.md`: o mapa da página, o que cada olhar viu, cada comando do Windows com o veredito, os testes e as fontes.

**O que mudou**

| Achado | Olhar | Como ficou |
|---|---|---|
| Um IP fixo em qualquer adaptador (o do VirtualBox, o do WSL) tirava do reparo a renovação do IP de todos, embora o `ipconfig /release` e o `/renew` só mexam nos adaptadores automáticos. | MVP e QA | Eles rodam quando há um adaptador automático conectado; só o reset de TCP/IP sai, com o aviso de qual adaptador tem IP fixo. |
| Pela Área de Trabalho Remota ou com uma VPN, o reparo não avisava antes da pergunta; na Manutenção, com a internet fora, rodava inteiro mesmo assim. | MVP e QA | O aviso antes da pergunta; na Manutenção, só o DNS é limpo, com o motivo. |
| Num PC de domínio, a troca do DNS deixava um DNS público em destaque. | MVP e QA | O aviso de que o DNS da empresa deve ficar, e nada em destaque. |
| No Windows PowerShell 5.1, o ping contava como recebidos os pacotes perdidos (`StatusCode` 11010). | MVP e QA | Só o `StatusCode` 0 conta. |
| O upload media junto o tempo de abrir a conexão. | MVP e QA | A conexão abre antes do relógio, como no download. |
| "Fixo:" em português nas telas em inglês e em espanhol; um aviso do reparo começando em minúscula em inglês. | QA | Traduzido; a frase começa em maiúscula. |
| Sem rede, sem medição, sem senha a mostrar, o reparo que não funciona ou funciona em parte, a troca do DNS em parte ou sem volta e o desfazer em parte davam a faixa genérica. | Designer e QA | Uma faixa para cada caso, com o botão do que resolve quando há um: "Nenhuma rede conectada", "Não foi possível medir a velocidade", "Academia não tem senha", "O reparo não funcionou", "O DNS de antes não voltou"… |
| O tipo de rede só como "Pública" ou "Privada"; na Senha do Wi-Fi, a primeira rede em destaque mesmo sem estar conectada. | Designer e QA | O tipo explicado, como o Windows explica; o destaque só na rede conectada. |
| Com o Windows dizendo que há internet (uma rede com proxy), o reparo dizia logo abaixo "o reparo é indicado". | Designer e QA | "Os testes diretos falharam, mas o Windows informa acesso à internet (…): só continue se os sites não abrirem." |

**Conferido e mantido**, com o motivo no relatório:
- **os comandos do reparo**, os que a Microsoft indica, com o reset de TCP/IP de fora diante de IP ou DNS fixo e com Não como padrão;
- **os endereços IPv4 e IPv6 dos quatro provedores de DNS**, conferidos nas páginas deles, e o filtro para famílias nunca em destaque;
- **a troca do DNS com backup por família**, que volta sozinha quando o novo não resolve nomes;
- **a senha do Wi-Fi** lida como XML numa pasta temporária apagada na hora, só na tela;
- **o relatório de Wi-Fi** aberto pelo Explorador, sem a elevação.

**Por dentro**
- **Network.psm1:** `Get-WinForgePingStats` conta só o `StatusCode` 0; `Get-WinForgeStaticIpConfiguration` devolve `Dhcp`, e `Get-WinForgeNetworkRepairCommands` ganha `-NoDhcp`; os avisos, a Manutenção e as faixas de `Invoke-WinForgeNetworkRepair`; `Measure-WinForgeUpload -WarmupUrl`; `Set-WinForgeSpeedFailureView` (nova); o tipo de rede e a faixa de `Show-WinForgeNetworkInfo` sem rede.
- **NetworkTools.psm1:** "Fixo:" pela tradução; o PC de domínio e as faixas de `Set-WinForgeDnsProvider`; as faixas de `Undo-WinForgeDnsChange`; as faixas e o destaque de `Show-WinForgeWifiPassword`.
- **Traduções:** 38 novas e 3 que saíram de uso, 5.306 ao todo.

**Conferido na nuvem**
- **As conferências novas da Rede, todas passando:** 144 em português e 153 em inglês e em espanhol.
  - As informações em 8 situações, o ping em 8 (e o do Windows PowerShell 5.1) e a velocidade em 8 (e o upload com um servidor falso).
  - O relatório de Wi-Fi em 3 e a senha do Wi-Fi em 10.
  - O reparo em 16, a troca do DNS em 11 e o desfazer em 5.
  - A página, os provedores e os textos nos três idiomas.

  Cada conferência das correções falha no código de antes e passa no de agora.
- **As 84 ações rodaram de novo 336 vezes** com o Windows simulado: nenhum erro escapou, e o resultado é o mesmo da R21, fora as faixas novas.
- **As de antes continuam passando:**
  - as 106, 115 e 115 dos Programas, as 110, 117 e 117 das Atualizações, as 112, 119 e 119 do Reparo, as 96, 102 e 102 do Desempenho, as 178, 187 e 187 da Limpeza, as 134, 142 e 142 da Segurança e as 212, 224 e 224 do Diagnóstico;
  - as 245, 247 e 252 da Manutenção, com o reparo de rede do Otimizar, e as 241 do Início;
  - as 83 do QA geral, as 80 da R11 e as 60 da R12;
  - as 59 da R9 e as 52 da R10, as 66 da QA, as 28 da integração e as 26 da R7;
  - o motor de instalação, a atualização simulada e o Setup de verdade (da R21 para esta), e o pacote de suporte;
  - as traduções (5.306/5.306), as 159 referências nos três idiomas e a busca de cada nome;
  - nenhuma chamada com parâmetro que não existe, nenhuma função sem uso e nenhum aviso novo do analisador.

**Falta ver num PC** (entrou no roteiro):
- reparar a rede num PC com VirtualBox ou WSL, com o IP do adaptador virtual mantido;
- reparar pela Área de Trabalho Remota, com o aviso antes da pergunta;
- trocar o DNS num PC de domínio;
- o upload numa internet rápida e o teste de conectividade numa rede sem internet;
- o tipo de rede explicado e a faixa sem rede nas Informações de rede.

**Entregue:** `WinForge.zip`, `WinForge-codigo-fonte.zip`, `historico-4.0.md` e `revisao-rede-4.0.md`.

---

## R23 — Os Ajustes do Windows com design, Windows e QA

**Data:** 19/11/2026 · **Commit:** 63b6f81

**Pedido:** juntar um Analista de UX/UI Sênior, um Especialista Microsoft (MVP Windows), um QA Sênior e um Engenheiro de Software Sênior para trabalhar na tela e na função de Ajustes do Windows:
- o designer revisa cada detalhe da interface e orienta o engenheiro;
- o especialista confere se os comandos e as alterações no Windows são feitos da melhor forma disponível hoje, de modo seguro e robusto, e se fazem sentido e mudam o que devem no PC;
- o QA testa todas as funções da tela;
- o engenheiro aplica as correções.

**O relatório completo** está em `docs/revisao-ajustes-4.0.md`: o mapa da página, o que cada olhar viu, cada ajuste com o veredito, os testes e as fontes.

**O que mudou**

| Achado | Olhar | Como ficou |
|---|---|---|
| Antes de aplicar os recomendados, um perfil ou um arquivo importado, um ponto de restauração de horas atrás (de uma atualização do Windows) contava como a rede de segurança, e nenhum ponto novo era criado; voltar a ele desfaria também o que mudou depois. | MVP e QA | O ponto é criado agora, como no começo do Otimizar e no ponto pedido sozinho: o limite de um por dia fica em 0 só durante a criação. |
| A chave do Recall aparecia nos Windows 11 22H2 e 23H2, que não têm o Recall. | MVP e QA | Só da build 26100 (24H2) em diante. |
| "notebook:" em português na revisão do Otimizar em inglês e em espanhol; "Documentos\WinForge" em português na faixa da exportação. | QA | O aviso vai como está, no idioma da tela; a pasta, pela tradução. |
| A chave que não mudava nada (uma política impondo o valor, acesso negado, a configuração protegida) terminava em "Concluído com ressalvas" ou "Não foi concluído". | Designer e QA | "ID de publicidade: nada mudou", com o motivo legível no idioma da tela. |
| A chave oferecia reiniciar o Explorador mesmo sem nada mudado; com o Explorador que não reiniciava, a faixa não dizia que o ajuste tinha sido feito. | Designer e QA | A pergunta só vem quando o ajuste mudou; "Mostrar arquivos e pastas ocultos: ativado", com quando a mudança aparece (também no lote e no Desfazer). |
| Nenhum ajuste aplicado ("0 ajustes aplicados, 4 com problema"), os recomendados ou o perfil já aplicados, nada a exportar, o arquivo não importado e nada desfeito davam a faixa genérica. | Designer e QA | Uma faixa para cada caso: "Nenhum ajuste foi aplicado", "Os ajustes recomendados já estão aplicados", "O perfil Essencial já está aplicado", "Nenhum ajuste para exportar", "O arquivo não foi importado", "Nenhum ajuste foi desfeito"… |
| O aviso do notebook dito duas vezes ("Atenção em notebook: Em notebook, …"; "[notebook: Em notebook, …]"), e o Alto desempenho dizendo "em notebook reduz a autonomia" num PC de mesa. | Designer e QA | O aviso uma vez só; a descrição vale para qualquer PC. |

**Conferido e mantido**, com o motivo no relatório:
- **cada ajuste grava o que as Configurações gravam** ou, em quatro, a política do Windows, e a chave deles diz "Permitir";
- **o `DODownloadMode` 0** para não compartilhar atualizações, o que a Microsoft indica (o 100, obsoleto no Windows 11, nunca é gravado);
- **desfazer não passa por cima de uma escolha mais nova**, e cada chave volta o registro e os planos de energia exatamente ao que eram;
- **o menu de contexto clássico**, a forma conhecida, só no perfil do usuário e desfeita por inteiro;
- **as teclas do idioma do teclado**, como texto, com o Windows avisado.

**Por dentro**
- **Tweaks.psm1:** o ponto com `-IgnoreFrequency` e as faixas de `Invoke-WinForgeTweakBatch`; as faixas de "nada mudou" e o Explorador só quando algo mudou em `Invoke-WinForgeTweakToggle`; as faixas dos recomendados, dos perfis, da exportação, da importação e do Desfazer; `Format-WinForgeTweakExportFolder` (nova); o aviso do notebook sem rótulo em `Read-WinForgeTweakSelection` e `Get-WinForgeTweakReviewText`; o Recall com `-MinBuild 26100`; a descrição do Alto desempenho.
- **WinForge.Gui.ps1:** o aviso do notebook na chave vai como está.
- **Traduções:** 17 novas e 3 que saíram de uso, 5.320 ao todo.

**Conferido na nuvem**
- **As conferências novas dos Ajustes do Windows, todas passando:** 412 em português e 422 em inglês e em espanhol.
  - A página e o catálogo, e o que aparece no Windows 10, no 11 23H2 e no 11 24H2.
  - As 34 chaves, uma a uma: o valor gravado contra o documentado e a volta exata do registro e dos planos de energia.
  - A chave em 13 casos de borda, os recomendados em 6, os perfis em 3, o ponto de restauração em 5, exportar e importar em 6, o Desfazer em 5 e as teclas do idioma em 6.
  - A revisão do Otimizar num notebook e os textos nos três idiomas.

  Cada conferência das correções falha no código de antes e passa no de agora.
- **As 84 ações rodaram de novo 336 vezes** com o Windows simulado: nenhum erro escapou, e o resultado é o mesmo da R22, fora as faixas novas.
- **As de antes continuam passando:**
  - as 144, 153 e 153 da Rede, as 106, 115 e 115 dos Programas, as 110, 117 e 117 das Atualizações, as 112, 119 e 119 do Reparo, as 96, 102 e 102 do Desempenho, as 178, 187 e 187 da Limpeza, as 134, 142 e 142 da Segurança e as 212, 224 e 224 do Diagnóstico;
  - as 245, 247 e 252 da Manutenção, com a revisão dos ajustes do Otimizar, e as 241 do Início;
  - as 83 do QA geral, as 80 da R11 e as 60 da R12;
  - as 59 da R9 e as 52 da R10, as 66 da QA, as 28 da integração e as 26 da R7;
  - o motor de instalação, a atualização simulada e o Setup de verdade (da R22 para esta), e o pacote de suporte;
  - as traduções (5.320/5.320), as 159 referências nos três idiomas e a busca de cada nome;
  - nenhuma chamada com parâmetro que não existe, nenhuma função sem uso e nenhum aviso novo do analisador.

**Falta ver num PC** (entrou no roteiro):
- aplicar os recomendados num PC com um ponto de restauração do mesmo dia: um ponto novo aparece;
- uma chave que uma política impede, num PC da empresa;
- o Recall num 23H2 (sem a chave) e num 24H2 Copilot+;
- o aviso de bateria uma vez só, num notebook;
- a exportação, com "Documentos\WinForge".

**Entregue:** `WinForge.zip`, `WinForge-codigo-fonte.zip`, `historico-4.0.md` e `revisao-ajustes-4.0.md`.

---

## R24 — A Personalização com design, Windows e QA

**Data:** 19/11/2026 · **Commit:** 915c697

**Pedido:** juntar um Analista de UX/UI Sênior, um Especialista Microsoft (MVP Windows), um QA Sênior e um Engenheiro de Software Sênior para trabalhar na tela e na função de Personalização:
- o designer revisa cada detalhe da interface e orienta o engenheiro;
- o especialista confere se os comandos e as alterações no Windows são feitos da melhor forma disponível hoje, de modo seguro e robusto, e se fazem sentido e mudam o que devem no PC;
- o QA testa todas as funções da tela;
- o engenheiro aplica as correções.

**O relatório completo** está em `docs/revisao-personalizacao-4.0.md`: o mapa da página, o que cada olhar viu, cada ajuste com o veredito, os testes e as fontes.

**O que mudou**

| Achado | Olhar | Como ficou |
|---|---|---|
| As linhas Cor de destaque e Teclas que trocam o idioma do teclado não diziam o estado de agora, enquanto as chaves dizem. | Designer e QA | "Agora: Azul" e "Agora: Alt + Shift e Ctrl + Shift", com a frase inteira na dica. |
| Com o Explorador que não reiniciava depois de trocar a cor, a faixa dizia só "Concluído com ressalvas"; a troca que falhava, "Não foi concluído". | Designer e QA | "Cor de destaque: Verde", com quando o Iniciar e a barra mudam; "A cor de destaque não mudou", com o motivo legível. |
| A cor automática perguntava se reiniciava o Explorador, embora ela só mude com o papel de parede. | MVP e QA | A pergunta só vem com uma das oito cores escolhida. |
| A cor no Iniciar e na barra dizia "só funciona com o modo escuro"; a Microsoft diz que basta o modo do Windows escuro (ou o personalizado). | MVP | "…; só com o Windows no modo escuro." |

**Conferido e mantido**, com o motivo no relatório:
- **cada chave grava o que as Configurações gravam**, com os programas avisados nas das cores e o Explorador oferecido nas da barra e da área de trabalho;
- **os Widgets pela política do computador** (`AllowNewsAndInterests`), a forma documentada, com o botão da barra protegido pelo Windows;
- **clima e notícias na tela de bloqueio pelo valor do usuário**, porque a política da Microsoft só vale no Windows Insider;
- **a cor de destaque** com a escolha automática gravada por último, para uma falha no meio não desligar a automática de quem a usava;
- **o que o Windows protege** (a pesquisa e os Widgets) não é forçado: a tela diz onde mudar.

**Por dentro**
- **Tweaks.psm1:** `Get-WinForgeTweakActionState` (nova); o Explorador só com uma cor escolhida e as faixas de `Set-WinForgeAccentColor`; a descrição da cor no Iniciar e na barra de tarefas.
- **WinForge.Gui.ps1:** o estado de agora nas linhas de ação, em `Update-GuiTweaksList`.
- **Traduções:** 4 novas e 1 que saiu de uso, 5.323 ao todo.

**Conferido na nuvem**
- **As conferências novas da Personalização, todas passando:** 265 em português e 270 em inglês e em espanhol.
  - A página e o catálogo, e o que aparece no Windows 11 24H2, 23H2 e 22H2 e no Windows 10.
  - As 18 chaves, uma a uma: o valor gravado e a volta exata do registro.
  - A chave em 9 casos de borda, a cor de destaque em 21 situações (as oito cores conferidas em hexadecimal), os perfis e um lote.
  - Os textos nos três idiomas.

  Cada conferência das correções falha no código de antes e passa no de agora.
- **As 84 ações rodaram de novo 336 vezes** com o Windows simulado: nenhum erro escapou, e o resultado é o mesmo da R23, fora a faixa nova da cor de destaque que falha.
- **As de antes continuam passando:**
  - as 412, 422 e 422 dos Ajustes do Windows, as 144, 153 e 153 da Rede, as 106, 115 e 115 dos Programas, as 110, 117 e 117 das Atualizações, as 112, 119 e 119 do Reparo, as 96, 102 e 102 do Desempenho, as 178, 187 e 187 da Limpeza, as 134, 142 e 142 da Segurança e as 212, 224 e 224 do Diagnóstico;
  - as 245, 247 e 252 da Manutenção e as 241 do Início;
  - as 83 do QA geral, as 80 da R11 e as 60 da R12;
  - as 59 da R9 e as 52 da R10, as 66 da QA, as 28 da integração e as 26 da R7;
  - o motor de instalação, a atualização simulada e o Setup de verdade (da R23 para esta), e o pacote de suporte;
  - as traduções (5.323/5.323), as 159 referências nos três idiomas e a busca de cada nome;
  - nenhuma chamada com parâmetro que não existe, nenhuma função sem uso e nenhum aviso novo do analisador.

**Falta ver num PC** (entrou no roteiro):
- a linha da cor de destaque com a cor de agora, e a das teclas do idioma;
- a cor automática sem a pergunta do Explorador;
- uma cor escolhida com o modo escuro e a cor na barra ligados;
- a cor no Iniciar e na barra com o modo personalizado.

**Entregue:** `WinForge.zip`, `WinForge-codigo-fonte.zip`, `historico-4.0.md` e `revisao-personalizacao-4.0.md`.

---

## R25 — O Sobre o WinForge com design, Windows e QA

**Data:** 20/11/2026 · **Commit:** 7f66851

**Pedido:** juntar um Analista de UX/UI Sênior, um Especialista Microsoft (MVP Windows), um QA Sênior e um Engenheiro de Software Sênior para trabalhar na tela e na função Sobre o WinForge:
- o designer revisa cada detalhe da interface e orienta o engenheiro;
- o especialista confere se os comandos e as alterações no Windows são feitos da melhor forma disponível hoje, de modo seguro e robusto, e se fazem sentido e mudam o que devem no PC;
- o QA testa todas as funções da tela;
- o engenheiro aplica as correções.

**O relatório completo** está em `docs/revisao-sobre-4.0.md`: o mapa da página, o que cada olhar viu, cada ajuste com o veredito, os testes e as fontes.

**O que mudou**

| Achado | Olhar | Como ficou |
|---|---|---|
| Criar atalho ficava sempre em destaque, mesmo com o atalho pronto, e no meio da página, longe do resumo e fora do grupo dele. | Designer | Em destaque logo abaixo do resumo só quando falta o atalho (ou ele abre outra pasta); com o atalho pronto, é uma linha de Integração com o Windows. |
| Versão e pastas dizia "Instalado em" também numa cópia só extraída. | Designer | "Pasta do WinForge", e a descrição sem "instalada". |
| Criar atalho terminava em faixas genéricas ("Não foi concluído: atalho não criado"). | Designer e QA | "O atalho não foi criado", "O atalho já existe" e "Atalho criado só na Área de Trabalho", com o motivo de cada lugar. |
| Verificar nova versão tinha 12 desfechos com a faixa genérica. | Designer e QA | Um título por desfecho, com a versão ("Versão 4.1 disponível", "A versão 4.1 não foi baixada"...), e o motivo ou o que fazer na frase. |
| As falhas do pacote de suporte, do monitor, dos dados online e do idioma, e Versão e pastas sem o ícone, tinham a faixa genérica. | Designer e QA | O título diz o que não aconteceu ("O monitor não foi ligado"); a frase, o porquê. |
| O pacote de suporte dizia levar os históricos mesmo sem nenhum, e contava logs que ficaram de fora do zip. | QA | A linha Leva diz só o que entrou no zip, com "preferências" à parte. |

**Conferido e mantido**, com o motivo e as fontes no relatório:
- **o atalho** com o identificador da barra de tarefas no `.lnk`, o mesmo da janela, como a Microsoft pede;
- **o monitor** pela entrada em Run do usuário, com o limite de 260 letras que a Microsoft documenta;
- **a nova versão** só baixada com o SHA-256 que o GitHub publica, e só da última versão que não é rascunho nem pré-lançamento;
- **o pacote de suporte** sem backups nem senhas;
- **com a conta de outro Administrador,** nada vai para o perfil errado.

**Por dentro**
- **Launcher.psm1:** `Test-WinForgeAppShortcutNeeded` (nova); "Pasta do WinForge"; as faixas de Criar atalho, do ícone que falta e do idioma.
- **WinForge.Gui.ps1:** o destaque do Sobre o WinForge em `Show-GuiListPage`.
- **AppUpdate.psm1, Reports.psm1, Agent.psm1, Catalog.psm1:** as faixas de Verificar nova versão, do pacote de suporte, do monitor e dos dados online; a linha Leva.
- **Console.psm1:** `Format-WinForgeReasonNote` (nova). **Navigation.psm1:** a descrição de Versão e pastas.
- **Traduções:** 27 novas e 4 que saíram de uso, 5.346 ao todo.

**Conferido na nuvem**
- **As conferências novas do Sobre o WinForge, todas passando:** 164 em português e 169 em inglês e em espanhol.
  - A página, o resumo do alto em 12 situações e o desenho da página na janela.
  - Criar atalho em 24 situações, Verificar nova versão em 21 e o monitor em 17.
  - O pacote de suporte em 6, com um zip de verdade, os dados online, o idioma e a pasta de logs.
  - Os textos nos três idiomas.

  Cada conferência das correções falha no código de antes e passa no de agora.
- **As 84 ações rodaram de novo 336 vezes** com o Windows simulado: nenhum erro escapou. O resultado é o mesmo da R24, fora as faixas novas de Verificar nova versão, de Criar atalho e do monitor nos casos que falham.
- **As de antes continuam passando:**
  - as 265, 270 e 270 da Personalização, as 412, 422 e 422 dos Ajustes do Windows, as 144, 153 e 153 da Rede, as 106, 115 e 115 dos Programas, as 110, 117 e 117 das Atualizações, as 112, 119 e 119 do Reparo, as 96, 102 e 102 do Desempenho, as 178, 187 e 187 da Limpeza, as 134, 142 e 142 da Segurança e as 212, 224 e 224 do Diagnóstico;
  - as 245, 247 e 252 da Manutenção e as 241 do Início;
  - as 83 do QA geral, as 80 da R11 e as 60 da R12;
  - as 59 da R9 e as 52 da R10, as 66 da QA, as 28 da integração e as 26 da R7;
  - o motor de instalação, a atualização simulada e o Setup de verdade (da R24 para esta), e o pacote de suporte;
  - as traduções (5.346/5.346), as 159 referências nos três idiomas e a busca de cada nome;
  - nenhuma chamada com parâmetro que não existe, nenhuma função sem uso e nenhum aviso novo do analisador.

**Falta ver num PC** (entrou no roteiro):
- o destaque de Criar atalho antes e depois de criar o atalho;
- a Pasta do WinForge em Versão e pastas;
- Criar atalho numa cópia instalada;
- Verificar nova versão sem internet;
- a linha Leva e o conteúdo do pacote de suporte.

**Entregue:** `WinForge.zip`, `WinForge-codigo-fonte.zip`, `historico-4.0.md` e `revisao-sobre-4.0.md`.

---

## R26 — A Busca com design, Windows e QA

**Data:** 20/11/2026 · **Commit:** c624773

**Pedido:** juntar um Analista de UX/UI Sênior, um Especialista Microsoft (MVP Windows), um QA Sênior e um Engenheiro de Software Sênior para trabalhar na tela e na função de Buscar:
- o designer revisa cada detalhe da interface e orienta o engenheiro;
- o especialista confere se os comandos e as alterações no Windows são feitos da melhor forma disponível hoje, de modo seguro e robusto, e se fazem sentido e mudam o que devem no PC;
- o QA testa todas as funções da tela;
- o engenheiro aplica as correções.

**O relatório completo** está em `docs/revisao-busca-4.0.md`: como a busca acha e pontua, o que cada olhar viu, os testes, a comparação de antes e depois e as fontes.

**O que mudou**

| Achado | Olhar | Como ficou |
|---|---|---|
| Em inglês, a correção de digitação nunca funcionava: a palavra "keys" do índice desmontava o vocabulário dela. | QA | "defnder" vira "defender", como em português e em espanhol. |
| A busca mostrava o que a página tira: a Saúde da bateria num PC sem bateria e as ações do Defender com outro antivírus. | QA | A mesma regra das páginas, com o resumo contando só o que aparece. |
| O Idioma achado na busca abria a pergunta do menu de texto; o cartão Idioma podia mostrar a escolha antiga. | Designer e QA | A busca leva ao cartão, com o foco na escolha; o cartão relê a escolha guardada. |
| "sem espaço", uma das buscas sugeridas, trazia um relatório e o Apagar o espaço livre antes de uma limpeza. | Designer | Limpeza rápida primeiro, nos três idiomas. |
| Os comandos e os nomes do Windows (eventvwr, winver, Visualizador de Eventos, Restaurar PC, Restablecer este equipo) e os aplicativos que o WinForge remove (Office, Copilot, Outlook) não achavam a tela certa. | MVP | Cada um traz a tela certa primeiro. |
| "about this pc" trazia outra página; "desinstalar winforge", os restos de programas; e buscas do jeito que a pessoa fala ("desligar a telemetria", "pc lenta", "no hay sonido") achavam só parte das palavras. | QA | A página pelo título só numa busca de uma palavra; as palavras de ligação, os sinônimos de ligar e desligar e o feminino em espanhol. |
| A dica da caixa dizia "vai aos cartões". | Designer | "…vai aos resultados". |

**Conferido e mantido**, com o motivo no relatório:
- **a busca só lê**, e o que ela abre são as ações e os atalhos das páginas;
- **os ajustes na busca são os deste Windows**, pela build;
- **nada roda por um palpite:** numa busca corrigida ou parcial com uma ação em primeiro, o Enter só seleciona;
- **o índice montado uma vez**, com cada tecla em 5 a 20 ms.

**Por dentro**
- **Navigation.psm1:** `Test-WinForgeNavItemHidden` (nova); o Idioma da busca no cartão; o vocabulário com `get_Keys()`; a página pelo título; as palavras de ligação, os sinônimos, os verbos de chave nos ajustes e as palavras-chave de seis itens.
- **WinForge.Gui.ps1:** `Get-GuiHiddenItemState` (nova), a mesma regra em `Show-GuiListPage` e `Show-GuiSearchResults`, o foco no cartão Idioma e o cartão que relê a escolha. **gui/MainWindow.xaml:** a dica da caixa.
- **Traduções:** 8 novas e 7 que saíram de uso, mais três palavras-chave revistas em espanhol; 5.347 ao todo.

**Conferido na nuvem**
- **As conferências novas da Busca, todas passando:** 109 em português, 98 em inglês e 101 em espanhol.
  - O texto digitado, o resumo, o Enter e as teclas.
  - O que vem primeiro em 40 buscas em português, 25 em inglês e 28 em espanhol, e cada nome achando a si mesmo.
  - A tela de resultados com a janela simulada.
  - Os textos nos três idiomas.

  Cada conferência das correções falha no código de antes e passa no de agora.
- **A pontuação, antes e depois,** em 1.355 buscas em português, 1.268 em inglês e 1.362 em espanhol. Em português, mudou o primeiro resultado de 13, e em espanhol, de 14: cada mudança é uma das correções, ou uma busca em outro idioma. Em inglês, de 25: as correções e buscas em português ou espanhol que agora passam pela correção de digitação.
- **As 84 ações rodaram de novo 336 vezes** com o Windows simulado: nenhum erro escapou, e o resultado é o mesmo da R25.
- **As de antes continuam passando:**
  - as 164, 169 e 169 do Sobre o WinForge (a simulação da página passou a carregar a função nova da janela);
  - as 265, 270 e 270 da Personalização, as 412, 422 e 422 dos Ajustes do Windows, as 144, 153 e 153 da Rede, as 106, 115 e 115 dos Programas, as 110, 117 e 117 das Atualizações, as 112, 119 e 119 do Reparo, as 96, 102 e 102 do Desempenho, as 178, 187 e 187 da Limpeza, as 134, 142 e 142 da Segurança e as 212, 224 e 224 do Diagnóstico;
  - as 245, 247 e 252 da Manutenção e as 241 do Início;
  - as 83 do QA geral, as 80 da R11 e as 60 da R12;
  - as 59 da R9 e as 52 da R10, as 66 da QA, as 28 da integração e as 26 da R7;
  - o motor de instalação, a atualização simulada e o Setup de verdade (da R25 para esta), e o pacote de suporte;
  - as traduções (5.347/5.347), as 159 referências nos três idiomas e a busca de cada nome;
  - nenhuma chamada com parâmetro que não existe, nenhuma função sem uso e nenhum aviso novo do analisador.

**Falta ver num PC** (entrou no roteiro):
- o Idioma pela busca, com o foco no cartão;
- a busca num PC de mesa e com outro antivírus;
- a busca em inglês com um erro de digitação;
- a sugestão "sem espaço";
- o cartão Idioma depois de mudar o idioma pelo menu de texto.

**Entregue:** `WinForge.zip`, `WinForge-codigo-fonte.zip`, `historico-4.0.md` e `revisao-busca-4.0.md`.

---

## R27 — O Verificar o PC com design, Windows e QA

**Data:** 20/11/2026 · **Commit:** e94042f

**Pedido:** juntar um Analista de UX/UI Sênior, um Especialista Microsoft (MVP Windows), um QA Sênior e um Engenheiro de Software Sênior para trabalhar na tela e na função Verificar o PC:
- o designer revisa cada detalhe da interface e orienta o engenheiro;
- o especialista confere se os comandos e as alterações no Windows são feitos da melhor forma disponível hoje, de modo seguro e robusto, e se fazem sentido e mudam o que devem no PC;
- o QA testa todas as funções da tela;
- o engenheiro aplica as correções.

**O relatório completo** está em `docs/revisao-verificar-o-pc-4.0.md`: o que cada etapa lê e quando pede atenção, o que cada olhar viu, os testes e as fontes.

**O que mudou**

| Achado | Olhar | Como ficou |
|---|---|---|
| Uma correção que falhava ao lado de outra que funcionava sumia da faixa ("1 correção feita… Nada mais pedindo atenção"). | QA | A faixa diz qual, com o motivo quando é uma só ("Registro: acesso negado."), e o botão leva à tela dela. |
| Com todos os temporários em uso, a limpeza não tirava nada e contava como correção feita. | QA | Não conta: "Temporários: nada foi liberado". |
| Temporários sem leitura viravam "nada acumulado" e "Tudo certo"; sem Administrador, a correção prometia os relatórios de erro. | QA | "não foi possível ler", na linha e na faixa; "Apagar os temporários do usuário". |
| Depois de liberar espaço, o espaço no disco continuava pedindo atenção com a leitura de antes. | QA | O disco é lido de novo; acima do limite, o ponto sai da faixa. |
| No menu de texto, a lista sem resposta válida derrubava a verificação inteira. | QA | É não corrigir nada, com os pontos na faixa. |
| A faixa genérica com uma etapa sem leitura, com todas as correções falhando e com a maior parte sem leitura. | Designer | "Nada pedindo atenção no que foi lido", "Nenhuma correção funcionou" (com o motivo e o botão) e "Não foi possível verificar o PC" (com o que fazer). |
| Um ponto só era dito pelo nome ("Proteção."); a lista longa era cortada no meio, e o nome dos temporários tinha vírgulas. | Designer | "Proteção: antivírus desligado, 2 ameaças ativas e firewall desligado (Rede pública)."; "Temporários"; os três mais importantes e "e mais N". |
| A linha Proteção tinha regra e textos próprios, diferentes da tela Estado da proteção. | MVP | Os mesmos pontos da tela, pelo nome curto de cada um. |
| O botão da faixa ia ao primeiro ponto das etapas (o espaço no disco), mesmo com atualizações de segurança faltando ou um disco falhando. | MVP e designer | Do mais grave ao menos, com os pesos do Início; o botão leva ao primeiro. |
| "falta o winget, da Microsoft Store"; o cache dos navegadores com duas frases; a barra da primeira etapa sem a saúde dos discos; "No fix done". | Designer | "falta o Instalador de Aplicativo (winget)"; uma frase só; "medindo o espaço livre e conferindo a saúde dos discos"; "No fixes done". |

**Conferido e mantido**, com o motivo e as fontes no relatório:
- **os temporários** só com mais de 24 horas, e o cache da Otimização de Entrega pelo comando do Windows, sem os arquivos fixados;
- **os programas desatualizados** pela mesma consulta da tela Atualizar programas, que só lista;
- **o registro** desmarcado, com o backup e o desfazer;
- **o firewall:** o perfil de domínio só conta num PC de empresa;
- **nada muda antes da lista:** a verificação só lê, e cada correção espera a pessoa marcar.

**Por dentro**
- **Checkup.psm1:** `Get-WinForgeCheckupWeight`, `Get-WinForgeCheckupOrder` e `Format-WinForgeCheckupReason` (novas); `Short` nos achados; `Set-WinForgeCheckupView` reescrita; a proteção por `Get-WinForgeSecurityFindings`; os temporários; a limpeza que não tirou nada; o disco lido de novo, a lista sem resposta e o erro com título em `Invoke-WinForgeCheckup`.
- **Traduções:** 8 novas, 11 que saíram de uso e 2 revistas em inglês; 5.344 ao todo.

**Conferido na nuvem**
- **As conferências novas do Verificar o PC, todas passando:** 146 em português e 147 em inglês e em espanhol.
  - Cada leitura, em todas as situações: o disco, os temporários com pastas de verdade, o registro, os atalhos, a memória, a inicialização, o winget, o Windows e a proteção em 12 situações, conferida contra a tela Estado da proteção.
  - A verificação inteira em 28 situações, com o que sai do disco, a Lixeira, o histórico, a faixa e se conta como cuidado com o PC.
  - A faixa e os textos nos três idiomas.

  Cada conferência das correções falha no código de antes e passa no de agora.
- **As 84 ações rodaram de novo 336 vezes** com o Windows simulado: nenhum erro escapou. O resultado é o mesmo da R26, fora o Verificar o PC, que agora põe a Proteção antes do Suporte do Windows e leva o botão a ela.
- **As de antes continuam passando:**
  - as 109, 98 e 101 da Busca e as 164, 169 e 169 do Sobre o WinForge;
  - as 265, 270 e 270 da Personalização, as 412, 422 e 422 dos Ajustes do Windows, as 144, 153 e 153 da Rede, as 106, 115 e 115 dos Programas, as 110, 117 e 117 das Atualizações, as 112, 119 e 119 do Reparo, as 96, 102 e 102 do Desempenho, as 178, 187 e 187 da Limpeza, as 134, 142 e 142 da Segurança e as 212, 224 e 224 do Diagnóstico;
  - as 245, 247 e 252 da Manutenção e as 241 do Início;
  - as 83 do QA geral, as 80 da R11 e as 60 da R12;
  - as 59 da R9 e as 52 da R10, as 66 da QA, as 28 da integração e as 26 da R7;
  - o motor de instalação, a atualização simulada e o Setup de verdade (da R26 para esta), e o pacote de suporte;
  - as traduções (5.344/5.344), as 159 referências nos três idiomas e a busca de cada nome;
  - nenhuma chamada com parâmetro que não existe, nenhuma função sem uso e nenhum aviso novo do analisador.

**Falta ver num PC** (entrou no roteiro):
- a faixa num PC usado, com o botão no ponto mais importante;
- a linha Proteção com o firewall de uma rede desligado;
- liberar espaço com o disco perto do limite;
- os temporários em uso, se acontecer.

**Entregue:** `WinForge.zip`, `WinForge-codigo-fonte.zip`, `historico-4.0.md` e `revisao-verificar-o-pc-4.0.md`.

---

## R28 — O Otimizar com design, Windows e QA

**Data:** 20/11/2026 · **Commit:** 92c60f4

**Pedido:** juntar um Analista de UX/UI Sênior, um Especialista Microsoft (MVP Windows), um QA Sênior e um Engenheiro de Software Sênior para trabalhar na tela e na função Otimizar:
- o designer revisa cada detalhe da interface e orienta o engenheiro;
- o especialista confere se os comandos e as alterações no Windows são feitos da melhor forma disponível hoje, de modo seguro e robusto, e se fazem sentido e mudam o que devem no PC;
- o QA testa todas as funções da tela;
- o engenheiro aplica as correções.

**O relatório completo** está em `docs/revisao-otimizar-4.0.md`: o caminho do Otimizar, o que cada olhar viu, os testes e as fontes.

**O que mudou**

| Achado | Olhar | Como ficou |
|---|---|---|
| O Otimizar desligava sozinho, a cada vez, as atualizações antecipadas ("Receba as atualizações mais recentes assim que estiverem disponíveis"), também de quem as ligou de propósito. | MVP | A etapa saiu (20 etapas). A opção entrou na revisão dos ajustes, no fim, marcada conforme o Windows está; com a política da empresa, fica de fora. |
| A descrição dessa chave prometia instabilidade. | MVP | Diz o que a Microsoft diz: o PC pode reiniciar mais vezes por mês. |
| A faixa do fim era a genérica em todos os desfechos, sem botão; com três ou mais etapas com problema, só a conta. | Designer | "PC otimizado"; "2 etapas pedem atenção", com os nomes e, com uma só, o motivo, e o botão para a tela da etapa; "Nenhuma etapa funcionou", com o motivo comum. |
| A parte automática cancelada terminava em "Concluído com ressalvas". | Designer | "Parte automática cancelada", com o que continua valendo. |
| O resumo dos navegadores sem pontuação ("Chrome a atualização é controlada por uma política"). | Designer | "Edge: atualizado para …; Chrome: …". |
| Uma pasta que não abria no Explorador sumia do resumo da etapa das pastas. | QA | "Documentos: não abriu no Explorador". |
| Procurar duplicados e desistir contava como etapa feita. | QA | Sem nada mudado, a etapa é ignorada. |

**Conferido e mantido**, com o motivo e as fontes no relatório:
- **os navegadores:** o Chrome pelo atualizador do Google com `--update-apps --system`, o Edge pelo atualizador dele e o Firefox pelo winget, no mesmo idioma; os que se atualizam sozinhos ou têm política ficam como estão;
- **a lista do winget sem os navegadores;**
- **as perguntas que podem custar algo no Não,** e "Manter" a Lixeira;
- **o console e o histórico** com a frase de antes.

**Por dentro**
- **Maintenance.psm1:** `Set-WinForgeMaintenanceView`, `Get-WinForgeMaintenanceStepTarget` e `Format-WinForgeMaintenanceGain` (novas); o plano sem as atualizações antecipadas.
- **Tweaks.psm1:** `Disable-WinForgeEarlyUpdates` saiu; a revisão dos ajustes com as antecipadas, menos com a política da empresa; a descrição da chave.
- **Software.psm1** (o resumo dos navegadores), **Cleanup.psm1** (a etapa das pastas) e **WinForge.Gui.ps1** (com o botão na faixa, o fim do Otimizar continua abrindo no Resumo).
- **Traduções:** 10 novas e 10 que saíram de uso; 5.344 ao todo.

**Conferido na nuvem**
- **As conferências novas do Otimizar, todas passando:** 146 em português e 151 em inglês e em espanhol.
  - O plano, os destinos das etapas e a revisão dos ajustes com as atualizações antecipadas.
  - O Otimizar de ponta a ponta em 23 situações, com a faixa, o console e o histórico.
  - Os navegadores em 18 situações, com o comando que roda; as pastas pessoais em 10; as perguntas antes da parte automática.

  Cada conferência das correções falha no código de antes e passa no de agora.
- **As de antes continuam passando:**
  - as 146, 147 e 147 do Verificar o PC e as das outras páginas revistas, com os mesmos números da R27;
  - as 243, 245 e 250 da Manutenção, com sete conferências da R14 adaptadas às 20 etapas;
  - as 241 do Início, as do QA geral, da R7 à R12, da QA e da integração;
  - as 84 ações rodando 336 vezes, o motor de instalação, a atualização simulada, o Setup de verdade (da R27 para esta) e o pacote de suporte;
  - as traduções (5.344/5.344), as 159 referências nos três idiomas e a busca de cada nome;
  - nenhuma chamada com parâmetro que não existe, nenhuma função sem uso e nenhum aviso novo do analisador.

**Falta ver num PC** (entrou no roteiro):
- as atualizações antecipadas ligadas, que continuam ligadas depois do Otimizar;
- a faixa num PC em dia e com uma etapa com problema;
- a parte automática cancelada;
- o resumo dos navegadores.

**Entregue:** `WinForge.zip`, `WinForge-codigo-fonte.zip`, `historico-4.0.md` e `revisao-otimizar-4.0.md`.

---

## R29 — Revisão de todos os arquivos

**Data:** 20/11/2026 · **Commit:** 8c355d1

**Pedido:** "Revise todos os arquivos do projeto. Scripts, docs, files, códigos."

**O relatório completo** está em `docs/revisao-arquivos-4.0.md`: o que foi revisto em cada tipo de arquivo, os achados, o que foi conferido e mantido e os testes.

**O que mudou**

| Achado | Onde | Como ficou |
|---|---|---|
| O `WinForge.zip` só podia ser montado fora do repositório; nenhuma ferramenta do projeto fazia o zip com os arquivos que o instalador troca e o CHANGELOG das cinco builds. | Ferramentas | `tools/New-WinForgePackage.ps1` (nova): o zip com a lista do instalador, o CHANGELOG curto, o `SHA256SUMS.txt` do que está no zip e o SHA-256 do zip para a página da versão. |
| O `Sign-WinForge.ps1` gravava um `SHA256SUMS.txt` da pasta inteira (com docs, ferramentas e o CHANGELOG inteiro), que não batia com o zip. | Ferramentas | Ele só assina; o `SHA256SUMS.txt` sai da ferramenta do zip. |
| O mapa de funcionalidades tinha a frase velha de Versão e pastas, 5.179 textos e o Otimizar sem o botão da faixa. | Documentos | Corrigido e conferido item por item contra o código. |
| O mapa de melhorias (no projeto) dizia que a proposta da 4.0 não estava decidida e que o instalador não existia. | Documentos | A situação de hoje no alto. |
| Os READMEs não citavam a ferramenta do zip. | Documentos | "assinatura, o zip da versão e traduções", nos três idiomas. |
| O `.editorconfig` pedia CRLF para os três arquivos do git, que são LF. | Regras | LF para eles, também no `.gitattributes`. |

**Conferido e mantido**, com o motivo no relatório:
- **o código do programa:** as varreduras da R12 (PowerShell 7, WMI sem tempo-limite, C#, fluxo, `catch`, estado sem uso) e o analisador, sem nada novo;
- **o `WinForge-Console.cmd`** só reconhece a verificação rápida com `-Action Check` em primeiro, como ele diz e os READMEs mostram;
- **o CHANGELOG da 4.0, os READMEs e os documentos do projeto no Claude**, sem contradição nem link quebrado.

**Por dentro**
- **tools/New-WinForgePackage.ps1** (nova) e **tools/Sign-WinForge.ps1**; o comentário da lista de arquivos no Install.psm1.
- **docs/funcionalidades-4.0.md**, os três READMEs, o `.editorconfig` e o `.gitattributes`.
- **Traduções:** nenhum texto novo; as referências de linha em dia. 5.344 ao todo.

**Conferido na nuvem**
- **As conferências novas, todas passando:** 14 das ferramentas (o zip numa cópia do repositório e a assinatura simulada) e 139 dos documentos e dos arquivos.
- **O zip da ferramenta** é o mesmo das entregas anteriores, arquivo por arquivo, mais o `SHA256SUMS.txt`, e passa pelo Setup de verdade.

  Cada conferência das correções falha nos arquivos de antes e passa nos de agora.
- **As de antes continuam passando:** as do Otimizar, da Manutenção, do Início, do QA geral, da R7 à R12, da QA e da integração; o motor de instalação, a atualização simulada, o Setup de verdade (da R28 para esta) e o pacote de suporte; as traduções, as referências e a busca; nenhuma chamada com parâmetro que não existe, nenhuma função sem uso e nenhum aviso novo do analisador. As baterias de cada tela não rodaram de novo: os módulos delas não mudaram desde a R28.

**Falta ver num PC** (entrou no roteiro): a ferramenta do zip no Windows PowerShell 5.1.

**Entregue:** `WinForge.zip` (montado pela ferramenta nova), `WinForge-codigo-fonte.zip`, `historico-4.0.md` e `revisao-arquivos-4.0.md`.

## R30 — Documentação técnica

**Data:** 20/11/2026 · **Commit:** 04c8365

**Pedido:** "Um Analista de Produto Sênior, junto do dev responsável, devem criar uma documentação técnica para o WinForge"

**O documento** está em `docs/documentacao-tecnica-4.0.md`, em duas partes:
- **Produto:** o que é o WinForge e para quem; por onde ele chega à pessoa (janela, menu de texto, monitor, manutenção agendada, linha de comando e instalador); os nove princípios que explicam as decisões do código; as 12 páginas, com os itens, os atalhos e o Administrador de cada uma; e os fluxos principais (Início, Verificar o PC, Otimizar, monitor, manutenção agendada, instalar e atualizar, relatório, verificação rápida e pacote de suporte).
- **Desenvolvimento:** os requisitos e o repositório; a arquitetura em camadas, os pontos de entrada e os 38 módulos; a tabela de navegação; o contrato de uma ação, com um modelo; a janela (como uma ação roda, uma janela por conta, o Administrador); o menu de texto e a linha de comando, com os códigos de saída e o JSON da verificação rápida; o monitor e a manutenção agendada; instalar, atualizar com um clique (com o contrato que as versões futuras precisam manter) e desinstalar; os ajustes; o histórico de mudanças; os dados e a integração com o Windows; o que vai para a internet; os idiomas; o visual; as regras de engenharia; como estender (uma ação, um ajuste, um módulo, uma etapa do Otimizar, uma conferência do monitor); como publicar; os riscos e um glossário.

**O que mudou**
- `docs/documentacao-tecnica-4.0.md` (novo).
- Os três READMEs, em Projeto: o link para a documentação técnica.
- O CHANGELOG, em Estrutura: o documento novo.
- Nenhuma linha de código mudou.

**Conferido na nuvem**
- **Os nomes:** cada função, variável e caminho citado existe no código (187 conferências; ficam de fora só os modelos do texto, como `Verbo-WinForgeNome`).
- **Os números**, contra o código carregado (96 conferências): as páginas, os itens, os atalhos e o Administrador de cada página; os 53 ajustes, as categorias, as marcas e os perfis; as conferências do monitor; os cartões, as etapas e as faixas da nota do Início; as etapas do Verificar o PC e do Otimizar; as cores e a tipografia; os limites (diário, histórico, prazos, a tarefa agendada) e a ordem dos idiomas. E mais 45: as funções de cada módulo, as linhas da janela, os arquivos do git e os textos.
- **Os documentos e os arquivos:** a conferência da R29, agora com o documento novo (140 conferências: links, âncoras, READMEs e o formato de cada arquivo).
- **Corrigido no rascunho antes da entrega**, depois de ler o código de cada ponto: os botões da nota do Início, os endereços do teste de conectividade, o que a pasta `support` guarda, quem transforma as perguntas em botões, a confirmação das ações leves (Acelerar agora roda num clique) e como o Administrador de um ajuste de registro é decidido.
- **O zip** mudou só nos READMEs e no CHANGELOG, e passa pelo Setup de verdade, da R29 para esta.

**Falta ver num PC:** nada novo. O documento não muda o que o WinForge faz.

**Entregue:** `WinForge.zip` (com os READMEs e o CHANGELOG novos), `WinForge-codigo-fonte.zip`, `historico-4.0.md` e `documentacao-tecnica-4.0.md`.

## R31 — O README nas práticas do GitHub

**Data:** 20/11/2026 · **Commit:** bd4c3d3

**Pedido:** "Corrija e ajuste/melhore o README nas melhores práticas para o GitHub". O dono sobe o projeto no GitHub à mão.

**O que foi corrigido**, frases que prometiam mais do que o WinForge faz:
- "Verifica o PC e corrige o que achar" virou "corrige num clique o que é seguro": o resto vira um botão para a tela certa.
- "o histórico mostra cada mudança" virou "o **Histórico de mudanças** desfaz o que tem volta".
- O monitor na bandeja aparece como opcional: ele só abre com o Windows depois que a pessoa o liga.

**O que entrou**, pelo que o GitHub diz que um README deve ter (o que o projeto faz, por que é útil, como começar, onde pedir ajuda e quem mantém):
- **Selos** no alto: a versão mais recente (a do último release), a licença, Windows 10 | 11 e PowerShell 5.1, com o rótulo no idioma de cada README.
- **O Otimizar** em "O que ele faz": é a função principal e não aparecia pelo nome.
- **Segurança e privacidade:** como conferir o zip (`Get-FileHash`) contra o SHA-256 da página da versão, e o que vai para a internet (só consultas e downloads; nenhum dado do PC sai).
- **Desinstalar:** por onde, a pergunta dos dados e que os ajustes do Windows continuam, com o caminho para desfazê-los antes.
- **Os códigos de saída da verificação rápida** (de 0 a 3), para quem automatiza.
- **Ajuda:** a aba Issues e o Pacote de suporte, com o aviso de que ele mostra o nome do PC e caminhos de pastas.
- **Projeto:** a documentação técnica primeiro, depois as pastas e o histórico.

**Mantido, com o motivo:**
- **O README principal em português,** com os outros dois a um clique: o WinForge é feito em português, e cada README segue a interface no idioma dele.
- **O link da documentação técnica com o endereço completo:** o GitHub prefere links relativos, mas o README também vai no `WinForge.zip`, que não leva a pasta `docs`. Com o endereço completo, o link funciona no GitHub e na pasta instalada.
- **Sem captura de tela:** ela pede o Windows de verdade e ficou para depois da conferência num PC, como a R9 já dizia.
- **Curto e direto:** 84 linhas em cada idioma, com poucas linhas por seção.

**Por dentro**
- `README.md`, `README.en.md` e `README.es.md`: reescritos, com a mesma estrutura nos três.
- `CHANGELOG.md`: a linha do README.
- O roteiro de conferência (no projeto): §24, Depois de subir no GitHub.
- Nenhuma linha de código mudou.

**Conferido na nuvem**
- **Os READMEs, em 71 conferências:**
  - cada tela citada existe com esse nome no idioma do README (Sobre o WinForge > Verificar nova versão, Ajustes do Windows > Desfazer ajustes do WinForge, Pacote de suporte...), e os nomes do Windows também (Configurações > Aplicativos, Extrair tudo);
  - as âncoras dos selos e os links relativos;
  - nenhum link quebrado em duas linhas, que o GitHub não aceita;
  - os blocos de código fechados e o texto alternativo das imagens;
  - os códigos de saída, iguais aos do código;
  - a mesma estrutura e os mesmos endereços nos três idiomas;
  - o formato: UTF-8 sem BOM e CRLF.
- **O que vai para a internet**, conferido no código: as únicas consultas do próprio WinForge são a versão nova e o zip dela, os dados online (os dois no GitHub), o teste de velocidade, o IP público e o ping.
- **A conferência dos documentos da R29:** as 140 passando.
- **Uma prévia** de cada README desenhado, para ler a página como ela aparece.
- **O zip** mudou só nos READMEs e no CHANGELOG, e passa pelo Setup de verdade, da R30 para esta.

**Falta ver depois de subir** (entrou no roteiro, §24): os selos desenhados (vêm do shields.io, que não abre daqui), os links, a aba Issues ligada e o SHA-256 do zip baixado.

**Entregue:** `WinForge.zip`, `WinForge-codigo-fonte.zip`, os três READMEs e `historico-4.0.md`.

---

## R32 — Desinstalar e atualizar programas só da conta

**Data:** 20/11/2026 · **Commit:** 94f3aac

**Pedido:** "(BUG) - Falha na desinstalação dos softwares exemplo do print. Analisar detalhadamente e corrigir de modo seguro e robusto, sem gambiarras, como um engenheiro de software sênior. Nada que funciona deve ser quebrado. Após, um QA Sênior deve testar se de fato foi resolvido da melhor forma possível. O MVP Windows deve validar também."

**O print:** o Otimizar, na etapa de desinstalar programas. CapCut, FFmpeg for yt-dlp e gallery-dl falharam com "o programa foi instalado só para o seu usuário, e o winget não o altera como Administrador; … — erro 0x8A15007D". O print diz "Etapa 4 de 22", de uma build anterior à R13, mas a desinstalação é a mesma de hoje: o código de agora repete a falha.

**A causa**
- **O código 0x8A15007D** é `APPINSTALLER_CLI_ERROR_ADMIN_CONTEXT_ACTION_PROHIBITED`, na tabela de códigos do winget: "The requested operation is not permitted from an administrator context on packages installed within the user scope." De um processo elevado, o winget recusa desinstalar e atualizar um programa instalado só para a conta. Instalar, não. O mesmo código já foi `…_ADMIN_CONTEXT_REPAIR_PROHIBITED`, só do reparo (é o nome que guias como o da FileWave ainda mostram): o winget estendeu a recusa.
- **O WinForge roda como Administrador** (a janela pede ao abrir). Todo programa só da conta caía nessa recusa, em três lugares: Programas > Desinstalar programas, Atualizações > Atualizar programas (winget) e o Otimizar. A recusa vem antes de qualquer mudança no PC. O WinForge só traduzia o erro, desde a 3.x.
- **Em outros projetos:** o WinUtil tem a mesma falha (issue #5018). Lá, quem mantém o projeto testou tirar a elevação com o `runas /trustlevel`, que não passa pela conferência do winget, e indicou rodar o winget num terminal sem Administrador.
- **No winget:** a issue #6363 relata a mesma recusa no winget 1.29.280. Nela, JohnMcPMS escreveu que "this actually is a bug for scoped circumstances" e que vai corrigi-lo: a conferência olhava se o processo está no grupo Administradores, quando devia olhar se ele tem o token completo ao lado de um limitado. Mesmo corrigida, a recusa continua no caso do WinForge, que roda com o token completo e o UAC ligado. A correção tinha de ser do lado do WinForge.

**Descartado, com o motivo**
- **Rodar como Administrador o desinstalador gravado no registro da conta** (HKCU): qualquer programa da conta pode trocar esse comando, e rodá-lo elevado daria o Administrador a ele. É justamente o que o winget bloqueia.
- **Abrir o winget pelo Explorador,** como o monitor na bandeja (`monitor.lnk`): o WinForge ficaria sem o código de saída e sem a saída, e o Parar não chegaria nele.
- **Uma tarefa S4U** (que roda sem a pessoa logada): a documentação do Agendador diz que ela não tem "access to either the network or encrypted files", e o winget precisa da rede.
- **O `runas /trustlevel`:** no WinUtil, não passou pela conferência do winget.
- **Deixar para a próxima entrada no Windows** (RunOnce), como o Winnow faz (PR #99): o resultado só vem depois, sem a saída do winget na tela e sem o Parar.
- **Pedir para abrir o WinForge sem Administrador:** o resto da página precisa dele, e a pessoa teria de fechar e abrir de novo para um programa.

**A correção**
- **Na recusa, de novo sem Administrador:** quando o winget responde 0x8A15007D a um pacote, `Invoke-WinForgeWingetUserScope` roda o mesmo comando de novo com a conta da pessoa, sem elevação, por `Invoke-WinForgeLimited`. A tela diz "CapCut foi instalado só para o seu usuário, e o winget não o altera como Administrador. Tentando de novo sem Administrador.", mostra o comando e a saída do winget enquanto chega. O resultado conta como os outros: desinstalado, atualizado ou a falha com o código do winget.
- **A tarefa de uma vez só:** `\WinForge\SemAdministrador-<data>-<id>`, sem horário, com a conta da pessoa (pelo SID), o token interativo (só roda com ela logada, na sessão dela) e os menores privilégios (`LeastPrivilege`). É o caminho que o Windows documenta para uma tarefa rodar sem elevação na sessão de quem está logado, e dá o mesmo token de um terminal aberto sem Administrador, o que o WinUtil indica fazer à mão. Ela roda o `WinForge.Unelevated.ps1` (novo), pelo mesmo PowerShell sem janela da manutenção agendada, e é apagada no fim.
- **Quando não dá, a faixa diz por quê,** sempre com o código 0x8A15007D:
  - o WinForge aberto com a conta de outro Administrador: o programa é dessa conta, e é preciso entrar no Windows com ela;
  - o UAC desligado de vez, ou o Administrador embutido do Windows: não há a versão da conta sem Administrador (`Get-WinForgeTokenElevationType`);
  - a tarefa que não rodou: o motivo, com o que fazer para continuar sem Administrador;
  - a mesma recusa sem Administrador.
- **Sem Administrador,** nada muda: o winget não recusa, e o código vale como veio.

**As decisões de segurança**
- **Nada roda elevado:** a tarefa e o que ela abre têm os direitos de qualquer programa que a pessoa abre.
- **O WinForge elevado não grava na pasta da execução** (`%LOCALAPPDATA%\WinForge\run\<id>`, que qualquer programa da conta altera): o pedido vai na linha de comando da tarefa (JSON em Base64), e quem cria a pasta e grava nela é o script, sem elevação.
- **Só lê o que é seguro ler:** arquivos comuns (nem link, nem atalho de pasta), numa pasta que não é atalho, cuja dona é a conta da pessoa; os textos curtos até 4 KB, a saída até 4 MB.
- **Parar de verdade:** o Parar, a janela fechada ou o prazo vencido encerram a árvore do script (`taskkill /T`, só depois de conferir que o número é de um PowerShell aberto depois da tarefa) e a tarefa, antes de apagá-la.
- **Nada fica para trás:** a pasta sai pelo `Remove-WinForgeFolder`, que não segue atalhos de pasta. Uma tarefa ou pasta que sobrou de um WinForge fechado à força sai na próxima execução, depois de 3 horas (mais que o limite de 2 horas da tarefa, para nunca tirar uma que ainda roda), e todas saem ao desinstalar o WinForge.

**O que o QA achou na revisão, e foi corrigido**
- **O que começa depois do prazo continuava rodando:** se a tarefa começasse logo depois dos 60 segundos, ou o Parar viesse antes de o script gravar o número dele, a limpeza só apagava a tarefa. A página do `Unregister-ScheduledTask` não diz que isso encerra o que já roda; a do `Stop-ScheduledTask` diz que ele "immediately stops all running instances". Agora a limpeza procura o script de novo, encerra a árvore dele e encerra a tarefa antes de apagá-la. Com a limpeza de antes, a conferência nova mostrou o script vivo depois do fim.
- **O motivo do prazo:** dizia "o Agendador de Tarefas não começou a tarefa", mas o mesmo prazo vence quando o script nem abre (uma política do PowerShell que o bloqueia, por exemplo). Agora: "a execução sem Administrador não começou em 60 segundos".
- **O arquivo trocado depois da conferência:** a dona era conferida pelo caminho, e o arquivo era aberto depois. Um programa da conta podia trocá-lo por um link nesse meio. Agora a dona é conferida de novo no arquivo já aberto (`Open-WinForgeLimitedRunFile`), e um arquivo de outra dona não é lido. Sem essa conferência, a conferência nova lê as 6 linhas do arquivo trocado.
- **O limite, escrito:** apagar a pasta segue o `Remove-WinForgeFolder`, como nas outras pastas do WinForge em `%LOCALAPPDATA%`, e um programa que já roda na conta e troca a pasta por um atalho no meio da limpeza não é coberto por inteiro. Os critérios de segurança da Microsoft tratam o UAC como defesa em profundidade, sem correção prevista, e não como fronteira de segurança. A fronteira é entre contas diferentes, e com a conta de outro Administrador a tarefa nem é criada.
- **A limpeza com a tarefa recusada no começo:** os caminhos da pasta passaram para antes da tarefa, e a limpeza não dá erro quando o Agendador aceita a tarefa e recusa começá-la.

**Por dentro**
- **Software.psm1:** `Invoke-WinForgeWingetUserScope` (nova); `Invoke-WinForgeWingetPackages` a chama no código 0x8A15007D (`$script:WinForgeWingetUserScopeCode`). O texto desse código em `Get-WinForgeWingetExitResult` não mudou.
- **Schedule.psm1:** a seção "Rodar sem Administrador": `Get-WinForgeLimitedRunState`, `ConvertTo-WinForgeLimitedRunRequest`, `New-WinForgeLimitedRunTaskXml`, `Test-WinForgeLimitedRunFile`, `Get-WinForgeLimitedRunStreamOwner`, `Open-WinForgeLimitedRunFile`, `Read-WinForgeLimitedRunText`, `Read-WinForgeLimitedRunOutput`, `Get-WinForgeLimitedRunProcess`, `Stop-WinForgeLimitedRunProcess`, `Remove-WinForgeLimitedRunLeftovers` e `Invoke-WinForgeLimited`. `Get-WinForgeHiddenPowerShellCommand` saiu de dentro de `Get-WinForgeScheduleCommand`, que dá o mesmo comando de antes.
- **Core.psm1:** `Get-WinForgeCurrentUserSid` e `Get-WinForgeTokenElevationType` (o `GetTokenInformation` do Windows).
- **Install.psm1:** `Uninstall-WinForge` tira as tarefas e pastas que sobraram.
- **WinForge.Unelevated.ps1 (novo):** cria a pasta da execução, grava o número do processo, roda o programa (como o `Invoke-WinForgeNative`, com a saída de erros junto) e grava a saída linha a linha e, por último, o código de saída. Entra no zip e na instalação pelo padrão `WinForge.*.ps1`, sem mudança no instalador.
- **Traduções:** 13 textos novos; `lang/en.po` e `lang/es.po` com 5.357.
- **Documentos:** o `CHANGELOG.md` (a mudança, o que pede conferência e a Estrutura); a documentação técnica (a seção 11.3, o repositório com 92 arquivos e 1.258 funções, os pontos de entrada, a pasta `run` e a tarefa nova, e o risco); o roteiro de conferência (no projeto), §25. O repositório tinha 91 arquivos, e não 90: a contagem da R30 não incluía a própria documentação técnica.

**Conferido na nuvem pelo QA**
- **O print, antes e depois:** com o código de antes, os três programas do print terminam na mesma faixa do PC ("nenhum programa foi desinstalado: CapCut, FFmpeg for yt-dlp e gallery-dl"). Com a correção: "3 programas desinstalados", cada um tentado de novo sem Administrador com o mesmo comando, a tela dizendo por quê, e o Histórico de mudanças com os três.
- **Os Programas, em 17 conferências, nos três idiomas:** os três do print; um programa do PC e um da conta juntos (só o da conta vai sem Administrador); cada caminho sem a tarefa (outra conta, UAC desligado, a tarefa que não rodou, a recusa repetida, sem Administrador, outro erro do desinstalador); a atualização; a etapa do Otimizar.
- **A execução sem Administrador, em 50 conferências, nos três idiomas,** com o Agendador simulado e o script de verdade em outro processo:
  - o estado para cada combinação de Administrador, conta e token;
  - o XML da tarefa;
  - cada argumento chegando igual ao programa (espaços, aspas retas e curvas, &, %, vazio, outras escritas);
  - a saída com acentos e uma linha de 140 KB cortada entre leituras;
  - o limite da saída;
  - o código de saída negativo do winget;
  - o programa que não existe;
  - o Agendador que recusa, que não começa e que começa depois do prazo;
  - o script encerrado por fora e pelo Parar, antes e depois de começar;
  - os arquivos de outra dona, os links, os atalhos de pasta e o arquivo trocado depois da conferência;
  - as sobras, com a pasta `run` trocada por um atalho de pasta.
  
  Seis delas falham com o código de antes da revisão do QA.
- **Nada do que funcionava quebrou,** em comparação com a R29:
  - o Início (241 em cada idioma), as conferências da R9 à R12 e as gerais (código, dados, frente, R7);
  - os Programas (106, 115 e 115) e as Atualizações (110, 117 e 117);
  - o Otimizar (146, 151 e 151);
  - a Manutenção (243, 245 e 250), com a manutenção agendada dando o mesmo comando de antes;
  - instalar, atualizar com um clique e o pacote de suporte, agora com 57 arquivos;
  - as traduções (diferentes = 0);
  - as funções sem referência (nenhuma, entre 1.451);
  - o PSScriptAnalyzer (os mesmos 224 avisos de antes, nenhum novo).
- **O Windows PowerShell 5.1:**
  - nada que só o PowerShell 7 tem;
  - o pedido em JSON segue o mesmo padrão do manifesto do backup, que o Windows já lê;
  - o programa é chamado do mesmo jeito que no `Invoke-WinForgeNative`, com as mesmas regras de aspas e de argumento vazio.

**Validado pelo MVP Windows**, na documentação da Microsoft:
- **A conta e o token:**
  - o tipo `logonType`: com o token interativo, "the task will be run only in an existing interactive session"; o S4U fica sem rede;
  - "Security Contexts for Running Tasks": de um processo elevado, uma tarefa com `LeastPrivilege` (`TASK_RUNLEVEL_LUA`) roda com os menores privilégios. O valor é ignorado com o UAC desligado, e na conta Administrador embutida a tarefa roda elevada;
  - `TOKEN_ELEVATION_TYPE`: `Default` é o token sem a versão ligada, `Full` o elevado e `Limited` o limitado.
- **A prioridade:** a tabela do `TaskSettings.Priority` põe o 5 na classe normal (o padrão de uma tarefa, 7, fica abaixo do normal); quem espera é a pessoa.
- **O encerramento:** o `Stop-ScheduledTask` "immediately stops all running instances". O `Unregister-ScheduledTask` não fala do que já roda, e por isso a tarefa é encerrada antes de apagada.
- **O UAC:** desabilitar a política "Run all administrators in Admin Approval Mode" (o valor `EnableLUA` = 0, no registro) desliga o modo de aprovação, e com ele a versão da conta sem Administrador. A opção "Elevate without prompting" só tira a pergunta, e a elevação continua sendo um passo à parte. O que o mínimo do controle deslizante muda não está documentado, e entrou no roteiro.
- **O que só um PC confirma:** o roteiro, §25. Lá estão a desinstalação e a atualização de verdade dos três programas do print, como Administrador, nos Programas e no Otimizar; um desinstalador com janela; o Parar no meio; o UAC no mínimo e desligado; a conta de outro Administrador; o WinForge sem Administrador; e a desinstalação do WinForge depois disso.

**Limites que ficam**
- **Atualizar tudo de uma vez:** é o caminho de reserva para quando o WinForge não lê a lista do winget, e continua como antes. Lá, o winget responde pelo conjunto, e rodar tudo de novo sem Administrador repetiria também os programas do PC inteiro.
- **Com o UAC desligado de vez, ou com a conta de outro Administrador,** não há como rodar com a conta da pessoa sem Administrador: a faixa diz o que fazer.
- **A conta Administrador embutida com o modo de aprovação ligado** (raro): a documentação do Agendador diz que, nela, a tarefa roda elevada. A recusa volta, e a faixa diz que o winget recusou também sem Administrador.

**Fontes**
- [winget: códigos de retorno](https://github.com/microsoft/winget-cli/blob/master/doc/windows/package-manager/winget/returnCodes.md) e a [issue #6363 do winget](https://github.com/microsoft/winget-cli/issues/6363)
- [WinUtil, issue #5018](https://github.com/ChrisTitusTech/winutil/issues/5018), [Winnow, PR #99](https://github.com/BiosSystem/Winnow/pull/99) e o [guia de erros do winget da FileWave](https://kb.filewave.com/books/microsoft-windows-package-manager-winget/page/troubleshooting-errors-with-winget)
- Microsoft: [Security Contexts for Running Tasks](https://learn.microsoft.com/en-us/windows/win32/TaskSchd/security-contexts-for-running-tasks), [logonType](https://learn.microsoft.com/en-us/windows/win32/taskschd/taskschedulerschema-logontype-simpletype), [TOKEN_ELEVATION_TYPE](https://learn.microsoft.com/en-us/windows/win32/api/winnt/ne-winnt-token_elevation_type), [TaskSettings.Priority](https://learn.microsoft.com/en-us/windows/win32/taskschd/tasksettings-priority), [Stop-ScheduledTask](https://learn.microsoft.com/en-us/powershell/module/scheduledtasks/stop-scheduledtask?view=win10-ps), [Unregister-ScheduledTask](https://learn.microsoft.com/en-us/powershell/module/ScheduledTasks/Unregister-ScheduledTask), [as configurações do UAC](https://learn.microsoft.com/nl-nl/windows/security/application-security/application-control/user-account-control/settings-and-configuration), [as chaves do UAC no registro](https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-server-2008-R2-and-2008/dd835564%28v=ws.10%29?redirectedfrom=MSDN), [Elevate without prompting](https://learn.microsoft.com/en-us/windows/device-security/security-policy-settings/user-account-control-behavior-of-the-elevation-prompt-for-administrators-in-admin-approval-mode) e os [critérios de segurança do Windows](https://microsoft.com/en-us/msrc/windows-security-servicing-criteria)

**Entregue:** `WinForge.zip`, `WinForge-codigo-fonte.zip` e `historico-4.0.md`.

---

## R33 — As mensagens da janela com o visual do WinForge

**Data:** 20/11/2026 · **Commit:** c566d30

**Pedido:** com o print do "Fechar o WinForge" no meio do Otimizar, "Tem como deixar esse tipo de tela estilizada conforme os padrões do WinForge? Ou ela é fixa e padrão do Windows?". Depois da resposta, "Pode fazer isso agora."

**O que era:** as 18 mensagens da própria janela saíam na caixa de mensagem do Windows (`System.Windows.MessageBox`), que não aceita o tema, a fonte nem botões próprios. Eram as de fechar no meio de uma ação, do Parar, do pedido de Administrador, da troca de idioma e dos erros. A caixa ficava clara num WinForge escuro e ignorava o contraste alto da janela. Os botões vinham no idioma do Windows: no print, "Yes" e "No" ao lado do texto em português.

**O que mudou**
- **Uma janela de mensagem do WinForge** (`New-GuiMessageDialog`), no desenho das caixas de diálogo do Windows 11:
  - o ícone, a frase em destaque e o texto no fundo do cartão;
  - os botões numa faixa embaixo, no fundo da janela, em duas colunas de mesma largura;
  - os mesmos estilos de botão, cores, fonte e tamanhos da janela, no tema de agora, no contraste alto e no tamanho do texto do Windows;
  - a barra de título na cor do tema e o ícone do WinForge.
- **Os botões dizem o que fazem**, no idioma do WinForge:

  | Pergunta | Botões | O padrão (Enter) |
  |---|---|---|
  | Fechar no meio de uma ação | **Fechar mesmo assim** (perigo) e **Continuar** | Continuar |
  | Parar a ação | **Parar** (perigo) e **Continuar** | Continuar |
  | Reabrir como Administrador | **Reabrir** (com o escudo) e **Cancelar** | Reabrir |
  | Reabrir para o idioma novo | **Reabrir** e **Agora não** | Reabrir |

  Os avisos têm um botão só, **OK** (em espanhol, **Aceptar**, como no Windows), na coluna da direita.
- **As 18 mensagens reescritas** com a frase principal em destaque e o resto embaixo, sem repetir a frase. Por exemplo, "\"Otimizar\" ainda está em andamento" e, embaixo, o que acontece se fechar. Os erros que só tinham a mensagem técnica ganharam a frase do que não aconteceu ("\"Otimizar\" não começou", "Não foi possível copiar").
- **O teclado:**
  - o foco começa na resposta padrão, a segura nas perguntas de perigo;
  - o Tab passa de um botão ao outro;
  - o Esc e o X respondem a resposta segura (na caixa do Windows com Sim e Não, o Esc não fazia nada);
  - o Ctrl+C copia a frase e o texto, como na caixa do Windows.
- **O leitor de tela** ouve a frase em destaque como nome da janela e o texto assim que ela aparece.
- **Com o WinForge minimizado** (fechar pela barra de tarefas), a janela volta antes da pergunta.
- **A reserva:** se a janela da mensagem não abrir, a mesma pergunta vai pela caixa do Windows, com a frase no alto do texto. A mensagem da falha da própria janela vai direto à caixa do Windows.

**Decisões, com o motivo**
- **Uma janela à parte, e não uma camada dentro da janela do WinForge** (como o ContentDialog do Windows 11): com o WinForge minimizado ou ainda abrindo, a camada não apareceria, e a pergunta de fechar precisa responder na hora, dentro do fechamento.
- **Os estilos e as cores da própria janela:** a mensagem recebe os recursos dela (pincéis, tamanhos, fonte e estilos). Assim, uma mudança no visual do WinForge vale também para as mensagens.
- **O desenho decidido num lugar só e conferível** (`Get-WinForgeMessagePlan`, no GuiDesign.psm1): o ícone, a ordem, o estilo e o padrão dos botões.
- **Sem o ponto de interrogação:** a pergunta usa o ícone de informação.
- **O Esc e o clique guardam a resposta na própria mensagem,** sem o IsCancel do WPF, que fecha a janela por conta própria. A resposta fica num lugar só.
- **Qualquer erro ao montar a mensagem leva à caixa do Windows,** e nunca a uma janela pela metade. A mensagem da falha da janela não passa pela janela de mensagem (`-System`): se ela fosse a falha, se chamaria de novo.
- **Uma mensagem com o texto vazio** (um erro sem descrição) mostra só a frase. Antes, o parâmetro obrigatório recusaria o texto vazio.

**Por dentro**
- **WinForge.Gui.ps1:**
  - `Show-GuiMessage` com `-Title` (a frase em destaque), `-YesText`, `-NoText`, `-YesIcon`, `-Danger` e `-System`;
  - `New-GuiMessageDialog` e `Show-GuiSystemMessage` (novas);
  - as 18 chamadas.
- **GuiDesign.psm1:** `Get-WinForgeMessagePlan` (nova).
- **Traduções:** 28 novas e 16 que saíram de uso; 5.369 ao todo.
- **Documentos:**
  - o `CHANGELOG.md`: a mudança, o que pede conferência e a Estrutura;
  - a documentação técnica: a seção 9.5, a regra das mensagens na seção 19 e os números da janela e dos módulos;
  - o mapa de funcionalidades: a conta dos textos;
  - o roteiro de conferência (no projeto): §26.

**Conferido na nuvem pelo QA**
- **O WPF do Windows PowerShell 5.1:** o QA roda a janela de mensagem de verdade sobre um WPF simulado. Cada tipo e membro desse WPF simulado (671 conferências) foi conferido contra o perfil de compatibilidade do Windows PowerShell 5.1 (Windows 10 1809) que vem com o PSScriptAnalyzer: os tipos, os valores de cada enum, as propriedades com o tipo e o set, os métodos com os parâmetros e o retorno, e os eventos. Com seis erros de propósito (um nome trocado, um valor de enum errado, uma propriedade sem set, um evento que não existe, um tipo e uma sobrecarga errados), a conferência pega os seis.
- **A mensagem, em 72 conferências, nos três idiomas:**
  - o desenho de cada tipo de mensagem;
  - as 18 chamadas: cada uma com a frase em destaque; as 4 perguntas com os verbos; o perigo só no parar e no fechar; o padrão Sim só ao reabrir; a caixa do Windows só na reserva, no aviso de antes de a janela abrir e na falha da janela; as frases com até 60 letras, sem ponto final, no idioma da tela;
  - a janela montada:
    - o dono e a posição, inclusive com o WinForge minimizado, maximizado e ainda fora da tela;
    - os recursos da janela;
    - os botões, o foco, o ícone e o texto que rola;
    - o texto do Windows a 225% numa tela pequena e numa tela minúscula;
    - os temas escuro e de contraste;
    - o leitor de tela e a barra de título;
    - o clique, o Esc e o Ctrl+C;
  - o caminho de `Show-GuiMessage`: a resposta pelo botão, pelo X e pelo Esc; a reserva quando a mensagem não abre ou falha ao montar; a resposta mantida quando o erro vem depois dela; o `-System`; a caixa do Windows sem a janela; o texto vazio.
- **Nove defeitos de propósito no código** (sem a reserva, perguntar de novo depois da resposta, o Esc respondendo Sim, o fechar sem o perigo, a janela minimizada sem voltar, o foco no botão errado, a falha da janela pela janela de mensagem, a mensagem sem os recursos da janela e o Ctrl+C sem conferir o Ctrl): as conferências pegam os nove.
- **Nada do que funcionava quebrou:**
  - as baterias das 14 páginas revistas, com os mesmos números de antes: Diagnóstico (212, 224 e 224), Segurança (134, 142 e 142), Limpeza (178, 187 e 187), Desempenho (96, 102 e 102), Reparo (112, 119 e 119), Atualizações (110, 117 e 117), Programas (106, 115 e 115), Rede (144, 153 e 153), Ajustes do Windows (412, 422 e 422), Personalização (265, 270 e 270), Sobre o WinForge (164, 169 e 169), Busca (109, 98 e 101), Verificar o PC (146, 147 e 147) e Otimizar (146, 151 e 151);
  - a Manutenção (243, 245 e 250) e o Início (241 em cada idioma), as conferências da R9 à R12 e as gerais (código, dados, frente, R7);
  - instalar, atualizar com um clique e o pacote de suporte;
  - as traduções (diferentes = 0) e as 159 referências "Página > Item" nos três idiomas;
  - as funções sem referência (nenhuma, entre 1.454);
  - o PSScriptAnalyzer: 11 avisos a mais, todos dos dois tipos que a R7 já explicou, o `$sender` e o `$eventArgs` dos quatro eventos da mensagem, no padrão dos outros eventos da janela; nenhum de outro tipo.
- **Uma prévia** da mensagem nos dois temas, feita com as cores, os tamanhos, os ícones e os textos do código (uma réplica em HTML, com a fonte Inter no lugar da Segoe UI).

**Validado pelo MVP Windows**, na documentação da Microsoft:
- **As caixas de diálogo do Windows 11:**
  - o título é a instrução principal, e o conteúdo não deve repeti-lo "with slightly different wording";
  - os botões usam respostas específicas;
  - o que faz algo fica à esquerda, e a resposta segura "appears as the rightmost button", também quando ela é a única (o OK);
  - o Esc aciona a resposta segura;
  - o botão padrão fica em destaque, recebe o Enter e começa com o foco.
- **A caixa do Windows:** num aviso só com OK, o Esc responde OK; numa caixa sem Cancelar nem OK (a de Sim e Não), o Esc não tem efeito. Por isso o Esc da mensagem nova, que responde a resposta segura, é uma mudança, e de propósito. O Ctrl+C dela copia o texto, e a mensagem nova também copia.
- **O WPF do 5.1:** o perfil do PSScriptAnalyzer, acima. `IInputElement` fica em `System.Windows` e `Visual` em `System.Windows.Media`, como o simulado ficou depois da conferência.
- **O que só um PC confirma:** o roteiro, §26.

**Fontes**
- Microsoft: [as caixas de diálogo do Windows](https://learn.microsoft.com/windows/apps/design/controls/dialogs-and-flyouts/dialogs), [a função MessageBox](https://learn.microsoft.com/windows/win32/api/winuser/nf-winuser-messagebox) e [o Ctrl+C numa caixa de mensagem](https://learn.microsoft.com/en-us/archive/blogs/tristank/ctrlc-in-a-message-box-does-what)
- O perfil de compatibilidade do Windows PowerShell 5.1 que vem com o PSScriptAnalyzer (`compatibility_profiles/win-48_x64_10.0.17763.0_5.1.17763.316_x64_4.0.30319.42000_framework.json`)

**Entregue:** `WinForge.zip`, `WinForge-codigo-fonte.zip`, `historico-4.0.md` e a prévia das mensagens.

---

## R34 — O ícone do WinForge na barra de tarefas

**Data:** 20/11/2026 · **Commit:** ec46398

**Pedido:** com o print da barra de tarefas, em que o WinForge aparece com uma folha em branco no lugar do ícone: "Por que as vezes quando abro o bat o WinForge fica sem íncone? Parece aleatório". E: "Faça algo robusto sem gambiarra para que isso não ocorra mais".

**A causa**
- **Uma identidade só para todas as cópias:** desde a Build 3.1, o processo, a janela e os atalhos de qualquer pasta do WinForge usavam o mesmo identificador na barra de tarefas (AppUserModelID), `WinForge.App`.
- **O Windows junta pelo identificador:** as janelas de mesmo identificador ficam num botão só, e o ícone do grupo é o do item fixado. A documentação do `RelaunchIconResource` diz que ele é "the icon used for the taskbar group and is shown for a pinned application whether that application is running or not". Sem esse valor, o Windows procura um atalho com o mesmo identificador.
- **Cada revisão vem num zip novo:** cada zip vai para uma pasta nova, e as antigas acabam apagadas. Um item fixado ou um atalho de uma pasta que não existe mais aponta para um ícone que não existe. A janela de qualquer outra pasta, com o mesmo identificador, aparece com esse ícone: a folha em branco.
- **Por que parece aleatório:** o Explorador guarda os ícones em cache e só os relê de vez em quando: ao reiniciar o Explorador ou o PC, ou quando um programa avisa que os ícones mudaram (o Criar atalho do WinForge avisa). Enquanto o ícone antigo estava no cache, a janela aparecia certa.
- **Em outros projetos:**
  - o Blender teve o mesmo problema com várias instalações e um identificador só: "running other installation of Blender with the same already registered ID will show a missing icon in the taskbar". A correção proposta pôs um hash da pasta no identificador;
  - o Firefox monta o identificador com um hash da pasta de instalação, para instalações separadas não se juntarem;
  - no Sentio, a janela se juntou a um item fixado de uma versão apagada, "which displayed a blank icon".
- **O que não dá para ver daqui:** qual item fixado ou atalho estava no PC do print. O roteiro (§27) confere.

**Descartado, com o motivo**
- **Mexer nos itens fixados e nos atalhos que o Explorador guarda** (a pasta `User Pinned` do perfil): o lugar não é documentado pela Microsoft. Quem fez isso no Blender chamou de "bit of a hack". No qingwu, a mudança foi tirada do código por alterar em silêncio o que a pessoa fixou.
- **Copiar o ícone para uma pasta fixa** (a de dados): esconderia o atalho quebrado com um ícone certo, e a janela continuaria juntada ao item de outra pasta, que abre a versão velha, ou nada.
- **Mandar o Explorador reler os ícones a cada abertura:** o ícone relido continuaria sendo o do item da pasta apagada.
- **Uma identidade por versão:** os atalhos e o "Fixar" deixariam de se juntar à janela a cada atualização. A Microsoft diz para deixar a versão fora do identificador quando a versão nova substitui a anterior.
- **Manter `WinForge.App` na cópia instalada:** ela também convive com pastas extraídas (todo zip novo traz o WinForge.cmd), e a colisão voltaria.

**A correção**
- **Uma identidade por pasta** (`Get-WinForgeAppId`): `WinForge.App.` e 16 letras do SHA-256 do caminho da pasta.
  - o caminho é completo, sem a barra do fim e em maiúsculas (o Windows não diferencia);
  - numa unidade de rede mapeada (Z:), ele vira `\\servidor\pasta`, que é como a execução elevada abre a janela;
  - atualizar no lugar mantém a pasta e, com ela, a identidade; uma pasta nova tem a sua.
- **A mesma em todo lugar:**
  - o processo, antes de qualquer janela;
  - a janela, com o comando, o nome e o ícone desta pasta para o "Fixar";
  - os atalhos que o WinForge grava: o do Criar atalho, com a pasta aberta, e o do instalador, com a pasta instalada (`Get-WinForgeLaunchDefinition -Root`).
- **Os atalhos de antes:** um atalho desta conta que abre esta pasta, com outra identidade (de uma versão anterior) ou sem nenhuma, aparece no resumo do Sobre o WinForge ("o de Área de Trabalho precisa ser atualizado; use Criar atalho do WinForge") e em Versão e pastas, com Criar atalho do WinForge em destaque. Criar de novo regrava o atalho. O Início não lê a identidade (é uma leitura de COM por atalho), e uma identidade que não pôde ser lida não acusa.
- **Os itens fixados ficam com a pessoa:** um item fixado de antes continua na barra, e a janela nova aparece ao lado, com o ícone certo. Basta desafixar o de antes e fixar de novo pela janela aberta, uma vez.

**Por dentro**
- **Launcher.psm1:**
  - `Get-WinForgeAppId` (nova), no lugar do `$script:WinForgeAppId` fixo;
  - `Get-WinForgeLaunchDefinition` e `Initialize-WinForgeAppIdentity` com ela;
  - `Get-WinForgeShortcutState -Identity` (a propriedade `Outdated`), usada no resumo do Sobre, em Versão e pastas e em `Test-WinForgeAppShortcutNeeded`;
  - `Get-WinForgeShortcutAppIdCached` (nova): a página Sobre pergunta duas vezes ao ser desenhada, e o atalho que não mudou (a mesma data e o mesmo tamanho) é lido uma vez só.
- **Shell.psm1:** `Get-WinForgeShortcutAppId` (nova), com o C# `GetShortcutAppId`, que lê o identificador do `.lnk` numa thread STA, como a gravação já fazia.
- **WinForge.Gui.ps1:** só o comentário.
- **Traduções:** 2 textos novos, 5.371 ao todo.
- **Documentos:**
  - o `CHANGELOG.md`: a mudança, o que pede conferência e a Estrutura;
  - a documentação técnica: a seção 9.6, a tabela da 15.3, a regra da 19, o risco da 22 e os números dos módulos;
  - o mapa de funcionalidades: a conta dos textos;
  - o roteiro de conferência (no projeto): §27.

**Conferido na nuvem pelo QA**
- **O C#:** compilado pelo Roslyn na versão 5 da linguagem (a do Windows PowerShell 5.1), sem erro nem aviso. Com quatro erros de propósito (uma interpolação, um `?.`, um `out var` e um membro que não existe), a compilação recusa os quatro.
- **As APIs do .NET da correção:** 16 de 16 estão no perfil do Windows PowerShell 5.1 do PSScriptAnalyzer (as do `Marshal`, o `Load` do `IPersistFile`, o `SetApartmentState`, o `DisplayRoot` da unidade, o SHA-256, o `GetFullPath`, entre outras).
- **53 conferências, nos três idiomas:**
  - **a identidade:** o formato e o mesmo cálculo feito à parte; a mesma pasta e pastas diferentes; maiúsculas, a barra do fim, `..` e barras normais; a unidade de rede mapeada, o caminho de rede, uma unidade local e uma desconhecida; acentos; o valor guardado;
  - **a mesma em todo lugar:** o processo, a janela (com o ícone e o comando desta pasta), os dois atalhos do Criar atalho e o atalho do instalador (o da pasta instalada, e não o da pasta de onde ele roda); a janela da pasta instalada chega à mesma;
  - **os atalhos:**
    - em dia, de antes (`WinForge.App`), sem identidade e com a identidade não lida;
    - de outra pasta, não lido, um `WinForge.lnk` que não abre o WinForge e o do instalador;
    - o resumo do Sobre, Versão e pastas e o destaque;
    - o cartão do Início, sem ler a identidade;
    - o atalho em dia depois de criar de novo;
    - o atalho lido uma vez só pelo resumo e pelo destaque, lido de novo depois de regravado, e a identidade não lida sem ficar guardada;
  - **a leitura do identificador no `.lnk`,** com o C# simulado: o identificador, vazio, não lido, um erro e um arquivo que não existe.
- **Quinze defeitos de propósito**, e as conferências pegam os quinze:
  - a identidade fixa de antes, sem maiúsculas, sem tirar a barra do fim e sem a unidade de rede;
  - o atalho do instalador com a pasta errada e o processo com a identidade antiga;
  - acusar a identidade que não pôde ser lida, ler a identidade no Início e acusar o atalho de outra pasta;
  - o resumo sem a linha do atalho a atualizar, Criar atalho sem o destaque e a identidade não lida virando texto vazio;
  - o atalho guardado mesmo depois de regravado, a identidade não lida guardada e o atalho lido duas vezes.
- **Nada do que funcionava quebrou:**
  - as baterias das 14 páginas revistas, com os mesmos números da R33: Diagnóstico (212, 224 e 224), Segurança (134, 142 e 142), Limpeza (178, 187 e 187), Desempenho (96, 102 e 102), Reparo (112, 119 e 119), Atualizações (110, 117 e 117), Programas (106, 115 e 115), Rede (144, 153 e 153), Ajustes do Windows (412, 422 e 422), Personalização (265, 270 e 270), Sobre o WinForge (164, 169 e 169), Busca (109, 98 e 101), Verificar o PC (146, 147 e 147) e Otimizar (146, 151 e 151);
  - a Manutenção (243, 245 e 250), o Início (241 em cada idioma), as mensagens da janela (72 em cada idioma), as conferências da R9 à R12 e as gerais (código, dados, frente, R7). Uma conferência de tempo da R11 (em espanhol) passou do limite com quatro baterias rodando juntas (784 ms, para um limite de 763) e passou rodando sozinha;
  - depois da última mudança no Launcher.psm1, de novo: o Sobre o WinForge, o Início, as conferências gerais e as da R9 à R12, instalar e o pacote de suporte, com os mesmos números;
  - instalar, atualizar com um clique e o pacote de suporte; o Setup de verdade, da R33 para esta: saída 0, os arquivos trocados e as notas da pessoa mantidas;
  - as traduções (diferentes = 0) e as 159 referências "Página > Item" nos três idiomas;
  - as funções sem referência (nenhuma, entre 1.457);
  - o PSScriptAnalyzer: os mesmos 235 avisos da R33, nenhum novo.

**Validado pelo MVP Windows**, na documentação da Microsoft:
- **O formato:** até 128 caracteres, sem espaços, na forma `CompanyName.ProductName.SubProduct.VersionInformation`. `WinForge.App.` com as 16 letras tem 29.
- **A mesma identidade em tudo o que é um aplicativo só:** "it must also assign the same AppUserModelID to all running windows or processes, shortcuts, and file associations", com um identificador só para os atalhos do Menu Iniciar, da Área de Trabalho e de outros lugares.
- **Cada pasta é um aplicativo à parte:** cada pasta do WinForge abre o próprio código, com o próprio comando. Para a barra de tarefas, são como duas versões lado a lado, que a Microsoft diz serem "discrete entities". Atualizar no lugar mantém a identidade, como ela pede para uma versão que substitui a anterior.
- **O processo antes de qualquer janela:** `SetCurrentProcessExplicitAppUserModelID` vale "during an application's initial startup routine before the application presents any UI". A identidade da janela passa na frente da do processo, e as duas são a mesma.
- **O ícone do grupo:** o `RelaunchIconResource` é o ícone do grupo na barra. O `RelaunchCommand` e o `RelaunchDisplayNameResource` "must always be set together", e o WinForge grava os dois.
- **O que só um PC confirma:** o roteiro, §27.

**Limites que ficam**
- **Os itens fixados e os atalhos de antes** continuam com a identidade antiga: o WinForge não mexe no que o Explorador guarda. Um item fixado de uma pasta apagada fica em branco até ser desafixado, mas não leva mais a janela de outra pasta junto.
- **A mesma pasta por outro caminho** (um nome curto 8.3, um atalho de pasta) teria outra identidade. O WinForge.cmd, o instalador e os atalhos abrem pelo caminho completo.

**Fontes**
- Microsoft: [Application User Model IDs](https://learn.microsoft.com/en-us/windows/win32/shell/appids), [System.AppUserModel.RelaunchIconResource](https://learn.microsoft.com/en-us/windows/win32/properties/props-system-appusermodel-relaunchiconresource) e [System.AppUserModel.RelaunchCommand](https://learn.microsoft.com/en-us/windows/win32/properties/props-system-appusermodel-relaunchcommand)
- [Blender, issue #112729](https://projects.blender.org/blender/blender/issues/112729), [PR #113321](https://projects.blender.org/blender/blender/pulls/113321) e [PR #113859](https://projects.blender.org/blender/blender/pulls/113859); [Firefox, bug 577867](https://bugzilla.mozilla.org/show_bug.cgi?id=577867); [Chromium, Windows Shortcut and Pinned Taskbar Icon handling](https://chromium.googlesource.com/chromium/src/+/8d69b4b268f524e37ca262d25f72239184fcb9f4/docs/windows_shortcut_and_taskbar_handling.md); [Sentio, PR #35](https://github.com/sentio-one/sentio/pull/35); [qingwu, PR #2](https://github.com/lvtian-bot/qingwu/pull/2)

**Entregue:** `WinForge.zip`, `WinForge-codigo-fonte.zip` e `historico-4.0.md`.

---

## R35 — Avaliação completa e sugestões de funções novas

**Data:** 20/11/2026 · **Commit:** d91f6ce (só documentação; o programa não mudou)

**Pedido:** "Sem codar ainda: Faça uma avaliação completa do Avyra e sugira novas funcionalidades/tools úteis que se encaixariam bem para essa versão 4.0." O Avyra é o sistema da clínica, que não tem versão 4.0: a avaliação é do WinForge 4.0.

**O resultado** está em `docs/avaliacao-4.0.md`:
- um placar de 8 olhares e o que está forte;
- 7 pontos que preocupam, com a evidência;
- a comparação com o Microsoft PC Manager, o CCleaner e o WinUtil;
- 16 sugestões (N1 a N16), com o critério de encaixe, onde cada uma entra, o tamanho e o risco;
- o que foi avaliado e ficou de fora;
- uma ordem proposta.

**Os principais achados**
- **O maior risco continua sendo não ter rodado num Windows de verdade:** o roteiro tem 27 seções e 191 itens por fazer.
- **Dois riscos novos de 2026:**
  - a Proteção de Administrador separa o perfil da conta elevada, e o WinForge, que roda a janela inteira elevado, daria uma orientação impossível ("abra sem trocar de conta");
  - o Controle Inteligente de Aplicativos, que agora liga sem reinstalar o Windows, bloqueia código sem assinatura. A documentação não diz se isso vale para scripts.
- **Uma dívida conhecida:** a Manutenção agendada ainda fala com o Agendador de Tarefas sem prazo (da R18).

**As sugestões**
- **Para a 4.0, recomendadas:** N1 (reconhecer a Proteção de Administrador), N2 (o prazo no Agendador), N3 (os certificados do Secure Boot, que venceram entre junho e outubro de 2026) e N4 (a recuperação do Windows pronta).
- **Para a 4.0, se couber:** N5 (Windows ativado), N6 (a integridade da memória), N7 (reparar o Instalador de Aplicativo), N8 (não atualizar este programa), N9 (destravar a impressão) e N10 (acertar a data e a hora).
- **Para a 4.1:** N11 (a janela sem Administrador, com as ações elevadas à parte) primeiro; depois o inicializador assinado (F2 + I2), o fluxo do Otimizar (M3 + M4) e o resto da lista.

**Como foi feita:** pela leitura do código e dos documentos do ciclo, e pela documentação da Microsoft e das outras ferramentas, com as fontes no fim do documento. Os nomes do código citados foram conferidos no código.

**Por dentro**
- `docs/avaliacao-4.0.md` (novo).
- A documentação técnica: o repositório com 93 arquivos e o documento novo nos documentos relacionados.
- Nenhuma linha de código mudou.

**Entregue:** `avaliacao-4.0.md`, `historico-4.0.md` e `WinForge-codigo-fonte.zip`. O `WinForge.zip` não muda, porque o programa não mudou.

---

## R36 — Seis funções novas: ativação, integridade da memória, winget, programas na versão atual, impressão e relógio

**Data:** 20/11/2026 · **Commit:** be4776b

**Pedido:** "Se couber, todas pequenas: Windows ativado, integridade da memória, reparar o winget, “não atualizar este programa”, destravar a impressão e acertar a data e a hora. Adicione isto". São as sugestões N5 a N10 da avaliação (R35).

**O que mudou para quem usa**
- **N5 · Diagnóstico > Sobre este PC, a ativação do Windows:**
  - uma linha **Ativação**, logo depois da build: ativado, ainda no prazo para ativar ou não ativado;
  - quando não está ativado, a linha seguinte diz onde ativar ("abra Configurações e procure por Ativação", que vale no Windows 10 e no 11);
  - o relatório traz a mesma linha (**Ativação do Windows**);
  - o Início não lê a ativação: a consulta ao licenciamento leva alguns segundos.
- **N6 · Segurança > Auditoria de segurança, a integridade da memória:**
  - entra em "Só para saber", fora da nota, como o BitLocker e o Secure Boot: ligada, desligada ou ligada nas configurações e fora de uso;
  - desligada, o conselho diz onde ligar (Segurança do Windows > Segurança do dispositivo > Detalhes de isolamento do núcleo) e que alguns drivers e programas antigos não funcionam com ela;
  - sem leitura, a linha diz que pede o Administrador (sem ele) ou que não deu para ler;
  - o WinForge só lê: ligá-la é escolha da pessoa.
- **N7 · Reparar o Instalador de Aplicativo:**
  - a faixa "Falta o Instalador de Aplicativo", em todas as telas que usam o winget, ganha o botão **Reparar**; no menu de texto, uma linha diz onde fica o reparo;
  - o reparo registra o winget de novo para a conta, com o comando que a Microsoft indica, e confere se ele voltou a responder;
  - se não voltou (o pacote não está no PC, por exemplo), diz o motivo e oferece a página dele na Microsoft Store;
  - com o winget respondendo, mostra a versão e não mexe em nada; elevado com a conta de outro Administrador, não registra, porque valeria para essa conta;
  - é um item sem cartão em Programas: o botão e a busca levam a ele.
- **N8 · Atualizações > Manter programas na versão atual:**
  - uma lista com os programas que têm versão nova no winget e os já marcados para não atualizar, estes já marcados; desmarcar tudo também vale;
  - marcado, o programa sai do `winget upgrade` e, com ele, de **Atualizar programas**, do Otimizar, do monitor e do **Verificar o PC**; desmarcado, volta;
  - cada linha diz o ID, a versão e, num marcador posto por fora do WinForge, o tipo dele ("bloqueado no winget", "só versões 2.43.*");
  - entra no Histórico de mudanças com desfazer: o que foi marcado volta sem marcador, e o que foi tirado volta com o mesmo tipo e a mesma fonte;
  - em **Atualizar programas**, uma linha diz quantos programas com versão nova ficaram de fora, e onde mudar; a faixa de "em dia" diz isso também, em vez de "nenhum tem versão nova";
  - elevado com a conta de outro Administrador, nada muda: os marcadores ficam no perfil da conta.
- **N9 · Reparo > Destravar a impressão:**
  - mostra o Spooler de Impressão (ligado ou parado) e quantos documentos estão na fila;
  - com documentos, pergunta como destravar: **Reiniciar o Spooler** (em destaque, os documentos ficam), **Apagar a fila e reiniciar** (em vermelho, dizendo quantos não serão impressos) ou Cancelar; com a fila vazia, só pergunta se reinicia;
  - os serviços que dependem do Spooler e estavam ligados voltam a ligar;
  - só reiniciando, a faixa diz para tentar imprimir e, se continuar travada, usar a ação de novo e apagar a fila (o passo seguinte da Microsoft);
  - um Spooler desativado fica como está, e a tela diz por quê; um Spooler que não para ou não liga de novo vira falha, com o reinício do PC como saída.
- **N10 · Rede > Acertar a data e a hora:**
  - mostra a hora do PC e quanto o relógio está adiantado ou atrasado ("antes"), sincroniza e mostra de novo ("agora"), com o fuso horário e o servidor de hora;
  - a hora certa vem de um servidor da Microsoft (o do teste de internet do próprio Windows), e não só do que o `w32tm` responde;
  - um relógio que continua errado depois de sincronizar (o Windows fora de domínio não corrige sozinho mais de 15 horas) pode, com a pessoa concordando, ir para a hora do servidor; o Windows sincroniza de novo em seguida;
  - num PC de domínio, a hora vem do domínio: o WinForge não a muda por fora, e a faixa diz para conferir em alguns minutos ou falar com o suporte de TI;
  - com o serviço Horário do Windows desativado, ou com o Windows configurado para não sincronizar, o WinForge não muda a configuração: a tela diz isso, e só o acerto pela hora do servidor fica oferecido;
  - sem o servidor da Microsoft para conferir (sem internet, um portal de Wi-Fi no caminho), vale o que o Windows respondeu; sem sincronizar, a faixa diz as causas que a Microsoft lista (a internet, a porta UDP 123 bloqueada).

**Dois problemas que já existiam, achados no caminho**
- **A tabela do winget num Windows em espanhol não era lida.** A R1 pôs os nomes das colunas em espanhol, mas o reconhecimento do cabeçalho só procurava "Name" e "Nome", e a coluna da fonte não tinha "Origen". Num Windows em espanhol, **Atualizar programas**, **Listar programas instalados**, a busca de programas, a desinstalação e o **Verificar o PC** não reconheciam a lista. Agora o cabeçalho "Nombre ... Origen" é lido, e a fonte e a versão nova vêm nas colunas certas.
- **Atualizar programas, só com programas deixados de fora.** Quando o winget deixa de fora todos os programas com versão nova (os marcados para não atualizar e os de versão desconhecida), ele termina sem tabela, só com o rodapé que conta os que ficaram de fora. O WinForge dizia que não dava para ler a lista e oferecia "Atualizar tudo o que o winget oferecer"; o **Verificar o PC** dizia "não foi possível ler". Com o N8, isso passaria a acontecer em todo PC com programas marcados. Agora é "em dia", reconhecido pelo `--include-pinned` e pelo `--include-unknown` do próprio winget, que aparecem no rodapé em qualquer idioma.

**Decisões, com o motivo**
- **N7, sem pergunta antes:** registrar o pacote de novo não apaga nada e não muda nada quando o winget já funciona; o clique em Reparar é o pedido.
- **N8, um item próprio em vez de uma opção dentro de Atualizar programas:** a lista de Atualizar programas é a mesma que o Otimizar usa; uma pergunta a mais lá entraria no Otimizar.
- **N8, o marcador comum, e não o `--blocking`:** a Microsoft diz que o comum tira o programa do `winget upgrade --all` e deixa o `winget upgrade <programa>`. O WinForge só atualiza o que o `winget upgrade` lista, então o comum basta, e quem quiser atualizar um programa marcado pelo nome, no próprio winget, ainda consegue.
- **N8, sem o `--force`:** um programa que já tem outro marcador (posto por fora do WinForge) fica com o dele, que já o segura, e esse marcador não entra no desfazer.
- **N9, reiniciar primeiro:** é a ordem da Microsoft (cancelar, reiniciar o serviço e, se não resolver, esvaziar a pasta da fila). Apagar fica como segunda opção, porque os documentos não voltam.
- **N9, só os .SPL e .SHD:** a Microsoft manda apagar todos os arquivos da pasta `spool\PRINTERS`; os trabalhos da fila são esses dois tipos, e o resto da pasta fica. Uma pasta da fila que aponta para outro lugar não é lida.
- **N10, conferir a hora fora do `w32tm`:** o código de saída do `w32tm` não é documentado, e a mensagem sai no idioma do Windows. A conferência pelo cabeçalho `Date` do servidor HTTP da Microsoft diz se o relógio ficou certo, em qualquer idioma. HTTP, e não HTTPS: com o relógio muito errado, o HTTPS recusa o certificado.

**Por dentro**
- **Diagnostics.psm1:** `Get-WinForgeWindowsActivation` (a consulta ao `SoftwareLicensingProduct` com o produto do Windows e a chave instalada) e `Get-WinForgeWindowsActivationText`; a linha em `Show-WinForgeSystemInfo`.
- **Reports.psm1:** a linha Ativação do Windows em `Get-WinForgeReportSystemItems`.
- **Security.psm1:** `Get-WinForgeMemoryIntegrityState` (a classe `Win32_DeviceGuard`), o fato `MemoryIntegrity` da auditoria e o ponto `memory-integrity`, de peso 0.
- **Software.psm1:**
  - `Repair-WinForgeWinget` e `Get-WinForgeWingetVersion`; o botão na faixa de `Get-WinForgeWingetMissingResult` e a linha do menu de texto em `Write-WinForgeWingetMissing`;
  - `Set-WinForgeWingetPins`, `Get-WinForgeWingetPins`, `ConvertFrom-WinForgeWingetPinTable`, `Invoke-WinForgeWingetPin`, `Test-WinForgeWingetPinId` e `Get-WinForgeWingetPinJournalText`;
  - `Get-WinForgeWingetHeldCount`, e o `Held` do plano de `Get-WinForgeWingetUpgradePlan`, com a linha e a faixa de `Invoke-WinForgeWingetUpgradePlan`;
  - `ConvertFrom-WinForgeWingetTable` com o cabeçalho em espanhol e "Origen"; `Test-WinForgeWingetNoUpgradeOutput` com a saída só de programas deixados de fora.
- **Journal.psm1:** o desfazer `winget-pin`, que confere cada ID, tipo, fonte e faixa de versões do diário antes de chamar o winget, e recusa com o WinForge elevado com outra conta. **Core.psm1:** só o comentário de `Add-WinForgeChange`.
- **Repair.psm1:** `Reset-WinForgePrintQueue` e `Get-WinForgeSpoolFiles`, com os serviços de `WindowsUpdate.psm1` (`Get-WinForgeServiceState`, `Stop-WinForgeService` e `Start-WinForgeService`).
- **NetworkTools.psm1:** `Sync-WinForgeTime`, `Get-WinForgeClockOffset`, `Get-WinForgeClockOffsetText`, `Write-WinForgeClockState`, `Invoke-WinForgeTimeResync` e `Get-WinForgeTimeSource`.
- **Navigation.psm1:** os itens `software.winget-repair` (sem cartão), `updates.winget-hold`, `repair.print-queue` e `network.time`; **GuiDesign.psm1:** o ícone de cada um. São 106 itens.
- **Traduções:** 187 textos novos, 5.558 ao todo.
- **Documentos:**
  - o `CHANGELOG.md`: as seis funções, os dois problemas que já existiam, o que pede conferência e a Estrutura;
  - o mapa de funcionalidades: os itens, as contas, os sinais e o Histórico de mudanças;
  - a documentação técnica: a tabela das páginas, os itens sem cartão, os módulos, o desfazer `winget-pin`, o que fica no Windows, o que vai para a internet, a conta dos textos (que estava em 5.344) e os riscos;
  - a avaliação (R35): o que foi feito de N5 a N10 e o que mudou da proposta;
  - o roteiro de conferência (no projeto): §28.

**Conferido na nuvem pelo QA**
- **257 conferências, nos três idiomas,** com o Windows simulado:
  - **a ativação:** cada LicenseStatus; a consulta com o produto do Windows, a chave instalada e prazo; dois produtos com chave; nenhum; um valor estranho; sem resposta; a linha em Sobre este PC, logo depois da build, com e sem como ativar; o relatório; o Início sem a consulta;
  - **a integridade da memória:** em uso, configurada e fora de uso, só o Credential Guard, nada configurado, propriedades vazias, sem resposta e sem instância; o ponto da auditoria em cada estado, com e sem Administrador; fora da nota; na tela, em "Só para saber", sem virar ponto de atenção;
  - **as tabelas do winget:** em inglês, português e espanhol, com as colunas no lugar; o rodapé dos marcados nos três idiomas, o da versão desconhecida, a tabela com o rodapé, um erro do winget e a frase de erro de um pacote marcado; Atualizar programas só com marcados, com a lista e em dia; o Verificar o PC e o monitor (com um controle de três programas);
  - **o reparo do winget:** já funcionando, registrado, o pacote que não está no PC (com e sem a Store), o registro sem efeito, outra conta, a faixa com o botão, o item e a linha do menu de texto;
  - **os programas na versão atual:** a leitura dos marcadores nos três idiomas (com um programa chamado "Blocking", um marcado em duas fontes e a lista vazia); 24 IDs, válidos e recusados (espaços, "-", aspas, símbolos, caracteres de controle e invisíveis, IDs inventados e cortados); cada comando do winget e cada código de saída; a lista, a ordem e a linha de cada programa; marcar e tirar; o histórico e o desfazer lido de volta do arquivo, inteiro, em parte, com o diário adulterado, com outra conta e sem o winget; um marcador que já existia; desmarcar tudo; cancelar; uma falha no meio; outra conta; o winget antigo; nada para mostrar; a lista de versões novas que falhou; sem o winget; o item e a ordem na página;
  - **a impressão:** só reiniciar, apagar, cancelar, sem resposta, fila vazia (Sim e Não), Spooler desativado, sem o serviço, sem resposta do serviço, que não para, que não liga, sem Administrador e a pasta da fila que aponta para outro lugar;
  - **o relógio:** os textos de adiantado e atrasado; sincronizar com o serviço parado; muito errado com Sim e com Não; PC de domínio; serviço desativado com o relógio certo e errado; o Windows configurado para não sincronizar; sem o servidor da Microsoft, com o `w32tm` dando certo e falhando (com o `/rediscover`); o resultado pela hora conferida e não pelo texto do `w32tm`; o relógio que o Windows não deixa mudar; sem o serviço; sem Administrador; o serviço que não liga; e `Get-WinForgeClockOffset` de verdade contra um servidor HTTP local: adiantado, 3 dias atrasado, certo, uma cópia guardada no caminho (Age), um portal de Wi-Fi, um redirecionamento, dois cabeçalhos Date e sem servidor;
  - **a navegação:** cada item novo, a frase até 60 letras, a função, o ícone e a busca em cada idioma;
  - **os textos:** nenhum texto em português nas telas em inglês e em espanhol, nenhum `{0}` sobrando.
- **46 defeitos de propósito,** e as conferências pegam todos: um em cada regra das seis funções e das duas correções (a ativação não reconhecida, a consulta sem a chave, o prazo virando ativado; a integridade configurada virando em uso, entrando na nota, sem pedir o Administrador; o cabeçalho em espanhol e o "Origen" de volta; o rodapé virando "não deu para ler" ou sempre "em dia"; o reparo sem conferir antes, com outra conta, sem o botão, sem conferir depois; o `--force`, o desfazer com o tipo errado, sem conferir o diário, o tipo mais fraco vencendo, o "-" aceito, a outra conta; apagar tudo da pasta da fila, ler a pasta que aponta para outro lugar, ligar o Spooler desativado, apagar com o serviço ligado, sem religar os dependentes, apagar em destaque; o relógio para o lado errado, mudar o relógio de um PC de domínio, ligar o serviço desativado, ignorar o NoSync, "certo" com um minuto de diferença, sem o Age, aceitar o portal, sem o `/rediscover`, o resultado pelo código do `w32tm`; a impressão sem Administrador e o reparo como cartão).
- **As APIs do .NET e os comandos:** 43 de 43 estão no perfil do Windows PowerShell 5.1 do PSScriptAnalyzer (as do `HttpWebRequest` e da resposta, o `ParseExact` com `DateTimeStyles`, o `TimeZoneInfo.Local`, o `RequestCachePolicy`, o `Add-AppxPackage -RegisterByFamilyName -MainPackage`, o `Set-Date -Date`, o `Get-CimInstance -Namespace -OperationTimeoutSec`, entre outras).
- **Nada do que funcionava quebrou:**
  - as baterias das 14 páginas revistas: Diagnóstico (212, 224 e 224), Segurança (134, 142 e 142), Limpeza (178, 187 e 187), Desempenho (96, 102 e 102), Ajustes do Windows (412, 422 e 422), Personalização (265, 270 e 270), Sobre o WinForge (164, 169 e 169), Busca (109, 98 e 101), Verificar o PC (146, 147 e 147) e Otimizar (146, 151 e 151), com os mesmos números da R34; Reparo (114, 121 e 121), Atualizações (112, 119 e 119), Programas (108, 117 e 117) e Rede (146, 155 e 155), com as conferências a mais do item novo de cada página;
  - três conferências antigas contavam os itens de antes: os 102 itens, as 87 frases inteiras e a lista dos itens com escudo na Rede. Com os itens novos nas contas, passam (dados: 46; R9: 59, 58 e 58; Rede, acima);
  - a Manutenção (243, 245 e 250), o Início (241 em cada idioma), as mensagens da janela (72 em cada idioma), as conferências da R10 à R12 e as gerais (código, frente, R7, as 66 correções da QA e as 28 da integração);
  - instalar, atualizar com um clique e o pacote de suporte; o Setup de verdade, da R34 para esta: saída 0, os arquivos trocados e as notas da pessoa mantidas; o zip com 58 arquivos;
  - as traduções (diferentes = 0, 5.558 textos), as 166 referências com "Página > Item" nos três idiomas (eram 159; as sete novas são das funções novas) e a busca, que acha os 106 itens nos três idiomas;
  - os documentos: o mapa, o CHANGELOG e os READMEs conferidos contra o código (145, com a conta dos itens fora da lista em quatro) e cada nome citado na documentação técnica (223);
  - as funções sem referência (nenhuma, entre 1.477) e nenhuma chamada a uma função que não existe;
  - o PSScriptAnalyzer: os mesmos 235 avisos da R34, nenhum novo.

**Validado pelo MVP Windows**, na documentação da Microsoft e no código do winget:
- **A ativação:** o `SoftwareLicensingProduct` (Root\CIMV2) tem o `LicenseStatus` de 0 a 6 (0 Unlicensed, 1 Licensed, 2 OOBGrace, 3 OOTGrace, 4 NonGenuineGrace, 5 Notification, 6 ExtendedGrace), e o `PartialProductKey` "returns a null value if a product key is not installed". O filtro pelo produto do Windows (`ApplicationId = '55c92734-d682-4d71-983e-d6ec3f16059f'` com `PartialProductKey <> null`) é o mesmo que um engenheiro da Microsoft passou no Tech Community.
- **A integridade da memória:** a Microsoft manda ler `Win32_DeviceGuard` em `root\Microsoft\Windows\DeviceGuard`: o valor 2 em `SecurityServicesConfigured` é "memory integrity is configured", e em `SecurityServicesRunning`, "memory integrity is running". O caminho na Segurança do Windows é o da página de suporte em português ("Detalhes de isolamento do núcleo"), e a própria Microsoft avisa que "some applications and hardware device drivers may be incompatible with memory integrity".
- **O reparo do winget:** "If you have recently logged in as a user for the first time and find that WinGet is not yet available, you can open PowerShell and enter the following command to request this WinGet registration: `Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe`". Sem o Instalador de Aplicativo, a Microsoft aponta a página dele na Store (9NBLGGH4NNS1), a mesma que o WinForge já abria.
- **Os programas na versão atual:**
  - o marcador comum: "The package is excluded from `winget upgrade --all` but allows `winget upgrade <package>`"; e "a pinned package may still upgrade on its own and be upgraded from outside the Windows Package Manager", por isso a frase dos programas que se atualizam sozinhos;
  - no código do winget: a lista do `winget upgrade` pula os marcados e só conta quantos ficaram de fora, num rodapé com o `--include-pinned` que não se traduz; o tipo do marcador no `winget pin list` é o nome interno (Pinning, Blocking, Gating) em qualquer idioma; o `pin add` com um marcador diferente já posto termina em 0x8A150062, e o `pin remove` sem marcador, em 0x8A150063; um comando que o winget não conhece termina em 0x8A150002; os marcadores ficam no `pinning.db` da pasta do Instalador de Aplicativo, no perfil da conta;
  - os títulos das colunas nos três idiomas são os das traduções do próprio winget ("Nombre", "Origen"; "Nome", "Origem").
- **A impressão:** a ordem da Microsoft é "Cancel print jobs", "Restart the Print Spooler service" e, "if canceling jobs does not clear the queue", parar o Spooler, apagar os arquivos de `C:\Windows\System32\spool\PRINTERS` e ligá-lo de novo.
- **O relógio:**
  - `/resync` "tells a computer that it should resynchronize its clock as soon as possible"; `/rediscover` "redetects the network configuration, rediscovers network sources, and then resynchronizes"; o `w32tm` pede o Administrador;
  - num PC fora de domínio, `MaxPosPhaseCorrection` e `MaxNegPhaseCorrection` são de 54.000 segundos (15 horas): "if the service determines that a change larger than this value is required, it logs an event instead". Num PC de domínio, o padrão é corrigir sempre;
  - o `Type` NoSync "does not synchronize time";
  - "The computer did not resync because no time data was available": a Microsoft aponta o DNS, a porta UDP 123 bloqueada e o servidor que não responde como NTP;
  - o servidor do teste de internet do Windows é `www.msftconnecttest.com`, por HTTP, e a resposta esperada é "Microsoft Connect Test".
- **O que só um PC confirma:** o roteiro, §28.

**Limites que ficam**
- **A ativação leva alguns segundos** em Sobre este PC e no relatório.
- **Listar programas instalados** continua contando "com atualização" também os programas marcados (o `winget list` mostra a versão nova de todos); **Atualizar programas** diz quantos desses ficaram de fora.
- **Um programa com o ID cortado na tabela do winget** (um ID muito comprido) não aparece em Manter programas na versão atual: o `winget pin` precisa do ID inteiro.
- **Os marcadores feitos com `--installed`** (por fora do WinForge) podem não sair pelo WinForge: o `winget pin remove --id` procura o programa nas fontes. Quando falha, a tela diz qual e o motivo.
- **A hora do servidor tem um a dois segundos de folga:** até 10 segundos de diferença, o relógio conta como certo.
- **O acerto direto do relógio** usa a hora do servidor da Microsoft, com a mesma folga; o Windows sincroniza logo depois, quando pode, e acerta os segundos.

**Fontes**
- Microsoft: [SoftwareLicensingProduct class](https://learn.microsoft.com/en-us/previous-versions/windows/desktop/sppwmi/softwarelicensingproduct), [Tech Community, Windows Server vNext cannot be activated (a resposta com o filtro)](https://techcommunity.microsoft.com/discussions/windowsserverinsiders/windows-server-vnext-cannot-be-activated/4525762/replies/4529909), [Enable memory integrity](https://learn.microsoft.com/en-us/windows/security/hardware-security/enable-virtualization-based-protection-of-code-integrity), [Segurança do dispositivo no aplicativo Segurança do Windows](https://support.microsoft.com/pt-br/help/4096339), [Use WinGet to install and manage applications](https://learn.microsoft.com/en-us/windows/package-manager/winget/), [pin command (WinGet)](https://learn.microsoft.com/en-us/windows/package-manager/winget/pinning), [Fix print job stuck in queue errors in Windows](https://support.microsoft.com/en-us/windows/fix-print-job-stuck-in-queue-errors-in-windows-9ee21bad-4488-45b5-b497-2d8299bd74aa), [Windows Time service tools and settings](https://learn.microsoft.com/en-us/windows-server/networking/windows-time-service/windows-time-service-tools-and-settings), [Parameters\Type Subkey](https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-server-2003/cc737179(v=ws.10)), [Error message when you run w32tm /resync: no time data was available](https://learn.microsoft.com/en-us/troubleshoot/windows-server/identity/error-message-run-w32tm-resync-no-time-data-available), [NCSI overview](https://learn.microsoft.com/en-us/windows-server/networking/ncsi/ncsi-overview)
- O código do winget: [microsoft/winget-cli](https://github.com/microsoft/winget-cli) (`WorkflowBase.cpp`, `UpdateFlow.cpp`, `PinFlow.cpp`, `PinCommand.cpp`, `Core.cpp`, `Pin.cpp`, `PinningIndex.cpp` e as traduções em `Localization/Resources`)
- O caminho da integridade da memória em espanhol: [Riot Games, Habilitar la integridad de memoria](https://support.riotgames.com/es-es/riot/support-tools/enable-memory-integrity)

**Entregue:** `WinForge.zip`, `WinForge-codigo-fonte.zip` e `historico-4.0.md`.

---

## R37 — O desenho novo do WinForge

**Data:** 21/11/2026 · **Commit:** b4f4662

**Pedido:** com a imagem de um Início redesenhado (tema escuro, laranja na bigorna e nos botões, a nota "100 / 100" grande com dez traços e uma faixa inclinada atrás, três cartões, a linha da manutenção e do reinício, "Histórico neste PC" e a faixa do monitor no fim): "É possível deixar o WinForge neste design? Não faça ainda, apenas me diga se é possível?". Depois da resposta (é possível, com duas escolhas: o laranja como cor da marca, com o ícone, e o tema claro), o pedido foi "Faça".

**A leitura adotada, dita no começo:** seguir a imagem nas duas escolhas. O laranja vira a cor da marca, com a face da bigorna do ícone em laranja, e o tema claro usa um laranja mais escuro, para o texto continuar legível.

**O que mudou para quem usa**
- **As cores, nos dois temas:**
  - o escuro é o da imagem: a janela `#171A1C`, a barra lateral `#1C2022`, os cartões `#202527`, o texto `#F1EEE7`, o laranja `#F49367` (com o texto escuro em cima) e o verde e o amarelo mais suaves;
  - o claro usa os mesmos tons, com um laranja mais escuro (`#B9501E`, com o texto branco em cima, e `#A5451A` nos links e nos ícones de destaque);
  - nenhum azul da marca sobrou; os temas de contraste do Windows continuam com as cores deles.
- **O ícone:** a bigorna branca com a face laranja no arquivo do ícone (a barra de tarefas, o Alt+Tab, a barra de título e os atalhos) e no desenho do ícone (`WinForge.svg`). Os dez tamanhos são os mesmos de antes.
- **A barra lateral:** no alto, a bigorna desenhada (do mesmo desenho do ícone, que acompanha o tamanho do texto) e o nome WinForge em negrito; a barra tem um tom à parte e uma linha fina à direita; a versão saiu do alto e foi para baixo de **Sobre o WinForge**, menor.
- **Os títulos:** o nome da página com 40, em negrito, em todas as páginas; o título da tela de execução com 28, em negrito; os títulos das partes do Início com 20, em negrito. A fonte deles é a Segoe UI Variable Display quando o Windows tem o negrito dela (no Windows 11); senão, a Segoe UI.
- **O Início:**
  - **a nota de saúde** num cartão próprio: "Saúde do PC" com o ícone e a cor da nota, a frase em letras grandes, o resumo e os dois caminhos (**Verificar o PC**, com um ícone novo, e **Otimizar**), maiores que os botões comuns; à direita, a nota em números grandes ("100 / 100"), dez traços na cor da nota e "Atualizado às …" com o botão de ler de novo, sobre a faixa inclinada da imagem, com duas linhas finas no lado inclinado;
  - numa janela estreita ou com o texto do Windows grande, a nota vai para baixo dos botões, sem a faixa; no contraste alto, a faixa não aparece;
  - **Seu PC:** três cartões, **Disco do sistema** (o espaço livre, "de … GB", quanto está em uso e a barra de uso, amarela com o disco quase cheio), **Proteção** e **Sistema** (era Windows); embaixo, um cartão dividido com a última manutenção, o reinício pendente e, num notebook, a bateria, cada um com o valor à direita;
  - **Histórico neste PC** (era "Com o WinForge neste PC"): os três números grandes direto na página, com um traço entre eles;
  - **a configuração inicial** (era "Deixe o WinForge pronto") foi para o fim, como a faixa do monitor da imagem: o ícone e o nome do próximo passo, "Configuração inicial · 1 de 3 etapas concluídas", **Agora não** e o botão do passo.
- **Nada cortado:** os valores grandes (a frase da nota, o número, o valor dos cartões e os números do histórico) diminuem até caber, sem quebrar nem cortar. Os cartões, as partes da linha e os números do histórico ficam lado a lado quando o texto de cada um cabe inteiro na coluna; senão, um embaixo do outro. Um embaixo do outro, o histórico fica sem o traço e sem o recuo.

**Um problema achado no caminho, corrigido**
- **A prévia em espanhol cortava a linha do Início.** A regra que decidia as colunas usava uma largura fixa (240 por parte, vezes o tamanho do texto). Medindo os nomes e os valores, "Último mantenimiento" com "Hace 11 meses" pede cerca de 320, e em português "Última manutenção" com "Há 11 meses", perto de 290: na janela padrão, num notebook (três partes de cerca de 280), o nome saía com reticências. Agora a regra mede o texto de agora (`Measure`, com espaço sem limite) e só põe lado a lado o que cabe inteiro, nos três idiomas e com qualquer tamanho de texto. Os cartões usam a mesma medida, sem o valor grande, que diminui até caber.

**Decisões, com o motivo**
- **"Atualizado às", e não "Verificado às" (como na imagem):** o Início lê o PC, não verifica; "verificar" é o que o **Verificar o PC** faz.
- **"Liberado nas manutenções", e não "Espaço liberado":** o número conta só o que as manutenções liberaram, e é o mesmo nome da linha do Histórico de manutenções.
- **"Mudanças anotadas" com "27 com desfazer":** o número conta todas as mudanças anotadas; dizer só "com desfazer" no título contaria errado.
- **"Sistema" no cartão do Windows** e **"Histórico neste PC"** vieram da imagem; "Sistema" já tinha tradução (System, Sistema).
- **Os botões da configuração inicial continuam com o verbo do passo** (Criar, Ligar, Agendar), e não um botão genérico: cada passo faz uma coisa diferente.
- **Os contornos dos botões e dos campos mais claros que os da imagem:** com o cinza da imagem, ficavam abaixo de 3:1 sobre o cartão, o mínimo para um controle (WCAG 2.2, 1.4.11).
- **O verde e o amarelo do tema claro continuam os do Windows** (`#0F7B0F` e `#9D5D00`): passam de 4,5:1 em todos os fundos claros, também na barra lateral.
- **A bateria entra na linha**, como a terceira parte, só num notebook; a imagem é de um PC de mesa.
- **O nome da página com 40 em negrito em todas as páginas**, e não só no Início: a barra lateral e o título são iguais em todas.
- **O tamanho da janela continua 1180 x 760:** a imagem é de uma tela maior; numa janela menor, as regras de arranjo cuidam do resto.
- **A faixa inclinada some no contraste alto e com a nota embaixo:** no contraste alto, só as cores do sistema; embaixo, a faixa passaria atrás dos botões.
- **A fonte dos títulos só com o negrito de verdade:** a Segoe UI Variable Display entra quando o Windows tem a face em negrito dela; com o negrito simulado (o Windows "engorda" as letras), vale a Segoe UI. A Microsoft diz que um negrito não simulado "é geralmente desenhado para ter uma aparência melhor que um negrito simulado".

**Por dentro**
- **GuiDesign.psm1:**
  - as duas paletas novas, com as chaves `Hero` (o cartão da nota), `HeroPanel` (a faixa) e `Bar` (a barra de uso do disco), que no contraste alto ficam com a cor da janela e a do texto; as 16 cores dos detalhes técnicos de cada tema;
  - `Display` (68, entrelinha 92) na escala;
  - o ícone `scan` (os cantos e o visto), usado pelo Verificar o PC, e a face laranja em `Get-WinForgeLogoDrawing`;
  - as regras do desenho, sem WPF: `Get-WinForgeScoreMarks` (quantos traços cheios), `Get-WinForgeHomeColumns` (todos lado a lado ou um embaixo do outro), `Test-WinForgeHeroWide` (a nota ao lado ou embaixo) e `Get-WinForgeHeroBand` (os pontos da faixa e das duas linhas).
- **MainWindow.xaml:** as cores iniciais do tema claro; os recursos `DisplayFont` e `TitleLargeSize`; a linha da barra lateral; o logotipo desenhado (a bigorna em dois caminhos, a face na cor de destaque e o corpo na do texto, e o nome), no lugar da imagem do ícone e da versão (`LogoImage` e `BuildText` saíram); o nome da página e o título da tela de execução em negrito, na fonte dos títulos.
- **WinForge.Gui.ps1:**
  - `Get-GuiDisplayFont` e a fonte dos títulos em `Set-GuiTypography`; `New-GuiText -Display`; `New-GuiValueBox` (a `Viewbox` que só diminui); `Add-GuiNavButton -Note` (a versão embaixo de Sobre o WinForge); `New-GuiSectionHeading` em 20 negrito; o destaque das páginas (`New-GuiHeroCard`) no fundo do cartão da nota;
  - a nota: `New-GuiScoreBlock` (o número, "/ 100", os traços e a hora), `Set-GuiHeroLayout`, `Update-GuiHeroBand` e `Update-GuiHealthCard` reescrita; saíram `New-GuiScoreRing` e `Set-GuiHealthLayout`;
  - Seu PC: `New-GuiHomeCard`, `New-GuiHomeSkeleton`, `New-GuiHomeStrip`, `Update-GuiHomeStripLayout` e `Set-GuiHomeCardText` (chamada por `Set-GuiHomeFact`);
  - as colunas: `Set-GuiHomeColumns`, `Update-GuiHomeColumns`, `Measure-GuiNaturalWidth`, `Get-GuiHomeFitWidth` e `Set-GuiHomeDividers`;
  - `New-GuiValueSummary` (Histórico neste PC) e `New-GuiSetupCard` (a configuração inicial) reescritas; `Show-GuiHomePage` na ordem nova.
- **Home.psm1:** o nome Sistema no cartão do Windows e o uso do disco (`Usage`, de 0 a 100, arredondado para cima no meio) no fato do disco; a verificação rápida e o relatório continuam com os mesmos campos de antes. **Agent.psm1** e **Maintenance.psm1:** só os comentários com os nomes novos.
- **assets:** `WinForge.svg` e `WinForge.ico` com a face laranja.
- **Traduções:** 4 textos novos ("Configuração inicial", "Configuração inicial · {0} de {1} etapas concluídas", "Histórico neste PC" e "{0}% em uso") e 4 que saíram, sem uso ("Deixe o WinForge pronto", "{0} de {1} feitos · próximo: {2}", "Com o WinForge neste PC" e "de 100"); 5.558 ao todo.
- **Documentos:** o `CHANGELOG.md` (o resumo, a primeira abertura, a janela, o Início, o que pede conferência e a Estrutura); o mapa de funcionalidades (a janela e o Início); a documentação técnica (o Início, os módulos, o arranjo do Início e o visual: as cores, o contraste e a tipografia; a janela com 7.294 linhas e 182 funções, e os módulos com 1.286 funções: a conta dos módulos tinha ficado em 1.262 na R36, que acrescentou 20); o roteiro de conferência (no projeto): §29, e as linhas que falavam do azul, do anel e dos nomes antigos.

**Conferido na nuvem pelo QA**
- **209 conferências em português e 210 em inglês e em espanhol,** com as funções de verdade do `WinForge.Gui.ps1` sobre um WPF simulado:
  - **as cores:** as mesmas chaves nos dois temas; o laranja de cada um; nenhum azul da marca de antes; todo texto acima de 4,5:1 em todos os fundos (a janela, a barra lateral, os cartões, o cartão da nota e a faixa), os contornos, o foco, os traços da nota e a barra do disco acima de 3:1, e as 16 cores dos detalhes técnicos acima de 4,5:1; o contraste alto; as cores iniciais do XAML iguais às do tema claro;
  - **o desenho:** os traços cheios de 13 notas (de -1 a 150, com 9, 10, 89, 90 e 95, que ficam nos limites); as colunas no limite, sem largura e com uma parte; a nota ao lado e embaixo; a faixa, as duas linhas, sem passar da borda e sem tamanho;
  - **os dados:** o uso do disco (o arredondamento no meio, sem tamanho, sem leitura); o nome Sistema; a ordem dos cartões; a verificação rápida sem campos novos;
  - **o texto:** o negrito e a fonte dos títulos pelo recurso, a entrelinha, o texto grande que só diminui;
  - **a nota:** nos dois temas, o cartão, a faixa num `Canvas`, as cores, a frase, o número e "/ 100", os dez traços, os botões, a hora, o leitor de tela, largo, estreito e largo de novo; a nota 100 e uma com o disco quase cheio e a manutenção atrasada (os traços, a cor e o botão do ponto mais pesado); lendo, sem conseguir calcular e sem leitura; o contraste alto; o texto a 225%;
  - **Seu PC, a linha, o histórico e a configuração inicial:** a ordem da página; os cartões na largura da coluna; enquanto lê; o disco com o uso, quase cheio e com usos estranhos (sem, 150, negativo, em texto); a linha com e sem a bateria, estreita e larga; **a medida do texto** (uma parte que não cabe inteira fica embaixo, mesmo acima do mínimo; um valor mais curto volta a caber; o valor grande dos cartões não conta; um complemento comprido põe os cartões um embaixo do outro, e um curto os devolve lado a lado); o histórico com e sem o traço e o recuo; a configuração inicial, o botão, o "Agora não" e o escudo; a leitura guardada e a troca de tema;
  - **a barra lateral e as fontes:** a versão embaixo de Sobre o WinForge, com o leitor de tela; a escolha da fonte dos títulos no Windows 11, com o negrito simulado, no Windows 10 e sem a lista de fontes;
  - **o XAML e o ícone:** o nome da página, o título da tela de execução, os recursos, nenhum tamanho de letra escrito no XAML, o logotipo com os traços do SVG, a linha da barra lateral, o ícone com os dez tamanhos (do 16 ao 48 em BMP, do 64 ao 256 em PNG);
  - **os textos:** no idioma da tela, nenhum texto em português em inglês e em espanhol, nenhum `{0}` sobrando.
- **54 defeitos de propósito,** e as conferências pegam todos: um em cada regra (o traço a mais, as colunas no limite, a nota ao lado sem lugar, a faixa passando da borda ou no contraste alto ou num `Grid`, o texto discreto escuro demais, o azul de volta, o amarelo do claro abaixo de 4,5:1, o ícone velho, a face azul no desenho da janela e no SVG, o título sem a fonte dos títulos, o texto grande que estica, o cartão da nota no fundo comum, a barra do disco acima de 100 e sem o amarelo, a linha que não se refaz, o traço antes da primeira parte, a linha medindo só o mínimo, os cartões ignorando o texto, o valor grande entrando na medida, a moldura fora da medida, o texto que chega sem refazer as colunas, o histórico empilhado com o traço, a configuração inicial colada no histórico, o nome Windows de volta, o uso arredondado para o par, a página no tamanho de antes, a face da bigorna na cor do texto, a barra lateral sem a linha, entre outros).
- **O WPF simulado** foi conferido contra o perfil do Windows PowerShell 5.1 do PSScriptAnalyzer: 72 tipos, 2.052 membros, nenhum que o Windows PowerShell não tenha (entre eles `UIElement.Measure(Size)` e `DesiredSize`). No caminho, alguns valores padrão do simulado estavam diferentes dos do WPF e foram corrigidos (o `StackPanel` vertical, os alinhamentos `Stretch`, o `TextWrapping` `NoWrap`, a `Viewbox` `Uniform`/`Both` e o peso `Normal`); a bateria acima já roda com eles.
- **A prévia:** o Início montado pelas funções de verdade e desenhado no navegador, com a fonte Inter no lugar da Segoe UI (que não existe na nuvem): escuro e claro numa janela de 1380, o escuro na de 900 (a menor) e o claro em espanhol na de 1180 (a padrão). Ela mostrou o corte da linha em espanhol e o histórico empilhado com o traço, corrigidos acima.
- **Nada do que funcionava quebrou:**
  - as baterias das 14 páginas revistas, com os mesmos números da R36: Diagnóstico (212, 224 e 224), Segurança (134, 142 e 142), Limpeza (178, 187 e 187), Desempenho (96, 102 e 102), Reparo (114, 121 e 121), Atualizações (112, 119 e 119), Programas (108, 117 e 117), Rede (145, 154 e 154, com a mesma conferência antiga da lista dos itens com escudo que a R36 já explicou), Ajustes do Windows (412, 422 e 422), Personalização (265, 270 e 270), Sobre o WinForge (164, 169 e 169), Busca (109, 98 e 101), Verificar o PC (146, 147 e 147) e Otimizar (146, 151 e 151);
  - quatro conferências antigas descreviam o desenho de antes e falham de propósito: o cinza do contorno no cartão escuro e o da linha da barra lateral (R10, "o mesmo cinza de antes"), o ícone do Verificar o PC na nota (R9 e R10, que procuravam o `check-circle`) e a nota ao lado da frase (R10, que procurava `Set-GuiHealthLayout`). Com os valores novos, as cópias passam: R9 59, 58 e 58; R10 52 em cada idioma. Os dados passam com a conta de itens da R36 (46);
  - o Início da R13 (241 em cada idioma), a Manutenção (243, 245 e 250), as mensagens da janela (72 em cada idioma), as conferências da R11 e da R12 e as gerais (código, frente, R7, as 66 correções da QA e as 28 da integração);
  - instalar, atualizar com um clique e o pacote de suporte; o Setup de verdade, da R36 para esta: saída 0, os 58 arquivos trocados pelos do pacote e as notas da pessoa mantidas; o zip com 58 arquivos;
  - as traduções (diferentes = 0, 5.558 textos), as 166 referências com "Página > Item" nos três idiomas (as mesmas da R36) e a busca, que acha os 106 itens nos três idiomas;
  - os documentos: o mapa, o CHANGELOG e os READMEs conferidos contra o código (145) e cada nome citado na documentação técnica (230; eram 223); no CHANGELOG da 4.0, os nomes que não existem mais são só os que ele diz que saíram;
  - as funções sem referência (nenhuma, entre 1.494; eram 1.477) e nenhuma chamada a uma função que não existe; o XAML lido como XML;
  - o PSScriptAnalyzer: 245 avisos, os 235 da R36 e 10 dos dois tipos que todos os manipuladores de evento do arquivo já tinham (o nome `$sender`/`$eventArgs` e o `$eventArgs` sem uso), um para cada um dos quatro manipuladores novos (`param ($sender, $eventArgs)`, o padrão do arquivo: eram 38, são 42).

**Validado pelo MVP Windows**, na documentação:
- **A `Viewbox` que só diminui:** `StretchDirection.DownOnly` — "The content scales downward only when it is larger than the parent. If the content is smaller, no scaling upward is performed."
- **A medida do texto:** `UIElement.Measure` "Updates the DesiredSize of a UIElement", e o espaço dado "can be any number from zero to infinite". Com espaço sem limite, o texto diz a largura inteira; o WPF mede de novo com a largura de verdade no passo seguinte do layout, que é assíncrono.
- **O negrito de verdade:** `Typeface.IsBoldSimulated` diz se o Windows simula o negrito, e "uma fonte em negrito não simulada é geralmente desenhada para ter uma aparência melhor que uma fonte em negrito simulada".
- **O contraste:** WCAG 2.2, 1.4.3 (texto, 4,5:1) e 1.4.11 (componentes e gráficos, 3:1 "against adjacent color(s)").
- **O que só um PC confirma:** o roteiro, §29.

**Limites que ficam**
- **A prévia usou a Inter**, mais larga que a Segoe UI: no Windows, o texto ocupa um pouco menos, e a regra das colunas mede o texto de lá.
- **O ícone antigo pode aparecer** na barra de tarefas e nos atalhos até o Windows reler os ícones (o Explorador guarda os ícones em cache, como na R34).
- **A fonte dos títulos** depende de o Windows ter a Segoe UI Variable Display em negrito; num Windows 11 sem ela, os títulos ficam na Segoe UI em negrito.

**Fontes**
- Microsoft: [StretchDirection Enum](https://learn.microsoft.com/dotnet/api/system.windows.controls.stretchdirection), [UIElement.Measure(Size)](https://learn.microsoft.com/dotnet/api/system.windows.uielement.measure), [Typeface.IsBoldSimulated](https://learn.microsoft.com/fr-fr/dotnet/api/system.windows.media.typeface.isboldsimulated)
- W3C: [Understanding SC 1.4.3 Contrast (Minimum)](https://w3.org/WAI/WCAG22/Understanding/contrast-minimum.html), [Understanding SC 1.4.11 Non-text Contrast](https://w3.org/WAI/WCAG22/Understanding/non-text-contrast)

**Entregue:** `WinForge.zip`, `WinForge-codigo-fonte.zip`, `historico-4.0.md` e as prévias do Início.

---

## R38 — Revisão de UX/UI

**Data:** 21/11/2026 · **Commit:** 822b035 (só documentação; o programa não mudou)

**Pedido:** "Como um analista de UX/UI, revise o sistema."

**O resultado** está em `docs/revisao-ux-4.0.md`, no formato da R8:
- o veredito e um placar com as notas da R8 ao lado;
- o que a R8 pediu e onde está;
- 21 achados (UX10 a UX30, continuando a numeração da R8), cada um com a evidência, a proposta, a gravidade, o esforço e o risco;
- o que não mudar;
- um plano em três fases;
- dez imagens em `docs/revisao-ux/`: cinco de hoje e cinco das propostas.

**Como foi feita:**
- **As telas, pelo código de verdade:** as funções da janela montaram 12 páginas e a busca sobre o WPF simulado da R37, nos dois temas, nos três idiomas, com e sem Administrador e na largura mínima.
- **As 88 ações, no modo janela:** 176 execuções, aceitando e cancelando, com as mudanças no PC bloqueadas, guardando o texto das perguntas, das opções e das faixas.
- **As maquetes das propostas:** as mesmas funções com só a mudança proposta, numa cópia fora do WinForge.

**Os principais achados**
- **O que mais rende:** a chave de um ajuste abre a tela de execução e pede Voltar, e a página lê tudo de novo; a proposta é a chave mudar na própria linha (UX19).
- **Um defeito à vista:** na Rede, o destaque cai no meio da lista, colado no grupo de cima, porque os itens seguintes do mesmo grupo entram no cartão que já está acima (UX10).
- **Peças antigas ao lado das novas:**
  - o cartão da Manutenção (UX11);
  - o quadrado laranja cheio do destaque (UX12);
  - o parágrafo do alto de Ajustes (UX14);
  - o carregamento escrito (UX16).
- **Os ajustes ficaram fora da regra das 60 letras:** 50 das 53 descrições passam (UX15).
- **Perguntas e faixas:**
  - a pasta é digitada em seis ações (UX20);
  - 56 das 60 perguntas de Sim e Não não dizem o verbo no botão (UX21);
  - a duração aparece duas vezes (UX22);
  - um erro inesperado chega cru (UX23).
- **Três textos escapam da tradução:** duas dicas do terminal em inglês e espanhol (UX24) e o título "Avisos pausados" do monitor (UX25).
- **A busca:** "limpar" põe a Limpeza rápida em 5º, depois de duas ações do grupo Avançado (UX26).
- **Fora da janela:** o menu do terminal tem outra ordem de páginas (UX29), e o instalador é uma janela de texto (UX30).

**O plano**
- **Fase 1** (pequena, cabe na 4.0): dez itens de esforço pequeno e risco baixo, como o destaque no alto, a faixa de resumo, a duração uma vez só e os textos fora da tradução.
- **Fase 2:** a chave na própria linha primeiro; depois o "Procurar...", o verbo nos botões, o erro em palavras, as descrições dos ajustes e os ícones.
- **Fase 3:** o instalador com janela, junto com a decisão da assinatura (I2).

**Por dentro**
- `docs/revisao-ux-4.0.md` e `docs/revisao-ux/` (novos).
- A documentação técnica: o repositório com 104 arquivos e o documento novo nos documentos relacionados.
- Nenhuma linha de código mudou.

**Entregue:** `revisao-ux-4.0.md`, as imagens, `historico-4.0.md` e `WinForge-codigo-fonte.zip`. O `WinForge.zip` não muda, porque o programa não mudou.

---

## R39 — O Início e os destaques no Windows de verdade

**Data:** 21/11/2026 · **Commit:** 853abc3

**Pedido:** com o print do Início no Windows, só com a linha da última manutenção e do reinício e com a configuração inicial: "Tela inicial bugada".

**O que acontecia no Windows**
- **No Início,** não apareciam o cartão da nota, "Seu PC" com os três cartões e o "Histórico neste PC". Do histórico, sobrava só o traço fino embaixo do título, que explica o espaço a mais antes da configuração inicial no print.
- **Em cada página,** faltava o destaque: Otimizar, Limpeza rápida, Reparar o Windows e os outros. O print não mostra, mas a causa é a mesma.
- **A fonte da janela** (a Segoe UI Variable, da R9) e **a dos títulos** (a Segoe UI Variable Display, da R37) nunca valeram no Windows 11: a janela ficava na Segoe UI do XAML.

**A causa**
- **O embrulho do PowerShell:** `Set-GuiTypography` guardava as duas fontes com `$window.Resources["DisplayFont"] = New-Object System.Windows.Media.FontFamily (...)`. Pelo indexador, o PowerShell entrega ao dicionário o embrulho (`PSObject`) do objeto que o `New-Object` cria, e não o `FontFamily`. Numa chamada de método ou numa propriedade, o PowerShell desembrulha; pelo indexador, não.
- **A recusa do WPF:** ao aplicar o recurso, o WPF recusa o embrulho ("... is not a valid value for property 'FontFamily'"). Na abertura, o `try` em volta engolia a recusa, e a janela seguia com a Segoe UI.
- **Por que as partes sumiam:** a R37 pôs a fonte dos títulos, pelo recurso, na frase e nos números da nota, em "Seu PC", nos valores dos cartões, no histórico e no nome de cada destaque. Quando uma dessas partes entra na tela (`Children.Add`), o WPF resolve o recurso, recusa, e a entrada falha. Com `$ErrorActionPreference = "Continue"`, a janela segue para a linha seguinte: a parte não aparece, sem aviso nenhum.
- **Em outros projetos:** o Purview_CaseTools e o SmartDeployTool tiveram a mesma recusa com pincéis feitos pelo `New-Object` e guardados pelo indexador, e corrigiram guardando o objeto de verdade.
- **Por que a nuvem não pegou:** o WPF simulado guardava qualquer valor no dicionário e não resolvia os recursos, e o QA não abria a janela como ela abre (as fontes postas por `Set-GuiTypography` e a página ligada à janela).
- **Reproduzido antes de corrigir:** com o WPF simulado novo (abaixo), o código da R38 monta o Início com as mesmas três partes do print, a linha, o traço e a configuração inicial, e a Limpeza sem a Limpeza rápida.

**A correção**
- **`Set-GuiResource` (nova):** todo recurso que o script põe num dicionário do WPF passa por ela, que guarda o objeto de verdade (`.psobject.BaseObject`). Passam por ela as duas fontes, os pincéis do tema, os tamanhos e as entrelinhas, a largura dos cartões (`CardWidth`) e a cópia dos recursos para a janela de mensagem. A chave vai como veio, para os estilos guardados pelo tipo.
- **As fontes pelo construtor:** `[System.Windows.Media.FontFamily]::new(...)`, que não embrulha.
- **O que muda para quem usa:** o Início e os destaques inteiros; no Windows 11, a janela passa a usar a Segoe UI Variable e os títulos a Segoe UI Variable Display, como a R9 e a R37 previam. No Windows 10, nada muda (a Segoe UI).
- **Sem gambiarra:** a regra entrou na documentação técnica (seção 19), e uma conferência do QA recusa qualquer recurso posto pelo indexador direto.

**O WPF simulado, mais perto do de verdade**
- **O dicionário de recursos** guarda o que recebe e recusa o embrulho logo depois, como o WPF faz ao reler o recurso nos controles que o usam.
- **Uma referência de recurso** se resolve quando o controle entra numa árvore ligada à janela; um valor que não é do tipo da propriedade é recusado, e a entrada falha.
- **Um controle com dois pais** é recusado ("already the logical child of another element"); tirar de um painel, trocar o `Child` ou o `Content` solta o de antes. Nenhuma tela tinha esse problema.
- **O `FrameworkElement.WidthProperty`,** que faltava: a largura dos cartões pelo recurso passa a rodar o caminho de verdade, e não o de reserva.
- **O QA da R37 fazia os pincéis pelo `New-Object`;** agora pelo construtor, como o `ConvertFromString` do código.
- **A conferência do simulado contra o perfil do Windows PowerShell 5.1** passou a listar os campos estáticos no tipo que os declara, como o perfil lista.

**Conferido na nuvem pelo QA**
- **38 conferências em cada idioma,** com a janela aberta como no PC (as raízes ligadas à janela, o tema e a fonte postos na abertura, e um erro de uma linha sem parar a página):
  - os recursos: as duas fontes como `FontFamily`, a abertura sem nenhuma recusa, nenhum recurso embrulhado nos dois temas (72), a largura dos cartões como número;
  - `Set-GuiResource`: um objeto do `New-Object`, numa variável e devolvido por uma função entram como eles mesmos; o número, o vazio e a chave pelo tipo;
  - o simulado: recusa o embrulho, o controle com dois pais e a entrada na janela com a fonte embrulhada;
  - o Início inteiro, na ordem: a nota com a frase, "Seu PC" na fonte dos títulos, os três cartões com os valores, a linha, o histórico com os números e a configuração inicial;
  - o destaque de cada uma das nove páginas que têm um, e o Criar atalho do Sobre o WinForge;
  - o código: nenhum indexador de `Resources` fora de `Set-GuiResource`, nenhum `New-Object` entregue a um indexador do .NET, as duas fontes pelo construtor.
- **No código de antes (822b035):** 26 das 31 conferências que rodam falham (as 5 que passam são do próprio simulado). No de agora, 38 de 38.
- **10 defeitos de propósito,** e as conferências pegam todos: as fontes de volta pelo indexador e pelo `New-Object`; `Set-GuiResource` sem desembrulhar, sozinho e com a fonte pelo `New-Object`; a chave virando texto; os pincéis, a cópia da mensagem, a largura dos cartões e os tamanhos pelo indexador direto; a fonte dos títulos sem ser posta.
- **O WPF simulado** foi conferido contra o perfil do Windows PowerShell 5.1 do PSScriptAnalyzer: 78 tipos, 2.298 membros, nenhum que o Windows PowerShell não tenha. Com um campo estático errado de propósito, a conferência o pega.
- **Todas as páginas montadas no simulado novo,** nos dois temas, nos três idiomas, com e sem Administrador, e a busca: nenhuma parte recusada ao entrar na tela. Os erros que sobram são as leituras do Windows que não existem na nuvem (o registro, o WMI, as permissões), que o código já captura.
- **Nada do que funcionava quebrou:**
  - a bateria da R37 com o simulado novo (209, 210 e 210) e as mensagens da janela (72 em cada idioma, com `Set-GuiResource` carregada pela bateria);
  - as baterias das 14 páginas revistas, com os mesmos números da R37: Diagnóstico (212, 224 e 224), Segurança (134, 142 e 142), Limpeza (178, 187 e 187), Desempenho (96, 102 e 102), Reparo (114, 121 e 121), Atualizações (112, 119 e 119), Programas (108, 117 e 117), Rede (145, 154 e 154, com a mesma conferência antiga da lista dos itens com escudo), Ajustes do Windows (412, 422 e 422), Personalização (265, 270 e 270), Sobre o WinForge (164, 169 e 169), Busca (109, 98 e 101), Verificar o PC (146, 147 e 147) e Otimizar (146, 151 e 151);
  - o Início da R13 (241 em cada idioma), a Manutenção (243, 245 e 250), as conferências da R11 e da R12 e as gerais (código, frente, R7, dados), com os mesmos números da R37; as da R9 e da R10 com as mesmas falhas da R37, das conferências antigas que descrevem o desenho de antes;
  - instalar, atualizar com um clique e o pacote de suporte, iguais aos da R37;
  - os documentos: o mapa, o CHANGELOG e os READMEs conferidos contra o código (146, com o link desta entrada no índice) e cada nome citado na documentação técnica (233);
  - as traduções: nenhum texto novo (5.558);
  - as funções sem referência (nenhuma, entre 1.495; eram 1.494) e nenhuma chamada a uma função que não existe;
  - o PSScriptAnalyzer: os mesmos 245 avisos da R37, nenhum novo;
  - os 54 defeitos de propósito da R37, todos pegos; o que tirava o título grande dos recursos foi reescrito para o código novo, que o põe por `Set-GuiResource`;
  - o Setup de verdade, da R37 para esta: saída 0, os 58 arquivos trocados pelos do pacote e as notas da pessoa mantidas; o zip muda só na janela, no CHANGELOG e no `SHA256SUMS.txt`.

**Validado pelo MVP Windows**
- **O mesmo construtor:** `[System.Windows.Media.FontFamily]::new(nome)` chama o mesmo construtor público, `FontFamily(string familyName)`, que o `New-Object` de antes chamava. A fonte já era criada no PC; o que falhava era guardá-la embrulhada. O `::new` existe desde o PowerShell 5.0 ("This feature was added in PowerShell 5.0").
- **O embrulho:** a mesma recusa, com a mesma causa e a mesma saída, nos dois projetos citados nas fontes, no Windows PowerShell 5.1. Na nuvem, o PowerShell 7 faz o mesmo: pelo indexador, o dicionário recebe o `PSObject`; por um método ou por uma propriedade, o objeto.
- **O que só um PC confirma:** o roteiro, §30.

**Fontes**
- [Purview_CaseTools, PR #3](https://github.com/purviewpower-lab/Purview_CaseTools/pull/3): "Assigning a value through the ResourceDictionary indexer keeps that wrapper"; o erro "is not a valid value for property 'Foreground'" no Windows PowerShell 5.1.
- [SmartDeployTool, PR #5](https://github.com/borubarczyk/SmartDeployTool/pull/5): o pincel do `New-Object` guardado como `PSObject` nos recursos da janela, recusado pelo WPF.
- Microsoft: [about_Object_Creation (Windows PowerShell 5.1)](https://learn.microsoft.com/he-il/powershell/module/microsoft.powershell.core/about/about_object_creation?view=powershell-5.1) e [FontFamily Constructors](https://learn.microsoft.com/ko-kr/dotnet/api/system.windows.media.fontfamily.-ctor)

**Entregue:** `WinForge.zip`, `WinForge-codigo-fonte.zip`, `historico-4.0.md` e a prévia do Início antes e depois.

---

## R40 — Segunda revisão do Início

**Data:** 21/11/2026 · **Commit:** 9edd58a

**Pedido:** com os prints do Início e da Manutenção depois da R39, "Tuudo igual. Algo tu quenbrou. Antes dessa refatoração visual esse bug não ocorria."; depois, "Revise a tela/função "Início"", com cinco olhares: um Analista de Produto Sênior avalia o todo; um Engenheiro de Software Sênior revisa o código, refatora, tira o que não serve e melhora o desempenho; um Designer Sênior com um Especialista em UX/UI revisam a tela, os botões, os textos e os fluxos; um MVP Windows confere as práticas da Microsoft, se cada função faz o melhor e se é robusta; um QA Sênior testa tudo, o óbvio e o que não é. O engenheiro aplica o que cada um pede.

**O relatório:** `docs/revisao-inicio-2-4.0.md`, com os 14 achados, o que foi mantido, os testes e as fontes.

**O "Tudo igual"**
- **A causa provável:** a janela do WinForge é uma por conta do Windows, e não uma por pasta. Com uma janela aberta, abrir o WinForge da pasta nova só trazia a janela da pasta antiga para a frente, sem dizer nada. A correção da R39 estava na pasta nova; a janela na tela era a de antes.
- **O que muda:** a janela aberta diz que é de outra pasta, com as duas pastas e os botões Fechar esta janela e Continuar aqui. Vale da R40 em diante: uma janela de uma versão anterior aberta ainda não sabe dizer isso.
- **Se a parte faltar de novo:** um aviso no alto do Início diz qual, e o motivo vai para `logs\janela.log`, que o Pacote de suporte leva.

**O que mudou**
- **Produto:** a mensagem de outra pasta (P1); a parte que falha fica de fora inteira, com o aviso e o log (P2).
- **Código:**
  - a fonte dos títulos direto na propriedade de cada texto (`Set-GuiDisplayFont`), sem depender do recurso na hora de entrar na tela (E1);
  - cada parte do Início numa peça só, posta inteira por `Add-GuiHomePart` (E2), com `Add-WinForgeWindowProblem` (Core.psm1) e `Show-GuiHomeProblem`;
  - a configuração inicial com o agendamento lido pela etapa da leitura do Início (`ScheduleSetup`), fora da thread da janela; a consulta ao Agendador de Tarefas pela COM na janela saiu (E3);
  - a nota montada uma vez por visita (E4); `New-GuiValueSummary` numa peça (E5); um caractere de controle num comentário (E6).
- **Design:** o cartão do disco sem " · quase cheio" nem " · pouco espaço", com os três cartões lado a lado (D1); a faixa inclinada só até o traço acima dos pontos de atenção (D2); "Agora não" fecha a faixa no lugar e passa o foco ao que vem antes (D3).
- **Windows:** o Narrador lê a frase da nota só quando uma leitura termina (M1).
- **QA:** o foco do teclado volta ao mesmo botão quando a nota é refeita (Q1) e ao botão de ler de novo depois de uma leitura pedida por ele (Q2).
- **Traduções:** 5.563 textos; " · quase cheio" saiu de uso (" · pouco espaço" continua no resumo da Limpeza).

**Conferido na nuvem pelo QA**
- **Uma bateria nova do Início,** 115 conferências em cada idioma, com a janela aberta como no PC: a fonte dos títulos; cada parte inteira, o aviso e o log; a configuração inicial; o Agora não; o foco do teclado; o Narrador e a nota uma vez; a faixa; o disco cheio; outra pasta; os textos.
- **No código de antes (853abc3):** cada conferência das correções falha, e as do que foi mantido passam. As partes inteiras, a configuração inicial, o Agora não e a outra pasta param no começo, sem as funções novas.
- **29 defeitos de propósito,** e as conferências pegam todos.
- **O WPF simulado** ganhou o foco do teclado, `MoveFocus`, `Decorator` e `IsKeyboardFocused`, e foi conferido de novo contra o perfil do Windows PowerShell 5.1: 83 tipos, 2.661 membros, nenhum que o Windows PowerShell não tenha.
- **Nada do que funcionava quebrou:**
  - as baterias da R37 e da R39 nas cópias que trocam só o que descreve o desenho de antes (a fonte pelo recurso e as partes soltas no painel): 209, 210 e 210, e 38 em cada idioma. As originais falham só nessas conferências;
  - as mensagens da janela, com a conta em 19 mensagens e 5 perguntas Sim/Não (72 em cada idioma);
  - as baterias das 14 páginas revistas, com os mesmos números da R39: Diagnóstico (212, 224 e 224), Segurança (134, 142 e 142), Limpeza (178, 187 e 187), Desempenho (96, 102 e 102), Reparo (114, 121 e 121), Atualizações (112, 119 e 119), Programas (108, 117 e 117), Rede (145, 154 e 154, com a mesma conferência antiga), Ajustes do Windows (412, 422 e 422), Personalização (265, 270 e 270), Sobre o WinForge (164, 169 e 169), Busca (109, 98 e 101), Verificar o PC (146, 147 e 147) e Otimizar (146, 151 e 151);
  - o Início da R13 (241 em cada idioma), a Manutenção (243, 245 e 250), as conferências da R11 e da R12 e as gerais (código, frente, R7, dados), com os mesmos números; as da R9 e da R10 com as mesmas falhas antigas;
  - a conferência da QA que lia o agendamento pela consulta que saiu: as duas falham, como esperado, e a cópia que lê pelo caminho novo passa nos mesmos quatro casos (66 de 66);
  - instalar, atualizar com um clique e o pacote de suporte, iguais aos da R39;
  - os documentos: o mapa, o CHANGELOG e os READMEs conferidos contra o código (147) e cada nome citado na documentação técnica (247);
  - as traduções: 5.563, nenhum sem tradução;
  - as funções sem referência (nenhuma, entre 1.507; eram 1.495) e nenhuma chamada a uma função que não existe;
  - o PSScriptAnalyzer: 248 avisos, 3 a mais que os 245 da R39, todos do botão Agora não, que recebe o clique com `param ($sender, $eventArgs)`, como os outros 43 botões da janela;
  - o Setup de verdade, da R39 para esta: saída 0, os 58 arquivos trocados pelos do pacote e as notas da pessoa mantidas; o zip muda na janela, em cinco módulos (Core, GuiHost, Home, Reports e Schedule), nas traduções, no CHANGELOG e no `SHA256SUMS.txt`.

**Validado pelo MVP Windows**
- **A fonte direto:** a Microsoft diz que um `DynamicResource` adia a busca até o valor ser preciso, o que pode ser depois de a página carregar; posta direto, a fonte é conferida quando o texto é montado.
- **Uma janela por conta:** o mutex com o prefixo `Local\` fica no espaço da sessão, como a Microsoft descreve.
- **O pedido de outra pasta:** a janela só mostra a pasta e nunca abre o que vem no pedido, gravado numa pasta em que qualquer programa da conta escreve.
- **O foco:** pelo `Keyboard.FocusedElement` e pelo `MoveFocus`, como a Microsoft mostra; um botão desligado não recebe o foco, então ele vai ao primeiro botão ligado.
- **O que só um PC confirma:** o roteiro, §31.

**Fontes**
- Microsoft: [DynamicResource Markup Extension](https://learn.microsoft.com/en-us/dotnet/desktop/wpf/advanced/dynamicresource-markup-extension), [Focus overview (WPF)](https://learn.microsoft.com/dotnet/desktop/wpf/advanced/focus-overview), [UIElement.Focus](https://learn.microsoft.com/en-us/dotnet/api/system.windows.uielement.focus?redirectedfrom=MSDN&view=windowsdesktop-11.0) e [Kernel object namespaces](https://learn.microsoft.com/windows/win32/termserv/kernel-object-namespaces)

**Entregue:** `WinForge.zip`, `WinForge-codigo-fonte.zip`, `revisao-inicio-2-4.0.md`, `historico-4.0.md` e a prévia do Início.

---

## R41 — Segunda revisão da Manutenção

**Data:** 21/11/2026 · **Commit:** 95943aa

**Pedido:** "Revise a tela/função "Manutenção"", com os mesmos cinco olhares da R40: um Analista de Produto Sênior avalia o todo; um Engenheiro de Software Sênior revisa o código, refatora, tira o que não serve e melhora o desempenho; um Designer Sênior com um Especialista em UX/UI revisam a tela, os botões, os textos e os fluxos; um MVP Windows confere as práticas da Microsoft, se cada função faz o melhor e se é robusta; um QA Sênior testa tudo, o óbvio e o que não é. O engenheiro aplica o que cada um pede.

**O relatório:** `docs/revisao-manutencao-2-4.0.md`, com os 7 achados, o que foi mantido, os testes e as fontes. A primeira revisão da página (R14) foi antes do desenho novo; o Otimizar e o Verificar o PC tiveram as suas (R28 e R27).

**O que mudou**
- **Produto:** a manutenção agendada que falha aparece no Início. O registro que o WinForge grava em cada execução passa a contar (`RecordFailed`): no Windows 11, o Agendador de Tarefas mostrava como concluída uma execução em que nada funcionou (P1).
- **Código:** saíram `New-GuiMaintenanceFact`, `New-GuiFactCard`, `Set-GuiFactCardText` e `Set-GuiCardWidth`, só do cartão antigo, e o caso à parte da Manutenção em `Show-GuiListPage`: a janela tem 110 linhas e 4 funções a menos (E1); a tela da manutenção agendada lê uma vez se o Agendador respondeu (E2).
- **Design:** a faixa "Última manutenção" de largura inteira, como nas outras páginas, com a seta que abre o Histórico de manutenções (D1, a UX11 da R38). `Get-WinForgeMaintenancePageStatus` (nova) dá a linha, e `New-GuiPageStatus` ganhou `Opens`.
- **Windows:** a leitura, a criação e a remoção da tarefa pelo `Invoke-WinForgeCimCommand`, com prazo, como a regra de engenharia pede; a remoção não espera um segundo prazo (M1).
- **QA:** desfazer um ajuste pelo Histórico de mudanças oferece o Explorador e pede o reinício do PC quando o ajuste pede (Q1); duas trocas de DNS desfeitas de uma vez contam como uma, com uma anotação só (Q2).
- **Traduções:** 5.564 textos (um novo).

**Conferido na nuvem pelo QA**
- **Uma bateria nova da Manutenção,** 67 conferências em cada idioma: a faixa do alto, o Agendador com prazo, o registro da execução mensal, o desfazer de um ajuste, as mudanças que voltam juntas e os textos.
- **No código de antes (9edd58a):** cada conferência das correções falha, e as do que foi mantido passam. A faixa para no começo, sem a função nova.
- **26 defeitos de propósito,** e as conferências pegam todos.
- **Nada do que funcionava quebrou:**
  - a bateria da Manutenção da R14 (243, 245 e 250), com o Agendador simulado de antes: os mesmos números, agora pelo caminho com prazo;
  - a bateria do Início da R40 (115 em cada idioma), as das 14 páginas revistas, com os mesmos números da R40 (a Rede com a mesma conferência antiga), o Início da R13 (241), as conferências da R11 e da R12 e as gerais; as da R9 e da R10 com as mesmas falhas antigas;
  - a conferência da QA do passo da configuração inicial, na cópia da R40, com o Agendador simulado no escopo em que o Windows tem os comandos dele: 66 de 66;
  - as mensagens da janela (72 em cada idioma, com 19 mensagens);
  - instalar, atualizar com um clique e o pacote de suporte, iguais aos da R40;
  - os documentos (148) e cada nome citado na documentação técnica (256);
  - as traduções: 5.564, nenhum sem tradução;
  - as funções sem referência (nenhuma, entre 1.504; eram 1.507) e nenhuma chamada a uma função que não existe;
  - o PSScriptAnalyzer: os mesmos 248 avisos da R40, nenhum novo;
  - o Setup de verdade, da R40 para esta: saída 0, os 58 arquivos trocados pelos do pacote e as notas da pessoa mantidas; o zip muda na janela, em quatro módulos (Journal, Maintenance, Navigation e Schedule), nas traduções, no CHANGELOG e no `SHA256SUMS.txt`.

**Validado pelo MVP Windows**
- **O prazo:** a Microsoft documenta o `-AsJob` dos comandos do Agendador para "commands that take a long time to complete"; é ele que `Invoke-WinForgeCimCommand` usa.
- **A tarefa mensal:** `StartWhenAvailable`, `DisallowStartIfOnBatteries`, `StopIfGoingOnBatteries`, `ExecutionTimeLimit` e `Priority` fazem o que a Microsoft descreve.
- **O que só um PC confirma:** o roteiro, §32.

**Fontes**
- Microsoft: [Get-ScheduledTask](https://learn.microsoft.com/en-us/powershell/module/scheduledtasks/get-scheduledtask) e [Settings (taskType) Element](https://learn.microsoft.com/en-au/windows/win32/taskschd/taskschedulerschema-settings-tasktype-element)

**Entregue:** `WinForge.zip`, `WinForge-codigo-fonte.zip`, `revisao-manutencao-2-4.0.md`, `historico-4.0.md` e a prévia da Manutenção.

---

## R42 — Segunda revisão da Limpeza

**Data:** 21/11/2026 · **Commit:** 4ee0de9

**Pedido:** "Revise a tela/função "Limpeza"", com os mesmos cinco olhares da R40 e da R41: um Analista de Produto Sênior avalia o todo; um Engenheiro de Software Sênior revisa o código, refatora, tira o que não serve e melhora o desempenho; um Designer Sênior com um Especialista em UX/UI revisam a tela, os botões, os textos e os fluxos; um MVP Windows confere as práticas da Microsoft, se cada função faz o melhor e se é robusta; um QA Sênior testa tudo, o óbvio e o que não é. O engenheiro aplica o que cada um pede.

**O relatório:** `docs/revisao-limpeza-2-4.0.md`, com os 8 achados, o que foi mantido, os testes e as fontes. A primeira revisão da página (R17) foi antes do desenho novo (R37) e da revisão de UX (R38).

**O que mudou**
- **Produto:** o disco cheio tem um conselho só, a Limpeza personalizada. Com pouco espaço, a faixa do alto da página fica em amarelo e é um botão que a abre (`Opens`, como na Manutenção); o aviso de pouco espaço do monitor abre a mesma tela, e ela entra nas ações que a janela aceita do monitor. Antes, a faixa e o aviso mandavam para a Limpeza rápida, e o Início e a Verificação do PC, para a personalizada (P1).
- **Código:** saíram a pergunta, as notas e os parâmetros `-Notes`, `-Embedded` e `-PassThru` da limpeza de uma pasta de temporários, que nunca rodava sozinha (E1); `Get-WinForgePathStats` soma sem um bloco por arquivo, com o mesmo resultado, cerca de dez vezes mais rápida numa pasta de 8.000 arquivos (de 690 ms para 56 ms) (E2).
- **Design:** a faixa de uma limpeza em que nada de espaço volta diz "Limpeza concluída" (ou "Lixeira esvaziada", ou "2 itens excluídos") e por quê, em vez de "Tudo certo · Liberou 0 B" (D1); as dez perguntas de Sim e Não da página dizem o verbo nos botões, a UX21 da R38 aplicada aqui (D2).
- **Windows:** Configurações de armazenamento diz que abre a página Armazenamento, que é o que `ms-settings:storagesense` abre (M1).
- **QA:** Limpar a pasta Downloads com outra conta avisa como as outras telas (Q1); Limpar o registro com ressalva mantém o botão Histórico de mudanças (Q2).
- **Traduções:** 5.567 textos (9 novos, 7 que saíram de uso e 1 que voltou).

**Conferido na nuvem pelo QA**
- **Uma bateria nova da Limpeza,** 97 conferências em cada idioma: o disco cheio, as faixas em que nada volta, os botões das perguntas, o código e a soma das pastas, Configurações de armazenamento, outra conta e o registro, e os textos.
- **No código de antes (95943aa):** cada conferência das correções falha, e as do que foi mantido passam. A faixa para no primeiro caso de pouco espaço, sem o botão.
- **42 defeitos de propósito,** e as conferências pegam todos.
- **Nada do que funcionava quebrou:**
  - a bateria da Limpeza da R17 (178, 187 e 187) e as das outras 13 páginas revistas, com os mesmos números da R41 (a Rede com a mesma conferência antiga); o Início da R13 (241), a Manutenção da R14 (243, 245 e 250), as conferências da R11 e da R12 e as gerais; as da R9 e da R10 com as mesmas falhas antigas;
  - a bateria do Início da R40 (115 em cada idioma), a da Manutenção da R41 (67 em cada idioma) e a conferência da QA do passo da configuração inicial (66 de 66);
  - as mensagens da janela (72 em cada idioma);
  - instalar, atualizar com um clique e o pacote de suporte, iguais aos da R41;
  - cada nome e link citado na documentação técnica (259);
  - as traduções: 5.567, nenhum sem tradução e nenhum sem uso;
  - as funções sem referência (nenhuma, entre 1.505; eram 1.504, e a nova é `Get-WinForgeCleanupZeroNote`) e nenhuma chamada a uma função que não existe;
  - o PSScriptAnalyzer: 247 avisos, um a menos que na R41 (o parâmetro que só o bloco por arquivo usava), nenhum novo;
  - o Setup de verdade, da R41 para esta: saída 0, os 58 arquivos trocados pelos do pacote e as notas da pessoa mantidas; o zip muda em nove módulos (Agent, Cleanup, CleanupTools, Core, Navigation, Performance, RegistryCleaner, Repair e Shortcuts), nas traduções, no CHANGELOG e no `SHA256SUMS.txt`.

**Validado pelo MVP Windows**
- **Armazenamento:** na tabela da Microsoft, `ms-settings:storagesense` é a página Storage, e `ms-settings:storagepolicies`, a do Sensor de Armazenamento.
- **A Lixeira:** o `Clear-RecycleBin` esvazia a do usuário, em todas as unidades; o limite que o WinForge calcula é o padrão do Windows desde o Vista (10% dos primeiros 40 GB e 5% do resto).
- **O cache da Otimização de Entrega:** `Delete-DeliveryOptimizationCache -Force`, sem os arquivos fixados.
- **O que só um PC confirma:** o roteiro, §33.

**Fontes**
- Microsoft: [Launch the Windows Settings app](https://learn.microsoft.com/en-us/windows/apps/develop/launch/launch-settings), [Clear-RecycleBin](https://learn.microsoft.com/powershell/module/microsoft.powershell.management/clear-recyclebin), [Monitor Delivery Optimization](https://learn.microsoft.com/windows/deployment/do/waas-delivery-optimization-monitor) e [Dialog controls](https://learn.microsoft.com/windows/apps/design/controls/dialogs-and-flyouts/dialogs)
- Raymond Chen, The Old New Thing: [What is the default size of the Recycle Bin?](https://devblogs.microsoft.com/oldnewthing/20140701-00/?p=603)

**Entregue:** `WinForge.zip`, `WinForge-codigo-fonte.zip`, `revisao-limpeza-2-4.0.md`, `historico-4.0.md` e a prévia da Limpeza.

---

## R43 — Segunda revisão do Desempenho

**Data:** 21/11/2026 · **Commit:** a05efdd

**Pedido:** "Revise a tela/função "Desempenho"", com os mesmos cinco olhares da R40 à R42: um Analista de Produto Sênior avalia o todo; um Engenheiro de Software Sênior revisa o código, refatora, tira o que não serve e melhora o desempenho; um Designer Sênior com um Especialista em UX/UI revisam a tela, os botões, os textos e os fluxos; um MVP Windows confere as práticas da Microsoft, se cada função faz o melhor e se é robusta; um QA Sênior testa tudo, o óbvio e o que não é. O engenheiro aplica o que cada um pede.

**O relatório:** `docs/revisao-desempenho-2-4.0.md`, com os 9 achados, o que foi mantido, os testes e as fontes. A primeira revisão da página (R18) foi antes do desenho novo (R37) e da revisão de UX (R38).

**O que mudou**
- **Produto:** a faixa do alto leva ao que resolve. Com a memória a partir de 85%, a linha diz "… · alta" e é um botão que abre Programas pesando agora, o destino da Verificação do PC (P1); com o PC ligado há 7 dias ou mais, a linha é um botão que abre Tempo ligado e energia, que explica por que desligar não zera esse tempo (P2). Antes, a faixa só dizia o que fazer.
- **Código:** `Get-WinForgeBoostTempState` (nova) diz numa palavra o que houve com os temporários do Acelerar agora, e o resumo e a faixa usam a mesma resposta (E1); `New-WinForgeStartupChoices` (nova) monta as listas de Gerenciar inicialização, antes montadas em dois lugares, e a lista dos processos protegidos perdeu um nome repetido (E2).
- **Design:** os botões dizem o verbo em Programas pesando agora ("Fechar", "Encerrar à força" em vermelho e "Não encerrar"), em Gerenciar inicialização ("Desativar (2)", "Reativar (1)") e na revisão do Otimizar ("Aplicar" e "Deixar como está"), a UX21 da R38 aplicada aqui (D1); os atalhos da pasta Inicializar aparecem sem ".lnk", com o nome do arquivo guardado por dentro para o Windows e para o desfazer (D2); Gerenciar inicialização tem a mesma frase e as mesmas palavras de busca em Desempenho e em Programas, e a busca traz sempre a de Desempenho, a UX28 da R38 (D3).
- **Windows:** nenhuma correção; os conselhos da página são os da Microsoft para um PC lento.
- **QA:** o Acelerar agora diz "os temporários estavam em uso e ficaram" quando é isso, e não "nenhum temporário para apagar" (Q1); dois programas com o mesmo nome amigável levam o nome do processo ("Python (python)" e "Python (pythonw)") (Q2).
- **Traduções:** 5.570 textos (8 novos e 5 que saíram de uso).

**Conferido na nuvem pelo QA**
- **Uma bateria nova do Desempenho,** 94 conferências em cada idioma: a faixa do alto, o Acelerar agora com temporários em uso (com a limpeza de verdade de uma pasta Temp com arquivos presos), Programas pesando agora com nomes repetidos e os botões, Gerenciar inicialização com atalhos e a busca, e os textos.
- **No código de antes (4ee0de9):** cada conferência das correções falha, e as do que foi mantido passam. A faixa para no primeiro caso de memória alta, sem o botão.
- **36 defeitos de propósito (um escapou na primeira rodada e a conferência ficou mais forte),** e as conferências pegam todos.
- **Nada do que funcionava quebrou:**
  - a bateria do Desempenho da R18 (96, 102 e 102) e as das outras 13 páginas revistas, com os mesmos números da R42 (a Rede com a mesma conferência antiga); a busca da R26 igual, depois da troca das palavras de Gerenciar inicialização; o Início da R13 (241), a Manutenção da R14 (243, 245 e 250), as conferências da R11 e da R12 e as gerais; as da R9 e da R10 com as mesmas falhas antigas;
  - a bateria do Início da R40 (115 em cada idioma), a da Manutenção da R41 (67), a da Limpeza da R42 (97) e a conferência da QA do passo da configuração inicial (66 de 66);
  - as mensagens da janela (72 em cada idioma);
  - instalar, atualizar com um clique e o pacote de suporte, iguais aos da R42;
  - cada nome e link citado na documentação técnica (260);
  - as traduções: 5.570, nenhum sem tradução e nenhum sem uso;
  - as funções sem referência (nenhuma, entre 1.508; eram 1.505, e as novas são `Get-WinForgeBoostTempState`, `Get-WinForgeStartupDisplayName` e `New-WinForgeStartupChoices`) e nenhuma chamada a uma função que não existe;
  - o PSScriptAnalyzer: 247 avisos, os mesmos da R42, nenhum novo;
  - o Setup de verdade, da R42 para esta: saída 0, os 58 arquivos trocados pelos do pacote e as notas da pessoa mantidas; o zip muda em quatro módulos (Cleanup, Navigation, Performance e Startup), na janela (`WinForge.Gui.ps1`, só um comentário), nas traduções, no CHANGELOG e no `SHA256SUMS.txt`.

**Validado pelo MVP Windows**
- **Os conselhos:** desativar o que abre com o Windows, ver o que usa o processador e a memória, fechar o que não está em uso e reiniciar, como a Microsoft orienta para um PC lento.
- **Ligado há:** com a Inicialização Rápida, desligar não é um desligamento completo; reiniciar é.
- **Fechar como no X** (`CloseMainWindow`) e encerrar à força (`Kill`) só para o que não tem janela, depois da pergunta.
- **O que só um PC confirma:** o roteiro, §34.

**Fontes**
- Microsoft: [Tips to improve PC performance in Windows](https://support.microsoft.com/windows/b3b3ef5b-5953-fb6a-2528-4bbed82fba96), [System power states](https://learn.microsoft.com/en-us/windows/win32/Power/system-power-states), [Process.CloseMainWindow](https://learn.microsoft.com/en-us/dotnet/api/system.diagnostics.process.closemainwindow) e [Dialog controls](https://learn.microsoft.com/windows/apps/design/controls/dialogs-and-flyouts/dialogs)
- Raymond Chen, The Old New Thing: [How do I determine whether Explorer is showing or hiding file extensions?](https://devblogs.microsoft.com/oldnewthing/20241120-00/?p=110547)

**Entregue:** `WinForge.zip`, `WinForge-codigo-fonte.zip`, `revisao-desempenho-2-4.0.md`, `historico-4.0.md` e a prévia do Desempenho.

---

## R44 — Segunda revisão do Reparo

**Data:** 21/11/2026 · **Commit:** 4689784

**Pedido:** "Revise a tela/função "Reparo"", com os mesmos cinco olhares da R40 à R43: um Analista de Produto Sênior avalia o todo; um Engenheiro de Software Sênior revisa o código, refatora, tira o que não serve e melhora o desempenho; um Designer Sênior com um Especialista em UX/UI revisam a tela, os botões, os textos e os fluxos; um MVP Windows confere as práticas da Microsoft, se cada função faz o melhor e se é robusta; um QA Sênior testa tudo, o óbvio e o que não é. O engenheiro aplica o que cada um pede.

**O relatório:** `docs/revisao-reparo-2-4.0.md`, com os 10 achados, o que foi mantido, os testes e as fontes. A primeira revisão da página (R19) foi antes do Destravar a impressão (R36), do desenho novo (R37) e da revisão de UX (R38).

**O que mudou**
- **Produto:** o Reparar o Windows (DISM + SFC) numa bateria avisa para ligar o carregador e pergunta com o Não como padrão, como o Otimizar (P1); o Otimizar a unidade diz "O que o Windows já faz toda semana, feito agora", e não promete mais um disco mais rápido (P2).
- **Código:** `Get-WinForgeExitCodeResult` sem o texto da saída, que não lia, e o cabeçalho do módulo com as seis ações (E1); `Get-WinForgeExternalDriveLetters` (nova) lê as partições e os discos uma vez para a lista de unidades do CHKDSK, no lugar de dois pedidos por unidade, e `Test-WinForgeDriveExternal` saiu (E2).
- **Design:** os botões das sete perguntas dizem o verbo ("Reparar", "Verificar", "Agendar" e "Agora não", "Otimizar", "Procurar", "Reiniciar" ou "Ligar", e "Cancelar"), a UX21 da R38 aplicada aqui (D1); o Destravar a impressão com o ícone de lista, e não o do SFC (D2); no grupo Disco e dispositivos, as ações de disco juntas, depois as de dispositivos (D3).
- **Windows:** `Start-WinForgeService` pede ao Windows para ligar o serviço e espera no máximo 30 segundos, com o motivo no erro; o `Start-Service` esperava sem limite, e um Spooler de Impressão preso em "Iniciando" parava a tela (M1). Vale para o Destravar a impressão, o Corrigir o Windows Update e o Acertar a data e a hora.
- **QA:** com o Spooler parado, o Destravar a impressão diz "ligar" do começo ao fim, da pergunta ao Histórico de mudanças, e não "reiniciar" (Q1); um serviço ainda "Parando" é esperado e ligado, em vez de ficar desligado (Q2).
- **Traduções:** 5.584 textos (16 novos e 2 que saíram de uso).

**Conferido na nuvem pelo QA**
- **Uma bateria nova do Reparo,** 92 conferências em cada idioma: a página, os botões das sete perguntas, a bateria, o resultado pelo código de saída, o CHKDSK com vários discos, ligar um serviço em cada estado (com os estados de um serviço de verdade), o Spooler parado com a pasta da fila de verdade, e os textos.
- **No código de antes (a05efdd):** cada conferência das correções falha (36), e as 56 do que foi mantido passam. Com o Spooler preso em "Iniciando", a tela de antes só termina quando a simulação desiste.
- **37 defeitos de propósito (na primeira rodada, um não foi aplicado e três foram pegos por uma falha da própria conferência; corrigidos os dois, as conferências de verdade pegaram os quatro),** e as conferências pegam todos.
- **As baterias antigas do Reparo (R19) e das Atualizações (R20)** simulavam o Windows com os comandos que o código usava: as partições e os discos passaram a responder também sem filtro, e os serviços simulados ganharam os métodos de um serviço de verdade. Uma conferência da R20 passou a olhar se os serviços terminam ligados, e não quantos pedidos de ligar foram feitos. As duas adaptadas passam também no código de antes.
- **Nada do que funcionava quebrou:**
  - as baterias das 14 páginas revistas, com os mesmos números da R43 (a do Reparo e a das Atualizações depois da adaptação acima; a Rede com a mesma conferência antiga); a das seis funções novas da R36 (257 em cada idioma); o Início da R13 (241), a Manutenção da R14 (243, 245 e 250), as conferências da R11 e da R12 e as gerais; as da R9 e da R10 com as mesmas falhas antigas;
  - a bateria do Início da R40 (115 em cada idioma), a da Manutenção da R41 (67), a da Limpeza da R42 (97), a do Desempenho da R43 (94) e a conferência da QA do passo da configuração inicial (66 de 66);
  - as mensagens da janela (72 em cada idioma);
  - instalar, atualizar com um clique e o pacote de suporte, iguais aos da R43;
  - cada nome e link citado na documentação técnica (264);
  - as traduções: 5.584, nenhum sem tradução e nenhum sem uso;
  - as funções sem referência (nenhuma, entre 1.508: entrou `Get-WinForgeExternalDriveLetters` e saiu `Test-WinForgeDriveExternal`) e nenhuma chamada a uma função que não existe;
  - o PSScriptAnalyzer: 247 avisos, como na R43; saiu o do parâmetro `OutputText`, que ninguém lia, e entrou um do mesmo tipo no analisador da busca de dispositivos, que recebe os valores pela posição;
  - o Setup de verdade, da R43 para esta: saída 0, os 58 arquivos trocados pelos do pacote e as notas da pessoa mantidas; o zip muda em cinco módulos (Cleanup, GuiDesign, Navigation, Repair e WindowsUpdate), nas traduções, no CHANGELOG e no `SHA256SUMS.txt`.

**Validado pelo MVP Windows**
- **O DISM antes do SFC,** com os mesmos comandos que a Microsoft indica.
- **A otimização semanal** que o Windows já faz, e o `/O`, que deixa o Windows escolher o TRIM ou a desfragmentação.
- **Ligar um serviço:** esperar com prazo, esperar o serviço parar antes de ligá-lo e esperar enquanto ele está "Iniciando", como no exemplo da Microsoft.
- **O que só um PC confirma:** o roteiro, §35.

**Fontes**
- Microsoft: [Use the System File Checker tool](https://support.microsoft.com/help/929833), [Defragment/optimize your PC drives](https://support.microsoft.com/en-us/help/17126/), [Starting a Service](https://learn.microsoft.com/windows/win32/services/starting-a-service), [ServiceController.WaitForStatus](https://learn.microsoft.com/en-us/dotnet/api/system.serviceprocess.servicecontroller.waitforstatus), [StartServiceW function](https://learn.microsoft.com/en-us/windows/win32/api/winsvc/nf-winsvc-startservicew) e [Dialog controls](https://learn.microsoft.com/windows/apps/design/controls/dialogs-and-flyouts/dialogs)

**Entregue:** `WinForge.zip`, `WinForge-codigo-fonte.zip`, `revisao-reparo-2-4.0.md`, `historico-4.0.md` e a prévia do Reparo.

---

## R45 — Segunda revisão do Diagnóstico

**Data:** 21/11/2026 · **Commit:** b69d0f4

**Pedido:** "Revise a tela/função "Diagnóstico"", com os mesmos cinco olhares da R40 à R44: um Analista de Produto Sênior avalia o todo; um Engenheiro de Software Sênior revisa o código, refatora, tira o que não serve e melhora o desempenho; um Designer Sênior com um Especialista em UX/UI revisam a tela, os botões, os textos e os fluxos; um MVP Windows confere as práticas da Microsoft, se cada função faz o melhor e se é robusta; um QA Sênior testa tudo, o óbvio e o que não é. O engenheiro aplica o que cada um pede.

**O relatório:** `docs/revisao-diagnostico-2-4.0.md`, com os 12 achados, o que foi mantido, os testes e as fontes. A primeira revisão da página (R15) foi antes do desenho novo (R37), da revisão de UX (R38) e das faixas que levam ao que resolve (R41 a R43).

**O que mudou**
- **Produto:** Tempo ligado e energia oferece reiniciar com o PC ligado há uma semana ou mais, com o Depois como padrão (P1); o disco do Windows cheio tem o mesmo conselho do resto do WinForge, a Limpeza personalizada, e a faixa de Discos e espaço livre tem o botão "Liberar espaço" (P2); as faixas de Dispositivos com problema ("Detectar dispositivos") e dos Eventos críticos ("Ver a saúde dos discos", "Verificar o disco", "Testar a memória") levam ao que a tela manda fazer (P3).
- **Código:** a Saúde dos discos não espera de novo o armazenamento depois de um tempo esgotado, e três discos sem resposta custam um prazo, e não três (E1); `Get-WinForgePartitionLetters` (nova) lê as letras de cada disco para Discos e espaço livre, a Saúde dos discos e a lista do CHKDSK, antes lidas em três lugares (E2); `Test-WinForgeLongUptime` (nova) é a regra do "ligado há uma semana", em UTC, do Desempenho e de Tempo ligado e energia (E3).
- **Design:** o Teste de memória com "Abrir" e "Agora não", a UX21 da R38 aplicada aqui (D1); o Teste de memória com um ícone próprio, e não o de Dispositivos com problema (D2); as Telas azuis com uma linha por código, as vezes e a última, e cada causa uma vez, e a frase da página sem repetir o nome (D3).
- **Windows:** o Reinício pendente lê o pending.xml, como o Reparo: antes, o Diagnóstico dizia "nenhum reinício pendente" enquanto o Reparo pedia para reiniciar, e o Início, a Verificação do PC, o monitor e o Otimizar seguiam o Diagnóstico (M1); Sobre este PC com o WMI sem resposta diz isso em 30 segundos, e não em dois minutos e meio, com o que não depende dele (M2).
- **QA:** os contadores de um disco sem resposta não são mais descritos como os de um pendrive ("não expõe contadores"): a tela diz que o Windows não respondeu a tempo, uma vez, com os discos, e o relatório também (Q1).
- **Traduções:** 5.591 textos (9 novos e 2 que saíram de uso).

**Conferido na nuvem pelo QA**
- **Uma bateria nova do Diagnóstico,** 87 conferências em cada idioma: a página, o Teste de memória, Tempo ligado e energia (com a faixa do Desempenho), Discos e espaço livre, as partições, a Saúde dos discos com o armazenamento sem resposta (com prazo de verdade), o reinício pendente com um pending.xml de verdade, o WMI sem resposta, as faixas, as Telas azuis e os textos.
- **No código de antes (4689784):** cada conferência das correções falha (40), e as 47 do que foi mantido passam. Com os três discos sem resposta, a Saúde dos discos de antes espera um prazo por disco.
- **40 defeitos de propósito (um escapou na primeira rodada e a conferência ficou mais forte),** e as conferências pegam todos.
- **A bateria antiga do Diagnóstico (R15):** duas conferências pediam o que mudou de propósito (o conselho antigo do disco cheio e a frase "não expõe contadores" para um disco sem resposta) e passaram a pedir as frases novas; no código de antes, só elas falham.
- **Nada do que funcionava quebrou:**
  - as baterias das 14 páginas revistas, com os mesmos números da R44 (a do Diagnóstico depois da adaptação acima; a Rede com a mesma conferência antiga); a das seis funções novas da R36 (257 em cada idioma); o Início da R13 (241), a Manutenção da R14 (243, 245 e 250), as conferências da R11 e da R12 e as gerais; as da R9 e da R10 com as mesmas falhas antigas;
  - a bateria do Início da R40 (115 em cada idioma), a da Manutenção da R41 (67), a da Limpeza da R42 (97), a do Desempenho da R43 (94), a do Reparo da R44 (92) e a conferência da QA do passo da configuração inicial (66 de 66);
  - as mensagens da janela (72 em cada idioma);
  - instalar, atualizar com um clique e o pacote de suporte, iguais aos da R44;
  - cada nome e link citado na documentação técnica (267);
  - as traduções: 5.591, nenhum sem tradução e nenhum sem uso;
  - as funções sem referência (nenhuma, entre 1.511; eram 1.508, e as novas são `Test-WinForgeLongUptime`, `Get-WinForgePartitionLetters` e `Get-WinForgeLowDiskText`) e nenhuma chamada a uma função que não existe;
  - o PSScriptAnalyzer: 245 avisos, dois a menos que na R44 (dois `catch` vazios que agora tratam o tempo esgotado), nenhum novo;
  - o Setup de verdade, da R44 para esta: saída 0, os 58 arquivos trocados pelos do pacote e as notas da pessoa mantidas; o zip muda em seis módulos (Diagnostics, GuiDesign, Navigation, Performance, Repair e Reports), nas traduções, no CHANGELOG e no `SHA256SUMS.txt`.

**Validado pelo MVP Windows**
- **Reiniciar** quando o PC está lento, como a Microsoft aconselha, sem fechar nada à força.
- **O pending.xml:** é onde a instalação de uma atualização deixa o que o Windows termina ao desligar ou reiniciar.
- **O restante da R15:** as leituras com prazo, o log do Sistema, as telas azuis pelo código, o Secure Boot, a ativação, a bateria e o teste de memória do Windows.
- **O que só um PC confirma:** o roteiro, §36.

**Fontes**
- Microsoft: [Tips to improve PC performance in Windows](https://support.microsoft.com/windows/b3b3ef5b-5953-fb6a-2528-4bbed82fba96), [Why you don't want to edit your pending.xml to resolve 0xC0000034 issues](https://learn.microsoft.com/fr-fr/archive/blogs/joscon/why-you-dont-want-to-edit-your-pending-xml-to-resolve-0xc0000034-issues) (blog arquivado) e [Dialog controls](https://learn.microsoft.com/windows/apps/design/controls/dialogs-and-flyouts/dialogs)

**Entregue:** `WinForge.zip`, `WinForge-codigo-fonte.zip`, `revisao-diagnostico-2-4.0.md`, `historico-4.0.md` e a prévia do Diagnóstico.

---

## R46 — Segunda revisão da Rede

**Data:** 21/11/2026 · **Commit:** aa221d4

**Pedido:** "Revise a tela/função "Rede"", com os mesmos cinco olhares da R40 à R45: um Analista de Produto Sênior avalia o todo; um Engenheiro de Software Sênior revisa o código, refatora, tira o que não serve e melhora o desempenho; um Designer Sênior com um Especialista em UX/UI revisam a tela, os botões, os textos e os fluxos; um MVP Windows confere as práticas da Microsoft, se cada função faz o melhor e se é robusta; um QA Sênior testa tudo, o óbvio e o que não é. O engenheiro aplica o que cada um pede.

**O relatório:** `docs/revisao-rede-2-4.0.md`, com os 11 achados, o que foi mantido, os testes e as fontes. A primeira revisão da página (R22) foi antes do desenho novo (R37), da revisão de UX (R38) e das faixas no alto das páginas (R41 a R43).

**O que mudou**
- **Produto:** a faixa **Conexão** no alto da Rede, com o que o próprio Windows diz da conexão (com internet, sem internet, acesso limitado ou nenhuma rede, e o nome da rede), que leva ao Testar conectividade quando há problema (P1); o reparo oferece reiniciar quando refez o Winsock ou o TCP/IP, com o Depois como padrão (P2); o teste de velocidade sem nenhuma rede mostra a faixa "Nenhuma rede conectada", sem perguntar nem terminar num erro técnico (P3).
- **Código:** o ping manda os pacotes a todos os endereços juntos, pela classe Ping do .NET, a mesma nos dois PowerShell: o Testar conectividade leva cerca de 3 segundos, e não 15, e o teste da conexão do reparo pinga os dois IPs juntos (E1); o reparo monta a lista de comandos uma vez, cada um com um `Id`, sem comparar títulos traduzidos, e a faixa sem rede é uma só (E2).
- **Design:** "Reparar" e "Cancelar", "Testar" e "Cancelar", "Abrir" e "Agora não", "Acertar" e "Agora não", a UX21 da R38 aplicada aqui (D1); o DNS com o nome do provedor ("Fixo (Cloudflare): …") (D2); um site que só ignora o ping sem vermelho (D3).
- **Windows:** num Wi-Fi que pede login numa página (hotel, aeroporto, café), o teste diz "A rede limita o acesso", com o que fazer, e não oferece o reparo; o reparo avisa antes de perguntar; o Otimizar só limpa o DNS, e não refaz mais o Winsock e o TCP/IP numa rede assim (M1).
- **QA:** cada rede uma vez na Senha do Wi-Fi com dois adaptadores (Q1); trocar para o DNS que já está em uso não regrava nada nem anota no Histórico de mudanças (Q2).
- **Traduções:** 5.616 textos (26 novos e 1 que saiu de uso).

**Conferido na nuvem pelo QA**
- **Uma bateria nova da Rede,** 128 conferências em cada idioma: a faixa (com a janela de verdade sobre o WPF simulado), o Testar conectividade (com o ping de verdade no próprio PC), o reparo, o teste de velocidade, a troca e o desfazer do DNS, as Informações de rede, a Senha do Wi-Fi com dois adaptadores, as perguntas, o código e os textos.
- **No código de antes (b69d0f4):** cada conferência das correções falha (56); das 72 que passam, 39 conferem o que foi mantido e 33 são os textos em português. Os cinco endereços, com o ping de verdade no próprio PC: 15,1 segundos antes, 3,0 agora.
- **47 defeitos de propósito,** e as conferências pegam todos.
- **A bateria antiga da Rede (R22):** quatro conferências pediam o que mudou de propósito (o andamento do ping por endereço, as duas do `Win32_PingStatus` e o DNS fixo sem o provedor) e passaram a pedir o novo; ela passou a responder Depois à oferta de reiniciar. Os mesmos números da R45.
- **Nada do que funcionava quebrou:**
  - as baterias das 14 páginas revistas, com os mesmos números da R45 (a da Rede depois da adaptação acima); a das seis funções novas da R36 (257 em cada idioma); o Início da R13 (241), a Manutenção da R14 (243, 245 e 250), com o reparo de rede do Otimizar, as conferências da R11 e da R12 e as gerais; as da R9 e da R10 com as mesmas falhas antigas;
  - a bateria do Início da R40 (115 em cada idioma), a da Manutenção da R41 (67), a da Limpeza da R42 (97), a do Desempenho da R43 (94), a do Reparo da R44 (92), a do Diagnóstico da R45 (87) e a conferência da QA do passo da configuração inicial (66 de 66);
  - as mensagens da janela (72 em cada idioma);
  - instalar, atualizar com um clique e o pacote de suporte, iguais aos da R45;
  - cada nome e link citado na documentação técnica (273);
  - as traduções: 5.616, nenhum sem tradução e nenhum sem uso;
  - as funções sem referência (nenhuma, entre 1.517; eram 1.511: entraram `Get-WinForgePingReplies`, `ConvertTo-WinForgePingStats`, `Get-WinForgeInternetConnection`, `Get-WinForgeNetworkPageStatus`, `Set-WinForgeNoNetworkView`, `Get-WinForgeDnsProviderName` e `Test-WinForgeDnsAlready`, e saiu `Get-WinForgePingStats`) e nenhuma chamada a uma função que não existe;
  - o PSScriptAnalyzer: 244 avisos, um a menos que na R45 (o `catch` vazio do ping de antes), nenhum novo;
  - o Setup de verdade, da R45 para esta: saída 0, os 58 arquivos trocados pelos do pacote e as notas da pessoa mantidas; o zip muda em dois módulos (Network e NetworkTools), na janela (`WinForge.Gui.ps1`), nas traduções, no CHANGELOG e no `SHA256SUMS.txt`.

**Validado pelo MVP Windows**
- **O acesso limitado:** a API de conectividade do Windows marca assim a rede que pede login (um portal cativo), e a Microsoft avisa que é um indício: a faixa leva ao teste, que confirma.
- **O reinício depois do reset do TCP/IP,** como a Microsoft manda.
- **O ping pela classe Ping do .NET,** um pedido por instância; e os perfis de Wi-Fi, que o Windows exporta um por adaptador.
- **O restante da R22:** o reparo que não apaga IP nem DNS fixos, os avisos de Área de Trabalho Remota, VPN e proxy, o DNS medido e com backup, o PC de domínio, a senha fora do log e o relógio.
- **O que só um PC confirma:** o roteiro, §37.

**Fontes**
- Microsoft: [NetworkConnectivityLevel Enum](https://learn.microsoft.com/uwp/api/windows.networking.connectivity.networkconnectivitylevel), [NetworkInformation Class](https://learn.microsoft.com/en-us/uwp/api/windows.networking.connectivity.networkinformation), [Network Connectivity Status Indicator overview](https://learn.microsoft.com/en-us/windows-server/networking/ncsi/ncsi-overview), [Reset TCP/IP by using the NetShell utility](https://learn.microsoft.com/en-us/troubleshoot/windows-server/networking/reset-tcp-ip-net-shell), [Ping.SendPingAsync](https://learn.microsoft.com/en-us/dotnet/api/system.net.networkinformation.ping.sendpingasync), [Test-Connection (Windows PowerShell 5.1)](https://learn.microsoft.com/th-th/powershell/module/microsoft.powershell.management/test-connection?view=powershell-5.1), [netsh wlan](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/netsh-wlan) e [Dialog controls](https://learn.microsoft.com/windows/apps/design/controls/dialogs-and-flyouts/dialogs)

**Entregue:** `WinForge.zip`, `WinForge-codigo-fonte.zip`, `revisao-rede-2-4.0.md`, `historico-4.0.md` e a prévia da Rede.

---

## R47 — Segunda revisão da Segurança

**Data:** 21/11/2026 · **Commit:** c1af423

**Pedido:** "Revise a tela/função "Segurança"", com os mesmos cinco olhares da R40 à R46: um Analista de Produto Sênior avalia o todo; um Engenheiro de Software Sênior revisa o código, refatora, tira o que não serve e melhora o desempenho; um Designer Sênior com um Especialista em UX/UI revisam a tela, os botões, os textos e os fluxos; um MVP Windows confere as práticas da Microsoft, se cada função faz o melhor e se é robusta; um QA Sênior testa tudo, o óbvio e o que não é. O engenheiro aplica o que cada um pede.

**O relatório:** `docs/revisao-seguranca-2-4.0.md`, com os 11 achados, o que foi mantido, os testes e as fontes. A primeira revisão da página (R16) foi antes do desenho novo (R37), da revisão de UX (R38) e das faixas no alto das páginas (R41 a R43).

**O que mudou**
- **Produto:** as verificações (a rápida, a completa e a de uma pasta) oferecem reiniciar quando o Windows Defender só espera isso para terminar a limpeza, com o Depois como padrão e fora do Otimizar (P1); a Verificar uma pasta mostra os pendrives e cartões de memória conectados, para onde a verificação completa manda quem quer examiná-los (P2).
- **Código:** o Estado da proteção e a Auditoria de segurança começam a consulta ao Windows Update antes das outras leituras, e ela corre junto (com 1,5 segundo de leituras e 2 de Windows Update simulados: de 3,5 para 2,1 segundos, e de 3,7 para 2,1); o Core ganhou as duas metades do `Invoke-WinForgeInBackground` e o `Stop` (E1); `Get-WinForgeThreatName` saiu, e uma ameaça sem nome não pergunta mais de novo ao Defender, ameaça por ameaça; as unidades removíveis vêm de uma função só (E2).
- **Design:** "Começar" e "Agora não" na Verificação completa, "Salvar mesmo assim" e "Cancelar" na chave salva no próprio disco, a UX21 da R38 aplicada aqui (D1); "Pendrives e cartões de memória ficam de fora", no lugar de "Pen drives e discos USB" (D2).
- **Windows:** a auditoria lê a Área de Trabalho Remota pela política (de grupo, ou do MDM da empresa), que decide no lugar da chave da tela do Windows, e aconselha mudar a política quando é ela que liga (M1).
- **QA:** a cópia da chave do BitLocker que não grava diz "Não foi possível salvar a cópia da chave", com o botão "Tentar de novo", e não "não foi possível ler o BitLocker" (Q1); as assinaturas nunca atualizadas entram na auditoria como "Nunca atualizadas" (Q2); uma unidade de rede mapeada, que o WinForge como Administrador não vê, é explicada (Q3); os leitores de cartão vazios não aparecem como pendrives (Q4).
- **Traduções:** 5.631 textos (19 novos e 4 que saíram de uso).

**Conferido na nuvem pelo QA**
- **Uma bateria nova da Segurança,** 83 conferências em português e 84 em inglês e em espanhol (nestes dois, mais uma: nenhum texto em português na tela): as tarefas em segundo plano do Core (de verdade), o Estado da proteção e a Auditoria com a procura do Windows Update de verdade num runspace à parte (o tempo, a procura recebida e a largada), a Área de Trabalho Remota com e sem a política, as assinaturas nunca atualizadas, a oferta de reiniciar nas três verificações, os pendrives, a unidade que não aparece, a Chave do BitLocker que não grava, a página e os textos.
- **No código de antes (aa221d4):** cada conferência das correções falha (51); das 26 que passam, 25 conferem o que foi mantido e 1 é a dos marcadores de texto. Com as leituras e o Windows Update simulados, o Estado da proteção levou 3,5 segundos antes e 2,1 agora; a auditoria, 3,7 e 2,1.
- **40 defeitos de propósito,** e as conferências pegam todos.
- **A bateria antiga da Segurança (R16):** uma conferência pedia o texto antigo do aviso da verificação completa e passou a pedir o novo. Os mesmos números da R46.
- **Nada do que funcionava quebrou:**
  - as baterias das 14 páginas revistas, com os mesmos números da R46 (a da Segurança depois da adaptação acima); a das seis funções novas da R36 (257 em cada idioma); o Início da R13 (241), a Manutenção da R14 (243, 245 e 250), as conferências da R11 e da R12 e as gerais; as da R9 e da R10 com as mesmas falhas antigas;
  - a bateria do Início da R40 (115 em cada idioma), a da Manutenção da R41 (67), a da Limpeza da R42 (97), a do Desempenho da R43 (94), a do Reparo da R44 (92), a do Diagnóstico da R45 (87), a da Rede da R46 (128) e a conferência da QA do passo da configuração inicial (66 de 66);
  - as mensagens da janela (72 em cada idioma);
  - instalar, atualizar com um clique e o pacote de suporte, iguais aos da R46;
  - cada nome e link citado na documentação técnica (279);
  - as traduções: 5.631, nenhum sem tradução e nenhum sem uso;
  - as funções sem referência (nenhuma, entre 1.523; eram 1.517: entraram `Start-WinForgeInBackground`, `Receive-WinForgeInBackground`, `Stop-WinForgeInBackground`, `Start-WinForgePendingUpdatesSearch`, `Request-WinForgeScanRestart`, `Get-WinForgeRemovableDrives` e `Get-WinForgeMissingDriveNote`, e saiu `Get-WinForgeThreatName`) e nenhuma chamada a uma função que não existe;
  - o PSScriptAnalyzer: 242 avisos, dois a menos que na R46 (dois `catch` vazios que saíram), nenhum novo;
  - o Setup de verdade, da R46 para esta: saída 0, os 58 arquivos trocados pelos do pacote e as notas da pessoa mantidas; o zip muda em quatro módulos (Core, Diagnostics, Navigation e Security), nas traduções, no CHANGELOG e no `SHA256SUMS.txt`.

**Validado pelo MVP Windows**
- **A política da Área de Trabalho Remota:** sem ela configurada, vale a configuração do PC; configurada, a chave dela decide (1 é desligada pela política).
- **Os pendrives na verificação de uma pasta:** a regra que os tira da completa não vale para as outras.
- **A unidade mapeada:** com o UAC, cada entrada no Windows tem duas sessões, e um mapeamento vale só para a sessão em que foi criado.
- **O restante da R16:** o prazo das leituras do Defender e do firewall, o modo passivo com outro antivírus, a segunda tentativa das assinaturas no MMPC só quando ele está na ordem do Defender, a conta Convidado pelo SID e a chave fora do log.
- **O que só um PC confirma:** o roteiro, §38.

**Fontes**
- Microsoft: [Set-MpPreference](https://learn.microsoft.com/powershell/module/defender/set-mppreference), [Policy CSP - RemoteDesktopServices](https://learn.microsoft.com/windows/client-management/mdm/policy-csp-remotedesktopservices), [Troubleshoot an RDP general error in Azure VM](https://learn.microsoft.com/en-us/azure/virtual-machines/troubleshooting/troubleshoot-rdp-general-error), [Mapped drives are not available from an elevated prompt when UAC is configured to Prompt for credentials](https://learn.microsoft.com/en-us/troubleshoot/windows-client/networking/mapped-drives-not-available-from-elevated-command) e [Dialog controls](https://learn.microsoft.com/windows/apps/design/controls/dialogs-and-flyouts/dialogs)

**Entregue:** `WinForge.zip`, `WinForge-codigo-fonte.zip`, `revisao-seguranca-2-4.0.md`, `historico-4.0.md` e a prévia da Segurança.

---

## R48 — Segunda revisão das Atualizações

**Data:** 21/11/2026 · **Commit:** 6126c1c

**Pedido:** "Revise a tela/função "Atualizações"", com os mesmos cinco olhares da R40 à R47: um Analista de Produto Sênior avalia o todo; um Engenheiro de Software Sênior revisa o código, refatora, tira o que não serve e melhora o desempenho; um Designer Sênior com um Especialista em UX/UI revisam a tela, os botões, os textos e os fluxos; um MVP Windows confere as práticas da Microsoft, se cada função faz o melhor e se é robusta; um QA Sênior testa tudo, o óbvio e o que não é. O engenheiro aplica o que cada um pede.

**O relatório:** `docs/revisao-atualizacoes-2-4.0.md`, com os 13 achados, o que foi mantido, os testes e as fontes. A primeira revisão da página (R20) foi antes do desenho novo (R37), da revisão de UX (R38) e das faixas no alto das páginas (R41 a R43).

**O que mudou**
- **Produto:** a faixa no alto das Atualizações, com a versão do Windows e até quando ela recebe atualizações de segurança e, quando pede atenção, o Windows Update pausado ou atrasado, cada um com o botão para o que resolve (P1); as atualizações pausadas nas Configurações passam a valer no WinForge: o Otimizar nem procura, e Instalar atualizações e Atualizar drivers perguntam "Procurar mesmo assim?", no Cancelar (P2).
- **Código:** a instalação pelas tarefas em segundo plano do Core, sem runspace próprio nem `catch` vazio (E1); o desfecho dos drivers é o das atualizações (`Get-WinForgeUpdateRunResult -Drivers`), a escolha do reinício pendente e o prazo curto do suporte viraram uma função cada, e a Store perdeu dois `try` que nunca pegavam nada (E2); o Corrigir o Windows Update para os três serviços juntos: com 1,5 segundo para cada um parar, de cerca de 5,5 para 2,5 segundos (E3).
- **Design:** o verbo nos botões de seis perguntas, a UX21 da R38 aplicada aqui (D1); o reinício pendente numa escolha só (Reiniciar agora, Continuar sem reiniciar, Cancelar), como no Otimizar, nas atualizações, nos drivers e no Corrigir (D2); o resultado dos drivers na tabela "Resumo", como o das atualizações (D3).
- **Windows:** numa conexão limitada, o Otimizar instala só o que já foi baixado, como o próprio Windows, a menos que "Baixar atualizações em conexões limitadas" esteja ligado (M1); a sessão do Windows Update leva o nome do WinForge, e o histórico do Windows Update diz o que ele instalou (M2).
- **QA:** a instalação interrompida no meio diz "A instalação foi interrompida", e não "2 de 2 atualizações instaladas" com "; o motivo…" (Q1); quatro textos em português nas telas em inglês e em espanhol (o título "Resumo", duas frases do script da instalação, "biometria" e "sensores") saem traduzidos (Q2); a falha sem código diz que o Windows Update não informou o motivo (Q3).
- **Traduções:** 5.655 textos (28 novos e 4 que saíram de uso).

**Conferido na nuvem pelo QA**
- **Uma bateria nova das Atualizações,** 83 conferências em português e 84 em inglês e em espanhol (em português, mais a instalação que não termina, com o prazo de um minuto; nos outros dois, mais duas: nenhum texto e nenhuma palavra solta em português na tela): a busca e a instalação de verdade com um Windows Update de mentira no outro runspace (inclusive a que não termina), a pausa (a leitura e as três telas), a conexão limitada no Otimizar, o reinício pendente e os botões (com o Otimizar), os drivers e os textos, o Corrigir com o tempo de verdade, a faixa e o código.
- **No código de antes (c1af423):** das 54 conferências que chegam a rodar, 31 falham, cada uma de uma correção; as 23 que passam conferem o que foi mantido e os marcadores de texto. Com 1,5 segundo para cada serviço parar, o Corrigir o Windows Update levou cerca de 5,5 segundos antes e 2,5 agora.
- **45 defeitos de propósito,** e as conferências pegam todos.
- **A bateria antiga das Atualizações (R20):** duas conferências pediam as duas perguntas seguidas do reinício pendente e passaram a pedir a escolha só. Os mesmos números da R47.
- **Nada do que funcionava quebrou:**
  - as baterias das 14 páginas revistas, com os mesmos números da R47 (a das Atualizações depois da adaptação acima); a das seis funções novas da R36 (257 em cada idioma); o Início da R13 (241), a Manutenção da R14 (243, 245 e 250), as conferências da R11 e da R12 e as gerais; as da R9 e da R10 com as mesmas falhas antigas;
  - a bateria do Início da R40 (115 em cada idioma), a da Manutenção da R41 (67), a da Limpeza da R42 (97), a do Desempenho da R43 (94), a do Reparo da R44 (92), a do Diagnóstico da R45 (87), a da Rede da R46 (128), a da Segurança da R47 (83, 84 e 84) e a conferência da QA do passo da configuração inicial (66 de 66);
  - as mensagens da janela (72 em cada idioma);
  - instalar, atualizar com um clique e o pacote de suporte, iguais aos da R47;
  - cada nome e link citado na documentação técnica (283);
  - as traduções: 5.655, nenhum sem tradução e nenhum sem uso;
  - as funções sem referência (nenhuma, entre 1.530; eram 1.523: entraram `Get-WinForgeWindowsUpdatePause`, `Get-WinForgeUpdatePauseText`, `Test-WinForgeMeteredUpdateDownload`, `Get-WinForgeUpdatesPageStatus`, `Stop-WinForgeServices`, `Read-WinForgePendingRebootChoice` e `Get-WinForgeWindowsSupportShortText`) e nenhuma chamada a uma função que não existe;
  - o PSScriptAnalyzer: 241 avisos, um a menos que na R47 (o `catch` vazio da instalação), nenhum novo;
  - o Setup de verdade, da R47 para esta: saída 0, os 58 arquivos trocados pelos do pacote e as notas da pessoa mantidas; o zip muda em seis módulos (Drivers, Home, Maintenance, Software, WindowsSupport e WindowsUpdate), no `WinForge.Gui.ps1`, nas traduções, no CHANGELOG e no `SHA256SUMS.txt`.

**Validado pelo MVP Windows**
- **A pausa:** a situação pela chave que a Microsoft documenta (`PausedQualityStatus`: 1 pausadas; 0 e 2, não); a data pela que as Configurações gravam, em UTC. Pausadas, o Windows não baixa nem instala o que pede reinício até a data.
- **A conexão limitada:** o Windows Update só baixa as prioritárias, a menos que a pessoa (ou a política) permita baixar nela.
- **O nome na sessão:** o exemplo da Microsoft dá um; sem ele, o histórico diz "Unknown".
- **O restante da R20:** a busca sem as opcionais, a busca local antes da instalação, o reparo com os passos da Microsoft, as políticas e o Medic sem mudanças, a Store pela ponte só com Administrador.
- **O que só um PC confirma:** o roteiro, §39.

**Fontes**
- Microsoft: [Pause updates in Windows](https://support.microsoft.com/windows/manage-updates-in-windows-643e9ea7-3cf6-7da6-a25c-95d4f7f099fe), [Configure Windows Update client policies](https://learn.microsoft.com/en-us/windows/deployment/update/waas-configure-wufb), [Pausing windows update using powershell](https://learn.microsoft.com/en-us/answers/questions/1287073/pausing-windows-update-using-powershell) (Microsoft Q&A), [Metered connections in Windows](https://support.microsoft.com/en-us/windows/metered-connections-in-windows-7b33928f-a144-b265-97b6-f2e95a87c408), [Policy CSP - Update](https://learn.microsoft.com/windows/client-management/mdm/policy-csp-update), [Searching, Downloading, and Installing Updates](https://learn.microsoft.com/en-us/windows/win32/wua_sdk/searching--downloading--and-installing-updates), [IUpdateHistoryEntry::get_ClientApplicationID](https://learn.microsoft.com/en-us/windows/desktop/api/wuapi/nf-wuapi-iupdatehistoryentry-get_clientapplicationid) e [Dialog controls](https://learn.microsoft.com/windows/apps/design/controls/dialogs-and-flyouts/dialogs)

**Entregue:** `WinForge.zip`, `WinForge-codigo-fonte.zip`, `revisao-atualizacoes-2-4.0.md`, `historico-4.0.md` e a prévia das Atualizações.

---

## R49 — A aparência fora da revisão do Otimizar

**Data:** 21/11/2026 · **Commit:** 0f7b363

**Pedido:** depois da análise dos ajustes para jogos, que ficaram de fora ("nada me convenceu"): "coisas como alterações de barra de tarefas por exemplo (que são meramente visuais), devem ficar fora dos ajustes do otimizar ou recomendados. Isso é a gosto do usuário, e não recomendado. os demais ajustes sim faz sentido".

**Como estava**
- **A revisão do Otimizar** (a última etapa, "Revisar os ajustes do Windows") listava os ajustes das duas páginas, menos os segundos no relógio e o agendamento de GPU: 49 num Windows 11 24H2. Entre eles, a barra de tarefas à esquerda, a pesquisa, os ícones da área de trabalho, o modo escuro e as cores, que numa lista do Otimizar pareciam manutenção.
- **Os recomendados** (Aplicar ajustes recomendados) já eram só quatro, nenhum de aparência: as extensões de arquivos, as dicas e sugestões, as dicas da tela de bloqueio e o ID de publicidade. Ficam como estão.

**O que mudou**
- **A marca `Cosmetic`,** em `New-WinForgeTweak` e `New-WinForgeRegistryTweak`, nos 17 ajustes que só mudam a aparência ou a arrumação da tela:
  - a barra de tarefas: alinhada à esquerda, a pesquisa, o botão Visão de Tarefas, o botão do Copilot, nunca agrupar, os segundos no relógio e o Finalizar tarefa (uma opção a mais no menu da barra);
  - a área de trabalho: a Lixeira e Este Computador;
  - as cores: o modo escuro, a transparência e a cor de destaque no Iniciar, na barra de tarefas e nas barras de título;
  - os widgets da tela de bloqueio (o clima, as notícias e as cotações com o PC bloqueado);
  - o jeito do Explorador: o menu de contexto clássico, abrir em Este Computador e mostrar os arquivos ocultos.
- **A revisão do Otimizar** deixa de fora o que tem a marca: `Test-WinForgeTweakInReview` decide, no lugar da lista de Ids `Get-WinForgeTweakReviewSkipped`. São 34 num Windows 11 24H2. O que fica de fora não muda, nem se estiver em uso: desmarcar tudo desfaz só os da lista.
- **Continuam na revisão** os ajustes de privacidade, anúncios, segurança, Windows Update, teclado, jogos, energia e manutenção, como o pedido diz. Da Personalização, ficam os quatro que não são aparência: desativar os Widgets (o recurso inteiro, pela política, e não só o botão), as recomendações do Iniciar (as sugestões de dicas e de aplicativos novos) e as notificações e as dicas na tela de bloqueio.
- **Os recomendados:** a aparência nunca é recomendada. Está no comentário de `-Recommended`, e uma conferência do QA recusa um ajuste com as duas marcas.
- **O que não mudou:** as páginas Ajustes do Windows e Personalização, com os 53 ajustes e as chaves de sempre; os perfis (Trabalho, Jogos e Notebook trazem alguns de aparência), que a pessoa escolhe pelo nome e cuja descrição diz o que aplicam; exportar e importar; os textos da tela.

**Conferido na nuvem pelo QA**
- **Uma bateria nova,** 96 conferências em cada idioma: o catálogo (os 17 de aparência, nenhum de privacidade, Windows Update, teclado, jogos ou energia entre eles, nenhum recomendado, os 4 recomendados oferecidos, as páginas e os perfis como eram), a regra para cada um dos 53 ajustes e a revisão inteira com o Windows simulado: no Windows 11 e no 10, com o modo escuro, a barra à esquerda, os ocultos e os segundos em uso (deixada como veio e com tudo desmarcado), uma chave de fora na resposta, outra conta elevada, a política da empresa e o menu de texto.
- **No código de antes (6126c1c):** 37 das 96 conferências falham, cada uma de algo que mudou (a marca, a regra, a lista da revisão e o que ela desfaz); as que passam conferem o que foi mantido (os recomendados, as páginas, os perfis, a política da empresa) e os 35 ajustes que continuam na revisão.
- **13 defeitos de propósito,** e as conferências pegam todos.
- **A bateria do Otimizar (R28):** a conferência que pedia a lista antiga ("só os segundos no relógio e o agendamento de GPU") passou a pedir a regra nova, com os segundos e o agendamento de fora e as atualizações antecipadas dentro. Os mesmos números da R48.
- **Nada do que funcionava quebrou:**
  - as baterias das 14 páginas revistas, com os mesmos números da R48 (a do Otimizar depois da adaptação acima); a das seis funções novas da R36 (257 em cada idioma); o Início da R13 (241), a Manutenção da R14 (243, 245 e 250), as conferências da R11 e da R12 e as gerais; as da R9 e da R10 com as mesmas falhas antigas;
  - as baterias das segundas revisões: Início (115 em cada idioma), Manutenção (67), Limpeza (97), Desempenho (94), Reparo (92), Diagnóstico (87), Rede (128), Segurança (83, 84 e 84) e Atualizações (83, 84 e 84), e a conferência da QA do passo da configuração inicial (66 de 66);
  - as mensagens da janela (72 em cada idioma);
  - instalar, atualizar com um clique e o pacote de suporte, como na R48;
  - cada nome e link citado na documentação técnica (285);
  - as traduções: 5.655, nenhum texto novo e nenhum sem uso;
  - as funções sem referência (nenhuma, entre 1.530: saiu `Get-WinForgeTweakReviewSkipped` e entrou `Test-WinForgeTweakInReview`) e nenhuma chamada a uma função que não existe;
  - o PSScriptAnalyzer: os mesmos 241 avisos da R48, nenhum novo;
  - o Setup de verdade, da R48 para esta: saída 0, os 58 arquivos trocados pelos do pacote e as notas da pessoa mantidas; o zip muda só no `Tweaks.psm1`, nas traduções (só as linhas de referência), no CHANGELOG e no `SHA256SUMS.txt`.

**Entregue:** `WinForge.zip`, `WinForge-codigo-fonte.zip` e `historico-4.0.md`.

---

## R50 — O Explorador e a tela de bloqueio de volta à revisão do Otimizar

**Data:** 21/11/2026 · **Commit:** 72c8bd7

**Pedido:** sobre os ajustes que a R49 tirou da revisão do Otimizar, "Tela de bloqueio: os widgets (clima, notícias e cotações). Explorador: menu de contexto clássico, abrir em Este Computador e mostrar arquivos ocultos. Estes pode manter no recomendado."

**Como foi lido:** "o recomendado", aqui, é a lista da revisão do Otimizar, a mesma que o pedido da R49 chamou de "ajustes do otimizar ou recomendados". Os quatro voltam para ela, como eram até a R48. Aplicar ajustes recomendados continua com os mesmos quatro de antes.

**O que mudou**
- **Saiu a marca `Cosmetic`** do menu de contexto clássico, de abrir o Explorador em Este Computador, de mostrar os arquivos ocultos e dos widgets da tela de bloqueio. Ficam com ela 13 ajustes, todos da Personalização: a barra de tarefas, a área de trabalho e as cores.
- **A revisão do Otimizar** volta a oferecê-los, marcados conforme o Windows está: são 38 num Windows 11 24H2 (eram 34 na R49 e 49 até a R48).
- **O comentário da marca** diz que o jeito do Explorador e os widgets da tela de bloqueio ficam na revisão.
- **CHANGELOG, documentação técnica e roteiro (§40)** passam a dizer o que fica de fora: a barra de tarefas, a área de trabalho e as cores.

**Conferido na nuvem pelo QA**
- **A bateria da R49, refeita para a R50:** 101 conferências em cada idioma. Os 13 de aparência, os quatro de volta (não são aparência, entram na revisão e estão na lista do Windows 11), nenhum ajuste da página Ajustes do Windows com a marca, as contas da lista (38 no Windows 11, 37 com a política da empresa), os ocultos em uso marcados na lista e desfeitos com tudo desmarcado, junto com as extensões e o Modo de Jogo, e o aviso de outra conta com os da lista.
- **No código de antes (0f7b363):** 19 das 101 falham, cada uma de um dos quatro ajustes.
- **Nada do que funcionava quebrou:** as baterias dos Ajustes do Windows (412, 422 e 422), da Personalização (265, 270 e 270) e do Otimizar (146, 151 e 151), com os mesmos números da R49; as funções sem referência (nenhuma, entre 1.530); as traduções (5.655, nenhum texto novo). A regressão completa roda com a R51.

**Entregue:** junto com a R51.

---

## R51 — Segunda revisão dos Programas

**Data:** 21/11/2026 · **Commit:** eb5a3ce

**Pedido:** "Revise a tela/função "Programas"", com os mesmos cinco olhares da R40 à R48: um Analista de Produto Sênior avalia o todo; um Engenheiro de Software Sênior revisa o código, refatora, tira o que não serve e melhora o desempenho; um Designer Sênior com um Especialista em UX/UI revisam a tela, os botões, os textos e os fluxos; um MVP Windows confere as práticas da Microsoft, se cada função faz o melhor e se é robusta; um QA Sênior testa tudo, o óbvio e o que não é. O engenheiro aplica o que cada um pede.

**O relatório:** `docs/revisao-programas-2-4.0.md`, com os 12 achados, o que foi mantido, os testes e as fontes. A primeira revisão da página (R21) foi antes do desenho novo (R37), da revisão de UX (R38) e das faixas no alto das páginas (R41 a R48).

**O que mudou**
- **Produto:** a restauração procura o backup também na raiz dos pendrives, HDs externos e outras partições, onde o próprio backup o grava, diz onde cada um está e oferece Procurar de novo quando não acha (P1); sem o Instalador de Aplicativo, logo depois de formatar, ela oferece repará-lo ali mesmo, e os programas vêm marcados (P2); a faixa do alto dos Programas, só quando ele falta, leva ao reparo (P3).
- **Código:** o `winget list` lido num lugar só (`Read-WinForgeWingetList`), que guarda a leitura: Buscar e os essenciais, logo depois de Listar ou de Desinstalar, não leem de novo; saíram duas guardas que não guardavam nada (E1); o registro do Instalador de Aplicativo numa função (`Register-WinForgeWinget`), da tela do reparo e da restauração (E2).
- **Design:** o verbo nos botões de onze perguntas e listas, a UX21 da R38 aplicada aqui, com o Remover em vermelho quando um aplicativo aposentado está marcado (D1); o reinício oferecido depois de instalar, desinstalar e restaurar, quando um instalador ou um driver pede, menos quando ele já reinicia sozinho e dentro do Otimizar (D2).
- **Windows:** o Mapas, que a Microsoft tirou da Store em julho de 2025, diz que não volta (M1); o Paint 3D, fora da Store desde novembro de 2024, entra na lista de remover, e o Paint de sempre continua protegido (M2).
- **QA:** o backup numa pasta do disco do Windows (C:\Backup) pede para copiá-la antes de formatar, como Documentos (Q1); a pasta de fora com um backup só dentro leva a ele, e com vários a faixa diz quantos e o mais novo (Q2); a reinstalação com um programa que só termina ao reiniciar não conta mais como problema (Q3).
- **Traduções:** 5.682 textos (30 novos e 3 que saíram de uso).

**Conferido na nuvem pelo QA**
- **Uma bateria nova dos Programas,** 75 conferências em português e 87 em inglês e em espanhol (nos outros dois, mais duas por seção: nenhum texto e nenhuma palavra solta em português na tela): a restauração achando o backup (Documentos, pendrive, HD externo, Procurar de novo, a raiz digitada), o reparo na restauração, a faixa e a leitura única do winget, os botões, o reinício, os aplicativos aposentados e o backup no disco do Windows, e os textos.
- **No código de antes (72c8bd7):** das 75 conferências, 51 falham, cada uma de uma correção; as 24 que passam conferem o que foi mantido (a tela do reparo, a restauração com o winget no PC, os casos sem reinício, o backup fora do disco do Windows, o Paint de sempre) e os marcadores de texto.
- **37 defeitos de propósito,** e as conferências pegam todos.
- **A bateria antiga dos Programas (R21):** os mesmos 108, 117 e 117, com uma adaptação: a conferência de "nenhum backup encontrado" procurava a frase antiga, que saiu das traduções (em inglês e em espanhol, falhava); agora procura a nova.
- **Nada do que funcionava quebrou:**
  - as baterias das 14 páginas revistas, com os mesmos números da R50 (a dos Programas da R21 depois da adaptação acima; a da Rede da R22 com a mesma conferência antiga do escudo); a das seis funções novas da R36 (257 em cada idioma); o Início da R13 (241), a Manutenção da R14 (243, 245 e 250), as conferências da R11 e da R12 e as gerais; as da R9 e da R10 com as mesmas falhas antigas;
  - as baterias das segundas revisões: Início (115 em cada idioma), Manutenção (67), Limpeza (97), Desempenho (94), Reparo (92), Diagnóstico (87), Rede (128), Segurança (83, 84 e 84) e Atualizações (83, 84 e 84), a do Explorador e da tela de bloqueio da R50 (101) e a conferência da QA do passo da configuração inicial (66 de 66);
  - as mensagens da janela (72 em cada idioma);
  - instalar, atualizar com um clique e o pacote de suporte, como na R49;
  - cada nome e link citado na documentação técnica (287);
  - as traduções: 5.682, 30 textos novos e 3 que saíram de uso;
  - as funções sem referência (nenhuma, entre 1.536, seis novas) e nenhuma chamada a uma função que não existe;
  - o PSScriptAnalyzer: os mesmos 241 avisos da R49, nenhum novo;
  - o Setup de verdade, da R49 para esta (a R50 não teve pacote): saída 0, os 58 arquivos trocados pelos do pacote e as notas da pessoa mantidas; o zip muda nos cinco módulos desta revisão (`Software.psm1`, `Backup.psm1`, `PreinstalledApps.psm1`, `WindowsFeatures.psm1` e `Console.psm1`), no `Tweaks.psm1` da R50, na janela, nas traduções, no CHANGELOG e no `SHA256SUMS.txt`.

**Validado pelo MVP Windows**
- **Os aplicativos aposentados:** pela lista de recursos descontinuados do Windows, o Paint 3D saiu da Microsoft Store em 4 de novembro de 2024; o Mapas, até julho de 2025; o Visualizador 3D, em 1º de julho de 2026 (a lista já dizia isso).
- **O reinício dos instaladores:** 0x8A150109 pede o reinício; 0x8A15010B é o instalador reiniciando sozinho.
- **O `winget source update` uma vez por sessão** ficou: o winget atualiza a fonte sozinho ao usá-la, quando ela tem mais de 15 minutos, e a atualização explícita só antecipa isso e avisa quando falha.
- **O registro na restauração** é o mesmo comando do reparo (R36), só para a conta de quem usa o PC.
- **O que só um PC confirma:** o roteiro, §41.

**Fontes**
- Microsoft: [Deprecated features in the Windows client](https://learn.microsoft.com/windows/whats-new/deprecated-features) e [settings command (winget)](https://learn.microsoft.com/windows/package-manager/winget/settings); os códigos do winget pela tabela reproduzida em [Troubleshooting Errors with WinGet](https://kb.filewave.com/books/microsoft-windows-package-manager-winget/page/troubleshooting-errors-with-winget) (FileWave).

**Entregue:** `WinForge.zip`, `WinForge-codigo-fonte.zip`, `revisao-programas-2-4.0.md`, `historico-4.0.md` e a prévia dos Programas.

---

## R52 — Segunda revisão dos Ajustes do Windows

**Data:** 22/11/2026 · **Commit:** 0cbd196

**Pedido:** "Revise a tela/função "Ajustes do Windows"", com os mesmos cinco olhares da R40 à R51: um Analista de Produto Sênior avalia o todo; um Engenheiro de Software Sênior revisa o código, refatora, tira o que não serve e melhora o desempenho; um Designer Sênior com um Especialista em UX/UI revisam a tela, os botões, os textos e os fluxos; um MVP Windows confere as práticas da Microsoft, se cada função faz o melhor e se é robusta; um QA Sênior testa tudo, o óbvio e o que não é. O engenheiro aplica o que cada um pede.

**O relatório:** `docs/revisao-ajustes-2-4.0.md`, com os 12 achados, o que foi mantido, os testes e as fontes. A primeira revisão da página (R23) foi antes do desenho novo (R37), da revisão de UX (R38) e das faixas no alto das páginas (R41 a R48).

**O que mudou**
- **Produto:** Aplicar ajustes recomendados não pede mais Administrador: os quatro só mudam o perfil do usuário; sem Administrador, o ponto de restauração fica de fora, com aviso; elevado com outra conta, para antes de perguntar e diz por onde aplicar (P1). Elevado com outra conta, os ajustes do perfil do usuário ficam de fora dos perfis, da importação, da exportação, do Backup antes de formatar e da lista, que mostra "Outra conta" com a chave desligada (P2). O perfil Trabalho sem os segundos no relógio (P3).
- **Código:** saiu o modo de Aplicar ajustes recomendados para dentro do Otimizar (`-Ids`, `-Embedded`, `-PassThru`), que ninguém chamava, com o `-Unattended` do lote e quatro parâmetros sem uso do desfazer (E1); o ajuste pelo Id vem de um índice (1.060 buscas em 62 ms, eram 954 ms), e a regra de outra conta virou `Get-WinForgeTweaksForSession`, usada em seis lugares (E2).
- **Design:** a chave muda na própria linha, com "Alterando…", o estado lido de novo, o foco e o Narrador, e a tela de execução só abre quando há algo a ler (D1, a UX19 da R38); o verbo nos botões das perguntas e listas (D2, a UX21); o resumo do alto no lugar do parágrafo, com Recomendados e Mudanças (D3, a UX14); as linhas-esqueleto no lugar de "Lendo..." (D4, a UX16). D1, D3 e D4 valem também para a Personalização.
- **Windows:** o Alto desempenho fora dos PCs com Modern Standby, que só permitem o plano Equilibrado e os derivados dele (M1); a web na busca diz que o Explorador deixa de sugerir as buscas recentes, como a política faz (M2).
- **QA:** a chave da Inicialização Rápida que liga a hibernação junto diz isso na faixa (Q1).
- **A documentação técnica:** a conta de funções de quatro módulos (Cleanup, Core, Maintenance e Schedule), que tinha ficado para trás, e a de itens com Administrador (38).
- **Traduções:** 5.706 textos (30 novos e 6 que saíram de uso).

**Conferido na nuvem pelo QA**
- **Uma bateria nova dos Ajustes,** 137 conferências em português e 147 em inglês e em espanhol (nos outros dois, mais uma por seção: nenhuma palavra solta em português na tela): os recomendados sem Administrador, com ele e com outra conta; outra conta nos perfis, na importação, na exportação, no backup, na lista, nas teclas do idioma, no menu de texto e no Otimizar; os perfis; o Modern Standby; a web na busca; quando a chave termina na linha; os botões; o código e a velocidade; o resumo do alto; e a janela (o esqueleto, o resumo, a linha de outra conta e a chave na linha, com o foco, o leitor de tela e a tela de execução quando há algo a ler).
- **No código de antes (eb5a3ce):** das 137 conferências, 100 falham, cada uma de uma correção; as 37 que passam conferem o que foi mantido e os marcadores de texto.
- **46 defeitos de propósito,** e as conferências pegam todos. O do foco só foi pego depois de a bateria imitar o WPF, que tira o foco de uma chave desligada.
- **As baterias antigas, adaptadas ao que mudou de propósito:** a dos Ajustes (R23), nas conferências do escudo (Aplicar ajustes recomendados sem ele) e dos recomendados sem Administrador (aplicados, sem o ponto), com os mesmos 412, 422 e 422; e a do Explorador e da tela de bloqueio (R50), na conferência dos perfis (o Trabalho sem os segundos), com os mesmos 101.
- **Nada do que funcionava quebrou:**
  - as baterias das 14 páginas revistas, com os mesmos números da R51 (a dos Ajustes da R23 depois da adaptação acima; a da Rede da R22 com a mesma conferência antiga do escudo); a das seis funções novas da R36 (257 em cada idioma); o Início da R13 (241), a Manutenção da R14 (243, 245 e 250), as conferências da R11 e da R12 e as gerais; as da R9 e da R10 com as mesmas falhas antigas;
  - as baterias das segundas revisões: Início (115 em cada idioma), Manutenção (67), Limpeza (97), Desempenho (94), Reparo (92), Diagnóstico (87), Rede (128), Segurança (83, 84 e 84), Atualizações (83, 84 e 84) e Programas (75, 87 e 87), a do Explorador e da tela de bloqueio da R50 (101) e a conferência da QA do passo da configuração inicial (66 de 66);
  - as mensagens da janela (72 em cada idioma);
  - instalar, atualizar com um clique e o pacote de suporte, como na R51;
  - cada nome e link citado na documentação técnica (300);
  - as traduções: 5.706, 30 textos novos e 6 que saíram de uso;
  - as funções sem referência (nenhuma, entre 1.544: nove novas e uma que saiu) e nenhuma chamada a uma função que não existe;
  - o PSScriptAnalyzer: 240 avisos, nenhum novo; saiu o do `Id` de `Get-WinForgeTweakById`, que a análise não via ser usado dentro do filtro antigo;
  - o Setup de verdade, da R51 para esta: saída 0, os 58 arquivos trocados pelos do pacote e as notas da pessoa mantidas; o zip muda só nos cinco módulos desta revisão (`Tweaks.psm1`, `Core.psm1`, `Console.psm1`, `Navigation.psm1` e `Menus.psm1`), na janela, nas traduções, no CHANGELOG e no `SHA256SUMS.txt`.

**Validado pelo MVP Windows**
- **O Modern Standby:** a Microsoft diz que esses PCs só permitem o plano Equilibrado ou os derivados dele; o WinForge lê o campo `AoAc` de `SYSTEM_POWER_CAPABILITIES` ("the system supports the S0 low power idle model"), o byte 20, uma vez por sessão, e nada some se a leitura falha.
- **A web na busca:** `DisableSearchBoxSuggestions` é "Turn off display of recent search entries in the File Explorer search box", do usuário, do Windows 10 2004 com a KB5005101 e do Windows 11 21H2 em diante.
- **A chave na linha:** a Microsoft orienta usar a chave para opções de dois estados que valem logo depois da mudança.
- **Os segundos no relógio:** uma atividade periódica não deixa o processador entrar num estado de baixo consumo (Raymond Chen).
- **O que só um PC confirma:** o roteiro, §42.

**Fontes**
- Microsoft: [Power Policy Settings](https://learn.microsoft.com/windows/win32/power/power-policy-settings), [SYSTEM_POWER_CAPABILITIES](https://learn.microsoft.com/windows/win32/api/winnt/ns-winnt-system_power_capabilities), [Policy CSP - ADMX_WindowsExplorer](https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-admx-windowsexplorer), [Toggle switches](https://learn.microsoft.com/en-sg/windows/apps/design/controls/toggles) e [Now that computers have more than 4MB of memory, can we get seconds on the taskbar?](https://devblogs.microsoft.com/oldnewthing/20220411-00/?p=106456) (Raymond Chen).

**Entregue:** `WinForge.zip`, `WinForge-codigo-fonte.zip`, `revisao-ajustes-2-4.0.md`, `historico-4.0.md` e a prévia dos Ajustes do Windows.

---

## R53 — Segunda revisão da Personalização

**Data:** 22/11/2026 · **Commit:** d920d9a

**Pedido:** "Revise a tela/função "Personalização"", com os mesmos cinco olhares da R40 à R52: um Analista de Produto Sênior avalia o todo; um Engenheiro de Software Sênior revisa o código, refatora, tira o que não serve e melhora o desempenho; um Designer Sênior com um Especialista em UX/UI revisam a tela, os botões, os textos e os fluxos; um MVP Windows confere as práticas da Microsoft, se cada função faz o melhor e se é robusta; um QA Sênior testa tudo, o óbvio e o que não é. O engenheiro aplica o que cada um pede.

**O relatório:** `docs/revisao-personalizacao-2-4.0.md`, com os 10 achados, o que foi mantido, os testes e as fontes. A primeira revisão da página (R24) foi antes do desenho novo (R37), da revisão de UX (R38) e da chave na própria linha (R52); a R52 já tinha dado à Personalização o resumo do alto, as linhas cinza e a chave na linha, e esta olhou o que é só dela.

**O que mudou**
- **Produto:** a cor de destaque escolhida pelo WinForge passa a ter desfazer no Histórico de mudanças: volta a cor de antes inteira (os sete valores que o Windows grava), até a automática, uma personalizada e a de um perfil novo; se a cor foi trocada depois, fica como está; elevado com outra conta, não desfaz (P1). As teclas que trocam o idioma do teclado, nos Ajustes do Windows, ganham o mesmo desfazer (P2).
- **Código:** uma especificação por escolha (`Get-WinForgeChoiceSpec`), com um leitor, um gravador e um desfazer que confere pelo tipo cada valor que vem do diário; a cor aceita `-Color`, sem a pergunta, e `Get-WinForgeAccentColorKey` diz qual é a de agora (E1). A chave na própria linha da R52 passa a servir a outras linhas, pelo tipo guardado (`Kind`), e o foco e o aviso ao leitor de tela ficam numa função só (E2).
- **Design:** a cor de destaque escolhida na própria linha, nas oito cores em círculos e na Automática, com um anel na de agora, o teclado (o Tab entra na marcada; as setas andam) e o Narrador; a tela de execução só abre para a pergunta do Explorador e na Automática; a busca leva à linha (D1, a UX19 da R38 para a cor). As linhas de ação dentro dos grupos sem o ícone do assunto, com o texto no mesmo lugar das chaves (D2, a UX13). Uma frase curta de até 60 letras em cada um dos 53 ajustes, nos três idiomas, e a inteira na dica e no leitor de tela, nas duas páginas (D3, a UX15).
- **Windows:** os Widgets dizem que valem para todas as contas do PC, porque a política `AllowNewsAndInterests` é do computador (M1).
- **QA:** o Modo escuro ligado na própria linha, com a aparência Automática, refaz a página; o foco e o aviso ao leitor de tela agora vão para a linha nova (Q1), e a rolagem volta quando a lista fica pronta (Q2).
- **Traduções:** 5.765 textos (61 novos e 2 que saíram de uso).

**Conferido na nuvem pelo QA**
- **Uma bateria nova da Personalização,** 93 conferências em português e 99 em inglês e em espanhol (nos outros dois, mais uma por seção: nenhuma palavra solta em português na tela): a cor pela linha e pelo menu de texto; o desfazer da cor, com o diário mexido de seis jeitos e o Histórico de mudanças de verdade; o desfazer das teclas do idioma; a frase curta dos 53 ajustes nos três idiomas; a busca e o código; e a janela (a linha da cor, as linhas de ação, a cor mudando na linha e o Modo escuro com o tema da janela trocando).
- **No código de antes (0cbd196):** 69 conferências falham, cada uma de uma correção; as que passam conferem o que foi mantido e os marcadores de texto.
- **45 defeitos de propósito,** e as conferências pegam todos. Dois da rolagem só foram pegos depois de a bateria imitar o WPF, que não rola a página além do alto enquanto as linhas cinza estão na tela.
- **Nada do que funcionava quebrou:**
  - as baterias das 14 páginas revistas, com os mesmos números da R52, sem nada a adaptar (a da Personalização da R24, 265, 270 e 270; a dos Ajustes da R23, 412, 422 e 422; a da Busca da R26, 109, 98 e 101; a da Rede da R22 com a mesma conferência antiga do escudo); a das seis funções novas da R36 (257 em cada idioma); o Início da R13 (241), a Manutenção da R14 (243, 245 e 250), as conferências da R11 e da R12 e as gerais; as da R9 e da R10 com as mesmas falhas antigas;
  - as baterias das segundas revisões: Início (115 em cada idioma), Manutenção (67), Limpeza (97), Desempenho (94), Reparo (92), Diagnóstico (87), Rede (128), Segurança (83, 84 e 84), Atualizações (83, 84 e 84), Programas (75, 87 e 87) e Ajustes do Windows (137, 147 e 147), a do Explorador e da tela de bloqueio da R50 (101) e a conferência da QA do passo da configuração inicial (66 de 66);
  - as mensagens da janela (72 em cada idioma);
  - instalar, atualizar com um clique e o pacote de suporte, como na R52;
  - cada nome e link citado na documentação técnica (308);
  - as traduções: 5.765, 61 textos novos e 2 que saíram de uso;
  - as funções sem referência (nenhuma, entre 1.554: dez novas) e nenhuma chamada a uma função que não existe;
  - os nomes do XAML: a conferência pegou um nome sem uso no estilo novo da amostra (o do anel), que saiu antes da entrega;
  - o PSScriptAnalyzer: 243 avisos; os três a mais são dos dois tipos que todos os cliques da janela já têm (o nome `$sender`/`$eventArgs` e o `$eventArgs` sem uso), do clique da amostra de cor, que segue o padrão do arquivo;
  - o Setup de verdade, da R52 para esta: saída 0, os 58 arquivos trocados pelos do pacote e as notas da pessoa mantidas; o zip muda só nos quatro módulos desta revisão (`Tweaks.psm1`, `Journal.psm1`, `Navigation.psm1` e `Core.psm1`), na janela (`WinForge.Gui.ps1` e `MainWindow.xaml`), nas traduções, no CHANGELOG e no `SHA256SUMS.txt`.

**Validado pelo MVP Windows**
- **A cor de destaque:** "Show accent color on Start and taskbar" só existe com o modo do Windows escuro ou personalizado, e a cor automática vem da tela de fundo, como a Microsoft descreve; por isso a cor escolhida com o modo claro muda na linha sem reiniciar o Explorador.
- **O desfazer:** devolve exatamente os valores de antes, pelos caminhos e tipos fixos do WinForge; do diário só vêm os dados, e um caminho posto nele é ignorado. Os programas são avisados da cor desfeita como da escolhida (`WM_SETTINGCHANGE` com "ImmersiveColorSet", sem esperar janela travada).
- **Os Widgets:** `AllowNewsAndInterests` é documentada com "Scope: Device", em `SOFTWARE\Policies\Microsoft\Dsh`.
- **A chave e a cor na linha:** a Microsoft orienta usar a chave para o que vale logo depois da mudança, e a cor segue a mesma regra.
- **O que só um PC confirma:** o roteiro, §43.

**Fontes**
- Microsoft: [Personalize your Colors in Windows](https://support.microsoft.com/en-us/help/4531350), [Policy CSP - NewsAndInterests](https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-newsandinterests) e [Toggle switches](https://learn.microsoft.com/en-sg/windows/apps/design/controls/toggles).

**Entregue:** `WinForge.zip`, `WinForge-codigo-fonte.zip`, `revisao-personalizacao-2-4.0.md`, `historico-4.0.md` e a prévia da Personalização, antes e depois.

---

## R54 — Segunda revisão do Sobre o WinForge

**Data:** 22/11/2026 · **Commit:** 725dd4f

**Pedido:** "Revise a tela/função "Sobre o WinForge"", com os mesmos cinco olhares da R40 à R53: um Analista de Produto Sênior avalia o todo; um Engenheiro de Software Sênior revisa o código, refatora, tira o que não serve e melhora o desempenho; um Designer Sênior com um Especialista em UX/UI revisam a tela, os botões, os textos e os fluxos; um MVP Windows confere as práticas da Microsoft, se cada função faz o melhor e se é robusta; um QA Sênior testa tudo, o óbvio e o que não é. O engenheiro aplica o que cada um pede.

**O relatório:** `docs/revisao-sobre-2-4.0.md`, com os 10 achados, o que foi mantido, os testes e as fontes. A primeira revisão da página (R25) foi antes do desenho novo (R37), da revisão de UX (R38) e das faixas do alto das outras páginas (R41 a R48).

**O que mudou**
- **Produto:** o monitor na bandeja avisa da versão nova do WinForge: consulta o GitHub no máximo uma vez a cada 20 horas, nunca numa conexão limitada ou na bateria, mostra o balão uma vez por versão e deixa o aviso no menu do ícone até a atualização; o clique abre Verificar nova versão. No alto da página, a linha Versão diz se esta é a mais recente ou qual está disponível, e leva a Verificar nova versão (P1).
- **Código:** cada atalho lido uma vez pelo COM enquanto o arquivo não muda, e não duas vezes a cada desenho da página (`Read-WinForgeShortcutCached`, E1); a última versão consultada guardada num lugar só, por Verificar nova versão e pelo monitor (`Save-WinForgeUpdateCheck` e `Get-WinForgeKnownUpdate`, E2); os nomes dos idiomas numa lista só.
- **Design:** o subtítulo numa frase curta (D1, a UX18 da R38); a Aparência, o Idioma e as amostras da cor de destaque com o teclado de um grupo de opções do Windows, e a Aparência marcada sem refazer a página (D2); os verbos nas quatro perguntas (D3, a UX21); o resumo sem a linha do Administrador quando a janela já está com ele (D4).
- **Windows:** os avisos de uma vez do monitor (tela azul, teste de memória) mostram o balão uma vez, e não a cada 15 segundos até a conferência seguinte (M1).
- **QA:** o título "Avisos pausados" traduzido (Q1, a UX25); com a conta de outro Administrador, o resumo sem a linha do atalho dessa conta (Q2).
- **Os READMEs:** com o monitor ligado, o WinForge avisa quando sai uma versão nova.
- **Traduções:** 5.771 textos (8 novos e 2 que saíram de uso).

**Conferido na nuvem pelo QA**
- **Uma bateria nova do Sobre o WinForge,** 81 conferências em português e 87 em inglês e em espanhol (nos outros dois, mais uma por seção: nenhuma palavra solta em português na tela): o resumo do alto, o aviso da versão no monitor e os avisos de uma vez, Verificar nova versão e o pacote de suporte com os botões, o código e a janela (a Aparência, o Idioma e as amostras pelo teclado, a Aparência marcada, o resumo e a linha da versão nova).
- **No código de antes (d920d9a):** 47 das 81 conferências falham, cada uma de uma correção; as 34 que passam conferem o que foi mantido e os marcadores de texto.
- **42 defeitos de propósito,** e as conferências pegam todos.
- **As baterias antigas, adaptadas ao que mudou de propósito:** a do Sobre o WinForge (R25), nas duas conferências do resumo (três linhas com o Administrador, sem a linha dele), com os mesmos 164, 169 e 169; a da Personalização da R53, na conferência do teclado das amostras (as setas sem dar a volta), com os mesmos 93, 99 e 99; e a da Busca (R26), que carrega só algumas funções da janela e passou a carregar também a do teclado dos grupos, que o cartão Idioma usa, com os mesmos 109, 98 e 101.
- **Nada do que funcionava quebrou:**
  - as baterias das 14 páginas revistas, com os mesmos números da R53 (a do Sobre o WinForge da R25, a da Personalização da R53 e a da Busca da R26 depois da adaptação acima; a da Rede da R22 com a mesma conferência antiga do escudo); a das seis funções novas da R36 (257 em cada idioma); o Início da R13 (241), a Manutenção da R14 (243, 245 e 250), as conferências da R11 e da R12 e as gerais; as da R9 e da R10 com as mesmas falhas antigas;
  - as baterias das segundas revisões: Início (115 em cada idioma), Manutenção (67), Limpeza (97), Desempenho (94), Reparo (92), Diagnóstico (87), Rede (128), Segurança (83, 84 e 84), Atualizações (83, 84 e 84), Programas (75, 87 e 87), Ajustes do Windows (137, 147 e 147) e Personalização (93, 99 e 99), a do Explorador e da tela de bloqueio da R50 (101) e a conferência da QA do passo da configuração inicial (66 de 66);
  - as mensagens da janela (72 em cada idioma);
  - instalar, atualizar com um clique e o pacote de suporte, como na R53;
  - cada nome e link citado na documentação técnica (312);
  - as traduções: 5.771, 8 textos novos e 2 que saíram de uso;
  - as funções sem referência (nenhuma, entre 1.558: quatro novas) e nenhuma chamada a uma função que não existe;
  - o PSScriptAnalyzer: os mesmos 243 avisos da R53, nenhum novo;
  - o Setup de verdade, da R53 para esta: saída 0, os 58 arquivos trocados pelos do pacote e as notas da pessoa mantidas; o zip muda só nos cinco módulos desta revisão (`Launcher.psm1`, `AppUpdate.psm1`, `Agent.psm1`, `Reports.psm1` e `Navigation.psm1`), na janela, no monitor (`WinForge.Agent.ps1`), nas traduções, nos três READMEs, no CHANGELOG e no `SHA256SUMS.txt`.

**Validado pelo MVP Windows**
- **As notificações:** a Microsoft orienta mostrar o aviso de um evento uma vez, e o de uma tarefa opcional no máximo uma vez por dia, até três vezes; a versão nova aparece uma vez por versão.
- **A conexão limitada:** a Microsoft orienta adiar o que não é urgente e não buscar dados por antecipação; o monitor não consulta o GitHub numa conexão limitada nem na bateria.
- **A versão da API do GitHub:** sem o cabeçalho `X-GitHub-Api-Version`, o pedido usa a versão padrão e passa à seguinte quando ela sai de uso; com uma versão encerrada, viria "410 Gone". Uma cópia instalada não troca o cabeçalho a tempo, e o WinForge continua sem ele.
- **O teclado dos grupos:** como a Microsoft descreve um grupo de opções: o Tab entra na marcada, as setas andam pelas opções e não dão a volta.
- **O que só um PC confirma:** o roteiro, §44.

**Fontes**
- Microsoft: [Notifications](https://learn.microsoft.com/windows/win32/uxguide/mess-notif), [How to manage metered network cost constraints](https://learn.microsoft.com/en-us/previous-versions/windows/apps/hh750310(v=win.10)) e [Radio buttons](https://learn.microsoft.com/en-my/windows/apps/develop/ui/controls/radio-button).
- GitHub: [API versions](https://docs.github.com/en/rest/about-the-rest-api/api-versions).

**Entregue:** `WinForge.zip`, `WinForge-codigo-fonte.zip`, `revisao-sobre-2-4.0.md`, `historico-4.0.md` e a prévia do Sobre o WinForge, antes e depois.

---

## R55 — Segunda revisão da Busca

**Data:** 22/11/2026 · **Commit:** 0958da4

**Pedido:** "Revise a tela/função "Buscar"", com os mesmos cinco olhares da R40 à R54: um Analista de Produto Sênior avalia o todo; um Engenheiro de Software Sênior revisa o código, refatora, tira o que não serve e melhora o desempenho; um Designer Sênior com um Especialista em UX/UI revisam a tela, os botões, os textos e os fluxos; um MVP Windows confere as práticas da Microsoft, se cada função faz o melhor e se é robusta; um QA Sênior testa tudo, o óbvio e o que não é. O engenheiro aplica o que cada um pede.

**O relatório:** `docs/revisao-busca-2-4.0.md`, com os 10 achados, o que foi mantido, os testes e as fontes. A primeira revisão da Busca (R26) foi antes do desenho novo (R37) e da revisão de UX (R38), que deixou para ela a UX26 e a UX27.

**O que mudou**
- **Produto:** as buscas sobre o próprio WinForge trazem o que é dele: "atualizar winforge" acha Verificar nova versão (antes, Manter programas na versão atual), "avisos do winforge" acha o Monitor na bandeja (antes, a chave Notificações do Windows) e "winforge", a página Sobre o WinForge (P1).
- **Código:** a página de cada grupo de ajustes procurada uma vez na montagem do índice, e não uma vez por ajuste (E1, na nuvem, a parte dos ajustes cai de 156 a 199 ms para 97 a 129 ms); o comentário da ordenação dizia que os empates favoreciam o destaque da página, o que o código nunca fez. O desempate foi testado e ficou de fora, porque punha ações pesadas na frente das que só olham; o comentário diz o que o código faz (E2).
- **Design:** a página achada pelo nome traz logo depois o caminho recomendado dela ("limpar": Limpeza e Limpeza rápida; D1, a UX26 da R38); a linha de cima diz a página e o grupo ("Ajustes do Windows > Explorador"), no lugar de "> ajuste" (D2, a UX27); a dica da caixa com duas frases, sem prometer o que o Enter nem sempre faz (D3).
- **Windows:** o leitor de tela ouve o caminho da linha de cima com vírgulas, sem o sinal ">" (M1); a caixa passa o atalho Ctrl+K ao leitor de tela, como os botões das páginas (M2).
- **QA:** a página achada por qualquer palavra do título, e não só pela primeira ("tweaks", em inglês, acha Windows tweaks; Q1); o singular de uma palavra vale como palavra inteira, e não como começo de outra ("programas", em espanhol, não traz mais o Programador de tareas à frente da página; Q2).
- **A documentação técnica:** a busca ganhou uma seção (9.7), e a lista das revisões passou a ligar as segundas revisões dos Programas, dos Ajustes do Windows, da Personalização, do Sobre o WinForge e da Busca.
- **Traduções:** 5.770 textos (3 novos e 4 que saíram de uso).

**Conferido na nuvem pelo QA**
- **Uma bateria nova da Busca,** 81 conferências em português, 92 em inglês e 90 em espanhol (nos outros dois, mais uma por seção: nenhuma palavra solta em português na tela; e as do singular de cada idioma): a ordem, a linha de cima, a página por qualquer palavra do título, as buscas sobre o WinForge, o singular, a caixa, o índice e a janela (a ordem, a linha de cima na tela e no leitor de tela, o clique num ajuste).
- **No código de antes (725dd4f):** falham 33 das 81 conferências em português, 36 das 92 em inglês e 36 das 90 em espanhol, cada uma de uma correção; as que passam conferem o que foi mantido e os textos.
- **23 defeitos de propósito,** e as conferências pegam todos.
- **A ordem antes e depois,** em 4.175 buscas nos três idiomas: o primeiro resultado mudou em 18, todas pelo pedido, fora "add remove programs" (em inglês, digitado na janela em português ou em espanhol, que só acha parte das palavras).
- **A bateria antiga adaptada ao que mudou de propósito:** a da Busca (R26), na conferência da linha de cima de um ajuste (a página e o grupo, no lugar de "> ajuste"), com os mesmos 109, 98 e 101.
- **Nada do que funcionava quebrou:**
  - as baterias das 14 páginas revistas, com os mesmos números da R54 (a da Busca da R26 depois da adaptação acima; a da Rede da R22 com a mesma conferência antiga do escudo); a das seis funções novas da R36 (257 em cada idioma); o Início da R13 (241), a Manutenção da R14 (243, 245 e 250), as conferências da R11 e da R12 e as gerais; as da R9 e da R10 com as mesmas falhas antigas;
  - as baterias das segundas revisões: Início (115 em cada idioma), Manutenção (67), Limpeza (97), Desempenho (94), Reparo (92), Diagnóstico (87), Rede (128), Segurança (83, 84 e 84), Atualizações (83, 84 e 84), Programas (75, 87 e 87), Ajustes do Windows (137, 147 e 147), Personalização (93, 99 e 99) e Sobre o WinForge (81, 87 e 87), a do Explorador e da tela de bloqueio da R50 (101) e a conferência da QA do passo da configuração inicial (66 de 66);
  - as mensagens da janela (72 em cada idioma);
  - instalar, atualizar com um clique e o pacote de suporte, como na R54;
  - cada nome e link citado na documentação técnica (327);
  - as traduções: 5.770, 3 textos novos e 4 que saíram de uso;
  - as funções sem referência (nenhuma, entre 1.558) e nenhuma chamada a uma função que não existe;
  - o PSScriptAnalyzer: os mesmos 243 avisos da R54, nenhum novo;
  - o Setup de verdade, da R54 para esta: saída 0, os 58 arquivos trocados pelos do pacote e as notas da pessoa mantidas; o zip muda só em `Navigation.psm1`, na janela (`WinForge.Gui.ps1` e `MainWindow.xaml`), nas traduções, no CHANGELOG e no `SHA256SUMS.txt`.

**Validado pelo MVP Windows**
- **Ctrl+F para achar:** é o atalho da Microsoft para achar numa janela; o WinForge o aceita, com o Ctrl+K, e numa lista com filtro o Ctrl+F vai ao filtro.
- **O Enter:** na caixa, envia a busca; num resultado, o escolhe, como a Microsoft descreve para uma caixa de busca com sugestões. Sem resultado, uma linha diz isso.
- **O atalho na dica,** como a Microsoft orienta, e na propriedade de atalho da Automação da Interface do Usuário (`AcceleratorKey`), como nos botões das páginas.
- **O sinal ">":** no padrão, os leitores de tela o leem; o caminho falado vai com vírgulas.
- **O que só um PC confirma:** o roteiro, §45.

**Fontes**
- Microsoft: [Keyboard accelerators](https://learn.microsoft.com/en-us/windows/uwp/design/input/keyboard-accelerators), [AutomationProperties.AcceleratorKey](https://learn.microsoft.com/en-us/uwp/api/windows.ui.xaml.automation.automationproperties.acceleratorkey?view=winrt-26100) e [Auto-suggest box](https://learn.microsoft.com/en-us/windows/apps/design/controls/auto-suggest-box).
- Eleven Ways: [How screen readers read special characters: an update](https://elevenways.be/en/articles/screenreaders-special-characters).

**Entregue:** `WinForge.zip`, `WinForge-codigo-fonte.zip`, `revisao-busca-2-4.0.md`, `historico-4.0.md` e a prévia da Busca, antes e depois.

---

## R56 — Segunda revisão do Verificar o PC

**Data:** 22/11/2026 · **Commit:** 3595e35

**Pedido:** "Revise a tela/função "Verificar o PC"", com os mesmos cinco olhares da R40 à R55: um Analista de Produto Sênior avalia o todo; um Engenheiro de Software Sênior revisa o código, refatora, tira o que não serve e melhora o desempenho; um Designer Sênior com um Especialista em UX/UI revisam a tela, os botões, os textos e os fluxos; um MVP Windows confere as práticas da Microsoft, se cada função faz o melhor e se é robusta; um QA Sênior testa tudo, o óbvio e o que não é. O engenheiro aplica o que cada um pede.

**O relatório:** `docs/revisao-verificar-o-pc-2-4.0.md`, com os 10 achados, o que foi mantido, os testes e as fontes. A primeira revisão do Verificar o PC (R27) foi antes da pausa na página Atualizações (R48), do reparo do Instalador de Aplicativo na faixa dos Programas (R36 e R51) e do Gerenciar inicialização no Desempenho (R43).

**O que mudou**
- **Produto:** com o Windows Update pausado e as atualizações de segurança atrasadas, a linha diz a pausa e o ponto leva ao Windows Update, para retomar (antes, a Instalar atualizações); pausadas e em dia, a linha só informa (P1). Sem o winget, o ponto pede você e leva ao reparo do Instalador de Aplicativo; antes, uma linha cinza sem caminho, com a faixa em "Tudo certo" (P2).
- **Código:** a consulta do winget começa em segundo plano antes da primeira etapa e corre junto com as outras (E1: na nuvem, com um winget de 3 segundos e uma etapa de 3, a verificação leva 3,2 segundos, contra 6,2 a 6,5); saíram o `-Skip` da varredura, que ninguém usava, a lista das pastas lida duas vezes, a build lida de novo e a orientação do registro que nunca aparecia (E2).
- **Design:** a inicialização cheia leva a Desempenho > Gerenciar inicialização, como a memória alta (D1); sem o winget, a faixa sem dois sinais de dois-pontos, e as listas dizem "Instalador de Aplicativo" (D2).
- **Windows:** a consulta do winget com prazo de 120 segundos; sem resposta, a etapa fica como não lida, a verificação termina e o winget é encerrado, também no Parar (M1).
- **QA:** dois discos com sinal de falha num ponto só, com os nomes (Q1); o firewall ou as ameaças sem leitura não deixam a faixa em "Tudo certo" (Q2); atalhos quebrados no OneDrive aparecem, com onde revisar, no lugar de "nenhum quebrado" (Q3).
- **A documentação técnica:** a seção do Verificar o PC diz a consulta em segundo plano e o prazo, e a lista das revisões liga a segunda do Verificar o PC.
- **Traduções:** 5.783 textos (15 novos e 2 que saíram de uso).

**Conferido na nuvem pelo QA**
- **Uma bateria nova do Verificar o PC,** 163 conferências em português e 166 em inglês e em espanhol (nos outros dois, as dos textos traduzidos e uma que procura palavras soltas em português na tela): cada leitura, a consulta do winget (com um winget falso de verdade no caminho do sistema: os argumentos, as linhas, o código de saída, o UTF-8, o erro padrão, o prazo, a consulta junto com uma etapa lenta e a parada no meio), a verificação inteira em 15 situações, os textos e os caminhos nos três idiomas e o código.
- **No código de antes (0958da4):** falham 74 das 162 conferências em português e 80 das 165 em inglês e em espanhol, cada uma de uma correção; as que passam conferem o que foi mantido e os textos.
- **28 defeitos de propósito,** e as conferências pegam todos.
- **As baterias antigas adaptadas ao que mudou de propósito:** a do Verificar o PC (R27), com a consulta do winget passando pela tarefa em segundo plano (a mesma resposta simulada) e três conferências (os dois discos num ponto só, a inicialização no Desempenho e o texto sem o winget), com 148, 149 e 149 (duas a mais em cada idioma, das faixas com botão); a das seis funções novas da R36, nas duas conferências dos programas marcados no Verificar o PC, que passaram a ler a resposta por `ConvertTo-WinForgeCheckupProgramsFinding`, com os mesmos 257.
- **Nada do que funcionava quebrou:**
  - as baterias das 14 páginas revistas, com os mesmos números da R55 (a do Verificar o PC da R27 depois da adaptação acima; a da Rede da R22 com a mesma conferência antiga do escudo); a das seis funções novas da R36 (257 em cada idioma, depois da adaptação acima); o Início da R13 (241), a Manutenção da R14 (243, 245 e 250), as conferências da R11 e da R12 e as gerais; as da R9 e da R10 com as mesmas falhas antigas;
  - as baterias das segundas revisões: Início (115 em cada idioma), Manutenção (67), Limpeza (97), Desempenho (94), Reparo (92), Diagnóstico (87), Rede (128), Segurança (83, 84 e 84), Atualizações (83, 84 e 84), Programas (75, 87 e 87), Ajustes do Windows (137, 147 e 147), Personalização (93, 99 e 99), Sobre o WinForge (81, 87 e 87) e Busca (81, 92 e 90), a do Explorador e da tela de bloqueio da R50 (101) e a conferência da QA do passo da configuração inicial (66 de 66);
  - as mensagens da janela (72 em cada idioma);
  - instalar, atualizar com um clique e o pacote de suporte, como na R55;
  - cada nome e link citado na documentação técnica (330);
  - as traduções: 5.783, 15 textos novos e 2 que saíram de uso;
  - as funções sem referência (nenhuma, entre 1.560) e nenhuma chamada a uma função que não existe;
  - o PSScriptAnalyzer: 242 avisos, um a menos que na R55 (o do `-Skip` que saiu), nenhum novo;
  - o Setup de verdade, da R55 para esta: saída 0, os 58 arquivos trocados pelos do pacote e as notas da pessoa mantidas; o zip muda só em `Checkup.psm1`, nas traduções, no CHANGELOG e no `SHA256SUMS.txt`.

**Validado pelo MVP Windows**
- **A consulta:** `winget upgrade` sem argumentos só lista, e `--accept-source-agreements` aceita o contrato da fonte sem a pergunta, como na tela Atualizar programas; agora com prazo, e encerrada numa parada.
- **Sem o winget:** a Microsoft indica registrar de novo o Instalador de Aplicativo, o que o Reparar o Instalador de Aplicativo faz; o Windows Sandbox não tem o winget.
- **A pausa:** até 35 dias, adia sem desligar, retoma a qualquer hora ou sozinha no fim; a leitura é a da página Atualizações (R48).
- **O que só um PC confirma:** o roteiro, §46.

**Fontes**
- Microsoft: [Use WinGet to install and manage applications](https://learn.microsoft.com/en-us/windows/package-manager/winget/), [upgrade command (winget)](https://learn.microsoft.com/en-us/windows/package-manager/winget/upgrade) e [Pause updates in Windows](https://support.microsoft.com/windows/manage-updates-in-windows-643e9ea7-3cf6-7da6-a25c-95d4f7f099fe).

**Entregue:** `WinForge.zip`, `WinForge-codigo-fonte.zip`, `revisao-verificar-o-pc-2-4.0.md` e `historico-4.0.md`.

---

## R57 — Segunda revisão do Otimizar

**Data:** 22/11/2026 · **Commit:** be410d8

**Pedido:** "Revise a tela/função "Otimizar"", com os mesmos cinco olhares da R40 à R56: um Analista de Produto Sênior avalia o todo; um Engenheiro de Software Sênior revisa o código, refatora, tira o que não serve e melhora o desempenho; um Designer Sênior com um Especialista em UX/UI revisam as telas, os botões, os textos e os fluxos; um MVP Windows confere as práticas da Microsoft, se cada função faz o melhor e se é robusta; um QA Sênior testa tudo, o óbvio e o que não é. O engenheiro aplica o que cada um pede.

**O relatório:** `docs/revisao-otimizar-2-4.0.md`, com os 11 achados, o que foi mantido, os testes e as fontes. A primeira revisão do Otimizar (R28) foi antes do Gerenciar inicialização no Desempenho (R43), da pausa e da conexão limitada na etapa do Windows Update (R48), da revisão dos ajustes sem a aparência (R49 e R50), do reparo do Instalador de Aplicativo (R51) e da consulta do winget em segundo plano no Verificar o PC (R56).

**O que mudou**
- **Produto:** com a parte automática cancelada, o fim só sugere reiniciar quando algo pede (P1); sem o winget, o começo oferece repará-lo ali mesmo, com Reparar como padrão, e, sem reparar, diz uma vez onde repará-lo depois (P2).
- **Código:** a lista do winget começa em segundo plano logo depois dos programas e corre enquanto a pessoa revisa a inicialização e as pastas (E1: na nuvem, com um winget de 3 segundos e as duas telas levando 3, a pergunta esperou 0,1 segundo, contra 3,3); a consulta, com o prazo, saiu do Verificar o PC para o `Software.psm1` e é a mesma nos dois; o formato das respostas da parte automática num lugar só (E2).
- **Design:** nas perguntas e no fim, o alto da janela diz "Antes da parte automática" e "Para terminar", e não a etapa que já terminou, com a barra cheia até ela (D1); Continuar e Cancelar, Continuar sem o ponto e Cancelar, Agendar e Agora não, no lugar de Sim e Não (D2); a inicialização leva a Desempenho > Gerenciar inicialização, no botão e no histórico (D3).
- **Windows:** numa conexão limitada, a pergunta antes de baixar os programas, os navegadores e a Store, com Deixar para depois como padrão; deixadas para depois, as três etapas ficam de fora dizendo por quê (M1); a lista do winget com prazo de 120 segundos (M2).
- **QA:** o ponto de restauração que falha com um erro também pergunta se continua sem ele (Q1); sem o winget, um aviso só, sem nada em vermelho e sem a pergunta da Microsoft Store no meio do Otimizar (Q2).
- **A documentação técnica:** a seção do Otimizar diz o que vem antes da parte automática (a conexão limitada, a consulta adiantada, o reparo e as partes), e a lista das revisões liga a segunda do Otimizar.
- **Traduções:** 5.794 textos (14 novos e 3 que saíram de uso).

**Conferido na nuvem pelo QA**
- **Uma bateria nova do Otimizar,** 97 conferências em português e 101 em inglês e em espanhol (nos outros dois, uma que procura palavras soltas em português na tela): a consulta do winget (com um winget falso de verdade no caminho do sistema: os argumentos, a lista com a consulta adiantada, o prazo e o winget encerrado, a consulta que falha e a que não responde, o Verificar o PC lendo a mesma), as perguntas (a conexão comum e a limitada, sem o winget, o erro do winget), as etapas (o reparo em cinco situações, as três que baixam numa conexão limitada), o fluxo inteiro (a ordem, o `finally`, o ponto de restauração, o fim depois de cancelar, os rótulos, a inicialização) e a janela (a frase em destaque, a barra, o resumo e o contexto da pergunta, com o WPF simulado da R37).
- **No código de antes (3595e35):** das conferências que rodam nele, falham 53 das 82 em português e 54 das 86 em inglês e em espanhol, cada uma de uma correção; as que passam conferem o que foi mantido e os textos.
- **45 defeitos de propósito,** e as conferências pegam todos.
- **As baterias antigas adaptadas ao que mudou de propósito:** a do Otimizar (R28), com as perguntas simuladas recebendo a consulta adiantada, o winget presente nas perguntas e, nos dois casos em que tudo falha (o ponto também), o sim para seguir sem o ponto, com os mesmos 146, 151 e 151; a da Manutenção (R14), no caso em que tudo falha, com o mesmo sim, com os mesmos 243, 245 e 250; a do Verificar o PC (R27) e a da R56, com a consulta pelo nome novo e o prazo no `Software.psm1`, com os mesmos 148, 149 e 149 e 163, 166 e 166.
- **Nada do que funcionava quebrou:**
  - as baterias das 14 páginas revistas, com os mesmos números da R56 (a do Otimizar da R28 e a do Verificar o PC da R27 depois da adaptação acima; a da Rede da R22 com a mesma conferência antiga do escudo); a das seis funções novas da R36 (257 em cada idioma); o Início da R13 (241), a Manutenção da R14 (243, 245 e 250, depois da adaptação acima), as conferências da R11 e da R12 e as gerais; as da R9 e da R10 com as mesmas falhas antigas;
  - as baterias das segundas revisões: Início (115 em cada idioma), Manutenção (67), Limpeza (97), Desempenho (94), Reparo (92), Diagnóstico (87), Rede (128), Segurança (83, 84 e 84), Atualizações (83, 84 e 84), Programas (75, 87 e 87), Ajustes do Windows (137, 147 e 147), Personalização (93, 99 e 99), Sobre o WinForge (81, 87 e 87), Busca (81, 92 e 90) e Verificar o PC (163, 166 e 166, depois da adaptação acima), a do Explorador e da tela de bloqueio da R50 (101) e a conferência da QA do passo da configuração inicial (66 de 66);
  - as mensagens da janela (72 em cada idioma);
  - instalar, atualizar com um clique e o pacote de suporte, como na R56;
  - cada nome e link citado na documentação técnica (340);
  - as traduções: 5.794, 14 textos novos e 3 que saíram de uso;
  - as funções sem referência (nenhuma, entre 1.565) e nenhuma chamada a uma função que não existe;
  - o PSScriptAnalyzer: os mesmos 242 avisos da R56, nenhum novo;
  - o Setup de verdade, da R56 para esta: saída 0, os 58 arquivos trocados pelos do pacote e as notas da pessoa mantidas; o zip muda em cinco módulos (Checkup, Console, GuiDesign, Maintenance e Software), na janela, nas traduções, no CHANGELOG e no `SHA256SUMS.txt`.

**Validado pelo MVP Windows**
- **A conexão limitada:** o Windows baixa só as atualizações prioritárias e pode pausar os downloads da Microsoft Store; o Otimizar pergunta antes de baixar os programas, os navegadores e a Store, e o Windows Update segue a regra dele (R48).
- **O reparo:** a Microsoft indica registrar de novo o Instalador de Aplicativo quando o winget ainda não aparece, o que o reparo do começo faz, pelo mesmo registro de Programas > Reparar o Instalador de Aplicativo.
- **A consulta:** a mesma `winget upgrade --accept-source-agreements` da tela Atualizar programas e do Verificar o PC, agora com prazo também no Otimizar.
- **O que só um PC confirma:** o roteiro, §47.

**Fontes**
- Microsoft: [Metered connections in Windows](https://support.microsoft.com/en-us/windows/metered-connections-in-windows-7b33928f-a144-b265-97b6-f2e95a87c408) e [Use WinGet to install and manage applications](https://learn.microsoft.com/en-us/windows/package-manager/winget/).

**Entregue:** `WinForge.zip`, `WinForge-codigo-fonte.zip`, `revisao-otimizar-2-4.0.md` e `historico-4.0.md`.

---

## R58 — A documentação técnica e o README

**Data:** 22/11/2026 · **Commit:** b46d1fc

**Pedido:** "Um Analista de Produto Sênior deve criar/refatorar a documentação técnica do sistema, bem como um README com boas práticas para o GitHub. Criar readme/página do projeto em diferentes línguas."

**De onde partiu:** a documentação técnica foi escrita na R30 e acompanhou o código a cada revisão, mas cresceu por camadas: o cabeçalho ainda dizia "depois da R29", alguns números tinham ficado para trás, parágrafos inteiros juntavam o estado de nove páginas, e quem chegava não tinha por onde começar. O README era o da R31, com as seções de antes das segundas revisões. Nenhuma linha do código do WinForge mudou nesta revisão.

**O que mudou**
- **A documentação técnica** (`docs/documentacao-tecnica-4.0.md`), refeita sobre o código de agora (depois da R57):
  - **Comece por aqui** (seção 5, nova): rodar a partir do código, o caminho de um clique, onde fica cada coisa ("para mudar isto, olhe ali") e o que conferir antes de mandar uma mudança;
  - **diagramas em Mermaid,** que o GitHub desenha, no lugar dos desenhos em texto: a visão geral da arquitetura, o caminho de um clique e a atualização com um clique;
  - **as decisões de arquitetura** (seção 7.4: por que PowerShell 5.1, o runspace, a tabela única, o texto em português como chave, o estado em arquivos, os prazos e nada elevado sozinho) e **as marcas da saída** (seção 9: o que cada marca vira no resumo da janela, um contrato que não estava escrito);
  - **os parágrafos longos em tabelas e listas:** a faixa de resumo de cada página e a chave de um ajuste na janela;
  - **a página do repositório no GitHub** (seção 22.1): os READMEs nos três idiomas, os links, o alerta, os diagramas, e a descrição e os tópicos do About, que ficam fora dos arquivos;
  - **os números de agora:** 120 arquivos no git, 1.338 funções nos módulos (Checkup 22, Console 47, Maintenance 41, Software 86), 7.975 linhas na janela, 5.794 textos; os documentos relacionados e as revisões de cada tela em tabelas.
- **O índice da documentação** (`docs/README.md`, novo), que o GitHub mostra ao abrir a pasta: por onde começar, as decisões de produto e de desenho e as revisões de cada tela.
- **Os READMEs** em português, inglês e espanhol, com o que o GitHub pede de um README (o que o projeto faz, por que é útil, como começar, onde pedir ajuda e quem o mantém): por que o WinForge; começar, com os dois botões do Início; o que ele faz, nos quatro grupos da barra lateral; requisitos; o aviso dos scripts sem assinatura num alerta, com o SHA-256; perguntas frequentes (velocidade, antivírus, como voltar atrás, sem internet, Administrador); a documentação para quem desenvolve; quem mantém. As mesmas onze seções, na mesma ordem, com os nomes das telas iguais aos das traduções.
- **O CHANGELOG:** a linha do README e a da documentação técnica, com o índice novo.

**Conferido na nuvem**
- **Os links:** cada link interno da documentação técnica, do índice e dos READMEs leva a um título que existe, com as âncoras calculadas como o GitHub calcula, e cada arquivo citado existe; os nomes de função e os caminhos da documentação técnica, conferidos no código (380; os 3 de sempre são exemplos de nome, como `Verbo-WinForgeNome`).
- **Os diagramas:** os três desenhados pelo Mermaid sem erro e conferidos na imagem (um ponto e vírgula, que o Mermaid lê como fim de linha, saiu de um deles).
- **Os READMEs:** a conferência da R31 (77): cada caminho de tela existe na navegação do idioma, os nomes do Windows ("Configurações > Aplicativos", "Settings > Apps", "Configuración > Aplicaciones"), as âncoras, os arquivos, os textos alternativos, os códigos de saída, o formato (UTF-8 sem BOM e CRLF) e os três com a mesma forma e os mesmos endereços; o README em português desenhado como página e conferido na imagem; nenhuma menção a testes; as conferências do QA geral sobre o README e o CHANGELOG (as da R11 e a de dados, com a mesma falha antiga).
- **Os números** contados no código: 12 páginas, 106 itens (88 ações e 18 atalhos do Windows), 38 com Administrador, 11 destaques, 53 ajustes em 10 categorias, 5 perfis, 11 etapas no Verificar o PC, 20 no Otimizar e 11 conferências no monitor.
- **O pacote:** os 58 arquivos; mudam só os três READMEs, o CHANGELOG e o `SHA256SUMS.txt`. O Setup de verdade, da R57 para esta: saída 0, os arquivos trocados pelos do pacote e as notas da pessoa mantidas.

**O que só um PC e o GitHub mostram:** o roteiro, §48.

**Fontes**
- GitHub: [About the repository README file](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-readmes), [Basic writing and formatting syntax](https://docs.github.com/en/get-started/writing-on-github/getting-started-with-writing-and-formatting-on-github/basic-writing-and-formatting-syntax), [Creating diagrams](https://docs.github.com/en/get-started/writing-on-github/working-with-advanced-formatting/creating-diagrams) e [Classifying your repository with topics](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/classifying-your-repository-with-topics).

**Entregue:** `WinForge.zip`, `WinForge-codigo-fonte.zip`, `documentacao-tecnica-4.0.md`, os três READMEs e `historico-4.0.md`.

---

## R59 — O site do WinForge no README e no programa

**Data:** 22/11/2026 · **Commit:** 2ef915f

**Pedido:** "Avalue, tanto nos arquivos do projeto quanto no todo, quando vê até no sistema (avaliar), onde podemos inserir o site (landingPage) do projeto: USEWINFORGE.COM.BR" e, depois da avaliação, "Pode fazer desta forma então, dando referencia ao site do winforge".

**De onde partiu:** o site (usewinforge.com.br) é do dono, que o publica por fora. A avaliação (no projeto WinForge do Claude, `claude/site-onde-inserir.md`) achou três lugares que ajudam sem pesar nenhuma tela: a linha de links do alto do README, um item em Sobre o WinForge e a entrada em Aplicativos instalados, que levava ao repositório duas vezes. O download e a atualização ficam no GitHub, de onde o WinForge confere o SHA-256.

**O que mudou**
- **Sobre o WinForge > Site do WinForge** (em Versão e dados, depois do Pacote de suporte): abre o site no navegador, na página do idioma da janela: o português na raiz, o inglês em `/en/` e o espanhol em `/es/` (`Get-WinForgeWebsiteUrl`, no AppUpdate.psm1, ao lado do endereço do repositório). É um atalho (`Website`, no Shortcuts.psm1), com o globo e o ↗, e abre pelo explorer.exe, como as páginas dos fabricantes: com a janela como Administrador, o navegador abre sem a elevação. A busca o acha por "site", "website", "sitio web" e "usewinforge".
- **A dica e o leitor de tela** dizem "Abre no navegador" no site e "Abre no Windows" nos outros atalhos (`Get-GuiOutsideNote`, no lugar do mesmo texto repetido em sete lugares da janela). Se o navegador não abre, a mensagem dá o endereço para digitar, e não "o recurso pode não existir nesta edição do Windows".
- **A entrada em Aplicativos instalados** (`Get-WinForgeInstallLinks`, no Install.psm1): o site em `URLInfoAbout` (pela raiz: a entrada é do PC, e não de um idioma), as issues do GitHub em `HelpLink` e, novo, a página de versões em `URLUpdateInfo`. Antes, os dois primeiros levavam ao repositório. A atualização com um clique grava de novo os três (`Update-WinForgeInstallVersion`): uma instalação feita por uma versão anterior passa aos de agora.
- **Os READMEs:** "Site", "Website" e "Sitio web" no começo da linha do download, cada um na página do idioma do README.
- **Os documentos:** a documentação técnica (os itens e os atalhos, a entrada em Aplicativos instalados, o que vai para a internet, o campo Website do About do GitHub e os números), o mapa de funcionalidades (que ainda contava 11 páginas, sem a Personalização) e o CHANGELOG.

**Conferido na nuvem**
- **Uma bateria nova,** 52 conferências em inglês e em espanhol e 47 em português (as cinco dos textos traduzidos só valem nos outros dois): o endereço em cada idioma; o item (o grupo, a ordem, a frase de até 60, o globo, a busca e a conta de 107 itens e 19 atalhos); a abertura pelo explorer.exe, com o endereço entre aspas, na janela e no menu de texto, e a falha com o motivo; a dica nos três casos; os três endereços ao instalar (os 13 valores da entrada, na mesma ordem) e ao atualizar (só a versão, os endereços e o tamanho mudam), sem mexer na entrada de outra pasta e sem erro quando o registro recusa.
- **No código de antes (b46d1fc):** a bateria acusa a falta do endereço, do item e do atalho.
- **20 defeitos de propósito** (o idioma errado, o navegador aberto direto, o endereço sem aspas, o item fora do lugar, a dica antiga, a entrada sem um endereço, a atualização que não os grava, entre outros), e a bateria pega todos.
- **A bateria antiga do Sobre o WinForge (R25) adaptada ao item novo:** a lista dos itens e a ordem da página passam a ter o Site do WinForge; com as conferências de cada item, 166, 171 e 171 (eram 164, 169 e 169).
- **Nada do que funcionava quebrou:**
  - as baterias das outras 13 páginas revistas, com os mesmos números da R57 (a da Rede da R22 com a mesma conferência antiga do escudo); a das seis funções novas da R36 (257 em cada idioma); o Início da R13 (241), a Manutenção da R14 (243, 245 e 250), as conferências da R11 e da R12 e as gerais (a de dados com a mesma falha antiga, agora com 107 itens); as da R9 e da R10 com as mesmas falhas antigas;
  - as baterias das segundas revisões, com os mesmos números da R57: Início (115 em cada idioma), Manutenção (67), Limpeza (97), Desempenho (94), Reparo (92), Diagnóstico (87), Rede (128), Segurança (83, 84 e 84), Atualizações (83, 84 e 84), Programas (75, 87 e 87), Ajustes do Windows (137, 147 e 147), Personalização (93, 99 e 99), Sobre o WinForge (81, 87 e 87), Busca (81, 92 e 90), Verificar o PC (163, 166 e 166) e Otimizar (97, 101 e 101), a do Explorador e da tela de bloqueio da R50 (101) e a da QA do passo da configuração inicial (66 de 66);
  - as mensagens da janela (72 em cada idioma);
  - instalar, atualizar com um clique e o pacote de suporte, como na R58;
  - a busca acha cada um dos 107 itens pelo próprio nome, nos três idiomas, e as 166 referências "Página > Item" levam a um item que existe;
  - as funções sem referência (nenhuma, entre 1.568) e nenhuma chamada a uma função que não existe;
  - o PSScriptAnalyzer com os mesmos 242 avisos de antes, nenhum no código novo.
- **Os READMEs:** a conferência da R31, agora com o site na página do idioma de cada um (80).
- **A documentação técnica:** cada nome e link citado (383; os 3 de sempre são exemplos de nome) e os três diagramas, desenhados sem erro.
- **Os números** contados no código: 12 páginas, 107 itens (88 ações e 19 atalhos), 38 com Administrador, 11 destaques, 1.340 funções nos módulos e 202 na janela, 5.798 textos (5 novos e 1 que saiu de uso).
- **O pacote:** os 58 arquivos; mudam cinco módulos (AppUpdate, GuiDesign, Install, Navigation e Shortcuts), a janela, as traduções, os três READMEs, o CHANGELOG e o `SHA256SUMS.txt`. O Setup de verdade, da R58 para esta: saída 0, os arquivos trocados pelos do pacote e as notas da pessoa mantidas.

**O que só um PC mostra:** o roteiro, §49. E o site no ar, com as páginas `/en/` e `/es/`, antes de publicar.

**Fontes**
- Microsoft: [Uninstall Registry Key](https://learn.microsoft.com/en-ca/Windows/win32/msi/uninstall-registry-key) (os valores `URLInfoAbout`, `HelpLink` e `URLUpdateInfo`) e [Configuring Add/Remove Programs with Windows Installer](https://learn.microsoft.com/cs-cz/windows/win32/msi/configuring-add-remove-programs-with-windows-installer) (o que cada um é: a página do programa, o suporte e as informações de atualização).

**Entregue:** `WinForge.zip`, `WinForge-codigo-fonte.zip`, os três READMEs, `documentacao-tecnica-4.0.md` e `historico-4.0.md`.

---

## R60 — A cor de destaque e o que sobrou na inicialização

**Data:** 22/11/2026 · **Commit:** o desta entrada

**Pedido:** "Preciso de 2 correções/melhorias, implementadas da melhor forma possível, segura, por um Engenheiro de Software Sênior, com validação do QA Sênior, Especialista Windows MVP e Designer Sênior. 1. Erro ao alterar a cor de destaque, em diferentes dispositivos (se for para fazer gambiarra ou não funcionar perfeito, pode capar fora. Evidencia anexada. 2. Teoricamente eu desinstalei a FACEIT, tanto que o próprio WinForge não retorna nada dela para excluir. Porém, tanto no Windows quanto no WinForge, ainda aparece o update dela como candidato a inicializar junto do Windows. Tem como remover estes tipos de cenário de forma segura, pelo WinForge?"

**De onde partiu**
- **A cor de destaque:** o print mostra "Cannot convert value "4285753168" to type "System.Int32"". O REG_DWORD são 32 bits sem sinal, e o provedor do registro do PowerShell devolve acima de 2.147.483.647 um UInt32. As cores do Windows guardam o alfa em FF, e toda cor passa disso: o `[int]` da leitura da cor de agora (e dos valores de antes, para o desfazer) quebrava em qualquer PC, antes de gravar qualquer coisa. Corrigir a leitura era simples; o resto não. O Windows não tem um jeito documentado de um programa trocar a cor de destaque: a troca grava valores que não são documentados (`AccentColorMenu`, `AccentPalette`, os do DWM), e a paleta de tons o WinForge calculava por conta própria (o Windows tem a dele). Numa discussão da Microsoft Q&A sobre isso, a troca pelo registro pede o Explorador reiniciado num PC e não em outro, e um MVP conta que a cor voltava à de antes. Pelo critério do pedido (ou funciona perfeito, ou sai), a troca saiu.
- **A inicialização:** o FACEIT usa o Squirrel, o instalador de muitos programas feitos em Electron (o desinstalador dele é o `Update.exe` da pasta do programa). A entrada que esses programas põem na inicialização abre "Update.exe --processStart Programa.exe"; ao desinstalar, o Squirrel apaga as pastas `app-<versão>` e deixa o `Update.exe`, e a entrada fica. Para o Windows e para o WinForge ela parecia boa (o `Update.exe` existe), mas não abre nada. E o que aponta para um arquivo apagado o WinForge só tirava da lista de ligar e desligar, sem oferecer tirar o item: ele continuava no Gerenciador de Tarefas.

**O que mudou**
- **A cor de destaque** (Personalização > Cores e transparência): a linha abre as Cores das Configurações do Windows (`ms-settings:colors`), com o ↗, como a Tela de bloqueio do Windows. Saem a troca (`Set-WinForgeAccentColor` e as funções da cor), as amostras da linha, os estilos delas e o desfazer `accent-color`. A busca "cor de destaque" abre as Cores direto. O desfazer das teclas do idioma continua, só com os valores de texto.
- **O Histórico só oferece o desfazer que existe:** uma troca da cor anotada nas versões de teste desta 4.0 fica entre as mudanças sem desfazer, em vez de mostrar um desfazer que só falharia. `Test-WinForgeChangeUndoable` confere o tipo contra os que o `Undo-WinForgeChange` sabe desfazer (`$script:WinForgeUndoKinds`, um para cada caso dele); vale também para uma anotação de versão mais nova.
- **O REG_DWORD sem sinal**, a causa do erro, que podia aparecer em outros lugares: `ConvertTo-WinForgeRegistryDWord` leva o número ao Int32 com os mesmos 32 bits (4.285.753.168 vira -9.214.128, e o Windows grava os mesmos 4 bytes), e `Set-WinForgeRegistryDWord`, `Set-WinForgeRegistryValue` e o desfazer dos ajustes passam por ele; o QWORD, por `ConvertTo-WinForgeRegistryQWord`. Comparar um valor capturado com o do catálogo usa a mesma conta. A regra ficou na seção 20 da documentação técnica.
- **Remover o que sobrou** (Gerenciar inicialização, em Desempenho e em Programas):
  - **o que é sobra** (`Get-WinForgeStartupLeftoverReason`): o arquivo que o item abre não existe mais num disco fixo (a regra que já tirava o item da lista), ou o `Update.exe` do Squirrel sem o programa nas pastas `app-*`, na `current` nem como lançador na própria pasta (`Test-WinForgeStartupLauncherOrphan`). Na dúvida (outro comando, um pendrive, uma pasta que não dá para ler), não é. Numa chave de todos os usuários, um comando com uma pasta da conta (`%LOCALAPPDATA%`...) nunca é: o WinForge só vê a pasta da própria conta;
  - **a tela:** o resumo diz "Restos de programas desinstalados: N"; a escolha ganha **Remover o que sobrou**, em destaque ("1 item de um programa que não está mais no PC"); a lista vem marcada, com o que falta em cada item ("só sobrou o Update.exe; o programa foi desinstalado", "velho.exe não existe mais") e o botão **Remover**. Sem Administrador e elevado com outra conta, valem as regras da lista de desativar;
  - **tirar** (`Remove-WinForgeStartupLeftover`): o valor sai de uma das três chaves Run que a lista lê, só se ainda for o mesmo comando e o programa continuar fora do PC (reinstalado no meio, fica); o atalho da pasta Inicializar vai para a Lixeira, só da pasta de onde veio; a marca em StartupApproved sai junto, para o Gerenciador de Tarefas e as Configurações não mostrarem mais nada. O `Update.exe` fica onde está;
  - **o Histórico** anota o que saiu, sem desfazer: o item não abria nada, e um desfazer que gravasse de volta numa chave Run de todos os usuários o comando lido do diário (que qualquer programa da conta altera) seria um jeito de fazer algo abrir na sessão de outra pessoa do PC;
  - o `Update.exe` que sobrou deixa de contar como algo que abre com o Windows (a lista de desativar, o Verificar o PC e o Otimizar).
- **Os textos e os documentos:** 26 textos novos e 38 que saíram; a documentação técnica (a cor nas seções 10, 14 e 15, a regra do REG_DWORD na 20, a sobra na 23 e os números), o mapa de funcionalidades, o CHANGELOG e o roteiro (§50; os itens da troca da cor saíram dos §18 e §43).

**Conferido na nuvem**
- **Uma bateria nova,** num Windows simulado (o registro, os arquivos, os atalhos, os discos, a Lixeira, o Administrador e as perguntas): 79 conferências em português e 86 em inglês e em espanhol. Cobre o número do print (4.285.753.168) lido e gravado como DWORD, o QWORD, o desfazer dos ajustes e a comparação com o catálogo; a linha da cor como atalho, a abertura das Cores, a busca e o que saiu da janela; o desfazer das teclas do idioma, a anotação antiga da cor recusada e fora da lista de desfazer, e a lista de tipos igual aos casos do `Undo-WinForgeChange`; o FACEIT, o Discord instalado (pastas `app-*` e `current`), o lançador na própria pasta, outro exe com `--processStart`, o pendrive, a pasta da conta numa chave de todos os usuários e o atalho quebrado; tirar com o comando mudado, com o programa reinstalado, sem Administrador, com uma chave de fora da lista e com um atalho de fora da pasta Inicializar; a marca StartupApproved, a Lixeira, o Histórico e a tela (a escolha em destaque, a lista marcada, o botão Remover e a faixa).
- **No código de antes (2ef915f):** a bateria acusa o erro do print (o `[int]` na gravação, no desfazer dos ajustes e na comparação), a linha que não é atalho e o atalho que não existe.
- **23 defeitos de propósito** (a conta dos 32 bits tirada, o `[int]` de volta em cada lugar, a linha de volta como ação, o atalho para outra página, o Squirrel sem olhar as pastas, qualquer exe contando, tirar sem conferir o comando, o programa ou o Administrador, a marca StartupApproved esquecida, um desfazer inventado no Histórico, a lista desmarcada, o Histórico oferecendo desfazer qualquer tipo, a lista de tipos sem um caso, entre outros), e a bateria pega todos.
- **As baterias antigas adaptadas ao que mudou de propósito:**
  - a da Personalização (R24) e a segunda revisão dela (R53): as conferências da troca da cor (as oito cores, a paleta, o desfazer da cor e as amostras) deram lugar às da linha como atalho; ficam 211, 216 e 216 (eram 265, 270 e 270) e 47, 53 e 53 (eram 93, 99 e 99);
  - a segunda revisão do Sobre o WinForge (R54), que conferia o teclado nas amostras da cor, e a da Busca (R55), em que a Cor de destaque agora é o próprio atalho: os mesmos números da R59 (81, 87 e 87; 81, 92 e 90);
  - as duas do Desempenho (R18 e R43): a simulação da lista de inicialização passou a separar as sobras, e a conta das listas de marcar com o verbo no botão é 4 (a nova é a das sobras, com **Remover**); os mesmos números da R59 (96, 102 e 102; 94 em cada idioma);
  - a do site (R59): 20 atalhos, em vez de 19.
- **Nada do que funcionava quebrou:**
  - as baterias das outras 12 páginas revistas, com os mesmos números da R59 (a da Rede da R22 com a mesma conferência antiga do escudo); a das seis funções novas da R36 (257 em cada idioma); as gerais, com as mesmas falhas antigas;
  - as segundas revisões, com os mesmos números da R59: Início (115 em cada idioma), Manutenção (67), Limpeza (97), Desempenho (94), Reparo (92), Diagnóstico (87), Rede (128), Segurança (83, 84 e 84), Atualizações (83, 84 e 84), Programas (75, 87 e 87), Ajustes do Windows (137, 147 e 147), Verificar o PC (163, 166 e 166) e Otimizar (97, 101 e 101); e as correções da R41 (66);
  - as mensagens da janela (72 em cada idioma);
  - instalar, atualizar com um clique e o pacote de suporte, como na R59;
  - a busca acha cada um dos 107 itens pelo próprio nome, nos três idiomas, e as 166 referências "Página > Item" levam a um item que existe;
  - as funções sem referência (nenhuma, entre 1.568) e nenhuma chamada a uma função que não existe;
  - o PSScriptAnalyzer com 240 avisos (eram 242: os dois a menos estavam no código da cor), nenhum no código novo.
- **Os READMEs:** a conferência da R31 (80), sem mudança.
- **A documentação técnica:** cada nome e link citado (385; os 3 de sempre são exemplos de nome).
- **Os números** contados no código: 12 páginas, 107 itens (87 ações e 20 atalhos), 38 com Administrador, 1.343 funções nos módulos e 199 na janela (7.844 linhas), 5.786 textos (26 novos e 38 que saíram de uso).
- **O pacote:** os 58 arquivos; mudam sete módulos (Core, Diagnostics, Journal, Navigation, Shortcuts, Startup e Tweaks), a janela e o `MainWindow.xaml`, as traduções, o CHANGELOG e o `SHA256SUMS.txt`. O Setup de verdade, da R59 para esta: saída 0, os arquivos trocados pelos do pacote e as notas da pessoa mantidas.

**O que só um PC mostra:** o roteiro, §50.

**Fontes**
- Microsoft Q&A: [Change Accent Color for Taskbar on Windows 11 via Registry](https://learn.microsoft.com/en-us/answers/questions/2045412/change-accent-color-for-taskbar-on-windows-11-via) (nenhum jeito documentado; a troca pelo registro pede o Explorador num PC e não em outro, e a cor volta à de antes no de um MVP).
- Microsoft Learn: [Launch the Windows Settings app](https://learn.microsoft.com/en-us/windows/apps/develop/launch/launch-settings) (`ms-settings:colors`).
- O Squirrel: [What is Squirrel in the Windows application management world?](https://www.advancedinstaller.com/what-is-squirrel-framework.html) (as pastas `app-<versão>` e o `Update.exe` de cada programa) e a documentação antiga do Electron sobre abrir com o Windows ([espelho do commit d9a9d5b](https://ayakael.net/mirrors/electron/commit/d9a9d5b8fe30ee0a9539d9e546f6d51c62c957b8): o `Update.exe` com `--processStart "Programa.exe"`).
- O FACEIT: [Advanced Uninstaller](https://www.advanceduninstaller.com/FACEIT-28941a2cb8f8f1646cc6f8a6a57db352-application.htm) (a pasta `%LOCALAPPDATA%\FACEIT` e o `Update.exe` como desinstalador).

**Entregue:** `WinForge.zip`, `WinForge-codigo-fonte.zip`, `documentacao-tecnica-4.0.md`, `funcionalidades-4.0.md`, `CHANGELOG.md` e `historico-4.0.md`.

---

## O que falta para terminar a 4.0
- A conferência num PC, pelo roteiro `claude/roteiro-conferencia-4.0.md`, agora com a janela nova, as seis funções novas (§28), o desenho novo (§29), o Início e os destaques no Windows de verdade (§30), a segunda revisão do Início (§31), a da Manutenção (§32), a da Limpeza (§33), a do Desempenho (§34), a do Reparo (§35), a do Diagnóstico (§36), a da Rede (§37), a da Segurança (§38), a das Atualizações (§39), a aparência fora da revisão do Otimizar (§40) e a segunda revisão dos Programas (§41), a dos Ajustes do Windows (§42), a da Personalização (§43), a do Sobre o WinForge (§44), a da Busca (§45), a do Verificar o PC (§46) e a do Otimizar (§47), a página do projeto no GitHub (§48), o site do WinForge (§49) e a cor de destaque e o que sobrou na inicialização (§50).
- As decisões do dono: I1 (licença) e I2 (certificado).
- O site no ar antes de publicar, com as páginas `/en/` e `/es/`: o Site do WinForge e os READMEs em inglês e em espanhol levam a elas. E o campo Website do About do GitHub (seção 22.1 da documentação técnica).
- As sugestões recomendadas da avaliação (R35) que o dono escolher para a 4.0: N1 a N4 (`docs/avaliacao-4.0.md`). N5 a N10 foram feitas na R36.
- Publicar: assinar, se houver o certificado (`tools\Sign-WinForge.ps1`); montar o zip com `tools\New-WinForgePackage.ps1`; pôr o SHA-256 que ela mostra na página da versão.
- F3 + F8, se a medição num PC confirmar.
- Da revisão da interface, só o que ficou para depois: as capturas de tela, a Mica e a arquitetura de páginas.
- Da revisão de UX/UI (R38), o que o dono escolher (`docs/revisao-ux-4.0.md`): a fase 1 cabe na 4.0. A UX11 (a faixa da Manutenção) entrou na R41; a UX21 (o verbo nos botões), nas perguntas da Limpeza (R42), do Desempenho (R43), do Reparo (R44), do Diagnóstico (R45), da Rede (R46), da Segurança (R47), das Atualizações (R48), dos Programas (R51) e dos Ajustes do Windows (R52); a UX28 (Gerenciar inicialização com uma frase só), na R43; a UX14 (o resumo no lugar do parágrafo), a UX16 (os esqueletos) e a UX19 (a chave na própria linha), em Ajustes e na Personalização, na R52; a UX19 para a cor de destaque, a UX13 (o texto das linhas de ação no mesmo lugar) e a UX15 (as frases de até 60 letras), nas duas páginas de ajustes, na R53; a UX18 (o subtítulo do Sobre o WinForge), a UX25 ("Avisos pausados" traduzido) e a UX21 nas perguntas do Sobre o WinForge, na R54; a UX26 (a ordem da busca, sem o desconto do Avançado, que não mudaria nada) e a UX27 (a linha de cima dos ajustes), na R55; a UX21 nas perguntas do próprio Otimizar, na R57.
