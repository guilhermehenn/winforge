# Programas: instalação, atualização e remoção pelo winget.
# O winget só é consultado quando uma ação precisa dele (e a lista de pacotes é atualizada uma vez por sessão).

$script:WinForgeWingetReady = $false


# ---------------------------------------------------------------------------
# Disponibilidade do winget
# ---------------------------------------------------------------------------

function Test-WinForgeWinget {
    return [bool](Get-Command -Name "winget" -CommandType Application -ErrorAction SilentlyContinue)
}


function Initialize-WinForgeWinget {
    # Verifica o winget e atualiza a fonte principal uma única vez por sessão. Devolve $false se não houver winget.
    param (
        [switch]$Force
    )

    if (-not (Test-WinForgeWinget)) {
        Write-WinForgeStatus -Type Error -Message "O winget não foi encontrado neste sistema."
        Write-Host "      Instale ou atualize o 'Instalador de Aplicativo' (App Installer) pela Microsoft Store." -ForegroundColor DarkGray
        return $false
    }

    if ($script:WinForgeWingetReady -and -not $Force) {
        return $true
    }

    Write-WinForgeStatus -Type Running -Message "Atualizando a lista de pacotes do winget..."
    $source = Invoke-WinForgeCapture -FilePath "winget" -Arguments @("source", "update", "--name", "winget", "--disable-interactivity")

    if ($source.ExitCode -eq 0) {
        Write-WinForgeStatus -Type Success -Message "Lista de pacotes atualizada."
    }
    else {
        Write-WinForgeStatus -Type Warning -Message "Não foi possível atualizar a lista de pacotes; a consulta usará os dados em cache."
    }

    $script:WinForgeWingetReady = $true
    return $true
}


function Write-WinForgeWingetUserWarning {
    # Pacotes instalados só para o usuário logado não aparecem quando o WinForge foi elevado com outra conta.
    if (-not (Test-WinForgeUserContextMismatch)) {
        return
    }

    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent().Name
    $interactiveUser = Get-WinForgeInteractiveUser

    Write-WinForgeStatus -Type Warning -Message "O WinForge está elevado como $currentUser."
    Write-WinForgeStatus -Type Info -Message "Pacotes exclusivos de $interactiveUser podem não aparecer neste contexto."
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

    # Caminho rápido: sem caracteres largos, coluna e posição no texto são a mesma coisa.
    if ($Text -notmatch "[\u0300-\u036F\u1100-\uFFFF]|[\uD800-\uDFFF]") {
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

        $column += Get-WinForgeCharWidth -Char $char
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

        # Uma linha sem Id (texto solto depois da tabela) não é um pacote.
        if ([string]::IsNullOrWhiteSpace($id) -or $id -match "\s") {
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
    param (
        [string]$OutputText
    )

    return (
        $OutputText -match "No installed package found matching input criteria" -or
        $OutputText -match "No available upgrade found" -or
        $OutputText -match "Nenhuma atualização" -or
        $OutputText -match "Nenhuma atualizacao" -or
        $OutputText -match "Nenhum pacote instalado"
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
        [switch]$WingetSourceOnly
    )

    switch ($Operation) {
        "UpgradeAll" {
            return @("upgrade", "--all", "--accept-source-agreements", "--accept-package-agreements", "--disable-interactivity", "--silent")
        }
        "Uninstall" {
            return @("uninstall", "--id", $PackageId, "-e", "--disable-interactivity", "--silent")
        }
        default {
            $verb = $Operation.ToLowerInvariant()
            $arguments = @($verb, "--id", $PackageId, "-e", "--accept-source-agreements", "--accept-package-agreements", "--disable-interactivity", "--silent")

            if ($WingetSourceOnly) {
                $arguments += @("--source", "winget")
            }

            return $arguments
        }
    }
}


function Get-WinForgeWingetExitResult {
    # Traduz o código de saída do winget. Os códigos 0x8A15xxxx chegam como inteiros negativos.
    param (
        [int]$ExitCode
    )

    switch ($ExitCode) {
        0 { return (New-WinForgeResult -Kind Ok) }
        -1978335189 { return (New-WinForgeResult -Kind Ok -Detail "já está na versão mais recente") }
        -1978335135 { return (New-WinForgeResult -Kind Ok -Detail "já estava instalado") }
        -1978335212 { return (New-WinForgeResult -Kind Failed -Detail "pacote não encontrado") }
        default {
            $hex = $ExitCode.ToString("X8")
            return (New-WinForgeResult -Kind Failed -Detail "código $ExitCode (0x$hex)")
        }
    }
}


function Invoke-WinForgeWingetPackages {
    <#
    Instala, atualiza ou desinstala uma lista de pacotes, um por vez, com resumo no final.
    Packages: objetos com Id e Nome. Devolve um WinForge.Result.
    #>
    param (
        [Parameter(Mandatory)]
        [ValidateSet("Install", "Upgrade", "Uninstall")]
        [string]$Operation,

        [Parameter(Mandatory)]
        [object[]]$Packages,

        [switch]$WingetSourceOnly
    )

    $verbText = switch ($Operation) {
        "Install"   { "Instalando" }
        "Upgrade"   { "Atualizando" }
        "Uninstall" { "Desinstalando" }
    }

    $outcomes = @()
    $position = 0

    foreach ($package in $Packages) {
        $position++
        $arguments = Get-WinForgeWingetArguments -Operation $Operation -PackageId $package.Id -WingetSourceOnly:$WingetSourceOnly

        Write-Host ""
        Write-WinForgeProgress -Current ($position - 1) -Total $Packages.Count -Label "$verbText $($package.Nome)"
        Write-WinForgeCommand -Command "winget $($arguments -join ' ')"
        Write-Host ""

        $exitCode = Invoke-WinForgeNative -FilePath "winget" -Arguments $arguments -IgnoreExitCode -PassThru
        $result = Get-WinForgeWingetExitResult -ExitCode $exitCode
        $result.Etapa = [string]$package.Nome

        Write-Host ""

        if ($result.Kind -eq "Ok") {
            Write-WinForgeStatus -Type Success -Message "$($package.Nome): $($result.Status)"
        }
        else {
            Write-WinForgeStatus -Type Warning -Message "$($package.Nome): $($result.Status)"
        }

        $outcomes += $result
    }

    if ($Packages.Count -gt 1) {
        Write-WinForgeSection -Title "Resumo"
        Write-WinForgeResultTable -Results $outcomes
    }

    $failed = @($outcomes | Where-Object { $_.Kind -ne "Ok" })

    if ($failed.Count -eq 0) {
        return (New-WinForgeResult -Kind Ok)
    }

    $names = ($failed | ForEach-Object { $_.Etapa }) -join ", "

    if ($failed.Count -eq $outcomes.Count) {
        return (New-WinForgeResult -Kind Failed -Detail "nenhum pacote foi processado: $names")
    }

    return (New-WinForgeResult -Kind Warning -Detail "$($failed.Count) de $($outcomes.Count) com falha: $names")
}


# ---------------------------------------------------------------------------
# Atualização
# ---------------------------------------------------------------------------

function Get-WinForgeWingetUpgradePlan {
    <#
    Coleta a decisão do usuário sem instalar nada, para que a Manutenção recomendada possa perguntar tudo antes da
    fase automática. Action: Unavailable | NoUpdates | None | All | Ids.
    #>
    if (-not (Initialize-WinForgeWinget)) {
        return [PSCustomObject]@{ Action = "Unavailable"; Ids = @(); Packages = @() }
    }

    Write-Host "Esta opção atualiza apenas programas gerenciados pelo winget." -ForegroundColor Yellow
    Write-Host "O Windows Update, os drivers opcionais e a Microsoft Store ficam nos outros itens da página Atualizações." -ForegroundColor Cyan
    Write-Host ""

    Write-WinForgeStatus -Type Running -Message "Verificando atualizações disponíveis..."
    Write-Host ""

    $upgrade = Invoke-WinForgeCapture -FilePath "winget" -Arguments @("upgrade", "--accept-source-agreements") -Echo

    if (Test-WinForgeWingetNoUpgradeOutput -OutputText $upgrade.Text) {
        Write-Host ""
        Write-WinForgeStatus -Type Success -Message "Nenhuma atualização via winget foi encontrada."
        return [PSCustomObject]@{ Action = "NoUpdates"; Ids = @(); Packages = @() }
    }

    if ($upgrade.ExitCode -ne 0 -and [string]::IsNullOrWhiteSpace($upgrade.Text)) {
        throw "O winget terminou com código $($upgrade.ExitCode) sem retornar detalhes."
    }

    $available = @(ConvertFrom-WinForgeWingetTable -Lines $upgrade.Lines)

    if ($available.Count -eq 0 -and $upgrade.ExitCode -ne 0) {
        throw "Não foi possível consultar as atualizações do winget (código $($upgrade.ExitCode))."
    }

    Write-Host ""

    while ($true) {
        $choice = Read-WinForgeChoice -Message "Como deseja continuar?" -TextPrompt "Digite S, N ou E" -ShowMenu -Options @(
            @{ Key = "S"; Label = "Atualizar todos os pacotes"; Accent = $true },
            @{ Key = "E"; Label = "Escolher quais atualizar"; Description = "marque os pacotes na lista" },
            @{ Key = "N"; Label = "Não atualizar"; Exit = $true }
        )

        if ($choice -eq "N") {
            return [PSCustomObject]@{ Action = "None"; Ids = @(); Packages = $available }
        }

        if ($choice -eq "S") {
            return [PSCustomObject]@{ Action = "All"; Ids = @(); Packages = $available }
        }

        if ($available.Count -gt 0) {
            $options = @(
                foreach ($package in $available) {
                    @{ Key = $package.Id; Label = $package.Nome; Description = "$($package.Id)  -  $($package.Versao) -> $($package.Disponivel)" }
                }
            )

            $picked = Read-WinForgeMultiSelect -Message "Escolha os pacotes para atualizar" -Options $options

            if ($null -eq $picked -or @($picked).Count -eq 0) {
                Write-WinForgeStatus -Type Warning -Message "Nenhum pacote selecionado."
                continue
            }

            return [PSCustomObject]@{ Action = "Ids"; Ids = @($picked); Packages = $available }
        }

        # Sem tabela reconhecida (formato inesperado do winget): permite informar os IDs manualmente.
        Write-Host ""
        Write-Host "  Não foi possível ler a tabela de pacotes; informe os IDs manualmente." -ForegroundColor Yellow
        Write-Host "  Para vários pacotes, separe os IDs por vírgula. Exemplo: Google.Chrome, Notepad++.Notepad++" -ForegroundColor DarkCyan
        Write-Host ""

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
            return (New-WinForgeResult -Kind Ok -Detail "nada a atualizar")
        }
        "Error" {
            return (New-WinForgeResult -Kind Failed -Detail $Plan.Detail)
        }
        "None" {
            Write-WinForgeStatus -Type Warning -Message "Atualização via winget não executada."
            return (New-WinForgeResult -Kind Skipped -Detail "dispensado pelo usuário")
        }
        "Ids" {
            $packages = @(
                foreach ($id in @($Plan.Ids)) {
                    $known = @($Plan.Packages | Where-Object { $_.Id -eq $id }) | Select-Object -First 1
                    [PSCustomObject]@{ Id = $id; Nome = $(if ($known) { $known.Nome } else { $id }) }
                }
            )

            return (Invoke-WinForgeWingetPackages -Operation Upgrade -Packages $packages)
        }
        "All" {
            $arguments = Get-WinForgeWingetArguments -Operation UpgradeAll

            Write-Host ""
            Write-WinForgeStatus -Type Running -Message "Atualizando todos os pacotes disponíveis..."
            Write-WinForgeCommand -Command "winget $($arguments -join ' ')"
            Write-Host ""

            $exitCode = Invoke-WinForgeNative -FilePath "winget" -Arguments $arguments -IgnoreExitCode -PassThru

            Write-Host ""

            if ($exitCode -eq 0) {
                Write-WinForgeStatus -Type Success -Message "Atualização via winget finalizada."
                Write-WinForgeStatus -Type Info -Message "Alguns aplicativos podem exigir reinicialização ou uma etapa manual."
                return (New-WinForgeResult -Kind Ok)
            }

            Write-WinForgeStatus -Type Warning -Message "O winget terminou com código $exitCode. Revise a saída acima."
            return (New-WinForgeResult -Kind Warning -Detail "winget terminou com código $exitCode")
        }
    }

    # Um plano que este código não conhece é um erro de programação, não um sucesso.
    return (New-WinForgeResult -Kind Failed -Detail "ação desconhecida no plano: $($Plan.Action)")
}


function Update-WinForgeSoftware {
    Enter-WinForgeAction -Title "Atualizar programas (winget)"

    try {
        $plan = Get-WinForgeWingetUpgradePlan
        [void](Invoke-WinForgeWingetUpgradePlan -Plan $plan)
    }
    catch {
        Write-Host ""
        Write-WinForgeStatus -Type Error -Message "Ocorreu um erro ao atualizar programas via winget: $($_.Exception.Message)"
    }

    Exit-WinForgeAction
}


# ---------------------------------------------------------------------------
# Listar, buscar e instalar, desinstalar
# ---------------------------------------------------------------------------

function Show-WinForgeInstalledSoftware {
    Enter-WinForgeAction -Title "Listar programas instalados"

    try {
        if (Initialize-WinForgeWinget) {
            Write-WinForgeWingetUserWarning

            # A tabela é exibida como o winget a gera: não depende do idioma nem de versões do formato.
            $exitCode = Invoke-WinForgeNative -FilePath "winget" -Arguments @("list", "--accept-source-agreements") -IgnoreExitCode -PassThru

            Write-Host ""

            if ($exitCode -ne 0) {
                Write-WinForgeStatus -Type Warning -Message "O winget terminou com código $exitCode."
            }

            Write-WinForgeStatus -Type Info -Message "Para remover programas, use Programas > Desinstalar programas."
        }
    }
    catch {
        Write-WinForgeStatus -Type Error -Message "Ocorreu um erro ao listar os programas instalados: $($_.Exception.Message)"
    }

    Exit-WinForgeAction
}


function Find-WinForgeSoftware {
    # Busca no winget, deixa o usuário marcar os resultados e instala os escolhidos.
    Enter-WinForgeAction -Title "Buscar e instalar programas"

    try {
        if (-not (Initialize-WinForgeWinget)) {
            Exit-WinForgeAction
            return
        }

        Write-Host ""
        $term = Read-WinForgeText -Message "Nome (ou ID) do programa que deseja buscar"

        # Aspas dentro do termo quebram a passagem de argumentos no Windows PowerShell 5.1.
        $term = ($term -replace '["`]', " ").Trim()

        if ([string]::IsNullOrWhiteSpace($term)) {
            Write-WinForgeStatus -Type Warning -Message "Nenhum termo informado. Busca cancelada."
            Exit-WinForgeAction
            return
        }

        if ($term.Length -gt 100) {
            $term = $term.Substring(0, 100)
        }

        Write-Host ""
        Write-WinForgeStatus -Type Running -Message "Buscando por: $term"

        $search = Invoke-WinForgeCapture -FilePath "winget" -Arguments @("search", "--query", $term, "--accept-source-agreements")
        $results = @(ConvertFrom-WinForgeWingetTable -Lines $search.Lines)

        Write-Host ""

        if ($results.Count -eq 0) {
            if (-not [string]::IsNullOrWhiteSpace($search.Text)) {
                $search.Lines | ForEach-Object { Write-Host $_ }
                Write-Host ""
            }

            Write-WinForgeStatus -Type Warning -Message "Nenhum pacote encontrado para '$term'."
            Exit-WinForgeAction
            return
        }

        $options = @(
            foreach ($package in $results) {
                @{ Key = $package.Id; Label = $package.Nome; Description = "$($package.Id)  -  $($package.Versao)" }
            }
        )

        $picked = Read-WinForgeMultiSelect -Message "Encontrados $($results.Count) pacote(s). Marque os que deseja instalar" -Options $options

        if ($null -eq $picked -or @($picked).Count -eq 0) {
            Write-WinForgeStatus -Type Warning -Message "Nenhum pacote selecionado."
            Exit-WinForgeAction
            return
        }

        $packages = @($results | Where-Object { @($picked) -contains $_.Id })
        [void](Invoke-WinForgeWingetPackages -Operation Install -Packages $packages)

        Write-Host ""
        Write-WinForgeStatus -Type Info -Message "Alguns instaladores podem exigir interação manual ou reinicialização."
    }
    catch {
        Write-WinForgeStatus -Type Error -Message "Ocorreu um erro ao buscar ou instalar: $($_.Exception.Message)"
    }

    Exit-WinForgeAction
}


function Uninstall-WinForgeSoftware {
    Enter-WinForgeAction -Title "Desinstalar programas"

    try {
        if (-not (Initialize-WinForgeWinget)) {
            Exit-WinForgeAction
            return
        }

        Write-WinForgeWingetUserWarning
        Write-WinForgeStatus -Type Running -Message "Lendo a lista de programas instalados..."

        $listing = Invoke-WinForgeCapture -FilePath "winget" -Arguments @("list", "--accept-source-agreements")
        $installed = @(ConvertFrom-WinForgeWingetTable -Lines $listing.Lines | Sort-Object Nome)

        Write-Host ""

        if ($installed.Count -eq 0) {
            $listing.Lines | ForEach-Object { Write-Host $_ }
            Write-Host ""
            Write-WinForgeStatus -Type Warning -Message "Não foi possível ler a lista de programas (código $($listing.ExitCode))."
            Exit-WinForgeAction
            return
        }

        Write-Host "Remova somente programas que você reconhece e não usa." -ForegroundColor Yellow
        Write-Host ""

        $options = @(
            foreach ($package in $installed) {
                @{ Key = $package.Id; Label = $package.Nome; Description = "$($package.Id)  -  $($package.Versao)" }
            }
        )

        $picked = Read-WinForgeMultiSelect -Message "Marque os programas que deseja desinstalar" -Options $options

        if ($null -eq $picked -or @($picked).Count -eq 0) {
            Write-WinForgeStatus -Type Warning -Message "Nenhum programa selecionado."
            Exit-WinForgeAction
            return
        }

        $packages = @($installed | Where-Object { @($picked) -contains $_.Id })

        Write-WinForgeSection -Title "Programas que serão desinstalados"
        $packages | ForEach-Object { Write-Host ("  - {0}  ({1})" -f $_.Nome, $_.Id) -ForegroundColor Gray }
        Write-Host ""

        if (-not (Confirm-WinForgeAction "Deseja desinstalar $($packages.Count) programa(s)?" -DefaultKey N)) {
            Write-WinForgeStatus -Type Warning -Message "Desinstalação cancelada."
            Exit-WinForgeAction
            return
        }

        [void](Invoke-WinForgeWingetPackages -Operation Uninstall -Packages $packages)

        Write-Host ""
        Write-WinForgeStatus -Type Info -Message "Alguns aplicativos podem exigir uma etapa manual ou reinicialização."
    }
    catch {
        Write-WinForgeStatus -Type Error -Message "Ocorreu um erro ao desinstalar: $($_.Exception.Message)"
    }

    Exit-WinForgeAction
}


# ---------------------------------------------------------------------------
# Programas essenciais
# ---------------------------------------------------------------------------

function Get-WinForgeEssentialSoftwareCatalog {
    return @(
        [PSCustomObject]@{ Categoria = "Básico"; Nome = "7-Zip"; Id = "7zip.7zip" },
        [PSCustomObject]@{ Categoria = "Básico"; Nome = "Google Chrome"; Id = "Google.Chrome" },
        [PSCustomObject]@{ Categoria = "Básico"; Nome = "Mozilla Firefox"; Id = "Mozilla.Firefox" },
        [PSCustomObject]@{ Categoria = "Básico"; Nome = "Notepad++"; Id = "Notepad++.Notepad++" },
        [PSCustomObject]@{ Categoria = "Básico"; Nome = "VLC Media Player"; Id = "VideoLAN.VLC" },
        [PSCustomObject]@{ Categoria = "Comunicação e mídia"; Nome = "Discord"; Id = "Discord.Discord" },
        [PSCustomObject]@{ Categoria = "Comunicação e mídia"; Nome = "Spotify"; Id = "Spotify.Spotify" },
        [PSCustomObject]@{ Categoria = "Desenvolvimento"; Nome = "Git"; Id = "Git.Git" },
        [PSCustomObject]@{ Categoria = "Desenvolvimento"; Nome = "Java JDK 21 (Temurin)"; Id = "EclipseAdoptium.Temurin.21.JDK" },
        [PSCustomObject]@{ Categoria = "Desenvolvimento"; Nome = "Node.js LTS"; Id = "OpenJS.NodeJS.LTS" },
        [PSCustomObject]@{ Categoria = "Desenvolvimento"; Nome = "PowerShell 7"; Id = "Microsoft.PowerShell" },
        [PSCustomObject]@{ Categoria = "Desenvolvimento"; Nome = "Python 3.12"; Id = "Python.Python.3.12" },
        [PSCustomObject]@{ Categoria = "Desenvolvimento"; Nome = "Visual Studio Code"; Id = "Microsoft.VisualStudioCode" },
        [PSCustomObject]@{ Categoria = "Jogos"; Nome = "Steam"; Id = "Valve.Steam" },
        [PSCustomObject]@{ Categoria = "Produtividade"; Nome = "Everything"; Id = "voidtools.Everything" },
        [PSCustomObject]@{ Categoria = "Produtividade"; Nome = "Microsoft PowerToys"; Id = "Microsoft.PowerToys" }
    )
}


function Install-WinForgeEssentialSoftware {
    Enter-WinForgeAction -Title "Instalar programas essenciais"

    try {
        if (-not (Initialize-WinForgeWinget)) {
            Exit-WinForgeAction
            return
        }

        $catalog = @(Get-WinForgeEssentialSoftwareCatalog | Sort-Object Categoria, Nome)

        $options = @(
            foreach ($entry in $catalog) {
                @{ Key = $entry.Id; Label = $entry.Nome; Description = $entry.Categoria }
            }
        )

        Write-Host "Alguns instaladores podem exigir interação, fechar aplicativos abertos ou reiniciar o Windows." -ForegroundColor Yellow
        Write-Host ""

        $picked = Read-WinForgeMultiSelect -Message "Escolha os programas para instalar" -Options $options

        if ($null -eq $picked -or @($picked).Count -eq 0) {
            Write-WinForgeStatus -Type Warning -Message "Nenhum programa selecionado."
            Exit-WinForgeAction
            return
        }

        $packages = @($catalog | Where-Object { @($picked) -contains $_.Id })

        [void](Invoke-WinForgeWingetPackages -Operation Install -Packages $packages -WingetSourceOnly)
    }
    catch {
        Write-WinForgeStatus -Type Error -Message "Ocorreu um erro ao instalar: $($_.Exception.Message)"
    }

    Exit-WinForgeAction
}


Export-ModuleMember -Function *
