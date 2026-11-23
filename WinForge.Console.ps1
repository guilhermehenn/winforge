#requires -Version 5.1
<#
.SYNOPSIS
    WinForge no terminal: menus de texto para manutenção, diagnóstico e ajustes do Windows.

.DESCRIPTION
    A versão com janela é WinForge.Gui.ps1 (abra pelo WinForge.cmd). As duas usam os mesmos módulos e a mesma
    tabela de navegação (modules\Navigation.psm1), então oferecem as mesmas ações na mesma ordem.

.PARAMETER Action
    Menu     - abre o menu interativo (padrão).
    Report   - gera o relatório HTML/TXT e termina.
    Shortcut - cria o atalho do WinForge (com o ícone) na Área de Trabalho e termina. Não pede Administrador.
    ScheduledMaintenance - o que a tarefa da Manutenção agendada executa: limpa os temporários do usuário com mais de
               7 dias, salva o relatório e termina, sem perguntas e sem pedir Administrador (uma tarefa em segundo plano não pode
               esperar por um pedido de elevação).
    Check    - verificação rápida e só de leitura: nota de saúde e nota de segurança (sem a consulta ao Windows Update).
               Não pede Administrador, não grava log e não pergunta nada, então serve para tarefas e scripts. O código
               de saída diz o resultado: 0 tudo em dia, 1 pontos de atenção, 2 algo crítico, 3 não foi possível avaliar.

.PARAMETER Json
    Somente com -Action Check: escreve o resultado como JSON (UTF-8) em vez do texto, e nada mais na saída.

.PARAMETER ReportDirectory
    Pasta de saída do relatório (somente com -Action Report). Padrão: %LOCALAPPDATA%\WinForge\reports.

.PARAMETER Language
    O idioma do menu: pt (português), en (inglês) ou es (espanhol). Sem ele, vale a escolha em Sobre o WinForge > Idioma
    ou, sem escolha, o idioma do Windows (português, inglês ou espanhol; qualquer outro, inglês).

.PARAMETER PauseAtEnd
    Espera uma tecla antes de fechar. É passado automaticamente quando o script se reabre como Administrador,
    para que a janela nova não suma antes de o resultado ser lido.
#>
[CmdletBinding()]
param (
    [string]$Action = "Menu",

    [string]$ReportDirectory,

    [switch]$Json,

    [string]$Language,

    [switch]$PauseAtEnd
)

$ErrorActionPreference = "Continue"

function Get-WinForgeStartupText {
    # As mensagens de antes dos módulos (ou de quando eles não carregaram). Com o Core carregado, valem Get-WinForgeText e
    # o idioma do WinForge; sem ele, estas poucas mensagens trazem a tradução aqui mesmo, pelo idioma do Windows.
    param ([string]$Text)

    $command = Get-Command -Name Get-WinForgeText -CommandType Function -ErrorAction SilentlyContinue

    if ($null -ne $command) { return (& $command $Text @args) }

    $table = @{
        "Não foi possível abrir a janela do WinForge. Abra o WinForge de novo." = @("The WinForge window could not be opened. Open WinForge again.", "No se pudo abrir la ventana de WinForge. Abre WinForge de nuevo.")
        "Módulo obrigatório não encontrado: {0}" = @("Required module not found: {0}", "No se encontró un módulo necesario: {0}")
        "Arquivo da janela não encontrado: {0}" = @("Window file not found: {0}", "No se encontró el archivo de la ventana: {0}")
        "Extraia de novo o WinForge.zip inteiro (Extrair tudo), numa pasta sem colchetes no nome, e abra o WinForge da pasta extraída." = @("Extract the whole WinForge.zip again (Extract all) to a folder without brackets in its name, and open WinForge from the extracted folder.", "Vuelve a extraer todo WinForge.zip (Extraer todo) en una carpeta sin corchetes en el nombre y abre WinForge desde la carpeta extraída.")
        "O WinForge não abriu porque falta um arquivo dele: {0}.`n`n{1} Se o arquivo sumir outra vez, veja se o antivírus o pôs em quarentena." = @("WinForge did not open because one of its files is missing: {0}.`n`n{1} If the file disappears again, check whether the antivirus quarantined it.", "WinForge no se abrió porque falta uno de sus archivos: {0}.`n`n{1} Si el archivo vuelve a desaparecer, revisa si el antivirus lo puso en cuarentena.")
        "O WinForge não abriu.`n`n{0} Se continuar, mande este detalhe ao suporte:`n`n{1}" = @("WinForge did not open.`n`n{0} If it keeps happening, send this detail to support:`n`n{1}", "WinForge no se abrió.`n`n{0} Si sigue pasando, envía este detalle al soporte:`n`n{1}")
        "Ação desconhecida: '{0}'. Use -Action Menu, Report, Shortcut, ScheduledMaintenance ou Check." = @("Unknown action: '{0}'. Use -Action Menu, Report, Shortcut, ScheduledMaintenance or Check.", "Acción desconocida: '{0}'. Usa -Action Menu, Report, Shortcut, ScheduledMaintenance o Check.")
        "O -Json só vale com -Action Check (a verificação rápida)." = @("-Json only works with -Action Check (the quick check).", "-Json solo funciona con -Action Check (la verificación rápida).")
        "Idioma desconhecido: '{0}'. Use -Language pt, en ou es." = @("Unknown language: '{0}'. Use -Language pt, en or es.", "Idioma desconocido: '{0}'. Usa -Language pt, en o es.")
        "Arquivo de módulos não encontrado: {0}" = @("Module list not found: {0}", "No se encontró la lista de módulos: {0}")
        "Extraia o WinForge por completo antes de executar." = @("Extract all of WinForge before running it.", "Extrae WinForge por completo antes de ejecutarlo.")
        "Não foi possível carregar o WinForge: {0}" = @("WinForge could not be loaded: {0}", "No se pudo cargar WinForge: {0}")
    }

    $language = ""

    try { $language = [string][System.Globalization.CultureInfo]::CurrentUICulture.TwoLetterISOLanguageName } catch { $language = "" }

    if ($env:WINFORGE_LANG) { $language = ([string]$env:WINFORGE_LANG).Trim().ToLowerInvariant() }

    if ($language -ne "pt" -and $table.ContainsKey($Text)) { $Text = $table[$Text][$(if ($language -eq "es") { 1 } else { 0 })] }

    if ($args.Count -gt 0) { return [string]::Format([System.Globalization.CultureInfo]::InvariantCulture, $Text, [object[]]$args) }

    return $Text
}

# O idioma pedido vale para este processo (e para a reabertura como Administrador, que o recebe de novo).
if (-not [string]::IsNullOrWhiteSpace($Language)) {
    if ($Language.Trim().ToLowerInvariant() -notin @("pt", "en", "es")) {
        Write-Host (Get-WinForgeStartupText 'Idioma desconhecido: ''{0}''. Use -Language pt, en ou es.' "$Language") -ForegroundColor Red
        exit 1
    }

    $Language = $Language.Trim().ToLowerInvariant()
    $env:WINFORGE_LANG = $Language
}

# A ação é conferida aqui, e não com ValidateSet: um nome errado ("-Action Relatorio") recebe a lista em português, e
# não o erro em inglês do PowerShell. Maiúsculas e minúsculas não importam.
$knownActions = @("Menu", "Report", "Shortcut", "ScheduledMaintenance", "Check")
$matchedAction = @($knownActions | Where-Object { $_ -ieq $Action })

if ($matchedAction.Count -eq 0) {
    Write-Host (Get-WinForgeStartupText 'Ação desconhecida: ''{0}''. Use -Action Menu, Report, Shortcut, ScheduledMaintenance ou Check.' "$Action") -ForegroundColor Red
    exit 1
}

$Action = $matchedAction[0]

if ($Json -and $Action -ne "Check") {
    Write-Host (Get-WinForgeStartupText 'O -Json só vale com -Action Check (a verificação rápida).') -ForegroundColor Red
    exit 1
}

# --- Módulos (lista em modules\Modules.psd1) ---------------------------------------------------------
$moduleRoot = Join-Path $PSScriptRoot "modules"
$manifestPath = Join-Path $moduleRoot "Modules.psd1"

if (-not (Test-Path -LiteralPath $manifestPath)) {
    Write-Host (Get-WinForgeStartupText 'Arquivo de módulos não encontrado: {0}' "$manifestPath") -ForegroundColor Red
    Write-Host (Get-WinForgeStartupText 'Extraia o WinForge por completo antes de executar.') -ForegroundColor Yellow
    exit 1
}

try {
    $manifest = Import-PowerShellDataFile -LiteralPath $manifestPath -ErrorAction Stop

    foreach ($name in (@($manifest.Common) + @($manifest.Console))) {
        $modulePath = Join-Path $moduleRoot "$name.psm1"

        if (-not (Test-Path -LiteralPath $modulePath)) {
            throw (Get-WinForgeStartupText 'Módulo obrigatório não encontrado: {0}' "$modulePath")
        }

        try {
            Import-Module -Name $modulePath -Force -DisableNameChecking -Global -ErrorAction Stop
        }
        catch {
            # Caminhos com colchetes são lidos como curinga pelo Import-Module; escapar resolve.
            Import-Module -Name ([System.Management.Automation.WildcardPattern]::Escape($modulePath)) -Force -DisableNameChecking -Global -ErrorAction Stop
        }
    }
}
catch {
    Write-Host (Get-WinForgeStartupText 'Não foi possível carregar o WinForge: {0}' "$($_.Exception.Message)") -ForegroundColor Red
    exit 1
}

Initialize-WinForgeEnvironment

# --- Administrador -----------------------------------------------------------------------------------
# Uma pasta de relatório relativa ("-ReportDirectory .\saida") vale a partir de onde o comando foi digitado: o .cmd
# entra na pasta do WinForge e a reabertura como Administrador começa em System32, então o caminho vira absoluto aqui.
if (-not [string]::IsNullOrWhiteSpace($ReportDirectory) -and -not [System.IO.Path]::IsPathRooted($ReportDirectory)) {
    $callerFolder = $(if ($env:WINFORGE_CALLER_DIR) { $env:WINFORGE_CALLER_DIR } else { (Get-Location).ProviderPath })
    $ReportDirectory = [System.IO.Path]::GetFullPath((Join-Path $callerFolder $ReportDirectory))
}

$relaunchArguments = @()

if ($Action -ne "Menu") {
    $relaunchArguments += "-Action $Action"
}

if (-not [string]::IsNullOrWhiteSpace($Language)) {
    $relaunchArguments += "-Language $Language"
}

if (-not [string]::IsNullOrWhiteSpace($ReportDirectory)) {
    $relaunchArguments += "-ReportDirectory $(ConvertTo-WinForgeCommandLineArgument -Value $ReportDirectory)"
}

if ($Action -eq "Report") {
    $relaunchArguments += "-PauseAtEnd"
}

# O atalho é criado pela pessoa que executa (a Área de Trabalho dela); elevar poderia usar o perfil de outro usuário.
# A manutenção agendada roda em segundo plano com o usuário logado e sem elevação, então não há quem aprove o pedido.
# A verificação rápida só lê e é feita para scripts: reabrir como Administrador abriria outra janela e perderia a saída.
if ($Action -notin "Shortcut", "ScheduledMaintenance", "Check") {
    Restart-WinForgeAsAdministrator -ScriptPath $PSCommandPath -ExtraArguments $relaunchArguments
}

# --- Execução ----------------------------------------------------------------------------------------
$exitCode = 0

# A verificação rápida não grava log: a saída precisa ficar limpa e uma tarefa que roda sempre não deve encher a pasta.
if ($Action -ne "Check") {
    [void](Start-WinForgeLogging)
}

try {
    if ($Action -eq "Report") {
        Write-Host (Get-WinForgeText 'Gerando relatório...') -ForegroundColor Cyan

        $report = Export-WinForgeReport -Directory $ReportDirectory
        Write-Host (Get-WinForgeText 'HTML : {0}' "$($report.Html)") -ForegroundColor Green

        # O HTML vale sozinho; a cópia em texto que não pôde ser gravada é avisada, sem esconder o HTML salvo.
        if ($report.Text) { Write-Host (Get-WinForgeText 'Texto: {0}' "$($report.Text)") -ForegroundColor Green }
        else { Write-Host (Get-WinForgeText 'Texto: não foi gravado ({0})' "$($report.TextProblem)") -ForegroundColor Yellow }

        if ($PauseAtEnd) {
            Write-Host ""
            Wait-WinForgeKey -Message (Get-WinForgeText 'Pressione qualquer tecla para fechar...')
        }
    }
    elseif ($Action -eq "ScheduledMaintenance") {
        $scheduled = @(Invoke-WinForgeScheduledMaintenance) | Select-Object -Last 1

        if ($scheduled.Kind -eq "Failed") {
            $exitCode = 1
        }
    }
    elseif ($Action -eq "Check") {
        $check = Get-WinForgeCheckReport

        if ($Json) {
            Write-Output (ConvertTo-WinForgeCheckJson -Report $check)
        }
        else {
            Show-WinForgeCheckReport -Report $check
        }

        $exitCode = [int]$check.ExitCode
    }
    elseif ($Action -eq "Shortcut") {
        $shortcut = New-WinForgeAppShortcut -Location Desktop -Embedded -PassThru

        if ($shortcut.Kind -eq "Failed") {
            $exitCode = 1
        }
    }
    else {
        # Sem isto, a janela do terminal se chamaria "Administrador: C:\Windows\System32\...\powershell.exe".
        try { $Host.UI.RawUI.WindowTitle = "WinForge" } catch { Write-Verbose "Título da janela: $($_.Exception.Message)" }

        try { Add-WinForgeOpenTime -Kind "Console" -Seconds ((Get-Date) - (Get-Process -Id $PID).StartTime).TotalSeconds } catch { Write-Verbose "Tempo de abertura: $($_.Exception.Message)" }

        # Aberto pelo instalador depois de uma atualização: diz como ela terminou, uma vez.
        try {
            $update = Read-WinForgeUpdateResult

            if ($null -ne $update) {
                $message = Get-WinForgeUpdateResultText -Result $update
                Write-Host ""
                Write-WinForgeStatus -Type $(if ($message.Ok) { "Success" } else { "Warning" }) -Message $message.Text
                Write-Host ""
                Wait-WinForgeKey
            }
        }
        catch {
            Write-Verbose "Resultado da atualização: $($_.Exception.Message)"
        }

        Show-WinForgeMainMenu
    }
}
catch {
    $exitCode = 1
    Write-Host ""
    $failure = $_.Exception.Message
    try { $failure = ConvertTo-WinForgeReadableError -Text $failure } catch { }
    Write-Host (Get-WinForgeText 'O WinForge encontrou um erro e precisa fechar: {0}' "$failure") -ForegroundColor Red

    # Aberto pelo WinForge-Console.cmd (WINFORGE_FROM_CMD), quem pausa é o .cmd, uma vez só.
    if (($PauseAtEnd -or $Action -eq "Menu") -and $env:WINFORGE_FROM_CMD -ne "1") {
        Wait-WinForgeKey -Message (Get-WinForgeText 'Pressione qualquer tecla para fechar...')
    }
}
finally {
    Stop-WinForgeLogging
}

exit $exitCode
