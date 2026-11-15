# Windows Update dentro do WinForge: procurar, escolher, baixar e instalar as atualizações pendentes, com progresso.
#
# Usa a API COM do próprio Windows Update (Microsoft.Update.Session), a mesma de Get-WinForgePendingWindowsUpdates. O
# trabalho roda em outro runspace (Invoke-WinForgeInBackground cuida só da consulta): enquanto ele baixa e instala, a
# tela acompanha o progresso e o botão Parar continua funcionando.
#
# As atualizações opcionais (BrowseOnly: drivers opcionais e prévias) não entram na instalação do Windows: o Windows só
# as oferece na página de atualizações opcionais. Os drivers (Criteria com Type='Driver', em Drivers.psm1) usam a mesma
# busca e a mesma instalação, com os opcionais incluídos e marcados como tal (BrowseOnly).
#
# Quando o Windows Update em si falha (cache corrompido, serviço desativado), Repair-WinForgeWindowsUpdate refaz o cache
# como manda a Microsoft: para os serviços, põe de lado as pastas Download e DataStore e o catroot2, e liga tudo de novo.


# ---------------------------------------------------------------------------
# Acesso ao Windows Update (código que roda no outro runspace)
# ---------------------------------------------------------------------------

function Get-WinForgeUpdateComFactoryCode {
    # Cria a sessão do Windows Update e a coleção de atualizações. É um texto para que os testes troquem o Windows
    # Update de verdade por um de mentira, sem mudar o restante do código.
    return @'
@{
    Session       = (New-Object -ComObject "Microsoft.Update.Session" -ErrorAction Stop)
    NewCollection = { New-Object -ComObject "Microsoft.Update.UpdateColl" -ErrorAction Stop }
}
'@
}


function Get-WinForgeUpdateSessionCode {
    <#
    Abre a sessão do Windows Update ($com e $session), como texto para os dois scripts que rodam no outro runspace. Com o
    componente COM do Windows Update quebrado ou não registrado, New-Object falha e, sem esta parada, o script seguia com
    a sessão nula até "You cannot call a method on a null-valued expression". O erro sai com a marca WinForge.SemSessao e o
    código do Windows (0x...) quando houver; Get-WinForgeWindowsUpdateProblem o traduz para a pessoa.
    #>
    return @'
try {
    $com = & ([scriptblock]::Create($FactoryCode))
    $session = $null
    if ($null -ne $com) { $session = $com.Session }
    if ($null -eq $session) { throw "sem sessão" }
}
catch {
    $sessionCode = 0
    $problem = $_.Exception

    while ($null -ne $problem) {
        $codeMatch = [regex]::Match([string]$problem.Message, '0x[0-9A-Fa-f]{8}')

        if ($codeMatch.Success) { $sessionCode = [Convert]::ToInt32($codeMatch.Value.Substring(2), 16); break }

        # Os HResult genéricos do .NET e do PowerShell não dizem nada sobre a causa.
        if ($problem.HResult -lt 0 -and $problem.HResult -notin @(-2146233088, -2146233087, -2146233079, -2146232832)) { $sessionCode = $problem.HResult; break }

        $problem = $problem.InnerException
    }

    throw ("WinForge.SemSessao:0x{0:X8}" -f $sessionCode)
}
'@
}


function Get-WinForgeUpdateSearchCode {
    <#
    A busca padrão das atualizações, como texto (roda no outro runspace, que não enxerga as funções do WinForge). Só um
    Windows Update que não conhece o critério BrowseOnly (WU_E_INVALID_CRITERIA, 0x80240032) ganha a busca sem ele; um
    erro de verdade (sem internet, serviço parado) volta como erro, em vez de virar uma segunda busca que traria também
    os opcionais (prévias e drivers) como se fossem atualizações comuns.
    #>
    return @'
if (-not [string]::IsNullOrEmpty($Criteria)) {
    $found = $searcher.Search($Criteria)
}
else {
    try {
        $found = $searcher.Search("IsInstalled=0 and IsHidden=0 and BrowseOnly=0")
    }
    catch {
        $invalidCriteria = $false
        $problem = $_.Exception

        while ($null -ne $problem) {
            # -2145124302 = 0x80240032 (WU_E_INVALID_CRITERIA).
            if ($problem.HResult -eq -2145124302 -or [string]$problem.Message -match '0x80240032') { $invalidCriteria = $true }
            $problem = $problem.InnerException
        }

        if (-not $invalidCriteria) { throw }

        $found = $searcher.Search("IsInstalled=0 and IsHidden=0")
    }
}
'@
}


function Get-WinForgeUpdateSearchScript {
    # Com "Stop", o primeiro erro encerra a busca e é ele que volta para a tela (e não um erro posterior, consequência dele).
    $text = @'
param ($FactoryCode, $Criteria)

$ErrorActionPreference = "Stop"

__SESSION__

$searcher = $session.CreateUpdateSearcher()

__SEARCH__

foreach ($update in $found.Updates) {
    $kb = ""

    try {
        $firstKb = @($update.KBArticleIDs) | Select-Object -First 1

        if ($null -ne $firstKb) { $kb = [string]$firstKb }
    }
    catch {
        $kb = ""
    }

    $browseOnly = $false
    try { $browseOnly = [bool]$update.BrowseOnly } catch { $browseOnly = $false }

    # Type 2 = driver (IWindowsDriverUpdate): a classe (Display, Net...) e o aparelho dizem para que ele serve, o que o
    # título ("Intel - System - 10.1.1.44"), muitas vezes repetido para aparelhos diferentes, não diz.
    $driver = $false
    $driverClass = ""
    $driverModel = ""

    try { $driver = ([int]$update.Type -eq 2) } catch { $driver = $false }

    if ($driver) {
        try { $driverClass = [string]$update.DriverClass } catch { $driverClass = "" }
        try { $driverModel = [string]$update.DriverModel } catch { $driverModel = "" }
    }

    # Uma versão nova do Windows (a classificação Upgrades, pelo Id, que não muda com o idioma): o Otimizar a deixa de
    # fora, porque troca o Windows inteiro e leva horas.
    $upgrade = $false

    try {
        foreach ($category in $update.Categories) {
            if ([string]$category.CategoryID -eq "3689bdc8-b205-4af4-8d4a-a63924c5e9d5") { $upgrade = $true }
        }
    }
    catch {
        $upgrade = $false
    }

    [PSCustomObject]@{
        Id          = [string]$update.Identity.UpdateID
        Title       = [string]$update.Title
        Kb          = $kb
        Size        = [int64]$update.MaxDownloadSize
        Downloaded  = [bool]$update.IsDownloaded
        BrowseOnly  = $browseOnly
        Driver      = $driver
        DriverClass = $driverClass.Trim()
        DriverModel = $driverModel.Trim()
        Upgrade     = $upgrade
    }
}
'@

    return $text.Replace("__SESSION__", (Get-WinForgeUpdateSessionCode)).Replace("__SEARCH__", (Get-WinForgeUpdateSearchCode))
}


function Get-WinForgeUpdateInstallScript {
    # Procura de novo (primeiro no que o Windows guardou da busca que montou a lista), separa as escolhidas pelo Id, baixa
    # e instala. Escreve o andamento em $State (tabela sincronizada) e nunca lança erro: qualquer falha vai para
    # $State.Error. $State.Done fica verdadeiro ao final.
    # Escolhidas que o Windows deixou de oferecer vão para $State.Missing (Ids) e as que não foram baixadas, para
    # $State.NotDownloaded (Ids): nenhuma some do resumo em silêncio. Junto do texto do erro vai o HRESULT de origem
    # ($State.ErrorHResult), para a tela dizer o código mesmo quando a mensagem não o traz.
    $text = @'
param ($State, $Ids, $FactoryCode, $Criteria)

$ErrorActionPreference = "Stop"

# BeginDownload e BeginInstall mostram o andamento; quando o Windows recusa o próprio pedido assíncrono (o tipo dos
# parâmetros), o método síncrono faz o mesmo sem o andamento. Um erro do Windows Update (0x8024xxxx) ou do Windows
# (0x8007xxxx: serviço parado, disco cheio, sem conexão) não melhora com uma segunda tentativa: volta como erro.
$isUpdateError = {
    param ($exception)

    $current = $exception

    while ($null -ne $current) {
        $code = "{0:X8}" -f [int]$current.HResult
        if (($code.StartsWith("8024") -or $code.StartsWith("8007")) -and $code -ne "80070057") { return $true }
        $current = $current.InnerException
    }

    return $false
}

try {
__SESSION__

    $State.Phase = "Procurando"
    $searcher = $session.CreateUpdateSearcher()

    # A busca (Get-WinForgeUpdateSearchCode) deixa o resultado em $found.
    $runSearch = {
__SEARCH__

        return $found
    }

    # A lista que a pessoa acabou de ver veio de uma busca online, e o Windows guarda o resultado dela: a busca neste PC
    # (Online = falso) acha as mesmas em segundos. Só quando falta alguma escolhida a busca vai ao Windows Update de novo.
    $found = $null

    try {
        $searcher.Online = $false
        $local = & $runSearch
        $localIds = @(foreach ($update in $local.Updates) { [string]$update.Identity.UpdateID })

        if (@(@($Ids) | Where-Object { $localIds -notcontains [string]$_ }).Count -eq 0) { $found = $local }
    }
    catch {
        $found = $null
    }

    if ($null -eq $found) {
        try { $searcher.Online = $true } catch { }
        $found = & $runSearch
    }

    $selected = New-Object System.Collections.ArrayList

    foreach ($update in $found.Updates) {
        if (@($Ids) -contains [string]$update.Identity.UpdateID) {
            [void]$selected.Add($update)
        }
    }

    foreach ($id in @($Ids)) {
        $present = $false

        foreach ($update in $selected) {
            if ([string]$update.Identity.UpdateID -eq [string]$id) { $present = $true; break }
        }

        if (-not $present) {
            [void]$State.Missing.Add([string]$id)
        }
    }

    if ($selected.Count -eq 0) {
        $State.Error = "as atualizações escolhidas não estão mais disponíveis"
        return
    }

    $State.Total = $selected.Count

    foreach ($update in $selected) {
        if (-not $update.EulaAccepted) {
            $update.AcceptEula()
        }
    }

    # Baixar só o que ainda não foi baixado.
    $toDownload = & $com.NewCollection

    foreach ($update in $selected) {
        if (-not $update.IsDownloaded) {
            [void]$toDownload.Add($update)
        }
    }

    if ($toDownload.Count -gt 0) {
        $State.Phase = "Baixando"
        $State.Percent = 0
        $State.Index = 0
        $State.Total = $toDownload.Count
        $downloader = $session.CreateUpdateDownloader()
        $downloader.Updates = $toDownload

        $job = $null

        try { $job = $downloader.BeginDownload($null, $null, $null) } catch { if (& $isUpdateError $_.Exception) { throw }; $job = $null }

        if ($null -ne $job) {
            while (-not $job.IsCompleted) {
                $progress = $job.GetProgress()
                $State.Percent = [int]$progress.PercentComplete
                $State.Index = [int]$progress.CurrentUpdateIndex + 1

                try { $State.Current = [string]$toDownload.Item([int]$progress.CurrentUpdateIndex).Title } catch { }

                Start-Sleep -Milliseconds 500
            }

            $downloadResult = $downloader.EndDownload($job)
        }
        else {
            $downloadResult = $downloader.Download()
        }

        $State.Percent = 100

        if ([int]$downloadResult.ResultCode -notin 2, 3) {
            # Só os códigos: a frase é montada do lado da tela (Get-WinForgeUpdateDownloadError), que conhece os erros.
            $State.DownloadCode = [int]$downloadResult.ResultCode
            try { $State.DownloadHResult = [int]$downloadResult.HResult } catch { $State.DownloadHResult = 0 }
            return
        }

        # Com o código 3 o Windows baixou só parte: o que ficou sem baixar não pode ser instalado.
        foreach ($update in $selected) {
            if (-not $update.IsDownloaded) {
                [void]$State.NotDownloaded.Add([string]$update.Identity.UpdateID)
            }
        }
    }

    # Instalar o que está baixado.
    $toInstall = & $com.NewCollection

    foreach ($update in $selected) {
        if ($update.IsDownloaded) {
            [void]$toInstall.Add($update)
        }
    }

    if ($toInstall.Count -eq 0) {
        $State.Error = "nenhuma das atualizações foi baixada, então nada foi instalado"
        return
    }

    $State.Phase = "Instalando"
    $State.Percent = 0
    $State.Index = 0
    $State.Total = $toInstall.Count

    $installer = $session.CreateUpdateInstaller()
    $installer.Updates = $toInstall

    try { $installer.AllowSourcePrompts = $false } catch { }

    $job = $null

    try { $job = $installer.BeginInstall($null, $null, $null) } catch { if (& $isUpdateError $_.Exception) { throw }; $job = $null }

    if ($null -ne $job) {
        while (-not $job.IsCompleted) {
            $progress = $job.GetProgress()
            $State.Percent = [int]$progress.PercentComplete
            $State.Index = [int]$progress.CurrentUpdateIndex + 1

            try { $State.Current = [string]$toInstall.Item([int]$progress.CurrentUpdateIndex).Title } catch { }

            Start-Sleep -Milliseconds 500
        }

        $installResult = $installer.EndInstall($job)
    }
    else {
        $installResult = $installer.Install()
    }

    $State.Percent = 100

    for ($i = 0; $i -lt $toInstall.Count; $i++) {
        $one = $installResult.GetUpdateResult($i)

        [void]$State.Results.Add([PSCustomObject]@{
                Title   = [string]$toInstall.Item($i).Title
                Code    = [int]$one.ResultCode
                HResult = [int]$one.HResult
            })
    }

    $State.RebootRequired = [bool]$installResult.RebootRequired
}
catch {
    $State.Error = [string]$_.Exception.Message

    try {
        $inner = $_.Exception
        while ($null -ne $inner.InnerException) { $inner = $inner.InnerException }
        $State.ErrorHResult = [int]$inner.HResult
    }
    catch {
        $State.ErrorHResult = 0
    }
}
finally {
    $State.Done = $true
}
'@

    return $text.Replace("__SESSION__", (Get-WinForgeUpdateSessionCode)).Replace("__SEARCH__", (Get-WinForgeUpdateSearchCode))
}


# ---------------------------------------------------------------------------
# Lista, resultados e textos
# ---------------------------------------------------------------------------

function Get-WinForgeWindowsUpdateHResultText {
    <#
    Uma frase para os códigos de erro mais comuns do Windows Update (os nomes e significados são os da tabela de
    códigos do Windows Update Agent e da página de erros comuns do Windows Update, da Microsoft; os 0x8007xxxx e
    0x800Fxxxx são erros do Windows). "" para os demais. Quando o caminho é refazer o cache do Windows Update ou reparar
    os arquivos do Windows, a frase aponta o item do WinForge que faz isso.
    #>
    param ([int]$HResult)

    $cache = "use Atualizações > Corrigir o Windows Update"
    $store = "use Reparo > Reparar o Windows (DISM + SFC)"

    switch ("0x{0:X8}" -f $HResult) {
        "0x80240016" { return "outra instalação estava em andamento ou falta reiniciar o PC" }
        "0x8024200D" { return "a atualização precisa ser baixada de novo; se o erro voltar, $cache" }
        "0x80246007" { return "a atualização não foi baixada; se o erro voltar, $cache" }
        "0x80242006" { return "os dados da atualização guardados no PC estão inválidos; $cache" }
        "0x80248007" { return "falta informação no cache do Windows Update; $cache" }
        "0x8007000D" { return "o que foi baixado veio corrompido; $cache" }
        "0x80246008" { return "o serviço de transferência do Windows (BITS) não respondeu; $cache" }
        "0x80240034" { return "o download falhou" }
        "0x8024001E" { return "o Windows estava desligando ou o serviço parou" }
        "0x8024000B" { return "a operação foi cancelada" }
        "0x8024001F" { return "sem conexão com a internet" }
        "0x8024402C" { return "não foi possível chegar ao servidor do Windows Update (endereço não encontrado)" }
        "0x80072EFD" { return "não foi possível conectar ao servidor do Windows Update" }
        "0x80072EFE" { return "a conexão com o Windows Update caiu no meio" }
        "0x80072EE2" { return "a conexão com o Windows Update esgotou o tempo" }
        "0x8024401C" { return "o servidor do Windows Update demorou demais para responder" }
        "0x80244017" { return "o servidor recusou o acesso (um proxy ou firewall pode estar bloqueando)" }
        "0x80244018" { return "o servidor recusou o acesso (um proxy ou firewall pode estar bloqueando)" }
        "0x80244022" { return "o servidor do Windows Update está sobrecarregado; tente mais tarde" }
        "0x8024002E" { return "uma política do Windows bloqueia o acesso ao Windows Update" }
        "0x80070422" { return "o serviço Windows Update está desativado; $cache" }
        "0x80070070" { return "falta espaço no disco" }
        "0x80070020" { return "um arquivo estava em uso por outro programa, como um antivírus" }
        "0x80070BC9" { return "o Windows precisa reiniciar para desfazer uma instalação anterior; reinicie o PC e tente de novo" }
        "0x80073712" { return "a imagem do Windows está danificada; $store" }
        "0x80073701" { return "faltam arquivos do Windows de que a atualização precisa; $store" }
        "0x800F081F" { return "faltam arquivos do Windows de que a atualização precisa; $store" }
        "0x800F0831" { return "faltam arquivos do Windows de que a atualização precisa; $store" }
    }

    return ""
}


function Format-WinForgeUpdateError {
    # "frase — erro 0x80240016", ou só "erro 0x8024XXXX" para um código sem frase. "" sem código.
    param ([int]$HResult)

    if ($HResult -eq 0) { return "" }

    $code = "0x{0:X8}" -f $HResult
    $text = Get-WinForgeWindowsUpdateHResultText -HResult $HResult

    if ($text) { return "$text — erro $code" }

    return "erro $code"
}


function Get-WinForgeWindowsUpdateProblem {
    <#
    O motivo de a consulta (ou a instalação) ter falhado, para a pessoa. A mensagem do PowerShell embrulha a do Windows
    ('Exception calling "Search" with "1" argument(s): "Exception from HRESULT: 0x80070422"'): sai o embrulho, e um
    código conhecido vira frase. HResult é o código da exceção de origem: vale quando a mensagem não traz código nenhum
    (uma mensagem do Windows em texto puro), e o código vai junto da frase, para a pessoa poder pesquisá-lo.
    #>
    param (
        [string]$Message,
        [int]$HResult = 0
    )

    $text = ([string]$Message).Trim()

    while ($text -match '^Exception calling "[^"]+" with "[0-9]+" argument\(s\): "(.*)"$') {
        $text = $Matches[1].Trim()
    }

    # A sessão do Windows Update não abriu (Get-WinForgeUpdateSessionCode): componente COM quebrado, não registrado ou
    # serviço que não responde. A frase diz isso; um código conhecido acrescenta o motivo, e o código vai junto.
    if ($text -match 'WinForge\.SemSessao:0x([0-9A-Fa-f]{8})') {
        $sessionCode = [Convert]::ToInt32($Matches[1], 16)
        $base = "o Windows Update não abriu neste PC"

        if ($sessionCode -eq 0) { return "$base (o componente dele não respondeu)" }

        $phrase = Get-WinForgeWindowsUpdateHResultText -HResult $sessionCode

        return "$base ($(if ($phrase) { $phrase } else { 'o componente dele não respondeu' })) — erro $("0x{0:X8}" -f $sessionCode)"
    }

    if ($text -match '0x([0-9A-Fa-f]{8})') {
        return (Format-WinForgeUpdateError -HResult ([Convert]::ToInt32($Matches[1], 16)))
    }

    # Os códigos genéricos do .NET e do PowerShell não dizem nada e ficam de fora (Get-WinForgeErrorCode).
    $code = Get-WinForgeErrorCode -HResult $HResult

    if ($code) {
        $phrase = Get-WinForgeWindowsUpdateHResultText -HResult $HResult

        if ($phrase) { return "$phrase — erro $code" }
        if ([string]::IsNullOrWhiteSpace($text)) { return "erro $code" }

        return "$($text.TrimEnd('.')) — erro $code"
    }

    if ([string]::IsNullOrWhiteSpace($text)) { return "o Windows Update devolveu um erro" }

    return $text.TrimEnd(".")
}


function Find-WinForgeWindowsUpdates {
    <#
    Procura as atualizações pendentes. Devolve Updates (Id, Title, Kb, Size em bytes, Downloaded e BrowseOnly; lista vazia
    = o Windows está em dia) e Problem: "" quando a consulta funcionou, ou o motivo de não ter funcionado (Updates fica
    $null). Criteria troca a busca padrão (por exemplo, só drivers).
    #>
    param (
        [int]$TimeoutSeconds = 300,

        [string]$FactoryCode = (Get-WinForgeUpdateComFactoryCode),

        [string]$Criteria = ""
    )

    try {
        $run = Invoke-WinForgeInBackground -ScriptBlock ([scriptblock]::Create((Get-WinForgeUpdateSearchScript))) -ArgumentList @($FactoryCode, $Criteria) -TimeoutSeconds $TimeoutSeconds
    }
    catch {
        return [PSCustomObject]@{ Updates = $null; Problem = (Get-WinForgeWindowsUpdateProblem -Message $_.Exception.Message -HResult $_.Exception.HResult) }
    }

    if ($run.TimedOut) {
        $minutes = [int][math]::Ceiling($TimeoutSeconds / 60)
        return [PSCustomObject]@{ Updates = $null; Problem = "o Windows Update não respondeu em $(Format-WinForgeCount -Count $minutes -One 'minuto' -Many 'minutos')" }
    }

    if (-not $run.Completed) {
        return [PSCustomObject]@{ Updates = $null; Problem = (Get-WinForgeWindowsUpdateProblem -Message $run.Error) }
    }

    return [PSCustomObject]@{
        Updates = @($run.Output | Where-Object { $null -ne $_ -and -not [string]::IsNullOrWhiteSpace([string]$_.Id) })
        Problem = ""
    }
}


function Get-WinForgeUpdateOutcome {
    # Traduz o código de resultado do Windows Update (0 e 1 = não terminou, 2 = instalada, 3 = com erros, 4 = falhou,
    # 5 = interrompida), com o código de erro de cada atualização quando houver.
    param (
        [int]$Code,

        [int]$HResult = 0
    )

    $errorText = Format-WinForgeUpdateError -HResult $HResult

    switch ($Code) {
        2 { return (New-WinForgeResult -Kind Ok) }
        3 { return (New-WinForgeResult -Kind Warning -Detail $(if ($errorText) { "instalada com erros: $errorText" } else { "instalada com erros" })) }
        5 { return (New-WinForgeResult -Kind Failed -Detail "interrompida") }
        { $_ -in 0, 1 } { return (New-WinForgeResult -Kind Failed -Detail "não foi concluída") }
        default { return (New-WinForgeResult -Kind Failed -Detail $errorText) }
    }
}


function Get-WinForgeUpdateDownloadError {
    # O motivo de o download inteiro ter falhado (código 4) ou parado (código 5), com o erro do Windows quando houver.
    param (
        [int]$Code,

        [int]$HResult = 0
    )

    $errorText = Format-WinForgeUpdateError -HResult $HResult

    if ($Code -eq 5) { return "o download das atualizações foi interrompido" }
    if ($errorText) { return "o download das atualizações falhou: $errorText" }

    return "o download das atualizações falhou"
}


function Get-WinForgeUpdateRunDetail {
    <#
    A frase do resultado de uma instalação: quantas foram instaladas e o que deu errado. Ok = instaladas sem
    problema, Warned = instaladas com erros, Failed = não instaladas.
    #>
    param (
        [int]$Ok,

        [int]$Warned,

        [int]$Failed
    )

    $total = $Ok + $Warned + $Failed
    $installed = $Ok + $Warned

    if ($installed -eq 0) {
        if ($total -eq 1) { return "a atualização não foi instalada" }

        return "nenhuma das $total atualizações foi instalada"
    }

    if ($Failed -eq 0 -and $Warned -eq 0) {
        return (Format-WinForgeCount -Count $Ok -One "atualização instalada" -Many "atualizações instaladas")
    }

    $text = "$installed de $total $(if ($installed -eq 1) { 'instalada' } else { 'instaladas' })"

    if ($Warned -gt 0) { $text += " ($Warned com erros)" }
    if ($Failed -eq 1) { $text += "; 1 falhou" }
    elseif ($Failed -gt 1) { $text += "; $Failed falharam" }

    return $text
}


function Get-WinForgeUpdateTitleById {
    # O título da atualização com o Id dado, na lista que a pessoa viu; sem ela, o próprio Id.
    param (
        [object[]]$Updates,

        [Parameter(Mandatory)]
        [string]$Id
    )

    $match = @($Updates | Where-Object { $_.Id -eq $Id }) | Select-Object -First 1

    if ($null -ne $match -and -not [string]::IsNullOrWhiteSpace([string]$match.Title)) {
        return [string]$match.Title
    }

    return $Id
}


function Get-WinForgeUpdateSizeText {
    # O tamanho para a pessoa: o Windows informa o máximo que o download pode ter (MaxDownloadSize); com as atualizações
    # expressas ele costuma ser menor, por isso "até".
    param ([Parameter(Mandatory)]$Update)

    if ($Update.Downloaded) { return "já baixada" }
    if ([int64]$Update.Size -gt 0) { return "até $(Format-WinForgeBytes -Bytes ([int64]$Update.Size))" }

    return "tamanho não informado"
}


function Get-WinForgeDriverClassText {
    # A classe do driver no Windows Update (a classe de instalação do aparelho) com o nome que a pessoa conhece. Uma classe
    # sem tradução aqui aparece como veio; vazio sem classe.
    param ([string]$Class)

    switch -Regex (([string]$Class).Trim()) {
        '^Display$' { return "vídeo" }
        '^Net$' { return "rede" }
        '^Bluetooth$' { return "Bluetooth" }
        '^(MEDIA|AudioEndpoint|AudioProcessingObject)$' { return "som" }
        '^(Camera|Image)$' { return "câmera" }
        '^USB$' { return "USB" }
        '^(HIDClass|Keyboard|Mouse)$' { return "teclado, mouse ou touchpad" }
        '^System$' { return "sistema" }
        '^Firmware$' { return "firmware (como a BIOS)" }
        '^(Printer|PrintQueue)$' { return "impressora" }
        '^SoftwareComponent$' { return "programa de apoio do aparelho" }
        '^Extension$' { return "extensão de outro driver" }
        '^Biometric$' { return "biometria" }
        '^(SCSIAdapter|HDC|DiskDrive)$' { return "disco" }
        '^Monitor$' { return "monitor" }
        '^SecurityDevices$' { return "segurança (TPM)" }
        '^Sensor$' { return "sensores" }
        '^Battery$' { return "bateria" }
        '^$' { return "" }
    }

    return ([string]$Class).Trim()
}


function Get-WinForgeDriverPurposeText {
    <#
    Para que serve um driver da lista: "vídeo: Intel(R) UHD Graphics 620", só a classe ou só o aparelho; vazio sem nenhum
    dos dois. Prefix vai na frente quando há texto (" de " para "driver de vídeo: ...").
    #>
    param (
        [Parameter(Mandatory)]$Update,
        [string]$Prefix = ""
    )

    $class = Get-WinForgeDriverClassText -Class ([string](Get-WinForgeJsonValue -Object $Update -Name "DriverClass" -Default ""))
    $model = ([string](Get-WinForgeJsonValue -Object $Update -Name "DriverModel" -Default "")).Trim()

    if ($model.Length -gt 60) { $model = $model.Substring(0, 57) + "..." }

    $text = $(if ($class -and $model) { "${class}: $model" } elseif ($class) { $class } else { $model })

    return $(if ($text) { "$Prefix$text" } else { "" })
}


function Test-WinForgeFirmwareUpdate {
    # Se a atualização é de firmware (a BIOS/UEFI ou o de um componente): a que não pode ser interrompida de jeito nenhum.
    param ([Parameter(Mandatory)]$Update)

    return ([string](Get-WinForgeJsonValue -Object $Update -Name "DriverClass" -Default "")).Trim() -eq "Firmware"
}


function Write-WinForgeFirmwareWarning {
    # Um firmware entre as escolhidas: ele termina no reinício, e faltar energia no meio pode deixar o PC sem ligar.
    param ([AllowEmptyCollection()][object[]]$Updates = @())

    if (@($Updates | Where-Object { Test-WinForgeFirmwareUpdate -Update $_ }).Count -gt 0) {
        Write-WinForgeStatus -Type Warning -Message "Há uma atualização de firmware (como a BIOS): ela termina no reinício. Não desligue o PC e, num notebook, deixe-o na tomada."
    }
}


function Write-WinForgeMeteredWarning {
    # Numa conexão limitada (plano de dados), avisa antes de baixar: o próprio Windows não baixaria sozinho.
    param ([int64]$Bytes = 0)

    if (-not (Test-WinForgeMeteredConnection)) { return }

    $what = $(if ($Bytes -gt 0) { "baixar até $(Format-WinForgeBytes -Bytes $Bytes)" } else { "baixar as atualizações" })
    Write-WinForgeStatus -Type Warning -Message "A conexão com a internet está marcada como limitada (plano de dados): $what pode consumir a sua franquia."
}


function Get-WinForgeUpdateOptionLabel {
    param ([Parameter(Mandatory)]$Update)

    if ([string]::IsNullOrWhiteSpace($Update.Kb)) {
        return $Update.Title
    }

    if ($Update.Title -match "KB$([regex]::Escape($Update.Kb))") {
        return $Update.Title
    }

    return "$($Update.Title) (KB$($Update.Kb))"
}


function Get-WinForgeWindowsUpdatePolicy {
    <#
    O que as políticas do Windows dizem sobre o Windows Update. Server: o servidor da empresa (WSUS) de onde as
    atualizações vêm, quando a política está ligada. Blocked: o acesso ao Windows Update desligado, por
    DisableWindowsUpdateAccess (nas duas chaves de política em que o Windows a lê) ou, sem servidor de empresa, por
    DoNotConnectToWindowsUpdateInternetLocations; as duas dão o erro 0x8024002E. Num PC de casa, quem costuma pôr essas
    políticas é um programa bloqueador de atualizações. Sem as chaves (o normal) ou sem leitura, nada.
    #>
    $key = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
    $server = ""
    $blocked = $false

    try {
        $values = Get-ItemProperty -LiteralPath $key -ErrorAction SilentlyContinue
        $au = Get-ItemProperty -LiteralPath "$key\AU" -ErrorAction SilentlyContinue

        if ([string](Get-WinForgeJsonValue -Object $au -Name "UseWUServer" -Default "0") -eq "1") {
            $server = ([string](Get-WinForgeJsonValue -Object $values -Name "WUServer" -Default "")).Trim()
        }

        $blocked = ([string](Get-WinForgeJsonValue -Object $values -Name "DisableWindowsUpdateAccess" -Default "0") -eq "1") -or
            (-not $server -and [string](Get-WinForgeJsonValue -Object $values -Name "DoNotConnectToWindowsUpdateInternetLocations" -Default "0") -eq "1")

        foreach ($other in @("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\WindowsUpdate", "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\WindowsUpdate")) {
            $value = Get-ItemProperty -LiteralPath $other -ErrorAction SilentlyContinue
            if ([string](Get-WinForgeJsonValue -Object $value -Name "DisableWindowsUpdateAccess" -Default "0") -eq "1") { $blocked = $true }
        }
    }
    catch {
        Write-Verbose "Políticas do Windows Update: $($_.Exception.Message)"
    }

    return [PSCustomObject]@{ Server = $server; Blocked = $blocked }
}


function Write-WinForgeWindowsUpdatePolicyNote {
    <#
    Quando uma política muda de onde vêm as atualizações, a tela diz isso: é a explicação mais provável de uma consulta
    que falha, e nenhum reparo do WinForge a muda. Devolve $true quando escreveu.
    #>
    $policy = Get-WinForgeWindowsUpdatePolicy
    $who = "Num PC de empresa, fale com o suporte de TI; num PC de casa, um programa bloqueador de atualizações costuma fazer isso: desfaça a configuração por ele."

    if ($policy.Blocked) {
        Write-WinForgeStatus -Type Info -Message "Uma política do Windows desliga o acesso ao Windows Update neste PC. $who"
        return $true
    }

    if ($policy.Server) {
        Write-WinForgeStatus -Type Info -Message "Uma política do Windows manda buscar as atualizações num servidor da empresa ($($policy.Server)), e não no Windows Update. $who"
        return $true
    }

    return $false
}


function Write-WinForgeWindowsUpdateSearchHelp {
    <#
    O que fazer quando a consulta ao Windows Update falha, depois do motivo: a política que muda de onde vêm as
    atualizações, quando há uma; senão, se o motivo não é a conexão nem já diz o caminho, o reparo do Windows Update.
    #>
    param ([string]$Problem)

    if (Write-WinForgeWindowsUpdatePolicyNote) { return }
    if ($Problem -match 'Corrigir o Windows Update|Reparo >|internet|conectar|conexão|servidor|proxy|firewall|política|espaço') { return }

    # O reparo refaz o cache de atualizações e religa os serviços.
    Write-WinForgeStatus -Type Info -Message "Se o erro se repetir, use Atualizações > Corrigir o Windows Update."
}


# ---------------------------------------------------------------------------
# Acompanhamento
# ---------------------------------------------------------------------------

function Wait-WinForgeUpdateJob {
    <#
    Espera o trabalho do outro runspace mostrando o andamento na barra de progresso. Devolve $true se terminou e $false
    se o tempo esgotou. A espera é em fatias de um segundo, então o botão Parar continua valendo; ao ser interrompida, o
    chamador cuida de parar o runspace (o serviço do Windows Update pode continuar a instalar por conta própria).
    #>
    param (
        [Parameter(Mandatory)]
        $Handle,

        [Parameter(Mandatory)]
        $State,

        [int]$TimeoutMinutes = 180
    )

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $lastKey = ""

    while (-not $Handle.AsyncWaitHandle.WaitOne(1000)) {
        if ($stopwatch.Elapsed.TotalMinutes -ge $TimeoutMinutes) {
            return $false
        }

        $key = "$($State.Phase)|$($State.Index)|$($State.Percent)|$($State.Current)"

        if ($key -eq $lastKey) { continue }

        $lastKey = $key

        if ($State.Phase -in "Baixando", "Instalando") {
            $activity = $(if ($State.Phase -eq "Baixando") { "Baixando as atualizações" } else { "Instalando as atualizações" })
            $status = "$($State.Index) de $($State.Total)"

            if (-not [string]::IsNullOrWhiteSpace([string]$State.Current)) { $status += ": $($State.Current)" }

            Write-Progress -Activity $activity -Status $status -PercentComplete ([math]::Max(0, [math]::Min(100, [int]$State.Percent)))
        }
        else {
            # Antes de baixar, o Windows Update confere de novo as escolhidas, o que pode demorar.
            Write-Progress -Activity "Preparando a instalação" -Status "o Windows Update confere as atualizações escolhidas"
        }
    }

    return $true
}


function Invoke-WinForgeUpdateInstall {
    <#
    Baixa e instala as atualizações com os Ids dados, no outro runspace, acompanhando o progresso na tela. Devolve o
    estado final: Done, Error, Results (Title, Code, HResult), RebootRequired, TimedOut, Missing (Ids que o Windows
    deixou de oferecer) e NotDownloaded (Ids que não foram baixados).
    #>
    param (
        [Parameter(Mandatory)]
        [string[]]$Ids,

        [string]$FactoryCode = (Get-WinForgeUpdateComFactoryCode),

        [int]$TimeoutMinutes = 180,

        [string]$Criteria = ""
    )

    $state = [hashtable]::Synchronized(@{
            Phase          = "Preparando"
            Percent        = 0
            Index          = 0
            Total          = 0
            Current        = ""
            Error          = ""
            ErrorHResult   = 0
            DownloadCode   = 0
            DownloadHResult = 0
            Done           = $false
            RebootRequired = $false
            Results        = (New-Object System.Collections.ArrayList)
            Missing        = (New-Object System.Collections.ArrayList)
            NotDownloaded  = (New-Object System.Collections.ArrayList)
        })

    $shell = [powershell]::Create()
    $finished = $false
    $timedOut = $false

    try {
        [void]$shell.AddScript((Get-WinForgeUpdateInstallScript))
        [void]$shell.AddArgument($state)
        [void]$shell.AddArgument($Ids)
        [void]$shell.AddArgument($FactoryCode)
        [void]$shell.AddArgument($Criteria)

        $handle = $shell.BeginInvoke()

        if (Wait-WinForgeUpdateJob -Handle $handle -State $state -TimeoutMinutes $TimeoutMinutes) {
            $finished = $true
            [void]$shell.EndInvoke($handle)
        }
        else {
            $timedOut = $true
        }
    }
    finally {
        Write-Progress -Activity "Instalando as atualizações" -Completed

        if ($finished) {
            $shell.Dispose()
        }
        else {
            # Interrompido ou sem resposta: pede para parar sem esperar uma chamada COM presa.
            try { [void]$shell.BeginStop($null, $null) } catch { }
        }
    }

    # O texto do erro passa pela mesma tradução da consulta: sem o embrulho do PowerShell, com a frase de um código
    # conhecido e sempre com o código. O download que falhou inteiro só deixa os códigos no estado (DownloadCode
    # diferente de zero).
    $errorText = [string]$state.Error
    if (-not [string]::IsNullOrWhiteSpace($errorText)) { $errorText = Get-WinForgeWindowsUpdateProblem -Message $errorText -HResult ([int]$state.ErrorHResult) }
    if ([int]$state.DownloadCode -ne 0) { $errorText = Get-WinForgeUpdateDownloadError -Code ([int]$state.DownloadCode) -HResult ([int]$state.DownloadHResult) }

    return [PSCustomObject]@{
        Done           = [bool]$state.Done
        Error          = $errorText
        Results        = @($state.Results)
        RebootRequired = [bool]$state.RebootRequired
        TimedOut       = $timedOut
        Missing        = @($state.Missing)
        NotDownloaded  = @($state.NotDownloaded)
    }
}


# ---------------------------------------------------------------------------
# Ação
# ---------------------------------------------------------------------------

function Get-WinForgeUpdateSupportStatus {
    <#
    Até quando este Windows recebe atualizações de segurança (Get-WinForgeWindowsSupportStatus), para a tela não dizer
    "em dia" a um Windows sem suporte: a versão nova do Windows é opcional no Windows Update e não entra na lista. $null
    quando não foi possível saber.
    #>
    try {
        return (Get-WinForgeWindowsSupportStatus)
    }
    catch {
        Write-Verbose "Suporte do Windows: $($_.Exception.Message)"
        return $null
    }
}


function Test-WinForgeWindowsSupportEnded {
    # Verdadeiro quando este Windows não recebe mais atualizações de segurança: fora do suporte, ou só com o ESU, que
    # deu para conferir e não está instalado.
    param ($Status)

    if ($null -eq $Status) { return $false }

    $state = [string](Get-WinForgeJsonValue -Object $Status -Name "State" -Default "")

    return ($state -eq "Ended" -or ($state -eq "EsuAvailable" -and [bool](Get-WinForgeJsonValue -Object $Status -Name "EsuChecked" -Default $false)))
}


function Get-WinForgeSupportEndedText {
    # "o Windows 11 24H2 não recebe mais atualizações de segurança desde 13/10/2026" (sem a data quando ela não é conhecida).
    param ([Parameter(Mandatory)]$Status)

    $product = [string](Get-WinForgeJsonValue -Object $Status -Name "Product" -Default "")
    if ([string]::IsNullOrWhiteSpace($product)) { $product = "Windows" }

    $text = "o $product não recebe mais atualizações de segurança"
    $end = Get-WinForgeJsonValue -Object $Status -Name "EndDate" -Default $null

    if ($end -is [datetime]) { $text += " desde $(Format-WinForgeDateTime -When $end -Pattern 'dd/MM/yyyy')" }

    return $text
}


function Write-WinForgeUpdateSupportNote {
    <#
    O que a tela de atualizações diz sobre o suporte do Windows. Sem suporte: um aviso (com -NothingPending, no lugar do
    "em dia"), o que fazer e onde ver os detalhes. Perto do fim (ou sem conseguir conferir o ESU): uma linha de informação.
    Devolve $true quando o Windows está sem suporte.
    #>
    param (
        $Status,
        [switch]$NothingPending
    )

    if ($null -eq $Status) { return $false }

    $state = [string](Get-WinForgeJsonValue -Object $Status -Name "State" -Default "")

    if (Test-WinForgeWindowsSupportEnded -Status $Status) {
        $ended = Get-WinForgeSupportEndedText -Status $Status

        if ($NothingPending) {
            Write-WinForgeStatus -Type Warning -Message "Não há atualizações pendentes, mas $ended."
        }
        else {
            Write-WinForgeStatus -Type Warning -Notice -Message "$($ended.Substring(0, 1).ToUpperInvariant())$($ended.Substring(1)): instalar as pendentes não muda isso."
        }

        $advice = [string](Get-WinForgeJsonValue -Object $Status -Name "Advice" -Default "")
        if ($advice) { Write-WinForgeStatus -Type Info -Message $advice }

        # A edição de longo prazo (LTSC) não recebe a versão nova pelo Windows Update.
        if ([string](Get-WinForgeJsonValue -Object $Status -Name "Class" -Default "") -ne "Ltsc") {
            Write-WinForgeStatus -Type Info -Message "Quando houver uma versão nova para este PC, ela aparece em Atualizações > Windows Update, no botão Baixar e instalar."
        }

        Write-WinForgeStatus -Type Info -Message "Detalhes em Diagnóstico > Suporte do Windows."
        return $true
    }

    if ($state -in @("EndingSoon", "EsuAvailable")) {
        $text = ([string](Get-WinForgeJsonValue -Object $Status -Name "Text" -Default "")).Trim()
        if ($text) { Write-WinForgeStatus -Type Info -Message "$text Veja Diagnóstico > Suporte do Windows." }
    }

    return $false
}


function Request-WinForgeRestartOffer {
    <#
    Oferece reiniciar ali mesmo (Request-WinForgeRestart, com Não como padrão), quando a tela pede um reinício. Um
    problema ao pedir o reinício não muda o resultado da ação: a tela só diz para reiniciar depois (Fallback).
    #>
    param (
        [Parameter(Mandatory)][string]$Reason,
        [Parameter(Mandatory)][string]$Comment,
        [Parameter(Mandatory)][string]$DeclinedMessage,
        [string]$Fallback = "Reinicie o PC quando puder."
    )

    try {
        [void](Request-WinForgeRestart -Reason $Reason -Comment $Comment -DeclinedMessage $DeclinedMessage)
    }
    catch {
        Write-Verbose "Oferta de reinício: $($_.Exception.Message)"
        Write-WinForgeStatus -Type Info -Message $Fallback
    }
}


function Request-WinForgeInstallRestart {
    # O reinício que conclui uma instalação (atualizações, drivers). What: o que falta terminar ("as atualizações");
    # Later: a frase de quem não reiniciou agora.
    param (
        [Parameter(Mandatory)][string]$What,
        [Parameter(Mandatory)][string]$Later
    )

    Request-WinForgeRestartOffer -Reason "Para terminar de instalar $What, o Windows precisa reiniciar." `
        -Comment "Reinicialização solicitada pelo WinForge para terminar de instalar $What." `
        -DeclinedMessage "Reinicialização não iniciada. $Later" `
        -Fallback "Reinicie o PC para terminar a instalação."
}


function Confirm-WinForgeUpdateConditions {
    <#
    Antes de procurar o que instalar pelo Windows Update (atualizações ou drivers): com um reinício pendente ou o
    notebook na bateria, a tela diz por que isso importa (Reboot, Battery) e pergunta, com Não como padrão. $true para
    seguir; $false quando a pessoa desistiu, com o que fazer já escrito. Quem não quis seguir sem reiniciar pode reiniciar
    dali mesmo (Request-WinForgeRestart, com Não como padrão); Retry é o item para abrir de novo depois.
    #>
    param (
        [Parameter(Mandatory)][string]$Reboot,
        [Parameter(Mandatory)][string]$Battery,
        [string]$Retry = "Atualizações > Instalar atualizações do Windows"
    )

    if (Test-WinForgePendingReboot) {
        Write-WinForgeStatus -Type Warning -Message "Há um reinício pendente. $Reboot"

        if (-not (Confirm-WinForgeAction -Message "Continuar sem reiniciar?" -DefaultKey "N")) {
            Write-WinForgeStatus -Type Warning -Message "Operação cancelada."
            Request-WinForgeRestartOffer -Reason "Reinicie agora e, depois, abra $Retry de novo." `
                -Comment "Reinicialização solicitada pelo WinForge (reinício pendente antes de atualizar)." `
                -DeclinedMessage "Reinicialização não iniciada. Reinicie o PC e tente de novo." `
                -Fallback "Reinicie o PC e tente de novo."
            return $false
        }
    }

    if (Test-WinForgeOnBattery) {
        Write-WinForgeStatus -Type Warning -Message "O notebook está na bateria. $Battery"

        if (-not (Confirm-WinForgeAction -Message "Instalar mesmo assim?" -DefaultKey "N")) {
            Write-WinForgeStatus -Type Warning -Message "Operação cancelada."
            Write-WinForgeStatus -Type Info -Message "Ligue o carregador e tente de novo."
            return $false
        }
    }

    return $true
}


function Get-WinForgeUpdateRunResult {
    <#
    O desfecho de uma instalação do Windows Update (Invoke-WinForgeUpdateInstall): a tabela com cada atualização, a
    anotação no Histórico de mudanças e o WinForge.Result, com Data.RebootRequired quando alguma instalada pede o
    reinício. Chosen: as atualizações que a pessoa viu (para dar nome às que não chegaram a ser instaladas).
    #>
    param (
        [Parameter(Mandatory)]$Run,
        [AllowEmptyCollection()][object[]]$Chosen = @(),
        [string]$Title = "",
        [string]$SectionTitle = "Resumo"
    )

    $chosen = @($Chosen)
    $final = $null

    if ($run.TimedOut) {
        Write-WinForgeStatus -Type Warning -Message "O WinForge parou de acompanhar depois de muito tempo. O Windows pode continuar instalando: veja o andamento em Atualizações > Windows Update."
        $final = New-WinForgeResult -Kind Warning -Detail "tempo esgotado; a instalação pode continuar" -Title $Title
    }
    elseif (-not [string]::IsNullOrWhiteSpace($run.Error) -and $run.Results.Count -eq 0) {
        Write-WinForgeStatus -Type Error -Message "Não foi possível instalar as atualizações: $($run.Error.TrimEnd('.'))."
        $final = New-WinForgeResult -Kind Failed -Detail $run.Error -Title $Title
    }
    else {
        $results = @()

        foreach ($item in $run.Results) {
            $outcome = Get-WinForgeUpdateOutcome -Code $item.Code -HResult $item.HResult
            $outcome.Etapa = $item.Title
            $results += $outcome
        }

        # As escolhidas que não chegaram a ser instaladas também entram no resumo, com o nome que a pessoa viu.
        foreach ($id in @($run.NotDownloaded)) {
            $outcome = New-WinForgeResult -Kind Failed -Detail "não foi baixada"
            $outcome.Etapa = Get-WinForgeUpdateTitleById -Updates $chosen -Id $id
            $results += $outcome
        }

        foreach ($id in @($run.Missing)) {
            $outcome = New-WinForgeResult -Kind Failed -Detail "não está mais disponível"
            $outcome.Etapa = Get-WinForgeUpdateTitleById -Updates $chosen -Id $id
            $results += $outcome
        }

        Write-WinForgeSection -Title $SectionTitle
        Write-WinForgeResultTable -Results $results

        $failed = @($results | Where-Object { $_.Kind -eq "Failed" })
        $warned = @($results | Where-Object { $_.Kind -eq "Warning" })

        # O Histórico de mudanças anota o que foi instalado, pelo número KB quando houver (os títulos são longos).
        $installedNames = @(
            foreach ($item in @($run.Results)) {
                if ([int]$item.Code -notin 2, 3) { continue }
                $match = @($chosen | Where-Object { [string]$_.Title -eq [string]$item.Title }) | Select-Object -First 1
                if ($null -ne $match -and $match.Kb) { "KB$($match.Kb)" } else { [string]$item.Title }
            }
        )

        if ($installedNames.Count -gt 0) {
            [void](Add-WinForgeChange -Action "Atualizações do Windows" -Text "$(Format-WinForgeCount -Count $installedNames.Count -One 'instalada' -Many 'instaladas'): $(Join-WinForgeList -Items $installedNames)")
        }

        # "Reinicie para concluir" só faz sentido se alguma foi instalada; sem nenhuma, o motivo de cada uma diz o que fazer.
        $reboot = [bool]$run.RebootRequired -and $failed.Count -lt $results.Count

        $detail = Get-WinForgeUpdateRunDetail -Ok ($results.Count - $failed.Count - $warned.Count) -Warned $warned.Count -Failed $failed.Count

        # As contas e os motivos, para a faixa da janela (Set-WinForgeInstallView).
        $data = @{
            RebootRequired = $reboot
            Installed      = ($results.Count - $failed.Count)
            Failed         = $failed.Count
            Warned         = $warned.Count
            Problems       = @(@($failed) + @($warned) | ForEach-Object { [string]$_.Detail } | Where-Object { $_ })
        }

        # Um erro depois de algumas atualizações já terem resultado (por exemplo, ao ler o resultado das outras) deixa o
        # resumo incompleto: ele não pode sumir nem terminar como "Tudo certo".
        $cutShort = -not [string]::IsNullOrWhiteSpace($run.Error)

        if ($cutShort) {
            Write-WinForgeStatus -Type Error -Message "A instalação foi interrompida por um erro: $($run.Error.TrimEnd('.'))."
            $detail = "$detail; erro durante a instalação: $($run.Error)"
        }

        if ($failed.Count -eq $results.Count) {
            $final = New-WinForgeResult -Kind Failed -Detail $detail -Title $Title -Data $data
        }
        elseif ($failed.Count -gt 0 -or $warned.Count -gt 0 -or $cutShort) {
            $final = New-WinForgeResult -Kind Warning -Detail $detail -Title $Title -Data $data
        }
        else {
            $final = New-WinForgeResult -Kind Ok -Detail $detail -Title $Title -Data $data
        }
    }

    return $final
}


function Get-WinForgeUpdateFixStep {
    <#
    O item do WinForge que resolve um erro do Windows Update, para o botão da faixa: os motivos (Get-WinForgeWindowsUpdateHResultText)
    já dizem "use Atualizações > Corrigir o Windows Update" ou "use Reparo > Reparar o Windows (DISM + SFC)" quando é o
    caso. Next e Label vazios quando nenhum motivo aponta um item.
    #>
    param ([AllowEmptyCollection()][string[]]$Texts = @())

    $all = (@($Texts) | Where-Object { $_ }) -join " | "

    if ($all -match 'Corrigir o Windows Update') { return [PSCustomObject]@{ Next = "updates.repair"; Label = "Corrigir o Windows Update" } }
    if ($all -match 'Reparar o Windows \(DISM \+ SFC\)') { return [PSCustomObject]@{ Next = "repair.dism-sfc"; Label = "Reparar o Windows" } }

    return [PSCustomObject]@{ Next = ""; Label = "" }
}


function Set-WinForgeInstallView {
    <#
    A faixa de uma instalação pelo Windows Update (atualizações ou drivers, Get-WinForgeUpdateRunResult e a dos drivers):
    o título diz quantas foram instaladas; a frase, se falta reiniciar (ou como voltar atrás, nos drivers) ou que o motivo
    de cada falha está no resumo; e, quando um motivo aponta um item do WinForge, o botão para ele. Um, Many e None são
    os textos do que foi instalado ("atualização instalada", "atualizações", "Nenhuma atualização instalada"). OkNote: a
    frase de quando deu tudo certo sem reinício. Devolve o próprio resultado.
    #>
    param (
        [Parameter(Mandatory)]$Result,
        [Parameter(Mandatory)][string]$One,
        [Parameter(Mandatory)][string]$Many,
        [Parameter(Mandatory)][string]$Noun,
        [Parameter(Mandatory)][string]$None,
        [string]$OkNote = "Não precisa reiniciar.",
        [string]$Each = "cada uma",
        [string]$DoneMany = "instaladas"
    )

    $installed = Get-WinForgeResultData -Result $Result -Name "Installed"
    if ($null -eq $installed) { return $Result }

    $installed = [int]$installed
    $failed = [int](Get-WinForgeResultData -Result $Result -Name "Failed")
    $warned = [int](Get-WinForgeResultData -Result $Result -Name "Warned")
    $total = $installed + $failed
    $reboot = Test-WinForgeResultFlag -Result $Result -Name "RebootRequired"
    $fix = Get-WinForgeUpdateFixStep -Texts @(Get-WinForgeResultData -Result $Result -Name "Problems")

    if ($Result.Kind -eq "Ok") {
        return (Set-WinForgeResultView -Result $Result -Headline (Format-WinForgeCount -Count $installed -One $One -Many "$Many") `
                -Note $(if ($reboot) { "Reinicie o PC para terminar a instalação." } else { $OkNote }))
    }

    # O que deu errado, em números: o motivo de cada um fica no resumo, na linha dele.
    $parts = @()
    if ($failed -gt 0) { $parts += $(if ($failed -eq 1) { "1 falhou" } else { "$failed falharam" }) }
    if ($warned -gt 0) { $parts += "$warned com erros" }
    $reason = $(if ($total -eq 1 -or ($failed + $warned) -eq 1) { "o motivo está no resumo" } else { "o motivo de $Each está no resumo" })

    if ($Result.Kind -eq "Failed") {
        return (Set-WinForgeResultView -Result $Result -Headline $None -Note "$($reason.Substring(0, 1).ToUpper())$($reason.Substring(1))." -Next $fix.Next -NextLabel $fix.Label)
    }

    if ($Result.Kind -eq "Warning" -and $total -gt 0) {
        return (Set-WinForgeResultView -Result $Result -Headline "$installed de $total $Noun $DoneMany" `
                -Note "$($parts -join ' e '); $reason." -Next $fix.Next -NextLabel $fix.Label)
    }

    return $Result
}


function Set-WinForgeInstallErrorView {
    # A instalação que nem chegou a dar resultado (o Windows Update recusou antes, sem as contas de Set-WinForgeInstallView):
    # o título diz que não foi possível instalar, a frase traz o motivo e, quando ele aponta um item, o botão. Devolve o
    # próprio resultado.
    param ([Parameter(Mandatory)]$Result)

    $why = ([string]$Result.Detail).Trim().TrimEnd(".")

    if ($Result.Kind -ne "Failed" -or -not $why -or $null -ne (Get-WinForgeResultData -Result $Result -Name "Installed")) { return $Result }

    $fix = Get-WinForgeUpdateFixStep -Texts @($why)

    return (Set-WinForgeResultView -Result $Result -Headline "Não foi possível instalar" -Note ($why.Substring(0, 1).ToUpper() + $why.Substring(1) + ".") -Next $fix.Next -NextLabel $fix.Label)
}


function Set-WinForgeUpdateSearchView {
    # A faixa de quando o Windows Update não respondeu à consulta: o título diz isso, a frase traz o motivo e, quando ele
    # aponta um item do WinForge, o botão. Devolve o próprio resultado.
    param (
        [Parameter(Mandatory)]$Result,
        [string]$Problem = ""
    )

    $text = ([string]$Problem).Trim().TrimEnd(".")
    $note = $(if ($text) { $text.Substring(0, 1).ToUpper() + $text.Substring(1) + "." } else { "" })
    $fix = Get-WinForgeUpdateFixStep -Texts @($text)

    return (Set-WinForgeResultView -Result $Result -Headline "O Windows Update não respondeu" -Note $note -Next $fix.Next -NextLabel $fix.Label)
}


function Install-WinForgeWindowsUpdates {
    $title = "Instalar atualizações do Windows"

    Enter-WinForgeAction -Title $title

    $final = New-WinForgeResult -Kind Ok -Title $title

    try {
        if (-not (Test-WinForgeElevation -Reason "Instalar atualizações do Windows exige privilégios de Administrador.")) {
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Failed -Detail "requer Administrador" -Title $title)
            return
        }

        if (-not (Confirm-WinForgeUpdateConditions -Reboot "Reiniciar antes evita que as novas atualizações falhem." -Battery "Atualizar gasta bastante energia e não deve ser interrompido.")) {
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Skipped -Detail "cancelado pelo usuário" -Title $title)
            return
        }

        # O andamento vai para a barra de progresso: uma linha "procurando..." ficaria no resumo depois do fim.
        Write-Progress -Activity "Procurando atualizações" -Status "o Windows Update pode levar alguns minutos para responder"

        try {
            $search = Find-WinForgeWindowsUpdates
        }
        finally {
            Write-Progress -Activity "Procurando atualizações" -Completed
        }

        if ($null -eq $search.Updates) {
            Write-WinForgeStatus -Type Error -Message "Não foi possível consultar o Windows Update: $($search.Problem)."
            Write-WinForgeWindowsUpdateSearchHelp -Problem $search.Problem
            Exit-WinForgeAction -Result (Set-WinForgeUpdateSearchView -Result (New-WinForgeResult -Kind Failed -Detail "não foi possível consultar o Windows Update: $($search.Problem)" -Title $title) -Problem $search.Problem)
            return
        }

        $updates = @($search.Updates)

        # A versão nova do Windows é opcional e não entra na lista: num Windows sem suporte, "em dia" seria falso.
        $support = Get-WinForgeUpdateSupportStatus

        if ($updates.Count -eq 0) {
            if (Test-WinForgeWindowsSupportEnded -Status $support) {
                [void](Write-WinForgeUpdateSupportNote -Status $support -NothingPending)
                $ended = New-WinForgeResult -Kind Warning -Detail "nada pendente, mas este Windows não recebe mais atualizações de segurança" -Title $title
                Exit-WinForgeAction -Result (Set-WinForgeResultView -Result $ended -Headline "Este Windows não recebe mais atualizações" `
                        -Note "Não há nada pendente, mas o suporte deste Windows terminou." -Next "diagnostics.windows-support" -NextLabel "Ver o suporte do Windows")
                return
            }

            Write-WinForgeStatus -Type Success -Message "O Windows está em dia: não há atualizações pendentes."
            [void](Write-WinForgeUpdateSupportNote -Status $support)
            Write-WinForgeStatus -Type Info -Message "Drivers ficam em Atualizações > Atualizar drivers."
            Exit-WinForgeAction -Result (Set-WinForgeResultView -Result (New-WinForgeResult -Kind Ok -Detail "o Windows está em dia" -Title $title) -Headline "O Windows está em dia" -Note "Não há atualizações pendentes.")
            return
        }

        [void](Write-WinForgeUpdateSupportNote -Status $support)

        # As opcionais (BrowseOnly: prévias e drivers opcionais) só aparecem quando o Windows Update não conhece o critério
        # que as deixa de fora; o Windows não as instala sozinho, então elas vêm desmarcadas e com o aviso.
        $options = @(
            foreach ($update in $updates) {
                $optional = [bool](Get-WinForgeJsonValue -Object $update -Name "BrowseOnly" -Default $false)
                $parts = @()
                if ($optional) { $parts += "opcional" }
                if ([bool](Get-WinForgeJsonValue -Object $update -Name "Driver" -Default $false)) { $parts += "driver$(Get-WinForgeDriverPurposeText -Update $update -Prefix ' de ')" }
                $parts += Get-WinForgeUpdateSizeText -Update $update
                @{ Key = $update.Id; Label = (Get-WinForgeUpdateOptionLabel -Update $update); Description = ($parts -join " · "); Selected = (-not $optional) }
            }
        )

        if (@($updates | Where-Object { [bool](Get-WinForgeJsonValue -Object $_ -Name "BrowseOnly" -Default $false) }).Count -gt 0) {
            Write-WinForgeStatus -Type Info -Message "As opcionais (prévias e drivers opcionais) vêm desmarcadas."
        }

        # Na janela, Confirmar só fica disponível com algo marcado: voltar sem escolha é o Cancelar.
        $picked = Read-WinForgeMultiSelect -Message "Quais atualizações instalar?" -Options $options

        if ($null -eq $picked -or @($picked).Count -eq 0) {
            Write-WinForgeStatus -Type Warning -Message "Operação cancelada."
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Skipped -Detail "cancelado pelo usuário" -Title $title)
            return
        }

        $chosen = @($updates | Where-Object { @($picked) -contains $_.Id })
        $download = [int64]0

        foreach ($pending in @($chosen | Where-Object { -not $_.Downloaded })) {
            $download += [int64]$pending.Size
        }

        $countText = Format-WinForgeCount -Count $chosen.Count -One "atualização" -Many "atualizações"
        $needsDownload = @($chosen | Where-Object { -not $_.Downloaded }).Count -gt 0

        Write-WinForgeKeyValue -Label "Atualizações escolhidas" -Value $chosen.Count
        Write-WinForgeKeyValue -Label "A baixar" -Value $(if (-not $needsDownload) { "nada (já estão baixadas)" } elseif ($download -gt 0) { "até $(Format-WinForgeBytes -Bytes $download)" } else { "tamanho não informado" })
        Write-WinForgeFirmwareWarning -Updates $chosen
        if ($needsDownload) { Write-WinForgeMeteredWarning -Bytes $download }
        # Parado no meio, o Windows pode continuar instalando por conta própria.
        Write-WinForgeStatus -Type Info -Message "Não desligue o PC durante a instalação."
        Write-Host ""

        $question = $(if ($needsDownload) { "Baixar e instalar ${countText}?" } else { "Instalar ${countText}?" })

        if (-not (Confirm-WinForgeAction -Message $question -DefaultKey "S")) {
            Write-WinForgeStatus -Type Warning -Message "Operação cancelada."
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Skipped -Detail "cancelado pelo usuário" -Title $title)
            return
        }

        $keepAwake = Set-WinForgeKeepAwake -Enabled $true

        try {
            $run = Invoke-WinForgeUpdateInstall -Ids @($chosen | ForEach-Object { $_.Id })
        }
        finally {
            if ($keepAwake) {
                [void](Set-WinForgeKeepAwake -Enabled $false)
            }
        }

        Write-Host ""

        $final = Get-WinForgeUpdateRunResult -Run $run -Chosen $chosen -Title $title
        [void](Set-WinForgeInstallView -Result $final -One "atualização instalada" -Many "atualizações instaladas" -Noun "atualizações" `
                -None $(if ($chosen.Count -eq 1) { "A atualização não foi instalada" } else { "Nenhuma atualização instalada" }))

        [void](Set-WinForgeInstallErrorView -Result $final)

        if (Test-WinForgeResultFlag -Result $final -Name "RebootRequired") {
            Request-WinForgeInstallRestart -What "as atualizações" -Later "As atualizações terminam de instalar quando você reiniciar o PC."
        }
    }
    catch {
        $problem = Get-WinForgeWindowsUpdateProblem -Message $_.Exception.Message -HResult $_.Exception.HResult
        Write-WinForgeStatus -Type Error -Message "Não foi possível instalar as atualizações: $problem."
        $final = New-WinForgeResult -Kind Failed -Detail $problem -Title $title
    }

    Exit-WinForgeAction -Result $final
}


function Get-WinForgeAllUpdatesCriteria {
    # A busca do Otimizar: tudo o que não está instalado nem escondido, inclusive as opcionais (BrowseOnly: prévias e
    # drivers opcionais), que a busca padrão deixa de fora.
    return "IsInstalled=0 and IsHidden=0"
}


function Install-WinForgePendingUpdates {
    <#
    A etapa do Windows Update do Otimizar: procura e instala, sem perguntar, as atualizações que o Windows Update oferece e
    os drivers opcionais. Ficam de fora uma versão nova do Windows (troca o Windows inteiro e leva horas), um firmware
    opcional (como a BIOS: só com o Windows pedindo) e as prévias (as opcionais que não são drivers: as atualizações antes
    da hora, que o Otimizar desliga; o que elas trazem chega na atualização normal do mês seguinte). O reinício fica para
    o fim do Otimizar (Data.RebootRequired).
    #>
    param (
        [switch]$Embedded,
        [switch]$PassThru
    )

    $title = "Atualizar o Windows"

    Enter-WinForgeAction -Title $title -Embedded:$Embedded

    $final = $null

    try {
        Write-Progress -Activity "Procurando atualizações" -Status "o Windows Update pode levar alguns minutos para responder"

        try {
            # Sem ninguém esperando (a parte automática do Otimizar), a busca tem mais tempo: a primeira num PC que passou
            # meses sem atualizar pode levar mais de 5 minutos. O Parar continua funcionando durante a espera.
            $search = Find-WinForgeWindowsUpdates -Criteria (Get-WinForgeAllUpdatesCriteria) -TimeoutSeconds $(if ($Embedded) { 1200 } else { 300 })
        }
        finally {
            Write-Progress -Activity "Procurando atualizações" -Completed
        }

        if ($null -eq $search.Updates) {
            Write-WinForgeStatus -Type Error -Message "Não foi possível consultar o Windows Update: $($search.Problem)."
            Write-WinForgeWindowsUpdateSearchHelp -Problem $search.Problem
            $final = New-WinForgeResult -Kind Failed -Detail "não foi possível consultar o Windows Update: $($search.Problem)" -Title $title
        }
        else {
            $updates = @($search.Updates)
            $upgrades = @($updates | Where-Object { [bool](Get-WinForgeJsonValue -Object $_ -Name "Upgrade" -Default $false) })
            $firmware = @($updates | Where-Object { -not [bool](Get-WinForgeJsonValue -Object $_ -Name "Upgrade" -Default $false) -and [bool](Get-WinForgeJsonValue -Object $_ -Name "BrowseOnly" -Default $false) -and (Test-WinForgeFirmwareUpdate -Update $_) })
            $previews = @($updates | Where-Object { -not [bool](Get-WinForgeJsonValue -Object $_ -Name "Upgrade" -Default $false) -and [bool](Get-WinForgeJsonValue -Object $_ -Name "BrowseOnly" -Default $false) -and -not [bool](Get-WinForgeJsonValue -Object $_ -Name "Driver" -Default $false) })
            $left = @(@($upgrades) + @($firmware) + @($previews) | ForEach-Object { [string]$_.Id })
            $chosen = @($updates | Where-Object { $left -notcontains [string]$_.Id })

            # O que fica de fora, numa linha só (o porquê de cada um está no comentário da função).
            $leftNames = @(
                @($upgrades | ForEach-Object { "$($_.Title) (versão nova do Windows)" })
                @($firmware | ForEach-Object { "$($_.Title) (firmware opcional)" })
                @($previews | ForEach-Object { "$(Get-WinForgeUpdateOptionLabel -Update $_) (prévia)" })
            )

            if ($leftNames.Count -gt 0) {
                Write-WinForgeStatus -Type Info -Message "$(if ($leftNames.Count -eq 1) { 'Ficou' } else { 'Ficaram' }) de fora: $(Join-WinForgeList -Items $leftNames)."
            }

            $support = Get-WinForgeUpdateSupportStatus

            if ($chosen.Count -eq 0) {
                if (Test-WinForgeWindowsSupportEnded -Status $support) {
                    [void](Write-WinForgeUpdateSupportNote -Status $support -NothingPending)
                    $final = New-WinForgeResult -Kind Warning -Detail "nada pendente, mas este Windows não recebe mais atualizações de segurança" -Title $title
                }
                else {
                    Write-WinForgeStatus -Type Success -Message "O Windows está em dia: não há atualizações pendentes."
                    [void](Write-WinForgeUpdateSupportNote -Status $support)
                    $final = New-WinForgeResult -Kind Ok -Detail "o Windows está em dia" -Title $title
                }
            }
            else {
                [void](Write-WinForgeUpdateSupportNote -Status $support)

                $download = [int64]0
                foreach ($pending in @($chosen | Where-Object { -not $_.Downloaded })) { $download += [int64]$pending.Size }

                $optional = @($chosen | Where-Object { [bool](Get-WinForgeJsonValue -Object $_ -Name "BrowseOnly" -Default $false) }).Count
                $countText = Format-WinForgeCount -Count $chosen.Count -One "atualização" -Many "atualizações"
                if ($optional -gt 0) { $countText += " ($(Format-WinForgeCount -Count $optional -One 'opcional' -Many 'opcionais'))" }

                # Os nomes aparecem uma vez só, no fim, entre as instaladas.
                Write-WinForgeKeyValue -Label "A instalar" -Value $countText

                Write-WinForgeFirmwareWarning -Updates $chosen
                Write-WinForgeMeteredWarning -Bytes $download
                Write-Host ""

                $run = Invoke-WinForgeUpdateInstall -Ids @($chosen | ForEach-Object { $_.Id }) -Criteria (Get-WinForgeAllUpdatesCriteria)

                Write-Host ""
                $final = Get-WinForgeUpdateRunResult -Run $run -Chosen $chosen -Title $title -SectionTitle "Atualizações instaladas"
            }
        }
    }
    catch {
        $problem = Get-WinForgeWindowsUpdateProblem -Message $_.Exception.Message -HResult $_.Exception.HResult
        Write-WinForgeStatus -Type Error -Message "Não foi possível instalar as atualizações: $problem."
        $final = New-WinForgeResult -Kind Failed -Detail $problem -Title $title
    }

    if ($PassThru) { $final }
    Exit-WinForgeAction -Embedded:$Embedded -Result $final
}


# ---------------------------------------------------------------------------
# Corrigir o Windows Update
# ---------------------------------------------------------------------------

function Get-WinForgeWindowsUpdateServices {
    <#
    Os serviços de que o Windows Update depende, com o tipo de inicialização padrão do Windows. Stop: os que o reparo
    para e liga de novo (na ordem de parar); o orquestrador de atualizações só volta ao padrão se estiver desativado.
    #>
    return @(
        [PSCustomObject]@{ Name = "wuauserv"; Label = "Windows Update"; Default = "Manual"; Stop = $true },
        [PSCustomObject]@{ Name = "bits"; Label = "Serviço de Transferência Inteligente de Plano de Fundo (BITS)"; Default = "Manual"; Stop = $true },
        [PSCustomObject]@{ Name = "cryptsvc"; Label = "Serviços de Criptografia"; Default = "Automatic"; Stop = $true },
        [PSCustomObject]@{ Name = "UsoSvc"; Label = "Orquestrador de atualizações (UsoSvc)"; Default = "Automatic"; Stop = $false }
    )
}


function Get-WinForgeWindowsUpdateCacheFolders {
    <#
    As pastas que a Microsoft manda pôr de lado para o Windows Update refazer o cache (página de erros comuns do Windows
    Update): os downloads, o banco de dados e o catálogo de assinaturas. Keep: a cópia fica guardada (.bak); os downloads
    são só cache, e a cópia é apagada para não ficar ocupando o disco.
    #>
    $windows = [string]$env:SystemRoot
    if ([string]::IsNullOrWhiteSpace($windows)) { $windows = [string]$env:windir }
    if ([string]::IsNullOrWhiteSpace($windows)) { $windows = "C:\Windows" }

    return @(
        [PSCustomObject]@{ Name = "Download"; Label = "Downloads do Windows Update"; Path = (Join-Path $windows "SoftwareDistribution\Download"); Keep = $false },
        [PSCustomObject]@{ Name = "DataStore"; Label = "Banco de dados do Windows Update"; Path = (Join-Path $windows "SoftwareDistribution\DataStore"); Keep = $true },
        [PSCustomObject]@{ Name = "catroot2"; Label = "Catálogo de assinaturas do Windows"; Path = (Join-Path $windows "System32\catroot2"); Keep = $true }
    )
}


function Test-WinForgeWindowsUpdateBusy {
    <#
    Se o Windows Update está instalando alguma coisa agora (IUpdateInstaller.IsBusy). Parar os serviços no meio de uma
    instalação a interromperia. A pergunta vai ao serviço, que pode estar travado (é por isso que a pessoa veio): sem
    resposta em 15 segundos, ou sem leitura, $false.
    #>
    try {
        $run = Invoke-WinForgeInBackground -ScriptBlock { [bool](New-Object -ComObject "Microsoft.Update.Installer" -ErrorAction Stop).IsBusy } -TimeoutSeconds 15
        return ($run.Completed -and @($run.Output | Where-Object { $_ -eq $true }).Count -gt 0)
    }
    catch {
        return $false
    }
}


function Get-WinForgeServiceState {
    <#
    Situação, tipo de inicialização e dependentes ligados de um serviço. Missing: o serviço não existe (um script de
    "limpeza" pode tê-lo removido); $null quando o Windows não respondeu.
    #>
    param ([Parameter(Mandatory)][string]$Name)

    try {
        $service = Get-Service -Name $Name -ErrorAction Stop

        return [PSCustomObject]@{
            Name       = $Name
            Missing    = $false
            Status     = [string]$service.Status
            StartType  = [string]$service.StartType
            Dependents = @($service.DependentServices | Where-Object { [string]$_.Status -eq "Running" } | ForEach-Object { [string]$_.Name })
        }
    }
    catch {
        if ($_.CategoryInfo.Category -eq [System.Management.Automation.ErrorCategory]::ObjectNotFound) {
            return [PSCustomObject]@{ Name = $Name; Missing = $true; Status = ""; StartType = ""; Dependents = @() }
        }

        return $null
    }
}


function Stop-WinForgeService {
    <#
    Para o serviço (e os que dependem dele) e espera até TimeoutSeconds. $true quando parou. Um serviço "parando" ou
    "iniciando" recusa o pedido de parar: a espera continua e o pedido é repetido, em vez de virar erro; um serviço preso
    não segura a tela para sempre.
    #>
    param (
        [Parameter(Mandatory)][string]$Name,
        [int]$TimeoutSeconds = 30
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)

    while ($true) {
        $status = [string](Get-Service -Name $Name -ErrorAction Stop).Status

        if ($status -eq "Stopped") { return $true }

        if ($status -in @("Running", "Paused")) {
            try { Stop-Service -Name $Name -Force -NoWait -ErrorAction Stop } catch { Write-Verbose "Parar ${Name}: $($_.Exception.Message)" }
        }

        if ((Get-Date) -ge $deadline) { return $false }

        Start-Sleep -Milliseconds 500
    }
}


function Start-WinForgeService {
    param ([Parameter(Mandatory)][string]$Name)

    Start-Service -Name $Name -ErrorAction Stop
}


function Set-WinForgeServiceStartType {
    param (
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][ValidateSet("Manual", "Automatic")][string]$StartType
    )

    Set-Service -Name $Name -StartupType $StartType -ErrorAction Stop
}


function Move-WinForgeUpdateCacheFolder {
    <#
    Põe uma pasta do cache de lado (Nome.bak), apagando antes a cópia de uma vez anterior. Devolve um WinForge.Result:
    Ok (Data.Backup = o caminho da cópia), Skipped (a pasta não existe; ou, com Data.Linked, é atalho para outro lugar)
    ou Failed (em uso, sem permissão). Uma pasta que é atalho (junção, de um programa que mudou o cache de disco) fica
    como está: apagar por ela apagaria o que está do outro lado.
    #>
    param ([Parameter(Mandatory)]$Folder)

    $path = [string]$Folder.Path

    if (-not (Test-Path -LiteralPath $path)) { return (New-WinForgeResult -Kind Skipped -Detail "a pasta não existia") }

    try {
        $item = Get-Item -LiteralPath $path -Force -ErrorAction Stop

        if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            return (New-WinForgeResult -Kind Skipped -Detail "a pasta aponta para outro lugar e ficou como está" -Data @{ Linked = $true })
        }

        $backupName = "$($Folder.Name).bak"
        $backup = Join-Path (Split-Path -Parent $path) $backupName

        # A cópia de uma vez anterior sai; se ela não sair (em uso, ou é atalho), a nova ganha a data no nome.
        if (Test-Path -LiteralPath $backup) {
            [void](Remove-WinForgeUpdateCacheBackup -Path $backup)

            if (Test-Path -LiteralPath $backup) {
                $backupName = "$($Folder.Name).bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
                $backup = Join-Path (Split-Path -Parent $path) $backupName
            }
        }

        Rename-Item -LiteralPath $path -NewName $backupName -ErrorAction Stop
    }
    catch {
        $reason = $(if ($_.Exception -is [System.IO.IOException]) { "está em uso" } elseif ($_.Exception -is [System.UnauthorizedAccessException]) { "o Windows não deixou mexer" } else { $_.Exception.Message.TrimEnd(".") })
        return (New-WinForgeResult -Kind Failed -Detail "$reason; ficou como estava")
    }

    return (New-WinForgeResult -Kind Ok -Detail "guardado como $backupName" -Data @{ Backup = $backup })
}


function Remove-WinForgeUpdateCacheBackup {
    <#
    Apaga uma cópia posta de lado. Directory.Delete não entra em atalhos (junções) que estejam dentro dela, ao contrário
    de Remove-Item -Recurse no Windows PowerShell 5.1, que apagaria o que está do outro lado. Uma cópia que é ela mesma
    um atalho não é apagada. $true quando apagou.
    #>
    param ([Parameter(Mandatory)][string]$Path)

    try {
        $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop

        if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) { return $false }

        [System.IO.Directory]::Delete($item.FullName, $true)
        return $true
    }
    catch {
        Write-Verbose "Cópia $Path ficou: $($_.Exception.Message)"
        return $false
    }
}


function Get-WinForgeServiceNamesText {
    # "o serviço Windows Update" ou "os serviços Windows Update e BITS", com o verbo que vem depois concordando.
    param (
        [Parameter(Mandatory)][string[]]$Labels,
        [string]$One = "",
        [string]$Many = ""
    )

    $list = Join-WinForgeList -Items $Labels

    if ($Labels.Count -eq 1) { return ("o serviço $list $One").TrimEnd() }

    return ("os serviços $list $Many").TrimEnd()
}


function Repair-WinForgeWindowsUpdate {
    <#
    O reparo do Windows Update que a Microsoft indica quando as atualizações falham ou travam: para os serviços, põe de
    lado o cache (Get-WinForgeWindowsUpdateCacheFolders) e liga os serviços de novo. Um serviço desativado (por um
    "otimizador" ou bloqueador) volta antes para o tipo de inicialização padrão do Windows; se não voltar, nada mais é
    feito, porque o cache refeito não adiantaria. Políticas não são mudadas: a tela só diz quando há uma. Os serviços
    voltam a ligar mesmo se algo falhar no meio (finally), e os downloads postos de lado só são apagados depois disso.
    #>
    $title = "Corrigir o Windows Update"

    Enter-WinForgeAction -Title $title

    $final = New-WinForgeResult -Kind Ok -Title $title

    try {
        if (-not (Test-WinForgeElevation -Reason "Corrigir o Windows Update exige privilégios de Administrador.")) {
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Failed -Detail "requer Administrador" -Title $title)
            return
        }

        Write-Progress -Activity $title -Status "lendo os serviços do Windows Update"

        try {
            $services = @(
                foreach ($service in Get-WinForgeWindowsUpdateServices) {
                    [PSCustomObject]@{ Name = $service.Name; Label = $service.Label; Default = $service.Default; Stop = $service.Stop; State = (Get-WinForgeServiceState -Name $service.Name) }
                }
            )
            $medic = Get-WinForgeServiceState -Name "WaaSMedicSvc"
            $pending = Test-WinForgePendingReboot
            $busy = Test-WinForgeWindowsUpdateBusy
        }
        finally {
            Write-Progress -Activity $title -Completed
        }

        # Parar os serviços no meio interromperia a instalação.
        $busyText = "O Windows Update está instalando atualizações agora: espere terminar."
        $busyHint = "O andamento fica em Atualizações > Windows Update; se o problema continuar, volte aqui."
        $busyResult = "o Windows Update está instalando atualizações agora; espere terminar"

        # A faixa de quando o Windows Update está instalando: o botão abre o andamento dele.
        $busyView = {
            Set-WinForgeResultView -Result (New-WinForgeResult -Kind Skipped -Detail $busyResult -Title $title) -Headline "O Windows Update está instalando agora" `
                -Note "Espere terminar; se o problema continuar, volte aqui." -Next "updates.windows" -NextLabel "Ver o andamento"
        }

        if ($busy) {
            Write-WinForgeStatus -Type Warning -Message $busyText
            Write-WinForgeStatus -Type Info -Message $busyHint
            Exit-WinForgeAction -Result (& $busyView)
            return
        }

        # Um serviço que não existe mais (removido por um script de "limpeza") não volta com este reparo.
        $missing = @($services | Where-Object { [bool](Get-WinForgeJsonValue -Object $_.State -Name "Missing" -Default $false) })
        $unread = @($services | Where-Object { $null -eq $_.State })

        if ($missing.Count -gt 0) {
            $names = Get-WinForgeServiceNamesText -Labels @($missing | ForEach-Object { $_.Label }) -One "não existe" -Many "não existem"
            Write-WinForgeStatus -Type Error -Message "$($names.Substring(0, 1).ToUpper())$($names.Substring(1)) neste Windows, e este reparo não o recria."
            Write-WinForgeStatus -Type Info -Message "Reparo > Recuperação pode reinstalar o Windows mantendo os seus arquivos."
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Failed -Detail "$names neste Windows" -Title $title)
            return
        }

        if ($unread.Count -gt 0) {
            $names = Get-WinForgeServiceNamesText -Labels @($unread | ForEach-Object { $_.Label })
            Write-WinForgeStatus -Type Error -Message "O Windows não respondeu sobre $names."
            Write-WinForgeStatus -Type Info -Message "Isso costuma ser dano nos arquivos do Windows: use Reparo > Reparar o Windows (DISM + SFC)."
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Failed -Detail "o Windows não respondeu sobre $names" -Title $title)
            return
        }

        # O reparo desliga os serviços, põe de lado o cache (os downloads, o banco de dados e o catálogo de assinaturas) e
        # liga os serviços de novo, como a Microsoft indica. O que a pessoa precisa saber antes: o histórico some.
        Write-WinForgeStatus -Type Info -Message "Refaz o cache do Windows Update: as atualizações instaladas ficam, mas o histórico delas recomeça vazio."

        $disabled = @($services | Where-Object { $_.State.StartType -eq "Disabled" })

        foreach ($service in $disabled) {
            Write-WinForgeStatus -Type Warning -Message "O serviço $($service.Label) está desativado: ele volta para o padrão do Windows ($(if ($service.Default -eq 'Manual') { 'manual' } else { 'automático' }))."
        }

        if ([string](Get-WinForgeJsonValue -Object $medic -Name "StartType" -Default "") -eq "Disabled") {
            # O Medic conserta o Windows Update sozinho; o Windows o protege, e o WinForge não mexe nele.
            Write-WinForgeStatus -Type Warning -Message "O serviço Windows Update Medic (WaaSMedicSvc) está desativado: desfaça pelo programa que o desativou."
        }

        if (Write-WinForgeWindowsUpdatePolicyNote) {
            Write-WinForgeStatus -Type Info -Message "O reparo não muda políticas."
        }

        Write-Host ""

        if ($pending) {
            Write-WinForgeStatus -Type Warning -Message "Há um reinício pendente: reinicie antes, muitas vezes isso já resolve."

            if (-not (Confirm-WinForgeAction -Message "Corrigir sem reiniciar?" -DefaultKey "N")) {
                Write-WinForgeStatus -Type Warning -Message "Operação cancelada."
                Request-WinForgeRestartOffer -Reason "Reinicie agora e, se o problema continuar, abra Atualizações > Corrigir o Windows Update de novo." `
                    -Comment "Reinicialização solicitada pelo WinForge (reinício pendente antes de corrigir o Windows Update)." `
                    -DeclinedMessage "Reinicialização não iniciada. Reinicie o PC e, se o problema continuar, volte aqui." `
                    -Fallback "Reinicie o PC e, se o problema continuar, volte aqui."
                Exit-WinForgeAction -Result (New-WinForgeResult -Kind Skipped -Detail "cancelado pelo usuário" -Title $title)
                return
            }
        }
        elseif (-not (Confirm-WinForgeAction -Message "Corrigir o Windows Update agora?" -DefaultKey "S")) {
            Write-WinForgeStatus -Type Warning -Message "Operação cancelada."
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Skipped -Detail "cancelado pelo usuário" -Title $title)
            return
        }

        # A pergunta pode ter ficado aberta enquanto o Windows começava a instalar sozinho.
        if (Test-WinForgeWindowsUpdateBusy) {
            Write-WinForgeStatus -Type Warning -Message $busyText
            Write-WinForgeStatus -Type Info -Message $busyHint
            Exit-WinForgeAction -Result (& $busyView)
            return
        }

        $rows = @()
        $restored = @()
        $stillDisabled = @()

        # 1. Os serviços desativados voltam ao padrão. Se algum não voltar, o Windows Update continua sem funcionar, e
        # refazer o cache (que esvazia o histórico das Configurações) não adiantaria: para aqui.
        foreach ($service in $disabled) {
            try {
                Set-WinForgeServiceStartType -Name $service.Name -StartType $service.Default
                $restored += $service.Label
                $row = New-WinForgeResult -Kind Ok -Detail "voltou para $(if ($service.Default -eq 'Manual') { 'manual' } else { 'automático' })"
            }
            catch {
                $stillDisabled += $service.Label
                $row = New-WinForgeResult -Kind Failed -Detail "continua desativado: $($_.Exception.Message.TrimEnd('.'))"
            }

            $row.Etapa = "Serviço $($service.Label)"
            $rows += $row
        }

        if ($restored.Count -gt 0) {
            [void](Add-WinForgeChange -Action "Corrigir o Windows Update" -Text "$(Get-WinForgeServiceNamesText -Labels $restored -One 'voltou' -Many 'voltaram') ao padrão do Windows")
        }

        if ($stillDisabled.Count -gt 0) {
            $names = Get-WinForgeServiceNamesText -Labels $stillDisabled -One "continua desativado" -Many "continuam desativados"
            Write-WinForgeSection -Title "Resumo"
            Write-WinForgeResultTable -Results $rows
            Write-WinForgeStatus -Type Warning -Message "$($names.Substring(0, 1).ToUpper())$($names.Substring(1)), e sem $(if ($stillDisabled.Count -eq 1) { 'ele' } else { 'eles' }) o Windows Update não funciona; um bloqueador de atualizações pode estar travando isso."
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Warning -Detail "$names; o cache não foi mexido" -Title $title)
            return
        }

        # 2. Para os serviços e põe o cache de lado; 3. liga tudo de novo (finally); 4. apaga os downloads postos de lado.
        $stopping = @($services | Where-Object { $_.Stop })
        $restart = New-Object System.Collections.ArrayList
        $moved = @()
        $stopProblem = ""

        try {
            Write-Progress -Activity $title -Status "desligando os serviços do Windows Update"

            # Quem depende de um serviço para junto com ele (Stop-Service -Force): esses voltam a ligar no fim.
            foreach ($service in $stopping) {
                foreach ($dependent in @($service.State.Dependents)) { if (-not $restart.Contains($dependent)) { [void]$restart.Add($dependent) } }

                if (-not (Stop-WinForgeService -Name $service.Name)) {
                    $stopProblem = "o serviço $($service.Label) não parou em 30 segundos"
                    break
                }
            }

            if (-not $stopProblem) {
                foreach ($folder in @(Get-WinForgeWindowsUpdateCacheFolders)) {
                    Write-Progress -Activity $title -Status "pondo de lado: $($folder.Label)"

                    # Outro serviço (o orquestrador de atualizações) pode religar o Windows Update a qualquer momento.
                    foreach ($service in $stopping) {
                        try { [void](Stop-WinForgeService -Name $service.Name -TimeoutSeconds 10) } catch { Write-Verbose "Parar $($service.Name): $($_.Exception.Message)" }
                    }

                    $row = Move-WinForgeUpdateCacheFolder -Folder $folder
                    $row.Etapa = $folder.Label
                    $rows += $row

                    if ($row.Kind -eq "Ok") { $moved += [PSCustomObject]@{ Folder = $folder; Row = $row } }
                }
            }
        }
        catch {
            $stopProblem = "não foi possível desligar os serviços: $($_.Exception.Message.TrimEnd('.'))"
        }
        finally {
            Write-Progress -Activity $title -Status "ligando os serviços de novo"
            $notStarted = @()
            $toStart = @(@("cryptsvc", "bits", "wuauserv") + @($restart))
            if (@($services | Where-Object { $_.Name -eq "UsoSvc" -and $restored -contains $_.Label }).Count -gt 0) { $toStart += "UsoSvc" }

            foreach ($name in $toStart) {
                try { Start-WinForgeService -Name $name } catch { $notStarted += $name }
            }

            Write-Progress -Activity $title -Completed
        }

        # Os downloads são só cache: a cópia sai depois que os serviços já estão ligados de novo.
        foreach ($entry in @($moved | Where-Object { -not $_.Folder.Keep })) {
            $backup = [string](Get-WinForgeResultData -Result $entry.Row -Name "Backup")
            $text = $(if (Remove-WinForgeUpdateCacheBackup -Path $backup) { "apagados; o Windows baixa de novo o que precisar" } else { "postos de lado em $(Split-Path -Leaf $backup)" })
            $entry.Row.Detail = $text
            $entry.Row.Status = "OK ($text)"
        }

        $movedNames = @($moved | ForEach-Object { [string]$_.Folder.Name })

        if ($movedNames.Count -gt 0) {
            [void](Add-WinForgeChange -Action "Corrigir o Windows Update" -Text "cache refeito ($(Join-WinForgeList -Items $movedNames))")
        }

        $labels = @{}
        foreach ($service in $services) { $labels[$service.Name] = $service.Label }
        $notStartedText = Join-WinForgeList -Items @($notStarted | ForEach-Object { if ($labels.ContainsKey($_)) { $labels[$_] } else { $_ } })

        if ($rows.Count -gt 0) {
            Write-WinForgeSection -Title "Resumo"
            Write-WinForgeResultTable -Results $rows
        }

        $folderFailed = @($rows | Where-Object { $_.Kind -eq "Failed" -and $_.Etapa -notlike "Serviço *" })
        $linked = @($rows | Where-Object { Test-WinForgeResultFlag -Result $_ -Name "Linked" })

        if ($stopProblem) {
            $touched = $(if ($movedNames.Count -gt 0) { "Só parte do cache foi refeita ($(Join-WinForgeList -Items $movedNames))." } else { "Nada do cache foi mexido." })
            Write-WinForgeStatus -Type Error -Message "Não foi possível terminar a correção: $stopProblem. $touched"
            Write-WinForgeStatus -Type Info -Message "Reinicie o PC e tente de novo."
            $final = New-WinForgeResult -Kind Failed -Detail "$stopProblem; $($touched.TrimEnd('.').ToLower())" -Title $title
        }
        elseif ($notStarted.Count -gt 0) {
            Write-WinForgeStatus -Type Warning -Message "Não foi possível ligar de novo: $notStartedText. Reinicie o PC para o Windows ligá-los."
            $final = New-WinForgeResult -Kind Warning -Detail "cache refeito, mas não ligou de novo: $notStartedText; reinicie o PC" -Title $title -Data @{ RebootRequired = $true }
            Request-WinForgeRestartOffer -Reason "Reiniciar liga de novo os serviços do Windows Update." `
                -Comment "Reinicialização solicitada pelo WinForge para ligar os serviços do Windows Update." `
                -DeclinedMessage "Reinicialização não iniciada. Os serviços voltam a ligar quando você reiniciar o PC."
        }
        elseif ($folderFailed.Count -gt 0) {
            $names = Join-WinForgeList -Items @($folderFailed | ForEach-Object { $_.Etapa })
            Write-WinForgeStatus -Type Info -Message "Reinicie o PC e rode a correção de novo."
            $final = New-WinForgeResult -Kind Warning -Detail "ficou como estava: $names" -Title $title
        }
        elseif ($linked.Count -gt 0) {
            $names = Join-WinForgeList -Items @($linked | ForEach-Object { $_.Etapa })
            # Quase sempre um programa que mudou o cache de disco; o WinForge não mexe do outro lado.
            Write-WinForgeStatus -Type Info -Message "$names $(if ($linked.Count -eq 1) { 'aponta' } else { 'apontam' }) para outra pasta: desfaça pelo programa que mudou isso."
            $final = New-WinForgeResult -Kind Warning -Detail "cache refeito em parte; $names aponta para outro lugar e ficou como está" -Title $title
        }
        else {
            Write-WinForgeStatus -Type Info -Message "Agora use Atualizações > Instalar atualizações do Windows; a primeira busca demora mais."
            $final = New-WinForgeResult -Kind Ok -Detail "cache do Windows Update refeito e serviços ligados de novo" -Title $title
            [void](Set-WinForgeResultView -Result $final -Headline "Cache do Windows Update refeito" -Note "Os serviços estão ligados de novo. A primeira busca por atualizações demora mais." `
                    -Next "updates.install" -NextLabel "Procurar atualizações")
        }
    }
    catch {
        Write-WinForgeStatus -Type Error -Message "Não foi possível corrigir o Windows Update: $($_.Exception.Message.TrimEnd('.'))."
        $final = New-WinForgeResult -Kind Failed -Detail $_.Exception.Message.TrimEnd(".") -Title $title
    }

    Exit-WinForgeAction -Result $final
}

Export-ModuleMember -Function *
