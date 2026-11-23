# WinForge 4.0 — segunda revisão dos Programas (R51)

**Data:** 21/11/2026 · **Versão:** Build 4.0 em preparação, depois da R50

**Pedido:** revisar a tela e a função Programas com cinco olhares:
- **Analista de Produto Sênior:** avalia o todo.
- **Engenheiro de Software Sênior:** revisa o código, refatora, segue as boas práticas, tira o que não serve e melhora o desempenho.
- **Designer Sênior, com um Especialista em UX/UI:** revisam a tela, os botões, os textos e os fluxos; o engenheiro aplica.
- **MVP Windows:** confere se os Programas seguem as práticas da Microsoft, se cada função faz da melhor forma o que promete e se é robusta e estável.
- **QA Sênior:** testa tudo o que dá para testar, o óbvio e o que não é; o engenheiro aplica.

**De onde partiu:** a primeira revisão dos Programas (R21) foi antes do desenho novo (R37), da revisão de UX (R38) e das faixas no alto das páginas (R41 a R48). Esta olhou os 13 itens da página e o que eles dividem com outras partes: o desinstalar e a remoção de aplicativos (etapas do Otimizar), o winget (das Atualizações), Reparar o Instalador de Aplicativo (R36) e Gerenciar inicialização (revisto na R43).

**Resultado:** 12 achados, todos corrigidos.

| Olhar | Achados |
|---|---|
| Produto | 3: a restauração sem achar o backup no pendrive, onde o próprio backup o grava; a restauração logo depois de formatar sem caminho para o Instalador de Aplicativo que falta; e a página sem dizer que ele falta, com o reparo escondido |
| Engenharia | 2: o `winget list` lido em quatro lugares, com a leitura guardada só num deles (e duas guardas que não guardavam nada); e o registro do Instalador de Aplicativo preso à tela do reparo |
| Designer e UX/UI | 2: Sim, Não e Confirmar em onze perguntas e listas; e o reinício pedido por um instalador sem a oferta de reiniciar, que os recursos opcionais e as Atualizações já fazem |
| MVP Windows | 2: o Mapas, que a Microsoft tirou da Store, prometendo voltar por ela; e o Paint 3D, também fora da Store, fora da lista |
| QA | 3: o backup numa pasta do disco do Windows tratado como se estivesse num pendrive; a pasta de fora com backups dentro recusada como "não é um backup"; e a reinstalação com um programa que só termina ao reiniciar contada como problema |

Nada rodou num Windows de verdade. A conferência foi feita na nuvem com o Windows simulado da R21 (o winget, os aplicativos, os recursos opcionais, as unidades e as pastas do backup), mais o registro do Instalador de Aplicativo e as letras C: e D: como unidades do PowerShell. O que só um PC mostra entrou no roteiro de conferência (§41).

## Os Programas hoje

A página tem os mesmos 13 itens e, quando falta o Instalador de Aplicativo, a faixa do alto:
1. **Instalar e remover:** Instalar programas essenciais, em destaque ("Escolher programas"); Buscar e instalar programas; Listar programas instalados; Desinstalar programas; Remover aplicativos do Windows; e Reparar o Instalador de Aplicativo, sem linha própria (a faixa do alto, a faixa de quando ele falta e a busca levam a ele).
2. **Inicialização e recursos:** Gerenciar inicialização (a mesma ação do Desempenho); Recursos opcionais do Windows.
3. **Backup e formatação:** Backup antes de formatar; Restaurar a partir de um backup.
4. **Ferramentas do Windows:** Aplicativos instalados, Programas e Recursos e Aplicativos de inicialização, que abrem as telas do Windows.

Recursos opcionais, Backup e Restaurar pedem Administrador e mostram o escudo.

## Analista de Produto

| # | O que estava | Por que importa | Como ficou |
|---|---|---|---|
| P1 | O Backup antes de formatar põe em destaque o pendrive ou o HD externo e grava o backup na raiz dele (`E:\Backup-<PC>-<data>`). A restauração só procurava em Documentos\WinForge\Backups. | Depois de formatar, Documentos está vazio: a lista da restauração vinha sem nenhum backup, e a pessoa tinha de digitar o caminho do pendrive. É justamente o caminho que a própria tela recomenda. | A restauração procura também na raiz de cada unidade fora a do Windows (o pendrive, o HD externo, outra partição) e diz onde cada backup está ("criado em 10/11/2026 18:30 · PC-ANTIGO · Pendrive (E:)"). O mais novo vem em destaque pela data gravada no backup, e não pela da pasta, que muda quando ela é copiada. Sem nenhum backup, a tela pede para conectar o do backup e oferece **Procurar de novo**, em destaque, como a escolha de onde guardar. |
| P2 | Logo depois de formatar, o Instalador de Aplicativo (o winget) costuma ainda não estar registrado. A restauração deixava **Reinstalar os programas** desmarcado, dizendo que ele falta, sem caminho na tela. | Reinstalar os programas é o principal motivo da restauração. O reparo existe (R36), mas fica sem linha na página. | Com programas no backup e sem o winget, a restauração diz o que falta e pergunta "Reparar o Instalador de Aplicativo agora?" (**Reparar** ou **Agora não**). Reparado, diz a versão, e **Reinstalar os programas** vem marcado; sem sucesso, diz o motivo e o que fazer. Elevado com outra conta, não oferece: o registro valeria para essa conta. |
| P3 | Sem o winget, a página parecia normal: a falta só aparecia depois de abrir uma ação, que terminava na faixa "Falta o Instalador de Aplicativo". | Quase todas as ações da página dependem dele, e o reparo não tem linha própria. | A faixa do alto, como nas outras páginas, só quando ele falta: "winget · falta o Instalador de Aplicativo", em amarelo, que abre **Reparar o Instalador de Aplicativo**. Com ele no PC, a página fica como antes. A leitura só procura o comando: nada roda ao abrir a página. |

**Conferido e mantido:**
- **Um destaque só, Instalar programas essenciais,** e as descrições em até 60 letras nos três idiomas.
- **A faixa sem a versão do winget:** saber a versão pede rodar o winget, e a faixa é lida na hora em que a página abre. A versão continua em Reparar o Instalador de Aplicativo.
- **Listar programas instalados só com a conta** e a lista completa nos detalhes técnicos; o botão leva a atualizar quando há versão nova (R21).
- **Gerenciar inicialização aqui e no Desempenho,** com a mesma frase (R43).

## Engenheiro de Software

| # | O que estava | Como ficou |
|---|---|---|
| E1 | O `winget list` (alguns segundos) era chamado e lido em quatro lugares: Listar programas instalados, Desinstalar programas, a marca de "já instalado" das listas de instalar e a conferência depois de desinstalar. Só a marca de "já instalado" guardava a leitura (por 2 minutos). O Backup e os Aplicativos do Windows chamavam `Clear-WinForgeInstalledWingetIdsCache` atrás de um `Get-Command`, como se o módulo dos Programas pudesse faltar, mas ele sempre está carregado. | `Read-WinForgeWingetList` (nova) lê e entende a lista num lugar só, e toda leitura guarda os IDs: Buscar e instalar e os essenciais, logo depois de Listar ou de Desinstalar, não leem de novo. Na bateria, Listar e depois Buscar fazem uma leitura, e não duas. A conferência depois de desinstalar continua lendo na hora e deixa a leitura nova guardada. As duas guardas saíram. |
| E2 | O registro do Instalador de Aplicativo (o `Add-AppxPackage -RegisterByFamilyName`, a conferência da versão, o Histórico e a lista de pacotes preparada de novo) estava dentro da tela Reparar o Instalador de Aplicativo. | `Register-WinForgeWinget` (nova), usada pela tela do reparo, que ficou igual, e pela restauração (P2). |

**Por dentro:**
- **Software.psm1:**
  - `Read-WinForgeWingetList`, `Register-WinForgeWinget`, `Request-WinForgeProgramsRestart` e `Get-WinForgeSoftwarePageStatus` (novas);
  - `Get-WinForgeInstalledWingetIds`, `Get-WinForgeWingetInstalledRows`, `Show-WinForgeInstalledSoftware` e `Uninstall-WinForgeSoftware` pela leitura única; `Repair-WinForgeWinget` pelo registro;
  - `RebootStarted` no 0x8A15010B de `Get-WinForgeWingetExitResult`, juntado por `Invoke-WinForgeWingetPackages`;
  - os botões e o reinício de Buscar, dos essenciais e de Desinstalar.
- **Console.psm1:** `Test-WinForgeNestedAction` (nova): se a ação roda dentro do Otimizar.
- **Backup.psm1:**
  - `Test-WinForgeBackupOnSystemDrive` (nova);
  - `Find-WinForgeBackups` com as unidades, `CreatedAt` e `Where`; `Get-WinForgeBackupChoiceDescription` com onde o backup está; `Read-WinForgeBackupFolder` com a pasta de fora;
  - `Read-WinForgeBackupDestination` com `OnSystemDrive` (saiu `IsDefault`, que nada mais lia);
  - `Restore-WinForgeBackupPrograms` com o reinício; `Restore-WinForgeFromBackup` com Procurar de novo, o reparo, os botões e o reinício;
  - `Clear-WinForgeInstalledWingetIdsCache` direto.
- **PreinstalledApps.psm1:** o Mapas e o Paint 3D; os botões; `Clear-WinForgeInstalledWingetIdsCache` direto.
- **WindowsFeatures.psm1:** os botões.
- **WinForge.Gui.ps1:** a faixa dos Programas.
- **Traduções:** 5.682 textos (30 novos e 3 que saíram de uso). Entraram seis funções (1.318 nos módulos).

## Designer e Especialista em UX/UI

| # | O que estava | Orientação | Como ficou |
|---|---|---|---|
| D1 | Onze perguntas e listas com Sim, Não ou Confirmar: as listas de Buscar e instalar, dos essenciais, dos recursos opcionais, do backup e da restauração; as perguntas de desinstalar, de conferir de novo, de remover aplicativos, de ligar ou desligar recursos, do Wi-Fi num backup no OneDrive e de restaurar. É a UX21 da R38, aplicada nesta página. | Os botões dizem o que fazem, como a Microsoft orienta para as caixas de diálogo. | **Instalar** nas duas listas de instalar; **Desinstalar** e **Cancelar**; **Conferir de novo** e **Deixar como está**; **Remover** e **Cancelar**, com o **Remover** em vermelho quando um aplicativo aposentado (que não volta) está marcado; **Mudar** na lista dos recursos e **Ligar**, **Desligar** ou **Aplicar** na pergunta; **Fazer o backup**; **Incluir** e **Deixar de fora**; **Restaurar**. O lado seguro de cada pergunta não mudou. No menu de texto, as perguntas continuam com S/N. |
| D2 | Um instalador que termina ao reiniciar (o 0x8A150109 do winget, o 3010 do pnputil) deixava a faixa com "Reinicie o PC para concluir.", sem a oferta de reiniciar que os recursos opcionais e as Atualizações fazem. | O mesmo jeito em toda a página. | Instalar programas essenciais, Buscar e instalar, Desinstalar e Restaurar oferecem reiniciar ali mesmo (**Reiniciar agora** ou **Depois**, com o Depois como padrão). Não oferecem quando o próprio instalador já reinicia o PC (o 0x8A15010B, "Your PC will restart to finish installation") nem dentro do Otimizar, que tem o próprio fim. |

**Conferido e mantido:**
- **As perguntas começam no lado seguro** (R21): desinstalar, remover aplicativos e ligar o SMB 1.0 ou o PowerShell 2.0 no Cancelar; restaurar e reparar no verbo, porque a pessoa já escolheu o que fazer.
- **As listas de remover sem Marcar todos,** e a revisão do que vai sair, com a versão, antes de desinstalar.
- **O escudo** nas três ações que pedem Administrador.

## MVP Windows

| # | O que estava | Por que importa | Como ficou |
|---|---|---|---|
| M1 | O Mapas, na lista de Remover aplicativos do Windows, dizia só "Mapas do Windows" e, removido, "Volta pela Microsoft Store, se precisar." | A Microsoft o descontinuou e o tirou da Microsoft Store em julho de 2025 ("It will be removed from the Microsoft Store by July 2025 and will no longer be supported"). | "Mapas do Windows; aposentado pela Microsoft: não volta depois de removido", como os outros aposentados; a confirmação e o Histórico dizem que ele não volta. |
| M2 | O Paint 3D, que vinha no Windows 10, não estava na lista. | A Microsoft o descontinuou em agosto de 2024 e o tirou da Microsoft Store em 4 de novembro de 2024. Quem ainda o tem não acha onde removê-lo. | Na lista, como aposentado ("Desenho em 3D; aposentado pela Microsoft: não volta depois de removido. O Paint de sempre não é afetado"). O Paint de sempre (`Microsoft.Paint`) é outro pacote e continua protegido; o Paint 3D é o `Microsoft.MSPaint`. |

**Conferido**, com as fontes no fim:
- **O Visualizador 3D,** que já dizia ter saído da Store: a Microsoft o tirou em 1º de julho de 2026. Certo.
- **O Windows PowerShell 2.0** continua na lista só quando o Windows o lista: a Microsoft lembra que ele está descontinuado e vai sair numa versão próxima.
- **O registro do Instalador de Aplicativo na restauração** é o mesmo comando do reparo (R36), `Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe`, só para a conta de quem usa o PC.
- **O `winget source update` uma vez por sessão:** o winget atualiza a fonte sozinho quando a usa e ela tem mais de 15 minutos (o padrão de `autoUpdateIntervalInMinutes`). A atualização explícita, na primeira ação de cada sessão, só antecipa isso e avisa quando falha, e ficou.
- **Os códigos do reinício:** 0x8A150109 ("Restart your PC to finish installation") pede o reinício; 0x8A15010B ("Your PC will restart to finish installation") é o instalador reiniciando sozinho.
- **O restante da R21 continua valendo:** a instalação um por vez, pela fonte winget nos essenciais e pela fonte da busca; o desinstalar só pelo desinstalador do programa, conferido na lista; a remoção de aplicativos só para a conta de quem usa; os recursos com `-NoRestart`, a Plataforma de Máquina Virtual junto com o WSL; o backup e o `winget import` com `--ignore-unavailable` e `--ignore-versions`.
- **Robusto:** a busca do backup lê só a raiz das unidades prontas (sem as de rede e de CD), e um `backup.json` ilegível vale pela data da pasta; o reparo na restauração não muda nada quando a pessoa diz Agora não.

## QA Sênior

**Como foi testado:** uma bateria nova dos Programas, 75 conferências em português e 87 em inglês e em espanhol (nos outros dois, mais duas por seção: nenhum texto e nenhuma palavra solta em português na tela).
- **A restauração acha o backup (A):** os de Documentos, do pendrive e do HD externo juntos, pela data do backup, com onde está cada um; uma pasta qualquer e uma pasta Backup- sem o backup.json fora da lista; Procurar de novo, antes e depois de conectar o pendrive; as cinco voltas sem nenhum; a raiz do pendrive digitada, com um backup e com dois.
- **O reparo na restauração (B):** Reparar (a versão, o Histórico, os programas marcados), Agora não, o registro que falha, outra conta, um backup sem programas e o winget já no PC; e a tela Reparar o Instalador de Aplicativo, com e sem sucesso.
- **A faixa e a leitura única (C):** a faixa sem e com o winget, e a janela pedindo a faixa; Listar e depois Buscar; Desinstalar e depois os essenciais; a conferência depois de desinstalar; o código.
- **Os botões (D):** as onze perguntas e listas, o vermelho do Remover com um aposentado e sem ele.
- **O reinício (E):** os essenciais e a busca com um instalador que pede reinício, que reinicia sozinho e sem pedido; desinstalar, sozinho e dentro do Otimizar; restaurar com um driver que pede reinício, com um programa que pede, com um que reinicia sozinho e com um que falha.
- **Os aplicativos e o disco do Windows (F):** o Mapas e o Paint 3D no catálogo e na remoção; o Paint de sempre protegido; a unidade do Windows pela letra (C:, D:, um caminho de rede, a raiz de outra unidade); o backup em C:\Backup, em D:\Backup e no pendrive.
- **Os textos** nos três idiomas.

**Achados**

| # | O que estava | Como ficou |
|---|---|---|
| Q1 | No Backup antes de formatar, **Outra pasta** no disco do Windows (C:\Backup) terminava em "Backup salvo. Está em C:\Backup\…. Antes de formatar, copie também as suas pastas pessoais.", a mesma frase do pendrive: quem confiasse nela formataria com o backup no disco que vai ser apagado. Só Documentos pedia para copiar a pasta. | A pasta é conferida pela letra (`Test-WinForgeBackupOnSystemDrive`): no disco do Windows, a tela e a faixa pedem para copiar a pasta para um pendrive ou HD externo antes de formatar, como em Documentos. Documentos levado para outro disco deixa de pedir. |
| Q2 | Na restauração, a pasta de fora com backups dentro (a raiz do pendrive, a pasta Backups) terminava em "a pasta não é um backup do WinForge (falta o arquivo backup.json)". | Com um backup só dentro, é ele que se restaura (a tela mostra a pasta dele); com vários, a faixa diz quantos e o mais novo, para a pessoa informar a pasta de um deles. |
| Q3 | A reinstalação dos programas que terminava com um programa esperando o reinício (o 0x8A150109 do `winget import`) dizia "O winget terminou com problemas: termina na próxima reinicialização." e "Backup restaurado em parte". | "O winget reinstalou os programas da lista; algum termina de instalar quando o PC reiniciar.", sem contar como problema, e o reinício oferecido no fim (D2). |

Os testes também acharam os do produto (P1 a P3), os da engenharia (E1 e E2), os do designer (D1 e D2) e os do MVP (M1 e M2).

**A bateria antiga dos Programas (R21):** os mesmos números da R50 (108, 117 e 117), depois de uma adaptação: a conferência de "nenhum backup encontrado" procurava a frase antiga, que saiu das traduções. Em português passava, porque a frase nova começa igual; em inglês e em espanhol, falhava. Agora procura a frase nova.

**Contra o código de antes (R50):** das 75 conferências, 51 falham, cada uma de uma correção: a restauração achando o backup nas unidades, com o Procurar de novo e a pasta de fora; o reparo na restauração; a faixa; a leitura única do winget e o código; os botões; o reinício; o Mapas e o Paint 3D; o disco do Windows. As 24 que passam conferem o que foi mantido (a tela Reparar o Instalador de Aplicativo, a restauração com o winget no PC, sem programas no backup ou com outra conta, a conferência depois de desinstalar lendo na hora, a instalação sem pedido de reinício e o Otimizar sem a oferta, o backup fora do disco do Windows, o Paint de sempre protegido) e os marcadores de texto.

**37 defeitos de propósito,** e as conferências pegam todos: a restauração sem procurar nas unidades, ordenando pela data da pasta, sem dizer onde está cada backup e sem o Procurar de novo; a pasta de fora com um backup só recusada e, com vários, sem dizer quantos; o reparo na restauração ausente, oferecido com outra conta, no Agora não e sem o Histórico; a faixa com o winget no PC, abrindo outro item e fora da janela; a lista do winget não guardada ou guardada e ignorada; Sim, Não e Confirmar de volta na busca, nos essenciais, no Desinstalar, no Conferir de novo, nos recursos, no backup, no Wi-Fi do OneDrive e na restauração; o Remover nunca e sempre em vermelho; o reinício oferecido quando o instalador já reinicia e dentro do Otimizar, e faltando no Desinstalar e na restauração; a reinstalação com reinício contando como problema; o 0x8A15010B e o lote sem a marca do reinício que já começou; o Mapas voltando pela Store e o Paint 3D fora da lista; a unidade do Windows nunca reconhecida e o backup no C: com a frase do pendrive.

**Nada do que funcionava quebrou:** as baterias das 14 páginas revistas, com os mesmos números da R50 (a dos Programas da R21 depois da adaptação acima; a da Rede da R22 com a mesma conferência antiga do escudo); a das seis funções novas da R36 (257 em cada idioma); a do Início da R40 (115), a da Manutenção da R41 (67), a da Limpeza da R42 (97), a do Desempenho da R43 (94), a do Reparo da R44 (92), a do Diagnóstico da R45 (87), a da Rede da R46 (128) e a do Explorador e da tela de bloqueio da R50 (101) em cada idioma, e a da Segurança da R47 e a das Atualizações da R48 (83, 84 e 84); a da Manutenção da R14 (243, 245 e 250) e a do Início da R13 (241); as mensagens da janela (72 em cada idioma); instalar, atualizar com um clique, o pacote de suporte e o Setup de verdade, da R49 para esta; nenhuma função sem uso (1.536, seis novas). O PSScriptAnalyzer ficou com os mesmos 241 avisos da R49, nenhum novo.

## O que só um PC mostra

Isto entrou no roteiro de conferência (§41):
- **O backup num pendrive, achado pela restauração num Windows recém-instalado,** com o Procurar de novo. A busca nas unidades é a mudança mais sensível desta revisão.
- **A faixa do alto e o reparo na restauração,** num Windows em que o winget ainda não responde.
- **O backup em C:\Backup** e a raiz do pendrive digitada em Outra pasta.
- **O reinício** depois de instalar, desinstalar e restaurar, quando um instalador ou um driver pede.
- **O Paint 3D** num Windows 10 que ainda o tem, e os botões novos nos três idiomas.

## Fontes
- [Deprecated features in the Windows client (Microsoft Learn)](https://learn.microsoft.com/windows/whats-new/deprecated-features): o Paint 3D fora da Microsoft Store desde 4 de novembro de 2024; o Mapas, até julho de 2025; o Visualizador 3D, em 1º de julho de 2026; o Windows PowerShell 2.0 descontinuado.
- [settings command (winget) (Microsoft Learn)](https://learn.microsoft.com/windows/package-manager/winget/settings): `autoUpdateIntervalInMinutes`, padrão 15, conferido só quando a fonte é usada.
- [Troubleshooting Errors with WinGet (FileWave)](https://kb.filewave.com/books/microsoft-windows-package-manager-winget/page/troubleshooting-errors-with-winget): os códigos 0x8A150109 e 0x8A15010B, da tabela de códigos do winget.
- As da R21, da R36 e da R48 continuam valendo: o `winget import`, o Windows Sandbox, o registro do Instalador de Aplicativo e os botões das caixas de diálogo.
