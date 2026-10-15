# Núcleo: ambiente, sessão, registro, log, formatação e execução de programas nativos.
# Nada aqui desenha cabeçalhos ou faz perguntas; isso fica em Console.psm1.

$script:WinForgeBuild = "3.5"
$script:WinForgeSession = $null
$script:WinForgeLastMaintenance = $null
$script:WinForgeLogPath = $null
$script:WinForgeLoggingActive = $false

# Limites de Get-WinForgeDiskSpaceLevel: abaixo de 5 GB livres é "Critical"; abaixo de 10% livres é "Low".
$script:WinForgeLowDiskBytes = 5GB
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


function Get-WinForgeDataPath {
    # Local persistente para logs, backups de ajustes e relatórios (por usuário elevado).
    $root = Join-Path $env:LOCALAPPDATA "WinForge"

    if (-not (Test-Path -LiteralPath $root)) {
        New-Item -Path $root -ItemType Directory -Force | Out-Null
    }

    return $root
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

    Show-WinForgeHeader "WinForge"

    Write-Host "O WinForge precisa ser executado como Administrador para operações do sistema." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "A aplicação será reiniciada como Administrador." -ForegroundColor Cyan
    Write-Host ""

    Start-Sleep -Seconds 2

    if (-not (Test-Path -LiteralPath $ScriptPath)) {
        Write-Host "Não foi possível identificar o caminho do script principal." -ForegroundColor Red
        Write-Host "Execute o WinForge a partir de um arquivo .ps1 salvo." -ForegroundColor Yellow
        Write-Host ""
        Wait-WinForgeKey
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
        # UAC recusado ou bloqueado por política: não há o que fazer além de avisar.
        Write-Host "A elevação foi cancelada. O WinForge não pode continuar sem privilégios de Administrador." -ForegroundColor Red
        Write-Host ""
        Wait-WinForgeKey
    }

    exit
}


function Get-WinForgeInteractiveUser {
    try {
        $interactiveUser = (Get-CimInstance Win32_ComputerSystem -ErrorAction Stop).UserName

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
    # Considera notebook quando há bateria ou o chassi é portátil (SMBIOS ChassisTypes).
    try {
        if (@(Get-CimInstance Win32_Battery -ErrorAction Stop).Count -gt 0) {
            return $true
        }
    }
    catch {
        # Segue para a checagem de chassi.
    }

    try {
        $portableTypes = @(8, 9, 10, 11, 12, 14, 18, 21, 30, 31, 32)
        $chassis = @((Get-CimInstance Win32_SystemEnclosure -ErrorAction Stop).ChassisTypes)

        foreach ($type in $chassis) {
            if ($portableTypes -contains [int]$type) {
                return $true
            }
        }
    }
    catch {
        # Sem informação: assume desktop.
    }

    return $false
}


function Test-WinForgeOnBattery {
    # $true quando o notebook está funcionando na bateria (BatteryStatus 1 = descarregando, 4 = baixa, 5 = crítica).
    # Desktop, tomada conectada e falha na consulta dão $false: na dúvida, o WinForge não atrapalha o usuário.
    try {
        $batteries = @(Get-CimInstance Win32_Battery -ErrorAction Stop)
        return (@($batteries | Where-Object { [int]$_.BatteryStatus -in 1, 4, 5 }).Count -gt 0)
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
    checagem da Manutenção: "Critical" = menos de 5 GB livres (pouco até para o DISM e as atualizações trabalharem),
    "Low" = menos de 10% livres e "Ok" nos demais casos. Sem dados válidos (valor negativo ou nulo) devolve "Unknown".
    #>
    param (
        [object]$FreeBytes,
        [object]$TotalBytes
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
    if ($free -lt $script:WinForgeLowDiskBytes) { return "Critical" }
    if ($total -gt 0 -and (($free * 100) / $total) -lt $script:WinForgeLowDiskPercent) { return "Low" }

    return "Ok"
}


function Get-WinForgeWindowsBuild {
    try {
        $operatingSystem = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
        return [int]$operatingSystem.BuildNumber
    }
    catch {
        return [int][Environment]::OSVersion.Version.Build
    }
}


function Test-WinForgeWindows11 {
    return (Get-WinForgeWindowsBuild) -ge 22000
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

    try {
        $build = [int](Get-CimInstance Win32_OperatingSystem -ErrorAction Stop).BuildNumber
        $windowsLabel = if ($build -ge 22000) { "Windows 11" } else { "Windows 10" }
    }
    catch {
        # Mantém valores padrão.
    }

    try {
        $script:WinForgeSession = [PSCustomObject]@{
            IsAdmin      = Test-WinForgeAdministrator
            User         = [Security.Principal.WindowsIdentity]::GetCurrent().Name
            UserMismatch = Test-WinForgeUserContextMismatch
            IsLaptop     = Test-WinForgeLaptop
            WindowsLabel = $windowsLabel
            WindowsBuild = $build
        }
    }
    catch {
        # As informações de sessão são auxiliares; nunca devem impedir a exibição de uma tela.
        $script:WinForgeSession = [PSCustomObject]@{
            IsAdmin      = $false
            User         = $env:USERNAME
            UserMismatch = $false
            IsLaptop     = $false
            WindowsLabel = $windowsLabel
            WindowsBuild = $build
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
        [Console]::InputEncoding = $utf8Encoding
        [Console]::OutputEncoding = $utf8Encoding
        $global:OutputEncoding = $utf8Encoding
        chcp.com 65001 | Out-Null
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


function Start-WinForgeLogging {
    # Idempotente: chamar de novo com o log ativo não abre um segundo transcript.
    if ($script:WinForgeLoggingActive) {
        return $true
    }

    try {
        $logDirectory = Join-Path (Get-WinForgeDataPath) "logs"

        if (-not (Test-Path -LiteralPath $logDirectory)) {
            New-Item -Path $logDirectory -ItemType Directory -Force | Out-Null
        }

        # Mantém apenas os 20 logs mais recentes.
        Get-ChildItem -LiteralPath $logDirectory -Filter "winforge-*.log" -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            Select-Object -Skip 20 |
            Remove-Item -Force -ErrorAction SilentlyContinue

        $script:WinForgeLogPath = Join-Path $logDirectory ("winforge-{0:yyyyMMdd-HHmmss}.log" -f (Get-Date))
        Start-Transcript -Path $script:WinForgeLogPath -Force | Out-Null
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
            Stop-Transcript | Out-Null
        }
    }
    catch {
        # O transcript pode não estar ativo.
    }

    $script:WinForgeLoggingActive = $false
}


function Get-WinForgeLogPath {
    return $script:WinForgeLogPath
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


function Set-WinForgeRegistryDWord {
    param (
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [int]$Value
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -Path $Path -Force | Out-Null
    }

    New-ItemProperty -LiteralPath $Path -Name $Name -Value $Value -PropertyType DWord -Force | Out-Null
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
    # Remove um valor de registro; não é erro se a chave ou o valor já não existem.
    param (
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Name
    )

    if (Test-Path -LiteralPath $Path) {
        Remove-ItemProperty -LiteralPath $Path -Name $Name -ErrorAction SilentlyContinue
    }
}


# ---------------------------------------------------------------------------
# Formatação
# ---------------------------------------------------------------------------

function Format-WinForgeBytes {
    # Texto legível para tamanhos (B, KB, MB, GB, TB). Valores nulos, inválidos ou <= 0 viram $ZeroText.
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

    if ($value -ge 1PB) { return "$([Math]::Round($value / 1PB, 2)) PB" }
    if ($value -ge 1TB) { return "$([Math]::Round($value / 1TB, 2)) TB" }
    if ($value -ge 1GB) { return "$([Math]::Round($value / 1GB, 2)) GB" }
    if ($value -ge 1MB) { return "$([Math]::Round($value / 1MB, 2)) MB" }
    if ($value -ge 1KB) { return "$([Math]::Round($value / 1KB, 2)) KB" }

    return "$([Math]::Round($value, 0)) B"
}


function Format-WinForgeRelativeTime {
    # "há 3 dias", "há 2 horas", "agora há pouco": mostra quando algo aconteceu sem obrigar a pessoa a fazer a conta.
    # Um horário no futuro (relógio ajustado depois) conta como "agora há pouco".
    param (
        [Parameter(Mandatory)]
        [datetime]$When,

        [datetime]$Now = (Get-Date)
    )

    $span = $Now - $When

    if ($span.TotalMinutes -lt 1) { return "agora há pouco" }

    if ($span.TotalHours -lt 1) {
        $amount = [int][Math]::Floor($span.TotalMinutes)
        $unit = @("minuto", "minutos")
    }
    elseif ($span.TotalDays -lt 1) {
        $amount = [int][Math]::Floor($span.TotalHours)
        $unit = @("hora", "horas")
    }
    elseif ($span.TotalDays -lt 30) {
        $amount = [int][Math]::Floor($span.TotalDays)
        $unit = @("dia", "dias")
    }
    elseif ($span.TotalDays -lt 365) {
        $amount = [int][Math]::Floor($span.TotalDays / 30)
        $unit = @("mês", "meses")
    }
    else {
        $amount = [int][Math]::Floor($span.TotalDays / 365)
        $unit = @("ano", "anos")
    }

    $word = if ($amount -eq 1) { $unit[0] } else { $unit[1] }

    return "há $amount $word"
}


function Format-WinForgeDuration {
    param (
        [TimeSpan]$Span
    )

    # O relógio pode ser ajustado durante uma etapa longa; duração negativa não faz sentido.
    if ($Span.Ticks -lt 0) { $Span = [TimeSpan]::Zero }

    if ($Span.TotalHours -ge 1) { return ("{0}h {1:00}min" -f [int][Math]::Floor($Span.TotalHours), $Span.Minutes) }
    if ($Span.TotalMinutes -ge 1) { return ("{0}min {1:00}s" -f [int][Math]::Floor($Span.TotalMinutes), $Span.Seconds) }
    return ("{0}s" -f [int][Math]::Round($Span.TotalSeconds))
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
        throw "Não há itens para escolher."
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
                throw "O intervalo '$part' está invertido."
            }

            $values = @($first, $last)
            $expand = $true
        }
        elseif ($part -match "^[0-9]{1,9}$") {
            $values = @([int]$part)
            $expand = $false
        }
        else {
            throw "'$part' não é um número nem um intervalo válido."
        }

        foreach ($value in $values) {
            if ($value -lt 1 -or $value -gt $Maximum) {
                throw "O número $value está fora da lista (1 a $Maximum)."
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

    # Sem isto, o código de uma chamada anterior pareceria ser o deste programa se ele nem chegasse a definir um.
    $global:LASTEXITCODE = 0

    if (Test-WinForgeGuiMode) {
        # Ferramentas que gravam em UTF-16 (SFC) deixam caracteres nulos entre as letras; eles são removidos.
        & $FilePath @Arguments 2>&1 | ForEach-Object { Write-Host (([string]$_) -replace "`0", "") }
    }
    else {
        & $FilePath @Arguments | Out-Host
    }

    $exitCode = $LASTEXITCODE

    if (-not $IgnoreExitCode -and $null -ne $exitCode -and $exitCode -ne 0) {
        throw "Comando '$FilePath $($Arguments -join ' ')' finalizou com código $exitCode."
    }

    if ($PassThru) {
        return $exitCode
    }
}


function Invoke-WinForgeCapture {
    <#
    Executa um programa nativo e devolve ExitCode, Lines e Text. Com -Echo as linhas também aparecem na tela
    enquanto chegam, o que evita uma janela parada durante comandos demorados (CHKDSK, DISM).
    #>
    param (
        [Parameter(Mandatory)]
        [string]$FilePath,

        [string[]]$Arguments = @(),

        [switch]$Echo
    )

    $lines = New-Object System.Collections.Generic.List[string]
    $global:LASTEXITCODE = 0

    & $FilePath @Arguments 2>&1 | ForEach-Object {
        $line = ([string]$_) -replace "`0", ""
        $lines.Add($line)

        if ($Echo) {
            Write-Host $line
        }
    }

    return [PSCustomObject]@{
        ExitCode = $LASTEXITCODE
        Lines    = @($lines)
        Text     = ($lines -join "`n")
    }
}


function Get-WinForgePathStats {
    <#
    Percorre um arquivo ou pasta sem seguir atalhos de pasta (junções e links simbólicos), que poderiam levar a
    outras pastas, a ciclos ou a contar duas vezes o mesmo conteúdo. Devolve Size (bytes), Files e Newest (data
    de alteração mais recente). Itens ilegíveis são ignorados: o resultado é uma estimativa.
    -ExcludeShellMetadata ignora desktop.ini e Thumbs.db, que não são conteúdo do usuário.
    #>
    param (
        [string]$Path,
        [switch]$ExcludeShellMetadata
    )

    $stats = [PSCustomObject]@{
        Size   = [int64]0
        Files  = [int64]0
        Newest = [datetime]::MinValue
    }

    $addFile = {
        param ($file)

        if ($ExcludeShellMetadata -and $file.Name -in @("desktop.ini", "Thumbs.db")) {
            return
        }

        $stats.Size += [int64]$file.Length
        $stats.Files++

        if ($file.LastWriteTime -gt $stats.Newest) {
            $stats.Newest = $file.LastWriteTime
        }
    }

    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path)) {
        return $stats
    }

    try {
        $root = Get-Item -LiteralPath $Path -Force -ErrorAction Stop

        if (-not $root.PSIsContainer) {
            & $addFile $root
            return $stats
        }

        $pending = New-Object System.Collections.Generic.Stack[string]
        $pending.Push($root.FullName)

        while ($pending.Count -gt 0) {
            $current = $pending.Pop()

            try {
                $directory = New-Object System.IO.DirectoryInfo -ArgumentList $current

                foreach ($entry in $directory.EnumerateFileSystemInfos()) {
                    try {
                        if ($entry -is [System.IO.DirectoryInfo]) {
                            if (($entry.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -eq 0) {
                                $pending.Push($entry.FullName)
                            }
                        }
                        else {
                            & $addFile $entry
                        }
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
    catch {
        # Caminho inacessível: devolve o que foi somado.
    }

    return $stats
}


function Invoke-WinForgeInBackground {
    <#
    Roda um bloco em outro runspace e espera por ele em fatias curtas, até $TimeoutSeconds. É para chamadas que podem
    demorar e que o botão Parar não consegue interromper por dentro (por exemplo, a consulta COM do Windows Update): a
    espera aqui continua interrompível, e um bloco que não termina a tempo é abandonado.
    O bloco roda num runspace novo e não enxerga as funções do WinForge; os valores entram por -ArgumentList (param).
    Devolve Completed, TimedOut, Output (o que o bloco escreveu) e Error (texto do primeiro erro, ou vazio).
    #>
    param (
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock,

        [object[]]$ArgumentList = @(),

        [ValidateRange(1, 3600)]
        [int]$TimeoutSeconds = 60
    )

    $shell = [powershell]::Create()
    $finished = $false

    try {
        [void]$shell.AddScript($ScriptBlock.ToString())

        foreach ($argument in $ArgumentList) {
            [void]$shell.AddArgument($argument)
        }

        $handle = $shell.BeginInvoke()
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

        while (-not $handle.AsyncWaitHandle.WaitOne(200)) {
            if ($stopwatch.Elapsed.TotalSeconds -ge $TimeoutSeconds) {
                return [PSCustomObject]@{ Completed = $false; TimedOut = $true; Output = @(); Error = "" }
            }
        }

        $finished = $true
        $output = @()
        $errorText = ""

        try {
            $output = @($shell.EndInvoke($handle))
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
        if ($finished) {
            $shell.Dispose()
        }
        else {
            # Tempo esgotado ou interrompido: pede para parar sem esperar (Dispose bloquearia numa chamada COM presa).
            try { [void]$shell.BeginStop($null, $null) } catch { }
        }
    }
}


function Set-WinForgeKeepAwake {
    <#
    Impede que o Windows suspenda o PC enquanto uma manutenção longa roda (SetThreadExecutionState).
    O pedido vale para a thread atual: chame com -Enabled $false (em um finally) ao terminar.
    Retorna $false quando a API não está disponível.
    #>
    param (
        [Parameter(Mandatory)]
        [bool]$Enabled
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

        if ($Enabled) {
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
        throw "O Explorer do Windows não pôde ser encerrado."
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
    Start-Process -FilePath (Join-Path $env:WINDIR "explorer.exe") -ErrorAction Stop | Out-Null

    $startupDeadline = [DateTime]::UtcNow.AddSeconds(8)

    do {
        if (@(& $getSessionExplorer).Count -gt 0) {
            return
        }

        Start-Sleep -Milliseconds 200
    } while ([DateTime]::UtcNow -lt $startupDeadline)

    throw "O Explorer do Windows não reiniciou no tempo esperado."
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
    $guidPattern = "[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}"

    $activate = {
        param ([string]$Scheme)
        return ((Invoke-WinForgeCapture -FilePath "powercfg.exe" -Arguments @("/setactive", $Scheme)).ExitCode -eq 0)
    }

    if (& $activate $highPerformanceGuid) {
        return $true
    }

    # Em algumas instalações o plano pode não estar disponível. Nesse caso, recria a partir do template oficial.
    $duplicate = Invoke-WinForgeCapture -FilePath "powercfg.exe" -Arguments @("/duplicatescheme", $highPerformanceGuid)

    if ($duplicate.ExitCode -eq 0) {
        $newGuid = [regex]::Match($duplicate.Text, $guidPattern).Value

        if (-not [string]::IsNullOrWhiteSpace($newGuid) -and (& $activate $newGuid)) {
            return $true
        }
    }

    # Fallback conhecido do powercfg: SCHEME_MIN representa o mínimo de economia de energia, ou seja, Alto desempenho.
    if (& $activate "SCHEME_MIN") {
        return $true
    }

    if ($ThrowOnFailure) {
        throw "Não foi possível definir o plano de energia como Alto desempenho."
    }

    return $false
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
        $After = $null
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

        $path = Get-WinForgeLastMaintenancePath
        $temporary = "$path.tmp"

        Set-Content -LiteralPath $temporary -Value ($document | ConvertTo-Json -Depth 4) -Encoding UTF8 -ErrorAction Stop
        Move-Item -LiteralPath $temporary -Destination $path -Force -ErrorAction Stop
    }
    catch {
        # O histórico em disco é um complemento; a memória já tem o resultado.
    }
}


function Get-WinForgeLastMaintenance {
    if ($null -ne $script:WinForgeLastMaintenance) {
        return $script:WinForgeLastMaintenance
    }

    try {
        $path = Get-WinForgeLastMaintenancePath

        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            return $null
        }

        $document = Get-Content -LiteralPath $path -Raw -Encoding UTF8 -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop

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


Export-ModuleMember -Function *
