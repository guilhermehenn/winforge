# Recursos opcionais do Windows (os que ficam em "Ativar ou desativar recursos do Windows"): ligar e desligar os mais
# comuns, com uma explicação em português do que cada um faz. Usa Get-/Enable-/Disable-WindowsOptionalFeature.
#
# Os recursos mudam o sistema por baixo, então sempre é a pessoa quem marca o que alterar, e o PC pode pedir reinício.


# ---------------------------------------------------------------------------
# Catálogo
# ---------------------------------------------------------------------------

function Get-WinForgeFeatureCatalog {
    <#
    Os recursos que o WinForge conhece. Name é o nome interno do Windows. RiskOnEnable e RiskOnDisable: texto de alerta
    quando ligar ou desligar o recurso traz risco (a confirmação passa a ter Não como padrão). Hypervisor: ligar o recurso
    liga o hipervisor do Windows, o que a tela avisa (uma vez, para todos os marcados) sem mudar o padrão da confirmação:
    para quem pediu o recurso, ligar é o esperado. Recursos que a edição do Windows não tem não aparecem na tela.
    #>
    return @(
        [PSCustomObject]@{ Name = "Microsoft-Windows-Subsystem-Linux"; Label = "Subsistema do Windows para Linux (WSL)"; Description = "Roda programas de Linux dentro do Windows; usado por desenvolvedores"; RiskOnEnable = ""; RiskOnDisable = "Sem o WSL, os Linux instalados nele deixam de abrir; os arquivos deles continuam no disco."; Hypervisor = $false },
        [PSCustomObject]@{ Name = "VirtualMachinePlatform"; Label = "Plataforma de Máquina Virtual"; Description = "Necessária para o WSL 2 e para aplicativos que usam máquinas virtuais leves"; RiskOnEnable = ""; RiskOnDisable = "Sem a Plataforma de Máquina Virtual, o WSL 2 e os programas que usam máquinas virtuais leves (como o Docker Desktop) param de funcionar."; Hypervisor = $true },
        [PSCustomObject]@{ Name = "HypervisorPlatform"; Label = "Plataforma do Hipervisor do Windows"; Description = "Permite que emuladores e programas de terceiros usem a virtualização do Windows"; RiskOnEnable = ""; RiskOnDisable = ""; Hypervisor = $true },
        [PSCustomObject]@{ Name = "Microsoft-Hyper-V-All"; Label = "Hyper-V"; Description = "Cria e roda máquinas virtuais completas (só nas edições Pro, Enterprise e Education)"; RiskOnEnable = ""; RiskOnDisable = "Desligar o Hyper-V faz as máquinas virtuais criadas nele pararem de funcionar; os arquivos delas continuam no disco."; Hypervisor = $true },
        [PSCustomObject]@{ Name = "Containers-DisposableClientVM"; Label = "Windows Sandbox"; Description = "Uma janela descartável do Windows para testar programas sem risco (só nas edições Pro e Enterprise)"; RiskOnEnable = ""; RiskOnDisable = ""; Hypervisor = $true },
        [PSCustomObject]@{ Name = "NetFx3"; Label = ".NET Framework 3.5"; Description = "Necessário para programas antigos; o Windows baixa o componente ao ligar"; RiskOnEnable = ""; RiskOnDisable = "Programas antigos que usam o .NET 3.5 deixam de abrir."; Hypervisor = $false },
        [PSCustomObject]@{ Name = "TelnetClient"; Label = "Cliente Telnet"; Description = "Comando telnet para testar conexões de rede; pouco usado hoje"; RiskOnEnable = ""; RiskOnDisable = ""; Hypervisor = $false },
        [PSCustomObject]@{ Name = "MicrosoftWindowsPowerShellV2Root"; Label = "Windows PowerShell 2.0"; Description = "Versão antiga e sem proteções do PowerShell; desligar é mais seguro"; RiskOnEnable = "O PowerShell 2.0 é antigo e não tem as proteções modernas; ligue só se um programa antigo exigir."; RiskOnDisable = ""; Hypervisor = $false },
        [PSCustomObject]@{ Name = "SMB1Protocol"; Label = "Compartilhamento SMB 1.0"; Description = "Protocolo antigo de arquivos em rede, inseguro; só equipamentos muito velhos (scanners, NAS) ainda o exigem"; RiskOnEnable = "O SMB 1.0 é inseguro e foi usado por ataques como o WannaCry; ligue só se um equipamento antigo realmente exigir."; RiskOnDisable = ""; Hypervisor = $false }
    )
}


function Get-WinForgeFeatureStates {
    # Nome -> estado (Enabled, Disabled...) de todos os recursos que o Windows lista. $null quando não foi possível ler.
    try {
        $features = @(Get-WindowsOptionalFeature -Online -ErrorAction Stop)
    }
    catch {
        return $null
    }

    $states = @{}

    foreach ($feature in $features) {
        $name = [string](Get-WinForgeJsonValue -Object $feature -Name "FeatureName" -Default "")

        if ($name) {
            $states[$name] = [string](Get-WinForgeJsonValue -Object $feature -Name "State" -Default "")
        }
    }

    return $states
}


function Get-WinForgeFeatureChoices {
    <#
    Os recursos do catálogo que existem neste Windows, com o estado atual e a ação que a escolha faria (Enable ou
    Disable). Os que estão com a mudança pendente de reinício não entram: o Windows ainda não os aplicou.
    #>
    param (
        [Parameter(Mandatory)]
        [hashtable]$States
    )

    return @(
        foreach ($feature in @(Get-WinForgeFeatureCatalog)) {
            if (-not $States.ContainsKey($feature.Name)) { continue }

            $state = [string]$States[$feature.Name]

            if ($state -match 'Pending') { continue }

            $enabled = ($state -eq "Enabled")

            [PSCustomObject]@{
                Name         = $feature.Name
                Label        = $feature.Label
                Description  = $feature.Description
                RiskOnEnable = $feature.RiskOnEnable
                RiskOnDisable = $feature.RiskOnDisable
                Hypervisor   = [bool](Get-WinForgeJsonValue -Object $feature -Name "Hypervisor" -Default $false)
                Enabled      = $enabled
                Action       = $(if ($enabled) { "Disable" } else { "Enable" })
            }
        }
    )
}


function Set-WinForgeOptionalFeature {
    # Liga ou desliga um recurso sem reiniciar. Devolve RestartNeeded.
    param (
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [ValidateSet("Enable", "Disable")]
        [string]$Action
    )

    if ($Action -eq "Enable") {
        $result = Enable-WindowsOptionalFeature -Online -FeatureName $Name -NoRestart -All -ErrorAction Stop
    }
    else {
        $result = Disable-WindowsOptionalFeature -Online -FeatureName $Name -NoRestart -ErrorAction Stop
    }

    return [PSCustomObject]@{ RestartNeeded = [bool](Get-WinForgeJsonValue -Object $result -Name "RestartNeeded" -Default $false) }
}


function Get-WinForgeFeaturePendingLabels {
    # Os recursos do catálogo com uma mudança que só termina ao reiniciar (estado "...Pending"): ficam fora da escolha, e a
    # tela diz que estão esperando o reinício.
    param (
        [Parameter(Mandatory)]
        [hashtable]$States
    )

    return @(
        foreach ($feature in @(Get-WinForgeFeatureCatalog)) {
            if ($States.ContainsKey($feature.Name) -and [string]$States[$feature.Name] -match 'Pending') { $feature.Label }
        }
    )
}


function Get-WinForgeFeatureErrorText {
    <#
    O motivo de um recurso não ter mudado, a partir do erro do cmdlet. Os códigos mais comuns viram frase, com o código
    junto; os demais ficam com a primeira linha da mensagem do Windows e o código, quando houver.
    #>
    param (
        [string]$Message,
        [int]$HResult = 0
    )

    $code = Get-WinForgeErrorCode -Message $Message -HResult $HResult

    $phrase = switch ($code) {
        "0x800F081F" { "o Windows não encontrou os arquivos do recurso; confira a internet e o Windows Update" }
        "0x800F0906" { "o Windows não conseguiu baixar os arquivos do recurso; confira a internet" }
        "0x800F0907" { "uma política de rede impediu o download dos arquivos do recurso; fale com o suporte de TI" }
        "0x800F0954" { "o Windows não conseguiu os arquivos do recurso; costuma acontecer quando o PC busca atualizações num servidor de empresa (WSUS), o que, num PC de casa, um bloqueador de atualizações pode ter configurado" }
        "0x800F080C" { "o recurso não existe nesta edição do Windows" }
        "0x80070005" { "acesso negado" }
        default { "" }
    }

    if ($phrase) {
        return "$phrase — erro $code"
    }

    $text = @(([string]$Message) -split "[\r\n]+" | Where-Object { $_.Trim() }) | Select-Object -First 1
    $text = $(if ($text) { ([string]$text).Trim().TrimEnd('.') } else { "o Windows não aplicou a mudança" })

    if ($code -and $text.IndexOf($code, [System.StringComparison]::OrdinalIgnoreCase) -lt 0) {
        return "$text — erro $code"
    }

    return $text
}


# ---------------------------------------------------------------------------
# Ação
# ---------------------------------------------------------------------------

function Set-WinForgeWindowsFeatures {
    $title = "Recursos opcionais do Windows"

    Enter-WinForgeAction -Title $title

    $final = New-WinForgeResult -Kind Ok -Title $title

    try {
        if (-not (Test-WinForgeElevation -Reason "Ligar ou desligar recursos do Windows exige privilégios de Administrador.")) {
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Failed -Detail "requer Administrador" -Title $title)
            return
        }

        Write-Progress -Activity "Recursos opcionais do Windows" -Status "lendo os recursos (pode levar alguns segundos)"

        try {
            $states = Get-WinForgeFeatureStates
        }
        finally {
            Write-Progress -Activity "Recursos opcionais do Windows" -Completed
        }

        if ($null -eq $states) {
            Write-WinForgeStatus -Type Error -Message "Não foi possível ler os recursos do Windows neste PC."
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Failed -Detail "não foi possível ler os recursos do Windows" -Title $title)
            return
        }

        $choices = @(Get-WinForgeFeatureChoices -States $states)
        $pending = @(Get-WinForgeFeaturePendingLabels -States $states)

        if ($choices.Count -eq 0 -and $pending.Count -eq 0) {
            Write-WinForgeStatus -Type Info -Message "Nenhum dos recursos conhecidos está disponível nesta edição do Windows."
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Skipped -Detail "nenhum recurso disponível nesta edição do Windows" -Title $title)
            return
        }

        Write-WinForgeSection -Title "Situação atual"

        foreach ($choice in $choices) {
            Write-WinForgeKeyValue -Label $choice.Label -Value $(if ($choice.Enabled) { "Ligado" } else { "Desligado" }) -LabelWidth 38
        }

        foreach ($label in $pending) {
            Write-WinForgeKeyValue -Label $label -Value "Mudança pendente" -LabelWidth 38
        }

        Write-Host ""

        if ($pending.Count -eq 1) {
            Write-WinForgeStatus -Type Info -Message "Reinicie o PC para concluir a mudança pendente; até lá, esse recurso fica fora da lista."
        }
        elseif ($pending.Count -gt 1) {
            Write-WinForgeStatus -Type Info -Message "Reinicie o PC para concluir as mudanças pendentes; até lá, esses recursos ficam fora da lista."
        }

        if ($choices.Count -eq 0) {
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Skipped -Detail "os recursos esperam o reinício do PC" -Title $title)
            return
        }

        $options = @(
            foreach ($choice in $choices) {
                $verb = if ($choice.Enabled) { "Desligar" } else { "Ligar" }

                @{ Key = $choice.Name; Label = "${verb}: $($choice.Label)"; Description = $choice.Description }
            }
        )

        $picked = Read-WinForgeMultiSelect -Message "Marque o que deseja mudar" -Options $options -NoSelectAll

        if ($null -eq $picked -or @($picked).Count -eq 0) {
            Write-WinForgeStatus -Type Warning -Message "Operação cancelada."
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Skipped -Detail "cancelado pelo usuário" -Title $title)
            return
        }

        $changes = @($choices | Where-Object { @($picked) -contains $_.Name })

        # O WSL 2, o padrão hoje, roda sobre a Plataforma de Máquina Virtual: ligar o WSL sem ela daria só o WSL 1.
        $platform = @($choices | Where-Object { $_.Name -eq "VirtualMachinePlatform" -and -not $_.Enabled }) | Select-Object -First 1
        $addedPlatform = $false

        if (@($changes | Where-Object { $_.Name -eq "Microsoft-Windows-Subsystem-Linux" -and $_.Action -eq "Enable" }).Count -gt 0 -and $null -ne $platform -and @($changes | Where-Object { $_.Name -eq "VirtualMachinePlatform" }).Count -eq 0) {
            $changes += $platform
            $addedPlatform = $true
        }

        $risky = @($changes | Where-Object { ($_.Action -eq "Enable" -and $_.RiskOnEnable) -or ($_.Action -eq "Disable" -and $_.RiskOnDisable) })

        # O que vai mudar fica no resumo, junto com o alerta de cada recurso arriscado: a pergunta só confirma.
        Write-WinForgeSection -Title "O que vai mudar"

        foreach ($change in $changes) {
            Write-WinForgeKeyValue -Label $change.Label -Value $(if ($change.Action -eq "Enable") { "Ligar" } else { "Desligar" }) -LabelWidth 38
        }

        Write-Host ""

        if ($addedPlatform) {
            Write-WinForgeStatus -Type Warning -Message "A Plataforma de Máquina Virtual entra junto (o WSL 2 precisa dela): ela liga o hipervisor do Windows a cada início, o que pode atrapalhar VirtualBox e VMware antigos, emuladores de Android e o antitrapaça de jogos."
        }

        # O mesmo aviso para o que a pessoa marcou e liga o hipervisor (sem repetir o da Plataforma que entrou junto).
        $hypervisor = @($changes | Where-Object { $_.Action -eq "Enable" -and (Get-WinForgeJsonValue -Object $_ -Name "Hypervisor" -Default $false) -and -not ($addedPlatform -and $_.Name -eq "VirtualMachinePlatform") } | ForEach-Object { [string]$_.Label })

        if ($hypervisor.Count -gt 0) {
            Write-WinForgeStatus -Type Warning -Notice -Message "$(Join-WinForgeList -Items $hypervisor) $(if ($hypervisor.Count -eq 1) { 'liga' } else { 'ligam' }) o hipervisor do Windows a cada início, o que pode atrapalhar VirtualBox e VMware antigos, emuladores de Android e o antitrapaça de jogos."
        }

        foreach ($change in $risky) {
            Write-WinForgeStatus -Type Warning -Message $(if ($change.Action -eq "Enable") { $change.RiskOnEnable } else { $change.RiskOnDisable })
        }

        $question = $(if ($changes.Count -eq 1) { "$(if ($changes[0].Action -eq 'Enable') { 'Ligar' } else { 'Desligar' }) $($changes[0].Label)?" } else { "Aplicar as $($changes.Count) mudanças?" })

        if (-not (Confirm-WinForgeAction -Message $question -DefaultKey $(if ($risky.Count -gt 0) { "N" } else { "S" }))) {
            Write-WinForgeStatus -Type Warning -Message "Operação cancelada."
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Skipped -Detail "cancelado pelo usuário" -Title $title)
            return
        }

        $results = @()
        $restart = $false
        $position = 0

        try {
            foreach ($change in $changes) {
                $position++
                $doing = $(if ($change.Action -eq "Enable") { "ligando" } else { "desligando" })
                $done = $(if ($change.Action -eq "Enable") { "ligado" } else { "desligado" })

                Write-Progress -Activity "Alterando recursos do Windows" -Status "$position de $($changes.Count): $doing $($change.Label)" -PercentComplete ([int](($position - 1) * 100 / $changes.Count))

                try {
                    $applied = Set-WinForgeOptionalFeature -Name $change.Name -Action $change.Action
                    $restart = $restart -or $applied.RestartNeeded
                    $result = New-WinForgeResult -Kind Ok -Detail $done -Data @{ RebootRequired = [bool]$applied.RestartNeeded }
                    Write-WinForgeStatus -Type Success -Message "$($change.Label): $done$(if ($applied.RestartNeeded) { '; termina ao reiniciar o PC' })."
                    $opposite = $(if ($change.Action -eq "Enable") { "Disable" } else { "Enable" })
                    [void](Add-WinForgeChange -Action "Recurso do Windows" -Text "$($change.Label) $done" -Undo @{ Kind = "feature"; Name = [string]$change.Name; Action = $opposite })
                }
                catch {
                    $reason = Get-WinForgeFeatureErrorText -Message $_.Exception.Message -HResult $_.Exception.HResult
                    Write-WinForgeStatus -Type Error -Message "$($change.Label): $reason."
                    $result = New-WinForgeResult -Kind Failed -Detail $reason
                }

                $result.Etapa = $change.Label
                $results += $result
            }
        }
        finally {
            Write-Progress -Activity "Alterando recursos do Windows" -Completed
        }

        # No console, a tabela junta tudo no fim; na janela, cada recurso já tem a sua linha no resumo.
        if ($results.Count -gt 1 -and -not (Test-WinForgeGuiMode)) {
            Write-WinForgeSection -Title "Resumo"
            Write-WinForgeResultTable -Results $results
        }

        $failed = @($results | Where-Object { $_.Kind -eq "Failed" })
        $names = Join-WinForgeList -Items @($failed | ForEach-Object { [string]$_.Etapa })

        # Ligar o WSL não instala nenhum Linux: falta escolher uma distribuição.
        $wsl = @($changes | Where-Object { $_.Name -eq "Microsoft-Windows-Subsystem-Linux" -and $_.Action -eq "Enable" }) | Select-Object -First 1
        if ($null -ne $wsl -and @($results | Where-Object { $_.Etapa -eq $wsl.Label -and $_.Kind -ne "Failed" }).Count -gt 0) {
            Write-WinForgeStatus -Type Info -Message "Depois de reiniciar, instale um Linux pela Microsoft Store ou com wsl --install (a virtualização precisa estar ligada na BIOS)."
        }

        # A faixa acrescenta "Reinicie o PC para concluir." quando RebootRequired está ligado.
        if ($failed.Count -eq 0) {
            $detail = $(if ($results.Count -eq 1) { "$($results[0].Etapa) $($results[0].Detail)" } else { "$($results.Count) recursos alterados" })
            $final = New-WinForgeResult -Kind Ok -Detail $detail -Title $title -Data @{ RebootRequired = $restart }

            # Na janela, o título diz quantos e o que mudou; a frase, quais. O pedido de reinício a faixa acrescenta.
            $on = @($results | Where-Object { $_.Detail -eq "ligado" } | ForEach-Object { [string]$_.Etapa })
            $off = @($results | Where-Object { $_.Detail -eq "desligado" } | ForEach-Object { [string]$_.Etapa })

            if ($off.Count -eq 0) {
                [void](Set-WinForgeResultView -Result $final -Headline (Format-WinForgeCount -Count $on.Count -One "recurso ligado" -Many "recursos ligados") -Note "$(Join-WinForgeShortList -Items $on).")
            }
            elseif ($on.Count -eq 0) {
                [void](Set-WinForgeResultView -Result $final -Headline (Format-WinForgeCount -Count $off.Count -One "recurso desligado" -Many "recursos desligados") -Note "$(Join-WinForgeShortList -Items $off).")
            }
            else {
                [void](Set-WinForgeResultView -Result $final -Headline (Format-WinForgeCount -Count $results.Count -One "recurso alterado" -Many "recursos alterados") `
                        -Note "$(if ($on.Count -eq 1) { 'Ligado' } else { 'Ligados' }): $(Join-WinForgeShortList -Items $on). $(if ($off.Count -eq 1) { 'Desligado' } else { 'Desligados' }): $(Join-WinForgeShortList -Items $off).")
            }
        }
        elseif ($failed.Count -eq $results.Count) {
            $detail = $(if ($results.Count -eq 1) { "$names não mudou: $($failed[0].Detail)" } else { "nenhum recurso mudou: $names" })
            $final = New-WinForgeResult -Kind Failed -Detail $detail -Title $title
        }
        else {
            $verbText = $(if ($failed.Count -eq 1) { "não mudou" } else { "não mudaram" })
            $final = New-WinForgeResult -Kind Warning -Detail "$($failed.Count) de $($results.Count) ${verbText}: $names" -Title $title -Data @{ RebootRequired = $restart }
            $reason = $(if ($failed.Count -eq 1) { "o motivo está no resumo" } else { "o motivo de cada um está no resumo" })
            [void](Set-WinForgeResultView -Result $final -Headline "$($results.Count - $failed.Count) de $($results.Count) recursos alterados" `
                    -Note "$(Join-WinForgeShortList -Items @($failed | ForEach-Object { [string]$_.Etapa })) ${verbText}; $reason.")
        }
    }
    catch {
        Write-WinForgeStatus -Type Error -Message "Não foi possível alterar os recursos: $($_.Exception.Message)"
        $final = New-WinForgeResult -Kind Failed -Detail $_.Exception.Message -Title $title
    }

    Exit-WinForgeAction -Result $final
}


Export-ModuleMember -Function *
