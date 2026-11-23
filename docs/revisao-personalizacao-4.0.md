# WinForge 4.0 — revisão da Personalização (R24)

**Data:** 19/11/2026 · **Versão:** Build 4.0 em preparação, depois da R23

**Pedido:** juntar quatro olhares para a tela e a função de Personalização:
- **Analista de UX/UI Sênior (designer):** revisa cada detalhe da interface e orienta o engenheiro.
- **Especialista Microsoft (MVP Windows):** confere se os comandos e as alterações no Windows são feitos da melhor forma disponível hoje, de modo seguro e robusto, e se fazem sentido e mudam o que devem no PC.
- **QA Sênior:** testa todas as funções da tela.
- **Engenheiro de Software Sênior:** aplica as correções.

**Resultado:** 5 achados, todos corrigidos.

| Olhar | Achados |
|---|---|
| Designer | 3: as linhas da cor de destaque e das teclas do idioma sem o estado de agora, e as faixas genéricas da cor de destaque quando o Explorador não reinicia e quando a troca falha |
| MVP Windows | 2: a cor automática pedindo para reiniciar o Explorador sem nada a mostrar, e a descrição da cor no Iniciar e na barra de tarefas, que não batia com o que a Microsoft diz |
| QA | Nenhum próprio: os testes acharam os 5, e nenhum texto em português sobrou nas telas em inglês e em espanhol. |
| Engenharia | Nenhum próprio: aplicou os 5. |

Nada rodou num Windows de verdade. O Windows (o registro, o Explorador, os avisos aos programas, a sessão e a build) foi simulado. O que só um PC mostra entrou no roteiro de conferência.

## A Personalização hoje

No alto, o botão Personalização do Windows (abre a tela de fundo, os temas, as cores e as fontes nas Configurações) e Atualizar estado. Embaixo, as chaves, por categoria, cada uma com o estado lido do Windows na hora:
- **Barra de tarefas e Iniciar:**
  - barra alinhada à esquerda;
  - finalizar tarefa pela barra (do Windows 11 23H2 em diante);
  - pesquisa na barra;
  - botão Visão de Tarefas;
  - segundos no relógio;
  - Widgets;
  - botão do Copilot (só até o Windows 11 23H2; depois, o Copilot é um aplicativo comum);
  - agrupar os botões (do 23H2 em diante);
  - recomendações no Iniciar.
- **Área de trabalho:** os ícones da Lixeira e de Este Computador.
- **Cores e transparência:** modo escuro, transparência, a cor de destaque no Iniciar e na barra e nas barras de título, e a linha **Cor de destaque**, que escolhe a cor.
- **Tela de bloqueio:** clima e notícias, notificações, dicas, e a linha **Tela de bloqueio do Windows**, que abre a página dela nas Configurações.

No Windows 10, aparecem só as chaves que existem nele (11 das 18). A chave dos Widgets pede Administrador e mostra o escudo.

O que cada ação muda:
- **A chave de um ajuste:** grava o que as Configurações gravam, guarda antes o valor de agora e anota no Histórico. Desligar volta ao valor guardado. As chaves das cores avisam os programas na hora; as da barra e da área de trabalho oferecem reiniciar o Explorador.
- **Cor de destaque:** uma das oito cores principais do Windows, ou a automática, tirada do papel de parede.
- **Os atalhos:** abrem as páginas das Configurações (`ms-settings:personalization` e `ms-settings:lockscreen`).

## Designer (UX/UI)

| # | O que estava | Orientação | Como ficou |
|---|---|---|---|
| D1 | As chaves mostram o estado de agora, mas as linhas Cor de destaque e Teclas que trocam o idioma do teclado só mostravam a frase do que fazem: para saber a cor de agora, era preciso abrir a ação. | A linha diz o estado, como as chaves; a frase inteira continua na dica. | "Agora: Azul" (ou "Automática", ou "outra cor") e "Agora: Alt + Shift e Ctrl + Shift". A linha das teclas fica nos Ajustes do Windows. |
| D2 | Com o Explorador que não reiniciava depois de trocar a cor, a faixa dizia "Concluído com ressalvas: o Explorador não reiniciou", sem dizer que a cor tinha mudado. | O título diz a cor; a frase, quando o Iniciar e a barra mudam. | "Cor de destaque: Verde", com "O Explorador não reiniciou; o Iniciar e a barra de tarefas mudam de cor quando você sair e entrar de novo no Windows." |
| D3 | Uma troca de cor que falhava terminava em "Não foi concluído: …", com a mensagem crua. | O título diz que a cor ficou como estava; o motivo vem legível. | "A cor de destaque não mudou", com o motivo no idioma da tela. |

**Conferido e mantido:**
- sem destaque na página: o botão do alto é a Personalização do Windows, que leva ao que o WinForge não faz (papel de parede, temas, fontes);
- a cor de destaque e a tela de bloqueio como linhas nos grupos delas, no fim das chaves;
- as descrições em até 60 letras nos três idiomas, e o "o que é" de cada chave em até 100 letras em português;
- a cor de agora antes da escolha, as oito cores com o azul do Windows 11 primeiro, e Cancelar como padrão;
- com o modo claro, a tela diz o que ativar para pintar o Iniciar e a barra, em vez de reiniciar o Explorador à toa.

## Especialista Microsoft (MVP Windows)

**O que mudou**

| # | O que estava | Por que não é o melhor | Como ficou |
|---|---|---|---|
| M1 | Escolher a cor **Automática** com o modo escuro e a cor na barra ligados perguntava se reiniciava o Explorador "para a barra de tarefas e o Iniciar mudarem de cor". | Na automática, o Windows só calcula a cor nova quando o papel de parede muda (a própria tela diz isso): reiniciar o Explorador fecharia as janelas de pastas e interromperia cópias sem mostrar nada novo. | A pergunta só vem com uma das oito cores escolhida. |
| M2 | A chave da cor no Iniciar e na barra dizia "só funciona com o modo escuro". | A Microsoft diz que a opção só existe com o modo do **Windows** escuro ou personalizado (o Windows escuro com os aplicativos claros). O WinForge já conferia o modo do Windows, mas a frase sugeria que os aplicativos também precisavam ficar escuros. | "Pinta o Iniciar e a barra de tarefas com a cor de destaque; só com o Windows no modo escuro." |

**Cada ajuste, conferido**

| Ajuste | Como o WinForge faz | Veredito |
|---|---|---|
| Barra à esquerda, Visão de Tarefas, segundos no relógio, recomendações no Iniciar | Os valores que as Configurações gravam em `Explorer\Advanced` (`TaskbarAl`, `ShowTaskViewButton`, `ShowSecondsInSystemClock`, `Start_IrisRecommendations`), com o Explorador reiniciado se a pessoa quiser. | Certo. |
| Finalizar tarefa pela barra | `TaskbarDeveloperSettings\TaskbarEndTask` = 1, a opção de Para desenvolvedores, do Windows 11 23H2 em diante. | Certo. |
| Nunca agrupar | `TaskbarGlomLevel` e `MMTaskbarGlomLevel` = 2, do 23H2 em diante (antes dele, o Windows 11 não lê o valor). | Certo. |
| Pesquisa na barra | `SearchboxTaskbarMode` = 0. Onde o Windows protege o valor, a tela diz onde mudar: nas Configurações, no Windows 11, ou no clique direito na barra, no Windows 10. | Certo. |
| Widgets | A política `AllowNewsAndInterests` = 0 em `HKLM\SOFTWARE\Policies\Microsoft\Dsh`. O botão dos Widgets nas Configurações é protegido pelo Windows; a política é a forma documentada e vale para os Widgets inteiros, com o botão da barra. Desfazer apaga a política. | Certo: a Microsoft a documenta para o computador, e a chave diz "Permitir os Widgets". |
| Botão do Copilot | `ShowCopilotButton` = 0, só até o Windows 11 23H2. | Certo. |
| Ícones da área de trabalho | Os valores de `HideDesktopIcons\NewStartPanel` da Lixeira e de Este Computador, os mesmos das Configurações de ícones da área de trabalho. | Certo. |
| Modo escuro, transparência | `AppsUseLightTheme` e `SystemUsesLightTheme` = 0; `EnableTransparency` = 0; os programas são avisados na hora (`ImmersiveColorSet`). | Certo. |
| Cor no Iniciar e na barra; nas barras de título | `ColorPrevalence` = 1 em `Themes\Personalize`; `ColorPrevalence` = 1 em `DWM`. Com o modo do Windows claro, a tela diz que falta o modo escuro. | Certo, com o M2. A das barras de título não depende do modo, como a Microsoft diz. |
| Clima e notícias na tela de bloqueio | O valor do usuário `Lock Screen\LockScreenWidgetsEnabled` = 0, e não a política. | Mantido: a política `DisableWidgetsOnLockScreen` só vale no Windows Insider, pela Microsoft, e travaria a chave das Configurações. |
| Notificações na tela de bloqueio | `NOC_GLOBAL_SETTING_ALLOW_TOASTS_ABOVE_LOCK` = 0, a chave das Configurações, e `LockScreenToastEnabled` = 0. | Certo. |
| Dicas na tela de bloqueio | `RotatingLockScreenOverlayEnabled` e `SubscribedContent-338387Enabled` = 0, com o Windows avisado. | Certo. |
| Cor de destaque | A paleta e as cores do Iniciar em `Explorer\Accent`, a cor das janelas em `DWM`, e a escolha automática desligada por último, como o Windows grava ao escolher a cor nas Configurações; os programas são avisados na hora. | Mantido. Gravar a escolha automática por último faz uma falha no meio não desligar a automática de quem a usava. |
| Os atalhos | `ms-settings:personalization`, `ms-settings:lockscreen` e `ms-settings:taskbar`. | Certo: são os endereços que a Microsoft lista. |

**Conferido e mantido**
- **Desfazer não passa por cima de uma escolha mais nova:** um valor mudado depois do WinForge fica como está, e a tela diz.
- **Elevado com outra conta,** as chaves e a cor de destaque, que valem para o perfil do usuário, ficam de fora, para não mudar o perfil errado.
- **O que o Windows protege** (a pesquisa e os Widgets, em alguns PCs) não é forçado: a tela diz onde a pessoa muda.

## QA Sênior

**Como foi testado:** cada função da página rodou com o Windows simulado, nos três idiomas: 265 conferências em português e 270 em inglês e em espanhol. As 5 a mais conferem, em cada seção, que nenhum texto do português aparece na tela.
- **A página e o catálogo:**
  - cada item existe e tem até 60 letras;
  - os atalhos abrem as páginas certas, sem destaque;
  - a cor e a tela de bloqueio estão nos grupos delas, e as quatro categorias, na ordem;
  - o estado de cada chave é lido;
  - o que aparece no Windows 11 24H2, no 23H2, no 22H2 e no Windows 10;
  - a linha de estado da cor de destaque e das teclas do idioma.
- **As 18 chaves, uma a uma** (no Windows 11 24H2 e, o botão do Copilot, no 23H2), ligar e desligar:
  - o valor gravado, conferido contra o que as Configurações gravam;
  - o Explorador só nas da barra e da área de trabalho, e o aviso aos programas nas das cores;
  - o backup e o Histórico;
  - o registro voltando exatamente ao que era.
- **A chave nos casos de borda (9):**
  - a pesquisa protegida no Windows 11 e no 10;
  - os Widgets sem Administrador, e desfazer os Widgets com a política protegida;
  - a cor na barra com o modo claro, com o escuro e com o personalizado;
  - o modo escuro elevado com outra conta;
  - Desfazer ajustes do WinForge com a pesquisa protegida.
- **A cor de destaque (21 situações):**
  - cancelar, e as oito cores, cada uma conferida em hexadecimal (`AccentColorMenu`, `AccentColor`, `ColorizationColor`, `ColorizationAfterglow` e a paleta de 32 bytes, do mais claro ao mais escuro, com a cor escolhida na quarta posição), com a escolha automática desligada por último;
  - o modo claro, o escuro com e sem reiniciar, e o Explorador que não reinicia;
  - a automática, a falha no meio e outra conta;
  - a cor de agora: automática, a exata, o azul do Windows 10, outra e sem leitura.
- **Os perfis e o lote:** os ajustes da Personalização nos cinco perfis e nos recomendados; um lote de quatro, com o Explorador uma vez e o aviso da cor.
- **Os textos:** nenhum marcador `{0}` sobrando e nenhum texto do português na tela em inglês e em espanhol.

**Achados:** nenhum próprio. As 7 conferências das correções (a linha de estado, a faixa do Explorador, a automática sem o Explorador e a faixa da falha) falham no código de antes e passam no de agora.

## Engenharia

**Por dentro**
- **Tweaks.psm1:**
  - `Get-WinForgeTweakActionState` (nova): o "Agora: …" das linhas de ação;
  - `Set-WinForgeAccentColor`: o Explorador só com uma cor escolhida; as faixas do Explorador que não reinicia e da falha;
  - a descrição da cor no Iniciar e na barra de tarefas.
- **WinForge.Gui.ps1:** `Update-GuiTweaksList` põe o estado de agora nas linhas de ação, numa cópia do item da navegação.
- **Traduções:** 4 novas e 1 que saiu de uso; 5.323 ao todo.

**Conferido na nuvem**
- **As conferências novas da Personalização, todas passando:** 265 em português e 270 em inglês e em espanhol.

  Cada conferência das correções falha no código de antes e passa no de agora.
- **As 84 ações rodaram de novo 336 vezes** com o Windows simulado: nenhum erro escapou, e o resultado é o mesmo da R23, fora a faixa nova da cor de destaque que falha.
- **As de antes continuam passando:**
  - as 412, 422 e 422 dos Ajustes do Windows, as 144, 153 e 153 da Rede, as 106, 115 e 115 dos Programas, as 110, 117 e 117 das Atualizações, as 112, 119 e 119 do Reparo, as 96, 102 e 102 do Desempenho, as 178, 187 e 187 da Limpeza, as 134, 142 e 142 da Segurança e as 212, 224 e 224 do Diagnóstico;
  - as 245, 247 e 252 da Manutenção e as 241 do Início nos três idiomas;
  - as 83 do QA geral, as 80 da R11 e as 60 da R12;
  - as 59 da R9 e as 52 da R10;
  - as 66 da QA, as 28 da integração e as 26 da R7;
  - o motor de instalação, a atualização simulada e o Setup de verdade (da R23 para esta), e o pacote de suporte;
  - as traduções (5.323/5.323), as 159 referências nos três idiomas e a busca dos 102 itens;
  - nenhuma chamada com parâmetro que não existe, nenhuma função sem uso e nenhum aviso novo do analisador.

## O que só um PC mostra

Isto entrou no roteiro de conferência:
- **A linha da cor de destaque:** "Agora: Azul" (ou a cor de agora), e, depois de escolher Verde, "Agora: Verde". Nos Ajustes do Windows, a linha das teclas do idioma diz as teclas de agora.
- **A cor automática com o modo escuro e a cor na barra ligados:** nenhuma pergunta sobre o Explorador. Ao trocar o papel de parede, a cor muda.
- **Uma cor escolhida com o modo escuro e a cor na barra ligados:** a pergunta do Explorador; com Sim, o Iniciar e a barra mudam de cor.
- **A cor no Iniciar e na barra com o modo personalizado** (o Windows escuro e os aplicativos claros): a cor aparece, sem a frase de que falta o modo escuro.

**Não visto, e por quê:**
- **Se a cor de destaque gravada aparece nas barras de título na hora:** o Windows não documenta como as janelas abertas releem a cor; pode ser preciso sair e entrar.
- **O valor de clima e notícias na tela de bloqueio em cada versão do Windows 11:** a Microsoft não documenta o valor do usuário. O que se tem é a página de Configurações e a política, que só vale no Windows Insider.
- **A pesquisa e os Widgets protegidos:** a proteção do Windows não chega a todo PC, e a recusa só se vê num que a tenha.

## Fontes
- [Personalize your Colors in Windows (Suporte da Microsoft)](https://support.microsoft.com/en-us/help/4531350): "Show accent color on Start and taskbar" só com o modo do Windows escuro ou personalizado; a cor automática a partir da tela de fundo; a cor nas barras de título sem depender do modo.
- [Policy CSP - NewsAndInterests (Microsoft Learn)](https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-newsandinterests): `AllowNewsAndInterests` em `SOFTWARE\Policies\Microsoft\Dsh`, para o computador, valendo para os Widgets inteiros, com o conteúdo da barra; `DisableWidgetsOnLockScreen`, só no Windows Insider.
- [Launch the Windows Settings app (Microsoft Learn)](https://learn.microsoft.com/windows/apps/develop/launch/launch-settings-app): `ms-settings:personalization`, `ms-settings:lockscreen` e `ms-settings:taskbar`.
