# WinForge 4.0 — segunda revisão das Atualizações (R48)

**Data:** 21/11/2026 · **Versão:** Build 4.0 em preparação, depois da R47

**Pedido:** revisar a tela e a função Atualizações com cinco olhares:
- **Analista de Produto Sênior:** avalia o todo.
- **Engenheiro de Software Sênior:** revisa o código, refatora, segue as boas práticas, tira o que não serve e melhora o desempenho.
- **Designer Sênior, com um Especialista em UX/UI:** revisam a tela, os botões, os textos e os fluxos; o engenheiro aplica.
- **MVP Windows:** confere se as Atualizações seguem as práticas da Microsoft, se cada função faz da melhor forma o que promete e se é robusta e estável.
- **QA Sênior:** testa tudo o que dá para testar, o óbvio e o que não é; o engenheiro aplica.

**De onde partiu:** a primeira revisão das Atualizações (R20) foi antes do desenho novo (R37), da revisão de UX (R38) e das faixas no alto das páginas (R41 a R43). Esta olhou os nove itens da página e o que eles dividem com outras partes: a etapa do Windows Update do Otimizar, a pergunta do reinício pendente (a mesma do Otimizar) e o prazo do suporte do Windows (o mesmo do Início).

**Resultado:** 13 achados, todos corrigidos.

| Olhar | Achados |
|---|---|
| Produto | 2: a página sem a faixa do alto, que as outras já têm; e as atualizações pausadas nas Configurações sem efeito no WinForge, nem no Otimizar, que as instalava sem ninguém olhando |
| Engenharia | 3: a instalação com um runspace próprio (e um `catch` vazio), ao lado das tarefas em segundo plano do Core; o desfecho dos drivers escrito duas vezes; e o Corrigir o Windows Update parando os três serviços um depois do outro |
| Designer e UX/UI | 3: Sim e Não em seis perguntas; o reinício pendente em duas perguntas seguidas, ao contrário do Otimizar; e o resultado dos drivers linha por linha, e o das atualizações numa tabela |
| MVP Windows | 2: o Otimizar baixando atualizações numa conexão limitada, o que o próprio Windows não faz; e a sessão do Windows Update sem o nome do WinForge, como a Microsoft faz no exemplo dela |
| QA | 3: a faixa de uma instalação interrompida no meio ("2 de 2 atualizações instaladas", "; o motivo de cada uma está no resumo."); textos em português nas telas em inglês e em espanhol; e uma falha sem código, sem motivo nenhum no resumo |

Nada rodou num Windows de verdade. A conferência foi feita na nuvem: a busca e a instalação de verdade (os scripts que rodam no outro runspace) com um Windows Update de mentira, e o resto com o Windows simulado (a pausa, a conexão limitada, o reinício pendente, os serviços e o suporte do Windows). O que só um PC mostra entrou no roteiro de conferência (§39).

## As Atualizações hoje

A página continua com os mesmos nove itens, de cima para baixo, e ganhou a faixa do alto:
1. **Windows e drivers:** Instalar atualizações do Windows, em destaque ("Procurar atualizações"); Atualizar drivers; Ferramentas do fabricante; Corrigir o Windows Update.
2. **Programas e aplicativos:** Atualizar programas (winget); Manter programas na versão atual; Atualizar aplicativos da Microsoft Store.
3. **Ferramentas do Windows:** Windows Update e Atualizações opcionais, que abrem as Configurações.

Instalar atualizações, Atualizar drivers e Corrigir o Windows Update pedem Administrador e mostram o escudo.

## Analista de Produto

| # | O que estava | Por que importa | Como ficou |
|---|---|---|---|
| P1 | A Manutenção, a Limpeza, o Desempenho e a Rede têm a faixa do alto, com o que importa da página e o botão para o que resolve. As Atualizações abriam direto na lista. | A pergunta de quem abre as Atualizações é "o meu Windows está em dia?". O prazo do suporte e um Windows Update pausado ou parado numa atualização antiga só apareciam no Início ou depois de procurar. | A faixa mostra a versão e até quando ela recebe atualizações de segurança ("Windows · Windows 11 24H2 · suporte até 13/10/2026"), em amarelo e com o botão para Suporte do Windows quando acaba em breve ou já acabou. Só quando pede atenção, uma segunda linha: "Windows Update · pausado até 05/12/2026", que abre o Windows Update das Configurações, onde se retoma; ou "faltam atualizações de segurança", que abre Instalar atualizações do Windows. São leituras rápidas (o catálogo do WinForge e o Registro), as mesmas do Início, sem consultar o Windows Update. |
| P2 | Pausar as atualizações nas Configurações não mudava nada no WinForge. O Otimizar procurava e instalava as atualizações do mês sem ninguém olhando, mesmo pausadas; Instalar atualizações e Atualizar drivers procuravam sem dizer nada. | Quem pausa quer, de propósito, que nada seja instalado até a data: a Microsoft diz que, pausadas, "Updates that might require a restart won't be downloaded or installed until the pause ends". O Otimizar desfazia essa escolha. | No Otimizar, a etapa do Windows Update nem procura: "As atualizações do Windows estão pausadas até 05/12/2026.", "Para retomar, use Atualizações > Windows Update.", e a etapa fica como ignorada ("pausadas até 05/12/2026"). Em Instalar atualizações e em Atualizar drivers, a tela diz isso e pergunta "Procurar mesmo assim?", com "Procurar mesmo assim" e "Cancelar", no Cancelar; cancelada, a faixa "As atualizações estão pausadas" tem o botão "Abrir o Windows Update". |

**Conferido e mantido:**
- **Um destaque só, Instalar atualizações do Windows,** e as descrições em até 60 letras nos três idiomas.
- **A faixa não consulta o Windows Update:** a busca leva de segundos a minutos, e a faixa é lida na hora em que a página abre. Quantas atualizações faltam continua sendo a resposta de "Procurar atualizações".
- **As ferramentas dos fabricantes** continuam as da Dell, da Lenovo, da HP, da Intel, da NVIDIA e da AMD. Pôr outra marca pede conferir a ferramenta oficial dela; para um fabricante que o WinForge não conhece, a tela manda à página de suporte do modelo e aos drivers do Windows Update.

## Engenheiro de Software

| # | O que estava | Como ficou |
|---|---|---|
| E1 | A instalação (`Invoke-WinForgeUpdateInstall`) montava o próprio runspace e, no fim, pedia para ele parar dentro de um `catch` vazio, ao lado das tarefas em segundo plano que o Core ganhou na R47. | Ela começa pelo `Start-WinForgeInBackground` e larga num `finally`, pelo `Stop-WinForgeInBackground`: terminada, o runspace é liberado; interrompida ou sem resposta, o pedido de parar não espera uma chamada presa. Sem runspace próprio nem `catch` vazio no módulo. |
| E2 | O desfecho dos drivers (a tabela, o Histórico de mudanças, as contas da faixa, o erro no meio, o tempo esgotado) era uma cópia do das atualizações, com cerca de 70 linhas, e já tinha se afastado dela (o resumo linha por linha, o texto de cada resultado refeito à parte). A Store abria a página dentro de um `try` que nunca pegava nada: `Open-WinForgeShortcut` não lança erro. | `Get-WinForgeUpdateRunResult -Drivers` faz os dois, com os textos no masculino para os drivers ("instalado com erros", "não foi baixado") e o Histórico pelo nome do driver. A escolha do reinício pendente virou uma função só, `Read-WinForgePendingRebootChoice`, que o Otimizar também usa; e o prazo do suporte em poucas palavras ("suporte até 13/10/2026"), `Get-WinForgeWindowsSupportShortText`, é o mesmo do Início e da faixa. Os `try` da Store saíram. |
| E3 | O Corrigir o Windows Update parava o Windows Update, o BITS e a Criptografia um depois do outro, esperando cada um parar (até 30 segundos cada). | Os três recebem o pedido juntos (`Stop-WinForgeServices`, nova), e a espera é a do mais lento. Na bateria, com 1,5 segundo para cada serviço parar, o reparo foi de cerca de 5,5 para 2,5 segundos. `Stop-WinForgeService`, que o reparo do Spooler usa, passou a ser o caso de um serviço só. |

**Por dentro:**
- **WindowsUpdate.psm1:**
  - `Get-WinForgeWindowsUpdatePause`, `Get-WinForgeUpdatePauseText`, `Test-WinForgeMeteredUpdateDownload`, `Get-WinForgeUpdatesPageStatus` e `Stop-WinForgeServices` (novas);
  - `Confirm-WinForgeUpdateConditions` (a pausa, a escolha do reinício e os botões; devolve o resultado com que a tela termina), `Invoke-WinForgeUpdateInstall`, `Get-WinForgeUpdateRunResult -Drivers`, `Get-WinForgeUpdateOutcome -Driver`, `Set-WinForgeInstallView`, `Install-WinForgeWindowsUpdates`, `Install-WinForgePendingUpdates`, `Repair-WinForgeWindowsUpdate` e `Stop-WinForgeService`;
  - a sessão com o nome do WinForge e o script da instalação sem frases em português.
- **Drivers.psm1:** `Install-WinForgeDriverUpdates` usa o desfecho das atualizações.
- **Maintenance.psm1:** `Read-WinForgePendingRebootChoice` (nova), usada pelo Otimizar.
- **WindowsSupport.psm1:** `Get-WinForgeWindowsSupportShortText` (nova); **Home.psm1** usa ela.
- **Software.psm1:** a Store sem os `try`; o Instalador de Aplicativo com "Abrir" e "Agora não".
- **WinForge.Gui.ps1:** a faixa da página Atualizações.
- **Traduções:** 5.655 textos (28 novos e 4 que saíram de uso). Entraram sete funções (1.312 nos módulos).

## Designer e Especialista em UX/UI

| # | O que estava | Orientação | Como ficou |
|---|---|---|---|
| D1 | Seis perguntas com Sim e Não: instalar na bateria, "Baixar e instalar 3 atualizações?", a dos drivers, "Corrigir o Windows Update agora?" e, nas duas telas em que o winget falta, "Abrir o Instalador de Aplicativo na Microsoft Store agora?". É a UX21 da revisão de UX, aplicada nesta página. | Os botões dizem o que fazem, como a Microsoft orienta ("Use specific responses to the main instruction or content as button text"). | "Instalar mesmo assim" e "Cancelar"; "Baixar e instalar" (ou "Instalar", com tudo já baixado) e "Cancelar"; "Instalar" e "Cancelar" nos drivers; "Corrigir" e "Cancelar"; "Abrir" e "Agora não". A pergunta nova da pausa já nasce com "Procurar mesmo assim" e "Cancelar". Os padrões não mudaram; no menu de texto, as perguntas continuam com S/N. |
| D2 | Com um reinício pendente, Instalar atualizações, Atualizar drivers e Corrigir o Windows Update perguntavam "Continuar sem reiniciar?" (no Não) e, no Não, "Operação cancelada." e logo outra pergunta: "Reiniciar o Windows agora?". O Otimizar já fazia isso numa escolha só. | Uma pergunta só, com a saída que resolve à mão, igual nas quatro telas. | "Reiniciar antes de atualizar?" (ou "antes de corrigir?"), com "Reiniciar agora" (que diz o que fazer depois e ainda confirma o reinício, no Depois), "Continuar sem reiniciar" e "Cancelar", no Reiniciar agora, como o Otimizar. Com o reinício começando, a tela não diz "cancelada". |
| D3 | O resultado de Atualizar drivers vinha linha por linha ("Intel - Display - 31.0: instalado."); o de Instalar atualizações, na tabela "Resumo". | O mesmo resultado escrito do mesmo jeito. | Os drivers também na tabela "Resumo", com o motivo de cada um na linha dele. |

**Conferido e mantido:**
- **Os ícones, a ordem e os grupos da página,** e o escudo nas três ações que pedem Administrador.
- **As perguntas começam no lado seguro** (R20): instalar na bateria e procurar com as atualizações pausadas no Cancelar; um firmware (BIOS) entre os drivers no Cancelar; instalar o que a pessoa marcou no Instalar.
- **A lista mostra o KB, o tamanho ("até", "já baixada") e para que serve cada driver** ("vídeo: Intel UHD Graphics 620"), com as opcionais e a versão nova do Windows desmarcadas (R20).

## MVP Windows

| # | O que estava | Por que importa | Como ficou |
|---|---|---|---|
| M1 | Numa conexão limitada (um celular roteado, um chip, uma rede marcada como limitada), a etapa do Windows Update do Otimizar avisava do consumo e baixava tudo, sem ninguém olhando. | A Microsoft diz que, numa conexão limitada, "Windows Update will only download priority updates", a menos que a pessoa ligue "Baixar atualizações em conexões limitadas" (ou a política `AllowAutoWindowsUpdateDownloadOverMeteredNetwork`). O Otimizar gastava a franquia que o Windows poupa. | Numa conexão limitada, o Otimizar instala só o que já foi baixado e diz quantas ficaram: "A conexão é limitada (plano de dados): 2 atualizações ficaram para baixar numa conexão sem limite." Sem nada baixado, a etapa fica como ignorada, sem dizer "em dia". Com a chave das Configurações ou a política ligadas (a política decide, quando existe), baixa tudo, com o aviso do consumo. Pedida sozinha, Instalar atualizações continua como antes: o aviso vem antes da confirmação, e a pessoa decide. |
| M2 | A sessão do Windows Update que o WinForge abre não dizia quem era: o histórico do Windows Update guarda, para cada atualização, o programa que a instalou, e o das instaladas pelo WinForge ficava "Unknown". | O exemplo da Microsoft dá um nome à sessão (`updateSession.ClientApplicationID = appName`), e o histórico devolve "Unknown" quando o programa não o diz. | A sessão, na busca e na instalação, leva o nome "WinForge". Num PC, quem lê o histórico (um técnico, o suporte da empresa) sabe o que o WinForge instalou. |

**Conferido**, com as fontes no fim:
- **A pausa (P2):** a situação vem de `PausedQualityStatus`, em `HKLM\SOFTWARE\Microsoft\WindowsUpdate\UpdatePolicy\Settings`, como a Microsoft documenta (1 = pausadas; 0 e 2, sem pausa ou retomadas sozinhas no fim do prazo); a data, de `PauseUpdatesExpiryTime`, que a página das Configurações grava em UTC em `HKLM\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings` (o valor é citado numa resposta do Microsoft Q&A). Sem a situação, a data no futuro basta; uma data que já passou ou ilegível não conta.
- **A pausa vale também para os drivers:** eles chegam pelo mesmo Windows Update, e Atualizar drivers pergunta como Instalar atualizações.
- **O restante da R20 continua valendo:** a busca `IsInstalled=0 and IsHidden=0 and BrowseOnly=0`, com a busca sem o `BrowseOnly` só num Windows que não o conhece; a busca local antes de ir ao Windows Update de novo, na instalação; o reparo com os passos da Microsoft para refazer os componentes, sem os que ela deixa para o fim; as políticas e o Windows Update Medic sem mudanças; a Store pela ponte de gerenciamento só com Administrador.
- **Robusto:** a instalação que não termina não prende a tela (o pedido de parar não espera); um serviço preso no Corrigir não segura os outros e continua sendo dito pelo nome; e nenhuma frase do outro runspace aparece sem tradução.

## QA Sênior

**Como foi testado:** uma bateria nova das Atualizações, 83 conferências em português e 84 em inglês e em espanhol (em português, mais a instalação que não termina, com o prazo de um minuto; nos outros dois, mais duas: nenhum texto e nenhuma palavra solta em português na tela).
- **A busca e a instalação de verdade (A),** com um Windows Update de mentira no outro runspace: as duas instaladas, a faixa e o Histórico; o nome do WinForge na sessão; só o que faltava baixado, depois da busca local; o reinício oferecido; as escolhidas que sumiram da oferta; nada baixado; o erro no meio da leitura dos resultados; e a instalação que não termina, largada no prazo.
- **A pausa (B):** a leitura com a situação e a data (pausada, sem data, retomada sozinha, situação 0, só a data, a data que passou, uma data ilegível, nada); a permissão de baixar numa conexão limitada (a política, a política em 0 com a chave das Configurações ligada, só a chave, nada); Instalar atualizações e Atualizar drivers com a pausa, no Cancelar e em Procurar mesmo assim; o Otimizar com a pausa; e sem pausa.
- **A conexão limitada (C):** o Otimizar com uma parte baixada, sem nada baixado, com a permissão de baixar e sem conexão limitada; e Instalar atualizações pedida sozinha.
- **O reinício pendente e os botões (D):** a escolha nas atualizações (o padrão, Continuar, o reinício começando, Cancelar) e nos drivers; os botões da bateria, da confirmação (com e sem o que baixar) e dos drivers; o Otimizar com a mesma escolha (Continuar, o reinício confirmado e o padrão).
- **Os drivers e os textos (E):** a tabela, o masculino, o que sumiu, o Histórico, a faixa e o reinício; interrompidos no meio, sem resultado nenhum e no tempo esgotado; a falha sem código; o título do resumo; e a interrompida depois de todas certas.
- **O Corrigir o Windows Update (F),** com o tempo de verdade: o cache refeito; os três pedidos de parar juntos; o tempo; os serviços ligados de novo; um serviço preso; e o caso de um serviço só.
- **A faixa (G):** com suporte, acabando, sem suporte, pausado (com o atraso junto), atrasado, sem suporte e atrasado, sem leitura nenhuma; os destinos; a janela; e o prazo em poucas palavras do Início.
- **A página e o código (H)** e **os textos** nos três idiomas.

**Achados**

| # | O que estava | Como ficou |
|---|---|---|
| Q1 | Quando a instalação parava por um erro depois de algumas atualizações já terem resultado (ao ler o resultado das outras), a faixa dizia "2 de 2 atualizações instaladas" e "; o motivo de cada uma está no resumo.", sem motivo no resumo. O mesmo nos drivers. | A faixa diz "A instalação foi interrompida", com o motivo ("Erro 0x80240FFF.") e, quando ele aponta um item do WinForge, o botão. |
| Q2 | Em inglês e em espanhol, quatro textos apareciam em português: o título "Resumo" da tabela de Instalar atualizações; "as atualizações escolhidas não estão mais disponíveis" e "nenhuma das atualizações foi baixada, então nada foi instalado", que o script da instalação escrevia no outro runspace, sem as traduções; e "biometria" e "sensores", na lista dos drivers. | O script diz só o caso, e a frase sai do lado da tela, no idioma dela; o título e os tipos de driver vêm traduzidos. |
| Q3 | Uma atualização que falhava sem código de erro (o resultado 4 do Windows Update, sem o HRESULT) aparecia como "Falhou", sem motivo, e a faixa mandava ver o motivo no resumo. | "o Windows Update não informou o motivo", na linha dela. |

Os testes também acharam os do produto (P1 e P2), os da engenharia (E1 a E3), os do designer (D1 a D3) e os do MVP (M1 e M2).

**A bateria antiga das Atualizações (R20):** duas conferências pediam as duas perguntas seguidas do reinício pendente ("Continuar sem reiniciar?" e "Corrigir sem reiniciar?", no Não) e passaram a pedir a escolha só, no Reiniciar agora; a simulação do reinício passou a valer também dentro da Manutenção, onde a escolha mora agora. Com isso, os mesmos números da R47: 112, 119 e 119.

**Contra o código de antes (R47):** das 54 conferências que chegam a rodar (sem as funções novas, parte das seções B e G nem começa), 31 falham, cada uma de uma correção: o nome na sessão, a faixa da instalação interrompida, a pausa, a conexão limitada no Otimizar, a escolha do reinício pendente e os botões, a tabela dos drivers, a falha sem motivo, os três serviços juntos, a faixa do alto, o prazo curto do suporte e o código. As 23 que passam conferem o que foi mantido (a busca e a instalação de verdade com o Windows Update de mentira, as frases que em português já saíam certas, a instalação que não termina, o Otimizar com a mesma escolha do reinício, os drivers sem resultado e no tempo esgotado, o cache refeito, a página) e os marcadores de texto. Com 1,5 segundo para cada serviço parar, o Corrigir o Windows Update levou cerca de 5,5 segundos no código de antes e 2,5 no de agora.

**45 defeitos de propósito,** e as conferências pegam todos: a sessão sem o nome; as duas frases da instalação sem tradução ou de volta ao português; a instalação esperando o runspace no fim; a interrompida sem a faixa própria ou sem a marca; o Otimizar e as telas ignorando a pausa; a pergunta da pausa no Sim e sem o botão do Windows Update; a pausa retomada contando como pausa, a data em UTC e a data passada; a chave das Configurações por cima da política; o Otimizar baixando numa conexão limitada, ignorando a permissão de baixar, dizendo "em dia" sem nada baixado e avisando do consumo sem nada para baixar; a escolha do reinício no Continuar, o Continuar que não segue, o reinício sem confirmação e o reinício começando como "cancelada"; a bateria, a confirmação e os drivers com Sim e Não; o Otimizar sem o "Restarting" e seguindo sem a resposta; os drivers sem o `-Drivers`, sem o masculino, com o Histórico das atualizações e com os tipos em português; o "Resumo" em português; a falha sem motivo; os serviços um por vez, o pedido só ao primeiro e o preso sumindo da lista; a faixa sem a pausa, o suporte sem destino, o atraso num Windows sem suporte e a janela sem a faixa; o ESU e o fim do suporte sem data; a Store com o `try` de volta; e o Corrigir com Sim e Não. Na primeira rodada, um escapou (a instalação esperando o runspace no fim): a instalação presa da bateria era uma espera que o Parar interrompe; com uma que ele não interrompe, como uma chamada COM presa, ele foi pego.

**Nada do que funcionava quebrou:** as baterias das 14 páginas revistas, com os mesmos números da R47 (a das Atualizações da R20 com 112, 119 e 119, depois da adaptação acima; a da Rede da R22 com a mesma conferência antiga do escudo); a das seis funções novas da R36 (257 em cada idioma); a do Início da R40 (115), a da Manutenção da R41 (67), a da Limpeza da R42 (97), a do Desempenho da R43 (94), a do Reparo da R44 (92), a do Diagnóstico da R45 (87) e a da Rede da R46 (128) em cada idioma, e a da Segurança da R47 (83, 84 e 84), com o tempo das leituras em paralelo; a da Manutenção da R14 (243, 245 e 250), com o Windows Update e a Store do Otimizar, e a do Início da R13 (241), com o prazo do suporte no cartão do Windows; as mensagens da janela (72 em cada idioma); instalar, atualizar com um clique, o pacote de suporte e o Setup de verdade, da R47 para esta; nenhuma função sem uso (1.530, sete novas). O PSScriptAnalyzer ficou com 241 avisos, um a menos que na R47 (o `catch` vazio da instalação), e nenhum novo.

## O que só um PC mostra

Isto entrou no roteiro de conferência (§39):
- **A faixa do alto** das Atualizações, nos temas claro e escuro, e com as atualizações pausadas nas Configurações.
- **A pausa** em Instalar atualizações, em Atualizar drivers e no Otimizar.
- **A conexão limitada** no Otimizar, com e sem "Baixar atualizações em conexões limitadas".
- **O nome do WinForge** no histórico do Windows Update, depois de instalar uma atualização por aqui.
- **A escolha do reinício pendente** nas três telas.
- **O Corrigir o Windows Update** num PC sem problema, com os segundos anotados.
- **O resumo dos drivers** na tabela, e os botões novos nos três idiomas.

## Fontes
- [Pause updates in Windows](https://support.microsoft.com/windows/manage-updates-in-windows-643e9ea7-3cf6-7da6-a25c-95d4f7f099fe) (Microsoft): pausadas, "Updates that might require a restart won't be downloaded or installed until the pause ends."; a pausa vai até 35 dias.
- [Configure Windows Update client policies](https://learn.microsoft.com/en-us/windows/deployment/update/waas-configure-wufb) (Microsoft): `PausedQualityStatus` em `HKLM\SOFTWARE\Microsoft\WindowsUpdate\UpdatePolicy\Settings`, com 0 (não pausadas), 1 (pausadas) e 2 (retomadas sozinhas depois da pausa).
- [Pausing windows update using powershell](https://learn.microsoft.com/en-us/answers/questions/1287073/pausing-windows-update-using-powershell) (Microsoft Q&A, resposta da comunidade): `PauseUpdatesExpiryTime` em `HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings`, no formato `yyyy-MM-ddTHH:mm:ssZ` (UTC).
- [Metered connections in Windows](https://support.microsoft.com/en-us/windows/metered-connections-in-windows-7b33928f-a144-b265-97b6-f2e95a87c408) (Microsoft): numa conexão limitada, "Windows Update will only download priority updates", e a opção de baixar as atualizações nela, em Windows Update > Opções avançadas.
- [Policy CSP - Update](https://learn.microsoft.com/windows/client-management/mdm/policy-csp-update) (Microsoft): `AllowAutoWindowsUpdateDownloadOverMeteredNetwork`, "automatically download updates, even over metered data connections", na chave `Software\Policies\Microsoft\Windows\WindowsUpdate`, e "accessible through the Update setting in the user interface or Group Policy".
- [Searching, Downloading, and Installing Updates](https://learn.microsoft.com/en-us/windows/win32/wua_sdk/searching--downloading--and-installing-updates) (Microsoft): o exemplo da API do Windows Update, com `updateSession.ClientApplicationID = appName`.
- [IUpdateHistoryEntry::get_ClientApplicationID](https://learn.microsoft.com/en-us/windows/desktop/api/wuapi/nf-wuapi-iupdatehistoryentry-get_clientapplicationid) (Microsoft): "Gets the identifier of the client application that processed an update." e "Returns the Unknown value if the client application has not set the property."
- [Dialog controls](https://learn.microsoft.com/windows/apps/design/controls/dialogs-and-flyouts/dialogs) (Microsoft): "Use specific responses to the main instruction or content as button text".
