# WinForge 4.0 — revisão da interface

Uma revisão geral da janela do WinForge, feita em 18/11/2026 sobre a Build 4.0 (o commit 25f2496 da branch `b370`). Ela compara a janela com o que há de melhor hoje em design, produto e UX/UI. Esta revisão não muda nada no programa: ela diz o que manter, o que mudar e em que ordem. A decisão do que entra, e quando, é do dono do WinForge.

**Quem revisou:** quatro olhares, cada um com a sua seção:
- um Gerente de Marketing Sênior;
- um Gerente de Produto Sênior (o pedido citou quatro pessoas e três cargos; o quarto olhar é o de produto, que o pedido também cita);
- um Designer Sênior;
- um Analista de UX/UI Sênior.

**Como foi feita:**
- a leitura do código da janela: `gui/MainWindow.xaml`, as cores e os ícones de `modules/GuiDesign.psm1` e a montagem das telas em `WinForge.Gui.ps1`;
- a navegação medida no próprio código: as páginas, os itens, os grupos e o tamanho de cada descrição;
- as prévias das builds anteriores (3.30 a 3.47), para ver o visual;
- maquetes novas, em HTML, de duas telas: hoje e na proposta.

**Referências:** o Windows 11 e o Fluent 2 (a fonte Segoe UI Variable, a escala de tamanhos, a Mica e os cantos), as Configurações do Windows 11 (listas agrupadas) e o Microsoft PC Manager, o concorrente gratuito e direto. As fontes estão no fim.

**O que esta revisão não viu:** nada rodou num Windows de verdade. As imagens são maquetes. A de "hoje" foi refeita a partir das cores e medidas do código; ela não é uma captura da janela. As maquetes usam a fonte Inter no lugar da Segoe UI, que não existe fora do Windows.

**Depois desta revisão:** as fases 1 e 2 do plano (itens 1 a 11) entraram na própria 4.0, na revisão R9 do `docs/historico-4.0.md`, e o que ainda faltava das propostas do designer (as transições dos botões e da chave, o botão no destaque, os contornos translúcidos, as cores dos detalhes técnicos, a entrelinha, o canto do seletor e o estilo de perigo), na R10. Ficaram de fora o item 12 (as capturas de tela, que pedem o Windows) e a fase 3 (a Mica e a arquitetura de páginas). O retrato de "hoje" abaixo é o da janela antes da R9.

**Correção (R9):** a janela tinha 13 tamanhos de fonte, e não 16. A lista do DS1 incluía 18, 20 e 26, que são tamanhos de ícone, e não de letra.

---

## Veredito

A base é sólida. O WinForge é honesto: não assusta, anota o que muda e deixa desfazer. Ele é acessível e coerente, e a nota de saúde já leva ao próximo passo. Para chegar ao "mais bonito de hoje", faltam duas coisas: **parecer um programa do Windows 11** e **falar menos**.

As três mudanças que mais rendem:
1. **Visual nativo do Windows 11, com a cor da marca.** A fonte, a escala de tamanhos e os cantos passam a ser os do Fluent 2. A Mica entra no Windows 11. O azul dos botões passa a vir da bigorna do ícone.
2. **Menos texto, mais leitura.** As páginas viram listas agrupadas, como as Configurações do Windows, com o item recomendado em destaque. Cada item fica com uma linha de descrição.
3. **Um Início que conta a história.** Primeiro a nota, depois o que fazer, por fim o que o WinForge já fez neste PC.

## Placar

De 1 (fraco) a 5 (no nível dos melhores).

| Critério | Nota | Por quê |
|---|---|---|
| Confiança e honestidade | 5 | Não assusta, não promete o que não faz, anota cada mudança e oferece desfazer onde há volta. É o diferencial do WinForge |
| Caminho principal | 4 | A nota de saúde leva ao próximo passo de cada ponto, e cada página tem um só destaque |
| Acessibilidade | 4 | O contraste foi medido e está escrito no código, o leitor de tela recebe nomes completos e o foco é visível. Faltam o contraste alto e o tamanho de texto do Windows |
| Hierarquia visual | 3 | Todos os cartões têm o mesmo peso. O destaque ajuda, mas 12 cartões iguais por página cansam |
| Consistência do sistema visual | 3 | São 13 tamanhos de fonte, 8 raios de canto e 6 estilos de botão |
| Marca | 3 | O ícone é forte, mas a cor dele não é a cor da interface |
| Quantidade de texto | 2 | 84 das 99 descrições visíveis passam de 60 caracteres, e o aviso de Administrador aparece escrito em até 37 cartões |
| Aparência nativa no Windows 11 | 2 | A paleta e os cantos são de Mac, a fonte é a Segoe UI antiga e não há Mica |
| Movimento e acabamento | 2 | Só a barra de progresso anima |

---

## Marketing — Gerente de Marketing Sênior

**MK1 — A marca não está na interface.** O azul da bigorna do ícone é `#5B91FF`, e o azul dos botões é outro: `#0071E3`, o azul da Apple. As cinzas da janela (`#F5F5F7` e `#1D1D1F`) também são as do macOS. Quem vê uma captura de tela não liga a janela ao ícone.
- **Proposta:** a cor de destaque sai da bigorna.
  - No tema claro, `#2B63D9`: texto branco sobre ele tem 5,4:1, e como texto sobre o fundo tem 4,9:1.
  - No tema escuro, o próprio `#5B91FF`, com texto escuro (5,8:1), como o Windows faz no modo escuro.

**MK2 — A promessa da 4.0 não aparece na tela.** "O WinForge avisa antes do problema" está no CHANGELOG, mas a janela não mostra o valor que o WinForge já entregou.
- **Proposta:** um bloco "Com o WinForge neste PC" no Início, com o espaço liberado nas manutenções, as manutenções feitas e as mudanças com desfazer.
- **Condição:** só com dados que o WinForge já guarda. O histórico de manutenções guarda as 20 últimas, então o texto precisa dizer "nas últimas" quando for o caso. Nada estimado.

**MK3 — "Build 4.0" no alto da barra lateral.** "Build" é palavra de quem desenvolve.
- **Proposta:** "Versão 4.0" na janela. O CHANGELOG pode continuar com "Build".

**MK4 — O diferencial é a honestidade, e ele deve ficar.** O PC Manager agrada pelos botões grandes e pela linguagem simples. Ao mesmo tempo, é criticado por não explicar o que fez e por avisos mais urgentes do que o problema. O WinForge já faz o contrário: o resultado diz o que mudou, e o Histórico de mudanças guarda o desfazer.
- **Proposta:** manter como está. Não acrescentar selos nem textos: o bloco do MK2 já conta essa história.

**MK5 — Verbos demais para "cuidar do PC".** No Início aparecem Otimizar, Verificar vírus e Verificar o PC; em Desempenho, Acelerar agora; em Limpeza, Limpeza rápida. "Verificar o PC" e "Verificar vírus" ficam lado a lado com o mesmo verbo e coisas diferentes.
- **Proposta:** a nota de saúde traz os dois caminhos de cuidado, **Verificar o PC** e **Otimizar**. Verificar vírus continua na página Segurança, e o cartão Proteção do Início já leva ao Estado da proteção, na mesma página.

**MK6 — Imagens para vender.** Um programa à venda precisa de capturas de tela iguais entre si: o mesmo PC de exemplo, claro e escuro, as mesmas telas.
- **Proposta:** fazer o conjunto depois das mudanças visuais da fase 2, não antes, para não refazer.

## Produto — Gerente de Produto Sênior

**PR1 — A barra lateral é longa e não tem grupos.** São o Início, 11 páginas e Sobre o WinForge no rodapé. Manutenção, Limpeza, Desempenho e Reparo se confundem na cabeça de quem usa.
- **Proposta rápida:** títulos de grupo na barra (Cuidar, Consertar, Proteger, Configurar), sem renomear nem mover nada. As 159 referências "Página > Item", a busca e o menu de texto continuam valendo.
- **Reorganizar as páginas** (juntar, renomear) só depois de um teste de árvore com 5 a 8 pessoas. A ideia é ver onde cada pessoa procura "limpar a pasta Downloads", "senha do Wi-Fi" e "desfazer um ajuste".

**PR2 — O Início tem cinco blocos.** São os avisos, "Deixe o WinForge pronto", a nota de saúde, "Seu PC" e "Por onde começar". "Por onde começar" repete caminhos que a nota e a barra lateral já dão.
- **Proposta:**
  - "Deixe o WinForge pronto" vira uma faixa de uma linha: "1 de 3 feitos", o botão do próximo passo e "Agora não";
  - "Por onde começar" sai;
  - entra "Com o WinForge neste PC" (MK2).
- **Manter** a regra de hoje para o botão principal da nota: com pontos de atenção, o destaque é o botão do primeiro ponto; sem pontos, é o Otimizar.

**PR3 — Oito botões no alto de Ajustes do Windows.** Aplicar ajustes recomendados, Perfis, Teclas que trocam o idioma, Notificações (↗), Criar ponto de restauração, Exportar, Importar e Desfazer aparecem antes da lista, em mais de uma fileira.
- **Proposta:** um botão em destaque (Aplicar ajustes recomendados) e um "Mais opções" com o resto. "Teclas que trocam o idioma do teclado" vira uma linha da lista, como os outros ajustes.

**PR4 — Os 18 atalhos para o Windows pesam como funções.** Eles já ficam no último grupo de cada página, mas com o mesmo cartão grande.
- **Proposta:** na lista, cada atalho é uma linha com ↗ no fim, sempre no último grupo.

**PR5 — Toda mudança de navegação tem custo.** Ela passa pela busca (com sinônimos nos três idiomas), pelas 159 referências, pelo menu de texto, pelo README, pelo CHANGELOG e pelas traduções. Por isso o plano começa pelos grupos, que não mexem em nada disso.

**PR6 — Medir antes e depois, sem coletar uso.** O WinForge não coleta dados de uso, e não deve coletar sem consentimento.
- **Proposta:** o mesmo roteiro com 5 pessoas antes e depois de cada fase, com tarefas curtas (achar, fazer, desfazer), anotando tempo e erros.

## Design — Designer Sênior

**DS1 — Tipografia.** A janela usa Segoe UI e 13 tamanhos de fonte: 11, 12, 12,5, 13, 13,5, 14, 15, 16, 17, 19, 22, 28 e 36. O Windows 11 usa a Segoe UI Variable e uma escala curta.
- **Proposta:** Segoe UI Variable no Windows 11, com volta para a Segoe UI no Windows 10, e cinco tamanhos:
  - 12/16 para legendas;
  - 14/20 para texto (semibold para títulos de linha);
  - 18/24 para texto grande;
  - 20/28 para subtítulos;
  - 28/36 para o título da página (que já é 28).
- **A conferir num PC:** como o WPF do Windows PowerShell 5.1 escolhe a variação "Segoe UI Variable Text".

**DS2 — Cores.** As cinzas de hoje são as do macOS.
- **Proposta:**
  - as bases do Windows 11: fundo `#F3F3F3` e cartões brancos no claro; fundo `#202020` e cartões `#2B2B2B` no escuro;
  - linhas com transparência, em vez de cinza sólido;
  - os tons de estado do Windows no tema claro (verde `#0F7B0F`, aviso `#9D5D00`, erro `#C42B1C`);
  - no escuro, o aviso em laranja (`#F5A524`) em vez do amarelo do Windows, que fica áspero no anel da nota.
- **Manter** a regra de contraste já escrita em `GuiDesign.psm1`: todo texto acima de 4,5:1 e todo contorno de controle acima de 3:1.

**DS3 — Cantos.** Hoje são 5, 7, 8, 9, 10, 12, 14 (os botões em pílula) e 16.
- **Proposta:** 4 nos controles (botões, campos e itens da barra lateral) e 8 nos cartões e painéis. Os botões em pílula viram retângulos de canto 4, como no Windows 11.

**DS4 — Botões.** São seis estilos (Primary, Pill, Ghost, Danger, Option e Segment), além dos de cartão e de navegação.
- **Proposta:** três estilos, como no Windows: destaque, padrão e sutil. O de perigo fica só onde algo é apagado sem volta.

**DS5 — Material.** O fundo é uma cor sólida, e a barra lateral tem cor própria. A barra de título já acompanha o tema, o que é bom.
- **Proposta:** Mica no fundo da janela, no Windows 11 22H2 ou mais novo (o atributo 38 do DWM, valor 2), com a barra lateral sobre o mesmo fundo, sem cor própria. No Windows 10, ou com a transparência desligada, o fundo continua sólido.
- **Risco técnico:** no WPF do Windows PowerShell 5.1 isso pede o `WindowChrome`, que muda as bordas da janela. É um estudo à parte, não uma mudança para a 4.0.

**DS6 — Os cartões de ação.** Cada um tem 148 px de altura mínima, um quadrado azul de 38 px, título de 15 e descrição de 13 em até três linhas. Isolado, o cartão é bonito; em 12 por página, vira uma parede de quadrados azuis.
- **Proposta** (maquete "Limpeza"):
  - o item recomendado vira um destaque, com o botão de fazer ali mesmo;
  - o resto vira linhas de 64 px agrupadas, com ícone de traço sem quadrado, uma linha de descrição e, no fim, o escudo de Administrador e › ou ↗.
- **A troca, sem exagero:** a altura da página fica parecida (na maquete, de 1.066 para 1.092 px). O ganho é outro: leitura em uma coluna, metade do texto e o mesmo jeito das Configurações do Windows. Os cartões grandes ficam no Início.

**DS7 — Movimento.** Hoje só a barra de progresso anima.
- **Proposta:**
  - a página entra com opacidade e 8 px de deslocamento, em cerca de 170 ms;
  - a chave e os botões mudam de estado em cerca de 80 ms;
  - a faixa do resultado entra deslizando.
- Tudo desligado quando a opção "Efeitos de animação" do Windows estiver desligada.

**DS8 — Ícones.** O conjunto próprio, de traço, numa grade de 24 e com pontas redondas, combina com o Fluent. Manter.

**DS9 — Ícone do programa.** A bigorna sobre o quadrado grafite funciona de 16 a 256 px. Manter, e usar a cor dela na interface (MK1).

## UX/UI — Analista de UX/UI Sênior

**UX1 — Texto demais nos cartões.** 84 das 99 descrições visíveis passam de 60 caracteres. O Windows 11 recomenda linhas de 50 a 60.
- **Proposta:** uma linha de descrição, de até uns 55 caracteres. O detalhe vai para a tela da ação, que já explica antes de fazer.
- **Exemplos da página Limpeza:**

| Item | Hoje | Proposta |
|---|---|---|
| Analisar uso de espaço | Mostra o que a limpeza libera, as maiores pastas do perfil e os arquivos grandes do sistema | O que ocupa o disco e quanto a limpeza libera |
| Limpeza personalizada | Você marca numa lista, com o tamanho de cada item: temporários, caches, despejos de falhas, Lixeira | Escolha item por item, vendo o tamanho de cada um |
| Restos de programas desinstalados | Pastas que sobraram de programas desinstalados pelo WinForge; você escolhe o que vai para a Lixeira | Pastas que ficaram depois de desinstalar |
| Apagar o espaço livre | Sobrescreve o espaço livre do disco: o que já foi apagado não pode mais ser trazido de volta | Impede recuperar o que já foi apagado |

**UX2 — O aviso de Administrador escrito.** "Pede Administrador ao executar" aparece em até 37 cartões, quando a janela abre sem Administrador. No Windows, a convenção é o escudo no próprio botão ou na linha.
- **Proposta:** só o escudo. O texto fica no nome lido pelo leitor de tela, que já o tem, e passa a aparecer na dica, ao passar o mouse.

**UX3 — O contraste alto do Windows não é seguido.** Com um tema de contraste do Windows ligado, a janela continua com as próprias cores. Para um programa à venda, isso é requisito de acessibilidade.
- **Proposta:** com o contraste alto ligado, usar as cores do sistema e contornos de 1 px em tudo o que é clicável.

**UX4 — O tamanho do texto do Windows não é seguido.** A opção Acessibilidade > Tamanho do texto não muda a janela do WinForge.
- **Proposta:** ler o fator escolhido e aumentar as fontes junto.
- **A conferir num PC:** a 150%, cartões, linhas e a tela de execução precisam continuar inteiros.

**UX5 — Carregamento escrito.** Os cartões do Início mostram "Lendo..." até cada leitura chegar.
- **Proposta:** um esqueleto, com barras cinza do tamanho do conteúdo e sem texto. O valor entra no lugar sem a tela pular.

**UX6 — A tela de execução está no nível dos melhores. Manter.** Ela mostra o estado e o tempo, a pergunta na própria tela e o resultado com o próximo passo. Os detalhes técnicos ficam fechados, com Copiar, Salvar e Abrir log.

**UX7 — A busca está no nível dos melhores. Manter.** O Ctrl+K entende sinônimos nos três idiomas, e o Enter abre o primeiro resultado.

**UX8 — Os outros idiomas são mais longos.** Os textos em inglês e espanhol costumam ficar de 20% a 30% mais compridos. Com uma linha de descrição, reticências e o texto inteiro na dica (como os cartões do Início já fazem), o risco de cortar cai.
- **Proposta:** conferir cada tela nova em espanhol, que costuma ser o idioma mais longo.

**UX9 — Teclado e foco: manter.** Os atalhos das páginas, o Esc, o F5 e o foco visível de 2 px já estão no nível dos melhores.

---

## O que não mudar

- A honestidade: só o que o WinForge faz de verdade, sem susto e com desfazer onde há volta.
- A nota de saúde com o botão de cada ponto, e a regra de um só destaque por tela.
- A tela de execução, com os detalhes técnicos fechados.
- A busca.
- A barra de título na cor do tema.
- O que já foi feito em acessibilidade: o contraste medido, os nomes para o leitor de tela e o foco visível.

## Plano

Esforço: P (pequeno), M (médio) ou G (grande). Risco é a chance de quebrar algo que funciona hoje.

**Fase 1 — rápida e de baixo risco** (cabe numa versão depois da 4.0)

| # | O quê | De onde | Esforço | Risco |
|---|---|---|---|---|
| 1 | Segoe UI Variable, com volta para a Segoe UI, e a escala de cinco tamanhos | DS1 | M | Baixo |
| 2 | Só o escudo no lugar de "Pede Administrador ao executar" | UX2 | P | Baixo |
| 3 | "Versão 4.0" na barra lateral | MK3 | P | Baixo |
| 4 | Títulos de grupo na barra lateral, sem mover páginas | PR1 | P | Baixo |
| 5 | Ajustes do Windows com um botão em destaque e "Mais opções" | PR3 | M | Baixo |
| 6 | Contraste alto e tamanho do texto do Windows | UX3, UX4 | M | Médio |
| 7 | Movimento sutil, que respeita a opção do Windows | DS7 | M | Baixo |

**Fase 2 — muda o visual**

| # | O quê | De onde | Esforço | Risco |
|---|---|---|---|---|
| 8 | Cores do Windows 11 com o azul da marca; cantos 4 e 8; três estilos de botão | MK1, DS2, DS3, DS4 | M | Médio |
| 9 | Páginas em lista agrupada, com o recomendado em destaque, e as 99 descrições reescritas em uma linha nos três idiomas | DS6, UX1, PR4 | G | Médio |
| 10 | Início novo: faixa "Deixe o WinForge pronto", "Com o WinForge neste PC", sem "Por onde começar", com esqueletos | PR2, MK2, UX5 | M | Médio |
| 11 | Os dois caminhos na nota: Verificar o PC e Otimizar | MK5 | P | Baixo |
| 12 | Capturas de tela para vender, das telas novas | MK6 | P | — |

**Fase 3 — estudo antes de decidir**

| # | O quê | De onde | Esforço | Risco |
|---|---|---|---|---|
| 13 | Mica no Windows 11, com o `WindowChrome` do WPF no PowerShell 5.1 e o Windows 10 sem Mica | DS5 | G | Alto |
| 14 | Arquitetura de páginas (juntar ou renomear), depois do teste de árvore | PR1, PR5, PR6 | G | Alto |

## As maquetes

As cinco imagens desta revisão ficam em `docs/revisao-interface/`. Elas usam os nomes reais da página Limpeza, com as descrições encurtadas da UX1, e números de exemplo no Início.

| Imagem | O que mostra |
|---|---|
| `limpeza-hoje.png` | A página Limpeza como ela é hoje, refeita a partir das cores e medidas do código |
| `limpeza-proposta.png` | A mesma página na proposta: destaque, listas agrupadas, barra lateral com grupos, cores e cantos do Windows 11 |
| `limpeza-proposta-escuro.png` | A proposta no tema escuro, com o azul da bigorna nos botões |
| `inicio-proposta.png` | O Início na proposta: nota com os dois caminhos, faixa "Deixe o WinForge pronto", "Seu PC" e "Com o WinForge neste PC" |
| `inicio-proposta-escuro.png` | O Início na proposta, no tema escuro |

## Fontes

- [Typography in Windows 11 — Microsoft Learn](https://learn.microsoft.com/windows/apps/design/signature-experiences/typography): a Segoe UI Variable, a escala de tamanhos, a caixa de frase e as linhas de 50 a 60 caracteres.
- [Applying Mica to WPF — tvc-16.science](https://tvc-16.science/mica-wpf.html): o atributo 38 do DWM, o `WindowChrome` e os limites no Windows 10.
- [Data Doctors: Should I be using Microsoft PC Manager? — WTOP, janeiro de 2026](https://wtop.com/tech/2026/01/data-doctors-should-i-be-using-microsoft-pc-manager): botões grandes e linguagem simples, mas sem explicar o que mudou e com avisos mais urgentes que o problema.
