function Test-WinForgeWingetAvailable {
    $wingetExists = Get-Command winget -ErrorAction SilentlyContinue

    if (-not $wingetExists) {
        Write-Host "winget não foi encontrado neste sistema." -ForegroundColor Red
        Write-Host "Instale ou atualize o App Installer pela Microsoft Store." -ForegroundColor Yellow
        Write-Host ""
        return $false
    }

    return $true
}


function Get-WinForgeObjectPropertyValue {
    param (
        [object]$Object,
        [string[]]$Names
    )

    if ($null -eq $Object) {
        return ""
    }

    foreach ($name in $Names) {
        if ($Object.PSObject.Properties.Name -contains $name) {
            $value = $Object.$name

            if ($null -ne $value -and -not [string]::IsNullOrWhiteSpace($value.ToString())) {
                return $value.ToString().Trim()
            }
        }
    }

    return ""
}


function Get-WinForgeWingetJsonItems {
    param (
        [object]$JsonObject
    )

    if ($null -eq $JsonObject) {
        return @()
    }

    if ($JsonObject -is [array]) {
        return @($JsonObject)
    }

    if ($JsonObject.PSObject.Properties.Name -contains "Data") {
        return @($JsonObject.Data)
    }

    if ($JsonObject.PSObject.Properties.Name -contains "Sources") {
        $items = @()

        foreach ($source in @($JsonObject.Sources)) {
            if ($source.PSObject.Properties.Name -contains "Packages") {
                $items += @($source.Packages)
            }
            elseif ($source.PSObject.Properties.Name -contains "Data") {
                $items += @($source.Data)
            }
        }

        return @($items)
    }

    if ($JsonObject.PSObject.Properties.Name -contains "Packages") {
        return @($JsonObject.Packages)
    }

    return @()
}


function ConvertFrom-WinForgeWingetJsonPackage {
    param (
        [object]$Item
    )

    $name = Get-WinForgeObjectPropertyValue -Object $Item -Names @("Name", "PackageName", "DisplayName", "Moniker")
    $id = Get-WinForgeObjectPropertyValue -Object $Item -Names @("Id", "PackageIdentifier", "Identifier")
    $version = Get-WinForgeObjectPropertyValue -Object $Item -Names @("Version", "InstalledVersion")
    $source = Get-WinForgeObjectPropertyValue -Object $Item -Names @("Source", "SourceName")

    if ([string]::IsNullOrWhiteSpace($name) -and [string]::IsNullOrWhiteSpace($id)) {
        return $null
    }

    if ([string]::IsNullOrWhiteSpace($name)) { $name = "Não disponível" }
    if ([string]::IsNullOrWhiteSpace($id)) { $id = "Não disponível" }
    if ([string]::IsNullOrWhiteSpace($version)) { $version = "Não disponível" }
    if ([string]::IsNullOrWhiteSpace($source)) { $source = "Não disponível" }

    return [PSCustomObject]@{
        Nome   = $name
        Id     = $id
        Versao = $version
        Fonte  = $source
    }
}


function Get-WinForgeTextColumnIndex {
    param (
        [string]$Text,
        [string[]]$Names
    )

    foreach ($name in $Names) {
        $index = $Text.IndexOf($name)

        if ($index -ge 0) {
            return $index
        }
    }

    return -1
}


function Get-WinForgeSafeSubstring {
    param (
        [string]$Text,
        [int]$Start,
        [int]$End
    )

    if ([string]::IsNullOrEmpty($Text) -or $Start -lt 0 -or $Start -ge $Text.Length) {
        return ""
    }

    if ($End -le $Start -or $End -gt $Text.Length) {
        $End = $Text.Length
    }

    return $Text.Substring($Start, $End - $Start).Trim()
}


function ConvertFrom-WinForgeWingetListText {
    param (
        [string[]]$Lines
    )

    $packages = @()
    $lineArray = @($Lines)
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
    $sourceStart = Get-WinForgeTextColumnIndex -Text $header -Names @("Source", "Fonte")

    if ($nameStart -lt 0 -or $idStart -lt 0 -or $versionStart -lt 0) {
        return @()
    }

    $versionEnd = $lineArray[$headerIndex].Length

    if ($availableStart -gt $versionStart) {
        $versionEnd = $availableStart
    }
    elseif ($sourceStart -gt $versionStart) {
        $versionEnd = $sourceStart
    }

    for ($i = $headerIndex + 1; $i -lt $lineArray.Count; $i++) {
        $line = $lineArray[$i]

        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }

        if ($line.Trim() -match "^-+$") {
            continue
        }

        if ($line -match "^\d+\s+upgrades? available" -or $line -match "Nenhuma atualização" -or $line -match "No available upgrade") {
            continue
        }

        $name = Get-WinForgeSafeSubstring -Text $line -Start $nameStart -End $idStart
        $id = Get-WinForgeSafeSubstring -Text $line -Start $idStart -End $versionStart
        $version = Get-WinForgeSafeSubstring -Text $line -Start $versionStart -End $versionEnd
        $source = "Não disponível"

        if ($sourceStart -gt $versionStart) {
            $source = Get-WinForgeSafeSubstring -Text $line -Start $sourceStart -End $line.Length
        }

        if ([string]::IsNullOrWhiteSpace($name) -and [string]::IsNullOrWhiteSpace($id)) {
            continue
        }

        if ([string]::IsNullOrWhiteSpace($name)) { $name = "Não disponível" }
        if ([string]::IsNullOrWhiteSpace($id)) { $id = "Não disponível" }
        if ([string]::IsNullOrWhiteSpace($version)) { $version = "Não disponível" }
        if ([string]::IsNullOrWhiteSpace($source)) { $source = "Não disponível" }

        $packages += [PSCustomObject]@{
            Nome   = $name
            Id     = $id
            Versao = $version
            Fonte  = $source
        }
    }

    return @($packages)
}


function Get-WinForgeInstalledSoftwareList {
    $wingetExists = Get-Command winget -ErrorAction SilentlyContinue

    if (-not $wingetExists) {
        return @()
    }

    try {
        $jsonOutput = winget list --accept-source-agreements --output json 2>$null
        $jsonText = ($jsonOutput | Out-String).Trim()

        if (-not [string]::IsNullOrWhiteSpace($jsonText) -and $LASTEXITCODE -eq 0) {
            $jsonObject = $jsonText | ConvertFrom-Json
            $items = Get-WinForgeWingetJsonItems -JsonObject $jsonObject
            $packages = @()

            foreach ($item in $items) {
                $package = ConvertFrom-WinForgeWingetJsonPackage -Item $item

                if ($null -ne $package) {
                    $packages += $package
                }
            }

            if ($packages.Count -gt 0) {
                return @($packages | Sort-Object Nome, Id)
            }
        }
    }
    catch {
        # Alguns wingets antigos não suportam JSON para listagem. Usa fallback por texto abaixo.
    }

    try {
        $textOutput = winget list --accept-source-agreements 2>&1
        $packages = ConvertFrom-WinForgeWingetListText -Lines $textOutput
        return @($packages | Sort-Object Nome, Id)
    }
    catch {
        Write-Host "Ocorreu um erro ao executar winget list:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        return @()
    }
}


function Show-WinForgeSoftwareTable {
    param (
        [array]$Packages,
        [switch]$IncludeSource
    )

    $packageList = @($Packages)

    if ($packageList.Count -eq 0) {
        Write-Host "Nenhum software foi encontrado para exibição." -ForegroundColor Yellow
        return
    }

    if ($IncludeSource) {
        $packageList |
            Select-Object `
                @{ Name = "Nome"; Expression = { $_.Nome } },
                @{ Name = "Id"; Expression = { $_.Id } },
                @{ Name = "Versão"; Expression = { $_.Versao } },
                @{ Name = "Fonte"; Expression = { $_.Fonte } } |
            Format-Table -AutoSize |
            Out-Host
    }
    else {
        $packageList |
            Select-Object `
                @{ Name = "Nome"; Expression = { $_.Nome } },
                @{ Name = "Id"; Expression = { $_.Id } },
                @{ Name = "Versão"; Expression = { $_.Versao } } |
            Format-Table -AutoSize |
            Out-Host
    }
}


function Resolve-WinForgeInstalledPackage {
    param (
        [array]$Packages,
        [string]$Query
    )

    $cleanQuery = $Query.Trim()

    if ([string]::IsNullOrWhiteSpace($cleanQuery)) {
        return $null
    }

    $exactMatches = @(
        $Packages | Where-Object {
            $_.Id -ieq $cleanQuery -or $_.Nome -ieq $cleanQuery
        }
    )

    if ($exactMatches.Count -eq 1) {
        return $exactMatches[0]
    }

    if ($exactMatches.Count -gt 1) {
        Write-Host "Mais de um software corresponde exatamente ao texto informado." -ForegroundColor Yellow
        Write-Host "Refine usando o Id do pacote." -ForegroundColor Yellow
        Write-Host ""
        Show-WinForgeSoftwareTable -Packages $exactMatches
        return $null
    }

    $partialMatches = @(
        $Packages | Where-Object {
            $_.Id.IndexOf($cleanQuery, [System.StringComparison]::OrdinalIgnoreCase) -ge 0 -or
            $_.Nome.IndexOf($cleanQuery, [System.StringComparison]::OrdinalIgnoreCase) -ge 0
        }
    )

    if ($partialMatches.Count -eq 1) {
        return $partialMatches[0]
    }

    if ($partialMatches.Count -gt 1) {
        Write-Host "Mais de um software foi encontrado com esse texto." -ForegroundColor Yellow
        Write-Host "Digite o Nome completo ou, preferencialmente, o Id exato." -ForegroundColor Yellow
        Write-Host ""
        Show-WinForgeSoftwareTable -Packages $partialMatches
        return $null
    }

    return $null
}


function Get-InstalledSoftware {
    Show-Header "Softwares Instalados"

    try {
        if (-not (Test-WinForgeWingetAvailable)) {
            Pause
            return
        }

        $packages = Get-WinForgeInstalledSoftwareList
        Show-WinForgeSoftwareTable -Packages $packages -IncludeSource

        Write-Host ""
        Write-Host "Observação:" -ForegroundColor Yellow
        Write-Host "Para remover algum software, use a opção 'Desinstalar software' no menu de Softwares." -ForegroundColor Yellow
    }
    catch {
        Write-Host "Ocorreu um erro ao listar softwares instalados:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }

    Write-Host ""
    Pause
}


function Update-AllSoftware {
    Show-Header "Atualizar Softwares via winget"

    try {
        if (-not (Test-WinForgeWingetAvailable)) {
            Pause
            return
        }

        Write-Host "Esta opção atualiza apenas softwares gerenciados pelo winget." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Softwares fora do winget, drivers, BIOS, Windows Update e Microsoft Store não entram nesta rotina." -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Verificando atualizações disponíveis via winget..." -ForegroundColor Yellow
        Write-Host ""

        $upgradeOutput = winget upgrade --accept-source-agreements 2>&1
        $upgradeOutput | ForEach-Object { Write-Host $_ }

        $outputText = $upgradeOutput -join "`n"

        if (
            $outputText -match "No installed package found matching input criteria" -or
            $outputText -match "No available upgrade found" -or
            $outputText -match "Nenhuma atualização"
        ) {
            Write-Host ""
            Write-Host "Nenhuma atualização via winget foi encontrada." -ForegroundColor Green
            Write-Host ""
            Pause
            return
        }

        Write-Host ""

        $confirmed = Confirm-Action "Deseja atualizar todos os softwares disponíveis via winget?"

        if ($confirmed -eq $false) {
            Write-Host ""
            Write-Host "Atualização cancelada." -ForegroundColor Yellow
            Pause
            return
        }

        Write-Host ""
        Write-Host "Atualizando softwares via winget..." -ForegroundColor Green
        Write-Host ""

        winget upgrade --all --accept-source-agreements --accept-package-agreements --disable-interactivity

        $exitCode = $LASTEXITCODE

        Write-Host ""

        if ($exitCode -eq 0) {
            Write-Host "Processo de atualização via winget finalizado com sucesso." -ForegroundColor Green
        }
        else {
            Write-Host "winget finalizou com código de saída: $exitCode" -ForegroundColor Yellow
            Write-Host "Revise a saída acima para identificar o pacote que falhou." -ForegroundColor Yellow
        }

        Write-Host "Alguns aplicativos podem exigir atualização manual, interação do usuário ou reinicialização." -ForegroundColor Yellow
    }
    catch {
        Write-Host "Ocorreu um erro ao atualizar softwares via winget:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }

    Write-Host ""
    Pause
}


function Search-Software {
    Show-Header "Buscar Software"

    try {
        if (-not (Test-WinForgeWingetAvailable)) {
            Pause
            return
        }

        $query = Read-Host "Digite o nome do software"

        if ([string]::IsNullOrWhiteSpace($query)) {
            Write-Host ""
            Write-Host "A busca não pode estar vazia." -ForegroundColor Red
            Pause
            return
        }

        Write-Host ""
        Write-Host "Buscando por: $query" -ForegroundColor Yellow
        Write-Host ""

        winget search $query --accept-source-agreements
    }
    catch {
        Write-Host ""
        Write-Host "Ocorreu um erro ao buscar software:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }

    Write-Host ""
    Pause
}


function Install-Software {
    Show-Header "Instalar Software"

    try {
        if (-not (Test-WinForgeWingetAvailable)) {
            Pause
            return
        }

        Write-Host "Dica: use o ID do pacote exibido nos resultados de busca." -ForegroundColor Yellow
        Write-Host "Exemplo: Google.Chrome, 7zip.7zip, Microsoft.VisualStudioCode"
        Write-Host ""

        $packageId = Read-Host "Digite o ID do pacote"

        if ([string]::IsNullOrWhiteSpace($packageId)) {
            Write-Host ""
            Write-Host "O ID do pacote não pode estar vazio." -ForegroundColor Red
            Pause
            return
        }

        $packageId = $packageId.Trim()

        Write-Host ""
        Write-Host "Pacote selecionado: $packageId" -ForegroundColor Cyan

        $confirmed = Confirm-Action "Deseja instalar este software?"

        if ($confirmed -eq $false) {
            Write-Host ""
            Write-Host "Instalação cancelada." -ForegroundColor Yellow
            Pause
            return
        }

        Write-Host ""
        $arguments = @(
            "install",
            "--id", $packageId,
            "-e",
            "--accept-source-agreements",
            "--accept-package-agreements",
            "--disable-interactivity"
        )

        Write-Host "Instalando: $packageId" -ForegroundColor Green
        Write-Host "Comando: winget install --id $packageId -e --accept-source-agreements --accept-package-agreements --disable-interactivity" -ForegroundColor DarkCyan
        Write-Host ""

        & winget @arguments
        $exitCode = $LASTEXITCODE

        Write-Host ""

        if ($exitCode -eq 0) {
            Write-Host "Processo de instalação finalizado com sucesso." -ForegroundColor Green
        }
        else {
            Write-Host "winget install finalizou com código de saída: $exitCode" -ForegroundColor Yellow
            Write-Host "Revise a saída acima para entender o resultado." -ForegroundColor Yellow
        }

        Write-Host "Alguns instaladores podem exigir interação manual ou reinicialização." -ForegroundColor Yellow
    }
    catch {
        Write-Host ""
        Write-Host "Ocorreu um erro ao instalar software:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }

    Write-Host ""
    Pause
}


function Uninstall-Software {
    Show-Header "Desinstalar Software"

    try {
        if (-not (Test-WinForgeWingetAvailable)) {
            Pause
            return
        }

        Write-Host "Softwares encontrados:" -ForegroundColor Cyan
        Write-Host ""

        $packages = Get-WinForgeInstalledSoftwareList
        Show-WinForgeSoftwareTable -Packages $packages

        if ($packages.Count -eq 0) {
            Write-Host ""
            Pause
            return
        }

        Write-Host ""
        $query = Read-Host "Digite o Nome ou Id do software que deseja desinstalar"

        if ([string]::IsNullOrWhiteSpace($query)) {
            Write-Host ""
            Write-Host "Nenhum software informado. Desinstalação cancelada." -ForegroundColor Yellow
            Pause
            return
        }

        $selectedPackage = Resolve-WinForgeInstalledPackage -Packages $packages -Query $query

        if ($null -eq $selectedPackage) {
            Write-Host ""
            Write-Host "Software não encontrado. Verifique o Nome ou Id e tente novamente." -ForegroundColor Red
            Pause
            return
        }

        $displayName = $selectedPackage.Nome
        $packageId = $selectedPackage.Id

        Write-Host ""
        Write-Host "Software selecionado:" -ForegroundColor Cyan
        $selectedPackage | Select-Object Nome, Id, @{ Name = "Versão"; Expression = { $_.Versao } } | Format-List | Out-Host

        $confirmed = Confirm-Action "Deseja realmente desinstalar '$displayName'?"

        if ($confirmed -eq $false) {
            Write-Host ""
            Write-Host "Desinstalação cancelada." -ForegroundColor Yellow
            Pause
            return
        }

        Write-Host ""

        if (-not [string]::IsNullOrWhiteSpace($packageId) -and $packageId -ne "Não disponível") {
            $arguments = @("uninstall", "--id", $packageId, "-e", "--disable-interactivity")
            Write-Host "Desinstalando: $displayName" -ForegroundColor Green
            Write-Host "Comando: winget uninstall --id $packageId -e --disable-interactivity" -ForegroundColor DarkCyan
            Write-Host ""
            & winget @arguments
        }
        else {
            $arguments = @("uninstall", "--name", $displayName, "--disable-interactivity")
            Write-Host "Desinstalando: $displayName" -ForegroundColor Green
            Write-Host "Comando: winget uninstall --name '$displayName' --disable-interactivity" -ForegroundColor DarkCyan
            Write-Host ""
            & winget @arguments
        }

        $exitCode = $LASTEXITCODE

        Write-Host ""

        if ($exitCode -eq 0) {
            Write-Host "Processo de desinstalação finalizado." -ForegroundColor Green
        }
        else {
            Write-Host "winget uninstall finalizou com código de saída: $exitCode" -ForegroundColor Yellow
            Write-Host "Revise a saída acima para entender o resultado." -ForegroundColor Yellow
        }

        Write-Host "Alguns aplicativos podem exigir interação manual ou reinicialização." -ForegroundColor Yellow
    }
    catch {
        Write-Host ""
        Write-Host "Ocorreu um erro ao desinstalar software:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }

    Write-Host ""
    Pause
}


function Get-EssentialSoftwareCatalog {
    return @(
        [PSCustomObject]@{ Categoria = "Básico"; Nome = "7-Zip"; Id = "7zip.7zip" },
        [PSCustomObject]@{ Categoria = "Básico"; Nome = "Google Chrome"; Id = "Google.Chrome" },
        [PSCustomObject]@{ Categoria = "Básico"; Nome = "Mozilla Firefox"; Id = "Mozilla.Firefox" },
        [PSCustomObject]@{ Categoria = "Básico"; Nome = "Notepad++"; Id = "Notepad++.Notepad++" },
        [PSCustomObject]@{ Categoria = "Básico"; Nome = "VLC Media Player"; Id = "VideoLAN.VLC" },
        [PSCustomObject]@{ Categoria = "Comunicação e mídia"; Nome = "Discord"; Id = "Discord.Discord" },
        [PSCustomObject]@{ Categoria = "Comunicação e mídia"; Nome = "Spotify"; Id = "Spotify.Spotify" },
        [PSCustomObject]@{ Categoria = "Desenvolvimento"; Nome = "Git"; Id = "Git.Git" },
        [PSCustomObject]@{ Categoria = "Desenvolvimento"; Nome = "Java JDK"; Id = "EclipseAdoptium.Temurin.21.JDK" },
        [PSCustomObject]@{ Categoria = "Desenvolvimento"; Nome = "Node.js LTS"; Id = "OpenJS.NodeJS.LTS" },
        [PSCustomObject]@{ Categoria = "Desenvolvimento"; Nome = "PowerShell 7"; Id = "Microsoft.PowerShell" },
        [PSCustomObject]@{ Categoria = "Desenvolvimento"; Nome = "Python"; Id = "Python.Python.3.12" },
        [PSCustomObject]@{ Categoria = "Desenvolvimento"; Nome = "Visual Studio Code"; Id = "Microsoft.VisualStudioCode" },
        [PSCustomObject]@{ Categoria = "Jogos"; Nome = "Steam"; Id = "Valve.Steam" },
        [PSCustomObject]@{ Categoria = "Produtividade"; Nome = "Everything"; Id = "voidtools.Everything" },
        [PSCustomObject]@{ Categoria = "Produtividade"; Nome = "Microsoft PowerToys"; Id = "Microsoft.PowerToys" }
    )
}


function Get-EssentialSoftwareSelection {
    param (
        [string]$Category
    )

    $catalog = Get-EssentialSoftwareCatalog

    if ([string]::IsNullOrWhiteSpace($Category)) {
        return @($catalog)
    }

    return @($catalog | Where-Object { $_.Categoria -eq $Category })
}


function Show-EssentialSoftwareList {
    param (
        [switch]$SkipHeader,
        [switch]$SkipPause
    )

    if (-not $SkipHeader) {
        Show-Header "Softwares Essenciais"
    }

    Get-EssentialSoftwareCatalog |
        Sort-Object Categoria, Nome |
        Format-Table Categoria, Nome, Id -AutoSize |
        Out-Host

    Write-Host ""
    Write-Host "Observação: o WinForge usa winget para instalar estes softwares." -ForegroundColor Yellow
    Write-Host "Você pode instalar uma categoria específica, o pacote completo ou informar um Id específico." -ForegroundColor Yellow
    Write-Host ""

    if (-not $SkipPause) {
        Pause
    }
}


function Install-EssentialSoftwarePackages {
    param (
        [string]$Category,
        [string]$Title,
        [string]$ConfirmationTarget
    )

    Show-Header $Title

    if (-not (Test-WinForgeWingetAvailable)) {
        Pause
        return
    }

    $packages = Get-EssentialSoftwareSelection -Category $Category

    if ($packages.Count -eq 0) {
        Write-Host "Nenhum software encontrado para esta categoria." -ForegroundColor Yellow
        Write-Host ""
        Pause
        return
    }

    Write-Host "Softwares selecionados:" -ForegroundColor Cyan
    Write-Host ""
    $packages | Sort-Object Categoria, Nome | Format-Table Categoria, Nome, Id -AutoSize | Out-Host

    Write-Host ""
    Write-Host "Alguns instaladores podem exigir interação, fechar aplicativos abertos ou reinicialização." -ForegroundColor Yellow
    Write-Host ""

    if ([string]::IsNullOrWhiteSpace($ConfirmationTarget)) {
        if ([string]::IsNullOrWhiteSpace($Category)) {
            $ConfirmationTarget = "todos os softwares essenciais"
        }
        else {
            $ConfirmationTarget = "os softwares da categoria $Category"
        }
    }

    $confirmed = Confirm-Action "Deseja realmente instalar $ConfirmationTarget?"

    if ($confirmed -eq $false) {
        Write-Host ""
        Write-Host "Instalação cancelada." -ForegroundColor Yellow
        Write-Host ""
        Pause
        return
    }

    $results = @()

    foreach ($package in ($packages | Sort-Object Categoria, Nome)) {
        $packageName = $package.Nome
        $packageId = $package.Id
        $arguments = @(
            "install",
            "--id", $packageId,
            "-e",
            "--accept-source-agreements",
            "--accept-package-agreements",
            "--disable-interactivity"
        )
        $commandText = "winget install --id $packageId -e --accept-source-agreements --accept-package-agreements --disable-interactivity"

        Write-Host ""
        Write-Host "Instalando: $packageName" -ForegroundColor Cyan
        Write-Host "Comando: $commandText" -ForegroundColor DarkCyan
        Write-Host ""

        & winget @arguments
        $exitCode = $LASTEXITCODE

        if ($exitCode -eq 0) {
            Write-Host "Concluído: $packageName" -ForegroundColor Green
            $status = "OK"
        }
        else {
            Write-Host "Falhou ou exigiu atenção manual: $packageName - código $exitCode" -ForegroundColor Yellow
            $status = "Falhou/atenção"
        }

        $results += [PSCustomObject]@{
            Software = $packageName
            Id = $packageId
            Status = $status
        }
    }

    Write-Host ""
    Write-Host "Resumo" -ForegroundColor Cyan
    Write-Host ""
    $results | Format-Table -AutoSize | Out-Host

    Write-Host ""
    Pause
}


function Install-EssentialSoftwareById {
    Show-Header "Instalar Software Específico"

    if (-not (Test-WinForgeWingetAvailable)) {
        Pause
        return
    }

    Write-Host "Digite o Id exato do pacote winget que deseja instalar." -ForegroundColor Yellow
    Write-Host "Exemplo: Mozilla.Firefox" -ForegroundColor Cyan
    Write-Host "Deixe em branco para voltar ao menu sem instalar nada." -ForegroundColor Yellow
    Write-Host ""

    $packageId = Read-Host "Digite o Id do software que deseja instalar"

    if ([string]::IsNullOrWhiteSpace($packageId)) {
        Write-Host ""
        Write-Host "Nenhum Id informado. Voltando ao menu." -ForegroundColor Yellow
        Write-Host ""
        Pause
        return
    }

    $packageId = $packageId.Trim()

    Write-Host ""
    $confirmed = Confirm-Action "Deseja realmente instalar '$packageId'?"

    if ($confirmed -eq $false) {
        Write-Host ""
        Write-Host "Instalação cancelada." -ForegroundColor Yellow
        Write-Host ""
        Pause
        return
    }

    Write-Host ""
    $arguments = @(
        "install",
        "--id", $packageId,
        "-e",
        "--accept-source-agreements",
        "--accept-package-agreements",
        "--disable-interactivity"
    )

    Write-Host "Instalando: $packageId" -ForegroundColor Cyan
    Write-Host "Comando: winget install --id $packageId -e --accept-source-agreements --accept-package-agreements --disable-interactivity" -ForegroundColor DarkCyan
    Write-Host ""

    & winget @arguments

    $exitCode = $LASTEXITCODE

    Write-Host ""

    if ($exitCode -eq 0) {
        Write-Host "Instalação finalizada com sucesso." -ForegroundColor Green
    }
    else {
        Write-Host "winget install finalizou com código de saída: $exitCode" -ForegroundColor Yellow
        Write-Host "Revise a saída acima para entender o resultado." -ForegroundColor Yellow
    }

    Write-Host ""
    Pause
}


function Show-EssentialSoftwareMenu {
    do {
        Show-Header "Softwares Essenciais"
        Show-EssentialSoftwareList -SkipHeader -SkipPause

        Write-Host "[1] Instalar pacote completo"
        Write-Host "[2] Instalar softwares básicos"
        Write-Host "[3] Instalar comunicação e mídia"
        Write-Host "[4] Instalar desenvolvimento"
        Write-Host "[5] Instalar jogos"
        Write-Host "[6] Instalar produtividade"
        Write-Host "[7] Instalar software específico"
        Write-Host "[0] Voltar"
        Write-Host ""

        $choice = Read-Host "Escolha uma opção"

        switch ($choice) {
            "1" { Install-EssentialSoftwarePackages -Category "" -Title "Instalar Pacote Completo" -ConfirmationTarget "todos os softwares essenciais" }
            "2" { Install-EssentialSoftwarePackages -Category "Básico" -Title "Instalar Softwares Básicos" -ConfirmationTarget "os softwares da categoria Básico" }
            "3" { Install-EssentialSoftwarePackages -Category "Comunicação e mídia" -Title "Instalar Comunicação e Mídia" -ConfirmationTarget "os softwares da categoria Comunicação e mídia" }
            "4" { Install-EssentialSoftwarePackages -Category "Desenvolvimento" -Title "Instalar Desenvolvimento" -ConfirmationTarget "os softwares da categoria Desenvolvimento" }
            "5" { Install-EssentialSoftwarePackages -Category "Jogos" -Title "Instalar Jogos" -ConfirmationTarget "os softwares da categoria Jogos" }
            "6" { Install-EssentialSoftwarePackages -Category "Produtividade" -Title "Instalar Produtividade" -ConfirmationTarget "os softwares da categoria Produtividade" }
            "7" { Install-EssentialSoftwareById }
            "0" { return }
            default {
                Write-Host "`nOpção inválida." -ForegroundColor Red
                Pause
            }
        }
    } while ($choice -ne "0")
}


Export-ModuleMember -Function *
