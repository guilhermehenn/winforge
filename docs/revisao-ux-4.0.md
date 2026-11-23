# WinForge 4.0 — revisão de UX/UI

Uma revisão da experiência de uso do WinForge, feita em 21/11/2026 sobre a Build 4.0 (o commit b4f4662 da branch `b370`), 29 revisões depois da R8. Esta revisão não muda nada no programa: ela diz o que manter, o que mudar e em que ordem. A decisão do que entra, e quando, é do dono do WinForge.

**Quem revisou:** um Analista de UX/UI Sênior.

**Como foi feita:**
- **As telas, montadas pelo código de verdade.** As funções do `WinForge.Gui.ps1` montaram cada página sobre um WPF simulado, o mesmo caminho da prévia do Início na R37. A árvore de cada tela virou HTML e imagem.
  - 12 páginas e a busca;
  - os dois temas e os três idiomas;
  - com e sem Administrador;
  - na largura de abertura (1.180) e na mínima (900).
- **As 88 ações, no modo janela.** Cada uma rodou duas vezes, aceitando e cancelando, com as mudanças no PC bloqueadas: 176 execuções. De cada uma ficou o texto das perguntas, das opções e da faixa de resultado.
- **O texto medido** nos três idiomas: as descrições, os subtítulos e as descrições dos ajustes.
- **A leitura do código:**
  - da janela: `gui/MainWindow.xaml`, `WinForge.Gui.ps1` e `modules/GuiHost.psm1`;
  - da navegação e da busca: `modules/Navigation.psm1`;
  - do menu do terminal: `modules/Menus.psm1`;
  - do monitor: `WinForge.Agent.ps1`;
  - do instalador: `WinForge.Setup.ps1`.
- **Maquetes das propostas**, feitas do mesmo jeito: as funções de verdade com só a mudança proposta, numa cópia fora do WinForge.

**Referências:**
- a R8 (`docs/revisao-interface-4.0.md`) e as revisões de cada tela (R13 a R28);
- as orientações da Microsoft para a chave liga/desliga e para os botões das perguntas;
- a Nielsen Norman Group.

As fontes estão no fim.

**O que esta revisão não viu:**
- **Nada rodou num Windows.** As imagens usam a fonte Inter no lugar da Segoe UI. O desenho não mostra a chave liga/desliga nem o seletor de Aparência como o WPF os desenha.
- **Parte das ações parou cedo.** Das 176 execuções, 79 pararam em comandos que só existem no Windows. As perguntas e as faixas que essas ações mostrariam depois disso não foram vistas.
- **A tela de execução foi avaliada pelo XAML e pelos textos** de cada ação, e não por imagem.
- **As leituras do sistema nas imagens** (memória, atalho, Administrador) são as do ambiente de teste, e não as de um PC.

**Depois desta revisão (R39):** no Windows de verdade, o WPF recusava a fonte dos títulos. Por isso, no Início não apareciam o cartão da nota, "Seu PC" com os cartões e o "Histórico neste PC", e em cada página faltava o destaque. A prévia na nuvem não pegava isso, porque o WPF simulado aceitava o que o Windows recusa. A R39 corrigiu: com a correção, a janela fica como as imagens desta revisão mostram, e os achados continuam valendo.

---

## Veredito

A janela deu um salto desde a R8:
- as páginas viraram listas agrupadas, com um só destaque;
- as 102 descrições das ações cabem em 60 letras, nos três idiomas;
- o escudo tomou o lugar do aviso escrito;
- o Início conta a história do PC.

A tela de execução continua no nível dos melhores. Os títulos das faixas dizem o que houve: "Lixeira esvaziada", "28,3 GB livres de 252 GB", "Sem internet".

O que falta agora é mais fino. São **peças de gerações diferentes convivendo** e **três interações que pedem mais passos do que deviam**.

As três mudanças que mais rendem:
1. **A chave do ajuste muda na própria linha (UX19).** Hoje, cada chave leva para a tela de execução e pede Voltar.
2. **Uma peça para cada função (UX10 a UX16):**
   - o destaque sempre no alto, com um só laranja cheio;
   - a mesma faixa de resumo na Manutenção e em Ajustes;
   - os ajustes com a regra das 60 letras.
3. **Perguntas e resultados mais diretos (UX20 a UX25):**
   - o verbo no botão;
   - "Procurar..." para escolher a pasta;
   - a duração só uma vez;
   - nada de erro técnico cru nem de texto fora do idioma.

## Placar

De 1 (fraco) a 5 (no nível dos melhores). A coluna R8 tem as notas de 18/11/2026; "—" marca um critério novo.

| Critério | R8 | Hoje | Por quê |
|---|---|---|---|
| Confiança e honestidade | 5 | 5 | Continua o diferencial: anota cada mudança, oferece desfazer e começa as perguntas perigosas no Não |
| Caminho principal | 4 | 4 | Um destaque por página e os dois caminhos no Início. Na Rede, o destaque cai no meio da lista; na busca por "limpar", a Limpeza rápida vem em 5º |
| Hierarquia visual | 3 | 4 | Listas agrupadas, com títulos de seção. O quadrado laranja cheio do destaque disputa com o botão |
| Consistência do sistema visual | 3 | 3 | O Início e as listas novas convivem com peças antigas: o cartão da Manutenção, as linhas dos ajustes e o carregamento escrito |
| Quantidade de texto | 2 | 4 | Nenhuma das 102 descrições das ações passa de 60 letras. As dos ajustes ficaram de fora: 50 de 53 passam |
| Interação e controles | — | 3 | A chave que sai da página, a pasta digitada e o Sim e Não |
| Mensagens e resultado | — | 4 | Os títulos dizem o que houve. A duração aparece duas vezes, e um erro inesperado chega cru |
| Idiomas | — | 4 | Três idiomas completos. Duas dicas do terminal e um título do monitor escapam da tradução |
| Acessibilidade | 4 | 4 | Nomes e descrições para o leitor de tela, contraste medido e foco visível. O contraste alto e o tamanho do texto entraram na R9; só um PC confirma |

## O que a R8 pediu e onde está

| R8 | Situação |
|---|---|
| UX1 — texto demais nos cartões | Feito para as ações: 0 de 102 descrições passam de 60 letras, nos três idiomas. Os ajustes ficaram de fora (UX15) |
| UX2 — o aviso de Administrador escrito | Feito: o escudo na linha e no botão, e a frase na dica |
| UX3 e UX4 — o contraste alto e o tamanho do texto | Feitos na R9; a conferir num PC, pelo roteiro |
| UX5 — o carregamento escrito | Feito no Início, com esqueletos. Ajustes e Personalização ainda escrevem (UX16) |
| UX6, UX7 e UX9 — a tela de execução, a busca e o teclado | Mantidos |
| UX8 — os outros idiomas são mais longos | Conferido em espanhol, a 900 de largura: as listas das ações cabem; as dos ajustes quebram em duas linhas (UX15) |

---

## Achados

**Gravidade:**
- **alta:** atrapalha o uso de todo dia;
- **média:** confunde, ou parece descuido numa tela à vista;
- **baixa:** acabamento.

**Esforço:** P (pequeno), M (médio) ou G (grande). **Risco** é a chance de quebrar algo que funciona hoje.

### Páginas

**UX10 — Rede: o destaque cai no meio da lista, colado no grupo de cima.** O destaque da página (Testar conectividade) é o 2º item da tabela.
- **O que acontece:** a função `Show-GuiListPage` põe o cartão do destaque no lugar do item. Os itens seguintes do mesmo grupo entram no cartão do grupo, que já está acima.
- **O resultado:**
  - o destaque fica depois de Senha do Wi-Fi, fora da ordem que a R22 descreveu;
  - não há espaço entre os dois cartões: o grupo não tem margem embaixo, e o destaque não tem em cima.
- **Hoje é a única página assim.** Uma página nova com o destaque fora do 1º lugar terá o mesmo defeito.
- **Proposta:** o destaque sempre no alto, antes das seções, como o comentário do próprio código diz ("vem em destaque no alto"). A ordem do terminal e da busca não muda.
- **Imagens:** `rede-hoje.png` e `rede-proposta.png`.
- Gravidade média · Esforço P · Risco baixo.

**UX11 — Manutenção: o cartão "Última manutenção" é do desenho antigo.** É o único `New-GuiFactCard` que sobrou. O comentário da função ainda diz "Cartão de informação do Início".
- **Hoje:** o cartão ocupa meia largura, tem três linhas e fica a 4 px do destaque.
- **Nas outras páginas:** o resumo é uma faixa de largura inteira, a 16 px do destaque (Limpeza, Desempenho, Sobre o WinForge).
- **Proposta:** a mesma faixa de resumo, "Última manutenção · Ainda não executada · o ideal é uma por mês". A faixa ganha a seta que abre o histórico, como o cartão faz hoje.
- **Imagens:** `manutencao-hoje.png` e `manutencao-proposta.png`.
- Gravidade baixa · Esforço P · Risco baixo.

**UX12 — O quadrado do destaque pesa mais que o botão.** Cada destaque tem um quadrado de 48 px todo laranja e, à direita, o botão laranja: dois blocos da cor de destaque no mesmo cartão. No Início, o único laranja cheio é o botão.
- **Proposta:** o quadrado no tom suave do item escolhido na barra lateral (`NavSelected`), com o ícone em laranja. O botão passa a ser o único laranja cheio.
- **O contraste do ícone:** 6,1:1 no tema escuro e 4,0:1 no claro, acima dos 3:1 que a WCAG pede para gráficos (critério 1.4.11).
- **Imagens:** `limpeza-claro-hoje.png` e `limpeza-claro-proposta.png`. As maquetes da Rede e da Manutenção também já têm o quadrado novo.
- Gravidade baixa · Esforço P · Risco baixo.

**UX13 — Personalização: o texto começa em dois lugares no mesmo cartão.** Em "Cores e transparência" e em "Tela de bloqueio", as linhas de ajuste não têm ícone, e as linhas de ação (Cor de destaque, Tela de bloqueio do Windows) têm.
- **O resultado:** o texto começa em duas colunas, e a altura muda de uma linha para a outra.
- **Proposta:** as linhas de ação dessas páginas num grupo próprio, no fim. Os ajustes ficam como as Configurações do Windows os mostram.
- **Imagem:** `personalizacao-hoje.png`.
- Gravidade baixa · Esforço P · Risco baixo.

**UX14 — Ajustes e Personalização abrem com um parágrafo.** Abaixo dos botões vem: "Cada chave mostra como o Windows está agora: ligue para ativar e desligue para desativar. O WinForge guarda o valor de antes. Mudados pelo WinForge nesta página: 0."
- **O problema:** são duas linhas que explicam o que uma chave faz. Elas repetem o subtítulo ("Mudanças reversíveis, com backup do valor original").
- **Proposta:**
  - a instrução sai, porque a dica da chave já a tem;
  - a conta vira a faixa de resumo das outras páginas, no alto: "Mudanças · 3 ajustes desta página mudados pelo WinForge".
- **Imagens:** `ajustes-hoje.png` e `ajustes-proposta.png`.
- Gravidade baixa · Esforço P · Risco baixo.

**UX15 — As descrições dos ajustes ficaram fora da regra das 60 letras.**

| Página | Ajustes no catálogo | Passam de 60 letras | Média |
|---|---|---|---|
| Ajustes do Windows | 35 | 32 | 84 letras; em espanhol, até 115 |
| Personalização | 18 | 18 | 77 letras |

- **O efeito:** em espanhol, a 900 de largura, várias quebram em duas linhas, e cada linha fica de uma altura.
- **Proposta:** a mesma regra das ações, até uns 55 caracteres. O texto mais longo já tem onde ficar: o catálogo tem o campo `About`, que pode ir para a dica da linha.
- **Exemplo:** "Exibe .exe, .pdf, .png etc. no Explorador (ajuda a perceber arquivos disfarçados)." (82 letras), abaixo de "Mostrar extensões de arquivos", vira "Ajuda a perceber arquivos disfarçados" (37 letras).
- Gravidade média · Esforço M (53 textos, nos três idiomas) · Risco baixo.

**UX16 — Ajustes e Personalização carregam escrevendo.** Enquanto leem o Windows, as duas páginas mostram "Lendo o estado atual dos ajustes...". O Início, desde a R9, mostra esqueletos.
- **Proposta:** os cartões dos grupos com linhas-esqueleto, do tamanho das linhas de verdade.
- Gravidade baixa · Esforço P · Risco baixo.

**UX17 — Ícones repetidos com sentidos diferentes.** As 102 linhas usam 45 ícones. Repetir faz parte, mas alguns enganam:
- o chip serve para memória, drivers e dispositivos, dois deles no mesmo grupo do Diagnóstico;
- o cadeado serve para "Manter programas na versão atual" e para "Apagar o espaço livre";
- a lupa serve para "Verificar vírus" e para "Buscar e instalar programas".

- **Proposta:** quatro ou cinco ícones novos, no mesmo traço dos de hoje: memória, impressora, alfinete, borracha e escudo com lupa.
- Gravidade baixa · Esforço M · Risco baixo.

**UX18 — Sobre o WinForge: o subtítulo é uma lista.** "Versão e atualizações, suporte, atalho, logs, monitor na bandeja, dados online, aparência e idioma." São oito assuntos, no maior subtítulo dos três idiomas: 99 letras, e 122 em espanhol.
- **Proposta:** "A versão, o suporte e as preferências do WinForge."
- Gravidade baixa · Esforço P · Risco baixo.

### Interação

**UX19 — A chave do ajuste sai da página.** Ligar ou desligar uma chave abre a tela de execução (`Start-GuiAction`). Depois:
1. a pessoa lê "Tudo certo";
2. clica em Voltar;
3. a página lê de novo todos os ajustes e rola até o que ela mudou.

São duas trocas de tela e uma leitura completa para cada chave, nas 53 chaves de Ajustes e Personalização.
- **O que as referências dizem** (tradução livre):
  - a Microsoft: usar a chave "para opções de dois estados quando a mudança vale logo depois que a pessoa a faz";
  - a Nielsen Norman Group: a chave "deve ter efeito imediato".
- **Proposta:** a ação roda do mesmo jeito, mas a janela fica na página:
  - durante a ação, a chave não aceita clique, e a linha mostra "Aplicando..." no lugar de "Ativado";
  - no fim, a linha mostra o estado real, lido de novo só para aquele ajuste;
  - a tela de execução só abre quando a ação pergunta algo (o estado não identificado), falha ou pede reinício;
  - o resto aparece na faixa de ação em andamento, que já existe no alto das páginas.
- **O que a R23 decidiu continua:** a chave nunca mostra um estado que o Windows não tem, e cada mudança vai para o Histórico de mudanças.
- Gravidade alta · Esforço G · Risco médio. A ação é a mesma; muda o que a janela mostra durante e depois dela.

**UX20 — A pasta é digitada.** Seis ações pedem um caminho numa caixa de texto ("Cole o caminho da pasta"):
- o destino do Backup antes de formatar;
- a pasta do backup, ao restaurar;
- a pasta dos arquivos duplicados;
- a pasta ou o arquivo de Verificar uma pasta;
- a pasta da chave do BitLocker;
- o arquivo .json de Importar ajustes.

Numa janela do Windows, o esperado é o botão "Procurar...". A janela do WinForge já usa a caixa de salvar do Windows (`SaveFileDialog`) para salvar a saída das ações.
- **Proposta:**
  - a pergunta diz, por um parâmetro, que pede uma pasta ou um arquivo;
  - a janela põe "Procurar..." ao lado da caixa, que continua aceitando colar;
  - o terminal não muda.
- Gravidade média · Esforço M · Risco baixo.

**UX21 — Sim e Não nas perguntas.** Das 60 perguntas de Sim e Não das ações, só 4 dizem no botão o que fazem, como "Reiniciar agora" e "Depois".
- **Exemplo:** no Otimizar, a pergunta da Lixeira tem os botões "Esvaziar" e "Manter". Na ação Esvaziar a Lixeira, a pergunta "Deseja esvaziar a Lixeira?" tem Sim e Não.
- **A orientação da Microsoft:** usar no botão a resposta específica à pergunta, como Excluir e Cancelar, porque ela "é entendida mais rápido".
- **Proposta:** o verbo no botão, a começar pelas perguntas que mudam o PC: apagar, fechar, encerrar, desinstalar, reiniciar e restaurar ("Esvaziar", "Fechar", "Encerrar", "Desinstalar"...).
  - O suporte já existe: os parâmetros `-YesLabel` e `-NoLabel`.
  - O terminal continua com S/N.
- Gravidade média · Esforço M (as frases nos três idiomas) · Risco baixo.

### O resultado da execução

**UX22 — A duração aparece duas vezes.** A linha de estado mostra "Concluído · 00:02". O texto da faixa termina em "Duração: 00:02.". Isso acontece nas 84 faixas vistas, inclusive nas das ações de um segundo.
- **Proposta:** a duração só na linha de estado e no log. A faixa fica com o que aconteceu ("Liberou 1,2 GB.").
- Gravidade baixa · Esforço P · Risco baixo.

**UX23 — Um erro inesperado chega cru na faixa.** Quando uma ação falha por um erro que ela não previu, a faixa mostra o texto do .NET ou do PowerShell como ele veio.
- **Exemplo:** no teste de velocidade, a faixa foi "The proxy tunnel request to proxy '...' failed with status code '403'.".
- **O problema:** a frase pode vir em outro idioma e fala de coisas que a pessoa não vê.
- **Proposta:**
  - a faixa diz em palavras o tipo do problema: sem resposta, acesso negado, não encontrado ou tempo esgotado;
  - em seguida, "O motivo técnico está nos detalhes";
  - o texto original fica nos detalhes técnicos e no log.
- Gravidade média · Esforço M · Risco baixo.

**UX24 — Em inglês e espanhol, dicas do terminal aparecem na janela.** A janela tira do texto da pergunta as dicas do terminal, como "(ENTER cancela)" e "(vazio = voltar)", e põe o botão certo. Mas `Get-WinForgePromptPlan` procura as frases do português, e as traduções que trocam a palavra escapam.
- **Em inglês,** "(ENTER cancels)" fica escrito em três perguntas de pasta.
- **Em inglês e espanhol,** "(empty = back)" e "(vacío = volver)" ficam escritos na escolha por ID de Atualizar programas (winget). Nessa pergunta, o botão sai Cancelar em vez de Voltar.
- **Proposta:** a pergunta diz por um parâmetro qual é o botão de sair, como a lista de marcação já faz com `-CancelLabel`, em vez de a janela procurar a frase.
- Gravidade baixa · Esforço P · Risco baixo.

**UX25 — "Avisos pausados" não muda de idioma.** O título do aviso do monitor, quando os avisos são pausados por 24 horas, está escrito direto no código (`WinForge.Agent.ps1`, linha 129), sem passar pela tradução. Em inglês e espanhol, ele aparece em português.
- **Proposta:**
  - o título passa pelo `Get-WinForgeText`;
  - um teste novo procura textos de tela fora da tradução.
- Gravidade baixa · Esforço P · Risco baixo.

### A busca

**UX26 — A busca por "limpar" põe a Limpeza rápida em 5º.**

| Posição | Resultado |
|---|---|
| 1º | A página Limpeza (certo: o Enter a abre) |
| 2º | Limpar a pasta Downloads |
| 3º | Limpar o registro (do grupo Avançado) |
| 4º | Limpar componentes do Windows (do grupo Avançado) |
| 5º | Limpeza rápida, o destaque da página e o caminho mais seguro |

- **Por quê:** a pontuação dá 16 ou 17 a quem começa com a palavra e 9 a quem só tem o radical.
- **Proposta:** um pequeno bônus para o destaque de cada página e um pequeno desconto para o grupo Avançado. Os dois ficam pequenos o bastante para não passar na frente do nome exato.
- **Imagem:** `busca-limpar-hoje.png`.
- Gravidade média · Esforço P · Risco baixo (a busca tem testes próprios).

**UX27 — "Ajustes do Windows > ajuste".** Na linha de cima de cada ajuste achado, a palavra "ajuste" repete o que o nome da página já diz.
- **Proposta:** a categoria no lugar dela: "Ajustes do Windows › Explorador".
- Gravidade baixa · Esforço P · Risco baixo.

**UX28 — Gerenciar inicialização está em dois lugares, com duas frases.** Os dois itens abrem a mesma ação:
- em Desempenho: "O que abre junto com o Windows; desligue o que não precisa";
- em Programas: "Desative ou reative o que abre junto com o Windows".

A busca mostra só um, e qual depende da palavra: "inicialização" traz o de Desempenho, e "lento", o de Programas.
- **Proposta:** a mesma frase nos dois, e a busca sempre com o mesmo.
- Gravidade baixa · Esforço P · Risco baixo.

### Fora da janela

**UX29 — O menu do terminal tem outra ordem.**
- **A barra lateral** agrupa as páginas em Cuidar, Consertar, Proteger e Configurar: Manutenção, Limpeza, Desempenho, Reparo...
- **O terminal** segue a tabela de navegação: Manutenção, Diagnóstico, Segurança, Limpeza...

Quem passa de um para o outro procura a página em outro lugar. Os itens de cada página já vêm na mesma ordem e com as mesmas seções.
- **Proposta:** o terminal na ordem da barra, com os títulos dos grupos, como o menu de cada página já faz com as seções.
- **Atenção:** os números do menu mudam, e quem usa o terminal desde a 3.x vai achar as páginas em outros números. Como a 4.0 ainda não saiu, é a hora de mudar.
- Gravidade baixa · Esforço P · Risco baixo.

**UX30 — O instalador é uma janela de texto.** O primeiro contato de quem compra é o `WinForge-Setup.cmd`: uma janela de terminal com perguntas de Sim e Não ("Instalar o WinForge?", "Criar também um atalho na Área de Trabalho?", "Abrir o WinForge agora?"). Funciona e é honesto, mas destoa do resto.
- **Proposta:** uma janela pequena com o visual do WinForge, em três passos:
  1. onde instalar e os atalhos;
  2. o andamento;
  3. o fim, com o botão "Abrir o WinForge".
- **Estudar junto com a assinatura (I2):** um instalador assinado muda o aviso do Windows ao abrir.
- Gravidade média · Esforço G · Risco médio.

---

## O que não mudar

- **A honestidade:** só o que o WinForge faz de verdade, com o Histórico e o desfazer.
- **Um destaque por página,** com o verbo no botão.
- **As perguntas perigosas começam no lugar seguro:**
  - "Deseja esvaziar a Lixeira?" começa no Não, com o Sim na cor de perigo;
  - na Limpeza rápida, "Só os temporários" vem em destaque, e "Temporários e Lixeira", na cor de perigo;
  - "Fechar …?" começa no Não.
- **As faixas que dizem o que houve,** como "1 programa fechado", e o próximo passo no botão, como "Reparar a rede".
- **O cancelar** diz "Cancelado" e "Operação cancelada", sem chamar de erro.
- **A busca:**
  - a página primeiro, aberta pelo Enter;
  - os sintomas: "lento" traz Otimizar, Limpeza rápida, Acelerar agora e Programas pesando agora.
- **As descrições das ações** em até 60 letras, e o escudo no lugar do aviso escrito.
- **A acessibilidade:** o nome e a descrição de cada chave para o leitor de tela, o contraste medido e o foco visível.

## Plano

Esforço: P (pequeno), M (médio) ou G (grande). Risco é a chance de quebrar algo que funciona hoje.

**Fase 1 — pequena e de baixo risco** (cabe na 4.0, antes da conferência num PC)

| # | O quê | De onde | Esforço | Risco |
|---|---|---|---|---|
| 1 | O destaque sempre no alto | UX10 | P | Baixo |
| 2 | A faixa de resumo na Manutenção e em Ajustes, sem o parágrafo | UX11, UX14 | P | Baixo |
| 3 | O quadrado do destaque no tom suave | UX12 | P | Baixo |
| 4 | As linhas de ação da Personalização num grupo próprio | UX13 | P | Baixo |
| 5 | Esqueletos em Ajustes e Personalização | UX16 | P | Baixo |
| 6 | O subtítulo do Sobre o WinForge | UX18 | P | Baixo |
| 7 | A duração só na linha de estado | UX22 | P | Baixo |
| 8 | As dicas do terminal e "Avisos pausados" nos três idiomas | UX24, UX25 | P | Baixo |
| 9 | A ordem da busca, a linha de cima dos ajustes e a frase da inicialização | UX26, UX27, UX28 | P | Baixo |
| 10 | O terminal na ordem da barra lateral | UX29 | P | Baixo |

**Fase 2 — a interação e o texto** (a UX19 primeiro: é a que mais rende)

| # | O quê | De onde | Esforço | Risco |
|---|---|---|---|---|
| 11 | A chave do ajuste na própria linha | UX19 | G | Médio |
| 12 | "Procurar..." nas seis perguntas de pasta ou arquivo | UX20 | M | Baixo |
| 13 | O verbo no botão das perguntas que mudam o PC | UX21 | M | Baixo |
| 14 | O erro inesperado em palavras, com o original nos detalhes | UX23 | M | Baixo |
| 15 | As 53 descrições dos ajustes em até 60 letras, nos três idiomas | UX15 | M | Baixo |
| 16 | Os ícones novos | UX17 | M | Baixo |

**Fase 3 — estudo antes de decidir**

| # | O quê | De onde | Esforço | Risco |
|---|---|---|---|---|
| 17 | O instalador com janela, junto com a decisão da assinatura | UX30, I2 | G | Médio |

## As maquetes

As imagens desta revisão ficam em `docs/revisao-ux/`. As de "hoje" saíram das funções de verdade do WinForge. As de "proposta" usam as mesmas funções com só a mudança proposta, numa cópia fora do WinForge. Nada delas está no programa.

| Imagem | O que mostra |
|---|---|
| `rede-hoje.png` | A Rede hoje: o destaque depois de Senha do Wi-Fi, colado no grupo (UX10) |
| `rede-proposta.png` | A Rede com o destaque no alto e o quadrado suave (UX10, UX12) |
| `manutencao-hoje.png` | A Manutenção com o cartão antigo a 4 px do destaque (UX11) |
| `manutencao-proposta.png` | A Manutenção com a faixa de resumo e o quadrado suave (UX11, UX12) |
| `ajustes-hoje.png` | O alto de Ajustes do Windows, com o parágrafo (UX14) |
| `ajustes-proposta.png` | O alto de Ajustes do Windows, com a faixa de resumo (UX14) |
| `limpeza-claro-hoje.png` | O destaque da Limpeza no tema claro, com o quadrado cheio (UX12) |
| `limpeza-claro-proposta.png` | O mesmo destaque com o quadrado suave (UX12) |
| `personalizacao-hoje.png` | "Cores e transparência", com o texto começando em dois lugares (UX13) |
| `busca-limpar-hoje.png` | A busca por "limpar", com a Limpeza rápida em 5º (UX26) |

## Fontes

- [Toggle switches — Microsoft Learn](https://learn.microsoft.com/en-sg/windows/apps/design/controls/toggles): "Use a toggle switch for binary settings when changes become effective immediately after the user changes them". Quando é preciso mais um passo para valer, a página indica a caixa de seleção.
- [Toggle switches — Nielsen Norman Group](https://www.nngroup.com/articles/toggle-switch-guidelines/): "Toggle switches should take immediate effect".
- [Dialog controls — Microsoft Learn](https://learn.microsoft.com/windows/apps/design/controls/dialogs-and-flyouts/dialogs): "Use specific responses to the main instruction or content as button text". O exemplo de excluir um arquivo usa os botões "Delete" e "Cancel".
- A WCAG 2.2, critério 1.4.11 (3:1 para componentes e gráficos), a mesma referência da R37.
