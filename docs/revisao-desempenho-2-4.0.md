# WinForge 4.0 — segunda revisão do Desempenho (R43)

**Data:** 21/11/2026 · **Versão:** Build 4.0 em preparação, depois da R42

**Pedido:** revisar a tela e a função Desempenho com cinco olhares:
- **Analista de Produto Sênior:** avalia o todo.
- **Engenheiro de Software Sênior:** revisa o código, refatora, segue as boas práticas, tira o que não serve e melhora o desempenho.
- **Designer Sênior, com um Especialista em UX/UI:** revisam a tela, os botões, os textos e os fluxos; o engenheiro aplica.
- **MVP Windows:** confere se o Desempenho segue as práticas da Microsoft, se cada função faz da melhor forma o que promete e se é robusto e estável.
- **QA Sênior:** testa tudo o que dá para testar, o óbvio e o que não é; o engenheiro aplica.

**De onde partiu:** a primeira revisão do Desempenho (R18) foi antes do desenho novo (R37) e da revisão de UX (R38). Esta olhou a página inteira de hoje, os caminhos que levam a ela (a Verificação do PC, o menu do monitor, a etapa do Otimizar e a página Programas) e as faixas de cada ação.

**Resultado:** 9 achados, todos corrigidos.

| Olhar | Achados |
|---|---|
| Produto | 2: a faixa do alto dizia o que fazer, mas não levava a lugar nenhum, com a memória alta e com o PC ligado há uma semana |
| Engenharia | 2: o Acelerar agora decidia em dois lugares o que dizer dos temporários; e a lista de Gerenciar inicialização era montada em dois lugares |
| Designer e UX/UI | 3: os botões Sim e Não nas perguntas que fecham programas e mudam a inicialização; os atalhos da pasta Inicializar com ".lnk" no nome; e Gerenciar inicialização com duas frases, em Desempenho e em Programas |
| MVP Windows | nenhum: o que a página faz e aconselha é o que a Microsoft orienta |
| QA | 2: o Acelerar agora dizia "nenhum temporário para apagar" quando os temporários estavam em uso; e dois programas com o mesmo nome (Python e Python) viravam gêmeos na lista e na pergunta |

Nada rodou num Windows de verdade. A conferência foi feita na nuvem: a página com as funções de verdade da janela sobre o WPF simulado, e as ações com o Windows simulado (a memória, os processos, o Agendador de Tarefas, o registro) e, no Acelerar agora, a limpeza de verdade de uma pasta Temp com arquivos em uso. O que só um PC mostra entrou no roteiro de conferência (§34).

## O Desempenho hoje

De cima para baixo:
1. **Memória em uso e Ligado há:** a faixa do alto. Com a memória a partir de 85% ou o PC ligado há uma semana ou mais, a linha fica em amarelo e é um botão com a seta (novo).
2. **Acelerar agora,** em destaque, com "Acelerar": libera memória e apaga os temporários do usuário, sem pergunta.
3. **Deixar o PC mais leve:** Programas pesando agora e Liberar memória.
4. **Para o PC continuar leve:** Gerenciar inicialização e o Gerenciador de Tarefas (do Windows).

## Analista de Produto

| # | O que estava | Por que importa | Como ficou |
|---|---|---|---|
| P1 | Com a memória a partir de 85%, a faixa dizia "14,2 GB de 16 GB (89%) · alta; veja Programas pesando agora". A frase mandava a pessoa procurar o item na lista. | O que resolve a memória alta é fechar o que pesa, e é para lá que a Verificação do PC já leva. A Manutenção (R41) e a Limpeza (R42) têm a mesma faixa, e nelas a linha que pede atenção é um botão. | A linha diz "14,2 GB de 16 GB (89%) · alta", em amarelo, e é um botão com a seta que abre Programas pesando agora. Com a memória normal, a linha continua como era, sem botão. |
| P2 | Com o PC ligado há 7 dias ou mais, a faixa dizia "9 dias e 3 horas · reiniciar deixa o Windows mais leve", sem botão. | Quem desliga o PC toda noite lê "9 dias" e acha que é erro. Não é: com a Inicialização Rápida, desligar não zera esse tempo; só reiniciar zera. A tela Tempo ligado e energia (Diagnóstico) explica isso e diz se a Inicialização Rápida está ligada. | A linha fica com a mesma frase, em amarelo, e é um botão que abre Tempo ligado e energia. Com menos de 7 dias, sem botão. |

**Conferido e mantido:**
- **Acelerar agora em destaque,** sem pergunta, com "o efeito é passageiro" na descrição. Com a memória ainda alta depois dele, a faixa já leva a Programas pesando agora (R18).
- **Liberar memória separado do Acelerar agora:** é o mesmo esvaziamento, sem mexer em arquivo nenhum.
- **Os limites:** memória alta a partir de 85% (a mesma regra da Verificação do PC e da lista do que pesa) e o PC ligado há 7 dias.
- **O Gerenciador de Tarefas** como atalho do Windows, com os gráficos na aba Desempenho.

## Engenheiro de Software

| # | O que estava | Como ficou |
|---|---|---|
| E1 | O Acelerar agora decidia em dois lugares o que dizer dos temporários: o resumo (`Invoke-WinForgeBoost`) e a faixa (`Set-WinForgeBoostView`), cada um com as suas contas sobre o resultado e os bytes. O Q1 nasceu daí: nenhum dos dois via o caso "tudo em uso". | `Get-WinForgeBoostTempState` (nova) responde numa palavra: apagou (Done), nada a apagar (None), em uso (InUse) ou não pôde (Failed). O resumo, a linha "Temporários apagados" e a faixa usam a mesma resposta. O comentário de `Invoke-WinForgeFolderCleanup` diz o que a ressalva dela quer dizer: havia o que limpar, mas tudo estava em uso. |
| E2 | A lista de marcar de Gerenciar inicialização era montada em dois lugares, a de um lado (desativar ou reativar) e a revisão do Otimizar, com o mesmo laço. O nome da tela (D2) teria de entrar nos dois. | `New-WinForgeStartupChoices` (nova) monta as opções das duas, com o nome da tela, a descrição e o conselho. A lista dos processos protegidos também perdeu um nome repetido ("LsaIso" e "lsaiso"). |

**Por dentro:**
- **Performance.psm1:**
  - `Get-WinForgePerformancePageStatus` devolve `Opens` e monta cada linha uma vez;
  - `Get-WinForgeBoostTempState` (nova), usada pelo resumo e pela faixa do Acelerar agora;
  - `Add-WinForgeProcessDetails` separa os nomes amigáveis repetidos;
  - os verbos nas perguntas e na lista de Programas pesando agora.
- **Startup.psm1:**
  - `Get-WinForgeStartupDisplayName` e `New-WinForgeStartupChoices` (novas);
  - o nome da tela nas listas, nas mensagens, na faixa e no Histórico de mudanças; o desfazer continua guardando o nome do arquivo, que é o que o Windows usa;
  - os verbos nas listas e na pergunta da revisão.
- **Navigation.psm1:** Gerenciar inicialização com as mesmas frases e palavras em Desempenho e em Programas.
- **Cleanup.psm1 e WinForge.Gui.ps1:** só comentários.
- **Traduções:** 5.570 textos (8 novos e 5 que saíram de uso).

## Designer e Especialista em UX/UI

| # | O que estava | Orientação | Como ficou |
|---|---|---|---|
| D1 | As perguntas que fecham programas e mudam a inicialização tinham os botões Sim e Não, e as listas de marcar, "Confirmar". Na lista de desativar ou reativar o que abre com o Windows, o botão da lista é a única confirmação: depois dele, a mudança acontece. É a UX21 da revisão de UX, aplicada nesta página. | Os botões dizem o que fazem, como a Microsoft orienta ("Use specific responses to the main instruction or content as button text"). | Programas pesando agora: a lista com "Fechar (2)", a pergunta com "Fechar" e "Cancelar", e a de encerrar à força com "Encerrar à força" em vermelho e "Não encerrar". Gerenciar inicialização: a lista com "Desativar (2)" ou "Reativar (1)". A revisão do Otimizar: "Aplicar" e "Deixar como está" (o Não deixa tudo como está, sozinha ou dentro do Otimizar). O padrão de cada pergunta não mudou, e o menu de texto continua com S/N. |
| D2 | Os atalhos da pasta Inicializar apareciam com a extensão: "Zoom.lnk" na lista, "Zoom.lnk: desativado.", a faixa "Zoom.lnk desativado" e a mesma linha no Histórico de mudanças. | O Windows nunca mostra o ".lnk": no Explorador, o atalho do Zoom se chama "Zoom". | "Zoom" em todo lugar da tela. Por dentro, o nome do arquivo continua o mesmo, porque é com ele que o Windows guarda o liga e desliga: desativar, reativar e desfazer gravam em "Zoom.lnk". Um arquivo que não é atalho ("backup.bat") e os itens do registro ficam como são. |
| D3 | Gerenciar inicialização aparece em Desempenho ("O que abre junto com o Windows; desligue o que não precisa") e em Programas ("Desative ou reative o que abre junto com o Windows"), com palavras de busca diferentes. A busca mostra a ação uma vez só, e a palavra decidia qual: "inicialização" trazia a de Desempenho; "lento", "desativar" e "reativar", a de Programas. É a UX28 da revisão de UX. | A mesma ação, a mesma frase. | As duas com a frase de Desempenho e as mesmas palavras de busca (as das duas juntas). A busca traz sempre a de Desempenho, a casa da ação. |

**Conferido e mantido:**
- **As descrições** cabem em 60 letras nos três idiomas, e a página tem um destaque só.
- **Nada da página pede Administrador para abrir,** nem os dois destinos novos da faixa.
- **"Marcar todos"** continua nas listas de fechar programas e de desativar ou reativar: fechar como no X deixa o programa perguntar se quer salvar, e o que foi desativado volta pelo Histórico de mudanças. A revisão do Otimizar continua sem ele (R18).

## MVP Windows

Nenhuma correção: o que a página faz e aconselha é o que a Microsoft orienta.

**Conferido**, com as fontes no fim:
- **Os conselhos da página são os da Microsoft** para um PC lento: desativar o que abre com o Windows ("Apps that run at startup can slow boot time and increase background usage"), ver o que usa o processador e a memória e fechar o que não está em uso, e reiniciar ("Close any apps or tabs you don't need. If performance does not improve, restart your PC."). A faixa agora leva aos dois primeiros (P1) e explica o terceiro (P2).
- **Ligado há e a Inicialização Rápida:** "fast startup is the default transition when a system shutdown is requested. A full shutdown (S5) occurs when a system restart is requested". Por isso a frase pede reiniciar, e não desligar, e a tela Tempo ligado e energia explica a diferença.
- **Fechar como no X:** `CloseMainWindow` faz o mesmo que fechar a janela pelo menu dela, devolve falso quando há uma caixa de diálogo aberta e deixa o programa perguntar antes de sair. Encerrar à força (`Kill`) é para o que não tem janela, e "Data edited by the process ... can be lost": por isso a pergunta à parte, com Não como padrão e agora com o botão vermelho.
- **O ".lnk" fora da tela:** "Some extensions are never shown, like .lnk".
- **O restante da R18 continua valendo:** o `EmptyWorkingSet` com o acesso mínimo documentado; desativar como o Gerenciador de Tarefas e as Configurações (o valor em `StartupApproved` e o `State` da tarefa dos aplicativos da Store), sem apagar nada; as tarefas de outros fabricantes desativadas no Agendador.
- **Robusto:** toda leitura do Windows na página tem prazo (15 segundos para a memória, 5 para a memória de cada processo e para os processos pai, 60 para o Agendador de Tarefas), e sem resposta a tela diz o que faltou.

## QA Sênior

**Como foi testado:** uma bateria nova do Desempenho, 94 conferências em cada idioma.
- **A faixa do alto (A):** normal, com a memória alta, com o PC ligado há 9 dias e com os dois (a cor, o botão, a seta, a altura, a linha sem botão ao lado, o leitor de tela e o clique); os limites (85% e 84%, 7 dias e 6 dias e 23 horas); sem a leitura do Windows, sem o total da memória, sem a hora do início e com um início "no futuro"; o prazo da leitura; o mesmo destino da Verificação do PC.
- **O Acelerar agora com temporários em uso (B):** a limpeza de verdade de uma pasta Temp com arquivos presos, com a memória liberada, folgada, ainda alta, recusada e sem medida; parte em uso, a pasta vazia, sem a pasta Temp, só arquivos recentes e a pasta recusada, como antes; a resposta de cada resultado da limpeza.
- **Programas pesando agora (C):** nomes amigáveis repetidos (Python e Python, Java e Java), um sem leitura, maiúsculas diferentes, um programa só; a lista, a pergunta, o encerrar à força e os botões, também na janela de verdade.
- **Gerenciar inicialização (D):** o nome da tela de atalhos, de ".LNK", de um .bat e de itens do registro e da Store; as listas e os botões dos dois lados; desativar, a faixa, o Histórico e o desfazer pelo nome do arquivo; o Windows sem manter a mudança; a revisão do Otimizar e a pergunta dela; a mesma ação nas duas páginas e a busca por nove palavras.
- **Os textos (K)** nos três idiomas.

**Achados**

| # | O que estava | Como ficou |
|---|---|---|
| Q1 | Quando os temporários antigos estavam todos em uso (um programa aberto segurando um arquivo de log, por exemplo), o Acelerar agora dizia "nenhum temporário para apagar" e, no resumo, "Temporários apagados: 0 B". Com a memória folgada, o resumo dizia "o PC já estava leve: quase nada a liberar". | A faixa diz "os temporários estavam em uso e ficaram", e o resumo, "Temporários apagados: nenhum (estavam em uso)". A faixa não fica amarela por isso: o que o Acelerar agora promete é deixar o PC leve, e arquivo preso não pesa. "Nenhum temporário para apagar" ficou só para quando não há nada a apagar. |
| Q2 | Dois programas com o mesmo nome amigável apareciam como gêmeos: o python e o pythonw são "Python"; o java e o javaw, "Java(TM) Platform SE binary". A lista mostrava dois "Python", a pergunta era "Fechar Python e Python?", e a faixa, "1 de 2 não fecharam: Python", sem dizer qual. | Os repetidos levam o nome do processo: "Python (python)" e "Python (pythonw)". Um programa sem leitura, que já aparece com o nome do processo, e os nomes que não se repetem ficam como são. |

Os testes também acharam os do produto (P1 e P2) e os do designer (D1 a D3).

**Contra o código de antes (R42):** cada conferência das correções falha, e as que conferem o que foi mantido passam. A faixa para na primeira com a memória alta, porque ela não tem botão.

**36 defeitos de propósito,** e as conferências pegam todos: a faixa sem destino, com o destino errado, com a frase antiga, com botão na memória normal ou sem leitura e com o limite de 8 dias; os temporários em uso lidos como nada ou como falha, sem a frase na faixa ou no resumo, com "0 B" na linha, esquecidos no "O PC já estava leve" e no "quase nada a liberar"; a limpeza da pasta com outra ressalva; os gêmeos sem parêntese, com a comparação sem maiúsculas e com parêntese no programa sem leitura; cada botão de volta ao Sim, ao Não e ao Confirmar, os verbos trocados, o encerrar à força sem o vermelho e a revisão sempre com Sim como padrão; o nome protegido repetido; o ".lnk" de volta na lista, nas mensagens e na revisão, tirado de qualquer item ou só em minúsculas; o desfazer e a gravação pelo nome da tela; e as palavras e a frase antigas em Programas. Na primeira rodada, um escapou: a limpeza da pasta devolvendo ressalva para a pasta que não existe, que o Acelerar agora leria como "em uso". A conferência passou a olhar o código inteiro e ganhou um caso de verdade (a pasta Temp que não existe), e o defeito passou a ser pego.

**Nada do que funcionava quebrou:** a bateria do Desempenho da R18 (96, 102 e 102) e as das outras 13 páginas revistas, com os mesmos números da R42 (a Rede com a mesma conferência antiga); a do Início da R40 (115), a da Manutenção da R41 (67) e a da Limpeza da R42 (97) em cada idioma; a da Manutenção da R14 (243, 245 e 250) e a do Início da R13 (241); as mensagens da janela (72 em cada idioma); a busca da R26 com os mesmos números, depois da troca das palavras de Gerenciar inicialização; instalar, atualizar com um clique, o pacote de suporte e o Setup de verdade, da R42 para esta; nenhum aviso novo do PSScriptAnalyzer (247) e nenhuma função sem uso (1.508, três novas).

## O que só um PC mostra

Isto entrou no roteiro de conferência (§34):
- **A faixa do alto** com a memória alta e com o PC ligado há uma semana, nos dois temas, com o mouse, o teclado e o Narrador; o clique em cada linha.
- **Os botões** nos três idiomas, sem cortar o texto ("Finalizar a la fuerza" é o mais longo), e o vermelho do encerrar à força.
- **O Acelerar agora com um arquivo preso na pasta Temp** (um programa aberto há dias), e a faixa dele.
- **Programas pesando agora com dois programas do mesmo nome** abertos (o Python num terminal e um script com o pythonw, ou o Minecraft e outro programa Java).
- **Gerenciar inicialização com um atalho na pasta Inicializar:** o nome sem ".lnk", desativar, conferir no Gerenciador de Tarefas e desfazer pelo Histórico de mudanças.
- **A busca** por "lento", "desativar" e "inicialização", que traz Gerenciar inicialização de Desempenho.

## Fontes
- [Tips to improve PC performance in Windows](https://support.microsoft.com/windows/b3b3ef5b-5953-fb6a-2528-4bbed82fba96) (Microsoft): desativar o que abre com o Windows ("Apps that run at startup can slow boot time and increase background usage"), ver o uso de processador, memória e disco e fechar o que não está em uso, e "Close any apps or tabs you don't need. If performance does not improve, restart your PC."
- [System power states](https://learn.microsoft.com/en-us/windows/win32/Power/system-power-states) (Microsoft): "fast startup is the default transition when a system shutdown is requested. A full shutdown (S5) occurs when a system restart is requested".
- [Process.CloseMainWindow](https://learn.microsoft.com/en-us/dotnet/api/system.diagnostics.process.closemainwindow) (Microsoft): o mesmo que fechar a janela pelo menu dela; falso "if the main window is disabled (for example if a modal dialog is being shown)"; com `Kill`, "Data edited by the process or resources allocated to the process can be lost".
- [Dialog controls](https://learn.microsoft.com/windows/apps/design/controls/dialogs-and-flyouts/dialogs) (Microsoft): "Use specific responses to the main instruction or content as button text".
- [How do I determine whether Explorer is showing or hiding file extensions?](https://devblogs.microsoft.com/oldnewthing/20241120-00/?p=110547) (Raymond Chen, The Old New Thing, Microsoft): "Some extensions are never shown, like .lnk."
