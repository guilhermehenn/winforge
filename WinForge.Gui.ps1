#requires -Version 5.1
<#
.SYNOPSIS
    WinForge com janela (WPF): as ações rodam dentro da própria janela, sem abrir terminal.

.DESCRIPTION
    A barra lateral e os cartões vêm da tabela de navegação (modules\Navigation.psm1), a mesma que monta os menus
    do WinForge.Console.ps1. Cada ação roda num runspace separado com um host próprio (modules\GuiHost.psm1):
    a saída aparece no painel e as perguntas viram botões, listas de marcação ou caixa de texto.

    Abra pelo WinForge.cmd. A janela abre sempre como Administrador e em modo STA (exigido pelo WPF): sem um deles, o
    script se reabre pedindo a permissão ao Windows. Se a pessoa recusa o aviso do Windows, a janela abre assim mesmo,
    sem Administrador, e se reabre elevada, na mesma página, quando uma ação exige.

.PARAMETER Relaunched
    Uso interno: indica que esta é a segunda execução. Ela não pede a elevação de novo, o que evita um laço caso a
    elevação ou o STA falhem.

.PARAMETER Handover
    Uso interno: a execução anterior ainda segura a trava da janela e fecha logo depois de abrir esta (a janela que
    pediu o Administrador para uma ação); esta espera por ela em vez de lhe passar o pedido.

.PARAMETER Page
    Uso interno: a página que a janela abre. A segunda execução (elevada) reabre na página em que a pessoa estava.

.PARAMETER Action
    Uso interno: o item da navegação (por exemplo maintenance.checkup) que a janela roda assim que abre. O monitor na
    bandeja usa para Acelerar agora, Limpeza rápida e Verificar o PC.
#>
[CmdletBinding()]
param (
    [switch]$Relaunched,

    [switch]$Handover,

    [string]$Page = "home",

    [string]$Action = ""
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

function Show-GuiStartupMessage {
    # Usado antes de a janela existir (falhas de elevação e de carga). Sem console visível, é a única forma de avisar.
    param (
        [Parameter(Mandatory)][string]$Text,
        [string]$Icon = "Error"
    )

    try {
        Add-Type -AssemblyName PresentationFramework
        [void][System.Windows.MessageBox]::Show($Text, "WinForge", "OK", $Icon)
    }
    catch {
        Write-Host $Text
    }
}

# --- Administrador e STA (o WPF exige STA) -------------------------------------------------------------
# A janela abre sempre como Administrador. Sem ele, o script se reabre pedindo a permissão (o aviso do Windows). Se a
# pessoa recusa, a janela abre assim mesmo, sem Administrador: Diagnóstico e as telas de leitura funcionam, e cada ação
# que altera o sistema oferece reabrir elevada (Request-GuiAdministrator). A segunda execução (-Relaunched) não pede de
# novo, para não entrar em laço se o Windows não elevar.
function Get-GuiLaunchScriptPath {
    # O caminho deste script para a execução elevada. Uma unidade de rede mapeada (Z:) só existe na sessão sem elevação:
    # a execução elevada não a enxerga e terminaria sem janela, então o caminho vai como \\servidor\pasta.
    $path = $PSCommandPath

    try {
        if ($path -match '^([A-Za-z]):\\') {
            $root = [string](Get-PSDrive -Name $Matches[1] -PSProvider FileSystem -ErrorAction Stop).DisplayRoot
            if ($root -match '^\\\\[^\\]') { return ($root.TrimEnd('\') + $path.Substring(2)) }
        }
    }
    catch {
        # Sem a unidade, vale o caminho como veio.
    }

    return $path
}

function Start-GuiRelaunch {
    # Abre este script de novo, em STA e sem console, e devolve $true se o Windows abriu a nova execução. -Elevated pede o
    # Administrador (o aviso do Windows; recusado, devolve $false). -Handover: a nova execução espera esta fechar.
    param (
        [string]$Page = "",
        [string]$Action = "",
        [switch]$Elevated,
        [switch]$Handover
    )

    $launchArgs = "-NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File `"$(Get-GuiLaunchScriptPath)`" -Relaunched"
    if ($Handover) { $launchArgs += " -Handover" }
    if ($Page -match '^[a-z]+$') { $launchArgs += " -Page $Page" }
    if ($Action -match '^[a-z0-9][a-z0-9.-]*$') { $launchArgs += " -Action $Action" }

    try {
        $hostExe = (Get-Process -Id $PID).Path

        if ($Elevated) {
            Start-Process -FilePath $hostExe -ArgumentList $launchArgs -Verb RunAs -WindowStyle Hidden -ErrorAction Stop
        }
        else {
            Start-Process -FilePath $hostExe -ArgumentList $launchArgs -WindowStyle Hidden -ErrorAction Stop
        }

        return $true
    }
    catch {
        return $false
    }
}

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$isAdmin = (New-Object Security.Principal.WindowsPrincipal $identity).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$isSta = ([Threading.Thread]::CurrentThread.ApartmentState -eq "STA")

# Com uma janela do WinForge já aberta (a trava de Enter-WinForgeWindowLock, de mesmo nome), esta abertura só passa o
# pedido para ela, mais abaixo: sem o aviso do Windows e sem outra reabertura. Existir sem dar acesso (a trava de uma
# janela elevada, vista daqui sem elevação) também é estar aberta.
$windowOpen = $false

try {
    $existing = [System.Threading.Mutex]::OpenExisting("Local\WinForge.Window.$($identity.User.Value)")
    $existing.Dispose()
    $windowOpen = $true
}
catch [System.UnauthorizedAccessException] {
    $windowOpen = $true
}
catch {
    # Nenhuma janela aberta.
}

if (-not $windowOpen -and ((-not $isAdmin -and -not $Relaunched) -or -not $isSta)) {
    if ($Relaunched) {
        Show-GuiStartupMessage -Text (Get-WinForgeStartupText 'Não foi possível abrir a janela do WinForge. Abra o WinForge de novo.')
        exit 1
    }

    if (-not $isAdmin -and (Start-GuiRelaunch -Page $Page -Action $Action -Elevated)) { exit }

    # Aviso do Windows recusado (ou elevação bloqueada): segue sem Administrador, em STA.
    if (-not $isSta) {
        if (Start-GuiRelaunch -Page $Page -Action $Action) { exit }

        Show-GuiStartupMessage -Text (Get-WinForgeStartupText 'Não foi possível abrir a janela do WinForge. Abra o WinForge de novo.')
        exit 1
    }
}

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

# As dicas (ToolTip) ficam abertas enquanto o mouse está sobre o controle: o padrão do WPF as fecha em 5 segundos, antes de
# dar tempo de ler a descrição inteira de um cartão.
try {
    [System.Windows.Controls.ToolTipService]::ShowDurationProperty.OverrideMetadata([System.Windows.FrameworkElement], (New-Object System.Windows.FrameworkPropertyMetadata ([int]::MaxValue)))
}
catch {
    Write-Verbose "Dicas: $($_.Exception.Message)"
}

# --- Módulos (lista em modules\Modules.psd1) -----------------------------------------------------------
$moduleRoot = Join-Path $PSScriptRoot "modules"
$xamlPath = Join-Path $PSScriptRoot "gui\MainWindow.xaml"
$script:MissingFile = ""

try {
    $manifest = Import-PowerShellDataFile -LiteralPath (Join-Path $moduleRoot "Modules.psd1") -ErrorAction Stop
    $script:ActionModules = @($manifest.Common)

    foreach ($name in ($script:ActionModules + @($manifest.Gui))) {
        $modulePath = Join-Path $moduleRoot "$name.psm1"

        if (-not (Test-Path -LiteralPath $modulePath)) {
            $script:MissingFile = "modules\$name.psm1"
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

    # Uma janela só: se já há uma aberta, o pedido (e a ação, se veio do monitor) vai para ela, e esta abertura termina.
    # A reabertura pedida por uma janela aberta (-Handover) espera por ela, que fecha logo depois de abrir esta.
    if (-not (Enter-WinForgeWindowLock -WaitMilliseconds $(if ($Handover) { 15000 } else { 0 }))) {
        if (Send-WinForgeWindowRequest -Action $Action) { exit 0 }
    }
    elseif ($windowOpen -and ((-not $isAdmin -and -not $Relaunched) -or -not $isSta)) {
        # A janela que estava aberta fechou enquanto esta carregava: faz o que a partida faria (pedir o Administrador e,
        # recusado, reabrir em STA). A nova execução espera esta terminar para ficar com a trava.
        if (-not $isAdmin -and -not $Relaunched -and (Start-GuiRelaunch -Page $Page -Action $Action -Elevated -Handover)) { exit 0 }
        if (-not $isSta -and (Start-GuiRelaunch -Page $Page -Action $Action -Handover)) { exit 0 }
    }

    if (-not (Test-Path -LiteralPath $xamlPath)) {
        $script:MissingFile = "gui\MainWindow.xaml"
        throw (Get-WinForgeStartupText 'Arquivo da janela não encontrado: {0}' "$xamlPath")
    }

    # Os textos fixos da janela vêm traduzidos antes de ela ser montada. Com os efeitos de animação do Windows desligados,
    # as transições dos botões e da chave passam a durar zero (Convert-WinForgeXamlMotion).
    $animate = $true
    try { $animate = [bool][System.Windows.SystemParameters]::ClientAreaAnimation } catch { $animate = $true }
    $xamlText = Convert-WinForgeXamlMotion -Xaml (Get-Content -LiteralPath $xamlPath -Raw -Encoding UTF8) -Animate $animate
    [xml]$xaml = Convert-WinForgeXamlText -Xaml $xamlText
    $window = [System.Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $xaml))
}
catch {
    # Quase sempre é um arquivo que faltou (zip extraído pela metade, antivírus) ou uma pasta com colchetes no nome.
    $extract = (Get-WinForgeStartupText 'Extraia de novo o WinForge.zip inteiro (Extrair tudo), numa pasta sem colchetes no nome, e abra o WinForge da pasta extraída.')

    if (-not [string]::IsNullOrEmpty([string]$script:MissingFile)) {
        Show-GuiStartupMessage -Text (Get-WinForgeStartupText "O WinForge não abriu porque falta um arquivo dele: {0}.`n`n{1} Se o arquivo sumir outra vez, veja se o antivírus o pôs em quarentena." "$($script:MissingFile)" "$extract")
    }
    else {
        Show-GuiStartupMessage -Text (Get-WinForgeStartupText "O WinForge não abriu.`n`n{0} Se continuar, mande este detalhe ao suporte:`n`n{1}" "$extract" "$($_.Exception.Message)")
    }

    exit 1
}

# O processo ganha o nome "WinForge" para a barra de tarefas, com o identificador desta pasta (Get-WinForgeAppId): sem
# isso a janela é agrupada com o PowerShell e mostra o ícone dele. É cosmético: qualquer falha é ignorada.
try { [void](Initialize-WinForgeAppIdentity) } catch { }

# --- Elementos da janela -------------------------------------------------------------------------------
$navPanel = $window.FindName("NavPanel")
$contentPanel = $window.FindName("ContentPanel")
$pageScroll = $window.FindName("PageScroll")
$pageTitle = $window.FindName("PageTitle")
$pageSubtitle = $window.FindName("PageSubtitle")

# O resumo sob o título é lido pelo leitor de tela quando muda (na busca, quantos resultados há); a pergunta de uma ação e
# o desfecho dela são lidos na hora, interrompendo o que estiver sendo lido. .NET 4.7.1 ou mais novo.
try {
    [System.Windows.Automation.AutomationProperties]::SetLiveSetting($pageSubtitle, [System.Windows.Automation.AutomationLiveSetting]::Polite)
    [System.Windows.Automation.AutomationProperties]::SetLiveSetting($window.FindName("PromptLabel"), [System.Windows.Automation.AutomationLiveSetting]::Assertive)
    [System.Windows.Automation.AutomationProperties]::SetLiveSetting($window.FindName("RunStatus"), [System.Windows.Automation.AutomationLiveSetting]::Assertive)
    # A etapa nova do Otimizar é lida sem interromper o que estiver sendo lido.
    [System.Windows.Automation.AutomationProperties]::SetLiveSetting($window.FindName("RunStepText"), [System.Windows.Automation.AutomationLiveSetting]::Polite)
}
catch {
    Write-Verbose "Leitor de tela: $($_.Exception.Message)"
}
$pagesView = $window.FindName("PagesView")
$runView = $window.FindName("RunView")
$runTitle = $window.FindName("RunTitle")
$runStatus = $window.FindName("RunStatus")
$runDot = $window.FindName("RunDot")
$outputBox = $window.FindName("OutputBox")
$stopButton = $window.FindName("StopButton")
$copyButton = $window.FindName("CopyButton")
$backButton = $window.FindName("BackButton")
$footerNav = $window.FindName("FooterNav")
$progressPanel = $window.FindName("ProgressPanel")
$progressText = $window.FindName("ProgressText")
$runProgress = $window.FindName("RunProgress")
$promptBar = $window.FindName("PromptBar")
$promptLabel = $window.FindName("PromptLabel")
$promptTextRow = $window.FindName("PromptTextRow")
$promptInput = $window.FindName("PromptInput")
$promptSend = $window.FindName("PromptSend")
$promptButtons = $window.FindName("PromptButtons")
$promptListScroll = $window.FindName("PromptListScroll")
$promptList = $window.FindName("PromptList")
$promptFilterRow = $window.FindName("PromptFilterRow")
$promptFilter = $window.FindName("PromptFilter")
$promptFilterHint = $window.FindName("PromptFilterHint")
$promptFilterEmpty = $window.FindName("PromptFilterEmpty")
$promptOptionsScroll = $window.FindName("PromptOptionsScroll")
$promptOptions = $window.FindName("PromptOptions")
$searchBox = $window.FindName("SearchBox")
$searchHint = $window.FindName("SearchHint")
$searchKeys = $window.FindName("SearchKeys")
$searchClear = $window.FindName("SearchClear")
$runStrip = $window.FindName("RunStrip")
$runStripTitle = $window.FindName("RunStripTitle")
$runStripText = $window.FindName("RunStripText")
$runStripView = $window.FindName("RunStripView")
$runStripStop = $window.FindName("RunStripStop")
$runStripDismiss = $window.FindName("RunStripDismiss")
$runStripDot = $window.FindName("RunStripDot")
$runElapsed = $window.FindName("RunElapsed")
$resultBanner = $window.FindName("ResultBanner")
$resultIcon = $window.FindName("ResultIcon")
$resultBannerTitle = $window.FindName("ResultBannerTitle")
$resultBannerText = $window.FindName("ResultBannerText")
$resultAction = $window.FindName("ResultAction")
$rerunButton = $window.FindName("RerunButton")
$saveButton = $window.FindName("SaveButton")
$logButton = $window.FindName("LogButton")
$runHero = $window.FindName("RunHero")
$runStepText = $window.FindName("RunStepText")
$activityPanel = $window.FindName("ActivityPanel")
$activitySeparator = $window.FindName("ActivitySeparator")
$activityScroll = $window.FindName("ActivityScroll")
$activityList = $window.FindName("ActivityList")
$detailsCard = $window.FindName("DetailsCard")
$detailsToggle = $window.FindName("DetailsToggle")
$detailsChevron = $window.FindName("DetailsChevron")
$detailsPanel = $window.FindName("DetailsPanel")
$detailsActions = $window.FindName("DetailsActions")
$promptStep = $window.FindName("PromptStep")
$promptContext = $window.FindName("PromptContext")

# --- Estado --------------------------------------------------------------------------------------------
$script:GuiSession = $null
$script:Running = $false
$script:CurrentPage = "home"
$script:ShownPrompt = $null
$script:PromptFilterTexts = @{}

# A saída da ação que ainda não foi desenhada, e quanto desenhar por volta do relógio (Update-GuiRunView).
$script:OutputBacklog = New-Object System.Collections.Queue
$script:OutputBudgetMs = 60
$script:OutputMinItems = 40
$script:ProgressVersionShown = -1
$script:DeferredAction = $null
$script:HomeFacts = @{}
$script:HomeBanner = $null
$script:HomeHealth = $null
$script:HomeFactInfo = @{}
# A hora da leitura e o botão de ler de novo ficam logo abaixo da frase da nota de saúde, que é refeita a cada leitura: o
# texto e se o botão vale ficam aqui, e os controles da nota atual (HomeStampText e HomeRefreshButton) os mostram.
$script:HomeStamp = @{ Text = (Get-WinForgeText 'Lendo o PC...'); CanRefresh = $false; ReadAt = $null }
$script:HomeStampText = $null
$script:HomeRefreshButton = $null
# O botão de ler de novo tinha o foco do teclado quando foi desligado no começo da leitura (Set-GuiHomeStamp).
$script:HomeRefreshFocus = $false
# A frase grande da nota de saúde (o leitor de tela a lê quando a leitura termina).
$script:HomeHeadline = $null
$script:HomeRead = $null
$script:HomeSnapshot = $null
# A última leitura completa mostrada, mesmo vencida (HomeSnapshotSeconds) ou descartada por uma ação: voltar ao Início
# mostra os valores dela na hora, e a leitura nova os troca no lugar, em vez de os cartões voltarem à barra de espera.
$script:HomeLastSnapshot = $null
$script:HomeSnapshotSeconds = 30
# Sobe a cada vez que a leitura guardada é descartada (uma ação terminou, Atualizar): uma leitura que começou antes disso
# termina e aparece, mas não é guardada.
$script:HomeCacheVersion = 0
# As etapas do Início rodam num runspace à parte (New-WinForgeGuiReader), para a janela não parar enquanto o PC é lido.
# HomeReaderOwner é a etapa em andamento (a leitura que a pediu e o nome); HomeReaderWaiting, a leitura cuja próxima
# etapa espera o leitor ficar livre. Se o leitor não abrir, as etapas rodam aqui mesmo, como antes.
$script:HomeReader = $null
$script:HomeReaderOwner = $null
$script:HomeReaderWaiting = $null
$script:HomeReaderBroken = $false
$script:HomeStepTimeoutSeconds = 45
# A compilação do host da janela em segundo plano (veja o WarmupTimer).
$script:WarmupReader = $null
$script:TweaksAdvancedOpen = $false
$script:TaskbarInfo = $null
$script:IsAdmin = $isAdmin
# Aparência: depois de trocar o tema, o foco do teclado volta para a opção escolhida (Set-GuiThemePreference).
$script:AppearanceRefocus = $false
$script:AppearanceFocusTarget = $null
# Idioma: a escolha guardada (Auto, pt, en ou es) e, como na Aparência, o foco que volta para a opção escolhida.
$script:LanguagePreference = "Auto"
$script:LanguageRefocus = $false
$script:LanguageFocusTarget = $null
$script:LastAction = $null
$script:RunUnseen = $false
$script:RunPage = "home"
$script:LastRunView = $null
$script:SearchActive = $false
$script:SearchBack = "home"
$script:SearchFirst = $null
$script:SearchFirstCard = $null
# Os cartões da busca na tela (SearchPanel) e a lista que eles mostram (SearchShownKey): mais uma letra que não muda a lista
# não refaz os cartões. Cada busca mostra no máximo SearchMaxCards cartões (montar um cartão leva alguns milissegundos).
$script:SearchPanel = $null
$script:SearchShownKey = ""
$script:SearchMaxCards = 30
# SearchEnterOpens: o Enter abre o primeiro resultado (falso numa busca corrigida ou parcial com uma ação em primeiro, em
# que ele só seleciona). SearchEnterPending: o Enter foi apertado na caixa e age quando a tecla for solta.
$script:SearchEnterOpens = $false
$script:SearchEnterPending = $false
$script:FocusTweakId = ""
$script:FocusRow = $null
$script:TweaksScrollBack = $null
# A chave de um ajuste muda na própria linha (Start-GuiAction -InPlace): InPlaceRun diz qual linha e de que página, até a
# ação terminar ou a tela de execução abrir. TweakRows guarda as partes de cada linha da página de ajustes desenhada (a
# linha, o estado, a chave e o ajuste lido), e TweaksOverview, a lista lida, de onde sai o resumo do alto.
$script:InPlaceRun = $null
$script:TweakRows = @{}

# A linha que mudou na própria página quando a página foi refeita logo em seguida (o Modo escuro troca o tema da janela):
# o foco do teclado e o aviso ao leitor de tela vão para a linha nova, quando a lista fica pronta (Update-GuiTweaksList).
$script:TweakRefocus = $null
$script:TweaksOverview = @()
$script:ForceClose = $false
$script:StartPage = $Page
# A ação pedida na abertura: as do monitor na bandeja, ou qualquer uma na reabertura pedida pela própria janela
# (-Handover, quando uma ação precisou do Administrador). Outro programa desta conta não escolhe o que a janela roda.
$script:StartAction = $(if ($Action -match '^[a-z0-9][a-z0-9.-]*$' -and ($Handover -or $Action -in @(Get-WinForgeAgentActionIds))) { $Action } else { "" })

# --- Tema --------------------------------------------------------------------------------------------------
# Claro ou escuro, como o Windows (o padrão) ou como a pessoa escolheu em Sobre o WinForge > Aparência. As cores vêm de
# modules\GuiDesign.psm1; Set-GuiTheme (mais abaixo) aplica o tema escolhido antes de a janela aparecer.
$script:ThemeName = ""
$script:ThemePreference = "System"
$script:Theme = Get-WinForgePalette -Name "Light"
$script:LevelColors = Get-WinForgeLevelColors -Theme $script:Theme
# As cores do sistema com o contraste alto ligado (ThemeName = "Contrast"): mudam com o tema de contraste escolhido.
$script:ThemeSignature = ""
# O tamanho do texto escolhido no Windows (1 a 2,25) e a escala de tamanhos já multiplicada por ele (Set-GuiTypography).
$script:TextScale = 1.0
$script:Type = Get-WinForgeTypeRamp
# A entrelinha de cada tamanho da escala (Set-GuiTypography): New-GuiText a usa nos textos que montam.
$script:LineBySize = @{}
$script:FontApplied = $false
# A fonte dos títulos escolhida na abertura (Set-GuiTypography), que os títulos montados pelo script recebem direto.
$script:DisplayFontFamily = $null
$script:ColorMap = Get-WinForgeConsolePalette -Name "Light"
$script:IconCache = @{}
$script:NavParts = @{}
$script:SelectedNav = ""
$script:DetailsOpen = $false
$script:PromptFitTimer = $null
$script:ActivityEntries = New-Object System.Collections.ArrayList
$script:PendingSection = $null
$script:UncoveredLines = 0
$script:SummaryExpanded = $false
# Quem protege o PC, pela última leitura do Início (Active, Other, Off...): com outro antivírus, as ações do Defender
# (Verificar vírus e as outras) saem da página Segurança e da busca. Vem guardado da última vez que o WinForge abriu (lido
# antes da primeira página): sem isso, o botão apareceria por alguns segundos e sumiria quando a leitura terminasse. ""
# enquanto não se sabe.
$script:AntivirusMode = ""
# Se o PC tem bateria, pelo cartão Bateria do Início: $false (num PC de mesa) tira Saúde da bateria da página Diagnóstico
# e da busca. $null enquanto não se sabe: o cartão fica (o menu de texto chega nele de qualquer jeito).
$script:HasBattery = $null
# A grade dos cartões (Update-GuiContentWidth): de 252 a 300 de largura, com 12 entre um e outro.
$script:CardMinWidth = 252.0
$script:CardMaxWidth = 300.0
$script:CardGap = 12.0
$script:CardWidth = 252.0
# A etapa do Otimizar em andamento ("Etapa 3 de 22: ..."): depois da primeira, só uma etapa muda a frase em destaque (um
# título de seção no meio dela, como "Lixeira", não), e a barra mostra o andamento da execução inteira.
$script:RunStepSeen = $false
$script:RunStepIndex = 0
$script:RunStepTotal = 0
# Numa parte do fluxo que não é etapa (Write-WinForgePhase: as perguntas antes da parte automática, o fim do Otimizar),
# a última etapa já terminou: a barra fica com ela inteira, mesmo com a barra de progresso de uma ferramenta nessa parte.
$script:RunStepDone = $false
# O padrão de "Etapa N de M:" no idioma da tela (montado na primeira linha que chega).
$script:RunStepPattern = $null
# As linhas do resumo que, com uma pergunta na tela, foram para dentro do cartão dela (Set-GuiPromptContext).
$script:PromptContextHidden = New-Object System.Collections.ArrayList
# O que estava marcado quando a lista apareceu: numa revisão (o que abre com o Windows, os ajustes), o botão conta as mudanças.
$script:PromptInitialKeys = @()
$script:PromptReview = $false

$script:BrushConverter = New-Object System.Windows.Media.BrushConverter
$script:BrushByHex = @{}

function Set-GuiResource {
    <#
    Guarda um valor num dicionário de recursos do WPF (os da janela, os da mensagem) com o objeto de verdade. Pelo indexador
    ($dicionario[chave] = valor), o PowerShell entrega ao .NET o embrulho (PSObject) de um objeto criado pelo New-Object ou
    recebido como parâmetro, e não o objeto. O WPF recusa o embrulho ao aplicar o recurso ("... is not a valid value for
    property"): um texto que usa esse recurso não entra na tela. Todo recurso posto pelo script passa por aqui.
    #>
    param (
        [Parameter(Mandatory)]$Dictionary,
        [Parameter(Mandatory)]$Key,
        [AllowNull()]$Value
    )

    if ($null -ne $Value) { $Value = $Value.psobject.BaseObject }

    $Dictionary[$Key] = $Value
}

function New-GuiBrush {
    # Um pincel congelado para cada cor, feito uma vez: uma página pede a mesma cor dezenas de vezes, e o pincel congelado
    # é compartilhado sem custo (nenhum controle muda o pincel que recebeu).
    param ([Parameter(Mandatory)][string]$Hex)

    $brush = $script:BrushByHex[$Hex]

    if ($null -eq $brush) {
        $brush = $script:BrushConverter.ConvertFromString($Hex)
        if ($brush.CanFreeze) { $brush.Freeze() }
        $script:BrushByHex[$Hex] = $brush
    }

    return $brush
}

function Show-GuiMessage {
    <#
    Uma mensagem com o desenho do WinForge (New-GuiMessageDialog): Title é a frase em destaque, Text o que vem embaixo, e
    os botões dizem o que fazem (YesText e NoText; sem eles, Sim e Não), no idioma da tela. Default: a resposta que começa
    com o foco, a do Enter. Nas perguntas Sim/Não é Não, salvo quando a pessoa acabou de pedir aquilo (reabrir como
    Administrador): um Enter a mais nunca interrompe nem apaga nada. Danger: o Sim interrompe ou perde algo (o botão de
    perigo). YesIcon: o ícone do botão do Sim (o escudo do Administrador). O Esc e o X da barra de título respondem Não
    (ou OK, numa mensagem).
    Se a janela da mensagem não abrir, vale a caixa de mensagem do Windows (Show-GuiSystemMessage), como antes. -System
    vai direto a ela: é a da falha da própria janela, que não pode depender da janela para aparecer.
    Devolve "OK", "Yes" ou "No".
    #>
    param (
        [Parameter(Mandatory)][AllowEmptyString()][string]$Text,
        [string]$Title = "",
        [ValidateSet("OK", "YesNo")]
        [string]$Buttons = "OK",
        [ValidateSet("Information", "Warning", "Error", "Question")]
        [string]$Icon = "Information",
        [ValidateSet("Yes", "No")]
        [string]$Default = "No",
        [string]$YesText = "",
        [string]$NoText = "",
        [string]$YesIcon = "",
        [switch]$Danger,
        [switch]$System
    )

    if (-not $System) {
        $dialog = $null

        try {
            $plan = Get-WinForgeMessagePlan -Buttons $Buttons -Icon $Icon -Default $Default -YesText $YesText -NoText $NoText -YesIcon $YesIcon -Danger:$Danger
            $dialog = New-GuiMessageDialog -Plan $plan -Title $Title -Text $Text
            [void]$dialog.ShowDialog()

            return [string]$dialog.Tag.Answer
        }
        catch {
            Write-Verbose "Mensagem da janela: $($_.Exception.Message)"

            # Já respondida (o erro veio depois): vale a resposta. Senão, a mesma pergunta vai pela caixa do Windows.
            if ($null -ne $dialog -and $dialog.Tag -is [hashtable]) {
                if ($dialog.Tag.Answered) { return [string]$dialog.Tag.Answer }

                try { $dialog.Close() } catch { Write-Verbose "Mensagem da janela: $($_.Exception.Message)" }
            }
        }
    }

    return (Show-GuiSystemMessage -Text $Text -Title $Title -Buttons $Buttons -Icon $Icon -Default $Default)
}

function Show-GuiSystemMessage {
    # A caixa de mensagem do Windows, com a frase em destaque no alto do texto: a reserva de Show-GuiMessage. Os botões
    # vêm no idioma do Windows.
    param (
        [Parameter(Mandatory)][AllowEmptyString()][string]$Text,
        [string]$Title = "",
        [string]$Buttons = "OK",
        [string]$Icon = "Information",
        [string]$Default = "No"
    )

    $body = $(if ([string]::IsNullOrWhiteSpace($Title)) { $Text } elseif ([string]::IsNullOrEmpty($Text)) { $Title } else { "$Title`n`n$Text" })
    $defaultResult = $(if ($Buttons -eq "OK") { "OK" } else { $Default })

    try {
        return [string][System.Windows.MessageBox]::Show($window, $body, "WinForge", $Buttons, $Icon, $defaultResult)
    }
    catch {
        # Janela já fechada ou ainda não exibida: mostra a mensagem sem dono.
        return [string][System.Windows.MessageBox]::Show($body, "WinForge", $Buttons, $Icon, $defaultResult)
    }
}

function New-GuiMessageDialog {
    <#
    A janela de uma mensagem (Show-GuiMessage), no desenho das caixas de diálogo do Windows 11: o ícone, a frase em
    destaque e o texto no fundo do cartão; os botões numa faixa embaixo, no fundo da janela, em duas colunas de mesma
    largura. Plan: Get-WinForgeMessagePlan. Usa os estilos, as cores, a fonte e os tamanhos da janela do WinForge (o tema,
    o contraste alto e o tamanho do texto do Windows). Tag guarda a resposta (Answer), se a pessoa respondeu (Answered), a
    do Esc (Cancel), o texto que o Ctrl+C copia, como na caixa do Windows (Copy), e o texto para o leitor de tela (Message).
    #>
    param (
        [Parameter(Mandatory)]$Plan,
        [string]$Title = "",
        [Parameter(Mandatory)][AllowEmptyString()][string]$Text
    )

    # Qualquer erro na montagem para tudo: Show-GuiMessage cai na caixa do Windows, e nunca aparece uma janela pela metade.
    $ErrorActionPreference = "Stop"
    $scale = [double]$script:TextScale
    $area = [System.Windows.SystemParameters]::WorkArea

    $dialog = New-Object System.Windows.Window
    $dialog.Title = "WinForge"
    $dialog.SizeToContent = "WidthAndHeight"
    $dialog.ResizeMode = "NoResize"
    $dialog.ShowInTaskbar = $false
    $dialog.UseLayoutRounding = $true
    $dialog.SnapsToDevicePixels = $true
    $dialog.MinWidth = [Math]::Min(400.0 * $scale, [Math]::Max(240.0, $area.Width - 40.0))
    [System.Windows.Media.TextOptions]::SetTextFormattingMode($dialog, [System.Windows.Media.TextFormattingMode]::Display)

    # Os estilos dos botões pegam as cores e os tamanhos dos recursos de quem os usa: a mensagem recebe os da janela, que
    # já estão no tema e no tamanho do texto de agora (pincéis, tamanhos, a fonte e os estilos, todos compartilháveis).
    foreach ($key in @($window.Resources.Keys)) { Set-GuiResource -Dictionary $dialog.Resources -Key $key -Value $window.Resources[$key] }

    $dialog.FontFamily = $window.Resources["UiFont"]
    $dialog.FontSize = [double]$script:Type.Body
    $dialog.Background = New-GuiBrush $script:Theme.Card
    $dialog.Foreground = New-GuiBrush $script:Theme.Text

    try {
        if ($null -ne $window.Icon) { $dialog.Icon = $window.Icon }
    }
    catch {
        Write-Verbose "Ícone da mensagem: $($_.Exception.Message)"
    }

    # Com a janela aberta, a mensagem é dela e aparece no meio dela; minimizada, ela volta antes (a mensagem é sobre ela).
    # Sem a janela na tela (ainda abrindo), a mensagem aparece sozinha, no meio da tela e na barra de tarefas.
    $shown = $false
    try { $shown = ($window.IsVisible -and $null -ne [System.Windows.PresentationSource]::FromVisual($window)) } catch { $shown = $false }

    if ($shown) {
        if ($window.WindowState -eq [System.Windows.WindowState]::Minimized) { [System.Windows.SystemCommands]::RestoreWindow($window) }
        $dialog.Owner = $window
        $dialog.WindowStartupLocation = "CenterOwner"
    }
    else {
        $dialog.WindowStartupLocation = "CenterScreen"
        $dialog.ShowInTaskbar = $true
    }

    $root = New-Object System.Windows.Controls.DockPanel

    # A faixa dos botões.
    $footer = New-Object System.Windows.Controls.Border
    $footer.Background = New-GuiBrush $script:Theme.Window
    $footer.BorderBrush = New-GuiBrush $script:Theme.Line
    $footer.BorderThickness = New-Object System.Windows.Thickness (0, 1, 0, 0)
    $footer.Padding = New-Object System.Windows.Thickness 24
    Set-GuiDock -Element $footer -Side "Bottom"

    $grid = New-Object System.Windows.Controls.Primitives.UniformGrid
    $grid.Rows = 1
    $grid.Columns = 2
    $grid.Margin = New-Object System.Windows.Thickness (-4, 0, -4, 0)
    # O OK sozinho fica na coluna da direita, como o Fechar das caixas de diálogo do Windows 11.
    if (@($Plan.Buttons).Count -eq 1) { $grid.FirstColumn = 1 }

    $focus = $null

    foreach ($item in @($Plan.Buttons)) {
        $button = New-GuiButton -Text ([string]$item.Text) -Kind ([string]$item.Kind) -Icon ([string]$item.Icon) -Tag ([string]$item.Answer)
        $button.Margin = New-Object System.Windows.Thickness (4, 0, 4, 0)
        $button.MinHeight = [Math]::Round(32.0 * $scale)
        $button.HorizontalAlignment = "Stretch"

        $button.Add_Click({
            param ($sender, $eventArgs)

            $owner = [System.Windows.Window]::GetWindow($sender)
            $owner.Tag.Answer = [string]$sender.Tag
            $owner.Tag.Answered = $true
            $owner.Close()
        })

        [void]$grid.Children.Add($button)
        if ([string]$item.Answer -eq [string]$Plan.DefaultAnswer) { $focus = $button }
    }

    $footer.Child = $grid
    [void]$root.Children.Add($footer)

    # O ícone, a frase em destaque e o texto. O texto longo (um detalhe técnico) rola, sem passar da metade da tela.
    $body = New-Object System.Windows.Controls.DockPanel
    $body.Margin = New-Object System.Windows.Thickness 24

    $iconSize = [Math]::Round(24.0 * $scale)
    $firstLine = $(if ($Title) { $script:LineBySize["$($script:Type.Subtitle)"] } else { $script:LineBySize["$($script:Type.Body)"] })
    $iconTop = $(if ($null -ne $firstLine) { [Math]::Max(0.0, ([double]$firstLine - $iconSize) / 2.0) } else { 0.0 })

    $glyph = New-GuiIcon -Name ([string]$Plan.Icon) -Size $iconSize -Color $script:Theme[[string]$Plan.IconColor]
    $glyph.VerticalAlignment = "Top"
    $glyph.Margin = New-Object System.Windows.Thickness (0, $iconTop, 12, 0)
    Set-GuiDock -Element $glyph -Side "Left"
    [void]$body.Children.Add($glyph)

    $stack = New-Object System.Windows.Controls.StackPanel
    $stack.MaxWidth = [Math]::Max(200.0, [Math]::Min(440.0 * $scale, $area.Width - 160.0))

    if ($Title) { [void]$stack.Children.Add((New-GuiText -Text $Title -Size $script:Type.Subtitle -Bold $true)) }

    $message = New-GuiText -Text $Text -Size $script:Type.Body
    $scroll = New-Object System.Windows.Controls.ScrollViewer
    $scroll.VerticalScrollBarVisibility = "Auto"
    $scroll.HorizontalScrollBarVisibility = "Disabled"
    $scroll.Focusable = $false
    $scroll.MaxHeight = [Math]::Max(120.0, $area.Height * 0.5)
    $scroll.Content = $message
    if ($Title) { $scroll.Margin = New-Object System.Windows.Thickness (0, 12, 0, 0) }
    # Sem texto (um erro sem descrição), fica só a frase em destaque.
    if (-not [string]::IsNullOrEmpty($Text) -or -not $Title) { [void]$stack.Children.Add($scroll) }

    [void]$body.Children.Add($stack)
    [void]$root.Children.Add($body)
    $dialog.Content = $root

    $dialog.Tag = @{
        Answer   = [string]$Plan.CancelAnswer
        Answered = $false
        Cancel   = [string]$Plan.CancelAnswer
        Copy     = $(if ($Title -and $Text) { "$Title`r`n`r`n$Text" } elseif ($Title) { $Title } else { $Text })
        Message  = $message
    }

    # O leitor de tela: o nome da janela é a frase em destaque, e o texto é lido assim que ela aparece.
    Set-GuiAutomationName -Element $dialog -Name $(if ($Title) { $Title } else { "WinForge" })
    [System.Windows.Automation.AutomationProperties]::SetHelpText($dialog, $Text)

    try {
        [System.Windows.Automation.AutomationProperties]::SetLiveSetting($message, [System.Windows.Automation.AutomationLiveSetting]::Assertive)
    }
    catch {
        Write-Verbose "Leitor de tela: $($_.Exception.Message)"
    }

    if ($null -ne $focus) { [System.Windows.Input.FocusManager]::SetFocusedElement($dialog, $focus) }

    # A barra de título na cor do tema, como a da janela.
    $dialog.Add_SourceInitialized({
        param ($sender, $eventArgs)
        Set-GuiTitleBarTheme -Target $sender
    })

    $dialog.Add_ContentRendered({
        param ($sender, $eventArgs)
        Send-GuiAnnouncement -Element $sender.Tag.Message
    })

    # Esc: a resposta segura (o Não, ou o OK). Ctrl+C: copia a mensagem, como na caixa do Windows. O Enter fica com o botão
    # que tem o foco, que começa no padrão.
    $dialog.Add_PreviewKeyDown({
        param ($sender, $eventArgs)

        if ($eventArgs.Key -eq [System.Windows.Input.Key]::Escape) {
            $eventArgs.Handled = $true
            $sender.Tag.Answer = $sender.Tag.Cancel
            $sender.Tag.Answered = $true
            $sender.Close()
            return
        }

        if ($eventArgs.Key -eq [System.Windows.Input.Key]::C -and ([System.Windows.Input.Keyboard]::Modifiers -band [System.Windows.Input.ModifierKeys]::Control) -ne 0) {
            $eventArgs.Handled = $true

            try {
                [System.Windows.Clipboard]::SetText([string]$sender.Tag.Copy)
            }
            catch {
                Write-Verbose "Copiar a mensagem: $($_.Exception.Message)"
            }
        }
    })

    return $dialog
}

function Set-GuiDisplayFont {
    <#
    Põe a fonte dos títulos (a que Set-GuiTypography escolheu) num texto montado pelo script, direto na propriedade, e o
    desenho ideal da letra, feito para os tamanhos grandes. Direto, e não pelo recurso: o recurso só é procurado quando o
    texto entra na tela, e um valor que o WPF recusasse ali tiraria da tela a parte inteira, sem aviso (a R39). Sem a
    fonte escolhida (a janela ainda abrindo, ou a escolha que falhou), o texto fica com a fonte da janela.
    #>
    param ([Parameter(Mandatory)]$Element)

    if ($null -ne $script:DisplayFontFamily) {
        try { $Element.FontFamily = $script:DisplayFontFamily } catch { Write-Verbose "Fonte dos títulos: $($_.Exception.Message)" }
    }

    try { [System.Windows.Media.TextOptions]::SetTextFormattingMode($Element, "Ideal") } catch { Write-Verbose "Texto: $($_.Exception.Message)" }
}

function New-GuiText {
    # Display: um título em negrito na fonte dos títulos (Set-GuiDisplayFont), como o nome da página: a frase e os
    # números do Início, os títulos das partes da página.
    param (
        [string]$Text,
        [double]$Size = $script:Type.Caption,
        [string]$Color = $script:Theme.Text,
        [bool]$Bold = $false,
        [switch]$Display
    )

    $block = New-Object System.Windows.Controls.TextBlock
    $block.Text = $Text
    $block.FontSize = $Size
    $block.Foreground = New-GuiBrush $Color
    $block.TextWrapping = "Wrap"

    # A entrelinha da escala (14/20, 20/28...): pesa nos textos que quebram linha. Fora da escala, a natural da fonte.
    $line = $script:LineBySize["$Size"]
    if ($null -ne $line) { $block.LineHeight = [double]$line }

    if ($Display) {
        $block.FontWeight = [System.Windows.FontWeights]::Bold
        Set-GuiDisplayFont -Element $block
    }
    elseif ($Bold) {
        $block.FontWeight = [System.Windows.FontWeights]::SemiBold
    }

    return $block
}

function New-GuiValueBox {
    # Um texto numa linha que diminui até caber na largura que tiver, sem cortar nem quebrar (Viewbox só para baixo): a
    # frase da nota de saúde, a nota, o valor dos cartões do Início e os números do histórico. Com espaço, fica no tamanho
    # dele.
    param ([Parameter(Mandatory)]$Text)

    $Text.TextWrapping = "NoWrap"

    $box = New-Object System.Windows.Controls.Viewbox
    $box.Stretch = "Uniform"
    $box.StretchDirection = "DownOnly"
    $box.HorizontalAlignment = "Left"
    $box.Child = $Text

    return $box
}

function New-GuiOutlinedBorder {
    # Moldura arredondada com contorno, como as dos estilos do XAML: o fundo numa moldura e o contorno noutra, dentro
    # dela. Numa moldura só, o WPF pinta o fundo depois do contorno, e a borda suavizada do fundo cobre metade do contorno
    # nas quinas, que ficavam finas e falhadas. O raio do fundo é o do contorno mais meia espessura (as curvas de fora
    # coincidem). Devolve a moldura do fundo; a do contorno é o Child dela, e o conteúdo vai no Child do contorno
    # (Set-GuiPanelContent). Cor vazia = transparente.
    param (
        [string]$Background = "",
        [string]$BorderColor = "",
        [double]$Radius = 8,
        [double]$Thickness = 1,
        $Padding = $null
    )

    $fill = New-Object System.Windows.Controls.Border
    $fill.Background = $(if ($Background) { New-GuiBrush $Background } else { [System.Windows.Media.Brushes]::Transparent })
    $fill.CornerRadius = New-Object System.Windows.CornerRadius ($Radius + $Thickness / 2)

    $line = New-Object System.Windows.Controls.Border
    $line.BorderBrush = $(if ($BorderColor) { New-GuiBrush $BorderColor } else { [System.Windows.Media.Brushes]::Transparent })
    $line.BorderThickness = New-Object System.Windows.Thickness $Thickness
    $line.CornerRadius = New-Object System.Windows.CornerRadius $Radius
    if ($null -ne $Padding) { $line.Padding = $Padding }

    $fill.Child = $line

    return $fill
}

function Set-GuiPanelContent {
    # O conteúdo de uma moldura de New-GuiOutlinedBorder (dentro do contorno, com o espaçamento dele).
    param (
        [Parameter(Mandatory)]$Panel,
        $Content
    )

    $Panel.Child.Child = $Content
}

function Set-GuiPanelOutline {
    # A cor do contorno de uma moldura de New-GuiOutlinedBorder.
    param (
        [Parameter(Mandatory)]$Panel,
        [Parameter(Mandatory)][string]$Color
    )

    $Panel.Child.BorderBrush = New-GuiBrush $Color
}

function New-GuiPanelBorder {
    # Moldura arredondada usada por cartões de informação, grupos de ajustes e avisos (New-GuiOutlinedBorder).
    param (
        [string]$Background = $script:Theme.Card,
        [string]$BorderColor = $script:Theme.Line,
        [double]$Radius = 8,
        $Padding = $null,
        $Content = $null
    )

    if ($null -eq $Padding) { $Padding = New-Object System.Windows.Thickness (18, 14, 18, 14) }

    $border = New-GuiOutlinedBorder -Background $Background -BorderColor $BorderColor -Radius $Radius -Padding $Padding
    if ($null -ne $Content) { Set-GuiPanelContent -Panel $border -Content $Content }

    return $border
}

function New-GuiButton {
    # Botões montados pelo script. Primary = a ação recomendada (cor de destaque); Secondary = os demais; Danger = parar;
    # Ghost = discreto, sem contorno. Com Icon, o desenho vem antes do texto.
    param (
        [Parameter(Mandatory)][string]$Text,
        [ValidateSet("Secondary", "Primary", "Danger", "Ghost")]
        [string]$Kind = "Secondary",
        [string]$Icon = "",
        $Tag = $null
    )

    $button = New-Object System.Windows.Controls.Button

    switch ($Kind) {
        "Primary" { $button.Style = $window.FindResource("PrimaryButton") }
        "Danger" { $button.Style = $window.FindResource("DangerButton") }
        "Ghost" { $button.Style = $window.FindResource("GhostButton") }
        default { $button.Style = $window.FindResource("PillButton") }
    }

    $button.Tag = $Tag

    if ([string]::IsNullOrEmpty($Icon)) {
        $button.Content = $Text
        return $button
    }

    $iconColor = $script:Theme.Text

    switch ($Kind) {
        "Primary" { $iconColor = $script:Theme.OnAccent }
        "Danger" { $iconColor = $script:Theme.Danger }
        "Ghost" { $iconColor = $script:Theme.Muted }
    }

    $row = New-Object System.Windows.Controls.StackPanel
    $row.Orientation = "Horizontal"

    $glyph = New-GuiIcon -Name $Icon -Size 15 -Color $iconColor
    $glyph.Margin = New-Object System.Windows.Thickness (0, 0, 7, 0)
    [void]$row.Children.Add($glyph)

    # Sem cor própria: o texto herda a do botão (branco no principal, a do tema nos outros). Um pixel acima: a letra do
    # Segoe UI fica abaixo do meio da linha, e o texto parecia mais baixo que o ícone e que o meio do botão.
    $label = New-Object System.Windows.Controls.TextBlock
    $label.Text = $Text
    $label.VerticalAlignment = "Center"
    $label.Margin = New-Object System.Windows.Thickness (0, -1, 0, 1)
    [void]$row.Children.Add($label)

    # O desenho do ícone tem uma folga de uns 2 pixels à esquerda (o traço não encosta na caixa dele): o lado do ícone
    # perde esses 2 pixels de espaçamento, e o conteúdo fica no meio do botão (antes parecia puxado para a direita).
    try {
        $padding = $button.Padding
        $button.Padding = New-Object System.Windows.Thickness ([Math]::Max(0.0, [double]$padding.Left - 2.0), $padding.Top, $padding.Right, $padding.Bottom)
    }
    catch {
        Write-Verbose "Espaçamento do botão: $($_.Exception.Message)"
    }

    $button.Content = $row
    Set-GuiAutomationName -Element $button -Name $Text

    return $button
}

function Set-GuiAutomationName {
    # O nome que o leitor de tela fala para o controle.
    param (
        [Parameter(Mandatory)]$Element,
        [Parameter(Mandatory)][string]$Name
    )

    [System.Windows.Automation.AutomationProperties]::SetName($Element, $Name)
}

function Send-GuiAnnouncement {
    # Pede ao leitor de tela que leia de novo o texto de um controle marcado como "ao vivo" (o resumo da busca, com quantos
    # resultados há). Precisa do .NET 4.7.1 ou mais novo; sem ele, nada é lido e a janela segue normalmente.
    param ([Parameter(Mandatory)]$Element)

    try {
        $peer = [System.Windows.Automation.Peers.UIElementAutomationPeer]::CreatePeerForElement($Element)
        if ($null -ne $peer) { $peer.RaiseAutomationEvent([System.Windows.Automation.Peers.AutomationEvents]::LiveRegionChanged) }
    }
    catch {
        Write-Verbose "Leitor de tela: $($_.Exception.Message)"
    }
}

function Set-GuiDock {
    # Encosta o controle em um lado de um DockPanel (Left, Right, Top ou Bottom).
    param (
        [Parameter(Mandatory)]$Element,
        [Parameter(Mandatory)][string]$Side
    )

    [System.Windows.Controls.DockPanel]::SetDock($Element, $Side)
}

function New-GuiIcon {
    # Um ícone de traço (GuiDesign.psm1) no tamanho e na cor pedidos. O desenho de cada ícone é lido e congelado uma vez.
    # O traço tem 1,5 pixel na tela em qualquer tamanho (o desenho é de 24 e a Viewbox o escala): ícones pequenos não
    # ficam finos nem os grandes, grossos. Stroke só para um traço diferente.
    param (
        [Parameter(Mandatory)][string]$Name,
        [double]$Size = 18,
        [string]$Color = $script:Theme.Muted,
        [double]$Stroke = 0
    )

    if ($Stroke -le 0) { $Stroke = 36 / $Size }

    if (-not $script:IconCache.ContainsKey($Name)) {
        $geometry = [System.Windows.Media.Geometry]::Parse((Get-WinForgeIconData -Name $Name))
        $geometry.Freeze()
        $script:IconCache[$Name] = $geometry
    }

    $path = New-Object System.Windows.Shapes.Path
    $path.Data = $script:IconCache[$Name]
    $path.Stroke = New-GuiBrush $Color
    $path.StrokeThickness = $Stroke
    $path.StrokeStartLineCap = "Round"
    $path.StrokeEndLineCap = "Round"
    $path.StrokeLineJoin = "Round"

    $canvas = New-Object System.Windows.Controls.Canvas
    $canvas.Width = 24
    $canvas.Height = 24
    [void]$canvas.Children.Add($path)

    $box = New-Object System.Windows.Controls.Viewbox
    $box.Width = $Size
    $box.Height = $Size
    $box.Child = $canvas
    $box.IsHitTestVisible = $false
    $box.VerticalAlignment = "Center"

    return $box
}

function Set-GuiIconColor {
    # Troca a cor de um ícone já montado por New-GuiIcon.
    param (
        [Parameter(Mandatory)]$Icon,
        [Parameter(Mandatory)][string]$Color
    )

    try {
        $Icon.Child.Children[0].Stroke = New-GuiBrush $Color
    }
    catch {
        # Cosmético.
    }
}

function New-GuiChip {
    # Etiqueta pequena e arredondada ("Recomendado").
    param ([Parameter(Mandatory)][string]$Text)

    $chip = New-Object System.Windows.Controls.Border
    $chip.Background = New-GuiBrush $script:Theme.AccentCard
    $chip.CornerRadius = New-Object System.Windows.CornerRadius 4
    $chip.Padding = New-Object System.Windows.Thickness (8, 3, 8, 3)
    $chip.VerticalAlignment = "Top"
    $chip.Child = New-GuiText -Text $Text -Size $script:Type.Caption -Color $script:Theme.AccentText -Bold $true

    return $chip
}

function New-GuiKeyChip {
    # Uma tecla desenhada como a "Ctrl K" da caixa de busca: o "Enter" no resultado que o Enter abre.
    param ([Parameter(Mandatory)][string]$Text)

    $chip = New-GuiOutlinedBorder -Background $script:Theme.Card -BorderColor $script:Theme.Line -Radius 4 -Padding (New-Object System.Windows.Thickness (6, 1, 6, 1))
    $chip.VerticalAlignment = "Top"
    Set-GuiPanelContent -Panel $chip -Content (New-GuiText -Text $Text -Size $script:Type.Caption -Color $script:Theme.Dim)

    return $chip
}

function New-GuiSectionHeading {
    # Título de uma parte do Início ("Seu PC", "Histórico neste PC"), em negrito, no tamanho de subtítulo.
    param ([Parameter(Mandatory)][string]$Text)

    $heading = New-GuiText -Text $Text -Size $script:Type.Subtitle -Display
    $heading.Margin = New-Object System.Windows.Thickness (0, 30, 12, 14)
    Set-GuiAutomationName -Element $heading -Name (Get-WinForgeText 'Seção: {0}' "$Text")

    return $heading
}

function New-GuiGroupHeading {
    # Título de uma lista dentro de uma página ("Liberar espaço"), como os das Configurações do Windows: o texto em
    # seminegrito, na cor do texto. O primeiro não precisa do espaço que separa uma seção da anterior.
    param ([Parameter(Mandatory)][string]$Text, [bool]$First = $false)

    $heading = New-GuiText -Text $Text -Size $script:Type.Body -Bold $true
    $heading.Margin = New-Object System.Windows.Thickness (0, $(if ($First) { 2 } else { 14 }), 0, 10)
    Set-GuiAutomationName -Element $heading -Name (Get-WinForgeText 'Seção: {0}' "$Text")

    return $heading
}

function New-GuiNotice {
    # Aviso em destaque no alto de uma página (amarelo), com o ícone de atenção.
    param ([Parameter(Mandatory)][string]$Text)

    $banner = New-GuiPanelBorder -Background $script:LevelColors.Warn.Back -BorderColor $script:LevelColors.Warn.Line -Radius 8 -Padding (New-Object System.Windows.Thickness (14, 10, 14, 10))
    $banner.Margin = New-Object System.Windows.Thickness (0, 0, 12, 14)

    $row = New-Object System.Windows.Controls.DockPanel
    $glyph = New-GuiIcon -Name "warning" -Size 18 -Color $script:LevelColors.Warn.Dot
    $glyph.Margin = New-Object System.Windows.Thickness (0, 0, 10, 0)
    $glyph.VerticalAlignment = "Top"
    Set-GuiDock -Element $glyph -Side "Left"
    [void]$row.Children.Add($glyph)
    [void]$row.Children.Add((New-GuiText -Size $script:Type.Body -Color $script:Theme.Text -Text $Text))

    Set-GuiPanelContent -Panel $banner -Content $row

    return $banner
}

# --- Barra de título escura, ícone e barra de tarefas ------------------------------------------------------
if (-not ("WinForge.NativeWindow" -as [type])) {
    # C# 5 (Windows PowerShell 5.1): sem recursos mais novos da linguagem.
    Add-Type -Namespace WinForge -Name NativeWindow -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("dwmapi.dll")]
public static extern int DwmSetWindowAttribute(System.IntPtr hwnd, int attribute, ref int value, int size);

[System.Runtime.InteropServices.StructLayout(System.Runtime.InteropServices.LayoutKind.Sequential)]
public struct FlashInfo
{
    public uint cbSize;
    public System.IntPtr hwnd;
    public uint dwFlags;
    public uint uCount;
    public uint dwTimeout;
}

[System.Runtime.InteropServices.DllImport("user32.dll")]
public static extern bool FlashWindowEx(ref FlashInfo info);
'@
}

function Set-GuiTitleBarTheme {
    # A barra de título do Windows na cor da janela (Windows 11) e com o modo claro ou escuro (Windows 10 e 11).
    param ([System.Windows.Window]$Target)

    try {
        $handle = (New-Object System.Windows.Interop.WindowInteropHelper $Target).Handle

        if ($handle -eq [IntPtr]::Zero) { return }

        $dark = $(if ($script:ThemeName -eq "Dark" -or ($script:ThemeName -eq "Contrast" -and (Test-GuiDarkColor -Hex $script:Theme.Window))) { 1 } else { 0 })

        # 20 = modo escuro (Windows 10 20H1+ e 11); 19 = valor usado por builds anteriores do Windows 10.
        if ([WinForge.NativeWindow]::DwmSetWindowAttribute($handle, 20, [ref]$dark, 4) -ne 0) {
            [void][WinForge.NativeWindow]::DwmSetWindowAttribute($handle, 19, [ref]$dark, 4)
        }

        # Windows 11 (build 22000+): cor exata da barra, do texto e da borda. COLORREF = 0x00BBGGRR. Com o contraste alto,
        # a barra volta às cores do Windows (DWMWA_COLOR_DEFAULT, 0xFFFFFFFF).
        if ($script:ThemeName -eq "Contrast") {
            $caption = -1
            $text = -1
            $border = -1
        }
        else {
            $caption = ConvertTo-WinForgeColorRef -Hex $script:Theme.Window
            $text = ConvertTo-WinForgeColorRef -Hex $script:Theme.Text
            # O contorno é translúcido: a borda da janela usa o cinza que ele dá sobre o cartão.
            $border = ConvertTo-WinForgeColorRef -Hex (ConvertTo-WinForgeOpaqueColor -Hex $script:Theme.Line -Background $script:Theme.Card)
        }
        [void][WinForge.NativeWindow]::DwmSetWindowAttribute($handle, 35, [ref]$caption, 4)
        [void][WinForge.NativeWindow]::DwmSetWindowAttribute($handle, 36, [ref]$text, 4)
        [void][WinForge.NativeWindow]::DwmSetWindowAttribute($handle, 34, [ref]$border, 4)
    }
    catch {
        # Cosmético: em versões sem suporte a barra continua com o tema padrão do Windows.
    }
}

function Test-GuiDarkColor {
    # Uma cor "#RRGGBB" escura (a barra de título do contraste alto preto fica escura).
    param ([Parameter(Mandatory)][string]$Hex)

    if ($Hex -notmatch '^#([0-9A-Fa-f]{2})([0-9A-Fa-f]{2})([0-9A-Fa-f]{2})$') { return $false }

    $r = [Convert]::ToInt32($Matches[1], 16)
    $g = [Convert]::ToInt32($Matches[2], 16)
    $b = [Convert]::ToInt32($Matches[3], 16)

    return ((0.299 * $r + 0.587 * $g + 0.114 * $b) -lt 128)
}

function Get-GuiSystemTheme {
    # O tema dos aplicativos no Windows (Configurações > Personalização > Cores). Sem a informação, vale o claro.
    try {
        $value = Get-ItemPropertyValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "AppsUseLightTheme" -ErrorAction Stop

        if ([int]$value -eq 0) { return "Dark" }
    }
    catch {
        # Chave ausente (Windows antigo ou política): fica o claro.
    }

    return "Light"
}

function Test-GuiHighContrast {
    # O contraste alto do Windows (Configurações > Acessibilidade > Temas de contraste) está ligado.
    try { return [bool][System.Windows.SystemParameters]::HighContrast } catch { return $false }
}

function Get-GuiSystemColors {
    # As cores do sistema que a janela usa com o contraste alto ligado (Get-WinForgeHighContrastPalette), em "#RRGGBB".
    $toHex = { param ($color) "#{0:X2}{1:X2}{2:X2}" -f $color.R, $color.G, $color.B }

    return @{
        Window        = (& $toHex ([System.Windows.SystemColors]::WindowColor))
        WindowText    = (& $toHex ([System.Windows.SystemColors]::WindowTextColor))
        Highlight     = (& $toHex ([System.Windows.SystemColors]::HighlightColor))
        HighlightText = (& $toHex ([System.Windows.SystemColors]::HighlightTextColor))
        HotTrack      = (& $toHex ([System.Windows.SystemColors]::HotTrackColor))
    }
}

function Get-GuiThemeState {
    # O tema que vale agora: "Contrast" com o contraste alto do Windows ligado (Signature: as cores do sistema, que mudam
    # com o tema de contraste escolhido); fora dele, o escolhido pela pessoa ou o do Windows.
    if (Test-GuiHighContrast) {
        $colors = Get-GuiSystemColors
        return [PSCustomObject]@{ Name = "Contrast"; Signature = (@($colors.Keys | Sort-Object | ForEach-Object { "$_=$($colors[$_])" }) -join ";"); Colors = $colors }
    }

    return [PSCustomObject]@{ Name = (Resolve-WinForgeTheme -Preference $script:ThemePreference -SystemTheme (Get-GuiSystemTheme)); Signature = ""; Colors = $null }
}

function Set-GuiTheme {
    # Aplica um tema: as cores que o script usa ao montar controles, as do console nos detalhes técnicos e os pincéis do
    # XAML (que mudam na hora, por serem DynamicResource). "Contrast" usa as cores do sistema (Colors, de Get-GuiSystemColors).
    param (
        [ValidateSet("Light", "Dark", "Contrast")][string]$Name,
        [hashtable]$Colors = $null,
        [string]$Signature = ""
    )

    $script:ThemeName = $Name
    $script:ThemeSignature = $Signature

    if ($Name -eq "Contrast") {
        if ($null -eq $Colors) { $Colors = Get-GuiSystemColors }
        $script:Theme = Get-WinForgeHighContrastPalette -Colors $Colors
        $script:ColorMap = Get-WinForgeHighContrastConsolePalette -Text $script:Theme.Text
    }
    else {
        $script:Theme = Get-WinForgePalette -Name $Name
        $script:ColorMap = Get-WinForgeConsolePalette -Name $Name
    }

    $script:LevelColors = Get-WinForgeLevelColors -Theme $script:Theme
    $script:BrushCache = @{}

    foreach ($key in @($script:Theme.Keys)) {
        Set-GuiResource -Dictionary $window.Resources -Key "${key}Brush" -Value (New-GuiBrush $script:Theme[$key])
    }

    Set-GuiTitleBarTheme -Target $window
}

function Update-GuiTheme {
    # Confere o tema (o contraste alto do Windows, a escolha da pessoa ou o tema do Windows) e o tamanho do texto do Windows
    # e, se algum mudou, aplica e redesenha o que está na tela. Devolve verdadeiro quando mudou.
    $state = Get-GuiThemeState
    $typeChanged = Set-GuiTypography

    if ($state.Name -eq $script:ThemeName -and $state.Signature -eq $script:ThemeSignature -and -not $typeChanged) { return $false }

    Set-GuiTheme -Name $state.Name -Colors $state.Colors -Signature $state.Signature
    Update-GuiThemedContent

    return $true
}

function Get-GuiTextScaleSetting {
    # O tamanho do texto escolhido no Windows (Configurações > Acessibilidade > Tamanho do texto), de 1 a 2,25.
    $value = $null
    try { $value = Get-ItemPropertyValue -Path "HKCU:\Software\Microsoft\Accessibility" -Name "TextScaleFactor" -ErrorAction Stop } catch { $value = $null }

    return (Get-WinForgeTextScale -Value $value)
}

function Get-GuiUiFont {
    <#
    A fonte da janela: no Windows 11, a Segoe UI Variable (a variação para texto), mas só se o WPF a oferece com o seminegrito
    de verdade (um peso que o WPF tivesse de engrossar sozinho ficaria borrado); senão, e no Windows 10, a Segoe UI.
    #>
    try {
        foreach ($family in [System.Windows.Media.Fonts]::SystemFontFamilies) {
            if ([string]$family.Source -ne "Segoe UI Variable Text") { continue }

            # As faces que existem de fato no arquivo (uma face simulada é o WPF engrossando a normal).
            foreach ($face in $family.GetTypefaces()) {
                if ($face.Weight -eq [System.Windows.FontWeights]::SemiBold -and $face.Style -eq [System.Windows.FontStyles]::Normal -and -not $face.IsBoldSimulated) {
                    return "Segoe UI Variable Text"
                }
            }
        }
    }
    catch {
        Write-Verbose "Fonte: $($_.Exception.Message)"
    }

    return "Segoe UI"
}

function Get-GuiDisplayFont {
    <#
    A fonte dos títulos em negrito (o nome da página, a frase e os números do Início, o logotipo): no Windows 11, a Segoe UI
    Variable Display (a variação feita para tamanhos grandes), mas só se o WPF a oferece com o negrito de verdade; senão, e
    no Windows 10, a Segoe UI, que tem o negrito num arquivo próprio.
    #>
    try {
        foreach ($family in [System.Windows.Media.Fonts]::SystemFontFamilies) {
            if ([string]$family.Source -ne "Segoe UI Variable Display") { continue }

            foreach ($face in $family.GetTypefaces()) {
                if ($face.Weight -eq [System.Windows.FontWeights]::Bold -and $face.Style -eq [System.Windows.FontStyles]::Normal -and -not $face.IsBoldSimulated) {
                    return "Segoe UI Variable Display"
                }
            }
        }
    }
    catch {
        Write-Verbose "Fonte dos títulos: $($_.Exception.Message)"
    }

    return "Segoe UI"
}

function Set-GuiTypography {
    <#
    Aplica a fonte (na primeira vez) e a escala de tamanhos do Windows 11 multiplicada pelo tamanho do texto do Windows: os
    recursos do XAML (CaptionSize, BodySize... e as entrelinhas BodyLineHeight e SubtitleLineHeight) e os tamanhos que o
    script usa ($script:Type, com a entrelinha de cada um em $script:LineBySize). Devolve verdadeiro quando o
    tamanho mudou desde a última vez (os controles montados pelo script precisam ser refeitos).
    #>
    if (-not $script:FontApplied) {
        $script:FontApplied = $true
        try { Set-GuiResource -Dictionary $window.Resources -Key "UiFont" -Value ([System.Windows.Media.FontFamily]::new((Get-GuiUiFont))) } catch { Write-Verbose "Fonte: $($_.Exception.Message)" }

        # A fonte dos títulos vai para o recurso (o XAML: o nome da página, o logotipo) e fica guardada aqui, para os títulos
        # que o script monta (New-GuiText -Display) a receberem direto, sem depender de achar o recurso ao entrar na tela.
        try {
            $script:DisplayFontFamily = [System.Windows.Media.FontFamily]::new((Get-GuiDisplayFont))
            Set-GuiResource -Dictionary $window.Resources -Key "DisplayFont" -Value $script:DisplayFontFamily
        }
        catch {
            Write-Verbose "Fonte dos títulos: $($_.Exception.Message)"
        }
    }

    $scale = Get-GuiTextScaleSetting
    $changed = ($scale -ne $script:TextScale)

    $script:TextScale = $scale
    $script:Type = Get-WinForgeTypeRamp -Scale $scale
    $lines = Get-WinForgeLineRamp -Scale $scale
    $script:LineBySize = @{}
    foreach ($key in @($script:Type.Keys)) { $script:LineBySize["$($script:Type[$key])"] = $lines[$key] }
    Set-GuiResource -Dictionary $window.Resources -Key "BodyLineHeight" -Value ([double]$lines.Body)
    Set-GuiResource -Dictionary $window.Resources -Key "SubtitleLineHeight" -Value ([double]$lines.Subtitle)

    Set-GuiResource -Dictionary $window.Resources -Key "CaptionSize" -Value ([double]$script:Type.Caption)
    Set-GuiResource -Dictionary $window.Resources -Key "BodySize" -Value ([double]$script:Type.Body)
    Set-GuiResource -Dictionary $window.Resources -Key "BodyLargeSize" -Value ([double]$script:Type.BodyLarge)
    Set-GuiResource -Dictionary $window.Resources -Key "SubtitleSize" -Value ([double]$script:Type.Subtitle)
    Set-GuiResource -Dictionary $window.Resources -Key "TitleSize" -Value ([double]$script:Type.Title)
    Set-GuiResource -Dictionary $window.Resources -Key "TitleLargeSize" -Value ([double]$script:Type.TitleLarge)
    Set-GuiResource -Dictionary $window.Resources -Key "CodeSize" -Value ([double]([Math]::Round(12.5 * $scale * 2.0) / 2.0))

    return $changed
}

function Update-GuiThemedContent {
    # Os controles montados pelo script guardam a cor com que foram criados: refaz o que está na tela no tema novo.
    Set-GuiSelectedNav -Id $script:SelectedNav
    Update-GuiOutputColors
    Update-GuiActivityList

    if ($script:Running) {
        Set-GuiRunStatus -Text $runStatus.Text -DotColor $(if ($null -ne $script:ShownPrompt) { $script:Theme.Warn } else { $script:Theme.Accent })

        # A pergunta na tela foi montada com as cores do tema anterior: é refeita, com o que já estava marcado e digitado.
        if ($null -ne $script:ShownPrompt) { Update-GuiPromptTheme }
    }
    elseif ($null -ne $script:LastRunView) {
        Set-GuiResultView -View $script:LastRunView
    }

    Update-GuiRunStrip

    if ($pagesView.Visibility -eq "Visible") {
        if ($script:SearchActive -and -not [string]::IsNullOrWhiteSpace($searchBox.Text)) {
            Show-GuiSearchResults -Query $searchBox.Text -Rerender
        }
        else {
            Show-GuiPage -Id $script:CurrentPage -Rerender
        }
    }
}

function Set-GuiThemePreference {
    # A escolha de Sobre o WinForge > Aparência. Vale na hora e fica guardada nas preferências.
    param ([ValidateSet("System", "Light", "Dark")][string]$Value)

    # A opção que já está marcada não muda nada (nem refaz a página), como no Idioma.
    if ($Value -eq $script:ThemePreference) { return }

    $script:ThemePreference = $Value
    $script:AppearanceRefocus = $true
    [void](Set-WinForgeSetting -Name "Theme" -Value $Value)

    if (-not (Update-GuiTheme) -and $pagesView.Visibility -eq "Visible" -and $script:CurrentPage -eq "app") {
        # O tema na tela continua o mesmo (por exemplo, "Automático" com o Windows no claro): só a opção marcada muda.
        Show-GuiPage -Id "app" -Rerender
    }

    # A página foi refeita: o foco do teclado volta para a opção escolhida, em vez de pular para o começo da janela.
    $script:AppearanceRefocus = $false

    if ($null -ne $script:AppearanceFocusTarget) {
        [void]$script:AppearanceFocusTarget.Focus()
        $script:AppearanceFocusTarget = $null
    }
}

function Set-GuiLanguagePreference {
    <#
    A escolha de Sobre o WinForge > Idioma. Fica guardada e vale quando a janela abre de novo (os textos são montados ao
    abrir). Quando muda o idioma de verdade e nenhuma ação está rodando, oferece reabrir agora, na mesma página; com uma
    ação rodando, só avisa (reabrir no meio dela a interromperia).
    #>
    param ([ValidateSet("Auto", "pt", "en", "es")][string]$Value)

    if ($Value -eq $script:LanguagePreference) { return }

    if (-not (Set-WinForgeLanguagePreference -Language $Value)) {
        [void](Show-GuiMessage -Icon Warning -Title (Get-WinForgeText 'O idioma não foi guardado') -Text (Get-WinForgeText 'Tente de novo.'))
        return
    }

    $script:LanguagePreference = $Value
    $script:LanguageRefocus = $true
    if ($pagesView.Visibility -eq "Visible" -and $script:CurrentPage -eq "app") { Show-GuiPage -Id "app" -Rerender }
    $script:LanguageRefocus = $false

    if ($null -ne $script:LanguageFocusTarget) {
        [void]$script:LanguageFocusTarget.Focus()
        $script:LanguageFocusTarget = $null
    }

    # A escolha dá o idioma que já está na tela (Automático num Windows em português, por exemplo): nada a reabrir.
    if ((Get-WinForgeLanguageFor -Preference $Value) -eq (Get-WinForgeLanguage)) { return }

    if ($script:Running) {
        [void](Show-GuiMessage -Title (Get-WinForgeText 'O novo idioma vale quando o WinForge abrir de novo') -Text (Get-WinForgeText 'Feche e abra o WinForge depois que a ação terminar.'))
        return
    }

    $answer = Show-GuiMessage -Buttons YesNo -Icon Question -Default Yes -Title (Get-WinForgeText 'Reabrir o WinForge agora?') -Text (Get-WinForgeText 'O novo idioma vale quando o WinForge abrir de novo.') -YesText (Get-WinForgeText 'Reabrir') -NoText (Get-WinForgeText 'Agora não')
    if ($answer -ne "Yes") { return }

    # O idioma de um WINFORGE_LANG herdado passaria na frente da escolha que a pessoa acabou de fazer.
    Remove-Item -Path Env:WINFORGE_LANG -ErrorAction SilentlyContinue

    if (Start-GuiRelaunch -Page "app" -Handover) {
        $script:ForceClose = $true
        $window.Close()
    }
    else {
        [void](Show-GuiMessage -Icon Warning -Title (Get-WinForgeText 'O WinForge não foi reaberto') -Text (Get-WinForgeText 'Feche e abra de novo para ver o novo idioma.'))
    }
}

function Get-GuiIconDecoder {
    # Abre assets\WinForge.ico com todos os tamanhos. O arquivo é lido para a memória (e não aberto por endereço) para
    # funcionar com qualquer caractere no caminho, como # e %. Devolve $null se não houver ícone ou se ele for inválido.
    try {
        $path = Get-WinForgeIconPath

        if ($null -eq $path) { return $null }

        $script:IconStream = New-Object System.IO.MemoryStream (, [System.IO.File]::ReadAllBytes($path))

        # BitmapDecoder.Create escolhe o decodificador certo (de ícone, neste caso) e mantém todos os tamanhos do arquivo.
        return [System.Windows.Media.Imaging.BitmapDecoder]::Create($script:IconStream, [System.Windows.Media.Imaging.BitmapCreateOptions]::PreservePixelFormat, [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad)
    }
    catch {
        return $null
    }
}

function Set-GuiFallbackWindowIcon {
    # Reserva para quando o .ico não está na pasta: o mesmo desenho de assets\WinForge.svg (Get-WinForgeLogoDrawing),
    # reduzido da caixa de 1024 para 64 px.
    try {
        $logo = Get-WinForgeLogoDrawing
        $k = 64.0 / $logo.Box
        $tile = New-Object System.Windows.Rect ($logo.TileX * $k, $logo.TileX * $k, $logo.TileSize * $k, $logo.TileSize * $k)

        $visual = New-Object System.Windows.Media.DrawingVisual
        $context = $visual.RenderOpen()
        $context.DrawRoundedRectangle((New-GuiBrush $logo.TileColor), $null, $tile, $logo.TileRadius * $k, $logo.TileRadius * $k)
        $context.PushTransform((New-Object System.Windows.Media.MatrixTransform ($logo.Scale * $k, 0.0, 0.0, $logo.Scale * $k, $logo.OffsetX * $k, $logo.OffsetY * $k)))

        foreach ($part in $logo.Parts) {
            $context.DrawGeometry((New-GuiBrush $part.Color), $null, [System.Windows.Media.Geometry]::Parse($part.Data))
        }

        $context.Pop()
        $context.Close()

        $bitmap = New-Object System.Windows.Media.Imaging.RenderTargetBitmap (64, 64, 96, 96, [System.Windows.Media.PixelFormats]::Pbgra32)
        $bitmap.Render($visual)
        $bitmap.Freeze()
        $window.Icon = $bitmap
    }
    catch {
        # O ícone é opcional.
    }
}

function Set-GuiWindowIcon {
    $decoder = Get-GuiIconDecoder

    if ($null -ne $decoder -and $decoder.Frames.Count -gt 0) {
        try {
            # O WPF escolhe sozinho o tamanho certo do .ico para a barra de título, a barra de tarefas e o Alt+Tab. O
            # logotipo da barra lateral é desenhado pelo XAML, nas cores do tema.
            $window.Icon = $decoder.Frames[0]
            return
        }
        catch {
            # Cai na reserva abaixo.
        }
    }

    Set-GuiFallbackWindowIcon
}

function Set-GuiTaskbarProgress {
    # Mostra o andamento no botão da barra de tarefas, para acompanhar com a janela minimizada. Error (vermelho) e
    # Paused (amarelo) com a barra cheia servem de resultado enquanto a pessoa não volta à janela.
    param (
        [ValidateSet("None", "Indeterminate", "Normal", "Error", "Paused")]
        [string]$State,
        [double]$Value = 0
    )

    if ($null -eq $script:TaskbarInfo) { return }

    try {
        $script:TaskbarInfo.ProgressState = $State

        if ($State -in "Normal", "Error", "Paused") {
            # Os dois lados em double: com um 0 ou 1 inteiro, o PowerShell escolhe a versão para inteiros e a barra só
            # mostrava vazia ou cheia (45% virava 0).
            $script:TaskbarInfo.ProgressValue = [Math]::Max([double]0, [Math]::Min([double]1, $Value))
        }
    }
    catch {
        # Cosmético.
    }
}

function Set-GuiTaskbarFlash {
    # Faz o botão da janela piscar na barra de tarefas até a pessoa voltar a ela (ou para de piscar). Cosmético.
    param ([bool]$On)

    try {
        $info = New-Object WinForge.NativeWindow+FlashInfo
        $info.cbSize = [uint32][System.Runtime.InteropServices.Marshal]::SizeOf([type][WinForge.NativeWindow+FlashInfo])
        $info.hwnd = (New-Object System.Windows.Interop.WindowInteropHelper $window).Handle
        $info.uCount = [uint32]0
        $info.dwTimeout = [uint32]0

        # 2 = botão da barra de tarefas; 12 = pisca até a janela ir para o primeiro plano. 0 = parar.
        $info.dwFlags = $(if ($On) { [uint32]14 } else { [uint32]0 })

        [void][WinForge.NativeWindow]::FlashWindowEx([ref]$info)
    }
    catch {
        # Cosmético.
    }
}

$window.Add_SourceInitialized({
    Set-GuiTitleBarTheme -Target $window

    # "Fixar na barra de tarefas" passa a abrir o WinForge (com o ícone dele), e não o PowerShell. Cosmético.
    try { [void](Set-WinForgeWindowIdentity -Handle (New-Object System.Windows.Interop.WindowInteropHelper $window).Handle) } catch { }
})
Set-GuiWindowIcon

try {
    $script:TaskbarInfo = New-Object System.Windows.Shell.TaskbarItemInfo
    $window.TaskbarItemInfo = $script:TaskbarInfo
}
catch {
    $script:TaskbarInfo = $null
}

# O tema entra antes de qualquer controle ser montado pelo script (cada um guarda a cor com que foi criado).
try { $script:ThemePreference = Get-WinForgeThemePreference } catch { $script:ThemePreference = "System" }
try { $script:LanguagePreference = Get-WinForgeLanguagePreference } catch { $script:LanguagePreference = "Auto" }
[void](Set-GuiTypography)
$startTheme = Get-GuiThemeState
Set-GuiTheme -Name $startTheme.Name -Colors $startTheme.Colors -Signature $startTheme.Signature

# --- Painel de saída -----------------------------------------------------------------------------------

function Get-GuiConsoleBrush {
    param ($Color)

    $key = [string]$Color

    if (-not $script:BrushCache.ContainsKey($key)) {
        $hex = $script:ColorMap[$key]
        if ($null -eq $hex) { $hex = $script:ColorMap["Gray"] }
        $script:BrushCache[$key] = New-GuiBrush $hex
    }

    return $script:BrushCache[$key]
}

function Update-GuiOutputColors {
    # Os detalhes técnicos já escritos ganham as cores do console do tema novo (cada trecho guarda o nome da cor).
    try {
        foreach ($block in @($outputBox.Document.Blocks)) {
            foreach ($inline in @($block.Inlines)) {
                if ($inline -is [System.Windows.Documents.Run]) {
                    $inline.Foreground = Get-GuiConsoleBrush $inline.Tag
                }
            }
        }
    }
    catch {
        # Cosmético.
    }
}

function Reset-GuiOutput {
    $outputBox.Document.Blocks.Clear()
    $paragraph = New-Object System.Windows.Documents.Paragraph
    $paragraph.Margin = New-Object System.Windows.Thickness 0
    [void]$outputBox.Document.Blocks.Add($paragraph)

    $script:OutPara = $paragraph
    $script:CurrentRuns = New-Object System.Collections.ArrayList
    $script:CurrentText = ""
    $script:LastLineInlines = @()
    $script:LastLineProgress = $false
    $script:LineCount = 0
}

function Complete-GuiOutputLine {
    $text = $script:CurrentText
    $runs = @($script:CurrentRuns)

    $script:CurrentRuns = New-Object System.Collections.ArrayList
    $script:CurrentText = ""

    # Setas giratórias de programas nativos (- \ | /) não acrescentam informação.
    if (Test-WinForgeSpinnerLine -Text $text) {
        foreach ($run in $runs) { [void]$script:OutPara.Inlines.Remove($run) }
        return
    }

    # O resumo da execução: as mensagens de estado, as etapas, as linhas "rótulo : valor" e os títulos de seção
    # (confirmados pela linha de traços que vem logo depois deles).
    Add-GuiActivityFromLine -Text $text -Colors @($runs | ForEach-Object { [string]$_.Tag })

    $isProgress = Test-WinForgeProgressLine -Text $text

    # Linhas de progresso consecutivas substituem a anterior em vez de empilhar.
    if ($isProgress -and $script:LastLineProgress) {
        foreach ($old in $script:LastLineInlines) { [void]$script:OutPara.Inlines.Remove($old) }
    }

    $lineBreak = New-Object System.Windows.Documents.LineBreak
    [void]$script:OutPara.Inlines.Add($lineBreak)

    $script:LastLineInlines = @($runs) + @($lineBreak)
    $script:LastLineProgress = $isProgress
    $script:LineCount++

    # Mantém o painel leve em execuções muito longas.
    if ($script:LineCount -gt 5000) {
        $removed = 0

        while ($removed -lt 1000 -and $null -ne $script:OutPara.Inlines.FirstInline) {
            $first = $script:OutPara.Inlines.FirstInline

            if ($first -is [System.Windows.Documents.LineBreak]) { $removed++ }

            [void]$script:OutPara.Inlines.Remove($first)
        }

        $script:LineCount -= $removed
    }
}

function Add-GuiOutputItem {
    param ($Item)

    if ($Item.Clear) {
        Reset-GuiOutput
        return
    }

    $color = [string]$Item.Color
    $brush = Get-GuiConsoleBrush $color
    $parts = ([string]$Item.Text).Split("`n")

    for ($i = 0; $i -lt $parts.Length; $i++) {
        $segment = $parts[$i]

        if ($segment.Length -gt 0) {
            $run = New-Object System.Windows.Documents.Run $segment
            $run.Foreground = $brush

            # O nome da cor fica no trecho: o resumo reconhece títulos de seção por ela e a troca de tema recolore.
            $run.Tag = $color
            [void]$script:OutPara.Inlines.Add($run)
            [void]$script:CurrentRuns.Add($run)
            $script:CurrentText += $segment
        }

        $isLast = ($i -eq $parts.Length - 1)

        if ((-not $isLast) -or $Item.NewLine) {
            Complete-GuiOutputLine
        }
    }
}

function Get-GuiOutputColumns {
    # Largura dos detalhes técnicos em caracteres, para as tabelas e barras da saída caberem sem quebrar linha. Com os
    # detalhes fechados, usa a largura da tela de execução.
    try {
        $width = $outputBox.ActualWidth
        if ($width -le 0) { $width = $runView.ActualWidth - 44 }
        if ($width -le 0) { $width = 760 }

        $typeface = New-Object System.Windows.Media.Typeface ($outputBox.FontFamily, $outputBox.FontStyle, $outputBox.FontWeight, $outputBox.FontStretch)
        $sample = New-Object System.Windows.Media.FormattedText ("0", [System.Globalization.CultureInfo]::InvariantCulture, [System.Windows.FlowDirection]::LeftToRight, $typeface, $outputBox.FontSize, [System.Windows.Media.Brushes]::White)
        $columns = [int][Math]::Floor(($width - 34) / $sample.WidthIncludingTrailingWhitespace)

        return [Math]::Max(80, [Math]::Min(160, $columns))
    }
    catch {
        return 100
    }
}

function Set-GuiRunStatus {
    param ([string]$Text, [string]$DotColor)

    $runStatus.Text = $Text
    $runDot.Fill = New-GuiBrush $DotColor
}

function Reset-GuiActivity {
    $script:ActivityEntries = New-Object System.Collections.ArrayList
    $script:PendingSection = $null
    $script:UncoveredLines = 0
    $script:SummaryExpanded = $false
    $script:RunStepSeen = $false
    $script:RunStepIndex = 0
    $script:RunStepTotal = 0
    $script:RunStepDone = $false
    $script:PromptContextHidden = New-Object System.Collections.ArrayList
    $activityList.Children.Clear()
    $activityPanel.Visibility = "Collapsed"
    $activitySeparator.Visibility = "Visible"
}

function Add-GuiActivityFromLine {
    # Decide se uma linha completa da saída entra no resumo. Um título de seção só entra quando a linha seguinte é a de
    # traços; até lá fica guardado em PendingSection. Colors: as cores dos pedaços da linha, na ordem.
    # UncoveredLines conta as linhas com texto que o resumo não mostra (tabelas, saída de programas, um título que não
    # virou seção): sem nenhuma, o resumo diz tudo o que a ação escreveu (Test-GuiSummaryIsContent).
    param (
        [AllowEmptyString()][string]$Text,
        [string[]]$Colors = @()
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return
    }

    $color = $(if (@($Colors).Count -gt 0) { [string]$Colors[0] } else { "" })
    $isRule = Test-WinForgeRuleLine -Text $Text

    if ($null -ne $script:PendingSection -and $isRule) {
        $title = $script:PendingSection
        $script:PendingSection = $null
        Add-GuiActivity -Kind "Section" -Text $title
        return
    }

    # O título guardado não foi confirmado pela linha de traços: era um texto ciano qualquer, que o resumo não mostra.
    if ($null -ne $script:PendingSection) {
        $script:PendingSection = $null
        $script:UncoveredLines++
    }

    $entry = Get-WinForgeActivityEntry -Text $Text

    if ($null -ne $entry) {
        Add-GuiActivity -Kind $entry.Kind -Text $entry.Text
        return
    }

    $fact = Get-WinForgeFactEntry -Text $Text -Colors $Colors

    if ($null -ne $fact) {
        Add-GuiActivity -Kind "Fact" -Text $fact.Text -Label $fact.Label -Value $fact.Value -Level $fact.Level
        return
    }

    $script:PendingSection = Get-WinForgeSectionTitle -Text $Text -Color $color

    if ($null -eq $script:PendingSection) {
        $script:UncoveredLines++
    }
}

function Test-GuiSummaryIsContent {
    # O resumo diz tudo o que a ação escreveu: só mensagens do WinForge, linhas "rótulo : valor" e seções, sem tabela nem
    # texto de programa (que só os detalhes técnicos mostram).
    return ($script:ActivityEntries.Count -gt 0 -and $script:UncoveredLines -eq 0 -and $null -eq $script:PendingSection)
}

function New-GuiActivityRow {
    # Uma linha do resumo: ícone do tipo (feito, atenção, erro, informação, em andamento, ignorado) e o texto; seções e
    # etapas viram um subtítulo discreto; um fato ("rótulo : valor") vira rótulo apagado e valor, como no resumo do alto
    # das páginas.
    param ([Parameter(Mandatory)]$Entry)

    if ($Entry.Kind -eq "Section" -or $Entry.Kind -eq "Step" -or $Entry.Kind -eq "Phase") {
        $heading = New-GuiText -Text ([string]$Entry.Text) -Size $script:Type.Caption -Color $script:Theme.Muted -Bold $true
        $heading.Margin = New-Object System.Windows.Thickness (0, 10, 0, 3)
        return $heading
    }

    if ($Entry.Kind -eq "Fact") {
        $line = New-Object System.Windows.Controls.DockPanel
        $line.Margin = New-Object System.Windows.Thickness (27, 2, 0, 2)

        $label = New-GuiText -Text ([string]$Entry.Label) -Size $script:Type.Body -Color $script:Theme.Muted
        $label.Width = 210
        $label.Margin = New-Object System.Windows.Thickness (0, 0, 12, 0)
        Set-GuiDock -Element $label -Side "Left"
        [void]$line.Children.Add($label)

        # O valor que pede atenção (ou que confirma que está tudo certo) vem na cor do nível, como no console.
        $value = switch ([string]$Entry.Level) {
            "Ok"    { New-GuiText -Text ([string]$Entry.Value) -Size $script:Type.Body -Color $script:Theme.Ok }
            "Warn"  { New-GuiText -Text ([string]$Entry.Value) -Size $script:Type.Body -Color $script:Theme.Warn -Bold $true }
            "Bad"   { New-GuiText -Text ([string]$Entry.Value) -Size $script:Type.Body -Color $script:Theme.Bad -Bold $true }
            default { New-GuiText -Text ([string]$Entry.Value) -Size $script:Type.Body }
        }
        [void]$line.Children.Add($value)

        return $line
    }

    $looks = @{
        Ok   = @{ Icon = "check-circle"; Color = $script:Theme.Ok }
        Warn = @{ Icon = "warning"; Color = $script:Theme.Warn }
        Bad  = @{ Icon = "error-circle"; Color = $script:Theme.Bad }
        Info = @{ Icon = "info"; Color = $script:Theme.AccentText }
        Run  = @{ Icon = "dots"; Color = $script:Theme.AccentText }
        Skip = @{ Icon = "minus-circle"; Color = $script:Theme.Dim }
    }

    $look = $looks[[string]$Entry.Kind]
    if ($null -eq $look) { $look = $looks.Info }

    $row = New-Object System.Windows.Controls.DockPanel
    $row.Margin = New-Object System.Windows.Thickness (0, 3, 0, 3)

    $glyph = New-GuiIcon -Name $look.Icon -Size 17 -Color $look.Color
    $glyph.Margin = New-Object System.Windows.Thickness (0, 1, 10, 0)
    $glyph.VerticalAlignment = "Top"
    Set-GuiDock -Element $glyph -Side "Left"
    [void]$row.Children.Add($glyph)

    [void]$row.Children.Add((New-GuiActivityText -Text ([string]$Entry.Text)))

    return $row
}

function New-GuiActivityText {
    # O texto de uma linha do resumo. Cada referência "Página > Item" ("Use Limpeza > Limpar o registro para...") vira um
    # link que abre o item, como os botões dos pontos de atenção do Início: o próximo passo fica a um clique.
    param ([string]$Text)

    $reference = Find-WinForgeNavReference -Text $Text

    if ($null -eq $reference) { return (New-GuiText -Text $Text -Size $script:Type.Body) }

    $block = New-GuiText -Text "" -Size $script:Type.Body
    $rest = $Text

    while ($null -ne $reference) {
        $before = $rest.Substring(0, $reference.Start)
        $linked = $rest.Substring($reference.Start, $reference.Length)

        if ($before) { [void]$block.Inlines.Add((New-Object System.Windows.Documents.Run $before)) }

        $link = New-Object System.Windows.Documents.Hyperlink
        [void]$link.Inlines.Add((New-Object System.Windows.Documents.Run $linked))
        $link.Style = $window.FindResource("SummaryLink")
        $link.Tag = $reference.ItemId
        $link.ToolTip = (Get-WinForgeText 'Abrir {0}' "$linked")
        $link.Add_Click({
            param ($sender, $eventArgs)
            $item = Get-WinForgeNavItem -Id ([string]$sender.Tag)
            if ($null -ne $item) { Invoke-GuiNavItem -Item $item }
        })
        [void]$block.Inlines.Add($link)

        $rest = $rest.Substring($reference.Start + $reference.Length)
        $reference = Find-WinForgeNavReference -Text $rest
    }

    if ($rest) { [void]$block.Inlines.Add((New-Object System.Windows.Documents.Run $rest)) }

    return $block
}

function Add-GuiActivity {
    param (
        [Parameter(Mandatory)][string]$Kind,
        [Parameter(Mandatory)][string]$Text,

        # Só para um fato ("rótulo : valor"); Level pinta o valor (Ok, Warn, Bad).
        [string]$Label = "",
        [string]$Value = "",
        [string]$Level = "Normal"
    )

    # O título de seção que uma etapa escreve logo depois da marca "Etapa 3 de 9: título" repetiria a marca: a etapa em
    # destaque e o resumo ficam com a marca, que diz também em que ponto do fluxo se está.
    if ($Kind -eq "Section" -and $script:ActivityEntries.Count -gt 0) {
        $last = $script:ActivityEntries[$script:ActivityEntries.Count - 1]

        if ($last.Kind -eq "Step" -and ([string]$last.Text).EndsWith(": $Text")) { return }
    }

    $entry = [PSCustomObject]@{ Kind = $Kind; Text = $Text; Label = $Label; Value = $Value; Level = $Level }
    [void]$script:ActivityEntries.Add($entry)
    [void]$activityList.Children.Add((New-GuiActivityRow -Entry $entry))

    # O resumo guarda as últimas 300 linhas; os detalhes técnicos têm tudo.
    while ($script:ActivityEntries.Count -gt 300) {
        $script:ActivityEntries.RemoveAt(0)
        $activityList.Children.RemoveAt(0)
    }

    # Com uma pergunta na tela, o resumo pode estar escondido para a lista ter espaço (Update-GuiPromptFit). Uma linha que
    # chega com a pergunta já à vista aumenta o cartão do andamento e empurra a pergunta: a conta é refeita.
    if ($null -eq $script:ShownPrompt) { $activityPanel.Visibility = "Visible" } else { Request-GuiPromptFit }

    # A frase em destaque é a etapa: depois da primeira "Etapa N de M" (o Otimizar), só outra etapa a troca; um título no
    # meio dela ("Lixeira", "Reparar imagem e componentes") a faria parecer outra etapa. Sem etapas, vale o último título.
    # O padrão sai do mesmo texto que o Otimizar escreve ("Etapa {0} de {1}: {2}"), no idioma da tela.
    if ($null -eq $script:RunStepPattern) {
        $script:RunStepPattern = '^' + ([regex]::Escape((Get-WinForgeText 'Etapa {0} de {1}: {2}')) -replace '\\\{0}', '(?<index>[0-9]+)' -replace '\\\{1}', '(?<total>[0-9]+)' -replace '\\\{2}.*$', '')
    }

    if ($Kind -eq "Step" -and $Text -match $script:RunStepPattern) {
        $script:RunStepSeen = $true
        $script:RunStepIndex = [int]$Matches["index"]
        $script:RunStepTotal = [int]$Matches["total"]
        $script:RunStepDone = $false
        Set-GuiRunStep -Text $Text
        [void](Update-GuiOverallProgress -Fraction 0.0)
        Send-GuiAnnouncement -Element $runStepText
    }
    elseif ($Kind -eq "Phase") {
        # Uma parte do fluxo que não é etapa (as perguntas antes da parte automática, o fim do Otimizar): ela toma o lugar
        # da etapa em destaque, que já terminou, e a barra mostra essa etapa inteira feita. A conta das etapas não muda.
        Set-GuiRunStep -Text $Text
        $script:RunStepDone = $script:RunStepSeen
        [void](Update-GuiOverallProgress)
        Send-GuiAnnouncement -Element $runStepText
    }
    elseif (($Kind -eq "Section" -or $Kind -eq "Step") -and -not $script:RunStepSeen) {
        Set-GuiRunStep -Text $Text
    }

    $activityScroll.ScrollToEnd()
}

function Update-GuiOverallProgress {
    # Com etapas numeradas (o Otimizar), a barra e o botão na barra de tarefas mostram a execução inteira: as etapas já
    # feitas mais a parte da etapa atual que a ferramenta informa (Fraction, de 0 a 1). Falso quando não há etapas.
    param ([double]$Fraction = 0.0)

    if ($script:RunStepTotal -le 0) { return $false }
    if ($script:RunStepDone) { $Fraction = 1.0 }

    $value = Get-WinForgeOverallProgress -Index $script:RunStepIndex -Total $script:RunStepTotal -Fraction $Fraction
    $runProgress.IsIndeterminate = $false
    $runProgress.Value = $value
    Set-GuiTaskbarProgress -State Normal -Value ($value / 100)

    return $true
}

function Show-GuiSummarySection {
    # Rola o resumo até o último título de seção com este nome (sem nome, o último título, qualquer que seja), que fica no
    # alto da área visível.
    param ([string]$Title)

    try {
        for ($i = $script:ActivityEntries.Count - 1; $i -ge 0; $i--) {
            $entry = $script:ActivityEntries[$i]

            if ([string]$entry.Kind -eq "Section" -and ([string]::IsNullOrEmpty($Title) -or [string]$entry.Text -eq $Title) -and $i -lt $activityList.Children.Count) {
                $activityScroll.UpdateLayout()
                $offset = $activityList.Children[$i].TranslatePoint((New-Object System.Windows.Point (0, 0)), $activityList).Y
                $activityScroll.ScrollToVerticalOffset([Math]::Max(0.0, $offset - 4))
                return
            }
        }
    }
    catch {
        Write-Verbose "Resumo: $($_.Exception.Message)"
    }
}

function Update-GuiActivityList {
    # Redesenha o resumo (troca de tema).
    $activityList.Children.Clear()

    foreach ($entry in @($script:ActivityEntries)) {
        [void]$activityList.Children.Add((New-GuiActivityRow -Entry $entry))
    }
}

function Set-GuiRunStep {
    # A etapa em andamento, em destaque no alto da execução.
    param ([string]$Text)

    $runStepText.Text = $Text
}

function Set-GuiDetailsOpen {
    # Mostra ou esconde os detalhes técnicos (a saída completa da ação). Abertos, eles ocupam o resto da tela e o resumo
    # encolhe.
    param ([bool]$Open)

    $script:DetailsOpen = $Open
    $detailsPanel.Visibility = $(if ($Open) { "Visible" } else { "Collapsed" })
    $detailsActions.Visibility = $detailsPanel.Visibility
    Set-GuiAutomationName -Element $detailsToggle -Name $(if ($Open) { (Get-WinForgeText 'Ocultar os detalhes técnicos') } else { (Get-WinForgeText 'Mostrar os detalhes técnicos') })
    $detailsCard.VerticalAlignment = $(if ($Open) { "Stretch" } else { "Top" })
    Update-GuiSummaryHeight -Refresh

    # Com uma pergunta na tela, abrir os detalhes não pode empurrar os botões de resposta para fora.
    if ($promptBar.Visibility -eq "Visible") { Update-GuiPromptFit }

    try {
        $detailsChevron.Data = [System.Windows.Media.Geometry]::Parse((Get-WinForgeIconData -Name $(if ($Open) { "chevron-down" } else { "chevron-right" })))
    }
    catch {
        # Cosmético.
    }

    if ($Open) { $outputBox.ScrollToEnd() }
}

function Update-GuiSummaryHeight {
    # A altura do resumo: menor com os detalhes técnicos abertos (eles ocupam o resto da tela), a de sempre com eles
    # fechados e, quando o resumo é o conteúdo da tela (uma consulta como Sobre este PC), todo o espaço até o cartão dos
    # detalhes. -Refresh refaz o layout antes de medir; o evento de tamanho da janela chama sem ele (o layout já está feito).
    param ([switch]$Refresh)

    if ($script:DetailsOpen) {
        $activityScroll.MaxHeight = 132
        return
    }

    if (-not $script:SummaryExpanded) {
        $activityScroll.MaxHeight = 232
        return
    }

    try {
        if ($Refresh) { $runView.UpdateLayout() }

        $top = $activityScroll.TranslatePoint((New-Object System.Windows.Point (0, 0)), $runView).Y
        $activityScroll.MaxHeight = Get-WinForgeSummaryMaxHeight -ViewHeight $runView.ActualHeight -Top $top -DetailsHeight $detailsCard.ActualHeight
    }
    catch {
        $activityScroll.MaxHeight = 232
    }
}

function Set-GuiPromptState {
    # Enquanto a ação espera uma resposta, a barra de progresso some e o status diz isso; o que a tela mostra em volta da
    # pergunta (o cartão do andamento, o resumo, a etapa no alto da pergunta) é decidido por Update-GuiPromptFit.
    param ([bool]$Shown)

    if ($Shown) {
        $runProgress.Visibility = "Collapsed"
        $progressText.Visibility = $(if ([string]::IsNullOrEmpty($progressText.Text)) { "Collapsed" } else { "Visible" })

        # Sem nada à vista no resumo (nada feito ainda, ou o que havia foi para dentro da pergunta) e sem andamento, o
        # cartão do andamento sai e a pergunta fica no alto.
        if (-not (Test-GuiSummaryHasVisibleRows) -and [string]::IsNullOrEmpty($progressText.Text)) {
            $runHero.Visibility = "Collapsed"
        }

        Set-GuiRunStatus -Text (Get-WinForgeText 'Esperando a sua resposta') -DotColor $script:Theme.Warn
    }
    else {
        Restore-GuiAroundPrompt
        Set-GuiRunStatus -Text (Get-WinForgeText 'Em execução') -DotColor $script:Theme.Accent
    }
}

function Restore-GuiAroundPrompt {
    # Desfaz o que a pergunta mudou em volta dela: o cartão do andamento, o resumo (inteiro de novo, com as linhas que
    # tinham ido para dentro da pergunta), a barra de progresso e a altura do cartão da pergunta.
    Clear-GuiPromptContext
    $promptStep.Visibility = "Collapsed"
    $runProgress.Visibility = "Visible"
    $progressText.Visibility = "Visible"
    $runHero.Visibility = "Visible"
    $activityPanel.Visibility = $(if ($script:ActivityEntries.Count -gt 0) { "Visible" } else { "Collapsed" })
    $promptBar.MaxHeight = [double]::PositiveInfinity
    Update-GuiSummaryHeight

    try { $activityScroll.ScrollToEnd() } catch { Write-Verbose "Resumo: $($_.Exception.Message)" }
}

function Set-GuiPromptContext {
    # O contexto da pergunta: o que a ação disse desde o último título (a pasta e o tamanho dela, o que deixa de abrir com
    # o Windows, por que reiniciar), no máximo as 4 últimas linhas, vai para dentro do cartão, junto da pergunta. No
    # resumo, essas linhas ficam escondidas enquanto a pergunta está na tela (não aparecem duas vezes) e voltam depois.
    # Depois de uma lista longa de dados (o que o Verificar o PC encontrou), só as mensagens vão para o cartão: quatro
    # linhas soltas do fim da lista ("Reinício pendente: não") não explicam a pergunta, e a lista inteira fica no resumo.
    Clear-GuiPromptContext
    $promptContext.Children.Clear()

    $entries = $script:ActivityEntries
    $count = $entries.Count
    $start = $count

    while ($start -gt 0 -and [string]$entries[$start - 1].Kind -notin @("Section", "Step", "Phase")) { $start-- }

    $picked = @(for ($i = $start; $i -lt $count; $i++) { $i })
    if ($picked.Count -gt 4) { $picked = @($picked | Where-Object { [string]$entries[$_].Kind -ne "Fact" }) }

    foreach ($i in @($picked | Select-Object -Last 4)) {
        [void]$promptContext.Children.Add((New-GuiActivityRow -Entry $entries[$i]))

        if ($i -lt $activityList.Children.Count) {
            $row = $activityList.Children[$i]
            $row.Visibility = "Collapsed"
            [void]$script:PromptContextHidden.Add($row)
        }
    }

    $promptContext.Visibility = $(if ($promptContext.Children.Count -gt 0) { "Visible" } else { "Collapsed" })
}

function Clear-GuiPromptContext {
    foreach ($row in @($script:PromptContextHidden)) { $row.Visibility = "Visible" }
    $script:PromptContextHidden.Clear()
}

function Test-GuiSummaryHasVisibleRows {
    # Sobrou alguma linha à vista no resumo (sem contar as que foram para dentro da pergunta)?
    return (($script:ActivityEntries.Count - $script:PromptContextHidden.Count) -gt 0)
}

function Get-GuiPromptLayoutNow {
    <#
    As medidas da tela agora em Get-WinForgePromptLayout. Uma lista (ou opções em linha) pede pelo menos 40% da altura da
    tela, e o resumo cede antes dela. Abertos, os detalhes técnicos ficam com o cabeçalho e um pedaço da saída, que cede
    espaço antes do resumo e da lista; fechados, só com o cabeçalho.
    O painel em volta já limita o cartão ao fim da tela; a conta precisa das medidas sem limite: o cartão é medido de
    novo com altura livre (e volta a ser medido pelo painel na próxima passada), e a lista conta inteira (a altura do
    conteúdo dela, ExtentHeight). O resto do cartão (a pergunta, o filtro, os botões) é o cartão menos a lista. O que está
    à vista é lido em Visibility, que muda na hora, e não em IsVisible, que depende da tela já desenhada: uma lista medida
    como vazia fazia o cartão inteiro parecer "a pergunta sem a lista", e ele ficava do tamanho da lista, sem rolar.
    #>
    $details = $(if ($script:DetailsOpen) { [double]$detailsToggle.ActualHeight + 18 + 150 } else { [double]$detailsCard.ActualHeight })
    $detailsMin = $(if ($script:DetailsOpen) { [double]$detailsToggle.ActualHeight + 26 } else { $details })
    $scroll = $null
    if ($promptListScroll.Visibility -eq "Visible") { $scroll = $promptListScroll }
    elseif ($promptOptionsScroll.Visibility -eq "Visible") { $scroll = $promptOptionsScroll }

    $prompt = [double]$promptBar.ActualHeight
    $list = 0.0

    if ($null -ne $scroll) {
        $list = [Math]::Max([double]$scroll.ExtentHeight, [double]$scroll.ActualHeight)
        $prompt = $prompt - [double]$scroll.ActualHeight + $list
    }

    # Espremido abaixo da pergunta sem a lista (janela baixa), o cartão à vista esconde o tamanho do resto: a altura livre
    # diz. Sem conseguir medir, fica a conta acima.
    try {
        if ([double]$promptBar.ActualWidth -gt 0) {
            $promptBar.Measure((New-Object System.Windows.Size ([double]$promptBar.ActualWidth, [double]::PositiveInfinity)))
            $free = [double]$promptBar.DesiredSize.Height - [double]$promptBar.Margin.Top - [double]$promptBar.Margin.Bottom
            $promptBar.InvalidateMeasure()
            if ($free -gt $prompt) { $prompt = $free }
        }
    }
    catch {
        Write-Verbose "Altura livre da pergunta: $($_.Exception.Message)"
    }

    $view = [double]$runView.ActualHeight
    $minList = $(if ($list -gt 0) { [Math]::Max(160.0, [Math]::Floor(0.4 * $view)) } else { 160.0 })
    $summary = $(if ($runHero.Visibility -eq "Visible" -and $activityPanel.Visibility -eq "Visible") { [double]$activityScroll.ActualHeight } else { 0.0 })

    return (Get-WinForgePromptLayout -ViewHeight $view `
        -PromptTop $promptBar.TranslatePoint((New-Object System.Windows.Point (0, 0)), $runView).Y `
        -Margin $promptBar.Margin.Bottom -DetailsHeight $details -DetailsMinHeight $detailsMin -PromptHeight $prompt `
        -ListHeight $list -SummaryHeight $summary -MinList $minList)
}

function Request-GuiPromptFit {
    # Refaz a conta do tamanho da pergunta logo depois de a tela ser desenhada (um instante depois): o que muda em volta
    # dela depois de ela aparecer (linhas novas no resumo, a lista desenhada por inteiro) não deixa o cartão passar do fim.
    if ($null -eq $script:PromptFitTimer) { return }

    $script:PromptFitTimer.Stop()
    $script:PromptFitTimer.Start()
}

function Update-GuiPromptFit {
    <#
    A tela de execução não rola, e os botões da pergunta têm de ficar sempre à vista, em qualquer tamanho de janela: o
    cartão da pergunta fica limitado ao espaço que sobra até os detalhes técnicos (dentro dele, só a lista encolhe e
    rola), e o resumo acima encolhe antes quando a lista ficaria apertada (Get-WinForgePromptLayout). Um resumo com menos
    de três linhas à vista não ajuda: ele some, e com ele o cartão do andamento, e a etapa vai para o alto da pergunta, em
    letra pequena. O que a pergunta precisa do resumo já está dentro dela (Set-GuiPromptContext). Roda quando a pergunta
    aparece, quando a janela muda de tamanho e quando os detalhes abrem ou fecham.
    #>
    if ($promptBar.Visibility -ne "Visible") { return }

    try {
        # Primeiro, as medidas sem limite nenhum, com o cartão do andamento e o resumo como ficariam sem a pergunta.
        $hasStep = ($script:RunStepSeen -and -not [string]::IsNullOrWhiteSpace($runStepText.Text))
        $hasRows = Test-GuiSummaryHasVisibleRows
        $promptBar.MaxHeight = [double]::PositiveInfinity
        $promptStep.Visibility = "Collapsed"
        $promptContext.Visibility = $(if ($promptContext.Children.Count -gt 0) { "Visible" } else { "Collapsed" })
        $activityPanel.Visibility = $(if ($hasRows) { "Visible" } else { "Collapsed" })
        $runHero.Visibility = $(if ($hasRows) { "Visible" } else { "Collapsed" })
        Update-GuiSummaryHeight
        $runView.UpdateLayout()

        $layout = Get-GuiPromptLayoutNow

        if (-not $hasRows -or ($layout.SummaryMaxHeight -ge 0 -and $layout.SummaryMaxHeight -lt 72)) {
            $activityPanel.Visibility = "Collapsed"
            $runHero.Visibility = "Collapsed"

            if ($hasStep) {
                $promptStep.Text = $runStepText.Text
                $promptStep.Visibility = "Visible"
            }

            $runView.UpdateLayout()
            $layout = Get-GuiPromptLayoutNow
        }
        elseif ($layout.SummaryMaxHeight -ge 0) {
            $activityScroll.MaxHeight = $layout.SummaryMaxHeight
        }

        # Nem sem o cartão do andamento a pergunta cabe (janela baixa, texto grande): as linhas do resumo copiadas para
        # dentro dela saem antes, para os botões continuarem à vista. Elas continuam no resumo e nos detalhes técnicos.
        if ([bool](Get-WinForgeJsonValue -Object $layout -Name "Cramped" -Default $false) -and $promptContext.Visibility -eq "Visible") {
            $promptContext.Visibility = "Collapsed"
            $runView.UpdateLayout()
            $layout = Get-GuiPromptLayoutNow
        }

        $promptBar.MaxHeight = $layout.PromptMaxHeight

        # Encolhido, o resumo continua mostrando as últimas linhas, e não as do começo da execução.
        if ($activityPanel.Visibility -eq "Visible") {
            $activityScroll.UpdateLayout()
            $activityScroll.ScrollToEnd()
        }
    }
    catch {
        Write-Verbose "Tamanho da pergunta: $($_.Exception.Message)"

        # Sem a conta, o cartão nunca fica sem limite: vai, no máximo, até o fim da tela (a lista rola e os botões ficam à
        # vista; os detalhes técnicos podem ficar abaixo).
        try {
            $top = $promptBar.TranslatePoint((New-Object System.Windows.Point (0, 0)), $runView).Y
            $promptBar.MaxHeight = [Math]::Max(160.0, [Math]::Floor([double]$runView.ActualHeight - $top - $promptBar.Margin.Bottom))
        }
        catch {
            $promptBar.MaxHeight = 420
        }
    }
}

# --- Perguntas: botões, listas de marcação e texto -----------------------------------------------------------
function Submit-GuiPrompt {
    param ([string]$Answer, [int]$Index = -1)

    $prompt = $script:ShownPrompt

    if ($null -eq $prompt) { return }

    $script:ShownPrompt = $null
    $promptBar.Visibility = "Collapsed"
    Set-GuiPromptState -Shown $false
    Complete-WinForgeGuiPrompt -Session $script:GuiSession -Prompt $prompt -Answer $Answer -ChoiceIndex $Index
}

function Submit-GuiMultiPrompt {
    param ([bool]$Accepted)

    $prompt = $script:ShownPrompt

    if ($null -eq $prompt) { return }

    $keys = @()

    if ($Accepted) {
        $keys = @($promptList.Children | Where-Object { $_.IsChecked } | ForEach-Object { [string]$_.Tag })
    }

    $script:ShownPrompt = $null
    $promptBar.Visibility = "Collapsed"
    Set-GuiPromptState -Shown $false
    Complete-WinForgeGuiPrompt -Session $script:GuiSession -Prompt $prompt -Keys $keys -Accepted:$Accepted
}

function Update-GuiPromptTheme {
    # Refaz a pergunta que está na tela (troca de tema), mantendo as marcações, o filtro e o texto digitado.
    $prompt = $script:ShownPrompt
    if ($null -eq $prompt) { return }

    $checked = @($promptList.Children | Where-Object { $_.IsChecked } | ForEach-Object { [string]$_.Tag })
    $hadList = ($promptList.Children.Count -gt 0)
    $filterText = [string]$promptFilter.Text
    $typed = [string]$promptInput.Text

    Show-GuiPromptBar -Prompt $prompt

    if ($hadList) {
        foreach ($child in $promptList.Children) { $child.IsChecked = ($checked -contains [string]$child.Tag) }
        Update-GuiMultiPromptCount
    }

    if ($promptFilterRow.Visibility -eq "Visible" -and $filterText) {
        $promptFilter.Text = $filterText
        Update-GuiPromptFilter
    }

    if ($promptTextRow.Visibility -eq "Visible") { $promptInput.Text = $typed }
}

function Update-GuiPromptFilter {
    # O filtro das listas de marcação longas: mostra só os itens com todas as palavras digitadas (sem diferença de
    # maiúsculas nem de acentos). O que já está marcado continua marcado mesmo escondido, e conta no Confirmar; "Marcar
    # todos" e "Limpar" valem para os itens à vista.
    $typed = [string]$promptFilter.Text
    $words = @((ConvertTo-WinForgeSearchText -Text $typed) -split '\s+' | Where-Object { $_ })
    $shown = 0

    foreach ($child in $promptList.Children) {
        $text = [string]$script:PromptFilterTexts[[string]$child.Tag]
        $match = $true

        foreach ($word in $words) {
            if (-not $text.Contains($word)) { $match = $false; break }
        }

        $child.Visibility = $(if ($match) { "Visible" } else { "Collapsed" })
        if ($match) { $shown++ }
    }

    $promptFilterHint.Visibility = $(if ([string]::IsNullOrEmpty($typed)) { "Visible" } else { "Collapsed" })
    $promptFilterEmpty.Visibility = $(if ($shown -eq 0 -and $promptList.Children.Count -gt 0) { "Visible" } else { "Collapsed" })

    foreach ($child in $promptButtons.Children) {
        if ($child.Tag -is [hashtable] -and $child.Tag.Role -eq "all") {
            $child.Content = $(if ($words.Count -gt 0) { (Get-WinForgeText 'Marcar os {0} à vista' "$shown") } else { (Get-WinForgeText 'Marcar todos') })
        }
    }
}

function Update-GuiMultiPromptCount {
    # O botão de confirmar conta o que vai acontecer: numa lista comum, os itens marcados ("Desinstalar (2)", desligado sem
    # nenhum); numa revisão (a lista veio com o estado de agora já marcado), as mudanças ("Aplicar (3)"), e "Continuar"
    # quando nada mudou. Na revisão ele nunca fica desligado: desmarcar tudo também é uma resposta.
    $checkedKeys = @($promptList.Children | Where-Object { $_.IsChecked } | ForEach-Object { [string]$_.Tag })
    $review = [bool]$script:PromptReview
    $changes = @($promptList.Children | Where-Object { [bool]$_.IsChecked -ne (@($script:PromptInitialKeys) -contains [string]$_.Tag) }).Count

    foreach ($child in $promptButtons.Children) {
        if ($child.Tag -is [hashtable] -and $child.Tag.Role -eq "confirm") {
            $label = [string]$child.Tag.Label

            if ($review) {
                $child.Content = $(if ($changes -gt 0) { "$label ($changes)" } else { (Get-WinForgeText 'Continuar') })
                $child.IsEnabled = $true
            }
            else {
                $child.Content = "$label ($($checkedKeys.Count))"
                $child.IsEnabled = ($checkedKeys.Count -gt 0)
            }
        }
    }
}

function New-GuiPromptButton {
    # Danger: a resposta apaga algo sem volta (o Sim de esvaziar a Lixeira): o botão de perigo, mesmo sendo o padrão.
    param (
        [string]$Text,
        [string]$Description = "",
        [bool]$Accent = $false,
        [bool]$Exit = $false,
        [bool]$Danger = $false,
        $Tag
    )

    $kind = $(if ($Danger -and -not $Exit) { "Danger" } elseif ($Accent -and -not $Exit) { "Primary" } else { "Secondary" })
    $button = New-GuiButton -Text $Text -Kind $kind -Tag $Tag
    $button.Margin = New-Object System.Windows.Thickness (0, 0, 10, 8)

    if (-not [string]::IsNullOrWhiteSpace($Description)) {
        $button.ToolTip = $Description
    }

    return $button
}

function New-GuiPromptOption {
    # Uma opção da pergunta em linha, como nas listas de escolha dos sistemas atuais: título, descrição e a seta. A
    # opção recomendada vem destacada; a que apaga algo sem volta (Danger), com o título e o contorno na cor de perigo.
    param (
        [string]$Text,
        [string]$Description = "",
        [bool]$Accent = $false,
        [bool]$Danger = $false,
        $Tag
    )

    $button = New-Object System.Windows.Controls.Button
    $button.Style = $window.FindResource("OptionButton")
    $button.Tag = $Tag
    Set-GuiAutomationName -Element $button -Name $(if ([string]::IsNullOrWhiteSpace($Description)) { $Text } else { "$Text. $Description" })

    $row = New-Object System.Windows.Controls.DockPanel

    $chevron = New-GuiIcon -Name "chevron-right" -Size 16 -Color $script:Theme.Dim
    $chevron.Margin = New-Object System.Windows.Thickness (12, 0, 0, 0)
    Set-GuiDock -Element $chevron -Side "Right"
    [void]$row.Children.Add($chevron)

    $stack = New-Object System.Windows.Controls.StackPanel
    $stack.VerticalAlignment = "Center"
    [void]$stack.Children.Add((New-GuiText -Text $Text -Size $script:Type.Body -Bold $true -Color $(if ($Danger) { $script:Theme.Danger } else { $script:Theme.Text })))

    if (-not [string]::IsNullOrWhiteSpace($Description)) {
        $detail = New-GuiText -Text $Description -Size $script:Type.Caption -Color $script:Theme.Muted
        $detail.Margin = New-Object System.Windows.Thickness (0, 2, 0, 0)
        [void]$stack.Children.Add($detail)
    }

    [void]$row.Children.Add($stack)
    $button.Content = $row

    # A borda na cor do texto de destaque, que passa de 3:1 sobre o fundo do cartão nos dois temas (é a mesma do anel de
    # foco).
    if ($Accent) {
        $button.Background = New-GuiBrush $script:Theme.AccentCard
        $button.BorderBrush = New-GuiBrush $script:Theme.AccentText
    }
    elseif ($Danger) {
        $button.BorderBrush = New-GuiBrush $script:Theme.Danger
    }

    return $button
}

function Show-GuiPromptBar {
    param ($Prompt)

    $plan = Get-WinForgePromptPlan -Prompt $Prompt

    $promptLabel.Text = $plan.Label
    $promptButtons.Children.Clear()
    $promptOptions.Children.Clear()
    $promptList.Children.Clear()
    $promptListScroll.Visibility = "Collapsed"
    $promptOptionsScroll.Visibility = "Collapsed"
    $promptTextRow.Visibility = "Collapsed"
    $promptFilterRow.Visibility = "Collapsed"
    $promptFilterEmpty.Visibility = "Collapsed"
    $script:PromptFilterTexts = @{}
    $script:PromptInitialKeys = @()
    $script:PromptReview = $false

    # O que a ação acabou de dizer sobre a pergunta fica junto dela, dentro do cartão.
    Set-GuiPromptContext

    # Quem recebe o foco do teclado quando a pergunta aparece (sem isso ele ficava na tela, e o primeiro Tab caía em
    # "Parar"): a primeira linha de uma lista de marcação; a resposta padrão, quando a ação deu uma (Enter = a padrão, como
    # no console), mesmo que seja a saída e outra opção esteja em destaque; sem padrão, a saída que não muda nada
    # (Cancelar, Voltar, Não), para um Enter a mais não confirmar nada.
    $focusTarget = $null
    $safeTarget = $null
    $hasDefault = -not [string]::IsNullOrEmpty([string]$Prompt.DefaultKey)

    if ($plan.Kind -eq "multi") {
        foreach ($option in $plan.Options) {
            # O texto em que o filtro procura: o nome e a descrição do item, sem acentos.
            $script:PromptFilterTexts[[string]$option.Key] = ConvertTo-WinForgeSearchText -Text "$($option.Label) $($option.Description)"

            $box = New-Object System.Windows.Controls.CheckBox
            $box.Style = $window.FindResource("ListCheckBox")
            $box.Tag = [string]$option.Key
            $box.IsChecked = [bool]$option.Selected

            $stack = New-Object System.Windows.Controls.StackPanel
            [void]$stack.Children.Add((New-GuiText -Text ([string]$option.Label) -Size $script:Type.Body))

            if (-not [string]::IsNullOrWhiteSpace([string]$option.Description)) {
                [void]$stack.Children.Add((New-GuiText -Text ([string]$option.Description) -Size $script:Type.Caption -Color $script:Theme.Muted))
            }

            $box.Content = $stack

            # O conteúdo é um painel: sem nome próprio, o leitor de tela anunciaria só "caixa de seleção".
            Set-GuiAutomationName -Element $box -Name $(if ([string]::IsNullOrWhiteSpace([string]$option.Description)) { [string]$option.Label } else { "$($option.Label). $($option.Description)" })
            $box.Add_Click({ Update-GuiMultiPromptCount })
            [void]$promptList.Children.Add($box)

            if ($null -eq $focusTarget) { $focusTarget = $box }
        }

        $promptListScroll.Visibility = "Visible"

        # Numa revisão (a ação pediu -AllowNone: a lista vem com o estado de agora marcado, como o que abre com o Windows e
        # os ajustes em uso), o botão conta as mudanças, e não há "Desmarcar tudo" (seria o espelho do "Marcar todos" que a
        # revisão já não tem). Uma lista comum com itens já marcados (os recomendados) conta os marcados, como sempre.
        $review = ($null -ne $Prompt.PSObject.Properties["AllowNone"] -and [bool]$Prompt.AllowNone)
        $script:PromptReview = $review
        $script:PromptInitialKeys = $(if ($review) { @($plan.Options | Where-Object { [bool]$_.Selected } | ForEach-Object { [string]$_.Key }) } else { @() })

        $confirmLabel = $(if ($null -ne $Prompt.PSObject.Properties["ConfirmLabel"] -and -not [string]::IsNullOrWhiteSpace([string]$Prompt.ConfirmLabel)) { [string]$Prompt.ConfirmLabel } elseif ($review) { (Get-WinForgeText 'Aplicar') } else { (Get-WinForgeText 'Confirmar') })
        $cancelLabel = $(if ($null -ne $Prompt.PSObject.Properties["CancelLabel"] -and -not [string]::IsNullOrWhiteSpace([string]$Prompt.CancelLabel)) { [string]$Prompt.CancelLabel } else { (Get-WinForgeText 'Cancelar') })

        $confirm = New-GuiPromptButton -Text "$confirmLabel (0)" -Accent $true -Tag @{ Role = "confirm"; Label = $confirmLabel }
        $confirm.Add_Click({ Submit-GuiMultiPrompt -Accepted $true })
        [void]$promptButtons.Children.Add($confirm)

        # Sem "Marcar todos" onde marcar tudo de uma vez seria um desastre (desinstalar programas, remover aplicativos).
        $noSelectAll = ($null -ne $Prompt.PSObject.Properties["NoSelectAll"] -and [bool]$Prompt.NoSelectAll)

        if (-not $noSelectAll) {
            $all = New-GuiPromptButton -Text (Get-WinForgeText 'Marcar todos') -Tag @{ Role = "all" }
            $all.Add_Click({
                foreach ($child in $promptList.Children) { if ($child.Visibility -eq "Visible") { $child.IsChecked = $true } }
                Update-GuiMultiPromptCount
            })
            [void]$promptButtons.Children.Add($all)
        }

        if (-not $review) {
            $none = New-GuiPromptButton -Text (Get-WinForgeText 'Desmarcar tudo') -Tag @{ Role = "none" }
            $none.Add_Click({
                foreach ($child in $promptList.Children) { if ($child.Visibility -eq "Visible") { $child.IsChecked = $false } }
                Update-GuiMultiPromptCount
            })
            [void]$promptButtons.Children.Add($none)
        }

        $cancel = New-GuiPromptButton -Text $cancelLabel -Exit $true -Tag @{ Role = "cancel" }
        $cancel.Add_Click({ Submit-GuiMultiPrompt -Accepted $false })
        [void]$promptButtons.Children.Add($cancel)

        Update-GuiMultiPromptCount

        # Uma lista longa (programas instalados, itens de inicialização, duplicados) ganha um filtro, já com o foco: é só
        # digitar parte do nome.
        if (@($plan.Options).Count -gt 10) {
            $promptFilterRow.Visibility = "Visible"
            $promptFilter.Text = ""
            Update-GuiPromptFilter
        }
    }
    else {
        # Opções com descrição (ou muitas opções) viram linhas; as de sair (Cancelar, Voltar) ficam como botões embaixo.
        $answers = @($plan.Buttons | Where-Object { -not $_.Exit })
        $asRows = ($answers.Count -gt 3) -or (@($answers | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_.Description) }).Count -gt 0)

        $firstControl = $null

        foreach ($definition in $plan.Buttons) {
            $tag = @{ Answer = $definition.Answer; Index = $definition.Index; Role = "answer" }

            # Com a caixa de texto, o botão principal é o Enviar: nenhum outro fica destacado ao lado dele.
            $accent = ([bool]$definition.Accent -and -not $plan.ShowText)

            if ($asRows -and -not $definition.Exit) {
                $control = New-GuiPromptOption -Text $definition.Text -Description $definition.Description -Accent $accent -Danger ([bool](Get-WinForgeJsonValue -Object $definition -Name "Danger" -Default $false)) -Tag $tag
            }
            else {
                $control = New-GuiPromptButton -Text $definition.Text -Description $definition.Description -Accent $accent -Exit ([bool]$definition.Exit) -Danger ([bool](Get-WinForgeJsonValue -Object $definition -Name "Danger" -Default $false)) -Tag $tag
            }

            if ($null -eq $firstControl) { $firstControl = $control }
            if ($hasDefault -and $null -eq $focusTarget -and [string]$definition.Answer -ieq [string]$Prompt.DefaultKey) { $focusTarget = $control }
            if ($null -eq $safeTarget -and ([bool]$definition.Exit -or [string]$definition.Answer -eq "N")) { $safeTarget = $control }

            $control.Add_Click({
                param ($sender, $eventArgs)
                Submit-GuiPrompt -Answer ([string]$sender.Tag.Answer) -Index ([int]$sender.Tag.Index)
            })

            if ($asRows -and -not $definition.Exit) {
                [void]$promptOptions.Children.Add($control)
            }
            else {
                [void]$promptButtons.Children.Add($control)
            }
        }

        if ($promptOptions.Children.Count -gt 0) {
            $promptOptionsScroll.Visibility = "Visible"
            $firstControl = $promptOptions.Children[0]
        }

        if ($null -eq $focusTarget) { $focusTarget = $safeTarget }
        if ($null -eq $focusTarget) { $focusTarget = $firstControl }

        if ($plan.ShowText) {
            # A resposta padrão (o "ENTER = 30" do console) já vem escrita e selecionada: Enter aceita, digitar troca.
            $promptTextRow.Visibility = "Visible"
            $promptInput.Text = [string]$plan.DefaultText
            $promptInput.SelectAll()
        }
    }

    if ($promptButtons.Children.Count -eq 0) {
        $promptButtons.Visibility = "Collapsed"
    }
    else {
        $promptButtons.Visibility = "Visible"
    }

    $script:ShownPrompt = $Prompt
    $promptBar.Visibility = "Visible"
    Set-GuiPromptState -Shown $true

    # Sim/Não, "pressione Enter" e texto livre costumam falar do que acabou de aparecer na saída: sem nenhuma linha do
    # resumo dentro da pergunta, os detalhes técnicos se abrem para a pessoa ver do que se trata. Listas de escolha e de
    # marcação já dizem tudo nelas mesmas.
    if ($plan.Kind -ne "choice" -and $plan.Kind -ne "multi" -and $promptContext.Children.Count -eq 0) {
        Set-GuiDetailsOpen -Open $true
    }

    # A pergunta inteira tem de caber na janela; e o leitor de tela lê a pergunta assim que ela aparece. A conta é
    # refeita um instante depois, com a tela já desenhada (a lista inteira medida).
    Update-GuiPromptFit
    Request-GuiPromptFit
    Send-GuiAnnouncement -Element $promptLabel

    # Quem está digitando na busca continua lá: as teclas seguintes (e o Enter) não vão parar na resposta da pergunta.
    if ($searchBox.IsKeyboardFocusWithin) { return }

    if ($plan.ShowText) {
        [void]$promptInput.Focus()
    }
    elseif ($promptFilterRow.Visibility -eq "Visible") {
        [void]$promptFilter.Focus()
    }
    elseif ($null -ne $focusTarget) {
        [void]$focusTarget.Focus()
    }
}

# --- Execução de ações ---------------------------------------------------------------------------------
# A barra lateral continua livre durante uma ação: a pessoa pode olhar outras páginas (Diagnóstico enquanto o SFC
# roda, por exemplo) e a faixa no alto da página mostra o andamento e leva de volta à execução.

function Get-GuiRunElapsed {
    $session = $script:GuiSession

    if ($null -eq $session -or $null -eq $session.StartedAt) { return [TimeSpan]::Zero }

    $end = $session.EndedAt
    if ($null -eq $end) { $end = Get-Date }

    return ($end - $session.StartedAt)
}

function Show-GuiRunView {
    # Mostra a tela de execução (saída, andamento, perguntas) no lugar da página aberta. Uma chave que mudava na própria
    # linha passa a ser uma ação como as outras (a pergunta dela, o resultado com algo a ler).
    $script:InPlaceRun = $null
    $pagesView.Visibility = "Collapsed"
    $runView.Visibility = "Visible"
    $script:RunUnseen = $false
    Update-GuiRunStrip
    Set-GuiSelectedNav -Id $script:RunPage
}

function Update-GuiRunStrip {
    # A faixa no alto das páginas: mostra a ação em andamento (ou o resultado que ainda não foi visto). A chave que muda na
    # própria linha não ganha a faixa enquanto a página dela está aberta: a linha diz "Alterando…".
    $showStrip = ($script:Running -or $script:RunUnseen) -and ($runView.Visibility -ne "Visible") -and -not (Test-GuiInPlaceHere)

    if (-not $showStrip) {
        $runStrip.Visibility = "Collapsed"
        return
    }

    $runStrip.Visibility = "Visible"
    $runStripTitle.Text = $runTitle.Text

    if ($script:Running) {
        $runStripDot.Fill = New-GuiBrush $script:Theme.Accent
        $text = (Get-WinForgeText 'Em execução · {0}' "$(Format-WinForgeClock -Span (Get-GuiRunElapsed))")

        # A etapa do Otimizar diz mais do que a ferramenta da vez ("Etapa 9 de 22: Reparar o Windows").
        if ($script:RunStepSeen -and -not [string]::IsNullOrWhiteSpace($runStepText.Text)) {
            $text += " · $($runStepText.Text)"
        }
        elseif (-not [string]::IsNullOrWhiteSpace($progressText.Text)) {
            $text += " · $($progressText.Text)"
        }
        elseif (-not [string]::IsNullOrWhiteSpace($runStepText.Text) -and $runStepText.Text -ne (Get-WinForgeText 'Em andamento')) {
            $text += " · $($runStepText.Text)"
        }

        if ($null -ne $script:ShownPrompt) {
            $text = (Get-WinForgeText 'Esperando a sua resposta')
            $runStripDot.Fill = New-GuiBrush $script:Theme.Warn
        }

        $runStripText.Text = $text
        $runStripStop.Visibility = "Visible"
        $runStripDismiss.Visibility = "Collapsed"
        $runStripView.Content = (Get-WinForgeText 'Ver')
        Set-GuiAutomationName -Element $runStripView -Name (Get-WinForgeText 'Ver a ação em andamento: {0}' "$($runTitle.Text)")
    }
    else {
        $view = $script:LastRunView
        $colors = $script:LevelColors[[string]$view.Level]
        $runStripDot.Fill = New-GuiBrush $colors.Dot
        $runStripText.Text = "$($view.StatusText) · $($view.ElapsedText)"
        $runStripStop.Visibility = "Collapsed"
        $runStripDismiss.Visibility = "Visible"
        $runStripView.Content = (Get-WinForgeText 'Ver resultado')
        Set-GuiAutomationName -Element $runStripView -Name (Get-WinForgeText 'Ver o resultado: {0}' "$($runTitle.Text)")
    }
}

function Set-GuiResultView {
    # O resultado no alto da execução: ícone e cor do desfecho, título e a frase do que aconteceu. Telas que só mostram
    # informações não têm resultado: o resumo vira o conteúdo da tela quando diz tudo (SummaryExpanded); senão some e
    # ficam os detalhes.
    param ([Parameter(Mandatory)]$View)

    $colors = $script:LevelColors[[string]$View.Level]

    Set-GuiRunStatus -Text $View.StatusText -DotColor $colors.Dot
    $runElapsed.Text = "· $($View.ElapsedText)"

    # O leitor de tela lê o desfecho inteiro quando a ação termina (Complete-GuiRun pede a leitura).
    Set-GuiAutomationName -Element $runStatus -Name ("$($View.StatusText). $($View.ResultText)".Trim())

    # O próximo passo que o resultado pede (abrir a Segurança do Windows com ameaças pendentes) é o botão de destaque da
    # tela; o Voltar fica discreto (um destaque só por tela).
    $next = [string](Get-WinForgeJsonValue -Object $View -Name "Next" -Default "")
    $hasNext = ($View.ShowBanner -and -not [string]::IsNullOrWhiteSpace($next))
    $resultAction.Visibility = $(if ($hasNext) { "Visible" } else { "Collapsed" })
    $resultAction.Tag = $(if ($hasNext) { $next } else { $null })
    $backButton.Style = $window.FindResource($(if ($hasNext) { "PillButton" } else { "PrimaryButton" }))

    if ($hasNext) {
        $label = [string](Get-WinForgeJsonValue -Object $View -Name "NextLabel" -Default "")

        if ([string]::IsNullOrWhiteSpace($label)) {
            $item = Get-WinForgeNavItem -Id $next
            $label = $(if ($null -ne $item) { [string]$item.Label } else { (Get-WinForgeText 'Abrir') })
        }

        $resultAction.Content = $label
    }

    if ($View.ShowBanner) {
        # A faixa entra uma vez, quando aparece (só ela: o resumo que já estava aberto embaixo não pisca); refeita no
        # lugar (troca de tema), ela não se mexe.
        if ($resultBanner.Visibility -ne "Visible") { Start-GuiEntrance -Element $resultBanner -Offset 6 -Milliseconds 200 }

        $resultIcon.Background = New-GuiBrush $colors.Back
        $resultIcon.Child = New-GuiIcon -Name ([string]$colors.Icon) -Size 26 -Color $colors.Dot
        $resultBannerTitle.Text = $View.BannerTitle
        $resultBannerText.Text = $(if (-not [string]::IsNullOrWhiteSpace([string]$View.ResultText)) { [string]$View.ResultText } else { [string]$View.BannerText })
        $resultBanner.Visibility = "Visible"
        $runHero.Visibility = "Visible"
        $activitySeparator.Visibility = "Visible"

        # A faixa já diz tudo (nada encontrado na verificação de vírus): o resumo só a repetiria, e os detalhes técnicos
        # continuam à mão.
        if ([bool](Get-WinForgeJsonValue -Object $View -Name "HideSummary" -Default $false)) {
            $activityPanel.Visibility = "Collapsed"
        }
    }
    else {
        # Sem nada acima do resumo, a linha que o separa do resultado sobraria no alto do cartão.
        $resultBanner.Visibility = "Collapsed"
        $runHero.Visibility = $(if ($script:SummaryExpanded) { "Visible" } else { "Collapsed" })
        $activitySeparator.Visibility = "Collapsed"
    }
}

function Invoke-GuiNextStep {
    # Um próximo passo (o botão da faixa de resultado, o de um ponto da nota de saúde): um item da navegação (outra ação
    # ou página) ou um atalho do Windows (Shortcuts.psm1), aberto com o título dado.
    param (
        [AllowEmptyString()][string]$Next,
        [string]$Title = ""
    )

    if ([string]::IsNullOrWhiteSpace($Next)) { return }

    $item = Get-WinForgeNavItem -Id $Next

    if ($null -ne $item) {
        Invoke-GuiNavItem -Item $item
        return
    }

    Open-GuiShortcut -Name $Next -Title $Title
}

function Invoke-GuiResultAction {
    # O botão do próximo passo na faixa de resultado.
    Invoke-GuiNextStep -Next ([string]$resultAction.Tag) -Title ([string]$resultAction.Content)
}

function Complete-GuiRun {
    param (
        [string]$Status,
        $Outcome = $null
    )

    $script:Timer.Stop()
    $script:Running = $false
    $script:ShownPrompt = $null
    $promptBar.Visibility = "Collapsed"
    Restore-GuiAroundPrompt
    $progressPanel.Visibility = "Collapsed"
    $stopButton.Visibility = "Collapsed"
    $backButton.Visibility = "Visible"
    # Um ajuste é liga/desliga: "Executar de novo" o desfaria sem perguntar. Para ele, a volta é pela lista de ajustes. O
    # Otimizar leva mais de uma hora e pergunta tudo de novo: o botão do lado do resultado seria só ruído.
    $isTweak = ($script:LastAction -is [hashtable] -and -not [string]::IsNullOrEmpty([string]$script:LastAction["FocusTweak"]))
    $isLong = ($script:LastAction -is [hashtable] -and [string]$script:LastAction["Command"] -eq "Invoke-WinForgeRecommendedMaintenance")
    Set-GuiTaskbarProgress -State None

    # A ação pode ter mudado o PC (espaço livre, última manutenção...): a próxima leitura do Início não usa a guardada.
    Clear-GuiHomeCache

    # O desfecho vem da própria ação (OK, ressalvas, falha); sem ele, só se sabe que o PowerShell terminou.
    $view = Get-WinForgeRunView -Status $Status -Outcome $Outcome -Elapsed (Get-GuiRunElapsed)
    $script:LastRunView = $view

    # A chave que mudou na própria linha (a tela de execução não abriu): sem nada a ler além do novo estado, a linha mostra
    # como o recurso ficou, e a janela fica na página.
    $inPlace = $script:InPlaceRun
    $script:InPlaceRun = $null
    $quietDone = ($null -ne $inPlace -and $runView.Visibility -ne "Visible" -and (Test-GuiQuietOutcome -Status $Status -Outcome $Outcome))

    # Com um próximo passo na faixa (ameaças que pedem ação), rodar de novo não resolve nada: o botão sairia do lugar dele.
    $hasNext = -not [string]::IsNullOrWhiteSpace([string](Get-WinForgeJsonValue -Object $view -Name "Next" -Default ""))
    $hideSummary = [bool](Get-WinForgeJsonValue -Object $view -Name "HideSummary" -Default $false)
    # "Nada a fazer" (outro antivírus no lugar, nada para limpar) também não muda rodando de novo; "Cancelado" muda.
    $nothing = ($null -ne $Outcome -and [string]$Outcome.Kind -eq "Skipped" -and -not (Test-WinForgeCanceledText -Text ([string]$Outcome.Detail)) -and -not (Test-WinForgeRestartingText -Text ([string]$Outcome.Detail)))
    # Os históricos, só de ver (sem veredito), mostrariam a mesma coisa de novo.
    $viewOnly = (-not $view.ShowBanner -and $script:LastAction -is [hashtable] -and [string]$script:LastAction["Command"] -in @("Show-WinForgeMaintenanceHistory", "Show-WinForgeChangeHistory"))
    $rerunButton.Visibility = $(if ($null -ne $script:LastAction -and -not $isTweak -and -not $isLong -and -not $hasNext -and -not $nothing -and -not $viewOnly) { "Visible" } else { "Collapsed" })

    # Uma tela que só mostra informações não tem veredito. Quando o resumo diz tudo o que ela escreveu (dados "rótulo :
    # valor", mensagens e seções, como as do Diagnóstico), ele é o conteúdo: aparece com toda a altura e os detalhes
    # técnicos ficam fechados, à mão. Com saída que o resumo não mostra (tabelas, texto de programas), ou quando a ação
    # quebrou, os detalhes se abrem: o conteúdo, ou o motivo, está lá. Com a faixa de resultado, o resumo também usa a
    # altura que sobra (o resumo do Otimizar tem uma linha por etapa), em vez de deixar a janela grande vazia embaixo.
    $script:SummaryExpanded = ($Status -ne "Failed" -and -not $hideSummary -and (($view.ShowBanner -and $script:ActivityEntries.Count -gt 0) -or (-not $view.ShowBanner -and (Test-GuiSummaryIsContent))))
    Set-GuiResultView -View $view

    if ($Status -eq "Failed" -or (-not $view.ShowBanner -and -not $script:SummaryExpanded)) {
        Set-GuiDetailsOpen -Open $true
    }
    else {
        Update-GuiSummaryHeight -Refresh

        # Com o resumo de etapas (o "Resumo" do fim do Otimizar), a tela abre nele, e não no fim da lista: é lá que está a
        # etapa que o botão da faixa resolve. Com um próximo passo na faixa de outra ação (as ameaças que pedem ação), abre
        # na última seção, a da lista: numa janela baixa, o fim dela deixaria a primeira ameaça cortada.
        if ($view.ShowBanner) { Show-GuiSummarySection -Title $(if ($hasNext -and -not $isLong) { "" } else { (Get-WinForgeText 'Resumo') }) }
    }

    if ($null -ne $inPlace -and -not $quietDone -and $script:CurrentPage -eq $inPlace.Page -and $pagesView.Visibility -eq "Visible") {
        # A chave terminou com algo a ler (ficou como estava, falhou, pede reinício): o resultado abre, como nas outras ações.
        Show-GuiRunView
    }

    # Se a pessoa estava em outra página, o resultado fica na faixa até ela ver; se a janela não está em primeiro
    # plano, o botão pisca na barra de tarefas e mostra a cor do resultado. A chave que terminou na linha não tem o que ver.
    $script:RunUnseen = ($runView.Visibility -ne "Visible" -and -not $quietDone)
    Update-GuiRunStrip

    if (-not $window.IsActive -and $view.Notify -and -not $quietDone) {
        Set-GuiTaskbarProgress -State $view.Taskbar -Value 1
        Set-GuiTaskbarFlash -On $true
    }

    if ($quietDone) {
        # A linha mostra o estado lido de novo; o leitor de tela ouve como o recurso ficou. O Modo escuro troca o tema da
        # janela (com a aparência Automática), e a página é refeita com o estado novo: aí o foco e o aviso vão para a linha
        # nova, quando a lista fica pronta.
        if ($script:CurrentPage -eq $inPlace.Page) {
            $themed = $false
            try { $themed = [bool](Update-GuiTheme) } catch { Write-Verbose "Tema: $($_.Exception.Message)" }

            if ($themed) {
                $script:TweakRefocus = @{ Id = [string]$inPlace.Id; Page = [string]$inPlace.Page; Refocus = [bool]$inPlace.HadFocus }
            }
            else {
                try { Update-GuiTweakRow -Id ([string]$inPlace.Id) -Refocus ([bool]$inPlace.HadFocus) } catch { Write-Verbose "Linha do ajuste: $($_.Exception.Message)" }
            }
        }
    }
    else {
        Send-GuiAnnouncement -Element $runStatus
    }

    if ($runView.Visibility -eq "Visible") {
        # O foco vai para o botão de destaque: o do próximo passo, quando há um, senão o Voltar.
        if ($hasNext) { [void]$resultAction.Focus() } else { [void]$backButton.Focus() }
    }
    elseif ($script:CurrentPage -eq "home") {
        # Os cartões do Início (última manutenção, espaço livre...) mudaram com a ação: lê de novo, no lugar.
        Request-GuiHomeRefresh -Force
    }

    # Uma ação pode ter trocado o tema do Windows (o ajuste Modo escuro): com "Automático", a janela acompanha já.
    try { [void](Update-GuiTheme) } catch { Write-Verbose "Tema: $($_.Exception.Message)" }

    # A atualização com um clique: o instalador da versão nova espera esta janela fechar para trocar os arquivos. Um
    # instante para a faixa "Instalando a..." aparecer antes.
    if ((Get-WinForgeAppExitRequest) -eq "update") { $script:UpdateExitTimer.Start() }
}

function Show-GuiUpdateResult {
    # Aberta pelo instalador depois de uma atualização: diz como ela terminou, uma vez.
    $update = $null

    try { $update = Read-WinForgeUpdateResult } catch { $update = $null }

    if ($null -eq $update) { return }

    $message = Get-WinForgeUpdateResultText -Result $update
    [void](Show-GuiMessage -Icon $(if ($message.Ok) { "Information" } else { "Warning" }) -Title $message.Title -Text $message.Text)
}

function Update-GuiRunView {
    try {
        if ($null -eq $script:GuiSession) { return }

        $atBottom = (($outputBox.VerticalOffset + $outputBox.ViewportHeight) -ge ($outputBox.ExtentHeight - 24))
        $update = Read-WinForgeGuiUpdate -Session $script:GuiSession

        foreach ($item in $update.Items) {
            $script:OutputBacklog.Enqueue($item)
        }

        # Desenhar a saída custa caro (o resumo classifica cada linha): cada volta do relógio desenha o que couber em
        # alguns milésimos e deixa o resto para a próxima, e a janela continua respondendo durante uma saída enorme.
        $shown = 0
        $watch = [System.Diagnostics.Stopwatch]::StartNew()

        while ($script:OutputBacklog.Count -gt 0 -and ($shown -lt $script:OutputMinItems -or $watch.ElapsedMilliseconds -lt $script:OutputBudgetMs)) {
            $item = $script:OutputBacklog.Dequeue()

            # Uma linha que a janela não consegue desenhar fica de fora da tela (o log da sessão tem todas): ela não pode
            # interromper uma ação de uma hora no meio do DISM.
            try {
                Add-GuiOutputItem -Item $item
            }
            catch {
                Write-Verbose "Linha da saída: $($_.Exception.Message)"
                $script:CurrentRuns = New-Object System.Collections.ArrayList
                $script:CurrentText = ""
            }

            $shown++
        }

        if ($shown -gt 0 -and $atBottom) {
            $outputBox.ScrollToEnd()
        }

        # A ação só termina na tela quando tudo o que ela escreveu já foi desenhado.
        $backlogEmpty = ($script:OutputBacklog.Count -eq 0)

        if ($update.Status -eq "Running") {
            $runElapsed.Text = "· $(Format-WinForgeClock -Span (Get-GuiRunElapsed))"
        }

        if ($update.ProgressVersion -ne $script:ProgressVersionShown) {
            $script:ProgressVersionShown = $update.ProgressVersion
            $info = $update.Progress

            if ($null -ne $info -and -not $info.Completed) {
                # A porcentagem da ferramenta vai no texto (a barra pode ser a do Otimizar inteiro), salvo quando ela já diz.
                $percentText = $(if ($info.Percent -ge 0 -and "$($info.Activity) $($info.Status)" -notmatch '[0-9]\s*%') { "$([int][Math]::Min(100, $info.Percent))%" } else { "" })
                $progressText.Text = (@($info.Activity, $info.Status, $percentText) | Where-Object { $_ }) -join " · "

                # Uma ação que ainda não escreveu nenhum título (o Verificar o PC lendo o PC, o ponto de restauração sendo
                # criado) mostra o que está fazendo em destaque, em vez de "Em andamento".
                if ($runStepText.Text -eq (Get-WinForgeText 'Em andamento') -and -not [string]::IsNullOrWhiteSpace([string]$info.Activity)) { Set-GuiRunStep -Text ([string]$info.Activity) }

                # Com etapas numeradas, a barra é a da execução inteira, e a porcentagem da ferramenta fica no texto. Sem
                # porcentagem (a verificação de vírus, o Windows Update procurando), a faixa corre por cima da barra: parada,
                # ela pareceria travada por minutos.
                $fraction = $(if ($info.Percent -ge 0) { [Math]::Min([double]100, [double]$info.Percent) / 100 } else { 0.0 })
                $overall = Update-GuiOverallProgress -Fraction $fraction
                $runProgress.Tag = $(if ($overall -and $info.Percent -lt 0) { "busy" } else { $null })

                if (-not $overall) {
                    if ($info.Percent -ge 0) {
                        $runProgress.IsIndeterminate = $false
                        $runProgress.Value = [Math]::Min([double]100, [double]$info.Percent)
                        Set-GuiTaskbarProgress -State Normal -Value ($runProgress.Value / 100)
                    }
                    else {
                        $runProgress.IsIndeterminate = $true
                        Set-GuiTaskbarProgress -State Indeterminate
                    }
                }
            }
            else {
                $progressText.Text = ""
                $runProgress.Tag = $null

                if (-not (Update-GuiOverallProgress -Fraction 0.0)) {
                    $runProgress.IsIndeterminate = $true
                    Set-GuiTaskbarProgress -State Indeterminate
                }
            }
        }

        # A pergunta espera o texto que veio antes dela (a explicação do que vai ser perguntado) aparecer na tela.
        if ($backlogEmpty -and $null -ne $update.Prompt -and $null -eq $script:ShownPrompt -and -not $update.Prompt.Done.WaitOne(0)) {
            # Uma pergunta é a ação esperando pela pessoa: traz a execução de volta e avisa na barra de tarefas.
            if ($runView.Visibility -ne "Visible") {
                Show-GuiRunView

                if (-not $window.IsActive) { Set-GuiTaskbarFlash -On $true }
            }

            Show-GuiPromptBar -Prompt $update.Prompt
        }

        if ($update.Status -ne "Running" -and $backlogEmpty) {
            Complete-GuiRun -Status $update.Status -Outcome $update.Outcome
        }
        else {
            Update-GuiRunStrip
        }
    }
    catch {
        $failure = $_.Exception.Message
        $elapsed = Get-GuiRunElapsed

        # Sem a saída na tela não há como acompanhar a ação: interrompe-a em vez de deixá-la rodando escondida. A sessão
        # é descartada (a próxima ação abre outra): parada assim, ela ficaria marcada como "em execução" para sempre e
        # recusaria qualquer ação nova até a janela ser reaberta.
        try { Stop-WinForgeGuiCommand -Session $script:GuiSession } catch { }
        try { Close-WinForgeGuiSession -Session $script:GuiSession } catch { }
        $script:GuiSession = $null
        $script:OutputBacklog.Clear()

        $script:Timer.Stop()
        $script:Running = $false
        $script:ShownPrompt = $null
        $promptBar.Visibility = "Collapsed"
        try { Restore-GuiAroundPrompt } catch { Write-Verbose "Pergunta: $($_.Exception.Message)" }
        $progressPanel.Visibility = "Collapsed"
        $stopButton.Visibility = "Collapsed"
        $backButton.Visibility = "Visible"
        $runStrip.Visibility = "Collapsed"
        Set-GuiTaskbarProgress -State None

        # O resultado aparece como o de uma ação interrompida (com os detalhes abertos), e não uma tela parada.
        try {
            $script:LastRunView = Get-WinForgeRunView -Status "Stopped" -Elapsed $elapsed
            Set-GuiResultView -View $script:LastRunView
            Set-GuiDetailsOpen -Open $true
        }
        catch {
            Set-GuiRunStatus -Text (Get-WinForgeText 'Não foi concluído') -DotColor $script:Theme.Bad
        }

        [void](Show-GuiMessage -Icon Error -Title (Get-WinForgeText 'Ação interrompida') -Text (Get-WinForgeText "A janela parou de acompanhar a ação e, por segurança, ela foi interrompida.`n`nO que já foi feito continua feito. Tente de novo; se acontecer outra vez, abra Sobre o WinForge > Pasta de logs e relatórios e envie o log mais recente ao suporte.`n`nDetalhe técnico: {0}" "$failure"))
    }
}

function Get-GuiModifierFlags {
    # As teclas Alt, Ctrl e Shift apertadas agora (System.Windows.Input.ModifierKeys como número).
    return [int][System.Windows.Input.Keyboard]::Modifiers
}

function Get-GuiBasePage {
    # A página aberta de verdade. Durante uma busca, é a de onde ela começou ("search" não é uma página).
    if ($script:CurrentPage -eq "search") { return $script:SearchBack }

    return $script:CurrentPage
}

function Request-GuiAdministrator {
    # A janela fica sem Administrador quando o aviso do Windows foi recusado ao abrir (ou o Windows não elevou). Quando uma
    # ação exige, oferece reabrir elevada, na mesma página e já rodando a ação pedida (Action = Id da navegação). Devolve
    # verdadeiro se a ação pode seguir agora (já é Administrador).
    param (
        [Parameter(Mandatory)][string]$Reason,
        [string]$Action = ""
    )

    if ($script:IsAdmin) { return $true }

    $answer = Show-GuiMessage -Buttons YesNo -Icon Question -Default Yes -Title (Get-WinForgeText 'Reabrir como Administrador?') -Text (Get-WinForgeText "{0}`n`nPara continuar, o WinForge precisa ser reaberto como Administrador, na mesma página." "$Reason") `
        -YesText (Get-WinForgeText 'Reabrir') -YesIcon "admin" -NoText (Get-WinForgeText 'Cancelar')

    if ($answer -ne "Yes") { return $false }

    $page = Get-GuiBasePage
    if ($page -notmatch '^[a-z]+$') { $page = "home" }

    if (Start-GuiRelaunch -Page $page -Action $Action -Elevated -Handover) {
        # A janela nova já foi aberta: fecha esta sem perguntar de novo.
        $script:ForceClose = $true
        $window.Close()
    }
    else {
        [void](Show-GuiMessage -Icon Warning -Title (Get-WinForgeText 'O WinForge continua sem Administrador') -Text (Get-WinForgeText 'O Windows não concedeu a permissão. Tente de novo e aceite o aviso do Windows (Controle de Conta de Usuário).'))
    }

    return $false
}

function Update-GuiHintPosition {
    # Move a dica para onde o cursor de um campo vazio fica (GetRectFromCharacterIndex), no mesmo contêiner da dica. Com
    # texto, nada muda: a dica está escondida, e um texto longo rolado para o lado deslocaria a conta.
    param (
        [Parameter(Mandatory)]$TextBox,
        [Parameter(Mandatory)]$Hint
    )

    if ([string]$TextBox.Text -ne "") { return }

    try {
        $caret = $TextBox.GetRectFromCharacterIndex(0)
        if ($caret.IsEmpty -or [double]::IsNaN($caret.X) -or [double]::IsInfinity($caret.X)) { return }

        $parent = [System.Windows.Media.VisualTreeHelper]::GetParent($Hint)
        $caretX = $TextBox.TranslatePoint((New-Object System.Windows.Point ($caret.X, 0)), $parent).X
        $hintX = $Hint.TranslatePoint((New-Object System.Windows.Point (0, 0)), $parent).X
        $margin = $Hint.Margin
        $left = $margin.Left + ($caretX - $hintX)

        if ([Math]::Abs($left - $margin.Left) -ge 0.5 -and $left -ge 0) {
            $Hint.Margin = New-Object System.Windows.Thickness ($left, $margin.Top, $margin.Right, $margin.Bottom)
        }
    }
    catch {
        # Sem a posição (campo ainda não desenhado), vale a margem do XAML.
    }
}

function Wait-GuiWarmup {
    # Uma ação pedida enquanto o host da janela ainda compila em segundo plano espera por ele (no máximo 30 segundos), em
    # vez de compilar outro igual ao mesmo tempo.
    $reader = $script:WarmupReader

    if ($null -eq $reader) { return }

    $deadline = (Get-Date).AddSeconds(30)

    while ($null -ne $reader.Ps -and (Get-Date) -lt $deadline) {
        if ($null -ne (Receive-WinForgeGuiRead -Reader $reader)) { break }
        Start-Sleep -Milliseconds 50
    }

    Close-WinForgeGuiReader -Reader $reader
    $script:WarmupReader = $null
}

function Start-GuiAction {
    param (
        [Parameter(Mandatory)][string]$Label,
        [Parameter(Mandatory)][string]$Command,
        [bool]$RequiresAdmin = $false,

        # Só para a página de ajustes: o ajuste que a lista deve mostrar de novo ao voltar da ação.
        [string]$FocusTweak = "",

        # O item da navegação que pediu a ação: se for preciso reabrir como Administrador, a janela nova já o roda.
        [string]$NavId = "",

        # A chave de um ajuste (FocusTweak): a ação roda com a página na tela, e a linha diz "Alterando…". A tela de
        # execução só abre se a ação perguntar algo ou terminar com algo a ler (Complete-GuiRun).
        [switch]$InPlace
    )

    if ($script:Running) {
        [void](Show-GuiMessage -Icon Information -Title (Get-WinForgeText 'Já existe uma ação em andamento') -Text (Get-WinForgeText "`"{0}`" ainda está rodando. Aguarde terminar ou use Parar.`n`nPara voltar a ela, use o botão Ver, na faixa no alto da página." "$($runTitle.Text)"))
        return
    }

    if ($RequiresAdmin -and -not (Request-GuiAdministrator -Reason (Get-WinForgeText 'A ação ''{0}'' precisa de permissão de Administrador.' "$Label") -Action $NavId)) {
        return
    }

    try {
        if ($null -eq $script:GuiSession) {
            Wait-GuiWarmup
            $script:GuiSession = New-WinForgeGuiSession -ModuleRoot $moduleRoot -Modules $script:ActionModules
        }

        Reset-GuiOutput
        Reset-GuiActivity
        $script:OutputBacklog.Clear()
        $script:LastAction = @{ Label = $Label; Command = $Command; RequiresAdmin = $RequiresAdmin; FocusTweak = $FocusTweak }
        $script:InPlaceRun = $null
        $script:RunPage = $script:CurrentPage
        $script:RunUnseen = $false
        $script:LastRunView = $null
        $runTitle.Text = $Label
        try { $runStatus.ClearValue([System.Windows.Automation.AutomationProperties]::NameProperty) } catch { Write-Verbose "Leitor de tela: $($_.Exception.Message)" }
        Set-GuiRunStatus -Text (Get-WinForgeText 'Em execução') -DotColor $script:Theme.Accent
        $runElapsed.Text = "· 00:00"
        Set-GuiRunStep -Text (Get-WinForgeText 'Em andamento')
        $progressText.Text = ""
        $runProgress.IsIndeterminate = $true
        $runProgress.Tag = $null
        $runProgress.Visibility = "Visible"
        $progressPanel.Visibility = "Visible"
        $resultBanner.Visibility = "Collapsed"
        $runHero.Visibility = "Visible"
        $stopButton.Visibility = "Visible"
        $backButton.Visibility = "Collapsed"
        $rerunButton.Visibility = "Collapsed"
        $promptBar.Visibility = "Collapsed"
        Set-GuiDetailsOpen -Open $false
        $copyButton.Content = (Get-WinForgeText 'Copiar')
        $saveButton.Content = (Get-WinForgeText 'Salvar')
        $script:ShownPrompt = $null
        $script:ProgressVersionShown = -1
        Set-GuiTaskbarFlash -On $false

        if ($InPlace -and -not [string]::IsNullOrEmpty($FocusTweak) -and $script:TweakRows.ContainsKey($FocusTweak)) {
            # A página fica: a linha diz que está mudando, e a faixa do alto não aparece enquanto ela está na tela.
            $script:InPlaceRun = @{ Id = $FocusTweak; Page = $script:CurrentPage; HadFocus = (Set-GuiTweakRowBusy -Id $FocusTweak) }
            $runStrip.Visibility = "Collapsed"
        }
        else {
            $pagesView.Visibility = "Collapsed"
            $runView.Visibility = "Visible"
            $runStrip.Visibility = "Collapsed"
            $window.UpdateLayout()

            # O foco do teclado sai da caixa de busca (ou do cartão clicado, que sumiu): um Enter a mais não abre a ação de novo.
            [void]$runView.Focus()
        }

        $started = Start-WinForgeGuiCommand -Session $script:GuiSession -Command $Command -Columns (Get-GuiOutputColumns)

        if (-not $started) { throw (Get-WinForgeText 'Já existe uma ação em execução.') }

        $script:Running = $true
        Set-GuiTaskbarProgress -State Indeterminate
        $script:Timer.Start()
    }
    catch {
        # A linha que dizia "Alterando…" volta ao estado lido.
        if ($null -ne $script:InPlaceRun) {
            $id = [string]$script:InPlaceRun.Id
            $script:InPlaceRun = $null
            try { Update-GuiTweakRow -Id $id } catch { Write-Verbose "Linha do ajuste: $($_.Exception.Message)" }
        }

        $pagesView.Visibility = "Visible"
        $runView.Visibility = "Collapsed"
        Set-GuiTaskbarProgress -State None
        [void](Show-GuiMessage -Icon Error -Title (Get-WinForgeText "`"{0}`" não começou" "$Label") -Text (Get-WinForgeText "Tente de novo. Se continuar, feche e abra o WinForge.`n`nDetalhe técnico: {0}" "$($_.Exception.Message)"))
    }
}


function Test-GuiInPlaceHere {
    # Se uma chave está mudando na própria linha e a página dela está na tela.
    return ($null -ne $script:InPlaceRun -and $script:Running -and $script:CurrentPage -eq [string]$script:InPlaceRun.Page -and $pagesView.Visibility -eq "Visible")
}


function Test-GuiQuietOutcome {
    # Se o fim de uma ação não tem nada a ler além do novo estado (a chave de um ajuste que mudou sem aviso: Quiet, de
    # Set-WinForgeResultView): ela terminou, deu certo e não pede reinício nem um próximo passo.
    param (
        [string]$Status,
        $Outcome = $null
    )

    if ($Status -ne "Completed" -or $null -eq $Outcome) { return $false }
    if ([string]$Outcome.Kind -ne "Ok") { return $false }
    if ([bool](Get-WinForgeJsonValue -Object $Outcome -Name "RebootRequired" -Default $false)) { return $false }
    if (-not [string]::IsNullOrWhiteSpace([string](Get-WinForgeJsonValue -Object $Outcome -Name "Next" -Default ""))) { return $false }

    return [bool](Get-WinForgeJsonValue -Object $Outcome -Name "Quiet" -Default $false)
}

function Get-GuiOutsideNote {
    # O que a dica e o leitor de tela dizem de um item que abre fora do WinForge: o site abre no navegador; os outros, no
    # Windows (uma janela dele ou o Explorador de Arquivos).
    param ([Parameter(Mandatory)]$Item)

    if ([string](Get-WinForgeJsonValue -Object $Item -Name "Shortcut" -Default "") -eq "Website") { return (Get-WinForgeText 'Abre no navegador') }
    return (Get-WinForgeText 'Abre no Windows')
}

function Open-GuiShortcut {
    param ([Parameter(Mandatory)][string]$Name, [string]$Title = "")

    if ([string]::IsNullOrWhiteSpace($Title)) { $Title = $Name }

    $opened = $false

    try {
        $opened = [bool](Open-WinForgeShortcut -Name $Name -Quiet)
    }
    catch {
        $opened = $false
    }

    # Recusar o aviso de Administrador do Windows (a Restauração do Sistema pede) foi a resposta da pessoa: sem mensagem.
    if (-not $opened) {
        $cancelled = $false
        try { $cancelled = ([string](Get-WinForgeShortcutLastError) -eq "Cancelled") } catch { $cancelled = $false }
        if ($cancelled) { return }
    }

    if (-not $opened) {
        # As pastas (Downloads e logs) existem em qualquer edição; para elas, "recurso inexistente" seria enganoso.
        $reason = $(if ($Name -in @("Downloads", "LogFolder")) { (Get-WinForgeText 'O Explorador de Arquivos não abriu a pasta. Tente abri-la manualmente.') } elseif ($Name -eq "Website") { (Get-WinForgeText 'O navegador não abriu. O endereço do site é {0}.' "$(Get-WinForgeWebsiteUrl)") } else { (Get-WinForgeText 'O recurso pode não existir nesta edição do Windows.') })
        [void](Show-GuiMessage -Icon Warning -Title (Get-WinForgeText "`"{0}`" não abriu" "$Title") -Text $reason)
    }
}

function Get-GuiNavCommand {
    # O comando de um cartão vem da tabela de navegação; só nomes de função válidos chegam ao executor.
    param ([Parameter(Mandatory)]$Item)

    if ([string]$Item.Command -notmatch '^[A-Za-z]+-[A-Za-z0-9]+$') {
        throw (Get-WinForgeText 'Comando inválido na navegação: {0}' "$($Item.Command)")
    }

    return [string]$Item.Command
}

function Get-GuiTweakCommand {
    # O comando da chave de um ajuste. A chave já é a confirmação; -Ask deixa a ação perguntar (estado não identificado).
    # -Want: o estado que a chave pediu ("On" ou "Off"); se o Windows já está assim, a ação não muda nada.
    param (
        [Parameter(Mandatory)][string]$Id,
        [switch]$Ask,
        [ValidateSet("", "On", "Off")][string]$Want = ""
    )

    if ($Id -notmatch '^[a-z0-9][a-z0-9-]*$') {
        throw (Get-WinForgeText 'Identificador de ajuste inválido: {0}' "$Id")
    }

    $command = "Invoke-WinForgeTweakToggle -Tweak (Get-WinForgeTweakById -Id '$Id')"
    if (-not $Ask) { $command += " -AlreadyConfirmed" }
    if ($Want) { $command += " -Want $Want" }

    return $command
}

# --- Páginas -------------------------------------------------------------------------------------------
function Invoke-GuiDeferred {
    # Roda um bloco logo depois de a página aparecer, para a tela não esperar leituras lentas do sistema.
    param ([Parameter(Mandatory)][scriptblock]$Action)

    $script:DeferredAction = $Action
    $script:DeferredTimer.Stop()
    $script:DeferredTimer.Start()
}

function Invoke-GuiNavItem {
    # Clique em um item da tabela de navegação: abre a janela do Windows (atalho) ou roda a ação aqui dentro.
    param ([Parameter(Mandatory)]$Item)

    if ($Item.Kind -eq "Shortcut") {
        Open-GuiShortcut -Name $Item.Shortcut -Title $Item.Label
        return
    }

    if ($Item.Kind -eq "Page") {
        # Resultado de busca que leva a uma página (ou a um ajuste do Windows): a página destaca o ajuste e, se ele está
        # no grupo recolhido, abre o grupo.
        $focus = Get-WinForgeSearchFocus -Item $Item

        if ($focus.Advanced) { $script:TweaksAdvancedOpen = $true }

        # A Aparência ou o Idioma achados na busca: o foco do teclado vai para a opção marcada do cartão, como depois de
        # trocar o tema.
        $script:AppearanceRefocus = ($focus.Section -eq "appearance")
        $script:LanguageRefocus = ($focus.Section -eq "language")

        try {
            Show-GuiPage -Id ([string]$Item.Command) -FocusTweak $focus.TweakId
        }
        finally {
            $script:AppearanceRefocus = $false
            $script:LanguageRefocus = $false
        }

        if ($null -ne $script:AppearanceFocusTarget) {
            [void]$script:AppearanceFocusTarget.Focus()
            $script:AppearanceFocusTarget = $null
        }

        if ($null -ne $script:LanguageFocusTarget) {
            [void]$script:LanguageFocusTarget.Focus()
            $script:LanguageFocusTarget = $null
        }

        return
    }

    try {
        Start-GuiAction -Label $Item.Label -Command (Get-GuiNavCommand -Item $Item) -RequiresAdmin ([bool]$Item.RequiresAdmin) -NavId ([string]$Item.Id)
    }
    catch {
        [void](Show-GuiMessage -Icon Error -Title (Get-WinForgeText "`"{0}`" não começou" "$($Item.Label)") -Text $_.Exception.Message)
    }
}

function New-GuiActionRow {
    <#
    Uma linha de lista (estilo RowButton): o ícone do assunto, o nome, uma linha do que faz e, no fim, o escudo (pede
    Administrador, como nos botões do Windows) e a seta, ou o ícone de "abre fora" num atalho do Windows. A frase inteira
    do item (Detail, quando a da linha é a curta) aparece ao passar o mouse e o leitor de tela a ouve. Context: de onde
    vem o item (a página, nos resultados da busca, ou "Página > Categoria"); EnterHint: a tecla Enter no fim (o primeiro
    resultado, que o Enter da caixa abre).
    #>
    param (
        [Parameter(Mandatory)]$Item,
        [string]$Context = "",
        [switch]$EnterHint,

        # Sem o ícone do assunto: a linha dentro de um grupo de ajustes começa o texto onde as chaves começam (a UX13 da R38).
        [switch]$NoIcon
    )

    $needsAdmin = ([bool]$Item.RequiresAdmin -and -not $script:IsAdmin)
    $outside = ([string]$Item.Kind -eq "Shortcut")
    $about = [string]$Item.Description
    $detail = [string](Get-WinForgeJsonValue -Object $Item -Name "Detail" -Default "")

    $button = New-Object System.Windows.Controls.Button
    $button.Style = $window.FindResource("RowButton")
    $button.Tag = $Item

    $row = New-Object System.Windows.Controls.DockPanel
    $row.LastChildFill = $true

    if (-not $NoIcon) {
        $icon = New-GuiIcon -Name (Get-WinForgeIconName -Id ([string]$Item.Id)) -Size 20 -Color $script:Theme.Text
        $icon.Margin = New-Object System.Windows.Thickness (0, 0, 16, 0)
        Set-GuiDock -Element $icon -Side "Left"
        [void]$row.Children.Add($icon)
    }

    $end = New-Object System.Windows.Controls.StackPanel
    $end.Orientation = "Horizontal"
    $end.VerticalAlignment = "Center"
    $end.Margin = New-Object System.Windows.Thickness (16, 0, 0, 0)

    if ($EnterHint) {
        $key = New-GuiKeyChip -Text (Get-WinForgeText 'Enter')
        $key.VerticalAlignment = "Center"
        $key.Margin = New-Object System.Windows.Thickness (0, 0, 12, 0)
        [void]$end.Children.Add($key)
    }

    if ($needsAdmin) {
        $shield = New-GuiIcon -Name "admin" -Size 16 -Color $script:Theme.Muted
        $shield.Margin = New-Object System.Windows.Thickness (0, 0, 12, 0)
        [void]$end.Children.Add($shield)
    }

    [void]$end.Children.Add((New-GuiIcon -Name $(if ($outside) { "external" } else { "chevron-right" }) -Size 16 -Color $script:Theme.Muted))
    Set-GuiDock -Element $end -Side "Right"
    [void]$row.Children.Add($end)

    $texts = New-Object System.Windows.Controls.StackPanel
    $texts.VerticalAlignment = "Center"

    $lines = @()
    if (-not [string]::IsNullOrEmpty($Context)) { $lines += New-GuiText -Text $Context -Size $script:Type.Caption -Color $script:Theme.Muted }
    $lines += New-GuiText -Text ([string]$Item.Label) -Size $script:Type.Body -Bold $true
    if (-not [string]::IsNullOrEmpty($about)) { $lines += New-GuiText -Text $about -Size $script:Type.Caption -Color $script:Theme.Muted }

    # Uma linha para cada texto: o que não cabe termina em reticências e aparece inteiro na dica.
    foreach ($line in $lines) {
        $line.TextWrapping = "NoWrap"
        $line.TextTrimming = "CharacterEllipsis"
        [void]$texts.Children.Add($line)
    }

    [void]$row.Children.Add($texts)
    $button.Content = $row

    # A dica e o leitor de tela dizem o que a linha mostra em símbolo (o escudo, o "abre fora").
    $note = $(if ($outside) { (Get-GuiOutsideNote -Item $Item) } elseif ($needsAdmin) { (Get-WinForgeText 'Pede Administrador ao executar') } else { "" })
    $tip = @(@($(if ($detail) { $detail } else { $about }), $note) | Where-Object { -not [string]::IsNullOrEmpty($_) })
    if ($tip.Count -gt 0) { $button.ToolTip = ($tip -join "`n") }

    # O ">" do caminho é para os olhos: o leitor de tela o leria ("maior"). Falado, o caminho vai com vírgulas.
    $spoken = $(if ($Context) { "$($Item.Label), $($Context.Replace(' > ', ', ')). $about" } else { "$($Item.Label). $about" })
    if ($outside) { $spoken += ". $(Get-GuiOutsideNote -Item $Item)" }
    elseif ($needsAdmin) { $spoken += (Get-WinForgeText '. Pede Administrador ao executar') }
    Set-GuiAutomationName -Element $button -Name $spoken

    if ($detail) {
        try { [System.Windows.Automation.AutomationProperties]::SetHelpText($button, $detail) } catch { Write-Verbose "Leitor de tela: $($_.Exception.Message)" }
    }

    if ($EnterHint) {
        [System.Windows.Automation.AutomationProperties]::SetHelpText($button, (Get-WinForgeText 'Primeiro resultado: o Enter na caixa de busca abre este'))
    }

    $button.Add_Click({
        param ($sender, $eventArgs)
        Invoke-GuiNavItem -Item $sender.Tag
    })

    return $button
}

function New-GuiRowGroup {
    <#
    Um grupo de linhas (New-GuiActionRow) com contorno e cantos de 8, como nas Configurações do Windows; um traço fino
    separa uma linha da outra (Add-GuiRowToGroup). O conteúdo é recortado nos cantos: o fundo de uma linha sob o mouse não
    passa da curva. Devolve Element (o que entra na página) e Rows (onde entram as linhas).
    #>
    $rows = New-Object System.Windows.Controls.StackPanel
    $border = New-GuiPanelBorder -Padding (New-Object System.Windows.Thickness 0) -Content $rows
    $border.Margin = New-Object System.Windows.Thickness (0, 0, 12, 0)

    $rows.Add_SizeChanged({
        param ($sender, $eventArgs)

        try {
            $sender.Clip = New-Object System.Windows.Media.RectangleGeometry ((New-Object System.Windows.Rect (0, 0, $sender.ActualWidth, $sender.ActualHeight)), 7, 7)
        }
        catch {
            Write-Verbose "Recorte do grupo: $($_.Exception.Message)"
        }
    })

    return [PSCustomObject]@{ Element = $border; Rows = $rows }
}

function Add-GuiRowToGroup {
    # Põe a linha no grupo, com um traço fino separando-a da anterior.
    param (
        [Parameter(Mandatory)]$Group,
        [Parameter(Mandatory)]$Row
    )

    if ($Group.Rows.Children.Count -gt 0) {
        $line = New-Object System.Windows.Controls.Border
        $line.Height = 1
        $line.Background = New-GuiBrush $script:Theme.Line
        $line.IsHitTestVisible = $false
        [void]$Group.Rows.Children.Add($line)
    }

    [void]$Group.Rows.Children.Add($Row)
}

function New-GuiHeroCard {
    <#
    O destaque de uma página: o caminho recomendado (o item com Accent), maior, com o ícone cheio na cor de destaque e, à
    direita, o botão que o faz, com o verbo do item (ButtonText: "Limpar agora", "Reparar"...), como nas Configurações do
    Windows. O botão é o principal da página; o resto vem em listas (New-GuiActionRow). Sem ButtonText, o cartão inteiro é
    o botão, com a etiqueta "Recomendado".
    #>
    param ([Parameter(Mandatory)]$Item)

    $needsAdmin = ([bool]$Item.RequiresAdmin -and -not $script:IsAdmin)
    $outside = ([string]$Item.Kind -eq "Shortcut")
    $about = [string]$Item.Description
    $detail = [string](Get-WinForgeJsonValue -Object $Item -Name "Detail" -Default "")
    $verb = [string](Get-WinForgeJsonValue -Object $Item -Name "ButtonText" -Default "")

    $note = $(if ($outside) { (Get-GuiOutsideNote -Item $Item) } elseif ($needsAdmin) { (Get-WinForgeText 'Pede Administrador ao executar') } else { "" })
    $tip = @(@($(if ($detail) { $detail } else { $about }), $note) | Where-Object { -not [string]::IsNullOrEmpty($_) })

    $row = New-Object System.Windows.Controls.DockPanel
    $row.LastChildFill = $true

    $tile = New-Object System.Windows.Controls.Border
    $tile.Width = 48
    $tile.Height = 48
    $tile.CornerRadius = New-Object System.Windows.CornerRadius 8
    $tile.Background = New-GuiBrush $script:Theme.Accent
    $tile.Margin = New-Object System.Windows.Thickness (0, 0, 18, 0)
    $tile.VerticalAlignment = "Center"
    $tile.Child = New-GuiIcon -Name (Get-WinForgeIconName -Id ([string]$Item.Id)) -Size 24 -Color $script:Theme.OnAccent
    Set-GuiDock -Element $tile -Side "Left"
    [void]$row.Children.Add($tile)

    $end = New-Object System.Windows.Controls.StackPanel
    $end.Orientation = "Horizontal"
    $end.VerticalAlignment = "Center"
    $end.Margin = New-Object System.Windows.Thickness (16, 0, 0, 0)

    if ($verb) {
        # O botão diz o que faz; o escudo (pede Administrador) ou o "abre fora" vêm nele, como nos botões do Windows.
        $go = New-GuiButton -Text $verb -Kind Primary -Icon $(if ($outside) { "external" } elseif ($needsAdmin) { "admin" } else { "" }) -Tag $Item
        $go.VerticalAlignment = "Center"
        if ($tip.Count -gt 0) { $go.ToolTip = ($tip -join "`n") }
        Set-GuiAutomationName -Element $go -Name "$($verb): $($Item.Label)$(if ($outside) { ". $(Get-GuiOutsideNote -Item $Item)" } elseif ($needsAdmin) { (Get-WinForgeText '. Pede Administrador ao executar') })"
        if ($detail) {
            try { [System.Windows.Automation.AutomationProperties]::SetHelpText($go, $detail) } catch { Write-Verbose "Leitor de tela: $($_.Exception.Message)" }
        }
        $go.Add_Click({
            param ($sender, $eventArgs)
            Invoke-GuiNavItem -Item $sender.Tag
        })
        [void]$end.Children.Add($go)
    }
    else {
        $chip = New-GuiChip -Text (Get-WinForgeText 'Recomendado')
        $chip.VerticalAlignment = "Center"
        $chip.Margin = New-Object System.Windows.Thickness (0, 0, 12, 0)
        [void]$end.Children.Add($chip)

        if ($needsAdmin) {
            $shield = New-GuiIcon -Name "admin" -Size 16 -Color $script:Theme.Muted
            $shield.Margin = New-Object System.Windows.Thickness (0, 0, 12, 0)
            [void]$end.Children.Add($shield)
        }

        [void]$end.Children.Add((New-GuiIcon -Name $(if ($outside) { "external" } else { "chevron-right" }) -Size 16 -Color $script:Theme.Muted))
    }

    Set-GuiDock -Element $end -Side "Right"
    [void]$row.Children.Add($end)

    $texts = New-Object System.Windows.Controls.StackPanel
    $texts.VerticalAlignment = "Center"

    # O nome em negrito, na fonte dos títulos, como a frase da nota de saúde no Início.
    $title = New-GuiText -Text ([string]$Item.Label) -Size $script:Type.Subtitle -Display
    $title.TextWrapping = "NoWrap"
    $title.TextTrimming = "CharacterEllipsis"
    [void]$texts.Children.Add($title)

    if (-not [string]::IsNullOrEmpty($about)) {
        $line = New-GuiText -Text $about -Size $script:Type.Body -Color $script:Theme.Muted
        $line.TextWrapping = "NoWrap"
        $line.TextTrimming = "CharacterEllipsis"
        [void]$texts.Children.Add($line)
    }

    [void]$row.Children.Add($texts)

    if ($verb) {
        # Um painel (o clique é no botão), na largura toda da página, no fundo do cartão da nota de saúde.
        $card = New-GuiPanelBorder -Background $script:Theme.Hero -Padding (New-Object System.Windows.Thickness (20, 18, 20, 18)) -Content $row
        $card.Margin = New-Object System.Windows.Thickness (0, 0, 12, 4)
        if ($tip.Count -gt 0) { $texts.ToolTip = ($tip -join "`n") }
        return $card
    }

    $button = New-Object System.Windows.Controls.Button
    $button.Style = $window.FindResource("CardButton")
    $button.Background = New-GuiBrush $script:Theme.Hero
    $button.Tag = $Item

    # A largura toda da página (o estilo dos cartões usa a de uma coluna).
    $button.Width = [double]::NaN
    $button.HorizontalAlignment = "Stretch"
    $button.Margin = New-Object System.Windows.Thickness (0, 0, 12, 4)
    $button.Padding = New-Object System.Windows.Thickness (20, 18, 20, 18)
    $button.VerticalContentAlignment = "Center"
    $button.Content = $row

    if ($tip.Count -gt 0) { $button.ToolTip = ($tip -join "`n") }

    $spoken = "$($Item.Label). $about$(Get-WinForgeText '. Recomendado')"
    if ($outside) { $spoken += ". $(Get-GuiOutsideNote -Item $Item)" }
    elseif ($needsAdmin) { $spoken += (Get-WinForgeText '. Pede Administrador ao executar') }
    Set-GuiAutomationName -Element $button -Name $spoken

    if ($detail) {
        try { [System.Windows.Automation.AutomationProperties]::SetHelpText($button, $detail) } catch { Write-Verbose "Leitor de tela: $($_.Exception.Message)" }
    }

    $button.Add_Click({
        param ($sender, $eventArgs)
        Invoke-GuiNavItem -Item $sender.Tag
    })

    return $button
}

function Invoke-GuiSetupStep {
    # Um passo da configuração inicial (no fim do Início): roda o item da navegação (ou o comando próprio do passo).
    param ([Parameter(Mandatory)]$Step)

    $item = Get-WinForgeNavItem -Id ([string]$Step.NavId)

    if ([string]$Step.Command) {
        Start-GuiAction -Label $(if ($null -ne $item) { [string]$item.Label } else { [string]$Step.Label }) -Command ([string]$Step.Command) -RequiresAdmin ([bool]$Step.Admin) -NavId ([string]$Step.NavId)
    }
    elseif ($null -ne $item) {
        Invoke-GuiNavItem -Item $item
    }
}

function New-GuiSetupCard {
    <#
    A configuração inicial, no fim do Início, enquanto faltar algum passo (Get-WinForgeSetupChecklist): o atalho, o monitor
    na bandeja e a manutenção mensal. Uma faixa de uma linha com o próximo passo (o ícone e o nome), quantos estão feitos,
    "Agora não" (fecha a faixa de vez; os três continuam em Sobre o WinForge e em Manutenção) e o botão que faz o passo.
    Checklist: a lista já lida (Update-GuiSetupCard). $null quando a faixa não aparece.
    #>
    param ($Checklist)

    if ($null -eq $Checklist -or -not $Checklist.Visible) { return $null }

    $steps = @($Checklist.Steps)
    $done = @($steps | Where-Object { $_.Done }).Count
    $next = @($steps | Where-Object { -not $_.Done }) | Select-Object -First 1

    if ($null -eq $next) { return $null }

    $row = New-Object System.Windows.Controls.DockPanel
    $row.LastChildFill = $true

    $glyph = New-GuiIcon -Name ([string]$next.Icon) -Size 20 -Color $script:Theme.Muted
    $glyph.Margin = New-Object System.Windows.Thickness (0, 0, 16, 0)
    Set-GuiDock -Element $glyph -Side "Left"
    [void]$row.Children.Add($glyph)

    $end = New-Object System.Windows.Controls.StackPanel
    $end.Orientation = "Horizontal"
    $end.VerticalAlignment = "Center"
    $end.Margin = New-Object System.Windows.Thickness (16, 0, 0, 0)

    $later = New-GuiButton -Text (Get-WinForgeText 'Agora não') -Kind Ghost
    $later.VerticalAlignment = "Center"
    $later.Margin = New-Object System.Windows.Thickness (0, 0, 12, 0)
    $later.ToolTip = (Get-WinForgeText 'O cartão não volta; os três ficam em Sobre o WinForge e em Manutenção.')
    $later.Add_Click({
        param ($sender, $eventArgs)
        Close-GuiSetupCard -Button $sender
    })
    [void]$end.Children.Add($later)

    $needsAdmin = ([bool]$next.Admin -and -not $script:IsAdmin)
    $button = New-GuiButton -Text ([string]$next.Button) -Icon $(if ($needsAdmin) { "admin" } else { "" }) -Tag $next
    $button.VerticalAlignment = "Center"
    $button.ToolTip = $(if ($needsAdmin) { (Get-WinForgeText "{0}`nPede Administrador ao executar." "$($next.Description)") } else { [string]$next.Description })
    Set-GuiAutomationName -Element $button -Name "$($next.Button): $($next.Label)"
    $button.Add_Click({
        param ($sender, $eventArgs)
        Invoke-GuiSetupStep -Step $sender.Tag
    })
    [void]$end.Children.Add($button)

    Set-GuiDock -Element $end -Side "Right"
    [void]$row.Children.Add($end)

    $texts = New-Object System.Windows.Controls.StackPanel
    $texts.VerticalAlignment = "Center"

    $title = New-GuiText -Text ([string]$next.Label) -Size $script:Type.Body -Bold $true
    $title.TextWrapping = "NoWrap"
    $title.TextTrimming = "CharacterEllipsis"
    [void]$texts.Children.Add($title)

    $progress = (Get-WinForgeText 'Configuração inicial · {0} de {1} etapas concluídas' "$done" "$($steps.Count)")
    $line = New-GuiText -Text $progress -Size $script:Type.Body -Color $script:Theme.Muted
    $line.TextWrapping = "NoWrap"
    $line.TextTrimming = "CharacterEllipsis"
    [void]$texts.Children.Add($line)

    [void]$row.Children.Add($texts)

    $card = New-GuiPanelBorder -Padding (New-Object System.Windows.Thickness (20, 14, 16, 14)) -Content $row
    $card.Margin = New-Object System.Windows.Thickness (0, 32, 12, 0)
    $card.ToolTip = (@($steps | ForEach-Object { "$(if ($_.Done) { '✓' } else { '•' }) $($_.Label): $($_.Description)" }) -join "`n")
    Set-GuiAutomationName -Element $card -Name "$(Get-WinForgeText 'Configuração inicial'): $($next.Label). $progress"

    return $card
}

function Update-GuiSetupCard {
    <#
    Põe (ou tira) a configuração inicial no lugar dela, no fim do Início ($script:HomeSetup). ScheduleDone: se a
    manutenção mensal desta pasta está agendada, que vem da leitura do Início (Read-WinForgeHomeSchedule): ela consulta o
    Agendador de Tarefas fora da thread da janela, com prazo, e um Agendador travado não congela a janela. Os outros dois
    passos são leituras rápidas (arquivos e registro). Refaz a faixa só quando ela muda: um botão com o foco não some à toa.
    #>
    param ([bool]$ScheduleDone = $false)

    if ($null -eq $script:HomeSetup) { return }

    $checklist = $null

    try { $checklist = Get-WinForgeSetupChecklist -ScheduleDone $ScheduleDone } catch { $checklist = $null }

    $key = ""

    if ($null -ne $checklist -and $checklist.Visible) {
        $key = (@($checklist.Steps) | ForEach-Object { "$($_.Id)=$([bool]$_.Done)" }) -join ","
        $key += ";admin=$([bool]$script:IsAdmin)"
    }

    if ($key -eq $script:HomeSetupKey -and $script:HomeSetup.Children.Count -eq [int]($key -ne "")) { return }

    $script:HomeSetupKey = $key
    $script:HomeSetup.Children.Clear()

    $card = New-GuiSetupCard -Checklist $checklist
    if ($null -ne $card) { [void](Add-GuiHomePart -Element $card -Name (Get-WinForgeText 'Configuração inicial') -Panel $script:HomeSetup) }
}

function Close-GuiSetupCard {
    # "Agora não": a faixa fecha de vez e sai no lugar, sem refazer a página (o que leria o PC de novo, no meio de uma
    # leitura, e animaria a entrada). O foco do teclado vai para o que vem antes dela, em vez de se perder com o botão.
    param ($Button = $null)

    Close-WinForgeSetupCard

    if ($null -ne $Button) {
        try { [void]$Button.MoveFocus((New-Object System.Windows.Input.TraversalRequest ([System.Windows.Input.FocusNavigationDirection]::Previous))) } catch { Write-Verbose "Foco: $($_.Exception.Message)" }
    }

    $script:HomeSetupKey = ""
    if ($null -ne $script:HomeSetup) { $script:HomeSetup.Children.Clear() }
}

function New-GuiHomeSkeleton {
    # A barra cinza no lugar de um valor que ainda não chegou (sem texto piscando "Lendo..."): Set-GuiHomeCardText a
    # esconde quando o valor chega.
    param ([double]$Width, [double]$Height, $Margin = $null)

    $skeleton = New-Object System.Windows.Controls.Border
    $skeleton.Width = $Width
    $skeleton.Height = [Math]::Round($Height * $script:TextScale)
    $skeleton.CornerRadius = New-Object System.Windows.CornerRadius 4
    $skeleton.Background = New-GuiBrush $script:Theme.Line
    $skeleton.HorizontalAlignment = "Left"
    if ($null -ne $Margin) { $skeleton.Margin = $Margin }

    return $skeleton
}

function New-GuiHomeCard {
    <#
    Um cartão de "Seu PC" no Início: o ícone e o nome no alto, com a seta quando o cartão leva a uma tela; o valor grande
    (na cor do nível, e que diminui até caber, sem cortar); embaixo, o complemento. O do disco tem também quanto está em
    uso, à direita, e a barra de uso (Bar: o espaço usado; o resto, o trilho). Enquanto o valor não chega, uma barra cinza
    no lugar dele. A largura é a da coluna (Set-GuiHomeColumns), e a altura, a do maior cartão da fileira. Devolve as
    partes que Set-GuiHomeCardText preenche, com as linhas de texto (Rows) que Get-GuiHomeFitWidth mede.
    #>
    param (
        [Parameter(Mandatory)][string]$Id,
        [Parameter(Mandatory)][string]$Label
    )

    $stack = New-Object System.Windows.Controls.StackPanel

    $head = New-Object System.Windows.Controls.DockPanel
    $icon = New-GuiIcon -Name (Get-WinForgeIconName -Id "fact.$Id") -Size 18 -Color $script:Theme.Muted
    $icon.Margin = New-Object System.Windows.Thickness (0, 0, 10, 0)
    Set-GuiDock -Element $icon -Side "Left"
    [void]$head.Children.Add($icon)

    $target = Get-WinForgeHomeFactTarget -Id $Id
    $item = $null

    if (-not [string]::IsNullOrEmpty($target)) { $item = Get-WinForgeNavItem -Id $target }

    if ($null -ne $item) {
        $chevron = New-GuiIcon -Name "chevron-right" -Size 14 -Color $script:Theme.Dim
        $chevron.Margin = New-Object System.Windows.Thickness (8, 0, 0, 0)
        Set-GuiDock -Element $chevron -Side "Right"
        [void]$head.Children.Add($chevron)
    }

    $name = New-GuiText -Text $Label -Size $script:Type.Body -Color $script:Theme.Muted
    $name.TextWrapping = "NoWrap"
    $name.TextTrimming = "CharacterEllipsis"
    $name.VerticalAlignment = "Center"
    [void]$head.Children.Add($name)
    [void]$stack.Children.Add($head)

    $skeleton = New-GuiHomeSkeleton -Width 120 -Height 22 -Margin (New-Object System.Windows.Thickness (0, 18, 0, 8))
    [void]$stack.Children.Add($skeleton)

    $value = New-GuiText -Text "" -Size $script:Type.Title -Display
    $valueBox = New-GuiValueBox -Text $value
    $valueBox.Margin = New-Object System.Windows.Thickness (0, 12, 0, 0)
    $valueBox.Visibility = "Collapsed"
    [void]$stack.Children.Add($valueBox)

    # O complemento à esquerda e, no disco, quanto está em uso à direita, na mesma linha.
    $foot = New-Object System.Windows.Controls.DockPanel
    $foot.Margin = New-Object System.Windows.Thickness (0, 4, 0, 0)

    $extra = New-GuiText -Text "" -Size $script:Type.Body -Color $script:Theme.Muted
    $extra.TextWrapping = "NoWrap"
    $extra.Margin = New-Object System.Windows.Thickness (12, 0, 0, 0)
    $extra.Visibility = "Collapsed"
    Set-GuiDock -Element $extra -Side "Right"
    [void]$foot.Children.Add($extra)

    $detail = New-GuiText -Text "" -Size $script:Type.Body -Color $script:Theme.Muted
    $detail.TextWrapping = "NoWrap"
    $detail.TextTrimming = "CharacterEllipsis"
    $detail.Visibility = "Collapsed"
    [void]$foot.Children.Add($detail)
    [void]$stack.Children.Add($foot)

    $track = $null
    $usedColumn = $null
    $freeColumn = $null
    $fill = $null

    if ($Id -eq "disk") {
        # A barra de uso: duas colunas proporcionais (o usado e o livre), sem medir a largura na tela.
        $track = New-Object System.Windows.Controls.Grid
        $track.Height = [Math]::Max(4, [Math]::Round(6 * [Math]::Sqrt($script:TextScale)))
        $track.Margin = New-Object System.Windows.Thickness (0, 14, 0, 0)
        $track.Visibility = "Collapsed"
        $track.IsHitTestVisible = $false

        $usedColumn = New-Object System.Windows.Controls.ColumnDefinition
        $freeColumn = New-Object System.Windows.Controls.ColumnDefinition
        [void]$track.ColumnDefinitions.Add($usedColumn)
        [void]$track.ColumnDefinitions.Add($freeColumn)

        $rail = New-Object System.Windows.Controls.Border
        $rail.CornerRadius = New-Object System.Windows.CornerRadius 3
        $rail.Background = New-GuiBrush $script:Theme.Track
        [System.Windows.Controls.Grid]::SetColumnSpan($rail, 2)
        [void]$track.Children.Add($rail)

        $fill = New-Object System.Windows.Controls.Border
        $fill.CornerRadius = New-Object System.Windows.CornerRadius 3
        $fill.Background = New-GuiBrush $script:Theme.Bar
        [void]$track.Children.Add($fill)

        [void]$stack.Children.Add($track)
    }

    if ($null -ne $item) {
        $card = New-Object System.Windows.Controls.Button
        $card.Style = $window.FindResource("CardButton")
        $card.Tag = $item
        $card.Content = $stack
        Set-GuiAutomationName -Element $card -Name (Get-WinForgeText '{0}: lendo. Abre: {1}' "$($Label)" "$($item.Label)")
        $card.Add_Click({
            param ($sender, $eventArgs)
            Invoke-GuiNavItem -Item $sender.Tag
        })
    }
    else {
        $card = New-GuiPanelBorder -Padding (New-Object System.Windows.Thickness (20, 18, 20, 18)) -Content $stack
        Set-GuiAutomationName -Element $card -Name (Get-WinForgeText '{0}: lendo' "$($Label)")
    }

    # A largura é a da coluna da fileira, e não a de um cartão de ação (CardWidth).
    $card.Width = [double]::NaN
    $card.HorizontalAlignment = "Stretch"
    $card.Margin = New-Object System.Windows.Thickness (0, 0, 12, 12)
    if ($card -is [System.Windows.Controls.Button]) { $card.Padding = New-Object System.Windows.Thickness (20, 18, 20, 18) }

    return [PSCustomObject]@{
        Kind = "Card"; Id = $Id; Label = $Label; Holder = $card; Card = $card; Value = $value; ValueBox = $valueBox; Skeleton = $skeleton
        Detail = $detail; Extra = $extra; Track = $track; UsedColumn = $usedColumn; FreeColumn = $freeColumn; Fill = $fill
        Opens = $(if ($null -ne $item) { [string]$item.Label } else { "" }); Strip = $null
        Content = $stack; Rows = @($head, $foot); Grid = $null
    }
}

function New-GuiHomeStrip {
    <#
    A linha do Início com a última manutenção, o reinício pendente e, num notebook, a bateria: um cartão dividido em partes
    iguais, cada uma com o ícone, o nome e o valor à direita; o clique leva à tela do assunto. Uma parte que só existe em
    alguns PCs (a bateria) só aparece quando a leitura confirma, e as colunas se refazem (Update-GuiHomeStripLayout).
    Numa janela estreita, as partes ficam uma embaixo da outra. Devolve o cartão (Card) e as partes de cada fato (Parts).
    #>
    param (
        [Parameter(Mandatory)][string[]]$Ids,
        [Parameter(Mandatory)]$Labels,
        [string[]]$Optional = @()
    )

    $grid = New-Object System.Windows.Controls.Primitives.UniformGrid
    $grid.Rows = 0
    $grid.Columns = $Ids.Count
    $strip = [PSCustomObject]@{ Grid = $grid; Cells = @() }
    $parts = @{}

    foreach ($id in $Ids) {
        $label = [string]$Labels[$id]
        $target = Get-WinForgeHomeFactTarget -Id $id
        $item = $null
        if (-not [string]::IsNullOrEmpty($target)) { $item = Get-WinForgeNavItem -Id $target }

        $row = New-Object System.Windows.Controls.DockPanel
        $row.LastChildFill = $true

        $icon = New-GuiIcon -Name (Get-WinForgeIconName -Id "fact.$id") -Size 18 -Color $script:Theme.Muted
        $icon.Margin = New-Object System.Windows.Thickness (0, 0, 12, 0)
        Set-GuiDock -Element $icon -Side "Left"
        [void]$row.Children.Add($icon)

        # O valor à direita, em seminegrito; enquanto não chega, a barra cinza no lugar dele.
        $end = New-Object System.Windows.Controls.Grid
        $end.VerticalAlignment = "Center"
        $end.Margin = New-Object System.Windows.Thickness (12, 0, 0, 0)
        $skeleton = New-GuiHomeSkeleton -Width 64 -Height 12
        $skeleton.HorizontalAlignment = "Right"
        [void]$end.Children.Add($skeleton)

        $value = New-GuiText -Text "" -Size $script:Type.Body -Bold $true
        $value.TextWrapping = "NoWrap"
        $value.HorizontalAlignment = "Right"
        $value.Visibility = "Collapsed"
        [void]$end.Children.Add($value)
        Set-GuiDock -Element $end -Side "Right"
        [void]$row.Children.Add($end)

        $name = New-GuiText -Text $label -Size $script:Type.Body -Color $script:Theme.Muted
        $name.TextWrapping = "NoWrap"
        $name.TextTrimming = "CharacterEllipsis"
        $name.VerticalAlignment = "Center"
        [void]$row.Children.Add($name)

        $cell = New-Object System.Windows.Controls.Button
        $cell.Style = $window.FindResource("RowButton")
        $cell.MinHeight = 0
        $cell.Padding = New-Object System.Windows.Thickness (20, 16, 20, 16)
        $cell.HorizontalContentAlignment = "Stretch"
        $cell.Tag = $item
        $cell.Content = $row
        Set-GuiAutomationName -Element $cell -Name $(if ($null -ne $item) { (Get-WinForgeText '{0}: lendo. Abre: {1}' "$label" "$($item.Label)") } else { (Get-WinForgeText '{0}: lendo' "$label") })
        $cell.Add_Click({
            param ($sender, $eventArgs)
            if ($null -ne $sender.Tag) { Invoke-GuiNavItem -Item $sender.Tag }
        })

        # O traço entre as partes fica na moldura de cada uma (à esquerda, lado a lado; em cima, uma embaixo da outra).
        $holder = New-Object System.Windows.Controls.Border
        $holder.BorderBrush = New-GuiBrush $script:Theme.Line
        $holder.Child = $cell
        if ($id -in $Optional) { $holder.Visibility = "Collapsed" }
        [void]$grid.Children.Add($holder)
        $strip.Cells += $holder

        $parts[$id] = [PSCustomObject]@{
            Kind = "Cell"; Id = $id; Label = $label; Holder = $holder; Card = $cell; Value = $value; ValueBox = $value; Skeleton = $skeleton
            Detail = $null; Extra = $null; Track = $null; UsedColumn = $null; FreeColumn = $null; Fill = $null
            Opens = $(if ($null -ne $item) { [string]$item.Label } else { "" }); Strip = $strip
            Content = $row; Rows = @($row); Grid = $null
        }
    }

    # As partes ficam dentro dos cantos arredondados do cartão.
    $grid.Add_SizeChanged({
        param ($sender, $eventArgs)

        try {
            $sender.Clip = New-Object System.Windows.Media.RectangleGeometry ((New-Object System.Windows.Rect (0, 0, $sender.ActualWidth, $sender.ActualHeight)), 7, 7)
            if ($eventArgs.WidthChanged) { Update-GuiHomeStripLayout -Strip $sender.Tag }
        }
        catch {
            Write-Verbose "Linha do Início: $($_.Exception.Message)"
        }
    })
    $grid.Tag = $strip

    $card = New-GuiPanelBorder -Padding (New-Object System.Windows.Thickness 0) -Content $grid
    $card.Margin = New-Object System.Windows.Thickness (0, 0, 12, 0)
    Update-GuiHomeStripLayout -Strip $strip

    return [PSCustomObject]@{ Card = $card; Parts = $parts }
}

function Update-GuiHomeStripLayout {
    # As colunas da linha do Início: as partes visíveis lado a lado, ou uma embaixo da outra quando alguma não cabe
    # inteira (Get-WinForgeHomeColumns), com o traço entre elas do lado certo.
    param ([Parameter(Mandatory)]$Strip)

    $visible = @($Strip.Cells | Where-Object { $_.Visibility -ne "Collapsed" })

    # Lado a lado só quando cada parte cabe inteira (o nome sem reticências e o valor), nunca abaixo de 240. O nome de
    # cada parte e o valor mudam com o idioma e com a leitura, então a medida é a do texto de agora, mais o traço (1).
    $need = 240 * $script:TextScale

    if ($Strip.Grid.ActualWidth -gt 0) {
        foreach ($holder in $visible) { $need = [Math]::Max($need, (Measure-GuiNaturalWidth -Element $holder.Child) + 1) }
    }

    $columns = Get-WinForgeHomeColumns -Width $Strip.Grid.ActualWidth -Count $visible.Count -MinWidth $need
    $Strip.Grid.Columns = [Math]::Max(1, $columns)

    $first = $true

    foreach ($holder in $visible) {
        if ($first) { $holder.BorderThickness = New-Object System.Windows.Thickness 0 }
        elseif ($columns -gt 1) { $holder.BorderThickness = New-Object System.Windows.Thickness (1, 0, 0, 0) }
        else { $holder.BorderThickness = New-Object System.Windows.Thickness (0, 1, 0, 0) }

        $first = $false
    }
}

function Measure-GuiNaturalWidth {
    # A largura que um elemento pede sem limite: o texto numa linha só e inteiro (sem as reticências), com as margens.
    # É só a pergunta "quanto ele quer?": no passo seguinte do layout, o WPF mede de novo com a largura de verdade.
    param ([Parameter(Mandatory)][System.Windows.UIElement]$Element)

    if ($Element.Visibility -eq "Collapsed") { return 0.0 }

    $Element.Measure((New-Object System.Windows.Size ([double]::PositiveInfinity, [double]::PositiveInfinity)))
    return [double]$Element.DesiredSize.Width
}

function Get-GuiHomeFitWidth {
    <#
    A largura que um cartão do Início precisa para não cortar texto: a linha mais larga dele (Rows: o nome com a seta, o
    complemento com o "em uso"), mais o que a moldura põe em volta (o recuo, o contorno e a margem, medidos como a
    diferença entre o cartão e o conteúdo). O valor grande não entra: ele diminui até caber (New-GuiValueBox).
    #>
    param ([Parameter(Mandatory)]$Part)

    $rows = 0.0

    foreach ($row in @($Part.Rows)) {
        if ($null -ne $row) { $rows = [Math]::Max($rows, (Measure-GuiNaturalWidth -Element $row)) }
    }

    $frame = (Measure-GuiNaturalWidth -Element $Part.Card) - (Measure-GuiNaturalWidth -Element $Part.Content)
    return ([Math]::Max(0.0, $frame) + $rows)
}

function Update-GuiHomeColumns {
    # As colunas de uma fileira do Início (Set-GuiHomeColumns): Count lado a lado quando cada um fica com MinWidth, ou
    # com o que o texto do cartão mais largo pede (Get-GuiHomeFitWidth); senão, um embaixo do outro.
    param ([Parameter(Mandatory)]$Grid)

    $rule = $Grid.Tag
    $need = [double]$rule.MinWidth

    if ($Grid.ActualWidth -gt 0) {
        foreach ($part in @($rule.Fit)) {
            if ($null -ne $part -and $part.Holder.Visibility -ne "Collapsed") { $need = [Math]::Max($need, (Get-GuiHomeFitWidth -Part $part)) }
        }
    }

    $columns = Get-WinForgeHomeColumns -Width $Grid.ActualWidth -Count $rule.Count -MinWidth $need
    if ($Grid.Columns -ne $columns) { $Grid.Columns = $columns }
    Set-GuiHomeDividers -Holders $rule.Divided -Columns $columns
}

function Set-GuiHomeDividers {
    # O traço entre os números do histórico: lado a lado, à esquerda de cada um depois do primeiro, com o recuo; um
    # embaixo do outro, sem traço e sem recuo (rentes à página, como o primeiro).
    param (
        [object[]]$Holders = @(),
        [int]$Columns
    )

    $index = 0

    foreach ($holder in @($Holders)) {
        if ($null -eq $holder) { continue }

        $side = ($Columns -gt 1 -and $index -gt 0)
        $holder.BorderThickness = New-Object System.Windows.Thickness ($(if ($side) { 1 } else { 0 }), 0, 0, 0)
        $padding = $holder.Child.Padding
        $holder.Child.Padding = New-Object System.Windows.Thickness ($(if ($side) { 20 } else { 0 }), $padding.Top, $padding.Right, $padding.Bottom)
        $index++
    }
}

function Set-GuiHomeColumns {
    # Liga as colunas de uma fileira do Início (UniformGrid) à largura dela: Count lado a lado quando cada um fica com
    # MinWidth (já com o tamanho do texto) e, com Fit (as partes dos cartões), sem cortar o texto de nenhum; senão, um
    # embaixo do outro (Update-GuiHomeColumns). O texto que chega depois (Set-GuiHomeCardText) refaz a conta. Divided:
    # as molduras com o traço entre elas, que acompanham as colunas (Set-GuiHomeDividers).
    param (
        [Parameter(Mandatory)]$Grid,
        [int]$Count,
        [double]$MinWidth,
        [object[]]$Fit = @(),
        [object[]]$Divided = @()
    )

    $Grid.Rows = 0
    $Grid.Columns = [Math]::Max(1, $Count)
    $Grid.Tag = [PSCustomObject]@{ Count = $Count; MinWidth = $MinWidth; Fit = @($Fit); Divided = @($Divided) }
    Set-GuiHomeDividers -Holders $Divided -Columns $Grid.Columns

    foreach ($part in @($Fit)) {
        if ($null -ne $part) { $part.Grid = $Grid }
    }

    $Grid.Add_SizeChanged({
        param ($sender, $eventArgs)

        if (-not $eventArgs.WidthChanged) { return }

        try {
            Update-GuiHomeColumns -Grid $sender
        }
        catch {
            Write-Verbose "Colunas do Início: $($_.Exception.Message)"
        }
    })
}

function New-GuiValueSummary {
    <#
    "Histórico neste PC", no fim do Início: o que o WinForge já fez aqui, só com o que ele anota
    (Get-WinForgeHomeValueSummary): o espaço que as manutenções liberaram, quantas foram feitas e as mudanças anotadas (com
    quantas têm desfazer). Os números ficam grandes, direto na página, com um traço entre eles; cada um leva à tela de onde
    vem. Só os números que existem aparecem; sem nenhum, $null. Devolve o título, o traço e a fileira, nesta ordem.
    #>
    $summary = $null

    try { $summary = Get-WinForgeHomeValueSummary } catch { return $null }

    if ($null -eq $summary -or -not $summary.Visible) { return $null }

    $cells = @()

    if ($null -ne $summary.Freed) {
        $cells += [PSCustomObject]@{ Label = (Get-WinForgeText 'Liberado nas manutenções'); Value = (Format-WinForgeBytes -Bytes ([int64]$summary.Freed)); Note = ""; Opens = "maintenance.history" }
    }

    # Com o histórico cheio, ele guarda só as últimas: "20+".
    if ([int]$summary.Runs -gt 0) {
        $cells += [PSCustomObject]@{ Label = (Get-WinForgeText 'Manutenções feitas'); Value = "$($summary.Runs)$(if ($summary.Full) { '+' })"; Note = ""; Opens = "maintenance.history" }
    }

    if ([int]$summary.Changes -gt 0) {
        $cells += [PSCustomObject]@{ Label = (Get-WinForgeText 'Mudanças anotadas'); Value = "$($summary.Changes)"; Note = $(if ([int]$summary.Undoable -gt 0) { (Get-WinForgeText '{0} com desfazer' "$($summary.Undoable)") } else { "" }); Opens = "maintenance.changes" }
    }

    if ($cells.Count -eq 0) { return $null }

    $heading = New-GuiSectionHeading -Text (Get-WinForgeText 'Histórico neste PC')
    $heading.Margin = New-Object System.Windows.Thickness (0, 30, 12, 12)

    $rule = New-Object System.Windows.Controls.Border
    $rule.Height = 1
    $rule.Background = New-GuiBrush $script:Theme.Line
    $rule.Margin = New-Object System.Windows.Thickness (0, 0, 12, 6)

    $grid = New-Object System.Windows.Controls.Primitives.UniformGrid
    $grid.Margin = New-Object System.Windows.Thickness (0, 0, 12, 0)
    $holders = @()

    foreach ($cell in $cells) {
        $item = Get-WinForgeNavItem -Id $cell.Opens

        $button = New-Object System.Windows.Controls.Button
        $button.Style = $window.FindResource("RowButton")
        $button.Padding = New-Object System.Windows.Thickness (0, 12, 16, 12)
        $button.MinHeight = 0
        $button.Tag = $item
        $button.HorizontalContentAlignment = "Left"

        $stack = New-Object System.Windows.Controls.StackPanel
        [void]$stack.Children.Add((New-GuiText -Text $cell.Label -Size $script:Type.Body -Color $script:Theme.Muted))

        # O número grande (diminui até caber na coluna) e, logo ao lado, embaixo, a nota ("27 com desfazer").
        $value = New-Object System.Windows.Controls.DockPanel
        $value.Margin = New-Object System.Windows.Thickness (0, 6, 0, 0)
        $value.LastChildFill = $true

        $number = New-GuiValueBox -Text (New-GuiText -Text $cell.Value -Size $script:Type.TitleLarge -Display)
        $number.VerticalAlignment = "Bottom"
        Set-GuiDock -Element $number -Side "Left"
        [void]$value.Children.Add($number)

        if ($cell.Note) {
            $note = New-GuiText -Text $cell.Note -Size $script:Type.Body -Color $script:Theme.Muted
            $note.TextWrapping = "NoWrap"
            $note.TextTrimming = "CharacterEllipsis"
            $note.VerticalAlignment = "Bottom"
            $note.HorizontalAlignment = "Left"
            $note.Margin = New-Object System.Windows.Thickness (12, 0, 0, 8)
            [void]$value.Children.Add($note)
        }

        [void]$stack.Children.Add($value)
        $button.Content = $stack

        $spoken = "$($cell.Label): $($cell.Value)$(if ($cell.Note) { " $($cell.Note)" })"
        if ($null -ne $item) { $spoken += (Get-WinForgeText '. Abre: {0}' "$($item.Label)") }
        Set-GuiAutomationName -Element $button -Name $spoken
        if ($null -ne $item) { $button.ToolTip = [string]$item.Label }

        $button.Add_Click({
            param ($sender, $eventArgs)
            if ($null -ne $sender.Tag) { Invoke-GuiNavItem -Item $sender.Tag }
        })

        # O traço fino entre os números fica na moldura de cada um (Set-GuiHomeDividers).
        $holder = New-Object System.Windows.Controls.Border
        $holder.BorderBrush = New-GuiBrush $script:Theme.Line
        $holder.Child = $button
        [void]$grid.Children.Add($holder)
        $holders += $holder
    }

    Set-GuiHomeColumns -Grid $grid -Count $cells.Count -MinWidth (200 * $script:TextScale) -Divided $holders

    # O título, o traço e os números numa peça só: a parte entra (ou fica de fora) inteira (Add-GuiHomePart).
    $section = New-Object System.Windows.Controls.StackPanel
    foreach ($part in @($heading, $rule, $grid)) { [void]$section.Children.Add($part) }

    return $section
}

function Add-GuiHomePart {
    <#
    Põe uma parte do Início na tela (em Panel; sem ele, na página). Cada parte vem numa peça só ("Seu PC" com o título, os
    cartões e a linha; o histórico com o título, o traço e os números) e entra inteira. Se o WPF recusar a entrada (um valor
    que ele não aceita só aparece quando a parte entra na tela), ela fica de fora inteira, sem um título ou um traço
    sobrando; o alto da página diz qual parte faltou, e o motivo vai para o log da janela (Add-WinForgeWindowProblem), que
    o Pacote de suporte leva. Sem isso, a janela, que roda sem console, perdia a parte sem deixar rastro. $true quando entrou.
    #>
    param (
        [Parameter(Mandatory)]$Element,
        [Parameter(Mandatory)][string]$Name,
        $Panel = $null
    )

    if ($null -eq $Panel) { $Panel = $contentPanel }

    try {
        [void]$Panel.Children.Add($Element)
        return $true
    }
    catch {
        $reasons = @()
        $exception = $_.Exception

        # O erro de verdade costuma vir por dentro (a chamada do .NET embrulha o do WPF).
        while ($null -ne $exception -and $reasons.Count -lt 4) {
            $reasons += "$($exception.GetType().FullName): $($exception.Message)"
            $exception = $exception.InnerException
        }

        Add-WinForgeWindowProblem -Part "$(Get-WinForgeText 'Início') > $Name ($($Element.GetType().Name))" -Reason $reasons
        Show-GuiHomeProblem -Name $Name
        return $false
    }
}

function Show-GuiHomeProblem {
    # O aviso no alto do Início quando uma parte não pôde ser mostrada (Add-GuiHomePart): quais faltaram e onde ficou o
    # motivo. Um aviso só, com todas as partes, refeito a cada uma.
    param ([Parameter(Mandatory)][string]$Name)

    if ($null -eq $script:HomeProblems) { return }

    if ($Name -notin @($script:HomeProblemParts)) { $script:HomeProblemParts = @($script:HomeProblemParts) + $Name }

    $script:HomeProblems.Children.Clear()
    $text = (Get-WinForgeText 'Parte do Início não pôde ser mostrada: {0}. O motivo vai no Pacote de suporte (Sobre o WinForge).' "$(Join-WinForgeList -Items @($script:HomeProblemParts))")

    try { [void]$script:HomeProblems.Children.Add((New-GuiNotice -Text $text)) } catch { Write-Verbose "Aviso do Início: $($_.Exception.Message)" }
}

function Show-GuiHomePage {
    # Monta o Início. -Rerender (troca de tema) refaz os controles sem ler o PC de novo: mostra a última leitura (mesmo
    # depois dos 30 segundos, com a hora dela) ou continua a leitura em andamento de onde ela estava.
    param ([switch]$Rerender)

    # Sem a frase embaixo do título: a nota de saúde, "Seu PC" e "Histórico neste PC" já dizem o que a página tem.
    $pageTitle.Text = (Get-WinForgeText 'Início')
    $pageSubtitle.Text = ""
    $contentPanel.Children.Clear()
    $script:HomeFacts = @{}
    $script:HomeFactInfo = @{}
    $script:HomeRefreshFocus = $false

    # Uma leitura que ficou pela metade em outra visita não vale mais: os cartões abaixo são novos. Na troca de tema, a
    # leitura em andamento continua a mesma (e não fica solta se a montagem falhar) e passa para os cartões novos.
    $pending = $script:HomeRead
    if (-not $Rerender) { $script:HomeRead = $null }

    # A hora da leitura e o Atualizar entram na nota de saúde (Update-GuiHealthCard), que guarda o texto e o estado.
    if (-not $Rerender) { $script:HomeStamp = @{ Text = (Get-GuiHomeReadingText); CanRefresh = $false; ReadAt = $null } }

    # Cada parte entra na página inteira, numa peça só (Add-GuiHomePart); a que não puder ser mostrada é dita aqui, no alto.
    $script:HomeProblems = New-Object System.Windows.Controls.StackPanel
    $script:HomeProblemParts = @()
    [void]$contentPanel.Children.Add($script:HomeProblems)

    # Avisos (por exemplo, WinForge elevado com outra conta) entram aqui quando a leitura do sistema termina.
    $script:HomeBanner = New-Object System.Windows.Controls.StackPanel
    [void]$contentPanel.Children.Add($script:HomeBanner)

    # A nota de saúde chega com a leitura (ou com a última, mais abaixo); até lá, o cartão mostra que está lendo. Ela é
    # montada uma vez por visita, no fim, quando já se sabe o que mostrar.
    $script:HomeHealth = New-Object System.Windows.Controls.StackPanel
    $script:HomeHealth.Margin = New-Object System.Windows.Thickness (0, 0, 12, 0)
    [void]$contentPanel.Children.Add($script:HomeHealth)

    # "Seu PC": o disco, a proteção e o Windows em três cartões; embaixo, numa linha só, a última manutenção, o reinício
    # pendente e (num notebook) a bateria. O título, os cartões e a linha numa peça só.
    $yourPc = New-Object System.Windows.Controls.StackPanel
    [void]$yourPc.Children.Add((New-GuiSectionHeading -Text (Get-WinForgeText 'Seu PC')))

    $labels = Get-WinForgeHomeFactLabels
    $optional = @(Get-WinForgeHomeOptionalFacts)
    $stripIds = @(@("maintenance", "reboot", "battery") | Where-Object { $labels.Contains($_) })
    $cardIds = @(@($labels.Keys) | Where-Object { $_ -notin $stripIds })

    $cards = New-Object System.Windows.Controls.Primitives.UniformGrid
    $cardParts = @()

    foreach ($id in $cardIds) {
        $parts = New-GuiHomeCard -Id $id -Label $labels[$id]
        if ($id -in $optional) { $parts.Holder.Visibility = "Collapsed" }
        $script:HomeFacts[$id] = $parts
        $script:HomeFactInfo[$id] = [PSCustomObject]@{ Label = [string]$labels[$id] }
        [void]$cards.Children.Add($parts.Card)
        $cardParts += $parts
    }

    Set-GuiHomeColumns -Grid $cards -Count $cardIds.Count -MinWidth (200 * $script:TextScale) -Fit $cardParts

    [void]$yourPc.Children.Add($cards)

    if ($stripIds.Count -gt 0) {
        $strip = New-GuiHomeStrip -Ids $stripIds -Labels $labels -Optional $optional

        foreach ($id in $stripIds) {
            $script:HomeFacts[$id] = $strip.Parts[$id]
            $script:HomeFactInfo[$id] = [PSCustomObject]@{ Label = [string]$labels[$id] }
        }

        [void]$yourPc.Children.Add($strip.Card)
    }

    # Fora da tela, "Seu PC" não recebe leitura: os fatos dele não teriam onde aparecer.
    if (-not (Add-GuiHomePart -Element $yourPc -Name (Get-WinForgeText 'Seu PC'))) {
        $script:HomeFacts = @{}
    }

    # O que o WinForge já fez neste PC: só aparece com algo anotado (uma manutenção, uma mudança).
    $summary = New-GuiValueSummary
    if ($null -ne $summary) { [void](Add-GuiHomePart -Element $summary -Name (Get-WinForgeText 'Histórico neste PC')) }

    # Enquanto faltar o atalho, o monitor ou a manutenção mensal: a configuração inicial, no fim da página. Ela entra
    # quando se sabe se a manutenção mensal está agendada (a leitura do Início, ou a última leitura, Update-GuiSetupCard).
    $script:HomeSetup = New-Object System.Windows.Controls.StackPanel
    $script:HomeSetupKey = $null
    [void]$contentPanel.Children.Add($script:HomeSetup)

    if ($Rerender -and $null -ne $pending) {
        # Numa atualização, os cartões que a leitura nova ainda não alcançou continuam com a anterior (e a nota também).
        $shown = $false

        if ($pending.Refresh -and $null -ne $script:HomeLastSnapshot) {
            try { Show-GuiHomeResult -Snapshot $script:HomeLastSnapshot; $shown = $true } catch { $script:HomeLastSnapshot = $null }
        }

        if (-not $shown) { Update-GuiHealthCard -Health $null }

        foreach ($fact in @($pending.Facts)) { Set-GuiHomeFact -Fact $fact }
        if ($null -ne $pending.ScheduleSetup) { Update-GuiSetupCard -ScheduleDone ([bool]$pending.ScheduleSetup) }

        # Os avisos vêm da primeira etapa: depois dela, valem os da leitura nova.
        if ($pending.Next -gt 0 -or -not $pending.Refresh) {
            $script:HomeBanner.Children.Clear()
            Add-GuiHomeNotices -Notices $pending.Notices
        }

        # A próxima etapa já está marcada (Invoke-GuiDeferred) e continua nos cartões novos.
        Set-GuiHomeStamp -Text (Get-GuiHomeReadingText -Refresh:([bool]$pending.Refresh)) -CanRefresh $false
        return
    }

    # Voltar ao Início logo depois de uma leitura mostra o que já se sabe. Depois disso (ou depois de uma ação, que pode
    # ter mudado o PC), a última leitura aparece na hora e a nova a atualiza no lugar, cartão por cartão; só a primeira
    # visita começa com os cartões esperando (a barra cinza no lugar do valor).
    $snapshot = $(if ($Rerender) { $script:HomeLastSnapshot } else { Get-GuiHomeSnapshot })
    $stale = ($null -eq $snapshot -and $null -ne $script:HomeLastSnapshot)
    if ($stale) { $snapshot = $script:HomeLastSnapshot }

    if ($null -ne $snapshot) {
        try {
            Show-GuiHomeResult -Snapshot $snapshot
        }
        catch {
            # Uma leitura guardada que não pode ser mostrada falharia igual em toda visita: ela é descartada e o PC é lido
            # de novo, em vez de o Início ficar sem leitura até alguém apertar F5.
            $script:HomeSnapshot = $null
            $script:HomeLastSnapshot = $null
            Update-GuiHealthCard -Health $null
            Start-GuiHomeRead
            return
        }

        if ($stale) { Start-GuiHomeRead -Refresh }
        return
    }

    Update-GuiHealthCard -Health $null
    Start-GuiHomeRead
}

function Clear-GuiHomeCache {
    # O PC pode ter mudado (uma ação terminou, a pessoa pediu para atualizar): a próxima visita ao Início lê de novo, e
    # uma leitura que já estava em andamento não é guardada ao terminar.
    $script:HomeSnapshot = $null
    $script:HomeCacheVersion++
}

function Get-GuiHomeSnapshot {
    # A última leitura completa, enquanto ainda vale (HomeSnapshotSeconds); uma data no futuro (relógio ajustado) não vale.
    $snapshot = $script:HomeSnapshot

    if ($null -eq $snapshot) { return $null }

    $age = ((Get-Date) - $snapshot.ReadAt).TotalSeconds

    if ($age -lt 0 -or $age -ge $script:HomeSnapshotSeconds) { return $null }

    return $snapshot
}

function Set-GuiHomeStamp {
    # A hora da leitura (ou o andamento dela) e se o Atualizar vale. Fica guardado para a próxima nota de saúde, que
    # refaz a linha, e aparece na nota atual.
    param (
        [Parameter(Mandatory)][string]$Text,
        [bool]$CanRefresh = $false,

        # A hora da leitura que o texto descreve; com ela, o texto acompanha o relógio (Update-GuiHomeStampAge).
        $ReadAt = $null
    )

    $script:HomeStamp = @{ Text = $Text; CanRefresh = $CanRefresh; ReadAt = $ReadAt }

    if ($null -ne $script:HomeStampText) { $script:HomeStampText.Text = $Text }

    if ($null -ne $script:HomeRefreshButton) {
        # Desligado, o botão perde o foco do teclado: a nota refeita no fim da leitura o devolve (Get-GuiHomeHealthFocus).
        if (-not $CanRefresh -and $script:HomeRefreshButton.IsKeyboardFocused) { $script:HomeRefreshFocus = $true }
        $script:HomeRefreshButton.IsEnabled = $CanRefresh
    }
}

function New-GuiHomeStampBar {
    # A linha embaixo da frase da nota de saúde: a hora da leitura e o botão de ler de novo, só o ícone (F5 faz o mesmo),
    # com o texto e o estado guardados (HomeStamp). Discreta: o que a página pede ao olhar é a nota e o que fazer.
    $bar = New-Object System.Windows.Controls.StackPanel
    $bar.Orientation = "Horizontal"
    $bar.HorizontalAlignment = "Left"
    $bar.Margin = New-Object System.Windows.Thickness (0, 2, 0, 0)

    $stamp = New-GuiText -Text ([string]$script:HomeStamp.Text) -Size $script:Type.Caption -Color $script:Theme.Dim
    $stamp.VerticalAlignment = "Center"
    $stamp.TextWrapping = "NoWrap"
    [void]$bar.Children.Add($stamp)

    $refresh = New-Object System.Windows.Controls.Button
    $refresh.Style = $window.FindResource("GhostButton")
    $refresh.Content = New-GuiIcon -Name "refresh" -Size 14 -Color $script:Theme.Muted
    $refresh.Padding = New-Object System.Windows.Thickness (6, 4, 6, 4)
    $refresh.Margin = New-Object System.Windows.Thickness (4, 0, 0, 0)
    $refresh.VerticalAlignment = "Center"
    $refresh.ToolTip = (Get-WinForgeText 'Ler o PC de novo (F5)')
    $refresh.IsEnabled = [bool]$script:HomeStamp.CanRefresh
    Set-GuiAutomationName -Element $refresh -Name (Get-WinForgeText 'Ler o estado do PC de novo')
    $refresh.Add_Click({ Request-GuiHomeRefresh })
    [void]$bar.Children.Add($refresh)

    $script:HomeRefreshButton = $refresh
    $script:HomeStampText = $stamp

    return $bar
}

function Get-GuiHomeStampText {
    # "Atualizado às 14:20" para uma leitura de hoje; de outro dia, com o dia ("ontem às", "em 28/10 às"): a janela pode
    # ficar aberta de um dia para o outro, e só a hora enganaria.
    param ([Parameter(Mandatory)][datetime]$ReadAt, [datetime]$Now = (Get-Date))

    $time = Format-WinForgeDateTime -When $ReadAt -Pattern "HH:mm"

    if ($ReadAt.Date -eq $Now.Date) { return (Get-WinForgeText 'Atualizado às {0}' "$time") }
    if ($ReadAt.Date -eq $Now.Date.AddDays(-1)) { return (Get-WinForgeText 'Atualizado ontem às {0}' "$time") }

    return (Get-WinForgeText 'Atualizado em {0} às {1}' "$(Format-WinForgeDateTime -When $ReadAt -Pattern 'dd/MM')" "$time")
}

function Set-GuiHomeFact {
    # Mostra um fato do Início no cartão (ou na parte da linha) dele (Set-GuiHomeCardText).
    param ([Parameter(Mandatory)]$Fact)

    $id = [string]$Fact.Id

    # O que o Início leu da bateria vale também para a página Diagnóstico: o cartão visível diz que há bateria; "Sem
    # bateria" (PC de mesa, nenhuma bateria ou um nobreak) diz que não há. Uma leitura que não terminou não decide nada.
    if ($id -eq "battery") {
        if ([bool]$Fact.Visible) { $script:HasBattery = $true }
        elseif ([string]$Fact.Text -eq (Get-WinForgeText 'Sem bateria')) { $script:HasBattery = $false }
    }

    if (-not $script:HomeFacts.ContainsKey($id)) { return }

    Set-GuiHomeCardText -Parts $script:HomeFacts[$id] -Fact $Fact
}

function Set-GuiHomeCardText {
    <#
    Mostra um fato do Início no cartão de "Seu PC" ou na parte da linha dele (New-GuiHomeCard, New-GuiHomeStrip): o valor
    na cor do nível, o complemento, a barra de uso do disco (com quanto está em uso, Usage), se ele aparece, a frase inteira
    ao passar o mouse e o nome que o leitor de tela fala.
    #>
    param (
        [Parameter(Mandatory)]$Parts,
        [Parameter(Mandatory)]$Fact
    )

    $colors = @{ Normal = $script:Theme.Text; Ok = $script:Theme.Ok; Warn = $script:Theme.Warn; Muted = $script:Theme.Muted }
    $level = [string]$Fact.Level
    $text = [string]$Fact.Text
    $shown = [string](Get-WinForgeJsonValue -Object $Fact -Name "Value" -Default $text)
    $more = [string](Get-WinForgeJsonValue -Object $Fact -Name "Detail" -Default "")

    # O valor fica sozinho no cartão: começa em maiúscula ("há 5 horas" vira "Há 5 horas").
    $Parts.Value.Text = ConvertTo-WinForgeHeadline -Text $shown
    $Parts.Value.Foreground = New-GuiBrush $(if ($colors.ContainsKey($level)) { $colors[$level] } else { $script:Theme.Text })
    $Parts.Value.Visibility = "Visible"
    $Parts.ValueBox.Visibility = "Visible"
    $Parts.Skeleton.Visibility = "Collapsed"

    if ($null -ne $Parts.Detail) {
        $Parts.Detail.Text = $more
        $Parts.Detail.Visibility = $(if ([string]::IsNullOrEmpty($more)) { "Collapsed" } else { "Visible" })
    }

    if ($null -ne $Parts.Track) {
        # A barra de uso só com um número de 0 a 100 (uma leitura que falhou não tem barra).
        $usage = Get-WinForgeJsonValue -Object $Fact -Name "Usage" -Default $null
        $percent = -1.0
        if ($null -ne $usage -and -not [double]::TryParse([string]$usage, [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$percent)) { $percent = -1.0 }

        if ($null -ne $usage -and $percent -ge 0 -and $percent -le 100) {
            $Parts.UsedColumn.Width = New-Object System.Windows.GridLength ($percent, [System.Windows.GridUnitType]::Star)
            $Parts.FreeColumn.Width = New-Object System.Windows.GridLength ((100.0 - $percent), [System.Windows.GridUnitType]::Star)
            $Parts.Fill.Background = New-GuiBrush $(if ($level -eq "Warn") { $script:Theme.Warn } else { $script:Theme.Bar })
            $Parts.Extra.Text = (Get-WinForgeText '{0}% em uso' "$([int]$percent)")
            $Parts.Extra.Visibility = "Visible"
            $Parts.Track.Visibility = "Visible"
        }
        else {
            $Parts.Extra.Visibility = "Collapsed"
            $Parts.Track.Visibility = "Collapsed"
        }
    }

    $Parts.Card.ToolTip = $text

    # Partes que não se aplicam a este PC (bateria em desktop) saem da tela.
    $Parts.Holder.Visibility = $(if ($Fact.Visible) { "Visible" } else { "Collapsed" })

    # O leitor de tela lê o nome do botão no lugar do conteúdo: a frase inteira precisa estar nele.
    $name = "$($Parts.Label): $text"
    if (-not [string]::IsNullOrEmpty($Parts.Opens)) { $name += (Get-WinForgeText '. Abre: {0}' "$($Parts.Opens)") }
    Set-GuiAutomationName -Element $Parts.Card -Name $name

    # O texto novo pode não caber mais lado a lado (ou voltar a caber): a linha ou a fileira refaz as colunas.
    if ($null -ne $Parts.Strip) { Update-GuiHomeStripLayout -Strip $Parts.Strip }
    elseif ($null -ne $Parts.Grid) { Update-GuiHomeColumns -Grid $Parts.Grid }
}

function Get-GuiSavedAntivirusMode {
    # Quem protegia o PC na última leitura do Início, guardado nas preferências (Save-GuiAntivirusMode); "" sem registro.
    try {
        $mode = [string](Get-WinForgeSetting -Name "AntivirusMode" -Default "")
        if ($mode -in @("Active", "Other", "Off", "Passive", "Unavailable")) { return $mode }
    }
    catch {
        Write-Verbose "Antivírus guardado: $($_.Exception.Message)"
    }

    return ""
}

function Save-GuiAntivirusMode {
    # Guarda quem protege o PC, lido pelo Início, para a próxima vez que o WinForge abrir (só quando muda).
    param ([AllowEmptyString()][string]$Mode)

    if ([string]::IsNullOrEmpty($Mode) -or $Mode -eq [string]$script:AntivirusMode) { return }

    $script:AntivirusMode = $Mode
    [void](Set-WinForgeSetting -Name "AntivirusMode" -Value $Mode)
}

function Show-GuiHomeResult {
    # Mostra uma leitura completa: os cartões, a nota de saúde, os avisos e a hora em que foi lida. Uma leitura cuja nota
    # não pôde ser montada (Failed) mostra os cartões e diz isso na nota; mostrada de novo (troca de tema), ela não lê o
    # PC outra vez.
    param ([Parameter(Mandatory)]$Snapshot)

    foreach ($fact in @($Snapshot.Facts)) { Set-GuiHomeFact -Fact $fact }

    # Quem protege o PC, pelo cartão Proteção: com outro antivírus (ou nenhum funcionando), o que só o Defender faz
    # (Verificar vírus) sai da página Segurança. Sem leitura, fica como estava.
    foreach ($fact in @($Snapshot.Facts)) {
        if ($null -ne $fact -and [string](Get-WinForgeJsonValue -Object $fact -Name "Id" -Default "") -eq "security") {
            Save-GuiAntivirusMode -Mode ([string](Get-WinForgeJsonValue -Object $fact -Name "AntivirusMode" -Default ""))
        }
    }

    $failed = [bool](Get-WinForgeJsonValue -Object $Snapshot -Name "Failed" -Default $false)

    # A hora e o botão de ler de novo antes da nota: ela nasce com o botão ligado, que pode receber o foco de volta.
    if ($failed) {
        Set-GuiHomeStamp -Text (Get-WinForgeText 'A leitura não terminou') -CanRefresh $true
    }
    else {
        Set-GuiHomeStamp -Text (Get-GuiHomeStampText -ReadAt $Snapshot.ReadAt) -CanRefresh $true -ReadAt $Snapshot.ReadAt
    }

    if ($failed) { Update-GuiHealthCard -Failed } else { Update-GuiHealthCard -Health $Snapshot.Health }

    $script:HomeBanner.Children.Clear()
    Add-GuiHomeNotices -Notices $Snapshot.Notices

    # A configuração inicial, com o agendamento lido junto (uma leitura de antes da R40 não o tem: não agendada).
    Update-GuiSetupCard -ScheduleDone ([bool](Get-WinForgeJsonValue -Object $Snapshot -Name "ScheduleSetup" -Default $false))
}

function Update-GuiHomeStampAge {
    # Refaz "Atualizado às 14:20" quando o dia muda com a janela aberta no Início ("ontem às", depois "em 28/10 às").
    # Chamada a cada minuto; não faz nada durante uma leitura, que mostra o andamento.
    param ([datetime]$Now = (Get-Date))

    if ($script:CurrentPage -ne "home" -or $null -ne $script:HomeRead) { return }

    $readAt = $script:HomeStamp["ReadAt"]
    if ($null -eq $readAt) { return }

    $text = Get-GuiHomeStampText -ReadAt $readAt -Now $Now
    if ($text -ne $script:HomeStamp.Text) { Set-GuiHomeStamp -Text $text -CanRefresh ([bool]$script:HomeStamp.CanRefresh) -ReadAt $readAt }
}

function Add-GuiHomeNotices {
    # Os avisos de destaque do Início (por exemplo, WinForge elevado com outra conta), acima da nota de saúde.
    param ([object[]]$Notices = @())

    foreach ($notice in @($Notices | Where-Object { $null -ne $_ })) {
        [void]$script:HomeBanner.Children.Add((New-GuiNotice -Text $notice.Text))
    }
}

function Get-GuiHomeReadingText {
    # O texto da hora da leitura enquanto ela acontece. -Refresh: os cartões já mostram uma leitura anterior, que está
    # sendo atualizada. Sem contagem de etapas: cada cartão já mostra quando chega, e nem toda etapa tem cartão.
    param ([switch]$Refresh)

    if ($Refresh) { return (Get-WinForgeText 'Atualizando...') }

    return (Get-WinForgeText 'Lendo o PC...')
}

function Stop-GuiHomeRead {
    # Uma falha que a leitura não previu (no temporizador ou entre uma etapa e outra) não deixa o Início preso em "Lendo"
    # com o botão de ler de novo desligado: a leitura para, e a hora diz isso, com o botão ligado.
    $script:HomeRead = $null
    $script:HomeReaderOwner = $null
    $script:HomeReaderWaiting = $null

    try { Set-GuiHomeStamp -Text (Get-WinForgeText 'A leitura não terminou') -CanRefresh $true } catch { Write-Verbose "Início: $($_.Exception.Message)" }
}

function Start-GuiHomeRead {
    # Começa a ler o estado do PC para os cartões que estão na tela. Cada etapa roda em um tique do temporizador: a
    # janela responde entre uma e outra e cada cartão aparece assim que a etapa dele termina. -Refresh: os cartões já
    # mostram a leitura anterior, que a nova troca no lugar.
    param ([switch]$Refresh)

    $steps = @(Get-WinForgeHomeSteps)

    $script:HomeRead = [PSCustomObject]@{
        Steps = $steps; Next = 0; Facts = @(); Notices = @(); Issues = @(); Unread = @(); Failed = $false
        Version = $script:HomeCacheVersion; Refresh = [bool]$Refresh; ScheduleSetup = $null
    }

    Set-GuiHomeStamp -Text (Get-GuiHomeReadingText -Refresh:$Refresh) -CanRefresh $false
    Invoke-GuiDeferred -Action { Step-GuiHomeRead }
}

function Step-GuiHomeRead {
    # A próxima etapa da leitura do Início: no leitor em segundo plano quando ele existe, senão aqui mesmo.
    $read = $script:HomeRead

    if ($null -eq $read) { return }

    if ($script:CurrentPage -ne "home") {
        # A pessoa saiu do Início no meio da leitura: a próxima visita começa outra.
        $script:HomeRead = $null
        return
    }

    try {
        if (Start-GuiHomeBackgroundStep -Read $read) { return }
    }
    catch {
        Stop-GuiHomeRead
        return
    }

    try {
        $result = Read-WinForgeHomeStep -Name ([string]$read.Steps[$read.Next])
    }
    catch {
        $result = $null
    }

    try {
        Receive-GuiHomeStep -Read $read -Result $result -Failed:($null -eq $result)
    }
    catch {
        Stop-GuiHomeRead
    }
}

function Receive-GuiHomeStep {
    # Uma etapa terminou: os cartões dela são preenchidos e a próxima começa (ou a leitura termina). O resultado de uma
    # leitura que não vale mais (a pessoa saiu do Início ou pediu outra) é descartado.
    param ($Read, $Result = $null, [switch]$Failed)

    if ($null -eq $Read -or -not [object]::ReferenceEquals($Read, $script:HomeRead)) { return }

    if ($script:CurrentPage -ne "home") {
        $script:HomeRead = $null
        return
    }

    if ($Failed -or $null -eq $Result) {
        $Read.Failed = $true
    }
    else {
        try {
            foreach ($fact in @($Result.Facts)) { Set-GuiHomeFact -Fact $fact }

            # Os avisos aparecem assim que a etapa deles termina (o da conta diferente vem da primeira), e não só no fim:
            # a página desce uma vez, logo no começo, em vez de empurrar tudo quando a pessoa já está lendo. Ao ler de
            # novo, o aviso da leitura anterior sai na primeira etapa, para não aparecer duas vezes.
            if ($Read.Next -eq 0) { $script:HomeBanner.Children.Clear() }
            Add-GuiHomeNotices -Notices $Result.Notices

            $Read.Facts += @($Result.Facts)
            $Read.Notices += @($Result.Notices)
            $Read.Issues += @($Result.Issues)
            $Read.Unread += @($Result.Unread)

            # A etapa da manutenção agendada diz também se ela está agendada para esta pasta: a configuração inicial
            # aparece agora, sem consultar o Agendador de Tarefas na thread da janela.
            if ($null -ne $Result.PSObject.Properties["ScheduleSetup"]) {
                $Read.ScheduleSetup = [bool]$Result.ScheduleSetup
                Update-GuiSetupCard -ScheduleDone $Read.ScheduleSetup
            }
        }
        catch {
            $Read.Failed = $true
        }
    }

    $Read.Next++

    if ($Read.Next -lt $Read.Steps.Count) {
        Invoke-GuiDeferred -Action { Step-GuiHomeRead }
        return
    }

    Complete-GuiHomeRead
}

function Start-GuiHomeBackgroundStep {
    # Entrega a próxima etapa ao leitor em segundo plano. $false quando não há leitor (ele não abriu neste PC): a etapa
    # roda na thread da janela, como antes.
    param ($Read)

    if ($script:HomeReaderBroken) { return $false }

    if ($null -eq $script:HomeReader) {
        try {
            $script:HomeReader = New-WinForgeGuiReader -ModuleRoot $moduleRoot -Modules @(Get-WinForgeHomeReaderModules)
        }
        catch {
            $script:HomeReaderBroken = $true
            return $false
        }
    }

    $script:HomeReaderWaiting = $Read
    Update-GuiHomeReader
    return $true
}

function Update-GuiHomeReader {
    # O temporizador do leitor: recolhe a etapa que terminou, começa a que está esperando e para quando não há nada. Uma
    # etapa presa (WMI que não responde) não segura o Início: passado o limite, o leitor é descartado (outro abre na
    # próxima etapa) e a etapa conta como não lida.
    $reader = $script:HomeReader
    $owner = $script:HomeReaderOwner

    if ($null -ne $owner -and $null -ne $reader) {
        $done = Receive-WinForgeGuiRead -Reader $reader

        if ($null -eq $done -and (Get-WinForgeGuiReadSeconds -Reader $reader) -ge $script:HomeStepTimeoutSeconds) {
            Close-WinForgeGuiReader -Reader $reader
            $script:HomeReader = $null
            $reader = $null
            $done = [PSCustomObject]@{ Output = @(New-WinForgeHomeStepFailure -Name $owner.Name); Failed = $false }
        }

        if ($null -ne $done) {
            $script:HomeReaderOwner = $null
            $result = @($done.Output | Where-Object { $null -ne $_ -and $null -ne $_.PSObject.Properties["Facts"] }) | Select-Object -Last 1

            if ($null -eq $result -and $null -ne $reader) {
                # O leitor terminou sem resultado: Read-WinForgeHomeStep nunca lança erro, então quem falhou foi o leitor
                # (os módulos não carregaram nele, por exemplo), e falharia igual nas outras etapas. Ele é descartado, e
                # esta etapa e as próximas rodam aqui mesmo, em vez de todos os cartões dizerem "Não foi possível ler".
                Close-WinForgeGuiReader -Reader $reader
                $script:HomeReader = $null
                $script:HomeReaderBroken = $true
                Invoke-GuiDeferred -Action { Step-GuiHomeRead }
            }
            else {
                Receive-GuiHomeStep -Read $owner.Read -Result $result -Failed:($done.Failed -or $null -eq $result)
            }
        }
    }

    $waiting = $script:HomeReaderWaiting

    if ($null -eq $script:HomeReaderOwner -and $null -ne $waiting) {
        $script:HomeReaderWaiting = $null

        if ([object]::ReferenceEquals($waiting, $script:HomeRead) -and $script:CurrentPage -eq "home" -and $waiting.Next -lt $waiting.Steps.Count) {
            $name = [string]$waiting.Steps[$waiting.Next]
            $started = $false

            try {
                if ($null -eq $script:HomeReader) {
                    $script:HomeReader = New-WinForgeGuiReader -ModuleRoot $moduleRoot -Modules @(Get-WinForgeHomeReaderModules)
                }

                $started = Start-WinForgeGuiRead -Reader $script:HomeReader -Command "Read-WinForgeHomeStep" -Arguments @{ Name = $name }
            }
            catch {
                $script:HomeReaderBroken = $true
            }

            if ($started) {
                $script:HomeReaderOwner = [PSCustomObject]@{ Read = $waiting; Name = $name }
            }
            else {
                # Sem leitor: a etapa roda aqui mesmo, no próximo tique.
                $script:HomeReaderBroken = $true
                Invoke-GuiDeferred -Action { Step-GuiHomeRead }
            }
        }
    }

    if ($null -eq $script:HomeReaderOwner) { $script:HomeReaderTimer.Stop() } else { $script:HomeReaderTimer.Start() }
}

function Complete-GuiHomeRead {
    $read = $script:HomeRead
    $script:HomeRead = $null

    if ($null -eq $read) { return }

    $built = $null

    try {
        # Um cartão cuja etapa falhou por inteiro não fica esperando para sempre (o da bateria, que só existe em
        # alguns PCs, continua escondido); se ele entra na nota, a nota diz que ele ficou de fora.
        $known = @($read.Facts | ForEach-Object { [string]$_.Id })
        $optional = @(Get-WinForgeHomeOptionalFacts)
        $scored = @(Get-WinForgeHomeScoredFacts)
        $unread = @($read.Unread)
        $missing = @()

        # Esses cartões também entram na leitura guardada: mostrada de novo (na volta ao Início ou na troca de tema), ela
        # diz "Não foi possível ler", e não volta a esperar.
        foreach ($id in @($script:HomeFacts.Keys)) {
            if ($id -notin $known) {
                $fact = [PSCustomObject]@{ Id = $id; Text = (Get-WinForgeText 'Não foi possível ler'); Level = "Muted"; Visible = ($id -notin $optional) }
                Set-GuiHomeFact -Fact $fact
                $missing += $fact
                if ($id -in $scored) { $unread += $script:HomeFactInfo[$id].Label }
            }
        }

        # Sem a etapa da manutenção agendada (falhou ou passou do prazo), ela conta como não agendada, como quando o
        # Agendador de Tarefas não responde.
        $snapshot = [PSCustomObject]@{
            Facts         = @(@($read.Facts) + $missing)
            Notices       = @($read.Notices)
            Health        = $null
            ReadAt        = (Get-Date)
            Failed        = $false
            ScheduleSetup = [bool]$read.ScheduleSetup
        }

        # Os cartões ficam guardados mesmo que a nota não possa ser montada: a troca de tema mostra de novo o que foi
        # lido (com a nota dizendo que falhou), em vez de ler o PC outra vez.
        $built = $snapshot
        $script:HomeLastSnapshot = $snapshot
        $snapshot.Health = Get-WinForgeHealthScore -Issues $read.Issues -Unread $unread

        Show-GuiHomeResult -Snapshot $snapshot

        # Só uma leitura que pôde ser mostrada fica guardada. Como a mais recente, sempre; como a que vale por 30
        # segundos, não quando houve falha inesperada, nem quando começou antes de o PC mudar (uma ação terminou no meio
        # dela e descartou o que estava guardado): a próxima visita lê de novo.
        $current = (-not $read.Failed -and $read.Version -eq $script:HomeCacheVersion)
        $script:HomeSnapshot = $(if ($current) { $snapshot } else { $null })
        $script:HomeLastSnapshot = $snapshot
    }
    catch {
        # A nota não pôde ser montada: o cartão diz isso e mantém a hora e o botão de ler de novo (ligado).
        $script:HomeSnapshot = $null
        if ($null -ne $built) { $built.Failed = $true; $built.Health = $null }

        Set-GuiHomeStamp -Text (Get-WinForgeText 'A leitura não terminou') -CanRefresh $true

        try { Update-GuiHealthCard -Failed } catch { Write-Verbose "Nota de saúde: $($_.Exception.Message)" }
    }

    # O leitor de tela ouve a frase nova da nota, que chegou sem a pessoa pedir. Só quando uma leitura termina: ao voltar
    # ao Início com a leitura guardada, a frase já está na tela, e anunciá-la de novo a cada visita repetiria a página.
    if ($null -ne $script:HomeHeadline) {
        try { Send-GuiAnnouncement -Element $script:HomeHeadline } catch { Write-Verbose "Leitor de tela: $($_.Exception.Message)" }
    }
}

function Request-GuiHomeRefresh {
    # Ler de novo (o botão ao lado da hora, ou F5): lê no lugar, sem refazer a página; os cartões mantêm o valor antigo até a etapa
    # deles terminar. Com uma leitura em andamento, o pedido é ignorado, a não ser com Force (uma ação acabou de terminar).
    param ([switch]$Force)

    if ($script:CurrentPage -ne "home") { return }

    if ($null -ne $script:HomeRead -and -not $Force) { return }

    Clear-GuiHomeCache
    Start-GuiHomeRead -Refresh:($null -ne $script:HomeLastSnapshot)
}

function New-GuiScoreBlock {
    <#
    A nota de saúde, à direita do cartão: o número grande com "/ 100" na mesma linha de base, os dez traços
    (Get-WinForgeScoreMarks: cheios na cor da nota, vazios no trilho) e, embaixo, a hora da leitura com o botão de ler de
    novo. Score negativo = ainda sem nota (um traço no lugar do número, os traços vazios). A largura (Width) acompanha o
    tamanho do texto do Windows, e o número diminui até caber nela.
    #>
    param (
        [int]$Score,
        [string]$Color,
        [double]$Width
    )

    $block = New-Object System.Windows.Controls.StackPanel
    $block.Width = $Width
    $block.VerticalAlignment = "Center"

    # O número e "/ 100" num texto só, para ficarem na mesma linha de base.
    $number = New-Object System.Windows.Controls.TextBlock
    $number.TextWrapping = "NoWrap"
    Set-GuiDisplayFont -Element $number

    $big = New-Object System.Windows.Documents.Run
    $big.Text = $(if ($Score -lt 0) { "–" } else { "$Score" })
    $big.FontSize = $script:Type.Display
    $big.FontWeight = [System.Windows.FontWeights]::Bold
    $big.Foreground = New-GuiBrush $script:Theme.Text
    [void]$number.Inlines.Add($big)

    # O espaço entre os dois no tamanho do número, como no desenho.
    $gap = New-Object System.Windows.Documents.Run
    $gap.Text = " "
    $gap.FontSize = $script:Type.Display
    [void]$number.Inlines.Add($gap)

    $of = New-Object System.Windows.Documents.Run
    $of.Text = "/ 100"
    $of.FontSize = $script:Type.Subtitle
    $of.Foreground = New-GuiBrush $script:Theme.Muted
    [void]$number.Inlines.Add($of)

    [void]$block.Children.Add((New-GuiValueBox -Text $number))

    $marks = New-Object System.Windows.Controls.Primitives.UniformGrid
    $marks.Rows = 1
    $marks.Columns = 10
    $marks.Height = [Math]::Max(4, [Math]::Round(5 * [Math]::Sqrt($script:TextScale)))
    $marks.Margin = New-Object System.Windows.Thickness (0, 8, -4, 0)
    $marks.IsHitTestVisible = $false
    $filled = Get-WinForgeScoreMarks -Score $Score -Count 10

    for ($i = 0; $i -lt 10; $i++) {
        $mark = New-Object System.Windows.Controls.Border
        $mark.CornerRadius = New-Object System.Windows.CornerRadius 2
        $mark.Margin = New-Object System.Windows.Thickness (0, 0, 4, 0)
        $mark.Background = New-GuiBrush $(if ($i -lt $filled) { $Color } else { $script:Theme.Track })
        [void]$marks.Children.Add($mark)
    }

    [void]$block.Children.Add($marks)

    $stamp = New-GuiHomeStampBar
    $stamp.Margin = New-Object System.Windows.Thickness (0, 10, 0, 0)
    [void]$block.Children.Add($stamp)

    return $block
}

function New-GuiHealthButtons {
    # Os dois caminhos para cuidar do PC, sempre à mão: Verificar o PC (que confere e corrige num clique o que é seguro) e
    # o Otimizar (a manutenção completa e guiada), nessa ordem, do mais leve ao mais completo. Eles não dependem da
    # leitura: aparecem também enquanto a nota é calculada e quando ela não pôde ser calculada. PrimaryId é o que fica em
    # destaque (Update-GuiHealthCard decide): o Otimizar sem pontos de atenção; com pontos, o que resolve o mais pesado,
    # que pode ser um destes ("" quando é o botão do próprio ponto). Verificar vírus fica na página Segurança, aonde o
    # cartão Proteção leva. Os dois são maiores que os botões comuns: são o caminho principal da tela.
    param ([AllowEmptyString()][string]$PrimaryId = "maintenance.recommended")

    $buttons = New-Object System.Windows.Controls.WrapPanel

    foreach ($entry in @(@{ Id = "maintenance.checkup"; Icon = "scan" }, @{ Id = "maintenance.recommended"; Icon = "sparkles" })) {
        $navItem = Get-WinForgeNavItem -Id $entry.Id

        if ($null -eq $navItem) { continue }

        $go = New-GuiButton -Text $navItem.Label -Kind $(if ($entry.Id -eq $PrimaryId) { "Primary" } else { "Secondary" }) -Icon $entry.Icon -Tag $navItem
        $go.Padding = New-Object System.Windows.Thickness (16, 10, 18, 10)
        $go.Margin = New-Object System.Windows.Thickness (0, 0, 12, 4)
        $go.Add_Click({
            param ($sender, $eventArgs)
            Invoke-GuiNavItem -Item $sender.Tag
        })
        [void]$buttons.Children.Add($go)
    }

    return $buttons
}

function Set-GuiHeroLayout {
    # A nota à direita da frase (Wide), numa faixa inclinada, ou embaixo dos botões, sem a faixa; muda só quando o arranjo
    # muda.
    param (
        [Parameter(Mandatory)]$Grid,
        [bool]$Wide
    )

    $parts = $Grid.Tag
    if ($parts.Wide -eq $Wide) { return }
    $parts.Wide = $Wide

    $score = $parts.Score

    if ($Wide) {
        [System.Windows.Controls.Grid]::SetColumn($score, 1)
        [System.Windows.Controls.Grid]::SetRow($score, 0)
        $score.Margin = New-Object System.Windows.Thickness (32, 0, 0, 0)
        $score.HorizontalAlignment = "Right"
    }
    else {
        [System.Windows.Controls.Grid]::SetColumn($score, 0)
        [System.Windows.Controls.Grid]::SetRow($score, 1)
        $score.Margin = New-Object System.Windows.Thickness (0, 24, 0, 0)
        $score.HorizontalAlignment = "Left"
    }

    Update-GuiHeroBand -Parts $parts
}

function Update-GuiHeroBand {
    <#
    A faixa inclinada atrás da nota (Get-WinForgeHeroBand): começa no alto um pouco à esquerda da nota e desce inclinada,
    com uma linha fina no lado inclinado e outra paralela a ele. Só com a nota ao lado da frase e fora do contraste alto;
    refeita quando o cartão muda de tamanho. Com pontos de atenção embaixo, ela fica só na parte de cima, até o traço que
    os separa (Get-GuiHeroBandHeight).
    #>
    param ([Parameter(Mandatory)]$Parts)

    $frame = $Parts.Frame
    $band = $null

    if ($Parts.Wide -and $script:ThemeName -ne "Contrast") {
        $width = [double]$frame.ActualWidth
        $height = Get-GuiHeroBandHeight -Parts $Parts
        $start = $width - $Parts.Inset - $Parts.ScoreWidth - [Math]::Round(0.45 * $Parts.ScoreWidth)
        $band = Get-WinForgeHeroBand -Width $width -Height $height -Start $start -Slant ([Math]::Round(0.9 * $height)) -Gap 12
    }

    if ($null -eq $band) {
        foreach ($shape in @($Parts.Band, $Parts.Edge, $Parts.Trail)) { $shape.Visibility = "Collapsed" }
        return
    }

    $points = New-Object System.Windows.Media.PointCollection
    foreach ($point in $band.Points) { [void]$points.Add((New-Object System.Windows.Point ($point[0], $point[1]))) }
    $Parts.Band.Points = $points

    foreach ($pair in @(@($Parts.Edge, $band.Edge), @($Parts.Trail, $band.Trail))) {
        $pair[0].X1 = $pair[1][0][0]; $pair[0].Y1 = $pair[1][0][1]
        $pair[0].X2 = $pair[1][1][0]; $pair[0].Y2 = $pair[1][1][1]
    }

    foreach ($shape in @($Parts.Band, $Parts.Edge, $Parts.Trail)) { $shape.Visibility = "Visible" }
}

function Get-GuiHeroBandHeight {
    <#
    A altura da faixa inclinada da nota: o cartão inteiro sem pontos de atenção; com eles, só até o traço que os separa da
    frase e da nota. Atravessando a lista, as duas linhas finas da faixa cortariam o texto e os botões dos pontos, e o
    lado inclinado ficaria tão comprido quanto a lista.
    #>
    param ([Parameter(Mandatory)]$Parts)

    $height = [double]$Parts.Frame.ActualHeight

    if ($null -ne $Parts.Rule -and $null -ne $Parts.Grid -and $null -ne $Parts.Content) {
        $top = [double]$Parts.Content.Margin.Top + [double]$Parts.Grid.ActualHeight + [double]$Parts.Rule.Margin.Top
        if ($top -gt 0 -and $top -lt $height) { $height = $top }
    }

    return $height
}

function Update-GuiHealthCard {
    <#
    O cartão da nota de saúde, no alto do Início. À esquerda: "Saúde do PC" com o ícone do estado, a frase do estado (grande,
    e que diminui até caber, sem cortar), o resumo e os botões Verificar o PC e Otimizar. À direita, numa faixa inclinada: a
    nota, os dez traços e a hora da leitura com o botão de ler de novo (New-GuiScoreBlock). Embaixo, cada ponto de atenção
    com o botão que o resolve. Numa janela estreita (ou com o texto do Windows grande), a nota desce para baixo dos botões e
    a faixa some (Test-WinForgeHeroWide). Sem nota (Health $null), o cartão mostra que a leitura está em andamento; com
    -Failed, que a nota não pôde ser montada.
    #>
    param (
        $Health,
        [switch]$Failed
    )

    # A nota é refeita quando a leitura termina: quem estava num botão dela com o teclado continua nele.
    $focus = Get-GuiHomeHealthFocus
    $script:HomeHealth.Children.Clear()

    $issues = @()
    $line = ""
    $score = -1
    $tone = "Muted"

    # Nada do que forma a nota foi lido, e nenhum ponto apareceu: um "100" não diria nada sobre o PC.
    $unknown = ($null -ne $Health -and -not (Test-WinForgeHealthKnown -Health $Health))

    if ($Failed -or $unknown -or $null -eq $Health) {
        if ($Failed) {
            $title = (Get-WinForgeText 'Não foi possível calcular a nota')
            $line = (Get-WinForgeText 'Os cartões abaixo mostram o que foi lido. Tente ler de novo.')
            $spoken = (Get-WinForgeText 'Saúde do PC: não foi possível calcular a nota')
        }
        elseif ($unknown) {
            $title = (Get-WinForgeText 'Não foi possível avaliar o PC')
            $line = (Get-WinForgeText 'Nenhuma das leituras que formam a nota respondeu. Tente ler de novo.')
            $spoken = (Get-WinForgeText 'Saúde do PC: não foi possível avaliar')
        }
        else {
            # "Lendo", e não "Verificando": verificar é com Verificar o PC e Verificar vírus, que mudam o PC.
            $title = (Get-WinForgeText 'Lendo o estado do PC...')
            $line = (Get-WinForgeText 'Cada cartão abaixo aparece assim que é lido.')
            $spoken = (Get-WinForgeText 'Saúde do PC: lendo o estado do PC')
        }
    }
    else {
        $tone = $(if ($Health.Level -eq "Bad") { "Bad" } elseif ($Health.Level -eq "Warn") { "Warn" } else { "Ok" })
        $score = [int]$Health.Score
        $issues = @($Health.Issues | Where-Object { $null -ne $_ })

        $title = Get-WinForgeHealthHeadline -Health $Health

        # Com os pontos à vista logo abaixo, a frase não os conta de novo: fica só o que não pôde ser lido.
        $line = Get-WinForgeHealthSummary -Health $Health -WithoutCount:($issues.Count -gt 0)
        $spoken = (Get-WinForgeText 'Saúde do PC: nota {0} de 100, {1}. {2}' "$($Health.Score)" "$($Health.Label)" "$(Get-WinForgeHealthSummary -Health $Health)")
    }

    $colors = $script:LevelColors[$tone]

    # Um botão por ação e um destaque só (Get-WinForgeHealthActionPlan): o ponto que se resolve com Verificar o PC não
    # ganha outro botão igual, e, sendo o mais pesado, é o da nota que fica em destaque.
    $plan = Get-WinForgeHealthActionPlan -Issues $issues
    $primaryId = [string]$plan.PrimaryId

    # A frase, o resumo e os botões (coluna 0) | a nota (coluna 1, ou embaixo, na linha 1, quando não cabe ao lado).
    $grid = New-Object System.Windows.Controls.Grid
    $textColumn = New-Object System.Windows.Controls.ColumnDefinition
    $scoreColumn = New-Object System.Windows.Controls.ColumnDefinition
    $scoreColumn.Width = [System.Windows.GridLength]::Auto
    [void]$grid.ColumnDefinitions.Add($textColumn)
    [void]$grid.ColumnDefinitions.Add($scoreColumn)
    [void]$grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition))
    $scoreRow = New-Object System.Windows.Controls.RowDefinition
    $scoreRow.Height = [System.Windows.GridLength]::Auto
    [void]$grid.RowDefinitions.Add($scoreRow)

    $text = New-Object System.Windows.Controls.StackPanel
    $text.VerticalAlignment = "Center"

    $kicker = New-Object System.Windows.Controls.StackPanel
    $kicker.Orientation = "Horizontal"
    $glyph = New-GuiIcon -Name $colors.Icon -Size 18 -Color $colors.Dot
    $glyph.Margin = New-Object System.Windows.Thickness (0, 0, 8, 0)
    [void]$kicker.Children.Add($glyph)
    $kickerText = New-GuiText -Text (Get-WinForgeText 'Saúde do PC') -Size $script:Type.Body -Color $colors.Dot -Bold $true
    $kickerText.VerticalAlignment = "Center"
    [void]$kicker.Children.Add($kickerText)
    [void]$text.Children.Add($kicker)

    $headline = New-GuiText -Text $title -Size $script:Type.TitleLarge -Display
    Set-GuiAutomationName -Element $headline -Name $spoken
    try { [System.Windows.Automation.AutomationProperties]::SetLiveSetting($headline, [System.Windows.Automation.AutomationLiveSetting]::Polite) } catch { Write-Verbose "Leitor de tela: $($_.Exception.Message)" }
    $headlineBox = New-GuiValueBox -Text $headline
    $headlineBox.Margin = New-Object System.Windows.Thickness (0, 10, 0, 0)
    [void]$text.Children.Add($headlineBox)
    $script:HomeHeadline = $headline

    if (-not [string]::IsNullOrEmpty($line)) {
        $lineText = New-GuiText -Text $line -Size $script:Type.Body -Color $script:Theme.Muted
        $lineText.Margin = New-Object System.Windows.Thickness (0, 6, 0, 0)
        [void]$text.Children.Add($lineText)
    }

    $buttonRow = New-GuiHealthButtons -PrimaryId $primaryId
    $buttonRow.Margin = New-Object System.Windows.Thickness (0, 22, 0, 0)
    [void]$text.Children.Add($buttonRow)

    [System.Windows.Controls.Grid]::SetColumn($text, 0)
    [void]$grid.Children.Add($text)

    # O leitor de tela e o Tab chegam à nota (e ao botão de ler de novo) depois dos botões, nos dois arranjos.
    $scoreWidth = [Math]::Round(216.0 * [Math]::Sqrt($script:TextScale))
    $scoreBlock = New-GuiScoreBlock -Score $score -Color $colors.Dot -Width $scoreWidth
    [void]$grid.Children.Add($scoreBlock)

    $content = New-Object System.Windows.Controls.StackPanel
    $content.Margin = New-Object System.Windows.Thickness (28, 24, 28, 24)
    [void]$content.Children.Add($grid)
    $rule = $null

    if ($issues.Count -gt 0) {
        $rule = New-Object System.Windows.Controls.Border
        $rule.Height = 1
        $rule.Background = New-GuiBrush $script:Theme.Line
        $rule.Margin = New-Object System.Windows.Thickness (0, 22, 0, 6)
        [void]$content.Children.Add($rule)
    }

    $index = 0

    foreach ($issue in $issues) {
        $rowPlan = @($plan.Rows)[$index]
        $index++

        $row = New-Object System.Windows.Controls.DockPanel
        $row.Margin = New-Object System.Windows.Thickness (0, 6, 0, 0)
        # Sem botão na linha, a altura de um botão mantém o espaço entre os pontos igual.
        $row.MinHeight = 32 * $script:TextScale

        # O botão do primeiro ponto (o mais pesado) é o principal da tela; os outros, comuns. Um ponto que se resolve com um
        # dos botões da nota (Verificar o PC) fica sem botão: o da nota faz o mesmo, logo acima.
        if ([bool]$rowPlan.Button) {
            $fix = New-GuiButton -Text $issue.ButtonText -Kind $(if ([bool]$rowPlan.Primary) { "Primary" } else { "Secondary" }) -Tag $issue
            $fix.Margin = New-Object System.Windows.Thickness (12, 0, 0, 0)
            $fix.VerticalAlignment = "Center"
            Set-GuiDock -Element $fix -Side "Right"
            # A gravidade não fica só na cor e no desenho do ícone: o leitor de tela ouve "(grave)".
            Set-GuiAutomationName -Element $fix -Name "$($issue.ButtonText): $($issue.Text)$(if ($issue.Severe) { (Get-WinForgeText ' (grave)') })"
            $fix.Add_Click({
                param ($sender, $eventArgs)
                Invoke-GuiNextStep -Next ([string]$sender.Tag.Target) -Title ([string]$sender.Tag.ButtonText)
            })
            [void]$row.Children.Add($fix)
        }

        # Um ponto grave (que limita a nota) tem o círculo vermelho; os demais, o triângulo amarelo.
        $issueGlyph = New-GuiIcon -Name $(if ($issue.Severe) { "error-circle" } else { "warning" }) -Size 18 -Color $(if ($issue.Severe) { $script:Theme.Bad } else { $script:Theme.Warn })
        $issueGlyph.Margin = New-Object System.Windows.Thickness (0, 0, 12, 0)
        Set-GuiDock -Element $issueGlyph -Side "Left"
        [void]$row.Children.Add($issueGlyph)

        $issueText = New-GuiText -Text $issue.Text -Size $script:Type.Body
        $issueText.VerticalAlignment = "Center"
        [void]$row.Children.Add($issueText)

        [void]$content.Children.Add($row)
    }

    # A faixa inclinada fica atrás do conteúdo, no cartão inteiro (sem o espaçamento), e os cantos a cortam. Num Canvas,
    # que não pede tamanho: a faixa de uma largura anterior não segura o cartão largo quando a janela diminui.
    $frame = New-Object System.Windows.Controls.Grid
    $decor = New-Object System.Windows.Controls.Canvas
    $decor.IsHitTestVisible = $false

    $band = New-Object System.Windows.Shapes.Polygon
    $band.Fill = New-GuiBrush $script:Theme.HeroPanel
    $band.Visibility = "Collapsed"
    [void]$decor.Children.Add($band)

    $edge = New-Object System.Windows.Shapes.Line
    $trail = New-Object System.Windows.Shapes.Line

    foreach ($stroke in @($edge, $trail)) {
        $stroke.Stroke = New-GuiBrush $script:Theme.Line
        $stroke.StrokeThickness = 1
        $stroke.Visibility = "Collapsed"
        [void]$decor.Children.Add($stroke)
    }

    [void]$frame.Children.Add($decor)
    [void]$frame.Children.Add($content)

    $parts = @{
        Score = $scoreBlock; Wide = $null; Frame = $frame; Band = $band; Edge = $edge; Trail = $trail
        ScoreWidth = $scoreWidth; Inset = $content.Margin.Right; Content = $content; Grid = $grid; Rule = $rule
    }
    $grid.Tag = $parts
    Set-GuiHeroLayout -Grid $grid -Wide $true

    $grid.Add_SizeChanged({
        param ($sender, $eventArgs)

        if (-not $eventArgs.WidthChanged) { return }

        try {
            Set-GuiHeroLayout -Grid $sender -Wide (Test-WinForgeHeroWide -Width $sender.ActualWidth -ScoreWidth ($sender.Tag.ScoreWidth + 32) -MinText (320 * $script:TextScale))
        }
        catch {
            Write-Verbose "Arranjo da nota: $($_.Exception.Message)"
        }
    })

    $frame.Tag = $parts
    $frame.Add_SizeChanged({
        param ($sender, $eventArgs)

        try {
            $sender.Clip = New-Object System.Windows.Media.RectangleGeometry ((New-Object System.Windows.Rect (0, 0, $sender.ActualWidth, $sender.ActualHeight)), 8, 8)
            Update-GuiHeroBand -Parts $sender.Tag
        }
        catch {
            Write-Verbose "Faixa da nota: $($_.Exception.Message)"
        }
    })

    $border = New-GuiOutlinedBorder -Background $script:Theme.Hero -BorderColor $script:Theme.Line -Radius 8 -Padding (New-Object System.Windows.Thickness 0)
    Set-GuiPanelContent -Panel $border -Content $frame
    Set-GuiAutomationName -Element $border -Name $spoken

    if ((Add-GuiHomePart -Element $border -Name (Get-WinForgeText 'Saúde do PC') -Panel $script:HomeHealth) -and $focus) {
        Restore-GuiHomeHealthFocus -Key $focus
    }
}

function Get-GuiHomeFocusKey {
    # Como achar de novo um botão da nota de saúde depois de ela ser refeita: pelo item ou ponto que ele abre (Id), ou o
    # botão de ler de novo.
    param ($Element)

    if ($null -eq $Element) { return "" }
    if ([object]::ReferenceEquals($Element, $script:HomeRefreshButton)) { return "refresh" }

    $tag = $Element.Tag
    if ($null -ne $tag -and $null -ne $tag.PSObject.Properties["Id"] -and [string]$tag.Id) { return "id:$($tag.Id)" }

    return "first"
}

function Get-GuiHomeHealthFocus {
    # O botão da nota de saúde com o foco do teclado (Get-GuiHomeFocusKey), ou "" quando o foco está fora dela. O botão de
    # ler de novo desligado na leitura (HomeRefreshFocus) deixou o foco em nenhum elemento ou num que contém a nota: ele
    # volta a esse botão. Um foco que a pessoa levou para outro lugar fica onde está.
    try {
        $focused = [System.Windows.Input.Keyboard]::FocusedElement
        $lost = [bool]$script:HomeRefreshFocus
        $script:HomeRefreshFocus = $false

        if ($null -eq $script:HomeHealth) { return "" }
        if ($lost -and ($null -eq $focused -or ($focused -is [System.Windows.Media.Visual] -and $focused.IsAncestorOf($script:HomeHealth)))) { return "refresh" }
        if (-not ($focused -is [System.Windows.DependencyObject])) { return "" }
        if (-not $script:HomeHealth.IsAncestorOf($focused)) { return "" }

        return (Get-GuiHomeFocusKey -Element $focused)
    }
    catch {
        return ""
    }
}

function Restore-GuiHomeHealthFocus {
    # Põe o foco no botão da nota refeita que corresponde ao de antes; sem ele (o ponto foi resolvido), no primeiro botão
    # dela, para o teclado continuar ali, e não voltar ao começo da janela.
    param ([Parameter(Mandatory)][string]$Key)

    # Os botões na ordem da árvore, que é a do Tab: Verificar o PC, Otimizar, ler de novo e os dos pontos.
    $buttons = New-Object System.Collections.ArrayList
    $stack = New-Object System.Collections.Stack
    $stack.Push($script:HomeHealth)

    while ($stack.Count -gt 0) {
        $node = $stack.Pop()

        if ($node -is [System.Windows.Controls.Button]) { [void]$buttons.Add($node); continue }

        $next = @()
        if ($node -is [System.Windows.Controls.Panel]) { $next = @($node.Children | ForEach-Object { $_ }) }
        elseif ($node -is [System.Windows.Controls.Decorator]) { if ($null -ne $node.Child) { $next = @($node.Child) } }
        elseif ($node -is [System.Windows.Controls.ContentControl] -and $node.Content -is [System.Windows.UIElement]) { $next = @($node.Content) }

        for ($i = $next.Count - 1; $i -ge 0; $i--) { $stack.Push($next[$i]) }
    }

    $enabled = @($buttons | Where-Object { $_.IsEnabled })
    $target = $null

    foreach ($candidate in $enabled) {
        if ((Get-GuiHomeFocusKey -Element $candidate) -eq $Key) { $target = $candidate; break }
    }

    if ($null -eq $target -and $enabled.Count -gt 0) { $target = $enabled[0] }

    if ($null -ne $target) {
        try { [void]$target.Focus() } catch { Write-Verbose "Foco: $($_.Exception.Message)" }
    }
}

function New-GuiPageStatus {
    <#
    O resumo no alto de uma página (Manutenção, Limpeza, Desempenho, Rede, Atualizações, Programas e Sobre o WinForge):
    uma linha por informação, com o rótulo à esquerda. Vem de leituras rápidas (arquivos pequenos do WinForge, o espaço do
    disco, a memória, o que o Windows diz da conexão, o Registro, se o winget existe), então não atrasa a página; se a
    leitura falhar, ou não houver o que dizer, a página aparece sem ele. As páginas de ajustes passam as linhas já lidas
    (Rows, de Get-WinForgeTweaksPageStatus), feitas da lista que acabaram de ler. Uma linha com destino (Opens, um item da
    navegação) é um botão com a seta, como as linhas das listas: a da Manutenção abre o Histórico de manutenções; as da
    Limpeza, do Desempenho, da Rede, das Atualizações e dos Programas, quando pedem atenção, o que resolve (a Limpeza
    personalizada, Programas pesando agora, Tempo ligado e energia, Testar conectividade, Suporte do Windows, o Windows
    Update das Configurações, Instalar atualizações do Windows, Reparar o Instalador de Aplicativo).
    #>
    param (
        [Parameter(Mandatory)]$Page,
        [object[]]$Rows = $null
    )

    if ($PSBoundParameters.ContainsKey("Rows")) {
        $rows = @($Rows | Where-Object { $null -ne $_ })
    }
    else {
        $reader = switch ([string]$Page.Id) {
            "maintenance" { "Get-WinForgeMaintenancePageStatus" }
            "cleanup"     { "Get-WinForgeCleanupPageStatus" }
            "performance" { "Get-WinForgePerformancePageStatus" }
            "network"     { "Get-WinForgeNetworkPageStatus" }
            "updates"     { "Get-WinForgeUpdatesPageStatus" }
            "software"    { "Get-WinForgeSoftwarePageStatus" }
            "app"         { "Get-WinForgeAboutPageStatus" }
            default       { $null }
        }

        if ($null -eq $reader) { return $null }

        try {
            $rows = @(& $reader)
        }
        catch {
            return $null
        }
    }

    if ($rows.Count -eq 0) { return $null }

    $colors = @{ Normal = $script:Theme.Text; Warn = $script:Theme.Warn; Muted = $script:Theme.Muted }
    $lines = @()

    foreach ($row in $rows) {
        $line = New-Object System.Windows.Controls.DockPanel

        $label = New-GuiText -Text ([string]$row.Label) -Size $script:Type.Body -Color $script:Theme.Muted
        $label.Width = 160
        Set-GuiDock -Element $label -Side "Left"
        [void]$line.Children.Add($label)

        $item = $null
        $opens = [string](Get-WinForgeJsonValue -Object $row -Name "Opens" -Default "")
        if ($opens) { $item = Get-WinForgeNavItem -Id $opens }

        if ($null -ne $item) {
            $chevron = New-GuiIcon -Name "chevron-right" -Size 16 -Color $script:Theme.Muted
            $chevron.Margin = New-Object System.Windows.Thickness (16, 0, 0, 0)
            $chevron.VerticalAlignment = "Center"
            Set-GuiDock -Element $chevron -Side "Right"
            [void]$line.Children.Add($chevron)
        }

        $level = [string]$row.Level
        $text = New-GuiText -Text ([string]$row.Text) -Size $script:Type.Body -Color $(if ($colors.ContainsKey($level)) { $colors[$level] } else { $script:Theme.Text })
        [void]$line.Children.Add($text)

        $lines += [PSCustomObject]@{ Line = $line; Item = $item; Spoken = "$([string]$row.Label): $([string]$row.Text)" }
    }

    if (@($lines | Where-Object { $null -ne $_.Item }).Count -eq 0) {
        $border = New-GuiPanelBorder
        $border.Margin = New-Object System.Windows.Thickness (0, 0, 12, 16)
        $stack = New-Object System.Windows.Controls.StackPanel

        foreach ($entry in $lines) {
            $entry.Line.Margin = New-Object System.Windows.Thickness (0, 3, 0, 3)
            [void]$stack.Children.Add($entry.Line)
        }

        Set-GuiPanelContent -Panel $border -Content $stack

        return $border
    }

    # Com destino, cada linha ocupa a faixa de ponta a ponta (o fundo sob o mouse vai até a borda): o recuo da moldura
    # passa para dentro de cada linha, e a altura fica a da faixa sem destino.
    $group = New-GuiRowGroup
    $group.Element.Margin = New-Object System.Windows.Thickness (0, 0, 12, 16)

    foreach ($entry in $lines) {
        if ($null -eq $entry.Item) {
            $plain = New-Object System.Windows.Controls.Border
            $plain.Padding = New-Object System.Windows.Thickness (18, 17, 18, 17)
            $plain.Child = $entry.Line
            Add-GuiRowToGroup -Group $group -Row $plain
            continue
        }

        $button = New-Object System.Windows.Controls.Button
        $button.Style = $window.FindResource("RowButton")
        $button.MinHeight = 0
        $button.Padding = New-Object System.Windows.Thickness (18, 17, 18, 17)
        $button.Tag = $entry.Item
        $button.Content = $entry.Line
        Set-GuiAutomationName -Element $button -Name "$($entry.Spoken)$(Get-WinForgeText '. Abre: {0}' "$($entry.Item.Label)")"
        $button.Add_Click({
            param ($sender, $eventArgs)
            Invoke-GuiNavItem -Item $sender.Tag
        })
        Add-GuiRowToGroup -Group $group -Row $button
    }

    return $group.Element
}

function Set-GuiChoiceGroupKeyboard {
    <#
    O teclado de um grupo de escolhas na própria página (Aparência e Idioma), como um grupo de opções do Windows: o Tab
    entra no grupo na escolha marcada (sem nenhuma, na primeira) e sai dele de uma vez; as setas andam pelas escolhas, sem
    dar a volta do fim para o começo; Espaço ou Enter escolhe a que tem o foco.
    #>
    param (
        [Parameter(Mandatory)]$Panel,
        $Selected = $null
    )

    try {
        [System.Windows.Input.KeyboardNavigation]::SetTabNavigation($Panel, [System.Windows.Input.KeyboardNavigationMode]::Once)
        [System.Windows.Input.KeyboardNavigation]::SetDirectionalNavigation($Panel, [System.Windows.Input.KeyboardNavigationMode]::Contained)

        $target = $(if ($null -ne $Selected) { $Selected } else { @($Panel.Children)[0] })
        if ($null -ne $target) { [System.Windows.Input.KeyboardNavigation]::SetTabOnceActiveElement($Panel, $target) }
    }
    catch {
        Write-Verbose "Teclado: $($_.Exception.Message)"
    }
}

function New-GuiAppearanceCard {
    # Sobre o WinForge > Aparência: como o Windows (o padrão), clara ou escura. Vale na hora, sem reabrir a janela.
    $border = New-GuiPanelBorder
    $border.Margin = New-Object System.Windows.Thickness (0, 0, 12, 16)
    $border.Tag = "appearance"

    $row = New-Object System.Windows.Controls.DockPanel

    $segment = New-Object System.Windows.Controls.Border
    $segment.Background = New-GuiBrush $script:Theme.Inset
    $segment.CornerRadius = New-Object System.Windows.CornerRadius 4
    $segment.Padding = New-Object System.Windows.Thickness 2
    $segment.VerticalAlignment = "Center"
    $segment.Margin = New-Object System.Windows.Thickness (16, 0, 0, 0)
    Set-GuiDock -Element $segment -Side "Right"

    $choices = New-Object System.Windows.Controls.StackPanel
    $choices.Orientation = "Horizontal"
    Set-GuiAutomationName -Element $choices -Name (Get-WinForgeText 'Aparência')
    $chosen = $null

    foreach ($option in @(
            @{ Value = "System"; Text = (Get-WinForgeText 'Automático') },
            @{ Value = "Light"; Text = (Get-WinForgeText 'Claro') },
            @{ Value = "Dark"; Text = (Get-WinForgeText 'Escuro') }
        )) {
        $button = New-Object System.Windows.Controls.Button

        if ($script:ThemePreference -eq $option.Value) {
            $button.Style = $window.FindResource("SegmentButtonSelected")
        }
        else {
            $button.Style = $window.FindResource("SegmentButton")
        }

        $button.Content = $option.Text
        $button.Tag = $option.Value

        # O leitor de tela diz qual opção está marcada (a cor do botão não chega até ele).
        $selected = ($script:ThemePreference -eq $option.Value)
        Set-GuiAutomationName -Element $button -Name $(if ($selected) { (Get-WinForgeText 'Aparência: {0}, selecionada' "$($option.Text)") } else { (Get-WinForgeText 'Aparência: {0}' "$($option.Text)") })
        if ($selected -and $script:AppearanceRefocus) { $script:AppearanceFocusTarget = $button }

        $button.Add_Click({
            param ($sender, $eventArgs)
            Set-GuiThemePreference -Value ([string]$sender.Tag)
        })
        [void]$choices.Children.Add($button)
        if ($selected) { $chosen = $button }
    }

    Set-GuiChoiceGroupKeyboard -Panel $choices -Selected $chosen
    $segment.Child = $choices
    [void]$row.Children.Add($segment)

    $text = New-Object System.Windows.Controls.StackPanel
    $text.VerticalAlignment = "Center"
    [void]$text.Children.Add((New-GuiText -Text (Get-WinForgeText 'Aparência') -Size $script:Type.Body -Bold $true))

    $hint = New-GuiText -Text (Get-WinForgeText 'Automático acompanha o tema claro ou escuro escolhido nas Configurações do Windows.') -Size $script:Type.Caption -Color $script:Theme.Muted
    $hint.Margin = New-Object System.Windows.Thickness (0, 2, 0, 0)
    [void]$text.Children.Add($hint)
    [void]$row.Children.Add($text)

    Set-GuiPanelContent -Panel $border -Content $row

    return $border
}

function New-GuiLanguageCard {
    # Sobre o WinForge > Idioma: como o Windows (o padrão), português, inglês ou espanhol. Cada idioma aparece escrito
    # nele mesmo, para quem não lê o idioma atual achar o seu. Vale ao abrir de novo (Set-GuiLanguagePreference).
    $border = New-GuiPanelBorder
    $border.Margin = New-Object System.Windows.Thickness (0, 0, 12, 16)
    $border.Tag = "language"

    # A escolha guardada, relida a cada vez: o menu de texto (aberto em outra janela) também pode tê-la mudado.
    try { $script:LanguagePreference = Get-WinForgeLanguagePreference } catch { Write-Verbose "Idioma: $($_.Exception.Message)" }

    $row = New-Object System.Windows.Controls.DockPanel

    $segment = New-Object System.Windows.Controls.Border
    $segment.Background = New-GuiBrush $script:Theme.Inset
    $segment.CornerRadius = New-Object System.Windows.CornerRadius 4
    $segment.Padding = New-Object System.Windows.Thickness 2
    $segment.VerticalAlignment = "Center"
    $segment.Margin = New-Object System.Windows.Thickness (16, 0, 0, 0)
    Set-GuiDock -Element $segment -Side "Right"

    $choices = New-Object System.Windows.Controls.StackPanel
    $choices.Orientation = "Horizontal"
    Set-GuiAutomationName -Element $choices -Name (Get-WinForgeText 'Idioma')
    $chosen = $null

    foreach ($option in @(Get-WinForgeLanguageChoices)) {
        $button = New-Object System.Windows.Controls.Button
        $selected = ($script:LanguagePreference -eq [string]$option.Id)
        $button.Style = $window.FindResource($(if ($selected) { "SegmentButtonSelected" } else { "SegmentButton" }))
        $button.Content = [string]$option.Label
        $button.Tag = [string]$option.Id

        # O leitor de tela diz qual opção está marcada (a cor do botão não chega até ele).
        Set-GuiAutomationName -Element $button -Name $(if ($selected) { (Get-WinForgeText 'Idioma: {0}, selecionado' "$($option.Label)") } else { (Get-WinForgeText 'Idioma: {0}' "$($option.Label)") })
        if ($selected -and $script:LanguageRefocus) { $script:LanguageFocusTarget = $button }

        $button.Add_Click({
            param ($sender, $eventArgs)
            Set-GuiLanguagePreference -Value ([string]$sender.Tag)
        })
        [void]$choices.Children.Add($button)
        if ($selected) { $chosen = $button }
    }

    Set-GuiChoiceGroupKeyboard -Panel $choices -Selected $chosen
    $segment.Child = $choices
    [void]$row.Children.Add($segment)

    $text = New-Object System.Windows.Controls.StackPanel
    $text.VerticalAlignment = "Center"
    [void]$text.Children.Add((New-GuiText -Text (Get-WinForgeText 'Idioma') -Size $script:Type.Body -Bold $true))

    $hint = New-GuiText -Text (Get-WinForgeText 'Automático segue o idioma do Windows; fora do português e do espanhol, fica em inglês.') -Size $script:Type.Caption -Color $script:Theme.Muted
    $hint.Margin = New-Object System.Windows.Thickness (0, 2, 0, 0)
    [void]$text.Children.Add($hint)
    [void]$row.Children.Add($text)

    Set-GuiPanelContent -Panel $border -Content $row

    return $border
}

function Show-GuiListPage {
    param ([Parameter(Mandatory)]$Page)

    $pageTitle.Text = $Page.Title
    $pageSubtitle.Text = $Page.Summary
    $contentPanel.Children.Clear()

    $status = New-GuiPageStatus -Page $Page

    if ($null -ne $status) { [void]$contentPanel.Children.Add($status) }

    # O caminho recomendado da página (o item com Accent) vem em destaque no alto; os outros, em listas por seção
    # ("Liberar espaço", "Ferramentas do Windows"), cada uma com o seu título. Uma página sem seções é uma lista só.
    $rowGroup = $null
    $group = $null
    $heroShown = $false
    $heroId = ""

    if ($Page.Id -eq "app") {
        # Sobre o WinForge: Criar atalho é o destaque quando falta o atalho desta pasta, um deles abre outra ou o desta
        # conta precisa ser atualizado (Test-WinForgeAppShortcutNeeded), logo abaixo do resumo que diz isso. Com o atalho
        # pronto, é uma linha de Integração com o Windows, sem destaque; o destaque desta página se decide aqui.
        $heroShown = $true
        $accent = @($Page.Items | Where-Object { [bool]$_.Accent }) | Select-Object -First 1
        $needed = $true
        try { $needed = [bool](Test-WinForgeAppShortcutNeeded) } catch { $needed = $true }

        if ($null -ne $accent -and $needed) {
            $hero = New-GuiHeroCard -Item $accent
            # O mesmo espaço dos cartões de baixo (Aparência, Idioma).
            $hero.Margin = New-Object System.Windows.Thickness (0, 0, 12, 16)
            [void]$contentPanel.Children.Add($hero)
            $heroId = [string]$accent.Id
        }

        [void]$contentPanel.Children.Add((New-GuiAppearanceCard))
        [void]$contentPanel.Children.Add((New-GuiLanguageCard))
    }

    # Com outro antivírus protegendo o PC (o que o Início leu), as ações do Windows Defender não fariam nada; num PC sem
    # bateria, Saúde da bateria só diria isso: saem da página (Test-WinForgeNavItemHidden, a mesma regra da busca).
    $hidden = Get-GuiHiddenItemState

    foreach ($item in $Page.Items) {
        if (Test-WinForgeNavItemHidden -Id ([string]$item.Id) @hidden) { continue }

        # Itens fora da lista (o histórico de manutenções, aberto pela faixa do alto): a busca e o console chegam neles.
        if ($null -ne $item.PSObject.Properties["Unlisted"] -and [bool]$item.Unlisted) { continue }

        # O destaque já posto no alto (Sobre o WinForge) não se repete na lista.
        if ($heroId -and [string]$item.Id -eq $heroId) { continue }

        if ([bool]$item.Accent -and -not $heroShown) {
            [void]$contentPanel.Children.Add((New-GuiHeroCard -Item $item))
            $heroShown = $true
            continue
        }

        $itemGroup = [string]$item.Group

        if ($null -eq $rowGroup -or $itemGroup -ne $group) {
            if ($itemGroup) {
                [void]$contentPanel.Children.Add((New-GuiGroupHeading -Text $itemGroup -First ($contentPanel.Children.Count -eq 0)))
            }
            elseif ($null -ne $rowGroup -or $heroShown) {
                # Sem título, a lista nova ainda fica separada do que veio antes.
                $spacer = New-Object System.Windows.Controls.Border
                $spacer.Height = 16
                [void]$contentPanel.Children.Add($spacer)
            }

            $rowGroup = New-GuiRowGroup
            [void]$contentPanel.Children.Add($rowGroup.Element)
            $group = $itemGroup
        }

        Add-GuiRowToGroup -Group $rowGroup -Row (New-GuiActionRow -Item $item)
    }
}

function New-GuiTweakRow {
    # Uma linha de ajuste dentro do grupo da categoria: nome, descrição e avisos, o estado e a chave liga/desliga.
    param ([Parameter(Mandatory)]$Tweak)

    # Fundo e contorno transparentes; ganham cor quando a busca traz a pessoa até este ajuste (Set-GuiTweakRowHighlight).
    $border = New-GuiOutlinedBorder -Radius 4 -Padding (New-Object System.Windows.Thickness (10, 11, 10, 11))
    $border.Margin = New-Object System.Windows.Thickness (-10, 2, -10, 2)
    $border.Tag = [string]$Tweak.Id

    $grid = New-Object System.Windows.Controls.Grid
    $textColumn = New-Object System.Windows.Controls.ColumnDefinition
    $captionColumn = New-Object System.Windows.Controls.ColumnDefinition
    $captionColumn.Width = [System.Windows.GridLength]::Auto
    $captionColumn.MinWidth = 120
    $switchColumn = New-Object System.Windows.Controls.ColumnDefinition
    $switchColumn.Width = [System.Windows.GridLength]::Auto
    [void]$grid.ColumnDefinitions.Add($textColumn)
    [void]$grid.ColumnDefinitions.Add($captionColumn)
    [void]$grid.ColumnDefinitions.Add($switchColumn)

    $text = New-Object System.Windows.Controls.StackPanel
    [void]$text.Children.Add((New-GuiText -Text $Tweak.Name -Size $script:Type.Body -Bold $true))

    # A frase curta (até 60 letras); a inteira, quando é outra, aparece ao passar o mouse (a UX15 da R38).
    $detail = [string](Get-WinForgeTweakField -Entry $Tweak -Name "Detail" -Default $Tweak.Description)
    $description = New-GuiText -Text $Tweak.Description -Size $script:Type.Caption -Color $script:Theme.Muted
    $description.Margin = New-Object System.Windows.Thickness (0, 2, 0, 0)
    [void]$text.Children.Add($description)
    if ($detail -and $detail -ne [string]$Tweak.Description) { $text.ToolTip = $detail }

    if (-not [string]::IsNullOrWhiteSpace($Tweak.LaptopNote)) {
        # O aviso já começa com "Em notebook" ("Em notebook, consome mais bateria..."): vai como está, na cor de atenção.
        $warning = New-GuiText -Text ([string]$Tweak.LaptopNote) -Size $script:Type.Caption -Color $script:Theme.Warn
        $warning.Margin = New-Object System.Windows.Thickness (0, 2, 0, 0)
        [void]$text.Children.Add($warning)
    }

    $needsAdmin = ([bool]$Tweak.RequiresAdmin -and -not $script:IsAdmin)

    [System.Windows.Controls.Grid]::SetColumn($text, 0)
    [void]$grid.Children.Add($text)

    # A chave mostra o recurso do Windows como ele está agora (lido na abertura da página): ativado ou desativado.
    $inverted = [bool](Get-WinForgeTweakField -Entry $Tweak -Name "Inverted" -Default $false)
    $state = Get-WinForgeTweakSwitchState -Status $Tweak.Status -Inverted $inverted
    $colors = @{ Normal = $script:Theme.Text; Warn = $script:Theme.Warn; Muted = $script:Theme.Muted }

    # Elevado com outra conta, o estado lido de um ajuste do perfil do usuário seria o dessa conta, e a chave não o muda: a
    # linha diz "Outra conta", e a chave fica desligada (o resumo do alto diz por quê).
    $otherAccount = [bool](Get-WinForgeTweakField -Entry $Tweak -Name "OtherAccount" -Default $false)
    $captionText = $(if ($otherAccount) { (Get-WinForgeText 'Outra conta') } else { $state.Caption })
    $captionColor = $(if ($otherAccount) { $script:Theme.Muted } else { $colors[[string]$state.Level] })

    $caption = New-GuiText -Text $captionText -Size $script:Type.Caption -Color $captionColor -Bold $true
    $caption.VerticalAlignment = "Center"
    $caption.TextAlignment = "Right"

    # Pede Administrador: o escudo antes do estado, como nos botões do Windows (a frase fica na dica da chave).
    $status = New-Object System.Windows.Controls.StackPanel
    $status.Orientation = "Horizontal"
    $status.HorizontalAlignment = "Right"
    $status.VerticalAlignment = "Center"
    $status.Margin = New-Object System.Windows.Thickness (16, 0, 14, 0)

    if ($needsAdmin) {
        $shield = New-GuiIcon -Name "admin" -Size 16 -Color $script:Theme.Muted
        $shield.Margin = New-Object System.Windows.Thickness (0, 0, 8, 0)
        $shield.ToolTip = (Get-WinForgeText 'Pede Administrador ao executar')
        $shield.IsHitTestVisible = $true
        [void]$status.Children.Add($shield)
    }

    [void]$status.Children.Add($caption)
    [System.Windows.Controls.Grid]::SetColumn($status, 1)
    [void]$grid.Children.Add($status)

    $toggle = New-Object System.Windows.Controls.Primitives.ToggleButton
    $toggle.Style = $window.FindResource("SwitchToggle")
    $toggle.IsChecked = $state.IsOn
    $toggle.Tag = $Tweak
    $toggle.VerticalAlignment = "Center"
    $toggle.ToolTip = $(if ($otherAccount) { (Get-WinForgeText 'Vale para o perfil do usuário, e o WinForge está elevado com outra conta.') } elseif ($needsAdmin) { (Get-WinForgeText 'Ligue para ativar e desligue para desativar. Pede Administrador ao executar.') } else { (Get-WinForgeText 'Ligue para ativar e desligue para desativar.') })
    if ($otherAccount) { $toggle.IsEnabled = $false }
    Set-GuiAutomationName -Element $toggle -Name $Tweak.Name

    # O leitor de tela lê também o que o ajuste faz (a frase inteira), não só o nome.
    try { [System.Windows.Automation.AutomationProperties]::SetHelpText($toggle, $detail) } catch { Write-Verbose "Leitor de tela: $($_.Exception.Message)" }

    $toggle.Add_Click({
        param ($sender, $eventArgs)
        $tweak = $sender.Tag

        # A chave só mostra o estado real: volta ao que era e deixa a ação decidir (o novo estado aparece lido de novo do
        # Windows, na linha ou ao voltar da tela de execução). Assim, uma ação cancelada ou que falha nunca deixa a chave
        # mentindo.
        $shown = (Get-WinForgeTweakSwitchState -Status $tweak.Status -Inverted ([bool](Get-WinForgeTweakField -Entry $tweak -Name "Inverted" -Default $false))).IsOn
        $sender.IsChecked = $shown

        # Com o estado não identificado, a ação pergunta o que fazer (a chave não diz se vai ativar ou desativar). Com ele,
        # a ação recebe o estado pedido (o oposto do que a chave mostrava): se o Windows mudou depois que a página foi
        # aberta e já está assim, nada muda.
        $known = ([string]$tweak.Status -in @("Aplicado", "Padrão"))
        $want = $(if (-not $known) { "" } elseif ($shown) { "Off" } else { "On" })

        try {
            # A chave muda na própria linha (UX19 da R38): a tela de execução só abre se a ação perguntar algo ou terminar com
            # algo a ler.
            Start-GuiAction -Label $tweak.Name -Command (Get-GuiTweakCommand -Id $tweak.Id -Ask:(-not $known) -Want $want) -RequiresAdmin ([bool]$tweak.RequiresAdmin) -FocusTweak ([string]$tweak.Id) -InPlace
        }
        catch {
            [void](Show-GuiMessage -Icon Error -Title (Get-WinForgeText "`"{0}`" não começou" "$($tweak.Name)") -Text $_.Exception.Message)
        }
    })

    [System.Windows.Controls.Grid]::SetColumn($toggle, 2)
    [void]$grid.Children.Add($toggle)

    Set-GuiPanelContent -Panel $border -Content $grid

    # As partes que mudam depois que a chave muda na própria linha (Update-GuiTweakRow); a página refeita no meio de uma
    # mudança mostra a linha ainda mudando.
    $script:TweakRows[[string]$Tweak.Id] = @{ Kind = "tweak"; Row = $border; Caption = $caption; Toggle = $toggle; Tweak = $Tweak }
    if ($null -ne $script:InPlaceRun -and [string]$script:InPlaceRun.Id -eq [string]$Tweak.Id -and $script:Running) { [void](Set-GuiTweakRowBusy -Id ([string]$Tweak.Id)) }

    return $border
}

function Set-GuiTweakRowBusy {
    # A linha enquanto a ação dela roda na própria página: "Alterando…" no lugar do estado, e a chave desligada para outro
    # clique (a ação já está a caminho). Devolve se o foco do teclado estava nela, para ele voltar depois.
    param ([Parameter(Mandatory)][string]$Id)

    $parts = $script:TweakRows[$Id]
    if ($null -eq $parts) { return $false }

    $focused = $false
    try { $focused = [bool]$parts.Toggle.IsKeyboardFocusWithin } catch { $focused = $false }

    $parts.Caption.Text = (Get-WinForgeText 'Alterando…')
    $parts.Caption.Foreground = New-GuiBrush $script:Theme.Muted
    $parts.Toggle.IsEnabled = $false

    return $focused
}

function Update-GuiTweakRow {
    <#
    A linha de um ajuste depois que a chave mudou na própria página: o estado lido de novo do Windows, só desse ajuste, e o
    resumo do alto refeito com ele. O leitor de tela ouve como o recurso ficou. Sem a linha na tela (outra página aberta),
    nada a fazer: a página lê tudo quando abre. Refocus: o foco do teclado volta para a chave.
    #>
    param (
        [Parameter(Mandatory)][string]$Id,
        [bool]$Refocus = $false
    )

    $parts = $script:TweakRows[$Id]
    if ($null -eq $parts) { return }

    $tweak = $parts.Tweak
    $catalogTweak = Get-WinForgeTweakById -Id $Id
    if ($null -ne $catalogTweak) { $tweak.Status = [string](Get-WinForgeTweakStatus -Tweak $catalogTweak) }

    $state = Get-WinForgeTweakSwitchState -Status ([string]$tweak.Status) -Inverted ([bool](Get-WinForgeTweakField -Entry $tweak -Name "Inverted" -Default $false))
    $colors = @{ Normal = $script:Theme.Text; Warn = $script:Theme.Warn; Muted = $script:Theme.Muted }

    $parts.Caption.Text = $state.Caption
    $parts.Caption.Foreground = New-GuiBrush $colors[[string]$state.Level]
    $parts.Toggle.IsChecked = $state.IsOn
    $parts.Toggle.IsEnabled = (-not [bool](Get-WinForgeTweakField -Entry $tweak -Name "OtherAccount" -Default $false))

    Send-GuiTweakRowNews -Id $Id -Refocus $Refocus
    Set-GuiTweaksStatus
}

function Send-GuiTweakRowNews {
    <#
    Depois que uma linha mudou na própria página: o foco do teclado volta para ela (Refocus: a chave) e o leitor de tela
    ouve como o recurso ficou. Serve também para a linha nova, quando a página foi refeita pelo tema (TweakRefocus).
    #>
    param (
        [Parameter(Mandatory)][string]$Id,
        [bool]$Refocus = $false
    )

    $parts = $script:TweakRows[$Id]
    if ($null -eq $parts) { return }

    if ($Refocus -and $null -ne $parts.Toggle) { [void]$parts.Toggle.Focus() }

    # "Modo escuro: Ativado".
    $spoken = "$($parts.Tweak.Name): $($parts.Caption.Text)"

    try {
        Set-GuiAutomationName -Element $parts.Caption -Name $spoken
        [System.Windows.Automation.AutomationProperties]::SetLiveSetting($parts.Caption, [System.Windows.Automation.AutomationLiveSetting]::Polite)
    }
    catch {
        Write-Verbose "Leitor de tela: $($_.Exception.Message)"
    }

    Send-GuiAnnouncement -Element $parts.Caption
}

function Set-GuiTweaksStatus {
    # O resumo no alto da página de ajustes aberta (Get-WinForgeTweaksPageStatus), logo abaixo dos botões, feito da lista
    # lida (TweaksOverview). Refeito no lugar depois que uma chave muda; se a leitura falhar, a página segue sem ele.
    $navPage = Get-WinForgeNavPage -Id $script:CurrentPage
    if ($null -eq $navPage -or $navPage.Kind -ne "Tweaks") { return }

    $status = $null

    try {
        $status = New-GuiPageStatus -Page $navPage -Rows @(Get-WinForgeTweaksPageStatus -Page ([string]$navPage.Id) -Overview @($script:TweaksOverview))
    }
    catch {
        Write-Verbose "Resumo dos ajustes: $($_.Exception.Message)"
        $status = $null
    }

    $old = $null
    $index = 0
    $position = 0

    foreach ($child in @($contentPanel.Children)) {
        $position++
        if ([string]$child.Tag -eq "tweaks-status") { $old = $child }
        elseif ([string]$child.Tag -eq "tweaks-bar") { $index = $position }
    }

    if ($null -ne $old) {
        $index = $contentPanel.Children.IndexOf($old)
        $contentPanel.Children.Remove($old)
    }

    if ($null -ne $status) {
        $status.Tag = "tweaks-status"
        $contentPanel.Children.Insert($index, $status)
    }
}

function New-GuiTweaksSkeleton {
    # Enquanto a página lê o Windows: um cartão com linhas-esqueleto do tamanho das linhas de ajuste (como os cartões do
    # Início), no lugar de um texto (a UX16 da R38). O leitor de tela ouve que a página está lendo.
    $holder = New-Object System.Windows.Controls.StackPanel
    $holder.Tag = "loading"
    Set-GuiAutomationName -Element $holder -Name (Get-WinForgeText 'Lendo o estado atual dos ajustes...')

    [void]$holder.Children.Add((New-GuiHomeSkeleton -Width 140 -Height 16 -Margin (New-Object System.Windows.Thickness (0, 18, 0, 10))))

    $rows = New-Object System.Windows.Controls.StackPanel

    foreach ($width in @(240, 200, 280)) {
        $row = New-Object System.Windows.Controls.DockPanel
        $row.Margin = New-Object System.Windows.Thickness (0, 13, 0, 13)

        $switch = New-GuiHomeSkeleton -Width 40 -Height 20
        $switch.VerticalAlignment = "Center"
        Set-GuiDock -Element $switch -Side "Right"
        [void]$row.Children.Add($switch)

        $text = New-Object System.Windows.Controls.StackPanel
        [void]$text.Children.Add((New-GuiHomeSkeleton -Width $width -Height 14))
        [void]$text.Children.Add((New-GuiHomeSkeleton -Width ($width + 140) -Height 10 -Margin (New-Object System.Windows.Thickness (0, 6, 0, 0))))
        [void]$row.Children.Add($text)

        [void]$rows.Children.Add($row)
    }

    $card = New-GuiPanelBorder -Padding (New-Object System.Windows.Thickness (18, 4, 18, 4)) -Content $rows
    $card.Margin = New-Object System.Windows.Thickness (0, 0, 12, 0)
    [void]$holder.Children.Add($card)

    return $holder
}

function New-GuiTweakGroup {
    # O cartão de uma categoria de ajustes, com o título acima. Devolve Category, Heading, Card e Rows (onde entram as
    # linhas).
    param ([Parameter(Mandatory)][string]$Category)

    # O mesmo título das seções das outras páginas (tamanho, cor e o nome "Seção: ..." para o leitor de tela).
    $heading = New-GuiGroupHeading -Text $Category
    $heading.Margin = New-Object System.Windows.Thickness (0, 18, 0, 10)

    $rows = New-Object System.Windows.Controls.StackPanel
    $card = New-GuiPanelBorder -Padding (New-Object System.Windows.Thickness (18, 4, 18, 4)) -Content $rows
    $card.Margin = New-Object System.Windows.Thickness (0, 0, 12, 0)

    return [PSCustomObject]@{ Category = $Category; Heading = $heading; Card = $card; Rows = $rows }
}

function Add-GuiTweakToGroup {
    # Põe a linha no grupo, com uma linha fina separando-a da anterior.
    param (
        [Parameter(Mandatory)]$Group,
        [Parameter(Mandatory)]$Row
    )

    if ($Group.Rows.Children.Count -gt 0) {
        $line = New-Object System.Windows.Controls.Border
        $line.Height = 1
        $line.Background = New-GuiBrush $script:Theme.Line
        [void]$Group.Rows.Children.Add($line)
    }

    [void]$Group.Rows.Children.Add($Row)
}

function New-GuiPageActionButton {
    <#
    Um botão do alto de uma página de ajustes, para um item da navegação: Primary no caminho recomendado. Pede
    Administrador: o escudo antes do nome, como nos botões do Windows; abre uma tela do Windows: o ícone de "abre fora".
    #>
    param (
        [Parameter(Mandatory)]$Item,
        [ValidateSet("Secondary", "Primary")][string]$Kind = "Secondary"
    )

    $needsAdmin = ([bool]$Item.RequiresAdmin -and -not $script:IsAdmin)
    $icon = $(if ($Item.Kind -eq "Shortcut") { "external" } elseif ($needsAdmin) { "admin" } elseif ($Kind -eq "Primary") { "sparkles" } else { "" })

    $button = New-GuiButton -Text $Item.Label -Kind $Kind -Icon $icon -Tag $Item
    $button.Margin = New-Object System.Windows.Thickness (0, 0, 8, 8)

    $about = $(if ([string](Get-WinForgeJsonValue -Object $Item -Name "Detail" -Default "")) { [string]$Item.Detail } else { [string]$Item.Description })
    $button.ToolTip = $(if ($needsAdmin) { (Get-WinForgeText "{0}`nPede Administrador ao executar." "$about") } else { $about })
    if ($needsAdmin) { Set-GuiAutomationName -Element $button -Name "$($Item.Label)$(Get-WinForgeText '. Pede Administrador ao executar')" }

    $button.Add_Click({
        param ($sender, $eventArgs)
        Invoke-GuiNavItem -Item $sender.Tag
    })

    return $button
}

function Show-GuiMoreMenu {
    <#
    O menu "Mais opções" de uma página de ajustes: uma lista que abre embaixo do botão, com as outras ações da página. As
    setas andam entre elas, Enter abre, Esc ou um clique fora fecha, e o foco volta ao botão. O menu entra no mesmo painel
    do botão (sem ocupar espaço): assim usa as cores e os estilos da janela. Enquanto o menu está aberto, o botão não
    recebe o mouse: o clique nele só fecha o menu (o clique fora fecha o Popup e chegaria ao botão, que o abriria de novo).
    #>
    param (
        [Parameter(Mandatory)]$Anchor,
        [Parameter(Mandatory)][object[]]$Items
    )

    $list = New-Object System.Windows.Controls.StackPanel
    [System.Windows.Input.KeyboardNavigation]::SetDirectionalNavigation($list, [System.Windows.Input.KeyboardNavigationMode]::Cycle)
    [System.Windows.Input.KeyboardNavigation]::SetTabNavigation($list, [System.Windows.Input.KeyboardNavigationMode]::Cycle)

    $frame = New-GuiPanelBorder -Padding (New-Object System.Windows.Thickness 4) -Content $list
    $frame.Margin = New-Object System.Windows.Thickness (10, 2, 10, 14)

    try {
        $shadow = New-Object System.Windows.Media.Effects.DropShadowEffect
        $shadow.BlurRadius = 18
        $shadow.ShadowDepth = 4
        $shadow.Direction = 270
        $shadow.Opacity = 0.18
        $shadow.Color = [System.Windows.Media.Colors]::Black
        $frame.Effect = $shadow
    }
    catch {
        Write-Verbose "Sombra do menu: $($_.Exception.Message)"
    }

    $popup = New-Object System.Windows.Controls.Primitives.Popup
    $popup.AllowsTransparency = $true
    $popup.StaysOpen = $false
    $popup.PlacementTarget = $Anchor
    $popup.Placement = [System.Windows.Controls.Primitives.PlacementMode]::Bottom
    $popup.HorizontalOffset = -10
    $popup.Child = $frame
    $popup.Tag = $Anchor

    foreach ($item in $Items) {
        $needsAdmin = ([bool]$item.RequiresAdmin -and -not $script:IsAdmin)
        $outside = ([string]$item.Kind -eq "Shortcut")

        $entry = New-Object System.Windows.Controls.Button
        $entry.Style = $window.FindResource("MenuItemButton")
        $entry.Foreground = New-GuiBrush $script:Theme.Text
        $entry.Tag = @{ Item = $item; Popup = $popup }

        $row = New-Object System.Windows.Controls.DockPanel

        if ($outside -or $needsAdmin) {
            $mark = New-GuiIcon -Name $(if ($outside) { "external" } else { "admin" }) -Size 16 -Color $script:Theme.Muted
            $mark.Margin = New-Object System.Windows.Thickness (16, 0, 0, 0)
            Set-GuiDock -Element $mark -Side "Right"
            [void]$row.Children.Add($mark)
        }

        $label = New-GuiText -Text ([string]$item.Label) -Size $script:Type.Body
        $label.TextWrapping = "NoWrap"
        $label.VerticalAlignment = "Center"
        [void]$row.Children.Add($label)

        $entry.Content = $row

        $about = $(if ([string](Get-WinForgeJsonValue -Object $item -Name "Detail" -Default "")) { [string]$item.Detail } else { [string]$item.Description })
        $note = $(if ($outside) { (Get-GuiOutsideNote -Item $item) } elseif ($needsAdmin) { (Get-WinForgeText 'Pede Administrador ao executar') } else { "" })
        $entry.ToolTip = (@($about, $note) | Where-Object { -not [string]::IsNullOrEmpty($_) }) -join "`n"
        Set-GuiAutomationName -Element $entry -Name "$($item.Label)$(if ($outside) { ". $(Get-GuiOutsideNote -Item $item)" } elseif ($needsAdmin) { (Get-WinForgeText '. Pede Administrador ao executar') })"

        $entry.Add_Click({
            param ($sender, $eventArgs)

            $sender.Tag.Popup.IsOpen = $false
            Invoke-GuiNavItem -Item $sender.Tag.Item
        })

        [void]$list.Children.Add($entry)
    }

    $frame.Add_PreviewKeyDown({
        param ($sender, $eventArgs)

        if ($eventArgs.Key -eq "Escape") {
            $eventArgs.Handled = $true
            $sender.Parent.IsOpen = $false
        }
    })

    $popup.Add_Opened({
        param ($sender, $eventArgs)

        try {
            $first = $sender.Child.Child.Child.Children[0]
            if ($null -ne $first) { [void][System.Windows.Input.Keyboard]::Focus($first) }
        }
        catch {
            Write-Verbose "Foco do menu: $($_.Exception.Message)"
        }
    })

    $popup.Add_Closed({
        param ($sender, $eventArgs)

        try {
            $anchor = $sender.Tag
            if ($null -ne $anchor) { $anchor.IsHitTestVisible = $true }
            $holder = $sender.Parent
            if ($null -ne $holder -and $holder.Children.Contains($sender)) { $holder.Children.Remove($sender) }
            if ($null -ne $anchor -and $anchor.IsVisible) { [void]$anchor.Focus() }
        }
        catch {
            Write-Verbose "Menu fechado: $($_.Exception.Message)"
        }
    })

    # No mesmo painel do botão: o menu fica na árvore da janela (cores e estilos) e não ocupa lugar na página.
    $holder = $Anchor.Parent
    if ($holder -is [System.Windows.Controls.Panel]) { [void]$holder.Children.Add($popup) }

    $popup.IsOpen = $true
    if ($popup.IsOpen) { $Anchor.IsHitTestVisible = $false }
}

function New-GuiTweakActionRow {
    # Uma ação da página dentro do grupo de ajustes da categoria dela (ListCategory): a linha de lista, sem o ícone, com o
    # texto alinhado ao das chaves do grupo.
    param ([Parameter(Mandatory)]$Item)

    $row = New-GuiActionRow -Item $Item -NoIcon
    $row.Margin = New-Object System.Windows.Thickness (-14, 2, -14, 2)
    $row.Padding = New-Object System.Windows.Thickness (14, 10, 12, 10)
    $row.MinHeight = 56

    return $row
}

function Show-GuiTweaksPage {
    param (
        [Parameter(Mandatory)]$Page,
        [string]$FocusTweak = ""
    )

    # Cada visita à página define de novo o ajuste a destacar (vazio fora da busca).
    $script:FocusTweakId = $FocusTweak
    $pageTitle.Text = $Page.Title
    $pageSubtitle.Text = $Page.Summary
    $contentPanel.Children.Clear()

    $bar = New-Object System.Windows.Controls.WrapPanel
    $bar.Margin = New-Object System.Windows.Thickness (0, 0, 0, 10)
    $bar.Tag = "tweaks-bar"

    # As ações da página vêm da tabela de navegação. No alto, só o caminho recomendado (Accent) e "Mais opções" com as
    # outras; as que têm ListCategory viram linhas no grupo da categoria (Update-GuiTweaksList). Sem destaque, a primeira
    # vira o botão; uma ação sozinha no menu também fica como botão.
    $others = @()

    foreach ($item in $Page.Items) {
        if (-not [string]::IsNullOrEmpty([string](Get-WinForgeJsonValue -Object $item -Name "ListCategory" -Default ""))) { continue }

        if ($item.Accent -and $bar.Children.Count -eq 0) {
            [void]$bar.Children.Add((New-GuiPageActionButton -Item $item -Kind Primary))
        }
        else {
            $others += $item
        }
    }

    if ($bar.Children.Count -eq 0 -and $others.Count -gt 0) {
        [void]$bar.Children.Add((New-GuiPageActionButton -Item $others[0]))
        $others = @($others | Select-Object -Skip 1)
    }

    if ($others.Count -eq 1) {
        [void]$bar.Children.Add((New-GuiPageActionButton -Item $others[0]))
    }
    elseif ($others.Count -gt 1) {
        $more = New-GuiButton -Text (Get-WinForgeText 'Mais opções') -Icon "dots" -Tag @($others)
        $more.Margin = New-Object System.Windows.Thickness (0, 0, 8, 8)
        $more.ToolTip = (@($others | ForEach-Object { [string]$_.Label }) -join "`n")
        try { [System.Windows.Automation.AutomationProperties]::SetHelpText($more, (Join-WinForgeList -Items @($others | ForEach-Object { [string]$_.Label }))) } catch { Write-Verbose "Leitor de tela: $($_.Exception.Message)" }
        $more.Add_Click({
            param ($sender, $eventArgs)
            Show-GuiMoreMenu -Anchor $sender -Items @($sender.Tag)
        })
        [void]$bar.Children.Add($more)
    }

    $refresh = New-GuiButton -Text (Get-WinForgeText 'Atualizar estado') -Kind Ghost -Icon "refresh"
    $refresh.Margin = New-Object System.Windows.Thickness (0, 0, 0, 8)
    # Atualizar estado relê os ajustes sem voltar a lista para o topo: a lista é refeita depois (Update-GuiTweaksList), e
    # a rolagem volta ao ponto de antes quando ela fica pronta. A página é a aberta (Ajustes do Windows ou Personalização).
    $refresh.Add_Click({
        $script:TweaksScrollBack = $pageScroll.VerticalOffset
        Show-GuiPage -Id $script:CurrentPage
    })
    [void]$bar.Children.Add($refresh)

    [void]$contentPanel.Children.Add($bar)

    # O que a chave faz fica na dica dela; o resumo do alto (os recomendados em uso e o que o WinForge mudou) entra logo
    # abaixo dos botões depois da leitura (a UX14 da R38).
    [void]$contentPanel.Children.Add((New-GuiTweaksSkeleton))

    Invoke-GuiDeferred -Action { Update-GuiTweaksList }
}

function Set-GuiTweakFocus {
    # Destaca a linha do ajuste que a pessoa achou na busca e a traz para a vista, depois de a lista ser desenhada.
    param ($Row)

    if ($null -eq $Row) { return }

    Set-GuiPanelOutline -Panel $Row -Color $script:Theme.Accent
    $Row.Background = New-GuiBrush $script:Theme.AccentCard
    $script:FocusRow = $Row

    Invoke-GuiDeferred -Action {
        try { if ($null -ne $script:FocusRow) { $script:FocusRow.BringIntoView() } } catch { }
        $script:FocusRow = $null
    }
}

function Update-GuiTweaksList {
    # A lista da página de ajustes aberta (Ajustes do Windows ou Personalização). Saiu dela antes de a lista ficar pronta:
    # a rolagem pedida pelo Atualizar estado não vale mais.
    $navPage = Get-WinForgeNavPage -Id $script:CurrentPage

    if ($null -eq $navPage -or $navPage.Kind -ne "Tweaks") {
        $script:TweaksScrollBack = $null
        return
    }

    # Tira o esqueleto do carregamento e desenha a lista agrupada por categoria.
    foreach ($child in @($contentPanel.Children)) {
        if ([string]$child.Tag -eq "loading") {
            $contentPanel.Children.Remove($child)
        }
    }

    $script:TweakRows = @{}

    try {
        $overview = @(Get-WinForgeTweakOverview -Page $navPage.Id)
        $script:TweaksOverview = $overview
        $group = $null
        $rows = @{}

        # O resumo do alto: os recomendados em uso e quantos ajustes da página o WinForge mudou. As chaves mostram o estado
        # do Windows, e não o que o WinForge fez.
        Set-GuiTweaksStatus

        $groups = @{}

        # Os ajustes de energia e desempenho ficam recolhidos em "Avançados": mudam o comportamento do PC.
        foreach ($tweak in @($overview | Where-Object { -not $_.Advanced })) {
            if ($null -eq $group -or $tweak.Category -ne $group.Category) {
                $group = New-GuiTweakGroup -Category $tweak.Category
                $groups[[string]$tweak.Category] = $group
                [void]$contentPanel.Children.Add($group.Heading)
                [void]$contentPanel.Children.Add($group.Card)
            }

            $rows[[string]$tweak.Id] = New-GuiTweakRow -Tweak $tweak
            Add-GuiTweakToGroup -Group $group -Row $rows[[string]$tweak.Id]
        }

        # As ações e os atalhos da página que pertencem a uma categoria (as teclas do teclado, a cor de destaque) entram no
        # fim do grupo dela, como uma linha com a seta; sem o grupo na tela (nenhum ajuste dele neste Windows), num grupo
        # só delas.
        foreach ($item in @($navPage.Items | Where-Object { -not [string]::IsNullOrEmpty([string](Get-WinForgeJsonValue -Object $_ -Name "ListCategory" -Default "")) })) {
            $category = [string]$item.ListCategory

            if (-not $groups.ContainsKey($category)) {
                $groups[$category] = New-GuiTweakGroup -Category $category
                [void]$contentPanel.Children.Add($groups[$category].Heading)
                [void]$contentPanel.Children.Add($groups[$category].Card)
            }

            # Como as chaves, a linha mostra o estado de agora embaixo do nome ("Agora: Alt + Shift e Ctrl + Shift"), no
            # lugar da frase curta; a frase inteira continua na dica. A cópia não muda o item da tabela de navegação.
            $shown = $item
            $state = ""
            try { $state = [string](Get-WinForgeTweakActionState -Id ([string]$item.Id)) } catch { Write-Verbose "Estado da linha: $($_.Exception.Message)" }

            if (-not [string]::IsNullOrEmpty($state)) {
                $shown = $item.PSObject.Copy()
                $shown.Description = $state
            }

            Add-GuiTweakToGroup -Group $groups[$category] -Row (New-GuiTweakActionRow -Item $shown)
        }

        $advancedTweaks = @($overview | Where-Object { $_.Advanced })

        if ($advancedTweaks.Count -gt 0) {
            $advancedPanel = New-Object System.Windows.Controls.StackPanel
            $advancedPanel.Visibility = $(if ($script:TweaksAdvancedOpen) { "Visible" } else { "Collapsed" })

            $note = New-GuiText -Text (Get-WinForgeText 'Mudam energia e desempenho do PC; em notebook podem gastar bateria. Cada um pode ser desfeito.') -Size $script:Type.Caption -Color $script:Theme.Muted
            $note.Margin = New-Object System.Windows.Thickness (4, 4, 0, 0)
            [void]$advancedPanel.Children.Add($note)

            $group = $null

            foreach ($tweak in $advancedTweaks) {
                if ($null -eq $group -or $tweak.Category -ne $group.Category) {
                    $group = New-GuiTweakGroup -Category $tweak.Category
                    [void]$advancedPanel.Children.Add($group.Heading)
                    [void]$advancedPanel.Children.Add($group.Card)
                }

                $rows[[string]$tweak.Id] = New-GuiTweakRow -Tweak $tweak
                Add-GuiTweakToGroup -Group $group -Row $rows[[string]$tweak.Id]
            }

            $toggle = New-GuiButton -Text $(if ($script:TweaksAdvancedOpen) { (Get-WinForgeText 'Ocultar ajustes avançados') } else { (Get-WinForgeText 'Mostrar ajustes avançados ({0})' "$($advancedTweaks.Count)") }) `
                -Tag @{ Panel = $advancedPanel; Count = $advancedTweaks.Count }
            $toggle.Margin = New-Object System.Windows.Thickness (0, 18, 0, 4)
            $toggle.HorizontalAlignment = "Left"
            $toggle.Add_Click({
                param ($sender, $eventArgs)

                $panel = $sender.Tag.Panel
                $script:TweaksAdvancedOpen = ($panel.Visibility -ne "Visible")
                $panel.Visibility = $(if ($script:TweaksAdvancedOpen) { "Visible" } else { "Collapsed" })
                $sender.Content = $(if ($script:TweaksAdvancedOpen) { (Get-WinForgeText 'Ocultar ajustes avançados') } else { (Get-WinForgeText 'Mostrar ajustes avançados ({0})' "$($sender.Tag.Count)") })
            })

            [void]$contentPanel.Children.Add($toggle)
            [void]$contentPanel.Children.Add($advancedPanel)
        }

        # Vindo da busca: destaca o ajuste achado.
        if (-not [string]::IsNullOrEmpty($script:FocusTweakId) -and $rows.ContainsKey($script:FocusTweakId)) {
            Set-GuiTweakFocus -Row $rows[$script:FocusTweakId]
        }
    }
    catch {
        $failure = New-GuiText -Text (Get-WinForgeText 'Não foi possível ler o estado dos ajustes. Use Atualizar estado, logo acima, para tentar de novo.') -Color $script:Theme.Bad
        $failure.ToolTip = (Get-WinForgeText 'Detalhe técnico: {0}' "$($_.Exception.Message)")
        [void]$contentPanel.Children.Add($failure)
    }
    finally {
        $script:FocusTweakId = ""

        # A linha que mudou quando a página foi refeita pelo tema: o foco e o aviso vão para a linha nova.
        $pending = $script:TweakRefocus
        $script:TweakRefocus = $null

        if ($null -ne $pending -and [string]$pending.Page -eq [string]$script:CurrentPage) {
            try { Send-GuiTweakRowNews -Id ([string]$pending.Id) -Refocus ([bool]$pending.Refocus) } catch { Write-Verbose "Linha do ajuste: $($_.Exception.Message)" }
        }

        if ($null -ne $script:TweaksScrollBack) {
            try {
                $pageScroll.UpdateLayout()
                $pageScroll.ScrollToVerticalOffset([double]$script:TweaksScrollBack)
            }
            catch {
                Write-Verbose "Rolagem dos ajustes: $($_.Exception.Message)"
            }

            $script:TweaksScrollBack = $null
        }
    }
}

function Set-GuiSelectedNav {
    # Destaca na barra lateral a página aberta: fundo cinza e o ícone na cor de destaque (a versão para texto e ícones, que
    # tem contraste suficiente nos dois temas).
    param ([string]$Id)

    $script:SelectedNav = $Id

    foreach ($key in @($script:NavParts.Keys)) {
        $part = $script:NavParts[$key]

        # Além do fundo e da barrinha, o nome em negrito e, para o leitor de tela, "página aberta".
        $selected = ($key -eq $Id)

        if ($selected) {
            $part.Button.Style = $window.FindResource("NavButtonSelected")
            Set-GuiIconColor -Icon $part.Icon -Color $script:Theme.AccentText
        }
        else {
            $part.Button.Style = $window.FindResource("NavButton")
            Set-GuiIconColor -Icon $part.Icon -Color $script:Theme.Muted
        }

        $part.Label.Foreground = New-GuiBrush $script:Theme.Text
        $part.Label.FontWeight = $(if ($selected) { "SemiBold" } else { "Normal" })

        try {
            [System.Windows.Automation.AutomationProperties]::SetItemStatus($part.Button, $(if ($selected) { (Get-WinForgeText 'página aberta') } else { "" }))
        }
        catch {
            Write-Verbose "Leitor de tela: $($_.Exception.Message)"
        }
    }
}

function Clear-GuiSearch {
    # Esquece a busca e esvazia a caixa. A busca é dada como encerrada antes de a caixa mudar: o aviso de texto mudado que
    # isso dispara já não tem busca para fechar.
    $script:SearchActive = $false
    $script:SearchFirst = $null
    $script:SearchFirstCard = $null
    $script:SearchPanel = $null
    $script:SearchShownKey = ""
    $script:SearchEnterOpens = $false
    $script:SearchEnterPending = $false
    $script:SearchTimer.Stop()
    $searchBox.Text = ""
    $searchHint.Visibility = "Visible"
    $searchKeys.Visibility = "Visible"
    $searchClear.Visibility = "Collapsed"
}

function Hide-GuiRunView {
    # A página (ou a busca) toma o lugar da tela de execução. A ação que ainda roda, ou que terminou sem a pessoa ver o
    # resultado, continua na faixa do alto da página; a que ela já viu terminar sai da faixa.
    if ($runView.Visibility -eq "Visible" -and -not $script:Running) { $script:RunUnseen = $false }

    $runView.Visibility = "Collapsed"
    $pagesView.Visibility = "Visible"
    Update-GuiRunStrip
}

function Test-GuiAnimations {
    # Os "Efeitos de animação" do Windows (Acessibilidade > Efeitos visuais): desligados, nada na janela se move.
    try { return [bool][System.Windows.SystemParameters]::ClientAreaAnimation } catch { return $false }
}

function Start-GuiEntrance {
    # A entrada de uma página ou da faixa de resultado, como no Windows 11: aparece e sobe 8 pixels em 170 ms, rápido no
    # começo e devagar no fim. Sem as animações do Windows, ou se algo falhar, o elemento só aparece, parado.
    param (
        [Parameter(Mandatory)]$Element,
        [double]$Offset = 8,
        [int]$Milliseconds = 170
    )

    if (-not (Test-GuiAnimations)) { return }

    try {
        $duration = New-Object System.Windows.Duration ([TimeSpan]::FromMilliseconds($Milliseconds))
        $ease = New-Object System.Windows.Media.Animation.CubicEase
        $ease.EasingMode = [System.Windows.Media.Animation.EasingMode]::EaseOut

        $fade = New-Object System.Windows.Media.Animation.DoubleAnimation (0.0, 1.0, $duration)
        $fade.EasingFunction = $ease

        $move = New-Object System.Windows.Media.TranslateTransform (0.0, $Offset)
        $slide = New-Object System.Windows.Media.Animation.DoubleAnimation ($Offset, 0.0, $duration)
        $slide.EasingFunction = $ease

        $Element.RenderTransform = $move
        $Element.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $fade)
        $move.BeginAnimation([System.Windows.Media.TranslateTransform]::YProperty, $slide)
    }
    catch {
        # Sem a animação, o conteúdo fica no lugar e visível.
        try {
            $Element.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $null)
            $Element.Opacity = 1.0
            $Element.RenderTransform = [System.Windows.Media.Transform]::Identity
        }
        catch {
            Write-Verbose "Animação desfeita: $($_.Exception.Message)"
        }

        Write-Verbose "Animação: $($_.Exception.Message)"
    }
}

function Show-GuiPage {
    param (
        [Parameter(Mandatory)][string]$Id,

        # Só para a página de ajustes: o ajuste a destacar (vindo da busca).
        [string]$FocusTweak = "",

        # A mesma página, refeita no lugar (troca de tema): a rolagem fica onde estava e o Início não lê o PC de novo.
        [switch]$Rerender
    )

    $offset = $pageScroll.VerticalOffset

    # Outra página: o foco pendente de uma linha refeita não vale mais.
    if (-not $Rerender) { $script:TweakRefocus = $null }

    Clear-GuiSearch
    $script:CurrentPage = $Id
    Set-GuiSelectedNav -Id $Id
    Hide-GuiRunView

    if (-not $Rerender) { $pageScroll.ScrollToTop() }

    $page = $null
    if ($Id -ne "home") { $page = Get-WinForgeNavPage -Id $Id }

    if ($null -eq $page) {
        if ($Id -ne "home") {
            $script:CurrentPage = "home"
            Set-GuiSelectedNav -Id "home"
        }

        Show-GuiHomePage -Rerender:$Rerender
    }
    elseif ($page.Kind -eq "Tweaks") {
        # Refeita no lugar (o tema mudou), a lista é lida de novo e chega depois: a rolagem volta quando ela fica pronta, como
        # no Atualizar estado; com o esqueleto, mais curto, voltaria ao alto.
        if ($Rerender) { $script:TweaksScrollBack = $offset }
        Show-GuiTweaksPage -Page $page -FocusTweak $FocusTweak
    }
    else {
        Show-GuiListPage -Page $page
    }

    if ($Rerender) {
        # O conteúdo novo precisa ser medido antes de a rolagem voltar ao ponto em que estava.
        $pageScroll.UpdateLayout()
        $pageScroll.ScrollToVerticalOffset($offset)
    }
    else {
        # Uma página nova entra; a mesma refeita no lugar (tema, idioma do texto) não se mexe.
        Start-GuiEntrance -Element $contentPanel
    }
}

# --- Busca ---------------------------------------------------------------------------------------------------
function Get-GuiHiddenItemState {
    # O que o Início leu e decide os itens que saem das páginas e da busca (Test-WinForgeNavItemHidden): quem protege o PC
    # e se ele tem bateria. Antes da leitura, "" e $null: nada sai.
    return @{
        AntivirusMode = [string](Get-Variable -Name AntivirusMode -Scope Script -ValueOnly -ErrorAction SilentlyContinue)
        HasBattery    = (Get-Variable -Name HasBattery -Scope Script -ValueOnly -ErrorAction SilentlyContinue)
    }
}

function Show-GuiSearchResults {
    param (
        [string]$Query,

        # A mesma busca, refeita no lugar (troca de tema): os cartões são refeitos nas cores novas e a rolagem fica onde estava.
        [switch]$Rerender
    )

    $offset = $(if ($Rerender) { $pageScroll.VerticalOffset } else { 0 })

    if (-not $script:SearchActive) {
        # Guarda a página de onde a busca começou, para o Esc voltar a ela.
        $script:SearchBack = $script:CurrentPage
        $script:SearchActive = $true
    }

    # Nenhuma página fica marcada na barra lateral (o Ver da faixa de execução pode ter marcado uma no meio da busca).
    if ($script:SelectedNav) { Set-GuiSelectedNav -Id "" }

    $script:CurrentPage = "search"
    Hide-GuiRunView

    # O que a página tira neste PC (as ações do Defender com outro antivírus, a bateria num PC sem ela) também não aparece
    # aqui, e o resumo conta só o que aparece.
    $hidden = Get-GuiHiddenItemState
    $hits = @(Search-WinForgeNavigation -Query $Query | Where-Object { -not ($_.Kind -eq "Item" -and (Test-WinForgeNavItemHidden -Id ([string]$_.Item.Id) @hidden)) })
    $shown = @($hits | Select-Object -First $script:SearchMaxCards)
    $partial = ($hits.Count -gt 0 -and [bool]$hits[0].Partial)
    $corrected = $(if ($hits.Count -gt 0) { [string]$hits[0].Corrected } else { "" })
    $script:SearchFirst = $(if ($hits.Count -gt 0) { $hits[0] } else { $null })
    $script:SearchEnterOpens = Test-WinForgeSearchEnterOpens -Hit $script:SearchFirst

    $pageTitle.Text = (Get-WinForgeText 'Busca')
    $pageSubtitle.Text = Get-WinForgeSearchSummary -Query $Query -Total $hits.Count -Shown $shown.Count -Partial:$partial -Corrected $corrected `
        -EnterSelects:(-not $script:SearchEnterOpens)
    Send-GuiAnnouncement -Element $pageSubtitle

    # Mais uma letra que não muda a lista: os cartões na tela ficam como estão (só o resumo muda), sem refazer nada.
    $key = (@($shown | ForEach-Object { "$($_.Kind)|$($_.PageId)|$($_.Section)|$($_.Label)" }) -join "`n") + "`n$($script:ThemeName)|$($script:SearchEnterOpens)"

    if (-not $Rerender -and $shown.Count -gt 0 -and $key -eq $script:SearchShownKey -and $null -ne $script:SearchPanel -and
        $contentPanel.Children.Contains($script:SearchPanel)) {
        return
    }

    $script:SearchPanel = $null
    $script:SearchShownKey = ""
    $script:SearchFirstCard = $null
    $contentPanel.Children.Clear()

    if (-not $Rerender) { $pageScroll.ScrollToTop() }

    if ($hits.Count -eq 0) {
        # Uma letra só: o resumo já pede a segunda. Sem resultado: buscas que funcionam, como botões.
        if (-not (Test-WinForgeSearchTooShort -Query $Query)) { Add-GuiSearchSuggestions }
        return
    }

    # Os resultados numa lista só, como as páginas: de onde vem cada um em cima do nome.
    $results = New-GuiRowGroup

    foreach ($hit in $shown) {
        $first = ($null -eq $script:SearchFirstCard)
        $card = New-GuiActionRow -Item (Get-WinForgeSearchCardItem -Hit $hit) -Context (Get-WinForgeSearchContext -Hit $hit) -EnterHint:($first -and $script:SearchEnterOpens)

        if ($first) {
            # O primeiro é o que o Enter abre (ou seleciona): ganha o fundo de destaque e, quando abre, a tecla "Enter".
            $script:SearchFirstCard = $card
            $card.Background = New-GuiBrush $script:Theme.AccentCard
        }

        Add-GuiRowToGroup -Group $results -Row $card
    }

    # A seta para cima na primeira linha volta para a caixa de busca (SearchCardsKeyDown olha as linhas da lista).
    $results.Rows.Add_PreviewKeyDown($script:SearchCardsKeyDown)
    [void]$contentPanel.Children.Add($results.Element)
    $script:SearchPanel = $results.Element
    $script:SearchShownKey = $key

    if ($Rerender) {
        $pageScroll.UpdateLayout()
        $pageScroll.ScrollToVerticalOffset($offset)
    }
}

function Add-GuiSearchSuggestions {
    # Nada encontrado: buscas que funcionam, do jeito que a pessoa diria, como botões que buscam na hora.
    [void]$contentPanel.Children.Add((New-GuiText -Text (Get-WinForgeText 'Busque pelo que está acontecendo com o PC ou pelo nome do que procura. Por exemplo:') -Color $script:Theme.Muted))

    $row = New-Object System.Windows.Controls.WrapPanel
    $row.Margin = New-Object System.Windows.Thickness (0, 12, 0, 0)

    foreach ($tip in @(Get-WinForgeSearchSuggestions)) {
        $button = New-GuiButton -Text $tip -Tag $tip
        $button.Margin = New-Object System.Windows.Thickness (0, 0, 8, 8)
        $button.Add_Click({
            param ($sender, $eventArgs)

            $searchBox.Text = [string]$sender.Tag
            $searchBox.CaretIndex = $searchBox.Text.Length
            [void]$searchBox.Focus()
            Update-GuiSearch
        })
        [void]$row.Children.Add($button)
    }

    [void]$contentPanel.Children.Add($row)
}

function Update-GuiSearch {
    # Roda agora a busca do texto que está na caixa (o temporizador da digitação, ou o Enter, que não espera). Uma letra só
    # ainda não troca a página pela busca; com a busca já na tela, o resumo pede a segunda letra.
    $script:SearchTimer.Stop()

    $query = $searchBox.Text

    if ([string]::IsNullOrWhiteSpace($query)) { return }
    if (-not $script:SearchActive -and (Test-WinForgeSearchTooShort -Query $query)) { return }

    Show-GuiSearchResults -Query $query
}

function Exit-GuiSearch {
    # Esc ou a caixa esvaziada: a busca acaba e volta a página de onde ela começou. Com a tela de execução na frente (uma
    # ação aberta pela busca), ela continua lá e só a busca é esquecida. Sem busca na tela, só a caixa se esvazia.
    if (-not $script:SearchActive) {
        Clear-GuiSearch
        return
    }

    $back = $script:SearchBack

    if ($runView.Visibility -eq "Visible") {
        Clear-GuiSearch
        $script:CurrentPage = $back
        return
    }

    Show-GuiPage -Id $back
}

function Show-GuiRunBack {
    # Sai da tela de execução. Uma ação aberta a partir da busca volta para os resultados dela; as demais, para a página.
    $copyButton.Content = (Get-WinForgeText 'Copiar')

    if ($script:SearchActive -and -not [string]::IsNullOrWhiteSpace($searchBox.Text)) {
        Show-GuiSearchResults -Query $searchBox.Text
        return
    }

    # Depois de ligar ou desligar um ajuste, a lista volta já nele (com o novo estado), em vez de voltar ao topo.
    $page = Get-GuiBasePage
    $focus = ""

    $navPage = Get-WinForgeNavPage -Id $page

    if ($null -ne $navPage -and $navPage.Kind -eq "Tweaks" -and $script:LastAction -is [hashtable]) {
        $focus = [string]$script:LastAction.FocusTweak
    }

    Show-GuiPage -Id $page -FocusTweak $focus
}

# --- Barra lateral: Início + páginas da tabela de navegação (as de rodapé ficam embaixo) -----------------------
function Add-GuiNavButton {
    # Shortcut: a tecla que abre a página ("Ctrl+3"), mostrada ao passar o mouse e dita pelo leitor de tela. Note: uma
    # linha menor embaixo do nome (a versão, no Sobre o WinForge), que o leitor de tela também ouve.
    param ([string]$Id, [string]$Title, [bool]$Footer = $false, [string]$Shortcut = "", [string]$Note = "")

    $button = New-Object System.Windows.Controls.Button
    $button.Style = $window.FindResource("NavButton")
    $button.Tag = $Id
    Set-GuiAutomationName -Element $button -Name $Title

    if ($Shortcut) {
        $button.ToolTip = "$Title ($Shortcut)"
        [System.Windows.Automation.AutomationProperties]::SetAcceleratorKey($button, $Shortcut)
    }

    $row = New-Object System.Windows.Controls.StackPanel
    $row.Orientation = "Horizontal"

    $icon = New-GuiIcon -Name (Get-WinForgeIconName -Id $Id) -Size 18 -Color $script:Theme.Muted
    $icon.Margin = New-Object System.Windows.Thickness (0, 0, 12, 0)
    [void]$row.Children.Add($icon)

    $label = New-GuiText -Text $Title -Size $script:Type.Body
    $label.TextWrapping = "NoWrap"
    $label.VerticalAlignment = "Center"
    # A barra lateral é montada uma vez: o tamanho acompanha o do texto do Windows pelo recurso, sem refazer o botão.
    $label.SetResourceReference([System.Windows.Controls.TextBlock]::FontSizeProperty, "BodySize")

    if ($Note) {
        # O nome e, embaixo, a linha menor, na cor discreta (pelo recurso, como o tamanho: acompanha o tema).
        $texts = New-Object System.Windows.Controls.StackPanel
        $texts.VerticalAlignment = "Center"
        $texts.Margin = New-Object System.Windows.Thickness (0, 4, 0, 4)
        [void]$texts.Children.Add($label)

        $small = New-Object System.Windows.Controls.TextBlock
        $small.Text = $Note
        $small.TextWrapping = "NoWrap"
        $small.SetResourceReference([System.Windows.Controls.TextBlock]::FontSizeProperty, "CaptionSize")
        $small.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, "DimBrush")
        [void]$texts.Children.Add($small)
        [void]$row.Children.Add($texts)
        Set-GuiAutomationName -Element $button -Name "$Title. $Note"
    }
    else {
        [void]$row.Children.Add($label)
    }

    $button.Content = $row
    $script:NavParts[$Id] = @{ Button = $button; Icon = $icon; Label = $label }

    $button.Add_Click({
        param ($sender, $eventArgs)
        Show-GuiPage -Id ([string]$sender.Tag)
    })

    if ($Footer) {
        [void]$footerNav.Children.Add($button)
    }
    else {
        [void]$navPanel.Children.Add($button)
    }
}

function Add-GuiNavHeading {
    # O título de um grupo da barra lateral (Cuidar, Consertar...): discreto, só organiza a lista. As cores e o tamanho vêm
    # dos recursos da janela, e acompanham o tema e o tamanho do texto sem refazer a barra.
    param ([Parameter(Mandatory)][string]$Text)

    $heading = New-Object System.Windows.Controls.TextBlock
    $heading.Text = $Text
    $heading.FontWeight = [System.Windows.FontWeights]::SemiBold
    $heading.SetResourceReference([System.Windows.Controls.TextBlock]::FontSizeProperty, "CaptionSize")
    $heading.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, "MutedBrush")
    $heading.Margin = New-Object System.Windows.Thickness (12, 14, 0, 4)
    Set-GuiAutomationName -Element $heading -Name (Get-WinForgeText 'Seção: {0}' "$Text")
    [void]$navPanel.Children.Add($heading)
}

# A lista principal em grupos (Get-WinForgeNavOrder); Ctrl+1 a Ctrl+9 (e Ctrl+0 para a décima) seguem a ordem da barra:
# Início e as páginas, de cima para baixo.
$mainNavPages = @(Get-WinForgeNavigation | Where-Object { $_.Placement -ne "Footer" })
$mainNavOrder = @(Get-WinForgeNavOrder -Pages @($mainNavPages | ForEach-Object { [string]$_.Id }))
$script:PageShortcuts = @("home") + @($mainNavOrder | ForEach-Object { [string]$_.Id })

Add-GuiNavButton -Id "home" -Title (Get-WinForgeText 'Início') -Shortcut (Get-WinForgePageShortcutKey -Index 0)

foreach ($entry in $mainNavOrder) {
    $navPage = @($mainNavPages | Where-Object { [string]$_.Id -eq [string]$entry.Id }) | Select-Object -First 1

    if ($entry.Heading) { Add-GuiNavHeading -Text ([string]$entry.Heading) }

    Add-GuiNavButton -Id $navPage.Id -Title $navPage.Title `
        -Shortcut (Get-WinForgePageShortcutKey -Index ([array]::IndexOf($script:PageShortcuts, [string]$navPage.Id)))
}

# No rodapé, o Sobre o WinForge com a versão embaixo do nome.
foreach ($navPage in @(Get-WinForgeNavigation | Where-Object { $_.Placement -eq "Footer" })) {
    Add-GuiNavButton -Id $navPage.Id -Title $navPage.Title -Footer $true -Note $(if ([string]$navPage.Id -eq "app") { (Get-WinForgeText 'Versão {0}' "$(Get-WinForgeBuild)") } else { "" })
}

# --- Temporizadores, botões do painel de execução e encerramento -----------------------------------------------
$script:Timer = New-Object System.Windows.Threading.DispatcherTimer
$script:Timer.Interval = [TimeSpan]::FromMilliseconds(100)
$script:Timer.Add_Tick({ Update-GuiRunView })

$script:DeferredTimer = New-Object System.Windows.Threading.DispatcherTimer
$script:DeferredTimer.Interval = [TimeSpan]::FromMilliseconds(40)
$script:DeferredTimer.Add_Tick({
    $script:DeferredTimer.Stop()
    $action = $script:DeferredAction
    $script:DeferredAction = $null

    if ($null -ne $action) {
        try { & $action } catch { Write-Verbose "Ação adiada da janela: $($_.Exception.Message)" }
    }
})

# A conta do tamanho da pergunta, refeita um instante depois de ela aparecer (Request-GuiPromptFit).
$script:PromptFitTimer = New-Object System.Windows.Threading.DispatcherTimer
$script:PromptFitTimer.Interval = [TimeSpan]::FromMilliseconds(60)
$script:PromptFitTimer.Add_Tick({
    $script:PromptFitTimer.Stop()
    if ($promptBar.Visibility -eq "Visible") { Update-GuiPromptFit }
})

# A busca espera a pessoa parar de digitar um instante (a lista de cartões é refeita a cada busca); o Enter não espera.
$script:SearchTimer = New-Object System.Windows.Threading.DispatcherTimer
$script:SearchTimer.Interval = [TimeSpan]::FromMilliseconds(140)
$script:SearchTimer.Add_Tick({ Update-GuiSearch })

$script:StopRequested = {
    $answer = Show-GuiMessage -Buttons YesNo -Icon Warning -Title (Get-WinForgeText "Parar `"{0}`"?" "$($runTitle.Text)") -Text (Get-WinForgeText 'O que já foi feito continua feito, mas a etapa atual fica incompleta. Reparos e instalações em andamento são interrompidos no meio.') `
        -YesText (Get-WinForgeText 'Parar') -NoText (Get-WinForgeText 'Continuar') -Danger

    if ($answer -eq "Yes" -and $script:Running -and $null -ne $script:GuiSession) {
        Set-GuiRunStatus -Text (Get-WinForgeText 'Interrompendo...') -DotColor $script:Theme.Warn
        Stop-WinForgeGuiCommand -Session $script:GuiSession
    }
}

$stopButton.Add_Click({ & $script:StopRequested })
$runStripStop.Add_Click({ & $script:StopRequested })

$runStripView.Add_Click({ Show-GuiRunView })

$runStripDismiss.Add_Click({
    $script:RunUnseen = $false
    Update-GuiRunStrip
})

function Get-GuiOutputText {
    $range = New-Object System.Windows.Documents.TextRange ($outputBox.Document.ContentStart, $outputBox.Document.ContentEnd)
    return $range.Text
}

$copyButton.Add_Click({
    try {
        [System.Windows.Clipboard]::SetText((Get-GuiOutputText))
        $copyButton.Content = (Get-WinForgeText 'Copiado')
    }
    catch {
        [void](Show-GuiMessage -Icon Warning -Title (Get-WinForgeText 'Não foi possível copiar') -Text "$($_.Exception.Message)")
    }
})

$saveButton.Add_Click({
    try {
        $dialog = New-Object Microsoft.Win32.SaveFileDialog
        $dialog.Title = (Get-WinForgeText 'Salvar a saída')
        $dialog.Filter = (Get-WinForgeText 'Texto (*.txt)|*.txt|Todos os arquivos (*.*)|*.*')
        $dialog.FileName = Get-WinForgeOutputFileName -Title $runTitle.Text
        $dialog.InitialDirectory = [Environment]::GetFolderPath("MyDocuments")

        if ($dialog.ShowDialog($window)) {
            # UTF-8 com BOM: o Bloco de Notas do Windows 10 antigo só reconhece os acentos assim.
            [System.IO.File]::WriteAllText($dialog.FileName, (Get-GuiOutputText), (New-Object System.Text.UTF8Encoding($true)))
            $saveButton.Content = (Get-WinForgeText 'Salvo')
        }
    }
    catch {
        [void](Show-GuiMessage -Icon Warning -Title (Get-WinForgeText 'Não foi possível salvar') -Text "$($_.Exception.Message)")
    }
})

$logButton.Add_Click({
    # O log de cada sessão fica em %LOCALAPPDATA%\WinForge\logs; abre o mais recente (ou a pasta, se não houver).
    $opened = $false

    try {
        $latest = Get-WinForgeLatestLogFile

        if ($null -ne $latest) {
            # Pelo Explorador: o log abre no Bloco de Notas da sessão da pessoa, sem o Administrador da janela.
            Start-Process -FilePath "explorer.exe" -ArgumentList "`"$latest`"" -ErrorAction Stop
            $opened = $true
        }
    }
    catch {
        $opened = $false
    }

    if (-not $opened) { Open-GuiShortcut -Name "LogFolder" -Title (Get-WinForgeText 'Pasta de logs e relatórios') }
})

$rerunButton.Add_Click({
    $last = $script:LastAction

    if ($null -ne $last) {
        Start-GuiAction -Label $last.Label -Command $last.Command -RequiresAdmin ([bool]$last.RequiresAdmin) -FocusTweak ([string]$last.FocusTweak)
    }
})

$backButton.Add_Click({ Show-GuiRunBack })

$resultAction.Add_Click({ Invoke-GuiResultAction })

$detailsToggle.Add_Click({ Set-GuiDetailsOpen -Open (-not $script:DetailsOpen) })

# A página ocupa colunas inteiras de cartões, até quatro: numa janela maximizada, o texto não corre de uma ponta à outra
# da tela e a chave de um ajuste não fica a um palmo do nome dele. Os cartões crescem até preencher a linha (de 252 a 300
# de largura), em vez de deixar uma faixa vazia à direita do tamanho de quase um cartão.
function Get-GuiCardGrid {
    # Colunas, largura do cartão e largura da página para a área disponível (sem as margens).
    param ([Parameter(Mandatory)][double]$Available)

    $step = $script:CardMinWidth + $script:CardGap
    $columns = [Math]::Max(1.0, [Math]::Min(4.0, [Math]::Floor(($Available + $script:CardGap) / $step)))
    $width = [Math]::Floor(($Available + $script:CardGap) / $columns) - $script:CardGap
    $width = [Math]::Max($script:CardMinWidth, [Math]::Min($script:CardMaxWidth, $width))
    $content = $columns * ($width + $script:CardGap)

    return [PSCustomObject]@{ Columns = [int]$columns; Width = [double]$width; Content = [double]$content }
}

function Update-GuiContentWidth {
    try {
        $available = $pageScroll.ViewportWidth - 4
        if ($available -le 0) { return }

        $grid = Get-GuiCardGrid -Available $available

        if ($grid.Width -ne $script:CardWidth) {
            $script:CardWidth = $grid.Width
            Set-GuiResource -Dictionary $window.Resources -Key "CardWidth" -Value ([double]$grid.Width)
        }

        $contentPanel.Width = $grid.Content

        # A faixa da ação em andamento termina onde terminam os cartões, e não na borda da janela.
        $runStrip.HorizontalAlignment = "Left"
        $runStrip.Width = [Math]::Max(0.0, $grid.Content - $script:CardGap)
    }
    catch {
        Write-Verbose "Largura da página: $($_.Exception.Message)"
    }
}

$pageScroll.Add_SizeChanged({ Update-GuiContentWidth })

# A tela de execução tem a largura da área (menos as margens) até a das quatro colunas de cartões. Largura fixa, e não
# alinhada pelo conteúdo: assim ela não começa estreita e cresce conforme chegam linhas compridas.
function Update-GuiRunViewWidth {
    try {
        $available = $runView.Parent.ActualWidth - $runView.Margin.Left - $runView.Margin.Right
        $widest = 4 * ($script:CardMaxWidth + $script:CardGap) - $script:CardGap
        if ($available -gt 0) { $runView.Width = [Math]::Min($widest, [double]$available) }
    }
    catch {
        Write-Verbose "Largura da tela de execução: $($_.Exception.Message)"
    }
}

$runView.Parent.Add_SizeChanged({ Update-GuiRunViewWidth })
$pageScroll.Add_ScrollChanged({
    param ($sender, $eventArgs)
    if ($eventArgs.ViewportWidthChange -ne 0) { Update-GuiContentWidth }
})

# O resumo que é o conteúdo da tela acompanha a altura da janela; a pergunta continua inteira à vista.
$runView.Add_SizeChanged({
    if ($promptBar.Visibility -eq "Visible") { Update-GuiPromptFit } else { Update-GuiSummaryHeight }
})

$promptSend.Add_Click({ Submit-GuiPrompt -Answer $promptInput.Text })
$promptFilter.Add_TextChanged({ Update-GuiPromptFilter })

# Do filtro, a seta para baixo vai ao primeiro item à vista da lista (como da busca para os cartões).
$promptFilter.Add_PreviewKeyDown({
    param ($sender, $eventArgs)

    if ($eventArgs.Key -ne "Down") { return }

    $first = @($promptList.Children | Where-Object { $_.Visibility -eq "Visible" }) | Select-Object -First 1

    if ($null -ne $first) {
        $eventArgs.Handled = $true
        [void]$first.Focus()
    }
})

# As dicas por cima das caixas de texto ("Buscar", "Filtrar a lista") começam exatamente onde o cursor pisca, em qualquer
# escala de tela: a posição vem do próprio campo, depois de desenhado.
$searchBox.Add_SizeChanged({ Update-GuiHintPosition -TextBox $searchBox -Hint $searchHint })
$promptFilter.Add_SizeChanged({ Update-GuiHintPosition -TextBox $promptFilter -Hint $promptFilterHint })

$promptInput.Add_KeyDown({
    param ($sender, $eventArgs)

    if ($eventArgs.Key -eq "Return") {
        $eventArgs.Handled = $true
        Submit-GuiPrompt -Answer $sender.Text
    }
})

# --- Busca e atalhos de teclado ----------------------------------------------------------------------------------
$searchBox.Add_TextChanged({
    $query = $searchBox.Text
    $searchHint.Visibility = $(if ([string]::IsNullOrEmpty($query)) { "Visible" } else { "Collapsed" })
    $searchKeys.Visibility = $searchHint.Visibility

    # Com texto, o botão de limpar toma o lugar da dica Ctrl K.
    $searchClear.Visibility = $(if ([string]::IsNullOrEmpty($query)) { "Collapsed" } else { "Visible" })
    $script:SearchTimer.Stop()

    if ([string]::IsNullOrWhiteSpace($query)) {
        # A caixa esvaziada (ou só com espaços) com a busca na tela volta à página de onde ela começou, na hora.
        if ($script:SearchActive) { Exit-GuiSearch }
        return
    }

    $script:SearchTimer.Start()
})

# O botão de limpar faz o que o Esc faz (volta à página de onde a busca começou, ou só esvazia a caixa) e devolve o foco à
# caixa, para buscar outra coisa.
$searchClear.Add_Click({
    Exit-GuiSearch
    [void]$searchBox.Focus()
})

# Enter e seta para baixo são tratados antes da própria caixa (PreviewKeyDown), que usaria a seta para mover o cursor.
$searchBox.Add_PreviewKeyDown({
    param ($sender, $eventArgs)

    if ($eventArgs.Key -eq "Return" -and -not [string]::IsNullOrWhiteSpace($searchBox.Text)) {
        $eventArgs.Handled = $true

        # Segurar o Enter repete a tecla: só a primeira vale.
        if ($eventArgs.IsRepeat) { return }

        # Com a tela de execução na frente (uma ação aberta pela busca), o Enter traz os resultados de volta; o seguinte abre.
        if ($runView.Visibility -eq "Visible") {
            Update-GuiSearch
            return
        }

        # O Enter vale para o primeiro resultado (o melhor), mesmo que a busca ainda esperasse o fim da digitação. Ele age
        # quando a tecla é solta: segurada, ela não repete a ação nem responde a um aviso que apareça depois.
        if ($script:SearchTimer.IsEnabled) { Update-GuiSearch }

        $script:SearchEnterPending = ($null -ne $script:SearchFirst)
        return
    }

    if ($eventArgs.Key -eq "Down" -and $runView.Visibility -ne "Visible") {
        # Seta para baixo leva o foco ao primeiro cartão; dali as setas andam pelos resultados.
        if ($script:SearchTimer.IsEnabled) { Update-GuiSearch }

        if ($null -ne $script:SearchFirstCard) {
            $eventArgs.Handled = $true
            [void]$script:SearchFirstCard.Focus()
        }
    }
})

$searchBox.Add_PreviewKeyUp({
    param ($sender, $eventArgs)

    if ($eventArgs.Key -ne "Return" -or -not $script:SearchEnterPending) { return }

    $script:SearchEnterPending = $false
    $eventArgs.Handled = $true

    if ($null -eq $script:SearchFirst) { return }

    # Numa busca corrigida ou parcial com uma ação em primeiro, o Enter só seleciona o cartão: nada roda por um palpite.
    if (-not $script:SearchEnterOpens) {
        if ($null -ne $script:SearchFirstCard) { [void]$script:SearchFirstCard.Focus() }
        return
    }

    Invoke-GuiNavItem -Item (Get-WinForgeSearchCardItem -Hit $script:SearchFirst)
})

# Seta para cima num cartão da primeira linha dos resultados volta para a caixa de busca, com o cursor no fim do texto.
$script:SearchCardsKeyDown = {
    param ($sender, $eventArgs)

    if ($eventArgs.Key -ne "Up") { return }

    try {
        $focused = [System.Windows.Input.Keyboard]::FocusedElement

        if ($null -eq $focused -or -not $sender.Children.Contains($focused)) { return }

        if ($focused.TranslatePoint((New-Object System.Windows.Point (0, 0)), $sender).Y -lt 1) {
            $eventArgs.Handled = $true
            [void]$searchBox.Focus()
            $searchBox.CaretIndex = $searchBox.Text.Length
        }
    }
    catch {
        Write-Verbose "Seta para cima nos resultados: $($_.Exception.Message)"
    }
}

$window.Add_PreviewKeyDown({
    param ($sender, $eventArgs)

    # Com Alt apertado (inclusive o AltGr), o WPF entrega Key = System: não casa com nenhum atalho, que exigem Ctrl sozinho.
    # Os valores de System.Windows.Input.ModifierKeys: Alt = 1, Control = 2, Shift = 4.
    $modifiers = Get-GuiModifierFlags
    $decision = Resolve-WinForgeKeyAction -Key ([string]$eventArgs.Key) `
        -Control (($modifiers -band 2) -ne 0) -Alt (($modifiers -band 1) -ne 0) -Shift (($modifiers -band 4) -ne 0) `
        -PageCount $script:PageShortcuts.Count -SearchActive $script:SearchActive `
        -SearchHasText ($searchBox.Text.Length -gt 0) -PagesVisible ($pagesView.Visibility -eq "Visible") `
        -RunViewVisible ($runView.Visibility -eq "Visible") -Running $script:Running -PromptShown ($null -ne $script:ShownPrompt) `
        -PromptFilterVisible ($promptFilterRow.Visibility -eq "Visible")

    switch ($decision.Action) {
        "FocusSearch" {
            $eventArgs.Handled = $true
            [void]$searchBox.Focus()
            $searchBox.SelectAll()
        }
        "FocusPromptFilter" {
            $eventArgs.Handled = $true
            [void]$promptFilter.Focus()
            $promptFilter.SelectAll()
        }
        "OpenPage" {
            $eventArgs.Handled = $true
            Show-GuiPage -Id $script:PageShortcuts[$decision.PageIndex]
        }
        "Refresh" {
            $eventArgs.Handled = $true

            # No Início, a leitura do sistema refaz só os cartões (e ignora o pedido se já está lendo).
            $page = Get-GuiBasePage
            if ($page -eq "home") { Request-GuiHomeRefresh } else { Show-GuiPage -Id $page }
        }
        "LeaveSearch" {
            $eventArgs.Handled = $true
            Exit-GuiSearch
        }
        "ClearSearch" {
            $eventArgs.Handled = $true
            Clear-GuiSearch
        }
        "LeaveRun" {
            $eventArgs.Handled = $true
            Show-GuiRunBack
        }
    }
})

# Voltar à janela encerra o piscar e limpa a cor do resultado na barra de tarefas.
$window.Add_Activated({
    Set-GuiTaskbarFlash -On $false

    if (-not $script:Running) { Set-GuiTaskbarProgress -State None }

    # Quem troca o tema, o contraste alto ou o tamanho do texto do Windows nas Configurações volta para cá: a janela
    # acompanha (o tema, só no modo automático).
    try { [void](Update-GuiTheme) } catch { Write-Verbose "Tema: $($_.Exception.Message)" }
})

# --- Tamanho e posição da janela (settings.json) --------------------------------------------------------------------
function Restore-GuiWindowBounds {
    try {
        $screen = [PSCustomObject]@{
            Left   = [System.Windows.SystemParameters]::VirtualScreenLeft
            Top    = [System.Windows.SystemParameters]::VirtualScreenTop
            Width  = [System.Windows.SystemParameters]::VirtualScreenWidth
            Height = [System.Windows.SystemParameters]::VirtualScreenHeight
        }

        $bounds = Resolve-WinForgeWindowBounds -Saved (Get-WinForgeSetting -Name "Window") -Screen $screen -MinWidth $window.MinWidth -MinHeight $window.MinHeight

        if ($null -ne $bounds) {
            $window.WindowStartupLocation = "Manual"
            $window.Left = $bounds.Left
            $window.Top = $bounds.Top
            $window.Width = $bounds.Width
            $window.Height = $bounds.Height

            if ($bounds.Maximized) { $window.WindowState = "Maximized" }
        }
    }
    catch {
        # Sem posição guardada utilizável, a janela abre centralizada, como sempre.
    }
}

function Limit-GuiWindowToWorkArea {
    # A janela inteira cabe na área útil da tela (sem a barra de tarefas): num notebook de 1366 x 768, ou com a escala de
    # 125% ou 150%, o tamanho padrão passaria da borda de baixo e a barra de título sairia da tela. Só na primeira
    # abertura (sem posição guardada): a posição e o tamanho guardados podem ser de um segundo monitor, maior que a tela
    # principal, e Restore-GuiWindowBounds já os confere contra a área de todos os monitores.
    if ($window.WindowStartupLocation -eq "Manual") { return }

    try {
        $work = [System.Windows.SystemParameters]::WorkArea

        if ($work.Width -le 0 -or $work.Height -le 0) { return }

        if ($work.Height -lt $window.MinHeight) { $window.MinHeight = [Math]::Floor($work.Height) }
        if ($work.Width -lt $window.MinWidth) { $window.MinWidth = [Math]::Floor($work.Width) }

        $window.Width = [Math]::Min([double]$window.Width, [double]$work.Width)
        $window.Height = [Math]::Min([double]$window.Height, [double]$work.Height)
    }
    catch {
        # Sem a medida da tela, fica o tamanho de sempre.
    }
}

function Save-GuiWindowBounds {
    try {
        # RestoreBounds vale também com a janela maximizada ou minimizada: guarda o tamanho "normal".
        $normal = $window.RestoreBounds

        if ($normal.Width -gt 0 -and $normal.Height -gt 0) {
            [void](Set-WinForgeSetting -Name "Window" -Value ([ordered]@{
                        Left      = [int]$normal.Left
                        Top       = [int]$normal.Top
                        Width     = [int]$normal.Width
                        Height    = [int]$normal.Height
                        Maximized = ($window.WindowState -eq "Maximized")
                    }))
        }
    }
    catch {
        # Preferência opcional.
    }
}

$window.Add_Closing({
    param ($sender, $eventArgs)

    if ($script:Running -and -not $script:ForceClose) {
        $answer = Show-GuiMessage -Buttons YesNo -Icon Warning -Title (Get-WinForgeText "`"{0}`" ainda está em andamento" "$($runTitle.Text)") `
            -Text (Get-WinForgeText 'Se você fechar o WinForge agora, a ação é interrompida: o que já foi feito continua feito, mas a etapa atual fica incompleta.') `
            -YesText (Get-WinForgeText 'Fechar mesmo assim') -NoText (Get-WinForgeText 'Continuar') -Danger

        if ($answer -ne "Yes") {
            $eventArgs.Cancel = $true
            return
        }

        Stop-WinForgeGuiCommand -Session $script:GuiSession
    }

    Save-GuiWindowBounds
    $script:Timer.Stop()
    $script:DeferredTimer.Stop()
    $script:PromptFitTimer.Stop()
    $script:SearchTimer.Stop()
    $script:WarmupTimer.Stop()
    $script:SearchWarmTimer.Stop()
    $script:StartActionTimer.Stop()
    $script:RequestTimer.Stop()
    $script:HomeReaderTimer.Stop()
    $script:HomeStampTimer.Stop()
    $script:UpdateExitTimer.Stop()
    $script:UpdateResultTimer.Stop()
    Set-GuiTaskbarProgress -State None

    foreach ($reader in @($script:HomeReader, $script:WarmupReader)) {
        if ($null -ne $reader) { Close-WinForgeGuiReader -Reader $reader }
    }

    if ($null -ne $script:GuiSession) {
        Close-WinForgeGuiSession -Session $script:GuiSession
    }
})

$window.Dispatcher.Add_UnhandledException({
    param ($sender, $eventArgs)
    $eventArgs.Handled = $true
    # A caixa do Windows (-System): a mensagem da própria janela pode ter sido a falha.
    [void](Show-GuiMessage -System -Icon Error -Title (Get-WinForgeText 'Algo deu errado na janela do WinForge') -Text (Get-WinForgeText "Se uma ação estava rodando, confira o resultado dela antes de continuar. Se o problema se repetir, feche e abra o WinForge; o log fica em Sobre o WinForge > Pasta de logs e relatórios.`n`nDetalhe técnico: {0}" "$($eventArgs.Exception.Message)"))
})

# O executor das ações (e a compilação do host) é preparado logo depois de a janela aparecer, e não no primeiro
# clique: assim a primeira ação começa na hora e a abertura da janela não espera por isso.
$script:WarmupTimer = New-Object System.Windows.Threading.DispatcherTimer
$script:WarmupTimer.Interval = [TimeSpan]::FromMilliseconds(700)
$script:WarmupTimer.Add_Tick({
    try {
        if ($null -eq $script:GuiSession) {
            # Primeiro o host da janela (código C#) é compilado num runspace à parte: o Add-Type leva até um segundo, que
            # travaria a janela recém-aberta. O tipo compilado vale para o processo inteiro; depois a sessão abre sem
            # compilar nada. Uma compilação que não termina em 60 segundos é deixada de lado e a sessão compila aqui.
            if ($null -eq $script:WarmupReader -and -not ('WinForge.GuiHost' -as [type])) {
                $script:WarmupReader = New-WinForgeGuiReader -ModuleRoot $moduleRoot -Modules @("GuiHost")
                [void](Start-WinForgeGuiRead -Reader $script:WarmupReader -Command "Initialize-WinForgeGuiHost")
                $script:WarmupTimer.Interval = [TimeSpan]::FromMilliseconds(150)
                return
            }

            if ($null -ne $script:WarmupReader) {
                $compiling = ($null -ne $script:WarmupReader.Ps -and $null -eq (Receive-WinForgeGuiRead -Reader $script:WarmupReader))
                if ($compiling -and ((Get-Date) - $script:WarmupReader.StartedAt).TotalSeconds -lt 60) { return }

                Close-WinForgeGuiReader -Reader $script:WarmupReader
                $script:WarmupReader = $null
            }

            $script:GuiSession = New-WinForgeGuiSession -ModuleRoot $moduleRoot -Modules $script:ActionModules
        }
    }
    catch {
        # Se falhar aqui, a falha aparece (com mensagem) no primeiro clique.
        $script:GuiSession = $null

        if ($null -ne $script:WarmupReader) {
            Close-WinForgeGuiReader -Reader $script:WarmupReader
            $script:WarmupReader = $null
        }
    }

    $script:WarmupTimer.Stop()
})

# O temporizador que recolhe as etapas do Início feitas em segundo plano.
$script:HomeReaderTimer = New-Object System.Windows.Threading.DispatcherTimer
$script:HomeReaderTimer.Interval = [TimeSpan]::FromMilliseconds(120)
$script:HomeReaderTimer.Add_Tick({
    try { Update-GuiHomeReader } catch { $script:HomeReaderTimer.Stop(); Stop-GuiHomeRead }
})

# A hora da leitura do Início acompanha a virada do dia.
$script:HomeStampTimer = New-Object System.Windows.Threading.DispatcherTimer
$script:HomeStampTimer.Interval = [TimeSpan]::FromMinutes(1)
$script:HomeStampTimer.Add_Tick({
    try { Update-GuiHomeStampAge } catch { }
})

# O índice da busca (com o catálogo de ajustes) e o vocabulário da correção de digitação são montados uma vez, em 0,1 a
# 0,6 s; montá-los aqui, um pouco depois de a janela aparecer (e do executor das ações, às 0,7 s), evita que a primeira
# tecla digitada na busca espere por eles.
$script:SearchWarmTimer = New-Object System.Windows.Threading.DispatcherTimer
$script:SearchWarmTimer.Interval = [TimeSpan]::FromMilliseconds(1500)
$script:SearchWarmTimer.Add_Tick({
    $script:SearchWarmTimer.Stop()

    try {
        [void](Get-WinForgeSearchIndex)
        [void](Get-WinForgeSearchVocabulary)
    }
    catch {
        Write-Verbose "Índice da busca: $($_.Exception.Message)"
    }
})

# A atualização com um clique (Complete-GuiRun): fecha a janela sem perguntar, para o instalador trocar os arquivos.
$script:UpdateExitTimer = New-Object System.Windows.Threading.DispatcherTimer
$script:UpdateExitTimer.Interval = [TimeSpan]::FromMilliseconds(1500)
$script:UpdateExitTimer.Add_Tick({
    $script:UpdateExitTimer.Stop()
    $script:ForceClose = $true
    $window.Close()
})

# Depois de uma atualização, a mensagem de como ela terminou aparece com a janela já desenhada.
$script:UpdateResultTimer = New-Object System.Windows.Threading.DispatcherTimer
$script:UpdateResultTimer.Interval = [TimeSpan]::FromMilliseconds(400)
$script:UpdateResultTimer.Add_Tick({
    $script:UpdateResultTimer.Stop()
    Show-GuiUpdateResult
})

# Aberta pelo monitor na bandeja com uma ação (-Action): ela roda logo depois que o executor fica pronto.
$script:StartActionTimer = New-Object System.Windows.Threading.DispatcherTimer
$script:StartActionTimer.Interval = [TimeSpan]::FromMilliseconds(900)
$script:StartActionTimer.Add_Tick({
    $script:StartActionTimer.Stop()

    $item = Get-WinForgeNavItem -Id $script:StartAction
    $script:StartAction = ""

    if ($null -ne $item) { Invoke-GuiNavItem -Item $item }
})

function Test-GuiRequestFromOtherFolder {
    # O pedido veio de uma abertura de outra pasta do WinForge (outra identidade, Get-WinForgeAppId, que compara as pastas
    # do mesmo jeito em qualquer caminho)? Um pedido sem ela (de uma versão anterior à R40) conta como desta pasta.
    param ([Parameter(Mandatory)]$Request)

    $app = [string]$Request.App
    if (-not $app) { return $false }

    try { return ($app -ne [string](Get-WinForgeAppId)) } catch { return $false }
}

function Show-GuiOtherFolderMessage {
    <#
    Outra pasta do WinForge foi aberta (outra versão, extraída de outro zip) com esta janela aberta. Só uma janela do
    WinForge abre por conta, e a abertura nova só traria esta para a frente: a pessoa veria esta versão achando que é a
    outra. A mensagem diz de que pasta é cada uma e oferece fechar esta, para abrir a outra de novo. O WinForge não abre
    a outra sozinho: o pedido vem de um arquivo que qualquer programa da conta grava, e esta janela roda como Administrador.
    #>
    param ([Parameter(Mandatory)]$Request)

    $here = ""
    try { $here = [string](Get-WinForgeAppRoot) } catch { $here = "" }
    $there = $(if ([string]$Request.Root) { [string]$Request.Root } else { (Get-WinForgeText 'outra pasta') })

    $answer = Show-GuiMessage -Buttons YesNo -Icon Warning -Default No -Title (Get-WinForgeText 'Esta janela é de outra pasta do WinForge') `
        -Text (Get-WinForgeText "Você abriu o WinForge de:`n{0}`n`nEsta janela é de:`n{1}`n`nPara usar o que você abriu, feche esta janela e abra o WinForge de novo." "$there" "$here") `
        -YesText (Get-WinForgeText 'Fechar esta janela') -NoText (Get-WinForgeText 'Continuar aqui')

    if ($answer -eq "Yes") { $window.Close() }
}

function Receive-GuiWindowRequest {
    <#
    Um pedido de outra abertura do WinForge (Enter-WinForgeWindowLock), lido a cada meio segundo: a janela vem para a
    frente e, se o pedido trouxe uma ação do monitor na bandeja, ela roda. Um pedido de outra pasta do WinForge (outra
    versão) não roda nada: a janela diz de que pasta é cada uma (Show-GuiOtherFolderMessage).
    #>
    $request = Receive-WinForgeWindowRequest
    if ($null -eq $request) { return }

    if ($window.WindowState -eq "Minimized") { $window.WindowState = "Normal" }
    [void]$window.Activate()
    $window.Topmost = $true
    $window.Topmost = $false
    if (-not $window.IsActive) { Set-GuiTaskbarFlash -On $true }

    if (Test-GuiRequestFromOtherFolder -Request $request) {
        # Sem outro pedido no meio da mensagem: o relógio volta quando ela fecha (e não volta se a janela fechou).
        $script:RequestTimer.Stop()

        try {
            Show-GuiOtherFolderMessage -Request $request
        }
        finally {
            if ($window.IsVisible) { $script:RequestTimer.Start() }
        }

        return
    }

    # Só as ações que o monitor na bandeja oferece: o pedido vem de um arquivo que qualquer programa desta conta grava
    # sem elevação, e a janela roda como Administrador.
    if ($request.Action -and $request.Action -in @(Get-WinForgeAgentActionIds)) {
        $item = Get-WinForgeNavItem -Id $request.Action
        if ($null -ne $item) { Invoke-GuiNavItem -Item $item }
    }
}

# Pedidos de outra abertura do WinForge (Enter-WinForgeWindowLock): a janela vem para a frente e, se o pedido trouxe
# uma ação, ela roda (ou, com outra ação em andamento, a pessoa é avisada). De outra pasta, a janela diz isso.
$script:RequestTimer = New-Object System.Windows.Threading.DispatcherTimer
$script:RequestTimer.Interval = [TimeSpan]::FromMilliseconds(500)
$script:RequestTimer.Add_Tick({
    try {
        Receive-GuiWindowRequest
    }
    catch {
        Write-Verbose "Pedido de outra abertura: $($_.Exception.Message)"
    }
})

$window.Add_ContentRendered({
    $script:WarmupTimer.Start()
    $script:SearchWarmTimer.Start()
    $script:RequestTimer.Start()
    $script:HomeStampTimer.Start()
    $script:UpdateResultTimer.Start()

    if ($script:StartAction) { $script:StartActionTimer.Start() }

    # Quanto a janela levou para aparecer desde o começo deste processo (logs\abertura.log).
    try { Add-WinForgeOpenTime -Kind "Gui" -Seconds ((Get-Date) - (Get-Process -Id $PID).StartTime).TotalSeconds } catch { Write-Verbose "Tempo de abertura: $($_.Exception.Message)" }
})

if ($isAdmin) {
    $window.FindName("AdminText").Text = (Get-WinForgeText 'Administrador')
}
else {
    $window.FindName("AdminText").Text = (Get-WinForgeText 'Sem Administrador · o WinForge pede de novo quando uma ação precisar')
}

Restore-GuiWindowBounds
Limit-GuiWindowToWorkArea
Reset-GuiOutput
$script:AntivirusMode = Get-GuiSavedAntivirusMode
Show-GuiPage -Id $script:StartPage
[void]$window.ShowDialog()
