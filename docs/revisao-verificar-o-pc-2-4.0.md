# WinForge 4.0 — segunda revisão do Verificar o PC (R56)

**Data:** 22/11/2026 · **Versão:** Build 4.0 em preparação, depois da R55

**Pedido:** revisar a tela e a função Verificar o PC com cinco olhares:
- **Analista de Produto Sênior:** avalia o todo.
- **Engenheiro de Software Sênior:** revisa o código, refatora, segue as boas práticas, tira o que não serve e melhora o desempenho.
- **Designer Sênior, com um Especialista em UX/UI:** revisam a tela, os botões, os textos e os fluxos; o engenheiro aplica.
- **MVP Windows:** confere se o Verificar o PC segue as práticas da Microsoft, se cada etapa faz da melhor forma o que promete e se é robusto e estável.
- **QA Sênior:** testa tudo o que dá para testar, o óbvio e o que não é; o engenheiro aplica.

**De onde partiu:** a primeira revisão (R27) foi antes de quatro mudanças que tocam nas etapas dele: a página Atualizações passou a dizer quando o Windows Update está pausado (R48); a página Programas ganhou o reparo do Instalador de Aplicativo, com a faixa do alto levando a ele (R36 e R51); o Gerenciar inicialização passou a morar no Desempenho (R43); e as segundas revisões das páginas trouxeram as faixas que levam ao que resolve. O Verificar o PC abre de quatro lugares: o botão da nota do Início, a linha da página Manutenção, o menu do monitor na bandeja e o aviso "Hora de cuidar do PC".

**Resultado:** 10 achados, todos corrigidos.

| Olhar | Achados |
|---|---|
| Produto | 2: com o Windows Update pausado, o ponto mandava instalar as atualizações; e sem o winget, uma linha cinza sem caminho para o reparo |
| Engenharia | 2: a consulta do winget, a etapa mais demorada, rodando sozinha no meio da verificação; e o que não servia (um parâmetro sem uso, leituras repetidas e uma orientação que nunca aparecia) |
| Designer e UX/UI | 2: a inicialização levando a Programas, e não ao Desempenho, como a memória; e, sem o winget, a faixa com dois sinais de dois-pontos e o nome errado nas listas |
| MVP Windows | 1: a consulta do winget sem prazo, que podia deixar a verificação parada para sempre |
| QA | 3: dois discos com sinal de falha viravam dois pontos com o mesmo nome; o firewall ou as ameaças sem leitura deixavam a faixa em "Tudo certo"; e atalhos quebrados no OneDrive viravam "nenhum quebrado" |

Nada rodou num Windows de verdade. A conferência foi feita na nuvem, com o Windows simulado da R27 (as pastas de temporários de verdade, apagadas de fato pela correção) e com um winget falso de verdade no caminho do sistema, para a consulta em segundo plano, o prazo e a parada. O que só um PC mostra entrou no roteiro de conferência (§46).

## O Verificar o PC hoje

- **A leitura,** em 11 etapas, com a barra dizendo qual ("7 de 11: procurando programas desatualizados (winget)"). A consulta do winget começa antes de todas e corre junto com as outras; na vez dela, a etapa só recebe a resposta.
- **A lista do que encontrou:** uma linha por etapa (as atualizações do Windows e as assinaturas do antivírus com a delas), em amarelo o que pede atenção.
- **O que fazer com cada ponto sem correção daqui,** uma linha com o caminho ("Memória: feche o que pesa em Desempenho > Programas pesando agora."), que na janela é um link. Uma informação com orientação própria também tem a linha, sem pedir nada.
- **A lista de marcar,** "O que corrigir agora?", com Corrigir e Agora não. O seguro vem marcado (temporários, atalhos quebrados e assinaturas), com a frase do porquê; o cache dos navegadores e o registro, desmarcados.
- **O fim:** o resumo das correções, o espaço liberado, o disco lido de novo e a faixa, com o botão para o ponto mais importante que sobrou.

## Analista de Produto

| # | O que estava | Por que importa | Como ficou |
|---|---|---|---|
| P1 | Com as atualizações do Windows pausadas nas Configurações e as de segurança atrasadas, o ponto dizia "faltam atualizações de segurança" e levava a **Instalar atualizações do Windows**, que abre perguntando "Procurar mesmo assim?". Pausadas e em dia, nada falava da pausa. A página Atualizações já mostrava a pausa na faixa do alto, com o caminho para o Windows Update (R48). | Pausado, o Windows não instala nada até a data. O que resolve é retomar, e isso se faz no Windows Update das Configurações. | Atrasadas e pausadas: "faltam atualizações de segurança; pausadas até 05/12/2026", com "retome as atualizações em Atualizações > Windows Update" e o botão da faixa no **Windows Update**. Em dia e pausadas, a linha diz a pausa como informação: a pausa é uma escolha da pessoa, de até 35 dias. Sem saber o atraso (uma versão fora do catálogo), a linha aparece só com a pausa. |
| P2 | Sem o winget, a linha dizia "não dá para conferir: falta o Instalador de Aplicativo (winget)", em cinza, sem caminho. A faixa dizia "Tudo certo". A página Programas, nesse caso, tem a faixa em amarelo, com o botão para **Reparar o Instalador de Aplicativo** (R51). | Sem o winget, a pessoa nem sabe dos programas desatualizados, e quase tudo da página Programas para de funcionar. O reparo existe e é um clique. | O ponto pede você, com "veja o que fazer em Programas > Reparar o Instalador de Aplicativo" e o botão da faixa no reparo. Não conta como etapa não lida: a leitura funcionou, o que falta é o programa. |

**Conferido e mantido:**
- **O PC ligado há muito tempo não vira um ponto.** A página Desempenho mostra o tempo ligado em amarelo a partir de uma semana, e Tempo ligado e energia explica por que desligar não zera esse tempo (com a Inicialização Rápida, só reiniciar zera). Um ponto aqui pediria você em quase todo PC de quem desliga o PC toda noite, e a nota do Início também não o conta. O reinício pendente continua sendo o ponto.
- **As 11 etapas e a ordem delas,** do disco às telas azuis.
- **O que conta como cuidado com o PC** (o Início e o monitor param de lembrar por um mês): a maior parte das etapas lida e as correções seguras nem recusadas nem todas falhando.

**Para depois:** o monitor na bandeja e a faixa da página Programas também consultam o winget sem prazo. As revisões deles (R54 e R51) já passaram; vale levar o mesmo prazo para lá numa próxima.

## Engenheiro de Software

| # | O que estava | Como ficou |
|---|---|---|
| E1 | A consulta do winget (`winget upgrade`), que depende da rede e é a etapa mais demorada, rodava sozinha, na vez dela, depois das seis primeiras etapas. O tempo dela somava ao de todas as outras. | `Start-WinForgeCheckupProgramsRead` começa a consulta em segundo plano antes da primeira etapa (com `Start-WinForgeInBackground`, como o Estado da proteção faz com o Windows Update), e a etapa dos programas só recebe a resposta. Na nuvem, com um winget de 3 segundos e a memória levando 3 segundos, a verificação leva 3,2 segundos, contra 6,2 a 6,5 antes. A regra da resposta saiu para `ConvertTo-WinForgeCheckupProgramsFinding`, igual à de antes. |
| E2 | O que não servia: o parâmetro `-Skip` da varredura, que ninguém usava; a lista das pastas da limpeza lida duas vezes nos temporários; a build do Windows lida de novo para o atraso das atualizações, com o suporte já tendo lido; a orientação do registro só com bibliotecas compartilhadas, que nunca aparecia (é informação, sem correção daqui); e o comentário do módulo sem a saúde dos discos e as telas azuis. | Saíram o `-Skip` e a orientação que não aparecia; a lista das pastas é lida uma vez; o atraso usa a build do suporte; o comentário diz as 11 etapas e a consulta em segundo plano. As leituras da varredura viraram blocos, para a dos programas receber a consulta. |

**Por dentro:**
- **Checkup.psm1:** `Start-WinForgeCheckupProgramsRead` e `ConvertTo-WinForgeCheckupProgramsFinding`, novas; `Get-WinForgeCheckupPrograms` com `-Read`, o prazo (`WinForgeCheckupWingetTimeoutSec`, 120 segundos) e o reparo sem o winget; `Invoke-WinForgeCheckupScan` sem o `-Skip`, com a consulta começada antes e largada no `finally`; `Get-WinForgeCheckupDisk` com um ponto só para os discos falhando; `Get-WinForgeCheckupProtection` com a leitura pela metade como não lida; `Get-WinForgeCheckupShortcuts` com os atalhos do OneDrive; `Get-WinForgeCheckupWindows` com a pausa; `Get-WinForgeCheckupStartup` no Desempenho; `Invoke-WinForgeCheckup` com a linha da informação que tem orientação.
- **Traduções:** 5.783 textos (15 novos e 2 que saíram de uso). Duas funções novas: 1.333 nos módulos; 201 na janela, sem mudança.

## Designer e Especialista em UX/UI

| # | O que estava | Orientação | Como ficou |
|---|---|---|---|
| D1 | Com mais de 8 programas abrindo com o Windows, a orientação e o botão levavam a "Programas > Gerenciar inicialização". A memória alta, logo acima na mesma lista, leva a "Desempenho > Programas pesando agora", e o Gerenciar inicialização mora no Desempenho desde a R43 (a busca também leva para lá). | O PC lento tem uma casa: os dois pontos de lentidão levam à mesma página. | "desligue o que não precisa em Desempenho > Gerenciar inicialização", com o botão no da página Desempenho. |
| D2 | Sem o winget, a faixa de um ponto só dizia "Programas desatualizados: não dá para conferir: falta o Instalador de Aplicativo (winget)", com dois sinais de dois-pontos; e as listas diziam "Programas desatualizados", que não é o problema. | A frase lida de uma vez, e cada ponto pelo nome do que falta. | A linha diz "não dá para conferir sem o Instalador de Aplicativo (winget)", e as listas, "Instalador de Aplicativo" ("2 pontos pedem você · Reinício pendente e Instalador de Aplicativo"). |

**Conferido e mantido:**
- **Uma linha por etapa,** na ordem da leitura, com a cor do que pede atenção.
- **O que é seguro vem marcado,** com a frase do porquê só do que está na lista.
- **"Agora não" não esconde o que foi achado,** e a faixa diz os pontos que ficaram, do mais importante ao menos.
- **As orientações como links na janela:** cada caminho "Página > Item" dos textos do Verificar o PC (17, os novos incluídos) leva ao item certo, nos três idiomas.

## MVP Windows

| # | O que estava | Por que importa | Como ficou |
|---|---|---|---|
| M1 | A consulta do winget não tinha prazo. Um winget que não responde (um proxy que segura a conexão, a fonte travada, uma pergunta esperando resposta) deixava a verificação parada na etapa 7 para sempre; só o Parar a tirava dali, sem nada do que já tinha sido lido. | Uma verificação de um clique, que o monitor sugere todo mês, precisa terminar. O resto do WinForge já lê o Windows com prazo (o WMI, o Windows Update). | Prazo de 120 segundos, contados do começo da consulta. Sem resposta, a linha diz "o Instalador de Aplicativo não respondeu em 120 segundos", a etapa fica como não lida, e a verificação termina com o que leu. O winget que não respondeu é encerrado, e também quando a pessoa usa o Parar no meio da verificação: nenhum fica rodando. |

**Conferido**, com as fontes no fim:
- **A consulta:** `winget upgrade` sem argumentos só lista o que tem versão nova, sem instalar; `--accept-source-agreements` aceita o contrato da fonte sem a pergunta. É a mesma consulta da tela Atualizar programas. Os programas de versão desconhecida e os marcados para não atualizar ficam de fora, como lá (R36). O texto chega em UTF-8 e o código de saída, inteiro.
- **Sem o winget:** o winget vem com o Instalador de Aplicativo, no Windows 11, no 10 a partir da versão 1809 e no Windows Server 2025. A Microsoft indica registrar de novo o Instalador de Aplicativo (`Add-AppxPackage -RegisterByFamilyName`), que é o que o **Reparar o Instalador de Aplicativo** faz, com a página da Microsoft Store se não resolver. O Windows Sandbox não tem o winget.
- **A pausa:** a Microsoft descreve a pausa de até 35 dias, que adia as atualizações sem desligá-las; ela pode ser retomada a qualquer hora, e retoma sozinha no fim. A leitura é a da página Atualizações (R48).
- **A saúde dos discos, a proteção, o reinício e as telas azuis:** as mesmas regras das telas de cada um, como na R27.

## QA Sênior

**Como foi testado:** uma bateria nova do Verificar o PC, 163 conferências em português e 166 em inglês e em espanhol (nos outros dois, as dos textos traduzidos e uma que procura palavras soltas em português na tela):
- **Cada leitura (A):** a saúde de um, dois e três discos falhando (um sem letra) e de nenhum; a proteção com o firewall, as ameaças ou os dois sem leitura, com um problema e o firewall sem leitura, com outro antivírus e sem leitura nenhuma; os atalhos só no OneDrive, misturados, sem o OneDrive, nenhum e sem Administrador; a inicialização com 11 e com 8; as atualizações atrasadas ou em dia, com e sem pausa, com a pausa sem data, com o atraso desconhecido e num Windows sem suporte; a build que o atraso usa; sem o winget; o registro só com bibliotecas e com referências; a lista das pastas lida uma vez.
- **A consulta do winget (B):** a regra da resposta; a espera, a falha e o prazo, contado do começo; e, com um winget falso de verdade no caminho do sistema, os argumentos, as linhas, o código de saída, o texto em UTF-8, os caracteres nulos, o erro padrão, o winget sumido no meio, o winget parado (encerrado no prazo), a consulta correndo junto com uma etapa lenta e a parada no meio da verificação (o winget encerrado).
- **A verificação inteira (C),** da leitura à faixa, em 15 situações: dois discos, com o firewall da rede pública desligado; o firewall e as ameaças sem leitura; sem winget, sozinho e com o reinício; pausado, com e sem atraso; os atalhos só no OneDrive e misturados (o que vai para a Lixeira e o que fica); a inicialização cheia; o winget sem resposta; o registro só com bibliotecas; o PC bagunçado com a pausa e um atalho no OneDrive; tudo em dia. Em cada uma: o título, a frase dentro das 220 letras, nenhum marcador sobrando e o botão para um item que existe.
- **Os textos e os caminhos (D):** cada orientação nova como link para o item certo, nos três idiomas; os 15 textos novos traduzidos, com os mesmos marcadores; três situações com tudo de novo junto.
- **O código (E):** sem o `-Skip`; a consulta começada antes e largada no `finally`; o prazo; a lista das pastas lida uma vez; cada ponto de atenção com peso e cada destino existindo; nenhum `catch` vazio.

**Achados**

| # | O que estava | Como ficou |
|---|---|---|
| Q1 | Dois discos com sinal de falha viravam dois pontos com o mesmo nome: "2 pontos pedem você · Saúde do disco e Saúde do disco.", e a orientação de backup aparecia duas vezes. | Um ponto só, "Saúde dos discos: WDC WD10EZEX (D:) e Kingston A400 (C:) dão sinal de falha.", com o botão para a Saúde dos discos, onde está o sinal de cada um (na faixa, a frase com todos passaria das 220 letras). Com um disco, como antes, com o sinal dele. |
| Q2 | Com o firewall ou as ameaças sem leitura e o resto em dia, a linha dizia "leitura incompleta", mas a faixa dizia "Tudo certo", em verde, e o resultado era de sucesso. A tela Estado da proteção não afirma o que não leu. | A faixa diz "Nada pedindo atenção no que foi lido · Não foi possível ler: Firewall.", em amarelo. Com outro ponto, ele e o que não foi lido. Com um problema na proteção, como antes: o ponto, com "não foi possível ler o firewall" na linha. |
| Q3 | Com atalhos quebrados só no OneDrive, a linha dizia "Atalhos: nenhum quebrado". Eles ficam fora da correção de um clique (o programa pode estar em outro PC da pessoa) e aparecem, desmarcados, em Limpeza > Remover atalhos quebrados. | A linha diz "2 atalhos quebrados no OneDrive", como informação, e uma linha diz "revise em Limpeza > Remover atalhos quebrados; o programa pode estar em outro PC seu". Misturados, a correção leva só os outros, e a lista de marcar diz quantos do OneDrive ficam e onde. |

Os testes também acharam os do produto (P1 e P2), os da engenharia (E1 e E2), os do designer (D1 e D2) e o do MVP (M1).

**Contra o código de antes (R55):** falham 74 das 162 conferências em português e 80 das 165 em inglês e em espanhol, cada uma de uma correção. As que passam conferem o que foi mantido: um disco falhando, a proteção com um problema e com outro antivírus, os atalhos sem o OneDrive, as atualizações sem pausa, a faixa de tudo em dia e os textos.

**28 defeitos de propósito,** e as conferências pegam todos: os dois discos sem ponto e com o nome no singular; a proteção pela metade sem contar como não lida e sem o nome do que faltou; os atalhos do OneDrive como "nenhum quebrado", sem a orientação, na correção, e a linha de informação que não aparece; a inicialização de volta a Programas; a pausa ignorada, atrasado e pausado levando a Instalar, em dia e pausado sem a pausa, o atraso desconhecido sem a linha; a build lida de novo; sem winget como informação e sem o nome Instalador de Aplicativo; a consulta sem prazo, o prazo esgotado como leitura qualquer e o prazo de 30 segundos; o winget que não começa antes nem é largado na parada; a consulta sem aceitar o contrato da fonte, sem o erro padrão, com os nulos e sem o código de saída; a lista das pastas lida duas vezes; o registro só com bibliotecas com orientação; e, em inglês, um texto novo sem tradução.

**Nada do que funcionava quebrou:** as baterias das 14 páginas revistas, com os mesmos números da R55 (a do Verificar o PC da R27 depois da adaptação abaixo; a da Rede da R22 com a mesma conferência antiga do escudo); a das seis funções novas da R36 (257 em cada idioma, depois da adaptação abaixo); as das segundas revisões, do Início à Busca, com os mesmos números; a do Explorador e da tela de bloqueio da R50; a da Manutenção da R14 e a do Início da R13, que usam o Verificar o PC; as mensagens da janela (72 em cada idioma); instalar, atualizar com um clique, o pacote de suporte e o Setup de verdade, da R55 para esta; cada nome e link citado na documentação técnica; nenhuma função sem uso; o PSScriptAnalyzer com 242 avisos, um a menos (o do `-Skip` que saiu), nenhum novo.

**As baterias antigas adaptadas ao que mudou de propósito:** a do Verificar o PC da R27 passou a mandar a mesma resposta simulada do winget pela tarefa em segundo plano, e três conferências pedem o novo (os dois discos num ponto só, a inicialização no Desempenho e o texto sem o winget): 148, 149 e 149, duas a mais em cada idioma, porque o caso sem winget agora tem a faixa com botão. A das seis funções novas da R36 lê a resposta dos programas marcados por `ConvertTo-WinForgeCheckupProgramsFinding`, com os mesmos 257.

## O que só um PC mostra

Isto entrou no roteiro de conferência (§46):
- **O tempo da verificação** num PC real, com o winget respondendo, e sem internet (o winget sem resposta, a verificação terminando).
- **O Parar no meio da verificação:** nenhum winget sobrando no Gerenciador de Tarefas.
- **As atualizações pausadas** nas Configurações, com e sem atraso: a linha, a faixa e o botão Windows Update.
- **Sem o Instalador de Aplicativo** (o Windows Sandbox não tem o winget): o ponto, a faixa e o botão do reparo.
- **Um atalho quebrado no OneDrive:** a linha de informação, com o link, e o atalho que fica.
- **Dois discos com sinal de falha,** se houver.

## Fontes
- [Use WinGet to install and manage applications (Microsoft Learn)](https://learn.microsoft.com/en-us/windows/package-manager/winget/): o winget vem com o Instalador de Aplicativo no Windows 11, no Windows 10 a partir da versão 1809 e no Windows Server 2025; sem ele registrado, a Microsoft indica `Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe`; o Windows Sandbox não tem o winget.
- [upgrade command (winget) (Microsoft Learn)](https://learn.microsoft.com/en-us/windows/package-manager/winget/upgrade): sem argumentos, o `upgrade` lista as atualizações disponíveis; `--accept-source-agreements` aceita o contrato da fonte sem a pergunta; os programas de versão desconhecida e os marcados com um pino ficam de fora sem `--include-unknown` e `--include-pinned`.
- [Pause updates in Windows (Microsoft Support)](https://support.microsoft.com/windows/manage-updates-in-windows-643e9ea7-3cf6-7da6-a25c-95d4f7f099fe): a pausa de até 35 dias adia as atualizações sem desligá-las; dá para retomar a qualquer hora, e elas retomam sozinhas quando a pausa acaba.
- As da R27 continuam valendo.
