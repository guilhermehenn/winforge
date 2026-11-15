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
        Show-GuiStartupMessage -Text "Não foi possível abrir a janela do WinForge. Abra o WinForge de novo."
        exit 1
    }

    if (-not $isAdmin -and (Start-GuiRelaunch -Page $Page -Action $Action -Elevated)) { exit }

    # Aviso do Windows recusado (ou elevação bloqueada): segue sem Administrador, em STA.
    if (-not $isSta) {
        if (Start-GuiRelaunch -Page $Page -Action $Action) { exit }

        Show-GuiStartupMessage -Text "Não foi possível abrir a janela do WinForge. Abra o WinForge de novo."
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
            throw "Módulo obrigatório não encontrado: $modulePath"
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
        throw "Arquivo da janela não encontrado: $xamlPath"
    }

    [xml]$xaml = Get-Content -LiteralPath $xamlPath -Raw -Encoding UTF8
    $window = [System.Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $xaml))
}
catch {
    # Quase sempre é um arquivo que faltou (zip extraído pela metade, antivírus) ou uma pasta com colchetes no nome.
    $extract = "Extraia de novo o WinForge.zip inteiro (Extrair tudo), numa pasta sem colchetes no nome, e abra o WinForge da pasta extraída."

    if (-not [string]::IsNullOrEmpty([string]$script:MissingFile)) {
        Show-GuiStartupMessage -Text "O WinForge não abriu porque falta um arquivo dele: $($script:MissingFile).`n`n$extract Se o arquivo sumir outra vez, veja se o antivírus o pôs em quarentena."
    }
    else {
        Show-GuiStartupMessage -Text "O WinForge não abriu.`n`n$extract Se continuar, mande este detalhe ao suporte:`n`n$($_.Exception.Message)"
    }

    exit 1
}

# O processo ganha o nome "WinForge" para a barra de tarefas (sem isso a janela é agrupada com o PowerShell e
# mostra o ícone dele). É cosmético: qualquer falha é ignorada.
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
$script:HomeCards = @{}
$script:HomeBanner = $null
$script:HomeHealth = $null
$script:HomeFactInfo = @{}
# A hora da leitura e o botão de ler de novo ficam logo abaixo da frase da nota de saúde, que é refeita a cada leitura: o
# texto e se o botão vale ficam aqui, e os controles da nota atual (HomeStampText, HomeRefreshButton, HomeStampBar) os
# mostram.
$script:HomeStamp = @{ Text = "Lendo o PC..."; CanRefresh = $false; ReadAt = $null }
$script:HomeStampText = $null
$script:HomeRefreshButton = $null
# A frase grande da nota de saúde (o leitor de tela a lê quando a leitura termina).
$script:HomeHeadline = $null
$script:HomeRead = $null
$script:HomeSnapshot = $null
# A última leitura completa mostrada, mesmo vencida (HomeSnapshotSeconds) ou descartada por uma ação: voltar ao Início
# mostra os valores dela na hora, e a leitura nova os troca no lugar, em vez de os cartões voltarem a "Lendo...".
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
# Quem protege o PC, pela última leitura do Início (Active, Other, Off...): com outro antivírus, Verificar vírus sai do
# Início e as ações do Defender saem da página Segurança. Vem guardado da última vez que o WinForge abriu (lido antes da
# primeira página): sem isso, o botão apareceria por alguns segundos e sumiria quando a leitura terminasse. "" enquanto
# não se sabe.
$script:AntivirusMode = ""
# Se o PC tem bateria, pelo cartão Bateria do Início: $false (num PC de mesa) tira Saúde da bateria da página Diagnóstico.
# $null enquanto não se sabe: o cartão fica (a busca e o console chegam nele de qualquer jeito).
$script:HasBattery = $null
# A grade dos cartões (Update-GuiContentWidth): de 252 a 300 de largura, com 12 entre um e outro.
$script:CardMinWidth = 252.0
$script:CardMaxWidth = 300.0
$script:CardGap = 12.0
$script:CardWidth = 252.0
$script:WideCardWidth = 384.0
# A etapa do Otimizar em andamento ("Etapa 3 de 22: ..."): depois da primeira, só uma etapa muda a frase em destaque (um
# título de seção no meio dela, como "Lixeira", não), e a barra mostra o andamento da execução inteira.
$script:RunStepSeen = $false
$script:RunStepIndex = 0
$script:RunStepTotal = 0
# As linhas do resumo que, com uma pergunta na tela, foram para dentro do cartão dela (Set-GuiPromptContext).
$script:PromptContextHidden = New-Object System.Collections.ArrayList
# O que estava marcado quando a lista apareceu: numa revisão (o que abre com o Windows, os ajustes), o botão conta as mudanças.
$script:PromptInitialKeys = @()
$script:PromptReview = $false
$script:HomeStampBar = $null

$script:BrushConverter = New-Object System.Windows.Media.BrushConverter
$script:BrushByHex = @{}

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
    # Default: a resposta do Enter. Nas perguntas Sim/Não é Não, salvo quando a pessoa acabou de pedir aquilo (reabrir
    # como Administrador): um Enter a mais nunca interrompe nem apaga nada.
    param (
        [Parameter(Mandatory)][string]$Text,
        [string]$Title = "WinForge",
        [ValidateSet("OK", "YesNo")]
        [string]$Buttons = "OK",
        [ValidateSet("Information", "Warning", "Error", "Question")]
        [string]$Icon = "Information",
        [ValidateSet("Yes", "No")]
        [string]$Default = "No"
    )

    $defaultResult = $(if ($Buttons -eq "OK") { "OK" } else { $Default })

    try {
        return [string][System.Windows.MessageBox]::Show($window, $Text, $Title, $Buttons, $Icon, $defaultResult)
    }
    catch {
        # Janela já fechada ou ainda não exibida: mostra a mensagem sem dono.
        return [string][System.Windows.MessageBox]::Show($Text, $Title, $Buttons, $Icon, $defaultResult)
    }
}

function New-GuiText {
    param (
        [string]$Text,
        [double]$Size = 13,
        [string]$Color = $script:Theme.Text,
        [bool]$Bold = $false
    )

    $block = New-Object System.Windows.Controls.TextBlock
    $block.Text = $Text
    $block.FontSize = $Size
    $block.Foreground = New-GuiBrush $Color
    $block.TextWrapping = "Wrap"

    if ($Bold) { $block.FontWeight = [System.Windows.FontWeights]::SemiBold }

    return $block
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
        [double]$Radius = 14,
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
        [double]$Radius = 14,
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
    $chip.CornerRadius = New-Object System.Windows.CornerRadius 6
    $chip.Padding = New-Object System.Windows.Thickness (8, 3, 8, 3)
    $chip.VerticalAlignment = "Top"
    $chip.Child = New-GuiText -Text $Text -Size 12 -Color $script:Theme.AccentText -Bold $true

    return $chip
}

function New-GuiKeyChip {
    # Uma tecla desenhada como a "Ctrl K" da caixa de busca: o "Enter" no resultado que o Enter abre.
    param ([Parameter(Mandatory)][string]$Text)

    $chip = New-GuiOutlinedBorder -Background $script:Theme.Card -BorderColor $script:Theme.Line -Radius 5 -Padding (New-Object System.Windows.Thickness (6, 1, 6, 1))
    $chip.VerticalAlignment = "Top"
    Set-GuiPanelContent -Panel $chip -Content (New-GuiText -Text $Text -Size 11 -Color $script:Theme.Dim)

    return $chip
}

function New-GuiNote {
    # Observação discreta com ícone ("Pede Administrador ao executar", "Abre no Windows").
    param (
        [Parameter(Mandatory)][string]$Text,
        [Parameter(Mandatory)][string]$Icon
    )

    $row = New-Object System.Windows.Controls.StackPanel
    $row.Orientation = "Horizontal"

    $glyph = New-GuiIcon -Name $Icon -Size 13 -Color $script:Theme.Dim
    $glyph.Margin = New-Object System.Windows.Thickness (0, 0, 6, 0)
    [void]$row.Children.Add($glyph)

    $label = New-GuiText -Text $Text -Size 12 -Color $script:Theme.Dim
    $label.VerticalAlignment = "Center"
    [void]$row.Children.Add($label)

    return $row
}

function New-GuiSectionHeading {
    # Título de uma parte da página ("Seu PC", "Por onde começar").
    param ([Parameter(Mandatory)][string]$Text)

    $heading = New-GuiText -Text $Text -Size 16 -Bold $true
    $heading.Margin = New-Object System.Windows.Thickness (0, 22, 0, 12)

    return $heading
}

function New-GuiGroupHeading {
    # Título de uma seção de cartões dentro de uma página ("Liberar espaço"). Mais discreto que o das partes do Início:
    # organiza a página sem competir com o título dela. O primeiro não precisa do espaço que separa uma seção da anterior.
    param ([Parameter(Mandatory)][string]$Text, [bool]$First = $false)

    $heading = New-GuiText -Text $Text -Size 14 -Color $script:Theme.Muted -Bold $true
    $heading.Margin = New-Object System.Windows.Thickness (0, $(if ($First) { 2 } else { 14 }), 0, 10)
    Set-GuiAutomationName -Element $heading -Name "Seção: $Text"

    return $heading
}

function New-GuiNotice {
    # Aviso em destaque no alto de uma página (amarelo), com o ícone de atenção.
    param ([Parameter(Mandatory)][string]$Text)

    $banner = New-GuiPanelBorder -Background $script:LevelColors.Warn.Back -BorderColor $script:LevelColors.Warn.Line -Radius 12 -Padding (New-Object System.Windows.Thickness (14, 10, 14, 10))
    $banner.Margin = New-Object System.Windows.Thickness (0, 0, 12, 14)

    $row = New-Object System.Windows.Controls.DockPanel
    $glyph = New-GuiIcon -Name "warning" -Size 18 -Color $script:LevelColors.Warn.Dot
    $glyph.Margin = New-Object System.Windows.Thickness (0, 0, 10, 0)
    $glyph.VerticalAlignment = "Top"
    Set-GuiDock -Element $glyph -Side "Left"
    [void]$row.Children.Add($glyph)
    [void]$row.Children.Add((New-GuiText -Size 13 -Color $script:Theme.Text -Text $Text))

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

        $dark = $(if ($script:ThemeName -eq "Dark") { 1 } else { 0 })

        # 20 = modo escuro (Windows 10 20H1+ e 11); 19 = valor usado por builds anteriores do Windows 10.
        if ([WinForge.NativeWindow]::DwmSetWindowAttribute($handle, 20, [ref]$dark, 4) -ne 0) {
            [void][WinForge.NativeWindow]::DwmSetWindowAttribute($handle, 19, [ref]$dark, 4)
        }

        # Windows 11 (build 22000+): cor exata da barra, do texto e da borda. COLORREF = 0x00BBGGRR.
        $caption = ConvertTo-WinForgeColorRef -Hex $script:Theme.Window
        $text = ConvertTo-WinForgeColorRef -Hex $script:Theme.Text
        $border = ConvertTo-WinForgeColorRef -Hex $script:Theme.Line
        [void][WinForge.NativeWindow]::DwmSetWindowAttribute($handle, 35, [ref]$caption, 4)
        [void][WinForge.NativeWindow]::DwmSetWindowAttribute($handle, 36, [ref]$text, 4)
        [void][WinForge.NativeWindow]::DwmSetWindowAttribute($handle, 34, [ref]$border, 4)
    }
    catch {
        # Cosmético: em versões sem suporte a barra continua com o tema padrão do Windows.
    }
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

function Set-GuiTheme {
    # Aplica um tema: as cores que o script usa ao montar controles, as do console nos detalhes técnicos e os pincéis do
    # XAML (que mudam na hora, por serem DynamicResource).
    param ([ValidateSet("Light", "Dark")][string]$Name)

    $script:ThemeName = $Name
    $script:Theme = Get-WinForgePalette -Name $Name
    $script:LevelColors = Get-WinForgeLevelColors -Theme $script:Theme
    $script:ColorMap = Get-WinForgeConsolePalette -Name $Name
    $script:BrushCache = @{}

    foreach ($key in @($script:Theme.Keys)) {
        $window.Resources["${key}Brush"] = New-GuiBrush $script:Theme[$key]
    }

    Set-GuiTitleBarTheme -Target $window
}

function Update-GuiTheme {
    # Confere o tema (a escolha da pessoa ou o do Windows) e, se mudou, aplica e redesenha o que está na tela. Devolve
    # verdadeiro quando mudou.
    $name = Resolve-WinForgeTheme -Preference $script:ThemePreference -SystemTheme (Get-GuiSystemTheme)

    if ($name -eq $script:ThemeName) { return $false }

    Set-GuiTheme -Name $name
    Update-GuiThemedContent

    return $true
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
            # O WPF escolhe sozinho o tamanho certo do .ico para a barra de título, a barra de tarefas e o Alt+Tab.
            $window.Icon = $decoder.Frames[0]

            # Logotipo da barra lateral: o maior tamanho do arquivo, reduzido com qualidade pelo WPF.
            $logo = $window.FindName("LogoImage")
            $logo.Source = @($decoder.Frames | Sort-Object PixelWidth -Descending)[0]
            $logo.Visibility = "Visible"
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

$window.FindName("BuildText").Text = "Build $(Get-WinForgeBuild)"

# O tema entra antes de qualquer controle ser montado pelo script (cada um guarda a cor com que foi criado).
try { $script:ThemePreference = Get-WinForgeThemePreference } catch { $script:ThemePreference = "System" }
Set-GuiTheme -Name (Resolve-WinForgeTheme -Preference $script:ThemePreference -SystemTheme (Get-GuiSystemTheme))

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

    if ($Entry.Kind -eq "Section" -or $Entry.Kind -eq "Step") {
        $heading = New-GuiText -Text ([string]$Entry.Text) -Size 12.5 -Color $script:Theme.Muted -Bold $true
        $heading.Margin = New-Object System.Windows.Thickness (0, 10, 0, 3)
        return $heading
    }

    if ($Entry.Kind -eq "Fact") {
        $line = New-Object System.Windows.Controls.DockPanel
        $line.Margin = New-Object System.Windows.Thickness (27, 2, 0, 2)

        $label = New-GuiText -Text ([string]$Entry.Label) -Size 13 -Color $script:Theme.Muted
        $label.Width = 210
        $label.Margin = New-Object System.Windows.Thickness (0, 0, 12, 0)
        Set-GuiDock -Element $label -Side "Left"
        [void]$line.Children.Add($label)

        # O valor que pede atenção (ou que confirma que está tudo certo) vem na cor do nível, como no console.
        $value = switch ([string]$Entry.Level) {
            "Ok"    { New-GuiText -Text ([string]$Entry.Value) -Size 13.5 -Color $script:Theme.Ok }
            "Warn"  { New-GuiText -Text ([string]$Entry.Value) -Size 13.5 -Color $script:Theme.Warn -Bold $true }
            "Bad"   { New-GuiText -Text ([string]$Entry.Value) -Size 13.5 -Color $script:Theme.Bad -Bold $true }
            default { New-GuiText -Text ([string]$Entry.Value) -Size 13.5 }
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

    if ($null -eq $reference) { return (New-GuiText -Text $Text -Size 13.5) }

    $block = New-GuiText -Text "" -Size 13.5
    $rest = $Text

    while ($null -ne $reference) {
        $before = $rest.Substring(0, $reference.Start)
        $linked = $rest.Substring($reference.Start, $reference.Length)

        if ($before) { [void]$block.Inlines.Add((New-Object System.Windows.Documents.Run $before)) }

        $link = New-Object System.Windows.Documents.Hyperlink
        [void]$link.Inlines.Add((New-Object System.Windows.Documents.Run $linked))
        $link.Style = $window.FindResource("SummaryLink")
        $link.Tag = $reference.ItemId
        $link.ToolTip = "Abrir $linked"
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
    if ($Kind -eq "Step" -and $Text -match '^Etapa ([0-9]+) de ([0-9]+):') {
        $script:RunStepSeen = $true
        $script:RunStepIndex = [int]$Matches[1]
        $script:RunStepTotal = [int]$Matches[2]
        Set-GuiRunStep -Text $Text
        [void](Update-GuiOverallProgress -Fraction 0.0)
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
    Set-GuiAutomationName -Element $detailsToggle -Name $(if ($Open) { "Ocultar os detalhes técnicos" } else { "Mostrar os detalhes técnicos" })
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

        Set-GuiRunStatus -Text "Esperando a sua resposta" -DotColor $script:Theme.Warn
    }
    else {
        Restore-GuiAroundPrompt
        Set-GuiRunStatus -Text "Em execução" -DotColor $script:Theme.Accent
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

    while ($start -gt 0 -and [string]$entries[$start - 1].Kind -ne "Section" -and [string]$entries[$start - 1].Kind -ne "Step") { $start-- }

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
            $child.Content = $(if ($words.Count -gt 0) { "Marcar os $shown à vista" } else { "Marcar todos" })
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
                $child.Content = $(if ($changes -gt 0) { "$label ($changes)" } else { "Continuar" })
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
    param (
        [string]$Text,
        [string]$Description = "",
        [bool]$Accent = $false,
        [bool]$Exit = $false,
        $Tag
    )

    $button = New-GuiButton -Text $Text -Kind $(if ($Accent -and -not $Exit) { "Primary" } else { "Secondary" }) -Tag $Tag
    $button.Margin = New-Object System.Windows.Thickness (0, 0, 10, 8)

    if (-not [string]::IsNullOrWhiteSpace($Description)) {
        $button.ToolTip = $Description
    }

    return $button
}

function New-GuiPromptOption {
    # Uma opção da pergunta em linha, como nas listas de escolha dos sistemas atuais: título, descrição e a seta. A
    # opção recomendada vem destacada.
    param (
        [string]$Text,
        [string]$Description = "",
        [bool]$Accent = $false,
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
    [void]$stack.Children.Add((New-GuiText -Text $Text -Size 14 -Bold $true))

    if (-not [string]::IsNullOrWhiteSpace($Description)) {
        $detail = New-GuiText -Text $Description -Size 12.5 -Color $script:Theme.Muted
        $detail.Margin = New-Object System.Windows.Thickness (0, 2, 0, 0)
        [void]$stack.Children.Add($detail)
    }

    [void]$row.Children.Add($stack)
    $button.Content = $row

    # A borda na cor do texto de destaque: no tema escuro, o azul do botão principal fica abaixo do contraste mínimo
    # (3:1) sobre o fundo do cartão.
    if ($Accent) {
        $button.Background = New-GuiBrush $script:Theme.AccentCard
        $button.BorderBrush = New-GuiBrush $script:Theme.AccentText
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
            [void]$stack.Children.Add((New-GuiText -Text ([string]$option.Label) -Size 13.5))

            if (-not [string]::IsNullOrWhiteSpace([string]$option.Description)) {
                [void]$stack.Children.Add((New-GuiText -Text ([string]$option.Description) -Size 12 -Color $script:Theme.Muted))
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

        $confirmLabel = $(if ($null -ne $Prompt.PSObject.Properties["ConfirmLabel"] -and -not [string]::IsNullOrWhiteSpace([string]$Prompt.ConfirmLabel)) { [string]$Prompt.ConfirmLabel } elseif ($review) { "Aplicar" } else { "Confirmar" })
        $cancelLabel = $(if ($null -ne $Prompt.PSObject.Properties["CancelLabel"] -and -not [string]::IsNullOrWhiteSpace([string]$Prompt.CancelLabel)) { [string]$Prompt.CancelLabel } else { "Cancelar" })

        $confirm = New-GuiPromptButton -Text "$confirmLabel (0)" -Accent $true -Tag @{ Role = "confirm"; Label = $confirmLabel }
        $confirm.Add_Click({ Submit-GuiMultiPrompt -Accepted $true })
        [void]$promptButtons.Children.Add($confirm)

        # Sem "Marcar todos" onde marcar tudo de uma vez seria um desastre (desinstalar programas, remover aplicativos).
        $noSelectAll = ($null -ne $Prompt.PSObject.Properties["NoSelectAll"] -and [bool]$Prompt.NoSelectAll)

        if (-not $noSelectAll) {
            $all = New-GuiPromptButton -Text "Marcar todos" -Tag @{ Role = "all" }
            $all.Add_Click({
                foreach ($child in $promptList.Children) { if ($child.Visibility -eq "Visible") { $child.IsChecked = $true } }
                Update-GuiMultiPromptCount
            })
            [void]$promptButtons.Children.Add($all)
        }

        if (-not $review) {
            $none = New-GuiPromptButton -Text "Desmarcar tudo" -Tag @{ Role = "none" }
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
                $control = New-GuiPromptOption -Text $definition.Text -Description $definition.Description -Accent $accent -Tag $tag
            }
            else {
                $control = New-GuiPromptButton -Text $definition.Text -Description $definition.Description -Accent $accent -Exit ([bool]$definition.Exit) -Tag $tag
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
    # Mostra a tela de execução (saída, andamento, perguntas) no lugar da página aberta.
    $pagesView.Visibility = "Collapsed"
    $runView.Visibility = "Visible"
    $script:RunUnseen = $false
    Update-GuiRunStrip
    Set-GuiSelectedNav -Id $script:RunPage
}

function Update-GuiRunStrip {
    # A faixa no alto das páginas: mostra a ação em andamento (ou o resultado que ainda não foi visto).
    $showStrip = ($script:Running -or $script:RunUnseen) -and ($runView.Visibility -ne "Visible")

    if (-not $showStrip) {
        $runStrip.Visibility = "Collapsed"
        return
    }

    $runStrip.Visibility = "Visible"
    $runStripTitle.Text = $runTitle.Text

    if ($script:Running) {
        $runStripDot.Fill = New-GuiBrush $script:Theme.Accent
        $text = "Em execução · $(Format-WinForgeClock -Span (Get-GuiRunElapsed))"

        # A etapa do Otimizar diz mais do que a ferramenta da vez ("Etapa 9 de 22: Reparar o Windows").
        if ($script:RunStepSeen -and -not [string]::IsNullOrWhiteSpace($runStepText.Text)) {
            $text += " · $($runStepText.Text)"
        }
        elseif (-not [string]::IsNullOrWhiteSpace($progressText.Text)) {
            $text += " · $($progressText.Text)"
        }
        elseif (-not [string]::IsNullOrWhiteSpace($runStepText.Text) -and $runStepText.Text -ne "Em andamento") {
            $text += " · $($runStepText.Text)"
        }

        if ($null -ne $script:ShownPrompt) {
            $text = "Esperando a sua resposta"
            $runStripDot.Fill = New-GuiBrush $script:Theme.Warn
        }

        $runStripText.Text = $text
        $runStripStop.Visibility = "Visible"
        $runStripDismiss.Visibility = "Collapsed"
        $runStripView.Content = "Ver"
        Set-GuiAutomationName -Element $runStripView -Name "Ver a ação em andamento: $($runTitle.Text)"
    }
    else {
        $view = $script:LastRunView
        $colors = $script:LevelColors[[string]$view.Level]
        $runStripDot.Fill = New-GuiBrush $colors.Dot
        $runStripText.Text = "$($view.StatusText) · $($view.ElapsedText)"
        $runStripStop.Visibility = "Collapsed"
        $runStripDismiss.Visibility = "Visible"
        $runStripView.Content = "Ver resultado"
        Set-GuiAutomationName -Element $runStripView -Name "Ver o resultado: $($runTitle.Text)"
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
            $label = $(if ($null -ne $item) { [string]$item.Label } else { "Abrir" })
        }

        $resultAction.Content = $label
    }

    if ($View.ShowBanner) {
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

    # Com um próximo passo na faixa (ameaças que pedem ação), rodar de novo não resolve nada: o botão sairia do lugar dele.
    $hasNext = -not [string]::IsNullOrWhiteSpace([string](Get-WinForgeJsonValue -Object $view -Name "Next" -Default ""))
    $hideSummary = [bool](Get-WinForgeJsonValue -Object $view -Name "HideSummary" -Default $false)
    # "Nada a fazer" (outro antivírus no lugar, nada para limpar) também não muda rodando de novo; "Cancelado" muda.
    $nothing = ($null -ne $Outcome -and [string]$Outcome.Kind -eq "Skipped" -and [string]$Outcome.Detail -notmatch "(?i)cancelad|reiniciando")
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

        # Com o resumo de etapas (o "Resumo" do fim do Otimizar), a tela abre nele, e não no fim da lista. Com um próximo
        # passo na faixa (as ameaças que pedem ação), abre na última seção, a da lista: numa janela baixa, o fim dela
        # deixaria a primeira ameaça cortada.
        if ($view.ShowBanner) { Show-GuiSummarySection -Title $(if ($hasNext) { "" } else { "Resumo" }) }
    }

    # Se a pessoa estava em outra página, o resultado fica na faixa até ela ver; se a janela não está em primeiro
    # plano, o botão pisca na barra de tarefas e mostra a cor do resultado.
    $script:RunUnseen = ($runView.Visibility -ne "Visible")
    Update-GuiRunStrip

    if (-not $window.IsActive -and $view.Notify) {
        Set-GuiTaskbarProgress -State $view.Taskbar -Value 1
        Set-GuiTaskbarFlash -On $true
    }

    Send-GuiAnnouncement -Element $runStatus

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
                if ($runStepText.Text -eq "Em andamento" -and -not [string]::IsNullOrWhiteSpace([string]$info.Activity)) { Set-GuiRunStep -Text ([string]$info.Activity) }

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
            Set-GuiRunStatus -Text "Não foi concluído" -DotColor $script:Theme.Bad
        }

        [void](Show-GuiMessage -Icon Error -Title "Ação interrompida" -Text "A janela parou de acompanhar a ação e, por segurança, ela foi interrompida.`n`nO que já foi feito continua feito. Tente de novo; se acontecer outra vez, abra Sobre o WinForge > Pasta de logs e relatórios e envie o log mais recente ao suporte.`n`nDetalhe técnico: $failure")
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

    $answer = Show-GuiMessage -Buttons YesNo -Icon Question -Default Yes -Title "Administrador" -Text "$Reason`n`nPara continuar, o WinForge precisa ser reaberto como Administrador, na mesma página. Reabrir agora?"

    if ($answer -ne "Yes") { return $false }

    $page = Get-GuiBasePage
    if ($page -notmatch '^[a-z]+$') { $page = "home" }

    if (Start-GuiRelaunch -Page $page -Action $Action -Elevated -Handover) {
        # A janela nova já foi aberta: fecha esta sem perguntar de novo.
        $script:ForceClose = $true
        $window.Close()
    }
    else {
        [void](Show-GuiMessage -Icon Warning -Title "Administrador" -Text "O Windows não concedeu a permissão, então o WinForge continua sem Administrador.`n`nTente de novo e aceite o aviso do Windows (Controle de Conta de Usuário).")
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
        [string]$NavId = ""
    )

    if ($script:Running) {
        [void](Show-GuiMessage -Text "Já existe uma ação em andamento ($($runTitle.Text)). Aguarde terminar ou use Parar.`n`nPara voltar a ela, use o botão Ver, na faixa no alto da página." -Icon Information)
        return
    }

    if ($RequiresAdmin -and -not (Request-GuiAdministrator -Reason "A ação '$Label' precisa de permissão de Administrador." -Action $NavId)) {
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
        $script:RunPage = $script:CurrentPage
        $script:RunUnseen = $false
        $script:LastRunView = $null
        $runTitle.Text = $Label
        try { $runStatus.ClearValue([System.Windows.Automation.AutomationProperties]::NameProperty) } catch { Write-Verbose "Leitor de tela: $($_.Exception.Message)" }
        Set-GuiRunStatus -Text "Em execução" -DotColor $script:Theme.Accent
        $runElapsed.Text = "· 00:00"
        Set-GuiRunStep -Text "Em andamento"
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
        $copyButton.Content = "Copiar"
        $saveButton.Content = "Salvar"
        $script:ShownPrompt = $null
        $script:ProgressVersionShown = -1
        Set-GuiTaskbarFlash -On $false

        $pagesView.Visibility = "Collapsed"
        $runView.Visibility = "Visible"
        $runStrip.Visibility = "Collapsed"
        $window.UpdateLayout()

        # O foco do teclado sai da caixa de busca (ou do cartão clicado, que sumiu): um Enter a mais não abre a ação de novo.
        [void]$runView.Focus()

        $started = Start-WinForgeGuiCommand -Session $script:GuiSession -Command $Command -Columns (Get-GuiOutputColumns)

        if (-not $started) { throw "Já existe uma ação em execução." }

        $script:Running = $true
        Set-GuiTaskbarProgress -State Indeterminate
        $script:Timer.Start()
    }
    catch {
        $pagesView.Visibility = "Visible"
        $runView.Visibility = "Collapsed"
        Set-GuiTaskbarProgress -State None
        [void](Show-GuiMessage -Icon Error -Text "Não foi possível começar ""$Label"".`n`nTente de novo. Se continuar, feche e abra o WinForge.`n`nDetalhe técnico: $($_.Exception.Message)")
    }
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
        $reason = $(if ($Name -in @("Downloads", "LogFolder")) { "O Explorador de Arquivos não abriu a pasta. Tente abri-la manualmente." } else { "O recurso pode não existir nesta edição do Windows." })
        [void](Show-GuiMessage -Icon Warning -Title $Title -Text "Não foi possível abrir '$Title'.`n`n$reason")
    }
}

function Get-GuiNavCommand {
    # O comando de um cartão vem da tabela de navegação; só nomes de função válidos chegam ao executor.
    param ([Parameter(Mandatory)]$Item)

    if ([string]$Item.Command -notmatch '^[A-Za-z]+-[A-Za-z0-9]+$') {
        throw "Comando inválido na navegação: $($Item.Command)"
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
        throw "Identificador de ajuste inválido: $Id"
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

        # A Aparência achada na busca: o foco do teclado vai para a opção marcada, como depois de trocar o tema.
        $script:AppearanceRefocus = ($focus.Section -eq "appearance")

        try {
            Show-GuiPage -Id ([string]$Item.Command) -FocusTweak $focus.TweakId
        }
        finally {
            $script:AppearanceRefocus = $false
        }

        if ($null -ne $script:AppearanceFocusTarget) {
            [void]$script:AppearanceFocusTarget.Focus()
            $script:AppearanceFocusTarget = $null
        }

        return
    }

    try {
        Start-GuiAction -Label $Item.Label -Command (Get-GuiNavCommand -Item $Item) -RequiresAdmin ([bool]$Item.RequiresAdmin) -NavId ([string]$Item.Id)
    }
    catch {
        [void](Show-GuiMessage -Text $_.Exception.Message -Icon Error)
    }
}

function New-GuiActionCard {
    param (
        [Parameter(Mandatory)]$Item,

        # Texto discreto acima do título (por exemplo, a página, nos resultados da busca).
        [string]$Context = "",

        # O primeiro resultado da busca: a tecla "Enter" no canto diz que o Enter da caixa abre este.
        [switch]$EnterHint
    )

    # O destaque (ícone cheio e a etiqueta "Recomendado") marca o caminho recomendado de uma página. Os atalhos do Início
    # usam outro cartão (New-GuiQuickActionCard), sem destaque: lá o caminho recomendado é o botão da nota de saúde.
    $accent = [bool]$Item.Accent

    $button = New-Object System.Windows.Controls.Button
    $button.Style = $window.FindResource("CardButton")
    $button.Tag = $Item
    $button.MinHeight = 148

    # A descrição já aparece no cartão; o leitor de tela recebe título, de onde vem (na busca) e descrição juntos, e
    # também o que o cartão mostra em etiqueta e nota ("Recomendado", "Abre no Windows", "Pede Administrador ao
    # executar"): sem isso, quem usa o leitor de tela só descobre a janela do Windows ou o aviso de Administrador depois.
    $spoken = $(if ($Context) { "$($Item.Label), $Context. $($Item.Description)" } else { "$($Item.Label). $($Item.Description)" })
    if ([bool]$Item.Accent) { $spoken += ". Recomendado" }
    if ($Item.Kind -eq "Shortcut") { $spoken += ". Abre no Windows" }
    elseif ($Item.RequiresAdmin -and -not $script:IsAdmin) { $spoken += ". Pede Administrador ao executar" }
    Set-GuiAutomationName -Element $button -Name $spoken

    if ($EnterHint) {
        [System.Windows.Automation.AutomationProperties]::SetHelpText($button, "Primeiro resultado: o Enter na caixa de busca abre este")
    }

    $stack = New-Object System.Windows.Controls.StackPanel

    # No alto, o ícone do assunto; o cartão de destaque (o caminho recomendado da página) tem o ícone cheio e a etiqueta.
    $top = New-Object System.Windows.Controls.DockPanel
    $top.LastChildFill = $false

    $tile = New-Object System.Windows.Controls.Border
    $tile.Width = 38
    $tile.Height = 38
    $tile.CornerRadius = New-Object System.Windows.CornerRadius 10
    $tile.Background = New-GuiBrush $(if ($accent) { $script:Theme.Accent } else { $script:Theme.AccentCard })
    $tile.Child = New-GuiIcon -Name (Get-WinForgeIconName -Id ([string]$Item.Id)) -Size 20 -Color $(if ($accent) { $script:Theme.OnAccent } else { $script:Theme.AccentText })
    Set-GuiDock -Element $tile -Side "Left"
    [void]$top.Children.Add($tile)

    if ($accent) {
        $chip = New-GuiChip -Text "Recomendado"
        Set-GuiDock -Element $chip -Side "Right"
        [void]$top.Children.Add($chip)
    }

    if ($EnterHint) {
        $key = New-GuiKeyChip -Text "Enter"
        if ($accent) { $key.Margin = New-Object System.Windows.Thickness (0, 0, 6, 0) }
        Set-GuiDock -Element $key -Side "Right"
        [void]$top.Children.Add($key)
    }

    [void]$stack.Children.Add($top)

    if (-not [string]::IsNullOrEmpty($Context)) {
        $where = New-GuiText -Text $Context -Size 12 -Color $script:Theme.Dim
        $where.Margin = New-Object System.Windows.Thickness (0, 12, 0, 0)
        [void]$stack.Children.Add($where)
    }

    $title = New-GuiText -Text $Item.Label -Size 15 -Color $script:Theme.Text -Bold $true
    $title.Margin = New-Object System.Windows.Thickness (0, $(if ([string]::IsNullOrEmpty($Context)) { 14 } else { 2 }), 0, 0)
    [void]$stack.Children.Add($title)

    $description = New-GuiText -Text $Item.Description -Size 13 -Color $script:Theme.Muted
    $description.Margin = New-Object System.Windows.Thickness (0, 4, 0, 0)
    [void]$stack.Children.Add($description)

    $note = $null

    if ($Item.Kind -eq "Shortcut") {
        $note = New-GuiNote -Text "Abre no Windows" -Icon "external"
    }
    elseif ($Item.RequiresAdmin -and -not $script:IsAdmin) {
        $note = New-GuiNote -Text "Pede Administrador ao executar" -Icon "admin"
    }

    if ($null -ne $note) {
        $note.Margin = New-Object System.Windows.Thickness (0, 12, 0, 0)
        [void]$stack.Children.Add($note)
    }

    $button.Content = $stack
    $button.Add_Click({
        param ($sender, $eventArgs)
        Invoke-GuiNavItem -Item $sender.Tag
    })

    return $button
}

function Set-GuiCardWidth {
    <#
    Liga a largura de um cartão à da grade da página (os recursos CardWidth e WideCardWidth da janela, que
    Update-GuiContentWidth ajusta ao tamanho dela): a mudança de largura da janela alcança os cartões que já estão na
    tela. -Wide: meia linha (os atalhos de "Por onde começar"). Os cartões com o estilo CardButton já seguem CardWidth.
    #>
    param (
        [Parameter(Mandatory)]$Element,
        [switch]$Wide
    )

    $key = $(if ($Wide) { "WideCardWidth" } else { "CardWidth" })

    try {
        $Element.SetResourceReference([System.Windows.FrameworkElement]::WidthProperty, $key)
    }
    catch {
        $Element.Width = $(if ($Wide) { [double]$script:WideCardWidth } else { [double]$script:CardWidth })
    }
}

function New-GuiFactCard {
    # Cartão de informação do Início: ícone, nome, o valor em destaque e um complemento embaixo. Todos têm a mesma altura e
    # cada texto ocupa uma linha (o que não cabe termina em "..." e aparece inteiro ao passar o mouse), para as fileiras
    # ficarem alinhadas. Com destino (Target), o cartão é um botão (com a seta) que leva à tela do assunto.
    param (
        [Parameter(Mandatory)][string]$Id,
        [Parameter(Mandatory)][string]$Label
    )

    $row = New-Object System.Windows.Controls.DockPanel

    $tile = New-Object System.Windows.Controls.Border
    $tile.Width = 32
    $tile.Height = 32
    $tile.CornerRadius = New-Object System.Windows.CornerRadius 8
    $tile.Background = New-GuiBrush $script:Theme.Inset
    $tile.Margin = New-Object System.Windows.Thickness (0, 0, 12, 0)
    $tile.VerticalAlignment = "Center"
    $tile.Child = New-GuiIcon -Name (Get-WinForgeIconName -Id "fact.$Id") -Size 17 -Color $script:Theme.Muted
    Set-GuiDock -Element $tile -Side "Left"
    [void]$row.Children.Add($tile)

    $target = Get-WinForgeHomeFactTarget -Id $Id
    $item = $null

    if (-not [string]::IsNullOrEmpty($target)) { $item = Get-WinForgeNavItem -Id $target }

    if ($null -ne $item) {
        $chevron = New-GuiIcon -Name "chevron-right" -Size 14 -Color $script:Theme.Dim
        $chevron.Margin = New-Object System.Windows.Thickness (8, 0, 0, 0)
        Set-GuiDock -Element $chevron -Side "Right"
        [void]$row.Children.Add($chevron)
    }

    $stack = New-Object System.Windows.Controls.StackPanel
    $stack.VerticalAlignment = "Center"

    $name = New-GuiText -Text $Label -Size 12 -Color $script:Theme.Dim
    $value = New-GuiText -Text "Lendo..." -Size 14 -Color $script:Theme.Dim -Bold $true
    $detail = New-GuiText -Text "" -Size 12 -Color $script:Theme.Muted
    $detail.Visibility = "Collapsed"

    foreach ($line in @($name, $value, $detail)) {
        $line.TextWrapping = "NoWrap"
        $line.TextTrimming = "CharacterEllipsis"
        [void]$stack.Children.Add($line)
    }

    [void]$row.Children.Add($stack)

    if ($null -ne $item) {
        $card = New-Object System.Windows.Controls.Button
        $card.Style = $window.FindResource("CardButton")
        $card.Tag = $item
        $card.Content = $row

        # O estilo dos cartões de ação alinha o conteúdo no alto; aqui ele ocupa a altura toda, e o texto fica no meio
        # (com ou sem a segunda linha), como nos cartões que só informam.
        $card.VerticalContentAlignment = "Stretch"
        $card.Padding = New-Object System.Windows.Thickness (14, 10, 14, 10)
        Set-GuiAutomationName -Element $card -Name "$($Label): lendo. Abre: $($item.Label)"
        $card.Add_Click({
            param ($sender, $eventArgs)
            Invoke-GuiNavItem -Item $sender.Tag
        })
    }
    else {
        $card = New-GuiPanelBorder -Padding (New-Object System.Windows.Thickness (14, 10, 14, 10)) -Content $row
        $card.Margin = New-Object System.Windows.Thickness (0, 0, 12, 12)
        Set-GuiAutomationName -Element $card -Name "$($Label): lendo"
    }

    # A largura acompanha a da página (Update-GuiContentWidth), como a dos outros cartões.
    Set-GuiCardWidth -Element $card
    $card.Height = 80

    return [PSCustomObject]@{ Card = $card; Value = $value; Detail = $detail; Opens = $(if ($null -ne $item) { [string]$item.Label } else { "" }) }
}

function New-GuiQuickActionCard {
    # Um atalho de "Por onde começar": da altura dos cartões de Seu PC e da largura de meia linha da página, para que os
    # quatro fiquem em dois por dois (um por linha, na página de uma coluna só) e o nome da ação caiba inteiro. O ícone em destaque, o nome numa linha e a frase do que faz em até duas (inteira ao passar o
    # mouse). Uma ação que pede Administrador mostra o escudo no lugar da seta. O clique faz o mesmo que o cartão da página.
    param ([Parameter(Mandatory)]$Item)

    $needsAdmin = ([bool]$Item.RequiresAdmin -and -not $script:IsAdmin)
    $row = New-Object System.Windows.Controls.DockPanel

    $tile = New-Object System.Windows.Controls.Border
    $tile.Width = 32
    $tile.Height = 32
    $tile.CornerRadius = New-Object System.Windows.CornerRadius 8
    $tile.Background = New-GuiBrush $script:Theme.AccentCard
    $tile.Margin = New-Object System.Windows.Thickness (0, 0, 12, 0)
    $tile.VerticalAlignment = "Center"
    $tile.Child = New-GuiIcon -Name (Get-WinForgeIconName -Id ([string]$Item.Id)) -Size 17 -Color $script:Theme.AccentText
    Set-GuiDock -Element $tile -Side "Left"
    [void]$row.Children.Add($tile)

    $mark = New-GuiIcon -Name $(if ($needsAdmin) { "admin" } else { "chevron-right" }) -Size 14 -Color $script:Theme.Dim
    $mark.Margin = New-Object System.Windows.Thickness (8, 0, 0, 0)
    Set-GuiDock -Element $mark -Side "Right"
    [void]$row.Children.Add($mark)

    $stack = New-Object System.Windows.Controls.StackPanel
    $stack.VerticalAlignment = "Center"

    $title = New-GuiText -Text $Item.Label -Size 14 -Bold $true
    $title.TextWrapping = "NoWrap"
    $title.TextTrimming = "CharacterEllipsis"
    [void]$stack.Children.Add($title)

    # Duas linhas de 12 pontos; uma frase maior termina em reticências na segunda.
    $about = New-GuiText -Text $Item.Description -Size 12 -Color $script:Theme.Muted
    $about.TextWrapping = "Wrap"
    $about.TextTrimming = "CharacterEllipsis"
    $about.MaxHeight = 33
    $about.Margin = New-Object System.Windows.Thickness (0, 1, 0, 0)
    [void]$stack.Children.Add($about)

    [void]$row.Children.Add($stack)

    $card = New-Object System.Windows.Controls.Button
    $card.Style = $window.FindResource("CardButton")
    $card.Tag = $Item
    $card.Content = $row
    $card.VerticalContentAlignment = "Stretch"
    Set-GuiCardWidth -Element $card -Wide
    $card.Height = 80
    $card.Padding = New-Object System.Windows.Thickness (14, 10, 14, 10)

    $note = $(if ($needsAdmin) { "Pede Administrador ao executar" } else { "" })
    $card.ToolTip = $(if ($note) { "$($Item.Description)`n$note" } else { [string]$Item.Description })
    Set-GuiAutomationName -Element $card -Name $(if ($note) { "$($Item.Label). $($Item.Description). $note" } else { "$($Item.Label). $($Item.Description)" })

    $card.Add_Click({
        param ($sender, $eventArgs)
        Invoke-GuiNavItem -Item $sender.Tag
    })

    return $card
}

function Show-GuiHomePage {
    # Monta o Início. -Rerender (troca de tema) refaz os controles sem ler o PC de novo: mostra a última leitura (mesmo
    # depois dos 30 segundos, com a hora dela) ou continua a leitura em andamento de onde ela estava.
    param ([switch]$Rerender)

    # Sem a frase embaixo do título: "Seu PC" e "Por onde começar" já dizem o que a página tem, e a nota sobe.
    $pageTitle.Text = "Início"
    $pageSubtitle.Text = ""
    $contentPanel.Children.Clear()
    $script:HomeFacts = @{}
    $script:HomeCards = @{}
    $script:HomeFactInfo = @{}

    # Uma leitura que ficou pela metade em outra visita não vale mais: os cartões abaixo são novos. Na troca de tema, a
    # leitura em andamento continua a mesma (e não fica solta se a montagem falhar) e passa para os cartões novos.
    $pending = $script:HomeRead
    if (-not $Rerender) { $script:HomeRead = $null }

    # A hora da leitura e o Atualizar entram na nota de saúde (Update-GuiHealthCard), que guarda o texto e o estado.
    if (-not $Rerender) { $script:HomeStamp = @{ Text = (Get-GuiHomeReadingText); CanRefresh = $false; ReadAt = $null } }

    # Avisos (por exemplo, WinForge elevado com outra conta) entram aqui quando a leitura do sistema termina.
    $script:HomeBanner = New-Object System.Windows.Controls.StackPanel
    [void]$contentPanel.Children.Add($script:HomeBanner)

    # A nota de saúde também chega com a leitura; até lá o cartão mostra que está calculando.
    $script:HomeHealth = New-Object System.Windows.Controls.StackPanel
    $script:HomeHealth.Margin = New-Object System.Windows.Thickness (0, 0, 12, 0)
    [void]$contentPanel.Children.Add($script:HomeHealth)
    Update-GuiHealthCard -Health $null

    [void]$contentPanel.Children.Add((New-GuiSectionHeading -Text "Seu PC"))

    $facts = New-Object System.Windows.Controls.WrapPanel
    $labels = Get-WinForgeHomeFactLabels
    $optional = @(Get-WinForgeHomeOptionalFacts)

    foreach ($id in $labels.Keys) {
        $fact = New-GuiFactCard -Id $id -Label $labels[$id]
        $script:HomeFacts[$id] = $fact.Value
        $script:HomeCards[$id] = $fact.Card
        $script:HomeFactInfo[$id] = [PSCustomObject]@{ Label = [string]$labels[$id]; Opens = $fact.Opens; Detail = $fact.Detail }

        # Um cartão que só existe em alguns PCs (a bateria) só aparece quando a leitura confirma; antes disso, num desktop
        # ele apareceria em "Lendo..." e sumiria.
        if ($id -in $optional) { $fact.Card.Visibility = "Collapsed" }

        [void]$facts.Children.Add($fact.Card)
    }

    [void]$contentPanel.Children.Add($facts)

    $heading = New-GuiSectionHeading -Text "Por onde começar"
    $heading.Margin = New-Object System.Windows.Thickness (0, 12, 0, 12)
    [void]$contentPanel.Children.Add($heading)

    $shortcuts = New-Object System.Windows.Controls.WrapPanel

    foreach ($item in @(Get-WinForgeHomeActions)) {
        [void]$shortcuts.Children.Add((New-GuiQuickActionCard -Item $item))
    }

    [void]$contentPanel.Children.Add($shortcuts)

    if ($Rerender -and $null -ne $pending) {
        # Numa atualização, os cartões que a leitura nova ainda não alcançou continuam com a anterior (e a nota também).
        if ($pending.Refresh -and $null -ne $script:HomeLastSnapshot) {
            try { Show-GuiHomeResult -Snapshot $script:HomeLastSnapshot } catch { $script:HomeLastSnapshot = $null }
        }

        foreach ($fact in @($pending.Facts)) { Set-GuiHomeFact -Fact $fact }

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
    # visita começa com os cartões em "Lendo...".
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
            Start-GuiHomeRead
            return
        }

        if ($stale) { Start-GuiHomeRead -Refresh }
        return
    }

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
    if ($null -ne $script:HomeRefreshButton) { $script:HomeRefreshButton.IsEnabled = $CanRefresh }
}

function New-GuiHomeStampBar {
    # A linha embaixo da frase da nota de saúde: a hora da leitura e o botão de ler de novo, só o ícone (F5 faz o mesmo),
    # com o texto e o estado guardados (HomeStamp). Discreta: o que a página pede ao olhar é a nota e o que fazer.
    $bar = New-Object System.Windows.Controls.StackPanel
    $bar.Orientation = "Horizontal"
    $bar.HorizontalAlignment = "Left"
    $bar.Margin = New-Object System.Windows.Thickness (0, 2, 0, 0)

    $stamp = New-GuiText -Text ([string]$script:HomeStamp.Text) -Size 12 -Color $script:Theme.Dim
    $stamp.VerticalAlignment = "Center"
    $stamp.TextWrapping = "NoWrap"
    [void]$bar.Children.Add($stamp)

    $refresh = New-Object System.Windows.Controls.Button
    $refresh.Style = $window.FindResource("GhostButton")
    $refresh.Content = New-GuiIcon -Name "refresh" -Size 14 -Color $script:Theme.Muted
    $refresh.Padding = New-Object System.Windows.Thickness (6, 4, 6, 4)
    $refresh.Margin = New-Object System.Windows.Thickness (4, 0, 0, 0)
    $refresh.VerticalAlignment = "Center"
    $refresh.ToolTip = "Ler o PC de novo (F5)"
    $refresh.IsEnabled = [bool]$script:HomeStamp.CanRefresh
    Set-GuiAutomationName -Element $refresh -Name "Ler o estado do PC de novo"
    $refresh.Add_Click({ Request-GuiHomeRefresh })
    [void]$bar.Children.Add($refresh)

    $script:HomeRefreshButton = $refresh
    $script:HomeStampText = $stamp
    $script:HomeStampBar = $bar

    return $bar
}

function Get-GuiHomeStampText {
    # "Atualizado às 14:20" para uma leitura de hoje; de outro dia, com o dia ("ontem às", "em 28/10 às"): a janela pode
    # ficar aberta de um dia para o outro, e só a hora enganaria.
    param ([Parameter(Mandatory)][datetime]$ReadAt, [datetime]$Now = (Get-Date))

    $culture = [System.Globalization.CultureInfo]::InvariantCulture
    $time = $ReadAt.ToString("HH:mm", $culture)

    if ($ReadAt.Date -eq $Now.Date) { return "Atualizado às $time" }
    if ($ReadAt.Date -eq $Now.Date.AddDays(-1)) { return "Atualizado ontem às $time" }

    return "Atualizado em $($ReadAt.ToString('dd/MM', $culture)) às $time"
}

function Set-GuiHomeFact {
    # Mostra um fato do Início no cartão dele (Set-GuiFactCardText).
    param ([Parameter(Mandatory)]$Fact)

    $id = [string]$Fact.Id

    # O que o Início leu da bateria vale também para a página Diagnóstico: o cartão visível diz que há bateria; "Sem
    # bateria" (PC de mesa, nenhuma bateria ou um nobreak) diz que não há. Uma leitura que não terminou não decide nada.
    if ($id -eq "battery") {
        if ([bool]$Fact.Visible) { $script:HasBattery = $true }
        elseif ([string]$Fact.Text -eq "Sem bateria") { $script:HasBattery = $false }
    }

    if (-not $script:HomeFacts.ContainsKey($id)) { return }

    $info = $script:HomeFactInfo[$id]
    Set-GuiFactCardText -Card $script:HomeCards[$id] -Value $script:HomeFacts[$id] -Detail $info.Detail -Label $info.Label -Opens $info.Opens -Fact $Fact
}

function Set-GuiFactCardText {
    # Mostra um fato num cartão de informação (New-GuiFactCard): o valor (na cor do nível), o complemento, se o cartão
    # aparece, a frase inteira ao passar o mouse e o nome que o leitor de tela fala.
    param (
        [Parameter(Mandatory)]$Card,
        [Parameter(Mandatory)]$Value,
        [Parameter(Mandatory)]$Detail,
        [Parameter(Mandatory)][string]$Label,
        [AllowEmptyString()][string]$Opens = "",
        [Parameter(Mandatory)]$Fact
    )

    $colors = @{ Normal = $script:Theme.Text; Ok = $script:Theme.Ok; Warn = $script:Theme.Warn; Muted = $script:Theme.Muted }
    $level = [string]$Fact.Level
    $text = [string]$Fact.Text
    $shown = [string](Get-WinForgeJsonValue -Object $Fact -Name "Value" -Default $text)
    $more = [string](Get-WinForgeJsonValue -Object $Fact -Name "Detail" -Default "")

    $Value.Text = $shown
    $Value.Foreground = New-GuiBrush $(if ($colors.ContainsKey($level)) { $colors[$level] } else { $script:Theme.Text })
    $Detail.Text = $more
    $Detail.Visibility = $(if ([string]::IsNullOrEmpty($more)) { "Collapsed" } else { "Visible" })
    $Card.ToolTip = $text

    # Cartões que não se aplicam a este PC (bateria em desktop) saem da tela.
    $Card.Visibility = $(if ($Fact.Visible) { "Visible" } else { "Collapsed" })

    # O leitor de tela lê o nome do botão no lugar do conteúdo: a frase inteira precisa estar nele.
    $name = "$($Label): $text"
    if (-not [string]::IsNullOrEmpty($Opens)) { $name += ". Abre: $($Opens)" }
    Set-GuiAutomationName -Element $Card -Name $name
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
    # (Verificar vírus) sai do Início e da página Segurança. Sem leitura, fica como estava.
    foreach ($fact in @($Snapshot.Facts)) {
        if ($null -ne $fact -and [string](Get-WinForgeJsonValue -Object $fact -Name "Id" -Default "") -eq "security") {
            Save-GuiAntivirusMode -Mode ([string](Get-WinForgeJsonValue -Object $fact -Name "AntivirusMode" -Default ""))
        }
    }

    $failed = [bool](Get-WinForgeJsonValue -Object $Snapshot -Name "Failed" -Default $false)

    if ($failed) { Update-GuiHealthCard -Failed } else { Update-GuiHealthCard -Health $Snapshot.Health }

    $script:HomeBanner.Children.Clear()
    Add-GuiHomeNotices -Notices $Snapshot.Notices

    if ($failed) {
        Set-GuiHomeStamp -Text "A leitura não terminou" -CanRefresh $true
    }
    else {
        Set-GuiHomeStamp -Text (Get-GuiHomeStampText -ReadAt $Snapshot.ReadAt) -CanRefresh $true -ReadAt $Snapshot.ReadAt
    }

    # O leitor de tela ouve a frase nova da nota, que chegou sem a pessoa pedir.
    if ($null -ne $script:HomeHeadline) { Send-GuiAnnouncement -Element $script:HomeHeadline }
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

    if ($Refresh) { return "Atualizando..." }

    return "Lendo o PC..."
}

function Stop-GuiHomeRead {
    # Uma falha que a leitura não previu (no temporizador ou entre uma etapa e outra) não deixa o Início preso em "Lendo"
    # com o botão de ler de novo desligado: a leitura para, e a hora diz isso, com o botão ligado.
    $script:HomeRead = $null
    $script:HomeReaderOwner = $null
    $script:HomeReaderWaiting = $null

    try { Set-GuiHomeStamp -Text "A leitura não terminou" -CanRefresh $true } catch { Write-Verbose "Início: $($_.Exception.Message)" }
}

function Start-GuiHomeRead {
    # Começa a ler o estado do PC para os cartões que estão na tela. Cada etapa roda em um tique do temporizador: a
    # janela responde entre uma e outra e cada cartão aparece assim que a etapa dele termina. -Refresh: os cartões já
    # mostram a leitura anterior, que a nova troca no lugar.
    param ([switch]$Refresh)

    $steps = @(Get-WinForgeHomeSteps)

    $script:HomeRead = [PSCustomObject]@{
        Steps = $steps; Next = 0; Facts = @(); Notices = @(); Issues = @(); Unread = @(); Failed = $false
        Version = $script:HomeCacheVersion; Refresh = [bool]$Refresh
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
        # Um cartão cuja etapa falhou por inteiro não fica em "Lendo..." para sempre (o da bateria, que só existe em
        # alguns PCs, continua escondido); se ele entra na nota, a nota diz que ele ficou de fora.
        $known = @($read.Facts | ForEach-Object { [string]$_.Id })
        $optional = @(Get-WinForgeHomeOptionalFacts)
        $scored = @(Get-WinForgeHomeScoredFacts)
        $unread = @($read.Unread)
        $missing = @()

        # Esses cartões também entram na leitura guardada: mostrada de novo (na volta ao Início ou na troca de tema), ela
        # diz "Não foi possível ler", e não "Lendo...".
        foreach ($id in @($script:HomeFacts.Keys)) {
            if ($id -notin $known) {
                $fact = [PSCustomObject]@{ Id = $id; Text = "Não foi possível ler"; Level = "Muted"; Visible = ($id -notin $optional) }
                Set-GuiHomeFact -Fact $fact
                $missing += $fact
                if ($id -in $scored) { $unread += $script:HomeFactInfo[$id].Label }
            }
        }

        $snapshot = [PSCustomObject]@{
            Facts   = @(@($read.Facts) + $missing)
            Notices = @($read.Notices)
            Health  = $null
            ReadAt  = (Get-Date)
            Failed  = $false
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

        Set-GuiHomeStamp -Text "A leitura não terminou" -CanRefresh $true

        try { Update-GuiHealthCard -Failed } catch { Write-Verbose "Nota de saúde: $($_.Exception.Message)" }
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

function New-GuiScoreRing {
    # O anel da nota de saúde: o trilho inteiro e, por cima, o arco proporcional à nota, com o número no meio. Score
    # negativo = ainda sem nota (só o trilho e um traço).
    param (
        [int]$Score,
        [string]$Color
    )

    $size = 124.0
    $thickness = 10.0
    $radius = ($size - $thickness) / 2
    $center = $size / 2

    $grid = New-Object System.Windows.Controls.Grid
    $grid.Width = $size
    $grid.Height = $size

    # O trilho tem um tom claro da cor da nota: com a nota baixa, o anel quase vazio continua dizendo "vermelho", e não
    # parece cinza de desligado. Sem nota, o trilho neutro.
    $trackColor = $script:Theme.Track
    if ($Score -ge 0 -and $Color -match '^#[0-9A-Fa-f]{6}$') { $trackColor = "#38$($Color.Substring(1))" }

    $track = New-Object System.Windows.Shapes.Ellipse
    $track.Stroke = New-GuiBrush $trackColor
    $track.StrokeThickness = $thickness
    [void]$grid.Children.Add($track)

    $fraction = [Math]::Max(0, [Math]::Min(100, $Score)) / 100.0

    if ($Score -ge 100) {
        $full = New-Object System.Windows.Shapes.Ellipse
        $full.Stroke = New-GuiBrush $Color
        $full.StrokeThickness = $thickness
        [void]$grid.Children.Add($full)
    }
    elseif ($fraction -gt 0) {
        # O arco começa no alto (12 horas) e anda no sentido horário.
        $angle = 360.0 * $fraction
        $radians = ($angle - 90.0) * [Math]::PI / 180.0

        $figure = New-Object System.Windows.Media.PathFigure
        $figure.StartPoint = New-Object System.Windows.Point ($center, ($center - $radius))

        $arc = New-Object System.Windows.Media.ArcSegment
        $arc.Point = New-Object System.Windows.Point (($center + $radius * [Math]::Cos($radians)), ($center + $radius * [Math]::Sin($radians)))
        $arc.Size = New-Object System.Windows.Size ($radius, $radius)
        $arc.IsLargeArc = ($angle -gt 180.0)
        $arc.SweepDirection = "Clockwise"
        [void]$figure.Segments.Add($arc)

        $geometry = New-Object System.Windows.Media.PathGeometry
        [void]$geometry.Figures.Add($figure)

        $path = New-Object System.Windows.Shapes.Path
        $path.Data = $geometry
        $path.Stroke = New-GuiBrush $Color
        $path.StrokeThickness = $thickness
        $path.StrokeStartLineCap = "Round"
        $path.StrokeEndLineCap = "Round"
        [void]$grid.Children.Add($path)
    }

    $middle = New-Object System.Windows.Controls.StackPanel
    $middle.VerticalAlignment = "Center"
    $middle.HorizontalAlignment = "Center"

    $number = New-GuiText -Text $(if ($Score -lt 0) { "–" } else { "$Score" }) -Size 36 -Bold $true
    try { [System.Windows.Media.TextOptions]::SetTextFormattingMode($number, "Ideal") } catch { Write-Verbose "Texto: $($_.Exception.Message)" }
    $number.HorizontalAlignment = "Center"
    $number.TextAlignment = "Center"
    [void]$middle.Children.Add($number)

    $scale = New-GuiText -Text "de 100" -Size 12 -Color $script:Theme.Dim
    $scale.HorizontalAlignment = "Center"
    [void]$middle.Children.Add($scale)

    [void]$grid.Children.Add($middle)

    return $grid
}

function New-GuiHealthButtons {
    # Os dois caminhos para cuidar do PC, sempre à mão: o Otimizar (a manutenção completa e guiada) e Verificar vírus. Eles
    # não dependem da leitura: aparecem também enquanto a nota é calculada e quando ela não pôde ser calculada. O Otimizar
    # é o botão principal só quando nenhum ponto pede atenção: com pontos, o principal é o do primeiro deles, que resolve
    # o que a nota acusa (uma tela, um botão em destaque). Verificar vírus usa o Windows Defender: quando a última leitura
    # viu outro antivírus protegendo o PC, ou o Defender desligado, em modo passivo ou sem resposta, ele não aparece
    # (a verificação falharia, e o ponto da nota já leva à Segurança do Windows).
    param ([bool]$Primary = $true)

    $buttons = New-Object System.Windows.Controls.WrapPanel
    $buttons.Margin = New-Object System.Windows.Thickness (0, 16, 0, 0)
    $mode = [string](Get-Variable -Name AntivirusMode -Scope Script -ValueOnly -ErrorAction SilentlyContinue)
    $noDefender = ($mode -in @("Other", "Off", "Passive", "Unavailable"))

    foreach ($entry in @(@{ Id = "maintenance.recommended"; Kind = $(if ($Primary) { "Primary" } else { "Secondary" }); Icon = "sparkles" }, @{ Id = "security.scan"; Kind = "Secondary"; Icon = "search" })) {
        if ($noDefender -and $entry.Id -eq "security.scan") { continue }

        $navItem = Get-WinForgeNavItem -Id $entry.Id

        if ($null -eq $navItem) { continue }

        $go = New-GuiButton -Text $navItem.Label -Kind $entry.Kind -Icon $entry.Icon -Tag $navItem
        $go.Margin = New-Object System.Windows.Thickness (0, 0, 10, 0)
        $go.Add_Click({
            param ($sender, $eventArgs)
            Invoke-GuiNavItem -Item $sender.Tag
        })
        [void]$buttons.Children.Add($go)
    }

    return $buttons
}

function Update-GuiHealthCard {
    # A nota de saúde: o anel com a nota, a frase do estado, a hora da leitura (com o botão de ler de novo), os botões
    # Otimizar e Verificar vírus e, embaixo, cada ponto de atenção com o botão que o resolve. Sem nota (Health $null), o
    # cartão mostra que a leitura está em andamento; com -Failed, que a nota não pôde ser montada.
    param (
        $Health,
        [switch]$Failed
    )

    $script:HomeHealth.Children.Clear()

    $border = New-GuiPanelBorder -Radius 16 -Padding (New-Object System.Windows.Thickness (24, 22, 24, 22))

    $stack = New-Object System.Windows.Controls.StackPanel

    $grid = New-Object System.Windows.Controls.Grid
    $ringColumn = New-Object System.Windows.Controls.ColumnDefinition
    $ringColumn.Width = [System.Windows.GridLength]::Auto
    $textColumn = New-Object System.Windows.Controls.ColumnDefinition
    [void]$grid.ColumnDefinitions.Add($ringColumn)
    [void]$grid.ColumnDefinitions.Add($textColumn)

    $text = New-Object System.Windows.Controls.StackPanel
    $text.VerticalAlignment = "Center"

    $issues = @()
    $line = ""
    $primary = $true

    # Nada do que forma a nota foi lido, e nenhum ponto apareceu: um "100" não diria nada sobre o PC.
    $unknown = ($null -ne $Health -and -not (Test-WinForgeHealthKnown -Health $Health))

    if ($Failed -or $unknown -or $null -eq $Health) {
        $ring = New-GuiScoreRing -Score -1 -Color $script:Theme.Dim

        if ($Failed) {
            $title = "Não foi possível calcular a nota"
            $line = "Os cartões abaixo mostram o que foi lido. Tente ler de novo."
            $spoken = "Saúde do PC: não foi possível calcular a nota"
        }
        elseif ($unknown) {
            $title = "Não foi possível avaliar o PC"
            $line = "Nenhuma das leituras que formam a nota respondeu. Tente ler de novo."
            $spoken = "Saúde do PC: não foi possível avaliar"
        }
        else {
            # "Lendo", e não "Verificando": verificar é com Verificar o PC e Verificar vírus, que mudam o PC.
            $title = "Lendo o estado do PC..."
            $line = "Cada cartão abaixo aparece assim que é lido."
            $spoken = "Saúde do PC: lendo o estado do PC"
        }
    }
    else {
        $colors = $script:LevelColors[$(if ($Health.Level -eq "Bad") { "Bad" } elseif ($Health.Level -eq "Warn") { "Warn" } else { "Ok" })]
        $ring = New-GuiScoreRing -Score $Health.Score -Color $colors.Dot
        $issues = @($Health.Issues | Where-Object { $null -ne $_ })

        $title = Get-WinForgeHealthHeadline -Health $Health

        # Com os pontos à vista logo abaixo, a frase não os conta de novo: fica só o que não pôde ser lido.
        $line = Get-WinForgeHealthSummary -Health $Health -WithoutCount:($issues.Count -gt 0)
        $spoken = "Saúde do PC: nota $($Health.Score) de 100, $($Health.Label). $(Get-WinForgeHealthSummary -Health $Health)"
        $primary = ($issues.Count -eq 0)
    }

    $headline = New-GuiText -Text $title -Size 22 -Bold $true
    Set-GuiAutomationName -Element $headline -Name $spoken
    try { [System.Windows.Automation.AutomationProperties]::SetLiveSetting($headline, [System.Windows.Automation.AutomationLiveSetting]::Polite) } catch { Write-Verbose "Leitor de tela: $($_.Exception.Message)" }
    [void]$text.Children.Add($headline)
    $script:HomeHeadline = $headline

    # A hora da leitura e o botão de ler de novo, discretos, logo abaixo da frase.
    [void]$text.Children.Add((New-GuiHomeStampBar))

    if (-not [string]::IsNullOrEmpty($line)) {
        $lineText = New-GuiText -Text $line -Size 14 -Color $script:Theme.Muted
        $lineText.Margin = New-Object System.Windows.Thickness (0, 4, 0, 0)
        [void]$text.Children.Add($lineText)
    }

    $buttonRow = New-GuiHealthButtons -Primary $primary
    $buttonRow.Margin = New-Object System.Windows.Thickness (0, 14, 0, 0)
    [void]$text.Children.Add($buttonRow)

    Set-GuiAutomationName -Element $border -Name $spoken

    $ring.Margin = New-Object System.Windows.Thickness (0, 0, 28, 0)
    $ring.VerticalAlignment = "Center"
    [System.Windows.Controls.Grid]::SetColumn($ring, 0)
    [void]$grid.Children.Add($ring)

    [System.Windows.Controls.Grid]::SetColumn($text, 1)
    [void]$grid.Children.Add($text)

    [void]$stack.Children.Add($grid)

    if ($issues.Count -gt 0) {
        $rule = New-Object System.Windows.Controls.Border
        $rule.Height = 1
        $rule.Background = New-GuiBrush $script:Theme.Line
        $rule.Margin = New-Object System.Windows.Thickness (0, 20, 0, 6)
        [void]$stack.Children.Add($rule)
    }

    $first = $true

    foreach ($issue in $issues) {
        $row = New-Object System.Windows.Controls.DockPanel
        $row.Margin = New-Object System.Windows.Thickness (0, 6, 0, 0)

        # O botão do primeiro ponto (o mais pesado) é o principal da tela; os outros, comuns.
        $fix = New-GuiButton -Text $issue.ButtonText -Kind $(if ($first) { "Primary" } else { "Secondary" }) -Tag $issue
        $first = $false
        $fix.Margin = New-Object System.Windows.Thickness (12, 0, 0, 0)
        $fix.VerticalAlignment = "Center"
        Set-GuiDock -Element $fix -Side "Right"
        # A gravidade não fica só na cor e no desenho do ícone: o leitor de tela ouve "(grave)".
        Set-GuiAutomationName -Element $fix -Name "$($issue.ButtonText): $($issue.Text)$(if ($issue.Severe) { ' (grave)' })"
        $fix.Add_Click({
            param ($sender, $eventArgs)
            Invoke-GuiNextStep -Next ([string]$sender.Tag.Target) -Title ([string]$sender.Tag.ButtonText)
        })
        [void]$row.Children.Add($fix)

        # Um ponto grave (que limita a nota) tem o círculo vermelho; os demais, o triângulo amarelo.
        $glyph = New-GuiIcon -Name $(if ($issue.Severe) { "error-circle" } else { "warning" }) -Size 18 -Color $(if ($issue.Severe) { $script:Theme.Bad } else { $script:Theme.Warn })
        $glyph.Margin = New-Object System.Windows.Thickness (0, 0, 12, 0)
        Set-GuiDock -Element $glyph -Side "Left"
        [void]$row.Children.Add($glyph)

        $issueText = New-GuiText -Text $issue.Text -Size 14
        $issueText.VerticalAlignment = "Center"
        [void]$row.Children.Add($issueText)

        [void]$stack.Children.Add($row)
    }

    Set-GuiPanelContent -Panel $border -Content $stack
    [void]$script:HomeHealth.Children.Add($border)
}

function New-GuiPageStatus {
    # O resumo no alto de uma página (Limpeza, Desempenho e Sobre o WinForge): uma linha por informação, com
    # o rótulo à esquerda. Vem de leituras rápidas (arquivos pequenos do WinForge, o espaço do disco, a memória), então
    # não atrasa a página; se a leitura falhar, a página aparece sem ele.
    param ([Parameter(Mandatory)]$Page)

    $reader = switch ([string]$Page.Id) {
        "cleanup"     { "Get-WinForgeCleanupPageStatus" }
        "performance" { "Get-WinForgePerformancePageStatus" }
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

    if ($rows.Count -eq 0) { return $null }

    $colors = @{ Normal = $script:Theme.Text; Warn = $script:Theme.Warn; Muted = $script:Theme.Muted }
    $border = New-GuiPanelBorder
    $border.Margin = New-Object System.Windows.Thickness (0, 0, 12, 16)
    $stack = New-Object System.Windows.Controls.StackPanel

    foreach ($row in $rows) {
        $line = New-Object System.Windows.Controls.DockPanel
        $line.Margin = New-Object System.Windows.Thickness (0, 3, 0, 3)

        $label = New-GuiText -Text ([string]$row.Label) -Size 13 -Color $script:Theme.Muted
        $label.Width = 160
        Set-GuiDock -Element $label -Side "Left"
        [void]$line.Children.Add($label)

        $level = [string]$row.Level
        [void]$line.Children.Add((New-GuiText -Text ([string]$row.Text) -Size 13.5 -Color $(if ($colors.ContainsKey($level)) { $colors[$level] } else { $script:Theme.Text })))
        [void]$stack.Children.Add($line)
    }

    Set-GuiPanelContent -Panel $border -Content $stack

    return $border
}

function New-GuiMaintenanceFact {
    # O alto da página Manutenção: o cartão "Última manutenção", o mesmo do Início (Read-WinForgeHomeMaintenance, que lê
    # só arquivos pequenos do WinForge, sem consultar o Windows). O clique abre o Histórico de manutenções. Se a leitura
    # falhar, o cartão diz isso, sem impedir a página de abrir.
    $label = "Última manutenção"
    $info = New-GuiFactCard -Id "maintenance" -Label $label
    $fact = $null

    try {
        $fact = @(@((Read-WinForgeHomeMaintenance).Facts) | Where-Object { $null -ne $_ })[0]
    }
    catch {
        Write-Verbose "Última manutenção: $($_.Exception.Message)"
    }

    if ($null -eq $fact) { $fact = [PSCustomObject]@{ Id = "maintenance"; Text = "Não foi possível ler"; Level = "Muted"; Visible = $true } }

    Set-GuiFactCardText -Card $info.Card -Value $info.Value -Detail $info.Detail -Label $label -Opens $info.Opens -Fact $fact

    $panel = New-Object System.Windows.Controls.WrapPanel
    $panel.Margin = New-Object System.Windows.Thickness (0, 0, 0, 4)
    $panel.Tag = "fact"
    [void]$panel.Children.Add($info.Card)

    return $panel
}

function New-GuiAppearanceCard {
    # Sobre o WinForge > Aparência: como o Windows (o padrão), clara ou escura. Vale na hora, sem reabrir a janela.
    $border = New-GuiPanelBorder
    $border.Margin = New-Object System.Windows.Thickness (0, 0, 12, 16)
    $border.Tag = "appearance"

    $row = New-Object System.Windows.Controls.DockPanel

    $segment = New-Object System.Windows.Controls.Border
    $segment.Background = New-GuiBrush $script:Theme.Inset
    $segment.CornerRadius = New-Object System.Windows.CornerRadius 9
    $segment.Padding = New-Object System.Windows.Thickness 2
    $segment.VerticalAlignment = "Center"
    $segment.Margin = New-Object System.Windows.Thickness (16, 0, 0, 0)
    Set-GuiDock -Element $segment -Side "Right"

    $choices = New-Object System.Windows.Controls.StackPanel
    $choices.Orientation = "Horizontal"

    foreach ($option in @(
            @{ Value = "System"; Text = "Automático" },
            @{ Value = "Light"; Text = "Claro" },
            @{ Value = "Dark"; Text = "Escuro" }
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
        Set-GuiAutomationName -Element $button -Name $(if ($selected) { "Aparência: $($option.Text), selecionada" } else { "Aparência: $($option.Text)" })
        if ($selected -and $script:AppearanceRefocus) { $script:AppearanceFocusTarget = $button }

        $button.Add_Click({
            param ($sender, $eventArgs)
            Set-GuiThemePreference -Value ([string]$sender.Tag)
        })
        [void]$choices.Children.Add($button)
    }

    $segment.Child = $choices
    [void]$row.Children.Add($segment)

    $text = New-Object System.Windows.Controls.StackPanel
    $text.VerticalAlignment = "Center"
    [void]$text.Children.Add((New-GuiText -Text "Aparência" -Size 15 -Bold $true))

    $hint = New-GuiText -Text "Automático acompanha o tema claro ou escuro escolhido nas Configurações do Windows." -Size 13 -Color $script:Theme.Muted
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

    $status = $(if ([string]$Page.Id -eq "maintenance") { New-GuiMaintenanceFact } else { New-GuiPageStatus -Page $Page })

    if ($null -ne $status) { [void]$contentPanel.Children.Add($status) }

    if ($Page.Id -eq "app") { [void]$contentPanel.Children.Add((New-GuiAppearanceCard)) }

    # Os cartões vêm em seções ("Liberar espaço", "Ferramentas do Windows"), cada uma com o seu título e a sua grade; uma
    # página sem seções é uma grade só.
    $panel = $null
    $group = $null

    # Com outro antivírus protegendo o PC (o que o Início leu), as ações do Windows Defender não fariam nada: saem da
    # página. Ficam o estado, a auditoria e o aplicativo Segurança do Windows.
    $otherAntivirus = ([string]$Page.Id -eq "security" -and [string](Get-Variable -Name AntivirusMode -Scope Script -ValueOnly -ErrorAction SilentlyContinue) -eq "Other")

    # Num PC sem bateria (o que o Início leu), Saúde da bateria só diria isso: o cartão sai do Diagnóstico.
    $noBattery = ($false -eq (Get-Variable -Name HasBattery -Scope Script -ValueOnly -ErrorAction SilentlyContinue))

    foreach ($item in $Page.Items) {
        if ($otherAntivirus -and [string]$item.Id -in @("security.signatures", "security.scan", "security.full-scan", "security.folder-scan")) { continue }
        if ($noBattery -and [string]$item.Id -eq "diagnostics.battery") { continue }

        # Itens fora da grade (o histórico de manutenções, aberto pelo cartão do alto): a busca e o console chegam neles.
        if ($null -ne $item.PSObject.Properties["Unlisted"] -and [bool]$item.Unlisted) { continue }

        $itemGroup = [string]$item.Group

        if ($null -eq $panel -or $itemGroup -ne $group) {
            if ($itemGroup) {
                [void]$contentPanel.Children.Add((New-GuiGroupHeading -Text $itemGroup -First ($null -eq $panel)))
            }

            $panel = New-Object System.Windows.Controls.WrapPanel
            [void]$contentPanel.Children.Add($panel)
            $group = $itemGroup
        }

        [void]$panel.Children.Add((New-GuiActionCard -Item $item))
    }
}

function New-GuiTweakRow {
    # Uma linha de ajuste dentro do grupo da categoria: nome, descrição e avisos, o estado e a chave liga/desliga.
    param ([Parameter(Mandatory)]$Tweak)

    # Fundo e contorno transparentes; ganham cor quando a busca traz a pessoa até este ajuste (Set-GuiTweakRowHighlight).
    $border = New-GuiOutlinedBorder -Radius 10 -Padding (New-Object System.Windows.Thickness (10, 11, 10, 11))
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
    [void]$text.Children.Add((New-GuiText -Text $Tweak.Name -Size 14 -Bold $true))

    $description = New-GuiText -Text $Tweak.Description -Size 12.5 -Color $script:Theme.Muted
    $description.Margin = New-Object System.Windows.Thickness (0, 2, 0, 0)
    [void]$text.Children.Add($description)

    if (-not [string]::IsNullOrWhiteSpace($Tweak.LaptopNote)) {
        $warning = New-GuiText -Text "Atenção em notebook: $($Tweak.LaptopNote)" -Size 12.5 -Color $script:Theme.Warn
        $warning.Margin = New-Object System.Windows.Thickness (0, 2, 0, 0)
        [void]$text.Children.Add($warning)
    }

    $needsAdmin = ([bool]$Tweak.RequiresAdmin -and -not $script:IsAdmin)

    if ($needsAdmin) {
        $adminNote = New-GuiNote -Text "Pede Administrador ao executar" -Icon "admin"
        $adminNote.Margin = New-Object System.Windows.Thickness (0, 4, 0, 0)
        [void]$text.Children.Add($adminNote)
    }

    [System.Windows.Controls.Grid]::SetColumn($text, 0)
    [void]$grid.Children.Add($text)

    # A chave mostra o recurso do Windows como ele está agora (lido na abertura da página): ativado ou desativado.
    $inverted = [bool](Get-WinForgeTweakField -Entry $Tweak -Name "Inverted" -Default $false)
    $state = Get-WinForgeTweakSwitchState -Status $Tweak.Status -Inverted $inverted
    $colors = @{ Normal = $script:Theme.Text; Warn = $script:Theme.Warn; Muted = $script:Theme.Muted }

    $caption = New-GuiText -Text $state.Caption -Size 12.5 -Color $colors[[string]$state.Level] -Bold $true
    $caption.VerticalAlignment = "Center"
    $caption.TextAlignment = "Right"
    $caption.Margin = New-Object System.Windows.Thickness (16, 0, 14, 0)
    [System.Windows.Controls.Grid]::SetColumn($caption, 1)
    [void]$grid.Children.Add($caption)

    $toggle = New-Object System.Windows.Controls.Primitives.ToggleButton
    $toggle.Style = $window.FindResource("SwitchToggle")
    $toggle.IsChecked = $state.IsOn
    $toggle.Tag = $Tweak
    $toggle.VerticalAlignment = "Center"
    $toggle.ToolTip = $(if ($needsAdmin) { "Ligue para ativar e desligue para desativar. Pede Administrador ao executar." } else { "Ligue para ativar e desligue para desativar." })
    Set-GuiAutomationName -Element $toggle -Name $Tweak.Name

    # O leitor de tela lê também o que o ajuste faz (a descrição ao lado da chave), não só o nome.
    try { [System.Windows.Automation.AutomationProperties]::SetHelpText($toggle, [string]$Tweak.Description) } catch { Write-Verbose "Leitor de tela: $($_.Exception.Message)" }

    $toggle.Add_Click({
        param ($sender, $eventArgs)
        $tweak = $sender.Tag

        # A chave só mostra o estado real: volta ao que era e deixa a ação decidir (o novo estado aparece quando a
        # página é lida de novo, ao voltar). Assim, uma ação cancelada ou que falha nunca deixa a chave mentindo.
        $shown = (Get-WinForgeTweakSwitchState -Status $tweak.Status -Inverted ([bool](Get-WinForgeTweakField -Entry $tweak -Name "Inverted" -Default $false))).IsOn
        $sender.IsChecked = $shown

        # Com o estado não identificado, a ação pergunta o que fazer (a chave não diz se vai ativar ou desativar). Com ele,
        # a ação recebe o estado pedido (o oposto do que a chave mostrava): se o Windows mudou depois que a página foi
        # aberta e já está assim, nada muda.
        $known = ([string]$tweak.Status -in @("Aplicado", "Padrão"))
        $want = $(if (-not $known) { "" } elseif ($shown) { "Off" } else { "On" })

        try {
            Start-GuiAction -Label $tweak.Name -Command (Get-GuiTweakCommand -Id $tweak.Id -Ask:(-not $known) -Want $want) -RequiresAdmin ([bool]$tweak.RequiresAdmin) -FocusTweak ([string]$tweak.Id)
        }
        catch {
            [void](Show-GuiMessage -Text $_.Exception.Message -Icon Error)
        }
    })

    [System.Windows.Controls.Grid]::SetColumn($toggle, 2)
    [void]$grid.Children.Add($toggle)

    Set-GuiPanelContent -Panel $border -Content $grid
    return $border
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

    # As ações da página (aplicar recomendados, ponto de restauração, desfazer tudo) vêm da tabela de navegação. Um botão
    # que abre uma tela das Configurações do Windows leva o ícone de "abre fora", como a nota "Abre no Windows" dos cartões.
    foreach ($item in $Page.Items) {
        if ($item.Accent) {
            $actionButton = New-GuiButton -Text $item.Label -Kind Primary -Icon "sparkles" -Tag $item
        }
        elseif ($item.Kind -eq "Shortcut") {
            $actionButton = New-GuiButton -Text $item.Label -Icon "external" -Tag $item
        }
        else {
            $actionButton = New-GuiButton -Text $item.Label -Tag $item
        }

        $actionButton.Margin = New-Object System.Windows.Thickness (0, 0, 8, 8)
        $actionButton.ToolTip = $(if ($item.RequiresAdmin -and -not $script:IsAdmin) { "$($item.Description)`nPede Administrador ao executar." } else { $item.Description })
        $actionButton.Add_Click({
            param ($sender, $eventArgs)
            Invoke-GuiNavItem -Item $sender.Tag
        })
        [void]$bar.Children.Add($actionButton)
    }

    $refresh = New-GuiButton -Text "Atualizar estado" -Kind Ghost -Icon "refresh"
    $refresh.Margin = New-Object System.Windows.Thickness (0, 0, 0, 8)
    # Atualizar estado relê os ajustes sem voltar a lista para o topo: a lista é refeita depois (Update-GuiTweaksList), e
    # a rolagem volta ao ponto de antes quando ela fica pronta. A página é a aberta (Ajustes do Windows ou Personalização).
    $refresh.Add_Click({
        $script:TweaksScrollBack = $pageScroll.VerticalOffset
        Show-GuiPage -Id $script:CurrentPage
    })
    [void]$bar.Children.Add($refresh)

    [void]$contentPanel.Children.Add($bar)

    $hint = New-GuiText -Text (Get-GuiTweaksHintText) -Size 13 -Color $script:Theme.Muted
    $hint.Tag = "tweaks-hint"
    $hint.Margin = New-Object System.Windows.Thickness (0, 0, 0, 4)
    [void]$contentPanel.Children.Add($hint)

    $loading = New-GuiText -Text "Lendo o estado atual dos ajustes..." -Color $script:Theme.Muted
    $loading.Tag = "loading"
    $loading.Margin = New-Object System.Windows.Thickness (0, 14, 0, 0)
    [void]$contentPanel.Children.Add($loading)

    Invoke-GuiDeferred -Action { Update-GuiTweaksList }
}

function Get-GuiTweaksHintText {
    # A frase do alto da página; depois da leitura, com quantos itens da página o WinForge mudou e continuam como ele
    # deixou (os que Desfazer ajustes do WinForge devolveria; os avançados entram na conta).
    param ([int]$Changed = -1)

    $text = "Cada chave mostra como o Windows está agora: ligue para ativar e desligue para desativar. O WinForge guarda o valor de antes."

    if ($Changed -lt 0) { return $text }

    return "$text Mudados pelo WinForge nesta página: $Changed."
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

    # Remove o aviso de carregamento e desenha a lista agrupada por categoria.
    foreach ($child in @($contentPanel.Children)) {
        if ($child -is [System.Windows.Controls.TextBlock] -and $child.Tag -eq "loading") {
            $contentPanel.Children.Remove($child)
        }
    }

    try {
        $overview = @(Get-WinForgeTweakOverview -Page $navPage.Id)
        $group = $null
        $rows = @{}

        # Quantos o WinForge mudou e ainda estão como ele deixou, na frase do alto: o que Desfazer ajustes do WinForge
        # devolveria. As chaves mostram o estado do Windows, e não o que o WinForge fez.
        $saved = @(Get-WinForgeTweakBackupIds)
        $changedCount = @($overview | Where-Object { $_.Status -eq "Aplicado" -and $saved -contains [string]$_.Id }).Count

        foreach ($child in @($contentPanel.Children)) {
            if ($child -is [System.Windows.Controls.TextBlock] -and $child.Tag -eq "tweaks-hint") {
                $child.Text = Get-GuiTweaksHintText -Changed $changedCount
            }
        }

        # Os ajustes de energia e desempenho ficam recolhidos em "Avançados": mudam o comportamento do PC.
        foreach ($tweak in @($overview | Where-Object { -not $_.Advanced })) {
            if ($null -eq $group -or $tweak.Category -ne $group.Category) {
                $group = New-GuiTweakGroup -Category $tweak.Category
                [void]$contentPanel.Children.Add($group.Heading)
                [void]$contentPanel.Children.Add($group.Card)
            }

            $rows[[string]$tweak.Id] = New-GuiTweakRow -Tweak $tweak
            Add-GuiTweakToGroup -Group $group -Row $rows[[string]$tweak.Id]
        }

        $advancedTweaks = @($overview | Where-Object { $_.Advanced })

        if ($advancedTweaks.Count -gt 0) {
            $advancedPanel = New-Object System.Windows.Controls.StackPanel
            $advancedPanel.Visibility = $(if ($script:TweaksAdvancedOpen) { "Visible" } else { "Collapsed" })

            $note = New-GuiText -Text "Mudam energia e desempenho do PC; em notebook podem gastar bateria. Cada um pode ser desfeito." -Size 13 -Color $script:Theme.Muted
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

            $toggle = New-GuiButton -Text $(if ($script:TweaksAdvancedOpen) { "Ocultar ajustes avançados" } else { "Mostrar ajustes avançados ($($advancedTweaks.Count))" }) `
                -Tag @{ Panel = $advancedPanel; Count = $advancedTweaks.Count }
            $toggle.Margin = New-Object System.Windows.Thickness (0, 18, 0, 4)
            $toggle.HorizontalAlignment = "Left"
            $toggle.Add_Click({
                param ($sender, $eventArgs)

                $panel = $sender.Tag.Panel
                $script:TweaksAdvancedOpen = ($panel.Visibility -ne "Visible")
                $panel.Visibility = $(if ($script:TweaksAdvancedOpen) { "Visible" } else { "Collapsed" })
                $sender.Content = $(if ($script:TweaksAdvancedOpen) { "Ocultar ajustes avançados" } else { "Mostrar ajustes avançados ($($sender.Tag.Count))" })
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
        $failure = New-GuiText -Text "Não foi possível ler o estado dos ajustes. Use Atualizar estado, logo acima, para tentar de novo." -Color $script:Theme.Bad
        $failure.ToolTip = "Detalhe técnico: $($_.Exception.Message)"
        [void]$contentPanel.Children.Add($failure)
    }
    finally {
        $script:FocusTweakId = ""

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
            [System.Windows.Automation.AutomationProperties]::SetItemStatus($part.Button, $(if ($selected) { "página aberta" } else { "" }))
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

function Show-GuiPage {
    param (
        [Parameter(Mandatory)][string]$Id,

        # Só para a página de ajustes: o ajuste a destacar (vindo da busca).
        [string]$FocusTweak = "",

        # A mesma página, refeita no lugar (troca de tema): a rolagem fica onde estava e o Início não lê o PC de novo.
        [switch]$Rerender
    )

    $offset = $pageScroll.VerticalOffset

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
}

# --- Busca ---------------------------------------------------------------------------------------------------
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

    $hits = @(Search-WinForgeNavigation -Query $Query)
    $shown = @($hits | Select-Object -First $script:SearchMaxCards)
    $partial = ($hits.Count -gt 0 -and [bool]$hits[0].Partial)
    $corrected = $(if ($hits.Count -gt 0) { [string]$hits[0].Corrected } else { "" })
    $script:SearchFirst = $(if ($hits.Count -gt 0) { $hits[0] } else { $null })
    $script:SearchEnterOpens = Test-WinForgeSearchEnterOpens -Hit $script:SearchFirst

    $pageTitle.Text = "Busca"
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

    $panel = New-Object System.Windows.Controls.WrapPanel

    foreach ($hit in $shown) {
        $first = ($null -eq $script:SearchFirstCard)
        $card = New-GuiActionCard -Item (Get-WinForgeSearchCardItem -Hit $hit) -Context (Get-WinForgeSearchContext -Hit $hit) -EnterHint:($first -and $script:SearchEnterOpens)

        if ($first) {
            # O primeiro é o que o Enter abre (ou seleciona): ganha a moldura de destaque e, quando abre, a tecla "Enter".
            $script:SearchFirstCard = $card
            $card.BorderBrush = New-GuiBrush $script:Theme.Accent
        }

        [void]$panel.Children.Add($card)
    }

    $panel.Add_PreviewKeyDown($script:SearchCardsKeyDown)
    [void]$contentPanel.Children.Add($panel)
    $script:SearchPanel = $panel
    $script:SearchShownKey = $key

    if ($Rerender) {
        $pageScroll.UpdateLayout()
        $pageScroll.ScrollToVerticalOffset($offset)
    }
}

function Add-GuiSearchSuggestions {
    # Nada encontrado: buscas que funcionam, do jeito que a pessoa diria, como botões que buscam na hora.
    [void]$contentPanel.Children.Add((New-GuiText -Text "Busque pelo que está acontecendo com o PC ou pelo nome do que procura. Por exemplo:" -Color $script:Theme.Muted))

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
    $copyButton.Content = "Copiar"

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
    # Shortcut: a tecla que abre a página ("Ctrl+3"), mostrada ao passar o mouse e dita pelo leitor de tela.
    param ([string]$Id, [string]$Title, [bool]$Footer = $false, [string]$Shortcut = "")

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

    $label = New-GuiText -Text $Title -Size 13.5
    $label.TextWrapping = "NoWrap"
    $label.VerticalAlignment = "Center"
    [void]$row.Children.Add($label)

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

# Ctrl+1 a Ctrl+9 (e Ctrl+0 para a décima): Início e as páginas da lista principal, na ordem da barra lateral.
$script:PageShortcuts = @("home") + @(Get-WinForgeNavigation | Where-Object { $_.Placement -ne "Footer" } | ForEach-Object { $_.Id })

Add-GuiNavButton -Id "home" -Title "Início" -Shortcut (Get-WinForgePageShortcutKey -Index 0)

foreach ($navPage in @(Get-WinForgeNavigation)) {
    Add-GuiNavButton -Id $navPage.Id -Title $navPage.Title -Footer ($navPage.Placement -eq "Footer") `
        -Shortcut (Get-WinForgePageShortcutKey -Index ([array]::IndexOf($script:PageShortcuts, [string]$navPage.Id)))
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
        try { & $action } catch { }
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
    $answer = Show-GuiMessage -Buttons YesNo -Icon Warning -Title "Parar a ação" -Text "Parar ""$($runTitle.Text)"" agora?`n`nO que já foi feito continua feito, mas a etapa atual fica incompleta. Reparos e instalações em andamento são interrompidos no meio."

    if ($answer -eq "Yes" -and $script:Running -and $null -ne $script:GuiSession) {
        Set-GuiRunStatus -Text "Interrompendo..." -DotColor $script:Theme.Warn
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
        $copyButton.Content = "Copiado"
    }
    catch {
        [void](Show-GuiMessage -Icon Warning -Text "Não foi possível copiar: $($_.Exception.Message)")
    }
})

$saveButton.Add_Click({
    try {
        $dialog = New-Object Microsoft.Win32.SaveFileDialog
        $dialog.Title = "Salvar a saída"
        $dialog.Filter = "Texto (*.txt)|*.txt|Todos os arquivos (*.*)|*.*"
        $dialog.FileName = Get-WinForgeOutputFileName -Title $runTitle.Text
        $dialog.InitialDirectory = [Environment]::GetFolderPath("MyDocuments")

        if ($dialog.ShowDialog($window)) {
            # UTF-8 com BOM: o Bloco de Notas do Windows 10 antigo só reconhece os acentos assim.
            [System.IO.File]::WriteAllText($dialog.FileName, (Get-GuiOutputText), (New-Object System.Text.UTF8Encoding($true)))
            $saveButton.Content = "Salvo"
        }
    }
    catch {
        [void](Show-GuiMessage -Icon Warning -Text "Não foi possível salvar: $($_.Exception.Message)")
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

    if (-not $opened) { Open-GuiShortcut -Name "LogFolder" -Title "Pasta de logs e relatórios" }
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

    # Meia linha para os atalhos do Início; com uma coluna só, a largura de um cartão.
    $wide = $(if ($columns -ge 2) { [Math]::Floor($content / 2) - $script:CardGap } else { $width })

    return [PSCustomObject]@{ Columns = [int]$columns; Width = [double]$width; Wide = [double]$wide; Content = [double]$content }
}

function Update-GuiContentWidth {
    try {
        $available = $pageScroll.ViewportWidth - 4
        if ($available -le 0) { return }

        $grid = Get-GuiCardGrid -Available $available

        if ($grid.Width -ne $script:CardWidth -or $grid.Wide -ne $script:WideCardWidth) {
            $script:CardWidth = $grid.Width
            $script:WideCardWidth = $grid.Wide
            $window.Resources["CardWidth"] = [double]$grid.Width
            $window.Resources["WideCardWidth"] = [double]$grid.Wide
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

    # Quem troca o tema do Windows nas Configurações volta para cá: no modo automático, a janela acompanha.
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
        $answer = Show-GuiMessage -Buttons YesNo -Icon Warning -Title "Fechar o WinForge" -Text """$($runTitle.Text)"" ainda está em andamento.`n`nSe você fechar o WinForge agora, a ação é interrompida: o que já foi feito continua feito, mas a etapa atual fica incompleta.`n`nFechar mesmo assim?"

        if ($answer -ne "Yes") {
            $eventArgs.Cancel = $true
            return
        }

        Stop-WinForgeGuiCommand -Session $script:GuiSession
    }

    Save-GuiWindowBounds
    $script:Timer.Stop()
    $script:DeferredTimer.Stop()
    $script:SearchTimer.Stop()
    $script:WarmupTimer.Stop()
    $script:SearchWarmTimer.Stop()
    $script:StartActionTimer.Stop()
    $script:RequestTimer.Stop()
    $script:HomeReaderTimer.Stop()
    $script:HomeStampTimer.Stop()
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
    [void](Show-GuiMessage -Icon Error -Text "Algo deu errado na janela do WinForge.`n`nSe uma ação estava rodando, confira o resultado dela antes de continuar. Se o problema se repetir, feche e abra o WinForge; o log fica em Sobre o WinForge > Pasta de logs e relatórios.`n`nDetalhe técnico: $($eventArgs.Exception.Message)")
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

# Aberta pelo monitor na bandeja com uma ação (-Action): ela roda logo depois que o executor fica pronto.
$script:StartActionTimer = New-Object System.Windows.Threading.DispatcherTimer
$script:StartActionTimer.Interval = [TimeSpan]::FromMilliseconds(900)
$script:StartActionTimer.Add_Tick({
    $script:StartActionTimer.Stop()

    $item = Get-WinForgeNavItem -Id $script:StartAction
    $script:StartAction = ""

    if ($null -ne $item) { Invoke-GuiNavItem -Item $item }
})

# Pedidos de outra abertura do WinForge (Enter-WinForgeWindowLock): a janela vem para a frente e, se o pedido trouxe
# uma ação, ela roda (ou, com outra ação em andamento, a pessoa é avisada).
$script:RequestTimer = New-Object System.Windows.Threading.DispatcherTimer
$script:RequestTimer.Interval = [TimeSpan]::FromMilliseconds(500)
$script:RequestTimer.Add_Tick({
    try {
        $request = Receive-WinForgeWindowRequest
        if ($null -eq $request) { return }

        if ($window.WindowState -eq "Minimized") { $window.WindowState = "Normal" }
        [void]$window.Activate()
        $window.Topmost = $true
        $window.Topmost = $false
        if (-not $window.IsActive) { Set-GuiTaskbarFlash -On $true }

        # Só as ações que o monitor na bandeja oferece: o pedido vem de um arquivo que qualquer programa desta conta grava
        # sem elevação, e a janela roda como Administrador.
        if ($request.Action -and $request.Action -in @(Get-WinForgeAgentActionIds)) {
            $item = Get-WinForgeNavItem -Id $request.Action
            if ($null -ne $item) { Invoke-GuiNavItem -Item $item }
        }
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

    if ($script:StartAction) { $script:StartActionTimer.Start() }
})

if ($isAdmin) {
    $window.FindName("AdminText").Text = "Administrador"
}
else {
    $window.FindName("AdminText").Text = "Sem Administrador · o WinForge pede de novo quando uma ação precisar"
}

Restore-GuiWindowBounds
Limit-GuiWindowToWorkArea
Reset-GuiOutput
$script:AntivirusMode = Get-GuiSavedAntivirusMode
Show-GuiPage -Id $script:StartPage
[void]$window.ShowDialog()
