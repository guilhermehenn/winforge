# WinForge 4.0 — revisão dos Programas (R21)

**Data:** 19/11/2026 · **Versão:** Build 4.0 em preparação, depois da R20

**Pedido:** juntar quatro olhares para a tela e a função de Programas:
- **Analista de UX/UI Sênior (designer):** revisa cada detalhe da interface e orienta o engenheiro.
- **Especialista Microsoft (MVP Windows):** confere se os comandos e as alterações no Windows são feitos da melhor forma disponível hoje, de modo seguro e robusto, e se fazem sentido e mudam o que devem no PC.
- **QA Sênior:** testa todas as funções da tela.
- **Engenheiro de Software Sênior:** aplica as correções.

**Resultado:** 14 achados, todos corrigidos.

| Olhar | Achados |
|---|---|
| Designer | 10: as faixas genéricas quando nada foi instalado, desinstalado, removido, ligado ou salvo, quando falta o winget, quando a busca não acha nada e quando o backup ou a restauração terminam com ressalvas (o backup sem dizer onde ficou); o reinício que os recursos pedem e não era oferecido; o backup mais novo sem destaque na restauração; e duas frases em inglês fora de ordem |
| MVP Windows | 3: o antigo aplicativo do Office com um nome que o Windows não mostra mais; o Windows Sandbox sem a edição Education; e a restauração dos programas sem pedir a versão atual de cada um |
| QA | 1 próprio: a pergunta de ligar ou desligar um recurso só saía em português ("Ligar Hyper-V?") nas telas em inglês e em espanhol. Os testes também acharam todos os outros. |
| Engenharia | Nenhum próprio: aplicou os 14. |

Nada rodou num Windows de verdade. O Windows (o winget, os aplicativos, os recursos opcionais, os drivers, o Wi-Fi e as pastas do backup) foi simulado. O que só um PC mostra entrou no roteiro de conferência.

## Os Programas hoje

A página tem, de cima para baixo:
1. **Instalar e remover:**
   - Instalar programas essenciais, em destaque ("Escolher programas");
   - Buscar e instalar programas;
   - Listar programas instalados;
   - Desinstalar programas;
   - Remover aplicativos do Windows.
2. **Inicialização e recursos:**
   - Gerenciar inicialização (a mesma tela do Desempenho, revista na R18);
   - Recursos opcionais do Windows.
3. **Backup e formatação:**
   - Backup antes de formatar;
   - Restaurar a partir de um backup.
4. **Ferramentas do Windows:**
   - Aplicativos instalados, Programas e Recursos e Aplicativos de inicialização, que abrem as telas do Windows.

Recursos opcionais, Backup e Restaurar pedem Administrador e mostram o escudo.

O que cada ação muda:
- **Instalar, buscar e desinstalar:** instalam ou removem, pelo winget, só o que a pessoa marcou, um por vez. Um programa só conta como desinstalado quando sai da lista do winget.
- **Listar:** só lê.
- **Remover aplicativos do Windows:** remove, para a conta de quem usa, só os aplicativos marcados de uma lista curta. Os que a Microsoft aposentou não voltam, e a tela diz isso antes.
- **Recursos opcionais:** ligam ou desligam os recursos marcados, e o Histórico de mudanças guarda o desfazer de cada um.
- **Backup:** só lê o PC e grava na pasta escolhida.
- **Restaurar:** reinstala os programas, instala os drivers, reaplica os ajustes e recria as redes Wi-Fi que a pessoa marcar.

## Designer (UX/UI)

| # | O que estava | Orientação | Como ficou |
|---|---|---|---|
| D1 | Instalar ou desinstalar um programa que não dava certo terminava em "Não foi concluído", nos essenciais, na busca e no desinstalar. | A faixa diz o que não aconteceu e por quê. | "O programa não foi instalado" (ou desinstalado), com o nome e o motivo ("VLC Media Player: não foi possível baixar o instalador; confira a internet"). Com vários, "Nenhum programa foi instalado", e o motivo de cada um fica no resumo. |
| D2 | Sem o winget, as quatro telas de Programas, Atualizar programas e as Ferramentas do fabricante terminavam em "Não foi concluído". | Idem. | "Falta o Instalador de Aplicativo", com "Num Windows recém-instalado, ele chega quando a Microsoft Store se atualiza." |
| D3 | A busca sem resultado terminava em "Nada a fazer"; a busca que falhava, em "Não foi concluído". | Idem. | "Nenhum programa encontrado", com o que tentar; "A busca não funcionou", com o motivo. |
| D4 | Remover aplicativos sem conseguir remover nenhum dava "Não foi concluído". | Idem. | "O aplicativo não foi removido" (ou "Nenhum aplicativo foi removido"), com o motivo. |
| D5 | Os recursos opcionais sem conseguir mudar nenhum davam "Não foi concluído". | Idem. | "O recurso não mudou" (ou "Nenhum recurso mudou"), com o motivo. |
| D6 | Um recurso que só termina ao reiniciar dizia "Reinicie o PC", sem oferecer o reinício. | Fazer como as Atualizações. | O reinício é oferecido ali mesmo, com Não como padrão. |
| D7 | O backup com ressalvas terminava em "Concluído com ressalvas: problemas em …", sem dizer onde a pasta ficou, justo o que a pessoa precisa antes de formatar. Sem nada salvo, "Não foi concluído". | A faixa diz onde está e o que faltou. | "Backup salvo em parte", com "Está em E:\Backup-…" e o que faltou; "O backup não foi salvo", com onde está o motivo. |
| D8 | A restauração com ressalvas ou sem nada restaurado tinha a faixa genérica. | Idem. | "Backup restaurado em parte" e "Nada foi restaurado". |
| D9 | Na restauração, a escolha do backup começava em Cancelar, e nenhum vinha em destaque. | O caminho comum em destaque. | O mais novo vem primeiro, em destaque e como padrão. A escolha só lê o backup: o que restaurar e a confirmação vêm depois. |
| D10 | Em inglês, "2 installed programs" na mesma faixa que dizia "1 program installed", e "7-Zip already is installed". | A ordem natural do inglês. | "2 programs installed" e "7-Zip is installed already". |

**Conferido e mantido:**
- um destaque só na página, Instalar programas essenciais, e as descrições em até 60 letras nos três idiomas;
- o escudo nas três ações que pedem Administrador;
- as listas de marcar vêm sem nada marcado, menos o que restaurar (a pessoa já escolheu ao fazer o backup);
- as perguntas que removem começam no Não: desinstalar, remover aplicativos, ligar o SMB 1.0 ou o PowerShell 2.0 e desligar o que tem risco;
- o desinstalar revê o que vai sair, com a versão, e avisa dos drivers instalados como programa;
- a lista de instalar diz o que já está no PC;
- o backup oferece primeiro o pendrive ou o HD externo, e Documentos avisa que fica no disco que vai ser formatado.

## Especialista Microsoft (MVP Windows)

**O que mudou**

| # | O que estava | Por que não é o melhor | Como ficou |
|---|---|---|---|
| M1 | Na lista de Remover aplicativos, o aplicativo do Microsoft 365 aparecia como "Microsoft 365 (atalho)". | A Microsoft o renomeou para Microsoft 365 Copilot em janeiro de 2025 e diz que agora ele se chama Microsoft Copilot. A pessoa não achava na lista o nome que vê no Menu Iniciar. | "Microsoft 365 Copilot (antigo Office)", com a descrição de que o Windows pode mostrá-lo como Microsoft 365 Copilot ou Copilot e de que o Office instalado não é afetado. |
| M2 | O Windows Sandbox dizia "só nas edições Pro e Enterprise". | A Microsoft o lista também na Education. | "só nas edições Pro, Enterprise e Education", como o Hyper-V. |
| M3 | A restauração reinstalava os programas com `winget import` sem `--ignore-versions`. | Uma lista com versões (feita com `--include-versions`, ou por outro programa) faria o winget procurar as versões gravadas, e não as atuais. | Com `--ignore-versions`: o winget sempre instala a versão mais nova, como no resto do WinForge. |

**Cada comando, conferido**

| Função | Como o WinForge faz | Veredito |
|---|---|---|
| Instalar programas essenciais | `winget install --id <id> -e --accept-source-agreements --accept-package-agreements --disable-interactivity --silent --source winget`, um por vez. A lista diz o que já está instalado (o `winget list`, lido uma vez a cada 2 minutos). | Certo, com o D1 e o D2. |
| Buscar e instalar | `winget search --query <termo>`, com as aspas tiradas do termo. Cada ID aparece uma vez, e o da Microsoft Store instala com `--source msstore`. | Certo, com o D1 a D3. |
| Listar programas instalados | `winget list`, sem contar as peças do Windows (as bibliotecas dos aplicativos, a Store e o próprio winget). O botão leva a atualizar quando há versão nova. | Certo. |
| Desinstalar programas | `winget uninstall --id <id> -e --disable-interactivity --silent` (com `--all-versions` quando há mais de uma). Ficam fora as bibliotecas de que outros programas dependem (Visual C++, .NET, WebView2), o Edge e as entradas sem desinstalador. Depois, o `winget list` é lido de novo: só sai como desinstalado o que saiu da lista. | Certo, com o D1. |
| Remover aplicativos do Windows | `Get-AppxPackage` e `Remove-AppxPackage`, só para a conta de quem usa e só de uma lista curta. Os componentes, os não removíveis e os do sistema nunca entram. A conferência lê a lista de novo. | Certo, com o M1 e o D4. |
| Recursos opcionais do Windows | `Get-WindowsOptionalFeature`, `Enable-WindowsOptionalFeature -All -NoRestart` e `Disable-WindowsOptionalFeature -NoRestart`. O WSL leva junto a Plataforma de Máquina Virtual, com o aviso do hipervisor. O Histórico de mudanças guarda o desfazer. | Certo, com o M2, o D5, o D6 e o Q1. |
| Backup antes de formatar | `winget export` e a lista do registro; `Export-WindowsDriver`, com o `pnputil /export-driver` se ele falhar; os ajustes do WinForge; `netsh wlan export profile key=clear`, com o aviso das senhas e a pergunta no Não numa pasta do OneDrive. Os arquivos pessoais ficam de fora, listados no LEIA-ME. | Certo, com o D7. |
| Restaurar a partir de um backup | `winget import` com `--ignore-unavailable`, `pnputil /add-driver *.inf /subdirs /install` (o 3010 pede reinício; o 259 é "já usam drivers iguais ou mais novos") e `netsh wlan add profile user=all`. Os drivers de outro modelo de PC vêm desmarcados. | Certo, com o M3, o D8 e o D9. |

**Conferido e mantido**
- **Remover aplicativos só para a conta de quem usa:** sem `-AllUsers` e sem tirar os pacotes do sistema. É o que a tela promete, e o aplicativo volta pela Store.
- **O Edge fora do desinstalar:** fora da Europa, o Windows não deixa desinstalá-lo, e o winget terminaria com erro.
- **O desinstalar não apaga pastas nem o registro à mão:** quem remove é sempre o desinstalador do programa; os restos têm a tela deles na Limpeza.
- **O Windows PowerShell 2.0 e o SMB 1.0 com o aviso e a pergunta no Não:** são inseguros, e a tela só os liga para quem precisa.
- **A Plataforma de Máquina Virtual junto com o WSL:** sem ela, o WSL fica no 1.

## QA Sênior

**Como foi testado:** cada função da página rodou com o Windows simulado, nos três idiomas: 106 conferências em português e 115 em inglês e em espanhol. As 9 a mais conferem, em cada seção, que nenhum texto do português aparece na tela.
- **Instalar programas essenciais (7 situações):** sem o winget, a lista e cancelar, instalar dois, o que já estava, em parte, a falha e um instalador que pede reinício.
- **Buscar e instalar (5):** vazio, sem resultado, sem internet, um da Microsoft Store com o ID repetido e as aspas no termo, e um programa aberto.
- **Listar (3):** a conta com o botão de atualizar, um formato de tabela novo e o winget com erro.
- **Desinstalar (6):** a lista sem as peças do Windows e com o aviso do driver, o Não, dois que saem, um que continua (com a pergunta de conferir de novo), em parte e nada a desinstalar.
- **Remover aplicativos (6):** elevado com outra conta, nenhum da lista, a lista sem os protegidos, o Não com o aposentado, dois removidos e um aberto.
- **Recursos opcionais (7):** sem Administrador, sem leitura, a lista com um pendente, o WSL com a Plataforma, o SMB 1.0 no Não, ligados com o reinício oferecido e o .NET 3.5 sem os arquivos.
- **Backup (6):** sem Administrador, cancelar, completo (com a pasta, os arquivos e o aviso das senhas), sem o winget, nada salvo e uma pasta que não existe.
- **Restaurar (6):** nenhum backup, a escolha, uma pasta que não é backup, outro modelo de PC, tudo e com problemas.
- **A página (29):** cada item existe e tem até 60 letras, o escudo nas três ações, um destaque só, o catálogo dos essenciais e o Windows Sandbox.
- **Os textos:** nenhum marcador `{0}` sobrando e nenhum texto do português na tela em inglês e em espanhol, com os catálogos de aplicativos e de recursos.

**Achados**

| # | Severidade | O que acontecia | Como ficou |
|---|---|---|---|
| Q1 | Média | Em inglês e em espanhol, a pergunta de ligar ou desligar um recurso só começava em português ("Ligar SMB 1.0 file sharing?"): o verbo era escrito no código, fora da tradução. | A pergunta inteira por idioma: "Turn on SMB 1.0 file sharing?", "¿Activar Uso compartido de archivos SMB 1.0?". |
| Q2 | Baixa | As faixas genéricas, o reinício não oferecido, o backup mais novo sem destaque, o nome do Microsoft 365, o Windows Sandbox e o `winget import` (são o D1 ao D10 e o M1 ao M3). | Corrigido. |

Cada conferência nova falha no código de antes e passa no de agora.

## Engenharia

**Por dentro**
- **Software.psm1:**
  - `Get-WinForgeWingetMissingResult` (nova): a faixa sem o winget, nas quatro telas, em Atualizar programas e nas Ferramentas do fabricante (Drivers.psm1);
  - `Invoke-WinForgeWingetPackages` guarda o motivo do primeiro que falhou (`Reason`);
  - `Set-WinForgeWingetPackagesView` monta a faixa de quando nenhum deu certo;
  - as faixas da busca sem resultado e da busca que falha.
- **PreinstalledApps.psm1:** o nome do Microsoft 365 Copilot e a faixa de quando nenhum aplicativo saiu.
- **WindowsFeatures.psm1:** a pergunta de um recurso pela tradução; o Windows Sandbox com a Education; a faixa de quando nada mudou; o reinício oferecido.
- **Backup.psm1:** as faixas do backup e da restauração; o backup mais novo em destaque; o `--ignore-versions`.
- **Traduções:** 30 novas, 3 que saíram de uso e 2 corrigidas em inglês; 5.271 ao todo.

**Conferido na nuvem**
- **As conferências dos Programas:** 106, 115 e 115, todas passando.
- **As 84 ações rodaram de novo 336 vezes** com o Windows simulado: nenhum erro escapou, e o resultado é o mesmo da R20, fora as faixas novas.
- **As de antes continuam passando:**
  - as 110, 117 e 117 das Atualizações, as 112, 119 e 119 do Reparo, as 96, 102 e 102 do Desempenho, as 178, 187 e 187 da Limpeza, as 134, 142 e 142 da Segurança e as 212, 224 e 224 do Diagnóstico;
  - as 245, 247 e 252 da Manutenção, com o desinstalar, os aplicativos e o winget do Otimizar, e as 241 do Início nos três idiomas;
  - as 83 do QA geral, as 80 da R11 e as 60 da R12;
  - as 59 da R9 e as 52 da R10;
  - as 66 da QA, as 28 da integração e as 26 da R7;
  - o motor de instalação, a atualização simulada e o Setup de verdade (da R20 para esta), e o pacote de suporte;
  - as traduções (5.271/5.271), as 159 referências nos três idiomas e a busca dos 102 itens;
  - nenhuma chamada com parâmetro que não existe, nenhuma função sem uso e nenhum aviso novo do analisador.

## O que só um PC mostra

Isto entrou no roteiro de conferência:
- **Restaurar um backup num Windows recém-instalado:** a escolha já vem no backup mais novo; o `winget import` instala as versões atuais; a faixa diz o que voltou. A linha de comando do winget mudou: é a mudança mais sensível desta revisão.
- **Recursos opcionais:** ligar o Windows Sandbox (numa edição Pro) oferece o reinício, com Não como padrão; com a tela em inglês, a pergunta sai em inglês.
- **Remover aplicativos do Windows:** num Windows 11 com o aplicativo do Microsoft 365, ele aparece como "Microsoft 365 Copilot (antigo Office)", e o nome confere com o do Menu Iniciar.
- **Um backup com o Wi-Fi desligado:** a faixa diz "Backup salvo em parte" e onde a pasta ficou.

## Fontes
- [The Microsoft 365 app transition to the Microsoft 365 Copilot app (Microsoft Support)](https://support.microsoft.com/microsoft-365-copilot/the-microsoft-365-app-transition-to-the-microsoft-365-copilot-app): o nome Microsoft 365 Copilot desde 15 de janeiro de 2025 e o nome atual, Microsoft Copilot.
- [Windows Sandbox (Microsoft Learn)](https://learn.microsoft.com/en-us/windows/security/application-security/application-isolation/windows-sandbox/): as edições Pro, Enterprise, Pro Education/SE e Education; a Home não tem.
- [Install Windows Sandbox (Microsoft Learn)](https://learn.microsoft.com/windows/security/application-security/application-isolation/windows-sandbox/windows-sandbox-install): o recurso `Containers-DisposableClientVM`.
- [import command (winget) (Microsoft Learn)](https://learn.microsoft.com/windows/package-manager/winget/import): `--ignore-unavailable`, `--ignore-versions`, `--accept-package-agreements`, `--accept-source-agreements` e `--disable-interactivity`.
