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


# ---------------------------------------------------------------------------
# Disponibilidade do winget
# ---------------------------------------------------------------------------

function Test-WinForgeWinget {
    return [bool](Get-Command -Name "winget" -CommandType Application -ErrorAction SilentlyContinue)
}


function Get-WinForgeWingetMissingDetail {
    # O detalhe da faixa quando falta o winget, igual em todas as telas de Programas.
    return "o Instalador de Aplicativo (winget) não está neste PC"
}


function Write-WinForgeWingetMissing {
    <#
    O que dizer quando falta o winget, que a pessoa conhece como Instalador de Aplicativo. É o caso mais comum logo depois
    de formatar: o Windows recém-instalado só o registra quando a Microsoft Store se atualiza. -OfferStore pergunta se
    abre a página dele na Store (nas telas de Programas, em que a pessoa quer instalar ou remover algo agora).
    #>
    param ([switch]$OfferStore)

    Write-WinForgeStatus -Type Error -Message "O Instalador de Aplicativo da Microsoft, que o WinForge usa para instalar programas, não está neste PC."
    Write-WinForgeStatus -Type Info -Message "Num Windows recém-instalado, ele chega quando a Microsoft Store se atualiza. Abra a Store, deixe-a atualizar e tente de novo."

    if (-not $OfferStore) { return }

    Write-Host ""

    if (Confirm-WinForgeAction -Message "Abrir o Instalador de Aplicativo na Microsoft Store agora?" -DefaultKey S) {
        [void](Open-WinForgeAppInstallerPage)
    }
}


function Open-WinForgeAppInstallerPage {
    # A página do Instalador de Aplicativo (o winget) na Microsoft Store. Devolve $true se o Windows aceitou abrir.
    try {
        Start-Process -FilePath "ms-windows-store://pdp/?ProductId=9NBLGGH4NNS1" -ErrorAction Stop
        Write-WinForgeStatus -Type Info -Notice -Message "Abrindo a Microsoft Store. Depois de instalar ou atualizar o Instalador de Aplicativo, use esta ação de novo."
        return $true
    }
    catch {
        Write-WinForgeStatus -Type Warning -Notice -Message "O Windows não abriu a Microsoft Store ($(([string]$_.Exception.Message).Trim().TrimEnd('.'))). Abra a Store pelo Menu Iniciar e procure por Instalador de Aplicativo."
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
    Write-Progress -Activity "Preparando o winget" -Status "atualizando a lista de pacotes"

    try {
        $source = Invoke-WinForgeCapture -FilePath "winget" -Arguments @("source", "update", "--name", "winget", "--disable-interactivity")
    }
    finally {
        Write-Progress -Activity "Preparando o winget" -Completed
    }

    if ($source.ExitCode -ne 0) {
        Write-WinForgeStatus -Type Warning -Message "Não foi possível atualizar a lista de pacotes do winget; a consulta usa a lista guardada neste PC."
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

    Write-WinForgeStatus -Type Warning -Message "O WinForge está elevado como $currentUser."

    switch ($Context) {
        "Install" { Write-WinForgeStatus -Type Info -Message "Programas que se instalam só para o usuário ficam no perfil de $currentUser, não no de $interactiveUser." }
        "Upgrade" { Write-WinForgeStatus -Type Info -Message "Programas instalados só para $interactiveUser podem não aparecer na lista de atualizações." }
        default { Write-WinForgeStatus -Type Info -Message "Pacotes exclusivos de $interactiveUser podem não aparecer neste contexto." }
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

        if ($line -match "\bId\b" -and ($line -match "\bName\b" -or $line -match "\bNome\b") -and ($line -match "\bVersion\b" -or $line -match "Vers")) {
            $headerIndex = $i
            break
        }
    }

    if ($headerIndex -lt 0) {
        return @()
    }

    $header = $lineArray[$headerIndex]
    $nameStart = Get-WinForgeTextColumnIndex -Text $header -Names @("Name", "Nome")
    $idStart = Get-WinForgeTextColumnIndex -Text $header -Names @("Id")
    $versionStart = Get-WinForgeTextColumnIndex -Text $header -Names @("Version", "Versão", "Versao")
    $availableStart = Get-WinForgeTextColumnIndex -Text $header -Names @("Available", "Disponível", "Disponivel")
    $matchStart = Get-WinForgeTextColumnIndex -Text $header -Names @("Match", "Correspondência", "Correspondencia")
    $sourceStart = Get-WinForgeTextColumnIndex -Text $header -Names @("Source", "Fonte", "Origem")

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

        if ($line -match "^[0-9]+\s+(upgrades?|packages?|pacotes?|atualiza)" -or $line -match "Nenhuma atualiza" -or $line -match "No available upgrade") {
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
    # "Não há o que atualizar", pelo código de saída do winget (0x8A150014 = nenhum pacote encontrado e 0x8A15002B =
    # nenhuma atualização aplicável: não mudam com o idioma) ou, na falta dele, pelas frases em inglês e português.
    param (
        [string]$OutputText,
        [int]$ExitCode = 0
    )

    return (
        $ExitCode -in @(-1978335212, -1978335189) -or
        $OutputText -match "(?i)No installed package found matching input criteria" -or
        $OutputText -match "(?i)No available upgrade found" -or
        $OutputText -match "(?i)Nenhuma atualiza" -or
        $OutputText -match "(?i)Nenhum pacote instalado"
    )
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
            throw "Há uma vírgula sem um ID antes ou depois dela. Revise a lista informada."
        }

        if ($packageId -match "\s") {
            throw "O ID '$packageId' contém espaços. Separe vários IDs por vírgula."
        }

        if ($packageId.ToUpperInvariant() -in @("S", "N", "ID")) {
            throw "A lista contém '$packageId', que é uma opção de menu e não um ID de pacote."
        }

        if ($packageId -match '^-' -or $packageId -match '["`;|&<>]') {
            throw "O ID '$packageId' contém caracteres que não fazem parte de um ID do winget."
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
    $failed = { param ($Text) New-WinForgeResult -Kind Failed -Detail "$Text — erro $code" }

    switch ($code) {
        "0x00000000" { return (New-WinForgeResult -Kind Ok) }
        "0x8A15002B" { return (New-WinForgeResult -Kind Ok -Detail "já está na versão mais recente") }
        "0x8A150061" { return (New-WinForgeResult -Kind Ok -Detail "já estava instalado") }
        "0x8A15010D" { return (New-WinForgeResult -Kind Ok -Detail "outra versão já estava instalada") }
        "0x8A15010E" { return (New-WinForgeResult -Kind Ok -Detail "já há uma versão mais nova instalada") }
        "0x8A150109" { return (New-WinForgeResult -Kind Warning -Detail "termina na próxima reinicialização" -Data @{ RebootRequired = $true }) }
        "0x8A15010B" { return (New-WinForgeResult -Kind Warning -Detail "o instalador vai reiniciar o PC para terminar" -Data @{ RebootRequired = $true }) }
        "0x8A150014" { return (New-WinForgeResult -Kind Failed -Detail "pacote não encontrado") }
        "0x8A15002C" { return (& $failed "algum programa não foi atualizado") }
        "0x8A150034" { return (& $failed "algum programa da lista não foi instalado") }
        "0x8A150035" { return (& $failed "algum programa da lista não foi encontrado no winget") }
        "0x8A150011" { return (& $failed "o instalador baixado não confere com o esperado") }
        "0x8A150101" { return (& $failed "o programa está aberto; feche-o e tente de novo") }
        "0x8A150103" { return (& $failed "há arquivos do programa em uso; feche-o e tente de novo") }
        "0x8A150111" { return (& $failed "o programa está em uso por outro programa; feche-os e tente de novo") }
        "0x8A150102" { return (& $failed "outra instalação está em andamento; tente mais tarde") }
        "0x8A150105" { return (& $failed "falta espaço no disco") }
        "0x8A150107" { return (& $failed "o instalador precisa de internet") }
        "0x8A15010A" { return (& $failed "reinicie o PC e tente de novo") }
        "0x8A15010C" { return (& $failed "a instalação foi cancelada no instalador") }
        "0x8A150114" { return (& $failed "o instalador não atualiza por cima da versão instalada") }
        "0x8A15003A" { return (& $failed "bloqueado por uma política do Windows") }
        "0x8A15010F" { return (& $failed "uma política da organização impede a instalação; fale com o suporte de TI") }
        "0x8A15001B" { return (& $failed "a Microsoft Store está bloqueada por uma política do Windows") }
        "0x8A150104" { return (& $failed "falta no PC um componente de que o programa depende") }
        "0x8A150110" { return (& $failed "não foi possível instalar os componentes de que o programa depende") }
        "0x8A150106" { return (& $failed "falta memória livre; feche outros programas e tente de novo") }
        "0x8A150113" { return (& $failed "o programa não é compatível com este PC ou com esta versão do Windows") }
        "0x8A150108" { return (& $failed "o instalador do programa falhou; o fabricante sugere procurar o suporte dele") }
        "0x8A150115" { return (& $failed "o instalador do programa falhou com um erro próprio") }
        "0x8A150016" { return (& $failed "mais de um pacote corresponde a esse ID") }
        "0x8A15007D" { return (& $failed "o programa foi instalado só para o seu usuário, e o winget não o altera como Administrador; para continuar sem Administrador, $(Get-WinForgeUnelevatedHint)") }
        "0x8A150056" { return (& $failed "o instalador não roda como Administrador; para continuar sem Administrador, $(Get-WinForgeUnelevatedHint)") }
        "0x8A150076" { return (& $failed "a fonte do pacote pede que você entre com uma conta") }
        "0x8A15001C" { return (& $failed "uma política do Windows bloqueia esse aplicativo da Microsoft Store") }
        "0x8A15008E" { return (& $failed "a versão nova usa outro tipo de instalador; desinstale a atual e instale de novo") }
        "0x8A150015" { return (& $failed "o winget está sem fontes de pacotes configuradas") }
        # Desinstalar: o programa não registrou como se desinstala, ou o desinstalador dele terminou com erro (o que inclui
        # cancelar na janela dele). Os dois 0x80073xxx vêm do Windows ao remover um aplicativo da Microsoft Store.
        "0x8A15002F" { return (& $failed "o programa não tem desinstalador registrado") }
        "0x8A150030" { return (& $failed "o desinstalador terminou com erro ou foi cancelado") }
        "0x80073CFA" { return (& $failed "o Windows não permite remover este aplicativo") }
        "0x80073D02" { return (& $failed "o aplicativo está aberto; feche-o e tente de novo") }
        # Sem internet, ou com ela caindo no meio: o download do instalador falha (0x8A150008) ou o Windows nem chega ao
        # servidor (nome que não resolve, conexão recusada, tempo esgotado).
        "0x8A150008" { return (& $failed "não foi possível baixar o instalador; confira a internet") }
        "0x80072EE7" { return (& $failed "sem conexão com a internet") }
        "0x80072EFD" { return (& $failed "sem conexão com a internet") }
        "0x80072EE2" { return (& $failed "sem conexão com a internet") }
    }

    if ($ExitCode -lt 0) {
        return (New-WinForgeResult -Kind Failed -Detail "erro $code")
    }

    return (New-WinForgeResult -Kind Failed -Detail "código de saída $ExitCode")
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

    $truncated = "o winget mostrou o ID incompleto"

    switch ($Operation) {
        "Install"   { return @{ Activity = "Instalando programas"; One = "instalado"; Many = "instalados"; Truncated = "$truncated; busque de novo por um nome mais específico" } }
        "Upgrade"   { return @{ Activity = "Atualizando programas"; One = "atualizado"; Many = "atualizados"; Truncated = "$truncated; atualize pelo próprio programa" } }
        "Uninstall" { return @{ Activity = "Desinstalando programas"; One = "desinstalado"; Many = "desinstalados"; Truncated = "$truncated; desinstale em Programas > Aplicativos instalados" } }
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
        $parts += "$versions versões"
    }
    elseif ($version -and $version -notmatch '^(\?|Unknown|Desconhecid[ao])$') {
        $parts += "versão $version"
    }

    $source = Get-WinForgeWingetSourceLabel -Source ([string]$Package.Fonte)

    if ($source) {
        $parts += $source
    }

    if (Test-WinForgeWingetIdTruncated -Id $Package.Id) {
        $parts += "ID incompleto na lista do winget"
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
        $name -match '^(Microsoft Store|Instalador de Aplicativo|App Installer|Segurança do Windows|Windows Security)$' -or
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
        return "driver de um aparelho do PC"
    }

    return ""
}


function Get-WinForgeInstalledWingetIds {
    <#
    Os IDs (em minúsculas) do que o winget vê instalado, para as listas de instalar dizerem "já instalado". O "winget
    list" leva alguns segundos: a leitura vale por 2 minutos (buscar de novo logo depois não lê outra vez) e é descartada
    quando o WinForge instala, atualiza ou desinstala algo. $null quando o winget não respondeu: aí as listas ficam sem
    a marca, como antes.
    #>
    param ([string]$Activity = "Lendo os programas instalados")

    $cache = $script:WinForgeInstalledIdsCache
    if ($null -ne $cache -and ((Get-Date) - $cache.At).TotalSeconds -lt 120) { return ,$cache.Ids }

    Write-Progress -Activity $Activity -Status "conferindo o que já está instalado"

    try {
        $listing = Invoke-WinForgeCapture -FilePath "winget" -Arguments @("list", "--accept-source-agreements")
        $packages = @(ConvertFrom-WinForgeWingetTable -Lines $listing.Lines)
    }
    catch {
        return $null
    }
    finally {
        Write-Progress -Activity $Activity -Completed
    }

    if ($packages.Count -eq 0) { return $null }

    $ids = New-Object 'System.Collections.Generic.HashSet[string]'
    foreach ($package in $packages) { [void]$ids.Add(([string]$package.Id).ToLowerInvariant()) }

    $script:WinForgeInstalledIdsCache = [PSCustomObject]@{ At = (Get-Date); Ids = $ids }

    return ,$ids
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
        $done = $(if ($Operation -eq "Upgrade" -and $Available) { "atualizado para a versão $Available" } else { $verbs.One })
        Write-WinForgeStatus -Type Success -Message "${Name}: $done."
    }
    elseif ($Result.Kind -eq "Ok") {
        Write-WinForgeStatus -Type Success -Message "${Name}: $($Result.Detail)."
    }
    elseif ($Result.Kind -eq "Warning") {
        Write-WinForgeStatus -Type Warning -Message "${Name}: $($verbs.One), mas $($Result.Detail)."
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
    param ([string]$Activity = "Desinstalando programas")

    $script:WinForgeInstalledIdsCache = $null
    Write-Progress -Activity $Activity -Status "conferindo o que saiu"

    try {
        $listing = Invoke-WinForgeCapture -FilePath "winget" -Arguments @("list", "--accept-source-agreements")
        $rows = @(ConvertFrom-WinForgeWingetTable -Lines $listing.Lines)
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
        [string]$Activity = "Desinstalando programas"
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

        Write-Progress -Activity $Activity -Status "esperando o desinstalador terminar"
        Start-Sleep -Seconds ([int]$delay)
        $rows = Get-WinForgeWingetInstalledRows -Activity $Activity
        $waiting = @(& $getWaiting $rows)
    }

    # A janela do desinstalador pode estar esperando a pessoa: ela termina lá e manda conferir de novo.
    for ($ask = 0; $ask -lt 5 -and $waiting.Count -gt 0; $ask++) {
        $names = Join-WinForgeList -Items @($waiting | ForEach-Object { [string]$Packages[$_].Nome })
        $still = $(if ($waiting.Count -eq 1) { "ainda está instalado" } else { "ainda estão instalados" })

        Write-WinForgeStatus -Type Warning -Notice -Message "$names $still. Se abriu uma janela de desinstalação, conclua nela."

        if (-not (Confirm-WinForgeAction -Message "Conferir de novo?" -DefaultKey S)) { break }

        $rows = Get-WinForgeWingetInstalledRows -Activity $Activity
        $waiting = @(& $getWaiting $rows)
    }

    $final = @()

    for ($i = 0; $i -lt $count; $i++) {
        $result = $Results[$i]

        if ($ran[$i]) {
            if ($null -eq $rows) {
                if ($result.Kind -ne "Failed") { $result = New-WinForgeResult -Kind Failed -Detail "não foi possível conferir se saiu" }
            }
            elseif (Test-WinForgeWingetPackageListed -Package $Packages[$i] -Rows $rows) {
                # Pedir reinício e continuar na lista é o esperado; um erro do winget já diz o motivo.
                if ($result.Kind -eq "Ok") { $result = New-WinForgeResult -Kind Failed -Detail "continua instalado" }
            }
            elseif ($result.Kind -eq "Failed") {
                # Saiu da lista apesar do erro (o desinstalador avisou algo, mas removeu; ou o winget nem o achou mais).
                $notFound = ([int](Get-WinForgeResultData -Result $result -Name "ExitCode") -eq -1978335212)
                $result = $(if ($notFound) { New-WinForgeResult -Kind Ok -Detail "já não está instalado" } else { New-WinForgeResult -Kind Ok })
            }

            $result.Etapa = [string]$Packages[$i].Nome
        }

        $final += $result
    }

    return $final
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
            $status = "$position de $($Packages.Count): $name"
            if ($Operation -eq "Uninstall") { $status += " · se abrir uma janela, conclua nela" }
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
                $result = Get-WinForgeWingetExitResult -ExitCode $exitCode
                if ($result.Data -is [hashtable]) { $result.Data["ExitCode"] = $exitCode }

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
        Write-WinForgeSection -Title "Resumo"
        Write-WinForgeResultTable -Results $outcomes
    }

    $failed = @($outcomes | Where-Object { $_.Kind -eq "Failed" })

    # SucceededIds: os pacotes que deram certo. ChangedIds: os que o winget de fato mudou (sem "já estava instalado" nem
    # "já está na versão mais recente"): é o que o Histórico anota.
    $data = @{
        SucceededIds = @(for ($i = 0; $i -lt $outcomes.Count; $i++) { if ($outcomes[$i].Kind -ne "Failed") { [string]$Packages[$i].Id } })
        ChangedIds   = @(for ($i = 0; $i -lt $outcomes.Count; $i++) { if ($outcomes[$i].Kind -eq "Warning" -or ($outcomes[$i].Kind -eq "Ok" -and -not $outcomes[$i].Detail)) { [string]$Packages[$i].Id } })
    }

    if (@($outcomes | Where-Object { Test-WinForgeResultFlag -Result $_ -Name "RebootRequired" }).Count -gt 0) {
        $data["RebootRequired"] = $true
    }

    if ($failed.Count -eq 0) {
        $detail = Format-WinForgeCount -Count $outcomes.Count -One "programa $($verbs.One)" -Many "programas $($verbs.Many)"

        if ($outcomes.Count -eq 1) {
            $single = $outcomes[0]
            $detail = $(if ($single.Kind -eq "Ok" -and $single.Detail) { "$($single.Etapa): $($single.Detail)" } else { "$($single.Etapa) $($verbs.One)" })
        }

        return (New-WinForgeResult -Kind Ok -Detail $detail -Data $data)
    }

    $names = Join-WinForgeList -Items @($failed | ForEach-Object { [string]$_.Etapa })

    if ($failed.Count -eq $outcomes.Count) {
        if ($outcomes.Count -eq 1) {
            return (New-WinForgeResult -Kind Failed -Detail "$names não foi $($verbs.One): $($failed[0].Detail)" -Data $data)
        }

        return (New-WinForgeResult -Kind Failed -Detail "nenhum programa foi $($verbs.One): $names" -Data $data)
    }

    $verbText = $(if ($failed.Count -eq 1) { "não foi $($verbs.One)" } else { "não foram $($verbs.Many)" })

    return (New-WinForgeResult -Kind Warning -Detail "$($failed.Count) de $($outcomes.Count) ${verbText}: $names" -Data $data)
}


function Set-WinForgeWingetPackagesView {
    <#
    A faixa da janela depois de instalar ou desinstalar pelo winget: o título diz quantos, e a frase, quais. Ao instalar,
    conta como instalado o que o winget de fato mudou (ChangedIds) e não estava no PC antes (Installed, lido antes da
    lista); o que já estava e ganhou versão nova conta como atualizado; o que já estava e não mudou não conta. Com
    ressalvas, o título diz quantos deram certo, e a frase, quais não deram. Depois de desinstalar, o botão leva à busca de
    restos. A falha fica com a faixa de sempre ("7-Zip não foi instalado: ..."), que já diz qual e por quê. Devolve o
    próprio resultado.
    #>
    param (
        [Parameter(Mandatory)][ValidateSet("Install", "Uninstall")][string]$Operation,
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Packages,
        $Result,
        $Installed = $null
    )

    if ($null -eq $Result -or $Result.Kind -notin @("Ok", "Warning") -or $Packages.Count -eq 0) { return $Result }

    $succeeded = @(Get-WinForgeResultData -Result $Result -Name "SucceededIds")
    $changed = @(Get-WinForgeResultData -Result $Result -Name "ChangedIds")
    $done = @($Packages | Where-Object { $succeeded -contains [string]$_.Id })
    $failed = @($Packages | Where-Object { $succeeded -notcontains [string]$_.Id } | ForEach-Object { [string]$_.Nome })
    $verbs = Get-WinForgeWingetVerbs -Operation $Operation
    $next = $(if ($Operation -eq "Uninstall") { "cleanup.leftovers" } else { "" })
    $nextLabel = $(if ($Operation -eq "Uninstall") { "Procurar restos" } else { "" })

    if ($done.Count -eq 0) { return $Result }

    if ($failed.Count -gt 0) {
        $verbText = $(if ($failed.Count -eq 1) { "não foi $($verbs.One)" } else { "não foram $($verbs.Many)" })
        $reason = $(if ($failed.Count -eq 1) { "o motivo está no resumo" } else { "o motivo de cada um está no resumo" })

        return (Set-WinForgeResultView -Result $Result -Headline "$($done.Count) de $($Packages.Count) programas $($verbs.Many)" `
                -Note "$(Join-WinForgeShortList -Items $failed) ${verbText}; $reason." -Next $next -NextLabel $nextLabel)
    }

    if ($Operation -eq "Uninstall") {
        $names = @($done | ForEach-Object { [string]$_.Nome })

        return (Set-WinForgeResultView -Result $Result -Headline (Format-WinForgeCount -Count $names.Count -One "programa desinstalado" -Many "programas desinstalados") `
                -Note "$(Join-WinForgeShortList -Items $names)." -Next $next -NextLabel $nextLabel)
    }

    $new = @($done | Where-Object { $changed -contains [string]$_.Id -and -not (Test-WinForgeWingetIdInstalled -Installed $Installed -Id $_.Id) } | ForEach-Object { [string]$_.Nome })
    $updated = @($done | Where-Object { $changed -contains [string]$_.Id -and (Test-WinForgeWingetIdInstalled -Installed $Installed -Id $_.Id) } | ForEach-Object { [string]$_.Nome })
    $same = @($done | Where-Object { $changed -notcontains [string]$_.Id } | ForEach-Object { [string]$_.Nome })
    $parts = @()

    if ($new.Count -gt 0) {
        $headline = Format-WinForgeCount -Count $new.Count -One "programa instalado" -Many "programas instalados"
        $parts += "$(Join-WinForgeShortList -Items $new)."
        if ($updated.Count -gt 0) { $parts += "$(if ($updated.Count -eq 1) { 'Atualizado' } else { 'Atualizados' }): $(Join-WinForgeShortList -Items $updated)." }
    }
    elseif ($updated.Count -gt 0) {
        $headline = Format-WinForgeCount -Count $updated.Count -One "programa atualizado" -Many "programas atualizados"
        $parts += "$(Join-WinForgeShortList -Items $updated)."
    }
    else {
        # Nada mudou: o que foi marcado já estava no PC, e o winget não tinha versão nova.
        $headline = "Nada para instalar"
        $parts += "$(Join-WinForgeShortList -Items $same) já $(if ($same.Count -eq 1) { 'está instalado' } else { 'estão instalados' })."
        $same = @()
    }

    if ($same.Count -gt 0) { $parts += "Já $(if ($same.Count -eq 1) { 'estava instalado' } else { 'estavam instalados' }): $(Join-WinForgeShortList -Items $same)." }

    return (Set-WinForgeResultView -Result $Result -Headline $headline -Note ($parts -join " "))
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

    Write-WinForgeSection -Title "Atualizações disponíveis"

    foreach ($package in @($Packages | Select-Object -First $Limit)) {
        $name = [string]$package.Nome
        if ($name.Length -gt 48) { $name = $name.Substring(0, 45) + "..." }

        $versions = $(if ([string]::IsNullOrWhiteSpace([string]$package.Disponivel)) { [string]$package.Versao } else { "$($package.Versao) para $($package.Disponivel)" })
        Write-WinForgeKeyValue -Label $name -Value $versions
    }

    $rest = @($Packages).Count - $Limit

    if ($rest -gt 0) {
        Write-WinForgeStatus -Type Info -Message "E mais $(Format-WinForgeCount -Count $rest -One 'programa' -Many 'programas')."
    }
}


function Get-WinForgeWingetUpgradePlan {
    <#
    Coleta a decisão do usuário sem instalar nada, para que o Otimizar possa perguntar tudo antes da
    parte automática. Action: Unavailable | NoUpdates | None | All | Ids. Packages: o que o winget listou (Nome, Id,
    Versao, Disponivel), vazio quando a tabela não pôde ser lida. Uma pergunta sem resposta (a entrada terminou) é "Não
    atualizar", e não uma falha do winget.
    -SkipBrowsers (o Otimizar): Edge, Chrome e Firefox saem da lista, porque a etapa dos navegadores os atualiza pelo
    atualizador de cada um (Test-WinForgeWingetBrowserId).
    #>
    param ([switch]$SkipBrowsers)

    if (-not (Initialize-WinForgeWinget)) {
        return [PSCustomObject]@{ Action = "Unavailable"; Ids = @(); Packages = @() }
    }

    Write-WinForgeWingetUserWarning -Context Upgrade
    Write-Progress -Activity "Procurando atualizações de programas" -Status "consultando o winget"

    try {
        $upgrade = Invoke-WinForgeCapture -FilePath "winget" -Arguments @("upgrade", "--accept-source-agreements") -Echo
    }
    finally {
        Write-Progress -Activity "Procurando atualizações de programas" -Completed
    }

    if (Test-WinForgeWingetNoUpgradeOutput -OutputText $upgrade.Text -ExitCode $upgrade.ExitCode) {
        Write-Host ""
        Write-WinForgeStatus -Type Success -Message "Os programas que o winget reconhece estão em dia."
        return [PSCustomObject]@{ Action = "NoUpdates"; Ids = @(); Packages = @() }
    }

    $codeText = (Get-WinForgeWingetExitResult -ExitCode $upgrade.ExitCode).Detail

    if ($upgrade.ExitCode -ne 0 -and [string]::IsNullOrWhiteSpace($upgrade.Text)) {
        throw "o winget terminou sem dizer o motivo ($codeText)"
    }

    $available = @(ConvertFrom-WinForgeWingetTable -Lines $upgrade.Lines)

    if ($available.Count -eq 0 -and $upgrade.ExitCode -ne 0) {
        throw "o winget não conseguiu listar as atualizações ($codeText)"
    }

    if ($SkipBrowsers -and $available.Count -gt 0) {
        $browsers = @($available | Where-Object { Test-WinForgeWingetBrowserId -Id ([string]$_.Id) })
        $available = @($available | Where-Object { -not (Test-WinForgeWingetBrowserId -Id ([string]$_.Id)) })

        if ($browsers.Count -gt 0 -and $available.Count -eq 0) {
            Write-Host ""
            Write-WinForgeStatus -Type Success -Message "Os programas que o winget reconhece estão em dia; os navegadores têm a etapa deles."
            return [PSCustomObject]@{ Action = "NoUpdates"; Ids = @(); Packages = @() }
        }
    }

    Write-Host ""

    if ($available.Count -gt 0) {
        Write-WinForgeWingetUpgradeList -Packages $available
        $options = @(
            @{ Key = "S"; Label = "Atualizar todos ($($available.Count))"; Accent = $true },
            @{ Key = "E"; Label = "Escolher quais atualizar"; Description = "marque os programas na lista" },
            @{ Key = "N"; Label = "Não atualizar"; Exit = $true }
        )
    }
    else {
        # Sem tabela reconhecida (formato inesperado do winget): o que ele mostrou fica nos detalhes técnicos.
        Write-WinForgeStatus -Type Warning -Message "Não foi possível ler a lista do winget; ela está nos detalhes técnicos."
        $options = @(
            @{ Key = "S"; Label = "Atualizar tudo o que o winget oferecer"; Accent = $true },
            @{ Key = "E"; Label = "Digitar os IDs"; Description = "um ou mais IDs do winget, separados por vírgula" },
            @{ Key = "N"; Label = "Não atualizar"; Exit = $true }
        )
    }

    # Só entram programas que o winget reconhece; o Windows Update e a Microsoft Store ficam nos outros itens da página
    # Atualizações. Um programa aberto pode não ser atualizado.
    if ($available.Count -gt 0) {
        Write-WinForgeStatus -Type Info -Message "Feche os programas da lista antes de atualizar."
    }

    Write-Host ""

    while ($true) {
        try {
            $choice = Read-WinForgeChoice -Message "O que deseja atualizar?" -TextPrompt "Digite S, E ou N" -ShowMenu -Options $options
        }
        catch {
            Write-WinForgeStatus -Type Info -Message "Sem resposta: nenhum programa será atualizado."
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
                    $versions = $(if ([string]::IsNullOrWhiteSpace([string]$package.Disponivel)) { [string]$package.Versao } else { "$($package.Versao) para $($package.Disponivel)" })
                    @{ Key = $package.Id; Label = $package.Nome; Description = "$($package.Id) · $versions" }
                }
            )

            # Cancelar a lista volta para a pergunta anterior: o botão diz "Voltar".
            $picked = Read-WinForgeMultiSelect -Message "Quais programas atualizar?" -Options $listOptions -ConfirmLabel "Atualizar" -CancelLabel "Voltar"

            if ($null -eq $picked -or @($picked).Count -eq 0) {
                continue
            }

            return [PSCustomObject]@{ Action = "Ids"; Ids = @($picked); Packages = $available }
        }

        Write-WinForgeStatus -Type Info -Message "Para vários programas, separe os IDs por vírgula. Exemplo: Google.Chrome, Notepad++.Notepad++"

        $packageInput = Read-WinForgeText -Message "Digite um ou mais IDs (vazio = voltar)"

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
            return (New-WinForgeResult -Kind Failed -Detail "winget não encontrado")
        }
        "NoUpdates" {
            return (Set-WinForgeResultView -Result (New-WinForgeResult -Kind Ok -Detail "os programas que o winget reconhece estão em dia") `
                    -Headline "Os programas estão em dia" -Note "Nenhum programa que o winget reconhece tem versão nova.")
        }
        "Error" {
            return (New-WinForgeResult -Kind Failed -Detail $Plan.Detail)
        }
        "None" {
            # Sozinha, a tela termina em "Cancelado"; na Manutenção, a etapa fica como ignorada.
            Write-WinForgeStatus -Type Info -Message "Nenhum programa foi atualizado: você escolheu não atualizar."
            return (New-WinForgeResult -Kind Skipped -Detail "cancelado pelo usuário")
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
                    [void](Add-WinForgeChange -Action "Programas atualizados" -Text (Join-WinForgeList -Items $names))
                }

                # Na janela, tudo certo: o título diz quantos, e a frase, quais.
                if ($null -ne $result -and $result.Kind -eq "Ok" -and $names.Count -gt 0) {
                    [void](Set-WinForgeResultView -Result $result -Headline (Format-WinForgeCount -Count $names.Count -One "programa atualizado" -Many "programas atualizados") `
                            -Note "$(Join-WinForgeShortList -Items $names).")
                }

                return $result
            }

            # Sem a lista (o winget mostrou um formato que o WinForge não lê): o winget atualiza tudo de uma vez.
            $arguments = Get-WinForgeWingetArguments -Operation UpgradeAll

            Write-Host ""
            Write-WinForgeCommand -Command "winget $($arguments -join ' ')"
            Write-Host ""
            Write-Progress -Activity "Atualizando programas" -Status "o winget atualiza tudo o que tiver atualização"
            $script:WinForgeInstalledIdsCache = $null

            try {
                $exitCode = Invoke-WinForgeNative -FilePath "winget" -Arguments $arguments -IgnoreExitCode -PassThru
            }
            finally {
                Write-Progress -Activity "Atualizando programas" -Completed
            }

            Write-Host ""

            # "Nenhuma atualização aplicável" (0x8A15002B) não é problema: o winget só não tinha o que atualizar.
            $exitResult = Get-WinForgeWingetExitResult -ExitCode $exitCode

            if ($exitResult.Kind -ne "Failed") {
                # Só o código 0 diz que algo foi atualizado; "nenhuma atualização aplicável" também termina bem.
                if ($exitCode -eq 0) { [void](Add-WinForgeChange -Action "Programas atualizados" -Text "o que o winget tinha para atualizar") }
                Write-WinForgeStatus -Type Success -Message "O winget terminou a atualização."
                return (New-WinForgeResult -Kind Ok -Detail "o winget atualizou o que tinha atualização" -Data $exitResult.Data)
            }

            # O detalhe pode ser uma frase ("algum programa não foi atualizado — erro 0x8A15002C") ou só o código.
            Write-WinForgeStatus -Type Warning -Message "O winget terminou com problemas: $($exitResult.Detail). Veja os detalhes técnicos."
            return (New-WinForgeResult -Kind Warning -Detail "o winget terminou com problemas: $($exitResult.Detail)")
        }
    }

    # Um plano que este código não conhece é um erro de programação, não um sucesso.
    return (New-WinForgeResult -Kind Failed -Detail "ação desconhecida no plano: $($Plan.Action)")
}


function Update-WinForgeSoftware {
    Enter-WinForgeAction -Title "Atualizar programas (winget)"

    # O desfecho vem do resultado do plano, não da contagem de mensagens: "Não atualizar" não é ressalva, um erro depois
    # de a lista de pacotes ter sido atualizada continua sendo falha, e pacotes que falharam deixam a faixa vermelha.
    $final = New-WinForgeResult -Kind Failed -Detail "o plano de atualização não devolveu resultado"

    try {
        $plan = Get-WinForgeWingetUpgradePlan
        $result = Get-WinForgeLastResult -Output (Invoke-WinForgeWingetUpgradePlan -Plan $plan)
        if ($null -ne $result) {
            $final = $result
        }
    }
    catch {
        Write-Host ""
        Write-WinForgeStatus -Type Error -Message "Não foi possível atualizar os programas: $($_.Exception.Message.TrimEnd('.'))."
        $final = New-WinForgeResult -Kind Failed -Detail $_.Exception.Message
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

    $reopen = $(if ($Pending) { "; vale ao abrir de novo" } else { "" })

    if (-not [string]::IsNullOrWhiteSpace($After) -and $After -ne $Before) {
        return [PSCustomObject]@{ Kind = "Ok"; Text = "atualizado para $After$reopen" }
    }

    if ($ExitCode -ne 0) {
        $why = $(if ($FailText) { $FailText } else { "o atualizador terminou com o código $(Format-WinForgeExitCode -ExitCode $ExitCode)" })
        return [PSCustomObject]@{ Kind = "Warning"; Text = "não atualizou ($why)" }
    }

    if ($Unconfirmed) { return [PSCustomObject]@{ Kind = "Ok"; Text = "nenhuma versão nova instalada agora ($Before)$reopen" } }

    return [PSCustomObject]@{ Kind = "Ok"; Text = "já na versão mais nova ($Before)$reopen" }
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
        $browser.Text = "atualizador não encontrado; atualize em Configurações, Sobre o Microsoft Edge"
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
        $browser.Text = "instalado só para um usuário; o Chrome se atualiza sozinho"
        return $browser
    }

    if ($install.Blocked) {
        $browser.Text = "a atualização é controlada por uma política"
        return $browser
    }

    $command = Get-WinForgeGoogleUpdaterCommand

    if ($null -eq $command) {
        $browser.Kind = "Warning"
        $browser.Text = "atualizador não encontrado; atualize em Configurações, Sobre o Google Chrome"
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
        $browser.Text = "a atualização está desligada por uma política"
        return $browser
    }

    if ($install.Esr) {
        $browser.Text = "a versão ESR se atualiza sozinha"
        return $browser
    }

    if (-not (Test-WinForgeWinget)) {
        $browser.Text = "sem o winget; o Firefox se atualiza sozinho ao abrir"
        return $browser
    }

    if (Test-WinForgeFirefoxRunning) {
        $browser.Kind = "Warning"
        $browser.Text = "estava aberto; feche o Firefox para atualizar"
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
        $browser.Text = "o winget não reconhece esta instalação; o Firefox se atualiza sozinho ao abrir"
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

    $title = "Atualizar os navegadores"

    Enter-WinForgeAction -Title $title -Embedded:$Embedded

    $browsers = @()

    foreach ($command in @("Update-WinForgeEdgeBrowser", "Update-WinForgeChromeBrowser", "Update-WinForgeFirefoxBrowser")) {
        $name = @{ "Update-WinForgeEdgeBrowser" = "Microsoft Edge"; "Update-WinForgeChromeBrowser" = "Google Chrome"; "Update-WinForgeFirefoxBrowser" = "Mozilla Firefox" }[$command]
        Write-Progress -Activity $title -Status $name

        try {
            $browsers += @(& $command)
        }
        catch {
            $browsers += [PSCustomObject]@{ Name = $name; Installed = $true; Kind = "Failed"; Text = "não atualizou ($($_.Exception.Message.Trim().TrimEnd('.')))" }
        }
    }

    Write-Progress -Activity $title -Completed

    $installed = @($browsers | Where-Object { $_.Installed })

    foreach ($browser in $installed) {
        $type = switch ([string]$browser.Kind) { "Ok" { "Success" } "Skipped" { "Info" } "Warning" { "Warning" } default { "Error" } }
        Write-WinForgeStatus -Type $type -Message "$($browser.Name): $($browser.Text)."
    }

    $detail = (@($installed | ForEach-Object { "$(([string]$_.Name -split ' ')[-1]) $($_.Text)" }) -join "; ")

    if ($installed.Count -eq 0) {
        $final = New-WinForgeResult -Kind Skipped -Detail "nenhum navegador encontrado" -Title $title
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
    para a pessoa clicar.
    #>
    param (
        [switch]$Embedded,
        [switch]$PassThru
    )

    $title = "Atualizar aplicativos da Microsoft Store"

    Enter-WinForgeAction -Title $title -Embedded:$Embedded

    $final = $null

    try {
        $instance = @(Get-CimInstance -Namespace "root\cimv2\mdm\dmmap" -ClassName "MDM_EnterpriseModernAppManagement_AppManagement01" -ErrorAction Stop) | Select-Object -First 1

        if ($null -eq $instance) { throw "o Windows não respondeu ao pedido" }

        $call = Invoke-CimMethod -InputObject $instance -MethodName "UpdateScanMethod" -ErrorAction Stop
        # O ReturnValue é UInt32: um código de erro (0x8xxxxxxx) não cabe no [int] e vira o negativo correspondente, como
        # os códigos de saída que Format-WinForgeExitCode mostra em hexadecimal.
        $raw = [int64](Get-WinForgeJsonValue -Object $call -Name "ReturnValue" -Default 0)
        if ($raw -gt [int]::MaxValue) { $raw -= 4294967296 }
        $code = [int]$raw

        if ($code -ne 0) { throw "código $(Format-WinForgeExitCode -ExitCode $code)" }

        # Ela baixa e instala em segundo plano (minutos). Pedida sozinha, a lista de downloads da Store abre em seguida, para
        # a pessoa acompanhar; no Otimizar, não (a Store abriria por cima das outras etapas).
        Write-WinForgeStatus -Type Success -Message "Pedido enviado à Microsoft Store: ela instala as atualizações em segundo plano."
        $final = New-WinForgeResult -Kind Ok -Detail "pedido enviado; a Store instala em segundo plano" -Title $title

        if (-not $Embedded) {
            $shown = $false
            try { $shown = [bool](Open-WinForgeShortcut -Name "MicrosoftStore") } catch { $shown = $false }

            [void](Set-WinForgeResultView -Result $final -Headline "Pedido enviado à Microsoft Store" `
                    -Note "Ela baixa e instala as atualizações em segundo plano$(if ($shown) { '; a lista de downloads abriu para você acompanhar' } else { '' }).")
        }
    }
    catch {
        $reason = ([string]$_.Exception.Message).Trim().TrimEnd('.')
        Write-WinForgeStatus -Type Warning -Message "O Windows não aceitou o pedido de atualização à Microsoft Store ($reason)."

        if (Open-WinForgeShortcut -Name "MicrosoftStore") {
            Write-WinForgeStatus -Type Info -Message "Na página da Store que abriu, clique em Obter atualizações."
            $final = New-WinForgeResult -Kind Warning -Detail "o Windows não aceitou o pedido; a página de atualizações da Store foi aberta" -Title $title
        }
        else {
            $final = New-WinForgeResult -Kind Warning -Detail "o Windows não aceitou o pedido; abra a Store e clique em Obter atualizações" -Title $title
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
    Enter-WinForgeAction -Title "Listar programas instalados"

    # Resultado explícito: sem ele, a faixa dependeria de a lista de pacotes já ter sido atualizada nesta sessão (a primeira
    # consulta registra um "sucesso" e as seguintes não), e a mesma tela terminaria verde numa vez e sem faixa na outra.
    $final = New-WinForgeResult -Kind Failed -Detail "a listagem não devolveu resultado"

    try {
        if (-not (Initialize-WinForgeWinget -OfferStore)) {
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Failed -Detail (Get-WinForgeWingetMissingDetail))
            return
        }

        Write-WinForgeWingetUserWarning

        # A tabela vai para os detalhes técnicos como o winget a gera (no console, para a tela); o resumo traz as contas.
        Write-Progress -Activity "Listando os programas instalados" -Status "consultando o winget"

        try {
            $listing = Invoke-WinForgeCapture -FilePath "winget" -Arguments @("list", "--accept-source-agreements") -Echo
        }
        finally {
            Write-Progress -Activity "Listando os programas instalados" -Completed
        }

        Write-Host ""

        $all = @(ConvertFrom-WinForgeWingetTable -Lines $listing.Lines)
        $exitResult = Get-WinForgeWingetExitResult -ExitCode $listing.ExitCode

        # Os componentes do Windows (VCLibs, a Store, o próprio winget) não são programas: ficam fora da conta.
        $installed = @($all | Where-Object { -not (Test-WinForgeWingetComponent -Package $_) })

        if ($all.Count -eq 0) {
            if ($exitResult.Kind -eq "Ok" -and -not [string]::IsNullOrWhiteSpace($listing.Text)) {
                # O winget respondeu, mas num formato que este código não lê: a tabela está nos detalhes técnicos.
                Write-WinForgeStatus -Type Warning -Message "O WinForge não reconheceu a tabela do winget; ela está nos detalhes técnicos."
                $final = New-WinForgeResult -Kind Warning -Detail "a tabela do winget não foi reconhecida"
            }
            else {
                $reason = $(if ($exitResult.Kind -eq "Ok") { "o winget não respondeu" } else { $exitResult.Detail })
                Write-WinForgeStatus -Type Error -Message "Não foi possível listar os programas: $reason."
                $final = New-WinForgeResult -Kind Failed -Detail "não foi possível listar os programas: $reason"
            }

            Exit-WinForgeAction -Result $final
            return
        }

        $counts = Get-WinForgeInstalledSoftwareCounts -Packages $installed

        # Na tela, só o total e as atualizações; a fonte, a versão e o ID de cada programa ficam na tabela do winget, nos
        # detalhes técnicos (no console, ela já apareceu acima).
        Write-WinForgeSection -Title "Programas instalados"
        Write-WinForgeKeyValue -Label "Total" -Value (Format-WinForgeCount -Count $counts.Total -One "programa" -Many "programas") -LabelWidth 16
        if ($counts.Updates -gt 0) { Write-WinForgeKeyValue -Label "Com atualização" -Value $counts.Updates -LabelWidth 16 }
        Write-Host ""

        $detail = Format-WinForgeCount -Count $counts.Total -One "programa instalado" -Many "programas instalados"

        if ($counts.Updates -gt 0) {
            $detail += "; $($counts.Updates) com atualização no winget"
        }

        if ($exitResult.Kind -eq "Ok") {
            # Na janela, o título diz quantos; a frase, quantos têm versão nova; e o botão leva a atualizá-los.
            $final = New-WinForgeResult -Kind Ok -Detail $detail -Data @{ Count = $counts.Total }
            $updatesText = $(if ($counts.Updates -gt 0) { "$(Format-WinForgeNumber -Value $counts.Updates) com versão nova no winget" } else { "Nenhum com versão nova no winget" })
            [void](Set-WinForgeResultView -Result $final -Headline (Format-WinForgeCount -Count $counts.Total -One "programa instalado" -Many "programas instalados") `
                    -Note "$updatesText; a lista completa está nos detalhes técnicos." `
                    -Next $(if ($counts.Updates -gt 0) { "updates.winget" } else { "" }) -NextLabel $(if ($counts.Updates -gt 0) { "Atualizar programas" } else { "" }))
        }
        else {
            Write-WinForgeStatus -Type Warning -Message "O winget terminou com problemas ($($exitResult.Detail)); a lista pode estar incompleta."
            $final = New-WinForgeResult -Kind Warning -Detail "a lista pode estar incompleta: $($exitResult.Detail)" -Data @{ Count = $counts.Total }
        }

        if ($counts.Updates -gt 0) {
            Write-WinForgeStatus -Type Info -Message "Para atualizar, use Atualizações > Atualizar programas (winget)."
        }

        Write-WinForgeStatus -Type Info -Message "Para remover programas, use Programas > Desinstalar programas."
    }
    catch {
        Write-WinForgeStatus -Type Error -Message "Não foi possível listar os programas: $($_.Exception.Message.TrimEnd('.'))."
        $final = New-WinForgeResult -Kind Failed -Detail $_.Exception.Message
    }

    Exit-WinForgeAction -Result $final
}


function Find-WinForgeSoftware {
    # Busca no winget, deixa o usuário marcar os resultados e instala os escolhidos.
    Enter-WinForgeAction -Title "Buscar e instalar programas"

    # O desfecho vem do que aconteceu, não da contagem de mensagens: desistir é "Cancelado", a busca sem resultado é "nada a
    # fazer" (cinza) e o único pacote que não instala é falha (vermelho), nunca "ressalva".
    $final = New-WinForgeResult -Kind Failed -Detail "a busca não devolveu resultado"

    try {
        if (-not (Initialize-WinForgeWinget -OfferStore)) {
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Failed -Detail (Get-WinForgeWingetMissingDetail))
            return
        }

        Write-WinForgeWingetUserWarning -Context Install
        Write-Host ""
        $term = Read-WinForgeText -Message "Nome (ou ID) do programa que deseja buscar"

        # Aspas dentro do termo quebram a passagem de argumentos no Windows PowerShell 5.1.
        $term = ($term -replace '["`]', " ").Trim()

        # Campo vazio é desistência (o botão Cancelar da janela devolve o mesmo vazio).
        if ([string]::IsNullOrWhiteSpace($term)) {
            Write-WinForgeStatus -Type Warning -Message "Operação cancelada."
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Skipped -Detail "cancelado pelo usuário")
            return
        }

        if ($term.Length -gt 100) {
            $term = $term.Substring(0, 100)
        }

        Write-Progress -Activity "Buscando programas" -Status "procurando '$term' no winget"

        try {
            $search = Invoke-WinForgeCapture -FilePath "winget" -Arguments @("search", "--query", $term, "--accept-source-agreements")
        }
        finally {
            Write-Progress -Activity "Buscando programas" -Completed
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
                Write-WinForgeStatus -Type Warning -Message "Nenhum programa encontrado para '$term'."
                Write-WinForgeStatus -Type Info -Message "Tente outro nome, uma parte do nome ou o ID do programa (por exemplo, 7zip.7zip)."
                $final = New-WinForgeResult -Kind Skipped -Detail "nenhum programa encontrado para '$term'"
            }
            else {
                $reason = (Get-WinForgeWingetExitResult -ExitCode $search.ExitCode).Detail
                Write-WinForgeStatus -Type Error -Message "A busca por '$term' falhou: $reason."
                $final = New-WinForgeResult -Kind Failed -Detail "a busca falhou: $reason"
            }

            Exit-WinForgeAction -Result $final
            return
        }

        $installedIds = Get-WinForgeInstalledWingetIds -Activity "Buscando programas"

        $options = @(
            foreach ($package in $results) {
                $description = Format-WinForgeWingetPackageDescription -Package $package
                @{ Key = $package.Id; Label = $package.Nome; Description = $(if (Test-WinForgeWingetIdInstalled -Installed $installedIds -Id $package.Id) { "já instalado · $description" } else { $description }) }
            }
        )

        # Antes da lista: durante a pergunta de marcar, a janela mostra o resumo, e os detalhes técnicos ficam recolhidos.
        Write-WinForgeStatus -Type Info -Message "Alguns instaladores podem pedir para fechar programas abertos ou reiniciar o PC."
        if (@($results | Where-Object { Test-WinForgeWingetIdInstalled -Installed $installedIds -Id $_.Id }).Count -gt 0) {
            Write-WinForgeStatus -Type Info -Message "O que aparece como já instalado é atualizado, se houver versão nova."
        }
        Write-Host ""

        $found = Format-WinForgeCount -Count $results.Count -One "resultado" -Many "resultados"
        $picked = Read-WinForgeMultiSelect -Message "$found para '$term'. Marque o que deseja instalar" -Options $options

        if ($null -eq $picked -or @($picked).Count -eq 0) {
            Write-WinForgeStatus -Type Warning -Message "Operação cancelada."
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Skipped -Detail "cancelado pelo usuário")
            return
        }

        $packages = @($results | Where-Object { @($picked) -contains $_.Id })
        $result = Get-WinForgeLastResult -Output (Invoke-WinForgeWingetPackages -Operation Install -Packages $packages)
        if ($null -ne $result) {
            $final = Set-WinForgeWingetPackagesView -Operation Install -Packages $packages -Result $result -Installed $installedIds
            Add-WinForgeInstalledProgramsChange -Packages $packages -Result $result -Installed $installedIds
        }
    }
    catch {
        Write-WinForgeStatus -Type Error -Message "Não foi possível buscar ou instalar: $($_.Exception.Message.TrimEnd('.'))."
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

    Write-WinForgeSection -Title "Vão ser desinstalados"

    foreach ($package in $Packages) {
        $name = ([string]$package.Nome).Trim()
        if ($name.Length -gt 48) { $name = $name.Substring(0, 45) + "..." }
        $version = ([string]$package.Versao).Trim()
        $versions = [int](Get-WinForgeJsonValue -Object $package -Name "Versoes" -Default 1)
        $versionText = $(if ($versions -gt 1) { "$versions versões" } elseif ($version -and $version -notmatch '^(\?|Unknown|Desconhecid[ao])$') { "versão $version" } else { "versão não informada" })

        Write-WinForgeKeyValue -Label $name -Value $versionText -LabelWidth 32
    }

    Write-Host ""

    $drivers = @($Packages | Where-Object { Get-WinForgeWingetPackageCaution -Package $_ } | ForEach-Object { [string]$_.Nome })

    if ($drivers.Count -eq 1) {
        Write-WinForgeStatus -Type Warning -Notice -Message "$($drivers[0]) é driver de um aparelho do PC: o aparelho pode parar de funcionar."
    }
    elseif ($drivers.Count -gt 1) {
        Write-WinForgeStatus -Type Warning -Notice -Message "$(Join-WinForgeList -Items $drivers) são drivers de aparelhos do PC: os aparelhos podem parar de funcionar."
    }
}


function Uninstall-WinForgeSoftware {
    Enter-WinForgeAction -Title "Desinstalar programas"

    # Mesmo critério de "Buscar e instalar": desistir é "Cancelado"; o programa que não sai é falha.
    $final = New-WinForgeResult -Kind Failed -Detail "a desinstalação não devolveu resultado"

    try {
        if (-not (Initialize-WinForgeWinget -OfferStore)) {
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Failed -Detail (Get-WinForgeWingetMissingDetail))
            return
        }

        Write-WinForgeWingetUserWarning
        Write-Progress -Activity "Desinstalar programas" -Status "lendo a lista de programas instalados"

        try {
            $listing = Invoke-WinForgeCapture -FilePath "winget" -Arguments @("list", "--accept-source-agreements")
            $all = @(ConvertFrom-WinForgeWingetTable -Lines $listing.Lines)

            # Só entra o que o WinForge consegue de fato desinstalar; o que fica de fora, e por quê, está em
            # Get-WinForgeUninstallCandidates (componentes do Windows, bibliotecas, entradas sem desinstalador...).
            $installed = @(Get-WinForgeUninstallCandidates -Packages $all)
        }
        finally {
            Write-Progress -Activity "Desinstalar programas" -Completed
        }

        Write-Host ""

        if ($all.Count -gt 0 -and $installed.Count -eq 0) {
            Write-WinForgeStatus -Type Info -Message "Nenhum programa para desinstalar."
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Skipped -Detail "nenhum programa para desinstalar")
            return
        }

        if ($installed.Count -eq 0) {
            $listing.Lines | ForEach-Object { Write-Host $_ }
            Write-Host ""

            $exitResult = Get-WinForgeWingetExitResult -ExitCode $listing.ExitCode
            $reason = $(if ($exitResult.Kind -ne "Ok") { $exitResult.Detail } elseif ([string]::IsNullOrWhiteSpace($listing.Text)) { "o winget não respondeu" } else { "o WinForge não reconheceu a tabela do winget" })

            Write-WinForgeStatus -Type Error -Message "Não foi possível ler a lista de programas: $reason."
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Failed -Detail "não foi possível ler a lista de programas: $reason")
            return
        }

        $options = @(
            foreach ($package in $installed) {
                $caution = Get-WinForgeWingetPackageCaution -Package $package
                $description = Format-WinForgeWingetPackageDescription -Package $package
                @{ Key = $package.Id; Label = $package.Nome; Description = $(if ($caution -and $description) { "Atenção: $caution · $description" } elseif ($caution) { "Atenção: $caution" } else { $description }) }
            }
        )

        # Sem "Marcar todos": desinstalar é de um em um, e um clique não pode marcar a lista inteira.
        $count = Format-WinForgeCount -Count $installed.Count -One "programa instalado" -Many "programas instalados"
        $picked = Read-WinForgeMultiSelect -Message "O que desinstalar? ($count)" -Options $options -NoSelectAll -ConfirmLabel "Desinstalar"

        if ($null -eq $picked -or @($picked).Count -eq 0) {
            Write-WinForgeStatus -Type Warning -Message "Operação cancelada."
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Skipped -Detail "cancelado pelo usuário")
            return
        }

        $packages = @($installed | Where-Object { @($picked) -contains $_.Id })

        # Na hora de decidir, a pessoa revê o que marcou (com a versão) e os avisos de cada um, que na lista eram só texto
        # cinza. Até três nomes, a própria pergunta os diz; com mais, ela aponta para a lista.
        Write-WinForgeUninstallPreview -Packages $packages
        $names = @($packages | ForEach-Object { [string]$_.Nome })
        $question = $(if ($names.Count -le 3) { Get-WinForgeSelectionQuestion -Verb "Desinstalar" -Names $names -Many "programas" } else { "Desinstalar os $($names.Count) programas listados acima?" })

        if (-not (Confirm-WinForgeAction $question -DefaultKey N)) {
            Write-WinForgeStatus -Type Warning -Message "Operação cancelada."
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Skipped -Detail "cancelado pelo usuário")
            return
        }

        $result = Get-WinForgeLastResult -Output (Invoke-WinForgeWingetPackages -Operation Uninstall -Packages $packages)
        if ($null -ne $result) { $final = Set-WinForgeWingetPackagesView -Operation Uninstall -Packages $packages -Result $result }

        # Só os que saíram de fato da lista (ou saem no próximo reinício) vão para o Histórico e para a busca de restos.
        $doneIds = @(Get-WinForgeResultData -Result $final -Name "SucceededIds")
        $removed = @($packages | Where-Object { $doneIds -contains [string]$_.Id })

        if ($final.Kind -in @("Ok", "Warning") -and $removed.Count -gt 0) {
            [void](Add-WinForgeChange -Action "Programas desinstalados" -Text (Join-WinForgeList -Items @($removed | ForEach-Object { [string]$_.Nome })))

            foreach ($package in $removed) { Add-WinForgeUninstalledProgram -Name ([string]$package.Nome) -Id ([string]$package.Id) }

            Write-WinForgeStatus -Type Info -Message "Para procurar restos, use Limpeza > Restos de programas desinstalados."
        }
    }
    catch {
        Write-WinForgeStatus -Type Error -Message "Não foi possível desinstalar: $($_.Exception.Message.TrimEnd('.'))."
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

    if ($new.Count -gt 0) { [void](Add-WinForgeChange -Action "Programas instalados" -Text (Join-WinForgeList -Items $new)) }
    if ($updated.Count -gt 0) { [void](Add-WinForgeChange -Action "Programas atualizados" -Text (Join-WinForgeList -Items $updated)) }
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

    $order = @("Básico", "Comunicação e mídia", "Produtividade", "Jogos")
    $index = [array]::IndexOf($order, [string]$Category)

    if ($index -ge 0) { return $index }
    if ($Category -in @("Para programadores", "Desenvolvimento")) { return 1000 }

    return 100
}


function Install-WinForgeEssentialSoftware {
    Enter-WinForgeAction -Title "Instalar programas essenciais"

    # Mesmo critério de "Buscar e instalar": desistir é "Cancelado"; o único programa que não instala é falha.
    $final = New-WinForgeResult -Kind Failed -Detail "a instalação não devolveu resultado"

    try {
        if (-not (Initialize-WinForgeWinget -OfferStore)) {
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Failed -Detail (Get-WinForgeWingetMissingDetail))
            return
        }

        Write-WinForgeWingetUserWarning -Context Install

        $catalog = @(Get-WinForgeEssentialSoftwareCatalog | Sort-Object @{ Expression = { Get-WinForgeEssentialCategoryRank -Category $_.Categoria } }, Categoria, Nome)

        # Quem já tem o programa vê isso na lista, em vez de reinstalar sem saber.
        $installedIds = Get-WinForgeInstalledWingetIds -Activity "Instalar programas essenciais"
        $already = @($catalog | Where-Object { Test-WinForgeWingetIdInstalled -Installed $installedIds -Id $_.Id })

        $options = @(
            foreach ($entry in $catalog) {
                $description = "$($entry.Categoria) · $($entry.Descricao)"
                @{ Key = $entry.Id; Label = $entry.Nome; Description = $(if (Test-WinForgeWingetIdInstalled -Installed $installedIds -Id $entry.Id) { "já instalado · $description" } else { $description }) }
            }
        )

        # Antes da lista: durante a pergunta de marcar, a janela mostra o resumo, e os detalhes técnicos ficam recolhidos.
        Write-WinForgeStatus -Type Info -Message "Alguns instaladores podem pedir para fechar programas abertos ou reiniciar o PC."
        if ($already.Count -gt 0) {
            Write-WinForgeStatus -Type Info -Message "$(if ($already.Count -eq 1) { '1 programa da lista já está instalado: marcado, ele é atualizado' } else { "$($already.Count) programas da lista já estão instalados: marcados, eles são atualizados" }) se houver versão nova."
        }
        else {
            Write-WinForgeStatus -Type Info -Message "O que já estiver instalado é atualizado, se houver versão nova."
        }
        Write-Host ""

        $picked = Read-WinForgeMultiSelect -Message "Escolha os programas para instalar" -Options $options

        if ($null -eq $picked -or @($picked).Count -eq 0) {
            Write-WinForgeStatus -Type Warning -Message "Operação cancelada."
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Skipped -Detail "cancelado pelo usuário")
            return
        }

        $packages = @($catalog | Where-Object { @($picked) -contains $_.Id })

        $result = Get-WinForgeLastResult -Output (Invoke-WinForgeWingetPackages -Operation Install -Packages $packages -WingetSourceOnly)
        if ($null -ne $result) {
            $final = Set-WinForgeWingetPackagesView -Operation Install -Packages $packages -Result $result -Installed $installedIds
            Add-WinForgeInstalledProgramsChange -Packages $packages -Result $result -Installed $installedIds
        }
    }
    catch {
        Write-WinForgeStatus -Type Error -Message "Não foi possível instalar: $($_.Exception.Message.TrimEnd('.'))."
        $final = New-WinForgeResult -Kind Failed -Detail $_.Exception.Message
    }

    Exit-WinForgeAction -Result $final
}


Export-ModuleMember -Function *
