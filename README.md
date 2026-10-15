<p align="center"><img src="assets/WinForge.svg" width="96" height="96" alt="Ícone do WinForge"></p>

# WinForge

**Build 3.5** — manutenção, reparo, limpeza, atualização, segurança e diagnóstico do Windows 10/11 em uma janela só (ou no terminal).

O WinForge reúne o que normalmente exige dez janelas e vinte comandos: um fluxo guiado de **Manutenção recomendada** (com verificação do antivírus e comparação antes e depois), diagnósticos de hardware e da bateria, a **Segurança** do Windows (estado da proteção e verificações do Windows Defender), limpeza segura, reparos (DISM, SFC, CHKDSK), atualizações (Windows, drivers, Microsoft Store, winget), instalação de programas, ferramentas de rede, **ajustes reversíveis** com backup do valor original e uma **manutenção mensal agendada** opcional.

## Download

**[Baixar WinForge — versão mais recente](https://github.com/guilhermehenn/winforge/releases/latest/download/WinForge.zip)**

[Ver todas as releases](https://github.com/guilhermehenn/winforge/releases) · Download oficial pelo GitHub.

## Requisitos

- Windows 10 ou Windows 11
- Windows PowerShell 5.1 (já vem no Windows) ou PowerShell 7
- Permissão de Administrador (o WinForge pede sozinho)
- Winget (App Installer) apenas para os recursos de programas

## Como usar

1. Baixe o `WinForge.zip`.
2. Clique com o botão direito no arquivo > **Propriedades** > marque **Desbloquear**, se a opção aparecer.
3. Extraia **a pasta inteira**, de preferência em um caminho simples como `C:\WinForge` (evite pastas de rede mapeadas e nomes com colchetes).
4. Abra **`WinForge.cmd`** e aceite o aviso do Windows (Controle de Conta de Usuário).

| Arquivo | O que abre |
| --- | --- |
| `WinForge.cmd` | A **janela** (interface gráfica). Nenhum terminal aparece. |
| `WinForge-Console.cmd` | O **menu de texto** no terminal. Aceita `-Action Report`, `-ReportDirectory` e `-Action Shortcut`. |

```powershell
.\WinForge-Console.cmd -Action Report                              # gera o relatório sem abrir o menu
.\WinForge-Console.cmd -Action Report -ReportDirectory "D:\Relatorios"
.\WinForge-Console.cmd -Action Shortcut                            # cria o atalho com ícone na Área de Trabalho
```

### Ícone e atalho na Área de Trabalho

Arquivos `.cmd` não aceitam ícone próprio; um **atalho** aceita. Para ter o WinForge com o ícone dele na Área de Trabalho:

1. Abra o WinForge e entre em **Sobre o WinForge**, no rodapé da barra lateral.
2. Clique em **Criar atalho do WinForge** e escolha **Área de Trabalho**, **Menu Iniciar** ou os dois. Rodar de novo atualiza o atalho existente.

Sem abrir a janela, `.\WinForge-Console.cmd -Action Shortcut` cria o atalho na Área de Trabalho do usuário atual.

- O atalho abre a janela sem terminal (a mesma linha do `WinForge.cmd`) e pede o aviso do Windows (Controle de Conta de Usuário) como de costume.
- A janela e o botão na barra de tarefas também usam o ícone, com identidade própria (não se misturam com outras janelas do PowerShell). Para fixar na barra: botão direito no atalho > **Fixar na barra de tarefas**.
- Se você **mover a pasta** do WinForge, crie o atalho de novo.

## A janela

A barra lateral tem as páginas na ordem em que costumam ser úteis: **Início → Manutenção → Diagnóstico → Segurança → Limpeza → Reparo → Atualizações → Programas → Rede → Ajustes do Windows**; no rodapé fica **Sobre o WinForge** (versão e pastas, atalho com ícone, pasta de logs). O nome de cada item é o título da tela que ele abre. O **Início** mostra o estado do PC (Windows, computador, usuário, disco do sistema, reinício pendente e última manutenção) e os quatro atalhos mais procurados.

- As ações rodam **dentro da janela**, com a saída colorida e uma barra de progresso para DISM, SFC, winget e semelhantes.
- Toda pergunta vira controle na tela: **Sim/Não**, **Continuar**, botões de opção e **listas de marcação** (com "marcar todos" e contador). Só perguntas de texto livre (termo de busca, ID de pacote) usam a caixa de texto.
- **Parar** interrompe a ação e também o programa externo em uso (DISM, SFC, CHKDSK, winget...). **Copiar saída** e **Voltar** ficam sempre à mão.
- Os **ajustes** são chaves liga/desliga (ligar aplica e guarda o valor original; desligar desfaz); o que o Windows já oferece em janela própria (Windows Update, Gerenciador de Dispositivos etc.) abre direto.

## Manutenção recomendada

Você decide tudo no começo; depois o WinForge trabalha sem novas perguntas e mostra um resumo com a duração de cada etapa.

1. **Preparação** — confere o Administrador, avisa de reinício pendente, de notebook na bateria e de pouco espaço no disco do Windows, e pede a confirmação para começar.
2. **Plano** — uma lista única, na ordem de execução; desmarque o que não quiser.
3. **Revisão manual (antes)** — aplicativos de inicialização, aplicativos instalados, Programas e Recursos e a pasta Downloads. É o momento de enxugar o PC; o WinForge só abre as janelas e espera você.
4. **Escolhas** — o que atualizar no winget e quais ajustes aplicar.
5. **Fase automática** — só começa depois da sua confirmação, nesta ordem: ponto de restauração → reparo de rede (só se o ping ou o DNS falharem) → limpeza → DISM + SFC (o DISM só repara se houver dano) → CHKDSK online → winget → detecção de dispositivos e drivers → **verificação de segurança** → otimização da unidade → ajustes.
6. **Revisão manual (depois)** — armazenamento, Windows Update, atualizações opcionais/drivers e Microsoft Store. Ficam por último para não competir com os reparos.
7. **Encerramento** — oferta de reparo offline do disco (se o CHKDSK pedir), relatório e reinício, se necessário. O WinForge nunca reinicia o PC sem a sua confirmação.

Durante a fase automática o WinForge impede o Windows de suspender o PC e, na janela, mostra o progresso na barra de tarefas.

**Antes e depois:** o WinForge anota o espaço livre no disco do Windows e quantos programas abrem junto com o Windows antes da revisão manual e de novo no fim, e mostra a diferença no resumo e no relatório (junto com a duração da fase automática). Um dado que não pôde ser lido não entra na comparação.

**Rede de segurança:** o item **Restauração do Sistema** (página Manutenção) abre a janela do Windows para voltar a um ponto de restauração, completando o item que cria o ponto.

## Segurança do Windows

A página **Segurança** responde ao que as pessoas mais querem saber e roda as verificações do próprio Windows Defender:

- **Estado da proteção** (só leitura): antivírus ligado ou não, assinaturas em dia, proteção em tempo real, firewall nos três perfis, ameaças ativas e atualizações do Windows pendentes, com um resumo dos pontos de atenção. O que é rápido aparece primeiro; a consulta ao Windows Update, que pode demorar, vem por último, com tempo limite de 90 segundos, e não conta as atualizações opcionais (drivers e prévias).
- **Atualizar assinaturas**, **Verificação rápida**, **Verificação completa** (pode levar horas) e **Verificar uma pasta** (Downloads, Área de Trabalho ou outro caminho): usam o Windows Defender e mostram as ameaças encontradas, inclusive as de antes que ainda estão ativas. O WinForge não apaga nem isola nada sozinho; o que fazer com cada ameaça é decisão do Defender e sua, em **Segurança do Windows** (o último item da página abre o aplicativo).
- Se o Defender não é o antivírus ativo (outro antivírus instalado, Defender desligado por política ou ausente), as verificações não rodam e a tela explica o motivo.
- A **Manutenção recomendada** inclui a etapa **Verificação de segurança** (atualiza as assinaturas e faz a verificação rápida), que você pode desmarcar no plano.

O relatório HTML também traz a seção **Segurança** e, em notebooks, a seção **Bateria** (capacidade de fábrica, capacidade atual, saúde e ciclos; também disponível em **Diagnóstico > Saúde da bateria**).

## Manutenção agendada (opcional)

Em **Manutenção > Manutenção agendada** você pode pedir ao Windows uma tarefa mensal (dia 1, 15 ou 28, às 12h) que faz **só o que é seguro**: limpa os temporários do seu usuário e salva o relatório. Ela **não** esvazia a Lixeira, repara o Windows, atualiza programas nem muda ajustes.

- **Nada é agendado sem você pedir.** Para remover: a mesma tela, **Remover o agendamento**. A tarefa também fica visível no **Agendador de Tarefas** (item da própria página), na pasta `WinForge`.
- Roda **sem Administrador** e só com o seu usuário logado; se o PC estava desligado no dia, executa quando for ligado. Como roda sem privilégios, não limpa os temporários do Windows (só os seus).
- A tarefa executa `WinForge.Console.ps1 -Action ScheduledMaintenance` a partir da pasta onde o WinForge está; **se você mover a pasta, agende de novo**. O registro da última execução fica em `%LOCALAPPDATA%\WinForge\scheduled-maintenance.json`.

## Segurança

- **Reversível:** cada ajuste guarda o valor original em `%LOCALAPPDATA%\WinForge\tweak-backup.json`; é possível reverter um ajuste ou todos de uma vez.
- **Ponto de restauração** antes de mudanças relevantes. O Windows cria no máximo um a cada 24 horas; o WinForge confere se ele realmente existe e avisa quando não foi criado.
- **Limpeza conservadora:** só temporários, Lixeira e componentes do Windows. A pasta Downloads exige prévia, envia para a Lixeira por padrão e pede dupla confirmação para excluir de vez. Uma variável TEMP apontando para a raiz do disco, o perfil ou o Windows é recusada.
- **Sem mudanças silenciosas:** o que altera o sistema aparece na tela antes e depois.
- **Rede:** o WinForge só acessa a internet para o que você pede — winget, o teste de velocidade (`speed.cloudflare.com`) e a consulta do IP público (`api.ipify.org`, avisada na tela).
- **Dados locais** ficam em `%LOCALAPPDATA%\WinForge`: `logs` (os 20 mais recentes), `reports`, `tweak-backup.json`, `last-maintenance.json` e `scheduled-maintenance.json`.
- **Fora dessa pasta** o WinForge cria apenas o `WinForge.lnk` (Área de Trabalho e/ou Menu Iniciar do seu usuário) e a tarefa da Manutenção agendada, e **só quando você pede**.
- **Antivírus:** o WinForge só lê o estado e pede ao Windows Defender que verifique; não desativa proteção, não cria exclusões, não apaga nem põe arquivos em quarentena.

### O Windows bloqueou o arquivo?

Arquivos baixados da internet recebem a marca *Mark of the Web*, que causa avisos do SmartScreen e erros de política de execução.

1. **Antes de extrair:** botão direito no `.zip` > **Propriedades** > **Desbloquear**. Ou, no PowerShell: `Unblock-File .\winforge.zip`.
2. **Depois de extrair:** os dois `.cmd` já executam `Unblock-File` na pasta e usam `-ExecutionPolicy Bypass` só para o próprio processo (a política do sistema não é alterada).
3. Se aparecer "O Windows protegeu o computador": **Mais informações** > **Executar assim mesmo**.
4. Para distribuir sem avisos: assine os scripts com `tools\Sign-WinForge.ps1` (certificado de assinatura de código) e publique o `SHA256SUMS.txt` junto.

### Idioma do Windows

As mensagens do DISM, do SFC e do CHKDSK são lidas em texto; o WinForge reconhece Windows em **português e em inglês**. Em outro idioma, um resultado que depende do texto (por exemplo, o SFC avisar que não conseguiu reparar um arquivo) pode aparecer só como "concluído". Nesses casos vale conferir o `CBS.log`.

### Console sem Unicode

Defina `WINFORGE_ASCII=1` para usar apenas caracteres ASCII nos quadros e barras.

## Estrutura do projeto

```text
WinForge.cmd              abre a janela
WinForge-Console.cmd      abre o menu de texto
WinForge.Gui.ps1          janela (WPF): reabre como Administrador/STA, monta a barra lateral e os cartões
WinForge.Console.ps1      menu de texto, relatório e atalho pela linha de comando
gui/MainWindow.xaml       aparência da janela
assets/WinForge.ico       ícone da janela, da barra de tarefas e do atalho (16 a 256 px)
assets/WinForge.svg       fonte editável do ícone
modules/Modules.psd1      lista dos módulos (um lugar só)
modules/Core.psm1         ambiente, log, formatação, execução de programas nativos
modules/Console.psm1      cabeçalhos, status e perguntas (Read-WinForgeChoice, Confirm-WinForgeAction...)
modules/Navigation.psm1   a tabela de páginas e ações que alimenta a janela E os menus
modules/Menus.psm1        menus de texto
modules/GuiHost.psm1      ponte entre as ações e a janela (host próprio; perguntas viram botões)
modules/Shell.psm1        integração com o shell do Windows (criar .lnk, identidade na barra de tarefas)
modules/Launcher.psm1     o que o atalho executa, onde é criado e a ação "Criar atalho"
modules/*.psm1            ações: Cleanup, Repair, Software, Network, Diagnostics, Hardware, Security,
                          Reports, Tweaks, Maintenance, Schedule, Shortcuts
tests/                    testes (Pester 5) e verificações estáticas do projeto
tools/Sign-WinForge.ps1   assinatura dos scripts e SHA256SUMS.txt
```

Convenções que os testes verificam: programas nativos só são chamados por `Invoke-WinForgeNative`/`Invoke-WinForgeCapture`; só o módulo Console usa `Read-Host`; ações aceitam `-Embedded`/`-PassThru` para rodar dentro de um fluxo; páginas e ações existem em uma única tabela (`Navigation.psm1`).

## Testes

```powershell
.\tests\Run-Tests.ps1                 # tudo
.\tests\Run-Tests.ps1 -Name Core      # só os arquivos cujo nome contém "Core"
.\tests\Run-Tests.ps1 -Strict         # módulos com Set-StrictMode -Version Latest (acha variáveis e propriedades inexistentes)
```

Requer Pester 5 (`Install-Module Pester -MinimumVersion 5.0 -Scope CurrentUser -SkipPublisherCheck`). Os testes não alteram o sistema: os dados vão para uma pasta temporária e os pontos de contato com o Windows são substituídos por funções de teste. O CI (`.github/workflows/ci.yml`) roda os testes no Windows PowerShell 5.1 e no PowerShell 7, os testes em modo estrito e o PSScriptAnalyzer, em `windows-latest`.

O que **não** é coberto por testes automáticos: a aparência real da janela WPF (incluindo o ícone na barra de tarefas e o "Fixar"), a saída de DISM/SFC/CHKDSK/winget em cada versão do Windows, pontos de restauração, o encerramento de programas filhos pelo botão Parar, as respostas reais do Windows Defender (`Get-MpComputerStatus`, `Start-MpScan`), o formato do relatório de bateria do `powercfg` e o registro da tarefa no Agendador de Tarefas. A gravação de um atalho de verdade é testada só no Windows (CI). Vale um teste manual em uma máquina de teste a cada mudança nessas áreas.

## Licença

GPL-3.0 — veja `LICENSE`.
