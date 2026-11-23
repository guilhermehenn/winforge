# Núcleo: ambiente, sessão, registro, log, formatação e execução de programas nativos.
# Nada aqui desenha cabeçalhos ou faz perguntas; isso fica em Console.psm1.

$script:WinForgeBuild = "4.0"

# A trava dos arquivos de estado (Invoke-WinForgeStateLock): uma por sessão do Windows.
$script:WinForgeStateLockName = "Local\WinForge.State"

# O build do Windows, lido uma vez (Get-WinForgeWindowsBuild).
$script:WinForgeWindowsBuild = 0
$script:WinForgeSession = $null
$script:WinForgeLastMaintenance = $null
$script:WinForgeLogPath = $null
$script:WinForgeLoggingActive = $false
# Transcript (console) ou Gui (o host da janela grava o log); Start-WinForgeLogging escolhe.
$script:WinForgeLogMode = ""

# Se o PC usa o Modern Standby, lido uma vez (Test-WinForgeModernStandby); $null até a primeira leitura.
$script:WinForgeModernStandby = $null

# Limites de Get-WinForgeDiskSpaceLevel. Na unidade do Windows, o que conta é o espaço que ele precisa para se
# atualizar (de 6 a 11 GB numa atualização de versão, mais no Windows 11): abaixo de 10 GB livres é "Critical"; abaixo de
# 20 GB, "Low". Nas outras unidades, a proporção: abaixo de 5% livres é "Critical"; abaixo de 10%, "Low".
$script:WinForgeCriticalDiskBytes = 10GB
$script:WinForgeLowDiskBytes = 20GB
$script:WinForgeLowDiskPercent = 10


# ---------------------------------------------------------------------------
# Versão e pasta de dados
# ---------------------------------------------------------------------------

function Get-WinForgeBuild {
    return $script:WinForgeBuild
}


function Test-WinForgeGuiMode {
    # Verdadeiro dentro da janela: o executor das ações define $global:WinForgeGuiMode. A leitura não falha quando a
    # variável não existe (console), nem sob Set-StrictMode.
    $variable = Get-Variable -Name WinForgeGuiMode -Scope Global -ErrorAction SilentlyContinue

    return ($null -ne $variable -and [bool]$variable.Value)
}


function Request-WinForgeAppExit {
    <#
    Pede ao WinForge que feche quando a ação terminar (a atualização com um clique: o instalador espera este processo
    fechar para trocar os arquivos). Vale para o processo inteiro: a ação roda num runspace e a janela, em outro.
    #>
    param ([string]$Reason = "update")

    [AppDomain]::CurrentDomain.SetData("WinForge.ExitRequest", $Reason)
}


function Get-WinForgeAppExitRequest {
    # O motivo do pedido de fechar (Request-WinForgeAppExit), ou "" sem pedido.
    $value = [AppDomain]::CurrentDomain.GetData("WinForge.ExitRequest")

    return $(if ($null -eq $value) { "" } else { [string]$value })
}


function Get-WinForgeLocalAppDataPath {
    <#
    A pasta LocalAppData do usuário, sempre um caminho completo. Sem a variável LOCALAPPDATA (um acesso remoto que abre o
    PowerShell sem o ambiente do perfil, por exemplo), vale a pasta que o Windows informa para a conta; sem nenhuma das
    duas, lança erro: um "WinForge" relativo cairia na pasta atual, e apagar os dados apagaria outra coisa.
    #>
    $path = [string]$env:LOCALAPPDATA

    if ([string]::IsNullOrWhiteSpace($path) -or -not [System.IO.Path]::IsPathRooted($path)) {
        $path = [string][Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData)
    }

    if ([string]::IsNullOrWhiteSpace($path) -or -not [System.IO.Path]::IsPathRooted($path)) {
        throw (Get-WinForgeText 'A pasta de dados do usuário (LocalAppData) não foi encontrada.')
    }

    return $path
}


function Get-WinForgeDataPath {
    # Local persistente para logs, backups de ajustes e relatórios (por usuário elevado).
    $root = Join-Path (Get-WinForgeLocalAppDataPath) "WinForge"

    if (-not (Test-Path -LiteralPath $root)) {
        [void](New-Item -Path $root -ItemType Directory -Force)
    }

    return $root
}


# ---------------------------------------------------------------------------
# Arquivos de estado (JSON na pasta de dados)
# ---------------------------------------------------------------------------
# A janela, a ação em andamento (outro runspace do mesmo processo), o monitor na bandeja e a tarefa agendada leem e
# gravam os mesmos arquivos. Três regras evitam perder dados:
#   - gravar é atômico: um arquivo temporário com nome único e a troca pelo Windows (File.Replace), que guarda a versão
#     anterior em ".bak"; nunca há um instante em que o arquivo não existe;
#   - ler distingue "não existe" de "não deu para ler": um arquivo estragado volta do ".bak" (e a cópia estragada fica
#     guardada ao lado); um arquivo preso por outro processo faz a gravação desistir, em vez de gravar quase nada por cima;
#   - quem lê, altera e grava faz isso dentro da trava (Invoke-WinForgeStateLock).

function Open-WinForgeNamedMutex {
    <#
    Um mutex com nome que a janela elevada e a não elevada do mesmo usuário (e o monitor, nunca elevado) compartilham.
    Quem cria dá acesso total ao usuário (a conta elevada e a comum têm o mesmo SID). Quem chega depois num processo de
    nível de integridade menor (o monitor, quando foi a janela elevada que criou o mutex) não pode pedir acesso total:
    o Windows recusa "escrever para cima". Esse abre só com Synchronize e Modify, o que basta para esperar e soltar.
    $null quando nada deu certo.
    #>
    param ([Parameter(Mandatory)][string]$Name)

    try {
        $security = New-Object System.Security.AccessControl.MutexSecurity
        $user = [System.Security.Principal.WindowsIdentity]::GetCurrent().User
        $security.AddAccessRule((New-Object System.Security.AccessControl.MutexAccessRule($user, [System.Security.AccessControl.MutexRights]::FullControl, [System.Security.AccessControl.AccessControlType]::Allow)))
        $createdNew = $false
        return (New-Object System.Threading.Mutex($false, $Name, [ref]$createdNew, $security))
    }
    catch {
        # Existe e foi criado por um processo elevado (acesso total recusado), ou o sistema não tem essas permissões.
    }

    try {
        return [System.Threading.Mutex]::OpenExisting($Name, [System.Security.AccessControl.MutexRights]"Synchronize, Modify")
    }
    catch {
        # Não existe, ou a versão do .NET não tem esta forma de abrir.
    }

    try {
        return (New-Object System.Threading.Mutex($false, $Name))
    }
    catch {
        return $null
    }
}


function Invoke-WinForgeStateLock {
    # Roda o bloco com a trava dos arquivos de estado: um mutex com nome, da sessão do Windows, que a conta elevada e a
    # não elevada do mesmo usuário conseguem abrir. A trava é reentrante (uma função que já a tem pode chamar outra que
    # também a pede). Sem conseguir a trava em 5 segundos, segue sem ela: atrasar é aceitável, travar o WinForge não.
    # As variáveis daqui têm nomes próprios: o bloco enxerga as da função que o chamou e não deve confundi-las com estas.
    param (
        [Parameter(Mandatory)][scriptblock]$ScriptBlock
    )

    $stateLockMutex = $null
    $stateLockOwned = $false

    try {
        $stateLockMutex = Open-WinForgeNamedMutex -Name $script:WinForgeStateLockName

        if ($null -ne $stateLockMutex) {
            try { $stateLockOwned = $stateLockMutex.WaitOne(5000) } catch [System.Threading.AbandonedMutexException] { $stateLockOwned = $true }
        }

        return (& $ScriptBlock)
    }
    finally {
        if ($stateLockOwned) { $stateLockMutex.ReleaseMutex() }
        if ($null -ne $stateLockMutex) { $stateLockMutex.Dispose() }
    }
}


function Read-WinForgeStateFile {
    <#
    Lê um arquivo de estado JSON. Devolve Status e Document:
      Missing    - não existe: comece do zero (a gravação atômica nunca deixa o arquivo sumir; se ele não está lá, nunca
                   foi gravado ou alguém o apagou de propósito, e a cópia anterior não volta);
      Ok         - lido;
      Recovered  - o arquivo estava estragado e a cópia anterior (.bak) foi lida; o estragado fica guardado como
                   ".corrompido-<data>";
      Unreadable - existe, mas não deu para ler (preso por outro programa, sem permissão): quem grava deve desistir.
    Um arquivo estragado sem cópia anterior também é guardado ao lado e conta como Missing.
    #>
    param (
        [Parameter(Mandatory)][string]$Path
    )

    $backup = "$Path.bak"

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return [PSCustomObject]@{ Status = "Missing"; Document = $null }
    }

    $text = $null

    # Outro processo pode estar no meio da troca do arquivo: tenta de novo algumas vezes antes de desistir.
    for ($attempt = 1; $attempt -le 4; $attempt++) {
        try {
            $text = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
            break
        }
        catch [System.IO.FileNotFoundException] {
            return (Read-WinForgeStateFile -Path $Path)
        }
        catch {
            if ($attempt -eq 4) { return [PSCustomObject]@{ Status = "Unreadable"; Document = $null } }
            Start-Sleep -Milliseconds (40 * $attempt)
        }
    }

    $document = ConvertFrom-WinForgeStateText -Text $text

    if ($null -ne $document) { return [PSCustomObject]@{ Status = "Ok"; Document = $document } }

    # Estragado (truncado, vazio, outro formato): guarda a cópia para quem quiser recuperar à mão e tenta a anterior.
    try {
        $stamp = (Get-Date).ToString("yyyyMMddHHmmss", [System.Globalization.CultureInfo]::InvariantCulture)
        Move-Item -LiteralPath $Path -Destination "$Path.corrompido-$stamp" -Force -ErrorAction Stop
    }
    catch {
        return [PSCustomObject]@{ Status = "Unreadable"; Document = $null }
    }

    Remove-WinForgeOldCorruptCopies -Path $Path

    $fromBackup = ConvertFrom-WinForgeStateText -Path $backup

    if ($null -ne $fromBackup) {
        # A cópia anterior volta para o lugar do arquivo: quem lê primeiro quase nunca é quem grava (a janela, o Início, a
        # página), e sem isso a leitura seguinte veria o arquivo como inexistente, e a gravação seguinte trocaria a cópia
        # boa por uma quase vazia (o histórico de mudanças perderia o desfazer de vez).
        try {
            [System.IO.File]::Copy($backup, $Path, $false)
        }
        catch {
            Write-Verbose "Não foi possível repor a cópia de $($Path): $($_.Exception.Message)"
        }

        return [PSCustomObject]@{ Status = "Recovered"; Document = $fromBackup }
    }

    return [PSCustomObject]@{ Status = "Missing"; Document = $null }
}


function Remove-WinForgeOldCorruptCopies {
    # Guarda só as três cópias estragadas mais recentes de um arquivo de estado (".corrompido-<data>"): elas existem para
    # quem quiser recuperar algo à mão, e um arquivo que estraga sempre não pode encher a pasta.
    param ([Parameter(Mandatory)][string]$Path)

    try {
        $folder = Split-Path -Path $Path -Parent
        $name = Split-Path -Path $Path -Leaf
        $copies = @(Get-ChildItem -LiteralPath $folder -Filter "$name.corrompido-*" -File -ErrorAction Stop | Sort-Object -Property Name -Descending)

        foreach ($old in @($copies | Select-Object -Skip 3)) {
            Remove-Item -LiteralPath $old.FullName -Force -ErrorAction SilentlyContinue
        }
    }
    catch {
        Write-Verbose "Cópias estragadas de $($Path): $($_.Exception.Message)"
    }
}


function ConvertFrom-WinForgeStateText {
    # O JSON de um texto (ou de um arquivo, com -Path), ou $null se não for um JSON com conteúdo.
    param (
        [AllowNull()][string]$Text = $null,
        [string]$Path = ""
    )

    try {
        if ($Path) {
            if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
            $Text = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
        }

        if ([string]::IsNullOrWhiteSpace($Text)) { return $null }

        $document = $Text | ConvertFrom-Json -ErrorAction Stop

        # Uma lista JSON vazia é um conteúdo válido; $null não.
        if ($null -eq $document -and $Text.Trim() -ne "[]") { return $null }
        if ($Text.Trim() -eq "[]") { return , @() }

        return $document
    }
    catch {
        return $null
    }
}


function Write-WinForgeStateFile {
    # Grava o texto (UTF-8 com BOM, como o Set-Content do Windows PowerShell) de forma atômica: escreve um temporário com
    # nome único na mesma pasta e troca pelo arquivo, guardando o anterior em ".bak". Lança erro se não conseguir.
    param (
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Text
    )

    $temporary = "$Path.$PID-$([guid]::NewGuid().ToString('N').Substring(0, 8)).tmp"

    try {
        [System.IO.File]::WriteAllText($temporary, $Text, (New-Object System.Text.UTF8Encoding($true)))

        if (Test-Path -LiteralPath $Path -PathType Leaf) {
            [System.IO.File]::Replace($temporary, $Path, "$Path.bak", $true)
        }
        else {
            [System.IO.File]::Move($temporary, $Path)
        }
    }
    finally {
        if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Force -ErrorAction SilentlyContinue }
    }
}


function Write-WinForgeStateJson {
    # Write-WinForgeStateFile de um objeto. Uma lista continua lista no JSON mesmo com um item só (-AsList).
    param (
        [Parameter(Mandatory)][string]$Path,
        [AllowNull()]$InputObject,
        [int]$Depth = 6,
        [switch]$AsList
    )

    $json = $(if ($AsList) { ConvertTo-Json -InputObject @($InputObject) -Depth $Depth } else { ConvertTo-Json -InputObject $InputObject -Depth $Depth })

    # Uma lista vazia vira "" no ConvertTo-Json do Windows PowerShell.
    if ($AsList -and [string]::IsNullOrWhiteSpace($json)) { $json = "[]" }

    Write-WinForgeStateFile -Path $Path -Text $json
}


# ---------------------------------------------------------------------------
# Preferências do WinForge (settings.json)
# ---------------------------------------------------------------------------

function Get-WinForgeSettingsPath {
    return (Join-Path (Get-WinForgeDataPath) "settings.json")
}


function Get-WinForgeSettings {
    # Todas as preferências como hashtable. Arquivo ausente ou ilegível = nenhuma preferência (um arquivo estragado volta
    # da cópia anterior, ver Read-WinForgeStateFile). -Status devolve também o estado da leitura, para quem vai gravar.
    param ([switch]$Status)

    $settings = @{}
    $read = [PSCustomObject]@{ Status = "Unreadable"; Document = $null }

    try {
        $read = Read-WinForgeStateFile -Path (Get-WinForgeSettingsPath)

        if ($null -ne $read.Document) {
            foreach ($property in $read.Document.PSObject.Properties) {
                $settings[[string]$property.Name] = $property.Value
            }
        }
    }
    catch {
        $settings = @{}
    }

    if ($Status) { return [PSCustomObject]@{ Status = $read.Status; Settings = $settings } }

    return $settings
}


function Get-WinForgeSetting {
    param (
        [Parameter(Mandatory)][string]$Name,
        $Default = $null
    )

    $settings = Get-WinForgeSettings

    if ($settings.ContainsKey($Name) -and $null -ne $settings[$Name]) {
        return $settings[$Name]
    }

    return $Default
}


function Get-WinForgeLastCheckup {
    # Quando o Verificar o PC rodou pela última vez (a preferência LastCheckup, gravada no fim dele), ou $null. O Início e
    # o monitor contam essa data como um cuidado com o PC, assim como a última manutenção. -Strict: preferências que
    # existem, mas não puderam ser lidas, são um erro, e não "nunca verificou".
    param ([switch]$Strict)

    $read = Get-WinForgeSettings -Status

    if ($Strict -and [string]$read.Status -eq "Unreadable") { throw (Get-WinForgeText 'As preferências do WinForge existem, mas não puderam ser lidas.') }

    $value = $(if ($read.Settings.ContainsKey("LastCheckup") -and $null -ne $read.Settings["LastCheckup"]) { $read.Settings["LastCheckup"] } else { "" })

    if ($value -is [datetime]) { return $value }

    $when = [datetime]::MinValue

    if ([string]$value -and [datetime]::TryParse([string]$value, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$when)) {
        return $when
    }

    return $null
}


function Set-WinForgeSetting {
    # Grava uma preferência (valor simples, hashtable ou lista) sem perder as outras. Falha em silêncio: uma
    # preferência que não pôde ser salva nunca deve interromper uma ação.
    param (
        [Parameter(Mandatory)][string]$Name,
        [AllowNull()]$Value
    )

    try {
        return [bool](Invoke-WinForgeStateLock -ScriptBlock {
                $current = Get-WinForgeSettings -Status

                # Sem conseguir ler o que já está gravado, gravar agora apagaria as outras preferências.
                if ($current.Status -eq "Unreadable") { return $false }

                $settings = $current.Settings
                $settings[$Name] = $Value

                $ordered = [ordered]@{}
                foreach ($key in ($settings.Keys | Sort-Object)) { $ordered[$key] = $settings[$key] }

                Write-WinForgeStateJson -Path (Get-WinForgeSettingsPath) -InputObject $ordered -Depth 5
                return $true
            })
    }
    catch {
        return $false
    }
}


# ---------------------------------------------------------------------------
# Idioma da interface: português, inglês ou espanhol
# ---------------------------------------------------------------------------

# Os idiomas da interface. O português é o do código: como no gettext, o texto em português é a chave das traduções,
# que ficam em lang\en.po e lang\es.po. Em português, nada é lido.
$script:WinForgeLanguages = @("pt", "en", "es")
$script:WinForgeLanguage = $null
$script:WinForgeLanguageResolving = $false
$script:WinForgeTextTable = $null
$script:WinForgeTextLoading = $false


function Get-WinForgeSystemLanguage {
    # O idioma da interface pelo idioma de exibição do Windows: português, inglês ou espanhol; qualquer outro, inglês.
    $code = ""

    try { $code = [string][System.Globalization.CultureInfo]::CurrentUICulture.TwoLetterISOLanguageName } catch { $code = "" }

    if ($code -in $script:WinForgeLanguages) { return $code }

    return "en"
}


function Get-WinForgeLanguagePreference {
    # A escolha em Sobre o WinForge > Idioma: "Auto" (o do Windows), "pt", "en" ou "es".
    $value = ""

    try { $value = [string](Get-WinForgeSetting -Name "Language" -Default "Auto") } catch { $value = "" }

    if ($value -in $script:WinForgeLanguages) { return $value }

    return "Auto"
}


function Set-WinForgeLanguagePreference {
    # Grava a escolha do idioma. Vale na próxima vez que o WinForge abrir: as telas já montadas ficam como estão.
    param (
        [Parameter(Mandatory)][ValidateSet("Auto", "pt", "en", "es")][string]$Language
    )

    return (Set-WinForgeSetting -Name "Language" -Value $Language)
}


function Get-WinForgeLanguageFor {
    # O idioma que uma escolha do cartão Idioma dá: o próprio, ou o do Windows com "Auto".
    param ([AllowEmptyString()][string]$Preference = "Auto")

    if ($Preference -in $script:WinForgeLanguages) { return $Preference }

    return (Get-WinForgeSystemLanguage)
}


function Resolve-WinForgeLanguage {
    # Nesta ordem: WINFORGE_LANG (o -Language do menu de texto), a escolha em Sobre o WinForge e o idioma do Windows.
    $override = ([string]$env:WINFORGE_LANG).Trim().ToLowerInvariant()

    if ($override.Length -gt 2) { $override = $override.Substring(0, 2) }
    if ($override -in $script:WinForgeLanguages) { return $override }

    return (Get-WinForgeLanguageFor -Preference (Get-WinForgeLanguagePreference))
}


function Get-WinForgeLanguage {
    # O idioma em uso ("pt", "en" ou "es"). É resolvido uma vez por processo: a janela, as leituras do Início e as ações
    # rodam em runspaces diferentes do mesmo processo e precisam falar a mesma língua, mesmo que a escolha mude no meio.
    if ($null -ne $script:WinForgeLanguage) { return $script:WinForgeLanguage }

    $shared = [string][AppDomain]::CurrentDomain.GetData("WinForge.Language")

    if ($shared -in $script:WinForgeLanguages) {
        $script:WinForgeLanguage = $shared
        return $shared
    }

    # Ler as preferências pode escrever uma mensagem (e pedir o idioma de novo): enquanto isso, vale o do Windows.
    if ($script:WinForgeLanguageResolving) { return (Get-WinForgeSystemLanguage) }

    $script:WinForgeLanguageResolving = $true

    try {
        $language = Resolve-WinForgeLanguage
    }
    finally {
        $script:WinForgeLanguageResolving = $false
    }

    $script:WinForgeLanguage = $language
    [AppDomain]::CurrentDomain.SetData("WinForge.Language", $language)

    return $language
}


function Get-WinForgeLanguageFolder {
    # A pasta lang, ao lado de modules.
    return (Join-Path (Split-Path -Parent $PSScriptRoot) "lang")
}


function ConvertFrom-WinForgePoString {
    # O texto de uma linha de .po, sem as aspas e com \n, \t, \r, \" e \\ decodificados.
    param ([string]$Line)

    $first = $Line.IndexOf('"')
    $last = $Line.LastIndexOf('"')

    if ($first -lt 0 -or $last -le $first) { return "" }

    $text = $Line.Substring($first + 1, $last - $first - 1)

    if ($text.IndexOf('\') -lt 0) { return $text }

    $builder = New-Object System.Text.StringBuilder
    $i = 0

    while ($i -lt $text.Length) {
        $ch = $text[$i]

        if ($ch -eq '\' -and ($i + 1) -lt $text.Length) {
            $next = $text[$i + 1]

            if ($next -ceq 'n') { [void]$builder.Append([char]10) }
            elseif ($next -ceq 't') { [void]$builder.Append([char]9) }
            elseif ($next -ceq 'r') { [void]$builder.Append([char]13) }
            else { [void]$builder.Append($next) }

            $i += 2
            continue
        }

        [void]$builder.Append($ch)
        $i++
    }

    return $builder.ToString()
}


function Read-WinForgeTextCatalog {
    <#
    Lê um arquivo .po (gettext) como um dicionário: o texto em português (msgid) e a tradução (msgstr). Ficam de fora o
    cabeçalho (msgid vazio), as traduções vazias e as marcadas como "fuzzy" (a conferir): nesses casos vale o português.
    Um texto com contexto (msgctxt) entra como contexto + caractere 4 + texto, a chave que Get-WinForgeContextText procura.
    O arquivo tem milhares de linhas e é lido ao abrir: o texto entre as aspas sai aqui mesmo, e ConvertFrom-WinForgePoString
    (uma chamada de função, cara no PowerShell) só entra quando a linha tem barra invertida, o que é raro.
    #>
    param ([Parameter(Mandatory)][string]$Path)

    $table = New-Object 'System.Collections.Generic.Dictionary[string,string]' ([System.StringComparer]::Ordinal)
    $lines = [System.IO.File]::ReadAllLines($Path, [System.Text.Encoding]::UTF8)
    $count = $lines.Length
    $context = $null
    $id = $null
    $text = $null
    $field = ""
    $fuzzy = $false

    # Uma linha vazia a mais, depois da última, fecha a última entrada.
    for ($n = 0; $n -le $count; $n++) {
        if ($n -lt $count) { $line = $lines[$n].Trim() } else { $line = "" }

        if ($line.Length -eq 0 -or ($field -eq "str" -and ($line.StartsWith("#") -or $line.StartsWith("msgctxt ") -or $line.StartsWith("msgid ")))) {
            if ($null -ne $id -and $null -ne $text -and $id.Length -gt 0 -and $text.Length -gt 0 -and -not $fuzzy) {
                if ($null -ne $context) { $id = $context + [char]4 + $id }

                $table[$id] = $text
            }

            $context = $null
            $id = $null
            $text = $null
            $field = ""
            $fuzzy = $false
        }

        if ($line.Length -eq 0) { continue }

        if ($line.StartsWith("#")) {
            if ($line.StartsWith("#,") -and $line.Contains("fuzzy")) { $fuzzy = $true }
            continue
        }

        # O mesmo que ConvertFrom-WinForgePoString devolve: o que está entre a primeira e a última aspa, decodificado.
        $first = $line.IndexOf('"')
        $last = $line.LastIndexOf('"')
        $value = ""
        if ($first -ge 0 -and $last -gt $first) { $value = $line.Substring($first + 1, $last - $first - 1) }
        if ($value.IndexOf('\') -ge 0) { $value = ConvertFrom-WinForgePoString -Line $line }

        if ($line.StartsWith("msgctxt ")) { $context = $value; $field = "ctxt"; continue }
        if ($line.StartsWith("msgid ")) { $id = $value; $field = "id"; continue }
        if ($line.StartsWith("msgstr ")) { $text = $value; $field = "str"; continue }

        if ($first -eq 0) {
            if ($field -eq "ctxt") { $context += $value }
            elseif ($field -eq "id") { $id += $value }
            elseif ($field -eq "str") { $text += $value }
        }
    }

    return $table
}


function Get-WinForgeTextTable {
    # As traduções do idioma em uso: lidas uma vez por processo e divididas entre os runspaces. Em português, vazia.
    # $null enquanto a própria carga roda (uma mensagem escrita no meio dela sai em português).
    if ($null -ne $script:WinForgeTextTable) { return $script:WinForgeTextTable }
    if ($script:WinForgeTextLoading) { return $null }

    $script:WinForgeTextLoading = $true

    try {
        $language = Get-WinForgeLanguage
        $key = "WinForge.Text.$language"
        $table = [AppDomain]::CurrentDomain.GetData($key)

        if ($null -eq $table) {
            $table = New-Object 'System.Collections.Generic.Dictionary[string,string]' ([System.StringComparer]::Ordinal)

            if ($language -ne "pt") {
                $path = Join-Path (Get-WinForgeLanguageFolder) "$language.po"

                try {
                    $table = Read-WinForgeTextCatalog -Path $path
                }
                catch {
                    Write-Verbose "Tradução não lida ($path): $($_.Exception.Message)"
                }
            }

            [AppDomain]::CurrentDomain.SetData($key, $table)
        }

        $script:WinForgeTextTable = $table
        return $table
    }
    finally {
        $script:WinForgeTextLoading = $false
    }
}


function Get-WinForgeText {
    <#
    O texto da interface no idioma do WinForge. Como no gettext, o texto em português é a chave: em português ele volta
    como está; em inglês e espanhol, a tradução (sem tradução, o próprio português). Os argumentos preenchem {0}, {1}...
    e já chegam como texto ("$x", a mesma expansão que a string tinha antes). Uma tradução com marcadores errados não
    derruba a ação: vale o modelo em português.
    #>
    param ([AllowEmptyString()][AllowNull()][string]$Text)

    $value = $Text

    if ($Text.Length -gt 0) {
        $table = $script:WinForgeTextTable

        if ($null -eq $table) { $table = Get-WinForgeTextTable }

        if ($null -ne $table -and $table.Count -gt 0) {
            $translated = $null

            if ($table.TryGetValue($Text, [ref]$translated)) { $value = $translated }
        }
    }

    if ($args.Count -eq 0) { return $value }

    try {
        return [string]::Format([System.Globalization.CultureInfo]::InvariantCulture, $value, [object[]]$args)
    }
    catch [System.FormatException] {
        return [string]::Format([System.Globalization.CultureInfo]::InvariantCulture, $Text, [object[]]$args)
    }
}


function Get-WinForgeContextText {
    <#
    Como Get-WinForgeText, para o texto em português que muda conforme o uso em outro idioma (o "até" de uma data e o de
    um tamanho, por exemplo): o contexto separa as traduções, como o msgctxt do gettext. Sem tradução, o português.
    #>
    param (
        [string]$Context,
        [AllowEmptyString()][AllowNull()][string]$Text
    )

    $value = $Text

    if ($Text.Length -gt 0) {
        $table = $script:WinForgeTextTable

        if ($null -eq $table) { $table = Get-WinForgeTextTable }

        if ($null -ne $table -and $table.Count -gt 0) {
            $translated = $null

            if ($table.TryGetValue($Context + [char]4 + $Text, [ref]$translated)) { $value = $translated }
        }
    }

    if ($args.Count -eq 0) { return $value }

    try {
        return [string]::Format([System.Globalization.CultureInfo]::InvariantCulture, $value, [object[]]$args)
    }
    catch [System.FormatException] {
        return [string]::Format([System.Globalization.CultureInfo]::InvariantCulture, $Text, [object[]]$args)
    }
}


function Test-WinForgeCanceledText {
    # Se o detalhe de um resultado diz que a pessoa cancelou ("cancelado pelo usuário", "operação cancelada"), em
    # qualquer um dos três idiomas: "cancelad" em português e espanhol, "canceled" em inglês.
    param ([AllowEmptyString()][AllowNull()][string]$Text)

    return ([string]$Text -match '(?i)cancelad|cancell?ed')
}


function Test-WinForgeRestartingText {
    # Se o detalhe de um resultado diz que o PC está reiniciando (o Otimizar com um reinício pendente), em qualquer um
    # dos três idiomas.
    param ([AllowEmptyString()][AllowNull()][string]$Text)

    return ([string]$Text -match '(?i)reiniciando|restarting')
}


function Get-WinForgeLanguageChoices {
    # As opções do cartão Idioma, cada idioma escrito nele mesmo (quem não lê o atual acha o seu).
    return @(
        [PSCustomObject]@{ Id = "Auto"; Label = (Get-WinForgeText 'Automático') }
        [PSCustomObject]@{ Id = "pt"; Label = "Português" }
        [PSCustomObject]@{ Id = "en"; Label = "English" }
        [PSCustomObject]@{ Id = "es"; Label = "Español" }
    )
}


function Convert-WinForgeXamlText {
    <#
    Traduz os textos fixos de um XAML (Text, Content, ToolTip, Header, Title e AutomationProperties.Name) antes de a
    janela ser montada. Os valores estão escapados para XML: são lidos sem o escape e voltam escapados.
    #>
    param ([Parameter(Mandatory)][string]$Xaml)

    if ((Get-WinForgeLanguage) -eq "pt") { return $Xaml }

    return [regex]::Replace($Xaml, '(?<attr>\b(?:Text|Content|ToolTip|Header|Title|AutomationProperties\.Name))="(?<value>[^"]*)"', {
            param ($match)

            $value = [System.Net.WebUtility]::HtmlDecode($match.Groups["value"].Value)

            if ($value.Length -eq 0 -or $value.StartsWith("{")) { return $match.Value }

            $translated = Get-WinForgeText $value
            $escaped = [System.Security.SecurityElement]::Escape($translated)

            return "$($match.Groups['attr'].Value)=`"$escaped`""
        })
}


# ---------------------------------------------------------------------------
# Privilégios e sessão
# ---------------------------------------------------------------------------

function Test-WinForgeAdministrator {
    # Se não for possível verificar (sistema que não é Windows, identidade indisponível), vale "não é administrador":
    # é o lado seguro, e as ações que exigem elevação recusam em vez de falhar no meio.
    try {
        $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)

        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    catch {
        return $false
    }
}


function Get-WinForgeCurrentUserSid {
    # O SID da conta deste processo (S-1-5-21-...), ou "" quando não foi possível ler.
    $identity = $null

    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        return [string]$identity.User.Value
    }
    catch {
        return ""
    }
    finally {
        if ($null -ne $identity) { $identity.Dispose() }
    }
}


function Get-WinForgeTokenElevationType {
    <#
    O tipo de elevação deste processo (TokenElevationType, do GetTokenInformation): "Full" quando ele está elevado e a
    conta tem também uma versão sem Administrador (o UAC ligado, com uma conta de Administrador comum); "Limited" quando
    é essa versão sem Administrador; "Default" quando não há as duas (o UAC desligado, o Administrador embutido do
    Windows, ou uma conta sem Administrador). "" quando não foi possível ler.
    #>
    $identity = $null

    try {
        if (-not ("WinForge.TokenNative" -as [type])) {
            Add-Type -Namespace WinForge -Name TokenNative -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("advapi32.dll", SetLastError = true)]
public static extern bool GetTokenInformation(System.IntPtr token, int informationClass, out int information, int length, out int returnLength);
'@ -ErrorAction Stop
        }

        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $type = 0
        $length = 0

        # 18 = TokenElevationType; a resposta é um TOKEN_ELEVATION_TYPE (1, 2 ou 3), de 4 bytes.
        if (-not [WinForge.TokenNative]::GetTokenInformation($identity.Token, 18, [ref]$type, 4, [ref]$length)) { return "" }

        switch ($type) {
            1 { return "Default" }
            2 { return "Full" }
            3 { return "Limited" }
        }

        return ""
    }
    catch {
        return ""
    }
    finally {
        if ($null -ne $identity) { $identity.Dispose() }
    }
}


function Test-WinForgeModernStandby {
    <#
    Se o PC usa o Modern Standby (o modelo de espera "S0 low power idle", da maioria dos notebooks recentes): o campo AoAc
    de SYSTEM_POWER_CAPABILITIES, do GetPwrCapabilities. Nesses PCs, a Microsoft só permite o plano Equilibrado (ou os
    derivados dele). A leitura é guardada para a sessão; sem conseguir ler (outro sistema, a chamada falhou), $false: nada
    fica escondido por causa de uma leitura que não aconteceu.
    #>
    if ($null -ne $script:WinForgeModernStandby) { return [bool]$script:WinForgeModernStandby }

    $result = $false

    try {
        if (-not ("WinForge.PowerCapabilitiesNative" -as [type])) {
            Add-Type -Namespace WinForge -Name PowerCapabilitiesNative -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("powrprof.dll", SetLastError = true)]
[return: System.Runtime.InteropServices.MarshalAs(System.Runtime.InteropServices.UnmanagedType.U1)]
public static extern bool GetPwrCapabilities([System.Runtime.InteropServices.Out] byte[] capabilities);
'@ -ErrorAction Stop
        }

        # A estrutura tem 76 bytes; o buffer sobra. Os 20 campos antes do AoAc têm um byte cada (BOOLEAN e BYTE), então ele é
        # o byte 20.
        $buffer = New-Object byte[] 128

        if ([WinForge.PowerCapabilitiesNative]::GetPwrCapabilities($buffer)) { $result = ($buffer[20] -ne 0) }
    }
    catch {
        Write-Verbose "Modern Standby: $($_.Exception.Message)"
    }

    $script:WinForgeModernStandby = $result
    return $result
}


function ConvertTo-WinForgeCommandLineArgument {
    # Protege um valor para a linha de comando do Windows (regras do CommandLineToArgvW). Sem isso, um caminho que
    # termina em barra invertida ("C:\Relatorios\") faz a barra escapar a aspa final e engole os argumentos seguintes.
    param (
        [AllowEmptyString()]
        [string]$Value
    )

    if ($Value.Length -gt 0 -and $Value -notmatch '[\s"]') {
        return $Value
    }

    $escaped = [regex]::Replace($Value, '(\\*)"', '$1$1\"')
    $escaped = [regex]::Replace($escaped, '(\\+)$', '$1$1')

    return '"' + $escaped + '"'
}


function Restart-WinForgeAsAdministrator {
    # Relança o script do console como Administrador (UAC) e encerra esta instância.
    param (
        [Parameter(Mandatory)]
        [string]$ScriptPath,

        [string[]]$ExtraArguments = @()
    )

    if (Test-WinForgeAdministrator) {
        return
    }

    # Sem o cabeçalho (ele limparia a tela de quem digitou o comando num terminal) e sem o "Sem privilégios" vermelho:
    # só o que vai acontecer e o que fazer.
    # Aberto pelo WinForge-Console.cmd, quem pausa no fim é o .cmd (uma pausa só). A janela nova, elevada, não tem o
    # .cmd em volta: a marca sai do ambiente antes de abri-la, para ela mesma pausar.
    $fromCmd = ($env:WINFORGE_FROM_CMD -eq "1")
    Remove-Item -Path Env:WINFORGE_FROM_CMD -ErrorAction SilentlyContinue

    Write-Host ""
    Write-Host (Get-WinForgeText '  O WinForge precisa da permissão de Administrador para cuidar do PC.') -ForegroundColor Yellow
    Write-Host (Get-WinForgeText '  Clique em Sim no aviso do Windows: o WinForge continua numa janela nova.') -ForegroundColor Cyan
    Write-Host ""

    Start-Sleep -Seconds 2

    if (-not (Test-Path -LiteralPath $ScriptPath)) {
        Write-Host (Get-WinForgeText '  Não foi possível identificar o caminho do script principal.') -ForegroundColor Red
        Write-Host (Get-WinForgeText '  Execute o WinForge a partir de um arquivo .ps1 salvo.') -ForegroundColor Yellow
        Write-Host ""
        if (-not $fromCmd) { Wait-WinForgeKey }
        exit 1
    }

    # Reabre com o mesmo PowerShell que está em uso (Windows PowerShell 5.1 ou PowerShell 7).
    $hostExecutable = (Get-Process -Id $PID).Path

    if ([string]::IsNullOrWhiteSpace($hostExecutable)) {
        $hostExecutable = "powershell.exe"
    }

    $argumentText = "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`""

    if (@($ExtraArguments).Count -gt 0) {
        $argumentText += " " + (@($ExtraArguments) -join " ")
    }

    try {
        Start-Process -FilePath $hostExecutable -ArgumentList $argumentText -Verb RunAs
    }
    catch {
        # UAC recusado ou bloqueado por política: não há o que fazer além de avisar. O código de saída diz que nada foi
        # feito (um script que chamou o WinForge-Console.cmd não deve achar que o relatório saiu).
        Write-Host (Get-WinForgeText '  Sem a permissão de Administrador, o WinForge não pode continuar no terminal.') -ForegroundColor Red
        Write-Host (Get-WinForgeText '  Abra o WinForge-Console.cmd de novo e clique em Sim no aviso do Windows.') -ForegroundColor Yellow
        Write-Host ""
        if (-not $fromCmd) { Wait-WinForgeKey }
        exit 1
    }

    exit 0
}


function Get-WinForgeSessionShellUser {
    <#
    A conta dona do Explorador (explorer.exe) nesta sessão do Windows, como "DOMINIO\conta"; "" sem leitura (o Explorador
    não está aberto, a consulta falhou). É quem está usando o PC nesta sessão, também por Área de Trabalho Remota: o
    Win32_ComputerSystem.UserName diz só quem está no console (na frente do monitor), outra pessoa ou ninguém.
    #>
    try {
        $sessionId = [System.Diagnostics.Process]::GetCurrentProcess().SessionId
        $shell = @(Get-CimInstance -ClassName Win32_Process -Filter "Name = 'explorer.exe' AND SessionId = $sessionId" -OperationTimeoutSec 15 -ErrorAction Stop) | Select-Object -First 1

        if ($null -eq $shell) { return "" }

        $owner = Invoke-CimMethod -InputObject $shell -MethodName GetOwner -OperationTimeoutSec 15 -ErrorAction Stop
        $user = [string](Get-WinForgeJsonValue -Object $owner -Name "User" -Default "")
        $domain = [string](Get-WinForgeJsonValue -Object $owner -Name "Domain" -Default "")

        if ([int](Get-WinForgeJsonValue -Object $owner -Name "ReturnValue" -Default 1) -ne 0 -or [string]::IsNullOrWhiteSpace($user)) { return "" }

        return $(if ([string]::IsNullOrWhiteSpace($domain)) { $user.Trim() } else { "$($domain.Trim())\$($user.Trim())" })
    }
    catch {
        return ""
    }
}


function Get-WinForgeInteractiveUser {
    # Quem está usando o PC: o dono do Explorador desta sessão (vale também na Área de Trabalho Remota) e, sem ele, quem
    # está no console. "" sem leitura.
    $shellUser = Get-WinForgeSessionShellUser

    if (-not [string]::IsNullOrWhiteSpace($shellUser)) { return $shellUser }

    try {
        $interactiveUser = (Get-CimInstance Win32_ComputerSystem -OperationTimeoutSec 15 -ErrorAction Stop).UserName

        if (-not [string]::IsNullOrWhiteSpace($interactiveUser)) {
            return $interactiveUser.Trim()
        }
    }
    catch {
        # Informação auxiliar; não bloqueia a execução.
    }

    return ""
}


function Test-WinForgeUserContextMismatch {
    # Verdadeiro quando o WinForge foi elevado com outra conta que não a do usuário logado.
    # Nesse caso, HKCU, %LOCALAPPDATA% e Downloads pertencem ao administrador, não ao usuário interativo.
    $interactiveUser = Get-WinForgeInteractiveUser

    if ([string]::IsNullOrWhiteSpace($interactiveUser)) {
        return $false
    }

    try {
        $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent().Name
        return -not $currentUser.Equals($interactiveUser, [System.StringComparison]::OrdinalIgnoreCase)
    }
    catch {
        return $false
    }
}


function Test-WinForgeLaptop {
    # O chassi decide primeiro (SMBIOS ChassisTypes): portátil é notebook; gabinete de mesa não é, mesmo com "bateria" (um
    # nobreak USB aparece como bateria no Windows). Só com o chassi desconhecido a bateria desempata.
    $portableTypes = @(8, 9, 10, 11, 12, 14, 18, 21, 30, 31, 32)
    $desktopTypes = @(3, 4, 5, 6, 7, 13, 15, 16, 17, 23, 24, 25, 28, 29, 34, 35, 36)

    try {
        $chassis = @((Get-CimInstance Win32_SystemEnclosure -OperationTimeoutSec 15 -ErrorAction Stop).ChassisTypes | Where-Object { $null -ne $_ } | ForEach-Object { [int]$_ })

        if (@($chassis | Where-Object { $portableTypes -contains $_ }).Count -gt 0) { return $true }
        if (@($chassis | Where-Object { $desktopTypes -contains $_ }).Count -gt 0) { return $false }
    }
    catch {
        # Segue para a bateria.
    }

    try {
        return (@(Get-CimInstance Win32_Battery -OperationTimeoutSec 15 -ErrorAction Stop).Count -gt 0)
    }
    catch {
        # Sem informação: assume desktop.
        return $false
    }
}


function Test-WinForgeOnBattery {
    # $true quando o notebook está funcionando na bateria (BatteryStatus 1 = descarregando, 4 = baixa, 5 = crítica).
    # Desktop, tomada conectada e falha na consulta dão $false: na dúvida, o WinForge não atrapalha o usuário.
    try {
        $batteries = @(Get-CimInstance Win32_Battery -OperationTimeoutSec 15 -ErrorAction Stop)
        return (@($batteries | Where-Object { [int]$_.BatteryStatus -in 1, 4, 5 }).Count -gt 0)
    }
    catch {
        return $false
    }
}


function Test-WinForgeMeteredConnection {
    <#
    $true quando a conexão com a internet é limitada (o Windows a trata como plano de dados: celular roteado, chip,
    rede marcada como limitada nas Configurações), ou quando o plano está perto do limite, acabou ou em roaming. O próprio
    Windows não baixa atualizações sozinho numa conexão assim; quem baixa pelo WinForge fica sabendo antes. Sem a
    informação (Windows sem a API, consulta que falhou), $false: na dúvida, o WinForge não atrapalha.
    #>
    try {
        $network = [Windows.Networking.Connectivity.NetworkInformation, Windows.Networking.Connectivity, ContentType=WindowsRuntime]
        $connection = $network::GetInternetConnectionProfile()

        if ($null -eq $connection) { return $false }

        $cost = $connection.GetConnectionCost()

        return ([string]$cost.NetworkCostType -in @("Fixed", "Variable") -or [bool]$cost.ApproachingDataLimit -or [bool]$cost.OverDataLimit -or [bool]$cost.Roaming)
    }
    catch {
        return $false
    }
}


function Get-WinForgeSystemDriveFreeBytes {
    # Espaço livre na unidade do Windows, em bytes; -1 quando não for possível saber.
    try {
        $root = [IO.Path]::GetPathRoot($env:SystemRoot)
        return [int64](New-Object System.IO.DriveInfo $root).AvailableFreeSpace
    }
    catch {
        return -1
    }
}


function Get-WinForgeSystemDriveSpace {
    # Espaço livre e total da unidade do Windows, em bytes; $null quando não for possível ler.
    try {
        $root = [IO.Path]::GetPathRoot($env:SystemRoot)

        if ([string]::IsNullOrWhiteSpace($root)) {
            return $null
        }

        $drive = New-Object System.IO.DriveInfo $root

        return [PSCustomObject]@{
            FreeBytes  = [int64]$drive.AvailableFreeSpace
            TotalBytes = [int64]$drive.TotalSize
        }
    }
    catch {
        return $null
    }
}


function Get-WinForgeDiskSpaceLevel {
    <#
    Classifica o espaço livre de uma unidade com uma regra só, usada pela tela inicial, pela lista de discos e pela
    checagem da Manutenção. Na unidade do Windows, em gigabytes, e não em proporção: "Critical" = menos de 10 GB livres
    (pouco para uma atualização de versão do Windows) e "Low" = menos de 20 GB. Uma proporção acusaria um disco de 2 TB
    com 150 GB livres e deixaria passar um de 64 GB com 7 GB. Numa unidade que não é a do sistema (-System $false), os
    gigabytes não valem (um pen drive de 8 GB com 4 GB livres não está em perigo): "Critical" é menos de 5% livres e
    "Low", menos de 10%. "Ok" nos demais casos; sem dados válidos (valor negativo ou nulo), "Unknown".
    #>
    param (
        [object]$FreeBytes,
        [object]$TotalBytes,
        [bool]$System = $true
    )

    # Um valor que não é número deixa o padrão (livre desconhecido = -1, total desconhecido = 0): TryParse zera a saída
    # quando falha, e "0 bytes livres" seria lido como disco crítico.
    $free = [double]-1
    $total = [double]0
    $parsed = [double]0
    $style = [System.Globalization.NumberStyles]::Float
    $culture = [System.Globalization.CultureInfo]::InvariantCulture

    if ($null -ne $FreeBytes -and [double]::TryParse(([string]$FreeBytes), $style, $culture, [ref]$parsed)) { $free = $parsed }
    if ($null -ne $TotalBytes -and [double]::TryParse(([string]$TotalBytes), $style, $culture, [ref]$parsed)) { $total = $parsed }

    if ($free -lt 0) { return "Unknown" }

    if ($System) {
        if ($free -lt $script:WinForgeCriticalDiskBytes) { return "Critical" }
        if ($free -lt $script:WinForgeLowDiskBytes) { return "Low" }
        return "Ok"
    }

    if ($total -le 0) { return "Unknown" }
    if ((($free * 100) / $total) -lt 5) { return "Critical" }
    if ((($free * 100) / $total) -lt $script:WinForgeLowDiskPercent) { return "Low" }

    return "Ok"
}


function Get-WinForgeRegistryWindowsBuild {
    # A build pelo Registro (CurrentBuildNumber), sem o WMI; 0 sem leitura.
    $value = Get-WinForgeRegistryValueOrNull -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name "CurrentBuildNumber"
    $parsed = 0

    if ($null -ne $value -and [int]::TryParse(([string]$value).Trim(), [ref]$parsed) -and $parsed -gt 0) { return $parsed }

    return 0
}


function Get-WinForgeWindowsBuild {
    # O build não muda com o WinForge aberto: a primeira leitura fica guardada (a lista de ajustes pergunta uma vez por
    # ajuste, e cada pergunta era uma consulta ao Windows).
    if ($script:WinForgeWindowsBuild -gt 0) { return $script:WinForgeWindowsBuild }

    try {
        $operatingSystem = Get-CimInstance -ClassName Win32_OperatingSystem -OperationTimeoutSec 15 -ErrorAction Stop
        $build = [int]$operatingSystem.BuildNumber
    }
    catch {
        $build = Get-WinForgeRegistryWindowsBuild
        if ($build -le 0) { $build = [int][Environment]::OSVersion.Version.Build }
    }

    if ($build -gt 0) { $script:WinForgeWindowsBuild = $build }

    return $build
}


function Test-WinForgeWindows11 {
    return (Get-WinForgeWindowsBuild) -ge 22000
}


function Get-WinForgeWindowsName {
    # "Microsoft Windows 11 Pro" vira "Windows 11 Pro". Em alguns PCs atualizados do 10 para o 11 o nome ainda diz
    # "Windows 10"; a build decide. A tela inicial, o Diagnóstico e o relatório mostram este mesmo nome.
    param (
        [AllowEmptyString()][string]$Caption = "",
        [int]$Build = 0
    )

    $name = ([string]$Caption -replace '^\s*Microsoft\s+', '').Trim()

    if ($Build -ge 22000) { $name = $name -replace '\bWindows 10\b', 'Windows 11' }

    return $name
}


function Get-WinForgeWindowsDisplayVersion {
    # A versão de mercado (24H2, 23H2...): DisplayVersion desde o 20H2; antes, ReleaseId (2004, 1909...). "" sem leitura.
    try {
        $current = Get-ItemProperty -LiteralPath "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -ErrorAction Stop

        return [string](Get-WinForgeJsonValue -Object $current -Name "DisplayVersion" -Default (Get-WinForgeJsonValue -Object $current -Name "ReleaseId" -Default ""))
    }
    catch {
        return ""
    }
}


function Get-WinForgeSessionInfo {
    param (
        [switch]$Refresh
    )

    if ($null -ne $script:WinForgeSession -and -not $Refresh) {
        return $script:WinForgeSession
    }

    $build = 0
    $windowsLabel = "Windows"
    $caption = ""

    try {
        $os = Get-CimInstance Win32_OperatingSystem -OperationTimeoutSec 15 -ErrorAction Stop
        $build = [int]$os.BuildNumber
        $windowsLabel = if ($build -ge 22000) { "Windows 11" } else { "Windows 10" }
        $caption = Get-WinForgeWindowsName -Caption ([string](Get-WinForgeJsonValue -Object $os -Name "Caption" -Default "")) -Build $build
    }
    catch {
        # Sem o WMI (o serviço parado ou com defeito), a build ainda vem do Registro: sem ela, o Início não saberia o
        # suporte do Windows. O nome completo fica de fora.
        $build = Get-WinForgeRegistryWindowsBuild
        if ($build -gt 0) { $windowsLabel = $(if ($build -ge 22000) { "Windows 11" } else { "Windows 10" }) }
    }

    # Sem a versão, o cartão mostra só o nome e a build.
    $version = Get-WinForgeWindowsDisplayVersion

    try {
        $script:WinForgeSession = [PSCustomObject]@{
            IsAdmin        = Test-WinForgeAdministrator
            User           = [Security.Principal.WindowsIdentity]::GetCurrent().Name
            UserMismatch   = Test-WinForgeUserContextMismatch
            IsLaptop       = Test-WinForgeLaptop
            WindowsLabel   = $windowsLabel
            WindowsBuild   = $build
            WindowsName    = $caption
            WindowsVersion = $version
        }
    }
    catch {
        # As informações de sessão são auxiliares; nunca devem impedir a exibição de uma tela.
        $script:WinForgeSession = [PSCustomObject]@{
            IsAdmin        = $false
            User           = $env:USERNAME
            UserMismatch   = $false
            IsLaptop       = $false
            WindowsLabel   = $windowsLabel
            WindowsBuild   = $build
            WindowsName    = $caption
            WindowsVersion = $version
        }
    }

    return $script:WinForgeSession
}


# ---------------------------------------------------------------------------
# Ambiente e log
# ---------------------------------------------------------------------------

function Set-WinForgeConsoleEncoding {
    # Garante melhor exibição de acentos no Windows PowerShell 5.1 e em consoles legados.
    try {
        $utf8Encoding = New-Object System.Text.UTF8Encoding -ArgumentList $false
        # As duas propriedades já trocam a página de código do console (SetConsoleCP e SetConsoleOutputCP), o que o
        # chcp 65001 fazia de novo.
        [Console]::InputEncoding = $utf8Encoding
        [Console]::OutputEncoding = $utf8Encoding
        $global:OutputEncoding = $utf8Encoding
    }
    catch {
        # Não bloqueia a execução caso o console não permita alteração de encoding.
    }
}


function Enable-WinForgeTls12 {
    # O Windows PowerShell 5.1 em alguns sistemas só negocia TLS 1.0/1.1, que os servidores atuais recusam.
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    }
    catch {
        # Sem a enumeração (ambientes antigos): segue com o padrão do sistema.
    }
}


function Test-WinForgeTcpConnection {
    # Abre e fecha uma conexão TCP. Mostra se a internet responde mesmo quando o ping (ICMP) é bloqueado.
    # Nunca lança erro: tempo esgotado, recusa ou nome inválido dão $false.
    param (
        [Parameter(Mandatory)]
        [string]$ComputerName,

        [ValidateRange(1, 65535)]
        [int]$Port = 443,

        [ValidateRange(100, 30000)]
        [int]$TimeoutMilliseconds = 2000
    )

    $client = New-Object System.Net.Sockets.TcpClient

    try {
        $attempt = $client.BeginConnect($ComputerName, $Port, $null, $null)

        if (-not $attempt.AsyncWaitHandle.WaitOne($TimeoutMilliseconds, $false)) {
            return $false
        }

        $client.EndConnect($attempt)

        return [bool]$client.Connected
    }
    catch {
        return $false
    }
    finally {
        $client.Close()
    }
}


function Test-WinForgeDnsResolution {
    # Verdadeiro se o nome vira ao menos um endereço IP. Nunca lança erro: nome inexistente ou DNS fora do ar dão $false.
    param (
        [Parameter(Mandatory)]
        [string]$Name
    )

    try {
        return (@([System.Net.Dns]::GetHostAddresses($Name)).Count -gt 0)
    }
    catch {
        return $false
    }
}


function Initialize-WinForgeEnvironment {
    Set-WinForgeConsoleEncoding
    Enable-WinForgeTls12
}


function Get-WinForgeGuiHostUI {
    # A interface do host da janela (WinForge.GuiHostUI), que grava o log das ações; $null fora da janela.
    if (-not (Test-WinForgeGuiMode)) { return $null }

    $variable = Get-Variable -Name WinForgeGuiHost -Scope Global -ErrorAction SilentlyContinue
    if ($null -eq $variable -or $null -eq $variable.Value) { return $null }

    try { return $variable.Value.GuiUI } catch { return $null }
}


function Start-WinForgeLogging {
    <#
    Abre o log da sessão em %LOCALAPPDATA%\WinForge\logs (os 20 mais recentes ficam). Idempotente: chamar de novo com o
    log ativo não abre um segundo. No console, é o transcript do PowerShell; na janela, o próprio host grava cada linha
    que as ações escrevem, com a hora: o transcript não vê o que passa pelo host da janela, e o log ficava vazio.
    #>
    if ($script:WinForgeLoggingActive) {
        return $true
    }

    try {
        $logDirectory = Join-Path (Get-WinForgeDataPath) "logs"

        if (-not (Test-Path -LiteralPath $logDirectory)) {
            [void](New-Item -Path $logDirectory -ItemType Directory -Force)
        }

        # Mantém apenas os 20 logs mais recentes.
        Get-ChildItem -LiteralPath $logDirectory -Filter "winforge-*.log" -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            Select-Object -Skip 20 |
            Remove-Item -Force -ErrorAction SilentlyContinue

        $script:WinForgeLogPath = Join-Path $logDirectory ("winforge-{0:yyyyMMdd-HHmmss}.log" -f (Get-Date))
        $gui = Get-WinForgeGuiHostUI

        if ($null -ne $gui -and $null -ne $gui.PSObject.Methods["OpenLog"]) {
            $header = (Get-WinForgeText 'WinForge Build {0} - {1} - {2} - PowerShell {3}' "$($script:WinForgeBuild)" "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" "$env:COMPUTERNAME" "$($PSVersionTable.PSVersion)")
            if (-not $gui.OpenLog($script:WinForgeLogPath, $header)) { throw (Get-WinForgeText 'o log não pôde ser aberto') }
            $script:WinForgeLogMode = "Gui"
        }
        else {
            [void](Start-Transcript -Path $script:WinForgeLogPath -Force)
            $script:WinForgeLogMode = "Transcript"
        }

        $script:WinForgeLoggingActive = $true
        return $true
    }
    catch {
        $script:WinForgeLogPath = $null
        return $false
    }
}


function Stop-WinForgeLogging {
    try {
        if ($script:WinForgeLoggingActive) {
            if ($script:WinForgeLogMode -eq "Gui") {
                $gui = Get-WinForgeGuiHostUI
                if ($null -ne $gui) { $gui.CloseLog() }
            }
            else {
                [void](Stop-Transcript)
            }
        }
    }
    catch {
        # O log pode não estar ativo.
    }

    $script:WinForgeLoggingActive = $false
}


function Get-WinForgeLogPath {
    return $script:WinForgeLogPath
}


function Write-WinForgeSecret {
    <#
    Mostra um segredo na tela (a senha de uma rede Wi-Fi, a chave de recuperação do BitLocker) sem que ele vá para o log,
    como uma linha "rótulo : valor" (Write-WinForgeKeyValue), que o resumo da janela mostra. Na janela, o log grava o
    rótulo com "[fora do log]" no lugar do valor; no menu de texto, o log é pausado durante a linha.
    #>
    param (
        [Parameter(Mandatory)][string]$Label,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Value,
        [int]$LabelWidth = 24
    )

    $padded = $Label.PadRight($LabelWidth)
    $gui = Get-WinForgeGuiHostUI

    if ($null -ne $gui -and $null -ne $gui.PSObject.Methods["WriteSecretValue"]) {
        $gui.WriteSecretValue($padded, $Value, [ConsoleColor]::Cyan, (Get-WinForgeText '[fora do log]'))
        return
    }

    $paused = $false

    if ($script:WinForgeLoggingActive -and $script:WinForgeLogMode -eq "Transcript") {
        try { [void](Stop-Transcript); $paused = $true } catch { $paused = $false }
    }

    Write-Host "  " -NoNewline
    Write-Host $padded -ForegroundColor DarkGray -NoNewline
    Write-Host " : " -ForegroundColor DarkGray -NoNewline
    Write-Host $Value -ForegroundColor Cyan

    if ($paused) {
        try { [void](Start-Transcript -Path $script:WinForgeLogPath -Append) } catch { $script:WinForgeLoggingActive = $false }
    }
}


function Add-WinForgeOpenTime {
    <#
    Anota em logs\abertura.log quanto a janela (ou o menu) levou para abrir: a data, a versão, os segundos e se abriu como
    Administrador. Ficam as 100 aberturas mais recentes. Serve para medir a abertura num PC de verdade; uma falha aqui não
    muda nada.
    #>
    param (
        [Parameter(Mandatory)][double]$Seconds,
        [string]$Kind = "Gui"
    )

    try {
        $folder = Join-Path (Get-WinForgeDataPath) "logs"
        if (-not (Test-Path -LiteralPath $folder)) { [void](New-Item -ItemType Directory -Path $folder -Force) }

        $path = Join-Path $folder "abertura.log"
        $culture = [System.Globalization.CultureInfo]::InvariantCulture
        $line = "{0}  Build {1}  {2}  {3} s  {4}" -f (Get-Date).ToString("yyyy-MM-dd HH:mm:ss", $culture), $script:WinForgeBuild, $Kind, $Seconds.ToString("0.00", $culture), $(if (Test-WinForgeAdministrator) { "admin" } else { "user" })
        $lines = @()

        if (Test-Path -LiteralPath $path -PathType Leaf) { $lines = @([System.IO.File]::ReadAllLines($path) | Select-Object -Last 99) }

        [System.IO.File]::WriteAllLines($path, [string[]](@($lines) + @($line)))
    }
    catch {
        Write-Verbose "Tempo de abertura: $($_.Exception.Message)"
    }
}


function Add-WinForgeWindowProblem {
    <#
    Anota em logs\janela.log uma parte da janela que não pôde ser mostrada: a data, a versão, a parte (Part) e o motivo
    (Reason, os erros do momento, um por linha). A janela roda sem console, e sem isto a falha some sem deixar rastro; o
    Pacote de suporte leva o arquivo. Ficam as 200 linhas mais recentes. Uma falha aqui não muda nada.
    #>
    param (
        [Parameter(Mandatory)][string]$Part,
        [string[]]$Reason = @()
    )

    try {
        $folder = Join-Path (Get-WinForgeDataPath) "logs"
        if (-not (Test-Path -LiteralPath $folder)) { [void](New-Item -ItemType Directory -Path $folder -Force) }

        $path = Join-Path $folder "janela.log"
        $stamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss", [System.Globalization.CultureInfo]::InvariantCulture)
        $new = @("$stamp  Build $($script:WinForgeBuild)  $Part")

        # Cada motivo numa linha só (um erro do .NET pode trazer quebras de linha), com um limite por linha.
        foreach ($text in @($Reason | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -First 10)) {
            $line = ([regex]::Replace([string]$text, '[\p{Cc}\p{Zl}\p{Zp}]+', ' ')).Trim()
            if ($line.Length -gt 500) { $line = $line.Substring(0, 500) }
            $new += "    $line"
        }

        $lines = @()
        if (Test-Path -LiteralPath $path -PathType Leaf) { $lines = @([System.IO.File]::ReadAllLines($path)) }

        $all = @($lines) + $new
        if ($all.Count -gt 200) { $all = @($all | Select-Object -Last 200) }

        [System.IO.File]::WriteAllLines($path, [string[]]$all)
    }
    catch {
        Write-Verbose "Log da janela: $($_.Exception.Message)"
    }
}


function Get-WinForgeLatestLogFile {
    # O log mais recente da pasta de logs (a janela e as ações gravam logs em sessões separadas, então o caminho em
    # memória não serve para a janela). $null quando ainda não há nenhum.
    try {
        $directory = Join-Path (Get-WinForgeDataPath) "logs"

        if (-not (Test-Path -LiteralPath $directory -PathType Container)) {
            return $null
        }

        $latest = Get-ChildItem -LiteralPath $directory -Filter "winforge-*.log" -File -ErrorAction Stop |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1

        if ($null -eq $latest) { return $null }

        return $latest.FullName
    }
    catch {
        return $null
    }
}


# ---------------------------------------------------------------------------
# Registro
# ---------------------------------------------------------------------------

function Get-WinForgeRegistryValueOrNull {
    param (
        [string]$Path,
        [string]$Name
    )

    try {
        $item = Get-ItemProperty -LiteralPath $Path -Name $Name -ErrorAction Stop
        return $item.$Name
    }
    catch {
        return $null
    }
}


function ConvertTo-WinForgeRegistryDWord {
    <#
    O número de um REG_DWORD como o PowerShell 5.1 grava: um Int32. O REG_DWORD são 32 bits sem sinal, e o provedor do
    registro devolve acima de 2.147.483.647 um UInt32 (as cores do Windows, com o alfa em FF, passam disso): o mesmo
    padrão de bits vira um Int32 negativo, e o Windows guarda os mesmos 4 bytes. Aceita de -2.147.483.648 a
    4.294.967.295; fora disso, erro.
    #>
    param ([Parameter(Mandatory)]$Value)

    $number = [long]$Value

    if ($number -lt [int]::MinValue -or $number -gt [long][uint32]::MaxValue) {
        throw (Get-WinForgeText 'o valor {0} não cabe num DWORD do registro' "$Value")
    }

    if ($number -gt [int]::MaxValue) { return [int]($number - 4294967296) }

    return [int]$number
}


function ConvertTo-WinForgeRegistryQWord {
    # O número de um REG_QWORD como o PowerShell grava (Int64): acima de 9.223.372.036.854.775.807, o UInt64 que o provedor
    # do registro devolve vira o Int64 com os mesmos 8 bytes.
    param ([Parameter(Mandatory)]$Value)

    if ($Value -is [uint64] -and $Value -gt [uint64][long]::MaxValue) {
        return [BitConverter]::ToInt64([BitConverter]::GetBytes([uint64]$Value), 0)
    }

    return [long]$Value
}


function Set-WinForgeRegistryDWord {
    # Value: de -2.147.483.648 a 4.294.967.295, o jeito que o provedor do registro lê (ConvertTo-WinForgeRegistryDWord).
    param (
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        $Value
    )

    $data = ConvertTo-WinForgeRegistryDWord -Value $Value

    # -ErrorAction Stop: com a preferência padrão (Continue), um "acesso negado" só escreveria um erro e quem chamou
    # seguiria como se o valor tivesse sido gravado (anotando no Histórico e guardando backup de algo que não mudou).
    if (-not (Test-Path -LiteralPath $Path)) {
        [void](New-Item -Path $Path -Force -ErrorAction Stop)
    }

    [void](New-ItemProperty -LiteralPath $Path -Name $Name -Value $data -PropertyType DWord -Force -ErrorAction Stop)
}


function Set-WinForgeRegistryBinary {
    param (
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [byte[]]$Value
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        [void](New-Item -Path $Path -Force -ErrorAction Stop)
    }

    [void](New-ItemProperty -LiteralPath $Path -Name $Name -Value $Value -PropertyType Binary -Force -ErrorAction Stop)
}


function Get-WinForgeRegistryValueKind {
    # O tipo de um valor de registro, como o Windows o guarda (DWord, QWord, String, ExpandString, MultiString, Binary...),
    # ou "" quando o valor não existe ou não pôde ser lido.
    param (
        [string]$Path,
        [string]$Name
    )

    try {
        $key = Get-Item -LiteralPath $Path -ErrorAction Stop

        if (@($key.GetValueNames()) -notcontains $Name) {
            return ""
        }

        return [string]$key.GetValueKind($Name)
    }
    catch {
        return ""
    }
}


function Set-WinForgeRegistryValue {
    # Grava um valor com o tipo dado (o de Get-WinForgeRegistryValueKind), para devolver um valor ao que era: um texto
    # volta como texto, não como número. Tipos que o PowerShell não grava (None, Unknown) voltam como binário.
    param (
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$Kind,

        [AllowNull()]
        $Value
    )

    if ($Kind -eq "DWord") {
        $data = ConvertTo-WinForgeRegistryDWord -Value $Value
    }
    elseif ($Kind -eq "QWord") {
        $data = ConvertTo-WinForgeRegistryQWord -Value $Value
    }
    elseif ($Kind -eq "MultiString") {
        $data = [string[]]@($Value | Where-Object { $null -ne $_ })
    }
    elseif ($Kind -eq "String" -or $Kind -eq "ExpandString") {
        $data = [string]$Value
    }
    else {
        $Kind = "Binary"
        $data = [byte[]]@($Value | Where-Object { $null -ne $_ })
    }

    if (-not (Test-Path -LiteralPath $Path)) {
        [void](New-Item -Path $Path -Force -ErrorAction Stop)
    }

    [void](New-ItemProperty -LiteralPath $Path -Name $Name -Value $data -PropertyType $Kind -Force -ErrorAction Stop)
}


function Get-WinForgeRegistryValues {
    # Todos os valores nomeados de uma chave (nome -> valor), na ordem do registro. Chave ausente ou sem acesso = vazio.
    param (
        [Parameter(Mandatory)]
        [string]$Path
    )

    $values = [ordered]@{}

    try {
        $key = Get-Item -LiteralPath $Path -ErrorAction Stop

        foreach ($name in $key.GetValueNames()) {
            if (-not [string]::IsNullOrEmpty($name)) {
                $values[$name] = $key.GetValue($name)
            }
        }
    }
    catch {
        # Sem a chave, não há valores.
    }

    return $values
}


function Remove-WinForgeRegistryValue {
    # Remove um valor de registro. Só "a chave ou o valor já não existem" não é erro: sem permissão, o valor continua lá e
    # quem chamou precisa saber (desfazer um ajuste não pode dizer que voltou ao original sem ter voltado).
    param (
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Name
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }

    $key = Get-Item -LiteralPath $Path -ErrorAction Stop

    if (@($key.GetValueNames()) -notcontains $Name) {
        return
    }

    Remove-ItemProperty -LiteralPath $Path -Name $Name -ErrorAction Stop
}


function Test-WinForgeRegistryKey {
    param (
        [Parameter(Mandatory)]
        [string]$Path
    )

    return [bool](Test-Path -LiteralPath $Path -PathType Container)
}


function Set-WinForgeRegistryKeyDefault {
    # Cria a chave (e as de cima) e define o valor padrão dela como texto.
    param (
        [Parameter(Mandatory)]
        [string]$Path,

        [string]$Value = ""
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        [void](New-Item -Path $Path -Force -ErrorAction Stop)
    }

    Set-ItemProperty -LiteralPath $Path -Name "(default)" -Value $Value -ErrorAction Stop
}


function Remove-WinForgeRegistryKey {
    # Remove a chave com tudo o que há dentro; com -OnlyIfEmpty, só se não tiver subchaves nem valores. Chave ausente não é erro.
    param (
        [Parameter(Mandatory)]
        [string]$Path,

        [switch]$OnlyIfEmpty
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }

    if ($OnlyIfEmpty) {
        $key = Get-Item -LiteralPath $Path -ErrorAction Stop
        $hasValues = @($key.GetValueNames() | Where-Object { -not [string]::IsNullOrEmpty($_) }).Count -gt 0

        if ($hasValues -or $key.SubKeyCount -gt 0) {
            return
        }
    }

    Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
}


# ---------------------------------------------------------------------------
# Formatação
# ---------------------------------------------------------------------------

# Os números do WinForge saem como no português do Brasil (vírgula decimal), qualquer que seja o idioma do Windows: o
# texto em volta é sempre em português. Sem isto, o PowerShell escreve "8.23 GB" ao montar um texto com "$(...)".
# Montado na primeira vez que é usado (Get-WinForgeNumberFormat).
$script:WinForgeNumberFormat = $null


function Get-WinForgeNumberFormat {
    # Os separadores do idioma do WinForge: vírgula decimal e ponto de milhar em português e espanhol ("4,5", "12.345");
    # ponto decimal e vírgula de milhar em inglês ("4.5", "12,345").
    if ($null -eq $script:WinForgeNumberFormat) {
        $format = [System.Globalization.NumberFormatInfo]::InvariantInfo.Clone()

        if ((Get-WinForgeLanguage) -eq "en") {
            $format.NumberDecimalSeparator = "."
            $format.NumberGroupSeparator = ","
        }
        else {
            $format.NumberDecimalSeparator = ","
            $format.NumberGroupSeparator = "."
        }

        $script:WinForgeNumberFormat = $format
    }

    return $script:WinForgeNumberFormat
}


function Format-WinForgeBytes {
    <#
    Texto legível para tamanhos, como o Explorador mostra: três algarismos significativos e vírgula decimal ("8,23 GB",
    "47,6 GB", "476 GB", "1,5 GB"). Valores nulos, inválidos ou <= 0 viram $ZeroText.
    #>
    param (
        [object]$Bytes,
        [string]$ZeroText = "0 B"
    )

    try {
        $value = [double]$Bytes
    }
    catch {
        return $ZeroText
    }

    if ([double]::IsNaN($value) -or [double]::IsInfinity($value) -or $value -le 0) {
        return $ZeroText
    }

    $units = @("B", "KB", "MB", "GB", "TB", "PB")
    $index = 0

    while ($value -ge 1024 -and $index -lt ($units.Count - 1)) {
        $value = $value / 1024
        $index++
    }

    if ($index -eq 0) {
        return "$([Math]::Round($value, 0)) B"
    }

    # Duas casas abaixo de 10, uma abaixo de 100, nenhuma daí para cima. O arredondamento pode cruzar a faixa (9,996 vira
    # 10,00): a conta é refeita com uma casa a menos. E 1023,7 KB arredondaria para "1024 KB": vira "1 MB".
    $digits = $(if ($value -lt 10) { 2 } elseif ($value -lt 100) { 1 } else { 0 })
    $rounded = [Math]::Round($value, $digits)

    if ($digits -gt 0 -and $rounded -ge [Math]::Pow(10, 3 - $digits)) {
        $digits--
        $rounded = [Math]::Round($value, $digits)
    }

    if ($rounded -ge 1024 -and $index -lt ($units.Count - 1)) {
        $index++
        $digits = 2
        $rounded = [Math]::Round($value / 1024, $digits)
    }

    $pattern = $(if ($digits -gt 0) { "0." + ("#" * $digits) } else { "0" })

    return "$($rounded.ToString($pattern, (Get-WinForgeNumberFormat))) $($units[$index])"
}


function Format-WinForgeNumber {
    # "12.345", "4,5", "3,69": um número com os separadores do português do Brasil, até $Decimals casas (zeros à direita
    # somem). Montar o texto com "$(...)" escreveria "4.5" e "12345".
    param (
        [Parameter(Mandatory)][double]$Value,
        [ValidateRange(0, 6)][int]$Decimals = 0
    )

    $pattern = "#,##0" + $(if ($Decimals -gt 0) { "." + ("#" * $Decimals) } else { "" })

    return $Value.ToString($pattern, (Get-WinForgeNumberFormat))
}


function Format-WinForgeDateTime {
    # "21/10/2026 21:40" (ou outro padrão, como "dd/MM"), sempre com barras e dois pontos: num padrão de data, "/" e ":"
    # viram os separadores do idioma do Windows (pontos no alemão, por exemplo), e o texto em volta é o do WinForge. O
    # padrão é traduzido como um texto da interface ("dd/MM/yyyy" vira "MM/dd/yyyy" em inglês), e os nomes (AM/PM) são
    # os da cultura invariante.
    param (
        [Parameter(Mandatory)][datetime]$When,
        [string]$Pattern = "dd/MM/yyyy HH:mm"
    )

    return $When.ToString((Get-WinForgeText $Pattern), [System.Globalization.CultureInfo]::InvariantCulture)
}


function Format-WinForgeCount {
    # "1 etapa", "3 etapas", "0 etapas", "12.345 itens": a quantidade (com o separador de milhar do português) e a palavra
    # no singular ou no plural certo, em vez de "etapa(s)".
    param (
        [Parameter(Mandatory)][int]$Count,
        [Parameter(Mandatory)][string]$One,
        [Parameter(Mandatory)][string]$Many
    )

    return "$(Format-WinForgeNumber -Value $Count) $(if ($Count -eq 1) { $One } else { $Many })"
}


function Join-WinForgeList {
    # "C:", "C: e D:", "C:, D: e E:": uma enumeração como se escreve no idioma do WinForge ("C: and D:", "C: y D:"). Em
    # espanhol, o "y" vira "e" antes de palavra com som de i ("Chrome e Internet Explorer").
    param (
        [AllowEmptyCollection()][string[]]$Items = @()
    )

    $list = @($Items | Where-Object { -not [string]::IsNullOrEmpty($_) })

    if ($list.Count -le 1) { return ($list -join "") }

    $head = $list[0..($list.Count - 2)] -join ", "
    $last = $list[$list.Count - 1]

    if ((Get-WinForgeLanguage) -eq "es" -and $last -match '^(?i)h?[ií](?![aeoáéó])') { return "$head e $last" }

    return (Get-WinForgeText '{0} e {1}' "$head" "$last")
}


function Join-WinForgeShortList {
    # Como Join-WinForgeList, mas curta para caber na faixa de resultado: até Limit nomes, todos; com mais, os três
    # primeiros e quantos faltam ("Git, VLC, Zoom e mais 4").
    param (
        [AllowEmptyCollection()][string[]]$Items = @(),
        [ValidateRange(4, 100)][int]$Limit = 4
    )

    $list = @($Items | Where-Object { -not [string]::IsNullOrEmpty($_) })

    if ($list.Count -le $Limit) { return (Join-WinForgeList -Items $list) }

    return (Get-WinForgeText '{0} e mais {1}' "$($list[0..2] -join ', ')" "$(Format-WinForgeNumber -Value ($list.Count - 3))")
}


function Get-WinForgeSelectionQuestion {
    # A confirmação de uma lista marcada: "Remover Clipchamp?", "Remover Clipchamp e Mapas?" (até três nomes, que a janela
    # mostra na própria pergunta) ou "Remover os 5 aplicativos marcados?". Many é a palavra no plural, masculina.
    param (
        [Parameter(Mandatory)][string]$Verb,
        [Parameter(Mandatory)][string[]]$Names,
        [Parameter(Mandatory)][string]$Many,
        [int]$Limit = 3
    )

    if ($Names.Count -le $Limit) {
        return (Get-WinForgeText '{0} {1}?' "$Verb" "$(Join-WinForgeList -Items $Names)")
    }

    return (Get-WinForgeText '{0} os {1} {2} marcados?' "$Verb" "$($Names.Count)" "$Many")
}


function Get-WinForgeErrorCode {
    <#
    O código de um erro do Windows, como "0x80073CFA": o primeiro que aparece na mensagem ou, na falta dele, o HResult da
    exceção. Os HResult genéricos do .NET e do PowerShell (0x80131500, 0x80131501, 0x80131509, 0x80131600) não dizem nada
    sobre a causa e ficam de fora. Vazio quando não há código.
    #>
    param (
        [string]$Message,
        [int]$HResult = 0
    )

    $match = [regex]::Match([string]$Message, '0x[0-9A-Fa-f]{8}')

    if ($match.Success) {
        return "0x" + $match.Value.Substring(2).ToUpperInvariant()
    }

    if ($HResult -lt 0 -and $HResult -notin @(-2146233088, -2146233087, -2146233079, -2146232832)) {
        return ("0x{0:X8}" -f $HResult)
    }

    return ""
}


function Format-WinForgeRelativeTime {
    # "há 3 dias", "há 2 horas", "agora há pouco": mostra quando algo aconteceu sem obrigar a pessoa a fazer a conta.
    # Um horário até um dia no futuro (fuso, relógio um pouco adiantado) conta como "agora há pouco"; mais que isso, a data
    # foi gravada com o relógio errado, e o texto diz "com data no futuro" em vez de fingir que foi agora.
    param (
        [Parameter(Mandatory)]
        [datetime]$When,

        [datetime]$Now = (Get-Date)
    )

    $span = $Now - $When

    if ($span.TotalDays -le -1) { return (Get-WinForgeText 'com data no futuro') }

    if ($span.TotalMinutes -lt 1) { return (Get-WinForgeText 'agora há pouco') }

    if ($span.TotalHours -lt 1) {
        $amount = [int][Math]::Floor($span.TotalMinutes)
        $unit = @((Get-WinForgeText 'minuto'), (Get-WinForgeText 'minutos'))
    }
    elseif ($span.TotalDays -lt 1) {
        $amount = [int][Math]::Floor($span.TotalHours)
        $unit = @((Get-WinForgeText 'hora'), (Get-WinForgeText 'horas'))
    }
    elseif ($span.TotalDays -lt 30) {
        $amount = [int][Math]::Floor($span.TotalDays)
        $unit = @((Get-WinForgeText 'dia'), (Get-WinForgeText 'dias'))
    }
    elseif ($span.TotalDays -lt 365) {
        $amount = [int][Math]::Floor($span.TotalDays / 30)
        $unit = @((Get-WinForgeText 'mês'), (Get-WinForgeText 'meses'))
    }
    else {
        $amount = [int][Math]::Floor($span.TotalDays / 365)
        $unit = @((Get-WinForgeText 'ano'), (Get-WinForgeText 'anos'))
    }

    $word = if ($amount -eq 1) { $unit[0] } else { $unit[1] }

    return (Get-WinForgeText 'há {0} {1}' "$amount" "$word")
}


function Format-WinForgeDuration {
    param (
        [TimeSpan]$Span
    )

    # O relógio pode ser ajustado durante uma etapa longa; duração negativa não faz sentido.
    if ($Span.Ticks -lt 0) { $Span = [TimeSpan]::Zero }

    # Arredondada antes de escolher o formato: 59,6 segundos é "1min 00s", e não "60s".
    $Span = [TimeSpan]::FromSeconds([Math]::Round($Span.TotalSeconds))

    if ($Span.TotalHours -ge 1) { return ("{0}h {1:00}min" -f [int][Math]::Floor($Span.TotalHours), $Span.Minutes) }
    if ($Span.TotalMinutes -ge 1) { return ("{0}min {1:00}s" -f [int][Math]::Floor($Span.TotalMinutes), $Span.Seconds) }
    return ("{0}s" -f [int]$Span.TotalSeconds)
}


# ---------------------------------------------------------------------------
# Seleção por números ("1,3,5-7")
# ---------------------------------------------------------------------------

function ConvertTo-WinForgeSelectionIndexes {
    # Aceita "1,3,5", "1 3 5", "2-4" e combinações ("1, 3-5"). Vírgula, ponto e vírgula e espaço separam itens.
    # Lança erro com mensagem clara se algo for inválido. Os limites são validados antes de expandir intervalos,
    # para que "1-999999999" não consuma memória. Só dígitos 0-9: [int] não converte dígitos de outros alfabetos.
    param (
        [string]$InputText,
        [int]$Maximum
    )

    if ([string]::IsNullOrWhiteSpace($InputText)) {
        return @()
    }

    if ($Maximum -lt 1) {
        throw (Get-WinForgeText 'Não há itens para escolher.')
    }

    # "3 - 5" vira "3-5" antes de separar por espaços.
    $normalized = [regex]::Replace($InputText, "\s*-\s*", "-")
    $segments = @($normalized -split "[,;\s]+" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })

    if ($segments.Count -eq 0) {
        return @()
    }

    $indexes = New-Object System.Collections.Generic.List[int]

    foreach ($part in $segments) {
        if ($part -match "^([0-9]{1,9})-([0-9]{1,9})$") {
            $first = [int]$Matches[1]
            $last = [int]$Matches[2]

            if ($first -gt $last) {
                throw (Get-WinForgeText 'O intervalo ''{0}'' está invertido.' "$part")
            }

            $values = @($first, $last)
            $expand = $true
        }
        elseif ($part -match "^[0-9]{1,9}$") {
            $values = @([int]$part)
            $expand = $false
        }
        else {
            throw (Get-WinForgeText '''{0}'' não é um número nem um intervalo válido.' "$part")
        }

        foreach ($value in $values) {
            if ($value -lt 1 -or $value -gt $Maximum) {
                throw (Get-WinForgeText 'O número {0} está fora da lista (1 a {1}).' "$value" "$Maximum")
            }
        }

        if ($expand) {
            $values = $values[0]..$values[1]
        }

        foreach ($value in $values) {
            if (-not $indexes.Contains($value)) {
                $indexes.Add($value)
            }
        }
    }

    return @($indexes)
}


# ---------------------------------------------------------------------------
# Programas nativos
# ---------------------------------------------------------------------------

function Invoke-WinForgeNative {
    <#
    Executa um programa nativo mostrando a saída na tela e sem devolver linhas ao pipeline.
    Na interface gráfica não há console visível: stdout e stderr são capturados e escritos linha a linha,
    na ordem em que chegam. Lança erro se o código de saída for diferente de zero (exceto com -IgnoreExitCode).
    Com -PassThru devolve o código de saída.
    #>
    param (
        [Parameter(Mandatory)]
        [string]$FilePath,

        [string[]]$Arguments = @(),

        [switch]$IgnoreExitCode,

        [switch]$PassThru
    )

    # Um programa que não existe não pode parecer um sucesso: com $ErrorActionPreference = Continue (o padrão da janela
    # e do console), o "não reconhecido" do PowerShell não interrompe a função e o código de saída ficaria 0.
    if ($null -eq (Get-Command -Name $FilePath -ErrorAction SilentlyContinue)) {
        throw (Get-WinForgeText 'O programa ''{0}'' não foi encontrado neste PC.' "$FilePath")
    }

    # Sem isto, o código de uma chamada anterior pareceria ser o deste programa se ele nem chegasse a definir um.
    $global:LASTEXITCODE = 0

    if (Test-WinForgeGuiMode) {
        # Ferramentas que gravam em UTF-16 (SFC) deixam caracteres nulos entre as letras; eles são removidos.
        $progress = @{ Last = -1.0 }

        & $FilePath @Arguments 2>&1 | ForEach-Object {
            $line = ([string]$_) -replace "`0", ""

            if (Test-WinForgeEchoLine -Line $line -State $progress) { Write-Host $line }
        }
    }
    else {
        & $FilePath @Arguments | Out-Host
    }

    $exitCode = $LASTEXITCODE

    if (-not $IgnoreExitCode -and $null -ne $exitCode -and $exitCode -ne 0) {
        throw (Get-WinForgeText 'Comando ''{0} {1}'' finalizou com código {2}.' "$FilePath" "$($Arguments -join ' ')" "$exitCode")
    }

    if ($PassThru) {
        return $exitCode
    }
}


function Get-WinForgeProgressPercent {
    <#
    O percentual de uma linha de progresso do DISM ("[====    25.0%    ====]"), do SFC ("Verification 25% complete."
    / "Verificação 25% concluída." / "Se completó la comprobación de 25%.") ou do winget ("  ████▒▒▒▒  40%" e "  ████▒▒▒▒  512 KB / 1.50 MB"), ou $null quando a
    linha é outra coisa. Reconhece só esses formatos: o que não for reconhecido continua aparecendo inteiro.
    #>
    param ([string]$Line)

    if ([string]::IsNullOrEmpty($Line)) { return $null }

    $number = $null

    if ($Line -match '^\s*\[[=\s]*([0-9]{1,3}(?:[.,][0-9]+)?)%[=\s]*\]\s*$') {
        $number = $Matches[1]
    }
    elseif ($Line -match '^\s*[^0-9%]{1,60}?([0-9]{1,3})%\s+(?:complete|completo|conclu\S*|done)\.?\s*$') {
        $number = $Matches[1]
    }
    elseif ($Line -match '^\s*Se complet\S*\s+la\s+comprobaci\S*\s+de\s+([0-9]{1,3})\s?%\.?\s*$') {
        # O SFC em espanhol: "Se completó la comprobación de 25%."
        $number = $Matches[1]
    }
    elseif ($Line -match '^[\s\x08]*[\u2588\u2593\u2592\u2591]+[\s\x08]+([0-9]{1,3})%\s*$') {
        $number = $Matches[1]
    }
    elseif ($Line -match '^[\s\x08]*[\u2588\u2593\u2592\u2591]+[\s\x08]+([0-9]+(?:[.,][0-9]+)?)\s*(B|KB|MB|GB)\s*/\s*([0-9]+(?:[.,][0-9]+)?)\s*(B|KB|MB|GB)\s*$') {
        # Download do winget: tamanho baixado / tamanho total.
        $units = @{ B = 1.0; KB = 1024.0; MB = 1048576.0; GB = 1073741824.0 }
        $culture = [System.Globalization.CultureInfo]::InvariantCulture
        $done = [double]::Parse(($Matches[1] -replace ',', '.'), $culture) * $units[$Matches[2].ToUpperInvariant()]
        $total = [double]::Parse(($Matches[3] -replace ',', '.'), $culture) * $units[$Matches[4].ToUpperInvariant()]

        if ($total -le 0) { return $null }

        return [math]::Min(100.0, [math]::Round($done / $total * 100, 1))
    }

    if ($null -eq $number) { return $null }

    $value = [double]::Parse(($number -replace ',', '.'), [System.Globalization.CultureInfo]::InvariantCulture)

    if ($value -gt 100) { return $null }

    return $value
}


function Test-WinForgeProgressStepShown {
    # Barras de progresso chegam uma linha por atualização (dezenas por etapa). Na tela basta uma a cada 10 pontos:
    # a primeira, o 100% e a de uma nova etapa (quando o percentual volta a baixar). Last guarda a última exibida.
    param (
        [Parameter(Mandatory)]
        [double]$Percent,

        [Parameter(Mandatory)]
        [hashtable]$State
    )

    $last = [double]$State.Last

    $show = ($last -lt 0) -or ($Percent -lt $last) -or ($Percent -ge ($last + 10)) -or ($Percent -ge 100 -and $last -lt 100)

    if ($show) { $State.Last = $Percent }

    return $show
}


function Test-WinForgeEchoLine {
    <#
    Se uma linha da saída de um programa aparece na tela. Os quadros do indicador de espera do winget ("-", "\", "|", "/")
    nunca aparecem; barras de progresso aparecem uma a cada 10 pontos (Test-WinForgeProgressStepShown); o resto sempre.
    State é o mesmo @{ Last = -1.0 } durante toda a execução do programa.
    #>
    param (
        [string]$Line,

        [Parameter(Mandatory)]
        [hashtable]$State
    )

    # Os quadros do indicador são curtos; as linhas de verdade quase nunca.
    if ($Line.Length -le 8 -and $Line -match '^[\s\x08]*[-\\|/][\s\x08]*$') { return $false }

    $percent = $null

    # A maioria das linhas não tem "%" nem " / ": nem chama o reconhecedor.
    if ($Line.Contains("%") -or $Line.Contains(" / ")) { $percent = Get-WinForgeProgressPercent -Line $Line }

    if ($null -eq $percent) { return $true }

    return (Test-WinForgeProgressStepShown -Percent $percent -State $State)
}


function Invoke-WinForgeCapture {
    <#
    Executa um programa nativo e devolve ExitCode, Lines e Text. Com -Echo as linhas também aparecem na tela
    enquanto chegam, o que evita uma janela parada durante comandos demorados (CHKDSK, DISM). Linhas e Text trazem
    tudo; só a tela resume as barras de progresso (Test-WinForgeProgressStepShown).
    Com -ProgressActivity, o percentual das linhas de progresso (DISM, SFC: Get-WinForgeProgressPercent) vai também para
    a barra de progresso (na janela, a barra enche e o texto ao lado diz "62% · ..."), a cada ponto inteiro.
    #>
    param (
        [Parameter(Mandatory)]
        [string]$FilePath,

        [string[]]$Arguments = @(),

        [switch]$Echo,

        [string]$ProgressActivity = "",

        # O que vem depois do percentual no texto da barra.
        [string]$ProgressStatus = (Get-WinForgeText 'não feche o WinForge até terminar')
    )

    $lines = New-Object System.Collections.Generic.List[string]
    $progress = @{ Last = -1.0; Bar = -1 }

    # Um programa que não existe não pode parecer um sucesso: com $ErrorActionPreference = Continue (o padrão da janela
    # e do console), o "não reconhecido" do PowerShell não interrompe a função e o código de saída ficaria 0.
    if ($null -eq (Get-Command -Name $FilePath -ErrorAction SilentlyContinue)) {
        throw (Get-WinForgeText 'O programa ''{0}'' não foi encontrado neste PC.' "$FilePath")
    }

    $global:LASTEXITCODE = 0

    & $FilePath @Arguments 2>&1 | ForEach-Object {
        $line = ([string]$_) -replace "`0", ""
        $lines.Add($line)

        if ($Echo -and (Test-WinForgeEchoLine -Line $line -State $progress)) {
            Write-Host $line
        }

        if ($ProgressActivity -and ($line.Contains("%") -or $line.Contains(" / "))) {
            $percent = Get-WinForgeProgressPercent -Line $line

            if ($null -ne $percent -and [int][Math]::Floor($percent) -ne [int]$progress.Bar) {
                $progress.Bar = [int][Math]::Floor($percent)
                Write-Progress -Activity $ProgressActivity -Status "$($progress.Bar)% · $ProgressStatus" -PercentComplete $progress.Bar
            }
        }
    }

    return [PSCustomObject]@{
        ExitCode = $LASTEXITCODE
        Lines    = @($lines)
        Text     = ($lines -join "`n")
    }
}


# ---------------------------------------------------------------------------
# Exclusão segura
# ---------------------------------------------------------------------------

function Remove-WinForgeItem {
    <#
    Remove um arquivo ou pasta. Atalhos de pasta (junção/link simbólico) são removidos como atalho, sem tocar no
    conteúdo de destino: o Windows PowerShell 5.1 pode seguir o link em Remove-Item -Recurse e apagar o que está fora
    da pasta limpa. Em pastas, apaga o que for possível e lança erro se algum item continuar em uso.
    #>
    param (
        [Parameter(Mandatory)]
        [string]$Path
    )

    $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop

    if (-not $item.PSIsContainer) {
        if ($item.IsReadOnly) {
            $item.IsReadOnly = $false
        }

        $item.Delete()
        return
    }

    if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
        $item.Delete()
        return
    }

    $failed = $false

    foreach ($child in @($item.EnumerateFileSystemInfos())) {
        try {
            Remove-WinForgeItem -Path $child.FullName
        }
        catch {
            $failed = $true
        }
    }

    if ($failed) {
        throw (Get-WinForgeText 'Há itens em uso em ''{0}''.' "$($item.Name)")
    }

    if (($item.Attributes -band [System.IO.FileAttributes]::ReadOnly) -ne 0) {
        $item.Attributes = $item.Attributes -band (-bnot [System.IO.FileAttributes]::ReadOnly)
    }

    $item.Delete()
}


function Remove-WinForgeFolder {
    <#
    Apaga uma pasta do próprio WinForge (temporária, de dados, da atualização) com Remove-WinForgeItem: um atalho de pasta
    lá dentro sai como atalho, sem levar o que está do outro lado. O Remove-Item -Recurse do Windows PowerShell 5.1 segue
    junções e apagaria o conteúdo de destino, o que, com o WinForge elevado, alcançaria pastas do sistema. Pasta ausente
    não é erro. Com -Quiet, o que não pôde ser apagado fica para trás sem erro (para limpezas de fim de ação).
    #>
    param (
        [Parameter(Mandatory)][AllowEmptyString()][string]$Path,
        [switch]$Quiet
    )

    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path)) { return }

    try {
        Remove-WinForgeItem -Path $Path
    }
    catch {
        if (-not $Quiet) { throw }
        Write-Verbose "Pasta não apagada ($Path): $($_.Exception.Message)"
    }
}


function Get-WinForgePathStats {
    <#
    Percorre um arquivo ou pasta sem seguir atalhos de pasta (junções e links simbólicos), que poderiam levar a
    outras pastas, a ciclos ou a contar duas vezes o mesmo conteúdo. Devolve Size (bytes), Files e Newest (data
    de alteração mais recente). Itens ilegíveis são ignorados: o resultado é uma estimativa.
    -ExcludeShellMetadata ignora desktop.ini e Thumbs.db, que não são conteúdo do usuário.
    A soma fica em variáveis locais, sem chamar um bloco por arquivo: Analisar uso de espaço passa por cada arquivo do
    perfil, e um bloco chamado a cada um, somando nas propriedades de um objeto, deixava a soma cinco vezes mais lenta.
    #>
    param (
        [string]$Path,
        [switch]$ExcludeShellMetadata
    )

    $size = [int64]0
    $files = [int64]0
    $newest = [datetime]::MinValue

    if (-not [string]::IsNullOrWhiteSpace($Path) -and (Test-Path -LiteralPath $Path)) {
        try {
            $root = Get-Item -LiteralPath $Path -Force -ErrorAction Stop

            if (-not $root.PSIsContainer) {
                if (-not ($ExcludeShellMetadata -and ($root.Name -eq "desktop.ini" -or $root.Name -eq "Thumbs.db"))) {
                    $size = [int64]$root.Length
                    $files = [int64]1
                    $newest = $root.LastWriteTime
                }
            }
            else {
                $pending = New-Object System.Collections.Generic.Stack[string]
                $pending.Push($root.FullName)

                while ($pending.Count -gt 0) {
                    $current = $pending.Pop()

                    try {
                        foreach ($entry in (New-Object System.IO.DirectoryInfo -ArgumentList $current).EnumerateFileSystemInfos()) {
                            try {
                                if ($entry -is [System.IO.DirectoryInfo]) {
                                    if (($entry.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -eq 0) {
                                        $pending.Push($entry.FullName)
                                    }

                                    continue
                                }

                                if ($ExcludeShellMetadata -and ($entry.Name -eq "desktop.ini" -or $entry.Name -eq "Thumbs.db")) { continue }

                                $size += $entry.Length
                                $files++

                                $written = $entry.LastWriteTime
                                if ($written -gt $newest) { $newest = $written }
                            }
                            catch {
                                # Item removido ou inacessível durante a leitura.
                            }
                        }
                    }
                    catch {
                        # Pasta inacessível: segue com as demais.
                    }
                }
            }
        }
        catch {
            # Caminho inacessível: devolve o que foi somado.
        }
    }

    return [PSCustomObject]@{
        Size   = $size
        Files  = $files
        Newest = $newest
    }
}


# Quanto um comando do Windows feito sobre o WMI pode esperar a resposta (Invoke-WinForgeCimCommand). Mais que os 15
# segundos das consultas diretas ao WMI: a primeira leitura dos discos pode precisar ligar o serviço de armazenamento, o
# que num HD lento demora, e um prazo curto demais diria "não foi possível ler" num PC só lento. A leitura dos discos
# físicos pelo WMI (Diagnostics.psm1) usa o mesmo número, escrito na chamada.
$script:WinForgeCimTimeoutSec = 60


function Invoke-WinForgeCimCommand {
    <#
    Um comando do Windows feito sobre o WMI (os dos módulos Defender, NetSecurity, Storage e PnpDevice: Get-MpComputerStatus,
    Get-NetFirewallProfile, Get-Partition, Get-PnpDevice...) com prazo. Esses comandos não têm o -OperationTimeoutSec das
    consultas diretas ao WMI, e um WMI com defeito, um disco morrendo ou o serviço do Defender travado os deixam parados
    sem fim. A consulta roda como um trabalho do próprio processo (-AsJob, que esses comandos têm); passado o prazo, ela é
    largada com um erro, como uma consulta ao WMI sem resposta, e o Parar também a interrompe. Um comando sem -AsJob roda
    direto.
    O Invoke-WinForgeInBackground não serve aqui: num runspace novo, o módulo do comando seria carregado de novo a cada
    consulta, e o resultado voltaria com os tipos daquele runspace, e não com os deste.
    #>
    param (
        [Parameter(Mandatory)][string]$Name,

        [hashtable]$Parameters = @{}
    )

    $command = Get-Command -Name $Name -ErrorAction Stop

    if (-not $command.Parameters.ContainsKey("AsJob")) {
        return @(& $command @Parameters -ErrorAction Stop)
    }

    $job = & $command @Parameters -AsJob -ErrorAction Stop

    if (-not (Wait-Job -Job $job -Timeout $script:WinForgeCimTimeoutSec)) {
        # Parar o trabalho esperando por ele travaria do mesmo jeito: o pedido de parada vai sem espera, e o trabalho
        # termina sozinho (ou junto com o WinForge).
        # O erro é de tempo esgotado (TimeoutException): quem chama pode não tentar de novo outra consulta que travaria igual.
        try { [void]$job.StopJobAsync() } catch { Write-Verbose "A consulta $Name não aceitou o pedido de parada." }
        throw (New-Object System.TimeoutException (Get-WinForgeText 'o Windows não respondeu em {0} segundos' "$script:WinForgeCimTimeoutSec"))
    }

    try {
        return @(Receive-Job -Job $job -ErrorAction Stop)
    }
    finally {
        Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
    }
}


function Invoke-WinForgeInBackground {
    <#
    Roda um bloco em outro runspace e espera por ele em fatias curtas, até $TimeoutSeconds. É para chamadas que podem
    demorar e que o botão Parar não consegue interromper por dentro (por exemplo, a consulta COM do Windows Update): a
    espera aqui continua interrompível, e um bloco que não termina a tempo é abandonado.
    O bloco roda num runspace novo e não enxerga as funções do WinForge; os valores entram por -ArgumentList (param).
    Devolve Completed, TimedOut, Output (o que o bloco escreveu) e Error (texto do primeiro erro, ou vazio).
    Quem tem outro trabalho a fazer enquanto o bloco roda usa as duas metades: Start-WinForgeInBackground e
    Receive-WinForgeInBackground.
    #>
    param (
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock,

        [object[]]$ArgumentList = @(),

        [ValidateRange(1, 3600)]
        [int]$TimeoutSeconds = 60
    )

    $task = Start-WinForgeInBackground -ScriptBlock $ScriptBlock -ArgumentList $ArgumentList

    return (Receive-WinForgeInBackground -Task $task -TimeoutSeconds $TimeoutSeconds)
}


function Start-WinForgeInBackground {
    <#
    Começa um bloco em outro runspace e devolve a tarefa sem esperar por ela: quem chama faz outra coisa enquanto isso
    (o Estado da proteção e a auditoria leem o antivírus e o firewall enquanto o Windows Update responde) e depois a recebe
    com Receive-WinForgeInBackground. Uma tarefa que não vai ser recebida (quem a começou parou antes) é largada com
    Stop-WinForgeInBackground, num finally.
    #>
    param (
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock,

        [object[]]$ArgumentList = @()
    )

    $shell = [powershell]::Create()

    try {
        [void]$shell.AddScript($ScriptBlock.ToString())

        foreach ($argument in $ArgumentList) {
            [void]$shell.AddArgument($argument)
        }

        $handle = $shell.BeginInvoke()
    }
    catch {
        $shell.Dispose()
        throw
    }

    # O prazo conta daqui: o tempo que o bloco rodou enquanto quem chama fazia outra coisa já vale.
    return [PSCustomObject]@{ Shell = $shell; Handle = $handle; Clock = [System.Diagnostics.Stopwatch]::StartNew(); Done = $false }
}


function Receive-WinForgeInBackground {
    <#
    Espera, em fatias curtas, por uma tarefa de Start-WinForgeInBackground, até $TimeoutSeconds desde o começo dela, e
    devolve Completed, TimedOut, Output e Error, como Invoke-WinForgeInBackground. A espera continua interrompível pelo
    Parar; uma tarefa que não termina a tempo é abandonada.
    #>
    param (
        [Parameter(Mandatory)]
        $Task,

        [ValidateRange(1, 3600)]
        [int]$TimeoutSeconds = 60
    )

    $shell = $Task.Shell
    $finished = $false

    try {
        while (-not $Task.Handle.AsyncWaitHandle.WaitOne(200)) {
            if ($Task.Clock.Elapsed.TotalSeconds -ge $TimeoutSeconds) {
                return [PSCustomObject]@{ Completed = $false; TimedOut = $true; Output = @(); Error = "" }
            }
        }

        $finished = $true
        $output = @()
        $errorText = ""

        try {
            $output = @($shell.EndInvoke($Task.Handle))
        }
        catch {
            $errorText = [string]$_.Exception.Message
        }

        if (-not $errorText -and $shell.Streams.Error.Count -gt 0) {
            $errorText = [string]$shell.Streams.Error[0]
        }

        return [PSCustomObject]@{ Completed = (-not $errorText); TimedOut = $false; Output = @($output); Error = $errorText }
    }
    finally {
        $Task.Done = $true

        if ($finished) {
            $shell.Dispose()
        }
        else {
            # Tempo esgotado ou interrompido: pede para parar sem esperar (Dispose bloquearia numa chamada COM presa).
            try { [void]$shell.BeginStop($null, $null) } catch { Write-Verbose "A tarefa em segundo plano não aceitou o pedido de parada: $($_.Exception.Message)" }
        }
    }
}


function Stop-WinForgeInBackground {
    # Larga uma tarefa de Start-WinForgeInBackground que não vai ser recebida: pede para parar sem esperar. Uma tarefa já
    # recebida (ou nenhuma) fica como está.
    param ($Task)

    if ($null -eq $Task -or [bool]$Task.Done) { return }

    $Task.Done = $true

    try {
        # Já terminado, o runspace é só liberado; ainda rodando, pedir para parar não espera (Dispose bloquearia numa chamada
        # COM presa).
        if ($Task.Handle.IsCompleted) { $Task.Shell.Dispose() } else { [void]$Task.Shell.BeginStop($null, $null) }
    }
    catch {
        Write-Verbose "A tarefa em segundo plano não aceitou o pedido de parada: $($_.Exception.Message)"
    }
}


# Quantos pedidos de "não suspender" estão abertos e em qual thread (Set-WinForgeKeepAwake).
$script:WinForgeKeepAwakeDepth = 0
$script:WinForgeKeepAwakeThread = -1


function Set-WinForgeThreadExecutionState {
    # Chama o SetThreadExecutionState do Windows. Devolve $false quando a API não está disponível ou recusou o pedido.
    param (
        [Parameter(Mandatory)]
        [bool]$KeepAwake
    )

    try {
        if (-not ("WinForge.PowerNative" -as [type])) {
            Add-Type -Namespace WinForge -Name PowerNative -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("kernel32.dll")]
public static extern uint SetThreadExecutionState(uint flags);
'@ -ErrorAction Stop
        }

        $continuous = [uint32]2147483648
        $systemRequired = [uint32]1

        if ($KeepAwake) {
            $flags = $continuous -bor $systemRequired
        }
        else {
            $flags = $continuous
        }

        return ([WinForge.PowerNative]::SetThreadExecutionState($flags) -ne 0)
    }
    catch {
        return $false
    }
}


function Set-WinForgeKeepAwake {
    <#
    Impede que o Windows suspenda o PC enquanto uma manutenção longa roda (SetThreadExecutionState).
    O pedido vale para a thread atual: chame com -Enabled $false (em um finally) ao terminar.
    Os pedidos se acumulam: o Windows guarda só o último estado da thread, então uma ação longa dentro de outra (o reparo
    dentro do Otimizar) desligaria, ao terminar, o pedido da de fora, e o PC poderia dormir no meio das
    etapas seguintes. Aqui cada -Enabled $true conta um pedido, cada -Enabled $false fecha um, e o PC só volta a poder
    dormir quando o último fecha.
    Retorna $false quando a API não está disponível (e aí o pedido não conta: quem recebeu $false não precisa fechá-lo).
    #>
    param (
        [Parameter(Mandatory)]
        [bool]$Enabled
    )

    # A contagem é da thread que fez os pedidos (o estado do Windows também é): uma ação que começa em outra thread começa
    # do zero, mesmo que a anterior tenha sido interrompida sem fechar o seu pedido.
    $thread = [System.Threading.Thread]::CurrentThread.ManagedThreadId

    if ($script:WinForgeKeepAwakeThread -ne $thread) {
        $script:WinForgeKeepAwakeThread = $thread
        $script:WinForgeKeepAwakeDepth = 0
    }

    if ($Enabled) {
        if ($script:WinForgeKeepAwakeDepth -gt 0) {
            # Já pedido por uma ação de fora, que continua valendo.
            $script:WinForgeKeepAwakeDepth++
            return $true
        }

        if (-not (Set-WinForgeThreadExecutionState -KeepAwake $true)) {
            return $false
        }

        $script:WinForgeKeepAwakeDepth = 1
        return $true
    }

    if ($script:WinForgeKeepAwakeDepth -gt 1) {
        # Uma ação de fora ainda precisa do PC acordado.
        $script:WinForgeKeepAwakeDepth--
        return $true
    }

    $script:WinForgeKeepAwakeDepth = 0

    return (Set-WinForgeThreadExecutionState -KeepAwake $false)
}


function Restart-WinForgeExplorerShell {
    # Configurações do Explorador e da barra de tarefas são recarregadas pelo shell.
    # O Windows relança o shell sozinho (no contexto do usuário). Só abrimos o explorer.exe
    # manualmente se isso não acontecer, porque um explorer iniciado por um processo elevado
    # herda privilégios de Administrador.
    $currentSessionId = (Get-Process -Id $PID).SessionId

    $getSessionExplorer = {
        @(
            Get-Process -Name "explorer" -ErrorAction SilentlyContinue |
                Where-Object { $_.SessionId -eq $currentSessionId }
        )
    }.GetNewClosure()

    $previousProcessIds = @(& $getSessionExplorer | Select-Object -ExpandProperty Id)

    if ($previousProcessIds.Count -gt 0) {
        & $getSessionExplorer | Stop-Process -Force -ErrorAction SilentlyContinue
    }

    # 1) Aguarda o encerramento dos processos antigos.
    $exitDeadline = [DateTime]::UtcNow.AddSeconds(5)
    $stillRunning = $false

    do {
        $stillRunning = @(
            Get-Process -ErrorAction SilentlyContinue |
                Where-Object { $previousProcessIds -contains $_.Id }
        ).Count -gt 0

        if (-not $stillRunning) { break }

        Start-Sleep -Milliseconds 100
    } while ([DateTime]::UtcNow -lt $exitDeadline)

    if ($stillRunning) {
        throw (Get-WinForgeText 'O Explorer do Windows não pôde ser encerrado.')
    }

    # 2) Dá tempo ao Windows para relançar o shell automaticamente.
    $autoDeadline = [DateTime]::UtcNow.AddSeconds(6)

    do {
        if (@(& $getSessionExplorer).Count -gt 0) {
            return
        }

        Start-Sleep -Milliseconds 250
    } while ([DateTime]::UtcNow -lt $autoDeadline)

    # 3) Fallback: inicia manualmente.
    [void](Start-Process -FilePath (Join-Path $env:WINDIR "explorer.exe") -ErrorAction Stop)

    $startupDeadline = [DateTime]::UtcNow.AddSeconds(8)

    do {
        if (@(& $getSessionExplorer).Count -gt 0) {
            return
        }

        Start-Sleep -Milliseconds 200
    } while ([DateTime]::UtcNow -lt $startupDeadline)

    throw (Get-WinForgeText 'O Explorer do Windows não reiniciou no tempo esperado.')
}


function Set-WinForgeHighPerformancePowerPlan {
    # Ativa o plano Alto desempenho. Devolve $true/$false; com -PassThru, Guid (o plano ativado; vazio no SCHEME_MIN) e
    # Created (se uma cópia nova do plano foi criada agora), ou $null quando nada funcionou.
    param (
        [switch]$ThrowOnFailure,

        # Uma cópia do plano que o WinForge já criou antes: se ela ainda existe, é ativada em vez de criar outra (sem
        # isso, cada aplicação deixava mais um "Alto desempenho" na lista de planos).
        [string]$PreferredGuid = "",

        [switch]$PassThru
    )

    $outcome = $null

    if (-not (Get-Command "powercfg.exe" -ErrorAction SilentlyContinue)) {
        if ($ThrowOnFailure) {
            throw (Get-WinForgeText 'powercfg.exe não foi encontrado.')
        }

        if ($PassThru) { return $null }
        return $false
    }

    # GUID do plano Alto desempenho. O fallback SCHEME_MIN é usado somente se necessário.
    $highPerformanceGuid = "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"
    $guidPattern = "[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}"

    $activate = {
        param ([string]$Scheme)
        return ((Invoke-WinForgeCapture -FilePath "powercfg.exe" -Arguments @("/setactive", $Scheme)).ExitCode -eq 0)
    }

    if ($PreferredGuid -match "^$guidPattern$" -and (& $activate $PreferredGuid)) {
        $outcome = [PSCustomObject]@{ Guid = $PreferredGuid.ToLowerInvariant(); Created = $false }
    }
    elseif (& $activate $highPerformanceGuid) {
        $outcome = [PSCustomObject]@{ Guid = $highPerformanceGuid; Created = $false }
    }
    else {
        # Em algumas instalações o plano pode não estar disponível. Nesse caso, recria a partir do template oficial.
        $duplicate = Invoke-WinForgeCapture -FilePath "powercfg.exe" -Arguments @("/duplicatescheme", $highPerformanceGuid)

        if ($duplicate.ExitCode -eq 0) {
            $newGuid = [regex]::Match($duplicate.Text, $guidPattern).Value

            if (-not [string]::IsNullOrWhiteSpace($newGuid)) {
                if (& $activate $newGuid) {
                    $outcome = [PSCustomObject]@{ Guid = $newGuid.ToLowerInvariant(); Created = $true }
                }
                else {
                    # Uma cópia que não pôde ser ativada só ocuparia a lista de planos.
                    [void](Invoke-WinForgeCapture -FilePath "powercfg.exe" -Arguments @("/delete", $newGuid))
                }
            }
        }

        # Fallback conhecido do powercfg: SCHEME_MIN representa o mínimo de economia de energia, ou seja, Alto desempenho.
        if ($null -eq $outcome -and (& $activate "SCHEME_MIN")) {
            $outcome = [PSCustomObject]@{ Guid = ""; Created = $false }
        }
    }

    if ($null -eq $outcome -and $ThrowOnFailure) {
        throw (Get-WinForgeText 'Não foi possível definir o plano de energia como Alto desempenho.')
    }

    if ($PassThru) { return $outcome }

    return ($null -ne $outcome)
}


# ---------------------------------------------------------------------------
# Última manutenção (usada pelo relatório e pela tela inicial)
# ---------------------------------------------------------------------------

function Get-WinForgeLastMaintenancePath {
    return (Join-Path (Get-WinForgeDataPath) "last-maintenance.json")
}


function ConvertTo-WinForgeSnapshotDocument {
    # Uma foto do PC (At, FreeBytes, StartupItems) como dicionário para o JSON; sem foto, $null.
    param ($Snapshot)

    if ($null -eq $Snapshot) {
        return $null
    }

    return [ordered]@{
        At           = ([datetime]$Snapshot.At).ToString("o", [System.Globalization.CultureInfo]::InvariantCulture)
        FreeBytes    = $Snapshot.FreeBytes
        StartupItems = $Snapshot.StartupItems
    }
}


function ConvertFrom-WinForgeSnapshotDocument {
    # O inverso de ConvertTo-WinForgeSnapshotDocument. Foto ausente ou ilegível = $null (arquivos de versões antigas).
    param ($Document)

    if ($null -eq $Document) {
        return $null
    }

    try {
        $at = [datetime]::Parse([string]$Document.At, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind)
        $free = $Document.PSObject.Properties["FreeBytes"]
        $startup = $Document.PSObject.Properties["StartupItems"]

        return [PSCustomObject]@{
            At           = $at
            FreeBytes    = $(if ($null -ne $free -and $null -ne $free.Value) { [int64]$free.Value } else { $null })
            StartupItems = $(if ($null -ne $startup -and $null -ne $startup.Value) { [int]$startup.Value } else { $null })
        }
    }
    catch {
        return $null
    }
}


function Set-WinForgeLastMaintenance {
    # Guarda em memória e em disco: a janela e as ações rodam em sessões separadas, e o relatório
    # precisa enxergar uma manutenção feita antes de o WinForge ser reaberto.
    # Before e After são as fotos do PC no começo e no fim (espaço livre e itens na inicialização); podem faltar.
    param (
        [object[]]$Results,
        [datetime]$StartedAt = (Get-Date),
        $Before = $null,
        $After = $null,

        # Como rodou (optimize; as manutenções da 3.50 e anteriores, quick, full ou deep); vai para o histórico.
        [string]$ProfileId = "",

        # A execução: gravada de novo com o mesmo RunId, a entrada do histórico é substituída, e não repetida.
        [string]$RunId = ""
    )

    $script:WinForgeLastMaintenance = [PSCustomObject]@{
        StartedAt = $StartedAt
        Results   = @($Results)
        Before    = $Before
        After     = $After
    }

    try {
        $document = [ordered]@{
            StartedAt = $StartedAt.ToString("o", [System.Globalization.CultureInfo]::InvariantCulture)
            Before    = (ConvertTo-WinForgeSnapshotDocument -Snapshot $Before)
            After     = (ConvertTo-WinForgeSnapshotDocument -Snapshot $After)
            Results   = @(
                foreach ($result in @($Results)) {
                    [ordered]@{
                        Etapa   = [string]$result.Etapa
                        Status  = [string]$result.Status
                        Kind    = [string]$result.Kind
                        Duracao = [string]$result.Duracao
                    }
                }
            )
        }

        Write-WinForgeStateJson -Path (Get-WinForgeLastMaintenancePath) -InputObject $document -Depth 4
    }
    catch {
        # O histórico em disco é um complemento; a memória já tem o resultado.
    }

    try {
        $entry = New-WinForgeMaintenanceHistoryEntry -Results $Results -StartedAt $StartedAt -Before $Before -After $After -ProfileId $ProfileId -RunId $RunId
        # O "gravou?" não sai daqui: no fim do resumo da manutenção ele aparecia na tela como uma linha "True".
        [void](Add-WinForgeMaintenanceHistory -Entry $entry)
    }
    catch {
        # Idem: o histórico é só um complemento.
    }
}


function Get-WinForgeLastMaintenance {
    # O registro da última manutenção, ou $null quando não há (ou ele é de outra versão). -Strict: um registro que existe,
    # mas não pôde ser lido (preso por outro programa, sem permissão), lança erro em vez de passar por "nunca rodou".
    param ([switch]$Strict)

    if ($null -ne $script:WinForgeLastMaintenance) {
        return $script:WinForgeLastMaintenance
    }

    $state = Read-WinForgeStateFile -Path (Get-WinForgeLastMaintenancePath)

    if ($Strict -and [string]$state.Status -eq "Unreadable") {
        throw (Get-WinForgeText 'Não foi possível ler o registro da última manutenção.')
    }

    try {
        $document = $state.Document

        if ($null -eq $document) {
            return $null
        }

        $startedAt = [datetime]::Parse([string]$document.StartedAt, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind)

        # Arquivos gravados por versões anteriores não têm Before/After.
        $before = $document.PSObject.Properties["Before"]
        $after = $document.PSObject.Properties["After"]

        return [PSCustomObject]@{
            StartedAt = $startedAt
            Results   = @($document.Results)
            Before    = $(if ($null -ne $before) { ConvertFrom-WinForgeSnapshotDocument -Document $before.Value } else { $null })
            After     = $(if ($null -ne $after) { ConvertFrom-WinForgeSnapshotDocument -Document $after.Value } else { $null })
        }
    }
    catch {
        # Arquivo ausente, truncado ou de outra versão: trata como "nunca rodou".
        return $null
    }
}


# ---------------------------------------------------------------------------
# Histórico de manutenções (as últimas, para ver tendências)
# ---------------------------------------------------------------------------

$script:WinForgeMaintenanceHistoryLimit = 20


function Get-WinForgeMaintenanceHistoryLimit {
    return [int]$script:WinForgeMaintenanceHistoryLimit
}


function Get-WinForgeJsonValue {
    # Lê uma propriedade de um objeto vindo do JSON sem falhar quando ela não existe (modo estrito) ou é nula.
    param (
        $Object,
        [string]$Name,
        $Default = $null
    )

    if ($null -eq $Object) {
        return $Default
    }

    $property = $Object.PSObject.Properties[$Name]

    if ($null -eq $property -or $null -eq $property.Value) {
        return $Default
    }

    return $property.Value
}


function Get-WinForgeMaintenanceHistoryPath {
    return (Join-Path (Get-WinForgeDataPath) "maintenance-history.json")
}


function New-WinForgeMaintenanceHistoryEntry {
    # Uma linha do histórico: quando, quanto durou, o perfil, quantas etapas deram certo/ressalva/falha e as fotos do PC.
    param (
        [object[]]$Results,
        [datetime]$StartedAt,
        [datetime]$EndedAt = (Get-Date),
        $Before = $null,
        $After = $null,
        [string]$ProfileId = "",

        # A execução (o Otimizar grava duas vezes a mesma: no fim da parte automática e no fim); "" nas antigas.
        [string]$RunId = ""
    )

    $rows = @($Results | Where-Object { $null -ne $_ })

    $count = {
        param ([string]$Kind)
        @($rows | Where-Object { $null -ne $_.PSObject.Properties["Kind"] -and $_.Kind -eq $Kind }).Count
    }

    $seconds = [int][math]::Max(0, [math]::Round(($EndedAt - $StartedAt).TotalSeconds))

    # O que as etapas disseram ter liberado (Data.FreedBytes: a limpeza, os componentes, os restos de programas), e não a
    # variação do espaço livre, que mistura o que as atualizações ocuparam. Cada etapa devolve um resultado só, então a
    # soma não conta nada duas vezes. $null quando nenhuma etapa mediu.
    $freed = $null

    foreach ($row in $rows) {
        $data = Get-WinForgeJsonValue -Object $row -Name "Data"
        if (-not ($data -is [System.Collections.IDictionary]) -or -not $data.Contains("FreedBytes") -or $null -eq $data["FreedBytes"]) { continue }

        try {
            $bytes = [int64]$data["FreedBytes"]
            if ($bytes -lt 0) { continue }
            if ($null -eq $freed) { $freed = [int64]0 }
            $freed += $bytes
        }
        catch {
            continue
        }
    }

    return [PSCustomObject]@{
        StartedAt       = $StartedAt
        DurationSeconds = $seconds
        ProfileId       = $ProfileId
        RunId           = $RunId
        Freed           = $freed
        Ok              = [int](& $count "Ok")
        Warning         = [int](& $count "Warning")
        Failed          = [int](& $count "Failed")
        Skipped         = [int](& $count "Skipped")
        FreeBefore      = $(if ($null -ne $Before) { Get-WinForgeJsonValue -Object $Before -Name "FreeBytes" } else { $null })
        FreeAfter       = $(if ($null -ne $After) { Get-WinForgeJsonValue -Object $After -Name "FreeBytes" } else { $null })
        StartupBefore   = $(if ($null -ne $Before) { Get-WinForgeJsonValue -Object $Before -Name "StartupItems" } else { $null })
        StartupAfter    = $(if ($null -ne $After) { Get-WinForgeJsonValue -Object $After -Name "StartupItems" } else { $null })
        Steps           = @(
            foreach ($row in $rows) {
                [PSCustomObject]@{
                    Etapa   = [string](Get-WinForgeJsonValue -Object $row -Name "Etapa" -Default "")
                    Kind    = [string](Get-WinForgeJsonValue -Object $row -Name "Kind" -Default "")
                    Duracao = [string](Get-WinForgeJsonValue -Object $row -Name "Duracao" -Default "")
                }
            }
        )
    }
}


function ConvertFrom-WinForgeMaintenanceHistoryDocument {
    # Uma linha do JSON como entrada do histórico. Linha ilegível = $null; campos que faltam ficam nulos ou zerados.
    param ($Document)

    if ($null -eq $Document) {
        return $null
    }

    try {
        $startedAt = [datetime]::Parse([string](Get-WinForgeJsonValue -Object $Document -Name "StartedAt"), [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind)

        $number = {
            param ([string]$Name)
            $value = Get-WinForgeJsonValue -Object $Document -Name $Name
            if ($null -eq $value) { return $null }
            return [int64]$value
        }

        return [PSCustomObject]@{
            StartedAt       = $startedAt
            DurationSeconds = [int](Get-WinForgeJsonValue -Object $Document -Name "DurationSeconds" -Default 0)
            ProfileId       = [string](Get-WinForgeJsonValue -Object $Document -Name "ProfileId" -Default "")
            RunId           = [string](Get-WinForgeJsonValue -Object $Document -Name "RunId" -Default "")
            Freed           = (& $number "Freed")
            Ok              = [int](Get-WinForgeJsonValue -Object $Document -Name "Ok" -Default 0)
            Warning         = [int](Get-WinForgeJsonValue -Object $Document -Name "Warning" -Default 0)
            Failed          = [int](Get-WinForgeJsonValue -Object $Document -Name "Failed" -Default 0)
            Skipped         = [int](Get-WinForgeJsonValue -Object $Document -Name "Skipped" -Default 0)
            FreeBefore      = (& $number "FreeBefore")
            FreeAfter       = (& $number "FreeAfter")
            StartupBefore   = (& $number "StartupBefore")
            StartupAfter    = (& $number "StartupAfter")
            Steps           = @(
                foreach ($step in @(Get-WinForgeJsonValue -Object $Document -Name "Steps" -Default @())) {
                    [PSCustomObject]@{
                        Etapa   = [string](Get-WinForgeJsonValue -Object $step -Name "Etapa" -Default "")
                        Kind    = [string](Get-WinForgeJsonValue -Object $step -Name "Kind" -Default "")
                        Duracao = [string](Get-WinForgeJsonValue -Object $step -Name "Duracao" -Default "")
                    }
                }
            )
        }
    }
    catch {
        return $null
    }
}


function Get-WinForgeMaintenanceHistory {
    # As manutenções registradas, da mais recente para a mais antiga (a ordem em que foram gravadas, e não a das datas: com
    # o relógio atrasado, uma manutenção nova teria data "antiga"). Arquivo ausente ou ilegível = lista vazia (um arquivo
    # estragado volta da cópia anterior). -Status devolve também o estado da leitura, para quem vai gravar.
    param ([switch]$Status)

    $read = [PSCustomObject]@{ Status = "Unreadable"; Document = $null }

    try {
        $read = Read-WinForgeStateFile -Path (Get-WinForgeMaintenanceHistoryPath)

        if ($null -eq $read.Document) {
            if ($Status) { return [PSCustomObject]@{ Status = $read.Status; Entries = @() } }
            return @()
        }

        $document = $read.Document

        $entries = @(
            foreach ($row in @($document)) {
                $entry = ConvertFrom-WinForgeMaintenanceHistoryDocument -Document $row
                if ($null -ne $entry) { $entry }
            }
        )

        if ($Status) { return [PSCustomObject]@{ Status = $read.Status; Entries = $entries } }
        return $entries
    }
    catch {
        if ($Status) { return [PSCustomObject]@{ Status = "Unreadable"; Entries = @() } }
        return @()
    }
}


function Add-WinForgeMaintenanceHistory {
    # Acrescenta uma entrada e mantém só as últimas. Devolve $true se gravou.
    param (
        [Parameter(Mandatory)]
        $Entry
    )

    try {
        return [bool](Invoke-WinForgeStateLock -ScriptBlock { Save-WinForgeMaintenanceHistoryEntry -Entry $Entry })
    }
    catch {
        return $false
    }
}


function Save-WinForgeMaintenanceHistoryEntry {
    # O ler-acrescentar-gravar de Add-WinForgeMaintenanceHistory (que o faz dentro da trava).
    param (
        [Parameter(Mandatory)]
        $Entry
    )

    try {
        $current = Get-WinForgeMaintenanceHistory -Status

        # Sem conseguir ler o histórico gravado, gravar agora deixaria só esta entrada.
        if ($current.Status -eq "Unreadable") { return $false }

        # A mesma execução gravada de novo (o Otimizar grava ao fim da parte automática e outra vez no fim) substitui a
        # entrada dela, reconhecida pelo RunId: o histórico não fica com a mesma manutenção duas vezes. Sem RunId (as
        # gravadas por versões anteriores), nada é substituído.
        $runId = [string](Get-WinForgeJsonValue -Object $Entry -Name "RunId" -Default "")
        $existing = @($current.Entries | Where-Object {
            $null -ne $_ -and ([string]::IsNullOrEmpty($runId) -or [string](Get-WinForgeJsonValue -Object $_ -Name "RunId" -Default "") -ne $runId)
        })
        # A nova entra na frente e a mais antiga gravada sai: ordenar pela data descartaria a nova se o relógio estivesse
        # atrasado (bateria da placa-mãe fraca, por exemplo), com a gravação dizendo que deu certo.
        $all = @(@($Entry) + $existing | Select-Object -First (Get-WinForgeMaintenanceHistoryLimit))

        $documents = @(
            foreach ($item in $all) {
                [ordered]@{
                    StartedAt       = ([datetime]$item.StartedAt).ToString("o", [System.Globalization.CultureInfo]::InvariantCulture)
                    DurationSeconds = $item.DurationSeconds
                    ProfileId       = $item.ProfileId
                    RunId           = [string](Get-WinForgeJsonValue -Object $item -Name "RunId" -Default "")
                    Freed           = (Get-WinForgeJsonValue -Object $item -Name "Freed")
                    Ok              = $item.Ok
                    Warning         = $item.Warning
                    Failed          = $item.Failed
                    Skipped         = $item.Skipped
                    FreeBefore      = $item.FreeBefore
                    FreeAfter       = $item.FreeAfter
                    StartupBefore   = $item.StartupBefore
                    StartupAfter    = $item.StartupAfter
                    Steps           = @(
                        foreach ($step in @($item.Steps)) {
                            [ordered]@{ Etapa = $step.Etapa; Kind = $step.Kind; Duracao = $step.Duracao }
                        }
                    )
                }
            }
        )

        # Um único item continua lista no JSON.
        Write-WinForgeStateJson -Path (Get-WinForgeMaintenanceHistoryPath) -InputObject $documents -Depth 5 -AsList

        return $true
    }
    catch {
        return $false
    }
}


# ---------------------------------------------------------------------------
# Histórico de mudanças (o diário; o desfazer e a tela ficam em Journal.psm1)
# ---------------------------------------------------------------------------

function Get-WinForgeChangeJournalPath {
    return (Join-Path (Get-WinForgeDataPath) "changes.json")
}


function Get-WinForgeChangeJournalLimit {
    return 200
}


function Get-WinForgeChanges {
    # As mudanças anotadas, da mais recente para a mais antiga. Arquivo ausente ou ilegível = nenhuma (um arquivo estragado
    # volta da cópia anterior). -Status devolve também o estado da leitura, para quem vai gravar.
    param ([switch]$Status)

    $read = [PSCustomObject]@{ Status = "Unreadable"; Document = $null }
    try { $read = Read-WinForgeStateFile -Path (Get-WinForgeChangeJournalPath) } catch { $read = [PSCustomObject]@{ Status = "Unreadable"; Document = $null } }

    $document = $read.Document

    if ($null -eq $document) {
        if ($Status) { return [PSCustomObject]@{ Status = $read.Status; Changes = @() } }
        return @()
    }

    $entries = @(
        foreach ($item in @(Get-WinForgeJsonValue -Object $document -Name "Changes" -Default @())) {
            $at = [datetime]::MinValue
            $atText = [string](Get-WinForgeJsonValue -Object $item -Name "At" -Default "")

            if (-not [datetime]::TryParse($atText, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind, [ref]$at)) { continue }

            [PSCustomObject]@{
                Id     = [string](Get-WinForgeJsonValue -Object $item -Name "Id" -Default "")
                At     = $at
                Action = [string](Get-WinForgeJsonValue -Object $item -Name "Action" -Default "")
                Text   = [string](Get-WinForgeJsonValue -Object $item -Name "Text" -Default "")
                Undo   = (Get-WinForgeJsonValue -Object $item -Name "Undo" -Default $null)
                Undone = [bool](Get-WinForgeJsonValue -Object $item -Name "Undone" -Default $false)
            }
        }
    )

    $sorted = @($entries | Where-Object { $_.Id } | Sort-Object -Property At -Descending)

    if ($Status) { return [PSCustomObject]@{ Status = $read.Status; Changes = $sorted } }
    return $sorted
}


function Save-WinForgeChanges {
    # Grava a lista inteira (as mais recentes até o limite). Falha em silêncio: o diário nunca interrompe uma ação.
    param (
        [AllowEmptyCollection()][object[]]$Changes = @()
    )

    try {
        $kept = @($Changes | Sort-Object -Property At -Descending | Select-Object -First (Get-WinForgeChangeJournalLimit))
        $document = [ordered]@{
            Format  = "WinForge.Changes"
            Version = 1
            Changes = @($kept | ForEach-Object {
                    [ordered]@{
                        Id     = $_.Id
                        At     = ([datetime]$_.At).ToString("o", [System.Globalization.CultureInfo]::InvariantCulture)
                        Action = $_.Action
                        Text   = $_.Text
                        Undo   = $_.Undo
                        Undone = [bool]$_.Undone
                    }
                })
        }

        Write-WinForgeStateJson -Path (Get-WinForgeChangeJournalPath) -InputObject $document -Depth 8

        return $true
    }
    catch {
        return $false
    }
}


function Add-WinForgeChange {
    <#
    Anota uma mudança. Action é o nome curto ("Limpeza do registro"); Text, o que mudou ("12 entradas removidas"). Undo
    é $null (não dá para desfazer) ou uma hashtable com Kind e os dados de Undo-WinForgeChange: registry (File),
    startup (Items), tweak (Id), dns, feature (Name, Action), winget-pin (Items) ou keyboard-hotkeys (Before e After). Devolve o Id da mudança ("" se não foi possível anotar).
    #>
    param (
        [Parameter(Mandatory)][string]$Action,
        [Parameter(Mandatory)][string]$Text,
        $Undo = $null,
        [datetime]$At = (Get-Date)
    )

    # Anotar nunca interrompe a ação que mudou o PC: qualquer falha aqui só deixa a mudança fora do histórico.
    try {
        $id = [guid]::NewGuid().ToString("N").Substring(0, 12)

        $saved = Invoke-WinForgeStateLock -ScriptBlock {
            $current = Get-WinForgeChanges -Status

            # Sem conseguir ler o diário gravado, gravar agora deixaria só esta mudança: as outras perderiam o desfazer.
            if ($current.Status -eq "Unreadable") { return $false }

            $changes = @($current.Changes) + @([PSCustomObject]@{ Id = $id; At = $At; Action = $Action; Text = $Text; Undo = $Undo; Undone = $false })
            return (Save-WinForgeChanges -Changes $changes)
        }

        if ($saved) { return $id }
    }
    catch {
        Write-Verbose "Histórico de mudanças: $($_.Exception.Message)"
    }

    return ""
}


function Set-WinForgeChangeUndone {
    param (
        [Parameter(Mandatory)][string]$Id
    )

    [void](Invoke-WinForgeStateLock -ScriptBlock {
            $current = Get-WinForgeChanges -Status
            if ($current.Status -eq "Unreadable") { return }

            $changes = @($current.Changes)

            foreach ($change in $changes) {
                if ($change.Id -eq $Id) { $change.Undone = $true }
            }

            [void](Save-WinForgeChanges -Changes $changes)
        })
}


function Set-WinForgeChangesUndone {
    # Marca como desfeitas as mudanças ainda ativas de um tipo com um dado valor (por exemplo, o ajuste "explorer.ext"
    # desfeito pela página Ajustes do Windows): elas não aparecem mais para desfazer. Falha em silêncio.
    param (
        [Parameter(Mandatory)][string]$Kind,
        [Parameter(Mandatory)][string]$Key,
        [Parameter(Mandatory)][string]$Value
    )

    try {
        [void](Invoke-WinForgeStateLock -ScriptBlock {
                $current = Get-WinForgeChanges -Status
                if ($current.Status -eq "Unreadable") { return }

                $changes = @($current.Changes)
                $marked = 0

                foreach ($change in $changes) {
                    if ($change.Undone -or $null -eq $change.Undo) { continue }
                    if ([string](Get-WinForgeJsonValue -Object $change.Undo -Name "Kind" -Default "") -ne $Kind) { continue }
                    if ([string](Get-WinForgeJsonValue -Object $change.Undo -Name $Key -Default "") -ne $Value) { continue }

                    $change.Undone = $true
                    $marked++
                }

                if ($marked -gt 0) { [void](Save-WinForgeChanges -Changes $changes) }
            })
    }
    catch {
        Write-Verbose "Histórico de mudanças: $($_.Exception.Message)"
    }
}


# Os tipos de desfazer que o Undo-WinForgeChange (Journal) sabe fazer, um para cada caso do switch dele. Uma anotação de
# outro tipo (a cor de destaque das versões de teste da 4.0, ou uma de versão mais nova) fica no histórico sem o desfazer:
# o botão só apareceria para falhar.
$script:WinForgeUndoKinds = @("registry", "startup", "tweak", "dns", "feature", "keyboard-hotkeys", "winget-pin")

function Test-WinForgeChangeUndoable {
    # Se a mudança tem como ser desfeita agora (tem um modo de desfazer que esta versão conhece e ainda não foi desfeita).
    param (
        [Parameter(Mandatory)]$Change
    )

    if ($Change.Undone -or $null -eq $Change.Undo) { return $false }

    return ([string](Get-WinForgeJsonValue -Object $Change.Undo -Name "Kind" -Default "") -in $script:WinForgeUndoKinds)
}


function Add-WinForgeUninstalledProgram {
    # Guarda o nome e o ID de um programa desinstalado pelo WinForge, para a busca de restos (os 50 mais recentes).
    param (
        [Parameter(Mandatory)][string]$Name,
        [string]$Id = ""
    )

    try {
        [void](Invoke-WinForgeStateLock -ScriptBlock {
                $list = @(Get-WinForgeSetting -Name "UninstalledPrograms" -Default @()) | Where-Object { $null -ne $_ -and [string](Get-WinForgeJsonValue -Object $_ -Name "Name" -Default "") -ne $Name }
                $list = @([PSCustomObject]@{ Name = $Name; Id = $Id; At = (Get-Date).ToString("yyyy-MM-dd", [System.Globalization.CultureInfo]::InvariantCulture) }) + @($list) | Select-Object -First 50
                [void](Set-WinForgeSetting -Name "UninstalledPrograms" -Value @($list))
            })
    }
    catch {
        Write-Verbose "Não foi possível guardar o programa desinstalado: $($_.Exception.Message)"
    }
}

Export-ModuleMember -Function *
