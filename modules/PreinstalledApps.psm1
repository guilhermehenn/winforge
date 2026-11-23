# Aplicativos que vêm com o Windows (ou que o fabricante e a Microsoft instalam por conta própria) e que muita gente nunca usa.
#
# Só mexe numa lista curta e conhecida, mostra o que existe neste PC e remove apenas o que a pessoa marcar, para o
# usuário atual. Nada é removido do sistema: os aplicativos voltam pela Microsoft Store, menos os que a Microsoft
# aposentou (Reinstallable falso), e a tela diz isso antes.


# ---------------------------------------------------------------------------
# Catálogo
# ---------------------------------------------------------------------------

function Get-WinForgeAppCatalog {
    <#
    Os aplicativos que o WinForge oferece para remover. Pattern é o nome interno do pacote (aceita * no fim) e alcança só
    os pacotes daquele aplicativo: "*Facebook*" pegaria também o Instagram e o Messenger, que são do mesmo fabricante. A
    lista é curta de propósito: nada que o Windows precise para funcionar (Loja, Fotos, Calculadora, Terminal, Segurança
    do Windows, instalador de aplicativos, componentes .NET e VCLibs) está nela, e do Xbox só entra o aplicativo: a Game
    Bar e os componentes de identidade e de rede que os jogos usam ficam.
    #>
    return @(
        [PSCustomObject]@{ Pattern = "Microsoft.BingNews"; Label = (Get-WinForgeText 'Microsoft Notícias'); Description = (Get-WinForgeText 'Notícias do MSN') },
        [PSCustomObject]@{ Pattern = "Microsoft.BingWeather"; Label = (Get-WinForgeText 'Clima'); Description = (Get-WinForgeText 'Previsão do tempo do MSN') },
        [PSCustomObject]@{ Pattern = "Microsoft.GetHelp"; Label = (Get-WinForgeText 'Obter Ajuda'); Description = (Get-WinForgeText 'Atendimento da Microsoft dentro do Windows') },
        [PSCustomObject]@{ Pattern = "Microsoft.Getstarted"; Label = (Get-WinForgeText 'Dicas'); Description = (Get-WinForgeText 'Dicas e tutoriais do Windows') },
        # O aplicativo do Microsoft 365 (o antigo Office) virou Microsoft 365 Copilot em janeiro de 2025, e a Microsoft o
        # chama agora de Microsoft Copilot: o nome da lista é o que a pessoa vê no Menu Iniciar.
        [PSCustomObject]@{ Pattern = "Microsoft.MicrosoftOfficeHub"; Label = (Get-WinForgeText 'Microsoft 365 Copilot (antigo Office)'); Description = (Get-WinForgeText 'O aplicativo do Microsoft 365, que o Windows pode mostrar como Microsoft 365 Copilot ou Copilot; o Office que você já instalou não é afetado') },
        [PSCustomObject]@{ Pattern = "Microsoft.MicrosoftSolitaireCollection"; Label = (Get-WinForgeText 'Microsoft Solitaire Collection'); Description = (Get-WinForgeText 'Jogos de cartas com anúncios') },
        [PSCustomObject]@{ Pattern = "Microsoft.People"; Label = (Get-WinForgeText 'Pessoas'); Description = (Get-WinForgeText 'Agenda de contatos aposentada pela Microsoft: não volta depois de removida'); Reinstallable = $false },
        [PSCustomObject]@{ Pattern = "Microsoft.WindowsFeedbackHub"; Label = (Get-WinForgeText 'Hub de Comentários'); Description = (Get-WinForgeText 'Envio de sugestões e erros à Microsoft') },
        [PSCustomObject]@{ Pattern = "Microsoft.YourPhone"; Label = (Get-WinForgeText 'Vínculo com o Celular'); Description = (Get-WinForgeText 'Liga o celular ao PC; mantenha se você usa') },
        [PSCustomObject]@{ Pattern = "Microsoft.ZuneVideo"; Label = (Get-WinForgeText 'Filmes e TV'); Description = (Get-WinForgeText 'Player e loja de vídeos da Microsoft') },
        # O Mapas e o Paint 3D saíram da Microsoft Store (julho de 2025 e novembro de 2024, nos recursos descontinuados do
        # Windows): removidos, não voltam. O Paint de sempre (Microsoft.Paint) é outro pacote e fica protegido.
        [PSCustomObject]@{ Pattern = "Microsoft.WindowsMaps"; Label = (Get-WinForgeText 'Mapas'); Description = (Get-WinForgeText 'Mapas do Windows; aposentado pela Microsoft: não volta depois de removido'); Reinstallable = $false },
        [PSCustomObject]@{ Pattern = "Microsoft.MSPaint"; Label = (Get-WinForgeText 'Paint 3D'); Description = (Get-WinForgeText 'Desenho em 3D; aposentado pela Microsoft: não volta depois de removido. O Paint de sempre não é afetado'); Reinstallable = $false },
        [PSCustomObject]@{ Pattern = "Microsoft.MixedReality.Portal"; Label = (Get-WinForgeText 'Portal de Realidade Misturada'); Description = (Get-WinForgeText 'Só para óculos de realidade virtual; aposentado pela Microsoft: não volta depois de removido'); Reinstallable = $false },
        [PSCustomObject]@{ Pattern = "Microsoft.Microsoft3DViewer"; Label = (Get-WinForgeText 'Visualizador 3D'); Description = (Get-WinForgeText 'Abre modelos 3D; saiu da Microsoft Store: não volta depois de removido'); Reinstallable = $false },
        [PSCustomObject]@{ Pattern = "Microsoft.Print3D"; Label = (Get-WinForgeText 'Print 3D'); Description = (Get-WinForgeText 'Impressão 3D; aposentado pela Microsoft: não volta depois de removido'); Reinstallable = $false },
        [PSCustomObject]@{ Pattern = "Microsoft.SkypeApp"; Label = (Get-WinForgeText 'Skype'); Description = (Get-WinForgeText 'Aposentado pela Microsoft em 2025: não volta depois de removido'); Reinstallable = $false },
        [PSCustomObject]@{ Pattern = "Microsoft.OneConnect"; Label = (Get-WinForgeText 'Planos Móveis'); Description = (Get-WinForgeText 'Contratação de planos de celular') },
        [PSCustomObject]@{ Pattern = "Microsoft.Wallet"; Label = (Get-WinForgeText 'Microsoft Pay'); Description = (Get-WinForgeText 'Carteira digital') },
        [PSCustomObject]@{ Pattern = "Microsoft.Copilot"; Label = (Get-WinForgeText 'Copilot'); Description = (Get-WinForgeText 'Assistente de IA da Microsoft') },
        [PSCustomObject]@{ Pattern = "Microsoft.OutlookForWindows"; Label = (Get-WinForgeText 'Outlook (novo)'); Description = (Get-WinForgeText 'O novo aplicativo de e-mail; o Outlook do Office não é afetado') },
        [PSCustomObject]@{ Pattern = "Microsoft.Windows.DevHome"; Label = (Get-WinForgeText 'Dev Home'); Description = (Get-WinForgeText 'Painel para desenvolvedores; aposentado pela Microsoft: não volta depois de removido'); Reinstallable = $false },
        [PSCustomObject]@{ Pattern = "Microsoft.BingSearch"; Label = (Get-WinForgeText 'Bing Pesquisa'); Description = (Get-WinForgeText 'Aplicativo de busca do Bing; arquivos e aplicativos continuam sendo achados na pesquisa do Windows') },
        [PSCustomObject]@{ Pattern = "Microsoft.549981C3F5F10"; Label = (Get-WinForgeText 'Cortana'); Description = (Get-WinForgeText 'Assistente aposentado pela Microsoft: não volta depois de removido'); Reinstallable = $false },
        [PSCustomObject]@{ Pattern = "Microsoft.WindowsCommunicationsApps"; Label = (Get-WinForgeText 'Email e Calendário (antigo)'); Description = (Get-WinForgeText 'Aposentado pela Microsoft, não volta depois de removido; e-mails guardados só neste PC são apagados'); Reinstallable = $false },
        [PSCustomObject]@{ Pattern = "Microsoft.PowerAutomateDesktop"; Label = (Get-WinForgeText 'Power Automate'); Description = (Get-WinForgeText 'Automação de tarefas; mantenha se você criou fluxos nele') },
        [PSCustomObject]@{ Pattern = "Microsoft.Todos"; Label = (Get-WinForgeText 'Microsoft To Do'); Description = (Get-WinForgeText 'Lista de tarefas; mantenha se você usa') },
        [PSCustomObject]@{ Pattern = "Microsoft.GamingApp"; Label = (Get-WinForgeText 'Xbox'); Description = (Get-WinForgeText 'Loja e Game Pass de jogos para PC; mantenha se você joga pelo Xbox ou pelo Game Pass') },
        [PSCustomObject]@{ Pattern = "Clipchamp.Clipchamp"; Label = (Get-WinForgeText 'Clipchamp'); Description = (Get-WinForgeText 'Editor de vídeo') },
        [PSCustomObject]@{ Pattern = "MicrosoftTeams"; Label = (Get-WinForgeText 'Microsoft Teams (chat pessoal)'); Description = (Get-WinForgeText 'Versão pessoal do Teams; o Teams de trabalho ou escola não é afetado') },
        [PSCustomObject]@{ Pattern = "MSTeams"; Label = (Get-WinForgeText 'Microsoft Teams (novo)'); Description = (Get-WinForgeText 'O Teams atual, pessoal e de trabalho ou escola; mantenha se você usa o Teams') },
        [PSCustomObject]@{ Pattern = "king.com.CandyCrush*"; Label = (Get-WinForgeText 'Candy Crush'); Description = (Get-WinForgeText 'Jogos instalados por promoção') },
        [PSCustomObject]@{ Pattern = "SpotifyAB.SpotifyMusic"; Label = (Get-WinForgeText 'Spotify'); Description = (Get-WinForgeText 'Aplicativo de música instalado por promoção') },
        [PSCustomObject]@{ Pattern = "4DF9E0F8.Netflix"; Label = (Get-WinForgeText 'Netflix'); Description = (Get-WinForgeText 'Aplicativo instalado por promoção') },
        [PSCustomObject]@{ Pattern = "Disney.*"; Label = (Get-WinForgeText 'Disney+'); Description = (Get-WinForgeText 'Aplicativo instalado por promoção') },
        [PSCustomObject]@{ Pattern = "BytedancePte.Ltd.TikTok"; Label = "TikTok"; Description = (Get-WinForgeText 'Aplicativo instalado por promoção') },
        [PSCustomObject]@{ Pattern = "AmazonVideo.PrimeVideo"; Label = (Get-WinForgeText 'Prime Video'); Description = (Get-WinForgeText 'Aplicativo instalado por promoção') },
        [PSCustomObject]@{ Pattern = "Facebook.Facebook"; Label = (Get-WinForgeText 'Facebook'); Description = (Get-WinForgeText 'Aplicativo instalado por promoção') },
        [PSCustomObject]@{ Pattern = "Facebook.InstagramBeta"; Label = (Get-WinForgeText 'Instagram'); Description = (Get-WinForgeText 'Aplicativo instalado por promoção') },
        [PSCustomObject]@{ Pattern = "7EE7776C.LinkedInforWindows"; Label = "LinkedIn"; Description = (Get-WinForgeText 'Aplicativo instalado por promoção') }
    )
}


function Test-WinForgeAppProtected {
    <#
    Pacotes que nunca podem ser removidos, mesmo que um padrão do catálogo os alcance: componentes (framework), itens
    marcados pelo Windows como não removíveis e pacotes assinados como parte do sistema.
    #>
    param (
        [Parameter(Mandatory)]
        $Package
    )

    if ([bool](Get-WinForgeJsonValue -Object $Package -Name "IsFramework" -Default $false)) { return $true }
    if ([bool](Get-WinForgeJsonValue -Object $Package -Name "NonRemovable" -Default $false)) { return $true }
    if ([string](Get-WinForgeJsonValue -Object $Package -Name "SignatureKind" -Default "") -eq "System") { return $true }

    $name = [string](Get-WinForgeJsonValue -Object $Package -Name "Name" -Default "")

    return ($name -match '^(Microsoft\.(WindowsStore|StorePurchaseApp|DesktopAppInstaller|SecHealthUI|WindowsTerminal|WindowsCalculator|Windows\.Photos|WindowsNotepad|Paint|NET\.|VCLibs|UI\.Xaml|Services\.Store)|Windows\.|MicrosoftWindows\.)')
}


function Get-WinForgeInstalledAppCatalog {
    <#
    Os aplicativos do catálogo que existem neste PC, para o usuário atual: Key (uma por item do catálogo), Label,
    Description e FullNames (um por arquitetura instalada). Pacotes protegidos nunca entram. Sem conseguir listar os
    pacotes, lança o erro: "nenhum instalado" seria um palpite.
    #>
    # Uma consulta só, filtrada aqui: perguntar ao Windows item por item levava uma consulta por aplicativo do catálogo.
    $installed = @(Get-AppxPackage -ErrorAction Stop | Where-Object { $null -ne $_ -and -not (Test-WinForgeAppProtected -Package $_) })
    $taken = @{}
    $found = @()

    foreach ($entry in @(Get-WinForgeAppCatalog)) {
        # Um pacote pertence a um item só (o primeiro que o alcança): remover um item nunca remove o pacote de outro.
        $packages = @($installed | Where-Object { [string]$_.Name -like $entry.Pattern -and -not $taken.ContainsKey([string]$_.PackageFullName) })

        if ($packages.Count -eq 0) { continue }

        foreach ($package in $packages) { $taken[[string]$package.PackageFullName] = $true }

        $found += [PSCustomObject]@{
            Key           = [string]$entry.Pattern
            Label         = $entry.Label
            Description   = $entry.Description
            Reinstallable = [bool](Get-WinForgeJsonValue -Object $entry -Name "Reinstallable" -Default $true)
            FullNames     = @($packages | ForEach-Object { [string]$_.PackageFullName } | Select-Object -Unique)
        }
    }

    return @($found | Sort-Object -Property Label)
}


function Get-WinForgeAppRemovalResult {
    <#
    O resultado de remover um aplicativo a partir do erro do Remove-AppxPackage. Os códigos conhecidos viram frase, com o
    código junto ("o aplicativo está aberto; feche-o e tente de novo — erro 0x80073D02"); os significados são os da tabela
    de erros de implantação de aplicativos da Microsoft. Um pacote que já não estava instalado conta como removido.
    #>
    param (
        [string]$Message,
        [int]$HResult = 0
    )

    $code = Get-WinForgeErrorCode -Message $Message -HResult $HResult

    switch ($code) {
        "0x80073CF1" { return (New-WinForgeResult -Kind Ok -Detail (Get-WinForgeText 'já não estava instalado')) }
        "0x80073D02" { return (New-WinForgeResult -Kind Failed -Detail (Get-WinForgeText 'o aplicativo está aberto; feche-o e tente de novo — erro {0}' "$code")) }
        "0x80073CFA" { return (New-WinForgeResult -Kind Failed -Detail (Get-WinForgeText 'o Windows não permitiu a remoção — erro {0}' "$code")) }
        "0x80070005" { return (New-WinForgeResult -Kind Failed -Detail (Get-WinForgeText 'acesso negado — erro {0}' "$code")) }
    }

    if ($code) {
        return (New-WinForgeResult -Kind Failed -Detail (Get-WinForgeText 'a remoção falhou — erro {0}' "$code"))
    }

    $text = @(([string]$Message) -split "[\r\n]+" | Where-Object { $_.Trim() }) | Select-Object -First 1
    $text = $(if ($text) { ([string]$text).Trim().TrimEnd('.') } else { (Get-WinForgeText 'a remoção falhou') })

    return (New-WinForgeResult -Kind Failed -Detail $text)
}


function Get-WinForgeCheckedAppResults {
    <#
    A conferência depois de remover: um aplicativo só conta como removido quando nenhum pacote dele (pelo nome do pacote,
    em qualquer arquitetura ou versão) aparece mais na lista do Windows para o usuário atual. Apps: os itens marcados
    (FullNames); Results: o resultado da remoção de cada um, na mesma ordem. Devolve o resultado final de cada um:
    - saiu: o resultado da remoção ("removido", "já não estava instalado"), ou Ok se a remoção relatou erro e ainda assim
      saiu;
    - continua: o erro da remoção, ou Failed "continua instalado" se a remoção não relatou erro;
    - a lista não pôde ser lida: Failed "não foi possível conferir se saiu" (nada é dado como removido sem ela).
    #>
    param (
        [Parameter(Mandatory)][object[]]$Apps,
        [Parameter(Mandatory)][object[]]$Results
    )

    # O nome do pacote é a parte do nome completo antes do primeiro "_" (Microsoft.BingWeather_4.53_x64__8wekyb3d8bbwe).
    $left = $null

    try {
        $left = @(Get-AppxPackage -ErrorAction Stop | Where-Object { $null -ne $_ } | ForEach-Object { [string]$_.Name })
    }
    catch {
        $left = $null
    }

    $final = @()

    for ($i = 0; $i -lt @($Apps).Count; $i++) {
        $result = $Results[$i]
        $names = @(@($Apps[$i].FullNames) | ForEach-Object { ([string]$_).Split('_')[0] } | Select-Object -Unique)

        if ($null -eq $left) {
            if ($result.Kind -ne "Failed") { $result = New-WinForgeResult -Kind Failed -Detail (Get-WinForgeText 'não foi possível conferir se saiu') }
        }
        elseif (@($left | Where-Object { $names -contains $_ }).Count -gt 0) {
            if ($result.Kind -ne "Failed") { $result = New-WinForgeResult -Kind Failed -Detail (Get-WinForgeText 'continua instalado') }
        }
        elseif ($result.Kind -eq "Failed") {
            $result = New-WinForgeResult -Kind Ok
        }

        $result.Etapa = [string]$Apps[$i].Label
        $final += $result
    }

    return $final
}


# ---------------------------------------------------------------------------
# Ação
# ---------------------------------------------------------------------------

function Remove-WinForgePreinstalledApps {
    $title = (Get-WinForgeText 'Remover aplicativos do Windows')

    Enter-WinForgeAction -Title $title

    $final = New-WinForgeResult -Kind Ok -Title $title

    try {
        # Elevado com outra conta, os aplicativos removidos seriam os dessa conta, não os da pessoa logada.
        if (Test-WinForgeUserContextMismatch) {
            $interactiveUser = Get-WinForgeInteractiveUser
            Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'O WinForge está elevado com outra conta, não a de {0}. Abra-o sem trocar de conta.' "$interactiveUser")
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Skipped -Detail (Get-WinForgeText 'o WinForge está elevado com outra conta') -Title $title)
            return
        }

        Write-Progress -Activity (Get-WinForgeText 'Remover aplicativos do Windows') -Status (Get-WinForgeText 'procurando os aplicativos da lista neste PC')

        try {
            $apps = @(Get-WinForgeInstalledAppCatalog)
        }
        finally {
            Write-Progress -Activity (Get-WinForgeText 'Remover aplicativos do Windows') -Completed
        }

        if ($apps.Count -eq 0) {
            Write-WinForgeStatus -Type Success -Message (Get-WinForgeText 'Nenhum dos aplicativos da lista está instalado.')
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Skipped -Detail (Get-WinForgeText 'nenhum aplicativo da lista está instalado') -Title $title)
            return
        }

        # Nada vem marcado. A remoção vale para o usuário atual, e o aplicativo volta pela Microsoft Store, menos os que a
        # Microsoft aposentou (a descrição deles diz isso, e a confirmação repete).
        $options = @($apps | ForEach-Object { @{ Key = $_.Key; Label = $_.Label; Description = $_.Description } })
        $picked = Read-WinForgeMultiSelect -Message (Get-WinForgeText 'Quais aplicativos remover?') -Options $options -NoSelectAll -ConfirmLabel (Get-WinForgeText 'Remover')

        if ($null -eq $picked -or @($picked).Count -eq 0) {
            Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'Operação cancelada.')
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Skipped -Detail (Get-WinForgeText 'cancelado pelo usuário') -Title $title)
            return
        }

        $chosen = @($apps | Where-Object { @($picked) -contains $_.Key })
        $question = Get-WinForgeSelectionQuestion -Verb (Get-WinForgeText 'Remover') -Names @($chosen | ForEach-Object { [string]$_.Label }) -Many (Get-WinForgeText 'aplicativos')
        $retired = @($chosen | Where-Object { -not $_.Reinstallable } | ForEach-Object { [string]$_.Label })

        # Os que a Microsoft aposentou não voltam pela Store: a confirmação repete o que a descrição deles já dizia.
        if ($retired.Count -gt 0) {
            Write-WinForgeStatus -Type Warning -Notice -Message (Get-WinForgeText '{0} {1} pela Microsoft Store.' "$(Join-WinForgeList -Items $retired)" "$(if ($retired.Count -eq 1) { (Get-WinForgeText 'não volta') } else { (Get-WinForgeText 'não voltam') })")
        }

        # Um aposentado removido não volta: o botão vem como o das ações que apagam sem volta.
        if (-not (Confirm-WinForgeAction -Message $question -DefaultKey "N" -Danger:($retired.Count -gt 0) -YesLabel (Get-WinForgeText 'Remover') -NoLabel (Get-WinForgeText 'Cancelar'))) {
            Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'Operação cancelada.')
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Skipped -Detail (Get-WinForgeText 'cancelado pelo usuário') -Title $title)
            return
        }

        $results = @()
        $position = 0

        try {
            foreach ($app in $chosen) {
                $position++
                Write-Progress -Activity (Get-WinForgeText 'Removendo aplicativos') -Status (Get-WinForgeText '{0} de {1}: {2}' "$position" "$($chosen.Count)" "$($app.Label)") -PercentComplete ([int](($position - 1) * 100 / $chosen.Count))

                # Um aplicativo pode ter um pacote por arquitetura: a primeira falha decide, e "já não estava instalado" só
                # vale quando nenhum dos pacotes estava.
                $failure = $null
                $absent = 0

                foreach ($fullName in $app.FullNames) {
                    try {
                        Remove-AppxPackage -Package $fullName -ErrorAction Stop
                    }
                    catch {
                        $attempt = Get-WinForgeAppRemovalResult -Message $_.Exception.Message -HResult $_.Exception.HResult

                        if ($attempt.Kind -eq "Ok") { $absent++ }
                        elseif ($null -eq $failure) { $failure = $attempt }
                    }
                }

                $result = $(if ($null -ne $failure) { $failure } elseif ($absent -eq @($app.FullNames).Count) { New-WinForgeResult -Kind Ok -Detail (Get-WinForgeText 'já não estava instalado') } else { New-WinForgeResult -Kind Ok })
                $result.Etapa = $app.Label
                $results += $result
            }

            # A conferência: um aplicativo só conta como removido quando sai da lista de pacotes do Windows
            # (Get-WinForgeCheckedAppResults).
            Write-Progress -Activity (Get-WinForgeText 'Removendo aplicativos') -Status (Get-WinForgeText 'conferindo o que saiu')
            $results = @(Get-WinForgeCheckedAppResults -Apps $chosen -Results $results)
        }
        finally {
            Write-Progress -Activity (Get-WinForgeText 'Removendo aplicativos') -Completed
        }

        foreach ($result in $results) {
            if ($result.Kind -eq "Ok") {
                Write-WinForgeStatus -Type Success -Message "$($result.Etapa): $(if ($result.Detail) { $result.Detail } else { (Get-WinForgeText 'removido') })."
            }
            else {
                Write-WinForgeStatus -Type Error -Message "$($result.Etapa): $($result.Detail)."
            }
        }

        # No console, a tabela junta tudo no fim; na janela, cada aplicativo já tem a sua linha no resumo.
        if ($results.Count -gt 1 -and -not (Test-WinForgeGuiMode)) {
            Write-WinForgeSection -Title (Get-WinForgeText 'Resumo')
            Write-WinForgeResultTable -Results $results
        }

        $failed = @($results | Where-Object { $_.Kind -eq "Failed" })
        $names = Join-WinForgeList -Items @($failed | ForEach-Object { [string]$_.Etapa })
        $removed = @($results | Where-Object { $_.Kind -ne "Failed" } | ForEach-Object { [string]$_.Etapa })
        $back = @($chosen | Where-Object { $removed -contains [string]$_.Label -and $_.Reinstallable } | ForEach-Object { [string]$_.Label })
        $gone = @($chosen | Where-Object { $removed -contains [string]$_.Label -and -not $_.Reinstallable } | ForEach-Object { [string]$_.Label })

        if ($removed.Count -gt 0) {
            # O Histórico não promete a volta pela Store de um aplicativo que a Microsoft aposentou.
            # "1 aplicativo removido: Dicas", e não "Dicas removido": o nome do aplicativo pode ser feminino ou plural.
            $parts = @()
            if ($back.Count -gt 0) {
                $parts += $(if ($back.Count -eq 1) { (Get-WinForgeText '1 aplicativo removido: {0} (volta pela Microsoft Store)' "$(Join-WinForgeList -Items $back)") } else { (Get-WinForgeText '{0} aplicativos removidos: {1} (voltam pela Microsoft Store)' "$($back.Count)" "$(Join-WinForgeList -Items $back)") })
            }
            if ($gone.Count -gt 0) {
                $parts += $(if ($gone.Count -eq 1) { (Get-WinForgeText '1 aplicativo removido: {0} (aposentado pela Microsoft, não volta)' "$(Join-WinForgeList -Items $gone)") } else { (Get-WinForgeText '{0} aplicativos removidos: {1} (aposentados pela Microsoft, não voltam)' "$($gone.Count)" "$(Join-WinForgeList -Items $gone)") })
            }
            [void](Add-WinForgeChange -Action (Get-WinForgeText 'Aplicativos do Windows') -Text ($parts -join "; "))
            # A marca de "já instalado" das telas de instalar é lida de novo.
            Clear-WinForgeInstalledWingetIdsCache
        }

        if ($failed.Count -eq 0) {
            $detail = $(if ($results.Count -eq 1) { (Get-WinForgeText '1 aplicativo removido: {0}' "$($results[0].Etapa)") } else { (Get-WinForgeText '{0} aplicativos removidos' "$($results.Count)") })
            $final = New-WinForgeResult -Kind Ok -Detail $detail -Title $title

            # Na janela, o título diz quantos; a frase, quais e se voltam pela Microsoft Store.
            $storeNote = $(
                if ($gone.Count -eq 0) { $(if ($back.Count -eq 1) { (Get-WinForgeText 'Volta pela Microsoft Store, se precisar.') } else { (Get-WinForgeText 'Voltam pela Microsoft Store, se precisar.') }) }
                elseif ($back.Count -eq 0) { $(if ($gone.Count -eq 1) { (Get-WinForgeText 'Não volta pela Microsoft Store: a Microsoft aposentou esse aplicativo.') } else { (Get-WinForgeText 'Não voltam pela Microsoft Store: a Microsoft aposentou esses aplicativos.') }) }
                else { $(if ($back.Count -eq 1) { (Get-WinForgeText 'Só {0} volta pela Microsoft Store.' "$(Join-WinForgeShortList -Items $back)") } else { (Get-WinForgeText 'Só {0} voltam pela Microsoft Store.' "$(Join-WinForgeShortList -Items $back)") }) }
            )
            [void](Set-WinForgeResultView -Result $final -Headline (Format-WinForgeCount -Count $removed.Count -One (Get-WinForgeText 'aplicativo removido') -Many (Get-WinForgeText 'aplicativos removidos')) `
                    -Note "$(Join-WinForgeShortList -Items $removed). $storeNote")
        }
        elseif ($failed.Count -eq $results.Count) {
            $detail = $(if ($results.Count -eq 1) { (Get-WinForgeText 'não foi possível remover {0}: {1}' "$($names)" "$($failed[0].Detail)") } else { (Get-WinForgeText 'nenhum aplicativo foi removido: {0}' "$names") })
            $final = New-WinForgeResult -Kind Failed -Detail $detail -Title $title

            # Na janela, o título diz que nada saiu; a frase, o motivo (de um só) ou onde estão os motivos.
            [void](Set-WinForgeResultView -Result $final -Headline $(if ($results.Count -eq 1) { (Get-WinForgeText 'O aplicativo não foi removido') } else { (Get-WinForgeText 'Nenhum aplicativo foi removido') }) `
                    -Note $(if ($results.Count -eq 1) { "$($failed[0].Etapa): $(([string]$failed[0].Detail).TrimEnd('.'))." } else { (Get-WinForgeText 'O motivo de cada um está no resumo.') }))
        }
        else {
            $verbText = $(if ($failed.Count -eq 1) { (Get-WinForgeText 'não foi removido') } else { (Get-WinForgeText 'não foram removidos') })
            $final = New-WinForgeResult -Kind Warning -Detail (Get-WinForgeText '{0} de {1} {2}: {3}' "$($failed.Count)" "$($results.Count)" "${verbText}" "$names") -Title $title
            $reason = $(if ($failed.Count -eq 1) { (Get-WinForgeText 'o motivo está no resumo') } else { (Get-WinForgeText 'o motivo de cada um está no resumo') })
            [void](Set-WinForgeResultView -Result $final -Headline (Get-WinForgeText '{0} de {1} aplicativos removidos' "$($removed.Count)" "$($results.Count)") `
                    -Note "$(Join-WinForgeShortList -Items @($failed | ForEach-Object { [string]$_.Etapa })) ${verbText}; $reason.")
        }
    }
    catch {
        Write-WinForgeStatus -Type Error -Message (Get-WinForgeText 'Não foi possível remover os aplicativos: {0}' "$($_.Exception.Message)")
        $final = New-WinForgeResult -Kind Failed -Detail $_.Exception.Message -Title $title
    }

    Exit-WinForgeAction -Result $final
}


Export-ModuleMember -Function *
