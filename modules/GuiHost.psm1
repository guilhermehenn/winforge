# Ponte entre os módulos do WinForge (que usam Write-Host, Read-Host e programas nativos) e a interface gráfica.
# As ações rodam num runspace próprio com um "host" personalizado: toda a saída vai para uma fila lida pela janela
# e toda pergunta vira um pedido (botões ou caixa de texto) respondido pelo usuário. Nenhum console é aberto.

$script:GuiHostSource = @'
using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Globalization;
using System.IO;
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
        public bool NoSelectAll;
        // Os botões de uma lista de marcação ("Desinstalar", "Pular"); vazios, a janela usa Confirmar e Cancelar.
        public string ConfirmLabel;
        public string CancelLabel;
        // Uma revisão (a lista vem com o estado de agora marcado): o botão conta as mudanças e desmarcar tudo é resposta.
        public bool AllowNone;
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

        // O log da sessão: cada linha que as ações escrevem, com a hora (o transcript do PowerShell não vê o que passa
        // por este host). Aberto por Start-WinForgeLogging, fechado por Stop-WinForgeLogging ou ao fechar a janela.
        private readonly object logLock = new object();
        private StreamWriter log;
        private bool logLineOpen;

        public GuiHostUI()
        {
            raw = new GuiRawUI(this);
        }

        public GuiRawUI Raw { get { return raw; } }
        public override PSHostRawUserInterface RawUI { get { return raw; } }

        public GuiProgressInfo Progress { get { return progress; } }
        public int ProgressVersion { get { return Volatile.Read(ref progressVersion); } }

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
            WriteLog(item.Text, newLine);
        }

        public bool OpenLog(string path, string header)
        {
            lock (logLock)
            {
                if (log != null) { return true; }

                try
                {
                    log = new StreamWriter(path, true, new UTF8Encoding(true));
                    if (!string.IsNullOrEmpty(header)) { log.WriteLine(header); log.WriteLine(); }
                    log.Flush();
                    logLineOpen = false;
                    return true;
                }
                catch
                {
                    log = null;
                    return false;
                }
            }
        }

        public void CloseLog()
        {
            lock (logLock)
            {
                if (log == null) { return; }

                try
                {
                    if (logLineOpen) { log.WriteLine(); }
                    log.Dispose();
                }
                catch
                {
                    // O disco pode ter sumido (pendrive); o log é um complemento.
                }

                log = null;
                logLineOpen = false;
            }
        }

        private void WriteLog(string text, bool newLine)
        {
            lock (logLock)
            {
                if (log == null) { return; }

                try
                {
                    if (!logLineOpen && !string.IsNullOrEmpty(text))
                    {
                        log.Write(DateTime.Now.ToString("HH:mm:ss ", CultureInfo.InvariantCulture));
                        logLineOpen = true;
                    }

                    log.Write(text);

                    if (newLine)
                    {
                        log.WriteLine();
                        logLineOpen = false;
                        log.Flush();
                    }
                }
                catch
                {
                    // Idem.
                }
            }
        }

        public void EnqueueClear()
        {
            GuiOutputItem item = new GuiOutputItem();
            item.Text = "";
            item.Clear = true;
            lock (queueLock) { queue.Enqueue(item); }
        }

        // O que ainda está na fila (a janela só dá a ação por terminada quando ela esvazia).
        public int PendingCount
        {
            get { lock (queueLock) { return queue.Count; } }
        }

        // Uma ação nova começa sem a saída nem o progresso da anterior.
        public void ClearQueue()
        {
            lock (queueLock) { queue.Clear(); }
        }

        public void ResetProgress()
        {
            progress = null;
            Interlocked.Increment(ref progressVersion);
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
            return AskMulti(title, message, options, false);
        }

        // noSelectAll: a lista vem sem o "Marcar todos" (desinstalar, remover aplicativos, recursos do Windows).
        public string[] AskMulti(string title, string message, GuiOption[] options, bool noSelectAll)
        {
            return AskMulti(title, message, options, noSelectAll, null, null, false);
        }

        // confirmLabel e cancelLabel: o que os botões dizem ("Desinstalar", "Pular"); nulos, Confirmar e Cancelar.
        // allowNone: uma revisão, em que desmarcar tudo também é uma resposta (a lista volta vazia, e não nula).
        public string[] AskMulti(string title, string message, GuiOption[] options, bool noSelectAll, string confirmLabel, string cancelLabel, bool allowNone)
        {
            GuiPromptRequest request = new GuiPromptRequest();
            request.Kind = "multi";
            request.Title = title;
            request.Label = message;
            request.Options = options;
            request.NoSelectAll = noSelectAll;
            request.ConfirmLabel = confirmLabel;
            request.CancelLabel = cancelLabel;
            request.AllowNone = allowNone;
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
            // O "parar" é conferido dentro da trava: se o CancelPending rodasse entre a conferência e o registro da
            // pergunta, ele não a veria, e a ação ficaria esperando uma resposta que nunca vem.
            lock (promptLock)
            {
                if (stopping) { throw new PipelineStoppedException(); }
                pending = request;
            }

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

try { Reset-WinForgeOutcome } catch { }

try {
    # O comando vem da tabela de navegação do próprio WinForge; vira um scriptblock para aceitar parâmetros.
    $commandBlock = [scriptblock]::Create($WinForgeGuiCommand)
    & $commandBlock | Out-Default
}
catch {
    $failure = $_.Exception.Message
    try { $failure = ConvertTo-WinForgeReadableError -Text $failure } catch { }

    Write-Host ""
    Write-Host ("Falha: " + $failure) -ForegroundColor Red

    try { Set-WinForgeOutcome -Kind Failed -Detail $failure } catch { }
}

# O desfecho (OK, ressalvas, falha...) é a única saída do pipeline; a janela o lê quando a ação termina.
try { Get-WinForgeOutcome } catch { }
'@


# ---------------------------------------------------------------------------
# Uma janela só por usuário
# ---------------------------------------------------------------------------
# Abrir o WinForge de novo (pelo atalho, pelo .cmd ou pelo monitor na bandeja) não abre uma segunda janela, que rodaria
# ações ao mesmo tempo que a primeira: o pedido (abrir, ou abrir já rodando uma ação) vai para a janela aberta, que
# confere a cada meio segundo se chegou algum.

$script:WinForgeWindowLock = $null


function Get-WinForgeWindowLockName {
    # Por sessão do Windows e por conta: a janela de outro Administrador (outra pasta de dados) não segura esta.
    try {
        return "Local\WinForge.Window.$([System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value)"
    }
    catch {
        return "Local\WinForge.Window"
    }
}


function Enter-WinForgeWindowLock {
    <#
    $true quando esta é a janela do WinForge (a trava ficou com ela até o processo terminar) ou quando não deu para saber
    (melhor abrir do que não abrir nada); $false quando já há uma janela aberta. -WaitMilliseconds: a reabertura como
    Administrador espera a janela anterior fechar.
    #>
    param ([int]$WaitMilliseconds = 0)

    # A janela elevada e a não elevada do mesmo usuário precisam enxergar a mesma trava (Open-WinForgeNamedMutex).
    $mutex = Open-WinForgeNamedMutex -Name (Get-WinForgeWindowLockName)

    if ($null -eq $mutex) { return $true }

    $owned = $false

    try { $owned = $mutex.WaitOne($WaitMilliseconds) } catch [System.Threading.AbandonedMutexException] { $owned = $true }

    if ($owned) {
        $script:WinForgeWindowLock = $mutex
        return $true
    }

    $mutex.Dispose()
    return $false
}


function Get-WinForgeWindowRequestPath {
    return (Join-Path (Get-WinForgeDataPath) "window-request.json")
}


function Send-WinForgeWindowRequest {
    # Deixa o pedido para a janela aberta: Action = Id da navegação a rodar ("" = só trazer a janela para a frente).
    param ([string]$Action = "")

    if ($Action -notmatch '^[a-z0-9][a-z0-9.-]*$') { $Action = "" }

    try {
        Write-WinForgeStateJson -Path (Get-WinForgeWindowRequestPath) -InputObject ([ordered]@{ Action = $Action; At = (Get-Date).ToString("o", [System.Globalization.CultureInfo]::InvariantCulture) })
        return $true
    }
    catch {
        return $false
    }
}


function Receive-WinForgeWindowRequest {
    # O pedido que outra abertura deixou (e que é apagado ao ser lido), ou $null. Um pedido de mais de um minuto (de uma
    # janela que estava travada) é descartado: rodar uma ação tanto tempo depois do clique surpreenderia a pessoa.
    $path = Get-WinForgeWindowRequestPath

    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $null }

    $document = $null

    try {
        $document = (Read-WinForgeStateFile -Path $path).Document
    }
    finally {
        Get-ChildItem -LiteralPath (Split-Path -Parent $path) -Filter "window-request.json*" -Force -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
    }

    if ($null -eq $document) { return [PSCustomObject]@{ Action = "" } }

    $at = [datetime]::MinValue
    $atText = [string](Get-WinForgeJsonValue -Object $document -Name "At" -Default "")

    if ([datetime]::TryParse($atText, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind, [ref]$at) -and ((Get-Date) - $at).TotalSeconds -gt 60) {
        return [PSCustomObject]@{ Action = "" }
    }

    $action = [string](Get-WinForgeJsonValue -Object $document -Name "Action" -Default "")
    if ($action -notmatch '^[a-z0-9][a-z0-9.-]*$') { $action = "" }

    return [PSCustomObject]@{ Action = $action }
}


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
        Outcome     = $null
        StartedAt   = $null
        EndedAt     = $null
        StopAskedAt = $null
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
    $Session.Host.GuiUI.ClearQueue()
    $Session.Host.GuiUI.ResetProgress()
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
    $Session.Outcome = $null
    $Session.StartedAt = Get-Date
    $Session.EndedAt = $null
    $Session.StopAskedAt = $null
    $Session.Async = $ps.BeginInvoke()
    $Session.Status = "Running"

    return $true
}


function Get-WinForgeDescendantProcesses {
    <#
    Os processos que descendem deste WinForge (os filhos e os filhos deles: o DISM e o DismHost que ele abre, o winget e o
    instalador do programa, o atualizador de um navegador), numa leitura só do Win32_Process. Fica de fora o conhost: o
    console do próprio WinForge mora num deles, e ele termina sozinho com quem o usa. Fica de fora também o MpCmdRun: depois
    do Parar, é ele que pede ao Windows Defender para cancelar a verificação (fechar a janela nessa hora não pode matar o
    pedido e deixar a verificação rodando por horas). Um "filho" mais velho que o pai é
    um número de processo reaproveitado, e não entra. Devolve as linhas do Win32_Process (ProcessId, Name, CreationDate).
    #>
    param ([int]$RootId = $PID)

    try {
        $all = @(Get-CimInstance -ClassName Win32_Process -OperationTimeoutSec 10 -ErrorAction Stop)
    }
    catch {
        return @()
    }

    $byParent = @{}
    $started = @{}

    foreach ($row in $all) {
        $parent = [int]$row.ParentProcessId
        if (-not $byParent.ContainsKey($parent)) { $byParent[$parent] = New-Object System.Collections.ArrayList }
        [void]$byParent[$parent].Add($row)
        $started[[int]$row.ProcessId] = $row.CreationDate
    }

    $found = New-Object System.Collections.ArrayList
    $seen = New-Object 'System.Collections.Generic.HashSet[int]'
    $queue = New-Object 'System.Collections.Generic.Queue[int]'
    [void]$seen.Add($RootId)
    $queue.Enqueue($RootId)

    while ($queue.Count -gt 0) {
        $parentId = $queue.Dequeue()
        if (-not $byParent.ContainsKey($parentId)) { continue }

        foreach ($row in $byParent[$parentId]) {
            $id = [int]$row.ProcessId
            if (-not $seen.Add($id)) { continue }

            $parentStart = $started[$parentId]
            if ($null -ne $parentStart -and $null -ne $row.CreationDate -and [datetime]$row.CreationDate -lt [datetime]$parentStart) { continue }
            if (([string]$row.Name) -in @("conhost.exe", "MpCmdRun.exe")) { continue }

            [void]$found.Add($row)
            $queue.Enqueue($id)
        }
    }

    return @($found)
}


function Stop-WinForgeChildTools {
    <#
    Quando uma ação é interrompida, o que ela iniciou não pode continuar rodando escondido: encerra a árvore de processos
    que descende deste WinForge (Get-WinForgeDescendantProcesses), dos mais novos para os mais velhos, ou a lista dada
    (Processes, lida antes de a ação parar: depois, o DismHost já não tem o DISM como pai). Um processo só é encerrado se
    ainda for o mesmo (a hora de início confere). O serviço que instala as atualizações do Windows não é filho do
    WinForge e termina sozinho o que estiver fazendo. Devolve quantos foram encerrados.
    #>
    param ([object[]]$Processes = $null)

    # Sempre uma lista (sob Set-StrictMode, uma lista vazia que vira $null não tem Count).
    $targets = @(if ($null -ne $Processes) { $Processes } else { Get-WinForgeDescendantProcesses })
    $stopped = 0

    for ($i = $targets.Count - 1; $i -ge 0; $i--) {
        $row = $targets[$i]

        try {
            $process = Get-Process -Id ([int]$row.ProcessId) -ErrorAction Stop

            if ($null -ne $row.CreationDate -and [Math]::Abs(($process.StartTime - [datetime]$row.CreationDate).TotalSeconds) -gt 2) { continue }

            Stop-Process -Id $process.Id -Force -ErrorAction Stop
            $stopped++
        }
        catch {
            continue
        }
    }

    return $stopped
}


function Stop-WinForgeGuiCommand {
    param (
        [Parameter(Mandatory)]
        $Session
    )

    if ($Session.Status -ne "Running" -or $null -eq $Session.Ps) {
        return
    }

    # A árvore é lida antes de parar: o PowerShell encerra só a ferramenta que ele mesmo abriu (o DISM), e os filhos dela
    # (o DismHost, que faz o reparo de verdade; o instalador que o winget abriu) ficariam rodando sem ninguém ver.
    $tree = @(Get-WinForgeDescendantProcesses)

    $Session.Host.GuiUI.CancelPending()
    [void]$Session.Ps.BeginStop($null, $null)
    $Session.StopAskedAt = Get-Date

    if ($tree.Count -gt 0) { [void](Stop-WinForgeChildTools -Processes $tree) }
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

        # Um "Parar" que chega enquanto a ação ainda está começando (carregando os módulos) pode não pegar: enquanto ela
        # não para, o pedido é repetido a cada 2 segundos.
        if ($null -ne $Session.StopAskedAt -and -not $Session.Async.IsCompleted -and ((Get-Date) - $Session.StopAskedAt).TotalSeconds -ge 2) {
            $Session.Host.GuiUI.CancelPending()
            [void]$ps.BeginStop($null, $null)
            $Session.StopAskedAt = Get-Date
        }

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
                $output = @($ps.EndInvoke($Session.Async))

                # O desfecho vem como último item do pipeline (ver o final de GuiRunnerScript).
                $found = @($output | Where-Object { $null -ne $_ -and $_.PSObject.TypeNames -contains "WinForge.Outcome" })

                if ($found.Count -gt 0) {
                    $Session.Outcome = $found[$found.Count - 1]
                }
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

            # Erros gravados no último instante (depois da leitura acima) também vão para a tela.
            while ($Session.ErrorIndex -lt $ps.Streams.Error.Count) {
                $record = $ps.Streams.Error[$Session.ErrorIndex]
                $Session.ErrorIndex++
                $ui.WriteInfoLine(("Erro: " + $record.ToString()), [ConsoleColor]::Red)
            }

            $ps.Dispose()
            $Session.Ps = $null
            $Session.Async = $null
            $Session.EndedAt = Get-Date
            $Session.Status = $finalState
        }
    }

    # A fila só é lida depois do estado: se a ação terminou, nada mais será enfileirado.
    $items = $ui.Drain($MaxItems)

    # Terminada, mas com saída ainda na fila (uma ação que escreveu muito no fim): para a janela ela continua "em
    # andamento" até a fila esvaziar, senão o fim da saída (o resumo do resultado) ficaria de fora.
    $status = $Session.Status
    if ($status -ne "Running" -and $ui.PendingCount -gt 0) { $status = "Running" }

    # A versão é lida antes do andamento: um andamento novo gravado entre as duas leituras volta na próxima volta (a
    # versão terá mudado), em vez de ficar marcado como mostrado sem ter aparecido.
    $progressVersion = $ui.ProgressVersion
    $progress = $ui.Progress

    return [PSCustomObject]@{
        Items           = $items
        Status          = $status
        Outcome         = $Session.Outcome
        Prompt          = $ui.PendingPrompt
        Progress        = $progress
        ProgressVersion = $progressVersion
        StartedAt       = $Session.StartedAt
        EndedAt         = $Session.EndedAt
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

            # A janela está fechando com a ação rodando: o que ela abriu também para, e o log fica fechado e completo.
            [void](Stop-WinForgeChildTools)
            $Session.Host.GuiUI.CloseLog()
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
    $label = [string]$Prompt.Label
    $defaultText = ""

    switch ($Prompt.Kind) {
        "key" {
            $buttons += [PSCustomObject]@{ Text = "Continuar"; Answer = ""; Index = -1; Accent = $true; Description = ""; Exit = $false }
        }

        "choice" {
            $index = 0

            # Um destaque só por pergunta: a resposta padrão só ganha a cor quando a ação não destacou nenhuma outra (na
            # pasta da revisão, "Limpar com o WinForge" em destaque e "Pular esta pasta" como padrão ficavam os dois).
            $anyAccent = (@($Prompt.Options | Where-Object { [bool]$_.Accent }).Count -gt 0)

            foreach ($option in @($Prompt.Options)) {
                $isAccent = [bool]$option.Accent

                # A opção de sair ("Cancelar", "Voltar") costuma ser a padrão do ENTER no console, mas na janela ela
                # não deve ganhar a cor de destaque: isso é da ação principal (ou de nenhuma, quando só há sair).
                if (-not $anyAccent -and -not [bool]$option.Exit -and -not [string]::IsNullOrEmpty($Prompt.DefaultKey) -and $option.Key -ieq $Prompt.DefaultKey) {
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
            if ($label -match '(?i)[\(\[]\s*S\s*/\s*N\s*[\)\]]') {
                $buttons += [PSCustomObject]@{ Text = "Sim"; Answer = "S"; Index = -1; Accent = $true; Description = ""; Exit = $false }
                $buttons += [PSCustomObject]@{ Text = "Não"; Answer = "N"; Index = -1; Accent = $false; Description = ""; Exit = $false }
            }
            elseif ($label -match '(?i)\bENTER\b' -and $label -match '(?i)pressione|conclua' -and $label -notmatch '(?i)digite|cole|informe') {
                # "Pressione ENTER para seguir": só o botão; uma caixa de texto ali não serviria para nada.
                $buttons += [PSCustomObject]@{ Text = "Continuar"; Answer = ""; Index = -1; Accent = $true; Description = ""; Exit = $false }

                if ($label -match '(?i)\bP\s*=\s*pular') {
                    $buttons += [PSCustomObject]@{ Text = "Pular as etapas restantes"; Answer = "P"; Index = -1; Accent = $false; Description = ""; Exit = $false }
                }
            }
            else {
                # Texto livre. As dicas de teclado do console saem do rótulo e viram o que são na janela: "(ENTER = 30)"
                # é a resposta já escrita na caixa; "(ENTER cancela)" e "(vazio = voltar)" viram o botão de sair. Sem
                # resposta padrão, a caixa vazia é desistir (Read-WinForgeText): o botão Cancelar manda isso.
                $showText = $true
                $exitText = "Cancelar"

                if ($label -match '(?i)\s*\(\s*ENTER\s*=\s*([^)]+)\)') {
                    $defaultText = $Matches[1].Trim()
                    $label = $label.Replace($Matches[0], "")
                    $exitText = ""
                }
                elseif ($label -match '(?i)\s*\(\s*vazio\s*=\s*voltar\s*\)') {
                    $label = $label.Replace($Matches[0], "")
                    $exitText = "Voltar"
                }
                elseif ($label -match '(?i)\s*\(\s*ENTER\s+cancela\s*\)') {
                    $label = $label.Replace($Matches[0], "")
                }

                if ($exitText) {
                    $buttons += [PSCustomObject]@{ Text = $exitText; Answer = ""; Index = -1; Accent = $false; Description = ""; Exit = $true }
                }
            }
        }
    }

    return [PSCustomObject]@{
        Kind        = [string]$Prompt.Kind
        ShowText    = $showText
        Buttons     = @($buttons)
        Options     = @($Prompt.Options)
        Label       = $label.Trim()
        DefaultText = $defaultText
    }
}


# ---------------------------------------------------------------------------
# Leituras em segundo plano (o Início)
# ---------------------------------------------------------------------------

# Um runspace à parte, só para leituras: a janela continua respondendo enquanto o PC é lido (a proteção do Windows e as
# consultas WMI podem levar segundos). Os módulos são importados uma vez, na primeira leitura, e não na thread da janela.
$script:GuiReaderScript = @'
param ([string]$WinForgeReadModuleRoot, [string[]]$WinForgeReadModules, [string]$WinForgeReadCommand, [hashtable]$WinForgeReadArguments)

$ErrorActionPreference = "Stop"

if (-not $global:WinForgeReaderReady) {
    foreach ($name in $WinForgeReadModules) {
        $modulePath = Join-Path $WinForgeReadModuleRoot "$name.psm1"

        try {
            Import-Module -Name $modulePath -Force -DisableNameChecking -Global
        }
        catch {
            # Caminhos com colchetes são lidos como curinga pelo Import-Module; escapar resolve (como na janela e nas ações).
            Import-Module -Name ([System.Management.Automation.WildcardPattern]::Escape($modulePath)) -Force -DisableNameChecking -Global
        }
    }

    $global:WinForgeReaderReady = $true
}

& $WinForgeReadCommand @WinForgeReadArguments
'@


function New-WinForgeGuiReader {
    # Prepara o runspace das leituras. Abrir é rápido; os módulos só são importados na primeira leitura.
    param (
        [Parameter(Mandatory)]
        [string]$ModuleRoot,

        [Parameter(Mandatory)]
        [string[]]$Modules
    )

    $runspace = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
    $runspace.Open()

    return [PSCustomObject]@{
        Runspace   = $runspace
        ModuleRoot = $ModuleRoot
        Modules    = $Modules
        Ps         = $null
        Async      = $null
        Command    = ""
        StartedAt  = $null
        Watch      = $null
    }
}


function Start-WinForgeGuiRead {
    # Começa uma leitura (uma função dos módulos, com os parâmetros dados). Devolve $false se a anterior não terminou.
    param (
        [Parameter(Mandatory)]
        $Reader,

        [Parameter(Mandatory)]
        [string]$Command,

        [hashtable]$Arguments = @{}
    )

    if ($null -ne $Reader.Ps) { return $false }

    $ps = [System.Management.Automation.PowerShell]::Create()
    $ps.Runspace = $Reader.Runspace
    [void]$ps.AddScript($script:GuiReaderScript, $false)
    [void]$ps.AddArgument($Reader.ModuleRoot)
    [void]$ps.AddArgument([string[]]$Reader.Modules)
    [void]$ps.AddArgument($Command)
    [void]$ps.AddArgument($Arguments)

    $Reader.Ps = $ps
    $Reader.Command = $Command
    $Reader.StartedAt = Get-Date
    $Reader.Watch = [System.Diagnostics.Stopwatch]::StartNew()
    $Reader.Async = $ps.BeginInvoke()

    return $true
}


function Get-WinForgeGuiReadSeconds {
    # Há quanto tempo a leitura em andamento começou, pelo cronômetro: um acerto do relógio do Windows no meio (a hora da
    # internet, o fuso) não a faz passar do limite antes da hora nem a deixa presa. Sem cronômetro, pela hora de início.
    param ([Parameter(Mandatory)]$Reader)

    $watch = $(if ($null -ne $Reader.PSObject.Properties["Watch"]) { $Reader.Watch } else { $null })

    if ($null -ne $watch) { return [double]$watch.Elapsed.TotalSeconds }
    if ($null -eq $Reader.StartedAt) { return 0.0 }

    return [double]((Get-Date) - [datetime]$Reader.StartedAt).TotalSeconds
}


function Receive-WinForgeGuiRead {
    <#
    O resultado da leitura em andamento: $null enquanto ela não termina; depois, Output (o que a função devolveu) e
    Failed (verdadeiro quando ela lançou erro), e o leitor fica livre para a próxima.
    #>
    param (
        [Parameter(Mandatory)]
        $Reader
    )

    if ($null -eq $Reader.Ps) { return $null }
    if (-not $Reader.Async.IsCompleted) { return $null }

    $ps = $Reader.Ps
    $output = @()
    $failed = $false

    try {
        $output = @($ps.EndInvoke($Reader.Async))
        if ($ps.HadErrors -and $output.Count -eq 0) { $failed = $true }
    }
    catch {
        $failed = $true
    }
    finally {
        $Reader.Ps = $null
        $Reader.Async = $null
        $ps.Dispose()
    }

    return [PSCustomObject]@{ Output = $output; Failed = $failed }
}


function Close-WinForgeGuiReader {
    # Descarta o leitor sem esperar: uma leitura presa (WMI que não responde) é interrompida e o runspace fechado em
    # segundo plano, e a janela não fica parada esperando por ela.
    param (
        [Parameter(Mandatory)]
        $Reader
    )

    try {
        if ($null -ne $Reader.Ps) { [void]$Reader.Ps.BeginStop($null, $null) }
        $Reader.Runspace.CloseAsync()
    }
    catch {
        # Encerramento é best-effort.
    }

    $Reader.Ps = $null
    $Reader.Async = $null
}


# ---------------------------------------------------------------------------
# Auxiliares da janela (lógica sem WPF, para ser testada fora do Windows)
# ---------------------------------------------------------------------------

function Format-WinForgeClock {
    # Relógio da execução: 00:00 ou 1:02:03.
    param ([TimeSpan]$Span)

    if ($Span.Ticks -lt 0) { $Span = [TimeSpan]::Zero }

    if ($Span.TotalHours -ge 1) {
        return ("{0}:{1:00}:{2:00}" -f [int][Math]::Floor($Span.TotalHours), $Span.Minutes, $Span.Seconds)
    }

    return ("{0:00}:{1:00}" -f $Span.Minutes, $Span.Seconds)
}


function Get-WinForgeRunView {
    <#
    Como a janela apresenta o fim de uma ação: Level (Ok | Warn | Bad | Muted) escolhe a cor; StatusText é o texto ao
    lado do título; a faixa de resultado só aparece quando há algo a dizer (ShowBanner). Taskbar é o estado do botão
    na barra de tarefas (Normal = verde, Paused = amarelo, Error = vermelho) enquanto a pessoa não volta à janela.
    Status é o da sessão (Completed | Stopped | Failed); Outcome é o WinForge.Outcome devolvido pela ação, se houver.
    Quando a ação deu título próprio ao resultado (Set-WinForgeResultView), ele vale na faixa e no status, com a cor que
    ela pediu; Next e NextLabel são o botão do próximo passo, e HideSummary esconde o resumo.
    #>
    param (
        [string]$Status,
        $Outcome = $null,
        [TimeSpan]$Elapsed = [TimeSpan]::Zero
    )

    $clock = Format-WinForgeClock -Span $Elapsed
    $kind = "Done"
    $title = ""
    $summary = ""
    $reboot = $false
    $headline = ""
    $tone = ""

    if ($null -ne $Outcome) {
        $kind = [string]$Outcome.Kind
        $title = [string]$Outcome.Title
        $summary = [string]$Outcome.Summary
        $reboot = [bool]$Outcome.RebootRequired
        $headline = ([string](Get-WinForgeJsonValue -Object $Outcome -Name "Headline" -Default "")).Trim()
        $tone = [string](Get-WinForgeJsonValue -Object $Outcome -Name "Tone" -Default "")
    }

    $view = [ordered]@{
        Level      = "Muted"
        StatusText = "Concluído"
        ShowBanner = $false
        BannerTitle = ""
        BannerText  = ""
        ResultText  = ""
        Taskbar     = "None"
        Notify      = $true
        ElapsedText = $clock
        Next        = ""
        NextLabel   = ""
        HideSummary = $false
    }

    if ($Status -eq "Stopped") {
        $view.Level = "Warn"
        $view.StatusText = "Interrompido"
        $view.ShowBanner = $true
        $view.BannerTitle = "Interrompido"
        $view.BannerText = "A ação foi interrompida. O que já tinha sido feito continua feito; a etapa em andamento ficou incompleta."
        $view.Taskbar = "Paused"
        $view.Notify = $false
    }
    elseif ($Status -eq "Failed") {
        $view.Level = "Bad"
        $view.StatusText = "Terminou com erro"
        $view.ShowBanner = $true
        $view.BannerTitle = "Terminou com erro"
        $view.BannerText = $(if ($summary) { $summary } else { "A ação terminou com erro. Veja os detalhes técnicos." })
        $view.Taskbar = "Error"
    }
    else {
        switch ($kind) {
            "Ok" {
                $view.Level = "Ok"; $view.StatusText = "Concluído"; $view.Taskbar = "Normal"
                $view.ShowBanner = $true; $view.BannerTitle = "Tudo certo"; $view.BannerText = $summary
            }
            "Warning" {
                $view.Level = "Warn"; $view.StatusText = "Concluído com ressalvas"; $view.Taskbar = "Paused"
                $view.ShowBanner = $true; $view.BannerTitle = "Concluído com ressalvas"; $view.BannerText = $summary
            }
            "Failed" {
                $view.Level = "Bad"; $view.StatusText = "Não foi concluído"; $view.Taskbar = "Error"
                $view.ShowBanner = $true; $view.BannerTitle = "Não foi concluído"; $view.BannerText = $summary
            }
            "Skipped" {
                $view.Level = "Muted"; $view.StatusText = $(if ($title) { $title } else { "Nada a fazer" }); $view.Taskbar = "None"
                $view.ShowBanner = $true; $view.BannerTitle = $view.StatusText; $view.BannerText = $summary
                $view.Notify = $false
            }
            default {
                # A ação só mostrou informações (consulta): não há veredito a destacar.
                $view.Level = "Muted"; $view.StatusText = "Concluído"
                $view.Notify = $false
            }
        }

        # O título que a ação deu ao resultado ("3 ameaças pedem ação") e a cor que ele pede: uma ameaça pendente é
        # vermelha mesmo com a verificação concluída. O botão do próximo passo só vale para um fim normal.
        if ($headline -and $kind -in @("Ok", "Warning", "Failed", "Skipped")) {
            $view.StatusText = $headline
            $view.BannerTitle = $headline
            $view.ShowBanner = $true

            if ($tone -in @("Ok", "Warn", "Bad")) {
                $view.Level = $tone
                $view.Taskbar = switch ($tone) { "Ok" { "Normal" } "Warn" { "Paused" } default { "Error" } }
                $view.Notify = $true
            }

            $view.Next = [string](Get-WinForgeJsonValue -Object $Outcome -Name "Next" -Default "")
            $view.NextLabel = [string](Get-WinForgeJsonValue -Object $Outcome -Name "NextLabel" -Default "")
            $view.HideSummary = [bool](Get-WinForgeJsonValue -Object $Outcome -Name "HideSummary" -Default $false)
        }

        if ($view.ShowBanner -and $reboot) {
            $view.BannerText = ($view.BannerText + (Get-WinForgeRebootSentence -Kind $kind -Detail $view.BannerText)).Trim()
        }
    }

    $view.BannerText = ($view.BannerText + " Duração: $clock.").Trim()
    $view.ResultText = (Get-WinForgeResultSentence -Status $Status -Outcome $Outcome -ShowBanner $view.ShowBanner) + " Duração: $clock."
    $view.ResultText = $view.ResultText.Trim()

    return [PSCustomObject]$view
}


function Get-WinForgeResultSentence {
    <#
    A frase do resultado na tela de execução, embaixo do título ("Tudo certo", "Concluído com ressalvas"...): o que
    aconteceu, sem repetir o título. Vem do detalhe que a ação registrou; sem ele, uma frase do próprio desfecho. Quando a
    ação deu título próprio ao resultado, a frase é a dela (Note), que completa o título em vez de repeti-lo.
    #>
    param (
        [string]$Status,
        $Outcome = $null,
        [bool]$ShowBanner = $true
    )

    if ($Status -eq "Stopped") {
        return "O que já tinha sido feito continua feito; a etapa em andamento ficou incompleta."
    }

    $kind = "Done"
    $detail = ""
    $reboot = $false

    if ($null -ne $Outcome) {
        $kind = [string]$Outcome.Kind
        $detail = ([string]$Outcome.Detail).Trim().TrimEnd(".").Trim()
        $reboot = [bool]$Outcome.RebootRequired

        $headline = ([string](Get-WinForgeJsonValue -Object $Outcome -Name "Headline" -Default "")).Trim()
        $note = ([string](Get-WinForgeJsonValue -Object $Outcome -Name "Note" -Default "")).Trim().TrimEnd(".").Trim()

        if ($headline -and $note -and $Status -ne "Failed") { $detail = $note }
    }

    # Longa demais, a frase é cortada num espaço, e não no meio de uma palavra.
    if ($detail.Length -gt 220) {
        $cut = $detail.LastIndexOf(" ", 216)
        if ($cut -lt 120) { $cut = 217 }
        $detail = $detail.Substring(0, $cut).TrimEnd(",", ";", " ") + "..."
    }

    $sentence = ""

    if ($detail.Length -gt 0) {
        $sentence = $detail.Substring(0, 1).ToUpperInvariant() + $detail.Substring(1)
        if (-not $sentence.EndsWith("...")) { $sentence += "." }
    }

    if ($Status -eq "Failed") {
        if ($sentence.Length -eq 0) { $sentence = "A ação terminou com um erro inesperado. Veja os detalhes técnicos." }
        return $sentence
    }

    switch ($kind) {
        "Ok" { if ($sentence.Length -eq 0) { $sentence = "Concluído com sucesso." } }
        "Warning" { if ($sentence.Length -eq 0) { $sentence = "Algumas etapas pediram atenção; veja os detalhes técnicos." } }
        "Failed" { if ($sentence.Length -eq 0) { $sentence = "Veja os detalhes técnicos para saber o motivo." } }
        "Skipped" {
            if ($detail -match "(?i)cancelad") { $sentence = "Operação cancelada." }
            elseif ($sentence.Length -eq 0) { $sentence = "Não havia nada a fazer." }
        }
        default { $sentence = "" }
    }

    if ($ShowBanner -and $reboot) { $sentence = ($sentence + (Get-WinForgeRebootSentence -Kind $kind -Detail $detail)).Trim() }

    return $sentence
}


function Get-WinForgePromptLayout {
    <#
    A tela de execução não rola, e os botões de uma pergunta têm de ficar sempre à vista. O cartão da pergunta recebe
    como altura máxima o espaço que sobra entre o alto dele e os detalhes técnicos; dentro dele, só a lista (ou as opções
    em linha) encolhe e rola. Se nem assim a pergunta fica confortável (a lista com pelo menos MinList, ou inteira se for
    menor), o resumo acima dela encolhe primeiro, até sumir se preciso.
    Medidas em pixels, com o cartão sem limite: ViewHeight (a tela de execução), PromptTop (o alto do cartão), Margin (a
    margem embaixo dele), DetailsHeight (o que os detalhes técnicos precisam), PromptHeight (o cartão inteiro), ListHeight
    (a lista ou as opções; 0 sem elas) e SummaryHeight (o resumo; 0 escondido).
    Devolve PromptMaxHeight, SummaryMaxHeight (-1 = deixe o resumo como está) e Cramped (nem a pergunta sem a lista cabe
    até o fim da tela: a janela tira o que der de dentro do cartão). O cartão nunca passa do fim da tela: medidas erradas
    (uma lista contada como vazia) deixavam o cartão do tamanho da lista, sem rolar.
    #>
    param (
        [double]$ViewHeight,
        [double]$PromptTop,
        [double]$Margin = 14,
        [double]$DetailsHeight = 0,
        [double]$PromptHeight,
        [double]$ListHeight = 0,
        [double]$SummaryHeight = 0,
        [double]$MinList = 160,

        # O mínimo dos detalhes técnicos abertos (o cabeçalho, com a saída espremida): a saída deles cede espaço antes do
        # resumo e da lista. Negativo (o padrão): os detalhes não cedem nada.
        [double]$DetailsMinHeight = -1
    )

    $chrome = [Math]::Max(0.0, $PromptHeight - $ListHeight)
    $want = $chrome + [Math]::Min($ListHeight, $MinList)
    $room = $ViewHeight - $PromptTop - $Margin - $DetailsHeight
    $summary = -1

    # Primeiro a saída dos detalhes técnicos abertos encolhe (ela rola e continua à mão); depois, o resumo.
    if ($room -lt $want -and $DetailsMinHeight -ge 0 -and $DetailsHeight -gt $DetailsMinHeight) {
        $room += [Math]::Min($want - $room, $DetailsHeight - $DetailsMinHeight)
    }

    $cut = 0.0

    if ($room -lt $want -and $SummaryHeight -gt 0) {
        $cut = [Math]::Min($want - $room, $SummaryHeight)
        $summary = [Math]::Floor($SummaryHeight - $cut)
        $room += $cut
    }

    # Nunca menos que a pergunta sem a lista: numa janela pequena demais, os botões ainda aparecem (e a lista some).
    $prompt = [Math]::Floor([Math]::Max($room, [Math]::Min($chrome, $PromptHeight)))

    # E nunca além do fim da tela (o alto do cartão sobe o tanto que o resumo encolheu).
    $bottom = [Math]::Floor($ViewHeight - $PromptTop + $cut - $Margin)
    $cramped = ($bottom -lt [Math]::Min($chrome, $PromptHeight))
    if ($bottom -gt 0 -and $prompt -gt $bottom) { $prompt = $bottom }

    return [PSCustomObject]@{ PromptMaxHeight = $prompt; SummaryMaxHeight = $summary; Cramped = $cramped }
}


function Get-WinForgeOutputFileName {
    # Nome sugerido ao salvar a saída de uma ação: "WinForge - Reparar o Windows - 2026-10-18 1502.txt".
    param (
        [string]$Title,
        [datetime]$When = (Get-Date)
    )

    $clean = ([string]$Title) -replace '[\\/:*?"<>|\x00-\x1F]', " "
    $clean = ($clean -replace '\s+', ' ').Trim()

    if ($clean.Length -gt 60) { $clean = $clean.Substring(0, 60).Trim() }
    if ([string]::IsNullOrEmpty($clean)) { $clean = "saida" }

    return ("WinForge - {0} - {1}.txt" -f $clean, $When.ToString("yyyy-MM-dd HHmm"))
}


function Resolve-WinForgeWindowBounds {
    <#
    Valida o tamanho e a posição guardados da janela. Devolve Left/Top/Width/Height/Maximized prontos para usar, ou
    $null quando nada foi guardado ou a janela ficaria fora das telas atuais (monitor desligado, resolução menor).
    Screen é a área virtual de todas as telas (Left, Top, Width, Height).
    #>
    param (
        $Saved,
        [Parameter(Mandatory)]$Screen,
        [double]$MinWidth = 860,
        [double]$MinHeight = 540
    )

    if ($null -eq $Saved) { return $null }

    foreach ($name in "Left", "Top", "Width", "Height") {
        if ($null -eq $Saved.PSObject.Properties[$name] -or $null -eq $Saved.PSObject.Properties[$name].Value) { return $null }
    }

    try {
        $width = [double]$Saved.Width
        $height = [double]$Saved.Height
        $left = [double]$Saved.Left
        $top = [double]$Saved.Top
    }
    catch {
        return $null
    }

    if ([double]::IsNaN($width) -or [double]::IsNaN($height) -or [double]::IsNaN($left) -or [double]::IsNaN($top)) { return $null }

    $width = [Math]::Max($MinWidth, [Math]::Min($width, [double]$Screen.Width))
    $height = [Math]::Max($MinHeight, [Math]::Min($height, [double]$Screen.Height))

    # Pelo menos um pedaço da barra de título (80 x 40) precisa continuar visível, para a janela poder ser arrastada.
    $visibleWidth = [Math]::Min($left + $width, $Screen.Left + $Screen.Width) - [Math]::Max($left, $Screen.Left)
    $visibleHeight = [Math]::Min($top + 40, $Screen.Top + $Screen.Height) - [Math]::Max($top, $Screen.Top)

    if ($visibleWidth -lt 80 -or $visibleHeight -lt 40) { return $null }

    $maximized = $false
    $property = $Saved.PSObject.Properties["Maximized"]
    if ($null -ne $property) { $maximized = [bool]$property.Value }

    return [PSCustomObject]@{ Left = $left; Top = $top; Width = $width; Height = $height; Maximized = $maximized }
}


Export-ModuleMember -Function *
