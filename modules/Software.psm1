# Programas: instalação, atualização e remoção pelo winget.
# O winget só é consultado quando uma ação precisa dele (e a lista de pacotes é atualizada uma vez por sessão).

$script:WinForgeWingetReady = $false
$script:WinForgeInstalledIdsCache = $null

# Depois de desinstalar, as esperas (em segundos) antes de conferir de novo um programa que o desinstalador deu como
# removido e que ainda aparece na lista: muitos se copiam para a pasta temporária, devolvem "sucesso" na hora e só então
# apagam o programa (ou abrem a própria janela, que espera a pessoa). Wait-WinForgeUninstallResults.
$script:WinForgeUninstallRecheckDelays = @(2, 5, 10)

# Quantos IDs cortados pela tabela do winget a lista de desinstalar completa com uma consulta própria ao winget (cada uma
# leva alguns segundos). Os que passam disso ficam fora da lista.
$script:WinForgeTruncatedIdQueryLimit = 5

# A recusa do winget, de um processo elevado, a desinstalar e atualizar o que foi instalado só para a conta da pessoa
# (APPINSTALLER_CLI_ERROR_ADMIN_CONTEXT_ACTION_PROHIBITED, 0x8A15007D, na tabela de códigos do winget).
# Invoke-WinForgeWingetUserScope.
$script:WinForgeWingetUserScopeCode = -1978335107


# ---------------------------------------------------------------------------
# Disponibilidade do winget
# ---------------------------------------------------------------------------

function Test-WinForgeWinget {
    return [bool](Get-Command -Name "winget" -CommandType Application -ErrorAction SilentlyContinue)
}


function Get-WinForgeWingetMissingDetail {
    # O detalhe da faixa quando falta o winget, igual em todas as telas de Programas.
    return (Get-WinForgeText 'o Instalador de Aplicativo (winget) não está neste PC')
}


function Get-WinForgeWingetMissingResult {
    # A faixa das telas que usam o winget quando ele falta: o título diz o que falta, e a frase, de onde ele vem; o botão
    # leva ao reparo (Repair-WinForgeWinget). O detalhe é o de sempre (Get-WinForgeWingetMissingDetail), que o Otimizar
    # reconhece.
    param ([string]$Title = "")

    $result = New-WinForgeResult -Kind Failed -Detail (Get-WinForgeWingetMissingDetail) -Title $Title

    return (Set-WinForgeResultView -Result $result -Headline (Get-WinForgeText 'Falta o Instalador de Aplicativo') `
            -Note (Get-WinForgeText 'Num Windows recém-instalado, ele chega quando a Microsoft Store se atualiza.') `
            -Next "software.winget-repair" -NextLabel (Get-WinForgeText 'Reparar'))
}


function Write-WinForgeWingetMissing {
    <#
    O que dizer quando falta o winget, que a pessoa conhece como Instalador de Aplicativo. É o caso mais comum logo depois
    de formatar: o Windows recém-instalado só o registra quando a Microsoft Store se atualiza. -OfferStore pergunta se
    abre a página dele na Store (nas telas de Programas, em que a pessoa quer instalar ou remover algo agora).
    #>
    param ([switch]$OfferStore)

    Write-WinForgeStatus -Type Error -Message (Get-WinForgeText 'O Instalador de Aplicativo da Microsoft, que o WinForge usa para instalar programas, não está neste PC.')
    Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Num Windows recém-instalado, ele chega quando a Microsoft Store se atualiza. Abra a Store, deixe-a atualizar e tente de novo.')

    # Na janela, o botão da faixa leva ao reparo; no menu de texto, a linha diz onde ele fica.
    if (-not (Test-WinForgeGuiMode)) { Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Se ele já estiver instalado, use Programas > Reparar o Instalador de Aplicativo.') }

    if (-not $OfferStore) { return }

    Write-Host ""

    if (Confirm-WinForgeAction -Message (Get-WinForgeText 'Abrir o Instalador de Aplicativo na Microsoft Store agora?') -DefaultKey S -YesLabel (Get-WinForgeText 'Abrir') -NoLabel (Get-WinForgeText 'Agora não')) {
        [void](Open-WinForgeAppInstallerPage)
    }
}


function Open-WinForgeAppInstallerPage {
    # A página do Instalador de Aplicativo (o winget) na Microsoft Store. Devolve $true se o Windows aceitou abrir.
    try {
        Start-Process -FilePath "ms-windows-store://pdp/?ProductId=9NBLGGH4NNS1" -ErrorAction Stop
        Write-WinForgeStatus -Type Info -Notice -Message (Get-WinForgeText 'Abrindo a Microsoft Store. Depois de instalar ou atualizar o Instalador de Aplicativo, use esta ação de novo.')
        return $true
    }
    catch {
        Write-WinForgeStatus -Type Warning -Notice -Message (Get-WinForgeText 'O Windows não abriu a Microsoft Store ({0}). Abra a Store pelo Menu Iniciar e procure por Instalador de Aplicativo.' "$(([string]$_.Exception.Message).Trim().TrimEnd('.'))")
        return $false
    }
}


function Initialize-WinForgeWinget {
    # Verifica o winget e atualiza a fonte principal uma única vez por sessão. Devolve $false se não houver winget.
    # -OfferStore: sem o winget, pergunta se abre a página dele na Microsoft Store (Write-WinForgeWingetMissing).
    param (
        [switch]$Force,
        [switch]$OfferStore
    )

    if (-not (Test-WinForgeWinget)) {
        Write-WinForgeWingetMissing -OfferStore:$OfferStore
        return $false
    }

    if ($script:WinForgeWingetReady -and -not $Force) {
        return $true
    }

    # O andamento vai para a barra de progresso; só um problema vira mensagem.
    Write-Progress -Activity (Get-WinForgeText 'Preparando o winget') -Status (Get-WinForgeText 'atualizando a lista de pacotes')

    try {
        $source = Invoke-WinForgeCapture -FilePath "winget" -Arguments @("source", "update", "--name", "winget", "--disable-interactivity")
    }
    finally {
        Write-Progress -Activity (Get-WinForgeText 'Preparando o winget') -Completed
    }

    if ($source.ExitCode -ne 0) {
        Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'Não foi possível atualizar a lista de pacotes do winget; a consulta usa a lista guardada neste PC.')
    }

    $script:WinForgeWingetReady = $true
    return $true
}


function Write-WinForgeWingetUserWarning {
    # Elevado com outra conta, o winget trabalha no perfil dessa conta: pacotes instalados só para o usuário logado não
    # aparecem, e o que se instala "só para o usuário" vai para o perfil da conta elevada.
    param (
        [ValidateSet("List", "Install", "Upgrade")]
        [string]$Context = "List"
    )

    if (-not (Test-WinForgeUserContextMismatch)) {
        return
    }

    $currentUser = "$([Environment]::UserDomainName)\$([Environment]::UserName)"
    $interactiveUser = Get-WinForgeInteractiveUser

    Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'O WinForge está elevado como {0}.' "$currentUser")

    switch ($Context) {
        "Install" { Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Programas que se instalam só para o usuário ficam no perfil de {0}, não no de {1}.' "$currentUser" "$interactiveUser") }
        "Upgrade" { Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Programas instalados só para {0} podem não aparecer na lista de atualizações.' "$interactiveUser") }
        default { Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Pacotes exclusivos de {0} podem não aparecer neste contexto.' "$interactiveUser") }
    }

    Write-Host ""
}


# ---------------------------------------------------------------------------
# Leitura das tabelas do winget (independente do idioma)
# ---------------------------------------------------------------------------

function Get-WinForgeTextColumnIndex {
    param (
        [string]$Text,
        [string[]]$Names
    )

    foreach ($name in $Names) {
        # Palavra inteira, sem diferenciar maiúsculas/minúsculas ("Id" e "ID" no winget em pt-BR).
        $pattern = "(?<!\p{L})" + [regex]::Escape($name) + "(?!\p{L})"
        $match = [regex]::Match($Text, $pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)

        if ($match.Success) {
            return $match.Index
        }
    }

    return -1
}


function Get-WinForgeCharWidth {
    # Colunas que um caractere ocupa no console: 2 para ideogramas, kana, hangul e emojis; 0 para marcas combinadas.
    param (
        [char]$Char
    )

    $code = [int]$Char

    if ([char]::IsLowSurrogate($Char)) { return 0 }
    if ([char]::IsHighSurrogate($Char)) { return 2 }
    if (($code -ge 0x0300 -and $code -le 0x036F) -or ($code -ge 0x200B -and $code -le 0x200F) -or $code -eq 0xFE0F) { return 0 }

    if (
        ($code -ge 0x1100 -and $code -le 0x115F) -or
        ($code -ge 0x2E80 -and $code -le 0xA4CF) -or
        ($code -ge 0xAC00 -and $code -le 0xD7A3) -or
        ($code -ge 0xF900 -and $code -le 0xFAFF) -or
        ($code -ge 0xFE30 -and $code -le 0xFE6F) -or
        ($code -ge 0xFF00 -and $code -le 0xFF60) -or
        ($code -ge 0xFFE0 -and $code -le 0xFFE6)
    ) {
        return 2
    }

    return 1
}


function Get-WinForgeSafeSubstring {
    # Recorta uma coluna da tabela do winget. Start e End são colunas de tela (o winget alinha pelo que aparece no
    # console, e nomes em chinês, japonês ou coreano ocupam duas colunas por caractere). End fora do texto ou
    # menor que Start significa "até o fim da linha".
    param (
        [string]$Text,
        [int]$Start,
        [int]$End
    )

    if ([string]::IsNullOrEmpty($Text) -or $Start -lt 0) {
        return ""
    }

    # Caminho rápido: sem caracteres largos nem combinados, coluna e posição no texto são a mesma coisa. A lista é a mesma de
    # Get-WinForgeCharWidth; letras acentuadas, reticências "…", símbolos comuns e emojis (dois caracteres, duas colunas) ficam
    # de fora e não pagam o caminho lento.
    if ($Text -notmatch "[\u0300-\u036F\u1100-\u115F\u200B-\u200F\u2E80-\uA4CF\uAC00-\uD7A3\uF900-\uFAFF\uFE0F\uFE30-\uFE6F\uFF00-\uFF60\uFFE0-\uFFE6]") {
        if ($Start -ge $Text.Length) { return "" }
        if ($End -le $Start -or $End -gt $Text.Length) { $End = $Text.Length }

        return $Text.Substring($Start, $End - $Start).Trim()
    }

    $builder = New-Object System.Text.StringBuilder
    $column = 0

    foreach ($char in $Text.ToCharArray()) {
        if ($End -gt $Start -and $column -ge $End) {
            break
        }

        if ($column -ge $Start) {
            [void]$builder.Append($char)
        }

        # Abaixo de U+0300 todo caractere ocupa uma coluna: só o resto precisa da tabela de larguras.
        if ([int]$char -lt 0x0300) { $column++ } else { $column += Get-WinForgeCharWidth -Char $char }
    }

    return $builder.ToString().Trim()
}


function ConvertFrom-WinForgeWingetTable {
    <#
    Lê a tabela de "winget list/upgrade/search" pelas posições das colunas do cabeçalho.
    Devolve objetos com Nome, Id, Versao, Disponivel e Fonte. Linhas fora da tabela (rodapé, avisos,
    segunda tabela de "requer seleção explícita") são ignoradas.
    #>
    param (
        [string[]]$Lines
    )

    $lineArray = @($Lines | ForEach-Object { [string]$_ })
    $headerIndex = -1

    for ($i = 0; $i -lt $lineArray.Count; $i++) {
        $line = $lineArray[$i]

        if ($line -match "\bId\b" -and $line -match "\b(Name|Nome|Nombre)\b" -and ($line -match "\bVersion\b" -or $line -match "Vers")) {
            $headerIndex = $i
            break
        }
    }

    if ($headerIndex -lt 0) {
        return @()
    }

    $header = $lineArray[$headerIndex]
    # Os títulos das colunas do winget em inglês, português e espanhol (os textos dele, de cada idioma do Windows).
    $nameStart = Get-WinForgeTextColumnIndex -Text $header -Names @("Name", "Nome", "Nombre")
    $idStart = Get-WinForgeTextColumnIndex -Text $header -Names @("Id")
    $versionStart = Get-WinForgeTextColumnIndex -Text $header -Names @("Version", "Versão", "Versao", "Versión")
    $availableStart = Get-WinForgeTextColumnIndex -Text $header -Names @("Available", "Disponível", "Disponivel", "Disponible")
    $matchStart = Get-WinForgeTextColumnIndex -Text $header -Names @("Match", "Correspondência", "Correspondencia", "Coincidencia")
    $sourceStart = Get-WinForgeTextColumnIndex -Text $header -Names @("Source", "Fonte", "Origem", "Origen")

    if ($nameStart -lt 0 -or $idStart -lt 0 -or $versionStart -lt 0) {
        return @()
    }

    # A coluna de versão termina onde começa a próxima coluna à direita.
    $versionEnd = $header.Length
    $availableEnd = $header.Length

    foreach ($candidate in @($availableStart, $matchStart, $sourceStart)) {
        if ($candidate -gt $versionStart -and $candidate -lt $versionEnd) {
            $versionEnd = $candidate
        }
    }

    if ($availableStart -gt $versionStart) {
        foreach ($candidate in @($matchStart, $sourceStart)) {
            if ($candidate -gt $availableStart -and $candidate -lt $availableEnd) {
                $availableEnd = $candidate
            }
        }
    }

    $packages = New-Object System.Collections.Generic.List[PSObject]
    $rowsStarted = $false

    for ($i = $headerIndex + 1; $i -lt $lineArray.Count; $i++) {
        $line = $lineArray[$i]

        if ([string]::IsNullOrWhiteSpace($line)) {
            if ($rowsStarted) { break }
            continue
        }

        if ($line.Trim() -match "^-+$") {
            continue
        }

        if ($line -match "^[0-9]+\s+(upgrades?|packages?|pacotes?|atualiza|actualizaci|paquetes?)" -or $line -match "Nenhuma atualiza|ninguna actualizaci" -or $line -match "No available upgrade") {
            if ($rowsStarted) { break }
            continue
        }

        $name = Get-WinForgeSafeSubstring -Text $line -Start $nameStart -End $idStart
        $id = Get-WinForgeSafeSubstring -Text $line -Start $idStart -End $versionStart
        $version = Get-WinForgeSafeSubstring -Text $line -Start $versionStart -End $versionEnd
        $available = ""
        $source = ""

        if ($availableStart -gt $versionStart) {
            $available = Get-WinForgeSafeSubstring -Text $line -Start $availableStart -End $availableEnd
        }

        if ($sourceStart -gt $versionStart) {
            $source = Get-WinForgeSafeSubstring -Text $line -Start $sourceStart -End 0
        }

        if ([string]::IsNullOrWhiteSpace($name) -and [string]::IsNullOrWhiteSpace($id)) {
            continue
        }

        # Uma linha sem Id, ou com espaço no Id (texto solto depois da tabela), não é um pacote. A exceção são os IDs locais
        # do winget para o que ele só encontrou no Windows, que repetem o nome do programa: "ARP\Machine\X86\Microsoft Edge
        # Update". Sem ela, a leitura parava no primeiro desses e a lista perdia todos os programas seguintes.
        if ([string]::IsNullOrWhiteSpace($id) -or ($id -match "\s" -and $id -notmatch '^(ARP|MSIX)\\')) {
            if ($rowsStarted) { break }
            continue
        }

        $rowsStarted = $true

        $packages.Add([PSCustomObject]@{
            Nome       = $(if ([string]::IsNullOrWhiteSpace($name)) { $id } else { $name })
            Id         = $id
            Versao     = $(if ([string]::IsNullOrWhiteSpace($version)) { "?" } else { $version })
            Disponivel = $available
            Fonte      = $(if ([string]::IsNullOrWhiteSpace($source)) { "?" } else { $source })
        })
    }

    return $packages.ToArray()
}


function Test-WinForgeWingetNoUpgradeOutput {
    <#
    "Não há o que atualizar", pelo código de saída do winget (0x8A150014 = nenhum pacote encontrado e 0x8A15002B =
    nenhuma atualização aplicável: não mudam com o idioma) ou, na falta dele, pelas frases em inglês, português e espanhol.
    Também quando o "winget upgrade" só deixou programas de fora: os marcados para não atualizar (winget pin) e os de
    versão desconhecida. Aí ele termina sem tabela e sem a frase de "nada a atualizar", só com o rodapé que conta os que
    ficaram de fora, e esse rodapé traz, em todo idioma, a opção do próprio winget (--include-pinned ou
    --include-unknown).
    #>
    param (
        [string]$OutputText,
        [int]$ExitCode = 0
    )

    if (
        $ExitCode -in @(-1978335212, -1978335189) -or
        $OutputText -match "(?i)No installed package found matching input criteria" -or
        $OutputText -match "(?i)No available upgrade found" -or
        $OutputText -match "(?i)Nenhuma atualiza" -or
        $OutputText -match "(?i)Nenhum pacote instalado" -or
        $OutputText -match "(?i)No se encontr.{1,3} ning.{1,3}n paquete|No se ha encontrado ninguna actualizaci"
    ) {
        return $true
    }

    if ($ExitCode -eq 0 -and $OutputText -match '(?m)^\s*\d+\s.*--include-(pinned|unknown)') {
        return (@(ConvertFrom-WinForgeWingetTable -Lines @($OutputText -split "`r?`n")).Count -eq 0)
    }

    return $false
}


function Get-WinForgeWingetHeldCount {
    # Quantos programas com versão nova o "winget upgrade" deixou de fora por estarem marcados para não atualizar (winget
    # pin): o número do rodapé "{0} pacote(s) têm pinos que impedem a atualização...", que traz em todo idioma o
    # --include-pinned do próprio winget. 0 sem esse rodapé.
    param ([string[]]$Lines = @())

    foreach ($line in @($Lines)) {
        if ([string]$line -match '^\s*(\d+)\s.*--include-pinned') { return [int]$Matches[1] }
    }

    return 0
}


function ConvertTo-WinForgeWingetPackageIdList {
    param (
        [string]$InputText
    )

    if ([string]::IsNullOrWhiteSpace($InputText)) {
        return @()
    }

    $packageIds = New-Object System.Collections.Generic.List[string]

    foreach ($segment in ($InputText -split ",")) {
        $packageId = $segment.Trim()

        if ([string]::IsNullOrWhiteSpace($packageId)) {
            throw (Get-WinForgeText 'Há uma vírgula sem um ID antes ou depois dela. Revise a lista informada.')
        }

        if ($packageId -match "\s") {
            throw (Get-WinForgeText 'O ID ''{0}'' contém espaços. Separe vários IDs por vírgula.' "$packageId")
        }

        if ($packageId.ToUpperInvariant() -in @("S", "N", "ID")) {
            throw (Get-WinForgeText 'A lista contém ''{0}'', que é uma opção de menu e não um ID de pacote.' "$packageId")
        }

        if ($packageId -match '^-' -or $packageId -match '["`;|&<>]') {
            throw (Get-WinForgeText 'O ID ''{0}'' contém caracteres que não fazem parte de um ID do winget.' "$packageId")
        }

        if (-not $packageIds.Contains($packageId)) {
            $packageIds.Add($packageId)
        }
    }

    return @($packageIds)
}


# ---------------------------------------------------------------------------
# Execução (argumentos e códigos de saída)
# ---------------------------------------------------------------------------

function Get-WinForgeWingetArguments {
    param (
        [Parameter(Mandatory)]
        [ValidateSet("Install", "Upgrade", "UpgradeAll", "Uninstall")]
        [string]$Operation,

        [string]$PackageId,

        # O catálogo essencial usa IDs do repositório winget; evita resolver para outra fonte.
        [switch]$WingetSourceOnly,

        # A fonte de onde o pacote veio na busca (winget ou msstore): instalar por ela evita que o winget ache o mesmo ID
        # em outra fonte e pare em "mais de um pacote".
        [string]$Source = "",

        # Desinstalar um ID com mais de uma versão instalada: sem --all-versions, o winget para em "várias versões
        # instaladas" e não remove nenhuma.
        [switch]$AllVersions
    )

    switch ($Operation) {
        "UpgradeAll" {
            return @("upgrade", "--all", "--accept-source-agreements", "--accept-package-agreements", "--disable-interactivity", "--silent")
        }
        "Uninstall" {
            $arguments = @("uninstall", "--id", $PackageId, "-e", "--disable-interactivity", "--silent")
            if ($AllVersions) { $arguments += "--all-versions" }
            return $arguments
        }
        default {
            $verb = $Operation.ToLowerInvariant()
            $arguments = @($verb, "--id", $PackageId, "-e", "--accept-source-agreements", "--accept-package-agreements", "--disable-interactivity", "--silent")

            if ($WingetSourceOnly) {
                $arguments += @("--source", "winget")
            }
            elseif ($Source -in @("winget", "msstore")) {
                $arguments += @("--source", $Source)
            }

            return $arguments
        }
    }
}


function Get-WinForgeWingetExitResult {
    <#
    Traduz o código de saída do winget. Os códigos 0x8A15xxxx chegam como inteiros negativos; os significados são os da
    tabela de códigos de retorno do winget (Microsoft). Os demais negativos aparecem em hexadecimal, que é como se
    pesquisa o erro; os positivos vêm do próprio instalador e ficam em decimal.
    #>
    param (
        [int]$ExitCode
    )

    $code = "0x{0:X8}" -f $ExitCode
    $failed = { param ($Text) New-WinForgeResult -Kind Failed -Detail (Get-WinForgeText '{0} — erro {1}' "$Text" "$code") }

    switch ($code) {
        "0x00000000" { return (New-WinForgeResult -Kind Ok) }
        "0x8A15002B" { return (New-WinForgeResult -Kind Ok -Detail (Get-WinForgeText 'já está na versão mais recente')) }
        "0x8A150061" { return (New-WinForgeResult -Kind Ok -Detail (Get-WinForgeText 'já estava instalado')) }
        "0x8A15010D" { return (New-WinForgeResult -Kind Ok -Detail (Get-WinForgeText 'outra versão já estava instalada')) }
        "0x8A15010E" { return (New-WinForgeResult -Kind Ok -Detail (Get-WinForgeText 'já há uma versão mais nova instalada')) }
        "0x8A150109" { return (New-WinForgeResult -Kind Warning -Detail (Get-WinForgeText 'termina na próxima reinicialização') -Data @{ RebootRequired = $true }) }
        # O próprio instalador reinicia o PC (RebootStarted): oferecer o reinício de novo não faria sentido.
        "0x8A15010B" { return (New-WinForgeResult -Kind Warning -Detail (Get-WinForgeText 'o instalador vai reiniciar o PC para terminar') -Data @{ RebootRequired = $true; RebootStarted = $true }) }
        "0x8A150014" { return (New-WinForgeResult -Kind Failed -Detail (Get-WinForgeText 'pacote não encontrado')) }
        "0x8A15002C" { return (& $failed (Get-WinForgeText 'algum programa não foi atualizado')) }
        "0x8A150034" { return (& $failed (Get-WinForgeText 'algum programa da lista não foi instalado')) }
        "0x8A150035" { return (& $failed (Get-WinForgeText 'algum programa da lista não foi encontrado no winget')) }
        "0x8A150011" { return (& $failed (Get-WinForgeText 'o instalador baixado não confere com o esperado')) }
        "0x8A150101" { return (& $failed (Get-WinForgeText 'o programa está aberto; feche-o e tente de novo')) }
        "0x8A150103" { return (& $failed (Get-WinForgeText 'há arquivos do programa em uso; feche-o e tente de novo')) }
        "0x8A150111" { return (& $failed (Get-WinForgeText 'o programa está em uso por outro programa; feche-os e tente de novo')) }
        "0x8A150102" { return (& $failed (Get-WinForgeText 'outra instalação está em andamento; tente mais tarde')) }
        "0x8A150105" { return (& $failed (Get-WinForgeText 'falta espaço no disco')) }
        "0x8A150107" { return (& $failed (Get-WinForgeText 'o instalador precisa de internet')) }
        "0x8A15010A" { return (& $failed (Get-WinForgeText 'reinicie o PC e tente de novo')) }
        "0x8A15010C" { return (& $failed (Get-WinForgeText 'a instalação foi cancelada no instalador')) }
        "0x8A150114" { return (& $failed (Get-WinForgeText 'o instalador não atualiza por cima da versão instalada')) }
        "0x8A15003A" { return (& $failed (Get-WinForgeText 'bloqueado por uma política do Windows')) }
        "0x8A15010F" { return (& $failed (Get-WinForgeText 'uma política da organização impede a instalação; fale com o suporte de TI')) }
        "0x8A15001B" { return (& $failed (Get-WinForgeText 'a Microsoft Store está bloqueada por uma política do Windows')) }
        "0x8A150104" { return (& $failed (Get-WinForgeText 'falta no PC um componente de que o programa depende')) }
        "0x8A150110" { return (& $failed (Get-WinForgeText 'não foi possível instalar os componentes de que o programa depende')) }
        "0x8A150106" { return (& $failed (Get-WinForgeText 'falta memória livre; feche outros programas e tente de novo')) }
        "0x8A150113" { return (& $failed (Get-WinForgeText 'o programa não é compatível com este PC ou com esta versão do Windows')) }
        "0x8A150108" { return (& $failed (Get-WinForgeText 'o instalador do programa falhou; o fabricante sugere procurar o suporte dele')) }
        "0x8A150115" { return (& $failed (Get-WinForgeText 'o instalador do programa falhou com um erro próprio')) }
        "0x8A150016" { return (& $failed (Get-WinForgeText 'mais de um pacote corresponde a esse ID')) }
        "0x8A15007D" { return (& $failed (Get-WinForgeText 'o programa foi instalado só para o seu usuário, e o winget não o altera como Administrador; para continuar sem Administrador, {0}' "$(Get-WinForgeUnelevatedHint)")) }
        "0x8A150056" { return (& $failed (Get-WinForgeText 'o instalador não roda como Administrador; para continuar sem Administrador, {0}' "$(Get-WinForgeUnelevatedHint)")) }
        "0x8A150076" { return (& $failed (Get-WinForgeText 'a fonte do pacote pede que você entre com uma conta')) }
        "0x8A15001C" { return (& $failed (Get-WinForgeText 'uma política do Windows bloqueia esse aplicativo da Microsoft Store')) }
        "0x8A15008E" { return (& $failed (Get-WinForgeText 'a versão nova usa outro tipo de instalador; desinstale a atual e instale de novo')) }
        "0x8A150015" { return (& $failed (Get-WinForgeText 'o winget está sem fontes de pacotes configuradas')) }
        # Desinstalar: o programa não registrou como se desinstala, ou o desinstalador dele terminou com erro (o que inclui
        # cancelar na janela dele). Os dois 0x80073xxx vêm do Windows ao remover um aplicativo da Microsoft Store.
        "0x8A15002F" { return (& $failed (Get-WinForgeText 'o programa não tem desinstalador registrado')) }
        "0x8A150030" { return (& $failed (Get-WinForgeText 'o desinstalador terminou com erro ou foi cancelado')) }
        "0x80073CFA" { return (& $failed (Get-WinForgeText 'o Windows não permite remover este aplicativo')) }
        "0x80073D02" { return (& $failed (Get-WinForgeText 'o aplicativo está aberto; feche-o e tente de novo')) }
        # Sem internet, ou com ela caindo no meio: o download do instalador falha (0x8A150008) ou o Windows nem chega ao
        # servidor (nome que não resolve, conexão recusada, tempo esgotado).
        "0x8A150008" { return (& $failed (Get-WinForgeText 'não foi possível baixar o instalador; confira a internet')) }
        "0x80072EE7" { return (& $failed (Get-WinForgeText 'sem conexão com a internet')) }
        "0x80072EFD" { return (& $failed (Get-WinForgeText 'sem conexão com a internet')) }
        "0x80072EE2" { return (& $failed (Get-WinForgeText 'sem conexão com a internet')) }
    }

    if ($ExitCode -lt 0) {
        return (New-WinForgeResult -Kind Failed -Detail (Get-WinForgeText 'erro {0}' "$code"))
    }

    return (New-WinForgeResult -Kind Failed -Detail (Get-WinForgeText 'código de saída {0}' "$ExitCode"))
}


function Get-WinForgeLastResult {
    # O último WinForge.Result entre as saídas de uma função (ou $null, se ela não devolveu nenhum). As funções de
    # instalar, atualizar e desinstalar escrevem na tela e devolvem o resultado no pipeline junto com outras saídas.
    param (
        [object[]]$Output
    )

    $last = $null

    foreach ($item in @($Output)) {
        if ($null -ne $item -and $item.PSObject.TypeNames -contains "WinForge.Result") {
            $last = $item
        }
    }

    return $last
}


function Get-WinForgeWingetVerbs {
    # As palavras de cada operação, para o andamento e as frases do resultado. Truncated: o que fazer com um pacote cujo ID
    # o winget mostrou cortado.
    param ([Parameter(Mandatory)][ValidateSet("Install", "Upgrade", "Uninstall")][string]$Operation)

    $truncated = (Get-WinForgeText 'o winget mostrou o ID incompleto')

    switch ($Operation) {
        "Install"   { return @{ Activity = (Get-WinForgeText 'Instalando programas'); One = (Get-WinForgeText 'instalado'); Many = (Get-WinForgeText 'instalados'); Truncated = (Get-WinForgeText '{0}; busque de novo por um nome mais específico' "$truncated") } }
        "Upgrade"   { return @{ Activity = (Get-WinForgeText 'Atualizando programas'); One = (Get-WinForgeText 'atualizado'); Many = (Get-WinForgeText 'atualizados'); Truncated = (Get-WinForgeText '{0}; atualize pelo próprio programa' "$truncated") } }
        "Uninstall" { return @{ Activity = (Get-WinForgeText 'Desinstalando programas'); One = (Get-WinForgeText 'desinstalado'); Many = (Get-WinForgeText 'desinstalados'); Truncated = (Get-WinForgeText '{0}; desinstale em Programas > Aplicativos instalados' "$truncated") } }
    }
}


function Test-WinForgeWingetIdTruncated {
    # O winget corta com reticências o que não cabe na largura da tabela, inclusive o ID ("MSIX\Microsoft.UI.Xaml.2.6_2.62…").
    # Um ID cortado não serve para --id: o winget responderia "pacote não encontrado".
    param (
        [string]$Id
    )

    return ([string]$Id).EndsWith([string][char]0x2026) -or ([string]$Id).EndsWith("...")
}


function Get-WinForgeWingetSourceLabel {
    # A fonte de um pacote como a pessoa a conhece: "winget", "Microsoft Store" ou vazio (o que o winget só encontrou no
    # Windows, sem um pacote correspondente nas fontes dele).
    param (
        [string]$Source
    )

    $text = ([string]$Source).Trim()

    if ($text -eq "msstore") { return "Microsoft Store" }
    if ($text -eq "" -or $text -eq "?") { return "" }

    return $text
}


function Format-WinForgeWingetPackageDescription {
    # A linha de apoio de um pacote nas listas de marcar: "Vendor.Tool · versão 3.1 · Microsoft Store". Versão e fonte que o
    # winget não informa ficam de fora; um ID cortado é avisado, porque não serve para instalar nem desinstalar. Os IDs que
    # o winget inventa para o que achou só no Windows ("ARP\Machine\X64\{8a69...}", "MSIX\Microsoft.Foo_1.2_x64__8wek...")
    # não dizem nada a quem lê e também ficam de fora.
    param (
        [Parameter(Mandatory)]
        $Package
    )

    $parts = @()
    if ([string]$Package.Id -notmatch '^(ARP|MSIX)\\') { $parts += [string]$Package.Id }
    $version = ([string]$Package.Versao).Trim()
    $versions = [int](Get-WinForgeJsonValue -Object $Package -Name "Versoes" -Default 1)

    if ($versions -gt 1) {
        $parts += (Get-WinForgeText '{0} versões' "$versions")
    }
    elseif ($version -and $version -notmatch '^(\?|Unknown|Desconhecid[ao])$') {
        $parts += (Get-WinForgeText 'versão {0}' "$version")
    }

    $source = Get-WinForgeWingetSourceLabel -Source ([string]$Package.Fonte)

    if ($source) {
        $parts += $source
    }

    if (Test-WinForgeWingetIdTruncated -Id $Package.Id) {
        $parts += (Get-WinForgeText 'ID incompleto na lista do winget')
    }

    return ($parts -join " · ")
}


function Test-WinForgeWingetComponent {
    <#
    Pacotes da lista do winget que são peças do Windows, e não programas: os componentes (framework) dos aplicativos da
    Microsoft Store (VCLibs, UI.Xaml, .NET Native, Windows App Runtime), a própria Store, a Segurança do Windows e o
    Instalador de Aplicativo, que é o próprio winget. Ficam fora da lista de desinstalar (remover qualquer um quebra outros
    aplicativos ou esta página) e fora da conta dos programas instalados. Os aplicativos que vêm com o Windows e que
    Programas > Remover aplicativos do Windows protege (Calculadora, Fotos, Terminal, Bloco de Notas, Paint, Ferramenta de
    Captura) também: a lista de desinstalar não pode oferecer o que a outra tela protege.
    #>
    param ([Parameter(Mandatory)]$Package)

    $id = [string](Get-WinForgeJsonValue -Object $Package -Name "Id" -Default "")
    $name = ([string](Get-WinForgeJsonValue -Object $Package -Name "Nome" -Default "")).Trim()

    # A Store e o Instalador de Aplicativo também aparecem pelo ID da loja (9WZDNCRFJBMP, 9NBLGGH4NNS1) e pelo nome. Pelo
    # ID da loja aparecem ainda, quando o winget os associa a ela, os aplicativos protegidos (Calculadora 9WZDNCRFHVN5,
    # Fotos 9WZDNCRFJBH4, Bloco de Notas 9MSMLRH6LZF3, Paint 9PCFS5B6T72H, Ferramenta de Captura 9MZ95KL8MR0L, Terminal
    # 9N0DX20HK701), os componentes dos jogos (Xbox Identity Provider 9WZDNCRD1HKW, Gaming Services 9MWPM2CQNLHN) e as
    # extensões de imagem e vídeo (HEIF, HEVC, VP9, AV1, MPEG-2, WebP, Raw, Web Media), sem as quais fotos e vídeos desses
    # formatos deixam de abrir.
    # Os componentes aparecem com o ID do pacote no Windows (MSIX\Microsoft.VCLibs...) ou, quando o winget os associa ao
    # repositório, com o ID dele (Microsoft.UI.Xaml.2.8, Microsoft.VCLibs.Desktop.14, Microsoft.WindowsAppRuntime.1.5).
    $storeIds = '9WZDNCRFJBMP|9NBLGGH4NNS1|9WZDNCRFHVN5|9WZDNCRFJBH4|9MSMLRH6LZF3|9PCFS5B6T72H|9MZ95KL8MR0L|9N0DX20HK701|9WZDNCRD1HKW|9MWPM2CQNLHN|9PMMSR1CGPWG|9N4WGH0Z6VHQ|9N4D0MSMP0PT|9MVZQVXJBQ9V|9N95Q1ZZPMH4|9PG2DK419DRG|9NCTDW2W1BH8|9N5TDP8VCMHS'

    return ($id -match "^(Microsoft\.AppInstaller|$storeIds)$" -or
        $name -match '^(Microsoft Store|Instalador de Aplicativo|App Installer|Segurança do Windows|Windows Security|Instalador de aplicaci.n|Seguridad de Windows)$' -or
        $id -match '^(MSIX\\)?Microsoft\.(VCLibs|UI\.Xaml|NET\.Native|WindowsAppRuntime|WinAppRuntime|DirectXRuntime|Services\.Store|WindowsStore|StorePurchaseApp|DesktopAppInstaller|SecHealthUI|Winget\.Source|LanguageExperiencePack|XboxIdentityProvider|XboxGameOverlay|XboxSpeechToTextOverlay|Xbox\.TCUI|GamingServices|WidgetsPlatformRuntime|(HEIF|Webp|Raw)ImageExtension|(HEVC|VP9|AV1|MPEG2|AVCEncoder)VideoExtension|WebMediaExtensions)' -or
        $id -match '^(MSIX\\)?MicrosoftCorporationII\.WinAppRuntime' -or
        $id -match '^(MSIX\\)?Microsoft\.(WindowsCalculator|Windows\.Photos|WindowsTerminal|WindowsNotepad|Paint|ScreenSketch)(_|$)' -or
        $id -match '^MSIX\\(Windows\.|MicrosoftWindows\.)')
}


function Test-WinForgeWingetUninstallBlocked {
    <#
    O que a lista de desinstalar não oferece, além dos componentes do Windows (Test-WinForgeWingetComponent):
    - bibliotecas que outros programas usam sem avisar (Visual C++, .NET, WebView2, DirectX, GameInput): sem elas,
      programas param de abrir sem dizer por quê, e o programa que precisa de uma a instala de novo;
    - o Microsoft Edge e o atualizador dele: fora da Europa, o Windows não deixa desinstalar o Edge (o winget termina com
      erro, e o Edge continua), e o atualizador é o que mantém o Edge e o WebView2 em dia;
    - o Microsoft Update Health Tools, que o Windows Update instala de novo.
    SDKs e pacotes de destino ficam: são ferramentas que a pessoa instalou para programar.
    #>
    param ([Parameter(Mandatory)]$Package)

    if (Test-WinForgeWingetComponent -Package $Package) { return $true }

    $id = [string](Get-WinForgeJsonValue -Object $Package -Name "Id" -Default "")
    $name = ([string](Get-WinForgeJsonValue -Object $Package -Name "Nome" -Default "")).Trim()

    if ($name -match '(?i)\bSDK\b|targeting pack') { return $false }

    # "Redist" e não "Redistributable": a tabela do winget corta nomes longos ("...Redistrib…"). Sem associação a uma
    # fonte, o Edge, o atualizador e o WebView2 aparecem pelas chaves do registro (ARP\Machine\X86\Microsoft Edge Update).
    return ($id -match '^Microsoft\.(VCRedist\.|DotNet\.(DesktopRuntime|Runtime|AspNetCore|HostingBundle)|EdgeWebView2Runtime$|DirectX$|Edge$|GameInput$)' -or
        $id -match '^ARP\\Machine\\[^\\]+\\Microsoft Edge( Update|WebView)?$' -or
        $name -match '(?i)Visual C\+\+.*(Redist|Runtime)|Windows Desktop Runtime|\.NET (Desktop |Core )?Runtime|ASP\.NET Core .*(Runtime|Shared Framework|Hosting Bundle)|WebView2 Runtime|DirectX|^Microsoft Edge( Update)?$|^Microsoft (Update Health Tools|GameInput)$')
}


function Get-WinForgeWingetPackageCaution {
    <#
    Um aviso curto para o que a lista de desinstalar oferece e costuma ser necessário: drivers instalados como programa.
    Vazio para o resto. Nada é impedido: a pessoa decide, mas sabe o que está marcando. (As bibliotecas que outros
    programas usam nem entram na lista: Test-WinForgeWingetUninstallBlocked.)
    #>
    param ([Parameter(Mandatory)]$Package)

    $name = [string](Get-WinForgeJsonValue -Object $Package -Name "Nome" -Default "")

    # Ferramentas de desenvolvimento (SDK, pacotes de destino) e programas "de drivers" (atualizadores, desinstaladores)
    # não são drivers.
    if ($name -match '(?i)\bSDK\b|targeting pack|booster|driver easy|uninstaller|support assistant|updater') { return "" }

    # "^AMD S\w+$" é o pacote do Adrenalin, que leva o driver de vídeo junto (o nome não tem mais nada).
    if ($name -match '(?i)\bdrivers?\b|chipset|management engine|serial io|rapid storage|bluetooth|wireless|wi-?fi|touchpad|adrenalin|^AMD S\w+$') {
        return (Get-WinForgeText 'driver de um aparelho do PC')
    }

    return ""
}


function Read-WinForgeWingetList {
    <#
    O "winget list", lido e entendido num lugar só: Rows (as linhas da tabela), ExitCode, Text e Lines. Toda leitura com
    linhas guarda os IDs para as listas de instalar dizerem "já instalado" (Get-WinForgeInstalledWingetIds, por 2 minutos):
    Listar programas instalados e Desinstalar programas, que leem a lista inteira, deixam a leitura pronta para Buscar e
    instalar e Instalar programas essenciais logo depois, que não leem de novo. -Echo: a tabela vai também para os
    detalhes técnicos. Lança o erro quando o winget nem roda.
    #>
    param ([switch]$Echo)

    $listing = Invoke-WinForgeCapture -FilePath "winget" -Arguments @("list", "--accept-source-agreements") -Echo:$Echo
    $rows = @(ConvertFrom-WinForgeWingetTable -Lines $listing.Lines)

    if ($rows.Count -gt 0) {
        $ids = New-Object 'System.Collections.Generic.HashSet[string]'
        foreach ($row in $rows) { [void]$ids.Add(([string]$row.Id).ToLowerInvariant()) }
        $script:WinForgeInstalledIdsCache = [PSCustomObject]@{ At = (Get-Date); Ids = $ids }
    }

    return [PSCustomObject]@{ Rows = $rows; ExitCode = [int]$listing.ExitCode; Text = [string]$listing.Text; Lines = @($listing.Lines) }
}


function Get-WinForgeInstalledWingetIds {
    <#
    Os IDs (em minúsculas) do que o winget vê instalado, para as listas de instalar dizerem "já instalado". O "winget
    list" leva alguns segundos: a leitura (de qualquer tela, Read-WinForgeWingetList) vale por 2 minutos e é descartada
    quando o WinForge instala, atualiza ou desinstala algo. $null quando o winget não respondeu: aí as listas ficam sem
    a marca, como antes.
    #>
    param ([string]$Activity = (Get-WinForgeText 'Lendo os programas instalados'))

    $cache = $script:WinForgeInstalledIdsCache
    if ($null -ne $cache -and ((Get-Date) - $cache.At).TotalSeconds -lt 120) { return ,$cache.Ids }

    Write-Progress -Activity $Activity -Status (Get-WinForgeText 'conferindo o que já está instalado')

    try {
        $listing = Read-WinForgeWingetList
    }
    catch {
        return $null
    }
    finally {
        Write-Progress -Activity $Activity -Completed
    }

    if (@($listing.Rows).Count -eq 0) { return $null }

    return ,$script:WinForgeInstalledIdsCache.Ids
}


function Test-WinForgeWingetIdInstalled {
    # Se o ID está entre os instalados lidos por Get-WinForgeInstalledWingetIds (sem a leitura, $false).
    param (
        $Installed,
        [string]$Id
    )

    return ($null -ne $Installed -and $Installed.Contains(([string]$Id).ToLowerInvariant()))
}


function Clear-WinForgeInstalledWingetIdsCache {
    # Outras telas que mudam o que está instalado (remover aplicativos, restaurar um backup) descartam a leitura guardada.
    $script:WinForgeInstalledIdsCache = $null
}


function Write-WinForgeWingetOutcomeLine {
    # A linha de um pacote depois de instalar, atualizar ou desinstalar: "Zeta: desinstalado.", "Zeta: atualizado para a
    # versão 2.0.", "Zeta: instalado, mas termina na próxima reinicialização.", "Zeta: continua instalado."
    param (
        [Parameter(Mandatory)][ValidateSet("Install", "Upgrade", "Uninstall")][string]$Operation,
        [string]$Name,
        [Parameter(Mandatory)]$Result,
        [string]$Available = ""
    )

    $verbs = Get-WinForgeWingetVerbs -Operation $Operation

    if ($Result.Kind -eq "Ok" -and [string]::IsNullOrWhiteSpace($Result.Detail)) {
        $done = $(if ($Operation -eq "Upgrade" -and $Available) { (Get-WinForgeText 'atualizado para a versão {0}' "$Available") } else { $verbs.One })
        Write-WinForgeStatus -Type Success -Message "${Name}: $done."
    }
    elseif ($Result.Kind -eq "Ok") {
        Write-WinForgeStatus -Type Success -Message "${Name}: $($Result.Detail)."
    }
    elseif ($Result.Kind -eq "Warning") {
        Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText '{0}: {1}, mas {2}.' "${Name}" "$($verbs.One)" "$($Result.Detail)")
    }
    else {
        Write-WinForgeStatus -Type Error -Message "${Name}: $($Result.Detail)."
    }
}


function Get-WinForgeTruncatedPrefix {
    # O começo de um texto que o winget cortou com reticências ("Contoso.Ferramenta.Com…" vira "Contoso.Ferramenta.Com").
    # Um texto sem reticências volta igual.
    param ([string]$Text)

    $value = [string]$Text

    if ($value.EndsWith([string][char]0x2026)) { return $value.Substring(0, $value.Length - 1) }
    if ($value.EndsWith("...")) { return $value.Substring(0, $value.Length - 3) }

    return $value
}


function Test-WinForgeWingetTextMatch {
    # Se dois textos da tabela do winget (IDs ou nomes) são o mesmo, sem diferenciar maiúsculas; um texto cortado com
    # reticências vale pelo começo.
    param (
        [string]$Listed,
        [string]$Wanted
    )

    if ([string]::IsNullOrWhiteSpace($Listed) -or [string]::IsNullOrWhiteSpace($Wanted)) { return $false }

    $listedCut = Test-WinForgeWingetIdTruncated -Id $Listed
    $wantedCut = Test-WinForgeWingetIdTruncated -Id $Wanted
    $a = (Get-WinForgeTruncatedPrefix -Text $Listed).Trim()
    $b = (Get-WinForgeTruncatedPrefix -Text $Wanted).Trim()

    if (-not $listedCut -and -not $wantedCut) { return [string]::Equals($a, $b, [StringComparison]::OrdinalIgnoreCase) }
    if ($a.Length -eq 0 -or $b.Length -eq 0) { return $false }
    if ($listedCut -and $b.StartsWith($a, [StringComparison]::OrdinalIgnoreCase)) { return $true }
    if ($wantedCut -and $a.StartsWith($b, [StringComparison]::OrdinalIgnoreCase)) { return $true }

    return $false
}


function Test-WinForgeWingetPackageListed {
    <#
    Se um pacote ainda aparece nas linhas do "winget list": pelo ID (inteiro, ou cortado com reticências pela tabela) ou,
    para um pacote que veio de uma fonte (winget, Microsoft Store), pelo nome numa linha com ID local (ARP\, MSIX\), que é
    como o winget o mostra quando, naquela consulta, não conseguiu associá-lo à fonte. Na dúvida, aparece.
    #>
    param (
        [Parameter(Mandatory)]$Package,
        [AllowEmptyCollection()][object[]]$Rows = @()
    )

    $id = [string](Get-WinForgeJsonValue -Object $Package -Name "Id" -Default "")
    $name = [string](Get-WinForgeJsonValue -Object $Package -Name "Nome" -Default "")
    $fromSource = ($id -notmatch '^(ARP|MSIX)\\')

    foreach ($row in @($Rows | Where-Object { $null -ne $_ })) {
        $rowId = [string](Get-WinForgeJsonValue -Object $row -Name "Id" -Default "")

        if (Test-WinForgeWingetTextMatch -Listed $rowId -Wanted $id) { return $true }

        if ($fromSource -and $rowId -match '^(ARP|MSIX)\\' -and (Test-WinForgeWingetTextMatch -Listed ([string](Get-WinForgeJsonValue -Object $row -Name "Nome" -Default "")) -Wanted $name)) {
            return $true
        }
    }

    return $false
}


function Get-WinForgeWingetInstalledRows {
    # O "winget list" lido de novo (a leitura guardada para as listas de instalar é descartada), para conferir o que saiu.
    # $null quando o winget não devolveu uma tabela legível: sem ela, nada pode ser dado como desinstalado.
    param ([string]$Activity = (Get-WinForgeText 'Desinstalando programas'))

    $script:WinForgeInstalledIdsCache = $null
    Write-Progress -Activity $Activity -Status (Get-WinForgeText 'conferindo o que saiu')

    try {
        $listing = Read-WinForgeWingetList
        $rows = @($listing.Rows)
    }
    catch {
        return $null
    }

    if ($rows.Count -eq 0) {
        # Vazia só com "nenhum pacote instalado" (0x8A150014). Um cabeçalho sem linhas, num PC que sempre tem programas, é
        # uma tabela que este código não leu (um formato novo do winget, uma saída cortada): dar tudo como desinstalado
        # seria mentir, então a conferência fica sem resposta.
        if ([int]$listing.ExitCode -eq -1978335212) { return ,@() }

        return $null
    }

    return ,$rows
}


function Wait-WinForgeUninstallResults {
    <#
    A conferência depois de desinstalar: um programa só conta como desinstalado quando sai da lista do winget. O código de
    saída sozinho não basta: muitos desinstaladores se copiam para a pasta temporária e devolvem "sucesso" na hora,
    enquanto ainda apagam o programa ou enquanto a janela deles espera a pessoa (que pode cancelar nela). Results: o
    resultado do código de saída de cada pacote, na ordem de Packages (Data.NotRun: o comando nem rodou). Devolve o
    resultado final de cada um:
    - saiu da lista: Ok (Warning com RebootRequired, se o desinstalador pediu reinício; Ok "já não está instalado", se o
      winget não o achou);
    - continua na lista depois de pedir reinício: Warning com RebootRequired (sai no próximo reinício);
    - continua na lista depois de um código de sucesso: espera um pouco e confere de novo (WinForgeUninstallRecheckDelays);
      se continuar, avisa e pergunta se confere de novo (a pessoa pode estar terminando na janela do desinstalador); por
      fim, Failed "continua instalado";
    - continua na lista depois de um erro: Failed com o motivo do erro;
    - a lista não pôde ser lida: Failed, porque nada pode ser dado como desinstalado sem ela.
    Nada é apagado à mão (pastas, registro): quem remove é sempre o desinstalador do próprio programa.
    #>
    param (
        [Parameter(Mandatory)][object[]]$Packages,
        [Parameter(Mandatory)][object[]]$Results,
        [string]$Activity = (Get-WinForgeText 'Desinstalando programas')
    )

    $count = @($Packages).Count
    $ran = @(for ($i = 0; $i -lt $count; $i++) { -not (Test-WinForgeResultFlag -Result $Results[$i] -Name "NotRun") })

    if (@($ran | Where-Object { $_ }).Count -eq 0) { return $Results }

    # O que o desinstalador deu como feito (sucesso, sem pedir reinício) e ainda aparece na lista.
    $getWaiting = {
        param ($Current)

        if ($null -eq $Current) { return }

        for ($i = 0; $i -lt $count; $i++) {
            if ($ran[$i] -and $Results[$i].Kind -eq "Ok" -and (Test-WinForgeWingetPackageListed -Package $Packages[$i] -Rows $Current)) { $i }
        }
    }

    $rows = Get-WinForgeWingetInstalledRows -Activity $Activity
    $waiting = @(& $getWaiting $rows)

    foreach ($delay in @($script:WinForgeUninstallRecheckDelays)) {
        if ($waiting.Count -eq 0) { break }

        Write-Progress -Activity $Activity -Status (Get-WinForgeText 'esperando o desinstalador terminar')
        Start-Sleep -Seconds ([int]$delay)
        $rows = Get-WinForgeWingetInstalledRows -Activity $Activity
        $waiting = @(& $getWaiting $rows)
    }

    # A janela do desinstalador pode estar esperando a pessoa: ela termina lá e manda conferir de novo.
    for ($ask = 0; $ask -lt 5 -and $waiting.Count -gt 0; $ask++) {
        $names = Join-WinForgeList -Items @($waiting | ForEach-Object { [string]$Packages[$_].Nome })
        $still = $(if ($waiting.Count -eq 1) { (Get-WinForgeText 'ainda está instalado') } else { (Get-WinForgeText 'ainda estão instalados') })

        Write-WinForgeStatus -Type Warning -Notice -Message (Get-WinForgeText '{0} {1}. Se abriu uma janela de desinstalação, conclua nela.' "$names" "$still")

        if (-not (Confirm-WinForgeAction -Message (Get-WinForgeText 'Conferir de novo?') -DefaultKey S -YesLabel (Get-WinForgeText 'Conferir de novo') -NoLabel (Get-WinForgeText 'Deixar como está'))) { break }

        $rows = Get-WinForgeWingetInstalledRows -Activity $Activity
        $waiting = @(& $getWaiting $rows)
    }

    $final = @()

    for ($i = 0; $i -lt $count; $i++) {
        $result = $Results[$i]

        if ($ran[$i]) {
            if ($null -eq $rows) {
                if ($result.Kind -ne "Failed") { $result = New-WinForgeResult -Kind Failed -Detail (Get-WinForgeText 'não foi possível conferir se saiu') }
            }
            elseif (Test-WinForgeWingetPackageListed -Package $Packages[$i] -Rows $rows) {
                # Pedir reinício e continuar na lista é o esperado; um erro do winget já diz o motivo.
                if ($result.Kind -eq "Ok") { $result = New-WinForgeResult -Kind Failed -Detail (Get-WinForgeText 'continua instalado') }
            }
            elseif ($result.Kind -eq "Failed") {
                # Saiu da lista apesar do erro (o desinstalador avisou algo, mas removeu; ou o winget nem o achou mais).
                $notFound = ([int](Get-WinForgeResultData -Result $result -Name "ExitCode") -eq -1978335212)
                $result = $(if ($notFound) { New-WinForgeResult -Kind Ok -Detail (Get-WinForgeText 'já não está instalado') } else { New-WinForgeResult -Kind Ok })
            }

            $result.Etapa = [string]$Packages[$i].Nome
        }

        $final += $result
    }

    return $final
}


function Invoke-WinForgeWingetUserScope {
    <#
    O que fazer quando o winget recusou um pacote por ele ser só da conta da pessoa (0x8A15007D): a recusa vem antes de
    qualquer mudança, e o mesmo comando roda de novo com a conta dela, sem Administrador (Invoke-WinForgeLimited), quando
    dá (Get-WinForgeLimitedRunState). Quando não dá, o resultado diz por quê, com o que fazer. Name: o nome do programa;
    Arguments: os do winget. Devolve o WinForge.Result do pacote (Data.ExitCode e, quando rodou sem Administrador,
    Data.Unelevated).
    Nunca roda como Administrador o desinstalador gravado no registro da conta: é o que o winget bloqueia, porque qualquer
    programa da conta pode trocá-lo.
    #>
    param (
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string[]]$Arguments
    )

    $code = "0x{0:X8}" -f $script:WinForgeWingetUserScopeCode
    $failed = { param ($Text) New-WinForgeResult -Kind Failed -Detail (Get-WinForgeText '{0} — erro {1}' "$Text" "$code") -Data @{ ExitCode = $script:WinForgeWingetUserScopeCode } }

    switch (Get-WinForgeLimitedRunState) {
        "OtherAccount" {
            # O programa é da conta que abriu o WinForge como Administrador, e não de quem usa o PC.
            return (& $failed (Get-WinForgeText 'o programa foi instalado só para a conta {0}, e o winget não o altera como Administrador; entre no Windows com essa conta para continuar' "$([Environment]::UserDomainName)\$([Environment]::UserName)"))
        }
        "NoLimitedToken" {
            return (& $failed (Get-WinForgeText 'o programa foi instalado só para o seu usuário, e o winget não o altera como Administrador; com o Controle de Conta de Usuário desligado, o WinForge não consegue rodá-lo sem Administrador'))
        }
        "NotElevated" {
            # Sem Administrador, o winget não recusa por isso: o código vale como veio.
            $result = Get-WinForgeWingetExitResult -ExitCode $script:WinForgeWingetUserScopeCode
            if ($result.Data -is [hashtable]) { $result.Data["ExitCode"] = $script:WinForgeWingetUserScopeCode }
            return $result
        }
    }

    Write-WinForgeStatus -Type Info -Message (Get-WinForgeText '{0} foi instalado só para o seu usuário, e o winget não o altera como Administrador. Tentando de novo sem Administrador.' "$Name")
    Write-Host ""
    Write-WinForgeCommand -Command "winget $($Arguments -join ' ')"
    Write-Host ""

    $run = Invoke-WinForgeLimited -FilePath "winget" -Arguments $Arguments
    Write-Host ""

    if (-not $run.Ran) {
        return (& $failed (Get-WinForgeText 'o programa foi instalado só para o seu usuário, e não foi possível rodar o winget sem Administrador ({0}); para continuar sem Administrador, {1}' "$($run.Reason)" "$(Get-WinForgeUnelevatedHint)"))
    }

    if ([int]$run.ExitCode -eq $script:WinForgeWingetUserScopeCode) {
        # A mesma recusa, agora sem Administrador: o Windows não deu à tarefa a versão da conta sem Administrador.
        return (& $failed (Get-WinForgeText 'o programa foi instalado só para o seu usuário, e o winget recusou também sem Administrador'))
    }

    $result = Get-WinForgeWingetExitResult -ExitCode ([int]$run.ExitCode)

    if ($result.Data -is [hashtable]) {
        $result.Data["ExitCode"] = [int]$run.ExitCode
        $result.Data["Unelevated"] = $true
    }

    return $result
}


function Invoke-WinForgeWingetPackages {
    <#
    Instala, atualiza ou desinstala uma lista de pacotes, um por vez, com resumo no final.
    Packages: objetos com Id e Nome (e, para atualizar, Disponivel: a versão nova; para desinstalar, Versoes: quantas
    versões do mesmo ID estão instaladas). Devolve um WinForge.Result: Ok quando todos deram certo (com RebootRequired se
    algum instalador pediu reinício), Warning quando parte falhou e Failed quando nenhum deu certo. Desinstalar só dá
    certo quando o programa sai da lista do winget (Wait-WinForgeUninstallResults), não só porque o comando terminou.
    #>
    param (
        [Parameter(Mandatory)]
        [ValidateSet("Install", "Upgrade", "Uninstall")]
        [string]$Operation,

        [Parameter(Mandatory)]
        [object[]]$Packages,

        [switch]$WingetSourceOnly
    )

    $verbs = Get-WinForgeWingetVerbs -Operation $Operation
    $outcomes = @()
    $position = 0

    # O que está instalado muda daqui em diante: a próxima lista lê de novo.
    $script:WinForgeInstalledIdsCache = $null

    try {
        foreach ($package in $Packages) {
            $position++
            $name = [string]$package.Nome
            $source = $(if ($Operation -eq "Install") { ([string](Get-WinForgeJsonValue -Object $package -Name "Fonte" -Default "")).Trim() } else { "" })
            $allVersions = ($Operation -eq "Uninstall" -and [int](Get-WinForgeJsonValue -Object $package -Name "Versoes" -Default 1) -gt 1)
            $arguments = Get-WinForgeWingetArguments -Operation $Operation -PackageId $package.Id -WingetSourceOnly:$WingetSourceOnly -Source $source -AllVersions:$allVersions

            # O andamento vai para a barra de progresso (na janela, o texto ao lado da barra). Um desinstalador pode abrir a
            # própria janela, que espera a pessoa.
            $status = (Get-WinForgeText '{0} de {1}: {2}' "$position" "$($Packages.Count)" "$name")
            if ($Operation -eq "Uninstall") { $status += (Get-WinForgeText ' · se abrir uma janela, conclua nela') }
            Write-Progress -Activity $verbs.Activity -Status $status -PercentComplete ([int](($position - 1) * 100 / $Packages.Count))

            if (Test-WinForgeWingetIdTruncated -Id $package.Id) {
                # O comando com o ID cortado só daria "pacote não encontrado": a linha diz o que fazer.
                $result = New-WinForgeResult -Kind Failed -Detail $verbs.Truncated -Data @{ NotRun = $true }
            }
            else {
                Write-Host ""
                Write-WinForgeCommand -Command "winget $($arguments -join ' ')"
                Write-Host ""

                $exitCode = Invoke-WinForgeNative -FilePath "winget" -Arguments $arguments -IgnoreExitCode -PassThru

                if ([int]$exitCode -eq $script:WinForgeWingetUserScopeCode) {
                    # Só da conta da pessoa: o winget não o altera como Administrador, e o comando roda de novo sem elevação.
                    $result = Invoke-WinForgeWingetUserScope -Name $name -Arguments $arguments
                }
                else {
                    $result = Get-WinForgeWingetExitResult -ExitCode $exitCode
                    if ($result.Data -is [hashtable]) { $result.Data["ExitCode"] = $exitCode }
                }

                Write-Host ""
            }

            $result.Etapa = $name

            # Ao desinstalar, a linha de cada programa espera a conferência da lista.
            if ($Operation -ne "Uninstall") {
                Write-WinForgeWingetOutcomeLine -Operation $Operation -Name $name -Result $result -Available ([string](Get-WinForgeJsonValue -Object $package -Name "Disponivel" -Default ""))
            }

            $outcomes += $result
        }

        if ($Operation -eq "Uninstall") {
            $outcomes = @(Wait-WinForgeUninstallResults -Packages $Packages -Results $outcomes -Activity $verbs.Activity)

            foreach ($result in $outcomes) {
                Write-WinForgeWingetOutcomeLine -Operation $Operation -Name ([string]$result.Etapa) -Result $result
            }
        }
    }
    finally {
        Write-Progress -Activity $verbs.Activity -Completed
    }

    # No console, a saída do winget se mistura às mensagens: o resumo junta tudo no fim. Na janela, cada programa já tem a
    # sua linha no resumo da execução, e a tabela só repetiria as mesmas linhas.
    if ($Packages.Count -gt 1 -and -not (Test-WinForgeGuiMode)) {
        Write-WinForgeSection -Title (Get-WinForgeText 'Resumo')
        Write-WinForgeResultTable -Results $outcomes
    }

    $failed = @($outcomes | Where-Object { $_.Kind -eq "Failed" })

    # SucceededIds: os pacotes que deram certo. ChangedIds: os que o winget de fato mudou (sem "já estava instalado" nem
    # "já está na versão mais recente"): é o que o Histórico anota.
    $data = @{
        SucceededIds = @(for ($i = 0; $i -lt $outcomes.Count; $i++) { if ($outcomes[$i].Kind -ne "Failed") { [string]$Packages[$i].Id } })
        ChangedIds   = @(for ($i = 0; $i -lt $outcomes.Count; $i++) { if ($outcomes[$i].Kind -eq "Warning" -or ($outcomes[$i].Kind -eq "Ok" -and -not $outcomes[$i].Detail)) { [string]$Packages[$i].Id } })
        # O motivo do primeiro que falhou: a faixa de um programa só que não deu certo diz qual foi.
        Reason       = $(if ($failed.Count -gt 0) { [string]$failed[0].Detail } else { "" })
    }

    if (@($outcomes | Where-Object { Test-WinForgeResultFlag -Result $_ -Name "RebootRequired" }).Count -gt 0) {
        $data["RebootRequired"] = $true
    }

    # RebootStarted: algum instalador reinicia o PC por conta própria (Request-WinForgeProgramsRestart não oferece).
    if (@($outcomes | Where-Object { Test-WinForgeResultFlag -Result $_ -Name "RebootStarted" }).Count -gt 0) {
        $data["RebootStarted"] = $true
    }

    if ($failed.Count -eq 0) {
        $detail = Format-WinForgeCount -Count $outcomes.Count -One (Get-WinForgeText 'programa {0}' "$($verbs.One)") -Many (Get-WinForgeText 'programas {0}' "$($verbs.Many)")

        if ($outcomes.Count -eq 1) {
            $single = $outcomes[0]
            $detail = $(if ($single.Kind -eq "Ok" -and $single.Detail) { "$($single.Etapa): $($single.Detail)" } else { "$($single.Etapa) $($verbs.One)" })
        }

        return (New-WinForgeResult -Kind Ok -Detail $detail -Data $data)
    }

    $names = Join-WinForgeList -Items @($failed | ForEach-Object { [string]$_.Etapa })

    if ($failed.Count -eq $outcomes.Count) {
        if ($outcomes.Count -eq 1) {
            return (New-WinForgeResult -Kind Failed -Detail (Get-WinForgeText '{0} não foi {1}: {2}' "$names" "$($verbs.One)" "$($failed[0].Detail)") -Data $data)
        }

        return (New-WinForgeResult -Kind Failed -Detail (Get-WinForgeText 'nenhum programa foi {0}: {1}' "$($verbs.One)" "$names") -Data $data)
    }

    $verbText = $(if ($failed.Count -eq 1) { (Get-WinForgeText 'não foi {0}' "$($verbs.One)") } else { (Get-WinForgeText 'não foram {0}' "$($verbs.Many)") })

    return (New-WinForgeResult -Kind Warning -Detail (Get-WinForgeText '{0} de {1} {2}: {3}' "$($failed.Count)" "$($outcomes.Count)" "${verbText}" "$names") -Data $data)
}


function Set-WinForgeWingetPackagesView {
    <#
    A faixa da janela depois de instalar ou desinstalar pelo winget: o título diz quantos, e a frase, quais. Ao instalar,
    conta como instalado o que o winget de fato mudou (ChangedIds) e não estava no PC antes (Installed, lido antes da
    lista); o que já estava e ganhou versão nova conta como atualizado; o que já estava e não mudou não conta. Com
    ressalvas, o título diz quantos deram certo, e a frase, quais não deram. Depois de desinstalar, o botão leva à busca de
    restos. A falha fica com a faixa de sempre ("7-Zip não foi instalado: ..."), que já diz qual e por quê. Devolve o
    próprio resultado. Quando nenhum deu certo, o título diz isso, e a frase, o motivo (de um programa só) ou onde estão os
    motivos (de vários).
    #>
    param (
        [Parameter(Mandatory)][ValidateSet("Install", "Uninstall")][string]$Operation,
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Packages,
        $Result,
        $Installed = $null
    )

    if ($null -eq $Result -or $Packages.Count -eq 0) { return $Result }

    if ($Result.Kind -eq "Failed") {
        $one = ($Packages.Count -eq 1)
        $reason = ([string](Get-WinForgeResultData -Result $Result -Name "Reason")).Trim().TrimEnd(".")
        $headline = $(if ($Operation -eq "Install") { $(if ($one) { (Get-WinForgeText 'O programa não foi instalado') } else { (Get-WinForgeText 'Nenhum programa foi instalado') }) } else { $(if ($one) { (Get-WinForgeText 'O programa não foi desinstalado') } else { (Get-WinForgeText 'Nenhum programa foi desinstalado') }) })
        $note = $(if ($one -and $reason) { "$([string]$Packages[0].Nome): $reason." } else { (Get-WinForgeText 'O motivo de cada um está no resumo.') })

        return (Set-WinForgeResultView -Result $Result -Headline $headline -Note $note)
    }

    if ($Result.Kind -notin @("Ok", "Warning")) { return $Result }

    $succeeded = @(Get-WinForgeResultData -Result $Result -Name "SucceededIds")
    $changed = @(Get-WinForgeResultData -Result $Result -Name "ChangedIds")
    $done = @($Packages | Where-Object { $succeeded -contains [string]$_.Id })
    $failed = @($Packages | Where-Object { $succeeded -notcontains [string]$_.Id } | ForEach-Object { [string]$_.Nome })
    $verbs = Get-WinForgeWingetVerbs -Operation $Operation
    $next = $(if ($Operation -eq "Uninstall") { "cleanup.leftovers" } else { "" })
    $nextLabel = $(if ($Operation -eq "Uninstall") { (Get-WinForgeText 'Procurar restos') } else { "" })

    if ($done.Count -eq 0) { return $Result }

    if ($failed.Count -gt 0) {
        $verbText = $(if ($failed.Count -eq 1) { (Get-WinForgeText 'não foi {0}' "$($verbs.One)") } else { (Get-WinForgeText 'não foram {0}' "$($verbs.Many)") })
        $reason = $(if ($failed.Count -eq 1) { (Get-WinForgeText 'o motivo está no resumo') } else { (Get-WinForgeText 'o motivo de cada um está no resumo') })

        return (Set-WinForgeResultView -Result $Result -Headline (Get-WinForgeText '{0} de {1} programas {2}' "$($done.Count)" "$($Packages.Count)" "$($verbs.Many)") `
                -Note "$(Join-WinForgeShortList -Items $failed) ${verbText}; $reason." -Next $next -NextLabel $nextLabel)
    }

    if ($Operation -eq "Uninstall") {
        $names = @($done | ForEach-Object { [string]$_.Nome })

        return (Set-WinForgeResultView -Result $Result -Headline (Format-WinForgeCount -Count $names.Count -One (Get-WinForgeText 'programa desinstalado') -Many (Get-WinForgeText 'programas desinstalados')) `
                -Note "$(Join-WinForgeShortList -Items $names)." -Next $next -NextLabel $nextLabel)
    }

    $new = @($done | Where-Object { $changed -contains [string]$_.Id -and -not (Test-WinForgeWingetIdInstalled -Installed $Installed -Id $_.Id) } | ForEach-Object { [string]$_.Nome })
    $updated = @($done | Where-Object { $changed -contains [string]$_.Id -and (Test-WinForgeWingetIdInstalled -Installed $Installed -Id $_.Id) } | ForEach-Object { [string]$_.Nome })
    $same = @($done | Where-Object { $changed -notcontains [string]$_.Id } | ForEach-Object { [string]$_.Nome })
    $parts = @()

    if ($new.Count -gt 0) {
        $headline = Format-WinForgeCount -Count $new.Count -One (Get-WinForgeText 'programa instalado') -Many (Get-WinForgeText 'programas instalados')
        $parts += "$(Join-WinForgeShortList -Items $new)."
        if ($updated.Count -gt 0) { $parts += $(if ($updated.Count -eq 1) { (Get-WinForgeText 'Atualizado: {0}.' "$(Join-WinForgeShortList -Items $updated)") } else { (Get-WinForgeText 'Atualizados: {0}.' "$(Join-WinForgeShortList -Items $updated)") }) }
    }
    elseif ($updated.Count -gt 0) {
        $headline = Format-WinForgeCount -Count $updated.Count -One (Get-WinForgeText 'programa atualizado') -Many (Get-WinForgeText 'programas atualizados')
        $parts += "$(Join-WinForgeShortList -Items $updated)."
    }
    else {
        # Nada mudou: o que foi marcado já estava no PC, e o winget não tinha versão nova.
        $headline = (Get-WinForgeText 'Nada para instalar')
        $parts += (Get-WinForgeText '{0} já {1}.' "$(Join-WinForgeShortList -Items $same)" "$(if ($same.Count -eq 1) { (Get-WinForgeText 'está instalado') } else { (Get-WinForgeText 'estão instalados') })")
        $same = @()
    }

    if ($same.Count -gt 0) { $parts += $(if ($same.Count -eq 1) { (Get-WinForgeText 'Já estava instalado: {0}.' "$(Join-WinForgeShortList -Items $same)") } else { (Get-WinForgeText 'Já estavam instalados: {0}.' "$(Join-WinForgeShortList -Items $same)") }) }

    return (Set-WinForgeResultView -Result $Result -Headline $headline -Note ($parts -join " "))
}


function Request-WinForgeProgramsRestart {
    <#
    Depois de instalar ou desinstalar, quando algum instalador pediu o reinício para terminar (Data.RebootRequired):
    oferece reiniciar ali mesmo, com o Depois como padrão, como os recursos opcionais e as Atualizações. Não oferece
    quando o próprio instalador já reinicia o PC (Data.RebootStarted) nem dentro do Otimizar (Test-WinForgeNestedAction),
    que tem o próprio fim. Recusado, a faixa continua pedindo o reinício.
    #>
    param (
        [Parameter(Mandatory)][ValidateSet("Install", "Uninstall")][string]$Operation,
        $Result
    )

    if ($null -eq $Result -or $Result.Kind -notin @("Ok", "Warning")) { return }
    if (-not (Test-WinForgeResultFlag -Result $Result -Name "RebootRequired")) { return }
    if ((Test-WinForgeResultFlag -Result $Result -Name "RebootStarted") -or (Test-WinForgeNestedAction)) { return }

    if ($Operation -eq "Install") {
        Request-WinForgeInstallRestart -What (Get-WinForgeText 'os programas') -Later (Get-WinForgeText 'Os programas terminam de instalar quando você reiniciar o PC.')
        return
    }

    Request-WinForgeRestartOffer -Reason (Get-WinForgeText 'Para terminar de desinstalar os programas, o Windows precisa reiniciar.') `
        -Comment (Get-WinForgeText 'Reinicialização solicitada pelo WinForge para terminar de desinstalar programas.') `
        -DeclinedMessage (Get-WinForgeText 'Reinicialização não iniciada. Os programas terminam de sair quando você reiniciar o PC.') `
        -Fallback (Get-WinForgeText 'Reinicie o PC para terminar a desinstalação.')
}


# ---------------------------------------------------------------------------
# Atualização
# ---------------------------------------------------------------------------

function Write-WinForgeWingetUpgradeList {
    # A lista do que tem atualização, no resumo da janela (os detalhes técnicos ficam recolhidos durante a pergunta):
    # "Google Chrome : 120.0 para 121.0". Até $Limit programas; o resto vira uma contagem.
    param (
        [AllowEmptyCollection()][object[]]$Packages = @(),
        [int]$Limit = 12
    )

    Write-WinForgeSection -Title (Get-WinForgeText 'Atualizações disponíveis')

    foreach ($package in @($Packages | Select-Object -First $Limit)) {
        $name = [string]$package.Nome
        if ($name.Length -gt 48) { $name = $name.Substring(0, 45) + "..." }

        $versions = $(if ([string]::IsNullOrWhiteSpace([string]$package.Disponivel)) { [string]$package.Versao } else { (Get-WinForgeText '{0} para {1}' "$($package.Versao)" "$($package.Disponivel)") })
        Write-WinForgeKeyValue -Label $name -Value $versions
    }

    $rest = @($Packages).Count - $Limit

    if ($rest -gt 0) {
        Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'E mais {0}.' "$(Format-WinForgeCount -Count $rest -One (Get-WinForgeText 'programa') -Many (Get-WinForgeText 'programas'))")
    }
}


# Quanto a consulta do "winget upgrade" em segundo plano (Start-WinForgeWingetUpgradeRead) pode levar, contado do começo
# dela. A primeira do dia atualiza a lista de programas da fonte e, com a rede lenta, demora; sem resposta até lá (um
# proxy que segura a conexão, a fonte travada, uma pergunta do winget esperando resposta), quem esperava segue sem ela,
# em vez de ficar parado.
$script:WinForgeWingetReadTimeoutSec = 120


function Start-WinForgeWingetUpgradeRead {
    <#
    Começa em segundo plano a consulta dos programas com versão nova, sem esperar por ela: ela depende da rede e é
    demorada, e quem a pede faz outra coisa enquanto isso (o Verificar o PC lê o resto do PC; o Otimizar espera a pessoa
    nas telas do começo). É a consulta da tela Atualizar programas ("winget upgrade", que só lista, com o contrato da
    fonte aceito). Receive-WinForgeWingetUpgradeRead recebe a resposta, com prazo. Sem o winget, $null.
    #>
    if (-not (Test-WinForgeWinget)) { return $null }

    return (Start-WinForgeInBackground -ScriptBlock {
            $lines = New-Object System.Collections.Generic.List[string]
            $global:LASTEXITCODE = 0

            & winget upgrade --accept-source-agreements 2>&1 | ForEach-Object { $lines.Add((([string]$_) -replace "`0", "")) }

            [PSCustomObject]@{ ExitCode = $LASTEXITCODE; Lines = @($lines); Text = ($lines -join "`n") }
        })
}


function Receive-WinForgeWingetUpgradeRead {
    <#
    Espera a consulta de Start-WinForgeWingetUpgradeRead até o prazo ($script:WinForgeWingetReadTimeoutSec, contado do
    começo dela) e devolve Upgrade (ExitCode, Lines e Text, como Invoke-WinForgeCapture; $null sem resposta), TimedOut,
    Error e TimeoutSeconds. A espera continua interrompível pelo Parar; sem resposta no prazo, a consulta é largada e o
    winget, encerrado. Sem a tarefa (o winget sumiu entre a conferência de quem chama e o começo da consulta), sem resposta.
    #>
    param ([AllowNull()]$Task)

    if ($null -eq $Task) { return [PSCustomObject]@{ Upgrade = $null; TimedOut = $false; Error = ""; TimeoutSeconds = $script:WinForgeWingetReadTimeoutSec } }

    $received = Receive-WinForgeInBackground -Task $Task -TimeoutSeconds $script:WinForgeWingetReadTimeoutSec
    $upgrade = $(if ($received.Completed) { @($received.Output | Where-Object { $null -ne $_ }) | Select-Object -Last 1 } else { $null })

    return [PSCustomObject]@{ Upgrade = $upgrade; TimedOut = [bool]$received.TimedOut; Error = [string]$received.Error; TimeoutSeconds = $script:WinForgeWingetReadTimeoutSec }
}


function Get-WinForgeWingetUpgradePlan {
    <#
    Coleta a decisão do usuário sem instalar nada, para que o Otimizar possa perguntar tudo antes da
    parte automática. Action: Unavailable | NoUpdates | None | All | Ids. Packages: o que o winget listou (Nome, Id,
    Versao, Disponivel), vazio quando a tabela não pôde ser lida. Uma pergunta sem resposta (a entrada terminou) é "Não
    atualizar", e não uma falha do winget.
    -SkipBrowsers (o Otimizar): Edge, Chrome e Firefox saem da lista, porque a etapa dos navegadores os atualiza pelo
    atualizador de cada um (Test-WinForgeWingetBrowserId).
    -Read (o Otimizar): a consulta já começada em segundo plano (Start-WinForgeWingetUpgradeRead), recebida aqui com o
    prazo dela; sem resposta no prazo, ou com a consulta falhando, um erro, como o winget que não lista. Sem -Read, a
    consulta roda agora, como na tela Atualizar programas.
    #>
    param (
        [switch]$SkipBrowsers,
        $Read = $null
    )

    if (-not (Initialize-WinForgeWinget)) {
        return [PSCustomObject]@{ Action = "Unavailable"; Ids = @(); Packages = @() }
    }

    Write-WinForgeWingetUserWarning -Context Upgrade
    Write-Progress -Activity (Get-WinForgeText 'Procurando atualizações de programas') -Status (Get-WinForgeText 'consultando o winget')

    try {
        if ($null -eq $Read) {
            $upgrade = Invoke-WinForgeCapture -FilePath "winget" -Arguments @("upgrade", "--accept-source-agreements") -Echo
        }
        else {
            $received = Receive-WinForgeWingetUpgradeRead -Task $Read

            if ($received.TimedOut) { throw (Get-WinForgeText 'o Instalador de Aplicativo não respondeu em {0} segundos' "$($received.TimeoutSeconds)") }
            if ($null -eq $received.Upgrade) { throw $(if ($received.Error) { $received.Error } else { (Get-WinForgeText 'o winget não respondeu') }) }

            $upgrade = $received.Upgrade

            # O que o winget escreveu vai para os detalhes técnicos, como na consulta de agora (-Echo), de uma vez.
            $state = @{ Last = -1.0 }
            foreach ($line in @($upgrade.Lines)) { if (Test-WinForgeEchoLine -Line ([string]$line) -State $state) { Write-Host $line } }
        }
    }
    finally {
        Write-Progress -Activity (Get-WinForgeText 'Procurando atualizações de programas') -Completed
    }

    # Os marcados para ficar na versão atual (Atualizações > Manter programas na versão atual) não entram na lista: uma
    # linha diz quantos ficaram de fora.
    $held = Get-WinForgeWingetHeldCount -Lines $upgrade.Lines
    $heldText = $(if ($held -gt 0) { Format-WinForgeCount -Count $held -One (Get-WinForgeText 'programa com versão nova ficou de fora: está marcado para não atualizar (Atualizações > Manter programas na versão atual).') -Many (Get-WinForgeText 'programas com versão nova ficaram de fora: estão marcados para não atualizar (Atualizações > Manter programas na versão atual).') } else { "" })

    if (Test-WinForgeWingetNoUpgradeOutput -OutputText $upgrade.Text -ExitCode $upgrade.ExitCode) {
        Write-Host ""
        Write-WinForgeStatus -Type Success -Message (Get-WinForgeText 'Os programas que o winget reconhece estão em dia.')
        if ($heldText) { Write-WinForgeStatus -Type Info -Message $heldText }
        return [PSCustomObject]@{ Action = "NoUpdates"; Ids = @(); Packages = @(); Held = $held }
    }

    $codeText = (Get-WinForgeWingetExitResult -ExitCode $upgrade.ExitCode).Detail

    if ($upgrade.ExitCode -ne 0 -and [string]::IsNullOrWhiteSpace($upgrade.Text)) {
        throw (Get-WinForgeText 'o winget terminou sem dizer o motivo ({0})' "$codeText")
    }

    $available = @(ConvertFrom-WinForgeWingetTable -Lines $upgrade.Lines)

    if ($available.Count -eq 0 -and $upgrade.ExitCode -ne 0) {
        throw (Get-WinForgeText 'o winget não conseguiu listar as atualizações ({0})' "$codeText")
    }

    if ($SkipBrowsers -and $available.Count -gt 0) {
        $browsers = @($available | Where-Object { Test-WinForgeWingetBrowserId -Id ([string]$_.Id) })
        $available = @($available | Where-Object { -not (Test-WinForgeWingetBrowserId -Id ([string]$_.Id)) })

        if ($browsers.Count -gt 0 -and $available.Count -eq 0) {
            Write-Host ""
            Write-WinForgeStatus -Type Success -Message (Get-WinForgeText 'Os programas que o winget reconhece estão em dia; os navegadores têm a etapa deles.')
            if ($heldText) { Write-WinForgeStatus -Type Info -Message $heldText }
            return [PSCustomObject]@{ Action = "NoUpdates"; Ids = @(); Packages = @(); Held = $held }
        }
    }

    Write-Host ""

    if ($available.Count -gt 0) {
        Write-WinForgeWingetUpgradeList -Packages $available
        if ($heldText) { Write-WinForgeStatus -Type Info -Message $heldText }
        $options = @(
            @{ Key = "S"; Label = (Get-WinForgeText 'Atualizar todos ({0})' "$($available.Count)"); Accent = $true },
            @{ Key = "E"; Label = (Get-WinForgeText 'Escolher quais atualizar'); Description = (Get-WinForgeText 'marque os programas na lista') },
            @{ Key = "N"; Label = (Get-WinForgeText 'Não atualizar'); Exit = $true }
        )
    }
    else {
        # Sem tabela reconhecida (formato inesperado do winget): o que ele mostrou fica nos detalhes técnicos.
        Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'Não foi possível ler a lista do winget; ela está nos detalhes técnicos.')
        $options = @(
            @{ Key = "S"; Label = (Get-WinForgeText 'Atualizar tudo o que o winget oferecer'); Accent = $true },
            @{ Key = "E"; Label = (Get-WinForgeText 'Digitar os IDs'); Description = (Get-WinForgeText 'um ou mais IDs do winget, separados por vírgula') },
            @{ Key = "N"; Label = (Get-WinForgeText 'Não atualizar'); Exit = $true }
        )
    }

    # Só entram programas que o winget reconhece; o Windows Update e a Microsoft Store ficam nos outros itens da página
    # Atualizações. Um programa aberto pode não ser atualizado.
    if ($available.Count -gt 0) {
        Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Feche os programas da lista antes de atualizar.')
    }

    Write-Host ""

    while ($true) {
        try {
            $choice = Read-WinForgeChoice -Message (Get-WinForgeText 'O que deseja atualizar?') -TextPrompt (Get-WinForgeText 'Digite S, E ou N') -ShowMenu -Options $options
        }
        catch {
            Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Sem resposta: nenhum programa será atualizado.')
            return [PSCustomObject]@{ Action = "None"; Ids = @(); Packages = $available }
        }

        if ($choice -eq "N") {
            return [PSCustomObject]@{ Action = "None"; Ids = @(); Packages = $available }
        }

        if ($choice -eq "S") {
            return [PSCustomObject]@{ Action = "All"; Ids = @(); Packages = $available }
        }

        if ($available.Count -gt 0) {
            $listOptions = @(
                foreach ($package in $available) {
                    $versions = $(if ([string]::IsNullOrWhiteSpace([string]$package.Disponivel)) { [string]$package.Versao } else { (Get-WinForgeText '{0} para {1}' "$($package.Versao)" "$($package.Disponivel)") })
                    @{ Key = $package.Id; Label = $package.Nome; Description = "$($package.Id) · $versions" }
                }
            )

            # Cancelar a lista volta para a pergunta anterior: o botão diz "Voltar".
            $picked = Read-WinForgeMultiSelect -Message (Get-WinForgeText 'Quais programas atualizar?') -Options $listOptions -ConfirmLabel (Get-WinForgeText 'Atualizar') -CancelLabel (Get-WinForgeText 'Voltar')

            if ($null -eq $picked -or @($picked).Count -eq 0) {
                continue
            }

            return [PSCustomObject]@{ Action = "Ids"; Ids = @($picked); Packages = $available }
        }

        Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Para vários programas, separe os IDs por vírgula. Exemplo: Google.Chrome, Notepad++.Notepad++')

        $packageInput = Read-WinForgeText -Message (Get-WinForgeText 'Digite um ou mais IDs (vazio = voltar)')

        if ([string]::IsNullOrWhiteSpace($packageInput)) {
            continue
        }

        try {
            $packageIds = @(ConvertTo-WinForgeWingetPackageIdList -InputText $packageInput)
        }
        catch {
            Write-WinForgeStatus -Type Error -Message $_.Exception.Message
            continue
        }

        return [PSCustomObject]@{ Action = "Ids"; Ids = @($packageIds); Packages = $available }
    }
}


function Test-WinForgeWingetBrowserId {
    # Os IDs do winget dos navegadores que a etapa dos navegadores atualiza: o Edge, o Chrome estável e o Firefox
    # (inclusive o de um idioma, como Mozilla.Firefox.pt-BR). O Firefox ESR, o Beta e o Developer Edition ficam: a etapa
    # dos navegadores não os atualiza.
    param ([AllowEmptyString()][string]$Id)

    return ($Id -cmatch '^(Microsoft\.Edge|Google\.Chrome|Google\.Chrome\.EXE|Mozilla\.Firefox(\.[a-z]{2,3}(-[A-Za-z]{2,4})?)?)$')
}


function Invoke-WinForgeWingetUpgradePlan {
    # Executa a decisão de Get-WinForgeWingetUpgradePlan e devolve um WinForge.Result.
    param (
        [Parameter(Mandatory)]
        $Plan
    )

    switch ($Plan.Action) {
        "Unavailable" {
            return (Get-WinForgeWingetMissingResult)
        }
        "NoUpdates" {
            # Com programas marcados para não atualizar, "nenhum tem versão nova" não seria verdade: a frase diz quantos
            # ficaram de fora.
            $held = [int](Get-WinForgeJsonValue -Object $Plan -Name "Held" -Default 0)
            $note = $(if ($held -gt 0) { Format-WinForgeCount -Count $held -One (Get-WinForgeText 'programa marcado para não atualizar ficou de fora.') -Many (Get-WinForgeText 'programas marcados para não atualizar ficaram de fora.') } else { (Get-WinForgeText 'Nenhum programa que o winget reconhece tem versão nova.') })

            return (Set-WinForgeResultView -Result (New-WinForgeResult -Kind Ok -Detail (Get-WinForgeText 'os programas que o winget reconhece estão em dia')) `
                    -Headline (Get-WinForgeText 'Os programas estão em dia') -Note $note)
        }
        "Error" {
            return (New-WinForgeResult -Kind Failed -Detail $Plan.Detail)
        }
        "None" {
            # Sozinha, a tela termina em "Cancelado"; na Manutenção, a etapa fica como ignorada.
            Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Nenhum programa foi atualizado: você escolheu não atualizar.')
            return (New-WinForgeResult -Kind Skipped -Detail (Get-WinForgeText 'cancelado pelo usuário'))
        }
        { $_ -in "Ids", "All" } {
            $known = @($Plan.Packages)

            # "Todos" com a lista lida é a própria lista, um a um: o resumo diz o que deu certo em cada programa.
            if ($Plan.Action -eq "Ids") { $ids = @($Plan.Ids) } else { $ids = @($known | ForEach-Object { $_.Id }) }

            if ($ids.Count -gt 0) {
                # O Instalador de Aplicativo é o próprio winget: atualizado no meio da lista, ele é trocado enquanto os
                # programas seguintes ainda precisam dele. Vai por último.
                $ids = @(@($ids | Where-Object { $_ -ne "Microsoft.AppInstaller" }) + @($ids | Where-Object { $_ -eq "Microsoft.AppInstaller" }))

                $packages = @(
                    foreach ($id in $ids) {
                        $match = @($known | Where-Object { $_.Id -eq $id }) | Select-Object -First 1
                        [PSCustomObject]@{
                            Id         = $id
                            Nome       = $(if ($match) { $match.Nome } else { $id })
                            Disponivel = $(if ($match) { [string]$match.Disponivel } else { "" })
                        }
                    }
                )

                $result = Get-WinForgeLastResult -Output (Invoke-WinForgeWingetPackages -Operation Upgrade -Packages $packages)

                # O Histórico de mudanças anota os programas que foram de fato atualizados.
                $changed = @(Get-WinForgeResultData -Result $result -Name "ChangedIds")
                $names = @($packages | Where-Object { $changed -contains $_.Id } | ForEach-Object { [string]$_.Nome })

                if ($names.Count -gt 0) {
                    [void](Add-WinForgeChange -Action (Get-WinForgeText 'Programas atualizados') -Text (Join-WinForgeList -Items $names))
                }

                # Na janela, tudo certo: o título diz quantos, e a frase, quais.
                if ($null -ne $result -and $result.Kind -eq "Ok" -and $names.Count -gt 0) {
                    [void](Set-WinForgeResultView -Result $result -Headline (Format-WinForgeCount -Count $names.Count -One (Get-WinForgeText 'programa atualizado') -Many (Get-WinForgeText 'programas atualizados')) `
                            -Note "$(Join-WinForgeShortList -Items $names).")
                }

                return $result
            }

            # Sem a lista (o winget mostrou um formato que o WinForge não lê): o winget atualiza tudo de uma vez.
            $arguments = Get-WinForgeWingetArguments -Operation UpgradeAll

            Write-Host ""
            Write-WinForgeCommand -Command "winget $($arguments -join ' ')"
            Write-Host ""
            Write-Progress -Activity (Get-WinForgeText 'Atualizando programas') -Status (Get-WinForgeText 'o winget atualiza tudo o que tiver atualização')
            $script:WinForgeInstalledIdsCache = $null

            try {
                $exitCode = Invoke-WinForgeNative -FilePath "winget" -Arguments $arguments -IgnoreExitCode -PassThru
            }
            finally {
                Write-Progress -Activity (Get-WinForgeText 'Atualizando programas') -Completed
            }

            Write-Host ""

            # "Nenhuma atualização aplicável" (0x8A15002B) não é problema: o winget só não tinha o que atualizar.
            $exitResult = Get-WinForgeWingetExitResult -ExitCode $exitCode

            if ($exitResult.Kind -ne "Failed") {
                # Só o código 0 diz que algo foi atualizado; "nenhuma atualização aplicável" também termina bem.
                if ($exitCode -eq 0) { [void](Add-WinForgeChange -Action (Get-WinForgeText 'Programas atualizados') -Text (Get-WinForgeText 'o que o winget tinha para atualizar')) }
                Write-WinForgeStatus -Type Success -Message (Get-WinForgeText 'O winget terminou a atualização.')
                return (New-WinForgeResult -Kind Ok -Detail (Get-WinForgeText 'o winget atualizou o que tinha atualização') -Data $exitResult.Data)
            }

            # O detalhe pode ser uma frase ("algum programa não foi atualizado — erro 0x8A15002C") ou só o código.
            Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'O winget terminou com problemas: {0}. Veja os detalhes técnicos.' "$($exitResult.Detail)")
            return (New-WinForgeResult -Kind Warning -Detail (Get-WinForgeText 'o winget terminou com problemas: {0}' "$($exitResult.Detail)"))
        }
    }

    # Um plano que este código não conhece é um erro de programação, não um sucesso.
    return (New-WinForgeResult -Kind Failed -Detail (Get-WinForgeText 'ação desconhecida no plano: {0}' "$($Plan.Action)"))
}


function Update-WinForgeSoftware {
    Enter-WinForgeAction -Title (Get-WinForgeText 'Atualizar programas (winget)')

    # O desfecho vem do resultado do plano, não da contagem de mensagens: "Não atualizar" não é ressalva, um erro depois
    # de a lista de pacotes ter sido atualizada continua sendo falha, e pacotes que falharam deixam a faixa vermelha.
    $final = New-WinForgeResult -Kind Failed -Detail (Get-WinForgeText 'o plano de atualização não devolveu resultado')

    try {
        $plan = Get-WinForgeWingetUpgradePlan
        $result = Get-WinForgeLastResult -Output (Invoke-WinForgeWingetUpgradePlan -Plan $plan)
        if ($null -ne $result) {
            $final = $result
        }
    }
    catch {
        Write-Host ""
        Write-WinForgeStatus -Type Error -Message (Get-WinForgeText 'Não foi possível atualizar os programas: {0}.' "$($_.Exception.Message.TrimEnd('.'))")
        $final = New-WinForgeResult -Kind Failed -Detail $_.Exception.Message
    }

    Exit-WinForgeAction -Result $final
}


# ---------------------------------------------------------------------------
# Reparar o Instalador de Aplicativo e manter programas na versão atual
# ---------------------------------------------------------------------------

function Get-WinForgeSoftwarePageStatus {
    <#
    O resumo no alto da página Programas (New-GuiPageStatus), só quando pede atenção: o Instalador de Aplicativo (o
    winget) que falta, com o botão para o reparo. Quase todas as ações da página dependem dele, e o reparo não tem linha
    própria na página. Com ele no PC, a página fica sem a faixa. Só procura o comando: nada roda.
    #>
    if (Test-WinForgeWinget) { return @() }

    return @([PSCustomObject]@{ Label = "winget"; Text = (Get-WinForgeText 'falta o Instalador de Aplicativo'); Level = "Warn"; Opens = "software.winget-repair" })
}


function Get-WinForgeWingetVersion {
    # A versão do winget ("v1.9.25200"), ou $null quando ele não está no PC ou não responde.
    if (-not (Test-WinForgeWinget)) { return $null }

    try {
        $run = Invoke-WinForgeCapture -FilePath "winget" -Arguments @("--version")
    }
    catch {
        return $null
    }

    $version = [string](@($run.Lines | Where-Object { [string]$_ -match '^\s*v?\d+\.\d+' }) | Select-Object -First 1)

    if ($run.ExitCode -ne 0 -or [string]::IsNullOrWhiteSpace($version)) { return $null }

    return $version.Trim()
}


function Register-WinForgeWinget {
    <#
    Registra de novo o Instalador de Aplicativo (o winget) para esta conta, com o comando que a Microsoft indica quando ele
    não aparece (Add-AppxPackage -RegisterByFamilyName), e confere se ele passou a responder. Devolve Version (vazio
    quando continua sem responder) e Problem (o erro do registro, quando houve). Quando ele volta, a próxima ação prepara
    a lista de pacotes de novo, e o Histórico de mudanças anota. Usada pelo reparo, pela restauração de um backup e pelo
    começo do Otimizar.
    #>
    param ([string]$Activity = (Get-WinForgeText 'Reparar o Instalador de Aplicativo'))

    Write-WinForgeCommand -Command "Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe"
    Write-Progress -Activity $Activity -Status (Get-WinForgeText 'registrando o Instalador de Aplicativo')
    $problem = ""

    try {
        Add-AppxPackage -RegisterByFamilyName -MainPackage "Microsoft.DesktopAppInstaller_8wekyb3d8bbwe" -ErrorAction Stop
    }
    catch {
        $problem = ([string]$_.Exception.Message).Trim().TrimEnd('.')
    }
    finally {
        Write-Progress -Activity $Activity -Completed
    }

    $version = Get-WinForgeWingetVersion

    if ($version) {
        $script:WinForgeWingetReady = $false
        $script:WinForgeInstalledIdsCache = $null
        [void](Add-WinForgeChange -Action (Get-WinForgeText 'Reparar o Instalador de Aplicativo') -Text (Get-WinForgeText 'Instalador de Aplicativo registrado de novo para esta conta'))
    }

    return [PSCustomObject]@{ Version = [string]$version; Problem = $problem }
}


function Repair-WinForgeWinget {
    <#
    Reparar o Instalador de Aplicativo: registra de novo o winget para esta conta, com o comando que a Microsoft indica
    quando ele não aparece (Add-AppxPackage -RegisterByFamilyName). Se o pacote não estiver no PC, ou o registro não
    resolver, oferece a página dele na Microsoft Store. Com o winget respondendo, não mexe em nada. Elevado com outra
    conta, não registra: o registro valeria para essa conta, e não para quem usa o PC.
    #>
    $title = (Get-WinForgeText 'Reparar o Instalador de Aplicativo')

    Enter-WinForgeAction -Title $title

    $final = New-WinForgeResult -Kind Ok -Title $title

    try {
        Write-Progress -Activity $title -Status (Get-WinForgeText 'conferindo o winget')
        try { $before = Get-WinForgeWingetVersion } finally { Write-Progress -Activity $title -Completed }

        if ($before) {
            Write-WinForgeKeyValue -Label (Get-WinForgeText 'Versão do winget') -Value $before
            Write-WinForgeStatus -Type Success -Message (Get-WinForgeText 'O Instalador de Aplicativo já funciona neste PC.')
            $final = New-WinForgeResult -Kind Skipped -Detail (Get-WinForgeText 'o winget já funcionava') -Title $title
            Exit-WinForgeAction -Result (Set-WinForgeResultView -Result $final -Headline (Get-WinForgeText 'O Instalador de Aplicativo já funciona') -Note (Get-WinForgeText 'Nada foi mudado.'))
            return
        }

        if (Test-WinForgeUserContextMismatch) {
            Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'O WinForge está elevado com outra conta: o registro valeria para ela, e não para {0}.' "$(Get-WinForgeInteractiveUser)")
            Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Para reparar, {0}.' "$(Get-WinForgeUnelevatedHint)")
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Skipped -Detail (Get-WinForgeText 'o WinForge está elevado com outra conta') -Title $title)
            return
        }

        $registration = Register-WinForgeWinget -Activity $title
        $problem = $registration.Problem
        $after = $registration.Version

        if ($after) {
            Write-WinForgeKeyValue -Label (Get-WinForgeText 'Versão do winget') -Value $after
            Write-WinForgeStatus -Type Success -Message (Get-WinForgeText 'O Instalador de Aplicativo voltou a funcionar.')
            $final = New-WinForgeResult -Kind Ok -Detail (Get-WinForgeText 'o winget voltou a funcionar ({0})' "$after") -Title $title
            [void](Set-WinForgeResultView -Result $final -Headline (Get-WinForgeText 'O Instalador de Aplicativo voltou a funcionar') -Note (Get-WinForgeText 'As telas de Programas e de Atualizações já podem usá-lo.'))
        }
        else {
            Write-WinForgeStatus -Type Warning -Message $(if ($problem) { (Get-WinForgeText 'O registro não resolveu: {0}.' "$problem") } else { (Get-WinForgeText 'O registro terminou, mas o winget continua sem responder.') })
            Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Instale ou atualize o Instalador de Aplicativo pela Microsoft Store e use esta ação de novo.')
            Write-Host ""

            if (Confirm-WinForgeAction -Message (Get-WinForgeText 'Abrir o Instalador de Aplicativo na Microsoft Store agora?') -DefaultKey S -YesLabel (Get-WinForgeText 'Abrir') -NoLabel (Get-WinForgeText 'Agora não')) {
                [void](Open-WinForgeAppInstallerPage)
            }

            $final = New-WinForgeResult -Kind Failed -Detail $(if ($problem) { (Get-WinForgeText 'o registro não resolveu: {0}' "$problem") } else { (Get-WinForgeText 'o winget continua sem responder') }) -Title $title
            [void](Set-WinForgeResultView -Result $final -Headline (Get-WinForgeText 'O Instalador de Aplicativo continua sem funcionar') -Note (Get-WinForgeText 'Instale ou atualize pela Microsoft Store e use esta ação de novo.'))
        }
    }
    catch {
        Write-WinForgeStatus -Type Error -Message (Get-WinForgeText 'Não foi possível reparar o Instalador de Aplicativo: {0}.' "$($_.Exception.Message.TrimEnd('.'))")
        $final = New-WinForgeResult -Kind Failed -Detail $_.Exception.Message.TrimEnd('.') -Title $title
    }

    Exit-WinForgeAction -Result $final
}


function Test-WinForgeWingetPinId {
    <#
    Se um ID pode ir para o "winget pin": sem espaços nem caracteres de controle, sem começar por "-" (viraria uma opção
    do winget), sem aspas nem símbolos de linha de comando, não cortado na tabela e de uma fonte do winget (os IDs que
    ele inventa para o que só achou no Windows, "ARP\..." e "MSIX\...", ficam de fora). O desfazer confere com esta
    regra o ID guardado no diário.
    #>
    param ([AllowEmptyString()][string]$Id)

    if ([string]::IsNullOrWhiteSpace($Id) -or $Id.Length -gt 128) { return $false }
    if ($Id -match '[\s\p{Cc}\p{Cf}]' -or $Id.StartsWith("-") -or $Id -match '["''`;|&<>]' -or $Id -match '^(ARP|MSIX)\\') { return $false }

    return (-not (Test-WinForgeWingetIdTruncated -Id $Id))
}


function ConvertFrom-WinForgeWingetPinTable {
    <#
    Lê a tabela do "winget pin list": Nome, Id, Versao e Fonte (Get-WinForgeWingetTable) e o tipo do marcador (Pin) com a
    faixa de versões (Gated). O tipo vem com o nome interno do winget em qualquer idioma do Windows ("Pinning", o comum;
    "Blocking", que bloqueia também a atualização pedida pelo nome; "Gating", preso a uma faixa de versões): ele é achado
    pelo nome, depois do ID na linha. Um programa com marcador em mais de uma fonte vira um só, com o tipo mais forte e,
    sem uma fonte só, Fonte vazia. IDs que não servem para o "winget pin" (Test-WinForgeWingetPinId) ficam de fora.
    #>
    param ([string[]]$Lines = @())

    $rows = @(ConvertFrom-WinForgeWingetTable -Lines $Lines | Where-Object { Test-WinForgeWingetPinId -Id ([string]$_.Id) })
    $strength = @{ "Pinning" = 1; "Gating" = 2; "Blocking" = 3 }
    $pins = [ordered]@{}

    foreach ($row in $rows) {
        $id = [string]$row.Id
        if ($pins.Contains($id)) { continue }

        $type = ""
        $gated = ""
        $sources = @()

        foreach ($line in @($Lines)) {
            $tokens = @(([string]$line).Trim() -split '\s+')
            $at = [Array]::IndexOf([string[]]$tokens, $id)
            if ($at -lt 0) { continue }

            for ($i = $at + 1; $i -lt $tokens.Count; $i++) {
                if ($strength.ContainsKey($tokens[$i])) {
                    if (-not $type -or $strength[$tokens[$i]] -gt $strength[$type]) {
                        $type = $tokens[$i]
                        $gated = $(if ($type -eq "Gating" -and $i + 1 -lt $tokens.Count) { $tokens[$i + 1] } else { "" })
                    }

                    if ($i -gt $at + 1) { $sources += $tokens[$i - 1] }
                    break
                }
            }
        }

        $sourceList = @($sources | Select-Object -Unique)

        $pins[$id] = [PSCustomObject]@{
            Id     = $id
            Nome   = [string]$row.Nome
            Versao = [string]$row.Versao
            Fonte  = $(if ($sourceList.Count -eq 1) { [string]$sourceList[0] } else { "" })
            Pin    = $(if ($type) { $type } else { "Pinning" })
            Gated  = $gated
        }
    }

    return @($pins.Values)
}


function Get-WinForgeWingetPins {
    # Os programas marcados no winget ("winget pin list"): Pins (ConvertFrom-WinForgeWingetPinTable) e Problem (vazio
    # quando leu). O winget antigo, sem o "pin", responde que a linha de comando é inválida (0x8A150002): Old diz isso.
    $listing = Invoke-WinForgeCapture -FilePath "winget" -Arguments @("pin", "list", "--accept-source-agreements")

    if ($listing.ExitCode -ne 0) {
        $old = (("0x{0:X8}" -f $listing.ExitCode) -eq "0x8A150002")
        $problem = $(if ($old) { (Get-WinForgeText 'o winget deste PC é antigo e não marca programas') } else { (Get-WinForgeWingetExitResult -ExitCode $listing.ExitCode).Detail })
        return [PSCustomObject]@{ Pins = @(); Problem = $problem; Old = $old }
    }

    return [PSCustomObject]@{ Pins = @(ConvertFrom-WinForgeWingetPinTable -Lines $listing.Lines); Problem = ""; Old = $false }
}


function Invoke-WinForgeWingetPin {
    <#
    Põe ou tira o marcador de um programa no winget e devolve um WinForge.Result. Add: Ok quando ficou marcado (com
    Data.Existing quando ele já tinha um marcador de outro tipo, que fica como está: --force trocaria o marcador que a
    pessoa pôs, e ele já segura o programa). Remove: Ok quando ficou sem marcador (Data.Missing quando já estava sem),
    em todas as fontes. Pin e Gated (Add) refazem um marcador do mesmo tipo, para o desfazer.
    #>
    param (
        [Parameter(Mandatory)][ValidateSet("Add", "Remove")][string]$Operation,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Id,
        [AllowEmptyString()][string]$Source = "",
        [ValidateSet("Pinning", "Blocking", "Gating")][string]$Pin = "Pinning",
        [AllowEmptyString()][string]$Gated = ""
    )

    if (-not (Test-WinForgeWingetPinId -Id $Id)) { return (New-WinForgeResult -Kind Failed -Detail (Get-WinForgeText 'ID do winget inválido')) }
    if ($Source -and $Source -notmatch '^[A-Za-z0-9._-]{1,64}$') { return (New-WinForgeResult -Kind Failed -Detail (Get-WinForgeText 'fonte do winget inválida')) }
    if ($Operation -eq "Add" -and $Pin -eq "Gating" -and $Gated -notmatch '^[0-9A-Za-z.+*-]{1,64}$') { return (New-WinForgeResult -Kind Failed -Detail (Get-WinForgeText 'faixa de versões inválida')) }

    $arguments = @("pin", $Operation.ToLowerInvariant(), "--id", $Id, "--exact")

    if ($Operation -eq "Add") {
        if ($Source) { $arguments += @("--source", $Source) }
        if ($Pin -eq "Blocking") { $arguments += "--blocking" }
        if ($Pin -eq "Gating") { $arguments += @("--version", $Gated) }
    }

    $arguments += "--accept-source-agreements"

    $run = Invoke-WinForgeCapture -FilePath "winget" -Arguments $arguments

    # 0x8A150062: outro marcador já existe; 0x8A150063: não há marcador para tirar.
    $code = "0x{0:X8}" -f $run.ExitCode

    if ($run.ExitCode -eq 0) { return (New-WinForgeResult -Kind Ok) }
    if ($Operation -eq "Add" -and $code -eq "0x8A150062") { return (New-WinForgeResult -Kind Ok -Detail (Get-WinForgeText 'já tinha um marcador do winget') -Data @{ Existing = $true }) }
    if ($Operation -eq "Remove" -and $code -eq "0x8A150063") { return (New-WinForgeResult -Kind Ok -Detail (Get-WinForgeText 'já estava sem marcador') -Data @{ Missing = $true }) }

    return (Get-WinForgeWingetExitResult -ExitCode $run.ExitCode)
}


function Get-WinForgeWingetPinJournalText {
    # "ficam na versão atual: A e B; voltam a atualizar: C": o Histórico de mudanças e o resultado.
    param (
        [AllowEmptyCollection()][string[]]$Held = @(),
        [AllowEmptyCollection()][string[]]$Released = @()
    )

    $parts = @()
    if (@($Held).Count -eq 1) { $parts += (Get-WinForgeText 'fica na versão atual: {0}' "$($Held[0])") }
    elseif (@($Held).Count -gt 1) { $parts += (Get-WinForgeText 'ficam na versão atual: {0}' "$(Join-WinForgeList -Items $Held)") }
    if (@($Released).Count -eq 1) { $parts += (Get-WinForgeText 'volta a atualizar: {0}' "$($Released[0])") }
    elseif (@($Released).Count -gt 1) { $parts += (Get-WinForgeText 'voltam a atualizar: {0}' "$(Join-WinForgeList -Items $Released)") }

    return ($parts -join "; ")
}


function Set-WinForgeWingetPins {
    <#
    Manter programas na versão atual: uma lista com os programas que têm versão nova no winget e os que já estão marcados
    para não atualizar (estes, marcados). Marcar põe o marcador do winget ("winget pin add", o tipo comum): o programa sai
    do "winget upgrade" e, com ele, de Atualizar programas, do Otimizar, do monitor e do Verificar o PC. O tipo comum deixa
    a atualização pedida pelo nome no próprio winget, de propósito: é uma escolha que a pessoa pode desfazer na hora.
    Desmarcar tira o marcador, de qualquer tipo. Vai para o Histórico de mudanças com o desfazer, que refaz cada marcador
    tirado com o mesmo tipo. Os marcadores ficam no perfil da conta: elevado com outra conta, nada é mudado.
    #>
    $title = (Get-WinForgeText 'Manter programas na versão atual')

    Enter-WinForgeAction -Title $title

    $final = New-WinForgeResult -Kind Ok -Title $title

    try {
        if (-not (Initialize-WinForgeWinget -OfferStore)) {
            Exit-WinForgeAction -Result (Get-WinForgeWingetMissingResult -Title $title)
            return
        }

        if (Test-WinForgeUserContextMismatch) {
            Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'O WinForge está elevado com outra conta: os marcadores do winget ficariam nela, e não em {0}.' "$(Get-WinForgeInteractiveUser)")
            Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Para mudar, {0}.' "$(Get-WinForgeUnelevatedHint)")
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Skipped -Detail (Get-WinForgeText 'o WinForge está elevado com outra conta') -Title $title)
            return
        }

        Write-Progress -Activity $title -Status (Get-WinForgeText 'consultando o winget')

        try {
            $read = Get-WinForgeWingetPins
            $upgrade = $(if (-not $read.Problem) { Invoke-WinForgeCapture -FilePath "winget" -Arguments @("upgrade", "--accept-source-agreements") } else { $null })
        }
        finally {
            Write-Progress -Activity $title -Completed
        }

        if ($read.Problem) {
            Write-WinForgeStatus -Type Error -Message (Get-WinForgeText 'Não foi possível ler os programas marcados: {0}.' "$($read.Problem)")
            $final = New-WinForgeResult -Kind Failed -Detail $read.Problem -Title $title

            # O winget antigo vem com o Instalador de Aplicativo: a Microsoft Store o atualiza.
            if ($read.Old) {
                Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Atualize o Instalador de Aplicativo pela Microsoft Store e use esta ação de novo.')
                [void](Set-WinForgeResultView -Result $final -Headline (Get-WinForgeText 'O winget deste PC é antigo') -Note (Get-WinForgeText 'Atualize o Instalador de Aplicativo pela Microsoft Store.') -Next "updates.store" -NextLabel (Get-WinForgeText 'Atualizar pela Store'))
            }

            Exit-WinForgeAction -Result $final
            return
        }

        $pins = @($read.Pins)
        $available = @()

        if (-not (Test-WinForgeWingetNoUpgradeOutput -OutputText $upgrade.Text -ExitCode $upgrade.ExitCode)) {
            $available = @(ConvertFrom-WinForgeWingetTable -Lines $upgrade.Lines)

            if ($available.Count -eq 0) {
                # Sem a lista de versões novas, a tela continua com os já marcados, que podem voltar a atualizar.
                Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'Não foi possível ler os programas com versão nova ({0}); a lista mostra só os já marcados.' "$((Get-WinForgeWingetExitResult -ExitCode $upgrade.ExitCode).Detail)")
            }
        }

        # Só o que pode ser marcado (Test-WinForgeWingetPinId); o que já tem marcador fica uma vez só, como marcado.
        $pinnedIds = @($pins | ForEach-Object { [string]$_.Id })
        $available = @($available | Where-Object { (Test-WinForgeWingetPinId -Id ([string]$_.Id)) -and $pinnedIds -notcontains [string]$_.Id })

        if ($pins.Count + $available.Count -eq 0) {
            Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Nenhum programa tem versão nova no winget agora, e nenhum está marcado para não atualizar.')
            $final = New-WinForgeResult -Kind Skipped -Detail (Get-WinForgeText 'nenhum programa com versão nova no winget') -Title $title
            Exit-WinForgeAction -Result (Set-WinForgeResultView -Result $final -Headline (Get-WinForgeText 'Nada para escolher agora') -Note (Get-WinForgeText 'Quando um programa tiver versão nova no winget, ele aparece aqui.'))
            return
        }

        if (Test-WinForgeGuiPrompts) {
            Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Marcado fica na versão atual: o WinForge não o atualiza. Programas que se atualizam sozinhos continuam se atualizando.')
        }
        else {
            Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Com * é o que já fica na versão atual. Digite os números de tudo o que deve ficar na versão atual: o que ficar de fora volta a atualizar. P deixa como está.')
            Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Programas que se atualizam sozinhos continuam se atualizando.')
        }

        $pool = @(
            @($pins | Sort-Object -Property Nome | ForEach-Object { [PSCustomObject]@{ Item = $_; Pinned = $true } }) +
            @($available | Sort-Object -Property Nome | ForEach-Object { [PSCustomObject]@{ Item = $_; Pinned = $false } })
        )

        $choices = @(
            for ($i = 0; $i -lt $pool.Count; $i++) {
                $item = $pool[$i].Item
                $parts = @([string]$item.Id)
                $version = ([string]$item.Versao).Trim()

                if ($pool[$i].Pinned) {
                    if ($version -and $version -notmatch '^(\?|Unknown|Desconhecid[ao])$') { $parts += (Get-WinForgeText 'versão {0}' "$version") }
                    if ($item.Pin -eq "Blocking") { $parts += (Get-WinForgeText 'bloqueado no winget') }
                    if ($item.Pin -eq "Gating") { $parts += (Get-WinForgeText 'só versões {0}' "$($item.Gated)") }
                }
                else {
                    $parts += (Get-WinForgeText '{0} para {1}' "$version" "$($item.Disponivel)")
                }

                @{ Key = [string]$i; Label = [string]$item.Nome; Description = ($parts -join " · "); Selected = [bool]$pool[$i].Pinned }
            }
        )

        # Sem "Marcar todos"; desmarcar tudo é uma resposta (todos voltam a atualizar): a lista volta vazia, e não $null.
        $picked = Read-WinForgeMultiSelect -Message (Get-WinForgeText 'O que deve ficar na versão atual') -Options $choices -NoSelectAll -AllowNone -ConfirmLabel (Get-WinForgeText 'Salvar')

        if ($null -eq $picked) {
            Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'Operação cancelada.')
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Skipped -Detail (Get-WinForgeText 'cancelado pelo usuário') -Title $title)
            return
        }

        $changes = @(
            for ($i = 0; $i -lt $pool.Count; $i++) {
                $want = (@($picked) -contains [string]$i)
                if ($want -ne [bool]$pool[$i].Pinned) { [PSCustomObject]@{ Item = $pool[$i].Item; Hold = $want } }
            }
        )

        if ($changes.Count -eq 0) {
            Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Nada foi mudado.')
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Skipped -Detail (Get-WinForgeText 'você não mudou nada') -Title $title)
            return
        }

        Write-Host ""

        $held = @()
        $released = @()
        $undo = @()
        $problems = @()

        foreach ($change in $changes) {
            $item = $change.Item
            $name = [string]$item.Nome

            if ($change.Hold) {
                $source = [string](Get-WinForgeJsonValue -Object $item -Name "Fonte" -Default "")
                $run = Invoke-WinForgeWingetPin -Operation Add -Id ([string]$item.Id) -Source $(if ($source -in @("winget", "msstore")) { $source } else { "" })
            }
            else {
                $run = Invoke-WinForgeWingetPin -Operation Remove -Id ([string]$item.Id)
            }

            if ($run.Kind -ne "Ok") {
                $problems += [PSCustomObject]@{ Name = $name; Detail = [string]$run.Detail }
                Write-WinForgeStatus -Type Error -Message "${name}: $([string]$run.Detail)."
                continue
            }

            if ($change.Hold) {
                $held += $name
                Write-WinForgeStatus -Type Success -Message (Get-WinForgeText '{0}: fica na versão atual.' "$name")

                # Um marcador que já existia (de outro tipo, posto fora do WinForge) não foi posto agora: o desfazer não o tira.
                if (-not (Test-WinForgeResultFlag -Result $run -Name "Existing")) { $undo += @{ Id = [string]$item.Id; Pin = "None"; Source = ""; Gated = "" } }
            }
            else {
                $released += $name
                Write-WinForgeStatus -Type Success -Message (Get-WinForgeText '{0}: volta a atualizar.' "$name")

                if (-not (Test-WinForgeResultFlag -Result $run -Name "Missing")) { $undo += @{ Id = [string]$item.Id; Pin = [string]$item.Pin; Source = [string]$item.Fonte; Gated = [string]$item.Gated } }
            }
        }

        $doneText = Get-WinForgeWingetPinJournalText -Held $held -Released $released

        if ($doneText) {
            if ($undo.Count -gt 0) {
                [void](Add-WinForgeChange -Action $title -Text $doneText -Undo @{ Kind = "winget-pin"; Items = $undo })
                Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Para desfazer, use Manutenção > Histórico de mudanças.')
            }
            else {
                [void](Add-WinForgeChange -Action $title -Text $doneText)
            }
        }

        $doneCount = $held.Count + $released.Count
        $headline = $(
            if ($released.Count -eq 0) { Format-WinForgeCount -Count $held.Count -One (Get-WinForgeText 'programa fica na versão atual') -Many (Get-WinForgeText 'programas ficam na versão atual') }
            elseif ($held.Count -eq 0) { Format-WinForgeCount -Count $released.Count -One (Get-WinForgeText 'programa volta a atualizar') -Many (Get-WinForgeText 'programas voltam a atualizar') }
            else { (Get-WinForgeText 'Lista salva') }
        )

        if ($problems.Count -eq 0) {
            $final = New-WinForgeResult -Kind Ok -Detail $doneText -Title $title
            [void](Set-WinForgeResultView -Result $final -Headline $headline -Note "$(ConvertTo-WinForgeHeadline -Text $doneText).")
        }
        else {
            $names = Join-WinForgeList -Items @($problems | ForEach-Object { $_.Name })
            $reason = [string]$problems[0].Detail
            $kind = $(if ($doneCount -gt 0) { "Warning" } else { "Failed" })
            $final = New-WinForgeResult -Kind $kind -Detail (Get-WinForgeText 'não mudou: {0} ({1})' "$names" "$reason") -Title $title
            [void](Set-WinForgeResultView -Result $final -Headline $(if ($doneCount -gt 0) { (Get-WinForgeText 'Nem tudo foi mudado') } else { (Get-WinForgeText 'Nada foi mudado') }) -Note (Get-WinForgeText 'Não mudou: {0} ({1}).' "$names" "$reason"))
        }
    }
    catch {
        Write-WinForgeStatus -Type Error -Message (Get-WinForgeText 'Não foi possível mudar os programas marcados: {0}.' "$($_.Exception.Message.TrimEnd('.'))")
        $final = New-WinForgeResult -Kind Failed -Detail $_.Exception.Message.TrimEnd('.') -Title $title
    }

    Exit-WinForgeAction -Result $final
}


# ---------------------------------------------------------------------------
# Navegadores e Microsoft Store (etapas do Otimizar)
# ---------------------------------------------------------------------------

# O Microsoft Edge comum (o canal Estável), como o atualizador do Edge o conhece.
$script:WinForgeEdgeAppId = "{56EB18F8-B008-4CBD-B6D2-8C97FE7E9062}"

# O Google Chrome comum (o canal Estável), como o atualizador do Google o conhece.
$script:WinForgeChromeAppId = "{8A69D345-D564-463c-AFF1-A69D9E530F96}"


function Get-WinForgeEdgeVersion {
    <#
    A versão do Microsoft Edge instalada para todos, como o atualizador do Edge a registra (pv). Pending: a versão nova
    já foi instalada, mas o Edge aberto ainda usa a de antes; ela passa a valer quando o Edge for fechado (o atualizador
    guarda a versão de antes em opv e deixa o new_msedge.exe ao lado do msedge.exe). $null quando o Edge não está
    instalado assim.
    #>
    $roots = @("HKLM:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients", "HKLM:\SOFTWARE\Microsoft\EdgeUpdate\Clients")

    foreach ($root in $roots) {
        $key = "$root\$($script:WinForgeEdgeAppId)"
        $version = [string](Get-WinForgeRegistryValueOrNull -Path $key -Name "pv")

        if ([string]::IsNullOrWhiteSpace($version)) { continue }

        $old = [string](Get-WinForgeRegistryValueOrNull -Path $key -Name "opv")
        $staged = $false

        foreach ($base in @(${env:ProgramFiles(x86)}, $env:ProgramFiles)) {
            if ([string]::IsNullOrWhiteSpace($base)) { continue }
            if (Test-Path -LiteralPath (Join-Path $base "Microsoft\Edge\Application\new_msedge.exe") -PathType Leaf) { $staged = $true }
        }

        return [PSCustomObject]@{ Version = $version.Trim(); Pending = ($staged -or -not [string]::IsNullOrWhiteSpace($old)) }
    }

    return $null
}


function Get-WinForgeEdgeUpdaterPath {
    # O atualizador do Edge (MicrosoftEdgeUpdate.exe), que fica em Arquivos de Programas (x86). "" se não existir.
    foreach ($base in @(${env:ProgramFiles(x86)}, $env:ProgramFiles)) {
        if ([string]::IsNullOrWhiteSpace($base)) { continue }

        $path = Join-Path $base "Microsoft\EdgeUpdate\MicrosoftEdgeUpdate.exe"

        if (Test-Path -LiteralPath $path -PathType Leaf) { return $path }
    }

    return ""
}


function Get-WinForgeBrowserOutcome {
    <#
    O que dizer de um navegador depois de pedir a versão nova: Before e After são as versões de antes e de depois (After
    vazio: não deu para ler), Pending diz que a versão nova espera o navegador ser fechado e aberto de novo, e ExitCode é
    o código do atualizador. Devolve Kind (Ok | Warning) e Text, curto ("atualizado para 131.0", "já na versão mais
    nova").
    #>
    param (
        [string]$Before,
        [AllowEmptyString()][string]$After,
        [bool]$Pending = $false,
        [int]$ExitCode = 0,
        [string]$FailText = "",

        # O atualizador não garante que procurou (o antigo do Google, por exemplo, sai sem procurar se procurou há
        # pouco): sem versão nova, a frase não afirma que a instalada é a mais nova.
        [switch]$Unconfirmed
    )

    $reopen = $(if ($Pending) { (Get-WinForgeText '; vale ao abrir de novo') } else { "" })

    if (-not [string]::IsNullOrWhiteSpace($After) -and $After -ne $Before) {
        return [PSCustomObject]@{ Kind = "Ok"; Text = (Get-WinForgeText 'atualizado para {0}{1}' "$After" "$reopen") }
    }

    if ($ExitCode -ne 0) {
        $why = $(if ($FailText) { $FailText } else { (Get-WinForgeText 'o atualizador terminou com o código {0}' "$(Format-WinForgeExitCode -ExitCode $ExitCode)") })
        return [PSCustomObject]@{ Kind = "Warning"; Text = (Get-WinForgeText 'não atualizou ({0})' "$why") }
    }

    if ($Unconfirmed) { return [PSCustomObject]@{ Kind = "Ok"; Text = (Get-WinForgeText 'nenhuma versão nova instalada agora ({0}){1}' "$Before" "$reopen") } }

    return [PSCustomObject]@{ Kind = "Ok"; Text = (Get-WinForgeText 'já na versão mais nova ({0}){1}' "$Before" "$reopen") }
}


function Update-WinForgeEdgeBrowser {
    # O Edge comum, pelo atualizador do próprio Edge (MicrosoftEdgeUpdate.exe). Devolve Name, Installed, Kind e Text.
    $browser = [PSCustomObject]@{ Name = "Microsoft Edge"; Installed = $false; Kind = "Skipped"; Text = "" }
    $before = Get-WinForgeEdgeVersion

    if ($null -eq $before) { return $browser }

    $browser.Installed = $true
    $updater = Get-WinForgeEdgeUpdaterPath

    if ([string]::IsNullOrWhiteSpace($updater)) {
        $browser.Kind = "Warning"
        $browser.Text = (Get-WinForgeText 'atualizador não encontrado; atualize em Configurações, Sobre o Microsoft Edge')
        return $browser
    }

    $run = Invoke-WinForgeCapture -FilePath $updater -Arguments @("/silent", "/install", "appguid=$($script:WinForgeEdgeAppId)&appname=Microsoft%20Edge&needsadmin=True")
    $after = Get-WinForgeEdgeVersion
    $outcome = Get-WinForgeBrowserOutcome -Before $before.Version -After $(if ($null -ne $after) { [string]$after.Version } else { "" }) `
        -Pending ($null -ne $after -and [bool]$after.Pending) -ExitCode ([int]$run.ExitCode)

    $browser.Kind = $outcome.Kind
    $browser.Text = $outcome.Text
    return $browser
}


function Get-WinForgeChromeInstall {
    <#
    O Google Chrome instalado para todos, que um Administrador atualiza: a versão (pv, no registro do atualizador do
    Google) e Pending (a versão nova já foi instalada e o Chrome aberto ainda usa a de antes: o atualizador guarda a de
    antes em opv e deixa o new_chrome.exe ao lado do chrome.exe). PerUser: só existe a instalação de um usuário, que o
    atualizador desse usuário mantém (como Administrador, o atualizador recusa: "usuário errado"). Blocked: uma política
    controla a atualização (UpdateDefault ou Update{id}: 0 = desligada, 2 = só pela pessoa, 3 = só a automática); pedir
    a atualização por fora dela não é garantido. $null sem Chrome.
    #>
    $id = $script:WinForgeChromeAppId
    $install = $null

    foreach ($root in @("HKLM:\SOFTWARE\WOW6432Node\Google\Update\Clients", "HKLM:\SOFTWARE\Google\Update\Clients")) {
        $version = [string](Get-WinForgeRegistryValueOrNull -Path "$root\$id" -Name "pv")
        if ([string]::IsNullOrWhiteSpace($version)) { continue }

        $staged = -not [string]::IsNullOrWhiteSpace([string](Get-WinForgeRegistryValueOrNull -Path "$root\$id" -Name "opv"))

        foreach ($base in @($env:ProgramFiles, ${env:ProgramFiles(x86)})) {
            if ([string]::IsNullOrWhiteSpace($base)) { continue }
            if (Test-Path -LiteralPath (Join-Path $base "Google\Chrome\Application\new_chrome.exe") -PathType Leaf) { $staged = $true }
        }

        $install = [PSCustomObject]@{ Version = $version.Trim(); Pending = $staged; PerUser = $false; Blocked = $false }
        break
    }

    if ($null -eq $install) {
        $version = [string](Get-WinForgeRegistryValueOrNull -Path "HKCU:\Software\Google\Update\Clients\$id" -Name "pv")
        if ([string]::IsNullOrWhiteSpace($version)) { return $null }

        return [PSCustomObject]@{ Version = $version.Trim(); Pending = $false; PerUser = $true; Blocked = $false }
    }

    $policy = "HKLM:\SOFTWARE\Policies\Google\Update"
    $app = Get-WinForgeRegistryValueOrNull -Path $policy -Name "Update$id"
    $default = Get-WinForgeRegistryValueOrNull -Path $policy -Name "UpdateDefault"
    $rule = $(if ($null -ne $app) { $app } else { $default })

    if ($null -ne $rule -and [string]$rule -in @("0", "2", "3")) { $install.Blocked = $true }

    return $install
}


function Get-WinForgeGoogleUpdaterCommand {
    <#
    O atualizador do Google para todos e o pedido de "atualizar agora". O atual (GoogleUpdater\<versão>\updater.exe, o
    de número mais alto) aceita --update-apps --system, que procura e instala na hora e só termina no fim. Sem ele, o
    antigo (Google\Update\GoogleUpdate.exe), com o mesmo pedido da tarefa agendada dele. $null sem nenhum dos dois.
    #>
    foreach ($base in @(${env:ProgramFiles(x86)}, $env:ProgramFiles)) {
        if ([string]::IsNullOrWhiteSpace($base)) { continue }

        $folder = Join-Path $base "Google\GoogleUpdater"
        if (-not (Test-Path -LiteralPath $folder -PathType Container)) { continue }

        $best = $null
        $bestVersion = $null

        foreach ($dir in @(Get-ChildItem -LiteralPath $folder -Directory -ErrorAction SilentlyContinue)) {
            $parsed = $null
            if (-not [version]::TryParse([string]$dir.Name, [ref]$parsed)) { continue }

            $exe = Join-Path $dir.FullName "updater.exe"
            if (-not (Test-Path -LiteralPath $exe -PathType Leaf)) { continue }

            if ($null -eq $bestVersion -or $parsed -gt $bestVersion) {
                $bestVersion = $parsed
                $best = $exe
            }
        }

        if ($null -ne $best) { return [PSCustomObject]@{ Path = $best; Arguments = @("--update-apps", "--system"); Legacy = $false } }
    }

    foreach ($base in @(${env:ProgramFiles(x86)}, $env:ProgramFiles)) {
        if ([string]::IsNullOrWhiteSpace($base)) { continue }

        $legacy = Join-Path $base "Google\Update\GoogleUpdate.exe"
        if (Test-Path -LiteralPath $legacy -PathType Leaf) { return [PSCustomObject]@{ Path = $legacy; Arguments = @("/ua", "/installsource", "scheduler"); Legacy = $true } }
    }

    return $null
}


function Update-WinForgeChromeBrowser {
    # O Chrome para todos, pelo atualizador do Google. Devolve Name, Installed, Kind e Text.
    $browser = [PSCustomObject]@{ Name = "Google Chrome"; Installed = $false; Kind = "Skipped"; Text = "" }
    $install = Get-WinForgeChromeInstall

    if ($null -eq $install) { return $browser }

    $browser.Installed = $true

    if ($install.PerUser) {
        $browser.Text = (Get-WinForgeText 'instalado só para um usuário; o Chrome se atualiza sozinho')
        return $browser
    }

    if ($install.Blocked) {
        $browser.Text = (Get-WinForgeText 'a atualização é controlada por uma política')
        return $browser
    }

    $command = Get-WinForgeGoogleUpdaterCommand

    if ($null -eq $command) {
        $browser.Kind = "Warning"
        $browser.Text = (Get-WinForgeText 'atualizador não encontrado; atualize em Configurações, Sobre o Google Chrome')
        return $browser
    }

    $run = Invoke-WinForgeCapture -FilePath $command.Path -Arguments @($command.Arguments)
    $after = Get-WinForgeChromeInstall
    $outcome = Get-WinForgeBrowserOutcome -Before $install.Version -After $(if ($null -ne $after) { [string]$after.Version } else { "" }) `
        -Pending ($null -ne $after -and [bool]$after.Pending) -ExitCode ([int]$run.ExitCode) `
        -Unconfirmed:([bool](Get-WinForgeJsonValue -Object $command -Name "Legacy" -Default $false))

    $browser.Kind = $outcome.Kind
    $browser.Text = $outcome.Text
    return $browser
}


function Get-WinForgeFirefoxInstall {
    <#
    O Firefox instalado para todos (o instalador da Mozilla grava HKLM\SOFTWARE\Mozilla\Mozilla Firefox, com
    CurrentVersion "145.0 (x64 pt-BR)"): Version, Locale (o idioma, que escolhe o pacote do winget), Esr, Path (o
    firefox.exe) e Blocked (a política DisableAppUpdate). A versão da Microsoft Store não grava essa chave: a Store a
    atualiza. $null sem Firefox.
    #>
    $keys = @(
        @{ Path = "HKLM:\SOFTWARE\Mozilla\Mozilla Firefox"; Esr = $false },
        @{ Path = "HKLM:\SOFTWARE\WOW6432Node\Mozilla\Mozilla Firefox"; Esr = $false },
        @{ Path = "HKLM:\SOFTWARE\Mozilla\Mozilla Firefox ESR"; Esr = $true },
        @{ Path = "HKLM:\SOFTWARE\WOW6432Node\Mozilla\Mozilla Firefox ESR"; Esr = $true }
    )

    foreach ($key in $keys) {
        $current = [string](Get-WinForgeRegistryValueOrNull -Path $key.Path -Name "CurrentVersion")
        if ($current -notmatch '^\s*([0-9][0-9.]*)') { continue }

        $version = $Matches[1].TrimEnd('.')
        $locale = $(if ($current -match '\(\S+\s+([A-Za-z]{2,3}(-[A-Za-z]{2,4})?)\)') { $Matches[1] } else { "" })
        $exe = [string](Get-WinForgeRegistryValueOrNull -Path "$($key.Path)\$($current.Trim())\Main" -Name "PathToExe")
        $esr = ([bool]$key.Esr -or $current -match '(?i)esr')
        $blocked = ([string](Get-WinForgeRegistryValueOrNull -Path "HKLM:\SOFTWARE\Policies\Mozilla\Firefox" -Name "DisableAppUpdate") -eq "1")

        return [PSCustomObject]@{ Version = $version; Locale = $locale; Esr = $esr; Path = $exe; Blocked = $blocked }
    }

    return $null
}


function Get-WinForgeFirefoxPackageId {
    # O pacote do winget com o mesmo idioma do Firefox instalado: Mozilla.Firefox é o inglês dos EUA; os outros idiomas
    # têm pacote próprio (Mozilla.Firefox.pt-BR). Trocar de pacote trocaria o idioma do Firefox.
    param ([AllowEmptyString()][string]$Locale)

    if ([string]::IsNullOrWhiteSpace($Locale) -or $Locale -eq "en-US") { return "Mozilla.Firefox" }

    return "Mozilla.Firefox.$Locale"
}


function Test-WinForgeFirefoxRunning {
    # Algum Firefox aberto? O instalador da Mozilla nunca fecha o navegador: por cima dele, a troca fica pela metade até
    # reiniciar.
    return (@(Get-Process -Name "firefox" -ErrorAction SilentlyContinue).Count -gt 0)
}


function Update-WinForgeFirefoxBrowser {
    <#
    O Firefox para todos. Não há um pedido de "atualizar agora" fora do próprio Firefox: a tarefa de atualização dele é
    por usuário e só baixa numa vez para instalar na seguinte. O que funciona sem abrir o navegador é o instalador da
    Mozilla por cima da instalação, que o winget baixa e roda em silêncio (o pacote do mesmo idioma). Devolve Name,
    Installed, Kind e Text.
    #>
    $browser = [PSCustomObject]@{ Name = "Mozilla Firefox"; Installed = $false; Kind = "Skipped"; Text = "" }
    $install = Get-WinForgeFirefoxInstall

    if ($null -eq $install) { return $browser }

    $browser.Installed = $true

    if ($install.Blocked) {
        $browser.Text = (Get-WinForgeText 'a atualização está desligada por uma política')
        return $browser
    }

    if ($install.Esr) {
        $browser.Text = (Get-WinForgeText 'a versão ESR se atualiza sozinha')
        return $browser
    }

    if (-not (Test-WinForgeWinget)) {
        $browser.Text = (Get-WinForgeText 'sem o winget; o Firefox se atualiza sozinho ao abrir')
        return $browser
    }

    if (Test-WinForgeFirefoxRunning) {
        $browser.Kind = "Warning"
        $browser.Text = (Get-WinForgeText 'estava aberto; feche o Firefox para atualizar')
        return $browser
    }

    $id = Get-WinForgeFirefoxPackageId -Locale $install.Locale
    $run = Invoke-WinForgeCapture -FilePath "winget" -Arguments @(Get-WinForgeWingetArguments -Operation Upgrade -PackageId $id -WingetSourceOnly)
    $code = [int]$run.ExitCode
    $after = Get-WinForgeFirefoxInstall
    $now = $(if ($null -ne $after) { [string]$after.Version } else { "" })

    # "Sem versão nova" e "o winget não reconhece esta instalação" não são falhas do Firefox.
    $hex = "0x{0:X8}" -f $code

    if ($now -eq $install.Version -and $hex -eq "0x8A15002B") { $code = 0 }

    if ($now -eq $install.Version -and $hex -eq "0x8A150014") {
        $browser.Text = (Get-WinForgeText 'o winget não reconhece esta instalação; o Firefox se atualiza sozinho ao abrir')
        return $browser
    }

    $failText = $(if ($code -ne 0) { [string](Get-WinForgeWingetExitResult -ExitCode $code).Detail } else { "" })
    $outcome = Get-WinForgeBrowserOutcome -Before $install.Version -After $now -ExitCode $code -FailText $failText

    $browser.Kind = $outcome.Kind
    $browser.Text = $outcome.Text
    return $browser
}


function Update-WinForgeBrowsers {
    <#
    A etapa dos navegadores do Otimizar: Edge, Chrome e Firefox, os que estiverem instalados, cada um pelo caminho que
    atualiza de verdade sem abrir o navegador. Uma linha por navegador instalado; os que não estão no PC não aparecem.
    Não pergunta nada.
    #>
    param (
        [switch]$Embedded,
        [switch]$PassThru
    )

    $title = (Get-WinForgeText 'Atualizar os navegadores')

    Enter-WinForgeAction -Title $title -Embedded:$Embedded

    $browsers = @()

    foreach ($command in @("Update-WinForgeEdgeBrowser", "Update-WinForgeChromeBrowser", "Update-WinForgeFirefoxBrowser")) {
        $name = @{ "Update-WinForgeEdgeBrowser" = "Microsoft Edge"; "Update-WinForgeChromeBrowser" = "Google Chrome"; "Update-WinForgeFirefoxBrowser" = "Mozilla Firefox" }[$command]
        Write-Progress -Activity $title -Status $name

        try {
            $browsers += @(& $command)
        }
        catch {
            $browsers += [PSCustomObject]@{ Name = $name; Installed = $true; Kind = "Failed"; Text = (Get-WinForgeText 'não atualizou ({0})' "$($_.Exception.Message.Trim().TrimEnd('.'))") }
        }
    }

    Write-Progress -Activity $title -Completed

    $installed = @($browsers | Where-Object { $_.Installed })

    foreach ($browser in $installed) {
        $type = switch ([string]$browser.Kind) { "Ok" { "Success" } "Skipped" { "Info" } "Warning" { "Warning" } default { "Error" } }
        Write-WinForgeStatus -Type $type -Message "$($browser.Name): $($browser.Text)."
    }

    # No resumo e no histórico, o nome curto e o que houve: "Edge: atualizado para 131.0; Chrome: já na versão mais nova".
    $detail = (@($installed | ForEach-Object { (Get-WinForgeText '{0}: {1}' "$(([string]$_.Name -split ' ')[-1])" "$($_.Text)") }) -join "; ")

    if ($installed.Count -eq 0) {
        $final = New-WinForgeResult -Kind Skipped -Detail (Get-WinForgeText 'nenhum navegador encontrado') -Title $title
    }
    elseif (@($installed | Where-Object { $_.Kind -eq "Failed" }).Count -eq $installed.Count) {
        $final = New-WinForgeResult -Kind Failed -Detail $detail -Title $title
    }
    elseif (@($installed | Where-Object { $_.Kind -in @("Failed", "Warning") }).Count -gt 0) {
        $final = New-WinForgeResult -Kind Warning -Detail $detail -Title $title
    }
    elseif (@($installed | Where-Object { $_.Kind -eq "Ok" }).Count -eq 0) {
        $final = New-WinForgeResult -Kind Skipped -Detail $detail -Title $title
    }
    else {
        $final = New-WinForgeResult -Kind Ok -Detail $detail -Title $title
    }

    if ($PassThru) { $final }
    Exit-WinForgeAction -Embedded:$Embedded -Result $final
}


function Update-WinForgeStoreApps {
    <#
    A etapa da Microsoft Store do Otimizar: o mesmo pedido do botão "Obter atualizações" da Store (o método
    UpdateScanMethod da ponte de gerenciamento do Windows). A Store baixa e instala em segundo plano; o WinForge não tem
    como acompanhar até o fim, e a faixa diz isso. Se o Windows recusar o pedido, a página de atualizações da Store abre
    para a pessoa clicar. Sem o modo Administrador o pedido nem é feito: a Microsoft documenta a ponte de gerenciamento só
    num prompt elevado, e a recusa viraria um aviso à toa; a página abre direto.
    #>
    param (
        [switch]$Embedded,
        [switch]$PassThru
    )

    $title = (Get-WinForgeText 'Atualizar aplicativos da Microsoft Store')

    Enter-WinForgeAction -Title $title -Embedded:$Embedded

    $final = $null

    if (-not $Embedded -and -not (Test-WinForgeAdministrator)) {
        if (Open-WinForgeShortcut -Name "MicrosoftStore") {
            Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Na página da Store que abriu, clique em Obter atualizações.')
            $final = New-WinForgeResult -Kind Ok -Detail (Get-WinForgeText 'a página de atualizações da Store foi aberta') -Title $title
            [void](Set-WinForgeResultView -Result $final -Headline (Get-WinForgeText 'Clique em Obter atualizações') -Note (Get-WinForgeText 'A página de atualizações da Microsoft Store abriu.'))
        }
        else {
            Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'O Windows não abriu a Microsoft Store.')
            $final = New-WinForgeResult -Kind Warning -Detail (Get-WinForgeText 'o Windows não abriu a Microsoft Store') -Title $title
            [void](Set-WinForgeResultView -Result $final -Headline (Get-WinForgeText 'A Microsoft Store não abriu') -Note (Get-WinForgeText 'Abra a Microsoft Store e clique em Obter atualizações.'))
        }

        if ($PassThru) { $final }
        Exit-WinForgeAction -Embedded:$Embedded -Result $final
        return
    }

    try {
        $instance = @(Get-CimInstance -Namespace "root\cimv2\mdm\dmmap" -ClassName "MDM_EnterpriseModernAppManagement_AppManagement01" -OperationTimeoutSec 30 -ErrorAction Stop) | Select-Object -First 1

        if ($null -eq $instance) { throw (Get-WinForgeText 'o Windows não respondeu ao pedido') }

        $call = Invoke-CimMethod -InputObject $instance -MethodName "UpdateScanMethod" -OperationTimeoutSec 60 -ErrorAction Stop
        # O ReturnValue é UInt32: um código de erro (0x8xxxxxxx) não cabe no [int] e vira o negativo correspondente, como
        # os códigos de saída que Format-WinForgeExitCode mostra em hexadecimal.
        $raw = [int64](Get-WinForgeJsonValue -Object $call -Name "ReturnValue" -Default 0)
        if ($raw -gt [int]::MaxValue) { $raw -= 4294967296 }
        $code = [int]$raw

        if ($code -ne 0) { throw (Get-WinForgeText 'código {0}' "$(Format-WinForgeExitCode -ExitCode $code)") }

        # Ela baixa e instala em segundo plano (minutos). Pedida sozinha, a lista de downloads da Store abre em seguida, para
        # a pessoa acompanhar; no Otimizar, não (a Store abriria por cima das outras etapas).
        Write-WinForgeStatus -Type Success -Message (Get-WinForgeText 'Pedido enviado à Microsoft Store: ela instala as atualizações em segundo plano.')
        $final = New-WinForgeResult -Kind Ok -Detail (Get-WinForgeText 'pedido enviado; a Store instala em segundo plano') -Title $title

        if (-not $Embedded) {
            # Open-WinForgeShortcut não lança erro: o que o Windows recusar vira uma linha na tela e $false.
            $shown = [bool](Open-WinForgeShortcut -Name "MicrosoftStore")

            [void](Set-WinForgeResultView -Result $final -Headline (Get-WinForgeText 'Pedido enviado à Microsoft Store') `
                    -Note (Get-WinForgeText 'Ela baixa e instala as atualizações em segundo plano{0}.' "$(if ($shown) { (Get-WinForgeText '; a lista de downloads abriu para você acompanhar') } else { '' })"))
        }
    }
    catch {
        $reason = ([string]$_.Exception.Message).Trim().TrimEnd('.')
        Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'O Windows não aceitou o pedido de atualização à Microsoft Store ({0}).' "$reason")

        # No Otimizar, a parte automática roda sem ninguém olhando: a Store não abre por cima das outras etapas (como no
        # pedido que deu certo), e a frase diz o que fazer depois. Pedida sozinha, a página abre para a pessoa clicar.
        if (-not $Embedded -and (Open-WinForgeShortcut -Name "MicrosoftStore")) {
            Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Na página da Store que abriu, clique em Obter atualizações.')
            $final = New-WinForgeResult -Kind Warning -Detail (Get-WinForgeText 'o Windows não aceitou o pedido; a página de atualizações da Store foi aberta') -Title $title
            [void](Set-WinForgeResultView -Result $final -Headline (Get-WinForgeText 'A Microsoft Store não aceitou o pedido') -Note (Get-WinForgeText 'Na página da Store que abriu, clique em Obter atualizações.'))
        }
        else {
            $final = New-WinForgeResult -Kind Warning -Detail (Get-WinForgeText 'o Windows não aceitou o pedido; abra a Store e clique em Obter atualizações') -Title $title
            if (-not $Embedded) { [void](Set-WinForgeResultView -Result $final -Headline (Get-WinForgeText 'A Microsoft Store não aceitou o pedido') -Note (Get-WinForgeText 'Abra a Microsoft Store e clique em Obter atualizações.')) }
        }
    }

    if ($PassThru) { $final }
    Exit-WinForgeAction -Embedded:$Embedded -Result $final
}


# ---------------------------------------------------------------------------
# Listar, buscar e instalar, desinstalar
# ---------------------------------------------------------------------------

function Get-WinForgeInstalledSoftwareCounts {
    # As contas da lista do "winget list": quantos programas, de que fonte e quantos têm atualização pelo winget.
    param (
        [AllowEmptyCollection()][object[]]$Packages = @()
    )

    $sources = @($Packages | ForEach-Object { Get-WinForgeWingetSourceLabel -Source ([string]$_.Fonte) })

    return [PSCustomObject]@{
        Total   = @($Packages).Count
        Winget  = @($sources | Where-Object { $_ -eq "winget" }).Count
        Store   = @($sources | Where-Object { $_ -eq "Microsoft Store" }).Count
        Other   = @($sources | Where-Object { $_ -eq "" }).Count
        # Sem a versão instalada ("Unknown"), o "winget upgrade" não mostra o programa: a conta é a mesma da tela de
        # atualizar.
        Updates = @($Packages | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_.Disponivel) -and ([string](Get-WinForgeJsonValue -Object $_ -Name "Versao" -Default "")).Trim() -notmatch '^(\?|Unknown|Desconhecid[ao])$' }).Count
    }
}


function Show-WinForgeInstalledSoftware {
    Enter-WinForgeAction -Title (Get-WinForgeText 'Listar programas instalados')

    # Resultado explícito: sem ele, a faixa dependeria de a lista de pacotes já ter sido atualizada nesta sessão (a primeira
    # consulta registra um "sucesso" e as seguintes não), e a mesma tela terminaria verde numa vez e sem faixa na outra.
    $final = New-WinForgeResult -Kind Failed -Detail (Get-WinForgeText 'a listagem não devolveu resultado')

    try {
        if (-not (Initialize-WinForgeWinget -OfferStore)) {
            Exit-WinForgeAction -Result (Get-WinForgeWingetMissingResult)
            return
        }

        Write-WinForgeWingetUserWarning

        # A tabela vai para os detalhes técnicos como o winget a gera (no console, para a tela); o resumo traz as contas.
        Write-Progress -Activity (Get-WinForgeText 'Listando os programas instalados') -Status (Get-WinForgeText 'consultando o winget')

        try {
            $listing = Read-WinForgeWingetList -Echo
        }
        finally {
            Write-Progress -Activity (Get-WinForgeText 'Listando os programas instalados') -Completed
        }

        Write-Host ""

        $all = @($listing.Rows)
        $exitResult = Get-WinForgeWingetExitResult -ExitCode $listing.ExitCode

        # Os componentes do Windows (VCLibs, a Store, o próprio winget) não são programas: ficam fora da conta.
        $installed = @($all | Where-Object { -not (Test-WinForgeWingetComponent -Package $_) })

        if ($all.Count -eq 0) {
            if ($exitResult.Kind -eq "Ok" -and -not [string]::IsNullOrWhiteSpace($listing.Text)) {
                # O winget respondeu, mas num formato que este código não lê: a tabela está nos detalhes técnicos.
                Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'O WinForge não reconheceu a tabela do winget; ela está nos detalhes técnicos.')
                $final = New-WinForgeResult -Kind Warning -Detail (Get-WinForgeText 'a tabela do winget não foi reconhecida')
            }
            else {
                $reason = $(if ($exitResult.Kind -eq "Ok") { (Get-WinForgeText 'o winget não respondeu') } else { $exitResult.Detail })
                Write-WinForgeStatus -Type Error -Message (Get-WinForgeText 'Não foi possível listar os programas: {0}.' "$reason")
                $final = New-WinForgeResult -Kind Failed -Detail (Get-WinForgeText 'não foi possível listar os programas: {0}' "$reason")
            }

            Exit-WinForgeAction -Result $final
            return
        }

        $counts = Get-WinForgeInstalledSoftwareCounts -Packages $installed

        # Na tela, só o total e as atualizações; a fonte, a versão e o ID de cada programa ficam na tabela do winget, nos
        # detalhes técnicos (no console, ela já apareceu acima).
        Write-WinForgeSection -Title (Get-WinForgeText 'Programas instalados')
        Write-WinForgeKeyValue -Label (Get-WinForgeText 'Total') -Value (Format-WinForgeCount -Count $counts.Total -One (Get-WinForgeText 'programa') -Many (Get-WinForgeText 'programas')) -LabelWidth 16
        if ($counts.Updates -gt 0) { Write-WinForgeKeyValue -Label (Get-WinForgeText 'Com atualização') -Value $counts.Updates -LabelWidth 16 }
        Write-Host ""

        $detail = Format-WinForgeCount -Count $counts.Total -One (Get-WinForgeText 'programa instalado') -Many (Get-WinForgeText 'programas instalados')

        if ($counts.Updates -gt 0) {
            $detail += (Get-WinForgeText '; {0} com atualização no winget' "$($counts.Updates)")
        }

        if ($exitResult.Kind -eq "Ok") {
            # Na janela, o título diz quantos; a frase, quantos têm versão nova; e o botão leva a atualizá-los.
            $final = New-WinForgeResult -Kind Ok -Detail $detail -Data @{ Count = $counts.Total }
            $updatesText = $(if ($counts.Updates -gt 0) { (Get-WinForgeText '{0} com versão nova no winget' "$(Format-WinForgeNumber -Value $counts.Updates)") } else { (Get-WinForgeText 'Nenhum com versão nova no winget') })
            [void](Set-WinForgeResultView -Result $final -Headline (Format-WinForgeCount -Count $counts.Total -One (Get-WinForgeText 'programa instalado') -Many (Get-WinForgeText 'programas instalados')) `
                    -Note (Get-WinForgeText '{0}; a lista completa está nos detalhes técnicos.' "$updatesText") `
                    -Next $(if ($counts.Updates -gt 0) { "updates.winget" } else { "" }) -NextLabel $(if ($counts.Updates -gt 0) { (Get-WinForgeText 'Atualizar programas') } else { "" }))
        }
        else {
            Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'O winget terminou com problemas ({0}); a lista pode estar incompleta.' "$($exitResult.Detail)")
            $final = New-WinForgeResult -Kind Warning -Detail (Get-WinForgeText 'a lista pode estar incompleta: {0}' "$($exitResult.Detail)") -Data @{ Count = $counts.Total }
        }

        if ($counts.Updates -gt 0) {
            Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Para atualizar, use Atualizações > Atualizar programas (winget).')
        }

        Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Para remover programas, use Programas > Desinstalar programas.')
    }
    catch {
        Write-WinForgeStatus -Type Error -Message (Get-WinForgeText 'Não foi possível listar os programas: {0}.' "$($_.Exception.Message.TrimEnd('.'))")
        $final = New-WinForgeResult -Kind Failed -Detail $_.Exception.Message
    }

    Exit-WinForgeAction -Result $final
}


function Find-WinForgeSoftware {
    # Busca no winget, deixa o usuário marcar os resultados e instala os escolhidos.
    Enter-WinForgeAction -Title (Get-WinForgeText 'Buscar e instalar programas')

    # O desfecho vem do que aconteceu, não da contagem de mensagens: desistir é "Cancelado", a busca sem resultado é "nada a
    # fazer" (cinza) e o único pacote que não instala é falha (vermelho), nunca "ressalva".
    $final = New-WinForgeResult -Kind Failed -Detail (Get-WinForgeText 'a busca não devolveu resultado')

    try {
        if (-not (Initialize-WinForgeWinget -OfferStore)) {
            Exit-WinForgeAction -Result (Get-WinForgeWingetMissingResult)
            return
        }

        Write-WinForgeWingetUserWarning -Context Install
        Write-Host ""
        $term = Read-WinForgeText -Message (Get-WinForgeText 'Nome (ou ID) do programa que deseja buscar')

        # Aspas dentro do termo quebram a passagem de argumentos no Windows PowerShell 5.1.
        $term = ($term -replace '["`]', " ").Trim()

        # Campo vazio é desistência (o botão Cancelar da janela devolve o mesmo vazio).
        if ([string]::IsNullOrWhiteSpace($term)) {
            Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'Operação cancelada.')
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Skipped -Detail (Get-WinForgeText 'cancelado pelo usuário'))
            return
        }

        if ($term.Length -gt 100) {
            $term = $term.Substring(0, 100)
        }

        Write-Progress -Activity (Get-WinForgeText 'Buscando programas') -Status (Get-WinForgeText 'procurando ''{0}'' no winget' "$term")

        try {
            $search = Invoke-WinForgeCapture -FilePath "winget" -Arguments @("search", "--query", $term, "--accept-source-agreements")
        }
        finally {
            Write-Progress -Activity (Get-WinForgeText 'Buscando programas') -Completed
        }

        # O mesmo ID pode vir duas vezes (o nome e uma etiqueta batem com a busca): uma opção por ID, na ordem do winget.
        $seenIds = @{}
        $results = @(ConvertFrom-WinForgeWingetTable -Lines $search.Lines | Where-Object { $key = ([string]$_.Id).ToLowerInvariant(); if ($seenIds.ContainsKey($key)) { $false } else { $seenIds[$key] = $true; $true } })

        Write-Host ""

        if ($results.Count -eq 0) {
            if (-not [string]::IsNullOrWhiteSpace($search.Text)) {
                $search.Lines | ForEach-Object { Write-Host $_ }
                Write-Host ""
            }

            # Sem tabela, o código de saída separa "nenhum pacote com esse nome" (0 ou 'não encontrado') de um erro de verdade.
            $notFound = ($search.ExitCode -eq 0 -or $search.ExitCode -eq -1978335212)

            if ($notFound) {
                Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'Nenhum programa encontrado para ''{0}''.' "$term")
                Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Tente outro nome, uma parte do nome ou o ID do programa (por exemplo, 7zip.7zip).')
                $final = New-WinForgeResult -Kind Skipped -Detail (Get-WinForgeText 'nenhum programa encontrado para ''{0}''' "$term")
                [void](Set-WinForgeResultView -Result $final -Headline (Get-WinForgeText 'Nenhum programa encontrado') -Note (Get-WinForgeText 'Tente outro nome, uma parte do nome ou o ID do programa (por exemplo, 7zip.7zip).'))
            }
            else {
                $reason = (Get-WinForgeWingetExitResult -ExitCode $search.ExitCode).Detail
                Write-WinForgeStatus -Type Error -Message (Get-WinForgeText 'A busca por ''{0}'' falhou: {1}.' "$term" "$reason")
                $final = New-WinForgeResult -Kind Failed -Detail (Get-WinForgeText 'a busca falhou: {0}' "$reason")
                [void](Set-WinForgeResultView -Result $final -Headline (Get-WinForgeText 'A busca não funcionou') -Note "$(([string]$reason).Substring(0, 1).ToUpper())$(([string]$reason).Substring(1)).")
            }

            Exit-WinForgeAction -Result $final
            return
        }

        $installedIds = Get-WinForgeInstalledWingetIds -Activity (Get-WinForgeText 'Buscando programas')

        $options = @(
            foreach ($package in $results) {
                $description = Format-WinForgeWingetPackageDescription -Package $package
                @{ Key = $package.Id; Label = $package.Nome; Description = $(if (Test-WinForgeWingetIdInstalled -Installed $installedIds -Id $package.Id) { (Get-WinForgeText 'já instalado · {0}' "$description") } else { $description }) }
            }
        )

        # Antes da lista: durante a pergunta de marcar, a janela mostra o resumo, e os detalhes técnicos ficam recolhidos.
        Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Alguns instaladores podem pedir para fechar programas abertos ou reiniciar o PC.')
        if (@($results | Where-Object { Test-WinForgeWingetIdInstalled -Installed $installedIds -Id $_.Id }).Count -gt 0) {
            Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'O que aparece como já instalado é atualizado, se houver versão nova.')
        }
        Write-Host ""

        $found = Format-WinForgeCount -Count $results.Count -One (Get-WinForgeText 'resultado') -Many (Get-WinForgeText 'resultados')
        $picked = Read-WinForgeMultiSelect -Message (Get-WinForgeText '{0} para ''{1}''. Marque o que deseja instalar' "$found" "$term") -Options $options -ConfirmLabel (Get-WinForgeText 'Instalar')

        if ($null -eq $picked -or @($picked).Count -eq 0) {
            Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'Operação cancelada.')
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Skipped -Detail (Get-WinForgeText 'cancelado pelo usuário'))
            return
        }

        $packages = @($results | Where-Object { @($picked) -contains $_.Id })
        $result = Get-WinForgeLastResult -Output (Invoke-WinForgeWingetPackages -Operation Install -Packages $packages)
        if ($null -ne $result) {
            $final = Set-WinForgeWingetPackagesView -Operation Install -Packages $packages -Result $result -Installed $installedIds
            Add-WinForgeInstalledProgramsChange -Packages $packages -Result $result -Installed $installedIds
            Request-WinForgeProgramsRestart -Operation Install -Result $final
        }
    }
    catch {
        Write-WinForgeStatus -Type Error -Message (Get-WinForgeText 'Não foi possível buscar ou instalar: {0}.' "$($_.Exception.Message.TrimEnd('.'))")
        $final = New-WinForgeResult -Kind Failed -Detail $_.Exception.Message
    }

    Exit-WinForgeAction -Result $final
}


function Get-WinForgeUninstallCommandPath {
    # O programa que um comando de desinstalação roda, quando o comando traz o caminho completo ('"C:\App\unins000.exe"
    # /SILENT' dá C:\App\unins000.exe). Vazio para comandos sem caminho (MsiExec.exe /X{...}, rundll32), que o Windows
    # acha sozinho.
    param ([string]$Command)

    $text = ([string]$Command).Trim()
    $path = ""

    if ($text -match '^"([^"]+)"') { $path = $Matches[1] }
    elseif ($text -match '^(.+?\.(exe|cmd|bat|com))(\s|$)') { $path = $Matches[1] }

    if ($path -notmatch '^([A-Za-z]:\\|\\\\)') { return "" }

    return $path
}


function ConvertFrom-WinForgeArpKey {
    # Uma chave de Uninstall do registro vira uma entrada de Get-WinForgeArpEntries ($null se não der para lê-la).
    param (
        [Parameter(Mandatory)]$Key,
        [Parameter(Mandatory)][string]$KeyName,
        [string]$Scope,
        [bool]$Wow
    )

    $sub = $null

    try {
        $sub = $Key.OpenSubKey($KeyName)
        if ($null -eq $sub) { return $null }

        $read = { param ($Name) $value = $sub.GetValue($Name); if ($null -eq $value) { "" } else { ([string]$value).Trim() } }

        # Um desinstalador de verdade: o Windows Installer, ou um comando cujo programa ainda está no disco (sem ele, a
        # entrada sobrou de um programa apagado à mão, e o winget não teria o que rodar).
        $commands = @((& $read "QuietUninstallString"), (& $read "UninstallString") | Where-Object { $_ })
        $runnable = @($commands | Where-Object { $exe = Get-WinForgeUninstallCommandPath -Command $_; -not $exe -or (Test-Path -LiteralPath $exe -PathType Leaf) })
        $hasUninstaller = ((& $read "WindowsInstaller") -eq "1" -or $runnable.Count -gt 0)

        # Atualizações e partes de outro programa saem junto com ele; NoRemove é o fabricante dizendo que não se remove
        # por ali (o botão Desinstalar do Windows fica apagado); SystemComponent é peça escondida do próprio sistema.
        $child = ((& $read "ParentKeyName") -ne "" -or (& $read "ReleaseType") -match '^(Update|Hotfix|Security Update|Service Pack)$')
        $locked = ((& $read "NoRemove") -eq "1" -or (& $read "SystemComponent") -eq "1")

        return [PSCustomObject]@{
            Scope       = $Scope
            Wow         = $Wow
            KeyName     = $KeyName
            DisplayName = (& $read "DisplayName")
            Removable   = ($hasUninstaller -and -not $child -and -not $locked)
        }
    }
    catch {
        return $null
    }
    finally {
        if ($null -ne $sub) { $sub.Dispose() }
    }
}


function Get-WinForgeArpEntries {
    <#
    As entradas de "Aplicativos instalados" do registro (as chaves Uninstall), como o winget as enxerga nos IDs locais
    (ARP\Machine\X64\..., ARP\Machine\X86\..., ARP\User\X64\...): Scope Machine nas duas visões do HKLM (Wow: a de 32
    bits) e User no HKCU. Cada uma traz KeyName, DisplayName e Removable (ConvertFrom-WinForgeArpKey). Só lê o registro.
    Vazio quando o registro não pode ser lido.
    #>
    $entries = New-Object System.Collections.Generic.List[PSObject]
    $path = "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
    $roots = @(
        @{ Hive = "LocalMachine"; View = "Registry64"; Scope = "Machine"; Wow = $false },
        @{ Hive = "CurrentUser"; View = "Default"; Scope = "User"; Wow = $false }
    )

    # Num Windows de 32 bits só há uma visão do HKLM.
    if ([Environment]::Is64BitOperatingSystem) {
        $roots += @{ Hive = "LocalMachine"; View = "Registry32"; Scope = "Machine"; Wow = $true }
    }

    foreach ($root in $roots) {
        $base = $null
        $key = $null

        try {
            $base = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]$root.Hive, [Microsoft.Win32.RegistryView]$root.View)
            $key = $base.OpenSubKey($path)

            if ($null -ne $key) {
                foreach ($keyName in @($key.GetSubKeyNames())) {
                    $entry = ConvertFrom-WinForgeArpKey -Key $key -KeyName $keyName -Scope $root.Scope -Wow $root.Wow
                    if ($null -ne $entry) { $entries.Add($entry) }
                }
            }
        }
        catch {
            Write-Verbose "Não foi possível ler $($root.Hive)\${path}: $($_.Exception.Message)"
        }
        finally {
            if ($null -ne $key) { $key.Dispose() }
            if ($null -ne $base) { $base.Dispose() }
        }
    }

    return $entries.ToArray()
}


function Find-WinForgeArpEntry {
    # A entrada do registro de um ID local do winget ("ARP\Machine\X86\Microsoft Edge Update", "ARP\User\X64\Discord"),
    # mesmo com o ID cortado com reticências pela tabela. $null quando não há exatamente uma entrada que corresponda.
    param (
        [string]$Id,
        [AllowEmptyCollection()][object[]]$Entries = @()
    )

    if ($Id -notmatch '^ARP\\(Machine|User)\\([^\\]+)\\(.+)$') { return $null }

    $scope = $Matches[1]
    $wow = ($Matches[2] -eq "X86")
    $rest = $Matches[3]
    $truncated = Test-WinForgeWingetIdTruncated -Id $Id
    $keyName = Get-WinForgeTruncatedPrefix -Text $rest

    if ($keyName.Length -eq 0) { return $null }

    $same = @($Entries | Where-Object {
            $null -ne $_ -and [string]$_.Scope -eq $scope -and $(if ($truncated) { ([string]$_.KeyName).StartsWith($keyName, [StringComparison]::OrdinalIgnoreCase) } else { [string]::Equals([string]$_.KeyName, $keyName, [StringComparison]::OrdinalIgnoreCase) })
        })

    # A mesma chave nas duas visões do HKLM: a do ID (X86 é a de 32 bits) desempata.
    if ($same.Count -gt 1 -and $scope -eq "Machine") { $same = @($same | Where-Object { [bool]$_.Wow -eq $wow }) }

    if ($same.Count -eq 1) { return $same[0] }

    return $null
}


function Get-WinForgeAppxInventory {
    # Os pacotes de aplicativo do usuário atual (Get-AppxPackage), para conferir as linhas MSIX\ do winget. $null quando o
    # Windows não responde ou não tem o comando.
    if ($null -eq (Get-Command -Name "Get-AppxPackage" -ErrorAction SilentlyContinue)) { return $null }

    try {
        return ,@(Get-AppxPackage -ErrorAction Stop | Where-Object { $null -ne $_ })
    }
    catch {
        return $null
    }
}


function Find-WinForgeAppxPackage {
    # O pacote de um ID MSIX\ do winget ("MSIX\Microsoft.Foo_1.2.0.0_x64__8wekyb3d8bbwe"), mesmo com o ID cortado com
    # reticências pela tabela. $null quando não há exatamente um.
    param (
        [string]$Id,
        [AllowEmptyCollection()][object[]]$Packages = @()
    )

    if ($Id -notmatch '^MSIX\\(.+)$') { return $null }

    $rest = $Matches[1]
    $truncated = Test-WinForgeWingetIdTruncated -Id $Id
    $fullName = Get-WinForgeTruncatedPrefix -Text $rest

    if ($fullName.Length -eq 0) { return $null }

    $same = @($Packages | Where-Object {
            $candidate = [string](Get-WinForgeJsonValue -Object $_ -Name "PackageFullName" -Default "")
            if ($truncated) { $candidate.StartsWith($fullName, [StringComparison]::OrdinalIgnoreCase) } else { [string]::Equals($candidate, $fullName, [StringComparison]::OrdinalIgnoreCase) }
        })

    if ($same.Count -eq 1) { return $same[0] }

    return $null
}


function Test-WinForgeAppxPackageSystem {
    # Pacotes de aplicativo que o Windows não deixa remover para um usuário: componentes (framework), os marcados como não
    # removíveis e os assinados como parte do sistema. O winget tentaria e terminaria com erro.
    param ([Parameter(Mandatory)]$Package)

    return ([bool](Get-WinForgeJsonValue -Object $Package -Name "IsFramework" -Default $false) -or
        [bool](Get-WinForgeJsonValue -Object $Package -Name "NonRemovable" -Default $false) -or
        [string](Get-WinForgeJsonValue -Object $Package -Name "SignatureKind" -Default "") -eq "System")
}


function Resolve-WinForgeWingetTruncatedId {
    <#
    O ID inteiro de um pacote que a tabela do winget mostrou cortado: sem uma janela de console (a saída capturada), o
    winget ajusta a tabela a 120 colunas e corta com reticências os IDs longos. A consulta só daquele começo ("winget list
    --id <começo>") devolve uma tabela curta, em que o ID cabe. "" quando não há exatamente um pacote que comece assim.
    #>
    param ([string]$Id)

    # Uma barra no fim atrapalha a passagem de argumentos com espaços no Windows PowerShell 5.1; o começo sem ela basta.
    $prefix = (Get-WinForgeTruncatedPrefix -Text $Id).TrimEnd('\').Trim()

    if ($prefix.Length -lt 4 -or $prefix -match '^-' -or $prefix -match '["`;|&<>]') { return "" }

    try {
        $query = Invoke-WinForgeCapture -FilePath "winget" -Arguments @("list", "--id", $prefix, "--accept-source-agreements")
        $rows = @(ConvertFrom-WinForgeWingetTable -Lines $query.Lines)
    }
    catch {
        return ""
    }

    $ids = @($rows | ForEach-Object { [string]$_.Id } | Where-Object { -not (Test-WinForgeWingetIdTruncated -Id $_) -and $_.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase) } | Sort-Object -Unique)

    if ($ids.Count -eq 1) { return $ids[0] }

    return ""
}


function Get-WinForgeUninstallCandidates {
    <#
    O que a lista de desinstalar oferece, a partir das linhas do "winget list" (Nome, Id, Versao, Fonte): objetos com o
    ID inteiro e Versoes (quantas versões instaladas o mesmo ID tem; desinstalar remove todas). Só entra o que o WinForge
    consegue de fato desinstalar pelo winget, para que a lista não ofereça o que terminaria em erro ou não sairia:
    - IDs que a tabela cortou com reticências são completados: pelo registro (ARP\), pelos pacotes de aplicativo (MSIX\)
      ou por uma consulta curta ao winget (os demais, até WinForgeTruncatedIdQueryLimit). Sem o ID inteiro, o winget não
      acharia o pacote, e a linha fica de fora.
    - Programas do registro (ARP\): fora quando não têm desinstalador (ou ele sumiu do disco), quando o fabricante travou a
      remoção (NoRemove), quando são componente escondido do sistema ou atualização de outro programa. Um programa de uma
      fonte (winget, Microsoft Store) cujas entradas do registro com o mesmo nome estão todas assim também fica de fora.
    - Aplicativos (MSIX\): fora quando o Windows os marca como parte do sistema, não removíveis ou componentes.
    - Componentes do Windows, bibliotecas que outros programas usam e o Edge (Test-WinForgeWingetUninstallBlocked).
    Usuários, 32 e 64 bits e aplicativos da Microsoft Store instalados pela pessoa entram como o winget os lista.
    #>
    param ([AllowEmptyCollection()][object[]]$Packages = @())

    $rows = @($Packages | Where-Object { $null -ne $_ })

    if ($rows.Count -eq 0) { return @() }

    $arp = @(Get-WinForgeArpEntries)
    $appx = $null
    $appxRead = $false
    $queries = 0
    $byId = [ordered]@{}

    foreach ($row in $rows) {
        $listedId = ([string](Get-WinForgeJsonValue -Object $row -Name "Id" -Default "")).Trim()
        $id = $listedId
        $name = ([string](Get-WinForgeJsonValue -Object $row -Name "Nome" -Default "")).Trim()
        $entry = $null
        $app = $null

        if ($id -match '^MSIX\\' -and -not $appxRead) {
            $appx = Get-WinForgeAppxInventory
            $appxRead = $true
        }

        # 1. O ID inteiro.
        if ($id -match '^ARP\\') {
            $entry = Find-WinForgeArpEntry -Id $id -Entries $arp
            if ($null -ne $entry -and (Test-WinForgeWingetIdTruncated -Id $id) -and $id -match '^(ARP\\[^\\]+\\[^\\]+\\)') { $id = $Matches[1] + [string]$entry.KeyName }
        }
        elseif ($id -match '^MSIX\\' -and $null -ne $appx) {
            $app = Find-WinForgeAppxPackage -Id $id -Packages $appx
            if ($null -ne $app -and (Test-WinForgeWingetIdTruncated -Id $id)) { $id = "MSIX\" + [string]$app.PackageFullName }
        }

        if (Test-WinForgeWingetIdTruncated -Id $id) {
            if ($queries -ge $script:WinForgeTruncatedIdQueryLimit) { continue }

            $queries++
            $id = Resolve-WinForgeWingetTruncatedId -Id $id

            if (-not $id) { continue }
            if ($id -match '^ARP\\') { $entry = Find-WinForgeArpEntry -Id $id -Entries $arp }
            if ($id -match '^MSIX\\' -and $null -ne $appx) { $app = Find-WinForgeAppxPackage -Id $id -Packages $appx }
        }

        # 2. Se dá para desinstalar.
        if ($null -ne $entry -and -not $entry.Removable) { continue }
        if ($null -ne $app -and (Test-WinForgeAppxPackageSystem -Package $app)) { continue }

        if ($id -notmatch '^(ARP|MSIX)\\' -and $name -and -not (Test-WinForgeWingetIdTruncated -Id $name)) {
            $same = @($arp | Where-Object { [string]::Equals([string]$_.DisplayName, $name, [StringComparison]::OrdinalIgnoreCase) })
            if ($same.Count -gt 0 -and @($same | Where-Object { $_.Removable }).Count -eq 0) { continue }
        }

        # O nome do registro é inteiro; o da tabela pode ter sido cortado.
        if ($null -ne $entry -and $entry.DisplayName -and (-not $name -or (Test-WinForgeWingetIdTruncated -Id $name) -or $name -eq $listedId)) { $name = [string]$entry.DisplayName }

        $candidate = [PSCustomObject]@{
            Nome    = $(if ($name) { $name } else { $id })
            Id      = $id
            Versao  = [string](Get-WinForgeJsonValue -Object $row -Name "Versao" -Default "")
            Fonte   = [string](Get-WinForgeJsonValue -Object $row -Name "Fonte" -Default "")
            Versoes = 1
        }

        if (Test-WinForgeWingetUninstallBlocked -Package $candidate) { continue }

        # Duas versões instaladas do mesmo pacote aparecem com o mesmo ID: uma opção só, que desinstala as duas.
        $key = $id.ToLowerInvariant()

        if ($byId.Contains($key)) { $byId[$key].Versoes++ }
        else { $byId[$key] = $candidate }
    }

    return @($byId.Values | Sort-Object -Property Nome, Id)
}


function Write-WinForgeUninstallPreview {
    <#
    Antes da confirmação de desinstalar: a seção "Vão ser desinstalados", com uma linha "nome : versão" por programa, e um
    aviso para os marcados que são drivers de um aparelho do PC.
    #>
    param ([Parameter(Mandatory)][object[]]$Packages)

    Write-WinForgeSection -Title (Get-WinForgeText 'Vão ser desinstalados')

    foreach ($package in $Packages) {
        $name = ([string]$package.Nome).Trim()
        if ($name.Length -gt 48) { $name = $name.Substring(0, 45) + "..." }
        $version = ([string]$package.Versao).Trim()
        $versions = [int](Get-WinForgeJsonValue -Object $package -Name "Versoes" -Default 1)
        $versionText = $(if ($versions -gt 1) { (Get-WinForgeText '{0} versões' "$versions") } elseif ($version -and $version -notmatch '^(\?|Unknown|Desconhecid[ao])$') { (Get-WinForgeText 'versão {0}' "$version") } else { (Get-WinForgeText 'versão não informada') })

        Write-WinForgeKeyValue -Label $name -Value $versionText -LabelWidth 32
    }

    Write-Host ""

    $drivers = @($Packages | Where-Object { Get-WinForgeWingetPackageCaution -Package $_ } | ForEach-Object { [string]$_.Nome })

    if ($drivers.Count -eq 1) {
        Write-WinForgeStatus -Type Warning -Notice -Message (Get-WinForgeText '{0} é driver de um aparelho do PC: o aparelho pode parar de funcionar.' "$($drivers[0])")
    }
    elseif ($drivers.Count -gt 1) {
        Write-WinForgeStatus -Type Warning -Notice -Message (Get-WinForgeText '{0} são drivers de aparelhos do PC: os aparelhos podem parar de funcionar.' "$(Join-WinForgeList -Items $drivers)")
    }
}


function Uninstall-WinForgeSoftware {
    Enter-WinForgeAction -Title (Get-WinForgeText 'Desinstalar programas')

    # Mesmo critério de "Buscar e instalar": desistir é "Cancelado"; o programa que não sai é falha.
    $final = New-WinForgeResult -Kind Failed -Detail (Get-WinForgeText 'a desinstalação não devolveu resultado')

    try {
        if (-not (Initialize-WinForgeWinget -OfferStore)) {
            Exit-WinForgeAction -Result (Get-WinForgeWingetMissingResult)
            return
        }

        Write-WinForgeWingetUserWarning
        Write-Progress -Activity (Get-WinForgeText 'Desinstalar programas') -Status (Get-WinForgeText 'lendo a lista de programas instalados')

        try {
            $listing = Read-WinForgeWingetList
            $all = @($listing.Rows)

            # Só entra o que o WinForge consegue de fato desinstalar; o que fica de fora, e por quê, está em
            # Get-WinForgeUninstallCandidates (componentes do Windows, bibliotecas, entradas sem desinstalador...).
            $installed = @(Get-WinForgeUninstallCandidates -Packages $all)
        }
        finally {
            Write-Progress -Activity (Get-WinForgeText 'Desinstalar programas') -Completed
        }

        Write-Host ""

        if ($all.Count -gt 0 -and $installed.Count -eq 0) {
            Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Nenhum programa para desinstalar.')
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Skipped -Detail (Get-WinForgeText 'nenhum programa para desinstalar'))
            return
        }

        if ($installed.Count -eq 0) {
            $listing.Lines | ForEach-Object { Write-Host $_ }
            Write-Host ""

            $exitResult = Get-WinForgeWingetExitResult -ExitCode $listing.ExitCode
            $reason = $(if ($exitResult.Kind -ne "Ok") { $exitResult.Detail } elseif ([string]::IsNullOrWhiteSpace($listing.Text)) { (Get-WinForgeText 'o winget não respondeu') } else { (Get-WinForgeText 'o WinForge não reconheceu a tabela do winget') })

            Write-WinForgeStatus -Type Error -Message (Get-WinForgeText 'Não foi possível ler a lista de programas: {0}.' "$reason")
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Failed -Detail (Get-WinForgeText 'não foi possível ler a lista de programas: {0}' "$reason"))
            return
        }

        $options = @(
            foreach ($package in $installed) {
                $caution = Get-WinForgeWingetPackageCaution -Package $package
                $description = Format-WinForgeWingetPackageDescription -Package $package
                @{ Key = $package.Id; Label = $package.Nome; Description = $(if ($caution -and $description) { (Get-WinForgeText 'Atenção: {0} · {1}' "$caution" "$description") } elseif ($caution) { (Get-WinForgeText 'Atenção: {0}' "$caution") } else { $description }) }
            }
        )

        # Sem "Marcar todos": desinstalar é de um em um, e um clique não pode marcar a lista inteira.
        $count = Format-WinForgeCount -Count $installed.Count -One (Get-WinForgeText 'programa instalado') -Many (Get-WinForgeText 'programas instalados')
        $picked = Read-WinForgeMultiSelect -Message (Get-WinForgeText 'O que desinstalar? ({0})' "$count") -Options $options -NoSelectAll -ConfirmLabel (Get-WinForgeText 'Desinstalar')

        if ($null -eq $picked -or @($picked).Count -eq 0) {
            Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'Operação cancelada.')
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Skipped -Detail (Get-WinForgeText 'cancelado pelo usuário'))
            return
        }

        $packages = @($installed | Where-Object { @($picked) -contains $_.Id })

        # Na hora de decidir, a pessoa revê o que marcou (com a versão) e os avisos de cada um, que na lista eram só texto
        # cinza. Até três nomes, a própria pergunta os diz; com mais, ela aponta para a lista.
        Write-WinForgeUninstallPreview -Packages $packages
        $names = @($packages | ForEach-Object { [string]$_.Nome })
        $question = $(if ($names.Count -le 3) { Get-WinForgeSelectionQuestion -Verb (Get-WinForgeText 'Desinstalar') -Names $names -Many (Get-WinForgeText 'programas') } else { (Get-WinForgeText 'Desinstalar os {0} programas listados acima?' "$($names.Count)") })

        if (-not (Confirm-WinForgeAction $question -DefaultKey N -YesLabel (Get-WinForgeText 'Desinstalar') -NoLabel (Get-WinForgeText 'Cancelar'))) {
            Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'Operação cancelada.')
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Skipped -Detail (Get-WinForgeText 'cancelado pelo usuário'))
            return
        }

        $result = Get-WinForgeLastResult -Output (Invoke-WinForgeWingetPackages -Operation Uninstall -Packages $packages)
        if ($null -ne $result) { $final = Set-WinForgeWingetPackagesView -Operation Uninstall -Packages $packages -Result $result }

        # Só os que saíram de fato da lista (ou saem no próximo reinício) vão para o Histórico e para a busca de restos.
        $doneIds = @(Get-WinForgeResultData -Result $final -Name "SucceededIds")
        $removed = @($packages | Where-Object { $doneIds -contains [string]$_.Id })

        if ($final.Kind -in @("Ok", "Warning") -and $removed.Count -gt 0) {
            [void](Add-WinForgeChange -Action (Get-WinForgeText 'Programas desinstalados') -Text (Join-WinForgeList -Items @($removed | ForEach-Object { [string]$_.Nome })))

            foreach ($package in $removed) { Add-WinForgeUninstalledProgram -Name ([string]$package.Nome) -Id ([string]$package.Id) }

            Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Para procurar restos, use Limpeza > Restos de programas desinstalados.')
        }

        Request-WinForgeProgramsRestart -Operation Uninstall -Result $final
    }
    catch {
        Write-WinForgeStatus -Type Error -Message (Get-WinForgeText 'Não foi possível desinstalar: {0}.' "$($_.Exception.Message.TrimEnd('.'))")
        $final = New-WinForgeResult -Kind Failed -Detail $_.Exception.Message
    }

    Exit-WinForgeAction -Result $final
}


# ---------------------------------------------------------------------------
# Programas essenciais
# ---------------------------------------------------------------------------

function Add-WinForgeInstalledProgramsChange {
    <#
    O Histórico de mudanças anota os programas que o winget de fato mudou (ChangedIds): os que não estavam no PC como
    instalados; os que já estavam (Installed, de Get-WinForgeInstalledWingetIds) como atualizados.
    #>
    param (
        [Parameter(Mandatory)][object[]]$Packages,
        $Result,
        $Installed = $null
    )

    $changed = @(Get-WinForgeResultData -Result $Result -Name "ChangedIds")
    $done = @($Packages | Where-Object { $changed -contains [string]$_.Id })
    $updated = @($done | Where-Object { Test-WinForgeWingetIdInstalled -Installed $Installed -Id $_.Id } | ForEach-Object { [string]$_.Nome })
    $new = @($done | Where-Object { -not (Test-WinForgeWingetIdInstalled -Installed $Installed -Id $_.Id) } | ForEach-Object { [string]$_.Nome })

    if ($new.Count -gt 0) { [void](Add-WinForgeChange -Action (Get-WinForgeText 'Programas instalados') -Text (Join-WinForgeList -Items $new)) }
    if ($updated.Count -gt 0) { [void](Add-WinForgeChange -Action (Get-WinForgeText 'Programas atualizados') -Text (Join-WinForgeList -Items $updated)) }
}


function Get-WinForgeEssentialSoftwareCatalog {
    # A lista vem do catálogo (Catalog.psm1): a cópia baixada em Sobre o WinForge > Conferir dados online, quando é mais
    # nova que a embutida; senão, a embutida. Descricao: o que o programa é, para quem não conhece o nome.
    return @((Get-WinForgeCatalog).Essentials)
}


function Get-WinForgeEssentialCategoryRank {
    <#
    A posição de uma categoria na lista de essenciais: primeiro o que quase todo mundo usa, por último as ferramentas para
    programadores ("Desenvolvimento" é o nome antigo dessa categoria, num catálogo baixado de antes). Uma categoria que
    esta versão não conhece (de um catálogo baixado mais novo) fica antes da dos programadores.
    #>
    param ([string]$Category)

    # As categorias são as do catálogo, em português (a tela traduz na hora de mostrar).
    $order = @("Básico", "Comunicação e mídia", "Produtividade", "Jogos")
    $index = [array]::IndexOf($order, [string]$Category)

    if ($index -ge 0) { return $index }
    if ($Category -in @("Para programadores", "Desenvolvimento")) { return 1000 }

    return 100
}


function Install-WinForgeEssentialSoftware {
    Enter-WinForgeAction -Title (Get-WinForgeText 'Instalar programas essenciais')

    # Mesmo critério de "Buscar e instalar": desistir é "Cancelado"; o único programa que não instala é falha.
    $final = New-WinForgeResult -Kind Failed -Detail (Get-WinForgeText 'a instalação não devolveu resultado')

    try {
        if (-not (Initialize-WinForgeWinget -OfferStore)) {
            Exit-WinForgeAction -Result (Get-WinForgeWingetMissingResult)
            return
        }

        Write-WinForgeWingetUserWarning -Context Install

        $catalog = @(Get-WinForgeEssentialSoftwareCatalog | Sort-Object @{ Expression = { Get-WinForgeEssentialCategoryRank -Category $_.Categoria } }, Categoria, Nome)

        # Quem já tem o programa vê isso na lista, em vez de reinstalar sem saber.
        $installedIds = Get-WinForgeInstalledWingetIds -Activity (Get-WinForgeText 'Instalar programas essenciais')
        $already = @($catalog | Where-Object { Test-WinForgeWingetIdInstalled -Installed $installedIds -Id $_.Id })

        $options = @(
            foreach ($entry in $catalog) {
                # O catálogo vem em português (o embutido e o baixado): a categoria e a descrição se traduzem aqui.
                $description = "$(Get-WinForgeText ([string]$entry.Categoria)) · $(Get-WinForgeText ([string]$entry.Descricao))"
                @{ Key = $entry.Id; Label = $entry.Nome; Description = $(if (Test-WinForgeWingetIdInstalled -Installed $installedIds -Id $entry.Id) { (Get-WinForgeText 'já instalado · {0}' "$description") } else { $description }) }
            }
        )

        # Antes da lista: durante a pergunta de marcar, a janela mostra o resumo, e os detalhes técnicos ficam recolhidos.
        Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Alguns instaladores podem pedir para fechar programas abertos ou reiniciar o PC.')
        if ($already.Count -gt 0) {
            Write-WinForgeStatus -Type Info -Message (Get-WinForgeText '{0} se houver versão nova.' "$(if ($already.Count -eq 1) { (Get-WinForgeText '1 programa da lista já está instalado: marcado, ele é atualizado') } else { (Get-WinForgeText '{0} programas da lista já estão instalados: marcados, eles são atualizados' "$($already.Count)") })")
        }
        else {
            Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'O que já estiver instalado é atualizado, se houver versão nova.')
        }
        Write-Host ""

        $picked = Read-WinForgeMultiSelect -Message (Get-WinForgeText 'Escolha os programas para instalar') -Options $options -ConfirmLabel (Get-WinForgeText 'Instalar')

        if ($null -eq $picked -or @($picked).Count -eq 0) {
            Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'Operação cancelada.')
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Skipped -Detail (Get-WinForgeText 'cancelado pelo usuário'))
            return
        }

        $packages = @($catalog | Where-Object { @($picked) -contains $_.Id })

        $result = Get-WinForgeLastResult -Output (Invoke-WinForgeWingetPackages -Operation Install -Packages $packages -WingetSourceOnly)
        if ($null -ne $result) {
            $final = Set-WinForgeWingetPackagesView -Operation Install -Packages $packages -Result $result -Installed $installedIds
            Add-WinForgeInstalledProgramsChange -Packages $packages -Result $result -Installed $installedIds
            Request-WinForgeProgramsRestart -Operation Install -Result $final
        }
    }
    catch {
        Write-WinForgeStatus -Type Error -Message (Get-WinForgeText 'Não foi possível instalar: {0}.' "$($_.Exception.Message.TrimEnd('.'))")
        $final = New-WinForgeResult -Kind Failed -Detail $_.Exception.Message
    }

    Exit-WinForgeAction -Result $final
}


Export-ModuleMember -Function *
