# WinForge 4.0 — revisão do Sobre o WinForge (R25)

**Data:** 20/11/2026 · **Versão:** Build 4.0 em preparação, depois da R24

**Pedido:** juntar quatro olhares para a tela e a função Sobre o WinForge:
- **Analista de UX/UI Sênior (designer):** revisa cada detalhe da interface e orienta o engenheiro.
- **Especialista Microsoft (MVP Windows):** confere se os comandos e as alterações no Windows são feitos da melhor forma disponível hoje, de modo seguro e robusto, e se fazem sentido e mudam o que devem no PC.
- **QA Sênior:** testa todas as funções da tela.
- **Engenheiro de Software Sênior:** aplica as correções.

**Resultado:** 6 achados, todos corrigidos.

| Olhar | Achados |
|---|---|
| Designer | 5: Criar atalho em destaque mesmo com o atalho pronto, e no meio da página; "Instalado em" numa cópia que não está instalada; e as faixas genéricas de Criar atalho, de Verificar nova versão e das falhas das outras ações |
| MVP Windows | Nenhum: o atalho, o monitor, a verificação da versão e o pacote de suporte usam o que a Microsoft e o GitHub documentam. Cada um está conferido abaixo. |
| QA | 1: o pacote de suporte dizia levar os históricos mesmo sem nenhum, e contava logs que ficaram de fora do zip |
| Engenharia | Nenhum próprio: aplicou os 6. |

Nada rodou num Windows de verdade. O Windows foi simulado: o registro, as pastas e os arquivos do atalho, o instalador, a sessão, o GitHub e o monitor. O que só um PC mostra entrou no roteiro de conferência.

## O Sobre o WinForge hoje

A página fica no rodapé da barra lateral. De cima para baixo:
- **O resumo:**
  - a versão;
  - onde o atalho já existe (e se ele abre esta pasta);
  - se a cópia está instalada;
  - se a janela está como Administrador.

  Quando é o caso, entram também o ícone que falta, a conta de outro Administrador e as permissões da pasta.
- **Criar atalho do WinForge,** em destaque, quando falta o atalho (R25).
- **Aparência:** automática, clara ou escura, na hora.
- **Idioma:** automático, português, inglês ou espanhol, ao abrir de novo.
- **Versão e dados:**
  - Versão e pastas;
  - Verificar nova versão;
  - Conferir dados online;
  - Pasta de logs e relatórios;
  - Pacote de suporte.
- **Integração com o Windows:** Criar atalho do WinForge (quando o atalho já existe) e Monitor na bandeja.

O que cada ação faz no PC:
- **Versão e pastas:** só lê. Mostra a versão, a pasta, a instalação, o PowerShell, o Administrador, as pastas de dados e o atalho em cada lugar.
- **Verificar nova versão:** consulta a última versão publicada no GitHub. Se houver uma mais nova, pergunta antes de baixar o WinForge.zip para a pasta Downloads. Confere o tamanho e o SHA-256 publicado e oferece instalar com um clique: o WinForge fecha, troca os arquivos e abre de novo.
- **Conferir dados online:** baixa a lista de programas essenciais e as datas de suporte do Windows. Não envia nada do PC.
- **Pasta de logs e relatórios:** abre a pasta de dados do WinForge no Explorador.
- **Pacote de suporte:** junta num zip, na pasta Downloads, as versões, a verificação rápida do PC, os logs recentes, o último relatório, os históricos e as preferências. Não leva os backups (que podem ter senhas de Wi-Fi) nem arquivos pessoais.
- **Criar atalho do WinForge:** grava o atalho, com o ícone e o identificador da barra de tarefas, na Área de Trabalho e/ou no Menu Iniciar desta conta.
- **Monitor na bandeja:** liga (a entrada em Run do usuário), abre, desliga ou retoma os avisos do ícone perto do relógio.
- **Idioma** (pelo menu de texto; na janela, o cartão): guarda a escolha, que vale ao abrir de novo.

## Designer (UX/UI)

| # | O que estava | Orientação | Como ficou |
|---|---|---|---|
| D1 | Criar atalho ficava sempre em destaque, mesmo com o atalho pronto. E ficava no meio da página: depois da lista Versão e dados e antes do título Integração com o Windows, o grupo dele, sem nada que o ligasse ao resumo. | O destaque é o caminho recomendado: só aparece quando falta o atalho, logo abaixo do resumo que diz "ainda não criado". Com o atalho pronto, é uma linha do grupo dele. | Sem o atalho desta pasta, ou com um que abre outra pasta, Criar atalho vem em destaque logo abaixo do resumo, com o mesmo espaço dos cartões. Com o atalho pronto (desta conta ou do instalador), ele é a primeira linha de Integração com o Windows. Com a conta de outro Administrador, ou sem as pastas do atalho, criar não daria certo, e ele fica sem destaque. |
| D2 | Versão e pastas mostrava "Instalado em" com a pasta, também numa cópia só extraída, logo acima de "Instalação: sem instalar". A descrição do item dizia "onde está instalada". | O rótulo diz o que é a linha, sem contradizer a de baixo. | "Pasta do WinForge"; a descrição diz "A versão aberta, a pasta dela e onde ficam os logs". |
| D3 | Criar atalho terminava em faixas genéricas: "Não foi concluído: atalho não criado", "Concluído: o atalho do WinForge instalado já existe" ou "Concluído com ressalvas: 1 atalho criado, 1 com erro". | O título diz o que aconteceu; a frase, onde e por quê. | "O atalho não foi criado", com o motivo de cada lugar. "O atalho já existe", com onde está o do instalador. "Atalho criado só na Área de Trabalho", com o que impediu o outro lugar. Com o ícone ou o identificador da barra faltando, "Atalho criado", com onde e a ressalva. |
| D4 | Verificar nova versão tinha título só em quatro desfechos: em dia, mais nova que a publicada, instalando e baixada. Os outros 12 eram genéricos. No menu de texto, "veja abaixo como instalar" vinha depois das instruções. | Um título por desfecho, com a versão; a frase com o motivo ou o que fazer. | "Não foi possível consultar o GitHub" (com o motivo, ou "Tente de novo mais tarde."). "Versão 4.1 disponível" (sem o zip, com outra conta ou com o download recusado). "A versão 4.1 não foi baixada" (sem SHA-256, o arquivo diferente, a rede). "O arquivo baixado não é um pacote do WinForge", "Versão 4.1 baixada, mas não instalada", "O pacote baixado não é da versão anunciada" e "Não foi possível verificar a versão". O detalhe passou a "falta instalar". |
| D5 | As falhas das outras ações também eram genéricas: o pacote de suporte, o monitor, os dados online, o idioma e Versão e pastas sem o ícone. | O mesmo padrão: o título diz o que não aconteceu; a frase, o porquê, legível. | "O pacote de suporte não foi criado". "O monitor não foi ligado", "O monitor não foi desligado" e "O monitor não abriu". "Dados não atualizados". "O idioma não mudou". "O ícone do WinForge não foi encontrado", com "Os atalhos usam o ícone do PowerShell até você extrair a pasta inteira do WinForge de novo." |

**Conferido e mantido:**
- **o resumo do alto:** cada linha com o rótulo à esquerda, em atenção só o que pede ação (o atalho de outra pasta, o ícone, a falta de Administrador, outra conta, a pasta que outras contas alteram);
- **Aparência e Idioma como cartões:** a escolha vale na hora (aparência) ou ao abrir de novo (idioma, com a oferta de reabrir), e cada idioma aparece escrito nele mesmo;
- **um destaque só por página,** e as perguntas que mudam algo com o Sim de padrão só onde a pessoa pediu a ação (baixar, instalar, mostrar o arquivo);
- **as descrições** dos itens em até 70 letras, sem "software".

## Especialista Microsoft (MVP Windows)

Nenhuma mudança: cada mecanismo da página já é feito da forma que a Microsoft e o GitHub documentam.

| Ação | Como o WinForge faz | Veredito |
|---|---|---|
| Criar atalho | Um `.lnk` com o Windows PowerShell 5.1 abrindo o `WinForge.Gui.ps1` (oculto, em STA), a pasta do WinForge como pasta de trabalho e o ícone `assets\WinForge.ico`. O atalho leva o identificador `WinForge.App` em `System.AppUserModel.ID`, o mesmo que a janela põe no processo e nela mesma. | Certo. A Microsoft diz que o identificador vai no atalho, por `IPropertyStore`, e que o mesmo deve ir nos processos, nas janelas e nos atalhos. Isso faz o "Fixar na barra de tarefas" abrir o WinForge com o ícone dele. O formato também é o pedido: até 128 letras, sem espaços. |
| Atalho do instalador | Instalado, o WinForge tem os atalhos para todos os usuários: Criar atalho não grava outro igual no mesmo lugar e tira o repetido desta conta. | Certo: evita dois ícones iguais no Menu Iniciar e na Área de Trabalho. |
| Monitor na bandeja | Uma entrada em `HKCU\...\CurrentVersion\Run`, do usuário. O WinForge recusa ligar quando a linha teria 260 letras ou mais. Ao religar, tira a marca de desativado da aba Inicializar (`StartupApproved\Run`). Da janela elevada, o monitor abre pelo Explorador, sem a elevação. | Certo. A Microsoft documenta que a entrada em Run do usuário roda a cada entrada dele no Windows, e o limite de 260 letras da linha. Diz também que o Windows pode atrasar essa entrada, e por isso a faixa diz "em instantes ou na próxima entrada no Windows". |
| Verificar nova versão | `GET /repos/.../releases/latest` com TLS 1.2. O WinForge.zip só é baixado com o SHA-256 que o GitHub publica (`digest`, "sha256:…"); o tamanho também é conferido. Um arquivo diferente é apagado, e o parcial nunca fica na pasta. | Certo. O GitHub documenta que a última versão é a mais recente que não é rascunho nem pré-lançamento. Documenta também que cada arquivo enviado a uma versão ganha o SHA-256 calculado no envio, que não muda depois. Sem o hash publicado, o WinForge não baixa, em vez de instalar algo sem conferir. |
| Pacote de suporte | Um zip na pasta Downloads (com a conta de outro Administrador, na pasta de dados do WinForge). Os logs são lidos com o compartilhamento total (o da janela aberta continua sendo gravado). | Certo: não leva backups nem senhas, e a tela diz que os logs têm o nome do PC e caminhos de pastas. |
| Pasta de logs | O Explorador abre a pasta de dados do WinForge. | Certo. |

**Conferido e mantido**
- **Com a conta de outro Administrador,** o atalho, o download e o monitor iriam para o perfil dessa conta: a tela não faz e diz como abrir o WinForge sem Administrador.
- **A instalação com um clique** só é oferecida quando o pacote baixado diz a mesma versão da página, e nunca com outra janela do WinForge aberta.

## QA Sênior

**Como foi testado:** cada função da página rodou com o Windows simulado, nos três idiomas: 164 conferências em português e 169 em inglês e em espanhol. As 5 a mais conferem, em cada seção, que nenhum texto do português aparece na tela.
- **A página:**
  - os 8 itens na ordem, com um só destaque, o Idioma fora dos cartões e o comando ou atalho de cada um existindo;
  - o resumo do alto em 12 situações: sem atalho, com o atalho, com um de outra pasta, com os do instalador, sem o ícone, com um ícone estragado, sem Administrador, com outra conta, com a pasta alterável por outras contas, sem as pastas do atalho e com um atalho ou o do instalador que não pôde ser lido;
  - quando Criar atalho fica em destaque, nas mesmas situações;
  - o desenho da página na janela, com e sem o atalho, e o de outra página, que segue igual.
- **Versão e pastas:** a pasta, a instalação, o PowerShell, o Administrador, as pastas de dados e o atalho em cada lugar; sem faixa quando está tudo certo, e a faixa do ícone que falta.
- **Criar atalho (24 situações):**
  - o atalho gravado: o PowerShell, os argumentos, a pasta de trabalho, o ícone, a descrição e o identificador;
  - a pergunta de onde, os dois lugares, de novo (atualizado), um novo e um que já existia, cancelar, uma resposta fora da lista, `-Location` e um lugar só;
  - sem as pastas, sem o `WinForge.Gui.ps1`, com outra conta e o lugar pedido que o Windows não informou;
  - os atalhos do instalador, nos dois lugares e num só;
  - um lugar que recusa, os dois que recusam, a gravação bloqueada sem erro e a pasta que não existe;
  - sem o ícone, sem o identificador, com outras contas na pasta e o atalho de outra pasta.
- **Verificar nova versão (21 situações):**
  - em dia e mais nova que a publicada;
  - sem internet, o GitHub sem responder e uma resposta que não se entende;
  - as notas da versão sem Markdown, sem o zip, com outra conta e o download recusado;
  - sem SHA-256, um hash que não é SHA-256, o arquivo diferente (apagado), o download que não termina e o arquivo incompleto;
  - um zip que não é do WinForge;
  - instalar agora, instalar depois (com o arquivo mostrado na pasta), já baixada (sem baixar de novo), outra janela aberta, a instalação que não começa, o pacote de outra versão e um erro inesperado.
- **Conferir dados online:** atualizados, em dia, sem internet e um erro inesperado.
- **Pacote de suporte (6 situações), com um zip de verdade:**
  - o que entra: as versões, a verificação, os 10 logs mais novos e a abertura, os 2 arquivos do último relatório, os históricos e as preferências;
  - os backups ficam de fora, e o `info.txt` está em inglês;
  - sem logs nem históricos; logs em uso; a verificação que falha; com outra conta;
  - a pasta Downloads que não pode ser criada;
  - a pasta temporária sempre sai.
- **Monitor na bandeja (17 situações):**
  - ligar: a entrada em Run, o ícone que demora e o Windows que não deixa abrir;
  - desligar: com o ícone fechando e sem fechar;
  - desativado na aba Inicializar (a marca 03, e a 02 contando como ligado), abrir agora e o ícone que não aparece;
  - ligado de outra pasta, com outra conta, ligar direto pelo Início, os avisos pausados e voltar;
  - sem o `WinForge.Agent.ps1`, a pasta com caminho longo, o Run recusado ao ligar e ao desligar.
- **Idioma:** English, o mesmo, voltar e a escolha que não foi guardada.
- **A pasta de logs:** o Explorador na pasta de dados.
- **Os textos:** nenhum marcador `{0}` sobrando e nenhum texto do português na tela em inglês e em espanhol.

**Achado**

| # | O que estava | Como ficou |
|---|---|---|
| Q1 | A linha "Leva" do pacote de suporte dizia "históricos" sempre, mesmo sem nenhum histórico copiado. E contava os logs encontrados, não os copiados: um log em uso por outro programa ficava fora do zip e entrava na conta. | A linha conta só o que entrou no zip: os logs copiados, o relatório se algum arquivo dele entrou, "históricos" com o das mudanças ou o das manutenções, e "preferências" com as da janela ou as do monitor. |

As 53 conferências das correções falham no código de antes e passam no de agora.

## Engenharia

**Por dentro**
- **Launcher.psm1:**
  - `Test-WinForgeAppShortcutNeeded` (nova): se Criar atalho fica em destaque;
  - `Show-WinForgeAbout`: "Pasta do WinForge" e a faixa do ícone que falta;
  - as faixas de `New-WinForgeAppShortcut` e de `New-WinForgeShortcutFiles`, com o motivo de cada lugar que falhou;
  - a faixa do idioma que não foi guardado.
- **WinForge.Gui.ps1:** `Show-GuiListPage` decide o destaque do Sobre o WinForge antes dos cartões e o tira da lista.
- **AppUpdate.psm1:** as faixas de `Invoke-WinForgeUpdateFlow` e de `Invoke-WinForgeUpdateCheck`, e o detalhe "falta instalar".
- **Reports.psm1:** a linha "Leva" do pacote de suporte e a faixa da falha.
- **Agent.psm1, Catalog.psm1:** as faixas das falhas do monitor e dos dados online.
- **Console.psm1:** `Format-WinForgeReasonNote` (nova): o motivo de uma falha como a frase da faixa.
- **Navigation.psm1:** a descrição de Versão e pastas.
- **Traduções:** 27 novas e 4 que saíram de uso; 5.346 ao todo.

**Conferido na nuvem**
- **As conferências novas do Sobre o WinForge, todas passando:** 164 em português e 169 em inglês e em espanhol.

  Cada conferência das correções falha no código de antes e passa no de agora.
- **As 84 ações rodaram de novo 336 vezes** com o Windows simulado: nenhum erro escapou. O resultado é o mesmo da R24, fora as faixas novas de Verificar nova versão, de Criar atalho e do monitor nos casos que falham.
- **As de antes continuam passando:**
  - as 265, 270 e 270 da Personalização, as 412, 422 e 422 dos Ajustes do Windows, as 144, 153 e 153 da Rede, as 106, 115 e 115 dos Programas, as 110, 117 e 117 das Atualizações, as 112, 119 e 119 do Reparo, as 96, 102 e 102 do Desempenho, as 178, 187 e 187 da Limpeza, as 134, 142 e 142 da Segurança e as 212, 224 e 224 do Diagnóstico;
  - as 245, 247 e 252 da Manutenção e as 241 do Início nos três idiomas;
  - as 83 do QA geral, as 80 da R11 e as 60 da R12;
  - as 59 da R9 e as 52 da R10;
  - as 66 da QA, as 28 da integração e as 26 da R7;
  - o motor de instalação, a atualização simulada e o Setup de verdade (da R24 para esta), e o pacote de suporte, que agora diz só o que entrou no zip;
  - as traduções (5.346/5.346), as 159 referências nos três idiomas e a busca dos 102 itens;
  - nenhuma chamada com parâmetro que não existe, nenhuma função sem uso e nenhum aviso novo do analisador.

## O que só um PC mostra

Isto entrou no roteiro de conferência:
- **O destaque de Criar atalho:** sem o atalho, ele vem logo abaixo do resumo. Depois de criar e voltar, ele vira uma linha de Integração com o Windows.
- **Versão e pastas:** "Pasta do WinForge" com a pasta de onde o WinForge abriu, e a linha Instalação.
- **Criar atalho numa cópia instalada:** "O atalho já existe", sem um segundo atalho no mesmo lugar.
- **Verificar nova versão sem internet:** "Não foi possível consultar o GitHub", com o motivo.
- **O pacote de suporte:** a linha Leva e o que há dentro do zip.

## Fontes
- [Run and RunOnce Registry Keys](https://learn.microsoft.com/windows/win32/setupapi/run-and-runonce-registry-keys) (Microsoft): a entrada em Run roda a cada entrada do usuário, com até 260 letras, e o Windows pode atrasá-la.
- [Application User Model IDs](https://learn.microsoft.com/windows/win32/shell/appids) (Microsoft): o identificador no atalho por `IPropertyStore`, o mesmo nos processos, nas janelas e nos atalhos, e o formato.
- [Releases — Get the latest release](https://docs.github.com/ru/rest/releases/releases) (GitHub): a mais recente que não é rascunho nem pré-lançamento.
- [Release assets](https://docs.github.com/ru/rest/releases/assets) (GitHub): o campo `digest` do arquivo, no formato "sha256:…".
- [Releases now expose digests for release assets](https://github.blog/changelog/2025-06-03-releases-now-expose-digests-for-release-assets/) (GitHub): o SHA-256 calculado no envio de cada arquivo, imutável.
