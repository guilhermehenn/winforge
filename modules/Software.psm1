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


function Get-WinForgeInteractiveUserName {
    try {
        $interactiveUser = (Get-CimInstance Win32_ComputerSystem -ErrorAction Stop).UserName

        if (-not [string]::IsNullOrWhiteSpace($interactiveUser)) {
            return $interactiveUser.Trim()
        }
    }
    catch {
        # A identificação do usuário interativo é auxiliar e não deve bloquear o winget.
    }

    return ""
}


function Test-WinForgeWingetUserContextMismatch {
    $interactiveUser = Get-WinForgeInteractiveUserName

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


function Get-InstalledSoftware {
    Show-Header "Softwares Instalados (winget)"

    try {
        if (-not (Test-WinForgeWingetAvailable)) {
            Pause
            return
        }

        if (Test-WinForgeWingetUserContextMismatch) {
            $interactiveUser = Get-WinForgeInteractiveUserName
            $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent().Name

            Write-WinForgeWarn "O WinForge está elevado como $currentUser."
            Write-WinForgeStatus -Type Info -Message "Pacotes exclusivos de $interactiveUser podem não aparecer neste contexto."
            Write-Host ""
        }

        # Exibe a saída nativa. Isso evita falhas de parser causadas por versões, idiomas
        # ou políticas corporativas que alteram o formato da tabela do winget.
        & winget list --accept-source-agreements
        $exitCode = $LASTEXITCODE

        Write-Host ""

        if ($exitCode -ne 0) {
            Write-WinForgeWarn "winget list finalizou com código de saída: $exitCode."
        }

        Write-WinForgeStatus -Type Info -Message "Para remover pacotes, use 'Desinstalar software (winget)'."
    }
    catch {
        Write-WinForgeStatus -Type Error -Message "Ocorreu um erro ao listar softwares instalados."
        Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
    }

    Write-Host ""
    Pause
}


function Test-WinForgeWingetNoUpgradeOutput {
    param (
        [string]$OutputText
    )

    return (
        $OutputText -match "No installed package found matching input criteria" -or
        $OutputText -match "No available upgrade found" -or
        $OutputText -match "Nenhuma atualização" -or
        $OutputText -match "Nenhuma atualizacao"
    )
}


function ConvertTo-WinForgeWingetPackageIdList {
    param (
        [string]$InputText
    )

    if ([string]::IsNullOrWhiteSpace($InputText)) {
        return @()
    }

    $segments = @($InputText -split ",")
    $packageIds = @()

    foreach ($segment in $segments) {
        $packageId = $segment.Trim()

        if ([string]::IsNullOrWhiteSpace($packageId)) {
            throw "Há uma vírgula sem um ID antes ou depois dela. Revise a lista informada."
        }

        if ($packageId.ToUpperInvariant() -in @("S", "N", "ID")) {
            throw "A lista contém '$packageId', que é uma opção do menu e não um ID de pacote."
        }

        # Evita executar duas vezes o mesmo pacote sem alterar a grafia do primeiro ID informado.
        if ($packageIds -notcontains $packageId) {
            $packageIds += $packageId
        }
    }

    return @($packageIds)
}


function Resolve-WinForgeWingetUpgradePackageIds {
    param (
        [string[]]$PackageIds,
        [array]$AvailablePackages
    )

    $resolvedIds = @()

    foreach ($packageId in @($PackageIds)) {
        $resolvedId = $packageId

        if (@($AvailablePackages).Count -gt 0) {
            $matchingPackage = @($AvailablePackages) |
                Where-Object { $_.Id -ieq $packageId } |
                Select-Object -First 1

            if ($null -ne $matchingPackage) {
                # Usa a grafia retornada pelo winget quando o pacote é localizado na tabela.
                $resolvedId = $matchingPackage.Id
            }
            else {
                Write-WinForgeWarn "O ID '$packageId' não foi reconhecido na tabela. O winget fará a validação."
            }
        }

        if ($resolvedIds -notcontains $resolvedId) {
            $resolvedIds += $resolvedId
        }
    }

    return @($resolvedIds)
}


function Show-WinForgeWingetPackageSelection {
    param (
        [string[]]$PackageIds
    )

    $packageList = @($PackageIds)

    Write-WinForgeSection -Title "Pacotes selecionados"

    for ($index = 0; $index -lt $packageList.Count; $index++) {
        Write-Host "  " -NoNewline
        Write-Host ("[{0}]" -f ($index + 1)) -ForegroundColor Cyan -NoNewline
        Write-Host " $($packageList[$index])" -ForegroundColor Gray
    }

    Write-Host ""
    Write-WinForgeStatus -Type "Info" -Message ("{0} pacotes serão atualizados em sequência." -f $packageList.Count)
}


function Invoke-WinForgeWingetPackageUpgrades {
    param (
        [string[]]$PackageIds,
        [switch]$ThrowOnFailure
    )

    $packageList = @($PackageIds)
    $results = @()

    if ($packageList.Count -gt 1) {
        Show-WinForgeWingetPackageSelection -PackageIds $packageList
    }

    for ($index = 0; $index -lt $packageList.Count; $index++) {
        $packageId = $packageList[$index]
        $arguments = @(
            "upgrade",
            "--id", $packageId,
            "-e",
            "--accept-source-agreements",
            "--accept-package-agreements",
            "--disable-interactivity"
        )

        if ($packageList.Count -gt 1) {
            Write-WinForgeSection -Title ("Pacote {0} de {1}" -f ($index + 1), $packageList.Count)
        }
        else {
            Write-Host ""
        }

        Write-WinForgeStatus -Type "Running" -Message "Atualizando $packageId..."
        Write-WinForgeCommand -Command "winget upgrade --id $packageId -e --accept-source-agreements --accept-package-agreements --disable-interactivity"
        Write-Host ""

        & winget @arguments
        $exitCode = $LASTEXITCODE

        Write-Host ""

        if ($exitCode -eq 0) {
            Write-WinForgeOk "$packageId atualizado com sucesso."
            $status = "OK"
        }
        else {
            Write-WinForgeWarn "$packageId não foi atualizado. Código de saída: $exitCode."
            $status = "Falhou"
        }

        $results += [PSCustomObject]@{
            Id          = $packageId
            Status      = $status
            CodigoSaida = $exitCode
        }
    }

    $failures = @($results | Where-Object { $_.Status -ne "OK" })

    if ($packageList.Count -gt 1) {
        Write-WinForgeSection -Title "Resumo"
        $results |
            Select-Object `
                @{ Name = "ID"; Expression = { $_.Id } },
                @{ Name = "Status"; Expression = { $_.Status } } |
            Format-Table -AutoSize |
            Out-Host
    }

    if ($failures.Count -gt 0) {
        $failedIds = ($failures | ForEach-Object { $_.Id }) -join ", "

        if ($packageList.Count -eq 1) {
            $failureMessage = "O pacote $failedIds não foi atualizado."
        }
        else {
            $failureMessage = "{0} de {1} pacotes não foram atualizados: {2}." -f $failures.Count, $packageList.Count, $failedIds
        }

        if ($ThrowOnFailure) {
            throw $failureMessage
        }

        Write-WinForgeWarn $failureMessage
        return $false
    }

    Write-Host ""
    Write-WinForgeOk "Atualização via winget finalizada com sucesso."
    Write-WinForgeWarn "Alguns aplicativos podem exigir reinicialização ou uma etapa manual posterior."
    return $true
}


function Invoke-WinForgeWingetUpgradeSelection {
    param (
        [switch]$NoHeader,
        [switch]$NoPause,
        [switch]$ThrowOnFailure
    )

    if (-not $NoHeader) {
        Show-Header "Atualizar Softwares (winget)"
    }

    try {
        if (-not (Test-WinForgeWingetAvailable)) {
            if ($ThrowOnFailure) {
                throw "winget não foi encontrado neste sistema."
            }

            return $false
        }

        Write-Host "Esta opção atualiza apenas softwares gerenciados pelo winget." -ForegroundColor Yellow
        Write-Host "Drivers, BIOS, Windows Update e Microsoft Store não entram nesta rotina." -ForegroundColor Cyan
        Write-Host ""

        Write-WinForgeStatus -Type "Running" -Message "Atualizando a fonte principal do winget..."
        winget source update --name winget --disable-interactivity
        $sourceExitCode = $LASTEXITCODE

        if ($sourceExitCode -eq 0) {
            Write-WinForgeOk "Fonte principal do winget atualizada."
        }
        else {
            Write-WinForgeWarn "Não foi possível atualizar a fonte. A verificação continuará com os dados disponíveis."
        }

        Write-Host ""
        Write-WinForgeStatus -Type "Running" -Message "Verificando atualizações disponíveis via winget..."
        Write-Host ""

        $upgradeOutput = winget upgrade --accept-source-agreements 2>&1
        $upgradeExitCode = $LASTEXITCODE
        $upgradeOutput | ForEach-Object { Write-Host $_ }
        $outputText = $upgradeOutput -join "`n"

        if (Test-WinForgeWingetNoUpgradeOutput -OutputText $outputText) {
            Write-Host ""
            Write-WinForgeOk "Nenhuma atualização via winget foi encontrada."
            return $true
        }

        if ($upgradeExitCode -ne 0 -and [string]::IsNullOrWhiteSpace($outputText)) {
            throw "winget upgrade finalizou com código $upgradeExitCode sem retornar detalhes."
        }

        Write-WinForgeSection -Title "Como deseja continuar?"
        Write-WinForgeMenuItem -Key "S" -Label "Atualizar todos os pacotes"
        Write-WinForgeMenuItem -Key "N" -Label "Não atualizar"
        Write-WinForgeMenuItem -Key "ID" -Label "Informar um ou mais IDs"
        Write-Host ""
        Write-Host "  Cole um ID ou vários IDs separados por vírgula." -ForegroundColor DarkGray
        Write-Host "  Exemplo: Google.Chrome, Notepad++.Notepad++" -ForegroundColor DarkCyan
        Write-Host ""

        $availablePackages = @(ConvertFrom-WinForgeWingetListText -Lines $upgradeOutput)

        while ($true) {
            $rawSelection = (Read-Host "Digite S, N, ID ou um/mais IDs").Trim()

            if ([string]::IsNullOrWhiteSpace($rawSelection)) {
                Write-WinForgeStatus -Type "Error" -Message "Informe S, N, ID ou pelo menos um ID de pacote."
                continue
            }

            $selection = $rawSelection.ToUpperInvariant()

            if ($selection -eq "N") {
                Write-Host ""
                Write-WinForgeWarn "Atualização via winget não executada."
                return $true
            }

            if ($selection -eq "S") {
                $arguments = @(
                    "upgrade",
                    "--all",
                    "--accept-source-agreements",
                    "--accept-package-agreements",
                    "--disable-interactivity"
                )

                Write-Host ""
                Write-WinForgeStatus -Type "Running" -Message "Atualizando todos os pacotes disponíveis..."
                Write-WinForgeCommand -Command "winget $($arguments -join ' ')"
                Write-Host ""

                & winget @arguments
                $exitCode = $LASTEXITCODE

                Write-Host ""

                if ($exitCode -eq 0) {
                    Write-WinForgeOk "Atualização via winget finalizada com sucesso."
                    Write-WinForgeWarn "Alguns aplicativos podem exigir reinicialização ou uma etapa manual posterior."
                    return $true
                }

                $failureMessage = "winget finalizou com código de saída: $exitCode. Revise a saída acima."

                if ($ThrowOnFailure) {
                    throw $failureMessage
                }

                Write-WinForgeWarn $failureMessage
                return $false
            }

            if ($selection -eq "ID") {
                Write-Host ""
                Write-Host "  Copie os valores da coluna ID exibida acima." -ForegroundColor Cyan
                Write-Host "  Para vários pacotes, separe os IDs por vírgula." -ForegroundColor DarkGray
                Write-Host "  Exemplo: Google.Chrome, Notepad++.Notepad++" -ForegroundColor DarkCyan
                Write-Host ""
                $packageInput = (Read-Host "Digite um ou mais IDs").Trim()
            }
            else {
                # Permite colar um ID ou uma lista diretamente no primeiro prompt.
                $packageInput = $rawSelection
            }

            try {
                $packageIds = @(ConvertTo-WinForgeWingetPackageIdList -InputText $packageInput)
            }
            catch {
                Write-WinForgeStatus -Type "Error" -Message $_.Exception.Message
                continue
            }

            if ($packageIds.Count -eq 0) {
                Write-WinForgeStatus -Type "Error" -Message "Informe pelo menos um ID de pacote."
                continue
            }

            $packageIds = @(Resolve-WinForgeWingetUpgradePackageIds -PackageIds $packageIds -AvailablePackages $availablePackages)
            return (Invoke-WinForgeWingetPackageUpgrades -PackageIds $packageIds -ThrowOnFailure:$ThrowOnFailure)
        }
    }
    catch {
        if ($ThrowOnFailure) {
            throw
        }

        Write-Host ""
        Write-WinForgeStatus -Type "Error" -Message "Ocorreu um erro ao atualizar softwares via winget."
        Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
    finally {
        if (-not $NoPause) {
            Write-Host ""
            Pause
        }
    }
}

function Update-AllSoftware {
    Invoke-WinForgeWingetUpgradeSelection | Out-Null
}


function Search-Software {
    Show-Header "Buscar Software (winget)"

    try {
        if (-not (Test-WinForgeWingetAvailable)) {
            Pause
            return
        }

        $query = Read-Host "Digite o nome do software"

        if ([string]::IsNullOrWhiteSpace($query)) {
            Write-Host ""
            Write-WinForgeStatus -Type Error -Message "A busca não pode estar vazia."
            Write-Host ""
            Pause
            return
        }

        Write-Host ""
        Write-WinForgeStatus -Type Running -Message "Buscando por: $query"
        Write-Host ""

        & winget search $query --accept-source-agreements
        $exitCode = $LASTEXITCODE

        if ($exitCode -ne 0) {
            Write-Host ""
            Write-WinForgeStatus -Type Warning -Message "winget search finalizou com código $exitCode."
        }
    }
    catch {
        Write-Host ""
        Write-WinForgeStatus -Type Error -Message "Ocorreu um erro ao buscar o software."
        Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
    }

    Write-Host ""
    Pause
}


function Install-Software {
    Show-Header "Instalar Software (winget)"

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
        Write-WinForgeCommand -Command "winget install --id $packageId -e --accept-source-agreements --accept-package-agreements --disable-interactivity"
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
    Show-Header "Desinstalar Software (winget)"

    try {
        if (-not (Test-WinForgeWingetAvailable)) {
            Pause
            return
        }

        if (Test-WinForgeWingetUserContextMismatch) {
            $interactiveUser = Get-WinForgeInteractiveUserName
            $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent().Name

            Write-WinForgeWarn "O WinForge está elevado como $currentUser."
            Write-WinForgeStatus -Type Info -Message "Pacotes exclusivos de $interactiveUser podem não aparecer neste contexto."
            Write-Host ""
        }

        # A saída nativa evita depender do idioma ou do formato da tabela do winget.
        & winget list --accept-source-agreements
        $listExitCode = $LASTEXITCODE

        if ($listExitCode -ne 0) {
            Write-Host ""
            Write-WinForgeStatus -Type Warning -Message "winget list finalizou com código $listExitCode."
            Write-Host ""
            Pause
            return
        }

        Write-Host ""
        Write-Host "Copie o ID exato do pacote que deseja remover." -ForegroundColor Cyan
        $packageId = (Read-Host "Digite o ID do pacote").Trim()

        if ([string]::IsNullOrWhiteSpace($packageId)) {
            Write-Host ""
            Write-WinForgeStatus -Type Warning -Message "Desinstalação cancelada."
            Write-Host ""
            Pause
            return
        }

        Write-Host ""
        Write-WinForgeKeyValue -Label "Pacote" -Value $packageId

        if (-not (Confirm-Action "Deseja desinstalar este pacote?")) {
            Write-Host ""
            Write-WinForgeStatus -Type Warning -Message "Desinstalação cancelada."
            Write-Host ""
            Pause
            return
        }

        $arguments = @("uninstall", "--id", $packageId, "-e", "--disable-interactivity")

        Write-Host ""
        Write-WinForgeStatus -Type Running -Message "Desinstalando $packageId..."
        Write-WinForgeCommand -Command "winget $($arguments -join ' ')"
        Write-Host ""

        & winget @arguments
        $exitCode = $LASTEXITCODE
        Write-Host ""

        if ($exitCode -eq 0) {
            Write-WinForgeStatus -Type Success -Message "Desinstalação finalizada."
        }
        else {
            Write-WinForgeStatus -Type Warning -Message "winget uninstall finalizou com código $exitCode."
            Write-Host "  Revise a saída acima para entender o resultado." -ForegroundColor DarkGray
        }

        Write-WinForgeWarn "Alguns aplicativos podem exigir uma etapa manual ou reinicialização."
    }
    catch {
        Write-Host ""
        Write-WinForgeStatus -Type Error -Message "Ocorreu um erro ao desinstalar o software."
        Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
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
        Show-Header "Softwares Essenciais (winget)"
    }

    Get-EssentialSoftwareCatalog |
        Sort-Object Categoria, Nome |
        Select-Object Categoria, Nome, @{ Name = "ID"; Expression = { $_.Id } } |
        Format-Table -AutoSize |
        Out-Host

    Write-Host ""
    Write-Host "Observação: o WinForge usa winget para instalar estes softwares." -ForegroundColor Yellow
    Write-Host "Você pode instalar uma categoria específica, o pacote completo ou informar um ID específico." -ForegroundColor Yellow
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
    $packages |
        Sort-Object Categoria, Nome |
        Select-Object Categoria, Nome, @{ Name = "ID"; Expression = { $_.Id } } |
        Format-Table -AutoSize |
        Out-Host

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
    $results |
        Select-Object Software, @{ Name = "ID"; Expression = { $_.Id } }, Status |
        Format-Table -AutoSize |
        Out-Host

    Write-Host ""
    Pause
}


function Install-EssentialSoftwareById {
    Show-Header "Instalar Software Específico"

    if (-not (Test-WinForgeWingetAvailable)) {
        Pause
        return
    }

    Write-Host "Digite o ID exato do pacote winget que deseja instalar." -ForegroundColor Yellow
    Write-Host "Exemplo: Mozilla.Firefox" -ForegroundColor Cyan
    Write-Host "Deixe em branco para voltar ao menu sem instalar nada." -ForegroundColor Yellow
    Write-Host ""

    $packageId = Read-Host "Digite o ID do software que deseja instalar"

    if ([string]::IsNullOrWhiteSpace($packageId)) {
        Write-Host ""
        Write-Host "Nenhum ID informado. Voltando ao menu." -ForegroundColor Yellow
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
        Show-Header "Softwares Essenciais (winget)"
        Show-EssentialSoftwareList -SkipHeader -SkipPause

        Write-WinForgeMenuItem -Key "1" -Label "Instalar pacote completo" -Accent
        Write-WinForgeMenuItem -Key "2" -Label "Instalar softwares básicos"
        Write-WinForgeMenuItem -Key "3" -Label "Instalar comunicação e mídia"
        Write-WinForgeMenuItem -Key "4" -Label "Instalar desenvolvimento"
        Write-WinForgeMenuItem -Key "5" -Label "Instalar jogos"
        Write-WinForgeMenuItem -Key "6" -Label "Instalar produtividade"
        Write-WinForgeMenuItem -Key "7" -Label "Instalar software específico"
        Write-WinForgeMenuItem -Key "0" -Label "Voltar" -Exit
        Write-Host ""

        $choice = Read-Host "Selecione uma opção"

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
