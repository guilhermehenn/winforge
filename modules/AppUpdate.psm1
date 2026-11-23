# Nova versão do WinForge: consulta a última versão publicada no GitHub, baixa o WinForge.zip para a pasta Downloads e
# confere o SHA-256 do arquivo antes de dizer que ele está pronto.
#
# Instalar é com a janela fechada: o WinForge.Setup.ps1 da versão nova espera o WinForge fechar, troca os arquivos
# (voltando ao que era se algo falhar; Install.psm1) e abre o WinForge de novo. O hash vem do "digest" que o GitHub
# publica para cada arquivo de um release; sem ele, nada é baixado (um arquivo que não pode ser conferido não deve virar
# instalação).


# ---------------------------------------------------------------------------
# Versão e endereços
# ---------------------------------------------------------------------------

function Get-WinForgeRepository {
    return "guilhermehenn/winforge"
}


function Get-WinForgeWebsiteUrl {
    # O site do WinForge, na página de um idioma (sem -Language, o da janela): o português na raiz, o inglês em /en/ e o
    # espanhol em /es/. O download e a atualização continuam no GitHub (Get-WinForgeRepository).
    param (
        [string]$Language = ""
    )

    $site = "https://usewinforge.com.br"

    if ([string]::IsNullOrEmpty($Language)) { $Language = [string](Get-WinForgeLanguage) }

    switch ($Language) {
        "en" { return "$site/en/" }
        "es" { return "$site/es/" }
    }

    return $site
}


function ConvertTo-WinForgeVersion {
    # "v3.7", "Build 3.7" e "3.7.0" viram o mesmo [version] (sem componentes -1, que fariam 3.7 ser menor que 3.7.0).
    # Texto sem número vira $null.
    param (
        [string]$Text
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $null
    }

    # O primeiro número com ponto que não é pedaço de outro: em "WinForge 2026 v3.45" é 3.45 (e não 2026), e ".44"
    # sozinho não é versão. Sem ponto, só um número que é o texto inteiro ("v4", "Build 4").
    $match = [regex]::Match($Text, '(?<![0-9.])v?([0-9]+\.[0-9]+(?:\.[0-9]+){0,2})(?![0-9.])')

    if ($match.Success) {
        $value = $match.Groups[1].Value
    }
    elseif ($Text -match '^\s*(?:v|Build\s+)?([0-9]+)\s*$') {
        $value = "$($Matches[1]).0"
    }
    else {
        return $null
    }

    $parsed = $null

    if (-not [version]::TryParse($value, [ref]$parsed)) {
        return $null
    }

    return (New-Object System.Version -ArgumentList $parsed.Major, $parsed.Minor, ([Math]::Max($parsed.Build, 0)), ([Math]::Max($parsed.Revision, 0)))
}


function Format-WinForgeVersion {
    # 3.7.0.0 volta a ser "3.7"; só mostra Build e Revision quando existem.
    param (
        [Parameter(Mandatory)]
        [version]$Version
    )

    if ($Version.Revision -gt 0) {
        return $Version.ToString(4)
    }

    if ($Version.Build -gt 0) {
        return $Version.ToString(3)
    }

    return $Version.ToString(2)
}


function Test-WinForgeReleaseDownloadUrl {
    # O arquivo só é baixado se o endereço for https e apontar para um release do próprio repositório. Um nome de
    # arquivo vindo da internet nunca é usado como caminho: quem escolhe o nome do arquivo local é o WinForge.
    param (
        [string]$Url
    )

    if ([string]::IsNullOrWhiteSpace($Url) -or $Url -ne $Url.Trim()) {
        return $false
    }

    # "/../", "/./", as formas codificadas ("%2e") e barras codificadas ("%2f", "%5c") sairiam da pasta de downloads do
    # repositório depois que o endereço fosse normalizado; nenhum endereço de release legítimo tem isso.
    if ($Url -match '(?i)(^|[/\\])(\.|%2e){1,2}([/\\?#]|$)' -or $Url -match '(?i)%2f|%5c' -or $Url.Contains("\")) {
        return $false
    }

    $uri = $null

    if (-not [Uri]::TryCreate($Url, [UriKind]::Absolute, [ref]$uri)) {
        return $false
    }

    if ($uri.Scheme -ne "https" -or $uri.Host -ne "github.com" -or -not $uri.IsDefaultPort -or $uri.UserInfo) {
        return $false
    }

    $folder = "/$(Get-WinForgeRepository)/releases/download/"

    return ($uri.AbsolutePath.Length -gt $folder.Length -and $uri.AbsolutePath.StartsWith($folder, [StringComparison]::OrdinalIgnoreCase))
}


# ---------------------------------------------------------------------------
# Consulta
# ---------------------------------------------------------------------------

function ConvertTo-WinForgeWebErrorText {
    <#
    Uma falha de rede, do GitHub ou do disco em português, com o que fazer: o .NET escreve a mensagem em inglês na
    maioria dos Windows em português. Devolve "" quando a falha não é de um tipo conhecido (quem chama usa a mensagem
    original). O limite de consultas do GitHub (60 por hora por conexão) diz a hora em que libera. -NotFound: o que dizer
    quando o endereço não existe (404), conforme o que se buscava.
    #>
    param (
        $Exception,
        [string]$NotFound = (Get-WinForgeText 'o GitHub não encontrou uma versão publicada do WinForge')
    )

    $code = 0
    $status = ""
    $reset = ""
    $remaining = ""
    $retryAfter = ""

    for ($current = $Exception; $null -ne $current; $current = $current.InnerException) {
        if ($current -is [System.IO.IOException] -and (($current.HResult -band 0xFFFF) -in 39, 112)) {
            return (Get-WinForgeText 'falta espaço em disco')
        }

        if ($current -is [System.Net.WebException] -and -not $status) { $status = [string]$current.Status }

        $response = $null
        if ($null -ne $current.PSObject.Properties["Response"]) { $response = $current.Response }

        if ($null -ne $response -and $code -eq 0) {
            try { $code = [int]$response.StatusCode } catch { $code = 0 }

            foreach ($name in "X-RateLimit-Reset", "X-RateLimit-Remaining", "Retry-After") {
                $value = ""

                try {
                    if ($response.Headers -is [System.Net.WebHeaderCollection]) {
                        $value = [string]$response.Headers[$name]
                    }
                    else {
                        $values = $null
                        if ($response.Headers.TryGetValues($name, [ref]$values)) { $value = [string]@($values)[0] }
                    }
                }
                catch {
                    $value = ""
                }

                if ($name -eq "X-RateLimit-Reset") { $reset = $value } elseif ($name -eq "Retry-After") { $retryAfter = $value } else { $remaining = $value }
            }
        }
    }

    # O limite secundário (consultas demais em pouco tempo) vem como 403 com Retry-After, em segundos.
    if (($code -eq 403 -or $code -eq 429) -and $retryAfter) {
        return (Get-WinForgeText 'o GitHub limitou por um tempo as consultas vindas desta conexão; tente de novo em alguns minutos')
    }

    if ($code -eq 429 -or ($code -eq 403 -and $remaining -eq "0")) {
        $text = (Get-WinForgeText 'o GitHub limitou por um tempo as consultas vindas desta conexão')
        $epoch = 0L

        if ([int64]::TryParse($reset, [ref]$epoch) -and $epoch -gt 0) {
            $when = [DateTimeOffset]::FromUnixTimeSeconds($epoch).LocalDateTime
            $text = (Get-WinForgeText '{0}; tente de novo depois das {1}' "$text" "$(Format-WinForgeDateTime -When $when -Pattern 'HH:mm')")
        }
        else {
            $text = (Get-WinForgeText '{0}; tente de novo em uma hora' "$text")
        }

        return $text
    }

    if ($code -eq 404) { return $NotFound }
    if ($code -ge 500) { return (Get-WinForgeText 'o GitHub está com problemas agora (erro {0}); tente de novo mais tarde' "$code") }
    if ($code -ge 400) { return (Get-WinForgeText 'o GitHub recusou a consulta (erro {0}); tente de novo mais tarde' "$code") }

    switch -Regex ($status) {
        '^(NameResolutionFailure|ProxyNameResolutionFailure|ConnectFailure)$' { return (Get-WinForgeText 'sem conexão com o GitHub: confira a internet ou se esta rede bloqueia o github.com') }
        '^Timeout$' { return (Get-WinForgeText 'o GitHub não respondeu a tempo; tente de novo mais tarde') }
        '^(TrustFailure|SecureChannelFailure)$' { return (Get-WinForgeText 'a conexão segura com o GitHub falhou; confira se a data e a hora do PC estão certas') }
        '^(ConnectionClosed|ReceiveFailure|SendFailure|KeepAliveFailure)$' { return (Get-WinForgeText 'a conexão com o GitHub caiu no meio; tente de novo') }
    }

    return ""
}


function Get-WinForgeLatestRelease {
    <#
    Lê a última versão publicada (não conta rascunho nem pré-lançamento). Devolve Tag, Version, PageUrl, Published,
    Notes e Asset (Url, Size, Digest; $null quando o release não tem o WinForge.zip). Lança erro quando o GitHub não
    responde ou a resposta não faz sentido; quem chama decide como avisar.
    #>
    $uri = "https://api.github.com/repos/$(Get-WinForgeRepository)/releases/latest"

    Enable-WinForgeTls12

    $headers = @{
        "User-Agent" = "WinForge/$(Get-WinForgeBuild)"
        "Accept"     = "application/vnd.github+json"
    }

    $release = Invoke-RestMethod -Uri $uri -Headers $headers -TimeoutSec 15 -ErrorAction Stop

    $tag = [string](Get-WinForgeJsonValue -Object $release -Name "tag_name" -Default "")
    $version = ConvertTo-WinForgeVersion -Text $tag

    if ($null -eq $version) {
        throw (Get-WinForgeText 'A resposta do GitHub não trouxe uma versão reconhecível.')
    }

    $asset = $null

    foreach ($candidate in @(Get-WinForgeJsonValue -Object $release -Name "assets" -Default @())) {
        if ([string](Get-WinForgeJsonValue -Object $candidate -Name "name" -Default "") -ieq "WinForge.zip") {
            $asset = [PSCustomObject]@{
                Url    = [string](Get-WinForgeJsonValue -Object $candidate -Name "browser_download_url" -Default "")
                Size   = [int64](Get-WinForgeJsonValue -Object $candidate -Name "size" -Default 0)
                Digest = [string](Get-WinForgeJsonValue -Object $candidate -Name "digest" -Default "")
            }
            break
        }
    }

    # A data do GitHub é ISO 8601 em UTC; vira a hora local (uma publicação às 01:30 UTC do dia 30 ainda é dia 29 no
    # Brasil). A leitura não depende do idioma do Windows.
    $published = $null
    $publishedText = [string](Get-WinForgeJsonValue -Object $release -Name "published_at" -Default "")
    $parsed = [datetime]::MinValue

    if ($publishedText -and [datetime]::TryParse($publishedText, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind, [ref]$parsed)) {
        $published = $parsed.ToLocalTime()
    }

    return [PSCustomObject]@{
        Tag       = $tag
        Version   = $version
        PageUrl   = [string](Get-WinForgeJsonValue -Object $release -Name "html_url" -Default "")
        Published = $published
        Notes     = [string](Get-WinForgeJsonValue -Object $release -Name "body" -Default "")
        Asset     = $asset
    }
}


function Get-WinForgeUpdateStatus {
    <#
    Compara a versão instalada com a última publicada. Status: UpdateAvailable, UpToDate, Ahead (a instalada é mais
    nova que a publicada, comum em quem testa uma versão antes do release) ou Unreachable (sem internet, bloqueio ou
    resposta inválida; Error leva o motivo em português quando ele é conhecido). Current e Release vêm preenchidos
    quando foi possível ler.
    #>
    $current = ConvertTo-WinForgeVersion -Text ([string](Get-WinForgeBuild))

    try {
        $release = Get-WinForgeLatestRelease
    }
    catch {
        $friendly = ConvertTo-WinForgeWebErrorText -Exception $_.Exception

        return [PSCustomObject]@{
            Status  = "Unreachable"
            Current = $current
            Release = $null
            Error   = $(if ($friendly) { $friendly } else { $_.Exception.Message })
            Known   = [bool]$friendly
        }
    }

    $status = "UpToDate"

    if ($release.Version -gt $current) {
        $status = "UpdateAvailable"
    }
    elseif ($release.Version -lt $current) {
        $status = "Ahead"
    }

    return [PSCustomObject]@{
        Status  = $status
        Current = $current
        Release = $release
        Error   = ""
        Known   = $true
    }
}


function Save-WinForgeUpdateCheck {
    <#
    Guarda a última versão publicada que uma consulta ao GitHub leu (Verificar nova versão ou o monitor), com a hora: o
    resumo de Sobre o WinForge e o monitor dizem dela sem consultar de novo. Uma consulta que não chegou ao GitHub não
    apaga o que já se sabia.
    #>
    param ([Parameter(Mandatory)]$Check)

    $release = Get-WinForgeJsonValue -Object $Check -Name "Release" -Default $null
    $version = $(if ($null -ne $release) { Get-WinForgeJsonValue -Object $release -Name "Version" -Default $null } else { $null })

    if ($version -isnot [version]) { return }

    [void](Set-WinForgeSetting -Name "UpdateLatest" -Value (Format-WinForgeVersion -Version $version))
    [void](Set-WinForgeSetting -Name "UpdateCheckedAt" -Value ((Get-Date).ToString("o", [System.Globalization.CultureInfo]::InvariantCulture)))
}


function Get-WinForgeKnownUpdate {
    <#
    O que o WinForge sabe da última versão publicada, sem consultar a internet (Save-WinForgeUpdateCheck): Latest (o
    número), Newer (mais nova que esta), Current (esta é a última), CheckedAt e Fresh (a consulta tem até 30 dias: depois
    disso, "a mais recente" já não se pode dizer). $null sem nenhuma consulta guardada, ou com uma que não se entende. A
    comparação é com a versão aberta agora: depois de atualizar, a versão guardada deixa de ser nova sozinha.
    #>
    param ([datetime]$Now = (Get-Date))

    $latest = ConvertTo-WinForgeVersion -Text ([string](Get-WinForgeSetting -Name "UpdateLatest" -Default ""))
    $current = ConvertTo-WinForgeVersion -Text ([string](Get-WinForgeBuild))

    if ($null -eq $latest -or $null -eq $current) { return $null }

    $checkedAt = Get-WinForgeSettingDate -Name "UpdateCheckedAt"

    # Uma data no futuro (o relógio estava adiantado) não vale como consulta recente.
    $fresh = ($null -ne $checkedAt -and $checkedAt -le $Now.AddDays(1) -and ($Now - $checkedAt).TotalDays -le 30)

    return [PSCustomObject]@{
        Latest    = (Format-WinForgeVersion -Version $latest)
        Newer     = ($latest -gt $current)
        Current   = ($latest -eq $current)
        CheckedAt = $checkedAt
        Fresh     = $fresh
    }
}


# ---------------------------------------------------------------------------
# Integridade
# ---------------------------------------------------------------------------

function Get-WinForgeFileSha256 {
    param (
        [Parameter(Mandatory)]
        [string]$Path
    )

    return ([string](Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash).ToLowerInvariant()
}


function Get-WinForgeExpectedHash {
    <#
    O SHA-256 que o arquivo deve ter: o "digest" que o GitHub publica para cada arquivo de um release (sha256:...).
    Devolve "" quando o release não traz nenhum (quem chama não baixa). Um digest estragado lança erro: é um hash
    publicado que não pôde ser lido, e não "sem hash".
    #>
    param (
        [Parameter(Mandatory)]
        $Release
    )

    $asset = Get-WinForgeJsonValue -Object $Release -Name "Asset"
    if ($null -eq $asset) { return "" }

    $digest = [string](Get-WinForgeJsonValue -Object $asset -Name "Digest" -Default "")
    if (-not $digest) { return "" }

    if ($digest -notmatch "(?i)^sha256:") {
        throw (Get-WinForgeText 'O GitHub publicou um hash que não é SHA-256 para o WinForge.zip.')
    }

    $hash = $digest.Substring(7).Trim()

    if ($hash -notmatch '^[0-9a-fA-F]{64}$') {
        throw (Get-WinForgeText 'O hash publicado pelo GitHub para o WinForge.zip não é um SHA-256 reconhecível.')
    }

    return $hash.ToLowerInvariant()
}


function Save-WinForgeRelease {
    <#
    Baixa o WinForge.zip do release para a pasta de destino com um nome que o WinForge escolhe (WinForge-<versão>.zip)
    e confere tamanho e SHA-256. Integrity: Verified (hash igual; Reused quando o arquivo já estava lá, conferido),
    Mismatch (o download é apagado), NoHash (o release não publica hash; nada é baixado) ou Failed (Error leva o
    motivo). O download parcial (.download) nunca fica na pasta, nem quando a ação é interrompida.
    #>
    param (
        [Parameter(Mandatory)]
        $Release,

        [Parameter(Mandatory)]
        [string]$DestinationFolder
    )

    $asset = Get-WinForgeJsonValue -Object $Release -Name "Asset"

    $result = [PSCustomObject]@{
        Integrity = "Failed"
        Path      = ""
        Hash      = ""
        Expected  = ""
        Reused    = $false
        Error     = ""
    }

    if ($null -eq $asset -or -not (Test-WinForgeReleaseDownloadUrl -Url ([string](Get-WinForgeJsonValue -Object $asset -Name "Url" -Default "")))) {
        $result.Error = (Get-WinForgeText 'o release não tem um WinForge.zip num endereço confiável do repositório')
        return $result
    }

    try {
        $result.Expected = Get-WinForgeExpectedHash -Release $Release
    }
    catch {
        $result.Error = $_.Exception.Message
        return $result
    }

    if (-not $result.Expected) {
        $result.Integrity = "NoHash"
        return $result
    }

    $finalPath = Join-Path $DestinationFolder ("WinForge-{0}.zip" -f (Format-WinForgeVersion -Version $Release.Version))
    $partialPath = "$finalPath.download"

    # A mesma versão já baixada e conferida não é baixada de novo.
    if (Test-Path -LiteralPath $finalPath -PathType Leaf) {
        try {
            if ((Get-WinForgeFileSha256 -Path $finalPath) -eq $result.Expected) {
                $result.Hash = $result.Expected
                $result.Path = $finalPath
                $result.Reused = $true
                $result.Integrity = "Verified"
                return $result
            }
        }
        catch {
            # Não deu para ler o arquivo antigo: baixa de novo.
        }
    }

    try {
        if (-not (Test-Path -LiteralPath $DestinationFolder -PathType Container)) {
            [void](New-Item -ItemType Directory -Path $DestinationFolder -Force)
        }

        Enable-WinForgeTls12

        $previous = $ProgressPreference
        $ProgressPreference = "SilentlyContinue"

        try {
            Invoke-WebRequest -Uri ([string]$asset.Url) -OutFile $partialPath -UseBasicParsing -TimeoutSec 120 -ErrorAction Stop
        }
        finally {
            $ProgressPreference = $previous
        }

        if (-not (Test-Path -LiteralPath $partialPath -PathType Leaf)) {
            throw (Get-WinForgeText 'o download terminou sem gravar o arquivo')
        }

        $size = (Get-Item -LiteralPath $partialPath).Length

        if ($size -le 0) {
            throw (Get-WinForgeText 'o arquivo baixado está vazio')
        }

        if ([int64]$asset.Size -gt 0 -and $size -ne [int64]$asset.Size) {
            throw (Get-WinForgeText 'o arquivo chegou incompleto ({0} de {1} bytes); tente de novo' "$size" "$($asset.Size)")
        }

        $result.Hash = Get-WinForgeFileSha256 -Path $partialPath

        if ($result.Hash -ne $result.Expected) {
            $result.Integrity = "Mismatch"
            return $result
        }

        # Um arquivo antigo de mesmo nome, com outro conteúdo e em uso (aberto num programa de zip, sendo lido pelo
        # antivírus), não derruba o download conferido: ele fica com outro nome.
        $target = $finalPath
        $moved = $false

        for ($attempt = 1; $attempt -le 9 -and -not $moved; $attempt++) {
            try {
                Move-Item -LiteralPath $partialPath -Destination $target -Force -ErrorAction Stop
                $moved = $true
            }
            catch {
                $target = Join-Path $DestinationFolder ("WinForge-{0} ({1}).zip" -f (Format-WinForgeVersion -Version $Release.Version), ($attempt + 1))
            }
        }

        if (-not $moved) {
            throw (Get-WinForgeText 'o arquivo {0} já existe na pasta Downloads e está em uso; feche o programa que o abriu e tente de novo' "$(Split-Path -Leaf $finalPath)")
        }

        $result.Path = $target
        $result.Integrity = "Verified"
    }
    catch {
        $friendly = ConvertTo-WinForgeWebErrorText -Exception $_.Exception
        $result.Integrity = "Failed"
        $result.Error = $(if ($friendly) { $friendly } else { $_.Exception.Message })
    }
    finally {
        # Também quando a ação é interrompida (Parar), em que o catch não roda.
        Remove-Item -LiteralPath $partialPath -Force -ErrorAction SilentlyContinue
    }

    return $result
}


function Get-WinForgeReleasePackageInfo {
    <#
    Confere que o zip é um pacote do WinForge e lê dele: Root (a pasta de dentro do zip que tem os arquivos, "WinForge"
    no pacote publicado, ou "" quando os arquivos estão na raiz) e Build (a versão escrita no Core.psm1 do pacote, ou "").
    $null quando o zip não abre ou não tem o WinForge.Gui.ps1.
    #>
    param (
        [Parameter(Mandatory)]
        [string]$Path
    )

    $zip = $null

    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
        $zip = [System.IO.Compression.ZipFile]::OpenRead($Path)

        $root = $null

        foreach ($entry in $zip.Entries) {
            $name = ([string]$entry.FullName).Replace("\", "/")

            if ($name -ieq "WinForge.Gui.ps1") { $root = ""; break }
            if ($name -match '^([^/]+)/WinForge\.Gui\.ps1$') { $root = $Matches[1]; break }
        }

        if ($null -eq $root) { return $null }

        $build = ""
        $corePath = $(if ($root) { "$root/modules/Core.psm1" } else { "modules/Core.psm1" })
        $core = @($zip.Entries | Where-Object { ([string]$_.FullName).Replace("\", "/") -ieq $corePath })[0]

        if ($null -ne $core) {
            $reader = New-Object System.IO.StreamReader ($core.Open())

            try {
                $match = [regex]::Match($reader.ReadToEnd(), '\$script:WinForgeBuild\s*=\s*"([0-9.]+)"')
                if ($match.Success) { $build = $match.Groups[1].Value }
            }
            finally {
                $reader.Dispose()
            }
        }

        return [PSCustomObject]@{ Root = $root; Build = $build }
    }
    catch {
        return $null
    }
    finally {
        if ($null -ne $zip) { $zip.Dispose() }
    }
}


# ---------------------------------------------------------------------------
# Tela
# ---------------------------------------------------------------------------

function Format-WinForgeReleaseNotes {
    <#
    As primeiras linhas úteis das notas do release, sem Markdown nem HTML, para caber na tela: um link vira o texto
    dele, tabelas, blocos de código, comentários e marcações HTML somem. Truncated diz se havia mais linhas.
    #>
    param (
        [string]$Notes,
        [int]$MaxLines = 8
    )

    $lines = @()
    $truncated = $false

    if (-not [string]::IsNullOrWhiteSpace($Notes)) {
        $text = [regex]::Replace($Notes, '(?s)<!--.*?-->', '')
        $inCode = $false

        foreach ($line in ($text -split "\r?\n")) {
            if ($line -match '^\s*(```|~~~)') { $inCode = -not $inCode; continue }
            if ($inCode -or $line -match '^\s*\|') { continue }

            $clean = $line -replace '!?\[([^\]]*)\]\([^)]*\)', '$1'
            $clean = $clean -replace '<[^>]+>', ''
            # Os marcadores de ênfase (**negrito**, _itálico_) saem; o "_" dentro de uma palavra (tweak_backup.json) fica.
            $clean = $clean -replace '^\s*[#>*+\-]+\s*', '' -replace '`', ''
            $clean = ($clean -replace '(?<![\p{L}0-9])[*_]{1,3}|[*_]{1,3}(?![\p{L}0-9])', '').Trim()

            if (-not $clean) { continue }

            if ($lines.Count -ge $MaxLines) {
                $truncated = $true
                break
            }

            $lines += $clean
        }
    }

    return [PSCustomObject]@{ Lines = @($lines); Truncated = $truncated }
}


function Show-WinForgeDownloadedRelease {
    # Onde o arquivo ficou, como instalar (com a pasta de dentro do zip) e a oferta de mostrar o arquivo na pasta. O
    # Explorador abre a pasta na sessão da pessoa, sem o Administrador da janela.
    param (
        [Parameter(Mandatory)]$Saved,
        $Package
    )

    Write-WinForgeKeyValue -Label (Get-WinForgeText 'Arquivo') -Value $Saved.Path
    Write-Host ""

    $appRoot = Get-WinForgeAppRoot
    $what = $(if ($null -ne $Package -and $Package.Root) { (Get-WinForgeText 'entre na pasta {0} dentro do zip e copie tudo o que está nela' "$($Package.Root)") } else { (Get-WinForgeText 'copie tudo o que está no zip') })
    Write-WinForgeStatus -Type Info -Notice -Message (Get-WinForgeText 'Para instalar à mão: feche o WinForge, abra o zip, {0} para {1}, substituindo os arquivos, e abra o WinForge de novo.' "$what" "$appRoot")
    Write-Host ""

    if (Confirm-WinForgeAction -Message (Get-WinForgeText 'Mostrar o arquivo na pasta Downloads?') -DefaultKey S -YesLabel (Get-WinForgeText 'Mostrar') -NoLabel (Get-WinForgeText 'Agora não')) {
        try {
            Start-Process -FilePath "explorer.exe" -ArgumentList "/select,`"$($Saved.Path)`"" -ErrorAction Stop
        }
        catch {
            Write-WinForgeStatus -Type Warning -Notice -Message (Get-WinForgeText 'Não foi possível abrir a pasta: {0}' "$($_.Exception.Message)")
        }
    }
}


function Invoke-WinForgeSelfUpdate {
    <#
    Oferece instalar agora a versão baixada e conferida. Started: a troca começou (o instalador da versão nova espera o
    WinForge fechar) e Result é o resultado da ação; Reason: não deu para começar (a instalação à mão continua valendo);
    os dois vazios: a pessoa preferiu instalar depois.
    #>
    param (
        [Parameter(Mandatory)]$Saved,
        [Parameter(Mandatory)]$Package,
        [Parameter(Mandatory)][string]$Published,
        [Parameter(Mandatory)][string]$Title
    )

    $answer = [PSCustomObject]@{ Started = $false; Result = $null; Reason = "" }

    Write-Host ""

    # Com outra janela ou outro menu desta pasta aberto, o instalador recusaria a troca só depois de fechar este: o que
    # fechar fica dito agora, sem o fecha e abre à toa.
    $others = @()
    try { $others = @(Get-WinForgeRunningCopies -Root (Get-WinForgeAppRoot) | Where-Object { $_.Kind -ne "Agent" }) } catch { $others = @() }

    if ($others.Count -gt 0) {
        $answer.Reason = (Get-WinForgeText 'outra janela do WinForge continua aberta')
        Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'Outra janela ou outro menu do WinForge está aberto. Feche-o e verifique de novo para instalar com um clique.')
        return $answer
    }

    if (-not (Confirm-WinForgeAction -Message (Get-WinForgeText 'Instalar a versão {0} agora? O WinForge fecha, troca os arquivos e abre de novo em alguns segundos.' "$Published") -DefaultKey S -YesLabel (Get-WinForgeText 'Instalar agora') -NoLabel (Get-WinForgeText 'Depois'))) {
        return $answer
    }

    Write-WinForgeStatus -Type Running -Notice -Message (Get-WinForgeText 'Preparando a instalação...')

    try {
        [void](Start-WinForgeUpdateInstall -ZipPath $Saved.Path -PackageRoot ([string]$Package.Root) -Reopen $(if (Test-WinForgeGuiMode) { "Gui" } else { "Console" }))
    }
    catch {
        $answer.Reason = ([string]$_.Exception.Message).TrimEnd('.')
        Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'Não foi possível instalar sozinho: {0}. A instalação à mão continua valendo.' "$($answer.Reason)")
        return $answer
    }

    Request-WinForgeAppExit -Reason "update"
    Write-WinForgeStatus -Type Success -Message (Get-WinForgeText 'O WinForge vai fechar e abrir de novo na versão {0}.' "$Published")

    $answer.Started = $true
    $answer.Result = Set-WinForgeResultView -Result (New-WinForgeResult -Kind Ok -Detail (Get-WinForgeText 'instalando a versão {0}; o WinForge fecha e abre de novo' "$Published") -Title $Title) `
        -Headline (Get-WinForgeText 'Instalando a versão {0}' "$Published") -Note (Get-WinForgeText 'O WinForge fecha agora e abre de novo na versão nova, em alguns segundos.')

    return $answer
}


function Invoke-WinForgeUpdateFlow {
    # O roteiro de Verificar nova versão. Devolve o resultado; quem chama abre e fecha a ação uma vez só.
    param ([Parameter(Mandatory)][string]$Title)

    Write-Host (Get-WinForgeText '  Consulta o GitHub para ver a última versão publicada.') -ForegroundColor DarkGray
    Write-Host ""

    $check = Get-WinForgeUpdateStatus
    Save-WinForgeUpdateCheck -Check $check
    $installed = $(if ($null -ne $check.Current) { "$(Format-WinForgeVersion -Version $check.Current)" } else { "$(Get-WinForgeBuild)" })

    Write-WinForgeSection -Title (Get-WinForgeText 'Versões')
    Write-WinForgeKeyValue -Label (Get-WinForgeText 'Instalada') -Value $installed

    if ($check.Status -eq "Unreachable") {
        # A faixa: o que não deu no título; o motivo conhecido (sem internet, limite do GitHub...) na frase.
        $unreachable = (Get-WinForgeText 'Não foi possível consultar o GitHub')

        if ($check.Known) {
            Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'Não foi possível consultar o GitHub agora: {0}.' "$($check.Error)")
            return (Set-WinForgeResultView -Result (New-WinForgeResult -Kind Warning -Detail $check.Error -Title $Title) -Headline $unreachable -Note (Format-WinForgeReasonNote -Text $check.Error))
        }

        Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'Não foi possível consultar o GitHub agora; tente de novo mais tarde.')
        Write-WinForgeStatus -Type Info -Notice -Message (Get-WinForgeText 'Detalhe: {0}' "$($check.Error)")
        return (Set-WinForgeResultView -Result (New-WinForgeResult -Kind Warning -Detail (Get-WinForgeText 'não foi possível consultar o GitHub agora; tente de novo mais tarde') -Title $Title) `
                -Headline $unreachable -Note (Get-WinForgeText 'Tente de novo mais tarde.'))
    }

    $release = $check.Release
    # O número da versão; as frases dizem "a versão {0}" (no inglês, "version {0}").
    $published = "$(Format-WinForgeVersion -Version $release.Version)"

    Write-WinForgeKeyValue -Label (Get-WinForgeText 'Última publicada') -Value $published

    if ($release.Published -is [datetime]) {
        Write-WinForgeKeyValue -Label (Get-WinForgeText 'Publicada em') -Value (Format-WinForgeDateTime -When $release.Published -Pattern "dd/MM/yyyy")
    }

    Write-Host ""

    if ($check.Status -eq "UpToDate") {
        Write-WinForgeStatus -Type Success -Message (Get-WinForgeText 'Você já está na versão mais recente.')
        return (Set-WinForgeResultView -Result (New-WinForgeResult -Kind Ok -Detail (Get-WinForgeText 'versão {0} em dia' "$published") -Title $Title) `
                -Headline (Get-WinForgeText 'Você está na versão mais recente') -Note (Get-WinForgeText 'A versão {0} é a última publicada no GitHub.' "$published"))
    }

    if ($check.Status -eq "Ahead") {
        Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'A versão instalada é mais nova que a última publicada; não há o que atualizar.')
        return (Set-WinForgeResultView -Result (New-WinForgeResult -Kind Ok -Detail (Get-WinForgeText 'esta cópia é mais nova que a última publicada ({0})' "$published") -Title $Title) `
                -Headline (Get-WinForgeText 'Esta cópia é mais nova que a publicada') -Note (Get-WinForgeText 'A última publicada é a versão {0}; não há o que atualizar.' "$published"))
    }

    Write-WinForgeStatus -Type Warning -Notice -Message (Get-WinForgeText 'Há uma versão mais nova: {0}.' "$published")

    # Sem o endereço da página na resposta do GitHub, a lista de releases do projeto é o caminho seguro.
    $pageUrl = $(if ([string]::IsNullOrWhiteSpace($release.PageUrl)) { "https://github.com/$(Get-WinForgeRepository)/releases" } else { [string]$release.PageUrl })
    $notes = Format-WinForgeReleaseNotes -Notes $release.Notes

    if ($notes.Lines.Count -gt 0) {
        Write-WinForgeSection -Title (Get-WinForgeText 'O que mudou')

        foreach ($note in $notes.Lines) {
            Write-WinForgeStatus -Type Info -Notice -Message $note
        }

        if ($notes.Truncated) { Write-WinForgeStatus -Type Info -Notice -Message (Get-WinForgeText 'Notas completas: {0}' "$pageUrl") }
    }

    # Os títulos da faixa: a versão nova que existe, ou a que não foi baixada.
    $available = (Get-WinForgeText 'Versão {0} disponível' "$published")
    $notDownloaded = (Get-WinForgeText 'A versão {0} não foi baixada' "$published")

    if ($null -eq $release.Asset) {
        $why = (Get-WinForgeText 'Esse release não tem o WinForge.zip anexado; baixe pela página do projeto: {0}' "$pageUrl")
        Write-WinForgeStatus -Type Warning -Message $why
        return (Set-WinForgeResultView -Result (New-WinForgeResult -Kind Warning -Detail (Get-WinForgeText 'a versão {0} está publicada, mas sem o WinForge.zip' "$published") -Title $Title) -Headline $available -Note $why)
    }

    Write-WinForgeSection -Title (Get-WinForgeText 'Download')

    # Elevado com a conta de outro Administrador, a pasta Downloads seria a dessa conta, fora do alcance de quem usa o
    # PC. Sem elevação (o aviso do Windows recusado), o download vai para a pasta certa.
    if (Test-WinForgeUserContextMismatch) {
        $why = (Get-WinForgeText 'O WinForge está aberto com a conta de outro Administrador: o arquivo iria para a pasta Downloads dessa conta. Para baixar, {0}, ou baixe pela página do projeto: {1}' "$(Get-WinForgeUnelevatedHint)" "$pageUrl")
        Write-WinForgeStatus -Type Warning -Message $why
        return (Set-WinForgeResultView -Result (New-WinForgeResult -Kind Warning -Detail (Get-WinForgeText 'a versão {0} está disponível; com a conta de outro Administrador, o download não foi feito' "$published") -Title $Title) -Headline $available -Note $why)
    }

    if (-not (Confirm-WinForgeAction -Message (Get-WinForgeText 'Baixar o WinForge.zip da versão {0} para a pasta Downloads?' "$published") -DefaultKey S -YesLabel (Get-WinForgeText 'Baixar') -NoLabel (Get-WinForgeText 'Agora não'))) {
        Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Nada foi baixado.')
        return (Set-WinForgeResultView -Result (New-WinForgeResult -Kind Skipped -Detail (Get-WinForgeText 'a versão {0} está disponível, mas o download foi recusado' "$published") -Title $Title) `
                -Headline $available -Note (Get-WinForgeText 'Nada foi baixado.'))
    }

    Write-WinForgeStatus -Type Running -Notice -Message (Get-WinForgeText 'Baixando e conferindo o arquivo...')
    $saved = Save-WinForgeRelease -Release $release -DestinationFolder (Get-WinForgeDownloadsPath)

    if ($saved.Integrity -eq "NoHash") {
        $why = (Get-WinForgeText 'Esta versão não publica um SHA-256 para conferir o arquivo, então o WinForge não a baixou. Baixe pela página do projeto: {0}' "$pageUrl")
        Write-WinForgeStatus -Type Error -Message $why
        return (Set-WinForgeResultView -Result (New-WinForgeResult -Kind Failed -Detail (Get-WinForgeText 'a versão {0} não publica um hash para conferir; nada foi baixado' "$published") -Title $Title) -Headline $notDownloaded -Note $why)
    }

    if ($saved.Integrity -eq "Mismatch") {
        $why = (Get-WinForgeText 'O arquivo baixado chegou diferente do publicado (corrompido no caminho ou alterado) e foi apagado. Tente de novo; se repetir, baixe pela página do projeto: {0}' "$pageUrl")
        Write-WinForgeStatus -Type Error -Message $why
        return (Set-WinForgeResultView -Result (New-WinForgeResult -Kind Failed -Detail (Get-WinForgeText 'o arquivo baixado não confere com o publicado e foi apagado') -Title $Title) -Headline $notDownloaded -Note $why)
    }

    if ($saved.Integrity -ne "Verified") {
        Write-WinForgeStatus -Type Error -Message (Get-WinForgeText 'Não foi possível baixar: {0}.' "$($saved.Error)")
        return (Set-WinForgeResultView -Result (New-WinForgeResult -Kind Failed -Detail $saved.Error -Title $Title) -Headline $notDownloaded -Note (Format-WinForgeReasonNote -Text $saved.Error))
    }

    $package = Get-WinForgeReleasePackageInfo -Path $saved.Path

    if ($null -eq $package) {
        # O arquivo é o publicado (o hash confere), mas não é um pacote do WinForge: erro do release.
        Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'O arquivo baixado confere com o publicado, mas não é um pacote do WinForge; baixe pela página do projeto: {0}' "$pageUrl")
        Write-WinForgeKeyValue -Label (Get-WinForgeText 'Arquivo') -Value $saved.Path
        return (Set-WinForgeResultView -Result (New-WinForgeResult -Kind Warning -Detail (Get-WinForgeText 'a versão {0} foi baixada, mas o arquivo não é um pacote do WinForge' "$published") -Title $Title) `
                -Headline (Get-WinForgeText 'O arquivo baixado não é um pacote do WinForge') -Note (Get-WinForgeText 'Ele é idêntico ao publicado, então o problema está no release. Baixe pela página do projeto: {0}' "$pageUrl"))
    }

    $how = $(if ($saved.Reused) { (Get-WinForgeText 'já estava na pasta Downloads e foi conferido') } else { (Get-WinForgeText 'foi baixado e conferido') })
    Write-WinForgeStatus -Type Success -Message (Get-WinForgeText 'O WinForge.zip da versão {0} {1}: é idêntico ao publicado no GitHub (SHA-256).' "$published" "$($how)")

    # Atualizar com um clique: só um pacote que diz a mesma versão da página vira instalação.
    if (-not $package.Build -or $package.Build -eq (Format-WinForgeVersion -Version $release.Version)) {
        $installed = Invoke-WinForgeSelfUpdate -Saved $saved -Package $package -Published $published -Title $Title

        if ($installed.Started) { return $installed.Result }

        if ($installed.Reason) {
            Show-WinForgeDownloadedRelease -Saved $saved -Package $package
            return (Set-WinForgeResultView -Result (New-WinForgeResult -Kind Warning -Detail (Get-WinForgeText 'a versão {0} foi baixada e conferida, mas não foi instalada sozinha: {1}' "$published" "$($installed.Reason)") -Title $Title) `
                    -Headline (Get-WinForgeText 'Versão {0} baixada, mas não instalada' "$published") -Note (Get-WinForgeText 'Não foi possível instalar sozinho: {0}. A instalação à mão continua valendo.' "$($installed.Reason)"))
        }
    }

    # A faixa da janela: a versão no título e, na frase, o passo que falta (a pessoa preferiu instalar depois).
    $from = $(if ($package.Root) { (Get-WinForgeText 'o que está na pasta {0} do zip' "$($package.Root)") } else { (Get-WinForgeText 'o que está no zip') })
    $result = Set-WinForgeResultView -Result (New-WinForgeResult -Kind Ok -Detail (Get-WinForgeText 'versão {0} baixada e conferida; falta instalar' "$published") -Title $Title) `
        -Headline $(if ($saved.Reused) { (Get-WinForgeText 'Versão {0} já baixada e conferida' "$published") } else { (Get-WinForgeText 'Versão {0} baixada e conferida' "$published") }) `
        -Note (Get-WinForgeText 'Para instalar, feche o WinForge e copie {0} para {1}, substituindo os arquivos.' "$from" "$(Get-WinForgeAppRoot)")

    if ($package.Build -and $package.Build -ne (Format-WinForgeVersion -Version $release.Version)) {
        $why = (Get-WinForgeText 'O pacote é da versão {0}, diferente da {1} anunciada na página.' "$($package.Build)" "$published")
        Write-WinForgeStatus -Type Warning -Message $why
        $result = Set-WinForgeResultView -Result (New-WinForgeResult -Kind Warning -Detail (Get-WinForgeText 'a versão {0} foi baixada, mas o pacote é da {1}' "$published" "$($package.Build)") -Title $Title) `
            -Headline (Get-WinForgeText 'O pacote baixado não é da versão anunciada') -Note $why
    }

    Show-WinForgeDownloadedRelease -Saved $saved -Package $package

    return $result
}


function Invoke-WinForgeUpdateCheck {
    $title = (Get-WinForgeText 'Verificar nova versão')

    Enter-WinForgeAction -Title $title

    try {
        $final = Invoke-WinForgeUpdateFlow -Title $title
    }
    catch {
        Write-WinForgeStatus -Type Error -Message (Get-WinForgeText 'Não foi possível verificar a versão: {0}' "$($_.Exception.Message)")
        $final = Set-WinForgeResultView -Result (New-WinForgeResult -Kind Failed -Detail $_.Exception.Message -Title $title) `
            -Headline (Get-WinForgeText 'Não foi possível verificar a versão') -Note (Format-WinForgeReasonNote -Text $_.Exception.Message)
    }

    Exit-WinForgeAction -Result $final
}


Export-ModuleMember -Function *
