# WinForge 4.0 — revisão do Verificar o PC (R27)

**Data:** 20/11/2026 · **Versão:** Build 4.0 em preparação, depois da R26

**Pedido:** juntar quatro olhares para a tela e a função Verificar o PC:
- **Analista de UX/UI Sênior (designer):** revisa cada detalhe da interface e orienta o engenheiro.
- **Especialista Microsoft (MVP Windows):** confere se os comandos e as alterações no Windows são feitos da melhor forma disponível hoje, de modo seguro e robusto, e se fazem sentido e mudam o que devem no PC.
- **QA Sênior:** testa todas as funções da tela.
- **Engenheiro de Software Sênior:** aplica as correções.

**Resultado:** 12 achados, todos corrigidos.

| Olhar | Achados |
|---|---|
| Designer | 4: a faixa genérica em três desfechos; um ponto só dito pelo nome; a lista longa cortada no meio, com o nome dos temporários cheio de vírgulas; e textos que não batiam com o resto do WinForge |
| MVP Windows | 2: a linha Proteção com regra e textos próprios, diferentes da tela aonde ela leva; e o botão da faixa indo ao primeiro ponto das etapas, e não ao mais grave |
| QA | 6: uma correção que falhava sumia da faixa; a limpeza que não tirava nada contava como feita; temporários sem leitura viravam "nada acumulado"; sem Administrador, a correção prometia o que não fazia; o espaço no disco não era lido de novo depois de liberar espaço; e, no menu de texto, a lista sem resposta derrubava a verificação |
| Engenharia | Nenhum próprio: aplicou os 12. |

Nada rodou num Windows de verdade. A conferência foi feita na nuvem, com o Windows simulado: as pastas de temporários eram pastas de verdade, com arquivos de verdade, e a correção os apagou de fato. O que só um PC mostra entrou no roteiro de conferência.

## O Verificar o PC hoje

Ele abre de quatro lugares: o botão da nota de saúde do Início, a linha da página Manutenção, o menu do monitor na bandeja e o aviso "Hora de cuidar do PC" do monitor. Pede Administrador (com o escudo), como na página.

**A leitura**, em 11 etapas, com a barra dizendo qual ("3 de 11: procurando referências quebradas no registro"). Uma etapa que não responde vira "não foi possível ler" e não para as outras.

| Etapa | O que lê | Pede atenção quando |
|---|---|---|
| Espaço no disco | o livre no disco do Windows e a saúde de cada disco | menos de 20 GB livres (menos de 10 GB, quase cheio); um disco com sinal de falha |
| Temporários | os temporários da conta e do Windows com mais de 24 horas, os relatórios de erro e o cache da Otimização de Entrega (os três últimos, com Administrador); à parte, o cache dos navegadores | 50 MB ou mais |
| Registro | as referências quebradas, sem as bibliotecas compartilhadas | nunca: é informação, com a correção desmarcada |
| Atalhos | os atalhos quebrados, sem os do OneDrive | um ou mais |
| Memória | a memória em uso | 85% ou mais |
| Abrem com o Windows | os programas ligados na inicialização | mais de 8 |
| Programas desatualizados | `winget upgrade` | um ou mais |
| Suporte do Windows | a data do fim do suporte e se as atualizações de segurança chegaram | sem suporte, perto do fim ou atualizações atrasadas |
| Proteção | o antivírus, as ameaças, o firewall e as assinaturas | os mesmos pontos da tela Estado da proteção; assinaturas com mais de 7 dias |
| Reinício pendente | os sinais fortes de reinício | um deles |
| Telas azuis | os últimos 30 dias | uma ou mais |

**A lista do que corrigir** ("O que corrigir agora?", com Corrigir e Agora não). O que é seguro vem marcado, e uma frase diz por quê:
- **Apagar os temporários:** o Windows os recria.
- **Enviar os atalhos quebrados para a Lixeira.**
- **Atualizar as assinaturas do antivírus:** só com o Defender ligado.

Desmarcados, à escolha da pessoa: o cache dos navegadores (senhas, cookies e histórico ficam) e as referências do registro (com backup e o desfazer no Histórico de mudanças). O resto vira um ponto com o caminho para a tela que resolve.

**O fim:** o resumo das correções, o espaço liberado e a faixa de resultado, com o botão para a tela do ponto mais importante. A verificação conta como cuidado com o PC, e o Início e o monitor param de lembrar por um mês, quando a maior parte das etapas foi lida e as correções seguras não foram recusadas nem falharam todas.

## Designer (UX/UI)

| # | O que estava | Orientação | Como ficou |
|---|---|---|---|
| D1 | A faixa genérica em três desfechos: com uma etapa sem leitura e o resto em dia, "Concluído com ressalvas"; com todas as correções falhando, "Não foi concluído: Nenhuma correção funcionou", sem dizer qual nem por quê e sem botão; com a maior parte sem leitura, "Não foi concluído", sem o "tente de novo; se continuar, reinicie o PC" que o console diz. | O título diz o que aconteceu; a frase, o porquê e o que fazer. | "Nada pedindo atenção no que foi lido", com "Não foi possível ler: Memória e Telas azuis"; "Nenhuma correção funcionou", com o motivo (ou os nomes) e o botão para a mais importante; "Não foi possível verificar o PC", com o que fazer. Um erro inesperado também tem esse título, com o motivo. |
| D2 | Com um ponto só, a frase dizia só o nome: "1 ponto pede você · Proteção." | Com um ponto só, a frase diz o que ele é. | "Proteção: antivírus desligado, 2 ameaças ativas e firewall desligado (Rede pública)."; "Saúde do disco: WDC WD10EZEX (C: e D:): o Windows marca o disco com problema." |
| D3 | A lista de "ainda pedem você" passava das 220 letras da faixa e era cortada no meio ("…Assinaturas do antivírus, Reinício..."), levando junto o que não foi lido. E o nome "Temporários, relatórios de erro e cache de atualizações", com vírgulas, se misturava com as vírgulas da lista. | A linha e as listas com um nome curto, e a lista longa resumida. | A linha diz "Temporários"; a correção, na lista de marcar, diz o que apaga. A faixa diz os três pontos mais importantes e "e mais 7"; o console continua com todos. |
| D4 | Textos que não batiam com o resto do WinForge: sem o winget, "falta o winget, da Microsoft Store" (as telas de Programas dizem "Instalador de Aplicativo" desde a R21); o cache dos navegadores com uma frase aqui ("carregam mais devagar") e outra na Limpeza personalizada ("abrem mais devagar"); a barra da primeira etapa dizia só "medindo o espaço livre", embora ela leia também a saúde dos discos, que pode levar até 60 segundos com um disco travado; em inglês, "No fix done". | A mesma palavra para a mesma coisa, e a barra dizendo o que de fato acontece. | "não dá para conferir: falta o Instalador de Aplicativo (winget)"; "abrem mais devagar" nos dois lugares; "medindo o espaço livre e conferindo a saúde dos discos"; "No fixes done". |

**Conferido e mantido:**
- **as linhas na ordem das etapas,** com a cor de cada uma (amarelo pede atenção, o resto em cinza): a pessoa acompanha a leitura de cima para baixo;
- **o que é seguro vem marcado,** com a frase do porquê só do que está de fato na lista;
- **"Agora não" não esconde o que foi achado:** a faixa continua com os pontos ("Nenhuma correção feita");
- **o resumo das correções** com uma linha por correção e o espaço liberado.

## Especialista Microsoft (MVP Windows)

| # | O que estava | Por que importa | Como ficou |
|---|---|---|---|
| M1 | A linha Proteção tinha regra e textos próprios: "ameaça ativa no antivírus" com duas ameaças, "firewall desligado em algum perfil" sem dizer qual, "não foi possível confirmar se há um antivírus ativo". A tela Estado da proteção, aonde o botão da linha leva, e o cartão do Início usam outra regra (R16). | A mesma leitura do Defender e do firewall não pode dar dois retratos. O nome do perfil importa: o firewall da rede pública desligado é o que deixa o PC exposto num Wi-Fi de café. | A linha vem dos mesmos pontos da tela (`Get-WinForgeSecurityFindings`), pelo nome curto de cada um: "2 ameaças ativas", "antivírus desligado", "firewall desligado (Rede pública)". |
| M2 | O botão da faixa e a ordem das listas seguiam a ordem das etapas. Com atualizações de segurança faltando, duas telas azuis e o disco com pouco espaço, o botão levava à Limpeza personalizada, porque o espaço no disco é a primeira etapa. | O que põe os arquivos ou o PC em risco vem antes do que só deixa o PC mais cheio ou mais lento. | Do mais grave ao menos, com os pesos do Início onde a nota tem o ponto: disco com sinal de falha, proteção, disco quase cheio, atualizações de segurança e suporte do Windows, telas azuis, pouco espaço, assinaturas, reinício, programas, memória, inicialização, temporários e atalhos. O botão leva ao primeiro. |

**Conferido e mantido**, com as fontes no fim:
- **Os temporários:** só os com mais de 24 horas, e o que está em uso fica. O cache da Otimização de Entrega é esvaziado pelo comando do Windows (`Delete-DeliveryOptimizationCache -Force`), que tira os arquivos e o que o serviço sabe deles. Sem `-IncludePinnedFiles`, os arquivos fixados ficam.
- **Os programas desatualizados:** `winget upgrade --accept-source-agreements` só lista, sem instalar nada, e aceita o contrato da fonte sem a pergunta. É a mesma consulta da tela Atualizar programas. Sem `--include-unknown`, os programas de versão desconhecida ficam de fora, como lá.
- **O registro desmarcado:** a Microsoft não dá suporte a limpadores de registro (o motivo está na R13 e na R14). Quem marcar tem o backup e o desfazer.
- **O firewall:** o perfil de domínio só conta num PC que faz parte de um domínio de empresa. Num PC de casa, ele desligado não deixa nenhuma rede sem firewall, e não é um ponto.
- **As assinaturas:** só com o Defender ligado, e atualizadas com a mesma segunda tentativa da tela (R16). Com outro antivírus, nada.
- **O reinício pendente:** só os sinais fortes (R15).
- **Nada muda antes da lista:** a verificação só lê, e cada correção espera a pessoa marcar.

## QA Sênior

**Como foi testado:** o Verificar o PC rodou nos três idiomas, com o Windows simulado e as pastas de temporários de verdade: 146 conferências em português e 147 em inglês e em espanhol.
- **Cada leitura:**
  - o disco com folga, com pouco espaço, quase cheio e sem leitura, e três discos com dois sinais de falha;
  - os temporários com Administrador (as quatro pastas), sem Administrador, poucos, nenhum, uma pasta ilegível e todas ilegíveis, e o cache dos navegadores grande e pequeno;
  - o registro (limpo, só bibliotecas, com referências), os atalhos (com os do OneDrive e os de todos os usuários);
  - a memória (48%, 92%, sem leitura), a inicialização (8 e 11), o winget (nenhum, 5, falhando, ausente);
  - o Windows em dia, com atualizações atrasadas, com o atraso desconhecido, perto do fim, sem suporte e com o ESU;
  - a proteção em 12 situações, conferida contra a tela Estado da proteção, e as assinaturas nunca atualizadas, com 5 dias e com 9 dias sem Administrador;
  - o reinício e as telas azuis.
- **A verificação inteira, da leitura à faixa,** em 28 situações:
  - tudo em dia, um PC bagunçado aceitando o marcado, recusando e marcando tudo;
  - os temporários em uso, um atalho em uso, as assinaturas e o registro falhando, e todas as correções falhando;
  - a maior parte sem leitura, duas etapas sem leitura e os temporários sem leitura;
  - sem Administrador, sem winget, com o winget falhando, com outro antivírus, com a proteção ruim, com as assinaturas de 5 dias e nunca atualizadas;
  - só correções opcionais, com e sem escolha;
  - o disco que continua cheio e o que volta ao normal depois de liberar espaço;
  - um disco falhando, o Windows sem suporte, só pontos sem correção, tudo de uma vez marcando tudo e a lista sem resposta no menu de texto.

  Em cada uma: o que sai do disco e o que fica, o que vai para a Lixeira e o histórico, a faixa (título, frase, cor e botão) e se conta como cuidado com o PC.
- **A faixa:** o título próprio, a frase dentro das 220 letras e sem corte, nenhum marcador `{0}` sobrando, o botão para um item que existe e, com algo a fazer, sempre um botão.
- **O código:** cada ponto de atenção com peso, todos os destinos existindo e nenhum `catch` vazio.
- **Os textos:** nenhum texto do português na tela em inglês e em espanhol.

**Achados**

| # | O que estava | Como ficou |
|---|---|---|
| Q1 | Uma correção que falhava ao lado de outra que funcionava sumia da faixa. Com o registro recusado e os temporários limpos, a faixa dizia "1 correção feita, 400 MB liberados" e "Nada mais pedindo atenção", em amarelo. Com duas com problema, nenhuma aparecia. | Com uma só, o motivo: "Registro: acesso negado.", com o botão para Limpar o registro. Com mais, "Com problema: Atalhos e Assinaturas do antivírus". Elas não se repetem em "ainda pedem você". |
| Q2 | Com todos os temporários em uso, a limpeza não tirava nada, mas contava como correção feita ("3 correções feitas"), e os temporários saíam de "ainda pede você". | Não conta. A faixa diz "Temporários: nada foi liberado", e o resumo marca a correção como falha. |
| Q3 | Com as pastas de temporários sem leitura (sem permissão), a linha dizia "nada acumulado" e a faixa, "Tudo certo". | "não foi possível ler", e a faixa diz "Nada pedindo atenção no que foi lido · Não foi possível ler: Temporários", como a Limpeza personalizada já fazia. |
| Q4 | Sem Administrador, a linha e a correção diziam "Temporários e relatórios de erro", mas os relatórios de erro pedem Administrador e ficavam de fora. A janela e o menu de texto pedem Administrador antes de verificar, então isso só aconteceria com a verificação chamada sem ele; o código já tratava esse caso, com o nome errado. | A correção diz "Apagar os temporários do usuário", o que de fato apaga. |
| Q5 | Depois de liberar espaço, o espaço no disco continuava "pedindo você", com a leitura de antes, mesmo com o disco já acima do limite. | O disco é lido de novo depois das correções que liberam espaço. A leitura nova aparece no resumo e, acima do limite, o ponto sai da faixa. |
| Q6 | No menu de texto, três respostas que não valiam na lista do que corrigir terminavam a verificação em erro ("Não foi possível verificar o PC: Nenhuma resposta válida foi informada"), e o que ela achou sumia da faixa. | É não corrigir nada: "Nenhuma correção feita", com os pontos na faixa. |

As 49 conferências das correções falham no código de antes e passam no de agora.

## Engenharia

**Por dentro**
- **Checkup.psm1:**
  - `Get-WinForgeCheckupWeight`, `Get-WinForgeCheckupOrder` e `Format-WinForgeCheckupReason` (novas): o peso de cada ponto, a ordem e o motivo curto de uma correção que falhou;
  - `Short` em `New-WinForgeCheckupFinding`: o nome nas listas;
  - `Set-WinForgeCheckupView` reescrita: as correções com problema, um ponto só, a lista curta, o que não foi lido, todas falhando e a maior parte sem leitura;
  - `Get-WinForgeCheckupJunk`: "Temporários", a correção pelo que de fato apaga e a leitura que não respondeu;
  - `Get-WinForgeCheckupProtection` pelos pontos da tela (`Get-WinForgeSecurityFindings`);
  - `Get-WinForgeCheckupDiskSpace` guarda o nível (quase cheio ou pouco espaço);
  - `Invoke-WinForgeCheckupFix`: a limpeza que não tirou nada é uma falha;
  - `Invoke-WinForgeCheckup`: o disco lido de novo, a lista sem resposta e o erro inesperado com título.
- **Traduções:** 8 novas, 11 que saíram de uso e 2 revistas em inglês; 5.344 ao todo.

**Conferido na nuvem**
- **As conferências novas do Verificar o PC, todas passando:** 146 em português e 147 em inglês e em espanhol.

  Cada conferência das correções falha no código de antes e passa no de agora.
- **As 84 ações rodaram de novo 336 vezes** com o Windows simulado: nenhum erro escapou. O resultado é o mesmo da R26, fora o Verificar o PC, que agora põe a Proteção antes do Suporte do Windows e leva o botão a ela.
- **As de antes continuam passando:**
  - as 109, 98 e 101 da Busca e as 164, 169 e 169 do Sobre o WinForge;
  - as 265, 270 e 270 da Personalização, as 412, 422 e 422 dos Ajustes do Windows, as 144, 153 e 153 da Rede, as 106, 115 e 115 dos Programas, as 110, 117 e 117 das Atualizações, as 112, 119 e 119 do Reparo, as 96, 102 e 102 do Desempenho, as 178, 187 e 187 da Limpeza, as 134, 142 e 142 da Segurança e as 212, 224 e 224 do Diagnóstico;
  - as 245, 247 e 252 da Manutenção, com o Verificar o PC de antes (o veredito, o que conta como verificação e o registro desmarcado), e as 241 do Início nos três idiomas, com as assinaturas nunca atualizadas que o Verificar o PC também oferece;
  - as 83 do QA geral, as 80 da R11 e as 60 da R12;
  - as 59 da R9 e as 52 da R10;
  - as 66 da QA, as 28 da integração (a etapa das telas azuis) e as 26 da R7;
  - o motor de instalação, a atualização simulada e o Setup de verdade (da R26 para esta), e o pacote de suporte;
  - as traduções (5.344/5.344), as 159 referências nos três idiomas e a busca dos 102 itens;
  - nenhuma chamada com parâmetro que não existe, nenhuma função sem uso e nenhum aviso novo do analisador.

## O que só um PC mostra

Isto entrou no roteiro de conferência:
- **A faixa num PC usado:** o botão leva ao ponto mais importante, e a frase resume a lista.
- **A linha Proteção igual ao Estado da proteção,** com o firewall de uma rede desligado.
- **Liberar espaço com o disco perto do limite:** a leitura nova no resumo.
- **Os temporários em uso:** a faixa diz que nada foi liberado.

## Fontes
- [upgrade command (winget)](https://learn.microsoft.com/en-au/windows/package-manager/winget/upgrade) (Microsoft): sem argumentos, o `winget upgrade` só lista as atualizações; `--accept-source-agreements` aceita o contrato da fonte sem a pergunta; sem `--include-unknown`, os programas de versão desconhecida ficam de fora.
- [Monitor Delivery Optimization](https://learn.microsoft.com/windows/deployment/do/waas-delivery-optimization-monitor) (Microsoft): `Delete-DeliveryOptimizationCache` esvazia o cache e o que o serviço guarda dos arquivos; `-Force` dispensa a pergunta; `-IncludePinnedFiles` tiraria também os fixados.
- [Windows Firewall Profiles](https://learn.microsoft.com/en-us/previous-versions/windows/desktop/ics/windows-firewall-profiles) (Microsoft): o perfil de domínio vale onde o PC se autentica num controlador de domínio; o público, nas redes públicas, como o Wi-Fi de um café.
