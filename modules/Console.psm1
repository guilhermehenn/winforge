# Console: cabeçalhos, mensagens padronizadas e perguntas.
# Na interface gráfica as perguntas viram botões e listas de marcação; no console, o texto de sempre.

$script:WinForgeMaxInvalidAnswers = 10


# ---------------------------------------------------------------------------
# Aparência do console
# ---------------------------------------------------------------------------

function Get-WinForgeConsoleWidth {
    try {
        if (Test-WinForgeGuiMode) {
            # Na interface gráfica a largura vem do painel de saída (o host personalizado).
            $width = $Host.UI.RawUI.WindowSize.Width - 1
        }
        else {
            $width = [Console]::WindowWidth - 1
        }
    }
    catch {
        $width = 72
    }

    return [Math]::Min(96, [Math]::Max(60, $width))
}


function Test-WinForgeUnicodeConsole {
    # Defina WINFORGE_ASCII=1 para forçar o modo ASCII em fontes/consoles sem caracteres de moldura.
    if ($env:WINFORGE_ASCII -eq "1") {
        return $false
    }

    if (Test-WinForgeGuiMode) {
        return $true
    }

    try {
        return ([Console]::OutputEncoding.CodePage -eq 65001)
    }
    catch {
        return $false
    }
}


function Get-WinForgeGlyphs {
    if (Test-WinForgeUnicodeConsole) {
        return @{
            TL = [string][char]0x250C; TR = [string][char]0x2510
            BL = [string][char]0x2514; BR = [string][char]0x2518
            H  = [string][char]0x2500; V  = [string][char]0x2502
            Dot = [string][char]0x25CF; Sep = [string][char]0x203A
            Full = [string][char]0x2588; Empty = [string][char]0x2591
        }
    }

    return @{
        TL = "+"; TR = "+"; BL = "+"; BR = "+"
        H = "-"; V = "|"; Dot = "*"; Sep = ">"
        Full = "#"; Empty = "."
    }
}


function Show-WinForgeHeader {
    param (
        [string]$Title
    )

    $glyphs = Get-WinForgeGlyphs
    $width = Get-WinForgeConsoleWidth
    $inner = $width - 2

    if (Test-WinForgeGuiMode) {
        # A janela já mostra o título da ação; aqui entra apenas um separador discreto, sem limpar a saída.
        if ($Title -ne "WinForge") {
            Write-Host ""
            Write-Host "  $Title" -ForegroundColor Cyan
            Write-Host ("  " + ($glyphs.H * $inner)) -ForegroundColor DarkCyan
            Write-Host ""
        }

        return
    }

    Clear-Host
    Write-Host ""

    if ($Title -eq "WinForge") {
        $titleText = "WinForge  $($glyphs.Dot)  Build $(Get-WinForgeBuild)"
        $subtitleText = "Manutenção, diagnóstico e ajustes do Windows"

        Write-Host ("  " + $glyphs.TL + ($glyphs.H * $inner) + $glyphs.TR) -ForegroundColor DarkCyan
        Write-Host ("  " + $glyphs.V) -ForegroundColor DarkCyan -NoNewline
        Write-Host (("  " + $titleText).PadRight($inner)) -ForegroundColor Cyan -NoNewline
        Write-Host $glyphs.V -ForegroundColor DarkCyan
        Write-Host ("  " + $glyphs.V) -ForegroundColor DarkCyan -NoNewline
        Write-Host (("  " + $subtitleText).PadRight($inner)) -ForegroundColor DarkGray -NoNewline
        Write-Host $glyphs.V -ForegroundColor DarkCyan
        Write-Host ("  " + $glyphs.BL + ($glyphs.H * $inner) + $glyphs.BR) -ForegroundColor DarkCyan

        Write-WinForgeStatusBar
    }
    else {
        Write-Host "  WinForge " -ForegroundColor DarkGray -NoNewline
        Write-Host "$($glyphs.Sep) " -ForegroundColor DarkCyan -NoNewline
        Write-Host $Title -ForegroundColor Cyan
        Write-Host ("  " + ($glyphs.H * $inner)) -ForegroundColor DarkCyan
    }

    Write-Host ""
}


function Write-WinForgeStatusBar {
    $glyphs = Get-WinForgeGlyphs
    $session = Get-WinForgeSessionInfo

    $items = @()
    $items += [PSCustomObject]@{ Text = $(if ($session.IsAdmin) { "Administrador" } else { "Sem privilégios" }); Color = $(if ($session.IsAdmin) { "Green" } else { "Red" }) }
    $items += [PSCustomObject]@{ Text = $session.User; Color = $(if ($session.UserMismatch) { "Yellow" } else { "Gray" }) }
    $items += [PSCustomObject]@{ Text = $(if ($session.IsLaptop) { "Notebook" } else { "Desktop" }); Color = "Gray" }
    $items += [PSCustomObject]@{ Text = "$($session.WindowsLabel) ($($session.WindowsBuild))"; Color = "Gray" }

    if ((Get-Command Test-WinForgePendingReboot -ErrorAction SilentlyContinue) -and (Test-WinForgePendingReboot)) {
        $items += [PSCustomObject]@{ Text = "Reinício pendente"; Color = "Yellow" }
    }

    Write-Host "  " -NoNewline

    foreach ($item in $items) {
        Write-Host "$($glyphs.Dot) " -ForegroundColor DarkGray -NoNewline
        Write-Host "$($item.Text)   " -ForegroundColor $item.Color -NoNewline
    }

    Write-Host ""

    if ($session.UserMismatch) {
        Write-Host "  [!] Elevado com outra conta: ajustes de usuário e Downloads afetam este perfil, não o usuário logado." -ForegroundColor Yellow
    }
}


# ---------------------------------------------------------------------------
# Mensagens
# ---------------------------------------------------------------------------

function Write-WinForgeMenuItem {
    param (
        [string]$Key,
        [string]$Label,
        [string]$Description = "",
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
    Write-Host $Key.PadLeft(2) -ForegroundColor $keyColor -NoNewline
    Write-Host "] " -ForegroundColor DarkGray -NoNewline
    Write-Host $Label -ForegroundColor $labelColor -NoNewline

    if (-not [string]::IsNullOrWhiteSpace($Description)) {
        Write-Host "  $Description" -ForegroundColor DarkGray -NoNewline
    }

    Write-Host ""
}


function Write-WinForgeSection {
    param (
        [string]$Title
    )

    $glyphs = Get-WinForgeGlyphs
    $ruleLength = [Math]::Min((Get-WinForgeConsoleWidth) - 4, [Math]::Max(12, $Title.Length + 4))

    Write-Host ""
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host ("  " + ($glyphs.H * $ruleLength)) -ForegroundColor DarkGray
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


function Write-WinForgeProgress {
    param (
        [int]$Current,
        [int]$Total,
        [string]$Label = "",
        [int]$BarWidth = 24
    )

    $glyphs = Get-WinForgeGlyphs

    if ($Total -le 0) { $Total = 1 }

    $ratio = [Math]::Min(1.0, [Math]::Max(0.0, $Current / $Total))
    $filled = [int][Math]::Round($ratio * $BarWidth)
    $bar = ($glyphs.Full * $filled) + ($glyphs.Empty * ($BarWidth - $filled))
    $percent = [int][Math]::Round($ratio * 100)

    Write-Host "  " -NoNewline
    Write-Host $bar -ForegroundColor Cyan -NoNewline
    Write-Host ("  {0,3}%  ({1}/{2})  " -f $percent, $Current, $Total) -ForegroundColor DarkGray -NoNewline
    Write-Host $Label -ForegroundColor Gray
}


function Write-WinForgeResultTable {
    # Resumo de etapas: objetos com Etapa, Status, Duracao e (opcional) Kind = Ok | Skipped | Warning | Failed.
    param (
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Results
    )

    if (@($Results).Count -eq 0) {
        Write-Host "  Nenhuma etapa foi executada." -ForegroundColor DarkGray
        return
    }

    $nameWidth = 20

    foreach ($result in $Results) {
        $nameValue = [string]$result.Etapa
        if ($nameValue.Length -gt $nameWidth) { $nameWidth = $nameValue.Length }
    }

    foreach ($result in $Results) {
        $kind = [string]$result.Kind

        if ([string]::IsNullOrEmpty($kind)) {
            $kind = switch -Wildcard ([string]$result.Status) {
                "OK*"      { "Ok" }
                "Falhou*"  { "Failed" }
                "Ignorad*" { "Skipped" }
                default    { "Warning" }
            }
        }

        switch ($kind) {
            "Ok"      { $badge = "[OK]"; $color = "Green" }
            "Failed"  { $badge = "[X] "; $color = "Red" }
            "Skipped" { $badge = "[-] "; $color = "DarkGray" }
            default   { $badge = "[!] "; $color = "Yellow" }
        }

        $duration = ""
        if (-not [string]::IsNullOrWhiteSpace([string]$result.Duracao)) {
            $duration = "  " + [string]$result.Duracao
        }

        Write-Host "  $badge " -ForegroundColor $color -NoNewline
        Write-Host ([string]$result.Etapa).PadRight($nameWidth) -ForegroundColor Gray -NoNewline
        Write-Host "  $($result.Status)" -ForegroundColor $color -NoNewline
        Write-Host $duration -ForegroundColor DarkGray
    }
}


# ---------------------------------------------------------------------------
# Moldura padrão das ações e resultado de etapa
# ---------------------------------------------------------------------------

function Enter-WinForgeAction {
    # Abertura de uma ação: cabeçalho completo quando ela é chamada sozinha, apenas uma seção quando faz parte de um fluxo.
    # Na janela gráfica o título da ação já aparece acima da saída (é o nome do botão clicado, igual a este), então
    # repeti-lo na saída só gastaria espaço.
    param (
        [Parameter(Mandatory)]
        [string]$Title,

        [switch]$Embedded
    )

    if ($Embedded) {
        Write-WinForgeSection -Title $Title
    }
    elseif (-not (Test-WinForgeGuiMode)) {
        Show-WinForgeHeader $Title
    }
}


function Exit-WinForgeAction {
    # Encerramento de uma ação chamada sozinha. Na interface gráfica o botão Voltar já faz esse papel.
    param (
        [switch]$Embedded
    )

    if (-not $Embedded) {
        Write-Host ""
        Wait-WinForgeKey
    }
}


function New-WinForgeResult {
    <#
    Resultado de uma etapa de fluxo (Manutenção recomendada). Só aparece no pipeline quando a ação recebe -PassThru.
    Status é o texto para a pessoa ("OK", "Atenção (...)"). Quem toma decisões (pedir reinício, oferecer uma nova
    tentativa) lê Kind e Data, nunca o texto do Status: Data leva fatos como RebootRequired = $true.
    #>
    param (
        [ValidateSet("Ok", "Skipped", "Warning", "Failed")]
        [string]$Kind = "Ok",

        [string]$Detail = "",

        [string]$Title = "",

        [hashtable]$Data = @{}
    )

    $status = switch ($Kind) {
        "Ok"      { "OK" }
        "Skipped" { "Ignorado" }
        "Warning" { "Atenção" }
        "Failed"  { "Falhou" }
    }

    if (-not [string]::IsNullOrWhiteSpace($Detail)) {
        $status += " ($Detail)"
    }

    return [PSCustomObject]@{
        PSTypeName = "WinForge.Result"
        Kind       = $Kind
        Etapa      = $Title
        Status     = $status
        Detail     = $Detail
        Duracao    = ""
        Data       = $Data
    }
}


function Get-WinForgeResultData {
    # Lê um fato de Data (por exemplo FreedBytes) sem depender de a chave, ou do próprio Data, existir. Falta = $null.
    param (
        $Result,

        [Parameter(Mandatory)]
        [string]$Name
    )

    if ($null -eq $Result -or -not ($Result.PSObject.Properties.Name -contains "Data")) {
        return $null
    }

    $data = $Result.Data

    if ($data -is [System.Collections.IDictionary] -and $data.Contains($Name)) {
        return $data[$Name]
    }

    return $null
}


function Test-WinForgeResultFlag {
    # Fato booleano de Data (por exemplo RebootRequired); ausente conta como falso.
    param (
        $Result,

        [Parameter(Mandatory)]
        [string]$Name
    )

    return [bool](Get-WinForgeResultData -Result $Result -Name $Name)
}


function Test-WinForgeElevation {
    # Verdadeiro quando o processo é Administrador; caso contrário mostra o motivo e devolve falso.
    param (
        [string]$Reason = "Esta ação exige privilégios de Administrador."
    )

    if (Test-WinForgeAdministrator) {
        return $true
    }

    Write-WinForgeStatus -Type Error -Message $Reason
    Write-Host "      Feche o WinForge e abra-o novamente como Administrador." -ForegroundColor DarkGray
    return $false
}


# ---------------------------------------------------------------------------
# Perguntas
# ---------------------------------------------------------------------------

function Test-WinForgeGuiPrompts {
    # Verdadeiro quando a interface gráfica fornece botões e listas de marcação para as perguntas.
    $guiHost = Get-Variable -Name WinForgeGuiHost -Scope Global -ErrorAction SilentlyContinue

    return ((Test-WinForgeGuiMode) -and $null -ne $guiHost -and $null -ne $guiHost.Value)
}


function Wait-WinForgeKey {
    # "Pressione qualquer tecla" do console. Na interface gráfica não há o que esperar: o botão Voltar faz esse papel.
    param (
        [string]$Message = "Pressione qualquer tecla para continuar..."
    )

    if (Test-WinForgeGuiMode) {
        return
    }

    Write-Host "  $Message" -ForegroundColor DarkGray

    try {
        [void]$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
    catch {
        # Hosts sem teclado direto (ISE, entrada redirecionada): usa ENTER.
        try { [void](Read-Host) } catch { }
    }
}


function Confirm-WinForgeAction {
    # Pergunta Sim/Não. DefaultKey ("S" ou "N") destaca o botão na interface gráfica e vale para ENTER no console.
    param (
        [string]$Message = "Deseja continuar?",

        [ValidateSet("", "S", "N")]
        [string]$DefaultKey = ""
    )

    if (Test-WinForgeGuiPrompts) {
        $answer = Read-WinForgeChoice -Message $Message -DefaultKey $(if ($DefaultKey) { $DefaultKey } else { "S" }) -Options @(
            @{ Key = "S"; Label = "Sim"; Accent = ($DefaultKey -ne "N") },
            @{ Key = "N"; Label = "Não"; Accent = ($DefaultKey -eq "N") }
        )

        return ($answer -eq "S")
    }

    $hint = switch ($DefaultKey) {
        "S"     { "S/n" }
        "N"     { "s/N" }
        default { "S/N" }
    }

    for ($attempt = 0; $attempt -lt $script:WinForgeMaxInvalidAnswers; $attempt++) {
        $answer = ([string](Read-Host "$Message ($hint)")).Trim().ToUpperInvariant()

        if ([string]::IsNullOrEmpty($answer) -and $DefaultKey) {
            $answer = $DefaultKey
        }

        switch ($answer) {
            { $_ -in @("S", "SIM", "Y", "YES") } { return $true }
            { $_ -in @("N", "NAO", "NÃO", "NO") } { return $false }
            default {
                Write-Host "Opção inválida. Digite S ou N." -ForegroundColor Red
            }
        }
    }

    throw "Nenhuma resposta válida foi informada."
}


function Get-WinForgeOptionField {
    # Lê um campo opcional de uma opção de pergunta (hashtable ou objeto). Campo ausente devolve $Default;
    # funciona também sob Set-StrictMode, que recusa "$hashtable.ChaveQueNaoExiste".
    param (
        $Option,

        [Parameter(Mandatory)]
        [string]$Name,

        $Default = $null
    )

    if ($Option -is [System.Collections.IDictionary]) {
        if ($Option.Contains($Name)) { return $Option[$Name] }

        return $Default
    }

    $property = $Option.PSObject.Properties[$Name]

    if ($null -ne $property) { return $property.Value }

    return $Default
}


function ConvertTo-WinForgeOptionList {
    # Normaliza as opções de Read-WinForgeChoice/Read-WinForgeMultiSelect: todos os campos existem, com o tipo certo.
    param (
        [object[]]$Options
    )

    foreach ($option in @($Options)) {
        [PSCustomObject]@{
            Key         = [string](Get-WinForgeOptionField $option "Key" "")
            Label       = [string](Get-WinForgeOptionField $option "Label" "")
            Description = [string](Get-WinForgeOptionField $option "Description" "")
            Accent      = [bool](Get-WinForgeOptionField $option "Accent" $false)
            Exit        = [bool](Get-WinForgeOptionField $option "Exit" $false)
            Selected    = [bool](Get-WinForgeOptionField $option "Selected" $false)
        }
    }
}


function Read-WinForgeChoice {
    <#
    Pergunta de escolha única. Na interface gráfica vira botões; no console, o menu de sempre.
    Options: hashtables/objetos com Key, Label e, opcionalmente, Description, Accent e Exit (opção de sair/cancelar).
    Retorna a Key escolhida.
    #>
    param (
        [string]$Message = "Selecione uma opção",
        [Parameter(Mandatory)]
        [object[]]$Options,
        [string]$DefaultKey = "",
        [string]$TextPrompt = "",
        [switch]$ShowMenu
    )

    $items = @(ConvertTo-WinForgeOptionList -Options $Options)

    if (Test-WinForgeGuiPrompts) {
        $converted = @(
            foreach ($option in $items) {
                $guiOption = New-Object WinForge.GuiOption
                $guiOption.Key = $option.Key
                $guiOption.Label = $option.Label
                $guiOption.Description = $option.Description
                $guiOption.Accent = $option.Accent
                $guiOption.Exit = $option.Exit
                $guiOption
            }
        )

        return [string]$global:WinForgeGuiHost.GuiUI.AskChoice("", $Message, $converted, $DefaultKey)
    }

    if ($ShowMenu) {
        foreach ($option in $items) {
            Write-WinForgeMenuItem -Key $option.Key -Label $option.Label -Description $option.Description -Accent:$option.Accent -Exit:$option.Exit
        }

        Write-Host ""
    }

    $prompt = $Message

    if (-not [string]::IsNullOrWhiteSpace($TextPrompt)) {
        $prompt = $TextPrompt
    }

    for ($attempt = 0; $attempt -lt $script:WinForgeMaxInvalidAnswers; $attempt++) {
        $answer = ([string](Read-Host $prompt)).Trim()

        if ([string]::IsNullOrEmpty($answer) -and -not [string]::IsNullOrEmpty($DefaultKey)) {
            return $DefaultKey
        }

        $match = @($items | Where-Object { $_.Key -ieq $answer }) | Select-Object -First 1

        if ($null -ne $match) {
            return $match.Key
        }

        Write-Host "Opção inválida." -ForegroundColor Red
    }

    throw "Nenhuma resposta válida foi informada."
}


function Read-WinForgeMultiSelect {
    <#
    Seleção múltipla. Na interface gráfica vira uma lista de marcação; no console, uma lista numerada
    ("1,3,5-7", T = todos, ENTER = cancelar). Options: Key, Label, Description e, opcionalmente, Selected.
    Retorna as Keys marcadas, ou $null se o usuário cancelar ou não marcar nada (o PowerShell não distingue uma
    lista vazia de $null no retorno de uma função, então os chamadores tratam os dois casos como "nada escolhido").
    #>
    param (
        [string]$Message = "Selecione os itens",
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Options
    )

    $items = @(ConvertTo-WinForgeOptionList -Options $Options)

    if ($items.Count -eq 0) {
        return $null
    }

    if (Test-WinForgeGuiPrompts) {
        $converted = @(
            foreach ($option in $items) {
                $guiOption = New-Object WinForge.GuiOption
                $guiOption.Key = $option.Key
                $guiOption.Label = $option.Label
                $guiOption.Description = $option.Description
                $guiOption.Selected = $option.Selected
                $guiOption
            }
        )

        $keys = $global:WinForgeGuiHost.GuiUI.AskMulti("", $Message, $converted)

        if ($null -eq $keys) {
            return $null
        }

        return @($keys)
    }

    for ($i = 0; $i -lt $items.Count; $i++) {
        $mark = if ($items[$i].Selected) { "*" } else { " " }

        Write-Host "  " -NoNewline
        Write-Host ("[{0,2}]{1}" -f ($i + 1), $mark) -ForegroundColor Cyan -NoNewline
        Write-Host (" {0}" -f $items[$i].Label.PadRight(30)) -ForegroundColor Gray -NoNewline
        Write-Host $items[$i].Description -ForegroundColor DarkGray
    }

    $preselected = @($items | Where-Object { $_.Selected })

    Write-Host ""
    Write-Host "  Informe números separados por vírgula ou intervalos (ex.: 1,3,5-7). T = todos. ENTER = cancelar." -ForegroundColor DarkCyan

    if ($preselected.Count -gt 0) {
        Write-Host "  P = manter os itens marcados com * ($($preselected.Count))." -ForegroundColor DarkCyan
    }

    Write-Host ""

    for ($attempt = 0; $attempt -lt $script:WinForgeMaxInvalidAnswers; $attempt++) {
        $inputText = ([string](Read-Host $Message)).Trim()

        if ([string]::IsNullOrWhiteSpace($inputText)) {
            return $null
        }

        if ($inputText -ieq "T") {
            return @($items | ForEach-Object { $_.Key })
        }

        if ($inputText -ieq "P" -and $preselected.Count -gt 0) {
            return @($preselected | ForEach-Object { $_.Key })
        }

        try {
            $indexes = @(ConvertTo-WinForgeSelectionIndexes -InputText $inputText -Maximum $items.Count)
            return @($indexes | ForEach-Object { $items[$_ - 1].Key })
        }
        catch {
            Write-WinForgeStatus -Type Error -Message $_.Exception.Message
        }
    }

    throw "Nenhuma resposta válida foi informada."
}


function Read-WinForgeText {
    # Texto livre (termo de busca, ID de pacote). Na interface gráfica usa a caixa de texto da barra de perguntas.
    # Retorna o texto sem espaços nas pontas; vazio significa que o usuário desistiu.
    param (
        [Parameter(Mandatory)]
        [string]$Message
    )

    return ([string](Read-Host $Message)).Trim()
}


Export-ModuleMember -Function *
