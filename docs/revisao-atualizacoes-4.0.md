# WinForge 4.0 — revisão das Atualizações (R20)

**Data:** 19/11/2026 · **Versão:** Build 4.0 em preparação, depois da R19

**Pedido:** juntar quatro olhares para a tela e a função de Atualizações:
- **Analista de UX/UI Sênior (designer):** revisa cada detalhe da interface e orienta o engenheiro.
- **Especialista Microsoft (MVP Windows):** confere se os comandos e as alterações no Windows são feitos da melhor forma disponível hoje, de modo seguro e robusto, e se fazem sentido e mudam o que devem no PC.
- **QA Sênior:** testa todas as funções da tela.
- **Engenheiro de Software Sênior:** aplica as correções.

**Resultado:** 13 achados, todos corrigidos.

| Olhar | Achados |
|---|---|
| Designer | 8: as faixas genéricas do tempo esgotado, das falhas das ferramentas do fabricante, das falhas do Corrigir o Windows Update e da recusa da Microsoft Store; a falta de espaço sem o botão para liberar espaço; a ferramenta instalada sem dizer como abrir; e o nome dos serviços com "serviço" repetido ("o serviço Serviço de Transferência...") |
| MVP Windows | 3: a versão nova do Windows vinha marcada na lista; a Microsoft Store recebia, sem o modo Administrador, um pedido que a Microsoft documenta só para um prompt elevado; e as páginas da HP e do NVIDIA App abriam em português em qualquer idioma |
| QA | 2 próprios: o título de Atualizar drivers em português nas telas em inglês e em espanhol, e a frase de abrir a página de um fabricante quebrada em inglês ("Opening Open the NVIDIA App page"). Os testes também acharam todos os outros. |
| Engenharia | Nenhum próprio: aplicou os 13. |

Nada rodou num Windows de verdade. O Windows (o Windows Update, os serviços e as pastas do cache, o winget, a Microsoft Store, o hardware e o navegador) foi simulado. O que só um PC mostra entrou no roteiro de conferência.

## As Atualizações hoje

A página tem, de cima para baixo:
1. **Windows e drivers:**
   - Instalar atualizações do Windows, em destaque ("Procurar atualizações");
   - Atualizar drivers;
   - Ferramentas do fabricante;
   - Corrigir o Windows Update.
2. **Programas e aplicativos:**
   - Atualizar programas (winget);
   - Atualizar aplicativos da Microsoft Store.
3. **Ferramentas do Windows:**
   - Windows Update e Atualizações opcionais, que abrem as páginas das Configurações.

Instalar atualizações, Atualizar drivers e Corrigir o Windows Update pedem Administrador e mostram o escudo.

O que cada ação muda:
- **Instalar atualizações e Atualizar drivers:** baixam e instalam, pelo próprio Windows Update, só o que a pessoa marcou. Antes de um driver, o WinForge cria um ponto de restauração.
- **Ferramentas do fabricante:** só indicam. Mudam algo só se a pessoa pedir: instalam a ferramenta pelo winget ou abrem a página oficial.
- **Corrigir o Windows Update:** volta ao padrão os serviços desativados, refaz o cache do Windows Update e liga os serviços de novo.
- **Programas (winget) e Microsoft Store:** atualizam os programas e os aplicativos que a pessoa escolheu, ou pedem à Store que procure.

## Designer (UX/UI)

| # | O que estava | Orientação | Como ficou |
|---|---|---|---|
| D1 | Quando o WinForge parava de acompanhar uma instalação longa, a faixa dizia "Concluído com ressalvas", nas atualizações e nos drivers. Os drivers tinham ainda uma frase um pouco diferente. | A faixa diz o que houve e onde acompanhar. | "O WinForge parou de acompanhar", com "O Windows pode continuar instalando" e o botão "Ver o andamento", que abre o Windows Update. A mesma frase nos dois. |
| D2 | Uma atualização que falhava por falta de espaço no disco dava a faixa sem botão. | Levar a quem resolve. | O botão "Liberar espaço", que abre a Limpeza personalizada, como no Início. |
| D3 | Instalar uma ferramenta do fabricante pelo winget terminava em "Concluído". | Dizer o próximo passo. | "Dell Command \| Update está instalado", com "Abra-o pelo menu Iniciar e siga as instruções dele." |
| D4 | Sem o navegador ou sem a Store, a faixa dizia "Não foi concluído", e o detalhe trazia o nome com maiúscula no meio da frase ("o endereço de Site de drivers da HP"). | A faixa diz o que não abriu e o que fazer. | "O navegador não abriu", com "Copie o endereço que está no resumo"; "A Microsoft Store não abriu", com o que procurar nela. |
| D5 | Com o Windows sem responder sobre o hardware, a faixa dizia "Concluído com ressalvas". | Idem. | "A indicação pode estar incompleta", com o que não foi lido. |
| D6 | No Corrigir o Windows Update, o nome de dois serviços já trazia a palavra "Serviço": "o serviço Serviço de Transferência Inteligente...", nos três idiomas, também no resumo. E "Reinicie o PC para o Windows ligá-los" valia mesmo para um serviço só. | Um nome que caiba depois de "o serviço"; singular e plural. | "Transferência Inteligente de Plano de Fundo (BITS)" e "Criptografia (CryptSvc)"; "ligá-lo" para um, "ligá-los" para mais. |
| D7 | No Corrigir o Windows Update, as faixas diziam só "Não foi concluído" ou "Concluído com ressalvas" com um serviço removido, com os serviços sem responder, com um serviço que continua desativado, com um serviço que não parou, com um que não ligou de novo e com o cache refeito em parte. | Cada faixa diz o que houve e, quando há, o botão. | "Falta um serviço do Windows Update" (botão "Abrir a Recuperação"); "Os serviços do Windows Update não responderam" (botão "Reparar o Windows"); "Um serviço do Windows Update continua desativado"; "O Windows Update não foi corrigido"; "Reinicie para terminar a correção"; "O cache foi refeito só em parte". |
| D8 | A Store que recusava o pedido dava "Concluído com ressalvas". | Idem. | "A Microsoft Store não aceitou o pedido", com "Na página da Store que abriu, clique em Obter atualizações." |

**Conferido e mantido:**
- um destaque só na página, Instalar atualizações do Windows, e as descrições em até 60 letras nos três idiomas;
- o escudo nas três ações que pedem Administrador;
- as perguntas começam no lugar seguro:
  - continuar com um reinício pendente e instalar na bateria, no Não;
  - instalar o que a pessoa marcou, no Sim;
  - drivers com um firmware (BIOS) na escolha, no Não;
  - corrigir com um reinício pendente, no Não, e sem ele, no Sim;
  - nas ferramentas do fabricante, "Concluir";
- a lista de atualizações traz o KB, o tamanho ("até", "já baixada") e as opcionais desmarcadas; a de drivers diz para que serve cada um ("vídeo: Intel UHD Graphics 620");
- a confirmação diz quanto vai ser baixado e avisa da conexão limitada e do firmware;
- o PC fica acordado durante a instalação;
- o reinício é oferecido quando a instalação pede.

## Especialista Microsoft (MVP Windows)

**O que mudou**

| # | O que estava | Por que não é o melhor | Como ficou |
|---|---|---|---|
| M1 | Uma versão nova do Windows (a classificação Upgrades do Windows Update) vinha marcada na lista quando o Windows Update a oferecia como comum. | Mudar a versão do Windows é uma decisão à parte das atualizações do mês, e o Otimizar já a deixava de fora. Marcada, um Enter a mais começava a mudança de versão. | Desmarcada, com "versão nova do Windows" na linha e a frase "A versão nova do Windows vem desmarcada: marque-a só se quiser mudar de versão agora." |
| M2 | Sem o modo Administrador, Atualizar aplicativos da Microsoft Store pedia a busca à ponte de gerenciamento do Windows mesmo assim. | A Microsoft documenta essa ponte só num prompt elevado de Administrador. Sem ele, a tela fazia o pedido mesmo assim e, na recusa, mostrava um aviso. | Sem o modo Administrador, o pedido nem é feito: a página de atualizações da Store abre direto, com "Clique em Obter atualizações". Com Administrador, nada mudou. |
| M3 | O site de drivers da HP abria sempre em `support.hp.com/br-pt`, e a página do NVIDIA App sempre em `pt-br`, também para quem usa o WinForge em inglês ou em espanhol. | A página vinha em português para quem não lê português. | A da HP abre em `support.hp.com/drivers`, que escolhe o país e o idioma sozinha. A do NVIDIA App abre no idioma da tela: `pt-br`, `en-us` ou `es-la`. |

**Cada comando, conferido**

| Função | Como o WinForge faz | Veredito |
|---|---|---|
| Instalar atualizações do Windows | A API do próprio Windows Update (`Microsoft.Update.Session`), noutro runspace, para a tela acompanhar e o Parar funcionar. A busca é `IsInstalled=0 and IsHidden=0 and BrowseOnly=0`; só um Windows que não conhece o `BrowseOnly` (0x80240032) busca sem ele. Antes: o reinício pendente e a bateria, com a pergunta no Não. Depois: os códigos conhecidos viram uma frase, com o botão para o item que resolve. | Certo, com o M1, o D1 e o D2. |
| Atualizar drivers | A mesma API, com `Type='Driver'`. Os opcionais vêm desmarcados. Um ponto de restauração é criado antes, e a tela diz como voltar ao driver anterior. | Certo, com o D1 e o Q1. |
| Ferramentas do fabricante | O fabricante, o modelo e a placa de vídeo vêm do WMI, com até 15 segundos. A Dell e a Lenovo têm duas ferramentas cada (Dell Command \| Update e SupportAssist; Lenovo System Update e Vantage), e a tela indica a da linha certa do PC. A ferramenta é instalada pelo winget ou aberta pela página oficial, pelo Explorador, para o navegador não herdar o Administrador. | Certo, com o M3, o D3 ao D5 e o Q2. |
| Corrigir o Windows Update | Para o BITS, o Windows Update e os Serviços de Criptografia. Põe de lado `SoftwareDistribution\DataStore`, `SoftwareDistribution\Download` e `System32\catroot2`, em `.bak`, e liga os serviços de novo. São os passos que a Microsoft dá para refazer os componentes do Windows Update. Antes de tudo, os serviços desativados voltam ao padrão. Se algum não voltar, nada mais é feito. Uma pasta que aponta para outro disco fica como está. | Certo, com o D6 e o D7. |
| Atualizar programas (winget) | `winget upgrade --accept-source-agreements` para a lista. Depois, um a um, `winget upgrade --id <id> -e --silent --accept-package-agreements --disable-interactivity`, com o Instalador de Aplicativo por último. | Certo. |
| Atualizar aplicativos da Microsoft Store | O método `UpdateScanMethod` da classe `MDM_EnterpriseModernAppManagement_AppManagement01`, o mesmo pedido do botão "Obter atualizações". Se o Windows recusar, a página da Store abre. | Certo, com o M2 e o D8. |
| Windows Update e Atualizações opcionais | `ms-settings:windowsupdate` e `ms-settings:windowsupdate-optionalupdates`. | Certo. |

**Conferido e mantido**
- **O Corrigir o Windows Update sem os passos que a Microsoft deixa para o fim ou que mexem em outras coisas.** A página da Microsoft lista mais passos, e o WinForge não faz estes de propósito:
  - não apaga a fila do BITS, que tem também os downloads de outros programas;
  - não roda o `sc.exe sdset` nos serviços, que a Microsoft manda pular porque troca as permissões;
  - não registra DLLs de novo com o `regsvr32`;
  - não roda o `netsh winsock reset`, que mexe na rede do PC inteiro.
- **O DataStore e o catroot2 guardados em `.bak`;** os downloads saem só depois que os serviços já estão ligados de novo, porque são só cache.
- **As políticas não mudam.** Com um bloqueio por política ou um servidor da empresa (WSUS), a tela só diz isso e para quem falar.
- **O Windows Update Medic (WaaSMedicSvc) não é mexido.** O Windows o protege; a tela diz quando ele está desativado.
- **Os drivers pelo Windows Update primeiro.** As ferramentas dos fabricantes ficam para o vídeo e a BIOS, que costumam ter versões mais novas nelas.
- **O Dell Command \| Update pelo winget (`Dell.CommandUpdate`).** A Dell publica a versão clássica e a Universal; o WinForge instala a clássica.

## QA Sênior

**Como foi testado:** cada função da página rodou com o Windows simulado, nos três idiomas: 110 conferências em português e 117 em inglês e em espanhol. As 7 a mais conferem, em cada seção, que nenhum texto do português aparece na tela.
- **Instalar atualizações do Windows (16 situações):**
  - sem Administrador, com o reinício pendente e na bateria;
  - a busca que falha (com o botão para o Corrigir) e com o servidor da empresa;
  - em dia e em dia num Windows sem suporte;
  - a lista com opcionais e uma versão nova do Windows; cancelar; o Não na confirmação;
  - instaladas, com reinício, em parte (falta de espaço), todas falhando com um erro de cache, recusada antes de começar e o tempo esgotado;
  - a conexão limitada.
- **Atualizar drivers (6):** nenhum novo, a lista com recomendado e opcional, o firmware (no Não), instalado com o ponto de restauração, em parte e o tempo esgotado.
- **Ferramentas do fabricante (7):** Dell Latitude (só olhar e instalar pelo winget), Lenovo IdeaPad com NVIDIA, HP sem navegador, Lenovo sem a Store abrir, fabricante desconhecido e o Windows sem responder.
- **Corrigir o Windows Update (12):**
  - sem Administrador, com o Windows Update instalando, com um serviço removido e com um sem responder;
  - cancelar e com o reinício pendente;
  - completo, com um serviço desativado voltando ao padrão;
  - um serviço que não sai de desativado, um que não para e um que não liga de novo;
  - uma pasta que aponta para outro lugar (o outro lado fica intacto);
  - a política e o Medic desativado.
- **Atualizar programas (5):** sem o winget, em dia, todos, Não e escolher.
- **Microsoft Store (5):** o pedido aceito, recusado, no Otimizar, sem Administrador e sem Administrador com a Store sem abrir.
- **A página (20):** cada item existe e tem até 60 letras, o escudo nas três ações, um destaque só e os dois atalhos do Windows.
- **Os textos:** nenhum marcador `{0}` sobrando, nenhum "serviço" repetido e nenhum texto do português na tela em inglês e em espanhol.

**Achados**

| # | Severidade | O que acontecia | Como ficou |
|---|---|---|---|
| Q1 | Média | Em inglês e em espanhol, o título de Atualizar drivers aparecia em português ("Atualizar drivers"), na tela e no resumo. | Traduzido, como o nome do item. |
| Q2 | Média | Em inglês, abrir a página de um fabricante dizia "Opening Open the NVIDIA App page in the browser.": a frase tirava o "Abrir " do rótulo do botão, e isso só funcionava em português e em espanhol. | Cada ferramenta tem no catálogo o que abre, já traduzido: "Opening the NVIDIA App page in the browser." |
| Q3 | Baixa | As faixas genéricas, a versão nova do Windows marcada, o pedido da Store sem Administrador e as páginas em português (são o D1 ao D8 e o M1 ao M3). | Corrigido. |

Cada conferência nova falha no código de antes e passa no de agora.

## Engenharia

**Por dentro**
- **WindowsUpdate.psm1:**
  - a lista com a versão nova do Windows desmarcada e dita;
  - `Set-WinForgeUpdateTimeoutView` (nova): a faixa do tempo esgotado, nas atualizações e nos drivers;
  - `Get-WinForgeUpdateFixStep`: a falta de espaço leva a Liberar espaço;
  - os nomes dos serviços e as faixas do Corrigir o Windows Update.
- **Drivers.psm1:**
  - o título traduzido e a mesma frase do tempo esgotado;
  - o catálogo com o que cada página abre (`Target`), a página da HP sem país fixo e a do NVIDIA App no idioma da tela;
  - as faixas da ferramenta instalada, do navegador e da Store sem abrir e do Windows sem responder.
- **Software.psm1:** a Microsoft Store sem o modo Administrador abre a página direto; a faixa da recusa.
- **Traduções:** 38 novas e 4 que saíram de uso; 5.244 ao todo.

**Conferido na nuvem**
- **As conferências das Atualizações:** 110, 117 e 117, todas passando.
- **As 84 ações rodaram de novo 336 vezes** com o Windows simulado: nenhum erro escapou, e o resultado é o mesmo da R19.
- **As de antes continuam passando:**
  - as 112, 119 e 119 do Reparo, as 96, 102 e 102 do Desempenho, as 178, 187 e 187 da Limpeza, as 134, 142 e 142 da Segurança e as 212, 224 e 224 do Diagnóstico;
  - as 245, 247 e 252 da Manutenção, com o Windows Update e a Store do Otimizar, e as 241 do Início nos três idiomas. A conferência antiga da Store recusada, pedida sozinha, passou a rodar com Administrador: a recusa só acontece com ele, porque sem ele a tela agora nem faz o pedido;
  - as 83 do QA geral, as 80 da R11 e as 60 da R12;
  - as 59 da R9 e as 52 da R10;
  - as 66 da QA, as 28 da integração e as 26 da R7;
  - o motor de instalação, a atualização simulada e o Setup de verdade (da R19 para esta), e o pacote de suporte;
  - as traduções (5.244/5.244), as 159 referências nos três idiomas e a busca dos 102 itens. São 159, e não 160, porque a frase do tempo esgotado dos drivers agora é a mesma das atualizações;
  - nenhuma chamada com parâmetro que não existe, nenhuma função sem uso e nenhum aviso novo do analisador.

## O que só um PC mostra

Isto entrou no roteiro de conferência:
- **Atualizar aplicativos da Microsoft Store com o WinForge aberto sem o modo Administrador:** a página de atualizações da Store abre direto, sem aviso de recusa, e a faixa diz "Clique em Obter atualizações". Com Administrador, o pedido vai como antes. É a mudança mais sensível desta revisão.
- **Instalar atualizações do Windows num PC com uma versão nova do Windows oferecida**, se houver um à mão: ela aparece desmarcada, com "versão nova do Windows".
- **Ferramentas do fabricante num PC da HP ou com placa NVIDIA**, com o WinForge em inglês: a página abre no idioma certo.
- **Corrigir o Windows Update** num PC sem problema: a faixa diz "Cache do Windows Update refeito", e a busca seguinte acha as atualizações. Com um serviço desativado, se houver um PC assim, o resumo diz o nome dele sem "serviço" repetido.

## Fontes
- [Windows Update - additional resources (Microsoft Learn)](https://learn.microsoft.com/windows/deployment/update/windows-update-resources): os passos para refazer os componentes do Windows Update (parar o BITS, o Windows Update e os Serviços de Criptografia; pôr de lado o DataStore, o Download e o catroot2 em `.bak`; ligar de novo), com o `sc.exe sdset` para pular, salvo se o resto não resolver, porque troca as permissões dos serviços.
- [MDM_EnterpriseModernAppManagement_AppManagement01 class (Microsoft Learn)](https://learn.microsoft.com/en-us/windows/win32/dmwmibridgeprov/mdm-enterprisemodernappmanagement-appmanagement01): o método `UpdateScanMethod`.
- [Using PowerShell scripting with the WMI Bridge Provider (Microsoft Learn)](https://learn.microsoft.com/en-us/windows/client-management/mdm/using-powershell-scripting-with-the-wmi-bridge-provider): os comandos da ponte num prompt elevado de Administrador.
- [Dell Command | Update (Dell)](https://www.dell.com/support/kbdoc/en-us/000177325): a versão Universal e a clássica, para os PCs de empresa da Dell.
- [Software and Drivers (HP)](https://support.hp.com/drivers): a página de drivers da HP, sem país fixo no endereço.
- [NVIDIA App (NVIDIA)](https://www.nvidia.com/es-la/software/nvidia-app/): a página do NVIDIA App, com o idioma no endereço.
