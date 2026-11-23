# WinForge 4.0 — segunda revisão do Diagnóstico (R45)

**Data:** 21/11/2026 · **Versão:** Build 4.0 em preparação, depois da R44

**Pedido:** revisar a tela e a função Diagnóstico com cinco olhares:
- **Analista de Produto Sênior:** avalia o todo.
- **Engenheiro de Software Sênior:** revisa o código, refatora, segue as boas práticas, tira o que não serve e melhora o desempenho.
- **Designer Sênior, com um Especialista em UX/UI:** revisam a tela, os botões, os textos e os fluxos; o engenheiro aplica.
- **MVP Windows:** confere se o Diagnóstico segue as práticas da Microsoft, se cada função faz da melhor forma o que promete e se é robusto e estável.
- **QA Sênior:** testa tudo o que dá para testar, o óbvio e o que não é; o engenheiro aplica.

**De onde partiu:** a primeira revisão do Diagnóstico (R15) foi antes do desenho novo (R37), da revisão de UX (R38) e das faixas que levam ao que resolve (R41 a R43). Esta olhou as doze telas da página e o que elas dividem com outras partes: a saúde dos discos (o relatório, o monitor e a Verificação do PC), o reinício pendente (o Início, o Otimizar e o Reparo) e o tempo ligado (o Desempenho).

**Resultado:** 12 achados, todos corrigidos.

| Olhar | Achados |
|---|---|
| Produto | 3: Tempo ligado e energia explicava que só reiniciar resolve, sem oferecer; o disco cheio com outro conselho que o resto do WinForge; e três faixas que mandavam a outra tela sem levar até ela |
| Engenharia | 3: a Saúde dos discos esperando o prazo de cada disco com o armazenamento sem resposta; as partições lidas em três lugares, de três jeitos; e a regra do "ligado há uma semana" em dois lugares |
| Designer e UX/UI | 3: Sim e Não no Teste de memória; o Teste de memória com o mesmo ícone de Dispositivos com problema; e as Telas azuis repetindo a mesma causa em cada travamento |
| MVP Windows | 2: o Reinício pendente sem ler o pending.xml, que o DISM lê; e Sobre este PC levando minutos para dizer que o WMI não responde |
| QA | 1: os contadores de um disco sem resposta descritos como os de um pendrive |

Nada rodou num Windows de verdade. A conferência foi feita na nuvem: a página com as funções de verdade da janela sobre o WPF simulado, e as telas com o Windows simulado (o WMI, as partições, os contadores dos discos e os dispositivos com prazo de verdade, os logs do Windows e o Registro) e o pending.xml numa pasta de verdade. O que só um PC mostra entrou no roteiro de conferência (§36).

## O Diagnóstico hoje

A página só lê o PC, fora reiniciar e o teste de memória, que ficam com as ferramentas do Windows quando a pessoa pede. De cima para baixo:
1. **Sobre este PC,** em destaque ("Ver detalhes").
2. **Visão geral:** Suporte do Windows e Exportar relatório.
3. **Hardware:** Discos e espaço livre, Saúde dos discos, Dispositivos com problema, Saúde da bateria (só num notebook) e Teste de memória.
4. **Funcionamento do Windows:** Eventos críticos (7 dias), Telas azuis, Reinício pendente e Tempo ligado e energia.
5. **Ferramentas do Windows:** Monitor de Confiabilidade e Gerenciador de Dispositivos.

## Analista de Produto

| # | O que estava | Por que importa | Como ficou |
|---|---|---|---|
| P1 | Com o PC ligado há 7 dias ou mais, a faixa do Desempenho (R43) traz a pessoa para Tempo ligado e energia. A tela explicava que só Reiniciar zera o tempo ligado, e terminava ali. | O que resolve é reiniciar, e o conselho da Microsoft para um PC lento é o mesmo. Reinício pendente, na mesma página, já oferece reiniciar. | Com uma semana ou mais, a tela diz "O PC está ligado há 9 dias e 3 horas: reiniciar deixa o Windows mais leve." e oferece reiniciar, com "Reiniciar agora" e "Depois" e o Depois como padrão, sem fechar nada à força. Com menos, nada muda. |
| P2 | Com o disco do Windows cheio, Discos e espaço livre e Sobre este PC diziam "use Limpeza > Limpeza rápida ou Limpeza > Analisar uso de espaço". | Na R42, o disco cheio passou a ter um conselho só, a Limpeza personalizada, no Início, na Verificação do PC, no monitor e na faixa da Limpeza. Dois conselhos para o mesmo problema confundem. | "Para liberar espaço no disco do Windows, use Limpeza > Limpeza personalizada." A faixa de Discos e espaço livre diz a frase da unidade ("A unidade C: está quase cheia: só 6 GB livres de 476 GB") e tem o botão "Liberar espaço", o mesmo do Início. Com só uma unidade de dados cheia, a frase dela, sem o botão: a Limpeza cuida do disco do Windows. |
| P3 | Três faixas mandavam a outra tela sem levar até ela. Dispositivos com problema dizia "use Reparo > Detectar dispositivos e drivers". Nos Eventos críticos, só a tela azul tinha botão; o erro de disco dizia "Veja Diagnóstico > Saúde dos discos", e o do sistema de arquivos, "Use Reparo > Verificar o sistema de arquivos (CHKDSK)". | As faixas da Manutenção, da Limpeza e do Desempenho (R41 a R43) levam ao que resolve. Aqui, a pessoa tinha de achar a tela sozinha. | Dispositivos com problema: o botão "Detectar dispositivos" (com só o código 14, o que resolve é reiniciar, e não há botão). Eventos críticos, pela ordem do mais grave: a tela azul ("Ver as telas azuis", como antes), o erro de disco ("Ver a saúde dos discos"), o sistema de arquivos ("Verificar o disco", o CHKDSK) e o erro de hardware ("Testar a memória"). O desligamento inesperado não tem tela que resolva: sem botão. |

**Conferido e mantido:**
- **Sobre este PC em destaque:** é o que um técnico pede primeiro, e o resto da página é uma caixa de ferramentas, cada uma para uma pergunta.
- **Sem faixa no alto:** o Início e a Verificação do PC já avisam do reinício pendente, das telas azuis e dos discos com problema; uma faixa aqui repetiria, e as leituras desta página levam segundos (o log do Sistema, o licenciamento, os discos).
- **Discos e espaço livre separado de Sobre este PC,** para quem só quer o espaço.

## Engenheiro de Software

| # | O que estava | Como ficou |
|---|---|---|
| E1 | A Saúde dos discos pedia os contadores de cada disco (temperatura, desgaste, erros), cada pedido com prazo de 60 segundos. Com o serviço de armazenamento sem resposta, cada disco esperava o prazo inteiro: com três discos, três minutos. O relatório e o monitor usam a mesma leitura. | Depois do primeiro tempo esgotado (o `Invoke-WinForgeCimCommand` avisa com o erro de tempo, para isso), os pedidos que faltam não são feitos: um prazo só, qualquer que seja o número de discos. Com as partições sem resposta, os contadores nem são pedidos. |
| E2 | As letras das unidades de cada disco vinham das partições em três lugares, cada um com o seu laço: Discos e espaço livre, Saúde dos discos e a lista do CHKDSK (R44). Só o do CHKDSK tratava a partição sem letra como o Windows a entrega (o caractere zero). | `Get-WinForgePartitionLetters` (nova) lê as partições uma vez e devolve a letra e o disco de cada unidade, e os três usam ela. A lista do CHKDSK nem lê os discos quando não há unidade com letra. O cabeçalho do módulo diz o que ele tem. |
| E3 | A regra do "ligado há uma semana ou mais" estava escrita no Desempenho, com a hora local, que erra uma hora na troca do horário de verão. Tempo ligado e energia (P1) precisava da mesma. | `Test-WinForgeLongUptime` (nova), em UTC, como o tempo ligado que a tela mostra. O Desempenho e Tempo ligado e energia usam ela. |

**Por dentro:**
- **Diagnostics.psm1:**
  - `Test-WinForgeLongUptime`, `Get-WinForgePartitionLetters` e `Get-WinForgeLowDiskText` (novas);
  - `Get-WinForgeDiskHealth` com `CountersTimedOut` e sem esperar de novo o armazenamento;
  - `Get-WinForgePendingReboot` pela mesma leitura de `Test-WinForgeServicingRebootPending`;
  - Sobre este PC, Discos e espaço livre, Dispositivos com problema, Eventos críticos, Telas azuis, Tempo ligado e energia e Teste de memória.
- **Repair.psm1:** a lista do CHKDSK por `Get-WinForgePartitionLetters`.
- **Performance.psm1:** a faixa do alto por `Test-WinForgeLongUptime`.
- **Reports.psm1:** a linha da saúde de um disco sem resposta.
- **GuiDesign.psm1 e Navigation.psm1:** o ícone do Teste de memória e a frase das Telas azuis.
- **Traduções:** 5.591 textos (9 novos e 2 que saíram de uso). Entraram três funções (1.293 nos módulos).

## Designer e Especialista em UX/UI

| # | O que estava | Orientação | Como ficou |
|---|---|---|---|
| D1 | O Teste de memória perguntava "Abrir o Diagnóstico de Memória do Windows?" com Sim e Não. É a UX21 da revisão de UX, aplicada nesta página. | Os botões dizem o que fazem, como a Microsoft orienta ("Use specific responses to the main instruction or content as button text"). | "Abrir" e "Agora não". O padrão não mudou: com um teste recente sem erros, o Agora não; senão, o Abrir. O menu de texto continua com S/N. As outras perguntas da página já tinham o verbo (o reinício, o que fazer com o relatório). |
| D2 | O Teste de memória tinha o ícone de chip, o mesmo de Dispositivos com problema, duas linhas acima. | Um ícone por ação na página. | O ícone de verificar (os cantos e o visto). Nenhum ícone se repete na página. |
| D3 | As Telas azuis mostravam uma linha por travamento, cada uma com "Causa provável: um driver. Atualize os drivers, principalmente os de rede, vídeo e chipset." embaixo. Num PC com o mesmo travamento dez vezes, eram dez linhas e dez vezes o mesmo conselho. A frase da página repetia o nome ("Telas azuis: Telas azuis dos últimos 90 dias"). | Pouco texto, e o que se repete, uma vez. | Uma linha por código, como nos Eventos críticos: "0x0000009F · DRIVER_POWER_STATE_FAILURE · 10 vezes, a última em 12/11 09:30". A causa vem embaixo do primeiro código que a tem, uma vez só. A frase da página é "Dos últimos 90 dias, com a causa provável". A faixa continua igual. |

**Conferido e mantido:**
- **As descrições** cabem em 60 letras nos três idiomas, e a página tem um destaque só.
- **As faixas das falhas de leitura** (o log do Sistema, os dispositivos, os discos) dizem o que não foi lido e onde conferir (R15).
- **Os textos das telas:** as categorias de dispositivo traduzidas, o tempo ligado com uma frase só e o resultado do teste de memória (R15).

## MVP Windows

| # | O que estava | Por que importa | Como ficou |
|---|---|---|---|
| M1 | O Reinício pendente lia as chaves do Windows Update e da manutenção dos componentes (CBS), mas não o pending.xml. O Reparo e o Otimizar leem o pending.xml para saber se o DISM e o SFC vão recusar (R44). | Na instalação de uma atualização, o Windows deixa no pending.xml o que ele termina ao desligar ou reiniciar. Com ele, o Reparo dizia "Reinicie antes de reparar" e o Diagnóstico, "Nenhum reinício pendente foi detectado". O Início, a Verificação do PC, o monitor e o Otimizar seguiam o Diagnóstico: o Otimizar começava sem oferecer o reinício e pulava o reparo e a limpeza dos componentes no meio. | O Reinício pendente parte da mesma leitura do Reparo (`Test-WinForgeServicingRebootPending`): com o pending.xml, "Uma atualização do Windows termina de instalar no reinício", como sinal forte, com a oferta de reiniciar. Sobre este PC, o Início, a Verificação do PC, o monitor e o Otimizar dizem o mesmo. |
| M2 | Sobre este PC lia nove coisas do WMI, uma depois da outra, cada uma com o seu prazo: sete classes de 15 segundos, a ativação (30) e os discos (15). Com o WMI sem resposta, a tela levava dois minutos e meio para dizer "O Windows não respondeu às consultas de hardware", e depois mostrava uma lista de "Não disponível". | O WMI com defeito é justo o caso de quem abre o Diagnóstico para entender o PC. | O Windows e o processador vêm primeiro: existem em todo Windows, e sem resposta dos dois o WMI não está respondendo. Aí a tela para as leituras do WMI e diz isso em 30 segundos, com o que não depende dele: o nome do PC, o reinício pendente e o Secure Boot (do Registro). Com o WMI respondendo e uma classe só faltando (uma máquina virtual sem a placa-mãe), a tela inteira, como antes. |

**Conferido**, com as fontes no fim:
- **Reiniciar:** "If performance does not improve, restart your PC." É o que a Microsoft aconselha para um PC lento, e o que Tempo ligado e energia passou a oferecer (P1), sem fechar nada à força.
- **O pending.xml:** "During service pack installation, we populate the pending.xml file with all of the files and registry values needed to install a particular update", e "During system shutdown, we process all of the critical transactions first" (M1).
- **O restante da R15 continua valendo:** as leituras com prazo (`Get-PhysicalDisk` pelo WMI, `Get-Partition`, `Get-StorageReliabilityCounter` e `Get-PnpDevice` como trabalho); o log do Sistema lido sem montar o texto de cada evento; a tela azul pelo código, do registro do WER (1001) e do reinício inesperado (Kernel-Power 41), contada uma vez; o Secure Boot pelo Registro; a ativação pelo licenciamento do Windows; a bateria pelo relatório do powercfg; o teste de memória na ferramenta do Windows.
- **Robusto:** toda leitura da página tem prazo, e sem resposta a tela diz o que faltou, agora em um prazo só para o armazenamento (E1) e para o WMI (M2).

## QA Sênior

**Como foi testado:** uma bateria nova do Diagnóstico, 87 conferências em cada idioma.
- **A página (A):** os ícones, sem repetição; a frase das Telas azuis; as descrições em 60 letras; a ordem; a busca.
- **O Teste de memória (B):** os botões e o padrão sem teste, com um teste recente sem erros e com erros; a pergunta na janela de verdade; uma leitura do código que confere que nenhuma pergunta da página ficou sem o verbo.
- **Tempo ligado e energia (C):** a regra (7 dias, 6 dias e 23 horas, sem a hora do início, um início "no futuro", 1601); a faixa do Desempenho pela mesma regra; a oferta, o Depois, o Reiniciar agora (o `shutdown /r /t 0`, sem o `/f`); 3 dias; sem a hora do início.
- **Discos e espaço livre (D):** o disco do Windows quase cheio, só o de dados, os dois, nenhum, sem a leitura do Windows; Sobre este PC.
- **As partições (E):** a letra minúscula, a partição sem letra, a sem disco; uma leitura em cada tela; a lista do CHKDSK, com e sem unidade com letra; o tempo esgotado chegando a quem chama.
- **A Saúde dos discos sem resposta (F):** os três discos, o segundo, as partições; um pendrive sem contadores; um disco com defeito sem contadores; o relatório; o monitor e a Verificação do PC.
- **O reinício pendente (G):** sem nada, com o pending.xml (o motivo, a tela, a oferta, Sobre este PC).
- **O WMI sem resposta (H):** tudo parado, uma classe só faltando, o PC de sempre.
- **As faixas (I):** Dispositivos com problema com um driver faltando, só o código 14, só desativados; Eventos críticos com tela azul e disco, disco, sistema de arquivos (os dois nomes do NTFS), hardware, desligamento inesperado e só erros comuns.
- **As Telas azuis (J):** 13 telas de 3 códigos, a ordem, as vezes, cada causa uma vez, a faixa; um código sem nome; nenhuma.
- **Os textos (K)** nos três idiomas.

**Achados**

| # | O que estava | Como ficou |
|---|---|---|
| Q1 | Com os contadores de um disco sem resposta no prazo, a Saúde dos discos dizia "Este disco não expõe contadores de confiabilidade (comum em discos USB e virtuais); só o estado geral foi avaliado." O relatório dizia "sem contadores de confiabilidade". Era o que valia para um pendrive, dito de um SSD interno que só não respondeu a tempo, e sem dizer o que fazer. | Uma linha só, no fim, para todos os discos nessa situação: "O Windows não respondeu a tempo sobre os contadores de Samsung SSD 980 e WDC WD20EZAZ: só o estado geral foi avaliado. Tente de novo; se continuar, reinicie o PC." O relatório diz "os contadores não vieram (o Windows não respondeu a tempo)". Um pendrive sem contadores continua com a frase dele. |

Os testes também acharam os do produto (P1 a P3), os do designer (D1 a D3) e os do MVP (M1 e M2).

**A bateria antiga do Diagnóstico (R15):** duas conferências pediam o que mudou de propósito. Uma pedia o conselho antigo do disco cheio (P2); a outra pedia, para contadores sem resposta, a frase "não expõe contadores" (o Q1). As duas passaram a pedir as frases novas; no código de antes, só elas falham.

**Contra o código de antes (R44):** cada conferência das correções falha (40), e as 47 do que foi mantido passam (o que cada tela já mostrava certo, como o tipo de cada disco, os dispositivos desativados, os erros comuns e a faixa das Telas azuis). Com os três discos sem resposta, a Saúde dos discos de antes levou 6,9 segundos na simulação, um prazo por disco; a de agora, um prazo só.

**40 defeitos de propósito,** e as conferências pegam todos: o ícone e a frase antigos; o Teste de memória com Sim e Não ou sempre com Sim como padrão; a regra do tempo ligado com 8 dias ou aceitando 1601, e o Desempenho fora dela; a oferta de reiniciar sumida, com qualquer tempo ligado ou sem a faixa do reinício; o conselho antigo do disco, a faixa sem o botão, com o botão só para a unidade de dados, sem a frase da unidade ou sem faixa com uma unidade cheia; a letra minúscula, a partição sem disco, a letra procurada com os dois pontos e a lista do CHKDSK lendo os discos sem nenhuma letra; os contadores pedidos depois do tempo esgotado, as partições sem resposta sem segurar os contadores, o tempo esgotado esquecido no disco e a frase antiga na tela e no relatório; o pending.xml fora do reinício pendente ou como sinal fraco; o WMI parado lido até o fim, a ativação pedida com ele parado, a lista de "Não disponível" e o aviso com uma classe só faltando; as faixas sem o botão, com o botão só com o código 14, sem o do sistema de arquivos ou do hardware, com o nome novo do NTFS esquecido e com o disco antes da tela azul; e as Telas azuis do mais antigo ao mais novo, com a causa repetida, sem as vezes ou numa linha só. Na primeira rodada, um escapou: a letra minúscula, porque a comparação da conferência não olhava maiúsculas; com ela olhando, o defeito passou a ser pego.

**Nada do que funcionava quebrou:** as baterias das 14 páginas revistas, com os mesmos números da R44 (a do Diagnóstico da R15 com 212, 224 e 224, depois das duas conferências acima; a Rede com a mesma conferência antiga); a das seis funções novas da R36 (257 em cada idioma); a do Início da R40 (115), a da Manutenção da R41 (67), a da Limpeza da R42 (97), a do Desempenho da R43 (94) e a do Reparo da R44 (92) em cada idioma; a da Manutenção da R14 (243, 245 e 250) e a do Início da R13 (241); as mensagens da janela (72 em cada idioma); instalar, atualizar com um clique, o pacote de suporte e o Setup de verdade, da R44 para esta; nenhuma função sem uso (1.511, três novas). O PSScriptAnalyzer ficou com 245 avisos, dois a menos que na R44 (dois `catch` vazios da Saúde dos discos agora tratam o tempo esgotado), e nenhum novo.

## O que só um PC mostra

Isto entrou no roteiro de conferência (§36):
- **Tempo ligado e energia** num PC ligado há uma semana: a oferta, o Depois e o Reiniciar agora.
- **O Reinício pendente** depois de instalar uma atualização pelo Windows Update e antes de reiniciar: o motivo, o Início e o Reparo dizendo o mesmo.
- **Discos e espaço livre** com o disco do Windows quase cheio: a frase, o botão "Liberar espaço" e a Limpeza personalizada.
- **As Telas azuis** num PC que já teve várias (ou numa máquina virtual, com o NotMyFault): uma linha por código.
- **Os botões novos das faixas** de Dispositivos com problema e dos Eventos críticos.
- **O Teste de memória:** "Abrir" e "Agora não" nos três idiomas, e o ícone novo.
- **A Saúde dos discos e Sobre este PC** no mesmo tempo de antes; num PC com o armazenamento ou o WMI travado, se houver, a tela no prazo.

## Fontes
- [Tips to improve PC performance in Windows](https://support.microsoft.com/windows/b3b3ef5b-5953-fb6a-2528-4bbed82fba96) (Microsoft): "Close any apps or tabs you don't need. If performance does not improve, restart your PC."
- [Why you don't want to edit your pending.xml to resolve 0xC0000034 issues](https://learn.microsoft.com/fr-fr/archive/blogs/joscon/why-you-dont-want-to-edit-your-pending-xml-to-resolve-0xc0000034-issues) (Microsoft, blog arquivado): "During service pack installation, we populate the pending.xml file with all of the files and registry values needed to install a particular update." e "During system shutdown, we process all of the critical transactions first and then the non-critical transactions."
- [Dialog controls](https://learn.microsoft.com/windows/apps/design/controls/dialogs-and-flyouts/dialogs) (Microsoft): "Use specific responses to the main instruction or content as button text".
