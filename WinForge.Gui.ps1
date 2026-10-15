#requires -Version 5.1
<#
.SYNOPSIS
    WinForge com janela (WPF): as ações rodam dentro da própria janela, sem abrir terminal.

.DESCRIPTION
    A barra lateral e os cartões vêm da tabela de navegação (modules\Navigation.psm1), a mesma que monta os menus
    do WinForge.Console.ps1. Cada ação roda num runspace separado com um host próprio (modules\GuiHost.psm1):
    a saída aparece no painel e as perguntas viram botões, listas de marcação ou caixa de texto.

    Abra pelo WinForge.cmd. O script se reabre sozinho como Administrador e em modo STA (exigido pelo WPF).

.PARAMETER Relaunched
    Uso interno: indica que esta é a segunda execução, já elevada. Evita um laço caso a elevação ou o STA falhem.
#>
[CmdletBinding()]
param (
    [switch]$Relaunched
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
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$isAdmin = (New-Object Security.Principal.WindowsPrincipal $identity).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$isSta = ([Threading.Thread]::CurrentThread.ApartmentState -eq "STA")

if (-not $isAdmin -or -not $isSta) {
    if ($Relaunched) {
        Show-GuiStartupMessage -Text "Não foi possível abrir o WinForge como Administrador em modo STA. Abra o arquivo WinForge.cmd com clique direito > Executar como administrador."
        exit 1
    }

    $hostExe = (Get-Process -Id $PID).Path
    $launchArgs = "-NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File `"$PSCommandPath`" -Relaunched"

    try {
        if (-not $isAdmin) {
            Start-Process -FilePath $hostExe -ArgumentList $launchArgs -Verb RunAs -ErrorAction Stop
        }
        else {
            Start-Process -FilePath $hostExe -ArgumentList $launchArgs -ErrorAction Stop
        }
    }
    catch {
        Show-GuiStartupMessage -Icon "Warning" -Text "O WinForge precisa de permissão de Administrador para fazer manutenção do Windows.`n`nAbra o WinForge novamente e aceite o aviso do Windows (Controle de Conta de Usuário)."
    }

    exit
}

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

# --- Módulos (lista em modules\Modules.psd1) -----------------------------------------------------------
$moduleRoot = Join-Path $PSScriptRoot "modules"
$xamlPath = Join-Path $PSScriptRoot "gui\MainWindow.xaml"

try {
    $manifest = Import-PowerShellDataFile -LiteralPath (Join-Path $moduleRoot "Modules.psd1") -ErrorAction Stop
    $script:ActionModules = @($manifest.Common)

    foreach ($name in ($script:ActionModules + @($manifest.Gui))) {
        $modulePath = Join-Path $moduleRoot "$name.psm1"

        if (-not (Test-Path -LiteralPath $modulePath)) {
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

    if (-not (Test-Path -LiteralPath $xamlPath)) {
        throw "Arquivo da janela não encontrado: $xamlPath"
    }

    [xml]$xaml = Get-Content -LiteralPath $xamlPath -Raw -Encoding UTF8
    $window = [System.Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $xaml))
}
catch {
    Show-GuiStartupMessage -Text "Não foi possível abrir o WinForge:`n`n$($_.Exception.Message)`n`nExtraia a pasta inteira do WinForge antes de executar e evite caminhos com colchetes."
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

# --- Estado --------------------------------------------------------------------------------------------
$script:GuiSession = $null
$script:Running = $false
$script:CurrentPage = "home"
$script:ShownPrompt = $null
$script:ProgressVersionShown = -1
$script:DeferredAction = $null
$script:HomeFacts = @{}
$script:HomeBanner = $null
$script:TaskbarInfo = $null

$script:Theme = @{
    Accent = "#3B82F6"; AccentText = "#7DB2FF"; AccentCard = "#16233A"; AccentLine = "#2C4A7C"
    Card = "#161D27"; Line = "#263241"
    Text = "#E6EDF3"; Muted = "#8A9BB0"; Dim = "#6B7C90"
    Ok = "#4ADE80"; Warn = "#FBBF24"; Bad = "#F87171"
}

$script:BrushConverter = New-Object System.Windows.Media.BrushConverter

function New-GuiBrush {
    param ([Parameter(Mandatory)][string]$Hex)

    return $script:BrushConverter.ConvertFromString($Hex)
}

function Show-GuiMessage {
    param (
        [Parameter(Mandatory)][string]$Text,
        [string]$Title = "WinForge",
        [ValidateSet("OK", "YesNo")]
        [string]$Buttons = "OK",
        [ValidateSet("Information", "Warning", "Error", "Question")]
        [string]$Icon = "Information"
    )

    try {
        return [string][System.Windows.MessageBox]::Show($window, $Text, $Title, $Buttons, $Icon)
    }
    catch {
        # Janela já fechada ou ainda não exibida: mostra a mensagem sem dono.
        return [string][System.Windows.MessageBox]::Show($Text, $Title, $Buttons, $Icon)
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

function New-GuiPanelBorder {
    # Moldura arredondada usada por fatos, linhas de ajustes e avisos.
    param (
        [string]$Background = $script:Theme.Card,
        [string]$BorderColor = $script:Theme.Line
    )

    $border = New-Object System.Windows.Controls.Border
    $border.Background = New-GuiBrush $Background
    $border.BorderBrush = New-GuiBrush $BorderColor
    $border.BorderThickness = New-Object System.Windows.Thickness 1
    $border.CornerRadius = New-Object System.Windows.CornerRadius 10
    $border.Padding = New-Object System.Windows.Thickness (16, 12, 16, 12)

    return $border
}

function New-GuiButton {
    param (
        [Parameter(Mandatory)][string]$Text,
        [string]$Background = "",
        $Tag = $null
    )

    $button = New-Object System.Windows.Controls.Button
    $button.Style = $window.FindResource("PillButton")
    $button.Content = $Text
    $button.Tag = $Tag

    if (-not [string]::IsNullOrEmpty($Background)) {
        $button.Background = New-GuiBrush $Background
    }

    return $button
}

# --- Barra de título escura, ícone e barra de tarefas ------------------------------------------------------
if (-not ("WinForge.NativeWindow" -as [type])) {
    Add-Type -Namespace WinForge -Name NativeWindow -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("dwmapi.dll")]
public static extern int DwmSetWindowAttribute(System.IntPtr hwnd, int attribute, ref int value, int size);
'@
}

function Set-GuiTitleBarTheme {
    param ([System.Windows.Window]$Target)

    try {
        $handle = (New-Object System.Windows.Interop.WindowInteropHelper $Target).Handle
        $dark = 1

        # 20 = modo escuro (Windows 10 20H1+ e 11); 19 = valor usado por builds anteriores do Windows 10.
        if ([WinForge.NativeWindow]::DwmSetWindowAttribute($handle, 20, [ref]$dark, 4) -ne 0) {
            [void][WinForge.NativeWindow]::DwmSetWindowAttribute($handle, 19, [ref]$dark, 4)
        }

        # Windows 11 (build 22000+): cor exata da barra, do texto e da borda. COLORREF = 0x00BBGGRR.
        $caption = 0x140F0B
        $text = 0xF3EDE6
        $border = 0x413226
        [void][WinForge.NativeWindow]::DwmSetWindowAttribute($handle, 35, [ref]$caption, 4)
        [void][WinForge.NativeWindow]::DwmSetWindowAttribute($handle, 36, [ref]$text, 4)
        [void][WinForge.NativeWindow]::DwmSetWindowAttribute($handle, 34, [ref]$border, 4)
    }
    catch {
        # Cosmético: em versões sem suporte a barra continua com o tema padrão do Windows.
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
    # Reserva para quando o .ico não está na pasta: um "W" branco sobre o quadrado azul.
    try {
        $visual = New-Object System.Windows.Media.DrawingVisual
        $context = $visual.RenderOpen()
        $context.DrawRoundedRectangle((New-GuiBrush $script:Theme.Accent), $null, (New-Object System.Windows.Rect (0, 0, 64, 64)), 14, 14)

        $face = New-Object System.Windows.Media.Typeface ((New-Object System.Windows.Media.FontFamily "Segoe UI"), [System.Windows.FontStyles]::Normal, [System.Windows.FontWeights]::Bold, [System.Windows.FontStretches]::Normal)
        $letter = New-Object System.Windows.Media.FormattedText ("W", [System.Globalization.CultureInfo]::InvariantCulture, [System.Windows.FlowDirection]::LeftToRight, $face, 42, [System.Windows.Media.Brushes]::White)
        $context.DrawText($letter, (New-Object System.Windows.Point (((64 - $letter.Width) / 2), ((64 - $letter.Height) / 2))))
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
    # Mostra o andamento no botão da barra de tarefas, para acompanhar com a janela minimizada.
    param (
        [ValidateSet("None", "Indeterminate", "Normal")]
        [string]$State,
        [double]$Value = 0
    )

    if ($null -eq $script:TaskbarInfo) { return }

    try {
        $script:TaskbarInfo.ProgressState = $State

        if ($State -eq "Normal") {
            $script:TaskbarInfo.ProgressValue = [Math]::Max(0, [Math]::Min(1, $Value))
        }
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
$window.FindName("AdminText").Text = "Executando como Administrador"

# --- Painel de saída -----------------------------------------------------------------------------------
$script:ColorMap = @{
    Black = "#4A5568"; DarkBlue = "#5B8DEF"; DarkGreen = "#3FB950"; DarkCyan = "#39C5CF"
    DarkRed = "#F85149"; DarkMagenta = "#BC8CFF"; DarkYellow = "#D29922"; Gray = "#C9D4E0"
    DarkGray = "#7D8CA0"; Blue = "#79B8FF"; Green = "#56D364"; Cyan = "#56D4DD"
    Red = "#FF7B72"; Magenta = "#D2A8FF"; Yellow = "#E3B341"; White = "#FFFFFF"
}
$script:BrushCache = @{}

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

    $brush = Get-GuiConsoleBrush $Item.Color
    $parts = ([string]$Item.Text).Split("`n")

    for ($i = 0; $i -lt $parts.Length; $i++) {
        $segment = $parts[$i]

        if ($segment.Length -gt 0) {
            $run = New-Object System.Windows.Documents.Run $segment
            $run.Foreground = $brush
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
    # Largura do painel em caracteres, para as tabelas e barras da saída caberem sem quebrar linha.
    try {
        $width = $outputBox.ActualWidth
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

# --- Perguntas: botões, listas de marcação e texto -----------------------------------------------------------
function Submit-GuiPrompt {
    param ([string]$Answer, [int]$Index = -1)

    $prompt = $script:ShownPrompt

    if ($null -eq $prompt) { return }

    $script:ShownPrompt = $null
    $promptBar.Visibility = "Collapsed"
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
    Complete-WinForgeGuiPrompt -Session $script:GuiSession -Prompt $prompt -Keys $keys -Accepted:$Accepted
}

function Update-GuiMultiPromptCount {
    $checked = @($promptList.Children | Where-Object { $_.IsChecked }).Count

    foreach ($child in $promptButtons.Children) {
        if ($child.Tag -is [hashtable] -and $child.Tag.Role -eq "confirm") {
            $child.Content = "Confirmar ($checked)"
            $child.IsEnabled = ($checked -gt 0)
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

    $button = New-GuiButton -Text $Text -Tag $Tag
    $button.Margin = New-Object System.Windows.Thickness (0, 0, 10, 8)

    if (-not [string]::IsNullOrWhiteSpace($Description)) {
        $stack = New-Object System.Windows.Controls.StackPanel
        [void]$stack.Children.Add((New-GuiText -Text $Text -Size 13 -Color "#FFFFFF" -Bold $true))
        [void]$stack.Children.Add((New-GuiText -Text $Description -Size 11 -Color "#B7C4D4"))
        $button.Content = $stack
    }

    if ($Accent) {
        $button.Background = New-GuiBrush $script:Theme.Accent
    }
    elseif ($Exit) {
        $button.Background = New-GuiBrush "#3A2230"
    }

    return $button
}

function Show-GuiPromptBar {
    param ($Prompt)

    $plan = Get-WinForgePromptPlan -Prompt $Prompt

    $promptLabel.Text = $plan.Label
    $promptButtons.Children.Clear()
    $promptList.Children.Clear()
    $promptListScroll.Visibility = "Collapsed"
    $promptTextRow.Visibility = "Collapsed"

    if ($plan.Kind -eq "multi") {
        foreach ($option in $plan.Options) {
            $box = New-Object System.Windows.Controls.CheckBox
            $box.Tag = [string]$option.Key
            $box.IsChecked = [bool]$option.Selected
            $box.Margin = New-Object System.Windows.Thickness (0, 3, 0, 3)
            $box.Cursor = [System.Windows.Input.Cursors]::Hand

            $stack = New-Object System.Windows.Controls.StackPanel
            [void]$stack.Children.Add((New-GuiText -Text ([string]$option.Label) -Size 13))

            if (-not [string]::IsNullOrWhiteSpace([string]$option.Description)) {
                [void]$stack.Children.Add((New-GuiText -Text ([string]$option.Description) -Size 11 -Color $script:Theme.Muted))
            }

            $box.Content = $stack
            $box.Add_Click({ Update-GuiMultiPromptCount })
            [void]$promptList.Children.Add($box)
        }

        $promptListScroll.Visibility = "Visible"

        $confirm = New-GuiPromptButton -Text "Confirmar (0)" -Accent $true -Tag @{ Role = "confirm" }
        $confirm.Add_Click({ Submit-GuiMultiPrompt -Accepted $true })
        [void]$promptButtons.Children.Add($confirm)

        $all = New-GuiPromptButton -Text "Marcar todos" -Tag @{ Role = "all" }
        $all.Add_Click({
            foreach ($child in $promptList.Children) { $child.IsChecked = $true }
            Update-GuiMultiPromptCount
        })
        [void]$promptButtons.Children.Add($all)

        $none = New-GuiPromptButton -Text "Limpar" -Tag @{ Role = "none" }
        $none.Add_Click({
            foreach ($child in $promptList.Children) { $child.IsChecked = $false }
            Update-GuiMultiPromptCount
        })
        [void]$promptButtons.Children.Add($none)

        $cancel = New-GuiPromptButton -Text "Cancelar" -Exit $true -Tag @{ Role = "cancel" }
        $cancel.Add_Click({ Submit-GuiMultiPrompt -Accepted $false })
        [void]$promptButtons.Children.Add($cancel)

        Update-GuiMultiPromptCount
    }
    else {
        foreach ($definition in $plan.Buttons) {
            $button = New-GuiPromptButton -Text $definition.Text -Description $definition.Description -Accent $definition.Accent -Exit $definition.Exit -Tag @{ Answer = $definition.Answer; Index = $definition.Index; Role = "answer" }

            $button.Add_Click({
                param ($sender, $eventArgs)
                Submit-GuiPrompt -Answer ([string]$sender.Tag.Answer) -Index ([int]$sender.Tag.Index)
            })

            [void]$promptButtons.Children.Add($button)
        }

        if ($plan.ShowText) {
            $promptTextRow.Visibility = "Visible"
            $promptInput.Text = ""
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

    if ($plan.ShowText) {
        [void]$promptInput.Focus()
    }
}

# --- Execução de ações ---------------------------------------------------------------------------------
function Set-GuiNavEnabled {
    # Durante uma ação a barra lateral inteira (páginas e rodapé) fica desabilitada.
    param ([Parameter(Mandatory)][bool]$Enabled)

    $navPanel.IsEnabled = $Enabled
    $footerNav.IsEnabled = $Enabled
}

function Complete-GuiRun {
    param ([string]$Status)

    $script:Timer.Stop()
    $script:Running = $false
    $script:ShownPrompt = $null
    $promptBar.Visibility = "Collapsed"
    $progressPanel.Visibility = "Collapsed"
    $stopButton.Visibility = "Collapsed"
    $backButton.Visibility = "Visible"
    Set-GuiNavEnabled -Enabled $true
    Set-GuiTaskbarProgress -State None

    switch ($Status) {
        "Completed" { Set-GuiRunStatus -Text "Concluído" -DotColor $script:Theme.Ok }
        "Stopped" { Set-GuiRunStatus -Text "Interrompido" -DotColor $script:Theme.Warn }
        default { Set-GuiRunStatus -Text "Terminou com erro" -DotColor $script:Theme.Bad }
    }

    [void]$backButton.Focus()
}

function Update-GuiRunView {
    try {
        if ($null -eq $script:GuiSession) { return }

        $atBottom = (($outputBox.VerticalOffset + $outputBox.ViewportHeight) -ge ($outputBox.ExtentHeight - 24))
        $update = Read-WinForgeGuiUpdate -Session $script:GuiSession

        foreach ($item in $update.Items) {
            Add-GuiOutputItem -Item $item
        }

        if ($update.Items.Count -gt 0 -and $atBottom) {
            $outputBox.ScrollToEnd()
        }

        if ($update.ProgressVersion -ne $script:ProgressVersionShown) {
            $script:ProgressVersionShown = $update.ProgressVersion
            $info = $update.Progress

            if ($null -ne $info -and -not $info.Completed) {
                $progressText.Text = (@($info.Activity, $info.Status) | Where-Object { $_ }) -join "  -  "
                $progressPanel.Visibility = "Visible"

                if ($info.Percent -ge 0) {
                    $runProgress.IsIndeterminate = $false
                    $runProgress.Value = [Math]::Min(100, $info.Percent)
                    Set-GuiTaskbarProgress -State Normal -Value ($runProgress.Value / 100)
                }
                else {
                    $runProgress.IsIndeterminate = $true
                    Set-GuiTaskbarProgress -State Indeterminate
                }
            }
            else {
                $progressPanel.Visibility = "Collapsed"
                Set-GuiTaskbarProgress -State Indeterminate
            }
        }

        if ($null -ne $update.Prompt -and $null -eq $script:ShownPrompt -and -not $update.Prompt.Done.WaitOne(0)) {
            Show-GuiPromptBar -Prompt $update.Prompt
        }

        if ($update.Status -ne "Running") {
            Complete-GuiRun -Status $update.Status
        }
    }
    catch {
        $failure = $_.Exception.Message

        # Sem a saída na tela não há como acompanhar a ação: interrompe-a em vez de deixá-la rodando escondida.
        try { Stop-WinForgeGuiCommand -Session $script:GuiSession } catch { }

        $script:Timer.Stop()
        $script:Running = $false
        $script:ShownPrompt = $null
        $promptBar.Visibility = "Collapsed"
        $progressPanel.Visibility = "Collapsed"
        Set-GuiNavEnabled -Enabled $true
        $stopButton.Visibility = "Collapsed"
        $backButton.Visibility = "Visible"
        Set-GuiRunStatus -Text "Terminou com erro" -DotColor $script:Theme.Bad
        Set-GuiTaskbarProgress -State None
        [void](Show-GuiMessage -Text "Erro ao atualizar a saída: $failure" -Icon Error)
    }
}

function Start-GuiAction {
    param (
        [Parameter(Mandatory)][string]$Label,
        [Parameter(Mandatory)][string]$Command
    )

    if ($script:Running) {
        [void](Show-GuiMessage -Text "Já existe uma ação em andamento. Aguarde terminar ou use Parar." -Icon Information)
        return
    }

    try {
        if ($null -eq $script:GuiSession) {
            $script:GuiSession = New-WinForgeGuiSession -ModuleRoot $moduleRoot -Modules $script:ActionModules
        }

        Reset-GuiOutput
        $runTitle.Text = $Label
        Set-GuiRunStatus -Text "Em execução..." -DotColor $script:Theme.Accent
        $stopButton.Visibility = "Visible"
        $backButton.Visibility = "Collapsed"
        $progressPanel.Visibility = "Collapsed"
        $promptBar.Visibility = "Collapsed"
        $copyButton.Content = "Copiar saída"
        $script:ShownPrompt = $null
        $script:ProgressVersionShown = -1

        $pagesView.Visibility = "Collapsed"
        $runView.Visibility = "Visible"
        $window.UpdateLayout()

        $started = Start-WinForgeGuiCommand -Session $script:GuiSession -Command $Command -Columns (Get-GuiOutputColumns)

        if (-not $started) { throw "Já existe uma ação em execução." }

        $script:Running = $true
        Set-GuiNavEnabled -Enabled $false
        Set-GuiTaskbarProgress -State Indeterminate
        $script:Timer.Start()
    }
    catch {
        $pagesView.Visibility = "Visible"
        $runView.Visibility = "Collapsed"
        Set-GuiNavEnabled -Enabled $true
        Set-GuiTaskbarProgress -State None
        [void](Show-GuiMessage -Text "Não foi possível iniciar a ação: $($_.Exception.Message)" -Icon Error)
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

    if (-not $opened) {
        [void](Show-GuiMessage -Icon Warning -Title $Title -Text "Não foi possível abrir '$Title'.`n`nO recurso pode não existir nesta edição do Windows.")
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
    param ([Parameter(Mandatory)][string]$Id)

    if ($Id -notmatch '^[a-z0-9][a-z0-9-]*$') {
        throw "Identificador de ajuste inválido: $Id"
    }

    return "Invoke-WinForgeTweakToggle -Tweak (Get-WinForgeTweakById -Id '$Id') -AlreadyConfirmed"
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

    try {
        Start-GuiAction -Label $Item.Label -Command (Get-GuiNavCommand -Item $Item)
    }
    catch {
        [void](Show-GuiMessage -Text $_.Exception.Message -Icon Error)
    }
}

function New-GuiActionCard {
    param ([Parameter(Mandatory)]$Item)

    $button = New-Object System.Windows.Controls.Button
    $button.Style = $window.FindResource("CardButton")
    $button.Tag = $Item
    $button.ToolTip = $Item.Description

    $stack = New-Object System.Windows.Controls.StackPanel
    $stack.Width = 242

    $titleColor = $script:Theme.Text

    if ($Item.Accent) {
        # O cartão de destaque (o caminho recomendado da página) tem título azul e moldura azulada.
        $titleColor = $script:Theme.AccentText
        $button.Background = New-GuiBrush $script:Theme.AccentCard
        $button.BorderBrush = New-GuiBrush $script:Theme.AccentLine
    }

    [void]$stack.Children.Add((New-GuiText -Text $Item.Label -Size 14 -Color $titleColor -Bold $true))

    $description = New-GuiText -Text $Item.Description -Size 12 -Color $script:Theme.Muted
    $description.Margin = New-Object System.Windows.Thickness (0, 4, 0, 0)
    [void]$stack.Children.Add($description)

    $button.Content = $stack
    $button.Add_Click({
        param ($sender, $eventArgs)
        Invoke-GuiNavItem -Item $sender.Tag
    })

    return $button
}

function New-GuiFactCard {
    param ([Parameter(Mandatory)][string]$Label)

    $border = New-GuiPanelBorder
    $border.Width = 276
    $border.Margin = New-Object System.Windows.Thickness (0, 0, 12, 12)

    $stack = New-Object System.Windows.Controls.StackPanel
    [void]$stack.Children.Add((New-GuiText -Text $Label -Size 11 -Color $script:Theme.Dim))

    $value = New-GuiText -Text "Lendo..." -Size 15 -Color $script:Theme.Dim -Bold $true
    [void]$stack.Children.Add($value)
    $border.Child = $stack

    return [PSCustomObject]@{ Card = $border; Value = $value }
}

function Show-GuiHomePage {
    $pageTitle.Text = "Início"
    $pageSubtitle.Text = "Como está o seu PC e por onde começar"
    $contentPanel.Children.Clear()
    $script:HomeFacts = @{}

    # Avisos (por exemplo, WinForge elevado com outra conta) entram aqui quando a leitura do sistema termina.
    $script:HomeBanner = New-Object System.Windows.Controls.StackPanel
    [void]$contentPanel.Children.Add($script:HomeBanner)

    $facts = New-Object System.Windows.Controls.WrapPanel
    $labels = Get-WinForgeHomeFactLabels

    foreach ($id in $labels.Keys) {
        $fact = New-GuiFactCard -Label $labels[$id]
        $script:HomeFacts[$id] = $fact.Value
        [void]$facts.Children.Add($fact.Card)
    }

    [void]$contentPanel.Children.Add($facts)

    $heading = New-GuiText -Text "Por onde começar" -Size 15 -Bold $true
    $heading.Margin = New-Object System.Windows.Thickness (0, 8, 0, 10)
    [void]$contentPanel.Children.Add($heading)

    $shortcuts = New-Object System.Windows.Controls.WrapPanel

    foreach ($item in @(Get-WinForgeHomeActions)) {
        [void]$shortcuts.Children.Add((New-GuiActionCard -Item $item))
    }

    [void]$contentPanel.Children.Add($shortcuts)

    Invoke-GuiDeferred -Action { Update-GuiHomeFacts }
}

function Update-GuiHomeFacts {
    if ($script:CurrentPage -ne "home") { return }

    $colors = @{ Normal = $script:Theme.Text; Ok = $script:Theme.Ok; Warn = $script:Theme.Warn; Muted = $script:Theme.Muted }

    try {
        # Cada leitura é independente: o que falhar vira "Não foi possível ler" e não apaga os outros fatos.
        $status = Get-WinForgeHomeStatus
    }
    catch {
        $status = $null
    }

    foreach ($id in @($script:HomeFacts.Keys)) {
        $block = $script:HomeFacts[$id]
        $fact = $null

        if ($null -ne $status) {
            $fact = @($status.Facts | Where-Object { $_.Id -eq $id }) | Select-Object -First 1
        }

        if ($null -eq $fact) {
            $block.Text = "Não foi possível ler"
            $block.Foreground = New-GuiBrush $script:Theme.Muted
        }
        else {
            $block.Text = $fact.Text
            $block.Foreground = New-GuiBrush $colors[[string]$fact.Level]
        }
    }

    if ($null -ne $status) {
        foreach ($notice in @($status.Notices)) {
            $banner = New-GuiPanelBorder -Background "#2A2110" -BorderColor "#7A5B12"
            $banner.Margin = New-Object System.Windows.Thickness (0, 0, 12, 14)
            $banner.Child = New-GuiText -Size 12 -Color $script:Theme.Warn -Text $notice.Text
            [void]$script:HomeBanner.Children.Add($banner)
        }
    }
}

function Show-GuiListPage {
    param ([Parameter(Mandatory)]$Page)

    $pageTitle.Text = $Page.Title
    $pageSubtitle.Text = $Page.Summary
    $contentPanel.Children.Clear()

    $panel = New-Object System.Windows.Controls.WrapPanel

    foreach ($item in $Page.Items) {
        [void]$panel.Children.Add((New-GuiActionCard -Item $item))
    }

    [void]$contentPanel.Children.Add($panel)
}

function New-GuiTweakRow {
    param ([Parameter(Mandatory)]$Tweak)

    $border = New-GuiPanelBorder
    $border.Margin = New-Object System.Windows.Thickness (0, 0, 0, 10)

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

    $description = New-GuiText -Text $Tweak.Description -Size 12 -Color $script:Theme.Muted
    $description.Margin = New-Object System.Windows.Thickness (0, 3, 0, 0)
    [void]$text.Children.Add($description)

    if (-not [string]::IsNullOrWhiteSpace($Tweak.LaptopNote)) {
        $warning = New-GuiText -Text "Atenção em notebook: $($Tweak.LaptopNote)" -Size 12 -Color $script:Theme.Warn
        $warning.Margin = New-Object System.Windows.Thickness (0, 3, 0, 0)
        [void]$text.Children.Add($warning)
    }

    [System.Windows.Controls.Grid]::SetColumn($text, 0)
    [void]$grid.Children.Add($text)

    $state = Get-WinForgeTweakSwitchState -Status $Tweak.Status
    $colors = @{ Ok = $script:Theme.Ok; Warn = $script:Theme.Warn; Muted = $script:Theme.Muted }

    $caption = New-GuiText -Text $state.Caption -Size 12 -Color $colors[[string]$state.Level] -Bold $true
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
    $toggle.ToolTip = "Ligue para aplicar; desligue para desfazer."
    [System.Windows.Automation.AutomationProperties]::SetName($toggle, $Tweak.Name)

    $toggle.Add_Click({
        param ($sender, $eventArgs)
        $tweak = $sender.Tag

        # A chave só mostra o estado real: volta ao que era e deixa a ação decidir (o novo estado aparece quando a
        # página é lida de novo, ao voltar). Assim, uma ação cancelada ou que falha nunca deixa a chave mentindo.
        $sender.IsChecked = (Get-WinForgeTweakSwitchState -Status $tweak.Status).IsOn

        try {
            Start-GuiAction -Label $tweak.Name -Command (Get-GuiTweakCommand -Id $tweak.Id)
        }
        catch {
            [void](Show-GuiMessage -Text $_.Exception.Message -Icon Error)
        }
    })

    [System.Windows.Controls.Grid]::SetColumn($toggle, 2)
    [void]$grid.Children.Add($toggle)

    $border.Child = $grid
    return $border
}

function Show-GuiTweaksPage {
    param ([Parameter(Mandatory)]$Page)

    $pageTitle.Text = $Page.Title
    $pageSubtitle.Text = $Page.Summary
    $contentPanel.Children.Clear()

    $bar = New-Object System.Windows.Controls.WrapPanel
    $bar.Margin = New-Object System.Windows.Thickness (0, 0, 0, 14)

    # As ações da página (aplicar recomendados, ponto de restauração, desfazer tudo) vêm da tabela de navegação.
    foreach ($item in $Page.Items) {
        $background = ""
        if ($item.Accent) { $background = $script:Theme.Accent }

        $actionButton = New-GuiButton -Text $item.Label -Background $background -Tag $item
        $actionButton.Margin = New-Object System.Windows.Thickness (0, 0, 10, 8)
        $actionButton.ToolTip = $item.Description
        $actionButton.Add_Click({
            param ($sender, $eventArgs)
            Invoke-GuiNavItem -Item $sender.Tag
        })
        [void]$bar.Children.Add($actionButton)
    }

    $refresh = New-GuiButton -Text "Atualizar estado"
    $refresh.Margin = New-Object System.Windows.Thickness (0, 0, 0, 8)
    $refresh.Add_Click({ Show-GuiPage -Id "tweaks" })
    [void]$bar.Children.Add($refresh)

    [void]$contentPanel.Children.Add($bar)

    $hint = New-GuiText -Text "Ligue a chave de um ajuste para aplicá-lo e desligue para desfazê-lo. O valor original é guardado." -Size 12 -Color $script:Theme.Muted
    $hint.Margin = New-Object System.Windows.Thickness (2, 0, 0, 6)
    [void]$contentPanel.Children.Add($hint)

    $loading = New-GuiText -Text "Lendo o estado atual dos ajustes..." -Color $script:Theme.Muted
    $loading.Tag = "loading"
    [void]$contentPanel.Children.Add($loading)

    Invoke-GuiDeferred -Action { Update-GuiTweaksList }
}

function Update-GuiTweaksList {
    if ($script:CurrentPage -ne "tweaks") { return }

    # Remove o aviso de carregamento e desenha a lista agrupada por categoria.
    foreach ($child in @($contentPanel.Children)) {
        if ($child -is [System.Windows.Controls.TextBlock] -and $child.Tag -eq "loading") {
            $contentPanel.Children.Remove($child)
        }
    }

    try {
        $lastCategory = ""

        foreach ($tweak in @(Get-WinForgeTweakOverview)) {
            if ($tweak.Category -ne $lastCategory) {
                $heading = New-GuiText -Text $tweak.Category -Size 13 -Color $script:Theme.AccentText -Bold $true
                $heading.Margin = New-Object System.Windows.Thickness (2, 8, 0, 8)
                [void]$contentPanel.Children.Add($heading)
                $lastCategory = $tweak.Category
            }

            [void]$contentPanel.Children.Add((New-GuiTweakRow -Tweak $tweak))
        }
    }
    catch {
        [void]$contentPanel.Children.Add((New-GuiText -Text "Não foi possível ler os ajustes: $($_.Exception.Message)" -Color $script:Theme.Bad))
    }
}

function Set-GuiSelectedNav {
    param ([string]$Id)

    foreach ($child in (@($navPanel.Children) + @($footerNav.Children))) {
        if ($child.Tag -eq $Id) {
            $child.Background = New-GuiBrush "#1F2D44"
            $child.Foreground = New-GuiBrush "#FFFFFF"
        }
        else {
            $child.Background = [System.Windows.Media.Brushes]::Transparent
            $child.Foreground = New-GuiBrush "#C9D4E0"
        }
    }
}

function Show-GuiPage {
    param ([Parameter(Mandatory)][string]$Id)

    $script:CurrentPage = $Id
    Set-GuiSelectedNav -Id $Id

    # Ao trocar de página, o painel de execução (já concluído) dá lugar ao conteúdo.
    $runView.Visibility = "Collapsed"
    $pagesView.Visibility = "Visible"
    $pageScroll.ScrollToTop()

    if ($Id -eq "home") {
        Show-GuiHomePage
        return
    }

    $page = Get-WinForgeNavPage -Id $Id

    if ($null -eq $page) {
        $script:CurrentPage = "home"
        Set-GuiSelectedNav -Id "home"
        Show-GuiHomePage
        return
    }

    if ($page.Kind -eq "Tweaks") {
        Show-GuiTweaksPage -Page $page
    }
    else {
        Show-GuiListPage -Page $page
    }
}

# --- Barra lateral: Início + páginas da tabela de navegação (as de rodapé ficam embaixo) -----------------------
function Add-GuiNavButton {
    param ([string]$Id, [string]$Title, [bool]$Footer = $false)

    $button = New-Object System.Windows.Controls.Button
    $button.Style = $window.FindResource("NavButton")
    $button.Content = $Title
    $button.Tag = $Id
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

Add-GuiNavButton -Id "home" -Title "Início"

foreach ($navPage in @(Get-WinForgeNavigation)) {
    Add-GuiNavButton -Id $navPage.Id -Title $navPage.Title -Footer ($navPage.Placement -eq "Footer")
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

$stopButton.Add_Click({
    $answer = Show-GuiMessage -Buttons YesNo -Icon Question -Text "Interromper a ação em andamento?`n`nO que já foi feito continua feito, mas a etapa atual fica incompleta. Ferramentas como DISM, SFC e winget são encerradas."

    if ($answer -eq "Yes" -and $script:Running -and $null -ne $script:GuiSession) {
        Set-GuiRunStatus -Text "Interrompendo..." -DotColor $script:Theme.Warn
        Stop-WinForgeGuiCommand -Session $script:GuiSession
    }
})

$copyButton.Add_Click({
    try {
        $range = New-Object System.Windows.Documents.TextRange ($outputBox.Document.ContentStart, $outputBox.Document.ContentEnd)
        [System.Windows.Clipboard]::SetText($range.Text)
        $copyButton.Content = "Copiado"
    }
    catch {
        [void](Show-GuiMessage -Icon Warning -Text "Não foi possível copiar: $($_.Exception.Message)")
    }
})

$backButton.Add_Click({
    $copyButton.Content = "Copiar saída"
    Show-GuiPage -Id $script:CurrentPage
})

$promptSend.Add_Click({ Submit-GuiPrompt -Answer $promptInput.Text })

$promptInput.Add_KeyDown({
    param ($sender, $eventArgs)

    if ($eventArgs.Key -eq "Return") {
        $eventArgs.Handled = $true
        Submit-GuiPrompt -Answer $sender.Text
    }
})

$window.Add_Closing({
    param ($sender, $eventArgs)

    if ($script:Running) {
        $answer = Show-GuiMessage -Buttons YesNo -Icon Warning -Text "Há uma ação em andamento. Interromper e sair?"

        if ($answer -ne "Yes") {
            $eventArgs.Cancel = $true
            return
        }

        Stop-WinForgeGuiCommand -Session $script:GuiSession
    }

    $script:Timer.Stop()
    $script:DeferredTimer.Stop()
    Set-GuiTaskbarProgress -State None

    if ($null -ne $script:GuiSession) {
        Close-WinForgeGuiSession -Session $script:GuiSession
    }
})

$window.Dispatcher.Add_UnhandledException({
    param ($sender, $eventArgs)
    $eventArgs.Handled = $true
    [void](Show-GuiMessage -Text "Erro inesperado: $($eventArgs.Exception.Message)" -Icon Error)
})

Reset-GuiOutput
Show-GuiPage -Id "home"
[void]$window.ShowDialog()
