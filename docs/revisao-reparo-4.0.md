# WinForge 4.0 — revisão do Reparo (R19)

**Data:** 19/11/2026 · **Versão:** Build 4.0 em preparação, depois da R18

**Pedido:** juntar quatro olhares para a tela e a função de Reparo:
- **Analista de UX/UI Sênior (designer):** revisa cada detalhe da interface e orienta o engenheiro.
- **Especialista Microsoft (MVP Windows):** confere se os comandos e as alterações no Windows são feitos da melhor forma disponível hoje, de modo seguro e robusto, e se fazem sentido e mudam o que devem no PC.
- **QA Sênior:** testa todas as funções da tela.
- **Engenheiro de Software Sênior:** aplica as correções.

**Resultado:** 11 achados, todos corrigidos.

| Olhar | Achados |
|---|---|
| Designer | 8: as faixas que diziam só "Não foi concluído" ou "Concluído com ressalvas" nas falhas conhecidas do DISM, no DISM e no SFC esperando reinício, no SFC que não rodou, no agendamento do CHKDSK recusado, na otimização que falhou e na busca de dispositivos que termina no reinício, e o conselho de reiniciar repetido duas vezes no resumo |
| MVP Windows | 3: a leitura dos dispositivos depois da busca e a do disco de cada unidade no CHKDSK, sem prazo, e o código 2 do CHKDSK tratado como ressalva |
| QA | Nenhum novo: os testes acharam dez dos acima (D1 a D8, M1 e M2). |
| Engenharia | Nenhum próprio: aplicou os 11. |

Nada rodou num Windows de verdade. O Windows (o DISM, o SFC e o CBS.log, o CHKDSK, o chkntfs e o fsutil, o defrag, o pnputil, os discos e os dispositivos) foi simulado. O que só um PC mostra entrou no roteiro de conferência.

## O Reparo hoje

A página tem, de cima para baixo:
1. **Arquivos do Windows:**
   - Reparar o Windows (DISM + SFC), em destaque ("Reparar");
   - Reparar imagem e componentes (DISM);
   - Verificar arquivos do sistema (SFC).
2. **Disco e dispositivos:**
   - Verificar o sistema de arquivos (CHKDSK);
   - Detectar dispositivos e drivers;
   - Otimizar a unidade do sistema.
3. **Ferramentas do Windows:**
   - Restauração do Sistema, que abre a janela do Windows;
   - Recuperação, que abre a página das Configurações.

As seis ações pedem Administrador e mostram o escudo.

O que cada ação muda:
- **DISM e SFC:** consertam os arquivos do Windows e não tocam nos arquivos da pessoa. A pergunta começa no Sim, porque nada se perde.
- **CHKDSK:** a verificação roda com o Windows aberto e só lê. O reparo, quando é preciso, roda ao reiniciar, com uma pergunta à parte no Não.
- **Otimizar a unidade:** o Windows escolhe o certo para o disco, o TRIM num SSD ou a desfragmentação num HD.
- **Detectar dispositivos:** o Windows procura hardware novo e instala os drivers que já tem.

## Designer (UX/UI)

| # | O que estava | Orientação | Como ficou |
|---|---|---|---|
| D1 | O DISM sem os arquivos do reparo (0x800F081F e 0x800F0906), bloqueado por uma política (0x800F0907) ou apontando para o servidor da empresa (0x800F0954) terminava com a faixa "Não foi concluído", sem frase. O que fazer só aparecia no resumo. | A faixa diz o que não aconteceu e o que fazer. | "A imagem do Windows não foi reparada", com a orientação de cada caso (a internet e o Windows Update, ou o suporte de TI). Também no reparo completo. |
| D2 | O DISM recusando por uma instalação esperando reinício (0x800F0806) terminava em "Não foi concluído", e o resumo dizia duas vezes para reiniciar ("Reinicie o PC e rode o reparo de novo." e "Reinicie o PC e tente de novo."). | Um conselho só, na faixa. | "Reinicie antes de reparar" e "Reinicie o PC e rode o reparo de novo.", como quando o WinForge percebe o reinício pendente antes de começar. O resumo diz uma vez. |
| D3 | O DISM sozinho que termina no reinício (3010) dizia "Concluído com ressalvas". | A faixa diz o que falta. | "Reinicie para concluir o reparo", como no reparo completo. |
| D4 | O SFC sozinho com um reparo pendente dizia "Concluído com ressalvas". | Idem. | "Reinicie e verifique de novo", com "depois de reiniciar, rode o SFC de novo". |
| D5 | O SFC que não conseguiu rodar dizia "Não foi concluído", sozinho e no reparo completo. | Idem. | "O SFC não conseguiu rodar", com o que fazer (o serviço Instalador de Módulos do Windows). |
| D6 | Com o chkntfs recusando o agendamento do reparo, a faixa dizia "Não foi concluído". | O que importa é que a unidade continua precisando de reparo. | "A unidade C: precisa de reparo", com o motivo, o conselho de copiar os arquivos antes e o botão para a saúde dos discos, como quando a pessoa diz Não. |
| D7 | A otimização que falhava dizia "Não foi concluído". | Idem. | "A unidade C: não foi otimizada", com o código. |
| D8 | A busca de dispositivos que termina no reinício (3010) dizia "Concluído com ressalvas". | Idem. | "Reinicie para terminar a instalação". |

**Conferido e mantido:**
- um destaque só na página, o reparo completo, e as descrições em até 60 letras nos três idiomas;
- o escudo nas seis ações;
- as perguntas começam no lugar seguro: as que só consertam ou só verificam, no Sim; o agendamento do reparo do disco, no Não; "Qual unidade verificar?", na do Windows, com Cancelar;
- com mais de um disco NTFS, a escolha da unidade vale como a confirmação, sem uma segunda pergunta;
- o comando aparece antes de rodar, e a barra diz para não fechar o WinForge;
- o resumo do reparo completo lista cada etapa com o tempo dela.

## Especialista Microsoft (MVP Windows)

**O que mudou**

| # | O que estava | Por que não é o melhor | Como ficou |
|---|---|---|---|
| M1 | Depois do `pnputil /scan-devices`, os dispositivos com problema eram lidos com `Get-PnpDevice`, sem prazo. | O comando fala com o Windows pelo WMI e não tem tempo-limite. Um WMI com defeito deixava a tela parada sem fim. Em Diagnóstico > Dispositivos com problema, a mesma leitura já tinha prazo desde a R15. | Pelo `Invoke-WinForgeCimCommand`, com `-AsJob` e até 60 segundos. Sem resposta, a faixa diz só que a busca terminou, sem afirmar nada sobre os dispositivos. |
| M2 | Na lista de unidades do CHKDSK, o disco de cada unidade (para saber se é externo) vinha de `Get-Partition` e `Get-Disk`, sem prazo. A R15 tinha deixado isso para esta revisão. | Um disco morrendo ou uma controladora travada, justo o caso de quem procura o CHKDSK, deixava a tela parada. | Os dois comandos rodam com `-AsJob` e até 60 segundos, como no Diagnóstico. Sem resposta, a unidade aparece sem a marca de externa. |
| M3 | O código 2 do CHKDSK virava "avisos menores", em amarelo. | Pela documentação da Microsoft, o código 2 quer dizer que o CHKDSK fez uma limpeza interna, ou que não a fez porque faltou o `/f`. Não é erro. Em amarelo, a etapa do disco no Otimizar ficaria amarela todo mês por nada. | "Nenhum erro na unidade C:", com a frase de que o CHKDSK só apontou uma limpeza interna, que não pede reparo. O pedido de `/spotfix` no texto continua levando ao reparo, como antes. |

**Cada comando, conferido**

| Função | Como o WinForge faz | Veredito |
|---|---|---|
| Reparar o Windows (DISM + SFC) | `DISM /Online /Cleanup-Image /RestoreHealth` e depois `sfc /scannow`, a ordem que a Microsoft indica. Antes, confere se o Windows espera um reinício; se espera, nada roda e o reinício é oferecido. O PC fica acordado até o fim. Se o SFC não reparar tudo, a faixa leva à Recuperação. No Otimizar, o `/CheckHealth` vem antes, e o `/RestoreHealth` só roda com dano marcado ou se o SFC não reparar tudo. | Certo, com o D1, o D2 e o D5. |
| Reparar imagem e componentes (DISM) | O `/RestoreHealth`, com os arquivos do Windows Update. Os códigos conhecidos (0x800F081F, 0x800F0906, 0x800F0907, 0x800F0954, 0x80070422 e os do reinício pendente) viram uma frase com o que fazer. | Certo, com o D1, o D2 e o D3. |
| Verificar arquivos do sistema (SFC) | `sfc /scannow`. O resultado vem da frase do SFC e das linhas `[SR]` do CBS.log desde a hora em que ele começou; os arquivos sem reparo aparecem pelo nome, sem repetir. | Certo, com o D4 e o D5. |
| Verificar o sistema de arquivos (CHKDSK) | `chkdsk C: /scan`, a verificação com o Windows aberto (só NTFS). As unidades são os discos fixos em NTFS; a do Windows vem primeiro. O reparo, quando pedido: `chkntfs /C` e `fsutil dirty set`, que fazem o Windows verificar a unidade ao reiniciar. O reinício é oferecido no Não. | Certo, com o M2, o M3 e o D6. |
| Detectar dispositivos e drivers | `pnputil /scan-devices` (do Windows 10 versão 2004 em diante). Depois, até 20 segundos de espera pelo serviço de instalação de dispositivos e a leitura dos que ainda têm problema, sem os desativados de propósito. | Certo, com o M1 e o D8. |
| Otimizar a unidade do sistema | `defrag C: /O /U /V`: o `/O` faz a otimização certa para o tipo do disco. A tela diz antes se é um SSD (TRIM, segundos) ou um HD (desfragmentação, de minutos a horas). | Certo, com o D7. |
| Restauração do Sistema e Recuperação | `rstrui.exe` e `ms-settings:recovery`. | Certo. |

**Conferido e mantido**
- **O `/RestoreHealth` sem `/Source`:** o Windows Update é a fonte padrão. Uma fonte própria pede uma imagem do Windows na mesma versão, fora do alcance de quem usa o WinForge; quando ela falta, a frase diz o que conferir.
- **O reparo do disco pela marca de "sujo"**, e não pelo `/spotfix`: no disco do Windows, o `/spotfix` pede uma confirmação digitada. A verificação completa ao reiniciar cobre o que o `/spotfix` cobriria, e a tela avisa que pode levar horas.
- **O CHKDSK com o Windows aberto só verifica (`/scan`, sem `/f`):** nada muda no disco sem a pessoa concordar com o reparo.
- **O `/O` no defrag:** quem decide entre o TRIM e a desfragmentação é o Windows; o WinForge nunca força a desfragmentação de um SSD.
- **DISM, SFC, CHKDSK e defrag sem tempo-limite:** são longos, a pessoa espera com a barra, e o Parar interrompe.

## QA Sênior

**Como foi testado:** cada função da página rodou com o Windows simulado, nos três idiomas: 112 conferências em português e 119 em inglês e em espanhol. As 7 a mais conferem, em cada seção, que nenhum texto do português aparece na tela.
- **Reparar o Windows (19):**
  - sem Administrador, com o reinício pendente e cancelado;
  - sem problema, com a imagem e os arquivos reparados e com arquivos sem reparo;
  - o DISM sem os arquivos, com o Windows Update desativado, esperando reinício e terminando no reinício;
  - o SFC que não rodou e o SFC com reparo pendente;
  - um erro no meio;
  - no Otimizar: sem dano marcado, com o segundo SFC, e sem conseguir consultar a imagem.
- **DISM sozinho (18):** cancelar, íntegra, reparada, os quatro códigos conhecidos, o Windows Update desativado, o reinício pendente (pelo código e antes de começar), o 3010 e sem Administrador.
- **SFC sozinho (9):** limpo, reparou, sem reparo (com os nomes do CBS.log), não rodou, pendente, um código de saída, sem frase e a leitura do CBS.log.
- **CHKDSK (21):**
  - um disco só e vários, com o exFAT fora e o USB dito;
  - cancelar na escolha;
  - um disco que não responde;
  - os códigos 1, 2 e 3, o pedido de `/spotfix` com o código 0 e o interrompido;
  - o reparo: Não, Sim, num disco externo e com o chkntfs recusando;
  - no Otimizar, sem pergunta no meio;
  - sem Administrador.
- **Otimizar a unidade (9):** num SSD, num HD e sem saber o tipo; cancelar; uma falha do defrag.
- **Detectar dispositivos (11):** um Windows anterior ao 2004, nenhum problema, dispositivos com problema, o código 14, sem leitura, o Windows sem responder e o 3010.
- **A página (18):** cada item existe e tem até 60 letras, as seis ações com o escudo, um destaque só e os dois atalhos do Windows.
- **Os textos:** nenhum marcador `{0}` sobrando e nenhum texto do português na tela em inglês e em espanhol.

**Achados**

| # | Severidade | O que acontecia | Como ficou |
|---|---|---|---|
| Q1 | Média | A busca de dispositivos e a lista de unidades do CHKDSK paradas sem fim com o Windows sem responder (são o M1 e o M2). | Corrigido. |
| Q2 | Baixa | As faixas genéricas nas falhas e nos reinícios (são o D1 ao D8). | Corrigido. |

Cada conferência nova falha no código de antes e passa no de agora.

## Engenharia

**Por dentro**
- **Repair.psm1:**
  - `Set-WinForgeDismFailureView` (no lugar de `Set-WinForgeDismServiceView`): o Windows Update desativado, o reinício pendente e os erros conhecidos do DISM, sozinho e no reparo completo;
  - `Set-WinForgeSfcFailureView` (nova): o SFC que não rodou;
  - `Get-WinForgeDismResult`: o 0x800F0806 sem a observação repetida;
  - as faixas do DISM e do SFC sozinhos com o reinício, de `Set-WinForgeRepairView` com as falhas, do agendamento recusado, da otimização que falhou e da busca de dispositivos com o 3010;
  - `Test-WinForgeDriveExternal` e `Get-WinForgeDeviceScanRemaining` pelo `Invoke-WinForgeCimCommand`;
  - o código 2 do CHKDSK como "nenhum erro".
- **Traduções:** 10 novas e 2 que saíram de uso; 5.210 ao todo.

**Conferido na nuvem**
- **As conferências do Reparo:** 112, 119 e 119, todas passando.
- **As 84 ações rodaram de novo 336 vezes** com o Windows simulado: nenhum erro escapou, e o resultado é o mesmo da R18.
- **As de antes continuam passando:**
  - as 96, 102 e 102 do Desempenho, as 178, 187 e 187 da Limpeza, as 134, 142 e 142 da Segurança e as 212, 224 e 224 do Diagnóstico;
  - as 245, 247 e 252 da Manutenção, com o DISM, o SFC e o CHKDSK do Otimizar, e as 241 do Início nos três idiomas;
  - as 83 do QA geral, as 80 da R11 e as 60 da R12;
  - as 59 da R9 e as 52 da R10;
  - as 66 da QA, as 28 da integração e as 26 da R7;
  - o motor de instalação, a atualização simulada e o Setup de verdade (da R18 para esta), e o pacote de suporte;
  - as traduções (5.210/5.210), as 160 referências nos três idiomas e a busca dos 102 itens;
  - nenhuma chamada com parâmetro que não existe, nenhuma função sem uso e nenhum aviso novo do analisador.

## O que só um PC mostra

Isto entrou no roteiro de conferência:
- **CHKDSK num PC com mais de um disco**, um deles externo (um HD ou SSD pela USB): a lista aparece no mesmo tempo de antes, e o externo vem marcado como "disco externo (USB)". A leitura do disco de cada unidade agora roda com prazo, por um trabalho do próprio WinForge: é a mudança mais sensível desta revisão.
- **Detectar dispositivos**, com um dispositivo novo ligado (um pendrive ou um fone Bluetooth): a faixa diz se algum ainda tem problema, no mesmo tempo de antes.
- **O DISM sem internet**, se der para provocar (num PC com algo a reparar): a faixa diz "A imagem do Windows não foi reparada", com o que conferir.
- **Otimizar a unidade** num SSD e num HD: a faixa diz o que o Windows fez.

## Fontes
- [Use the System File Checker tool to repair missing or corrupted system files (Microsoft Support)](https://support.microsoft.com/help/929833): rodar o DISM (`/Online /Cleanup-Image /RestoreHealth`) antes do `sfc /scannow`.
- [chkdsk (Microsoft Learn)](https://learn.microsoft.com/windows-server/administration/windows-commands/chkdsk): o `/scan` só no NTFS, com o Windows aberto; os códigos de saída de 0 a 3, com o 2 para a limpeza feita ou não feita por falta do `/f`.
- [defrag (Microsoft Learn)](https://learn.microsoft.com/windows-server/administration/windows-commands/defrag): o `/O` faz a otimização certa para cada tipo de mídia; `/U` mostra o andamento e `/V`, os detalhes.
- [PnPUtil command syntax (Microsoft Learn)](https://learn.microsoft.com/windows-hardware/drivers/devtest/pnputil-command-syntax): o `/scan-devices` procura alterações de hardware, a partir do Windows 10 versão 2004.
- [Get-Disk (Microsoft Learn)](https://learn.microsoft.com/en-us/powershell/module/storage/get-disk): o comando aceita `-Number` e `-AsJob`.
