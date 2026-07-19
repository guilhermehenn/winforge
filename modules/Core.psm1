$script:WinForgeBuild = "2.0"

function Set-WinForgeConsoleEncoding {
    # Garante melhor exibição de acentos no Windows PowerShell 5.1 e em consoles legados.
    try {
        $utf8Encoding = New-Object System.Text.UTF8Encoding -ArgumentList $false
        [Console]::InputEncoding = $utf8Encoding
        [Console]::OutputEncoding = $utf8Encoding
        $global:OutputEncoding = $utf8Encoding
        chcp.com 65001 | Out-Null
    }
    catch {
        # Não bloqueia a execução caso o console não permita alteração de encoding.
    }
}


function Get-WinForgeConsoleWidth {
    try {
        $width = [Console]::WindowWidth - 1
    }
    catch {
        $width = 72
    }

    return [Math]::Min(88, [Math]::Max(52, $width))
}


function Show-Header {
    param (
        [string]$Title
    )

    if ($Title -eq "WinForge") {
        $displayTitle = "WinForge  |  Build $script:WinForgeBuild"
    }
    else {
        $displayTitle = $Title
    }

    $line = "-" * (Get-WinForgeConsoleWidth)

    Clear-Host
    Write-Host $line -ForegroundColor DarkCyan
    Write-Host "  $displayTitle" -ForegroundColor Cyan

    if ($Title -eq "WinForge") {
        Write-Host "  Manutenção, diagnóstico e ajustes do Windows" -ForegroundColor DarkGray
    }

    Write-Host $line -ForegroundColor DarkCyan
    Write-Host ""
}


function Write-WinForgeMenuItem {
    param (
        [string]$Key,
        [string]$Label,
        [switch]$Accent,
        [switch]$Exit
    )

    $keyColor = "Cyan"
    $labelColor = "Gray"

    if ($Accent) {
        $keyColor = "Green"
        $labelColor = "White"
    }
    elseif ($Exit) {
        $keyColor = "DarkGray"
        $labelColor = "DarkGray"
    }

    Write-Host "  [" -ForegroundColor DarkGray -NoNewline
    Write-Host $Key -ForegroundColor $keyColor -NoNewline
    Write-Host "] " -ForegroundColor DarkGray -NoNewline
    Write-Host $Label -ForegroundColor $labelColor
}


function Write-WinForgeSection {
    param (
        [string]$Title
    )

    Write-Host ""
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host ("  " + ("-" * [Math]::Min(46, [Math]::Max(12, $Title.Length + 2)))) -ForegroundColor DarkGray
}


function Write-WinForgeKeyValue {
    param (
        [string]$Label,
        [object]$Value,
        [int]$LabelWidth = 24
    )

    $valueText = if ($null -eq $Value) {
        "Não disponível"
    }
    elseif ($Value -is [System.Array]) {
        ($Value | ForEach-Object { $_.ToString() }) -join ", "
    }
    elseif ([string]::IsNullOrWhiteSpace($Value.ToString())) {
        "Não disponível"
    }
    else {
        $Value.ToString()
    }

    Write-Host "  " -NoNewline
    Write-Host ($Label.PadRight($LabelWidth)) -ForegroundColor DarkGray -NoNewline
    Write-Host " : " -ForegroundColor DarkGray -NoNewline
    Write-Host $valueText -ForegroundColor Gray
}


function Write-WinForgeStatus {
    param (
        [ValidateSet("Success", "Warning", "Error", "Info", "Running")]
        [string]$Type,
        [string]$Message
    )

    $badge = switch ($Type) {
        "Success" { "[OK]" }
        "Warning" { "[!]" }
        "Error"   { "[X]" }
        "Running" { "[..]" }
        default   { "[i]" }
    }

    $color = switch ($Type) {
        "Success" { "Green" }
        "Warning" { "Yellow" }
        "Error"   { "Red" }
        "Running" { "Cyan" }
        default   { "Cyan" }
    }

    Write-Host "  $badge " -ForegroundColor $color -NoNewline
    Write-Host $Message -ForegroundColor Gray
}


function Write-WinForgeCommand {
    param (
        [string]$Command
    )

    Write-Host "  > " -ForegroundColor DarkGray -NoNewline
    Write-Host $Command -ForegroundColor DarkCyan
}

function Confirm-Action {
    param (
        [string]$Message = "Deseja continuar?"
    )

    while ($true) {
        $answer = Read-Host "$Message (S/N)"
        $answer = $answer.Trim().ToUpper()

        switch ($answer) {
            "S" { return $true }
            "N" { return $false }
            default {
                Write-Host "Opção inválida. Digite S ou N." -ForegroundColor Red
            }
        }
    }
}


function Test-IsAdministrator {
    $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)

    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}


function Restart-AsAdministratorIfNeeded {
    param (
        [string]$ScriptPath
    )

    if (Test-IsAdministrator) {
        return
    }

    Show-Header "WinForge"

    Write-Host "O WinForge precisa ser executado como Administrador para operações do sistema." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "A aplicação será reiniciada como Administrador." -ForegroundColor Cyan
    Write-Host ""

    Start-Sleep -Seconds 2

    if ([string]::IsNullOrWhiteSpace($ScriptPath)) {
        $ScriptPath = $PSCommandPath
    }

    if ([string]::IsNullOrWhiteSpace($ScriptPath) -or -not (Test-Path $ScriptPath)) {
        Write-Host "Não foi possível identificar o caminho do script principal." -ForegroundColor Red
        Write-Host "Execute o WinForge a partir de um arquivo .ps1 salvo." -ForegroundColor Yellow
        Write-Host ""
        Pause
        exit
    }

    $pwshCommand = Get-Command pwsh -ErrorAction SilentlyContinue

    if ($pwshCommand) {
        $hostExecutable = $pwshCommand.Source
    }
    else {
        $hostExecutable = "powershell.exe"
    }

    Start-Process $hostExecutable -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`"" -Verb RunAs
    exit
}


function Get-FolderSizeInBytes {
    param (
        [string]$Path
    )

    try {
        $size = (
            Get-ChildItem -Path $Path -Recurse -Force -ErrorAction SilentlyContinue |
            Where-Object { -not $_.PSIsContainer } |
            Measure-Object -Property Length -Sum
        ).Sum

        if ($null -eq $size) {
            return 0
        }

        return [double]$size
    }
    catch {
        return 0
    }
}


function Convert-BytesToGBText {
    param (
        [object]$Bytes
    )

    if ($null -eq $Bytes) {
        return "Desconhecido"
    }

    try {
        $numericBytes = [UInt64]$Bytes

        if ($numericBytes -le 0) {
            return "Desconhecido"
        }

        return "$([Math]::Round($numericBytes / 1GB, 2)) GB"
    }
    catch {
        return "Desconhecido"
    }
}


function Convert-MemoryType {
    param (
        [int]$Type
    )

    switch ($Type) {
        20 { return "DDR" }
        21 { return "DDR2" }
        24 { return "DDR3" }
        26 { return "DDR4" }
        34 { return "DDR5" }
        default { return "Desconhecido" }
    }
}


function Test-IsIntegratedGpu {
    param (
        [string]$GpuName
    )

    if ([string]::IsNullOrWhiteSpace($GpuName)) {
        return $false
    }

    $name = $GpuName.Trim()

    if ($name -match "AMD Radeon\(TM\) Graphics") {
        return $true
    }

    if ($name -match "^AMD Radeon Graphics$") {
        return $true
    }

    if ($name -match "Intel\(R\).*(UHD|Iris|HD) Graphics") {
        return $true
    }

    if ($name -match "Intel.*Integrated") {
        return $true
    }

    return $false
}


function Convert-ToComparableName {
    param (
        [string]$Text
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return ""
    }

    return ($Text.ToLowerInvariant() -replace "[^a-z0-9]", "")
}


function Convert-RegistryValueToUInt64 {
    param (
        [object]$Value
    )

    try {
        if ($null -eq $Value) {
            return $null
        }

        if ($Value -is [byte[]]) {
            if ($Value.Length -ge 8) {
                return [BitConverter]::ToUInt64($Value, 0)
            }

            if ($Value.Length -ge 4) {
                return [UInt64][BitConverter]::ToUInt32($Value, 0)
            }

            return $null
        }

        return [UInt64]$Value
    }
    catch {
        return $null
    }
}


function Get-RegistryGpuMemoryBytes {
    param (
        [string]$GpuName
    )

    try {
        $videoKeys = Get-ChildItem -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Video" -ErrorAction SilentlyContinue
        $candidates = @()
        $normalizedGpuName = Convert-ToComparableName -Text $GpuName

        foreach ($key in $videoKeys) {
            $adapterPath = Join-Path $key.PSPath "0000"
            $adapter = Get-ItemProperty -Path $adapterPath -ErrorAction SilentlyContinue

            if ($null -eq $adapter) {
                continue
            }

            $adapterString = $adapter."HardwareInformation.AdapterString"

            if ($adapterString -is [byte[]]) {
                $adapterString = [System.Text.Encoding]::Unicode.GetString($adapterString).Trim([char]0)
            }

            if ([string]::IsNullOrWhiteSpace($adapterString)) {
                continue
            }

            $normalizedAdapterString = Convert-ToComparableName -Text $adapterString

            $isSameGpu =
                $normalizedGpuName -eq $normalizedAdapterString -or
                $normalizedGpuName.Contains($normalizedAdapterString) -or
                $normalizedAdapterString.Contains($normalizedGpuName)

            if (-not $isSameGpu) {
                continue
            }

            $memoryBytes = $null

            if ($adapter.PSObject.Properties.Name -contains "HardwareInformation.qwMemorySize") {
                $memoryBytes = Convert-RegistryValueToUInt64 -Value $adapter."HardwareInformation.qwMemorySize"
            }
            elseif ($adapter.PSObject.Properties.Name -contains "HardwareInformation.MemorySize") {
                $memoryBytes = Convert-RegistryValueToUInt64 -Value $adapter."HardwareInformation.MemorySize"
            }

            if ($null -eq $memoryBytes -or $memoryBytes -le 0) {
                continue
            }

            $candidates += [PSCustomObject]@{
                Name   = $adapterString
                Memory = $memoryBytes
            }
        }

        if (@($candidates).Count -eq 0) {
            return $null
        }

        $bestCandidate = $candidates |
            Sort-Object -Property Memory -Descending |
            Select-Object -First 1

        return $bestCandidate.Memory
    }
    catch {
        return $null
    }
}

function Get-ExpoXmpStatus {
    param (
        [array]$MemoryModules
    )

    try {
        if ($null -eq $MemoryModules -or @($MemoryModules).Count -eq 0) {
            return "Desconhecido"
        }

        $memoryTypeCode = ($MemoryModules | Select-Object -First 1).SMBIOSMemoryType
        $memoryType = Convert-MemoryType -Type $memoryTypeCode

        $maxConfiguredSpeed = ($MemoryModules | Measure-Object -Property ConfiguredClockSpeed -Maximum).Maximum

        if ($null -eq $maxConfiguredSpeed -or $maxConfiguredSpeed -le 0) {
            return "Desconhecido"
        }

        if ($memoryType -eq "DDR5") {
            if ($maxConfiguredSpeed -ge 5200) {
                return "Provavelmente ativado"
            }

            if ($maxConfiguredSpeed -le 4800) {
                return "Provavelmente desativado / padrão JEDEC"
            }

            return "Desconhecido / velocidade customizada"
        }

        if ($memoryType -eq "DDR4") {
            if ($maxConfiguredSpeed -gt 3200) {
                return "Provavelmente ativado"
            }

            return "Provavelmente desativado / padrão JEDEC"
        }

        return "Desconhecido"
    }
    catch {
        return "Desconhecido"
    }
}


function Restart-WinForgeExplorerShell {
    # Configurações do Explorador e da barra de tarefas são recarregadas pelo shell.
    # A rotina atua apenas na sessão atual e evita abrir uma janela de arquivos extra.
    $currentSessionId = (Get-Process -Id $PID).SessionId
    $previousExplorerProcesses = @(
        Get-Process -Name "explorer" -ErrorAction SilentlyContinue |
            Where-Object { $_.SessionId -eq $currentSessionId }
    )
    $previousProcessIds = @($previousExplorerProcesses | Select-Object -ExpandProperty Id)
    $previousProcessesStillRunning = $false

    if ($previousExplorerProcesses.Count -gt 0) {
        $previousExplorerProcesses | Stop-Process -Force -ErrorAction SilentlyContinue
    }

    $exitDeadline = [DateTime]::UtcNow.AddSeconds(2)

    do {
        $previousProcessesStillRunning = @(
            Get-Process -ErrorAction SilentlyContinue |
                Where-Object { $previousProcessIds -contains $_.Id }
        ).Count -gt 0

        if (-not $previousProcessesStillRunning) {
            break
        }

        Start-Sleep -Milliseconds 50
    } while ([DateTime]::UtcNow -lt $exitDeadline)

    if ($previousProcessesStillRunning) {
        throw "O Explorer do Windows não pôde ser encerrado."
    }

    Start-Sleep -Milliseconds 100

    $explorerRestarted = @(
        Get-Process -Name "explorer" -ErrorAction SilentlyContinue |
            Where-Object { $_.SessionId -eq $currentSessionId }
    ).Count -gt 0

    if (-not $explorerRestarted) {
        Start-Process -FilePath (Join-Path $env:WINDIR "explorer.exe") -ErrorAction Stop | Out-Null
    }

    $startupDeadline = [DateTime]::UtcNow.AddSeconds(4)

    do {
        $explorerRestarted = @(
            Get-Process -Name "explorer" -ErrorAction SilentlyContinue |
                Where-Object { $_.SessionId -eq $currentSessionId }
        ).Count -gt 0

        if ($explorerRestarted) {
            return
        }

        Start-Sleep -Milliseconds 100
    } while ([DateTime]::UtcNow -lt $startupDeadline)

    throw "O Explorer do Windows não reiniciou no tempo esperado."
}


function Set-RegistryDWordValue {
    param (
        [string]$Path,
        [string]$Name,
        [int]$Value
    )

    if (-not (Test-Path $Path)) {
        New-Item -Path $Path -Force | Out-Null
    }

    New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType DWord -Force | Out-Null
}


function Set-WinForgeHighPerformancePowerPlan {
    param (
        [switch]$ThrowOnFailure
    )

    if (-not (Get-Command "powercfg.exe" -ErrorAction SilentlyContinue)) {
        if ($ThrowOnFailure) {
            throw "powercfg.exe não foi encontrado."
        }

        return $false
    }

    # GUID do plano Alto desempenho. O fallback SCHEME_MIN é usado somente se necessário.
    $highPerformanceGuid = "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"

    & powercfg.exe /SETACTIVE $highPerformanceGuid

    if ($LASTEXITCODE -eq 0) {
        return $true
    }

    # Em algumas instalações o plano pode não estar disponível. Nesse caso, recria a partir do template oficial.
    $duplicateOutput = powercfg.exe /duplicatescheme $highPerformanceGuid 2>&1

    if ($LASTEXITCODE -eq 0) {
        $duplicateText = $duplicateOutput -join "`n"
        $newGuid = [regex]::Match(
            $duplicateText,
            "[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}"
        ).Value

        if (-not [string]::IsNullOrWhiteSpace($newGuid)) {
            & powercfg.exe /SETACTIVE $newGuid

            if ($LASTEXITCODE -eq 0) {
                return $true
            }
        }
    }

    # Fallback conhecido do powercfg: SCHEME_MIN representa mínimo de economia de energia, ou seja, Alto desempenho.
    & powercfg.exe /SETACTIVE SCHEME_MIN

    if ($LASTEXITCODE -eq 0) {
        return $true
    }

    if ($ThrowOnFailure) {
        throw "Não foi possível definir o plano de energia como Alto desempenho."
    }

    return $false
}


function Invoke-DiagnosticCommand {
    param (
        [string]$Title,
        [string]$FilePath,
        [string[]]$Arguments,
        [string[]]$Description = @(),
        [string[]]$Warnings = @(),
        [switch]$SkipConfirmation,
        [switch]$NoClear,
        [switch]$NoPause
    )

    if (-not $NoClear) {
        Show-Header $Title
    }
    else {
        Write-WinForgeSection -Title $Title
    }

    if (-not (Test-IsAdministrator)) {
        Write-Host "Privilégios de Administrador são necessários para este diagnóstico." -ForegroundColor Red
        Write-Host ""
        Write-Host "Reinicie o WinForge como Administrador e tente novamente." -ForegroundColor Yellow
        Write-Host ""

        if (-not $NoPause) {
            Pause
        }

        return $false
    }

    foreach ($line in $Description) {
        Write-Host $line -ForegroundColor Yellow
    }

    if ($Description.Count -gt 0) {
        Write-Host ""
    }

    foreach ($line in $Warnings) {
        Write-Host $line -ForegroundColor Cyan
    }

    if ($Warnings.Count -gt 0) {
        Write-Host ""
    }

    Write-WinForgeCommand -Command "$FilePath $($Arguments -join ' ')"
    Write-Host ""

    if (-not $SkipConfirmation) {
        $confirmed = Confirm-Action "Deseja continuar?"

        if ($confirmed -eq $false) {
            Write-Host ""
            Write-Host "Operação cancelada." -ForegroundColor Yellow
            Write-Host ""

            if (-not $NoPause) {
                Pause
            }

            return $false
        }
    }

    try {
        $commandExists = Get-Command $FilePath -ErrorAction SilentlyContinue

        if (-not $commandExists) {
            Write-Host "Comando não encontrado: $FilePath" -ForegroundColor Red
            Write-Host ""

            if (-not $NoPause) {
                Pause
            }

            return $false
        }

        Write-Host ""
        Write-WinForgeStatus -Type Running -Message "Executando. Não feche esta janela."
        Write-Host ""

        & $FilePath @Arguments

        $exitCode = $LASTEXITCODE

        Write-Host ""

        if ($exitCode -eq 0) {
            Write-WinForgeStatus -Type Success -Message "$Title concluído com sucesso."
        }
        else {
            Write-WinForgeStatus -Type Warning -Message "$Title finalizado com código de saída: $exitCode."
            Write-Host "      Revise a saída do comando acima." -ForegroundColor DarkGray
        }

        Write-Host ""

        if (-not $NoPause) {
            Pause
        }

        return ($exitCode -eq 0)
    }
    catch {
        Write-Host ""
        Write-Host "Ocorreu um erro ao executar: $Title." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        Write-Host ""

        if (-not $NoPause) {
            Pause
        }

        return $false
    }
}


function Invoke-NativeCommandDirect {
    param (
        [string]$FilePath,
        [string[]]$Arguments = @(),
        [switch]$IgnoreExitCode
    )

    # Comandos nativos são usados aqui apenas por seus efeitos e mensagens.
    # Out-Host preserva a exibição e evita o retorno acidental de linhas ao pipeline.
    & $FilePath @Arguments | Out-Host

    $exitCode = $LASTEXITCODE

    if (-not $IgnoreExitCode -and $null -ne $exitCode -and $exitCode -ne 0) {
        throw "Comando '$FilePath $($Arguments -join ' ')' finalizou com código $exitCode."
    }
}


function Write-WinForgeSubStep {
    param (
        [string]$Title,
        [string]$Message = ""
    )

    Write-Host ""
    Write-Host "  [>] " -ForegroundColor Cyan -NoNewline
    Write-Host $Title -ForegroundColor White

    if (-not [string]::IsNullOrWhiteSpace($Message)) {
        Write-Host "      $Message" -ForegroundColor DarkGray
    }
}


function Write-WinForgeOk {
    param (
        [string]$Message
    )

    Write-WinForgeStatus -Type Success -Message $Message
}


function Write-WinForgeWarn {
    param (
        [string]$Message
    )

    Write-WinForgeStatus -Type Warning -Message $Message
}

function Initialize-WinForgeEnvironment {
    Set-WinForgeConsoleEncoding

    # Windows PowerShell 5.1 pode usar TLS antigo por padrão. TLS 1.2 melhora compatibilidade com chamadas HTTPS.
    if ($PSVersionTable.PSVersion.Major -lt 6) {
        try {
            [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
        }
        catch {
            # Não bloqueia a execução caso a plataforma não permita alterar o protocolo.
        }
    }
}


function Initialize-Winget {
    Show-Header "WinForge"

    Write-Host "Inicializando winget..." -ForegroundColor Yellow
    Write-Host ""

    try {
        if (-not (Get-Command "winget" -ErrorAction SilentlyContinue)) {
            Write-WinForgeStatus -Type Error -Message "winget não foi encontrado neste sistema."
            Write-Host "  Instale ou atualize o App Installer pela Microsoft Store." -ForegroundColor Yellow
            Write-Host ""
            Start-Sleep -Seconds 2
            return $false
        }

        & winget source update --accept-source-agreements | Out-Null
        $exitCode = $LASTEXITCODE

        if ($exitCode -eq 0) {
            Write-WinForgeStatus -Type Success -Message "winget está pronto."
        }
        else {
            Write-WinForgeStatus -Type Warning -Message "winget está disponível, mas a fonte não pôde ser atualizada."
        }

        Start-Sleep -Seconds 1
        return $true
    }
    catch {
        Write-WinForgeStatus -Type Error -Message "Falha ao inicializar winget."
        Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
        Write-Host ""
        Start-Sleep -Seconds 2
        return $false
    }
}


Export-ModuleMember -Function *
