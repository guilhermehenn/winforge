# WinForge 4.0 — segunda revisão da Limpeza (R42)

**Data:** 21/11/2026 · **Versão:** Build 4.0 em preparação, depois da R41

**Pedido:** revisar a tela e a função Limpeza com cinco olhares:
- **Analista de Produto Sênior:** avalia o todo.
- **Engenheiro de Software Sênior:** revisa o código, refatora, segue as boas práticas, tira o que não serve e melhora o desempenho.
- **Designer Sênior, com um Especialista em UX/UI:** revisam a tela, os botões, os textos e os fluxos; o engenheiro aplica.
- **MVP Windows:** confere se a Limpeza segue as práticas da Microsoft, se cada função faz da melhor forma o que promete e se é robusta e estável.
- **QA Sênior:** testa tudo o que dá para testar, o óbvio e o que não é; o engenheiro aplica.

**De onde partiu:** a primeira revisão da Limpeza (R17) foi antes do desenho novo (R37) e da revisão de UX (R38). Esta olhou a página inteira de hoje, os caminhos que levam a ela (o Início, a Verificação do PC, o monitor na bandeja) e as faixas de cada ação.

**Resultado:** 8 achados, todos corrigidos.

| Olhar | Achados |
|---|---|
| Produto | 1: o disco cheio tinha dois conselhos (o Início e a Verificação do PC mandavam para a Limpeza personalizada; a faixa da página e o aviso do monitor, para a Limpeza rápida) |
| Engenharia | 2: uma pergunta e um bloco que nunca apareciam na limpeza dos temporários; e a soma do tamanho das pastas, cinco vezes mais lenta do que precisava |
| Designer e UX/UI | 2: as faixas "Tudo certo · Liberou 0 B" quando o que saiu estava vazio; e os botões Sim e Não nas perguntas que apagam |
| MVP Windows | 1: Configurações de armazenamento dizia abrir o Sensor de Armazenamento, mas abre a página Armazenamento |
| QA | 2: o aviso de outra conta nos Downloads com palavras de técnico; e o registro com ressalva sem o botão do desfazer |

Nada rodou num Windows de verdade. A conferência foi feita na nuvem: a página com as funções de verdade da janela sobre o WPF simulado, e as ações com arquivos de verdade numa pasta temporária e o Windows simulado. O que só um PC mostra entrou no roteiro de conferência (§33).

## A Limpeza hoje

De cima para baixo:
1. **Disco do sistema:** a faixa do alto, com o espaço livre; com pouco espaço, em amarelo e com a seta que abre a Limpeza personalizada (novo).
2. **Limpeza rápida,** em destaque, com "Limpar agora".
3. **Liberar espaço:** Analisar uso de espaço, Limpeza personalizada, Esvaziar a Lixeira, Limpar a pasta Downloads e Configurações de armazenamento (a página do Windows).
4. **Arrumar o que sobrou:** Remover atalhos quebrados, Encontrar arquivos duplicados e Restos de programas desinstalados.
5. **Avançado:** Limpar o registro, Limpar componentes do Windows (WinSxS) e Apagar o espaço livre.

## Analista de Produto

| # | O que estava | Por que importa | Como ficou |
|---|---|---|---|
| P1 | Com o disco quase cheio, o Início ("Liberar espaço") e a Verificação do PC levavam à Limpeza personalizada. A faixa da página dizia "espaço crítico; comece pela Limpeza rápida", e o aviso do monitor, "Clique para fazer uma limpeza rápida". | A Limpeza rápida só tira os temporários (e a Lixeira, se a pessoa quiser). Com o disco cheio, o que mais rende costuma estar no resto: o cache de atualizações, os relatórios de erro, os despejos de memória, o cache dos navegadores. A Limpeza personalizada mede tudo isso e já vem com o que o Windows refaz sozinho marcado. Dois conselhos para o mesmo problema confundem. | Um conselho só, a Limpeza personalizada. Com pouco espaço, a faixa da página diz "6 GB livres de 476 GB · quase cheio", em amarelo, e é um botão com a seta que a abre, como a faixa da Manutenção (R41). O aviso do monitor diz "Clique para ver o que dá para apagar" e abre a mesma tela. Com espaço, a faixa continua como era, sem botão. |

**Conferido e mantido:**
- **Um destaque só (Limpeza rápida)** e os três grupos, do mais seguro ao mais profundo.
- **A Limpeza rápida no menu do ícone do monitor:** é a limpeza do dia a dia, sem pergunta de escolha.
- **A busca por "sem espaço"** continua trazendo a Limpeza rápida primeiro (R26). A ordem da busca por "limpar" é a UX26 da revisão de UX e fica para a decisão dela: a página Limpeza vem primeiro, e o Enter a abre.

## Engenheiro de Software

| # | O que estava | Como ficou |
|---|---|---|
| E1 | A limpeza de uma pasta de temporários (`Invoke-WinForgeFolderCleanup`) tinha uma pergunta ("Deseja limpar estes arquivos?"), notas e o cancelamento só para quando rodasse sozinha. Ela nunca roda sozinha: a Limpeza rápida e o Acelerar agora a chamam por dentro, com a pergunta deles. | Saíram a pergunta, as notas e os parâmetros `-Notes`, `-Embedded` e `-PassThru`. `Clear-WinForgeUserTemp` e `Clear-WinForgeWindowsTemp` devolvem o resultado direto, e quem chama não passa mais os dois parâmetros. Dois textos de tradução saíram de uso. |
| E2 | `Get-WinForgePathStats`, que soma o tamanho de uma pasta, chamava um bloco de código a cada arquivo e somava nas propriedades de um objeto. Analisar uso de espaço passa por cada arquivo do perfil; os Restos de programas, a Lixeira e a etapa das pastas pessoais do Otimizar também usam a soma. | A soma fica em variáveis locais, sem bloco por arquivo, com o mesmo resultado (tamanho, contagem e data, conferidos contra a versão de antes em sete casos). Numa pasta de 8.000 arquivos, de 690 ms para 56 ms; numa de 60.000, de cerca de 850 ms para 150 ms. |

**Por dentro:**
- **Cleanup.psm1:**
  - `Get-WinForgeCleanupPageStatus` devolve `Opens` (a Limpeza personalizada com pouco espaço);
  - `Get-WinForgeCleanupZeroNote` (nova): a frase da faixa quando nada de espaço volta;
  - `Clear-WinForgeRecycleBin` decide "já estava vazia" por um dado do resultado (`AlreadyEmpty`), e não comparando o texto traduzido;
  - `Invoke-WinForgeCleanupTargets` devolve `Data.Unmeasured`, o que foi limpo sem medida;
  - os verbos nas perguntas e o aviso de outra conta nos Downloads.
- **Core.psm1:** `Get-WinForgePathStats` sem bloco por arquivo.
- **Repair.psm1:** `Invoke-WinForgeTool` aceita `-YesLabel` e `-NoLabel` e os passa à pergunta.
- **Agent.psm1:** o aviso de pouco espaço abre a Limpeza personalizada, e ela entra na lista de ações que a janela aceita do monitor (só mostra a lista de escolha: nada muda sem um clique).
- **CleanupTools.psm1 e RegistryCleaner.psm1:** os verbos nas perguntas; o botão do desfazer na ressalva do registro.
- **Navigation.psm1 e Shortcuts.psm1:** os textos de Configurações de armazenamento.
- **Traduções:** 5.567 textos (9 novos, 7 que saíram de uso e 1 que voltou).

## Designer e Especialista em UX/UI

| # | O que estava | Orientação | Como ficou |
|---|---|---|---|
| D1 | Quando o que saía não ocupava espaço (pastas vazias e arquivos de 0 bytes, comuns nos temporários e na Lixeira), a faixa dizia "Tudo certo" e "Liberou 0 B": na Limpeza rápida, em Esvaziar a Lixeira, na Limpeza personalizada e na exclusão permanente dos Downloads. Com uma parte sem medida, também. | A faixa diz o que aconteceu e por que o número não aparece. | A Limpeza rápida e a personalizada dizem "Limpeza concluída"; a Lixeira, "Lixeira esvaziada"; os Downloads, "2 itens excluídos". Embaixo, "O que saiu estava vazio: o espaço livre não mudou." ou, com uma parte sem medida, "O espaço liberado não pôde ser medido.". Na personalizada com algo liberado e uma parte sem medida, a frase termina em "O total não inclui …", como na Limpeza rápida. |
| D2 | As perguntas que apagam tinham os botões Sim e Não. É a UX21 da revisão de UX, aplicada nesta página. | Os botões dizem o que fazem, como a Microsoft orienta ("Use specific responses to the main instruction or content as button text"). | "Esvaziar" e "Cancelar" (Esvaziar a Lixeira); "Limpar" e "Cancelar" (Limpeza rápida, personalizada e componentes); "Excluir" e "Cancelar" (exclusão permanente dos Downloads); "Enviar para a Lixeira" e "Cancelar" (duplicados e restos); "Apagar o espaço livre" e "Cancelar"; "Apagar" e "Manter" (a sobra de uma gravação interrompida); "Remover" e "Cancelar" (registro). O padrão e a cor de perigo de cada uma não mudaram, e o menu de texto continua com S/N. |

**Conferido e mantido:**
- **As descrições** cabem em 60 letras nos três idiomas.
- **O escudo** nas quatro ações que pedem Administrador (Limpeza rápida, personalizada, componentes e espaço livre).
- **As perguntas que apagam sem volta começam no Cancelar,** com o botão do verbo em vermelho; as que têm volta, no verbo.
- **A faixa sem pouco espaço** fica como era, sem botão: a Análise de espaço já está logo abaixo, na lista.

## MVP Windows

| # | O que estava | Por que importa | Como ficou |
|---|---|---|---|
| M1 | Configurações de armazenamento abre `ms-settings:storagesense`, e a descrição dizia "Abre o Sensor de Armazenamento, nas Configurações". | Na tabela da Microsoft, `ms-settings:storagesense` é a página Storage (Armazenamento); a do Sensor de Armazenamento é `ms-settings:storagepolicies`. A página Armazenamento é a certa para o item (é onde ficam os arquivos temporários e as instalações anteriores do Windows, que a Análise de espaço aponta), mas a frase prometia outra. | "Abre a página Armazenamento, nas Configurações", e a frase inteira diz que lá ficam os arquivos temporários e o Sensor de Armazenamento. O endereço não mudou. |

**Conferido e mantido**, com as fontes no fim:
- **Esvaziar a Lixeira** pelo `Clear-RecycleBin -Force`: "deletes the content of the current user's recycle bin", em todas as unidades, sem a pergunta do Windows.
- **O limite da Lixeira** que decide o que pode ir para ela: o padrão do Windows desde o Vista, "ten percent of the first 40 GB of quota, and five percent of any quota above 40 GB", é o que o WinForge calcula quando não há política nem configuração da unidade.
- **O cache da Otimização de Entrega** pelo `Delete-DeliveryOptimizationCache -Force` ("deletes the cache with no prompts"), sem `-IncludePinnedFiles`: o que uma empresa fixou no cache fica.
- **O restante da R17 continua valendo:** os temporários com mais de 24 horas, o DISM sem `/ResetBase` e com a conferência do reinício pendente, o `cipher /w` com a sobra apagada, os despejos de memória nos lugares padrão, e duplicados, restos e atalhos sempre pela Lixeira.

## QA Sênior

**Como foi testado:** uma bateria nova da Limpeza, com a página montada pelas funções de verdade da janela sobre o WPF simulado e as ações com arquivos de verdade numa pasta temporária e o Windows simulado: 97 conferências em cada idioma.
- **O disco cheio (A):** a faixa com espaço, com pouco espaço e quase cheio (a cor, o botão, a seta, a altura, o leitor de tela e o clique), sem a leitura do disco; o Início, a Verificação do PC, a faixa e o aviso do monitor levando ao mesmo lugar; toda ação que o monitor pede aceita pela janela.
- **Quando nada volta (B):** a Limpeza rápida com pastas e arquivos vazios e com a Lixeira sem medida; Esvaziar a Lixeira só com arquivos vazios, com o que liberar, vazia, esvaziada por outra janela no meio e sem medida; a personalizada com a Lixeira vazia de bytes, a Lixeira sem medida, o cache esvaziado numa pasta ilegível, uma parte sem medida e o que liberar; a exclusão dos Downloads com arquivos vazios e com o que liberar.
- **Os botões (C):** as dez perguntas, cada uma com o verbo, o padrão e a cor; o Cancelar de cada uma sem apagar nada; a pergunta na janela de verdade; o código sem pergunta de Sim e Não.
- **O código e a soma (D):** a pergunta que nunca aparecia fora; os temporários com um resultado só, o recente que fica e a pasta recusada; a soma igual à de antes em sete casos, sem seguir o atalho de pasta, e mais rápida.
- **Configurações de armazenamento (E)**, **outra conta e o registro (F)** e **os textos (K)** nos três idiomas.

**Achados**

| # | O que estava | Como ficou |
|---|---|---|
| Q1 | Com o WinForge aberto com outra conta, Limpar a pasta Downloads dizia "Elevado com outra conta: esta é a pasta Downloads de ana, não a do usuário logado.". As outras telas da Limpeza dizem isso de outro jeito, sem palavras de técnico. | O mesmo aviso das outras: "O WinForge está aberto com outra conta (ana): a pasta Downloads é a dessa conta, não a de quem está usando o Windows." |
| Q2 | Em Limpar o registro, quando uma referência não podia ser removida, a faixa da ressalva perdia o botão Histórico de mudanças, embora as outras tivessem saído com o desfazer. É o mesmo caso que a R17 corrigiu no botão da Lixeira. | A ressalva continua com o título e a frase dela, e o botão entra. Sem nada removido, sem botão. |

Os testes também acharam os do produto (P1), do designer (D1 e D2) e o do MVP (M1).

**Contra o código de antes (R41):** cada conferência das correções falha, e as que conferem o que foi mantido passam. A faixa para depois do primeiro caso de pouco espaço, porque ela não tem botão.

**42 defeitos de propósito,** e as conferências pegam todos: a faixa sem destino, levando à Limpeza rápida, com a frase antiga ou com botão com espaço; o aviso do monitor na Limpeza rápida, com a frase antiga ou recusado pela janela; cada faixa de "nada voltou" tirada, ignorando o que não foi medido, com a frase trocada ou sem a marca de "já estava vazia"; cada pergunta de volta ao Sim e Não, a Lixeira sem a cor de perigo e a ferramenta sem repassar os verbos; a soma contando os metadados, seguindo o atalho de pasta, com a data errada, a contagem em outro tipo ou com o bloco por arquivo de volta; a frase antiga de Armazenamento; o aviso antigo nos Downloads; o registro com ressalva sem o botão ou sem a frase dela; e a pergunta escondida de volta.

**Nada do que funcionava quebrou:** a bateria da Limpeza da R17 (178, 187 e 187) e as das outras 13 páginas revistas, com os mesmos números da R41 (a Rede com a mesma conferência antiga); a do Início da R40 (115) e a da Manutenção da R41 (67) em cada idioma; a da Manutenção da R14 (243, 245 e 250) e a do Início da R13 (241); as mensagens da janela (72 em cada idioma); instalar, atualizar com um clique, o pacote de suporte e o Setup de verdade, da R41 para esta; nenhum aviso novo do PSScriptAnalyzer (247, um a menos) e nenhuma função sem uso (1.505).

## O que só um PC mostra

Isto entrou no roteiro de conferência (§33):
- **A faixa com o disco quase cheio,** nos dois temas, com o mouse, o teclado e o Narrador, e o aviso do monitor de pouco espaço.
- **Os botões das perguntas** nos três idiomas, sem cortar o texto ("Enviar a la Papelera de reciclaje" é o mais longo).
- **A Limpeza rápida num PC usado:** quanto ela libera, e a faixa quando os temporários só têm pastas vazias.
- **Analisar uso de espaço:** o tempo da soma do perfil, antes e depois, e a pasta do OneDrive na lista das maiores pastas.

## Fontes
- [Launch the Windows Settings app](https://learn.microsoft.com/en-us/windows/apps/develop/launch/launch-settings) (Microsoft): Storage é `ms-settings:storagesense`; Storage Sense é `ms-settings:storagepolicies`.
- [Clear-RecycleBin](https://learn.microsoft.com/powershell/module/microsoft.powershell.management/clear-recyclebin) (Microsoft): "deletes the content of the current user's recycle bin"; `-Force` dispensa a confirmação.
- [What is the default size of the Recycle Bin?](https://devblogs.microsoft.com/oldnewthing/20140701-00/?p=603) (Raymond Chen, The Old New Thing, Microsoft): no Windows Vista e depois, "ten percent of the first 40 GB of quota, and five percent of any quota above 40 GB".
- [Monitor Delivery Optimization](https://learn.microsoft.com/windows/deployment/do/waas-delivery-optimization-monitor) (Microsoft): `Delete-DeliveryOptimizationCache` "lets you clear files from the cache"; `-Force` "deletes the cache with no prompts"; `-IncludePinnedFiles` apaga também os fixados.
- [Dialog controls](https://learn.microsoft.com/windows/apps/design/controls/dialogs-and-flyouts/dialogs) (Microsoft): "Use specific responses to the main instruction or content as button text"; o exemplo de excluir um arquivo usa "Delete" e "Cancel".
