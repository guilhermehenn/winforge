# Windows Update dentro do WinForge: procurar, escolher, baixar e instalar as atualizações pendentes, com progresso.
#
# Usa a API COM do próprio Windows Update (Microsoft.Update.Session), a mesma de Get-WinForgePendingWindowsUpdates. O
# trabalho roda em outro runspace (as tarefas em segundo plano do Core: Invoke-WinForgeInBackground na consulta,
# Start-WinForgeInBackground e Stop-WinForgeInBackground na instalação): enquanto ele baixa e instala, a tela acompanha
# o progresso e o botão Parar continua funcionando.
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
    A sessão leva o nome do WinForge (ClientApplicationID), como no exemplo da Microsoft: o histórico do Windows Update diz
    que programa instalou cada atualização, e sem o nome diz "Unknown".
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

# Um Windows que recuse o nome não atrapalha a busca nem a instalação.
try { $session.ClientApplicationID = "WinForge" } catch { }
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
    # ($State.ErrorHResult), para a tela dizer o código mesmo quando a mensagem não o traz. Quando nada chega a ser
    # instalado sem um erro do Windows (nenhuma escolhida ainda oferecida, nenhuma baixada), o script diz só o caso
    # ($State.Reason: Missing ou NotDownloaded): ele não enxerga as traduções, e a frase sai no idioma da tela.
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
        $State.Reason = "Missing"
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
        $State.Reason = "NotDownloaded"
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

    $cache = (Get-WinForgeText 'use Atualizações > Corrigir o Windows Update')
    $store = (Get-WinForgeText 'use Reparo > Reparar o Windows (DISM + SFC)')

    switch ("0x{0:X8}" -f $HResult) {
        "0x80240016" { return (Get-WinForgeText 'outra instalação estava em andamento ou falta reiniciar o PC') }
        "0x8024200D" { return (Get-WinForgeText 'a atualização precisa ser baixada de novo; se o erro voltar, {0}' "$cache") }
        "0x80246007" { return (Get-WinForgeText 'a atualização não foi baixada; se o erro voltar, {0}' "$cache") }
        "0x80242006" { return (Get-WinForgeText 'os dados da atualização guardados no PC estão inválidos; {0}' "$cache") }
        "0x80248007" { return (Get-WinForgeText 'falta informação no cache do Windows Update; {0}' "$cache") }
        "0x8007000D" { return (Get-WinForgeText 'o que foi baixado veio corrompido; {0}' "$cache") }
        "0x80246008" { return (Get-WinForgeText 'o serviço de transferência do Windows (BITS) não respondeu; {0}' "$cache") }
        "0x80240034" { return (Get-WinForgeText 'o download falhou') }
        "0x8024001E" { return (Get-WinForgeText 'o Windows estava desligando ou o serviço parou') }
        "0x8024000B" { return (Get-WinForgeText 'a operação foi cancelada') }
        "0x8024001F" { return (Get-WinForgeText 'sem conexão com a internet') }
        "0x8024402C" { return (Get-WinForgeText 'não foi possível chegar ao servidor do Windows Update (endereço não encontrado)') }
        "0x80072EFD" { return (Get-WinForgeText 'não foi possível conectar ao servidor do Windows Update') }
        "0x80072EFE" { return (Get-WinForgeText 'a conexão com o Windows Update caiu no meio') }
        "0x80072EE2" { return (Get-WinForgeText 'a conexão com o Windows Update esgotou o tempo') }
        "0x8024401C" { return (Get-WinForgeText 'o servidor do Windows Update demorou demais para responder') }
        "0x80244017" { return (Get-WinForgeText 'o servidor recusou o acesso (um proxy ou firewall pode estar bloqueando)') }
        "0x80244018" { return (Get-WinForgeText 'o servidor recusou o acesso (um proxy ou firewall pode estar bloqueando)') }
        "0x80244022" { return (Get-WinForgeText 'o servidor do Windows Update está sobrecarregado; tente mais tarde') }
        "0x8024002E" { return (Get-WinForgeText 'uma política do Windows bloqueia o acesso ao Windows Update') }
        "0x80070422" { return (Get-WinForgeText 'o serviço Windows Update está desativado; {0}' "$cache") }
        "0x80070070" { return (Get-WinForgeText 'falta espaço no disco') }
        "0x80070020" { return (Get-WinForgeText 'um arquivo estava em uso por outro programa, como um antivírus') }
        "0x80070BC9" { return (Get-WinForgeText 'o Windows precisa reiniciar para desfazer uma instalação anterior; reinicie o PC e tente de novo') }
        "0x80073712" { return (Get-WinForgeText 'a imagem do Windows está danificada; {0}' "$store") }
        "0x80073701" { return (Get-WinForgeText 'faltam arquivos do Windows de que a atualização precisa; {0}' "$store") }
        "0x800F081F" { return (Get-WinForgeText 'faltam arquivos do Windows de que a atualização precisa; {0}' "$store") }
        "0x800F0831" { return (Get-WinForgeText 'faltam arquivos do Windows de que a atualização precisa; {0}' "$store") }
    }

    return ""
}


function Format-WinForgeUpdateError {
    # "frase — erro 0x80240016", ou só "erro 0x8024XXXX" para um código sem frase. "" sem código.
    param ([int]$HResult)

    if ($HResult -eq 0) { return "" }

    $code = "0x{0:X8}" -f $HResult
    $text = Get-WinForgeWindowsUpdateHResultText -HResult $HResult

    if ($text) { return (Get-WinForgeText '{0} — erro {1}' "$text" "$code") }

    return (Get-WinForgeText 'erro {0}' "$code")
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
        $base = (Get-WinForgeText 'o Windows Update não abriu neste PC')

        if ($sessionCode -eq 0) { return (Get-WinForgeText '{0} (o componente dele não respondeu)' "$base") }

        $phrase = Get-WinForgeWindowsUpdateHResultText -HResult $sessionCode

        return (Get-WinForgeText '{0} ({1}) — erro {2}' "$base" "$(if ($phrase) { $phrase } else { (Get-WinForgeText 'o componente dele não respondeu') })" "$("0x{0:X8}" -f $sessionCode)")
    }

    if ($text -match '0x([0-9A-Fa-f]{8})') {
        return (Format-WinForgeUpdateError -HResult ([Convert]::ToInt32($Matches[1], 16)))
    }

    # Os códigos genéricos do .NET e do PowerShell não dizem nada e ficam de fora (Get-WinForgeErrorCode).
    $code = Get-WinForgeErrorCode -HResult $HResult

    if ($code) {
        $phrase = Get-WinForgeWindowsUpdateHResultText -HResult $HResult

        if ($phrase) { return (Get-WinForgeText '{0} — erro {1}' "$phrase" "$code") }
        if ([string]::IsNullOrWhiteSpace($text)) { return (Get-WinForgeText 'erro {0}' "$code") }

        return (Get-WinForgeText '{0} — erro {1}' "$($text.TrimEnd('.'))" "$code")
    }

    if ([string]::IsNullOrWhiteSpace($text)) { return (Get-WinForgeText 'o Windows Update devolveu um erro') }

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
        return [PSCustomObject]@{ Updates = $null; Problem = (Get-WinForgeText 'o Windows Update não respondeu em {0}' "$(Format-WinForgeCount -Count $minutes -One (Get-WinForgeText 'minuto') -Many (Get-WinForgeText 'minutos'))") }
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
    # 5 = interrompida), com o código de erro de cada atualização quando houver. Uma falha sem código diz isso: a faixa
    # manda ver o motivo no resumo. -Driver: "instalado com erros", no masculino.
    param (
        [int]$Code,

        [int]$HResult = 0,

        [switch]$Driver
    )

    $errorText = Format-WinForgeUpdateError -HResult $HResult

    switch ($Code) {
        2 { return (New-WinForgeResult -Kind Ok) }
        3 {
            $text = $(
                if ($Driver) { $(if ($errorText) { (Get-WinForgeText 'instalado com erros: {0}' "$errorText") } else { (Get-WinForgeText 'instalado com erros') }) }
                else { $(if ($errorText) { (Get-WinForgeText 'instalada com erros: {0}' "$errorText") } else { (Get-WinForgeText 'instalada com erros') }) }
            )
            return (New-WinForgeResult -Kind Warning -Detail $text)
        }
        5 { return (New-WinForgeResult -Kind Failed -Detail (Get-WinForgeText 'interrompida')) }
        { $_ -in 0, 1 } { return (New-WinForgeResult -Kind Failed -Detail (Get-WinForgeText 'não foi concluída')) }
        default { return (New-WinForgeResult -Kind Failed -Detail $(if ($errorText) { $errorText } else { (Get-WinForgeText 'o Windows Update não informou o motivo') })) }
    }
}


function Get-WinForgeUpdateDownloadError {
    # O motivo de o download inteiro ter falhado (código 4) ou parado (código 5), com o erro do Windows quando houver.
    param (
        [int]$Code,

        [int]$HResult = 0
    )

    $errorText = Format-WinForgeUpdateError -HResult $HResult

    if ($Code -eq 5) { return (Get-WinForgeText 'o download das atualizações foi interrompido') }
    if ($errorText) { return (Get-WinForgeText 'o download das atualizações falhou: {0}' "$errorText") }

    return (Get-WinForgeText 'o download das atualizações falhou')
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
        if ($total -eq 1) { return (Get-WinForgeText 'a atualização não foi instalada') }

        return (Get-WinForgeText 'nenhuma das {0} atualizações foi instalada' "$total")
    }

    if ($Failed -eq 0 -and $Warned -eq 0) {
        return (Format-WinForgeCount -Count $Ok -One (Get-WinForgeText 'atualização instalada') -Many (Get-WinForgeText 'atualizações instaladas'))
    }

    $text = $(if ($installed -eq 1) { (Get-WinForgeText '1 de {0} instalada' "$total") } else { (Get-WinForgeText '{0} de {1} instaladas' "$installed" "$total") })

    if ($Warned -gt 0) { $text += (Get-WinForgeText ' ({0} com erros)' "$Warned") }
    if ($Failed -eq 1) { $text += (Get-WinForgeText '; 1 falhou') }
    elseif ($Failed -gt 1) { $text += (Get-WinForgeText '; {0} falharam' "$Failed") }

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

    if ($Update.Downloaded) { return (Get-WinForgeText 'já baixada') }
    if ([int64]$Update.Size -gt 0) { return (Get-WinForgeText 'até {0}' "$(Format-WinForgeBytes -Bytes ([int64]$Update.Size))") }

    return (Get-WinForgeText 'tamanho não informado')
}


function Get-WinForgeDriverClassText {
    # A classe do driver no Windows Update (a classe de instalação do aparelho) com o nome que a pessoa conhece. Uma classe
    # sem tradução aqui aparece como veio; vazio sem classe.
    param ([string]$Class)

    switch -Regex (([string]$Class).Trim()) {
        '^Display$' { return (Get-WinForgeText 'vídeo') }
        '^Net$' { return (Get-WinForgeText 'rede') }
        '^Bluetooth$' { return (Get-WinForgeText 'Bluetooth') }
        '^(MEDIA|AudioEndpoint|AudioProcessingObject)$' { return (Get-WinForgeText 'som') }
        '^(Camera|Image)$' { return (Get-WinForgeText 'câmera') }
        '^USB$' { return "USB" }
        '^(HIDClass|Keyboard|Mouse)$' { return (Get-WinForgeText 'teclado, mouse ou touchpad') }
        '^System$' { return (Get-WinForgeText 'sistema') }
        '^Firmware$' { return (Get-WinForgeText 'firmware (como a BIOS)') }
        '^(Printer|PrintQueue)$' { return (Get-WinForgeText 'impressora') }
        '^SoftwareComponent$' { return (Get-WinForgeText 'programa de apoio do aparelho') }
        '^Extension$' { return (Get-WinForgeText 'extensão de outro driver') }
        '^Biometric$' { return (Get-WinForgeText 'biometria') }
        '^(SCSIAdapter|HDC|DiskDrive)$' { return (Get-WinForgeText 'disco') }
        '^Monitor$' { return (Get-WinForgeText 'monitor') }
        '^SecurityDevices$' { return (Get-WinForgeText 'segurança (TPM)') }
        '^Sensor$' { return (Get-WinForgeText 'sensores') }
        '^Battery$' { return (Get-WinForgeText 'bateria') }
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
        Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'Há uma atualização de firmware (como a BIOS): ela termina no reinício. Não desligue o PC e, num notebook, deixe-o na tomada.')
    }
}


function Write-WinForgeMeteredWarning {
    # Numa conexão limitada (plano de dados), avisa antes de baixar: o próprio Windows não baixaria sozinho.
    param ([int64]$Bytes = 0)

    if (-not (Test-WinForgeMeteredConnection)) { return }

    $what = $(if ($Bytes -gt 0) { (Get-WinForgeText 'baixar até {0}' "$(Format-WinForgeBytes -Bytes $Bytes)") } else { (Get-WinForgeText 'baixar as atualizações') })
    Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'A conexão com a internet está marcada como limitada (plano de dados): {0} pode consumir a sua franquia.' "$what")
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


function Get-WinForgeWindowsUpdatePause {
    <#
    Se as atualizações do Windows estão pausadas (Configurações > Windows Update > Pausar atualizações, ou uma política
    da empresa). $null quando não estão, ou sem leitura; senão Until, o fim da pausa na hora local ($null quando o
    Windows não diz). A situação vem de PausedQualityStatus, que a Microsoft documenta em UpdatePolicy\Settings (1 =
    pausadas; 0 e 2, sem pausa ou retomadas sozinhas no fim do prazo); a data, de PauseUpdatesExpiryTime, que a página das
    Configurações grava em UTC. Sem a situação, a data no futuro basta. Now: a hora de agora (para os testes).
    #>
    param ([datetime]$Now = (Get-Date))

    try {
        $policy = Get-ItemProperty -LiteralPath "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UpdatePolicy\Settings" -ErrorAction SilentlyContinue
        $settings = Get-ItemProperty -LiteralPath "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -ErrorAction SilentlyContinue
        $status = Get-WinForgeJsonValue -Object $policy -Name "PausedQualityStatus" -Default $null
        $expiry = ([string](Get-WinForgeJsonValue -Object $settings -Name "PauseUpdatesExpiryTime" -Default "")).Trim()
        $until = $null
        $parsed = [datetime]::MinValue
        $styles = [System.Globalization.DateTimeStyles]::AdjustToUniversal -bor [System.Globalization.DateTimeStyles]::AssumeUniversal

        if ($expiry -and [datetime]::TryParse($expiry, [System.Globalization.CultureInfo]::InvariantCulture, $styles, [ref]$parsed)) {
            $local = $parsed.ToLocalTime()
            if ($local -gt $Now) { $until = $local }
        }

        if ($null -ne $status) {
            if ([string]$status -ne "1") { return $null }
        }
        elseif ($null -eq $until) {
            return $null
        }

        return [PSCustomObject]@{ Until = $until }
    }
    catch {
        Write-Verbose "Pausa do Windows Update: $($_.Exception.Message)"
        return $null
    }
}


function Get-WinForgeUpdatePauseText {
    # A pausa em palavras: a frase ("As atualizações do Windows estão pausadas até 05/12/2026."), o pedaço para o
    # resultado (-Detail: "pausadas até 05/12/2026") ou o da faixa do alto da página (-Status: "pausado até 05/12/2026").
    param (
        [Parameter(Mandatory)]$Pause,
        [switch]$Detail,
        [switch]$Status
    )

    $until = Get-WinForgeJsonValue -Object $Pause -Name "Until" -Default $null
    $date = $(if ($until -is [datetime]) { Format-WinForgeDateTime -When $until -Pattern 'dd/MM/yyyy' } else { "" })

    if ($Status) { return $(if ($date) { (Get-WinForgeText 'pausado até {0}' "$date") } else { (Get-WinForgeText 'pausado') }) }
    if ($Detail) { return $(if ($date) { (Get-WinForgeText 'pausadas até {0}' "$date") } else { (Get-WinForgeText 'pausadas nas Configurações') }) }

    return $(if ($date) { (Get-WinForgeText 'As atualizações do Windows estão pausadas até {0}.' "$date") } else { (Get-WinForgeText 'As atualizações do Windows estão pausadas.') })
}


function Test-WinForgeMeteredUpdateDownload {
    <#
    Se o Windows baixa as atualizações numa conexão limitada: a chave "Baixar atualizações em conexões limitadas" das
    Configurações ou a política que a decide (AllowAutoWindowsUpdateDownloadOverMeteredNetwork, 1 = baixa). Com a
    política, vale ela; sem leitura, $false.
    #>
    $name = "AllowAutoWindowsUpdateDownloadOverMeteredNetwork"

    foreach ($key in @("HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate", "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings")) {
        try {
            $value = Get-WinForgeJsonValue -Object (Get-ItemProperty -LiteralPath $key -ErrorAction SilentlyContinue) -Name $name -Default $null
            if ($null -ne $value) { return ([string]$value -eq "1") }
        }
        catch {
            Write-Verbose "Conexão limitada do Windows Update: $($_.Exception.Message)"
        }
    }

    return $false
}


function Write-WinForgeWindowsUpdatePolicyNote {
    <#
    Quando uma política muda de onde vêm as atualizações, a tela diz isso: é a explicação mais provável de uma consulta
    que falha, e nenhum reparo do WinForge a muda. Devolve $true quando escreveu.
    #>
    $policy = Get-WinForgeWindowsUpdatePolicy
    $who = (Get-WinForgeText 'Num PC de empresa, fale com o suporte de TI; num PC de casa, um programa bloqueador de atualizações costuma fazer isso: desfaça a configuração por ele.')

    if ($policy.Blocked) {
        Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Uma política do Windows desliga o acesso ao Windows Update neste PC. {0}' "$who")
        return $true
    }

    if ($policy.Server) {
        Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Uma política do Windows manda buscar as atualizações num servidor da empresa ({0}), e não no Windows Update. {1}' "$($policy.Server)" "$who")
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
    # Palavras dos motivos nos três idiomas da interface, mais os nomes do item e da página no idioma de agora.
    $known = 'Corrigir o Windows Update|Reparo >|internet|conectar|conexão|servidor|proxy|firewall|política|espaço|connect|server|policy|space|conexión|directiva|espacio'
    $here = "$([regex]::Escape((Get-WinForgeText 'Corrigir o Windows Update')))|$([regex]::Escape((Get-WinForgeText 'Reparo'))) >"
    if ($Problem -match $known -or $Problem -match $here) { return }

    # O reparo refaz o cache de atualizações e religa os serviços.
    Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Se o erro se repetir, use Atualizações > Corrigir o Windows Update.')
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
            $activity = $(if ($State.Phase -eq "Baixando") { (Get-WinForgeText 'Baixando as atualizações') } else { (Get-WinForgeText 'Instalando as atualizações') })
            $status = (Get-WinForgeText '{0} de {1}' "$($State.Index)" "$($State.Total)")

            if (-not [string]::IsNullOrWhiteSpace([string]$State.Current)) { $status += ": $($State.Current)" }

            Write-Progress -Activity $activity -Status $status -PercentComplete ([math]::Max(0, [math]::Min(100, [int]$State.Percent)))
        }
        else {
            # Antes de baixar, o Windows Update confere de novo as escolhidas, o que pode demorar.
            Write-Progress -Activity (Get-WinForgeText 'Preparando a instalação') -Status (Get-WinForgeText 'o Windows Update confere as atualizações escolhidas')
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
            Reason         = ""
            RebootRequired = $false
            Results        = (New-Object System.Collections.ArrayList)
            Missing        = (New-Object System.Collections.ArrayList)
            NotDownloaded  = (New-Object System.Collections.ArrayList)
        })

    $task = Start-WinForgeInBackground -ScriptBlock ([scriptblock]::Create((Get-WinForgeUpdateInstallScript))) -ArgumentList @($state, $Ids, $FactoryCode, $Criteria)
    $timedOut = $false

    try {
        if (Wait-WinForgeUpdateJob -Handle $task.Handle -State $state -TimeoutMinutes $TimeoutMinutes) {
            [void]$task.Shell.EndInvoke($task.Handle)
        }
        else {
            $timedOut = $true
        }
    }
    finally {
        Write-Progress -Activity (Get-WinForgeText 'Instalando as atualizações') -Completed

        # Terminado, o runspace é liberado; interrompido (o Parar) ou sem resposta, o pedido de parar não espera uma
        # chamada COM presa.
        Stop-WinForgeInBackground -Task $task
    }

    # O texto do erro passa pela mesma tradução da consulta: sem o embrulho do PowerShell, com a frase de um código
    # conhecido e sempre com o código. O download que falhou inteiro só deixa os códigos no estado (DownloadCode
    # diferente de zero), e os dois casos sem erro do Windows, só o nome (Reason).
    $errorText = [string]$state.Error
    if (-not [string]::IsNullOrWhiteSpace($errorText)) { $errorText = Get-WinForgeWindowsUpdateProblem -Message $errorText -HResult ([int]$state.ErrorHResult) }
    if ([int]$state.DownloadCode -ne 0) { $errorText = Get-WinForgeUpdateDownloadError -Code ([int]$state.DownloadCode) -HResult ([int]$state.DownloadHResult) }
    if ([string]$state.Reason -eq "Missing") { $errorText = (Get-WinForgeText 'as atualizações escolhidas não estão mais disponíveis') }
    if ([string]$state.Reason -eq "NotDownloaded") { $errorText = (Get-WinForgeText 'nenhuma das atualizações foi baixada, então nada foi instalado') }

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

    $text = (Get-WinForgeText 'o {0} não recebe mais atualizações de segurança' "$product")
    $end = Get-WinForgeJsonValue -Object $Status -Name "EndDate" -Default $null

    if ($end -is [datetime]) { $text += (Get-WinForgeText ' desde {0}' "$(Format-WinForgeDateTime -When $end -Pattern 'dd/MM/yyyy')") }

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
            Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'Não há atualizações pendentes, mas {0}.' "$ended")
        }
        else {
            Write-WinForgeStatus -Type Warning -Notice -Message (Get-WinForgeText '{0}{1}: instalar as pendentes não muda isso.' "$($ended.Substring(0, 1).ToUpperInvariant())" "$($ended.Substring(1))")
        }

        $advice = [string](Get-WinForgeJsonValue -Object $Status -Name "Advice" -Default "")
        if ($advice) { Write-WinForgeStatus -Type Info -Message $advice }

        # A edição de longo prazo (LTSC) não recebe a versão nova pelo Windows Update.
        if ([string](Get-WinForgeJsonValue -Object $Status -Name "Class" -Default "") -ne "Ltsc") {
            Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Quando houver uma versão nova para este PC, ela aparece em Atualizações > Windows Update, no botão Baixar e instalar.')
        }

        Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Detalhes em Diagnóstico > Suporte do Windows.')
        return $true
    }

    if ($state -in @("EndingSoon", "EsuAvailable")) {
        $text = ([string](Get-WinForgeJsonValue -Object $Status -Name "Text" -Default "")).Trim()
        if ($text) { Write-WinForgeStatus -Type Info -Message (Get-WinForgeText '{0} Veja Diagnóstico > Suporte do Windows.' "$text") }
    }

    return $false
}


function Get-WinForgeUpdatesPageStatus {
    <#
    O resumo no alto da página Atualizações (New-GuiPageStatus), de leituras rápidas, sem consultar o Windows Update: a
    versão do Windows e até quando ela recebe atualizações de segurança (o catálogo do WinForge, como no Início) e, só
    quando pede atenção, o Windows Update pausado nas Configurações ou parado numa atualização antiga. Cada linha tem
    Label, Text, Level (Normal | Warn) e Opens: o suporte que pede atenção abre Suporte do Windows; a pausa, o Windows
    Update das Configurações, onde se retoma; o atraso, Instalar atualizações do Windows.
    #>
    $rows = @()
    $support = Get-WinForgeUpdateSupportStatus

    if ($null -ne $support -and [string]$support.Product) {
        $short = Get-WinForgeWindowsSupportShortText -Status $support
        $issue = Get-WinForgeWindowsSupportIssue -Status $support
        $rows += [PSCustomObject]@{
            Label = "Windows"
            Text  = $(if ($short) { "$([string]$support.Product) · $short" } else { [string]$support.Product })
            Level = $(if ($null -ne $issue) { "Warn" } else { "Normal" })
            Opens = $(if ($null -ne $issue) { "diagnostics.windows-support" } else { "" })
        }
    }

    $pause = Get-WinForgeWindowsUpdatePause

    if ($null -ne $pause) {
        $rows += [PSCustomObject]@{ Label = (Get-WinForgeText 'Windows Update'); Text = (Get-WinForgeUpdatePauseText -Pause $pause -Status); Level = "Warn"; Opens = "updates.windows" }
    }
    elseif ($null -ne $support -and [string]$support.State -in @("Supported", "EndingSoon", "Esu")) {
        # A mesma conta do Início: a revisão instalada contra a atualização de segurança de dois meses atrás.
        $lag = $null
        try { $lag = Get-WinForgeWindowsUpdateLag -Build ([int]$support.Build) } catch { $lag = $null }

        if ($lag -eq $true) {
            $rows += [PSCustomObject]@{ Label = (Get-WinForgeText 'Windows Update'); Text = (Get-WinForgeText 'faltam atualizações de segurança'); Level = "Warn"; Opens = "updates.install" }
        }
    }

    return @($rows)
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
        [string]$Fallback = (Get-WinForgeText 'Reinicie o PC quando puder.')
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

    Request-WinForgeRestartOffer -Reason (Get-WinForgeText 'Para terminar de instalar {0}, o Windows precisa reiniciar.' "$What") `
        -Comment (Get-WinForgeText 'Reinicialização solicitada pelo WinForge para terminar de instalar {0}.' "$What") `
        -DeclinedMessage (Get-WinForgeText 'Reinicialização não iniciada. {0}' "$Later") `
        -Fallback (Get-WinForgeText 'Reinicie o PC para terminar a instalação.')
}


function Confirm-WinForgeUpdateConditions {
    <#
    Antes de procurar o que instalar pelo Windows Update (atualizações ou drivers): com as atualizações pausadas nas
    Configurações, com um reinício pendente ou com o notebook na bateria, a tela diz por que isso importa (Reboot,
    Battery) e pergunta. A pausa e a bateria perguntam com Cancelar como padrão; o reinício pendente é a escolha do
    Otimizar (Read-WinForgePendingRebootChoice), e Retry é o item para abrir de novo depois de reiniciar. Devolve $null
    para seguir; senão, o resultado com que a tela termina (a pessoa desistiu, ou o PC está reiniciando), com o que fazer
    já escrito.
    #>
    param (
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][string]$Reboot,
        [Parameter(Mandatory)][string]$Battery,
        [string]$Retry = (Get-WinForgeText 'Atualizações > Instalar atualizações do Windows')
    )

    # Pausadas, o Windows não baixa nem instala nada até a data: procurar por aqui é uma escolha da pessoa.
    $pause = Get-WinForgeWindowsUpdatePause

    if ($null -ne $pause) {
        Write-WinForgeStatus -Type Warning -Message (Get-WinForgeUpdatePauseText -Pause $pause)

        if (-not (Confirm-WinForgeAction -Message (Get-WinForgeText 'Procurar mesmo assim?') -DefaultKey "N" -YesLabel (Get-WinForgeText 'Procurar mesmo assim') -NoLabel (Get-WinForgeText 'Cancelar'))) {
            Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Para retomar, use Atualizações > Windows Update.')
            $paused = New-WinForgeResult -Kind Skipped -Detail (Get-WinForgeUpdatePauseText -Pause $pause -Detail) -Title $Title

            return (Set-WinForgeResultView -Result $paused -Headline (Get-WinForgeText 'As atualizações estão pausadas') -Note (Get-WinForgeText 'Retome no Windows Update, nas Configurações.') `
                    -Next "updates.windows" -NextLabel (Get-WinForgeText 'Abrir o Windows Update'))
        }
    }

    if (Test-WinForgePendingReboot) {
        Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'Há um reinício pendente. {0}' "$Reboot")

        $answer = Read-WinForgePendingRebootChoice -Question (Get-WinForgeText 'Reiniciar antes de atualizar?') -Then (Get-WinForgeText 'Depois, abra {0} de novo' "$Retry") `
            -Reason (Get-WinForgeText 'Reinicie agora e, depois, abra {0} de novo.' "$Retry") `
            -Comment (Get-WinForgeText 'Reinicialização solicitada pelo WinForge (reinício pendente antes de atualizar).') `
            -DeclinedMessage (Get-WinForgeText 'Reinicialização não iniciada. Reinicie o PC e tente de novo.')

        if ($answer -eq "Restarting") { return (New-WinForgeResult -Kind Skipped -Detail (Get-WinForgeText 'o PC está reiniciando') -Title $Title) }

        if ($answer -ne "Continue") {
            Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'Operação cancelada.')
            return (New-WinForgeResult -Kind Skipped -Detail (Get-WinForgeText 'cancelado pelo usuário') -Title $Title)
        }
    }

    if (Test-WinForgeOnBattery) {
        Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'O notebook está na bateria. {0}' "$Battery")

        if (-not (Confirm-WinForgeAction -Message (Get-WinForgeText 'Instalar mesmo assim?') -DefaultKey "N" -YesLabel (Get-WinForgeText 'Instalar mesmo assim') -NoLabel (Get-WinForgeText 'Cancelar'))) {
            Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'Operação cancelada.')
            Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Ligue o carregador e tente de novo.')
            return (New-WinForgeResult -Kind Skipped -Detail (Get-WinForgeText 'cancelado pelo usuário') -Title $Title)
        }
    }

    return $null
}


function Get-WinForgeUpdateRunResult {
    <#
    O desfecho de uma instalação pelo Windows Update (Invoke-WinForgeUpdateInstall), das atualizações ou, com -Drivers, dos
    drivers: a tabela com cada uma, a anotação no Histórico de mudanças e o WinForge.Result, com as contas e os motivos
    para a faixa (Set-WinForgeInstallView) e Data.RebootRequired quando alguma instalada pede o reinício. Chosen: o que a
    pessoa viu (para dar nome ao que não chegou a ser instalado). Um erro no meio, depois de alguns resultados, vai em
    Data.Interrupted.
    #>
    param (
        [Parameter(Mandatory)]$Run,
        [AllowEmptyCollection()][object[]]$Chosen = @(),
        [string]$Title = "",
        [string]$SectionTitle = (Get-WinForgeText 'Resumo'),
        [switch]$Drivers
    )

    $chosen = @($Chosen)
    $final = $null

    if ($run.TimedOut) {
        Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'O WinForge parou de acompanhar depois de muito tempo. O Windows pode continuar instalando: veja o andamento em Atualizações > Windows Update.')
        $final = Set-WinForgeUpdateTimeoutView -Result (New-WinForgeResult -Kind Warning -Detail (Get-WinForgeText 'tempo esgotado; a instalação pode continuar') -Title $Title)
    }
    elseif (-not [string]::IsNullOrWhiteSpace($run.Error) -and $run.Results.Count -eq 0) {
        $why = $run.Error.TrimEnd('.')
        Write-WinForgeStatus -Type Error -Message $(if ($Drivers) { (Get-WinForgeText 'Não foi possível instalar os drivers: {0}.' "$why") } else { (Get-WinForgeText 'Não foi possível instalar as atualizações: {0}.' "$why") })
        $final = New-WinForgeResult -Kind Failed -Detail $run.Error -Title $Title
    }
    else {
        $results = @()

        foreach ($item in $run.Results) {
            $outcome = Get-WinForgeUpdateOutcome -Code $item.Code -HResult $item.HResult -Driver:$Drivers
            $outcome.Etapa = $item.Title
            $results += $outcome
        }

        # As escolhidas que não chegaram a ser instaladas também entram no resumo, com o nome que a pessoa viu.
        foreach ($id in @($run.NotDownloaded)) {
            $outcome = New-WinForgeResult -Kind Failed -Detail $(if ($Drivers) { (Get-WinForgeText 'não foi baixado') } else { (Get-WinForgeText 'não foi baixada') })
            $outcome.Etapa = Get-WinForgeUpdateTitleById -Updates $chosen -Id $id
            $results += $outcome
        }

        foreach ($id in @($run.Missing)) {
            $outcome = New-WinForgeResult -Kind Failed -Detail (Get-WinForgeText 'não está mais disponível')
            $outcome.Etapa = Get-WinForgeUpdateTitleById -Updates $chosen -Id $id
            $results += $outcome
        }

        Write-WinForgeSection -Title $SectionTitle
        Write-WinForgeResultTable -Results $results

        $failed = @($results | Where-Object { $_.Kind -eq "Failed" })
        $warned = @($results | Where-Object { $_.Kind -eq "Warning" })
        $installed = @($run.Results | Where-Object { [int]$_.Code -in 2, 3 })

        # O Histórico de mudanças anota o que foi instalado: as atualizações pelo número KB quando houver (os títulos são
        # longos), os drivers pelo nome.
        if ($installed.Count -gt 0 -and $Drivers) {
            [void](Add-WinForgeChange -Action (Get-WinForgeText 'Drivers instalados') -Text (Join-WinForgeList -Items @($installed | ForEach-Object { [string]$_.Title })))
        }
        elseif ($installed.Count -gt 0) {
            $installedNames = @(
                foreach ($item in $installed) {
                    $match = @($chosen | Where-Object { [string]$_.Title -eq [string]$item.Title }) | Select-Object -First 1
                    if ($null -ne $match -and $match.Kb) { "KB$($match.Kb)" } else { [string]$item.Title }
                }
            )

            [void](Add-WinForgeChange -Action (Get-WinForgeText 'Atualizações do Windows') -Text "$(Format-WinForgeCount -Count $installedNames.Count -One (Get-WinForgeText 'instalada') -Many (Get-WinForgeText 'instaladas')): $(Join-WinForgeList -Items $installedNames)")
        }

        # "Reinicie para concluir" só faz sentido se alguma foi instalada; sem nenhuma, o motivo de cada uma diz o que fazer.
        $reboot = [bool]$run.RebootRequired -and $failed.Count -lt $results.Count

        $okCount = $results.Count - $failed.Count - $warned.Count
        $detail = $(if ($Drivers) { Get-WinForgeDriverRunDetail -Ok $okCount -Warned $warned.Count -Failed $failed.Count } else { Get-WinForgeUpdateRunDetail -Ok $okCount -Warned $warned.Count -Failed $failed.Count })

        # As contas e os motivos, para a faixa da janela (Set-WinForgeInstallView).
        $data = @{
            RebootRequired = $reboot
            Installed      = ($results.Count - $failed.Count)
            Failed         = $failed.Count
            Warned         = $warned.Count
            Problems       = @(@($failed) + @($warned) | ForEach-Object { [string]$_.Detail } | Where-Object { $_ })
        }

        # Um erro depois de algumas atualizações já terem resultado (por exemplo, ao ler o resultado das outras) deixa o
        # resumo incompleto: ele não pode sumir nem terminar como "Tudo certo", e a faixa diz que a instalação parou.
        $cutShort = -not [string]::IsNullOrWhiteSpace($run.Error)

        if ($cutShort) {
            Write-WinForgeStatus -Type Error -Message (Get-WinForgeText 'A instalação foi interrompida por um erro: {0}.' "$($run.Error.TrimEnd('.'))")
            $detail = (Get-WinForgeText '{0}; erro durante a instalação: {1}' "$detail" "$($run.Error)")
            $data.Interrupted = [string]$run.Error
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


function Set-WinForgeUpdateTimeoutView {
    # A faixa de quando o WinForge parou de acompanhar a instalação (atualizações ou drivers): o Windows pode continuar
    # instalando sozinho, e o botão abre o andamento nas Configurações. Devolve o próprio resultado.
    param ([Parameter(Mandatory)]$Result)

    return (Set-WinForgeResultView -Result $Result -Headline (Get-WinForgeText 'O WinForge parou de acompanhar') `
            -Note (Get-WinForgeText 'O Windows pode continuar instalando; veja o andamento no Windows Update.') -Next "updates.windows" -NextLabel (Get-WinForgeText 'Ver o andamento'))
}


function Get-WinForgeUpdateFixStep {
    <#
    O item do WinForge que resolve um erro do Windows Update, para o botão da faixa: os motivos (Get-WinForgeWindowsUpdateHResultText)
    já dizem "use Atualizações > Corrigir o Windows Update" ou "use Reparo > Reparar o Windows (DISM + SFC)" quando é o
    caso; "falta espaço no disco" leva a liberar espaço. Next e Label vazios quando nenhum motivo aponta um item.
    #>
    param ([AllowEmptyCollection()][string[]]$Texts = @())

    $all = (@($Texts) | Where-Object { $_ }) -join " | "

    # Os motivos citam o item com o nome do idioma da tela (e, gravados antes, em português).
    if ($all -match 'Corrigir o Windows Update' -or $all -match [regex]::Escape((Get-WinForgeText 'Corrigir o Windows Update'))) { return [PSCustomObject]@{ Next = "updates.repair"; Label = (Get-WinForgeText 'Corrigir o Windows Update') } }
    if ($all -match 'Reparar o Windows \(DISM \+ SFC\)' -or $all -match [regex]::Escape((Get-WinForgeText 'Reparar o Windows (DISM + SFC)'))) { return [PSCustomObject]@{ Next = "repair.dism-sfc"; Label = (Get-WinForgeText 'Reparar o Windows') } }
    if ($all -match 'falta espaço no disco' -or $all -match [regex]::Escape((Get-WinForgeText 'falta espaço no disco'))) { return [PSCustomObject]@{ Next = "cleanup.custom"; Label = (Get-WinForgeText 'Liberar espaço') } }

    return [PSCustomObject]@{ Next = ""; Label = "" }
}


function Set-WinForgeInstallView {
    <#
    A faixa de uma instalação pelo Windows Update (atualizações ou drivers, Get-WinForgeUpdateRunResult e a dos drivers):
    o título diz quantas foram instaladas; a frase, se falta reiniciar (ou como voltar atrás, nos drivers) ou que o motivo
    de cada falha está no resumo; e, quando um motivo aponta um item do WinForge, o botão para ele. Um, Many e None são
    os textos do que foi instalado ("atualização instalada", "atualizações instaladas", "Nenhuma atualização instalada"); Partial, o
    de quando só parte foi instalada, com {0} e {1} ("{0} de {1} atualizações instaladas"). OkNote: a
    frase de quando deu tudo certo sem reinício. Devolve o próprio resultado.
    #>
    param (
        [Parameter(Mandatory)]$Result,
        [Parameter(Mandatory)][string]$One,
        [Parameter(Mandatory)][string]$Many,
        [Parameter(Mandatory)][string]$None,
        [string]$OkNote = (Get-WinForgeText 'Não precisa reiniciar.'),
        [string]$Each = (Get-WinForgeText 'cada uma'),
        # O título de quando só parte deu certo: {0} instaladas de {1} ("{0} de {1} atualizações instaladas").
        [string]$Partial = (Get-WinForgeText '{0} de {1} atualizações instaladas')
    )

    $installed = Get-WinForgeResultData -Result $Result -Name "Installed"
    if ($null -eq $installed) { return $Result }

    $installed = [int]$installed
    $failed = [int](Get-WinForgeResultData -Result $Result -Name "Failed")
    $warned = [int](Get-WinForgeResultData -Result $Result -Name "Warned")
    $total = $installed + $failed
    $reboot = Test-WinForgeResultFlag -Result $Result -Name "RebootRequired"
    $interrupted = ([string](Get-WinForgeResultData -Result $Result -Name "Interrupted")).Trim().TrimEnd(".")
    $fix = Get-WinForgeUpdateFixStep -Texts @(@($interrupted) + @(Get-WinForgeResultData -Result $Result -Name "Problems"))

    # Parada por um erro no meio, as contas não dizem o que houve (todas as lidas podiam estar certas): a faixa diz que a
    # instalação parou e por quê.
    if ($interrupted -and $Result.Kind -eq "Warning") {
        return (Set-WinForgeResultView -Result $Result -Headline (Get-WinForgeText 'A instalação foi interrompida') -Note "$(ConvertTo-WinForgeHeadline -Text $interrupted)." -Next $fix.Next -NextLabel $fix.Label)
    }

    if ($Result.Kind -eq "Ok") {
        return (Set-WinForgeResultView -Result $Result -Headline (Format-WinForgeCount -Count $installed -One $One -Many "$Many") `
                -Note $(if ($reboot) { (Get-WinForgeText 'Reinicie o PC para terminar a instalação.') } else { $OkNote }))
    }

    # O que deu errado, em números: o motivo de cada um fica no resumo, na linha dele.
    $parts = @()
    if ($failed -gt 0) { $parts += $(if ($failed -eq 1) { (Get-WinForgeText '1 falhou') } else { (Get-WinForgeText '{0} falharam' "$failed") }) }
    if ($warned -gt 0) { $parts += (Get-WinForgeText '{0} com erros' "$warned") }
    $reason = $(if ($total -eq 1 -or ($failed + $warned) -eq 1) { (Get-WinForgeText 'o motivo está no resumo') } else { (Get-WinForgeText 'o motivo de {0} está no resumo' "$Each") })

    if ($Result.Kind -eq "Failed") {
        return (Set-WinForgeResultView -Result $Result -Headline $None -Note "$($reason.Substring(0, 1).ToUpper())$($reason.Substring(1))." -Next $fix.Next -NextLabel $fix.Label)
    }

    if ($Result.Kind -eq "Warning" -and $total -gt 0) {
        return (Set-WinForgeResultView -Result $Result -Headline ([string]::Format([System.Globalization.CultureInfo]::InvariantCulture, $Partial, $installed, $total)) `
                -Note "$(Join-WinForgeList -Items $parts); $reason." -Next $fix.Next -NextLabel $fix.Label)
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

    return (Set-WinForgeResultView -Result $Result -Headline (Get-WinForgeText 'Não foi possível instalar') -Note ($why.Substring(0, 1).ToUpper() + $why.Substring(1) + ".") -Next $fix.Next -NextLabel $fix.Label)
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

    return (Set-WinForgeResultView -Result $Result -Headline (Get-WinForgeText 'O Windows Update não respondeu') -Note $note -Next $fix.Next -NextLabel $fix.Label)
}


function Install-WinForgeWindowsUpdates {
    $title = (Get-WinForgeText 'Instalar atualizações do Windows')

    Enter-WinForgeAction -Title $title

    $final = New-WinForgeResult -Kind Ok -Title $title

    try {
        if (-not (Test-WinForgeElevation -Reason (Get-WinForgeText 'Instalar atualizações do Windows exige privilégios de Administrador.'))) {
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Failed -Detail (Get-WinForgeText 'requer Administrador') -Title $title)
            return
        }

        $stop = Confirm-WinForgeUpdateConditions -Title $title -Reboot (Get-WinForgeText 'Reiniciar antes evita que as novas atualizações falhem.') -Battery (Get-WinForgeText 'Atualizar gasta bastante energia e não deve ser interrompido.')

        if ($null -ne $stop) {
            Exit-WinForgeAction -Result $stop
            return
        }

        # O andamento vai para a barra de progresso: uma linha "procurando..." ficaria no resumo depois do fim.
        Write-Progress -Activity (Get-WinForgeText 'Procurando atualizações') -Status (Get-WinForgeText 'o Windows Update pode levar alguns minutos para responder')

        try {
            $search = Find-WinForgeWindowsUpdates
        }
        finally {
            Write-Progress -Activity (Get-WinForgeText 'Procurando atualizações') -Completed
        }

        if ($null -eq $search.Updates) {
            Write-WinForgeStatus -Type Error -Message (Get-WinForgeText 'Não foi possível consultar o Windows Update: {0}.' "$($search.Problem)")
            Write-WinForgeWindowsUpdateSearchHelp -Problem $search.Problem
            Exit-WinForgeAction -Result (Set-WinForgeUpdateSearchView -Result (New-WinForgeResult -Kind Failed -Detail (Get-WinForgeText 'não foi possível consultar o Windows Update: {0}' "$($search.Problem)") -Title $title) -Problem $search.Problem)
            return
        }

        $updates = @($search.Updates)

        # A versão nova do Windows é opcional e não entra na lista: num Windows sem suporte, "em dia" seria falso.
        $support = Get-WinForgeUpdateSupportStatus

        if ($updates.Count -eq 0) {
            if (Test-WinForgeWindowsSupportEnded -Status $support) {
                [void](Write-WinForgeUpdateSupportNote -Status $support -NothingPending)
                $ended = New-WinForgeResult -Kind Warning -Detail (Get-WinForgeText 'nada pendente, mas este Windows não recebe mais atualizações de segurança') -Title $title
                Exit-WinForgeAction -Result (Set-WinForgeResultView -Result $ended -Headline (Get-WinForgeText 'Este Windows não recebe mais atualizações') `
                        -Note (Get-WinForgeText 'Não há nada pendente, mas o suporte deste Windows terminou.') -Next "diagnostics.windows-support" -NextLabel (Get-WinForgeText 'Ver o suporte do Windows'))
                return
            }

            Write-WinForgeStatus -Type Success -Message (Get-WinForgeText 'O Windows está em dia: não há atualizações pendentes.')
            [void](Write-WinForgeUpdateSupportNote -Status $support)
            Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Drivers ficam em Atualizações > Atualizar drivers.')
            Exit-WinForgeAction -Result (Set-WinForgeResultView -Result (New-WinForgeResult -Kind Ok -Detail (Get-WinForgeText 'o Windows está em dia') -Title $title) -Headline (Get-WinForgeText 'O Windows está em dia') -Note (Get-WinForgeText 'Não há atualizações pendentes.'))
            return
        }

        [void](Write-WinForgeUpdateSupportNote -Status $support)

        # As opcionais (BrowseOnly: prévias e drivers opcionais) só aparecem quando o Windows Update não conhece o critério
        # que as deixa de fora; o Windows não as instala sozinho, então elas vêm desmarcadas e com o aviso. Uma versão nova
        # do Windows (Upgrade) também vem desmarcada, mesmo quando o Windows Update a oferece como comum: mudar de versão é
        # uma decisão à parte das atualizações do mês (o Otimizar nem a instala); quem quer, marca.
        $options = @(
            foreach ($update in $updates) {
                $optional = [bool](Get-WinForgeJsonValue -Object $update -Name "BrowseOnly" -Default $false)
                $upgrade = [bool](Get-WinForgeJsonValue -Object $update -Name "Upgrade" -Default $false)
                $parts = @()
                if ($upgrade) { $parts += (Get-WinForgeText 'versão nova do Windows') } elseif ($optional) { $parts += (Get-WinForgeText 'opcional') }
                if ([bool](Get-WinForgeJsonValue -Object $update -Name "Driver" -Default $false)) { $purpose = Get-WinForgeDriverPurposeText -Update $update; $parts += $(if ($purpose) { (Get-WinForgeText 'driver de {0}' "$purpose") } else { (Get-WinForgeText 'driver') }) }
                $parts += Get-WinForgeUpdateSizeText -Update $update
                @{ Key = $update.Id; Label = (Get-WinForgeUpdateOptionLabel -Update $update); Description = ($parts -join " · "); Selected = (-not $optional -and -not $upgrade) }
            }
        )

        if (@($updates | Where-Object { [bool](Get-WinForgeJsonValue -Object $_ -Name "BrowseOnly" -Default $false) -and -not [bool](Get-WinForgeJsonValue -Object $_ -Name "Upgrade" -Default $false) }).Count -gt 0) {
            Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'As opcionais (prévias e drivers opcionais) vêm desmarcadas.')
        }

        if (@($updates | Where-Object { [bool](Get-WinForgeJsonValue -Object $_ -Name "Upgrade" -Default $false) }).Count -gt 0) {
            Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'A versão nova do Windows vem desmarcada: marque-a só se quiser mudar de versão agora.')
        }

        # Na janela, Confirmar só fica disponível com algo marcado: voltar sem escolha é o Cancelar.
        $picked = Read-WinForgeMultiSelect -Message (Get-WinForgeText 'Quais atualizações instalar?') -Options $options

        if ($null -eq $picked -or @($picked).Count -eq 0) {
            Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'Operação cancelada.')
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Skipped -Detail (Get-WinForgeText 'cancelado pelo usuário') -Title $title)
            return
        }

        $chosen = @($updates | Where-Object { @($picked) -contains $_.Id })
        $download = [int64]0

        foreach ($pending in @($chosen | Where-Object { -not $_.Downloaded })) {
            $download += [int64]$pending.Size
        }

        $countText = Format-WinForgeCount -Count $chosen.Count -One (Get-WinForgeText 'atualização') -Many (Get-WinForgeText 'atualizações')
        $needsDownload = @($chosen | Where-Object { -not $_.Downloaded }).Count -gt 0

        Write-WinForgeKeyValue -Label (Get-WinForgeText 'Atualizações escolhidas') -Value $chosen.Count
        Write-WinForgeKeyValue -Label (Get-WinForgeText 'A baixar') -Value $(if (-not $needsDownload) { (Get-WinForgeText 'nada (já estão baixadas)') } elseif ($download -gt 0) { (Get-WinForgeText 'até {0}' "$(Format-WinForgeBytes -Bytes $download)") } else { (Get-WinForgeText 'tamanho não informado') })
        Write-WinForgeFirmwareWarning -Updates $chosen
        if ($needsDownload) { Write-WinForgeMeteredWarning -Bytes $download }
        # Parado no meio, o Windows pode continuar instalando por conta própria.
        Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Não desligue o PC durante a instalação.')
        Write-Host ""

        $question = $(if ($needsDownload) { (Get-WinForgeText 'Baixar e instalar {0}?' "${countText}") } else { (Get-WinForgeText 'Instalar {0}?' "${countText}") })
        $verb = $(if ($needsDownload) { (Get-WinForgeText 'Baixar e instalar') } else { (Get-WinForgeText 'Instalar') })

        if (-not (Confirm-WinForgeAction -Message $question -DefaultKey "S" -YesLabel $verb -NoLabel (Get-WinForgeText 'Cancelar'))) {
            Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'Operação cancelada.')
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Skipped -Detail (Get-WinForgeText 'cancelado pelo usuário') -Title $title)
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
        [void](Set-WinForgeInstallView -Result $final -One (Get-WinForgeText 'atualização instalada') -Many (Get-WinForgeText 'atualizações instaladas') `
                -None $(if ($chosen.Count -eq 1) { (Get-WinForgeText 'A atualização não foi instalada') } else { (Get-WinForgeText 'Nenhuma atualização instalada') }))

        [void](Set-WinForgeInstallErrorView -Result $final)

        if (Test-WinForgeResultFlag -Result $final -Name "RebootRequired") {
            Request-WinForgeInstallRestart -What (Get-WinForgeText 'as atualizações') -Later (Get-WinForgeText 'As atualizações terminam de instalar quando você reiniciar o PC.')
        }
    }
    catch {
        $problem = Get-WinForgeWindowsUpdateProblem -Message $_.Exception.Message -HResult $_.Exception.HResult
        Write-WinForgeStatus -Type Error -Message (Get-WinForgeText 'Não foi possível instalar as atualizações: {0}.' "$problem")
        $final = New-WinForgeResult -Kind Failed -Detail $problem -Title $title
    }

    Exit-WinForgeAction -Result $final
}


function Get-WinForgeAllUpdatesCriteria {
    # A busca do Otimizar: tudo o que não está instalado nem escondido, inclusive as opcionais (BrowseOnly: prévias e
    # drivers opcionais), que a busca padrão deixa de fora: o Otimizar não as instala, mas diz quais ficaram de fora.
    return "IsInstalled=0 and IsHidden=0"
}


function Install-WinForgePendingUpdates {
    <#
    A etapa do Windows Update do Otimizar: procura e instala, sem perguntar, as atualizações que o Windows Update instalaria
    sozinho (as de segurança, as do mês e os drivers que ele traz por conta própria). Ficam de fora uma versão nova do
    Windows (troca o Windows inteiro e leva horas) e as opcionais: os drivers opcionais (a Microsoft só os indica para
    resolver um problema específico; num PC que funciona, um deles pode trazer um driver pior que o do fabricante), um
    firmware opcional (como a BIOS: só com o Windows pedindo) e as prévias (as atualizações antes da hora, que o Otimizar
    desliga; o que elas trazem chega na atualização normal do mês seguinte). Os drivers opcionais continuam em
    Atualizações > Atualizar drivers, desmarcados. O reinício fica para o fim do Otimizar (Data.RebootRequired).
    Sem ninguém olhando, a etapa segue as escolhas que a pessoa fez no Windows: com as atualizações pausadas nas
    Configurações, ela nem procura (o Windows não baixa nem instala nada até o fim da pausa); numa conexão limitada (plano
    de dados), instala só o que já foi baixado, como o Windows, a menos que "Baixar atualizações em conexões limitadas"
    esteja ligado.
    #>
    param (
        [switch]$Embedded,
        [switch]$PassThru
    )

    $title = (Get-WinForgeText 'Atualizar o Windows')

    Enter-WinForgeAction -Title $title -Embedded:$Embedded

    $final = $null
    $pause = Get-WinForgeWindowsUpdatePause

    if ($null -ne $pause) {
        Write-WinForgeStatus -Type Info -Message (Get-WinForgeUpdatePauseText -Pause $pause)
        Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Para retomar, use Atualizações > Windows Update.')
        $final = New-WinForgeResult -Kind Skipped -Detail (Get-WinForgeUpdatePauseText -Pause $pause -Detail) -Title $title

        if ($PassThru) { $final }
        Exit-WinForgeAction -Embedded:$Embedded -Result $final
        return
    }

    try {
        Write-Progress -Activity (Get-WinForgeText 'Procurando atualizações') -Status (Get-WinForgeText 'o Windows Update pode levar alguns minutos para responder')

        try {
            # Sem ninguém esperando (a parte automática do Otimizar), a busca tem mais tempo: a primeira num PC que passou
            # meses sem atualizar pode levar mais de 5 minutos. O Parar continua funcionando durante a espera.
            $search = Find-WinForgeWindowsUpdates -Criteria (Get-WinForgeAllUpdatesCriteria) -TimeoutSeconds $(if ($Embedded) { 1200 } else { 300 })
        }
        finally {
            Write-Progress -Activity (Get-WinForgeText 'Procurando atualizações') -Completed
        }

        if ($null -eq $search.Updates) {
            Write-WinForgeStatus -Type Error -Message (Get-WinForgeText 'Não foi possível consultar o Windows Update: {0}.' "$($search.Problem)")
            Write-WinForgeWindowsUpdateSearchHelp -Problem $search.Problem
            $final = New-WinForgeResult -Kind Failed -Detail (Get-WinForgeText 'não foi possível consultar o Windows Update: {0}' "$($search.Problem)") -Title $title
        }
        else {
            $updates = @($search.Updates)
            $upgrades = @($updates | Where-Object { [bool](Get-WinForgeJsonValue -Object $_ -Name "Upgrade" -Default $false) })
            $optional = @($updates | Where-Object { -not [bool](Get-WinForgeJsonValue -Object $_ -Name "Upgrade" -Default $false) -and [bool](Get-WinForgeJsonValue -Object $_ -Name "BrowseOnly" -Default $false) })
            $firmware = @($optional | Where-Object { Test-WinForgeFirmwareUpdate -Update $_ })
            $drivers = @($optional | Where-Object { [bool](Get-WinForgeJsonValue -Object $_ -Name "Driver" -Default $false) -and -not (Test-WinForgeFirmwareUpdate -Update $_) })
            $previews = @($optional | Where-Object { -not [bool](Get-WinForgeJsonValue -Object $_ -Name "Driver" -Default $false) -and -not (Test-WinForgeFirmwareUpdate -Update $_) })
            $left = @(@($upgrades) + @($optional) | ForEach-Object { [string]$_.Id })
            $chosen = @($updates | Where-Object { $left -notcontains [string]$_.Id })

            # O que fica de fora, numa linha só (o porquê de cada um está no comentário da função).
            $leftNames = @(
                @($upgrades | ForEach-Object { (Get-WinForgeText '{0} (versão nova do Windows)' "$($_.Title)") })
                @($firmware | ForEach-Object { (Get-WinForgeText '{0} (firmware opcional)' "$($_.Title)") })
                @($drivers | ForEach-Object { (Get-WinForgeText '{0} (driver opcional)' "$(Get-WinForgeUpdateOptionLabel -Update $_)") })
                @($previews | ForEach-Object { (Get-WinForgeText '{0} (prévia)' "$(Get-WinForgeUpdateOptionLabel -Update $_)") })
            )

            if ($leftNames.Count -gt 0) {
                Write-WinForgeStatus -Type Info -Message $(if ($leftNames.Count -eq 1) { Get-WinForgeText 'Ficou de fora: {0}.' "$(Join-WinForgeList -Items $leftNames)" } else { Get-WinForgeText 'Ficaram de fora: {0}.' "$(Join-WinForgeList -Items $leftNames)" })
            }

            if ($drivers.Count -gt 0) {
                Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Os drivers opcionais servem para um problema específico; se precisar de um, use Atualizações > Atualizar drivers.')
            }

            # Numa conexão limitada, o Windows Update baixa só as atualizações prioritárias, a menos que a pessoa permita
            # baixar nela; o Otimizar não sabe quais são prioritárias e instala só o que já foi baixado.
            $waiting = @()

            if ($chosen.Count -gt 0 -and (Test-WinForgeMeteredConnection) -and -not (Test-WinForgeMeteredUpdateDownload)) {
                $waiting = @($chosen | Where-Object { -not $_.Downloaded })
                $chosen = @($chosen | Where-Object { $_.Downloaded })
            }

            if ($waiting.Count -gt 0) {
                Write-WinForgeStatus -Type Info -Message $(if ($waiting.Count -eq 1) { (Get-WinForgeText 'A conexão é limitada (plano de dados): 1 atualização ficou para baixar numa conexão sem limite.') } else { (Get-WinForgeText 'A conexão é limitada (plano de dados): {0} atualizações ficaram para baixar numa conexão sem limite.' "$($waiting.Count)") })
            }

            $support = Get-WinForgeUpdateSupportStatus

            if ($chosen.Count -eq 0 -and $waiting.Count -gt 0) {
                [void](Write-WinForgeUpdateSupportNote -Status $support)
                $final = New-WinForgeResult -Kind Skipped -Detail (Get-WinForgeText 'conexão limitada: as atualizações ficam para uma conexão sem limite') -Title $title
            }
            elseif ($chosen.Count -eq 0) {
                if (Test-WinForgeWindowsSupportEnded -Status $support) {
                    [void](Write-WinForgeUpdateSupportNote -Status $support -NothingPending)
                    $final = New-WinForgeResult -Kind Warning -Detail (Get-WinForgeText 'nada pendente, mas este Windows não recebe mais atualizações de segurança') -Title $title
                }
                else {
                    Write-WinForgeStatus -Type Success -Message (Get-WinForgeText 'O Windows está em dia: não há atualizações pendentes.')
                    [void](Write-WinForgeUpdateSupportNote -Status $support)
                    $final = New-WinForgeResult -Kind Ok -Detail (Get-WinForgeText 'o Windows está em dia') -Title $title
                }
            }
            else {
                [void](Write-WinForgeUpdateSupportNote -Status $support)

                $download = [int64]0
                foreach ($pending in @($chosen | Where-Object { -not $_.Downloaded })) { $download += [int64]$pending.Size }

                $countText = Format-WinForgeCount -Count $chosen.Count -One (Get-WinForgeText 'atualização') -Many (Get-WinForgeText 'atualizações')

                # Os nomes aparecem uma vez só, no fim, entre as instaladas.
                Write-WinForgeKeyValue -Label (Get-WinForgeText 'A instalar') -Value $countText

                Write-WinForgeFirmwareWarning -Updates $chosen
                if (@($chosen | Where-Object { -not $_.Downloaded }).Count -gt 0) { Write-WinForgeMeteredWarning -Bytes $download }
                Write-Host ""

                $run = Invoke-WinForgeUpdateInstall -Ids @($chosen | ForEach-Object { $_.Id }) -Criteria (Get-WinForgeAllUpdatesCriteria)

                Write-Host ""
                $final = Get-WinForgeUpdateRunResult -Run $run -Chosen $chosen -Title $title -SectionTitle (Get-WinForgeText 'Atualizações instaladas')
            }
        }
    }
    catch {
        $problem = Get-WinForgeWindowsUpdateProblem -Message $_.Exception.Message -HResult $_.Exception.HResult
        Write-WinForgeStatus -Type Error -Message (Get-WinForgeText 'Não foi possível instalar as atualizações: {0}.' "$problem")
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
    Label vai depois de "o serviço" e de "Serviço" nas frases e no resumo: é o nome sem a palavra "Serviço".
    #>
    return @(
        [PSCustomObject]@{ Name = "wuauserv"; Label = (Get-WinForgeText 'Windows Update'); Default = "Manual"; Stop = $true },
        [PSCustomObject]@{ Name = "bits"; Label = (Get-WinForgeText 'Transferência Inteligente de Plano de Fundo (BITS)'); Default = "Manual"; Stop = $true },
        [PSCustomObject]@{ Name = "cryptsvc"; Label = (Get-WinForgeText 'Criptografia (CryptSvc)'); Default = "Automatic"; Stop = $true },
        [PSCustomObject]@{ Name = "UsoSvc"; Label = (Get-WinForgeText 'Orquestrador de atualizações (UsoSvc)'); Default = "Automatic"; Stop = $false }
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
        [PSCustomObject]@{ Name = "Download"; Label = (Get-WinForgeText 'Downloads do Windows Update'); Path = (Join-Path $windows "SoftwareDistribution\Download"); Keep = $false },
        [PSCustomObject]@{ Name = "DataStore"; Label = (Get-WinForgeText 'Banco de dados do Windows Update'); Path = (Join-Path $windows "SoftwareDistribution\DataStore"); Keep = $true },
        [PSCustomObject]@{ Name = "catroot2"; Label = (Get-WinForgeText 'Catálogo de assinaturas do Windows'); Path = (Join-Path $windows "System32\catroot2"); Keep = $true }
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


function Stop-WinForgeServices {
    <#
    Para os serviços (e os que dependem deles) todos de uma vez e espera até TimeoutSeconds: a espera é a do mais lento,
    e não a soma. Devolve os que não pararam (vazio quando todos pararam). Um serviço "parando" ou "iniciando" recusa o
    pedido de parar: a espera continua e o pedido é repetido, em vez de virar erro; um serviço preso não segura a tela
    para sempre.
    #>
    param (
        [Parameter(Mandatory)][string[]]$Name,
        [int]$TimeoutSeconds = 30
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    $pending = @($Name)

    while ($true) {
        $running = @()

        foreach ($one in $pending) {
            $status = [string](Get-Service -Name $one -ErrorAction Stop).Status

            if ($status -eq "Stopped") { continue }

            $running += $one

            if ($status -in @("Running", "Paused")) {
                try { Stop-Service -Name $one -Force -NoWait -ErrorAction Stop } catch { Write-Verbose "Parar ${one}: $($_.Exception.Message)" }
            }
        }

        $pending = $running

        if ($pending.Count -eq 0 -or (Get-Date) -ge $deadline) { return @($pending) }

        Start-Sleep -Milliseconds 500
    }
}


function Stop-WinForgeService {
    # Para um serviço (Stop-WinForgeServices). $true quando parou.
    param (
        [Parameter(Mandatory)][string]$Name,
        [int]$TimeoutSeconds = 30
    )

    return (@(Stop-WinForgeServices -Name @($Name) -TimeoutSeconds $TimeoutSeconds).Count -eq 0)
}


function Start-WinForgeService {
    <#
    Liga o serviço e espera até TimeoutSeconds que ele fique "Em execução"; um já ligado fica como está. Erro quando o
    Windows recusa, quando o serviço cai logo depois de ligar ou quando o prazo acaba. O Start-Service esperava sem fim por
    um serviço preso em "Iniciando" (o Spooler de Impressão fica assim com um driver de impressora com defeito), e a tela
    parava em "ligando o Spooler de Impressão" até alguém clicar em Parar. Um serviço ainda "Parando" (o pedido de parar
    passou do prazo de quem o parou) recusa o pedido de ligar: o pedido espera ele parar, dentro do mesmo prazo, em vez de
    deixá-lo desligado.
    #>
    param (
        [Parameter(Mandatory)][string]$Name,
        [int]$TimeoutSeconds = 30
    )

    $service = Get-Service -Name $Name -ErrorAction Stop
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    $askedAt = $null

    while ($true) {
        $status = [string]$service.Status

        if ($status -eq "Running") { return }

        if ($null -eq $askedAt -and $status -in @("Stopped", "Paused")) {
            if ($status -eq "Stopped") { $service.Start() } else { $service.Continue() }
            $askedAt = Get-Date
        }
        elseif ($null -ne $askedAt -and $status -eq "Stopped" -and (Get-Date) -ge $askedAt.AddSeconds(3)) {
            # Parado de novo passados uns segundos: o serviço caiu ao ligar, e esperar o prazo inteiro não muda isso.
            throw (Get-WinForgeText 'parou logo depois de ligar')
        }

        if ((Get-Date) -ge $deadline) {
            throw $(if ($status -eq "StopPending") { (Get-WinForgeText 'continua parando depois de {0} segundos' "$TimeoutSeconds") } else { (Get-WinForgeText 'continua ligando depois de {0} segundos' "$TimeoutSeconds") })
        }

        Start-Sleep -Milliseconds 250
        $service.Refresh()
    }
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

    if (-not (Test-Path -LiteralPath $path)) { return (New-WinForgeResult -Kind Skipped -Detail (Get-WinForgeText 'a pasta não existia')) }

    try {
        $item = Get-Item -LiteralPath $path -Force -ErrorAction Stop

        if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            return (New-WinForgeResult -Kind Skipped -Detail (Get-WinForgeText 'a pasta aponta para outro lugar e ficou como está') -Data @{ Linked = $true })
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
        $reason = $(if ($_.Exception -is [System.IO.IOException]) { (Get-WinForgeText 'está em uso') } elseif ($_.Exception -is [System.UnauthorizedAccessException]) { (Get-WinForgeText 'o Windows não deixou mexer') } else { $_.Exception.Message.TrimEnd(".") })
        return (New-WinForgeResult -Kind Failed -Detail (Get-WinForgeText '{0}; ficou como estava' "$reason"))
    }

    return (New-WinForgeResult -Kind Ok -Detail (Get-WinForgeText 'guardado como {0}' "$backupName") -Data @{ Backup = $backup })
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

    if ($Labels.Count -eq 1) { return ((Get-WinForgeText 'o serviço {0} {1}' "$list" "$One")).TrimEnd() }

    return ((Get-WinForgeText 'os serviços {0} {1}' "$list" "$Many")).TrimEnd()
}


function Repair-WinForgeWindowsUpdate {
    <#
    O reparo do Windows Update que a Microsoft indica quando as atualizações falham ou travam: para os serviços, põe de
    lado o cache (Get-WinForgeWindowsUpdateCacheFolders) e liga os serviços de novo. Um serviço desativado (por um
    "otimizador" ou bloqueador) volta antes para o tipo de inicialização padrão do Windows; se não voltar, nada mais é
    feito, porque o cache refeito não adiantaria. Políticas não são mudadas: a tela só diz quando há uma. Os serviços
    voltam a ligar mesmo se algo falhar no meio (finally), e os downloads postos de lado só são apagados depois disso.
    #>
    $title = (Get-WinForgeText 'Corrigir o Windows Update')

    Enter-WinForgeAction -Title $title

    $final = New-WinForgeResult -Kind Ok -Title $title

    try {
        if (-not (Test-WinForgeElevation -Reason (Get-WinForgeText 'Corrigir o Windows Update exige privilégios de Administrador.'))) {
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Failed -Detail (Get-WinForgeText 'requer Administrador') -Title $title)
            return
        }

        Write-Progress -Activity $title -Status (Get-WinForgeText 'lendo os serviços do Windows Update')

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
        $busyText = (Get-WinForgeText 'O Windows Update está instalando atualizações agora: espere terminar.')
        $busyHint = (Get-WinForgeText 'O andamento fica em Atualizações > Windows Update; se o problema continuar, volte aqui.')
        $busyResult = (Get-WinForgeText 'o Windows Update está instalando atualizações agora; espere terminar')

        # A faixa de quando o Windows Update está instalando: o botão abre o andamento dele.
        $busyView = {
            Set-WinForgeResultView -Result (New-WinForgeResult -Kind Skipped -Detail $busyResult -Title $title) -Headline (Get-WinForgeText 'O Windows Update está instalando agora') `
                -Note (Get-WinForgeText 'Espere terminar; se o problema continuar, volte aqui.') -Next "updates.windows" -NextLabel (Get-WinForgeText 'Ver o andamento')
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
            $names = Get-WinForgeServiceNamesText -Labels @($missing | ForEach-Object { $_.Label }) -One (Get-WinForgeText 'não existe') -Many (Get-WinForgeText 'não existem')
            Write-WinForgeStatus -Type Error -Message (Get-WinForgeText '{0}{1} neste Windows, e este reparo não o recria.' "$($names.Substring(0, 1).ToUpper())" "$($names.Substring(1))")
            Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Reparo > Recuperação pode reinstalar o Windows mantendo os seus arquivos.')
            $gone = New-WinForgeResult -Kind Failed -Detail (Get-WinForgeText '{0} neste Windows' "$names") -Title $title
            Exit-WinForgeAction -Result (Set-WinForgeResultView -Result $gone -Headline $(if ($missing.Count -eq 1) { (Get-WinForgeText 'Falta um serviço do Windows Update') } else { (Get-WinForgeText 'Faltam serviços do Windows Update') }) `
                    -Note (Get-WinForgeText 'A Recuperação pode reinstalar o Windows mantendo os seus arquivos.') -Next "repair.recovery" -NextLabel (Get-WinForgeText 'Abrir a Recuperação'))
            return
        }

        if ($unread.Count -gt 0) {
            $names = Get-WinForgeServiceNamesText -Labels @($unread | ForEach-Object { $_.Label })
            Write-WinForgeStatus -Type Error -Message (Get-WinForgeText 'O Windows não respondeu sobre {0}.' "$names")
            Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Isso costuma ser dano nos arquivos do Windows: use Reparo > Reparar o Windows (DISM + SFC).')
            $silent = New-WinForgeResult -Kind Failed -Detail (Get-WinForgeText 'o Windows não respondeu sobre {0}' "$names") -Title $title
            Exit-WinForgeAction -Result (Set-WinForgeResultView -Result $silent -Headline (Get-WinForgeText 'Os serviços do Windows Update não responderam') `
                    -Note (Get-WinForgeText 'Isso costuma ser dano nos arquivos do Windows.') -Next "repair.dism-sfc" -NextLabel (Get-WinForgeText 'Reparar o Windows'))
            return
        }

        # O reparo desliga os serviços, põe de lado o cache (os downloads, o banco de dados e o catálogo de assinaturas) e
        # liga os serviços de novo, como a Microsoft indica. O que a pessoa precisa saber antes: o histórico some.
        Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Refaz o cache do Windows Update: as atualizações instaladas ficam, mas o histórico delas recomeça vazio.')

        $disabled = @($services | Where-Object { $_.State.StartType -eq "Disabled" })

        foreach ($service in $disabled) {
            Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'O serviço {0} está desativado: ele volta para o padrão do Windows ({1}).' "$($service.Label)" "$(if ($service.Default -eq 'Manual') { (Get-WinForgeText 'manual') } else { (Get-WinForgeText 'automático') })")
        }

        if ([string](Get-WinForgeJsonValue -Object $medic -Name "StartType" -Default "") -eq "Disabled") {
            # O Medic conserta o Windows Update sozinho; o Windows o protege, e o WinForge não mexe nele.
            Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'O serviço Windows Update Medic (WaaSMedicSvc) está desativado: desfaça pelo programa que o desativou.')
        }

        if (Write-WinForgeWindowsUpdatePolicyNote) {
            Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'O reparo não muda políticas.')
        }

        Write-Host ""

        if ($pending) {
            Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'Há um reinício pendente: reinicie antes, muitas vezes isso já resolve.')

            $answer = Read-WinForgePendingRebootChoice -Question (Get-WinForgeText 'Reiniciar antes de corrigir?') -Then (Get-WinForgeText 'Se o problema continuar, volte aqui') `
                -Reason (Get-WinForgeText 'Reinicie agora e, se o problema continuar, abra Atualizações > Corrigir o Windows Update de novo.') `
                -Comment (Get-WinForgeText 'Reinicialização solicitada pelo WinForge (reinício pendente antes de corrigir o Windows Update).') `
                -DeclinedMessage (Get-WinForgeText 'Reinicialização não iniciada. Reinicie o PC e, se o problema continuar, volte aqui.')

            if ($answer -eq "Restarting") {
                Exit-WinForgeAction -Result (New-WinForgeResult -Kind Skipped -Detail (Get-WinForgeText 'o PC está reiniciando') -Title $title)
                return
            }

            if ($answer -ne "Continue") {
                Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'Operação cancelada.')
                Exit-WinForgeAction -Result (New-WinForgeResult -Kind Skipped -Detail (Get-WinForgeText 'cancelado pelo usuário') -Title $title)
                return
            }
        }
        elseif (-not (Confirm-WinForgeAction -Message (Get-WinForgeText 'Corrigir o Windows Update agora?') -DefaultKey "S" -YesLabel (Get-WinForgeText 'Corrigir') -NoLabel (Get-WinForgeText 'Cancelar'))) {
            Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'Operação cancelada.')
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Skipped -Detail (Get-WinForgeText 'cancelado pelo usuário') -Title $title)
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
                $row = New-WinForgeResult -Kind Ok -Detail (Get-WinForgeText 'voltou para {0}' "$(if ($service.Default -eq 'Manual') { (Get-WinForgeText 'manual') } else { (Get-WinForgeText 'automático') })")
            }
            catch {
                $stillDisabled += $service.Label
                $row = New-WinForgeResult -Kind Failed -Detail (Get-WinForgeText 'continua desativado: {0}' "$($_.Exception.Message.TrimEnd('.'))")
            }

            $row.Etapa = (Get-WinForgeText 'Serviço {0}' "$($service.Label)")
            $rows += $row
        }

        if ($restored.Count -gt 0) {
            [void](Add-WinForgeChange -Action (Get-WinForgeText 'Corrigir o Windows Update') -Text (Get-WinForgeText '{0} ao padrão do Windows' "$(Get-WinForgeServiceNamesText -Labels $restored -One (Get-WinForgeText 'voltou') -Many (Get-WinForgeText 'voltaram'))"))
        }

        if ($stillDisabled.Count -gt 0) {
            $names = Get-WinForgeServiceNamesText -Labels $stillDisabled -One (Get-WinForgeText 'continua desativado') -Many (Get-WinForgeText 'continuam desativados')
            Write-WinForgeSection -Title (Get-WinForgeText 'Resumo')
            Write-WinForgeResultTable -Results $rows
            Write-WinForgeStatus -Type Warning -Message $(if ($stillDisabled.Count -eq 1) { (Get-WinForgeText '{0}{1}, e sem ele o Windows Update não funciona; um bloqueador de atualizações pode estar travando isso.' "$($names.Substring(0, 1).ToUpper())" "$($names.Substring(1))") } else { (Get-WinForgeText '{0}{1}, e sem eles o Windows Update não funciona; um bloqueador de atualizações pode estar travando isso.' "$($names.Substring(0, 1).ToUpper())" "$($names.Substring(1))") })
            $blocked = New-WinForgeResult -Kind Warning -Detail (Get-WinForgeText '{0}; o cache não foi mexido' "$names") -Title $title
            Exit-WinForgeAction -Result (Set-WinForgeResultView -Result $blocked -Headline $(if ($stillDisabled.Count -eq 1) { (Get-WinForgeText 'Um serviço do Windows Update continua desativado') } else { (Get-WinForgeText 'Serviços do Windows Update continuam desativados') }) `
                    -Note (Get-WinForgeText 'Um bloqueador de atualizações pode estar travando isso. O cache não foi mexido.'))
            return
        }

        # 2. Para os serviços e põe o cache de lado; 3. liga tudo de novo (finally); 4. apaga os downloads postos de lado.
        $stopping = @($services | Where-Object { $_.Stop })
        $restart = New-Object System.Collections.ArrayList
        $moved = @()
        $stopProblem = ""

        try {
            Write-Progress -Activity $title -Status (Get-WinForgeText 'desligando os serviços do Windows Update')

            # Quem depende de um serviço para junto com ele (Stop-Service -Force): esses voltam a ligar no fim.
            foreach ($service in $stopping) {
                foreach ($dependent in @($service.State.Dependents)) { if (-not $restart.Contains($dependent)) { [void]$restart.Add($dependent) } }
            }

            # Os três param juntos: a espera é a do mais lento, e não a soma.
            $stoppingNames = @($stopping | ForEach-Object { [string]$_.Name })
            $notStopped = @(Stop-WinForgeServices -Name $stoppingNames)

            if ($notStopped.Count -gt 0) {
                $stuck = @($stopping | Where-Object { $_.Name -eq $notStopped[0] }) | Select-Object -First 1
                $stopProblem = (Get-WinForgeText 'o serviço {0} não parou em 30 segundos' "$($stuck.Label)")
            }

            if (-not $stopProblem) {
                foreach ($folder in @(Get-WinForgeWindowsUpdateCacheFolders)) {
                    Write-Progress -Activity $title -Status (Get-WinForgeText 'pondo de lado: {0}' "$($folder.Label)")

                    # Outro serviço (o orquestrador de atualizações) pode religar o Windows Update a qualquer momento.
                    try { [void](Stop-WinForgeServices -Name $stoppingNames -TimeoutSeconds 10) } catch { Write-Verbose "Parar os serviços: $($_.Exception.Message)" }

                    $row = Move-WinForgeUpdateCacheFolder -Folder $folder
                    $row.Etapa = $folder.Label
                    $rows += $row

                    if ($row.Kind -eq "Ok") { $moved += [PSCustomObject]@{ Folder = $folder; Row = $row } }
                }
            }
        }
        catch {
            $stopProblem = (Get-WinForgeText 'não foi possível desligar os serviços: {0}' "$($_.Exception.Message.TrimEnd('.'))")
        }
        finally {
            Write-Progress -Activity $title -Status (Get-WinForgeText 'ligando os serviços de novo')
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
            $text = $(if (Remove-WinForgeUpdateCacheBackup -Path $backup) { (Get-WinForgeText 'apagados; o Windows baixa de novo o que precisar') } else { (Get-WinForgeText 'postos de lado em {0}' "$(Split-Path -Leaf $backup)") })
            $entry.Row.Detail = $text
            $entry.Row.Status = "OK ($text)"
        }

        $movedNames = @($moved | ForEach-Object { [string]$_.Folder.Name })

        if ($movedNames.Count -gt 0) {
            [void](Add-WinForgeChange -Action (Get-WinForgeText 'Corrigir o Windows Update') -Text (Get-WinForgeText 'cache refeito ({0})' "$(Join-WinForgeList -Items $movedNames)"))
        }

        $labels = @{}
        foreach ($service in $services) { $labels[$service.Name] = $service.Label }
        $notStartedText = Join-WinForgeList -Items @($notStarted | ForEach-Object { if ($labels.ContainsKey($_)) { $labels[$_] } else { $_ } })

        if ($rows.Count -gt 0) {
            Write-WinForgeSection -Title (Get-WinForgeText 'Resumo')
            Write-WinForgeResultTable -Results $rows
        }

        $folderFailed = @($rows | Where-Object { $_.Kind -eq "Failed" -and $_.Etapa -notlike (Get-WinForgeText 'Serviço {0}' '*') })
        $linked = @($rows | Where-Object { Test-WinForgeResultFlag -Result $_ -Name "Linked" })

        if ($stopProblem) {
            $touched = $(if ($movedNames.Count -gt 0) { (Get-WinForgeText 'Só parte do cache foi refeita ({0}).' "$(Join-WinForgeList -Items $movedNames)") } else { (Get-WinForgeText 'Nada do cache foi mexido.') })
            Write-WinForgeStatus -Type Error -Message (Get-WinForgeText 'Não foi possível terminar a correção: {0}. {1}' "$stopProblem" "$touched")
            Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Reinicie o PC e tente de novo.')
            $final = New-WinForgeResult -Kind Failed -Detail "$stopProblem; $($touched.TrimEnd('.').ToLower())" -Title $title
            [void](Set-WinForgeResultView -Result $final -Headline (Get-WinForgeText 'O Windows Update não foi corrigido') -Note "$touched $(Get-WinForgeText 'Reinicie o PC e tente de novo.')")
        }
        elseif ($notStarted.Count -gt 0) {
            Write-WinForgeStatus -Type Warning -Message $(if ($notStarted.Count -eq 1) { (Get-WinForgeText 'Não foi possível ligar de novo: {0}. Reinicie o PC para o Windows ligá-lo.' "$notStartedText") } else { (Get-WinForgeText 'Não foi possível ligar de novo: {0}. Reinicie o PC para o Windows ligá-los.' "$notStartedText") })
            $final = New-WinForgeResult -Kind Warning -Detail (Get-WinForgeText 'cache refeito, mas não ligou de novo: {0}; reinicie o PC' "$notStartedText") -Title $title -Data @{ RebootRequired = $true }
            [void](Set-WinForgeResultView -Result $final -Headline (Get-WinForgeText 'Reinicie para terminar a correção') -Note (Get-WinForgeText 'O cache foi refeito; os serviços voltam a ligar quando o PC reiniciar.'))
            Request-WinForgeRestartOffer -Reason (Get-WinForgeText 'Reiniciar liga de novo os serviços do Windows Update.') `
                -Comment (Get-WinForgeText 'Reinicialização solicitada pelo WinForge para ligar os serviços do Windows Update.') `
                -DeclinedMessage (Get-WinForgeText 'Reinicialização não iniciada. Os serviços voltam a ligar quando você reiniciar o PC.')
        }
        elseif ($folderFailed.Count -gt 0) {
            $names = Join-WinForgeList -Items @($folderFailed | ForEach-Object { $_.Etapa })
            Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Reinicie o PC e rode a correção de novo.')
            $final = New-WinForgeResult -Kind Warning -Detail (Get-WinForgeText 'ficou como estava: {0}' "$names") -Title $title
            [void](Set-WinForgeResultView -Result $final -Headline (Get-WinForgeText 'O cache foi refeito só em parte') -Note (Get-WinForgeText 'Reinicie o PC e rode a correção de novo.'))
        }
        elseif ($linked.Count -gt 0) {
            $names = Join-WinForgeList -Items @($linked | ForEach-Object { $_.Etapa })
            # Quase sempre um programa que mudou o cache de disco; o WinForge não mexe do outro lado.
            $linkedText = $(if ($linked.Count -eq 1) { (Get-WinForgeText '{0} aponta para outra pasta: desfaça pelo programa que mudou isso.' "$names") } else { (Get-WinForgeText '{0} apontam para outra pasta: desfaça pelo programa que mudou isso.' "$names") })
            Write-WinForgeStatus -Type Info -Message $linkedText
            $final = New-WinForgeResult -Kind Warning -Detail (Get-WinForgeText 'cache refeito em parte; {0} aponta para outro lugar e ficou como está' "$names") -Title $title
            [void](Set-WinForgeResultView -Result $final -Headline (Get-WinForgeText 'O cache foi refeito só em parte') -Note $linkedText)
        }
        else {
            Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Agora use Atualizações > Instalar atualizações do Windows; a primeira busca demora mais.')
            $final = New-WinForgeResult -Kind Ok -Detail (Get-WinForgeText 'cache do Windows Update refeito e serviços ligados de novo') -Title $title
            [void](Set-WinForgeResultView -Result $final -Headline (Get-WinForgeText 'Cache do Windows Update refeito') -Note (Get-WinForgeText 'Os serviços estão ligados de novo. A primeira busca por atualizações demora mais.') `
                    -Next "updates.install" -NextLabel (Get-WinForgeText 'Procurar atualizações'))
        }
    }
    catch {
        Write-WinForgeStatus -Type Error -Message (Get-WinForgeText 'Não foi possível corrigir o Windows Update: {0}.' "$($_.Exception.Message.TrimEnd('.'))")
        $final = New-WinForgeResult -Kind Failed -Detail $_.Exception.Message.TrimEnd(".") -Title $title
    }

    Exit-WinForgeAction -Result $final
}

Export-ModuleMember -Function *
