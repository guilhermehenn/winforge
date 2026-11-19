<p align="center">
  <img src="assets/WinForge.svg" width="96" height="96" alt="Ícone do WinForge">
</p>

# WinForge

O **WinForge** é uma ferramenta open-source para manutenção, diagnóstico e gerenciamento do Windows. Desenvolvido em PowerShell, reúne recursos do sistema em uma interface gráfica e em um menu de terminal.

[Baixar a versão mais recente](https://github.com/guilhermehenn/winforge/releases/latest/download/WinForge.zip) · [Ver todas as versões](https://github.com/guilhermehenn/winforge/releases) · [Guia detalhado da build 3.69](https://github.com/guilhermehenn/winforge/blob/v3.69.0/README.md)

## O que você pode fazer

- **Diagnosticar o PC:** consultar informações do Windows, hardware, discos, rede, bateria e proteção.
- **Cuidar do sistema:** usar a verificação do PC, a manutenção guiada e ferramentas de reparo como DISM, SFC e CHKDSK.
- **Liberar espaço:** analisar o armazenamento e acessar opções de limpeza, arquivos duplicados e atalhos quebrados.
- **Gerenciar programas:** instalar, atualizar e remover aplicativos com o winget e revisar itens de inicialização.
- **Atualizar o Windows:** consultar atualizações e drivers disponíveis e acompanhar a instalação pela interface.
- **Acompanhar a segurança:** consultar o estado da proteção e usar as verificações do Windows Defender.
- **Personalizar o Windows:** aplicar ajustes e desfazer os que oferecem suporte à reversão.
- **Acompanhar o histórico:** gerar relatórios, consultar mudanças e, se desejar, habilitar a manutenção agendada ou o monitor na bandeja.

O WinForge reúne ferramentas do Windows e ações próprias. Algumas operações alteram configurações ou removem arquivos; confira as opções apresentadas antes de executá-las.

## Requisitos

- Windows 10 ou Windows 11.
- Windows PowerShell 5.1, incluído no Windows 10 e 11.
- Permissão de administrador para funções que precisam alterar ou consultar partes protegidas do sistema.
- [winget](https://learn.microsoft.com/pt-br/windows/package-manager/winget/) para os recursos de gerenciamento de programas.
- Conexão com a internet para downloads, atualizações e demais recursos online.

## Download e primeiros passos

1. Baixe **WinForge.zip** pela [release mais recente](https://github.com/guilhermehenn/winforge/releases/latest).
2. Confira se o arquivo veio do repositório oficial. Para verificar a integridade, compare o SHA-256 do ZIP com o informado junto ao arquivo na release:

   ```powershell
   Get-FileHash -LiteralPath "$env:USERPROFILE\Downloads\WinForge.zip" -Algorithm SHA256
   ```

   Se o arquivo estiver em outra pasta, ajuste o caminho no comando.

3. Nas propriedades do ZIP, marque **Desbloquear** se a opção aparecer e você confiar na origem do arquivo.
4. Extraia a pasta inteira. Uma opção é extrair para `C:\Program Files`, criando `C:\Program Files\WinForge`; o Windows pode pedir permissão para gravar nesse local.
5. Abra **WinForge.cmd** para a interface gráfica ou **WinForge-Console.cmd** para o menu de terminal.
6. Leia o pedido de permissão do Windows. A janela pode abrir sem administrador se o pedido for recusado; funções que precisarem de elevação poderão solicitá-la novamente.

Não execute os arquivos de dentro do ZIP: o WinForge precisa da estrutura completa de pastas.

## Segurança e dados

- **Permissões:** ações de limpeza, reparo, atualização e ajustes podem alterar o sistema. Mantenha seus backups e confira o que será executado; nem toda ação pode ser desfeita.
- **Inicialização:** os lançadores `.cmd` iniciam o PowerShell com `ExecutionPolicy Bypass` para o processo e, ao abrir a janela ou o menu, removem recursivamente o bloqueio de arquivos baixados dentro da pasta do WinForge. Use uma pasta exclusiva para o aplicativo e confira a origem dos arquivos.
- **Assinatura:** os scripts da versão 3.69 não estão assinados digitalmente. O Windows pode apresentar avisos ao abrir arquivos baixados.
- **Dados locais:** logs, relatórios e arquivos de estado ficam principalmente em `%LOCALAPPDATA%\WinForge`. Relatórios e logs podem conter informações do computador; confira seu conteúdo antes de compartilhá-los.
- **Recursos online:** algumas funções acessam serviços externos, como GitHub, winget, Windows Update e serviços de rede. O monitor na bandeja e a manutenção agendada são opcionais.
- **Backup antes de formatar:** o recurso pode guardar lista de programas, drivers, ajustes e, opcionalmente, redes Wi-Fi. Ele **não copia documentos, fotos ou outros arquivos pessoais**. Se você incluir redes Wi-Fi, as senhas são armazenadas em texto puro; proteja o backup.

## Atualizar o WinForge

Em **Sobre o WinForge > Verificar nova versão**, o aplicativo consulta a release mais recente e pode baixar o ZIP, conferindo seu SHA-256. A substituição dos arquivos é manual.

Para atualizar uma cópia existente, feche o WinForge e o monitor na bandeja, se estiver aberto. Extraia a nova versão em outra pasta e copie o conteúdo da pasta `WinForge` extraída para a pasta da instalação anterior, substituindo os arquivos. Mantenha a estrutura de pastas completa.

Os dados locais ficam em `%LOCALAPPDATA%\WinForge`; não apague essa pasta se quiser preservar logs, histórico e backups. Se você mover a pasta do programa, confira seus atalhos e o agendamento, caso estejam configurados.

## Linha de comando

No PowerShell, dentro da pasta do WinForge:

```powershell
.\WinForge-Console.cmd -Action Check        # verificação rápida
.\WinForge-Console.cmd -Action Check -Json  # saída em JSON
.\WinForge-Console.cmd -Action Report       # relatório HTML e texto
```

A ação `Check` faz consultas e não exige administrador; algumas informações podem ficar indisponíveis sem elevação.

## Como relatar um problema

[Abra uma issue](https://github.com/guilhermehenn/winforge/issues/new)
informando:

- Versão do WinForge.
- Versão e build do Windows.
- Interface utilizada: gráfica ou terminal.
- Função executada e passos para reproduzir o problema.
- Resultado esperado e o que aconteceu.
- Mensagem de erro completa ou captura de tela.

Se compartilhar logs ou relatórios de
`%LOCALAPPDATA%\WinForge`, confira o conteúdo
e remova informações pessoais antes de enviar.

## Documentação e projeto

- [Guia detalhado da build 3.69](https://github.com/guilhermehenn/winforge/blob/v3.69.0/README.md) — referência arquivada da versão publicada; pode não refletir versões posteriores.
- [Histórico de mudanças](CHANGELOG.md) e [releases](https://github.com/guilhermehenn/winforge/releases).
- `WinForge.Gui.ps1` e `gui/`: interface gráfica.
- `WinForge.Console.ps1`: interface de terminal.
- `modules/`: funcionalidades compartilhadas; `assets/`: ícones.

## Licença

Distribuído sob a licença [GNU GPLv3](LICENSE).

© 2026 Guilherme Henn
