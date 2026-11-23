# WinForge 4.0 — revisão da Rede (R22)

**Data:** 19/11/2026 · **Versão:** Build 4.0 em preparação, depois da R21

**Pedido:** juntar quatro olhares para a tela e a função de Rede:
- **Analista de UX/UI Sênior (designer):** revisa cada detalhe da interface e orienta o engenheiro.
- **Especialista Microsoft (MVP Windows):** confere se os comandos e as alterações no Windows são feitos da melhor forma disponível hoje, de modo seguro e robusto, e se fazem sentido e mudam o que devem no PC.
- **QA Sênior:** testa todas as funções da tela.
- **Engenheiro de Software Sênior:** aplica as correções.

**Resultado:** 18 achados, todos corrigidos.

| Olhar | Achados |
|---|---|
| Designer | 10: as faixas genéricas quando não há rede, quando o teste de velocidade não mede, quando não há senha a mostrar, quando o reparo não funciona ou funciona em parte, quando a troca do DNS deixa um adaptador de fora ou não volta e quando o desfazer não devolve tudo; o tipo de rede sem explicação; a rede em destaque na Senha do Wi-Fi sem estar conectada; e o reparo dizendo "o reparo é indicado" logo abaixo de "Com acesso à internet" |
| MVP Windows | 6: o reparo deixava de renovar o IP do Wi-Fi quando outro adaptador (o do VirtualBox, o do WSL) tinha IP fixo; pela Área de Trabalho Remota ou com uma VPN, nenhum aviso antes da pergunta; na Manutenção, o reparo completo derrubava a Área de Trabalho Remota; num PC de domínio, a troca do DNS sugeria um DNS público; no Windows PowerShell 5.1, o ping contava como recebidos os pacotes perdidos; e o upload media junto o tempo de abrir a conexão |
| QA | 2 próprios: "Fixo:" em português nas telas em inglês e em espanhol, e um aviso do reparo começando em minúscula em inglês. Os testes também acharam todos os outros. |
| Engenharia | Nenhum próprio: aplicou os 18. |

Nada rodou num Windows de verdade. O Windows (os adaptadores, o IP, o DNS, o Wi-Fi, o ping, o `ipconfig`, o `netsh` e o servidor do teste de velocidade) foi simulado. O que só um PC mostra entrou no roteiro de conferência.

## A Rede hoje

A página tem, de cima para baixo:
1. **Ver e testar:**
   - Informações de rede;
   - Testar conectividade (ping), em destaque ("Testar agora");
   - Testar velocidade da internet;
   - Relatório de Wi-Fi;
   - Senha do Wi-Fi.
2. **Consertar e configurar:**
   - Reparar rede e DNS;
   - Trocar o servidor DNS;
   - Desfazer a troca de DNS.

Relatório de Wi-Fi, Senha do Wi-Fi, Reparar, Trocar e Desfazer pedem Administrador e mostram o escudo.

O que cada ação muda:
- **Informações, ping e velocidade:** só leem. O teste de velocidade usa até cerca de 35 MB e pergunta antes (com Não como padrão numa conexão limitada).
- **Relatório de Wi-Fi:** o Windows gera o relatório; o WinForge guarda uma cópia na pasta de relatórios.
- **Senha do Wi-Fi:** só lê; a senha aparece na tela e não vai para o log.
- **Reparar rede e DNS:** renova o IP, limpa o DNS e refaz o Winsock e o TCP/IP, com Não como padrão; IP e DNS postos à mão ficam.
- **Trocar o servidor DNS:** troca o DNS dos adaptadores Ethernet e Wi-Fi ativos, guardando antes o de cada um; se o novo não resolve nomes, volta sozinho.
- **Desfazer a troca de DNS:** devolve o DNS de antes da primeira troca.

## Designer (UX/UI)

| # | O que estava | Orientação | Como ficou |
|---|---|---|---|
| D1 | Informações de rede sem nenhum adaptador ativo terminava em "Concluído com ressalvas: Nenhum adaptador ativo encontrado…". | A mesma faixa do teste de conectividade, com o que fazer. | "Nenhuma rede conectada", com "Ligue o Wi-Fi ou conecte o cabo; confira também o modo avião." e o botão das configurações de rede. |
| D2 | O tipo de rede aparecia só como "Pública" ou "Privada". "Pública" numa rede de casa assusta quem não sabe que é o mais protegido. | Dizer o que cada um quer dizer, como o Windows diz. | "Privada (o PC aparece para os outros aparelhos da rede)" e "Pública (o PC não aparece para os outros aparelhos da rede)". |
| D3 | O teste de velocidade que não media o download, o upload ou nenhum dos dois terminava em "Concluído com ressalvas" ou "Não foi concluído", com o erro. | O título diz o que não foi medido; a frase, o que foi e o motivo; sem medir nada, um caminho. | "O download não foi medido", com o upload e o motivo; com o upload de fora, o download continua no título ("94 Mbps de download") e a frase diz que o upload não foi medido; sem nada, "Não foi possível medir a velocidade", com o motivo e o botão "Testar a conexão" (menos atrás do proxy que pede senha, que o ping não resolve). |
| D4 | Na Senha do Wi-Fi, uma rede aberta, uma rede de empresa, uma senha que o Windows não entrega, um PC sem Wi-Fi e nenhuma rede salva terminavam em "Nada a fazer". | O título diz por que não há senha a mostrar. | "Academia não tem senha" ("É uma rede aberta."), "Empresa não guarda senha", "A senha de Vizinho não pôde ser mostrada", "Este PC não tem Wi-Fi" e "Nenhuma rede Wi-Fi salva", cada um com a frase do motivo. |
| D5 | A primeira rede da lista vinha em destaque mesmo sem nenhuma conectada: era só a primeira em ordem alfabética. | O destaque marca o que ele promete. | Só a rede conectada agora vem em destaque. |
| D6 | O reparo sem nenhum comando funcionando terminava em "Não foi concluído"; com um comando falhando, em "Concluído com ressalvas: 1 comando falhou". | O título diz o que a pessoa quer saber: a conexão voltou? | "O reparo não funcionou", com onde estão os códigos; com um comando falhando, "A conexão está funcionando" (ou "A conexão ainda não voltou"), com "Redefinir TCP/IP não deu certo; o código está no resumo." |
| D7 | Com os testes diretos falhando e o Windows dizendo "Com acesso à internet" (comum numa rede com proxy), a tela dizia logo abaixo "A internet não está funcionando: o reparo é indicado". | A tela não pode se contradizer. | "Os testes diretos falharam, mas o Windows informa acesso à internet (comum em redes com proxy ou firewall): só continue se os sites não abrirem." O mesmo quando os nomes de sites resolvem. |
| D8 | Trocar o DNS sem Wi-Fi nem cabo terminava em vermelho, "Não foi concluído: sem adaptador ativo". | Não é um erro do WinForge: é ligar um deles, como no ping. | Amarelo, "Nenhum Wi-Fi ou cabo conectado", com o botão das configurações de rede. |
| D9 | A troca que deixava um adaptador de fora tinha a faixa genérica; a troca que não funcionava e não conseguia voltar dizia "Não foi concluído". | O título diz qual DNS ficou; quando o de antes não volta, o botão do que resolve. | "DNS trocado para Cloudflare", com "1 adaptador não foi alterado (Ethernet); o motivo está no resumo."; "O DNS de antes não voltou", com o botão "Desfazer a troca de DNS". |
| D10 | O desfazer com um adaptador desligado, recusado pelo Windows ou feito em parte tinha a faixa genérica. | O título diz se o DNS de antes voltou; a frase, o que fazer com o resto. | "O DNS de antes não voltou", com "O adaptador Wi-Fi não está ativo agora: ligue-o e repita; o backup foi mantido." (ou onde está o motivo); "DNS de antes restaurado em parte". |

**Conferido e mantido:**
- um destaque só na página, Testar conectividade, e as descrições em até 60 letras nos três idiomas;
- o escudo nas cinco ações que pedem Administrador;
- o reparo e a troca do DNS começam no Não e no Cancelar; o reparo diz o que vai fazer, em palavras, antes de perguntar;
- o ping e o reparo com o andamento na barra de progresso, e só o resultado no resumo;
- a senha do Wi-Fi só na tela, fora do log e fora da faixa.

## Especialista Microsoft (MVP Windows)

**O que mudou**

| # | O que estava | Por que não é o melhor | Como ficou |
|---|---|---|---|
| M1 | Um IP fixo em qualquer adaptador tirava do reparo o `ipconfig /release` e o `/renew`, além do `netsh int ip reset`. Num PC com VirtualBox ou WSL (os adaptadores deles têm IP fixo), o Wi-Fi nunca renovava o IP. | Pela documentação da Microsoft, o `/release` e o `/renew` só mexem nos adaptadores que pegam o IP automaticamente; um IP fixo continua como está. Quem apaga IP e DNS fixos é o `netsh int ip reset`, que reescreve as chaves do TCP/IP. | O `/release` e o `/renew` rodam quando algum adaptador conectado pega o IP do roteador; só o reset de TCP/IP sai com IP ou DNS fixo, e o aviso diz qual adaptador e por quê. Sem nenhum adaptador automático conectado, ou sem conseguir ler, eles continuam de fora. |
| M2 | Pela Área de Trabalho Remota ou com uma VPN ligada, o reparo só dizia "A conexão pode cair por alguns instantes". | A pessoa perde justamente a conexão por onde está. | Antes da pergunta (que segue com Não): "Este PC está sendo usado pela Área de Trabalho Remota: o reparo derruba a conexão, e o acesso remoto pode não voltar sozinho." ou "Há uma VPN ligada: o reparo pode desconectá-la." |
| M3 | Na Manutenção (sem ninguém para confirmar), com a internet fora, o reparo completo rodava mesmo pela Área de Trabalho Remota ou com uma VPN. | Numa rede local, a Área de Trabalho Remota funciona com a internet fora; liberar o IP derrubaria a sessão de quem está administrando o PC. | Como no Otimizar: só limpa o DNS, e o motivo vai para o resultado. |
| M4 | Num PC do domínio de uma empresa, a troca do DNS medida deixava um DNS público em destaque. | O DNS da empresa é o que acha os servidores dela; a própria Microsoft avisa que o Active Directory depende muito do DNS. Um DNS público impediria o login e o acesso à rede. | O aviso "Este PC faz parte do domínio de uma empresa: … Mantenha o atual.", nada em destaque, e Cancelar continua como padrão. |
| M5 | No Windows PowerShell 5.1 (o que o WinForge usa), cada resposta do ping é um `Win32_PingStatus`, e a contagem olhava só se havia um campo `Status`, que ele não tem. | Pela documentação, só o `StatusCode` 0 é sucesso; 11010 é tempo esgotado. Se o Windows devolve os pacotes perdidos, um alvo sem resposta contava como 0% de perda. | Só conta como recebido o `StatusCode` 0 (no PowerShell 7, o `Status` Success, como antes). |
| M6 | O upload abria a conexão com o servidor dentro do tempo medido: resolver o nome, o TCP e o TLS caíam todos no primeiro envio. | O download já começa a medir depois de abrir a conexão; numa internet rápida, esse tempo derrubava o upload. | Um pedido vazio ao mesmo servidor abre a conexão antes do relógio; se ele falhar, os envios tentam do mesmo jeito. |

**Cada comando, conferido**

| Função | Como o WinForge faz | Veredito |
|---|---|---|
| Informações de rede | `Get-NetAdapter` (os ativos), `Get-NetIPConfiguration`, `Get-NetConnectionProfile`, `netsh wlan show interfaces` (com o aviso da Localização no Windows 11), o DNS de cada família por `Get-DnsClientServerAddress`, o proxy do registro (sem a conta e sem a chave do endereço) e o IP público em api.ipify.org, com a fonte na tela. | Certo, com o D1 e o D2. |
| Testar conectividade | `Test-Connection`, 4 pacotes para 1.1.1.1, 8.8.8.8, 9.9.9.9, www.microsoft.com e www.google.com (3 s por resposta no PowerShell 7). Separa sem rede, sem internet, DNS e conexão instável; um nome que não responde ao ping é perguntado ao DNS. | Certo, com o M5. |
| Testar velocidade | HTTPS ao speed.cloudflare.com: a latência é a mediana de pedidos vazios, sem o tempo do servidor (`Server-Timing`); o download, até 25 MB em até 12 s, medido depois do arranque; o upload, blocos de 1 MB por até 8 s. Passa pelo proxy do sistema com a conta do Windows. | Certo, com o M6 e o D3. |
| Relatório de Wi-Fi | `netsh wlan show wlanreport`, conferido pela data do arquivo (um relatório antigo não passa por novo), copiado para a pasta de relatórios e aberto pelo `explorer.exe`, sem a elevação. | Certo. |
| Senha do Wi-Fi | `netsh wlan export profile key=clear` numa pasta temporária própria, lida como XML (não muda com o idioma) e apagada na hora. A senha cifrada e a rede de empresa não são mostradas. | Certo, com o D4 e o D5. |
| Reparar rede e DNS | `ipconfig /release` e `/renew` (com algum adaptador automático conectado), `ipconfig /flushdns`, `netsh winsock reset` e `netsh int ip reset` (fora com IP ou DNS fixo em qualquer adaptador). Depois, confere a conexão por até um minuto e pede reinício só se o Winsock ou o TCP/IP rodaram. | Certo, com o M1 a M3, o D6 e o D7. |
| Trocar o servidor DNS | Mede o tempo de resposta direto a cada servidor (`Resolve-DnsName -DnsOnly -NoHostsFile`); guarda antes o DNS de cada família (o `NameServer` de Tcpip e de Tcpip6); troca com `Set-DnsClientServerAddress` (IPv4 e IPv6 do provedor); confere se resolve nomes e, se não, volta sozinho. | Certo, com o M4, o Q1, o D8 e o D9. |
| Desfazer a troca de DNS | Volta ao automático (`-ResetServerAddresses`) e só então devolve as famílias que eram fixas; só endereços IP de verdade viram servidores; o backup sai quando tudo voltou. | Certo, com o D10. |

**Conferido e mantido**
- **Os endereços dos provedores:** Cloudflare (1.1.1.1, 1.0.0.1, 2606:4700:4700::1111 e ::1001), Google (8.8.8.8, 8.8.4.4, 2001:4860:4860::8888 e ::8844), Quad9 (9.9.9.9, 149.112.112.112, 2620:fe::fe e 2620:fe::9) e Cloudflare para famílias (1.1.1.3, 1.0.0.3, 2606:4700:4700::1113 e ::1003), conferidos nas páginas de cada um.
- **O filtro para famílias nunca em destaque:** é escolha de quem quer o bloqueio.
- **O reset de TCP/IP fora com IP ou DNS fixo:** a Microsoft diz que ele reescreve as chaves do TCP/IP, com o mesmo efeito de remover e reinstalar o protocolo.
- **Nenhum destaque quando a rede bloqueia DNS externo** ou quando o DNS atual já é tão rápido quanto o melhor.
- **A troca não liga o DNS criptografado (DoH):** o Windows conhece Cloudflare, Google e Quad9 como servidores com DoH, mas ligá-lo é uma escolha à parte nas Configurações; fica como ideia para depois.

## QA Sênior

**Como foi testado:** cada função da página rodou com o Windows simulado, nos três idiomas: 144 conferências em português e 153 em inglês e em espanhol. As 9 a mais conferem, em cada seção, que nenhum texto do português aparece na tela.
- **Informações de rede (8 situações):** Wi-Fi conectado, nenhum adaptador, o IP ilegível, a Localização desligada, o Wi-Fi de hotel, sem o IP público, o sinal fraco e uma VPN com WSL e um proxy com conta e chave.
- **Testar conectividade (8, e o ping do 5.1):** tudo responde, sem rede, o erro de "nenhum perfil", nada responde, o DNS quebrado, nomes que ignoram o ping, instável e um alvo que ignora o ping; o `Win32_PingStatus` com perda e sem resposta.
- **Testar velocidade (8, e o upload):** cancelar, a conexão limitada, medida, lenta, sem o download, sem o upload, sem internet e o proxy que pede senha; o upload de verdade com um servidor falso.
- **Relatório de Wi-Fi (3):** sem Administrador, um relatório antigo e o gerado, aberto pelo Explorador.
- **Senha do Wi-Fi (10):** sem Administrador, sem Wi-Fi, o serviço parado, nenhuma rede salva, a rede conectada (a senha fora da faixa e os arquivos apagados), de empresa, aberta, a senha cifrada, nenhuma conectada e Voltar.
- **Reparar rede e DNS (16):** sem Administrador, a internet funcionando, tudo automático, DNS fixo (Pi-hole), o VirtualBox, o Wi-Fi com IP fixo, sem conseguir ler os IPs, a Área de Trabalho Remota, a VPN, nada funcionou, um comando falhou, a conexão não volta, nenhuma rede e a Manutenção (rede funcionando, Otimizar e Área de Trabalho Remota).
- **Trocar o servidor DNS (11):** sem Administrador, sem adaptador, cancelar, Cloudflare (com o backup e o Histórico), uma segunda troca, o novo que não funciona, DNS externo bloqueado, o atual já rápido, PC de domínio, um adaptador que não muda e o que não volta.
- **Desfazer a troca de DNS (5):** nada a desfazer, a volta ao fixo de antes, o adaptador desligado, recusado e em parte.
- **A página (18):** cada item existe e tem até 60 letras, o escudo nas cinco ações e um destaque só.
- **Os textos:** nenhum marcador `{0}` sobrando e nenhum texto do português na tela em inglês e em espanhol, com os provedores de DNS.

**Achados**

| # | Severidade | O que acontecia | Como ficou |
|---|---|---|---|
| Q1 | Média | O DNS fixo aparecia como "Fixo: 1.1.1.1, …" nas telas em inglês e em espanhol, em Trocar e em Desfazer: a palavra era escrita no código, fora da tradução. | "Static: …" e "Fijo: …". |
| Q2 | Baixa | Em inglês, o aviso do DNS fixo no reparo começava em minúscula ("static DNS on Wi-Fi: reset TCP/IP was removed…"). | Começa em maiúscula nos três idiomas. |
| Q3 | Baixa | As faixas genéricas, o tipo de rede, o destaque, o reparo que se contradiz, a renovação do IP, os avisos de Área de Trabalho Remota e VPN, o PC de domínio, o ping do 5.1 e o upload (são o D1 ao D10 e o M1 ao M6). | Corrigido. |

Cada conferência nova falha no código de antes e passa no de agora.

## Engenharia

**Por dentro**
- **Network.psm1:**
  - `Get-WinForgePingStats` conta só o `StatusCode` 0 do `Win32_PingStatus`;
  - `Get-WinForgeStaticIpConfiguration` diz também se há adaptador automático conectado (`Dhcp`), e `Get-WinForgeNetworkRepairCommands` ganha `-NoDhcp`;
  - `Invoke-WinForgeNetworkRepair`: a renovação do IP com IP fixo em outro adaptador, os avisos de Área de Trabalho Remota, VPN e rede com proxy, a Manutenção que não derruba a sessão e as faixas;
  - `Measure-WinForgeUpload` abre a conexão antes de medir (`-WarmupUrl`);
  - `Set-WinForgeSpeedFailureView` (nova) e as faixas de `Test-WinForgeInternetSpeed`;
  - o tipo de rede explicado e a faixa de `Show-WinForgeNetworkInfo` sem rede.
- **NetworkTools.psm1:** "Fixo:" pela tradução; o PC de domínio e as faixas de `Set-WinForgeDnsProvider`; as faixas de `Undo-WinForgeDnsChange`; as faixas e o destaque de `Show-WinForgeWifiPassword`.
- **Traduções:** 38 novas e 3 que saíram de uso; 5.306 ao todo.

**Conferido na nuvem**
- **As conferências da Rede:** 144, 153 e 153, todas passando.
- **As 84 ações rodaram de novo 336 vezes** com o Windows simulado: nenhum erro escapou, e o resultado é o mesmo da R21, fora as faixas novas.
- **As de antes continuam passando:**
  - as 106, 115 e 115 dos Programas, as 110, 117 e 117 das Atualizações, as 112, 119 e 119 do Reparo, as 96, 102 e 102 do Desempenho, as 178, 187 e 187 da Limpeza, as 134, 142 e 142 da Segurança e as 212, 224 e 224 do Diagnóstico;
  - as 245, 247 e 252 da Manutenção, com o reparo de rede do Otimizar, e as 241 do Início nos três idiomas;
  - as 83 do QA geral, as 80 da R11 e as 60 da R12;
  - as 59 da R9 e as 52 da R10;
  - as 66 da QA, as 28 da integração e as 26 da R7;
  - o motor de instalação, a atualização simulada e o Setup de verdade (da R21 para esta), e o pacote de suporte;
  - as traduções (5.306/5.306), as 159 referências nos três idiomas e a busca dos 102 itens;
  - nenhuma chamada com parâmetro que não existe, nenhuma função sem uso e nenhum aviso novo do analisador.

## O que só um PC mostra

Isto entrou no roteiro de conferência:
- **Reparar a rede num PC com VirtualBox ou WSL e Wi-Fi:** a tela lista `ipconfig /release` e `/renew`, sem o `netsh int ip reset`, e avisa do IP fixo do adaptador virtual; depois, o adaptador do VirtualBox continua com o IP dele (192.168.56.1). É a mudança mais sensível desta revisão: o reparo volta a liberar o IP nesses PCs.
- **Reparar pela Área de Trabalho Remota:** o aviso aparece antes da pergunta.
- **Trocar o DNS num PC de domínio:** o aviso, nada em destaque.
- **Testar a velocidade numa internet rápida:** o upload fica mais perto do que o teste da operadora mostra.
- **Testar a conectividade com o cabo solto e o Wi-Fi ligado a uma rede sem internet:** "Sem resposta" em cada IP, e não "OK".
- **Informações de rede:** o tipo de rede com a explicação.

## Fontes
- [ipconfig (Microsoft Learn)](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/ipconfig): o `/release` e o `/renew` só nos adaptadores que pegam o IP automaticamente.
- [Reset TCP/IP by Using the NetShell Utility (Microsoft Learn)](https://learn.microsoft.com/en-us/troubleshoot/windows-server/networking/reset-tcp-ip-net-shell): o `netsh int ip reset` reescreve as chaves do TCP/IP, com o mesmo efeito de remover e reinstalar o protocolo.
- [Win32_PingStatus (Microsoft Learn)](https://learn.microsoft.com/en-us/previous-versions/windows/desktop/wmipicmp/win32-pingstatus): `StatusCode` 0 é sucesso; 11010, tempo esgotado.
- [Win32_ComputerSystem (Microsoft Learn)](https://learn.microsoft.com/en-us/windows/win32/cimwin32prov/win32-computersystem): `PartOfDomain`.
- [Secure DNS Client over HTTPS (DoH) (Microsoft Learn)](https://learn.microsoft.com/windows-server/networking/dns/doh-client-support): a lista de servidores conhecidos com DoH e o aviso de que o Active Directory depende muito do DNS.
- [Rede pública e privada no Windows (Suporte da Microsoft)](https://support.microsoft.com/en-us/kb/4043043): na pública, o PC fica oculto para os outros aparelhos da rede; na privada, aparece.
- [1.1.1.1: endereços (Cloudflare)](https://developers.cloudflare.com/1.1.1.1/ip-addresses/), [Quad9: endereços e serviços](https://quad9.net/service/service-addresses-and-features/) e [Google Public DNS: Get Started](https://developers.google.com/speed/public-dns/docs/using?hl=ca): os endereços IPv4 e IPv6 de cada provedor.
