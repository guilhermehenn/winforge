# Desempenho: liberar memória, ver o que está pesando agora e "Acelerar agora" (memória + temporários, num clique).
#
# Sobre a memória, o WinForge é honesto: o Windows usa a memória livre como cache e a recupera sozinho. Liberar ajuda
# antes de abrir algo pesado (um jogo, um editor de vídeo) num PC com pouca memória; o efeito some aos poucos, conforme
# os programas voltam a usar o que precisam. A tela mostra quanto foi liberado de fato, medido antes e depois.
# O cache de arquivos (a lista de espera do Windows) não é esvaziado: ele já conta como memória disponível, e jogá-lo
# fora só faz o Windows ler de novo do disco o que estava pronto, deixando o PC mais lento por um tempo.


# ---------------------------------------------------------------------------
# Memória
# ---------------------------------------------------------------------------

# Abaixo disto, a memória liberada (e, no Acelerar agora, os temporários apagados) é "quase nada".
$script:WinForgeMemoryLittleBytes = 50MB

function Get-WinForgeMemoryUsage {
    # Total, disponível e em uso (bytes), como o Gerenciador de Tarefas mostra. $null sem leitura. -OperatingSystem: a
    # leitura do Win32_OperatingSystem que quem chama já fez (a página usa a mesma para o tempo ligado).
    param (
        $OperatingSystem = $null
    )

    $os = $OperatingSystem

    if ($null -eq $os) {
        try {
            $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
        }
        catch {
            return $null
        }
    }

    $total = [double](Get-WinForgeJsonValue -Object $os -Name "TotalVisibleMemorySize" -Default 0) * 1KB
    $available = [double](Get-WinForgeJsonValue -Object $os -Name "FreePhysicalMemory" -Default 0) * 1KB

    if ($total -le 0) { return $null }

    return [PSCustomObject]@{
        Total     = $total
        Available = $available
        Used      = [Math]::Max([double]0, $total - $available)
        Percent   = [int][Math]::Round(100 * [Math]::Max([double]0, $total - $available) / $total)
    }
}


function Test-WinForgeMemoryHigh {
    # Memória em uso alta: a partir de 85%. Uma regra só para a página, a lista dos que pesam e o Verificar o PC.
    param ([Parameter(Mandatory)]$Memory)

    return ([int]$Memory.Percent -ge 85)
}


function Get-WinForgePerformancePageStatus {
    <#
    O resumo no alto da página Desempenho: a memória em uso e há quanto tempo o PC está ligado, de uma leitura só do
    Windows, imediata. Cada linha tem Label, Text e Level (Normal | Warn | Muted). Memória a partir de 85% e o PC ligado
    há uma semana ou mais ficam em amarelo, com o que fazer.
    #>
    $os = $null

    try {
        $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
    }
    catch {
        return @([PSCustomObject]@{ Label = "Memória em uso"; Text = "não foi possível ler"; Level = "Muted" })
    }

    $rows = @()
    $memory = Get-WinForgeMemoryUsage -OperatingSystem $os

    if ($null -ne $memory) {
        $text = "$(Format-WinForgeBytes -Bytes $memory.Used) de $(Format-WinForgeBytes -Bytes $memory.Total) ($($memory.Percent)%)"

        if (Test-WinForgeMemoryHigh -Memory $memory) {
            $rows += [PSCustomObject]@{ Label = "Memória em uso"; Text = "$text · alta; veja Programas pesando agora"; Level = "Warn" }
        }
        else {
            $rows += [PSCustomObject]@{ Label = "Memória em uso"; Text = $text; Level = "Normal" }
        }
    }
    else {
        $rows += [PSCustomObject]@{ Label = "Memória em uso"; Text = "não foi possível ler"; Level = "Muted" }
    }

    $boot = Get-WinForgeJsonValue -Object $os -Name "LastBootUpTime" -Default $null

    if ($boot -is [datetime] -and $boot.Year -ge 2000) {
        $uptime = Get-WinForgeUptimeText -LastBootTime $boot

        # Um boot "no futuro" (o relógio acertado depois de ligar) não tem tempo ligado que se possa dizer: a linha sai,
        # como quando o Windows não informa a hora.
        if ($uptime -eq "Desconhecido") { return $rows }

        # Com a Inicialização Rápida, desligar não zera este tempo: só reiniciar zera.
        if (((Get-Date) - $boot).TotalDays -ge 7) {
            $rows += [PSCustomObject]@{ Label = "Ligado há"; Text = "$uptime · reiniciar deixa o Windows mais leve"; Level = "Warn" }
        }
        else {
            $rows += [PSCustomObject]@{ Label = "Ligado há"; Text = $uptime; Level = "Normal" }
        }
    }

    return $rows
}


function Initialize-WinForgeMemoryNative {
    # A chamada do Windows que esvazia a memória de trabalho dos processos.
    if ($null -ne ('WinForgeMemoryNative' -as [type])) { return }

    Add-Type -TypeDefinition @'
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;

public static class WinForgeMemoryNative
{
    [DllImport("psapi.dll")]
    private static extern bool EmptyWorkingSet(IntPtr process);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern IntPtr OpenProcess(uint access, bool inherit, int processId);

    [DllImport("kernel32.dll")]
    private static extern bool CloseHandle(IntPtr handle);

    // PROCESS_QUERY_INFORMATION | PROCESS_SET_QUOTA
    private const uint ProcessAccess = 0x0400 | 0x0100;

    // Só os processos da sessão da pessoa: os serviços do Windows (o antivírus, por exemplo) e os programas de outras
    // contas logadas no PC ficam como estão, sem ter de recarregar a memória por causa de quem pediu.
    public static int TrimWorkingSets()
    {
        int trimmed = 0;
        int session;
        int self;

        using (Process current = Process.GetCurrentProcess())
        {
            session = current.SessionId;
            self = current.Id;
        }

        foreach (Process process in Process.GetProcesses())
        {
            try
            {
                // O próprio WinForge fica: a memória dele voltaria na hora de desenhar o resultado, e a conta mentiria.
                if (process.SessionId != session || process.Id == self) { continue; }

                IntPtr handle = OpenProcess(ProcessAccess, false, process.Id);

                if (handle != IntPtr.Zero)
                {
                    if (EmptyWorkingSet(handle)) { trimmed++; }
                    CloseHandle(handle);
                }
            }
            catch (Exception)
            {
            }
            finally
            {
                process.Dispose();
            }
        }

        return trimmed;
    }
}
'@
}


function Invoke-WinForgeMemoryTrim {
    # Tira da memória as páginas dos processos da sessão da pessoa (os que o Windows deixa), menos o próprio WinForge.
    # Devolve quantos processos.
    Initialize-WinForgeMemoryNative

    return [WinForgeMemoryNative]::TrimWorkingSets()
}


function Optimize-WinForgeMemory {
    <#
    Libera memória e mede o efeito: Before e After (Get-WinForgeMemoryUsage) e Freed (bytes a menos em uso; nunca
    negativo). Espera um instante antes de medir de novo, para o Windows contabilizar.
    #>
    param (
        [int]$SettleMilliseconds = 1500
    )

    $before = Get-WinForgeMemoryUsage
    [void](Invoke-WinForgeMemoryTrim)

    if ($SettleMilliseconds -gt 0) { Start-Sleep -Milliseconds $SettleMilliseconds }

    $after = Get-WinForgeMemoryUsage
    $measured = ($null -ne $before -and $null -ne $after)
    $freed = $(if ($measured) { [Math]::Max([double]0, [double]$before.Used - [double]$after.Used) } else { 0 })

    # Measured falso: a memória foi esvaziada, mas o Windows não informou o uso antes ou depois; Freed 0 aí não quer
    # dizer "nada liberado".
    return [PSCustomObject]@{ Before = $before; After = $after; Measured = $measured; Freed = [double]$freed }
}


function Test-WinForgeMemoryFreedLittle {
    # Menos de 50 MB liberados é "quase nada": a memória já estava folgada. Sem a medição, não se sabe.
    param ([Parameter(Mandatory)]$Optimization)

    if (-not [bool](Get-WinForgeJsonValue -Object $Optimization -Name "Measured" -Default $true)) { return $false }

    return ([double]$Optimization.Freed -lt $script:WinForgeMemoryLittleBytes)
}


function Test-WinForgeMemoryStillHigh {
    # Verdadeiro quando, medida depois de liberar, a memória em uso continua alta (Test-WinForgeMemoryHigh): o que pesa são
    # os programas abertos, e esvaziar a memória deles não resolve. Sem a medição, falso (não se sabe).
    param ([Parameter(Mandatory)]$Optimization)

    if (-not [bool](Get-WinForgeJsonValue -Object $Optimization -Name "Measured" -Default $true)) { return $false }

    $after = Get-WinForgeJsonValue -Object $Optimization -Name "After" -Default $null

    return ($null -ne $after -and (Test-WinForgeMemoryHigh -Memory $after))
}


function Format-WinForgeMemoryFreedText {
    # "2 GB de memória liberados"; quase nada (Test-WinForgeMemoryFreedLittle), que a memória já estava folgada; sem a
    # leitura do Windows antes e depois, que a memória foi liberada sem medir. Com a memória ainda alta depois, nunca
    # "folgada": a frase diz que ela continua alta.
    param ([Parameter(Mandatory)]$Optimization)

    if (-not [bool](Get-WinForgeJsonValue -Object $Optimization -Name "Measured" -Default $true)) {
        return "memória liberada (o Windows não informou quanto)"
    }

    $high = Test-WinForgeMemoryStillHigh -Optimization $Optimization

    if (Test-WinForgeMemoryFreedLittle -Optimization $Optimization) {
        if ($high) { return "quase nada a liberar: a memória continua alta ($($Optimization.After.Percent)%)" }
        return "a memória já estava folgada (quase nada a liberar)"
    }

    $text = "$(Format-WinForgeBytes -Bytes $Optimization.Freed) de memória liberados"
    if ($high) { $text += "; a memória continua alta ($($Optimization.After.Percent)%)" }

    return $text
}


function Write-WinForgeMemoryStillHighNotice {
    # O aviso de que a memória continua alta depois de liberar: um aviso sobre o PC, que não conta no desfecho, com o lugar
    # que resolve.
    param ([Parameter(Mandatory)]$Optimization)

    if (-not (Test-WinForgeMemoryStillHigh -Optimization $Optimization)) { return $false }

    Write-WinForgeStatus -Type Warning -Notice -Message "A memória continua alta ($($Optimization.After.Percent)%): o que pesa são os programas abertos; veja Desempenho > Programas pesando agora."

    return $true
}


function Set-WinForgeMemoryStillHighView {
    <#
    A faixa de quando a memória continua alta depois de liberar: o título diz isso (amarelo), a frase diz que o peso são
    os programas abertos (com o que saiu, quando saiu algo que conte, e $Extra no fim) e o botão abre Programas pesando
    agora. Devolve o próprio resultado.
    #>
    param (
        [Parameter(Mandatory)]$Result,
        [Parameter(Mandatory)]$Optimization,
        [string]$Freed = "",
        [string]$Extra = ""
    )

    $note = $(
        if (Test-WinForgeMemoryFreedLittle -Optimization $Optimization) { "Liberar quase não ajudou: o que pesa são os programas abertos." }
        else { "$Freed liberados, mas o que pesa são os programas abertos." }
    )
    if ($Extra) { $note += " $Extra" }

    return (Set-WinForgeResultView -Result $Result -Headline "A memória continua alta ($($Optimization.After.Percent)%)" -Note $note -Tone Warn `
            -Next "performance.processes" -NextLabel "Ver o que está pesando")
}


function Write-WinForgeMemoryFacts {
    param ([Parameter(Mandatory)]$Optimization)

    if ($null -ne $Optimization.Before -and $null -ne $Optimization.After) {
        Write-WinForgeKeyValue -Label "Memória em uso antes" -Value "$(Format-WinForgeBytes -Bytes $Optimization.Before.Used) de $(Format-WinForgeBytes -Bytes $Optimization.Before.Total) ($($Optimization.Before.Percent)%)"
        $high = Test-WinForgeMemoryStillHigh -Optimization $Optimization
        Write-WinForgeKeyValue -Label "Memória em uso agora" -Value "$(Format-WinForgeBytes -Bytes $Optimization.After.Used) ($($Optimization.After.Percent)%)" -Level $(if ($high) { "Warn" } else { "Normal" })
        # Verde só quando liberou algo que faça diferença; "0 B" em verde pareceria uma conquista. "Folgada" só quando a
        # memória de fato está folgada: alta, o pouco que saiu é dos programas abertos que estão usando a memória.
        $freedValue = Format-WinForgeBytes -Bytes $Optimization.Freed
        if ((Test-WinForgeMemoryFreedLittle -Optimization $Optimization) -and -not $high) { $freedValue = "$freedValue (a memória já estava folgada)" }

        Write-WinForgeKeyValue -Label "Liberada" -Value $freedValue -Level $(if (-not (Test-WinForgeMemoryFreedLittle -Optimization $Optimization) -and -not $high) { "Ok" } else { "Normal" })
    }
    else {
        # Sem a leitura de antes e depois, "0 B" diria que nada saiu; o esvaziamento aconteceu, só não foi medido.
        Write-WinForgeKeyValue -Label "Liberada" -Value "não foi possível medir"
    }
}


function Set-WinForgeMemoryOptimizationView {
    <#
    A faixa de Liberar memória: quanto saiu no título, com a memória de agora e de antes embaixo. Folgada ou ainda alta,
    o título diz isso (alta, em amarelo e com o botão para o que está pesando). Quando a faixa já diz tudo, o resumo (as
    mesmas contas) fica nos detalhes. Devolve o próprio resultado.
    #>
    param (
        [Parameter(Mandatory)]$Result,
        [Parameter(Mandatory)]$Optimization
    )

    if (-not [bool](Get-WinForgeJsonValue -Object $Optimization -Name "Measured" -Default $true)) {
        return (Set-WinForgeResultView -Result $Result -Headline "Memória liberada" -Note "O Windows não informou quanto.")
    }

    $freed = "$(Format-WinForgeBytes -Bytes $Optimization.Freed) de memória"

    if (Test-WinForgeMemoryStillHigh -Optimization $Optimization) {
        return (Set-WinForgeMemoryStillHighView -Result $Result -Optimization $Optimization -Freed $freed)
    }

    # A memória de agora e de antes, quando o Windows informou as duas.
    $after = Get-WinForgeJsonValue -Object $Optimization -Name "After" -Default $null
    $before = Get-WinForgeJsonValue -Object $Optimization -Name "Before" -Default $null
    $now = $(if ($null -ne $after) { "Memória em uso: $($after.Percent)%" } else { "" })

    if (Test-WinForgeMemoryFreedLittle -Optimization $Optimization) {
        return (Set-WinForgeResultView -Result $Result -Headline "A memória já estava folgada" -Note $(if ($now) { "$now; quase nada a liberar." } else { "Quase nada a liberar." }) -HideSummary)
    }

    $lead = $(if ($now -and $null -ne $before) { "$now (antes, $($before.Percent)%). " } else { "" })

    return (Set-WinForgeResultView -Result $Result -Headline "$freed liberados" -Note "${lead}Ajuda antes de abrir algo pesado; o efeito some aos poucos." -HideSummary)
}


function Invoke-WinForgeMemoryOptimization {
    $title = "Liberar memória"

    Enter-WinForgeAction -Title $title

    $final = New-WinForgeResult -Kind Ok -Title $title

    try {
        Write-Progress -Activity $title -Status "esvaziando a memória que os programas não estão usando"

        try {
            $optimization = Optimize-WinForgeMemory
        }
        finally {
            Write-Progress -Activity $title -Completed
        }

        Write-WinForgeMemoryFacts -Optimization $optimization
        Write-Host ""

        # Os programas abertos recarregam o que voltarem a usar: o efeito some aos poucos. O cache de arquivos do Windows
        # fica como está: ele já conta como memória disponível e faz os programas abrirem mais rápido. Com a memória ainda
        # alta, o conselho é outro: o que pesa são os programas abertos.
        if (-not (Write-WinForgeMemoryStillHighNotice -Optimization $optimization)) {
            Write-WinForgeStatus -Type Info -Message "Ajuda antes de abrir algo pesado; o efeito some aos poucos."
        }

        $final = New-WinForgeResult -Kind Ok -Detail (Format-WinForgeMemoryFreedText -Optimization $optimization) -Title $title -Data @{ FreedBytes = [int64]$optimization.Freed }
        [void](Set-WinForgeMemoryOptimizationView -Result $final -Optimization $optimization)
    }
    catch {
        # A mensagem do .NET (DLL, ponto de entrada, modo de linguagem) não diz nada para a pessoa; fica no detalhe técnico.
        Write-Verbose "Liberar memória: $($_.Exception.Message)"
        Write-WinForgeStatus -Type Error -Message "Não foi possível liberar a memória: o Windows não atendeu ao pedido."
        $final = New-WinForgeResult -Kind Failed -Detail "o Windows não atendeu ao pedido de liberar a memória" -Title $title
    }

    Exit-WinForgeAction -Result $final
}


function Set-WinForgeBoostView {
    <#
    A faixa do Acelerar agora. O título diz o que importa: quanto de memória saiu (ou os temporários, quando eles foram o
    ganho), que o PC já estava leve, que a memória continua alta (amarelo, com o botão para o que está pesando) ou que ela
    não foi liberada; embaixo vêm a memória de agora e de antes e os temporários. O que deu errado com os temporários e
    a conta diferente vão no fim da frase, e aí o resumo fica à vista. Devolve o próprio resultado.
    #>
    param (
        [Parameter(Mandatory)]$Result,
        $Optimization = $null,
        [int64]$TempBytes = 0,
        $Temp = $null,
        [bool]$OtherAccount = $false
    )

    $tempText = Format-WinForgeBytes -Bytes $TempBytes
    $tempFailed = ($null -ne $Temp -and [string]$Temp.Kind -eq "Failed")
    $tempPart = $(if ($tempFailed) { "" } elseif ($TempBytes -le 0) { "nenhum temporário para apagar" } else { "$tempText de temporários apagados" })

    $extra = @(
        if ($tempFailed) { "Os temporários não foram apagados: $(([string]$Temp.Detail).Trim().TrimEnd('.'))." }
        if ($OtherAccount) { "Os temporários apagados foram os da conta com que o WinForge está aberto." }
    ) -join " "

    # A frase: a parte principal, os temporários (quando não estão no título) e o que deu errado.
    $join = {
        param ([string]$Lead, [string]$Temps)
        $text = $Lead
        if ($Temps) { $text = $(if ($text) { "$text; $Temps" } else { $Temps }) }
        if ($text -and -not $text.EndsWith(".")) { $text += "." }
        if ($text) { $text = $text.Substring(0, 1).ToUpper() + $text.Substring(1) }
        (@($text, $extra) | Where-Object { $_ }) -join " "
    }

    $hide = ([string]$Result.Kind -eq "Ok")

    if ($null -eq $Optimization) {
        return (Set-WinForgeResultView -Result $Result -Headline "A memória não foi liberada" -Note (& $join "O Windows não atendeu ao pedido" $tempPart))
    }

    if (-not [bool](Get-WinForgeJsonValue -Object $Optimization -Name "Measured" -Default $true)) {
        return (Set-WinForgeResultView -Result $Result -Headline "Memória liberada" -Note (& $join "O Windows não informou quanto" $tempPart))
    }

    $memory = "$(Format-WinForgeBytes -Bytes $Optimization.Freed) de memória"
    $little = Test-WinForgeMemoryFreedLittle -Optimization $Optimization

    if (Test-WinForgeMemoryStillHigh -Optimization $Optimization) {
        $freed = $(if ($tempFailed -or $TempBytes -le 0) { $memory } else { "$memory e $tempText de temporários" })
        return (Set-WinForgeMemoryStillHighView -Result $Result -Optimization $Optimization -Freed $freed -Extra $extra)
    }

    # A memória de agora e de antes, quando o Windows informou as duas.
    $after = Get-WinForgeJsonValue -Object $Optimization -Name "After" -Default $null
    $before = Get-WinForgeJsonValue -Object $Optimization -Name "Before" -Default $null
    $now = $(if ($null -ne $after) { "Memória em uso: $($after.Percent)%" } else { "" })

    if ($little -and $TempBytes -lt $script:WinForgeMemoryLittleBytes) {
        return (Set-WinForgeResultView -Result $Result -Headline "O PC já estava leve" -Note (& $join $(if ($now) { "$now; quase nada a liberar" } else { "Quase nada a liberar" }) "") -HideSummary:$hide)
    }

    if ($little) {
        # A memória já estava folgada, e o ganho foram os temporários: eles vão no título.
        return (Set-WinForgeResultView -Result $Result -Headline "$tempText de temporários apagados" -Note (& $join "A memória já estava folgada$(if ($null -ne $after) { " ($($after.Percent)% em uso)" })" "") -HideSummary:$hide)
    }

    $note = & $join $(if ($now -and $null -ne $before) { "$now (antes, $($before.Percent)%)" } else { "" }) $tempPart
    if (-not $tempFailed -and -not $OtherAccount) { $note += " O efeito na memória some aos poucos." }

    return (Set-WinForgeResultView -Result $Result -Headline "$memory liberados" -Note $note -HideSummary:$hide)
}


function Invoke-WinForgeBoost {
    # Acelerar agora: libera memória e apaga os temporários do usuário, sem perguntar nada (nada disso faz falta).
    $title = "Acelerar agora"

    Enter-WinForgeAction -Title $title

    $final = New-WinForgeResult -Kind Ok -Title $title

    try {
        Write-Progress -Activity $title -Status "1 de 2: liberando memória" -PercentComplete 0

        try {
            # As duas partes são independentes: a memória que o Windows não deixou liberar não impede apagar os temporários.
            $optimization = $null

            try {
                $optimization = Optimize-WinForgeMemory
            }
            catch {
                Write-Verbose "Acelerar agora, memória: $($_.Exception.Message)"
                Write-WinForgeStatus -Type Warning -Message "Não foi possível liberar a memória: o Windows não atendeu ao pedido."
            }

            Write-Progress -Activity $title -Status "2 de 2: apagando temporários" -PercentComplete 50
            $temp = Clear-WinForgeUserTemp -Embedded -PassThru
        }
        finally {
            Write-Progress -Activity $title -Completed
        }

        $tempBytes = [int64](Get-WinForgeResultData -Result $temp -Name "FreedBytes")
        $tempText = Format-WinForgeBytes -Bytes $tempBytes

        Write-WinForgeSection -Title "Resultado"

        if ($null -ne $optimization) {
            Write-WinForgeMemoryFacts -Optimization $optimization
        }
        else {
            Write-WinForgeKeyValue -Label "Memória" -Value "não foi possível liberar" -Level Warn
        }

        Write-WinForgeKeyValue -Label "Temporários apagados" -Value $tempText
        Write-Host ""

        # Com a memória ainda alta, o aviso diz onde está o peso (os programas abertos); senão, o conselho de sempre.
        $stillHigh = ($null -ne $optimization -and (Write-WinForgeMemoryStillHighNotice -Optimization $optimization))

        if (-not $stillHigh) {
            Write-WinForgeStatus -Type Info -Message "Para durar, use Desempenho > Gerenciar inicialização e Desempenho > Programas pesando agora."
        }

        # Sem pergunta, o aviso da outra conta fica no resumo, e a faixa fica amarela: os temporários apagados foram os
        # dessa conta.
        $otherAccount = Write-WinForgeOtherAccountNotice -What "os temporários apagados"

        $detail = $(
            if ($null -eq $optimization) { "a memória não foi liberada; $tempText de temporários apagados" }
            elseif (-not $optimization.Measured) { "$(Format-WinForgeMemoryFreedText -Optimization $optimization) e $tempText de temporários apagados" }
            elseif ($stillHigh) { "$(Format-WinForgeBytes -Bytes $optimization.Freed) de memória e $tempText de temporários liberados; a memória continua alta ($($optimization.After.Percent)%)" }
            elseif ((Test-WinForgeMemoryFreedLittle -Optimization $optimization) -and $tempBytes -lt $script:WinForgeMemoryLittleBytes) { "o PC já estava leve: quase nada a liberar" }
            else { "$(Format-WinForgeBytes -Bytes $optimization.Freed) de memória e $tempText de temporários liberados" }
        )
        $kind = $(if ($null -eq $optimization -or $temp.Kind -eq "Failed" -or $otherAccount) { "Warning" } else { "Ok" })
        if ($otherAccount) { $detail += "; os temporários apagados foram os da conta com que o WinForge está aberto" }
        $final = New-WinForgeResult -Kind $kind -Detail $detail -Title $title -Data @{ FreedBytes = [int64]$tempBytes }
        [void](Set-WinForgeBoostView -Result $final -Optimization $optimization -TempBytes $tempBytes -Temp $temp -OtherAccount ([bool]$otherAccount))
    }
    catch {
        Write-WinForgeStatus -Type Error -Message "Não foi possível acelerar: $($_.Exception.Message.TrimEnd('.'))."
        $final = New-WinForgeResult -Kind Failed -Detail $_.Exception.Message.TrimEnd('.') -Title $title
    }

    Exit-WinForgeAction -Result $final
}


# ---------------------------------------------------------------------------
# Programas pesando agora
# ---------------------------------------------------------------------------

function Get-WinForgeProtectedProcessNames {
    # Processos que não podem ser fechados por aqui: os do Windows (fechá-los derruba a sessão ou o próprio Windows), os
    # de instalação e atualização (fechá-los no meio estraga a instalação) e os que hospedam o próprio WinForge (o
    # PowerShell e o terminal do console). Também os que o Windows divide entre vários programas: o WebView2 (Teams,
    # Outlook, Widgets e a busca desenham as janelas com ele; encerrá-lo derruba todos), a moldura dos aplicativos da
    # Store (ApplicationFrameHost) e a busca do Windows 10 (SearchApp).
    return @(
        "Idle", "System", "Registry", "smss", "csrss", "wininit", "winlogon", "services", "lsass", "lsaiso", "svchost", "dwm",
        "fontdrvhost", "Memory Compression", "explorer", "sihost", "ctfmon", "taskhostw", "RuntimeBroker", "SearchHost",
        "SearchIndexer", "StartMenuExperienceHost", "ShellExperienceHost", "TextInputHost", "audiodg", "spoolsv", "conhost",
        "WmiPrvSE", "MsMpEng", "NisSrv", "SecurityHealthService", "SecurityHealthSystray", "SgrmBroker", "smartscreen",
        "dllhost", "LsaIso", "Secure System", "LogonUI", "WUDFHost", "msiexec", "TiWorker", "TrustedInstaller",
        "MoUsoCoreWorker", "wuauclt", "UsoClient", "powershell", "pwsh", "WindowsTerminal", "OpenConsole", "WinForge",
        "msedgewebview2", "ApplicationFrameHost", "SearchApp", "SearchUI", "LockApp", "ShellHost", "Widgets", "WidgetService",
        "backgroundTaskHost", "rundll32", "SystemSettingsBroker", "UserOOBEBroker", "ChsIME", "TabTip", "AggregatorHost",
        "MpDefenderCoreService"
    )
}


function Get-WinForgePrivateWorkingSets {
    <#
    A memória de cada processo como o Gerenciador de Tarefas mostra (o conjunto de trabalho privado), por número de
    processo. O WorkingSet64 conta também as bibliotecas que vários processos dividem: somado nos 30 processos de um
    navegador, dava várias vezes a memória de verdade. Vazio sem resposta do Windows (quem chama usa outra medida).
    #>
    $map = @{}

    try {
        foreach ($row in @(Get-CimInstance -ClassName Win32_PerfRawData_PerfProc_Process -Property IDProcess, WorkingSetPrivate -OperationTimeoutSec 5 -ErrorAction Stop)) {
            $id = [int](Get-WinForgeJsonValue -Object $row -Name "IDProcess" -Default 0)
            $bytes = Get-WinForgeJsonValue -Object $row -Name "WorkingSetPrivate" -Default $null

            if ($id -gt 0 -and $null -ne $bytes) { $map[$id] = [double]$bytes }
        }
    }
    catch {
        Write-Verbose "Memória por processo: $($_.Exception.Message)"
    }

    return $map
}


function Get-WinForgeProcessSample {
    <#
    Lê os processos duas vezes (com $IntervalMilliseconds entre as leituras) e devolve, por programa (processos com o
    mesmo nome somados): Name, Description, Company, Count, Cpu (% do PC no intervalo), CpuUnread (quantos processos o
    Windows não deixou medir: abertos como Administrador, com o WinForge sem), Memory (bytes, o conjunto de trabalho
    privado, como no Gerenciador de Tarefas), Ids, Processes e Protected. Description e Company começam com o nome do
    processo; Add-WinForgeProcessDetails as preenche só para os que vão aparecer. Só entram os processos desta sessão do
    Windows: os de serviços (sessão 0) e os de outras contas logadas (troca rápida de usuário) não são da pessoa.
    Processes guarda, de cada um, o Id e a hora em que começou: entre medir e fechar passam minutos, e o Windows
    reaproveita o número de um processo que saiu. A memória é lida no intervalo entre as duas leituras, que é de espera.
    #>
    param (
        [int]$IntervalMilliseconds = 1500
    )

    # Cada leitura guarda a hora em que foi feita: o intervalo de cada processo é o dele, e não o de uma lista inteira
    # até a outra (percorrer centenas de processos leva tempo, e o uso pareceria maior).
    $clock = [System.Diagnostics.Stopwatch]::StartNew()
    $session = [System.Diagnostics.Process]::GetCurrentProcess().SessionId
    $first = @{}

    foreach ($process in @(Get-Process -ErrorAction SilentlyContinue)) {
        if ($process.SessionId -ne $session) { continue }

        # Sem acesso, o Windows nega a leitura: conforme o PowerShell, isso vem como erro ou como valor vazio. Os dois
        # contam como "sem leitura".
        try {
            $time = $process.TotalProcessorTime
            $first[$process.Id] = $(if ($null -ne $time) { [PSCustomObject]@{ Cpu = $time.TotalMilliseconds; At = $clock.Elapsed.TotalMilliseconds } } else { $null })
        }
        catch {
            $first[$process.Id] = $null
        }
    }

    $privateSets = Get-WinForgePrivateWorkingSets
    $remaining = $IntervalMilliseconds - $clock.Elapsed.TotalMilliseconds
    if ($remaining -gt 0) { Start-Sleep -Milliseconds ([int]$remaining) }
    $cores = [Math]::Max(1, [Environment]::ProcessorCount)
    $protected = Get-WinForgeProtectedProcessNames
    $groups = @{}

    foreach ($process in @(Get-Process -ErrorAction SilentlyContinue)) {
        if ($process.Id -eq $PID -or $process.Id -eq 0) { continue }
        if ($process.SessionId -ne $session) { continue }

        # Um processo que começou no intervalo não tem a primeira leitura: o uso dele fica de fora (zero), sem contar como
        # "sem leitura". O que o Windows não deixa ler (aberto como Administrador) conta.
        $cpu = 0.0
        $cpuRead = $true

        try {
            $previous = $first[$process.Id]
            if ($first.ContainsKey($process.Id) -and $null -eq $previous) { $cpuRead = $false }

            if ($null -ne $previous) {
                $time = $process.TotalProcessorTime

                if ($null -eq $time) {
                    $cpuRead = $false
                }
                else {
                    $gap = [Math]::Max([double]1, $clock.Elapsed.TotalMilliseconds - $previous.At)

                    # Limitado a 100%: um número de processo reaproveitado no intervalo somaria o tempo de outro processo.
                    $cpu = [Math]::Min([double]100, [Math]::Max([double]0, ($time.TotalMilliseconds - $previous.Cpu) / $gap / $cores * 100))
                }
            }
        }
        catch {
            $cpu = 0.0
            $cpuRead = $false
        }

        $name = [string]$process.ProcessName

        if (-not $groups.ContainsKey($name)) {
            $groups[$name] = [PSCustomObject]@{
                Name        = $name
                Description = $name
                Company     = ""
                Count       = 0
                Cpu         = 0.0
                CpuUnread   = 0
                Memory      = [double]0
                Ids         = New-Object System.Collections.ArrayList
                Processes   = New-Object System.Collections.ArrayList
                Protected   = ($protected -contains $name)
            }
        }

        $startTicks = $null
        try { $start = $process.StartTime; if ($null -ne $start) { $startTicks = $start.Ticks } } catch { $startTicks = $null }

        $memory = $privateSets[[int]$process.Id]

        if ($null -eq $memory) {
            # Sem a leitura do Windows, a memória privada do processo (inclui o que está no arquivo de paginação), que ao
            # menos não soma várias vezes o que os processos dividem.
            try { $memory = [double]$process.PrivateMemorySize64 } catch { $memory = [double]$process.WorkingSet64 }
        }

        $group = $groups[$name]
        $group.Count++
        $group.Cpu += $cpu
        if (-not $cpuRead) { $group.CpuUnread++ }
        $group.Memory += [double]$memory
        [void]$group.Ids.Add($process.Id)
        [void]$group.Processes.Add([PSCustomObject]@{ Id = $process.Id; StartTicks = $startTicks })
    }

    # Um programa inteiro também não passa de 100% do PC.
    foreach ($group in $groups.Values) { if ($group.Cpu -gt 100) { $group.Cpu = [double]100 } }

    return @($groups.Values)
}


function Add-WinForgeProcessDetails {
    <#
    O nome amigável e o fabricante (lidos do arquivo do programa) dos programas que vão aparecer. Ler o módulo de um
    processo custa, e numa sessão há centenas deles: a medição deixa isso para cá, só para a dúzia que aparece. Sem
    leitura (aberto como Administrador, com o WinForge sem), fica o nome do processo.
    #>
    param ([object[]]$Groups = @())

    foreach ($group in $Groups) {
        foreach ($id in @(Get-WinForgeJsonValue -Object $group -Name "Ids" -Default @())) {
            $process = Get-Process -Id ([int]$id) -ErrorAction SilentlyContinue
            if ($null -eq $process) { continue }

            try {
                $version = $process.MainModule.FileVersionInfo
            }
            catch {
                continue
            }

            $description = ([string]$version.FileDescription).Trim()
            if ($description) { $group.Description = $description }
            $group.Company = ([string]$version.CompanyName).Trim()
            break
        }
    }
}


function Get-WinForgeHeavyProcesses {
    # Os programas que mais pesam: os $Top de maior CPU e os $Top de maior memória, sem repetir, do mais pesado ao mais
    # leve, com o nome amigável e o fabricante.
    param (
        [object[]]$Sample = @(Get-WinForgeProcessSample),
        [int]$Top = 6
    )

    $byCpu = @($Sample | Where-Object { $_.Cpu -ge 1 } | Sort-Object -Property Cpu -Descending | Select-Object -First $Top)
    $byMemory = @($Sample | Sort-Object -Property Memory -Descending | Select-Object -First $Top)
    $names = @($byCpu + $byMemory | ForEach-Object { $_.Name } | Select-Object -Unique)
    # Na ordem em que a tela mostra: pelo processador arredondado ("quase parado" empata em zero) e, no empate, pela memória.
    $heavy = @($Sample | Where-Object { $names -contains $_.Name } | Sort-Object -Property @{ Expression = { if ($_.Cpu -ge 1) { [Math]::Round($_.Cpu) } else { 0 } }; Descending = $true }, @{ Expression = { $_.Memory }; Descending = $true })

    Add-WinForgeProcessDetails -Groups $heavy

    return $heavy
}


function Format-WinForgeProcessUsage {
    # "18% do processador · 2,1 GB de memória". Sem nenhum processo do programa medido (aberto como Administrador, com o
    # WinForge sem), o processador fica "sem leitura": "quase parado" seria um palpite. Com parte sem leitura e o resto
    # parado, "sem leitura em parte": o processo que não deu para medir pode ser o ocupado.
    param ([Parameter(Mandatory)]$Process)

    $count = [int](Get-WinForgeJsonValue -Object $Process -Name "Count" -Default 1)
    $unread = [int](Get-WinForgeJsonValue -Object $Process -Name "CpuUnread" -Default 0)

    $cpuText = $(
        if ($Process.Cpu -ge 1) { "$([int][Math]::Round($Process.Cpu))% do processador" }
        elseif ($unread -gt 0 -and $unread -ge $count) { "processador sem leitura" }
        elseif ($unread -gt 0) { "processador sem leitura em parte" }
        else { "processador quase parado" }
    )

    return "$cpuText · $(Format-WinForgeBytes -Bytes $Process.Memory) de memória"
}


function Get-WinForgeProtectedProcessReason {
    # Por que um processo protegido não entra na lista para fechar, na marca que ele leva na lista dos que pesam.
    param ([Parameter(Mandatory)][string]$Name)

    # O WinForge que está aberto fica fora da lista; um PowerShell ou terminal que aparece pode ser o monitor da bandeja,
    # a janela de texto do WinForge ou um script seu: fechar por aqui poderia derrubar o WinForge.
    if ($Name -eq "WinForge") { return "usado pelo WinForge" }
    if ($Name -in @("powershell", "pwsh", "WindowsTerminal", "OpenConsole")) { return "pode ser o WinForge" }
    if ($Name -in @("msiexec", "TiWorker", "TrustedInstaller", "MoUsoCoreWorker", "wuauclt", "UsoClient")) { return "instalação ou atualização" }
    if ($Name -in @("msedgewebview2", "rundll32", "dllhost")) { return "usado por vários programas" }

    return "do Windows"
}


function Get-WinForgeSampledProcess {
    # O processo medido, se ainda for ele: o mesmo número, o mesmo nome e a mesma hora de início (o Windows reaproveita
    # o número de um processo que saiu). $null quando saiu, quando o número agora é de outro processo ou quando não dá
    # para confirmar (sem a hora de início, nada é fechado).
    param (
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)]$Entry
    )

    $running = Get-Process -Id ([int]$Entry.Id) -ErrorAction SilentlyContinue

    if ($null -eq $running -or [string]$running.ProcessName -ne $Name) { return $null }
    if ($null -eq $Entry.StartTicks) { return $null }

    try {
        $start = $running.StartTime
        if ($null -eq $start -or $start.Ticks -ne [int64]$Entry.StartTicks) { return $null }
    }
    catch {
        return $null
    }

    return $running
}


function Test-WinForgeSampledProcessUnconfirmed {
    # Verdadeiro quando o processo medido parece continuar aberto (o mesmo número e o mesmo nome), mas não dá para
    # conferir a hora de início: sem Administrador, o Windows nega lê-la num programa aberto como Administrador. Ele não
    # foi fechado, e a tela não pode dizer que foi.
    param (
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)]$Entry
    )

    $running = Get-Process -Id ([int]$Entry.Id) -ErrorAction SilentlyContinue

    if ($null -eq $running -or [string]$running.ProcessName -ne $Name) { return $false }
    if ($null -eq $Entry.StartTicks) { return $true }

    # A leitura negada vem como erro ou como valor vazio, conforme o PowerShell: as duas são "não deu para conferir".
    try {
        if ($null -eq $running.StartTime) { return $true }
    }
    catch {
        return $true
    }

    # A hora de início é legível e não bate: o número é de outro processo, e o medido já saiu.
    return $false
}


function Get-WinForgeProcessParents {
    # O processo pai de cada processo com este nome (Win32_Process): Id -> Id do pai. Vazio sem resposta do Windows.
    param ([Parameter(Mandatory)][string]$Name)

    $map = @{}
    $wql = ($Name + ".exe") -replace '\\', '\\' -replace "'", "\'"

    try {
        foreach ($row in @(Get-CimInstance -ClassName Win32_Process -Filter "Name = '$wql'" -Property ProcessId, ParentProcessId -OperationTimeoutSec 5 -ErrorAction Stop)) {
            $map[[int](Get-WinForgeJsonValue -Object $row -Name "ProcessId" -Default 0)] = [int](Get-WinForgeJsonValue -Object $row -Name "ParentProcessId" -Default 0)
        }
    }
    catch {
        Write-Verbose "Processos pai de ${Name}: $($_.Exception.Message)"
    }

    return $map
}


function Initialize-WinForgeWindowNative {
    # As chamadas do Windows que acham a moldura de um aplicativo da Store e pedem para fechá-la (como o X).
    if ($null -ne ('WinForgeWindowNative' -as [type])) { return }

    Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;

public sealed class WinForgeAppFrame
{
    public int ProcessId;
    public IntPtr Window;
}

public static class WinForgeWindowNative
{
    private delegate bool EnumWindowsProc(IntPtr window, IntPtr parameter);

    [DllImport("user32.dll")]
    private static extern bool EnumWindows(EnumWindowsProc callback, IntPtr parameter);

    [DllImport("user32.dll")]
    private static extern bool EnumChildWindows(IntPtr parent, EnumWindowsProc callback, IntPtr parameter);

    [DllImport("user32.dll")]
    private static extern uint GetWindowThreadProcessId(IntPtr window, out uint processId);

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    private static extern int GetClassName(IntPtr window, StringBuilder name, int size);

    [DllImport("user32.dll")]
    private static extern bool IsWindowVisible(IntPtr window);

    [DllImport("user32.dll")]
    private static extern bool PostMessage(IntPtr window, uint message, IntPtr wParam, IntPtr lParam);

    private static string ClassOf(IntPtr window)
    {
        StringBuilder name = new StringBuilder(256);
        GetClassName(window, name, name.Capacity);
        return name.ToString();
    }

    // Cada moldura visível (ApplicationFrameWindow, do ApplicationFrameHost) com a janela de um aplicativo da Store
    // dentro (Windows.UI.Core.CoreWindow, do processo do aplicativo).
    public static WinForgeAppFrame[] ListAppFrames()
    {
        List<WinForgeAppFrame> frames = new List<WinForgeAppFrame>();

        EnumWindows(delegate (IntPtr frame, IntPtr unused)
        {
            if (!IsWindowVisible(frame) || ClassOf(frame) != "ApplicationFrameWindow") { return true; }

            uint host;
            GetWindowThreadProcessId(frame, out host);

            EnumChildWindows(frame, delegate (IntPtr child, IntPtr unusedChild)
            {
                uint owner;
                GetWindowThreadProcessId(child, out owner);

                if (owner != host && ClassOf(child) == "Windows.UI.Core.CoreWindow")
                {
                    WinForgeAppFrame item = new WinForgeAppFrame();
                    item.ProcessId = (int)owner;
                    item.Window = frame;
                    frames.Add(item);
                    return false;
                }

                return true;
            }, IntPtr.Zero);

            return true;
        }, IntPtr.Zero);

        return frames.ToArray();
    }

    // Como o X da moldura: pede para fechar (WM_CLOSE), sem esperar.
    public static bool RequestClose(IntPtr window)
    {
        return PostMessage(window, 0x0010, IntPtr.Zero, IntPtr.Zero);
    }
}
'@
}


function Get-WinForgeAppFrameWindows {
    <#
    As janelas dos aplicativos da Store abertas agora: Id do processo do aplicativo -> a moldura do Windows que a mostra.
    Esses aplicativos desenham a janela dentro de uma moldura de outro processo (ApplicationFrameHost), então o
    MainWindowHandle deles vem vazio mesmo com a janela na tela. Vazio sem resposta do Windows. Um aplicativo minimizado
    pode não aparecer (o Windows tira a janela de dentro da moldura).
    #>
    $map = @{}

    try {
        Initialize-WinForgeWindowNative

        foreach ($frame in @([WinForgeWindowNative]::ListAppFrames())) {
            $map[[int]$frame.ProcessId] = $frame.Window
        }
    }
    catch {
        Write-Verbose "Janelas dos aplicativos da Store: $($_.Exception.Message)"
    }

    return $map
}


function Close-WinForgeAppFrameWindow {
    # Pede para fechar a moldura de um aplicativo da Store, como o X. Falso quando o Windows não aceitou o pedido.
    param ([Parameter(Mandatory)][IntPtr]$Window)

    try {
        Initialize-WinForgeWindowNative
        return [bool][WinForgeWindowNative]::RequestClose($Window)
    }
    catch {
        Write-Verbose "Fechar a janela do aplicativo: $($_.Exception.Message)"
        return $false
    }
}


function Test-WinForgeProcessGroupWindowless {
    <#
    Verdadeiro quando o programa continua aberto e nenhum processo dele tem janela: fechar como no X não tem onde
    clicar, só encerrando à força. Um processo que não dá para conferir (aberto como Administrador, com o WinForge sem)
    não conta como sem janela: ele nem seria encerrado, e perguntar sobre "encerrar à força" seria enganoso.
    #>
    param ([Parameter(Mandatory)]$Process)

    $name = [string]$Process.Name
    $alive = 0
    $frames = $null

    foreach ($entry in @(Get-WinForgeJsonValue -Object $Process -Name "Processes" -Default @())) {
        $running = Get-WinForgeSampledProcess -Name $name -Entry $entry

        if ($null -eq $running) {
            if (Test-WinForgeSampledProcessUnconfirmed -Name $name -Entry $entry) { return $false }
            continue
        }

        if ($running.MainWindowHandle -ne [IntPtr]::Zero) { return $false }

        # Um aplicativo da Store tem a janela dentro da moldura do Windows: ela existe, e fecha como no X.
        if ($null -eq $frames) { $frames = Get-WinForgeAppFrameWindows }
        if ($frames.ContainsKey([int]$running.Id)) { return $false }

        $alive++
    }

    return ($alive -gt 0)
}


function Stop-WinForgeProcessGroup {
    <#
    Fecha um programa: primeiro pedindo para fechar cada janela, como o X (a de um aplicativo da Store é a moldura do
    Windows em volta dela, Get-WinForgeAppFrameWindows), e esperando até $WaitMilliseconds (a espera
    acaba assim que elas fecham: um programa que fecha na hora não segura a tela, e um que demora a salvar tem tempo).
    O que não fecha fica aberto, com o motivo: uma caixa de diálogo aberta (o Windows nem entrega o pedido), a janela
    que continua aberta (pode estar perguntando "Salvar alterações?", ou há outra janela) ou o programa que foi para
    perto do relógio (fechar a janela só o escondeu). Só depois que as janelas fecharam, saem os processos sem janela
    que são do programa (abertos por ele, pelo processo pai): um processo de mesmo nome que é de outro programa (outro
    "python", outro "javaw") fica. Um programa sem nenhuma janela só é encerrado com -AllowForce, que a tela só passa
    depois de perguntar: é como encerrar pelo Gerenciador de Tarefas, e o que não foi salvo pode ser perdido (uma
    gravação, uma máquina virtual). Antes de agir em cada processo, confere que o número ainda é do mesmo processo
    medido. Devolve um WinForge.Result.
    #>
    param (
        [Parameter(Mandatory)]$Process,
        [int]$WaitMilliseconds = 5000,
        [switch]$AllowForce
    )

    $name = [string]$Process.Name
    $entries = @(Get-WinForgeJsonValue -Object $Process -Name "Processes" -Default @())
    $windowed = @()
    $background = @()
    $unconfirmed = 0
    $dialog = 0
    $frames = $null
    $framed = @{}

    foreach ($entry in $entries) {
        $running = Get-WinForgeSampledProcess -Name $name -Entry $entry

        if ($null -eq $running) {
            # Saiu, ou o número agora é de outro programa: não há o que fechar. Mas o mesmo programa ainda aberto sem a
            # hora de início legível (aberto como Administrador, com o WinForge sem) não pode ser dado como fechado.
            if (Test-WinForgeSampledProcessUnconfirmed -Name $name -Entry $entry) { $unconfirmed++ }
            continue
        }

        if ($running.MainWindowHandle -ne [IntPtr]::Zero) {
            # Falso: a janela tem uma caixa de diálogo aberta, e o pedido de fechar nem é entregue.
            if ($running.CloseMainWindow()) { $windowed += $entry } else { $dialog++ }
            continue
        }

        # Um aplicativo da Store tem a janela dentro da moldura do Windows (de outro processo): fechar a moldura é o X
        # dele. Se o pedido não for atendido, a espera abaixo vê a janela ainda aberta e diz isso.
        if ($null -eq $frames) { $frames = Get-WinForgeAppFrameWindows }

        if ($frames.ContainsKey([int]$running.Id)) {
            [void](Close-WinForgeAppFrameWindow -Window $frames[[int]$running.Id])
            $windowed += $entry
            $framed[[int]$entry.Id] = $true
        }
        else {
            $background += $entry
        }
    }

    $stillOpen = 0
    $tray = 0

    if ($windowed.Count -gt 0) {
        $deadline = (Get-Date).AddMilliseconds($WaitMilliseconds)
        $open = @()

        do {
            Start-Sleep -Milliseconds 250
            $open = @($windowed | ForEach-Object { Get-WinForgeSampledProcess -Name $name -Entry $_ } | Where-Object { $null -ne $_ })

            # O aplicativo da Store sai logo depois de a moldura fechar (o Windows o suspende e encerra): sem a moldura, ele
            # não conta mais como aberto, nem como "perto do relógio".
            if ($framed.Count -gt 0 -and $open.Count -gt 0) {
                $framesNow = Get-WinForgeAppFrameWindows
                $open = @($open | Where-Object { -not $framed.ContainsKey([int]$_.Id) -or $framesNow.ContainsKey([int]$_.Id) })
            }
        } while ($open.Count -gt 0 -and (Get-Date) -lt $deadline)

        foreach ($running in $open) {
            if ($framed.ContainsKey([int]$running.Id) -or $running.MainWindowHandle -ne [IntPtr]::Zero) { $stillOpen++ } else { $tray++ }
        }
    }

    $hadWindow = ($windowed.Count + $dialog) -gt 0
    $failed = 0
    $left = 0
    $targets = @()

    if (-not $hadWindow -and $AllowForce) {
        $targets = @($background)
    }
    elseif ($hadWindow -and $stillOpen -eq 0 -and $tray -eq 0 -and $dialog -eq 0 -and $unconfirmed -eq 0 -and $background.Count -gt 0) {
        # Só os processos abertos pelo programa (direta ou indiretamente, pelo processo que tinha a janela).
        $parents = Get-WinForgeProcessParents -Name $name
        $family = @{}
        foreach ($entry in $windowed) { $family[[int]$entry.Id] = $true }

        do {
            $grew = $false

            foreach ($entry in $background) {
                $id = [int]$entry.Id
                if ($family.ContainsKey($id)) { continue }
                if ($family.ContainsKey([int]$parents[$id])) { $family[$id] = $true; $grew = $true }
            }
        } while ($grew)

        $targets = @($background | Where-Object { $family.ContainsKey([int]$_.Id) })
    }

    foreach ($entry in $targets) {
        $running = Get-WinForgeSampledProcess -Name $name -Entry $entry
        if ($null -eq $running) { continue }

        try {
            Stop-Process -Id $running.Id -Force -ErrorAction Stop
        }
        catch {
            $failed++
        }
    }

    # Os auxiliares que não eram do programa (ou cujo pai não deu para saber) costumam sair sozinhos logo depois dele.
    $others = @($background | Where-Object { $targets -notcontains $_ })

    if ($hadWindow -and $others.Count -gt 0 -and $stillOpen -eq 0 -and $tray -eq 0 -and $dialog -eq 0 -and $unconfirmed -eq 0) {
        Start-Sleep -Milliseconds 500
        $left = @($others | Where-Object { $null -ne (Get-WinForgeSampledProcess -Name $name -Entry $_) }).Count
    }

    if ($dialog -gt 0) { return (New-WinForgeResult -Kind Warning -Detail "está com uma caixa de diálogo aberta; responda a ela e feche o programa por ela") }
    if ($stillOpen -gt 0) { return (New-WinForgeResult -Kind Warning -Detail "a janela não fechou (pode estar perguntando se quer salvar, ou ter outra janela aberta); feche por ela") }
    if ($tray -gt 0) { return (New-WinForgeResult -Kind Warning -Detail "fechou a janela, mas continua aberto perto do relógio; para sair, use o ícone dele (botão direito, Sair)") }
    if ($unconfirmed -gt 0 -and $windowed.Count -eq 0 -and $targets.Count -eq 0) { return (New-WinForgeResult -Kind Failed -Detail "o Windows não deixou conferir que é o mesmo programa medido (talvez aberto como Administrador); feche-o pela janela dele") }
    if ($unconfirmed -gt 0) { return (New-WinForgeResult -Kind Warning -Detail "parte dos processos continuou aberta (o Windows não deixou conferir todos)") }
    if (-not $hadWindow -and -not $AllowForce -and $background.Count -gt 0) { return (New-WinForgeResult -Kind Warning -Detail "não tem janela aberta para fechar como no X; ficou aberto") }
    if ($failed -gt 0 -and $failed -lt $targets.Count) { return (New-WinForgeResult -Kind Warning -Detail "parte dos processos continuou aberta") }
    if ($failed -gt 0) { return (New-WinForgeResult -Kind Failed -Detail "o Windows não deixou fechar (talvez precise de Administrador)") }
    if ($left -gt 0) { return (New-WinForgeResult -Kind Warning -Detail "$(Format-WinForgeCount -Count $left -One 'processo com o mesmo nome continua aberto' -Many 'processos com o mesmo nome continuam abertos') (pode ser de outro programa)") }

    return (New-WinForgeResult -Kind Ok -Detail "fechado")
}


function Show-WinForgeHeavyProcesses {
    $title = "Programas pesando agora"

    Enter-WinForgeAction -Title $title

    $final = New-WinForgeResult -Kind Ok -Title $title

    try {
        Write-Progress -Activity $title -Status "medindo o uso do processador e da memória"

        try {
            $heavy = @(Get-WinForgeHeavyProcesses)
            $memory = Get-WinForgeMemoryUsage
        }
        finally {
            Write-Progress -Activity $title -Completed
        }

        if ($heavy.Count -eq 0) {
            # Sem nenhum processo lido, "o que pesa é do Windows" seria um palpite.
            Write-WinForgeStatus -Type Error -Message "Não foi possível ler os programas abertos agora."
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Failed -Detail "não foi possível ler os programas abertos" -Title $title)
            return
        }

        if ($null -ne $memory) {
            Write-WinForgeKeyValue -Label "Memória em uso" -Value "$(Format-WinForgeBytes -Bytes $memory.Used) de $(Format-WinForgeBytes -Bytes $memory.Total) ($($memory.Percent)%)" -Level $(if (Test-WinForgeMemoryHigh -Memory $memory) { "Warn" } else { "Normal" })
            Write-Host ""
        }

        Write-WinForgeSection -Title "O que mais pesa"

        foreach ($process in $heavy) {
            $label = $process.Description
            if ($process.Count -gt 1) { $label += " ($($process.Count))" }

            # Os protegidos aparecem (é bom saber o que pesa), com o motivo: não entram na lista para fechar.
            $value = Format-WinForgeProcessUsage -Process $process
            if ($process.Protected) { $value += " · $(Get-WinForgeProtectedProcessReason -Name ([string]$process.Name))" }

            Write-WinForgeKeyValue -Label $label -Value $value -LabelWidth 34
        }

        Write-Host ""

        # Um aviso sobre o PC, não sobre a tela: não conta no desfecho.
        if ($null -ne $memory -and (Test-WinForgeMemoryHigh -Memory $memory)) {
            Write-WinForgeStatus -Type Warning -Notice -Message "A memória em uso está alta ($($memory.Percent)%): fechar programas que você não está usando ajuda."
        }

        $closable = @($heavy | Where-Object { -not $_.Protected })

        # Só olhar não tem veredito: sem desfecho registrado, a janela termina sem a faixa "Tudo certo", e a lista é o
        # conteúdo da tela.
        if ($closable.Count -eq 0) {
            # O que mais pesa é do Windows, de uma instalação em andamento ou do próprio WinForge.
            Write-WinForgeStatus -Type Info -Message "Nada do que mais pesa agora pode ser fechado por aqui."
            Exit-WinForgeAction
            return
        }

        # Os programas do Windows não entram na lista.
        Write-WinForgeStatus -Type Info -Message "Fechar por aqui é como clicar no X: o que não foi salvo pode ser perdido."
        Write-Host ""

        $answer = Read-WinForgeChoice -Message "Quer fechar algum programa?" -DefaultKey "X" -ShowMenu -TextPrompt "Opção (F ou X; ENTER = concluir)" -Options @(
            @{ Key = "F"; Label = "Fechar programas"; Description = "escolha na lista o que fechar" },
            @{ Key = "X"; Label = "Concluir"; Exit = $true; Accent = $true }
        )

        if ($answer -ine "F") {
            Exit-WinForgeAction
            return
        }

        $options = @(
            foreach ($process in $closable) {
                $parts = @(Format-WinForgeProcessUsage -Process $process)
                if ($process.Company) { $parts += $process.Company }
                if ($process.Count -gt 1) { $parts += "$($process.Count) processos" }
                @{ Key = $process.Name; Label = $process.Description; Description = ($parts -join " · "); Selected = $false }
            }
        )

        $picked = Read-WinForgeMultiSelect -Message "Marque os programas que devem ser fechados" -Options $options

        if ($null -eq $picked -or @($picked).Count -eq 0) {
            Write-WinForgeStatus -Type Warning -Message "Operação cancelada."
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Skipped -Detail "cancelado pelo usuário" -Title $title)
            return
        }

        $chosen = @($closable | Where-Object { @($picked) -contains $_.Name })
        $question = Get-WinForgeSelectionQuestion -Verb "Fechar" -Names @($chosen | ForEach-Object { [string]$_.Description }) -Many "programas"

        if (-not (Confirm-WinForgeAction -Message $question -DefaultKey "N")) {
            Write-WinForgeStatus -Type Warning -Message "Operação cancelada."
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Skipped -Detail "cancelado pelo usuário" -Title $title)
            return
        }

        # Um programa sem janela aberta (perto do relógio, uma máquina virtual, um processo em segundo plano) não tem como
        # fechar como no X: só encerrando à força, e isso pede uma pergunta à parte, com Não como padrão.
        $windowless = @($chosen | Where-Object { Test-WinForgeProcessGroupWindowless -Process $_ })
        $force = $false

        if ($windowless.Count -gt 0) {
            Write-WinForgeStatus -Type Warning -Notice -Message "$(Join-WinForgeList -Items @($windowless | ForEach-Object { [string]$_.Description })) $(if ($windowless.Count -eq 1) { 'não tem janela aberta' } else { 'não têm janela aberta' }): fechar é encerrar à força, e o que não foi salvo (uma gravação, uma máquina virtual) pode ser perdido."
            $force = Confirm-WinForgeAction -Message (Get-WinForgeSelectionQuestion -Verb "Encerrar à força" -Names @($windowless | ForEach-Object { [string]$_.Description }) -Many "programas") -DefaultKey "N"
        }

        $results = @()

        foreach ($process in $chosen) {
            if (-not $force -and $windowless -contains $process) {
                $result = New-WinForgeResult -Kind Warning -Detail "ficou aberto (sem janela para fechar como no X)"
                $result.Etapa = $process.Description
                $results += $result
                Write-WinForgeStatus -Type Warning -Message "$($process.Description): $($result.Detail)."
                continue
            }

            $result = Stop-WinForgeProcessGroup -Process $process -AllowForce:($windowless -contains $process)
            $result.Etapa = $process.Description
            $results += $result

            if ($result.Kind -eq "Ok") { Write-WinForgeStatus -Type Success -Message "$($process.Description): fechado." }
            elseif ($result.Kind -eq "Warning") { Write-WinForgeStatus -Type Warning -Message "$($process.Description): $($result.Detail)." }
            else { Write-WinForgeStatus -Type Error -Message "$($process.Description): $($result.Detail)." }
        }

        $failed = @($results | Where-Object { $_.Kind -ne "Ok" })
        $names = Join-WinForgeList -Items @($failed | ForEach-Object { [string]$_.Etapa })
        $now = $null

        # O efeito, medido: a memória em uso antes (da medição) e agora.
        if ($failed.Count -lt $results.Count -and $null -ne $memory) {
            $now = Get-WinForgeMemoryUsage

            if ($null -ne $now) {
                Write-Host ""
                Write-WinForgeKeyValue -Label "Memória em uso agora" -Value "$(Format-WinForgeBytes -Bytes $now.Used) de $(Format-WinForgeBytes -Bytes $now.Total) ($($now.Percent)%); antes, $($memory.Percent)%"
            }
        }

        if ($failed.Count -eq 0) {
            # Na janela, o título diz quantos, e a frase, o efeito na memória (os nomes ficam no resumo); sem a leitura da
            # memória, a frase diz quais.
            $closedText = Format-WinForgeCount -Count $results.Count -One "programa fechado" -Many "programas fechados"
            $final = New-WinForgeResult -Kind Ok -Detail $closedText -Title $title
            $note = $(
                if ($null -ne $now) { "Memória em uso agora: $($now.Percent)% (antes, $($memory.Percent)%)." }
                else { "$(if ($results.Count -eq 1) { 'Fechado' } else { 'Fechados' }): $(Join-WinForgeList -Items @($results | ForEach-Object { [string]$_.Etapa }))." }
            )
            [void](Set-WinForgeResultView -Result $final -Headline $closedText -Note $note)
        }
        elseif (@($failed | Where-Object { $_.Kind -eq "Failed" }).Count -eq $results.Count) {
            $final = New-WinForgeResult -Kind Failed -Detail "não foi possível fechar: $names" -Title $title
        }
        elseif ($failed.Count -eq $results.Count) {
            # Uma janela que ficou aberta perguntando se quer salvar não é erro: a pessoa responde e fecha por ela.
            $final = New-WinForgeResult -Kind Warning -Detail "$(if ($failed.Count -eq 1) { 'ficou aberto' } else { 'ficaram abertos' }): $names" -Title $title
        }
        else {
            $final = New-WinForgeResult -Kind Warning -Detail "$($failed.Count) de $($results.Count) não fecharam: $names" -Title $title
        }
    }
    catch {
        Write-WinForgeStatus -Type Error -Message "Não foi possível medir os programas: $($_.Exception.Message.TrimEnd('.'))."
        $final = New-WinForgeResult -Kind Failed -Detail $_.Exception.Message.TrimEnd('.') -Title $title
    }

    Exit-WinForgeAction -Result $final
}


Export-ModuleMember -Function *
