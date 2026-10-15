# Navegação: a única tabela com as páginas e ações do WinForge. A barra lateral da janela e os menus do console
# leem daqui, então a ordem e os nomes nunca ficam diferentes entre as duas interfaces.
#
# Ordem das páginas: primeiro o caminho guiado (Manutenção); depois as ferramentas manuais na sequência natural de
# quem cuida de um PC: olhar o estado, limpar, consertar, atualizar, instalar programas, conferir a rede e, por fim,
# personalizar. A página do próprio WinForge fica no rodapé da barra lateral (Placement = Footer).
#
# Nomes: o rótulo de uma ação é o mesmo texto do título que ela mostra ao abrir (um teste confere), para que o botão
# clicado e a tela aberta nunca tenham nomes diferentes. Ações usam verbo no infinitivo; telas de consulta usam o
# nome do que mostram; atalhos para o Windows usam o nome do painel e a descrição começa com "Abre".
# Dentro de cada página a ordem vai do mais seguro (só olhar) ao que mexe mais fundo no sistema.

$script:WinForgeNavigation = $null


function New-WinForgeNavItem {
    # Kind = Action (executa uma função do WinForge) ou Shortcut (abre uma janela do Windows).
    param (
        [Parameter(Mandatory)][string]$Id,
        [Parameter(Mandatory)][string]$Label,
        [Parameter(Mandatory)][string]$Description,
        [string]$Command = "",
        [string]$Shortcut = "",
        [switch]$Accent
    )

    return [PSCustomObject]@{
        Id          = $Id
        Label       = $Label
        Description = $Description
        Kind        = $(if ([string]::IsNullOrEmpty($Shortcut)) { "Action" } else { "Shortcut" })
        Command     = $Command
        Shortcut    = $Shortcut
        Accent      = [bool]$Accent
    }
}


function New-WinForgeNavPage {
    # Kind = List (cartões) ou Tweaks (lista de interruptores montada a partir do catálogo de ajustes; os Items são a
    # barra de ações da página). Placement = Main (lista principal da barra lateral) ou Footer (rodapé).
    param (
        [Parameter(Mandatory)][string]$Id,
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][string]$Summary,
        [object[]]$Items = @(),
        [ValidateSet("List", "Tweaks")]
        [string]$Kind = "List",
        [ValidateSet("Main", "Footer")]
        [string]$Placement = "Main"
    )

    return [PSCustomObject]@{
        Id        = $Id
        Title     = $Title
        Summary   = $Summary
        Kind      = $Kind
        Placement = $Placement
        Items     = @($Items)
    }
}


function Get-WinForgeNavigation {
    if ($null -ne $script:WinForgeNavigation) {
        return $script:WinForgeNavigation
    }

    $pages = @()

    $pages += New-WinForgeNavPage -Id "maintenance" -Title "Manutenção" -Summary "O caminho guiado, a rede de segurança e a manutenção automática." -Items @(
        (New-WinForgeNavItem -Id "maintenance.recommended" -Label "Manutenção recomendada" -Accent `
            -Description "Fluxo guiado: você escolhe o plano, o WinForge executa e mostra o resumo" -Command "Invoke-WinForgeRecommendedMaintenance"),
        (New-WinForgeNavItem -Id "maintenance.restore-point" -Label "Criar ponto de restauração" `
            -Description "Um ponto para voltar atrás se algo der errado; recomendado antes de mexer no sistema" -Command "Invoke-WinForgeRestorePoint"),
        (New-WinForgeNavItem -Id "maintenance.restore" -Label "Restauração do Sistema" `
            -Description "Abre a Restauração do Sistema do Windows, para voltar o PC a um ponto de restauração" -Shortcut "SystemRestore"),
        (New-WinForgeNavItem -Id "maintenance.schedule" -Label "Manutenção agendada" `
            -Description "Opcional: uma limpeza leve e um relatório todo mês, sozinhos; você remove quando quiser" -Command "Show-WinForgeScheduledMaintenance"),
        (New-WinForgeNavItem -Id "maintenance.task-scheduler" -Label "Agendador de Tarefas" `
            -Description "Abre o Agendador de Tarefas do Windows, onde a tarefa do WinForge aparece" -Shortcut "TaskScheduler")
    )

    $pages += New-WinForgeNavPage -Id "diagnostics" -Title "Diagnóstico" -Summary "Veja como o PC está antes de mexer em qualquer coisa." -Items @(
        (New-WinForgeNavItem -Id "diagnostics.about" -Label "Sobre este PC" -Accent `
            -Description "Processador, memória, vídeo, discos e EXPO/XMP" -Command "Show-WinForgeSystemInfo"),
        (New-WinForgeNavItem -Id "diagnostics.disks" -Label "Discos e espaço livre" `
            -Description "SSD ou HDD, espaço livre e uso de cada unidade" -Command "Show-WinForgeDisks"),
        (New-WinForgeNavItem -Id "diagnostics.disk-health" -Label "Saúde dos discos" `
            -Description "Estado, temperatura e desgaste" -Command "Show-WinForgeDiskHealth"),
        (New-WinForgeNavItem -Id "diagnostics.battery" -Label "Saúde da bateria" `
            -Description "Capacidade de hoje comparada à de fábrica, ciclos de carga e carga atual" -Command "Show-WinForgeBatteryHealth"),
        (New-WinForgeNavItem -Id "diagnostics.events" -Label "Eventos críticos (7 dias)" `
            -Description "Quedas de energia, tela azul, erros de disco e de hardware" -Command "Show-WinForgeCriticalEvents"),
        (New-WinForgeNavItem -Id "diagnostics.devices" -Label "Dispositivos com problema" `
            -Description "Drivers e hardware com erro" -Command "Show-WinForgeProblemDevices"),
        (New-WinForgeNavItem -Id "diagnostics.startup" -Label "Inicialização e energia" `
            -Description "Tempo ligado, Inicialização Rápida e hibernação" -Command "Show-WinForgeStartupInfo"),
        (New-WinForgeNavItem -Id "diagnostics.pending-reboot" -Label "Reinício pendente" `
            -Description "O que está esperando um reinício e se ele é mesmo necessário" -Command "Show-WinForgePendingReboot"),
        (New-WinForgeNavItem -Id "diagnostics.report" -Label "Exportar relatório" `
            -Description "Salva um relatório em HTML e texto: sistema, hardware, discos, ajustes, eventos, segurança e última manutenção" -Command "Invoke-WinForgeReport"),
        (New-WinForgeNavItem -Id "diagnostics.device-manager" -Label "Gerenciador de Dispositivos" `
            -Description "Abre o Gerenciador de Dispositivos do Windows" -Shortcut "DeviceManager"),
        (New-WinForgeNavItem -Id "diagnostics.reliability" -Label "Monitor de Confiabilidade" `
            -Description "Abre o histórico de falhas do Windows" -Shortcut "Reliability")
    )

    $pages += New-WinForgeNavPage -Id "security" -Title "Segurança" -Summary "Veja se o PC está protegido e rode a verificação do Windows." -Items @(
        (New-WinForgeNavItem -Id "security.status" -Label "Estado da proteção" -Accent `
            -Description "Antivírus, assinaturas, firewall, atualizações pendentes e ameaças ativas" -Command "Show-WinForgeSecurityStatus"),
        (New-WinForgeNavItem -Id "security.signatures" -Label "Atualizar assinaturas do antivírus" `
            -Description "Baixa as definições mais recentes do Windows Defender" -Command "Update-WinForgeDefenderSignatures"),
        (New-WinForgeNavItem -Id "security.quick-scan" -Label "Verificação rápida" `
            -Description "O Windows Defender examina os locais mais comuns de ameaças, em alguns minutos" -Command "Start-WinForgeQuickScan"),
        (New-WinForgeNavItem -Id "security.full-scan" -Label "Verificação completa" `
            -Description "O Windows Defender examina todos os arquivos; pode levar horas" -Command "Start-WinForgeFullScan"),
        (New-WinForgeNavItem -Id "security.folder-scan" -Label "Verificar uma pasta" `
            -Description "O Windows Defender examina só a pasta ou o arquivo que você indicar" -Command "Start-WinForgeFolderScan"),
        (New-WinForgeNavItem -Id "security.windows-security" -Label "Segurança do Windows" `
            -Description "Abre o aplicativo do Windows, com a verificação offline e o histórico de proteção" -Shortcut "WindowsSecurity")
    )

    $pages += New-WinForgeNavPage -Id "cleanup" -Title "Limpeza" -Summary "Libere espaço, do mais seguro ao mais profundo." -Items @(
        (New-WinForgeNavItem -Id "cleanup.quick" -Label "Limpeza rápida" -Accent `
            -Description "Temporários do usuário e do Windows, mais a Lixeira" -Command "Invoke-WinForgeQuickCleanup"),
        (New-WinForgeNavItem -Id "cleanup.user-temp" -Label "Limpar temporários do usuário" `
            -Description "Esvazia a pasta Temp do seu perfil" -Command "Clear-WinForgeUserTemp"),
        (New-WinForgeNavItem -Id "cleanup.windows-temp" -Label "Limpar temporários do Windows" `
            -Description "Esvazia a pasta Temp do sistema" -Command "Clear-WinForgeWindowsTemp"),
        (New-WinForgeNavItem -Id "cleanup.recycle-bin" -Label "Esvaziar a Lixeira" `
            -Description "Remove em definitivo o que está na Lixeira, de todas as unidades" -Command "Clear-WinForgeRecycleBin"),
        (New-WinForgeNavItem -Id "cleanup.downloads" -Label "Limpar a pasta Downloads" `
            -Description "Você vê uma prévia, filtra por idade e escolhe entre a Lixeira e a exclusão" -Command "Clear-WinForgeDownloads"),
        (New-WinForgeNavItem -Id "cleanup.components" -Label "Limpar componentes do Windows (WinSxS)" `
            -Description "Remove versões antigas de componentes substituídos por atualizações (DISM)" -Command "Invoke-WinForgeComponentCleanup"),
        (New-WinForgeNavItem -Id "cleanup.storage" -Label "Configurações de armazenamento" `
            -Description "Abre as Configurações do Windows, onde fica o Sensor de Armazenamento" -Shortcut "Storage")
    )

    $pages += New-WinForgeNavPage -Id "repair" -Title "Reparo" -Summary "Conserte o Windows e o disco, e mantenha a unidade em forma." -Items @(
        (New-WinForgeNavItem -Id "repair.dism-sfc" -Label "Reparar o Windows (DISM + SFC)" -Accent `
            -Description "DISM e depois SFC, na ordem certa; não apaga arquivos pessoais" -Command "Invoke-WinForgeDismAndSfc"),
        (New-WinForgeNavItem -Id "repair.dism" -Label "Reparar imagem e componentes (DISM)" `
            -Description "Corrige a imagem do Windows usando o Windows Update; leva vários minutos" -Command "Invoke-WinForgeDism"),
        (New-WinForgeNavItem -Id "repair.sfc" -Label "Verificar arquivos do sistema (SFC)" `
            -Description "Confere os arquivos protegidos do Windows e repara o que estiver errado" -Command "Invoke-WinForgeSfc"),
        (New-WinForgeNavItem -Id "repair.chkdsk" -Label "Verificar o sistema de arquivos (CHKDSK)" `
            -Description "Verifica o disco sem reiniciar; o reparo offline só com a sua confirmação" -Command "Start-WinForgeChkdsk"),
        (New-WinForgeNavItem -Id "repair.device-scan" -Label "Detectar dispositivos e drivers" `
            -Description "Procura hardware novo e instala os drivers que já estejam disponíveis" -Command "Invoke-WinForgeDeviceScan"),
        (New-WinForgeNavItem -Id "repair.optimize" -Label "Otimizar a unidade do sistema" `
            -Description "TRIM em SSD ou desfragmentação em HDD" -Command "Start-WinForgeDriveOptimization")
    )

    $pages += New-WinForgeNavPage -Id "updates" -Title "Atualizações" -Summary "Windows, drivers, Microsoft Store e programas." -Items @(
        (New-WinForgeNavItem -Id "updates.windows" -Label "Windows Update" `
            -Description "Abre o Windows Update nas Configurações do Windows" -Shortcut "WindowsUpdate"),
        (New-WinForgeNavItem -Id "updates.optional" -Label "Atualizações opcionais e drivers" `
            -Description "Abre as atualizações opcionais nas Configurações do Windows" -Shortcut "OptionalUpdates"),
        (New-WinForgeNavItem -Id "updates.store" -Label "Atualizações da Microsoft Store" `
            -Description "Abre a página de atualizações da Microsoft Store" -Shortcut "MicrosoftStore"),
        (New-WinForgeNavItem -Id "updates.winget" -Label "Atualizar programas (winget)" -Accent `
            -Description "Você vê a lista e escolhe o que atualizar" -Command "Update-WinForgeSoftware")
    )

    $pages += New-WinForgeNavPage -Id "software" -Title "Programas" -Summary "Instale, remova e organize o que roda no PC." -Items @(
        (New-WinForgeNavItem -Id "software.essentials" -Label "Instalar programas essenciais" -Accent `
            -Description "Escolha numa lista de programas comuns, como navegadores, 7-Zip, VLC e Git" -Command "Install-WinForgeEssentialSoftware"),
        (New-WinForgeNavItem -Id "software.find" -Label "Buscar e instalar programas" `
            -Description "Pesquisa no winget e instala o que você marcar" -Command "Find-WinForgeSoftware"),
        (New-WinForgeNavItem -Id "software.list" -Label "Listar programas instalados" `
            -Description "Mostra a tabela de programas que o winget reconhece" -Command "Show-WinForgeInstalledSoftware"),
        (New-WinForgeNavItem -Id "software.uninstall" -Label "Desinstalar programas" `
            -Description "Lista os programas e remove os que você marcar" -Command "Uninstall-WinForgeSoftware"),
        (New-WinForgeNavItem -Id "software.startup" -Label "Aplicativos de inicialização" `
            -Description "Abre as Configurações do Windows: o que abre junto com o Windows" -Shortcut "StartupApps"),
        (New-WinForgeNavItem -Id "software.installed-apps" -Label "Aplicativos instalados" `
            -Description "Abre as Configurações do Windows: lista completa, com a opção de desinstalar" -Shortcut "InstalledApps"),
        (New-WinForgeNavItem -Id "software.programs-features" -Label "Programas e Recursos" `
            -Description "Abre o painel de controle clássico, para programas antigos" -Shortcut "ProgramsAndFeatures")
    )

    $pages += New-WinForgeNavPage -Id "network" -Title "Rede" -Summary "Do mais simples ao mais invasivo: ver, testar, medir e reparar." -Items @(
        (New-WinForgeNavItem -Id "network.info" -Label "Informações de rede" `
            -Description "Adaptadores, IP, DNS, gateway e IP público" -Command "Show-WinForgeNetworkInfo"),
        (New-WinForgeNavItem -Id "network.ping" -Label "Testar conectividade (ping)" `
            -Description "Ping com perda de pacotes e diagnóstico de DNS" -Command "Test-WinForgePing"),
        (New-WinForgeNavItem -Id "network.speed" -Label "Testar velocidade da internet" `
            -Description "Download e upload aproximados (usa cerca de 35 MB)" -Command "Test-WinForgeInternetSpeed"),
        (New-WinForgeNavItem -Id "network.repair" -Label "Reparar rede e DNS" `
            -Description "Renova o IP, limpa o DNS e redefine Winsock e TCP/IP; preserva IP estático" -Command "Invoke-WinForgeNetworkRepair")
    )

    $pages += New-WinForgeNavPage -Id "tweaks" -Title "Ajustes do Windows" -Kind Tweaks `
        -Summary "Mudanças reversíveis, com backup do valor original." -Items @(
        (New-WinForgeNavItem -Id "tweaks.recommended" -Label "Aplicar ajustes recomendados" -Accent `
            -Description "Você escolhe quais dos recomendados aplicar" -Command "Invoke-WinForgeRecommendedTweaks"),
        (New-WinForgeNavItem -Id "tweaks.restore-point" -Label "Criar ponto de restauração" `
            -Description "Um ponto para voltar atrás se algo der errado" -Command "Invoke-WinForgeRestorePoint"),
        (New-WinForgeNavItem -Id "tweaks.revert-all" -Label "Desfazer ajustes do WinForge" `
            -Description "Desfaz tudo o que o WinForge aplicou, usando o backup" -Command "Invoke-WinForgeRevertAllTweaks")
    )

    $pages += New-WinForgeNavPage -Id "app" -Title "Sobre o WinForge" -Placement Footer `
        -Summary "Versão, atalho com ícone, logs e relatórios." -Items @(
        (New-WinForgeNavItem -Id "app.about" -Label "Versão e pastas" `
            -Description "Qual versão está aberta, onde ela está instalada e onde ficam os logs e relatórios" -Command "Show-WinForgeAbout"),
        (New-WinForgeNavItem -Id "app.shortcut" -Label "Criar atalho do WinForge" -Accent `
            -Description "Coloca o WinForge, com o ícone dele, na Área de Trabalho ou no Menu Iniciar" -Command "New-WinForgeAppShortcut"),
        (New-WinForgeNavItem -Id "app.logs" -Label "Pasta de logs e relatórios" `
            -Description "Abre a pasta com os logs e os relatórios gerados" -Shortcut "LogFolder")
    )

    $script:WinForgeNavigation = @($pages)
    return $script:WinForgeNavigation
}


function Get-WinForgeNavPage {
    param (
        [Parameter(Mandatory)]
        [string]$Id
    )

    return (Get-WinForgeNavigation | Where-Object { $_.Id -eq $Id } | Select-Object -First 1)
}


function Get-WinForgeNavItem {
    param (
        [Parameter(Mandatory)]
        [string]$Id
    )

    foreach ($page in (Get-WinForgeNavigation)) {
        $item = @($page.Items | Where-Object { $_.Id -eq $Id }) | Select-Object -First 1

        if ($null -ne $item) {
            return $item
        }
    }

    return $null
}


function Get-WinForgeHomeActions {
    # Atalhos da tela inicial: o que a maioria das pessoas procura primeiro.
    return @(
        "maintenance.recommended",
        "diagnostics.about",
        "cleanup.quick",
        "updates.winget"
    ) | ForEach-Object { Get-WinForgeNavItem -Id $_ }
}


function Test-WinForgeNavigation {
    # Confere a tabela: Ids únicos, funções existentes, atalhos conhecidos e as convenções de nome.
    # Devolve a lista de problemas (vazia = ok).
    $problems = @()
    $seen = @{}
    $shortcutNames = @(Get-WinForgeShortcutNames)

    foreach ($page in (Get-WinForgeNavigation)) {
        if ($seen.ContainsKey($page.Id)) { $problems += "Id de página repetido: $($page.Id)" }
        $seen[$page.Id] = $true

        foreach ($item in $page.Items) {
            if ($seen.ContainsKey($item.Id)) { $problems += "Id de item repetido: $($item.Id)" }
            $seen[$item.Id] = $true

            if ($item.Kind -eq "Action") {
                if (-not (Get-Command -Name $item.Command -CommandType Function -ErrorAction SilentlyContinue)) {
                    $problems += "Função inexistente em '$($item.Id)': $($item.Command)"
                }
            }
            elseif ($shortcutNames -notcontains $item.Shortcut) {
                $problems += "Atalho desconhecido em '$($item.Id)': $($item.Shortcut)"
            }
            elseif ($item.Description -notmatch '^Abre ') {
                # A descrição de um atalho avisa que o clique abre uma janela do Windows (e não uma tela do WinForge).
                $problems += "A descrição do atalho '$($item.Id)' deveria começar com 'Abre'."
            }
        }
    }

    return $problems
}


# ---------------------------------------------------------------------------
# Tela inicial
# ---------------------------------------------------------------------------

# Os fatos da tela inicial, na ordem em que aparecem. A janela desenha os cartões a partir desta lista antes de a
# leitura do sistema terminar, e Get-WinForgeHomeStatus preenche os mesmos Ids.
$script:WinForgeHomeFactLabels = [ordered]@{
    windows     = "Windows"
    computer    = "Computador"
    user        = "Usuário"
    disk        = "Disco do sistema"
    reboot      = "Reinício pendente"
    maintenance = "Última manutenção"
}


function Get-WinForgeHomeFactLabels {
    return $script:WinForgeHomeFactLabels
}


function New-WinForgeHomeFact {
    # Level = Normal | Ok | Warn | Muted (a interface escolhe a cor).
    param (
        [Parameter(Mandatory)][string]$Id,
        [AllowEmptyString()][string]$Text,
        [ValidateSet("Normal", "Ok", "Warn", "Muted")]
        [string]$Level = "Normal"
    )

    # Um valor vazio (por exemplo, variável de ambiente ausente) não pode virar um cartão em branco.
    if ([string]::IsNullOrWhiteSpace($Text)) {
        $Text = "Não disponível"
    }

    return [PSCustomObject]@{ Id = $Id; Label = [string]$script:WinForgeHomeFactLabels[$Id]; Text = $Text; Level = $Level }
}


function Get-WinForgeHomeStatus {
    <#
    Os fatos que a tela inicial mostra (Windows, computador, usuário, disco do sistema, reinício pendente, última
    manutenção) e os avisos que merecem um destaque. Cada leitura é independente: uma que falhe vira "Não foi possível
    ler" e não apaga as outras. Facts: Id, Label, Text e Level. Notices: Level e Text.
    #>
    $facts = @()
    $notices = @()

    $session = $null
    try { $session = Get-WinForgeSessionInfo } catch { $session = $null }

    if ($null -ne $session) {
        $kind = $(if ($session.IsLaptop) { "Notebook" } else { "Desktop" })

        $facts += New-WinForgeHomeFact -Id "windows" -Text "$($session.WindowsLabel) (build $($session.WindowsBuild))"
        $facts += New-WinForgeHomeFact -Id "computer" -Text "$($env:COMPUTERNAME) · $kind"
        $facts += New-WinForgeHomeFact -Id "user" -Text ([string]$session.User)

        if ($session.UserMismatch) {
            $notices += [PSCustomObject]@{
                Level = "Warn"
                Text  = "O WinForge está elevado com outra conta ($($session.User)). Ajustes do usuário, Downloads e temporários afetam o perfil dessa conta, não o da pessoa logada no Windows."
            }
        }
    }
    else {
        $facts += New-WinForgeHomeFact -Id "windows" -Text "Não foi possível ler" -Level Muted
        $facts += New-WinForgeHomeFact -Id "computer" -Text ([string]$env:COMPUTERNAME)
        $facts += New-WinForgeHomeFact -Id "user" -Text ([string]$env:USERNAME)
    }

    try {
        $space = Get-WinForgeSystemDriveSpace

        if ($null -eq $space) { throw "sem dados" }

        $text = "$(Format-WinForgeBytes -Bytes $space.FreeBytes) livres de $(Format-WinForgeBytes -Bytes $space.TotalBytes)"
        $level = "Normal"

        switch (Get-WinForgeDiskSpaceLevel -FreeBytes $space.FreeBytes -TotalBytes $space.TotalBytes) {
            "Critical" { $text += " (espaço crítico)"; $level = "Warn" }
            "Low"      { $text += " (pouco espaço)"; $level = "Warn" }
        }

        $facts += New-WinForgeHomeFact -Id "disk" -Text $text -Level $level
    }
    catch {
        $facts += New-WinForgeHomeFact -Id "disk" -Text "Não foi possível ler" -Level Muted
    }

    try {
        if (Test-WinForgePendingReboot) {
            $facts += New-WinForgeHomeFact -Id "reboot" -Text "Sim, reinicie o PC" -Level Warn
        }
        else {
            $facts += New-WinForgeHomeFact -Id "reboot" -Text "Não" -Level Ok
        }
    }
    catch {
        $facts += New-WinForgeHomeFact -Id "reboot" -Text "Não foi possível ler" -Level Muted
    }

    try {
        $last = Get-WinForgeLastMaintenance

        if ($null -eq $last) {
            $facts += New-WinForgeHomeFact -Id "maintenance" -Text "Ainda não executada" -Level Muted
        }
        else {
            $startedAt = [datetime]$last.StartedAt
            $problems = @(@($last.Results) | Where-Object { $_.Kind -in @("Warning", "Failed") }).Count
            $text = "$(Format-WinForgeRelativeTime -When $startedAt) ($($startedAt.ToString('dd/MM/yyyy HH:mm')))"
            $level = "Normal"

            if ($problems -gt 0) {
                $text += " · $problems com atenção"
                $level = "Warn"
            }
            elseif (((Get-Date) - $startedAt).TotalDays -ge 30) {
                # Uma manutenção por mês mantém o PC em dia; depois disso vale lembrar.
                $text += " · já passou de um mês"
                $level = "Warn"
            }

            $facts += New-WinForgeHomeFact -Id "maintenance" -Text $text -Level $level
        }
    }
    catch {
        $facts += New-WinForgeHomeFact -Id "maintenance" -Text "Não foi possível ler" -Level Muted
    }

    return [PSCustomObject]@{
        Facts   = @($facts)
        Notices = @($notices)
    }
}


Export-ModuleMember -Function *
