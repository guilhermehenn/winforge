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
    # Description: uma linha, de até 60 caracteres (a janela mostra numa linha só); Detail: a frase inteira, quando a
    # da linha é a curta (a dica ao passar o mouse, o leitor de tela e a busca).
    # ListCategory: numa página de ajustes, o item vira uma linha no fim do grupo dessa categoria, e não um botão no alto.
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
        [switch]$Unlisted,
        [string]$Detail = "",
        [string]$ListCategory = "",

        # O texto do botão no destaque da página (o item com Accent, New-GuiHeroCard): o verbo do que ele faz.
        [string]$ButtonText = ""
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
        Detail        = $Detail
        ListCategory  = $ListCategory
        ButtonText    = $ButtonText
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

    # Manutenção: na janela, a faixa "Última manutenção" no alto abre o histórico, e os dois grupos têm três linhas cada.
    # O histórico e o Agendador de Tarefas não viram linha (Unlisted), mas a busca e o console chegam neles.
    $pages += New-WinForgeNavPage -Id "maintenance" -Title (Get-WinForgeText 'Manutenção') -Summary (Get-WinForgeText 'Cuide do PC e volte atrás se algo der errado.') -Items @(
        (New-WinForgeNavItem -Id "maintenance.recommended" -Label (Get-WinForgeText 'Otimizar') -ButtonText (Get-WinForgeText 'Otimizar agora') -Group (Get-WinForgeText 'Cuidar do PC') -Admin -Accent `
            -Keywords (Get-WinForgeText 'manutenção recomendada completa profunda windows acelerar lento tudo guiada limpeza reparo atualizar') `
            -Description (Get-WinForgeText 'A manutenção completa, em ordem; pode passar de uma hora') -Detail (Get-WinForgeText 'A manutenção completa do PC, em ordem; pode levar mais de uma hora') -Command "Invoke-WinForgeRecommendedMaintenance"),
        (New-WinForgeNavItem -Id "maintenance.checkup" -Label (Get-WinForgeText 'Verificar o PC') -Group (Get-WinForgeText 'Cuidar do PC') -Admin `
            -Keywords (Get-WinForgeText 'escanear examinar scan check-up checkup diagnóstico um clique corrigir problemas saúde') `
            -Description (Get-WinForgeText 'Confere o PC e corrige num clique o que é seguro') -Detail (Get-WinForgeText 'Confere o PC em uma passada e corrige, num clique, o que é seguro') -Command "Invoke-WinForgeCheckup"),
        (New-WinForgeNavItem -Id "maintenance.schedule" -Label (Get-WinForgeText 'Manutenção agendada') -Group (Get-WinForgeText 'Cuidar do PC') -Admin `
            -Keywords (Get-WinForgeText 'automática mensal tarefa sozinha agendar') `
            -Description (Get-WinForgeText 'Limpeza leve e relatório todo mês, sem abrir o WinForge') -Detail (Get-WinForgeText 'Uma limpeza leve e um relatório todo mês, sem você abrir o WinForge') -Command "Show-WinForgeScheduledMaintenance"),
        (New-WinForgeNavItem -Id "maintenance.history" -Label (Get-WinForgeText 'Histórico de manutenções') -Group (Get-WinForgeText 'Cuidar do PC') -Unlisted `
            -Keywords (Get-WinForgeText 'última manutenção tendência espaço duração falhas atenção') `
            -Description (Get-WinForgeText 'A última manutenção e a variação de espaço das anteriores') -Detail (Get-WinForgeText 'A última manutenção, o que pediu atenção nela e a variação de espaço das anteriores') -Command "Show-WinForgeMaintenanceHistory"),
        (New-WinForgeNavItem -Id "maintenance.task-scheduler" -Label (Get-WinForgeText 'Agendador de Tarefas') -Group (Get-WinForgeText 'Cuidar do PC') -Unlisted `
            -Keywords (Get-WinForgeText 'taskschd agendar tarefas') `
            -Description (Get-WinForgeText 'Abre o Agendador de Tarefas, onde fica a tarefa do WinForge') -Detail (Get-WinForgeText 'Abre o Agendador de Tarefas do Windows, onde a tarefa do WinForge aparece') -Shortcut "TaskScheduler"),
        (New-WinForgeNavItem -Id "maintenance.restore-point" -Label (Get-WinForgeText 'Criar ponto de restauração') -Group (Get-WinForgeText 'Se algo der errado') -Admin `
            -Keywords (Get-WinForgeText 'backup segurança voltar atrás proteção do sistema') `
            -Description (Get-WinForgeText 'Guarda o Windows de agora, para voltar a ele depois') -Detail (Get-WinForgeText 'Guarda o estado do Windows de agora, para voltar a ele depois') -Command "Invoke-WinForgeRestorePoint"),
        (New-WinForgeNavItem -Id "maintenance.changes" -Label (Get-WinForgeText 'Histórico de mudanças') -Group (Get-WinForgeText 'Se algo der errado') `
            -Keywords (Get-WinForgeText 'desfazer voltar atrás reverter restaurar registro backup central de resgate mudanças feitas') `
            -Description (Get-WinForgeText 'O que o WinForge mudou no PC; desfaça o que tiver volta') -Command "Show-WinForgeChangeHistory"),
        (New-WinForgeNavItem -Id "maintenance.restore" -Label (Get-WinForgeText 'Restauração do Sistema') -Group (Get-WinForgeText 'Se algo der errado') `
            -Keywords (Get-WinForgeText 'voltar desfazer rstrui restore') `
            -Description (Get-WinForgeText 'Abre a janela que volta o PC a um ponto de restauração') -Detail (Get-WinForgeText 'Abre a janela do Windows que volta o PC a um ponto de restauração') -Shortcut "SystemRestore")
    )

    $pages += New-WinForgeNavPage -Id "diagnostics" -Title (Get-WinForgeText 'Diagnóstico') -Summary (Get-WinForgeText 'Veja como o PC está antes de mexer em qualquer coisa.') -Items @(
        (New-WinForgeNavItem -Id "diagnostics.about" -Label (Get-WinForgeText 'Sobre este PC') -ButtonText (Get-WinForgeText 'Ver detalhes') -Group (Get-WinForgeText 'Visão geral') -Accent `
            -Keywords (Get-WinForgeText 'cpu ram processador memória gpu placa de vídeo hardware especificações configuração xmp winver') `
            -Description (Get-WinForgeText 'Windows, processador, memória, vídeo, discos e Secure Boot') -Detail (Get-WinForgeText 'Windows, processador, memória, placa de vídeo, discos e Secure Boot') -Command "Show-WinForgeSystemInfo"),
        (New-WinForgeNavItem -Id "diagnostics.windows-support" -Label (Get-WinForgeText 'Suporte do Windows') -Group (Get-WinForgeText 'Visão geral') `
            -Keywords (Get-WinForgeText 'fim do suporte windows 10 windows 11 atualizações de segurança esu requisitos tpm compatível upgrade versão 24h2 25h2') `
            -Description (Get-WinForgeText 'Até quando há atualizações e se dá para ir ao Windows 11') -Detail (Get-WinForgeText 'Até quando este Windows recebe atualizações de segurança e se o PC pode ir para o Windows 11') -Command "Show-WinForgeWindowsSupport"),
        (New-WinForgeNavItem -Id "diagnostics.report" -Label (Get-WinForgeText 'Exportar relatório') -Group (Get-WinForgeText 'Visão geral') `
            -Keywords (Get-WinForgeText 'salvar html txt relatório laudo') `
            -Description (Get-WinForgeText 'Salva o estado do PC em HTML e texto, para guardar ou mandar') -Detail (Get-WinForgeText 'Salva o estado do PC em HTML e em texto, para guardar ou mandar a quem vai ajudar') -Command "Invoke-WinForgeReport"),
        (New-WinForgeNavItem -Id "diagnostics.disks" -Label (Get-WinForgeText 'Discos e espaço livre') -Group (Get-WinForgeText 'Hardware') `
            -Keywords (Get-WinForgeText 'armazenamento ssd hdd hd cheio capacidade unidade') `
            -Description (Get-WinForgeText 'SSD ou HDD, espaço livre e uso de cada unidade') -Command "Show-WinForgeDisks"),
        (New-WinForgeNavItem -Id "diagnostics.disk-health" -Label (Get-WinForgeText 'Saúde dos discos') -Group (Get-WinForgeText 'Hardware') -Admin `
            -Keywords (Get-WinForgeText 'smart temperatura desgaste ssd hdd hd falha') `
            -Description (Get-WinForgeText 'Estado, temperatura, desgaste e erros de cada disco') -Command "Show-WinForgeDiskHealth"),
        (New-WinForgeNavItem -Id "diagnostics.devices" -Label (Get-WinForgeText 'Dispositivos com problema') -Group (Get-WinForgeText 'Hardware') `
            -Keywords (Get-WinForgeText 'driver drivers erro hardware câmera webcam som áudio microfone fone impressora teclado mouse bluetooth pendrive usb reconhecido tela piscando') `
            -Description (Get-WinForgeText 'Drivers e hardware com erro') -Command "Show-WinForgeProblemDevices"),
        (New-WinForgeNavItem -Id "diagnostics.battery" -Label (Get-WinForgeText 'Saúde da bateria') -Group (Get-WinForgeText 'Hardware') `
            -Keywords (Get-WinForgeText 'notebook laptop carga ciclos desgaste energia') `
            -Description (Get-WinForgeText 'Capacidade de hoje e de fábrica, ciclos e carga atual') -Detail (Get-WinForgeText 'Capacidade de hoje comparada à de fábrica, ciclos de carga e carga atual') -Command "Show-WinForgeBatteryHealth"),
        (New-WinForgeNavItem -Id "diagnostics.memory-test" -Label (Get-WinForgeText 'Teste de memória') -Group (Get-WinForgeText 'Hardware') -Admin `
            -Keywords (Get-WinForgeText 'ram memória mdsched pente defeito tela azul memtest teste') `
            -Description (Get-WinForgeText 'Testa a memória (RAM) no próximo reinício') -Detail (Get-WinForgeText 'Testa a memória (RAM) no próximo reinício; o resultado aparece depois') -Command "Start-WinForgeMemoryTest"),
        (New-WinForgeNavItem -Id "diagnostics.events" -Label (Get-WinForgeText 'Eventos críticos (7 dias)') -Group (Get-WinForgeText 'Funcionamento do Windows') `
            -Keywords (Get-WinForgeText 'erro tela azul preta travou travando travamento queda de energia falha log reiniciando reiniciou desligando desligou visualizador de eventos eventvwr') `
            -Description (Get-WinForgeText 'Quedas de energia, tela azul, erros de disco e de hardware') -Command "Show-WinForgeCriticalEvents"),
        (New-WinForgeNavItem -Id "diagnostics.blue-screens" -Label (Get-WinForgeText 'Telas azuis') -Group (Get-WinForgeText 'Funcionamento do Windows') `
            -Keywords (Get-WinForgeText 'tela azul bsod bugcheck stop code erro travou reiniciou reiniciando reinicia sozinho minidump') `
            -Description (Get-WinForgeText 'Dos últimos 90 dias, com a causa provável') -Detail (Get-WinForgeText 'As telas azuis dos últimos 90 dias, com a causa provável e o que fazer') -Command "Show-WinForgeBlueScreens"),
        (New-WinForgeNavItem -Id "diagnostics.pending-reboot" -Label (Get-WinForgeText 'Reinício pendente') -Group (Get-WinForgeText 'Funcionamento do Windows') `
            -Keywords (Get-WinForgeText 'reiniciar reboot restart') `
            -Description (Get-WinForgeText 'O que espera um reinício e se ele é mesmo necessário') -Detail (Get-WinForgeText 'O que está esperando um reinício, se ele é mesmo necessário, e reiniciar quando quiser') -Command "Show-WinForgePendingReboot"),
        (New-WinForgeNavItem -Id "diagnostics.startup" -Label (Get-WinForgeText 'Tempo ligado e energia') -Group (Get-WinForgeText 'Funcionamento do Windows') `
            -Keywords (Get-WinForgeText 'boot lento ligar demora inicialização rápida hibernar hibernação energia uptime') `
            -Description (Get-WinForgeText 'Tempo ligado, Inicialização Rápida e hibernação') -Detail (Get-WinForgeText 'Quanto tempo o PC está ligado, Inicialização Rápida e hibernação') -Command "Show-WinForgeStartupInfo"),
        (New-WinForgeNavItem -Id "diagnostics.reliability" -Label (Get-WinForgeText 'Monitor de Confiabilidade') -Group (Get-WinForgeText 'Ferramentas do Windows') `
            -Keywords (Get-WinForgeText 'falhas travamentos histórico confiabilidade perfmon') `
            -Description (Get-WinForgeText 'Abre o histórico de falhas do Windows') -Shortcut "Reliability"),
        (New-WinForgeNavItem -Id "diagnostics.device-manager" -Label (Get-WinForgeText 'Gerenciador de Dispositivos') -Group (Get-WinForgeText 'Ferramentas do Windows') `
            -Keywords (Get-WinForgeText 'devmgmt drivers') `
            -Description (Get-WinForgeText 'Abre o Gerenciador de Dispositivos do Windows') -Shortcut "DeviceManager")
    )

    $pages += New-WinForgeNavPage -Id "security" -Title (Get-WinForgeText 'Segurança') -Summary (Get-WinForgeText 'Veja se o PC está protegido e rode a verificação do Windows.') -Items @(
        (New-WinForgeNavItem -Id "security.status" -Label (Get-WinForgeText 'Estado da proteção') -ButtonText (Get-WinForgeText 'Ver a proteção') -Group (Get-WinForgeText 'Proteção') -Accent `
            -Keywords (Get-WinForgeText 'vírus malware defender firewall antivírus proteção ameaça') `
            -Description (Get-WinForgeText 'Antivírus, assinaturas, firewall e ameaças ativas') -Detail (Get-WinForgeText 'Antivírus, assinaturas, firewall, atualizações pendentes e ameaças ativas') -Command "Show-WinForgeSecurityStatus"),
        (New-WinForgeNavItem -Id "security.audit" -Label (Get-WinForgeText 'Auditoria de segurança') -Group (Get-WinForgeText 'Proteção') `
            -Description (Get-WinForgeText 'Senhas, acesso remoto, criptografia e mais, com uma nota') -Detail (Get-WinForgeText 'Além do antivírus e do firewall, confere senhas, acesso remoto e criptografia, e dá uma nota') -Command "Show-WinForgeSecurityAudit" `
            -Keywords (Get-WinForgeText 'nota uac smartscreen bitlocker criptografia secure boot remota rdp convidado senha entrada automática')),
        (New-WinForgeNavItem -Id "security.bitlocker-key" -Label (Get-WinForgeText 'Chave de recuperação do BitLocker') -Group (Get-WinForgeText 'Proteção') -Admin `
            -Keywords (Get-WinForgeText 'bitlocker chave recuperação criptografia bloqueado recovery key 48 números') `
            -Description (Get-WinForgeText 'Se o disco está criptografado; guarda a chave fora do PC') -Detail (Get-WinForgeText 'Mostra se o disco está criptografado e guarda uma cópia da chave fora do PC') -Command "Show-WinForgeBitLockerKey"),
        (New-WinForgeNavItem -Id "security.signatures" -Label (Get-WinForgeText 'Atualizar assinaturas do antivírus') -Group (Get-WinForgeText 'Proteção') -Admin `
            -Keywords (Get-WinForgeText 'vírus malware definições atualizar defender') `
            -Description (Get-WinForgeText 'Baixa a lista mais nova de vírus do Windows Defender') -Detail (Get-WinForgeText 'Baixa do Windows Defender a lista mais nova de vírus conhecidos (as assinaturas)') -Command "Update-WinForgeDefenderSignatures"),
        (New-WinForgeNavItem -Id "security.scan" -Label (Get-WinForgeText 'Verificar vírus') -Group (Get-WinForgeText 'Procurar ameaças') -Admin `
            -Keywords (Get-WinForgeText 'vírus antivírus malware ransomware trojan scan escanear examinar varredura assinaturas um clique verificação rápida') `
            -Description (Get-WinForgeText 'Atualiza e faz a verificação rápida do Windows Defender') -Detail (Get-WinForgeText 'Atualiza o antivírus e faz a verificação rápida do Windows Defender, em alguns minutos') -Command "Invoke-WinForgeSecurityCheck"),
        (New-WinForgeNavItem -Id "security.full-scan" -Label (Get-WinForgeText 'Verificação completa de vírus') -Group (Get-WinForgeText 'Procurar ameaças') -Admin `
            -Keywords (Get-WinForgeText 'vírus malware ransomware trojan scan antivírus escanear examinar horas') `
            -Description (Get-WinForgeText 'O Defender examina todos os arquivos; pode levar horas') -Detail (Get-WinForgeText 'Atualiza o antivírus e o Windows Defender examina todos os arquivos; pode levar horas') -Command "Start-WinForgeFullScan"),
        (New-WinForgeNavItem -Id "security.folder-scan" -Label (Get-WinForgeText 'Verificar uma pasta') -Group (Get-WinForgeText 'Procurar ameaças') -Admin `
            -Keywords (Get-WinForgeText 'vírus malware scan arquivo suspeito suspeita baixado download pendrive pen drive usb cartão de memória') `
            -Description (Get-WinForgeText 'O Defender examina uma pasta, um arquivo ou um pendrive') -Detail (Get-WinForgeText 'Atualiza o antivírus e o Windows Defender examina só a pasta, o arquivo ou o pendrive que você indicar') -Command "Start-WinForgeFolderScan"),
        (New-WinForgeNavItem -Id "security.windows-security" -Label (Get-WinForgeText 'Segurança do Windows') -Group (Get-WinForgeText 'Procurar ameaças') `
            -Keywords (Get-WinForgeText 'windows security defender firewall vírus offline proteção quarentena histórico') `
            -Description (Get-WinForgeText 'Abre o aplicativo do Windows, com a verificação offline') -Detail (Get-WinForgeText 'Abre o aplicativo do Windows, com a verificação offline e o histórico de proteção') -Shortcut "WindowsSecurity")
    )

    $pages += New-WinForgeNavPage -Id "cleanup" -Title (Get-WinForgeText 'Limpeza') -Summary (Get-WinForgeText 'Libere espaço, do mais seguro ao mais profundo.') -Items @(
        (New-WinForgeNavItem -Id "cleanup.quick" -Label (Get-WinForgeText 'Limpeza rápida') -ButtonText (Get-WinForgeText 'Limpar agora') -Group (Get-WinForgeText 'Liberar espaço') -Admin -Accent `
            -Keywords (Get-WinForgeText 'limpar liberar espaço sem espaço lixo lento temp tmp temporários arquivos apagar limpeza de disco clean cleanup cleaner disk cleanmgr') `
            -Description (Get-WinForgeText 'Temporários do usuário e do Windows, e a Lixeira se quiser') -Detail (Get-WinForgeText 'Temporários do usuário e do Windows e, se você quiser, a Lixeira') -Command "Invoke-WinForgeQuickCleanup"),
        (New-WinForgeNavItem -Id "cleanup.space" -Label (Get-WinForgeText 'Analisar uso de espaço') -Group (Get-WinForgeText 'Liberar espaço') `
            -Keywords (Get-WinForgeText 'disco cheio o que ocupa espaço maiores pastas tamanho armazenamento ocupa windows.old hiberfil hibernação pagefile memória virtual swapfile') `
            -Description (Get-WinForgeText 'O que ocupa o disco e quanto a limpeza libera') -Detail (Get-WinForgeText 'Mostra o que a limpeza libera, as maiores pastas do perfil e os arquivos grandes do sistema') -Command "Show-WinForgeSpaceAnalysis"),
        (New-WinForgeNavItem -Id "cleanup.custom" -Label (Get-WinForgeText 'Limpeza personalizada') -Group (Get-WinForgeText 'Liberar espaço') -Admin `
            -Keywords (Get-WinForgeText 'escolher lista tamanhos temporários do usuário temporários do windows cache navegador relatórios de erro otimização de entrega delivery optimization despejo memória dump') `
            -Description (Get-WinForgeText 'Escolha item por item, vendo o tamanho de cada um') -Detail (Get-WinForgeText 'Você marca numa lista, com o tamanho de cada item: temporários, caches, despejos de falhas, Lixeira') -Command "Invoke-WinForgeCustomCleanup"),
        (New-WinForgeNavItem -Id "cleanup.recycle-bin" -Label (Get-WinForgeText 'Esvaziar a Lixeira') -Group (Get-WinForgeText 'Liberar espaço') `
            -Keywords (Get-WinForgeText 'lixo excluídos apagados') `
            -Description (Get-WinForgeText 'Apaga de vez o que está na Lixeira, em todas as unidades') -Detail (Get-WinForgeText 'Remove em definitivo o que está na Lixeira, de todas as unidades') -Command "Clear-WinForgeRecycleBin"),
        (New-WinForgeNavItem -Id "cleanup.downloads" -Label (Get-WinForgeText 'Limpar a pasta Downloads') -Group (Get-WinForgeText 'Liberar espaço') `
            -Keywords (Get-WinForgeText 'baixados arquivos antigos apagar excluir remover') `
            -Description (Get-WinForgeText 'Prévia e filtro por idade antes de apagar') -Detail (Get-WinForgeText 'Você vê uma prévia, filtra por idade e escolhe entre a Lixeira e a exclusão') -Command "Clear-WinForgeDownloads"),
        (New-WinForgeNavItem -Id "cleanup.storage" -Label (Get-WinForgeText 'Configurações de armazenamento') -Group (Get-WinForgeText 'Liberar espaço') `
            -Keywords (Get-WinForgeText 'sensor de armazenamento configurações espaço') `
            -Description (Get-WinForgeText 'Abre a página Armazenamento, nas Configurações') -Detail (Get-WinForgeText 'Abre Armazenamento, nas Configurações do Windows, onde ficam os arquivos temporários e o Sensor de Armazenamento') -Shortcut "Storage"),
        (New-WinForgeNavItem -Id "cleanup.shortcuts" -Label (Get-WinForgeText 'Remover atalhos quebrados') -Group (Get-WinForgeText 'Arrumar o que sobrou') `
            -Keywords (Get-WinForgeText 'atalho quebrado inválido lnk ícone não abre') `
            -Description (Get-WinForgeText 'Atalhos que apontam para o que não existe mais') -Detail (Get-WinForgeText 'Atalhos que apontam para o que não existe mais; eles vão para a Lixeira') -Command "Remove-WinForgeBrokenShortcuts"),
        (New-WinForgeNavItem -Id "cleanup.duplicates" -Label (Get-WinForgeText 'Encontrar arquivos duplicados') -Group (Get-WinForgeText 'Arrumar o que sobrou') `
            -Keywords (Get-WinForgeText 'duplicado duplicados cópia cópias repetidos iguais fotos espaço') `
            -Description (Get-WinForgeText 'Arquivos iguais numa pasta; você escolhe o que sai') -Detail (Get-WinForgeText 'Arquivos iguais (mesmo conteúdo) numa pasta; você escolhe o que vai para a Lixeira') -Command "Find-WinForgeDuplicateFiles"),
        (New-WinForgeNavItem -Id "cleanup.leftovers" -Label (Get-WinForgeText 'Restos de programas desinstalados') -Group (Get-WinForgeText 'Arrumar o que sobrou') `
            -Keywords (Get-WinForgeText 'sobras resíduos desinstalado pastas vazias appdata program files revo') `
            -Description (Get-WinForgeText 'Pastas de programas que o WinForge desinstalou') -Detail (Get-WinForgeText 'Pastas que sobraram de programas desinstalados pelo WinForge; você escolhe o que vai para a Lixeira') -Command "Find-WinForgeProgramLeftovers"),
        (New-WinForgeNavItem -Id "cleanup.registry" -Label (Get-WinForgeText 'Limpar o registro') -Group (Get-WinForgeText 'Avançado') `
            -Keywords (Get-WinForgeText 'registro regedit chaves inválidas quebradas órfãs erros do registro limpador') `
            -Description (Get-WinForgeText 'Só referências quebradas, com backup e desfazer') -Detail (Get-WinForgeText 'Só referências quebradas a programas e arquivos que não existem mais; com backup e desfazer') -Command "Invoke-WinForgeRegistryCleanup"),
        (New-WinForgeNavItem -Id "cleanup.components" -Label (Get-WinForgeText 'Limpar componentes do Windows (WinSxS)') -Group (Get-WinForgeText 'Avançado') -Admin `
            -Keywords (Get-WinForgeText 'winsxs dism component store atualizações antigas espaço') `
            -Description (Get-WinForgeText 'Versões antigas deixadas pelas atualizações (DISM)') -Detail (Get-WinForgeText 'Remove versões antigas de componentes substituídos por atualizações (DISM)') -Command "Invoke-WinForgeComponentCleanup"),
        (New-WinForgeNavItem -Id "cleanup.wipe-free" -Label (Get-WinForgeText 'Apagar o espaço livre') -Group (Get-WinForgeText 'Avançado') -Admin `
            -Keywords (Get-WinForgeText 'cipher apagar com segurança vender doar sobrescrever definitivo') `
            -Description (Get-WinForgeText 'Impede recuperar o que já foi apagado do disco') -Detail (Get-WinForgeText 'Sobrescreve o espaço livre do disco: o que já foi apagado não pode mais ser trazido de volta') -Command "Clear-WinForgeFreeSpace")
    )

    $pages += New-WinForgeNavPage -Id "performance" -Title (Get-WinForgeText 'Desempenho') -Summary (Get-WinForgeText 'Deixe o PC mais leve agora e veja o que está pesando.') -Items @(
        (New-WinForgeNavItem -Id "performance.boost" -Label (Get-WinForgeText 'Acelerar agora') -ButtonText (Get-WinForgeText 'Acelerar') -Group (Get-WinForgeText 'Deixar o PC mais leve') -Accent `
            -Keywords (Get-WinForgeText 'lento lentidão travando turbo boost otimizar memória ram rápido pc') `
            -Description (Get-WinForgeText 'Libera memória e apaga temporários; o efeito é passageiro') -Detail (Get-WinForgeText 'Libera memória e apaga os seus temporários, num clique; o efeito na memória é passageiro') -Command "Invoke-WinForgeBoost"),
        (New-WinForgeNavItem -Id "performance.processes" -Label (Get-WinForgeText 'Programas pesando agora') -Group (Get-WinForgeText 'Deixar o PC mais leve') `
            -Keywords (Get-WinForgeText 'processos processo pesados pesado cpu processador memória ram travando lento fechar encerrar uso alto disco 100% esquentando quente temperatura superaquecendo superaquecimento ventoinha cooler barulho') `
            -Description (Get-WinForgeText 'O que mais usa processador e memória agora') -Detail (Get-WinForgeText 'O que mais usa o processador e a memória neste momento; você pode fechar o que quiser') -Command "Show-WinForgeHeavyProcesses"),
        (New-WinForgeNavItem -Id "performance.memory" -Label (Get-WinForgeText 'Liberar memória') -Group (Get-WinForgeText 'Deixar o PC mais leve') `
            -Keywords (Get-WinForgeText 'ram memória cheia otimizar limpar memória') `
            -Description (Get-WinForgeText 'Tira da memória o que os programas abertos ocupam') -Detail (Get-WinForgeText 'Tira da memória o que os programas abertos ocupam; ajuda antes de abrir algo pesado') -Command "Invoke-WinForgeMemoryOptimization"),
        (New-WinForgeNavItem -Id "performance.startup" -Label (Get-WinForgeText 'Gerenciar inicialização') -Group (Get-WinForgeText 'Para o PC continuar leve') `
            -Keywords (Get-WinForgeText 'programas iniciam abrem junto boot demora msconfig desativar reativar lento lenta lentidão startup abrir iniciar com o windows') `
            -Description (Get-WinForgeText 'O que abre junto com o Windows; desligue o que não precisa') -Detail (Get-WinForgeText 'O que abre junto com o Windows; desligar o que não precisa deixa o PC leve desde o início') -Command "Set-WinForgeStartupItems"),
        (New-WinForgeNavItem -Id "performance.task-manager" -Label (Get-WinForgeText 'Gerenciador de Tarefas') -Group (Get-WinForgeText 'Para o PC continuar leve') `
            -Keywords (Get-WinForgeText 'taskmgr task manager ctrl shift esc processos desempenho') `
            -Description (Get-WinForgeText 'Abre o Gerenciador de Tarefas do Windows') -Detail (Get-WinForgeText 'Abre o Gerenciador de Tarefas do Windows; os gráficos de uso ficam na aba Desempenho') -Shortcut "TaskManager")
    )

    $pages += New-WinForgeNavPage -Id "repair" -Title (Get-WinForgeText 'Reparo') -Summary (Get-WinForgeText 'Conserte o Windows e o disco, e mantenha a unidade em forma.') -Items @(
        (New-WinForgeNavItem -Id "repair.dism-sfc" -Label (Get-WinForgeText 'Reparar o Windows (DISM + SFC)') -ButtonText (Get-WinForgeText 'Reparar') -Group (Get-WinForgeText 'Arquivos do Windows') -Admin -Accent `
            -Keywords (Get-WinForgeText 'corrigir consertar arquivos corrompidos corrupção erro windows travando instável tela azul') `
            -Description (Get-WinForgeText 'Conserta arquivos do Windows; leva de 20 a 60 minutos') -Detail (Get-WinForgeText 'Conserta arquivos danificados do Windows; costuma levar de 20 a 60 minutos e não apaga nada seu') -Command "Invoke-WinForgeDismAndSfc"),
        (New-WinForgeNavItem -Id "repair.dism" -Label (Get-WinForgeText 'Reparar imagem e componentes (DISM)') -Group (Get-WinForgeText 'Arquivos do Windows') -Admin `
            -Keywords (Get-WinForgeText 'imagem corrompida componente store restorehealth cleanup-image update com erro atualização falhando travado travada falhou') `
            -Description (Get-WinForgeText 'Restaura a base do Windows pela internet; 10 a 30 minutos') -Detail (Get-WinForgeText 'Restaura os arquivos-base do Windows pela internet (Windows Update); leva de 10 a 30 minutos') -Command "Invoke-WinForgeDism"),
        (New-WinForgeNavItem -Id "repair.sfc" -Label (Get-WinForgeText 'Verificar arquivos do sistema (SFC)') -Group (Get-WinForgeText 'Arquivos do Windows') -Admin `
            -Keywords (Get-WinForgeText 'scannow corrompidos arquivos protegidos integridade verificar integridade cbs') `
            -Description (Get-WinForgeText 'Confere e conserta os arquivos protegidos; 5 a 20 minutos') -Detail (Get-WinForgeText 'Confere os arquivos protegidos do Windows e conserta os danificados; leva de 5 a 20 minutos') -Command "Invoke-WinForgeSfc"),
        (New-WinForgeNavItem -Id "repair.chkdsk" -Label (Get-WinForgeText 'Verificar o sistema de arquivos (CHKDSK)') -Group (Get-WinForgeText 'Disco e dispositivos') -Admin `
            -Keywords (Get-WinForgeText 'disco erros setores defeituosos bad sector verificar hd com problema ntfs fsutil disco corrompido') `
            -Description (Get-WinForgeText 'Procura erros no disco sem reiniciar') -Detail (Get-WinForgeText 'Procura erros no disco sem reiniciar; se precisar de reparo na reinicialização, pergunta antes') -Command "Start-WinForgeChkdsk"),
        (New-WinForgeNavItem -Id "repair.optimize" -Label (Get-WinForgeText 'Otimizar a unidade do sistema') -Group (Get-WinForgeText 'Disco e dispositivos') -Admin `
            -Keywords (Get-WinForgeText 'trim ssd desfragmentar desfragmentação hdd defrag disco lento') `
            -Description (Get-WinForgeText 'O que o Windows já faz toda semana, feito agora') -Detail (Get-WinForgeText 'O que o Windows já faz sozinho toda semana (o TRIM num SSD, desfragmentar num HD), feito agora') -Command "Start-WinForgeDriveOptimization"),
        (New-WinForgeNavItem -Id "repair.device-scan" -Label (Get-WinForgeText 'Detectar dispositivos e drivers') -Group (Get-WinForgeText 'Disco e dispositivos') -Admin `
            -Keywords (Get-WinForgeText 'driver drivers hardware novo pnp pnputil usb não reconhecido dispositivo não reconhecido') `
            -Description (Get-WinForgeText 'Procura hardware novo e instala os drivers disponíveis') -Detail (Get-WinForgeText 'Procura hardware novo e instala os drivers que já estejam disponíveis') -Command "Invoke-WinForgeDeviceScan"),
        (New-WinForgeNavItem -Id "repair.print-queue" -Label (Get-WinForgeText 'Destravar a impressão') -Group (Get-WinForgeText 'Disco e dispositivos') -Admin `
            -Keywords (Get-WinForgeText 'impressora não imprime fila de impressão travada presa documento preso cancelar impressão spooler spool') `
            -Description (Get-WinForgeText 'Reinicia o Spooler de Impressão; apagar a fila é escolha sua') -Detail (Get-WinForgeText 'Para a impressora que não imprime: reinicia o Spooler de Impressão e, se você escolher, esvazia a fila') -Command "Reset-WinForgePrintQueue"),
        (New-WinForgeNavItem -Id "repair.system-restore" -Label (Get-WinForgeText 'Restauração do Sistema') -Group (Get-WinForgeText 'Ferramentas do Windows') `
            -Keywords (Get-WinForgeText 'voltar rstrui desfazer') `
            -Description (Get-WinForgeText 'Abre a janela que volta o PC a um ponto de restauração') -Detail (Get-WinForgeText 'Abre a janela do Windows que volta o PC a um ponto de restauração') -Shortcut "SystemRestore"),
        (New-WinForgeNavItem -Id "repair.recovery" -Label (Get-WinForgeText 'Recuperação') -Group (Get-WinForgeText 'Ferramentas do Windows') `
            -Keywords (Get-WinForgeText 'restaurar pc restaurar o pc restaurar este pc reinstalar formatar inicialização avançada modo de segurança reset') `
            -Description (Get-WinForgeText 'Abre a Recuperação: restaurar o PC e inicialização avançada') -Detail (Get-WinForgeText 'Abre a Recuperação do Windows: restaurar o PC e a inicialização avançada') -Shortcut "Recovery")
    )

    $pages += New-WinForgeNavPage -Id "updates" -Title (Get-WinForgeText 'Atualizações') -Summary (Get-WinForgeText 'Windows, drivers, Microsoft Store e programas.') -Items @(
        (New-WinForgeNavItem -Id "updates.install" -Label (Get-WinForgeText 'Instalar atualizações do Windows') -ButtonText (Get-WinForgeText 'Procurar atualizações') -Group (Get-WinForgeText 'Windows e drivers') -Admin -Accent `
            -Keywords (Get-WinForgeText 'baixar instalar atualizar windows update pendentes progresso reiniciar atualização atualizações pendente kb cumulativa segurança patch desatualizado pc') `
            -Description (Get-WinForgeText 'Procura, baixa e instala aqui mesmo as atualizações') -Detail (Get-WinForgeText 'Procura, baixa e instala aqui mesmo as atualizações pendentes, com o progresso na tela') -Command "Install-WinForgeWindowsUpdates"),
        (New-WinForgeNavItem -Id "updates.drivers" -Label (Get-WinForgeText 'Atualizar drivers') -Group (Get-WinForgeText 'Windows e drivers') -Admin `
            -Keywords (Get-WinForgeText 'driver drivers placa de vídeo som rede wifi bluetooth chipset desatualizado opcionais') `
            -Description (Get-WinForgeText 'Drivers do Windows Update; você marca quais instalar') -Detail (Get-WinForgeText 'Procura drivers no Windows Update e instala os que você marcar; os opcionais vêm desmarcados') -Command "Install-WinForgeDriverUpdates"),
        (New-WinForgeNavItem -Id "updates.vendor-tools" -Label (Get-WinForgeText 'Ferramentas do fabricante') -Group (Get-WinForgeText 'Windows e drivers') `
            -Keywords (Get-WinForgeText 'dell lenovo hp intel nvidia amd geforce radeon fabricante bios firmware support assistant command update') `
            -Description (Get-WinForgeText 'O programa oficial do fabricante para drivers e BIOS') -Detail (Get-WinForgeText 'Indica o programa oficial do fabricante do PC e da placa de vídeo, que acha drivers e BIOS') -Command "Show-WinForgeVendorTools"),
        (New-WinForgeNavItem -Id "updates.repair" -Label (Get-WinForgeText 'Corrigir o Windows Update') -Group (Get-WinForgeText 'Windows e drivers') -Admin `
            -Keywords (Get-WinForgeText 'erro falha falhou falhando travado atualização travada preso parado cache softwaredistribution catroot2 resetar redefinir consertar') `
            -Description (Get-WinForgeText 'Quando as atualizações falham: refaz o cache e os serviços') -Detail (Get-WinForgeText 'Quando as atualizações falham ou travam: refaz o cache do Windows Update e religa os serviços') -Command "Repair-WinForgeWindowsUpdate"),
        (New-WinForgeNavItem -Id "updates.winget" -Label (Get-WinForgeText 'Atualizar programas (winget)') -Group (Get-WinForgeText 'Programas e aplicativos') `
            -Keywords (Get-WinForgeText 'atualizar programas apps upgrade todos tudo desatualizado desatualizados navegador chrome firefox') `
            -Description (Get-WinForgeText 'Programas com versão nova no winget; você escolhe quais') -Detail (Get-WinForgeText 'Mostra os programas com versão nova no winget e atualiza os que você escolher') -Command "Update-WinForgeSoftware"),
        (New-WinForgeNavItem -Id "updates.winget-hold" -Label (Get-WinForgeText 'Manter programas na versão atual') -Group (Get-WinForgeText 'Programas e aplicativos') `
            -Keywords (Get-WinForgeText 'não atualizar segurar bloquear travar fixar congelar versão antiga pin winget pausar atualização de programa') `
            -Description (Get-WinForgeText 'Marque os programas que o WinForge não deve atualizar') -Detail (Get-WinForgeText 'Marque os programas que devem ficar na versão de agora: eles saem das atualizações do WinForge') -Command "Set-WinForgeWingetPins"),
        (New-WinForgeNavItem -Id "updates.store" -Label (Get-WinForgeText 'Atualizar aplicativos da Microsoft Store') -Group (Get-WinForgeText 'Programas e aplicativos') `
            -Keywords (Get-WinForgeText 'loja aplicativos apps') `
            -Description (Get-WinForgeText 'Pede à Microsoft Store as atualizações dos aplicativos') -Detail (Get-WinForgeText 'Pede à Microsoft Store as atualizações dos aplicativos e abre a lista para acompanhar') -Command "Update-WinForgeStoreApps"),
        (New-WinForgeNavItem -Id "updates.windows" -Label (Get-WinForgeText 'Windows Update') -Group (Get-WinForgeText 'Ferramentas do Windows') `
            -Keywords (Get-WinForgeText 'windows update atualizar configurações patch desatualizado verificar pausar adiar desativar atualizações') `
            -Description (Get-WinForgeText 'Abre o Windows Update nas Configurações do Windows') -Shortcut "WindowsUpdate"),
        (New-WinForgeNavItem -Id "updates.optional" -Label (Get-WinForgeText 'Atualizações opcionais') -Group (Get-WinForgeText 'Ferramentas do Windows') `
            -Keywords (Get-WinForgeText 'opcionais prévia preview recursos') `
            -Description (Get-WinForgeText 'Abre as opcionais: drivers e prévias da próxima atualização') -Detail (Get-WinForgeText 'Abre nas Configurações do Windows as opcionais: drivers e prévias da próxima atualização') -Shortcut "OptionalUpdates")
    )

    $pages += New-WinForgeNavPage -Id "software" -Title (Get-WinForgeText 'Programas') -Summary (Get-WinForgeText 'Instale, remova e organize o que roda no PC.') -Items @(
        (New-WinForgeNavItem -Id "software.essentials" -Label (Get-WinForgeText 'Instalar programas essenciais') -ButtonText (Get-WinForgeText 'Escolher programas') -Group (Get-WinForgeText 'Instalar e remover') -Accent `
            -Keywords (Get-WinForgeText 'instalar baixar navegador chrome firefox 7zip 7-zip vlc pdf acrobat libreoffice zoom git aplicativos discord steam vscode code python node nodejs java jdk powershell notepad everything powertoys') `
            -Description (Get-WinForgeText 'Navegadores, leitor de PDF, 7-Zip, VLC e outros comuns') -Detail (Get-WinForgeText 'Escolha numa lista de programas comuns, como navegadores, leitor de PDF, 7-Zip e VLC') -Command "Install-WinForgeEssentialSoftware"),
        (New-WinForgeNavItem -Id "software.find" -Label (Get-WinForgeText 'Buscar e instalar programas') -Group (Get-WinForgeText 'Instalar e remover') `
            -Keywords (Get-WinForgeText 'pesquisar procurar instalar baixar winget app') `
            -Description (Get-WinForgeText 'Procura um programa pelo nome e instala o que você marcar') -Command "Find-WinForgeSoftware"),
        (New-WinForgeNavItem -Id "software.list" -Label (Get-WinForgeText 'Listar programas instalados') -Group (Get-WinForgeText 'Instalar e remover') `
            -Keywords (Get-WinForgeText 'winget lista programas apps instalados') `
            -Description (Get-WinForgeText 'Os programas instalados e quantos têm versão nova') -Detail (Get-WinForgeText 'Conta os programas instalados e quantos têm versão nova, com a lista completa do winget') -Command "Show-WinForgeInstalledSoftware"),
        (New-WinForgeNavItem -Id "software.uninstall" -Label (Get-WinForgeText 'Desinstalar programas') -Group (Get-WinForgeText 'Instalar e remover') `
            -Keywords (Get-WinForgeText 'remover apagar excluir app programa uninstall') `
            -Description (Get-WinForgeText 'Lista os programas e remove os que você marcar') -Command "Uninstall-WinForgeSoftware"),
        (New-WinForgeNavItem -Id "software.remove-apps" -Label (Get-WinForgeText 'Remover aplicativos do Windows') -Group (Get-WinForgeText 'Instalar e remover') `
            -Keywords (Get-WinForgeText 'bloatware pré-instalados candy crush xbox spotify tiktok teams clima notícias cortana bing linkedin office copilot outlook') `
            -Description (Get-WinForgeText 'Os aplicativos que vêm com o PC; remove só os marcados') -Detail (Get-WinForgeText 'Mostra os aplicativos que vêm com o PC e remove só os que você marcar') -Command "Remove-WinForgePreinstalledApps"),
        (New-WinForgeNavItem -Id "software.winget-repair" -Label (Get-WinForgeText 'Reparar o Instalador de Aplicativo') -Group (Get-WinForgeText 'Instalar e remover') -Unlisted `
            -Keywords (Get-WinForgeText 'winget não encontrado não reconhecido sumiu falta app installer registrar consertar') `
            -Description (Get-WinForgeText 'Registra de novo o winget quando ele some do PC') -Detail (Get-WinForgeText 'Registra de novo o winget para esta conta, como a Microsoft indica; se não resolver, abre a Microsoft Store') -Command "Repair-WinForgeWinget"),
        # A mesma ação de Desempenho > Gerenciar inicialização, com as mesmas frases e palavras de busca: a busca, que mostra
        # uma ação uma vez só, traz sempre a de Desempenho, a casa dela (antes, a palavra decidia qual das duas aparecia).
        (New-WinForgeNavItem -Id "software.startup-manager" -Label (Get-WinForgeText 'Gerenciar inicialização') -Group (Get-WinForgeText 'Inicialização e recursos') `
            -Keywords (Get-WinForgeText 'programas iniciam abrem junto boot demora msconfig desativar reativar lento lenta lentidão startup abrir iniciar com o windows') `
            -Description (Get-WinForgeText 'O que abre junto com o Windows; desligue o que não precisa') -Detail (Get-WinForgeText 'O que abre junto com o Windows; desligar o que não precisa deixa o PC leve desde o início') -Command "Set-WinForgeStartupItems"),
        (New-WinForgeNavItem -Id "software.features" -Label (Get-WinForgeText 'Recursos opcionais do Windows') -Group (Get-WinForgeText 'Inicialização e recursos') -Admin `
            -Keywords (Get-WinForgeText 'wsl hyper-v sandbox virtualização net framework telnet smb smb1 powershell ativar desativar') `
            -Description (Get-WinForgeText 'Liga ou desliga WSL, Hyper-V, Windows Sandbox, .NET 3.5...') -Detail (Get-WinForgeText 'Liga ou desliga recursos como WSL, Hyper-V, Windows Sandbox e .NET 3.5') -Command "Set-WinForgeWindowsFeatures"),
        (New-WinForgeNavItem -Id "software.backup" -Label (Get-WinForgeText 'Backup antes de formatar') -Group (Get-WinForgeText 'Backup e formatação') -Admin `
            -Keywords (Get-WinForgeText 'formatar reinstalar windows drivers wifi pendrive exportar lista') `
            -Description (Get-WinForgeText 'Programas, drivers e ajustes; fotos e documentos à parte') -Detail (Get-WinForgeText 'Guarda a lista de programas, os drivers e os ajustes; fotos e documentos você copia à parte') -Command "Invoke-WinForgeBackupBeforeFormat"),
        (New-WinForgeNavItem -Id "software.restore" -Label (Get-WinForgeText 'Restaurar a partir de um backup') -Group (Get-WinForgeText 'Backup e formatação') -Admin `
            -Keywords (Get-WinForgeText 'formatar reinstalar windows drivers wifi importar') `
            -Description (Get-WinForgeText 'Reinstala programas e drivers e reaplica os ajustes') -Detail (Get-WinForgeText 'Reinstala os programas e os drivers e reaplica os ajustes de um backup do WinForge') -Command "Restore-WinForgeFromBackup"),
        (New-WinForgeNavItem -Id "software.installed-apps" -Label (Get-WinForgeText 'Aplicativos instalados') -Group (Get-WinForgeText 'Ferramentas do Windows') `
            -Keywords (Get-WinForgeText 'remover desinstalar lista apps') `
            -Description (Get-WinForgeText 'Abre a lista completa nas Configurações, para desinstalar') -Detail (Get-WinForgeText 'Abre nas Configurações do Windows, em Aplicativos, a lista completa, com a opção de desinstalar') -Shortcut "InstalledApps"),
        (New-WinForgeNavItem -Id "software.programs-features" -Label (Get-WinForgeText 'Programas e Recursos') -Group (Get-WinForgeText 'Ferramentas do Windows') `
            -Keywords (Get-WinForgeText 'painel de controle appwiz desinstalar clássico') `
            -Description (Get-WinForgeText 'Abre o painel de controle clássico, para programas antigos') -Shortcut "ProgramsAndFeatures"),
        (New-WinForgeNavItem -Id "software.startup" -Label (Get-WinForgeText 'Aplicativos de inicialização') -Group (Get-WinForgeText 'Ferramentas do Windows') `
            -Keywords (Get-WinForgeText 'iniciar inicialização abrir boot startup') `
            -Description (Get-WinForgeText 'Abre nas Configurações o que abre junto com o Windows') -Detail (Get-WinForgeText 'Abre nas Configurações do Windows, em Aplicativos, Inicialização, o que abre junto com o Windows') -Shortcut "StartupApps")
    )

    $pages += New-WinForgeNavPage -Id "network" -Title (Get-WinForgeText 'Rede') -Summary (Get-WinForgeText 'Do mais simples ao que mexe mais: ver, testar, medir e consertar a conexão.') -Items @(
        (New-WinForgeNavItem -Id "network.info" -Label (Get-WinForgeText 'Informações de rede') -Group (Get-WinForgeText 'Ver e testar') `
            -Keywords (Get-WinForgeText 'ip gateway adaptador mac endereço internet dns meu público ipconfig placa proxy ssid banda canal') `
            -Description (Get-WinForgeText 'Adaptadores, Wi-Fi, IP, DNS, gateway, proxy e IP público') -Detail (Get-WinForgeText 'Adaptadores, rede Wi-Fi, IP, DNS, gateway, proxy e IP público') -Command "Show-WinForgeNetworkInfo"),
        (New-WinForgeNavItem -Id "network.ping" -Label (Get-WinForgeText 'Testar conectividade (ping)') -ButtonText (Get-WinForgeText 'Testar agora') -Group (Get-WinForgeText 'Ver e testar') -Accent `
            -Keywords (Get-WinForgeText 'latência perda de pacotes sem internet conexão teste lag alto jogo roteador') `
            -Description (Get-WinForgeText 'Se a internet responde e se a conexão está estável') -Detail (Get-WinForgeText 'Diz se a internet responde e se a conexão está estável ou perdendo dados') -Command "Test-WinForgePing"),
        (New-WinForgeNavItem -Id "network.speed" -Label (Get-WinForgeText 'Testar velocidade da internet') -Group (Get-WinForgeText 'Ver e testar') `
            -Keywords (Get-WinForgeText 'speedtest internet lenta wifi download upload mbps banda teste') `
            -Description (Get-WinForgeText 'Latência, download e upload (usa cerca de 35 MB)') -Command "Test-WinForgeInternetSpeed"),
        (New-WinForgeNavItem -Id "network.wifi-report" -Label (Get-WinForgeText 'Relatório de Wi-Fi') -Group (Get-WinForgeText 'Ver e testar') -Admin `
            -Keywords (Get-WinForgeText 'wlan quedas desconexoes sinal wireless wifi wi-fi sem fio caindo cai caiu desconectando instável fraco') `
            -Description (Get-WinForgeText 'Relatório do Windows com as quedas do Wi-Fi recentes') -Detail (Get-WinForgeText 'Gera o relatório do Windows com as sessões e as quedas do Wi-Fi dos últimos dias') -Command "Show-WinForgeWifiReport"),
        (New-WinForgeNavItem -Id "network.wifi-password" -Label (Get-WinForgeText 'Senha do Wi-Fi') -Group (Get-WinForgeText 'Ver e testar') -Admin `
            -Keywords (Get-WinForgeText 'senha wifi wi-fi chave rede sem fio password esqueci visitante') `
            -Description (Get-WinForgeText 'Mostra a senha de uma rede Wi-Fi salva neste PC, só na tela') -Command "Show-WinForgeWifiPassword"),
        (New-WinForgeNavItem -Id "network.time" -Label (Get-WinForgeText 'Acertar a data e a hora') -Group (Get-WinForgeText 'Consertar e configurar') -Admin `
            -Keywords (Get-WinForgeText 'relógio hora errada data errada horário sincronizar ntp w32time fuso relógio atrasado adiantado erro de certificado') `
            -Description (Get-WinForgeText 'Sincroniza o relógio do PC com o servidor de hora agora') -Detail (Get-WinForgeText 'Pede ao Windows para sincronizar o relógio agora e confere a hora num servidor da Microsoft') -Command "Sync-WinForgeTime"),
        (New-WinForgeNavItem -Id "network.repair" -Label (Get-WinForgeText 'Reparar rede e DNS') -Group (Get-WinForgeText 'Consertar e configurar') -Admin `
            -Keywords (Get-WinForgeText 'internet não funciona conecta conectar sem conexão caiu queda wifi wi-fi fio winsock flushdns ipconfig reset renovar reiniciar redefinir dhcp netsh roteador') `
            -Description (Get-WinForgeText 'Refaz as configurações de rede; IP e DNS fixos ficam') -Detail (Get-WinForgeText 'Para quando a internet não funciona: refaz as configurações de rede; IP e DNS fixos são mantidos') -Command "Invoke-WinForgeNetworkRepair"),
        (New-WinForgeNavItem -Id "network.dns" -Label (Get-WinForgeText 'Trocar o servidor DNS') -Group (Get-WinForgeText 'Consertar e configurar') -Admin `
            -Keywords (Get-WinForgeText 'cloudflare google quad9 1.1.1.1 8.8.8.8 1.1.1.3 lento sites família filtro adulto controle parental bloquear') `
            -Description (Get-WinForgeText 'Mede o DNS e troca por Cloudflare, Google ou Quad9') -Detail (Get-WinForgeText 'Mede o tempo de resposta e troca para Cloudflare, Google, Quad9 ou o filtro para famílias') -Command "Set-WinForgeDnsProvider"),
        (New-WinForgeNavItem -Id "network.dns-undo" -Label (Get-WinForgeText 'Desfazer a troca de DNS') -Group (Get-WinForgeText 'Consertar e configurar') -Admin `
            -Keywords (Get-WinForgeText 'voltar restaurar dns original automatico') `
            -Description (Get-WinForgeText 'Devolve o DNS de antes da troca feita pelo WinForge') -Detail (Get-WinForgeText 'Devolve o DNS que o PC usava antes da troca feita pelo WinForge') -Command "Undo-WinForgeDnsChange")
    )

    $pages += New-WinForgeNavPage -Id "tweaks" -Title (Get-WinForgeText 'Ajustes do Windows') -Kind Tweaks `
        -Summary (Get-WinForgeText 'Mudanças reversíveis, com backup do valor original.') -Items @(
        (New-WinForgeNavItem -Id "tweaks.recommended" -Label (Get-WinForgeText 'Aplicar ajustes recomendados') -Accent `
            -Keywords (Get-WinForgeText 'extensão extensões publicidade anúncios propaganda sugestões') `
            -Description (Get-WinForgeText 'Extensões à vista e menos dicas e sugestões; você escolhe') -Detail (Get-WinForgeText 'Mostra as extensões de arquivos e tira dicas, sugestões e o ID de publicidade; você escolhe quais') -Command "Invoke-WinForgeRecommendedTweaks"),
        (New-WinForgeNavItem -Id "tweaks.profiles" -Label (Get-WinForgeText 'Perfis de ajustes') -Admin `
            -Keywords (Get-WinForgeText 'perfil essencial trabalho jogos privacidade notebook conjunto telemetria rastreamento') `
            -Description (Get-WinForgeText 'Essencial, Trabalho, Jogos, Privacidade e Notebook') -Detail (Get-WinForgeText 'Conjuntos prontos: Essencial, Trabalho, Jogos, Privacidade e Notebook; você escolhe o que aplicar') -Command "Invoke-WinForgeTweakProfile"),
        (New-WinForgeNavItem -Id "tweaks.keyboard-language" -Label (Get-WinForgeText 'Teclas que trocam o idioma do teclado') -ListCategory (Get-WinForgeText 'Notificações e teclado') `
            -Keywords (Get-WinForgeText 'alt shift ctrl trocar mudar idioma teclado layout abnt abnt2 internacional muda troca sozinho') `
            -Description (Get-WinForgeText 'Alt + Shift, Ctrl + Shift, as duas ou nenhuma') -Detail (Get-WinForgeText 'Escolhe as teclas que trocam o idioma e o teclado: Alt + Shift, Ctrl + Shift, as duas ou nenhuma') -Command "Set-WinForgeKeyboardLanguageHotkey"),
        (New-WinForgeNavItem -Id "tweaks.notifications" -Label (Get-WinForgeText 'Notificações e Não incomodar') -ListCategory (Get-WinForgeText 'Notificações e teclado') `
            -Keywords (Get-WinForgeText 'assistente de foco silenciar avisos notificação concentração quiet hours') `
            -Description (Get-WinForgeText 'Abre as notificações e o Não incomodar nas Configurações') -Detail (Get-WinForgeText 'Abre nas Configurações do Windows as notificações e o Não incomodar (assistente de foco)') -Shortcut "Notifications"),
        (New-WinForgeNavItem -Id "tweaks.restore-point" -Label (Get-WinForgeText 'Criar ponto de restauração') -Admin `
            -Keywords (Get-WinForgeText 'backup segurança voltar atrás proteção do sistema') `
            -Description (Get-WinForgeText 'Um ponto para voltar atrás se algo der errado') -Command "Invoke-WinForgeRestorePoint"),
        (New-WinForgeNavItem -Id "tweaks.export" -Label (Get-WinForgeText 'Exportar ajustes aplicados') `
            -Keywords (Get-WinForgeText 'salvar backup levar outro pc') `
            -Description (Get-WinForgeText 'Salva os ajustes aplicados, para repetir em outro PC') -Detail (Get-WinForgeText 'Salva em um arquivo os ajustes aplicados neste PC, para repetir em outro') -Command "Export-WinForgeTweaks"),
        (New-WinForgeNavItem -Id "tweaks.import" -Label (Get-WinForgeText 'Importar ajustes') -Admin `
            -Keywords (Get-WinForgeText 'restaurar carregar arquivo outro pc') `
            -Description (Get-WinForgeText 'Aplica ajustes de um arquivo exportado; você escolhe quais') -Detail (Get-WinForgeText 'Aplica ajustes de um arquivo exportado antes, depois de você escolher quais') -Command "Import-WinForgeTweaks"),
        (New-WinForgeNavItem -Id "tweaks.revert-all" -Label (Get-WinForgeText 'Desfazer ajustes do WinForge') -Admin `
            -Keywords (Get-WinForgeText 'reverter voltar padrão original normal tudo') `
            -Description (Get-WinForgeText 'Desfaz tudo o que o WinForge aplicou, usando o backup') -Detail (Get-WinForgeText 'Desfaz tudo o que o WinForge aplicou aqui e na Personalização, usando o backup') -Command "Invoke-WinForgeRevertAllTweaks")
    )

    # O visual do Windows: os ajustes das categorias da Personalização (Get-WinForgeTweakPages) e os atalhos para as telas
    # do Windows que o WinForge não faz. A cor de destaque se escolhe nas Configurações: o Windows não tem um jeito
    # documentado de um programa trocá-la (os valores do registro não são documentados e nem sempre pegam na hora).
    $pages += New-WinForgeNavPage -Id "personalize" -Title (Get-WinForgeText 'Personalização') -Kind Tweaks `
        -Summary (Get-WinForgeText 'O visual do Windows: barra de tarefas, área de trabalho, cores e tela de bloqueio.') -Items @(
        (New-WinForgeNavItem -Id "personalize.accent-color" -Label (Get-WinForgeText 'Cor de destaque') -ListCategory (Get-WinForgeText 'Cores e transparência') `
            -Keywords (Get-WinForgeText 'cor accent azul verde roxo vermelho rosa laranja cinza automática colorir') `
            -Description (Get-WinForgeText 'Abre as Cores do Windows, onde se escolhe a cor') -Detail (Get-WinForgeText 'Abre nas Configurações do Windows as Cores, onde se escolhe a cor de destaque') -Shortcut "Colors"),
        (New-WinForgeNavItem -Id "personalize.lock-screen" -Label (Get-WinForgeText 'Tela de bloqueio do Windows') -ListCategory (Get-WinForgeText 'Tela de bloqueio') `
            -Keywords (Get-WinForgeText 'imagem foto destaque do windows spotlight bloqueio lock screen') `
            -Description (Get-WinForgeText 'Abre a tela de bloqueio: a imagem e o que aparece nela') -Detail (Get-WinForgeText 'Abre nas Configurações do Windows a tela de bloqueio: a imagem e o que aparece nela') -Shortcut "LockScreen"),
        (New-WinForgeNavItem -Id "personalize.settings" -Label (Get-WinForgeText 'Personalização do Windows') `
            -Keywords (Get-WinForgeText 'papel de parede tela de fundo temas fonte wallpaper') `
            -Description (Get-WinForgeText 'Abre a tela de fundo, os temas, as cores e as fontes') -Detail (Get-WinForgeText 'Abre nas Configurações do Windows a tela de fundo, os temas, as cores e as fontes') -Shortcut "Personalization")
    )

    $pages += New-WinForgeNavPage -Id "app" -Title (Get-WinForgeText 'Sobre o WinForge') -Placement Footer `
        -Summary (Get-WinForgeText 'A versão, o suporte e as preferências do WinForge.') -Items @(
        (New-WinForgeNavItem -Id "app.about" -Label (Get-WinForgeText 'Versão e pastas') -Group (Get-WinForgeText 'Versão e dados') `
            -Keywords (Get-WinForgeText 'build powershell instalar winforge desinstalar winforge instalação') `
            -Description (Get-WinForgeText 'A versão aberta, a pasta dela e onde ficam os logs') -Detail (Get-WinForgeText 'Qual versão está aberta, de que pasta, se está instalada e onde ficam os logs e relatórios') -Command "Show-WinForgeAbout"),
        (New-WinForgeNavItem -Id "app.update" -Label (Get-WinForgeText 'Verificar nova versão') -Group (Get-WinForgeText 'Versão e dados') `
            -Keywords (Get-WinForgeText 'atualizar winforge atualização baixar release github') `
            -Description (Get-WinForgeText 'Procura uma versão nova e instala com um clique') -Detail (Get-WinForgeText 'Vê se há uma versão mais nova do WinForge e instala com um clique, conferindo o SHA-256') -Command "Invoke-WinForgeUpdateCheck"),
        (New-WinForgeNavItem -Id "app.catalog" -Label (Get-WinForgeText 'Conferir dados online') -Group (Get-WinForgeText 'Versão e dados') `
            -Keywords (Get-WinForgeText 'catálogo lista essenciais datas suporte') `
            -Description (Get-WinForgeText 'Atualiza a lista de essenciais e as datas de suporte') -Detail (Get-WinForgeText 'Confere na internet a lista de essenciais e as datas de suporte do Windows mais recentes') -Command "Update-WinForgeOnlineData"),
        (New-WinForgeNavItem -Id "app.logs" -Label (Get-WinForgeText 'Pasta de logs e relatórios') -Group (Get-WinForgeText 'Versão e dados') `
            -Keywords (Get-WinForgeText 'log arquivo txt html') `
            -Description (Get-WinForgeText 'Abre a pasta com os logs e os relatórios gerados') -Shortcut "LogFolder"),
        (New-WinForgeNavItem -Id "app.support" -Label (Get-WinForgeText 'Pacote de suporte') -Group (Get-WinForgeText 'Versão e dados') `
            -Keywords (Get-WinForgeText 'suporte ajuda log logs zip problema erro bug enviar mandar técnico') `
            -Description (Get-WinForgeText 'Logs, verificação e versões num zip, para quem vai ajudar') -Detail (Get-WinForgeText 'Junta logs, verificação e versões num zip para mandar a quem vai ajudar') -Command "New-WinForgeSupportPackage"),
        (New-WinForgeNavItem -Id "app.website" -Label (Get-WinForgeText 'Site do WinForge') -Group (Get-WinForgeText 'Versão e dados') `
            -Keywords (Get-WinForgeText 'site página internet web novidades usewinforge') `
            -Description (Get-WinForgeText 'Abre o site do WinForge no navegador') -Shortcut "Website"),
        (New-WinForgeNavItem -Id "app.shortcut" -Label (Get-WinForgeText 'Criar atalho do WinForge') -ButtonText (Get-WinForgeText 'Criar atalho') -Group (Get-WinForgeText 'Integração com o Windows') -Accent `
            -Keywords (Get-WinForgeText 'fixar barra tarefas') `
            -Description (Get-WinForgeText 'Põe o WinForge na Área de Trabalho ou no Menu Iniciar') -Detail (Get-WinForgeText 'Coloca o WinForge, com o ícone dele, na Área de Trabalho ou no Menu Iniciar') -Command "New-WinForgeAppShortcut"),
        (New-WinForgeNavItem -Id "app.monitor" -Label (Get-WinForgeText 'Monitor na bandeja') -Group (Get-WinForgeText 'Integração com o Windows') `
            -Keywords (Get-WinForgeText 'bandeja ícone relógio alertas avisos notificação notificações winforge segundo plano vigiar') `
            -Description (Get-WinForgeText 'Avisa perto do relógio quando algo no PC pede atenção') -Detail (Get-WinForgeText 'Avisa, perto do relógio, quando o disco enche ou falha, a proteção desliga ou falta manutenção') -Command "Set-WinForgeMonitor"),
        # Na janela, o cartão Idioma da página faz o mesmo (por isso fica fora dos cartões): o menu de texto chega aqui, e a
        # busca da janela leva ao cartão (Get-WinForgeSearchCardItem).
        (New-WinForgeNavItem -Id "app.language" -Label (Get-WinForgeText 'Idioma') -Group (Get-WinForgeText 'Integração com o Windows') -Unlisted `
            -Keywords 'idioma idiomas lingua lengua language english ingles espanol espanhol portugues traducao traduccion' `
            -Description (Get-WinForgeText 'Português, inglês ou espanhol; ou o idioma do Windows') -Detail (Get-WinForgeText 'Português, inglês ou espanhol; no automático, o mesmo idioma do Windows') -Command "Set-WinForgeInterfaceLanguage")
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

# O que o caminho recomendado de uma página ganha quando a busca acha a página pelo nome: com a palavra no nome ou nas
# palavras-chave dele, ele passa as outras ações que começam com ela (17); fica sempre abaixo de um nome exato (36 ou mais).
$script:WinForgeSearchHighlightBonus = 10

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
    "consigo", "conseguir", "consegue", "posso", "pode", "qual", "quais", "melhorar", "aumentar", "este", "estes", "estas"
)
$script:WinForgeSearchSoftWords = @("pc", "computador")

# Prefixos que invertem o sentido: um pedaço depois deles não conta como achado ("ativar" em "desativar").
$script:WinForgeSearchNegations = @("des", "re", "in", "im", "dis")

# As terminações que Get-WinForgeSearchStem tira (da mais longa para a mais curta).
$script:WinForgeSearchSuffixes = @("acoes", "acao", "mentos", "mento", "ando", "endo", "indo", "ados", "adas", "ado", "ada", "idos", "idas", "ido", "ida", "ar", "er", "ir", "am", "em", "s")

# As mesmas tabelas em inglês e espanhol (as de cima são as do português): a busca procura no texto da tela, que está no
# idioma da interface, então as palavras de ligação, os sinônimos e as terminações são as desse idioma. Sem acento, como
# a busca compara (ConvertTo-WinForgeSearchText).
$script:WinForgeSearchLanguageTables = @{
    en = @{
        StopWords = @(
            "a", "an", "the", "of", "to", "for", "in", "on", "at", "by", "with", "without", "and", "or", "my", "mine", "i", "me", "is",
            "are", "it", "its", "this", "that", "these", "those", "how", "do", "does", "doesnt", "dont", "not", "no", "too", "very",
            "more", "make", "get", "want", "need", "when", "what", "which", "why", "can", "cant", "cannot", "working", "works", "work",
            "keeps", "keep", "really", "much", "so", "be", "being", "improve", "increase", "itself"
        )
        SoftWords = @("pc", "computer", "laptop")
        Negations = @("dis", "un", "de", "re", "in", "im")
        Suffixes  = @("ations", "ation", "ments", "ment", "ings", "ing", "ers", "ied", "ies", "ed", "er", "es", "s")
        Synonyms  = @(
            "disable deactivate hide",
            "disable deactivate off",
            "enable activate",
            "delete remove erase",
            "fix repair",
            "freezing frozen freezes freeze hanging hangs stuck crashing",
            "slow sluggish laggy",
            "app apps application applications"
        )
    }
    es = @{
        StopWords = @(
            "el", "la", "los", "las", "lo", "un", "una", "unos", "unas", "de", "del", "al", "a", "en", "para", "por", "con", "sin", "y",
            "e", "o", "u", "que", "se", "yo", "me", "mi", "mis", "como", "esta", "estan", "estoy", "muy", "mucho", "mucha", "mas", "no",
            "funciona", "funcionando", "funciono", "solo", "sola", "poco", "poca", "dejar", "deja", "quedar", "queda", "quedo", "cuando",
            "quiero", "necesito", "hacer", "esto", "eso", "ese", "esa", "tiene", "tengo", "puedo", "puede", "cual", "cuales", "mejorar",
            "aumentar", "este", "estos", "estas", "hay"
        )
        SoftWords = @("pc", "computadora", "ordenador", "equipo")
        Negations = @("des", "re", "in", "im", "dis")
        Suffixes  = @("aciones", "acion", "mientos", "miento", "ando", "iendo", "ados", "adas", "ado", "ada", "idos", "idas", "ido", "ida", "ar", "er", "ir", "an", "en", "s")
        Synonyms  = @(
            "desactivar deshabilitar ocultar esconder",
            "desactivar deshabilitar apagar",
            "activar habilitar encender",
            "borrar eliminar suprimir",
            "arreglar reparar corregir",
            "congelado congelada congela congelando colgado colgada cuelga trabado trabada traba",
            "lento lenta",
            "app apps aplicacion aplicaciones"
        )
    }
}

# Palavras que a busca trata como parecidas (cada grupo vale em todos os sentidos). O sinônimo vale 4 pontos a menos que
# a própria palavra: no rótulo, ele fica abaixo da palavra exata em qualquer ponto do rótulo.
$script:WinForgeSearchSynonymPenalty = 4
$script:WinForgeSearchSynonyms = @(
    "desativar desabilitar ocultar esconder",
    "desativar desabilitar desligar",
    "ativar habilitar ligar",
    "apagar excluir deletar",
    "consertar reparar corrigir arrumar",
    "travando travado travou trava congelando congelado congelou congela",
    "lento lenta devagar lerdo lerda",
    "app apps aplicativo aplicativos"
)

# Palavras extras de cada ajuste do Windows (o catálogo de ajustes não tem campo de palavras-chave). Um teste confere
# que todos os Ids existem.
$script:WinForgeSearchTweakKeywords = @{
    "file-extensions"      = (Get-WinForgeText 'extensao tipo exe pdf nome do arquivo')
    "hidden-files"         = (Get-WinForgeText 'ocultos ocultas escondidos escondidas invisiveis pastas')
    "taskbar-left"         = (Get-WinForgeText 'iniciar alinhar centralizar windows 11')
    "classic-context-menu" = (Get-WinForgeText 'botao direito mostrar mais opcoes windows 11')
    "dark-mode"            = (Get-WinForgeText 'dark mode theme tema escuro noite aparencia cores')
    "no-transparency"      = (Get-WinForgeText 'efeitos acrilico visual leve desempenho')
    "show-seconds"         = (Get-WinForgeText 'hora relogio')
    "hide-widgets"         = (Get-WinForgeText 'noticias clima painel windows 11')
    "hide-copilot"         = (Get-WinForgeText 'ia inteligencia artificial assistente windows 11')
    "tips-suggestions"     = (Get-WinForgeText 'anuncios propaganda sugestoes notificacoes telemetria')
    "lock-screen-tips"     = (Get-WinForgeText 'bloqueio lock screen spotlight anuncios')
    "explorer-recent"      = (Get-WinForgeText 'acesso rapido recentes frequentes historico privacidade arquivos abertos')
    "explorer-sync-ads"    = (Get-WinForgeText 'anuncios propaganda onedrive microsoft 365 avisos sincronizacao')
    "search-highlights"    = (Get-WinForgeText 'pesquisa busca destaques ilustracoes noticias datas')
    "storage-sense"        = (Get-WinForgeText 'sensor armazenamento espaco disco cheio limpeza automatica lixeira temporarios')
    "background-apps"      = (Get-WinForgeText 'segundo plano aplicativos memoria bateria windows 10')
    "advertising-id"       = (Get-WinForgeText 'publicidade anuncios rastreamento telemetria privacidade')
    "bing-start"           = (Get-WinForgeText 'pesquisa web internet busca menu iniciar')
    "recall"               = (Get-WinForgeText 'ia captura de tela historico privacidade copilot')
    "game-bar"             = (Get-WinForgeText 'jogo jogos gamer xbox gravacao fps')
    "fast-startup"         = (Get-WinForgeText 'inicializacao rapida hibrida desligar lento boot')
    "high-performance"     = (Get-WinForgeText 'plano de energia alto desempenho velocidade')
    "pcie-aspm"            = (Get-WinForgeText 'pcie pci express placa de video ssd travamento energia')
    "no-sleep-timeouts"    = (Get-WinForgeText 'suspender tela apagar dormir energia')
    "hibernation"          = (Get-WinForgeText 'hiberfil espaco disco hibernar')
    "explorer-this-pc"     = (Get-WinForgeText 'este computador meu pc acesso rapido explorador abrir')
    "taskbar-end-task"     = (Get-WinForgeText 'finalizar tarefa travado travou fechar programa windows 11')
    "autoplay-off"         = (Get-WinForgeText 'reproducao automatica autorun pendrive usb seguranca')
    "taskbar-search"       = (Get-WinForgeText 'caixa busca pesquisar lupa esconder espaco')
    "task-view-button"     = (Get-WinForgeText 'multitarefa desktops virtuais esconder')
    "start-recommendations" = (Get-WinForgeText 'recomendados recomendacoes menu iniciar sugestoes windows 11')
    "tailored-experiences" = (Get-WinForgeText 'experiencias personalizadas privacidade dados de diagnostico anuncios')
    "feedback-requests"    = (Get-WinForgeText 'feedback opiniao pesquisa avaliacao notificacoes')
    "activity-history"     = (Get-WinForgeText 'historico de atividades linha do tempo timeline privacidade')
    "diagnostic-data"      = (Get-WinForgeText 'telemetria dados de diagnostico privacidade coleta envio microsoft')
    "app-tracking"         = (Get-WinForgeText 'rastreamento programas mais usados menu iniciar privacidade')
    "online-speech"        = (Get-WinForgeText 'voz fala ditado reconhecimento privacidade cortana')
    "inking-typing"        = (Get-WinForgeText 'digitacao teclado caneta escrita dicionario privacidade')
    "delivery-peers"       = (Get-WinForgeText 'otimizacao de entrega p2p compartilhar atualizacoes banda internet')
    "early-updates"        = (Get-WinForgeText 'windows update novidades antecipadas antes previa preview instabilidade recursos assim que saem')
    "gpu-scheduling"       = (Get-WinForgeText 'hags placa de video gpu jogos latencia agendamento')
    "taskbar-never-combine" = (Get-WinForgeText 'agrupar combinar desagrupar botoes janelas rotulos nomes windows 11')
    "desktop-recycle-bin"  = (Get-WinForgeText 'lixeira icone area de trabalho esconder remover')
    "desktop-this-pc"      = (Get-WinForgeText 'este computador meu icone area de trabalho')
    "accent-taskbar"       = (Get-WinForgeText 'cor de destaque colorir barra iniciar')
    "accent-titlebars"     = (Get-WinForgeText 'cor de destaque colorir janelas bordas titulo')
    "lock-screen-widgets"  = (Get-WinForgeText 'bloqueio lock screen clima noticias cotacoes widgets')
    "lock-screen-notifications" = (Get-WinForgeText 'bloqueio lock screen avisos notificacoes privacidade')
    "notifications-off"    = (Get-WinForgeText 'avisos notificacoes silenciar desativar toast balao')
    "sticky-keys-shortcut" = (Get-WinForgeText 'teclas de aderencia shift cinco vezes acessibilidade jogos filtragem alternancia')
    "clipboard-history"    = (Get-WinForgeText 'area de transferencia copiar colar windows v historico')
    "game-mode"            = (Get-WinForgeText 'modo de jogo jogos gamer desempenho fps')
    "mouse-acceleration"   = (Get-WinForgeText 'mouse aceleracao precisao do ponteiro mira jogos fps')
}


function Get-WinForgeSearchStem {
    # O começo de uma palavra sem a terminação mais comum do idioma, para "iniciar" achar "inicialização", "limpar"
    # achar "limpeza" e "programas" achar "programa". Vazio quando sobraria menos de 4 letras.
    param ([string]$Token)

    foreach ($suffix in @(Get-WinForgeSearchTable -Name "Suffixes")) {
        if ($Token.Length -ge ($suffix.Length + 4) -and $Token.EndsWith($suffix)) {
            return $Token.Substring(0, $Token.Length - $suffix.Length)
        }
    }

    return ""
}


function Get-WinForgeSearchTable {
    # Uma das tabelas da busca (StopWords, SoftWords, Negations, Suffixes, Synonyms) no idioma da interface.
    param ([Parameter(Mandatory)][ValidateSet("StopWords", "SoftWords", "Negations", "Suffixes", "Synonyms")][string]$Name)

    $language = Get-WinForgeLanguage

    if ($script:WinForgeSearchLanguageTables.ContainsKey($language)) { return @($script:WinForgeSearchLanguageTables[$language][$Name]) }

    switch ($Name) {
        "StopWords" { return @($script:WinForgeSearchStopWords) }
        "SoftWords" { return @($script:WinForgeSearchSoftWords) }
        "Negations" { return @($script:WinForgeSearchNegations) }
        "Suffixes" { return @($script:WinForgeSearchSuffixes) }
        default { return @($script:WinForgeSearchSynonyms) }
    }
}


function Get-WinForgeSearchBase {
    # O singular simples de uma palavra de 5 letras ou mais terminada em "s" ("erros" vira "erro", "drivers" vira "driver"):
    # com ele, a busca acha as duas formas. As demais palavras ficam como estão.
    param ([string]$Token)

    if ($Token.Length -ge 5 -and $Token.EndsWith("s") -and -not $Token.EndsWith("ss")) { return $Token.Substring(0, $Token.Length - 1) }

    return $Token
}


function Get-WinForgeSearchSynonyms {
    # Os sinônimos de uma palavra (sem ela mesma), da tabela WinForgeSearchSynonyms. Uma palavra em dois grupos fica com
    # os dois ("disable" acha "hide" e "off"), sem juntar os grupos entre si ("hide" não acha "off").
    param ([string]$Token)

    if ($null -eq $script:WinForgeSearchSynonymMap) {
        $map = @{}

        foreach ($group in @(Get-WinForgeSearchTable -Name "Synonyms")) {
            $words = @($group -split ' ')

            foreach ($word in $words) {
                $others = @($words | Where-Object { $_ -ne $word })

                if ($map.ContainsKey($word)) { $others = @(@($map[$word]) + $others | Select-Object -Unique) }

                $map[$word] = $others
            }
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

        # Mais texto que a busca reconhece como descrição, sem aparecer no resultado (a frase inteira de um item, Detail).
        [string]$More = "",
        [string]$Keywords = "",
        [string]$PageText = "",
        $Item = $null,
        $Tweak = $null,
        [string]$Section = "",
        [int]$Order = 0,

        # Desempate entre resultados de mesma pontuação: 1 para as ações do WinForge e as partes de página, 2 para os atalhos
        # que só abrem uma janela do Windows, 3 para os ajustes (as páginas, que vêm pelo título, têm 0).
        [int]$Rank = 1,

        # O caminho recomendado da página (o item com Accent): vem logo depois da página quando a busca acha a página pelo
        # nome (Find-WinForgeSearchHits).
        [switch]$Accent
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
    $descWords = " $(ConvertTo-WinForgeSearchIndexWords -Text ("$Description $More".Trim())) "
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
        Accent      = [bool]$Accent
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
            Label       = (Get-WinForgeText 'Aparência do WinForge')
            Description = (Get-WinForgeText 'Claro, escuro ou automático, acompanhando o tema do Windows')
            Keywords    = (Get-WinForgeText 'tema modo escuro claro noturno cores automatico')
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

    # A página (e o título dela) de cada categoria, procurada uma vez só: são poucas categorias para dezenas de ajustes.
    $pages = @{}

    # Cada ajuste é uma chave: "ligar o modo escuro" e "desligar a telemetria" acham a chave, que liga e desliga. Os verbos
    # contam como o texto da página (o menor peso): sozinhos, eles não passam na frente das palavras de cada ajuste.
    $toggle = (Get-WinForgeText 'ativar desativar ligar desligar')

    foreach ($tweak in $catalog) {
        $order++

        try {
            if (-not (Test-WinForgeTweakAvailable -Tweak $tweak)) { continue }

            # Cada ajuste leva à página dele: a Personalização ou os Ajustes do Windows.
            $category = [string]$tweak.Category

            if (-not $pages.ContainsKey($category)) {
                $id = Get-WinForgeTweakPageId -Tweak $tweak
                $page = Get-WinForgeNavPage -Id $id
                $pages[$category] = [PSCustomObject]@{ Id = $id; Title = $(if ($null -ne $page) { [string]$page.Title } else { (Get-WinForgeText 'Ajustes do Windows') }) }
            }

            $pageId = $pages[$category].Id
            $title = $pages[$category].Title
            $extra = [string]$script:WinForgeSearchTweakKeywords[[string]$tweak.Id]

            # O cartão diz o que a página mostra (o recurso do Windows e o que ele é); o nome do ajuste ("Desativar...")
            # também acha o cartão, entre as palavras de busca.
            $feature = [string](Get-WinForgeTweakField -Entry $tweak -Name "Feature" -Default $tweak.Name)
            $about = [string](Get-WinForgeTweakField -Entry $tweak -Name "About" -Default $tweak.Description)

            [void]$entries.Add((New-WinForgeSearchEntry -Kind "Tweak" -PageId $pageId -PageTitle $title -Label $feature `
                        -Description $about -Keywords "$extra $($tweak.Name)" -PageText "$($title.ToLowerInvariant()) $category $toggle" -Tweak $tweak -Order $order -Rank 3))
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
                            -Description $item.Description -More ([string]$item.Detail) -Keywords $item.Keywords -PageText $page.Title -Item $item -Order $order -Rank $rank `
                            -Accent:([bool]$item.Accent)))
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
    $pages = @([PSCustomObject]@{ Id = "home"; Title = (Get-WinForgeText 'Início'); Summary = (Get-WinForgeText 'O estado do PC, a nota de saúde e os atalhos mais procurados.') })

    foreach ($page in (Get-WinForgeNavigation)) {
        $pages += [PSCustomObject]@{ Id = $page.Id; Title = $page.Title; Summary = $page.Summary }
    }

    return $pages
}


function Get-WinForgeSearchPageIndex {
    # As páginas com o título já normalizado (Words) e as palavras dele (TitleWords), montadas uma vez.
    if ($null -eq $script:WinForgeSearchPageIndex) {
        $order = -1000

        $script:WinForgeSearchPageIndex = @(
            foreach ($page in (Get-WinForgeSearchPages)) {
                $order++
                $words = ConvertTo-WinForgeSearchWords -Text $page.Title

                [PSCustomObject]@{
                    Id = $page.Id; Title = $page.Title; Summary = $page.Summary; Words = $words; TitleWords = @($words -split ' '); Order = $order
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

    foreach ($group in @(Get-WinForgeSearchTable -Name "Synonyms")) {
        foreach ($word in ($group -split ' ')) {
            if ($word.Length -ge 4) { $weights[$word] = [int]$weights[$word] + 1 }
        }
    }

    $byLetter = @{}

    # get_Keys(), e não .Keys: as palavras são as chaves, e num índice com a palavra "keys" (o inglês tem, de "Sticky keys")
    # $weights.Keys devolveria o peso dela, e o vocabulário ficaria com uma palavra só.
    foreach ($word in (@($weights.get_Keys()) | Sort-Object)) {
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

        if ($prefix.Length -gt 0 -and $prefix -notin @(Get-WinForgeSearchTable -Name "Negations")) { return $true }

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
    $stopWords = @(Get-WinForgeSearchTable -Name "StopWords")
    $softWords = @(Get-WinForgeSearchTable -Name "SoftWords")
    $meaningful = @($unique | Where-Object { $_ -notin $stopWords })

    # Só palavras de ligação ("de", "para"): valem como estão, para quem ainda está digitando "desinstalar".
    $tokens = @(if ($meaningful.Count -gt 0) { $meaningful } else { $unique })
    $hard = @($tokens | Where-Object { $_ -notin $softWords })

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
    # digitada e vale pelo começo, como uma palavra sozinha. O singular vale como palavra inteira: no começo de outra
    # palavra, ele é só o radical ("programas" acha "Programas" pelo nome e "programador" pelo radical, com o peso dele).
    param ([string[]]$Tokens)

    # "pc" e "computador" só são opcionais quando há outra palavra que conta.
    $softWords = @(Get-WinForgeSearchTable -Name "SoftWords")
    $soft = (@($Tokens | Where-Object { $_ -notin $softWords }).Count -gt 0)
    $last = $(if (@($Tokens).Count -gt 0) { [string]@($Tokens)[-1] } else { "" })

    return @(
        foreach ($token in $Tokens) {
            $base = Get-WinForgeSearchBase -Token $token
            $stem = Get-WinForgeSearchStem -Token $token

            # Probe: o pedaço que precisa estar no texto para qualquer forma de achar valer (o radical é o começo da palavra).
            $variants = @([PSCustomObject]@{
                    Start = " $token"; Whole = " $token "; Token = $token; Inside = ($token.Length -ge 5)
                    Stem = $(if ($stem) { " $stem" } else { "" }); Penalty = 0; Probe = $(if ($stem) { $stem } else { $token })
                })

            if ($base -ne $token) {
                $variants += [PSCustomObject]@{ Start = " $base "; Whole = " $base "; Token = $base; Inside = $false; Stem = ""; Penalty = 1; Probe = " $base" }
            }

            foreach ($synonym in (Get-WinForgeSearchSynonyms -Token $token)) {
                $variants += [PSCustomObject]@{
                    Start = " $synonym"; Whole = " $synonym "; Token = $synonym; Inside = $false; Stem = ""; Penalty = $script:WinForgeSearchSynonymPenalty; Probe = " $synonym"
                }
            }

            [PSCustomObject]@{
                Token = $token; Soft = ($soft -and $token -in $softWords); Variants = $variants
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
    item de até três palavras. O caminho recomendado de uma página achada assim ganha 10 (WinForgeSearchHighlightBonus):
    vem logo depois dela, sem passar um nome exato. Sem -Partial, todas as palavras obrigatórias precisam aparecer; com
    ele, basta uma. Uma palavra de uma ou duas letras que não é a última (e qualquer uma delas com -Partial) só vale inteira.
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
                Score = $total; Matched = $matched; Rank = $entry.Rank; Accent = $entry.Accent; Order = $entry.Order; Target = $entry.Target
                Partial = [bool]$Partial; Corrected = ""
            })
    }

    if (-not $Partial -and $words.Length -ge 2) {
        # Uma busca de uma palavra só (fora "pc") acha também a página por qualquer palavra do título, pelo singular ou pelo
        # radical: "redes" acha Rede, "limpar" acha Limpeza, "atualizar" acha Atualizações, "tweaks" acha Windows tweaks e
        # "winforge" acha Sobre o WinForge. O Início fica de fora ("iniciar" é de inicialização). Uma palavra de ligação já
        # faz mais de uma: "about this pc" é o nome de Sobre este PC, e não o começo de About WinForge.
        $softWords = @(Get-WinForgeSearchTable -Name "SoftWords")
        $plainWords = @($Query.All | Where-Object { $_ -notin $softWords })
        $single = $(if ($Query.Hard -eq 1 -and $plainWords.Count -eq 1) { @($Specs | Where-Object { -not $_.Soft })[0] } else { $null })
        $alternatives = @()

        if ($null -ne $single) {
            $alternatives = @($single.Token, (Get-WinForgeSearchBase -Token $single.Token), $single.Variants[0].Stem.Trim()) | Where-Object { $_.Length -ge 4 }
        }

        $pages = New-Object 'System.Collections.Generic.HashSet[string]'

        foreach ($page in (Get-WinForgeSearchPageIndex)) {
            $score = 0

            if ($page.Words.StartsWith($words)) { $score = $(if ($page.Words -eq $words) { 60 } else { 40 }) }
            elseif ($page.Id -ne "home") {
                foreach ($alternative in $alternatives) {
                    foreach ($titleWord in $page.TitleWords) {
                        if ($titleWord.StartsWith($alternative)) { $score = 40; break }
                    }

                    if ($score -gt 0) { break }
                }
            }

            if ($score -gt 0) {
                [void]$pages.Add([string]$page.Id)
                [void]$found.Add([PSCustomObject]@{
                        Kind = "Page"; PageId = $page.Id; PageTitle = $page.Title; Label = $page.Title; Description = $page.Summary
                        Item = $null; Tweak = $null; Section = ""; Score = $score; Matched = $Query.Hard; Rank = 0; Accent = $false; Order = $page.Order
                        Target = "page:$($page.Id)"; Partial = $false; Corrected = ""
                    })
            }
        }

        # A página achada pelo nome traz logo depois o caminho recomendado dela ("limpar": Limpeza e, em seguida, a Limpeza
        # rápida), quando ele também tem as palavras.
        if ($pages.Count -gt 0) {
            foreach ($hit in $found) {
                if ($hit.Accent -and $hit.Kind -eq "Item" -and $pages.Contains([string]$hit.PageId)) { $hit.Score += $script:WinForgeSearchHighlightBonus }
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
    Page), PageId, PageTitle, Label, Description, Item (ou Tweak), Section, Score, Rank, Accent, Order, Partial e Corrected,
    do melhor para o pior; empates: as páginas, depois as ações, os atalhos do Windows e os ajustes, e então a ordem da
    barra lateral e de cada página (que vai do mais seguro ao que mexe mais fundo). -First limita a quantidade.
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
        $softWords = @(Get-WinForgeSearchTable -Name "SoftWords")
        $unknown = @($prepared.Tokens | Where-Object { $_ -notin $softWords -and -not (Test-WinForgeSearchKnown -Token $_) })
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


# Os itens que, na janela, são um cartão da página (o Idioma de Sobre o WinForge): a busca leva ao cartão, com o foco na
# escolha marcada, e não à pergunta do menu de texto.
$script:WinForgeSearchCardSections = @{ "app.language" = "language" }


function Test-WinForgeNavItemHidden {
    <#
    Se a janela tira um item das páginas neste PC (e, pelo mesmo motivo, da busca): com outro antivírus protegendo o PC,
    as ações do Windows Defender, que não fariam nada; sem bateria, a Saúde da bateria, que só diria isso. AntivirusMode
    e HasBattery vêm da leitura do Início; enquanto ela não termina ("" e $null), nada sai.
    #>
    param (
        [AllowEmptyString()][string]$Id,
        [AllowEmptyString()][string]$AntivirusMode = "",
        $HasBattery = $null
    )

    if ($AntivirusMode -eq "Other" -and $Id -in @("security.signatures", "security.scan", "security.full-scan", "security.folder-scan")) { return $true }
    if ($HasBattery -is [bool] -and -not $HasBattery -and $Id -eq "diagnostics.battery") { return $true }

    return $false
}


function Get-WinForgeSearchCardItem {
    # O item que a janela desenha como cartão para um resultado, e que o clique (ou o Enter no primeiro) executa. Ações e
    # atalhos são os próprios itens da tabela; uma página, uma parte de página, um ajuste e um item que na janela é um
    # cartão (WinForgeSearchCardSections) viram um item "Page" que leva à página. Um ajuste avançado leva junto
    # TweakAdvanced, para a página de ajustes abrir o grupo recolhido onde ele está; uma parte de página leva Section, para
    # a página levar o foco até ela.
    param ([Parameter(Mandatory)]$Hit)

    $section = ""
    if ($Hit.Kind -eq "Item") { $section = [string]$script:WinForgeSearchCardSections[[string]$Hit.Item.Id] }

    if ($section) {
        # Um item que, na janela, é um cartão da página: a busca leva ao cartão, como a Aparência.
        return [PSCustomObject]@{
            Id = "search.page.$($Hit.PageId).$section"; Label = $Hit.Label; Description = $Hit.Description; Kind = "Page"; Command = $Hit.PageId
            Shortcut = ""; Accent = $false; RequiresAdmin = $false; Keywords = ""; TweakId = ""; TweakAdvanced = $false; Section = $section
        }
    }

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
    # O texto discreto acima do título de um resultado: de onde ele vem. Um ajuste (e um item que, na janela, é uma linha
    # no grupo de uma categoria, como a Cor de destaque) leva a categoria em que está na página: "Ajustes do Windows >
    # Explorador".
    param ([Parameter(Mandatory)]$Hit)

    switch ($Hit.Kind) {
        "Page" { return $(if ([string]$Hit.Section) { [string]$Hit.PageTitle } else { (Get-WinForgeText 'Ir para a página') }) }
        "Tweak" { return "$($Hit.PageTitle) > $($Hit.Tweak.Category)" }
        default {
            $category = $(if ($null -ne $Hit.Item -and $null -ne $Hit.Item.PSObject.Properties["ListCategory"]) { [string]$Hit.Item.ListCategory } else { "" })

            if ($category) { return "$($Hit.PageTitle) > $category" }

            return [string]$Hit.PageTitle
        }
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

    if (Test-WinForgeSearchTooShort -Query $Query) { return (Get-WinForgeText 'Continue digitando: a busca começa na segunda letra') }

    $text = Format-WinForgeSearchQuote -Text $Query

    if ($Total -le 0) { return (Get-WinForgeText 'Nada encontrado para ''{0}''' "$text") }

    $what = $(if ($Corrected) { (Get-WinForgeText '''{0}'' (você digitou ''{1}'')' "$(Format-WinForgeSearchQuote -Text $Corrected)" "$text") } else { "'$text'" })
    $enter = $(if ($Total -eq 1) { (Get-WinForgeText 'Enter abre') } else { (Get-WinForgeText 'Enter abre o primeiro') })
    if ($EnterSelects) { $enter = $(if ($Total -eq 1) { (Get-WinForgeText 'Enter seleciona') } else { (Get-WinForgeText 'Enter seleciona o primeiro') }) }

    if ($Partial) {
        $closest = $(if ($Shown -le 1) { (Get-WinForgeText 'o mais próximo') } else { (Get-WinForgeText 'os {0} mais próximos' "$Shown") })
        return (Get-WinForgeText 'Nada tem todas as palavras de {0}; {1} · {2}' "$what" "$closest" "$enter")
    }

    if ($Total -eq 1) { return (Get-WinForgeText '1 resultado para {0} · {1}' "$what" "$enter") }
    if ($Shown -lt $Total) { return (Get-WinForgeText 'Mostrando os {0} melhores de {1} resultados para {2} · {3}' "$Shown" "$Total" "$what" "$enter") }

    return (Get-WinForgeText '{0} resultados para {1} · {2}' "$Total" "$what" "$enter")
}


function Get-WinForgeSearchSuggestions {
    # As buscas sugeridas quando nada foi encontrado, do jeito que a pessoa diria: todas devolvem resultados (um teste
    # confere).
    return @((Get-WinForgeText 'pc lento'), (Get-WinForgeText 'sem espaço'), (Get-WinForgeText 'internet lenta'), (Get-WinForgeText 'vírus'))
}


# ---------------------------------------------------------------------------
# Teclas de atalho da janela
# ---------------------------------------------------------------------------

function Get-WinForgePageShortcutKey {
    # A tecla que abre a página de posição Index na lista dos atalhos (0 = Início): "Ctrl+1" a "Ctrl+9", e "Ctrl+0" para a
    # décima. Vazio depois disso.
    param ([int]$Index)

    if ($Index -lt 0 -or $Index -gt 9) { return "" }

    return (Get-WinForgeText 'Ctrl+{0}' "$(($Index + 1) % 10)")
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
