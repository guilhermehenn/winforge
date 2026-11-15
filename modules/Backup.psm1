# Backup antes de formatar o PC e restauração depois da reinstalação do Windows.
#
# O backup guarda o que é difícil de lembrar: a lista de programas (para reinstalar pelo winget), os drivers de
# terceiros, os ajustes do WinForge e, se a pessoa quiser, as redes Wi-Fi salvas. Documentos, fotos e outros arquivos
# pessoais NÃO são copiados: o LEIA-ME do backup lista as pastas e os tamanhos para a pessoa copiar à parte.
#
# Nada aqui altera o Windows: o backup só lê e grava dentro da pasta escolhida. A restauração é quem instala.


# ---------------------------------------------------------------------------
# Nomes e pastas
# ---------------------------------------------------------------------------

function Get-WinForgeBackupDefaultRoot {
    # Documentos\WinForge\Backups: fica no mesmo disco do Windows, então o fluxo avisa para copiar para fora dele.
    return (Join-Path (Get-WinForgeTweakExportFolder) "Backups")
}


function Test-WinForgeBackupInCloudFolder {
    # Se a pasta fica dentro do OneDrive (pessoal ou corporativo): o que é gravado ali vai para a nuvem.
    param (
        [AllowEmptyString()][string]$Path
    )

    return (Test-WinForgeOneDrivePath -Path $Path)
}


function New-WinForgeBackupFolderName {
    param (
        [datetime]$At = (Get-Date)
    )

    return "Backup-$([Environment]::MachineName)-$($At.ToString('yyyy-MM-dd-HHmm', [System.Globalization.CultureInfo]::InvariantCulture))"
}


function Get-WinForgeBackupFileNames {
    # Onde cada coisa fica dentro da pasta do backup.
    return [PSCustomObject]@{
        Manifest     = "backup.json"
        Readme       = "LEIA-ME.txt"
        WingetList   = "programas-winget.json"
        ProgramsList = "programas-instalados.csv"
        Drivers      = "drivers"
        Tweaks       = "ajustes-winforge.json"
        Wifi         = "wifi"
    }
}


function Get-WinForgeBackupItems {
    # Os itens que o backup pode incluir. Admin: exige privilégios de Administrador.
    return @(
        @{ Id = "programs"; Label = "Programas instalados"; Description = "A lista para reinstalar pelo winget"; Selected = $true }
        @{ Id = "drivers"; Label = "Drivers de terceiros"; Description = "Vídeo, rede, som...; ocupa de centenas de MB a alguns GB"; Selected = $true }
        @{ Id = "tweaks"; Label = "Ajustes do WinForge"; Description = "Quais ajustes você aplicou, para repetir no Windows novo"; Selected = $true }
        @{ Id = "wifi"; Label = "Redes Wi-Fi salvas, com as senhas"; Description = "As senhas ficam em texto puro nos arquivos: guarde o backup em local seguro"; Selected = $false }
    )
}


# ---------------------------------------------------------------------------
# Leitura do que está instalado
# ---------------------------------------------------------------------------

function ConvertTo-WinForgeInstalledProgram {
    <#
    Uma entrada da chave Uninstall do registro vira Name, Version e Publisher; $null para o que não é um programa de
    verdade (sem nome, componente do sistema, atualização ou parte de outro programa).
    #>
    param (
        $Properties
    )

    $name = [string](Get-WinForgeJsonValue -Object $Properties -Name "DisplayName" -Default "")

    if ([string]::IsNullOrWhiteSpace($name)) { return $null }
    if ([int](Get-WinForgeJsonValue -Object $Properties -Name "SystemComponent" -Default 0) -eq 1) { return $null }
    if (-not [string]::IsNullOrWhiteSpace([string](Get-WinForgeJsonValue -Object $Properties -Name "ParentKeyName" -Default ""))) { return $null }
    if ([string](Get-WinForgeJsonValue -Object $Properties -Name "ReleaseType" -Default "") -match '^(Update|Hotfix|Security Update|Service Pack)') { return $null }
    if ($name -match '^(Update for|Security Update for|Hotfix for) ') { return $null }

    return [PSCustomObject]@{
        Name      = $name.Trim()
        Version   = [string](Get-WinForgeJsonValue -Object $Properties -Name "DisplayVersion" -Default "")
        Publisher = [string](Get-WinForgeJsonValue -Object $Properties -Name "Publisher" -Default "")
    }
}


function Get-WinForgeInstalledProgramList {
    # Os programas que o Windows lista em "Aplicativos instalados", lidos do registro (sem winget). Ordenado por nome, sem repetições.
    $roots = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
    )

    $programs = @()

    foreach ($root in $roots) {
        foreach ($key in @(Get-ChildItem -LiteralPath $root -ErrorAction SilentlyContinue)) {
            $program = ConvertTo-WinForgeInstalledProgram -Properties (Get-ItemProperty -LiteralPath $key.PSPath -ErrorAction SilentlyContinue)

            if ($null -ne $program) {
                $programs += $program
            }
        }
    }

    return @($programs | Sort-Object -Property Name, Version -Unique)
}


function Get-WinForgeWingetExportCount {
    # Quantos pacotes há num arquivo de "winget export". $null quando o arquivo não existe ou não é um JSON do winget.
    param (
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $null
    }

    try {
        $document = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        return $null
    }

    $sources = @(Get-WinForgeJsonValue -Object $document -Name "Sources" -Default @())
    $count = 0

    foreach ($source in $sources) {
        $count += @(Get-WinForgeJsonValue -Object $source -Name "Packages" -Default @()).Count
    }

    if ($sources.Count -eq 0) {
        return $null
    }

    return $count
}


# ---------------------------------------------------------------------------
# Itens do backup
# ---------------------------------------------------------------------------

function Export-WinForgeBackupPrograms {
    param (
        [Parameter(Mandatory)]
        [string]$Folder
    )

    $names = Get-WinForgeBackupFileNames
    $wingetFile = Join-Path $Folder $names.WingetList
    $csvFile = Join-Path $Folder $names.ProgramsList

    $wingetCount = $null
    $wingetNote = ""

    if (Test-WinForgeWinget) {
        Write-Progress -Activity "Backup antes de formatar" -Status "exportando a lista de programas do winget (pode levar um minuto)"

        try {
            $run = Invoke-WinForgeCapture -FilePath "winget" -Arguments @("export", "-o", $wingetFile, "--accept-source-agreements", "--disable-interactivity")
        }
        finally {
            Write-Progress -Activity "Backup antes de formatar" -Completed
        }

        $wingetCount = Get-WinForgeWingetExportCount -Path $wingetFile

        if ($null -eq $wingetCount) {
            $wingetNote = "o winget não gerou a lista ($((Get-WinForgeWingetExitResult -ExitCode $run.ExitCode).Detail))"
        }
    }
    else {
        $wingetNote = "o winget não foi encontrado"
    }

    $installed = @()

    try {
        $installed = @(Get-WinForgeInstalledProgramList)

        if ($installed.Count -gt 0) {
            $installed | Select-Object Name, Version, Publisher | Export-Csv -LiteralPath $csvFile -NoTypeInformation -Delimiter ";" -Encoding UTF8 -ErrorAction Stop
        }
    }
    catch {
        $installed = @()
    }

    $listed = Format-WinForgeCount -Count $installed.Count -One "programa" -Many "programas"

    if ($null -ne $wingetCount) {
        # Quantos voltam sozinhos na restauração, e onde fica o resto: a lista completa é para o que se baixa à mão.
        $back = Format-WinForgeCount -Count $wingetCount -One 'programa vai ser reinstalado sozinho' -Many 'programas vão ser reinstalados sozinhos'
        $rest = $(if ($installed.Count -gt 0) { "; a lista completa ($($installed.Count)) fica em $($names.ProgramsList), para os que você precisa baixar à mão" } else { "" })
        Write-WinForgeStatus -Type Success -Message "$back$rest."

        return (New-WinForgeResult -Kind Ok -Detail "$(Format-WinForgeCount -Count $wingetCount -One 'programa' -Many 'programas') para reinstalar" -Data @{ Count = $wingetCount; Listed = $installed.Count })
    }

    if ($installed.Count -gt 0) {
        Write-WinForgeStatus -Type Warning -Message "Só a lista completa foi salva ($listed): $wingetNote."

        return (New-WinForgeResult -Kind Warning -Detail "só a lista de consulta: $wingetNote" -Data @{ Count = 0; Listed = $installed.Count })
    }

    Write-WinForgeStatus -Type Error -Message "Não foi possível salvar a lista de programas: $wingetNote."

    return (New-WinForgeResult -Kind Failed -Detail $wingetNote)
}


function Export-WinForgeBackupDrivers {
    param (
        [Parameter(Mandatory)]
        [string]$Folder
    )

    $names = Get-WinForgeBackupFileNames
    $target = Join-Path $Folder $names.Drivers
    [void](New-Item -ItemType Directory -Path $target -Force -ErrorAction Stop)

    $firstError = ""

    Write-Progress -Activity "Backup antes de formatar" -Status "copiando os drivers de terceiros (pode levar alguns minutos)"

    try {
        try {
            [void](Export-WindowsDriver -Online -Destination $target -ErrorAction Stop)
        }
        catch {
            # O pnputil faz a mesma cópia: a tentativa fica só nos detalhes técnicos, e o resumo diz o resultado.
            $firstError = (ConvertTo-WinForgeReadableError -Text $_.Exception.Message).TrimEnd('.')
            Write-Host "O Export-WindowsDriver não funcionou ($firstError); tentando o pnputil..." -ForegroundColor DarkGray

            $run = Invoke-WinForgeCapture -FilePath "pnputil" -Arguments @("/export-driver", "*", $target)

            if ($run.ExitCode -ne 0) {
                $firstError = "$firstError; a segunda tentativa do Windows também falhou (código $($run.ExitCode))"
            }
        }
    }
    finally {
        Write-Progress -Activity "Backup antes de formatar" -Completed
    }

    $infs = @(Get-ChildItem -LiteralPath $target -Filter "*.inf" -Recurse -File -ErrorAction SilentlyContinue)

    if ($infs.Count -eq 0) {
        $reason = if ($firstError) { $firstError } else { "o Windows não devolveu nenhum driver" }
        Write-WinForgeStatus -Type Error -Message "Nenhum driver foi copiado: $reason."

        return (New-WinForgeResult -Kind Failed -Detail "nenhum driver copiado")
    }

    $bytes = [int64](Get-WinForgePathStats -Path $target).Size
    $size = Format-WinForgeBytes -Bytes $bytes
    $count = Format-WinForgeCount -Count $infs.Count -One "driver" -Many "drivers"
    Write-WinForgeStatus -Type Success -Message "$(Format-WinForgeCount -Count $infs.Count -One 'driver copiado' -Many 'drivers copiados') ($size)."

    return (New-WinForgeResult -Kind Ok -Detail "$count, $size" -Data @{ Count = $infs.Count; Size = $bytes })
}


function Export-WinForgeBackupTweaks {
    param (
        [Parameter(Mandatory)]
        [string]$Folder
    )

    $names = Get-WinForgeBackupFileNames
    $ids = @(Get-WinForgeAppliedTweakIds)

    if ($ids.Count -eq 0) {
        Write-WinForgeStatus -Type Info -Message "Nenhum ajuste do WinForge está aplicado neste PC; nada a guardar."

        return (New-WinForgeResult -Kind Skipped -Detail "nenhum ajuste aplicado")
    }

    Set-Content -LiteralPath (Join-Path $Folder $names.Tweaks) -Value (New-WinForgeTweakExport -Ids $ids | ConvertTo-Json -Depth 4) -Encoding UTF8 -ErrorAction Stop
    Write-WinForgeStatus -Type Success -Message "$(Format-WinForgeCount -Count $ids.Count -One 'ajuste do WinForge guardado' -Many 'ajustes do WinForge guardados')."

    return (New-WinForgeResult -Kind Ok -Detail (Format-WinForgeCount -Count $ids.Count -One "ajuste" -Many "ajustes") -Data @{ Count = $ids.Count })
}


function Export-WinForgeBackupWifi {
    param (
        [Parameter(Mandatory)]
        [string]$Folder
    )

    $names = Get-WinForgeBackupFileNames
    $target = Join-Path $Folder $names.Wifi
    [void](New-Item -ItemType Directory -Path $target -Force -ErrorAction Stop)

    Write-Progress -Activity "Backup antes de formatar" -Status "exportando as redes Wi-Fi salvas"

    # Sem o argumento folder=, o netsh grava na pasta atual: assim um caminho com espaços não vira problema de aspas.
    Push-Location -LiteralPath $target

    try {
        $run = Invoke-WinForgeCapture -FilePath "netsh" -Arguments @("wlan", "export", "profile", "key=clear")
    }
    finally {
        Pop-Location
        Write-Progress -Activity "Backup antes de formatar" -Completed
    }

    $files = @(Get-ChildItem -LiteralPath $target -Filter "*.xml" -File -ErrorAction SilentlyContinue)

    # Com o Wi-Fi desligado (ou o serviço de rede sem fio parado), o netsh falha e não exporta nada: isso não é "nenhuma
    # rede salva", e o backup não pode terminar como se as redes estivessem guardadas.
    if ($run.ExitCode -ne 0) {
        $reason = @($run.Lines | ForEach-Object { ([string]$_).Trim() } | Where-Object { $_ }) | Select-Object -First 2
        $reasonText = $(if (@($reason).Count -gt 0) { (@($reason) -join " ").TrimEnd('.') } else { "código $($run.ExitCode)" })
        $saved = $(if ($files.Count -gt 0) { "; só $(Format-WinForgeCount -Count $files.Count -One 'rede foi exportada' -Many 'redes foram exportadas')" } else { "" })

        Write-WinForgeStatus -Type Warning -Message "O Windows não exportou as redes Wi-Fi ($reasonText)$saved. Se o PC tem Wi-Fi, ligue-o e faça o backup de novo para guardá-las."

        return (New-WinForgeResult -Kind Warning -Detail "o Windows não exportou as redes Wi-Fi: $reasonText" -Data @{ Count = $files.Count })
    }

    if ($files.Count -eq 0) {
        Write-WinForgeStatus -Type Info -Message "Nenhuma rede Wi-Fi salva foi encontrada (ou este PC não tem Wi-Fi)."

        return (New-WinForgeResult -Kind Skipped -Detail "nenhuma rede Wi-Fi salva")
    }

    Write-WinForgeStatus -Type Success -Message "$(Format-WinForgeCount -Count $files.Count -One 'rede Wi-Fi exportada' -Many 'redes Wi-Fi exportadas')."
    Write-WinForgeStatus -Type Warning -Message "As senhas estão em texto puro na pasta '$($names.Wifi)': não deixe este backup em nuvem pública nem em pendrive sem proteção."

    return (New-WinForgeResult -Kind Ok -Detail (Format-WinForgeCount -Count $files.Count -One "rede" -Many "redes") -Data @{ Count = $files.Count })
}


# ---------------------------------------------------------------------------
# LEIA-ME e manifesto
# ---------------------------------------------------------------------------

function Get-WinForgeBackupUserFolders {
    # As pastas pessoais com tamanho, para o LEIA-ME. Fora AppData e pastas ocultas de configuração.
    param (
        [string]$ProfilePath = $env:USERPROFILE
    )

    return @(
        Get-WinForgeUserFolderSizes -ProfilePath $ProfilePath -Top 60 |
            Where-Object { $_.Name -notmatch '^(AppData|Application Data|Local Settings|Cookies|NetHood|PrintHood|Recent|SendTo|Start Menu|Templates|My Documents)$' -and -not $_.Name.StartsWith(".") -and $_.Size -gt 0 } |
            Sort-Object -Property Name
    )
}


function New-WinForgeBackupReadme {
    param (
        [Parameter(Mandatory)]
        $Manifest,

        [object[]]$UserFolders = @()
    )

    $names = Get-WinForgeBackupFileNames
    $ids = @($Manifest.Items | Where-Object { $_.Ok } | ForEach-Object { $_.Id })
    $lines = New-Object System.Collections.Generic.List[string]

    $lines.Add("BACKUP DO WINFORGE")
    $lines.Add("==================")
    $lines.Add("")
    $lines.Add("Criado em : $(([datetime]$Manifest.CreatedAt).ToString('dd/MM/yyyy HH:mm', [System.Globalization.CultureInfo]::InvariantCulture))")
    $lines.Add("Computador: $($Manifest.Computer)")
    $lines.Add("Windows   : $($Manifest.Windows)")
    $lines.Add("")
    $lines.Add("O QUE HÁ NESTA PASTA")
    $lines.Add("--------------------")

    if ($ids -contains "programs") {
        $lines.Add("- $($names.WingetList): programas que o winget sabe reinstalar.")
        $lines.Add("- $($names.ProgramsList): lista completa dos programas, para consulta. Programas que não estão no winget (jogos,")
        $lines.Add("  programas de empresas, instaladores antigos) precisam ser baixados à mão por esta lista.")
    }

    if ($ids -contains "drivers") { $lines.Add("- $($names.Drivers)\: cópia dos drivers de terceiros (placa de vídeo, rede, som, touchpad...).") }
    if ($ids -contains "tweaks") { $lines.Add("- $($names.Tweaks): os ajustes do WinForge que estavam aplicados.") }
    if ($ids -contains "wifi") { $lines.Add("- $($names.Wifi)\: redes Wi-Fi salvas, COM AS SENHAS em texto puro. Guarde este backup em local seguro.") }

    $lines.Add("- $($names.Manifest): usado pelo WinForge para reconhecer o backup. Não apague.")
    $lines.Add("")
    $lines.Add("COMO RESTAURAR")
    $lines.Add("--------------")
    $lines.Add("1. Instale o Windows, conecte à internet e rode o Windows Update.")
    $lines.Add("2. Copie esta pasta para o PC novo (ou ligue o pendrive ou HD externo).")
    $lines.Add("3. Abra o WinForge como Administrador, vá em Programas > Restaurar a partir de um backup e escolha esta pasta.")
    $lines.Add("4. Marque o que quer restaurar. Ao final, reinicie o PC.")
    $lines.Add("")
    $lines.Add("O QUE NÃO ESTÁ NO BACKUP (copie à parte antes de formatar)")
    $lines.Add("---------------------------------------------------------")
    $lines.Add("Estas são as suas pastas pessoais e o tamanho de cada uma. O WinForge NÃO copiou nenhuma delas:")

    if (@($UserFolders).Count -eq 0) {
        $lines.Add("  (não foi possível listar as pastas)")
    }
    else {
        foreach ($folder in $UserFolders) {
            $lines.Add(("  {0,-28} {1}" -f $folder.Name, (Format-WinForgeBytes -Bytes $folder.Size)))
        }
    }

    $lines.Add("")
    $lines.Add("Lembre-se também de:")
    $lines.Add("- Favoritos e senhas do navegador: entre na conta do navegador (Edge, Chrome ou Firefox) para sincronizar, ou exporte-os.")
    $lines.Add("- Chaves e licenças de programas pagos, e contas de jogos e de lojas.")
    $lines.Add("- Arquivos que estão só em pastas fora do perfil (outros discos, C:\Dados, etc.).")
    $lines.Add("- Se usa BitLocker, a chave de recuperação.")

    return ($lines -join "`r`n")
}


function Get-WinForgePcModel {
    <#
    Fabricante e modelo deste PC ("Dell Inc. Inspiron 15 3520"), para o backup lembrar de que PC ele veio: depois de
    formatar, o nome do computador costuma mudar, e o modelo, não. A Lenovo põe no modelo o tipo de máquina com a
    configuração ("20QDS00K00"): vale a família ("ThinkPad T490") ou, sem ela, o tipo de máquina (os 4 primeiros). Vazio
    sem leitura, com os textos genéricos das placas montadas ("To Be Filled By O.E.M."), que não distinguem um PC de
    outro, e numa máquina virtual, onde todas se chamam igual.
    #>
    try {
        $system = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
    }
    catch {
        return ""
    }

    $maker = ([string](Get-WinForgeJsonValue -Object $system -Name "Manufacturer" -Default "")).Trim()
    $model = ([string](Get-WinForgeJsonValue -Object $system -Name "Model" -Default "")).Trim()
    $family = ([string](Get-WinForgeJsonValue -Object $system -Name "SystemFamily" -Default "")).Trim()

    if (-not (Test-WinForgeVendorText -Text $maker) -or -not (Test-WinForgeVendorText -Text $model)) { return "" }
    if ($model -match '(?i)virtual machine|vmware|virtualbox|kvm|qemu') { return "" }

    if ($maker -match '(?i)lenovo') {
        if (Test-WinForgeVendorText -Text $family) { return "$maker $family" }
        if ($model.Length -gt 4) { return "$maker $($model.Substring(0, 4))" }
    }

    return "$maker $model"
}


function New-WinForgeBackupManifest {
    # Complete: falso enquanto o backup está em andamento (o manifesto é gravado a cada item, para que um backup
    # interrompido continue restaurável com o que já foi salvo). Backups de versões anteriores não têm o campo.
    param (
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Items,

        [object[]]$UserFolders = @(),

        [datetime]$At = (Get-Date),

        [bool]$Complete = $true,

        [string]$Model = ""
    )

    $session = Get-WinForgeSessionInfo

    return [ordered]@{
        Format      = "WinForge.Backup"
        Version     = 1
        Build       = (Get-WinForgeBuild)
        CreatedAt   = $At.ToString("o", [System.Globalization.CultureInfo]::InvariantCulture)
        Computer    = [Environment]::MachineName
        Model       = $Model
        Windows     = "$($session.WindowsLabel) ($($session.WindowsBuild))"
        Complete    = $Complete
        Items       = @($Items)
        UserFolders = @($UserFolders | ForEach-Object { [ordered]@{ Name = $_.Name; Size = [int64]$_.Size } })
    }
}


# ---------------------------------------------------------------------------
# Fazer o backup
# ---------------------------------------------------------------------------

function Get-WinForgeBackupDrives {
    <#
    As unidades onde vale guardar o backup: pendrives, HDs externos e outras partições prontas, menos a do Windows (a que
    vai ser formatada). Root ("E:\"), Label ("Pendrive (E:)", ou o nome que a unidade tem) e FreeBytes. Só unidades com
    letra: unidades de rede e de CD ficam de fora.
    #>
    $system = ([string]$env:SystemDrive).TrimEnd('\').ToUpperInvariant()
    $found = @()

    try {
        $all = @([System.IO.DriveInfo]::GetDrives())
    }
    catch {
        return @()
    }

    foreach ($drive in $all) {
        try {
            $root = [string]$drive.Name
            $type = [string]$drive.DriveType

            if ($root -notmatch '^[A-Za-z]:\\$' -or $type -notin @("Removable", "Fixed") -or -not $drive.IsReady) { continue }

            $letter = $root.Substring(0, 2).ToUpperInvariant()
            if ($letter -eq $system) { continue }

            $name = ([string]$drive.VolumeLabel).Trim()
            if (-not $name) { $name = $(if ($type -eq "Removable") { "Pendrive" } else { "Disco" }) }

            $found += [PSCustomObject]@{ Root = $root; Label = "$name ($letter)"; FreeBytes = [int64]$drive.AvailableFreeSpace }
        }
        catch {
            # Uma unidade que some no meio da leitura (pendrive retirado) só fica fora da lista.
            continue
        }
    }

    return @($found)
}


function Read-WinForgeBackupDestination {
    <#
    Pergunta onde guardar. As unidades fora a do Windows (pendrive, HD externo) vêm primeiro, a primeira em destaque: o
    backup existe para sobreviver à formatação. Documentos vem sem destaque, avisando que fica no disco que vai ser
    formatado. Sem nenhuma unidade, a tela pede para conectar uma e oferece procurar de novo. Devolve Path (a pasta onde o
    backup será criado; vazio se a pessoa desistiu), IsDefault (Documentos, no mesmo disco do Windows) e Missing (a pasta
    informada, quando ela não existe).
    #>
    $defaultRoot = Get-WinForgeBackupDefaultRoot
    $none = [PSCustomObject]@{ Path = ""; IsDefault = $false; Missing = "" }
    $rounds = 5
    $answer = ""
    $drives = @()

    for ($round = 1; $round -le $rounds; $round++) {
        $drives = @(Get-WinForgeBackupDrives | Select-Object -First 9)
        $rescan = ($drives.Count -eq 0 -and $round -lt $rounds)
        $options = @()

        if ($drives.Count -eq 0) {
            $notice = $(if ($round -eq 1) { "Conecte um pendrive ou HD externo agora para guardar o backup direto nele." } else { "Nenhum pendrive ou HD externo foi encontrado. Confira se ele aparece no Explorador de Arquivos." })
            Write-WinForgeStatus -Type Info -Notice -Message $notice
            Write-Host ""
        }

        if ($rescan) {
            $options += @{ Key = "P"; Label = "Procurar de novo"; Description = "Depois de conectar o pendrive ou HD externo"; Accent = $true }
        }

        for ($i = 0; $i -lt $drives.Count; $i++) {
            $options += @{ Key = [string]($i + 1); Label = $drives[$i].Label; Description = "$(Format-WinForgeBytes -Bytes $drives[$i].FreeBytes) livres"; Accent = ($i -eq 0) }
        }

        $options += @{ Key = "D"; Label = "Documentos"; Description = "Fica no disco que vai ser formatado: copie a pasta para fora dele antes de formatar" }
        $options += @{ Key = "O"; Label = "Outra pasta ou unidade"; Description = "Uma pasta de outro disco, da rede ou do OneDrive" }
        $options += @{ Key = "X"; Label = "Cancelar"; Exit = $true }

        if ($drives.Count -gt 0) {
            $defaultKey = "1"
            $prompt = "Destino (número = unidade, D = Documentos, O = outra pasta, X = cancelar; ENTER = $($drives[0].Label))"
        }
        elseif ($rescan) {
            $defaultKey = "P"
            $prompt = "Destino (P = procurar de novo, D = Documentos, O = outra pasta, X = cancelar; ENTER = procurar de novo)"
        }
        else {
            $defaultKey = "X"
            $prompt = "Destino (D = Documentos, O = outra pasta, X = cancelar; ENTER = cancelar)"
        }

        $answer = Read-WinForgeChoice -Message "Onde guardar o backup?" -DefaultKey $defaultKey -ShowMenu -TextPrompt $prompt -Options $options

        if (-not ($rescan -and $answer -ieq "P")) { break }
    }

    if ($answer -match '^[0-9]$' -and [int]$answer -ge 1 -and [int]$answer -le $drives.Count) {
        return [PSCustomObject]@{ Path = $drives[[int]$answer - 1].Root; IsDefault = $false; Missing = "" }
    }

    if ($answer -ieq "D") {
        return [PSCustomObject]@{ Path = $defaultRoot; IsDefault = $true; Missing = "" }
    }

    if ($answer -ine "O") {
        return $none
    }

    $path = (Read-WinForgeText -Message "Pasta ou unidade de destino (ex.: E:\)").Trim().Trim('"')

    if ([string]::IsNullOrWhiteSpace($path)) {
        return $none
    }

    if (-not (Test-Path -LiteralPath $path -PathType Container)) {
        return [PSCustomObject]@{ Path = ""; IsDefault = $false; Missing = $path }
    }

    return [PSCustomObject]@{ Path = $path; IsDefault = $false; Missing = "" }
}


function Write-WinForgeBackupUserFolders {
    # As pastas pessoais que o backup não copia, as maiores primeiro, no resumo: a pessoa vê ali o que precisa levar à parte.
    # Até $Limit pastas; a lista completa fica no LEIA-ME.
    param (
        [AllowEmptyCollection()][object[]]$Folders = @(),
        [int]$Limit = 8
    )

    if (@($Folders).Count -eq 0) {
        return
    }

    Write-WinForgeSection -Title "Copie à parte (não estão no backup)"

    foreach ($folder in @($Folders | Sort-Object -Property Size -Descending | Select-Object -First $Limit)) {
        Write-WinForgeKeyValue -Label $folder.Name -Value (Format-WinForgeBytes -Bytes ([int64]$folder.Size))
    }

    $rest = @($Folders).Count - $Limit

    if ($rest -gt 0) {
        Write-WinForgeStatus -Type Info -Message "E mais $(Format-WinForgeCount -Count $rest -One 'pasta' -Many 'pastas'); a lista completa está no LEIA-ME."
    }

    Write-Host ""
}


function Get-WinForgeBackupProblemText {
    # "problemas em Drivers de terceiros e Redes Wi-Fi": os itens que falharam ou ficaram pela metade, na ordem em que rodaram.
    param (
        [AllowEmptyCollection()][object[]]$Results = @()
    )

    $names = @($Results | Where-Object { $_.Kind -in "Failed", "Warning" } | ForEach-Object { [string]$_.Etapa })

    return "problemas em $(Join-WinForgeList -Items $names)"
}


function Invoke-WinForgeBackupBeforeFormat {
    $title = "Backup antes de formatar"

    Enter-WinForgeAction -Title $title

    $final = New-WinForgeResult -Kind Ok -Title $title

    try {
        if (-not (Test-WinForgeElevation -Reason "O backup dos drivers e das redes Wi-Fi exige privilégios de Administrador.")) {
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Failed -Detail "requer Administrador" -Title $title)
            return
        }

        # O que o backup guarda aparece na lista de marcar; o que importa saber antes é o que fica de fora.
        Write-WinForgeStatus -Type Info -Message "Seus arquivos pessoais não entram no backup: o LEIA-ME lista as pastas para copiar à parte."
        Write-Host ""

        $destination = Read-WinForgeBackupDestination

        if ($destination.Missing) {
            Write-WinForgeStatus -Type Error -Message "A pasta '$($destination.Missing)' não existe. Conecte o pendrive ou HD e tente de novo."
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Failed -Detail "a pasta '$($destination.Missing)' não existe" -Title $title)
            return
        }

        if ([string]::IsNullOrWhiteSpace($destination.Path)) {
            Write-WinForgeStatus -Type Warning -Message "Operação cancelada."
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Skipped -Detail "cancelado pelo usuário" -Title $title)
            return
        }

        $options = @(Get-WinForgeBackupItems | ForEach-Object { @{ Key = $_.Id; Label = $_.Label; Description = $_.Description; Selected = $_.Selected } })
        $picked = Read-WinForgeMultiSelect -Message "O que incluir no backup?" -Options $options

        if ($null -eq $picked -or @($picked).Count -eq 0) {
            Write-WinForgeStatus -Type Warning -Message "Operação cancelada."
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Skipped -Detail "cancelado pelo usuário" -Title $title)
            return
        }

        # Com o backup das pastas do OneDrive ligado, Documentos (o destino padrão) fica no OneDrive, e tudo o que for
        # gravado lá sobe para a nuvem, inclusive as senhas do Wi-Fi em texto puro. Só entram se a pessoa confirmar.
        if (@($picked) -contains "wifi" -and (Test-WinForgeBackupInCloudFolder -Path $destination.Path)) {
            Write-WinForgeStatus -Type Warning -Notice -Message "Esta pasta fica no OneDrive: os arquivos das redes Wi-Fi, com as senhas em texto puro, seriam enviados para a nuvem."

            if (-not (Confirm-WinForgeAction -Message "Incluir as redes Wi-Fi mesmo assim?" -DefaultKey "N")) {
                $picked = @(@($picked) | Where-Object { $_ -ne "wifi" })
                Write-WinForgeStatus -Type Info -Message "As redes Wi-Fi ficaram fora deste backup. Para guardá-las, faça outro backup só com elas, num pendrive ou HD externo."

                if ($picked.Count -eq 0) {
                    Write-WinForgeStatus -Type Warning -Message "Operação cancelada."
                    Exit-WinForgeAction -Result (New-WinForgeResult -Kind Skipped -Detail "cancelado pelo usuário" -Title $title)
                    return
                }
            }
        }

        $root = $destination.Path
        $folder = Join-Path $root (New-WinForgeBackupFolderName)
        $suffix = 1

        while (Test-Path -LiteralPath $folder) {
            $suffix++
            $folder = Join-Path $root "$(New-WinForgeBackupFolderName)-$suffix"
        }

        [void](New-Item -ItemType Directory -Path $folder -Force -ErrorAction Stop)

        # O backup.json é gravado já no começo e de novo a cada item: parar no meio (a soma das pastas pessoais, no fim, leva
        # minutos) não pode deixar uma pasta que a restauração recusa por falta dele. Complete só fica verdadeiro no fim.
        $names = Get-WinForgeBackupFileNames
        $startedAt = Get-Date
        $manifestPath = Join-Path $folder $names.Manifest
        $pcModel = Get-WinForgePcModel
        Set-Content -LiteralPath $manifestPath -Value (New-WinForgeBackupManifest -Items @() -At $startedAt -Complete $false -Model $pcModel | ConvertTo-Json -Depth 5) -Encoding UTF8 -ErrorAction Stop

        $steps = @(
            @(
                @{ Id = "programs"; Label = "Programas instalados"; Command = "Export-WinForgeBackupPrograms" },
                @{ Id = "drivers"; Label = "Drivers de terceiros"; Command = "Export-WinForgeBackupDrivers" },
                @{ Id = "tweaks"; Label = "Ajustes do WinForge"; Command = "Export-WinForgeBackupTweaks" },
                @{ Id = "wifi"; Label = "Redes Wi-Fi"; Command = "Export-WinForgeBackupWifi" }
            ) | Where-Object { @($picked) -contains $_.Id }
        )

        $results = @()
        $manifestItems = @()

        foreach ($step in $steps) {
            Write-WinForgeSection -Title $step.Label

            try {
                $result = & $step.Command -Folder $folder
            }
            catch {
                Write-WinForgeStatus -Type Error -Message "$($step.Label): $($_.Exception.Message)"
                $result = New-WinForgeResult -Kind Failed -Detail $_.Exception.Message
            }

            $result.Etapa = $step.Label
            $results += $result
            $manifestItems += [ordered]@{ Id = $step.Id; Ok = ($result.Kind -in "Ok", "Warning"); Detail = $result.Detail }
            Set-Content -LiteralPath $manifestPath -Value (New-WinForgeBackupManifest -Items $manifestItems -At $startedAt -Complete $false -Model $pcModel | ConvertTo-Json -Depth 5) -Encoding UTF8 -ErrorAction Stop
        }

        $failed = @($results | Where-Object { $_.Kind -eq "Failed" })
        $warned = @($results | Where-Object { $_.Kind -eq "Warning" })
        $done = @($results | Where-Object { $_.Kind -eq "Ok" })

        if ($done.Count -eq 0 -and $warned.Count -eq 0) {
            # Nada foi salvo (tudo falhou, ou o que foi marcado estava vazio): a pasta criada agora, só com o backup.json, não
            # fica para trás, nem aparece na lista da restauração, e a tela não manda copiá-la.
            Remove-Item -LiteralPath $folder -Recurse -Force -ErrorAction SilentlyContinue

            if (-not (Test-WinForgeGuiMode)) {
                Write-WinForgeSection -Title "Resumo"
                Write-WinForgeResultTable -Results $results
            }

            # Algo falhou e nada foi salvo: Não foi concluído. Tudo o que foi marcado estava vazio (nenhum ajuste aplicado,
            # nenhuma rede salva): Nada a fazer.
            $final = $(if ($failed.Count -gt 0) { New-WinForgeResult -Kind Failed -Detail "nenhum item foi salvo" -Title $title } else { New-WinForgeResult -Kind Skipped -Detail "nada a guardar nos itens marcados" -Title $title })
            Exit-WinForgeAction -Result $final
            return
        }

        Write-Progress -Activity "Backup antes de formatar" -Status "somando o tamanho das pastas pessoais para o LEIA-ME (pode levar alguns minutos)"

        try {
            $userFolders = @(Get-WinForgeBackupUserFolders)
        }
        finally {
            Write-Progress -Activity "Backup antes de formatar" -Completed
        }

        $manifest = New-WinForgeBackupManifest -Items $manifestItems -UserFolders $userFolders -At $startedAt -Model $pcModel

        Set-Content -LiteralPath $manifestPath -Value ($manifest | ConvertTo-Json -Depth 5) -Encoding UTF8 -ErrorAction Stop
        Set-Content -LiteralPath (Join-Path $folder $names.Readme) -Value (New-WinForgeBackupReadme -Manifest $manifest -UserFolders $userFolders) -Encoding UTF8 -ErrorAction Stop

        # No console, a tabela junta tudo no fim; na janela, cada item já tem a sua seção no resumo.
        if (-not (Test-WinForgeGuiMode)) {
            Write-WinForgeSection -Title "Resumo"
            Write-WinForgeResultTable -Results $results
            Write-Host ""
        }

        Write-WinForgeSection -Title "Onde está o backup"
        Write-WinForgeKeyValue -Label "Pasta do backup" -Value $folder
        Write-WinForgeKeyValue -Label "Leia primeiro" -Value (Join-Path $folder $names.Readme)
        Write-Host ""
        Write-WinForgeBackupUserFolders -Folders $userFolders

        if ($destination.IsDefault) {
            Write-WinForgeStatus -Type Warning -Message "Copie esta pasta para um pendrive ou HD externo ANTES de formatar, junto com as suas pastas pessoais (a lista está no LEIA-ME)."
        }
        else {
            Write-WinForgeStatus -Type Warning -Message "Antes de formatar, confira que esta pasta não está no disco que será formatado, e copie também as suas pastas pessoais (a lista está no LEIA-ME)."
        }

        Write-WinForgeStatus -Type Info -Message "No Windows novo, use Programas > Restaurar a partir de um backup."

        if ($failed.Count -gt 0 -or $warned.Count -gt 0) {
            $final = New-WinForgeResult -Kind Warning -Detail (Get-WinForgeBackupProblemText -Results $results) -Title $title
        }
        else {
            $final = New-WinForgeResult -Kind Ok -Detail "backup salvo na pasta $(Split-Path -Path $folder -Leaf)" -Title $title

            # Na janela, o título diz que deu certo; a frase, onde está e o que falta fazer antes de formatar.
            $copy = $(if ($destination.IsDefault) { "copie essa pasta e as suas pastas pessoais para um pendrive ou HD externo" } else { "copie também as suas pastas pessoais" })
            [void](Set-WinForgeResultView -Result $final -Headline "Backup salvo" -Note "Está em $folder. Antes de formatar, $copy.")
        }
    }
    catch {
        Write-WinForgeStatus -Type Error -Message "Não foi possível fazer o backup: $($_.Exception.Message)"
        $final = New-WinForgeResult -Kind Failed -Detail $_.Exception.Message -Title $title
    }

    Exit-WinForgeAction -Result $final
}


# ---------------------------------------------------------------------------
# Restaurar
# ---------------------------------------------------------------------------

function Read-WinForgeBackupFolder {
    <#
    Lê e valida uma pasta de backup. Devolve Folder, CreatedAt, Computer, Windows e Available (os itens que existem
    de fato na pasta: programs, drivers, tweaks, wifi). Pasta que não é um backup do WinForge gera um erro com mensagem clara,
    escrita para entrar no meio de uma frase ("Não foi possível restaurar: a pasta não é um backup do WinForge...").
    #>
    param (
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        throw "a pasta não foi encontrada: $Path"
    }

    $names = Get-WinForgeBackupFileNames
    $manifestPath = Join-Path $Path $names.Manifest
    $document = $null

    if (Test-Path -LiteralPath $manifestPath -PathType Leaf) {
        try {
            $document = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        }
        catch {
            throw "o arquivo $($names.Manifest) está corrompido"
        }

        if ([string](Get-WinForgeJsonValue -Object $document -Name "Format") -ne "WinForge.Backup") {
            throw "a pasta não é um backup do WinForge"
        }
    }
    else {
        throw "a pasta não é um backup do WinForge (falta o arquivo $($names.Manifest))"
    }

    $available = @()

    # A lista do winget só serve se for um "winget export" legível e com algum pacote: um arquivo vazio ou cortado (backup
    # interrompido, cópia danificada) faria o winget import falhar inteiro. DamagedPrograms avisa a tela desse caso (uma
    # lista legível sem nenhum pacote só não tem o que reinstalar).
    $wingetFile = Join-Path $Path $names.WingetList
    $wingetCount = Get-WinForgeWingetExportCount -Path $wingetFile
    $damagedPrograms = (Test-Path -LiteralPath $wingetFile -PathType Leaf) -and $null -eq $wingetCount

    if ($null -ne $wingetCount -and $wingetCount -gt 0) { $available += "programs" }

    if (@(Get-ChildItem -LiteralPath (Join-Path $Path $names.Drivers) -Filter "*.inf" -Recurse -File -ErrorAction SilentlyContinue).Count -gt 0) { $available += "drivers" }

    if (Test-Path -LiteralPath (Join-Path $Path $names.Tweaks) -PathType Leaf) { $available += "tweaks" }

    if (@(Get-ChildItem -LiteralPath (Join-Path $Path $names.Wifi) -Filter "*.xml" -File -ErrorAction SilentlyContinue).Count -gt 0) { $available += "wifi" }

    return [PSCustomObject]@{
        Folder          = $Path
        CreatedAt       = [string](Get-WinForgeJsonValue -Object $document -Name "CreatedAt" -Default "")
        Computer        = [string](Get-WinForgeJsonValue -Object $document -Name "Computer" -Default "")
        Model           = [string](Get-WinForgeJsonValue -Object $document -Name "Model" -Default "")
        Windows         = [string](Get-WinForgeJsonValue -Object $document -Name "Windows" -Default "")
        Available       = @($available)
        DamagedPrograms = $damagedPrograms
        Complete        = [bool](Get-WinForgeJsonValue -Object $document -Name "Complete" -Default $true)
    }
}


function Find-WinForgeBackups {
    # Os backups mais recentes na pasta padrão, do mais novo ao mais antigo.
    param (
        [int]$Top = 6
    )

    $root = Get-WinForgeBackupDefaultRoot
    $names = Get-WinForgeBackupFileNames

    if (-not (Test-Path -LiteralPath $root -PathType Container)) {
        return @()
    }

    return @(
        Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue |
            Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName $names.Manifest) -PathType Leaf } |
            Sort-Object -Property LastWriteTime -Descending |
            Select-Object -First $Top
    )
}


function Format-WinForgeBackupDate {
    # A data do backup.json ("2026-10-20T18:30:00-03:00") como a tela mostra, no horário deste PC; vazio quando o campo
    # falta ou não é uma data (um backup.json editado à mão não derruba a tela).
    param (
        [string]$Text
    )

    $parsed = [datetime]::MinValue

    if ([string]::IsNullOrWhiteSpace($Text) -or -not [datetime]::TryParse($Text, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$parsed)) {
        return ""
    }

    return (Format-WinForgeDateTime -When $parsed)
}


function Get-WinForgeBackupChoiceDescription {
    # A linha de apoio de um backup na escolha: "criado em 20/10/2026 18:30 · ANA-PC", lida do backup.json. Sem ele legível,
    # a data da pasta, que muda quando a pasta é copiada.
    param (
        [Parameter(Mandatory)]
        $Folder
    )

    $names = Get-WinForgeBackupFileNames
    $parts = @()

    try {
        $document = Get-Content -LiteralPath (Join-Path $Folder.FullName $names.Manifest) -Raw -Encoding UTF8 -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        $created = Format-WinForgeBackupDate -Text ([string](Get-WinForgeJsonValue -Object $document -Name "CreatedAt" -Default ""))
        $computer = [string](Get-WinForgeJsonValue -Object $document -Name "Computer" -Default "")

        if ($created) { $parts += "criado em $created" }
        if ($computer) { $parts += $computer }
        if ($parts.Count -gt 0 -and -not [bool](Get-WinForgeJsonValue -Object $document -Name "Complete" -Default $true)) { $parts += "interrompido antes do fim" }
    }
    catch {
        $parts = @()
    }

    if ($parts.Count -eq 0) {
        return "pasta de $(Format-WinForgeDateTime -When $Folder.LastWriteTime)"
    }

    return ($parts -join " · ")
}


function Get-WinForgeRestoreOptions {
    # As opções de "O que restaurar?", com o que cada uma faz neste PC e quanto há no backup. Tudo o que está no backup vem
    # marcado: a pessoa já escolheu o que guardar quando fez o backup.
    param (
        [Parameter(Mandatory)]
        $Backup,

        # O backup veio de outro modelo de PC: os drivers dele são para aquele PC e vêm desmarcados.
        [switch]$OtherModel
    )

    $names = Get-WinForgeBackupFileNames
    $folder = $Backup.Folder

    return @(
        foreach ($id in @("programs", "drivers", "tweaks", "wifi")) {
            if (@($Backup.Available) -notcontains $id) { continue }

            switch ($id) {
                "programs" {
                    # Sem o winget (o comum logo depois de formatar, antes de a Microsoft Store se atualizar), a reinstalação
                    # falharia: a opção aparece, mas desmarcada, dizendo o que falta.
                    if (-not (Test-WinForgeWinget)) {
                        @{ Key = $id; Label = "Reinstalar os programas"; Description = "Precisa do Instalador de Aplicativo, que ainda não está neste Windows"; Selected = $false }
                    }
                    else {
                        $count = Get-WinForgeWingetExportCount -Path (Join-Path $folder $names.WingetList)
                        $what = $(if ($null -ne $count) { "Reinstala pelo winget $(Format-WinForgeCount -Count $count -One 'programa' -Many 'programas')" } else { "Reinstala pelo winget os programas da lista" })
                        @{ Key = $id; Label = "Reinstalar os programas"; Description = "$what; os que não estão no winget ficam em $($names.ProgramsList)"; Selected = $true }
                    }
                }
                "drivers" {
                    $count = @(Get-ChildItem -LiteralPath (Join-Path $folder $names.Drivers) -Filter "*.inf" -Recurse -File -ErrorAction SilentlyContinue).Count
                    $origin = $(if ($OtherModel) { " (são de outro modelo de PC)" } else { "" })
                    @{ Key = $id; Label = "Instalar os drivers"; Description = "Adiciona $(Format-WinForgeCount -Count $count -One 'driver' -Many 'drivers') e instala os que servirem neste PC$origin"; Selected = (-not $OtherModel) }
                }
                "tweaks" {
                    @{ Key = $id; Label = "Reaplicar os ajustes do WinForge"; Description = "Os ajustes que estavam aplicados no PC de origem"; Selected = $true }
                }
                "wifi" {
                    $count = @(Get-ChildItem -LiteralPath (Join-Path $folder $names.Wifi) -Filter "*.xml" -File -ErrorAction SilentlyContinue).Count
                    @{ Key = $id; Label = "Restaurar as redes Wi-Fi"; Description = "Recria $(Format-WinForgeCount -Count $count -One 'rede salva' -Many 'redes salvas'), com as senhas"; Selected = $true }
                }
            }
        }
    )
}


function Restore-WinForgeBackupPrograms {
    param (
        [Parameter(Mandatory)]
        [string]$Folder
    )

    $names = Get-WinForgeBackupFileNames
    $file = Join-Path $Folder $names.WingetList

    if (-not (Test-WinForgeWinget)) {
        Write-WinForgeWingetMissing

        return (New-WinForgeResult -Kind Failed -Detail (Get-WinForgeWingetMissingDetail))
    }

    $arguments = @("import", "-i", $file, "--accept-source-agreements", "--accept-package-agreements", "--disable-interactivity", "--ignore-unavailable")

    Write-WinForgeCommand -Command "winget $($arguments -join ' ')"
    Write-Host ""
    Write-Progress -Activity "Reinstalando os programas" -Status "o winget instala um programa por vez; pode levar bastante tempo"

    try {
        $exitCode = Invoke-WinForgeNative -FilePath "winget" -Arguments $arguments -IgnoreExitCode -PassThru
    }
    finally {
        Write-Progress -Activity "Reinstalando os programas" -Completed
    }

    # Os mesmos códigos das outras telas de programas: "já estava instalado" não é problema.
    $exitResult = Get-WinForgeWingetExitResult -ExitCode $exitCode
    # A marca de "já instalado" das telas de instalar é lida de novo (Software.psm1, quando carregado).
    if (Get-Command -Name Clear-WinForgeInstalledWingetIdsCache -ErrorAction SilentlyContinue) { Clear-WinForgeInstalledWingetIdsCache }

    if ($exitResult.Kind -eq "Ok") {
        Write-WinForgeStatus -Type Success -Message "O winget reinstalou os programas da lista."

        return (New-WinForgeResult -Kind Ok)
    }

    Write-WinForgeStatus -Type Warning -Message "O winget terminou com problemas: $($exitResult.Detail)."
    Write-WinForgeStatus -Type Info -Message "Para o que faltar, use Programas > Buscar e instalar programas; a lista completa está em $($names.ProgramsList)."

    return (New-WinForgeResult -Kind Warning -Detail $exitResult.Detail)
}


function Restore-WinForgeBackupDrivers {
    param (
        [Parameter(Mandatory)]
        [string]$Folder
    )

    $names = Get-WinForgeBackupFileNames
    $source = Join-Path $Folder $names.Drivers

    Write-Progress -Activity "Instalando os drivers do backup" -Status "pode levar alguns minutos"

    try {
        $run = Invoke-WinForgeCapture -FilePath "pnputil" -Arguments @("/add-driver", (Join-Path $source "*.inf"), "/subdirs", "/install")
    }
    finally {
        Write-Progress -Activity "Instalando os drivers do backup" -Completed
    }

    # Códigos do pnputil (Microsoft): 3010 = instalado, falta reiniciar; 259 = nenhum dispositivo precisava destes drivers
    # (ou já usa um igual ou mais novo, o comum depois do Windows Update). Nenhum dos dois é falha.
    if ($run.ExitCode -in 0, 3010) {
        Write-WinForgeStatus -Type Success -Message "Drivers instalados."

        if ($run.ExitCode -eq 3010) {
            Write-WinForgeStatus -Type Info -Message "Reinicie o PC para concluir a instalação dos drivers."
        }

        return (New-WinForgeResult -Kind Ok -Data @{ RebootRequired = ($run.ExitCode -eq 3010) })
    }

    if ($run.ExitCode -eq 259) {
        Write-WinForgeStatus -Type Success -Message "Drivers adicionados ao Windows; os dispositivos deste PC já usam drivers iguais ou mais novos."

        return (New-WinForgeResult -Kind Ok -Detail "os dispositivos já usam drivers iguais ou mais novos")
    }

    Write-WinForgeStatus -Type Warning -Message "Alguns drivers podem não ter sido instalados (código $($run.ExitCode))."

    return (New-WinForgeResult -Kind Warning -Detail "alguns drivers não foram instalados")
}


function Get-WinForgeWifiProfileName {
    # O nome da rede guardado no perfil exportado (o <name> do WLANProfile). Sem ele, o nome do arquivo, que o netsh monta
    # como "<adaptador>-<rede>.xml".
    param (
        [Parameter(Mandatory)]
        [string]$Path
    )

    try {
        [xml]$document = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 -ErrorAction Stop

        # O indexador procura o filho pelo nome, com ou sem o namespace do perfil; ".name" devolveria o nome do elemento.
        $node = $document.DocumentElement["name"]
        $name = $(if ($null -ne $node) { [string]$node.InnerText } else { "" })

        if (-not [string]::IsNullOrWhiteSpace($name)) {
            return $name.Trim()
        }
    }
    catch {
        Write-Verbose "Perfil Wi-Fi ilegível: $Path"
    }

    return [IO.Path]::GetFileNameWithoutExtension($Path)
}


function Restore-WinForgeBackupWifi {
    param (
        [Parameter(Mandatory)]
        [string]$Folder
    )

    $names = Get-WinForgeBackupFileNames
    $files = @(Get-ChildItem -LiteralPath (Join-Path $Folder $names.Wifi) -Filter "*.xml" -File -ErrorAction SilentlyContinue)

    # O netsh recebe o nome do arquivo sem caminho (a cópia de trabalho tem nome simples): nomes de rede com espaços
    # e caracteres acentuados não viram problema de aspas. A cópia tem as senhas em texto e é apagada no final.
    $scratch = Join-Path ([IO.Path]::GetTempPath()) "winforge-wifi-$([guid]::NewGuid().ToString('N'))"
    [void](New-Item -ItemType Directory -Path $scratch -Force -ErrorAction Stop)

    $added = 0
    $position = 0
    $firstReason = ""

    try {
        Push-Location -LiteralPath $scratch

        try {
            foreach ($file in $files) {
                $position++
                $network = Get-WinForgeWifiProfileName -Path $file.FullName
                Write-Progress -Activity "Restaurando as redes Wi-Fi" -Status "$position de $($files.Count): $network" -PercentComplete ([int](($position - 1) * 100 / $files.Count))

                $workName = "perfil$position.xml"
                Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $scratch $workName) -Force -ErrorAction Stop

                $run = Invoke-WinForgeCapture -FilePath "netsh" -Arguments @("wlan", "add", "profile", "filename=$workName", "user=all")

                if ($run.ExitCode -eq 0) {
                    $added++
                    Write-WinForgeStatus -Type Success -Message "Rede restaurada: $network"
                }
                else {
                    # O motivo do netsh (serviço de rede sem fio parado, PC sem Wi-Fi) vai junto, como no backup.
                    $why = @($run.Lines | ForEach-Object { ([string]$_).Trim() } | Where-Object { $_ }) | Select-Object -First 1
                    $why = $(if ($why) { ([string]$why).TrimEnd('.') } else { "" })
                    if (-not $firstReason) { $firstReason = $why }

                    Write-WinForgeStatus -Type Error -Message "Não foi possível restaurar a rede: $network$(if ($why) { " ($why)" })"
                }
            }
        }
        finally {
            Pop-Location
            Write-Progress -Activity "Restaurando as redes Wi-Fi" -Completed
        }
    }
    finally {
        Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction SilentlyContinue
    }

    if ($added -eq $files.Count) {
        return (New-WinForgeResult -Kind Ok -Detail (Format-WinForgeCount -Count $added -One "rede" -Many "redes") -Data @{ Count = $added })
    }

    if ($added -eq 0) {
        return (New-WinForgeResult -Kind Failed -Detail "nenhuma rede restaurada$(if ($firstReason) { ": $firstReason" })")
    }

    return (New-WinForgeResult -Kind Warning -Detail "$added de $(Format-WinForgeCount -Count $files.Count -One 'rede' -Many 'redes')" -Data @{ Count = $added })
}


function Restore-WinForgeFromBackup {
    $title = "Restaurar a partir de um backup"

    Enter-WinForgeAction -Title $title

    $final = New-WinForgeResult -Kind Ok -Title $title

    try {
        if (-not (Test-WinForgeElevation -Reason "Instalar programas, drivers e redes Wi-Fi exige privilégios de Administrador.")) {
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Failed -Detail "requer Administrador" -Title $title)
            return
        }

        $backups = @(Find-WinForgeBackups)
        $options = @()
        $position = 0

        foreach ($backup in $backups) {
            $position++
            $options += @{ Key = [string]$position; Label = $backup.Name; Description = (Get-WinForgeBackupChoiceDescription -Folder $backup) }
        }

        $options += @{ Key = "O"; Label = "Outra pasta"; Description = "Informar a pasta do backup (um pendrive, um HD externo...)" }
        $options += @{ Key = "X"; Label = "Cancelar"; Exit = $true }

        # Antes da pergunta: durante uma escolha, a janela mostra o resumo, e os detalhes técnicos ficam recolhidos.
        if ($backups.Count -eq 0) {
            Write-WinForgeStatus -Type Info -Message "Nenhum backup foi encontrado em $(Get-WinForgeBackupDefaultRoot). Se ele está num pendrive ou HD externo, escolha Outra pasta."
            Write-Host ""
        }

        $answer = Read-WinForgeChoice -Message "Qual backup restaurar?" -Options $options -DefaultKey "X" -ShowMenu `
            -TextPrompt "Backup (número, O = outra pasta, X = cancelar; ENTER = cancelar)"

        $path = ""

        if ($answer -ieq "O") {
            $path = (Read-WinForgeText -Message "Pasta do backup (a que tem o arquivo backup.json)").Trim().Trim('"')
        }
        elseif ($answer -match "^[0-9]+$" -and [int]$answer -ge 1 -and [int]$answer -le $backups.Count) {
            $path = $backups[[int]$answer - 1].FullName
        }

        if ([string]::IsNullOrWhiteSpace($path)) {
            Write-WinForgeStatus -Type Warning -Message "Operação cancelada."
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Skipped -Detail "cancelado pelo usuário" -Title $title)
            return
        }

        # Quem cola o caminho do próprio backup.json (ou de outro arquivo da pasta) quer a pasta dele.
        if (Test-Path -LiteralPath $path -PathType Leaf) {
            $path = Split-Path -Path $path -Parent
        }

        $backup = Read-WinForgeBackupFolder -Path $path

        Write-WinForgeKeyValue -Label "Pasta" -Value $backup.Folder
        Write-WinForgeKeyValue -Label "Criado em" -Value $(Format-WinForgeBackupDate -Text $backup.CreatedAt)
        Write-WinForgeKeyValue -Label "Computador de origem" -Value $(if ($backup.Computer) { $backup.Computer } else { $null })
        $backupModel = [string](Get-WinForgeJsonValue -Object $backup -Name "Model" -Default "")
        if ($backupModel) { Write-WinForgeKeyValue -Label "Modelo de origem" -Value $backupModel }
        Write-WinForgeKeyValue -Label "Windows de origem" -Value $(if ($backup.Windows) { $backup.Windows } else { $null })
        Write-Host ""

        # O nome do computador muda ao formatar; o modelo, não. Drivers de outro modelo vêm desmarcados.
        $currentModel = Get-WinForgePcModel
        $otherModel = ($backupModel -and $currentModel -and $backupModel -ne $currentModel -and @($backup.Available) -contains "drivers")

        if ($otherModel) {
            Write-WinForgeStatus -Type Warning -Message "Este backup é de outro modelo de PC ($backupModel; este é $currentModel). Os drivers dele são para aquele PC e vêm desmarcados."
            Write-Host ""
        }

        if (-not [bool](Get-WinForgeJsonValue -Object $backup -Name "Complete" -Default $true)) {
            Write-WinForgeStatus -Type Warning -Message "Este backup foi interrompido antes do fim: só o que chegou a ser salvo aparece na lista."
            Write-Host ""
        }

        if ([bool](Get-WinForgeJsonValue -Object $backup -Name "DamagedPrograms" -Default $false)) {
            $names = Get-WinForgeBackupFileNames
            Write-WinForgeStatus -Type Warning -Message "A lista de programas do winget neste backup está danificada e ficou de fora. A lista completa, para reinstalar à mão, está em $($names.ProgramsList)."
            Write-Host ""
        }

        $restoreOptions = @(Get-WinForgeRestoreOptions -Backup $backup -OtherModel:$otherModel)

        if ($restoreOptions.Count -eq 0) {
            Write-WinForgeStatus -Type Warning -Message "Este backup não tem nada a restaurar."
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Skipped -Detail "o backup não tem nada a restaurar" -Title $title)
            return
        }

        $picked = Read-WinForgeMultiSelect -Message "O que restaurar?" -Options $restoreOptions

        if ($null -eq $picked -or @($picked).Count -eq 0) {
            Write-WinForgeStatus -Type Warning -Message "Operação cancelada."
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Skipped -Detail "cancelado pelo usuário" -Title $title)
            return
        }

        $chosen = @($restoreOptions | Where-Object { @($picked) -contains $_.Key })

        if (@($picked) -contains "programs") {
            # O winget baixa e instala um programa por vez.
            Write-WinForgeStatus -Type Info -Message "Reinstalar os programas pode levar bastante tempo."
            Write-Host ""
        }

        $question = $(if ($chosen.Count -eq 1) { "$($chosen[0].Label) neste PC?" } else { "Restaurar os $($chosen.Count) itens marcados neste PC?" })

        if (-not (Confirm-WinForgeAction -Message $question -DefaultKey "S")) {
            Write-WinForgeStatus -Type Warning -Message "Operação cancelada."
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Skipped -Detail "cancelado pelo usuário" -Title $title)
            return
        }

        $names = Get-WinForgeBackupFileNames
        $results = @()

        foreach ($option in $chosen) {
            $id = $option.Key
            $label = $option.Label
            Write-WinForgeSection -Title $label

            try {
                $result = switch ($id) {
                    "programs" { Restore-WinForgeBackupPrograms -Folder $backup.Folder }
                    "drivers"  { Restore-WinForgeBackupDrivers -Folder $backup.Folder }
                    "tweaks"   { Invoke-WinForgeTweakImportFile -Path (Join-Path $backup.Folder $names.Tweaks) -Title $label }
                    "wifi"     { Restore-WinForgeBackupWifi -Folder $backup.Folder }
                }
            }
            catch {
                Write-WinForgeStatus -Type Error -Message "${label}: $($_.Exception.Message)"
                $result = New-WinForgeResult -Kind Failed -Detail $_.Exception.Message
            }

            $result.Etapa = $label
            $results += $result
        }

        # No console, a tabela junta tudo no fim; na janela, cada item já tem a sua seção no resumo.
        if (-not (Test-WinForgeGuiMode)) {
            Write-WinForgeSection -Title "Resumo"
            Write-WinForgeResultTable -Results $results
        }

        $failed = @($results | Where-Object { $_.Kind -eq "Failed" })
        $warned = @($results | Where-Object { $_.Kind -eq "Warning" })
        $skipped = @($results | Where-Object { $_.Kind -eq "Skipped" })
        $restart = @($results | Where-Object { Test-WinForgeResultFlag -Result $_ -Name "RebootRequired" }).Count -gt 0

        # O que fazer ao terminar só vale quando algo voltou.
        if ($failed.Count + $skipped.Count -lt $results.Count) {
            Write-Host ""
            Write-WinForgeStatus -Type Info -Message "Ao terminar, reinicie o PC e copie de volta as suas pastas pessoais (a lista está no LEIA-ME do backup)."
        }

        if ($failed.Count -eq $results.Count) {
            $final = New-WinForgeResult -Kind Failed -Detail "nada foi restaurado" -Title $title
        }
        elseif ($skipped.Count -eq $results.Count) {
            $final = New-WinForgeResult -Kind Skipped -Detail "nada a restaurar nos itens marcados" -Title $title
        }
        elseif ($failed.Count -gt 0 -or $warned.Count -gt 0) {
            $final = New-WinForgeResult -Kind Warning -Detail (Get-WinForgeBackupProblemText -Results $results) -Title $title -Data @{ RebootRequired = $restart }
        }
        else {
            $done = @($results | Where-Object { $_.Kind -eq "Ok" }).Count
            $final = New-WinForgeResult -Kind Ok -Detail (Format-WinForgeCount -Count $done -One "item restaurado" -Many "itens restaurados") -Title $title -Data @{ RebootRequired = $restart }
            [void](Set-WinForgeResultView -Result $final -Headline (Format-WinForgeCount -Count $done -One "item restaurado" -Many "itens restaurados") `
                    -Note "Reinicie o PC e copie de volta as suas pastas pessoais (a lista está no LEIA-ME do backup).")

            # A lista do winget danificada ficou de fora: o que foi marcado deu certo, mas o backup não voltou inteiro.
            if ([bool](Get-WinForgeJsonValue -Object $backup -Name "DamagedPrograms" -Default $false)) {
                $final = New-WinForgeResult -Kind Warning -Detail "$($final.Detail); a lista de programas do winget do backup está danificada" -Title $title -Data @{ RebootRequired = $restart }
            }
        }
    }
    catch {
        Write-WinForgeStatus -Type Error -Message "Não foi possível restaurar: $($_.Exception.Message.TrimEnd('.'))."
        $final = New-WinForgeResult -Kind Failed -Detail $_.Exception.Message.TrimEnd('.') -Title $title
    }

    Exit-WinForgeAction -Result $final
}


Export-ModuleMember -Function *
