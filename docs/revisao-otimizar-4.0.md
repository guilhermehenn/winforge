# WinForge 4.0 — revisão do Otimizar (R28)

**Data:** 20/11/2026 · **Versão:** Build 4.0 em preparação, depois da R27

**Pedido:** juntar quatro olhares para a tela e a função Otimizar:
- **Analista de UX/UI Sênior (designer):** revisa cada detalhe da interface e orienta o engenheiro.
- **Especialista Microsoft (MVP Windows):** confere se os comandos e as alterações no Windows são feitos da melhor forma disponível hoje, de modo seguro e robusto, e se fazem sentido e mudam o que devem no PC.
- **QA Sênior:** testa todas as funções da tela.
- **Engenheiro de Software Sênior:** aplica as correções.

**Resultado:** 7 achados, todos corrigidos.

| Olhar | Achados |
|---|---|
| Designer | 3: a faixa genérica em todos os desfechos, sem botão; a parte automática cancelada terminando em "Concluído com ressalvas"; e o resumo dos navegadores sem os dois-pontos |
| MVP Windows | 2: o Otimizar desligava sozinho, a cada vez, as atualizações antecipadas, mesmo de quem as ligou de propósito; e a descrição dessa chave prometia instabilidade, o que a Microsoft não diz |
| QA | 2: uma pasta que não abria no Explorador sumia do resumo da etapa; e procurar duplicados e desistir contava como etapa feita |
| Engenharia | Nenhum próprio: aplicou os 7. |

Nada rodou num Windows de verdade. A conferência foi feita na nuvem, com o Windows simulado: as pastas pessoais eram pastas de verdade, e os atualizadores dos navegadores, arquivos de verdade em Arquivos de Programas. O que só um PC mostra entrou no roteiro de conferência.

A Manutenção (R14) e o Início (R13) já tinham conferido os comandos de cada etapa do Otimizar. Esta revisão olhou o Otimizar como uma tela só: o caminho de ponta a ponta, a faixa do fim e as três etapas que só existem dentro dele (as pastas pessoais, os navegadores e as atualizações antecipadas), que nenhuma revisão de página tinha testado.

## O Otimizar hoje

Ele abre do botão da nota de saúde do Início e da página Manutenção, e pede Administrador. Agora são 20 etapas, numeradas na tela ("Etapa 8 de 20: Reparar o Windows (DISM + SFC)"), com a barra e o botão na barra de tarefas mostrando a execução inteira.

1. **Preparação:** uma linha para cada coisa que atrapalha: outra conta, reinício pendente (com a oferta de reiniciar antes), bateria, pouco espaço e os programas abertos, pelo nome. "Já fechei, começar" em destaque.
2. **Com você, no começo:** o ponto de restauração (sem ele, a pessoa decide se segue, com Não como padrão), desinstalar programas, remover aplicativos do Windows, o que abre com o Windows e as pastas Downloads, Documentos e Imagens, uma por vez.
3. **As perguntas da parte automática:** o que atualizar no winget (sem os navegadores, que têm etapa própria), que restos de programas apagar e se a Lixeira é esvaziada (Manter como padrão). Depois, "Começar a parte automática?".
4. **Sozinha, com o PC sem dormir:** antivírus, componentes do Windows, DISM e SFC, Windows Update, dispositivos, winget, navegadores, Microsoft Store, limpeza rápida, atalhos quebrados, restos de programas, rede, CHKDSK e otimização do disco. No fim dela, o resultado já fica gravado.
5. **Com você, no fim:** a revisão dos ajustes do Windows, cada um marcado conforme o Windows está agora.
6. **Encerramento:** o resumo (uma linha por etapa), o antes e depois (o espaço livre e os programas que abrem com o Windows), o reparo do disco ao reiniciar quando o CHKDSK pede, e sempre a sugestão de reiniciar, com Não como padrão.

## Designer (UX/UI)

| # | O que estava | Orientação | Como ficou |
|---|---|---|---|
| D1 | A faixa do fim era a genérica em todos os desfechos: "Tudo certo"; "Concluído com ressalvas", que com três ou mais etapas com problema dizia só a conta ("1 etapa falhou e 2 terminaram com ressalvas"); "Não foi concluído: As 21 etapas falharam". Nenhuma tinha botão, embora quase toda etapa exista sozinha numa tela do WinForge. As telas revistas antes desta já dizem o que aconteceu e levam ao próximo passo. | O título diz o que aconteceu; a frase, qual etapa e por quê; o botão leva à tela que roda a etapa sozinha. | "PC otimizado", com o que a execução fez. "2 etapas pedem atenção", com os nomes (as que falharam antes das que terminaram com ressalvas; com mais de quatro, as três primeiras e "e mais N") e, com uma só, o motivo: "Criar ponto de restauração: a Proteção do Sistema está desligada". O botão leva à tela da primeira que existe fora do Otimizar ("Instalar atualizações do Windows"). "Nenhuma etapa funcionou", com o motivo quando é o mesmo em todas; quando só uma etapa rodou e falhou, "Atualizar o Windows falhou". |
| D2 | Com a parte automática cancelada depois das telas do começo, a faixa dizia "Concluído com ressalvas", como se a manutenção tivesse terminado. | O título diz o que a pessoa fez. | "Parte automática cancelada", com "O que já foi feito continua valendo: 2 etapas executadas e 3 ignoradas…". Sem nada mudado, continua "Operação cancelada". |
| D3 | O resumo e o histórico da etapa dos navegadores juntavam o nome e a frase sem pontuação: "Chrome a atualização é controlada por uma política", "Edge atualizador não encontrado". | O nome e o que houve, separados. | "Edge: atualizado para 131.0.2903.51; Chrome: já na versão mais nova (131.0.6778.86)". |

**Conferido e mantido:**
- **a etapa em destaque no alto da tela,** com o título de seção que repete o nome dela escondido no resumo, para não aparecer duas vezes;
- **um destaque por pergunta:** "Já fechei, começar", "Começar", "Limpar com o WinForge" na Downloads e "Abrir no Explorador" nas outras pastas;
- **as perguntas que podem custar algo começam no Não:** continuar sem o ponto de restauração, na bateria ou com outra conta, esvaziar a Lixeira (o botão diz "Manter"), agendar o reparo do disco, reiniciar e reiniciar o Explorador;
- **os fins que já diziam tudo:** tudo ignorado ("Nada a fazer"), cancelado no começo ("Operação cancelada") e reiniciando antes de começar continuam com a faixa de antes;
- **o console e o histórico** continuam com a frase de antes ("Otimização concluída: 15 etapas executadas e 5 ignoradas; 2 GB a mais de espaço livre."), que o histórico guarda.

## Especialista Microsoft (MVP Windows)

| # | O que estava | Por que importa | Como ficou |
|---|---|---|---|
| M1 | Uma etapa da parte automática desligava, a cada Otimizar e sem perguntar, a opção "Receba as atualizações mais recentes assim que estiverem disponíveis" (`IsContinuousInnovationOptedIn` = 0). A revisão dos ajustes, no fim, a deixava de fora. Quem a ligou de propósito a via desligada de novo todo mês. | A Microsoft diz que, ligada ou desligada, as atualizações de segurança chegam do mesmo jeito; ligada, o PC recebe antes as novidades que não são de segurança e pode reiniciar mais vezes por mês. É uma preferência da pessoa, e não manutenção. Na maior parte dos PCs ela já vem desligada, e a etapa só dizia "já estava desligada". | A etapa saiu: o Otimizar tem 20 etapas. A opção entrou na revisão dos ajustes, no fim, marcada conforme o Windows está: desligada, vem marcada e nada muda; ligada, vem desmarcada e continua ligada, a menos que a pessoa marque. Com a política da empresa que controla o conteúdo opcional do Windows Update (`SetAllowOptionalContent`), ela fica de fora da revisão, como a etapa fazia. |
| M2 | A descrição da chave Receber as atualizações assim que saem, em Ajustes do Windows, dizia "pode trazer instabilidade". | A página da Microsoft sobre a opção não fala em instabilidade; ela diz que o PC pode reiniciar mais vezes por mês. | "O Windows instala as novidades antes de chegarem a todos, e o PC pode reiniciar mais vezes por mês." |

**Conferido e mantido**, com as fontes no fim:
- **O Chrome:** pelo atualizador do Google para todos, o de versão mais alta, com `--update-apps --system`. No código do atualizador do Chromium, `update-apps` "atualiza os aplicativos" e `system` o faz no escopo do computador. Sem ele, o atualizador antigo, com o mesmo pedido da tarefa agendada dele (`/ua /installsource scheduler`); como esse pode sair sem procurar, a frase não afirma que a versão instalada é a mais nova. Instalado só para um usuário ou com a política do Google que controla as atualizações, nada roda.
- **O Edge:** pelo atualizador do próprio Edge, em silêncio e para todos, como a R14 conferiu. A versão nova que espera o Edge fechar aparece como "vale ao abrir de novo".
- **O Firefox:** pelo winget, com o pacote no mesmo idioma do Firefox instalado (`Mozilla.Firefox.pt-BR`), só da fonte winget. Trocar de pacote trocaria o idioma. Aberto, com a versão ESR, com a política que desliga as atualizações ou sem o winget, nada roda, e a frase diz por quê.
- **A lista do winget sem os navegadores:** cada um é atualizado uma vez só, pelo caminho dele.
- **A ordem das etapas, o DISM e o SFC antes do Windows Update, a rede só com o DNS quando a internet funciona e o PC sem dormir só na parte automática:** conferidos na R13 e na R14.

## QA Sênior

**Como foi testado:** o Otimizar rodou nos três idiomas, com o Windows simulado: 146 conferências em português e 151 em inglês e em espanhol.
- **O plano:** 20 etapas, sem repetir, nas fases e na ordem de antes; a etapa antiga não existe mais; cada etapa com tela própria tem destino na navegação, e ele leva ao mesmo lugar que o "rode de novo em" do histórico.
- **A revisão dos ajustes com as atualizações antecipadas:** desligadas (marcadas, nada muda), ligadas pela pessoa (desmarcadas, continuam ligadas), marcadas para desligar (o ajuste é aplicado) e com a política da empresa (de fora).
- **O Otimizar de ponta a ponta, em 23 situações:**
  - o dia comum, na janela e no console, e sem espaço ganho nem reinício;
  - uma falha e uma ressalva, três etapas, seis etapas, só as etapas sem tela própria, os navegadores falhando com o Windows Update com ressalva;
  - sem o ponto de restauração, uma etapa que lança erro, o erro de uma exceção, um motivo comprido demais para a faixa, um motivo que começa por um nome (o Firefox aberto) e três navegadores com o problema no último;
  - tudo falhando pelo mesmo motivo e por motivos diferentes, e só uma etapa rodando e falhando;
  - tudo ignorado, cancelado no começo e reiniciando antes;
  - a parte automática cancelada, com o ponto que faltou e sem nada mudado.

  Em cada uma: as etapas que rodaram e a ordem, a numeração na janela, a faixa (título, frase, cor e botão), a linha final do console, o detalhe do histórico e o histórico.
- **Os navegadores, em 18 situações:** nenhum; o Edge atualizando, já na mais nova, sem atualizador, com código de erro e lançando erro; o Chrome pelo atualizador novo (o de versão mais alta entre dois), pelo antigo, só do usuário e com política; o Firefox atualizando, sem versão nova, aberto, ESR, com a política que desliga as atualizações, em inglês dos EUA que o winget não reconhece e sem o winget; os três juntos. Em cada uma: o comando que roda, com os argumentos, e o que diz.
- **As pastas pessoais, em 10 situações:** pular tudo, limpar e abrir, uma pasta que não abre, pastas que não existem e uma vazia, pular as restantes, duplicados com e sem mudança, limpar que falha e desistir numa e abrir outra. Em cada uma: as perguntas, o destaque, a resposta do Enter e o que a etapa diz.
- **As perguntas antes da parte automática:** a lista do winget sem os navegadores, o winget que não responde, a Lixeira vazia (sem pergunta), com itens, ilegível e sem resposta; e as etapas que dependem das respostas (a limpeza com e sem a Lixeira, o winget sem lista e ausente, os restos escolhidos e a lista abandonada).
- **A janela:** com o botão na faixa, o fim do Otimizar continua abrindo no Resumo, pela leitura do código (a janela só abre num Windows).
- **Os textos:** nenhum texto desta revisão em português na tela em inglês e em espanhol, e nenhum marcador `{0}` sobrando.

**Achados**

| # | O que estava | Como ficou |
|---|---|---|
| Q1 | Na etapa das pastas, uma pasta que o Explorador não abria sumia do resumo: com Documentos sem abrir e Imagens aberta, a etapa terminava com ressalvas dizendo só "Imagens: aberta no Explorador". | O resumo diz qual: "Documentos: não abriu no Explorador; Imagens: aberta no Explorador". |
| Q2 | Procurar duplicados (ou limpar a Downloads) e desistir no meio contava como etapa feita: "Downloads: nada mudou", com o sinal de feito no resumo e na conta de "etapas executadas". | Sem nada mudado, a etapa é ignorada ("nenhuma pasta foi mexida"), como nas outras telas com escolha. |

Os testes também acharam os três do designer: a faixa genérica (D1), a parte automática cancelada (D2) e o resumo dos navegadores (D3).

Cada conferência das correções falha no código de antes e passa no de agora; as que conferem o que foi mantido passam nos dois.

## Engenharia

**Por dentro**
- **Maintenance.psm1:**
  - `Set-WinForgeMaintenanceView` (nova): a faixa do fim e a da parte automática cancelada;
  - `Get-WinForgeMaintenanceStepTarget` (nova): a tela de cada etapa, para o botão;
  - `Format-WinForgeMaintenanceGain` (nova): o espaço ganho, que o desfecho e a faixa usam;
  - o plano sem a etapa das atualizações antecipadas, com o motivo no comentário.
- **Tweaks.psm1:** `Disable-WinForgeEarlyUpdates` saiu; `Get-WinForgeTweakReviewSkipped` sem as antecipadas; `Invoke-WinForgeTweakReview` as deixa de fora com a política da empresa; a descrição da chave.
- **Software.psm1:** o detalhe de `Update-WinForgeBrowsers` com "Nome: o que houve".
- **Cleanup.psm1:** `Invoke-WinForgeFolderReview` diz a pasta que não abriu e não conta o que não mudou nada.
- **WinForge.Gui.ps1:** com o botão na faixa, o fim do Otimizar continua abrindo no Resumo, onde está a linha da etapa com problema. Outras telas com botão (as ameaças, por exemplo) abrem na última seção, como antes.
- **Traduções:** 10 novas e 10 que saíram de uso; 5.344 ao todo.

**Conferido na nuvem**
- **As conferências novas do Otimizar, todas passando:** 146 em português e 151 em inglês e em espanhol.
- **As 84 ações rodaram de novo 336 vezes** com o Windows simulado: nenhum erro escapou. O resultado é o mesmo da R27.
- **As de antes continuam passando:**
  - as 146, 147 e 147 do Verificar o PC, as 109, 98 e 101 da Busca e as 164, 169 e 169 do Sobre o WinForge;
  - as 265, 270 e 270 da Personalização, as 412, 422 e 422 dos Ajustes do Windows (com a revisão do Otimizar), as 144, 153 e 153 da Rede, as 106, 115 e 115 dos Programas, as 110, 117 e 117 das Atualizações, as 112, 119 e 119 do Reparo, as 96, 102 e 102 do Desempenho, as 178, 187 e 187 da Limpeza, as 134, 142 e 142 da Segurança e as 212, 224 e 224 do Diagnóstico;
  - as 243, 245 e 250 da Manutenção: sete conferências da R14 contavam 21 etapas e passaram a contar 20, e duas conferências por etapa somam duas a menos;
  - as 241 do Início nos três idiomas;
  - as 83 do QA geral, as 80 da R11 e as 60 da R12;
  - as 59 da R9 e as 52 da R10;
  - as 66 da QA, as 28 da integração e as 26 da R7;
  - o motor de instalação, a atualização simulada e o Setup de verdade (da R27 para esta), e o pacote de suporte;
  - as traduções (5.344/5.344), as 159 referências nos três idiomas e a busca dos 102 itens;
  - nenhuma chamada com parâmetro que não existe, nenhuma função sem uso e nenhum aviso novo do analisador.

## O que só um PC mostra

Isto entrou no roteiro de conferência:
- **As atualizações antecipadas ligadas continuam ligadas** depois de um Otimizar.
- **A faixa num PC de verdade:** "PC otimizado" num PC em dia; com uma etapa com problema, o nome, o motivo e o botão.
- **A parte automática cancelada:** o título novo.
- **Os navegadores:** o resumo com o nome de cada um, e a versão do Chrome depois do atualizador novo.

## Fontes
- [Get Windows updates as soon as they're available for your device](https://support.microsoft.com/en-us/windows/cad7b32b-001e-435b-9110-f18309b54168) (Microsoft): a opção traz antes as atualizações que não são de segurança; ligada ou desligada, as de segurança chegam do mesmo jeito; ligada, pode haver mais reinícios por mês; num PC gerenciado, a política de conteúdo opcional decide.
- [chrome/updater/constants.h](https://chromium.googlesource.com/chromium/src/+/lkgr/chrome/updater/constants.h) (Chromium): `update-apps` "Updates the apps."; `system`, "The updater needs to operate in the system context."
