# Changelog

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
