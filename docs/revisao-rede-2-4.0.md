# WinForge 4.0 — segunda revisão da Rede (R46)

**Data:** 21/11/2026 · **Versão:** Build 4.0 em preparação, depois da R45

**Pedido:** revisar a tela e a função Rede com cinco olhares:
- **Analista de Produto Sênior:** avalia o todo.
- **Engenheiro de Software Sênior:** revisa o código, refatora, segue as boas práticas, tira o que não serve e melhora o desempenho.
- **Designer Sênior, com um Especialista em UX/UI:** revisam a tela, os botões, os textos e os fluxos; o engenheiro aplica.
- **MVP Windows:** confere se a Rede segue as práticas da Microsoft, se cada função faz da melhor forma o que promete e se é robusta e estável.
- **QA Sênior:** testa tudo o que dá para testar, o óbvio e o que não é; o engenheiro aplica.

**De onde partiu:** a primeira revisão da Rede (R22) foi antes do desenho novo (R37), da revisão de UX (R38) e das faixas no alto das páginas (R41 a R43). Esta olhou as nove telas da página e o que elas dividem com outras partes: o teste da conexão do reparo (que o Otimizar usa) e a troca do DNS (que o Histórico de mudanças desfaz).

**Resultado:** 11 achados, todos corrigidos.

| Olhar | Achados |
|---|---|
| Produto | 3: a página sem dizer se o PC está conectado; o reparo pedindo para reiniciar sem oferecer; e o teste de velocidade sem nenhuma rede terminando num erro técnico |
| Engenharia | 2: o ping de um endereço depois do outro, com um caminho para cada versão do PowerShell; e o reparo montando a lista de comandos duas vezes e achando cada um pelo título traduzido |
| Designer e UX/UI | 3: Sim e Não em quatro perguntas; o DNS só com os números; e um site que só ignora o ping em vermelho, logo acima de "A internet está funcionando" |
| MVP Windows | 1: o Wi-Fi que pede login numa página tratado como "sem internet", com o reparo oferecido e, no Otimizar, feito |
| QA | 2: cada rede duas vezes na Senha do Wi-Fi com dois adaptadores; e trocar para o DNS que já está em uso anotando uma mudança no Histórico |

Nada rodou num Windows de verdade. A conferência foi feita na nuvem: a página com as funções de verdade da janela sobre o WPF simulado, as telas com o Windows simulado (os adaptadores, o IP, o DNS, o registro, o Wi-Fi, o relógio e o que o Windows diz da conexão) e o ping de verdade, pela classe Ping do .NET, no próprio PC. O que só um PC mostra entrou no roteiro de conferência (§37).

## A Rede hoje

No alto, a faixa **Conexão** (nova). Depois, de cima para baixo:
1. **Ver e testar:** Informações de rede; Testar conectividade (ping), em destaque ("Testar agora"); Testar velocidade da internet; Relatório de Wi-Fi; Senha do Wi-Fi.
2. **Consertar e configurar:** Acertar a data e a hora; Reparar rede e DNS; Trocar o servidor DNS; Desfazer a troca de DNS.

O Relatório e a Senha do Wi-Fi, a data e a hora, o reparo e a troca do DNS pedem Administrador e mostram o escudo.

## Analista de Produto

| # | O que estava | Por que importa | Como ficou |
|---|---|---|---|
| P1 | A página não dizia se o PC está conectado. Para saber, era preciso rodar o Testar conectividade (cerca de 15 segundos, E1) ou olhar o ícone de rede da barra de tarefas. | É a primeira pergunta de quem abre a Rede. A Manutenção, a Limpeza e o Desempenho já abrem com a faixa do assunto delas (R41 a R43), e o Windows tem essa resposta pronta, na hora. | A faixa **Conexão**, com o que o próprio Windows diz da conexão (o mesmo do ícone de rede): "Wi-Fi Casa · com internet", "Cabo de rede · sem internet", "Wi-Fi Hotel · acesso limitado (a rede pode pedir login)" ou "nenhuma rede conectada". Sem internet, com o acesso limitado ou sem rede, a linha fica em amarelo, com a seta, e abre o Testar conectividade, que confirma o problema e leva ao que resolve. A leitura não passa pelo WMI e não atrasa a página. |
| P2 | O reparo, depois de refazer o Winsock e o TCP/IP, dizia "Reinicie o PC para o reparo terminar de valer." e terminava ali. | A Microsoft manda reiniciar depois do reset do TCP/IP. O Corrigir o Windows Update, os Recursos opcionais e o CHKDSK já oferecem o reinício ali mesmo. | Oferece reiniciar, com "Reiniciar agora" e "Depois" e o Depois como padrão, só quando o Winsock ou o TCP/IP foram refeitos. Dentro do Otimizar, não pergunta: o Otimizar oferece o reinício no fim, como antes. |
| P3 | O Testar velocidade sem nenhuma rede (Wi-Fi desligado, cabo solto) perguntava "Iniciar o teste agora?" e terminava em "Não foi possível medir a velocidade", com o erro técnico ("Este host não é conhecido"). | O Testar conectividade e as Informações de rede, nesse caso, já dizem "Nenhuma rede conectada" com o botão das configurações. | Sem perguntar nem medir, a mesma faixa: "Nenhuma rede conectada", "Ligue o Wi-Fi ou conecte o cabo; confira também o modo avião.", com o botão "Abrir as configurações de rede". |

**Conferido e mantido:**
- **Um destaque só, o Testar conectividade:** é o que responde "minha internet funciona?", e a faixa nova leva até ele.
- **Desfazer a troca de DNS como item próprio,** além do Histórico de mudanças: é para onde a troca manda quando o DNS de antes não volta, e ele diz quando não há o que desfazer.
- **Acertar a data e a hora na Rede:** o relógio se acerta pela rede, e um relógio errado derruba os sites seguros (os erros de certificado).

## Engenheiro de Software

| # | O que estava | Como ficou |
|---|---|---|
| E1 | O Testar conectividade pingava os cinco endereços um depois do outro, pelo `Test-Connection`: quatro pacotes, um por segundo, cerca de 3 segundos por endereço com a internet funcionando (cerca de 15 no total) e mais sem ela. O teste da conexão do reparo e do Otimizar pingava o 1.1.1.1 e, sem resposta, o 8.8.8.8. E o `Test-Connection` responde de um jeito em cada PowerShell (o 5.1 devolve um `Win32_PingStatus`; o 7, outro objeto, com outro prazo), com um caminho no código para cada um. | `Get-WinForgePingReplies` (nova) manda os pacotes a todos os endereços juntos, uma rodada por segundo, pela classe Ping do .NET (`SendPingAsync`), a mesma nos dois PowerShell: os cinco endereços levam cerca de 3 segundos (até 5, com algum sem resposta), e cada resposta espera até 2 segundos, com o Parar funcionando no meio. Um nome que não vira endereço conta como pacote perdido. O teste do reparo pinga os dois endereços juntos. `ConvertTo-WinForgePingStats` (nova) faz a conta da perda e dos tempos; `Get-WinForgePingStats` saiu. |
| E2 | O reparo montava a lista de comandos duas vezes (uma para dizer o que faz, outra para fazer) e achava o "Renovar endereço IP" e o "Redefinir TCP/IP" na lista comparando o título traduzido. A faixa "Nenhuma rede conectada" estava escrita à mão em quatro lugares. | Cada comando tem um `Id` (`release`, `renew`, `flushdns`, `winsock`, `ipreset`) e a lista é montada uma vez. A faixa sem rede é uma só, `Set-WinForgeNoNetworkView` (nova), para o teste de conectividade, o de velocidade, as Informações de rede e o reparo. |

**Por dentro:**
- **Network.psm1:**
  - `Get-WinForgePingReplies`, `ConvertTo-WinForgePingStats`, `Get-WinForgeInternetConnection`, `Get-WinForgeNetworkPageStatus` e `Set-WinForgeNoNetworkView` (novas); `Get-WinForgePingStats` (saiu);
  - `Test-WinForgePing`, `Get-WinForgePingVerdict` (`-Limited`), `Test-WinForgeInternetConnectivity`, `Get-WinForgeNetworkRepairCommands` (`Id`), `Invoke-WinForgeNetworkRepair`, `Test-WinForgeInternetSpeed`, `Show-WinForgeNetworkInfo` e `Write-WinForgeNetworkConfig`;
  - o cabeçalho diz o que o módulo tem.
- **NetworkTools.psm1:** `Get-WinForgeDnsProviderName` e `Test-WinForgeDnsAlready` (novas); `Get-WinForgeDnsModeText`, `Set-WinForgeDnsProvider`, `Read-WinForgeWifiProfiles`, o Relatório de Wi-Fi e o relógio; o cabeçalho, que falava só do DNS e do relatório.
- **WinForge.Gui.ps1:** `New-GuiPageStatus` lê a faixa da Rede.
- **Traduções:** 5.616 textos (26 novos e 1 que saiu de uso). Entraram seis funções (1.299 nos módulos).

## Designer e Especialista em UX/UI

| # | O que estava | Orientação | Como ficou |
|---|---|---|---|
| D1 | Quatro perguntas com Sim e Não: "Reparar a rede agora?", "Iniciar o teste agora?", "Abrir o relatório agora?" e "Pôr o relógio na hora do servidor da Microsoft agora?". É a UX21 da revisão de UX, aplicada nesta página. | Os botões dizem o que fazem, como a Microsoft orienta ("Use specific responses to the main instruction or content as button text"). | "Reparar" e "Cancelar" (o Cancelar como padrão, como antes); "Testar" e "Cancelar" (o Cancelar como padrão numa conexão limitada); "Abrir" e "Agora não"; "Acertar" e "Agora não". No menu de texto, as perguntas continuam com S/N. |
| D2 | O DNS aparecia só com os números ("Fixo: 1.1.1.1, 1.0.0.1, 2606:4700:4700::1111, …"), em Trocar o servidor DNS, em Desfazer a troca de DNS e nas Informações de rede. | Depois de trocar pelo WinForge, a pessoa reconhece o nome que escolheu, e não o endereço. | "Fixo (Cloudflare): 1.1.1.1, …" na troca e no desfazer, e "1.1.1.1, 1.0.0.1 (Cloudflare)" nas Informações de rede, quando os endereços são de um dos quatro provedores da troca. Um DNS fixo de outro (um Pi-hole, o da empresa) continua só com os números. |
| D3 | Um site que não responde ao ping (servidores que o ignoram), com o nome funcionando, aparecia em vermelho, "Sem resposta", logo acima de "A internet está funcionando". | A tela não pode se contradizer (a mesma regra da R22). | A linha diz "Não responde ao ping (normal em alguns servidores)", sem vermelho. Um IP sem resposta continua em vermelho, e um nome que não resolve continua sendo um problema de DNS. |

**Conferido e mantido:**
- **A faixa nova** é a das outras páginas: o rótulo à esquerda, a frase em amarelo e a seta só quando pede atenção, o leitor de tela com "Abre: Testar conectividade (ping)".
- **Um ícone por item,** as descrições em até 60 letras nos três idiomas, a ordem e os grupos da página.
- **O reparo e a troca do DNS** começam no Cancelar; o reparo diz o que vai fazer, em palavras, antes de perguntar (R22).

## MVP Windows

| # | O que estava | Por que importa | Como ficou |
|---|---|---|---|
| M1 | Num Wi-Fi que pede login numa página (hotel, aeroporto, café), antes de entrar, o Testar conectividade dizia "Sem internet" (ou, com o DNS da rede respondendo, "Os sites não abrem pelo nome") e oferecia o reparo. O reparo dizia "A internet não está funcionando: o reparo é indicado." E o Otimizar, com a internet fora e ninguém olhando, fazia o reparo inteiro: renovavam o IP e refaziam o Winsock e o TCP/IP, com um reinício para terminar. | Nenhum comando do reparo faz o login. O Windows já sabe desse caso: o indicador de conectividade dele (o NCSI) percebe o portal quando a sonda dele não recebe o texto esperado, e a API marca a conexão como acesso limitado (`ConstrainedInternetAccess`), "possivelmente por um portal cativo". | `Get-WinForgeInternetConnection` (nova) lê esse indicador pela API do Windows (`Windows.Networking.Connectivity`), na hora e sem o WMI. Com algo sem resposta e o acesso limitado, o teste diz "A rede limita o acesso", "Comum em Wi-Fi de hotel, aeroporto e café: abra o navegador e entre na página de login da rede.", sem o botão do reparo. O reparo avisa antes de perguntar, no lugar de "o reparo é indicado". O Otimizar só limpa o DNS e diz por quê. |

**Conferido**, com as fontes no fim:
- **O indicador de conectividade é um indício:** a Microsoft avisa que o acesso limitado pode ser também um proxy no caminho, e que o estado é "only a hint". Por isso a faixa diz "acesso limitado (a rede pode pedir login)" e leva ao teste, que confirma com os pacotes; o indicador só muda o conselho quando o teste também falha (M1).
- **O reinício depois do reset do TCP/IP:** "Restart the computer", no passo a passo da Microsoft (P2).
- **O ping pela classe Ping do .NET:** um pedido por instância (a mesma instância recusa um segundo envio ao mesmo tempo) e um nome que não vira endereço como erro, que o WinForge conta como pacote perdido (E1). O `Test-Connection` do Windows PowerShell 5.1 manda quatro pacotes, um por segundo, e devolve um `Win32_PingStatus` por resposta: era o tempo de cada endereço (E1).
- **A exportação dos perfis de Wi-Fi:** "Each exported profile is saved as 'Interface Name-Profile Name.xml'", um arquivo por adaptador (Q1).
- **O restante da R22 continua valendo:** o reparo que não apaga IP nem DNS fixos e renova o IP dos adaptadores automáticos; os avisos de Área de Trabalho Remota, VPN e proxy; o DNS medido direto em cada servidor, com o backup por família e a volta sozinha quando o novo não resolve; o PC de domínio sem destaque; a senha do Wi-Fi lida do XML, fora do log; o relatório de Wi-Fi aberto sem a elevação; o relógio pelo servidor de teste da Microsoft.
- **Robusto:** a leitura da faixa nunca derruba a página (sem a API, "não foi possível ler"); cada pacote do ping tem prazo; e as perguntas novas começam no lado que não muda nada.

## QA Sênior

**Como foi testado:** uma bateria nova da Rede, 128 conferências em cada idioma.
- **A faixa (A):** com internet, sem internet, o acesso limitado, nenhuma rede, sem como saber, sem o nome da rede; o botão, a seta, a cor, o leitor de tela e o clique; uma leitura ao abrir a página, e nenhuma nas outras; os ícones, as descrições, a ordem e o destaque da página.
- **Testar conectividade (B):** os cinco endereços de uma vez; tudo respondendo; um site que ignora o ping; um IP sem resposta; nada respondendo e o DNS bloqueado num Wi-Fi que pede login; nada respondendo numa rede comum; a conexão instável; nenhuma rede; o ping de verdade no próprio PC (o tempo de quatro rodadas, as respostas, um nome que não existe, a barra de progresso); a conta da perda; o teste do reparo com os dois IPs juntos, a conexão TCP e nada respondendo.
- **Reparar rede e DNS (C):** os botões da pergunta; o reparo inteiro; a oferta de reiniciar, o Depois e o Reiniciar agora (o `shutdown /r /t 0`, com o motivo); sem o Winsock refeito; o Wi-Fi que pede login, sozinho e dentro de um fluxo (o Otimizar); o Otimizar numa rede comum e com a internet funcionando; os `Id`; a faixa sem rede.
- **Testar velocidade (D):** sem nenhuma rede; os botões; a medida; a conexão limitada.
- **Trocar e desfazer o DNS (E):** o provedor no DNS atual; escolher o que já está em uso (Cloudflare e o automático); trocar de provedor; dois adaptadores com um já no Cloudflare; um já no Cloudflare e o outro sem o DNS legível; o Cloudflare só no IPv4; a ordem trocada; um Pi-hole; o desfazer com o provedor.
- **Informações de rede (F):** o provedor nas duas famílias, o DNS do roteador, sem adaptador.
- **Senha do Wi-Fi (G):** a mesma rede em dois adaptadores, a cópia com a senha cifrada, nomes que só diferem na maiúscula.
- **As perguntas (H):** o Relatório de Wi-Fi e o relógio.
- **O código (I)** e **os textos (J)** nos três idiomas.

**Achados**

| # | O que estava | Como ficou |
|---|---|---|
| Q1 | Num notebook com um segundo adaptador de Wi-Fi (um USB), a Senha do Wi-Fi mostrava cada rede salva nos dois duas vezes: o Windows exporta um arquivo por adaptador ("Wi-Fi-Casa.xml" e "Wi-Fi 2-Casa.xml"). | Cada rede aparece uma vez; das cópias, vale a que tem a senha em texto. Redes cujos nomes só diferem na maiúscula continuam separadas. |
| Q2 | Escolher em Trocar o servidor DNS o que o PC já usa (o Cloudflare de novo, ou o Automático com o DNS já automático) regravava o DNS, guardava um backup e anotava "trocado para Cloudflare" no Histórico de mudanças, sem nada ter mudado. | "Este PC já usa Cloudflare" (ou "o DNS automático"), "Nada mudou.", sem tocar no adaptador, sem backup e sem nada no Histórico. Com dois adaptadores, só o que ainda não usa o escolhido muda. |

Os testes também acharam os do produto (P1 a P3), os do designer (D1 a D3) e o do MVP (M1).

**A bateria antiga da Rede (R22):** quatro conferências pediam o que mudou de propósito e passaram a pedir o novo: o andamento do ping, que agora é por rodada (quatro) e não por endereço (cinco); as duas do `Win32_PingStatus`, que saiu com o `Test-Connection` (a mesma conta, agora pelos tempos das respostas); e o DNS fixo, agora com o provedor. Ela responde Sim a todas as perguntas, e passou a responder Depois à oferta de reiniciar. Com isso, os mesmos números da R45: 145, 154 e 154, com a mesma conferência antiga do escudo.

**Contra o código de antes (R45):** cada conferência das correções falha (56). Das 72 que passam, 39 conferem o que foi mantido (o reparo inteiro numa rede comum, a conexão instável, a troca de um provedor para outro, a faixa sem adaptador, o relógio acertado, a página) e 33 são os textos, que em português não têm o que diferenciar. Com o mesmo ping de verdade no próprio PC (o PowerShell 7 da nuvem), os cinco endereços levaram 15,1 segundos no código de antes, um depois do outro, e 3,0 no de agora.

**47 defeitos de propósito,** e as conferências pegam todos: a Rede sem a faixa na janela; a faixa sem destino sem internet ou sem rede, com seta com internet, no tom normal com o acesso limitado, em amarelo sem saber, sem o nome de reserva ou lida pelo WMI; o ping com três pacotes, sem a pausa de um segundo ou com três, contando pacote perdido como recebido, sem o número do pacote na barra, derrubado por um nome que não existe e, no teste do reparo, com um IP só; o site que ignora o ping em vermelho; a rede que pede login esquecida no teste, com o DNS bloqueado virando problema de DNS, com o botão do reparo, ou a conexão do Windows lida mesmo com tudo respondendo; o reparo com Sim e Não, sem a oferta de reiniciar, com ela no Otimizar ou sem o Winsock refeito, refazendo o Winsock numa rede que pede login, sem o aviso, sem ler a conexão do Windows ou lendo-a com a internet funcionando, com a lista montada duas vezes, com um `Id` trocado e com a faixa sem rede escrita à mão; a velocidade sem conferir a rede ou com Sim e Não; o provedor fora do DNS atual e das Informações de rede, ou achado só pelo primeiro endereço; escolher o que já está em uso trocando de novo, o automático nunca igual, o IPv6 e a ordem esquecidos, e um adaptador ilegível escondido; cada rede duas vezes, a cópia cifrada na frente e redes de maiúsculas diferentes juntadas; o Relatório de Wi-Fi e o relógio com Sim e Não; e o cabeçalho antigo. Na primeira rodada, um defeito não pôde ser aplicado (o trecho aparecia duas vezes no código); com o trecho único, ele foi pego.

**Nada do que funcionava quebrou:** as baterias das 14 páginas revistas, com os mesmos números da R45 (a da Rede da R22 com 145, 154 e 154, depois das adaptações acima, com a mesma conferência antiga do escudo); a das seis funções novas da R36 (257 em cada idioma); a do Início da R40 (115), a da Manutenção da R41 (67), a da Limpeza da R42 (97), a do Desempenho da R43 (94), a do Reparo da R44 (92) e a do Diagnóstico da R45 (87) em cada idioma; a da Manutenção da R14 (243, 245 e 250), com o reparo de rede do Otimizar, e a do Início da R13 (241); as mensagens da janela (72 em cada idioma); instalar, atualizar com um clique, o pacote de suporte e o Setup de verdade, da R45 para esta; nenhuma função sem uso (1.517, seis novas e uma que saiu). O PSScriptAnalyzer ficou com 244 avisos, um a menos que na R45 (o `catch` vazio do ping de antes), e nenhum novo.

## O que só um PC mostra

Isto entrou no roteiro de conferência (§37):
- **A faixa Conexão:** com internet, sem internet (um roteador sem o cabo do modem), nenhuma rede (o Wi-Fi desligado) e um Wi-Fi que pede login (hotel, café), e o nome da rede; com a Localização desligada no Windows 11, o nome pode faltar.
- **O Testar conectividade** em cerca de 3 a 5 segundos, com os mesmos resultados de antes; e o Wi-Fi que pede login, no teste, no reparo e no Otimizar.
- **A oferta de reiniciar** depois do reparo.
- **O teste de velocidade** com o Wi-Fi desligado.
- **O DNS com o nome do provedor** e escolher o que já está em uso.
- **A Senha do Wi-Fi** num notebook com um adaptador de Wi-Fi USB.
- **Os botões novos** nos três idiomas.

## Fontes
- [NetworkConnectivityLevel Enum](https://learn.microsoft.com/uwp/api/windows.networking.connectivity.networkconnectivitylevel) (Microsoft): "ConstrainedInternetAccess: Limited internet access. This value is an indication that the connection is constrained, possibly due to a captive portal." e "The network status reported by Windows APIs is only a hint".
- [Network Connectivity Status Indicator overview](https://learn.microsoft.com/en-us/windows-server/networking/ncsi/ncsi-overview) (Microsoft): o NCSI percebe um portal cativo quando a resposta da sonda "didn't match the expected content: `Microsoft Connect Test`", e os portais ficam "in public environments such as airports, hospitals, coffee shops".
- [NetworkInformation Class](https://learn.microsoft.com/en-us/uwp/api/windows.networking.connectivity.networkinformation) (Microsoft): `GetInternetConnectionProfile`, a conexão preferida, que "may return null if offline".
- [Reset TCP/IP by using the NetShell utility](https://learn.microsoft.com/en-us/troubleshoot/windows-server/networking/reset-tcp-ip-net-shell) (Microsoft): depois do `netsh int ip reset`, "Restart the computer."
- [Ping.SendPingAsync](https://learn.microsoft.com/en-us/dotnet/api/system.net.networkinformation.ping.sendpingasync) (Microsoft): o pedido assíncrono, a recusa de um segundo envio na mesma instância e o erro de um nome que não vira endereço.
- [Test-Connection, Windows PowerShell 5.1](https://learn.microsoft.com/th-th/powershell/module/microsoft.powershell.management/test-connection?view=powershell-5.1) (Microsoft): quatro pacotes, um por segundo, e um `Win32_PingStatus` por resposta.
- [netsh wlan](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/netsh-wlan) (Microsoft): "Each exported profile is saved as 'Interface Name-Profile Name.xml'."
- [Dialog controls](https://learn.microsoft.com/windows/apps/design/controls/dialogs-and-flyouts/dialogs) (Microsoft): "Use specific responses to the main instruction or content as button text".
