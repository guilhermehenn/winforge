# Verificar o PC: olha tudo de uma vez e corrige com um clique o que é seguro corrigir.
#
# A verificação só lê (espaço no disco, lixo acumulado, registro, atalhos, memória, inicialização, programas
# desatualizados, suporte e atualizações do Windows, proteção e reinício pendente). Depois, uma lista de marcar traz o que
# dá para corrigir aqui mesmo, com o que é seguro já marcado: temporários e relatórios de erro (o Windows recria), atalhos
# quebrados (para a Lixeira) e assinaturas do antivírus. As referências quebradas do registro ficam na lista, desmarcadas
# (a Microsoft não recomenda limpar o registro; o WinForge guarda backup e desfaz, mas o ganho é pequeno). O resto vira
# um atalho para a tela certa: liberar espaço, fechar o que pesa na memória, decidir o que abre com o Windows ou
# atualizar programas pede o olhar da pessoa.


function New-WinForgeCheckupFinding {
    <#
    Um achado da verificação. Fix = nome da correção (vazio = não se corrige daqui); Selected = vem marcado; Target = item
    da navegação para ver de perto; Level = Ok | Warn | Info; Data = o que a correção precisa; Unread = a leitura não
    respondeu (a etapa conta como não lida no veredito).
    #>
    param (
        [Parameter(Mandatory)][string]$Id,
        [Parameter(Mandatory)][string]$Label,
        [Parameter(Mandatory)][string]$Value,
        [ValidateSet("Ok", "Warn", "Info")][string]$Level = "Info",
        [string]$Fix = "",
        [string]$FixLabel = "",
        [bool]$Selected = $false,
        [string]$Target = "",
        [string]$Advice = "",
        $Data = $null,
        [bool]$Unread = $false
    )

    return [PSCustomObject]@{
        Id       = $Id
        Label    = $Label
        Value    = $Value
        Level    = $Level
        Fix      = $Fix
        FixLabel = $FixLabel
        Selected = $Selected
        Target   = $Target
        Advice   = $Advice
        Data     = $Data
        Unread   = $Unread
    }
}


function Get-WinForgeCheckupSteps {
    # As etapas da verificação, na ordem, com o texto da barra de progresso.
    return @(
        @{ Id = "disk"; Label = "Espaço no disco"; Text = "medindo o espaço livre do disco do Windows" },
        @{ Id = "junk"; Label = "Temporários e caches"; Text = "medindo temporários e caches" },
        @{ Id = "registry"; Label = "Registro"; Text = "procurando referências quebradas no registro" },
        @{ Id = "shortcuts"; Label = "Atalhos"; Text = "conferindo os atalhos" },
        @{ Id = "memory"; Label = "Memória"; Text = "lendo o uso de memória" },
        @{ Id = "startup"; Label = "Abrem com o Windows"; Text = "contando o que abre com o Windows" },
        @{ Id = "programs"; Label = "Programas desatualizados"; Text = "procurando programas desatualizados (winget)" },
        @{ Id = "windows"; Label = "Suporte do Windows"; Text = "conferindo o suporte e as atualizações do Windows" },
        @{ Id = "protection"; Label = "Proteção"; Text = "conferindo a proteção" },
        @{ Id = "reboot"; Label = "Reinício pendente"; Text = "conferindo se falta reiniciar" }
    )
}


function Get-WinForgeCheckupDisk {
    # O espaço livre no disco do Windows, com a regra do Início (Get-WinForgeDiskSpaceLevel): menos de 20 GB pede
    # atenção, menos de 10 GB é quase cheio. Não se corrige daqui: a Limpeza personalizada mostra o tamanho de cada
    # coisa que dá para apagar (os temporários desta verificação, logo abaixo, já ajudam).
    $space = Get-WinForgeSystemDriveSpace
    $level = $(if ($null -eq $space) { "Unknown" } else { Get-WinForgeDiskSpaceLevel -FreeBytes $space.FreeBytes -TotalBytes $space.TotalBytes })

    if ($level -eq "Unknown") {
        return (New-WinForgeCheckupFinding -Id "disk" -Label "Espaço no disco" -Value "não foi possível ler" -Level Info -Unread $true)
    }

    $value = "$(Format-WinForgeBytes -Bytes $space.FreeBytes) livres de $(Format-WinForgeBytes -Bytes $space.TotalBytes)"

    if ($level -in @("Critical", "Low")) {
        return (New-WinForgeCheckupFinding -Id "disk" -Label "Espaço no disco" -Value "$value ($(if ($level -eq 'Critical') { 'quase cheio' } else { 'pouco espaço' }))" -Level Warn `
                -Target "cleanup.custom" -Advice "libere espaço em Limpeza > Limpeza personalizada")
    }

    return (New-WinForgeCheckupFinding -Id "disk" -Label "Espaço no disco" -Value $value -Level Ok)
}


function Get-WinForgeCheckupJunk {
    $isAdmin = Test-WinForgeAdministrator
    $targets = @(Get-WinForgeCleanupTargets | Where-Object { $_.Selected -and ($isAdmin -or -not $_.Admin) })
    $measured = @(foreach ($target in $targets) { Measure-WinForgeCleanupTarget -Target $target })
    $size = [int64]0
    foreach ($target in $measured) { if ($null -ne $target.Size) { $size += [int64]$target.Size } }

    # Com Administrador, o que vem marcado na Limpeza personalizada inclui o cache da Otimização de Entrega (pedaços de
    # atualizações já instaladas): o nome diz isso.
    $updates = (@($measured | Where-Object { [string]$_.Id -eq "delivery-optimization" }).Count -gt 0)
    $label = $(if ($updates) { "Temporários, relatórios de erro e cache de atualizações" } else { "Temporários e relatórios de erro" })
    $fixLabel = $(if ($updates) { "Apagar temporários, relatórios de erro e cache de atualizações" } else { "Apagar temporários e relatórios de erro" })

    $findings = @()

    if ($size -ge 50MB) {
        $findings += New-WinForgeCheckupFinding -Id "junk" -Label $label -Value (Format-WinForgeBytes -Bytes $size) -Level Warn `
            -Fix "junk" -FixLabel $fixLabel -Selected $true -Target "cleanup.custom" -Data @($measured)
    }
    else {
        $findings += New-WinForgeCheckupFinding -Id "junk" -Label $label -Value $(if ($size -gt 0) { "pouco ($(Format-WinForgeBytes -Bytes $size))" } else { "nada acumulado" }) -Level Ok
    }

    $browser = @(Get-WinForgeCleanupTargets | Where-Object { $_.Id -eq "browser-cache" }) | Select-Object -First 1

    if ($null -ne $browser) {
        $browser = Measure-WinForgeCleanupTarget -Target $browser

        if ($null -ne $browser.Size -and [int64]$browser.Size -ge 200MB) {
            $findings += New-WinForgeCheckupFinding -Id "browser" -Label "Cache dos navegadores" -Value (Format-WinForgeBytes -Bytes $browser.Size) -Level Info `
                -Fix "browser" -FixLabel "Limpar o cache dos navegadores" -Target "cleanup.custom" -Data @($browser) `
                -Advice "senhas, cookies e histórico ficam; as páginas carregam mais devagar na primeira vez"
        }
    }

    if (-not $isAdmin) {
        $findings += New-WinForgeCheckupFinding -Id "junk-admin" -Label "Temporários do Windows" -Value "só com Administrador" -Level Info -Target "cleanup.quick"
    }

    return @($findings)
}


function Get-WinForgeCheckupRegistry {
    # As bibliotecas compartilhadas (SharedDLLs) ficam fora da correção com um clique: é uma contagem de uso que
    # instaladores consultam, e quem decide removê-la é a pessoa, olhando a lista em Limpeza > Limpar o registro. As
    # outras referências quebradas vêm na lista desmarcadas: a Microsoft não dá suporte a programas de limpeza do registro
    # (KB2563254), e o ganho de remover chaves órfãs é pequeno; o backup e o desfazer continuam valendo para quem marcar.
    $all = @(Find-WinForgeRegistryIssues)
    $issues = @($all | Where-Object { $_.Category -ne "shared-dlls" })
    $shared = $all.Count - $issues.Count
    $advice = $(if ($shared -gt 0) { "$(Format-WinForgeCount -Count $shared -One 'biblioteca compartilhada fica' -Many 'bibliotecas compartilhadas ficam') para você revisar em Limpeza > Limpar o registro" } else { "" })

    if ($issues.Count -eq 0) {
        if ($shared -gt 0) {
            # Sobras comuns e inofensivas: informação, não um ponto que pede decisão a cada verificação.
            return (New-WinForgeCheckupFinding -Id "registry" -Label "Registro" -Value (Format-WinForgeCount -Count $shared -One "biblioteca compartilhada que não existe mais" -Many "bibliotecas compartilhadas que não existem mais") -Level Info `
                    -Target "cleanup.registry" -Advice $advice)
        }

        return (New-WinForgeCheckupFinding -Id "registry" -Label "Registro" -Value "nenhuma referência quebrada" -Level Ok)
    }

    return (New-WinForgeCheckupFinding -Id "registry" -Label "Registro" -Value (Format-WinForgeCount -Count $issues.Count -One "referência quebrada" -Many "referências quebradas") -Level Warn `
            -Fix "registry" -FixLabel "Remover as referências quebradas do registro (com backup)" -Selected $false -Target "cleanup.registry" -Advice $advice -Data $issues)
}


function Get-WinForgeCheckupShortcuts {
    # Os atalhos do OneDrive ficam fora da correção de um clique: o programa pode estar instalado em outro PC da pessoa, e
    # o atalho apagado aqui some de lá também. Eles aparecem, desmarcados, em Limpeza > Remover atalhos quebrados.
    $isAdmin = Test-WinForgeAdministrator
    $broken = @(Find-WinForgeBrokenShortcuts | Where-Object { ($isAdmin -or -not $_.Admin) -and -not [bool](Get-WinForgeJsonValue -Object $_ -Name "Synced" -Default $false) })

    if ($broken.Count -eq 0) {
        return (New-WinForgeCheckupFinding -Id "shortcuts" -Label "Atalhos" -Value "nenhum quebrado" -Level Ok)
    }

    return (New-WinForgeCheckupFinding -Id "shortcuts" -Label "Atalhos" -Value (Format-WinForgeCount -Count $broken.Count -One "atalho quebrado" -Many "atalhos quebrados") -Level Warn `
            -Fix "shortcuts" -FixLabel "Enviar os atalhos quebrados para a Lixeira" -Selected $true -Target "cleanup.shortcuts" -Data $broken)
}


function Get-WinForgeCheckupMemory {
    $memory = Get-WinForgeMemoryUsage

    # Sem leitura, a linha diz isso: sumir com ela pareceria que a memória nem foi olhada (ou que está tudo bem).
    if ($null -eq $memory) {
        return (New-WinForgeCheckupFinding -Id "memory" -Label "Memória" -Value "não foi possível ler" -Level Info -Unread $true)
    }

    $text = "$($memory.Percent)% em uso ($(Format-WinForgeBytes -Bytes $memory.Used) de $(Format-WinForgeBytes -Bytes $memory.Total))"

    # Sem correção daqui: esvaziar a memória dos programas não resolve (eles a recarregam do disco, mais devagar, e a
    # memória volta a encher). O que resolve é fechar o que pesa.
    if (Test-WinForgeMemoryHigh -Memory $memory) {
        return (New-WinForgeCheckupFinding -Id "memory" -Label "Memória" -Value $text -Level Warn -Target "performance.processes" `
                -Advice "feche o que pesa em Desempenho > Programas pesando agora")
    }

    return (New-WinForgeCheckupFinding -Id "memory" -Label "Memória" -Value $text -Level Ok)
}


function Get-WinForgeCheckupStartup {
    $enabled = @(Get-WinForgeStartupItems | Where-Object { $_.Enabled }).Count

    if ($enabled -gt 8) {
        return (New-WinForgeCheckupFinding -Id "startup" -Label "Abrem com o Windows" -Value (Format-WinForgeCount -Count $enabled -One "programa" -Many "programas") -Level Warn `
                -Target "software.startup-manager" -Advice "desligue o que não precisa em Programas > Gerenciar inicialização")
    }

    return (New-WinForgeCheckupFinding -Id "startup" -Label "Abrem com o Windows" -Value (Format-WinForgeCount -Count $enabled -One "programa" -Many "programas") -Level Ok)
}


function Get-WinForgeCheckupPrograms {
    if (-not (Test-WinForgeWinget)) {
        return (New-WinForgeCheckupFinding -Id "programs" -Label "Programas desatualizados" -Value "não dá para conferir neste PC (falta o winget, da Microsoft Store)" -Level Info)
    }

    $upgrade = Invoke-WinForgeCapture -FilePath "winget" -Arguments @("upgrade", "--accept-source-agreements")

    if (Test-WinForgeWingetNoUpgradeOutput -OutputText $upgrade.Text -ExitCode $upgrade.ExitCode) {
        return (New-WinForgeCheckupFinding -Id "programs" -Label "Programas desatualizados" -Value "nenhum" -Level Ok)
    }

    $available = @(ConvertFrom-WinForgeWingetTable -Lines $upgrade.Lines)

    if ($available.Count -eq 0) {
        return (New-WinForgeCheckupFinding -Id "programs" -Label "Programas desatualizados" -Value "não foi possível ler" -Level Info -Target "updates.winget" -Unread $true)
    }

    return (New-WinForgeCheckupFinding -Id "programs" -Label "Programas desatualizados" -Value (Format-WinForgeCount -Count $available.Count -One "programa" -Many "programas") -Level Warn `
            -Target "updates.winget" -Advice "atualize em Atualizações > Atualizar programas (winget)")
}


function Get-WinForgeCheckupWindows {
    # O ESU do Windows 10 é conferido pela revisão da build instalada, sem consultar o histórico de atualizações.
    $support = Get-WinForgeWindowsSupportStatus

    $issue = Get-WinForgeWindowsSupportIssue -Status $support
    $findings = @()

    # Com o suporte em dia, falta saber se as atualizações chegaram (a mesma conta do Início): um Windows parado na
    # atualização de meses atrás (Windows Update pausado, desligado ou com defeito) está sem as correções de segurança,
    # mesmo dentro do prazo. Sem como saber (versão fora do catálogo, Windows Server), a linha não aparece.
    if ([string]$support.State -in @("Supported", "EndingSoon", "Esu")) {
        $lag = $null

        try { $lag = Get-WinForgeWindowsUpdateLag } catch { $lag = $null }

        if ($lag -eq $true) {
            $findings += New-WinForgeCheckupFinding -Id "updates" -Label "Atualizações do Windows" -Value "faltam atualizações de segurança" -Level Warn `
                -Target "updates.install" -Advice "instale em Atualizações > Instalar atualizações do Windows"
        }
        elseif ($lag -eq $false) {
            $findings += New-WinForgeCheckupFinding -Id "updates" -Label "Atualizações do Windows" -Value "nenhuma atualização de segurança atrasada" -Level Ok
        }
    }

    if ($null -eq $issue) {
        $value = $(if ($support.State -eq "Supported") { "$($support.Product): atualizações até $(Format-WinForgeDateTime -When $support.EndDate -Pattern 'dd/MM/yyyy')" } else { "$($support.Product): data não conhecida" })
        return @(@(New-WinForgeCheckupFinding -Id "windows" -Label "Suporte do Windows" -Value $value -Level $(if ($support.State -eq "Supported") { "Ok" } else { "Info" })) + $findings)
    }

    $value = switch ([string]$support.State) {
        "EndingSoon" { $(if ([int]$support.DaysLeft -le 0) { "atualizações só até hoje" } else { "atualizações só até $(Format-WinForgeDateTime -When $support.EndDate -Pattern 'dd/MM/yyyy')" }) }
        "Esu" { Get-WinForgeEsuText -Status $support }
        default {
            if ([string]$support.State -eq "EsuAvailable" -and -not [bool](Get-WinForgeJsonValue -Object $support -Name "EsuChecked" -Default $true)) { "não foi possível conferir o ESU" }
            else { "sem atualizações de segurança" }
        }
    }

    return @(@(New-WinForgeCheckupFinding -Id "windows" -Label "Suporte do Windows" -Value "$($support.Product): $value" -Level Warn -Target "diagnostics.windows-support" -Advice "veja o que fazer em Diagnóstico > Suporte do Windows") + $findings)
}


function Get-WinForgeCheckupProtection {
    $protection = Get-WinForgeSecurityStatus

    if ($null -eq $protection) {
        return (New-WinForgeCheckupFinding -Id "protection" -Label "Proteção" -Value "não foi possível ler" -Level Info -Target "security.status" -Unread $true)
    }

    $antivirus = $protection.Antivirus
    $problems = @()

    if ($null -ne $protection.Threats -and @($protection.Threats).Count -gt 0) { $problems += "ameaça ativa no antivírus" }
    if ($antivirus.Mode -eq "Off") { $problems += "nenhum antivírus ativo" }
    elseif ($antivirus.Mode -eq "Unavailable") { $problems += "não foi possível confirmar se há um antivírus ativo" }
    elseif ($antivirus.Mode -eq "Passive") { $problems += "Defender em modo passivo, sem outro antivírus identificado" }
    elseif ($antivirus.Mode -eq "Active" -and $antivirus.RealTime -eq $false) { $problems += "proteção em tempo real desligada" }
    if ($null -ne $protection.Firewall -and @(Get-WinForgeFirewallGaps -Firewall $protection.Firewall).Count -gt 0) { $problems += "firewall desligado em algum perfil" }

    # O que não pôde ser lido (como na tela Estado da proteção e no Início): sem o firewall, ou sem as ameaças com o
    # Defender protegendo, "em dia" seria afirmar o que não foi visto.
    $unread = @()
    if ($null -eq $protection.Firewall) { $unread += "o firewall" }
    if ($antivirus.Mode -eq "Active" -and $null -eq $protection.Threats) { $unread += "as ameaças ativas" }

    $findings = @()

    if ($problems.Count -gt 0) {
        $value = Join-WinForgeList -Items $problems
        if ($unread.Count -gt 0) { $value += "; não foi possível ler $(Join-WinForgeList -Items $unread)" }

        $findings += New-WinForgeCheckupFinding -Id "protection" -Label "Proteção" -Value $value -Level Warn -Target "security.status" -Advice "veja em Segurança > Estado da proteção"
    }
    elseif ($unread.Count -gt 0) {
        $findings += New-WinForgeCheckupFinding -Id "protection" -Label "Proteção" -Value "leitura incompleta: não foi possível ler $(Join-WinForgeList -Items $unread)" -Level Info -Target "security.status"
    }

    $isAdmin = Test-WinForgeAdministrator

    # Os mesmos limites da tela Estado da proteção: mais de 7 dias pede atenção; de 4 a 7, o Windows costuma atualizar
    # sozinho (um notebook desligado num feriado), então é só informação, com a atualização à mão e desmarcada.
    if ($antivirus.Mode -eq "Active" -and $null -ne $antivirus.SignatureAgeDays -and [int]$antivirus.SignatureAgeDays -gt 3) {
        $old = ([int]$antivirus.SignatureAgeDays -gt 7)

        $findings += New-WinForgeCheckupFinding -Id "signatures" -Label "Assinaturas do antivírus" -Value "atualizadas há $($antivirus.SignatureAgeDays) dias" -Level $(if ($old) { "Warn" } else { "Info" }) `
            -Fix $(if ($isAdmin) { "signatures" } else { "" }) -FixLabel "Atualizar as assinaturas do antivírus" -Selected ($isAdmin -and $old) -Target "security.signatures" `
            -Advice $(if ($isAdmin) { "" } elseif ($old) { "atualize em Segurança > Atualizar assinaturas do antivírus" } else { "" })
    }

    if ($findings.Count -eq 0) {
        $findings += New-WinForgeCheckupFinding -Id "protection" -Label "Proteção" -Value "em dia" -Level Ok
    }

    return @($findings)
}


function Get-WinForgeCheckupReboot {
    if (Test-WinForgePendingReboot) {
        return (New-WinForgeCheckupFinding -Id "reboot" -Label "Reinício pendente" -Value "sim" -Level Warn -Target "diagnostics.pending-reboot" -Advice "reinicie o PC quando puder; o motivo está em Diagnóstico > Reinício pendente")
    }

    return (New-WinForgeCheckupFinding -Id "reboot" -Label "Reinício pendente" -Value "não" -Level Ok)
}


function Invoke-WinForgeCheckupScan {
    <#
    Roda as etapas da verificação, uma por vez, com a barra de progresso. Uma etapa que falha vira um achado "não foi
    possível ler" e não interrompe as outras. Devolve os achados.
    #>
    param (
        [string[]]$Skip = @()
    )

    $steps = @(Get-WinForgeCheckupSteps | Where-Object { $Skip -notcontains $_.Id })
    $findings = @()
    $position = 0

    $readers = @{
        disk       = "Get-WinForgeCheckupDisk"
        junk       = "Get-WinForgeCheckupJunk"
        registry   = "Get-WinForgeCheckupRegistry"
        shortcuts  = "Get-WinForgeCheckupShortcuts"
        memory     = "Get-WinForgeCheckupMemory"
        startup    = "Get-WinForgeCheckupStartup"
        programs   = "Get-WinForgeCheckupPrograms"
        windows    = "Get-WinForgeCheckupWindows"
        protection = "Get-WinForgeCheckupProtection"
        reboot     = "Get-WinForgeCheckupReboot"
    }

    try {
        foreach ($step in $steps) {
            Write-Progress -Activity "Verificando o PC" -Status "$($position + 1) de $($steps.Count): $($step.Text)" -PercentComplete ([int]($position * 100 / $steps.Count))
            $position++

            try {
                $read = @(& $readers[$step.Id] | Where-Object { $null -ne $_ })
            }
            catch {
                Write-Verbose "Verificar o PC, $($step.Id): $($_.Exception.Message)"
                $read = @(New-WinForgeCheckupFinding -Id $step.Id -Label $step.Label -Value "não foi possível ler" -Level Info -Unread $true)
            }

            # A etapa de cada achado: o veredito conta etapas lidas, não achados (a limpeza e a proteção dão mais de um).
            foreach ($finding in $read) { Add-Member -InputObject $finding -NotePropertyName StepId -NotePropertyValue $step.Id -Force }

            $findings += $read
        }
    }
    finally {
        Write-Progress -Activity "Verificando o PC" -Completed
    }

    return @($findings)
}


function Invoke-WinForgeCheckupFix {
    # Aplica uma correção e devolve um WinForge.Result (Etapa = o rótulo da correção; Data.FreedBytes quando libera espaço).
    param ([Parameter(Mandatory)]$Finding)

    switch ($Finding.Fix) {
        { $_ -in "junk", "browser" } {
            $result = Invoke-WinForgeCleanupTargets -Targets @($Finding.Data) -NoSummary
        }
        "registry" {
            $result = Clear-WinForgeRegistryIssues -Issues @($Finding.Data)
        }
        "shortcuts" {
            $moved = @()
            $failed = 0

            try {
                foreach ($shortcut in @($Finding.Data)) {
                    # Aberto em outro programa, o Windows mostraria a janela "Arquivo em uso" e a correção ficaria parada.
                    if (Test-WinForgeItemInUse -Path $shortcut.Path) { $failed++; continue }

                    try { Move-WinForgeItemToRecycleBin -Path $shortcut.Path; $moved += $shortcut.Name } catch { $failed++ }
                }
            }
            finally {
                # No finally: parar a correção no meio não deixa sem anotação o que já foi para a Lixeira.
                if ($moved.Count -gt 0) {
                    [void](Add-WinForgeChange -Action "Atalhos quebrados" -Text "$(Join-WinForgeList -Items $moved) $(if ($moved.Count -eq 1) { 'foi' } else { 'foram' }) para a Lixeira")
                }
            }

            $text = Format-WinForgeCount -Count $moved.Count -One "atalho foi para a Lixeira" -Many "atalhos foram para a Lixeira"
            $result = $(if ($failed -eq 0) { New-WinForgeResult -Kind Ok -Detail $text } elseif ($moved.Count -eq 0) { New-WinForgeResult -Kind Failed -Detail "nenhum atalho foi removido" } else { New-WinForgeResult -Kind Warning -Detail "$text; $failed não" })
        }
        "signatures" {
            $result = Update-WinForgeDefenderSignatures -Embedded -PassThru
        }
        default {
            $result = New-WinForgeResult -Kind Failed -Detail "correção desconhecida"
        }
    }

    $result.Etapa = $Finding.FixLabel

    return $result
}


function Set-WinForgeCheckupView {
    <#
    Como a janela mostra o fim da verificação: depois de correções, o título da faixa diz o que foi feito ("3 correções
    feitas, 1,9 GB liberados") e a frase embaixo, o que ainda pede a pessoa. Com algo pedindo atenção, o botão da faixa
    leva à tela do primeiro deles (Limpeza personalizada, Atualizações...). O console continua com o Detail.
    #>
    param (
        [Parameter(Mandatory)]$Result,
        [object[]]$Results = @(),
        [int]$Failed = 0,
        [int64]$Freed = 0,
        [object[]]$Remaining = @(),
        [AllowEmptyString()][string]$Unread = "",
        [switch]$Declined
    )

    # Todas as correções falhando: a faixa vermelha genérica ("Nenhuma correção funcionou") já diz tudo.
    if (@($Results).Count -gt 0 -and $Failed -ge @($Results).Count) { return $Result }

    $next = ""
    $nextLabel = ""
    $first = @(@($Remaining) | Where-Object { $null -ne $_ -and -not [string]::IsNullOrEmpty([string]$_.Target) }) | Select-Object -First 1

    if ($null -ne $first) {
        try {
            $item = Get-WinForgeNavItem -Id ([string]$first.Target)
            if ($null -ne $item) { $next = [string]$item.Id; $nextLabel = [string]$item.Label }
        }
        catch {
            Write-Verbose "Próximo passo da verificação: $($_.Exception.Message)"
        }
    }

    $headline = ""
    $notes = @()

    $names = Join-WinForgeList -Items @($Remaining | ForEach-Object { [string]$_.Label })

    if (@($Results).Count -gt 0) {
        $headline = Format-WinForgeCount -Count (@($Results).Count - $Failed) -One "correção feita" -Many "correções feitas"
        if ($Freed -gt 0) { $headline += ", $(Format-WinForgeBytes -Bytes $Freed) liberados" }
    }
    elseif ($Declined) {
        $headline = "Nenhuma correção feita"
    }
    elseif (@($Remaining).Count -gt 0) {
        # Nada a corrigir daqui: o título conta, e a frase embaixo diz quais (o botão leva ao primeiro).
        $headline = Format-WinForgeCount -Count @($Remaining).Count -One "ponto pede você" -Many "pontos pedem você"
        $notes += $names
    }

    if (@($Remaining).Count -gt 0 -and (@($Results).Count -gt 0 -or $Declined)) { $notes += "Ainda $(if (@($Remaining).Count -eq 1) { 'pede' } else { 'pedem' }) você: $names" }
    if (-not [string]::IsNullOrWhiteSpace($Unread)) { $notes += "Não foi possível ler: $Unread" }
    if ($headline -and $notes.Count -eq 0) { $notes += "Nada mais pedindo atenção" }

    if (-not $headline -and -not $next) { return $Result }

    return (Set-WinForgeResultView -Result $Result -Headline $headline -Note $(if ($headline) { "$($notes -join '. ')." } else { "" }) -Next $next -NextLabel $nextLabel)
}


function Invoke-WinForgeCheckup {
    $title = "Verificar o PC"

    Enter-WinForgeAction -Title $title

    $final = New-WinForgeResult -Kind Ok -Title $title

    try {
        $findings = @(Invoke-WinForgeCheckupScan)

        Write-WinForgeSection -Title "O que a verificação encontrou"

        foreach ($finding in $findings) {
            Write-WinForgeKeyValue -Label $finding.Label -Value $finding.Value -LabelWidth 32 -Level $(if ($finding.Level -eq "Info") { "Normal" } else { $finding.Level })
        }

        Write-Host ""

        $attention = @($findings | Where-Object { $_.Level -eq "Warn" })
        $fixable = @($findings | Where-Object { $_.Fix })
        $safe = @($fixable | Where-Object { $_.Selected })
        $manual = @($attention | Where-Object { -not $_.Fix -and $_.Advice })

        foreach ($finding in $manual) {
            Write-WinForgeStatus -Type Warning -Message "$($finding.Label): $($finding.Advice)."
        }

        # A verificação conta como cuidado com o PC (o Início e o monitor param de lembrar por um mês) só quando ela de
        # fato olhou o PC (mais da metade das etapas respondeu) e não deixou correções seguras para trás: cancelada, ou
        # com todas as correções falhando, ela não cuidou de nada.
        $unreadFindings = @($findings | Where-Object { [bool](Get-WinForgeJsonValue -Object $_ -Name "Unread" -Default $false) })
        $stepOf = { param ($item) [string](Get-WinForgeJsonValue -Object $item -Name "StepId" -Default $item.Id) }
        $stepCount = @($findings | ForEach-Object { & $stepOf $_ } | Select-Object -Unique).Count
        $unreadSteps = @($unreadFindings | ForEach-Object { & $stepOf $_ } | Select-Object -Unique).Count
        $scanRead = ($stepCount -gt 0 -and ($unreadSteps * 2) -lt $stepCount)

        # O que não respondeu vai junto do veredito (como a nota "Incompleta" do Início): "nada pedindo atenção" em verde
        # afirmaria o que não foi visto.
        $unreadText = Join-WinForgeList -Items @($unreadFindings | ForEach-Object { [string]$_.Label })

        $results = @()
        $fixedIds = @()
        $freed = [int64]0
        # A pessoa cancelou a lista de correções: o veredito é o da verificação, sem conta como cuidado com o PC.
        $declined = $false

        if ($fixable.Count -gt 0) {
            if ($manual.Count -gt 0) { Write-Host "" }

            if ($safe.Count -gt 0) {
                # Só o que está de fato marcado na lista: falar do registro ou dos atalhos quando eles nem aparecem confunde.
                $why = @{
                    junk       = "os temporários o Windows recria"
                    registry   = "o registro tem backup e volta em Manutenção > Histórico de mudanças"
                    shortcuts  = "os atalhos vão para a Lixeira"
                    signatures = "as assinaturas só são atualizadas"
                }
                $reasons = @($safe | Where-Object { $why.ContainsKey([string]$_.Fix) } | ForEach-Object { $why[[string]$_.Fix] } | Select-Object -Unique)
                $message = $(if ($reasons.Count -gt 0) { "O que vem marcado é seguro: $(Join-WinForgeList -Items $reasons)." } else { "O que vem marcado é seguro de corrigir." })

                Write-WinForgeStatus -Type Info -Message $message
            }
            else {
                Write-WinForgeStatus -Type Info -Message "Nada desta lista é necessário: marque só o que quiser fazer agora."
            }

            Write-Host ""

            $options = @(
                foreach ($finding in $fixable) {
                    $description = $finding.Value
                    if ($finding.Advice) { $description += " · $($finding.Advice)" }
                    @{ Key = $finding.Id; Label = $finding.FixLabel; Description = $description; Selected = [bool]$finding.Selected }
                }
            )

            $picked = Read-WinForgeMultiSelect -Message "O que corrigir agora?" -Options $options -ConfirmLabel "Corrigir" -CancelLabel "Agora não"

            # Com correções seguras na lista, não escolher nada é cancelar as correções, mas não a verificação: o que ela
            # achou continua na tela e na faixa (um antivírus desligado não pode sumir num "Operação cancelada"). Só com o
            # que é opcional (o cache dos navegadores, por exemplo), é a resposta "não, obrigado".
            if (($null -eq $picked -or @($picked).Count -eq 0) -and $safe.Count -gt 0) {
                $declined = $true
                Write-WinForgeStatus -Type Info -Message "Nenhuma correção foi feita."
            }

            $chosen = @($fixable | Where-Object { $null -ne $picked -and @($picked) -contains $_.Id })
            $position = 0

            foreach ($finding in $chosen) {
                Write-Progress -Activity "Corrigindo" -Status "$($position + 1) de $($chosen.Count): $($finding.FixLabel)" -PercentComplete ([int]($position * 100 / $chosen.Count))
                $position++

                try {
                    $result = Invoke-WinForgeCheckupFix -Finding $finding
                }
                catch {
                    $result = New-WinForgeResult -Kind Failed -Detail $_.Exception.Message.TrimEnd('.')
                    $result.Etapa = $finding.FixLabel
                }

                $bytes = Get-WinForgeResultData -Result $result -Name "FreedBytes"
                if ($null -ne $bytes) { $freed += [int64]$bytes }
                # Remaining: a correção rodou, mas o ponto continua pedindo atenção (a memória ainda alta, por exemplo).
                if ($result.Kind -ne "Failed" -and -not [bool](Get-WinForgeResultData -Result $result -Name "Remaining")) { $fixedIds += $finding.Id }

                $results += $result
            }

            if ($chosen.Count -gt 0) {
                Write-Progress -Activity "Corrigindo" -Completed

                Write-WinForgeSection -Title "Resumo"
                Write-WinForgeResultTable -Results $results

                if ($freed -gt 0) {
                    Write-WinForgeKeyValue -Label "Espaço liberado" -Value (Format-WinForgeBytes -Bytes $freed) -Level Ok
                }
            }
        }

        $failed = @($results | Where-Object { $_.Kind -eq "Failed" })
        $warned = @($results | Where-Object { $_.Kind -eq "Warning" })

        # O que continua pedindo atenção: tudo o que foi apontado e não foi corrigido (por escolha, ou porque a correção
        # falhou). Sem isso, "1 correção feita" em verde esconderia um antivírus desligado.
        $remaining = @($attention | Where-Object { $fixedIds -notcontains $_.Id })

        if ($scanRead -and -not $declined -and ($results.Count -eq 0 -or $failed.Count -lt $results.Count)) {
            [void](Set-WinForgeSetting -Name "LastCheckup" -Value (Get-Date).ToString("s", [System.Globalization.CultureInfo]::InvariantCulture))
        }

        $data = @{ FreedBytes = $freed }

        if ($results.Count -eq 0 -and -not $scanRead) {
            Write-WinForgeStatus -Type Error -Message "Não foi possível ler a maior parte do PC: tente de novo; se continuar, reinicie o PC."
            $final = New-WinForgeResult -Kind Failed -Detail "não foi possível ler a maior parte do PC" -Title $title
        }
        elseif ($results.Count -gt 0 -and $failed.Count -eq $results.Count) {
            $final = New-WinForgeResult -Kind Failed -Detail "nenhuma correção funcionou" -Title $title -Data $data
        }
        else {
            $parts = @()

            if ($results.Count -gt 0) {
                $done = Format-WinForgeCount -Count ($results.Count - $failed.Count) -One "correção feita" -Many "correções feitas"
                $parts += $(if ($freed -gt 0) { "$done; $(Format-WinForgeBytes -Bytes $freed) liberados" } else { $done })
            }
            elseif ($declined) {
                $parts += "nenhuma correção feita"
            }

            if ($failed.Count -gt 0 -or $warned.Count -gt 0) {
                $parts += "$(Join-WinForgeList -Items @(@($failed) + @($warned) | ForEach-Object { [string]$_.Etapa })) com problema"
            }

            if ($remaining.Count -gt 0) {
                # A faixa diz o que pede atenção pelo nome (um "2 pontos pedem a sua decisão" não diz quais).
                $still = $(if ($results.Count -gt 0 -or $declined) { "ainda " } else { "" })
                $names = Join-WinForgeList -Items @($remaining | ForEach-Object { [string]$_.Label })
                $parts += "$still$(if ($remaining.Count -eq 1) { 'pede' } else { 'pedem' }) atenção: $names"

                if ($results.Count -gt 0 -or $declined) {
                    # O que fazer com cada um que tem orientação e ainda não a mostrou (os sem correção já a mostraram
                    # antes da lista): a memória, por exemplo, só tinha a dica dentro da lista de marcar.
                    foreach ($finding in @($remaining | Where-Object { $_.Fix -and $_.Advice })) {
                        Write-WinForgeStatus -Type Warning -Message "$($finding.Label): $($finding.Advice)."
                    }

                    Write-WinForgeStatus -Type Warning -Message "Ainda $(if ($remaining.Count -eq 1) { 'pede' } else { 'pedem' }) atenção: $names."
                }
            }

            if ($unreadFindings.Count -gt 0) { $parts += "não foi possível ler: $unreadText" }

            if ($parts.Count -eq 0) {
                Write-WinForgeStatus -Type Success -Message "Nada pedindo atenção."
                $parts += "nada pedindo atenção"
            }
            elseif ($results.Count -eq 0 -and $remaining.Count -eq 0) {
                Write-WinForgeStatus -Type Warning -Message "Nada pedindo atenção no que foi lido; não foi possível ler: $unreadText."
                $parts = @("nada pedindo atenção no que foi lido; não foi possível ler: $unreadText")
            }

            $clean = ($failed.Count -eq 0 -and $warned.Count -eq 0 -and $remaining.Count -eq 0 -and $unreadFindings.Count -eq 0)
            $final = New-WinForgeResult -Kind $(if ($clean) { "Ok" } else { "Warning" }) -Detail ($parts -join "; ") -Title $title -Data $data
            $final = Set-WinForgeCheckupView -Result $final -Results $results -Failed $failed.Count -Freed $freed -Remaining $remaining -Unread $unreadText -Declined:$declined
        }
    }
    catch {
        Write-Progress -Activity "Verificando o PC" -Completed
        Write-WinForgeStatus -Type Error -Message "Não foi possível verificar o PC: $($_.Exception.Message.TrimEnd('.'))."
        $final = New-WinForgeResult -Kind Failed -Detail $_.Exception.Message.TrimEnd('.') -Title $title
    }

    Exit-WinForgeAction -Result $final
}


Export-ModuleMember -Function *
