# Dados que mudam mais rápido que o WinForge: a lista de programas essenciais e as datas de fim de suporte do Windows.
#
# O WinForge traz uma cópia embutida desses dados e, quando pode, baixa a versão publicada no repositório do projeto
# (catalog/catalog.json). A cópia online só vale se passar na conferência (formato, versão, IDs e datas bem formados) e
# for mais nova que a embutida; senão, fica a embutida. Nada aqui manda dados do PC para fora: é um download só.


# ---------------------------------------------------------------------------
# Cópia embutida
# ---------------------------------------------------------------------------

function Get-WinForgeBuiltInCatalog {
    # Updated: a data destes dados. A cópia online só substitui a embutida quando é mais nova.
    # Fora da lista: programas cujo instalador recusa rodar como Administrador (o Spotify, por exemplo), porque a janela
    # do WinForge sempre roda assim e a instalação falharia sempre. A tela mostra as categorias na ordem de
    # Get-WinForgeEssentialCategoryRank (Software.psm1): "Para programadores" fica por último.
    $essentials = @(
        @("Básico", "7-Zip", "7zip.7zip", "Abre e cria arquivos compactados (.zip, .7z, .rar)"),
        @("Básico", "Adobe Acrobat Reader", "Adobe.Acrobat.Reader.64-bit", "Abre e assina PDFs"),
        @("Básico", "Google Chrome", "Google.Chrome", "Navegador do Google"),
        @("Básico", "Mozilla Firefox", "Mozilla.Firefox", "Navegador da Mozilla"),
        @("Básico", "Notepad++", "Notepad++.Notepad++", "Editor de texto e de código"),
        @("Básico", "VLC Media Player", "VideoLAN.VLC", "Toca quase todo formato de vídeo e áudio"),
        @("Comunicação e mídia", "Discord", "Discord.Discord", "Conversa por voz, vídeo e texto"),
        @("Comunicação e mídia", "Zoom", "Zoom.Zoom", "Reuniões e aulas por vídeo"),
        @("Produtividade", "Everything", "voidtools.Everything", "Acha qualquer arquivo do PC pelo nome, na hora"),
        @("Produtividade", "LibreOffice", "TheDocumentFoundation.LibreOffice", "Textos, planilhas e apresentações, grátis"),
        @("Produtividade", "Microsoft PowerToys", "Microsoft.PowerToys", "Utilitários extras da Microsoft para o Windows"),
        @("Jogos", "Steam", "Valve.Steam", "Loja e biblioteca de jogos"),
        @("Para programadores", "Git", "Git.Git", "Controle de versões de código"),
        @("Para programadores", "Java JDK 25 (Temurin, LTS)", "EclipseAdoptium.Temurin.25.JDK", "Java mais recente com suporte longo"),
        @("Para programadores", "Java JDK 21 (Temurin, LTS)", "EclipseAdoptium.Temurin.21.JDK", "Java anterior com suporte longo, para projetos que pedem a 21"),
        @("Para programadores", "Node.js LTS", "OpenJS.NodeJS.LTS", "JavaScript fora do navegador, na versão com suporte longo"),
        @("Para programadores", "PowerShell 7", "Microsoft.PowerShell", "O PowerShell atual, instalado ao lado do Windows PowerShell"),
        @("Para programadores", "Python 3.15", "Python.Python.3.15", "Linguagem Python"),
        @("Para programadores", "Visual Studio Code", "Microsoft.VisualStudioCode", "Editor de código da Microsoft")
    )

    # Datas da página "Windows 11 release information" e do ciclo de vida do Windows 10 (Microsoft). HomeEnd vale para
    # Home e Pro; EnterpriseEnd, para Enterprise e Education; LtscEnd, para as edições LTSC/LTSB; EsuEnd, para o programa
    # de Atualizações de Segurança Estendidas do consumidor. IotLtscEnd é o prazo das edições IoT Enterprise LTSC quando
    # ele é diferente do LTSC comum (vazio = o mesmo de LtscEnd). EsuFirstRevision é a revisão da build (o "6575" de
    # 19045.6575) da primeira atualização que só chega a quem está no ESU: com ela instalada, o PC está no programa
    # (0 = não se aplica). EsuOrgEnd é o último dia do ESU que empresas e escolas contratam (Enterprise e Education;
    # vazio = não há). UpdateRevision é a revisão da atualização de segurança mensal de um mês antes de Updated (a de
    # outubro de 2026 nesta lista), e UpdateDate, o dia em que ela saiu: um PC sem ela, 35 dias depois, está atrasado
    # (Get-WinForgeWindowsUpdateLag). 0 e vazio = a versão não recebe mais atualizações mensais. Quando o mês anterior é
    # de hotpatch (atualização sem reinício do Windows 11 Enterprise), vale a revisão do hotpatch, que é menor: senão os
    # PCs que o recebem contariam como atrasados.
    $lifecycle = @(
        @(14393, "Windows 10 1607", "2018-04-10", "2019-04-09", "2026-10-13", "", "", 0, "", 9612, "2026-10-13"),
        @(17763, "Windows 10 1809", "2020-11-10", "2021-05-11", "2029-01-09", "", "", 0, "", 9376, "2026-10-13"),
        @(19044, "Windows 10 21H2", "2023-06-13", "2024-06-11", "2027-01-12", "", "2032-01-13", 0, "", 7807, "2026-10-13"),
        @(19045, "Windows 10 22H2", "2025-10-14", "2025-10-14", "", "2027-10-12", "", 6575, "2028-10-10", 7807, "2026-10-13"),
        @(22000, "Windows 11 21H2", "2023-10-10", "2024-10-08", "", "", "", 0, "", 0, ""),
        @(22621, "Windows 11 22H2", "2024-10-08", "2025-10-14", "", "", "", 0, "", 0, ""),
        @(22631, "Windows 11 23H2", "2025-11-11", "2026-11-10", "", "", "", 0, "", 7652, "2026-10-13"),
        @(26100, "Windows 11 24H2", "2026-10-13", "2027-10-12", "2029-10-09", "", "2034-10-10", 0, "", 9711, "2026-10-13"),
        @(26200, "Windows 11 25H2", "2027-10-12", "2028-10-10", "", "", "", 0, "", 9711, "2026-10-13"),
        @(26300, "Windows 11 26H2", "2028-10-10", "2029-10-09", "", "", "", 0, "", 9711, "2026-10-13"),
        @(28000, "Windows 11 26H1", "2028-03-14", "2029-03-13", "", "", "", 0, "", 3231, "2026-10-13")
    )

    # Objetos (e não hashtables), no mesmo formato que o JSON baixado vira: a conferência é uma só para os dois.
    return [PSCustomObject]@{
        Format           = "WinForge.Catalog"
        Version          = 1
        Updated          = "2026-11-15"
        Essentials       = @($essentials | ForEach-Object { [PSCustomObject]@{ Categoria = $_[0]; Nome = $_[1]; Id = $_[2]; Descricao = $_[3] } })
        WindowsLifecycle = @($lifecycle | ForEach-Object { [PSCustomObject]@{ Build = $_[0]; Name = $_[1]; HomeEnd = $_[2]; EnterpriseEnd = $_[3]; LtscEnd = $_[4]; EsuEnd = $_[5]; IotLtscEnd = $_[6]; EsuFirstRevision = $_[7]; EsuOrgEnd = $_[8]; UpdateRevision = $_[9]; UpdateDate = $_[10] } })
    }
}


# ---------------------------------------------------------------------------
# Conferência e leitura
# ---------------------------------------------------------------------------

function Get-WinForgeCatalogUrl {
    return "https://raw.githubusercontent.com/$(Get-WinForgeRepository)/main/catalog/catalog.json"
}


function Get-WinForgeCatalogCachePath {
    return (Join-Path (Get-WinForgeDataPath) "catalog.json")
}


function Test-WinForgeCatalogDate {
    <#
    "2026-10-30" (ou vazio, quando -AllowEmpty). Outra forma de data seria lida de jeitos diferentes conforme o idioma. As
    datas de suporte ficam entre 2015 (o Windows 10) e 2045: "1900-01-01" ou "9999-12-31" num catálogo publicado por
    engano marcariam todo Windows como sem suporte (ou com suporte para sempre).
    #>
    param (
        [AllowEmptyString()][string]$Text,
        [switch]$AllowEmpty
    )

    if ([string]::IsNullOrEmpty($Text)) { return [bool]$AllowEmpty }
    if ($Text -notmatch '^[0-9]{4}-[0-9]{2}-[0-9]{2}$') { return $false }

    $parsed = [datetime]::MinValue

    if (-not [datetime]::TryParseExact($Text, "yyyy-MM-dd", [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$parsed)) { return $false }

    return ($parsed.Year -ge 2015 -and $parsed.Year -le 2045)
}


function ConvertFrom-WinForgeCatalogDocument {
    <#
    Confere e normaliza um catálogo (o embutido ou o baixado). Devolve $null quando qualquer parte está fora do formato:
    um catálogo pela metade nunca substitui o embutido. Os IDs do winget só podem ter letras, números e . + _ -, e os
    textos não podem ser vazios nem longos demais.
    #>
    param (
        $Document,

        # Um catálogo baixado (ou a cópia dele): a data de publicação não pode estar no futuro. O embutido não passa por
        # essa conta, que depende do relógio do PC: com o relógio atrasado, ele seria recusado e nada teria catálogo.
        [switch]$Downloaded
    )

    if ($null -eq $Document) { return $null }
    if ([string](Get-WinForgeJsonValue -Object $Document -Name "Format" -Default "") -ne "WinForge.Catalog") { return $null }
    if ([string](Get-WinForgeJsonValue -Object $Document -Name "Version" -Default "") -ne "1") { return $null }

    $updated = [string](Get-WinForgeJsonValue -Object $Document -Name "Updated" -Default "")
    if (-not (Test-WinForgeCatalogDate -Text $updated)) { return $null }

    # Uma data de publicação no futuro passaria na frente de todo catálogo embutido das próximas versões.
    if ($Downloaded -and [datetime]::ParseExact($updated, "yyyy-MM-dd", [System.Globalization.CultureInfo]::InvariantCulture) -gt (Get-Date).Date.AddDays(2)) { return $null }

    $essentials = @()

    foreach ($entry in @(Get-WinForgeJsonValue -Object $Document -Name "Essentials" -Default @())) {
        $item = [PSCustomObject]@{
            Categoria = [string](Get-WinForgeJsonValue -Object $entry -Name "Categoria" -Default "")
            Nome      = [string](Get-WinForgeJsonValue -Object $entry -Name "Nome" -Default "")
            Id        = [string](Get-WinForgeJsonValue -Object $entry -Name "Id" -Default "")
            Descricao = [string](Get-WinForgeJsonValue -Object $entry -Name "Descricao" -Default "")
        }

        # Caracteres de controle (quebra de linha, ESC) deixariam um texto baixado desenhar linhas falsas no console
        # ("[OK] Tudo certo") ou mexer na tela; nenhum nome ou descrição de verdade tem isso.
        foreach ($text in @($item.Categoria, $item.Nome, $item.Descricao)) {
            if ([string]::IsNullOrWhiteSpace($text) -or $text.Length -gt 120 -or $text -match '[\x00-\x1f\x7f]') { return $null }
        }

        if ($item.Id -notmatch '^[A-Za-z0-9][A-Za-z0-9.+_-]{1,99}$') { return $null }

        $essentials += $item
    }

    if ($essentials.Count -eq 0 -or @($essentials | Group-Object -Property Id | Where-Object { $_.Count -gt 1 }).Count -gt 0) { return $null }

    $lifecycle = @()

    foreach ($entry in @(Get-WinForgeJsonValue -Object $Document -Name "WindowsLifecycle" -Default @())) {
        $build = [string](Get-WinForgeJsonValue -Object $entry -Name "Build" -Default "")
        $name = [string](Get-WinForgeJsonValue -Object $entry -Name "Name" -Default "")

        if ($build -notmatch '^[0-9]{4,6}$' -or [string]::IsNullOrWhiteSpace($name) -or $name.Length -gt 60 -or $name -match '[\x00-\x1f\x7f]') { return $null }

        # IotLtscEnd, EsuFirstRevision e EsuOrgEnd vieram depois: um catálogo sem eles (o guardado por uma versão anterior) continua
        # válido, como "mesmo prazo do LTSC" e "não se sabe qual atualização é só do ESU".
        $esuFirst = [string](Get-WinForgeJsonValue -Object $entry -Name "EsuFirstRevision" -Default "")
        if ($esuFirst -notmatch '^[0-9]{0,6}$') { return $null }

        # UpdateRevision e UpdateDate vieram na 3.55; sem eles, não se confere o atraso das atualizações.
        $updateRevision = [string](Get-WinForgeJsonValue -Object $entry -Name "UpdateRevision" -Default "")
        if ($updateRevision -notmatch '^[0-9]{0,6}$') { return $null }

        $item = [PSCustomObject]@{
            Build            = [int]$build
            Name             = $name
            HomeEnd          = [string](Get-WinForgeJsonValue -Object $entry -Name "HomeEnd" -Default "")
            EnterpriseEnd    = [string](Get-WinForgeJsonValue -Object $entry -Name "EnterpriseEnd" -Default "")
            LtscEnd          = [string](Get-WinForgeJsonValue -Object $entry -Name "LtscEnd" -Default "")
            EsuEnd           = [string](Get-WinForgeJsonValue -Object $entry -Name "EsuEnd" -Default "")
            IotLtscEnd       = [string](Get-WinForgeJsonValue -Object $entry -Name "IotLtscEnd" -Default "")
            EsuFirstRevision = $(if ($esuFirst) { [int]$esuFirst } else { 0 })
            EsuOrgEnd        = [string](Get-WinForgeJsonValue -Object $entry -Name "EsuOrgEnd" -Default "")
            UpdateRevision   = $(if ($updateRevision) { [int]$updateRevision } else { 0 })
            UpdateDate       = [string](Get-WinForgeJsonValue -Object $entry -Name "UpdateDate" -Default "")
        }

        if (-not (Test-WinForgeCatalogDate -Text $item.HomeEnd) -or -not (Test-WinForgeCatalogDate -Text $item.EnterpriseEnd)) { return $null }
        if (-not (Test-WinForgeCatalogDate -Text $item.LtscEnd -AllowEmpty) -or -not (Test-WinForgeCatalogDate -Text $item.EsuEnd -AllowEmpty)) { return $null }
        if (-not (Test-WinForgeCatalogDate -Text $item.IotLtscEnd -AllowEmpty) -or -not (Test-WinForgeCatalogDate -Text $item.EsuOrgEnd -AllowEmpty)) { return $null }
        if (-not (Test-WinForgeCatalogDate -Text $item.UpdateDate -AllowEmpty)) { return $null }

        # O suporte das edições Enterprise e Education nunca acaba antes do das Home e Pro.
        if ([string]::CompareOrdinal($item.EnterpriseEnd, $item.HomeEnd) -lt 0) { return $null }

        $lifecycle += $item
    }

    if ($lifecycle.Count -eq 0 -or @($lifecycle | Group-Object -Property Build | Where-Object { $_.Count -gt 1 }).Count -gt 0) { return $null }

    return [PSCustomObject]@{
        Updated          = $updated
        Essentials       = @($essentials)
        WindowsLifecycle = @($lifecycle | Sort-Object -Property Build)
        Source           = ""
    }
}


function Read-WinForgeCatalogCache {
    # O catálogo baixado da última vez, já conferido; $null sem cópia válida.
    $path = Get-WinForgeCatalogCachePath

    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $null }

    try {
        $document = Get-Content -LiteralPath $path -Raw -Encoding UTF8 -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        return $null
    }

    return (ConvertFrom-WinForgeCatalogDocument -Document $document -Downloaded)
}


function Get-WinForgeCatalog {
    # O catálogo em uso: a cópia baixada quando ela é válida e mais nova que a embutida; senão, a embutida. Source diz
    # qual ("online" ou "embutido"). Não acessa a internet: quem baixa é Update-WinForgeCatalog.
    $builtIn = ConvertFrom-WinForgeCatalogDocument -Document (Get-WinForgeBuiltInCatalog)
    $builtIn.Source = "embutido"

    $cached = Read-WinForgeCatalogCache

    if ($null -ne $cached -and [string]::CompareOrdinal($cached.Updated, $builtIn.Updated) -gt 0) {
        $cached.Source = "online"
        return $cached
    }

    return $builtIn
}


# ---------------------------------------------------------------------------
# Download
# ---------------------------------------------------------------------------

function Invoke-WinForgeCatalogDownload {
    # O texto do catálogo publicado. Lança erro quando não há resposta; separado para os testes trocarem a rede.
    param (
        [int]$TimeoutSeconds = 15
    )

    Enable-WinForgeTls12

    # Sem a barra de andamento do próprio PowerShell: na janela, ela tomaria o lugar do texto da etapa.
    $previous = $ProgressPreference
    $ProgressPreference = "SilentlyContinue"

    try {
        $response = Invoke-WebRequest -Uri (Get-WinForgeCatalogUrl) -UseBasicParsing -TimeoutSec $TimeoutSeconds -Headers @{ "User-Agent" = "WinForge/$(Get-WinForgeBuild)" } -ErrorAction Stop
    }
    finally {
        $ProgressPreference = $previous
    }

    return [string]$response.Content
}


function Update-WinForgeCatalog {
    <#
    Baixa o catálogo publicado e guarda a cópia se ela for válida e não for mais antiga que a guardada. Devolve Changed (a
    cópia em uso mudou), Problem ("" quando deu certo, em português), Detail (a mensagem técnica, quando há) e Catalog (o
    que vale agora). Nunca lança erro: sem internet, o embutido continua valendo.
    #>
    param (
        [int]$TimeoutSeconds = 15
    )

    $before = Get-WinForgeCatalog

    try {
        $text = Invoke-WinForgeCatalogDownload -TimeoutSeconds $TimeoutSeconds
    }
    catch {
        $friendly = ""
        if (Get-Command -Name ConvertTo-WinForgeWebErrorText -ErrorAction SilentlyContinue) { $friendly = ConvertTo-WinForgeWebErrorText -Exception $_.Exception -NotFound "o arquivo de dados não foi encontrado no site do WinForge" }

        return [PSCustomObject]@{
            Changed = $false
            Problem = $(if ($friendly) { $friendly } else { "não foi possível baixar os dados agora; tente de novo mais tarde" })
            Detail  = $(if ($friendly) { "" } else { $_.Exception.Message.TrimEnd('.') })
            Catalog = $before
        }
    }

    try {
        $document = $text | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        return [PSCustomObject]@{ Changed = $false; Problem = "os dados baixados não são um catálogo do WinForge"; Detail = ""; Catalog = $before }
    }

    $downloaded = ConvertFrom-WinForgeCatalogDocument -Document $document -Downloaded

    if ($null -eq $downloaded) {
        return [PSCustomObject]@{ Changed = $false; Problem = "os dados baixados não passaram na conferência"; Detail = ""; Catalog = $before }
    }

    # Uma publicação mais antiga que a cópia guardada (o arquivo do site voltou atrás) não substitui a mais nova.
    $cached = Read-WinForgeCatalogCache

    if ($null -ne $cached -and [string]::CompareOrdinal($downloaded.Updated, $cached.Updated) -lt 0) {
        [void](Set-WinForgeSetting -Name "CatalogCheckedAt" -Value ((Get-Date).ToString("o", [System.Globalization.CultureInfo]::InvariantCulture)))
        return [PSCustomObject]@{ Changed = $false; Problem = ""; Detail = ""; Catalog = $before }
    }

    try {
        # Gravação inteira de uma vez (arquivo temporário único e troca), com a trava dos arquivos de estado: a janela e o
        # monitor podem conferir os dados ao mesmo tempo.
        Invoke-WinForgeStateLock -ScriptBlock { Write-WinForgeStateFile -Path (Get-WinForgeCatalogCachePath) -Text $text }
    }
    catch {
        return [PSCustomObject]@{ Changed = $false; Problem = "não foi possível guardar os dados na pasta do WinForge"; Detail = $_.Exception.Message.TrimEnd('.'); Catalog = $before }
    }

    [void](Set-WinForgeSetting -Name "CatalogCheckedAt" -Value ((Get-Date).ToString("o", [System.Globalization.CultureInfo]::InvariantCulture)))

    $after = Get-WinForgeCatalog

    return [PSCustomObject]@{ Changed = ($after.Updated -ne $before.Updated -or $after.Source -ne $before.Source); Problem = ""; Detail = ""; Catalog = $after }
}


function Test-WinForgeCatalogStale {
    # Verdadeiro quando o catálogo não é conferido online há mais de $Days dias (o monitor da bandeja confere sozinho).
    param (
        [int]$Days = 7,
        [datetime]$Now = (Get-Date)
    )

    $checked = [string](Get-WinForgeSetting -Name "CatalogCheckedAt" -Default "")
    $parsed = [datetime]::MinValue

    if ([string]::IsNullOrWhiteSpace($checked) -or -not [datetime]::TryParse($checked, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind, [ref]$parsed)) {
        return $true
    }

    return (($Now - $parsed).TotalDays -gt $Days)
}


function Update-WinForgeOnlineData {
    $title = "Conferir dados online"

    Enter-WinForgeAction -Title $title

    $final = New-WinForgeResult -Kind Ok -Title $title

    try {
        Write-Progress -Activity $title -Status "baixando a lista de programas e as datas de suporte do Windows"

        try {
            $update = Update-WinForgeCatalog
        }
        finally {
            Write-Progress -Activity $title -Completed
        }

        $catalog = $update.Catalog
        $dated = Format-WinForgeDateTime -When ([datetime]::ParseExact($catalog.Updated, "yyyy-MM-dd", [System.Globalization.CultureInfo]::InvariantCulture)) -Pattern "dd/MM/yyyy"
        $essentials = @($catalog.Essentials).Count
        $versions = @($catalog.WindowsLifecycle).Count

        Write-WinForgeKeyValue -Label "Dados de" -Value $dated
        Write-WinForgeKeyValue -Label "Origem" -Value $(if ($catalog.Source -eq "online") { "baixados do site do WinForge" } else { "os que vêm com o WinForge" })
        Write-WinForgeKeyValue -Label "Programas essenciais" -Value (Format-WinForgeCount -Count $essentials -One "programa" -Many "programas")
        Write-WinForgeKeyValue -Label "Versões do Windows" -Value (Format-WinForgeCount -Count $versions -One "versão" -Many "versões")
        Write-Host ""

        if ($update.Problem) {
            Write-WinForgeStatus -Type Warning -Message "Não foi possível atualizar: $($update.Problem). O WinForge continua com os dados acima."
            if ($update.Detail) { Write-WinForgeStatus -Type Info -Notice -Message "Detalhe: $($update.Detail)" }
            $problem = $update.Problem.Substring(0, 1).ToUpperInvariant() + $update.Problem.Substring(1)
            $final = Set-WinForgeResultView -Result (New-WinForgeResult -Kind Warning -Detail $update.Problem -Title $title) `
                -Headline "Dados não atualizados" -Note "$problem. O WinForge segue com os dados de $dated."
        }
        elseif ($update.Changed) {
            Write-WinForgeStatus -Type Success -Message "Dados atualizados."
            $contents = "$(Format-WinForgeCount -Count $essentials -One 'programa essencial' -Many 'programas essenciais') e $(Format-WinForgeCount -Count $versions -One 'versão do Windows' -Many 'versões do Windows')"
            $final = Set-WinForgeResultView -Result (New-WinForgeResult -Kind Ok -Detail "dados atualizados" -Title $title) `
                -Headline "Dados atualizados" -Note "Dados de ${dated}: $contents."
        }
        else {
            Write-WinForgeStatus -Type Success -Message "Os dados já estavam em dia."
            $final = Set-WinForgeResultView -Result (New-WinForgeResult -Kind Ok -Detail "os dados já estavam em dia" -Title $title) `
                -Headline "Dados em dia" -Note "Não há dados publicados mais novos que os de $dated."
        }

        Write-WinForgeStatus -Type Info -Message "Só a lista é baixada: o WinForge não envia nenhum dado do PC."
    }
    catch {
        Write-WinForgeStatus -Type Error -Message "Não foi possível atualizar os dados: $($_.Exception.Message)"
        $final = New-WinForgeResult -Kind Failed -Detail $_.Exception.Message -Title $title
    }

    Exit-WinForgeAction -Result $final
}


Export-ModuleMember -Function *
