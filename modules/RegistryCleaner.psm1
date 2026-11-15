# Limpeza do registro: remove só referências quebradas, isto é, entradas que apontam para arquivos que não existem mais
# (programas desinstalados que deixaram a entrada para trás, atalhos de inicialização para um .exe apagado...).
#
# É uma limpeza conservadora de propósito. Nada é removido sem backup (um .reg das chaves inteiras e um .json dos valores
# soltos), e o backup desfaz tudo pelo Histórico de mudanças. O WinForge não promete deixar o PC mais rápido com isso: o ganho é um registro sem referências
# quebradas e listas (inicialização, Aplicativos instalados) sem entradas fantasmas.


# ---------------------------------------------------------------------------
# Caminhos e comandos
# ---------------------------------------------------------------------------

function Get-WinForgeWow64PathVariants {
    <#
    Onde um caminho gravado por um programa de 32 bits fica de fato num Windows de 64 bits. Para ele, System32 é a pasta
    SysWOW64, Sysnative é a System32 de verdade e Arquivos de Programas (também %ProgramFiles% e %CommonProgramFiles%) é
    "Program Files (x86)". Devolve só os caminhos traduzidos (sem o original); vazio quando nenhuma tradução se aplica.
    #>
    param (
        [AllowEmptyString()][string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) { return @() }

    $expanded = [Environment]::ExpandEnvironmentVariables($Path.Trim().Trim('"'))
    $pairs = @()

    $windows = $(if (-not [string]::IsNullOrWhiteSpace($env:WINDIR)) { $env:WINDIR } else { $env:SystemRoot })

    if (-not [string]::IsNullOrWhiteSpace($windows)) {
        $windows = $windows.TrimEnd('\')
        $pairs += , @("$windows\System32", "$windows\SysWOW64")
        $pairs += , @("$windows\Sysnative", "$windows\System32")
    }

    # ProgramW6432 é sempre a pasta de 64 bits, mesmo quando ProgramFiles já foi traduzida para a de 32.
    $programFiles = $(if (-not [string]::IsNullOrWhiteSpace($env:ProgramW6432)) { $env:ProgramW6432 } else { $env:ProgramFiles })
    $programFilesX86 = ${env:ProgramFiles(x86)}

    if (-not [string]::IsNullOrWhiteSpace($programFiles) -and -not [string]::IsNullOrWhiteSpace($programFilesX86) -and
        -not [string]::Equals($programFiles.TrimEnd('\'), $programFilesX86.TrimEnd('\'), [StringComparison]::OrdinalIgnoreCase)) {
        $pairs += , @($programFiles.TrimEnd('\'), $programFilesX86.TrimEnd('\'))
    }

    $variants = @()

    foreach ($pair in $pairs) {
        $from = [string]$pair[0]

        if ($expanded.StartsWith($from + "\", [StringComparison]::OrdinalIgnoreCase)) {
            $variants += ([string]$pair[1] + $expanded.Substring($from.Length))
        }
    }

    return @($variants)
}


function Test-WinForgeLocalPathMissing {
    <#
    Verdadeiro só quando o caminho é um arquivo local (C:\...) numa unidade que o Windows vê como disco fixo e o arquivo
    não existe. Caminho de rede, de uma unidade que não está ligada ou que não é disco fixo (pendrive, cartão, DVD,
    unidade de rede mapeada: a letra pode ser hoje de outro aparelho, e a pasta de rede pode só estar fora do ar) ou que
    não dá para entender (aspas e argumentos no meio, caracteres que um caminho não tem) fica como "não sei": falso.
    Um HD externo USB costuma aparecer como disco fixo: desconectado, a letra some e o caminho fica como "não sei"; com
    outro disco na mesma letra, não há como distinguir.
    -Wow64: a entrada pode ter sido gravada por um programa de 32 bits (chaves WOW6432Node e as do usuário, que os dois
    lados compartilham); só falta quando não existe nem no caminho escrito nem na tradução de 32 bits
    (Get-WinForgeWow64PathVariants). Sem isso, uma DLL registrada em System32 por um instalador de 32 bits, que está na
    verdade em SysWOW64, pareceria apagada.
    #>
    param (
        [AllowEmptyString()][string]$Path,

        [switch]$Wow64
    )

    if ([string]::IsNullOrWhiteSpace($Path)) { return $false }

    $expanded = [Environment]::ExpandEnvironmentVariables($Path.Trim().Trim('"'))

    if ($expanded -notmatch '^[A-Za-z]:\\') { return $false }
    if ($expanded -match '[%"<>|*?]' -or $expanded.IndexOf(':', 2) -ge 0) { return $false }

    $drive = $expanded.Substring(0, 3)

    if ((Get-WinForgeDriveType -Root $drive) -ne "Fixed") { return $false }
    if (-not (Test-Path -LiteralPath $drive -PathType Container)) { return $false }

    if (Test-Path -LiteralPath $expanded) { return $false }

    if ($Wow64) {
        foreach ($variant in @(Get-WinForgeWow64PathVariants -Path $expanded)) {
            if (Test-Path -LiteralPath $variant) { return $false }
        }
    }

    return $true
}


function Test-WinForgeRegistryViewMismatch {
    # Verdadeiro quando o WinForge roda num PowerShell de 32 bits num Windows de 64 bits: aí o Windows troca, por baixo,
    # o registro (SOFTWARE vira WOW6432Node) e as pastas do sistema (System32 vira SysWOW64), e a busca de referências
    # quebradas olharia as chaves e os arquivos errados.
    return ([Environment]::Is64BitOperatingSystem -and -not [Environment]::Is64BitProcess)
}


function Get-WinForgeRegistryViewMismatchText {
    return "o WinForge está aberto num PowerShell de 32 bits, que enxerga outra parte do registro e das pastas do sistema; feche e abra de novo pelo atalho do WinForge"
}


function Test-WinForgeRegistryRootShared {
    # Chaves que um programa de 32 bits também grava (as WOW6432Node e as do usuário, que os dois lados compartilham):
    # nelas, os caminhos são conferidos também na tradução de 32 bits.
    param ([Parameter(Mandatory)][string]$Root)

    return ($Root -like "*\WOW6432Node\*" -or $Root -like "HKCU:*")
}


function Get-WinForgeCommandTargetPath {
    <#
    O arquivo que uma linha de comando executa: "C:\App\app.exe" --min, C:\App\app.exe /x ou rundll32.exe C:\x.dll,Entry
    (aí, a DLL). Devolve "" quando não dá para saber (sem caminho completo, msiexec, comandos do sistema).
    #>
    param (
        [AllowEmptyString()][string]$Command
    )

    $text = ([string]$Command).Trim()

    if ([string]::IsNullOrWhiteSpace($text)) { return "" }

    if ($text.StartsWith('"')) {
        $close = $text.IndexOf('"', 1)
        if ($close -lt 2) { return "" }
        $target = $text.Substring(1, $close - 1)
        $rest = $text.Substring($close + 1).Trim()
    }
    else {
        $match = [regex]::Match($text, '^(.+?\.(exe|com|bat|cmd))(\s|$)', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        if (-not $match.Success) { return "" }
        $target = $match.Groups[1].Value
        $rest = $text.Substring($match.Length).Trim()
    }

    if ([IO.Path]::GetFileName($target) -ieq "rundll32.exe" -or $target -ieq "rundll32") {
        $dll = ($rest -split ',', 2)[0].Trim().Trim('"')
        return $(if ($dll -match '^[A-Za-z]:\\|^%') { $dll } else { "" })
    }

    if ($target -notmatch '^[A-Za-z]:\\|^%') { return "" }

    return $target
}


function ConvertTo-WinForgeRegExePath {
    # "HKLM:\SOFTWARE\X" vira "HKLM\SOFTWARE\X", como o reg.exe espera.
    param ([Parameter(Mandatory)][string]$Path)

    return ($Path -replace '^(HKLM|HKCU|HKCR|HKU):\\', '$1\')
}


function Get-WinForgeRegistryChildValues {
    # As subchaves de uma chave, cada uma com os valores dela (Name, Path, Values). Chave ausente ou sem acesso = vazio.
    param ([Parameter(Mandatory)][string]$Path)

    $children = @()

    try {
        foreach ($key in @(Get-ChildItem -LiteralPath $Path -ErrorAction Stop)) {
            $values = @{}

            foreach ($name in $key.GetValueNames()) {
                $values[[string]$name] = $key.GetValue($name, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
            }

            $children += [PSCustomObject]@{ Name = $key.PSChildName; Path = $key.PSPath -replace '^Microsoft\.PowerShell\.Core\\Registry::HKEY_LOCAL_MACHINE', 'HKLM:' -replace '^Microsoft\.PowerShell\.Core\\Registry::HKEY_CURRENT_USER', 'HKCU:'; Values = $values }
        }
    }
    catch {
        return @()
    }

    return @($children)
}


function New-WinForgeRegistryIssue {
    # Uma referência quebrada. Value vazio = a chave inteira sai; senão, só aquele valor. Admin: a chave é do HKLM.
    # Wow64: o arquivo foi procurado também na tradução de 32 bits (a reconferência antes de remover usa a mesma regra).
    param (
        [Parameter(Mandatory)][string]$Category,
        [Parameter(Mandatory)][string]$Key,
        [AllowEmptyString()][string]$Value = "",
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Missing,
        [bool]$Wow64 = $false
    )

    return [PSCustomObject]@{
        Category = $Category
        Key      = $Key
        Value    = $Value
        Name     = $Name
        Missing  = $Missing
        Admin    = ($Key -like "HKLM:*")
        Wow64    = $Wow64
    }
}


# ---------------------------------------------------------------------------
# O que procurar
# ---------------------------------------------------------------------------

function Get-WinForgeRegistryRoots {
    <#
    As chaves onde cada categoria procura (-Category), ou todas. É a mesma lista que o desfazer usa para conferir os
    backups (Get-WinForgeRegistryBackupRoots): escrita uma vez só, as duas não têm como se desencontrar.
    #>
    param ([string]$Category = "")

    $current = "Microsoft\Windows\CurrentVersion"
    $all = [ordered]@{
        "uninstall"   = @("HKCU:\Software\$current\Uninstall", "HKLM:\SOFTWARE\$current\Uninstall", "HKLM:\SOFTWARE\WOW6432Node\$current\Uninstall")
        "run"         = @("HKCU:\Software\$current\Run", "HKLM:\SOFTWARE\$current\Run", "HKLM:\SOFTWARE\WOW6432Node\$current\Run")
        "app-paths"   = @("HKCU:\Software\$current\App Paths", "HKLM:\SOFTWARE\$current\App Paths")
        "mui-cache"   = @("HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\MuiCache")
        "shared-dlls" = @("HKLM:\SOFTWARE\$current\SharedDLLs", "HKLM:\SOFTWARE\WOW6432Node\$current\SharedDLLs")
        "help-files"  = @("HKLM:\SOFTWARE\Microsoft\Windows\Help", "HKLM:\SOFTWARE\Microsoft\Windows\HTML Help")
        "fonts"       = @("HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts")
    }

    if ($Category) { return @($all[$Category]) }

    return @(foreach ($roots in $all.Values) { $roots })
}


function Get-WinForgeRegistryCategories {
    # As categorias, na ordem da tela. Admin: precisa de Administrador para remover (fica fora da busca sem ele).
    return @(
        [PSCustomObject]@{ Id = "uninstall"; Label = "Desinstaladores que não existem mais"; Description = "Programas que sumiram, mas continuam em Aplicativos instalados"; Admin = $false },
        [PSCustomObject]@{ Id = "run"; Label = "Inicialização apontando para arquivos apagados"; Description = "Ao entrar no Windows, ele tenta abrir algo que não existe mais"; Admin = $false },
        [PSCustomObject]@{ Id = "app-paths"; Label = "Atalhos de nome de programas apagados"; Description = "Nomes de programas que o Executar e o Iniciar não conseguem mais abrir"; Admin = $false },
        [PSCustomObject]@{ Id = "mui-cache"; Label = "Nomes guardados de programas apagados"; Description = "Cache que o Explorador guarda de cada programa já aberto"; Admin = $false },
        [PSCustomObject]@{ Id = "shared-dlls"; Label = "Bibliotecas compartilhadas que não existem mais"; Description = "Contagem de uso de bibliotecas já removidas"; Admin = $true },
        [PSCustomObject]@{ Id = "help-files"; Label = "Arquivos de ajuda que não existem mais"; Description = "Ajudas (.chm, .hlp) de programas desinstalados"; Admin = $true },
        [PSCustomObject]@{ Id = "fonts"; Label = "Fontes que não existem mais"; Description = "Fontes registradas cujo arquivo foi apagado"; Admin = $true }
    )
}


function Test-WinForgeInstallerCachePath {
    <#
    Verdadeiro para um desinstalador guardado na pasta de cache de um instalador, e não na do programa: Package Cache
    (pacotes WiX/Burn, como os Redistribuíveis do Visual C++), Caphyon (Advanced Installer) e InstallShield Installation
    Information. Outro programa de limpeza pode ter esvaziado esse cache com o programa ainda instalado; sem o
    desinstalador ali, não dá para saber se o programa saiu.
    #>
    param ([AllowEmptyString()][string]$Path)

    return ([string]$Path -match '\\(Package Cache|Caphyon|[^\\]*Installation Information)\\')
}


function Get-WinForgeDisplayIconPath {
    # O arquivo do ícone de uma entrada de Aplicativos instalados: "C:\App\app.exe",0 vira C:\App\app.exe.
    param ([AllowEmptyString()][string]$Icon)

    $text = ([string]$Icon).Trim()
    $text = ([regex]::Replace($text, ',\s*-?[0-9]+$', '')).Trim().Trim('"')

    return $text
}


function Find-WinForgeBrokenUninstallEntries {
    <#
    Entradas de Aplicativos instalados cujo desinstalador e pasta de instalação sumiram. As do Windows Installer (MSI)
    e os componentes do sistema ficam de fora: quem cuida delas é o próprio Windows. Também ficam as que ainda têm
    sinal de programa instalado: o ícone (DisplayIcon) num arquivo que existe, ou o desinstalador na pasta de cache de
    um instalador (Test-WinForgeInstallerCachePath), como os pacotes do Visual C++; tirar uma dessas da lista
    esconderia um programa que continua no PC.
    #>
    foreach ($root in @(Get-WinForgeRegistryRoots -Category "uninstall")) {
        $wow64 = Test-WinForgeRegistryRootShared -Root $root

        foreach ($child in @(Get-WinForgeRegistryChildValues -Path $root)) {
            $values = $child.Values
            $name = [string]$values["DisplayName"]

            if ([string]::IsNullOrWhiteSpace($name)) { continue }
            if ([string]$values["SystemComponent"] -eq "1" -or [string]$values["WindowsInstaller"] -eq "1") { continue }

            if ($values.ContainsKey("BundleCachePath") -or $values.ContainsKey("BundleUpgradeCode")) { continue }

            $target = Get-WinForgeCommandTargetPath -Command ([string]$values["UninstallString"])

            if ([string]::IsNullOrWhiteSpace($target) -or (Test-WinForgeInstallerCachePath -Path $target)) { continue }
            if (-not (Test-WinForgeLocalPathMissing -Path $target -Wow64:$wow64)) { continue }

            $icon = Get-WinForgeDisplayIconPath -Icon ([string]$values["DisplayIcon"])

            if ($icon -and -not (Test-WinForgeLocalPathMissing -Path $icon -Wow64:$wow64)) { continue }

            $location = [string]$values["InstallLocation"]

            if (-not [string]::IsNullOrWhiteSpace($location) -and -not (Test-WinForgeLocalPathMissing -Path $location -Wow64:$wow64)) { continue }

            # Sem a pasta de instalação registrada, a do desinstalador faz as vezes dela: com a pasta ainda lá, o programa
            # pode estar instalado (só o desinstalador sumiu), e remover a entrada o tiraria da lista de Aplicativos.
            if ([string]::IsNullOrWhiteSpace($location)) {
                $cut = $target.TrimEnd('\').LastIndexOf('\')
                $folder = $(if ($cut -gt 2) { $target.Substring(0, $cut) } else { "" })

                if (-not [string]::IsNullOrWhiteSpace($folder) -and -not (Test-WinForgeLocalPathMissing -Path $folder -Wow64:$wow64)) { continue }
            }

            New-WinForgeRegistryIssue -Category "uninstall" -Key $child.Path -Name $name.Trim() -Missing $target -Wow64 $wow64
        }
    }
}


function Find-WinForgeBrokenRunEntries {
    # Valores das chaves Run que abrem um arquivo que não existe mais.
    foreach ($root in @(Get-WinForgeRegistryRoots -Category "run")) {
        $wow64 = Test-WinForgeRegistryRootShared -Root $root
        $values = Get-WinForgeRegistryValues -Path $root

        foreach ($name in @($values.Keys)) {
            $target = Get-WinForgeCommandTargetPath -Command ([string]$values[$name])

            if ($target -and (Test-WinForgeLocalPathMissing -Path $target -Wow64:$wow64)) {
                New-WinForgeRegistryIssue -Category "run" -Key $root -Value $name -Name $name -Missing $target -Wow64 $wow64
            }
        }
    }
}


function Find-WinForgeBrokenAppPaths {
    # App Paths: o nome curto de um programa (ex.: winword.exe) apontando para um arquivo que não existe mais.
    foreach ($root in @(Get-WinForgeRegistryRoots -Category "app-paths")) {
        $wow64 = Test-WinForgeRegistryRootShared -Root $root

        foreach ($child in @(Get-WinForgeRegistryChildValues -Path $root)) {
            $target = ([string]$child.Values[""]).Trim()

            # Entre aspas, o caminho é o que está dentro delas ("C:\X\x.exe" /arg); sem aspas, o valor inteiro.
            if ($target.StartsWith('"')) { $target = Get-WinForgeCommandTargetPath -Command $target }

            if ($target -and (Test-WinForgeLocalPathMissing -Path $target -Wow64:$wow64)) {
                New-WinForgeRegistryIssue -Category "app-paths" -Key $child.Path -Name $child.Name -Missing $target -Wow64 $wow64
            }
        }
    }
}


function Find-WinForgeStaleMuiCache {
    # MuiCache: "C:\App\app.exe.FriendlyAppName" e "C:\App\app.exe.ApplicationCompany" de programas apagados.
    $root = @(Get-WinForgeRegistryRoots -Category "mui-cache")[0]
    $values = Get-WinForgeRegistryValues -Path $root

    foreach ($name in @($values.Keys)) {
        $match = [regex]::Match([string]$name, '^(.+\.(exe|dll))\.[A-Za-z]+$', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)

        if ($match.Success -and (Test-WinForgeLocalPathMissing -Path $match.Groups[1].Value -Wow64)) {
            New-WinForgeRegistryIssue -Category "mui-cache" -Key $root -Value $name -Name ([IO.Path]::GetFileName($match.Groups[1].Value)) -Missing $match.Groups[1].Value -Wow64 $true
        }
    }
}


function Find-WinForgeMissingSharedDlls {
    # As duas chaves recebem caminhos escritos por instaladores de 32 bits (System32 querendo dizer SysWOW64): a
    # tradução de 32 bits vale para as duas.
    foreach ($root in @(Get-WinForgeRegistryRoots -Category "shared-dlls")) {
        $values = Get-WinForgeRegistryValues -Path $root

        foreach ($name in @($values.Keys)) {
            if (Test-WinForgeLocalPathMissing -Path $name -Wow64) {
                New-WinForgeRegistryIssue -Category "shared-dlls" -Key $root -Value $name -Name ([IO.Path]::GetFileName($name)) -Missing $name -Wow64 $true
            }
        }
    }
}


function Find-WinForgeMissingHelpFiles {
    # Help e HTML Help: o nome do arquivo de ajuda (valor) e a pasta dele (dado).
    foreach ($root in @(Get-WinForgeRegistryRoots -Category "help-files")) {
        $values = Get-WinForgeRegistryValues -Path $root

        foreach ($name in @($values.Keys)) {
            $folder = [string]$values[$name]

            if ([string]::IsNullOrWhiteSpace($folder)) { continue }

            # Sem Join-Path: com a pasta numa unidade que não existe mais, ele escreve um erro a cada entrada.
            $file = $folder.Trim().TrimEnd('\') + "\" + [string]$name

            if (Test-WinForgeLocalPathMissing -Path $file) {
                New-WinForgeRegistryIssue -Category "help-files" -Key $root -Value $name -Name $name -Missing $file
            }
        }
    }
}


function Find-WinForgeMissingFonts {
    # Fontes registradas: o dado é o arquivo, na pasta Fonts do Windows (nome simples) ou em qualquer lugar (caminho completo).
    $windows = $(if (-not [string]::IsNullOrWhiteSpace($env:WINDIR)) { $env:WINDIR } else { $env:SystemRoot })

    if ([string]::IsNullOrWhiteSpace($windows)) { return }

    $root = @(Get-WinForgeRegistryRoots -Category "fonts")[0]
    $values = Get-WinForgeRegistryValues -Path $root

    foreach ($name in @($values.Keys)) {
        $file = [string]$values[$name]

        if ([string]::IsNullOrWhiteSpace($file)) { continue }

        $full = $(if ($file -match '^[A-Za-z]:\\') { $file } else { Join-Path (Join-Path $windows "Fonts") $file })

        if (Test-WinForgeLocalPathMissing -Path $full) {
            New-WinForgeRegistryIssue -Category "fonts" -Key $root -Value $name -Name $name -Missing $full
        }
    }
}


function Find-WinForgeRegistryIssues {
    <#
    Procura as referências quebradas nas categorias pedidas (padrão: todas). Sem Administrador, as categorias que só
    existem no HKLM ficam de fora, e as entradas do HKLM das outras também: não daria para removê-las.
    #>
    param (
        [string[]]$Categories = @(Get-WinForgeRegistryCategories | ForEach-Object { $_.Id }),
        [bool]$IncludeMachine = (Test-WinForgeAdministrator)
    )

    if (Test-WinForgeRegistryViewMismatch) {
        throw (Get-WinForgeRegistryViewMismatchText)
    }

    $finders = @{
        "uninstall"   = "Find-WinForgeBrokenUninstallEntries"
        "run"         = "Find-WinForgeBrokenRunEntries"
        "app-paths"   = "Find-WinForgeBrokenAppPaths"
        "mui-cache"   = "Find-WinForgeStaleMuiCache"
        "shared-dlls" = "Find-WinForgeMissingSharedDlls"
        "help-files"  = "Find-WinForgeMissingHelpFiles"
        "fonts"       = "Find-WinForgeMissingFonts"
    }

    $issues = @()

    foreach ($category in @(Get-WinForgeRegistryCategories)) {
        if ($Categories -notcontains $category.Id) { continue }
        if ($category.Admin -and -not $IncludeMachine) { continue }

        try {
            $issues += @(& $finders[$category.Id])
        }
        catch {
            Write-Verbose "Categoria $($category.Id) ilegível: $($_.Exception.Message)"
        }
    }

    if (-not $IncludeMachine) {
        $issues = @($issues | Where-Object { -not $_.Admin })
    }

    return @($issues | Where-Object { $null -ne $_ })
}


# ---------------------------------------------------------------------------
# Backup e remoção
# ---------------------------------------------------------------------------

function Get-WinForgeRegistryBackupFolder {
    $folder = Join-Path (Get-WinForgeDataPath) "RegistryBackups"

    if (-not (Test-Path -LiteralPath $folder)) {
        [void](New-Item -ItemType Directory -Path $folder -Force)
    }

    return $folder
}


function Get-WinForgeRegistryBackupRoots {
    <#
    As chaves de onde a limpeza tira alguma coisa (as raízes das buscas acima). O desfazer só devolve o que fica nelas: o
    backup mora em %LOCALAPPDATA%, onde qualquer programa da conta grava sem Administrador, e o desfazer pode rodar como
    Administrador. Um backup que mexe em outra chave não é usado.
    #>
    return @(Get-WinForgeRegistryRoots)
}


function Test-WinForgeRegistryBackupFile {
    <#
    Um arquivo de backup só é usado pelo desfazer se estiver direto na pasta de backups do registro do WinForge, com a
    extensão esperada (.reg para chaves inteiras, .json para valores) e sem ser um atalho para outro arquivo. O caminho
    vem do Histórico de mudanças, que fica em %LOCALAPPDATA% e pode ser alterado por qualquer programa da conta.
    #>
    param (
        [AllowEmptyString()][string]$Path,

        [Parameter(Mandatory)]
        [ValidateSet(".reg", ".json")]
        [string]$Extension
    )

    if ([string]::IsNullOrWhiteSpace($Path)) { return $false }
    if ($Path -match '(^|[\\/])[.][.]([\\/]|$)') { return $false }

    try {
        $full = [IO.Path]::GetFullPath($Path)
        $folder = [IO.Path]::GetFullPath((Get-WinForgeRegistryBackupFolder)).TrimEnd([char[]]@([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar))
    }
    catch {
        return $false
    }

    if (-not [string]::Equals([IO.Path]::GetDirectoryName($full), $folder, [StringComparison]::OrdinalIgnoreCase)) { return $false }
    if (-not [string]::Equals([IO.Path]::GetExtension($full), $Extension, [StringComparison]::OrdinalIgnoreCase)) { return $false }

    $item = Get-Item -LiteralPath $full -Force -ErrorAction SilentlyContinue

    if ($null -eq $item -or $item.PSIsContainer) { return $false }
    if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { return $false }

    return $true
}


function Test-WinForgeRegistryKeyInBackupRoots {
    # Se a chave é uma das raízes da limpeza ou fica dentro de uma (-Exact: só as próprias raízes, que é de onde saem
    # os valores).
    param (
        [Parameter(Mandatory)][string]$Key,
        [switch]$Exact
    )

    foreach ($root in @(Get-WinForgeRegistryBackupRoots)) {
        if ([string]::Equals($Key, $root, [StringComparison]::OrdinalIgnoreCase)) { return $true }
        if (-not $Exact -and $Key.StartsWith($root + "\", [StringComparison]::OrdinalIgnoreCase)) { return $true }
    }

    return $false
}


function Test-WinForgeRegistryBackupKeys {
    <#
    Confere, antes de importar um .reg de backup, que ele só grava nas chaves da limpeza (Get-WinForgeRegistryBackupRoots)
    e não apaga nada (linhas "[-HKEY...]"). Assim um .reg preparado por outro programa e posto na pasta de backups não
    vira um jeito de gravar qualquer coisa no registro com Administrador.
    #>
    param (
        [Parameter(Mandatory)][string]$Path
    )

    try {
        $text = [IO.File]::ReadAllText($Path)
    }
    catch {
        return $false
    }

    $found = 0

    foreach ($line in ($text -split "`r?`n")) {
        $trimmed = $line.Trim()

        if (-not $trimmed.StartsWith("[")) { continue }

        $match = [regex]::Match($trimmed, '^\[(-?)(HKEY_LOCAL_MACHINE|HKEY_CURRENT_USER)\\(.+)\]$', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)

        if (-not $match.Success -or $match.Groups[1].Value -eq "-") { return $false }

        $hive = $(if ($match.Groups[2].Value -ieq "HKEY_LOCAL_MACHINE") { "HKLM:" } else { "HKCU:" })

        if (-not (Test-WinForgeRegistryKeyInBackupRoots -Key "$hive\$($match.Groups[3].Value)")) { return $false }

        $found++
    }

    return ($found -gt 0)
}


function Get-WinForgeRegistryValueRecord {
    <#
    O que é preciso para recriar um valor: Key, Name, Kind (o tipo, como RegistryValueKind) e Data, com as variáveis de
    ambiente sem expandir. Binário vai em Base64 e números em texto, para o JSON não mudar nada. $null quando o valor não
    existe; Kind vazio quando o tipo não cabe no JSON (aí a chave vai inteira para o .reg). Lança erro se a chave não
    puder ser lida: sem saber o que havia, o valor não pode sair.
    #>
    param (
        [Parameter(Mandatory)][string]$Key,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Name
    )

    $item = Get-Item -LiteralPath $Key -ErrorAction Stop

    if (@($item.GetValueNames()) -notcontains $Name) { return $null }

    $kind = [string]$item.GetValueKind($Name)
    $raw = $item.GetValue($Name, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
    $invariant = [System.Globalization.CultureInfo]::InvariantCulture
    $data = $null

    if ($kind -eq "String" -or $kind -eq "ExpandString") { $data = [string]$raw }
    elseif ($kind -eq "DWord") { $data = ([int]$raw).ToString($invariant) }
    elseif ($kind -eq "QWord") { $data = ([int64]$raw).ToString($invariant) }
    elseif ($kind -eq "Binary") { $data = [Convert]::ToBase64String([byte[]]$raw) }
    elseif ($kind -eq "MultiString") { $data = @([string[]]$raw) }
    else { $kind = "" }

    return [PSCustomObject]@{ Key = $Key; Name = $Name; Kind = $kind; Data = $data }
}


function Test-WinForgeRegistryValuePresent {
    # Se o valor existe hoje. Chave ausente ou ilegível = não existe (recriar vai dizer se dá para gravar ali).
    param (
        [Parameter(Mandatory)][string]$Key,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Name
    )

    try {
        $item = Get-Item -LiteralPath $Key -ErrorAction Stop
    }
    catch {
        return $false
    }

    return (@($item.GetValueNames()) -contains $Name)
}


function Set-WinForgeRegistryValueRecord {
    # Recria um valor guardado por Get-WinForgeRegistryValueRecord, com o mesmo tipo e o mesmo dado.
    param (
        [Parameter(Mandatory)][string]$Key,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Name,
        [Parameter(Mandatory)][string]$Kind,
        $Data
    )

    $invariant = [System.Globalization.CultureInfo]::InvariantCulture

    $value = switch ($Kind) {
        "String" { [string]$Data }
        "ExpandString" { [string]$Data }
        "DWord" { [int]::Parse([string]$Data, $invariant) }
        "QWord" { [int64]::Parse([string]$Data, $invariant) }
        "Binary" { , [Convert]::FromBase64String([string]$Data) }
        "MultiString" { , [string[]]@($Data) }
        default { throw "tipo de valor desconhecido: $Kind" }
    }

    if (-not (Test-Path -LiteralPath $Key)) {
        [void](New-Item -Path $Key -Force -ErrorAction Stop)
    }

    [void](New-ItemProperty -LiteralPath $Key -Name $Name -Value $value -PropertyType $Kind -Force -ErrorAction Stop)
}


function Restore-WinForgeRegistryValues {
    <#
    Desfaz a remoção de valores a partir do JSON do backup: recria só os que não existem hoje. Um valor que voltou a
    existir (o programa foi reinstalado e o gravou de novo) fica como está; devolver o dado antigo desfaria uma mudança
    que não foi do WinForge. Só valores das chaves da limpeza são recriados. Devolve Restored, Kept e Failed (os nomes
    que não voltaram); lança erro se o arquivo não puder ser lido.
    #>
    param (
        [Parameter(Mandatory)][string]$Path
    )

    $document = ConvertFrom-WinForgeStateText -Path $Path

    if ($null -eq $document) {
        throw "não foi possível ler o backup dos valores do registro"
    }

    $restored = 0
    $kept = 0
    $failed = @()

    foreach ($entry in @(Get-WinForgeJsonValue -Object $document -Name "Values" -Default @())) {
        if ($null -eq $entry) { continue }

        $key = [string](Get-WinForgeJsonValue -Object $entry -Name "Key" -Default "")
        $name = [string](Get-WinForgeJsonValue -Object $entry -Name "Name" -Default "")
        $kind = [string](Get-WinForgeJsonValue -Object $entry -Name "Kind" -Default "")
        $data = Get-WinForgeJsonValue -Object $entry -Name "Data" -Default $null

        if (-not (Test-WinForgeRegistryKeyInBackupRoots -Key $key -Exact) -or $kind -notin @("String", "ExpandString", "DWord", "QWord", "Binary", "MultiString")) {
            $failed += $name
            continue
        }

        try {
            if (Test-WinForgeRegistryValuePresent -Key $key -Name $name) {
                $kept++
                continue
            }

            Set-WinForgeRegistryValueRecord -Key $key -Name $name -Kind $kind -Data $data
            $restored++
        }
        catch {
            $failed += $name
        }
    }

    return [PSCustomObject]@{ Restored = $restored; Kept = $kept; Failed = @($failed) }
}


function Export-WinForgeRegistryBackup {
    <#
    Salva o que vai mudar antes de mexer. Chaves inteiras (programas em Aplicativos instalados, App Paths) vão para um
    .reg, que o desfazer importa. Valores soltos (Run, MuiCache, SharedDLLs, ajudas, fontes) vão para um .json com a chave,
    o nome, o tipo e o dado de cada um: o desfazer recria só esses valores. Antes, a chave que os continha ia inteira
    para o .reg, e desfazer importava a chave toda, voltando também valores que outros programas tinham mudado depois.
    Devolve File (o .reg, ou "") e Values (o .json, ou ""); lança erro se algo não pôde ser salvo (aí nada é removido).
    #>
    param (
        [Parameter(Mandatory)][object[]]$Issues,
        [datetime]$At = (Get-Date)
    )

    $folder = Get-WinForgeRegistryBackupFolder
    $stamp = $At.ToString('yyyy-MM-dd-HHmmss', [System.Globalization.CultureInfo]::InvariantCulture)
    $file = Join-Path $folder "registro-$stamp.reg"
    $valuesFile = Join-Path $folder "registro-$stamp.json"
    $records = New-Object System.Collections.Generic.List[object]
    $recorded = @{}
    $keys = New-Object System.Collections.Generic.List[string]

    foreach ($issue in $Issues) {
        if ([string]::IsNullOrEmpty($issue.Value)) {
            if (-not $keys.Contains([string]$issue.Key)) { $keys.Add([string]$issue.Key) }
            continue
        }

        $id = "$($issue.Key)|$($issue.Value)".ToLowerInvariant()
        if ($recorded.ContainsKey($id)) { continue }
        $recorded[$id] = $true

        try {
            $record = Get-WinForgeRegistryValueRecord -Key $issue.Key -Name $issue.Value
        }
        catch {
            throw "não foi possível salvar o backup de $(ConvertTo-WinForgeRegExePath -Path $issue.Key)"
        }

        # Valor que já não existe: não há o que salvar (e a remoção dele vai falhar e ser contada).
        if ($null -eq $record) { continue }

        if ([string]::IsNullOrEmpty($record.Kind)) {
            # Tipo raro, que o JSON não guardaria igual: a chave inteira vai para o .reg, como antes.
            if (-not $keys.Contains([string]$issue.Key)) { $keys.Add([string]$issue.Key) }
            continue
        }

        $records.Add($record)
    }

    $parts = New-Object System.Collections.Generic.List[string]
    $position = 0

    foreach ($key in $keys) {
        $position++
        $partFile = Join-Path $folder "parte-$position.reg"
        $run = Invoke-WinForgeCapture -FilePath "reg" -Arguments @("export", (ConvertTo-WinForgeRegExePath -Path $key), $partFile, "/y")

        if ($run.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $partFile -PathType Leaf)) {
            foreach ($part in $parts) { Remove-Item -LiteralPath $part -Force -ErrorAction SilentlyContinue }
            throw "não foi possível salvar o backup de $(ConvertTo-WinForgeRegExePath -Path $key)"
        }

        $parts.Add($partFile)
    }

    $regFile = ""

    if ($parts.Count -gt 0) {
        # O reg export grava em UTF-16 com o cabeçalho "Windows Registry Editor Version 5.00": o arquivo final leva o
        # cabeçalho uma vez e o resto de cada parte.
        $builder = New-Object System.Text.StringBuilder
        [void]$builder.AppendLine("Windows Registry Editor Version 5.00")

        foreach ($part in $parts) {
            $text = [IO.File]::ReadAllText($part)
            $body = $text -replace '^\uFEFF?Windows Registry Editor Version 5\.00\r?\n', ''
            [void]$builder.AppendLine("")
            [void]$builder.Append($body.TrimEnd())
            [void]$builder.AppendLine("")
            Remove-Item -LiteralPath $part -Force -ErrorAction SilentlyContinue
        }

        [IO.File]::WriteAllText($file, $builder.ToString(), [System.Text.Encoding]::Unicode)
        $regFile = $file
    }

    $jsonFile = ""

    if ($records.Count -gt 0) {
        try {
            Write-WinForgeStateJson -Path $valuesFile -InputObject ([ordered]@{ Format = "WinForge.RegistryValues"; Version = 1; Values = $records.ToArray() }) -Depth 6
        }
        catch {
            if ($regFile) { Remove-Item -LiteralPath $regFile -Force -ErrorAction SilentlyContinue }
            throw "não foi possível salvar o backup dos valores do registro: $($_.Exception.Message.TrimEnd('.'))"
        }

        $jsonFile = $valuesFile
    }

    return [PSCustomObject]@{ File = $regFile; Values = $jsonFile }
}


function Test-WinForgeRegistryIssuePresent {
    # Se o que a referência aponta ainda está no registro: a chave (Value vazio) ou o valor. Ilegível = não está.
    param ([Parameter(Mandatory)]$Issue)

    if ([string]::IsNullOrEmpty([string]$Issue.Value)) { return (Test-Path -LiteralPath $Issue.Key) }

    return (Test-WinForgeRegistryValuePresent -Key $Issue.Key -Name ([string]$Issue.Value))
}


function Remove-WinForgeRegistryValueExact {
    <#
    Remove um valor pelo nome exato. O -Name do Remove-ItemProperty trata colchetes e asteriscos de um jeito que muda
    com a versão do PowerShell e com o -LiteralPath: um nome como C:\App[1]\app.exe.FriendlyAppName podia casar com
    outro valor (que sairia sem backup) ou com nenhum (e a remoção falharia sempre). Aqui o nome vai direto para o
    Windows, sem curinga nenhum. Um valor que já não existe não é erro.
    #>
    param (
        [Parameter(Mandatory)][string]$Key,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Name
    )

    $match = [regex]::Match($Key, '^(HKCU|HKLM):\\(.+)$', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)

    if (-not $match.Success) { throw "chave do registro não reconhecida: $Key" }

    $hive = $(if ($match.Groups[1].Value -ieq "HKLM") { [Microsoft.Win32.Registry]::LocalMachine } else { [Microsoft.Win32.Registry]::CurrentUser })
    $subKey = $hive.OpenSubKey($match.Groups[2].Value, $true)

    if ($null -eq $subKey) { return }

    try {
        $subKey.DeleteValue($Name, $false)
    }
    finally {
        $subKey.Close()
    }
}


function Remove-WinForgeRegistryIssue {
    # Remove a referência quebrada: o valor, ou a chave inteira quando Value é vazio.
    param ([Parameter(Mandatory)]$Issue)

    if ([string]::IsNullOrEmpty($Issue.Value)) {
        Remove-Item -LiteralPath $Issue.Key -Recurse -Force -ErrorAction Stop
    }
    else {
        Remove-WinForgeRegistryValueExact -Key $Issue.Key -Name ([string]$Issue.Value)
    }
}


function Clear-WinForgeRegistryIssues {
    <#
    Salva o backup e remove as referências dadas, sem perguntar nada (a Verificação do PC e a tela usam esta parte).
    Anota a mudança no Histórico com o desfazer. Devolve um WinForge.Result com Data.Backup (o primeiro arquivo de
    backup), Data.BackupFiles (o .reg e/ou o .json) e Data.Removed.
    #>
    param (
        [Parameter(Mandatory)][object[]]$Issues
    )

    if (Test-WinForgeRegistryViewMismatch) {
        throw (Get-WinForgeRegistryViewMismatchText)
    }

    # A busca pode ter sido minutos antes (a Verificação do PC lista e só depois corrige): um disco ligado nesse
    # meio-tempo, ou um programa reinstalado, faz o arquivo voltar a existir, e a referência deixa de estar quebrada. A
    # conferência usa a mesma regra de 32 bits da busca (Wow64); com outra, uma referência quebrada nunca sairia. O que
    # já saiu do registro (um desinstalador que tirou a própria chave) também fica de fora: não há o que salvar nem tirar.
    $present = @($Issues | Where-Object { $null -ne $_ -and (Test-WinForgeRegistryIssuePresent -Issue $_) })
    $gone = $Issues.Count - $present.Count
    $current = @($present | Where-Object { Test-WinForgeLocalPathMissing -Path ([string]$_.Missing) -Wow64:([bool](Get-WinForgeJsonValue -Object $_ -Name "Wow64" -Default $false)) })
    $back = $present.Count - $current.Count
    $removed = 0
    $failures = @()
    $backup = $null
    $backupFiles = @()

    if ($current.Count -gt 0) {
        $backup = Export-WinForgeRegistryBackup -Issues $current
        $backupFiles = @(@([string]$backup.File, [string]$backup.Values) | Where-Object { -not [string]::IsNullOrEmpty($_) })
    }

    try {
        foreach ($issue in $current) {
            try {
                Remove-WinForgeRegistryIssue -Issue $issue
                $removed++
            }
            catch {
                $failures += "$($issue.Name): $($_.Exception.Message.TrimEnd('.'))"
            }
        }
    }
    finally {
        # No finally: parar a ação no meio não deixa sem anotação (e sem o desfazer) o que já saiu.
        if ($removed -gt 0) {
            # File: as chaves inteiras (.reg); Values: os valores soltos (.json). Qualquer um dos dois pode faltar.
            [void](Add-WinForgeChange -Action "Limpeza do registro" -Text (Format-WinForgeCount -Count $removed -One "referência removida" -Many "referências removidas") -Undo @{ Kind = "registry"; File = [string]$backup.File; Values = [string]$backup.Values })
        }
    }

    $removedText = Format-WinForgeCount -Count $removed -One "referência removida" -Many "referências removidas"

    $keptParts = @()
    if ($back -gt 0) { $keptParts += Format-WinForgeCount -Count $back -One "referência voltou a apontar para um arquivo que existe e ficou" -Many "referências voltaram a apontar para arquivos que existem e ficaram" }
    if ($gone -gt 0) { $keptParts += Format-WinForgeCount -Count $gone -One "referência já tinha saído do registro" -Many "referências já tinham saído do registro" }
    if ($keptParts.Count -gt 0) { $removedText += "; " + ($keptParts -join "; ") }

    $data = @{ Backup = $(if ($backupFiles.Count -gt 0) { $backupFiles[0] } else { "" }); BackupFiles = $backupFiles; Removed = $removed; Failures = @($failures); Back = $back; Gone = $gone }

    if ($current.Count -eq 0) { return (New-WinForgeResult -Kind Ok -Detail "nada a remover: $($keptParts -join '; ')" -Data $data) }

    if ($failures.Count -eq 0) { return (New-WinForgeResult -Kind Ok -Detail $removedText -Data $data) }
    if ($removed -eq 0) { return (New-WinForgeResult -Kind Failed -Detail "nenhuma referência foi removida" -Data $data) }

    return (New-WinForgeResult -Kind Warning -Detail "$removedText; $(if ($failures.Count -eq 1) { '1 não pôde ser removida' } else { "$($failures.Count) não puderam ser removidas" })" -Data $data)
}


# ---------------------------------------------------------------------------
# Ação
# ---------------------------------------------------------------------------

function Invoke-WinForgeRegistryCleanup {
    $title = "Limpar o registro"

    Enter-WinForgeAction -Title $title

    $final = New-WinForgeResult -Kind Ok -Title $title

    try {
        $isAdmin = Test-WinForgeAdministrator

        Write-Progress -Activity $title -Status "procurando referências a arquivos que não existem mais"

        try {
            $issues = @(Find-WinForgeRegistryIssues -IncludeMachine $isAdmin)
        }
        finally {
            Write-Progress -Activity $title -Completed
        }

        if (-not $isAdmin) {
            Write-WinForgeStatus -Type Info -Message "Sem Administrador, só as entradas do seu usuário entram. Para incluir as do PC todo, feche o WinForge, abra de novo e aceite o aviso do Windows."
        }

        if ($issues.Count -eq 0) {
            Write-WinForgeStatus -Type Success -Message "Nenhuma referência quebrada foi encontrada."
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Ok -Detail "nenhuma referência quebrada" -Title $title)
            return
        }

        $categories = @(Get-WinForgeRegistryCategories | Where-Object { $id = $_.Id; @($issues | Where-Object { $_.Category -eq $id }).Count -gt 0 })

        Write-WinForgeSection -Title "Referências quebradas"

        foreach ($category in $categories) {
            Write-WinForgeKeyValue -Label $category.Label -Value (Format-WinForgeNumber -Value @($issues | Where-Object { $_.Category -eq $category.Id }).Count) -LabelWidth 48
        }

        Write-Host ""
        [void](Write-WinForgeOtherAccountNotice -What "as entradas do registro do usuário")

        # A lista completa fica nos detalhes técnicos: a chave, o valor e o arquivo que falta.
        foreach ($issue in $issues) {
            Write-Host "  $(ConvertTo-WinForgeRegExePath -Path $issue.Key)$(if ($issue.Value) { ' : ' + $issue.Value }) -> falta $($issue.Missing)" -ForegroundColor DarkGray
        }

        Write-Host ""
        Write-WinForgeStatus -Type Info -Message "Só saem referências a arquivos que não existem mais. Antes, o WinForge salva um backup que desfaz tudo pelo Histórico de mudanças."
        Write-WinForgeStatus -Type Info -Message "Isso não deixa o PC mais rápido: tira do registro entradas que levam a lugar nenhum."
        Write-Host ""

        $options = @(
            foreach ($category in $categories) {
                $inCategory = @($issues | Where-Object { $_.Category -eq $category.Id })
                $examples = Join-WinForgeList -Items @($inCategory | Select-Object -First 3 | ForEach-Object { $_.Name })
                # Bibliotecas compartilhadas vêm desmarcadas: é uma contagem que os instaladores consultam, e quem decide é a pessoa.
                @{ Key = $category.Id; Label = "$($category.Label) ($($inCategory.Count))"; Description = "$($category.Description). Ex.: $examples"; Selected = ($category.Id -ne "shared-dlls") }
            }
        )

        $picked = Read-WinForgeMultiSelect -Message "O que remover?" -Options $options

        if ($null -eq $picked -or @($picked).Count -eq 0) {
            Write-WinForgeStatus -Type Warning -Message "Operação cancelada."
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Skipped -Detail "cancelado pelo usuário" -Title $title)
            return
        }

        $chosen = @($issues | Where-Object { @($picked) -contains $_.Category })
        $countText = Format-WinForgeCount -Count $chosen.Count -One "referência quebrada" -Many "referências quebradas"

        if (-not (Confirm-WinForgeAction -Message "Remover $countText (com backup)?" -DefaultKey "S")) {
            Write-WinForgeStatus -Type Warning -Message "Operação cancelada."
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Skipped -Detail "cancelado pelo usuário" -Title $title)
            return
        }

        Write-Progress -Activity $title -Status "salvando o backup e removendo"

        try {
            $result = Clear-WinForgeRegistryIssues -Issues $chosen
        }
        finally {
            Write-Progress -Activity $title -Completed
        }

        foreach ($backupFile in @($result.Data.BackupFiles)) {
            Write-WinForgeKeyValue -Label "Backup" -Value $backupFile
        }

        Write-Host ""

        foreach ($failure in @($result.Data.Failures) | Select-Object -First 5) {
            Write-WinForgeStatus -Type Error -Message "$failure."
        }

        if ([int]$result.Data.Removed -gt 0) {
            Write-WinForgeStatus -Type Success -Message "$(Format-WinForgeCount -Count ([int]$result.Data.Removed) -One 'referência removida' -Many 'referências removidas')."
            Write-WinForgeStatus -Type Info -Message "Para desfazer, use Manutenção > Histórico de mudanças."
        }

        $result.Etapa = $title
        $final = $result
    }
    catch {
        Write-WinForgeStatus -Type Error -Message "Não foi possível limpar o registro: $($_.Exception.Message.TrimEnd('.'))."
        $final = New-WinForgeResult -Kind Failed -Detail $_.Exception.Message.TrimEnd('.') -Title $title
    }

    Exit-WinForgeAction -Result $final
}


Export-ModuleMember -Function *
