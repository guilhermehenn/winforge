# Console: cabeçalhos, mensagens padronizadas e perguntas.
# Na interface gráfica as perguntas viram botões e listas de marcação; no console, o texto de sempre.

# Respostas inválidas seguidas que uma pergunta do console aceita antes de desistir. Com a entrada redirecionada (um
# script, uma tarefa) o limite é curto: a entrada pode ter acabado. Com alguém digitando, errar não fecha nada; o teto
# alto só impede um laço sem fim.
$script:WinForgeMaxInvalidAnswers = 10
$script:WinForgeMaxTypedAnswers = 1000

# Resultado da ação em andamento: o que as ações registraram de forma explícita (Set-WinForgeOutcome) e a contagem das
# mensagens de estado (Write-WinForgeStatus). A janela e o modo de linha de comando leem isto quando a ação termina.
$script:WinForgeOutcomeState = $null

# Ações inteiras que rodam dentro de um fluxo (Invoke-WinForgeNestedAction), como as etapas com você do Otimizar:
# quantas estão abertas agora e o resultado com que a mais recente terminou.
$script:WinForgeNestedDepth = 0
$script:WinForgeNestedResult = $null


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


function Get-WinForgeWrapWidth {
    # Até que coluna uma linha do console pode ir antes de continuar embaixo, com recuo (o Windows continuaria na coluna 0,
    # embaixo dos números do menu). 0 = não quebrar: na janela (o resumo quebra sozinho), com a saída indo para um arquivo
    # ou quando a largura não pode ser lida.
    if (Test-WinForgeGuiMode) {
        return 0
    }

    try {
        if ([Console]::IsOutputRedirected) {
            return 0
        }

        $width = [Console]::WindowWidth
        $buffer = [Console]::BufferWidth

        if ($buffer -gt 0 -and $buffer -lt $width) {
            $width = $buffer
        }

        if ($width -lt 40) {
            return 0
        }

        # Uma linha que ocupa a largura inteira já leva o cursor para a linha de baixo.
        return ($width - 1)
    }
    catch {
        return 0
    }
}


function Split-WinForgeWrappedText {
    # Quebra um texto em linhas de no máximo -Width caracteres, nos espaços (uma palavra maior que a linha é cortada).
    param (
        [AllowEmptyString()]
        [string]$Text,

        [int]$Width
    )

    if ($Width -lt 1 -or $Text.Length -le $Width) {
        return $Text
    }

    $lines = New-Object System.Collections.Generic.List[string]
    $current = ""

    foreach ($word in ($Text -split ' ')) {
        if ($word.Length -eq 0) { continue }

        while ($word.Length -gt $Width) {
            if ($current.Length -gt 0) { $lines.Add($current); $current = "" }
            $lines.Add($word.Substring(0, $Width))
            $word = $word.Substring($Width)
        }

        if ($current.Length -eq 0) {
            $current = $word
        }
        elseif ($current.Length + 1 + $word.Length -le $Width) {
            $current += " " + $word
        }
        else {
            $lines.Add($current)
            $current = $word
        }
    }

    if ($current.Length -gt 0 -or $lines.Count -eq 0) {
        $lines.Add($current)
    }

    return $lines.ToArray()
}


function Write-WinForgeWrappedLine {
    <#
    Uma linha de texto com recuo. No console, o que passa da largura da janela continua na linha de baixo com o mesmo
    recuo (depois do -Prefix, como "[OK] "), em vez de voltar para a coluna 0. Na janela, sai igual, numa linha só.
    #>
    param (
        [AllowEmptyString()]
        [string]$Text,

        [int]$Indent = 2,

        [string]$Color = "Gray",

        [string]$Prefix = "",

        [string]$PrefixColor = "Gray"
    )

    $lead = " " * $Indent
    $hang = " " * ($Indent + $Prefix.Length)
    $width = Get-WinForgeWrapWidth
    $lines = @($Text)

    if ($width -gt 0 -and ($hang.Length + $Text.Length) -gt $width) {
        $lines = @(Split-WinForgeWrappedText -Text $Text -Width ([Math]::Max(20, $width - $hang.Length)))
    }

    if ($Prefix.Length -gt 0) {
        Write-Host ($lead + $Prefix) -ForegroundColor $PrefixColor -NoNewline
        Write-Host $lines[0] -ForegroundColor $Color
    }
    else {
        Write-Host ($lead + $lines[0]) -ForegroundColor $Color
    }

    for ($i = 1; $i -lt $lines.Count; $i++) {
        Write-Host ($hang + $lines[$i]) -ForegroundColor $Color
    }
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
    # Cada linha ocupa $width colunas: o traço tem 2 de recuo; a caixa, 2 de recuo e as 2 bordas.
    $rule = $width - 2
    $inner = $width - 4

    if (Test-WinForgeGuiMode) {
        # A janela já mostra o título da ação; aqui entra apenas um separador discreto, sem limpar a saída.
        if ($Title -ne "WinForge") {
            Write-Host ""
            Write-Host "  $Title" -ForegroundColor Cyan
            Write-Host ("  " + ($glyphs.H * $rule)) -ForegroundColor DarkCyan
            Write-Host ""
        }

        return
    }

    Clear-Host
    Write-Host ""

    if ($Title -eq "WinForge") {
        $titleText = (Get-WinForgeText 'WinForge  {0}  versão {1}' "$($glyphs.Dot)" "$(Get-WinForgeBuild)")
        $subtitleText = (Get-WinForgeText 'Manutenção, diagnóstico e ajustes do Windows')

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
        Write-Host ("  " + ($glyphs.H * $rule)) -ForegroundColor DarkCyan
    }

    Write-Host ""
}


function Write-WinForgeStatusBar {
    $glyphs = Get-WinForgeGlyphs
    $session = Get-WinForgeSessionInfo

    # O menu de texto só abre como Administrador: a marca aparece quando falta, e não o tempo todo.
    # O usuário e o Windows saem como no cartão do Início ("ana", "Windows 11 Home 24H2").
    $user = [string]$session.User
    $computer = $env:COMPUTERNAME
    if ([string]::IsNullOrWhiteSpace($computer)) { $computer = [Environment]::MachineName }

    if (Get-Command Get-WinForgeUserDisplayName -ErrorAction SilentlyContinue) {
        $user = Get-WinForgeUserDisplayName -Name $user -Computer $computer
    }

    $windows = [string](Get-WinForgeJsonValue -Object $session -Name "WindowsName" -Default "")
    if ([string]::IsNullOrWhiteSpace($windows)) { $windows = [string]$session.WindowsLabel }

    $version = [string](Get-WinForgeJsonValue -Object $session -Name "WindowsVersion" -Default "")
    if (-not [string]::IsNullOrWhiteSpace($version)) { $windows += " $version" }

    $items = @()

    if (-not $session.IsAdmin) {
        $items += [PSCustomObject]@{ Text = (Get-WinForgeText 'Sem Administrador'); Color = "Yellow" }
    }

    $items += [PSCustomObject]@{ Text = $user; Color = $(if ($session.UserMismatch) { "Yellow" } else { "Gray" }) }
    $items += [PSCustomObject]@{ Text = $(if ($session.IsLaptop) { (Get-WinForgeText 'Notebook') } else { "Desktop" }); Color = "Gray" }
    $items += [PSCustomObject]@{ Text = $windows; Color = "Gray" }

    if ((Get-Command Test-WinForgePendingReboot -ErrorAction SilentlyContinue) -and (Test-WinForgePendingReboot)) {
        $items += [PSCustomObject]@{ Text = (Get-WinForgeText 'Reinício pendente'); Color = "Yellow" }
    }

    Write-Host "  " -NoNewline

    for ($i = 0; $i -lt $items.Count; $i++) {
        if ($i -gt 0) { Write-Host "   " -NoNewline }
        Write-Host "$($glyphs.Dot) " -ForegroundColor DarkGray -NoNewline
        Write-Host $items[$i].Text -ForegroundColor $items[$i].Color -NoNewline
    }

    Write-Host ""

    if ($session.UserMismatch) {
        Write-Host (Get-WinForgeText '  [!] Elevado com outra conta: ajustes de usuário e Downloads afetam este perfil, não o usuário logado.') -ForegroundColor Yellow
    }
}


# ---------------------------------------------------------------------------
# Mensagens
# ---------------------------------------------------------------------------

function Write-WinForgeMenuItem {
    # -Recommended: escreve "(recomendado)" depois do nome, como a marca "Recomendado" do cartão na janela (a cor sozinha
    # não diz nada a quem não a distingue). Uma descrição que não cabe na linha vai para baixo do nome, com o mesmo recuo.
    param (
        [string]$Key,
        [string]$Label,
        [string]$Description = "",
        [switch]$Accent,
        [switch]$Exit,
        [switch]$Recommended
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

    $keyText = $Key.PadLeft(2)
    $tag = $(if ($Recommended -and $Label -notmatch '(?i)recomendad') { (Get-WinForgeText ' (recomendado)') } else { "" })

    Write-Host "  [" -ForegroundColor DarkGray -NoNewline
    Write-Host $keyText -ForegroundColor $keyColor -NoNewline
    Write-Host "] " -ForegroundColor DarkGray -NoNewline
    Write-Host $Label -ForegroundColor $labelColor -NoNewline

    if ($tag) {
        Write-Host $tag -ForegroundColor Green -NoNewline
    }

    if (-not [string]::IsNullOrWhiteSpace($Description)) {
        $indent = 4 + $keyText.Length + 1
        $width = Get-WinForgeWrapWidth

        if ($width -gt 0 -and ($indent + $Label.Length + $tag.Length + 2 + $Description.Length) -gt $width) {
            Write-Host ""

            foreach ($line in @(Split-WinForgeWrappedText -Text $Description -Width ([Math]::Max(20, $width - $indent)))) {
                Write-Host ((" " * $indent) + $line) -ForegroundColor DarkGray
            }

            return
        }

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
    # Level pinta o valor: Ok verde, Warn amarelo, Bad vermelho. O resumo da janela lê a cor e pinta o valor também, para
    # o que pede atenção saltar aos olhos numa lista de dados.
    param (
        [string]$Label,
        [object]$Value,
        [int]$LabelWidth = 24,
        [ValidateSet("Normal", "Ok", "Warn", "Bad")][string]$Level = "Normal"
    )

    $valueText = if ($null -eq $Value) {
        (Get-WinForgeText 'Não disponível')
    }
    elseif ($Value -is [System.Array]) {
        ($Value | ForEach-Object { $_.ToString() }) -join ", "
    }
    elseif ([string]::IsNullOrWhiteSpace($Value.ToString())) {
        (Get-WinForgeText 'Não disponível')
    }
    else {
        $Value.ToString()
    }

    Write-Host "  " -NoNewline
    Write-Host ($Label.PadRight($LabelWidth)) -ForegroundColor DarkGray -NoNewline
    Write-Host " : " -ForegroundColor DarkGray -NoNewline
    Write-Host $valueText -ForegroundColor $(switch ($Level) { "Ok" { "Green" } "Warn" { "Yellow" } "Bad" { "Red" } default { "Gray" } })
}


function ConvertTo-WinForgeReadableError {
    <#
    Um texto de erro do jeito que a pessoa deve ler, numa linha: sem o embrulho do PowerShell em volta da mensagem do
    Windows ('Exception calling "Search" with "1" argument(s): "..."', ou 'Exceção ao chamar ... com ... argumento(s)'),
    e com um comando que não existe neste Windows dito no idioma da tela, sem as duas linhas de "verifique a grafia" que o
    PowerShell acrescenta. Texto sem nada disso volta igual.
    #>
    param ([AllowEmptyString()][AllowNull()][string]$Text)

    if ([string]::IsNullOrEmpty($Text)) { return [string]$Text }

    $result = $Text
    # Em espanhol, 'Excepción al llamar a "..." con "1" argumento(s)': o que vem depois do número varia por idioma.
    $wrapper = '(?s)(Exception calling|Exceção ao chamar|Excepci.n al llamar a) "[^"]+" (with|com|con) "[0-9]+" [^:"]{1,24}: "(?<inner>.*)"(?<tail>[.\s]*)\z'

    for ($i = 0; $i -lt 5 -and $result -match $wrapper; $i++) {
        $result = $result.Substring(0, $result.Length - $Matches[0].Length) + $Matches['inner'] + $Matches['tail']
    }

    $missing = "(?s)(The term|O termo|El t.rmino) '(?<name>[^']+)' (is not recognized as|não é reconhecido como|no se reconoce como).*\z"

    if ($result -match $missing) {
        $result = $result.Substring(0, $result.Length - $Matches[0].Length) + (Get-WinForgeText 'o comando ''{0}'' não está disponível neste Windows' "$($Matches['name'])")
    }

    # As recusas de acesso do .NET chegam em inglês na maioria dos Windows em português (sem o pacote de idioma do .NET).
    $denied = @{
        "Attempted to perform an unauthorized operation."   = (Get-WinForgeText 'o Windows negou a alteração (acesso negado)')
        "Tentativa de executar uma operação não autorizada." = (Get-WinForgeText 'o Windows negou a alteração (acesso negado)')
        "Requested registry access is not allowed."          = (Get-WinForgeText 'o Windows negou o acesso ao registro')
        "O acesso ao Registro solicitado não é permitido."   = (Get-WinForgeText 'o Windows negou o acesso ao registro')
        "Intento de realizar una operación no autorizada."  = (Get-WinForgeText 'o Windows negou a alteração (acesso negado)')
        "No se permite el acceso al Registro solicitado."    = (Get-WinForgeText 'o Windows negou o acesso ao registro')
    }

    foreach ($english in $denied.Keys) {
        $result = $result.Replace($english, $denied[$english])
    }

    # Uma mensagem do Windows com quebras de linha vira uma linha só (o resumo e a faixa de resultado são de uma linha).
    return ([regex]::Replace($result, '\s*\r?\n\s*', ' ')).TrimEnd()
}


function Format-WinForgeReasonNote {
    # O motivo de uma falha como a frase embaixo do título da faixa de resultado: legível (ConvertTo-WinForgeReadableError),
    # com a primeira letra maiúscula e o ponto final. Vazio volta vazio.
    param ([AllowEmptyString()][AllowNull()][string]$Text)

    $why = ([string](ConvertTo-WinForgeReadableError -Text $Text)).Trim()

    if (-not $why) { return "" }

    $why = "$($why.Substring(0, 1).ToUpperInvariant())$($why.Substring(1))"
    if ($why -notmatch '[.!?]$') { $why = "$why." }

    return $why
}


function Write-WinForgeStatus {
    param (
        [ValidateSet("Success", "Warning", "Error", "Info", "Running")]
        [string]$Type,
        [string]$Message,

        # Um aviso ANTES de uma pergunta ("os itens serão removidos permanentemente"): aparece com o ícone do tipo, na
        # saída e no resumo da janela, mas não é um resultado e não conta no desfecho da ação.
        [switch]$Notice
    )

    $Message = ConvertTo-WinForgeReadableError -Text $Message

    if (-not $Notice) {
        Add-WinForgeOutcomeMessage -Type $Type -Message $Message
    }

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

    # Uma mensagem longa continua embaixo do texto, depois do "[OK] ", e não embaixo do ícone.
    Write-WinForgeWrappedLine -Prefix "$badge " -PrefixColor $color -Text $Message -Color Gray
}


function Write-WinForgeCommand {
    param (
        [string]$Command
    )

    Write-Host "  > " -ForegroundColor DarkGray -NoNewline
    Write-Host $Command -ForegroundColor DarkCyan
}


function Write-WinForgePhase {
    # Uma parte de um fluxo em etapas numeradas que não é uma das etapas (no Otimizar, as perguntas antes da parte
    # automática e o fim). Na janela, ela toma o lugar da etapa em destaque, sem mudar a conta das etapas: as perguntas
    # não aparecem embaixo do nome da etapa que já terminou.
    param ([Parameter(Mandatory)][string]$Title)

    Write-Host ""
    Write-Host "  [>>] " -ForegroundColor Cyan -NoNewline
    Write-Host $Title -ForegroundColor White
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
        Write-Host (Get-WinForgeText '  Nenhuma etapa foi executada.') -ForegroundColor DarkGray
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
            # Sem Kind (um resultado de outra origem): o texto do Status, em português ou no idioma da tela.
            $statusText = [string]$result.Status
            $kind = $(
                if ($statusText -like "OK*") { "Ok" }
                elseif ($statusText -like "Falhou*" -or $statusText -like "$(Get-WinForgeText 'Falhou')*") { "Failed" }
                elseif ($statusText -like "Ignorad*" -or $statusText -like "$(Get-WinForgeText 'Ignorado')*") { "Skipped" }
                else { "Warning" }
            )
        }

        switch ($kind) {
            "Ok"      { $badge = "[OK]"; $color = "Green" }
            "Failed"  { $badge = "[X] "; $color = "Red" }
            "Skipped" { $badge = "[-] "; $color = "DarkGray" }
            default   { $badge = "[!] "; $color = "Yellow" }
        }

        if (Test-WinForgeGuiMode) {
            # Na janela, cada linha vira uma linha do resumo da execução (com o ícone do desfecho): sem as colunas
            # alinhadas, que lá só deixariam espaços no meio do texto, e sem repetir "OK" ao lado do ícone verde.
            $parts = @([string]$result.Etapa)
            if ($kind -ne "Ok") { $parts += [string]$result.Status }
            if (-not [string]::IsNullOrWhiteSpace([string]$result.Duracao)) { $parts += [string]$result.Duracao }

            Write-Host "  $($badge.Trim()) " -ForegroundColor $color -NoNewline
            Write-Host ($parts -join " · ") -ForegroundColor Gray
            continue
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

    if ($Embedded -or $script:WinForgeNestedDepth -gt 0) {
        Write-WinForgeSection -Title $Title
    }
    elseif (-not (Test-WinForgeGuiMode)) {
        # No console, a ação que começa sozinha começa um desfecho novo (a linha final de Exit-WinForgeAction). Na janela
        # quem zera é o executor, antes de a ação começar.
        Reset-WinForgeOutcome
        Show-WinForgeHeader $Title
    }
}


function Exit-WinForgeAction {
    # Encerramento de uma ação chamada sozinha. Na interface gráfica o botão Voltar já faz esse papel.
    # -Result: o WinForge.Result da ação; quando ela roda sozinha (sem -Embedded) o resultado vira o desfecho que a janela
    # mostra. Dentro de um fluxo (Manutenção) quem decide o desfecho é o fluxo.
    param (
        [switch]$Embedded,

        $Result = $null
    )

    if (-not $Embedded -and $script:WinForgeNestedDepth -gt 0) {
        # Uma ação que roda dentro de um fluxo (Invoke-WinForgeNestedAction): o resultado dela vai para o fluxo, sem mudar
        # o desfecho dele e sem a pausa do fim.
        if ($null -ne $Result -and -not ($Result -is [System.Array])) {
            $script:WinForgeNestedResult = $Result
        }

        return
    }

    if (-not $Embedded) {
        if ($null -ne $Result -and -not ($Result -is [System.Array])) {
            Set-WinForgeOutcome -Result $Result
        }

        # No console, a última linha diz como a ação terminou, como a faixa de resultado da janela. Depois de Voltar ou
        # Cancelar não há o que ler: o menu volta sem pedir mais uma tecla.
        if (-not (Test-WinForgeGuiMode)) {
            $outcome = Get-WinForgeOutcome

            if ($outcome.Kind -eq "Skipped" -and (Test-WinForgeCanceledText -Text ([string]$outcome.Detail))) {
                return
            }

            Write-WinForgeOutcomeLine -Outcome $outcome
        }

        # O WinForge vai fechar para a atualização: o instalador espera este menu fechar, e uma tecla pedida aqui o
        # deixaria esperando até desistir.
        if (Get-WinForgeAppExitRequest) { return }

        Write-Host ""
        Wait-WinForgeKey
    }
}


function Invoke-WinForgeNestedAction {
    <#
    Roda uma ação inteira, com as perguntas dela, dentro de um fluxo (as etapas com você do Otimizar): o título vira uma
    seção, sem o cabeçalho e sem a pausa do fim, e o desfecho do fluxo não muda. Devolve o WinForge.Result com que a
    ação terminou (o de Exit-WinForgeAction ou o último que ela devolveu), ou um Ok sem detalhe se ela não disse nada.
    -Arguments: os parâmetros da ação, por nome.
    #>
    param (
        [Parameter(Mandatory)]
        [string]$Command,

        [hashtable]$Arguments = @{}
    )

    $previous = $script:WinForgeNestedResult
    $script:WinForgeNestedResult = $null
    $script:WinForgeNestedDepth++
    $result = $null

    try {
        $output = @(& $Command @Arguments)
        $result = $script:WinForgeNestedResult
    }
    finally {
        $script:WinForgeNestedDepth--
        $script:WinForgeNestedResult = $previous
    }

    $returned = @($output | Where-Object { $null -ne $_ -and $_.PSObject.TypeNames -contains "WinForge.Result" })
    $others = @($output | Where-Object { $null -ne $_ -and -not ($_.PSObject.TypeNames -contains "WinForge.Result") })

    # Texto ou objetos soltos da ação aparecem na tela, mas não viram o resultado.
    if ($others.Count -gt 0) {
        $others | Out-Host
    }

    if ($null -eq $result -and $returned.Count -gt 0) {
        $result = $returned[$returned.Count - 1]
    }

    if ($null -eq $result) {
        $result = New-WinForgeResult -Kind Ok
    }

    return $result
}


function Test-WinForgeNestedAction {
    # Se a ação roda dentro de um fluxo (Invoke-WinForgeNestedAction, as etapas com você do Otimizar): ali, quem oferece
    # reiniciar no fim é o fluxo, e não cada ação.
    return ($script:WinForgeNestedDepth -gt 0)
}


function Get-WinForgeRebootSentence {
    <#
    O que dizer do reinício no fim do resultado: "Reinicie o PC para concluir." quando a ação terminou e falta reiniciar;
    "Reinicie o PC e tente de novo." quando ela não foi concluída por causa de um reinício pendente (nada termina sozinho
    ao reiniciar: é preciso rodar de novo). Nada quando o detalhe da ação já diz para reiniciar ("depois de reiniciar, rode o
    SFC de novo"); quando ele só fala do reinício ("termina na próxima reinicialização"), o pedido continua.
    #>
    param (
        [string]$Kind,
        [string]$Detail = ""
    )

    # Nos três idiomas (os detalhes saem no idioma da tela): "reinicie", "depois de reiniciar"; "restart the PC",
    # "after restarting"; "reinicie", "después de reiniciar", "al reiniciar".
    if ($Detail -match '(?i)\breinicie\b|(depois|antes|ao) de reiniciar|\bao reiniciar') { return "" }
    if ($Detail -match '(?i)\brestart (the|your) PC\b|\b(after|before|when) restarting\b') { return "" }
    if ($Detail -match '(?i)(después|antes) de reiniciar|\bal reiniciar') { return "" }
    if ($Kind -eq "Failed") { return (Get-WinForgeText ' Reinicie o PC e tente de novo.') }

    return (Get-WinForgeText ' Reinicie o PC para concluir.')
}


function Write-WinForgeOutcomeLine {
    # A linha final de uma ação no console: "[OK] Concluído: ...", "[!] Concluído com ressalvas: ..." e, se o Windows
    # precisa reiniciar, o lembrete. Uma tela que só mostrou informações (Done) não ganha linha.
    param (
        [Parameter(Mandatory)]
        $Outcome
    )

    if ($Outcome.Kind -eq "Done") {
        return
    }

    switch ($Outcome.Kind) {
        "Ok"      { $badge = "[OK]"; $color = "Green" }
        "Warning" { $badge = "[!]"; $color = "Yellow" }
        "Failed"  { $badge = "[X]"; $color = "Red" }
        default   { $badge = "[-]"; $color = "DarkGray" }
    }

    Write-Host ""
    Write-WinForgeWrappedLine -Prefix "$badge " -PrefixColor $color -Text ([string]$Outcome.Summary) -Color $color

    # O mesmo pedido de reinício da janela (Get-WinForgeRebootSentence): nada quando o detalhe já manda reiniciar.
    if ($Outcome.RebootRequired) {
        $reboot = (Get-WinForgeRebootSentence -Kind ([string]$Outcome.Kind) -Detail ([string]$Outcome.Summary)).Trim()
        if ($reboot) { Write-Host "  $reboot" -ForegroundColor Yellow }
    }
}


function New-WinForgeResult {
    <#
    Resultado de uma etapa de fluxo (Otimizar). Só aparece no pipeline quando a ação recebe -PassThru.
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

    $Detail = ConvertTo-WinForgeReadableError -Text $Detail

    $status = switch ($Kind) {
        "Ok"      { "OK" }
        "Skipped" { (Get-WinForgeText 'Ignorado') }
        "Warning" { (Get-WinForgeText 'Atenção') }
        "Failed"  { (Get-WinForgeText 'Falhou') }
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


# ---------------------------------------------------------------------------
# Desfecho da ação (o que a janela mostra na faixa de resultado)
# ---------------------------------------------------------------------------

function Reset-WinForgeOutcome {
    $script:WinForgeOutcomeState = [ordered]@{
        Explicit    = $null
        Success     = 0
        Warning     = 0
        Error       = 0
        LastWarning = ""
        LastError   = ""
    }
}


function Add-WinForgeOutcomeMessage {
    # Chamado por Write-WinForgeStatus: conta as mensagens de sucesso, aviso e erro da ação em andamento.
    param (
        [string]$Type,
        [string]$Message
    )

    if ($null -eq $script:WinForgeOutcomeState) {
        Reset-WinForgeOutcome
    }

    $state = $script:WinForgeOutcomeState

    switch ($Type) {
        "Success" { $state.Success++ }
        "Warning" { $state.Warning++; $state.LastWarning = $Message }
        "Error"   { $state.Error++; $state.LastError = $Message }
    }
}


function Set-WinForgeOutcome {
    <#
    Registra o resultado explícito da ação (um WinForge.Result, ou Kind e Detail soltos). Vale mais do que a contagem
    de mensagens; o último registro vence.
    #>
    param (
        $Result = $null,

        [ValidateSet("Ok", "Skipped", "Warning", "Failed")]
        [string]$Kind = "",

        [string]$Detail = ""
    )

    if ($null -eq $script:WinForgeOutcomeState) {
        Reset-WinForgeOutcome
    }

    $reboot = $false
    $view = @{ Headline = ""; Note = ""; Tone = ""; Next = ""; NextLabel = ""; HideSummary = $false; Quiet = $false }

    if ($null -ne $Result) {
        $Kind = [string]$Result.Kind
        $Detail = [string]$Result.Detail
        $reboot = Test-WinForgeResultFlag -Result $Result -Name "RebootRequired"

        # Como a janela apresenta este resultado, se a ação disse (Set-WinForgeResultView).
        foreach ($name in @("Headline", "Note", "Tone", "Next", "NextLabel")) {
            $view[$name] = [string](Get-WinForgeResultData -Result $Result -Name $name)
        }

        $view.HideSummary = Test-WinForgeResultFlag -Result $Result -Name "HideSummary"
        $view.Quiet = Test-WinForgeResultFlag -Result $Result -Name "Quiet"
    }

    if ([string]::IsNullOrEmpty($Kind)) {
        return
    }

    $script:WinForgeOutcomeState.Explicit = [PSCustomObject]@{
        Kind = $Kind; Detail = $Detail; RebootRequired = $reboot
        Headline = $view.Headline; Note = $view.Note; Tone = $view.Tone; Next = $view.Next; NextLabel = $view.NextLabel; HideSummary = $view.HideSummary
        Quiet = $view.Quiet
    }
}


function Set-WinForgeResultView {
    <#
    Como a janela apresenta um resultado quando o genérico ("Concluído com ressalvas: 4 ameaças encontradas; 3 ainda
    pedem ação") não basta. Headline é o título da faixa ("3 ameaças pedem ação"); Note, a frase embaixo dele; Tone, a
    cor (Ok, Warn ou Bad) quando ela não é a do Kind; Next, o próximo passo (um item da navegação ou um atalho do
    Windows), com NextLabel no botão; HideSummary esconde o resumo quando a faixa já diz tudo. Quiet: além do novo estado,
    não há nada a ler (a chave de um ajuste que mudou sem aviso): a janela pode mostrar o resultado na própria linha, sem a
    tela de execução. Fica em Data: o console, o Otimizar e o histórico continuam com Kind e Detail. Devolve o próprio
    resultado.
    #>
    param (
        [Parameter(Mandatory)]
        $Result,

        [string]$Headline = "",
        [string]$Note = "",

        [ValidateSet("", "Ok", "Warn", "Bad")]
        [string]$Tone = "",

        [string]$Next = "",
        [string]$NextLabel = "",
        [switch]$HideSummary,
        [switch]$Quiet
    )

    if (-not ($Result.Data -is [System.Collections.IDictionary])) { $Result.Data = @{} }

    $Result.Data["Headline"] = $Headline
    $Result.Data["Note"] = $Note
    $Result.Data["Tone"] = $Tone
    $Result.Data["Next"] = $Next
    $Result.Data["NextLabel"] = $NextLabel
    $Result.Data["HideSummary"] = [bool]$HideSummary
    $Result.Data["Quiet"] = [bool]$Quiet

    return $Result
}


function Format-WinForgeOutcomeSummary {
    # Uma linha para a faixa de resultado: o que aconteceu, sem repetir o nome da ação.
    param (
        [ValidateSet("Ok", "Skipped", "Warning", "Failed", "Done")]
        [string]$Kind,

        [string]$Detail = ""
    )

    $detail = ([string]$Detail).Trim().TrimEnd(".")

    if ($detail.Length -gt 220) {
        $detail = $detail.Substring(0, 217) + "..."
    }

    switch ($Kind) {
        "Ok"      { if ($detail) { return (Get-WinForgeText 'Concluído: {0}.' "$detail") } else { return (Get-WinForgeText 'Concluído com sucesso.') } }
        "Warning" { if ($detail) { return (Get-WinForgeText 'Concluído com ressalvas: {0}.' "$detail") } else { return (Get-WinForgeText 'Concluído com ressalvas; revise a saída.') } }
        "Failed"  { if ($detail) { return (Get-WinForgeText 'Não foi concluído: {0}.' "$detail") } else { return (Get-WinForgeText 'Não foi concluído; revise a saída.') } }
        "Skipped" {
            # "cancelado pelo usuário" e "operação cancelada" são o mesmo fato; a faixa diz sempre a mesma frase.
            if (Test-WinForgeCanceledText -Text $detail) { return (Get-WinForgeText 'Operação cancelada.') }
            if ($detail) { return (Get-WinForgeText 'Nada foi feito: {0}.' "$detail") } else { return (Get-WinForgeText 'Nada a fazer.') }
        }
        default   { return (Get-WinForgeText 'Concluído.') }
    }
}


function Get-WinForgeOutcome {
    <#
    O desfecho da ação que acabou de rodar. Kind = Ok | Warning | Failed | Skipped | Done (Done: a ação só mostrou
    informações e não registrou nada). Usa o resultado explícito, se houver; senão, deduz das mensagens de estado:
    erro sem nenhum sucesso é falha, erro com sucesso e aviso são ressalvas, aviso de cancelamento é "nada feito".
    #>
    if ($null -eq $script:WinForgeOutcomeState) {
        Reset-WinForgeOutcome
    }

    $state = $script:WinForgeOutcomeState
    $kind = "Done"
    $detail = ""
    $reboot = $false
    $view = @{ Headline = ""; Note = ""; Tone = ""; Next = ""; NextLabel = ""; HideSummary = $false; Quiet = $false }

    if ($null -ne $state.Explicit) {
        $kind = [string]$state.Explicit.Kind
        $detail = [string]$state.Explicit.Detail
        $reboot = [bool]$state.Explicit.RebootRequired

        foreach ($name in @("Headline", "Note", "Tone", "Next", "NextLabel")) {
            $view[$name] = [string](Get-WinForgeJsonValue -Object $state.Explicit -Name $name -Default "")
        }

        $view.HideSummary = [bool](Get-WinForgeJsonValue -Object $state.Explicit -Name "HideSummary" -Default $false)
        $view.Quiet = [bool](Get-WinForgeJsonValue -Object $state.Explicit -Name "Quiet" -Default $false)
    }
    elseif ($state.Error -gt 0) {
        $detail = [string]$state.LastError

        if ($state.Success -gt 0) { $kind = "Warning" } else { $kind = "Failed" }
    }
    elseif ($state.Warning -gt 0) {
        $detail = [string]$state.LastWarning

        if ($state.Success -eq 0 -and (Test-WinForgeCanceledText -Text $detail)) {
            $kind = "Skipped"
            $detail = (Get-WinForgeText 'operação cancelada')
        }
        else {
            $kind = "Warning"
        }
    }
    elseif ($state.Success -gt 0) {
        $kind = "Ok"
    }

    $title = switch ($kind) {
        "Ok"      { (Get-WinForgeText 'Concluído') }
        "Warning" { (Get-WinForgeText 'Concluído com ressalvas') }
        "Failed"  { (Get-WinForgeText 'Não foi concluído') }
        # O PC reiniciando a pedido da pessoa (o Otimizar com um reinício pendente) não é "Nada a fazer".
        "Skipped" { $(if (Test-WinForgeCanceledText -Text $detail) { (Get-WinForgeText 'Cancelado') } elseif (Test-WinForgeRestartingText -Text $detail) { (Get-WinForgeText 'Reiniciando') } else { (Get-WinForgeText 'Nada a fazer') }) }
        default   { (Get-WinForgeText 'Concluído') }
    }

    # O título que a própria ação deu ao resultado ("Nenhum vírus encontrado") vale mais que o genérico.
    if (-not [string]::IsNullOrWhiteSpace($view.Headline)) { $title = $view.Headline }

    return [PSCustomObject]@{
        PSTypeName     = "WinForge.Outcome"
        Kind           = $kind
        Title          = $title
        Summary        = (Format-WinForgeOutcomeSummary -Kind $kind -Detail $detail)
        Detail         = $detail
        RebootRequired = $reboot
        Headline       = $view.Headline
        Note           = $view.Note
        Tone           = $view.Tone
        Next           = $view.Next
        NextLabel      = $view.NextLabel
        HideSummary    = $view.HideSummary
        Quiet          = $view.Quiet
    }
}


function Test-WinForgeElevation {
    # Verdadeiro quando o processo é Administrador; caso contrário mostra o motivo e devolve falso.
    param (
        [string]$Reason = (Get-WinForgeText 'Esta ação exige privilégios de Administrador.')
    )

    if (Test-WinForgeAdministrator) {
        return $true
    }

    Write-WinForgeStatus -Type Error -Message $Reason
    Write-Host (Get-WinForgeText '      Feche o WinForge e abra-o novamente como Administrador.') -ForegroundColor DarkGray
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
        [string]$Message = (Get-WinForgeText 'Pressione qualquer tecla para continuar...')
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


function Test-WinForgeInputRedirected {
    # Se as respostas do console vêm de um arquivo ou de outro programa (e não de alguém digitando).
    try {
        return [bool][Console]::IsInputRedirected
    }
    catch {
        return $true
    }
}


function Get-WinForgeAnswerLimit {
    # Quantas respostas inválidas seguidas uma pergunta do console aceita (veja $script:WinForgeMaxInvalidAnswers).
    if ((Test-WinForgeGuiMode) -or (Test-WinForgeInputRedirected)) {
        return $script:WinForgeMaxInvalidAnswers
    }

    return $script:WinForgeMaxTypedAnswers
}


function Format-WinForgeKeyHint {
    # O que pode ser digitado, para a mensagem de opção inválida: "um número de 0 a 11", "L, D ou 0",
    # "um número de 0 a 28, A, P ou R".
    param (
        [string[]]$Keys
    )

    $numbers = @($Keys | Where-Object { $_ -match '^[0-9]+$' } | ForEach-Object { [int]$_ } | Sort-Object -Unique)
    $letters = @($Keys | Where-Object { $_ -notmatch '^[0-9]+$' } | ForEach-Object { $_.ToUpperInvariant() })
    $parts = @()

    if ($numbers.Count -ge 3 -and ($numbers[-1] - $numbers[0] + 1) -eq $numbers.Count) {
        $parts += (Get-WinForgeText 'um número de {0} a {1}' "$($numbers[0])" "$($numbers[-1])")
    }
    else {
        $parts += @($numbers | ForEach-Object { [string]$_ })
    }

    $parts += $letters

    # A saída (0), quando há letras, vai por último: "L, D ou 0".
    if ($letters.Count -gt 0 -and $parts -contains "0") {
        $parts = @($parts | Where-Object { $_ -ne "0" }) + "0"
    }

    if ($parts.Count -le 1) {
        return ($parts -join "")
    }

    return (Get-WinForgeText '{0} ou {1}' "$($parts[0..($parts.Count - 2)] -join ', ')" "$($parts[-1])")
}


function Get-WinForgeUnelevatedHint {
    # Como abrir o WinForge sem Administrador, com a conta de quem usa o PC (quando ele está aberto com a conta de outro
    # Administrador). Na janela, recusar o aviso do Windows abre a janela assim mesmo; no menu de texto, recusar fecha.
    if (Test-WinForgeGuiMode) {
        return (Get-WinForgeText 'feche o WinForge, abra de novo e responda Não ao aviso do Windows: a janela abre sem Administrador')
    }

    return (Get-WinForgeText 'abra a janela do WinForge (pelo atalho ou pelo WinForge.cmd) e responda Não ao aviso do Windows: ela abre sem Administrador')
}


function Confirm-WinForgeAction {
    # Pergunta Sim/Não. DefaultKey ("S" ou "N") destaca o botão na interface gráfica e vale para ENTER no console.
    param (
        [string]$Message = (Get-WinForgeText 'Deseja continuar?'),

        [ValidateSet("", "S", "N")]
        [string]$DefaultKey = "",

        # Na janela, botões que dizem o que fazem ("Reiniciar agora" e "Depois") no lugar de Sim e Não. O do não vira a
        # saída: nunca fica em destaque, e com Não como padrão a pergunta fica sem botão em destaque (o Enter fica nele).
        # O console continua com S/N.
        [string]$YesLabel = "",
        [string]$NoLabel = "",

        # O Sim apaga algo sem volta (esvaziar a Lixeira, excluir em definitivo): na janela, o botão vem na cor de perigo.
        # Use com DefaultKey N. O console não muda.
        [switch]$Danger
    )

    if (Test-WinForgeGuiPrompts) {
        # Sem resposta padrão, a janela põe o foco do teclado no Não (um Enter a mais não confirma nada); com ela, na padrão.
        $verbs = (-not [string]::IsNullOrWhiteSpace($YesLabel) -and -not [string]::IsNullOrWhiteSpace($NoLabel))

        if ($verbs) {
            $options = @(
                @{ Key = "S"; Label = $YesLabel; Accent = ($DefaultKey -ne "N"); Danger = [bool]$Danger },
                @{ Key = "N"; Label = $NoLabel; Exit = $true }
            )
        }
        else {
            $options = @(
                @{ Key = "S"; Label = (Get-WinForgeText 'Sim'); Accent = ($DefaultKey -ne "N"); Danger = [bool]$Danger },
                @{ Key = "N"; Label = (Get-WinForgeText 'Não'); Accent = ($DefaultKey -eq "N") }
            )
        }

        $answer = Read-WinForgeChoice -Message $Message -DefaultKey $DefaultKey -Options $options

        return ($answer -eq "S")
    }

    # As teclas do idioma (Y/N em inglês); a resposta aceita as dos três, e DefaultKey continua S ou N.
    $hint = switch ($DefaultKey) {
        "S"     { (Get-WinForgeText 'S/n') }
        "N"     { (Get-WinForgeText 's/N') }
        default { (Get-WinForgeText 'S/N') }
    }

    $limit = Get-WinForgeAnswerLimit
    $ended = 0

    for ($attempt = 0; $attempt -lt $limit -and $ended -lt $script:WinForgeMaxInvalidAnswers; $attempt++) {
        Write-Host "  " -NoNewline
        $raw = Read-Host "$Message ($hint)"

        # Nulo: a entrada acabou (redirecionada, Ctrl+Z). Conta sempre para o limite curto.
        if ($null -eq $raw) { $ended++ }

        $answer = ([string]$raw).Trim().ToUpperInvariant()

        if ([string]::IsNullOrEmpty($answer) -and $DefaultKey) {
            $answer = $DefaultKey
        }

        switch ($answer) {
            { $_ -in @("S", "SIM", "SI", "SÍ", "Y", "YES") } { return $true }
            { $_ -in @("N", "NAO", "NÃO", "NO") } { return $false }
            "" {
                Write-Host (Get-WinForgeText '  Digite S ou N e tecle Enter.') -ForegroundColor DarkGray
            }
            default {
                Write-Host (Get-WinForgeText '  Opção inválida. Digite S ou N e tecle Enter.') -ForegroundColor Red
            }
        }
    }

    throw (Get-WinForgeText 'Nenhuma resposta válida foi informada.')
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
            Danger      = [bool](Get-WinForgeOptionField $option "Danger" $false)
        }
    }
}


function Read-WinForgeChoice {
    <#
    Pergunta de escolha única. Na interface gráfica vira botões; no console, o menu de sempre.
    Options: hashtables/objetos com Key, Label e, opcionalmente, Description, Accent, Exit (opção de sair/cancelar) e
    Danger (a opção apaga algo sem volta: na janela, ela vem na cor de perigo). Retorna a Key escolhida.
    #>
    param (
        [string]$Message = (Get-WinForgeText 'Selecione uma opção'),
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
                $guiOption.Danger = $option.Danger
                $guiOption
            }
        )

        return [string]$global:WinForgeGuiHost.GuiUI.AskChoice("", $Message, $converted, $DefaultKey)
    }

    # 0 sempre volta ou cancela: a opção de saída (Exit) aceita também o 0 quando nenhuma outra usa o 0. Ela aparece como
    # [ 0], salvo quando o texto da pergunta (-TextPrompt) cita a tecla dela ("X = cancelar").
    $exit = @($items | Where-Object { $_.Exit }) | Select-Object -First 1
    $zeroAlias = ($null -ne $exit -and $exit.Key -ne "0" -and @($items | Where-Object { $_.Key -eq "0" }).Count -eq 0)
    $showZero = ($zeroAlias -and ([string]::IsNullOrWhiteSpace($TextPrompt) -or $TextPrompt -cnotmatch ('(^|[^\p{L}\p{N}])' + [regex]::Escape($exit.Key) + '([^\p{L}\p{N}]|$)')))

    $shownKeys = @(
        foreach ($option in $items) {
            if ($showZero -and $option.Exit -and $option.Key -eq $exit.Key) { "0" } else { $option.Key }
        }
    )

    if ($ShowMenu) {
        for ($i = 0; $i -lt $items.Count; $i++) {
            $option = $items[$i]
            Write-WinForgeMenuItem -Key $shownKeys[$i] -Label $option.Label -Description $option.Description -Accent:$option.Accent -Exit:$option.Exit
        }

        Write-Host ""
    }

    # A pergunta vai numa linha própria e o pedido é só "Opção" (o Read-Host acrescenta ": "; depois de um "?" ficava
    # "atalho?: "). Um -TextPrompt já diz tudo e fica como está.
    if (-not [string]::IsNullOrWhiteSpace($TextPrompt)) {
        $prompt = $TextPrompt
    }
    else {
        Write-WinForgeWrappedLine -Text $Message -Color Gray
        $prompt = (Get-WinForgeText 'Opção')
    }

    $keyHint = Format-WinForgeKeyHint -Keys $shownKeys
    $limit = Get-WinForgeAnswerLimit
    $ended = 0

    for ($attempt = 0; $attempt -lt $limit -and $ended -lt $script:WinForgeMaxInvalidAnswers; $attempt++) {
        Write-Host "  " -NoNewline
        $raw = Read-Host $prompt

        # Nulo: a entrada acabou (redirecionada, Ctrl+Z). Conta sempre para o limite curto.
        if ($null -eq $raw) { $ended++ }

        $answer = ([string]$raw).Trim()

        if ([string]::IsNullOrEmpty($answer) -and -not [string]::IsNullOrEmpty($DefaultKey)) {
            return $DefaultKey
        }

        if ($zeroAlias -and $answer -eq "0") {
            return $exit.Key
        }

        $match = @($items | Where-Object { $_.Key -ieq $answer }) | Select-Object -First 1

        if ($null -ne $match) {
            return $match.Key
        }

        if ([string]::IsNullOrEmpty($answer)) {
            Write-Host (Get-WinForgeText '  Digite {0} e tecle Enter.' "$keyHint") -ForegroundColor DarkGray
        }
        else {
            Write-Host (Get-WinForgeText '  Opção inválida. Digite {0} e tecle Enter.' "$keyHint") -ForegroundColor Red
        }
    }

    throw (Get-WinForgeText 'Nenhuma resposta válida foi informada.')
}


function Read-WinForgeMultiSelect {
    <#
    Seleção múltipla. Na interface gráfica vira uma lista de marcação; no console, uma lista numerada
    ("1,3,5-7", T = todos, ENTER = cancelar). Options: Key, Label, Description e, opcionalmente, Selected.
    Retorna as Keys marcadas, ou $null se o usuário cancelar ou não marcar nada (o PowerShell não distingue uma
    lista vazia de $null no retorno de uma função, então os chamadores tratam os dois casos como "nada escolhido").
    -NoSelectAll: sem o atalho de marcar tudo (o "T" do console, o "Marcar todos" da janela), nas listas em que marcar
    tudo de uma vez seria um estrago difícil de desfazer (desinstalar programas, remover aplicativos, recursos do Windows).
    -AllowNone: nas revisões (o que já vem marcado é o estado de agora), desmarcar tudo é uma resposta: devolve uma lista
    vazia (como @(), que o chamador distingue de $null), e o console aceita 0 para "nenhum".
    -ConfirmLabel e -CancelLabel: o que os botões da janela dizem ("Desinstalar", "Voltar"); dentro de um fluxo (o
    Otimizar), desistir da lista é pular a etapa, e o botão diz "Pular".
    #>
    param (
        [string]$Message = (Get-WinForgeText 'Selecione os itens'),
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Options,
        [switch]$NoSelectAll,
        [switch]$AllowNone,
        [string]$ConfirmLabel = "",
        [string]$CancelLabel = ""
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

        if ([string]::IsNullOrWhiteSpace($CancelLabel) -and $script:WinForgeNestedDepth -gt 0) { $CancelLabel = (Get-WinForgeText 'Pular') }

        # Na janela, -NoSelectAll tira o "Marcar todos" da lista.
        $keys = $global:WinForgeGuiHost.GuiUI.AskMulti("", $Message, $converted, [bool]$NoSelectAll, $ConfirmLabel, $CancelLabel, [bool]$AllowNone)

        if ($null -eq $keys) {
            return $null
        }

        if ($AllowNone) { return , @($keys) }

        return @($keys)
    }

    for ($i = 0; $i -lt $items.Count; $i++) {
        $mark = if ($items[$i].Selected) { "*" } else { " " }

        Write-Host "  " -NoNewline
        Write-Host ("[{0,2}]{1}" -f ($i + 1), $mark) -ForegroundColor Cyan -NoNewline
        # Um espaço depois do nome mesmo quando ele passa de 30 caracteres: sem ele, nome e descrição se colavam.
        Write-Host (" {0} " -f $items[$i].Label.PadRight(30)) -ForegroundColor Gray -NoNewline
        Write-Host $items[$i].Description -ForegroundColor DarkGray
    }

    $preselected = @($items | Where-Object { $_.Selected })

    Write-Host ""
    $allHint = $(if ($NoSelectAll) { "" } else { (Get-WinForgeText ' T = todos.') })
    $noneHint = $(if ($AllowNone) { (Get-WinForgeText ' 0 = nenhum.') } else { "" })
    Write-Host (Get-WinForgeText '  Informe números separados por vírgula ou intervalos (ex.: 1,3,5-7).{0}{1} ENTER = cancelar.' "$allHint" "$noneHint") -ForegroundColor DarkCyan

    if ($preselected.Count -gt 0) {
        Write-Host (Get-WinForgeText '  P = usar os já marcados com * ({0}).' "$($preselected.Count)") -ForegroundColor DarkCyan
    }

    Write-Host ""

    $limit = Get-WinForgeAnswerLimit

    for ($attempt = 0; $attempt -lt $limit; $attempt++) {
        Write-Host "  " -NoNewline
        $inputText = ([string](Read-Host $Message)).Trim()

        if ([string]::IsNullOrWhiteSpace($inputText)) {
            return $null
        }

        if ($inputText -ieq "T" -and -not $NoSelectAll) {
            return @($items | ForEach-Object { $_.Key })
        }

        if ($inputText -ieq "P" -and $preselected.Count -gt 0) {
            return @($preselected | ForEach-Object { $_.Key })
        }

        if ($inputText -eq "0" -and $AllowNone) {
            return , @()
        }

        try {
            $indexes = @(ConvertTo-WinForgeSelectionIndexes -InputText $inputText -Maximum $items.Count)
            return @($indexes | ForEach-Object { $items[$_ - 1].Key })
        }
        catch {
            # Um número digitado errado não é um erro da ação (não entra no desfecho).
            Write-WinForgeStatus -Type Error -Notice -Message $_.Exception.Message
        }
    }

    throw (Get-WinForgeText 'Nenhuma resposta válida foi informada.')
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
