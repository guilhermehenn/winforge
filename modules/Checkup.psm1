# Verificar o PC: olha tudo de uma vez e corrige com um clique o que é seguro corrigir.
#
# A verificação só lê (espaço e saúde dos discos, lixo acumulado, registro, atalhos, memória, inicialização, programas
# desatualizados, suporte e atualizações do Windows, proteção, reinício pendente e telas azuis). A consulta do winget, a
# mais demorada (depende da rede), começa antes de todas e corre junto com as outras etapas, com prazo. Depois, uma lista
# de marcar traz o que dá para corrigir aqui mesmo, com o que é seguro já marcado: temporários e relatórios de erro (o Windows recria), atalhos
# quebrados (para a Lixeira) e assinaturas do antivírus. As referências quebradas do registro ficam na lista, desmarcadas
# (a Microsoft não recomenda limpar o registro; o WinForge guarda backup e desfaz, mas o ganho é pequeno). O resto vira
# um atalho para a tela certa: liberar espaço, fechar o que pesa na memória, decidir o que abre com o Windows ou
# atualizar programas pede o olhar da pessoa.


function New-WinForgeCheckupFinding {
    <#
    Um achado da verificação. Fix = nome da correção (vazio = não se corrige daqui); Selected = vem marcado; Target = item
    da navegação para ver de perto; Level = Ok | Warn | Info; Data = o que a correção precisa; Unread = a leitura não
    respondeu (a etapa conta como não lida no veredito). Short = o nome nas listas ("ainda pedem você: ..."), quando o
    rótulo da linha não serve para elas; sem ele, vale o Label.
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
        [bool]$Unread = $false,
        [string]$Short = ""
    )

    return [PSCustomObject]@{
        Id       = $Id
        Label    = $Label
        Short    = $(if ($Short) { $Short } else { $Label })
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
        @{ Id = "disk"; Label = (Get-WinForgeText 'Espaço no disco'); Text = (Get-WinForgeText 'medindo o espaço livre e conferindo a saúde dos discos') },
        @{ Id = "junk"; Label = (Get-WinForgeText 'Temporários'); Text = (Get-WinForgeText 'medindo temporários e caches') },
        @{ Id = "registry"; Label = (Get-WinForgeText 'Registro'); Text = (Get-WinForgeText 'procurando referências quebradas no registro') },
        @{ Id = "shortcuts"; Label = (Get-WinForgeText 'Atalhos'); Text = (Get-WinForgeText 'conferindo os atalhos') },
        @{ Id = "memory"; Label = (Get-WinForgeText 'Memória'); Text = (Get-WinForgeText 'lendo o uso de memória') },
        @{ Id = "startup"; Label = (Get-WinForgeText 'Abrem com o Windows'); Text = (Get-WinForgeText 'contando o que abre com o Windows') },
        @{ Id = "programs"; Label = (Get-WinForgeText 'Programas desatualizados'); Text = (Get-WinForgeText 'procurando programas desatualizados (winget)') },
        @{ Id = "windows"; Label = (Get-WinForgeText 'Suporte do Windows'); Text = (Get-WinForgeText 'conferindo o suporte e as atualizações do Windows') },
        @{ Id = "protection"; Label = (Get-WinForgeText 'Proteção'); Text = (Get-WinForgeText 'conferindo a proteção') },
        @{ Id = "reboot"; Label = (Get-WinForgeText 'Reinício pendente'); Text = (Get-WinForgeText 'conferindo se falta reiniciar') },
        @{ Id = "bluescreens"; Label = (Get-WinForgeText 'Telas azuis'); Text = (Get-WinForgeText 'procurando telas azuis recentes') }
    )
}


function Get-WinForgeCheckupDisk {
    # O espaço livre no disco do Windows (Get-WinForgeCheckupDiskSpace) e, quando algum disco dá sinais de que pode falhar
    # (Test-WinForgeDiskFailing, o mesmo aviso do monitor na bandeja), um achado a mais, que leva a Diagnóstico > Saúde
    # dos discos. Com mais de um disco falhando, é um ponto só, com os nomes: dois pontos iguais ("Saúde do disco e Saúde
    # do disco") não diziam qual era qual. Uma leitura da saúde que falha não tira o espaço livre da conta.
    $findings = @(Get-WinForgeCheckupDiskSpace)

    try {
        $failing = @(Get-WinForgeDiskHealth | Where-Object { Test-WinForgeDiskFailing -Disk $_ })
        $names = @(foreach ($disk in $failing) {
                $drives = @(Get-WinForgeJsonValue -Object $disk -Name "Drives" -Default @())
                $(if ($drives.Count -gt 0) { Get-WinForgeText '{0} ({1})' "$($disk.Name)" "$(Join-WinForgeList -Items $drives)" } else { [string]$disk.Name })
            })
        $advice = (Get-WinForgeText 'faça backup dos seus arquivos e veja Diagnóstico > Saúde dos discos')

        if ($failing.Count -eq 1) {
            $findings += New-WinForgeCheckupFinding -Id "disk-health" -Label (Get-WinForgeText 'Saúde do disco') -Value (Get-WinForgeText '{0}: {1}' "$($names[0])" "$(Get-WinForgeDiskFailingText -Disk $failing[0])") -Level Warn `
                -Target "diagnostics.disk-health" -Advice $advice
        }
        elseif ($failing.Count -gt 1) {
            # O sinal de cada um fica na tela aonde o ponto leva: na faixa, a frase com todos passaria das 220 letras.
            $findings += New-WinForgeCheckupFinding -Id "disk-health" -Label (Get-WinForgeText 'Saúde dos discos') -Value (Get-WinForgeText '{0} dão sinal de falha' "$(Join-WinForgeList -Items $names)") -Level Warn `
                -Target "diagnostics.disk-health" -Advice $advice
        }
    }
    catch {
        Write-Verbose "Saúde do disco: $($_.Exception.Message)"
    }

    return $findings
}


function Get-WinForgeCheckupDiskSpace {
    # O espaço livre no disco do Windows, com a regra do Início (Get-WinForgeDiskSpaceLevel): menos de 20 GB pede
    # atenção, menos de 10 GB é quase cheio. Não se corrige daqui: a Limpeza personalizada mostra o tamanho de cada
    # coisa que dá para apagar (os temporários desta verificação, logo abaixo, já ajudam).
    $space = Get-WinForgeSystemDriveSpace
    $level = $(if ($null -eq $space) { "Unknown" } else { Get-WinForgeDiskSpaceLevel -FreeBytes $space.FreeBytes -TotalBytes $space.TotalBytes })

    if ($level -eq "Unknown") {
        return (New-WinForgeCheckupFinding -Id "disk" -Label (Get-WinForgeText 'Espaço no disco') -Value (Get-WinForgeText 'não foi possível ler') -Level Info -Unread $true)
    }

    $value = (Get-WinForgeText '{0} livres de {1}' "$(Format-WinForgeBytes -Bytes $space.FreeBytes)" "$(Format-WinForgeBytes -Bytes $space.TotalBytes)")

    # Data = o nível, que decide o peso do ponto (Get-WinForgeCheckupWeight): o disco quase cheio vem antes.
    if ($level -in @("Critical", "Low")) {
        return (New-WinForgeCheckupFinding -Id "disk" -Label (Get-WinForgeText 'Espaço no disco') -Value $(if ($level -eq 'Critical') { (Get-WinForgeText '{0} (quase cheio)' "$value") } else { (Get-WinForgeText '{0} (pouco espaço)' "$value") }) -Level Warn `
                -Target "cleanup.custom" -Advice (Get-WinForgeText 'libere espaço em Limpeza > Limpeza personalizada') -Data $level)
    }

    return (New-WinForgeCheckupFinding -Id "disk" -Label (Get-WinForgeText 'Espaço no disco') -Value $value -Level Ok)
}


function Get-WinForgeCheckupJunk {
    $isAdmin = Test-WinForgeAdministrator
    $all = @(Get-WinForgeCleanupTargets)
    $targets = @($all | Where-Object { $_.Selected -and ($isAdmin -or -not $_.Admin) })
    $measured = @(foreach ($target in $targets) { Measure-WinForgeCleanupTarget -Target $target })
    $size = [int64]0
    foreach ($target in $measured) { if ($null -ne $target.Size) { $size += [int64]$target.Size } }

    # O nome da correção diz o que ela apaga. Com Administrador, o que vem marcado na Limpeza personalizada inclui os
    # relatórios de erro e o cache da Otimização de Entrega (pedaços de atualizações já instaladas); sem ele, os dois pedem
    # Administrador e ficam de fora: só os temporários desta conta. A linha e as listas dizem só "Temporários" (um nome com
    # vírgulas se perdia no meio de "ainda pedem você: Espaço no disco, Temporários, ...").
    $ids = @($measured | ForEach-Object { [string]$_.Id })
    $label = (Get-WinForgeText 'Temporários')
    $fixLabel = $(
        if ($ids -contains "delivery-optimization") { (Get-WinForgeText 'Apagar temporários, relatórios de erro e cache de atualizações') }
        elseif ($ids -contains "error-reports") { (Get-WinForgeText 'Apagar temporários e relatórios de erro') }
        else { (Get-WinForgeText 'Apagar os temporários do usuário') }
    )

    $findings = @()

    # Nenhuma pasta pôde ser medida (sem permissão para ler): "nada acumulado" afirmaria o que não foi visto, como a
    # Limpeza personalizada já evita.
    if ($measured.Count -gt 0 -and @($measured | Where-Object { $null -ne $_.Size }).Count -eq 0) {
        $findings += New-WinForgeCheckupFinding -Id "junk" -Label $label -Value (Get-WinForgeText 'não foi possível ler') -Level Info -Target "cleanup.custom" -Unread $true
    }
    elseif ($size -ge 50MB) {
        $findings += New-WinForgeCheckupFinding -Id "junk" -Label $label -Value (Format-WinForgeBytes -Bytes $size) -Level Warn `
            -Fix "junk" -FixLabel $fixLabel -Selected $true -Target "cleanup.custom" -Data @($measured)
    }
    else {
        $findings += New-WinForgeCheckupFinding -Id "junk" -Label $label -Value $(if ($size -gt 0) { (Get-WinForgeText 'pouco ({0})' "$(Format-WinForgeBytes -Bytes $size)") } else { (Get-WinForgeText 'nada acumulado') }) -Level Ok
    }

    $browser = @($all | Where-Object { $_.Id -eq "browser-cache" }) | Select-Object -First 1

    if ($null -ne $browser) {
        $browser = Measure-WinForgeCleanupTarget -Target $browser

        if ($null -ne $browser.Size -and [int64]$browser.Size -ge 200MB) {
            $findings += New-WinForgeCheckupFinding -Id "browser" -Label (Get-WinForgeText 'Cache dos navegadores') -Value (Format-WinForgeBytes -Bytes $browser.Size) -Level Info `
                -Fix "browser" -FixLabel (Get-WinForgeText 'Limpar o cache dos navegadores') -Target "cleanup.custom" -Data @($browser) `
                -Advice (Get-WinForgeText 'senhas, cookies e histórico ficam; as páginas abrem mais devagar na primeira vez')
        }
    }

    if (-not $isAdmin) {
        $findings += New-WinForgeCheckupFinding -Id "junk-admin" -Label (Get-WinForgeText 'Temporários do Windows') -Value (Get-WinForgeText 'só com Administrador') -Level Info -Target "cleanup.quick"
    }

    return @($findings)
}


function Get-WinForgeCheckupRegistry {
    # As bibliotecas compartilhadas (SharedDLLs) ficam fora da correção com um clique: é uma contagem de uso que
    # instaladores consultam, e quem decide removê-la é a pessoa, olhando a lista em Limpeza > Limpar o registro. As
    # outras referências quebradas vêm na lista desmarcadas: a Microsoft não dá suporte a programas de limpeza do registro
    # (KB2563254), e o ganho de remover chaves órfãs é pequeno; o backup e o desfazer continuam valendo para quem marcar.
    # Por isso elas são informação, e não um ponto de atenção: quase todo PC tem alguma, e um ponto que o próprio WinForge
    # não recomenda corrigir deixaria toda verificação "com ressalvas" ("ainda pede atenção: Registro").
    $all = @(Find-WinForgeRegistryIssues)
    $issues = @($all | Where-Object { $_.Category -ne "shared-dlls" })
    $shared = $all.Count - $issues.Count
    $advice = $(if ($shared -gt 0) { (Get-WinForgeText '{0} para você revisar em Limpeza > Limpar o registro' "$(Format-WinForgeCount -Count $shared -One (Get-WinForgeText 'biblioteca compartilhada fica') -Many (Get-WinForgeText 'bibliotecas compartilhadas ficam'))") } else { "" })

    if ($issues.Count -eq 0) {
        if ($shared -gt 0) {
            # Sobras comuns e inofensivas: informação, sem orientação, e não um ponto que pede decisão a cada verificação.
            return (New-WinForgeCheckupFinding -Id "registry" -Label (Get-WinForgeText 'Registro') -Value (Format-WinForgeCount -Count $shared -One (Get-WinForgeText 'biblioteca compartilhada que não existe mais') -Many (Get-WinForgeText 'bibliotecas compartilhadas que não existem mais')) -Level Info `
                    -Target "cleanup.registry")
        }

        return (New-WinForgeCheckupFinding -Id "registry" -Label (Get-WinForgeText 'Registro') -Value (Get-WinForgeText 'nenhuma referência quebrada') -Level Ok)
    }

    return (New-WinForgeCheckupFinding -Id "registry" -Label (Get-WinForgeText 'Registro') -Value (Format-WinForgeCount -Count $issues.Count -One (Get-WinForgeText 'referência quebrada') -Many (Get-WinForgeText 'referências quebradas')) -Level Info `
            -Fix "registry" -FixLabel (Get-WinForgeText 'Remover as referências quebradas do registro (com backup)') -Selected $false -Target "cleanup.registry" -Advice $advice -Data $issues)
}


function Get-WinForgeCheckupShortcuts {
    # Os atalhos do OneDrive ficam fora da correção de um clique: o programa pode estar instalado em outro PC da pessoa, e
    # o atalho apagado aqui some de lá também. Eles aparecem, desmarcados, em Limpeza > Remover atalhos quebrados, e a
    # linha diz isso, como o registro faz com as bibliotecas compartilhadas: "nenhum quebrado" com eles lá não era verdade.
    $isAdmin = Test-WinForgeAdministrator
    $usable = @(Find-WinForgeBrokenShortcuts | Where-Object { $isAdmin -or -not $_.Admin })
    $broken = @($usable | Where-Object { -not [bool](Get-WinForgeJsonValue -Object $_ -Name "Synced" -Default $false) })
    $synced = $usable.Count - $broken.Count

    if ($broken.Count -eq 0) {
        if ($synced -gt 0) {
            return (New-WinForgeCheckupFinding -Id "shortcuts" -Label (Get-WinForgeText 'Atalhos') -Value (Format-WinForgeCount -Count $synced -One (Get-WinForgeText 'atalho quebrado no OneDrive') -Many (Get-WinForgeText 'atalhos quebrados no OneDrive')) -Level Info `
                    -Target "cleanup.shortcuts" -Advice (Get-WinForgeText 'revise em Limpeza > Remover atalhos quebrados; o programa pode estar em outro PC seu'))
        }

        return (New-WinForgeCheckupFinding -Id "shortcuts" -Label (Get-WinForgeText 'Atalhos') -Value (Get-WinForgeText 'nenhum quebrado') -Level Ok)
    }

    $advice = $(if ($synced -gt 0) { (Get-WinForgeText '{0} para você revisar em Limpeza > Remover atalhos quebrados' "$(Format-WinForgeCount -Count $synced -One (Get-WinForgeText 'atalho do OneDrive fica') -Many (Get-WinForgeText 'atalhos do OneDrive ficam'))") } else { "" })

    return (New-WinForgeCheckupFinding -Id "shortcuts" -Label (Get-WinForgeText 'Atalhos') -Value (Format-WinForgeCount -Count $broken.Count -One (Get-WinForgeText 'atalho quebrado') -Many (Get-WinForgeText 'atalhos quebrados')) -Level Warn `
            -Fix "shortcuts" -FixLabel (Get-WinForgeText 'Enviar os atalhos quebrados para a Lixeira') -Selected $true -Target "cleanup.shortcuts" -Advice $advice -Data $broken)
}


function Get-WinForgeCheckupMemory {
    $memory = Get-WinForgeMemoryUsage

    # Sem leitura, a linha diz isso: sumir com ela pareceria que a memória nem foi olhada (ou que está tudo bem).
    if ($null -eq $memory) {
        return (New-WinForgeCheckupFinding -Id "memory" -Label (Get-WinForgeText 'Memória') -Value (Get-WinForgeText 'não foi possível ler') -Level Info -Unread $true)
    }

    $text = (Get-WinForgeText '{0}% em uso ({1} de {2})' "$($memory.Percent)" "$(Format-WinForgeBytes -Bytes $memory.Used)" "$(Format-WinForgeBytes -Bytes $memory.Total)")

    # Sem correção daqui: esvaziar a memória dos programas não resolve (eles a recarregam do disco, mais devagar, e a
    # memória volta a encher). O que resolve é fechar o que pesa.
    if (Test-WinForgeMemoryHigh -Memory $memory) {
        return (New-WinForgeCheckupFinding -Id "memory" -Label (Get-WinForgeText 'Memória') -Value $text -Level Warn -Target "performance.processes" `
                -Advice (Get-WinForgeText 'feche o que pesa em Desempenho > Programas pesando agora'))
    }

    return (New-WinForgeCheckupFinding -Id "memory" -Label (Get-WinForgeText 'Memória') -Value $text -Level Ok)
}


function Get-WinForgeCheckupStartup {
    # Mais de 8 pede atenção, com o caminho para Desempenho > Gerenciar inicialização: a página do PC lento, a mesma aonde
    # a memória alta leva.
    $enabled = @(Get-WinForgeStartupItems | Where-Object { $_.Enabled }).Count

    if ($enabled -gt 8) {
        return (New-WinForgeCheckupFinding -Id "startup" -Label (Get-WinForgeText 'Abrem com o Windows') -Value (Format-WinForgeCount -Count $enabled -One (Get-WinForgeText 'programa') -Many (Get-WinForgeText 'programas')) -Level Warn `
                -Target "performance.startup" -Advice (Get-WinForgeText 'desligue o que não precisa em Desempenho > Gerenciar inicialização'))
    }

    return (New-WinForgeCheckupFinding -Id "startup" -Label (Get-WinForgeText 'Abrem com o Windows') -Value (Format-WinForgeCount -Count $enabled -One (Get-WinForgeText 'programa') -Many (Get-WinForgeText 'programas')) -Level Ok)
}


function Get-WinForgeCheckupPrograms {
    <#
    Os programas desatualizados. -Read: a consulta já começada (Start-WinForgeWingetUpgradeRead, a mesma do Otimizar);
    sem ela, a consulta começa agora. A espera vai até o prazo dela (Receive-WinForgeWingetUpgradeRead, contado do começo
    da consulta) e continua interrompível pelo Parar; sem resposta, a consulta é largada e a etapa fica como não lida.
    Sem o winget, o ponto leva ao reparo, como a tela Programas: quase tudo lá depende dele, e a pessoa nem saberia dos
    programas desatualizados.
    #>
    param ($Read = $null)

    $label = (Get-WinForgeText 'Programas desatualizados')

    if (-not (Test-WinForgeWinget)) {
        return (New-WinForgeCheckupFinding -Id "programs" -Label $label -Short (Get-WinForgeText 'Instalador de Aplicativo') -Value (Get-WinForgeText 'não dá para conferir sem o Instalador de Aplicativo (winget)') -Level Warn `
                -Target "software.winget-repair" -Advice (Get-WinForgeText 'veja o que fazer em Programas > Reparar o Instalador de Aplicativo'))
    }

    if ($null -eq $Read) { $Read = Start-WinForgeWingetUpgradeRead }

    $received = Receive-WinForgeWingetUpgradeRead -Task $Read

    if ($received.TimedOut) {
        return (New-WinForgeCheckupFinding -Id "programs" -Label $label -Value (Get-WinForgeText 'o Instalador de Aplicativo não respondeu em {0} segundos' "$($received.TimeoutSeconds)") -Level Info -Target "updates.winget" -Unread $true)
    }

    if ($null -eq $received.Upgrade) {
        Write-Verbose "Programas desatualizados: $($received.Error)"
        return (New-WinForgeCheckupFinding -Id "programs" -Label $label -Value (Get-WinForgeText 'não foi possível ler') -Level Info -Target "updates.winget" -Unread $true)
    }

    return (ConvertTo-WinForgeCheckupProgramsFinding -Upgrade $received.Upgrade)
}


function ConvertTo-WinForgeCheckupProgramsFinding {
    # O ponto dos programas desatualizados a partir da resposta do "winget upgrade" (ExitCode, Lines e Text), com as
    # mesmas regras da tela Atualizar programas: nada a atualizar pelo código ou pela frase, os marcados para não atualizar
    # fora da conta, e uma resposta sem tabela que não diz "nada a atualizar" como não lida.
    param ([Parameter(Mandatory)]$Upgrade)

    $label = (Get-WinForgeText 'Programas desatualizados')

    if (Test-WinForgeWingetNoUpgradeOutput -OutputText ([string]$Upgrade.Text) -ExitCode ([int]$Upgrade.ExitCode)) {
        return (New-WinForgeCheckupFinding -Id "programs" -Label $label -Value (Get-WinForgeText 'nenhum') -Level Ok)
    }

    $available = @(ConvertFrom-WinForgeWingetTable -Lines @($Upgrade.Lines))

    if ($available.Count -eq 0) {
        return (New-WinForgeCheckupFinding -Id "programs" -Label $label -Value (Get-WinForgeText 'não foi possível ler') -Level Info -Target "updates.winget" -Unread $true)
    }

    return (New-WinForgeCheckupFinding -Id "programs" -Label $label -Value (Format-WinForgeCount -Count $available.Count -One (Get-WinForgeText 'programa') -Many (Get-WinForgeText 'programas')) -Level Warn `
            -Target "updates.winget" -Advice (Get-WinForgeText 'atualize em Atualizações > Atualizar programas (winget)'))
}


function Get-WinForgeCheckupWindows {
    # O ESU do Windows 10 é conferido pela revisão da build instalada, sem consultar o histórico de atualizações.
    $support = Get-WinForgeWindowsSupportStatus

    $issue = Get-WinForgeWindowsSupportIssue -Status $support
    $findings = @()

    # Com o suporte em dia, falta saber se as atualizações chegaram (a mesma conta do Início): um Windows parado na
    # atualização de meses atrás (Windows Update pausado, desligado ou com defeito) está sem as correções de segurança,
    # mesmo dentro do prazo. Sem como saber (versão fora do catálogo, Windows Server), a linha só aparece com a pausa.
    # Pausadas (Configurações > Windows Update), o Windows não instala nada até a data: com as de segurança atrasadas, o
    # que resolve é retomar, e o ponto leva ao Windows Update, como a linha da página Atualizações; em dia, a pausa é uma
    # escolha da pessoa (até 35 dias) e fica como informação.
    if ([string]$support.State -in @("Supported", "EndingSoon", "Esu")) {
        $label = (Get-WinForgeText 'Atualizações do Windows')
        $lag = $null
        $pause = Get-WinForgeWindowsUpdatePause
        $paused = $(if ($null -ne $pause) { Get-WinForgeUpdatePauseText -Pause $pause -Detail } else { "" })

        try { $lag = Get-WinForgeWindowsUpdateLag -Build ([int]$support.Build) } catch { $lag = $null }

        if ($lag -eq $true -and $paused) {
            $findings += New-WinForgeCheckupFinding -Id "updates" -Label $label -Value (Get-WinForgeText 'faltam atualizações de segurança; {0}' "$paused") -Level Warn `
                -Target "updates.windows" -Advice (Get-WinForgeText 'retome as atualizações em Atualizações > Windows Update')
        }
        elseif ($lag -eq $true) {
            $findings += New-WinForgeCheckupFinding -Id "updates" -Label $label -Value (Get-WinForgeText 'faltam atualizações de segurança') -Level Warn `
                -Target "updates.install" -Advice (Get-WinForgeText 'instale em Atualizações > Instalar atualizações do Windows')
        }
        elseif ($lag -eq $false) {
            $findings += $(if ($paused) { New-WinForgeCheckupFinding -Id "updates" -Label $label -Value (Get-WinForgeText 'nenhuma atualização de segurança atrasada; {0}' "$paused") -Level Info -Target "updates.windows" }
                else { New-WinForgeCheckupFinding -Id "updates" -Label $label -Value (Get-WinForgeText 'nenhuma atualização de segurança atrasada') -Level Ok })
        }
        elseif ($paused) {
            $findings += New-WinForgeCheckupFinding -Id "updates" -Label $label -Value $paused -Level Info -Target "updates.windows"
        }
    }

    if ($null -eq $issue) {
        $value = $(if ($support.State -eq "Supported") { (Get-WinForgeText '{0}: atualizações até {1}' "$($support.Product)" "$(Format-WinForgeDateTime -When $support.EndDate -Pattern 'dd/MM/yyyy')") } else { (Get-WinForgeText '{0}: data não conhecida' "$($support.Product)") })
        return @(@(New-WinForgeCheckupFinding -Id "windows" -Label (Get-WinForgeText 'Suporte do Windows') -Value $value -Level $(if ($support.State -eq "Supported") { "Ok" } else { "Info" })) + $findings)
    }

    $value = switch ([string]$support.State) {
        "EndingSoon" { $(if ([int]$support.DaysLeft -le 0) { (Get-WinForgeText 'atualizações só até hoje') } else { (Get-WinForgeText 'atualizações só até {0}' "$(Format-WinForgeDateTime -When $support.EndDate -Pattern 'dd/MM/yyyy')") }) }
        "Esu" { Get-WinForgeEsuText -Status $support }
        default {
            if ([string]$support.State -eq "EsuAvailable" -and -not [bool](Get-WinForgeJsonValue -Object $support -Name "EsuChecked" -Default $true)) { (Get-WinForgeText 'não foi possível conferir o ESU') }
            else { (Get-WinForgeText 'sem atualizações de segurança') }
        }
    }

    return @(@(New-WinForgeCheckupFinding -Id "windows" -Label (Get-WinForgeText 'Suporte do Windows') -Value "$($support.Product): $value" -Level Warn -Target "diagnostics.windows-support" -Advice (Get-WinForgeText 'veja o que fazer em Diagnóstico > Suporte do Windows')) + $findings)
}


function Get-WinForgeCheckupProtection {
    $protection = Get-WinForgeSecurityStatus

    if ($null -eq $protection) {
        return (New-WinForgeCheckupFinding -Id "protection" -Label (Get-WinForgeText 'Proteção') -Value (Get-WinForgeText 'não foi possível ler') -Level Info -Target "security.status" -Unread $true)
    }

    $antivirus = $protection.Antivirus

    # Os mesmos pontos da tela Estado da proteção, aonde a linha leva (Get-WinForgeSecurityFindings), com o nome curto de
    # cada um: "2 ameaças ativas", "antivírus desligado", "firewall desligado (Rede pública)". As assinaturas têm a linha
    # delas, logo abaixo, com a correção.
    $problems = @(Get-WinForgeSecurityFindings -Antivirus $antivirus -Firewall $protection.Firewall -Threats $protection.Threats |
            Where-Object { $_.Level -eq "Warning" -and [string]$_.Id -notlike "signatures*" -and -not [string]::IsNullOrWhiteSpace([string]$_.Short) } |
            ForEach-Object { [string]$_.Short })

    # O que não pôde ser lido (como na tela Estado da proteção e no Início): sem o firewall, ou sem as ameaças com o
    # Defender protegendo, "em dia" seria afirmar o que não foi visto. Unread: na frase da linha ("o firewall") e nas
    # listas da faixa ("Firewall"), como as etapas que não responderam.
    $unread = @()
    $unreadNames = @()
    if ($null -eq $protection.Firewall) { $unread += (Get-WinForgeText 'o firewall'); $unreadNames += (Get-WinForgeText 'Firewall') }
    if ($antivirus.Mode -eq "Active" -and $null -eq $protection.Threats) { $unread += (Get-WinForgeText 'as ameaças ativas'); $unreadNames += (Get-WinForgeText 'Ameaças ativas') }

    $findings = @()

    if ($problems.Count -gt 0) {
        $value = Join-WinForgeList -Items $problems
        if ($unread.Count -gt 0) { $value += (Get-WinForgeText '; não foi possível ler {0}' "$(Join-WinForgeList -Items $unread)") }

        $findings += New-WinForgeCheckupFinding -Id "protection" -Label (Get-WinForgeText 'Proteção') -Value $value -Level Warn -Target "security.status" -Advice (Get-WinForgeText 'veja em Segurança > Estado da proteção')
    }
    elseif ($unread.Count -gt 0) {
        # Sem nada pedindo atenção no que foi lido, o que faltou vai para a faixa ("Não foi possível ler: Firewall"): sem
        # isso, ela dizia "Tudo certo" em verde.
        $findings += New-WinForgeCheckupFinding -Id "protection" -Label (Get-WinForgeText 'Proteção') -Short (Join-WinForgeList -Items $unreadNames) -Value (Get-WinForgeText 'leitura incompleta: não foi possível ler {0}' "$(Join-WinForgeList -Items $unread)") -Level Info -Target "security.status" -Unread $true
    }

    $isAdmin = Test-WinForgeAdministrator

    # Os mesmos limites da tela Estado da proteção e do Início: mais de 7 dias (ou nunca atualizadas) pede atenção; de 4 a
    # 7, o Windows costuma atualizar sozinho (um notebook desligado num feriado), então é só informação, com a atualização
    # à mão e desmarcada.
    $never = [bool](Get-WinForgeJsonValue -Object $antivirus -Name "SignaturesNeverUpdated" -Default $false)

    if ($antivirus.Mode -eq "Active" -and ($never -or ($null -ne $antivirus.SignatureAgeDays -and [int]$antivirus.SignatureAgeDays -gt 3))) {
        $old = ($never -or [int]$antivirus.SignatureAgeDays -gt 7)
        $age = $(if ($never) { (Get-WinForgeText 'nunca atualizadas') } else { (Get-WinForgeText 'atualizadas há {0} dias' "$($antivirus.SignatureAgeDays)") })

        $findings += New-WinForgeCheckupFinding -Id "signatures" -Label (Get-WinForgeText 'Assinaturas do antivírus') -Value $age -Level $(if ($old) { "Warn" } else { "Info" }) `
            -Fix $(if ($isAdmin) { "signatures" } else { "" }) -FixLabel (Get-WinForgeText 'Atualizar as assinaturas do antivírus') -Selected ($isAdmin -and $old) -Target "security.signatures" `
            -Advice $(if ($isAdmin) { "" } elseif ($old) { (Get-WinForgeText 'atualize em Segurança > Atualizar assinaturas do antivírus') } else { "" })
    }

    if ($findings.Count -eq 0) {
        $findings += New-WinForgeCheckupFinding -Id "protection" -Label (Get-WinForgeText 'Proteção') -Value (Get-WinForgeText 'em dia') -Level Ok
    }

    return @($findings)
}


function Get-WinForgeCheckupReboot {
    if (Test-WinForgePendingReboot) {
        return (New-WinForgeCheckupFinding -Id "reboot" -Label (Get-WinForgeText 'Reinício pendente') -Value (Get-WinForgeText 'sim') -Level Warn -Target "diagnostics.pending-reboot" -Advice (Get-WinForgeText 'reinicie o PC quando puder; o motivo está em Diagnóstico > Reinício pendente'))
    }

    return (New-WinForgeCheckupFinding -Id "reboot" -Label (Get-WinForgeText 'Reinício pendente') -Value (Get-WinForgeText 'não') -Level Ok)
}


function Get-WinForgeCheckupBlueScreens {
    # As telas azuis dos últimos 30 dias (Get-WinForgeBlueScreens): com alguma, um ponto de atenção que leva à causa
    # provável em Diagnóstico > Telas azuis. Não há o que corrigir daqui.
    $screens = @(Get-WinForgeBlueScreens -Days 30)

    if ($screens.Count -eq 0) {
        return (New-WinForgeCheckupFinding -Id "bluescreens" -Label (Get-WinForgeText 'Telas azuis') -Value (Get-WinForgeText 'nenhuma nos últimos 30 dias') -Level Ok)
    }

    $count = Format-WinForgeCount -Count $screens.Count -One (Get-WinForgeText 'tela azul') -Many (Get-WinForgeText 'telas azuis')
    $about = Get-WinForgeBugCheckCauseText -Cause ([string](Get-WinForgeBlueScreenMainCause -Screens $screens).Cause)

    return (New-WinForgeCheckupFinding -Id "bluescreens" -Label (Get-WinForgeText 'Telas azuis') -Value (Get-WinForgeText '{0} nos últimos 30 dias; causa mais provável: {1}' "$count" "$($about.Cause)") -Level Warn `
            -Target "diagnostics.blue-screens" -Advice (Get-WinForgeText 'veja o que fazer em Diagnóstico > Telas azuis'))
}


function Invoke-WinForgeCheckupScan {
    <#
    Roda as etapas da verificação, uma por vez, com a barra de progresso. Uma etapa que falha vira um achado "não foi
    possível ler" e não interrompe as outras. A consulta do winget começa antes de todas e corre junto com elas
    (Start-WinForgeWingetUpgradeRead): na vez dela, a etapa dos programas só recebe a resposta. Devolve os achados.
    #>
    $steps = @(Get-WinForgeCheckupSteps)
    $findings = @()
    $position = 0
    $programs = $null

    $readers = @{
        disk        = { Get-WinForgeCheckupDisk }
        junk        = { Get-WinForgeCheckupJunk }
        registry    = { Get-WinForgeCheckupRegistry }
        shortcuts   = { Get-WinForgeCheckupShortcuts }
        memory      = { Get-WinForgeCheckupMemory }
        startup     = { Get-WinForgeCheckupStartup }
        programs    = { Get-WinForgeCheckupPrograms -Read $programs }
        windows     = { Get-WinForgeCheckupWindows }
        protection  = { Get-WinForgeCheckupProtection }
        reboot      = { Get-WinForgeCheckupReboot }
        bluescreens = { Get-WinForgeCheckupBlueScreens }
    }

    try {
        # Sem a consulta começada aqui, a etapa dos programas a começa na vez dela (e, se falhar de novo, fica não lida).
        try { $programs = Start-WinForgeWingetUpgradeRead } catch { Write-Verbose "Verificar o PC, programas: $($_.Exception.Message)" }

        foreach ($step in $steps) {
            Write-Progress -Activity (Get-WinForgeText 'Verificando o PC') -Status (Get-WinForgeText '{0} de {1}: {2}' "$($position + 1)" "$($steps.Count)" "$($step.Text)") -PercentComplete ([int]($position * 100 / $steps.Count))
            $position++

            try {
                $read = @(& $readers[$step.Id] | Where-Object { $null -ne $_ })
            }
            catch {
                Write-Verbose "Verificar o PC, $($step.Id): $($_.Exception.Message)"
                $read = @(New-WinForgeCheckupFinding -Id $step.Id -Label $step.Label -Value (Get-WinForgeText 'não foi possível ler') -Level Info -Unread $true)
            }

            # A etapa de cada achado: o veredito conta etapas lidas, não achados (a limpeza e a proteção dão mais de um).
            foreach ($finding in $read) { Add-Member -InputObject $finding -NotePropertyName StepId -NotePropertyValue $step.Id -Force }

            $findings += $read
        }
    }
    finally {
        # Parada no meio (o Parar), a consulta do winget que ninguém vai receber não fica rodando.
        Stop-WinForgeInBackground -Task $programs
        Write-Progress -Activity (Get-WinForgeText 'Verificando o PC') -Completed
    }

    return @($findings)
}


function Invoke-WinForgeCheckupFix {
    # Aplica uma correção e devolve um WinForge.Result (Etapa = o rótulo da correção; Data.FreedBytes quando libera espaço).
    param ([Parameter(Mandatory)]$Finding)

    switch ($Finding.Fix) {
        { $_ -in "junk", "browser" } {
            $result = Invoke-WinForgeCleanupTargets -Targets @($Finding.Data) -NoSummary

            # Nada liberado e alguma parte com problema (tudo em uso, uma pasta recusada): a limpeza não aconteceu, e
            # contá-la como "correção feita" escondia isso na faixa.
            $cleaned = Get-WinForgeResultData -Result $result -Name "FreedBytes"

            if ($result.Kind -eq "Warning" -and ($null -eq $cleaned -or [int64]$cleaned -le 0)) {
                $result = New-WinForgeResult -Kind Failed -Detail $result.Detail -Data $result.Data
            }
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
                    [void](Add-WinForgeChange -Action (Get-WinForgeText 'Atalhos quebrados') -Text $(if ($moved.Count -eq 1) { (Get-WinForgeText '{0} foi para a Lixeira' "$(Join-WinForgeList -Items $moved)") } else { (Get-WinForgeText '{0} foram para a Lixeira' "$(Join-WinForgeList -Items $moved)") }))
                }
            }

            $text = Format-WinForgeCount -Count $moved.Count -One (Get-WinForgeText 'atalho foi para a Lixeira') -Many (Get-WinForgeText 'atalhos foram para a Lixeira')
            $result = $(if ($failed -eq 0) { New-WinForgeResult -Kind Ok -Detail $text } elseif ($moved.Count -eq 0) { New-WinForgeResult -Kind Failed -Detail (Get-WinForgeText 'nenhum atalho foi removido') } else { New-WinForgeResult -Kind Warning -Detail (Get-WinForgeText '{0}; {1} não' "$text" "$failed") })
        }
        "signatures" {
            $result = Update-WinForgeDefenderSignatures -Embedded -PassThru
        }
        default {
            $result = New-WinForgeResult -Kind Failed -Detail (Get-WinForgeText 'correção desconhecida')
        }
    }

    $result.Etapa = $Finding.FixLabel

    return $result
}


function Get-WinForgeCheckupWeight {
    <#
    O peso de um ponto de atenção, para a ordem das listas e o botão da faixa: o que põe os arquivos ou o PC em risco (um
    disco falhando, a proteção, as atualizações de segurança) vem antes do que só deixa o PC mais lento ou mais cheio. Os
    mesmos pesos do Início onde a nota de saúde tem o ponto (Home.psm1): a proteção, o disco quase cheio ou com pouco
    espaço, as atualizações de segurança, as assinaturas e o reinício.
    #>
    param ([Parameter(Mandatory)]$Finding)

    switch ([string]$Finding.Id) {
        "disk-health" { return 35 }
        "protection" { return 30 }
        "disk" { return $(if ([string]$Finding.Data -eq "Critical") { 25 } else { 12 }) }
        "updates" { return 20 }
        "windows" { return 20 }
        "bluescreens" { return 15 }
        "signatures" { return 10 }
        "reboot" { return 8 }
        "programs" { return 6 }
        "memory" { return 5 }
        "startup" { return 4 }
        "junk" { return 3 }
        "shortcuts" { return 2 }
        default { return 1 }
    }
}


function Get-WinForgeCheckupOrder {
    # Os pontos do mais importante ao menos (Get-WinForgeCheckupWeight); no mesmo peso, na ordem das etapas.
    param ([object[]]$Findings = @())

    $position = 0
    $ranked = @(foreach ($finding in @($Findings | Where-Object { $null -ne $_ })) {
            $position++
            [PSCustomObject]@{ Finding = $finding; Weight = (Get-WinForgeCheckupWeight -Finding $finding); Position = $position }
        })

    return @($ranked | Sort-Object -Property @{ Expression = "Weight"; Descending = $true }, @{ Expression = "Position"; Descending = $false } | ForEach-Object { $_.Finding })
}


function Format-WinForgeCheckupReason {
    # O motivo de uma correção que não deu certo, para depois de "Nome: " na faixa: legível, sem o ponto final e com a
    # primeira letra minúscula (menos numa sigla). Longo demais (a faixa tem 220 letras para tudo), fica a primeira parte
    # ("nada foi liberado", sem a lista das pastas) ou nada, e a frase diz só o nome: o motivo inteiro continua no resumo.
    param ([AllowEmptyString()][AllowNull()][string]$Text)

    $why = ([string](ConvertTo-WinForgeReadableError -Text $Text)).Trim().TrimEnd('.').Trim()

    if ($why.Length -gt 90) { $why = ($why -split ';')[0].Trim() }
    if (-not $why -or $why.Length -gt 90) { return "" }

    if ($why.Length -gt 1 -and [char]::IsUpper($why[0]) -and -not [char]::IsUpper($why[1])) {
        $why = $why.Substring(0, 1).ToLowerInvariant() + $why.Substring(1)
    }

    return $why
}


function Set-WinForgeCheckupView {
    <#
    Como a janela mostra o fim da verificação. O título da faixa diz o que aconteceu ("3 correções feitas, 1,9 GB
    liberados", "Nenhuma correção funcionou", "2 pontos pedem você", "Nada pedindo atenção no que foi lido"); a frase
    embaixo, a correção que deu problema e por quê, o que ainda pede a pessoa e o que não foi lido. Os pontos vêm do mais
    importante ao menos (Get-WinForgeCheckupWeight), e o botão da faixa leva à tela do primeiro deles. O console continua
    com o Detail.
    Problems: as correções que falharam ou ficaram pela metade, cada uma com Finding e Result. -NotRead: a maior parte das
    etapas não respondeu.
    #>
    param (
        [Parameter(Mandatory)]$Result,
        [object[]]$Results = @(),
        [int]$Failed = 0,
        [int64]$Freed = 0,
        [object[]]$Remaining = @(),
        [object[]]$Problems = @(),
        [AllowEmptyString()][string]$Unread = "",
        [switch]$Declined,
        [switch]$NotRead
    )

    if ($NotRead) {
        return (Set-WinForgeResultView -Result $Result -Headline (Get-WinForgeText 'Não foi possível verificar o PC') `
                -Note (Get-WinForgeText 'Não foi possível ler a maior parte do PC: tente de novo; se continuar, reinicie o PC.'))
    }

    $troubled = @($Problems | Where-Object { $null -ne $_ -and $null -ne $_.Finding })
    $troubledIds = @($troubled | ForEach-Object { [string]$_.Finding.Id })

    # O que ainda pede a pessoa, sem as correções que deram problema: essas vêm à parte, com o motivo.
    $still = @(Get-WinForgeCheckupOrder -Findings @($Remaining | Where-Object { $null -ne $_ -and $troubledIds -notcontains [string]$_.Id }))

    $next = ""
    $nextLabel = ""
    $first = @(Get-WinForgeCheckupOrder -Findings @(@($troubled | ForEach-Object { $_.Finding }) + @($still)) | Where-Object { -not [string]::IsNullOrEmpty([string]$_.Target) }) | Select-Object -First 1

    if ($null -ne $first) {
        try {
            $item = Get-WinForgeNavItem -Id ([string]$first.Target)
            if ($null -ne $item) { $next = [string]$item.Id; $nextLabel = [string]$item.Label }
        }
        catch {
            Write-Verbose "Próximo passo da verificação: $($_.Exception.Message)"
        }
    }

    $done = @($Results).Count - $Failed
    $headline = ""
    $notes = @()

    if (@($Results).Count -gt 0 -and $done -le 0) {
        $headline = (Get-WinForgeText 'Nenhuma correção funcionou')
    }
    elseif (@($Results).Count -gt 0) {
        $headline = Format-WinForgeCount -Count $done -One (Get-WinForgeText 'correção feita') -Many (Get-WinForgeText 'correções feitas')
        if ($Freed -gt 0) { $headline += (Get-WinForgeText ', {0} liberados' "$(Format-WinForgeBytes -Bytes $Freed)") }
    }
    elseif ($Declined) {
        $headline = (Get-WinForgeText 'Nenhuma correção feita')
    }
    elseif ($still.Count -gt 0) {
        $headline = Format-WinForgeCount -Count $still.Count -One (Get-WinForgeText 'ponto pede você') -Many (Get-WinForgeText 'pontos pedem você')
    }
    elseif (-not [string]::IsNullOrWhiteSpace($Unread)) {
        # Tudo o que foi lido está em dia, mas não tudo foi lido: "Tudo certo" afirmaria o que não foi visto.
        $headline = (Get-WinForgeText 'Nada pedindo atenção no que foi lido')
    }
    else {
        return $Result
    }

    # A correção que deu problema: com uma só, o motivo; com mais, os nomes (os motivos ficam no resumo).
    if ($troubled.Count -eq 1) {
        $why = Format-WinForgeCheckupReason -Text ([string]$troubled[0].Result.Detail)
        $notes += $(if ($why) { (Get-WinForgeText '{0}: {1}' "$($troubled[0].Finding.Short)" "$why") } else { (Get-WinForgeText 'Com problema: {0}' "$($troubled[0].Finding.Short)") })
    }
    elseif ($troubled.Count -gt 1) {
        $notes += (Get-WinForgeText 'Com problema: {0}' "$(Join-WinForgeShortList -Items @($troubled | ForEach-Object { [string]$_.Finding.Short }))")
    }

    if ($still.Count -gt 0) {
        # Os nomes curtos, do mais importante ao menos; numa lista longa, os primeiros e "e mais N", para a frase não
        # cortar no meio o que vem depois (o que não foi lido).
        $names = Join-WinForgeShortList -Items @($still | ForEach-Object { [string]$_.Short })

        if (@($Results).Count -gt 0 -or $Declined) {
            $notes += $(if ($still.Count -eq 1) { (Get-WinForgeText 'Ainda pede você: {0}' "$names") } else { (Get-WinForgeText 'Ainda pedem você: {0}' "$names") })
        }
        elseif ($still.Count -eq 1) {
            # Um ponto só: o que ele é, e não só o nome ("Proteção: 2 ameaças ativas e antivírus desligado").
            $notes += (Get-WinForgeText '{0}: {1}' "$($still[0].Label)" "$($still[0].Value)")
        }
        else {
            $notes += $names
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($Unread)) { $notes += (Get-WinForgeText 'Não foi possível ler: {0}' "$Unread") }
    if ($notes.Count -eq 0) { $notes += (Get-WinForgeText 'Nada mais pedindo atenção') }

    return (Set-WinForgeResultView -Result $Result -Headline $headline -Note "$($notes -join '. ')." -Next $next -NextLabel $nextLabel)
}


function Invoke-WinForgeCheckup {
    $title = (Get-WinForgeText 'Verificar o PC')

    Enter-WinForgeAction -Title $title

    $final = New-WinForgeResult -Kind Ok -Title $title

    try {
        $findings = @(Invoke-WinForgeCheckupScan)

        Write-WinForgeSection -Title (Get-WinForgeText 'O que a verificação encontrou')

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

        # A informação com orientação própria e sem correção daqui (atalhos quebrados só no OneDrive) diz onde ver, sem
        # pedir nada: sem a linha, a orientação não aparecia em lugar nenhum.
        $hints = @($findings | Where-Object { $_.Level -eq "Info" -and -not $_.Fix -and $_.Advice -and -not [bool](Get-WinForgeJsonValue -Object $_ -Name "Unread" -Default $false) })

        foreach ($finding in $hints) {
            Write-WinForgeStatus -Type Info -Message "$($finding.Label): $($finding.Advice)."
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
        $unreadText = Join-WinForgeList -Items @($unreadFindings | ForEach-Object { [string]$_.Short })

        $results = @()
        # Cada correção feita, com o ponto dela: a faixa diz pelo nome do ponto qual deu problema.
        $pairs = @()
        $fixedIds = @()
        $freed = [int64]0
        # A pessoa cancelou a lista de correções: o veredito é o da verificação, sem conta como cuidado com o PC.
        $declined = $false

        if ($fixable.Count -gt 0) {
            if ($manual.Count + $hints.Count -gt 0) { Write-Host "" }

            if ($safe.Count -gt 0) {
                # Só o que está de fato marcado na lista: falar do registro ou dos atalhos quando eles nem aparecem confunde.
                $why = @{
                    junk       = (Get-WinForgeText 'os temporários o Windows recria')
                    registry   = (Get-WinForgeText 'o registro tem backup e volta em Manutenção > Histórico de mudanças')
                    shortcuts  = (Get-WinForgeText 'os atalhos vão para a Lixeira')
                    signatures = (Get-WinForgeText 'as assinaturas só são atualizadas')
                }
                $reasons = @($safe | Where-Object { $why.ContainsKey([string]$_.Fix) } | ForEach-Object { $why[[string]$_.Fix] } | Select-Object -Unique)
                $message = $(if ($reasons.Count -gt 0) { (Get-WinForgeText 'O que vem marcado é seguro: {0}.' "$(Join-WinForgeList -Items $reasons)") } else { (Get-WinForgeText 'O que vem marcado é seguro de corrigir.') })

                Write-WinForgeStatus -Type Info -Message $message
            }
            else {
                Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Nada desta lista é necessário: marque só o que quiser fazer agora.')
            }

            Write-Host ""

            $options = @(
                foreach ($finding in $fixable) {
                    $description = $finding.Value
                    if ($finding.Advice) { $description += " · $($finding.Advice)" }
                    @{ Key = $finding.Id; Label = $finding.FixLabel; Description = $description; Selected = [bool]$finding.Selected }
                }
            )

            try {
                $picked = Read-WinForgeMultiSelect -Message (Get-WinForgeText 'O que corrigir agora?') -Options $options -ConfirmLabel (Get-WinForgeText 'Corrigir') -CancelLabel (Get-WinForgeText 'Agora não')
            }
            catch {
                # No menu de texto, respostas que não valem até o limite: é não corrigir nada, e não um erro da verificação
                # (o que ela achou continua na tela e na faixa).
                Write-Verbose "Lista do que corrigir sem resposta: $($_.Exception.Message)"
                $picked = $null
            }

            # Com correções seguras na lista, não escolher nada é cancelar as correções, mas não a verificação: o que ela
            # achou continua na tela e na faixa (um antivírus desligado não pode sumir num "Operação cancelada"). Só com o
            # que é opcional (o cache dos navegadores, por exemplo), é a resposta "não, obrigado".
            if (($null -eq $picked -or @($picked).Count -eq 0) -and $safe.Count -gt 0) {
                $declined = $true
                Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Nenhuma correção foi feita.')
            }

            $chosen = @($fixable | Where-Object { $null -ne $picked -and @($picked) -contains $_.Id })
            $position = 0

            foreach ($finding in $chosen) {
                Write-Progress -Activity (Get-WinForgeText 'Corrigindo') -Status (Get-WinForgeText '{0} de {1}: {2}' "$($position + 1)" "$($chosen.Count)" "$($finding.FixLabel)") -PercentComplete ([int]($position * 100 / $chosen.Count))
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
                $pairs += [PSCustomObject]@{ Finding = $finding; Result = $result }
            }

            if ($chosen.Count -gt 0) {
                Write-Progress -Activity (Get-WinForgeText 'Corrigindo') -Completed

                Write-WinForgeSection -Title (Get-WinForgeText 'Resumo')
                Write-WinForgeResultTable -Results $results

                if ($freed -gt 0) {
                    Write-WinForgeKeyValue -Label (Get-WinForgeText 'Espaço liberado') -Value (Format-WinForgeBytes -Bytes $freed) -Level Ok

                    # Com espaço liberado, o disco é lido de novo: "ainda pede atenção: Espaço no disco" com ele já acima do
                    # limite seria falso. Sem leitura agora, fica o que a verificação viu.
                    $diskFinding = @($attention | Where-Object { [string]$_.Id -eq "disk" }) | Select-Object -First 1

                    if ($null -ne $diskFinding) {
                        try {
                            $now = Get-WinForgeCheckupDiskSpace

                            if ($null -ne $now -and -not [bool]$now.Unread) {
                                $diskFinding.Value = $now.Value
                                $diskFinding.Data = $now.Data
                                Write-WinForgeKeyValue -Label $now.Label -Value $now.Value -Level $now.Level
                                if ($now.Level -eq "Ok") { $fixedIds += "disk" }
                            }
                        }
                        catch {
                            Write-Verbose "Espaço no disco depois das correções: $($_.Exception.Message)"
                        }
                    }
                }
            }
        }

        $failed = @($results | Where-Object { $_.Kind -eq "Failed" })
        $warned = @($results | Where-Object { $_.Kind -eq "Warning" })
        $problems = @($pairs | Where-Object { $_.Result.Kind -in @("Failed", "Warning") })

        # O que continua pedindo atenção: tudo o que foi apontado e não foi corrigido (por escolha, ou porque a correção
        # falhou), do mais importante ao menos. Sem isso, "1 correção feita" em verde esconderia um antivírus desligado.
        $remaining = @(Get-WinForgeCheckupOrder -Findings @($attention | Where-Object { $fixedIds -notcontains $_.Id }))

        if ($scanRead -and -not $declined -and ($results.Count -eq 0 -or $failed.Count -lt $results.Count)) {
            [void](Set-WinForgeSetting -Name "LastCheckup" -Value (Get-Date).ToString("s", [System.Globalization.CultureInfo]::InvariantCulture))
        }

        $data = @{ FreedBytes = $freed }

        if ($results.Count -eq 0 -and -not $scanRead) {
            Write-WinForgeStatus -Type Error -Message (Get-WinForgeText 'Não foi possível ler a maior parte do PC: tente de novo; se continuar, reinicie o PC.')
            $final = New-WinForgeResult -Kind Failed -Detail (Get-WinForgeText 'não foi possível ler a maior parte do PC') -Title $title
            $final = Set-WinForgeCheckupView -Result $final -NotRead
        }
        elseif ($results.Count -gt 0 -and $failed.Count -eq $results.Count) {
            $final = New-WinForgeResult -Kind Failed -Detail (Get-WinForgeText 'nenhuma correção funcionou') -Title $title -Data $data
            $final = Set-WinForgeCheckupView -Result $final -Results $results -Failed $failed.Count -Remaining $remaining -Problems $problems -Unread $unreadText
        }
        else {
            $parts = @()

            if ($results.Count -gt 0) {
                $done = Format-WinForgeCount -Count ($results.Count - $failed.Count) -One (Get-WinForgeText 'correção feita') -Many (Get-WinForgeText 'correções feitas')
                $parts += $(if ($freed -gt 0) { (Get-WinForgeText '{0}; {1} liberados' "$done" "$(Format-WinForgeBytes -Bytes $freed)") } else { $done })
            }
            elseif ($declined) {
                $parts += (Get-WinForgeText 'nenhuma correção feita')
            }

            if ($problems.Count -gt 0) {
                $parts += (Get-WinForgeText '{0} com problema' "$(Join-WinForgeList -Items @($problems | ForEach-Object { [string]$_.Finding.Short }))")
            }

            if ($remaining.Count -gt 0) {
                # A faixa diz o que pede atenção pelo nome (um "2 pontos pedem a sua decisão" não diz quais).
                $still = ($results.Count -gt 0 -or $declined)
                $names = Join-WinForgeList -Items @($remaining | ForEach-Object { [string]$_.Short })
                $parts += $(
                    if ($still -and $remaining.Count -eq 1) { (Get-WinForgeText 'ainda pede atenção: {0}' "$names") }
                    elseif ($still) { (Get-WinForgeText 'ainda pedem atenção: {0}' "$names") }
                    elseif ($remaining.Count -eq 1) { (Get-WinForgeText 'pede atenção: {0}' "$names") }
                    else { (Get-WinForgeText 'pedem atenção: {0}' "$names") }
                )

                if ($results.Count -gt 0 -or $declined) {
                    # O que fazer com cada um que tem orientação e ainda não a mostrou (os sem correção já a mostraram
                    # antes da lista): a memória, por exemplo, só tinha a dica dentro da lista de marcar.
                    foreach ($finding in @($remaining | Where-Object { $_.Fix -and $_.Advice })) {
                        Write-WinForgeStatus -Type Warning -Message "$($finding.Label): $($finding.Advice)."
                    }

                    Write-WinForgeStatus -Type Warning -Message $(if ($remaining.Count -eq 1) { (Get-WinForgeText 'Ainda pede atenção: {0}.' "$names") } else { (Get-WinForgeText 'Ainda pedem atenção: {0}.' "$names") })
                }
            }

            if ($unreadFindings.Count -gt 0) { $parts += (Get-WinForgeText 'não foi possível ler: {0}' "$unreadText") }

            if ($parts.Count -eq 0) {
                Write-WinForgeStatus -Type Success -Message (Get-WinForgeText 'Nada pedindo atenção.')
                $parts += (Get-WinForgeText 'nada pedindo atenção')
            }
            elseif ($results.Count -eq 0 -and $remaining.Count -eq 0) {
                Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'Nada pedindo atenção no que foi lido; não foi possível ler: {0}.' "$unreadText")
                $parts = @((Get-WinForgeText 'nada pedindo atenção no que foi lido; não foi possível ler: {0}' "$unreadText"))
            }

            $clean = ($failed.Count -eq 0 -and $warned.Count -eq 0 -and $remaining.Count -eq 0 -and $unreadFindings.Count -eq 0)
            $final = New-WinForgeResult -Kind $(if ($clean) { "Ok" } else { "Warning" }) -Detail ($parts -join "; ") -Title $title -Data $data
            $final = Set-WinForgeCheckupView -Result $final -Results $results -Failed $failed.Count -Freed $freed -Remaining $remaining -Problems $problems -Unread $unreadText -Declined:$declined
        }
    }
    catch {
        Write-Progress -Activity (Get-WinForgeText 'Verificando o PC') -Completed
        Write-WinForgeStatus -Type Error -Message (Get-WinForgeText 'Não foi possível verificar o PC: {0}.' "$($_.Exception.Message.TrimEnd('.'))")
        $final = New-WinForgeResult -Kind Failed -Detail $_.Exception.Message.TrimEnd('.') -Title $title
        $final = Set-WinForgeResultView -Result $final -Headline (Get-WinForgeText 'Não foi possível verificar o PC') -Note (Format-WinForgeReasonNote -Text $_.Exception.Message)
    }

    Exit-WinForgeAction -Result $final
}


Export-ModuleMember -Function *
