# WinForge 4.0 — revisão de todos os arquivos (R29)

**Data:** 20/11/2026 · **Versão:** Build 4.0 em preparação, depois da R28

**Pedido:** "Revise todos os arquivos do projeto. Scripts, docs, files, códigos."

**Resultado:** 6 achados, todos corrigidos. Nenhum muda o que o WinForge faz no PC: o código do programa já tinha passado por duas revisões de engenharia (R7 e R12) e por uma revisão de cada tela (R13 a R28), e as varreduras desta revisão não acharam nada novo nele. Os achados estão nas ferramentas, nos documentos e nas regras dos arquivos.

| Onde | Achados |
|---|---|
| Ferramentas | 2: o zip da versão só podia ser montado fora do repositório; e o SHA256SUMS.txt da assinatura não batia com o zip |
| Documentos | 3: o mapa de funcionalidades com três pontos velhos; o mapa de melhorias com a proposta da 4.0 "ainda não decidida"; os READMEs sem a ferramenta nova |
| Regras dos arquivos | 1: o `.editorconfig` pedia CRLF para os três arquivos do git, que são LF |

Nada rodou num Windows de verdade. A ferramenta nova foi conferida na nuvem, no PowerShell 7; ela entrou no roteiro para rodar uma vez no Windows PowerShell 5.1 antes de publicar.

## O que foi revisto

São 88 arquivos no git, mais a ferramenta nova:

| Tipo | Arquivos | Como foi revisto |
|---|---|---|
| Código do programa | 38 módulos, `Modules.psd1`, os 4 scripts de entrada (janela, menu de texto, monitor e instalador) e a janela (`gui/MainWindow.xaml`), cerca de 60 mil linhas | As varreduras da R12 de novo, sobre o código de hoje, e o analisador do PowerShell comparado com o da R12. Leitura dirigida do que nenhuma revisão de tela leu, como a reabertura como Administrador e os argumentos de cada programa aberto. |
| Os 3 `.cmd` | `WinForge.cmd`, `WinForge-Console.cmd` e `WinForge-Setup.cmd` | Lidos inteiros. |
| Ferramentas | `tools/Sign-WinForge.ps1`, `tools/Update-WinForgeTranslations.ps1` e o modelo `tools/WinForge.pot` | Lidas; a de traduções rodou. |
| Dados | as traduções (`lang/*.po`), o catálogo (`catalog/catalog.json`) e os ícones (`assets/`) | As traduções conferidas contra o código; o catálogo, pelo formato e pelas datas. |
| Documentos | os três READMEs, o CHANGELOG (a 4.0 inteira), os 20 documentos de `docs/` (e as 5 maquetes da revisão da interface) e a licença | Conferidos contra o código: os números, os nomes das telas, as funções citadas, os links e as âncoras. |
| Regras | `.editorconfig`, `.gitattributes` e `.gitignore` | Cada arquivo conferido contra elas: o BOM, o fim de linha, a nova linha no fim e os espaços sobrando. |
| Projeto WinForge no Claude | os 23 documentos | Conferidos contra os do repositório; o mapa de melhorias, que só existe lá, conferido contra o histórico. |

## Achados

| # | Onde | O que estava | Como ficou |
|---|---|---|---|
| A1 | Ferramentas | O `WinForge.zip` de cada entrega era montado por um script fora do repositório. Nenhuma ferramenta do projeto fazia o zip como o CHANGELOG promete: com os arquivos que o instalador troca e o CHANGELOG das cinco builds mais recentes. Quem montasse o zip à mão levaria docs, ferramentas e o CHANGELOG inteiro. | **`tools/New-WinForgePackage.ps1` (nova):** monta o `dist\WinForge.zip` com a mesma lista de arquivos que o instalador usa (`Get-WinForgePackageFiles`, do Install.psm1), o CHANGELOG das cinco builds e o link para o histórico, e o `SHA256SUMS.txt` feito dos arquivos como estão no zip. No fim, mostra o SHA-256 do zip, que vai na página da versão. |
| A2 | Ferramentas | O `tools/Sign-WinForge.ps1` gravava um `SHA256SUMS.txt` de tudo o que havia na pasta. Ele incluía docs, ferramentas e os arquivos do git, que não vão para o PC, e o CHANGELOG inteiro, que não é o do zip. | Ele só assina. O `SHA256SUMS.txt` sai da ferramenta do zip, e o fim da assinatura diz para montá-lo. |
| A3 | `docs/funcionalidades-4.0.md` | Três pontos velhos: a frase de Versão e pastas era a de antes da R25; a conta dos textos dizia 5.179 (são 5.344); e o Otimizar não levava a lugar nenhum, embora a faixa tenha o botão desde a R28. | Corrigidos, com uma linha no alto dizendo o que foi conferido de novo. Os 102 itens, as frases, os grupos e o Administrador de cada um batem com o código. |
| A4 | `claude/mapa-de-melhorias.md` (só no projeto) | A proposta da 4.0 aparecia como "ainda não decidida", e o F10 dizia que o instalador ainda não existe. | Ganhou a situação de hoje no alto: o que foi feito, o que falta antes de anunciar e o que não foi feito. O resto ficou como foi escrito, sobre a 3.69. |
| A5 | READMEs | "`tools/`: assinatura e traduções". | "assinatura, o zip da versão e traduções", nos três idiomas. |
| A6 | `.editorconfig` | `[*]` pede CRLF, e os três arquivos do git (`.gitattributes`, `.gitignore` e o próprio `.editorconfig`) são LF. Um editor que segue a regra os trocaria para CRLF ao salvar. | Uma seção própria, com LF, e as mesmas três linhas no `.gitattributes`. |

Também ficaram em dia as referências de linha das traduções (os comentários `#:` dos `.po` e do `.pot`): a última mudança da R28 tinha mexido nas linhas do Maintenance.psm1 depois da atualização delas. Nenhum texto mudou.

## Conferido e mantido

**No código** (a varredura e o que ela achou):
- **o que só existe no PowerShell 7:** nada, nos 38 módulos, nos scripts e nas ferramentas;
- **as consultas ao WMI:** as 42 têm tempo-limite e estão num `try`;
- **o C# compilado:** só C# 5, o do Windows PowerShell 5.1;
- **`break` e `continue`** dentro de um `ForEach-Object`, e **`$_` dentro de um `catch`:** nenhum;
- **estado sem uso:** só dois avisos, e nenhum é real. A trava da janela guarda o mutex para ele não ser descartado. A bateria é lida por `Get-Variable`, que a varredura não enxerga;
- **o analisador do PowerShell:** os mesmos 224 avisos da R12, todos já explicados na R7: os 74 de variável automática são o `$sender` e o `$eventArgs` dos eventos da janela;
- **nada de TODO, código comentado, caminho de disco escrito no código** (fora as reservas do `C:\Windows` e do `C:\ProgramData` quando a variável do Windows falta), **espaço sobrando ou tabulação;**
- **os argumentos dos programas abertos:** cada caminho vai entre aspas (`ConvertTo-WinForgeCommandLineArgument`), também na reabertura como Administrador com uma pasta de relatório que tem espaço;
- **`Modules.psd1`:** os 38 módulos, nem um a mais nem a menos;
- **a versão:** "4.0" num lugar só (`$script:WinForgeBuild`), que o instalador, a atualização e o Setup leem.

**Nos `.cmd`:**
- os três avisam nos três idiomas quando falta um arquivo;
- usam o PowerShell de 64 bits mesmo abertos por um programa de 32 bits;
- o `WinForge-Console.cmd` só não pausa nem desbloqueia na verificação rápida quando `-Action Check` vem primeiro, como o comentário dele diz e os READMEs mostram. Ler os argumentos em qualquer ordem pediria um laço no `.cmd` que não dá para conferir daqui. Fica como está, e o exemplo dos READMEs já está na ordem certa.

**Nos documentos:**
- **os READMEs** dizem o mesmo nos três idiomas, e os nomes das telas que eles citam são os da tradução;
- **o CHANGELOG da 4.0** não se contradiz depois das 16 revisões de tela;
- **nenhum link ou âncora quebrado** nos 24 documentos;
- **as funções citadas que não existem mais** aparecem só onde o texto diz que saíram ou mudaram de nome;
- **os documentos do projeto no Claude** batem com os do repositório. A cada revisão eles foram gravados a partir do repositório.

## Testes

**Como foi testado:**
- **A ferramenta do zip**, numa cópia do repositório com o que um PC de desenvolvedor costuma ter: um `Thumbs.db` nos ícones, um `desktop.ini` e um `SHA256SUMS.txt` velho. Foram 11 conferências:
  - o zip leva exatamente os arquivos que o instalador gerencia, mais o `SHA256SUMS.txt`;
  - nada de docs, ferramentas, arquivos do git, nem o `Thumbs.db` e o `desktop.ini`;
  - tudo dentro da pasta WinForge, com a barra "/";
  - cada arquivo igual, byte a byte, ao do repositório;
  - o CHANGELOG com as cinco builds mais recentes e o link;
  - o `SHA256SUMS.txt` conferindo com o zip, e não com o velho;
  - o zip passando pela mesma extração conferida da atualização com um clique e virando uma pasta do WinForge 4.0;
  - o SHA-256 que ela mostra é o do arquivo.
- **O zip da ferramenta comparado com o das entregas anteriores:** os mesmos 56 arquivos, com o mesmo conteúdo, mais o `SHA256SUMS.txt`.
- **A assinatura**, com o `Set-AuthenticodeSignature` simulado: assina todos os scripts, não grava mais o `SHA256SUMS.txt` e diz para montar o zip.
- **Os documentos e os arquivos, em 139 conferências:**
  - o mapa de funcionalidades item por item, contra a navegação do código, e os números do alto dele;
  - a conta de textos do CHANGELOG;
  - os READMEs;
  - os links e as âncoras;
  - o formato de cada arquivo contra o `.editorconfig` e o `.gitattributes`.

Cada conferência das correções falha nos arquivos de antes e passa nos de agora.

- **As de antes continuam passando.** O código do programa só mudou num comentário, então rodaram de novo as baterias que pegam o programa inteiro:
  - as 146, 151 e 151 do Otimizar;
  - as 243, 245 e 250 da Manutenção e as 241 do Início nos três idiomas;
  - as 83 do QA geral, as 80 da R11 e as 60 da R12;
  - as 59 da R9 e as 52 da R10, as 66 da QA, as 28 da integração e as 26 da R7;
  - o motor de instalação, a atualização simulada e o Setup de verdade (da R28 para esta, com o zip da ferramenta nova), e o pacote de suporte;
  - as traduções (5.344/5.344), as 159 referências nos três idiomas e a busca dos 102 itens;
  - nenhuma chamada com parâmetro que não existe, nenhuma função sem uso e nenhum aviso novo do analisador.

  As baterias de cada tela (R15 a R27) não rodaram de novo: os módulos delas não mudaram desde a R28, quando todas passaram.

## O que só um PC mostra

Isto entrou no roteiro de conferência:
- **a ferramenta do zip no Windows PowerShell 5.1:** montar o zip, conferir no Explorador que tudo está dentro da pasta WinForge, instalar por ele e comparar o SHA-256 que ela mostra com o `Get-FileHash` do arquivo.
