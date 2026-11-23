# WinForge 4.0 — revisão da Limpeza (R17)

**Data:** 19/11/2026 · **Versão:** Build 4.0 em preparação, depois da R16

**Pedido:** juntar quatro olhares para a tela e a função de Limpeza:
- **Analista de UX/UI Sênior (designer):** revisa cada detalhe da interface e orienta o engenheiro.
- **Especialista Microsoft (MVP Windows):** confere se os comandos e as alterações no Windows são feitos da melhor forma disponível hoje, de modo seguro e robusto, e se fazem sentido e mudam o que devem no PC.
- **QA Sênior:** testa todas as funções da tela.
- **Engenheiro de Software Sênior:** aplica as correções.

**Resultado:** 12 achados, todos corrigidos.

| Olhar | Achados |
|---|---|
| Designer | 8: as faixas que diziam só "Concluído" depois de liberar espaço, a ressalva da Limpeza rápida que não dizia qual parte falhou, a Lixeira oferecida nos Downloads de um pendrive, o botão da Lixeira que sumia numa ressalva, a seção da Lixeira vazia no resumo, a análise sem o disco lido, a faixa do registro sem o desfazer e a linha "Itens ignorados 0" |
| MVP Windows | 1: a limpeza dos componentes rodava o DISM mesmo com uma atualização esperando reinício, e a falha chegava como um código |
| QA | 3 novos: a pergunta dos restos de programas no masculino ("os 3 pastas marcados"), a barra da limpeza dos Downloads em português nas outras telas e os motivos de "sem Lixeira" que, em inglês, não se liam ("The Downloads folder it is on..."). Os testes também acharam três dos acima (D2, D3 e M1). |
| Engenharia | Nenhum próprio: aplicou os 12. |

Nada rodou num Windows de verdade. Os arquivos foram criados e apagados de verdade numa pasta da nuvem; o Windows (a Lixeira, o DISM, o cipher, o registro e o WMI) foi simulado. O que só um PC mostra entrou no roteiro de conferência.

## A Limpeza hoje

A página tem, de cima para baixo:
1. **Liberar espaço:**
   - Limpeza rápida, em destaque ("Limpar agora");
   - Analisar uso de espaço;
   - Limpeza personalizada;
   - Esvaziar a Lixeira;
   - Limpar a pasta Downloads;
   - Configurações de armazenamento, que abre a página de Armazenamento do Windows.
2. **Arrumar o que sobrou:**
   - Remover atalhos quebrados;
   - Encontrar arquivos duplicados;
   - Restos de programas desinstalados.
3. **Avançado:**
   - Limpar o registro;
   - Limpar componentes do Windows (WinSxS);
   - Apagar o espaço livre.

A Limpeza rápida, a personalizada, os componentes e o espaço livre pedem Administrador e mostram o escudo.

Quase tudo aqui apaga algo, e cada ação decide se há volta:
- **vão para a Lixeira:** os Downloads (a escolha recomendada), os atalhos quebrados, os duplicados e os restos de programas;
- **saem em definitivo, com a pergunta no Não:** a Lixeira, os despejos de memória, os Downloads quando a pessoa escolhe a exclusão permanente e o espaço livre;
- **saem sem volta, mas se refazem sozinhos:** os temporários, os caches e os relatórios de erro;
- **o registro:** sai com um backup `.reg` e fica no Histórico de mudanças.

A análise de espaço e o resumo da página só leem.

## Designer (UX/UI)

| # | O que estava | Orientação | Como ficou |
|---|---|---|---|
| D1 | A Limpeza rápida dizia "4 MB liberados" na faixa. As outras ações que liberam espaço diziam só "Concluído", com o total na frase de baixo: Esvaziar a Lixeira, a Limpeza personalizada, a exclusão permanente dos Downloads e os componentes. A Lixeira vazia e os Downloads sem nada para tirar também diziam "Concluído". | O que libera espaço diz quanto no título, como a Limpeza rápida. O que não tinha nada diz isso. | "6 MB liberados" com "Lixeira esvaziada." embaixo; na personalizada, de onde saiu ("Temporários do usuário e Relatórios de erro do Windows."); nos Downloads, "4 itens excluídos, sem passar pela Lixeira."; nos componentes, "Cerca de 2 GB liberados", com como foi medido, ou "Quase nada a liberar", com a frase de que o Windows já faz essa limpeza sozinho. Sem nada, "Nada para limpar", com o porquê. |
| D2 | Quando uma parte da Limpeza rápida falhava, a faixa dizia "Concluído com ressalvas" e "1 de 3 partes falhou; liberou 1 MB", sem dizer qual. Com tudo em uso, "Concluído com ressalvas" e "liberou 0 B". | A faixa diz quanto saiu e o que ficou para trás. | "1 MB liberados" e "Não foi possível limpar os temporários do Windows."; com tudo em uso, "Nada foi liberado" e "Itens em uso ficaram: feche os programas e tente de novo." O detalhe nomeia a parte. |
| D3 | Com a pasta Downloads num pendrive, numa unidade de rede ou com a Lixeira desligada, a tela oferecia "Enviar para a Lixeira". Depois da escolha, dizia que nada tinha saído e mandava abrir de novo e escolher a exclusão permanente. O aviso de que itens maiores que o limite da Lixeira ficariam também vinha depois da escolha, quando a pessoa já não podia decidir. | Sem Lixeira, a opção nem aparece. O que muda a decisão vem antes da pergunta. | Sem Lixeira, a tela diz por quê antes e oferece só "Excluir permanentemente", com a confirmação no Não, ou Cancelar. O aviso do limite vem antes da escolha. |
| D4 | Nos Downloads, nos duplicados e nos restos de programas, uma ressalva (um item em uso, uma cópia que mudou) tirava o botão "Esvaziar a Lixeira" da faixa. O que tinha ido para a Lixeira continuava ocupando espaço. | O botão fica sempre que algo foi para a Lixeira. | A faixa da ressalva diz o que ficou e mantém o botão. |
| D5 | Na Limpeza rápida com a Lixeira vazia, a pergunta era só dos temporários, mas o resumo ganhava a seção "Esvaziar a Lixeira — A Lixeira já está vazia". | O resumo mostra o que foi pedido. | Com a Lixeira vazia, não há a seção. |
| D6 | Na análise de espaço sem a leitura do disco, a faixa perdia o que a Limpeza personalizada liberaria e o botão para abri-la. | Faltar uma leitura não apaga as outras. | "Disco do sistema não lido", com o que a limpeza libera e o botão. |
| D7 | Em Limpar o registro, a faixa dizia "Concluído", e o desfazer só aparecia no texto. | A faixa diz quantas saíram e leva ao desfazer. | "3 referências removidas", com o botão Histórico de mudanças. |
| D8 | Nos Downloads, a linha "Itens ignorados" aparecia com 0. | Só o que diz algo. | A linha aparece só quando algum item ficou. |

**Conferido e mantido:**
- um destaque só na página, a Limpeza rápida, e as descrições em até 60 letras nos três idiomas;
- o escudo nas quatro ações que pedem Administrador;
- as perguntas começam no lugar seguro:
  - esvaziar a Lixeira, a exclusão permanente dos Downloads, os duplicados, os restos e o espaço livre, no Não;
  - a personalizada, no Não quando inclui a Lixeira ou os despejos de memória, que não têm volta;
  - "Onde procurar?" dos duplicados e a unidade do espaço livre, em Cancelar;
  - na Limpeza rápida, "Só os temporários" em destaque, e "Temporários e Lixeira" marcado como perigo;
- nos duplicados e nos restos, nada vem marcado; nos atalhos, o que está no OneDrive vem desmarcado, com o aviso de que sai dos outros PCs;
- o registro diz, antes de tudo, que não deixa o PC mais rápido.

## Especialista Microsoft (MVP Windows)

**O que mudou**

| # | O que estava | Por que não é o melhor | Como ficou |
|---|---|---|---|
| M1 | Limpar componentes do Windows, sozinha, rodava o `DISM /StartComponentCleanup` mesmo com uma atualização esperando reinício. | O DISM recusa a limpeza nesse estado, depois de minutos, com 0x800F0806 ("The operation could not be completed due to pending operations"). A tela dizia só "código de saída 0x800F0806". O reparo (DISM e SFC) já conferia isso antes de rodar; a limpeza, não. | Confere antes, pelo mesmo teste do reparo. Com um reinício pendente, o DISM não roda: a tela diz por quê, e a faixa diz "Reinicie antes de limpar" e oferece reiniciar, com o Não como padrão. Se o DISM ainda responder 0x800F0806 (ou 0x800F082F e 3017, do mesmo caso), a tela diz que falta reiniciar, e não só o código. No Otimizar, quem confere isso é o próprio Otimizar, como antes. |

**Cada comando, conferido**

| Função | Como o WinForge faz | Veredito |
|---|---|---|
| Limpeza rápida | Os temporários do usuário (`%TEMP%`) e os do Windows (`Windows\Temp`), só o que tem mais de 24 horas pela criação, pela alteração e pelo item mais novo de dentro de cada pasta. Não segue atalhos de pasta (junções e links). Recusa a pasta se `%TEMP%` apontar para o perfil, uma pasta pessoal ou o sistema. O que está em uso fica. A Lixeira entra só com a escolha da pessoa. | Certo, com o D2 e o D5. |
| Esvaziar a Lixeira | `Clear-RecycleBin -Force`: a Lixeira de quem está usando o Windows, em todas as unidades. A medida vem das pastas `$Recycle.Bin` do usuário. O erro do Windows para a Lixeira já vazia vira "já estava vazia". | Certo, com o D1. |
| Limpar a pasta Downloads | A pasta real vem do registro (User Shell Folders), e é recusada se apontar para o perfil ou outra pasta pessoal. "O que é mais antigo" usa a criação e a alteração; o `desktop.ini` fica. A Lixeira é pelo `Microsoft.VisualBasic` (`SendToRecycleBin`). Antes, o WinForge confere: os itens em uso; a Lixeira da unidade (pendrive, rede, CD, Lixeira desligada); e o limite dela, pela política, pela configuração da unidade e pelo padrão do Windows. | Certo, com o D3. |
| Analisar uso de espaço | Só lê: o espaço do disco, o que cada alvo da personalizada libera, as maiores pastas do perfil e os arquivos grandes do sistema (hibernação, memória virtual, arquivo de troca, `Windows.old`, os downloads do Windows Update e o despejo de tela azul), cada um com o que fazer. | Certo, com o D6. |
| Limpeza personalizada | Os alvos, cada um com o tamanho, marcados por padrão os que se refazem sozinhos:<br>- **temporários:** do usuário e do Windows;<br>- **relatórios de erro:** `WER\ReportArchive` e `ReportQueue`;<br>- **Otimização de Entrega:** `Delete-DeliveryOptimizationCache`, e a pasta se o comando falhar.<br>Desmarcados:<br>- **cache dos navegadores:** só o cache, sem histórico, senhas ou cookies;<br>- **cache de sombreadores:** DirectX, NVIDIA e AMD;<br>- **despejos de memória:** `CrashDumps`, `Minidump` e `MEMORY.DMP`;<br>- **a Lixeira.**<br>Os despejos e a Lixeira mudam a pergunta para o Não. | Certo, com o D1. |
| Atalhos quebrados | Área de Trabalho e Menu Iniciar, do usuário e de todos os usuários. Só entra o atalho cujo destino num disco fixo não existe nem na tradução de 32 bits. Os atalhos do Windows Installer, de rede, de pendrive e da Store ficam de fora. Vão para a Lixeira e ficam no Histórico de mudanças. | Certo. |
| Arquivos duplicados | Arquivos de 1 MB ou mais, sem os ocultos e os do sistema, comparados pelo tamanho, depois por uma amostra e, por último, pelo SHA-256 do arquivo inteiro. O mais antigo de cada grupo fica. Antes de mover, a cópia e o original são conferidos de novo: o que mudou depois da busca fica. As pastas do sistema e de programas são recusadas. | Certo, com o D4. |
| Restos de programas | Só dos programas desinstalados pelo WinForge: pastas com o nome exato do programa, ou com o nome tirado do ID do winget dentro da pasta do fabricante (`Mozilla\Firefox`), desde que nenhum programa instalado tenha esse nome. Nomes genéricos (como "Update") e as pastas do Windows e da Microsoft ficam de fora. As pastas de Arquivos de Programas e ProgramData pedem Administrador; as do AppData vêm com o aviso de que guardam configurações. | Certo, com o Q1. |
| Limpar o registro | Só referências a arquivos que não existem: desinstaladores, inicialização, nomes de programas (App Paths), o cache de nomes do Explorador, arquivos de ajuda, fontes e bibliotecas compartilhadas (estas, desmarcadas). Antes, um backup por `reg export`; depois, o Histórico de mudanças. Sem Administrador, só o que é do usuário. | Certo, com o D7. |
| Limpar componentes | `DISM /Online /Cleanup-Image /StartComponentCleanup`, sem `/ResetBase`. O espaço é medido no disco, antes e depois. | Certo, com o M1. |
| Apagar o espaço livre | `cipher /w:X:\` na unidade escolhida, que diz se é a do Windows e se é SSD ou HD. Uma pasta `EFSTMPWP` que sobrou de uma vez interrompida é apagada antes, e também depois de um erro. | Certo. |
| Configurações de armazenamento | `ms-settings:storagesense`, a página de Armazenamento, onde fica o Sensor de Armazenamento. | Certo. |

**Conferido e mantido**
- **Sem `/ResetBase` nos componentes:** com ele, as atualizações já instaladas não podem mais ser desinstaladas. O `/StartComponentCleanup` sozinho tira na hora as versões substituídas, sem os 30 dias que a tarefa automática do Windows espera.
- **O DISM e o cipher sem tempo-limite:** são longos, a pessoa espera com a barra de andamento, e o Parar interrompe.
- **Os despejos de memória pelos lugares padrão do Windows:** um lugar trocado à mão fica de fora, de propósito. Limpar uma pasta configurada por alguém poderia levar o que não é despejo.
- **Duplicados, restos e atalhos sempre pela Lixeira**, e a recusa quando a unidade não tem Lixeira: o Windows apagaria em definitivo.
- **Temporários só com mais de 24 horas:** um instalador ou uma atualização em andamento não perde o que acabou de escrever.

## QA Sênior

**Como foi testado:** cada função da página rodou com arquivos de verdade numa pasta da nuvem e o Windows simulado, nos três idiomas: 178 conferências em português e 187 em inglês e em espanhol. As 9 a mais conferem, em cada seção, que nenhum texto do português aparece na tela.
- **Limpeza rápida (22):**
  - nada para limpar;
  - só temporários, com a Lixeira vazia;
  - a Lixeira com itens: o padrão, "Temporários e Lixeira" e Cancelar;
  - a Lixeira sem medida;
  - a pasta do Windows ilegível;
  - tudo em uso;
  - outra conta;
  - no Otimizar;
  - `%TEMP%` apontando para Documentos.
- **Esvaziar a Lixeira (12):** cancelar no padrão, esvaziar, já vazia, sem medida, o erro de "já vazia" do Windows, uma falha e outra conta.
- **Downloads (24):**
  - vazia;
  - os mais antigos para a Lixeira, com 30 e 45 dias;
  - nada com mais de um ano;
  - três valores inválidos;
  - "Tudo" em definitivo, com Não e com Sim;
  - um item em uso;
  - sem Lixeira, ao cancelar e na exclusão permanente;
  - o limite da Lixeira;
  - a pasta redirecionada para o perfil e a que não existe;
  - o andamento no idioma da tela.
- **Análise de espaço e resumo da página (13):** normal, pouco espaço, o disco sem leitura, sem Administrador, nada acumulado e o resumo em quatro níveis.
- **Limpeza personalizada (15):**
  - sem Administrador;
  - o padrão;
  - o que não tem volta, com Não e com Sim;
  - nada marcado;
  - o cache em uso;
  - nada acumulado;
  - a Otimização de Entrega, com o comando e sem ele;
  - os alvos vindos do Verificar o PC.
- **Atalhos e duplicados (21):**
  - os atalhos: nenhum quebrado, os três tipos, em uso, só os de todos os usuários e nada marcado;
  - os duplicados: o conteúdo de verdade, o mais antigo que fica, Não, Sim, o original que mudou depois da busca, as pastas recusadas, sem Lixeira, nenhum duplicado e "Onde procurar?".
- **Restos de programas e registro (16):**
  - os restos: nenhum programa, sem Administrador, nomes genéricos, todas e Não;
  - o registro: nada, o padrão, sem Administrador e cancelar.
- **Componentes e espaço livre (18):**
  - os componentes: sem Administrador, liberou, quase nada, o reinício pendente, o 0x800F0806 e o Otimizar;
  - o espaço livre: sem Administrador, cancelar, Não, a unidade D:, um erro, a sobra de antes e o WMI sem resposta.
- **A página (28):**
  - cada item existe e tem até 60 letras;
  - um destaque só;
  - o escudo nas quatro ações;
  - o atalho de Armazenamento;
  - os motivos de "sem Lixeira" que completam a frase da pasta.
- **Os textos:** nenhum marcador `{0}` sobrando e nenhum texto do português na tela em inglês e em espanhol, incluída a barra de andamento.

**Achados**

| # | Severidade | O que acontecia | Como ficou |
|---|---|---|---|
| Q1 | Baixa | A pergunta final dos restos de programas dizia "Enviar para a Lixeira os 3 pastas marcados?". Com duas pastas do mesmo nome (a do Local e a do Roaming), dizia "Firefox e Firefox". | "Enviar 3 pastas para a Lixeira?", como nos duplicados. O caminho de cada uma está na lista logo acima. |
| Q2 | Baixa | A barra de andamento da limpeza dos Downloads dizia "Limpando Downloads" em português nas telas em inglês e em espanhol. | Pela tradução, com o nome da ação. |
| Q3 | Baixa | Em inglês, os motivos de "sem Lixeira" começavam com "it", e as frases dos Downloads e dos duplicados ficavam "The Downloads folder it is on a USB drive...". | Sem o "it": "The Downloads folder is on a USB drive...". |
| Q4 | Média | O DISM rodando com um reinício pendente (é o M1). | Corrigido. |
| Q5 | Baixa | A ressalva da Limpeza rápida sem dizer a parte (é o D2). | Corrigido. |
| Q6 | Baixa | A Lixeira oferecida nos Downloads de um pendrive (é o D3). | Corrigido. |

Cada conferência nova falha no código de antes e passa no de agora.

## Engenharia

**Por dentro**
- **Cleanup.psm1:**
  - `Set-WinForgeRecycleBinNext` aceita a ressalva: só o botão entra, e o título e a frase continuam os da ressalva;
  - `Clear-WinForgeRecycleBin`: a faixa sozinha;
  - `Invoke-WinForgeQuickCleanup`: a Lixeira vazia fora das etapas, e a ressalva com o nome das partes;
  - `Clear-WinForgeDownloads`: a Lixeira e o limite conferidos antes da escolha, e a faixa dos casos vazios;
  - `Invoke-WinForgeDownloadsRemoval`: a barra traduzida, "Itens ignorados" só quando houver e a faixa da exclusão permanente;
  - `Invoke-WinForgeCustomCleanup` e `Show-WinForgeSpaceAnalysis`: as faixas;
  - `Invoke-WinForgeComponentCleanup`: o reinício pendente, o 0x800F0806 traduzido e a faixa;
  - o padrão de `Clear-WinForgeFolderContents`, pela tradução.
- **Repair.psm1:**
  - `Request-WinForgeRepairRestart` recebe os textos, com os do reparo como padrão;
  - `Invoke-WinForgeTool` ganha `-ServicingText`, para a limpeza dos componentes passar os dela.
- **CleanupTools.psm1:** a pergunta dos restos, e o botão da Lixeira na ressalva dos duplicados e dos restos.
- **RegistryCleaner.psm1:** a faixa com o botão Histórico de mudanças.
- **Traduções:** 18 novas e 7 que saíram de uso; 5.198 ao todo. Em inglês, 7 motivos de "sem Lixeira" sem o "it".

**Conferido na nuvem**
- **As conferências da Limpeza:** 178, 187 e 187, todas passando.
- **As de antes continuam passando:**
  - as 134, 142 e 142 da Segurança, com o reparo do DISM e do SFC dizendo os mesmos textos de antes;
  - as 212, 224 e 224 do Diagnóstico;
  - as 245, 247 e 252 da Manutenção e as 241 do Início nos três idiomas;
  - as 83 do QA geral, as 80 da R11 e as 60 da R12;
  - as 59 da R9 e as 52 da R10;
  - as 66 da QA, as 28 da integração e as 26 da R7;
  - as 84 ações rodando 336 vezes;
  - o motor de instalação, a atualização simulada e o Setup de verdade (da R16 para esta), e o pacote de suporte;
  - as traduções (5.198/5.198), as 160 referências nos três idiomas e a busca dos 102 itens;
  - nenhuma chamada com parâmetro que não existe, nenhuma função sem uso e nenhum aviso novo do analisador.

## O que só um PC mostra

Isto entrou no roteiro de conferência:
- **Limpar componentes num PC com uma atualização esperando reinício:** a tela diz por quê, o DISM não roda e a faixa oferece reiniciar. Num PC sem reinício pendente, o DISM roda como antes. É a mudança mais sensível desta revisão: o mesmo teste do reparo agora também decide se a limpeza roda.
- **Downloads num pendrive**, ou com a Lixeira desligada na unidade: só "Excluir permanentemente" aparece, com o porquê antes.
- **As faixas novas:** esvaziar a Lixeira com algo dentro, a Limpeza personalizada e os componentes, cada uma com o quanto liberou.
- **A Limpeza rápida com a Lixeira vazia:** a pergunta é só dos temporários, e o resumo não tem a seção da Lixeira.

## Fontes
- [Clean up the WinSxS folder (Microsoft Learn)](https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/clean-up-the-winsxs-folder): a tarefa StartComponentCleanup limpa sozinha quando o PC está parado; o `/StartComponentCleanup` apaga na hora, sem os 30 dias; com `/ResetBase`, as atualizações já instaladas não podem mais ser desinstaladas.
- [Dism.exe /ResetBase error on Windows Server 2016 (Microsoft Q&A)](https://learn.microsoft.com/en-gb/answers/questions/152596/dism-exe-resetbase-error-on-windows-server-2016): a mensagem do DISM com 0x800f0806, "The operation could not be completed due to pending operations".
