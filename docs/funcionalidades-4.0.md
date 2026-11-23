# WinForge 4.0 — mapa de funcionalidades

O mapa do que o WinForge faz hoje, feito pela visão de produto em 18/11/2026, sobre a Build 4.0. Para cada função, ele diz o que ela faz, onde aparece e com quem conversa. As lacunas de integração encontradas estão no fim, com o que foi feito e o que ficou para depois.

**Conferido de novo na R29 (20/11/2026):** cada item, a frase inteira, o grupo e o Administrador, contra a tabela de navegação do código; os 53 ajustes em 10 grupos. Mudou a frase de Versão e pastas (da R25), a conta dos textos e o fim do Otimizar (da R28).

**Atualizado na R36 (20/11/2026):** as seis funções novas (a ativação do Windows, a integridade da memória, Reparar o Instalador de Aplicativo, Manter programas na versão atual, Destravar a impressão e Acertar a data e a hora), a conta dos itens e a dos textos.

**Atualizado na R52 (22/11/2026):** Aplicar ajustes recomendados sem Administrador, o resumo do alto e a chave na própria linha em Ajustes do Windows e na Personalização, e a conta dos textos.

**Atualizado na R55 (22/11/2026):** a ordem da Busca (a página achada pelo nome e, logo depois, o caminho recomendado dela) e a linha de cima de cada resultado, com o grupo do ajuste.

**Atualizado na R54 (22/11/2026):** o aviso de versão nova no monitor (uma conferência a mais) e o resumo do Sobre o WinForge.

**Atualizado na R53 (22/11/2026):** a cor de destaque nas amostras da própria linha, com o desfazer no Histórico de mudanças (e o das teclas do idioma), e a frase curta de cada chave. O desfazer das duas saiu da lista Para depois: a própria tela troca de volta, mas não a uma cor escolhida nas Configurações, fora das oito do WinForge.

**Atualizado na R59 (22/11/2026):** o item Site do WinForge em Sobre o WinForge, a conta dos itens e a das páginas, que ainda não contava a Personalização.

**Atualizado na R60 (22/11/2026):** a Cor de destaque passa a abrir as Cores do Windows (a troca pelo WinForge saiu), e Gerenciar inicialização tira o que sobrou de programas desinstalados.

## Visão geral

- **12 páginas e 107 itens.** São 11 páginas no menu e Sobre o WinForge no rodapé. Dos itens, 87 são funções do próprio WinForge e 20 abrem uma ferramenta do Windows ou o site do WinForge (↗). Quatro ficam fora da lista e são achados pela busca.
- **53 ajustes do Windows** em 10 grupos, nas páginas Ajustes do Windows e Personalização. Cada ajuste guarda o valor original, para desfazer.
- **Duas formas de usar, com as mesmas páginas:** a janela e o menu de texto.
- **Linha de comando:** `-Action Menu`, `Report`, `Shortcut`, `ScheduledMaintenance` e `Check` (com `-Json`), mais `-Language pt|en|es`.
- **Três idiomas:** português, inglês e espanhol, seguindo o Windows (5.794 textos traduzidos).
- **A janela (revisões R9 e R37):** a barra lateral em quatro grupos (Cuidar, Consertar, Proteger e Configurar), as páginas em listas com o caminho recomendado em destaque, a fonte e os tamanhos do Windows 11, títulos em negrito e o laranja da bigorna do ícone nos botões e destaques. Ela segue o contraste alto e o tamanho do texto do Windows. Cada linha mostra uma frase curta; a inteira fica na dica, no leitor de tela e na busca.
- **Programa do Windows:** instala pelo WinForge-Setup.cmd, atualiza com um clique e desinstala por Configurações > Aplicativos. Também abre direto da pasta extraída, sem instalar.

## Os sistemas que ligam tudo

| Sistema | O que faz | Leva a |
|---|---|---|
| **Início** | A nota de saúde (a frase, a nota de 0 a 100 com dez traços e os pontos de atenção); "Seu PC", com os cartões Disco do sistema (com a barra de uso), Proteção e Sistema e a linha da última manutenção, do reinício pendente e da bateria; "Histórico neste PC" (o espaço liberado nas manutenções, as manutenções feitas e as mudanças anotadas, só o que já aconteceu); e a faixa "Configuração inicial" (atalho, monitor e manutenção mensal) | A tela de cada assunto. Otimizar e Verificar o PC pelos botões da nota; os números de "Histórico neste PC", ao Histórico de manutenções e ao Histórico de mudanças |
| **Busca (Ctrl+K)** | Acha os 107 itens, as páginas e os ajustes nos três idiomas, por nome, sinônimo ou o nome em inglês das ferramentas do Windows. Quem busca pelo nome de uma página vê a página e, logo depois, o caminho recomendado dela; cada resultado diz de onde vem ("Ajustes do Windows > Explorador") | O item |
| **Verificar o PC** | 11 etapas: espaço e saúde dos discos, temporários, registro, atalhos, memória, o que abre com o Windows, programas desatualizados (o winget corre junto com as outras etapas, com prazo), suporte e atualizações do Windows (com a pausa do Windows Update), proteção, reinício pendente e telas azuis. Corrige num clique o que é seguro | A tela de cada ponto de atenção; sem o winget, o reparo do Instalador de Aplicativo; com as atualizações pausadas e atrasadas, o Windows Update |
| **Otimizar** | A manutenção completa, em ordem. No fim, a faixa diz o que aconteceu e qual etapa pede atenção | A tela que roda sozinha a etapa com problema, pelo botão da faixa |
| **Monitor na bandeja** | 11 conferências em segundo plano: espaço, reinício, manutenção, proteção, suporte do Windows, programas, dados online, saúde do disco, teste de memória, telas azuis e versão nova do WinForge. Cada aviso tem uma ação | A tela do aviso |
| **Manutenção agendada** | Uma limpeza leve e um relatório todo mês, sem abrir o WinForge | — |
| **Histórico de mudanças** | O que o WinForge mudou no PC, com o desfazer onde há volta | O desfazer |
| **Relatório (HTML e texto)** | Pontos de atenção, sistema, hardware, discos, ajustes, eventos críticos, telas azuis e memória, segurança, bateria e a última manutenção | — |
| **Verificação rápida** (`-Action Check -Json`) | A nota de saúde, a auditoria de segurança e as telas azuis, com um código de saída para scripts | — |
| **Pacote de suporte** | Um zip com versões, logs, tempo de abertura, o log da janela, a verificação rápida, o último relatório, os históricos e as preferências | — |
| **Próximo passo** | O botão da faixa de resultado que leva à tela seguinte (do DISM ao SFC, de uma tela azul de memória ao teste de memória...) | A tela seguinte |
| **Referências "Página > Item"** | Os textos que mandam para outro lugar viram link na janela | O item |
| **Idioma** | Português, inglês ou espanhol, em Sobre o WinForge > Idioma | — |

## As páginas e os itens

↗ abre uma ferramenta do Windows. "Só pela busca": fora da lista, mas achado pela busca. As descrições abaixo são as frases inteiras; na janela, cada linha mostra uma versão curta, de até 60 letras.

Na barra lateral, as páginas ficam em grupos: **Cuidar** (Manutenção, Limpeza, Desempenho), **Consertar** (Reparo, Diagnóstico, Rede), **Proteger** (Segurança, Atualizações) e **Configurar** (Programas, Ajustes do Windows, Personalização). O menu de texto e a busca seguem a ordem desta lista.

### Manutenção

_Cuide do PC e volte atrás se algo der errado._

| Item | O que faz | Grupo | Administrador |
|---|---|---|---|
| Otimizar | A manutenção completa do PC, em ordem; pode levar mais de uma hora | Cuidar do PC | Sim |
| Verificar o PC | Confere o PC em uma passada e corrige, num clique, o que é seguro | Cuidar do PC | Sim |
| Manutenção agendada | Uma limpeza leve e um relatório todo mês, sem você abrir o WinForge | Cuidar do PC | Sim |
| Histórico de manutenções (pelo cartão Última manutenção e pela busca) | A última manutenção, o que pediu atenção nela e a variação de espaço das anteriores | Cuidar do PC | — |
| Agendador de Tarefas ↗ (só pela busca) | Abre o Agendador de Tarefas do Windows, onde a tarefa do WinForge aparece | Cuidar do PC | — |
| Criar ponto de restauração | Guarda o estado do Windows de agora, para voltar a ele depois | Se algo der errado | Sim |
| Histórico de mudanças | O que o WinForge mudou no PC; desfaça o que tiver volta | Se algo der errado | — |
| Restauração do Sistema ↗ | Abre a janela do Windows que volta o PC a um ponto de restauração | Se algo der errado | — |

### Diagnóstico

_Veja como o PC está antes de mexer em qualquer coisa._

| Item | O que faz | Grupo | Administrador |
|---|---|---|---|
| Sobre este PC | Windows, processador, memória, placa de vídeo, discos e Secure Boot | Visão geral | — |
| Suporte do Windows | Até quando este Windows recebe atualizações de segurança e se o PC pode ir para o Windows 11 | Visão geral | — |
| Exportar relatório | Salva o estado do PC em HTML e em texto, para guardar ou mandar a quem vai ajudar | Visão geral | — |
| Discos e espaço livre | SSD ou HDD, espaço livre e uso de cada unidade | Hardware | — |
| Saúde dos discos | Estado, temperatura, desgaste e erros de cada disco | Hardware | Sim |
| Dispositivos com problema | Drivers e hardware com erro | Hardware | — |
| Saúde da bateria | Capacidade de hoje comparada à de fábrica, ciclos de carga e carga atual | Hardware | — |
| Teste de memória | Testa a memória (RAM) no próximo reinício; o resultado aparece depois | Hardware | Sim |
| Eventos críticos (7 dias) | Quedas de energia, tela azul, erros de disco e de hardware | Funcionamento do Windows | — |
| Telas azuis | As telas azuis dos últimos 90 dias, com a causa provável e o que fazer | Funcionamento do Windows | — |
| Reinício pendente | O que está esperando um reinício, se ele é mesmo necessário, e reiniciar quando quiser | Funcionamento do Windows | — |
| Tempo ligado e energia | Quanto tempo o PC está ligado, Inicialização Rápida e hibernação; ligado há uma semana ou mais, oferece reiniciar | Funcionamento do Windows | — |
| Monitor de Confiabilidade ↗ | Abre o histórico de falhas do Windows | Ferramentas do Windows | — |
| Gerenciador de Dispositivos ↗ | Abre o Gerenciador de Dispositivos do Windows | Ferramentas do Windows | — |

### Segurança

_Veja se o PC está protegido e rode a verificação do Windows._

| Item | O que faz | Grupo | Administrador |
|---|---|---|---|
| Estado da proteção | Antivírus, assinaturas, firewall, atualizações pendentes e ameaças ativas | Proteção | — |
| Auditoria de segurança | Além do antivírus e do firewall, confere senhas, acesso remoto e criptografia, e dá uma nota | Proteção | — |
| Chave de recuperação do BitLocker | Mostra se o disco está criptografado e guarda uma cópia da chave fora do PC | Proteção | Sim |
| Atualizar assinaturas do antivírus | Baixa do Windows Defender a lista mais nova de vírus conhecidos (as assinaturas) | Proteção | Sim |
| Verificar vírus | Atualiza o antivírus e faz a verificação rápida do Windows Defender, em alguns minutos | Procurar ameaças | Sim |
| Verificação completa de vírus | Atualiza o antivírus e o Windows Defender examina todos os arquivos; pode levar horas | Procurar ameaças | Sim |
| Verificar uma pasta | Atualiza o antivírus e o Windows Defender examina só a pasta, o arquivo ou o pendrive que você indicar | Procurar ameaças | Sim |
| Segurança do Windows ↗ | Abre o aplicativo do Windows, com a verificação offline e o histórico de proteção | Procurar ameaças | — |

### Limpeza

_Libere espaço, do mais seguro ao mais profundo._

| Item | O que faz | Grupo | Administrador |
|---|---|---|---|
| Limpeza rápida | Temporários do usuário e do Windows e, se você quiser, a Lixeira | Liberar espaço | Sim |
| Analisar uso de espaço | Mostra o que a limpeza libera, as maiores pastas do perfil e os arquivos grandes do sistema | Liberar espaço | — |
| Limpeza personalizada | Você marca numa lista, com o tamanho de cada item: temporários, caches, despejos de falhas, Lixeira | Liberar espaço | Sim |
| Esvaziar a Lixeira | Remove em definitivo o que está na Lixeira, de todas as unidades | Liberar espaço | — |
| Limpar a pasta Downloads | Você vê uma prévia, filtra por idade e escolhe entre a Lixeira e a exclusão | Liberar espaço | — |
| Configurações de armazenamento ↗ | Abre Armazenamento, nas Configurações do Windows, onde ficam os arquivos temporários e o Sensor de Armazenamento | Liberar espaço | — |
| Remover atalhos quebrados | Atalhos que apontam para o que não existe mais; eles vão para a Lixeira | Arrumar o que sobrou | — |
| Encontrar arquivos duplicados | Arquivos iguais (mesmo conteúdo) numa pasta; você escolhe o que vai para a Lixeira | Arrumar o que sobrou | — |
| Restos de programas desinstalados | Pastas que sobraram de programas desinstalados pelo WinForge; você escolhe o que vai para a Lixeira | Arrumar o que sobrou | — |
| Limpar o registro | Só referências quebradas a programas e arquivos que não existem mais; com backup e desfazer | Avançado | — |
| Limpar componentes do Windows (WinSxS) | Remove versões antigas de componentes substituídos por atualizações (DISM) | Avançado | Sim |
| Apagar o espaço livre | Sobrescreve o espaço livre do disco: o que já foi apagado não pode mais ser trazido de volta | Avançado | Sim |

### Desempenho

_Deixe o PC mais leve agora e veja o que está pesando._

| Item | O que faz | Grupo | Administrador |
|---|---|---|---|
| Acelerar agora | Libera memória e apaga os seus temporários, num clique; o efeito na memória é passageiro | Deixar o PC mais leve | — |
| Programas pesando agora | O que mais usa o processador e a memória neste momento; você pode fechar o que quiser | Deixar o PC mais leve | — |
| Liberar memória | Tira da memória o que os programas abertos ocupam; ajuda antes de abrir algo pesado | Deixar o PC mais leve | — |
| Gerenciar inicialização | O que abre junto com o Windows; desligar o que não precisa deixa o PC leve desde o início | Para o PC continuar leve | — |
| Gerenciador de Tarefas ↗ | Abre o Gerenciador de Tarefas do Windows; os gráficos de uso ficam na aba Desempenho | Para o PC continuar leve | — |

### Reparo

_Conserte o Windows e o disco, e mantenha a unidade em forma._

| Item | O que faz | Grupo | Administrador |
|---|---|---|---|
| Reparar o Windows (DISM + SFC) | Conserta arquivos danificados do Windows; costuma levar de 20 a 60 minutos e não apaga nada seu | Arquivos do Windows | Sim |
| Reparar imagem e componentes (DISM) | Restaura os arquivos-base do Windows pela internet (Windows Update); leva de 10 a 30 minutos | Arquivos do Windows | Sim |
| Verificar arquivos do sistema (SFC) | Confere os arquivos protegidos do Windows e conserta os danificados; leva de 5 a 20 minutos | Arquivos do Windows | Sim |
| Verificar o sistema de arquivos (CHKDSK) | Procura erros no disco sem reiniciar; se precisar de reparo na reinicialização, pergunta antes | Disco e dispositivos | Sim |
| Otimizar a unidade do sistema | O que o Windows já faz sozinho toda semana (o TRIM num SSD, desfragmentar num HD), feito agora | Disco e dispositivos | Sim |
| Detectar dispositivos e drivers | Procura hardware novo e instala os drivers que já estejam disponíveis | Disco e dispositivos | Sim |
| Destravar a impressão | Para a impressora que não imprime: reinicia (ou liga) o Spooler de Impressão e, se você escolher, esvazia a fila | Disco e dispositivos | Sim |
| Restauração do Sistema ↗ | Abre a janela do Windows que volta o PC a um ponto de restauração | Ferramentas do Windows | — |
| Recuperação ↗ | Abre a Recuperação do Windows: restaurar o PC e a inicialização avançada | Ferramentas do Windows | — |

### Atualizações

_Windows, drivers, Microsoft Store e programas._

| Item | O que faz | Grupo | Administrador |
|---|---|---|---|
| Instalar atualizações do Windows | Procura, baixa e instala aqui mesmo as atualizações pendentes, com o progresso na tela | Windows e drivers | Sim |
| Atualizar drivers | Procura drivers no Windows Update e instala os que você marcar; os opcionais vêm desmarcados | Windows e drivers | Sim |
| Ferramentas do fabricante | Indica o programa oficial do fabricante do PC e da placa de vídeo, que acha drivers e BIOS | Windows e drivers | — |
| Corrigir o Windows Update | Quando as atualizações falham ou travam: refaz o cache do Windows Update e religa os serviços | Windows e drivers | Sim |
| Atualizar programas (winget) | Mostra os programas com versão nova no winget e atualiza os que você escolher | Programas e aplicativos | — |
| Manter programas na versão atual | Marque os programas que devem ficar na versão de agora: eles saem das atualizações do WinForge | Programas e aplicativos | — |
| Atualizar aplicativos da Microsoft Store | Pede à Microsoft Store as atualizações dos aplicativos e abre a lista para acompanhar | Programas e aplicativos | — |
| Windows Update ↗ | Abre o Windows Update nas Configurações do Windows | Ferramentas do Windows | — |
| Atualizações opcionais ↗ | Abre nas Configurações do Windows as opcionais: drivers e prévias da próxima atualização | Ferramentas do Windows | — |

### Programas

_Instale, remova e organize o que roda no PC. Na janela, quando falta o Instalador de Aplicativo (winget), o alto da página diz isso e leva ao reparo._

| Item | O que faz | Grupo | Administrador |
|---|---|---|---|
| Instalar programas essenciais | Escolha numa lista de programas comuns, como navegadores, leitor de PDF, 7-Zip e VLC | Instalar e remover | — |
| Buscar e instalar programas | Procura um programa pelo nome e instala o que você marcar | Instalar e remover | — |
| Listar programas instalados | Conta os programas instalados e quantos têm versão nova, com a lista completa do winget | Instalar e remover | — |
| Desinstalar programas | Lista os programas e remove os que você marcar | Instalar e remover | — |
| Remover aplicativos do Windows | Mostra os aplicativos que vêm com o PC e remove só os que você marcar | Instalar e remover | — |
| Reparar o Instalador de Aplicativo (pela faixa do alto da página e pelo botão da faixa "Falta o Instalador de Aplicativo", quando ele falta, e pela busca) | Registra de novo o winget para esta conta, como a Microsoft indica; se não resolver, abre a Microsoft Store | Instalar e remover | — |
| Gerenciar inicialização | O que abre junto com o Windows; desligar o que não precisa deixa o PC leve desde o início (a mesma ação de Desempenho) | Inicialização e recursos | — |
| Recursos opcionais do Windows | Liga ou desliga recursos como WSL, Hyper-V, Windows Sandbox e .NET 3.5 | Inicialização e recursos | Sim |
| Backup antes de formatar | Guarda a lista de programas, os drivers e os ajustes; fotos e documentos você copia à parte | Backup e formatação | Sim |
| Restaurar a partir de um backup | Reinstala os programas e os drivers e reaplica os ajustes de um backup do WinForge, achado em Documentos ou na raiz dos pendrives e HDs conectados | Backup e formatação | Sim |
| Aplicativos instalados ↗ | Abre nas Configurações do Windows, em Aplicativos, a lista completa, com a opção de desinstalar | Ferramentas do Windows | — |
| Programas e Recursos ↗ | Abre o painel de controle clássico, para programas antigos | Ferramentas do Windows | — |
| Aplicativos de inicialização ↗ | Abre nas Configurações do Windows, em Aplicativos, Inicialização, o que abre junto com o Windows | Ferramentas do Windows | — |

### Rede

_Do mais simples ao que mexe mais: ver, testar, medir e consertar a conexão. Na janela, o alto da página diz a conexão, como o Windows a vê (com internet, sem internet, acesso limitado ou nenhuma rede), e leva ao Testar conectividade quando há problema._

| Item | O que faz | Grupo | Administrador |
|---|---|---|---|
| Informações de rede | Adaptadores, rede Wi-Fi, IP, DNS, gateway, proxy e IP público | Ver e testar | — |
| Testar conectividade (ping) | Diz se a internet responde e se a conexão está estável ou perdendo dados | Ver e testar | — |
| Testar velocidade da internet | Latência, download e upload (usa cerca de 35 MB) | Ver e testar | — |
| Relatório de Wi-Fi | Gera o relatório do Windows com as sessões e as quedas do Wi-Fi dos últimos dias | Ver e testar | Sim |
| Senha do Wi-Fi | Mostra a senha de uma rede Wi-Fi salva neste PC, só na tela | Ver e testar | Sim |
| Acertar a data e a hora | Pede ao Windows para sincronizar o relógio agora e confere a hora num servidor da Microsoft | Consertar e configurar | Sim |
| Reparar rede e DNS | Para quando a internet não funciona: refaz as configurações de rede; IP e DNS fixos são mantidos | Consertar e configurar | Sim |
| Trocar o servidor DNS | Mede o tempo de resposta e troca para Cloudflare, Google, Quad9 ou o filtro para famílias | Consertar e configurar | Sim |
| Desfazer a troca de DNS | Devolve o DNS que o PC usava antes da troca feita pelo WinForge | Consertar e configurar | Sim |

### Ajustes do Windows

_Mudanças reversíveis, com backup do valor original. Na janela, o alto da página tem Aplicar ajustes recomendados, Mais opções (as outras ações) e Atualizar estado; abaixo, o resumo diz quantos recomendados estão em uso (e leva a aplicá-los) e quantos ajustes da página o WinForge mudou (e leva ao Histórico de mudanças). Cada chave muda o ajuste na própria linha. As teclas do idioma e as notificações ficam como linhas no grupo Notificações e teclado. Com o WinForge aberto com a conta de outro Administrador, os ajustes do perfil do usuário ficam de fora, e o resumo diz isso._

| Item | O que faz | Grupo | Administrador |
|---|---|---|---|
| Aplicar ajustes recomendados | Mostra as extensões de arquivos e tira dicas, sugestões e o ID de publicidade; você escolhe quais. Só muda a sua conta; com Administrador, oferece o ponto de restauração antes | — | — |
| Perfis de ajustes | Conjuntos prontos: Essencial, Trabalho, Jogos, Privacidade e Notebook; você escolhe o que aplicar | — | Sim |
| Teclas que trocam o idioma do teclado | Escolhe as teclas que trocam o idioma e o teclado: Alt + Shift, Ctrl + Shift, as duas ou nenhuma; o Histórico de mudanças as desfaz | — | — |
| Notificações e Não incomodar ↗ | Abre nas Configurações do Windows as notificações e o Não incomodar (assistente de foco) | — | — |
| Criar ponto de restauração | Um ponto para voltar atrás se algo der errado | — | Sim |
| Exportar ajustes aplicados | Salva em um arquivo os ajustes aplicados neste PC, para repetir em outro | — | — |
| Importar ajustes | Aplica ajustes de um arquivo exportado antes, depois de você escolher quais | — | Sim |
| Desfazer ajustes do WinForge | Desfaz tudo o que o WinForge aplicou aqui e na Personalização, usando o backup | — | Sim |

### Personalização

_O visual do Windows: barra de tarefas, área de trabalho, cores e tela de bloqueio. Na janela, o resumo do alto diz quantos ajustes da página o WinForge mudou, cada chave muda o ajuste na própria linha, e a cor de destaque e a tela de bloqueio ficam como linhas nos grupos Cores e transparência e Tela de bloqueio._

| Item | O que faz | Grupo | Administrador |
|---|---|---|---|
| Cor de destaque ↗ | Abre nas Configurações do Windows as Cores, onde se escolhe a cor de destaque | — | — |
| Tela de bloqueio do Windows ↗ | Abre nas Configurações do Windows a tela de bloqueio: a imagem e o que aparece nela | — | — |
| Personalização do Windows ↗ | Abre nas Configurações do Windows a tela de fundo, os temas, as cores e as fontes | — | — |

### Sobre o WinForge

_A versão, o suporte e as preferências do WinForge. No alto, o resumo diz a versão (e se há uma mais nova, pelo que a última consulta viu), o atalho e a instalação._

| Item | O que faz | Grupo | Administrador |
|---|---|---|---|
| Versão e pastas | Qual versão está aberta, de que pasta, se está instalada e onde ficam os logs e relatórios | Versão e dados | — |
| Verificar nova versão | Vê se há uma versão mais nova do WinForge e instala com um clique, conferindo o SHA-256 | Versão e dados | — |
| Conferir dados online | Confere na internet a lista de essenciais e as datas de suporte do Windows mais recentes | Versão e dados | — |
| Pasta de logs e relatórios ↗ | Abre a pasta com os logs e os relatórios gerados | Versão e dados | — |
| Pacote de suporte | Junta logs, verificação e versões num zip para mandar a quem vai ajudar | Versão e dados | — |
| Site do WinForge ↗ | Abre o site do WinForge no navegador, na página do idioma da janela | Versão e dados | — |
| Criar atalho do WinForge | Coloca o WinForge, com o ícone dele, na Área de Trabalho ou no Menu Iniciar | Integração com o Windows | — |
| Monitor na bandeja | Avisa, perto do relógio, quando o disco enche ou falha, a proteção desliga ou falta manutenção | Integração com o Windows | — |
| Idioma (só pela busca) | Português, inglês ou espanhol; no automático, o mesmo idioma do Windows | Integração com o Windows | — |

## Como os sinais de saúde circulam

Onde cada sinal aparece além da própria tela. ✓ = aparece; "novo" = integrado nesta revisão.

| Sinal | Tela própria | Início | Verificar o PC | Monitor | Relatório | Verificação rápida |
|---|---|---|---|---|---|---|
| Espaço no disco | Discos e espaço livre | ✓ cartão | ✓ com limpeza | ✓ | ✓ | ✓ |
| Saúde do disco | Saúde dos discos | — | ✓ | ✓ (previsão do disco e estado do Windows) | ✓ | — |
| Proteção (antivírus, ameaças, assinaturas) | Estado da proteção | ✓ cartão | ✓ | ✓ | ✓ | ✓ |
| Suporte e atualizações do Windows | Suporte do Windows | ✓ cartão | ✓ | ✓ | ✓ | ✓ |
| Reinício pendente | Reinício pendente | ✓ cartão | ✓ | ✓ | ✓ | ✓ |
| Última manutenção | Histórico de manutenções | ✓ cartão | — | ✓ | ✓ | ✓ |
| Programas desatualizados (sem os marcados para ficar na versão atual) | Atualizar programas (winget) | — | ✓ | ✓ | — | — |
| Telas azuis | Telas azuis | — | ✓ novo | ✓ novo | ✓ | ✓ novo |
| Teste de memória | Teste de memória | — | — | ✓ | ✓ | — |
| Eventos críticos | Eventos críticos | — | — | — | ✓ | — |
| Bateria | Saúde da bateria | ✓ cartão | — | — | ✓ | ✓ |
| BitLocker | Chave de recuperação do BitLocker | — | — | — | ✓ auditoria | ✓ auditoria |
| Manutenção agendada parada | Manutenção agendada | ✓ ponto de atenção | — | — | — | ✓ |
| Ativação do Windows (R36) | Sobre este PC | — | — | — | ✓ | — |
| Integridade da memória (R36) | Auditoria de segurança | — | — | — | — | — |

**O que entra no Histórico de mudanças:**
- os ajustes do Windows (com desfazer);
- os programas marcados para ficar na versão atual e os que voltam a atualizar (com desfazer, da R36);
- o DNS (com desfazer);
- os itens que abrem com o Windows (com desfazer);
- os recursos opcionais (com desfazer);
- a limpeza do registro (com desfazer);
- as teclas que trocam o idioma do teclado (com desfazer, da R53);
- o que sobrou de programas desinstalados, tirado da inicialização (sem desfazer, da R60);
- os atalhos quebrados, os arquivos duplicados e os restos de programas;
- os aplicativos do Windows removidos e os programas instalados, atualizados e desinstalados;
- as atualizações do Windows e a correção do Windows Update, e os drivers;
- o monitor na bandeja e a chave do BitLocker criada;
- o Instalador de Aplicativo registrado de novo, a fila de impressão esvaziada ou o Spooler reiniciado (ou ligado, da R44) e o relógio acertado (da R36);
- e, a partir desta revisão, também as teclas que trocam o idioma do teclado, o reparo de rede, a manutenção agendada, o CHKDSK que corrigiu ou agendou o reparo e o que voltou de um backup.

## Lacunas de integração

### Feitas nesta revisão (R6)

| # | Lacuna | O que mudou |
|---|---|---|
| 1 | Uma tela azul nova não virava aviso | O monitor avisa uma vez, com a causa provável, e leva a Diagnóstico > Telas azuis. A primeira leitura só marca onde a conta está |
| 2 | O Verificar o PC não olhava as telas azuis | Etapa nova: telas azuis dos últimos 30 dias como ponto de atenção, com a causa mais provável |
| 3 | Os Eventos críticos com tela azul não tinham botão | O próximo passo leva às Telas azuis |
| 4 | A verificação rápida e o pacote de suporte não traziam as telas azuis | `Stability` no JSON (30 dias, quantas e a mais recente), sem mudar o Status nem o código de saída |
| 5 | O backup antes de formatar ignorava os discos com BitLocker | Avisa os discos além do Windows com BitLocker, que no Windows novo só abrem com a chave, e leva à tela da chave |
| 6 | O Histórico de mudanças não mostrava cada mudança, como o README promete | Passa a anotar a cor de destaque, as teclas do idioma, o reparo de rede, a manutenção agendada, o CHKDSK e a restauração do backup |
| 7 | O atalho do instalador não contava: o Sobre dizia "ainda não criado", e o Criar atalho e o Setup repetiam o do Menu Iniciar | O atalho do instalador conta como atalho desta pasta; o Criar atalho não repete e tira o repetido; o Setup tira o atalho desta conta onde o instalador já pôs o dele |
| 8 | O Sobre não dizia se o WinForge está instalado | Linha "Instalação": instalado (desinstala em Configurações > Aplicativos) ou sem instalar (instala pelo WinForge-Setup.cmd) |
| 9 | Na busca, "bsod" e "reinicia sozinho" iam primeiro para os Eventos críticos, "probar ram" (espanhol) não achava o Teste de memória e "desinstalar winforge" não achava o Sobre | Palavras ajustadas nos três idiomas |

As integrações da revisão de QA (R4) também valem: a auditoria lembra a chave do BitLocker, o relatório tem Telas azuis e memória, o Verificar o PC mostra a saúde do disco e o SHA256SUMS.txt é arquivo do WinForge.

### Para depois (e por quê)

| Lacuna | Por que não agora |
|---|---|
| A saúde do disco e as telas azuis no Início | A leitura do disco leva segundos, e o Início precisa abrir rápido. Vale medir a abertura num PC (`logs\abertura.log`) antes; o monitor e o Verificar o PC já cobrem |
| A saúde do disco na verificação rápida | A leitura do disco é lenta para uma verificação feita para ser rápida |
| O botão de próximo passo em Dispositivos com problema e em Discos e espaço livre | As duas telas já dizem o caminho no texto, que vira link na janela; um botão repetiria |
| A limpeza de componentes (WinSxS), Acelerar agora e Liberar memória no histórico | Não mudam configuração do Windows: limpam ou fecham algo temporário |
| O backup dos arquivos pessoais | Seria uma função nova, e não uma integração |
