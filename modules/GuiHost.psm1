# Ponte entre os módulos do WinForge (que usam Write-Host, Read-Host e programas nativos) e a interface gráfica.
# As ações rodam num runspace próprio com um "host" personalizado: toda a saída vai para uma fila lida pela janela
# e toda pergunta vira um pedido (botões ou caixa de texto) respondido pelo usuário. Nenhum console é aberto.

$script:GuiHostSource = @'
using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Globalization;
using System.Management.Automation;
using System.Management.Automation.Host;
using System.Security;
using System.Text;
using System.Threading;

namespace WinForge
{
    public class GuiOutputItem
    {
        public string Text;
        public ConsoleColor Color;
        public bool NewLine;
        public bool Clear;
    }

    public class GuiProgressInfo
    {
        public string Activity;
        public string Status;
        public int Percent;
        public bool Completed;
    }

    public class GuiOption
    {
        public string Key;
        public string Label;
        public string Description;
        public bool Accent;
        public bool Exit;
        public bool Selected;
    }

    public class GuiPromptRequest
    {
        public string Kind;
        public string Title;
        public string Label;
        public GuiOption[] Options;
        public string DefaultKey;
        public bool Secure;
        public string Answer;
        public string[] AnswerKeys;
        public bool Accepted;
        public int ChoiceIndex;
        public bool Cancelled;
        public readonly ManualResetEvent Done = new ManualResetEvent(false);
    }

    public class GuiRawUI : PSHostRawUserInterface
    {
        private readonly GuiHostUI ui;
        private ConsoleColor foreground = ConsoleColor.Gray;
        private ConsoleColor background = ConsoleColor.Black;
        private Coordinates cursor = new Coordinates(0, 0);
        private Coordinates windowPosition = new Coordinates(0, 0);
        private int cursorSize = 25;
        private string title = "WinForge";
        private volatile int columns = 100;

        public GuiRawUI(GuiHostUI owner)
        {
            ui = owner;
        }

        public int Columns
        {
            get { return columns; }
            set { columns = Math.Max(40, Math.Min(400, value)); }
        }

        public override ConsoleColor ForegroundColor { get { return foreground; } set { foreground = value; } }
        public override ConsoleColor BackgroundColor { get { return background; } set { background = value; } }
        public override Coordinates CursorPosition { get { return cursor; } set { cursor = value; } }
        public override Coordinates WindowPosition { get { return windowPosition; } set { windowPosition = value; } }
        public override int CursorSize { get { return cursorSize; } set { cursorSize = value; } }
        public override Size BufferSize { get { return new Size(columns, 5000); } set { } }
        public override Size WindowSize { get { return new Size(columns, 40); } set { } }
        public override Size MaxWindowSize { get { return new Size(columns, 40); } }
        public override Size MaxPhysicalWindowSize { get { return new Size(columns, 40); } }
        public override bool KeyAvailable { get { return false; } }
        public override string WindowTitle { get { return title; } set { title = value; } }

        public override KeyInfo ReadKey(ReadKeyOptions options)
        {
            GuiPromptRequest request = new GuiPromptRequest();
            request.Kind = "key";
            request.Label = "Pressione Continuar para prosseguir.";
            ui.Ask(request);
            return new KeyInfo(13, '\r', ControlKeyStates.NumLockOn, true);
        }

        public override void FlushInputBuffer() { }

        public override void SetBufferContents(Coordinates origin, BufferCell[,] contents) { }

        public override void SetBufferContents(Rectangle rectangle, BufferCell fill)
        {
            ui.EnqueueClear();
        }

        public override BufferCell[,] GetBufferContents(Rectangle rectangle)
        {
            return new BufferCell[0, 0];
        }

        public override void ScrollBufferContents(Rectangle source, Coordinates destination, Rectangle clip, BufferCell fill) { }
    }

    public class GuiHostUI : PSHostUserInterface
    {
        private readonly Queue<GuiOutputItem> queue = new Queue<GuiOutputItem>();
        private readonly object queueLock = new object();
        private readonly GuiRawUI raw;
        private readonly object promptLock = new object();
        private GuiPromptRequest pending;
        private volatile bool stopping;
        private volatile GuiProgressInfo progress;
        private int progressVersion;

        public GuiHostUI()
        {
            raw = new GuiRawUI(this);
        }

        public GuiRawUI Raw { get { return raw; } }
        public override PSHostRawUserInterface RawUI { get { return raw; } }

        public GuiProgressInfo Progress { get { return progress; } }
        public int ProgressVersion { get { return Thread.VolatileRead(ref progressVersion); } }

        public static string Sanitize(string value)
        {
            if (value == null) { return ""; }

            StringBuilder sb = new StringBuilder(value.Length);
            int i = 0;

            while (i < value.Length)
            {
                char c = value[i];

                if (c == '\u001b')
                {
                    i++;
                    if (i < value.Length && value[i] == '[')
                    {
                        // Sequência CSI (cores, cursor): termina em um caractere entre '@' e '~'.
                        i++;
                        while (i < value.Length && !(value[i] >= '@' && value[i] <= '~')) { i++; }
                        if (i < value.Length) { i++; }
                    }
                    else if (i < value.Length && value[i] == ']')
                    {
                        // Sequência OSC (título da janela, hiperlink): termina em BEL ou em ESC seguido de barra invertida.
                        i++;
                        while (i < value.Length && value[i] != '\a')
                        {
                            if (value[i] == '\u001b' && i + 1 < value.Length && value[i + 1] == '\\') { i++; break; }
                            i++;
                        }
                        if (i < value.Length) { i++; }
                    }
                    continue;
                }

                if (c == '\r')
                {
                    if (i + 1 < value.Length && value[i + 1] == '\n') { i++; continue; }
                    sb.Append('\n');
                    i++;
                    continue;
                }

                if (c == '\0' || c == '\a' || c == '\b') { i++; continue; }
                if (c < ' ' && c != '\n' && c != '\t') { i++; continue; }

                sb.Append(c);
                i++;
            }

            return sb.ToString();
        }

        private void Enqueue(string text, ConsoleColor color, bool newLine)
        {
            GuiOutputItem item = new GuiOutputItem();
            item.Text = Sanitize(text);
            item.Color = color;
            item.NewLine = newLine;
            lock (queueLock) { queue.Enqueue(item); }
        }

        public void EnqueueClear()
        {
            GuiOutputItem item = new GuiOutputItem();
            item.Text = "";
            item.Clear = true;
            lock (queueLock) { queue.Enqueue(item); }
        }

        public GuiOutputItem[] Drain(int max)
        {
            List<GuiOutputItem> items = new List<GuiOutputItem>();

            lock (queueLock)
            {
                while (items.Count < max && queue.Count > 0)
                {
                    items.Add(queue.Dequeue());
                }
            }

            return items.ToArray();
        }

        public void WriteInfoLine(string text, ConsoleColor color)
        {
            Enqueue(text, color, true);
        }

        public override void Write(string value) { Enqueue(value, raw.ForegroundColor, false); }
        public override void Write(ConsoleColor foregroundColor, ConsoleColor backgroundColor, string value) { Enqueue(value, foregroundColor, false); }
        public override void WriteLine() { Enqueue("", raw.ForegroundColor, true); }
        public override void WriteLine(string value) { Enqueue(value, raw.ForegroundColor, true); }
        public override void WriteLine(ConsoleColor foregroundColor, ConsoleColor backgroundColor, string value) { Enqueue(value, foregroundColor, true); }
        public override void WriteErrorLine(string value) { Enqueue(value, ConsoleColor.Red, true); }
        public override void WriteWarningLine(string value) { Enqueue("AVISO: " + value, ConsoleColor.Yellow, true); }
        public override void WriteVerboseLine(string value) { Enqueue("DETALHE: " + value, ConsoleColor.DarkGray, true); }
        public override void WriteDebugLine(string value) { Enqueue("DEPURAÇÃO: " + value, ConsoleColor.DarkGray, true); }

        public override void WriteProgress(long sourceId, ProgressRecord record)
        {
            GuiProgressInfo info = new GuiProgressInfo();
            info.Activity = record.Activity;
            info.Status = record.StatusDescription;
            info.Percent = record.PercentComplete;
            info.Completed = (record.RecordType == ProgressRecordType.Completed);
            progress = info;
            Interlocked.Increment(ref progressVersion);
        }

        // ----- Perguntas -----

        public GuiPromptRequest PendingPrompt
        {
            get { lock (promptLock) { return pending; } }
        }

        public void ResetStop()
        {
            stopping = false;
        }

        public void CancelPending()
        {
            stopping = true;

            lock (promptLock)
            {
                if (pending != null)
                {
                    pending.Cancelled = true;
                    pending.Done.Set();
                }
            }
        }

        public void Answer(GuiPromptRequest request, string answer, int choiceIndex)
        {
            request.Answer = answer;
            request.ChoiceIndex = choiceIndex;
            request.Done.Set();
        }

        public void AnswerMulti(GuiPromptRequest request, bool accepted, string[] keys)
        {
            request.Accepted = accepted;
            request.AnswerKeys = keys;
            request.Done.Set();
        }

        private static GuiOption FindOption(GuiOption[] options, string key)
        {
            if (options == null || key == null) { return null; }

            foreach (GuiOption option in options)
            {
                if (string.Equals(option.Key, key, StringComparison.OrdinalIgnoreCase)) { return option; }
            }

            return null;
        }

        public string AskChoice(string title, string message, GuiOption[] options, string defaultKey)
        {
            GuiPromptRequest request = new GuiPromptRequest();
            request.Kind = "choice";
            request.Title = title;
            request.Label = message;
            request.Options = options;
            request.DefaultKey = defaultKey;
            Ask(request);

            GuiOption chosen = FindOption(options, request.Answer);
            if (chosen == null) { chosen = FindOption(options, defaultKey); }
            if (chosen == null && options != null && options.Length > 0) { chosen = options[0]; }
            if (chosen == null) { return ""; }

            Enqueue(message + ": ", ConsoleColor.Cyan, false);
            Enqueue(chosen.Label, ConsoleColor.White, true);

            return chosen.Key;
        }

        public string[] AskMulti(string title, string message, GuiOption[] options)
        {
            GuiPromptRequest request = new GuiPromptRequest();
            request.Kind = "multi";
            request.Title = title;
            request.Label = message;
            request.Options = options;
            Ask(request);

            Enqueue(message + ": ", ConsoleColor.Cyan, false);

            if (!request.Accepted)
            {
                Enqueue("cancelado", ConsoleColor.White, true);
                return null;
            }

            string[] keys = request.AnswerKeys == null ? new string[0] : request.AnswerKeys;
            List<string> labels = new List<string>();

            foreach (string key in keys)
            {
                GuiOption found = FindOption(options, key);
                labels.Add(found == null ? key : found.Label);
            }

            Enqueue(keys.Length == 0 ? "nenhum item" : string.Join(", ", labels.ToArray()), ConsoleColor.White, true);

            return keys;
        }

        public GuiPromptRequest Ask(GuiPromptRequest request)
        {
            if (stopping) { throw new PipelineStoppedException(); }

            lock (promptLock) { pending = request; }

            request.Done.WaitOne();

            lock (promptLock)
            {
                if (object.ReferenceEquals(pending, request)) { pending = null; }
            }

            if (request.Cancelled) { throw new PipelineStoppedException(); }

            return request;
        }

        private string AskLine(string label, bool secure)
        {
            GuiPromptRequest request = new GuiPromptRequest();
            request.Kind = "line";
            request.Label = label;
            request.Secure = secure;
            Ask(request);

            string shown = secure ? "********" : request.Answer;
            Enqueue(label + ": ", ConsoleColor.Cyan, false);
            Enqueue(shown, ConsoleColor.White, true);

            return request.Answer == null ? "" : request.Answer;
        }

        public override string ReadLine()
        {
            return AskLine("Entrada", false);
        }

        public override SecureString ReadLineAsSecureString()
        {
            string text = AskLine("Entrada protegida", true);
            SecureString secure = new SecureString();
            foreach (char c in text) { secure.AppendChar(c); }
            secure.MakeReadOnly();
            return secure;
        }

        public override Dictionary<string, PSObject> Prompt(string caption, string message, Collection<FieldDescription> descriptions)
        {
            if (!string.IsNullOrEmpty(caption)) { Enqueue(caption, ConsoleColor.Cyan, true); }
            if (!string.IsNullOrEmpty(message)) { Enqueue(message, ConsoleColor.Gray, true); }

            Dictionary<string, PSObject> result = new Dictionary<string, PSObject>();

            foreach (FieldDescription field in descriptions)
            {
                string label = string.IsNullOrEmpty(field.Label) ? field.Name : field.Label;
                bool secure = field.ParameterTypeName != null && field.ParameterTypeName.IndexOf("SecureString", StringComparison.OrdinalIgnoreCase) >= 0;
                string text = AskLine(label, secure);

                if (secure)
                {
                    SecureString value = new SecureString();
                    foreach (char c in text) { value.AppendChar(c); }
                    value.MakeReadOnly();
                    result[field.Name] = PSObject.AsPSObject(value);
                }
                else
                {
                    result[field.Name] = PSObject.AsPSObject(text);
                }
            }

            return result;
        }

        public override int PromptForChoice(string caption, string message, Collection<ChoiceDescription> choices, int defaultChoice)
        {
            GuiOption[] options = new GuiOption[choices.Count];

            for (int i = 0; i < choices.Count; i++)
            {
                GuiOption option = new GuiOption();
                option.Key = i.ToString();
                option.Label = choices[i].Label.Replace("&", "");
                option.Description = choices[i].HelpMessage;
                option.Accent = (i == defaultChoice);
                options[i] = option;
            }

            if (!string.IsNullOrEmpty(caption)) { Enqueue(caption, ConsoleColor.Cyan, true); }

            string text = string.IsNullOrEmpty(message) ? "Escolha uma opção" : message;
            string key = AskChoice("", text, options, defaultChoice >= 0 ? defaultChoice.ToString() : null);
            int index;

            if (!int.TryParse(key, out index)) { index = defaultChoice >= 0 ? defaultChoice : 0; }

            return index;
        }

        public override PSCredential PromptForCredential(string caption, string message, string userName, string targetName)
        {
            throw new NotSupportedException("Credenciais não são solicitadas pela interface do WinForge.");
        }

        public override PSCredential PromptForCredential(string caption, string message, string userName, string targetName, PSCredentialTypes allowedCredentialTypes, PSCredentialUIOptions options)
        {
            throw new NotSupportedException("Credenciais não são solicitadas pela interface do WinForge.");
        }
    }

    public class GuiHost : PSHost
    {
        private readonly GuiHostUI ui = new GuiHostUI();
        private readonly Guid id = Guid.NewGuid();

        public GuiHostUI GuiUI { get { return ui; } }
        public bool ExitRequested;

        public override string Name { get { return "WinForgeGuiHost"; } }
        public override Version Version { get { return new Version(2, 2); } }
        public override Guid InstanceId { get { return id; } }
        public override PSHostUserInterface UI { get { return ui; } }
        public override CultureInfo CurrentCulture { get { return CultureInfo.CurrentCulture; } }
        public override CultureInfo CurrentUICulture { get { return CultureInfo.CurrentUICulture; } }

        public void ClearScreen() { ui.EnqueueClear(); }

        public override void SetShouldExit(int exitCode) { ExitRequested = true; }
        public override void EnterNestedPrompt() { }
        public override void ExitNestedPrompt() { }
        public override void NotifyBeginApplication() { }
        public override void NotifyEndApplication() { }
    }
}
'@

# Executado dentro do runspace da ação (escopo global). As variáveis WinForgeGui* são definidas antes de cada execução.
$script:GuiRunnerScript = @'
$ErrorActionPreference = "Continue"

if (-not $global:WinForgeGuiReady) {
    $global:WinForgeGuiMode = $true

    function global:Clear-Host { $global:WinForgeGuiHost.ClearScreen() }

    # O Write-Host padrão chega ao host depois da saída de programas nativos; esta versão grava na fila na hora,
    # preservando a ordem das mensagens (por exemplo, "Executando..." antes da saída do DISM).
    function global:Write-Host {
        [CmdletBinding()]
        param (
            [Parameter(Position = 0, ValueFromRemainingArguments = $true, ValueFromPipeline = $true)]
            [object[]]$Object,
            [switch]$NoNewline,
            [object]$Separator = " ",
            [System.ConsoleColor]$ForegroundColor,
            [System.ConsoleColor]$BackgroundColor
        )

        process {
            $text = ""

            if ($null -ne $Object) {
                $text = (@($Object | ForEach-Object { [string]$_ }) -join [string]$Separator)
            }

            $ui = $global:WinForgeGuiHost.GuiUI

            if ($PSBoundParameters.ContainsKey("ForegroundColor")) {
                $color = $ForegroundColor
            }
            else {
                $color = $ui.Raw.ForegroundColor
            }

            if ($NoNewline) {
                $ui.Write($color, [System.ConsoleColor]::Black, $text)
            }
            else {
                $ui.WriteLine($color, [System.ConsoleColor]::Black, $text)
            }
        }
    }

    function global:Write-Warning {
        [CmdletBinding()]
        param ([Parameter(Position = 0, Mandatory = $true)][AllowEmptyString()][string]$Message)

        $global:WinForgeGuiHost.GuiUI.WriteWarningLine($Message)
    }

    # Programas nativos são executados por Invoke-WinForgeNative / Invoke-WinForgeCapture (Core), que capturam
    # stdout e stderr; não há mais funções de atalho para winget, dism e outros neste runspace.
    foreach ($name in $WinForgeGuiModules) {
        $modulePath = Join-Path $WinForgeGuiModuleRoot "$name.psm1"

        try {
            Import-Module -Name $modulePath -Force -DisableNameChecking -Global -ErrorAction Stop
        }
        catch {
            # Caminhos com colchetes são lidos como curinga pelo Import-Module; escapar resolve.
            Import-Module -Name ([System.Management.Automation.WildcardPattern]::Escape($modulePath)) -Force -DisableNameChecking -Global -ErrorAction Stop
        }
    }

    Initialize-WinForgeEnvironment

    try { [void](Start-WinForgeLogging) } catch { }

    $global:WinForgeGuiReady = $true
}

try {
    # O comando vem da tabela de navegação do próprio WinForge; vira um scriptblock para aceitar parâmetros.
    $commandBlock = [scriptblock]::Create($WinForgeGuiCommand)
    & $commandBlock | Out-Default
}
catch {
    Write-Host ""
    Write-Host ("Falha: " + $_.Exception.Message) -ForegroundColor Red
}
'@


function Initialize-WinForgeGuiHost {
    if ('WinForge.GuiHost' -as [type]) {
        return
    }

    # Windows PowerShell 5.1 já referencia System.Management.Automation por padrão; no PowerShell 7 informar
    # -ReferencedAssemblies substituiria as referências padrão, então nada extra é passado.
    if ($PSVersionTable.PSEdition -eq "Core") {
        Add-Type -TypeDefinition $script:GuiHostSource -ErrorAction Stop
    }
    else {
        Add-Type -TypeDefinition $script:GuiHostSource -ReferencedAssemblies ([System.Management.Automation.PSObject].Assembly.Location) -ErrorAction Stop
    }
}


function New-WinForgeGuiSession {
    param (
        [Parameter(Mandatory)]
        [string]$ModuleRoot,

        # Módulos que o runspace das ações importa (a lista vem de modules\Modules.psd1).
        [Parameter(Mandatory)]
        [string[]]$Modules
    )

    Initialize-WinForgeGuiHost

    $guiHost = New-Object WinForge.GuiHost
    $runspace = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace($guiHost)
    $runspace.Open()

    # O $Host automático é um invólucro interno; o objeto real fica acessível por esta variável global.
    $runspace.SessionStateProxy.SetVariable("WinForgeGuiHost", $guiHost)

    return [PSCustomObject]@{
        Host        = $guiHost
        Runspace    = $runspace
        ModuleRoot  = $ModuleRoot
        Modules     = $Modules
        Ps          = $null
        Async       = $null
        Status      = "Idle"
        ErrorIndex  = 0
        Command     = ""
    }
}


function Start-WinForgeGuiCommand {
    param (
        [Parameter(Mandatory)]
        $Session,

        [Parameter(Mandatory)]
        [string]$Command,

        [int]$Columns = 100
    )

    if ($Session.Status -eq "Running") {
        return $false
    }

    $Session.Host.GuiUI.ResetStop()
    $Session.Host.GuiUI.Raw.Columns = $Columns

    $proxy = $Session.Runspace.SessionStateProxy
    $proxy.SetVariable("WinForgeGuiCommand", $Command)
    $proxy.SetVariable("WinForgeGuiModuleRoot", $Session.ModuleRoot)
    $proxy.SetVariable("WinForgeGuiModules", $Session.Modules)

    $ps = [System.Management.Automation.PowerShell]::Create()
    $ps.Runspace = $Session.Runspace
    [void]$ps.AddScript($script:GuiRunnerScript, $false)

    $Session.Ps = $ps
    $Session.ErrorIndex = 0
    $Session.Command = $Command
    $Session.Async = $ps.BeginInvoke()
    $Session.Status = "Running"

    return $true
}


function Stop-WinForgeChildTools {
    <#
    Depois que uma ação é interrompida, ferramentas nativas que ela iniciou (DISM, SFC, winget...) podem continuar
    rodando sem ninguém para mostrar a saída. Encerra apenas os filhos diretos deste processo que estão na lista.
    #>
    $toolNames = @("dism.exe", "dismhost.exe", "sfc.exe", "chkdsk.exe", "defrag.exe", "winget.exe", "powercfg.exe", "pnputil.exe", "ipconfig.exe", "netsh.exe")

    try {
        $children = @(
            Get-CimInstance -ClassName Win32_Process -Filter "ParentProcessId = $PID" -ErrorAction Stop |
                Where-Object { $toolNames -contains ([string]$_.Name).ToLowerInvariant() }
        )

        foreach ($child in $children) {
            Stop-Process -Id $child.ProcessId -Force -ErrorAction SilentlyContinue
        }

        return $children.Count
    }
    catch {
        return 0
    }
}


function Stop-WinForgeGuiCommand {
    param (
        [Parameter(Mandatory)]
        $Session
    )

    if ($Session.Status -ne "Running" -or $null -eq $Session.Ps) {
        return
    }

    $Session.Host.GuiUI.CancelPending()
    [void]$Session.Ps.BeginStop($null, $null)
}


function Read-WinForgeGuiUpdate {
    param (
        [Parameter(Mandatory)]
        $Session,

        [int]$MaxItems = 1500
    )

    $ui = $Session.Host.GuiUI

    if ($Session.Status -eq "Running" -and $null -ne $Session.Ps) {
        $ps = $Session.Ps

        # Erros não terminantes ficam no fluxo de erros do pipeline; são repassados para a tela (avisos já passam pelo host).
        while ($Session.ErrorIndex -lt $ps.Streams.Error.Count) {
            $record = $ps.Streams.Error[$Session.ErrorIndex]
            $Session.ErrorIndex++
            $ui.WriteInfoLine(("Erro: " + $record.ToString()), [ConsoleColor]::Red)
        }

        if ($Session.Async.IsCompleted) {
            $finalState = "Completed"
            $state = $ps.InvocationStateInfo.State

            try {
                $ps.EndInvoke($Session.Async)
            }
            catch {
                if ($state -ne "Stopped") {
                    $finalState = "Failed"
                    $ui.WriteInfoLine(("Falha: " + $_.Exception.Message), [ConsoleColor]::Red)
                }
            }

            if ($state -eq "Stopped") {
                $finalState = "Stopped"

                if ((Stop-WinForgeChildTools) -gt 0) {
                    $ui.WriteInfoLine("Ferramentas que ainda estavam rodando foram encerradas.", [ConsoleColor]::DarkGray)
                }
            }
            elseif ($state -eq "Failed" -and $finalState -ne "Failed") {
                $finalState = "Failed"

                if ($null -ne $ps.InvocationStateInfo.Reason) {
                    $ui.WriteInfoLine(("Falha: " + $ps.InvocationStateInfo.Reason.Message), [ConsoleColor]::Red)
                }
            }

            $ps.Dispose()
            $Session.Ps = $null
            $Session.Async = $null
            $Session.Status = $finalState
        }
    }

    # A fila só é lida depois do estado: se a ação terminou, nada mais será enfileirado.
    $items = $ui.Drain($MaxItems)

    return [PSCustomObject]@{
        Items           = $items
        Status          = $Session.Status
        Prompt          = $ui.PendingPrompt
        Progress        = $ui.Progress
        ProgressVersion = $ui.ProgressVersion
    }
}


function Complete-WinForgeGuiPrompt {
    param (
        [Parameter(Mandatory)]
        $Session,

        [Parameter(Mandatory)]
        $Prompt,

        [string]$Answer = "",

        [int]$ChoiceIndex = -1,

        [string[]]$Keys = @(),

        [switch]$Accepted
    )

    if ($Prompt.Kind -eq "multi") {
        $Session.Host.GuiUI.AnswerMulti($Prompt, [bool]$Accepted, [string[]]@($Keys))
        return
    }

    $Session.Host.GuiUI.Answer($Prompt, $Answer, $ChoiceIndex)
}


function Close-WinForgeGuiSession {
    param (
        [Parameter(Mandatory)]
        $Session
    )

    try {
        if ($Session.Status -eq "Running") {
            $Session.Host.GuiUI.CancelPending()

            if ($null -ne $Session.Ps) {
                [void]$Session.Ps.BeginStop($null, $null)
            }
        }

        elseif ($Session.Status -ne "Idle" -or $null -ne $Session.Runspace) {
            # Fecha o log da sessão (Start-Transcript) antes de descartar o runspace.
            $closer = [System.Management.Automation.PowerShell]::Create()
            $closer.Runspace = $Session.Runspace
            [void]$closer.AddScript('if ($global:WinForgeGuiReady) { try { Stop-WinForgeLogging } catch { } }', $false)
            [void]$closer.Invoke()
            $closer.Dispose()
        }

        $Session.Runspace.Dispose()
    }
    catch {
        # Encerramento é best-effort.
    }
}


function Test-WinForgeProgressLine {
    <#
    Linhas que representam apenas o avanço de uma barra (winget, DISM, SFC). A janela substitui a linha anterior
    em vez de empilhar centenas de atualizações.
    #>
    param (
        [AllowEmptyString()]
        [string]$Text
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $false
    }

    $blocks = "[" + [char]0x2580 + "-" + [char]0x259F + "]"

    if ($Text -match $blocks) { return $true }
    if ($Text -match '^\s*\[[=\s\-#>]*[0-9.,]+\s*%[=\s\-#>]*\]\s*$') { return $true }
    if ($Text -match '^\s*[0-9]{1,3}([.,][0-9]+)?\s*%\s*$') { return $true }
    if ($Text -match '(?i)\b[0-9]{1,3}\s*%\s*(complete|conclu)') { return $true }

    return $false
}


function Test-WinForgeSpinnerLine {
    param (
        [AllowEmptyString()]
        [string]$Text
    )

    return ($Text -match '^\s*[-\\|/]\s*$')
}


function Get-WinForgePromptPlan {
    <#
    Decide como a janela apresenta uma pergunta: botões prontos (Sim/Não, Continuar, opções), lista de marcação
    (seleção múltipla) ou caixa de texto.
    #>
    param (
        [Parameter(Mandatory)]
        $Prompt
    )

    $buttons = @()
    $showText = $false

    switch ($Prompt.Kind) {
        "key" {
            $buttons += [PSCustomObject]@{ Text = "Continuar"; Answer = ""; Index = -1; Accent = $true; Description = ""; Exit = $false }
        }

        "choice" {
            $index = 0

            foreach ($option in @($Prompt.Options)) {
                $isAccent = [bool]$option.Accent

                if (-not $isAccent -and -not [string]::IsNullOrEmpty($Prompt.DefaultKey) -and $option.Key -ieq $Prompt.DefaultKey) {
                    $isAccent = $true
                }

                $buttons += [PSCustomObject]@{
                    Text        = [string]$option.Label
                    Answer      = [string]$option.Key
                    Index       = $index
                    Accent      = $isAccent
                    Description = [string]$option.Description
                    Exit        = [bool]$option.Exit
                }

                $index++
            }
        }

        "multi" {
            # Os botões (Confirmar, Marcar todos...) são montados pela janela; aqui só vai a lista.
        }

        default {
            $label = [string]$Prompt.Label

            if ($label -match '(?i)[\(\[]\s*S\s*/\s*N\s*[\)\]]') {
                $buttons += [PSCustomObject]@{ Text = "Sim"; Answer = "S"; Index = -1; Accent = $true; Description = ""; Exit = $false }
                $buttons += [PSCustomObject]@{ Text = "Não"; Answer = "N"; Index = -1; Accent = $false; Description = ""; Exit = $false }
            }
            else {
                $showText = $true

                if ($label -match '(?i)\bENTER\b' -and $label -match '(?i)pressione|conclua') {
                    $buttons += [PSCustomObject]@{ Text = "Continuar"; Answer = ""; Index = -1; Accent = $true; Description = ""; Exit = $false }
                }

                if ($label -match '(?i)\bP\s*=\s*pular') {
                    $buttons += [PSCustomObject]@{ Text = "Pular as etapas restantes"; Answer = "P"; Index = -1; Accent = $false; Description = ""; Exit = $false }
                }
            }
        }
    }

    return [PSCustomObject]@{
        Kind     = [string]$Prompt.Kind
        ShowText = $showText
        Buttons  = @($buttons)
        Options  = @($Prompt.Options)
        Label    = [string]$Prompt.Label
    }
}


Export-ModuleMember -Function *
