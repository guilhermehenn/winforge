# Reparo e otimização: DISM, SFC, CHKDSK e otimização da unidade do sistema.
# Todas as ações aceitam -Embedded (sem cabeçalho, pergunta nem pausa, para uso dentro do Otimizar)
# e -PassThru (devolve um WinForge.Result em vez de não devolver nada).

$script:WinForgeChkdskRepairPending = $false


# ---------------------------------------------------------------------------
# Interpretação das saídas
# ---------------------------------------------------------------------------

function Test-WinForgeDismRepairNeeded {
    param (
        [int]$ExitCode,
        [string]$OutputText
    )

    # /CheckHealth só lê marcações já registradas pelo Windows; é rápido e evita um RestoreHealth desnecessário.
    # Os trechos aceitam letras trocadas ("corrup" basta): a saída do DISM depende do idioma e da página de código.
    if ($OutputText -match "(?i)no component store corruption|nenhuma corrup") {
        return $false
    }

    if ($OutputText -match "(?i)repairable|repar.{1,3}vel|corrupt|corromp") {
        return $true
    }

    return ($ExitCode -ne 0)
}


function Get-WinForgeDismHealthState {
    <#
    O estado do repositório de componentes sem ler texto: Healthy (sem dano marcado), Repairable (dano que o
    /RestoreHealth conserta), NonRepairable (precisa de mais que isso) ou Unknown (não deu para consultar). Usa o
    Repair-WindowsImage -CheckHealth, que devolve o estado como valor e não como frase; sem ele cai na leitura do
    texto do dism.exe /CheckHealth. Text traz a saída do dism.exe, quando foi ele quem respondeu; Code, o código de
    saída do dism.exe quando a consulta falhou (Unknown).
    #>
    $state = "Unknown"

    try {
        $image = Repair-WindowsImage -Online -CheckHealth -ErrorAction Stop

        if ($null -ne $image -and $null -ne $image.PSObject.Properties["ImageHealthState"]) {
            $state = [string]$image.ImageHealthState
        }
    }
    catch {
        $state = "Unknown"
    }

    if ($state -in @("Healthy", "Repairable", "NonRepairable")) {
        return [PSCustomObject]@{ State = $state; Text = ""; Source = "Repair-WindowsImage"; Code = "" }
    }

    $check = Invoke-WinForgeCapture -FilePath "dism.exe" -Arguments @("/Online", "/Cleanup-Image", "/CheckHealth") -Echo
    $text = [string]$check.Text
    $exitCode = [int]$check.ExitCode

    # Um DISM que falhou sem dizer nada sobre o repositório (reinício pendente, 0x800F082F; serviço sem resposta) não
    # consultou nada: isso não é "dano marcado", é "não sei".
    $saysHealthy = ($text -match "(?i)no component store corruption|nenhuma corrup")
    $saysDamaged = Test-WinForgeDismRepairNeeded -ExitCode 0 -OutputText $text

    # "The component store cannot be repaired." não tem "corrupt" nem "repairable": sem esta frase, com o código 0, o
    # repositório que nem o DISM conserta passava por saudável e o /RestoreHealth não rodava antes do SFC.
    if (-not $saysHealthy -and $text -match "(?i)cannot be repaired|n.{1,3}o pode ser reparad") {
        return [PSCustomObject]@{ State = "NonRepairable"; Text = $text; Source = "dism.exe"; Code = "" }
    }

    if ($exitCode -ne 0 -and -not $saysHealthy -and -not $saysDamaged) {
        return [PSCustomObject]@{ State = "Unknown"; Text = $text; Source = "dism.exe"; Code = (Format-WinForgeExitCode -ExitCode $exitCode) }
    }

    $needed = Test-WinForgeDismRepairNeeded -ExitCode $exitCode -OutputText $text

    return [PSCustomObject]@{ State = $(if ($needed) { "Repairable" } else { "Healthy" }); Text = $text; Source = "dism.exe"; Code = "" }
}


function Test-WinForgeChkdskRepairRequired {
    param (
        [int]$ExitCode,
        [string]$OutputText
    )

    # Códigos do CHKDSK: 0 = sem erros; 1 = erros encontrados e corrigidos;
    # 2 = limpeza/avisos sem /f (não exige reparo offline por si só); 3 = não foi possível verificar/reparar.
    # O código de saída e o nome do comando (/spotfix) não mudam com o idioma; as frases, sim (e aceitam letras trocadas).
    if ($ExitCode -ge 3) {
        return $true
    }

    return (
        $OutputText -match "(?i)spotfix" -or
        $OutputText -match "(?i)offline repair" -or
        $OutputText -match "(?i)reparo offline" -or
        $OutputText -match "(?i)next restart" -or
        $OutputText -match "(?i)pr.{1,3}xima reinicializa"
    )
}


function Get-WinForgeCbsLogPath {
    # Montado como texto: o caminho também aparece na tela, e o Join-Path recusaria uma unidade que não existe.
    $windows = $env:SystemRoot
    if ([string]::IsNullOrWhiteSpace($windows)) { $windows = "C:\Windows" }

    return ($windows.TrimEnd("\") + "\Logs\CBS\CBS.log")
}


function Read-WinForgeCbsLogTail {
    # O final do CBS.log (o arquivo pode ter centenas de megabytes e está em uso pelo Windows). Devolve as linhas,
    # ou lista vazia se não for possível ler.
    param ([int]$MaxBytes = 8MB)

    try {
        $path = Get-WinForgeCbsLogPath

        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return @() }

        $stream = New-Object System.IO.FileStream ($path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)

        try {
            if ($stream.Length -gt $MaxBytes) { [void]$stream.Seek(-$MaxBytes, [System.IO.SeekOrigin]::End) }

            $reader = New-Object System.IO.StreamReader ($stream, [System.Text.Encoding]::UTF8)
            $text = $reader.ReadToEnd()
        }
        finally {
            $stream.Dispose()
        }

        return @($text -split "\r?\n")
    }
    catch {
        return @()
    }
}


function Get-WinForgeSfcLogFileName {
    # O nome do arquivo numa linha [SR] do CBS.log, sem a pasta: "[l:16]'WSHost.exe' of ..." (Windows 10 e 11),
    # "[l:14{7}]"url.dll" of ..." (formato da documentação), "\??\C:\WINDOWS\WinStore\\WSHost.exe; ..." ou
    # "[ml:...]"??\C:\WINDOWS\WinStore"[l:20{10}]"WSHost.exe"; ...". "" quando não há nome reconhecível.
    param ([string]$Text)

    $name = ""

    if ($Text -match "^\s*\[[^\]]*\]'([^']+)'") { $name = $Matches[1] }
    else {
        $quoted = @([regex]::Matches(($Text -split ";")[0], '"([^"]+)"') | ForEach-Object { $_.Groups[1].Value })

        if ($quoted.Count -gt 0) { $name = $quoted[$quoted.Count - 1] }
        else { $name = (($Text -split ";")[0] -split " of ")[0].Trim() }
    }

    $name = ($name -split "\\")[-1].Trim()

    return $name
}


function Get-WinForgeSfcLogSummary {
    <#
    O que o CBS.log registrou do SFC desde $Since (as linhas [SR] não mudam com o idioma do Windows). CannotRepair =
    arquivos que o SFC não conseguiu reparar, cada um uma vez: o SFC repete "Cannot repair member file" a cada passada
    e ainda escreve "Could not reproject corrupted file" para o mesmo arquivo. CannotRepairNames = os nomes desses
    arquivos; Repaired = linhas de arquivos reparados. Linhas sem data (continuações) valem para a última data lida.
    Um arquivo que aparece como "sem reparo" e depois como reparado ("Repairing corrupted file", "Repaired file") sai da
    lista: o SFC tenta de novo por outro caminho e consegue.
    O CBS.log grava a hora sem frações de segundo: a margem de 2 segundos cobre isso sem alcançar uma passada anterior.
    #>
    param (
        [AllowEmptyCollection()][string[]]$Lines = @(),
        [Parameter(Mandatory)][datetime]$Since
    )

    $limit = $Since.AddSeconds(-2)
    $current = $null
    $cannot = [ordered]@{}
    $unnamed = 0
    $repaired = 0

    foreach ($line in @($Lines)) {
        if ($line -match '^([0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2})') {
            try { $current = [datetime]::ParseExact($Matches[1], "yyyy-MM-dd HH:mm:ss", [System.Globalization.CultureInfo]::InvariantCulture) } catch { $current = $null }
        }

        if ($null -eq $current -or $current -lt $limit) { continue }

        if ($line -match '\[SR\] (Cannot repair member file|Could not reproject corrupted file)(.*)$') {
            $name = Get-WinForgeSfcLogFileName -Text $Matches[2]

            if ($name) {
                $key = $name.ToLowerInvariant()
                if (-not $cannot.Contains($key)) { $cannot[$key] = $name }
            }
            else {
                $unnamed++
            }
        }
        elseif ($line -match '\[SR\] (Repairing (corrupted )?file|Repaired file)(.*)$') {
            $repaired++
            # "... WSHost.exe from store" e "... by copying from backup": a origem do reparo não faz parte do nome.
            $name = Get-WinForgeSfcLogFileName -Text ($Matches[3] -replace '\s+(from store|by copying).*$', '')

            if ($name) { $cannot.Remove($name.ToLowerInvariant()) }
        }
    }

    # Sem nenhum nome legível, o total são as linhas: o fato de haver arquivos sem reparo continua valendo.
    $count = $cannot.Count
    if ($count -eq 0) { $count = $unnamed }

    return [PSCustomObject]@{
        CannotRepair      = $count
        CannotRepairNames = @($cannot.Values)
        Repaired          = $repaired
    }
}


function Format-WinForgeExitCode {
    # Códigos pequenos ficam em decimal ("87"); os negativos ou grandes (HRESULT do DISM, como 0x800F081F) vão em
    # hexadecimal, que é como se pesquisa o erro.
    param ([int]$ExitCode)

    if ($ExitCode -lt 0 -or $ExitCode -gt 65535) {
        return ("0x{0:X8}" -f $ExitCode)
    }

    return [string]$ExitCode
}


function Get-WinForgeSfcUnrepairedResult {
    # A ressalva "o SFC não reparou tudo": com o CBS.log lido, diz quantos arquivos e quais; sem ele, só o fato.
    param ($LogSummary = $null)

    # A quantidade só é dita quando os nomes foram lidos (linhas sem nome podem repetir o mesmo arquivo).
    $names = @()

    if ($null -ne $LogSummary) {
        $names = @($LogSummary.CannotRepairNames | Where-Object { $_ })
    }

    $count = $names.Count
    $detail = "há arquivos corrompidos que o SFC não conseguiu reparar"

    if ($count -eq 1) { $detail = "1 arquivo corrompido não pôde ser reparado" }
    elseif ($count -gt 1) { $detail = "$count arquivos corrompidos não puderam ser reparados" }

    $notes = @()

    if ($count -gt 0) {
        $shown = @($names | Select-Object -First 5)
        $text = Join-WinForgeList -Items $shown
        if ($count -gt $shown.Count) { $text = ($shown -join ", ") + " e mais $($count - $shown.Count)" }
        $notes += "Arquivos que o SFC não reparou: $text."
    }

    $notes += "O registro completo fica em $(Get-WinForgeCbsLogPath)."

    return (New-WinForgeResult -Kind Warning -Detail $detail -Data @{ Unrepaired = $true; Notes = $notes })
}


function Get-WinForgeSfcResult {
    # O SFC devolve 0 mesmo quando encontra arquivos que não consegue reparar; a conclusão está no texto. As frases
    # mudam com o idioma e a página de código (aceitam letras trocadas), então o CBS.log (LogSummary) confirma.
    param (
        [int]$ExitCode,
        [string]$OutputText,
        $LogSummary = $null
    )

    if ($OutputText -match "(?i)repair pending|reparo.{0,40}pendente|requires reboot|requer.{0,20}rein|exige.{0,20}reinicializa") {
        return (New-WinForgeResult -Kind Warning -Detail "há um reparo do Windows pendente; depois de reiniciar, rode o SFC de novo" -Data @{ RebootRequired = $true })
    }

    if ($OutputText -match "(?i)unable to fix|n.{1,3}o p.{1,3}de (corrigir|reparar)|n.{1,3}o foi poss.{1,3}vel (corrigir|reparar)|n.{1,3}o conseguiu (corrigir|reparar)") {
        # Unrepaired: quem chama (DISM + SFC) usa o fato para decidir se vale reparar a imagem e repetir o SFC.
        return (Get-WinForgeSfcUnrepairedResult -LogSummary $LogSummary)
    }

    # O SFC pode avisar que não conseguiu rodar e ainda assim sair com código 0; isso não é "tudo certo".
    if ($OutputText -match "(?i)could not (perform|start)|n.{1,3}o p.{1,3}de (executar|iniciar)") {
        # O SFC depende do serviço Instalador de Módulos do Windows (TrustedInstaller); desativado por algum "otimizador",
        # o SFC nem começa.
        return (New-WinForgeResult -Kind Failed -Detail "o SFC não conseguiu executar a verificação" -Data @{ Notes = @("Se o serviço Instalador de Módulos do Windows estiver desativado, volte-o para Manual, reinicie e tente de novo.") })
    }

    $saysRepaired = ($OutputText -match "(?i)successfully repaired|reparou com .{1,3}xito|reparad[oa]s? com .{1,3}xito")
    $saysClean = ($OutputText -match "(?i)did not find any integrity violations|n.{1,3}o encontrou nenhuma viola")

    # O CBS.log só decide quando o SFC não disse com clareza como terminou. A Microsoft documenta linhas "Cannot repair
    # member file" de arquivos que o SFC não protege, enquanto ele mesmo diz que deu tudo certo: com elas valendo mais que
    # a frase, a Manutenção avisava de arquivos não reparados (e repetia DISM e SFC, de 30 a 60 minutos) todo mês.
    if (-not $saysRepaired -and -not $saysClean -and $null -ne $LogSummary -and [int]$LogSummary.CannotRepair -gt 0) {
        return (Get-WinForgeSfcUnrepairedResult -LogSummary $LogSummary)
    }

    if ($ExitCode -ne 0) {
        return (New-WinForgeResult -Kind Failed -Detail "código de saída $(Format-WinForgeExitCode -ExitCode $ExitCode)")
    }

    # Sfc: o que o SFC concluiu, para a faixa (Repaired ou Clean).
    if ($saysRepaired -or ($null -ne $LogSummary -and [int]$LogSummary.Repaired -gt 0)) {
        return (New-WinForgeResult -Kind Ok -Detail "arquivos corrompidos foram encontrados e reparados" -Data @{ Sfc = "Repaired" })
    }

    if ($saysClean) {
        return (New-WinForgeResult -Kind Ok -Detail "nenhum arquivo corrompido foi encontrado" -Data @{ Sfc = "Clean" })
    }

    return (New-WinForgeResult -Kind Ok)
}


function Get-WinForgeExitCodeResult {
    # Resultado padrão de ferramentas do sistema: 0 = OK; 3010 = OK, mas exige reinício; outros = falha.
    # OutputText existe só para ter a mesma assinatura dos demais analisadores de resultado (SFC): este não lê o texto.
    param (
        [int]$ExitCode,
        [string]$OutputText
    )

    if ($ExitCode -eq 0) {
        return (New-WinForgeResult -Kind Ok)
    }

    if ($ExitCode -eq 3010) {
        # A faixa da janela já acrescenta "Reinicie o PC para concluir."; o detalhe só diz o que falta.
        return (New-WinForgeResult -Kind Warning -Detail "o Windows termina a operação na próxima reinicialização" -Data @{ RebootRequired = $true })
    }

    return (New-WinForgeResult -Kind Failed -Detail "código de saída $(Format-WinForgeExitCode -ExitCode $ExitCode)")
}


function Get-WinForgeDismResult {
    <#
    O DISM /RestoreHealth: os códigos comuns de falha viram uma frase (o código vai junto, para pesquisa)
    e uma dica do que fazer. Os três códigos são os da documentação da Microsoft para "arquivos de origem não
    encontrados", "não foi possível baixá-los" e "uma política de rede impediu o download".
    #>
    param (
        [int]$ExitCode,
        [string]$OutputText
    )

    # O DISM busca os arquivos do reparo no Windows Update; num PC de empresa, a política ou o WSUS é que decide.
    # 0x80070422: um "bloqueador de atualizações" costuma desativar o serviço; o Corrigir o Windows Update o volta ao padrão.
    $code = Format-WinForgeExitCode -ExitCode $ExitCode
    $internet = "Confira a internet e o Windows Update (Atualizações > Instalar atualizações do Windows) e tente de novo."
    $company = "Num PC de empresa, fale com o suporte de TI."

    switch ($code) {
        "0x800F081F" { return (New-WinForgeResult -Kind Failed -Detail "o DISM não encontrou os arquivos de que precisa para o reparo — erro $code" -Data @{ Notes = @($internet) }) }
        "0x800F0906" { return (New-WinForgeResult -Kind Failed -Detail "o DISM não conseguiu baixar os arquivos de que precisa para o reparo — erro $code" -Data @{ Notes = @($internet) }) }
        "0x800F0907" { return (New-WinForgeResult -Kind Failed -Detail "uma política de rede impediu o DISM de baixar os arquivos do reparo — erro $code" -Data @{ Notes = @($company) }) }
        "0x800F0954" { return (New-WinForgeResult -Kind Failed -Detail "o PC busca atualizações num servidor da empresa (WSUS), sem os arquivos do reparo — erro $code" -Data @{ Notes = @($company, "Num PC de casa, um bloqueador de atualizações pode ter feito isso: desfaça por ele e tente de novo.") }) }
        "0x80070422" { return (New-WinForgeResult -Kind Failed -Detail "um serviço de que o DISM precisa está desativado (em geral, o Windows Update) — erro $code" -Data @{ Notes = @("Use Atualizações > Corrigir o Windows Update para religar o serviço.") }) }
    }

    # Operações do Windows esperando um reinício (0x800F0806 é o CBS_E_PENDING; 0x800F082F e o 3017 aparecem no mesmo
    # caso): o DISM não repara antes disso, e o que resolve é reiniciar.
    if ($code -in @("0x800F0806", "0x800F082F", "3017")) {
        return (New-WinForgeResult -Kind Failed -Detail "o Windows espera um reinício para terminar outra instalação, e o DISM só repara depois disso — erro $code" -Data @{ RebootRequired = $true; Notes = @("Reinicie o PC e rode o reparo de novo.") })
    }

    if ($ExitCode -eq 0) {
        if ($OutputText -match "(?i)corruption was repaired|corrup.{0,40}(foi|foram) reparad") {
            return (New-WinForgeResult -Kind Ok -Detail "a imagem do Windows tinha danos e foi reparada" -Data @{ ImageRepaired = $true })
        }

        return (New-WinForgeResult -Kind Ok -Detail "a imagem do Windows está íntegra")
    }

    if ($ExitCode -eq 3010) {
        return (New-WinForgeResult -Kind Warning -Detail "o reparo da imagem termina na próxima reinicialização" -Data @{ RebootRequired = $true })
    }

    return (Get-WinForgeExitCodeResult -ExitCode $ExitCode -OutputText $OutputText)
}


# ---------------------------------------------------------------------------
# Executor comum
# ---------------------------------------------------------------------------

function Test-WinForgeWindowsBuildBelow {
    # Verdadeiro quando este Windows 10 ou 11 é mais antigo que o build pedido. Sem um build do Windows 10 ou mais novo
    # (leitura falhou), devolve falso: a ferramenta roda e diz o que houver.
    param ([Parameter(Mandatory)][int]$Minimum)

    $build = [int](Get-WinForgeWindowsBuild)

    return ($build -ge 10240 -and $build -lt $Minimum)
}


function Write-WinForgeToolOutcome {
    # A linha final de uma ferramenta: o nome da etapa e o que aconteceu (o ícone já diz se deu certo), seguida das
    # observações que o analisador anexou (Notes: arquivos não reparados, o que fazer diante de um código conhecido).
    param (
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)]$Result
    )

    $detail = ([string]$Result.Detail).Trim().TrimEnd(".")

    switch ($Result.Kind) {
        "Ok" {
            $text = $(if ($detail) { $detail } else { "concluído" })
            Write-WinForgeStatus -Type Success -Message "${Title}: $text."
        }
        "Warning" {
            $text = $(if ($detail) { $detail } else { "concluído com ressalvas" })
            Write-WinForgeStatus -Type Warning -Message "${Title}: $text."
        }
        "Skipped" {
            $text = $(if ($detail) { $detail } else { "não executado" })
            Write-WinForgeStatus -Type Warning -Message "${Title}: $text."
        }
        default {
            # Um detalhe que é só o código ("código de saída 5") precisa do "falhou"; uma frase já diz o que houve.
            $text = "falhou"
            if ($detail -match "^código") { $text = "falhou ($detail)" }
            elseif ($detail) { $text = $detail }
            Write-WinForgeStatus -Type Error -Message "${Title}: $text."
        }
    }

    foreach ($note in @(Get-WinForgeResultData -Result $Result -Name "Notes")) {
        if (-not [string]::IsNullOrWhiteSpace([string]$note)) { Write-WinForgeStatus -Type Info -Message ([string]$note) }
    }
}


function Invoke-WinForgeTool {
    param (
        [Parameter(Mandatory)]
        [string]$Title,

        [Parameter(Mandatory)]
        [string]$FilePath,

        [string[]]$Arguments = @(),
        [string[]]$Description = @(),
        [string[]]$Warnings = @(),

        # Recebe ExitCode, OutputText, a hora em que a ferramenta começou e se a ação roda dentro de um fluxo (-Embedded),
        # e devolve um WinForge.Result.
        # Padrão: Get-WinForgeExitCodeResult.
        [scriptblock]$ResultParser,

        # Detalhe do resultado "Ok" quando o analisador não deu nenhum (o que a ferramenta fez, para a faixa).
        [string]$SuccessDetail = "",

        # Build mínimo do Windows para a ferramenta (0 = qualquer um) e a versão por extenso, para a mensagem.
        [int]$MinimumBuild = 0,
        [string]$MinimumVersion = "",

        # O que fazer quando o Windows é antigo demais para a ferramenta.
        [string]$UnavailableHint = "",

        # Recebe o WinForge.Result depois da mensagem final, só quando a ação roda sozinha: lugar de um "próximo passo".
        [scriptblock]$AfterResult,

        # A pergunta antes de começar, quando a ação roda sozinha ("Iniciar a verificação agora?").
        [string]$Question = "Deseja continuar?",

        # Recebe o WinForge.Result no fim, só quando a ação roda sozinha e a ferramenta rodou: monta a faixa da janela
        # (Set-WinForgeResultView).
        [scriptblock]$ResultView,

        # A ferramenta depende da manutenção dos componentes do Windows (DISM e SFC): com ela esperando um reinício, a
        # ação sozinha não roda e oferece reiniciar (Request-WinForgeRepairRestart).
        [switch]$NeedsServicing,

        # Enquanto a ferramenta roda depois do fim da saída (a espera que vem no analisador), o texto ao lado da barra.
        [string]$FinishingStatus = "",

        [switch]$Embedded,
        [switch]$PassThru
    )

    Enter-WinForgeAction -Title $Title -Embedded:$Embedded

    $result = $null

    try {
        if (-not (Test-WinForgeElevation -Reason "Esta ação exige privilégios de Administrador.")) {
            $result = New-WinForgeResult -Kind Failed -Detail "requer Administrador"
        }
        elseif (-not (Get-Command $FilePath -ErrorAction SilentlyContinue)) {
            Write-WinForgeStatus -Type Error -Message "Comando não encontrado: $FilePath"
            $result = New-WinForgeResult -Kind Failed -Detail "comando não encontrado"
        }
        elseif ($MinimumBuild -gt 0 -and (Test-WinForgeWindowsBuildBelow -Minimum $MinimumBuild)) {
            # Pedida sozinha, a ação não pôde ser feita (vermelho); num fluxo, a etapa fica de fora (ignorada).
            $detail = "esta função exige o $MinimumVersion ou mais novo"
            Write-WinForgeStatus -Type $(if ($Embedded) { "Warning" } else { "Error" }) -Message "Esta função exige o $MinimumVersion ou mais novo."
            if ($UnavailableHint) { Write-WinForgeStatus -Type Info -Message $UnavailableHint }
            $result = New-WinForgeResult -Kind $(if ($Embedded) { "Skipped" } else { "Failed" }) -Detail $detail
        }
        elseif ($NeedsServicing -and -not $Embedded -and (Test-WinForgeServicingRebootPending)) {
            $result = Request-WinForgeRepairRestart
        }
        else {
            # Sozinha, a ação diz o que a ferramenta faz e quanto pode demorar como mensagens: na janela elas aparecem
            # no resumo, acima da pergunta "Deseja continuar?" (os detalhes técnicos ficam recolhidos durante uma
            # pergunta de Sim e Não). Dentro de um fluxo não há pergunta, e o texto iria só alongar o resumo do fluxo.
            foreach ($line in @($Description) + @($Warnings)) {
                if ($Embedded) { Write-Host "  $line" -ForegroundColor DarkGray }
                else { Write-WinForgeStatus -Type Info -Message $line }
            }

            if ($Description.Count -gt 0 -or $Warnings.Count -gt 0) { Write-Host "" }

            Write-WinForgeCommand -Command "$FilePath $($Arguments -join ' ')"
            Write-Host ""

            if (-not $Embedded -and -not (Confirm-WinForgeAction $Question -DefaultKey S)) {
                Write-WinForgeStatus -Type Warning -Message "Operação cancelada."
                $result = New-WinForgeResult -Kind Skipped -Detail "cancelado pelo usuário"
            }
            else {
                # O andamento vai para a barra de progresso (na janela, o texto ao lado da barra): uma linha
                # "executando" ficaria no resumo depois do fim. DISM e SFC dizem o percentual, e a barra enche com ele.
                Write-Progress -Activity $Title -Status "em andamento; não feche o WinForge até terminar"

                # DISM, SFC e a otimização do disco levam minutos: o PC não pode dormir no meio, nem quando a ação roda
                # sozinha (dentro da Manutenção o pedido dela já vale; os pedidos se somam).
                $keepAwake = $false

                try {
                    $keepAwake = Set-WinForgeKeepAwake -Enabled $true
                    $startedAt = Get-Date
                    $run = Invoke-WinForgeCapture -FilePath $FilePath -Arguments $Arguments -Echo -ProgressActivity $Title
                }
                finally {
                    if ($keepAwake) { [void](Set-WinForgeKeepAwake -Enabled $false) }
                    Write-Progress -Activity $Title -Completed
                }

                if ($null -ne $ResultParser) {
                    if ($FinishingStatus) { Write-Progress -Activity $Title -Status $FinishingStatus }

                    try {
                        $result = & $ResultParser $run.ExitCode $run.Text $startedAt ([bool]$Embedded)
                    }
                    finally {
                        if ($FinishingStatus) { Write-Progress -Activity $Title -Completed }
                    }
                }
                else {
                    $result = Get-WinForgeExitCodeResult -ExitCode $run.ExitCode -OutputText $run.Text
                }

                if ($result.Kind -eq "Ok" -and [string]::IsNullOrWhiteSpace($result.Detail) -and $SuccessDetail) {
                    $result = New-WinForgeResult -Kind Ok -Detail $SuccessDetail -Data $result.Data
                }

                Write-Host ""
                Write-WinForgeToolOutcome -Title $Title -Result $result

                if ($null -ne $AfterResult -and -not $Embedded) {
                    & $AfterResult $result
                }

                if ($null -ne $ResultView -and -not $Embedded) {
                    [void](& $ResultView $result)
                }
            }
        }
    }
    catch {
        Write-WinForgeStatus -Type Error -Message "Ocorreu um erro ao executar '$Title': $($_.Exception.Message)"
        $result = New-WinForgeResult -Kind Failed -Detail $_.Exception.Message
    }

    $result.Etapa = $Title
    Exit-WinForgeAction -Embedded:$Embedded -Result $result

    if ($PassThru) {
        return $result
    }
}


# ---------------------------------------------------------------------------
# DISM e SFC
# ---------------------------------------------------------------------------

function Request-WinForgeRepairRestart {
    <#
    O DISM e o SFC pedidos sozinhos, com a manutenção dos componentes do Windows esperando um reinício (uma atualização
    que termina de instalar ao reiniciar, Test-WinForgeServicingRebootPending): os dois recusariam o reparo depois de
    minutos (o DISM com 0x800F0806, o SFC com "reparo pendente"). Nada roda: a tela diz por quê e oferece reiniciar, com
    Não como padrão. Devolve o WinForge.Result (ressalva, com o pedido de reinício).
    #>
    $note = "O Windows espera um reinício para terminar uma atualização: o DISM e o SFC só reparam depois de reiniciar."

    Write-WinForgeStatus -Type Warning -Message $note

    # Um problema ao oferecer o reinício não muda o resultado: a tela já disse o que fazer.
    try {
        [void](Request-WinForgeRestart -Reason "Reiniciar agora deixa o Windows pronto para o reparo." `
                -Comment "Reinicialização solicitada pelo WinForge antes do reparo do Windows (DISM e SFC)." `
                -DeclinedMessage "Reinicialização não iniciada. Depois de reiniciar, rode o reparo de novo.")
    }
    catch {
        Write-Verbose "Oferta de reinício antes do reparo: $($_.Exception.Message)"
    }

    $result = New-WinForgeResult -Kind Warning -Detail "o Windows espera um reinício para terminar uma atualização; o reparo só roda depois de reiniciar" -Data @{ RebootRequired = $true }

    return (Set-WinForgeResultView -Result $result -Headline "Reinicie antes de reparar" -Note $note)
}


function Invoke-WinForgeDism {
    param (
        [switch]$Embedded,
        [switch]$PassThru
    )

    $parser = {
        param ($ExitCode, $Text)
        Get-WinForgeDismResult -ExitCode $ExitCode -OutputText $Text
    }

    # A faixa: a imagem íntegra ou reparada (aí o próximo passo é o SFC, que tira dela os arquivos bons) e, com o Windows
    # Update desativado, o botão para religá-lo.
    $view = {
        param ($Result)

        if ($Result.Kind -eq "Ok") {
            if (Test-WinForgeResultFlag -Result $Result -Name "ImageRepaired") {
                Set-WinForgeResultView -Result $Result -Headline "Imagem do Windows reparada" -Note "Agora, o SFC confere os arquivos do Windows usando a imagem reparada." `
                    -Next "repair.sfc" -NextLabel "Verificar os arquivos (SFC)"
            }
            else {
                Set-WinForgeResultView -Result $Result -Headline "Imagem do Windows íntegra" -Note "O DISM não encontrou dano a reparar."
            }
        }
        else {
            Set-WinForgeDismServiceView -Result $Result
        }
    }

    Invoke-WinForgeTool `
        -Title "Reparar imagem e componentes (DISM)" `
        -FilePath "dism.exe" `
        -Arguments @("/Online", "/Cleanup-Image", "/RestoreHealth") `
        -Description @("Repara a imagem de componentes do Windows, pela internet, em 10 a 30 minutos.") `
        -Warnings @("Parar um tempo em 20% ou 62% é normal.") `
        -Question "Iniciar o reparo da imagem agora?" `
        -ResultParser $parser `
        -ResultView $view `
        -NeedsServicing `
        -Embedded:$Embedded -PassThru:$PassThru
}


function Invoke-WinForgeSfc {
    param (
        [switch]$Embedded,
        [switch]$PassThru
    )

    # O CBS.log confirma o que o texto do SFC diz (e cobre o que o texto não deixar claro em outro idioma). Vale o que
    # foi registrado a partir da hora em que o SFC começou.
    $parser = {
        param ($ExitCode, $Text, $StartedAt)

        $summary = $null

        try { $summary = Get-WinForgeSfcLogSummary -Lines (Read-WinForgeCbsLogTail) -Since $StartedAt } catch { $summary = $null }

        Get-WinForgeSfcResult -ExitCode $ExitCode -OutputText $Text -LogSummary $summary
    }

    # Sozinho, o SFC não corrige a imagem de onde tira os arquivos bons: o próximo passo vem no fim da tela, só quando
    # ele não conseguiu reparar tudo.
    $nextStep = {
        param ($Result)

        if (Test-WinForgeResultFlag -Result $Result -Name "Unrepaired") {
            # O reparo completo corrige a imagem do Windows (de onde o SFC tira os arquivos bons) e repete o SFC.
            Write-WinForgeStatus -Type Info -Message "Próximo passo: use Reparo > Reparar o Windows (DISM + SFC)."
        }
    }

    # A faixa: o que o SFC concluiu e, com arquivos sem reparo, o botão para o reparo completo.
    $view = {
        param ($Result)

        if (Test-WinForgeResultFlag -Result $Result -Name "Unrepaired") {
            Set-WinForgeResultView -Result $Result -Headline "Arquivos corrompidos sem reparo" -Note "O reparo completo (DISM + SFC) conserta a imagem de onde o SFC tira os arquivos bons." `
                -Next "repair.dism-sfc" -NextLabel "Fazer o reparo completo"
        }
        elseif ($Result.Kind -eq "Ok") {
            switch ([string](Get-WinForgeResultData -Result $Result -Name "Sfc")) {
                "Repaired" { Set-WinForgeResultView -Result $Result -Headline "Arquivos reparados" -Note "O SFC encontrou arquivos corrompidos e os reparou." }
                "Clean" { Set-WinForgeResultView -Result $Result -Headline "Nenhum arquivo corrompido" -Note "O SFC conferiu os arquivos protegidos do Windows." }
                default { Set-WinForgeResultView -Result $Result -Headline "Verificação concluída" -Note "O SFC terminou sem erros." }
            }
        }
    }

    Invoke-WinForgeTool `
        -Title "Verificar arquivos do sistema (SFC)" `
        -FilePath "sfc.exe" `
        -Arguments @("/scannow") `
        -Description @("Verifica os arquivos protegidos do Windows e repara os corrompidos, em 5 a 20 minutos.") `
        -Question "Iniciar a verificação agora?" `
        -ResultParser $parser `
        -AfterResult $nextStep `
        -ResultView $view `
        -NeedsServicing `
        -Embedded:$Embedded -PassThru:$PassThru
}


function Set-WinForgeDismServiceView {
    # O DISM que falhou porque o Windows Update está desativado (0x80070422, em geral por um bloqueador de atualizações):
    # a faixa diz isso no título, e o botão abre Corrigir o Windows Update, que religa o serviço. Outro erro fica como
    # está. Devolve o próprio resultado.
    param ([Parameter(Mandatory)]$Result)

    if ($Result.Kind -ne "Failed" -or [string]$Result.Detail -notmatch '0x80070422') { return $Result }

    return (Set-WinForgeResultView -Result $Result -Headline "Windows Update desativado" -Note "O DISM precisa dele para baixar os arquivos do reparo (erro 0x80070422)." `
            -Next "updates.repair" -NextLabel "Corrigir o Windows Update")
}


function Invoke-WinForgeTimedRepairStep {
    # Uma etapa do reparo (DISM ou SFC, dentro do fluxo) com o tempo que levou, para o resumo.
    param (
        [Parameter(Mandatory)]
        [ValidateSet("Dism", "Sfc")]
        [string]$Tool
    )

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    if ($Tool -eq "Dism") {
        $result = Invoke-WinForgeDism -Embedded -PassThru
    }
    else {
        $result = Invoke-WinForgeSfc -Embedded -PassThru
    }

    $stopwatch.Stop()
    $result.Duracao = Format-WinForgeDuration -Span $stopwatch.Elapsed

    return $result
}


function Get-WinForgeRepairFailureText {
    # "o DISM falhou (código de saída 5)" para a faixa do reparo completo; um detalhe que já começa pela ferramenta
    # ("o SFC não conseguiu executar a verificação") fica como está.
    param (
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)]$Result
    )

    $detail = ([string]$Result.Detail).Trim()

    if ($detail -match "^o $([regex]::Escape($Name)) ") { return $detail }

    # "o Windows espera um reinício..." não é o DISM falhando: ele nem chegou a reparar.
    if ($detail -match "^o Windows ") { return "o $Name não rodou: $detail" }
    if ($detail) { return "o $Name falhou ($detail)" }

    return "o $Name falhou"
}


function Set-WinForgeRepairView {
    <#
    A faixa do reparo completo (DISM + SFC): o título diz o que ele concluiu ("Nenhum problema encontrado", "Windows
    reparado", "Arquivos corrompidos sem reparo"), e a frase, o que isso quer dizer. Com arquivos que nem o DISM e um
    segundo SFC repararam, o botão abre a Recuperação do Windows (no Windows 11, ela reinstala o Windows pelo Windows
    Update mantendo arquivos e programas); com um reinício no meio, o título diz para reiniciar. Um caso sem frase própria
    fica com a faixa de sempre. Devolve o próprio resultado.
    #>
    param (
        [Parameter(Mandatory)]$Result,
        [Parameter(Mandatory)]$Sfc,
        [Parameter(Mandatory)]$FinalSfc,
        $Dism = $null,
        [switch]$Pending
    )

    if ($Result.Kind -eq "Ok") {
        if (-not [object]::ReferenceEquals($FinalSfc, $Sfc)) {
            return (Set-WinForgeResultView -Result $Result -Headline "Windows reparado" -Note "O SFC não tinha reparado tudo; depois do DISM, terminou sem pendências.")
        }

        $sfcState = [string](Get-WinForgeResultData -Result $FinalSfc -Name "Sfc")
        $imageRepaired = ($null -ne $Dism -and (Test-WinForgeResultFlag -Result $Dism -Name "ImageRepaired"))

        if ($imageRepaired -or $sfcState -eq "Repaired") {
            $note = ([string]$Result.Detail).Trim().TrimEnd(".")
            $note = $(if ($note) { $note.Substring(0, 1).ToUpperInvariant() + $note.Substring(1) + "." } else { "" })
            return (Set-WinForgeResultView -Result $Result -Headline "Windows reparado" -Note $note)
        }

        if ($sfcState -eq "Clean") {
            return (Set-WinForgeResultView -Result $Result -Headline "Nenhum problema encontrado" -Note "O DISM e o SFC conferiram o Windows: nenhum arquivo corrompido.")
        }

        return (Set-WinForgeResultView -Result $Result -Headline "Reparo concluído" -Note "O DISM e o SFC terminaram sem erros.")
    }

    if ($Result.Kind -eq "Warning") {
        if ((Test-WinForgeResultFlag -Result $FinalSfc -Name "Unrepaired") -and -not $Pending) {
            return (Set-WinForgeResultView -Result $Result -Headline "Arquivos corrompidos sem reparo" -Note "Mesmo depois do DISM, o SFC encontra arquivos que não consegue reparar." `
                    -Next "repair.recovery" -NextLabel "Abrir a Recuperação")
        }

        if (Test-WinForgeResultFlag -Result $FinalSfc -Name "RebootRequired") {
            return (Set-WinForgeResultView -Result $Result -Headline "Reinicie e repita o reparo" -Note "Há um reparo do Windows pendente: depois de reiniciar, repita o reparo.")
        }

        if (Test-WinForgeResultFlag -Result $Result -Name "RebootRequired") {
            return (Set-WinForgeResultView -Result $Result -Headline "Reinicie para concluir o reparo" -Note "O reparo da imagem do Windows termina ao reiniciar.")
        }

        return $Result
    }

    if ($Result.Kind -eq "Failed" -and $null -ne $Dism) {
        # O Windows Update desativado: a mesma faixa do DISM sozinho, com o detalhe do reparo completo.
        if ($Dism.Kind -eq "Failed" -and [string]$Dism.Detail -match '0x80070422') {
            return (Set-WinForgeResultView -Result $Result -Headline "Windows Update desativado" -Note "O DISM precisa dele para baixar os arquivos do reparo (erro 0x80070422)." `
                    -Next "updates.repair" -NextLabel "Corrigir o Windows Update")
        }
    }

    return $Result
}


function Invoke-WinForgeDismAndSfc {
    <#
    Reparo completo: DISM e depois SFC (o SFC usa a imagem que o DISM acabou de corrigir).
    Com -CheckFirst, o DISM só repara se o /CheckHealth indicar dano (usado em fluxos que só reparam se houver dano). O /CheckHealth
    só lê uma marcação, que pode faltar mesmo com o repositório danificado; por isso, se o SFC seguinte não conseguir
    reparar tudo, o DISM /RestoreHealth roda de qualquer forma e o SFC é repetido.
    #>
    param (
        [switch]$CheckFirst,
        [switch]$Embedded,
        [switch]$PassThru
    )

    $title = "Reparar o Windows (DISM + SFC)"

    Enter-WinForgeAction -Title $title -Embedded:$Embedded

    $result = $null
    $keepAwake = $false

    try {
        $proceed = $true

        if (-not (Test-WinForgeElevation -Reason "O reparo do Windows exige privilégios de Administrador.")) {
            $proceed = $false
            $result = New-WinForgeResult -Kind Failed -Detail "requer Administrador"
        }
        elseif (-not $Embedded -and (Test-WinForgeServicingRebootPending)) {
            # Com uma atualização esperando o reinício, o DISM e o SFC recusariam o reparo depois de minutos. No Otimizar
            # (embutido), quem confere isso é o Otimizar.
            $proceed = $false
            $result = Request-WinForgeRepairRestart
        }
        elseif (-not $Embedded) {
            # Mensagem, e não texto solto: na janela ela fica no resumo, à vista durante a pergunta. Primeiro o DISM repara
            # a imagem do Windows (pela internet, no Windows Update); depois o SFC verifica os arquivos usando essa imagem.
            # Os arquivos pessoais não são tocados.
            Write-WinForgeStatus -Type Info -Message "Leva de 20 a 60 minutos (mais num HD). Dá para usar o PC, mas não o desligue."
            Write-Host ""

            if (-not (Confirm-WinForgeAction "Iniciar o reparo agora?" -DefaultKey S)) {
                $proceed = $false
                Write-WinForgeStatus -Type Warning -Message "Operação cancelada."
                $result = New-WinForgeResult -Kind Skipped -Detail "cancelado pelo usuário"
            }
        }

        if ($proceed) {
            # DISM e SFC juntos levam de minutos a mais de uma hora: o PC não pode dormir entre as etapas (o pedido é
            # fechado no finally, no fim da função).
            $keepAwake = Set-WinForgeKeepAwake -Enabled $true
            $runDism = $true

            if ($CheckFirst) {
                Write-Progress -Activity $title -Status "DISM /CheckHealth: conferindo se o repositório de componentes foi marcado como danificado"

                try {
                    $check = Get-WinForgeDismHealthState
                }
                finally {
                    Write-Progress -Activity $title -Completed
                }

                # Sem conseguir consultar (Unknown), o /RestoreHealth não roda antes: a mesma falha (um reinício pendente,
                # por exemplo) costuma derrubá-lo também, depois de muitos minutos. O SFC verifica os arquivos de qualquer
                # forma e, se não conseguir reparar tudo, o /RestoreHealth roda em seguida, como no caso saudável.
                $runDism = ($check.State -in @("Repairable", "NonRepairable"))

                # Saudável ou sem consulta, o /RestoreHealth (demorado) só roda se o SFC a seguir não reparar tudo.
                switch ($check.State) {
                    "Healthy" {
                        Write-WinForgeStatus -Type Success -Message "DISM /CheckHealth: nenhum dano marcado na imagem do Windows."
                    }
                    "NonRepairable" {
                        Write-WinForgeStatus -Type Warning -Message "DISM /CheckHealth: a imagem do Windows tem dano grave; o DISM vai tentar reparar."
                    }
                    "Repairable" {
                        Write-WinForgeStatus -Type Warning -Message "DISM /CheckHealth: a imagem do Windows tem dano; o DISM vai repará-la."
                    }
                    default {
                        $code = [string](Get-WinForgeJsonValue -Object $check -Name "Code" -Default "")
                        $codeText = $(if ($code) { " (código $code)" } else { "" })
                        Write-WinForgeStatus -Type Warning -Message "DISM /CheckHealth: não foi possível consultar a imagem do Windows$codeText."
                    }
                }
            }

            $dism = $null

            if ($runDism) {
                # Com o DISM falhando, o SFC roda mesmo assim: a etapa dele aparece em seguida.
                $dism = Invoke-WinForgeTimedRepairStep -Tool Dism
            }

            $sfc = Invoke-WinForgeTimedRepairStep -Tool Sfc
            $finalSfc = $sfc

            # Linhas do resumo (todas as execuções) e as que decidem o resultado (a primeira passada do SFC deixa de
            # valer quando o DISM e um segundo SFC a substituem). Cada uma com o nome curto da ferramenta, para a faixa.
            $rows = @()
            $decisive = @()
            if ($null -ne $dism) { $rows += $dism; $decisive += @{ Name = "DISM"; Result = $dism } }
            $rows += $sfc
            $decisive += @{ Name = "SFC"; Result = $sfc }

            if ($null -eq $dism -and (Test-WinForgeResultFlag -Result $sfc -Name "Unrepaired")) {
                Write-WinForgeStatus -Type Info -Message "O SFC não reparou tudo: o DISM repara a imagem e o SFC roda de novo."

                $sfc.Etapa = "$($sfc.Etapa) (antes do DISM)"
                $dism = Invoke-WinForgeTimedRepairStep -Tool Dism
                $rows = @($sfc, $dism)
                $decisive = @(@{ Name = "DISM"; Result = $dism })

                if ($dism.Kind -eq "Failed") {
                    Write-WinForgeStatus -Type Info -Message "Com o DISM sem sucesso, o SFC não será repetido."
                    $decisive += @{ Name = "SFC"; Result = $sfc }
                }
                else {
                    $finalSfc = Invoke-WinForgeTimedRepairStep -Tool Sfc
                    $finalSfc.Etapa = "$($finalSfc.Etapa) (depois do DISM)"
                    $rows += $finalSfc
                    $decisive += @{ Name = "SFC"; Result = $finalSfc }
                }
            }

            Write-WinForgeSection -Title "Resumo do reparo"
            Write-WinForgeResultTable -Results $rows

            # Quando DISM e SFC rodaram e os arquivos continuam corrompidos, o próximo passo é voltar o Windows a um ponto
            # anterior ou reinstalá-lo. Não quando o caminho é outro: reiniciar (há algo pendente), a internet ou uma
            # política (o DISM já disse o que fazer), um serviço desativado.
            $pending = @($rows | Where-Object { Test-WinForgeResultFlag -Result $_ -Name "RebootRequired" }).Count -gt 0

            # Reparo > Restauração do Sistema volta a um ponto de restauração; em Reparo > Recuperação, o Windows 11 pode
            # reinstalar o Windows pelo Windows Update mantendo programas e arquivos ("Restaurar o PC" remove os programas).
            if (-not $Embedded -and -not $pending -and (Test-WinForgeResultFlag -Result $finalSfc -Name "Unrepaired")) {
                Write-Host ""
                Write-WinForgeStatus -Type Info -Message "Se o problema continuar: Reparo > Restauração do Sistema ou Reparo > Recuperação."
            }

            # O pedido de reinício de uma das ferramentas vale para o reparo inteiro.
            $data = @{}
            if (@($rows | Where-Object { Test-WinForgeResultFlag -Result $_ -Name "RebootRequired" }).Count -gt 0) {
                $data["RebootRequired"] = $true
            }

            $failed = @($decisive | Where-Object { $_.Result.Kind -eq "Failed" })
            $warned = @($decisive | Where-Object { $_.Result.Kind -eq "Warning" })

            if ($failed.Count -gt 0) {
                $texts = @($failed | ForEach-Object { Get-WinForgeRepairFailureText -Name $_.Name -Result $_.Result })
                $result = New-WinForgeResult -Kind Failed -Detail ($texts -join "; ") -Data $data
            }
            elseif ($warned.Count -gt 0) {
                $detail = "uma das etapas terminou com ressalvas"

                if (Test-WinForgeResultFlag -Result $finalSfc -Name "Unrepaired") {
                    $detail = "o SFC ainda encontra arquivos corrompidos que não conseguiu reparar"
                }
                elseif (Test-WinForgeResultFlag -Result $finalSfc -Name "RebootRequired") {
                    # O SFC não chegou a verificar: há um reparo pendente, e só depois do reinício ele roda de verdade.
                    $detail = "há um reparo do Windows pendente; depois de reiniciar, repita o reparo"
                }
                elseif ($data.ContainsKey("RebootRequired")) {
                    $detail = "o reparo termina na próxima reinicialização"
                }

                $result = New-WinForgeResult -Kind Warning -Detail $detail -Data $data
            }
            else {
                # O que o último SFC concluiu é o que vale para a pessoa ("nenhum arquivo corrompido foi encontrado"),
                # junto com o reparo da imagem, quando o DISM disse que houve um.
                $detail = [string]$finalSfc.Detail

                if (-not [object]::ReferenceEquals($finalSfc, $sfc)) {
                    $detail = "depois do DISM, o SFC terminou sem pendências"
                }
                elseif (Test-WinForgeResultFlag -Result $dism -Name "ImageRepaired") {
                    $detail = (@("o DISM reparou a imagem do Windows", $detail) | Where-Object { $_ }) -join "; "
                }

                $result = New-WinForgeResult -Kind Ok -Detail $detail -Data $data
            }

            if (-not $Embedded) {
                [void](Set-WinForgeRepairView -Result $result -Sfc $sfc -FinalSfc $finalSfc -Dism $dism -Pending:$pending)
            }
        }
    }
    catch {
        Write-WinForgeStatus -Type Error -Message "Ocorreu um erro durante o reparo: $($_.Exception.Message)"
        $result = New-WinForgeResult -Kind Failed -Detail $_.Exception.Message
    }
    finally {
        if ($keepAwake) { [void](Set-WinForgeKeepAwake -Enabled $false) }
    }

    $result.Etapa = $title
    Exit-WinForgeAction -Embedded:$Embedded -Result $result

    if ($PassThru) {
        return $result
    }
}


# ---------------------------------------------------------------------------
# Unidades
# ---------------------------------------------------------------------------

function Get-WinForgeSystemDriveLetter {
    # "C:", a unidade do Windows. Sem a variável SystemDrive (um ambiente montado à mão), sai da pasta do Windows; sem
    # nenhuma das duas, "C:", e não um texto vazio que viraria um comando sem unidade.
    $drive = [string]$env:SystemDrive

    if ($drive -match '^[A-Za-z]:$') { return $drive.ToUpperInvariant() }
    if ([string]$env:SystemRoot -match '^([A-Za-z]:)') { return $Matches[1].ToUpperInvariant() }

    return "C:"
}


function Get-WinForgeChkdskDrives {
    <#
    As unidades que o CHKDSK verifica com o Windows aberto (/scan): discos fixos do PC formatados em NTFS. Pendrives,
    cartões e unidades FAT32, exFAT ou ReFS ficam de fora (o /scan é só do NTFS), assim como uma unidade trancada pelo
    BitLocker, que não tem sistema de arquivos legível. A do Windows vem primeiro. Cada uma: Drive, Label, Free, Size,
    System e External (um HD ou SSD externo, pela USB: o Windows o vê como disco fixo, mas o reparo agendado só roda com
    ele conectado). Sem leitura do Windows, só a do sistema.
    #>
    $system = Get-WinForgeSystemDriveLetter
    $drives = @()

    try {
        foreach ($disk in @(Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DriveType = 3" -OperationTimeoutSec 15 -ErrorAction Stop)) {
            $letter = ([string](Get-WinForgeJsonValue -Object $disk -Name "DeviceID" -Default "")).ToUpperInvariant()
            $fileSystem = [string](Get-WinForgeJsonValue -Object $disk -Name "FileSystem" -Default "")
            $size = [double](Get-WinForgeJsonValue -Object $disk -Name "Size" -Default 0)

            if ($letter -notmatch '^[A-Z]:$' -or $fileSystem -ne "NTFS" -or $size -le 0) { continue }

            $drives += [PSCustomObject]@{
                Drive    = $letter
                Label    = ([string](Get-WinForgeJsonValue -Object $disk -Name "VolumeName" -Default "")).Trim()
                Free     = [double](Get-WinForgeJsonValue -Object $disk -Name "FreeSpace" -Default 0)
                Size     = $size
                System   = ($letter -eq $system)
                External = ($letter -ne $system -and (Test-WinForgeDriveExternal -Drive $letter))
            }
        }
    }
    catch {
        $drives = @()
    }

    if (@($drives | Where-Object { $_.System }).Count -eq 0) {
        $drives = @([PSCustomObject]@{ Drive = $system; Label = ""; Free = [double]0; Size = [double]0; System = $true; External = $false }) + $drives
    }

    return @($drives | Sort-Object -Property @{ Expression = { -not $_.System } }, Drive)
}


function Test-WinForgeDriveExternal {
    # Se a unidade fica num disco ligado pela USB (ou outro barramento externo). Sem leitura do Windows, falso.
    param ([Parameter(Mandatory)][string]$Drive)

    try {
        $disk = Get-Partition -DriveLetter $Drive.Substring(0, 1) -ErrorAction Stop | Get-Disk -ErrorAction Stop
        return ([string](Get-WinForgeJsonValue -Object $disk -Name "BusType" -Default "") -in @("USB", "1394", "SD", "MMC"))
    }
    catch {
        return $false
    }
}


function Select-WinForgeChkdskDrive {
    # A unidade a verificar: com uma só, ela mesma, sem pergunta; com mais, a pessoa escolhe (a do Windows em destaque).
    # "" = cancelou.
    param ([Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Drives)

    if ($Drives.Count -eq 0) { return (Get-WinForgeSystemDriveLetter) }
    if ($Drives.Count -eq 1) { return [string]$Drives[0].Drive }

    $options = @(
        foreach ($drive in $Drives) {
            $what = $(if ($drive.System) { "a do Windows" } elseif ($drive.External) { "disco externo (USB)$(if ($drive.Label) { ', ' + $drive.Label })" } elseif ($drive.Label) { $drive.Label } else { "disco do PC" })
            $space = $(if ($drive.Size -gt 0) { " · $(Format-WinForgeBytes -Bytes $drive.Free) livres de $(Format-WinForgeBytes -Bytes $drive.Size)" } else { "" })
            @{ Key = $drive.Drive.Substring(0, 1); Label = "Unidade $($drive.Drive)"; Description = "$what$space"; Accent = [bool]$drive.System }
        }
    )
    $options += @{ Key = "0"; Label = "Cancelar"; Exit = $true }

    $answer = [string](Read-WinForgeChoice -Message "Qual unidade verificar?" -Options $options -DefaultKey ($Drives[0].Drive.Substring(0, 1)) -ShowMenu)
    $match = @($Drives | Where-Object { $_.Drive.Substring(0, 1) -ieq $answer }) | Select-Object -First 1

    return $(if ($null -ne $match) { [string]$match.Drive } else { "" })
}


# ---------------------------------------------------------------------------
# CHKDSK
# ---------------------------------------------------------------------------

function Test-WinForgeChkdskRepairPending {
    return [bool]$script:WinForgeChkdskRepairPending
}


function Set-WinForgeChkdskStartupRepair {
    <#
    Agenda o reparo do CHKDSK para a próxima inicialização e devolve $true. Primeiro o chkntfs /C garante que a
    unidade não está fora da verificação de inicialização; por último o fsutil marca a unidade como "suja", o que faz o
    Windows rodar o reparo. A marcação não se desfaz: se o chkntfs falhar, nada foi mudado.
    #>
    param (
        [string]$Drive = (Get-WinForgeSystemDriveLetter)
    )

    foreach ($command in @("chkntfs.exe", "fsutil.exe")) {
        if (-not (Get-Command $command -ErrorAction SilentlyContinue)) {
            throw "comando não encontrado: $command"
        }
    }

    $schedule = Invoke-WinForgeCapture -FilePath "chkntfs.exe" -Arguments @("/C", $Drive)

    if ($schedule.ExitCode -ne 0) {
        throw "o chkntfs não aceitou o agendamento (código $(Format-WinForgeExitCode -ExitCode $schedule.ExitCode))"
    }

    $mark = Invoke-WinForgeCapture -FilePath "fsutil.exe" -Arguments @("dirty", "set", $Drive)

    if ($mark.ExitCode -ne 0) {
        throw "o fsutil não marcou a unidade $Drive para reparo (código $(Format-WinForgeExitCode -ExitCode $mark.ExitCode))"
    }

    $script:WinForgeChkdskRepairPending = $false
    return $true
}


function Invoke-WinForgeScheduleChkdskRepair {
    # Pergunta já feita pelo chamador; aqui só agenda e conta o que aconteceu.
    param ([string]$Drive = (Get-WinForgeSystemDriveLetter))

    try {
        [void](Set-WinForgeChkdskStartupRepair -Drive $Drive)
        # Com a Inicialização Rápida, "Desligar" e ligar pode pular a verificação de inicialização; "Reiniciar", não.
        Write-WinForgeStatus -Type Success -Message "Reparo da unidade $Drive agendado: use Reiniciar (não Desligar) e não desligue o PC até o Windows abrir."
        return $true
    }
    catch {
        Write-WinForgeStatus -Type Error -Message "Não foi possível agendar o reparo: $($_.Exception.Message)."
        return $false
    }
}


function Start-WinForgeChkdsk {
    <#
    Verificação online do sistema de arquivos (chkdsk /scan). Se o Windows indicar que o reparo precisa ser feito
    na inicialização, pergunta se deve agendá-lo; com -DeferRepairPrompt a pergunta fica para o final da Manutenção.
    Sozinha, com mais de um disco NTFS no PC, a pessoa escolhe a unidade (Select-WinForgeChkdskDrive), e a escolha vale
    como a confirmação; dentro da Manutenção, é sempre a do Windows.
    #>
    param (
        [switch]$DeferRepairPrompt,
        [switch]$Embedded,
        [switch]$PassThru
    )

    $script:WinForgeChkdskRepairPending = $false
    $title = "Verificar o sistema de arquivos (CHKDSK)"

    Enter-WinForgeAction -Title $title -Embedded:$Embedded

    $result = $null

    try {
        if (-not (Test-WinForgeElevation -Reason "O CHKDSK exige privilégios de Administrador.")) {
            $result = New-WinForgeResult -Kind Failed -Detail "requer Administrador"
        }
        elseif (-not (Get-Command "chkdsk.exe" -ErrorAction SilentlyContinue)) {
            Write-WinForgeStatus -Type Error -Message "Comando não encontrado: chkdsk.exe"
            $result = New-WinForgeResult -Kind Failed -Detail "comando não encontrado"
        }
        else {
            $drives = @()
            $drive = Get-WinForgeSystemDriveLetter

            if (-not $Embedded) {
                Write-Progress -Activity $title -Status "lendo os discos do PC"
                try { $drives = @(Get-WinForgeChkdskDrives) } finally { Write-Progress -Activity $title -Completed }
                if ($drives.Count -gt 1) { $drive = Select-WinForgeChkdskDrive -Drives $drives }
            }

            $arguments = @($drive, "/scan")

            if ($drive) {
                Write-WinForgeKeyValue -Label "Unidade" -Value $drive
                Write-WinForgeKeyValue -Label "Modo" -Value "Verificação online (não exige reiniciar)"
                if (-not $Embedded) { Write-WinForgeStatus -Type Info -Message "Leva poucos minutos num SSD, mais num HD." }
                Write-WinForgeCommand -Command "chkdsk.exe $($arguments -join ' ')"
                Write-Host ""
            }

            # Com a lista de unidades, a escolha já foi a confirmação; com uma unidade só, a pergunta de sempre.
            if (-not $drive -or (-not $Embedded -and $drives.Count -le 1 -and -not (Confirm-WinForgeAction "Iniciar a verificação agora?" -DefaultKey S))) {
                Write-WinForgeStatus -Type Warning -Message "Operação cancelada."
                $result = New-WinForgeResult -Kind Skipped -Detail "cancelado pelo usuário"
            }
            else {
                Write-Progress -Activity $title -Status "verificando a unidade $drive; não feche o WinForge até terminar"

                # A verificação pode levar muitos minutos num HDD: o PC não pode dormir no meio.
                $keepAwake = $false

                try {
                    $keepAwake = Set-WinForgeKeepAwake -Enabled $true
                    $run = Invoke-WinForgeCapture -FilePath "chkdsk.exe" -Arguments $arguments -Echo
                }
                finally {
                    if ($keepAwake) { [void](Set-WinForgeKeepAwake -Enabled $false) }
                    Write-Progress -Activity $title -Completed
                }

                Write-Host ""

                $code = $run.ExitCode
                $codeText = Format-WinForgeExitCode -ExitCode $code

                # Código negativo não é um código do CHKDSK: o programa foi interrompido (falha do próprio processo).
                # A frase do resultado só sai depois de ver se há reparo offline: um código 0 com o pedido de /spotfix
                # no texto não é "nenhum erro".
                $repairRequired = ($code -ge 0) -and (Test-WinForgeChkdskRepairRequired -ExitCode $code -OutputText $run.Text)

                if ($code -lt 0) {
                    Write-WinForgeStatus -Type Error -Message "O CHKDSK foi interrompido antes de terminar (código $codeText)."
                    $result = New-WinForgeResult -Kind Failed -Detail "o CHKDSK foi interrompido (código $codeText)"
                }
                elseif (-not $repairRequired) {
                    if ($code -eq 0) {
                        Write-WinForgeStatus -Type Success -Message "Nenhum erro foi encontrado na unidade $drive."
                        $result = New-WinForgeResult -Kind Ok -Detail "nenhum erro foi encontrado na unidade $drive"
                        if (-not $Embedded) { [void](Set-WinForgeResultView -Result $result -Headline "Nenhum erro na unidade $drive" -Note "A verificação online terminou sem encontrar problemas.") }
                    }
                    elseif ($code -eq 1) {
                        Write-WinForgeStatus -Type Success -Message "Erros foram encontrados e corrigidos na unidade $drive."
                        $result = New-WinForgeResult -Kind Ok -Detail "erros foram encontrados e corrigidos na unidade $drive"
                        if (-not $Embedded) { [void](Set-WinForgeResultView -Result $result -Headline "Erros corrigidos na unidade $drive" -Note "O CHKDSK encontrou e corrigiu erros com o Windows aberto.") }
                    }
                    else {
                        Write-WinForgeStatus -Type Warning -Message "A verificação terminou com avisos menores (código $codeText), que não exigem reparo offline."
                        $result = New-WinForgeResult -Kind Warning -Detail "avisos menores do CHKDSK (código $codeText), sem necessidade de reparo offline"
                    }
                }
                else {
                    if ($code -eq 3) {
                        Write-WinForgeStatus -Type Warning -Message "O CHKDSK não conseguiu verificar ou corrigir tudo com o Windows em uso (código 3)."
                    }
                    elseif ($code -gt 3) {
                        # Fora da tabela da Microsoft (0 a 3): na dúvida, o reparo offline é oferecido como no código 3.
                        Write-WinForgeStatus -Type Warning -Message "O CHKDSK terminou com um código desconhecido ($codeText); por segurança, o reparo offline é oferecido."
                    }
                    else {
                        Write-WinForgeStatus -Type Warning -Message "A verificação encontrou problemas que só o reparo offline corrige."
                    }

                    # Mensagens, e não texto solto: na janela elas ficam no resumo, à vista durante a pergunta. Erro no disco
                    # pode ser o disco falhando: antes de mexer nele, a cópia dos arquivos.
                    Write-WinForgeStatus -Type Info -Message "O reparo roda ao reiniciar, antes de o Windows abrir, e pode levar horas: não desligue o PC até o Windows abrir."

                    if (-not $DeferRepairPrompt) {
                        Write-WinForgeStatus -Type Info -Message "Erros no disco podem ser sinal de que ele está falhando: antes de agendar, copie seus arquivos importantes e veja Diagnóstico > Saúde dos discos."
                    }

                    Write-Host ""

                    if ($DeferRepairPrompt) {
                        # No Otimizar a decisão é pedida ao final, sem interromper as etapas.
                        $script:WinForgeChkdskRepairPending = $true
                        Write-WinForgeStatus -Type Info -Message "O agendamento do reparo vem no fim do Otimizar."
                        $result = New-WinForgeResult -Kind Warning -Detail "reparo offline pendente"
                    }
                    elseif (Confirm-WinForgeAction "Agendar o reparo para a próxima reinicialização?" -DefaultKey N) {
                        if (Invoke-WinForgeScheduleChkdskRepair -Drive $drive) {
                            $external = (@($drives | Where-Object { $_.Drive -eq $drive -and $_.External }).Count -gt 0)

                            if ($external) {
                                Write-WinForgeStatus -Type Info -Message "A unidade $drive é um disco externo: deixe-o conectado ao reiniciar, ou o reparo não roda."
                            }

                            $result = New-WinForgeResult -Kind Warning -Detail "reparo da unidade $drive agendado para a próxima inicialização" -Data @{ RebootRequired = $true }
                            [void](Set-WinForgeResultView -Result $result -Headline "Reparo da unidade $drive agendado" `
                                    -Note "Ele roda ao reiniciar, antes de o Windows abrir: use Reiniciar, e não Desligar.$(if ($external) { ' Deixe o disco externo conectado.' })")

                            # O reinício ali mesmo, com Não como padrão. Um problema ao pedir não muda o agendamento.
                            try {
                                [void](Request-WinForgeRestart -Reason "Reiniciar agora já faz o reparo da unidade $drive." `
                                        -Comment "Reinicialização solicitada pelo WinForge para o reparo do disco (CHKDSK)." `
                                        -DeclinedMessage "Reinicialização não iniciada. O reparo roda quando você reiniciar o PC (use Reiniciar, não Desligar).")
                            }
                            catch {
                                Write-Verbose "Oferta de reinício depois do CHKDSK: $($_.Exception.Message)"
                            }
                        }
                        else {
                            $result = New-WinForgeResult -Kind Failed -Detail "não foi possível agendar o reparo"
                        }
                    }
                    else {
                        Write-WinForgeStatus -Type Warning -Message "Reparo não agendado; para agendar depois, rode esta verificação de novo."
                        $result = New-WinForgeResult -Kind Warning -Detail "reparo offline não agendado"
                        [void](Set-WinForgeResultView -Result $result -Headline "A unidade $drive precisa de reparo" `
                                -Note "O reparo não foi agendado; para agendar, rode a verificação de novo. Antes, copie seus arquivos importantes." `
                                -Next "diagnostics.disk-health" -NextLabel "Ver a saúde dos discos")
                    }
                }
            }
        }
    }
    catch {
        Write-WinForgeStatus -Type Error -Message "Erro ao executar o CHKDSK: $($_.Exception.Message)"
        $result = New-WinForgeResult -Kind Failed -Detail $_.Exception.Message
    }

    $result.Etapa = $title
    Exit-WinForgeAction -Embedded:$Embedded -Result $result

    if ($PassThru) {
        return $result
    }
}


# ---------------------------------------------------------------------------
# Otimização da unidade
# ---------------------------------------------------------------------------

function Get-WinForgeDriveMediaText {
    # O tipo do disco de uma unidade ("SSD", "NVMe", "HDD"...), como o Diagnóstico mostra; "" quando não se sabe.
    param ([Parameter(Mandatory)][string]$Drive)

    try {
        $disk = @(Get-WinForgeDiskSummary | Where-Object { [string]$_.Unidade -ieq $Drive }) | Select-Object -First 1
        if ($null -ne $disk -and [string]$disk.Tipo -ne "Não disponível") { return [string]$disk.Tipo }
    }
    catch {
        Write-Verbose "Tipo do disco de ${Drive}: $($_.Exception.Message)"
    }

    return ""
}


function Start-WinForgeDriveOptimization {
    param (
        [switch]$Embedded,
        [switch]$PassThru
    )

    $drive = Get-WinForgeSystemDriveLetter

    # Ler o tipo do disco pode levar alguns segundos na primeira consulta: dentro da Manutenção, onde a explicação nem
    # aparece em destaque, fica de fora.
    $media = ""

    if (-not $Embedded) {
        Write-Progress -Activity "Otimizar a unidade do sistema" -Status "lendo o tipo do disco"
        try { $media = Get-WinForgeDriveMediaText -Drive $drive } finally { Write-Progress -Activity "Otimizar a unidade do sistema" -Completed }
    }

    # /O delega ao Windows a escolha correta: retrim/otimização para SSD e desfragmentação para HDD (num SSD, o Windows
    # só desfragmenta raramente, quando vê necessidade). Sabendo o tipo do disco, a tela diz o que vai acontecer e quanto
    # demora, numa linha; sem saber, as duas possibilidades.
    $description = $(
        if ($media -in @("SSD", "NVMe")) { "Na unidade $drive (um SSD), o Windows manda o TRIM, que mantém o SSD rápido. Costuma levar segundos." }
        elseif ($media -eq "HDD") { "Na unidade $drive (um HD), o Windows desfragmenta o disco. Pode levar de minutos a horas." }
        else { "Na unidade $drive, o Windows faz o TRIM num SSD (segundos) ou desfragmenta num HD (pode demorar)." }
    )

    # A faixa: o que o Windows fez, conforme o tipo do disco.
    $optimizedTitle = "Unidade $drive otimizada"
    $optimizedNote = $(
        if ($media -in @("SSD", "NVMe")) { "O Windows fez o TRIM, que mantém o SSD rápido." }
        elseif ($media -eq "HDD") { "O Windows desfragmentou o disco." }
        else { "O Windows fez a otimização certa para o tipo do disco." }
    )
    $view = {
        param ($Result)
        if ($Result.Kind -eq "Ok") { Set-WinForgeResultView -Result $Result -Headline $optimizedTitle -Note $optimizedNote }
    }

    Invoke-WinForgeTool `
        -Title "Otimizar a unidade do sistema" `
        -FilePath "defrag.exe" `
        -Arguments @($drive, "/O", "/U", "/V") `
        -Description @($description) `
        -Question "Otimizar a unidade $drive agora?" `
        -SuccessDetail "a unidade $drive foi otimizada" `
        -ResultView $view `
        -Embedded:$Embedded -PassThru:$PassThru
}


# ---------------------------------------------------------------------------
# Dispositivos e drivers
# ---------------------------------------------------------------------------

function Invoke-WinForgeDeviceScan {
    param (
        [switch]$Embedded,
        [switch]$PassThru
    )

    # Depois da busca, o que ainda está com problema: a busca terminar bem não quer dizer que o dispositivo que levou a
    # pessoa até aqui (a câmera, o som) voltou a funcionar.
    $parser = {
        param ($ExitCode, $Text, $StartedAt, $Embedded)

        $result = Get-WinForgeExitCodeResult -ExitCode $ExitCode -OutputText $Text

        if ($result.Kind -eq "Ok") {
            $remaining = Get-WinForgeDeviceScanRemaining -NotesOnly:([bool]$Embedded)
            if ($null -ne $remaining) { $result = $remaining }
        }

        $result
    }

    # A faixa: quantos dispositivos continuam com problema (com o primeiro pelo nome e o botão para a tela deles), nenhum,
    # ou só que a busca terminou, quando o Windows não deixou ler os dispositivos.
    $view = {
        param ($Result)

        $remaining = Get-WinForgeResultData -Result $Result -Name "Remaining"
        $searched = "O Windows procurou dispositivos novos e alterações de hardware."

        if ($Result.Kind -eq "Warning" -and $null -ne $remaining -and [int]$remaining -gt 0) {
            Set-WinForgeResultView -Result $Result -Headline (Format-WinForgeCount -Count ([int]$remaining) -One "dispositivo ainda com problema" -Many "dispositivos ainda com problema") `
                -Note "$([string](Get-WinForgeResultData -Result $Result -Name 'Problems'))." -Next "diagnostics.devices" -NextLabel "Ver os dispositivos com problema"
        }
        elseif ($Result.Kind -eq "Ok" -and $null -ne $remaining -and [int]$remaining -eq 0) {
            Set-WinForgeResultView -Result $Result -Headline "Nenhum dispositivo com problema" -Note $searched
        }
        elseif ($Result.Kind -eq "Ok") {
            Set-WinForgeResultView -Result $Result -Headline "Busca concluída" -Note $searched
        }
    }

    # O pnputil só tem /scan-devices a partir do Windows 10 versão 2004 (build 19041); antes, ele só mostraria a ajuda.
    Invoke-WinForgeTool `
        -Title "Detectar dispositivos e drivers" `
        -FilePath "pnputil.exe" `
        -Arguments @("/scan-devices") `
        -Description @("Pede ao Windows que procure dispositivos novos e instale os drivers que já tiver.") `
        -SuccessDetail "o Windows procurou dispositivos novos e alterações de hardware" `
        -ResultParser $parser `
        -ResultView $view `
        -Question "Procurar dispositivos agora?" `
        -FinishingStatus "esperando o Windows terminar de instalar os drivers encontrados (até 20 segundos)" `
        -MinimumBuild 19041 -MinimumVersion "Windows 10 versão 2004" `
        -UnavailableHint "Em Diagnóstico > Gerenciador de Dispositivos, menu Ação, use 'Verificar se há alterações de hardware': faz o mesmo." `
        -Embedded:$Embedded -PassThru:$PassThru
}


function Get-WinForgeDeviceScanRemaining {
    <#
    Os dispositivos que continuam com problema depois da busca (os desativados de propósito, códigos 22 e 29, não
    contam): uma ressalva com os nomes, ou Ok dizendo que não há nenhum; $null quando o Windows não deixou ler (aí a
    tela não afirma nada). Usa as mesmas regras de Diagnóstico > Dispositivos com problema. Antes de olhar, espera até
    $SettleSeconds o Windows terminar de instalar os drivers que a busca achou (o serviço de instalação de dispositivos
    fica ocupado enquanto isso): um dispositivo no meio da instalação aparece com problema por alguns segundos.
    -NotesOnly (dentro da Manutenção, todo mês): um problema que o WinForge não resolve, como um celular pareado sem
    driver, não deixa a etapa amarela todo mês; os nomes vão só nas observações.
    #>
    param (
        [switch]$NotesOnly,
        [int]$SettleSeconds = 20
    )

    $deadline = (Get-Date).AddSeconds($SettleSeconds)

    try {
        while ((Get-Date) -lt $deadline -and [string](Get-Service -Name "DeviceInstall" -ErrorAction Stop).Status -eq "Running") {
            Start-Sleep -Seconds 1
        }
    }
    catch {
        Write-Verbose "Serviço de instalação de dispositivos: $($_.Exception.Message)"
    }

    try {
        $devices = @(Get-PnpDevice -PresentOnly -ErrorAction Stop | Where-Object { Test-WinForgePnpDeviceHasProblem -Device $_ })
    }
    catch {
        Write-Verbose "Dispositivos com problema: $($_.Exception.Message)"
        return $null
    }

    $real = @($devices | Where-Object { (Get-WinForgeDeviceProblemCode -Device $_) -notin @(22, 29) })

    # Remaining e Problems: quantos e quais, para a faixa da janela.
    if ($real.Count -eq 0) { return (New-WinForgeResult -Kind Ok -Detail "o Windows procurou dispositivos novos e alterações de hardware; nenhum dispositivo com problema" -Data @{ Remaining = 0 }) }

    # "Câmera integrada (Câmera): o driver não está instalado (código 28); ...", como no Diagnóstico.
    $shown = @($real | Select-Object -First 3 | ForEach-Object { "$(Get-WinForgeDeviceName -Device $_): $(Get-WinForgeDeviceProblemText -Device $_)" })
    $list = ($shown -join "; ")
    if ($real.Count -gt $shown.Count) { $list += "; e mais $($real.Count - $shown.Count)" }

    $lead = if ($real.Count -eq 1) { "Ainda aparece com problema" } else { "Ainda aparecem com problema" }
    # O Windows pode ainda estar instalando um driver; o Diagnóstico diz o que fazer com cada dispositivo.
    $notes = @("${lead}: $list.", "Confira de novo em alguns minutos em Diagnóstico > Dispositivos com problema.")
    $data = @{ Notes = $notes; Remaining = $real.Count; Problems = $list }

    if (@($real | Where-Object { (Get-WinForgeDeviceProblemCode -Device $_) -eq 14 }).Count -gt 0) {
        $notes += "Reinicie o PC para o Windows terminar de preparar um dispositivo."
        $data = @{ Notes = $notes; RebootRequired = $true; Remaining = $real.Count; Problems = $list }
    }

    $countText = Format-WinForgeCount -Count $real.Count -One "dispositivo ainda aparece" -Many "dispositivos ainda aparecem"

    if ($NotesOnly) {
        return (New-WinForgeResult -Kind Ok -Detail "o Windows procurou dispositivos novos e alterações de hardware; $countText com problema" -Data $data)
    }

    return (New-WinForgeResult -Kind Warning -Detail "a busca terminou, mas $countText com problema" -Data $data)
}


Export-ModuleMember -Function *
