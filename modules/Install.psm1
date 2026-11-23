# Instalação do WinForge: copiar os arquivos de uma versão para a pasta do WinForge (instalar e atualizar, com volta
# ao que era se algo falhar), a entrada em Aplicativos instalados e a desinstalação. Quem usa: o WinForge.Setup.ps1
# (instalar, desinstalar e a troca de arquivos da atualização) e Sobre o WinForge > Verificar nova versão.
#
# Os arquivos do WinForge são os da raiz (WinForge*.cmd, WinForge.*.ps1, README*.md, CHANGELOG.md, LICENSE e o
# SHA256SUMS.txt do zip) e os das pastas modules, gui, lang e assets. Só eles são trocados ou apagados: o que a pessoa
# puser na pasta fica. O tools\New-WinForgePackage.ps1 monta o zip da versão com esta mesma lista.

$script:WinForgeUninstallKey = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\WinForge"
$script:WinForgePackageFolders = @("modules", "gui", "lang", "assets")
$script:WinForgePackageRootFiles = @("WinForge*.cmd", "WinForge.*.ps1", "README*.md", "CHANGELOG.md", "LICENSE", "SHA256SUMS.txt")
$script:WinForgePublisher = "Guilherme Henn"
# Quanto esperar o WinForge fechar antes de trocar os arquivos (segundos).
$script:WinForgeUpdateWaitSeconds = 120
# Um resultado de atualização mais velho que isto não é mostrado (a janela abriu muito depois, por outro caminho).
$script:WinForgeUpdateResultHours = 6


# ---------------------------------------------------------------------------
# O pacote
# ---------------------------------------------------------------------------

function Get-WinForgeFullPath {
    # O caminho completo, sem a barra do fim: duas grafias da mesma pasta ("C:\WinForge\" e "C:\winforge") comparam iguais.
    param ([Parameter(Mandatory)][string]$Path)

    return ([System.IO.Path]::GetFullPath($Path)).TrimEnd([char[]]@('\', '/'))
}


function Test-WinForgeSamePath {
    param ([string]$Path, [string]$Other)

    if ([string]::IsNullOrWhiteSpace($Path) -or [string]::IsNullOrWhiteSpace($Other)) { return $false }

    return ((Get-WinForgeFullPath -Path $Path) -ieq (Get-WinForgeFullPath -Path $Other))
}


function Test-WinForgePathInside {
    # Se Path está dentro de Folder (ou é a própria pasta).
    param ([string]$Path, [string]$Folder)

    if ([string]::IsNullOrWhiteSpace($Path) -or [string]::IsNullOrWhiteSpace($Folder)) { return $false }

    $full = Get-WinForgeFullPath -Path $Path
    $base = Get-WinForgeFullPath -Path $Folder

    return ($full -ieq $base -or $full.StartsWith($base + [System.IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase))
}


function Get-WinForgePackageFiles {
    # Os arquivos do WinForge numa pasta, como caminhos relativos a ela (modules\Core.psm1). Lista vazia se a pasta não existe.
    param ([Parameter(Mandatory)][string]$Root)

    if (-not (Test-Path -LiteralPath $Root -PathType Container)) { return @() }

    $base = Get-WinForgeFullPath -Path $Root
    $files = New-Object System.Collections.Generic.List[string]

    foreach ($pattern in $script:WinForgePackageRootFiles) {
        # O -like confirma o nome: o -Filter do Windows também compara com o nome curto (8.3) do arquivo.
        foreach ($file in @(Get-ChildItem -LiteralPath $base -Filter $pattern -File -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -like $pattern })) {
            if (-not $files.Contains($file.Name)) { $files.Add($file.Name) }
        }
    }

    foreach ($folder in $script:WinForgePackageFolders) {
        $path = Join-Path $base $folder

        if (-not (Test-Path -LiteralPath $path -PathType Container)) { continue }

        foreach ($file in @(Get-ChildItem -LiteralPath $path -Recurse -File -Force -ErrorAction Stop)) {
            $files.Add($file.FullName.Substring($base.Length + 1))
        }
    }

    return @($files | Sort-Object -Unique)
}


function Get-WinForgePackageBuild {
    # A versão escrita no Core.psm1 de uma pasta do WinForge ("" quando não dá para ler).
    param ([Parameter(Mandatory)][string]$Root)

    try {
        $core = Join-Path (Join-Path $Root "modules") "Core.psm1"
        $match = [regex]::Match([System.IO.File]::ReadAllText($core, [System.Text.Encoding]::UTF8), '\$script:WinForgeBuild\s*=\s*"([0-9.]+)"')

        if ($match.Success) { return $match.Groups[1].Value }
    }
    catch {
        Write-Verbose "Versão do pacote: $($_.Exception.Message)"
    }

    return ""
}


function Test-WinForgePackageFolder {
    # Se a pasta tem um WinForge inteiro (os scripts de entrada e os módulos): só uma pasta assim vira instalação.
    param ([Parameter(Mandatory)][string]$Root)

    foreach ($name in @("WinForge.Gui.ps1", "WinForge.Console.ps1", "WinForge.cmd", "modules\Modules.psd1", "modules\Core.psm1", "gui\MainWindow.xaml")) {
        $path = $Root

        foreach ($part in ($name -split '\\')) { $path = Join-Path $path $part }

        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $false }
    }

    return $true
}


function Expand-WinForgeReleasePackage {
    <#
    Extrai o zip de uma versão numa pasta vazia e devolve a pasta que tem os arquivos (a "WinForge" de dentro do zip).
    Cada arquivo é conferido: nenhum nome do zip sai da pasta de destino ("..\", caminho absoluto).
    #>
    param (
        [Parameter(Mandatory)][string]$ZipPath,
        [Parameter(Mandatory)][string]$Destination,
        [string]$Root = ""
    )

    Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue

    $base = Get-WinForgeFullPath -Path $Destination

    Remove-WinForgeFolder -Path $base

    [void](New-Item -ItemType Directory -Path $base -Force -ErrorAction Stop)

    $zip = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)

    try {
        foreach ($entry in $zip.Entries) {
            $name = ([string]$entry.FullName).Replace('\', '/')

            if ($name.EndsWith("/") -or $name.Length -eq 0) { continue }

            $relative = $name.Replace('/', [System.IO.Path]::DirectorySeparatorChar)
            $path = [System.IO.Path]::GetFullPath((Join-Path $base $relative))

            if (-not $path.StartsWith($base + [System.IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
                throw (Get-WinForgeText 'o pacote tem um arquivo fora da pasta do WinForge ({0}) e não foi usado' "$name")
            }

            $folder = Split-Path -Parent $path
            if (-not (Test-Path -LiteralPath $folder)) { [void](New-Item -ItemType Directory -Path $folder -Force -ErrorAction Stop) }

            [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $path, $true)
        }
    }
    finally {
        $zip.Dispose()
    }

    $folder = $(if ($Root) { Join-Path $base $Root } else { $base })

    if (-not (Test-WinForgePackageFolder -Root $folder)) {
        throw (Get-WinForgeText 'o pacote não tem todos os arquivos do WinForge')
    }

    return $folder
}


# ---------------------------------------------------------------------------
# A troca dos arquivos
# ---------------------------------------------------------------------------

function Copy-WinForgeFile {
    # Copia um arquivo por cima de outro, criando a pasta; um arquivo somente leitura no destino não impede a troca.
    param ([Parameter(Mandatory)][string]$From, [Parameter(Mandatory)][string]$To)

    $folder = Split-Path -Parent $To
    if (-not (Test-Path -LiteralPath $folder)) { [void](New-Item -ItemType Directory -Path $folder -Force -ErrorAction Stop) }

    if ([System.IO.File]::Exists($To)) { [System.IO.File]::SetAttributes($To, [System.IO.FileAttributes]::Normal) }

    [System.IO.File]::Copy($From, $To, $true)
}


function Install-WinForgeFiles {
    <#
    Troca os arquivos do WinForge da pasta Target pelos da pasta Source, como uma coisa só: primeiro guarda em
    BackupFolder uma cópia de cada arquivo do WinForge que está em Target; depois copia os novos, apaga os que a versão
    nova não tem e confere cada um pelo SHA-256. Se qualquer passo falha, tudo volta ao que era (os arquivos novos saem,
    os guardados voltam). Devolve Ok, Copied, Removed, Error, RolledBack e RollbackFailed (algum arquivo não voltou: a
    cópia guardada continua em BackupFolder).
    #>
    param (
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Target,
        [Parameter(Mandatory)][string]$BackupFolder
    )

    $result = [PSCustomObject]@{ Ok = $false; Copied = 0; Removed = 0; Error = ""; RolledBack = $false; RollbackFailed = $false; BackupFolder = $BackupFolder }

    $from = Get-WinForgeFullPath -Path $Source
    $to = Get-WinForgeFullPath -Path $Target
    $backup = Get-WinForgeFullPath -Path $BackupFolder

    if ($from -ieq $to) {
        $result.Error = (Get-WinForgeText 'a versão nova já está nesta pasta')
        return $result
    }

    if (-not (Test-WinForgePackageFolder -Root $from)) {
        $result.Error = (Get-WinForgeText 'a pasta da versão nova não tem todos os arquivos do WinForge')
        return $result
    }

    if ((Test-WinForgePathInside -Path $backup -Folder $to) -or (Test-WinForgePathInside -Path $backup -Folder $from)) {
        $result.Error = (Get-WinForgeText 'a pasta da cópia de segurança não pode ficar dentro da pasta do WinForge')
        return $result
    }

    $newFiles = @()
    $oldFiles = @()
    $written = New-Object System.Collections.Generic.List[string]
    $removed = New-Object System.Collections.Generic.List[string]

    try {
        $newFiles = @(Get-WinForgePackageFiles -Root $from)
        $oldFiles = @(Get-WinForgePackageFiles -Root $to)

        if (-not (Test-Path -LiteralPath $to)) { [void](New-Item -ItemType Directory -Path $to -Force -ErrorAction Stop) }
        Remove-WinForgeFolder -Path $backup
        [void](New-Item -ItemType Directory -Path $backup -Force -ErrorAction Stop)

        foreach ($relative in $oldFiles) { Copy-WinForgeFile -From (Join-Path $to $relative) -To (Join-Path $backup $relative) }

        foreach ($relative in $newFiles) {
            Copy-WinForgeFile -From (Join-Path $from $relative) -To (Join-Path $to $relative)
            $written.Add($relative)
        }

        foreach ($relative in @($oldFiles | Where-Object { $newFiles -notcontains $_ })) {
            $path = Join-Path $to $relative
            [System.IO.File]::SetAttributes($path, [System.IO.FileAttributes]::Normal)
            [System.IO.File]::Delete($path)
            $removed.Add($relative)
        }

        foreach ($relative in $newFiles) {
            $expected = (Get-FileHash -LiteralPath (Join-Path $from $relative) -Algorithm SHA256 -ErrorAction Stop).Hash
            $actual = (Get-FileHash -LiteralPath (Join-Path $to $relative) -Algorithm SHA256 -ErrorAction Stop).Hash

            if ($expected -ne $actual) { throw (Get-WinForgeText 'o arquivo {0} não foi gravado como devia' "$relative") }
        }

        # A marca de "baixado da internet" faria o Windows perguntar antes de cada script.
        foreach ($relative in $newFiles) {
            try { Unblock-File -LiteralPath (Join-Path $to $relative) -ErrorAction Stop } catch { Write-Verbose "Desbloqueio: $($_.Exception.Message)" }
        }

        $result.Ok = $true
        $result.Copied = $written.Count
        $result.Removed = $removed.Count
    }
    catch {
        $result.Error = (ConvertTo-WinForgeReadableError -Text ([string]$_.Exception.Message)).TrimEnd('.')
        $result.RolledBack = $true

        foreach ($relative in @($written) + @($removed)) {
            $path = Join-Path $to $relative
            $saved = Join-Path $backup $relative

            try {
                if ($oldFiles -contains $relative) {
                    Copy-WinForgeFile -From $saved -To $path
                }
                elseif ([System.IO.File]::Exists($path)) {
                    [System.IO.File]::SetAttributes($path, [System.IO.FileAttributes]::Normal)
                    [System.IO.File]::Delete($path)
                }
            }
            catch {
                $result.RollbackFailed = $true
            }
        }
    }

    return $result
}


# ---------------------------------------------------------------------------
# Aplicativos instalados
# ---------------------------------------------------------------------------

function Get-WinForgeInstallRegistration {
    # A entrada do WinForge em Aplicativos instalados: Location (a pasta) e Version, ou $null quando não está instalado.
    try {
        if (-not (Test-Path -LiteralPath $script:WinForgeUninstallKey)) { return $null }

        $key = Get-ItemProperty -LiteralPath $script:WinForgeUninstallKey -ErrorAction Stop
        $location = [string](Get-WinForgeJsonValue -Object $key -Name "InstallLocation" -Default "")

        if ([string]::IsNullOrWhiteSpace($location)) { return $null }

        return [PSCustomObject]@{ Location = $location.TrimEnd('\'); Version = [string](Get-WinForgeJsonValue -Object $key -Name "DisplayVersion" -Default "") }
    }
    catch {
        return $null
    }
}


function Test-WinForgeInstalledHere {
    # Se esta cópia do WinForge é a que está em Aplicativos instalados.
    param ([string]$Root = (Get-WinForgeAppRoot))

    $registration = Get-WinForgeInstallRegistration

    return ($null -ne $registration -and (Test-WinForgeSamePath -Path $registration.Location -Other $Root))
}


function Get-WinForgeFolderSizeKb {
    param ([Parameter(Mandatory)][string]$Root)

    $bytes = 0L

    foreach ($relative in @(Get-WinForgePackageFiles -Root $Root)) {
        try { $bytes += (Get-Item -LiteralPath (Join-Path $Root $relative) -Force).Length } catch { Write-Verbose "Tamanho: $($_.Exception.Message)" }
    }

    return [int][Math]::Ceiling($bytes / 1KB)
}


function Get-WinForgeInstallLinks {
    # Os endereços da entrada em Aplicativos instalados: o site (sobre o WinForge), as issues do GitHub (ajuda) e a página
    # de versões (atualização). A entrada é do PC, e não de um idioma: o site vai pela raiz.
    return [ordered]@{
        URLInfoAbout  = (Get-WinForgeWebsiteUrl -Language "pt")
        HelpLink      = "https://github.com/$(Get-WinForgeRepository)/issues"
        URLUpdateInfo = "https://github.com/$(Get-WinForgeRepository)/releases"
    }
}


function Register-WinForgeInstall {
    # Grava a entrada em Aplicativos instalados (Configurações > Aplicativos), de onde o WinForge se desinstala.
    param (
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string]$Build
    )

    $setup = Join-Path $Root "WinForge.Setup.ps1"
    $uninstall = "$(ConvertTo-WinForgeCommandLineArgument -Value (Get-WinForgePowerShellPath)) -NoProfile -ExecutionPolicy Bypass -File $(ConvertTo-WinForgeCommandLineArgument -Value $setup) -Uninstall"

    if (-not (Test-Path -LiteralPath $script:WinForgeUninstallKey)) { [void](New-Item -Path $script:WinForgeUninstallKey -Force -ErrorAction Stop) }

    $links = Get-WinForgeInstallLinks

    $values = [ordered]@{
        DisplayName     = "WinForge"
        DisplayVersion  = $Build
        Publisher       = $script:WinForgePublisher
        InstallLocation = $Root
        DisplayIcon     = (Join-Path (Join-Path $Root "assets") "WinForge.ico")
        UninstallString = $uninstall
        URLInfoAbout    = $links.URLInfoAbout
        HelpLink        = $links.HelpLink
        URLUpdateInfo   = $links.URLUpdateInfo
        InstallDate     = (Get-Date).ToString("yyyyMMdd", [System.Globalization.CultureInfo]::InvariantCulture)
    }

    foreach ($name in $values.Keys) {
        Set-ItemProperty -LiteralPath $script:WinForgeUninstallKey -Name $name -Value ([string]$values[$name]) -Type String -ErrorAction Stop
    }

    foreach ($flag in @("NoModify", "NoRepair")) {
        Set-ItemProperty -LiteralPath $script:WinForgeUninstallKey -Name $flag -Value 1 -Type DWord -ErrorAction Stop
    }

    Set-ItemProperty -LiteralPath $script:WinForgeUninstallKey -Name "EstimatedSize" -Value (Get-WinForgeFolderSizeKb -Root $Root) -Type DWord -ErrorAction Stop
}


function Update-WinForgeInstallVersion {
    # Depois de atualizar a pasta que está em Aplicativos instalados, a versão, os endereços e o tamanho de lá acompanham.
    # Sem entrada (uma pasta extraída, não instalada), nada muda.
    param (
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string]$Build
    )

    $registration = Get-WinForgeInstallRegistration

    if ($null -eq $registration -or -not (Test-WinForgeSamePath -Path $registration.Location -Other $Root)) { return $false }

    try {
        Set-ItemProperty -LiteralPath $script:WinForgeUninstallKey -Name "DisplayVersion" -Value $Build -Type String -ErrorAction Stop

        # Uma entrada gravada por uma versão anterior passa a levar ao site e às issues de agora.
        $links = Get-WinForgeInstallLinks
        foreach ($name in $links.Keys) {
            Set-ItemProperty -LiteralPath $script:WinForgeUninstallKey -Name $name -Value ([string]$links[$name]) -Type String -ErrorAction Stop
        }

        Set-ItemProperty -LiteralPath $script:WinForgeUninstallKey -Name "EstimatedSize" -Value (Get-WinForgeFolderSizeKb -Root $Root) -Type DWord -ErrorAction Stop
        return $true
    }
    catch {
        return $false
    }
}


function Unregister-WinForgeInstall {
    if (Test-Path -LiteralPath $script:WinForgeUninstallKey) { Remove-Item -LiteralPath $script:WinForgeUninstallKey -Recurse -Force -ErrorAction Stop }
}


# ---------------------------------------------------------------------------
# Atalhos e processos de uma pasta do WinForge
# ---------------------------------------------------------------------------

function Get-WinForgeCommonShortcutPaths {
    # Os atalhos para todos os usuários que o instalador cria: Menu Iniciar e Área de Trabalho.
    $paths = @()

    foreach ($special in @("CommonPrograms", "CommonDesktopDirectory")) {
        try {
            $folder = [string][Environment]::GetFolderPath($special)
            if ($folder) { $paths += [PSCustomObject]@{ Id = $(if ($special -eq "CommonPrograms") { "StartMenu" } else { "Desktop" }); Folder = $folder; Path = (Join-Path $folder "WinForge.lnk") } }
        }
        catch {
            Write-Verbose "Pasta comum: $($_.Exception.Message)"
        }
    }

    return @($paths)
}


function Test-WinForgeInstallerShortcut {
    # Se o atalho do instalador (para todos os usuários) no lugar Id (Desktop ou StartMenu) abre o WinForge da pasta Root.
    param (
        [Parameter(Mandatory)][string]$Id,
        [string]$Root = (Get-WinForgeAppRoot)
    )

    $place = @(Get-WinForgeCommonShortcutPaths | Where-Object { $_.Id -eq $Id })[0]
    if ($null -eq $place) { return $false }

    return (Test-WinForgeShortcutOpens -Path $place.Path -Root $Root)
}


function Get-WinForgeInstallStateText {
    # Como esta cópia está, numa frase: instalada (com a entrada em Aplicativos, de onde se desinstala) ou aberta direto
    # da pasta extraída (com o WinForge-Setup.cmd para instalar). Level: Normal ou Muted.
    $root = Get-WinForgeAppRoot

    if (Test-WinForgeInstalledHere -Root $root) {
        return [PSCustomObject]@{ Text = (Get-WinForgeText 'instalado; para desinstalar, use Configurações > Aplicativos'); Level = "Normal" }
    }

    if (Test-Path -LiteralPath (Join-Path $root "WinForge-Setup.cmd") -PathType Leaf) {
        return [PSCustomObject]@{ Text = (Get-WinForgeText 'sem instalar; para instalar, abra o WinForge-Setup.cmd desta pasta'); Level = "Muted" }
    }

    return [PSCustomObject]@{ Text = (Get-WinForgeText 'sem instalar'); Level = "Muted" }
}


function Test-WinForgeShortcutOpens {
    # Se o atalho abre o WinForge desta pasta (um atalho que não pôde ser lido não conta).
    param ([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$Root)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $false }

    try {
        $target = Get-WinForgeShortcutTarget -Path $Path
        $script = Join-Path $Root "WinForge.Gui.ps1"

        return ($null -ne $target -and ([string]$target.Arguments).IndexOf($script, [StringComparison]::OrdinalIgnoreCase) -ge 0)
    }
    catch {
        return $false
    }
}


function Save-WinForgeInstallShortcut {
    # Grava (ou regrava) um atalho que abre o WinForge da pasta Root.
    param ([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$Root)

    $launch = Get-WinForgeLaunchDefinition -Root $Root

    [void](Save-WinForgeShortcutFile -Path $Path -Target $launch.Executable -Arguments $launch.Arguments -WorkingDirectory $launch.WorkingDirectory `
            -IconLocation $launch.IconLocation -Description $launch.Description -AppId $launch.AppId)
}


function Get-WinForgeRunningCopies {
    <#
    Os processos que rodam o WinForge da pasta Root (a janela, o menu de texto e o monitor), pela linha de comando. Cada
    um: ProcessId e Kind (Gui, Console ou Agent). Lista vazia quando não dá para ler. O próprio processo não entra.
    #>
    param ([Parameter(Mandatory)][string]$Root)

    $found = @()

    try {
        $processes = @(Get-CimInstance -ClassName Win32_Process -Filter "Name = 'powershell.exe' OR Name = 'pwsh.exe'" -OperationTimeoutSec 15 -ErrorAction Stop)
    }
    catch {
        return @()
    }

    foreach ($process in $processes) {
        if ([int]$process.ProcessId -eq $PID) { continue }

        $line = [string]$process.CommandLine

        foreach ($kind in @("Gui", "Console", "Agent")) {
            $script = Join-Path $Root "WinForge.$kind.ps1"

            if ($line.IndexOf($script, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
                $found += [PSCustomObject]@{ ProcessId = [int]$process.ProcessId; Kind = $kind }
                break
            }
        }
    }

    return @($found)
}


function Wait-WinForgeProcessExit {
    # Espera os processos fecharem (até Seconds). Devolve os que continuam abertos.
    param ([int[]]$ProcessId = @(), [int]$Seconds = $script:WinForgeUpdateWaitSeconds)

    $deadline = (Get-Date).AddSeconds($Seconds)

    do {
        $open = @($ProcessId | Where-Object { $_ -gt 0 -and $null -ne (Get-Process -Id $_ -ErrorAction SilentlyContinue) })
        if ($open.Count -eq 0) { return @() }
        Start-Sleep -Milliseconds 500
    } while ((Get-Date) -lt $deadline)

    return @($open)
}


# ---------------------------------------------------------------------------
# Atualizar com um clique (Verificar nova versão)
# ---------------------------------------------------------------------------

function Get-WinForgeUpdateFolder {
    return (Join-Path (Get-WinForgeDataPath) "update")
}


function Test-WinForgeFolderWritable {
    # Se esta conta consegue gravar na pasta (um arquivo de teste, criado e apagado na hora).
    param ([Parameter(Mandatory)][string]$Root)

    $probe = Join-Path $Root (".winforge-gravar-{0}.tmp" -f [guid]::NewGuid().ToString("N"))

    try {
        [System.IO.File]::WriteAllText($probe, "")
        [System.IO.File]::Delete($probe)
        return $true
    }
    catch {
        return $false
    }
}


function Test-WinForgeMenuBatchHost {
    <#
    Se o cmd foi aberto só para rodar o WinForge-Console.cmd (cmd /c: dois cliques, o PowerShell, o próprio instalador):
    ele fecha logo depois do menu, e a troca espera por ele. O cmd de um Prompt de Comando aberto à mão (sem /c) roda o
    .cmd por dentro e só fecha quando a pessoa fecha o prompt: esperar por ele travaria a atualização.
    #>
    param ([AllowEmptyString()][string]$CommandLine)

    return ($CommandLine -match '(?i)(^|\s)/c(\s|")' -and $CommandLine -match '(?i)WinForge-Console\.cmd')
}


function Start-WinForgeUpdateInstall {
    <#
    Prepara a troca de arquivos da atualização e devolve se ela começou. O zip conferido é extraído em
    %LOCALAPPDATA%\WinForge\update\pacote, e o WinForge.Setup.ps1 da versão nova é aberto com -Update: ele espera este
    WinForge fechar (este processo e, no menu de texto, o cmd que o abriu), troca os arquivos, volta ao que era se algo
    falhar e abre o WinForge de novo. Quem chama fecha o WinForge (Request-WinForgeAppExit). Sem conseguir gravar na
    pasta do WinForge, o Setup pede o Administrador (o aviso do Windows; recusado, a função lança erro).
    #>
    param (
        [Parameter(Mandatory)][string]$ZipPath,
        [string]$PackageRoot = "WinForge",
        [ValidateSet("Gui", "Console")][string]$Reopen = "Gui"
    )

    $source = Expand-WinForgeReleasePackage -ZipPath $ZipPath -Destination (Join-Path (Get-WinForgeUpdateFolder) "pacote") -Root $PackageRoot
    $setup = Join-Path $source "WinForge.Setup.ps1"

    if (-not (Test-Path -LiteralPath $setup -PathType Leaf)) { throw (Get-WinForgeText 'a versão nova não tem o instalador (WinForge.Setup.ps1)') }

    $wait = @($PID)

    # No menu de texto, o cmd que abriu o PowerShell continua lendo o WinForge-Console.cmd até o fim: a troca espera ele,
    # quando ele foi aberto só para isso (Test-WinForgeMenuBatchHost).
    try {
        $parent = Get-CimInstance -ClassName Win32_Process -Filter "ProcessId = $PID" -OperationTimeoutSec 15 -ErrorAction Stop
        $parentId = [int](Get-WinForgeJsonValue -Object $parent -Name "ParentProcessId" -Default 0)

        if ($parentId -gt 0) {
            $parentProcess = Get-Process -Id $parentId -ErrorAction SilentlyContinue

            if ($null -ne $parentProcess -and $parentProcess.ProcessName -ieq "cmd") {
                $parentInfo = Get-CimInstance -ClassName Win32_Process -Filter "ProcessId = $parentId" -OperationTimeoutSec 15 -ErrorAction Stop
                if (Test-WinForgeMenuBatchHost -CommandLine ([string](Get-WinForgeJsonValue -Object $parentInfo -Name "CommandLine" -Default ""))) { $wait += $parentId }
            }
        }
    }
    catch {
        Write-Verbose "Processo pai: $($_.Exception.Message)"
    }

    $root = Get-WinForgeAppRoot
    $arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File $(ConvertTo-WinForgeCommandLineArgument -Value $setup) -Update -Target $(ConvertTo-WinForgeCommandLineArgument -Value $root) -WaitProcessId $($wait -join ',') -Reopen $Reopen"

    # O resultado anterior sairia como se fosse desta atualização.
    Remove-Item -LiteralPath (Join-Path (Get-WinForgeUpdateFolder) "result.json") -Force -ErrorAction SilentlyContinue

    if ((Test-WinForgeAdministrator) -or (Test-WinForgeFolderWritable -Root $root)) {
        Start-Process -FilePath (Get-WinForgePowerShellPath) -ArgumentList $arguments -WindowStyle Hidden -WorkingDirectory (Get-WinForgeUpdateFolder) -ErrorAction Stop
    }
    else {
        try {
            Start-Process -FilePath (Get-WinForgePowerShellPath) -ArgumentList $arguments -Verb RunAs -WindowStyle Hidden -WorkingDirectory (Get-WinForgeUpdateFolder) -ErrorAction Stop
        }
        catch {
            throw (Get-WinForgeText 'trocar os arquivos desta pasta pede o Administrador, e o pedido do Windows foi recusado')
        }
    }

    return $true
}


function Save-WinForgeUpdateResult {
    param (
        [string]$From = "",
        [string]$To = "",
        [bool]$Ok = $false,
        [string]$ErrorText = "",
        [bool]$RollbackFailed = $false
    )

    $folder = Get-WinForgeUpdateFolder
    if (-not (Test-Path -LiteralPath $folder)) { [void](New-Item -ItemType Directory -Path $folder -Force) }

    $document = [ordered]@{ From = $From; To = $To; Ok = $Ok; Error = $ErrorText; RollbackFailed = $RollbackFailed; At = (Get-Date).ToString("o", [System.Globalization.CultureInfo]::InvariantCulture) }
    Write-WinForgeStateJson -Path (Join-Path $folder "result.json") -InputObject $document
}


function Read-WinForgeUpdateResult {
    <#
    O resultado da última atualização, uma vez só (o arquivo é apagado ao ler): From, To, Ok, Error e RollbackFailed. $null
    quando não há, ou quando é velho demais para ser desta abertura. Depois de uma atualização que deu certo, a pasta do
    pacote extraído sai também.
    #>
    $folder = Get-WinForgeUpdateFolder
    $path = Join-Path $folder "result.json"

    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $null }

    $read = Read-WinForgeStateFile -Path $path
    Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath "$path.bak" -Force -ErrorAction SilentlyContinue

    if ($read.Status -notin @("Ok", "Recovered") -or $null -eq $read.Document) { return $null }

    $document = $read.Document
    $at = [datetime]::MinValue

    if (-not [datetime]::TryParse([string](Get-WinForgeJsonValue -Object $document -Name "At" -Default ""), [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind, [ref]$at)) { return $null }
    if (((Get-Date) - $at).TotalHours -gt $script:WinForgeUpdateResultHours) { return $null }

    $ok = [bool](Get-WinForgeJsonValue -Object $document -Name "Ok" -Default $false)

    if ($ok) { Remove-WinForgeFolder -Path (Join-Path $folder "pacote") -Quiet }

    return [PSCustomObject]@{
        From           = [string](Get-WinForgeJsonValue -Object $document -Name "From" -Default "")
        To             = [string](Get-WinForgeJsonValue -Object $document -Name "To" -Default "")
        Ok             = $ok
        Error          = [string](Get-WinForgeJsonValue -Object $document -Name "Error" -Default "")
        RollbackFailed = [bool](Get-WinForgeJsonValue -Object $document -Name "RollbackFailed" -Default $false)
    }
}


function Get-WinForgeUpdateResultText {
    # A mensagem que a janela (ou o menu) mostra ao abrir depois de uma atualização: Title e Text.
    param ([Parameter(Mandatory)]$Result)

    if ($Result.Ok) {
        return [PSCustomObject]@{ Ok = $true; Title = (Get-WinForgeText 'WinForge atualizado'); Text = (Get-WinForgeText 'O WinForge foi atualizado para a versão {0}.' "$($Result.To)") }
    }

    $text = $(if ($Result.RollbackFailed) {
            (Get-WinForgeText 'A atualização para a versão {0} não foi concluída ({1}), e alguns arquivos não voltaram sozinhos. A cópia dos arquivos anteriores está em {2}; se o WinForge não abrir direito, extraia de novo o WinForge.zip na pasta dele.' "$($Result.To)" "$($Result.Error)" "$(Join-Path (Get-WinForgeUpdateFolder) 'anterior')")
        }
        else {
            (Get-WinForgeText 'A atualização para a versão {0} não foi concluída ({1}). Nada mudou: o WinForge continua na versão {2}.' "$($Result.To)" "$($Result.Error)" "$($Result.From)")
        })

    return [PSCustomObject]@{ Ok = $false; Title = (Get-WinForgeText 'Atualização não concluída'); Text = $text }
}


function Install-WinForgeUpdatePackage {
    <#
    O lado do Setup na atualização (WinForge.Setup.ps1 -Update): roda da pasta da versão nova, sem janela. Espera o
    WinForge fechar, fecha o monitor desta pasta, troca os arquivos (com a volta ao que era), atualiza a versão em
    Aplicativos instalados, abre o monitor de novo se ele estava aberto e grava o resultado para o WinForge mostrar ao
    abrir. Abre o WinForge de novo em qualquer caso: na versão nova, ou na mesma, com o motivo.
    #>
    param (
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Target,
        [int[]]$WaitProcessId = @(),
        [ValidateSet("", "Gui", "Console")][string]$Reopen = ""
    )

    $from = Get-WinForgePackageBuild -Root $Target
    $to = Get-WinForgePackageBuild -Root $Source
    $agentWasOpen = $false
    $outcome = $null
    $errorText = ""

    try {
        $still = @(Wait-WinForgeProcessExit -ProcessId $WaitProcessId)

        # Um instante a mais: o cmd de um Prompt de Comando aberto à mão (que a troca não espera) ainda lê as últimas
        # linhas do WinForge-Console.cmd depois que o menu fecha.
        if ($still.Count -eq 0) { Start-Sleep -Seconds 2 }

        if (-not (Test-WinForgePackageFolder -Root $Target)) {
            # Só uma pasta que já tem o WinForge é atualizada: o Setup nunca troca arquivos de uma pasta qualquer.
            $errorText = (Get-WinForgeText 'a pasta {0} não tem o WinForge' "$Target")
        }
        elseif ($still.Count -gt 0) {
            $errorText = (Get-WinForgeText 'o WinForge não fechou a tempo')
        }
        elseif (@(Get-WinForgeRunningCopies -Root $Target | Where-Object { $_.Kind -ne "Agent" }).Count -gt 0) {
            # Outra janela ou outro menu desta pasta continua aberto: trocar os arquivos por baixo dele não é seguro.
            $errorText = (Get-WinForgeText 'outra janela do WinForge continua aberta')
        }
        else {
            $agentWasOpen = (@(Get-WinForgeRunningCopies -Root $Target | Where-Object { $_.Kind -eq "Agent" }).Count -gt 0)
            if ($agentWasOpen) { [void](Stop-WinForgeAgent) }

            $outcome = Install-WinForgeFiles -Source $Source -Target $Target -BackupFolder (Join-Path (Get-WinForgeUpdateFolder) "anterior")

            if ($outcome.Ok) { [void](Update-WinForgeInstallVersion -Root $Target -Build $to) } else { $errorText = $outcome.Error }
        }
    }
    catch {
        $errorText = ([string]$_.Exception.Message).TrimEnd('.')
    }

    $ok = ($null -ne $outcome -and $outcome.Ok)

    # Sem conseguir gravar o resultado, o WinForge abre do mesmo jeito (só sem a mensagem).
    try { Save-WinForgeUpdateResult -From $from -To $to -Ok $ok -ErrorText $errorText -RollbackFailed ($null -ne $outcome -and $outcome.RollbackFailed) } catch { Write-Verbose "Resultado: $($_.Exception.Message)" }

    if ($agentWasOpen) {
        try { [void](Start-WinForgeAgent -Root $Target) } catch { Write-Verbose "Monitor: $($_.Exception.Message)" }
    }

    if ($Reopen) { Open-WinForgeCopy -Root $Target -Kind $Reopen -Page "app" }

    return $ok
}


function Open-WinForgeCopy {
    # Abre a janela (ou o menu de texto) do WinForge da pasta Root, numa execução nova.
    param (
        [Parameter(Mandatory)][string]$Root,
        [ValidateSet("Gui", "Console")][string]$Kind = "Gui",
        [string]$Page = ""
    )

    try {
        if ($Kind -eq "Console") {
            Start-Process -FilePath (Join-Path $Root "WinForge-Console.cmd") -WorkingDirectory $Root -ErrorAction Stop
            return
        }

        $arguments = "-NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File $(ConvertTo-WinForgeCommandLineArgument -Value (Join-Path $Root 'WinForge.Gui.ps1'))"
        if ($Page -match '^[a-z]+$') { $arguments += " -Page $Page" }

        Start-Process -FilePath (Get-WinForgePowerShellPath) -ArgumentList $arguments -WindowStyle Hidden -WorkingDirectory $Root -ErrorAction Stop
    }
    catch {
        Write-Verbose "Abrir o WinForge: $($_.Exception.Message)"
    }
}


# ---------------------------------------------------------------------------
# Desinstalar
# ---------------------------------------------------------------------------

function Remove-WinForgeEmptyFolders {
    # Apaga as pastas do WinForge que ficaram vazias (de dentro para fora) e, vazia, a própria pasta Root.
    param ([Parameter(Mandatory)][string]$Root)

    foreach ($folder in $script:WinForgePackageFolders) {
        $path = Join-Path $Root $folder
        if (-not (Test-Path -LiteralPath $path -PathType Container)) { continue }

        foreach ($child in @(Get-ChildItem -LiteralPath $path -Recurse -Directory -Force -ErrorAction SilentlyContinue | Sort-Object { $_.FullName.Length } -Descending)) {
            if (@(Get-ChildItem -LiteralPath $child.FullName -Force -ErrorAction SilentlyContinue).Count -eq 0) { Remove-Item -LiteralPath $child.FullName -Force -ErrorAction SilentlyContinue }
        }

        if (@(Get-ChildItem -LiteralPath $path -Force -ErrorAction SilentlyContinue).Count -eq 0) { Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue }
    }

    if ((Test-Path -LiteralPath $Root -PathType Container) -and @(Get-ChildItem -LiteralPath $Root -Force -ErrorAction SilentlyContinue).Count -eq 0) {
        Remove-Item -LiteralPath $Root -Force -ErrorAction SilentlyContinue
    }
}


function Get-WinForgeSetupFiles {
    <#
    Os arquivos de que o WinForge.Setup.ps1 precisa para desinstalar desta pasta, como caminhos relativos: ele mesmo, os
    scripts que mostram que a pasta é do WinForge (Test-WinForgePackageFolder), os módulos que ele carrega, as traduções e
    o ícone da entrada em Aplicativos instalados.
    #>
    param ([Parameter(Mandatory)][string]$Root)

    $files = @("WinForge.Setup.ps1", "WinForge-Setup.cmd", "WinForge.Gui.ps1", "WinForge.Console.ps1", "WinForge.cmd",
        (Join-Path "modules" "Modules.psd1"), (Join-Path "modules" "Core.psm1"), (Join-Path "gui" "MainWindow.xaml"), (Join-Path "assets" "WinForge.ico"))

    try {
        $manifest = Import-PowerShellDataFile -LiteralPath (Join-Path (Join-Path $Root "modules") "Modules.psd1") -ErrorAction Stop
        foreach ($name in @($manifest.Common)) { $files += (Join-Path "modules" "$name.psm1") }
    }
    catch {
        Write-Verbose "Módulos do Setup: $($_.Exception.Message)"
    }

    foreach ($file in @(Get-WinForgePackageFiles -Root $Root)) {
        if (($file -split '[\\/]')[0] -eq "lang") { $files += $file }
    }

    return @($files | Select-Object -Unique)
}


function Remove-WinForgePackageFileList {
    # Apaga arquivos do WinForge (caminhos relativos a Root). O que não sai na primeira vez (preso por um instante, pelo
    # antivírus ou pelo indexador) ganha mais uma tentativa um segundo depois. Devolve os que ficaram.
    param (
        [Parameter(Mandatory)][string]$Root,
        [string[]]$Files = @()
    )

    $left = @($Files)

    for ($attempt = 0; $attempt -lt 2 -and $left.Count -gt 0; $attempt++) {
        if ($attempt -gt 0) { Start-Sleep -Seconds 1 }

        $failed = @()

        foreach ($relative in $left) {
            $path = Join-Path $Root $relative

            try {
                if (Test-Path -LiteralPath $path -PathType Leaf) {
                    [System.IO.File]::SetAttributes($path, [System.IO.FileAttributes]::Normal)
                    [System.IO.File]::Delete($path)
                }
            }
            catch {
                $failed += $relative
            }
        }

        $left = @($failed)
    }

    return @($left)
}


function Get-WinForgeInteractiveUserPlaces {
    <#
    Com o WinForge elevado pela conta de outro Administrador: onde ficam o monitor e os atalhos da conta de quem usa o PC
    (a chave Run dela e as pastas Área de Trabalho e Menu Iniciar\Programas), para o desinstalar alcançá-los. $null fora
    desse caso ou sem leitura (a conta precisa estar com a sessão aberta).
    #>
    if (-not (Test-WinForgeUserContextMismatch)) { return $null }

    try {
        $account = Get-WinForgeInteractiveUser
        $sid = (New-Object System.Security.Principal.NTAccount($account)).Translate([System.Security.Principal.SecurityIdentifier]).Value
        $hive = "Registry::HKEY_USERS\$sid"

        if (-not (Test-Path -LiteralPath $hive)) { return $null }

        $folders = Get-ItemProperty -LiteralPath "$hive\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders" -ErrorAction Stop
        $shortcutFolders = @(@([string](Get-WinForgeJsonValue -Object $folders -Name "Desktop" -Default ""), [string](Get-WinForgeJsonValue -Object $folders -Name "Programs" -Default "")) |
                Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Container) })

        return [PSCustomObject]@{ Account = $account; RunKey = "$hive\Software\Microsoft\Windows\CurrentVersion\Run"; ShortcutFolders = @($shortcutFolders) }
    }
    catch {
        Write-Verbose "Conta de quem usa o PC: $($_.Exception.Message)"
        return $null
    }
}


function Uninstall-WinForge {
    <#
    Tira o WinForge da pasta Root e do Windows: fecha o monitor e tira a entrada que o abre com o Windows, apaga a
    manutenção agendada desta pasta, os atalhos que abrem esta pasta (os do instalador e os criados pelo WinForge), a
    entrada em Aplicativos instalados e os arquivos do WinForge (o que a pessoa pôs na pasta fica). -RemoveData apaga
    também %LOCALAPPDATA%\WinForge (históricos, relatórios, logs e backups). Os ajustes do Windows aplicados continuam.
    Devolve Ok, Steps (o que foi feito) e Problems (o que não deu).
    #>
    param (
        [Parameter(Mandatory)][string]$Root,
        [switch]$RemoveData
    )

    $steps = @()
    $problems = @()

    # Elevado pela conta de outro Administrador, o monitor e os atalhos da conta de quem usa o PC também saem.
    $person = Get-WinForgeInteractiveUserPlaces

    # O monitor: fecha e não abre mais com o Windows (se a entrada é desta pasta).
    try {
        if (@(Get-WinForgeRunningCopies -Root $Root | Where-Object { $_.Kind -eq "Agent" }).Count -gt 0) { [void](Stop-WinForgeAgent) }

        $agentScript = Join-Path $Root "WinForge.Agent.ps1"
        $removedEntry = Remove-WinForgeAgentStaleEntry -ScriptPath $agentScript
        if ($null -ne $person -and (Remove-WinForgeAgentStaleEntry -ScriptPath $agentScript -RunKey $person.RunKey)) { $removedEntry = $true }
        if ($removedEntry) { $steps += (Get-WinForgeText 'monitor na bandeja desligado') }
    }
    catch {
        $problems += (Get-WinForgeText 'monitor na bandeja: {0}' "$(([string]$_.Exception.Message).TrimEnd('.'))")
    }

    # A manutenção agendada, se ela roda esta pasta.
    try {
        $schedule = Get-WinForgeScheduleStatus

        if ($schedule.Installed -and $schedule.ScriptPath -and (Test-WinForgePathInside -Path $schedule.ScriptPath -Folder $Root)) {
            $removed = Unregister-WinForgeScheduledMaintenance
            if ($removed.Kind -eq "Ok") { $steps += (Get-WinForgeText 'manutenção agendada removida') } else { $problems += (Get-WinForgeText 'manutenção agendada: {0}' "$($removed.Detail)") }
        }
    }
    catch {
        $problems += (Get-WinForgeText 'manutenção agendada: {0}' "$(([string]$_.Exception.Message).TrimEnd('.'))")
    }

    # O que sobrou de uma execução sem Administrador interrompida (uma tarefa de uma vez só, sem horário): nunca dá erro.
    Remove-WinForgeLimitedRunLeftovers -All

    # Os atalhos que abrem esta pasta: os do instalador (todos os usuários) e os que o WinForge criou para esta conta (e
    # para a de quem usa o PC).
    $links = @(Get-WinForgeCommonShortcutPaths | ForEach-Object { $_.Path })
    $names = @("WinForge.lnk")

    foreach ($place in @(Get-WinForgeShortcutLocation)) {
        $links += $place.Path
        $names += (Split-Path -Leaf $place.Path)
    }

    if ($null -ne $person) {
        foreach ($folder in @($person.ShortcutFolders)) {
            foreach ($name in @($names | Select-Object -Unique)) { $links += (Join-Path $folder $name) }
        }
    }

    $linkCount = 0

    foreach ($link in @($links | Select-Object -Unique)) {
        if (-not (Test-WinForgeShortcutOpens -Path $link -Root $Root)) { continue }

        try {
            Remove-Item -LiteralPath $link -Force -ErrorAction Stop
            $linkCount++
        }
        catch {
            $problems += (Get-WinForgeText 'atalho {0}: {1}' "$link" "$(([string]$_.Exception.Message).TrimEnd('.'))")
        }
    }

    if ($linkCount -gt 0) { $steps += (Format-WinForgeCount -Count $linkCount -One (Get-WinForgeText 'atalho removido') -Many (Get-WinForgeText 'atalhos removidos')) }

    # Os arquivos do WinForge (e as pastas que ficarem vazias). Os de que desinstalar precisa (Get-WinForgeSetupFiles)
    # saem por último, só quando todos os outros saíram: com algum arquivo preso, o WinForge continua em Aplicativos
    # instalados, e desinstalar de novo por lá termina o serviço.
    $files = @(Get-WinForgePackageFiles -Root $Root)
    $setupFiles = @(Get-WinForgeSetupFiles -Root $Root)
    $failed = @(Remove-WinForgePackageFileList -Root $Root -Files @($files | Where-Object { $setupFiles -notcontains $_ }))
    $keepEntry = ($failed.Count -gt 0)

    if (-not $keepEntry) { $failed = @(Remove-WinForgePackageFileList -Root $Root -Files @($files | Where-Object { $setupFiles -contains $_ })) }

    Remove-WinForgeEmptyFolders -Root $Root

    # Aplicativos instalados: a entrada sai com os arquivos.
    if (-not $keepEntry) {
        try {
            $registration = Get-WinForgeInstallRegistration

            if ($null -ne $registration -and (Test-WinForgeSamePath -Path $registration.Location -Other $Root)) {
                Unregister-WinForgeInstall
                $steps += (Get-WinForgeText 'saiu de Aplicativos instalados')
            }
        }
        catch {
            $problems += (Get-WinForgeText 'Aplicativos instalados: {0}' "$(([string]$_.Exception.Message).TrimEnd('.'))")
        }
    }

    if ($failed.Count -gt 0) {
        $problems += $(if ($failed.Count -eq 1) { (Get-WinForgeText '1 arquivo não pôde ser apagado de {0}' "$Root") }
            else { (Get-WinForgeText '{0} não puderam ser apagados de {1}' "$(Format-WinForgeCount -Count $failed.Count -One (Get-WinForgeText 'arquivo') -Many (Get-WinForgeText 'arquivos'))" "$Root") })
        if ($keepEntry -and (Test-WinForgeInstalledHere -Root $Root)) { $problems += (Get-WinForgeText 'o WinForge continua em Configurações > Aplicativos: desinstale de novo por lá para terminar') }
    }
    else {
        $steps += (Get-WinForgeText 'arquivos do WinForge apagados')
    }

    if (Test-Path -LiteralPath $Root -PathType Container) { $steps += (Get-WinForgeText 'a pasta {0} ficou, com o que não é do WinForge' "$Root") }

    if ($RemoveData) {
        try {
            # Sempre um caminho completo: um "WinForge" relativo apagaria a pasta de mesmo nome do diretório atual.
            $data = Join-Path (Get-WinForgeLocalAppDataPath) "WinForge"

            # O log desta desinstalação fica aberto até o fim: tudo o mais sai.
            Stop-WinForgeLogging
            Remove-WinForgeFolder -Path $data
            $steps += (Get-WinForgeText 'dados do WinForge apagados')
        }
        catch {
            $problems += (Get-WinForgeText 'dados do WinForge: {0}' "$(([string]$_.Exception.Message).TrimEnd('.'))")
        }
    }

    return [PSCustomObject]@{ Ok = ($problems.Count -eq 0); Steps = @($steps); Problems = @($problems) }
}


Export-ModuleMember -Function *
