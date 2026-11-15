# Changelog

## Build 3.69

Esta build revisa a **Busca** (Ctrl+K) de ponta a ponta: o desenho da caixa e dos resultados, o código por trás do índice e da pontuação, o que cada resultado abre e uma bateria de buscas como as pessoas digitam. "Wi-Fi", como se escreve, deixa de trazer uma lista de resultados sem relação, e a caixa ganha o botão de limpar.
- **"wi-fi" acha o mesmo que "wifi":** e "wi-fi não conecta" leva direto ao reparo da rede.
- **Botão de limpar (×):** com texto na caixa, no lugar de "Ctrl K"; faz o mesmo que o Esc.
- **Buscas do dia a dia:** "apps", "melhorar desempenho", "pausar atualizações", "task manager", "msconfig".

### Mudou para quem usa

**A caixa de busca**
- **Botão de limpar:** com texto na caixa, um **×** aparece no lugar de "Ctrl K". Ele faz o mesmo que o Esc: volta à página de onde a busca começou (ou só esvazia a caixa, se a busca ainda não tinha aparecido) e deixa o cursor na caixa, para buscar outra coisa. Antes, quem usa só o mouse precisava selecionar e apagar o texto. Ele fica fora da ordem do Tab, como nas caixas de busca do Windows; pelo teclado, o Esc faz o mesmo.
- **O texto não passa por baixo do botão:** a caixa fica só na área do texto.

**Os resultados**
- **Conferidos, sem mudança de arrumação:** os cartões (no máximo 30, com a página de onde vêm), o resumo, o primeiro com a moldura e a tecla "Enter", as sugestões quando nada é encontrado, e o que cada tipo de resultado abre (página, ação, atalho do Windows, ajuste e a Aparência).

**O que a busca acha**
- **Palavras com hífen:** "wi-fi", como se escreve, era lida como "wi" e "fi", e trazia 15 resultados, entre eles **Finalizar tarefa pela barra de tarefas** e **Suporte do Windows**, por começarem com "fi" e "wi"; "wi-fi não conecta" trazia 114. Agora uma palavra com hífen vale como uma só ("wi-fi" acha o mesmo que "wifi", "hyper-v" o mesmo que "hyperv"), também com os hífens de texto colado. Um hífen entre duas palavras soltas ("limpeza-rápida") ainda acha pelas duas.
- **Palavras de uma ou duas letras no meio da frase:** só valem inteiras ("wi fi" não acha mais "Windows", e "ctrl k" não traz o que começa com k). A última palavra, que pode estar sendo digitada, continua valendo pelo começo ("disco c" acha os discos).
- **"wi-fi não conecta", "internet não conecta":** levam a **Reparar rede e DNS**.
- **"apps" e "app":** acham os aplicativos; "apps pré-instalados" leva a **Remover aplicativos do Windows** em primeiro.
- **"melhorar" e "aumentar":** não atrapalham mais ("melhorar desempenho" abre a página **Desempenho**, como "desempenho"; "aumentar fps" acha o **Modo de Jogo**).
- **"pausar atualizações" e "desativar atualizações":** levam ao **Windows Update**, onde se pausam as atualizações.
- **Nomes dos programas do Windows e em inglês:** "task manager", "msconfig", "cleanmgr", "disk cleanup" e "uninstall" acham o item certo; "superaquecendo" acha **Programas pesando agora**.
- **"rede":** deixa de trazer **Criar ponto de restauração**, que tinha "rede de segurança" entre as palavras de busca.

**O que não foi visto:** como nas builds anteriores, nada disto rodou num Windows de verdade. Pedem conferência num PC: o botão de limpar na caixa de busca, nos dois temas e com o mouse sobre ele, e um texto longo na caixa com o botão à vista.

A lista da 3.31 do que pede conferência continua valendo.

### Estrutura
- **Navigation.psm1:** `Join-WinForgeSearchHyphens` (uma palavra com hífen vira uma só); `Get-WinForgeSearchQuery` junta as palavras com hífen e separa as partes com `-SplitHyphens`; `New-WinForgeSearchSpecs` e `Find-WinForgeSearchHits` com a regra das palavras curtas no meio da frase; `Search-WinForgeNavigation` tenta as partes separadas quando a palavra junta não acha nada; "app", "apps", "aplicativo" e "aplicativos" como sinônimos; "melhorar" e "aumentar" entre as palavras de ligação; palavras de busca novas em oito itens e uma a menos no ponto de restauração.
- **MainWindow.xaml e WinForge.Gui.ps1:** o botão **SearchClear**, que aparece com texto na caixa e chama a mesma função do Esc.

### Preparação para publicação

- **Catálogo online:** endereço corrigido para a branch `main`; o repositório inclui `catalog/catalog.json`, gerado a partir dos dados já embutidos nesta build.
- **Código-fonte:** configurações de Git e ferramenta de assinatura preservadas no pacote do repositório.
- **Documentação:** esclarecido que assinar scripts não assina os arquivos `.cmd` e não garante a ausência de alertas do SmartScreen.

## Build 3.68

Esta build revisa a página **Sobre o WinForge** de ponta a ponta: o desenho em vários tamanhos de janela, o código por trás de cada item, o que cada um faz no Windows e uma bateria de casos típicos e fora do comum. O que cada item faz já estava certo; o que mudou é a faixa de resultado, que agora diz o que aconteceu em vez de "Tudo certo".
- **Verificar nova versão:** "Você está na versão mais recente" ou "Build 3.9 baixada e conferida", com a pasta para onde copiar.
- **Criar atalho do WinForge:** "Atalho criado", com onde ele ficou e como fixar na barra de tarefas.
- **Conferir dados online e Monitor na bandeja:** "Dados atualizados", "Dados em dia", "Monitor ligado", "Monitor desligado".

### Mudou para quem usa

**A página**
- **Conferida, sem mudança de arrumação:** o alto da página (versão, atalho e Administrador), os dois grupos de itens (Versão e dados; Integração com o Windows) e o cartão **Aparência**. Conferi também o que cada item faz: o download confere o SHA-256 publicado pelo GitHub, vai para a pasta Downloads de quem usa o PC e não troca os arquivos do WinForge; o monitor grava só a entrada de início da sua conta. Nada disso mudou.

**Verificar nova versão**
- **Em dia:** "Você está na versão mais recente", com a build publicada no GitHub. Numa cópia mais nova que a publicada, "Esta cópia é mais nova que a publicada".
- **Depois do download:** "Build 3.9 baixada e conferida" (ou "já baixada e conferida", quando o arquivo já estava na pasta Downloads), e a frase diz o passo que falta: fechar o WinForge e copiar o que está na pasta WinForge do zip para a pasta dele, que a frase mostra.

**Criar atalho do WinForge**
- **A faixa:** "Atalho criado", "Atalhos criados" (nos dois lugares) ou "Atalho atualizado", com onde ele ficou e como fixar na barra de tarefas.
- **Fixar no Windows 11:** a tela diz que a opção **Fixar na barra de tarefas** fica dentro de **Mostrar mais opções** (Área de Trabalho) ou de **Mais** (Menu Iniciar).

**Conferir dados online**
- **A faixa:** "Dados atualizados", com a data deles e quantos programas essenciais e versões do Windows trazem; "Dados em dia", quando não há dados publicados mais novos; e, sem conexão, "Dados não atualizados", com o motivo e a data dos dados que seguem valendo.

**Monitor na bandeja**
- **A faixa:** "Monitor ligado" (com onde achar o ícone), "Monitor desligado", "Monitor aberto" e "Avisos retomados". Desligar com o ícone já fechado não diz mais que ele fechou agora. Quando algo fica pela metade, o título diz o quê: "Monitor ligado, mas não abriu agora", "O ícone do monitor não fechou", com o que fazer.

**O que não foi visto:** como nas builds anteriores, nada disto rodou num Windows de verdade. Pedem conferência num PC: a faixa de cada item desta página na janela, com textos longos (uma pasta do WinForge com caminho comprido); e a opção **Fixar na barra de tarefas** no menu do atalho no Windows 11.

A lista da 3.31 do que pede conferência continua valendo.

### Estrutura
- **AppUpdate.psm1:** `Invoke-WinForgeUpdateFlow` com a faixa da versão em dia, da cópia mais nova e do download conferido (com a pasta para onde copiar).
- **Launcher.psm1:** `New-WinForgeShortcutFiles` com a faixa do atalho e o caminho da opção de fixar no Windows 11.
- **Catalog.psm1:** `Update-WinForgeOnlineData` com a faixa dos dados atualizados, em dia ou não atualizados.
- **Agent.psm1:** `Set-WinForgeMonitor` com a faixa de cada escolha.

## Build 3.67

Esta build revisa a página **Personalização** de ponta a ponta: o desenho em vários tamanhos de janela, o código por trás de cada item e de cada chave, o que cada ajuste e a cor de destaque gravam no Windows e uma bateria de casos típicos e fora do comum. A cor de destaque diz o que falta para pintar o Iniciar e a barra de tarefas (e só oferece reiniciar o Explorador quando isso muda algo), a faixa diz a cor escolhida, e uma gravação que falha não desliga mais a cor automática.
- **"Cor de destaque: Verde":** o título da faixa, em vez de "Tudo certo".
- **O que falta para pintar o Iniciar e a barra:** só o que de fato falta, o modo escuro, a opção ou os dois.
- **Cor no Iniciar e na barra com o modo claro:** a chave avisa que ela só aparece com o Modo escuro.

### Mudou para quem usa

**A página**
- **Conferida, sem mudança de arrumação:** os três cartões do alto (a cor de destaque e os dois atalhos para as Configurações do Windows) e as quatro categorias de chaves (Barra de tarefas e Iniciar, Área de trabalho, Cores e transparência, Tela de bloqueio). Conferi também o que cada ajuste grava e as versões do Windows em que cada um aparece; nada mudou neles. As chaves seguem a faixa da 3.66 ("Modo escuro: ativado").

**Cor de destaque**
- **A faixa:** "Cor de destaque: Verde", com o que acontece no Iniciar e na barra de tarefas: que eles também mudaram de cor, que mudam quando você sair e entrar de novo no Windows (sem o Explorador reiniciado) ou o que falta ligar. Na automática, "Cor de destaque automática", dizendo que a cor nova aparece quando o papel de parede mudar, com o botão **Abrir a Personalização do Windows**, onde se escolhe o papel de parede.
- **O que falta para pintar o Iniciar e a barra:** a cor só pinta os dois com o Windows no modo escuro e a opção **Cor de destaque no Iniciar e na barra de tarefas** ligada (a Microsoft diz que essa opção só existe no modo escuro). A tela mandava ligar os dois mesmo com o modo escuro já ligado, e, com a opção ligada e o Windows no modo claro, oferecia reiniciar o Explorador, o que não mudaria nada. Agora ela diz só o que falta e só oferece o reinício com os dois ligados.
- **O Explorador que não reinicia:** a cor já está gravada, e a faixa fica amarela dizendo o que faltou, como nas chaves (antes, ficava "Tudo certo").
- **Uma gravação que falha:** a cor automática era desligada antes das outras gravações; se uma delas falhava, quem usava a automática ficava sem ela e sem a cor nova. Agora ela é desligada por último.

**Cor de destaque no Iniciar e na barra de tarefas**
- **Com o modo claro:** ligar a chave gravava a opção e dizia que deu certo, mas nada aparecia, porque ela só vale com o modo escuro. Agora a tela e a faixa avisam: "Só aparece com o Modo escuro: ative-o também, aqui na Personalização."

**O que não foi visto:** como nas builds anteriores, nada disto rodou num Windows de verdade. Pedem conferência num PC: a cor de destaque com o modo escuro e a cor no Iniciar e na barra ligados, com o Explorador reiniciado e sem reiniciar; e o botão **Abrir a Personalização do Windows** depois da cor automática.

A lista da 3.31 do que pede conferência continua valendo.

### Estrutura
- **Tweaks.psm1:** `Get-WinForgeAccentTaskbarGaps` (o que falta para a cor pintar o Iniciar e a barra) e `Get-WinForgeTweakApplyHint` (o aviso do modo escuro ao ligar a cor no Iniciar e na barra); `Set-WinForgeAccentColor` com a faixa, o reinício do Explorador só quando muda algo, o Explorador que não reinicia como ressalva e a cor automática desligada por último; `Invoke-WinForgeTweakToggle` com o aviso.

## Build 3.66

Esta build revisa a página **Ajustes do Windows** de ponta a ponta: o desenho em vários tamanhos de janela, o código por trás de cada item e de cada chave, o que cada ajuste grava no Windows e uma bateria de casos típicos e fora do comum. As faixas dizem no título o que mudou, e a frase diz quais, como voltar e quando a mudança aparece; a Game Bar deixa de prometer o que os valores dela não garantem.
- **"Modo escuro: ativado", "2 ajustes aplicados", "2 ajustes desfeitos":** o título da faixa, em vez de "Tudo certo".
- **Quando a mudança aparece:** sem o Explorador reiniciado, a faixa diz que ela vale ao sair e entrar de novo no Windows.
- **Game Bar:** a descrição diz o que o ajuste para (a gravação de jogos e o botão Xbox do controle), sem prometer o Windows + G.
- **Pergunta no mesmo padrão:** "Desfazer todos agora?".

### Mudou para quem usa

**A página**
- **Conferida, sem mudança de arrumação:** os oito cartões do alto (com **Aplicar ajustes recomendados** como o único em destaque) e as seis categorias de chaves (Explorador, Privacidade e sugestões, Windows Update, Notificações e teclado, Jogos, Energia e desempenho) seguem do que mais se vê para o que mexe no hardware. Conferi também o que cada ajuste grava no registro e nos planos de energia, e as versões do Windows em que cada um aparece; fora da Game Bar, nada mudou.

**As chaves**
- **A faixa:** o título diz o recurso e como ele ficou ("ID de publicidade: desativado"); a frase diz como voltar ("O valor de antes foi guardado; para voltar, use a chave de novo"), ou, ao desfazer, se voltou ao valor de antes do WinForge, se o que foi alterado depois foi mantido ou se valeram os padrões do Windows. Num ajuste do Explorador sem reiniciá-lo, a frase acrescenta que a mudança aparece quando você sair e entrar de novo no Windows.

**Aplicar ajustes recomendados, Perfis de ajustes e Importar ajustes**
- **A faixa:** "2 ajustes aplicados", com os nomes (até quatro; com mais, três e quantos faltam). Com falhas, "1 de 2 ajustes aplicados", dizendo qual não foi aplicado e que o motivo está no resumo. Sem o Explorador reiniciado, a frase diz quando as mudanças aparecem.

**Exportar ajustes aplicados**
- **A faixa:** "2 ajustes exportados", com a pasta do arquivo e o que fazer no outro PC (**Ajustes do Windows > Importar ajustes**).

**Desfazer ajustes do WinForge**
- **A faixa:** "2 ajustes desfeitos", com os nomes. Com falhas, "1 de 2 ajustes desfeitos", dizendo qual ficou e que o backup dele foi mantido para uma nova tentativa.
- **A pergunta:** "Desfazer todos agora?", com **Não** como padrão, como antes, em vez de "Deseja desfazer todos?".

**Teclas que trocam o idioma do teclado**
- **A faixa:** o título diz a escolha ("Só Alt + Shift"; para a última opção, "Nenhuma tecla troca o idioma"), e a frase, o que ela faz.

**Desativar Xbox Game Bar e Game DVR**
- **O que a tela promete:** a descrição dizia que a barra do Windows + G parava. O ajuste grava a gravação de jogos desligada (a política do Windows e as opções do usuário) e desliga o botão Xbox do controle que abre a barra, mas a Microsoft não documenta que esses valores fechem o atalho Windows + G no Windows 11. Agora a descrição e a chave dizem só o que eles fazem: param a gravação de jogos em segundo plano e o botão do controle que abre a Game Bar. O que o ajuste grava não mudou.

**O que não foi visto:** como nas builds anteriores, nada disto rodou num Windows de verdade. Pedem conferência num PC: a faixa das chaves e dos recomendados com o Explorador reiniciado e sem reiniciar; e, no Windows 11, se o Windows + G ainda abre a Game Bar depois do ajuste (se não abrir, a descrição pode voltar a dizer isso).

A lista da 3.31 do que pede conferência continua valendo.

### Estrutura
- **Tweaks.psm1:** `Invoke-WinForgeTweakToggle`, `Invoke-WinForgeTweakBatch` (usada pelos recomendados, pelos perfis e pela importação), `Export-WinForgeTweaks`, `Invoke-WinForgeRevertAllTweaks` e `Set-WinForgeKeyboardLanguageHotkey` com a faixa; o que acontece no pedido de reiniciar o Explorador entra na frase; a descrição e a chave da Game Bar, sem o Windows + G; a pergunta de desfazer tudo no padrão.

## Build 3.65

Esta build revisa a página **Rede** de ponta a ponta: o desenho em vários tamanhos de janela, o código por trás de cada item, o que cada um pede ao Windows e uma bateria de casos típicos e fora do comum. As faixas dizem no título o que foi encontrado ou feito, com o botão para o que resolve; sem nenhuma rede conectada, o ping e o reparo dizem isso em vez de culpar a internet; e o teste de velocidade deixa de subestimar as conexões rápidas.
- **"A internet está funcionando", "Sem internet", "95 Mbps de download":** o título da faixa, em vez de "Tudo certo" ou "Concluído com ressalvas".
- **O botão que resolve:** sem internet ou com o DNS falhando, **Reparar a rede**; sem nenhuma rede, as configurações de rede do Windows.
- **Velocidade do download:** conta o trecho depois do arranque da conexão.
- **Perguntas no mesmo padrão:** "Iniciar o teste agora?" e "Reparar a rede agora?".

### Mudou para quem usa

**A página**
- **Conferida, sem mudança de arrumação:** as duas seções (**Ver e testar**, com quatro cartões, e **Consertar e configurar**, com três) vão do que só lê ao que mexe na rede, com o **Testar conectividade (ping)** como o único cartão em destaque.

**Testar conectividade (ping)**
- **A faixa:** "A internet está funcionando" (com a frase de quando alguns endereços ignoram o ping ou um deles perdeu um pouco de dados); "Sem internet" e "Os sites não abrem pelo nome", os dois com o botão **Reparar a rede**; "Conexão instável", com o que fazer.
- **Nenhuma rede conectada:** com o Wi-Fi desligado, o cabo solto ou o modo avião, os cinco pings só confirmavam o óbvio, e a faixa de "sem internet" mandava para o reparo, que não liga o Wi-Fi nem o cabo. Agora o ping nem roda: a faixa diz "Nenhuma rede conectada", o que conferir, e o botão **Abrir as configurações de rede** abre **Rede e Internet** nas Configurações do Windows.

**Testar velocidade da internet**
- **A faixa:** o título traz o download ("95 Mbps de download"), e a frase, o upload, a latência e o que isso permite ("Boa para vídeo em 4K e vários aparelhos ao mesmo tempo"). Internet lenta (menos de 10 Mbps) ou latência alta (mais de 100 ms) deixam a faixa amarela, dizendo o que isso atrapalha.
- **A conta do download:** toda conexão começa devagar e acelera nos primeiros instantes. Numa internet rápida, os 25 MB da medição chegam em menos de um segundo, e esse começo sozinho puxava o resultado para baixo. Agora a velocidade é a do trecho depois do arranque (o primeiro quarto de segundo, ou os primeiros 5 MB); numa conexão lenta, o número é o mesmo de antes. O download também nunca passa do limite de 25 MB, mesmo que o servidor mande mais, e lê em blocos de até 256 KB, com menos voltas no laço numa internet rápida.
- **A pergunta:** "Iniciar o teste agora?", no padrão das outras telas, em vez de "Deseja iniciar o teste de velocidade?".

**Reparar rede e DNS**
- **A faixa:** "Rede reparada" (a conexão funciona; falta reiniciar) ou "A conexão ainda não voltou", com o que fazer: reiniciar e testar de novo, e, se continuar, conferir o roteador ou falar com a operadora.
- **Nenhuma rede conectada:** antes da pergunta, a tela dizia "o reparo é indicado". Agora diz que o PC não está ligado a nenhuma rede e que o reparo não liga o Wi-Fi nem o cabo; se a pessoa repara mesmo assim, a faixa diz "Nenhuma rede conectada", com o botão para as configurações de rede.
- **A pergunta:** "Reparar a rede agora?", com **Não** como padrão, como antes, em vez de "Deseja executar o reparo de rede e DNS?".

**Trocar o servidor DNS, Desfazer a troca de DNS e Relatório de Wi-Fi**
- **A faixa:** "DNS trocado para Cloudflare" (e como voltar ao de antes), "DNS automático", "O novo DNS não funcionou" (o de antes foi restaurado), "DNS de antes restaurado", "Relatório do Wi-Fi gerado" (com onde ele ficou) e, num PC sem Wi-Fi, "Relatório não gerado", com o motivo provável.

**O que não foi visto:** como nas builds anteriores, nada disto rodou num Windows de verdade. Pedem conferência num PC: o teste de velocidade numa internet rápida (de 300 Mbps para cima), comparado ao teste da operadora ou ao speed.cloudflare.com; o ping e o reparo com o Wi-Fi desligado e com o modo avião ligado; e o botão **Abrir as configurações de rede** abrindo a página **Rede e Internet** no Windows 10 e no 11.

A lista da 3.31 do que pede conferência continua valendo.

### Estrutura
- **Network.psm1:** `Get-WinForgePingVerdict` devolve também o título, a frase e o botão da faixa; `Test-WinForgePing` confere antes se há alguma rede conectada; `Get-WinForgeSteadyMbps` (a velocidade depois do arranque da conexão), usada por `Measure-WinForgeDownload`, que guarda o andamento do download e não passa do limite de bytes; `Test-WinForgeInternetSpeed` e `Invoke-WinForgeNetworkRepair` com a faixa e as perguntas no padrão.
- **NetworkTools.psm1:** `Set-WinForgeDnsProvider`, `Undo-WinForgeDnsChange` e `Show-WinForgeWifiReport` com a faixa.
- **Shortcuts.psm1:** o atalho `NetworkSettings` (`ms-settings:network-status`, a página Rede e Internet), usado pelo botão da faixa.

## Build 3.64

Esta build revisa a página **Programas** de ponta a ponta: o desenho em vários tamanhos de janela, o código por trás de cada item, o que cada um pede ao Windows e ao winget e uma bateria de casos típicos e fora do comum. As faixas dizem no título o que aconteceu, com o botão para o próximo passo; o Python dos essenciais passa ao 3.15, e o backup que não salvou nada não deixa pasta para trás.
- **"2 programas instalados", "1 programa desinstalado":** o título da faixa, em vez de "Tudo certo".
- **O próximo passo num botão:** depois de desinstalar, a busca de restos; na lista de instalados, a tela de atualizar.
- **Python 3.15** nos programas essenciais, no lugar do 3.14.
- **Backup sem nada salvo:** a pasta vazia não fica para trás, e a tela não manda copiá-la.

### Mudou para quem usa

**A página**
- **Conferida, sem mudança de arrumação:** as quatro seções (**Instalar e remover**, com cinco cartões, **Inicialização e recursos** e **Backup e formatação**, com dois cada, e **Ferramentas do Windows**, com três) seguem o assunto, com o **Instalar programas essenciais** como o único cartão em destaque. As listas longas (a de desinstalar chega a centenas de programas) continuam com o filtro da janela.

**Instalar programas essenciais e Buscar e instalar programas**
- **A faixa:** o título diz quantos programas foram instalados ("2 programas instalados") ou atualizados (o que já estava no PC e ganhou versão nova: "1 programa atualizado"), e a frase, quais; o que já estava instalado e em dia aparece como "Já estava instalado". Se tudo o que foi marcado já estava em dia, "Nada para instalar", em vez de "Tudo certo" como se tivesse instalado. Com falhas: "1 de 2 programas instalados", com quais não foram instalados e que o motivo está no resumo. Com muitos programas, a frase diz três nomes e quantos faltam.
- **Python 3.15:** o Python 3.15 saiu em outubro de 2026, e o winget já o tem (`Python.Python.3.15`); ele substitui o 3.14 na lista. O catálogo publicado (`catalog/catalog.json`) muda junto, então uma build anterior também passa a oferecer o 3.15 quando confere os dados online.

**Desinstalar programas**
- **A faixa:** "1 programa desinstalado", com o nome, e o botão **Procurar restos**, que abre **Limpeza > Restos de programas desinstalados** (a busca já sabe quais programas acabaram de sair). Com falhas: "1 de 2 programas desinstalados", dizendo qual ficou, e o botão continua; se nenhum saiu, não há botão.

**Listar programas instalados**
- **A faixa:** o título diz quantos programas há ("35 programas instalados"), e a frase, quantos têm versão nova no winget, com o botão **Atualizar programas** quando há algum. O aviso de que a lista completa está nos detalhes técnicos passa do resumo para a faixa.
- **A conta das atualizações:** um programa de versão desconhecida ("Unknown") contava como "com atualização", mas a tela de atualizar não o mostra (o winget só o lista ali com a opção `--include-unknown`). Agora as duas telas contam igual.

**Remover aplicativos do Windows e Recursos opcionais do Windows**
- **A faixa:** "1 aplicativo removido", com o nome e se ele volta pela Microsoft Store (ou, para um aposentado pela Microsoft, que não volta); "1 recurso ligado", "1 recurso desligado" ou "2 recursos alterados", com os nomes, e o pedido de reinício, como antes. Com falhas, quantos deram certo e qual não deu.

**Backup antes de formatar e Restaurar a partir de um backup**
- **A faixa do backup:** "Backup salvo", com a pasta e o que falta fazer antes de formatar (copiar a pasta, quando ela ficou em Documentos, e as pastas pessoais).
- **Nada salvo:** quando o que foi marcado estava vazio (nenhum ajuste aplicado, nenhuma rede salva) ou falhou, a pasta criada para o backup ficava em **Documentos > WinForge > Backups** só com o `backup.json` e o `LEIA-ME`, e a tela mostrava **Onde está o backup** e mandava copiá-la para um pendrive. Agora a pasta é apagada e a tela não manda copiar nada; o desfecho continua "Nada a fazer" ou "Não foi concluído". A soma do tamanho das pastas pessoais, que pode levar minutos, também deixa de rodar nesse caso.
- **A faixa da restauração:** "4 itens restaurados", com o lembrete de reiniciar e de copiar de volta as pastas pessoais. Quando nada voltou, esse lembrete sai da tela.

**O que não foi visto:** como nas builds anteriores, nada disto rodou num Windows de verdade. Pedem conferência num PC: a instalação do Python 3.15 pelos essenciais (`Python.Python.3.15`); os botões **Procurar restos** e **Atualizar programas** abrindo as telas certas; e, num PC com programas de versão desconhecida, a conta de "com versão nova" da lista batendo com a tela de atualizar.

A lista da 3.31 do que pede conferência continua valendo.

### Estrutura
- **Software.psm1:** `Set-WinForgeWingetPackagesView` (a faixa de instalar e desinstalar pelo winget: instalados, atualizados, já em dia e os que falharam, com o botão de restos); `Show-WinForgeInstalledSoftware`, `Find-WinForgeSoftware`, `Install-WinForgeEssentialSoftware` e `Uninstall-WinForgeSoftware` com a faixa; `Get-WinForgeInstalledSoftwareCounts` não conta como atualização o programa de versão desconhecida.
- **Core.psm1:** `Join-WinForgeShortList` (até quatro nomes; com mais, três e quantos faltam), usada nas faixas para a frase não esticar, inclusive na de **Atualizar programas (winget)**.
- **PreinstalledApps.psm1 e WindowsFeatures.psm1:** `Remove-WinForgePreinstalledApps` e `Set-WinForgeWindowsFeatures` com a faixa.
- **Backup.psm1:** `Invoke-WinForgeBackupBeforeFormat` apaga a pasta quando nada foi salvo e monta a faixa; `Restore-WinForgeFromBackup` com a faixa e o lembrete só quando algo voltou.
- **Catalog.psm1 e catalog/catalog.json:** Python 3.15 no lugar do 3.14 (dados de 15/11/2026).

## Build 3.63

Esta build revisa a página **Atualizações** de ponta a ponta: o desenho em vários tamanhos de janela, o código por trás de cada item, o que cada um pede ao Windows e uma bateria de casos típicos e fora do comum. As faixas dizem no título o que aconteceu, com o botão para o que resolve; o cartão da Microsoft Store passa a pedir as atualizações, e as ferramentas da AMD e da Lenovo abrem no lugar certo.
- **"3 atualizações instaladas", "O Windows está em dia":** o título da faixa, em vez de "Tudo certo".
- **O botão que resolve:** um erro que o cache do Windows Update ou o reparo do Windows resolvem leva direto a eles.
- **Atualizar aplicativos da Microsoft Store:** pede as atualizações e abre a lista de downloads, em vez de só abrir a Store.
- **Ferramentas do fabricante:** a página de drivers da AMD e o Lenovo Vantage direto na Store.

### Mudou para quem usa

**A página**
- **Conferida, sem mudança de arrumação:** as três seções (**Windows e drivers**, com quatro cartões, **Programas e aplicativos**, com dois, e **Ferramentas do Windows**, com dois) seguem o assunto, com o **Instalar atualizações do Windows** como o único cartão em destaque.
- **Atualizar aplicativos da Microsoft Store:** o cartão "Atualizações da Microsoft Store" só abria a biblioteca da Store, para a pessoa clicar em **Obter atualizações**. Agora ele faz esse pedido (o mesmo da etapa da Store do Otimizar) e abre a lista de downloads, para acompanhar: a Store baixa e instala em segundo plano. Se o Windows recusar o pedido, a lista abre do mesmo jeito, como antes. O nome do cartão passa a ser o da tela que ele abre.

**Instalar atualizações do Windows e Atualizar drivers**
- **A faixa:** o título diz quantas foram instaladas ("3 atualizações instaladas", "2 drivers instalados"), e a frase, se falta reiniciar ("Reinicie o PC para terminar a instalação", dito uma vez só) ou, sem reinício, "Não precisa reiniciar" (nos drivers, como voltar ao driver anterior). Com falhas: "1 de 3 atualizações instaladas", com quantas falharam e que o motivo de cada uma está no resumo; nenhuma: "Nenhuma atualização instalada", em vermelho. Nada pendente: "O Windows está em dia"; nenhum driver novo: "Nenhum driver novo", com o botão **Ver as ferramentas do fabricante** (placa de vídeo e BIOS costumam ter versões mais novas lá).
- **O botão que resolve:** quando o motivo de uma falha aponta um item do WinForge (o cache do Windows Update estragado, o serviço desativado, os arquivos do Windows danificados), a faixa traz o botão **Corrigir o Windows Update** ou **Reparar o Windows**. Também quando a consulta ao Windows Update falha ("O Windows Update não respondeu", com o motivo embaixo).
- **Windows sem suporte:** com nada pendente num Windows que não recebe mais atualizações de segurança, a faixa diz isso e o botão abre **Diagnóstico > Suporte do Windows**.

**Corrigir o Windows Update**
- **A faixa:** "Cache do Windows Update refeito", com o botão **Procurar atualizações**, que abre **Instalar atualizações do Windows**; com o Windows Update no meio de uma instalação, "O Windows Update está instalando agora", com o botão **Ver o andamento**.
- **A pergunta:** "Corrigir o Windows Update agora?", no padrão das outras telas, em vez de "Deseja corrigir o Windows Update?".

**Atualizar programas (winget)**
- **A faixa:** "2 programas atualizados", com os nomes embaixo; nada para atualizar, "Os programas estão em dia".

**Ferramentas do fabricante**
- **AMD:** o botão abria um artigo que só explica o detector automático da AMD; agora abre a página de drivers da AMD, onde o detector é baixado.
- **Lenovo Vantage:** abre a página do aplicativo na Microsoft Store, em vez de uma busca por ele.

**O que não foi visto:** como nas builds anteriores, nada disto rodou num Windows de verdade. Pedem conferência num PC: o pedido de atualização à Microsoft Store pelo cartão (e a lista de downloads abrindo em seguida); a página do Lenovo Vantage abrindo na Store; e os botões da faixa abrindo as telas certas.

A lista da 3.31 do que pede conferência continua valendo.

### Estrutura
- **WindowsUpdate.psm1:** `Get-WinForgeUpdateFixStep` (o item que resolve um erro, pelo motivo), `Set-WinForgeInstallView` (a faixa de uma instalação, usada nas atualizações e nos drivers), `Set-WinForgeInstallErrorView` e `Set-WinForgeUpdateSearchView`; `Get-WinForgeUpdateRunResult` guarda as contas e os motivos (`Installed`, `Failed`, `Warned`, `Problems`); `Install-WinForgeWindowsUpdates` e `Repair-WinForgeWindowsUpdate` com a faixa.
- **Drivers.psm1:** `Install-WinForgeDriverUpdates` com a faixa; no catálogo de `Get-WinForgeVendorToolCatalog`, a página de drivers da AMD e a página do Lenovo Vantage na Store (`ProductId=9WZDNCRFJ4MV`).
- **Software.psm1:** `Update-WinForgeStoreApps`, pedida sozinha, abre a lista de downloads da Store e monta a faixa; `Invoke-WinForgeWingetUpgradePlan` com a faixa.
- **Navigation.psm1:** `updates.store` passa de atalho a ação (`Update-WinForgeStoreApps`), com o nome **Atualizar aplicativos da Microsoft Store**.

## Build 3.62

Esta build revisa a página **Reparo** de ponta a ponta: o desenho em vários tamanhos de janela, o código por trás de cada item, o que cada um pede ao Windows e uma bateria de casos típicos e fora do comum. O DISM e o SFC deixam de rodar à toa quando o Windows espera um reinício, as faixas das seis ações dizem no título o que concluíram, e o próximo passo vira um botão.
- **Reinício pendente primeiro:** com uma atualização esperando o reinício, o reparo nem começa; a tela diz por quê e oferece reiniciar.
- **"Nenhum problema encontrado", "Windows reparado":** o título da faixa do reparo, em vez de "Tudo certo".
- **O próximo passo num botão:** do SFC ao reparo completo, do DISM ao SFC, do reparo que não resolveu à Recuperação, e outros.
- **Perguntas no mesmo padrão:** "Iniciar o reparo agora?", como no resto do WinForge.

### Mudou para quem usa

**A página**
- **Conferida, sem mudança de arrumação:** as três seções (**Arquivos do Windows** e **Disco e dispositivos**, com três cartões cada, e **Ferramentas do Windows**, com dois) seguem o assunto, com o **Reparar o Windows (DISM + SFC)** como o único cartão em destaque.
- **As perguntas:** "Iniciar o reparo agora?", "Iniciar a verificação agora?" e "Agendar o reparo para a próxima reinicialização?", no padrão das outras telas, em vez de "Deseja iniciar o reparo?" e semelhantes. O agendamento continua com **Não** como padrão.

**Reparar o Windows, DISM e SFC**
- **Com o Windows esperando um reinício:** quando uma atualização termina de instalar ao reiniciar, o DISM recusa o reparo (erro 0x800F0806) e o SFC diz que há um reparo pendente, os dois depois de minutos de espera. O Otimizar já deixava essas etapas para depois; pedidos sozinhos, eles rodavam e falhavam. Agora nem começam: a tela diz "O Windows espera um reinício para terminar uma atualização: o DISM e o SFC só reparam depois de reiniciar" e oferece reiniciar ali mesmo, com **Não** como padrão. A faixa fica amarela: "Reinicie antes de reparar".
- **A faixa do reparo completo:** "Nenhum problema encontrado" (o DISM e o SFC conferiram o Windows), "Windows reparado" (com o que o DISM ou o SFC repararam), "Arquivos corrompidos sem reparo" (amarelo, com o botão **Abrir a Recuperação**, onde o Windows 11 reinstala o Windows mantendo arquivos e programas), "Reinicie e repita o reparo" e "Reinicie para concluir o reparo". Quando o SFC não diz nada reconhecível, "Reparo concluído", sem afirmar o que não foi lido.
- **O SFC sozinho:** "Nenhum arquivo corrompido", "Arquivos reparados" ou "Arquivos corrompidos sem reparo", este com o botão **Fazer o reparo completo** (o reparo completo conserta a imagem de onde o SFC tira os arquivos bons).
- **O DISM sozinho:** "Imagem do Windows íntegra" ou "Imagem do Windows reparada"; reparada, o botão **Verificar os arquivos (SFC)**, porque o passo seguinte é o SFC conferir os arquivos com a imagem consertada.
- **O Windows Update desativado:** o DISM que falha com o erro 0x80070422 (em geral, um bloqueador de atualizações desligou o serviço) mostra "Windows Update desativado" e o botão **Corrigir o Windows Update**, sozinho ou no reparo completo. Os outros erros continuam com a frase e o código.

**Verificar o sistema de arquivos (CHKDSK)**
- **A faixa:** "Nenhum erro na unidade C:" ou "Erros corrigidos na unidade C:"; com o reparo agendado, "Reparo da unidade C: agendado", com a frase "use Reiniciar, e não Desligar" (e, num disco externo, para deixá-lo conectado); sem agendar, "A unidade C: precisa de reparo", com o botão **Ver a saúde dos discos**.

**Detectar dispositivos e drivers e Otimizar a unidade do sistema**
- **Dispositivos:** "Nenhum dispositivo com problema"; ou "2 dispositivos ainda com problema", com os nomes e o problema de cada um embaixo e o botão **Ver os dispositivos com problema**; sem conseguir ler os dispositivos depois da busca, "Busca concluída", sem afirmar nada sobre eles.
- **Otimizar:** "Unidade C: otimizada", com o que o Windows fez conforme o disco (o TRIM num SSD, a desfragmentação num HD).

**O que não foi visto:** como nas builds anteriores, nada disto rodou num Windows de verdade. Pedem conferência num PC: o DISM e o SFC pedidos sozinhos num PC com uma atualização esperando o reinício (e a oferta de reiniciar); os botões da faixa abrindo as telas certas; e o reparo completo de ponta a ponta num Windows com arquivos danificados.

A lista da 3.31 do que pede conferência continua valendo.

### Estrutura
- **Repair.psm1:** `Request-WinForgeRepairRestart` (o reinício pendente antes do DISM e do SFC, com `Test-WinForgeServicingRebootPending`); `Invoke-WinForgeTool` ganha `-NeedsServicing` e `-ResultView` (a faixa de cada ferramenta, só quando ela roda sozinha); `Set-WinForgeRepairView` (a faixa do reparo completo) e `Set-WinForgeDismServiceView` (o Windows Update desativado); `Get-WinForgeSfcResult` marca o que o SFC concluiu (`Sfc`: `Clean` ou `Repaired`) e `Get-WinForgeDeviceScanRemaining`, quantos e quais dispositivos continuam com problema (`Remaining`, `Problems`); `Start-WinForgeChkdsk`, `Start-WinForgeDriveOptimization` e `Invoke-WinForgeDeviceScan` com a faixa; as perguntas no padrão das outras telas.

## Build 3.61

Esta build revisa a página **Desempenho** de ponta a ponta: o desenho em vários tamanhos de janela, o código por trás de cada item, o que cada um pede ao Windows e uma bateria de casos típicos e fora do comum. O **Acelerar agora** e o **Liberar memória** param de chamar de leve um PC com a memória cheia, as faixas das quatro ações dizem no título o que aconteceu, e os aplicativos da Microsoft Store passam a fechar como no X.
- **Memória que continua alta:** faixa amarela e o botão **Ver o que está pesando**, em vez de "Tudo certo".
- **"2 GB de memória liberados":** o título do Acelerar agora e do Liberar memória, com a memória de agora e de antes embaixo.
- **Aplicativos da Store:** fecham pela moldura do Windows, sem a pergunta de encerrar à força.
- **Gerenciar inicialização:** "Spotify desativado" no título.

### Mudou para quem usa

**A página**
- **Conferida, sem mudança de arrumação:** os dois grupos (**Deixar o PC mais leve**, com três cartões, e **Para o PC continuar leve**, com dois) seguem o assunto, com o **Acelerar agora** como o único cartão em destaque. O resumo do alto continua com a memória em uso e o tempo ligado; com o relógio do Windows acertado depois de ligar (a hora de ligar "no futuro"), a linha do tempo ligado sai, em vez de mostrar "Desconhecido".
- **Gerenciador de Tarefas:** a descrição diz que os gráficos de uso ficam na aba Desempenho dele (ele abre na última aba usada).

**Acelerar agora e Liberar memória**
- **A memória que continua alta:** quando, depois de liberar, a memória em uso continua em 85% ou mais, o que pesa são os programas abertos. Antes, a faixa saía verde e, se quase nada saísse, dizia "o PC já estava leve" ou "a memória já estava folgada" com 95% em uso. Agora o título diz "A memória continua alta (92%)", em amarelo, a frase diz que o peso são os programas abertos, e o botão **Ver o que está pesando** abre **Programas pesando agora**. No resumo, a memória de agora fica em amarelo, com um aviso que leva à mesma tela.
- **A faixa:** o título é quanto de memória saiu ("2 GB de memória liberados"), com a memória em uso agora e antes embaixo ("Memória em uso: 62% (antes, 88%)") e, no Acelerar agora, os temporários apagados. Com quase nada a liberar: "O PC já estava leve" ou "A memória já estava folgada", com a memória em uso. Quando o ganho foram os temporários, eles vão no título ("80 MB de temporários apagados"). O resumo, com as mesmas contas, fica nos detalhes quando a faixa já diz tudo.
- **O que deu errado:** "A memória não foi liberada" quando o Windows recusa; sem a leitura do Windows, "Memória liberada", sem número. No Acelerar agora, a pasta de temporários recusada e a conta diferente aparecem no fim da frase (antes, a faixa ficava amarela sem dizer por quê).

**Programas pesando agora**
- **Aplicativos da Microsoft Store:** a janela deles (Calculadora, Configurações...) é desenhada dentro de uma moldura do Windows, que é de outro processo. O WinForge os tratava como programas sem janela: dizia "não tem janela aberta" e oferecia encerrar à força. Agora eles fecham pela moldura, como no X, e contam como fechados quando ela fecha (o Windows encerra o aplicativo logo depois). Minimizado, um aplicativo da Store sai de dentro da moldura e continua contando como sem janela, com a pergunta de antes.
- **PowerShell e terminais:** um PowerShell ou terminal pesando aparece com "pode ser o WinForge", em vez de "usado pelo WinForge": o WinForge que está aberto nem entra na lista, e o que aparece pode ser o monitor da bandeja, a janela de texto do WinForge ou um script seu. Continua fora da lista para fechar.
- **A faixa:** "2 programas fechados" no título, com a memória em uso agora e antes embaixo (sem a leitura da memória, os nomes).

**Gerenciar inicialização** (também em **Programas**)
- **A faixa:** o título diz o que mudou ("Spotify desativado", "3 itens desativados", "1 desativado e 1 reativado"), e a frase, que vale a partir da próxima entrada no Windows.

**O que não foi visto:** como nas builds anteriores, nada disto rodou num Windows de verdade. Pedem conferência num PC: fechar um aplicativo da Store aberto (Calculadora, Configurações) por **Programas pesando agora**, inclusive minimizado, e a parte nova que acha a moldura compilando no Windows PowerShell 5.1; o Acelerar agora e o Liberar memória num PC com a memória cheia; e o botão **Ver o que está pesando**.

A lista da 3.31 do que pede conferência continua valendo.

### Estrutura
- **Performance.psm1:** `Test-WinForgeMemoryStillHigh`, `Write-WinForgeMemoryStillHighNotice` e `Set-WinForgeMemoryStillHighView` (a memória que continua alta, no resumo e na faixa); `Format-WinForgeMemoryFreedText` e `Write-WinForgeMemoryFacts` só dizem "folgada" com a memória de fato folgada; `Set-WinForgeMemoryOptimizationView` e `Set-WinForgeBoostView` montam as faixas com `Set-WinForgeResultView`; `Initialize-WinForgeWindowNative`, `Get-WinForgeAppFrameWindows` e `Close-WinForgeAppFrameWindow` (as molduras dos aplicativos da Store), usadas por `Test-WinForgeProcessGroupWindowless` e `Stop-WinForgeProcessGroup`; `Get-WinForgeProtectedProcessReason` com "pode ser o WinForge"; `Show-WinForgeHeavyProcesses` com a faixa de quantos fechou; `Get-WinForgePerformancePageStatus` sem a linha do tempo ligado quando ele não se pode dizer.
- **Startup.psm1:** `Set-WinForgeStartupItems` com a faixa do que mudou.
- **Navigation.psm1:** a descrição do Gerenciador de Tarefas.

## Build 3.60

Esta build revisa a página **Limpeza** de ponta a ponta: o desenho em vários tamanhos de janela, o código por trás de cada item, o que cada um pede ao Windows e uma bateria de casos típicos e fora do comum. A **Limpeza rápida** diz quanto vai sair antes de perguntar, o **Analisar uso de espaço** termina com o espaço livre e o caminho para limpar, e as ferramentas que mandam arquivos para a Lixeira oferecem esvaziá-la.
- **Quanto, antes de perguntar:** a Limpeza rápida mede os temporários e a Lixeira; sem nada para tirar, nem pergunta.
- **"2,3 GB liberados":** o título da faixa da Limpeza rápida.
- **Analisar uso de espaço:** "45 GB livres de 238 GB" no título, amarelo com pouco espaço, e o botão **Abrir a Limpeza personalizada**.
- **Esvaziar a Lixeira com um clique:** depois da limpeza da Downloads, dos duplicados e dos restos de programas.
- **Apagar o espaço livre:** o PC não suspende no meio.

### Mudou para quem usa

**A página**
- **Conferida, sem mudança de arrumação:** os três grupos (**Liberar espaço**, com seis cartões, **Arrumar o que sobrou**, com três, e **Avançado**, com três) seguem o assunto, com a **Limpeza rápida** como o único cartão em destaque.

**Limpeza rápida**
- **Quanto sai, antes da pergunta:** o resumo mostra os temporários que vão sair ("Temporários: 1,2 GB · 340 itens", contando só o que tem mais de um dia, como a limpeza) e o que está na Lixeira. Antes, só a Lixeira era medida, e a pessoa confirmava sem saber quanto os temporários liberariam.
- **Nada para limpar, nada para confirmar:** com os temporários vazios ou só com arquivos recentes e a Lixeira vazia, a tela diz "Nada para limpar" e não pergunta. Antes, era preciso confirmar para chegar a um "liberou 0 B".
- **A pergunta:** com a Lixeira vazia, "Limpar os temporários agora?", em vez de "Deseja continuar?".
- **A faixa:** "2,3 GB liberados" como título, com o que foi limpo embaixo (a Lixeira só entra quando havia algo nela). O resumo, parte por parte, fica nos detalhes; quando alguma parte não pôde ser medida, ele continua à vista.

**Analisar uso de espaço**
- **Uma faixa:** a análise terminava sem um resultado próprio na faixa. Agora o título é o espaço livre ("45 GB livres de 238 GB"), amarelo com pouco espaço ou com o disco quase cheio (a regra do Início), e embaixo vem quanto a Limpeza personalizada pode liberar ("Até 3,1 GB", ou "Pelo menos", quando algo não pôde ser medido, que também é dito).
- **O botão:** **Abrir a Limpeza personalizada**, quando há o que limpar, leva aonde se escolhe o que tirar.
- **Ressalva só quando falta algo:** sem ler o disco do sistema, ou quando, como Administrador, um item não pôde ser medido.

**Limpeza personalizada**
- **Nada acumulado:** a faixa diz "Nada para limpar", com "Não há temporários, relatórios nem caches acumulados" embaixo.

**Downloads, arquivos duplicados e restos de programas**
- **O espaço ainda está na Lixeira:** o que essas ferramentas tiram vai para a Lixeira, e o espaço só volta ao esvaziá-la. A faixa agora diz quanto foi para lá ("12 itens na Lixeira", "1,4 GB voltam ao disco ao esvaziar a Lixeira") e traz o botão **Esvaziar a Lixeira**, que abre a tela que faz isso. Antes, só o texto apontava o caminho. A exclusão definitiva da Downloads não tem o botão: ali o espaço já voltou.

**Apagar o espaço livre**
- **O PC fica acordado:** o `cipher /w` grava por horas, e com o PC suspenso no meio ele para com o disco cheio até o PC voltar. Enquanto ele roda, o WinForge pede ao Windows para não suspender, como na Manutenção, e devolve o controle ao terminar, ao ser parado ou com erro.

**O que não foi visto:** como nas builds anteriores, nada disto rodou num Windows de verdade. Pedem conferência num PC: quanto tempo a medição dos temporários leva antes da pergunta numa pasta Temp com dezenas de milhares de arquivos (ela lê a pasta inteira, e a limpeza lê de novo); os botões da faixa abrindo a Limpeza personalizada e o Esvaziar a Lixeira; e o Apagar o espaço livre num notebook com a suspensão automática ligada.

A lista da 3.31 do que pede conferência continua valendo.

### Estrutura
- **Cleanup.psm1:** `Measure-WinForgeTempCleanup` (o que a Limpeza rápida tiraria dos temporários, com as regras da limpeza: tempo mínimo, pastas seguras, a mesma pasta contada uma vez); `Invoke-WinForgeQuickCleanup` mostra as duas medidas antes da pergunta, termina em "Nada para limpar" sem perguntar e monta a faixa com `Set-WinForgeResultView`; `Show-WinForgeSpaceAnalysis` devolve um resultado (o espaço livre e `CleanableBytes`) com a faixa; `Set-WinForgeRecycleBinNext` (o título, a frase e o botão **Esvaziar a Lixeira**), usado por `Invoke-WinForgeDownloadsRemoval`; `Invoke-WinForgeCustomCleanup` com a faixa "Nada para limpar".
- **CleanupTools.psm1:** `Find-WinForgeDuplicateFiles` e `Remove-WinForgeProgramLeftovers` passam por `Set-WinForgeRecycleBinNext` (os restos somam o tamanho das pastas enviadas); `Clear-WinForgeFreeSpace` usa `Set-WinForgeKeepAwake` em volta do `cipher /w`.

## Build 3.59

Esta build revisa a página **Segurança** de ponta a ponta: o desenho em vários tamanhos de janela, o código por trás de cada item, o que cada um pede ao Windows e uma bateria de casos típicos e fora do comum. O resultado do **Estado da proteção** e da **Auditoria de segurança** passa a dizer o mais grave no título, na cor certa e com o botão para resolver; a auditoria confere o **SMB 1.0**; e as verificações completa e de uma pasta atualizam o antivírus antes, como o **Verificar vírus**.
- **Resultado direto:** "Antivírus desligado", em vermelho, com **Abrir a Segurança do Windows**, em vez de "Concluído com ressalvas" e uma frase longa.
- **Um botão que resolve:** a página certa da Segurança do Windows, **Atualizar as assinaturas**, **Instalar as atualizações** ou os recursos do Windows.
- **SMB 1.0 na auditoria:** o protocolo antigo usado pelo WannaCry, ligado, pede atenção.
- **Verificar com o antivírus de hoje:** a completa e a de uma pasta atualizam as assinaturas antes.

### Mudou para quem usa

**A página**
- **Conferida, sem mudança de arrumação:** as duas seções (**Proteção**, com três cartões, e **Procurar ameaças**, com quatro) seguem o assunto e cabem em duas linhas em qualquer largura de janela. Com outro antivírus protegendo o PC, as ações do Windows Defender continuam saindo da página.
- **Descrições:** as da verificação completa e da de uma pasta dizem que o antivírus é atualizado antes.

**Estado da proteção**
- **O título da faixa:** um ponto de atenção aparece pelo nome ("Antivírus desligado", "Assinaturas com 9 dias", "Firewall desligado (Rede pública)"), com a frase do que fazer embaixo; vários aparecem pela conta ("3 pontos de atenção"), com cada um pelo nome embaixo. Antes, era sempre "Concluído com ressalvas" com todos numa frase só. Com tudo em ordem: "Nenhum ponto de atenção" e "Antivírus, firewall e atualizações do Windows em ordem".
- **A cor:** vermelho quando o PC está sem proteção (antivírus ou proteção em tempo real desligados, ameaça ativa, firewall desligado na rede pública), como no Verificar vírus e na auditoria; amarelo para o resto. Com outro antivírus no lugar, as ameaças que o Defender ainda guarda continuam ressalva amarela.
- **O botão:** leva aonde se resolve o mais grave: a página **Proteção contra vírus e ameaças** ou a **Firewall e proteção de rede** da Segurança do Windows, **Segurança > Atualizar assinaturas do antivírus** ou **Atualizações > Instalar atualizações do Windows**. O resumo continua com cada ponto e o que fazer.

**Auditoria de segurança**
- **SMB 1.0:** um ponto novo, com o recurso do Windows que a Microsoft indica para conferir o SMB 1.0 no Windows 10 e 11 (`SMB1Protocol`). Ligado (ou ligando no próximo reinício), pede atenção e aponta **Programas > Recursos opcionais do Windows**, para quem não tem um scanner ou NAS antigo que precise dele; desligado ou ausente, está em ordem; sem leitura, fica de fora da nota e a tela diz isso.
- **SmartScreen:** "Ligado" quando o Registro diz, ou "Ligado (o padrão do Windows)" quando nada está gravado, em vez de "Não está desligado".
- **A faixa:** a nota como título ("Nota 95 de 100 · Ótima"), os pontos de atenção pelo nome embaixo, vermelho com um problema grave, e o botão para o primeiro ponto que tem um lugar certo para resolver (a Segurança do Windows, as assinaturas, as atualizações, o suporte do Windows ou os recursos do Windows). O UAC, a conta Convidado, a entrada automática e a Área de Trabalho Remota não têm um clique que resolva, e a tela continua dizendo o que fazer em cada um.

**Verificação completa e Verificar uma pasta**
- **Antivírus atualizado antes:** como o Verificar vírus, as duas atualizam as assinaturas antes de verificar. Horas de verificação completa com as assinaturas de dias atrás deixariam passar o que surgiu nesse meio-tempo, e quem verifica um arquivo baixado agora quer as de hoje (a verificação pedida ao Defender não atualiza nada antes de começar). Sem conseguir atualizar, a verificação roda com as de antes e a faixa fica amarela, dizendo por quê.
- **Caminho errado primeiro:** na de uma pasta, um caminho sem a unidade ou que não existe é recusado antes de atualizar o antivírus, sem trabalho à toa.
- **A faixa:** "Antivírus atualizado e verificação completa concluída"; na de uma pasta, "Antivírus atualizado; verificado: D:\Fotos".

**O código**
- A verificação rápida sozinha, sem atualizar o antivírus, ainda existia no código, sem cartão nem item no menu desde a 3.54. Saiu.

**O que não foi visto:** como nas builds anteriores, nada disto rodou num Windows de verdade. Pedem conferência num PC: o `Get-WindowsOptionalFeature -Online -FeatureName SMB1Protocol` num Windows com o SMB 1.0 ligado e num instalado do zero (e quanto tempo a consulta leva); os botões da faixa abrindo as páginas certas da Segurança do Windows; e a verificação de uma pasta com o antivírus sendo atualizado antes, num PC sem internet.

A lista da 3.31 do que pede conferência continua valendo.

### Estrutura
- **Security.psm1:** `Get-WinForgeSecurityNextStep` (o botão de cada ponto) e `ConvertTo-WinForgeHeadline`; `Show-WinForgeSecurityStatus` e `Show-WinForgeSecurityAudit` montam a faixa com `Set-WinForgeResultView`; `Get-WinForgeSmb1State` e o fato `Smb1`, com o ponto `smb1` na auditoria (só quando foi lido); o fato `SmartScreenSet`; `Test-WinForgeScanPath` confere o caminho antes; `Start-WinForgeFullScan` e `Start-WinForgeFolderScan` passam por `Invoke-WinForgeSignatureUpdate` e `Join-WinForgeSecurityCheckResult`, que diz a frase de cada verificação; `Start-WinForgeQuickScan` saiu.
- **Navigation.psm1:** as descrições da verificação completa e da de uma pasta.

## Build 3.58

Esta build revisa a página **Diagnóstico** de ponta a ponta: o desenho em vários tamanhos de janela, o código por trás de cada item, o que cada um pede ao Windows e uma bateria de casos típicos e fora do comum. A página passa a ser organizada pelo assunto, **Sobre este PC** diz o fabricante e o modelo do PC, e uma tela que dizia "nenhum dispositivo com problema" sem ter olhado foi corrigida.
- **Seções pelo assunto:** **Visão geral**, **Hardware**, **Funcionamento do Windows** e **Ferramentas do Windows**, com a mesma arrumação em qualquer largura de janela.
- **Sem cartão inútil:** num PC sem bateria, **Saúde da bateria** sai da página.
- **Fabricante e modelo:** **Sobre este PC** mostra o modelo do PC, como o relatório, e avisa quando a placa de vídeo está sem driver.
- **Disco no fim da vida:** **Saúde dos discos** avisa quando o próprio disco prevê a falha (SMART).
- **Erros comuns explicados:** em **Eventos críticos**, os erros que quase todo PC registra aparecem explicados, sem alarme.

### Mudou para quem usa

**A página**
- **Organização:** as seções tinham três, três e seis cartões, arrumados para a janela de três colunas: só nessa largura o Monitor de Confiabilidade ficava embaixo de Eventos críticos e o Gerenciador de Dispositivos embaixo de Dispositivos com problema. Com a janela no mínimo (duas colunas) ou maximizada (quatro), a arrumação se perdia e os atalhos do Windows ficavam no meio das telas do WinForge. Agora as seções seguem o assunto: **Visão geral** (Sobre este PC, Suporte do Windows, Exportar relatório), **Hardware** (Discos e espaço livre, Saúde dos discos, Dispositivos com problema, Saúde da bateria), **Funcionamento do Windows** (Eventos críticos, Reinício pendente, Tempo ligado e energia) e **Ferramentas do Windows** (Monitor de Confiabilidade e Gerenciador de Dispositivos), como nas outras páginas. Em qualquer largura, nenhuma seção passa de duas linhas.
- **Saúde da bateria:** quando o cartão Bateria do Início confirma que o PC não tem bateria (um PC de mesa, inclusive com nobreak), o cartão sai do Diagnóstico. Ele é o último da seção **Hardware**, então os outros não mudam de lugar. Antes de o Início terminar a leitura, ele aparece; a busca continua chegando nele.

**Sobre este PC**
- **Fabricante e modelo:** uma linha nova no Sistema ("Dell Inc. Inspiron 15 3520"), o que um técnico pergunta primeiro. Num Lenovo, o nome do modelo vem junto do tipo da máquina ("Lenovo ThinkPad X1 Carbon Gen 9 (20XWCTO1WW)"). Num PC montado, em que o Windows só tem textos de fábrica ("System Product Name"), a linha não aparece e a seção Placa-mãe identifica o PC. O relatório usa a mesma regra e deixa de mostrar só o fabricante.
- **Placa de vídeo sem driver:** quando a única placa é o adaptador básico da Microsoft, a tela avisa, em amarelo, e aponta **Atualizações > Atualizar drivers**.

**Dispositivos com problema**
- **Falha que parecia "tudo certo":** na janela, uma falha da consulta que o Windows não trata como erro grave (o serviço do WMI parado, por exemplo) deixava a lista vazia, e a tela dizia, em verde, "nenhum dispositivo com problema". Agora qualquer falha da consulta termina em vermelho, com o motivo.
- **Menos texto:** com um dispositivo com problema, a dica do fim (onde procurar drivers mais novos) repetia o que o "o que fazer" logo acima já dizia; ela fica só quando não há problema.

**Saúde dos discos**
- **Previsão de falha:** um disco que prevê a própria falha (SMART) aparece no Windows com o estado de atenção e "Predictive Failure". A tela diz isso com todas as letras ("O próprio disco avisa que pode falhar em breve"), no lugar do genérico "estado de atenção", e pede backup. O relatório diz o mesmo.
- **Ordem fixa:** os discos aparecem na ordem do Gerenciamento de Disco (disco 0, 1, 2...); antes, vinham na ordem em que o Windows os devolvia, que podia mudar de uma vez para outra.

**Discos e espaço livre**
- **A unidade do Windows:** a dica de onde liberar espaço (a Limpeza no disco do Windows; mover arquivos nas outras unidades) segue a mesma regra que decidiu o aviso. Antes, sem a variável SystemDrive, o aviso tratava C: como a unidade do Windows e a dica, como uma unidade de dados.

**Eventos críticos (7 dias)**
- **Erros comuns explicados:** o DCOM ("um componente do Windows não respondeu a tempo"), o Schannel ("uma conexão segura com um site ou serviço foi recusada") e a atualização que não foi instalada aparecem explicados, como comuns e sem alarme; antes eram linhas só com a origem e o número. Na atualização, a tela diz que o Windows tenta de novo e, se continuar, aponta **Atualizações > Corrigir o Windows Update**.

**Conferido, sem mudança**
- **O que cada item pede ao Windows:** os dois atalhos abrem o Monitor de Confiabilidade (`perfmon /rel`) e o Gerenciador de Dispositivos (`devmgmt.msc`); a saúde da bateria vem do relatório do `powercfg`, que não pede Administrador; a saúde dos discos pede Administrador porque os contadores de confiabilidade exigem; o Reinício pendente lê as chaves do Registro que o próprio Windows usa para isso. As datas do **Suporte do Windows** batem com as publicadas, inclusive as atualizações estendidas gratuitas do Windows 10 até 12/10/2027.

**O que não foi visto:** como nas builds anteriores, nada disto rodou num Windows de verdade. Pedem conferência num PC: a página Diagnóstico com a janela no mínimo, no tamanho padrão e maximizada; **Saúde da bateria** num PC de mesa (o cartão sai depois de o Início ler) e num notebook (fica); **Sobre este PC** num notebook de marca, num Lenovo e num PC montado; **Dispositivos com problema** com o serviço Instrumentação de Gerenciamento do Windows parado; **Saúde dos discos** com um disco que o Windows marca com "Predictive Failure"; e **Eventos críticos** num PC com erros do DCOM ou do Windows Update.

A lista da 3.31 do que pede conferência continua valendo.

### Estrutura
- **Navigation.psm1:** os itens do Diagnóstico em quatro seções (Visão geral, Hardware, Funcionamento do Windows, Ferramentas do Windows), com a Saúde da bateria por último em Hardware.
- **WinForge.Gui.ps1:** `$script:HasBattery`, preenchido por `Set-GuiHomeFact` com o que o cartão Bateria do Início leu; `Show-GuiListPage` tira `diagnostics.battery` da página quando ele é `$false`.
- **Diagnostics.psm1:** `Get-WinForgeMachineModelText` (fabricante e modelo, também usado pelo relatório); `Show-WinForgeSystemInfo` lê o `Win32_ComputerSystem` sempre e avisa do adaptador básico; `Get-WinForgeDiskSummary` marca a unidade do Windows (`Sistema`), que `Show-WinForgeDiskSummary` usa na dica; `Get-WinForgeDiskHealth` ordena pelo número do disco e guarda `OperationalStatus`, que `Get-WinForgeDiskHealthNotes` lê; `Show-WinForgeProblemDevices` consulta com `-ErrorAction Stop`; `Get-WinForgeEventHint` explica o DCOM, o Schannel e o Windows Update 20, e `Get-WinForgeEventNote` diz o que vem depois de cada causa comum.
- **Reports.psm1:** o fabricante e o modelo pela mesma função da tela.

## Build 3.57

Esta build corrige as perguntas da tela de execução que passavam do fim da janela. Na etapa **Desinstalar programas** do **Otimizar**, com dezenas de programas, a lista não rolava e os botões ficavam fora da tela. A correção vale para toda pergunta da janela (listas de marcação, escolhas em linhas e perguntas de texto), em qualquer ação que as mostre.
- **A lista rola:** o cartão da pergunta nunca passa do fim da janela, e só a lista encolhe.
- **Botões sempre à vista:** os botões de resposta ficam inteiros, em qualquer tamanho de janela.

### Mudou para quem usa

**Perguntas na tela de execução**
- **O defeito:** a altura do cartão da pergunta dependia só de uma conta feita quando ela aparecia. Quando essa conta falhava, ou media a lista antes de ela estar desenhada (contando-a como vazia), o cartão ficava do tamanho da lista inteira, sem barra de rolagem, e os botões ficavam abaixo do fim da janela. O mesmo podia acontecer em qualquer pergunta com lista longa: programas, aplicativos, inicialização, duplicados, ajustes.
- **Duas proteções:** a própria janela agora mede a pergunta com a altura que sobra até o fim da tela, então a lista rola mesmo se a conta falhar. A conta (o resumo que encolhe, o cartão do andamento que sai) mede o que está à vista sem depender da tela já desenhada, nunca deixa o cartão passar do fim da tela e, se falhar, limita o cartão até lá.
- **A conta refeita:** um instante depois de a pergunta aparecer, com a tela já desenhada, e a cada linha nova do resumo enquanto ela está à vista.
- **Janela baixa:** quando nem a pergunta sem a lista cabe (janela de 600 px, texto grande), as linhas do resumo copiadas para dentro dela saem primeiro, e os botões continuam à vista. Elas continuam no resumo e nos detalhes técnicos, e voltam para a pergunta quando a janela cresce.

**As outras telas**
- **Revisão de rolagem:** todas as áreas da janela que crescem com o conteúdo foram revistas: as páginas, a barra lateral, o resumo da execução, as listas e as opções das perguntas e os detalhes técnicos. Todas já rolavam; o único lugar sem limite de altura era o cartão da pergunta.

**O que não foi visto:** como nas builds anteriores, nada disto rodou num Windows de verdade, e a causa exata do defeito no seu PC não foi reproduzida (as duas causas possíveis estão cobertas). Pedem conferência num PC: a etapa **Desinstalar programas** do Otimizar com mais de 50 programas, em 1366 x 768 com 125% de escala, em 1920 x 1080 e com a janela maximizada, rolando a lista com a roda do mouse e com o teclado até os botões; uma lista longa com os detalhes técnicos abertos; e mudar o tamanho da janela com uma pergunta na tela.

A lista da 3.31 do que pede conferência continua valendo.

### Estrutura
- **MainWindow.xaml:** a tela de execução passa a ter três linhas; a pergunta e os detalhes técnicos ficam num `DockPanel` na linha de altura `*` (a pergunta encaixada no alto, os detalhes com o resto).
- **WinForge.Gui.ps1:** `Get-GuiPromptLayoutNow` lê `Visibility` e `ExtentHeight` no lugar de `IsVisible` e mede o cartão com altura livre; `Update-GuiPromptFit` tira o contexto quando nem a pergunta sem a lista cabe e, se a conta falhar, limita o cartão ao fim da tela; `Request-GuiPromptFit` e o relógio `PromptFitTimer` refazem a conta depois de a pergunta aparecer e a cada linha nova do resumo.
- **GuiHost.psm1:** `Get-WinForgePromptLayout` nunca devolve um limite além do fim da tela e diz quando nem a pergunta sem a lista cabe (`Cramped`).

## Build 3.56

Esta build revisa a página **Manutenção** de ponta a ponta: o desenho em vários tamanhos de janela, o código por trás de cada item, o que cada um pede ao Windows e uma bateria de casos com os arquivos de estado de verdade. A página fica mais curta e direta, o **Verificar o PC** passa a olhar o disco e as atualizações, e alguns casos em que a tela dizia o que não era verdade foram corrigidos.
- **Página mais limpa:** no alto, o cartão **Última manutenção** do Início; embaixo, duas seções de três cartões.
- **O motivo de cada etapa:** o **Histórico de manutenções** começa pelo que pediu atenção na última manutenção, com onde rodar cada etapa de novo.
- **Verificar o PC mais completo:** confere o espaço no disco e se as atualizações de segurança estão em dia.
- **Ponto de restauração honesto:** quando o Windows não cria o ponto, a faixa diz isso, em vermelho.
- **Nada some:** um arquivo do WinForge estragado que volta da cópia anterior não se perde mais na leitura seguinte.

### Mudou para quem usa

**A página**
- **O alto da página:** o cartão **Última manutenção**, o mesmo do Início ("há 2 dias" e, embaixo, a data ou "2 etapas com atenção"), no lugar das três linhas de texto. O clique nele abre o **Histórico de manutenções**. A frase embaixo do título ficou curta: "Cuide do PC e volte atrás se algo der errado."
- **Duas seções de três cartões:** **Cuidar do PC** (**Otimizar**, **Verificar o PC** e **Manutenção agendada**) e **Se algo der errado** (**Criar ponto de restauração**, **Histórico de mudanças** e **Restauração do Sistema**). A manutenção agendada não fica mais abaixo da dobra numa janela de 1180 x 760. O **Histórico de manutenções** (que repetia o cartão do alto) e o **Agendador de Tarefas** não viram cartão: a busca e o console continuam chegando neles.
- **Descrições curtas:** cada cartão diz o que faz em uma frase ("A manutenção completa do PC, em ordem; pode levar mais de uma hora"). O **Histórico de mudanças** não promete mais "tudo o que o WinForge mudou": diz o que mudou e que dá para desfazer o que tiver volta.
- **Ícones:** **Criar ponto de restauração** ganhou uma bandeira, e **Restauração do Sistema** ficou com a seta de voltar; antes, os dois eram quase iguais, lado a lado.
- **Leitor de tela:** o nome de cada cartão inclui o que ele mostra em etiqueta e nota ("Recomendado", "Abre no Windows", "Pede Administrador ao executar"), em todas as páginas.

**Verificar o PC**
- **Espaço no disco:** a primeira linha é o espaço livre no disco do Windows, com os limites do Início; com pouco espaço, ela leva à **Limpeza personalizada**. Antes, a verificação podia terminar verde com o disco quase cheio.
- **Atualizações do Windows:** com o Windows no suporte, confere se as atualizações de segurança estão em dia (a mesma conta do Início); atrasadas, a linha leva a **Instalar atualizações do Windows**.
- **Registro desmarcado:** as referências quebradas do registro continuam na lista, mas desmarcadas: a Microsoft não dá suporte a limpadores de registro, e o ganho é pequeno. O backup e o desfazer continuam valendo para quem marcar.
- **Memória:** saiu a correção **Liberar memória**, que não resolvia (os programas voltam a ocupar a memória). Com a memória acima de 85%, a linha leva a **Desempenho > Programas pesando agora**.
- **Nomes que dizem tudo:** com Administrador, a limpeza marcada leva também o cache de atualizações da Otimização de Entrega, e o nome dela diz isso ("Temporários, relatórios de erro e cache de atualizações").
- **A pergunta:** "O que corrigir agora?", com **Corrigir** e **Agora não**. Na janela, o cartão da pergunta mostra a frase do que vem marcado, e não as últimas linhas da lista ("Reinício pendente: não"). Enquanto a verificação lê o PC, o alto da tela diz "Verificando o PC", em vez de "Em andamento".
- **O fim:** o título da faixa diz o que foi feito ("3 correções feitas, 1,9 GB liberados"), e embaixo vem o que ainda pede você. Com algo pendente, o botão da faixa abre a tela do primeiro deles.

**Histórico de manutenções**
- **A última manutenção primeiro:** cada etapa que pediu atenção aparece com o motivo guardado e onde rodá-la de novo ("Limpeza rápida: Atenção (2 arquivos em uso); rode de novo em Limpeza > Limpeza rápida"). O cartão do Início e o da página diziam "2 etapas com atenção" e mandavam para cá, mas aqui só havia contagens.
- **Datas no futuro:** uma verificação gravada com o relógio adiantado não aparece mais como "agora há pouco". Em todo o WinForge, uma data mais de um dia no futuro aparece como "com data no futuro".
- **Sem "Executar de novo":** a tela só mostra informações, e rodar de novo mostraria a mesma coisa (o mesmo vale para o **Histórico de mudanças** quando nada é desfeito). Um histórico que não pôde ser lido termina em vermelho.

**Criar ponto de restauração**
- **O ponto que o Windows não cria:** com o ponto mais novo de 3 dias e o Windows sem criar outro, a faixa dizia "Já havia um ponto recente", em amarelo, e dentro do Otimizar a pergunta "Continuar sem o ponto de restauração?" era pulada. Agora é "O ponto de restauração não foi criado", em vermelho, com o motivo embaixo, e o Otimizar pergunta.
- **Proteção do Sistema desligada:** reconhecida pelo código do erro do Windows (0x80070422), em qualquer idioma, e não pelo texto. A pergunta ficou numa linha, com **Ligar e criar** e **Agora não**.
- **Política:** com a Restauração do Sistema desligada por uma política do PC (Diretiva de Grupo, a empresa), a tela diz isso e não oferece ligar a proteção, que falharia.
- **Criado:** a faixa diz "Ponto de restauração criado" e onde voltar a ele.

**Histórico de mudanças**
- **Uma vez só:** a pergunta "O que desfazer?" (botão **Desfazer**) traz as mudanças que têm volta; a lista de cima traz só as outras. Antes, cada mudança aparecia duas vezes, e três linhas soltas vinham antes da pergunta.
- **Sem Administrador:** desfazer um recurso do Windows ou o DNS diz "pede Administrador: abra o WinForge como Administrador e desfaça de novo", e a mudança continua na lista. Antes, vinha o texto cru do Windows, ou a indicação de outra tela que também pede Administrador.
- **DNS:** só endereços IP de verdade voltam como servidores DNS; um backup alterado por outro programa deixa o adaptador como está.

**Manutenção agendada**
- **Uma linha só:** "Uma vez por mês, às 12h (ou depois que você entrar no Windows, se o PC estava desligado), apaga os temporários com mais de 7 dias e salva um relatório. Nada mais muda; no notebook, só na tomada." Antes, a tela dizia que a tarefa rodava "quando o PC for ligado", mas ela roda só com você conectado.
- **A pergunta:** "Em que dia do mês?" com **Dia 1**, **Dia 15**, **Dia 28** e **Voltar**; com a tarefa criada, "Trocar o dia ou remover?". Sem o título "Situação" e sem a mesma descrição repetida em cada dia.
- **Agendador sem resposta:** com o Agendador de Tarefas parado ou recusando a consulta, a tela diz "não foi possível consultar o Agendador de Tarefas", e não mais "Não agendada".

**O que acontece no Windows**
- **A janela da tarefa no Windows 11:** com o Terminal do Windows como programa de console padrão (o normal no Windows 11 22H2 em diante), o `-WindowStyle Hidden` não esconde nada: a janela aparecia todo mês, e fechá-la parava a limpeza. No Windows 11, a tarefa nova abre o PowerShell pelo console sem janela (`conhost.exe --headless`). Uma tarefa criada antes continua como estava até o dia ser escolhido de novo.
- **Arquivos recuperados da cópia:** quando um arquivo de estado do WinForge (o diário de mudanças, o histórico, as preferências) estava estragado e a cópia anterior (`.bak`) era lida no lugar, o arquivo bom não voltava para o lugar. A leitura seguinte dizia "nunca rodou", e a gravação seguinte trocava a cópia boa pela vazia: desfazer uma mudança apagava as outras do diário. Agora a cópia volta para o lugar na hora, e só as três cópias estragadas mais novas ficam guardadas.
- **Leituras que falham:** com as preferências presas por outro programa, a última verificação não vira mais "nunca verificou"; o cartão diz "Não foi possível ler", e o monitor na bandeja não avisa "Hora de cuidar do PC" sem ter lido.
- **Restauração do Sistema:** recusar o aviso de Administrador dela (código 1223) não mostra mais "o recurso pode não existir nesta edição do Windows".

**O que não foi visto:** como nas builds anteriores, nada disto rodou num Windows de verdade. Pedem conferência num PC: a tarefa mensal criada no Windows 11 23H2 e 24H2 com o Terminal do Windows como padrão, rodando sem janela pelo `conhost.exe --headless` (e o Agendador mostrando o resultado dela), e no Windows 10 como antes; o `Checkpoint-Computer` com a Proteção do Sistema desligada devolvendo o código 0x80070422 num Windows em português; a política `DisableSR` e `DisableConfig` em `HKLM\SOFTWARE\Policies\Microsoft\Windows NT\SystemRestore`; o ponto que o Windows não renova com o mais novo de dias atrás; recusar o aviso de Administrador da Restauração do Sistema; o `Get-ScheduledTask` com o serviço Agendador de Tarefas parado e sem permissão; o cartão Última manutenção no alto da página e as duas seções em 900 x 600, 1180 x 760, 1366 x 768 com escala de 125% e 1920 x 1080, nos dois temas; e o Narrador lendo os cartões com a nota.

A lista da 3.31 do que pede conferência continua valendo.

### Estrutura
- **Navigation.psm1:** `-Unlisted` em `New-WinForgeNavItem` (a propriedade `Unlisted`); a Manutenção com as seções "Cuidar do PC" e "Se algo der errado", descrições novas e o histórico e o Agendador fora da grade.
- **Core.psm1:** `Read-WinForgeStateFile` devolve a cópia `.bak` ao lugar e chama `Remove-WinForgeOldCorruptCopies`; `Get-WinForgeLastCheckup -Strict` (uma leitura só das preferências); `Format-WinForgeRelativeTime` com "com data no futuro"; `[void](...)` no lugar de `| Out-Null` (também em Backup, Tweaks, Agent, AppUpdate, NetworkTools e Reports).
- **Home.psm1:** `Get-WinForgeLastCare -Strict` vale também para a verificação, com `CheckupInFuture`; `Read-WinForgeHomeMaintenance -Now`. **Agent.psm1:** o lembrete da manutenção com `-Strict`.
- **Maintenance.psm1:** sem `Get-WinForgeMaintenancePageStatus`; `Write-WinForgeLastMaintenanceSteps` no começo de `Show-WinForgeMaintenanceHistory`, que devolve o resultado nas falhas.
- **Checkup.psm1:** as etapas `disk` (`Get-WinForgeCheckupDisk`) e `updates` (em `Get-WinForgeCheckupWindows`); sem a correção `memory`; o registro desmarcado; `Set-WinForgeCheckupView`.
- **Tweaks.psm1:** `Get-WinForgeRestorePolicy` e `Test-WinForgeRestoreProtectionOffError`; `New-WinForgeRestorePoint` sem o "já havia um ponto recente" para pontos de mais de um dia; `Invoke-WinForgeRestorePoint` com o título da faixa.
- **Journal.psm1:** recurso e DNS sem Administrador recusados antes de tentar; a tela com as duas listas sem repetição. **NetworkTools.psm1:** `Restore-WinForgeDnsFromBackup` confere os endereços.
- **Schedule.psm1:** `Get-WinForgeScheduleCommand -Build -SystemRoot` (o `conhost.exe --headless`); `QueryFailed` em `Get-WinForgeScheduleStatus`; a tela nova.
- **Shortcuts.psm1:** `Test-WinForgeUserCancelled` e `Get-WinForgeShortcutLastError`. **GuiDesign.psm1:** o ícone `flag`.
- **WinForge.Gui.ps1:** `New-GuiMaintenanceFact` e `Set-GuiFactCardText` (o preenchimento de `Set-GuiHomeFact`, agora reaproveitado); os itens `Unlisted` fora da grade; o nome dos cartões para o leitor de tela; `Set-GuiPromptContext` só com mensagens depois de uma lista longa; a atividade do andamento no alto da execução; "Executar de novo" escondido nos dois históricos sem veredito; o aviso de Administrador recusado num atalho sem mensagem.

## Build 3.55

Esta build revisa o **Início** de ponta a ponta: o desenho da tela em vários tamanhos de janela, o código da leitura do PC e o que cada ponto da nota de saúde pede ao Windows. A tela fica mais limpa, com um botão principal só, e a nota passa a acusar o que antes passava em branco: um Windows sem as atualizações de segurança do mês e um disco grande demais para a regra dos 10%.
- **Um caminho claro:** o botão do primeiro ponto de atenção é o principal da tela; sem pontos, o principal é o **Otimizar**.
- **Atualizações atrasadas:** um Windows parado numa atualização mensal antiga vira ponto grave, com o botão **Atualizar**.
- **Disco pelo que o Windows precisa:** pouco espaço é menos de 20 GB livres, e quase cheio, menos de 10 GB, em qualquer tamanho de disco.
- **Direto ao assunto:** antivírus, tempo real e firewall desligados abrem a Segurança do Windows na página certa.
- **Menos coisa na tela:** sem a frase embaixo do título, sem o rótulo "SAÚDE DO PC" e sem os cartões Computador e Manutenção agendada.
- **Cartões do tamanho da janela:** a grade cresce até preencher a linha, em todas as páginas.

### Mudou para quem usa

**A tela do Início**
- **A nota:** a hora da leitura ("Atualizado às 14:20") fica logo abaixo da frase grande, com o botão de ler de novo só com o ícone (**F5** continua valendo). Saíram a frase "Como está o seu PC e por onde começar" e o rótulo "SAÚDE DO PC", que repetiam o que a página já mostra. O trilho do anel tem um tom claro da cor da nota (com nota baixa, o anel quase vazio continua vermelho, e não cinza de desligado).
- **Um botão principal só:** com pontos de atenção, o botão do primeiro (o mais pesado) é o principal, e o **Otimizar** fica comum; sem pontos, o **Otimizar** é o principal. Com os pontos à vista, a frase embaixo da nota não os conta de novo ("2 pontos pedem atenção"); ela fica só com o que não pôde ser lido.
- **Os pontos:** um ponto grave tem o círculo vermelho, e não o mesmo triângulo dos leves. Os botões ficaram curtos: **Segurança do Windows**, **Liberar espaço**, **Atualizar**, **Verificar o PC** (antes "Verificar agora", que não dizia o quê).
- **Os cartões:** saíram **Computador** (o nome e o tipo do PC estão em **Sobre este PC**, que entrou em **Por onde começar**) e **Manutenção agendada** (opcional: só aparece quando existe e não está rodando, como ponto leve). O cartão **Windows** mostra o Windows e a versão ("Windows 11 24H2"); a edição fica na frase inteira, ao passar o mouse. Com dois ou mais outros antivírus, o cartão Proteção mostra o primeiro e quantos mais ("Kaspersky Total Security +1"); a frase inteira, ao passar o mouse e no leitor de tela, traz todos. A segunda linha da última manutenção ficou mais curta ("verificado há 45 minutos"), e não termina mais em "...".
- **Por onde começar:** **Verificar o PC**, **Limpeza rápida**, **Instalar atualizações do Windows** e **Sobre este PC**. O **Acelerar agora** saiu do Início (continua na página Desempenho): os mesmos ajustes estão no Otimizar, e um atalho de "acelerar" na primeira tela prometia mais do que ele entrega num PC comum.
- **Verificar vírus** aparece só quando o Windows Defender é quem protege o PC: sai também com o Defender desligado, em modo passivo ou sem resposta (a verificação falharia, e o ponto da nota já leva à Segurança do Windows). Quem protege fica guardado para a próxima abertura: o botão não aparece mais por alguns segundos para sumir quando a leitura termina.
- **Leitura:** "Lendo o PC..." e "Atualizando...", sem a contagem de etapas ("2 de 7"), que não batia com os cartões. Uma falha no meio da leitura não deixa mais o Início preso em "Lendo" com o botão de ler de novo desligado: a hora diz "A leitura não terminou". Trocar o tema depois de uma leitura cuja nota não pôde ser calculada não lê o PC de novo.
- **Leitor de tela:** a frase da nota é lida quando a leitura termina, e os cartões dizem "lendo" enquanto esperam.
- **O aviso da conta diferente** ficou mais curto ("O WinForge foi aberto com a conta admin, não com a que está em uso: a limpeza e os ajustes do Windows valem só para ela."), e sem o nome da conta não fica mais com um buraco ("conta , e não").

**A nota de saúde**
- **Atualizações atrasadas:** com o Windows ainda no suporte, a nota confere a revisão da build instalada (o "7807" de 19045.7807) contra a da atualização de segurança de outubro de 2026, guardada no catálogo. Sem ela, 35 dias depois (o máximo que o Windows Update deixa pausar), "Faltam atualizações de segurança do Windows" é um ponto grave, com o botão **Atualizar**, e o cartão Windows diz "atualizações atrasadas". Vale também para o Windows 10 no ESU, que antes contava como protegido só por ter instalado uma atualização do programa.
- **Disco:** pouco espaço é menos de 20 GB livres no disco do Windows, e quase cheio, menos de 10 GB (antes, menos de 10% e menos de 5 GB). Os 10% acusavam um disco de 2 TB com 150 GB livres e deixavam passar um de 64 GB com 7 GB livres, pouco para uma atualização de versão. O botão **Liberar espaço** abre a **Limpeza personalizada**, que mostra o tamanho de cada coisa e solta mais que a Limpeza rápida. Um espaço livre que não é número aparece como leitura que falhou, e não como "0 B livres" num cartão tranquilo.
- **Proteção:** antivírus desligado, tempo real desligado e ameaça ativa abrem a página **Proteção contra vírus e ameaças**; o firewall desligado abre **Firewall e proteção de rede**. Antes, os quatro abriam a primeira página da Segurança do Windows. Um antivírus que não responde não é mais ponto de atenção ("Não foi possível confirmar se há um antivírus ativo"): a nota diz que a proteção ficou sem leitura, e o cartão, "Leitura incompleta". Assinaturas que nunca foram atualizadas viram "O antivírus nunca foi atualizado", com o botão **Atualizar**; as velhas, "O antivírus não é atualizado há 12 dias".
- **Um ponto achado vale:** com o antivírus desligado numa proteção lida pela metade e o resto sem resposta, a tela mostrava "Não foi possível avaliar o PC" e escondia o ponto grave (a verificação rápida o mostrava). Agora a tela mostra a nota e o ponto.
- **Suporte do Windows sem leitura:** quando a leitura do Windows falha ou passa do tempo, a nota diz "Não foi possível ler: Suporte do Windows", como quando só o suporte falha; antes, ela ficava "Ótima" em verde.
- **Resumo:** com algo sem leitura e um ponto leve, o resumo dizia "1 ponto pede atenção." embaixo de "Seu PC parece bem"; agora diz "1 detalhe para quando puder.".
- **Manutenção:** a última manutenção com etapas pedindo atenção leva ao histórico (**Ver**), onde está o motivo de cada uma, e não mais a refazer a manutenção inteira. O registro da manutenção que existe, mas não abre (preso por outro programa), aparece como "Não foi possível ler", e não como "nunca feita" pedindo uma verificação. A data registrada depois da data de hoje diz só que as duas não batem ("confira o relógio"), sem afirmar qual está errada.
- **Manutenção agendada:** desligada no Agendador de Tarefas, usando um WinForge de outra pasta ou com a última execução falha, é um ponto leve (peso 3) com o botão **Ver**, que abre a tela do agendamento.

**O que acontece no Windows**
- **Quem está usando o PC:** o WinForge pergunta ao Windows o dono do Explorador da sessão em que ele roda, e só sem isso usa quem está no console. Antes, pela Área de Trabalho Remota, a conta de quem estava na frente do monitor (ou ninguém) aparecia como "a que está usando o PC", e o aviso da conta diferente saía errado.
- **Sem o WMI:** a build do Windows vem do Registro quando o WMI não responde; antes, ela ficava em 0, e o suporte do Windows não era conferido.
- **Bateria:** o cartão só aparece em notebooks. Num desktop com nobreak ligado pelo USB, que o Windows mostra como bateria, ele aparecia.
- **Leitura em segundo plano:** o limite de 45 segundos por etapa conta pelo cronômetro, e não pelo relógio do Windows (um acerto da hora no meio não encerra a etapa antes do tempo nem a deixa presa). Um leitor que roda, mas termina sem resultado (os módulos não carregaram nele), é descartado, e a etapa roda na janela, em vez de todos os cartões dizerem "Não foi possível ler".

**Outras telas**
- **A grade dos cartões** cresce com a janela (cada cartão de 252 a 300 de largura) até preencher a linha, em todas as páginas; antes, ficava uma faixa vazia à direita do tamanho de quase um cartão. A faixa da ação em andamento termina onde terminam os cartões, e a tela de execução vai até a largura de quatro deles.
- **Botões comuns** têm o contorno mais escuro (contraste acima de 3:1 nos dois temas): o claro fazia o botão parecer desligado.
- **Diagnóstico > Discos e espaço livre**, a **Limpeza** e o **monitor na bandeja** usam os mesmos limites novos de espaço no disco do Windows; nas outras unidades continua a proporção (menos de 10% livres é pouco espaço, e menos de 5%, quase cheio).

**O que não foi visto:** como nas builds anteriores, nada disto rodou num Windows de verdade. Pedem conferência num PC: o `windowsdefender://network` abrindo a página Firewall e proteção de rede; a revisão da build (UBR) de um PC atualizado e de um parado em setembro de 2026, nas versões 19045, 22631 e 26100 (e um 24H2 Enterprise com hotpatch); o dono do Explorador pela Área de Trabalho Remota, com outra pessoa no console; a build pelo Registro com o serviço WMI parado; o `AntivirusSignatureAge` em 65535 num Defender recém-instalado; um desktop com nobreak USB; a grade dos cartões em 900 x 600, 1366 x 768 com escala de 125% e numa janela maximizada em 1920 x 1080, nos dois temas; o contorno novo dos botões no tema escuro; e o leitor de tela (Narrador) lendo a frase da nota ao fim da leitura.

A lista da 3.31 do que pede conferência continua valendo.

### Estrutura
- **Home.psm1:** sem os fatos `computer` e `schedule` (`Read-WinForgeHomeSchedule` devolve só o ponto); `Get-WinForgeHomeWindowsShortName`; o ponto `updates` (`Get-WinForgeWindowsUpdateLag`) e `$script:WinForgeHomeSupportLabel` no que fica sem leitura quando a sessão falha (também em `New-WinForgeHomeStepFailure`); `Get-WinForgeHomeAntivirusText -Full`; a proteção `Unavailable` sem ponto (só `Unread`); os destinos `WindowsSecurityThreats` e `WindowsSecurityFirewall`; `Get-WinForgeLastCare -Strict`; `Get-WinForgeHealthSummary -WithoutCount` e a frase pela nota, e não pela cor; `Test-WinForgeHealthKnown` com os pontos achados; os atalhos sem `performance.boost` e com `diagnostics.about`.
- **Core.psm1:** `Get-WinForgeDiskSpaceLevel` com 10 GB e 20 GB no disco do Windows (`$script:WinForgeCriticalDiskBytes`); `Get-WinForgeSessionShellUser` antes do console em `Get-WinForgeInteractiveUser`; `Get-WinForgeRegistryWindowsBuild` em `Get-WinForgeSessionInfo` e `Get-WinForgeWindowsBuild`; `Get-WinForgeLastMaintenance -Strict`.
- **WindowsSupport.psm1 e Catalog.psm1:** `Get-WinForgeWindowsUpdateLag`; `UpdateRevision` e `UpdateDate` no ciclo de vida (embutido, `catalog/catalog.json` e a conferência do baixado, que aceita o catálogo antigo sem eles); catálogo de 13/11/2026.
- **Security.psm1:** `SignaturesNeverUpdated` em `Get-WinForgeAntivirusStatus`. **Shortcuts.psm1:** `WindowsSecurityFirewall`. **GuiHost.psm1:** `Watch` no leitor e `Get-WinForgeGuiReadSeconds`. **GuiDesign.psm1:** `ButtonLine` mais escuro.
- **WinForge.Gui.ps1 e MainWindow.xaml:** os recursos `CardWidth` e `WideCardWidth`, `Get-GuiCardGrid` e `Set-GuiCardWidth`; o subtítulo que some sem texto; `Update-GuiHealthCard` sem o rótulo, com a hora embaixo da frase (`$script:HomeHeadline`) e o botão principal no primeiro ponto (`New-GuiHealthButtons -Primary`); `Invoke-GuiNextStep` (o botão da faixa de resultado e os dos pontos); `Get-GuiSavedAntivirusMode` e `Save-GuiAntivirusMode`; `Stop-GuiHomeRead`; a leitura guardada mesmo quando a nota falha (`Failed`).

## Build 3.54

Esta build revisa o **Verificar vírus** de ponta a ponta: o desenho da tela, o código por trás dela e o que ele pede ao Windows Defender. O resultado passa a dizer o que importa, e as ameaças que pedem ação ficam em vermelho, com o botão para resolvê-las. A atualização do antivírus tem um segundo caminho quando o Windows Update falha, e o WinForge confere se a verificação chegou ao fim.
- **Resultado claro:** "Nenhum vírus encontrado", "2 ameaças resolvidas" ou, em vermelho, "3 ameaças pedem ação", com o botão **Abrir a Segurança do Windows** em destaque.
- **Nenhuma ameaça escondida:** as de antes que ainda estão ativas aparecem mesmo quando a verificação acha outras.
- **Antivírus atualizado de verdade:** se o Windows Update falha, o WinForge tenta direto da Microsoft.
- **Verificação até o fim:** sem o registro do fim no Defender, a tela diz que ela pode ter parado antes.
- **Sem botão à toa:** com outro antivírus protegendo o PC, Verificar vírus sai do Início e as ações do Defender saem da página Segurança.
- **Uma verificação rápida só:** o cartão "Verificação rápida de vírus" saiu; o Verificar vírus faz a mesma verificação, com o antivírus atualizado antes.

### Mudou para quem usa

**A tela do Verificar vírus**
- **Enquanto roda:** a frase em destaque diz a fase (**Atualização do antivírus**, depois **Verificação rápida**), e a linha de baixo diz quanto a verificação costuma levar: o tempo da última verificação rápida deste PC, quando o Windows diz, ou "de 2 a 15 minutos". A linha "Leva de 2 a 15 minutos." não fica mais no resumo depois do fim.
- **O resultado:** a faixa tem título próprio. Nada encontrado com o antivírus atualizado é "Nenhum vírus encontrado", sem lista embaixo (os detalhes técnicos continuam à mão). Ameaças já resolvidas pelo Defender são verde ("1 ameaça resolvida"). Ameaças que pedem ação são vermelho ("3 ameaças pedem ação"), também no botão da barra de tarefas, com o botão **Abrir a Segurança do Windows**, que abre direto a página Proteção contra vírus e ameaças e recebe o foco do teclado; o Voltar fica discreto e o "Executar de novo" sai, porque rodar de novo não resolve nada. Quando todas as pendentes só esperam a verificação completa, o botão é **Fazer a verificação completa**. A lista abre no começo da verificação, e não no fim (numa janela baixa, a primeira ameaça ficava cortada).
- **As ameaças:** uma linha curta por ameaça, com o nome legível, o que o Defender fez e o arquivo ("Wacatac (trojan) · não resolvida · setup.exe e mais 2"). A resolvida tem o ícone de feito, e não mais o de atenção. O nome completo do Defender e os caminhos inteiros ficam nos detalhes técnicos. Acabaram os parênteses dentro de parênteses e a linha "Verificação concluída: N ameaças encontradas", que repetia a faixa. Com uma ameaça só, "Escolha o que fazer com ela", e não mais "com cada uma".
- **Antivírus desligado** é vermelho ("Antivírus desligado"), e não mais "Concluído com ressalvas". **Modo passivo** sem outro antivírus e **Defender sem resposta** são ressalva amarela, e não mais "Nada a fazer" em cinza; no Otimizar, eles também deixam de passar como "Ignorado". As três faixas trazem o botão para a Segurança do Windows. Com o Defender desligado e sem conseguir consultar a Central de Segurança, a tela não diz mais que o Defender "não respondeu". Com dois ou mais antivírus, "Outros antivírus protegem este PC (Avast e Norton 360): use um deles".
- **Sem internet:** "O antivírus não foi atualizado: o PC não encontrou o servidor, sem internet ou sem DNS (erro 0x80072EE7)", sem os dois-pontos em sequência. Com nada encontrado, a faixa fica amarela, "Nenhum vírus encontrado", e diz que o antivírus não foi atualizado; com a verificação também falhando, ela diz "A verificação não foi concluída", o motivo e que o antivírus também não foi atualizado. O aviso "confira a conexão com a internet" só aparece quando o erro é mesmo de conexão (um acesso negado sem código não o mostra mais).
- **Parar:** "Verificação cancelada" quando o Defender aceita cancelar; senão, a tela diz que ele pode continuar até o fim. Na verificação de uma pasta, que não tem como ser cancelada por fora, a tela diz isso, em vez de "Verificação interrompida".

**O que acontece no Windows**
- **Atualização:** quando o `Update-MpSignature` falha (o Windows Update desligado por um programa de "otimização", com defeito, ou um servidor da empresa sem a atualização do Defender aprovada) ou termina com as assinaturas ainda com mais de 3 dias, o WinForge tenta de novo direto da Microsoft (`-UpdateSource MMPC`), como o próprio Defender só faria depois de 7 dias. Uma política da empresa que tirou essa fonte da lista é respeitada.
- **O que a verificação achou:** antes de começar, o WinForge anota as detecções que o Defender já tinha; depois, só o que é novo conta como achado. Antes, valia o relógio, com um minuto de folga: uma detecção de segundos antes (a da execução anterior, ou da proteção em tempo real durante a atualização) contava como desta, e um ajuste da hora no meio podia esconder uma de verdade.
- **Ameaças de antes ainda ativas** aparecem sempre. Antes, só quando a verificação não achava nada: uma ameaça nova já resolvida escondia uma antiga ainda ativa.
- **O fim da verificação:** depois da rápida (ou da completa), o WinForge confere no Defender o registro do fim. Sem ele (a verificação cancelada por fora, por exemplo), a faixa diz "A verificação pode ter parado antes do fim", em vez de "Nenhum vírus encontrado".
- **O que o Defender ainda pede ao PC** (reiniciar, a verificação completa, a offline ou uma ação sua) aparece na linha da ameaça e, quando é do PC inteiro, na faixa.
- **Verificação já em andamento** (a agendada do Windows, ou uma aberta na Segurança do Windows): ressalva, "Já havia uma verificação em andamento", e não mais erro vermelho.
- **O PC não suspende** no meio da verificação rápida também (antes, só na completa e na de uma pasta).
- **Fechar a janela** logo depois do Parar não mata mais o pedido de cancelamento ao Defender (`MpCmdRun -Scan -Cancel`), que deixaria uma verificação completa rodando por horas.
- **Erros em português:** entram proxy pedindo senha, servidor sobrecarregado, conexão segura com a data e a hora do PC erradas, Windows Update com erro, Defender desligado por política, acesso negado, verificação interrompida, falta de memória e Defender desatualizado. O texto de "acesso negado" não perde mais o ponto final.
- Os locais de uma detecção por comportamento ("behavior:_pid:...") aparecem como "programa em execução (processo 5524)".

**Início e página Segurança**
- O botão **Verificar vírus** do Início sai quando a leitura do Início vê outro antivírus protegendo o PC; na página **Segurança**, saem também as ações do Defender (Atualizar assinaturas, Verificar vírus, a verificação completa e a de uma pasta). Ficam o estado, a auditoria e o aplicativo Segurança do Windows.
- O cartão **Verificação rápida de vírus** saiu da página Segurança (e do menu de texto): ele fazia o mesmo que o Verificar vírus, sem atualizar o antivírus antes. A busca por "verificação rápida", "malware", "trojan" ou "scan" leva ao Verificar vírus.
- Verificar vírus tem o mesmo ícone, a lupa, no Início e na página Segurança.

**Outras telas**
- **Executar de novo** não aparece mais depois de "Nada a fazer" (outro antivírus no lugar, nada para limpar), quando rodar de novo daria o mesmo; depois de "Cancelado", continua.
- A barra sem porcentagem corre no mesmo ritmo e fica à vista o mesmo tempo em qualquer largura de janela (antes, numa janela estreita, a faixa passava mais da metade do tempo fora da barra).
- No Otimizar, quando a etapa não informa porcentagem (a verificação de vírus, a busca do Windows Update), a faixa corre por cima da barra da execução inteira, que antes ficava parada por minutos.

**O que não foi visto:** como nas builds anteriores, nada disto rodou num Windows de verdade. Pedem conferência num PC: a atualização direto da Microsoft com o Windows Update desligado (o serviço desativado) e com um servidor WSUS; o registro do fim da verificação rápida (`QuickScanEndTime`) logo depois do `Start-MpScan`, e a verificação cancelada pela Segurança do Windows no meio; a mensagem do Windows em português para "verificação já em andamento" (o WinForge reconhece a frase em inglês e uma tradução provável); o `windowsdefender://threat` abrindo a página Proteção contra vírus e ameaças; os bits de `ComputerState` e `AdditionalActionsBitMask` com uma ameaça que pede reinício (o arquivo EICAR não pede); a faixa com o botão em 900 x 600, em 1366 x 768 com escala de 125% e no tema escuro; a barra sem porcentagem e a faixa por cima da barra do Otimizar; o Início e a página Segurança com outro antivírus instalado (Avast, Kaspersky); e o Parar seguido de fechar a janela no meio de uma verificação completa.

A lista da 3.31 do que pede conferência continua valendo.

### Estrutura
- **Security.psm1:** `Test-WinForgeDefenderReady` devolve o resultado com a faixa (Off falha; Passive e Unavailable ressalva; `DefenderRead` separa os dois Unavailable); `Invoke-WinForgeSignatureUpdate` com a segunda tentativa (`Test-WinForgeMmpcFallback`) e `Data.Caveat`; `Get-WinForgeDetectionIds` e `Get-WinForgeScanDetections -Known` (Found e Leftover); `Get-WinForgeScanFinish`, `Get-WinForgeDefenderNeeds` e `Get-WinForgeDefenderNeedText`; `Get-WinForgeScanOutcome`, `Write-WinForgeThreatLine` e `Get-WinForgeThreatShortName`; `ConvertTo-WinForgeScanFailure` e `Write-WinForgeScanStopped`; `Get-WinForgeDefenderErrorInfo`; `Join-WinForgeSecurityCheckResult`.
- **Console.psm1:** `Set-WinForgeResultView` (Headline, Note, Tone, Next, NextLabel e HideSummary em Data), lidos por `Set-WinForgeOutcome` e devolvidos por `Get-WinForgeOutcome`.
- **GuiHost.psm1:** `Get-WinForgeRunView` com o título, a cor e o próximo passo do resultado; `Get-WinForgeResultSentence` com a Note; `MpCmdRun.exe` fora de `Get-WinForgeDescendantProcesses`.
- **WinForge.Gui.ps1 e MainWindow.xaml:** `ResultAction` na faixa de resultado e `Invoke-GuiResultAction`; o resumo escondido com `HideSummary`; `$script:AntivirusMode` (da leitura do Início) no Início e na página Segurança; a faixa da barra pela origem relativa da escala, e `Tag="busy"` na barra do Otimizar.
- **Navigation.psm1:** sem `security.quick-scan`. **Shortcuts.psm1:** `WindowsSecurityThreats`. **Home.psm1:** `AntivirusMode` no cartão Proteção.

## Build 3.53

Esta build revisa a tela do **Otimizar** de ponta a ponta: o desenho, o código por trás dela e o que cada etapa faz no Windows. A pergunta ganha o espaço da tela, a etapa e o andamento ficam sempre à vista, e várias etapas ficam mais seguras.
- **Perguntas com espaço:** a lista de uma pergunta fica com pelo menos 40% da tela; o resumo, o cartão do andamento e a saída dos detalhes técnicos cedem antes, e o que a etapa disse sobre a pergunta vai para dentro dela.
- **Onde você está:** "Etapa N de 22" não é mais trocada por títulos do meio da etapa, e a barra mostra o Otimizar inteiro, sem voltar a zero.
- **Lixeira:** a limpeza vem antes dos atalhos e dos restos de programas, e esvaziar a Lixeira nunca apaga de vez o que o Otimizar acabou de mandar para lá.
- **Ponto de restauração sempre novo**, e sem ele o Otimizar pergunta se continua.
- **Parar de verdade:** o que a ação abriu (o DismHost do DISM, o instalador do winget) também para.
- **Log de verdade na janela:** o log da sessão tem cada linha das ações, com a hora.
- **Rede:** com VPN ou Área de Trabalho Remota, o Otimizar só limpa o DNS.
- **Cancelar a parte automática** não conta mais como manutenção feita.

### Mudou para quem usa

**A tela do Otimizar**
- Com uma pergunta na tela, a lista (ou as opções em linha) fica com pelo menos 40% da altura; antes dela, encolhem a saída dos detalhes técnicos abertos e o resumo. Um resumo que ficaria com menos de três linhas some, e o cartão do andamento com ele: a etapa vai para o alto da pergunta, em letra pequena.
- As últimas linhas que a etapa escreveu (a pasta e o tamanho dela, o que deixa de abrir com o Windows, por que reiniciar) ficam dentro do cartão da pergunta, e não mais escondidas no alto de um resumo encolhido.
- A frase em destaque é sempre a etapa: títulos do meio dela ("Lixeira", "Reparar imagem e componentes (DISM)", "Reiniciar o PC") não a trocam mais. A barra de progresso e o botão na barra de tarefas mostram o Otimizar inteiro, e a porcentagem da ferramenta da vez fica no texto embaixo da etapa. Em outra página, a faixa de execução mostra a etapa. O leitor de tela lê cada etapa nova.
- **Botões:** um só destaque por pergunta (na pasta da revisão, "Limpar com o WinForge" e "Pular esta pasta" ficavam os dois em azul). "Fechou todos os programas?" e "Começar a parte automática?" respondem ao Enter com o botão em destaque, e não mais com Cancelar. Na Lixeira, **Esvaziar** e **Manter**; no fim, **Reiniciar agora** e **Depois**, sem botão azul quando o padrão é não.
- **Listas:** o botão diz o que faz e quantos ("Desinstalar (2)", "Remover (1)", "Atualizar (3)"). Nas revisões (inicialização e ajustes), ele conta as mudanças ("Aplicar (3)") e diz **Continuar** quando nada mudou, e desmarcar tudo passa a ser uma resposta (antes, o botão ficava desligado sem nada marcado). "Limpar" virou **Desmarcar tudo** e sai das revisões. Dentro do Otimizar, fechar uma lista é **Pular**; na lista do winget, **Voltar**. Do filtro, a seta para baixo leva à lista.
- **Parar** fica discreto (não mais vermelho) e continua com a confirmação. **Executar de novo** não aparece depois do Otimizar. **Copiar**, **Salvar** e **Abrir log** aparecem só com os detalhes técnicos abertos.
- No fim, o resumo usa a altura da janela e abre no "Resumo" das etapas. A faixa de resultado diz até duas etapas pelo nome e, com mais, a conta; o desfecho e a duração não se repetem mais no resumo, e uma frase longa demais é cortada num espaço, não no meio de uma palavra.
- A sugestão de fechar os programas vem numa linha só, com os abertos ("Salve seu trabalho e feche os programas abertos: Google Chrome e Microsoft Word."), e a lista passa a incluir os aplicativos da Microsoft Store abertos.

**O que as etapas fazem**
- **Ordem:** a limpeza rápida vem antes dos atalhos quebrados, dos restos de programas e do registro. Com "Esvaziar", os restos e os atalhos que o Otimizar manda para a Lixeira eram apagados de vez minutos depois. É a segunda troca na ordem pedida na 3.51.
- **Ponto de restauração:** sempre um novo no começo, mesmo com outro de poucas horas atrás (de uma atualização do Windows, por exemplo), que voltaria também o que mudou depois dele. Sem o ponto, o Otimizar pergunta se continua, com **Não** como padrão.
- **winget e navegadores:** no Otimizar, Edge, Chrome e Firefox saem da lista do winget, porque a etapa dos navegadores os atualiza. Antes, "Não atualizar" ou o Firefox desmarcado eram desfeitos por ela, e "Atualizar todos" os atualizava duas vezes. "Não atualizar" aparece no resumo como "nada mudou", e uma pergunta sem resposta é "não atualizar", e não uma falha do winget.
- **Rede:** com uma VPN ligada (do Windows ou de um programa) ou com o PC usado pela Área de Trabalho Remota, o reparo do Otimizar só limpa o DNS: liberar o IP derrubaria a conexão no meio da parte automática.
- **Componentes e DISM + SFC:** só ficam para depois quando a manutenção dos componentes do Windows espera o reinício; um driver ou um nome novo do PC esperando o reinício não os seguram mais.
- **Windows Update:** no Otimizar, a busca espera até 20 minutos (eram 5), para o primeiro Otimizar num PC que ficou meses sem atualizar.
- **Atualizações antecipadas:** com a política da empresa que controla o conteúdo opcional do Windows Update, a etapa diz isso e não muda nada.
- **CHKDSK:** a frase do fim não afirma mais que o disco tem erros, porque o código 3 do CHKDSK também é "não deu para verificar tudo com o Windows aberto".
- **Aplicativos do Windows:** Pessoas, Portal de Realidade Misturada, Visualizador 3D, Print 3D e Dev Home dizem que não voltam depois de removidos (saíram da Microsoft Store).
- **Parar e fechar a janela** param também o que a ação abriu e que continuava rodando escondido: o DismHost do DISM, o instalador que o winget abriu, o atualizador de um navegador.
- Reiniciar o Explorador no fim tem **Não** como padrão.

**Histórico e log**
- No fim da parte automática o resultado já fica gravado: se a janela fechar ou o PC reiniciar durante a revisão dos ajustes, a manutenção não se perde. O fim do Otimizar grava de novo, por cima da mesma execução.
- Cancelar a parte automática depois das telas com você não conta mais como manutenção: o resumo e a faixa dizem que ela foi cancelada, e o Início continua lembrando do Otimizar. Sem nada mudado antes, é só "Cancelado". Reiniciar antes de otimizar termina como "Reiniciando", e não "Nada a fazer".
- Na janela, o log da sessão (`%LOCALAPPDATA%\WinForge\logs`, botão Abrir log) passa a ter cada linha que as ações escrevem, com a hora; antes, o log das ações da janela ficava praticamente vazio.
- Durações: 59,6 segundos aparecem como "1min 00s", e não "60s". A última etapa que falha não diz mais que o WinForge "continuará para a próxima etapa", e tudo falhando termina em vermelho também no resumo do menu de texto.

**O que não foi visto:** como nas builds anteriores, nada disto rodou num Windows de verdade. Pedem conferência num PC: a tela do Otimizar em 1366 x 768 com escala de 125%, em 1920 x 1080 e maximizada, com uma lista longa, com os detalhes técnicos abertos e no tema escuro (o cartão do andamento saindo e voltando, a etapa no alto da pergunta, as linhas dentro do cartão); a barra do Otimizar inteiro na janela e na barra de tarefas; o Parar no meio do DISM e do winget (o DismHost e o instalador encerrados, e outra ação logo depois); a lista de programas abertos com aplicativos da Microsoft Store e com o Explorador aberto; o log da sessão da janela depois de um Otimizar inteiro; o reparo de rede com uma VPN ligada; e o ponto de restauração novo com outro de poucas horas atrás.

A lista da 3.31 do que pede conferência continua valendo.

### Estrutura
- **Maintenance.psm1:** a ordem do plano (`cleanup` antes de `shortcuts`, `leftovers` e `registry`); o ponto de restauração numa fase própria, com a pergunta quando o resultado traz `NotCreated`; `Set-WinForgeLastMaintenance` no fim da parte automática, com o `RunId` da execução; a parte automática cancelada com `Show-WinForgeMaintenanceSummary -NoRecord -Verdict`; `Get-WinForgeTopLevelWindows` (EnumWindows, com os aplicativos da Store pelo título) e `Get-WinForgeFrameAppName`; `Test-WinForgeServicingRebootPending` nos componentes e no reparo.
- **Core.psm1:** `Start-WinForgeLogging` grava pelo host da janela (`Get-WinForgeGuiHostUI`); `RunId` em `Set-WinForgeLastMaintenance` e no histórico, que substitui a entrada da mesma execução; `Format-WinForgeDuration` arredonda antes; sem o `chcp`.
- **GuiHost.psm1:** `GuiHostUI.OpenLog` e `CloseLog`; `ConfirmLabel` e `CancelLabel` nas listas; `Get-WinForgeDescendantProcesses` e `Stop-WinForgeChildTools` pela árvore de processos; `Get-WinForgePromptLayout -DetailsMinHeight`; um destaque por pergunta em `Get-WinForgePromptPlan`.
- **Console.psm1:** `Confirm-WinForgeAction -YesLabel -NoLabel`; `Read-WinForgeMultiSelect -AllowNone -ConfirmLabel -CancelLabel`.
- **WinForge.Gui.ps1 e MainWindow.xaml:** `PromptStep` e `PromptContext` no cartão da pergunta, `Set-GuiPromptContext`, `Restore-GuiAroundPrompt` e o novo `Update-GuiPromptFit`; `Update-GuiOverallProgress` com `Get-WinForgeOverallProgress` (GuiDesign.psm1); `DetailsActions`.
- **Network.psm1:** `Get-WinForgeNetworkHoldReason`. **Software.psm1:** `Get-WinForgeWingetUpgradePlan -SkipBrowsers` e `Test-WinForgeWingetBrowserId`. **Diagnostics.psm1:** `Test-WinForgeServicingRebootPending`.

## Build 3.52

Esta build deixa o **Otimizar** sempre inteiro, sem a lista do que fazer, e começa com a sugestão forte de fechar os programas. As telas ficam mais curtas, os botões das perguntas não somem mais em janelas pequenas, os navegadores Chrome e Firefox entram nas atualizações, e as telas de desinstalar e de inicialização só oferecem o que o WinForge consegue mudar de verdade.
- **Otimizar sempre completo:** sai a pergunta "Escolha o que o Otimizar deve fazer"; as 22 etapas rodam sempre, e cada uma decide sozinha se tem o que fazer.
- **Feche os programas:** antes de começar, o aviso e a lista dos programas abertos, pelo nome; "Já fechei" confere de novo.
- **Botões sempre à vista:** a lista de uma pergunta encolhe e rola dentro do cartão, e os botões ficam embaixo dela em qualquer tamanho de janela.
- **Menos texto:** uma linha por aviso, perguntas curtas, sem parágrafos de como funciona.
- **Navegadores:** Edge, Chrome e Firefox, os que estiverem instalados, numa etapa só.
- **Desinstalar e inicialização de verdade:** só aparece o que dá para remover ou desligar, e o resultado é conferido no Windows depois.
- **Ajustes novos:** Sensor de Armazenamento, sem os recentes e sem os anúncios no Explorador, sem os destaques da pesquisa e, no Windows 10, sem os aplicativos em segundo plano.

### Mudou para quem usa

**Otimizar**
- Não há mais lista para escolher as etapas: o Otimizar é sempre o inteiro, na mesma ordem da 3.51 (com os navegadores no lugar do Edge).
- O começo é a sugestão forte de fechar os programas: "Salve seu trabalho e feche todos os programas antes de otimizar", com "Abertos agora:" e os nomes (até seis, e quantos mais). "Já fechei, começar" confere de novo; com algo ainda aberto, a tela diz o quê e oferece verificar de novo, começar assim mesmo ou cancelar. O próprio WinForge, o terminal que o abriu e as partes do Windows que sempre têm janela não entram na lista.
- A confirmação da parte automática é um clique em **Começar** (no menu de texto, S), sem a palavra WINFORGE.
- Saem o parágrafo "Como funciona", as orientações antes das telas com você, a pergunta do relatório no fim (ele continua em Diagnóstico > Exportar relatório), a linha "Otimização finalizada" e o caminho do log no resumo (ele fica no botão Abrir log). Os avisos de reinício pendente, bateria, pouco espaço e outra conta viram uma linha cada.
- **Atualizar os navegadores** substitui a etapa do Edge: o Edge pelo atualizador dele; o Chrome instalado para todos pelo atualizador do Google; o Firefox pelo instalador da Mozilla, que o winget baixa e roda em silêncio no mesmo idioma. Uma linha por navegador instalado ("Google Chrome: atualizado para 141.0", "já na versão mais nova"); ficam de fora, dizendo por quê, o Chrome de um usuário só, a atualização desligada por política, o Firefox ESR e o Firefox aberto.
- O Windows Update mostra numa linha só o que ficou de fora (a versão nova do Windows, o firmware opcional, as prévias) e não lista mais cada atualização antes de instalar: os nomes aparecem uma vez, entre as instaladas.

**Janela**
- O cartão da pergunta fica limitado ao espaço que sobra na tela: a lista (ou as opções em linha) encolhe e rola dentro dele, e os botões de resposta, a caixa de texto e o filtro ficam sempre inteiros. Quando a lista ficaria apertada, o resumo acima encolhe antes, até sumir se preciso. Vale para todas as perguntas, ao abrir, ao mudar o tamanho da janela e ao abrir os detalhes técnicos.

**Desinstalar programas e Remover aplicativos do Windows**
- A lista só oferece o que o WinForge consegue remover de verdade. Os programas de ID longo, que o winget cortava na tabela e por isso sempre falhavam, aparecem agora com o ID completo (lido do registro, dos aplicativos instalados ou numa consulta curta ao winget); o que continua sem ID fica de fora. Também ficam de fora entradas sem desinstalador (ou com ele apagado do disco), as que o fabricante travou, atualizações de outro programa, componentes do Windows (bibliotecas do Visual C++ e do .NET, WebView2, o Edge e o atualizador dele, codecs, componentes do Xbox, pacotes de idioma) e os aplicativos de fábrica protegidos (Calculadora, Fotos, Bloco de Notas, Paint, Ferramenta de Captura, Terminal).
- Desinstalado só quando sumiu: depois do desinstalador, o WinForge lê a lista de novo; se o programa continua lá, confere outra vez em alguns segundos e, se ainda estiver, pergunta se confere de novo (o desinstalador pode estar com a janela dele aberta). Cada programa termina como desinstalado, termina na próxima reinicialização, continua instalado ou com o motivo do erro, e só o que saiu de verdade vai para o Histórico e para a busca de restos.
- Duas versões do mesmo programa viram uma opção só, desinstaladas juntas.
- Remover aplicativos do Windows confere do mesmo jeito, aplicativo por aplicativo.
- Menos texto: sem as linhas antes da lista; Listar programas instalados mostra só o total e as atualizações.

**Inicialização**
- Entram os aplicativos da Microsoft Store que abrem com o Windows (Teams, Spotify, WhatsApp), desligados e religados como no Gerenciador de Tarefas e desfeitos pelo Histórico de mudanças. Ficam de fora os controlados por política e os de aplicativos já desinstalados.
- Saem da lista as entradas que apontam para um arquivo que não existe mais, as tarefas agendadas de outras contas ou com o gatilho de entrada desligado e as tarefas de atualização que também rodam todo dia (desligá-las pararia as atualizações). Os itens de todos os usuários só aparecem com o WinForge como Administrador, e a tela diz quantos ficaram de fora.
- Cada mudança é lida de volta no Windows antes de contar como feita.
- Menos texto: cada item mostra só o fabricante (ou o arquivo) e "todos os usuários" quando vale.

**Ajustes do Windows**
- Novos: **Não mostrar os recentes no Explorador** (os arquivos usados há pouco e as pastas mais usadas), **Desativar os anúncios no Explorador** (os avisos do OneDrive e do Microsoft 365), **Desativar os destaques da pesquisa**, **Ativar o Sensor de Armazenamento** (com o disco cheio, o Windows apaga temporários e o que está há mais de 30 dias na Lixeira) e, só no Windows 10, **Desativar os aplicativos em segundo plano**. Os cinco entram também na revisão dos ajustes do fim do Otimizar, que já tinha todos os ajustes das duas páginas (menos os segundos no relógio e o agendamento de GPU).

**Menos texto nas outras telas**
- Cerca de 180 mensagens ficaram mais curtas ou saíram, em Reparo, Segurança, Limpeza, Rede, Atualizações, Desempenho, Agendamento, Backup e nas demais telas: uma linha de introdução no lugar dos parágrafos, e o porquê de cada coisa só no código. Continuam inteiros os avisos de segurança: o reparo do disco na reinicialização e o disco que pode estar falhando, a atualização de firmware, o DNS público bloqueado, o antivírus em modo passivo, a redefinição de rede com VPN, as senhas do Wi-Fi em texto e as cópias antes de formatar.

**O que não foi visto:** como nas builds anteriores, nada disto rodou num Windows de verdade. Pedem conferência num PC: a janela pequena (1366 x 768 com escala de 125%) numa lista longa, com os botões da pergunta à vista; a lista dos programas abertos contra o que a barra de tarefas mostra; o Chrome e o Firefox sendo atualizados (abertos e fechados) e o Firefox em outro idioma; a desinstalação de um programa cujo desinstalador abre a própria janela, e a conferência depois dela; os aplicativos da Microsoft Store na inicialização, desligados e religados, contra o Gerenciador de Tarefas; e os cinco ajustes novos contra as telas do Windows.

A lista da 3.31 do que pede conferência continua valendo.

### Estrutura
- **Maintenance.psm1:** sem `Read-WinForgeMaintenancePlan` e sem as orientações (`Hint`) do plano; `Get-WinForgeOpenPrograms`, `Format-WinForgeOpenPrograms` e `Confirm-WinForgeProgramsClosed`; `Confirm-WinForgeAutomaticPhase` sem parâmetros; o fim sem o relatório.
- **Software.psm1:** `Update-WinForgeBrowsers` (com `Update-WinForgeEdgeBrowser`, `Update-WinForgeChromeBrowser`, `Update-WinForgeFirefoxBrowser`, `Get-WinForgeChromeInstall`, `Get-WinForgeGoogleUpdaterCommand`, `Get-WinForgeFirefoxInstall`, `Get-WinForgeFirefoxPackageId` e `Get-WinForgeBrowserOutcome`) no lugar de `Update-WinForgeEdge`. A desinstalação usa `Get-WinForgeUninstallCandidates`, `Test-WinForgeWingetUninstallBlocked` e `Wait-WinForgeUninstallResults`; **PreinstalledApps.psm1**, `Get-WinForgeCheckedAppResults`.
- **GuiHost.psm1:** `Get-WinForgePromptLayout` no lugar de `Get-WinForgePromptFit`. **MainWindow.xaml:** o cartão da pergunta é uma grade com a linha da lista em "*". **WinForge.Gui.ps1:** `Update-GuiPromptFit` limita a altura do cartão.
- **Tweaks.psm1:** os ajustes `explorer-recent`, `explorer-sync-ads`, `search-highlights`, `storage-sense` e `background-apps`.
- **Startup.psm1 e Diagnostics.psm1:** os aplicativos da Store na inicialização (`Get-WinForgeStartupPackagedApps` e `Get-WinForgeStartupAppStates`), `Test-WinForgeStartupTargetMissing` e a conferência de cada mudança. **Journal.psm1:** o desfazer aceita os aplicativos da Store.
- Nos demais módulos, só os textos mudaram: a lógica, as respostas padrão e os resultados ficaram como estavam.

## Build 3.51

Esta build troca os botões do Início por **Otimizar** e **Verificar vírus**, e a Manutenção recomendada vira o **Otimizar**: sempre a manutenção mais completa, na ordem pedida, com as telas do WinForge onde é preciso escolher.
- **Otimizar:** ponto de restauração, programas, o que abre com o Windows e as pastas pessoais com você; depois, sozinho, antivírus, atualizações antecipadas desligadas, componentes, DISM e SFC, Windows Update com os drivers opcionais, dispositivos, winget, Edge, Microsoft Store, atalhos, restos, registro, limpeza, rede, CHKDSK e disco; no fim, a revisão de todos os ajustes e, sempre, a sugestão de reiniciar.
- **Verificar vírus:** atualiza o antivírus e faz a verificação rápida, numa ação só.
- **Sem perfis:** saem os perfis Rápida, Completa e Profunda e a tela Opções da manutenção.

### Mudou para quem usa

**Início e Manutenção**
- Os botões da nota de saúde são **Otimizar** (o principal) e **Verificar vírus**. **Verificar o PC** passa a abrir os atalhos de **Por onde começar**, no lugar da Verificação rápida de vírus.
- Na página Manutenção, o **Otimizar** vem primeiro e em destaque. A seção **Opções e agendamento** vira **Agendamento**, e o resumo do alto não tem mais a linha do perfil; sem nenhuma manutenção, ele aponta para o Otimizar.
- Na página Segurança, **Verificar vírus** abre a seção **Procurar ameaças**. A busca por "vírus" leva a ele.

**Otimizar**
- A lista traz as 22 etapas na ordem de execução, todas marcadas, com "Com você" ou "Automático" na descrição. A janela numera as etapas pelo Otimizar inteiro ("Etapa 19 de 22").
- **Com você, no começo:** o ponto de restauração oferece ligar a Proteção do Sistema quando é ela que falta (Não como padrão). Depois, as telas do próprio WinForge, e não mais as janelas do Windows: Desinstalar programas (sem o winget no PC, a etapa fica ignorada, como a do winget), Remover aplicativos do Windows, **Revisar o que abre com o Windows** (uma lista só, com o que abre hoje marcado; desmarcar desativa, marcar reativa, e a tela mostra o que muda e pergunta, com Não como padrão quando algo deixa de abrir) e **Organizar Downloads, Documentos e Imagens** (uma pasta por vez, com o tamanho: limpar a Downloads com o WinForge, abrir no Explorador ou procurar arquivos duplicados). Fechar uma dessas listas pula a etapa e aparece no resumo como "nada mudou".
- **Perguntas antes da parte automática:** o que atualizar no winget, que restos de programas mandar para a Lixeira (procurados depois das desinstalações) e se a Lixeira é esvaziada.
- **Parte automática:** Verificar vírus; **Desligar as atualizações antecipadas** (a opção "Receba as atualizações mais recentes assim que estiverem disponíveis", com o valor de antes guardado); componentes do Windows; DISM e SFC completos, sem esperar sinal de dano; **Atualizar o Windows**, que instala as atualizações do Windows Update e os drivers opcionais; dispositivos e drivers; winget; **Atualizar o Microsoft Edge**, pelo atualizador do próprio Edge, dizendo de qual versão para qual foi; **Atualizar aplicativos da Microsoft Store**, com o mesmo pedido do botão Obter atualizações (se o Windows recusar, abre a página de atualizações da Store, e um código de erro aparece em hexadecimal); atalhos quebrados e registro, com a mesma correção de Verificar o PC; restos de programas; limpeza rápida; reparo de rede e DNS, agora mesmo com a internet funcionando; CHKDSK; otimização da unidade.
- **A ordem pedida, com uma troca:** a limpeza dos componentes e o DISM e SFC vêm antes do Windows Update, e não depois. Uma atualização instalada deixa o Windows esperando o reinício, e aí o DISM recusa a limpeza e o reparo (0x800F0806) e o SFC também: depois do Windows Update, as duas etapas quase nunca rodariam. Com um reinício já pendente desde antes do Otimizar, as duas ficam para depois de reiniciar, ignoradas e não em vermelho, e dizem onde rodar o reparo.
- **O que fica de fora do Windows Update:** as prévias (as atualizações opcionais que não são drivers), porque são as atualizações antes da hora que a etapa anterior desliga, e o que elas trazem chega na atualização normal do mês seguinte; uma versão nova do Windows; e um firmware opcional.
- **Com você, no fim:** **Revisar os ajustes do Windows** lista os ajustes das duas páginas (menos os segundos no relógio, o agendamento de GPU e as atualizações antecipadas), cada um marcado se já está em uso agora. Marcar aplica, desmarcar o que está em uso desfaz, e a tela mostra os dois lados antes de perguntar, com Não como padrão quando há algo a desfazer.
- **As duas revisões** (a da inicialização e a dos ajustes) não têm "Marcar todos", que reativaria tudo o que a pessoa desativou ou aplicaria até os ajustes de energia que gastam a bateria. No menu de texto, a orientação diz que os números digitados são a lista inteira do que fica marcado (não há como desmarcar um por um), e P deixa tudo como está.
- **Reinício:** o Otimizar sempre sugere reiniciar, com Não como padrão. A faixa só lembra do reinício quando alguma etapa precisa dele.
- Cancelar a parte automática depois das telas com você termina em amarelo, com o que já foi feito no resumo.
- O histórico mostra "Otimizar" nas execuções novas; as antigas continuam com o perfil delas. O relatório diz só "Duração".

**Ajustes do Windows**
- Categoria nova, **Windows Update**: **Receber as atualizações assim que saem** (nova) e Permitir atualizações entre PCs (que estava em Privacidade e sugestões).

**Rede**
- **Reparar rede e DNS** (sozinho e no Otimizar) deixa de fora o reset de TCP/IP quando um adaptador Ethernet ou Wi-Fi tem DNS posto à mão (um Pi-hole, um DNS de filtro, o que Trocar o servidor DNS gravou), porque o reset apagaria esses servidores; a tela diz em qual adaptador. Liberar e renovar o IP continuam, porque não mexem nele. Um adaptador cujo DNS não pôde ser lido conta junto.

**O que não foi visto:** como nas builds anteriores, nada disto rodou num Windows de verdade. Pedem conferência num PC: o Otimizar inteiro, do começo ao fim; o Windows Update com atualizações opcionais e drivers pendentes; a atualização do Edge com o Edge fechado e aberto; o pedido de atualização à Microsoft Store (há relatos de PCs em que o Windows recusa o pedido feito por um Administrador); a chave Receber as atualizações assim que saem contra a tela do Windows Update; as prévias reconhecidas como opcionais que não são drivers; o reparo de rede rodando com a internet boa (Wi-Fi, cabo e VPN) e com DNS posto à mão (o DNS tem de continuar o mesmo depois de reiniciar); e as pastas Documentos e Imagens levadas para o OneDrive.

A lista da 3.31 do que pede conferência continua valendo.

### Estrutura
- **Maintenance.psm1:** o plano tem as fases Before, Auto e After e o tipo "Com você" (`New-WinForgePlanItem -WithYou`), com `components` e `repair` antes de `windows-update` e as duas etapas ignoradas com reinício pendente; `Invoke-WinForgeMaintenancePhase` roda uma fase com a numeração do Otimizar inteiro e `-KeepAwake` na parte automática; `Read-WinForgeMaintenanceDetails` pergunta o winget, os restos e a Lixeira; `Invoke-WinForgeMaintenanceShortcuts` e `Invoke-WinForgeMaintenanceRegistry` usam as correções de Verificar o PC; `ConvertTo-WinForgeStepResult` troca a desistência de uma tela por "nada mudou"; `Get-WinForgeMaintenanceProfileLabel` dá o nome das execuções antigas. Saíram os perfis, `Set-WinForgeMaintenanceOptions`, as etapas manuais e `Invoke-WinForgeAutomaticPhase`.
- **Console.psm1:** `Invoke-WinForgeNestedAction` roda uma ação inteira dentro de um fluxo; `Enter-WinForgeAction` e `Exit-WinForgeAction` sabem quando estão aninhados (seção no lugar do cabeçalho, sem a pausa do fim e sem mudar o desfecho de fora).
- **Startup.psm1:** `Set-WinForgeStartupItems -Review` (`Read-WinForgeStartupReview`); o jeito de sempre ficou em `Read-WinForgeStartupSide`.
- **Cleanup.psm1:** `Invoke-WinForgeFolderReview`, `Get-WinForgeReviewFolders` e `Get-WinForgeKnownFolderPath`. **CleanupTools.psm1:** `Find-WinForgeDuplicateFiles -Path`; os restos de programas em `Select-WinForgeProgramLeftovers` e `Remove-WinForgeProgramLeftovers`. **Shortcuts.psm1:** os atalhos Documents e Pictures (`Get-WinForgeShortcutFolderPath`).
- **WindowsUpdate.psm1:** `Install-WinForgePendingUpdates`, `Get-WinForgeAllUpdatesCriteria`, `Get-WinForgeUpdateRunResult` (o fim da instalação, também usado pela tela de sempre) e o campo `Upgrade` na busca. **Software.psm1:** `Update-WinForgeEdge`, `Get-WinForgeEdgeVersion`, `Get-WinForgeEdgeUpdaterPath` e `Update-WinForgeStoreApps`.
- **Tweaks.psm1:** o ajuste `early-updates`, `Disable-WinForgeEarlyUpdates`, `Invoke-WinForgeTweakReview`, `Invoke-WinForgeTweakReviewChanges`, `Get-WinForgeTweakReviewSkipped` e `Invoke-WinForgeRestorePoint -OfferProtection`. **Network.psm1:** `Invoke-WinForgeNetworkRepair -Force`, `Get-WinForgeManualDnsAdapters` e `Get-WinForgeNetworkRepairCommands -HasManualDns`. **Security.psm1:** `Invoke-WinForgeSecurityCheck` com o título Verificar vírus. **Navigation.psm1:** `security.scan`, o Otimizar no lugar da Manutenção recomendada e sem `maintenance.options`.

## Build 3.50

Esta build faz cada chave dos Ajustes do Windows e da Personalização mostrar como o Windows está agora, lido do próprio Windows, e alternar entre ativado e desativado, como nas Configurações do Windows.
- **O recurso, e não a mudança:** a chave tem o nome do recurso ("Efeitos de transparência", "Ícone da Lixeira na área de trabalho", "Modo de Jogo") e diz **Ativado** ou **Desativado**. Antes, ela tinha o nome da mudança ("Desativar efeitos de transparência") e dizia "Aplicado" ou "Padrão", e uma chave ligada podia querer dizer um recurso desligado.
- **Lido do Windows:** a chave lê o que as Configurações do Windows mostram, e o Modo de Jogo, que vem ativado, aparece ativado.
- **A chave alterna:** ligar ativa e desligar desativa; ao aplicar uma mudança, o WinForge guarda o valor de antes, e uma página aberta antes de uma mudança nas Configurações não faz o contrário do pedido.

### Mudou para quem usa

**Ajustes do Windows e Personalização**
- Cada chave mostra o recurso do Windows e se ele está ativado ou desativado, lido ao abrir a página, ao voltar de uma mudança e em **Atualizar estado**. "Ativado" fica no texto normal e "Desativado", discreto; nenhum dos dois é verde ou vermelho, porque é o estado, e não um problema.
- Nas políticas que o WinForge grava para esses recursos, a chave diz "Permitir" e mostra a política: Permitir os Widgets, Permitir o Recall, Permitir o histórico de atividades, Permitir dados de diagnóstico opcionais e Permitir atualizações entre PCs.
- **Lido como nas Configurações:** a chave segue o que as Configurações do Windows mostram, e não todos os valores que o ajuste grava:
  - Teclas de Aderência: só o bit do atalho delas. Desativar muda só esse bit nas três teclas (Aderência, Filtragem e Alternância), e as outras opções que a pessoa escolheu ficam como estão (antes, o WinForge gravava os números padrão inteiros).
  - Dicas e sugestões do Windows: a opção principal (Receber dicas e sugestões); as outras são desativadas junto.
  - Xbox Game Bar e gravação de jogos: os valores do usuário (a política do sistema é gravada junto). Agrupar os botões: a barra principal. Notificações na tela de bloqueio: o valor que as Configurações gravam.
  - Planos de energia: o plano ativo e, num PC sem bateria, só o valor na tomada. Pela chave, a economia do PCI Express e a tela e suspensão automáticas voltam também no plano ativo que o WinForge não mudou; Desfazer ajustes do WinForge continua só devolvendo os planos que ele mudou.
  - Inicialização Rápida: desligada também quando a hibernação está desligada; ativá-la pela chave liga a hibernação junto, com aviso.
  - Alto desempenho: desligar a chave sai de qualquer plano de alto desempenho (o Desempenho Máximo, uma cópia), para o plano de antes ou o Equilibrado.
  - Compartilhar atualizações: os modos 99 e 100, que também não compartilham, contam como desativado. Dados de diagnóstico: o nível 0 (Segurança) também conta como desativado, e a chave não sobe esse nível para 1.
  - Reconhecimento de fala online: sem o valor, desativado (o padrão do Windows); ativá-lo grava o aceite.
  - Agendamento de GPU: sem o valor no registro, "Não identificado" (quem decide é o driver), e a ação pergunta antes.
- **Página velha:** a janela manda junto o estado que a chave pediu. Se o Windows mudou depois que a página foi aberta e já está assim, nada muda, e a tela diz isso.
- A descrição embaixo do nome diz o que o recurso é (e, quando ajuda, por que desativar), no lugar do que a mudança fazia.
- A tela de uma chave diz o recurso e o estado de agora ("Recurso: Efeitos de transparência", "Estado atual: Ativado"), e o resultado diz "Efeitos de transparência: desativado." No menu de texto, a pergunta diz o que vai acontecer (Deseja desativar "Efeitos de transparência"?). Com o estado não identificado, a janela também pergunta antes, porque a chave não diz se vai ativar ou desativar. No notebook, o que afeta a bateria pergunta de novo, com Não como padrão.
- A frase do alto diz quantos itens da página o WinForge mudou e continuam assim (os que Desfazer ajustes do WinForge devolveria), no lugar de quantos ajustes estavam aplicados.
- **Modo de Jogo:** aparece Ativado num Windows de fábrica (antes, "Padrão" e desligado). Desativar grava o desativado; ativar de novo guarda o de antes. Só entra em Exportar ajustes aplicados quando foi o WinForge que o ativou. Um backup dele feito pela 3.49 (aplicado com ele já ativado) é esquecido, para Desfazer ajustes do WinForge não o desativar.
- **Agendamento de GPU acelerado por hardware:** desativar sem o valor de antes guardado grava o desativado (antes, apagava o valor e deixava o que o driver escolhesse).
- Nomes que mudaram para não confundir na busca: "Ícone da Lixeira na área de trabalho", "Ícone de Este Computador na área de trabalho", "Teclas de Aderência pelo Shift", "Clima e notícias na tela de bloqueio" e "Tela e suspensão automáticas".
- Aplicar ajustes recomendados, Perfis de ajustes, Desfazer ajustes do WinForge e o Histórico de mudanças continuam falando das mudanças ("Desativar o ID de publicidade: aplicado.").

**Busca, menu de texto e relatório**
- Os cartões da busca mostram o recurso, como a página; o nome da mudança ("desativar transparência") também acha. "lixeira" continua levando a esvaziar a Lixeira, e "notificações", à chave das Notificações.
- No menu de texto, cada item aparece como [ativado] ou [desativado], e a legenda diz que é o estado de agora.
- O relatório do PC lista cada recurso como Ativado ou Desativado.

**O que não foi visto:** como nas builds anteriores, nada disto rodou num Windows de verdade. Pedem conferência num PC: cada chave das duas páginas contra a tela correspondente das Configurações do Windows, mudando dos dois lados (no WinForge e nas Configurações) e usando Atualizar estado; o Modo de Jogo num Windows de fábrica; as Teclas de Aderência com opções personalizadas; os planos de energia num desktop e num notebook; e a Inicialização Rápida com a hibernação desligada.

A lista da 3.31 do que pede conferência continua valendo.

### Estrutura
- **Tweaks.psm1:** `Get-WinForgeTweakSwitchLabels` dá a cada ajuste o recurso que a chave mostra (Feature), o que ele é (About) e se o ajuste o desativa (Inverted); o catálogo os acrescenta a cada ajuste. `Get-WinForgeTweakSwitchState -Inverted` diz Ativado ou Desativado. A visão geral traz Name (o recurso), Description (About), Action (o nome do ajuste) e Inverted. `New-WinForgeTweak -OnByDefault` marca o ajuste que já é o padrão do Windows (o Modo de Jogo), e `Get-WinForgeTweakBackupIds` lista os ajustes com o valor de antes guardado. `Invoke-WinForgeTweakToggle` pergunta e responde pelo recurso e ganha `-Want`; enquanto ele desfaz, `Test-WinForgeTweakSwitchRevert` é verdadeiro. Os valores do catálogo aceitam `Also`, `AbsentIsTarget`, `AbsentUnknown` e `State` (`Test-WinForgeTweakValueMatches`, `Test-WinForgeTweakChangeState`); as Teclas de Aderência e a Inicialização Rápida viraram ajustes próprios (`Get-WinForgeAccessibilityFlags`), os planos de energia leem com `Test-WinForgePowerValuesAtZero`, e `ConvertFrom-WinForgeLegacyGameModeBackup` trata o backup do Modo de Jogo da 3.49.
- **Janela:** a linha mostra o recurso, a cor do estado e o balão "Ligue para ativar e desligue para desativar"; `Get-GuiTweakCommand -Ask` deixa a ação perguntar com o estado não identificado; `Get-GuiTweaksHintText -Changed`. **Menus.psm1**, **Reports.psm1** e a busca (**Navigation.psm1**) mostram o recurso.

## Build 3.49

Esta build cria a página **Personalização**, com o visual do Windows que estava nos Ajustes do Windows e coisas novas, e acrescenta aos Ajustes do Windows notificações, teclado, mouse e Modo de Jogo.
- **Personalização:** barra de tarefas e Iniciar (alinhamento, pesquisa, Visão de Tarefas, Widgets, segundos no relógio e, novo, nunca agrupar os botões), área de trabalho (ocultar a Lixeira, mostrar Este Computador), cores e transparência (modo escuro, transparência e, nova, a cor de destaque no Iniciar, na barra e nas barras de título) e tela de bloqueio (dicas e, novos, notificações e widgets).
- **Cor de destaque:** uma das oito cores principais do Windows, ou a automática, tirada do papel de parede.
- **Ajustes do Windows:** desativar as notificações, tirar o atalho das Teclas de Aderência, histórico da área de transferência, Modo de Jogo e sem aceleração do mouse; na barra, as teclas que trocam o idioma do teclado e Notificações e Não incomodar.

### Mudou para quem usa

**Personalização (página nova)**
- Fica logo abaixo dos Ajustes do Windows, com o ícone de uma paleta, e funciona como eles: chave liga/desliga, backup do valor original, Atualizar estado, destaque do ajuste achado na busca e volta da tela de execução no ajuste que mudou. Não tem ajustes avançados, e a frase do alto conta só os dela.
- Saíram dos Ajustes do Windows para cá: barra de tarefas alinhada à esquerda, Finalizar tarefa pela barra, ocultar a pesquisa, o botão Visão de Tarefas, os Widgets e o botão do Copilot, segundos no relógio, recomendações do Iniciar, modo escuro, transparência e dicas da tela de bloqueio. Quem já tinha aplicado algum continua com o estado e o backup dele.
- Ajustes novos: Nunca agrupar os botões da barra de tarefas (do Windows 11 23H2 em diante), Ocultar a Lixeira da área de trabalho, Mostrar Este Computador na área de trabalho, Cor de destaque no Iniciar e na barra de tarefas, Cor de destaque nas barras de título, Remover os widgets da tela de bloqueio (Windows 11) e Não mostrar notificações na tela de bloqueio.
- Na barra: **Cor de destaque** mostra a cor de agora pelo nome, grava a escolhida com tons mais claros e mais escuros, avisa o Windows na hora e, com a cor no Iniciar e na barra ligada, oferece reiniciar o Explorador (sem ela, diz o que ligar: o modo escuro e o ajuste da cor). A automática aparece quando o papel de parede mudar, e a tela diz como ver na hora. **Tela de bloqueio do Windows** e **Personalização do Windows** abrem essas telas nas Configurações do Windows e levam o ícone de abrir fora.
- **Ajustes do Windows > Desfazer ajustes do WinForge** desfaz também os da Personalização, e o relatório do PC chama a seção de "Ajustes do Windows e Personalização".

**Ajustes do Windows**
- Grupos: Explorador, Privacidade e sugestões, **Notificações e teclado** (novo), Jogos e, nos avançados, Energia e desempenho. O grupo Aparência foi para a Personalização.
- Ajustes novos: Desativar as notificações (vale depois de sair e entrar de novo no Windows), Desativar o atalho das Teclas de Aderência (e os das Teclas de Filtragem e de Alternância), Ativar o histórico da área de transferência, Ativar o Modo de Jogo (já vem ligado no Windows; a chave o religa se algo o desligou) e Desativar a aceleração do mouse. O WinForge pede ao Windows que use na hora as opções novas do teclado e do mouse, sem precisar sair e entrar de novo.
- **Teclas que trocam o idioma do teclado** (novo, na barra): o padrão do Windows (Alt + Shift troca o idioma e Ctrl + Shift, o teclado do mesmo idioma), só Alt + Shift (para quem troca entre o ABNT2 e o Internacional sem querer), só Ctrl + Shift ou nenhuma tecla, com as teclas de agora à vista.
- A Cor de destaque e as Teclas que trocam o idioma do teclado, com o WinForge elevado por outra conta, não mudam nada e dizem por quê (iriam para o perfil da outra conta).
- **Notificações e Não incomodar** (novo, na barra): abre a tela nas Configurações do Windows; o Não incomodar não tem um valor que o WinForge mude com segurança.
- Perfil Jogos: liga também o Modo de Jogo e tira a aceleração do mouse e o atalho das Teclas de Aderência.
- Aplicar ajustes recomendados: a lista segue a ordem das páginas, e as dicas da tela de bloqueio vêm por último.

**Busca, teclas e menu de texto**
- Um ajuste achado na busca abre a página dele, e o cartão diz "Personalização > ajuste" ou "Ajustes do Windows > ajuste". "personalização" leva à página nova; "tema" continua levando à Aparência do WinForge.
- A Personalização, como os Ajustes do Windows, fica fora do Ctrl+número (Ctrl+1 a Ctrl+0 continuam abrindo o Início e as nove páginas seguintes).
- No menu de texto, a Personalização tem o próprio menu, com as letras C (Cor de destaque), B (Tela de bloqueio do Windows) e P (Personalização do Windows); nos Ajustes do Windows, T são as teclas do idioma e N as notificações.

**O que não foi visto:** como nas builds anteriores, nada disto rodou num Windows de verdade. Pedem conferência num PC: a cor de destaque nas oito cores e na automática (Iniciar, barra, barras de título e Configurações, nos dois modos), os widgets da tela de bloqueio nas versões do Windows 11 (o ajuste grava o valor do usuário que a chave das Configurações usa), as notificações na tela de bloqueio, Nunca agrupar na 23H2 e na 24H2, a Lixeira e Este Computador depois de reiniciar o Explorador, o efeito na hora das Teclas de Aderência, da aceleração do mouse e das teclas do idioma, e se Desativar as notificações cala também os avisos do monitor do WinForge.

A lista da 3.31 do que pede conferência continua valendo.

### Estrutura
- **Tweaks.psm1:** `Get-WinForgeTweakPages` diz a página de cada categoria; `Get-WinForgeTweakCategories` e `Get-WinForgeTweakOverview` aceitam `-Page`, `Get-WinForgeTweakPageId` devolve a página de um ajuste, e o catálogo sai na ordem das páginas. Os valores do catálogo aceitam `Kind = "String"` (aplicar, conferir, desfazer e voltar ao padrão sem backup em texto). Entram `Sync-WinForgeAccessibilityKeys`, `Sync-WinForgeMouseSettings` e `Sync-WinForgeLanguageHotkey` (SystemParametersInfo), as funções da cor de destaque (`Get-WinForgeAccentColors`, `ConvertTo-WinForgeShade`, `Get-WinForgeAccentPalette`, `ConvertTo-WinForgeColorDWord`, `Set-WinForgeAccentColor`) as das teclas do idioma (`Get-WinForgeLanguageHotkeys`, `Get-WinForgeLanguageHotkeyState`, `Set-WinForgeKeyboardLanguageHotkey`) e `Test-WinForgeTweakOtherAccount`, que barra as duas ações com o WinForge elevado por outra conta.
- **Navigation.psm1:** página `personalize` (do tipo Tweaks) e os itens novos dos Ajustes; a busca leva cada ajuste à página dele. **Shortcuts.psm1:** Personalization, LockScreen e Notifications. **Menus.psm1:** `Get-WinForgeTweaksMenuLetters` e `Show-WinForgeTweaksMenu -PageId`. **Janela:** a lista, o Atualizar estado e a volta da execução valem para as duas páginas. **GuiDesign.psm1:** ícones de paleta e de teclado.

## Build 3.48

Esta build acerta dois detalhes de acabamento da janela: os contornos arredondados, que afinavam nas quinas, e o texto dos botões com ícone, que parecia fora do centro.
- **Quinas por inteiro:** o contorno de botões, cartões, caixas de texto, avisos e da pergunta de uma ação tem a mesma espessura nas retas e nas curvas, também o azul que aparece ao passar o mouse.
- **Botões com ícone centralizados:** "Atualizar" no Início e os outros botões com ícone ficam com o conteúdo no meio.

### Mudou para quem usa

**A janela**
- Contornos arredondados: nas quinas, o contorno ficava fino e falhado, porque o WPF pinta o fundo de uma moldura depois do contorno, e a borda suavizada do fundo cobria metade dele. Agora o fundo e o contorno ficam em molduras separadas, com o contorno por cima, e as quinas têm a mesma espessura das retas. Vale para todos os cartões, botões, caixas de texto, a chave liga/desliga, as caixas de marcação, as dicas, a busca, a faixa de ação em andamento, os cartões da tela de execução, os avisos amarelos e o destaque do ajuste achado pela busca.
- Botões com ícone (como **Atualizar**, no Início, e **Atualizar estado**, nos Ajustes do Windows): o texto subiu um pixel, porque a letra fica abaixo do meio da linha, e o lado do ícone perdeu dois pixels de espaçamento, porque o desenho do ícone já tem essa folga. O conteúdo fica no meio do botão.
- O contorno da caixa de busca, com o foco do teclado, usa a mesma cor das outras caixas de texto.

**O que não foi visto:** como nas builds anteriores, nada disto rodou num Windows de verdade. Pedem conferência num PC: as quinas dos contornos nos dois temas, com o mouse sobre os cartões e botões e com a escala de 100% e de 125%, e o centro do conteúdo dos botões com ícone.

A lista da 3.31 do que pede conferência continua valendo.

### Estrutura
- **XAML:** cada moldura arredondada com contorno virou duas: a de fora com o fundo (raio do contorno mais meia espessura, para as curvas de fora coincidirem) e a de dentro com o contorno, o espaçamento e o conteúdo. Os gatilhos trocam o fundo em `Bd` e o contorno em `Line`.
- **Janela:** entram `New-GuiOutlinedBorder`, `Set-GuiPanelContent` e `Set-GuiPanelOutline`; `New-GuiPanelBorder` passa a usá-las e ganha `-Radius`, `-Padding` e `-Content`. `New-GuiButton` compensa o espaçamento e a altura do texto quando há ícone.

## Build 3.47

Esta build é uma revisão completa da experiência de uso: cada tela, botão e opção da janela, do menu de texto e do monitor na bandeja, mais a abertura e o README. O foco é que quem não entende de computador saiba sempre o que aconteceu e o que fazer em seguida, que um Enter a mais nunca apague, interrompa ou reinicie nada, e que a janela funcione bem com o teclado, com o leitor de tela e em telas pequenas.
- **Chave liga/desliga visível:** no tema claro, a chave desligada era quase invisível; agora tem contorno e bolinha, como a do Windows 11, e texto, contornos e foco do teclado passam do contraste mínimo nos dois temas.
- **Um Enter a mais não faz estrago:** parar uma ação e fechar o WinForge no meio dela têm Não como padrão, as perguntas sem resposta padrão põem o foco no Não ou no Cancelar, e a Limpeza rápida propõe só os temporários (a Lixeira só com escolha).
- **Perguntas inteiras à vista:** a pergunta e os botões de resposta sempre cabem na janela, as perguntas de texto ganham Cancelar e a resposta padrão já vem escrita.
- **Resultados que dizem o que aconteceu:** as faixas nomeiam as etapas que falharam, dizem o espaço ganho, não repetem o pedido de reinício e, onde o Windows precisa reiniciar, oferecem reiniciar ali mesmo.
- **Menu de texto, monitor e README:** o 0 sempre volta, o menu diz como a ação terminou, o ícone da bandeja lista os avisos abertos, e o README começa por "Primeiros passos" e termina com "Como remover o WinForge".

### Mudou para quem usa

**A janela**
- Chave liga/desliga (Ajustes do Windows): desligada, só o contorno e uma bolinha escura; ligada, preenchida na cor de destaque, com a bolinha maior à direita.
- Contraste: o texto apagado (datas, "de 100", legendas) e o amarelo de atenção ficaram mais escuros no tema claro e mais claros no escuro; as caixas de texto, os botões comuns, as dicas e a barra de rolagem ganharam contorno visível; a barra de progresso do tema escuro aparece sobre o trilho. Letras de 11,5 passaram a 12.
- Foco do teclado: o contorno usa a cor de destaque para texto (a dos botões sumia no tema escuro) e não é mais cortado nas bordas das listas; links mostram o foco sublinhados e com fundo, e os detalhes técnicos ganham contorno quando recebem o foco (e o cursor, para selecionar com Shift e as setas).
- Barra lateral: a página aberta ganha uma barrinha na cor de destaque e o nome em negrito, e o leitor de tela diz "página aberta". Itens e botões mostram quando estão sendo clicados.
- Perguntas: o foco do teclado vai para a resposta padrão, para o primeiro item de uma lista de marcação ou, sem padrão, para a saída que não muda nada (Não, Cancelar, Voltar); antes ficava na tela, e o primeiro Tab caía em Parar. Uma lista de marcação ocupa um Tab só (as setas andam entre os itens). Quando a pergunta passaria da borda de baixo, o resumo e a lista encolhem, com barra de rolagem, para os botões de resposta continuarem à vista.
- Perguntas de texto: as dicas do console saem do rótulo ("(ENTER cancela)", "(vazio = voltar)"), entra o botão Cancelar (ou Voltar), e uma resposta padrão ("(ENTER = 30)") já vem escrita e selecionada. "Pressione Enter para continuar" mostra só o botão Continuar, sem caixa de texto.
- Parar e fechar: "Parar "Reparar o Windows" agora?" e ""Reparar o Windows" ainda está em andamento... Fechar mesmo assim?" dizem o nome da ação e o que acontece, com **Não** como padrão. Todas as caixas de mensagem Sim/Não da janela passam a ter Não como padrão, salvo reabrir como Administrador, que a pessoa acabou de pedir.
- Leitor de tela: a pergunta de uma ação e o desfecho dela são lidos assim que aparecem; o botão dos detalhes diz "Mostrar" ou "Ocultar"; a faixa do alto das páginas diz "Esperando a sua resposta" e o nome da ação; cada chave dos ajustes lê também a descrição; os pontos graves do Início dizem "(grave)".
- Na primeira abertura, a janela não passa da área útil da tela (num notebook de 1366 × 768, ou com a escala de 125% ou 150%, a barra de título saía da tela); depois, vale o tamanho guardado, também num segundo monitor. Maximizada, a página fica em até quatro colunas de cartões, e a tela de execução também tem largura máxima.
- O título de uma ação comprida quebra a linha em vez de ser cortado com "…", e o resumo da ação pode ser rolado pelo teclado.
- Ícones com traço da mesma espessura em qualquer tamanho; as dicas (ao passar o mouse) ficam abertas enquanto o mouse está sobre o controle.
- Erros: "Não foi possível começar "...". Tente de novo..." no lugar da mensagem crua do .NET; um erro ao acompanhar a ação mostra o resultado vermelho, com os detalhes abertos, e o caminho do log. Ao abrir, um arquivo faltando diz qual é e o que fazer ("Extraia de novo o WinForge.zip inteiro...").

**Início**
- Os pontos graves de proteção (antivírus ou tempo real desligado, firewall desligado, ameaça ativa) levam direto à Segurança do Windows, com o botão **Abrir a Segurança do Windows**.
- O cartão Windows diz o suporte ("suporte até 13/10/2026", "sem suporte de segurança", "ESU até..."); o cartão Usuário saiu (o nome da conta continua em Sobre este PC e no relatório); o disco diz "quase cheio".
- Com a nota no verde, o resumo diz "1 detalhe para quando puder", e não "pede atenção". Enquanto lê o PC, o cartão diz "Lendo o estado do PC..." (antes, "Verificando", o nome da ação logo abaixo).
- O aviso de WinForge aberto com outra conta explica, sem jargão, que a limpeza e os ajustes vão valer para aquela conta.

**Manutenção**
- **Verificar o PC:** fechar a lista sem corrigir não descarta o que foi achado ("Nenhuma correção foi feita", faixa amarela com os itens); a faixa nomeia o que pede atenção; a nota de segurança da lista fala só do que está marcado.
- **Manutenção recomendada:** com reinício pendente, uma escolha só ("Reiniciar agora", "Continuar sem reiniciar", "Cancelar"); o fim diz o espaço ganho e nomeia as etapas com problema; depois de salvar o relatório, oferece abri-lo ou mostrá-lo na pasta. O passo manual das atualizações virou **Abrir o Windows Update**. Textos do plano, dos perfis e das opções sem jargão.
- **Histórico de mudanças:** vai direto para a lista do que pode ser desfeito (sem marcar tudo de uma vez), e cada linha que pode ser desfeita diz isso. **Histórico de manutenções:** mostra a última verificação e, para uma etapa que costuma falhar, onde rodá-la sozinha.
- **Manutenção agendada:** "Não agendada", "Ativa" ou "Desligada no Agendador de Tarefas", códigos de erro explicados, e uma resposta só para onde extrair o WinForge (Arquivos de Programas).
- Telas que só mostram informação (históricos, opções ao voltar, agendamento ao voltar) terminam sem a faixa "Tudo certo".
- O reparo do disco agendado pela manutenção usa os mesmos textos de Reparo > Verificar o sistema de arquivos (CHKDSK).

**Diagnóstico**
- **Eventos críticos (7 dias):** sem nada sério, "Nenhum problema sério nos últimos 7 dias", em verde; o reinício inesperado (41 e 6008) vira uma linha só, o veredito nomeia as causas, e as dicas são leigas, com o caminho na janela. A leitura mostra a barra de progresso.
- **Inicialização e energia** virou **Tempo ligado e energia**. **Reinício pendente:** só com sinais que aparecem em quase todo PC, diz que reiniciar não é obrigatório, em verde. **Dispositivos com problema**, **Suporte do Windows**, **Sobre este PC** e **Discos e espaço livre** sem jargão (JEDEC, VRAM, PnP), com os caminhos para resolver.
- **Exportar relatório:** começa pelos "Pontos de atenção" (a nota e cada ponto) e mostra o andamento.

**Segurança**
- **Verificação rápida de vírus** e **Verificação completa de vírus** (antes, só "Verificação"): a completa avisa quando o notebook está na bateria e mantém o PC acordado.
- **Auditoria de segurança:** nota de 0 a 100 com as faixas do Início ("84 de 100 · Boa"), no lugar da letra; os conselhos dizem onde clicar.
- Com o antivírus desligado, as ameaças aparecem como "Nenhuma registrada (com o antivírus desligado, nada está sendo examinado)", e não "Nenhuma" em verde.
- Toda menção à Segurança do Windows aponta **Segurança > Segurança do Windows**.

**Limpeza**
- **Limpeza rápida:** o padrão é "Só os temporários"; "Temporários e Lixeira" diz que a Lixeira é apagada sem volta. Na personalizada, com a Lixeira ou os despejos de memória marcados, aviso e padrão Não. **Esvaziar a Lixeira** ensina a restaurar algo antes.
- Aberto com outra conta, as limpezas por conta avisam de quem são os arquivos.
- "Itens ignorados" virou "Em uso (ficaram)" e some quando é zero; contagens com separador de milhar ("12.345 itens"); o aviso do limite da Lixeira só aparece quando algum item passa dele. **Restos de programas desinstalados** explica quando não há o que procurar. **Limpar a pasta Downloads** pergunta de novo um número de dias inválido, e **Encontrar arquivos duplicados** tem Não como padrão. **Analisar uso de espaço** aponta onde liberar cada coisa.

**Desempenho**
- **Liberar memória** e **Acelerar agora** com quase nada a liberar dizem isso, em vez de "0 B" em verde. **Programas pesando agora** termina sem faixa e avisa a memória alta. **Gerenciar inicialização** diz o que é seguro desligar e marca antivírus, itens do Windows e do fabricante.

**Reparo**
- DISM e SFC mostram a porcentagem na barra e quanto costumam levar; as perguntas dizem o que vai começar ("Iniciar o reparo da imagem agora?").
- **Verificar o sistema de arquivos (CHKDSK):** antes de agendar, sugere copiar os arquivos importantes; explica que o reparo roda antes de o Windows abrir e que não se deve desligar o PC; depois de agendar, oferece reiniciar.
- **Limpar componentes do Windows (WinSxS)** diz quanto liberou. Descrições dos itens com o tempo que levam e sem jargão.
- A faixa não repete "Reinicie o PC para concluir" quando o detalhe já manda reiniciar, e o que não foi concluído por causa de um reinício pendente diz "Reinicie o PC e tente de novo".

**Atualizações**
- Num Windows sem suporte, **Instalar atualizações do Windows** não diz mais "em dia": a faixa fica amarela e explica que o Windows não recebe mais atualizações de segurança.
- Depois de instalar atualizações ou drivers, e em **Corrigir o Windows Update**, o WinForge oferece reiniciar ali mesmo, com Não como padrão. Com um firmware (como a BIOS) entre os drivers escolhidos, a confirmação também tem Não como padrão. **Detectar dispositivos e drivers** diz o que está esperando; **Atualizar programas (winget)** pede para fechar os programas antes.
- "Abra o WinForge como Administrador" virou "feche o WinForge, abra de novo e aceite o aviso do Windows".

**Programas**
- **Instalar programas essenciais:** saiu o Spotify; entraram Adobe Acrobat Reader, LibreOffice e Zoom; "Desenvolvimento" virou "Para programadores", por último.
- **Desinstalar programas**, **Remover aplicativos do Windows** e **Recursos opcionais do Windows** vêm sem "Marcar todos" (e sem o T no console), mostram o que vai sair antes de confirmar e avisam dos programas que dependem do que sai. Calculadora, Fotos, Terminal, Bloco de Notas, Paint e Ferramenta de Captura saíram da lista de desinstalar.
- Sem o Instalador de Aplicativo (winget), a tela explica o que é e oferece abri-lo na Microsoft Store; os erros de falta de internet viram texto.
- **Backup antes de formatar:** diz que fotos e documentos ficam à parte, oferece primeiro pendrives e HDs externos, avisa que Documentos fica no disco que vai ser formatado e diz quantos programas voltam sozinhos.
- Recursos opcionais avisam o que para de funcionar ao desligar Hyper-V, WSL e .NET 3.5.

**Rede**
- **Testar conectividade (ping)** é o Recomendado da página. Perda de pacotes deixa a faixa amarela ("conexão instável"), cada linha tem a sua cor, e os vereditos dizem o que fazer.
- **Reparar rede e DNS:** pergunta sempre com Não como padrão (com "indicado" quando a internet não funciona) e mostra "O que o reparo faz" em frases; os comandos ficam nos detalhes.
- **Testar velocidade da internet:** sem casas decimais a partir de 10 Mbps e com uma frase do que a velocidade permite. **Relatório de Wi-Fi** vai para a pasta de relatórios.

**Ajustes do Windows**
- A Game Bar saiu dos recomendados (continua no perfil Jogos). **Desativar hibernação** (antes "Desativar hibernação (hiberfil.sys)") e descrições sem jargão; o agendamento da placa de vídeo avisa que pede reinício.
- Ajustes que gastam bateria perguntam com Não como padrão no notebook. A Proteção do Sistema explica o que é antes de ligar. Fechar uma lista sem escolher diz "Operação cancelada". **Exportar ajustes aplicados** oferece mostrar o arquivo na pasta; **Importar ajustes** mostra a data da exportação e ignora, com aviso, ajustes de outra versão.
- Os títulos dos grupos são os mesmos das outras páginas, e **Atualizar estado** não volta a lista para o topo.

**Monitor na bandeja**
- O menu do ícone lista os avisos abertos (clicar abre o que resolve), tem **Retomar os avisos** durante a pausa e **Configurar o monitor...**, e "Fechar até a próxima entrada no Windows" diz o que acontece.
- A dica do ícone diz o aviso ("WinForge: Pouco espaço no disco C: e mais 1 aviso") e "pausados até amanhã, às 14:30", e é refeita a cada leitura. Pausar mostra um balão com o horário de volta; a primeira vez que o monitor abre, um balão ensina onde ele fica.
- O aviso de disco diz qual disco; o do Windows sem suporte se chama "Windows sem atualizações de segurança". Os balões de pasta sumida dizem o que fazer, e clicar neles não repete o aviso anterior.
- A tela **Monitor na bandeja** oferece **Retomar os avisos** e explica sem jargão quando ele está desligado na inicialização ou foi ligado de outra pasta.

**Menu de texto**
- O 0 sempre volta ou cancela; Enter vazio repete a ajuda; errar a tecla diz o que digitar ("Digite um número de 0 a 11 e tecle Enter"); dez respostas erradas só encerram quando a entrada vem de um arquivo ou de outro programa.
- Ao terminar, a linha "[OK] Concluído", "[!] Concluído com ressalvas" ou "[X] Não foi concluído", e o pedido de reinício quando for o caso. Voltar ou Cancelar não pede mais uma tecla.
- Descrições compridas vão para a linha de baixo, com recuo; a caixa do cabeçalho não passa mais da largura da janela; a barra de estado só mostra "Sem Administrador" quando falta, e o Windows como no Início.
- Ajustes do Windows no console: "[ligado]" e "[desligado]", com legenda, e as letras A (recomendados), P (perfis) e R (ponto de restauração). O item em destaque diz "(recomendado)". A janela do terminal se chama WinForge.

**Abertura e README**
- WinForge.cmd e WinForge-Console.cmd conferem se os arquivos estão na pasta: aberto de dentro do zip, diz para extrair tudo, em vez de não abrir nada.
- O pedido de Administrador no terminal não apaga a tela e explica o que fazer quando é recusado; uma pausa só no fim.
- Criar atalho: "Atalho criado na Área de Trabalho", com descrições do que é cada lugar.
- README: "Primeiros passos" (baixar, desbloquear, extrair em Arquivos de Programas, abrir, o aviso do SmartScreen, o aviso do Windows PowerShell, por onde começar), "Como remover o WinForge" e uma resposta só para onde extrair.

**O que não foi visto:** como nas builds anteriores, nada disto rodou num Windows de verdade. Pedem conferência num PC:
- a chave liga/desliga, a barrinha da barra lateral, os contornos e o foco do teclado nos dois temas, a página em colunas inteiras maximizada e a janela num notebook de 1366 × 768 com escala de 125%;
- o foco nas perguntas, a pergunta comprida encolhendo o resumo, o Cancelar das perguntas de texto, e o Narrador lendo a pergunta, o desfecho e "página aberta" (este último pede o .NET 4.7.1 ou mais novo);
- a porcentagem do DISM e do SFC na barra, os pedidos de reinício reais, o PC acordado na verificação completa de vírus e o espaço liberado pelo WinSxS;
- a Microsoft Store abrindo no Instalador de Aplicativo, os instaladores novos (Acrobat Reader, LibreOffice, Zoom), a lista de pendrives e HDs do backup e o "mostrar na pasta" do exportar;
- o menu do ícone na bandeja refeito a cada abertura, os balões novos e a dica do ícone;
- o menu de texto numa janela de 80 e de 120 colunas, e o aviso de arquivos faltando ao abrir o .cmd de dentro do zip.

A lista da 3.31 do que pede conferência continua valendo.

### Estrutura
- **Cores:** a paleta ganha `SwitchLine`, `SwitchKnobOff`, `SwitchKnobOn`, `InputLine` e `ButtonLine`, e o contraste mínimo de cada uma é conferido nos dois temas.
- **Janela:** entram `Update-GuiPromptFit` (com a conta em `Get-WinForgePromptFit`, no GuiHost), `Limit-GuiWindowToWorkArea` e `Update-GuiContentWidth`. `Show-GuiMessage` ganha `-Default`. `New-GuiIcon` calcula o traço pelo tamanho. As chamadas do leitor de tela que só existem no Windows ficam protegidas, como as outras.
- **GuiHost:** `Get-WinForgePromptPlan` devolve `DefaultText` e tira do rótulo as dicas de teclado do console; o pedido de lista leva `NoSelectAll` (sobrecarga de `AskMulti`).
- **Console:** `Read-WinForgeChoice`, `Confirm-WinForgeAction` e `Read-WinForgeMultiSelect` mudam o limite de respostas, a tecla 0 e a ajuda; `Read-WinForgeMultiSelect` ganha `-NoSelectAll`; `Confirm-WinForgeAction` passa à janela a resposta padrão como veio. Entram `Get-WinForgeUnelevatedHint`, o conselho de como abrir sem Administrador, certo para a janela e para o terminal, e `Get-WinForgeRebootSentence`, o que a janela e o console dizem do reinício no fim de uma ação.
- **Módulos:** entram `Write-WinForgeOtherAccountNotice` (Cleanup), `Open-WinForgeSavedReport` (Reports), `Request-WinForgeRestart` (Maintenance), `Request-WinForgeRestartOffer` (WindowsUpdate), `Get-WinForgeSecurityGradeLabel` (Security) e `Get-WinForgeEssentialCategoryRank` (Software). `Invoke-WinForgeCapture` ganha `-ProgressActivity` (a porcentagem das ferramentas na barra), `Invoke-WinForgeTool` ganha `-Question`, e `Format-WinForgeCount` usa o separador de milhar. O catálogo embutido e `catalog/catalog.json` saem juntos, com a data nova. O JSON do `-Action Check` ganha `Version` (2): `Security.Grade` passou de letra à faixa da nota.

## Build 3.46

Esta build revisa a busca (Ctrl+K) e as teclas de atalho da janela nos sete pontos: se fazem o que prometem, segurança e robustez, interface e fluxos, código, desempenho e erros comuns e incomuns. O foco é que a busca ache o que a pessoa procura do jeito que ela escreve, que nada rode por um palpite e que o teclado nunca tire uma ação ou uma pergunta da frente.
- **Busca que entende erro de digitação:** "limpesa", "atualisar", "desistalar" e "antevirus" acham o que procuram, e o resumo diz a correção.
- **Sintomas do dia a dia:** "tela piscando", "impressora", "internet caiu", "programas pesados", "esquentando" e "pendrive não reconhecido" levam à tela certa; quando nada tem todas as palavras, aparecem os mais próximos, com o aviso.
- **Nada roda por um palpite:** numa busca corrigida ou parcial, o Enter só seleciona uma ação; e o Enter age quando a tecla é solta, então segurá-lo não abre a ação de novo nem responde ao aviso seguinte.
- **Esc seguro:** não tira da frente uma ação em andamento nem uma pergunta.
- **Teclas à vista:** a tecla de cada página aparece ao passar o mouse, e o leitor de tela diz quantos resultados há.

### Mudou para quem usa

**O que a busca acha**
- Erro de digitação: uma palavra de 6 letras ou mais que não aparece em lugar nenhum vira a mais parecida do WinForge, com as mesmas duas primeiras letras (uma letra trocada, sobrando, faltando ou invertida; duas nas palavras de 9 letras ou mais), e o resumo mostra "'limpeza' (você digitou 'limpesa')". Para quem ainda está digitando, vale também o começo de uma palavra ("atualisa" acha "atualizar"). Palavras comuns que o WinForge não tem ("excel", "filmes", "renomear", "carregador") ficam como estão, e com mais de duas palavras desconhecidas nada é corrigido.
- Quando nada tem todas as palavras ("senha wifi", "jogo travando"), aparecem os resultados com parte delas, os que têm mais palavras primeiro, e o resumo diz "Nada tem todas as palavras de...". Antes, a tela ficava vazia. Uma busca só com palavras de ligação ("o que fazer") continua sem resultado.
- O Enter, numa busca corrigida ou que achou só parte das palavras, abre uma página ou um ajuste, mas uma ação ou uma janela do Windows só fica selecionada, e o resumo diz "Enter seleciona o primeiro".
- Palavras parecidas: "ocultar" e "esconder" acham também o que diz "desativar"; "apagar", "excluir" e "deletar" se acham entre si, assim como "consertar", "reparar", "corrigir" e "arrumar", "travando" e "congelando", e "lento" e "devagar". A palavra exata, em qualquer ponto do nome, vem antes.
- Uma palavra não conta mais no meio de outra logo depois de "des", "re" ou "in": "fazer" não acha "desfazer", "instalar" não acha "desinstalar" e "iniciar" não acha "reiniciar".
- O plural acha o singular ("erros" acha "erro", "drivers" acha "driver"), um pouco abaixo da palavra exata.
- Uma palavra só leva também à página: "limpar" abre a Limpeza, "redes" a Rede, "atualizar" as Atualizações e "reparar" o Reparo. O Enter numa palavra solta abre a página, e não a primeira ação que começa com ela (antes, "limpar" abria **Limpar a pasta Downloads**).
- Cada palavra vale pelo melhor lugar em que aparece: no nome da ação, mesmo pela raiz da palavra, vale mais que nas palavras extras; e nas palavras extras, a palavra inteira vale mais que o começo de outra ("restore" leva à Restauração do Sistema, e não ao DISM).
- A mesma ação em duas páginas (Restauração do Sistema, Gerenciar inicialização, Criar ponto de restauração) aparece uma vez só.
- "pc" e "computador" só somam com a palavra inteira ("PCs" não conta).
- Palavras novas para sintomas e pedidos comuns: "tela piscando", "tela preta", "impressora", "microfone", "pendrive não reconhecido", "internet caiu", "wifi lento", "disco 100%", "programas pesados", "esquentando", "barulho", "limpeza de disco", "otimizar windows", "atualizar windows", "atualização travada", "programas que iniciam" e termos em inglês ("cleanup", "restore"). Palavras como "não funciona", "não consigo", "sozinho" e "deixar" não atrapalham mais.
- **Apagar o espaço livre** não é mais achado por quem procura recuperar arquivos apagados (as palavras "recuperar arquivos apagados" saíram dele, e a descrição diz que o apagado não pode mais ser trazido de volta).
- A **Aparência do WinForge** é achada por "tema", "modo escuro", "claro" e "cores", e abre Sobre o WinForge com o foco na opção marcada.
- A busca começa na segunda letra: uma letra só mostrava quase tudo e agora não troca a página pela busca.
- Caracteres invisíveis colados de outros programas (hífen opcional, espaço de largura zero) não partem mais a palavra, e um texto enorme colado por engano é cortado em 200 caracteres.
- Com a versão do Windows desconhecida, a busca mostra os mesmos ajustes que a página de Ajustes (antes, mostrava os do Windows 11, que a página escondia).

**Teclado e tela**
- O Enter na caixa de busca age quando a tecla é solta, uma vez só: antes, cada repetição da tecla segurada abria de novo (uma janela do Windows por repetição, ou um aviso de "Já existe uma ação em andamento"), e a tecla ainda segurada podia responder ao aviso que aparecesse em seguida.
- Quando a ação começa, o foco do teclado sai da caixa de busca; e o Enter na caixa, com a tela da ação na frente, traz os resultados de volta em vez de abrir a ação outra vez.
- Uma pergunta que aparece enquanto você digita na busca não leva mais o foco: as letras seguintes, e o Enter, não viram resposta.
- Esc: com uma ação em andamento ou uma pergunta na tela, não faz nada (antes, com a busca aberta, tirava a ação da frente). Com texto na caixa antes de a busca aparecer, só esvazia a caixa (antes, podia abrir a página de uma busca anterior). Apagar o texto com a tela da ação na frente não a tira de lá.
- A seta para baixo, que vai da caixa ao primeiro cartão, passa a ser tratada antes da própria caixa (que a usaria para mover o cursor), e a seta para cima na primeira linha de cartões volta para a caixa.
- Com uma lista com filtro na tela, **Ctrl+F** vai para o filtro da lista; **Ctrl+K** continua indo para a busca.
- O primeiro resultado ganha a tecla "Enter" no canto quando o Enter o abre, além da moldura; os cartões de página e de ajuste têm o ícone da página, e não mais a lupa.
- Sem resultado, as sugestões ("pc lento", "sem espaço", "internet lenta", "vírus") são botões que buscam na hora.
- A tecla de cada página (Ctrl+1 a Ctrl+0) aparece ao passar o mouse sobre ela na barra lateral, e o leitor de tela a diz; a dica da caixa de busca também cita as teclas das páginas.
- Leitor de tela (com o .NET 4.7.1 ou mais novo, que vem no Windows 10 desde a versão 1709): o resumo da busca (quantos resultados) é lido a cada busca. Em qualquer versão, cada cartão diz de onde vem ("Modo escuro, Ajustes do Windows > ajuste") e qual é o que o Enter abre.
- A caixa de busca ganha contorno na cor de destaque com o foco, como as outras caixas de texto.
- Na barra lateral, o Tab segue a ordem da tela: busca, páginas e, por último, o rodapé (antes, ia da busca para Sobre o WinForge). Durante a busca, nenhuma página fica marcada na barra lateral.
- Trocar o tema com a busca na tela mantém a rolagem, e mais uma letra que não muda a lista não refaz os cartões. Montar o índice da busca, logo depois de a janela abrir, leva cerca de metade do tempo de antes, e o vocabulário da correção de digitação é montado junto, e não na primeira busca com erro.

**O que não foi visto:** como nas builds anteriores, nada disto rodou num Windows de verdade. Pedem conferência num PC:
- o Enter agindo ao soltar a tecla, as setas para baixo e para cima entre a caixa e os cartões, e o foco saindo da caixa quando a ação começa;
- o leitor de tela (Narrador) lendo o número de resultados e a tecla de cada página;
- o contorno da caixa de busca com o foco e a ordem do Tab na barra lateral.

A lista da 3.31 do que pede conferência continua valendo.

### Estrutura
- **`Navigation`:** cada palavra é pontuada pelo melhor lugar em que aparece, em todas as formas (a própria, o singular e os sinônimos). Entram `Get-WinForgeSearchQuery`, `New-WinForgeSearchSpecs`, `Find-WinForgeSearchHits`, `Get-WinForgeSearchCorrection` (distância de Damerau contra as palavras do índice, de `Get-WinForgeSearchVocabulary`, com a resposta guardada por palavra), `Test-WinForgeSearchKnown`, `Test-WinForgeSearchInside`, `Test-WinForgeSearchEnterOpens`, `Get-WinForgeSearchBase`, `Get-WinForgeSearchSynonyms`, `Get-WinForgeSearchSections`, `Get-WinForgeSearchTweakEntries`, `Get-WinForgeSearchPageIndex`, `Test-WinForgeSearchTooShort`, `Format-WinForgeSearchQuote` e `Get-WinForgePageShortcutKey`. Cada resultado traz `Partial`, `Corrected`, `Section`, `Rank` e `Matched`. A normalização troca as letras acentuadas de uma vez por tabela, e não letra por letra, e cada entrada guarda um texto único para pular de uma vez o que não tem a palavra. Um ajuste com defeito fica fora da busca sozinho (a falha vai para `Write-Verbose`). `Resolve-WinForgeKeyAction` ganha `ClearSearch` e `FocusPromptFilter`.
- **Janela:** o Enter da caixa de busca passa a agir no `PreviewKeyUp`. `Exit-GuiSearch` junta o que o Esc e a caixa esvaziada faziam em dois lugares, e `Hide-GuiRunView`, o que `Show-GuiPage` e a busca repetiam; `Add-GuiSearchSuggestions`, `Send-GuiAnnouncement` e `New-GuiKeyChip` são novas. Sai a variável `SuppressSearch`: a busca é dada como encerrada antes de a caixa ser esvaziada. `New-GuiBrush` guarda um pincel congelado por cor. O comentário do índice da busca estava em cima do temporizador errado, e o relógio da hora do Início não era parado ao fechar.

## Build 3.45

Esta build revisa a página Sobre o WinForge inteira, nos mesmos sete pontos das revisões anteriores: se cada opção faz o que promete, segurança e robustez, interface e fluxos, código, desempenho e erros comuns e incomuns. O foco é que a nova versão chegue conferida e fácil de instalar, e que o monitor na bandeja funcione bem com a janela sempre como Administrador.
- **Nova versão conferida ou nada:** sem o SHA-256 publicado pelo GitHub, nada é baixado; com ele, a tela confere o pacote e diz como instalar.
- **Monitor abre na hora:** ligado pela janela, ele abre já, sem herdar o Administrador.
- **Desligar o monitor** não mostra mais o aviso de que o ícone não fechou quando ele fechou.
- **Resumo que avisa:** atalho de uma cópia antiga, conta de outro Administrador e pasta que outras contas alteram.
- **Falhas de rede em português**, com o que fazer.

### Mudou para quem usa

**Verificar nova versão**
- O arquivo só é baixado quando o GitHub publica o SHA-256 dele (o `digest`, que o GitHub dá aos arquivos de release). Sem ele, nada é baixado e a tela aponta a página do projeto; antes, o arquivo ficava na pasta, sem conferência, com a instrução de instalar.
- Depois do download, a tela confere que o zip é um pacote do WinForge e avisa se a versão escrita nele não bate com a anunciada. Ela diz como instalar (abrir o zip, entrar na pasta WinForge e copiar tudo para a pasta do WinForge, substituindo os arquivos; extrair "por cima", como dizia antes, criava uma pasta WinForge dentro da outra) e oferece mostrar o arquivo na pasta Downloads.
- A mesma versão já baixada e conferida não é baixada de novo, e um arquivo antigo de mesmo nome em uso não derruba mais um download bom (o novo fica com outro nome, como "WinForge-3.45 (2).zip").
- Parar no meio do download não deixa o arquivo parcial (.download) na pasta.
- Com a conta de outro Administrador, o download não é feito (iria para a pasta Downloads dessa conta), e a tela diz como baixar na sua.
- As falhas aparecem em português, com o que fazer: sem conexão, GitHub sem resposta, data e hora do PC erradas, limite de consultas do GitHub (com a hora em que libera, quando o GitHub informa), versão não encontrada, falta de espaço em disco.
- As notas do release perdem os marcadores de ênfase, mas não o "_" dentro de uma palavra (tweak_backup.json).
- As versões aparecem como "Instalada" e "Última publicada", as duas no formato "Build 3.45", e a data de publicação vem na hora local (antes, em UTC: à noite, um dia depois). A versão do release é o número com ponto: "WinForge 2026 v3.45" é 3.45, e não 2026.
- As notas do release entram no resumo da janela, sem Markdown, links, HTML, tabelas nem blocos de código, com "Notas completas" quando são cortadas.

**Conferir dados online**
- Um catálogo baixado com data no futuro, com datas de suporte fora de 2015 a 2045 ou com o fim do Enterprise antes do Home é recusado; antes, um erro de digitação no arquivo publicado podia marcar todo Windows como sem suporte. O catálogo que vem com o WinForge não depende do relógio do PC.
- Uma publicação mais antiga que a cópia guardada não a substitui.
- As falhas de download aparecem em português, com o detalhe técnico numa linha separada, e a barra de andamento do PowerShell não toma mais o lugar do texto da etapa.

**Resumo da página e Criar atalho**
- O resumo avisa em amarelo quando o atalho abre outra pasta do WinForge (uma cópia antiga), quando o WinForge está aberto com a conta de outro Administrador e quando outras contas do PC podem alterar os arquivos do WinForge, que a janela roda como Administrador. A linha do ícone diz o que fazer ("extraia a pasta inteira do WinForge de novo"), e a do Administrador diz "aberta como Administrador".
- Com a conta de outro Administrador, o atalho não é criado (iria para a Área de Trabalho dessa conta), e a tela diz como criar na sua.
- Numa pasta que outras contas alteram, **Criar atalho do WinForge** avisa antes e sugere extrair o WinForge de novo em Arquivos de Programas (mover a pasta não muda as permissões dela); o README passa a sugerir `C:\Program Files\WinForge`.
- Depois de gravar o atalho, o WinForge pede ao Windows que releia os ícones, para o ícone novo aparecer.
- O botão **Abrir log** abre o log pelo Explorador, no Bloco de Notas da sessão, sem o Administrador da janela.

**Monitor na bandeja**
- **Ligar o monitor** e **Abrir agora**, com a janela como Administrador, abrem o ícone na hora pelo Explorador, sem a elevação; antes, ele só aparecia no próximo login. Se o Windows não fizer essa troca, o monitor fecha sozinho (com o UAC ligado, ele nunca fica como Administrador), e a tela diz que ele abre com o Windows. Um monitor aberto de outra pasta do WinForge (a cópia antiga) é fechado e trocado pelo desta.
- **Desligar o monitor** com o ícone já fechado (ou fechado logo no pedido) dizia que ele não tinha fechado; agora fica verde.
- "Começa com o Windows" diz quando a entrada foi desativada no Gerenciador de Tarefas ou aponta para outra pasta (a pasta mudou de lugar), e **Ligar o monitor** corrige as duas. Uma pasta de caminho longo demais para a entrada de início é recusada com a explicação.
- Com a pasta do WinForge apagada ou movida, o monitor aberto tira a própria entrada, avisa e fecha alguns segundos depois; o menu do ícone não tenta mais abrir uma janela que não existe.
- Um balão por vez, o mais grave primeiro, e o clique no balão que está na tela abre a tela daquele aviso; antes, vários saíam de uma vez, e o clique abria a do último.
- Sem nenhuma verificação ainda, o aviso diz "O WinForge ainda não verificou este PC" (antes, "faz mais de um mês"). Uma leitura que não confirmou o ESU não vira mais aviso semanal.
- Numa conexão limitada ou na bateria, o monitor não consulta o winget nem os dados online.
- Um relógio que esteve adiantado não cala mais o monitor (conferências e pausa gravadas no futuro), e os avisos pausados mostram até quando.
- Antes da primeira leitura, a dica do ícone diz "a primeira leitura sai em instantes", e não "nada pedindo atenção".
- A janela só roda, de um pedido vindo de outra abertura ou da linha de comando, as ações que o monitor oferece (a reabertura que a própria janela pede para uma ação que precisa do Administrador continua com qualquer ação).

**Aparência**
- A opção marcada ganha contorno na cor de destaque (o fundo quase não se distinguia do trilho), o leitor de tela diz "selecionada", e o foco do teclado volta para a opção escolhida depois da troca.
- Com **Automático**, a janela acompanha o tema do Windows assim que uma ação termina (o ajuste Modo escuro, por exemplo).

**O que não foi visto:** como nas builds anteriores, nada disto rodou num Windows de verdade. Pedem conferência num PC:
- o monitor abrindo pelo Explorador com a janela como Administrador, e a entrada desativada no Gerenciador de Tarefas;
- o download de uma versão nova e as mensagens de rede (sem internet, limite do GitHub);
- o ícone do atalho atualizado depois de criá-lo de novo;
- a linha da pasta com o WinForge em `C:\WinForge` num PC com mais de uma conta.

A lista da 3.31 do que pede conferência continua valendo.

### Estrutura
- **`AppUpdate`:** `ConvertTo-WinForgeWebErrorText`, `Get-WinForgeReleasePackageInfo`, `Show-WinForgeDownloadedRelease` e `Invoke-WinForgeUpdateFlow` (a tela abre e fecha a ação uma vez só). `Save-WinForgeRelease` devolve `NoHash` e `Reused` e apaga o parcial num `finally`. Saem `ConvertFrom-WinForgeHashText` e a leitura de um arquivo `.sha256` do release (o hash vem só do `digest`). `Format-WinForgeReleaseNotes` devolve `Lines` e `Truncated`.
- **`Catalog`:** limites das datas em `Test-WinForgeCatalogDate`; `ConvertFrom-WinForgeCatalogDocument -Downloaded` (a data no futuro só vale para o baixado); `Update-WinForgeCatalog` devolve `Detail` e não troca a cópia guardada por uma mais antiga.
- **`Launcher`:** `Get-WinForgeShortcutState`, `Get-WinForgeAppFolderWriters` e `Show-WinForgeFolderWritersNotice`.
- **`Shell`:** `[WinForge.ShellIdentity]::RefreshIcons()`.
- **`Agent`:** `Get-WinForgeAgentRunState`, `Get-WinForgeAgentPausedUntil`, `Remove-WinForgeAgentStaleEntry` e `Get-WinForgeAgentActionIds`; `Start-WinForgeAgent` devolve se o ícone apareceu e continuou aberto, e `Test-WinForgeAgentStartBlocked` passa a ser verdadeiro ou falso. O `WinForge.Agent.ps1` fecha quando abre elevado com o UAC ligado.
- **Janela:** foco e nome acessível da Aparência; `Update-GuiTheme` ao fim de cada ação; saem os ícones `sun`, `moon` e `auto`, que não eram usados, e uma inicialização repetida do cache de pincéis.

## Build 3.44

Esta build atende quatro pedidos: explica e trata a falha de **Desativar os Widgets**, põe o cursor da busca no lugar (e corrige outros desalinhamentos da janela do mesmo tipo), troca o ícone do WinForge e faz a janela abrir sempre como Administrador.
- **Widgets e pesquisa protegidos pelo Windows:** a tela diz por que não muda e oferece abrir as Configurações da barra de tarefas.
- **Cursor da busca no lugar:** o cursor piscante começa onde começa a dica "Buscar".
- **Contorno de foco acompanha cada controle:** cartões, chaves, opções e botões menores.
- **Ícone novo:** uma bigorna branca de face azul sobre um quadrado grafite, em dez tamanhos.
- **Sempre como Administrador:** o aviso do Windows aparece ao abrir a janela.

### Mudou para quem usa

**Abrir o WinForge**
- A janela abre sempre como Administrador: o aviso do Windows (Controle de Conta de Usuário) aparece ao abrir, como já acontecia no menu de texto. O item **Modo de Administrador** saiu de Sobre o WinForge, e a escolha gravada antes deixa de ser lida.
- Recusado o aviso, a janela abre assim mesmo, sem Administrador: o rodapé diz "Sem Administrador", a linha Administrador do resumo de Sobre o WinForge fica amarela, e cada ação que altera o sistema oferece reabrir elevada, na mesma página.
- Aberta pelo monitor na bandeja (Acelerar agora, Limpeza rápida, Verificar o PC), a janela também pede a permissão, e a ação pedida segue para a janela elevada.
- Com a janela já aberta, abrir o WinForge de novo (pelo atalho, pelo `WinForge.cmd` ou pelo monitor) não mostra o aviso do Windows: o pedido vai direto para a janela aberta, como antes.
- **Monitor na bandeja:** ligado pela janela, que agora roda como Administrador, ele passa a abrir no próximo login (o monitor nunca roda como Administrador). Quem já usa o monitor não percebe diferença.
- **Programas:** com a janela como Administrador, o winget não altera um programa instalado só para o seu usuário (0x8A15007D) nem roda um instalador que recusa o Administrador (0x8A150056). Esses programas falham em **Atualizar programas** e na instalação, e a tela diz como seguir: fechar o WinForge, abrir de novo e responder Não ao aviso do Windows; sem Administrador, eles atualizam como antes.
- **Páginas dos fabricantes** (drivers, em Atualizações): abrem pelo Explorador, então o navegador não herda o Administrador da janela.
- Aberto de uma unidade de rede mapeada (Z:, por exemplo), o WinForge passa à execução elevada o caminho de rede, que ela enxerga; a janela elevada não enxerga a letra da unidade.

**Desativar os Widgets e Ocultar a pesquisa da barra de tarefas**
- No Windows 11 atual, um driver do próprio Windows (UCPD) protege a configuração dos Widgets e, em algumas versões, a da pesquisa na barra de tarefas: ele impede que ferramentas como o PowerShell, que o WinForge usa, as gravem, mesmo como Administrador, enquanto as Configurações do Windows mudam normalmente. Por isso **Desativar os Widgets** falhava sempre, com "Attempted to perform an unauthorized operation.".
- Agora, quando o Windows recusa, o resultado fica amarelo, diz que a configuração é protegida e onde mudar (nas Configurações do Windows, em Personalização, Barra de tarefas; no Windows 10, a pesquisa pelo clique direito na barra de tarefas) e, no Windows 11, oferece abrir as Configurações da barra de tarefas. O WinForge não tenta contornar a proteção.
- Ao aplicar vários (recomendados, perfis, importar), o ajuste protegido vira um aviso, sem pergunta.
- Ao desfazer (pela chave, em **Desfazer ajustes do WinForge** ou no **Histórico de mudanças**), a tela diz onde voltar: a pesquisa, pelas Configurações do Windows; os Widgets, pelo Editor de Política de Grupo (gpedit.msc, no Windows Pro), porque a política gravada deixa a chave das Configurações travada. Desfazer os Widgets não oferece mais abrir as Configurações.
- Nos outros ajustes, uma recusa do Windows aparece em português ("o Windows negou a alteração (acesso negado)"), e não mais com a mensagem em inglês.

**A janela**
- **Busca:** o recuo do texto era aplicado duas vezes, e o cursor piscante ficava cerca de 6 px à direita da dica "Buscar" (entre o B e o u). Agora começa no mesmo ponto, e a janela confere a posição da dica com o cursor depois de desenhar o campo. O filtro das listas longas ("Filtrar a lista") tinha o mesmo defeito.
- **Caixas de texto das perguntas:** com o mesmo recuo dobrado, o texto ficava mais para dentro e a caixa, mais alta; agora seguem as medidas do desenho.
- **Contorno de foco** (o anel azul ao navegar com Tab): era um só, com a curva dos botões comuns, para todos os controles; nos cartões, nas chaves liga/desliga, nas opções das perguntas e nos botões menores, a curva do anel não acompanhava a do controle. Agora cada um tem o seu.

**Ícone**
- Ícone novo: uma bigorna branca de face azul sobre um quadrado grafite. `assets\WinForge.ico` tem dez tamanhos (16, 20, 24, 32, 40, 48, 64, 96, 128 e 256 px), cada um desenhado para o seu tamanho, e vale para a barra de título, a barra de tarefas, o Alt+Tab, o atalho, a barra lateral e o monitor na bandeja. `assets\WinForge.svg` é a nova fonte editável.
- Sem o `.ico` na pasta, a janela desenha a mesma bigorna (antes, um "W" sobre o quadrado azul).
- Um atalho criado antes pode continuar com o ícone antigo até o Windows atualizar o cache de ícones; criar o atalho de novo, em Sobre o WinForge, resolve.

**O que não foi visto:** como nas builds anteriores, nada disto rodou num Windows de verdade. O motivo da falha dos Widgets vem da documentação pública do driver UCPD e da mensagem da sua captura de tela. Pedem conferência num PC:
- abrir a janela aceitando e recusando o aviso do Windows, e pelo monitor na bandeja;
- **Desativar os Widgets** num Windows 11 com a proteção ativa, o botão que abre as Configurações e o desfazer pelo Editor de Política de Grupo;
- abrir o WinForge de uma unidade de rede mapeada;
- o cursor e a dica da busca, e o anel de foco, nas escalas de tela de 100%, 125% e 150%;
- o ícone novo na barra de tarefas, no Alt+Tab e na bandeja.

A lista da 3.31 do que pede conferência continua valendo.

### Estrutura
- **`Tweaks`:** `New-WinForgeTweak` e `New-WinForgeRegistryTweak` ganham `-Protected` (a dica e o atalho das Configurações do Windows, com variantes para o Windows 10); `UndoShortcut` para o desfazer; `Test-WinForgeAccessDenied` (só recusas do registro, não de arquivos), `Get-WinForgeTweakProtectedHelp` e `Get-WinForgeTweakProtectedText`.
- **`Journal`:** desfazer um ajuste protegido pelo Histórico de mudanças usa a mesma explicação.
- **`Drivers`:** as páginas dos fabricantes abrem pelo `explorer.exe`.
- **`Shortcuts`:** `Taskbar` (Configurações da barra de tarefas).
- **`Console`:** `ConvertTo-WinForgeReadableError` traduz as mensagens de acesso negado do Windows.
- **`Launcher`:** saem `Get-WinForgeAdminMode` e `Set-WinForgeAdminMode`; a linha Administrador do resumo diz só se a janela está com ele.
- **`Navigation`:** sai o item `app.admin-mode`.
- **`GuiDesign`:** `Get-WinForgeLogoDrawing`, o desenho do SVG para a reserva da janela.
- **Janela:** a partida sempre pede o Administrador (menos quando já há uma janela aberta, reconhecida pela trava de `Enter-WinForgeWindowLock`) e sai `Get-GuiAdminModePreference`; `Start-GuiRelaunch` (sem console, com `-Handover` só para a reabertura pedida por uma janela aberta) e `Get-GuiLaunchScriptPath`; `Update-GuiHintPosition`; os modelos das caixas de texto não repetem o `Padding` no `PART_ContentHost`; `FocusRingSmall`, `FocusRingOption` e `FocusRingCard`.
- **`assets`:** `WinForge.ico` e `WinForge.svg` novos.

## Build 3.43

Esta build revisa a tela de Ajustes do Windows inteira, nos mesmos sete pontos das revisões anteriores: se cada opção faz o que promete, segurança e robustez, interface e fluxos, código, desempenho e erros comuns e incomuns. O foco é que desfazer seja seguro e que cada ajuste só apareça onde faz efeito.
- **Desfazer não passa por cima do que mudou depois:** só volta ao original o que ainda está como o WinForge deixou.
- **Cada ajuste na versão certa do Windows:** Finalizar tarefa só a partir da 23H2; o botão do Copilot só até a 23H2.
- **Dois ajustes novos na barra de tarefas:** ocultar a pesquisa e o botão Visão de Tarefas.
- **Resumo mais limpo:** andamento na barra de progresso, avisos como linhas do resumo e a data de cada ajuste ao desfazer todos.
- **A busca só oferece o que a página mostra:** um ajuste que não vale neste Windows não aparece mais nos resultados.

### Mudou para quem usa

**A página**
- A frase do alto diz, depois da leitura, quantos ajustes estão aplicados ("Aplicados agora: 8 de 35, contando os avançados.").
- Os nomes não trazem mais "(Windows 11)": os ajustes exclusivos dele já só aparecem nele.
- **Ocultar a pesquisa da barra de tarefas** (para pesquisar, abra o Iniciar e comece a digitar) e **Ocultar o botão Visão de Tarefas** (ela continua no Windows + Tab), no Windows 10 e no 11.
- **Finalizar tarefa pela barra de tarefas** só aparece a partir do Windows 11 23H2 (build 22631), quando a opção chegou; antes, o ajuste aparecia como aplicado sem fazer nada. **Ocultar o botão do Copilot** (antes "Esconder") só aparece até a 23H2: na 24H2 o Copilot virou um aplicativo comum, que se desafixa da barra como qualquer outro.
- **Busca:** os ajustes que não valem neste Windows (os do Windows 11 no 10, o botão do Copilot na 24H2) saem dos resultados; antes, o clique levava a uma página sem eles.
- **Desativar o reconhecimento de fala online** não cita mais a Cortana, aposentada pela Microsoft; diz que recursos que dependem da nuvem, como o ditado, podem deixar de funcionar.

**Desfazer um ajuste (a chave e Desfazer ajustes do WinForge)**
- **O que mudou depois fica:** um valor que você (ou o Windows) mudou depois do ajuste não volta ao original de antes, que passaria por cima da sua escolha mais nova; o que ainda está como o WinForge deixou volta. Vale também para a energia: o plano de antes só volta se o plano ativo ainda é o Alto desempenho que o ajuste ativou (trocado depois, até para o Desempenho Máximo, fica), um tempo de tela ou de suspensão que você mudou depois fica, e a hibernação só é ligada se ainda estiver desligada.
- **O resultado diz o que aconteceu:** "desfeito"; "desfeito; o que foi alterado depois foi mantido"; ou "nada a desfazer; foi alterado depois", que não conta como desfeito nem pede para reiniciar o Explorador. Com tudo alterado depois, a faixa fica cinza ("Nada a fazer").
- **Sem conseguir ler o plano de energia ativo**, desfazer o Alto desempenho falha e o backup fica para uma nova tentativa (antes, o plano não voltava e o backup era apagado).
- **Desfazer ajustes do WinForge** lista cada ajuste com a data em que foi aplicado ("aplicado em 01/11/2026 14:30"), numa coluna do tamanho do maior nome.
- O andamento fica na barra de progresso.

**Aplicar vários (recomendados, perfis, importar)**
- O andamento ("2 de 5: Modo escuro") fica na barra de progresso; antes, uma barra de texto por ajuste ficava no resumo.
- O estado de cada ajuste é lido uma vez a menos (nos de energia, uma consulta a menos ao powercfg por ajuste).
- **Perfis:** descrições corrigidas ("O Essencial e menos distrações", "O Essencial e mais"; no Trabalho, o botão do Copilot "onde existe"; no Jogos, que em notebook é o Alto desempenho que vem desmarcado).

**Reiniciar o Explorador**
- Antes da pergunta, a tela avisa que o reinício fecha as janelas de pastas abertas e interrompe cópias de arquivos em andamento.

**Ligar ou desligar um ajuste**
- A descrição do ajuste é uma linha de informação do resumo; antes era um texto amarelo solto, que o resumo da janela não mostrava.
- Desligar um ajuste que já foi alterado depois (o Alto desempenho trocado pelo Desempenho Máximo, por exemplo) diz "Nada a desfazer" e mantém a escolha de agora, em vez de falar de uma política que imporia o valor.
- Um estado que não pôde ser lido ("Não identificado") é lido de novo na hora de aplicar.

**Importar ajustes**
- A data da exportação aparece como dia e hora ("01/10/2026 09:05"), e não no formato técnico.
- Um arquivo de mais de 1 MB nem é lido: não é uma exportação de ajustes.
- O caminho digitado aceita aspas simples ou duplas e variáveis como `%USERPROFILE%`.

**Criar ponto de restauração**
- As explicações (Proteção do Sistema desativada, nenhum ponto no PC, limite de um por dia, aviso do Windows) viraram linhas de informação do resumo.

**O que não foi visto:** como nas builds anteriores, nada disto rodou num Windows de verdade, e a prévia da página foi desenhada a partir das medidas do código, e não capturada da janela. Pedem conferência num PC:
- ocultar a pesquisa e o botão Visão de Tarefas no Windows 10 e no 11;
- Finalizar tarefa numa 22H2 e numa 23H2, e o botão do Copilot numa 24H2;
- desfazer depois de mudar o valor pelas Configurações do Windows.

A lista da 3.31 do que pede conferência continua valendo.

### Estrutura
- **`Tweaks`:** `New-WinForgeTweak` e `New-WinForgeRegistryTweak` ganham `-MinBuild` e `-MaxBuild`, que `Test-WinForgeTweakAvailable` aplica quando a build é conhecida; `Test-WinForgeTweakValueAtTarget`; `New-WinForgeTweakRevertReport` (o que cada desfazer devolve: `Restored` e `Kept`); `Invoke-WinForgeTweakRevert -Detailed`; `Format-WinForgeTweakAppliedAt`; `Invoke-WinForgeTweakApply -Status`.
- **`Navigation`:** o índice da busca só leva os ajustes disponíveis quando a build do Windows é conhecida.
- **Janela:** `Get-GuiTweaksHintText`.

## Build 3.42

Esta build revisa a tela de Rede inteira, nos mesmos sete pontos das revisões anteriores: se cada opção faz o que promete, segurança e robustez, interface e fluxos, código, desempenho e erros comuns e incomuns. O foco é o que a pessoa precisa saber para resolver um problema de internet: onde está o gargalo, qual DNS é de fato mais rápido daqui e o que o Windows sabe do Wi-Fi.
- **Ping legível:** uma linha por alvo no lugar da tabela de sete colunas, que quebrava na janela.
- **Latência no teste de velocidade:** o tempo de ida e volta até o servidor, que pesa em jogos e chamadas de vídeo.
- **DNS medido:** o tempo de resposta do DNS atual e de cada opção, deste PC; o destaque vai para o mais rápido, e para nenhum quando trocar não ajudaria.
- **Cloudflare para famílias:** nova opção de DNS, que bloqueia sites adultos e maliciosos.
- **Wi-Fi e proxy nas informações de rede:** rede, sinal, padrão, banda e canal; o tipo de rede; o proxy configurado.
- **Plano de dados:** numa conexão limitada, o teste de velocidade avisa da franquia e pergunta com Não como padrão.

### Mudou para quem usa

**A página**
- **Testar velocidade da internet** e **Trocar o servidor DNS** dizem nos cartões o que passaram a mostrar, e **Informações de rede** cita o Wi-Fi e o proxy. A busca acha o DNS por "controle parental" e "bloquear sites adultos", e as informações de rede por "proxy".

**Informações de rede**
- **Uma seção por adaptador ativo**, com tudo o que é dele junto: a placa, a velocidade do link (com vírgula decimal, "866,7 Mbps"), o MAC, o IP, o gateway e o DNS, agora IPv4 e IPv6 (cada família só com os endereços dela, e sem os `fec0:0:0:ffff::1` a `3` que o Windows põe quando não há DNS IPv6). Antes, os adaptadores vinham numa tabela e a configuração IP noutra parte da tela. Um adaptador ativo sem endereço diz isso, em vez de sumir; uma interface com IP que não está na lista de adaptadores (uma VPN, por exemplo) ganha a sua seção.
- **Wi-Fi:** a rede, o sinal e a conexão (o padrão, como "802.11ax (Wi-Fi 6)", Wi-Fi 6E na banda de 6 GHz ou Wi-Fi 7, a banda e o canal), lidos do `netsh wlan show interfaces` em português ou em inglês. Sinal abaixo de 40% vem em amarelo, com a dica de aproximar o PC do roteador ou usar cabo. No Windows 11 com a Localização desligada, o Windows não informa o Wi-Fi; a tela diz para ativá-la em Privacidade e segurança.
- **Tipo de rede:** privada, pública ou de domínio, como o Windows decidiu ao conectar.
- **Internet:** o proxy configurado (servidor manual e script de configuração automática) e o IP público, com a fonte ("consultado em api.ipify.org"). Usuário e senha embutidos no endereço do proxy nunca aparecem, mesmo com "@", "/" ou ";" na senha, e o endereço do script sai sem a consulta ("?..."), que às vezes leva uma chave de acesso.
- **Robustez:** a configuração IP que o Windows não consegue informar (uma interface com problema, comum com VPN ou adaptadores virtuais) não derruba mais a tela: os adaptadores, o Wi-Fi, o proxy e o IP público aparecem, as seções dizem que o IP não pôde ser lido e a faixa fica amarela. Sem o serviço de Wi-Fi, ou sem o tipo de rede, a tela sai igual, só sem esses detalhes.

**Testar conectividade (ping)**
- **Uma linha por alvo:** "Cloudflare DNS (1.1.1.1) : OK · média 12 ms (mín. 10, máx. 15)", "Instável · 25% de perda · ..." ou "Sem resposta". A tabela de sete colunas não cabia na janela e quebrava as linhas.
- **O andamento** ("1 de 5: Cloudflare DNS (1.1.1.1)") fica na barra de progresso, e não no resumo depois do fim.

**Testar velocidade da internet**
- **Latência:** antes do download, pedidos vazios ao mesmo servidor medem o tempo de ida e volta (o primeiro, que abre a conexão, não conta; vale a mediana dos outros três). Como no medidor do próprio Cloudflare, sai de cada pedido o tempo que o servidor diz ter gasto (cabeçalho `Server-Timing`). Ela aparece no resultado e na faixa, na ordem da tela ("latência 18 ms, download 95,3 Mbps, upload 20,1 Mbps"). Uma falha no meio fica com as amostras que já havia; sem nenhuma, o resto sai igual, sem a linha. Só o primeiro pedido espera até 10 s; os outros, 5 s.
- **Conexão limitada:** com o Windows tratando a conexão como plano de dados (celular roteado, chip, rede marcada como limitada), a tela avisa em amarelo, antes da pergunta, que os cerca de 35 MB saem da franquia, e a pergunta vem com **Não** como padrão.
- **O andamento** (latência e download, depois upload) fica na barra de progresso; "Download concluído" e "Upload concluído" não ocupam mais o resumo, que fica com as falhas e o resultado.

**Reparar rede e DNS**
- **Proxy:** o diagnóstico mostra o proxy configurado, que nenhum comando do reparo muda, e a tela diz onde conferi-lo nas Configurações do Windows. Um proxy deixado por um programa explica a internet que só funciona em alguns programas.
- **Depois do reparo:** a conferência da conexão depois dos comandos ganha a sua seção. As linhas do diagnóstico ficam alinhadas ("Conexão segundo o Windows" passava da coluna).
- **O andamento** de cada comando e da espera pela conexão fica na barra de progresso; no resumo, uma linha por comando, a do resultado. Os avisos de antes da pergunta (IP fixo, a conexão que pode cair) não contam mais como resultado.

**Trocar o servidor DNS**
- **Tempo de resposta:** antes do menu, o WinForge consulta três nomes de sites comuns direto em cada servidor (sem o cache do Windows) e mostra a mediana ao lado de cada opção ("· 12 ms") e do servidor medido no DNS atual de cada adaptador ("192.168.0.1 (4 ms)"). Um servidor que não responde, quando os outros respondem, aparece como "sem resposta deste PC"; sem nenhuma resposta, os tempos não aparecem. Um servidor que não responde ao primeiro nome não é consultado de novo, e depois de dois DNS públicos seguidos sem resposta os outros nem são consultados: o menu não fica esperando o tempo limite de cada um. A barra de progresso diz qual está sendo medido ("Cloudflare (1.1.1.1)").
- **Destaque:** a opção mais rápida entre as que não filtram conteúdo; para não pular entre execuções por 1 ou 2 ms, a primeira medida só perde para uma claramente mais rápida (mais de 5 ms e mais de 20%). Nenhuma fica em destaque quando o DNS atual já responde tão rápido quanto a melhor (o roteador costuma responder do cache em poucos ms), e a tela diz que trocar não deve deixar as páginas mais rápidas, nem quando nenhum DNS público responde: aí a tela avisa, antes da pergunta, que a rede parece bloquear DNS externo e que o melhor é manter o atual. Sem medição, o Cloudflare, como antes.
- **Cloudflare para famílias:** bloqueia sites adultos e maliciosos (1.1.1.3, 1.0.0.3 e os IPv6 publicados pela Cloudflare). Por filtrar conteúdo, nunca é a sugerida em destaque.
- A conferência do novo DNS fica na barra de progresso.

**Relatório de Wi-Fi**
- A geração fica na barra de progresso, e o "Como ler" vira uma dica do resumo.

**O que não foi visto:** como nas builds anteriores, nada disto rodou num Windows de verdade, e a prévia da página foi desenhada a partir das medidas do código, e não capturada da janela. Pedem conferência num PC:
- a saída do `netsh wlan show interfaces` em português e em inglês, com a acentuação que chega ao WinForge;
- o tempo de resposta do `Resolve-DnsName` com servidor escolhido, numa rede comum e numa que bloqueia DNS externo;
- a latência do teste de velocidade comparada à de um medidor conhecido;
- o proxy lido das Configurações do Windows, manual e por script;
- o aviso da Localização no Windows 11 e o cabeçalho `Server-Timing` do servidor do teste de velocidade.

A lista da 3.31 do que pede conferência continua valendo.

### Estrutura
- **`Network`:** `Format-WinForgePingLine`, `Get-WinForgeProxySettings`, `Measure-WinForgeSpeedLatency` (chamada por `Measure-WinForgeDownload`, que devolve `LatencyMs`), `Get-WinForgeServerTimingMs`, `ConvertFrom-WinForgeWlanInterfaces`, `Get-WinForgeWifiLinkText`, `Get-WinForgeNetworkCategoryText`, `Test-WinForgeDnsPlaceholder` e `Write-WinForgeNetworkConfig`. O ping e as informações de rede não usam mais `Format-Table`.
- **`NetworkTools`:** `Measure-WinForgeDnsLatency`, `Get-WinForgeDnsPrimaryServer`, `Get-WinForgeDnsLatencyText`, `Get-WinForgeDnsSuggestion` e `Format-WinForgeDnsModeLatency`; os provedores de DNS ganham `Filters`.

## Build 3.41

Esta build revisa a tela de Programas inteira, nos mesmos sete pontos das revisões anteriores: se cada opção faz o que promete, segurança e robustez, interface e fluxos, código, desempenho e erros comuns e incomuns. As telas de instalar e desinstalar já tinham sido revistas a fundo. Desta vez o foco é o que a pessoa vê antes de escolher: o que já está instalado, o que não deve sair do PC e o que cada recurso puxa junto.
- **Desinstalar sem quebrar o Windows:** o próprio winget, a Microsoft Store e as bibliotecas dos aplicativos saem da lista; bibliotecas compartilhadas e drivers vêm com aviso.
- **Já instalado:** os essenciais e a busca mostram o que já está no PC.
- **Histórico:** o que foi instalado ou atualizado entra no Histórico de mudanças, como já acontecia com o que foi desinstalado.
- **Remover aplicativos:** mais aplicativos na lista, o aviso de que o Teams novo é também o de trabalho e o dos aposentados pela Microsoft, que não voltam pela Store.
- **WSL completo:** ligar o WSL leva junto o que o WSL 2 precisa.
- **Backup:** os drivers de um backup de outro modelo de PC vêm desmarcados.

### Mudou para quem usa

**A página**
- Cada cartão tem o seu ícone. Antes, **Desinstalar programas** e **Remover aplicativos do Windows**, **Aplicativos instalados** e **Programas e Recursos**, e **Gerenciar inicialização** e **Aplicativos de inicialização** tinham o mesmo.
- As descrições de **Listar programas instalados** e **Buscar e instalar programas** dizem o que cada uma faz.

**Desinstalar programas**
- **Componentes do Windows ficam de fora:** o Instalador de Aplicativo (o próprio winget, sem o qual esta página para), a Microsoft Store, a Segurança do Windows e as bibliotecas dos aplicativos da Store (VCLibs, UI.Xaml, .NET Native, Windows App Runtime), venham com o ID do pacote no Windows ou com o do repositório do winget. A tela diz quantos ficaram de fora.
- **Avisos na lista:** bibliotecas que outros programas usam (Visual C++, o Windows Desktop Runtime e os runtimes do .NET, WebView2, DirectX) dizem que removê-las pode fazer outros programas pararem de abrir; drivers instalados como programa (vídeo, rede, Wi-Fi, Bluetooth, touchpad, chipset, o pacote da AMD) dizem que o aparelho pode parar. Atualizadores e desinstaladores de drivers, SDKs e ferramentas de desenvolvimento não ganham o aviso. Nada é impedido: a pessoa decide sabendo.

**Listar programas instalados**
- Os componentes do Windows ficam fora da conta, numa linha própria que diz quantos são, e o total conta só programas.

**Instalar programas essenciais e Buscar e instalar programas**
- **Já instalado:** o que já está no PC aparece assim na lista, e a tela diz quantos são. Marcado, ele é atualizado se houver versão nova. A leitura do que está instalado vale por 2 minutos, para buscar de novo logo depois não ler outra vez, e é refeita depois de instalar, atualizar ou desinstalar, de remover aplicativos do Windows e de restaurar um backup.
- **A busca** mostra uma vez só um programa que o winget repete (nome e etiqueta batendo com o termo) e instala pela fonte de onde o resultado veio (winget ou Microsoft Store).
- **Histórico:** os programas instalados entram no **Histórico de mudanças**, e os que já estavam no PC e foram atualizados entram como atualizados; o que o winget disse que já estava na versão nova, não.

**Erros do winget**
- **Mais códigos com frase:** programa instalado só para o usuário, que o winget não altera como Administrador (`0x8A15007D`), e instalador que não roda como Administrador (`0x8A150056`), os dois apontando **Sobre o WinForge > Modo de Administrador**; política da organização (`0x8A15010F`) ou da Microsoft Store (`0x8A15001B`, `0x8A15001C`); dependência faltando (`0x8A150104`, `0x8A150110`); memória (`0x8A150106`); PC ou Windows incompatível (`0x8A150113`); erro do instalador (`0x8A150108`, `0x8A150115`); versão nova com outro tipo de instalador (`0x8A15008E`); mais de um pacote com o ID (`0x8A150016`); a fonte do pacote pedindo conta (`0x8A150076`); winget sem fontes (`0x8A150015`).

**Remover aplicativos do Windows**
- **O Teams novo** diz que é também o de trabalho ou escola: removê-lo remove o Teams da pessoa.
- **Novos na lista:** Bing Pesquisa, Cortana, Email e Calendário, Power Automate, Microsoft To Do, Xbox e LinkedIn. Do Xbox só entra o aplicativo; a Game Bar e os componentes que os jogos usam não são alcançados. Os que muita gente usa dizem para manter se você usa.
- **Os aposentados não voltam:** Skype, Cortana e Email e Calendário, aposentados pela Microsoft, dizem na lista que não voltam depois de removidos (e Email e Calendário, que os e-mails guardados só no PC são apagados), a tela repete isso antes da confirmação, e o Histórico não promete a volta pela Store para eles.

**Recursos opcionais do Windows**
- **WSL:** ligar o WSL leva junto a Plataforma de Máquina Virtual, de que o WSL 2 precisa. A tela avisa antes o que ela traz: o hipervisor do Windows ligado a cada início, que pode atrapalhar versões antigas do VirtualBox e do VMware, alguns emuladores de Android e o antitrapaça de alguns jogos. Cada um entra no Histórico separado, para desfazer um sem o outro. Depois de ligar, a tela diz como instalar um Linux (pela Microsoft Store ou com `wsl --install`) e que a virtualização precisa estar ligada na BIOS.
- **Desligar com aviso:** desligar a Plataforma de Máquina Virtual (o WSL 2 e programas como o Docker Desktop param) ou o Hyper-V (as máquinas virtuais dele param; os arquivos delas continuam no disco) mostra o alerta, e a confirmação vem com **Não** como padrão, como já era ao ligar o SMB 1.0.
- **Erro com frase:** `0x800F0954`, comum no .NET 3.5 quando o PC busca atualizações num servidor de empresa (WSUS).

**Backup antes de formatar e Restaurar a partir de um backup**
- **O modelo do PC:** o backup guarda o fabricante e o modelo, que, ao contrário do nome do computador, não mudam ao formatar. Na Lenovo, que põe no modelo a configuração da máquina, vale a família ("ThinkPad T490"). Uma máquina virtual ou uma placa genérica não guardam modelo. A restauração mostra o modelo de origem; com um backup de outro modelo, avisa e traz os drivers desmarcados (eles são para aquele PC). Backups antigos, sem o modelo, continuam como antes.

**No console**
- Nas listas de marcar, um nome com mais de 30 caracteres não gruda mais na descrição.

**O que não foi visto:** como nas builds anteriores, nada disto rodou num Windows de verdade, e as prévias da página foram desenhadas a partir das medidas do código, e não capturadas da janela. Pedem conferência num PC:
- as tabelas reais do `winget list` e do `winget search` com os componentes e a marca de já instalado;
- a instalação pela fonte do resultado (`--source winget` e `--source msstore`);
- os novos nomes de pacotes da lista de aplicativos, e se os aposentados ainda estão fora da Microsoft Store;
- ligar o WSL com a plataforma no Windows 10 e no 11;
- o modelo lido do PC para o backup.

A lista da 3.31 do que pede conferência continua valendo.

### Estrutura
- **`Software`:** `Test-WinForgeWingetComponent`, `Get-WinForgeWingetPackageCaution`, `Get-WinForgeInstalledWingetIds` (com a leitura guardada em `$script:WinForgeInstalledIdsCache`, que `Clear-WinForgeInstalledWingetIdsCache` descarta), `Test-WinForgeWingetIdInstalled` e `Add-WinForgeInstalledProgramsChange`; `Get-WinForgeWingetArguments -Source`; o resultado de `Invoke-WinForgeWingetPackages` traz `ChangedIds`.
- **`PreinstalledApps`:** sete aplicativos novos no catálogo e o campo `Reinstallable`.
- **`WindowsFeatures`:** o campo `RiskOnDisable` no catálogo.
- **`Backup`:** `Get-WinForgePcModel`; o campo `Model` no `backup.json` e em `Read-WinForgeBackupFolder`; `Get-WinForgeRestoreOptions -OtherModel`.
- **Janela:** os ícones (`GuiDesign`).

## Build 3.40

Esta build revisa a tela de Atualizações inteira, nos mesmos sete pontos das revisões anteriores: se cada opção faz o que promete, segurança e robustez, interface e fluxos, código, desempenho e erros comuns e incomuns. A instalação pelo Windows Update já tinha sido revista a fundo. Desta vez o foco é o que faltava em volta dela: o que fazer quando o próprio Windows Update quebra, para que serve cada driver e qual programa de fabricante serve para cada PC.
- **Corrigir o Windows Update:** um item novo refaz o cache do Windows Update e religa os serviços, como a Microsoft indica quando as atualizações falham ou travam.
- **Drivers explicados:** cada driver diz para que serve; um firmware (como a BIOS) é avisado antes.
- **Antes de baixar:** reinício pendente e bateria também nos drivers; numa conexão limitada, a tela diz quanto vai ser baixado.
- **Ferramenta do fabricante certa:** Dell e Lenovo têm uma para a linha de empresa e outra para a de uso pessoal; a tela indica a da linha do PC.
- **Mais erros explicados,** com o item do WinForge que resolve, e a política que bloqueia o Windows Update é dita quando a consulta falha.

### Mudou para quem usa

**A página**
- **Corrigir o Windows Update** entra na seção Windows e drivers.
- **Atualizações opcionais e drivers** passa a se chamar **Atualizações opcionais**: o nome antigo se confundia com **Atualizar drivers**.
- Cada cartão tem o seu ícone: **Atualizar programas (winget)** e **Windows Update**, e **Atualizações opcionais** e **Atualizar drivers**, tinham o mesmo.
- As descrições de **Atualizar programas (winget)**, **Atualizações da Microsoft Store** e **Atualizações opcionais** dizem o que cada uma faz.

**Corrigir o Windows Update (novo)**
- **O que faz:** desliga os serviços Windows Update, BITS e Serviços de Criptografia, põe de lado o cache (as pastas `SoftwareDistribution\Download` e `SoftwareDistribution\DataStore` e o `catroot2`, os passos da página de erros comuns do Windows Update, da Microsoft) e liga os serviços de novo. Os downloads são apagados depois que os serviços já estão ligados de novo; o banco de dados e o `catroot2` ficam guardados como `.bak`, e a cópia de uma vez anterior sai antes.
- **Antes de perguntar,** a tela diz que as atualizações instaladas continuam instaladas e que a lista do histórico nas Configurações recomeça vazia.
- **Serviço desativado:** um serviço desativado por um "otimizador" ou bloqueador (inclusive o orquestrador de atualizações) é avisado antes e volta ao padrão do Windows. Se ele não voltar, o reparo para aí, sem mexer no cache: refeito, ele não adiantaria, e o histórico das Configurações se perderia à toa. O Windows Update Medic desativado é dito; o Windows protege esse serviço, e o WinForge não mexe nele.
- **Serviço que não existe:** um serviço removido por um script de limpeza é dito como tal, com a saída possível (**Reparo > Recuperação**); antes de um serviço sem resposta, a tela indica o reparo dos arquivos do Windows.
- **O que ele não faz:** não roda com o Windows Update no meio de uma instalação (confere antes e de novo depois da pergunta, e pede para esperar), não muda políticas (diz quando há uma) e não segue uma pasta que aponta para outro disco, nem um atalho dentro dos downloads ao apagá-los. Com um reinício pendente, sugere reiniciar antes, com Não em destaque.
- **Quando algo falha:** um serviço "parando" ou "iniciando" ganha tempo em vez de virar erro; um que não para em 30 segundos cancela tudo sem mexer no cache. Uma pasta em uso fica como estava, e a faixa diz qual; uma que aponta para outro lugar também, com o que fazer. Os serviços voltam a ligar mesmo assim, e um que não liga pede o reinício.
- O que foi feito fica no **Histórico de mudanças**: o serviço que voltou ao padrão e o cache refeito, cada um quando acontece.

**Instalar atualizações do Windows**
- **Drivers na lista:** um driver diz que é driver e de quê: "driver de som: Realtek(R) Audio · até 2 MB".
- **Firmware:** um firmware escolhido (a BIOS ou o de um componente) é avisado antes da confirmação: termina no reinício, sem desligar o PC e, num notebook, na tomada.
- **Conexão limitada:** numa conexão marcada como limitada (celular roteado, chip, rede marcada assim nas Configurações), a tela diz quanto vai ser baixado antes de perguntar, porque isso pode consumir a franquia. O próprio Windows não baixa sozinho numa conexão assim.
- **Mais erros com frase:** acesso bloqueado por política (`0x8024002E`), sem internet ou conexão que caiu (`0x8024001F`, `0x80072EFD`, `0x80072EFE`), servidor que recusa ou demora (`0x80244017`, `0x80244018`, `0x8024401C`), reinício necessário (`0x80070BC9`) e arquivo em uso (`0x80070020`).
- **O caminho de cada erro:** os de cache (`0x80242006`, `0x80248007`, `0x8007000D`, `0x80246008`, e `0x8024200D` e `0x80246007` quando voltam) e o serviço desativado (`0x80070422`) apontam **Atualizações > Corrigir o Windows Update**; os de arquivos do Windows faltando (`0x800F081F`, `0x800F0831`, `0x80073701`) apontam **Reparo > Reparar o Windows (DISM + SFC)**.
- **A consulta que falha:** com uma política que manda buscar num servidor de empresa ou que desliga o acesso ao Windows Update (nas duas chaves de política em que o Windows a lê, e também a que proíbe ir ao Windows Update na internet), a tela diz isso e quem costuma pôr a política. Sem política e sem ser a conexão, indica **Corrigir o Windows Update**.
- **O andamento do download** conta só o que falta baixar: "1 de 2", e não "1 de 3", quando uma das três já estava baixada.
- O que foi instalado entra no **Histórico de mudanças**, pelo número KB quando houver.

**Atualizar drivers**
- **Para que serve cada um:** a descrição traz a classe e o aparelho ("recomendado · vídeo: Intel(R) UHD Graphics 620 · até 300 MB"). O título do Windows Update ("Intel - System - 10.1.1.44") se repete para aparelhos diferentes, e antes eles eram iguais na lista.
- **As mesmas conferências da instalação:** um reinício pendente ou o notebook na bateria são perguntados antes da busca, com Não em destaque. Um firmware interrompido por falta de energia pode deixar o PC sem ligar.
- O aviso de firmware e o da conexão limitada, como na instalação das atualizações.

**Ferramentas do fabricante**
- **A linha do PC:** a Dell tem o Dell Command | Update para Dell Pro e Pro Max, Latitude, OptiPlex, Precision, Vostro e XPS, e o Dell SupportAssist para Inspiron, Alienware e G; a Lenovo tem o Lenovo System Update para ThinkPad, ThinkCentre e ThinkStation, e o Lenovo Vantage para IdeaPad, Yoga, Legion, ThinkBook e outros. Antes, todo PC Dell recebia o Command | Update e todo Lenovo o System Update, que dizem que o PC não é compatível nas outras linhas.
- **O modelo de um Lenovo** aparece com o nome: "IdeaPad 5 14IAL7 (82XQ)", e não só o tipo de máquina. Nos outros fabricantes, a família é código interno e fica de fora. Uma placa genérica ("To Be Filled By O.E.M.") não aparece como fabricante nem como modelo.
- **A AMD** abre a página atual da detecção automática; a HP, o site de drivers, agora com esse nome. O Lenovo Vantage abre a busca da Microsoft Store.
- A tela diz "Abrindo a página do NVIDIA App no navegador.", e não que a página foi aberta: o Windows só recebeu o pedido.

**Atualizar programas (winget)**
- **O winget por último:** o Instalador de Aplicativo, que é o próprio winget, é atualizado depois dos outros programas, que ainda precisam dele.
- Os programas atualizados entram no **Histórico de mudanças**; os que o winget disse que já estavam na versão nova, não.

**O que não foi visto:** como nas builds anteriores, nada disto rodou num Windows de verdade, e as prévias da página foram desenhadas a partir das medidas do código, e não capturadas da janela. Pedem conferência num PC:
- **Corrigir o Windows Update** inteiro: parar e ligar os serviços, o `catroot2` (que o Windows costuma religar rápido), e um serviço desativado voltando ao padrão;
- a pergunta ao Windows Update se ele está instalando (`IsBusy`);
- a conexão limitada lida pelo Windows;
- a classe e o aparelho dos drivers vindos do Windows Update;
- as políticas de servidor de empresa e de acesso desligado;
- a busca da Microsoft Store pelo Lenovo Vantage e as páginas da Dell e da AMD.

A lista da 3.31 do que pede conferência continua valendo.

### Estrutura
- **`WindowsUpdate`:**
  - `Repair-WinForgeWindowsUpdate`, com `Get-WinForgeWindowsUpdateServices`, `Get-WinForgeWindowsUpdateCacheFolders`, `Get-WinForgeServiceState`, `Stop-WinForgeService`, `Start-WinForgeService`, `Set-WinForgeServiceStartType`, `Move-WinForgeUpdateCacheFolder`, `Remove-WinForgeUpdateCacheBackup`, `Get-WinForgeServiceNamesText` e `Test-WinForgeWindowsUpdateBusy`.
  - `Get-WinForgeWindowsUpdatePolicy`, `Write-WinForgeWindowsUpdatePolicyNote` e `Write-WinForgeWindowsUpdateSearchHelp`.
  - `Confirm-WinForgeUpdateConditions` (reinício pendente e bateria, para as atualizações e os drivers), `Get-WinForgeDriverClassText`, `Get-WinForgeDriverPurposeText`, `Test-WinForgeFirmwareUpdate`, `Write-WinForgeFirmwareWarning` e `Write-WinForgeMeteredWarning`.
  - A busca devolve também `Driver`, `DriverClass` e `DriverModel`.
- **`Drivers`:** `Test-WinForgeVendorText` e `Get-WinForgeHardwareModelText`; `Get-WinForgeHardwareVendors` lê também a família do PC (`Family`); o catálogo ganhou `dell-supportassist` e `lenovo-vantage` e os campos `Open` e `Store`.
- **`Core`:** `Test-WinForgeMeteredConnection`.
- **`Software`:** o plano do winget põe o Instalador de Aplicativo por último e anota no Histórico; o resultado de `Invoke-WinForgeWingetPackages` traz também `ChangedIds`.
- **Janela:** o item `updates.repair` (`Navigation`) e os ícones (`GuiDesign`); o atalho `OptionalUpdates` com o título novo (`Shortcuts`).

## Build 3.39

Esta build revisa a tela de Reparo inteira, nos mesmos sete pontos das revisões anteriores: se cada opção faz o que promete, segurança e robustez, interface e fluxos, código, desempenho e erros comuns e incomuns. As ferramentas já tinham sido revistas a fundo em builds anteriores. Desta vez, o que muda é o que acontece em volta delas: qual disco o CHKDSK verifica, o que continua com problema depois de detectar dispositivos e para onde ir quando o reparo não resolve.
- **CHKDSK em qualquer disco do PC:** com mais de um disco NTFS, você escolhe qual verificar.
- **Dispositivos depois da busca:** os que continuam com problema aparecem com o nome; antes, a busca terminava verde.
- **SSD ou HD dito antes:** a otimização diz o que vai fazer e quanto costuma demorar.
- **Quando o reparo não resolve:** Restauração do Sistema e Recuperação ficam na própria página, e a tela aponta as duas.
- **Mais erros explicados:** o DISM num PC configurado para um servidor de empresa (WSUS), com o Windows Update desativado ou com reinício pendente, e o SFC que nem consegue começar.

### Mudou para quem usa

**A página**
- **Ferramentas do Windows:** uma terceira seção com **Restauração do Sistema** (voltar o PC a um ponto de restauração) e **Recuperação** (a página das Configurações com "Restaurar o PC", a reinstalação pelo Windows Update no Windows 11 e a inicialização avançada). São o próximo passo quando DISM e SFC não resolvem, e antes ficavam só na Manutenção (a Restauração) ou fora do WinForge (a Recuperação).
- **Ao abrir um atalho:** a tela diz "Abrindo: Recuperação.", em vez de "Recuperação aberto.", que errava o gênero e afirmava antes da hora que a janela abriu.

**Reparar o Windows (DISM + SFC)**
- **O próximo passo:** quando o reparo roda até o fim e o SFC continua encontrando arquivos que não consegue reparar, a tela termina indicando **Reparo > Restauração do Sistema** (se houver um ponto de restauração) e **Reparo > Recuperação**, com o que cada opção mantém: no Windows 11, reinstalar pelo Windows Update mantém programas e arquivos; "Restaurar o PC" mantém os arquivos, mas remove os programas. Quando o caminho é outro (reiniciar, a internet, um serviço desativado), a tela não sugere reinstalar.

**Reparar imagem e componentes (DISM)**
- **Mais erros com frase:** `0x800F0954` (o PC está configurado para buscar atualizações num servidor da empresa, o WSUS, que não tem os arquivos do reparo; num PC de casa, a configuração costuma vir de um bloqueador de atualizações ou de um "otimizador"), `0x80070422` (o Windows Update está desativado: volte-o para Manual em Serviços) e `0x800F0806`, `0x800F082F` e `3017` (o Windows tem operações esperando um reinício: reinicie e rode de novo; o resumo pede o reinício). Antes, apareciam só como o código.

**Verificar arquivos do sistema (SFC)**
- **O SFC que nem começa:** quando o Windows diz que não pôde iniciar o serviço de reparo, a tela explica que o SFC depende do serviço Instalador de Módulos do Windows, que alguns "otimizadores" desativam, e como voltar.

**Verificar o sistema de arquivos (CHKDSK)**
- **Qual unidade:** com mais de um disco NTFS no PC, a tela pergunta qual verificar, com o espaço de cada um e a do Windows em destaque; a escolha já vale como a confirmação. Um HD ou SSD externo, pela USB, aparece como "disco externo (USB)". Pendrives, cartões, unidades FAT32, exFAT ou ReFS (o `/scan` é só do NTFS) e unidades trancadas pelo BitLocker ficam de fora. Com uma unidade só, ou dentro da Manutenção recomendada, continua sendo a do Windows, como antes.
- **Reparo offline na unidade certa:** quando a verificação pede reparo offline, ele é agendado na unidade verificada, e a tela diz qual. Ela também avisa que o reparo roda ao **Reiniciar**, e não ao Desligar e ligar (com a Inicialização Rápida do Windows, ele pode não rodar), e, num disco externo, que ele precisa estar conectado.

**Detectar dispositivos e drivers**
- **O que continua com problema:** depois da busca, o WinForge espera até 20 segundos o Windows terminar de instalar os drivers que ela achou e confere os dispositivos com as mesmas regras de **Diagnóstico > Dispositivos com problema**. Com algum ainda com problema, a faixa fica amarela ("a busca terminou, mas 1 dispositivo ainda aparece com problema"), com o nome, o problema e o caminho para ver mais; os desativados de propósito não contam, e um dispositivo esperando o reinício faz o resumo pedir o reinício. Sem nenhum, a faixa diz isso, e, sem conseguir ler os dispositivos, não afirma nada. Antes, a busca terminava sempre em verde, mesmo com a câmera ou o som que levaram a pessoa até ali ainda sem funcionar.
- **Na Manutenção recomendada:** os nomes vão nas observações da etapa, que continua verde: um problema que a busca não resolve, como um celular pareado sem driver, não deixa a manutenção amarela todo mês.

**Otimizar a unidade do sistema**
- **SSD ou HD:** antes de perguntar, a tela diz o que o Windows vai fazer no disco do PC: num SSD, o TRIM, que costuma levar segundos (desfragmentar, só raramente, quando o próprio Windows vê necessidade); num HD, a desfragmentação, que pode levar de minutos a horas. Sem saber o tipo do disco, as duas possibilidades, como antes. Dentro da Manutenção recomendada, o tipo do disco não é lido, para não atrasar a etapa.

**Robustez**
- A unidade do Windows não depende mais só da variável `SystemDrive`: sem ela, sai da pasta do Windows e, sem nenhuma das duas, é `C:`, em vez de um comando sem unidade.
- A leitura dos discos do CHKDSK tem limite de 15 segundos e mostra o progresso, em vez de deixar a tela parada se o WMI travar.

**O que não foi visto:** como nas builds anteriores, nada disto rodou num Windows de verdade, e as prévias da página foram desenhadas a partir das medidas do código, e não capturadas da janela. Pedem conferência num PC:
- o CHKDSK `/scan` numa unidade que não é a do Windows, e o reparo offline agendado nela;
- o `Win32_LogicalDisk` de uma unidade trancada pelo BitLocker;
- o reparo agendado num disco externo e a Inicialização Rápida ao Desligar;
- o `Get-PnpDevice` depois do `pnputil /scan-devices`, e se 20 segundos bastam para o Windows terminar de instalar um driver;
- o tipo do disco lido para a otimização;
- os códigos `0x800F0954`, `0x80070422`, `0x800F0806`, `0x800F082F` e `3017` do DISM;
- a página `ms-settings:recovery` no Windows 10 e no 11.

A lista da 3.31 do que pede conferência continua valendo.

### Estrutura
- **`Repair`:** `Get-WinForgeSystemDriveLetter`, `Get-WinForgeChkdskDrives`, `Test-WinForgeDriveExternal`, `Select-WinForgeChkdskDrive`, `Get-WinForgeDriveMediaText` e `Get-WinForgeDeviceScanRemaining -NotesOnly -SettleSeconds`; `Invoke-WinForgeScheduleChkdskRepair -Drive`; a detecção de dispositivos tem um analisador próprio. O analisador de `Invoke-WinForgeTool` recebe um quarto argumento, se a ação roda dentro de um fluxo.
- **`Shortcuts`:** o atalho `Recovery` (`ms-settings:recovery`); a mensagem ao abrir um atalho.
- **Janela:** os itens `repair.system-restore` e `repair.recovery` (`Navigation`) e os ícones deles (`GuiDesign`).

## Build 3.38

Uma revisão da tela de Desempenho por inteiro, nos mesmos sete pontos das revisões anteriores: se cada opção faz o que promete, segurança e robustez, interface e fluxos, código, desempenho e erros comuns e incomuns. Liberar memória deixa de jogar fora o cache de arquivos do Windows, o que deixava o PC mais lento logo depois. Programas pesando agora passa a mostrar a mesma memória do Gerenciador de Tarefas.
- **O cache de arquivos fica:** ele já conta como memória disponível, e esvaziá-lo só fazia o Windows ler tudo de novo do disco.
- **Só os seus programas:** liberar memória não mexe mais nos serviços do Windows (o antivírus, por exemplo) nem nos programas de outras contas.
- **A memória de verdade de cada programa:** um navegador com 30 processos aparecia com várias vezes a memória que usa.
- **Sem palpite:** um programa aberto como Administrador mostra o processador "sem leitura", e não "quase parado"; os do Windows vêm com a marca "do Windows".
- **Fechar com cuidado:** um programa sem janela (perto do relógio, uma máquina virtual, uma gravação) não é mais encerrado à força sem uma pergunta à parte, e um processo de mesmo nome que é de outro programa fica.
- **O motivo de cada janela que não fechou:** caixa de diálogo aberta, janela perguntando se quer salvar ou programa que foi para perto do relógio.
- **Gerenciar inicialização também nesta página.**

### Mudou para quem usa

**A página**
- **Duas seções:** **Deixar o PC mais leve** (Acelerar agora, Programas pesando agora e Liberar memória) e **Para o PC continuar leve**, com **Gerenciar inicialização** (o mesmo de **Programas > Gerenciar inicialização**, também aqui, porque o que abre junto com o Windows é o que mais pesa no dia a dia) e o Gerenciador de Tarefas, que mostra os gráficos de uso ao longo do tempo.
- **Liberar memória:** a descrição diz o que ele faz ("tira da memória o que os programas abertos ocupam") e quando ajuda ("antes de abrir algo pesado"), sem a promessa do cache de arquivos. Antes, dizia que esvaziava "a memória que os programas não estão usando", mas o Windows tira tudo o que pode, e os programas recarregam o que voltam a usar.

**Liberar memória e Acelerar agora**
- **O cache de arquivos fica:** como Administrador, o WinForge esvaziava também a lista de espera do Windows (o cache de arquivos). Ela já conta como memória disponível: esvaziá-la não aumentava a memória livre que a tela media, e o Windows tinha de ler de novo do disco o que estava pronto, o que deixava programas e arquivos mais lentos por um tempo. Agora a tela diz que o cache fica e por quê, com ou sem Administrador.
- **Só a sua sessão:** a memória esvaziada é a dos programas da sua sessão. Os serviços do Windows (o antivírus, a impressão) e os programas de outras contas logadas no PC ficam como estão, sem ter de recarregar a memória. O próprio WinForge também fica: a memória dele voltava na hora de desenhar o resultado, e entrava na conta do que foi liberado.
- O mesmo vale para a correção de memória do **Verificar o PC**, que agora diz a verdade quando não adianta: com a memória ainda alta depois de liberar (85% ou mais), ou sem medida, a correção fica em amarelo ("a memória continua alta (90%): feche o que pesa em Desempenho > Programas pesando agora") e a Memória continua entre os pontos que pedem a sua decisão. Antes, a correção contava como feita e a faixa podia ficar verde com a memória cheia.

**Programas pesando agora**
- **A memória do Gerenciador de Tarefas:** cada processo conta a memória privada dele, a mesma da coluna Memória do Gerenciador de Tarefas. Antes, contava também as bibliotecas que os processos dividem, e somar os processos de um navegador ou do Teams dava várias vezes o que eles usam de fato. Sem essa leitura do Windows, vale a memória privada de cada processo, que também não repete o que eles dividem.
- **Processador "sem leitura":** um programa aberto como Administrador, com o WinForge sem, não deixa medir o uso do processador; antes aparecia como "processador quase parado", mesmo a 100%. Com parte dos processos sem leitura e o resto parado, "sem leitura em parte". Vale também quando o Windows nega a leitura devolvendo um valor vazio, e não um erro.
- **O motivo de não fechar:** os processos que aparecem na lista dos que mais pesam e não podem ser fechados por aqui vêm com o motivo: "do Windows", "usado por vários programas" (o WebView2, que desenha o Teams e o novo Outlook), "instalação ou atualização" ou "usado pelo WinForge". Antes, tudo isso aparecia como "do Windows", e a tela dizia que o que mais pesava era "do próprio Windows".
- **A ordem da tela:** a lista vem pelo processador como ele aparece (o que está "quase parado" empata) e, no empate, pela memória; antes, um programa a 0,9% de processador e 40 MB vinha antes de um a 0,1% com 3 GB.
- **Mais processos do Windows protegidos:** tarefas em segundo plano do Windows (`backgroundTaskHost`), o `rundll32` (que hospeda partes do Windows), o teclado virtual, o editor de idiomas asiáticos (IME), o configurador do Windows e o núcleo do Defender não entram na lista para fechar.
- **Fechar sem esperar à toa:** o WinForge espera a janela fechar e segue assim que ela fecha, até 5 segundos; antes, esperava sempre 2 segundos, o que era pouco para um programa salvando e demais para um que fecha na hora.
- **Programa sem janela:** um programa que não tem nenhuma janela aberta (escondido perto do relógio, como o OBS gravando ou o Outlook minimizado; uma máquina virtual; um processo em segundo plano) era encerrado à força na hora, apesar do "é como clicar no X". Agora a tela avisa que fechar é encerrar à força e faz uma pergunta à parte, com **Não** como padrão; com Não, ele fica aberto.
- **Só os auxiliares do programa:** depois que a janela fecha, saem os processos sem janela abertos pelo próprio programa (pelo processo pai, direta ou indiretamente). Um processo de mesmo nome que é de outro programa (outro `python`, outro `javaw`) fica, e a faixa diz que ele continua aberto. Sem saber o processo pai, nenhum auxiliar é encerrado.
- **Por que não fechou:** uma janela com caixa de diálogo aberta nem recebe o pedido de fechar, e a tela diz isso na hora, sem esperar; um programa que foi para perto do relógio ao fechar a janela (Discord, Teams, Steam) aparece como "continua aberto perto do relógio", com como sair; a janela que continua aberta pode estar perguntando se quer salvar ou ter outra janela aberta.
- **O efeito, medido:** depois de fechar, a tela mostra a memória em uso agora e quanto era antes.
- **Mais rápido:** o nome amigável e o fabricante são lidos só dos programas que aparecem, e não de todos os processos abertos; a memória por processo é lida enquanto a medição do processador espera.
- **Medição mais exata:** cada processo é medido no próprio intervalo, e não no intervalo de uma lista inteira até a outra (o uso saía maior que o real); os processos de outras sessões nem são lidos. Um número de processo reaproveitado pelo Windows no meio da medição não gera mais um uso acima de 100%, nem a soma de um programa.

**O que não foi visto:** como nas builds anteriores, nada disto rodou num Windows de verdade, e as prévias da página foram desenhadas a partir das medidas do código, e não capturadas da janela. Pedem conferência num PC: a classe `Win32_PerfRawData_PerfProc_Process` (o tempo da primeira consulta e os números comparados com o Gerenciador de Tarefas), `EmptyWorkingSet` só na sessão da pessoa, `CloseMainWindow` num programa aberto como Administrador e com caixa de diálogo, programas que vão para perto do relógio, os processos pai pelo `Win32_Process` e o tempo que programas reais levam para fechar. A lista da 3.31 do que pede conferência continua valendo.

### Estrutura
- **`Performance`:** `Get-WinForgePrivateWorkingSets`, `Add-WinForgeProcessDetails`, `Get-WinForgeProcessParents`, `Test-WinForgeProcessGroupWindowless`, `Get-WinForgeProtectedProcessReason` e `Test-WinForgeMemoryHigh` (a regra dos 85%, uma só para a página, a lista e o Verificar o PC); a medição devolve `CpuUnread`; `Get-WinForgeMemoryUsage -OperatingSystem` (a página lê o Windows uma vez só); `Stop-WinForgeProcessGroup -WaitMilliseconds -AllowForce`. Saíram `Write-WinForgeStandbyNote`, `PurgeStandbyList` e o parâmetro `PurgeStandby`, e o resultado da liberação não traz mais `Purged` nem `Trimmed`.
- **`Checkup`:** um resultado com `Data.Remaining` não conta como corrigido.
- **Janela:** o item `performance.startup` (`Navigation`) e o ícone dele (`GuiDesign`).

## Build 3.37

Uma revisão da tela de Limpeza por inteiro, nos mesmos sete pontos das revisões anteriores: se cada opção faz o que promete, segurança e robustez, interface e fluxos, código, desempenho e erros comuns e incomuns. A limpeza dos temporários deixa de apagar o que uma instalação em andamento ainda usa, nada vai embora em definitivo dizendo que foi para a Lixeira, e as ferramentas de atalhos, duplicados, restos e registro passam a recusar casos em que tiravam coisas que ainda funcionam.
- **Temporários com menos de um dia ficam:** um instalador ou uma atualização em andamento quebraria sem eles.
- **A Lixeira na Limpeza rápida é escolha sua**, com o que há nela à vista.
- **Lixeira de verdade:** um item maior que o limite da Lixeira, ou numa Lixeira configurada para apagar na hora, fica onde está.
- **Atalhos, duplicados e restos mais cuidadosos:** atalhos do Office e do OneDrive, arquivos que mudaram depois da busca, pastas de jogos e pastas de outros fabricantes deixam de ser propostos.
- **Registro sem falso "quebrado":** pendrive, cartão de memória e unidade de rede não contam, e o Visual C++ não some de Aplicativos instalados.
- **Página com 12 itens em três seções**, sem os cartões soltos dos temporários (estão na Limpeza rápida e na personalizada).

### Mudou para quem usa

**A página**
- **Três seções:** **Liberar espaço** (Limpeza rápida, Analisar uso de espaço, Limpeza personalizada, Esvaziar a Lixeira, Limpar a pasta Downloads e Configurações de armazenamento), **Arrumar o que sobrou** (atalhos quebrados, duplicados e restos de programas) e **Avançado** (registro, componentes do Windows e apagar o espaço livre). Os cartões "Limpar temporários do usuário" e "Limpar temporários do Windows" saíram: a Limpeza rápida faz os dois, e a personalizada deixa escolher um só. A busca por "temp", "tmp" e "temporários" leva à Limpeza rápida.
- **Um ícone por cartão.**

**Limpeza rápida**
- **A Lixeira à vista:** com algo na Lixeira, a tela mostra quanto há nela e pergunta "Temporários e Lixeira", "Só os temporários" ou "Cancelar" (o que está na Lixeira é removido em definitivo). Com a Lixeira vazia, é só confirmar. Antes, a Lixeira era esvaziada junto, sem mostrar o que havia nela.
- **O que fica:** a tela diz que Documentos, Downloads e outros arquivos pessoais não são tocados, e que os temporários de menos de um dia e os arquivos em uso ficam.

**Temporários (na Limpeza rápida, na personalizada, no Verificar o PC e no Acelerar agora)**
- **Menos de um dia fica:** um arquivo ou uma pasta dos temporários com atividade nas últimas 24 horas não é apagado (numa pasta, vale o arquivo mais novo lá dentro). Instaladores e atualizações guardam ali o que vão usar no passo seguinte, sem deixar o arquivo aberto, e apagá-lo quebrava a instalação. O tamanho estimado e a medição da personalizada contam só o que vai sair, e a tela diz quantos itens recentes ficaram. Com só itens recentes, a tela diz que não há nada para limpar e por quê, sem perguntar.

**Limpeza personalizada e Analisar uso de espaço**
- **`MEMORY.DMP`:** o despejo completo da última tela azul (costuma ter vários GB) entra em "Despejos de memória de falhas" e aparece na análise de espaço, com a indicação de onde se limpa.
- **Otimização de Entrega:** o cache é esvaziado pelo comando do próprio Windows quando ele existe, que avisa o serviço do que saiu; se o comando falhar, a pasta é limpa diretamente e a tela diz por quê. Com a pasta do cache fora do lugar de sempre, a tela diz que o espaço liberado não pôde ser medido, em vez de "0 B".
- **OneDrive:** arquivos guardados só na nuvem não são abertos para conferir se estão em uso; abri-los fazia o Windows baixar cada um.

**A Lixeira em todas as ferramentas**
- **Limite da Lixeira:** um item maior que o limite da Lixeira da unidade fica onde está, com o tamanho e o limite na tela. Antes, o Windows o apagava em definitivo, sem perguntar, enquanto a tela dizia "na Lixeira". Vale para atalhos, duplicados, restos de programas e a pasta Downloads (que sugere "Excluir permanentemente" para esses itens). O limite é o configurado na unidade, o da política do Windows ou, sem nenhum dos dois, o padrão do Windows; um limite configurado em zero vale como "apaga na hora". Sem conseguir identificar a unidade, vale o mais cauteloso das configuradas.
- **Lixeira que apaga na hora:** com a Lixeira configurada para não guardar nada (na unidade ou por política), as ferramentas tratam a unidade como sem Lixeira: avisam e não removem.

**Remover atalhos quebrados**
- **Atalhos do Office e de outros programas MSI:** os atalhos "anunciados" do Windows Installer apontam para o produto, e não para o arquivo; o caminho que se lê deles é o de um ícone guardado em `Windows\Installer`, que outro limpador pode ter apagado. Ficam de fora, e não são mais tratados como quebrados.
- **Só disco fixo:** um atalho para um programa num pendrive, cartão de memória ou unidade de rede não conta como quebrado, mesmo que outra coisa esteja hoje naquela letra.
- **OneDrive:** um atalho da Área de Trabalho sincronizada pelo OneDrive vem desmarcado, com o aviso de que o programa pode estar instalado em outro PC seu e que o atalho sairia de lá também. Fica fora da correção com um clique do **Verificar o PC**.

**Encontrar arquivos duplicados**
- **Mudou depois da busca, fica:** antes de mover, o WinForge confere que os dois arquivos continuam com a mesma data de modificação da busca. Um disco virtual, um cofre criptografado ou uma caixa do Outlook mudam por dentro sem mudar de tamanho, e a "cópia" podia ser a única versão antiga.
- **Fica o criado primeiro:** uma cópia feita no Explorador guarda a data de modificação do original; o arquivo que fica passa a ser o criado primeiro.
- **Pastas de programas e jogos:** `Program Files`, `ProgramData`, `WindowsApps` e bibliotecas da Steam, Epic, GOG e Xbox de qualquer unidade ficam fora da busca e não podem ser escolhidas.
- **Pasta que é atalho:** uma pasta que é atalho para outra (ou fica dentro de um) é recusada, com o destino na tela; antes, `D:\Link` apontando para `C:\Program Files` passava pela trava.
- **OneDrive:** a tela diz quantos itens ficaram de fora por serem atalhos de pasta ou arquivos do OneDrive, em vez de um "Nenhum arquivo duplicado" que parecia ter olhado tudo.
- **Mais rápido, e o Parar funciona:** arquivos do mesmo tamanho são comparados primeiro pelo começo e pelo fim, e só os que empatam são lidos inteiros, em blocos; o botão **Parar** responde no meio de um arquivo grande, em vez de esperar a leitura dele acabar.

**Restos de programas desinstalados**
- **Nomes de canal e edição:** a última parte de IDs como `Google.Chrome.Beta`, `Adobe.Acrobat.Reader.64-bit`, `Ubisoft.Connect` e `Amazon.Games` virava nome de pasta ("Beta", "64-bit", "Connect", "Games") e podia achar a pasta de outro programa. Esses nomes não são mais procurados.
- **Pasta do fabricante:** um nome tirado do ID só vale, dentro de uma pasta de fabricante, na do próprio fabricante ("Firefox" em `Mozilla\Firefox`, e não em `OutraEmpresa\Firefox`). O nome inteiro do programa continua valendo em qualquer uma.
- **Aplicativos da Store** contam como instalados, e atalhos de pasta (junções) não são propostos.
- **AppData:** as pastas de dados vêm com a marca "dados do programa" e o aviso de que podem guardar configurações e arquivos salvos.
- **Mais rápido:** cada pasta de programas é listada uma vez só, e não uma vez por programa e por nome.
- Num PowerShell de 32 bits, que não enxerga os programas de 64 bits, a busca não roda e a tela diz por quê.

**Limpar o registro**
- **Só disco fixo conta:** um caminho num pendrive, cartão de memória ou unidade de rede mapeada não conta como quebrado, mesmo com a letra existindo (pode ser hoje de outro aparelho, ou a rede pode estar fora do ar). Um HD externo USB costuma aparecer para o Windows como disco fixo: desconectado, continua como "não sei"; com outro disco na mesma letra, não há como distinguir. Um caminho com aspas e argumentos no meio, ou com caracteres que um caminho não tem, é "não sei", e não "falta".
- **Programas que continuam instalados:** um desinstalador guardado na pasta de cache de um instalador (os Redistribuíveis do Visual C++, Advanced Installer, InstallShield) ou com o ícone do programa ainda no disco não sai de Aplicativos instalados.
- **App Paths com argumentos:** o caminho é o que está entre aspas; antes, a aspa sobrando fazia o arquivo parecer apagado.
- **Conferência na hora de remover:** cada referência é conferida de novo antes de sair, também na correção do **Verificar o PC**, com a mesma regra de 32 bits da busca; a que voltou a apontar para um arquivo que existe fica, fora do backup, e a que já saiu do registro (um desinstalador que tirou a própria chave) também, e a faixa diz quantas.
- **Nomes com colchetes:** um valor com colchetes no nome (`C:\App[1]\app.exe...`) é removido pelo nome exato; antes, a remoção podia falhar sempre, e a referência voltava a cada verificação.
- **Textos:** "Nomes curtos de programas apagados (App Paths)", para não confundir com os atalhos, e "Ao entrar no Windows, ele tenta abrir algo que não existe mais".

**Histórico de mudanças:** a remoção de atalhos (também na correção do **Verificar o PC**), duplicados, restos e referências do registro é anotada mesmo quando a ação é parada no meio.

**Apagar o espaço livre:** o aviso diz que o disco fica cheio até o fim e pede para fechar os outros programas.

**O que não foi visto:** como nas builds anteriores, nada disto rodou num Windows de verdade, e as prévias da página foram desenhadas a partir das medidas do código, e não capturadas da janela. Pedem conferência num PC: o limite da Lixeira lido do registro (`BitBucket\Volume`, a política `RecycleBinSize` e o padrão do Windows) e o comportamento do Windows com um item maior que ele; o comando `Delete-DeliveryOptimizationCache`; os atributos dos arquivos do OneDrive só na nuvem; o `mountvol` e o `Win32_Volume` para achar a configuração da Lixeira; o cabeçalho dos atalhos anunciados do Office; a propriedade `Target` das junções no Windows PowerShell 5.1; e `Get-AppxPackage` sem Administrador. A lista da 3.31 do que pede conferência continua valendo.

### Estrutura
- **`Cleanup`:** `$script:WinForgeTempMinAgeHours` (24) e o parâmetro `MinAgeHours` em `Clear-WinForgeFolderContents`, `Invoke-WinForgeFolderCleanup` e nos alvos da personalizada (que também ganham `Files`); `Get-WinForgeMemoryDumpFile`; `Get-WinForgeRecycleBinCapacity` (Nuke e MaxBytes, guardado por dois minutos), `Get-WinForgeVolumeGuid` (mountvol e, sem ele, WMI com tempo limite) e `Move-WinForgeItemToRecycleBin -SizeBytes`; `Test-WinForgeOneDrivePath`, que o `Backup` passa a usar.
- **`CleanupTools`:** `Get-WinForgeProgramFolderNames`, `Get-WinForgeFolderLinkTarget` e `Get-WinForgeFileDigest` (no lugar do `Get-FileHash`); os grupos de duplicados trazem `Stamps`, e a busca devolve `Links`; os atalhos trazem `Synced`; os restos trazem `Data`, e a busca lista cada raiz uma vez.
- **`RegistryCleaner`:** `Get-WinForgeRegistryRoots` (as buscas e o desfazer usam a mesma lista), `Test-WinForgeInstallerCachePath`, `Get-WinForgeDisplayIconPath`, `Test-WinForgeRegistryIssuePresent` e `Remove-WinForgeRegistryValueExact`; cada referência traz `Wow64`, e `Clear-WinForgeRegistryIssues` devolve `Back` e `Gone`.
- **`Shell`:** `Test-WinForgeAdvertisedShortcut`.
- **Janela:** as seções e os ícones da Limpeza (`Navigation`, `GuiDesign`).

## Build 3.36

Uma revisão da tela de Segurança por inteiro, nos mesmos sete pontos das revisões anteriores: se cada opção faz o que promete, segurança e robustez, interface e fluxos, código, desempenho e erros comuns e incomuns. As verificações passam a dizer o que o Windows Defender fez com cada ameaça, a auditoria enxerga o UAC no nível "Nunca notificar" e o BitLocker suspenso, e o perfil Domínio do firewall deixa de acusar problema em PCs de casa.
- **O que aconteceu com cada ameaça:** em quarentena, removida, bloqueada ou não resolvida, e a faixa diz se ainda falta alguma ação.
- **Auditoria que não deixa passar:** o UAC no nível "Nunca notificar" é risco real, e o BitLocker com a proteção suspensa pede atenção.
- **Menos alarme falso:** o firewall desligado no perfil Domínio, num PC fora de um domínio, não é mais ponto de atenção, nem no Início.
- **Verificar uma pasta mais clara:** pede o caminho completo, avisa sobre pastas de rede, e os erros do Defender aparecem em português.
- **Página em duas seções**, com um ícone por cartão.

### Mudou para quem usa

**A página**
- **Duas seções:** **Proteção** (Estado da proteção, Auditoria de segurança, Atualizar assinaturas do antivírus) e **Procurar ameaças** (Verificação rápida, Verificação completa, Verificar uma pasta e o aplicativo Segurança do Windows). O aplicativo fica ao lado das verificações, porque é lá que se vê o que o Defender fez e se roda a verificação offline; antes, ficava sozinho numa terceira seção.
- **Um ícone por cartão:** a Verificação rápida (raio) e a Segurança do Windows (cadeado) tinham o mesmo ícone da completa e do Estado da proteção.

**Estado da proteção**
- **Perfil Domínio:** num PC que não faz parte de um domínio de empresa, o perfil Domínio nunca entra em uso; desligado, aparece como "Desligado (não vale para este PC, que não está num domínio)", sem vermelho e sem ponto de atenção. Vale também para a auditoria, o Início e o Verificar o PC. Sem conseguir saber se o PC está num domínio, continua como antes.
- **Assinaturas antigas:** com mais de 7 dias, a linha das assinaturas fica amarela.
- O relatório (**Diagnóstico > Exportar relatório**) diz o mesmo do perfil Domínio que a tela.

**Verificação rápida, completa e de uma pasta**
- **O que o Defender fez:** cada ameaça encontrada traz o que aconteceu com ela (em quarentena, removida, limpa, bloqueada, permitida, ou "o Windows Defender não conseguiu resolver") e onde estava. A que ainda pede ação aparece em vermelho, e a faixa diz "1 ameaça encontrada; 1 ainda pede ação" ou "2 ameaças encontradas; todas resolvidas pelo Windows Defender". Uma ameaça resolvida para a qual o Defender ainda pede reiniciar o PC ou outra verificação conta como pendente. Antes, só o nome e onde estava, com "veja no aplicativo".
- **Onde estava, sem lixo:** um arquivo baixado mostra só o caminho, sem o endereço do site e o número do processo que o Defender guarda junto; um programa em execução aparece como "programa em execução (processo 4321)".
- **Caminho completo:** "Fotos", ".\Downloads" ou "\Fotos" seriam procurados a partir da pasta do WinForge; a tela pede o caminho com a unidade (D:\Fotos) ou de rede. Só a letra de um pen drive ("E:") vale pela raiz dele (E:\), também em **Limpeza > Encontrar arquivos duplicados**.
- **Pasta de rede:** com o Defender configurado para não examinar arquivos de rede (o padrão), a tela avisa antes de começar, e "nenhuma ameaça" vem com a ressalva de que os arquivos podem não ter sido examinados.
- **Completa:** avisa quando pen drives e discos USB ficam de fora (o padrão do Defender) e onde examiná-los.
- **Erros em português:** sem internet, servidor fora do ar, outra instalação em andamento, o serviço do Defender parado e um serviço necessário desativado (geralmente o Windows Update) viram frases, com o código ("o PC não encontrou o servidor: sem internet ou sem DNS (erro 0x80072EE7)"). O código vem de onde o Windows o põe (no identificador do erro, e não na mensagem), e "confira a conexão com a internet" só aparece quando o erro é de conexão.

**Auditoria de segurança**
- **UAC "Nunca notificar":** o nível mais baixo do UAC deixa o UAC ligado, mas, numa conta de administrador, os programas ganham Administrador sem perguntar. Antes, a auditoria dizia "Ligado"; agora é problema grave, como o UAC desligado (limita a nota a C), com o que fazer.
- **BitLocker:** o disco criptografado com a proteção suspensa (a chave fica gravada no disco, como depois de uma atualização da BIOS) pede atenção, com o caminho para retomar; a criptografia do dispositivo esperando ativação também, com o caminho nas Configurações; o disco ainda criptografando conta como em ordem. Antes, os três apareciam como "Desligada".
- **Secure Boot:** a mesma leitura de **Diagnóstico > Sobre este PC**; com o Windows no modo BIOS legado, "indisponível", com o caminho para o UEFI, em vez de "Desligada" (com "ligue na placa-mãe") ou "Não verificada".
- **Sem leitura, à vista:** a Área de Trabalho Remota e a conta Convidado que não puderam ser lidas aparecem como não verificadas, e não somem da lista. Um Windows sem a conta Convidado conta como "desativada".
- **O que pede ação primeiro:** os pontos verificados vêm com os de risco real no alto, depois os de atenção, os não verificados e, por último, os que estão em ordem.

**O que não foi visto:** como nas builds anteriores, nada disto rodou num Windows de verdade, e as prévias da página foram desenhadas a partir das medidas do código, e não capturadas da janela. Pedem conferência num PC: o que o Defender devolve em `ThreatStatusID` e nos recursos de uma ameaça baixada, os estados do BitLocker (`Get-BitLockerVolume`, suspenso, criptografando e esperando ativação), os campos `ActionSuccess` e `AdditionalActionsBitMask` das detecções, o UAC no nível "Nunca notificar", o perfil Domínio num PC fora de domínio (`PartOfDomain`), as preferências do Defender (`Get-MpPreference`) e os códigos de erro reais. A lista da 3.31 do que pede conferência continua valendo.

### Estrutura
- **`Security`:** `Get-WinForgeFirewallGaps` e o dado `Applies` de cada perfil; `Get-WinForgeThreatStatusText`; `Get-WinForgeScanDetections` devolve `Status` e `Resolved`; `Get-WinForgeDefenderErrorText`, `Get-WinForgeDefenderPreference`, `Test-WinForgeNetworkPath` e `Test-WinForgeNetworkScanSkipped`; `Get-WinForgeBitLockerState` devolve "Suspended"; os fatos da auditoria trazem `UacNeverNotify`, e o `SecureBoot` pode ser "Legacy"; `Get-WinForgeBitLockerState` também devolve "Encrypting" e "Pending"; `Get-WinForgeDefenderErrorCode` e `Test-WinForgeDefenderNetworkError`; `ConvertTo-WinForgeScanPath` completa "E:" com a barra.
- **`Diagnostics`:** `Get-WinForgeSecureBootState` (On, Off, Legacy, NoAdmin, Unknown), de onde saem o texto de Sobre este PC e o dado da auditoria. `Get-WinForgeMpValue` era cópia de `Get-WinForgeJsonValue` (Core) e saiu.
- **`Home` e `Checkup`:** o firewall conta por `Get-WinForgeFirewallGaps`.
- **Janela:** as seções (`Navigation`); os ícones `bolt` e `lock` (`GuiDesign`).

## Build 3.35

Uma revisão da tela de Diagnóstico por inteiro, nos mesmos sete pontos das revisões do Início e da Manutenção: se cada opção faz o que promete, segurança e robustez, interface e fluxos, código, desempenho e erros comuns e incomuns. O mais grave era a tela Eventos críticos, que contava a lista inteira de eventos como um evento só (num PC sem erro nenhum, "1 evento" de "Origem desconhecida"); outras telas inventavam dados que o Windows não deu (0 °C, "0 horas", "4 GB" de vídeo numa placa de 8) ou alarmavam sem motivo (um pen drive "quase cheio", serviços que falham em todo PC).
- **Eventos críticos funcionando:** cada evento conta por si, os avisos do disco e do vídeo entram, e um serviço barulhento não esconde mais um desligamento inesperado.
- **Só o que o Windows informou:** discos, bateria, memória de vídeo e XMP/EXPO deixam de mostrar valores impossíveis ou conclusões que o WinForge não tem como tirar.
- **Menos alarme falso:** pen drives e discos de dados, serviços que falham ao iniciar, dispositivos desativados pela BIOS e o nobreak de um PC de mesa deixam de pedir atenção.
- **Suporte do Windows mais certo:** o Windows Server não leva a data do Windows 11 Home, o ESU de empresas e escolas é reconhecido, e o conselho muda conforme a edição e a versão.
- **Relatório de laudo:** fabricante e modelo, o veredito do suporte do Windows, abrir ou mostrar na pasta, e nenhum relatório apaga outro.
- **Página em três seções:** Visão geral, Discos e bateria, e Funcionamento do Windows, com um ícone por cartão.

### Mudou para quem usa

**A página**
- **Três seções:** **Visão geral** (Sobre este PC, Suporte do Windows, Exportar relatório), **Discos e bateria** (Discos e espaço livre, Saúde dos discos, Saúde da bateria) e **Funcionamento do Windows** (Eventos críticos, Dispositivos com problema, Inicialização e energia, Monitor de Confiabilidade, Gerenciador de Dispositivos, Reinício pendente). Os dois atalhos do Windows ficam embaixo das telas do mesmo assunto, e não numa seção à parte.
- **Um ícone por cartão:** Suporte do Windows (calendário), Saúde dos discos (pulso) e Gerenciador de Dispositivos (chave) tinham o mesmo ícone de um vizinho.
- As descrições de **Exportar relatório** e **Saúde dos discos** dizem o que a tela entrega hoje.

**Eventos críticos**
- **A lista chegava inteira como um evento só:** a leitura devolvia os eventos dentro de outra lista. Num PC sem erro nenhum, a tela mostrava "1 evento", do grupo "Origem desconhecida (ID 0)"; com eventos, juntava todos numa linha ("disk disk disk", 1 vez), sem as explicações. Agora cada evento conta por si.
- **Avisos do hardware:** entram os avisos do disco que repetiu uma leitura ou não conseguiu paginar (51 e 153) e do driver de vídeo que parou e voltou (4101), contados à parte ("1 evento de erro ou crítico e 3 avisos do disco ou do vídeo"). Antes, só Crítico e Erro: um disco começando a falhar passava por "nenhum evento".
- **Limite de leitura cheio:** com 3.000 eventos lidos, uma segunda leitura curta busca só as origens com causa conhecida (desligamento, tela azul, disco, NTFS, hardware, vídeo), sem repetir eventos. Antes, um serviço que falhava a cada minuto enchia o limite e o desligamento inesperado de dias atrás ficava de fora.
- **Contagem por problema:** o desligamento inesperado (Kernel-Power 41 e EventLog 6008, registrados juntos) conta uma vez: "1 problema com causa conhecida", em vez de "2 grupos de eventos têm causa conhecida". A explicação do 41 cita o botão de ligar segurado e a queda de energia.
- **Sem alarme pelo comum:** serviços que falharam ao iniciar ou pararam e o driver de vídeo que se recuperou sozinho aparecem explicados, "comum e quase sempre sem consequência", sem deixar a faixa amarela; o que pede atenção vem primeiro.
- O NTFS com o nome novo (Microsoft-Windows-Ntfs) ganha a mesma explicação do nome antigo.

**Discos e espaço livre, Saúde dos discos**
- **Outras unidades:** os 5 GB livres valem só para o disco do Windows. Num pen drive ou num disco de dados, conta a porcentagem: menos de 10% livres é pouco espaço, menos de 5% é quase cheio. Antes, um pen drive de 8 GB com 3 GB livres era "quase cheio".
- **O livre arredonda para baixo:** "menos de 10% livre" não diz mais "10% livre", e um disco com espaço livre não aparece "100% usado".
- **Valores que o Windows não deu:** temperatura de 0 °C ou de 128 °C para cima, horas ligado em zero ou na casa dos milhões e desgaste acima de 100% (o que algumas gavetas USB informam) não aparecem; um disco que só traz isso diz que só o estado geral foi avaliado, em vez de "nenhum alerta". Num HD, o desgaste em zero não vira "0% da vida útil".
- **Temperatura por tipo:** 55 °C num HD, 70 °C num SSD e 60 °C quando o Windows não diz o tipo. Antes, 70 °C para todos. Um SSD acima de 100 °C (até 127) continua valendo.
- **Que disco é esse:** cada disco mostra as unidades dele (C:, D:), e o aviso de backup diz quais guardar. Os erros não corrigidos mostram "não informado" quando o disco não conta um deles.

**Saúde da bateria**
- **PC de mesa com nobreak:** o Windows enxerga a bateria de um nobreak USB; num PC que se identifica como de mesa, a tela diz que ela deve ser a de um nobreak e não lê capacidade nem ciclos. Antes, o nobreak aparecia como a bateria de um notebook.
- **Duas baterias:** a carga do conjunto pesa o tamanho de cada uma (o que resta somado sobre o total somado), e "usando a bateria" ou "carregando" vale para o conjunto.
- **Uma casa decimal:** "45,6 Wh de 57 Wh", em vez de "46 Wh" com 80% de saúde, que não batia.
- Bateria que informa a capacidade em porcentagem, e não em Wh, mostra a saúde sem inventar Wh; quando falta a capacidade de hoje, o aviso diz qual faltou.

**Sobre este PC**
- **Secure Boot:** com o Windows iniciado no modo BIOS legado, "Indisponível (o Windows iniciou no modo BIOS legado)", e não "Desativado", que sugeria uma opção ao alcance. Nos requisitos do Windows 11, o texto lembra que muitos PCs têm UEFI e que o disco pode ser convertido (MBR2GPT).
- **Memória de vídeo:** pelo nome exato da placa, quando o Registro guarda também a de uma placa que já saiu do PC (uma RTX 4070 Ti SUPER trocada por uma RTX 4070 mostrava 16 GB). Quando o Windows só dá o teto de 4 GB, "4 GB ou mais".
- **XMP/EXPO:** abaixo do que o módulo anuncia, a tela diz as duas velocidades e as causas possíveis (perfil desligado, limite do processador ou da placa), sem afirmar "desativado". Num notebook, "não se aplica": é o que o fabricante definiu.
- **Tempo ligado:** com a Inicialização Rápida ligada e mais de um dia ligado, a tela explica que Desligar não zera a conta, só Reiniciar. A conta é feita em UTC (não erra uma hora na troca do horário de verão), e um boot "no futuro" é "Desconhecido".

**Dispositivos com problema, Reinício pendente**
- **Desativado pela BIOS** (código 29) fica entre os desativados de propósito, como o desativado no Gerenciador. Antes, era "problema ativo".
- **Código 14:** a tela pede para reiniciar o PC. O código que só o WMI informa também conta, e a dica lembra de ligar **Mostrar dispositivos ocultos** no Gerenciador.
- **Reinício pendente** confere também os pacotes do Windows que terminam no reinício, um reinício já em preparação, o instalador de atualização que termina no reinício e a entrada num domínio. Um serviço do Windows Update esperando o reinício para se registrar conta como sinal fraco (a chave pode sobrar depois de reiniciar). O aviso do monitor na bandeja não diz mais "uma atualização" quando o motivo é outro (o novo nome do computador, por exemplo).
- **Atualizações pendentes:** a consulta simples do Windows Update só repete quando o Windows não entende o critério; sem internet ou com o serviço parado, não repete (dobrava a espera).

**Suporte do Windows**
- **Windows Server:** o Server 2025 tem a mesma build do Windows 11 24H2 e levava a data do Windows 11 Home. Agora o Windows Server fica sem data, com o conselho de conferir na página da Microsoft, e sem a seção de requisitos do Windows 11.
- **ESU de empresas e escolas:** um Windows 10 22H2 Enterprise ou Education com a build do ESU instalada está "nas atualizações estendidas (ESU) da organização", até o último ano do programa (10/10/2028, nos dados do catálogo). Sem ela, o conselho fala do ESU para empresas, e não da inscrição do consumidor nas Configurações. Depois do fim de cada ESU, uma build dele instalada não segura mais o PC como "no ESU".
- **Windows 10 mais antigo que o 22H2:** o conselho é ir para o 22H2 (é a versão que pode receber o ESU).
- **No último dia:** "terminam hoje", e não "daqui a 0 dias".
- **Requisitos do Windows 11:** a memória é a instalada (um PC de 4 GB com vídeo integrado aparecia com 3,6 GB e "não atende"); a primeira geração do Core i (i7 920, i5 M 520) e o Snapdragon 835 não atendem; o Windows de 32 bits é uma linha própria, sem acusar o processador.

**Exportar relatório**
- **Mais completo:** o fabricante e o modelo do PC (sem textos de fábrica vazios como "System Product Name"), o veredito do suporte do Windows e as unidades de cada disco. Discos que não puderam ser lidos viram uma linha que diz isso.
- **Depois de salvar:** a escolha entre **Abrir o relatório**, **Mostrar na pasta** e **Agora não**, e o lembrete de que o relatório traz o nome do computador e do usuário.
- **Sem perder relatório:** dois relatórios no mesmo segundo não se sobrescrevem (o segundo ganha "-2"). Se só a cópia em texto falha, o HTML salvo vale, com ressalvas, em vez de "o relatório não foi salvo".

**O que não foi visto:** como nas builds anteriores, nada disto rodou num Windows de verdade, e as prévias da página foram desenhadas a partir das medidas do código, e não capturadas da janela. Pedem conferência num PC: a leitura dos eventos (`EventLogReader`) com as consultas novas, as partições de cada disco (`Get-Partition`), os contadores de confiabilidade de um disco USB, o tipo de firmware (`PEFirmwareType`), a memória de vídeo de uma placa trocada, um nobreak USB num PC de mesa, um notebook com duas baterias (`root\wmi`), as chaves de reinício pendente da entrada num domínio, o erro do Windows Update sem internet e um Windows Server 2025. A lista da 3.31 do que pede conferência continua valendo.

### Estrutura
- **`Diagnostics`:** `Read-WinForgeEventLog` devolve os eventos soltos, com `RecordId`; `Get-WinForgeRecentCriticalEvents` desembrulha listas e faz a segunda leitura das origens conhecidas; `Test-WinForgeEventHintSerious` e `Get-WinForgeEventCause`; o resumo dos eventos ganha `Serious`. `Get-WinForgeDiskHealth` lê as partições uma vez e devolve `Drives`; `Get-WinForgeDiskSummary` devolve `LivrePercent`. `Get-WinForgeBatteryInfo` devolve `Ups`; `Get-WinForgeBatteryState`, `Count`; `New-WinForgeBatteryReading -Relative`; `Get-WinForgeBatteryAssessment -Missing`; `Format-WinForgeWattHours -MilliwattHours`. `Test-WinForgePnpDeviceHasProblem` usa `Get-WinForgeDeviceProblemCode`.
- **`Core`:** `Get-WinForgeDiskSpaceLevel -System`.
- **`Hardware`:** `Get-WinForgeGpuMemoryBytes` prefere o nome exato; `Get-WinForgeExpoXmpStatus` usa `Test-WinForgeLaptop`.
- **`WindowsSupport`:** `Get-WinForgeSupportDaysText` e `Get-WinForgeEsuText`; `Get-WinForgeWindowsSupportStatus` devolve `IsServer` e perde o parâmetro `-LastUpdate`, que não decidia mais nada.
- **`Catalog`:** o campo `EsuOrgEnd` (o fim do ESU de empresas e escolas), opcional: um catálogo sem ele continua válido.
- **`Reports`:** `Export-WinForgeReport` devolve `TextProblem`; `Invoke-WinForgeReport` usa `Read-WinForgeChoice`.
- **Janela:** as seções e a ordem dos itens (`Navigation`); os ícones `pulse`, `wrench` e `calendar` (`GuiDesign`).

## Build 3.34

Uma revisão da tela de Manutenção por inteiro, nos mesmos sete pontos da revisão do Início: se cada opção faz o que promete, segurança e robustez, interface e fluxos, código, desempenho e erros comuns e incomuns. O que saiu dela são vereditos que escondiam o que ainda pedia atenção, uma Lixeira esvaziada sem pergunta, um reinício que podia fechar arquivos sem salvar e um agendamento que podia rodar o que outra conta pusesse na pasta do WinForge.
- **Nada some sem você ver:** a manutenção só esvazia a Lixeira com confirmação, mostrando o que há nela, e o reinício não fecha mais os programas à força.
- **Vereditos honestos:** o Verificar o PC não fica verde depois de uma correção com o antivírus desligado, e o resumo da manutenção não diz "concluídas" quando tudo foi ignorado.
- **Rede de segurança de verdade:** o ponto de restauração vem antes da revisão manual, e o pedido avulso não esbarra mais no limite de um ponto por dia.
- **Agendamento seguro:** a tela diz de quem é um agendamento de outra conta, e o WinForge não agenda a partir de uma pasta que outras contas alteram.
- **Página mais clara:** um resumo com uma informação por linha, que conta a última verificação como o Início, e três seções de três cartões, três por linha.

### Mudou para quem usa

**A página**
- **Resumo no alto:** uma informação por linha: a última manutenção ("há 2 dias (16/10/2026 21:40)"), as etapas que pediram atenção ("2 etapas: Limpeza rápida e Reparar o Windows (DISM + SFC)"), a última verificação e o perfil padrão. A conta é a do Início: uma verificação de menos de um mês cobre a manutenção atrasada (nada fica amarelo), e uma data mais de um dia no futuro não vale como recente ("registrada em ..., uma data no futuro (confira o relógio do Windows)"). Antes, tudo vinha numa linha só, em amarelo inteira, com "14 etapas" no meio, e a verificação recente não contava.
- **Cartões três por linha:** os cartões das páginas têm a largura dos cartões do Início. Na janela padrão cabem três por linha, em vez de dois com uma faixa vazia à direita; na janela mínima, dois, em vez de um. Vale para todas as páginas e para a busca.
- **Seções de três:** **Opções da manutenção** foi para a seção **Opções e agendamento** (antes, **Manutenção automática**), e as três seções ficam com três cartões cada. O **Agendador de Tarefas** ganhou um ícone próprio (antes, o mesmo calendário da Manutenção agendada).

**Verificar o PC**
- **O que ainda pede decisão entra na faixa:** depois das correções, a faixa diz quantos pontos ainda pedem a sua decisão ("1 correção feita; 300 MB liberados; 1 ponto ainda pede a sua decisão") e fica amarela, com a linha "Ainda pedem a sua decisão: Proteção.". Antes, corrigir os temporários deixava a faixa verde com o antivírus desligado.
- **Só itens opcionais na lista** (o cache dos navegadores, por exemplo): a lista diz "Nada desta lista é necessário", e não marcar nada encerra a verificação, que conta como cuidado com o PC. Antes, terminava em "Cancelado" e o Início continuava pedindo para verificar.
- **Memória:** liberar memória vem desmarcado, com o caminho de **Desempenho > Programas pesando agora** (esvaziar a memória dos programas ajuda pouco; fechar o que pesa resolve). Sem a medição do Windows, a correção diz "memória liberada (o Windows não informou quanto)", e não "0 B".
- **Assinaturas do antivírus:** os mesmos limites de **Segurança > Estado da proteção**: mais de 7 dias pede atenção, com a atualização marcada; de 4 a 7, é informação, com a atualização desmarcada. Antes, 4 dias já pediam atenção.
- **Bibliotecas compartilhadas** que não existem mais, sozinhas, são informação: não aparecem mais como "1 ponto pede a sua decisão" em toda verificação.
- "Leu a maior parte do PC" conta etapas, e não achados: duas etapas que dão vários achados cada não escondem outras que não responderam.
- **Registro:** uma entrada de Aplicativos instalados cujo desinstalador sumiu, mas cuja pasta continua lá (sem a pasta de instalação registrada), não é mais removida: o programa pode estar instalado. "1 não pôde ser removida", no singular.

**Manutenção recomendada**
- **Lixeira:** com algo nela, a manutenção mostra quantos itens e o tamanho e pergunta, antes de começar, se a esvazia junto com a limpeza (**Não** é o padrão). Antes, ela era esvaziada em definitivo sem pergunta, até na Rápida.
- **Reinício sem fechar nada à força:** aceitar o reinício reinicia na hora, e um programa com arquivo sem salvar segura o reinício (o Windows pergunta antes de fechá-lo). Antes, o reinício em 30 segundos fechava os programas à força (é o que o Windows faz com um prazo) e um arquivo sem salvar se perdia. Vale também para **Diagnóstico > Reinício pendente**; a contagem de 30 segundos e o botão de cancelar saíram. A faixa continua lembrando de reiniciar, para o caso de o reinício ser cancelado na tela do Windows.
- **Ponto de restauração antes da revisão manual:** com os dois marcados, o ponto é criado antes das janelas de revisão, onde se desinstala programas. Antes, vinha depois delas. Cancelar a fase automática depois disso avisa que o ponto continua na Restauração do Sistema.
- **Reparo de rede:** não roda sem nenhuma rede conectada (Wi-Fi desligado, cabo solto, modo avião), e só pede reinício quando os resets de Winsock e TCP/IP funcionaram. Antes, resetava a rede de um notebook desligado do Wi-Fi e pedia reinício.
- **Profunda:** ganha a limpeza dos componentes do Windows (WinSxS), depois do reparo, que remove versões antigas que as atualizações substituíram. Na Completa ela vem desmarcada. Com um reinício pendente, a limpeza fica para a próxima manutenção (o Windows a recusaria). Antes, a Profunda só se diferenciava por rodar o DISM completo.
- **Sem o winget:** a etapa fica como ignorada ("winget não encontrado"), e não como falha em toda manutenção (nem como "problema repetido" no histórico).
- A etapa **Detectar dispositivos e drivers** diz o que faz: procura hardware novo, e o Windows instala o driver que já tiver para ele.
- A frase do resumo segue o veredito da faixa: com todas as etapas ignoradas, "Nenhuma etapa automática precisou rodar", e não "Todas as etapas automáticas foram concluídas".
- **Histórico de manutenções:** "Variação do espaço livre" (do começo ao fim de cada manutenção), em vez de "Espaço liberado por manutenção: média de sem mudança"; com uma manutenção só, as linhas dizem só o que ela registrou, sem "média" nem "primeira e última"; um perfil que esta versão não conhece não vira "Completa". O histórico fica na ordem em que foi gravado: com o relógio do Windows atrasado, a manutenção nova não é mais descartada quando já há 20.

**Criar ponto de restauração**
- Pedido sozinho, o ponto é criado mesmo com outro de menos de 24 horas: o limite de um por dia do Windows fica em zero só durante a criação e volta ao que era. O original fica anotado até voltar, então um WinForge fechado no meio da criação devolve o limite no próximo ponto. Antes, terminava em "já havia um ponto recente", mesmo antes de instalar um driver.
- Ligar a Proteção do Sistema só é oferecido quando é ela que falta. Com outro motivo (disco sem espaço, política do Windows), o motivo aparece e o resultado fica vermelho, sem ligar a proteção à toa.

**Manutenção agendada**
- O Windows guarda um agendamento só por PC, com a conta de quem agendou. Se ele é de outra conta, a tela diz de quem é, e trocar o dia ou remover pedem confirmação (**Não** é o padrão). Antes, outra conta via "Ativo" e, ao recriar, tirava o agendamento da primeira sem saber.
- O WinForge não agenda a partir de uma pasta que outras contas do PC podem alterar (uma pasta criada direto em `C:\`, por exemplo), nem de uma cujas permissões não pôde conferir: a tarefa rodaria o que estivesse nela, todo mês, com a sua conta. A tela pede para extrair o WinForge de novo dentro da sua pasta de usuário (mover a pasta leva junto as permissões de onde ela está). Um agendamento feito antes, de uma pasta assim, ganha o mesmo aviso na tela.
- Remover um agendamento que já não existe (apagado pelo Agendador de Tarefas) termina bem, e a pasta `WinForge` vazia sai do Agendador. Com o Agendador fora do ar, a remoção diz o motivo, em vez de "já não existia".

**Histórico de mudanças**
- **Registro:** as chaves (`.reg`) e os valores (`.json`) voltam cada um por si: um arquivo que sumiu ou estragou num corte de energia não segura o outro. Com uma parte sumida, a outra volta e a mudança sai da lista, com o aviso do que não tinha como voltar; com uma parte ilegível agora, o desfazer fica amarelo, na lista, para tentar de novo.
- **Ajustes:** com os valores de antes guardados, o desfazer sempre volta a eles, mesmo quando o Windows já desfez parte do ajuste. Antes, dizia "o ajuste já estava desfeito" e deixava o resto como o WinForge pôs. Sem os valores guardados, a frase diz que valeram os padrões do Windows.
- **DNS:** desfazer volta ao DNS de antes da primeira troca (como em **Rede > Desfazer a troca de DNS**) e tira todas as trocas da lista. Antes, a frase dizia "DNS de antes" e as outras trocas continuavam na lista, prometendo um DNS intermediário.
- Desfazer vários itens de inicialização lê as tarefas do Agendador uma vez, e não uma por item (cada leitura leva segundos).

**O que não foi visto:** como nas builds anteriores, nada disto rodou num Windows de verdade, e as prévias da página foram desenhadas a partir das medidas do código, e não capturadas da janela. Pedem conferência num PC: o reinício sem prazo (`shutdown /r /t 0`) com um programa segurando, o limite de pontos de restauração em zero (`SystemRestorePointCreationFrequency`), a leitura das permissões da pasta do WinForge (`Get-Acl`), a remoção da pasta vazia do Agendador de Tarefas, a detecção de nenhuma rede conectada (`Get-NetConnectionProfile`) e a limpeza dos componentes dentro da manutenção. A lista da 3.31 do que pede conferência continua valendo.

### Estrutura
- **`Maintenance`:** `Get-WinForgeMaintenancePageStatus` usa `Get-WinForgeLastCare` e `Get-WinForgeLastCheckup` (com `-Now`). Nova etapa `components` (`Invoke-WinForgeComponentCleanup`), só no perfil Profunda. `Read-WinForgeMaintenanceDetails` devolve `EmptyRecycleBin`; `Invoke-WinForgeMaintenanceStep -Standalone` roda o ponto de restauração antes da revisão manual; `Request-WinForgeRestart` reinicia sem prazo; `Test-WinForgeMaintenanceNeedsRestart` decide só pelo dado `RebootRequired` das etapas.
- **`Cleanup`:** `Invoke-WinForgeQuickCleanup -SkipRecycleBin`.
- **`Checkup`:** cada achado tem `Unread` e a etapa (`StepId`); o veredito conta o que continua pedindo atenção.
- **`Tweaks`:** `Set-WinForgeRestorePointFrequency` e `Restore-WinForgeRestorePointFrequency`; `New-WinForgeRestorePoint -IgnoreFrequency` e o dado `ProtectionOff`.
- **`Network`:** `Test-WinForgeNetworkConnected`.
- **`Schedule`:** `Get-WinForgeScheduleUntrustedWriters`, `Get-WinForgePathWriteRules`, `ConvertTo-WinForgeScheduleAccountName`, `Test-WinForgeScheduleSameAccount` e `Remove-WinForgeScheduleFolder`; o estado da tarefa traz `Owner` e `OtherUser`.
- **`Journal`:** `Test-WinForgeStartupUndoItem -Tasks`.
- **`Core`:** o histórico de manutenções é lido e gravado na ordem da gravação, sem ordenar pela data.
- **`RegistryCleaner`:** a pasta do desinstalador segura uma entrada sem pasta de instalação registrada.
- **Janela:** o estilo `CardButton` (`gui/MainWindow.xaml`) tem 252 de largura; o Agendador de Tarefas usa o ícone `clock` (`GuiDesign`); a seção "Opções e agendamento" (`Navigation`).

## Build 3.33

Uma revisão da tela de Início por inteiro: se cada parte faz o que promete, segurança e robustez, interface e fluxos, código, desempenho e erros comuns e incomuns. O Início ganhou um módulo próprio, os cartões vêm em ordem de relevância, a última leitura não some ao voltar à tela, e o ponto do reinício pendente leva a uma tela que resolve.
- **O que o Início promete, cumprido:** o ponto "Há um reinício pendente" leva a uma tela que oferece reiniciar. Antes, ela só explicava.
- **Relógio adiantado não cala o lembrete:** uma manutenção registrada com a data no futuro não deixa mais o PC "em dia" até o relógio alcançar essa data, no Início e no monitor.
- **Tela mais clara:** cartões em ordem de relevância, a última leitura à vista enquanto a nova chega, os botões da nota sempre à mão e atalhos compactos.
- **Mais leve:** o leitor do Início carrega só os módulos que usa, e a proteção, a leitura mais demorada, vem por último.

### Mudou para quem usa

**Início: nota e cartões**
- **Reinício pendente:** o ponto da nota leva a **Diagnóstico > Reinício pendente**, que agora oferece reiniciar quando há um motivo confiável (uma atualização do Windows esperando o reinício ou o novo nome do computador): **Não** é o padrão, o Windows avisa por 30 segundos e dá para cancelar. Recusar termina amarelo, com "reinicie quando puder". Só arquivos aguardando substituição, um sinal fraco, continua sem a oferta.
- **Data no futuro:** uma manutenção ou verificação registrada mais de um dia no futuro (de quando o relógio do Windows estava adiantado) não conta mais como cuidado recente. O cartão **Última manutenção** mostra "Data no futuro" e, sem uma verificação recente com a data certa (que cobre a manutenção), pede para conferir o relógio, e a nota ganha o ponto "A data da última manutenção está no futuro, então não dá para saber se o PC está em dia", com **Verificar agora**. Antes, essa data aparecia como "agora há pouco" e o lembrete só voltava um mês depois dela. O monitor na bandeja segue a mesma regra.
- **Ordem dos cartões:** primeiro o que pode pedir atenção (disco do sistema, proteção, Windows, reinício pendente, última manutenção, manutenção agendada), depois a identificação (computador, usuário e, nos notebooks, a bateria).
- **Texto numa linha:** um nome de computador, de antivírus ou de versão do Windows com quebra de linha (inclusive os separadores de linha do Unicode) ou outro caractere de controle aparece numa linha só, em vez de desalinhar o cartão.

**Início: leitura e atalhos**
- **A última leitura à vista:** voltar ao Início depois de 30 segundos, ou depois de uma ação, mostra na hora a última leitura, com a hora dela, e a nova a substitui cartão por cartão ("Atualizando (2 de 7)..."). Antes, todos os cartões voltavam a "Lendo..." a cada volta.
- **A hora da leitura** diz o dia quando a leitura não é de hoje, e acompanha a virada do dia com a janela aberta no Início: "Atualizado ontem às 23:50", depois "Atualizado em 28/10 às 23:50". Antes, só a hora, que parecia ser de hoje.
- **Botões da nota sempre à mão:** **Verificar o PC** e **Manutenção recomendada** aparecem também enquanto o PC é lido e quando a nota não pôde ser calculada.
- **A proteção é lida por último**, por ser a leitura mais demorada (o Defender e a Central de Segurança): os outros cartões não esperam por ela.
- **Por onde começar:** os atalhos ficam compactos, na altura dos cartões de **Seu PC** e dois por linha (os quatro em dois por dois na janela padrão), com o nome e a frase do que fazem. O escudo no lugar da seta mostra que a ação pede Administrador, o que também aparece ao passar o mouse e é lido pelo leitor de tela. Antes, eram cartões grandes, do tamanho dos das páginas.

**Desempenho**
- O leitor do Início, que roda em segundo plano, importa só os 8 módulos que a leitura usa, e não os 34. No PowerShell 7 com o Windows simulado, a importação caiu de cerca de 0,65 s para 0,2 s.

**O que não foi visto:** como nas builds anteriores, nada disto rodou num Windows de verdade. As prévias da tela foram desenhadas a partir das medidas do código, e não capturadas da janela. O corte da frase dos atalhos em duas linhas, o pedido de reinício pela tela de Reinício pendente (`shutdown.exe /r /t 30`) e o tempo de importação do leitor no Windows PowerShell 5.1 pedem conferência num PC. A lista da 3.31 do que pede conferência continua valendo.

### Estrutura
- **`Home` (novo):** o Início saiu de `Navigation`, que fica com a tabela, a busca e as teclas. Em `Home` ficam as leituras em etapas, a nota, os cartões, os atalhos e `Get-WinForgeHomeReaderModules`, a lista dos módulos que o leitor importa.
- **`Home`:** `Get-WinForgeLastCare` faz a conta do último cuidado (manutenção ou verificação, sem as datas no futuro) para o Início e para o monitor (`Agent`). `ConvertTo-WinForgeHomeLine` deixa os textos dos cartões numa linha.
- **`Maintenance`:** `Request-WinForgeRestart` recebe o motivo, o comentário do `shutdown.exe` e a mensagem de recusa, e é usado também pelo Reinício pendente.
- **Janela:** `New-GuiHomeStampBar` monta a linha da hora a cada nota, a partir de `$script:HomeStamp` (antes, o mesmo controle era tirado de uma nota e posto na seguinte), e `Update-GuiHomeStampAge` refaz o texto a cada minuto. A última leitura (`$script:HomeLastSnapshot`) só é guardada depois de mostrada, e uma que não pode ser mostrada é descartada, com uma leitura nova no lugar. `New-GuiHealthButtons` e `New-GuiQuickActionCard` são novos, e `New-GuiActionCard` perdeu o parâmetro `-Highlight`.

## Build 3.32

Uma rodada de QA em todos os fluxos: cada ação da janela e do console foi executada de ponta a ponta, com cada tipo de resposta (o padrão, a primeira opção, cancelar, marcar tudo e Parar), com e sem Administrador, com pastas de nomes difíceis e com cada arquivo de dados estragado de vários jeitos. O que saiu dela são correções de vereditos que diziam mais do que o WinForge sabia, de mensagens cruas do Windows e de casos em que a Build 3.31 não fazia o que o CHANGELOG prometia.
- **Vereditos honestos:** uma leitura que não respondeu não vira mais "tudo certo", e um driver instalado com erros, um relatório que falhou ao gravar ou um ponto de restauração que não foi criado não aparecem mais como sucesso.
- **Mensagens em português:** os erros do Windows chegam sem o embrulho técnico do PowerShell, e um comando que não existe no Windows da pessoa vira uma frase.
- **O que a 3.31 prometia e agora faz:** o desfazer parcial fica na lista para tentar de novo, e a manutenção agendada só esvazia uma pasta chamada Temp.
- **Ajustes, DNS e programas:** desfazer um ajuste de energia não mexe num plano que ele não tocou, a volta automática do DNS devolve o DNS de logo antes da troca, e fechar programas não oferece mais componentes do Windows.

### Mudou para quem usa

**Correções do que a Build 3.31 prometia**
- **Histórico de mudanças:** um desfazer que dá certo só em parte (um item da inicialização que exige Administrador, um adaptador de rede desligado) termina amarelo, diz o que faltou e o motivo, e a mudança continua na lista para tentar de novo. Antes, ela saía da lista como desfeita.
- **Manutenção agendada:** só esvazia uma pasta chamada `Temp`, como a limpeza feita na hora. Antes, uma variável TEMP apontando para uma pasta de dados teria tudo o que tem mais de 7 dias apagado todo mês, sem ninguém olhando.
- O Histórico de mudanças ilegível não aparece mais como "ainda não mudou nada", e o histórico de manutenções ilegível é dito como tal.

**Vereditos**
- **Verificar o PC:** uma leitura que não respondeu não vira mais "nada pedindo atenção" em verde.
- **Exportar relatório:** uma falha ao gravar não diz mais "Relatório salvo".
- **Suporte do Windows:** o ESU que não pôde ser conferido não vira "não recebe mais atualizações" na faixa de resultado.
- **Reparo:** o `DISM /CheckHealth` que diz "cannot be repaired" ou "não pode ser reparado" conta como dano.
- **Criar ponto de restauração:** sem nenhum ponto no PC, o WinForge não promete mais que "um ponto recente já deve existir": a ação termina em vermelho e oferece ligar a Proteção do Sistema, e na Manutenção vira ressalva com o motivo certo.
- **Atualizar drivers:** um driver instalado com erros fica amarelo, com o motivo; um erro no meio da instalação aparece na tela e na faixa; e um erro inesperado ao criar o ponto de restauração segue sem ponto novo, em vez de parar tudo.
- **Ferramentas do fabricante:** sem resposta do Windows para o fabricante do PC e a placa de vídeo, a tela diz "não foi possível ler", e não "Tudo certo".
- **Duplicados:** um caminho digitado que não existe termina "Não foi concluído" (e não "Cancelado"), e a lista avisa quando só mostra as 300 maiores cópias.
- **Monitor na bandeja:** Voltar sem mudar nada termina "Cancelado", e não verde com "monitor desligado"; com a conta de outro Administrador, "Nada a fazer" com o motivo. Ligar com a entrada em `Run` recusada pelo Windows para com uma frase em português, e o ícone que não abre vira ressalva.
- A Manutenção não escreve mais uma linha "True" no resumo.

**Mensagens**
- Os erros do Windows aparecem sem o embrulho do PowerShell (`Exception calling "..." with "N" argument(s)`, ou a forma em português) e numa linha só, no resumo, na faixa de resultado e nos detalhes técnicos.
- Um comando que não existe no Windows da pessoa (uma edição sem a ferramenta, por exemplo) aparece como "o comando 'X' não está disponível neste Windows", sem as linhas em inglês de "verifique a grafia".
- Um programa do Windows que não existe neste PC nunca parece ter rodado com sucesso: as ferramentas executadas com a saída na tela também param com "O programa 'X' não foi encontrado neste PC.".
- **Windows Update:** a sessão que não abre vira uma frase em português com o código, na busca, na instalação e nos drivers (antes, um erro técnico em inglês).
- **Linha de comando:** uma ação desconhecida (`-Action Relatorio`) recebe a lista das ações em português, e `-Json` fora da verificação rápida é explicado.
- Contagens no singular e no plural certos nos ajustes e no atalho ("1 ajuste aplicado", "2 ajustes desfeitos", "1 atalho criado, 1 com erro"), sem "(s)".

**Ajustes do Windows**
- Desfazer o PCI Express ou os tempos de tela e suspensão não grava mais os valores num plano de energia que o ajuste não tocou (quando o plano do ajuste foi apagado, como a cópia do Alto desempenho). O plano ativo só volta aos padrões do Windows se estiver entre os planos do ajuste.
- A chave de um ajuste do perfil do usuário, com o WinForge elevado por outra conta, fica de fora com aviso, como já acontecia nos perfis, na importação e nos recomendados. Antes, ela aplicava no perfil da conta elevada e dizia "Tudo certo".

**Rede**
- **Trocar o servidor DNS:** quando o DNS novo não resolve e a ação desfaz sozinha, volta o DNS de logo antes da troca, e não o original do backup. Antes, trocar para o Cloudflare (porque o do provedor não funcionava) e depois para um DNS que não resolve deixava o PC sem resolver nomes, com "desfeito" na faixa. O **Desfazer a troca de DNS** continua voltando ao original.

**Desempenho e segurança**
- **Programas pesando agora:** o WebView2, o ApplicationFrameHost, a busca do Windows 10, a tela de bloqueio e os Widgets não entram mais na lista para fechar. Um programa cuja hora de início não pôde ser lida (aberto como Administrador) não é mais dado como fechado, e uma janela que ficou aberta perguntando se quer salvar termina amarela, e não vermelha.
- **Acelerar agora** apaga os temporários mesmo quando o Windows recusa liberar a memória, e uma memória sem leitura não vira "0 B liberados". Como Administrador, a lista de espera recusada não manda mais abrir como Administrador.
- Um firewall de outro fabricante ligado na Central de Segurança protege os perfis em que o do Windows está desligado: o Estado da proteção, a auditoria, o Início, o Verificar o PC e o relatório não acusam mais "firewall desligado" nesse caso.
- **Auditoria:** o Defender ativo sem a data das assinaturas deixa esse ponto como não verificado, em vez de sumir da conta.

**Limpeza**
- **Atalhos quebrados** (Limpeza e Verificar o PC): um atalho criado por um instalador de 32 bits não é mais dado como quebrado quando o destino está em `Arquivos de Programas (x86)`.
- Um atalho de pasta na Downloads (ou entre os restos de programas) não é mais dado como "em uso" pelo que está aberto no destino, e a busca não percorre o destino.

**Programas, backup e atualizações**
- **Backup antes de formatar:** o índice do backup é gravado no começo e a cada parte, então parar no meio deixa um backup que a restauração aceita, com o que chegou a ser salvo; a restauração avisa que ele não terminou.
- **Restaurar a partir de um backup:** uma lista de programas danificada não é oferecida (a tela avisa e a faixa fica amarela), e uma rede Wi-Fi que não volta diz o motivo.
- **Verificar nova versão:** um hash publicado que não é um SHA-256 inteiro, ou um arquivo de hash fora do repositório do projeto, faz o download falhar (e o arquivo é apagado), em vez de passar como "não conferido".
- **Conferir dados online:** nomes e descrições com caracteres de controle (quebra de linha, ESC), que podiam desenhar linhas falsas no console, fazem o catálogo inteiro ser recusado; vale a cópia embutida.

**Janela**
- O Início lido em segundo plano (Build 3.31) importa os módulos também quando a pasta do WinForge tem colchetes no nome. Antes, no Windows PowerShell 5.1, todos os cartões ficariam como "Não foi possível ler".
- A trava dos arquivos de dados e a da janela única, quando o Windows recusa o acesso total a uma trava que a outra parte criou (a janela como Administrador e o monitor sem, por exemplo), abrem só com o acesso para esperar e soltar, em vez de seguir sem trava.

**O que não foi visto:** como nas builds anteriores, nada disto rodou num Windows de verdade. Os fluxos rodaram no PowerShell 7 com o Windows simulado: as leituras do sistema falham ali, e o que se conferiu é se cada fluxo termina bem e com um veredito correto mesmo assim. A trava aberta só para esperar e soltar (`Mutex.OpenExisting` com Synchronize e Modify) e a importação com colchetes no Windows PowerShell 5.1 pedem conferência num PC. A lista da 3.31 do que pede conferência continua valendo.

### Estrutura
- **`Console`:** `ConvertTo-WinForgeReadableError` limpa o texto de um erro; `Write-WinForgeStatus` e `New-WinForgeResult` passam por ela.
- **`Core`:** `Open-WinForgeNamedMutex` abre a trava compartilhada (cria com acesso do usuário; senão abre com Synchronize e Modify; senão uma trava simples). `Invoke-WinForgeNative` confere se o programa existe, como `Invoke-WinForgeCapture`.
- **`GuiHost`:** o script do leitor em segundo plano importa os módulos com a mesma segunda tentativa (caminho escapado) da janela e do executor das ações.
- **`Backup`:** o índice (`backup.json`) tem `Complete`, falso até o fim.
- **`WinForge.Console.ps1`:** a ação é conferida no próprio script (a lista em `$knownActions`), sem `ValidateSet`.

## Build 3.31

Uma revisão de engenharia do projeto inteiro: consistência dos dados gravados, desempenho da janela e correções em todas as páginas, quase todas em casos que davam um resultado errado sem avisar.
- **Dados que não se perdem:** preferências, históricos e backups são gravados por inteiro de uma vez, com cópia da versão anterior, e um arquivo que não abre nunca é sobrescrito.
- **Janela mais leve:** o Início é lido fora da janela, a saída longa de uma ação não trava a tela, e abrir o WinForge de novo traz a janela que já está aberta.
- **Limpeza mais segura:** nada vai "para a Lixeira" onde o Windows apagaria em definitivo, os restos de programas não propõem pastas do sistema, e o registro de programas de 32 bits não aparece mais como quebrado.
- **Segurança sem falso alarme nem falsa tranquilidade:** o ESU do Windows 10 é conferido pela build, a auditoria usa as mesmas datas de suporte do Início, e uma leitura que falhou não vira "sem antivírus".
- **Ajustes, rede e manutenção:** desfazer volta exatamente ao que era, o DNS volta IPv4 e IPv6 em separado, o reparo de rede preserva IP fixo, e a manutenção agendada avisa quando a pasta do WinForge mudou.

### Mudou para quem usa

**Dados gravados**
- Preferências, histórico de manutenções, Histórico de mudanças, última manutenção, backups de ajustes e de DNS, o registro da manutenção agendada e os dados online são gravados num arquivo temporário e trocados de uma vez, com uma cópia `.bak` da versão anterior. A janela, o monitor e a manutenção agendada não gravam o mesmo arquivo ao mesmo tempo.
- Um arquivo que não abre (corrompido) é guardado como `.corrompido-<data>` e o WinForge volta à cópia anterior. Um arquivo que existe, mas não pôde ser lido agora (em uso, sem permissão), nunca é sobrescrito: a gravação é recusada com uma mensagem, em vez de apagar o que havia.

**Janela**
- **Uma janela só:** abrir o WinForge com ele já aberto (pelo atalho, pelo `.cmd` ou por um aviso do monitor) traz a janela para a frente e abre nela a ação pedida.
- **O Início é lido fora da janela.** A proteção do Windows e as consultas ao WMI podem levar segundos; agora a janela continua respondendo enquanto isso. Uma etapa que não responde em 45 segundos fica como "Não foi possível ler" e a leitura segue.
- A preparação das ações (o código que liga a janela às ações) também é feita fora da janela, logo depois de ela abrir.
- **Saída longa:** a tela desenha a saída aos poucos, sem travar, e só termina a ação depois de mostrar tudo. Antes, parte da saída de uma ação grande podia aparecer no começo da ação seguinte, e os últimos erros se perdiam. O progresso de uma ação também não aparece mais na seguinte.
- Uma pergunta só aparece depois de a saída anterior estar na tela. Um erro dentro da própria janela descarta a sessão da ação, para a próxima começar limpa.
- **Parar** é repetido até a ação realmente terminar.
- **Executar de novo** não aparece mais depois de ligar ou desligar um ajuste (repetir desfazia a mudança sem perguntar).
- Reabrir como Administrador para uma ação mantém a ação: ela abre sozinha depois do aviso do Windows.
- Trocar o tema com uma pergunta aberta redesenha a pergunta, mantendo o que estava marcado, o filtro e o texto digitado.
- Leitores de tela: as caixas de marcação das listas têm nome, e a caixa de texto das perguntas é ligada ao rótulo dela.

**Início e nota de saúde**
- Uma leitura que entra na nota e não respondeu deixa a nota como **"Incompleta"**, em amarelo, com a frase "Seu PC parece bem", em vez de um verde que não foi conferido. O suporte do Windows também entra nessa conta quando não pôde ser lido.
- O cartão **Manutenção agendada** fica amarelo, com "Pede atenção", quando a tarefa usa um WinForge que não existe mais ou de outra pasta, ou quando a última execução terminou mal.
- O Defender em modo passivo sem outro antivírus identificado é um ponto leve na nota. Com outro antivírus no lugar, as ameaças que o Defender ainda guarda são ressalva (confira no outro antivírus), e não mais "ameaça ativa", que é um ponto grave.
- O ESU do Windows 10 é conferido pela build instalada, sem consultar o histórico de atualizações (a leitura fica mais rápida). Quando não dá para conferir, o cartão diz "ESU não conferido", e não "sem atualizações de segurança".

**Verificar o PC**
- A verificação só conta como cuidado com o PC (no Início e no monitor) quando leu de verdade a maior parte do PC e, havendo o que corrigir, nem todas as correções falharam. Cancelar não conta mais.
- A proteção aparece como "leitura incompleta" quando o firewall ou, com o Defender ativo, as ameaças não puderam ser lidos. A linha da memória continua aparecendo, com "não foi possível ler", quando a leitura falha.
- Programas de 32 bits não aparecem mais como referências quebradas no registro, e as DLLs compartilhadas ficam fora da correção com um clique.
- Atalhos quebrados abertos em outro programa ficam de fora, sem parar a ação atrás da janela "Arquivo em uso".

**Desempenho**
- **Fechar programas medidos:** só entram programas da sua sessão. Antes de fechar, o WinForge confere que o processo ainda é o mesmo que foi medido (o Windows reaproveita números de processo). Um programa cuja janela continua aberta (pode estar perguntando se quer salvar) fica aberto, com um aviso em amarelo, em vez de ser encerrado à força; os processos sem janela só são encerrados depois.
- A lista de processos do Windows que nunca entram ganhou a tela de entrada, os drivers de usuário, o Windows Update e os instaladores (`msiexec`, `TiWorker`, `TrustedInstaller`) e o Terminal.

**Limpeza**
- **Lixeira:** atalhos quebrados, duplicados, restos de programas e a limpeza da pasta Downloads não mandam mais nada "para a Lixeira" em pendrives, cartões de memória e unidades ou pastas de rede, onde o Windows apagaria em definitivo: o WinForge avisa e não remove. Duplicados e restos também mostram o aviso do limite de tamanho da Lixeira.
- **Restos de programas:** pastas do Windows, da Microsoft e com nomes genéricos (`AppData\Microsoft\Windows`, pastas de idioma como `pt-BR`) não são mais propostas.
- **Temporários** (também na Limpeza rápida, no Acelerar agora e na manutenção agendada): só uma pasta chamada `Temp` é esvaziada, e uma TEMP apontando para o AppData, a pasta do WinForge, o perfil público ou a pasta Users é recusada.
- A limpeza da pasta Downloads recusa uma Downloads redirecionada para Documentos, Área de Trabalho, OneDrive ou outra pasta pessoal.
- **Duplicados:** a busca não segue mais atalhos de pasta (junções), que faziam um arquivo parecer cópia de si mesmo; recusa as pastas do Windows, dos programas, o ProgramData e o AppData (também em "Outra pasta"); fica mais rápida em pastas grandes e para no limite sem listar a pasta inteira antes. Uma cópia só vai para a Lixeira depois de conferir que o arquivo que fica continua lá, com o mesmo tamanho.
- **Apagar o espaço livre:** se for interrompido ou falhar, a pasta `EFSTMPWP` que enche o disco é apagada, e ao abrir a tela de novo o WinForge oferece apagar uma que tenha ficado. **Parar** também interrompe o `cipher`.
- **Limpar o registro:** a limpeza se recusa a rodar num PowerShell de 32 bits, e remover um valor com colchetes no nome não leva mais junto outro valor parecido.

**Histórico de mudanças**
- Dá para desfazer qualquer mudança guardada, não só as 30 mais recentes.
- Desfazer uma limpeza do registro recria só os valores removidos que não existem hoje, sem voltar valores que outros programas mudaram depois. Só são aceitos backups do registro da pasta do WinForge que mexem nas chaves da limpeza, itens de inicialização que o WinForge gerencia e recursos do Windows da lista dele. Um desfazer que dá certo só em parte fica na lista para tentar de novo.
- Desfazer a troca de DNS com o backup ilegível diz que não conseguiu ler, em vez de "já estava como antes"; um adaptador que ficou como estava não conta como restaurado.

**Ajustes do Windows**
- Ligar de novo um ajuste que o Windows desfez em parte não troca mais os valores originais pelos do WinForge: desfazer volta ao que era antes. Nos ajustes de energia, cada plano guarda os próprios valores.
- Desfazer devolve o valor com o tipo que ele tinha (texto, número de 64 bits, binário), em vez de virar número de 32 bits ou falhar, e grava só os valores daquele ajuste.
- Quando o Windows nega a gravação no registro, o ajuste aparece como falha, e não como "aplicado"; desfazer só apaga o backup e marca o Histórico depois de voltar de fato ao original.
- Um backup de ajustes que não pôde ser lido não é mais tratado como vazio: aplicar e desfazer param com uma mensagem, e os originais guardados não se perdem.
- **Plano de energia Alto desempenho:** não acumula mais cópias do plano. A cópia criada é reaproveitada e apagada ao desfazer; com um plano de alto desempenho já ativo, nada muda.
- "Desativar resultados da web na busca do Iniciar" agora pede Administrador, que é o que o Windows exige para essa política.
- Com o WinForge elevado por outra conta, os ajustes do perfil do usuário ficam de fora, com aviso, nos perfis, na importação e nos recomendados.

**Programas**
- Ao desinstalar vários programas, só os que saíram de fato vão para o Histórico e para a busca de restos.
- **Gerenciar inicialização** confere o item que mudou mesmo com tarefas ou atalhos de mesmo nome em lugares diferentes, e não mexe nos itens de outra conta quando o WinForge está elevado por ela. Instalar, instalar essenciais e atualizar programas avisam, nesse caso, que o perfil é o da conta elevada.
- **Remover aplicativos do Windows:** remover o Facebook não leva mais o Instagram e o Messenger, e nenhum item some da lista quando há dois aplicativos do mesmo fabricante. A lista abre mais rápido (uma consulta ao Windows) e diz quando não conseguiu ler, em vez de dizer que nada está instalado.

**Segurança e suporte do Windows**
- **ESU do Windows 10 22H2:** o WinForge só diz que o PC recebe as atualizações estendidas quando a build instalada é uma das que só saem para quem se inscreveu (19045.6575 em diante). Antes, um PC fora do programa que instalou a última atualização gratuita com atraso aparecia como protegido.
- Versões do Windows 10 anteriores ao 22H2 que não estavam na lista de datas (1703 a 21H1) aparecem como sem atualizações de segurança, em vez de "fora da lista".
- A **Auditoria de segurança** usa as mesmas datas de suporte da tela Suporte do Windows e do Início (atualizáveis pelos dados online), com o prazo das edições IoT Enterprise LTSC (2021 até 13/01/2032; 2024 até 10/10/2034). Uma versão sem suporte limita a nota a B.
- A auditoria não dá nota quando o antivírus não pôde ser verificado, e explica o motivo.
- Quando a Central de Segurança do Windows não responde e o Defender está desligado, o WinForge diz "não foi possível ler" em vez de acusar "PC sem antivírus". Um antivírus só registrado, desligado ou vencido não conta mais como proteção.
- O estado do firewall inclui as regras da política de grupo e do gerenciamento da empresa.
- Com outro antivírus no lugar, a auditoria não conta as ameaças do Defender como "sem verificar"; as que ele ainda guarda viram ressalva. O Defender em modo passivo sem outro antivírus ligado é ponto de atenção na auditoria, no Estado da proteção e no Verificar o PC.
- **Requisitos do Windows 11:** o disco (64 GB, contados como no script da Microsoft) agora é conferido de verdade; antes ficava "não verificado" e o resultado nunca dava "atende". Sem Administrador, ou quando a consulta ao TPM falha, o TPM aparece como "não verificado", e não como "não encontrado" (que reprovava o PC).

**Diagnóstico e relatório**
- **Eventos críticos** ficou bem mais rápido: o WinForge lê só a origem, o código e a hora de cada evento.
- A lista de discos mostra o tipo certo (SSD ou HDD, e não só "SATA"), com uma consulta só ao Windows.
- As placas Intel Arc integradas ao processador (Meteor Lake, Arrow Lake, Lunar Lake e Panther Lake) não são mais tratadas como placas de vídeo dedicadas.
- O indicativo de XMP/EXPO compara primeiro com a velocidade do próprio módulo e usa os limites JEDEC atuais (DDR5 até 8800), sem acusar perfil ligado em memórias padrão.
- A saúde da bateria não trava nem sai errada quando o firmware informa capacidade 0 ou 4294967295; esses valores contam como "não informado".
- O relatório HTML abre pelo Explorador, então o navegador não abre mais como Administrador. "Reinício pendente" diz "Não" quando só há sinais fracos, como nas telas.
- Notebook ou desktop é decidido primeiro pelo gabinete; a bateria só decide quando o tipo de gabinete é desconhecido, então um desktop com nobreak não vira notebook.

**Manutenção e reparo**
- Quando o SFC diz que não encontrou problemas ou que reparou tudo, linhas "Cannot repair" do `CBS.log` não viram ressalva, e a Manutenção deixa de repetir DISM e SFC todo mês por causa delas.
- Quando o `DISM /CheckHealth` não consegue consultar o Windows, a tela diz "não foi possível consultar (código X)" em vez de "há dano marcado"; o `/RestoreHealth` só roda se o SFC não reparar tudo.
- DISM, SFC, CHKDSK e a otimização do disco impedem o PC de dormir também quando rodados sozinhos, e uma ação dentro de outra não desliga mais o "manter acordado" da Manutenção.

**Manutenção agendada**
- Se a pasta do WinForge usada pela tarefa for apagada ou trocada, a tela avisa, deixa de dizer só "Ativo" e oferece recriar a tarefa escolhendo o dia; a última execução registrada pelo Agendador aparece quando é mais nova ou terminou mal.
- A tarefa apaga só os temporários com mais de 7 dias, como a Limpeza de Disco do Windows (um programa aberto pode estar usando os mais novos). A limpeza feita na hora continua igual.
- A tarefa confere que o relatório foi mesmo gravado antes de dizer que ele foi salvo.

**Atualizações**
- A instalação usa o que o Windows guardou da busca que montou a lista e só consulta o Windows Update de novo se faltar alguma escolhida: uma consulta online por instalação, em vez de duas.
- A busca só repete sem o filtro de opcionais quando o Windows não conhece esse filtro; atualizações opcionais (prévias e drivers) vêm desmarcadas e marcadas como "opcional".
- Erros do Windows Update e da atualização de drivers aparecem em português e sempre com o código, e o download ou a instalação não é repetido depois de um erro do próprio Windows Update.
- **Verificar nova versão:** um arquivo de hash publicado que não pôde ser lido faz o download falhar (o arquivo é apagado), em vez de passar como "não verificado".

**Rede**
- **Desfazer a troca de DNS** devolve IPv4 e IPv6 em separado, sem transformar em fixos os servidores que vinham do roteador. Um adaptador cujo DNS de antes não pôde ser lido não é alterado, e a tela avisa; ao trocar o DNS, um adaptador ilegível também fica de fora. Se o backup existente não puder ser lido, a troca é recusada sem alterar nada.
- **Reparar rede e DNS** reconhece IP fixo em qualquer adaptador (também sem gateway, IPv6 ou com o WMI com erro) e não apaga essa configuração. Na Manutenção, o reparo não roda quando os nomes de sites resolvem ou o Windows informa acesso à internet (redes com proxy).
- O teste de velocidade passa pelo proxy do sistema com a conta do Windows, explica em português um proxy que exige autenticação e mostra os números com vírgula ("94,12 Mbps", "2,1 s").
- O relatório de Wi-Fi abre no navegador sem os privilégios de Administrador.

**Backup antes de formatar**
- Se a pasta do backup fica no OneDrive, o WinForge avisa que as senhas do Wi-Fi iriam para a nuvem e só as inclui se você confirmar.
- O backup avisa quando o Windows não consegue exportar as redes Wi-Fi (com o Wi-Fi desligado, por exemplo), em vez de dizer que não há redes salvas.

**Monitor na bandeja**
- O monitor nunca roda como Administrador: ligado com a janela elevada, ele passa a abrir no próximo login; com a janela aberta como Administrador de outra conta, ele não é ligado, e a tela explica por quê. Desligar diz se o ícone fechou de fato.
- Cada usuário do PC tem o seu monitor: ligar, desligar e conferir o monitor só enxergam o da sua sessão do Windows. Uma leitura que não termina em 5 minutos é abandonada, uma leitura que falha não fica sendo repetida, e o pedido para fechar é atendido em meio segundo.

**Linha de comando e iniciadores**
- `-Action Check`: com parte da nota sem leitura, o resultado é "Há pontos de atenção" (código 1), e não "Tudo em dia". Sem conseguir verificar o antivírus, a segurança aparece "sem nota" com o motivo, também com código 1. O JSON ganhou `Security.NoGradeReason`.
- `-ReportDirectory` com uma pasta relativa vale a partir da pasta de onde o comando foi rodado.
- Aberto por um programa de 32 bits, o WinForge usa o PowerShell de 64 bits e lê a parte certa do registro.
- Cancelar o aviso do Windows ao reabrir como Administrador termina com código 1.
- Um programa do Windows que não existe neste PC dá a mensagem "O programa 'X' não foi encontrado neste PC.".

**Outras correções**
- A identidade do WinForge na barra de tarefas (o ícone e o agrupamento próprios) não falha mais ao ser aplicada à janela e ao atalho.
- **Correção do texto da Build 3.29:** o ESU do Windows 10 para consumidores vai até **12/10/2027** (a Microsoft estendeu o programa), e não até 13/10/2026 como aquela entrada dizia. Os dados do WinForge já usavam a data certa.

**O que não foi visto:** nada disto rodou num Windows de verdade. O código foi conferido no PowerShell 7 com o Windows simulado, e a janela e o XAML foram validados contra as bibliotecas do WPF. Pedem conferência num PC: a janela única e o pedido entre duas aberturas; a leitura do Início e a preparação das ações em runspaces à parte no Windows PowerShell 5.1; a busca do Windows Update no que ficou guardado (`Online = falso`) e os códigos 0x80240032 e 0x8024xxxx; o `Get-AppxPackage` sem nome, o `GetValueKind` e o `powercfg /delete`; o `Sysnative` dos iniciadores; o leitor de eventos do Windows, o `MediaType` dos discos e o `-PolicyStore ActiveStore` do firewall; o relatório aberto pelo Explorador; o tipo de unidade usado para decidir onde há Lixeira (unidades `SUBST` e o limite de tamanho da Lixeira de cada unidade não são conferidos); e as propriedades de acesso à internet do Windows usadas pelo reparo de rede. O nome do pacote do Instagram (`Facebook.InstagramBeta`) vem de listas conhecidas, não de um PC com ele instalado; se estiver errado, o aplicativo só não aparece.

### Estrutura
- **`Core`:** os arquivos de estado têm uma trava com nome (`Invoke-WinForgeStateLock`), leitura com estado (`Read-WinForgeStateFile`: Missing, Ok, Recovered, Unreadable) e gravação atômica (`Write-WinForgeStateFile`, `Write-WinForgeStateJson`). Os gravadores de registro param em acesso negado e guardam o tipo do valor (`Set-WinForgeRegistryValue`, `Get-WinForgeRegistryValueKind`). `Set-WinForgeKeepAwake` conta os pedidos por thread (`Set-WinForgeThreadExecutionState`). `Invoke-WinForgeCapture` lança erro quando o programa não existe.
- **`GuiHost`:** leituras em segundo plano (`New-WinForgeGuiReader`, `Start-WinForgeGuiRead`, `Receive-WinForgeGuiRead`, `Close-WinForgeGuiReader`) e a janela única (`Enter-WinForgeWindowLock`, `Send-WinForgeWindowRequest`, `Receive-WinForgeWindowRequest`; o pedido fica em `window-request.json` e vale por um minuto). O host das ações tem `PendingCount`, `ClearQueue()` e `ResetProgress()`.
- **`Navigation`:** `New-WinForgeHomeStepFailure` (o resultado de uma etapa que falhou ou passou do tempo); a nota tem o rótulo "Incompleta".
- **`WindowsSupport` e `Catalog`:** campos opcionais `EsuFirstRevision` e `IotLtscEnd` no catálogo; `Get-WinForgeWindowsRevision` lê a revisão da build. `Get-WinForgeWindowsSupportEnd` saiu de `Security`, que usa `Get-WinForgeWindowsSupportStatus`.
- **`Security`:** a nota da auditoria traz `NoGradeReason` (`Antivirus` ou `Coverage`); o modo do antivírus ganhou `Passive`.
- **`Schedule`:** `Get-WinForgeScheduleStatus` devolve `ScriptPath`, `ScriptMissing`, `Stale`, `LastRunFailed`, `NeedsAttention` e `Problem`; `Clear-WinForgeScheduledTempFolder` limpa só o que tem mais de 7 dias.
- **`Diagnostics`:** `Read-WinForgeEventLog` lê os eventos com o `EventLogReader` e uma consulta XPath.
- **`WindowsUpdate`:** `Get-WinForgeUpdateSearchCode` é a busca única das duas pontas (lista e instalação).
- **`Cleanup` e `CleanupTools`:** `Get-WinForgeRecycleBinProblem`, `Get-WinForgePathRelation`, `Test-WinForgeDownloadsFolderSafe`, `Test-WinForgeDuplicateFolderSafe`, `Test-WinForgeGenericLeftoverName` e `Remove-WinForgeCipherLeftover`.
- **`RegistryCleaner`:** backup dos valores em `.json` (`Restore-WinForgeRegistryValues`), conferência das chaves de um `.reg` antes de importar e leitura das duas vistas do registro (64 e 32 bits).
- **`Tweaks`:** os originais de energia por plano (`Merge-WinForgePowerOriginal`) e a cópia do Alto desempenho (`Remove-WinForgeCreatedPowerScheme`).
- **`Performance`:** `Get-WinForgeSampledProcess` confere nome e hora de início do processo medido. **`Agent`:** `Test-WinForgeAgentStartBlocked`.
- **Janela:** `Update-GuiHomeReader` (as etapas do Início), `Wait-GuiWarmup`, `Update-GuiPromptTheme`; a saída das ações passa por uma fila desenhada com orçamento de tempo por quadro.
- **Iniciadores:** `WinForge.cmd` e `WinForge-Console.cmd` escolhem o PowerShell de 64 bits pelo `Sysnative`; o do console guarda a pasta de onde foi chamado em `WINFORGE_CALLER_DIR`.
- As contas com `[Math]::Max`/`[Math]::Min` não misturam mais um número inteiro escrito no código com um valor fracionário (o PowerShell escolheria a versão para inteiros e cortaria as casas), e o projeto passou a recusar esse padrão.

## Build 3.30

Uma revisão de design da janela e dos fluxos: páginas organizadas em seções, um resumo que se lê de relance e leva à próxima tela, filtro nas listas longas e um Início coerente com o Verificar o PC.
- **Seções nas páginas:** os cartões vêm agrupados ("Liberar espaço", "Arrumar o que sobrou", "Ferramentas do Windows"), na janela e no console.
- **Resumo com cor e links:** os dados que dizem se algo está bem ou pede atenção ficam verdes, amarelos ou vermelhos, e cada "Página > Item" citado vira link.
- **Filtro nas listas de marcação longas,** como a de programas para desinstalar.
- **Início:** o Verificar o PC conta como cuidado com o PC, e o ponto de atenção leva a ele.
- **Desempenho:** memória em uso e tempo ligado no alto da página, e um ícone próprio na barra lateral.

### Mudou para quem usa

**Seções nas páginas**
- Os cartões de cada página vêm em seções com título, e as seções vão do que se usa mais ao que se usa menos:
  - Manutenção: Cuidar do PC, Rede de segurança e Manutenção automática;
  - Diagnóstico: Visão geral, Discos e bateria, Funcionamento do Windows e Ferramentas do Windows;
  - Segurança: Proteção, Procurar ameaças e Ferramentas do Windows;
  - Limpeza: Liberar espaço, Arrumar o que sobrou, Avançado e Ferramentas do Windows;
  - Desempenho: Deixar o PC mais leve e Ferramentas do Windows;
  - Reparo: Arquivos do Windows e Disco e dispositivos;
  - Atualizações: Windows e drivers, Programas e aplicativos e Ferramentas do Windows;
  - Programas: Instalar e remover, Inicialização e recursos, Backup e formatação e Ferramentas do Windows;
  - Rede: Ver e testar e Consertar e configurar;
  - Sobre o WinForge: Versão e dados e Integração com o Windows.
- **Ferramentas do Windows** junta os atalhos que só abrem uma janela do Windows e fica por último. A Restauração do Sistema, o Agendador de Tarefas, as atualizações da Microsoft Store e a pasta de logs ficam junto do assunto deles.
- Alguns itens mudaram de lugar para a seção ficar inteira: Exportar relatório subiu para a Visão geral do Diagnóstico, Limpar a pasta Downloads foi para Liberar espaço, e a Manutenção ficou com o Histórico de manutenções e as Opções logo depois dos dois botões principais.
- **No console,** o menu de cada página mostra o nome das seções antes dos itens; a numeração segue direto de uma seção para a outra.

**Resumo da execução**
- **Valores com cor:** um dado que diz se algo está bem ou pede atenção vem na cor do nível, na janela e no console. Verde para "Ameaças ativas: Nenhuma", "Firewall: Ligado" e o espaço liberado pelo Verificar o PC; amarelo, em negrito, para memória a partir de 85%, reinício pendente, atualizações pendentes e o que o Verificar o PC encontrou para corrigir; vermelho, em negrito, para firewall desligado, ameaça ativa, antivírus desligado e versão do Windows sem atualizações de segurança. Valem para Verificar o PC, Estado da proteção, Suporte do Windows (também cada requisito do Windows 11), Saúde dos discos, Sobre este PC (reinício pendente), Programas pesando agora, Acelerar agora e Liberar memória.
- **Links:** cada referência a outra tela numa mensagem ("desative o que não precisa em Programas > Gerenciar inicialização") vira um link que abre a tela, como os botões dos pontos de atenção do Início. Uma linha com duas referências tem dois links. O link fica na cor de destaque e se sublinha sob o mouse.
- O reinício pendente do Verificar o PC agora indica Diagnóstico > Reinício pendente, para ver o motivo.

**Listas de marcação**
- **Uma lista com mais de 10 itens ganha um filtro,** já com o foco: é só digitar parte do nome. A busca não diferencia maiúsculas nem acentos ("camera" acha "Câmera"), procura também na descrição de cada item (o ID do pacote, o fabricante) e exige todas as palavras digitadas.
- O que estiver marcado continua marcado fora do filtro e conta no **Confirmar**. Com o filtro, o botão vira "Marcar os 3 à vista", e **Limpar** também vale só para os itens à vista.
- Sem nenhum item com o texto, a lista diz "Nenhum item com esse texto."

**Início**
- **O Verificar o PC conta como cuidado com o PC.** Feito há menos de um mês e depois da última manutenção, ele cobre o atraso e o que a manutenção antiga deixou pedindo atenção: o ponto some da nota, e o cartão **Última manutenção** diz "PC verificado há 3 dias" na segunda linha.
- Sem nenhum dos dois em dia, o ponto leva ao **Verificar o PC**, o botão principal da nota ("Verificar agora"). Sem manutenção nem verificação, o ponto diz "O PC ainda não passou por uma verificação nem por uma manutenção". Uma manutenção recente que terminou com etapas pedindo atenção continua com o botão "Refazer", que abre a Manutenção recomendada.
- O monitor na bandeja usa a mesma leitura da última verificação.

**Desempenho**
- **O alto da página mostra a memória em uso e há quanto tempo o PC está ligado.** Memória a partir de 85% fica em amarelo, com "veja Programas pesando agora"; uma semana ou mais ligado fica em amarelo, com "reiniciar deixa o Windows mais leve" (com a Inicialização Rápida, desligar não zera esse tempo).
- **Ícone próprio na barra lateral,** um foguete, que também está no cartão Acelerar agora. Antes, o ícone parecia o da Manutenção.
- **Correção:** com mais de 2 GB de memória em uso, a conta podia falhar, porque o PowerShell escolhia a versão para números inteiros pequenos de uma função de máximo. Afetava a linha Memória do Verificar o PC, Acelerar agora, Liberar memória e Programas pesando agora, que também perdia as casas decimais do uso do processador. Conferido no PowerShell 7; no Windows PowerShell 5.1, não.

**O que não foi visto:** a janela não foi aberta num Windows de verdade. O desenho foi conferido numa prévia em HTML com as mesmas medidas e cores, e o script da janela e o XAML foram validados contra as bibliotecas do WPF. O link do resumo usa o `Hyperlink` do WPF dentro do texto da linha, e o filtro usa o evento de texto alterado da caixa; o clique no link e a digitação no filtro foram conferidos com controles simulados, não na tela.

### Estrutura
- **`Navigation`:** cada item tem `Group` (a seção), e um item da tabela mostra a seção com `New-WinForgeNavItem -Group`; os itens de uma seção ficam juntos na tabela. `Find-WinForgeNavReference` acha a referência "Página > Item" de um texto e o item que ela abre (o de nome mais longo, quando dois começam igual).
- **`Console`:** `Write-WinForgeKeyValue -Level Ok|Warn|Bad` pinta o valor; **`GuiDesign`:** `Get-WinForgeFactEntry` devolve o `Level` pela cor do valor.
- **`Core`:** `Get-WinForgeLastCheckup` lê a data do último Verificar o PC; o Início e o monitor usam essa função.
- **`Performance`:** `Get-WinForgePerformancePageStatus`, o resumo do alto da página, de uma leitura só do `Win32_OperatingSystem`. As contas de memória e de processador usam `[Math]::Max([double]0, ...)`.
- **`Security`:** as linhas do antivírus (`Get-WinForgeAntivirusRows`) trazem o nível de cada valor; o relatório continua usando só o texto.
- **Janela:** `New-GuiGroupHeading` (o título de uma seção), `New-GuiActivityText` (o texto da linha do resumo, com os links) e `Update-GuiPromptFilter` (o filtro). O XAML ganhou o estilo `SummaryLink` e a linha do filtro (`PromptFilterRow`, `PromptFilter`, `PromptFilterHint` e `PromptFilterEmpty`).
- **Ícones:** `rocket`, para a página Desempenho e o Acelerar agora.

## Build 3.29

Uma build grande, com o que faltava para o WinForge cuidar do PC de ponta a ponta, mais a revisão da tela de Programas.
- **Verificar o PC:** uma passada lê tudo (lixo, registro, atalhos, memória, inicialização, programas desatualizados, suporte do Windows, proteção e reinício) e corrige com um clique o que é seguro. Virou o botão principal do Início.
- **Página Desempenho:** Acelerar agora, Programas pesando agora e Liberar memória.
- **Histórico de mudanças,** com desfazer: registro, inicialização, ajustes, recursos do Windows e DNS.
- **Limpar o registro,** só referências quebradas, com backup.
- **Limpeza:** atalhos quebrados, arquivos duplicados, restos de programas desinstalados, apagar o espaço livre e mais navegadores, sombreadores e despejos de memória na limpeza personalizada.
- **Drivers** pelo Windows Update, dentro do WinForge, e as ferramentas oficiais dos fabricantes.
- **Suporte do Windows:** até quando a versão recebe atualizações de segurança, o ESU do Windows 10 e os requisitos do Windows 11. Entra na nota do Início.
- **Monitor na bandeja,** opcional, com avisos.
- **Gerenciar inicialização** com tarefas agendadas e o fabricante de cada programa.
- **13 ajustes novos** e o perfil Privacidade.
- **Dados online:** a lista de programas essenciais e as datas de suporte podem ser atualizadas sem uma nova versão.
- A revisão da tela de Programas (preparada como 3.28, que não foi publicada) entra aqui.

### Mudou para quem usa

**Verificar o PC** (Manutenção, e botão principal do Início)
- **Uma passada, só de leitura,** mostra uma linha por assunto: temporários e relatórios de erro, cache dos navegadores, referências quebradas no registro, atalhos quebrados, memória em uso, quantos programas abrem com o Windows, programas com versão nova (winget), suporte do Windows, proteção e reinício pendente.
- **Depois, uma lista de marcar com o que dá para corrigir ali mesmo.** Vem marcado o que é seguro:
  - apagar temporários e relatórios de erro (o Windows recria);
  - remover as referências quebradas do registro, com backup e desfazer;
  - mandar os atalhos quebrados para a Lixeira;
  - liberar memória, quando passa de 85% em uso;
  - atualizar as assinaturas do antivírus, quando têm mais de 3 dias.
  - O cache dos navegadores aparece desmarcado.
- **O que pede decisão vira uma linha com a tela que resolve:** o que desativar na inicialização, quais programas atualizar, o suporte do Windows, a proteção desligada, o reinício.
- A faixa diz quantas correções foram feitas e quanto espaço foi liberado ("3 correções feitas; 1,4 GB liberados"). Não marcar nada termina em "Cancelado".
- Uma leitura que falha vira "não foi possível ler" naquela linha, e as outras continuam.
- Na página Manutenção, é o primeiro cartão e o destacado; a Manutenção recomendada vem logo depois.

**Início**
- **Os botões da nota são Verificar o PC** (o principal) **e Manutenção recomendada.**
- **A nota conta o suporte do Windows.** Sem atualizações de segurança é um ponto grave ("O Windows 11 24H2 não recebe mais atualizações de segurança", com o botão "Ver como resolver"); faltando 90 dias ou menos, um ponto leve; no ESU do Windows 10, um ponto leve com a data do fim.
- O cartão **Windows** fica amarelo nesses casos, diz "sem atualizações de segurança" ou "atualizações até 13/10/2026", e abre Diagnóstico > Suporte do Windows (antes abria Sobre este PC).
- **Por onde começar:** Acelerar agora, Limpeza rápida, Instalar atualizações do Windows e Verificação rápida. Atualizar programas saiu daqui; Verificar o PC já aponta os programas desatualizados.

**Desempenho** (página nova, depois da Limpeza)
- **Acelerar agora:** libera memória e apaga os temporários do seu usuário, sem perguntas. Mostra a memória em uso antes e depois e o que foi apagado.
- **Programas pesando agora:**
  - mede por um instante o processador e a memória e mostra os programas que mais pesam, com o nome amigável ("Google Chrome", e não "chrome") e os processos do mesmo programa somados;
  - dá para fechar os que você marcar: primeiro como o X da janela, e só o que não fechar é encerrado;
  - processos do Windows não entram na lista, nada vem marcado e a confirmação vem com **Não** como padrão.
- **Liberar memória:** esvazia a memória que os programas não estão usando e, como Administrador, também a lista de espera (o cache de arquivos). A tela diz com honestidade o efeito: o Windows volta a usar a memória conforme os programas precisam.
- **Gerenciador de Tarefas:** abre o do Windows.

**Histórico de mudanças** (Manutenção)
- Lista o que o WinForge mudou no PC, com data e hora: ajustes, inicialização, recursos do Windows, DNS, limpeza do registro, aplicativos e programas removidos, drivers, atalhos, duplicados e restos enviados para a Lixeira, monitor ligado ou desligado.
- **Desfaz o que tem volta:** o registro (importa o backup), a inicialização (cada item volta ao estado de antes), os ajustes, os recursos do Windows e o DNS. Nada vem marcado.
- Desfazer um ajuste pela página Ajustes do Windows, ou o DNS pela página Rede, marca a mudança como desfeita aqui também.

**Limpeza**
- **Limpar o registro** (novo): só referências quebradas a programas e arquivos que não existem mais.
  - Procura em desinstaladores sem programa, itens de inicialização sem o arquivo, caminhos de aplicativos, o cache de nomes de programas e, como Administrador, DLLs compartilhadas, arquivos de ajuda e fontes.
  - Instaladores MSI e componentes do sistema ficam de fora. Um caminho numa unidade desconectada (pendrive) não conta como quebrado.
  - Salva um `.reg` antes de remover e anota no Histórico de mudanças, de onde dá para desfazer.
  - A tela diz com honestidade que isso não deixa o PC mais rápido: só tira do registro entradas que levam a lugar nenhum.
- **Remover atalhos quebrados** (novo): Área de Trabalho e Menu Iniciar, seus e de todos os usuários (estes com Administrador). Os atalhos vão para a Lixeira.
- **Encontrar arquivos duplicados** (novo): compara pelo conteúdo os arquivos de 1 MB ou mais de Downloads, Imagens, Documentos, Área de Trabalho ou outra pasta. Em cada grupo o mais antigo fica; nada vem marcado, e o que você marcar vai para a Lixeira.
- **Restos de programas desinstalados** (novo): procura pastas com o nome dos programas desinstalados pelo WinForge, em Arquivos de Programas, ProgramData e AppData, desde que nenhum programa instalado tenha esse nome. Nada vem marcado; vai para a Lixeira.
- **Apagar o espaço livre** (novo): o `cipher /w` do Windows, para que arquivos já apagados não possam ser recuperados. A tela explica quando vale a pena e o desgaste em SSD; a confirmação vem com **Não** como padrão.
- **Limpeza personalizada:** o cache dos navegadores inclui Brave, Opera, Opera GX e Vivaldi. Novos alvos, desmarcados: cache de sombreadores dos jogos (DirectX, NVIDIA e AMD) e despejos de memória de falhas.

**Atualizações**
- **Atualizar drivers** (novo): procura drivers no Windows Update e instala, aqui mesmo, os que você marcar.
  - Os recomendados vêm marcados; os opcionais, que o Windows só mostra na página de atualizações opcionais, vêm desmarcados.
  - Antes de instalar, cria um ponto de restauração quando o Windows deixa.
  - O andamento, as falhas com o código do Windows e o pedido de reinício funcionam como na instalação das atualizações do Windows.
- **Ferramentas do fabricante** (novo): lê o fabricante do PC, a placa de vídeo e o processador e indica o programa oficial. Dell Command | Update, Lenovo System Update e Intel Driver & Support Assistant são instalados pelo winget; HP Support Assistant, NVIDIA App e a detecção automática da AMD abrem a página oficial.
- Instalar atualizações do Windows, sem nada pendente, indica Atualizar drivers.

**Diagnóstico > Suporte do Windows** (novo)
- Até quando a versão e a edição deste Windows recebem atualizações de segurança: Home e Pro, Enterprise e Education, e LTSC têm datas diferentes.
- **Windows 10 22H2:** depois de 14/10/2025, diz se o PC está no ESU (pela data da última atualização instalada) ou como entrar nele, pela página do Windows Update, até 13/10/2026.
- **Requisitos do Windows 11,** no Windows 10: TPM 2.0, UEFI e Secure Boot, memória, disco, processador e 64 bits. O processador é avaliado pelo nome; os casos que só a lista da Microsoft decide aparecem como "não dá para saber pelo nome".
- As datas vêm do catálogo do WinForge, que pode ser atualizado em Sobre o WinForge > Conferir dados online.

**Programas > Gerenciar inicialização**
- **Entram as tarefas agendadas** de outros fabricantes que rodam ao entrar no Windows ou ao ligar o PC, onde ficam os atualizadores. Desativar uma delas a desativa no Agendador de Tarefas.
- **Cada item mostra quem publica o programa:** "Google LLC · Registro (usuário) · ...".
- A mudança entra no Histórico de mudanças, de onde dá para desfazer.
- A explicação de que desativar não remove o programa aparece no resumo antes da escolha. Ela indica também Programas > Aplicativos de inicialização.
- **A faixa diz quais itens não mudaram:** "1 de 2 não foi desativado: Audio". Antes era "1 de 2 não puderam ser alterados".
- Um item cuja mudança o Windows não manteve vira linha vermelha, como a faixa. Antes a linha era amarela.
- A lista separa as partes com "·": "Registro (todos os usuários) · C:\Windows\audio.exe · exige Administrador".

**Ajustes do Windows**
- **13 ajustes novos:**
  - Explorador: abrir em Este Computador, Finalizar tarefa pela barra de tarefas (Windows 11) e desativar a Reprodução Automática;
  - Privacidade e sugestões: recomendações do Iniciar (Windows 11), experiências personalizadas, pedidos de opinião, histórico de atividades, dados de diagnóstico no mínimo, acompanhamento dos programas abertos, fala online, personalização da digitação e compartilhamento de atualizações com outros PCs;
  - Energia e desempenho, entre os avançados: agendamento de GPU acelerado por hardware.
- Os recomendados não mudaram: continuam só os de baixo impacto.
- **Perfil novo, Privacidade:** o Essencial mais tudo o que reduz os dados enviados ao Windows e à Microsoft, também a busca na web e o Recall.

**Sobre o WinForge**
- **Monitor na bandeja** (novo, opcional): um ícone perto do relógio que avisa quando o disco enche, a proteção desliga ou há ameaça ativa, falta reiniciar, passa um mês sem verificação, o Windows perde o suporte ou há três ou mais programas com versão nova.
  - Cada aviso aparece no máximo uma vez a cada tanto tempo (de 12 horas a uma semana), e clicar nele abre a tela que resolve.
  - O menu do ícone abre o WinForge, roda Acelerar agora, Limpeza rápida e Verificar o PC, pausa os avisos por 24 horas e fecha o monitor.
  - Só lê; nada muda no PC sem o seu clique. Começa com o Windows por uma entrada do seu usuário em `Run`, sem Administrador.
- **Conferir dados online** (novo): baixa do repositório do projeto a lista de programas essenciais e as datas de suporte do Windows. Sem internet, vale a cópia embutida; uma cópia que não passa na conferência é descartada. Nenhum dado do PC é enviado.

**Em todas as telas de Programas**
- **Fechar uma lista sem marcar nada termina em "Cancelado"**, como em Atualizações. Antes era "Nada a fazer: nada marcado". O mesmo vale para deixar em branco o nome da busca, que é o que o botão Cancelar da janela devolve.
- **O andamento vai para a barra de progresso.**
  - Vão para lá: ler a lista do winget, buscar, procurar os aplicativos, ler os recursos do Windows, copiar os drivers e somar as pastas pessoais.
  - Antes, linhas como "Buscando por: chrome" e "Lendo a lista de programas instalados..." ficavam no resumo depois do fim.
  - Remover aplicativos e mudar recursos mostram o item da vez e a porcentagem ("Removendo aplicativos · 2 de 3: Clima"), como instalar e desinstalar já faziam.
- **Os avisos aparecem no resumo durante a pergunta.** Antes, eram linhas amarelas ou cinza soltas, que a janela recolhe enquanto a pergunta espera:
  - "Remova só o que você reconhece e não usa", em Desinstalar;
  - "Alguns instaladores podem pedir para fechar programas abertos ou reiniciar o PC", nos essenciais e na busca;
  - a explicação de Gerenciar inicialização.
- **A confirmação diz o que foi marcado:** "Desinstalar Alfa App e Zeta App?" ou "Remover Clipchamp?". Com mais de três, "Remover os 5 aplicativos marcados?".
  - Antes era "Deseja desinstalar 2 programa(s)?".
  - A lista "Programas que serão desinstalados", em cinza, não aparecia durante a pergunta.
- Na janela, a tabela "Resumo" saiu de Remover aplicativos, Recursos opcionais, Backup e Restaurar, porque cada item já tem a sua linha ou a sua seção no resumo. No console, ela continua.
- As contagens usam o singular e o plural certos, sem "(s)".

**Instalar programas essenciais**
- Cada programa diz o que é, por exemplo "Básico · Abre e cria arquivos compactados (.zip, .7z, .rar)". Antes aparecia só a categoria.
- O resumo avisa, antes da lista, que o que já estiver instalado é atualizado, se houver versão nova.

**Buscar e instalar programas**
- **Cada resultado mostra o ID, a versão e a fonte:** "Vendor.Tool · versão 3.1 · winget" ou "9NBLGGH4NNS1 · Microsoft Store". Antes era "Vendor.Tool  -  3.1", e a versão "Unknown" da loja aparecia como veio.
- A lista diz "2 resultados para 'cool'", e não mais "Encontrados 2 pacote(s)".
- Sem resultado, a tela sugere tentar outro nome, uma parte do nome ou o ID.
- **A linha genérica depois da instalação saiu.** Era "Alguns instaladores podem exigir interação manual ou reinicialização". O aviso agora vem antes da lista, e o pedido de reinício de um instalador já aparece na linha do programa.

**Listar programas instalados**
- **O resumo conta os programas:**
  - o total;
  - quantos são do repositório do winget e quantos da Microsoft Store;
  - quantos não têm pacote no winget;
  - quantos têm atualização.
- A faixa diz, por exemplo, "52 programas instalados; 5 com atualização no winget". Antes, o resumo ficava vazio e a faixa dizia "Concluído com sucesso". A tabela continua nos detalhes técnicos.
- Quando há atualização, a tela indica Atualizações > Atualizar programas (winget).
- **Os erros do winget agora são separados:**
  - com a tabela lida, viram ressalva ("a lista pode estar incompleta");
  - sem a tabela, a faixa fica vermelha e diz o motivo.
  - Antes, qualquer código diferente de zero virava "Concluído com ressalvas: o winget terminou com código -1978335231 (0x8A150001)".

**Desinstalar programas**
- **Corrigido: a lista parava no primeiro programa com ID local com espaço.**
  - Para o que só encontra no Windows, o winget monta um ID com o nome do programa, como "ARP\Machine\X86\Microsoft Edge Update".
  - O WinForge tratava o espaço como fim da tabela, e todos os programas seguintes sumiam da lista.
  - Listar programas instalados, que agora conta os programas, usa a mesma leitura.
- **Um ID que o winget mostra cortado não vai para o comando.**
  - O winget corta com reticências o que não cabe na largura da tabela, inclusive o ID.
  - A lista avisa "ID incompleto na lista do winget". Se ele for marcado, a linha diz o que fazer: "desinstale em Programas > Aplicativos instalados".
  - Antes, o comando saía com o ID cortado e só podia falhar.
  - Buscar e instalar e Atualizar programas tratam o ID cortado do mesmo jeito.
- Duas versões instaladas do mesmo pacote viram uma opção só na lista.
- Depois de desinstalar, a tela indica Limpeza > Restos de programas desinstalados, que procura as pastas que o programa deixou.
- Quando a leitura da lista falha, a tela diz o motivo: "código de saída 1", ou que o WinForge não reconheceu a tabela do winget. Antes era "(código 1)".

**Remover aplicativos do Windows**
- **Os erros mais comuns do Windows viram frase, com o código:**
  - "o aplicativo está aberto; feche-o e tente de novo — erro 0x80073D02";
  - "o Windows não permitiu a remoção — erro 0x80073CFA".
  - Antes aparecia a mensagem inteira do Windows, com inglês e português misturados.
- Um aplicativo que já não estava instalado (0x80073CF1) conta como removido: "Clima: já não estava instalado".
- **A faixa diz quais:** "Clima removido" e "1 de 2 não foi removido: Candy Crush". Antes eram "1 removido(s)" e "1 de 2 com falha".
- Quando nenhum aplicativo da lista está no PC, a faixa diz isso ("nenhum aplicativo da lista está instalado"), em vez de "nada a remover".

**Recursos opcionais do Windows**
- **Um recurso com mudança pendente aparece como "Mudança pendente", com o pedido de reinício.**
  - Antes, ele sumia da tela sem explicação.
  - Com todos pendentes, a tela dizia "Nenhum dos recursos conhecidos está disponível nesta edição do Windows". Agora diz que eles esperam o reinício.
- **Antes da pergunta, o resumo mostra "O que vai mudar":** cada recurso, com "Ligar" ou "Desligar", e os alertas de risco.
  - A pergunta ficou curta: "Ligar Compartilhamento SMB 1.0?" ou "Aplicar as 2 mudanças?".
  - Antes era "Confirmar: ligar X; desligar Y?".
- Cada linha diz o que mudou: "Subsistema do Windows para Linux (WSL): ligado; termina ao reiniciar o PC". Antes era "feito".
- **A faixa diz o que mudou e o que não mudou:**
  - "2 recursos alterados" ou "Windows PowerShell 2.0 desligado", em vez de "Concluído com sucesso";
  - na falha, "1 de 2 não mudou: Hyper-V", em vez de "1 de 2 com falha".
- Os erros mais comuns viram frase, com o código: 0x800F081F, 0x800F0906, 0x800F0907, 0x800F080C e 0x80070005.
- O aviso amarelo "Reinicie o PC para concluir a mudança" saiu. A faixa já pede o reinício, e cada linha diz o que termina ao reiniciar.

**Backup antes de formatar**
- **Corrigido: "Concluído com ressalvas: com ressalvas: Programas instalados".** Agora a faixa diz "problemas em Programas instalados". No sucesso, diz "backup salvo na pasta Backup-...".
- **O resumo lista as pastas pessoais que ficam de fora**, na seção "Copie à parte (não estão no backup)".
  - Vêm das maiores para as menores, até 8; as outras ficam no LEIA-ME.
  - Antes, só o LEIA-ME as listava.
- Uma pasta de destino que não existe termina em "Não foi concluído: a pasta 'E:\' não existe". Antes terminava em "Cancelado".
- Fora de Documentos, o aviso final pede para conferir que a pasta não está no disco que será formatado. Antes, mandava copiar para um pendrive em qualquer caso.
- Se o Export-WindowsDriver falha, a nova tentativa com o pnputil fica nos detalhes técnicos, e o resumo diz só o resultado.
- A lista de programas diz "2 programas para reinstalar pelo winget; a lista completa tem 52 programas". Quando o winget não gera a lista, o código vem como frase.

**Restaurar a partir de um backup**
- **Corrigido: o código 259 do pnputil virava ressalva.**
  - Esse código quer dizer que os dispositivos já usam drivers iguais ou mais novos, o comum depois do Windows Update.
  - Agora a linha diz "Drivers adicionados ao Windows; os dispositivos deste PC já usam drivers iguais ou mais novos".
- **Corrigido: a faixa repetia "com ressalvas" e listava os itens fora da ordem em que rodaram.**
- **A escolha do backup mostra a data e o PC do próprio backup:** "criado em 20/10/2026 18:30 · ANA-PC". Antes mostrava a data da pasta, que muda quando a pasta é copiada para outro disco.
- Sem backup em Documentos, a tela diz onde procurou e indica "Outra pasta".
- Colar o caminho do backup.json, ou de outro arquivo da pasta, abre a pasta dele.
- **"O que restaurar?" diz o que cada parte faz neste PC, com as quantidades:**
  - "Reinstala pelo winget 52 programas";
  - "Adiciona 120 drivers ao Windows";
  - "Recria 3 redes salvas, com as senhas".
  - Antes, repetia as descrições do backup, como "ocupa de centenas de MB a alguns GB".
  - Tudo o que está no backup vem marcado. Antes, as redes Wi-Fi vinham desmarcadas.
- As redes aparecem pelo nome guardado no perfil ("Casa da Ana"), e não pelo nome do arquivo ("Wi-Fi-Casa da Ana").
- O aviso de que reinstalar os programas demora aparece antes da confirmação. A confirmação diz "Restaurar os 4 itens marcados neste PC?", e não mais "Restaurar 4 item(ns) neste PC?".
- **O erro do winget import vira frase:** "O winget terminou com problemas: algum programa da lista não foi instalado — erro 0x8A150034". A tela não manda mais "ver a saída acima", porque na janela essa saída fica nos detalhes técnicos.
- Uma data inválida no backup.json não derruba a tela: aparece "Não disponível".
- A faixa conta o que foi restaurado: "4 itens restaurados".

**Também em Atualizações** (o mesmo executor do winget)
- Em "Atualizar tudo o que o winget oferecer", uma falha agora diz o motivo, por exemplo "o winget terminou com problemas: algum programa não foi atualizado — erro 0x8A15002C". Antes, a frase saía quebrada, como "o winget terminou com outra instalação está em andamento".

**O que não foi visto:** a janela não foi aberta num Windows de verdade. O desenho foi conferido numa prévia em HTML com as mesmas medidas e cores, e o script da janela foi validado contra as bibliotecas do WPF. As respostas do Windows foram simuladas:
- o winget, por uma função que responde o que cada cenário combinou, com tabelas alinhadas como as dele;
- o Remove-AppxPackage, os cmdlets de recursos opcionais, o registro da inicialização, o pnputil e o netsh;
- nas funções novas, o Windows Update (busca de drivers), as tarefas agendadas, o registro, os atalhos (.lnk), os processos, a memória, o Defender e o `cipher`.

Partes que só rodam no Windows e não foram executadas aqui: a liberação de memória (as chamadas `EmptyWorkingSet` e `NtSetSystemInformation`; o código C# foi conferido como C# 5, o compilador do Windows PowerShell 5.1), o `reg export` e o `reg import` do limpador do registro, o `cipher /w`, a busca de drivers com o critério `Type='Driver'` e o monitor na bandeja (`WinForge.Agent.ps1`, que usa o ícone de notificação do Windows Forms). O monitor teve as regras conferidas (quando conferir, quando avisar, a pausa e cada leitura); o ícone e os balões, não.

As datas de suporte seguem as páginas de ciclo de vida da Microsoft, consultadas em 30/10/2026; o ESU do Windows 10 para consumidores vai até 13/10/2026. Os IDs do winget das ferramentas da Dell, da Lenovo e da Intel foram conferidos no repositório do winget; HP, NVIDIA e AMD abrem a página oficial. A Auditoria de segurança continua com a própria tabela de datas, com os mesmos valores do catálogo.

Os significados dos códigos seguem as tabelas da Microsoft, consultadas em 25/10/2026: códigos de retorno do winget e do pnputil, e erros de implantação de aplicativos. Os IDs locais com espaço e os IDs cortados com reticências seguem saídas do winget publicadas por usuários.

O catálogo de essenciais continua com o Python 3.14. O Python 3.15 saiu em 9/10/2026, mas não foi possível confirmar o pacote dele no winget.

### Estrutura
- **Módulos novos:**
  - `Checkup` (Verificar o PC: cada leitura é uma função `Get-WinForgeCheckup*`, e `Invoke-WinForgeCheckupFix` aplica cada correção);
  - `Performance` (memória, processos e Acelerar agora, com o C# de `EmptyWorkingSet` e da lista de espera);
  - `RegistryCleaner` (as buscas por categoria, o backup em `.reg` e `Clear-WinForgeRegistryIssues`, sem perguntas, que a Verificação do PC usa);
  - `Journal` (o desfazer de cada tipo de mudança e a tela do histórico);
  - `CleanupTools` (atalhos quebrados, duplicados, restos de programas e o espaço livre);
  - `Drivers` (a busca de drivers no Windows Update e as ferramentas dos fabricantes);
  - `WindowsSupport` (o suporte por versão e edição e os requisitos do Windows 11);
  - `Catalog` (o catálogo embutido, a conferência do arquivo baixado e o download);
  - `Agent` (as regras do monitor na bandeja e o liga/desliga). O ícone é o `WinForge.Agent.ps1`, na raiz.
- **`Core`:** o diário de mudanças (`Add-WinForgeChange`, `Get-WinForgeChanges`, `Set-WinForgeChangesUndone`...) e `Add-WinForgeUninstalledProgram` ficam aqui, para qualquer módulo anotar sem depender de outro.
- **`WindowsUpdate`:** a busca e a instalação aceitam um critério (`-Criteria`), e cada atualização traz `BrowseOnly`.
- **`Startup`:** novos `Get-WinForgeStartupTasks`, `Get-WinForgeStartupPublisher`, `Get-WinForgeStartupEntries` e `ConvertTo-WinForgeStartupUndoItem`; `Set-WinForgeStartupItemEnabled` liga e desliga tarefas agendadas.
- **`Shell`:** novo `Get-WinForgeShortcutTarget`.
- **`Cleanup`:** `Get-WinForgeShaderCachePaths`, `Get-WinForgeCrashDumpPaths`; `Invoke-WinForgeCleanupTargets -NoSummary`.
- **`Tweaks`:** aplicar e desfazer anotam no Histórico de mudanças; 13 ajustes novos e o perfil Privacidade.
- **`Navigation`:** a página Desempenho, 16 itens novos, o suporte do Windows na leitura do Início, e a busca dá um ponto a mais à palavra inteira no rótulo.
- **Janela:** o parâmetro `-Action` roda um item da navegação ao abrir (o monitor usa); os botões da nota de saúde são dois.
- **`catalog/catalog.json`** (só no repositório): a cópia publicada do catálogo, que Conferir dados online baixa.
- **`Core`:** novos `Get-WinForgeSelectionQuestion` (a confirmação com os nomes marcados) e `Get-WinForgeErrorCode`.
- **`Software`:**
  - `ConvertFrom-WinForgeWingetTable` aceita IDs `ARP\` e `MSIX\` com espaço.
  - Novos `Test-WinForgeWingetIdTruncated`, `Get-WinForgeWingetSourceLabel`, `Format-WinForgeWingetPackageDescription` e `Get-WinForgeInstalledSoftwareCounts`.
  - `Get-WinForgeWingetExitResult` conhece 0x8A15002C, 0x8A150034 e 0x8A150035.
  - `Invoke-WinForgeWingetPackages` não chama o winget com um ID cortado. A dica de cada operação vem de `Get-WinForgeWingetVerbs`.
  - `Show-WinForgeInstalledSoftware` lê a tabela com `Invoke-WinForgeCapture -Echo` em vez de `Invoke-WinForgeNative`.
  - O catálogo de essenciais ganhou `Descricao` e passou a vir de `Get-WinForgeCatalog`.
- **`PreinstalledApps`:** novo `Get-WinForgeAppRemovalResult`.
- **`WindowsFeatures`:** novos `Get-WinForgeFeaturePendingLabels` e `Get-WinForgeFeatureErrorText`.
- **`Backup`:**
  - `Read-WinForgeBackupDestination` devolve `Path`, `IsDefault` e `Missing`.
  - Novos `Write-WinForgeBackupUserFolders`, `Get-WinForgeBackupProblemText`, `Format-WinForgeBackupDate`, `Get-WinForgeBackupChoiceDescription`, `Get-WinForgeRestoreOptions` e `Get-WinForgeWifiProfileName`.
  - As mensagens de `Read-WinForgeBackupFolder` foram escritas para entrar no meio de uma frase.
- As linhas soltas de `Write-Host` deram lugar a `Write-WinForgeStatus`. As linhas "executando" e a barra de texto do backup deram lugar a `Write-Progress`.

## Build 3.27

Revisão da tela de Atualizações.
- No winget, a escolha agora mostra antes o que tem versão nova. "Atualizar todos" atualiza cada programa da lista e diz o que deu certo em cada um.
- No Windows Update, cada falha vem com o motivo e o código, o tamanho aparece como "até", e cancelar a lista termina em "Cancelado".
- O andamento das duas telas vai para a barra de progresso, com a porcentagem do download e da instalação.

### Mudou para quem usa

**Instalar atualizações do Windows**
- **O andamento vai para a barra de progresso.**
  - Procurar, preparar, baixar e instalar aparecem ao lado da barra, com a porcentagem e a atualização da vez: "Baixando as atualizações · 1 de 3: ...".
  - Antes, "Procurando atualizações..." e "Preparando a instalação..." ficavam no resumo depois do fim.
  - A porcentagem do download e da instalação só aparecia nos detalhes técnicos, numa linha "42% (42/100)" que parecia contar 100 itens.
- **O tamanho é o máximo, e a tela diz isso:** "até 500 MB". O Windows informa o tamanho máximo do download; com as atualizações expressas, ele costuma ser menor.
- **O aviso de não desligar o PC aparece antes da pergunta, no resumo,** junto com o lembrete de que parar no meio não garante parar a instalação. Antes, o lembrete era uma linha cinza que só aparecia depois de confirmar.
- **A pergunta fala certo:** "Baixar e instalar 3 atualizações?", ou "Instalar 1 atualização?" quando ela já foi baixada. Antes era "Baixar e instalar 3 atualização(ões)?".
- **Cada falha diz o motivo, com o código do Windows.**
  - Os códigos mais comuns viram frase. Por exemplo: "outra instalação estava em andamento ou falta reiniciar o PC — erro 0x80240016" e "a imagem do Windows está danificada; use Reparo > Reparar o Windows (DISM + SFC) — erro 0x80073712".
  - Antes aparecia "Falhou (falhou (0x80240016))".
- **A faixa conta o que foi instalado.** Agora é "2 de 3 instaladas (1 com erros); 1 falhou", em vez de "1 de 3 falhou; 1 com erros". Quando nada é instalado: "nenhuma das 3 atualizações foi instalada".
- **Corrigido: "Reinicie o PC para concluir" quando nenhuma atualização foi instalada.** Se o Windows Update pede reinício mas tudo falhou, a faixa não manda mais reiniciar "para concluir". O motivo de cada falha diz o que fazer.
- **A consulta que falha diz o motivo.**
  - Exemplos: "o serviço Windows Update está desativado — erro 0x80070422" e "o Windows Update não respondeu em 5 minutos".
  - Antes, toda falha era "Windows Update indisponível".
  - A consulta agora espera até 5 minutos. Antes eram 2, pouco para a primeira busca depois de muito tempo, e um PC lento podia dar como indisponível um Windows Update que só estava demorando.
- **O download que falha inteiro diz o motivo**, com o código do Windows quando houver, em vez de "O download das atualizações falhou (código 4)".
- **Cancelar a lista termina em "Cancelado"**, como as outras telas. Antes era "Nada a fazer: nada marcado". O mesmo vale para recusar seguir com reinício pendente ou na bateria; o que fazer ("Reinicie o PC e tente de novo") fica no resumo.
- "Reinicie o PC para concluir a instalação" no resumo é uma informação, e não mais um aviso amarelo ao lado de uma faixa verde.

**Atualizar programas (winget)**
- **Corrigido: dava para escolher sem ver a lista.**
  - A pergunta "Como deseja continuar?" aparecia com o resumo vazio. A tabela do winget ficava nos detalhes técnicos, que a janela recolhe durante a pergunta.
  - Agora o resumo mostra o que tem atualização, de qual versão para qual: "Google Chrome: 130.0.6723.70 para 130.0.6723.92". Vão até 12 programas, e o resto aparece contado.
  - A pergunta virou "O que deseja atualizar?", com "Atualizar todos (5)".
- **"Atualizar todos" atualiza a lista mostrada, um programa por vez.**
  - Cada programa tem a sua linha: "Mozilla Firefox: atualizado para a versão 132.0", ou o motivo da falha.
  - A faixa diz quantos foram atualizados e quais falharam: "1 de 3 não foi atualizado: Google Chrome".
  - Antes, um único `winget upgrade --all` terminava em "Concluído com sucesso" ou em "winget terminou com código ...", sem dizer qual programa.
  - Quando a lista do winget não pode ser lida, a tela avisa e "Atualizar tudo o que o winget oferecer" continua usando o comando único.
- **Os códigos mais comuns do winget viram frase.**
  - Programa aberto, outra instalação em andamento, falta de espaço, instalador que não confere, sem internet e bloqueio por política.
  - O código vai junto ("— erro 0x8A150101"). Um código do próprio instalador aparece em decimal ("código de saída 5").
  - Um instalador que pede reinício para terminar conta como feito, e a faixa pede o reinício. Antes ele contava como falha.
- **"Não atualizar" termina em "Cancelado"**, como as outras telas. Antes era "Nada a fazer: dispensado pelo usuário".
- O que a tela cobre ("Só entram programas que o winget reconhece...") aparece no resumo antes da pergunta. Antes eram linhas amarela e azul, só nos detalhes técnicos.
- Atualizar a lista de pacotes e procurar atualizações vão para a barra de progresso. Só o problema vira mensagem: "Não foi possível atualizar a lista de pacotes do winget; a consulta usa a lista guardada neste PC".
- Na janela, a tabela "Resumo" saiu: cada programa já tem a sua linha no resumo da execução. No console ela continua, porque lá a saída do winget se mistura às mensagens.
- Sem atualizações: "Os programas que o winget reconhece estão em dia".

**Também em Programas** (o mesmo executor do winget)
- As telas de instalar e desinstalar usam as mesmas linhas por programa e as mesmas faixas:
  - "7-Zip instalado";
  - "7-Zip não foi instalado: código de saída 1";
  - "1 de 2 não foi desinstalado: Alfa App".
- Antes eram "Concluído com sucesso", "nenhum pacote foi processado: 7-Zip" e "1 de 2 com falha".

**O que não foi visto:** a janela não foi aberta num Windows de verdade. O desenho foi conferido numa prévia em HTML com as mesmas medidas e cores, e o script da janela foi validado contra as bibliotecas do WPF. As respostas do Windows foram simuladas:
- o Windows Update, por uma API de mentira com os mesmos métodos;
- o winget, por uma função que responde o que cada cenário combinou.

As telas rodaram no mesmo executor da janela. Os significados dos códigos seguem as tabelas da Microsoft (códigos do Windows Update Agent e códigos de retorno do winget), consultadas em 25/10/2026.

### Estrutura
- **`WindowsUpdate`:**
  - Consulta:
    - `Get-WinForgeWindowsUpdateList` deu lugar a `Find-WinForgeWindowsUpdates`, que devolve `Updates` e `Problem`, o motivo de a consulta não ter funcionado. O tempo limite passou para 300 s.
    - Novo `Get-WinForgeWindowsUpdateProblem`.
  - Novos `Get-WinForgeWindowsUpdateHResultText`, `Format-WinForgeUpdateError`, `Get-WinForgeUpdateDownloadError` e `Get-WinForgeUpdateSizeText`.
  - Andamento: `Wait-WinForgeUpdateJob` usa `Write-Progress` com a porcentagem, e o script do outro runspace guarda o código do download que falhou (`DownloadCode`, `DownloadHResult`).
- **`Software`:**
  - Novos `Write-WinForgeWingetUpgradeList` (o que tem atualização, no resumo) e `Get-WinForgeWingetVerbs`.
  - `Get-WinForgeWingetExitResult` traduz os códigos conhecidos do winget.
  - `Invoke-WinForgeWingetPackages`:
    - anda pela barra de progresso;
    - trata o pedido de reinício como feito;
    - no fim, escreve a tabela só no console.
  - "Todos" com a lista lida é atualizado programa por programa.
  - As linhas soltas de `Write-Host` deram lugar a `Write-WinForgeStatus`, e as linhas "executando" a `Write-Progress`.

## Build 3.26

Revisão da tela de Reparo.
- As faixas dizem o que cada ferramenta concluiu ("nenhum arquivo corrompido foi encontrado", "a unidade C: foi otimizada"), e não só "Concluído com sucesso".
- Na janela, o resumo mostra antes de cada pergunta o que vai acontecer: o que cada ferramenta faz, quanto pode demorar e por que o reparo offline do disco é pedido. Antes, a pergunta do reparo completo aparecia com o resumo vazio.
- O SFC conta cada arquivo sem reparo uma vez e diz quais são.
- O CHKDSK não diz mais "Nenhum erro foi encontrado" quando o próprio texto pede o reparo offline. A unidade só é marcada para reparo depois que o agendamento é aceito.

### Mudou para quem usa

**Em todas as telas do Reparo**
- **O andamento vai na barra de progresso.** "Executando. Não feche esta janela." ficava no resumo depois do fim.
- **A linha final diz o que a ferramenta concluiu:** "Otimizar a unidade do sistema: a unidade C: foi otimizada." Antes era "Otimizar a unidade do sistema concluído com sucesso.", e a faixa dizia só "Concluído com sucesso". O mesmo vale para **Limpeza > Limpar componentes do Windows (WinSxS)**, que usa o mesmo executor.
- O pedido de reinício não se repete na faixa. Agora é "O reparo da imagem termina na próxima reinicialização. Reinicie o PC para concluir.". Antes era "Concluído; reinicie o Windows para finalizar. Reinicie o PC para concluir.".

**Reparar o Windows (DISM + SFC)**
- **Corrigido: a pergunta "Deseja iniciar o reparo?" aparecia sem contexto.** O aviso "Serão executados DISM e SFC, nesta ordem" era uma linha amarela, e a janela não mostra esse tipo de linha durante a pergunta. Agora o resumo explica o que cada ferramenta faz e avisa que pode levar bastante tempo.
- A descrição de cada ferramenta não se repete no meio do reparo. O resumo fica com o resultado de cada uma e o tempo que levou.
- **A faixa diz o que deu errado:** "o DISM não encontrou os arquivos de que precisa para o reparo — erro 0x800F081F". Antes era "DISM ou SFC falhou; revise a saída". No sucesso, a faixa traz o que o SFC concluiu, por exemplo "o DISM reparou a imagem do Windows; nenhum arquivo corrompido foi encontrado".
- **Na Manutenção:**
  - A conferência prévia do DISM (/CheckHealth) aparece na barra de progresso e o resultado ocupa uma linha só.
  - O resumo explica que o DISM completo só roda se o SFC não conseguir reparar tudo.
  - Quando o SFC é repetido depois do DISM e termina bem, a faixa diz "depois do DISM, a nova verificação do SFC terminou sem pendências". Ela não diz mais "nenhum arquivo corrompido foi encontrado", o que contradiria a primeira passada.

**Reparar imagem e componentes (DISM)**
- **Os erros mais comuns vêm explicados, com o que fazer.** Antes aparecia só "código de saída 0x800F081F".
  - 0x800F081F (os arquivos de reparo não foram encontrados) e 0x800F0906 (não foi possível baixá-los): a tela indica conferir a internet e o Windows Update.
  - 0x800F0907 (uma política de rede impediu o download): a tela indica falar com o suporte de TI, no caso de PCs de empresa.
- A faixa diz "a imagem do Windows está íntegra". Quando o DISM avisa que consertou algo, diz "a imagem do Windows tinha danos e foi reparada".

**Verificar arquivos do sistema (SFC)**
- **Corrigido: o mesmo arquivo sem reparo era contado mais de uma vez.** O SFC repete a linha de cada arquivo no CBS.log a cada passada, e um único arquivo aparecia como "3 arquivo(s) corrompido(s)". Agora cada arquivo conta uma vez: "1 arquivo corrompido não pôde ser reparado".
- **Os nomes desses arquivos aparecem no resumo**, junto com o caminho do CBS.log.
  - O WinForge lê os nomes entre aspas simples e entre aspas duplas (o formato da documentação da Microsoft). Antes, o formato com aspas duplas não era lido e o nome virava "arquivo".
  - A linha "Could not reproject corrupted file" também conta.
- **Corrigido: uma passada anterior do SFC podia entrar na conta.** O CBS.log era lido a partir de um minuto antes da pergunta. Se o SFC fosse repetido logo depois do DISM, os arquivos da primeira passada podiam aparecer como não reparados na segunda. Agora conta só o que foi registrado depois de a ferramenta começar.
- A faixa diz "nenhum arquivo corrompido foi encontrado" ou "arquivos corrompidos foram encontrados e reparados".
- **O próximo passo vai para o resumo.** Quando sobram arquivos sem reparo, a tela indica "use Reparo > Reparar o Windows (DISM + SFC)". Antes era uma linha cinza, só nos detalhes técnicos. A mesma dica saiu de antes da pergunta: agora ela só aparece quando serve.
- Com um reparo pendente, a faixa diz "depois de reiniciar, rode o SFC de novo".

**Verificar o sistema de arquivos (CHKDSK)**
- **Corrigido: "Nenhum erro foi encontrado" seguido de um pedido de reparo offline.** Com o código 0 e a frase do /spotfix no texto, a tela dizia as duas coisas. Agora o WinForge primeiro vê se há reparo offline e só depois escreve a mensagem: "A verificação encontrou problemas que só o reparo offline corrige."
- **Corrigido: um agendamento que falhava deixava a unidade marcada.**
  - Antes, o WinForge marcava a unidade para reparo (`fsutil dirty set`, que não se desfaz) e só depois agendava a verificação (`chkntfs /C`).
  - Se o agendamento falhasse, a tela dizia "não foi possível agendar", mas a unidade já estava marcada e o Windows verificaria o disco na inicialização.
  - Agora o agendamento vem primeiro e a marcação por último. Se o agendamento falhar, nada muda.
- **O tempo do reparo offline aparece no resumo durante a pergunta:** "pode levar de minutos a horas (principalmente em HDD)". Antes era uma linha cinza, que a janela não mostrava enquanto a pergunta esperava. O mesmo vale para a pergunta no fim da Manutenção.
- Recusar o agendamento termina com "Para agendar depois, rode esta verificação de novo."
- As faixas dizem o resultado com a unidade:
  - "nenhum erro foi encontrado na unidade C:";
  - "erros foram encontrados e corrigidos na unidade C:";
  - "reparo agendado para a próxima inicialização" (antes, "próximo boot").
- Com um código fora da tabela da Microsoft (4 ou mais), a tela diz que o reparo offline é oferecido por segurança.

**Detectar dispositivos e drivers**
- **Num Windows 10 anterior à versão 2004, a tela explica em vez de falhar com um código.**
  - O `pnputil /scan-devices` só existe a partir dessa versão.
  - Agora a tela diz o que a função exige e indica a opção "Verificar se há alterações de hardware" do Gerenciador de Dispositivos.
  - Na Manutenção, a etapa aparece como ignorada.

**O que não foi visto:** a janela não foi aberta num Windows de verdade. O desenho foi conferido numa prévia em HTML com as mesmas medidas e cores, e o script da janela foi validado contra as bibliotecas do WPF. As respostas do Windows foram simuladas:
- o DISM, o SFC e o CBS.log;
- o CHKDSK, o fsutil e o chkntfs;
- o defrag e o pnputil.

As telas rodaram no mesmo executor da janela. Os formatos de linha do CBS.log e os códigos de erro do DISM seguem a documentação da Microsoft e registros publicados por usuários, consultados em 24/10/2026. O texto exato pode variar entre versões do Windows.

### Estrutura
- **`Repair`:**
  - `Invoke-WinForgeTool`:
    - O andamento usa `Write-Progress`.
    - O analisador recebe também a hora em que a ferramenta começou.
    - Novos parâmetros `-SuccessDetail`, `-MinimumBuild`, `-MinimumVersion` e `-UnavailableHint`.
    - A linha final vem do novo `Write-WinForgeToolOutcome`, que também escreve as observações (`Notes`) do resultado.
    - Dentro de um fluxo (`-Embedded`), a descrição não vira mensagem.
  - Novos `Get-WinForgeDismResult` (códigos conhecidos do DISM) e `Test-WinForgeWindowsBuildBelow`.
  - SFC:
    - `Get-WinForgeSfcLogSummary` conta arquivos únicos e lê os dois formatos de nome e as linhas "Could not reproject" (novo `Get-WinForgeSfcLogFileName`). A margem de tempo é de 2 segundos.
    - O novo `Get-WinForgeSfcUnrepairedResult` monta a ressalva.
    - O analisador deixou de ser uma closure.
  - `Invoke-WinForgeDismAndSfc` usa mensagens em vez de texto solto. O novo `Get-WinForgeRepairFailureText` escreve a faixa de falha.
  - CHKDSK: `Set-WinForgeChkdskStartupRepair` roda `chkntfs /C` antes de `fsutil dirty set`.
  - `Get-WinForgeCbsLogPath` monta o caminho como texto (ele também aparece na tela) e usa `C:\Windows` quando `SystemRoot` está vazio.
- **`Maintenance`:** a explicação do reparo offline no fim da manutenção é uma mensagem.

## Build 3.25

Revisão da tela de Segurança.
- As faixas de resultado dizem o que a tela encontrou: os pontos de atenção do Estado da proteção, um a um; se as assinaturas mudaram de versão; quantas ameaças a verificação achou.
- Na janela, o que fazer em cada ponto da auditoria, os nomes das atualizações pendentes e onde estava cada ameaça aparecem no resumo. Antes ficavam só nos detalhes técnicos. A Verificação completa explica o que faz antes de perguntar se pode começar.
- O suporte do Windows considera a edição: o Windows 11 24H2 Home e Pro recebeu a última correção em 13/10/2026, e a auditoria agora diz isso.
- A auditoria não dá nota quando menos da metade da proteção pôde ser verificada.
- Datas no mesmo formato em qualquer idioma do Windows.

### Mudou para quem usa

**Em todas as telas da Segurança**
- **O andamento vai na barra de progresso.** "Consultando o antivírus e o firewall...", "Consultando o Windows Update...", "Baixando as assinaturas..." e "Verificando..." ficavam no resumo depois do fim, como se a tela ainda estivesse trabalhando.
- **Corrigido: as datas seguiam o idioma do Windows.** As das assinaturas e das últimas verificações, e a do fim do suporte na auditoria, saíam com pontos num Windows em alemão ("24.10.2026"). Agora são sempre "24/10/2026 08:00".
- "1 ameaça encontrada", "3 atualizações pendentes" e "2 pontos de atenção", em vez de "ameaça(s)", "atualização(ões)" e "ponto(s)". Listas com "e": "Rede privada e Rede pública".
- Para as atualizações pendentes, a tela indica **Atualizações > Instalar atualizações do Windows**, que instala dentro do WinForge. Antes indicava **Windows Update**, que só abre as Configurações do Windows.

**Estado da proteção**
- **A faixa conta e nomeia os pontos de atenção:** "5 pontos de atenção: proteção em tempo real desligada, assinaturas com 10 dias, 2 ameaças ativas, firewall desligado (Rede pública) e 7 atualizações pendentes". Antes, a faixa repetia só a última mensagem ("7 atualização(ões) do Windows pendente(s)...").
- O que não pôde ser lido vem depois, na mesma frase: "nenhum ponto de atenção no que foi lido; não foi possível consultar o firewall".
- **Os nomes das atualizações pendentes entram no resumo** (até 5, e "E mais 2 atualizações."). Antes eram linhas cinza, só nos detalhes técnicos.
- **Corrigido: com outro antivírus, a tela mostrava as assinaturas do Defender de reserva.** Elas apareciam logo abaixo de "Outro antivírus em uso: Kaspersky", como se fossem dele. Agora aparecem só quando o Defender protege o PC ou está em modo passivo. O mesmo vale para "Ameaças ativas: Nenhuma", que era a lista do Defender. Se o Defender guardar alguma ameaça, ela aparece como "Ameaças no Defender". O relatório usa as mesmas linhas.

**Auditoria de segurança**
- **Corrigido: o suporte do Windows ignorava a edição.** A auditoria só apontava uma versão do Windows 11 quando todas as edições já tinham saído de suporte. Agora o calendário é o da edição:
  - Windows 11 24H2 Home e Pro: última correção em 13/10/2026 (Enterprise e Education: 12/10/2027);
  - 23H2 Home e Pro: em 11/11/2025 (Enterprise e Education: 10/11/2026).

  Com suporte, o ponto diz até quando: "Windows 11 versão 25H2: correções de segurança até 12/10/2027". Sem saber a edição, a auditoria não promete a data mais tardia.
- **As edições de longo prazo (LTSC) têm o calendário delas.** Antes, o Windows 10 LTSC 2021, que recebe correções até 12/01/2027, aparecia como sem suporte. Um Windows 10 anterior ao 22H2 aponta a atualização para o 22H2, a única versão do 10 que pode entrar no programa ESU.
- **Corrigido: uma nota A com quase nada lido.** Sem ler o antivírus, as ameaças, o firewall, o UAC e o Windows Update, a nota saía A, tirada só da conta Convidado e da entrada automática. Agora, com menos da metade da proteção verificada, a tela diz "Sem nota: só 3 de 9 pontos puderam ser verificados".
- **O que fazer fica no resumo, logo abaixo do ponto:** "O que fazer: ...". Antes era uma linha cinza, que a janela não mostra quando há faixa de resultado.
- As assinaturas em dia dizem "Atualizadas há 12 horas". Antes era "Atualizadas hoje", mesmo para as que tinham sido atualizadas às 23h do dia anterior.
- Os pontos sem leitura dizem o motivo direto ("Firewall: Não foi possível ler"), em vez de "não verificado. Não foi possível ler".
- "Nota de segurança: A (100 de 100)", sem o espaço duplo. O Secure Boot é lido como no Diagnóstico: o Registro e, sem ele, a consulta do Windows.
- A dica de abrir como Administrador só aparece quando a janela está sem Administrador. Ela também não conta mais o BitLocker e o Secure Boot como "fora da nota", porque eles nunca entram na nota.

**Atualizar assinaturas do antivírus**
- **A faixa diz o que aconteceu:** "assinaturas atualizadas para a versão 1.421.200.0" ou "as assinaturas já estavam em dia". Antes era "Concluído com sucesso".
- As orientações ("Confira a conexão com a internet e tente de novo.") e o motivo de não atualizar com outro antivírus aparecem no resumo.

**Verificação rápida, completa e de uma pasta**
- **A Verificação completa diz quanto demora antes de perguntar:** "Examina todos os arquivos; pode levar de uma hora a várias horas", e o que o Defender faz com o que encontrar. Antes, a pergunta só dizia "pode levar horas"; o resto vinha depois de responder Sim.
- O que a verificação faz aparece no resumo, como mensagens. Antes eram linhas amarelas e azuis, só nos detalhes técnicos.
- **Cada ameaça encontrada aparece no resumo com onde estava:** "Trojan:Win32/Wacatac.B!ml: C:\Users\ana\Downloads\crack.exe". Antes, os nomes e os arquivos ficavam só nos detalhes, e o arquivo vinha com o prefixo do Defender ("file:_C:\...").
- As faixas: "nenhuma ameaça encontrada", "1 ameaça encontrada" ou "nenhuma ameaça nova; 1 ameaça ativa de antes".

**O que não foi visto:** a janela não foi aberta num Windows de verdade. O desenho foi conferido numa prévia em HTML com as mesmas medidas e cores, e o script da janela foi validado contra as bibliotecas do WPF. As respostas do Windows foram simuladas:
- o Windows Defender (estado, assinaturas, verificações e ameaças);
- o firewall, a Central de Segurança e o Windows Update;
- o Registro (UAC, Área de Trabalho Remota, edição do Windows) e o BitLocker.

As telas rodaram no mesmo executor da janela. As datas de suporte do Windows são as das páginas de ciclo de vida da Microsoft, consultadas em 24/10/2026.

### Estrutura
- **`Security`:**
  - Pontos de atenção: `New-WinForgeSecurityFinding` ganhou `Short`, o nome curto que a faixa usa.
  - Estado da proteção:
    - O novo `Get-WinForgeAntivirusRows` monta as linhas do antivírus para a tela e para o relatório (`Reports`).
    - `Show-WinForgeSecurityStatus` termina com `Exit-WinForgeAction -Result`.
  - Verificações:
    - Novos `Write-WinForgeScanIntro` e `ConvertTo-WinForgeThreatResourceText`.
    - `Invoke-WinForgeDefenderScan` ganhou `-SkipIntro`.
  - Auditoria:
    - `Get-WinForgeWindows11Retired` deu lugar a `Get-WinForgeWindowsSupportEnd` (versão e edição) e `Get-WinForgeWindowsSupportCheck`.
    - `Get-WinForgeSecurityAuditFacts` lê também a edição e a versão do Windows.
    - `Get-WinForgeSecurityGrade` devolve `Verified` e `Total`, e não dá nota com menos da metade do peso verificado.
  - As datas usam `Format-WinForgeDateTime`, e as listas, `Join-WinForgeList`.
  - As linhas soltas de `Write-Host` deram lugar a `Write-WinForgeStatus`, e as linhas "Consultando..." a `Write-Progress`.
- **`Reports`:** a seção Segurança usa `Get-WinForgeAntivirusRows`.

## Build 3.24

Revisão da tela de Limpeza.
- Na janela, o que cada pergunta precisa aparece no resumo, logo acima dos botões: a prévia dos Downloads, o aviso de exclusão definitiva e o que a Limpeza rápida e a Limpeza personalizada fazem. Antes, parte disso ficava só nos detalhes técnicos, que ficam recolhidos durante a pergunta.
- A Lixeira passou a ser medida pelas próprias pastas, e o que ela libera entra no total da Limpeza rápida e da Limpeza personalizada.
- Na pasta Downloads, um arquivo que acabou de chegar (copiado ou extraído de um .zip) não é mais tratado como antigo, e um arquivo aberto em outro programa fica onde está, sem travar a limpeza.
- A página Limpeza mostra no alto o espaço livre no disco do sistema.

### Mudou para quem usa

**Página Limpeza**
- **Novo resumo no alto:** "Disco do sistema: 30 GB livres de 476 GB". Com menos de 10% livres, a linha diz "pouco espaço"; com menos de 5 GB, "espaço crítico; comece pela Limpeza rápida". A regra é a mesma do Início.

**Em todas as telas da Limpeza**
- **Corrigido: na janela, o contexto de uma pergunta ficava escondido.** Durante uma pergunta de Sim e Não ou de escolha, os detalhes técnicos ficam recolhidos, e só o resumo aparece. Estes textos saíam como linhas soltas, que o resumo não mostra:
  - a explicação da Limpeza rápida;
  - o aviso "os itens são removidos em definitivo" da Lixeira;
  - as notas dos temporários;
  - a prévia dos Downloads;
  - a nota da Limpeza personalizada sobre as pastas pessoais.

  Agora são mensagens e linhas "rótulo : valor" do resumo, acima dos botões.
- **O andamento vai na barra de progresso**, com o nome da parte ("Medindo o que pode ser liberado · Cache dos navegadores (3 de 6)"). Antes, linhas "Medindo...", "Limpando..." e "Analisando os itens..." ficavam no resumo, como se a ação continuasse depois de terminada.
- Os textos dizem "1 item" e "2 itens", em vez de "item(ns)".

**Limpeza rápida**
- **O total liberado inclui a Lixeira**, medida antes de ser esvaziada. A faixa diz "liberou 50,8 MB" em vez de "Concluído com sucesso", e a nota "o conteúdo da Lixeira não entra na conta" saiu.
- Se a Lixeira não puder ser medida, a tela diz isso: "O total não inclui a Lixeira: não foi possível medir antes de limpar."
- A explicação antes da pergunta diz também que o que está na Lixeira é removido em definitivo e que arquivos em uso ficam.
- "1 de 3 partes falhou", no singular.

**Esvaziar a Lixeira**
- **"Na Lixeira: 3 itens, 50 MB"** antes da pergunta e **"Espaço liberado: 50 MB"** depois. Antes, só a quantidade de itens, e nenhum tamanho.
- A Lixeira é medida direto nas pastas dela, em cada unidade, sem depender do Shell do Windows, que não responde em algumas sessões. A Análise de espaço e a Limpeza personalizada usam a mesma medida.
- Sem conseguir medir, a tela diz "Não foi possível medir a Lixeira; ela será esvaziada mesmo assim."
- O aviso de exclusão definitiva tem o ícone de atenção e não conta como ressalva: esvaziar com sucesso termina em "Tudo certo".

**Limpar temporários do usuário e do Windows**
- **Corrigido: a variável TEMP apontando para uma pasta pessoal não era recusada.** A trava recusava só a raiz do disco, o perfil e o Windows. Uma TEMP em Documentos, ou numa pasta dentro dela, faria a limpeza apagar os documentos. Agora a TEMP também é recusada quando é, ou fica dentro de, Documentos, Área de Trabalho, Downloads, Imagens, Músicas, Vídeos, Favoritos ou OneDrive. A Limpeza personalizada usa a mesma trava.
- A explicação de uma pasta recusada ou que não abre aparece como mensagem no resumo, e não mais como linha cinza nos detalhes.

**Limpar a pasta Downloads**
- **Corrigido: um arquivo recém-chegado podia ser tratado como antigo.** A idade era a da última alteração. Copiar um arquivo, ou extrair um .zip, mantém a data de alteração original: um arquivo copiado ontem de um pen drive podia ter data de 2019 e entrar em "mais antigo que 30 dias". Agora conta também quando o item chegou à pasta, e a pergunta diz "Remover o que foi baixado ou alterado há mais de quantos dias?".
- **Corrigido: um arquivo aberto em outro programa podia travar a limpeza.** Enviar um arquivo em uso para a Lixeira faz o Windows abrir a janela "Arquivo em uso", e a limpeza ficava parada esperando resposta. Agora um arquivo aberto (ou uma pasta com um arquivo aberto dentro) fica onde está e entra em "Itens ignorados".
- **Corrigido: um item que o Windows não tirou da pasta contava como enviado.** Agora a tela confere se o item saiu.
- Uma pasta que sai pela metade conta, no espaço liberado, só o que saiu dela.
- **A prévia entra no resumo,** acima da pergunta do destino: "setup.exe : 1,9 MB · 26/07/2026", dos maiores para os menores, e "E mais 3 itens menores." Os rótulos dizem "Itens a limpar" e "Espaço que ocupam", porque mandar para a Lixeira não libera espaço. Antes era "Espaço a liberar".
- As opções dizem o que fazem: "O que é mais antigo" (recomendado: você escolhe há quantos dias) e "Tudo" (todos os 4 itens da pasta, de qualquer data). As perguntas falam do número certo: "O que fazer com este item?" ou "com estes 2 itens?", e "Confirma a exclusão permanente de 1 item?".
- **As faixas dizem o que aconteceu:**
  - "2 itens enviados à Lixeira (2,2 MB)";
  - "1 item excluído, liberou 97,7 KB";
  - "nada com mais de 30 dias";
  - "a pasta já estava vazia".

  Antes, "Concluído com sucesso" ou a última mensagem da tela.
- **Corrigido: com o WinForge elevado com outra conta, uma limpeza que dava certo terminava "com ressalvas",** por causa do aviso de quem é a pasta. O aviso continua antes da primeira pergunta, sem mudar a faixa.

**Analisar uso de espaço**
- **Novo aviso de disco cheio**, com a regra do Início: "Pouco espaço livre no disco do sistema." ou "O disco do sistema está quase cheio...". É um aviso sobre o disco, não sobre a análise: a tela continua sem faixa de ressalva.
- A análise só informa, então termina sem faixa, com o resumo como conteúdo da tela. Antes, "nada acumulado" deixava a faixa verde.
- Pastas do perfil vazias não entram mais na lista das maiores.
- Sem nenhum arquivo grande do sistema, a seção diz "Nenhum arquivo grande do sistema foi encontrado.", em vez de ficar vazia.
- Sem conseguir ler o disco, o aviso fica dentro da seção Disco do sistema.
- As dicas dos arquivos grandes saem depois de "·" e começam em minúscula ("some se a hibernação for desativada, em Ajustes do Windows").
- Os nomes dos arquivos grandes ficaram mais curtos, para caber na coluna do resumo sem quebrar a linha: "Hibernação (hiberfil.sys)", "Arquivo de troca (swapfile.sys)" e "Windows anterior (Windows.old)".

**Limpeza personalizada**
- **Corrigido: o espaço da Lixeira não entrava no total.** Com a Lixeira marcada, o "Espaço liberado" e a faixa só somavam as pastas. Agora a Lixeira entra na conta.
- **Corrigido: uma Lixeira com itens de 0 B não aparecia na lista.** Agora a Lixeira entra pela quantidade de itens.
- **A pergunta diz quanto será liberado:** "Limpar os 3 itens marcados (cerca de 51,1 MB)?", ou "(pelo menos 4 KB)" quando algo ficou sem medir, ou "Limpar o item marcado?" sem número quando nada foi medido. Antes, a estimativa somava zero para o que não foi medido.
- **Uma linha por parte:** "Liberou 879 KB." embaixo de "Cache dos navegadores", em vez de uma linha por pasta com o caminho inteiro (o cache de cada perfil de cada navegador). O caminho aparece quando uma pasta dá erro.
- **Quando nada sai de uma parte,** a tela diz o que fazer: "feche os navegadores e tente de novo" para o cache, "feche os programas abertos" para o resto. A nota "isso é esperado" só conta os itens em uso das partes que foram limpas.
- **A faixa nomeia a parte com problema:** "liberou 4 KB; com problema: Cache dos navegadores", ou "nada foi liberado; com problema: ..." quando nada saiu. Antes era "1 parte(s) com problema".
- A Lixeira não ganha mais dois títulos seguidos ("Lixeira" e "Esvaziar a Lixeira").
- As opções da lista dizem "Cache dos navegadores · 879 KB".

**Na janela, em outras páginas**
- A explicação das ferramentas que perguntam "Deseja continuar?" também aparece no resumo: o que a ferramenta faz e quanto pode demorar. Vale para Limpar componentes do Windows (WinSxS) e, no Reparo, para Reparar imagem e componentes (DISM), Verificar arquivos do sistema (SFC), Otimizar a unidade do sistema e Detectar dispositivos e drivers. Antes eram linhas amarelas e azuis, só nos detalhes.

**O que não foi visto:** a janela não foi aberta num Windows de verdade. O desenho da página e das telas foi conferido numa prévia em HTML com as mesmas medidas e cores, e o script da janela foi validado contra as bibliotecas do WPF. As respostas do Windows foram simuladas:
- a Lixeira (as pastas `$Recycle.Bin` de cada unidade e o esvaziamento);
- a janela "Arquivo em uso" do Windows, que a tela agora evita;
- o envio para a Lixeira e o acesso negado;
- a data de criação dos arquivos, que fora do Windows acompanha a de alteração.

As telas rodaram no mesmo executor da janela, com pastas e arquivos de verdade. A detecção de arquivo aberto foi conferida com arquivos abertos de verdade.

### Estrutura
- **`Cleanup`:**
  - **Lixeira:**
    - Novos `Get-WinForgeRecycleBinFolders`, `Get-WinForgeRecycleBinContents` e `Format-WinForgeRecycleBinText`.
    - Saíram `Get-WinForgeRecycleBinItemCount` e `Get-WinForgeRecycleBinSize`, que usavam o Shell.
    - `Clear-WinForgeRecycleBin` recebe `-Contents` (o que já foi medido) no lugar de `-SkipCount` e devolve `FreedBytes`.
  - **Temporários:**
    - Novos `Get-WinForgePersonalFolders` e `Test-WinForgeTempFolderSafe`, usados por `Invoke-WinForgeFolderCleanup` e pela Limpeza personalizada.
    - Os resultados de pasta não encontrada e de nada a limpar levam `FreedBytes = 0`.
  - **Downloads:**
    - `Clear-WinForgeDownloads` tem uma saída só, com `Exit-WinForgeAction -Result`.
    - A remoção foi para o novo `Invoke-WinForgeDownloadsRemoval`, com `Test-WinForgeItemInUse` antes de enviar à Lixeira e a conferência de que o item saiu.
    - Novo `Get-WinForgeFreedFromPartial`, usado também por `Clear-WinForgeFolderContents`.
    - `Show-WinForgeDownloadsPreview` escreve `Write-WinForgeKeyValue`.
    - `Measure-WinForgeFolderItems` usa a data mais recente entre alteração e criação.
  - **Limpeza rápida:** as partes têm nome para a frase do total.
  - **Análise e Limpeza personalizada:**
    - Novos `Measure-WinForgeCleanupTargets` (com a barra de progresso) e `Test-WinForgeCleanupTargetAvailable`.
    - `New-WinForgeCleanupTarget` ganhou `BinContents`.
    - A limpeza dos alvos foi para o novo `Invoke-WinForgeCleanupTargets`.
    - `Invoke-WinForgeCustomCleanup` tem uma saída só.
    - `Get-WinForgeUserFolderSizes` mostra o andamento.
  - **Página:** novo `Get-WinForgeCleanupPageStatus`.
- **`Console`:** `Write-WinForgeStatus -Notice` escreve o aviso sem contar no desfecho da ação.
- **`Repair`:** `Invoke-WinForgeTool` escreve a descrição e os avisos com `Write-WinForgeStatus -Type Info`.
- **`WinForge.Gui.ps1`:** `New-GuiPageStatus` escolhe a função de resumo pela página e atende também a Limpeza.

## Build 3.23

Revisão da tela de Diagnóstico.
- Na janela, as listas que as telas encontram aparecem no resumo: dispositivos com defeito, grupos de eventos e unidades de disco. Antes ficavam só nos detalhes técnicos.
- Corrigidas leituras erradas ou diferentes das outras telas: Secure Boot, frequência do processador, unidade da memória, nome e versão do Windows, carga da bateria e estado dos discos.
- Datas e decimais saem iguais em qualquer idioma do Windows.
- Cada tela termina com uma faixa que diz o que encontrou.
- Uma consulta cujo resumo diz tudo, como Sobre este PC, mostra o resumo como o conteúdo da tela.

### Mudou para quem usa

**Em todas as telas do Diagnóstico**
- **Corrigido: na janela, as listas ficavam escondidas.** Os dispositivos com problema, os grupos de eventos e as unidades de disco saíam em tabelas ou em linhas soltas, que só os detalhes técnicos mostram. Com a faixa amarela, os detalhes ficam recolhidos, e "veja a lista abaixo" ou "em amarelo, com a explicação" apontavam para o que não estava na tela. Agora cada item é uma linha do resumo.
- **As faixas de resultado dizem o que a tela encontrou:**
  - "nenhum alerta nos 2 discos" ou "1 disco com alerta: WDC WD20EZRZ";
  - "2 dispositivos com problema ativo";
  - "bateria em bom estado (95% da carga de quando era nova)";
  - "nenhum evento crítico ou de erro nos últimos 7 dias";
  - "nenhum reinício pendente";
  - "pouco espaço em C: e D:".

  Antes apareciam "Concluído com sucesso" ou a última mensagem de aviso; com duas unidades cheias, só a última era citada.
- Datas ("23/10/2026 08:31", "23/10 05:37") e números ("4,5 GHz", "12.345 horas") saem iguais em qualquer idioma do Windows. Antes, um Windows em alemão mostrava "23.10.2026", e a frequência saía "4.5 GHz" em todos.

**Sobre este PC**
- **O Windows aparece com o nome e a versão da tela inicial:** "Windows 11 Pro", versão "24H2" e a build.
  - Antes: "Microsoft Windows 11 Pro" e versão "10.0.26100", a do núcleo, que não diz qual Windows é.
  - Num PC atualizado do 10 para o 11 cujo WMI ainda diz "Windows 10", vale a build, como no Início.
- **Corrigido: Secure Boot "Indisponível / não suportado" sem Administrador.** A tela não pede Administrador, e a consulta do Windows recusa sem ele; um PC com o Secure Boot ligado aparecia como sem suporte. Agora o estado vem do Registro, que não exige Administrador. Quando o Registro não responde, a tela diz "Não verificado (requer Administrador)" ou, num BIOS legado, "Não suportado (BIOS legado, sem UEFI)".
- **Processador:** "Núcleos: 8 núcleos, 16 processadores lógicos" e "Frequência base: 4,5 GHz".
  - Saíram "Clock atual" e "Clock máximo". O Windows informa como máximo a frequência base, sem o turbo, e o "atual" costuma repetir esse número.
- **Memória:**
  - "Módulos: 2 × 16 GB" (ou "8 GB + 16 GB"), em vez de só a quantidade.
  - A velocidade sai em MT/s, a unidade do nome do módulo (DDR5-6000), que o Gerenciador de Tarefas do Windows 11 também passou a usar. Antes dizia MHz.
  - O indicativo de XMP/EXPO também conta como ativado a memória que roda acima do que o próprio módulo anuncia.
  - A nota "XMP/EXPO é deduzido da velocidade em uso" fica logo abaixo do valor, e não no fim da tela, depois dos discos.
- O tempo ligado diz "1 dia, 5 horas e 7 minutos" (antes, "1 dia, 5 horas, 7 minutos"), também em Inicialização e energia e no relatório.

**Discos e espaço livre** (e a seção Discos de Sobre este PC)
- **Uma linha por unidade:** "C: : 477 GB livres de 931 GB (49% usado) · NVMe · Samsung SSD 980". Tipo e modelo que o Windows não informou ficam de fora, em vez de "Não disponível".
- **As palavras da tela inicial:** "está com pouco espaço" (menos de 10% livres) e "está quase cheia" (menos de 5 GB). Antes, as duas situações diziam "quase cheia", inclusive numa unidade de 2 TB com 140 GB livres.
- **A dica depende da unidade:**
  - no disco do Windows, a página Limpeza;
  - numa unidade de dados, a tela diz que a Limpeza libera pouco ali e sugere mover ou apagar arquivos grandes.
- **Corrigido:** sem o espaço livre informado, a unidade aparecia com "0 B livres" e 100% de uso. Agora diz que o espaço livre é desconhecido.
- **Corrigido:** uma unidade que o Windows devolvesse sem letra derrubava a lista inteira ("Não foi possível detectar informações de disco"). Agora ela é pulada.

**Saúde dos discos**
- **Estado em português:** Saudável, Atenção, Com defeito ou Desconhecido. Antes saía "Healthy" ou "Warning".
  - **Corrigido:** um estado informado como número (0 = saudável) virava alerta. Agora é entendido.
  - Um estado desconhecido não vira mais alerta amarelo.
- A temperatura 0 °C, que muitos discos informam quando não têm sensor, aparece como "Não disponível".
- **Num HD:**
  - o desgaste diz "Não se aplica (HDD)" e não gera alerta;
  - a temperatura alta começa em 55 °C (num SSD, continua em 70 °C).
- "Horas ligado: 12.345 horas" e "Erros não corrigidos: 0 de leitura, 0 de escrita".
- **Depois de um alerta, a tela diz o que fazer:**
  - backup, para estado ruim, erros ou desgaste;
  - conferir a ventilação, para temperatura alta.
- No terminal sem Administrador, a tela diz que os contadores exigem Administrador. Um disco sem estado nem contadores diz que não há como avaliá-lo por aqui, em vez de "só o estado geral foi avaliado".

**Dispositivos com problema**
- **Cada dispositivo numa linha, com o problema em português e o código do Gerenciador de Dispositivos:** "Realtek PCIe GbE Family Controller (Rede): o driver não está instalado (código 28)."
  - Antes: uma tabela com "Error", "Net" e "CM_PROB_FAILED_INSTALL".
  - O identificador do Windows continua nos detalhes técnicos, para pesquisar.
- Um dispositivo desativado é reconhecido também pelo número que o Windows informa (22), e não só pelo nome do problema.
- A tela indica o Gerenciador de Dispositivos para reinstalar ou atualizar o driver.

**Eventos críticos**
- **Cada grupo numa linha:**
  - o de causa conhecida vira um aviso com a explicação, a contagem e a origem: "Reinício inesperado: queda de energia, travamento ou superaquecimento. 3 vezes, a última em 23/10 13:38 (Kernel-Power, ID 41).";
  - os outros, uma linha "origem (ID): quantas vezes".
- "10 eventos de erro ou críticos nos últimos 7 dias, em 3 grupos", em vez de "10 evento(s) de erro/crítico". O fim da lista diz "Mais 3 grupos menos relevantes", em vez de "... e mais 3 grupo(s)".

**Saúde da bateria**
- **Corrigido: carga "255%".** Alguns drivers informam 255 quando não sabem a carga, e a tela e o relatório mostravam o número. Agora aparece "Não disponível", com a mesma regra do cartão do Início.
- "Capacidade de fábrica" e "Capacidade hoje", no lugar de "De fábrica" e "Hoje, carga completa".

**Inicialização e energia**
- A hibernação aparece como um dado ("Hibernação: Ativada"), antes da lista de modos de energia do Windows.
- Se a lista não puder ser lida: "Não foi possível listar os modos de energia (powercfg finalizou com código 1)".

**Reinício pendente**
- Cada motivo explica o que espera o reinício:
  - "Windows Update: uma atualização instalada espera o reinício";
  - "Renomeação do computador: o nome PC-NOVO vale depois do reinício".

**Exportar relatório**
- **O relatório usa as frases das telas:**
  - o Windows como no Início ("Windows 11 Pro 24H2 (build 26100)");
  - a memória com os módulos;
  - cada unidade com a linha de Discos e espaço livre;
  - a saúde dos discos em português;
  - os eventos com "N vezes, a última em".
- As datas do relatório também saem iguais em qualquer idioma.
- A faixa diz "relatório salvo em HTML e em texto". Se o relatório não puder ser aberto, a tela termina com ressalvas e o motivo.

**Na janela, em todas as páginas**
- **Uma tela que só informa e cujo resumo diz tudo mostra o resumo como o conteúdo.** Isso vale quando a tela escreveu só mensagens do WinForge, linhas "rótulo : valor" e seções.
  - O resumo ocupa toda a altura até o cartão dos detalhes técnicos, e os detalhes ficam recolhidos.
  - Antes, essas telas escondiam o resumo e abriam os detalhes técnicos, em fonte de terminal.
  - Quando há algo que o resumo não mostra (uma tabela, o texto de um programa), os detalhes continuam se abrindo. É o caso de Informações de rede e de Inicialização e energia.

**O que não foi visto:** a janela não foi aberta num Windows de verdade. O desenho foi conferido numa prévia em HTML com as mesmas medidas e cores, e o script da janela foi validado contra as bibliotecas do WPF. A altura do resumo é calculada a partir do layout do WPF, que só a janela real faz. As respostas do Windows também foram simuladas:
- WMI;
- dispositivos;
- discos e seus contadores;
- Secure Boot;
- log de eventos;
- powercfg.

### Estrutura
- **`Core`:** novos `Format-WinForgeNumber`, `Join-WinForgeList`, `Get-WinForgeWindowsName` e `Get-WinForgeWindowsDisplayVersion`. Os dois últimos são usados também por `Get-WinForgeSessionInfo`.
- **`Diagnostics`:**
  - `Get-WinForgeDiskSummary` deixa só a consulta no `try` e ganhou `UsoPercent`. O novo `Get-WinForgeDiskSummaryText` monta a linha da tela e do relatório.
  - `Show-WinForgeDiskSummary` escreve `Write-WinForgeKeyValue` e ganhou `-PassThru`.
  - Novas funções:
    - `Get-WinForgeSecureBootText` e `Get-WinForgeMemoryModulesText`;
    - `Get-WinForgeDeviceProblemCode`, `Get-WinForgeDeviceProblemText` e `Get-WinForgeDeviceName`;
    - `Get-WinForgeHibernationText`, usado também por `Get-WinForgeFastStartupText`;
    - `Get-WinForgeDiskHealthStatusText` e `ConvertTo-WinForgeBatteryPercent`;
    - `Get-WinForgeEventProviderText` e `Format-WinForgeEventOccurrences`.
  - As tabelas (`Format-Table | Out-Host`) e as linhas soltas de `Write-Host` deram lugar a `Write-WinForgeStatus` e `Write-WinForgeKeyValue`.
  - As telas com veredito terminam com `Exit-WinForgeAction -Result`, e `Show-WinForgeBatteryHealth` tem uma saída só.
- **`Hardware`:** `Get-WinForgeExpoXmpStatus` escreve MT/s e reconhece a memória acima do que o módulo anuncia.
- **`Reports`:** as seções usam os textos das telas e `Format-WinForgeDateTime`; `Invoke-WinForgeReport` termina com `-Result`.
- **`Navigation`:** `Read-WinForgeHomeBattery` usa `ConvertTo-WinForgeBatteryPercent`, e a descrição de Sobre este PC cita o Windows e o Secure Boot.
- **`GuiDesign`:** novo `Get-WinForgeSummaryMaxHeight`.
- **`WinForge.Gui.ps1` e `MainWindow.xaml`:**
  - `Add-GuiActivityFromLine` conta as linhas que o resumo não mostra.
  - Novos `Test-GuiSummaryIsContent` e `Update-GuiSummaryHeight`.
  - `Complete-GuiRun` e `Set-GuiResultView` usam o resumo como conteúdo da tela quando ele diz tudo.
  - A linha que separa o resumo da faixa ganhou nome (`ActivitySeparator`) e some quando não há faixa.
  - A altura do resumo acompanha o tamanho da tela de execução.

## Build 3.22

Revisão da tela de Manutenção.
- Na janela nova, as orientações de cada fase e a situação da Manutenção agendada ficavam escondidas nos detalhes técnicos enquanto a pergunta esperava; agora aparecem no resumo.
- A manutenção mostra em que etapa está.
- Opções da manutenção, Manutenção agendada e um ponto de restauração que não foi criado terminam com um resultado que diz o que aconteceu.
- Escolher um perfil só para olhar o plano não muda mais o perfil padrão.
- O ponto de restauração recebe um nome que diz de onde veio.
- O histórico ganhou linhas legíveis, e frases como "etapa(s)" passaram para o plural certo.

### Mudou para quem usa

**Manutenção recomendada**
- **Corrigido: na janela, as orientações ficavam escondidas durante as perguntas.** Elas apareciam só nos detalhes técnicos, recolhidos enquanto a pergunta espera:
  - as fases do preparo;
  - o que o perfil decide;
  - como usar o plano;
  - o que fazer em cada janela da revisão manual ("Desative apenas o que você reconhece...");
  - o aviso da fase automática;
  - por que reiniciar.

  Agora todas aparecem no resumo, acima da pergunta.
- **A etapa em andamento aparece no alto, com a posição no fluxo:** "Etapa 4 de 9: Reparar o Windows (DISM + SFC)". Ela também vira um subtítulo no resumo. No terminal, a barra de texto com o percentual continua igual.
- **O resumo final mostra cada etapa numa linha:** "Limpeza rápida · 1min 05s", "Reparar o Windows · Atenção (…) · 12min 40s", com o ícone do desfecho. As etapas ignoradas também aparecem, com o ícone de "ignorado". O antes e depois mostra cada dado com o rótulo ao lado.
- **Corrigido: escolher um perfil mudava o perfil padrão mesmo sem a manutenção começar.** Olhar o plano da Profunda e cancelar deixava a Profunda como padrão. Agora o perfil só vira o padrão quando a fase automática é confirmada, ou quando a manutenção só tem revisão manual.
- **Corrigido: uma janela da revisão manual que não abria ainda pedia "conclua na janela aberta".** Agora a tela diz "A janela não abriu; esta revisão fica para depois".
- O ponto de restauração criado pela manutenção agora se chama "WinForge - antes da manutenção recomendada" na Restauração do Sistema. Antes se chamava "antes dos ajustes".
- "Manutenção recomendada finalizada." passou a ser uma informação, e não um "ok" verde ao lado de etapas que falharam. O desfecho continua sendo o das etapas.
- **Frases corrigidas:**
  - "1 etapa falhou e 1 etapa terminou com ressalvas. As mensagens de cada etapa e o log dizem o motivo." Antes: "1 etapa(s) falharam e 0 terminaram com ressalvas. Revise a saída acima".
  - "Duração da fase automática", em vez de "Tempo total", porque a conta não inclui a revisão manual.
  - "A fase automática executa 1 etapa" ou "7 etapas", em vez de "etapa(s)".
  - No resultado, "1 etapa terminou com ressalvas" (antes, "1 terminou com ressalvas").
- No terminal, digitar " winforge " com espaços ou terminar a entrada (Ctrl+Z) conta como "não começar", sem erro.
- Na janela, o "Cancelar" da fase automática passou a ser a saída da pergunta, como nas outras.

**Opções da manutenção**
- **Termina com um resultado que diz o que mudou:**
  - "Perfil padrão: Rápida";
  - "salvo; o DISM completo rodará em toda manutenção que incluir o reparo";
  - em vermelho, se não foi possível salvar;
  - em cinza ("Cancelado"), ao voltar sem escolher.

  Antes terminava "Concluído com sucesso" sem dizer o quê.
- A situação atual (perfil padrão e DISM completo) aparece no resumo, e não só nos detalhes.

**Manutenção agendada**
- **Corrigido: na janela, a situação da tarefa ficava escondida enquanto a tela perguntava o que fazer.** Ela ficava só nos detalhes recolhidos: se está agendada, a próxima execução e a última execução. O que a tarefa faz e o que não faz também. Agora tudo aparece no resumo, acima das opções.
- Cada opção tem uma explicação curta. O dia atual diz que escolher de novo recria a tarefa, e "Remover o agendamento" diz que nada mais roda sozinho.
- **Termina com um resultado que diz o que ficou valendo:**
  - "agendada para todo dia 15, às 12h";
  - "agendamento removido; nada mais roda sozinho";
  - em vermelho, com o motivo, se o Agendador recusar;
  - em cinza, ao voltar sem escolher.
- A tela agora diz o que a tarefa sempre fez: num notebook, ela só começa na tomada.
- As datas saem sempre como "15/11/2026 12:00", em qualquer idioma do Windows.
- **Corrigido:** se a limpeza devolvesse algum texto junto com o resultado, uma execução em que nada funcionou podia ser registrada como "com ressalvas". Nesse caso a tarefa terminava sem o código de erro que o Agendador mostra.

**Criar ponto de restauração** (páginas Manutenção e Ajustes)
- **O ponto se chama "WinForge - ponto criado manualmente"** na Restauração do Sistema. O de antes de aplicar ajustes continua "WinForge - antes dos ajustes".
- **Corrigido: pedido sozinho, um ponto que não foi criado terminava "Concluído com ressalvas: não criado".** Isso acontecia, por exemplo, com a Proteção do Sistema desligada e a pessoa recusando ligá-la. Agora termina em vermelho: "Não foi concluído: o ponto de restauração não foi criado". Dentro da Manutenção recomendada, o mesmo caso continua sendo uma ressalva e o fluxo segue.
- **Corrigido: sem o comando do ponto de restauração** (PowerShell 7), o ponto não era criado, mas os ajustes seguiam sem perguntar se a pessoa queria aplicar mesmo sem ele. Agora a pergunta aparece, como quando a Proteção do Sistema está desligada. Ligar a Proteção do Sistema não é oferecido nesse caso, porque não resolveria.

**Histórico de manutenções**
- **Cada manutenção aparece numa linha legível,** como "04/03/2026 09:05 : Completa · 12min 05s · 8 ok, 1 com ressalva, 2 falharam, 1 ignorada · espaço: +1,2 GB". Antes era uma tabela com "OK 8 | ressalvas 1" e "-" no lugar do que faltava. As etapas ignoradas, que antes não apareciam, passam a contar.
- Na janela, as tendências e as linhas aparecem no resumo. Antes, com uma etapa repetindo problema, o resultado ficava amarelo e o histórico em si ficava escondido nos detalhes.
- "Espaço livre ao fim de cada uma" passou a "Espaço livre, da primeira à última", que é o que a linha compara. O texto também diz "em 2 manutenções com medição" (antes, "manutenção(ões)").
- Uma entrada antiga sem duração registrada não vira mais "a última levou 0s".

**Em todas as telas da janela**
- **O resumo da execução mostra também os dados que as ações escrevem como "rótulo : valor"**: o rótulo apagado à esquerda e o valor ao lado. Exemplos: "Espaço liberado: 1,4 GB", "Próxima execução", a duração de uma etapa. Antes, esses dados só apareciam nos detalhes técnicos. Nas telas que só informam, sem resultado, os detalhes técnicos continuam se abrindo sozinhos no lugar do resumo.
- **As tabelas de resultados de etapas viram linhas do resumo** ("etapa · desfecho · duração"), também no Reparo. Antes viravam linhas cheias de espaços, e as etapas ignoradas não apareciam. No terminal, as tabelas continuam alinhadas em colunas.
- Na tela de execução, o título que uma etapa escreve logo depois da marca "Etapa N de M" não aparece repetido.

**O que não foi visto:** a janela não foi aberta num Windows de verdade. O desenho foi conferido numa prévia em HTML com as mesmas medidas e cores, e o script da janela foi validado contra as bibliotecas do WPF. A criação do ponto de restauração e o Agendador de Tarefas foram simulados.

### Estrutura

- **`Maintenance`:**
  - Novo `Save-WinForgeMaintenanceProfileChoice`; `Read-WinForgeMaintenanceProfile` não grava mais a escolha.
  - `Set-WinForgeMaintenanceOptions` termina com `-Result`.
  - `Invoke-WinForgeManualStep` olha o retorno de `Open-WinForgeShortcut`.
  - As orientações das fases viraram `Write-WinForgeStatus -Type Info` (o aviso da fase automática, `Warning`).
  - `Invoke-WinForgeMaintenanceStep` escreve `Write-WinForgeSubStep "Etapa N de M: …"` na janela e a barra de texto no terminal.
  - `Format-WinForgeHistoryLine` monta a linha nova, e o histórico é escrito com `Write-WinForgeKeyValue`.
  - `Format-WinForgeHistoryDate` deu lugar a `Format-WinForgeDateTime` (`Core`).
  - A frase de `Get-WinForgeMaintenanceResult` foi corrigida ("1 etapa terminou com ressalvas").
- **`Schedule`:**
  - `Show-WinForgeScheduledMaintenance` termina com `-Result` (o de `Register`/`Unregister`, ou `Skipped`).
  - As opções da tela têm `Description`.
  - Os resultados das limpezas são filtrados por `WinForge.Result`.
  - As datas usam `Format-WinForgeDateTime`.
- **`Tweaks`:** `Invoke-WinForgeRestorePoint` e `Request-WinForgeRestorePoint` recebem `-Description`. O ponto não criado vira `Failed` quando a ação é pedida sozinha. A falta do `Checkpoint-Computer` marca `NotCreated` e `Unavailable`.
- **`Console`:** `Write-WinForgeResultTable` escreve linhas compactas dentro da janela.
- **`Core`:** novo `Format-WinForgeDateTime`.
- **`GuiDesign`:** `Get-WinForgeActivityEntry` reconhece `[-]` (`Skip`), e o novo `Get-WinForgeFactEntry` reconhece as linhas de `Write-WinForgeKeyValue` pelas cores dos pedaços.
- **`WinForge.Gui.ps1`:**
  - `Add-GuiActivityFromLine` recebe as cores de todos os pedaços da linha.
  - `New-GuiActivityRow` desenha `Fact` e `Skip`.
  - `Add-GuiActivity` não repete o título de seção logo depois da marca da etapa.

## Build 3.21

Revisão da tela de Início. A nota de saúde agora diz quando parte do PC não pôde ser lida, em vez de mostrar uma nota cheia. Ela também não some mais quando falha, e uma manutenção antiga e com problemas não desconta menos que uma antiga sem problemas. Os cartões de Seu PC ganharam duas linhas de mesma altura, e os tamanhos saem com vírgula decimal em todas as telas. Os atalhos de Por onde começar não repetem mais o que a página já oferece. Uma leitura que cruza o fim de uma ação não fica guardada, e trocar o tema não lê o PC de novo.

### Mudou para quem usa

**Nota de saúde**
- **Corrigido: uma parte sem leitura sumia da nota sem aviso.** Se uma leitura que entra na nota não respondia (disco, reinício, manutenção ou proteção), a nota ignorava essa parte. Podia aparecer "100 · Seu PC está em ótima forma" com o cartão Proteção dizendo "Não foi possível ler".
  - Agora a nota vale para o resto, e a frase fica "Seu PC parece bem".
  - O resumo diz o que ficou de fora ("Não foi possível ler: Proteção.").
  - O mesmo vale para a proteção lida pela metade ("Leitura incompleta").
- **Corrigido: nenhuma leitura respondia e a nota era 100.** Agora a tela diz "Não foi possível avaliar o PC", sem número, com o Atualizar à mão.
- **Corrigido: se a nota falhasse ao ser montada, o cartão sumia.** Ele levava junto a hora da leitura e o botão Atualizar, e não havia como tentar de novo. Agora o cartão diz "Não foi possível calcular a nota" e mantém os dois.
- **Corrigido: uma manutenção antiga e com problemas descontava menos que uma antiga sem problemas.** Uma manutenção com mais de um mês que terminou com etapas pedindo atenção descontava 6 pontos; uma antiga que correu bem descontava 8.
  - Agora as duas situações juntas são um ponto só, de 8, que diz as duas coisas.
  - O resumo da página Manutenção também mostra as duas.
- **Corrigido: pontos com o mesmo peso não tinham ordem garantida** (por exemplo, reinício pendente e manutenção atrasada). O PowerShell não garante a ordem dos empates ao ordenar, então eles podiam trocar de lugar entre uma leitura e outra. Agora ficam na ordem em que foram lidos.
- **Plural certo nas frases:**
  - "1 ameaça ativa", "3 ameaças ativas";
  - "1 ponto de atenção", "2 pontos de atenção";
  - "2 etapas pedindo atenção".
  - Antes apareciam "ameaça(s)" e "ponto(s)".
- O botão do ponto de assinaturas antigas passou de "Atualizar" para "Atualizar assinaturas". Não se confunde mais com o Atualizar da nota, no mesmo cartão.
- **Corrigido: com a janela estreita, a frase e o botão Manutenção recomendada ficavam espremidos** numa coluna ao lado da hora da leitura. Agora a hora e o Atualizar ficam na primeira linha do cartão, ao lado de "SAÚDE DO PC", e a frase usa a largura toda.
  - "Calculando a nota de saúde..." ficou "Verificando o seu PC...".
  - A hora da leitura em andamento ficou mais curta: "Lendo o PC (3 de 7)...".

**Cartões de Seu PC**
- **Cada cartão mostra o valor em destaque e um complemento embaixo, uma linha cada.** Exemplos: "40,2 GB livres" sobre "de 476 GB · pouco espaço"; "há 2 dias" sobre "21/10/2026 21:40".
  - Antes, textos longos quebravam em duas ou três linhas e os cartões de uma mesma fileira ficavam com alturas diferentes.
  - Agora todos têm a mesma altura. O que não cabe termina em "...", e a frase inteira aparece ao passar o mouse. O leitor de tela continua lendo a frase inteira.
- **Windows:** o cartão mostra o nome completo e a versão ("Windows 11 Pro", "versão 24H2 · build 26100"), e não mais só "Windows 11 (build …)". Sem a build, o cartão não mostra mais "build 0".
- **Usuário:** o nome aparece sem o nome do computador na frente ("ana" em vez de "PC-DA-ANA\ana"). Contas de domínio continuam inteiras. O aviso de conta diferente usa o mesmo nome.
- **Corrigido (todas as telas): tamanhos saíam com ponto decimal**, como "8.23 GB livres de 475.83 GB", o que em português se lê como milhar. Agora saem com vírgula e três algarismos, como no Explorador: "8,23 GB", "47,6 GB", "476 GB". Vale em qualquer idioma do Windows.
- As datas e horas do Início saem sempre como "21/10/2026 21:40", em qualquer idioma do Windows.
- **Proteção:** o cartão diz qual antivírus protege, por exemplo "Windows Defender", o nome do outro antivírus ou "Defender sem tempo real".
- **Bateria:**
  - O cartão só aparece em notebooks e agora vem por último. Num desktop, ele não aparece mais em "Lendo..." para depois sumir.
  - Com 15% de carga ou menos, longe da tomada, fica em amarelo (a nota não muda).
  - Uma carga impossível que alguns drivers informam (255%, por exemplo) vira "Carga desconhecida".
- **Manutenção agendada:** o cartão mostra a próxima data ("próxima em 15/11"). Quando não está configurada, explica "opcional, uma vez por mês".
- **Última manutenção:** o cartão abre o Histórico de manutenções, e não mais a Manutenção recomendada. Nenhum cartão começa uma ação que muda o PC; para isso há o botão da nota e o "Fazer agora" do ponto de atenção.
- O aviso de conta diferente aparece logo na primeira etapa da leitura. Antes, ele empurrava a página quando tudo já estava na tela.

**Por onde começar**
- Os atalhos agora são Limpeza rápida, Instalar atualizações do Windows, Verificação rápida e Atualizar programas.
  - A Manutenção recomendada saiu porque já é o botão principal da nota.
  - Sobre este PC saiu porque já abre pelos cartões Windows e Computador.
- Nenhum atalho leva mais a etiqueta "Recomendado" no Início. Antes três dos quatro levavam, porque cada um é o recomendado da sua página.

**Atualizar e troca de tema**
- **Corrigido: uma leitura em andamento quando uma ação terminava ficava guardada por 30 segundos**, com dados de antes da ação. Agora ela aparece, mas não é guardada, e a próxima visita ao Início lê de novo.
- **Trocar o tema com o Início aberto não lê mais o PC de novo nem volta ao topo da página.** A tela é refeita com o que já estava nela, e uma leitura em andamento continua de onde estava. Nas outras páginas, a rolagem também fica no lugar.

**Verificação rápida (`-Action Check`)**
- **Corrigido: sem nenhuma leitura da nota, o resultado era "Tudo em dia" (código 0).** Agora é "não foi possível avaliar" (código 3), com o motivo em `Error`, a não ser que a auditoria tenha achado algo grave.
- O JSON traz `Health.Unread`, com o que não pôde ser lido. Quando falta alguma parte, o texto diz "Nenhum ponto de atenção no que foi lido".

**O que não foi visto:** a janela não foi aberta num Windows de verdade. O desenho foi conferido numa prévia em HTML com as mesmas medidas e cores, e o script da janela foi validado contra as bibliotecas do WPF.

### Estrutura

- **`Core`:**
  - `Format-WinForgeBytes` usa vírgula decimal e três algarismos significativos (`Get-WinForgeNumberFormat`).
  - Novo `Format-WinForgeCount`, para singular e plural.
  - `Get-WinForgeSessionInfo` traz `WindowsName` (do `Win32_OperatingSystem`) e `WindowsVersion` (`DisplayVersion` do Registro).
- **`Navigation`:**
  - Os fatos do Início têm `Value` e `Detail`, e os pontos de atenção têm `Severe`.
  - `Get-WinForgeHealthScore -Unread` mantém a ordem dos empates e devolve `Unread`.
  - Cada etapa devolve `Unread`.
  - Novas funções: `Get-WinForgeHealthSummary`, `Test-WinForgeHealthKnown`, `Get-WinForgeUserDisplayName`, `Get-WinForgeHomeAntivirusText`, `Get-WinForgeHomeScoredFacts` e `Get-WinForgeHomeOptionalFacts`.
  - A bateria passou a ser o último cartão e a última etapa.
  - O cartão de manutenção leva a `maintenance.history`, e os atalhos do Início mudaram.
- **`GuiDesign`:** `Get-WinForgeHealthHeadline` considera a leitura parcial.
- **`Reports`:** a verificação rápida inclui `Health.Unread`, uma nota quando falta alguma parte e `Unknown` quando nada da nota foi lido.
- **`Maintenance`:** `Get-WinForgeMaintenancePageStatus` mostra a atenção e o atraso juntos.
- **`WinForge.Gui.ps1`:**
  - `New-GuiFactCard` faz cartões de duas linhas com altura fixa; `Set-GuiHomeFact` preenche o complemento e o balão.
  - `Update-GuiHealthCard` ganhou `-Failed` e o estado "sem avaliação"; a hora e o Atualizar foram para a primeira linha.
  - Novas funções `Add-GuiHomeNotices` e `Get-GuiHomeReadingText`, e o contador `$script:HomeCacheVersion`.
  - `Show-GuiHomePage -Rerender` e `Show-GuiPage -Rerender` refazem a página no lugar.
  - `New-GuiActionCard -Highlight` permite tirar o destaque dos atalhos.

## Build 3.20

Interface nova. A janela ganhou um visual mais limpo e atual, em temas claro e escuro. As páginas, os cartões e a barra lateral têm ícones. O Início mostra a nota de saúde num anel. A tela de execução mostra a etapa em andamento e um resumo do que foi feito, com o texto técnico recolhido. As perguntas usam botões e listas mais claras. O funcionamento das ações não mudou.

### Mudou para quem usa

**Aparência**
- **Tema claro e tema escuro.** Por padrão, a janela segue o tema das Configurações do Windows, inclusive se você trocar com ela aberta. Para fixar um tema: **Sobre o WinForge > Aparência** (**Automático**, **Claro** ou **Escuro**). A troca vale na hora e fica salva. A barra de título também segue o tema.
- **Visual novo:**
  - Fundo neutro, cartões brancos (ou grafite, no escuro) com cantos arredondados.
  - Uma cor de destaque azul.
  - Botões em pílula: o principal da tela em azul, os demais discretos, Parar em vermelho.
  - Barras de rolagem finas e chaves liga/desliga redesenhadas.
  - A janela abre um pouco maior na primeira vez (1180 × 760). Se ela já guardou um tamanho, continua abrindo nele.
- **Leitura e acessibilidade:**
  - As cores de texto têm contraste de pelo menos 4,5:1 (nível AA da WCAG) nos dois temas, inclusive as cores da saída técnica.
  - Os botões com ícone dizem o nome ao leitor de tela.

**Barra lateral e busca**
- Cada página tem um ícone. A página aberta fica marcada, com o ícone em azul.
- A busca mostra "Buscar" e o atalho **Ctrl K**.
- O rodapé diz se a janela está como **Administrador** ou como usuário padrão. Como usuário padrão, lembra que o WinForge pede o Administrador quando uma ação precisar.

**Cartões das páginas**
- Cada ação é um cartão com ícone, nome e uma frase do que faz.
- A ação recomendada da página vem marcada com "Recomendado".
- Antes do clique, o cartão avisa quando abre uma janela do Windows ("Abre no Windows") ou quando pede Administrador.
- O título da página ficou maior. O resumo do alto das páginas (Manutenção, Sobre e outras) segue o visual novo dos cartões.

**Início**
- **A nota de saúde aparece num anel de 0 a 100,** com uma frase do estado:
  - "Seu PC está em ótima forma"
  - "Seu PC está bem"
  - "Seu PC pede atenção"
  - "Seu PC precisa de cuidados"
- O botão **Manutenção recomendada** fica ao lado da nota.
- Logo abaixo vem cada ponto que desconta a nota, com o botão que o resolve.
- **A página tem duas seções:**
  - **Seu PC:** os cartões do estado, com ícone e uma seta nos que abrem uma tela.
  - **Por onde começar:** as ações mais usadas.
- A hora da leitura e o botão **Atualizar** ficam no canto do cartão da nota.

**Ajustes do Windows**
- Os ajustes ficam agrupados por tema, em cartões com uma linha por ajuste e a chave à direita. Os avançados continuam recolhidos.

**Tela de execução**
- **A etapa em andamento fica em destaque,** com uma barra de progresso fina. Com percentual (DISM, SFC, winget...), a barra enche; sem percentual, ela corre.
- **Um resumo do que já foi feito:** uma linha por mensagem do WinForge, com ícone de ok, atenção, erro ou informação. Os títulos de seção viram subtítulos.
- **A saída completa fica em "Detalhes técnicos", recolhida.** Ela se abre sozinha em três casos:
  - quando a ação termina com erro;
  - quando a tela só mostra informações (Informações de rede, por exemplo);
  - quando uma pergunta depende do que acabou de aparecer ("Remover os itens acima?", "pressione uma tecla").
- **Copiar**, **Salvar** e **Abrir log** ficam junto dos detalhes.
- **O resultado ficou mais limpo:**
  - um ícone na cor do desfecho;
  - o desfecho em uma palavra ou duas (Tudo certo, Concluído com ressalvas, Não foi concluído, Cancelado, Interrompido, Terminou com erro);
  - uma frase com o que aconteceu e a duração, como "1,4 GB liberados. Duração: 01:15." A frase não repete mais "Concluído:" na frente.
  - Sem detalhe a dizer, aparecem frases claras: "Concluído com sucesso.", "Operação cancelada.", "Não havia nada a fazer.".
- **Interromper uma ação** explica: "O que já tinha sido feito continua feito; a etapa em andamento ficou incompleta."
- **Os textos do Reparo e do erro inesperado** apontam para os detalhes técnicos, e não mais para a "saída acima".
- **Perguntas:**
  - Escolhas com descrição, ou com mais de três opções, viram linhas clicáveis, com a recomendada destacada. "Cancelar" e "Voltar" ficam como botões embaixo.
  - As listas de marcação ganharam caixas no estilo da janela.
  - Enquanto o WinForge espera a resposta, a barra de progresso para e o estado diz "Esperando a sua resposta".
- **A barra de execução** (a que aparece no alto quando você está em outra página) mostra o tempo e a etapa: "Em execução · 01:15 · Limpeza do Windows". Quando o WinForge espera uma resposta, ela diz "Precisa da sua resposta". Quando a ação termina sem você ver, o ponto fica na cor do resultado e o botão vira "Ver resultado".

**O que não foi visto:** a janela nova não foi aberta num Windows de verdade durante este trabalho. Para conferir o desenho, usei uma prévia em HTML com as mesmas cores, ícones e medidas. O XAML e o script da janela foram validados contra as bibliotecas do WPF. Os pontos abaixo ainda precisam de uma conferência no Windows:
- o desenho final com a fonte Segoe UI;
- as animações;
- a cor da barra de título;
- a troca automática de tema ao mudar o Windows.

### Estrutura

- Novo módulo `GuiDesign` (na lista `Gui` de `Modules.psd1`). Ele guarda:
  - as paletas clara e escura da janela e da saída técnica (`Get-WinForgePalette`, `Get-WinForgeConsolePalette`, `Get-WinForgeLevelColors`);
  - os ícones, como geometrias de traço numa grade 24 × 24 (`Get-WinForgeIconData`), e o ícone de cada página, item e cartão do Início (`Get-WinForgeIconName`);
  - a preferência de tema, na chave `Theme` de `settings.json` (`Get-WinForgeThemePreference`, `Resolve-WinForgeTheme`, `ConvertTo-WinForgeColorRef`);
  - a frase da nota (`Get-WinForgeHealthHeadline`);
  - a leitura das linhas da saída para o resumo (`Get-WinForgeActivityEntry`, `Test-WinForgeRuleLine`, `Get-WinForgeSectionTitle`).
- `gui/MainWindow.xaml` foi refeito:
  - as cores são pincéis `DynamicResource`, trocados na hora pelo tema;
  - estilos novos: `PillButton`, `PrimaryButton`, `DangerButton`, `GhostButton`, `NavButton`, `NavButtonSelected`, `OptionButton`, `ListCheckBox`, `SlimProgress`, a chave e as barras de rolagem;
  - a tela de execução tem a etapa, o resumo, o resultado, as perguntas e os detalhes técnicos.
- `WinForge.Gui.ps1`:
  - Novas funções de tema: `Set-GuiTheme`, `Update-GuiTheme` (chamada quando a janela é ativada), `Set-GuiThemePreference` e `Set-GuiTitleBarTheme` (atributos do DWM).
  - Novas funções de ícone e de construção de controles: `New-GuiIcon`, `New-GuiButton -Kind -Icon`, `New-GuiChip`, `New-GuiNote`, `New-GuiNotice`, `New-GuiScoreRing`.
  - O resumo da execução usa `Add-GuiActivityFromLine` e `Add-GuiActivity` (últimas 300 linhas). Os detalhes técnicos usam `Set-GuiDetailsOpen`, e o estado da pergunta, `Set-GuiPromptState`.
  - A saída guarda o nome da cor de cada trecho, para ser recolorida quando o tema muda.
  - Não sobrou nenhuma cor escrita à mão no script.
- `GuiHost`: `Get-WinForgeRunView` devolve `ResultText`, montado pelo novo `Get-WinForgeResultSentence` (a frase do resultado com a duração).
- `Repair`: os textos de falha e ressalva do DISM/SFC não falam mais em "saída acima".

## Build 3.19

Revisão da tela Sobre o WinForge: o endereço de download da nova versão passa a ser conferido contra tentativas de sair da pasta de releases do projeto, a faixa de resultado do atalho diz onde ele ficou e avisa quando ele sai sem o ícone, o Modo de Administrador e a verificação de nova versão terminam com uma faixa que diz o que mudou ou por que não deu, e o alto da página ganha um resumo com a versão, o atalho e o modo de Administrador.

### Mudou para quem usa

**Criar atalho do WinForge**
- **Corrigido: um atalho criado sem o ícone, ou sem o identificador que agrupa o botão na barra de tarefas, saía verde ("Concluído com sucesso").** Agora a faixa fica amarela e diz o que falta: "atalho criado na Área de Trabalho, mas está com o ícone do PowerShell" e/ou "o botão pode aparecer como PowerShell ao ser fixado na barra de tarefas".
- **A faixa diz onde o atalho ficou:** "Concluído: atalho criado na Área de Trabalho e no Menu Iniciar." (ou "atualizado", quando já existia).
- **Cancelar o menu agora termina em "Operação cancelada."** em vez de "Nada a fazer".
- **Corrigido: pedir um lugar que o Windows não informou (por exemplo, sem a pasta do Menu Iniciar do usuário) terminava como "nada a fazer".** Agora é uma falha, com a explicação, e o modo console sai com código 1 em vez de 0.

**Modo de Administrador**
- **Voltar sem escolher termina em cinza ("Cancelado")**, em vez de ficar sem faixa de resultado.
- **Salvar a escolha diz o efeito:** "Concluído: salvo; a partir da próxima abertura, o Administrador será pedido ao abrir a janela" (ou "só será pedido quando uma ação precisar"). Se a preferência não puder ser gravada, a faixa fica vermelha com esse motivo.

**Versão e pastas**
- Se o arquivo `assets\WinForge.ico` não for encontrado, a faixa fica amarela e diz isso; antes a tela terminava sem nada, só com o aviso no meio do texto. Com o ícone no lugar, continua sem faixa, porque a tela só informa.

**Verificar nova versão**
- **Corrigido (segurança): o endereço do WinForge.zip que o GitHub informa era aceito se apenas começasse com a pasta de downloads do projeto.** Endereços com `..` ou `%2e%2e` ("…/releases/download/../../outro-projeto/…"), espaços em volta, `\`, credenciais no endereço, porta diferente ou sem nome de arquivo depois da pasta agora são recusados antes de qualquer download. O endereço de uma release legítima continua funcionando. O download já era conferido pelo SHA-256 publicado; isto fecha a porta antes dele.
- **As faixas dizem a versão e o motivo**, com o número da versão publicada: "a versão … está disponível, mas o download foi recusado", "versão … baixada e conferida (SHA-256)", "versão … baixada, mas sem hash publicado para conferir", "o hash do download não confere e o arquivo foi apagado", "esta cópia é mais nova que a última publicada (…)", "não foi possível consultar o GitHub agora; tente de novo mais tarde". O aviso de GitHub inacessível agora inclui "resposta inesperada" entre as causas possíveis.
- **Se a resposta do GitHub vier sem o endereço da página da release,** a mensagem aponta para a lista de releases do projeto em vez de terminar com um endereço vazio.

**Pasta de logs e Downloads**
- **Corrigido: se o Explorador de Arquivos não abrisse a pasta, a mensagem dizia "o recurso pode não existir nesta edição do Windows".** Para a pasta de logs e a de Downloads, que existem em qualquer edição, agora diz "O Explorador de Arquivos não abriu a pasta. Tente abri-la manualmente."

**Página Sobre o WinForge**
- **Um resumo no alto da página**, que não espera nenhuma leitura lenta: a **versão** ("Build 3.19"), **onde o atalho já existe** ("Área de Trabalho e Menu Iniciar", ou "ainda não criado; use Criar atalho do WinForge"), um aviso amarelo quando o **ícone** não foi encontrado e o **Administrador** ("pedido só quando uma ação precisar · esta janela está sem Administrador"). Se alguma leitura falhar, só aquela linha vira "não foi possível ler", e a página abre do mesmo jeito.
- A descrição da página na barra lateral e nos resultados da busca passa a citar as atualizações e o modo de Administrador: "Versão e atualizações, atalho com ícone, pasta de logs e modo de Administrador."

**Busca**
- Novas palavras levam ao item certo: "build" e "powershell" a Versão e pastas; "fixar" e "barra de tarefas" a Criar atalho do WinForge; "pedir", "sempre" e "sob demanda" ao Modo de Administrador.

**Desempenho** (medido em Linux, com leituras simuladas; no Windows não foi medido)
- O resumo do alto da página lê só as preferências, duas pastas e o cabeçalho do ícone; na simulação, leva cerca de 4 ms (mediana), e abrir a tela "Versão e pastas" no console, cerca de 7 ms. Nenhuma consulta à internet acontece ao abrir a página: a verificação de nova versão continua só quando você a pede.

### Estrutura

- `AppUpdate`: `Test-WinForgeReleaseDownloadUrl` passa a validar o endereço como `Uri` (esquema https, host github.com, porta padrão, sem credenciais, sem `..`/`.` nem `%2e` no caminho, sem espaços nem `\`, com um nome de arquivo depois de `/<repositório>/releases/download/`); `Invoke-WinForgeUpdateCheck` leva a versão para os detalhes das faixas e usa a lista de releases do projeto quando a resposta não traz `PageUrl`.
- `Launcher`: `New-WinForgeShortcutFiles` devolve `Warning` quando falta o ícone ou o `AppId`, e o texto de `Ok` diz onde o atalho ficou; `New-WinForgeAppShortcut` separa "nenhuma escolha" (`Skipped`, cancelado) de "lugar indisponível" (`Failed`); `Set-WinForgeAdminMode` termina sempre com um resultado explícito; `Show-WinForgeAbout` devolve `Warning` quando falta o ícone; novo `Get-WinForgeAboutPageStatus` (linhas `Label`, `Text`, `Level` do resumo da página).
- `WinForge.Gui.ps1`: `New-GuiPageStatus` atende também a página `app`; `Open-GuiShortcut` troca o motivo da falha para as pastas de logs e de Downloads.
- `Navigation`: descrição da página Sobre o WinForge e palavras de busca de três itens.

## Build 3.18

Revisão da tela de Ajustes do Windows: a faixa de resultado da chave de cada ajuste passa a dizer o que aconteceu (aplicar em notebook deixa de sair amarelo, sem Administrador fica vermelho), o Explorador que não reinicia vira um aviso com o que fazer em vez de uma falha do ajuste, aplicar recomendados, perfis ou importar sem que nenhum ajuste funcione deixa de sair "com ressalvas", a lista reabre no ajuste que acabou de mudar, os ajustes de sistema avisam que pedem Administrador antes do clique e a busca reconhece "pastas ocultas", "gamer" e "lock screen".

### Mudou para quem usa

**Ligar e desligar um ajuste (a chave)**
- **Corrigido: aplicar em notebook um ajuste que gasta bateria saía amarelo mesmo dando certo.** O aviso que aparece antes da pergunta (o de notebook, ou o de o WinForge estar elevado com outra conta) rebaixava a faixa. Agora ela fica verde e diz "Concluído: ajuste aplicado." (ou "ajuste desfeito.").
- **Corrigido: se o Explorador de Arquivos não reiniciava, a tela dizia "Falha ao alterar o ajuste"**, embora o ajuste já estivesse gravado, e a faixa repetia essa falha. Agora aparece "Não foi possível reiniciar o Explorador (motivo). Para ver as mudanças, saia do Windows e entre de novo." e a faixa fica amarela: "o Explorador não reiniciou".
- **Sem Administrador, num ajuste de sistema, a faixa fica vermelha:** "Não foi concluído: requer Administrador". Recusar a pergunta termina em cinza ("Cancelado").
- **Depois de aplicar, a dica de como desfazer fala da janela:** "para desfazer, desligue a chave deste ajuste" (no terminal continua "abra este ajuste de novo").
- **A lista reabre já no ajuste que mudou**, destacado e trazido para a vista, com o estado novo, em vez de voltar ao topo. Vale também para ajustes avançados (o painel continua aberto) e para "Executar de novo".
- **Os ajustes que pedem Administrador avisam antes do clique:** com a janela sem Administrador, a linha mostra "Pede Administrador ao executar" e o balão da chave e dos botões repete o aviso. Como Administrador, nada disso aparece.

**Aplicar ajustes recomendados, Perfis de ajustes e Importar ajustes**
- **Corrigido: se nenhum ajuste era aplicado, a faixa saía amarela.** Agora, quando todos falham, ela fica vermelha: "Não foi concluído: nenhum ajuste foi aplicado (N com problema)". "Concluído com ressalvas" fica para quando parte deu certo. A frase "Todos podem ser desfeitos..." só aparece quando algo foi aplicado.
- **Corrigido: o Explorador que não reiniciava no fim deixava a faixa vermelha** ("Falha ao aplicar os ajustes", "Não foi possível importar"), com os ajustes já gravados. Agora é a mesma faixa amarela de acima.

**Importar ajustes**
- **Corrigido: um arquivo sem nenhum ajuste que esta versão conheça dizia que os ajustes "já estão aplicados".** Agora diz "O arquivo não traz nenhum ajuste que esta versão do WinForge conheça" e termina em cinza ("Nada a fazer"). Ajustes repetidos no arquivo aparecem uma vez só.

**Desfazer ajustes do WinForge**
- **A faixa diz o que ficou:** "Concluído: 3 ajuste(s) desfeito(s).", amarela com "1 de 3 não puderam ser desfeitos" (o backup deles é mantido) e vermelha quando nenhum pôde ser desfeito. Sem backup ou recusando a pergunta, cinza. Um Explorador que não reinicia deixa de ser tratado como erro e vira o mesmo aviso amarelo.

**Busca**
- Novas palavras levam ao ajuste certo: "pastas ocultas" e "arquivos escondidos" a Mostrar arquivos ocultos; "gamer" à Game Bar; "lock screen" às dicas da tela de bloqueio; "perfil" a Perfis de ajustes.

**Desempenho** (medido em Linux, com um powercfg simulado que gasta 60 ms por chamada; no Windows o ganho depende do tempo real do powercfg e não foi medido)
- **Ler o estado da página de Ajustes consulta o powercfg uma vez a menos** (de 4 para 3 processos) quando o plano de energia ativo não é o Alto desempenho, que é o caso comum: o ajuste "Plano de energia Alto desempenho" chamava `powercfg /getactivescheme` duas vezes. Na simulação, a leitura caiu de cerca de 250 ms para cerca de 195 ms.

### Estrutura

- `Tweaks`: `Get-WinForgeActivePowerScheme` devolve o GUID e o texto do plano ativo numa consulta só (`Get-WinForgeActivePowerSchemeGuid` usa a mesma); `Get-WinForgeTweakOverview` leva `RequiresAdmin`; `Request-WinForgeExplorerRestart` pergunta e reinicia o Explorador devolvendo `Restarted`, `Declined` ou `Failed`, usada pelo alternar, pelo lote e pelo desfazer tudo; `Invoke-WinForgeTweakToggle` e `Invoke-WinForgeRevertAllTweaks` entregam o desfecho a `Exit-WinForgeAction -Result`; `Invoke-WinForgeTweakBatch` devolve `Failed` quando nada foi aplicado; `Read-WinForgeTweakExport` não repete Ids; `Invoke-WinForgeTweakImportFile` separa "arquivo sem ajustes conhecidos" de "tudo já aplicado"; `Invoke-WinForgeTweakRevert` lê o original do backup sem depender de a propriedade existir.
- `WinForge.Gui.ps1`: `Start-GuiAction -FocusTweak` guarda o ajuste na última ação; `Show-GuiRunBack` e "Executar de novo" o repassam à página de Ajustes; `New-GuiTweakRow` mostra a nota de Administrador.
- `Navigation`: novas palavras de busca dos ajustes e dos perfis.

## Build 3.17

Revisão da tela de Rede: o reparo que não funciona deixa de sair amarelo e de pedir reinício à toa, o teste de velocidade não perde mais um número bom quando o outro falha e deixa de contar o tempo de abrir a conexão, o ping não acusa o DNS quando o problema é só o ping bloqueado, a consulta do IP público não confunde a página de login do Wi-Fi com um endereço, as faixas de DNS, Wi-Fi e velocidade passam a dizer o que aconteceu, o "Cancelar" deixa de aparecer em destaque nos menus e a página ganha uma ordem do mais simples ao mais invasivo e uma busca que reconhece "lag", "wifi caindo", "teste de velocidade" e mais.

### Mudou para quem usa

**Reparar rede e DNS**
- **Corrigido: se nenhum comando funcionasse, a faixa saía amarela e mandava reiniciar.** Agora, quando todos falham (por exemplo, se o Windows se recusa a rodar o ipconfig e o netsh), a faixa fica vermelha: "Não foi concluído: nenhum dos comandos funcionou". A tela não espera a conexão voltar nem pede reinício, porque nada foi redefinido.
- **Corrigido: o reinício era pedido sempre.** Agora só quando o reset do Winsock ou do TCP/IP funcionou (limpar o DNS e renovar o IP não precisam dele). A faixa diz "Reinicie o PC para concluir." uma vez só.
- **Quando só parte dos comandos falha**, a faixa amarela diz quantos: "1 comando falhou" ou "2 comandos falharam". O código de saída aparece também em hexadecimal quando é negativo ("finalizou com código 0xFFFFFFFF").
- Com IP estático (só limpar o DNS e redefinir o Winsock), o reinício também é pedido, porque o Winsock só termina de valer depois dele.

**Testar velocidade da internet**
- **Corrigido: uma falha jogava fora a outra medição.** Se o upload era recusado, o download já medido sumia (e o contrário). Agora a tela mostra o que foi medido, escreve "não foi possível medir" no que falhou e a faixa fica amarela: "Concluído com ressalvas: o upload falhou: ...". Se as duas falham, fica vermelha com o motivo.
- **Corrigido: a conta do download incluía o tempo de abrir a conexão** (resolver o nome, conectar, negociar o TLS), o que fazia a velocidade parecer menor do que é, e mais ainda nas conexões rápidas. Agora o relógio só corre quando os dados começam a chegar.
- **Corrigido: uma queda no meio da medição jogava tudo fora.** Agora vale o que já tinha chegado.
- **Quando dá certo, a faixa traz os dois números:** "Concluído: download 95.3 Mbps, upload 20.1 Mbps." Recusar a pergunta termina em cinza ("Cancelado", "Operação cancelada.").

**Testar conectividade (ping)**
- **Corrigido: servidores que não respondem ao ping eram tratados como problema de DNS.** Quando os IPs respondiam e www.microsoft.com e www.google.com não, a tela dizia que o DNS estava quebrado, mesmo com o DNS funcionando e só o ping bloqueado. Agora o WinForge pergunta ao DNS do PC: se ele resolve os nomes, a mensagem é "Alguns servidores bloqueiam ICMP"; se não resolve, aí sim aponta o DNS e o "Reparar rede e DNS".
- **Corrigido: sem internet o teste podia ficar parado por muito tempo.** No PowerShell 7, cada resposta esperada tinha até 5 s; agora são 3 s.

**Informações de rede**
- **Corrigido: a página de login do Wi-Fi de hotel ou aeroporto aparecia como "IP público".** Agora, se a resposta não é um endereço IP, a tela avisa em amarelo e não mostra o texto da página.
- A consulta do IP público espera até 5 s (eram 8 s).

**Trocar o servidor DNS e Desfazer a troca de DNS**
- **A faixa diz o que ficou:** "Concluído: DNS Cloudflare." ou "Concluído: DNS automático.". Se um adaptador recusa a troca, fica amarela dizendo qual ("1 adaptador não foi alterado (Wi-Fi)", "2 adaptadores não foram alterados (Wi-Fi, Ethernet 2)"), sem "adaptador(es)" nem "(s)".
- **Corrigido: desfazer com os adaptadores desligados saía vermelho.** Quando os adaptadores do backup estão desligados (Wi-Fi apagado, cabo fora), a faixa fica amarela: "nenhum adaptador do backup está ativo agora; ligue-os e repita", e o backup é mantido. Uma restauração parcial também fica amarela e mantém o backup; "1 adaptador voltou ao DNS de antes" e "2 adaptadores voltaram ao DNS de antes" saem no singular e no plural certos.

**Relatório de Wi-Fi**
- A faixa diz "Concluído: relatório salvo." (ou "relatório salvo; não foi possível abri-lo" se o Windows não abriu o arquivo).

**Menus com "Cancelar" ou "Voltar" como resposta do ENTER**
- **Corrigido: o botão de sair aparecia em azul, como se fosse a ação recomendada.** No menu de DNS, "Cancelar" ficava em destaque junto com "Cloudflare". Agora só a ação recomendada tem a cor de destaque, e "Cancelar" e "Voltar" aparecem como botões de sair, também nos outros menus em que ENTER cancela ou volta (restaurar um backup, perfis e importação de ajustes, agendamento e ajustes da Manutenção, verificar pasta ou arquivo, gerenciar inicialização e modo de Administrador).

**Página Rede**
- **Ordem do mais simples ao mais invasivo:** Informações de rede → Testar conectividade (ping) → Testar velocidade da internet → Relatório de Wi-Fi → Reparar rede e DNS → Trocar o servidor DNS → Desfazer a troca de DNS. O relatório de Wi-Fi, que só lê, vinha depois das telas que mudam o DNS.

**Busca**
- Novas palavras levam à tela certa: "ping alto", "lag" e "sem internet" levam a Testar conectividade; "teste de velocidade" a Testar velocidade da internet; "wifi caindo", "cai", "desconectando" e "fraco" ao Relatório de Wi-Fi; "reiniciar rede", "redefinir", "dhcp" e "netsh" a Reparar rede e DNS; "meu ip" e "ip público" a Informações de rede.

**Desempenho** (medido em Linux, com um servidor HTTP local que simula a conexão e 0,5 s de espera para conectar; no Windows e na internet de verdade os números mudam)
- **Teste de velocidade:** numa conexão simulada de cerca de 8 Mbps, a versão antiga marcava 6,6 a 6,8 Mbps e a nova marca 7,9; numa de cerca de 130 Mbps, a antiga marcava 86 a 94 Mbps e a nova 122 a 133. A diferença é o tempo de abrir a conexão, que antes entrava na conta.
- **Menos espera, por conta feita a partir dos limites do código (não medida no Windows):** o reparo em que nenhum comando funciona deixa de esperar a conexão voltar (4 tentativas de 3 s, pelo menos 12 s); a espera por resposta do ping no PowerShell 7 cai de 5 s para 3 s; a consulta do IP público espera até 5 s em vez de 8 s.

### Estrutura

- `Network`: `Test-WinForgeIpAddressText` (um endereço IP de verdade, em vez de qualquer texto) usado pelo veredito do ping e pela consulta do IP público; `Get-WinForgePingVerdict` considera `Resolved` (o DNS do PC resolve o nome); `Get-WinForgeNetworkRepairCommands` marca `NeedsRestart`; o reparo devolve `Failed` quando todos os comandos falham e leva `RebootRequired` ao resultado; `Measure-WinForgeDownload` (`-BaseUrl`) e `Measure-WinForgeUpload` (`-Url`) aceitam outro endereço e tratam a queda no meio da transferência; o teste de velocidade entrega o resultado a `Exit-WinForgeAction -Result` com download e upload separados.
- `NetworkTools`: trocar e desfazer o DNS e o relatório de Wi-Fi entregam o desfecho a `Exit-WinForgeAction -Result`, com singular e plural nas frases.
- `GuiHost`: `Get-WinForgePromptPlan` não promove a opção de sair (`Exit`) a botão de destaque só porque ela é a padrão do ENTER.
- `Navigation`: nova ordem da página Rede e novas palavras de busca.

## Build 3.16

Revisão da tela de Programas: instalar, buscar e desinstalar passam a terminar com o desfecho certo (o programa que falha deixa a faixa vermelha; nada marcado e recusar a confirmação ficam cinza), o código de erro do winget aparece também em hexadecimal, a leitura da lista do winget deixa de demorar alguns segundos quando os nomes têm "…", "™" ou "–", o backup deixa de sair verde quando não havia nada a guardar e a página ganha uma ordem em grupos e uma busca que reconhece o nome dos programas.

### Mudou para quem usa

**Instalar programas essenciais, Buscar e instalar programas e Desinstalar programas**
- **Corrigido: o único programa que falhava saía amarelo.** "Concluído com ressalvas" agora só aparece quando parte dos programas deu certo. Se o único marcado (ou todos) falha, a faixa fica vermelha: "Não foi concluído: nenhum pacote foi processado: 7-Zip". Com dois marcados e um falhando, continua amarela e diz qual: "1 de 2 com falha: Google Chrome".
- **Corrigido: "nada marcado" e "cancelar" saíam amarelos.** Nada marcado, nome em branco na busca e busca sem resultado terminam em cinza ("Nada a fazer"); recusar a confirmação de desinstalar termina em cinza ("Cancelado", "Operação cancelada.").
- **Corrigido: um erro da busca podia passar por "não encontrei".** Quando o winget não devolve tabela, o código de saída decide: "nenhum pacote encontrado para 'nome'" (cinza) ou "a busca falhou: código ... (0x...)" (vermelho).
- **Corrigido: lista de programas ilegível na desinstalação** (o winget devolveu erro e nenhuma tabela) aparecia como aviso amarelo. Agora é erro, a faixa fica vermelha com o código e nada é removido.
- **Sem winget**, a faixa diz "winget não encontrado" nas quatro telas.
- **Erro inesperado** durante a instalação, a busca ou a remoção deixa a faixa vermelha com o motivo.

**Listar programas instalados**
- **Corrigido: a faixa mudava de uma vez para outra.** Na primeira consulta da sessão a tela terminava verde (a atualização da lista de pacotes contava como sucesso) e nas seguintes saía sem faixa. Agora termina sempre verde ("Tudo certo"), ou amarela com o código quando o winget termina com erro ("código 3 (0x00000003)").

**Recursos opcionais do Windows**
- **Corrigido: o pedido de reinício aparecia duas vezes na faixa** ("Concluído: reinício necessário. Reinicie o PC para concluir."). Agora a faixa diz só "Concluído com sucesso. Reinicie o PC para concluir."

**Gerenciar inicialização**
- A faixa diz o que mudou: "Concluído: 2 itens desativados." ou "Concluído: 1 item reativado.", em vez de só "Concluído com sucesso".

**Backup antes de formatar e Restaurar a partir de um backup**
- **Corrigido: backup em que tudo o que foi marcado estava vazio saía verde.** Marcar só os ajustes (sem nenhum aplicado) ou só o Wi-Fi (sem redes salvas) gerava uma pasta sem nada e a faixa dizia "Tudo certo". Agora termina em cinza: "Nada foi feito: nada a guardar nos itens marcados".
- **Corrigido: na restauração, o winget dizendo que o programa "já estava instalado" virava ressalva.** Agora conta como sucesso, como nas outras telas de programas; um erro de verdade mostra o código em decimal e em hexadecimal.
- **Restauração em que nada havia a restaurar** termina em cinza, em vez de verde.
- **O pedido de reinício dos drivers chega à faixa.** Quando o instalador de drivers diz que falta reiniciar (código 3010), a faixa passa a acrescentar "Reinicie o PC para concluir.", também quando outro item terminou com ressalva.

**Página Programas**
- **Itens em grupos.** Instalar (essenciais, buscar, listar) → remover (desinstalar, aplicativos instalados, Programas e Recursos, aplicativos do Windows) → inicialização (o gerenciador do WinForge vem antes da janela do Windows que faz parecido) → recursos opcionais → backup e restauração. Antes, "Gerenciar inicialização" ficava separado de "Aplicativos de inicialização" por três itens e os atalhos de remoção ficavam espalhados.

**Busca**
- Novas palavras levam à tela certa: o nome dos programas essenciais ("discord", "steam", "vscode", "python", "node", "java", "powershell", "notepad", "everything", "powertoys") leva a Instalar programas essenciais; "startup", "lenta" e "lentidão" levam a Gerenciar inicialização e a Aplicativos de inicialização; "smb1" leva a Recursos opcionais.

**Desempenho** (medido em Linux, com uma tabela de 400 programas gerada para o teste; no Windows os números mudam, e quem domina o tempo é o próprio winget)
- **Ler a lista do winget** com nomes que têm "…", "™" ou "–" passou de 2,9 s para 0,1 s (com "…", de 1,4 s para 0,08 s): antes, qualquer caractere acima de U+1100 mandava a linha pela leitura lenta, mesmo sendo de uma coluna só. Com ideogramas ou hangul, de 1,2 s para 0,7 s; tabelas só com ASCII continuam em cerca de 0,2 s.

### Estrutura

- `Software`: instalar os essenciais, buscar, desinstalar e listar entregam o resultado a `Exit-WinForgeAction -Result` (novo `Get-WinForgeLastResult`, que pega o último resultado entre as saídas); `Get-WinForgeSafeSubstring` usa o caminho rápido para tudo o que não é largo nem combinado e conta as colunas dos caracteres abaixo de U+0300 sem chamar `Get-WinForgeCharWidth`.
- `WindowsFeatures`: o resultado final não leva mais o detalhe "reinício necessário" (a marca `RebootRequired` já pede o reinício).
- `Startup`: o resultado final leva a contagem de itens desativados ou reativados.
- `Backup`: backup vazio vira `Skipped`; a restauração interpreta o código do `winget import` com `Get-WinForgeWingetExitResult`, distingue `Skipped` e leva `RebootRequired` ao resultado final; removido o dado `Folder` dos resultados do backup, que nenhuma tela lia.
- `Navigation`: nova ordem da página Programas e novas palavras de busca.

## Build 3.15

Revisão da tela de Atualizações: "Windows em dia" deixa de aparecer como "nada feito", uma atualização que sumiu da lista ou que não foi baixada deixa de passar em silêncio, o pedido de reinício aparece uma vez só, os erros do winget ficam vermelhos e a tela deixa de despejar centenas de linhas do indicador de espera e das barras de download.

### Mudou para quem usa

**Instalar atualizações do Windows**
- **Corrigido: "Windows em dia" saía cinza.** Sem nada pendente, a faixa dizia "Nada foi feito". Agora a faixa diz "Tudo certo" ("Concluído: o Windows está em dia.") e sai verde.
- **Corrigido: atualização que sumiu ou não foi baixada passava em silêncio.** Se uma das escolhidas deixava de ser oferecida pelo Windows Update entre a lista e a instalação, ou o download terminava sem baixá-la, ela não aparecia no resumo e a faixa podia sair verde. Agora ela entra no resumo com o nome que você viu ("não está mais disponível" ou "não foi baixada"), conta como falha e a faixa fica amarela (vermelha, se nenhuma foi instalada).
- **Corrigido: erro no meio da instalação sumia.** Se o Windows Update dava erro depois de algumas atualizações já terem resultado (uma situação rara), a tela mostrava só o resumo parcial, como se estivesse completo. Agora o erro aparece na tela e na faixa, que fica amarela.
- **Corrigido: o reinício era pedido duas vezes** (na frase da faixa e de novo no fim dela). Agora a faixa diz "Reinicie o PC para concluir." uma vez só, e o pedido chega à faixa também quando a instalação termina com ressalvas.
- **Resumo com contagem.** A frase diz quantas foram instaladas ("2 atualizações instaladas") ou o que deu errado ("1 de 3 falhou; 1 com erros", "nenhuma atualização foi instalada"), no lugar de "N de M com ressalvas".
- **Códigos do Windows Update que indicam "não terminou"** (0 e 1) aparecem como "não foi concluída", em vez de "falhou" sem explicação.
- **Avisos durante a espera.** A busca diz que pode levar até 2 minutos (antes dizia "até um minuto", abaixo do tempo limite real). Depois de confirmar, a tela avisa "Preparando a instalação (o Windows Update confere as atualizações escolhidas)..." e "Se interromper, o Windows pode continuar instalando por conta própria.", em vez de parecer parada.

**Atualizar programas (winget)**
- **Corrigido: "Não atualizar" saía amarelo.** Agora a faixa é cinza ("Nada foi feito"), porque você decidiu não atualizar.
- **Corrigido: falhas do winget podiam sair amarelas.** O desfecho agora vem do resultado de verdade: pacote escolhido que falha deixa a faixa vermelha, e um erro depois de a lista de pacotes ter sido atualizada continua sendo falha.
- **Corrigido: "nenhuma atualização aplicável" saía amarelo** em "Atualizar todos". É só o winget dizendo que não havia o que atualizar; agora termina verde.
- **Código de erro legível.** Um erro do winget aparece como "código 5 (0x00000005)", em decimal e em hexadecimal.
- **Saída resumida na tela.** O winget escreve um quadro do indicador de espera ("-", "\", "|", "/") e uma barra a cada passo do download; num exemplo sintético de dois programas, a tela recebia 1.018 linhas. Agora mostra 30: sem os quadros do indicador, com a primeira barra, uma a cada 10 pontos e a última. O texto completo continua no log, e uma linha que o WinForge não reconhece como progresso continua aparecendo.

**Página Atualizações**
- **"Instalar atualizações do Windows" vem primeiro e em destaque** (é o caminho recomendado), seguido de "Atualizar programas (winget)" e dos três atalhos para as janelas do Windows. Antes, os atalhos vinham na frente e o destaque ficava no winget.

**Busca**
- Novas palavras levam à tela certa: "atualizar tudo", "programas desatualizados", "navegador", "chrome" e "firefox" (Atualizar programas); "kb", "cumulativa", "segurança", "patch" e "pc desatualizado" (Instalar atualizações do Windows); "driver desatualizado", "prévia" e "preview" (Atualizações opcionais e drivers); "verificar" e "desatualizado" (Windows Update); "travado", "travada" e "falhou" levam ao Reparo (DISM), para um Windows Update que não anda.

**Desempenho** (medido em Linux, com um winget simulado; no Windows os números mudam, e quem domina o tempo é o próprio Windows Update/winget)
- Decidir se uma linha de progresso aparece custa cerca de 0,1 ms; linhas sem "%" nem " / " nem são examinadas. Conferido, sem mudança: cada instalação consulta o Windows Update duas vezes (uma para montar a lista e outra dentro do instalador, porque os objetos da consulta não podem ser passados de uma execução interna para a outra); não alterei isso sem poder testar no Windows.

### Estrutura

- `Core`: `Get-WinForgeProgressPercent` passa a ler também as barras do winget (blocos com percentual ou com "tamanho / total"); novo `Test-WinForgeEchoLine` (esconde os quadros do indicador e limita as barras), usado por `Invoke-WinForgeCapture -Echo` e por `Invoke-WinForgeNative` na janela.
- `WindowsUpdate`: o instalador devolve também `Missing` e `NotDownloaded`; novos `Get-WinForgeUpdateRunDetail` e `Get-WinForgeUpdateTitleById`; `Get-WinForgeUpdateOutcome` reconhece os códigos 0 e 1.
- `Software`: `Update-WinForgeSoftware` entrega o resultado do plano a `Exit-WinForgeAction -Result`; o ramo "Atualizar todos" interpreta o código de saída com `Get-WinForgeWingetExitResult`.
- `Navigation`: nova ordem e novo destaque na página Atualizações; palavras de busca.

## Build 3.14

Revisão da tela de Reparo: um SFC que não chegou a rodar e um CHKDSK interrompido deixam de terminar como "concluído", os códigos de erro ficam legíveis, a tela deixa de despejar centenas de linhas de progresso e o resumo diz quanto cada etapa levou e por que é preciso reiniciar.

### Mudou para quem usa

**Resultado dos reparos**
- **Corrigido: SFC que não rodou terminava verde.** Quando o SFC avisava que não conseguiu iniciar a verificação, a tela dizia "Concluído" e a faixa saía verde. Agora termina em vermelho com "o SFC não conseguiu executar a verificação", em português e em inglês.
- **Corrigido: CHKDSK interrompido terminava verde.** Se o programa fechava no meio (código de saída negativo), a verificação era dada como feita e não oferecia nada. Agora diz "O CHKDSK foi interrompido antes de terminar" com o código, termina em vermelho e não pergunta sobre reparo.
- **Corrigido: códigos de saída ilegíveis.** Um código como `-2146498530` aparecia em decimal; agora, quando é negativo ou grande demais para ser um código comum do programa, aparece em hexadecimal (`0x800F081E`).
- **Corrigido: texto torto** na descrição de "Otimizar a unidade do sistema": saía "Unidade C: : o Windows escolhe…", com dois-pontos repetido; agora "Na unidade C:, o Windows escolhe…".
- **Reinício com motivo.** A faixa e o resumo dizem o que falta: "há um reparo pendente do Windows: reinicie e repita o reparo", "reinicie o Windows para concluir o reparo" ou, quando o SFC ainda acha arquivos corrompidos, "o SFC ainda encontra arquivos corrompidos que não conseguiu reparar; veja o CBS.log".
- **Próximo passo do SFC.** Rodando sozinho e deixando arquivos sem reparo, o SFC indica "Reparar o Windows (DISM + SFC)", que corrige a imagem antes de repetir a verificação. Dentro do reparo completo essa dica não aparece, porque ele já faz isso.
- **Tempo de cada etapa.** O resumo do reparo completo mostra a duração do DISM e do SFC (e do SFC final, quando há).

**Tela e progresso**
- **Barras de progresso resumidas.** O DISM escreve uma barra a cada fração de porcentagem e o SFC um percentual por linha; a tela mostrava todas (num teste sintético, 2.022 linhas). Agora mostra a primeira, uma a cada 10 pontos e a última (222 linhas). O log guarda o texto completo, e uma linha que o WinForge não reconhece como progresso continua aparecendo.
- **Faixa "Operação cancelada." em todas as telas.** Ao cancelar na pergunta, a faixa dizia "Nada foi feito: cancelado pelo usuário."; agora diz "Operação cancelada.", igual em Reparo, Segurança, Limpeza e nas demais.

**Busca**
- Novas palavras levam ao reparo certo: "corrupção", "instável" e "tela azul" (Reparar o Windows); "restorehealth", "cleanup-image" e "atualização falhando" (DISM); "integridade" e "cbs" (SFC); "bad sector", "hd com problema", "ntfs", "fsutil" e "disco corrompido" (CHKDSK); "pnputil", "usb não reconhecido" e "dispositivo não reconhecido" (Detectar dispositivos e drivers).

**Desempenho** (medido em Linux, com ferramentas simuladas; no Windows os números mudam, e quem domina o tempo é o próprio DISM/SFC)
- Reconhecer uma linha de progresso custa cerca de 0,2 ms; linhas sem "%" nem são examinadas. Conferido, sem mudança: o reparo completo com verificação prévia consulta o estado da imagem uma vez e cada ferramenta roda uma vez só.

### Estrutura

- `Core`: novos `Get-WinForgeProgressPercent` (lê o percentual das barras do DISM e do SFC) e `Test-WinForgeProgressStepShown` (decide quais linhas aparecem); `Invoke-WinForgeCapture` passa a usá-los na saída ao vivo, sem alterar `Lines` nem `Text`.
- `Repair`: novos `Format-WinForgeExitCode` e `Invoke-WinForgeTimedRepairStep`; `Invoke-WinForgeTool` aceita `-AfterResult`; `Get-WinForgeSfcResult` reconhece o SFC que não rodou; `Start-WinForgeChkdsk` trata o código negativo como interrupção.
- `Console`: `Format-WinForgeOutcomeSummary` resume o cancelamento como "Operação cancelada.".
- `Navigation`: palavras de busca da página Reparo.

## Build 3.13

Revisão da tela de Limpeza: pasta que o Windows não deixa ler deixa de parecer "vazia", limpeza em que nada pôde ser removido deixa de terminar como "concluída", e a pasta Downloads redirecionada para um lugar perigoso passa a ser recusada.

### Mudou para quem usa

**Temporários do usuário, temporários do Windows e Limpeza rápida**
- **Corrigido: "Não há nada para limpar" sem ter olhado.** Quando o Windows negava a leitura da pasta (por exemplo, a Temp do Windows sem Administrador), a tela dizia "Não há nada para limpar nesta pasta" e terminava verde. Agora diz "Não foi possível ler a pasta" com o motivo, orienta abrir o WinForge como Administrador, não pergunta nada e termina em vermelho.
- **Corrigido: "Limpeza concluída" sem ter removido nada.** Se todos os itens estavam em uso, a tela mostrava "Limpeza concluída. Itens removidos: 0" e a faixa saía verde. Agora diz "Nenhum item pôde ser removido", orienta fechar os programas e a faixa fica amarela. Quando só parte dos itens está em uso, continua verde e explica que isso é esperado.
- A **Limpeza rápida** passa a contar as partes que terminaram com ressalvas: uma parte em que nada foi removido não deixa mais o total verde ("2 de 3 partes com ressalvas"). Uma parte que falhou continua sendo dita junto ("1 de 3 partes falharam; 1 com ressalvas").
- O espaço liberado sai do que de fato foi removido: cada item é medido uma vez, antes de ser apagado, inclusive numa pasta que ficou pela metade.

**Pasta Downloads**
- **Corrigido: sem trava de segurança.** Se o Windows tinha a pasta Downloads redirecionada para a raiz de um disco, para o seu perfil ou para uma pasta que o contém, a opção "Tudo" apagaria muito mais do que downloads. Agora essa pasta é recusada, com a mesma trava dos temporários, antes de qualquer pergunta.
- **Corrigido: pasta ilegível parecia "já está vazia".** Agora a tela dá o erro com o motivo e termina em vermelho.
- **Corrigido: atalho de pasta inflava o "Espaço a liberar".** Um atalho (junção ou link simbólico) dentro de Downloads era somado com todo o conteúdo da pasta de destino. Agora vale como atalho (zero), e só o atalho é removido.
- **Corrigido: "Concluído com ressalvas" depois de excluir de vez com sucesso.** O aviso "Os itens serão removidos permanentemente", mostrado antes da confirmação, contava como ressalva. Agora é só um aviso: a exclusão que deu certo termina verde.
- Quando nada foi removido (tudo em uso), a tela diz "Nenhum item foi removido" em amarelo, e a dica de que o espaço só volta ao esvaziar a Lixeira só aparece se algo foi para a Lixeira.

**Analisar uso de espaço**
- **Corrigido: "Não há temporários, relatórios nem caches acumulados" sem ter medido tudo.** Com a Lixeira sem resposta ou uma pasta que o Windows não deixa ler, a tela afirmava que não havia nada. Agora nomeia o que não foi medido ("Não foi possível medir: Lixeira."), e o total vira "Pelo menos X podem ser liberados" quando algo ficou de fora. Como Administrador isso é uma ressalva; sem Administrador é só uma informação, com o conselho de abrir o WinForge como Administrador.
- O Windows.old e os downloads do Windows Update que existem e não abrem aparecem como "não foi possível medir" (antes a linha sumia, como se não existissem). Se o tamanho do disco não pôde ser lido, a tela avisa em vez de pular a seção em silêncio.

**Limpeza personalizada**
- **Corrigido: "liberou 0 B" em verde.** Numa pasta marcada em que todos os itens estavam em uso, o resultado era "liberou 0 B". Agora vira "nenhum item pôde ser removido (em uso)" e a faixa fica amarela.
- Uma pasta que o Windows não deixa ler aparece na lista como "tamanho desconhecido" (antes ficava fora da lista, como se estivesse vazia) e, se marcada, vira uma ressalva dita; as outras pastas seguem.
- A Lixeira marcada é esvaziada sem contar os itens de novo.

**Desempenho** (medido em Linux, numa árvore sintética de 9.000 arquivos; no Windows os números mudam, e o tempo total quase não muda porque apagar os arquivos domina)
- Limpar uma pasta percorria a árvore 3 vezes (medir antes, listar, medir depois); agora percorre 1. Na Limpeza rápida foram de 6 para 2 e na personalizada de 6 para 4.
- A Limpeza personalizada consultava a Lixeira pelo Shell do Windows 2 vezes; agora 1.

**Busca**
- Novas palavras levam à tela certa: "windows.old", "hiberfil", "hibernação", "pagefile", "memória virtual" e "swapfile" (Analisar uso de espaço); "otimização de entrega" e "delivery optimization" (Limpeza personalizada); "apagar", "excluir" e "remover" (Downloads). As descrições dos cartões de Analisar uso de espaço, Limpeza personalizada e Downloads ficaram mais curtas.

### Estrutura

- `Cleanup`: novos `Get-WinForgeFolderListing` (diz se a pasta pôde ser lida), `Measure-WinForgeFolderItems` (mede os itens numa passada só, sem seguir atalhos) e `Get-WinForgeFolderSize` (nulo quando a pasta não pôde ser lida); `Clear-WinForgeFolderContents` devolve `Removed`, `Skipped`, `SizeBefore` e `Freed` (saíram `Remaining` e `SizeAfter`) e aceita `-Entries`; `Clear-WinForgeRecycleBin` aceita `-SkipCount`; `Get-WinForgeDownloadsItems` saiu, no lugar da listagem e da medição novas; os alvos da limpeza e os arquivos do sistema ganham `Unreadable`.
- `Navigation`: palavras de busca e descrições da página Limpeza.

## Build 3.12

Revisão da tela de Segurança: o "tudo em ordem" deixa de aparecer quando parte da proteção não pôde ser lida, a auditoria deixa de dar nota A sem ter lido o antivírus, e as verificações conferem o Defender antes de fazer perguntas à toa.

### Mudou para quem usa

**Estado da proteção**
- **Corrigido: "Nenhum ponto de atenção" sem ter olhado tudo.** Com o firewall ilegível (módulo de rede ausente), as ameaças ativas sem resposta (Defender ativo) ou o Windows Update sem responder, o resumo dizia "Nenhum ponto de atenção na proteção do PC" e a faixa saía verde. Agora diz "Nenhum ponto de atenção no que foi lido, mas não foi possível consultar o firewall, as ameaças ativas e o Windows Update" (só os que falharam), a faixa fica amarela e, havendo um aviso de verdade, a lacuna vem logo abaixo como informação.
- A linha **Ameaças ativas** passa a aparecer como "Não foi possível consultar" quando o Defender ativo não respondeu (antes a linha simplesmente sumia). Com outro antivírus no lugar, continua sem a linha, porque ali a falta de resposta é esperada. O relatório faz o mesmo.
- O rótulo "Última verificação completa" tinha 27 letras numa coluna de 24: os dois pontos saíam tortos. A coluna ficou larga o bastante.
- O cartão **Proteção** da tela inicial não diz mais "Protegido" quando o firewall (ou as ameaças, com o Defender ativo) não foi lido: diz "Leitura incompleta", em amarelo, sem mexer na nota de saúde.

**Auditoria de segurança**
- **Corrigido: nota A sem ter lido o antivírus.** Os pontos que não puderam ser verificados ficam fora da conta, e com o antivírus, o firewall e o UAC ilegíveis a tela dava "A (100 de 100)" e a faixa verde. Agora a nota vem com "calculada sem N ponto(s) que não puderam ser verificados", uma linha amarela lista quais ficaram de fora e o resultado é "Concluído com ressalvas". O que só informa (BitLocker, Secure Boot) continua não alterando o resultado.
- **Corrigido: Windows 11 antigo contava como "em dia".** Qualquer Windows 11 era "Windows 11, com suporte". Agora as versões 21H2 (compilações 22000 a 22620, fim do suporte em 08/10/2024) e 22H2 (22621 a 22630, 14/10/2025) viram ressalva, com o conselho de atualizar. Versões mais novas só saem de suporte para parte das edições (Home e Pro antes de Enterprise e Education) e o WinForge não lê a edição, então continuam "em dia".

**Atualizar assinaturas**
- **Corrigido: "Assinaturas em dia: ."** Se o Windows não devolvesse a data das assinaturas depois da atualização, a tela dizia "em dia" com o texto vazio e a faixa verde. Agora vira ressalva: "o Windows concluiu a atualização, mas não informou a data das assinaturas".
- Menos consultas ao Windows: a atualização lia o estado do Defender 3 vezes (e a Central de Segurança, via WMI, outras 3); agora lê 2 vezes e não consulta a Central de Segurança enquanto o Defender estiver ativo. A etapa **Verificação de segurança** da Manutenção caiu de 3 leituras e 3 consultas WMI para 2 e 0.

**Verificação rápida, completa e de uma pasta**
- **Corrigido: perguntar antes de conferir.** A Verificação completa perguntava "deseja começar agora?" e **Verificar uma pasta** mostrava os botões e pedia o caminho antes de descobrir que faltava Administrador ou que outro antivírus protegia o PC. Agora a conferência vem primeiro, e sem Administrador ou sem o Defender protegendo nenhuma pergunta é feita.
- **Verificar uma pasta**: o caminho colado entre aspas simples (`'D:\Fotos'`) ou com variáveis como `%USERPROFILE%\Downloads` agora vale; antes dava "Pasta ou arquivo não encontrado".
- Quando o estado do Defender não pode ser lido, a mensagem deixou de afirmar que "os comandos não estão disponíveis neste Windows" (pode ser só o serviço parado) e passou a orientar a conferir em Segurança do Windows.
- A Verificação rápida, a completa e a de uma pasta deixam de consultar a Central de Segurança (WMI) quando o Defender protege o PC.

**Busca**
- Novas palavras levam à tela certa: "criptografia", "secure boot", "senha" e "entrada automática" (Auditoria), "ransomware" e "trojan" (verificações), "pasta suspeita" (Verificar uma pasta) e "quarentena" e "windows security" (Segurança do Windows).

### Estrutura

- `Security`: novos `New-WinForgeSecurityFinding` (os pontos de atenção ganham `Id`), `ConvertTo-WinForgeScanPath` e `Get-WinForgeWindows11Retired`; `Test-WinForgeDefenderReady` devolve também o `Antivirus` lido; `Invoke-WinForgeSignatureUpdate` aceita `-Current`; `Get-WinForgeSecurityGrade` informa `Unverified`; `Get-WinForgeAntivirusStatus` só consulta a Central de Segurança quando o Defender não protege.
- `Navigation`: palavras de busca da página Segurança; cartão Proteção do Início. `Reports`: linha "Ameaças ativas" quando o Defender ativo não responde.

## Build 3.11

Revisão da tela de Diagnóstico: o log de eventos que não pode ser lido deixa de parecer "nenhum evento", os discos sem contadores deixam de prometer "nenhum alerta", e as telas que achavam algo terminam com a faixa certa.

### Mudou para quem usa

**Eventos críticos**
- **Corrigido: "Nenhum evento crítico" quando o log não pôde ser lido.** Qualquer erro do Windows ao ler o log do Sistema (serviço de eventos parado, RPC indisponível, acesso negado) era tratado como "não há eventos" e a faixa saía verde, "Tudo certo". Agora só a resposta "não há eventos" do Windows (reconhecida pelo código do erro e pelo texto, em inglês e em português) vale como lista vazia; qualquer outro erro mostra "Não foi possível ler o log do Sistema: ..." com a orientação de abrir o Visualizador de Eventos, e a faixa fica amarela. O relatório HTML/texto também passa a mostrar "Não foi possível ler esta seção" nesse caso.
- Eventos de causa conhecida (queda de energia, tela azul, erro de disco ou de hardware) agora levam um aviso no alto ("1 grupo de eventos tem causa conhecida") e a faixa amarela; antes a tela terminava sem destaque nenhum. Eventos sem explicação conhecida continuam só listados.
- O resumo por origem e ID ficou bem mais rápido com o log cheio (3.000 eventos sintéticos em poucos grupos, no PowerShell 7: de ~120 ms para ~7 ms; com muitos grupos diferentes, de ~580 ms para ~250 ms); no empate, os eventos mais recentes vêm primeiro.

**Dispositivos com problema**
- **Corrigido: defeito sem destaque.** Com dispositivos em erro, a tela só listava a tabela e terminava sem faixa. Agora mostra "1 dispositivo com problema ativo" / "N dispositivos com problema ativo" e a faixa amarela. Dispositivos desativados de propósito continuam sendo só uma nota.

**Saúde dos discos**
- **Corrigido: "Nenhum alerta para este disco" sem ter lido nada.** Discos USB, virtuais ou lidos sem Administrador não expõem os contadores de confiabilidade (temperatura, desgaste, erros); a tela dizia "nenhum alerta" mesmo assim. Agora diz que o disco não expõe os contadores e que só o estado geral foi avaliado, sem alarme. "Nenhum alerta" só aparece quando os contadores foram lidos. O relatório diz o mesmo ("Healthy, sem contadores de confiabilidade").

**Sobre este PC**
- Se o Windows não responder a nenhuma consulta de hardware (WMI com defeito), a tela avisa no alto que os dados estão incompletos e como tentar resolver, em vez de mostrar só "Não disponível" em tudo.
- Sem placa de vídeo detectada, a seção Vídeo mostra "GPU: Não disponível" em vez de ficar vazia; o espaço entre as placas e antes de "Discos" ficou certo (havia duas linhas em branco).

**Inicialização e energia**
- **Corrigido: Inicialização Rápida "Ativada" com a hibernação desligada.** O valor da Inicialização Rápida continua ligado no Registro mesmo depois de desligar a hibernação, mas ela depende do arquivo de hibernação. Agora a tela diz "Sem efeito: a hibernação está desligada, e a Inicialização Rápida depende dela".

**Saúde da bateria**
- **Corrigido: "0 ciclos".** Muitos notebooks informam 0 ciclos quando o firmware não conta; o relatório do powercfg passava o 0 adiante e a tela dizia que a bateria era nova. Agora 0, valores negativos e ilegíveis aparecem como "Não disponível".
- **Duas baterias do mesmo fabricante** não ficam mais com o mesmo nome (quando o identificador contém o fabricante, o nome é o identificador), e nomes de fabricante com `[ ]` ou `*` deixam de ser lidos como curinga.

**Reinício pendente**
- A tela lia o Registro duas vezes para chegar à mesma conclusão; agora usa os motivos já lidos.

### Estrutura

- `Diagnostics`: novo `Get-WinForgeFastStartupText`; `Get-WinForgeRecentCriticalEvents` devolve lista vazia só para "não há eventos" e lança os outros erros; `ConvertTo-WinForgeEventSummary` agrupa em uma passada; `Get-WinForgeDiskHealth` informa `CountersAvailable`; `New-WinForgeBatteryReading` normaliza os ciclos. A soma da RAM e o tipo de memória não dependem mais de haver módulos de memória na resposta do Windows (máquinas virtuais).
- `Reports`: a linha de saúde do disco no relatório usa `CountersAvailable`.

## Build 3.10

Revisão da tela de Manutenção: o desfecho da Manutenção recomendada passa a refletir as etapas, a página ganha um resumo no alto e a Manutenção agendada e o ponto de restauração deixam de dar falsos avisos.

### Mudou para quem usa

**Manutenção recomendada**
- **Corrigido: o desfecho mostrado ao terminar não vinha das etapas.** A faixa de resultado contava as mensagens de estado da tela: o aviso do preparo ("Salve seu trabalho...") fazia uma manutenção perfeita terminar "Concluído com ressalvas", e uma etapa que falhava mostrava só a última mensagem de erro. Agora o desfecho é o das etapas: *Tudo certo* ("Concluído: 3 etapas executadas e 1 ignorada"), *Concluído com ressalvas* ("1 etapa falhou", "2 terminaram com ressalvas"), *Não foi concluído* (nenhuma etapa funcionou) ou *Cancelado*. Etapas ignoradas não contam como problema.
- **Cancelar termina sempre como *Cancelado*,** no preparo, no perfil, na lista do plano ou ao não confirmar a fase automática, sem aviso sonoro nem barra colorida. Antes o desfecho era deduzido das mensagens da tela e podia sair como sucesso ou falha, conforme a última mensagem escrita.
- **Reinício recusado vira lembrete:** se o Windows ainda precisa reiniciar e você recusa (ou cancela o reinício agendado), a faixa de resultado acrescenta "Reinicie o PC para concluir."
- A tela de Opções da manutenção marca o perfil padrão atual com "(atual)".
- O histórico vazio não promete mais que a Manutenção agendada aparece nele (ela guarda só a última execução, na tela dela).

**Página Manutenção**
- **Resumo no alto:** quando foi a última manutenção ("há 2 dias (16/10/2026 21:40) · 14 etapas"), quais etapas pediram atenção e o perfil padrão (com "o DISM completo roda sempre", se for o caso). Em amarelo quando alguma etapa pediu atenção ou passou de um mês; "ainda não executada" quando nunca rodou. Só lê arquivos pequenos do WinForge, então não atrasa a página, e um arquivo ilegível vira "não foi possível ler" em vez de derrubar a página. Ao voltar de uma manutenção, o resumo já mostra a que acabou de terminar.

**Manutenção agendada**
- **Corrigido: beco sem saída sem Administrador.** O cartão não pedia Administrador, mas a tela sim: no modo padrão da janela (pedir só quando precisa), quem não era Administrador via a tela recusar. O cartão agora tem a marca de Administrador (e a nota "Pede Administrador ao executar"), então a janela oferece reabrir como Administrador.
- **Corrigido: uma exceção na limpeza derrubava o relatório e o registro.** Se a limpeza dos temporários lançava um erro, o relatório não era salvo e a execução ficava sem registro. Agora a falha vira uma parte que falhou ("terminou com ressalvas"), e o relatório e o registro são feitos.
- **Quando nada funciona** (nem a limpeza nem o relatório), a execução termina como *Falhou* e a tarefa sai com erro, que o Agendador de Tarefas mostra; antes era só "ressalva".
- A tela mostra a última execução com o desfecho ("; terminou com ressalvas", "; não funcionou") e o caminho do relatório.

**Ponto de restauração**
- **Já havia um ponto recente deixa de ser ressalva.** O Windows cria no máximo um ponto a cada 24 horas; se existe um de menos de 24 horas, o WinForge diz isso e a etapa fica *Ignorada*, não "Concluído com ressalvas" na Manutenção recomendada nem ponto de atenção no Início. Se a data do ponto não puder ser lida, continua sendo um aviso, como antes.

### Estrutura

- `Maintenance`: novos `Get-WinForgeMaintenanceResult` (o desfecho a partir das etapas) e `Get-WinForgeMaintenancePageStatus` (o resumo). `Invoke-WinForgeMaintenanceClosing` devolve se o reinício ficou pendente. `Get-WinForgeDefaultMaintenanceProfile` substitui três cópias da mesma leitura do perfil padrão.
- `Tweaks`: `ConvertFrom-WinForgeWmiDate` e `Get-WinForgeLatestRestorePointTime` (a data do ponto mais recente).
- `Schedule`: a limpeza e o relatório isolados por `try/catch`; `Failed` quando nada funcionou.
- `Navigation`: `maintenance.schedule` marcado como Administrador.
- `WinForge.Gui.ps1`: `New-GuiPageStatus` desenha o resumo; `Show-GuiListPage` o coloca antes dos cartões.

## Build 3.9

Revisão da tela de Início: uma nota de saúde mais fiel, a janela respondendo enquanto o PC é lido e o botão Atualizar.

### Mudou para quem usa

**Início**
- **Corrigido: "ameaça ativa" que não existia.** Quando o Windows Defender não conseguia responder sobre ameaças (o que acontece com outro antivírus no lugar dele), a nota de saúde contava "1 ameaça ativa" e descontava 30 pontos; a verificação rápida (`-Action Check`) saía com código 2 (crítico) por isso. Agora só uma lista real de ameaças conta.
- **Antivírus que não pôde ser lido** deixa de valer como "nenhum antivírus": vira o aviso "Não foi possível confirmar se há um antivírus ativo" (10 pontos; a verificação rápida sai com 1, atenção). "Nenhum antivírus ativo" (25 pontos, código 2) só aparece quando o Windows diz que ele está desligado.
- **A nota não fica mais verde com um problema grave:** com antivírus ou proteção em tempo real desligados, disco quase cheio ou ameaça ativa (pontos de 20 ou mais), a nota para em 74, "Pede atenção", em amarelo. Antes, só o antivírus desligado dava 75, "Boa", em verde.
- **A janela responde enquanto lê o PC:** a leitura é feita em sete etapas, cada cartão aparece assim que a sua termina e o alto da página mostra o andamento ("Lendo o estado do PC... 3 de 7").
- **Atualizar:** botão no alto do Início (e **F5**) que lê de novo no lugar, sem refazer a página nem voltar a rolagem ao topo; os cartões mantêm o valor antigo até o novo chegar. O alto mostra "Atualizado às 21:40".
- **Voltar ao Início é imediato:** a última leitura fica guardada por 30 segundos. Ela é descartada quando uma ação termina, com **F5** ou com **Atualizar**.
- Quando uma ação termina com você no Início, os cartões são atualizados no lugar (antes a página inteira era refeita e voltava ao topo).
- **Leitor de tela:** o nome de cada cartão passa a incluir o valor ("Disco do sistema: 300 GB livres de 500 GB. Abre: ..."); antes só dizia o rótulo e o destino.
- Um erro no meio da leitura da proteção deixava dois cartões "Proteção" e pontos de atenção pela metade; agora o cartão vira "Não foi possível ler" e nenhum ponto é contado.
- Sem a variável de ambiente `COMPUTERNAME`, o cartão do computador não começa mais com "·": usa o nome da máquina.

### Estrutura

- `Navigation`: `Get-WinForgeHomeStatus` virou a soma de etapas (`Get-WinForgeHomeSteps`, `Read-WinForgeHomeStep` e um leitor por etapa, cada um sem deixar erro escapar); a saída é a mesma de antes. A regra do limite da nota ficou em `Get-WinForgeHealthScore`.
- `WinForge.Gui.ps1`: `Update-GuiHomeFacts` (lia tudo de uma vez) deu lugar a `Start-GuiHomeRead`, `Step-GuiHomeRead`, `Complete-GuiHomeRead`, `Show-GuiHomeResult`, `Request-GuiHomeRefresh` e ao cache (`Get-GuiHomeSnapshot`, `Clear-GuiHomeCache`). `Set-GuiAutomationName` e `Set-GuiDock` substituem as chamadas diretas ao WPF.
- O aviso do Início usa as cores do nível Warn da própria janela, em vez de repetir os valores.

## Build 3.8

Revisão da busca (Ctrl+K) e dos atalhos de teclado da janela: resultados mais certeiros, digitação mais leve e o teclado completo.

### Mudou para quem usa

**Busca**
- **Acha pelo que a pessoa diz, não só pelo nome do item:** "pc lento", "meu pc está lento", "travando", "tela azul", "disco cheio", "internet lenta", "wifi", "ram", "cpu", "vírus", "malware", "formatar", "dark mode". Palavras de ligação ("meu", "está", "para") não atrapalham; "limpar" acha "Limpeza", "iniciar" acha "Inicialização", "programa" acha "programas"; "wifi" acha "Wi-Fi" e "hyperv" acha "Hyper-V". Os ajustes do Windows também têm palavras extras (por exemplo, "noite", "anúncios", "fps").
- **Menos ruído:** palavras de até 4 letras só valem no começo de uma palavra ("ram" não acha mais "programas"), e as palavras-chave nunca valem no meio de outra palavra, o nome inteiro de um item vem em primeiro ("Windows Update", "Saúde da bateria"), uma frase combinada com as palavras-chave sobe ("disco cheio" leva a *Analisar uso de espaço*) e as páginas aparecem quando o nome delas é digitado ("rede", "ajustes do w", "início").
- **Mais leve:** a lista de itens e a de ajustes são montadas uma vez e preparadas logo depois que a janela abre, e os textos não são mais refeitos a cada tecla (de 50–100 ms por tecla para 5–15 ms). A janela espera uma pequena pausa na digitação antes de redesenhar os cartões; o Enter não espera.
- **Teclado:** **Enter** abre o primeiro resultado, que agora aparece com a moldura em destaque; **seta para baixo** leva o foco ao primeiro cartão; **Ctrl+F** também abre a busca. Sem resultado, a tela sugere palavras que funcionam; com muitos, mostra "Mostrando os 30 melhores de N".
- **Ajuste achado na busca:** a página de Ajustes abre com o ajuste destacado e à vista (e abre o grupo **Avançados** quando é o caso).
- **Voltar de uma ação que saiu da busca:** o botão **Voltar** (e o Esc) leva de volta aos resultados, não ao Início; o Esc seguinte limpa a busca e volta à página de onde ela começou. Pedir Administrador no meio de uma busca reabre na página de onde a busca começou.

**Teclas de atalho**
- **Ctrl+1 a Ctrl+9, Ctrl+0, Ctrl+K, Ctrl+F e F5 só valem com a tecla sozinha:** Ctrl+Alt (o AltGr do teclado ABNT2, que digita ¹ ² ³ com AltGr+1/2/3) e Ctrl+Shift não disparam mais nada.
- **Enter com a caixa vazia** depois de um Esc não reabre mais o primeiro resultado da busca anterior.

### Estrutura

- `Navigation`: a busca foi reescrita sobre um índice (`Get-WinForgeSearchIndex`) com pontuação por começo de palavra, palavras de ligação, radical (`Get-WinForgeSearchStem`) e palavras extras por item e por ajuste; as regras das teclas ficam em `Resolve-WinForgeKeyAction` e os dados dos cartões em `Get-WinForgeSearchCardItem`, `Get-WinForgeSearchContext`, `Get-WinForgeSearchSummary`, `Get-WinForgeSearchFocus` e `Get-WinForgeSearchSuggestions`. A tabela de acentos tinha uma letra a mais, e `ç`, `ñ`, `ý` e `ú` eram trocados pela letra errada (a busca ainda funcionava porque o texto digitado e o índice sofriam a mesma troca); corrigida.
- Removidos o estilo `GhostButton` (nunca usado) da janela e a função `Get-WinForgeShortcutNames` (nenhuma tela a chamava).

## Build 3.7

Avaliação da 3.6 página por página (interface, fluxos, possíveis falhas) e as ideias novas que saíram dela.

### Mudou para quem usa

**Janela e fluxos**
- **Faixa de resultado:** ao terminar, a ação mostra se foi OK, terminou com ressalvas ou falhou, e quanto tempo levou. O mesmo desfecho vale no menu de texto. Há **Executar de novo**, **Salvar saída** e **Abrir log**; o botão da barra de tarefas mostra o andamento e, com a janela em segundo plano, pisca ao terminar (barra vermelha se falhou, amarela se houve ressalvas). Ao trocar de página durante uma ação, a **barra de execução** no topo mostra o que está rodando, com **Parar** e **Ver**.
- **Busca (Ctrl+K)** em ações, atalhos e ajustes de qualquer página, com sinônimos; **Ctrl+1 a Ctrl+9** (e Ctrl+0) abrem o Início e as páginas; **F5** atualiza o Início. A janela lembra o tamanho e a posição.
- **Início:** novos cartões (proteção, bateria, manutenção agendada) e a **nota de saúde** de 0 a 100, com cada ponto que a desconta e o botão que o resolve. Os cartões são clicáveis.
- **Modo de Administrador:** a janela agora abre como usuário comum e pede o Administrador só quando uma ação precisar. Quem prefere o comportamento antigo (pedir ao abrir) muda em **Sobre o WinForge > Modo de Administrador**. O menu de texto continua pedindo ao abrir.
- **Parar** agora também pede ao Windows Defender que cancele a verificação em andamento.

**Manutenção**
- **Perfis Rápida, Completa e Profunda.** A Profunda roda sempre o `DISM /RestoreHealth`; **Opções da manutenção** guarda o perfil padrão e se o DISM completo deve rodar sempre.
- **Histórico de manutenções** com tendências (duração, espaço liberado, espaço livre ao fim de cada uma, programas que abrem com o Windows).
- SFC, DISM e CHKDSK passam a ser interpretados sem depender do idioma do Windows (código de saída e padrões em português e inglês).

**Limpeza**
- **Analisar uso de espaço** (só leitura) e **Limpeza personalizada**, em que cada alvo aparece com o tamanho real e só o que for marcado é limpo.

**Segurança**
- **Auditoria de segurança** com **nota de A a F** (antivírus, tempo real, assinaturas, ameaças, firewall, UAC, SmartScreen, atualizações, suporte do Windows, Área de Trabalho Remota, conta Convidado e entrada automática; BitLocker e Secure Boot "só para saber"). Só lê. Um ponto com risco real limita a nota a B e um problema grave a limita a C.

**Atualizações**
- **Instalar atualizações do Windows** dentro do WinForge: procura, deixa escolher, baixa e instala com progresso e com o botão **Parar** à mão.

**Programas**
- **Gerenciar inicialização** (liga e desliga o que abre com o Windows pelo mesmo mecanismo do Gerenciador de Tarefas; nada é apagado).
- **Remover aplicativos do Windows** (lista curta e conhecida; só o que for marcado, para o usuário atual; voltam pela Microsoft Store).
- **Recursos opcionais do Windows** (WSL, Plataforma de Máquina Virtual, Hyper-V, Windows Sandbox, .NET 3.5, Telnet, PowerShell 2.0, SMB 1.0...), com explicação de cada um; o PC pode pedir reinício.
- **Backup antes de formatar** (programas, drivers de terceiros, ajustes e, se quiser, redes Wi-Fi) e **Restaurar a partir de um backup**. Documentos e fotos não são copiados: o `LEIA-ME` do backup lista as pastas.
- Programas essenciais: Python 3.14 e JDK 25. A atualização pelo winget reconhece "nenhuma atualização disponível" pelo código de saída, não pelo texto.

**Rede**
- **Trocar o servidor DNS** (Cloudflare, Google, Quad9 ou automático) guardando o DNS de antes, com **Desfazer a troca de DNS**; se o PC deixar de resolver nomes depois da troca, a ação desfaz sozinha.
- **Relatório de Wi-Fi** (`netsh wlan show wlanreport`), copiado para `Documentos\WinForge`.

**Ajustes do Windows**
- Os **recomendados** agora são só os de baixo impacto (extensões visíveis, sem dicas e sugestões, sem ID de publicidade, sem Game Bar). Os de energia e desempenho (Inicialização Rápida, Alto desempenho, PCI Express, nunca suspender, hibernação) **deixaram de ser recomendados**, ficam em **Avançados** (recolhidos na janela) e não vêm marcados.
- Ajustes novos: ID de publicidade, resultados da web na busca do Iniciar, menu de contexto clássico, Copilot, Widgets, Recall e segundos no relógio.
- **Perfis de ajustes** (Essencial, Trabalho, Jogos e Notebook), **Exportar ajustes aplicados** e **Importar ajustes** (mostra o que vai mudar antes de aplicar).

**Sobre o WinForge e linha de comando**
- **Verificar nova versão:** compara a build instalada com a última release do GitHub e, se você aceitar, baixa o `WinForge.zip` para Downloads e confere o **SHA-256** (`digest` do GitHub ou arquivo `.sha256` do release). Hash diferente apaga o arquivo; sem hash publicado o arquivo fica com um aviso e o hash calculado na tela. O WinForge nunca troca os próprios arquivos.
- **`-Action Check [-Json]`** no `WinForge.Console.ps1`: verificação rápida e só de leitura (nota de saúde e nota de segurança, sem a consulta ao Windows Update). Não pede Administrador, não pergunta nada, não grava log e devolve o **código de saída** 0 (tudo em dia), 1 (atenção), 2 (crítico) ou 3 (não foi possível avaliar). Com `-Json`, escreve só o JSON. O `WinForge-Console.cmd` não pausa nem desbloqueia arquivos nesse modo.
- `WinForge.cmd`: o comentário sobre o Administrador passou a refletir o modo sob demanda.

### Correções

- **Recursos opcionais do Windows:** a pergunta de confirmação usava `$summary?`, que o PowerShell lê como uma variável chamada `summary?`; o resumo do que seria ligado ou desligado saía em branco. Corrigido (`${summary}?`).
- **Instalar atualizações do Windows:** a soma do tamanho a baixar falhava quando todas as atualizações já estavam baixadas e o PowerShell estava em modo estrito.
- **Trocar o DNS:** desfazer com um adaptador do backup que não está mais ativo podia falhar no modo estrito (índice em lista vazia).

### Estrutura

- Módulos novos: `Startup`, `Backup`, `NetworkTools`, `WindowsUpdate`, `WindowsFeatures`, `PreinstalledApps` e `AppUpdate`, todos em `modules/Modules.psd1`.
- Dados novos em `%LOCALAPPDATA%\WinForge`: `maintenance-history.json`, `dns-backup.json` e `settings.json`. Backups, ajustes exportados e relatórios de Wi-Fi vão para `Documentos\WinForge`.
- `Reports`: `Get-WinForgeCheckReport`, `Get-WinForgeCheckLevel`, `Get-WinForgeCheckExitCode`, `ConvertTo-WinForgeCheckJson` e `Show-WinForgeCheckReport`.
- `Navigation`: nota de saúde do Início (`Get-WinForgeHealthScore`, `Get-WinForgeHomeStatus`) e itens novos nas páginas Manutenção, Segurança, Limpeza, Atualizações, Programas, Rede, Ajustes do Windows e Sobre o WinForge.

## Build 3.6

Revisão da 3.5 página por página, a partir de um caso real: o reparo da Manutenção sempre pulava o DISM.

### Mudou para quem usa

- **Reparar o Windows (DISM + SFC) na Manutenção recomendada:** o `DISM /CheckHealth` só lê a marcação de dano que o Windows já gravou. Num PC saudável ele diz "Nenhuma corrupção detectada" e o DISM completo (`/RestoreHealth`), que é demorado, é dispensado de propósito; mas ele diz o mesmo quando há dano que ninguém marcou, e aí o DISM completo nunca rodava. Agora, se o **SFC** achar arquivos que não consegue reparar, o WinForge roda o `DISM /RestoreHealth` e **repete o SFC**. O resumo mostra as três linhas ("SFC (antes do DISM)", DISM e "SFC (depois do DISM)") e o resultado final vem do DISM e da segunda passada; se o DISM falhar, o SFC não é repetido. A mensagem que explicava o pulo agora diz quando o DISM completo ainda pode rodar, e a descrição do item no plano também.
- **Reparo > Reparar o Windows (DISM + SFC)** continua rodando o DISM completo sempre, antes do SFC.
- **Verificar arquivos do sistema (SFC)** sozinho: a tela avisa que, se sobrar algo que ele não consiga reparar, o caminho é **Reparar o Windows (DISM + SFC)**, que corrige a imagem antes.
- **Testar velocidade da internet:** o resultado não aparece mais duas vezes (uma linha "medido" e o quadro "Resultado" com os mesmos números).

### Estrutura

- `Repair`: o resultado do SFC leva o fato `Unrepaired`, que `Invoke-WinForgeDismAndSfc` lê para decidir o DISM de recuperação (nunca o texto da mensagem).
- Removidas `Test-WinForgeNavigation` e `Get-WinForgeShortcutTitle`, funções de conferência que nada no programa chamava.

## Build 3.5

Revisão da 3.4, página por página (nomes, dados mostrados, interação, código, desempenho), com as telas novas lidas como o usuário as vê.

### Mudou para quem usa

- **Estado da proteção:** a parte rápida (antivírus, firewall, ameaças) aparece primeiro e a consulta ao Windows Update, que pode demorar, vem por último, com indicador de atividade e **tempo limite de 90 segundos**. Antes, a tela só mostrava algo depois de tudo pronto e uma consulta travada podia prender o botão Parar. Se o Windows Update não responder, a tela diz "demorou ou está indisponível" em vez de sugerir que não há atualizações. A contagem de atualizações pendentes **não inclui mais as opcionais** (drivers e prévias), que não deixam o PC desprotegido e davam alarme falso.
- **Verificação do Defender:** se a verificação não achou nada novo mas o Defender ainda tem uma ameaça **ativa de antes**, o resultado agora é uma ressalva com o nome dela (na Manutenção também), em vez de "nenhuma ameaça encontrada". A atualização das assinaturas e as verificações mostram a barra de atividade enquanto o Windows trabalha.
- **Verificar uma pasta:** em vez de colar um caminho, você escolhe **Downloads**, **Área de Trabalho** ou **Outra pasta ou arquivo** (aí informa o caminho). Cancelar é o padrão.
- **Exportar relatório:** a descrição lista o que o relatório traz (sistema, hardware, discos, ajustes, eventos, segurança e última manutenção); antes dizia "com tudo acima".
- **Limpeza dos temporários:** se as variáveis do Windows que indicam a pasta não existirem, a ação explica e termina como "falhou", em vez de mostrar um erro técnico em inglês.
- README: nova nota sobre o idioma do Windows (DISM, SFC e CHKDSK são lidos em português e inglês).

### Correções de compatibilidade

- Distribuição: removidos os testes automatizados e o workflow do GitHub Actions; preservadas as funcionalidades do WinForge.
- Host gráfico: a leitura da versão do progresso usa `Volatile.Read` no lugar da API obsoleta, mantendo compatibilidade com Windows PowerShell 5.1 e PowerShell 7.
- Publicação: normalização das quebras de linha do README e da licença para evitar falhas de formatação e avisos do Git.

### Estrutura

- `Core`: `Invoke-WinForgeInBackground` (executa um bloco em outro runspace, com tempo limite, esperando em fatias curtas para o Parar continuar funcionando). Removidas `Get-WinForgeFolderSize` e `Get-WinForgeRegistryDWord`, sem nenhum uso.
- `Security`: `Get-WinForgeSecurityStatus` não consulta mais o Windows Update (a tela o faz à parte, e o relatório nunca esperou por ele); `Select-WinForgeScanTarget`. `Diagnostics`: `Get-WinForgePendingWindowsUpdates` roda a consulta COM em segundo plano. `Cleanup`: `Get-WinForgeWindowsTempPath`.

## Build 3.4

Cinco ideias novas e a verificação do antivírus do Windows na Manutenção.

### Mudou para quem usa

- **Segurança (página nova, entre Diagnóstico e Limpeza):**
  - **Estado da proteção** (só leitura): antivírus ligado ou não (e qual, se for outro que não o Windows Defender), assinaturas em dia, proteção em tempo real, firewall nos três perfis (domínio, privada, pública), ameaças ativas e atualizações do Windows pendentes. O resumo no fim lista os pontos de atenção, do mais importante ao menos, e diz o que fazer em cada um.
  - **Atualizar assinaturas do antivírus**, **Verificação rápida**, **Verificação completa** (avisa que pode levar horas) e **Verificar uma pasta** (você informa o caminho da pasta ou do arquivo). Elas usam o próprio Windows Defender (`Start-MpScan`) e mostram, ao final, as ameaças encontradas e o que o Defender fez com elas. O WinForge **não apaga nem põe nada em quarentena por conta própria**: quem decide é o Defender, e o item **Segurança do Windows** abre o aplicativo do Windows para revisar e agir.
  - Se o Defender não for o antivírus ativo (outro antivírus instalado, Defender desligado por política ou ausente), a verificação **não roda** e a tela explica por quê, em vez de tentar e falhar.
- **Manutenção recomendada:** nova etapa **Verificação de segurança** na fase automática (depois de drivers e antes da otimização da unidade): atualiza as assinaturas e faz a verificação rápida. Aparece no plano como as demais, pode ser desmarcada e mostra no resumo as ameaças encontradas.
- **Antes e depois na Manutenção:** o WinForge registra **o espaço livre no disco do Windows e quantos programas abrem junto com o Windows** antes da revisão manual e de novo no fim, e mostra a comparação (por exemplo, "de 41 GB para 52 GB (+11 GB)") no resumo e no relatório. O relatório também traz a duração da fase automática. Um dado que não pôde ser lido simplesmente não aparece na comparação, em vez de virar uma diferença inventada. Os programas contados são só os que estão ativos, não os desativados no Gerenciador de Tarefas.
- **Restauração do Sistema:** novo item em Manutenção que abre a janela de restauração do Windows, completando o ponto de restauração que já existia.
- **Manutenção agendada (opcional):** novo item em Manutenção. Você escolhe o dia do mês (1, 15 ou 28) e o Windows roda, às 12h, **só o que é seguro**: limpa os temporários do seu usuário e salva o relatório. Não esvazia a Lixeira, não repara o Windows, não atualiza programas e não muda ajustes. A tarefa roda **sem Administrador** (nenhum aviso do Windows em segundo plano) e só com você logado; se o PC estava desligado no dia, roda quando for ligado. **Remover** está na mesma tela, e o item **Agendador de Tarefas** abre o programa do Windows onde a tarefa fica visível (pasta `WinForge`). Nada é agendado sem você pedir.
- **Saúde da bateria** (Diagnóstico, só leitura, para notebooks): carga e situação atuais, capacidade de fábrica, capacidade atual com a carga completa, saúde em porcentagem e ciclos de carga, a partir do relatório do próprio Windows (`powercfg /batteryreport`), com a leitura direta do WMI como alternativa quando o relatório não vem. Em um computador sem bateria, a tela diz isso. O relatório HTML do WinForge ganha a seção **Bateria** em notebooks e a seção **Segurança** em qualquer computador.
- Versão **3.4** em **Sobre o WinForge** e no relatório.

### Estrutura

- Módulos novos: `Security` (estado, verificação, assinaturas, ameaças) e `Schedule` (XML da tarefa, registro, remoção, execução e tela), ambos na lista de `modules/Modules.psd1`.
- `Diagnostics`: leitura da bateria (XML do `powercfg` com WMI como alternativa), `Get-WinForgeStartupItems` e `Get-WinForgePendingWindowsUpdates`.
- `Core`: `Get-WinForgeRegistryValues`; `last-maintenance.json` guarda o instantâneo de antes e de depois (arquivos antigos continuam legíveis; um arquivo corrompido é ignorado).
- `WinForge.Console.ps1` aceita `-Action ScheduledMaintenance`, que é o que a tarefa agendada executa.
- `Navigation`: nova página `security`; os itens `maintenance.restore`, `maintenance.schedule`, `maintenance.task-scheduler` e `diagnostics.battery`; `Shortcuts`: `SystemRestore`, `WindowsSecurity` e `TaskScheduler`.
## Build 3.3

### Mudou para quem usa

- **Ajustes do Windows com chave liga/desliga:** cada ajuste agora é uma chave (ligada = aplicado), com o estado escrito ao lado ("Aplicado", "Padrão" ou "Não identificado"), no lugar do par "estado + botão Aplicar/Desfazer". Ligar aplica e guarda o valor original; desligar desfaz. A chave nunca fica "mentindo": ela mostra sempre o estado real e é relida quando você volta da execução. Ajustes que gastam bateria em notebook continuam pedindo confirmação. As três ações da página (aplicar os recomendados, criar o ponto de restauração, desfazer tudo) continuam sendo botões, porque são ações e não estados.
- Estrutura: `Get-WinForgeTweakSwitchState` (estado da chave, testável sem WPF) e o estilo `SwitchToggle` em `gui/MainWindow.xaml`.

## Build 3.2

Revisão página por página da barra lateral: nomes, ordem, o que cada tela mostra, perguntas, código.

### Mudou para quem usa

- **Uma regra de nomes para todo o programa:** o nome do item no menu é o título que a tela mostra ao abrir (por exemplo, "Reparar o Windows (DISM + SFC)", "Limpar temporários do usuário"); itens que abrem uma janela do Windows têm o nome da própria janela e a descrição começa com "Abre"; os textos dizem "programas", não "software". As mensagens que mandam o usuário para outra tela usam o caminho real do menu ("Limpeza > Esvaziar a Lixeira", "Diagnóstico > Saúde dos discos").
- **Ordem:** Início → Manutenção → Diagnóstico → Limpeza → Reparo → Atualizações → Programas → Rede → Ajustes do Windows, e **Sobre o WinForge** fixo no rodapé da barra lateral (antes era a última página da lista). Cada página vai do que é mais seguro/mais usado ao mais profundo, com o item recomendado em destaque (cartão azulado). O menu de texto segue a mesma tabela e a mesma ordem.
- **Início** mostra o estado do PC antes de você clicar em qualquer coisa: Windows, computador, usuário, disco do sistema (avisa "pouco espaço" abaixo de 10% livres e "espaço crítico" abaixo de 5 GB), reinício pendente e última manutenção ("há 3 dias", "2 etapas com atenção", "já passou de um mês"). Os cartões aparecem como "Lendo..." e são preenchidos em seguida; uma leitura que falhe vira "Não foi possível ler" sem apagar as demais.
- **Sobre o WinForge:** nova tela **Versão e pastas** (versão, onde está instalado, PowerShell, se está como Administrador, pastas de logs e relatórios e quais atalhos já existem); **Criar atalho do WinForge** (nome igual ao título da tela) e a pasta de logs. A barra lateral inteira, rodapé incluído, fica desabilitada enquanto uma ação roda.
- **Manutenção:** os nomes das etapas do plano são os mesmos dos itens do menu; a decisão de pedir reinício passa a ler dados estruturados do resultado de cada etapa (DISM/SFC e CHKDSK avisam por `RebootRequired`) em vez do texto exibido.
- **Diagnóstico:** a lista de discos aplica a mesma regra de espaço do Início e, se algum estiver quase cheio, aponta para a página Limpeza. A leitura de eventos críticos tem limite (diz "pelo menos N" quando o limite é atingido e "e mais N grupo(s)" para o que não coube na lista); as dicas dos eventos citam a tela certa. O título da tela não se repete dentro da janela, que já o mostra no topo.
- **Limpeza:** a Limpeza rápida mostra o **espaço liberado** somado; limpar a pasta Downloads diz quantos itens foram para a Lixeira e quanto espaço ocupam (o espaço só volta ao esvaziar a Lixeira) ou, na exclusão definitiva, quanto foi liberado; esvaziar uma Lixeira que já estava vazia é reconhecido pelo código de erro do Windows, em qualquer idioma.
- **Reparo:** o reparo DISM + SFC e o CHKDSK avisam por dado estruturado quando é preciso reiniciar; as mensagens de resultado mostram o motivo ("concluído com ressalvas: ...").
- **Rede:** redes e firewalls que bloqueiam o ping são comuns; agora, se o ping falha, uma conexão TCP na porta 443 decide, então uma rede saudável deixa de ser tratada como quebrada (e a Manutenção não redefine o Winsock sem motivo). O teste de conectividade conclui em uma frase entre "nada responde" (cabo/Wi-Fi/roteador), "os IPs respondem mas os nomes não" (DNS) e "tudo responde"; o reparo de rede avisa que é preciso reiniciar.
- **Atualizações e Programas:** o texto do winget aponta para os outros itens da página Atualizações (Windows Update, drivers opcionais, Microsoft Store); "Listar programas instalados" aponta para "Programas > Desinstalar programas". Um plano de atualização com ação desconhecida agora é falha, nunca sucesso silencioso.
- **Ajustes do Windows:** em **Aplicar ajustes recomendados**, se o ponto de restauração não puder ser criado o WinForge oferece ativar a Proteção do Sistema e, sem o ponto, **só aplica se você confirmar** (padrão: não). **Desfazer ajustes do WinForge** avisa quando os backups são de ajustes que esta versão não conhece (e não finge desfazer) e mostra o total desfeito; a mensagem de "Ajuste aplicado" explica como desfazer.

### Estrutura

- `Core`: `Get-WinForgeSystemDriveSpace` e `Test-WinForgeDnsResolution`; `Get-WinForgeDiskSpaceLevel` deixou de ler um valor inválido como "0 bytes livres" (o `TryParse` zera a saída quando falha).
- `Console`: `New-WinForgeResult` ganhou `-Data` (fatos para quem decide, como `RebootRequired` e `FreedBytes`), com `Get-WinForgeResultData` e `Test-WinForgeResultFlag`.
- `Navigation`: os fatos da tela inicial vêm de `Get-WinForgeHomeStatus` (testável, sem WPF); `Launcher`: `Show-WinForgeAbout`; `Tweaks`: `Request-WinForgeRestorePoint` (ponto de restauração + oferta de ativar a proteção) compartilhado pelas telas.
- Código removido ou unificado: leituras de disco/reinício/manutenção que estavam repetidas na janela, uma atribuição sem uso na Manutenção, `LogsButton` (agora é um item da tabela), título duplicado na janela.

## Build 3.1

Ícone próprio e atalho na Área de Trabalho.

### Mudou para quem usa

- **Ícone do WinForge** (uma bigorna com uma faísca, no azul da janela) em sete tamanhos, de 16 a 256 px: aparece na barra de título, na barra de tarefas, no Alt+Tab e na barra lateral. Antes a janela mostrava um "W" desenhado na hora.
- O WinForge ganha **identidade própria na barra de tarefas**: o botão não se mistura mais com outras janelas do PowerShell e o "Fixar na barra de tarefas" abre o WinForge, com o ícone dele.
- **Criar atalho:** nova página **WinForge** (a última da barra lateral) com o botão que cria o atalho com o ícone na Área de Trabalho, no Menu Iniciar ou nos dois. Se o atalho já existir, é atualizado.
- `WinForge-Console.cmd -Action Shortcut` cria o atalho na Área de Trabalho sem abrir a janela e sem pedir Administrador.
- A pasta de logs e relatórios também está na nova página (e, portanto, no menu de texto).
- O WinForge confere o arquivo do ícone (vazio, cortado ou que não é ícone vira "sem ícone") e confere se o atalho realmente apareceu depois de gravar (a proteção contra ransomware do Windows pode bloquear a Área de Trabalho sem avisar).

### Estrutura

- Novos módulos: `Shell` (COM e API do shell: gravar `.lnk`, pastas especiais, AppUserModelID) e `Launcher` (o que o atalho executa e onde é criado). Novos arquivos `assets/WinForge.ico` e `assets/WinForge.svg` (fonte editável).

## Build 3.0

Reorganização completa do projeto. A interface com janela passa a ser a principal; o terminal continua disponível.

### Mudou para quem usa

- `WinForge.cmd` agora abre a **janela**; o menu de texto passou para `WinForge-Console.cmd`.
- Tudo acontece dentro da janela: perguntas viram botões (Sim/Não, Continuar, opções) e listas de marcação; só texto livre usa a caixa de texto. Nenhum terminal aparece.
- Barra de título escura, barra de progresso para DISM/SFC/winget e progresso na barra de tarefas.
- **Nova ordem do menu lateral:** Manutenção → Diagnóstico → Limpeza → Reparo → Atualizações → Programas → Rede → Ajustes (olhar, limpar, consertar, atualizar, instalar, conferir a rede, personalizar). A mesma ordem vale no menu de texto.
- **Nova ordem da Manutenção recomendada:** uma única lista na ordem de execução; revisão manual antes (inicialização, aplicativos, Programas e Recursos, Downloads), automática (ponto de restauração → rede → limpeza → DISM + SFC → CHKDSK → winget → drivers → otimização → ajustes) e revisão manual depois (armazenamento, Windows Update, opcionais/drivers, Store).
- A Manutenção recomendada agora **avisa quando o notebook está na bateria** (pergunta antes de continuar) e quando o **disco do Windows está quase cheio**.
- Na janela, a confirmação da fase automática é um botão deliberado; no console continua sendo a palavra `WINFORGE`.
- Botão **Parar** também encerra o programa externo em execução (DISM, SFC, CHKDSK, winget, defrag, powercfg...).

### Correções

- `Pasta Downloads`: uma lista vazia/nula virava um item nulo no filtro por idade; o caminho de Downloads dependia de `USERPROFILE`.
- `Limpeza`: trava de segurança que recusa uma variável TEMP apontando para a raiz do disco, o perfil, o Windows ou Arquivos de Programas.
- `Relatório`: o tempo ligado com data de boot nula derrubava o relatório inteiro; cada seção agora falha isoladamente.
- `Dispositivos com problema`: dispositivos de software com estado "Unknown" e sem código de problema deixam de aparecer como defeito.
- `Teste de ping`: filtro robusto a respostas sem status.
- `Test-WinForgeAdministrator` não lança mais erro fora do Windows.
- Argumentos de linha de comando com aspas e barras invertidas passam a seguir as regras do Windows (`CommandLineToArgvW`).
- Tela do host gráfico: sequências ANSI e de título de janela (OSC), NUL e retornos de carro isolados são tratados.
- Janela: se a tela de execução falhar no meio de uma ação, a ação é interrompida e a janela volta ao estado normal (antes podia ficar uma ação "zumbi" rodando por trás).
- Perguntas: opções passadas em formatos diferentes (tabela de hash com chaves opcionais ou objeto) são normalizadas em um único lugar (`ConvertTo-WinForgeOptionList`); chaves ausentes não quebram mais.
- O modo janela é consultado só por `Test-WinForgeGuiMode`, que não falha com `Set-StrictMode`.
- Importação dos módulos tolera colchetes no caminho da pasta (o `Import-Module` os lê como curinga), no menu de texto, na janela e na execução das ações.

### Estrutura

- Módulos reorganizados e listados em um único lugar (`modules/Modules.psd1`).
- Tabela única de navegação (`modules/Navigation.psm1`) alimenta a barra lateral e os menus de texto.
- Convenções do projeto: programas nativos só por `Invoke-WinForgeNative`/`Invoke-WinForgeCapture`; `Read-Host` só no módulo Console; resultado de etapa padronizado (`WinForge.Result`); ações com `-Embedded`/`-PassThru`.
- `README.md`, `CHANGELOG.md`, `.editorconfig`, `.gitattributes` e `.gitignore` adicionados/atualizados.

## Builds anteriores

Veja o histórico do repositório.
