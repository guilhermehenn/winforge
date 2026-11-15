# Otimizar: a manutenção completa do PC, num fluxo guiado em que as perguntas vêm antes da parte demorada.
#
#   1. Preparação          os avisos que importam e a sugestão forte de fechar os programas (com a lista dos abertos)
#   2. Plano               sempre o inteiro, na ordem da lista abaixo, sem perguntar o que fazer
#   3. Com você, no começo ponto de restauração, programas, o que abre com o Windows e as pastas pessoais (telas do WinForge)
#   4. Perguntas           o que a parte automática precisa saber (o que atualizar no winget, que restos apagar, a Lixeira)
#   5. Automática          sem perguntas: antivírus, reparo do Windows, atualizações, navegadores, limpeza, rede e disco;
#                          no fim dela, o resultado já fica gravado (se a janela fechar na revisão dos ajustes, não se perde)
#   6. Com você, no fim    a revisão dos ajustes do Windows, já marcados conforme o Windows está agora
#   7. Encerramento        resumo, CHKDSK offline e, sempre, a sugestão de reiniciar
#
# Na tela, o mínimo de texto: uma linha por aviso, perguntas curtas; o porquê de cada coisa fica nestes comentários.

# A lista das janelas abertas (Get-WinForgeTopLevelWindows): as que a barra de tarefas mostra, como ela decide (visível,
# sem dono, que não é janela de ferramenta) e sem as encobertas pelo Windows (aplicativos suspensos, outras áreas de
# trabalho virtuais).
$script:WinForgeOpenWindowsSource = @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;

namespace WinForge
{
    public static class OpenWindows
    {
        private delegate bool EnumWindowsProc(IntPtr hwnd, IntPtr lParam);

        [DllImport("user32.dll")]
        private static extern bool EnumWindows(EnumWindowsProc callback, IntPtr lParam);

        [DllImport("user32.dll")]
        private static extern bool IsWindowVisible(IntPtr hwnd);

        [DllImport("user32.dll")]
        private static extern IntPtr GetWindow(IntPtr hwnd, uint command);

        [DllImport("user32.dll", CharSet = CharSet.Unicode)]
        private static extern int GetWindowTextLength(IntPtr hwnd);

        [DllImport("user32.dll", CharSet = CharSet.Unicode)]
        private static extern int GetWindowText(IntPtr hwnd, StringBuilder text, int maxCount);

        [DllImport("user32.dll")]
        private static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint processId);

        [DllImport("user32.dll", EntryPoint = "GetWindowLongW")]
        private static extern int GetWindowLong(IntPtr hwnd, int index);

        [DllImport("dwmapi.dll")]
        private static extern int DwmGetWindowAttribute(IntPtr hwnd, int attribute, out int value, int size);

        public sealed class Entry
        {
            public int ProcessId;
            public string Title;
        }

        public static Entry[] List()
        {
            List<Entry> found = new List<Entry>();

            EnumWindows(delegate (IntPtr hwnd, IntPtr lParam)
            {
                try
                {
                    if (!IsWindowVisible(hwnd)) { return true; }
                    // GW_OWNER = 4: uma janela com dono (diálogo, paleta) não tem botão próprio na barra de tarefas.
                    if (GetWindow(hwnd, 4) != IntPtr.Zero) { return true; }
                    // GWL_EXSTYLE = -20; WS_EX_TOOLWINDOW = 0x80.
                    if ((GetWindowLong(hwnd, -20) & 0x80) != 0) { return true; }

                    // DWMWA_CLOAKED = 14.
                    int cloaked = 0;
                    if (DwmGetWindowAttribute(hwnd, 14, out cloaked, 4) == 0 && cloaked != 0) { return true; }

                    int length = GetWindowTextLength(hwnd);
                    if (length <= 0) { return true; }

                    StringBuilder text = new StringBuilder(length + 1);
                    GetWindowText(hwnd, text, text.Capacity);

                    uint processId;
                    GetWindowThreadProcessId(hwnd, out processId);

                    Entry entry = new Entry();
                    entry.ProcessId = (int)processId;
                    entry.Title = text.ToString();
                    found.Add(entry);
                }
                catch
                {
                    // Uma janela que fechou no meio da conta fica de fora.
                }

                return true;
            }, IntPtr.Zero);

            return found.ToArray();
        }
    }
}
'@

$script:WinForgeWindowListFailed = $false
$script:WinForgeWindowNativeFailed = $false


# ---------------------------------------------------------------------------
# Plano
# ---------------------------------------------------------------------------

function New-WinForgePlanItem {
    # Uma etapa do Otimizar. Phase: Before (antes da parte automática), Auto ou After (depois dela). -WithYou: a etapa
    # mostra uma tela do WinForge e espera a pessoa escolher (Kind "Com você"); sem ele, roda sozinha ("Automático").
    param (
        [string]$Id,
        [ValidateSet("Before", "Auto", "After")]
        [string]$Phase,
        [string]$Title,
        [string]$Description,
        [switch]$WithYou
    )

    return [PSCustomObject]@{
        Id          = $Id
        Phase       = $Phase
        Kind        = $(if ($WithYou) { "Com você" } else { "Automático" })
        WithYou     = [bool]$WithYou
        Title       = $Title
        Description = $Description
    }
}


function Get-WinForgeMaintenancePlanItems {
    # A ordem desta lista é a ordem de execução. Antes: o ponto de restauração e o que precisa da pessoa (enxugar o PC).
    # Automático: proteger; limpar os componentes e reparar o Windows ANTES do Windows Update (uma atualização instalada
    # deixa o Windows esperando o reinício, e aí o DISM recusa a limpeza e o reparo, 0x800F0806, e o SFC também); atualizar
    # (Windows, drivers, programas, navegadores e Store, já com a internet de antes do reparo de rede); limpar; reparar a
    # rede; conferir o disco e otimizar por último. Depois: os ajustes, com a pessoa de volta.
    # A limpeza (que esvazia a Lixeira, quando a pessoa pede) vem ANTES dos atalhos quebrados e dos restos de programas,
    # que vão para a Lixeira: depois deles, ela apagaria de vez o que acabou de ir para lá, e a promessa de "vão para a
    # Lixeira" seria falsa.
    return @(
        (New-WinForgePlanItem -Id "restore-point" -Phase Before -Title "Criar ponto de restauração" `
            -Description "antes de qualquer mudança, para poder voltar atrás"),
        (New-WinForgePlanItem -Id "uninstall" -Phase Before -WithYou -Title "Desinstalar programas" `
            -Description "a lista do winget; você marca o que não usa"),
        (New-WinForgePlanItem -Id "windows-apps" -Phase Before -WithYou -Title "Remover aplicativos do Windows" `
            -Description "os que vêm com o PC; você marca o que remover"),
        (New-WinForgePlanItem -Id "startup" -Phase Before -WithYou -Title "Revisar o que abre com o Windows" `
            -Description "uma lista só: marcado abre com o Windows"),
        (New-WinForgePlanItem -Id "folders" -Phase Before -WithYou -Title "Organizar Downloads, Documentos e Imagens" `
            -Description "uma pasta por vez: limpar, abrir no Explorador ou procurar duplicados"),

        (New-WinForgePlanItem -Id "security" -Phase Auto -Title "Verificar vírus" `
            -Description "atualiza o antivírus e faz a verificação rápida do Windows Defender"),
        (New-WinForgePlanItem -Id "early-updates" -Phase Auto -Title "Desligar as atualizações antecipadas" `
            -Description "a opção de receber as novidades do Windows assim que saem; pode trazer instabilidade"),
        (New-WinForgePlanItem -Id "components" -Phase Auto -Title "Limpar componentes do Windows (WinSxS)" `
            -Description "só sem reinício pendente; com ele, fica para a próxima vez"),
        (New-WinForgePlanItem -Id "repair" -Phase Auto -Title "Reparar o Windows (DISM + SFC)" `
            -Description "o reparo completo, mesmo sem sinal de dano, antes das atualizações; não mexe nos seus arquivos"),
        (New-WinForgePlanItem -Id "windows-update" -Phase Auto -Title "Atualizar o Windows" `
            -Description "as atualizações e os drivers opcionais; as prévias e uma versão nova do Windows ficam de fora"),
        (New-WinForgePlanItem -Id "drivers" -Phase Auto -Title "Detectar dispositivos e drivers" `
            -Description "procura hardware novo; o Windows instala o driver que já tiver para ele"),
        (New-WinForgePlanItem -Id "winget" -Phase Auto -Title "Atualizar programas (winget)" `
            -Description "você escolhe o que atualizar antes da parte automática"),
        (New-WinForgePlanItem -Id "browsers" -Phase Auto -Title "Atualizar os navegadores" `
            -Description "Edge, Chrome e Firefox, os que estiverem instalados"),
        (New-WinForgePlanItem -Id "store" -Phase Auto -Title "Atualizar aplicativos da Microsoft Store" `
            -Description "o mesmo pedido do botão Obter atualizações; a Store instala em segundo plano"),
        (New-WinForgePlanItem -Id "cleanup" -Phase Auto -Title "Limpeza rápida" `
            -Description "temporários do usuário e do Windows; a Lixeira, só se você confirmar"),
        (New-WinForgePlanItem -Id "shortcuts" -Phase Auto -Title "Remover atalhos quebrados" `
            -Description "vão para a Lixeira; os de pastas do OneDrive ficam"),
        (New-WinForgePlanItem -Id "leftovers" -Phase Auto -Title "Restos de programas desinstalados" `
            -Description "pastas de programas desinstalados pelo WinForge; você escolhe antes da parte automática"),
        (New-WinForgePlanItem -Id "registry" -Phase Auto -Title "Limpar o registro" `
            -Description "só referências quebradas a programas e arquivos que não existem mais, com backup e desfazer"),
        (New-WinForgePlanItem -Id "network" -Phase Auto -Title "Reparar rede e DNS" `
            -Description "renova o IP, limpa o DNS e redefine Winsock e TCP/IP; com VPN ou acesso remoto, só o DNS"),
        (New-WinForgePlanItem -Id "chkdsk" -Phase Auto -Title "Verificar o sistema de arquivos (CHKDSK)" `
            -Description "confere o disco com o Windows aberto; se precisar de reparo ao reiniciar, o Otimizar pergunta no fim"),
        (New-WinForgePlanItem -Id "optimize" -Phase Auto -Title "Otimizar a unidade do sistema" `
            -Description "deixa o disco em ordem (TRIM no SSD, desfragmentação no HD)"),

        (New-WinForgePlanItem -Id "tweaks" -Phase After -WithYou -Title "Revisar os ajustes do Windows" `
            -Description "cada ajuste vem marcado se já está em uso; você marca o que aplicar")
    )
}


function Get-WinForgeMaintenanceProfileLabel {
    # O nome do jeito como uma manutenção do histórico rodou: as da 3.50 e anteriores tinham perfil (Rápida, Completa,
    # Profunda); o Otimizar é um só. "" para um Id que esta versão não conhece.
    param ([AllowEmptyString()][string]$Id)

    $labels = @{ quick = "Rápida"; full = "Completa"; deep = "Profunda"; optimize = "Otimizar" }

    if ([string]::IsNullOrWhiteSpace($Id) -or -not $labels.ContainsKey($Id)) { return "" }

    return [string]$labels[$Id]
}


# ---------------------------------------------------------------------------
# Fase 1: preparação
# ---------------------------------------------------------------------------

function Test-WinForgeWindowCloaked {
    <#
    Se a janela está "encoberta" (cloaked) pelo Windows: os aplicativos da Store pré-carregados ou suspensos e as janelas
    de outras áreas de trabalho virtuais têm janela e título, mas a pessoa não as vê nem tem o que fechar. Sem poder
    perguntar ao Windows, devolve falso (a janela conta).
    #>
    param ([IntPtr]$Handle)

    # A ponte que já falhou uma vez (fora do Windows, por exemplo) não é compilada de novo a cada processo da lista.
    if ($script:WinForgeWindowNativeFailed) { return $false }

    try {
        if (-not ("WinForge.WindowNative" -as [type])) {
            Add-Type -Namespace WinForge -Name WindowNative -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("dwmapi.dll")]
public static extern int DwmGetWindowAttribute(System.IntPtr hwnd, int attribute, out int value, int size);
[System.Runtime.InteropServices.DllImport("user32.dll")]
public static extern bool IsWindowVisible(System.IntPtr hwnd);
'@ -ErrorAction Stop
        }

        if (-not [WinForge.WindowNative]::IsWindowVisible($Handle)) { return $true }

        $cloaked = 0
        # DWMWA_CLOAKED = 14
        if ([WinForge.WindowNative]::DwmGetWindowAttribute($Handle, 14, [ref]$cloaked, 4) -eq 0 -and $cloaked -ne 0) { return $true }
    }
    catch {
        $script:WinForgeWindowNativeFailed = $true
        return $false
    }

    return $false
}


function Get-WinForgeTopLevelWindows {
    <#
    As janelas que a barra de tarefas mostra (visíveis, sem dono, que não são janelas de ferramenta nem estão encobertas),
    com o processo e o título, numa passada só pelo Windows (EnumWindows): os aplicativos da Store, que aparecem pela
    janela do ApplicationFrameHost, entram pelo título. $null quando não dá para perguntar ao Windows (a ponte não
    compila ou a chamada falha): quem chama usa o caminho do Get-Process. A falha fica guardada, para não ser tentada de
    novo a cada conferência.
    #>
    if ($script:WinForgeWindowListFailed) { return $null }

    try {
        if (-not ("WinForge.OpenWindows" -as [type])) {
            Add-Type -TypeDefinition $script:WinForgeOpenWindowsSource -ErrorAction Stop
        }

        return , @([WinForge.OpenWindows]::List())
    }
    catch {
        $script:WinForgeWindowListFailed = $true
        return $null
    }
}


function Get-WinForgeFrameAppName {
    # O nome de um aplicativo da Store pelo título da janela que o ApplicationFrameHost desenha: "Calculadora", ou o fim de
    # "IMG_0042.jpg - Fotos". "" para as partes do Windows que usam a mesma moldura (as Configurações).
    param ([AllowEmptyString()][string]$Title)

    $name = ([string]$Title).Trim()
    $parts = @($name -split '\s+[-–—]\s+' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($parts.Count -gt 1) { $name = ([string]$parts[$parts.Count - 1]).Trim() }

    # O título de alguns aplicativos começa com uma marca invisível de direção do texto.
    $name = $name.Trim([char]0x200E, [char]0x200F, ' ')

    if ($name -in @("Configurações", "Settings", "Configuración")) { return "" }

    return $name
}


function Get-WinForgeOwnProcessIds {
    <#
    O próprio WinForge e a cadeia de quem o abriu (o PowerShell, o cmd). Um pai só conta se foi criado antes do filho: o
    número de um processo que já fechou (o PowerShell que pediu o Administrador e saiu) pode ter sido reaproveitado por
    um programa de verdade, que não pode sumir da lista.
    #>
    $own = New-Object System.Collections.Generic.HashSet[int]
    $id = [int]$PID
    $childStart = $null

    for ($i = 0; $i -lt 6 -and $id -gt 0; $i++) {
        try {
            # Com o serviço de WMI travado, a pergunta não pode segurar o Otimizar: 5 segundos e segue sem o pai.
            $row = Get-CimInstance -ClassName Win32_Process -Filter "ProcessId = $id" -OperationTimeoutSec 5 -ErrorAction Stop
        }
        catch {
            break
        }

        if ($null -eq $row) { break }

        $start = Get-WinForgeJsonValue -Object $row -Name "CreationDate" -Default $null
        if ($null -ne $childStart -and $null -ne $start -and [datetime]$start -gt [datetime]$childStart) { break }
        if (-not $own.Add($id)) { break }

        $childStart = $start
        $id = [int](Get-WinForgeJsonValue -Object $row -Name "ParentProcessId" -Default 0)
    }

    [void]$own.Add([int]$PID)
    return , $own
}


function Get-WinForgeOpenPrograms {
    <#
    Os programas com janela aberta na sessão de quem usa o PC, pelo nome que o Windows mostra (a descrição do arquivo,
    como "Google Chrome"; sem ela, o nome do processo), sem repetir e em ordem alfabética. Ficam de fora o próprio
    WinForge e quem o abriu, os terminais (no Windows 11, o Terminal que mostra o WinForge não é pai dele: fechá-lo
    fecharia o WinForge), as janelas encobertas (aplicativos da Store suspensos) e as partes do Windows e de drivers que
    sempre têm janela (Explorador, Iniciar, busca, teclado virtual, Configurações, Gerenciador de Tarefas, a sobreposição
    da NVIDIA). Sem poder ler os processos, devolve uma lista vazia.
    #>
    $shell = @("explorer", "ApplicationFrameHost", "TextInputHost", "ShellExperienceHost", "StartMenuExperienceHost", "SearchHost",
        "SearchApp", "SearchUI", "LockApp", "SystemSettings", "Taskmgr", "dwm", "ctfmon", "WidgetBoard", "Widgets", "PhoneExperienceHost",
        "WindowsTerminal", "OpenConsole", "conhost", "NVIDIA Overlay", "nvcontainer", "NVIDIA Share")

    $own = Get-WinForgeOwnProcessIds

    try {
        $session = [int](Get-Process -Id $PID -ErrorAction Stop).SessionId
        $processes = @(Get-Process -ErrorAction Stop)
    }
    catch {
        return @()
    }

    $names = New-Object System.Collections.Generic.List[string]

    # O nome que o Windows mostra para um processo: a descrição do arquivo ("Google Chrome"); sem ela, o nome do processo.
    $displayName = {
        param ($Process)
        $text = ""
        try { $text = [string]$Process.Description } catch { $text = "" }
        if ([string]::IsNullOrWhiteSpace($text)) { $text = [string]$Process.ProcessName }
        return $text.Trim()
    }

    # O caminho principal: as janelas da barra de tarefas, numa passada só. Os filtros baratos (sessão, o próprio WinForge,
    # as partes do Windows) vêm antes de ler a descrição do arquivo.
    $windows = Get-WinForgeTopLevelWindows

    if ($null -ne $windows) {
        $byId = @{}
        foreach ($process in $processes) { $byId[[int]$process.Id] = $process }

        foreach ($window in $windows) {
            try {
                $process = $byId[[int]$window.ProcessId]

                if ($null -eq $process) { continue }
                if ([int]$process.SessionId -ne $session -or $own.Contains([int]$process.Id)) { continue }

                $processName = [string]$process.ProcessName

                if ($processName -eq "ApplicationFrameHost") { $name = Get-WinForgeFrameAppName -Title ([string]$window.Title) }
                elseif ($shell -contains $processName) { continue }
                else { $name = & $displayName $process }

                if (-not [string]::IsNullOrWhiteSpace($name) -and -not $names.Contains($name)) { $names.Add($name) }
            }
            catch {
                continue
            }
        }

        return @($names | Sort-Object)
    }

    # Sem a ponte com o Windows: a janela principal de cada processo, como o Gerenciador de Tarefas antigo.
    foreach ($process in $processes) {
        try {
            if ([int]$process.SessionId -ne $session -or $own.Contains([int]$process.Id)) { continue }
            if ($shell -contains [string]$process.ProcessName) { continue }
            if ($process.MainWindowHandle -eq [IntPtr]::Zero -or [string]::IsNullOrWhiteSpace([string]$process.MainWindowTitle)) { continue }
            if (Test-WinForgeWindowCloaked -Handle $process.MainWindowHandle) { continue }

            $name = & $displayName $process

            if (-not $names.Contains($name)) { $names.Add($name) }
        }
        catch {
            continue
        }
    }

    return @($names | Sort-Object)
}


function Format-WinForgeOpenPrograms {
    # "Google Chrome, Microsoft Word e Spotify"; com mais de seis, os seis primeiros e "e mais N".
    param ([string[]]$Names)

    $list = @($Names | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })

    if ($list.Count -le 6) { return (Join-WinForgeList -Items $list) }

    return "$(@($list[0..5]) -join ', ') e mais $($list.Count - 6)"
}


function Confirm-WinForgeProgramsClosed {
    # A sugestão forte de fechar tudo antes de começar: o Otimizar atualiza e repara o Windows, e um programa aberto
    # atrapalha (arquivo em uso, atualização que não instala) e pode perder o que não foi salvo no reinício do fim. A
    # lista do que está aberto deixa a pergunta concreta (numa linha só com o aviso); começar com algo ainda aberto pede
    # uma segunda resposta.
    $open = @(Get-WinForgeOpenPrograms)

    if ($open.Count -gt 0) {
        Write-WinForgeStatus -Type Warning -Notice -Message "Salve seu trabalho e feche os programas abertos: $(Format-WinForgeOpenPrograms -Names $open)."
    }
    else {
        Write-WinForgeStatus -Type Warning -Notice -Message "Salve seu trabalho e feche todos os programas antes de otimizar."
    }

    # Uma entrada que terminou (Ctrl+Z, entrada redirecionada) faz a pergunta desistir: conta como cancelar, sem derrubar
    # o Otimizar. Por isso o "começar" só é a resposta do Enter na janela, onde a entrada não termina: lá, o Enter faz o
    # mesmo que o botão em destaque.
    try {
        $answer = Read-WinForgeChoice -Message "Fechou todos os programas?" -ShowMenu -DefaultKey $(if (Test-WinForgeGuiMode) { "S" } else { "" }) -TextPrompt "Opção (S = já fechei, começar; X = cancelar)" -Options @(
            @{ Key = "S"; Label = "Já fechei, começar"; Accent = $true },
            @{ Key = "X"; Label = "Cancelar"; Exit = $true }
        )

        while ($answer -ieq "S" -or $answer -ieq "V") {
            $open = @(Get-WinForgeOpenPrograms)

            if ($open.Count -eq 0) { return $true }

            Write-WinForgeStatus -Type Warning -Notice -Message "Ainda abertos: $(Format-WinForgeOpenPrograms -Names $open)."

            $answer = Read-WinForgeChoice -Message "Fechar esses programas antes?" -ShowMenu -TextPrompt "Opção (V = verificar de novo, C = começar assim mesmo, X = cancelar)" -Options @(
                @{ Key = "V"; Label = "Já fechei, verificar de novo"; Accent = $true },
                @{ Key = "C"; Label = "Começar assim mesmo" },
                @{ Key = "X"; Label = "Cancelar"; Exit = $true }
            )

            if ($answer -ieq "C") { return $true }
        }
    }
    catch {
        return $false
    }

    return $false
}


function Confirm-WinForgeMaintenancePreflight {
    # O que pode atrapalhar, em uma linha cada: outra conta, reinício pendente, bateria, pouco espaço e, por último, os
    # programas abertos. Devolve verdadeiro para começar, falso para cancelar ou "Restarting".
    $session = Get-WinForgeSessionInfo

    if ($session.UserMismatch) {
        Write-WinForgeStatus -Type Warning -Notice -Message "O WinForge foi aberto com a senha de outra conta: pastas, inicialização e ajustes vão valer para aquela conta."

        if (-not (Confirm-WinForgeAction "Continuar mesmo assim?" -DefaultKey N)) {
            return $false
        }
    }

    if (Test-WinForgePendingReboot) {
        Write-WinForgeStatus -Type Warning -Notice -Message "O Windows está esperando um reinício."

        # Uma escolha só, com a saída que resolve à mão: um Sim/Não terminaria em "cancelada" sem oferecer o reinício. O
        # reinício ainda pede a confirmação dele (com Não como padrão).
        $answer = Read-WinForgeChoice -Message "Reiniciar antes de otimizar?" -DefaultKey "R" -ShowMenu `
            -TextPrompt "Opção (R = reiniciar agora, C = continuar sem reiniciar, X = cancelar; ENTER = reiniciar agora)" -Options @(
            @{ Key = "R"; Label = "Reiniciar agora"; Description = "Depois, clique em Otimizar de novo"; Accent = $true },
            @{ Key = "C"; Label = "Continuar sem reiniciar" },
            @{ Key = "X"; Label = "Cancelar"; Exit = $true }
        )

        if ($answer -ieq "R") {
            if (Request-WinForgeRestart -Reason "Depois de reiniciar, clique em Otimizar de novo." -Comment "Reinicialização solicitada pelo WinForge antes do Otimizar." -DeclinedMessage "O PC não foi reiniciado; o Otimizar não começou.") {
                return "Restarting"
            }

            return $false
        }

        if ($answer -ine "C") {
            return $false
        }
    }

    if (Test-WinForgeOnBattery) {
        Write-WinForgeStatus -Type Warning -Notice -Message "Ligue o carregador: o Otimizar pode levar mais de uma hora."

        if (-not (Confirm-WinForgeAction "Continuar na bateria?" -DefaultKey N)) {
            return $false
        }
    }

    $freeBytes = Get-WinForgeSystemDriveFreeBytes

    if ((Get-WinForgeDiskSpaceLevel -FreeBytes $freeBytes) -eq "Critical") {
        Write-WinForgeStatus -Type Warning -Notice -Message "Pouco espaço livre no disco do Windows ($(Format-WinForgeBytes -Bytes $freeBytes)): as atualizações podem falhar."
    }

    return (Confirm-WinForgeProgramsClosed)
}


# ---------------------------------------------------------------------------
# Fase 4: as perguntas da parte automática
# ---------------------------------------------------------------------------

function Read-WinForgeMaintenanceDetails {
    # Tudo o que as etapas automáticas precisam saber, perguntado de uma vez, para a parte demorada rodar sem ninguém por
    # perto: o que atualizar no winget, que restos de programas mandar para a Lixeira e se a Lixeira é esvaziada.
    param (
        [string[]]$AutoIds
    )

    $details = [PSCustomObject]@{
        WingetPlan      = $null
        EmptyRecycleBin = $false
        Leftovers       = @()
        LeftoversResult = $null
    }

    if ($AutoIds -contains "winget") {
        Write-WinForgeSection -Title "Atualizar programas (winget)"

        # Edge, Chrome e Firefox ficam com a etapa dos navegadores, pelo atualizador de cada um: na lista do winget, um
        # "Não atualizar" ou um Firefox desmarcado seria desfeito por ela, e "Atualizar todos" os atualizaria duas vezes.
        try {
            $details.WingetPlan = Get-WinForgeWingetUpgradePlan -SkipBrowsers
        }
        catch {
            Write-WinForgeStatus -Type Error -Message "Não foi possível consultar o winget: $($_.Exception.Message)"
            $details.WingetPlan = [PSCustomObject]@{ Action = "Error"; Detail = $_.Exception.Message; Ids = @(); Packages = @() }
        }
    }

    # Os restos são procurados agora, depois das desinstalações do começo: os programas que acabaram de sair entram.
    if ($AutoIds -contains "leftovers") {
        Write-WinForgeSection -Title "Restos de programas desinstalados"

        try {
            $selection = Select-WinForgeProgramLeftovers
            $details.Leftovers = @($selection.Chosen)
            $details.LeftoversResult = $selection.Result
        }
        catch {
            Write-WinForgeStatus -Type Error -Message "Não foi possível procurar os restos: $($_.Exception.Message.TrimEnd('.'))."
            $details.LeftoversResult = New-WinForgeResult -Kind Failed -Detail $_.Exception.Message.TrimEnd('.')
        }
    }

    # A Lixeira é a última chance de recuperar um arquivo apagado por engano: esvaziá-la é uma decisão da pessoa, com o
    # que há nela à vista, e não um efeito da limpeza automática.
    if ($AutoIds -contains "cleanup") {
        $bin = $null
        try { $bin = Get-WinForgeRecycleBinContents } catch { $bin = $null }

        if ($null -eq $bin -or [int]$bin.Count -gt 0) {
            Write-WinForgeSection -Title "Lixeira"

            if ($null -ne $bin) { Write-WinForgeKeyValue -Label "Na Lixeira" -Value (Format-WinForgeRecycleBinText -Contents $bin) }

            # Na janela, os botões dizem o que fazem; "Manter" é a saída segura e a resposta do Enter.
            $details.EmptyRecycleBin = [bool](Confirm-WinForgeAction "Esvaziar a Lixeira? O que está nela é apagado de vez." -DefaultKey N -YesLabel "Esvaziar" -NoLabel "Manter")
        }
    }

    return $details
}


function Confirm-WinForgeAutomaticPhase {
    # O último clique antes da parte demorada: ela roda sem perguntas, e a pessoa pode sair de perto até a revisão dos
    # ajustes, no fim.
    Write-Host ""
    Write-WinForgeStatus -Type Info -Message "A parte automática segue sozinha e pode levar mais de uma hora. No fim, falta revisar os ajustes."

    # Uma entrada que terminou (Ctrl+Z, entrada redirecionada) conta como "não": as telas com você já mudaram o PC, e o
    # resumo e o fim do Otimizar ainda têm de aparecer. Na janela, o Enter faz o mesmo que o botão em destaque.
    try {
        $start = Read-WinForgeChoice -Message "Começar a parte automática?" -ShowMenu -DefaultKey $(if (Test-WinForgeGuiMode) { "S" } else { "" }) -TextPrompt "Opção (S = começar, X = cancelar)" -Options @(
            @{ Key = "S"; Label = "Começar"; Accent = $true },
            @{ Key = "X"; Label = "Cancelar"; Exit = $true }
        )
    }
    catch {
        return $false
    }

    return ($start -ieq "S")
}


# ---------------------------------------------------------------------------
# As etapas
# ---------------------------------------------------------------------------

function ConvertTo-WinForgeStepResult {
    # O resultado de uma tela com você no resumo do Otimizar: desistir da lista ("cancelado pelo usuário") não é uma
    # operação cancelada, é escolher não mudar nada naquela etapa.
    param ([Parameter(Mandatory)]$Result)

    if ([string]$Result.Kind -eq "Skipped" -and [string](Get-WinForgeJsonValue -Object $Result -Name "Detail" -Default "") -match "(?i)cancelad") {
        return (New-WinForgeResult -Kind Skipped -Detail "nada mudou" -Data $Result.Data)
    }

    return $Result
}


function Invoke-WinForgeMaintenanceShortcuts {
    # A etapa dos atalhos quebrados: a mesma correção de Verificar o PC (para a Lixeira, anotada no Histórico de
    # mudanças). Os de pastas do OneDrive ficam de fora: o atalho apagado aqui some também dos outros PCs da pessoa.
    $title = "Remover atalhos quebrados"

    Write-Progress -Activity $title -Status "conferindo os atalhos"

    try { $broken = @(Find-WinForgeBrokenShortcuts | Where-Object { -not [bool](Get-WinForgeJsonValue -Object $_ -Name "Synced" -Default $false) }) }
    finally { Write-Progress -Activity $title -Completed }

    if ($broken.Count -eq 0) {
        Write-WinForgeStatus -Type Success -Message "Nenhum atalho quebrado."
        return (New-WinForgeResult -Kind Ok -Detail "nenhum atalho quebrado")
    }

    foreach ($shortcut in $broken) {
        Write-WinForgeKeyValue -Label $shortcut.Name -Value "aponta para $($shortcut.Target), que não existe mais"
    }

    $finding = New-WinForgeCheckupFinding -Id "shortcuts" -Label "Atalhos" -Value (Format-WinForgeCount -Count $broken.Count -One "atalho quebrado" -Many "atalhos quebrados") -Fix "shortcuts" -FixLabel $title -Data $broken
    $result = Invoke-WinForgeCheckupFix -Finding $finding
    $detail = [string]$result.Detail

    if ($result.Kind -eq "Ok" -and $detail) { Write-WinForgeStatus -Type Success -Message "$($detail.Substring(0, 1).ToUpper())$($detail.Substring(1))." }

    return $result
}


function Invoke-WinForgeMaintenanceRegistry {
    # A etapa do registro: a mesma correção de Verificar o PC (backup antes, desfazer no Histórico de mudanças). As
    # bibliotecas compartilhadas (SharedDLLs) ficam de fora: é uma contagem que instaladores consultam, e quem decide
    # removê-la é a pessoa, em Limpeza > Limpar o registro.
    $title = "Limpar o registro"

    Write-Progress -Activity $title -Status "procurando referências quebradas no registro"

    try { $issues = @(Find-WinForgeRegistryIssues | Where-Object { $_.Category -ne "shared-dlls" }) }
    finally { Write-Progress -Activity $title -Completed }

    if ($issues.Count -eq 0) {
        Write-WinForgeStatus -Type Success -Message "Nenhuma referência quebrada no registro."
        return (New-WinForgeResult -Kind Ok -Detail "nenhuma referência quebrada")
    }

    Write-WinForgeKeyValue -Label "Referências quebradas" -Value $issues.Count
    $result = Clear-WinForgeRegistryIssues -Issues $issues

    if ($result.Kind -in @("Ok", "Warning")) {
        Write-WinForgeStatus -Type Info -Message "O backup foi salvo antes; para desfazer, use Manutenção > Histórico de mudanças."
    }

    return $result
}


function Invoke-WinForgeMaintenanceStepAction {
    param (
        [Parameter(Mandatory)]
        [string]$Id,

        [Parameter(Mandatory)]
        $Details
    )

    switch ($Id) {
        # A pessoa está presente no começo: sem a Proteção do Sistema, o ponto oferece ligá-la (Não como padrão).
        "restore-point" { Invoke-WinForgeRestorePoint -Embedded -PassThru -OfferProtection -Description "WinForge - antes do Otimizar" }
        "uninstall" {
            $uninstall = Invoke-WinForgeNestedAction -Command "Uninstall-WinForgeSoftware"

            # Sem o winget (Windows LTSC, Windows 10 sem o Instalador de Aplicativo), a tela não tem como rodar: não é uma
            # falha do Otimizar, como na etapa do winget.
            if ($null -ne $uninstall -and [string]$uninstall.Kind -eq "Failed" -and [string]$uninstall.Detail -eq (Get-WinForgeWingetMissingDetail)) {
                New-WinForgeResult -Kind Skipped -Detail "winget não encontrado"
            }
            else {
                ConvertTo-WinForgeStepResult -Result $uninstall
            }
        }
        "windows-apps"  { ConvertTo-WinForgeStepResult -Result (Invoke-WinForgeNestedAction -Command "Remove-WinForgePreinstalledApps") }
        "startup"       { ConvertTo-WinForgeStepResult -Result (Invoke-WinForgeNestedAction -Command "Set-WinForgeStartupItems" -Arguments @{ Review = $true }) }
        "folders"       { Invoke-WinForgeFolderReview -Embedded -PassThru }
        "security"      { Invoke-WinForgeSecurityCheck -Embedded -PassThru }
        "early-updates" { Disable-WinForgeEarlyUpdates -Embedded -PassThru }
        "windows-update" { Install-WinForgePendingUpdates -Embedded -PassThru }
        "drivers"       { Invoke-WinForgeDeviceScan -Embedded -PassThru }
        "winget" {
            Enter-WinForgeAction -Title "Atualizar programas (winget)" -Embedded

            if ($null -eq $Details.WingetPlan) {
                Write-WinForgeStatus -Type Info -Message "As atualizações do winget não foram revisadas nesta execução."
                New-WinForgeResult -Kind Skipped -Detail "não revisado"
            }
            elseif ([string]$Details.WingetPlan.Action -eq "Unavailable") {
                # Sem o winget no PC, a etapa não tem como rodar: não é uma falha do Otimizar (nem um "problema repetido"
                # no histórico a cada mês).
                Write-WinForgeStatus -Type Info -Message "O winget não está instalado neste PC; a etapa foi ignorada. Ele vem com o Instalador de Aplicativo, da Microsoft Store."
                New-WinForgeResult -Kind Skipped -Detail "winget não encontrado"
            }
            else {
                # "Não atualizar" é escolher não mudar nada nesta etapa, como desistir de uma tela com você.
                ConvertTo-WinForgeStepResult -Result (Invoke-WinForgeWingetUpgradePlan -Plan $Details.WingetPlan)
            }
        }
        "browsers"      { Update-WinForgeBrowsers -Embedded -PassThru }
        "store"         { Update-WinForgeStoreApps -Embedded -PassThru }
        "shortcuts"     { Invoke-WinForgeMaintenanceShortcuts }
        "leftovers" {
            $chosen = @(Get-WinForgeJsonValue -Object $Details -Name "Leftovers" -Default @() | Where-Object { $null -ne $_ })
            $earlier = Get-WinForgeJsonValue -Object $Details -Name "LeftoversResult" -Default $null

            if ($chosen.Count -gt 0) {
                Remove-WinForgeProgramLeftovers -Items $chosen
            }
            elseif ($null -ne $earlier) {
                # A busca já disse o que houve (nenhum programa, nenhum resto, desistência): esse é o resultado da etapa.
                ConvertTo-WinForgeStepResult -Result $earlier
            }
            else {
                New-WinForgeResult -Kind Skipped -Detail "nenhuma pasta escolhida"
            }
        }
        "registry"      { Invoke-WinForgeMaintenanceRegistry }
        "components" {
            # Com a manutenção dos componentes esperando o reinício (uma atualização que o Windows instalou sozinho), o DISM
            # recusa a limpeza (0x800F0806): ela fica para a próxima vez, sem virar uma falha. Os outros motivos de reinício
            # (um driver, um nome novo do PC) não atrapalham o DISM e não seguram a etapa.
            if (Test-WinForgeServicingRebootPending) {
                Enter-WinForgeAction -Title "Limpar componentes do Windows (WinSxS)" -Embedded
                Write-WinForgeStatus -Type Info -Message "Há um reinício pendente: o Windows só limpa os componentes depois de reiniciar. A limpeza fica para o próximo Otimizar."
                New-WinForgeResult -Kind Skipped -Detail "reinício pendente; fica para depois de reiniciar"
            }
            else {
                Invoke-WinForgeComponentCleanup -Embedded -PassThru
            }
        }
        "cleanup" {
            if ([bool](Get-WinForgeJsonValue -Object $Details -Name "EmptyRecycleBin" -Default $false)) { Invoke-WinForgeQuickCleanup -Embedded -PassThru }
            else { Invoke-WinForgeQuickCleanup -Embedded -PassThru -SkipRecycleBin }
        }
        "network"       { Invoke-WinForgeNetworkRepair -Embedded -PassThru -Force }
        # Sem -CheckFirst: o Otimizar roda o DISM /RestoreHealth sempre, mesmo sem sinal de dano. Com a manutenção dos
        # componentes esperando o reinício, o DISM recusa o reparo (0x800F0806) e o SFC também: a etapa fica para depois de
        # reiniciar, sem virar uma falha.
        "repair" {
            if (Test-WinForgeServicingRebootPending) {
                Enter-WinForgeAction -Title "Reparar o Windows (DISM + SFC)" -Embedded
                Write-WinForgeStatus -Type Info -Message "Há um reinício pendente: o DISM e o SFC só reparam depois de reiniciar. Depois do reinício, use Reparo > Reparar o Windows (DISM + SFC)."
                New-WinForgeResult -Kind Skipped -Detail "reinício pendente; rode depois de reiniciar"
            }
            else {
                Invoke-WinForgeDismAndSfc -Embedded -PassThru
            }
        }
        "chkdsk"        { Start-WinForgeChkdsk -DeferRepairPrompt -Embedded -PassThru }
        "optimize"      { Start-WinForgeDriveOptimization -Embedded -PassThru }
        "tweaks"        { Invoke-WinForgeTweakReview -Embedded -PassThru }
        default         { throw "Etapa desconhecida: $Id" }
    }
}


function Invoke-WinForgeMaintenanceStep {
    # Roda uma etapa e devolve exatamente um WinForge.Result, aconteça o que acontecer dentro dela.
    param (
        [Parameter(Mandatory)]
        $Step,

        [Parameter(Mandatory)]
        $Details,

        [int]$Position,
        [int]$Total
    )

    Write-Host ""

    if (Test-WinForgeGuiMode) {
        # Na janela, "Etapa 3 de 21: ..." fica em destaque no alto da tela de execução e vira um subtítulo do resumo.
        Write-WinForgeSubStep -Title "Etapa $Position de ${Total}: $($Step.Title)"
    }
    else {
        Write-WinForgeProgress -Current ($Position - 1) -Total $Total -Label "Próxima: $($Step.Title)"
    }

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $result = $null

    try {
        $output = @(Invoke-WinForgeMaintenanceStepAction -Id $Step.Id -Details $Details)

        $results = @($output | Where-Object { $null -ne $_ -and $_.PSObject.TypeNames -contains "WinForge.Result" })
        $others = @($output | Where-Object { $null -ne $_ -and -not ($_.PSObject.TypeNames -contains "WinForge.Result") })

        # Texto ou objetos soltos de uma etapa aparecem na tela, mas nunca entram no resumo.
        if ($others.Count -gt 0) {
            $others | Out-Host
        }

        if ($results.Count -gt 0) {
            $result = $results[$results.Count - 1]
        }
        else {
            $result = New-WinForgeResult -Kind Ok
        }
    }
    catch {
        Write-Host ""
        Write-WinForgeStatus -Type Error -Message "Falha nesta etapa ($($Step.Title)): $($_.Exception.Message)"

        # Na última etapa não há "próxima": a frase prometeria uma etapa que não vem.
        if ($Position -lt $Total) { Write-Host "      O WinForge continuará para a próxima etapa." -ForegroundColor DarkGray }

        $result = New-WinForgeResult -Kind Failed -Detail $_.Exception.Message
    }

    $stopwatch.Stop()

    $result.Etapa = $Step.Title
    $result.Duracao = Format-WinForgeDuration -Span $stopwatch.Elapsed
    Add-Member -InputObject $result -NotePropertyName "StepId" -NotePropertyValue $Step.Id -Force

    return $result
}


function Invoke-WinForgeMaintenancePhase {
    # Roda as etapas pedidas de uma fase (StepIds), na ordem do plano. Start: a posição da primeira (a numeração "Etapa N
    # de M" corre pelo Otimizar inteiro); Total: quantas etapas o Otimizar tem ao todo. A parte automática (-KeepAwake)
    # impede o Windows de suspender o PC no meio das atualizações, do DISM e do CHKDSK.
    param (
        [Parameter(Mandatory)]
        [ValidateSet("Before", "Auto", "After")]
        [string]$Phase,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$StepIds,

        [Parameter(Mandatory)]
        $Details,

        [int]$Start = 1,
        [int]$Total = 0,

        [switch]$KeepAwake
    )

    $catalog = @(Get-WinForgeMaintenancePlanItems | Where-Object { $_.Phase -eq $Phase })
    $steps = @($catalog | Where-Object { $StepIds -contains $_.Id })
    $results = @()

    if ($Total -lt ($Start + $steps.Count - 1)) { $Total = $Start + $steps.Count - 1 }

    if ($KeepAwake) { [void](Set-WinForgeKeepAwake -Enabled $true) }

    try {
        $position = $Start - 1

        foreach ($step in $steps) {
            $position++
            $results += @(Invoke-WinForgeMaintenanceStep -Step $step -Details $Details -Position $position -Total $Total)
        }
    }
    finally {
        if ($KeepAwake) { [void](Set-WinForgeKeepAwake -Enabled $false) }
    }

    return @($results)
}


# ---------------------------------------------------------------------------
# Antes e depois
# ---------------------------------------------------------------------------

function Get-WinForgeMaintenanceSnapshot {
    # Uma foto do PC para comparar o começo com o fim da manutenção: espaço livre no disco do sistema e quantos
    # programas abrem junto com o Windows. O que não puder ser lido fica $null e some da comparação.
    $freeBytes = $null
    $startupItems = $null

    try {
        $space = Get-WinForgeSystemDriveSpace
        if ($null -ne $space) { $freeBytes = [int64]$space.FreeBytes }
    }
    catch {
        $freeBytes = $null
    }

    try {
        $startupItems = [int]@(Get-WinForgeStartupItems | Where-Object { $_.Enabled }).Count
    }
    catch {
        $startupItems = $null
    }

    return [PSCustomObject]@{ At = (Get-Date); FreeBytes = $freeBytes; StartupItems = $startupItems }
}


function Format-WinForgeSignedBytes {
    # "+11,5 GB" / "-2 GB"; menos de 1 MB de diferença conta como "sem mudança".
    param ([int64]$Delta)

    if ([math]::Abs($Delta) -lt 1MB) {
        return "sem mudança"
    }

    $sign = $(if ($Delta -gt 0) { "+" } else { "-" })

    return "$sign$(Format-WinForgeBytes -Bytes ([math]::Abs($Delta)))"
}


function Get-WinForgeSnapshotComparison {
    # As linhas "antes e depois" (Label e Text) entre duas fotos. Linha cujo dado falta em uma das fotos não aparece.
    param (
        $Before,
        $After
    )

    $rows = @()

    if ($null -eq $Before -or $null -eq $After) {
        return @()
    }

    if ($null -ne $Before.FreeBytes -and $null -ne $After.FreeBytes) {
        $rows += [PSCustomObject]@{
            Label = "Espaço livre no disco do sistema"
            Text  = "de $(Format-WinForgeBytes -Bytes $Before.FreeBytes) para $(Format-WinForgeBytes -Bytes $After.FreeBytes) ($(Format-WinForgeSignedBytes -Delta ([int64]$After.FreeBytes - [int64]$Before.FreeBytes)))"
        }
    }

    if ($null -ne $Before.StartupItems -and $null -ne $After.StartupItems) {
        $delta = [int]$After.StartupItems - [int]$Before.StartupItems
        $change = $(if ($delta -eq 0) { "sem mudança" } elseif ($delta -gt 0) { "+$delta" } else { "$delta" })

        $rows += [PSCustomObject]@{
            Label = "Programas que abrem com o Windows"
            Text  = "de $($Before.StartupItems) para $($After.StartupItems) ($change)"
        }
    }

    return @($rows)
}


# ---------------------------------------------------------------------------
# Resumo e encerramento
# ---------------------------------------------------------------------------

function Show-WinForgeMaintenanceSummary {
    param (
        [object[]]$Results,
        [datetime]$StartedAt,

        # Fotos do PC no começo e no fim (Get-WinForgeMaintenanceSnapshot); sem elas não há comparação.
        $Before = $null,
        $After = $null,

        # Como rodou (optimize; as manutenções antigas guardavam quick, full ou deep), para o histórico.
        [string]$ProfileId = "optimize",

        # O desfecho já calculado por quem chama (com a parte automática cancelada, por exemplo); sem ele, a conta é a de
        # Get-WinForgeMaintenanceResult, a mesma da faixa de resultado.
        $Verdict = $null,

        # Não grava no histórico nem como última manutenção (a parte automática foi cancelada: segurança, atualizações e
        # reparos não rodaram, e o Início deve continuar lembrando do Otimizar).
        [switch]$NoRecord,

        # A execução, para a gravação do fim substituir a do meio (Set-WinForgeLastMaintenance -RunId).
        [string]$RunId = ""
    )

    Write-WinForgeSection -Title "Resumo"

    # Só resultados formais de etapa compõem a tabela.
    $summaryResults = @($Results | Where-Object { $null -ne $_ -and $null -ne $_.PSObject.Properties["Etapa"] -and $null -ne $_.PSObject.Properties["Status"] })

    Write-WinForgeResultTable -Results $summaryResults

    if (-not $NoRecord) {
        Set-WinForgeLastMaintenance -Results $summaryResults -StartedAt $StartedAt -Before $Before -After $After -ProfileId $ProfileId -RunId $RunId
    }

    $comparison = @(Get-WinForgeSnapshotComparison -Before $Before -After $After)

    if ($comparison.Count -gt 0) {
        Write-WinForgeSection -Title "Antes e depois"

        foreach ($row in $comparison) {
            Write-WinForgeKeyValue -Label $row.Label -Value $row.Text -LabelWidth 34
        }
    }

    # Na janela, o desfecho e a duração ficam na faixa de resultado e ao lado do título: repetidos no resumo, eram três
    # vezes a mesma informação na mesma tela.
    if (Test-WinForgeGuiMode) { return }

    Write-Host ""

    # A mesma conta da faixa de resultado (Get-WinForgeMaintenanceResult): tudo ignorado não é "tudo concluído".
    if ($null -eq $Verdict) { $Verdict = Get-WinForgeMaintenanceResult -Results $summaryResults -Before $Before -After $After }
    $detail = [string]$Verdict.Detail
    $sentence = $(if ($detail) { $detail.Substring(0, 1).ToUpper() + $detail.Substring(1) } else { "" })

    switch ([string]$Verdict.Kind) {
        "Ok" { Write-WinForgeStatus -Type Success -Message "Otimização concluída: $detail." }
        "Skipped" { Write-WinForgeStatus -Type Info -Message "$sentence." }
        "Failed" { Write-WinForgeStatus -Type Error -Message "$sentence. Veja acima o que cada etapa disse." }
        default { Write-WinForgeStatus -Type Warning -Message "$sentence. Veja acima o que cada etapa disse." }
    }

    # O caminho do log fica no botão "Abrir log" dos detalhes técnicos (e no Sobre): o resumo diz só a duração.
    Write-WinForgeStatus -Type Info -Message "Duração: $(Format-WinForgeDuration -Span ((Get-Date) - $StartedAt))."
}


function Test-WinForgeMaintenanceNeedsRestart {
    param (
        [object[]]$Results,
        [bool]$ChkdskScheduled
    )

    if ($ChkdskScheduled) {
        return $true
    }

    if (Test-WinForgePendingReboot) {
        return $true
    }

    foreach ($result in @($Results)) {
        if ($null -eq $result) { continue }

        # Cada etapa avisa por Data quando uma mudança só termina depois de reiniciar: as atualizações do Windows, o
        # reparo de rede (quando os resets de Winsock e TCP/IP funcionaram), o DISM e o SFC, quando o reparo pede, e um
        # ajuste que só vale depois de reiniciar.
        if (Test-WinForgeResultFlag -Result $result -Name "RebootRequired") {
            return $true
        }
    }

    return $false
}


function Request-WinForgeRestart {
    <#
    Oferece reiniciar o Windows (Não como padrão) e, com o sim, reinicia na hora, sem fechar nada à força: com um prazo
    (shutdown /t 30, por exemplo), o Windows fecha os programas à força (o /f vem junto) e um arquivo sem salvar se perde.
    Sem prazo, um programa com algo por salvar segura o reinício e o Windows pergunta antes de fechá-lo, com a opção de
    cancelar. Devolve verdadeiro quando o reinício começou. -Reason: a frase do porquê; -Comment: o motivo que fica
    registrado no Windows.
    #>
    param (
        [switch]$ChkdskScheduled,
        [string]$Reason = "Reinicie para concluir a otimização.",
        [string]$Comment = "Reinicialização solicitada pelo WinForge após o Otimizar.",
        [string]$DeclinedMessage = "O PC não foi reiniciado. Reinicie quando puder."
    )

    Write-WinForgeSection -Title "Reiniciar o PC"
    Write-WinForgeStatus -Type Info -Message $Reason

    if ($ChkdskScheduled) {
        Write-WinForgeStatus -Type Info -Message "O reparo do disco roda antes de o Windows abrir e pode demorar."
    }

    Write-Host ""

    if (-not (Confirm-WinForgeAction "Reiniciar o Windows agora? Salve o que estiver aberto antes." -DefaultKey N -YesLabel "Reiniciar agora" -NoLabel "Depois")) {
        Write-WinForgeStatus -Type Info -Message $DeclinedMessage
        return $false
    }

    # O shutdown.exe bloqueado (por uma política da empresa, por exemplo) não pode derrubar o fim do Otimizar: o reinício
    # volta a ser pendência, como quando o Windows o recusa.
    try {
        $run = Invoke-WinForgeCapture -FilePath "shutdown.exe" -Arguments @("/r", "/t", "0", "/c", $Comment)
    }
    catch {
        Write-WinForgeStatus -Type Error -Message "Não foi possível reiniciar: $(([string]$_.Exception.Message).Trim().TrimEnd('.')). Reinicie pelo menu Iniciar."
        return $false
    }

    if ($run.ExitCode -ne 0) {
        Write-WinForgeStatus -Type Error -Message "Não foi possível reiniciar (código $($run.ExitCode)): $($run.Text.Trim())"
        return $false
    }

    Write-WinForgeStatus -Type Success -Message "O Windows está reiniciando. Se algum programa tiver arquivo sem salvar, o Windows pergunta antes de fechá-lo."

    return $true
}


function Invoke-WinForgeMaintenanceClosing {
    # O fim do Otimizar: o reparo offline do CHKDSK (se a verificação achou problema), o relatório e, sempre, a sugestão
    # de reiniciar; sem reiniciar, o Explorador, quando algum ajuste só aparece depois dele. Devolve verdadeiro quando o
    # Windows ainda precisa reiniciar para concluir (a faixa lembra disso).
    param (
        [object[]]$Results,
        [string[]]$StepIds
    )

    # O reparo offline do CHKDSK só é oferecido se a verificação rodou nesta otimização.
    $chkdskScheduled = $false

    if ($StepIds -contains "chkdsk" -and (Test-WinForgeChkdskRepairPending)) {
        Write-WinForgeSection -Title "CHKDSK"
        # Na janela, as mensagens ficam no resumo, à vista durante a pergunta. Erro no disco pode ser o disco falhando.
        # O código 3 do CHKDSK também é "não deu para verificar tudo com o Windows aberto": a frase não afirma que há erro.
        Write-WinForgeStatus -Type Warning -Message "O CHKDSK pede um reparo que só roda ao reiniciar."
        Write-WinForgeStatus -Type Info -Message "Ele roda antes de o Windows abrir e pode levar horas; não desligue o PC até o Windows abrir."
        Write-Host ""

        if (Confirm-WinForgeAction "Agendar o reparo do disco para a próxima reinicialização?" -DefaultKey N) {
            $chkdskScheduled = [bool](Invoke-WinForgeScheduleChkdskRepair)
        }
    }

    # Sem a pergunta do relatório: ele continua em Diagnóstico > Exportar relatório, e o histórico guarda o Otimizar.
    Write-Host ""

    # O Otimizar sempre sugere reiniciar: o Windows começa do zero, com tudo o que mudou já valendo. Quando alguma etapa
    # só termina com o reinício, a frase diz isso, e a faixa lembra dele se a pessoa não reiniciar.
    $needed = Test-WinForgeMaintenanceNeedsRestart -Results $Results -ChkdskScheduled $chkdskScheduled
    $reason = $(if ($needed) { "Reinicie para concluir: algumas mudanças só valem depois do reinício." } else { "Reinicie para o Windows começar do zero, com tudo o que mudou valendo." })
    $declined = $(if ($needed) { "O PC não foi reiniciado. Reinicie quando puder para concluir." } else { "O PC não foi reiniciado. Reinicie quando puder." })

    $restarting = Request-WinForgeRestart -ChkdskScheduled:$chkdskScheduled -Reason $reason -DeclinedMessage $declined

    if (-not $restarting) {
        Invoke-WinForgeExplorerRestartOffer -Results $Results
    }

    # Mesmo com o reinício pedido, a faixa lembra dele quando ele é necessário: um programa com arquivo sem salvar pode
    # segurá-lo, e a pessoa pode cancelar na tela do Windows.
    return [bool]$needed
}


function Invoke-WinForgeExplorerRestartOffer {
    # Alguns ajustes (as extensões dos arquivos, os itens ocultos) só aparecem quando o Explorador reinicia: sem o
    # reinício do Windows, o Otimizar oferece só isso.
    param (
        [object[]]$Results
    )

    $needsExplorer = @($Results | Where-Object { $null -ne $_ -and $_.Kind -in @("Ok", "Warning") -and (Test-WinForgeResultFlag -Result $_ -Name "ExplorerRestart") }).Count -gt 0

    if (-not $needsExplorer) {
        return
    }

    Write-Host ""

    # Reiniciar o Explorador fecha as janelas de pastas abertas: no fim de uma execução longa, sem ninguém para responder,
    # nada acontece sozinho (Não como padrão).
    if (Confirm-WinForgeAction "Reiniciar o Explorador de Arquivos agora para ver os ajustes?" -DefaultKey N -YesLabel "Reiniciar o Explorador" -NoLabel "Depois") {
        try {
            Restart-WinForgeExplorerShell
            Write-WinForgeStatus -Type Success -Message "Explorador reiniciado."
        }
        catch {
            Write-WinForgeStatus -Type Error -Message "Não foi possível reiniciar o Explorador: $($_.Exception.Message)"
        }
    }
}


# ---------------------------------------------------------------------------
# Desfecho
# ---------------------------------------------------------------------------

function Get-WinForgeMaintenanceResult {
    <#
    O desfecho do Otimizar, que a janela mostra na faixa de resultado: Falhou quando nenhuma etapa
    funcionou, Atenção quando alguma falhou ou terminou com ressalvas, Ok nos demais casos e Ignorado quando todas as
    etapas foram ignoradas. RestartPending: o Windows ainda precisa reiniciar (a faixa lembra disso).
    #>
    param (
        [object[]]$Results,
        [bool]$RestartPending = $false,

        # Fotos do começo e do fim (Get-WinForgeMaintenanceSnapshot): com 100 MB ou mais de espaço livre a mais, a faixa
        # diz isso, que é o que a pessoa percebe da manutenção.
        $Before = $null,
        $After = $null
    )

    $steps = @($Results | Where-Object { $null -ne $_ -and $null -ne $_.PSObject.Properties["Kind"] })
    $count = { param ([string]$Kind) @($steps | Where-Object { $_.Kind -eq $Kind }).Count }
    # Os nomes das etapas de um desfecho; sem nome em alguma delas, a frase usa a contagem.
    $namesOf = {
        param ([string]$Kind)
        @($steps | Where-Object { $_.Kind -eq $Kind } | ForEach-Object { [string](Get-WinForgeJsonValue -Object $_ -Name "Etapa" -Default "") })
    }
    # Até três nomes ("A, B e C"); passando disso, "A, B, C e mais 2".
    $listOf = {
        param ([string[]]$Names)
        if ($Names.Count -gt 3) { return "$(@($Names | Select-Object -First 3) -join ', ') e mais $($Names.Count - 3)" }
        return (Join-WinForgeList -Items $Names)
    }

    $failed = [int](& $count "Failed")
    $warned = [int](& $count "Warning")
    $skipped = [int](& $count "Skipped")
    $done = $steps.Count - $skipped

    $data = @{}

    if ($RestartPending) { $data.RebootRequired = $true }

    $gain = ""

    if ($null -ne $Before -and $null -ne $After) {
        $beforeFree = Get-WinForgeJsonValue -Object $Before -Name "FreeBytes" -Default $null
        $afterFree = Get-WinForgeJsonValue -Object $After -Name "FreeBytes" -Default $null

        if ($null -ne $beforeFree -and $null -ne $afterFree -and ([int64]$afterFree - [int64]$beforeFree) -ge 100MB) {
            $gain = "; $(Format-WinForgeBytes -Bytes ([int64]$afterFree - [int64]$beforeFree)) a mais de espaço livre"
        }
    }

    if ($steps.Count -eq 0) {
        return (New-WinForgeResult -Kind Skipped -Detail "nenhuma etapa rodou" -Data $data)
    }

    if ($done -eq 0) {
        return (New-WinForgeResult -Kind Skipped -Detail "todas as etapas foram ignoradas" -Data $data)
    }

    if ($failed -eq $done) {
        return (New-WinForgeResult -Kind Failed -Detail $(if ($failed -eq 1) { "a única etapa falhou" } else { "as $failed etapas falharam" }) -Data $data)
    }

    if ($failed -gt 0 -or $warned -gt 0) {
        $failedNames = @(& $namesOf "Failed")
        $warnedNames = @(& $namesOf "Warning")
        # Até duas etapas, a faixa diz quais são, para a pessoa saber onde olhar no resumo; com mais, a lista de nomes não
        # caberia numa frase, e a faixa diz quantas (o resumo, logo abaixo, tem uma linha por etapa).
        $named = (($failed + $warned) -le 2 -and @(@($failedNames) + @($warnedNames) | Where-Object { [string]::IsNullOrWhiteSpace($_) }).Count -eq 0)
        $parts = @()

        if ($named) {
            if ($failed -gt 0) { $parts += "$(& $listOf $failedNames) $(if ($failed -eq 1) { 'falhou' } else { 'falharam' })" }
            if ($warned -gt 0) { $parts += "$(& $listOf $warnedNames) $(if ($warned -eq 1) { 'terminou' } else { 'terminaram' }) com ressalvas" }

            return (New-WinForgeResult -Kind Warning -Detail (($parts -join "; ") + $gain) -Data $data)
        }

        if ($failed -gt 0) { $parts += $(if ($failed -eq 1) { "1 etapa falhou" } else { "$failed etapas falharam" }) }

        if ($warned -gt 0) {
            # Depois de "1 etapa falhou e", a palavra "etapa" fica subentendida; sozinha, a frase precisa dela.
            $noun = $(if ($failed -gt 0) { "" } elseif ($warned -eq 1) { "etapa " } else { "etapas " })
            $parts += $(if ($warned -eq 1) { "1 ${noun}terminou com ressalvas" } else { "$warned ${noun}terminaram com ressalvas" })
        }

        return (New-WinForgeResult -Kind Warning -Detail (($parts -join " e ") + $gain) -Data $data)
    }

    $text = $(if ($done -eq 1) { "1 etapa executada" } else { "$done etapas executadas" })

    if ($skipped -gt 0) { $text += $(if ($skipped -eq 1) { " e 1 ignorada" } else { " e $skipped ignoradas" }) }

    return (New-WinForgeResult -Kind Ok -Detail ($text + $gain) -Data $data)
}


# ---------------------------------------------------------------------------
# Ação principal
# ---------------------------------------------------------------------------

function Invoke-WinForgeRecommendedMaintenance {
    # O Otimizar (o botão do Início e Manutenção > Otimizar): veja as fases no alto deste arquivo.
    Enter-WinForgeAction -Title "Otimizar"

    if (-not (Test-WinForgeElevation -Reason "O Otimizar exige privilégios de Administrador.")) {
        Exit-WinForgeAction -Result (New-WinForgeResult -Kind Failed -Detail "requer Administrador")
        return
    }

    $cancelled = {
        Write-Host ""
        Write-WinForgeStatus -Type Warning -Message "Otimização cancelada."
        Exit-WinForgeAction -Result (New-WinForgeResult -Kind Skipped -Detail "operação cancelada")
    }

    # Fase 1: preparação. "Restarting": a pessoa escolheu reiniciar antes (havia um reinício pendente) e o Windows já
    # está reiniciando; o Otimizar fica para depois.
    $preflight = Confirm-WinForgeMaintenancePreflight

    if ($preflight -is [string] -and $preflight -eq "Restarting") {
        Exit-WinForgeAction -Result (New-WinForgeResult -Kind Skipped -Detail "o PC está reiniciando; depois, abra o WinForge e clique em Otimizar de novo")
        return
    }

    if (-not $preflight) {
        & $cancelled
        return
    }

    # Fase 2: o plano é sempre o inteiro, sem lista para escolher: cada etapa decide sozinha se tem o que fazer (e as
    # telas com você deixam escolher o que entra nelas).
    $items = @(Get-WinForgeMaintenancePlanItems)
    $beforeIds = @($items | Where-Object { $_.Phase -eq "Before" } | ForEach-Object { $_.Id })
    $autoIds = @($items | Where-Object { $_.Phase -eq "Auto" } | ForEach-Object { $_.Id })
    $afterIds = @($items | Where-Object { $_.Phase -eq "After" } | ForEach-Object { $_.Id })
    $total = $items.Count

    # A foto do "antes" vem antes de tudo: desinstalar e desativar programas da inicialização também contam.
    $before = Get-WinForgeMaintenanceSnapshot
    $startedAt = Get-Date
    $runId = [guid]::NewGuid().ToString("N")

    $details = [PSCustomObject]@{ WingetPlan = $null; EmptyRecycleBin = $false; Leftovers = @(); LeftoversResult = $null }

    # Fase 3: com você, no começo. O ponto de restauração vem antes de qualquer mudança, e sem ele (Proteção do Sistema
    # desligada e a pessoa não quis ligá-la, ou o Windows recusou) a pessoa decide se segue sem a rede de segurança, com
    # Não como padrão: desinstalar, o registro, a rede e os ajustes não teriam para onde voltar.
    $results = @(Invoke-WinForgeMaintenancePhase -Phase Before -StepIds @("restore-point") -Details $details -Start 1 -Total $total)

    if (@($results | Where-Object { Test-WinForgeResultFlag -Result $_ -Name "NotCreated" }).Count -gt 0) {
        Write-Host ""

        if (-not (Confirm-WinForgeAction "Continuar sem o ponto de restauração?" -DefaultKey N)) {
            & $cancelled
            return
        }
    }

    $results += @(Invoke-WinForgeMaintenancePhase -Phase Before -StepIds @($beforeIds | Where-Object { $_ -ne "restore-point" }) -Details $details -Start 2 -Total $total)

    # Fase 4: as perguntas da parte automática, depois das desinstalações (que mudam a lista do winget e os restos)
    $details = Read-WinForgeMaintenanceDetails -AutoIds $autoIds

    if (-not (Confirm-WinForgeAutomaticPhase)) {
        # Nada mudou até aqui (todas as telas com você foram puladas e o ponto não foi criado): é só um cancelamento.
        if (@($results | Where-Object { [string]$_.Kind -ne "Skipped" }).Count -eq 0) {
            & $cancelled
            return
        }

        # As telas com você já mudaram o PC: o resumo mostra o que foi feito, mas a execução não conta como manutenção
        # (segurança, atualizações e reparos não rodaram, e o Início continua lembrando do Otimizar).
        Write-Host ""
        Write-WinForgeStatus -Type Warning -Message "Parte automática cancelada. O que já foi feito continua valendo."

        $after = Get-WinForgeMaintenanceSnapshot
        $partial = Get-WinForgeMaintenanceResult -Results $results -Before $before -After $after
        $verdict = New-WinForgeResult -Kind Warning -Detail "a parte automática foi cancelada; $($partial.Detail)" -Data $partial.Data

        Show-WinForgeMaintenanceSummary -Results $results -StartedAt $startedAt -Before $before -After $after -Verdict $verdict -NoRecord
        $restartPending = [bool](@(Invoke-WinForgeMaintenanceClosing -Results $results -StepIds @()) | Select-Object -Last 1)

        $outcome = New-WinForgeResult -Kind Warning -Detail $verdict.Detail -Data $(if ($restartPending) { @{ RebootRequired = $true } } else { @{} })
        Exit-WinForgeAction -Result $outcome
        return
    }

    # Fase 5: automática. No fim dela, o resultado já fica gravado: a revisão dos ajustes espera a pessoa, e uma janela
    # fechada ou um reinício do Windows Update nessa espera não podem apagar uma hora de manutenção. O fim do Otimizar
    # grava de novo, por cima da mesma execução (o mesmo RunId).
    $results += @(Invoke-WinForgeMaintenancePhase -Phase Auto -StepIds $autoIds -Details $details -Start ($beforeIds.Count + 1) -Total $total -KeepAwake)

    try {
        Set-WinForgeLastMaintenance -Results $results -StartedAt $startedAt -Before $before -After (Get-WinForgeMaintenanceSnapshot) -ProfileId "optimize" -RunId $runId
    }
    catch {
        Write-Verbose "Gravação parcial do Otimizar: $($_.Exception.Message)"
    }

    # Fase 6: com você, no fim
    $results += @(Invoke-WinForgeMaintenancePhase -Phase After -StepIds $afterIds -Details $details -Start ($beforeIds.Count + $autoIds.Count + 1) -Total $total)

    # Fase 7: resumo e encerramento
    $after = Get-WinForgeMaintenanceSnapshot
    Show-WinForgeMaintenanceSummary -Results $results -StartedAt $startedAt -Before $before -After $after -ProfileId "optimize" -RunId $runId

    $restartPending = [bool](@(Invoke-WinForgeMaintenanceClosing -Results $results -StepIds $autoIds) | Select-Object -Last 1)

    # O desfecho é o das etapas: a contagem das mensagens de estado trataria o aviso do preparo ("Salve seu trabalho...")
    # como uma ressalva e mostraria só a última mensagem de erro.
    $outcome = Get-WinForgeMaintenanceResult -Results $results -RestartPending $restartPending -Before $before -After $after

    Exit-WinForgeAction -Result $outcome
}


# ---------------------------------------------------------------------------
# Histórico
# ---------------------------------------------------------------------------

function Format-WinForgeHistoryLine {
    <#
    Uma manutenção do histórico em uma linha: como rodou (Otimizar, ou o perfil das manutenções da 3.50 e anteriores),
    duração, o desfecho das etapas e a variação de espaço ("Otimizar · 1h 12min · 18 ok, 1 com ressalvas · espaço: +1,2
    GB"). A data vai no rótulo da linha (Show-WinForgeMaintenanceHistory). O que não foi registrado (o jeito de uma versão
    antiga, espaço sem medição) fica de fora.
    #>
    param (
        [Parameter(Mandatory)]
        $Entry
    )

    $parts = @()

    # Um jeito que esta versão não conhece fica de fora, em vez de virar outro.
    $label = Get-WinForgeMaintenanceProfileLabel -Id ([string](Get-WinForgeJsonValue -Object $Entry -Name "ProfileId" -Default ""))

    if ($label) {
        $parts += $label
    }

    if ([int]$Entry.DurationSeconds -gt 0) {
        $parts += Format-WinForgeDuration -Span ([TimeSpan]::FromSeconds($Entry.DurationSeconds))
    }

    $steps = @()

    if ([int]$Entry.Ok -gt 0) { $steps += "$($Entry.Ok) ok" }
    if ([int]$Entry.Warning -gt 0) { $steps += "$($Entry.Warning) com $(if ([int]$Entry.Warning -eq 1) { 'ressalva' } else { 'ressalvas' })" }
    if ([int]$Entry.Failed -gt 0) { $steps += $(if ([int]$Entry.Failed -eq 1) { "1 falhou" } else { "$($Entry.Failed) falharam" }) }
    if ([int]$Entry.Skipped -gt 0) { $steps += $(if ([int]$Entry.Skipped -eq 1) { "1 ignorada" } else { "$($Entry.Skipped) ignoradas" }) }

    if ($steps.Count -gt 0) { $parts += ($steps -join ", ") }

    if ($null -ne $Entry.FreeBefore -and $null -ne $Entry.FreeAfter) {
        $parts += "espaço: $(Format-WinForgeSignedBytes -Delta ([int64]$Entry.FreeAfter - [int64]$Entry.FreeBefore))"
    }

    return ($parts -join " · ")
}


function Get-WinForgeMaintenanceTrends {
    # Tendências das últimas manutenções (a lista vem da mais recente para a mais antiga, na ordem em que foram gravadas).
    # Cada linha tem Label, Text e Level (Info | Success | Warning). Com uma manutenção só não há tendência: as linhas
    # que comparam (primeira e última, média) dizem só o que ela registrou.
    param (
        [object[]]$History
    )

    $entries = @($History | Where-Object { $null -ne $_ })
    $rows = @()

    if ($entries.Count -eq 0) {
        return @()
    }

    $newest = $entries[0]
    $oldest = $entries[$entries.Count - 1]

    $rows += [PSCustomObject]@{
        Label = "Manutenções registradas"
        Text  = $(if ($entries.Count -eq 1) { "1 (em $(Format-WinForgeDateTime -When $newest.StartedAt))" } else { "$($entries.Count), de $(Format-WinForgeDateTime -When $oldest.StartedAt) a $(Format-WinForgeDateTime -When $newest.StartedAt)" })
        Level = "Info"
    }

    $durations = @($entries | Where-Object { $_.DurationSeconds -gt 0 } | ForEach-Object { [double]$_.DurationSeconds })

    if ($entries.Count -eq 1 -and $durations.Count -eq 1) {
        $rows += [PSCustomObject]@{ Label = "Duração"; Text = (Format-WinForgeDuration -Span ([TimeSpan]::FromSeconds($durations[0]))); Level = "Info" }
    }
    elseif ($durations.Count -gt 0) {
        $average = ($durations | Measure-Object -Average).Average
        $text = "média de $(Format-WinForgeDuration -Span ([TimeSpan]::FromSeconds($average)))"

        # Uma entrada antiga sem duração registrada não vira "a última levou 0s".
        if ([int]$newest.DurationSeconds -gt 0) {
            $text += "; a última levou $(Format-WinForgeDuration -Span ([TimeSpan]::FromSeconds($newest.DurationSeconds)))"
        }

        $rows += [PSCustomObject]@{ Label = "Duração"; Text = $text; Level = "Info" }
    }

    # O espaço livre do começo ao fim de cada manutenção: inclui o que a limpeza liberou, mas também o que as
    # atualizações, o ponto de restauração e o DISM ocuparam; por isso "variação", e não "liberado".
    $freed = @($entries | Where-Object { $null -ne $_.FreeBefore -and $null -ne $_.FreeAfter } | ForEach-Object { [int64]$_.FreeAfter - [int64]$_.FreeBefore })

    if ($freed.Count -gt 0) {
        $averageFreed = [int64][math]::Round(($freed | Measure-Object -Average).Average)
        $change = Format-WinForgeSignedBytes -Delta $averageFreed
        $text = $(if ($entries.Count -eq 1) { $change } else { "em média, $change por manutenção" })

        if ($freed.Count -lt $entries.Count) { $text += " (em $(Format-WinForgeCount -Count $freed.Count -One 'manutenção' -Many 'manutenções') com medição)" }

        $rows += [PSCustomObject]@{ Label = "Variação do espaço livre"; Text = $text; Level = "Info" }
    }

    $withFree = @($entries | Where-Object { $null -ne $_.FreeAfter })

    if ($withFree.Count -ge 2) {
        $first = $withFree[$withFree.Count - 1]
        $last = $withFree[0]
        $delta = [int64]$last.FreeAfter - [int64]$first.FreeAfter

        $rows += [PSCustomObject]@{
            Label = "Espaço livre, da primeira à última"
            Text  = "de $(Format-WinForgeBytes -Bytes ([int64]$first.FreeAfter)) para $(Format-WinForgeBytes -Bytes ([int64]$last.FreeAfter)) ($(Format-WinForgeSignedBytes -Delta $delta))"
            Level = $(if ($delta -le -(5GB)) { "Warning" } else { "Info" })
        }
    }

    $withStartupBefore = @($entries | Where-Object { $null -ne $_.StartupBefore })
    $withStartupAfter = @($entries | Where-Object { $null -ne $_.StartupAfter })

    if ($withStartupBefore.Count -gt 0 -and $withStartupAfter.Count -gt 0) {
        $from = $withStartupBefore[$withStartupBefore.Count - 1].StartupBefore
        $to = $withStartupAfter[0].StartupAfter

        $rows += [PSCustomObject]@{
            Label = "Programas que abrem com o Windows"
            Text  = $(if ($entries.Count -eq 1) { "de $from para $to" } else { "de $from na primeira para $to na última" })
            Level = "Info"
        }
    }

    # Etapas que deram ressalva ou falha em pelo menos duas das últimas cinco manutenções.
    $recent = @($entries | Select-Object -First 5)
    $problems = @{}

    foreach ($entry in $recent) {
        $seen = @{}

        foreach ($step in @($entry.Steps)) {
            if ($step.Kind -in @("Warning", "Failed") -and -not [string]::IsNullOrWhiteSpace($step.Etapa) -and -not $seen.ContainsKey($step.Etapa)) {
                $seen[$step.Etapa] = $true
                $problems[$step.Etapa] = 1 + $(if ($problems.ContainsKey($step.Etapa)) { [int]$problems[$step.Etapa] } else { 0 })
            }
        }
    }

    foreach ($name in @($problems.Keys | Sort-Object)) {
        if ([int]$problems[$name] -ge 2) {
            # O próximo passo: rodar a etapa sozinha mostra o motivo, sem o resto da manutenção em volta.
            $reference = Get-WinForgeMaintenanceStepReference -Name $name
            $next = $(if ($reference) { "; abra $reference e rode a etapa sozinha para ver o motivo" } else { "" })

            $rows += [PSCustomObject]@{
                Label = "Etapa com problema repetido"
                Text  = "${name}: ressalva ou falha em $($problems[$name]) das últimas $($recent.Count) manutenções$next"
                Level = "Warning"
            }
        }
    }

    return @($rows)
}


function Get-WinForgeMaintenanceStepReference {
    <#
    Onde rodar sozinha uma etapa automática da manutenção, como "Página > Item" (a janela faz disso um link), pelo nome
    da etapa (o que o histórico guarda). Uma tabela fixa, e não uma busca na navegação: a tela do histórico não pede
    Administrador e não pode depender da tabela inteira de ações (um teste confere que cada referência existe). Sem
    correspondência, "".
    #>
    param ([AllowEmptyString()][string]$Name)

    # Os nomes antigos (Verificação de segurança, Aplicar ajustes recomendados) continuam: o histórico guarda manutenções
    # da 3.50 e anteriores.
    $references = @{
        "Criar ponto de restauração"               = "Manutenção > Criar ponto de restauração"
        "Desinstalar programas"                    = "Programas > Desinstalar programas"
        "Remover aplicativos do Windows"           = "Programas > Remover aplicativos do Windows"
        "Revisar o que abre com o Windows"         = "Programas > Gerenciar inicialização"
        "Verificar vírus"                          = "Segurança > Verificar vírus"
        "Verificação de segurança"                 = "Segurança > Verificar vírus"
        "Atualizar o Windows"                      = "Atualizações > Instalar atualizações do Windows"
        "Detectar dispositivos e drivers"          = "Reparo > Detectar dispositivos e drivers"
        "Atualizar programas (winget)"             = "Atualizações > Atualizar programas (winget)"
        "Atualizar aplicativos da Microsoft Store" = "Atualizações > Atualizar aplicativos da Microsoft Store"
        "Remover atalhos quebrados"                = "Limpeza > Remover atalhos quebrados"
        "Restos de programas desinstalados"        = "Limpeza > Restos de programas desinstalados"
        "Limpar o registro"                        = "Limpeza > Limpar o registro"
        "Limpar componentes do Windows (WinSxS)"   = "Limpeza > Limpar componentes do Windows (WinSxS)"
        "Limpeza rápida"                           = "Limpeza > Limpeza rápida"
        "Reparar rede e DNS"                       = "Rede > Reparar rede e DNS"
        "Reparar o Windows (DISM + SFC)"           = "Reparo > Reparar o Windows (DISM + SFC)"
        "Verificar o sistema de arquivos (CHKDSK)" = "Reparo > Verificar o sistema de arquivos (CHKDSK)"
        "Otimizar a unidade do sistema"            = "Reparo > Otimizar a unidade do sistema"
        "Aplicar ajustes recomendados"             = "Ajustes do Windows > Aplicar ajustes recomendados"
    }

    if ([string]::IsNullOrWhiteSpace($Name) -or -not $references.ContainsKey($Name)) { return "" }

    return [string]$references[$Name]
}


function Write-WinForgeLastMaintenanceSteps {
    <#
    A primeira seção do histórico: a última manutenção e, uma por linha, as etapas que pediram atenção nela, com o
    motivo guardado e onde rodá-la sozinha de novo ("Página > Item"). É o que o cartão Última manutenção (do Início e da
    página) resume em "2 etapas com atenção". Sem registro, não escreve nada; registro ilegível é um aviso.
    #>
    $last = $null

    try {
        $last = Get-WinForgeLastMaintenance -Strict
    }
    catch {
        Write-WinForgeStatus -Type Warning -Notice -Message "Não foi possível ler a última manutenção agora: o arquivo está em uso ou sem permissão."
        return
    }

    if ($null -eq $last) { return }

    Write-WinForgeSection -Title "A última manutenção ($(Format-WinForgeDateTime -When ([datetime]$last.StartedAt)))"

    $attention = @(@($last.Results) | Where-Object { $null -ne $_ -and $null -ne $_.PSObject.Properties["Kind"] -and [string]$_.Kind -in @("Warning", "Failed") })

    if ($attention.Count -eq 0) {
        Write-WinForgeStatus -Type Info -Message "Nenhuma etapa pediu atenção."
        return
    }

    foreach ($step in $attention) {
        $status = [string](Get-WinForgeJsonValue -Object $step -Name "Status" -Default "")
        if ([string]::IsNullOrWhiteSpace($status)) { $status = $(if ([string]$step.Kind -eq "Failed") { "Falhou" } else { "Atenção" }) }

        $name = [string](Get-WinForgeJsonValue -Object $step -Name "Etapa" -Default "")
        if ([string]::IsNullOrWhiteSpace($name)) { $name = "Etapa sem nome" }

        $text = "$($name): $status"
        $reference = Get-WinForgeMaintenanceStepReference -Name $name
        if (-not [string]::IsNullOrEmpty($reference)) { $text += "; rode de novo em $reference" }

        # Aviso à vista (com o ícone), mas não um desfecho: só olhar o histórico não termina "com ressalvas".
        Write-WinForgeStatus -Type Warning -Notice -Message $text
    }
}


function Show-WinForgeMaintenanceHistory {
    # Uma tela de consulta: termina sem veredito (sem a faixa "Tudo certo"); o que pede atenção aparece com o ícone de
    # aviso, mas não vira desfecho. Primeiro a última manutenção, com o que pediu atenção nela (é por isso que a pessoa
    # chega aqui pelo cartão Última manutenção); depois a última verificação, as tendências e a lista.
    Enter-WinForgeAction -Title "Histórico de manutenções"

    try {
        Write-WinForgeLastMaintenanceSteps

        # O último Verificar o PC: o cartão Última manutenção conta os dois, e a pessoa que clicou nele precisa ver aqui
        # a verificação que ele citou. Uma data no futuro (relógio adiantado) não vira "agora há pouco".
        # Preferências presas por outro programa não viram "ainda não feita".
        $checkupText = "ainda não feita"

        try {
            $checkupAt = Get-WinForgeLastCheckup -Strict

            if ($null -ne $checkupAt -and $checkupAt -gt (Get-Date).AddDays(1)) {
                $checkupText = "registrada com data depois da de hoje no relógio do Windows"
            }
            elseif ($null -ne $checkupAt) {
                $checkupText = "$(Format-WinForgeRelativeTime -When $checkupAt) ($(Format-WinForgeDateTime -When $checkupAt))"
            }
        }
        catch {
            $checkupText = "não foi possível ler"
        }

        Write-WinForgeSection -Title "Verificar o PC"
        Write-WinForgeKeyValue -Label "Última verificação" -Value $checkupText -LabelWidth 34

        $read = Get-WinForgeMaintenanceHistory -Status
        $history = @($read.Entries)

        # Um histórico que existe, mas não abriu agora (preso por outro programa, sem permissão), não é "nenhuma manutenção".
        if ($read.Status -eq "Unreadable") {
            Write-WinForgeStatus -Type Error -Message "Não foi possível ler o histórico de manutenções agora: o arquivo está em uso ou sem permissão. Tente de novo em instantes."
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Failed -Title "Histórico de manutenções" -Detail "o arquivo do histórico está em uso ou sem permissão")
            return
        }

        if ($history.Count -eq 0) {
            Write-WinForgeStatus -Type Info -Message "Nenhuma manutenção registrada ainda. Ela aparece aqui depois de Manutenção > Otimizar; a execução mensal fica em Manutenção > Manutenção agendada."
            Exit-WinForgeAction
            return
        }

        Write-WinForgeSection -Title "Tendências"

        foreach ($row in @(Get-WinForgeMaintenanceTrends -History $history)) {
            if ($row.Level -eq "Warning") {
                # Aviso à vista (com o ícone), mas não um desfecho: só olhar o histórico não termina "com ressalvas".
                Write-WinForgeStatus -Type Warning -Notice -Message "$($row.Label): $($row.Text)"
            }
            else {
                Write-WinForgeKeyValue -Label $row.Label -Value $row.Text -LabelWidth 34
            }
        }

        Write-WinForgeSection -Title "Últimas manutenções"

        foreach ($entry in $history) {
            Write-WinForgeKeyValue -Label (Format-WinForgeDateTime -When $entry.StartedAt) -Value (Format-WinForgeHistoryLine -Entry $entry) -LabelWidth 18
        }

        Write-Host ""
        Write-WinForgeStatus -Type Info -Message "O WinForge guarda as últimas $(Get-WinForgeMaintenanceHistoryLimit) manutenções neste computador (pasta de dados do WinForge)."
    }
    catch {
        Write-WinForgeStatus -Type Error -Message "Não foi possível ler o histórico: $($_.Exception.Message)"
        Exit-WinForgeAction -Result (New-WinForgeResult -Kind Failed -Title "Histórico de manutenções" -Detail $_.Exception.Message)
        return
    }

    Exit-WinForgeAction
}


Export-ModuleMember -Function *
