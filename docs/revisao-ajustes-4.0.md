# WinForge 4.0 — revisão dos Ajustes do Windows (R23)

**Data:** 19/11/2026 · **Versão:** Build 4.0 em preparação, depois da R22

**Pedido:** juntar quatro olhares para a tela e a função de Ajustes do Windows:
- **Analista de UX/UI Sênior (designer):** revisa cada detalhe da interface e orienta o engenheiro.
- **Especialista Microsoft (MVP Windows):** confere se os comandos e as alterações no Windows são feitos da melhor forma disponível hoje, de modo seguro e robusto, e se fazem sentido e mudam o que devem no PC.
- **QA Sênior:** testa todas as funções da tela.
- **Engenheiro de Software Sênior:** aplica as correções.

**Resultado:** 15 achados, todos corrigidos.

| Olhar | Achados |
|---|---|
| Designer | 11: as faixas genéricas quando a chave não muda nada, quando ela falha, quando o Explorador não reinicia, quando nenhum ajuste do lote é aplicado, quando os recomendados ou o perfil já estão aplicados, quando não há o que exportar, quando o arquivo não é importado e quando nada é desfeito; o Explorador reiniciado à toa; e o aviso do notebook dito duas vezes |
| MVP Windows | 2: o ponto de restauração antes de aplicar ajustes, que aceitava um ponto de horas atrás como rede de segurança; e o Recall nos Windows 11 que não têm o Recall |
| QA | 2 próprios: "notebook:" em português na revisão do Otimizar em inglês e em espanhol, e "Documentos\WinForge" em português na faixa da exportação. Os testes também acharam todos os outros. |
| Engenharia | Nenhum próprio: aplicou os 15. |

Nada rodou num Windows de verdade. O Windows (o registro, o `powercfg`, a Restauração do Sistema, o Explorador, a sessão e a build) foi simulado. O que só um PC mostra entrou no roteiro de conferência.

## Os Ajustes do Windows hoje

A página tem as ações e, abaixo delas, as chaves dos ajustes, por categoria:
1. **As ações:**
   - Aplicar ajustes recomendados, em destaque;
   - Perfis de ajustes (Essencial, Trabalho, Jogos, Privacidade e Notebook);
   - Criar ponto de restauração;
   - Exportar ajustes aplicados e Importar ajustes;
   - Desfazer ajustes do WinForge.
2. **As chaves**, cada uma com o estado lido do Windows na hora:
   - **Explorador (7):** extensões, arquivos ocultos, menu de contexto clássico, abrir em Este Computador, Reprodução Automática, recentes e avisos de produtos;
   - **Privacidade e sugestões (12):** dicas, ID de publicidade, web na busca, Recall, experiências personalizadas, pedidos de opinião, histórico de atividades, dados de diagnóstico, programas abertos, fala online, digitação e escrita à mão, destaques da pesquisa;
   - **Windows Update (2):** atualizações antecipadas e atualizações entre PCs;
   - **Notificações e teclado (3):** notificações, atalho das Teclas de Aderência e histórico da área de transferência, com as linhas Teclas que trocam o idioma do teclado e Notificações e Não incomodar;
   - **Jogos (3):** Game Bar e gravação, Modo de Jogo e aceleração do mouse;
   - **Energia e desempenho:** o Sensor de Armazenamento (e, no Windows 10, os aplicativos em segundo plano) e, recolhidos em "Mostrar ajustes avançados", Inicialização Rápida, Alto desempenho, economia do PCI Express, tela e suspensão, hibernação e agendamento de GPU.

Recomendados, Perfis, Criar ponto, Importar e Desfazer pedem Administrador e mostram o escudo; nas chaves, o escudo aparece nas que pedem Administrador (as que valem para o PC inteiro e as políticas).

O que cada ação muda:
- **A chave de um ajuste:** grava o que as Configurações do Windows gravam (ou a política do Windows, nos que dizem "Permitir"), guarda antes o valor de agora e anota no Histórico; desligar volta ao valor guardado ou, sem ele, ao padrão do Windows.
- **Recomendados, Perfis e Importar:** aplicam os ajustes marcados de uma vez, com o ponto de restauração antes (a pergunta começa no Sim) e o Explorador reiniciado depois, se a pessoa quiser. No notebook, o que gasta bateria vem desmarcado.
- **Criar ponto de restauração:** cria o ponto agora; com a Proteção do Sistema desligada, oferece ligá-la.
- **Exportar:** grava num arquivo quais ajustes estão aplicados. **Importar:** aplica os de um arquivo, depois de a pessoa escolher.
- **Desfazer ajustes do WinForge:** devolve tudo o que o WinForge mudou, aqui e na Personalização, com Não como padrão.
- **Teclas que trocam o idioma do teclado:** grava as teclas do idioma e do teclado do mesmo idioma e avisa o Windows.

## Designer (UX/UI)

| # | O que estava | Orientação | Como ficou |
|---|---|---|---|
| D1 | A chave cujo valor o Windows não manteve (uma política impondo outro) terminava em "Concluído com ressalvas: o Windows não manteve o valor"; a que não conseguia desfazer, em "Concluído com ressalvas: continua ativado". | O título diz o que a pessoa quer saber: a chave mudou? | "ID de publicidade: nada mudou", com "O valor foi gravado, mas o Windows não o manteve. Uma política da organização pode estar impondo outro valor." (ou "Continua ativado. Uma política…"). |
| D2 | A chave que falhava (acesso negado, um erro do Windows) terminava em "Não foi concluído: …"; a configuração que o Windows protege, em "Concluído com ressalvas". | O mesmo título, com o motivo legível. | "Histórico da área de transferência: nada mudou", com "O Windows negou o acesso ao registro." no idioma da tela; na protegida, onde mudar nas Configurações. |
| D3 | A chave, o lote e o Desfazer com o Explorador que não reiniciava terminavam em "Concluído com ressalvas: o Explorador não reiniciou", sem dizer que o ajuste tinha sido feito. | O título diz como ficou; a frase, quando a mudança aparece. | "Mostrar arquivos e pastas ocultos: ativado" (ou "4 ajustes aplicados", "4 ajustes desfeitos"), com "O Explorador não reiniciou; a mudança aparece quando você sair e entrar de novo no Windows." |
| D4 | A chave oferecia reiniciar o Explorador mesmo quando nada tinha mudado (o valor que o Windows não manteve, nada a desfazer). | Reiniciar fecha as janelas de pastas e interrompe cópias: só quando há o que mostrar. | A pergunta só aparece quando o ajuste mudou. |
| D5 | O lote em que nenhum ajuste entrava dizia "0 ajustes aplicados, 4 com problema." e terminava em "Não foi concluído". | Dizer o fato e onde está o motivo. | "Nenhum ajuste foi aplicado.", e a faixa "Nenhum ajuste foi aplicado", com "O motivo de cada um está no resumo." |
| D6 | Com todos os recomendados já aplicados, a tela dizia duas vezes a mesma coisa ("Todos os ajustes recomendados já estão aplicados." e "Nenhum ajuste a aplicar.") e terminava em "Nada a fazer". | Uma frase, e a faixa dizendo o mesmo. | Uma frase só, e a faixa "Os ajustes recomendados já estão aplicados". |
| D7 | Um perfil já aplicado terminava em "Nada a fazer: nada a aplicar". | Dizer qual. | "O perfil Essencial já está aplicado". |
| D8 | Exportar sem nenhum ajuste aplicado terminava em "Nada a fazer: nada a exportar". | Dizer por quê. | "Nenhum ajuste para exportar", com "Nenhum ajuste do WinForge está aplicado neste PC." |
| D9 | Importar um arquivo que não é uma exportação terminava em "Não foi concluído: O arquivo não é um JSON válido." | O título diz o que aconteceu; o motivo vem embaixo. | "O arquivo não foi importado", com o motivo. |
| D10 | Desfazer sem nada a desfazer terminava em "Nada a fazer"; sem conseguir desfazer nenhum, em "Não foi concluído: nenhum ajuste pôde ser desfeito". | O título diz o fato; a frase, que o backup ficou. | "Nenhum ajuste do WinForge para desfazer"; "Nenhum ajuste foi desfeito", com "O backup foi mantido para uma nova tentativa; o motivo de cada um está no resumo." |
| D11 | O aviso do notebook vinha dito duas vezes: "Atenção em notebook: Em notebook, consome mais bateria…" na chave, e "[notebook: Em notebook, …]" nas listas de escolha. E o Alto desempenho dizia "em notebook reduz a autonomia" também num PC de mesa. | O aviso já diz que é do notebook; a descrição vale para qualquer PC. | "Em notebook, consome mais bateria e esquenta mais." na cor de atenção; nas listas, logo depois da descrição. O Alto desempenho: "Prioriza o desempenho; o PC passa a gastar mais energia." |

**Conferido e mantido:**
- um destaque só na página, Aplicar ajustes recomendados, e as descrições em até 60 letras nos três idiomas;
- o escudo nas cinco ações que pedem Administrador;
- a chave mostra o recurso do Windows como ele está agora ("Notificações: Desativado"), e não o que o WinForge fez; nas políticas, ela diz "Permitir";
- a chave volta ao estado real quando a ação é cancelada ou falha, e uma página velha não faz o contrário do pedido;
- os ajustes de energia e desempenho recolhidos em "Mostrar ajustes avançados", com o aviso de bateria;
- Desfazer ajustes do WinForge e a chave do que gasta bateria no notebook começam no Não; no Desfazer, a lista do que sai vem antes da pergunta, com a data de cada um.

## Especialista Microsoft (MVP Windows)

**O que mudou**

| # | O que estava | Por que não é o melhor | Como ficou |
|---|---|---|---|
| M1 | Antes de aplicar os recomendados, um perfil ou um arquivo importado, o ponto de restauração seguia o limite do Windows de um por dia: com um ponto de horas atrás (de uma atualização do Windows, de um instalador), nenhum era criado, e a tela dizia "Já existe um ponto de restauração recente" e seguia. | Voltar àquele ponto desfaria também tudo o que mudou depois dele. Pela Microsoft, o limite de 24 horas vale quando não há o valor `SystemRestorePointCreationFrequency`; com ele em 0, o ponto é sempre criado. O começo do Otimizar e o ponto pedido sozinho já faziam assim. | O ponto é criado agora: o limite fica em 0 só durante a criação e volta ao que era. |
| M2 | A chave do Recall aparecia em todo Windows 11 e gravava a política nos 22H2 e 23H2, que não têm o Recall. | A política "Desativar o salvamento de instantâneos para o Recall" vale do Windows 11 24H2 em diante; antes, a chave mostraria "Desativado" para um recurso que não existe. | A chave só aparece da build 26100 (24H2) em diante. A política continua no computador (HKLM): a Microsoft a documenta para o computador e para o usuário. |

**Cada ajuste, conferido**

| Ajuste | Como o WinForge faz | Veredito |
|---|---|---|
| Extensões, arquivos ocultos, abrir em Este Computador, recentes, avisos de produtos, programas abertos | Os valores que as Opções de Pasta e as Configurações gravam em `HKCU\…\Explorer` e `Explorer\Advanced` (`HideFileExt`, `Hidden`, `LaunchTo`, `ShowRecent`, `ShowFrequent`, `ShowSyncProviderNotifications`, `Start_TrackProgs`), com o Explorador reiniciado se a pessoa quiser. Os arquivos protegidos do sistema continuam ocultos. | Certo, com o D3 e o D4. |
| Menu de contexto clássico | A chave vazia `HKCU\Software\Classes\CLSID\{86ca1aa0…}\InprocServer32`; desfazer apaga a chave. | Não é uma opção documentada pela Microsoft, mas é a forma conhecida, só no perfil do usuário e desfeita por inteiro. Mantido. |
| Reprodução Automática | `DisableAutoplay` = 1, o que a chave das Configurações grava. | Certo. |
| Dicas e sugestões, ID de publicidade, experiências personalizadas, pedidos de opinião, fala online, digitação e escrita à mão, destaques da pesquisa | Os valores do usuário que as Configurações gravam (`ContentDeliveryManager`, `AdvertisingInfo\Enabled`, `TailoredExperiencesWithDiagnosticDataEnabled`, `Siuf\Rules`, `OnlineSpeechPrivacy\HasAccepted`, `InputPersonalization`, `IsDynamicSearchBoxEnabled`). | Certo. |
| Web na busca do Iniciar | A política do usuário `DisableSearchBoxSuggestions`. | Certo; pede Administrador porque `HKCU\Software\Policies` é só leitura para o usuário comum. |
| Recall | A política `DisableAIDataAnalysis` = 1 em `HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsAI`. | Certo, com o M2. |
| Histórico de atividades, dados de diagnóstico | As políticas `PublishUserActivities` e `UploadUserActivities` = 0; `AllowTelemetry` = 1 (só o obrigatório; o 0 também conta como aplicado). | Certo; a descrição dos dados de diagnóstico já diz que a opção aparece como gerenciada. |
| Atualizações antecipadas | `IsContinuousInnovationOptedIn` = 0, a chave "Receba as atualizações mais recentes assim que estiverem disponíveis"; sem o valor, ela já vem desligada. | Certo. |
| Atualizações entre PCs | A política `DODownloadMode` = 0 (só HTTP, sem compartilhar); 99 e 100 também contam como desligado. | Certo: a Microsoft indica o 0 para desligar o compartilhamento, e diz que o 100 está obsoleto no Windows 11. O WinForge nunca grava o 100. |
| Notificações | `ToastEnabled` = 0, o que a chave das Configurações grava. | Certo; vale depois de sair e entrar, como a descrição diz. |
| Atalho das Teclas de Aderência | Só o bit 4 de `Flags` (o atalho) nas Teclas de Aderência, de Filtragem e de Alternância; o Windows é avisado na hora. As outras opções que a pessoa escolheu ficam. | Certo. |
| Histórico da área de transferência | `EnableClipboardHistory` = 1. | Certo. |
| Game Bar e gravação | Os valores do usuário (`AppCaptureEnabled`, `GameDVR_Enabled`, o botão do controle) e a política `AllowGameDVR` = 0 para o computador; a Game Bar aberta é fechada. | Mantido: a política é a forma que segura a gravação; a chave lê os valores do usuário, e desfazer apaga a política. |
| Modo de Jogo | `AutoGameModeEnabled`; sem o valor, ele já vem ativado. | Certo. |
| Aceleração do mouse | `MouseSpeed`, `MouseThreshold1` e `MouseThreshold2` = "0" (texto, como o Painel de Controle grava), aplicados na hora. | Certo. |
| Sensor de Armazenamento | `StoragePolicy\01` = 1, a chave das Configurações. | Certo. |
| Inicialização Rápida e hibernação | `HiberbootEnabled` = 0; `powercfg /hibernate off`. Ligar a Inicialização Rápida pela chave liga a hibernação junto, e diz. | Certo. |
| Alto desempenho | `powercfg /setactive` do plano Alto desempenho; sem ele na lista, uma cópia (`/duplicatescheme`), reaproveitada e apagada ao desfazer. | Certo. |
| Economia do PCI Express, tela e suspensão | `powercfg /setacvalueindex` e `/setdcvalueindex` no plano ativo (`SUB_PCIEXPRESS ASPM`, `VIDEOIDLE`, `STANDBYIDLE`, `HIBERNATEIDLE`), guardando o valor de cada plano. | Certo. |
| Agendamento de GPU | `HwSchMode` = 2; sem o valor, quem decide é o driver, e a chave mostra "Não identificado". Pede reinício. | Certo. |
| Criar ponto de restauração | `Checkpoint-Computer`, conferido na lista do Windows; o limite de um por dia fica em 0 só durante a criação; a Proteção do Sistema desligada é oferecida para ligar; a política que a desliga, respeitada. | Certo, com o M1. |
| Teclas do idioma do teclado | `HKCU\Keyboard Layout\Toggle`: `Language Hotkey` e `Hotkey` (1 Alt + Shift, 2 Ctrl + Shift, 3 nenhuma) e `Layout Hotkey`, como texto, com o Windows avisado. | Certo. |

**Conferido e mantido**
- **Quatro ajustes usam a política do Windows mesmo havendo uma opção nas Configurações** (Recall, histórico de atividades, dados de diagnóstico e atualizações entre PCs): a política é o que segura o valor. Por isso a chave deles diz "Permitir", e desfazer apaga a política.
- **Desfazer não passa por cima de uma escolha mais nova:** um valor mudado depois do WinForge fica como está, e a tela diz.
- **Elevado com outra conta,** os ajustes do perfil do usuário ficam de fora, para não mudar o perfil errado.

## QA Sênior

**Como foi testado:** cada função da página rodou com o Windows simulado, nos três idiomas: 412 conferências em português e 422 em inglês e em espanhol. As 10 a mais conferem, em cada seção, que nenhum texto do português aparece na tela.
- **A página e o catálogo:** cada item existe e tem até 60 letras, o escudo nas cinco ações, um destaque só, as seis categorias na ordem, o estado de cada ajuste, os avançados e o que aparece no Windows 10, no 11 23H2 e no 11 24H2.
- **As 34 chaves da página, uma a uma:** ligar e desligar, conferindo o valor gravado contra o que a Microsoft documenta, o backup, o Histórico e que o registro e os planos de energia voltam exatamente ao que eram.
- **A chave nos casos de borda (13):** sem Administrador, elevado com outra conta, o notebook com o Alto desempenho, o estado não identificado, a página velha, o valor que o Windows não mantém, o acesso negado, sem o valor de antes, o Explorador recusado, o Explorador que não reinicia, nada mudou, o Alto desempenho sem o plano (a cópia criada e apagada) e a Inicialização Rápida sem a hibernação.
- **Aplicar ajustes recomendados (6):** sem Administrador, cancelar, aplicar com um ponto de cinco horas atrás, já aplicados, nenhum aplicado e sem a Proteção do Sistema.
- **Perfis (3, e os cinco perfis):** cancelar, Jogos num notebook, um perfil já aplicado; cada perfil só com ajustes do catálogo.
- **Criar ponto de restauração (5):** sem Administrador, criado com um ponto de horas atrás, a Proteção desligada (ligar e recusar) e a política.
- **Exportar e Importar (6):** nada a exportar, quatro exportados (o arquivo, a pasta com o arquivo selecionado e o nome da pasta Documentos), importar da lista, um arquivo inválido, só ajustes de outra versão e cancelar.
- **Desfazer ajustes do WinForge (5):** nada, Não, todos (com o plano de energia), nenhum e o que já foi mudado depois.
- **Teclas do idioma do teclado (6):** cancelar, as quatro escolhas (o que é gravado, como texto) e outra conta.
- **A revisão do Otimizar num notebook:** o aviso de bateria no idioma da tela.
- **Os textos:** nenhum marcador `{0}` sobrando e nenhum texto do português na tela em inglês e em espanhol.

**Achados**

| # | Severidade | O que acontecia | Como ficou |
|---|---|---|---|
| Q1 | Média | Na revisão dos ajustes do Otimizar, num notebook, o aviso aparecia como "notebook: On a laptop, …" em inglês e "notebook: En un portátil, …" em espanhol: a palavra era escrita no código, fora da tradução. | O aviso vai como está, no idioma da tela. |
| Q2 | Média | Depois de exportar, a faixa dizia "Salvo em Documentos\WinForge" também em inglês e em espanhol. | "Documents\WinForge" e "Documentos\WinForge", pela tradução. |
| Q3 | Baixa | As faixas genéricas, o Explorador à toa, o aviso repetido do notebook, o ponto de restauração e o Recall (são o D1 ao D11, o M1 e o M2). | Corrigido. |

Cada conferência nova falha no código de antes e passa no de agora.

## Engenharia

**Por dentro**
- **Tweaks.psm1:**
  - `Invoke-WinForgeTweakBatch`: o ponto de restauração com `-IgnoreFrequency`, a frase de nenhum aplicado e as faixas de nenhum aplicado e do Explorador que não reinicia;
  - `Invoke-WinForgeTweakToggle`: as faixas de "nada mudou" (o valor que o Windows não manteve, o que continua, a falha legível e a configuração protegida) e do Explorador que não reinicia, que só é oferecido quando o ajuste mudou;
  - as faixas de `Invoke-WinForgeRecommendedTweaks`, `Invoke-WinForgeTweakProfile`, `Export-WinForgeTweaks`, `Import-WinForgeTweaks` e `Invoke-WinForgeRevertAllTweaks`;
  - `Format-WinForgeTweakExportFolder` (nova): a pasta Documentos no idioma da tela;
  - o aviso do notebook sem rótulo em `Read-WinForgeTweakSelection` e em `Get-WinForgeTweakReviewText`;
  - o Recall com `-MinBuild 26100` e a descrição nova do Alto desempenho.
- **WinForge.Gui.ps1:** o aviso do notebook na chave vai como está.
- **Traduções:** 17 novas e 3 que saíram de uso; 5.320 ao todo.

**Conferido na nuvem**
- **As conferências novas dos Ajustes do Windows, todas passando:** 412 em português e 422 em inglês e em espanhol.

  Cada conferência das correções falha no código de antes e passa no de agora.
- **As 84 ações rodaram de novo 336 vezes** com o Windows simulado: nenhum erro escapou, e o resultado é o mesmo da R22, fora as faixas novas.
- **As de antes continuam passando:**
  - as 144, 153 e 153 da Rede, as 106, 115 e 115 dos Programas, as 110, 117 e 117 das Atualizações, as 112, 119 e 119 do Reparo, as 96, 102 e 102 do Desempenho, as 178, 187 e 187 da Limpeza, as 134, 142 e 142 da Segurança e as 212, 224 e 224 do Diagnóstico;
  - as 245, 247 e 252 da Manutenção, com a revisão dos ajustes do Otimizar, e as 241 do Início nos três idiomas;
  - as 83 do QA geral, as 80 da R11 e as 60 da R12;
  - as 59 da R9 e as 52 da R10;
  - as 66 da QA, as 28 da integração e as 26 da R7;
  - o motor de instalação, a atualização simulada e o Setup de verdade (da R22 para esta), e o pacote de suporte;
  - as traduções (5.320/5.320), as 159 referências nos três idiomas e a busca dos 102 itens;
  - nenhuma chamada com parâmetro que não existe, nenhuma função sem uso e nenhum aviso novo do analisador.

## O que só um PC mostra

Isto entrou no roteiro de conferência:
- **Aplicar os recomendados num PC com um ponto de restauração do mesmo dia:** um ponto novo, "WinForge - antes dos ajustes", aparece na lista da Restauração do Sistema, e o limite de um por dia volta ao que era. É a mudança mais sensível desta revisão: antes, o ponto não era criado.
- **Uma chave que uma política impede** (num PC da empresa): a faixa "…: nada mudou", sem a pergunta do Explorador.
- **O Recall num Windows 11 23H2** (a chave não aparece) e num 24H2 Copilot+ (a chave aparece e desliga).
- **A chave do Alto desempenho num notebook:** o aviso de bateria uma vez só.
- **Exportar:** a faixa com "Documentos\WinForge" e a pasta aberta com o arquivo selecionado.

**Não visto, e por quê:**
- **O Recall na edição Home:** a Microsoft lista a política para as edições Pro, Enterprise e Education; num Home com o Recall, a chave pode mostrar "Desativado" sem que o Windows siga a política.
- **O Alto desempenho num notebook com Modern Standby:** o WinForge cria uma cópia do plano quando ele não está na lista; o que esse tipo de PC faz com ela só se vê nele.
- **O agendamento de GPU numa placa que não tem o recurso:** o Windows esconde a opção das Configurações, e a chave pode mostrar o valor gravado.
- **As políticas aparecendo como gerenciadas nas Configurações** (atualizações entre PCs, histórico de atividades, Recall, Game Bar): não há uma página da Microsoft que confirme isso para cada uma; por isso as descrições não foram mudadas.

## Fontes
- [Calling SRSetRestorePoint (Microsoft Learn)](https://learn.microsoft.com/en-us/windows/win32/sr/calling-srsetrestorepoint): o limite de um ponto a cada 24 horas e o valor `SystemRestorePointCreationFrequency` (0 = sem limite).
- [Policy CSP - WindowsAI (Microsoft Learn)](https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-windowsai): `DisableAIDataAnalysis` ("Turn off saving snapshots for use with Recall"), para o computador e para o usuário, do Windows 11 24H2 em diante, nas edições Pro, Enterprise e Education.
- [Delivery Optimization reference (Microsoft Learn)](https://learn.microsoft.com/en-us/windows/deployment/do/waas-delivery-optimization-reference): `DODownloadMode` 0 desliga o compartilhamento entre PCs; o 100 está obsoleto no Windows 11.
- [Powercfg command-line options (Microsoft Learn)](https://learn.microsoft.com/windows-hardware/design/device-experiences/powercfg-command-line-options): `/hibernate`, `/duplicatescheme`, `/setactive`, `/setacvalueindex` e `/setdcvalueindex`.
