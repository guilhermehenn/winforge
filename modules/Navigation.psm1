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
    # RequiresAdmin: a ação só funciona elevada (a janela aberta sem Administrador, quando o aviso do Windows foi recusado,
    # pede de novo antes).
    # Keywords: palavras extras que a busca reconhece (sinônimos, nomes de ferramentas, sintomas).
    # Group: a seção da página em que o item aparece ("Liberar espaço", "Ferramentas do Windows"); os itens de uma seção
    # ficam juntos na tabela, e a janela e o console mostram o nome da seção antes deles.
    # Unlisted: a janela não mostra o item como cartão da página (ele é aberto por outro caminho, como o cartão de
    # informação no alto dela); a busca, o console e os links "Página > Item" continuam chegando nele.
    param (
        [Parameter(Mandatory)][string]$Id,
        [Parameter(Mandatory)][string]$Label,
        [Parameter(Mandatory)][string]$Description,
        [string]$Command = "",
        [string]$Shortcut = "",
        [switch]$Accent,
        [switch]$Admin,
        [string]$Keywords = "",
        [string]$Group = "",
        [switch]$Unlisted
    )

    return [PSCustomObject]@{
        Id            = $Id
        Label         = $Label
        Group         = $Group
        Description   = $Description
        Kind          = $(if ([string]::IsNullOrEmpty($Shortcut)) { "Action" } else { "Shortcut" })
        Command       = $Command
        Shortcut      = $Shortcut
        Accent        = [bool]$Accent
        RequiresAdmin = [bool]$Admin
        Keywords      = $Keywords
        Unlisted      = [bool]$Unlisted
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

    # Manutenção: na janela, o cartão "Última manutenção" no alto abre o histórico, e os dois grupos têm três cartões
    # cada. O histórico e o Agendador de Tarefas não viram cartão (Unlisted), mas a busca e o console chegam neles.
    $pages += New-WinForgeNavPage -Id "maintenance" -Title "Manutenção" -Summary "Cuide do PC e volte atrás se algo der errado." -Items @(
        (New-WinForgeNavItem -Id "maintenance.recommended" -Label "Otimizar" -Group "Cuidar do PC" -Admin -Accent `
            -Keywords "manutenção recomendada completa profunda windows acelerar lento tudo guiada limpeza reparo atualizar" `
            -Description "A manutenção completa do PC, em ordem; pode levar mais de uma hora" -Command "Invoke-WinForgeRecommendedMaintenance"),
        (New-WinForgeNavItem -Id "maintenance.checkup" -Label "Verificar o PC" -Group "Cuidar do PC" -Admin `
            -Keywords "escanear examinar scan check-up checkup diagnóstico um clique corrigir problemas saúde" `
            -Description "Confere o PC em uma passada e corrige, num clique, o que é seguro" -Command "Invoke-WinForgeCheckup"),
        (New-WinForgeNavItem -Id "maintenance.schedule" -Label "Manutenção agendada" -Group "Cuidar do PC" -Admin `
            -Keywords "automática mensal tarefa sozinha agendar" `
            -Description "Uma limpeza leve e um relatório todo mês, sem você abrir o WinForge" -Command "Show-WinForgeScheduledMaintenance"),
        (New-WinForgeNavItem -Id "maintenance.history" -Label "Histórico de manutenções" -Group "Cuidar do PC" -Unlisted `
            -Keywords "última manutenção tendência espaço duração falhas atenção" `
            -Description "A última manutenção, o que pediu atenção nela e a variação de espaço das anteriores" -Command "Show-WinForgeMaintenanceHistory"),
        (New-WinForgeNavItem -Id "maintenance.task-scheduler" -Label "Agendador de Tarefas" -Group "Cuidar do PC" -Unlisted `
            -Keywords "taskschd agendar tarefas" `
            -Description "Abre o Agendador de Tarefas do Windows, onde a tarefa do WinForge aparece" -Shortcut "TaskScheduler"),
        (New-WinForgeNavItem -Id "maintenance.restore-point" -Label "Criar ponto de restauração" -Group "Se algo der errado" -Admin `
            -Keywords "backup segurança voltar atrás" `
            -Description "Guarda o estado do Windows de agora, para voltar a ele depois" -Command "Invoke-WinForgeRestorePoint"),
        (New-WinForgeNavItem -Id "maintenance.changes" -Label "Histórico de mudanças" -Group "Se algo der errado" `
            -Keywords "desfazer voltar atrás reverter restaurar registro backup central de resgate mudanças feitas" `
            -Description "O que o WinForge mudou no PC; desfaça o que tiver volta" -Command "Show-WinForgeChangeHistory"),
        (New-WinForgeNavItem -Id "maintenance.restore" -Label "Restauração do Sistema" -Group "Se algo der errado" `
            -Keywords "voltar desfazer rstrui restore" `
            -Description "Abre a janela do Windows que volta o PC a um ponto de restauração" -Shortcut "SystemRestore")
    )

    $pages += New-WinForgeNavPage -Id "diagnostics" -Title "Diagnóstico" -Summary "Veja como o PC está antes de mexer em qualquer coisa." -Items @(
        (New-WinForgeNavItem -Id "diagnostics.about" -Label "Sobre este PC" -Group "Visão geral" -Accent `
            -Keywords "cpu ram processador memória gpu placa de vídeo hardware especificações configuração xmp" `
            -Description "Windows, processador, memória, placa de vídeo, discos e Secure Boot" -Command "Show-WinForgeSystemInfo"),
        (New-WinForgeNavItem -Id "diagnostics.windows-support" -Label "Suporte do Windows" -Group "Visão geral" `
            -Keywords "fim do suporte windows 10 windows 11 atualizações de segurança esu requisitos tpm compatível upgrade versão 24h2 25h2" `
            -Description "Até quando este Windows recebe atualizações de segurança e se o PC pode ir para o Windows 11" -Command "Show-WinForgeWindowsSupport"),
        (New-WinForgeNavItem -Id "diagnostics.report" -Label "Exportar relatório" -Group "Visão geral" `
            -Keywords "salvar html txt relatório laudo" `
            -Description "Salva o estado do PC em HTML e em texto, para guardar ou mandar a quem vai ajudar" -Command "Invoke-WinForgeReport"),
        (New-WinForgeNavItem -Id "diagnostics.disks" -Label "Discos e espaço livre" -Group "Hardware" `
            -Keywords "armazenamento ssd hdd hd cheio capacidade unidade" `
            -Description "SSD ou HDD, espaço livre e uso de cada unidade" -Command "Show-WinForgeDisks"),
        (New-WinForgeNavItem -Id "diagnostics.disk-health" -Label "Saúde dos discos" -Group "Hardware" -Admin `
            -Keywords "smart temperatura desgaste ssd hdd hd falha" `
            -Description "Estado, temperatura, desgaste e erros de cada disco" -Command "Show-WinForgeDiskHealth"),
        (New-WinForgeNavItem -Id "diagnostics.devices" -Label "Dispositivos com problema" -Group "Hardware" `
            -Keywords "driver drivers erro hardware câmera webcam som áudio microfone fone impressora teclado mouse bluetooth pendrive usb reconhecido tela piscando" `
            -Description "Drivers e hardware com erro" -Command "Show-WinForgeProblemDevices"),
        (New-WinForgeNavItem -Id "diagnostics.battery" -Label "Saúde da bateria" -Group "Hardware" `
            -Keywords "notebook laptop carga ciclos desgaste energia" `
            -Description "Capacidade de hoje comparada à de fábrica, ciclos de carga e carga atual" -Command "Show-WinForgeBatteryHealth"),
        (New-WinForgeNavItem -Id "diagnostics.events" -Label "Eventos críticos (7 dias)" -Group "Funcionamento do Windows" `
            -Keywords "erro tela azul preta bsod travou travando travamento queda de energia falha log reiniciando reiniciou desligando desligou" `
            -Description "Quedas de energia, tela azul, erros de disco e de hardware" -Command "Show-WinForgeCriticalEvents"),
        (New-WinForgeNavItem -Id "diagnostics.pending-reboot" -Label "Reinício pendente" -Group "Funcionamento do Windows" `
            -Keywords "reiniciar reboot restart" `
            -Description "O que está esperando um reinício, se ele é mesmo necessário, e reiniciar quando quiser" -Command "Show-WinForgePendingReboot"),
        (New-WinForgeNavItem -Id "diagnostics.startup" -Label "Tempo ligado e energia" -Group "Funcionamento do Windows" `
            -Keywords "boot lento ligar demora inicialização rápida hibernar hibernação energia uptime" `
            -Description "Quanto tempo o PC está ligado, Inicialização Rápida e hibernação" -Command "Show-WinForgeStartupInfo"),
        (New-WinForgeNavItem -Id "diagnostics.reliability" -Label "Monitor de Confiabilidade" -Group "Ferramentas do Windows" `
            -Keywords "falhas travamentos histórico confiabilidade perfmon" `
            -Description "Abre o histórico de falhas do Windows" -Shortcut "Reliability"),
        (New-WinForgeNavItem -Id "diagnostics.device-manager" -Label "Gerenciador de Dispositivos" -Group "Ferramentas do Windows" `
            -Keywords "devmgmt drivers" `
            -Description "Abre o Gerenciador de Dispositivos do Windows" -Shortcut "DeviceManager")
    )

    $pages += New-WinForgeNavPage -Id "security" -Title "Segurança" -Summary "Veja se o PC está protegido e rode a verificação do Windows." -Items @(
        (New-WinForgeNavItem -Id "security.status" -Label "Estado da proteção" -Group "Proteção" -Accent `
            -Keywords "vírus malware defender firewall antivírus proteção ameaça" `
            -Description "Antivírus, assinaturas, firewall, atualizações pendentes e ameaças ativas" -Command "Show-WinForgeSecurityStatus"),
        (New-WinForgeNavItem -Id "security.audit" -Label "Auditoria de segurança" -Group "Proteção" `
            -Description "Além do antivírus e do firewall, confere senhas, acesso remoto e criptografia, e dá uma nota" -Command "Show-WinForgeSecurityAudit" `
            -Keywords "nota uac smartscreen bitlocker criptografia secure boot remota rdp convidado senha entrada automática"),
        (New-WinForgeNavItem -Id "security.signatures" -Label "Atualizar assinaturas do antivírus" -Group "Proteção" -Admin `
            -Keywords "vírus malware definições atualizar defender" `
            -Description "Baixa do Windows Defender a lista mais nova de vírus conhecidos (as assinaturas)" -Command "Update-WinForgeDefenderSignatures"),
        (New-WinForgeNavItem -Id "security.scan" -Label "Verificar vírus" -Group "Procurar ameaças" -Admin `
            -Keywords "vírus antivírus malware ransomware trojan scan escanear examinar varredura assinaturas um clique verificação rápida" `
            -Description "Atualiza o antivírus e faz a verificação rápida do Windows Defender, em alguns minutos" -Command "Invoke-WinForgeSecurityCheck"),
        (New-WinForgeNavItem -Id "security.full-scan" -Label "Verificação completa de vírus" -Group "Procurar ameaças" -Admin `
            -Keywords "vírus malware ransomware trojan scan antivírus escanear examinar horas" `
            -Description "Atualiza o antivírus e o Windows Defender examina todos os arquivos; pode levar horas" -Command "Start-WinForgeFullScan"),
        (New-WinForgeNavItem -Id "security.folder-scan" -Label "Verificar uma pasta" -Group "Procurar ameaças" -Admin `
            -Keywords "vírus malware scan arquivo suspeito suspeita baixado download" `
            -Description "Atualiza o antivírus e o Windows Defender examina só a pasta ou o arquivo que você indicar" -Command "Start-WinForgeFolderScan"),
        (New-WinForgeNavItem -Id "security.windows-security" -Label "Segurança do Windows" -Group "Procurar ameaças" `
            -Keywords "windows security defender firewall vírus offline proteção quarentena histórico" `
            -Description "Abre o aplicativo do Windows, com a verificação offline e o histórico de proteção" -Shortcut "WindowsSecurity")
    )

    $pages += New-WinForgeNavPage -Id "cleanup" -Title "Limpeza" -Summary "Libere espaço, do mais seguro ao mais profundo." -Items @(
        (New-WinForgeNavItem -Id "cleanup.quick" -Label "Limpeza rápida" -Group "Liberar espaço" -Admin -Accent `
            -Keywords "limpar liberar espaço lixo lento temp tmp temporários arquivos apagar limpeza de disco clean cleanup cleaner disk cleanmgr" `
            -Description "Temporários do usuário e do Windows e, se você quiser, a Lixeira" -Command "Invoke-WinForgeQuickCleanup"),
        (New-WinForgeNavItem -Id "cleanup.space" -Label "Analisar uso de espaço" -Group "Liberar espaço" `
            -Keywords "disco cheio o que ocupa espaço maiores pastas tamanho armazenamento ocupa windows.old hiberfil hibernação pagefile memória virtual swapfile" `
            -Description "Mostra o que a limpeza libera, as maiores pastas do perfil e os arquivos grandes do sistema" -Command "Show-WinForgeSpaceAnalysis"),
        (New-WinForgeNavItem -Id "cleanup.custom" -Label "Limpeza personalizada" -Group "Liberar espaço" -Admin `
            -Keywords "escolher lista tamanhos temporários do usuário temporários do windows cache navegador relatórios de erro otimização de entrega delivery optimization despejo memória dump" `
            -Description "Você marca numa lista, com o tamanho de cada item: temporários, caches, despejos de falhas, Lixeira" -Command "Invoke-WinForgeCustomCleanup"),
        (New-WinForgeNavItem -Id "cleanup.recycle-bin" -Label "Esvaziar a Lixeira" -Group "Liberar espaço" `
            -Keywords "lixo excluídos apagados" `
            -Description "Remove em definitivo o que está na Lixeira, de todas as unidades" -Command "Clear-WinForgeRecycleBin"),
        (New-WinForgeNavItem -Id "cleanup.downloads" -Label "Limpar a pasta Downloads" -Group "Liberar espaço" `
            -Keywords "baixados arquivos antigos apagar excluir remover" `
            -Description "Você vê uma prévia, filtra por idade e escolhe entre a Lixeira e a exclusão" -Command "Clear-WinForgeDownloads"),
        (New-WinForgeNavItem -Id "cleanup.storage" -Label "Configurações de armazenamento" -Group "Liberar espaço" `
            -Keywords "sensor de armazenamento configurações espaço" `
            -Description "Abre as Configurações do Windows, onde fica o Sensor de Armazenamento" -Shortcut "Storage"),
        (New-WinForgeNavItem -Id "cleanup.shortcuts" -Label "Remover atalhos quebrados" -Group "Arrumar o que sobrou" `
            -Keywords "atalho quebrado inválido lnk ícone não abre" `
            -Description "Atalhos que apontam para o que não existe mais; eles vão para a Lixeira" -Command "Remove-WinForgeBrokenShortcuts"),
        (New-WinForgeNavItem -Id "cleanup.duplicates" -Label "Encontrar arquivos duplicados" -Group "Arrumar o que sobrou" `
            -Keywords "duplicado duplicados cópia cópias repetidos iguais fotos espaço" `
            -Description "Arquivos iguais (mesmo conteúdo) numa pasta; você escolhe o que vai para a Lixeira" -Command "Find-WinForgeDuplicateFiles"),
        (New-WinForgeNavItem -Id "cleanup.leftovers" -Label "Restos de programas desinstalados" -Group "Arrumar o que sobrou" `
            -Keywords "sobras resíduos desinstalado pastas vazias appdata program files revo" `
            -Description "Pastas que sobraram de programas desinstalados pelo WinForge; você escolhe o que vai para a Lixeira" -Command "Find-WinForgeProgramLeftovers"),
        (New-WinForgeNavItem -Id "cleanup.registry" -Label "Limpar o registro" -Group "Avançado" `
            -Keywords "registro regedit chaves inválidas quebradas órfãs erros do registro limpador" `
            -Description "Só referências quebradas a programas e arquivos que não existem mais; com backup e desfazer" -Command "Invoke-WinForgeRegistryCleanup"),
        (New-WinForgeNavItem -Id "cleanup.components" -Label "Limpar componentes do Windows (WinSxS)" -Group "Avançado" -Admin `
            -Keywords "winsxs dism component store atualizações antigas espaço" `
            -Description "Remove versões antigas de componentes substituídos por atualizações (DISM)" -Command "Invoke-WinForgeComponentCleanup"),
        (New-WinForgeNavItem -Id "cleanup.wipe-free" -Label "Apagar o espaço livre" -Group "Avançado" -Admin `
            -Keywords "cipher apagar com segurança vender doar sobrescrever definitivo" `
            -Description "Sobrescreve o espaço livre do disco: o que já foi apagado não pode mais ser trazido de volta" -Command "Clear-WinForgeFreeSpace")
    )

    $pages += New-WinForgeNavPage -Id "performance" -Title "Desempenho" -Summary "Deixe o PC mais leve agora e veja o que está pesando." -Items @(
        (New-WinForgeNavItem -Id "performance.boost" -Label "Acelerar agora" -Group "Deixar o PC mais leve" -Accent `
            -Keywords "lento lentidão travando turbo boost otimizar memória ram rápido pc" `
            -Description "Libera memória e apaga os seus temporários, num clique; o efeito na memória é passageiro" -Command "Invoke-WinForgeBoost"),
        (New-WinForgeNavItem -Id "performance.processes" -Label "Programas pesando agora" -Group "Deixar o PC mais leve" `
            -Keywords "processos processo pesados pesado cpu processador memória ram travando lento fechar encerrar uso alto disco 100% esquentando quente temperatura superaquecendo superaquecimento ventoinha cooler barulho" `
            -Description "O que mais usa o processador e a memória neste momento; você pode fechar o que quiser" -Command "Show-WinForgeHeavyProcesses"),
        (New-WinForgeNavItem -Id "performance.memory" -Label "Liberar memória" -Group "Deixar o PC mais leve" `
            -Keywords "ram memória cheia otimizar limpar memória" `
            -Description "Tira da memória o que os programas abertos ocupam; ajuda antes de abrir algo pesado" -Command "Invoke-WinForgeMemoryOptimization"),
        (New-WinForgeNavItem -Id "performance.startup" -Label "Gerenciar inicialização" -Group "Para o PC continuar leve" `
            -Keywords "programas iniciam abrem junto boot demora msconfig" `
            -Description "O que abre junto com o Windows; desligar o que não precisa deixa o PC leve desde o início" -Command "Set-WinForgeStartupItems"),
        (New-WinForgeNavItem -Id "performance.task-manager" -Label "Gerenciador de Tarefas" -Group "Para o PC continuar leve" `
            -Keywords "taskmgr task manager ctrl shift esc processos desempenho" `
            -Description "Abre o Gerenciador de Tarefas do Windows; os gráficos de uso ficam na aba Desempenho" -Shortcut "TaskManager")
    )

    $pages += New-WinForgeNavPage -Id "repair" -Title "Reparo" -Summary "Conserte o Windows e o disco, e mantenha a unidade em forma." -Items @(
        (New-WinForgeNavItem -Id "repair.dism-sfc" -Label "Reparar o Windows (DISM + SFC)" -Group "Arquivos do Windows" -Admin -Accent `
            -Keywords "corrigir consertar arquivos corrompidos corrupção erro windows travando instável tela azul" `
            -Description "Conserta arquivos danificados do Windows; costuma levar de 20 a 60 minutos e não apaga nada seu" -Command "Invoke-WinForgeDismAndSfc"),
        (New-WinForgeNavItem -Id "repair.dism" -Label "Reparar imagem e componentes (DISM)" -Group "Arquivos do Windows" -Admin `
            -Keywords "imagem corrompida componente store restorehealth cleanup-image update com erro atualização falhando travado travada falhou" `
            -Description "Restaura os arquivos-base do Windows pela internet (Windows Update); leva de 10 a 30 minutos" -Command "Invoke-WinForgeDism"),
        (New-WinForgeNavItem -Id "repair.sfc" -Label "Verificar arquivos do sistema (SFC)" -Group "Arquivos do Windows" -Admin `
            -Keywords "scannow corrompidos arquivos protegidos integridade verificar integridade cbs" `
            -Description "Confere os arquivos protegidos do Windows e conserta os danificados; leva de 5 a 20 minutos" -Command "Invoke-WinForgeSfc"),
        (New-WinForgeNavItem -Id "repair.chkdsk" -Label "Verificar o sistema de arquivos (CHKDSK)" -Group "Disco e dispositivos" -Admin `
            -Keywords "disco erros setores defeituosos bad sector verificar hd com problema ntfs fsutil disco corrompido" `
            -Description "Procura erros no disco sem reiniciar; se precisar de reparo na reinicialização, pergunta antes" -Command "Start-WinForgeChkdsk"),
        (New-WinForgeNavItem -Id "repair.device-scan" -Label "Detectar dispositivos e drivers" -Group "Disco e dispositivos" -Admin `
            -Keywords "driver drivers hardware novo pnp pnputil usb não reconhecido dispositivo não reconhecido" `
            -Description "Procura hardware novo e instala os drivers que já estejam disponíveis" -Command "Invoke-WinForgeDeviceScan"),
        (New-WinForgeNavItem -Id "repair.optimize" -Label "Otimizar a unidade do sistema" -Group "Disco e dispositivos" -Admin `
            -Keywords "trim ssd desfragmentar desfragmentação hdd defrag disco lento" `
            -Description "Deixa o disco do Windows mais rápido: o próprio Windows escolhe o certo para SSD ou HD" -Command "Start-WinForgeDriveOptimization"),
        (New-WinForgeNavItem -Id "repair.system-restore" -Label "Restauração do Sistema" -Group "Ferramentas do Windows" `
            -Keywords "voltar rstrui desfazer" `
            -Description "Abre a janela do Windows que volta o PC a um ponto de restauração" -Shortcut "SystemRestore"),
        (New-WinForgeNavItem -Id "repair.recovery" -Label "Recuperação" -Group "Ferramentas do Windows" `
            -Keywords "restaurar o pc reinstalar formatar inicialização avançada modo de segurança reset" `
            -Description "Abre a Recuperação do Windows: restaurar o PC e a inicialização avançada" -Shortcut "Recovery")
    )

    $pages += New-WinForgeNavPage -Id "updates" -Title "Atualizações" -Summary "Windows, drivers, Microsoft Store e programas." -Items @(
        (New-WinForgeNavItem -Id "updates.install" -Label "Instalar atualizações do Windows" -Group "Windows e drivers" -Admin -Accent `
            -Keywords "baixar instalar atualizar windows update pendentes progresso reiniciar atualização atualizações pendente kb cumulativa segurança patch desatualizado pc" `
            -Description "Procura, baixa e instala aqui mesmo as atualizações pendentes, com o progresso na tela" -Command "Install-WinForgeWindowsUpdates"),
        (New-WinForgeNavItem -Id "updates.drivers" -Label "Atualizar drivers" -Group "Windows e drivers" -Admin `
            -Keywords "driver drivers placa de vídeo som rede wifi bluetooth chipset desatualizado opcionais" `
            -Description "Procura drivers no Windows Update e instala os que você marcar; os opcionais vêm desmarcados" -Command "Install-WinForgeDriverUpdates"),
        (New-WinForgeNavItem -Id "updates.vendor-tools" -Label "Ferramentas do fabricante" -Group "Windows e drivers" `
            -Keywords "dell lenovo hp intel nvidia amd geforce radeon fabricante bios firmware support assistant command update" `
            -Description "Indica o programa oficial do fabricante do PC e da placa de vídeo, que acha drivers e BIOS" -Command "Show-WinForgeVendorTools"),
        (New-WinForgeNavItem -Id "updates.repair" -Label "Corrigir o Windows Update" -Group "Windows e drivers" -Admin `
            -Keywords "erro falha falhou falhando travado atualização travada preso parado cache softwaredistribution catroot2 resetar redefinir consertar" `
            -Description "Quando as atualizações falham ou travam: refaz o cache do Windows Update e religa os serviços" -Command "Repair-WinForgeWindowsUpdate"),
        (New-WinForgeNavItem -Id "updates.winget" -Label "Atualizar programas (winget)" -Group "Programas e aplicativos" `
            -Keywords "atualizar programas apps upgrade todos tudo desatualizado desatualizados navegador chrome firefox" `
            -Description "Mostra os programas com versão nova no winget e atualiza os que você escolher" -Command "Update-WinForgeSoftware"),
        (New-WinForgeNavItem -Id "updates.store" -Label "Atualizar aplicativos da Microsoft Store" -Group "Programas e aplicativos" `
            -Keywords "loja aplicativos apps" `
            -Description "Pede à Microsoft Store as atualizações dos aplicativos e abre a lista para acompanhar" -Command "Update-WinForgeStoreApps"),
        (New-WinForgeNavItem -Id "updates.windows" -Label "Windows Update" -Group "Ferramentas do Windows" `
            -Keywords "windows update atualizar configurações patch desatualizado verificar pausar adiar desativar atualizações" `
            -Description "Abre o Windows Update nas Configurações do Windows" -Shortcut "WindowsUpdate"),
        (New-WinForgeNavItem -Id "updates.optional" -Label "Atualizações opcionais" -Group "Ferramentas do Windows" `
            -Keywords "opcionais prévia preview recursos" `
            -Description "Abre nas Configurações do Windows as opcionais: drivers e prévias da próxima atualização" -Shortcut "OptionalUpdates")
    )

    $pages += New-WinForgeNavPage -Id "software" -Title "Programas" -Summary "Instale, remova e organize o que roda no PC." -Items @(
        (New-WinForgeNavItem -Id "software.essentials" -Label "Instalar programas essenciais" -Group "Instalar e remover" -Accent `
            -Keywords "instalar baixar navegador chrome firefox 7zip 7-zip vlc pdf acrobat libreoffice zoom git aplicativos discord steam vscode code python node nodejs java jdk powershell notepad everything powertoys" `
            -Description "Escolha numa lista de programas comuns, como navegadores, leitor de PDF, 7-Zip e VLC" -Command "Install-WinForgeEssentialSoftware"),
        (New-WinForgeNavItem -Id "software.find" -Label "Buscar e instalar programas" -Group "Instalar e remover" `
            -Keywords "pesquisar procurar instalar baixar winget app" `
            -Description "Procura um programa pelo nome e instala o que você marcar" -Command "Find-WinForgeSoftware"),
        (New-WinForgeNavItem -Id "software.list" -Label "Listar programas instalados" -Group "Instalar e remover" `
            -Keywords "winget lista programas apps instalados" `
            -Description "Conta os programas instalados e quantos têm versão nova, com a lista completa do winget" -Command "Show-WinForgeInstalledSoftware"),
        (New-WinForgeNavItem -Id "software.uninstall" -Label "Desinstalar programas" -Group "Instalar e remover" `
            -Keywords "remover apagar excluir app programa uninstall" `
            -Description "Lista os programas e remove os que você marcar" -Command "Uninstall-WinForgeSoftware"),
        (New-WinForgeNavItem -Id "software.remove-apps" -Label "Remover aplicativos do Windows" -Group "Instalar e remover" `
            -Keywords "bloatware pré-instalados candy crush xbox spotify tiktok teams clima notícias cortana bing linkedin" `
            -Description "Mostra os aplicativos que vêm com o PC e remove só os que você marcar" -Command "Remove-WinForgePreinstalledApps"),
        (New-WinForgeNavItem -Id "software.startup-manager" -Label "Gerenciar inicialização" -Group "Inicialização e recursos" `
            -Keywords "desativar reativar lento lenta lentidão boot startup abrir iniciar com o windows msconfig" `
            -Description "Desative ou reative, aqui mesmo, os programas que abrem junto com o Windows" -Command "Set-WinForgeStartupItems"),
        (New-WinForgeNavItem -Id "software.features" -Label "Recursos opcionais do Windows" -Group "Inicialização e recursos" -Admin `
            -Keywords "wsl hyper-v sandbox virtualização net framework telnet smb smb1 powershell ativar desativar" `
            -Description "Liga ou desliga recursos como WSL, Hyper-V, Windows Sandbox e .NET 3.5" -Command "Set-WinForgeWindowsFeatures"),
        (New-WinForgeNavItem -Id "software.backup" -Label "Backup antes de formatar" -Group "Backup e formatação" -Admin `
            -Keywords "formatar reinstalar windows drivers wifi pendrive exportar lista" `
            -Description "Guarda a lista de programas, os drivers e os ajustes; fotos e documentos você copia à parte" -Command "Invoke-WinForgeBackupBeforeFormat"),
        (New-WinForgeNavItem -Id "software.restore" -Label "Restaurar a partir de um backup" -Group "Backup e formatação" -Admin `
            -Keywords "formatar reinstalar windows drivers wifi importar" `
            -Description "Reinstala os programas e os drivers e reaplica os ajustes de um backup do WinForge" -Command "Restore-WinForgeFromBackup"),
        (New-WinForgeNavItem -Id "software.installed-apps" -Label "Aplicativos instalados" -Group "Ferramentas do Windows" `
            -Keywords "remover desinstalar lista apps" `
            -Description "Abre nas Configurações do Windows, em Aplicativos, a lista completa, com a opção de desinstalar" -Shortcut "InstalledApps"),
        (New-WinForgeNavItem -Id "software.programs-features" -Label "Programas e Recursos" -Group "Ferramentas do Windows" `
            -Keywords "painel de controle appwiz desinstalar clássico" `
            -Description "Abre o painel de controle clássico, para programas antigos" -Shortcut "ProgramsAndFeatures"),
        (New-WinForgeNavItem -Id "software.startup" -Label "Aplicativos de inicialização" -Group "Ferramentas do Windows" `
            -Keywords "iniciar inicialização abrir boot startup" `
            -Description "Abre nas Configurações do Windows, em Aplicativos, Inicialização, o que abre junto com o Windows" -Shortcut "StartupApps")
    )

    $pages += New-WinForgeNavPage -Id "network" -Title "Rede" -Summary "Do mais simples ao que mexe mais: ver, testar, medir e consertar a conexão." -Items @(
        (New-WinForgeNavItem -Id "network.info" -Label "Informações de rede" -Group "Ver e testar" `
            -Keywords "ip gateway adaptador mac endereço internet dns meu público ipconfig placa proxy ssid banda canal" `
            -Description "Adaptadores, rede Wi-Fi, IP, DNS, gateway, proxy e IP público" -Command "Show-WinForgeNetworkInfo"),
        (New-WinForgeNavItem -Id "network.ping" -Label "Testar conectividade (ping)" -Group "Ver e testar" -Accent `
            -Keywords "latência perda de pacotes sem internet conexão teste lag alto jogo roteador" `
            -Description "Diz se a internet responde e se a conexão está estável ou perdendo dados" -Command "Test-WinForgePing"),
        (New-WinForgeNavItem -Id "network.speed" -Label "Testar velocidade da internet" -Group "Ver e testar" `
            -Keywords "speedtest internet lenta wifi download upload mbps banda teste" `
            -Description "Latência, download e upload (usa cerca de 35 MB)" -Command "Test-WinForgeInternetSpeed"),
        (New-WinForgeNavItem -Id "network.wifi-report" -Label "Relatório de Wi-Fi" -Group "Ver e testar" -Admin `
            -Keywords "wlan quedas desconexoes sinal wireless wifi wi-fi sem fio caindo cai caiu desconectando instável fraco" `
            -Description "Gera o relatório do Windows com as sessões e as quedas do Wi-Fi dos últimos dias" -Command "Show-WinForgeWifiReport"),
        (New-WinForgeNavItem -Id "network.repair" -Label "Reparar rede e DNS" -Group "Consertar e configurar" -Admin `
            -Keywords "internet não funciona conecta conectar sem conexão caiu queda wifi wi-fi fio winsock flushdns ipconfig reset renovar reiniciar redefinir dhcp netsh roteador" `
            -Description "Para quando a internet não funciona: refaz as configurações de rede; IP e DNS fixos são mantidos" -Command "Invoke-WinForgeNetworkRepair"),
        (New-WinForgeNavItem -Id "network.dns" -Label "Trocar o servidor DNS" -Group "Consertar e configurar" -Admin `
            -Keywords "cloudflare google quad9 1.1.1.1 8.8.8.8 1.1.1.3 lento sites família filtro adulto controle parental bloquear" `
            -Description "Mede o tempo de resposta e troca para Cloudflare, Google, Quad9 ou o filtro para famílias" -Command "Set-WinForgeDnsProvider"),
        (New-WinForgeNavItem -Id "network.dns-undo" -Label "Desfazer a troca de DNS" -Group "Consertar e configurar" -Admin `
            -Keywords "voltar restaurar dns original automatico" `
            -Description "Devolve o DNS que o PC usava antes da troca feita pelo WinForge" -Command "Undo-WinForgeDnsChange")
    )

    $pages += New-WinForgeNavPage -Id "tweaks" -Title "Ajustes do Windows" -Kind Tweaks `
        -Summary "Mudanças reversíveis, com backup do valor original." -Items @(
        (New-WinForgeNavItem -Id "tweaks.recommended" -Label "Aplicar ajustes recomendados" -Admin -Accent `
            -Description "Mostra as extensões de arquivos e tira dicas, sugestões e o ID de publicidade; você escolhe quais" -Command "Invoke-WinForgeRecommendedTweaks"),
        (New-WinForgeNavItem -Id "tweaks.profiles" -Label "Perfis de ajustes" -Admin `
            -Keywords "perfil essencial trabalho jogos privacidade notebook conjunto telemetria rastreamento" `
            -Description "Conjuntos prontos: Essencial, Trabalho, Jogos, Privacidade e Notebook; você escolhe o que aplicar" -Command "Invoke-WinForgeTweakProfile"),
        (New-WinForgeNavItem -Id "tweaks.keyboard-language" -Label "Teclas que trocam o idioma do teclado" `
            -Keywords "alt shift ctrl trocar mudar idioma teclado layout abnt abnt2 internacional muda troca sozinho" `
            -Description "Escolhe as teclas que trocam o idioma e o teclado: Alt + Shift, Ctrl + Shift, as duas ou nenhuma" -Command "Set-WinForgeKeyboardLanguageHotkey"),
        (New-WinForgeNavItem -Id "tweaks.notifications" -Label "Notificações e Não incomodar" `
            -Keywords "assistente de foco silenciar avisos notificação concentração quiet hours" `
            -Description "Abre nas Configurações do Windows as notificações e o Não incomodar (assistente de foco)" -Shortcut "Notifications"),
        (New-WinForgeNavItem -Id "tweaks.restore-point" -Label "Criar ponto de restauração" -Admin `
            -Description "Um ponto para voltar atrás se algo der errado" -Command "Invoke-WinForgeRestorePoint"),
        (New-WinForgeNavItem -Id "tweaks.export" -Label "Exportar ajustes aplicados" `
            -Keywords "salvar backup levar outro pc" `
            -Description "Salva em um arquivo os ajustes aplicados neste PC, para repetir em outro" -Command "Export-WinForgeTweaks"),
        (New-WinForgeNavItem -Id "tweaks.import" -Label "Importar ajustes" -Admin `
            -Keywords "restaurar carregar arquivo outro pc" `
            -Description "Aplica ajustes de um arquivo exportado antes, depois de você escolher quais" -Command "Import-WinForgeTweaks"),
        (New-WinForgeNavItem -Id "tweaks.revert-all" -Label "Desfazer ajustes do WinForge" -Admin `
            -Description "Desfaz tudo o que o WinForge aplicou aqui e na Personalização, usando o backup" -Command "Invoke-WinForgeRevertAllTweaks")
    )

    # O visual do Windows: os ajustes das categorias da Personalização (Get-WinForgeTweakPages) e, no alto, a cor de destaque
    # e os atalhos para as telas do Windows que o WinForge não faz.
    $pages += New-WinForgeNavPage -Id "personalize" -Title "Personalização" -Kind Tweaks `
        -Summary "O visual do Windows: barra de tarefas, área de trabalho, cores e tela de bloqueio." -Items @(
        (New-WinForgeNavItem -Id "personalize.accent-color" -Label "Cor de destaque" `
            -Keywords "cor accent azul verde roxo vermelho rosa laranja cinza automática colorir" `
            -Description "Escolhe a cor do Windows entre as principais (azul, verde, roxo...) ou a do papel de parede" -Command "Set-WinForgeAccentColor"),
        (New-WinForgeNavItem -Id "personalize.lock-screen" -Label "Tela de bloqueio do Windows" `
            -Keywords "imagem foto destaque do windows spotlight bloqueio lock screen" `
            -Description "Abre nas Configurações do Windows a tela de bloqueio: a imagem e o que aparece nela" -Shortcut "LockScreen"),
        (New-WinForgeNavItem -Id "personalize.settings" -Label "Personalização do Windows" `
            -Keywords "papel de parede tela de fundo temas fonte wallpaper" `
            -Description "Abre nas Configurações do Windows a tela de fundo, os temas, as cores e as fontes" -Shortcut "Personalization")
    )

    $pages += New-WinForgeNavPage -Id "app" -Title "Sobre o WinForge" -Placement Footer `
        -Summary "Versão e atualizações, atalho, logs, monitor na bandeja, dados online e aparência." -Items @(
        (New-WinForgeNavItem -Id "app.about" -Label "Versão e pastas" -Group "Versão e dados" `
            -Keywords "build powershell" `
            -Description "Qual versão está aberta, onde ela está instalada e onde ficam os logs e relatórios" -Command "Show-WinForgeAbout"),
        (New-WinForgeNavItem -Id "app.update" -Label "Verificar nova versão" -Group "Versão e dados" `
            -Keywords "atualizar atualização baixar release github" `
            -Description "Vê se há uma versão mais nova do WinForge e baixa o zip conferindo o SHA-256" -Command "Invoke-WinForgeUpdateCheck"),
        (New-WinForgeNavItem -Id "app.catalog" -Label "Conferir dados online" -Group "Versão e dados" `
            -Keywords "catálogo lista essenciais datas suporte" `
            -Description "Confere na internet a lista de essenciais e as datas de suporte do Windows mais recentes" -Command "Update-WinForgeOnlineData"),
        (New-WinForgeNavItem -Id "app.logs" -Label "Pasta de logs e relatórios" -Group "Versão e dados" `
            -Description "Abre a pasta com os logs e os relatórios gerados" -Shortcut "LogFolder"),
        (New-WinForgeNavItem -Id "app.shortcut" -Label "Criar atalho do WinForge" -Group "Integração com o Windows" -Accent `
            -Keywords "fixar barra tarefas" `
            -Description "Coloca o WinForge, com o ícone dele, na Área de Trabalho ou no Menu Iniciar" -Command "New-WinForgeAppShortcut"),
        (New-WinForgeNavItem -Id "app.monitor" -Label "Monitor na bandeja" -Group "Integração com o Windows" `
            -Keywords "bandeja ícone relógio alertas avisos notificação notificações segundo plano vigiar" `
            -Description "Um ícone perto do relógio que avisa quando o disco enche, a proteção desliga ou falta manutenção" -Command "Set-WinForgeMonitor")
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


function Find-WinForgeNavReference {
    <#
    A primeira referência "Página > Item" de um texto (como em "Use Limpeza > Limpar o registro para..."), resolvida para
    o item da navegação, para o resumo da janela fazer dela um link. Devolve ItemId, Start e Length (o trecho
    "Página > Item" no texto), ou $null. Com dois itens que começam igual, vale o de nome mais longo.
    #>
    param ([AllowEmptyString()][string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text) -or $Text.IndexOf(" > ", [System.StringComparison]::Ordinal) -lt 0) { return $null }

    $best = $null

    foreach ($page in (Get-WinForgeNavigation)) {
        $prefix = "$($page.Title) > "
        $position = $Text.IndexOf($prefix, [System.StringComparison]::Ordinal)

        if ($position -lt 0) { continue }

        $rest = $Text.Substring($position + $prefix.Length)

        foreach ($item in @($page.Items)) {
            $label = [string]$item.Label

            if (-not $rest.StartsWith($label, [System.StringComparison]::Ordinal)) { continue }

            # O nome termina ali: "Limpar o registro" não casa com "Limpar o registro do Windows" se este não existir;
            # depois do nome vem fim de texto, espaço ou pontuação.
            $after = $rest.Substring($label.Length)
            if ($after.Length -gt 0 -and [char]::IsLetterOrDigit($after[0])) { continue }

            if ($null -eq $best -or $position -lt $best.Start -or ($position -eq $best.Start -and ($prefix.Length + $label.Length) -gt $best.Length)) {
                $best = [PSCustomObject]@{ ItemId = [string]$item.Id; Start = $position; Length = $prefix.Length + $label.Length }
            }
        }
    }

    return $best
}


# ---------------------------------------------------------------------------
# Busca (Ctrl+K na janela)
# ---------------------------------------------------------------------------

# O índice: os textos de todas as ações, atalhos, partes de página e ajustes, já normalizados, montado uma vez por sessão
# (a janela o prepara logo depois de aparecer, com o vocabulário da correção de digitação). Cada tecla só compara textos
# prontos: uma busca leva de 5 a 20 ms; uma com erro de digitação ou que só acha parte das palavras passa o índice mais
# duas ou três vezes. Montar o índice leva de 0,1 a 0,5 s (mais na primeira leitura do catálogo de ajustes).
$script:WinForgeSearchIndex = $null
$script:WinForgeSearchTweaks = $null
$script:WinForgeSearchEntries = $null
$script:WinForgeSearchAllText = ""
$script:WinForgeSearchPageIndex = $null
$script:WinForgeSearchVocabulary = $null
$script:WinForgeSearchCorrections = @{}
$script:WinForgeSearchSynonymMap = $null

# Uma busca usa no máximo estes caracteres e palavras: um texto colado por engano não trava a janela. O nome e a descrição
# mais longos da janela, juntos, têm menos de 170 caracteres.
$script:WinForgeSearchMaxLength = 200
$script:WinForgeSearchMaxWords = 8

# Acentos do português (e do espanhol/francês mais comuns). Tabela própria em vez de String.Normalize: funciona igual em
# qualquer edição do Windows e com a globalização reduzida.
$script:WinForgeAccentFrom = "áàâãäåéèêëíìîïóòôõöøúùûüçñýÿ"
$script:WinForgeAccentTo = "aaaaaaeeeeiiiioooooouuuucnyy"


function ConvertTo-WinForgeSearchText {
    # Minúsculas e sem acentos, para "limpeza", "LIMPEZA" e "limpêza" acharem o mesmo. Marcas de acento soltas (texto
    # decomposto, comum ao colar de outros programas) e caracteres invisíveis de formatação (hífen opcional, espaço de
    # largura zero, marca de direção do texto) são descartados: no meio de uma palavra, eles a partiriam em duas.
    param ([AllowEmptyString()][AllowNull()][string]$Text)

    if ([string]::IsNullOrEmpty($Text)) { return "" }

    $lower = $Text.ToLowerInvariant()

    # Texto só ASCII (a maioria) não precisa de tradução.
    if ($lower -notmatch '[^\x00-\x7F]') { return $lower }

    for ($i = 0; $i -lt $script:WinForgeAccentFrom.Length; $i++) {
        $lower = $lower.Replace($script:WinForgeAccentFrom[$i], $script:WinForgeAccentTo[$i])
    }

    return [regex]::Replace($lower, '[̀-ͯ\p{Cf}]', '')
}


function ConvertTo-WinForgeSearchWords {
    # As palavras do texto (letras e números sem acento, em minúsculas) separadas por um espaço: "Wi-Fi (DNS)" vira
    # "wi fi dns". Pontuação e símbolos nunca atrapalham o que a pessoa digitou.
    param ([AllowEmptyString()][AllowNull()][string]$Text)

    return ([regex]::Replace((ConvertTo-WinForgeSearchText -Text $Text), '[^a-z0-9]+', ' ')).Trim()
}


function Join-WinForgeSearchHyphens {
    # Uma palavra escrita com hífen vira uma só ("wi-fi" vira "wifi", "pré-instalados" vira "preinstalados"), como o
    # índice também guarda. Vale para o hífen comum e para os de texto colado (U+2010 e o sem quebra, U+2011). O texto já
    # vem sem acentos e em minúsculas (ConvertTo-WinForgeSearchText).
    param ([AllowEmptyString()][AllowNull()][string]$Text)

    if ([string]::IsNullOrEmpty($Text)) { return "" }

    return [regex]::Replace($Text, '(?<=[a-z0-9])[\-\u2010\u2011](?=[a-z0-9])', '')
}


function ConvertTo-WinForgeSearchIndexWords {
    # As palavras de um texto do índice. O que é escrito com hífen vale também junto, para "wifi" achar "Wi-Fi" e "hyperv"
    # achar "Hyper-V". Essas palavras extras vão no fim, depois das do texto.
    param ([AllowEmptyString()][AllowNull()][string]$Text)

    $plain = ConvertTo-WinForgeSearchText -Text $Text
    $words = ([regex]::Replace($plain, '[^a-z0-9]+', ' ')).Trim()
    $joined = @(foreach ($match in [regex]::Matches($plain, '[a-z0-9]+(-[a-z0-9]+)+')) { $match.Value.Replace("-", "") })

    if ($joined.Count -eq 0) { return $words }

    return "$words $($joined -join ' ')".Trim()
}


# Palavras de ligação que não ajudam a achar nada ("meu pc está lento", "o som não funciona", "deixar mais rápido"): saem
# da busca quando sobra outra palavra. "pc" e "computador" são opcionais: valem 1 ponto quando o texto tem a palavra
# inteira, mas não impedem o resultado.
$script:WinForgeSearchStopWords = @(
    "a", "o", "as", "os", "um", "uma", "uns", "umas", "de", "do", "da", "dos", "das", "em", "no", "na", "nos", "nas", "ao", "aos",
    "para", "pra", "por", "com", "sem", "e", "ou", "que", "se", "eu", "me", "meu", "minha", "meus", "minhas", "como", "esta", "estao",
    "estou", "ta", "muito", "muita", "mais", "nao", "funciona", "funcionando", "funcionou", "sozinho", "sozinha", "pouco", "pouca",
    "deixar", "deixa", "ficar", "fica", "ficou", "quando", "quero", "preciso", "fazer", "isso", "esse", "essa", "tem", "ele", "ela",
    "consigo", "conseguir", "consegue", "posso", "pode", "qual", "quais", "melhorar", "aumentar"
)
$script:WinForgeSearchSoftWords = @("pc", "computador")

# Prefixos que invertem o sentido: um pedaço depois deles não conta como achado ("ativar" em "desativar").
$script:WinForgeSearchNegations = @("des", "re", "in", "im", "dis")

# Palavras que a busca trata como parecidas (cada grupo vale em todos os sentidos). O sinônimo vale 4 pontos a menos que
# a própria palavra: no rótulo, ele fica abaixo da palavra exata em qualquer ponto do rótulo.
$script:WinForgeSearchSynonymPenalty = 4
$script:WinForgeSearchSynonyms = @(
    "desativar desabilitar ocultar esconder",
    "ativar habilitar",
    "apagar excluir deletar",
    "consertar reparar corrigir arrumar",
    "travando travado travou trava congelando congelado congelou congela",
    "lento lenta devagar lerdo lerda",
    "app apps aplicativo aplicativos"
)

# Palavras extras de cada ajuste do Windows (o catálogo de ajustes não tem campo de palavras-chave). Um teste confere
# que todos os Ids existem.
$script:WinForgeSearchTweakKeywords = @{
    "file-extensions"      = "extensao tipo exe pdf nome do arquivo"
    "hidden-files"         = "ocultos ocultas escondidos escondidas invisiveis pastas"
    "taskbar-left"         = "iniciar alinhar centralizar windows 11"
    "classic-context-menu" = "botao direito mostrar mais opcoes windows 11"
    "dark-mode"            = "dark mode theme tema escuro noite aparencia cores"
    "no-transparency"      = "efeitos acrilico visual leve desempenho"
    "show-seconds"         = "hora relogio"
    "hide-widgets"         = "noticias clima painel windows 11"
    "hide-copilot"         = "ia inteligencia artificial assistente windows 11"
    "tips-suggestions"     = "anuncios propaganda sugestoes notificacoes telemetria"
    "lock-screen-tips"     = "bloqueio lock screen spotlight anuncios"
    "explorer-recent"      = "acesso rapido recentes frequentes historico privacidade arquivos abertos"
    "explorer-sync-ads"    = "anuncios propaganda onedrive microsoft 365 avisos sincronizacao"
    "search-highlights"    = "pesquisa busca destaques ilustracoes noticias datas"
    "storage-sense"        = "sensor armazenamento espaco disco cheio limpeza automatica lixeira temporarios"
    "background-apps"      = "segundo plano aplicativos memoria bateria windows 10"
    "advertising-id"       = "publicidade anuncios rastreamento telemetria privacidade"
    "bing-start"           = "pesquisa web internet busca menu iniciar"
    "recall"               = "ia captura de tela historico privacidade copilot"
    "game-bar"             = "jogo jogos gamer xbox gravacao fps"
    "fast-startup"         = "inicializacao rapida hibrida desligar lento boot"
    "high-performance"     = "plano de energia alto desempenho velocidade"
    "pcie-aspm"            = "pcie pci express placa de video ssd travamento energia"
    "no-sleep-timeouts"    = "suspender tela apagar dormir energia"
    "hibernation"          = "hiberfil espaco disco hibernar"
    "explorer-this-pc"     = "este computador meu pc acesso rapido explorador abrir"
    "taskbar-end-task"     = "finalizar tarefa travado travou fechar programa windows 11"
    "autoplay-off"         = "reproducao automatica autorun pendrive usb seguranca"
    "taskbar-search"       = "caixa busca pesquisar lupa esconder espaco"
    "task-view-button"     = "multitarefa desktops virtuais esconder"
    "start-recommendations" = "recomendados recomendacoes menu iniciar sugestoes windows 11"
    "tailored-experiences" = "experiencias personalizadas privacidade dados de diagnostico anuncios"
    "feedback-requests"    = "feedback opiniao pesquisa avaliacao notificacoes"
    "activity-history"     = "historico de atividades linha do tempo timeline privacidade"
    "diagnostic-data"      = "telemetria dados de diagnostico privacidade coleta envio microsoft"
    "app-tracking"         = "rastreamento programas mais usados menu iniciar privacidade"
    "online-speech"        = "voz fala ditado reconhecimento privacidade cortana"
    "inking-typing"        = "digitacao teclado caneta escrita dicionario privacidade"
    "delivery-peers"       = "otimizacao de entrega p2p compartilhar atualizacoes banda internet"
    "early-updates"        = "windows update novidades antecipadas antes previa preview instabilidade recursos assim que saem"
    "gpu-scheduling"       = "hags placa de video gpu jogos latencia agendamento"
    "taskbar-never-combine" = "agrupar combinar desagrupar botoes janelas rotulos nomes windows 11"
    "desktop-recycle-bin"  = "lixeira icone area de trabalho esconder remover"
    "desktop-this-pc"      = "este computador meu icone area de trabalho"
    "accent-taskbar"       = "cor de destaque colorir barra iniciar"
    "accent-titlebars"     = "cor de destaque colorir janelas bordas titulo"
    "lock-screen-widgets"  = "bloqueio lock screen clima noticias cotacoes widgets"
    "lock-screen-notifications" = "bloqueio lock screen avisos notificacoes privacidade"
    "notifications-off"    = "avisos notificacoes silenciar desativar toast balao"
    "sticky-keys-shortcut" = "teclas de aderencia shift cinco vezes acessibilidade jogos filtragem alternancia"
    "clipboard-history"    = "area de transferencia copiar colar windows v historico"
    "game-mode"            = "modo de jogo jogos gamer desempenho fps"
    "mouse-acceleration"   = "mouse aceleracao precisao do ponteiro mira jogos fps"
}


function Get-WinForgeSearchStem {
    # O começo de uma palavra sem a terminação mais comum do português, para "iniciar" achar "inicialização", "limpar"
    # achar "limpeza" e "programas" achar "programa". Vazio quando sobraria menos de 4 letras.
    param ([string]$Token)

    foreach ($suffix in @("acoes", "acao", "mentos", "mento", "ando", "endo", "indo", "ados", "adas", "ado", "ada", "idos", "idas", "ido", "ida", "ar", "er", "ir", "am", "em", "s")) {
        if ($Token.Length -ge ($suffix.Length + 4) -and $Token.EndsWith($suffix)) {
            return $Token.Substring(0, $Token.Length - $suffix.Length)
        }
    }

    return ""
}


function Get-WinForgeSearchBase {
    # O singular simples de uma palavra de 5 letras ou mais terminada em "s" ("erros" vira "erro", "drivers" vira "driver"):
    # o começo do singular acha as duas formas. As demais palavras ficam como estão.
    param ([string]$Token)

    if ($Token.Length -ge 5 -and $Token.EndsWith("s") -and -not $Token.EndsWith("ss")) { return $Token.Substring(0, $Token.Length - 1) }

    return $Token
}


function Get-WinForgeSearchSynonyms {
    # Os sinônimos de uma palavra (sem ela mesma), da tabela WinForgeSearchSynonyms.
    param ([string]$Token)

    if ($null -eq $script:WinForgeSearchSynonymMap) {
        $map = @{}

        foreach ($group in $script:WinForgeSearchSynonyms) {
            $words = @($group -split ' ')

            foreach ($word in $words) { $map[$word] = @($words | Where-Object { $_ -ne $word }) }
        }

        $script:WinForgeSearchSynonymMap = $map
    }

    $found = $script:WinForgeSearchSynonymMap[$Token]

    if ($null -eq $found) { return @() }

    return @($found)
}


function New-WinForgeSearchEntry {
    param (
        [Parameter(Mandatory)][string]$Kind,
        [Parameter(Mandatory)][string]$PageId,
        [Parameter(Mandatory)][string]$PageTitle,
        [Parameter(Mandatory)][string]$Label,
        [string]$Description = "",
        [string]$Keywords = "",
        [string]$PageText = "",
        $Item = $null,
        $Tweak = $null,
        [string]$Section = "",
        [int]$Order = 0,

        # Desempate entre resultados de mesma pontuação: 1 para as ações do WinForge e as partes de página, 2 para os atalhos
        # que só abrem uma janela do Windows, 3 para os ajustes (as páginas, que vêm pelo título, têm 0).
        [int]$Rank = 1
    )

    # O que a entrada abre: duas entradas com o mesmo destino (a mesma ação em duas páginas) aparecem uma vez só.
    $target = switch ($Kind) {
        "Item" { $(if ($Item.Kind -eq "Shortcut") { "shortcut:$($Item.Shortcut)" } else { "command:$($Item.Command)" }) }
        "Tweak" { "tweak:$($Tweak.Id)" }
        default { "section:$PageId.$Section" }
    }

    # Os textos levam um espaço em cada ponta: " palavra" acha o começo de uma palavra, "palavra" acha em qualquer ponto.
    # All junta os quatro: uma palavra que não está nele não está em nenhum (a busca pula a entrada com uma comparação só).
    $labelWords = " $(ConvertTo-WinForgeSearchIndexWords -Text $Label) "
    $descWords = " $(ConvertTo-WinForgeSearchIndexWords -Text $Description) "
    $keyWords = " $(ConvertTo-WinForgeSearchIndexWords -Text $Keywords) "
    $pageWords = " $(ConvertTo-WinForgeSearchIndexWords -Text $PageText) "

    return [PSCustomObject]@{
        Kind        = $Kind
        PageId      = $PageId
        PageTitle   = $PageTitle
        Label       = $Label
        Description = $Description
        Item        = $Item
        Tweak       = $Tweak
        Section     = $Section
        Order       = $Order
        Rank        = $Rank
        Target      = $target
        LabelPlain  = " $(ConvertTo-WinForgeSearchWords -Text $Label) "
        LabelGlued  = " $(([regex]::Replace((Join-WinForgeSearchHyphens -Text (ConvertTo-WinForgeSearchText -Text $Label)), '[^a-z0-9]+', ' ')).Trim()) "
        LabelWords  = $labelWords
        DescWords   = $descWords
        KeyWords    = $keyWords
        PageWords   = $pageWords
        All         = "$labelWords$keyWords$descWords$pageWords"
    }
}


function Get-WinForgeSearchSections {
    # Partes de uma página que a busca acha pelo nome, além das ações: a Aparência de Sobre o WinForge é um quadro da
    # página, e não uma ação, mas é o que a pessoa procura com "tema" ou "modo escuro".
    return @(
        [PSCustomObject]@{
            Id          = "appearance"
            PageId      = "app"
            Label       = "Aparência do WinForge"
            Description = "Claro, escuro ou automático, acompanhando o tema do Windows"
            Keywords    = "tema modo escuro claro noturno cores automatico"
        }
    )
}


function Get-WinForgeSearchTweakEntries {
    # Os ajustes do Windows que a página de ajustes mostra neste Windows (um ajuste do Windows 11 no 10, ou o botão do
    # Copilot na 24H2, levaria a uma página sem ele). Sem o catálogo (módulo ausente), nenhum: a busca tenta de novo na
    # próxima vez. Um ajuste com defeito fica de fora sozinho.
    try {
        $catalog = @(Get-WinForgeTweakCatalog)
    }
    catch {
        Write-Verbose "Busca sem os ajustes do Windows: $($_.Exception.Message)"
        return @()
    }

    $entries = New-Object System.Collections.ArrayList
    $order = 100000

    foreach ($tweak in $catalog) {
        $order++

        try {
            if (-not (Test-WinForgeTweakAvailable -Tweak $tweak)) { continue }

            # Cada ajuste leva à página dele: a Personalização ou os Ajustes do Windows.
            $pageId = Get-WinForgeTweakPageId -Tweak $tweak
            $page = Get-WinForgeNavPage -Id $pageId
            $title = $(if ($null -ne $page) { [string]$page.Title } else { "Ajustes do Windows" })
            $extra = [string]$script:WinForgeSearchTweakKeywords[[string]$tweak.Id]

            # O cartão diz o que a página mostra (o recurso do Windows e o que ele é); o nome do ajuste ("Desativar...")
            # também acha o cartão, entre as palavras de busca.
            $feature = [string](Get-WinForgeTweakField -Entry $tweak -Name "Feature" -Default $tweak.Name)
            $about = [string](Get-WinForgeTweakField -Entry $tweak -Name "About" -Default $tweak.Description)

            [void]$entries.Add((New-WinForgeSearchEntry -Kind "Tweak" -PageId $pageId -PageTitle $title -Label $feature `
                        -Description $about -Keywords "$extra $($tweak.Name)" -PageText "$($title.ToLowerInvariant()) $($tweak.Category)" -Tweak $tweak -Order $order -Rank 3))
        }
        catch {
            Write-Verbose "Busca: o ajuste $($tweak.Id) ficou de fora: $($_.Exception.Message)"
        }
    }

    return @($entries)
}


function Get-WinForgeSearchIndex {
    # As entradas pesquisáveis, na ordem em que empatam: ações e atalhos de todas as páginas (na ordem da barra lateral),
    # as partes de página que a busca acha (a Aparência) e, por último, os ajustes do Windows.
    if ($null -eq $script:WinForgeSearchIndex) {
        $entries = New-Object System.Collections.ArrayList
        $order = 0

        foreach ($page in (Get-WinForgeNavigation)) {
            foreach ($item in $page.Items) {
                $order++
                $rank = $(if ($item.Kind -eq "Shortcut") { 2 } else { 1 })

                [void]$entries.Add((New-WinForgeSearchEntry -Kind "Item" -PageId $page.Id -PageTitle $page.Title -Label $item.Label `
                            -Description $item.Description -Keywords $item.Keywords -PageText $page.Title -Item $item -Order $order -Rank $rank))
            }
        }

        foreach ($section in (Get-WinForgeSearchSections)) {
            $order++
            $page = Get-WinForgeNavPage -Id $section.PageId

            if ($null -eq $page) { continue }

            [void]$entries.Add((New-WinForgeSearchEntry -Kind "Page" -PageId $page.Id -PageTitle $page.Title -Label $section.Label `
                        -Description $section.Description -Keywords $section.Keywords -PageText $page.Title -Section $section.Id -Order $order))
        }

        $script:WinForgeSearchIndex = @($entries)
        $script:WinForgeSearchEntries = $null
    }

    if ($null -eq $script:WinForgeSearchTweaks) {
        $tweaks = @(Get-WinForgeSearchTweakEntries)

        if ($tweaks.Count -gt 0) {
            $script:WinForgeSearchTweaks = $tweaks
            $script:WinForgeSearchEntries = $null
        }
    }

    if ($null -eq $script:WinForgeSearchEntries) {
        $all = @($script:WinForgeSearchIndex)

        if ($null -ne $script:WinForgeSearchTweaks) { $all += $script:WinForgeSearchTweaks }

        $script:WinForgeSearchEntries = $all
        $script:WinForgeSearchAllText = (@($all | ForEach-Object { $_.All }) -join "")
        $script:WinForgeSearchVocabulary = $null
        $script:WinForgeSearchCorrections = @{}
    }

    return $script:WinForgeSearchEntries
}


function Get-WinForgeSearchPages {
    # As páginas que a busca sabe abrir: o Início e as da tabela de navegação (inclusive a do rodapé).
    $pages = @([PSCustomObject]@{ Id = "home"; Title = "Início"; Summary = "O estado do PC, a nota de saúde e os atalhos mais procurados." })

    foreach ($page in (Get-WinForgeNavigation)) {
        $pages += [PSCustomObject]@{ Id = $page.Id; Title = $page.Title; Summary = $page.Summary }
    }

    return $pages
}


function Get-WinForgeSearchPageIndex {
    # As páginas com o título já normalizado (Words) e a primeira palavra dele, montadas uma vez.
    if ($null -eq $script:WinForgeSearchPageIndex) {
        $order = -1000

        $script:WinForgeSearchPageIndex = @(
            foreach ($page in (Get-WinForgeSearchPages)) {
                $order++
                $words = ConvertTo-WinForgeSearchWords -Text $page.Title

                [PSCustomObject]@{
                    Id = $page.Id; Title = $page.Title; Summary = $page.Summary; Words = $words; FirstWord = ($words -split ' ')[0]; Order = $order
                }
            }
        )
    }

    return $script:WinForgeSearchPageIndex
}


function Get-WinForgeSearchVocabulary {
    # As palavras do índice com 4 letras ou mais, agrupadas pela primeira letra, cada uma com um peso (rótulo e
    # palavras-chave pesam mais que descrição e página). A correção de digitação procura aqui a palavra mais parecida.
    $entries = Get-WinForgeSearchIndex

    if ($null -ne $script:WinForgeSearchVocabulary) { return $script:WinForgeSearchVocabulary }

    $weights = @{}

    foreach ($entry in $entries) {
        foreach ($field in @(@($entry.LabelWords, 3), @($entry.KeyWords, 3), @($entry.DescWords, 1), @($entry.PageWords, 1))) {
            foreach ($word in ([string]$field[0]).Split([char]32)) {
                if ($word.Length -ge 4) { $weights[$word] = [int]$weights[$word] + [int]$field[1] }
            }
        }
    }

    foreach ($page in (Get-WinForgeSearchPageIndex)) {
        foreach ($word in $page.Words.Split([char]32)) {
            if ($word.Length -ge 4) { $weights[$word] = [int]$weights[$word] + 3 }
        }
    }

    foreach ($group in $script:WinForgeSearchSynonyms) {
        foreach ($word in ($group -split ' ')) {
            if ($word.Length -ge 4) { $weights[$word] = [int]$weights[$word] + 1 }
        }
    }

    $byLetter = @{}

    foreach ($word in ($weights.Keys | Sort-Object)) {
        $letter = [string]$word[0]

        if (-not $byLetter.ContainsKey($letter)) { $byLetter[$letter] = New-Object System.Collections.ArrayList }

        [void]$byLetter[$letter].Add([PSCustomObject]@{ Word = $word; Weight = $weights[$word] })
    }

    $script:WinForgeSearchVocabulary = $byLetter

    return $byLetter
}


function Get-WinForgeSearchCorrection {
    <#
    A palavra do índice mais parecida com uma que não aparece em lugar nenhum ("limpesa" vira "limpeza", "antevirus" vira
    "antivirus"). Só corrige palavras de 6 letras ou mais, com as mesmas duas primeiras letras, e aceita 1 letra trocada,
    sobrando, faltando ou invertida com a vizinha (2 nas palavras de 9 letras ou mais). A palavra do índice pode ser maior
    (quem ainda está digitando: "atualisa" acha "atualizar"), mas só 1 letra menor, e só nas palavras de 8 letras ou mais:
    "filmes" não vira "files" nem "carregador" vira "carregar". Empate: a palavra mais usada no índice. Vazio quando
    nenhuma serve. A resposta de cada palavra fica guardada até o índice mudar.
    #>
    param ([Parameter(Mandatory)][AllowEmptyString()][string]$Token)

    if ($Token.Length -lt 6 -or $Token -notmatch '^[a-z]+$') { return "" }

    $vocabulary = Get-WinForgeSearchVocabulary

    if ($script:WinForgeSearchCorrections.ContainsKey($Token)) { return [string]$script:WinForgeSearchCorrections[$Token] }

    $candidates = $vocabulary[[string]$Token[0]]
    $best = ""

    if ($null -ne $candidates) {
        $n = $Token.Length
        $limit = $(if ($n -ge 9) { 2 } else { 1 })
        $width = $n + $limit + 1
        $before = [int[]]::new($width)
        $previous = [int[]]::new($width)
        $current = [int[]]::new($width)
        $bestDistance = $limit + 1
        $bestWeight = 0

        foreach ($candidate in $candidates) {
            $word = [string]$candidate.Word

            if ($word[1] -cne $Token[1]) { continue }
            if ($word.Length -lt $n -and -not ($n -ge 8 -and $word.Length -eq $n - 1)) { continue }

            # Distância de Damerau (alinhamento ótimo) entre a palavra digitada e os começos da palavra do índice de n a
            # n + limit letras (ou a palavra inteira, quando ela é menor).
            $other = $(if ($word.Length -gt $n + $limit) { $word.Substring(0, $n + $limit) } else { $word })
            $m = $other.Length

            for ($j = 0; $j -le $m; $j++) { $previous[$j] = $j }

            $rowMin = 0
            $lastRowMin = 0

            for ($i = 1; $i -le $n; $i++) {
                $current[0] = $i
                $rowMin = $i
                $a = $Token[$i - 1]

                for ($j = 1; $j -le $m; $j++) {
                    $b = $other[$j - 1]
                    $value = $previous[$j - 1] + $(if ($a -ceq $b) { 0 } else { 1 })

                    if ($previous[$j] + 1 -lt $value) { $value = $previous[$j] + 1 }
                    if ($current[$j - 1] + 1 -lt $value) { $value = $current[$j - 1] + 1 }

                    if ($i -gt 1 -and $j -gt 1 -and $a -ceq $other[$j - 2] -and $Token[$i - 2] -ceq $b -and $before[$j - 2] + 1 -lt $value) {
                        $value = $before[$j - 2] + 1
                    }

                    $current[$j] = $value
                    if ($value -lt $rowMin) { $rowMin = $value }
                }

                if ($rowMin -gt $limit -and $lastRowMin -gt $limit) { break }

                $lastRowMin = $rowMin
                $swap = $before
                $before = $previous
                $previous = $current
                $current = $swap
            }

            if ($rowMin -gt $limit) { continue }

            # A última linha completa ficou em $previous: vale o melhor começo de n letras ou mais (ou a palavra inteira).
            $distance = $limit + 1

            for ($j = [Math]::Min($n, $m); $j -le $m; $j++) {
                if ($previous[$j] -lt $distance) { $distance = $previous[$j] }
            }

            # Uma palavra do índice menor que a digitada só vale com 1 letra de diferença.
            if ($m -lt $n -and $distance -gt 1) { continue }
            if ($distance -gt $limit -or $distance -eq 0) { continue }

            if ($distance -lt $bestDistance -or ($distance -eq $bestDistance -and [int]$candidate.Weight -gt $bestWeight)) {
                $best = $word
                $bestDistance = $distance
                $bestWeight = [int]$candidate.Weight
            }
        }
    }

    $script:WinForgeSearchCorrections[$Token] = $best

    return $best
}


function Test-WinForgeSearchKnown {
    # A palavra aparece em algum texto do índice (inteira, no meio de outra, pelo singular ou pelo radical) ou tem
    # sinônimos: não é erro de digitação.
    param ([Parameter(Mandatory)][string]$Token)

    [void](Get-WinForgeSearchIndex)
    $all = $script:WinForgeSearchAllText

    if ($all.Contains($Token)) { return $true }

    $base = Get-WinForgeSearchBase -Token $Token
    if ($base -ne $Token -and $all.Contains(" $base")) { return $true }

    $stem = Get-WinForgeSearchStem -Token $Token
    if ($stem -and $all.Contains(" $stem")) { return $true }

    return (@(Get-WinForgeSearchSynonyms -Token $Token).Count -gt 0)
}


function Test-WinForgeSearchInside {
    # A palavra aparece no meio de outra do texto, mas não logo depois de um prefixo que inverte o sentido: "ativar" não
    # acha "desativar", "fazer" não acha "desfazer" e "iniciar" não acha "reiniciar"; "virus" acha "antivirus".
    param ([string]$Text, [string]$Token)

    $index = $Text.IndexOf($Token, [System.StringComparison]::Ordinal)

    while ($index -ge 0) {
        $wordStart = $Text.LastIndexOf([char]32, $index) + 1
        $prefix = $Text.Substring($wordStart, $index - $wordStart)

        if ($prefix.Length -gt 0 -and $prefix -notin $script:WinForgeSearchNegations) { return $true }

        $index = $Text.IndexOf($Token, $index + 1, [System.StringComparison]::Ordinal)
    }

    return $false
}


function Get-WinForgeSearchQuery {
    # O texto digitado pronto para a busca: Words (as palavras, sem repetir, para o bônus do nome exato), Tokens (as que
    # contam: sem as de ligação, quando sobra outra) e Hard (quantas são obrigatórias; "pc" e "computador" não são).
    # Uma palavra com hífen vale como uma só ("wi-fi" é "wifi"), e Joined diz que houve uma; -SplitHyphens separa as
    # partes ("limpeza-rápida", quando o hífen não era de uma palavra composta). $null quando não há o que buscar:
    # vazio, só símbolos ou uma letra só.
    param (
        [AllowEmptyString()][AllowNull()][string]$Query,
        [switch]$SplitHyphens
    )

    if ([string]::IsNullOrEmpty($Query)) { return $null }

    if ($Query.Length -gt $script:WinForgeSearchMaxLength) { $Query = $Query.Substring(0, $script:WinForgeSearchMaxLength) }

    $plain = ConvertTo-WinForgeSearchText -Text $Query
    $joined = $false

    if (-not $SplitHyphens) {
        $glued = Join-WinForgeSearchHyphens -Text $plain
        $joined = ($glued -ne $plain)
        $plain = $glued
    }

    $words = ([regex]::Replace($plain, '[^a-z0-9]+', ' ')).Trim()

    if ($words.Replace(" ", "").Length -lt 2) { return $null }

    # Palavra repetida vale uma vez só.
    $seen = New-Object 'System.Collections.Generic.HashSet[string]'
    $unique = @(foreach ($word in $words.Split([char]32)) { if ($seen.Add($word)) { $word } })
    $unique = @($unique | Select-Object -First $script:WinForgeSearchMaxWords)
    $meaningful = @($unique | Where-Object { $_ -notin $script:WinForgeSearchStopWords })

    # Só palavras de ligação ("de", "para"): valem como estão, para quem ainda está digitando "desinstalar".
    $tokens = @(if ($meaningful.Count -gt 0) { $meaningful } else { $unique })
    $hard = @($tokens | Where-Object { $_ -notin $script:WinForgeSearchSoftWords })

    # Só "pc" ou "computador": elas mesmas são o que se procura.
    if ($hard.Count -eq 0) { $hard = @($tokens) }

    return [PSCustomObject]@{
        Words = ($unique -join ' '); Phrase = ($tokens -join ' '); All = $unique; Tokens = @($tokens); Hard = $hard.Count; Meaningful = $meaningful.Count
        Joined = $joined
    }
}


function New-WinForgeSearchSpecs {
    # Como procurar cada palavra: as formas que valem (a própria palavra; o singular simples, que vale 1 ponto a menos, e
    # os sinônimos, 4 a menos), se ela é opcional ("pc" com outra palavra) e se é curta (uma ou duas letras) e não a última
    # da frase: aí ela só vale como palavra inteira ("wi" em "wi fi" não acha "Windows"). A última pode estar sendo
    # digitada e vale pelo começo, como uma palavra sozinha.
    param ([string[]]$Tokens)

    # "pc" e "computador" só são opcionais quando há outra palavra que conta.
    $soft = (@($Tokens | Where-Object { $_ -notin $script:WinForgeSearchSoftWords }).Count -gt 0)
    $last = $(if (@($Tokens).Count -gt 0) { [string]@($Tokens)[-1] } else { "" })

    return @(
        foreach ($token in $Tokens) {
            $base = Get-WinForgeSearchBase -Token $token
            $stem = Get-WinForgeSearchStem -Token $token
            if ($stem -eq $base) { $stem = "" }

            # Probe: o pedaço que precisa estar no texto para qualquer forma de achar valer (o radical é o começo da palavra).
            $variants = @([PSCustomObject]@{
                    Start = " $token"; Whole = " $token "; Token = $token; Inside = ($token.Length -ge 5)
                    Stem = $(if ($stem) { " $stem" } else { "" }); Penalty = 0; Probe = $(if ($stem) { $stem } else { $token })
                })

            if ($base -ne $token) {
                $variants += [PSCustomObject]@{ Start = " $base"; Whole = " $base "; Token = $base; Inside = $false; Stem = ""; Penalty = 1; Probe = " $base" }
            }

            foreach ($synonym in (Get-WinForgeSearchSynonyms -Token $token)) {
                $variants += [PSCustomObject]@{
                    Start = " $synonym"; Whole = " $synonym "; Token = $synonym; Inside = $false; Stem = ""; Penalty = $script:WinForgeSearchSynonymPenalty; Probe = " $synonym"
                }
            }

            [PSCustomObject]@{
                Token = $token; Soft = ($soft -and $token -in $script:WinForgeSearchSoftWords); Variants = $variants
                Short = ($token.Length -le 2); Last = ($token -eq $last)
            }
        }
    )
}


function Find-WinForgeSearchHits {
    <#
    Uma passada pelo índice e pelos títulos das páginas. A pontuação de cada palavra é a do melhor lugar em que ela
    aparece (do maior para o menor):
      17/16  começo do rótulo (17 com a palavra inteira)       9  radical no rótulo ("limp" de limpar)
      13/12  começo de outra palavra do rótulo               9/8  palavras-chave (9 com a palavra inteira)
       7     no meio de uma palavra do rótulo (5+ letras)      6  radical nas palavras-chave
       5     descrição; 4 radical; 3 no meio dela              3  título da página; 2 no meio ou radical
    O singular simples vale 1 a menos, e um sinônimo, 4 a menos. O nome exato do item ganha 20; uma frase inteira das palavras-chave,
    10 (5 quando a frase só bate sem as palavras de ligação). "pc" soma 1 quando
    o texto tem a palavra. Uma página cujo título começa com a busca vale 40 (60 com o título inteiro): acima de qualquer
    item de até três palavras. Sem -Partial, todas as palavras obrigatórias precisam aparecer; com ele, basta uma. Uma
    palavra de uma ou duas letras que não é a última (e qualquer uma delas com -Partial) só vale inteira.
    #>
    param (
        [Parameter(Mandatory)]$Query,
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Specs,
        [switch]$Partial
    )

    $words = [string]$Query.Words
    $phrase = " $($Query.Phrase) "
    $multiWord = $words.Contains(" ")
    $multiPhrase = ([string]$Query.Phrase).Contains(" ")
    $found = New-Object System.Collections.ArrayList

    foreach ($entry in (Get-WinForgeSearchIndex)) {
        $total = 0
        $matched = 0
        $missing = $false
        $label = $entry.LabelWords

        foreach ($spec in $Specs) {
            if ($spec.Soft) {
                $whole = " $($spec.Token) "
                if ($label.Contains($whole) -or $entry.KeyWords.Contains($whole) -or $entry.DescWords.Contains($whole)) { $total += 1 }
                continue
            }

            $best = 0

            # Curta e no meio da frase (ou numa busca por parte das palavras): só a palavra inteira vale.
            $wholeOnly = ($spec.Short -and ($Partial -or -not $spec.Last))

            foreach ($variant in $spec.Variants) {
                if (-not $entry.All.Contains($variant.Probe)) { continue }

                $start = $variant.Start
                $value = 0

                if ($wholeOnly) {
                    $whole = $variant.Whole

                    if ($label.Contains($whole)) { $value = $(if ($label.StartsWith($whole)) { 17 } else { 13 }) }
                    elseif ($entry.KeyWords.Contains($whole)) { $value = 9 }
                    elseif ($entry.DescWords.Contains($whole)) { $value = 5 }
                    elseif ($entry.PageWords.Contains($whole)) { $value = 3 }
                }
                elseif ($label.Contains($start)) {
                    $value = $(if ($label.StartsWith($start)) { 16 } else { 12 })
                    if ($label.Contains($variant.Whole)) { $value += 1 }
                }
                elseif ($variant.Stem -and $label.Contains($variant.Stem)) { $value = 9 }
                elseif ($entry.KeyWords.Contains($start)) { $value = $(if ($entry.KeyWords.Contains($variant.Whole)) { 9 } else { 8 }) }
                elseif ($variant.Inside -and $label.Contains($variant.Token) -and (Test-WinForgeSearchInside -Text $label -Token $variant.Token)) { $value = 7 }
                elseif ($variant.Stem -and $entry.KeyWords.Contains($variant.Stem)) { $value = 6 }
                elseif ($entry.DescWords.Contains($start)) { $value = 5 }
                elseif ($variant.Stem -and $entry.DescWords.Contains($variant.Stem)) { $value = 4 }
                elseif ($variant.Inside -and $entry.DescWords.Contains($variant.Token) -and (Test-WinForgeSearchInside -Text $entry.DescWords -Token $variant.Token)) { $value = 3 }
                elseif ($entry.PageWords.Contains($start)) { $value = 3 }
                elseif ($variant.Inside -and $entry.PageWords.Contains($variant.Token) -and (Test-WinForgeSearchInside -Text $entry.PageWords -Token $variant.Token)) { $value = 2 }
                elseif ($variant.Stem -and $entry.PageWords.Contains($variant.Stem)) { $value = 2 }

                # Vale a forma que acha melhor: a palavra exata nas palavras-chave (8) perde para o sinônimo no rótulo (15).
                if ($value -gt 0) {
                    $value = [Math]::Max(1, $value - [int]$variant.Penalty)
                    if ($value -gt $best) { $best = $value }
                }
            }

            if ($best -eq 0) {
                if ($Partial) { continue }

                $missing = $true
                break
            }

            $matched++
            $total += $best
        }

        if ($missing -or $matched -eq 0) { continue }

        if ($entry.LabelPlain -eq " $words " -or $entry.LabelGlued -eq " $words ") { $total += 20 }
        elseif ($multiWord -and $entry.KeyWords.Contains(" $words ")) { $total += 10 }
        elseif ($multiPhrase -and $entry.KeyWords.Contains($phrase)) { $total += 5 }

        [void]$found.Add([PSCustomObject]@{
                Kind = $entry.Kind; PageId = $entry.PageId; PageTitle = $entry.PageTitle; Label = $entry.Label
                Description = $entry.Description; Item = $entry.Item; Tweak = $entry.Tweak; Section = $entry.Section
                Score = $total; Matched = $matched; Rank = $entry.Rank; Order = $entry.Order; Target = $entry.Target
                Partial = [bool]$Partial; Corrected = ""
            })
    }

    if (-not $Partial -and $words.Length -ge 2) {
        # Uma busca de uma palavra só (fora "pc") acha também a página pelo singular ou pelo radical: "redes" acha Rede,
        # "limpar" acha Limpeza e "atualizar" acha Atualizações. O Início fica de fora ("iniciar" é de inicialização).
        $single = $(if ($Query.Hard -eq 1) { @($Specs | Where-Object { -not $_.Soft })[0] } else { $null })
        $alternatives = @()

        if ($null -ne $single) {
            $alternatives = @($single.Token, (Get-WinForgeSearchBase -Token $single.Token), $single.Variants[0].Stem.Trim()) | Where-Object { $_.Length -ge 4 }
        }

        foreach ($page in (Get-WinForgeSearchPageIndex)) {
            $score = 0

            if ($page.Words.StartsWith($words)) { $score = $(if ($page.Words -eq $words) { 60 } else { 40 }) }
            elseif ($page.Id -ne "home") {
                foreach ($alternative in $alternatives) {
                    if ($page.FirstWord.StartsWith($alternative)) { $score = 40; break }
                }
            }

            if ($score -gt 0) {
                [void]$found.Add([PSCustomObject]@{
                        Kind = "Page"; PageId = $page.Id; PageTitle = $page.Title; Label = $page.Title; Description = $page.Summary
                        Item = $null; Tweak = $null; Section = ""; Score = $score; Matched = $Query.Hard; Rank = 0; Order = $page.Order
                        Target = "page:$($page.Id)"; Partial = $false; Corrected = ""
                    })
            }
        }
    }

    return , $found
}


function Search-WinForgeNavigation {
    <#
    Procura nas ações, atalhos, páginas e ajustes do Windows pelo texto digitado (pontuação em Find-WinForgeSearchHits).
    Quando nada tem todas as palavras, a busca tenta, nesta ordem: separar as partes de uma palavra com hífen
    ("limpeza-rápida"), trocar uma palavra que não existe no índice pela mais parecida (erro de digitação; Corrected diz a busca corrigida) e aceitar o que tem parte das palavras (Partial, com
    os que têm mais palavras primeiro). A mesma ação em duas páginas aparece uma vez só. Devolve Kind (Item | Tweak |
    Page), PageId, PageTitle, Label, Description, Item (ou Tweak), Section, Score, Rank, Order, Partial e Corrected, do
    melhor para o pior; empates: o caminho recomendado da página, depois as ações, os atalhos do Windows e os ajustes, e
    então a ordem das páginas. -First limita a quantidade.
    #>
    param (
        [AllowEmptyString()][AllowNull()][string]$Query,
        [int]$First = 0
    )

    $prepared = Get-WinForgeSearchQuery -Query $Query

    if ($null -eq $prepared) { return @() }

    $hits = Find-WinForgeSearchHits -Query $prepared -Specs (New-WinForgeSearchSpecs -Tokens $prepared.Tokens)
    $corrected = ""

    # Um hífen que não era de palavra composta ("limpeza-rápida"): as partes, separadas, acham o que a pessoa quis dizer.
    if ($hits.Count -eq 0 -and $prepared.Joined) {
        $split = Get-WinForgeSearchQuery -Query $Query -SplitHyphens

        if ($null -ne $split) {
            $splitHits = Find-WinForgeSearchHits -Query $split -Specs (New-WinForgeSearchSpecs -Tokens $split.Tokens)

            if ($splitHits.Count -gt 0) {
                $prepared = $split
                $hits = $splitHits
            }
        }
    }

    if ($hits.Count -eq 0) {
        # Uma palavra que não aparece em lugar nenhum do índice pode ser erro de digitação: vale a mais parecida. Com mais
        # de duas palavras desconhecidas, não é erro de digitação (é outro assunto, ou um texto colado).
        $unknown = @($prepared.Tokens | Where-Object { $_ -notin $script:WinForgeSearchSoftWords -and -not (Test-WinForgeSearchKnown -Token $_) })
        $fixed = @{}

        if ($unknown.Count -le 2) {
            foreach ($token in $unknown) {
                $correction = Get-WinForgeSearchCorrection -Token $token
                if ($correction) { $fixed[$token] = $correction }
            }
        }

        if ($fixed.Count -gt 0) {
            $prepared = Get-WinForgeSearchQuery -Query (@($prepared.All | ForEach-Object { if ($fixed.ContainsKey($_)) { $fixed[$_] } else { $_ } }) -join ' ')
            $hits = Find-WinForgeSearchHits -Query $prepared -Specs (New-WinForgeSearchSpecs -Tokens $prepared.Tokens)
            $corrected = $prepared.Words
        }
    }

    # Parte das palavras só vale com duas ou mais palavras que contam (só palavras de ligação, como "o que fazer", não).
    if ($hits.Count -eq 0 -and $prepared.Hard -gt 1 -and $prepared.Meaningful -gt 1) {
        $hits = Find-WinForgeSearchHits -Query $prepared -Specs (New-WinForgeSearchSpecs -Tokens $prepared.Tokens) -Partial
    }

    if ($hits.Count -eq 0) { return @() }

    $sorted = @($hits | Sort-Object @{ Expression = "Matched"; Descending = $true }, @{ Expression = "Score"; Descending = $true },
        @{ Expression = "Rank"; Descending = $false }, @{ Expression = "Order"; Descending = $false })

    $targets = New-Object 'System.Collections.Generic.HashSet[string]'
    $unique = New-Object System.Collections.ArrayList

    foreach ($hit in $sorted) {
        if (-not $targets.Add([string]$hit.Target)) { continue }

        $hit.Corrected = $corrected
        [void]$unique.Add($hit)

        if ($First -gt 0 -and $unique.Count -ge $First) { break }
    }

    return @($unique)
}


function Test-WinForgeSearchEnterOpens {
    # O Enter na caixa de busca abre o primeiro resultado só quando ele achou o que foi digitado. Numa busca corrigida ou
    # que achou só parte das palavras, ele só abre uma página (ou um ajuste, que leva à página); uma ação ou uma janela do
    # Windows fica selecionada, para a pessoa conferir antes: nada roda por um palpite.
    param ($Hit)

    if ($null -eq $Hit) { return $false }
    if (-not [bool]$Hit.Partial -and [string]::IsNullOrEmpty([string]$Hit.Corrected)) { return $true }

    return ($Hit.Kind -eq "Page" -or $Hit.Kind -eq "Tweak")
}


function Test-WinForgeSearchTooShort {
    # Uma letra só (ou um algarismo): a busca espera a segunda, em vez de mostrar quase tudo.
    param ([AllowEmptyString()][AllowNull()][string]$Query)

    $compact = (ConvertTo-WinForgeSearchWords -Text $Query).Replace(" ", "")

    return ($compact.Length -eq 1)
}


function Get-WinForgeSearchCardItem {
    # O item que a janela desenha como cartão para um resultado, e que o clique (ou o Enter no primeiro) executa. Ações e
    # atalhos são os próprios itens da tabela; uma página, uma parte de página e um ajuste viram um item "Page" que leva à
    # página. Um ajuste avançado leva junto TweakAdvanced, para a página de ajustes abrir o grupo recolhido onde ele está;
    # uma parte de página leva Section, para a página levar o foco até ela.
    param ([Parameter(Mandatory)]$Hit)

    switch ($Hit.Kind) {
        "Item" { return $Hit.Item }
        "Page" {
            $section = [string]$Hit.Section

            return [PSCustomObject]@{
                Id = $(if ($section) { "search.page.$($Hit.PageId).$section" } else { "search.page.$($Hit.PageId)" })
                Label = $Hit.Label; Description = $Hit.Description; Kind = "Page"; Command = $Hit.PageId; Shortcut = ""
                Accent = $false; RequiresAdmin = $false; Keywords = ""; TweakId = ""; TweakAdvanced = $false; Section = $section
            }
        }
        default {
            return [PSCustomObject]@{
                Id = "search.tweak.$($Hit.PageId).$($Hit.Tweak.Id)"; Label = $Hit.Label; Description = $Hit.Description; Kind = "Page"
                Command = [string]$Hit.PageId; Shortcut = ""; Accent = $false; RequiresAdmin = $false; Keywords = ""; TweakId = [string]$Hit.Tweak.Id
                TweakAdvanced = [bool]$Hit.Tweak.Advanced; Section = ""
            }
        }
    }
}


function Get-WinForgeSearchFocus {
    # O que a página aberta por um resultado da busca destaca: TweakId (o ajuste; vazio quando o item não é um ajuste),
    # Advanced (o ajuste está no grupo recolhido, que precisa abrir) e Section (a parte da página que recebe o foco, como a
    # Aparência). Serve para qualquer item.
    param ($Item)

    $id = ""
    $advanced = $false
    $section = ""

    if ($null -ne $Item) {
        $idProperty = $Item.PSObject.Properties["TweakId"]
        $advancedProperty = $Item.PSObject.Properties["TweakAdvanced"]
        $sectionProperty = $Item.PSObject.Properties["Section"]

        if ($null -ne $idProperty -and $null -ne $idProperty.Value) { $id = [string]$idProperty.Value }
        if ($id -and $null -ne $advancedProperty) { $advanced = [bool]$advancedProperty.Value }
        if ($null -ne $sectionProperty -and $null -ne $sectionProperty.Value) { $section = [string]$sectionProperty.Value }
    }

    return [PSCustomObject]@{ TweakId = $id; Advanced = $advanced; Section = $section }
}


function Get-WinForgeSearchContext {
    # O texto discreto acima do título de um resultado.
    param ([Parameter(Mandatory)]$Hit)

    switch ($Hit.Kind) {
        "Page" { return $(if ([string]$Hit.Section) { [string]$Hit.PageTitle } else { "Ir para a página" }) }
        "Tweak" { return "$($Hit.PageTitle) > ajuste" }
        default { return $Hit.PageTitle }
    }
}


function Format-WinForgeSearchQuote {
    # O texto da busca para o cabeçalho, abreviado em 40 caracteres sem partir um emoji ao meio.
    param ([AllowEmptyString()][AllowNull()][string]$Text)

    $value = ([string]$Text).Trim()

    if ($value.Length -le 40) { return $value }

    $cut = 40
    if ([char]::IsHighSurrogate($value[$cut - 1])) { $cut-- }

    return $value.Substring(0, $cut) + "…"
}


function Get-WinForgeSearchSummary {
    # A linha sob o título "Busca": quantos resultados, se a busca foi corrigida ou só achou parte das palavras, e o Enter
    # (-EnterSelects: o Enter só seleciona o primeiro, sem abrir; veja Test-WinForgeSearchEnterOpens).
    param (
        [AllowEmptyString()][string]$Query,
        [int]$Total,
        [int]$Shown,
        [switch]$Partial,
        [AllowEmptyString()][string]$Corrected = "",
        [switch]$EnterSelects
    )

    if (Test-WinForgeSearchTooShort -Query $Query) { return "Continue digitando: a busca começa na segunda letra" }

    $text = Format-WinForgeSearchQuote -Text $Query

    if ($Total -le 0) { return "Nada encontrado para '$text'" }

    $what = $(if ($Corrected) { "'$(Format-WinForgeSearchQuote -Text $Corrected)' (você digitou '$text')" } else { "'$text'" })
    $enter = $(if ($Total -eq 1) { "Enter abre" } else { "Enter abre o primeiro" })
    if ($EnterSelects) { $enter = $(if ($Total -eq 1) { "Enter seleciona" } else { "Enter seleciona o primeiro" }) }

    if ($Partial) {
        $closest = $(if ($Shown -le 1) { "o mais próximo" } else { "os $Shown mais próximos" })
        return "Nada tem todas as palavras de $what; $closest · $enter"
    }

    if ($Total -eq 1) { return "1 resultado para $what · $enter" }
    if ($Shown -lt $Total) { return "Mostrando os $Shown melhores de $Total resultados para $what · $enter" }

    return "$Total resultados para $what · $enter"
}


function Get-WinForgeSearchSuggestions {
    # As buscas sugeridas quando nada foi encontrado, do jeito que a pessoa diria: todas devolvem resultados (um teste
    # confere).
    return @("pc lento", "sem espaço", "internet lenta", "vírus")
}


# ---------------------------------------------------------------------------
# Teclas de atalho da janela
# ---------------------------------------------------------------------------

function Get-WinForgePageShortcutKey {
    # A tecla que abre a página de posição Index na lista dos atalhos (0 = Início): "Ctrl+1" a "Ctrl+9", e "Ctrl+0" para a
    # décima. Vazio depois disso.
    param ([int]$Index)

    if ($Index -lt 0 -or $Index -gt 9) { return "" }

    return "Ctrl+$(($Index + 1) % 10)"
}


function Resolve-WinForgeKeyAction {
    <#
    O que uma tecla faz na janela. A janela só traduz o evento do WPF (nome da tecla, Ctrl/Alt/Shift e o estado da tela)
    e executa a resposta; as regras ficam aqui para serem testadas. Action:
      FocusSearch        Ctrl+K, e Ctrl+F fora de uma lista com filtro
      FocusPromptFilter  Ctrl+F com uma lista de marcação com filtro na tela
      OpenPage           Ctrl+1 a Ctrl+9 e Ctrl+0 (PageIndex é a posição na lista de páginas)
      Refresh            F5 numa página
      LeaveRun           Esc na tela de execução já terminada
      LeaveSearch        Esc com resultados da busca na tela (volta à página de onde ela começou)
      ClearSearch        Esc com texto na caixa, antes de a busca aparecer (só esvazia a caixa)
      None               a tecla segue o caminho normal
    Ctrl precisa estar sozinho: no teclado ABNT2, AltGr chega como Ctrl+Alt, e AltGr+1/2/3 digitam ¹ ² ³ (e Ctrl+Shift
    é combinação de outros programas).
    #>
    param (
        [Parameter(Mandatory)][string]$Key,
        [bool]$Control = $false,
        [bool]$Alt = $false,
        [bool]$Shift = $false,
        [int]$PageCount = 0,
        [bool]$SearchActive = $false,
        [bool]$SearchHasText = $false,
        [bool]$PagesVisible = $false,
        [bool]$RunViewVisible = $false,
        [bool]$Running = $false,
        [bool]$PromptShown = $false,
        [bool]$PromptFilterVisible = $false
    )

    $none = [PSCustomObject]@{ Action = "None"; PageIndex = -1 }
    $plain = (-not $Control -and -not $Alt -and -not $Shift)
    $ctrlOnly = ($Control -and -not $Alt -and -not $Shift)

    if ($ctrlOnly -and $Key -ieq "F" -and $RunViewVisible -and $PromptShown -and $PromptFilterVisible) {
        return [PSCustomObject]@{ Action = "FocusPromptFilter"; PageIndex = -1 }
    }

    if ($ctrlOnly -and ($Key -ieq "K" -or $Key -ieq "F")) {
        return [PSCustomObject]@{ Action = "FocusSearch"; PageIndex = -1 }
    }

    if ($ctrlOnly -and $Key -match '^(D|NumPad)([0-9])$') {
        $number = [int]$Matches[2]
        $index = $(if ($number -eq 0) { 9 } else { $number - 1 })

        if ($index -lt $PageCount) {
            return [PSCustomObject]@{ Action = "OpenPage"; PageIndex = $index }
        }

        return $none
    }

    if ($plain -and $Key -eq "F5" -and $PagesVisible -and -not $SearchActive) {
        return [PSCustomObject]@{ Action = "Refresh"; PageIndex = -1 }
    }

    if ($plain -and $Key -eq "Escape") {
        # Esc volta um passo. Na tela de execução, só depois de a ação terminar (de volta aos resultados da busca, se a ação
        # saiu de lá): nunca interrompe uma ação nem uma pergunta na tela, nem a tira da frente. Fora dela, limpa a busca
        # e volta à página de onde ela começou; com texto na caixa e a busca ainda por aparecer, só esvazia a caixa.
        if ($RunViewVisible) {
            if (-not $Running -and -not $PromptShown) { return [PSCustomObject]@{ Action = "LeaveRun"; PageIndex = -1 } }

            return $none
        }

        if ($SearchActive) { return [PSCustomObject]@{ Action = "LeaveSearch"; PageIndex = -1 } }
        if ($SearchHasText) { return [PSCustomObject]@{ Action = "ClearSearch"; PageIndex = -1 } }
    }

    return $none
}


Export-ModuleMember -Function *
