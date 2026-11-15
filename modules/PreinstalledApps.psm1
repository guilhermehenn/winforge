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
        [PSCustomObject]@{ Pattern = "Microsoft.BingNews"; Label = "Microsoft Notícias"; Description = "Notícias do MSN" },
        [PSCustomObject]@{ Pattern = "Microsoft.BingWeather"; Label = "Clima"; Description = "Previsão do tempo do MSN" },
        [PSCustomObject]@{ Pattern = "Microsoft.GetHelp"; Label = "Obter Ajuda"; Description = "Atendimento da Microsoft dentro do Windows" },
        [PSCustomObject]@{ Pattern = "Microsoft.Getstarted"; Label = "Dicas"; Description = "Dicas e tutoriais do Windows" },
        [PSCustomObject]@{ Pattern = "Microsoft.MicrosoftOfficeHub"; Label = "Microsoft 365 (atalho)"; Description = "Só o atalho para assinar o Microsoft 365; o Office que você já instalou não é afetado" },
        [PSCustomObject]@{ Pattern = "Microsoft.MicrosoftSolitaireCollection"; Label = "Microsoft Solitaire Collection"; Description = "Jogos de cartas com anúncios" },
        [PSCustomObject]@{ Pattern = "Microsoft.People"; Label = "Pessoas"; Description = "Agenda de contatos aposentada pela Microsoft: não volta depois de removida"; Reinstallable = $false },
        [PSCustomObject]@{ Pattern = "Microsoft.WindowsFeedbackHub"; Label = "Hub de Comentários"; Description = "Envio de sugestões e erros à Microsoft" },
        [PSCustomObject]@{ Pattern = "Microsoft.YourPhone"; Label = "Vínculo com o Celular"; Description = "Liga o celular ao PC; mantenha se você usa" },
        [PSCustomObject]@{ Pattern = "Microsoft.ZuneVideo"; Label = "Filmes e TV"; Description = "Player e loja de vídeos da Microsoft" },
        [PSCustomObject]@{ Pattern = "Microsoft.WindowsMaps"; Label = "Mapas"; Description = "Mapas do Windows" },
        [PSCustomObject]@{ Pattern = "Microsoft.MixedReality.Portal"; Label = "Portal de Realidade Misturada"; Description = "Só para óculos de realidade virtual; aposentado pela Microsoft: não volta depois de removido"; Reinstallable = $false },
        [PSCustomObject]@{ Pattern = "Microsoft.Microsoft3DViewer"; Label = "Visualizador 3D"; Description = "Abre modelos 3D; saiu da Microsoft Store: não volta depois de removido"; Reinstallable = $false },
        [PSCustomObject]@{ Pattern = "Microsoft.Print3D"; Label = "Print 3D"; Description = "Impressão 3D; aposentado pela Microsoft: não volta depois de removido"; Reinstallable = $false },
        [PSCustomObject]@{ Pattern = "Microsoft.SkypeApp"; Label = "Skype"; Description = "Aposentado pela Microsoft em 2025: não volta depois de removido"; Reinstallable = $false },
        [PSCustomObject]@{ Pattern = "Microsoft.OneConnect"; Label = "Planos Móveis"; Description = "Contratação de planos de celular" },
        [PSCustomObject]@{ Pattern = "Microsoft.Wallet"; Label = "Microsoft Pay"; Description = "Carteira digital" },
        [PSCustomObject]@{ Pattern = "Microsoft.Copilot"; Label = "Copilot"; Description = "Assistente de IA da Microsoft" },
        [PSCustomObject]@{ Pattern = "Microsoft.OutlookForWindows"; Label = "Outlook (novo)"; Description = "O novo aplicativo de e-mail; o Outlook do Office não é afetado" },
        [PSCustomObject]@{ Pattern = "Microsoft.Windows.DevHome"; Label = "Dev Home"; Description = "Painel para desenvolvedores; aposentado pela Microsoft: não volta depois de removido"; Reinstallable = $false },
        [PSCustomObject]@{ Pattern = "Microsoft.BingSearch"; Label = "Bing Pesquisa"; Description = "Aplicativo de busca do Bing; arquivos e aplicativos continuam sendo achados na pesquisa do Windows" },
        [PSCustomObject]@{ Pattern = "Microsoft.549981C3F5F10"; Label = "Cortana"; Description = "Assistente aposentado pela Microsoft: não volta depois de removido"; Reinstallable = $false },
        [PSCustomObject]@{ Pattern = "Microsoft.WindowsCommunicationsApps"; Label = "Email e Calendário (antigo)"; Description = "Aposentado pela Microsoft, não volta depois de removido; e-mails guardados só neste PC são apagados"; Reinstallable = $false },
        [PSCustomObject]@{ Pattern = "Microsoft.PowerAutomateDesktop"; Label = "Power Automate"; Description = "Automação de tarefas; mantenha se você criou fluxos nele" },
        [PSCustomObject]@{ Pattern = "Microsoft.Todos"; Label = "Microsoft To Do"; Description = "Lista de tarefas; mantenha se você usa" },
        [PSCustomObject]@{ Pattern = "Microsoft.GamingApp"; Label = "Xbox"; Description = "Loja e Game Pass de jogos para PC; mantenha se você joga pelo Xbox ou pelo Game Pass" },
        [PSCustomObject]@{ Pattern = "Clipchamp.Clipchamp"; Label = "Clipchamp"; Description = "Editor de vídeo" },
        [PSCustomObject]@{ Pattern = "MicrosoftTeams"; Label = "Microsoft Teams (chat pessoal)"; Description = "Versão pessoal do Teams; o Teams de trabalho ou escola não é afetado" },
        [PSCustomObject]@{ Pattern = "MSTeams"; Label = "Microsoft Teams (novo)"; Description = "O Teams atual, pessoal e de trabalho ou escola; mantenha se você usa o Teams" },
        [PSCustomObject]@{ Pattern = "king.com.CandyCrush*"; Label = "Candy Crush"; Description = "Jogos instalados por promoção" },
        [PSCustomObject]@{ Pattern = "SpotifyAB.SpotifyMusic"; Label = "Spotify"; Description = "Aplicativo de música instalado por promoção" },
        [PSCustomObject]@{ Pattern = "4DF9E0F8.Netflix"; Label = "Netflix"; Description = "Aplicativo instalado por promoção" },
        [PSCustomObject]@{ Pattern = "Disney.*"; Label = "Disney+"; Description = "Aplicativo instalado por promoção" },
        [PSCustomObject]@{ Pattern = "BytedancePte.Ltd.TikTok"; Label = "TikTok"; Description = "Aplicativo instalado por promoção" },
        [PSCustomObject]@{ Pattern = "AmazonVideo.PrimeVideo"; Label = "Prime Video"; Description = "Aplicativo instalado por promoção" },
        [PSCustomObject]@{ Pattern = "Facebook.Facebook"; Label = "Facebook"; Description = "Aplicativo instalado por promoção" },
        [PSCustomObject]@{ Pattern = "Facebook.InstagramBeta"; Label = "Instagram"; Description = "Aplicativo instalado por promoção" },
        [PSCustomObject]@{ Pattern = "7EE7776C.LinkedInforWindows"; Label = "LinkedIn"; Description = "Aplicativo instalado por promoção" }
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
        "0x80073CF1" { return (New-WinForgeResult -Kind Ok -Detail "já não estava instalado") }
        "0x80073D02" { return (New-WinForgeResult -Kind Failed -Detail "o aplicativo está aberto; feche-o e tente de novo — erro $code") }
        "0x80073CFA" { return (New-WinForgeResult -Kind Failed -Detail "o Windows não permitiu a remoção — erro $code") }
        "0x80070005" { return (New-WinForgeResult -Kind Failed -Detail "acesso negado — erro $code") }
    }

    if ($code) {
        return (New-WinForgeResult -Kind Failed -Detail "a remoção falhou — erro $code")
    }

    $text = @(([string]$Message) -split "[\r\n]+" | Where-Object { $_.Trim() }) | Select-Object -First 1
    $text = $(if ($text) { ([string]$text).Trim().TrimEnd('.') } else { "a remoção falhou" })

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
            if ($result.Kind -ne "Failed") { $result = New-WinForgeResult -Kind Failed -Detail "não foi possível conferir se saiu" }
        }
        elseif (@($left | Where-Object { $names -contains $_ }).Count -gt 0) {
            if ($result.Kind -ne "Failed") { $result = New-WinForgeResult -Kind Failed -Detail "continua instalado" }
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
    $title = "Remover aplicativos do Windows"

    Enter-WinForgeAction -Title $title

    $final = New-WinForgeResult -Kind Ok -Title $title

    try {
        # Elevado com outra conta, os aplicativos removidos seriam os dessa conta, não os da pessoa logada.
        if (Test-WinForgeUserContextMismatch) {
            $interactiveUser = Get-WinForgeInteractiveUser
            Write-WinForgeStatus -Type Warning -Message "O WinForge está elevado com outra conta, não a de $interactiveUser. Abra-o sem trocar de conta."
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Skipped -Detail "o WinForge está elevado com outra conta" -Title $title)
            return
        }

        Write-Progress -Activity "Remover aplicativos do Windows" -Status "procurando os aplicativos da lista neste PC"

        try {
            $apps = @(Get-WinForgeInstalledAppCatalog)
        }
        finally {
            Write-Progress -Activity "Remover aplicativos do Windows" -Completed
        }

        if ($apps.Count -eq 0) {
            Write-WinForgeStatus -Type Success -Message "Nenhum dos aplicativos da lista está instalado."
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Skipped -Detail "nenhum aplicativo da lista está instalado" -Title $title)
            return
        }

        # Nada vem marcado. A remoção vale para o usuário atual, e o aplicativo volta pela Microsoft Store, menos os que a
        # Microsoft aposentou (a descrição deles diz isso, e a confirmação repete).
        $options = @($apps | ForEach-Object { @{ Key = $_.Key; Label = $_.Label; Description = $_.Description } })
        $picked = Read-WinForgeMultiSelect -Message "Quais aplicativos remover?" -Options $options -NoSelectAll -ConfirmLabel "Remover"

        if ($null -eq $picked -or @($picked).Count -eq 0) {
            Write-WinForgeStatus -Type Warning -Message "Operação cancelada."
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Skipped -Detail "cancelado pelo usuário" -Title $title)
            return
        }

        $chosen = @($apps | Where-Object { @($picked) -contains $_.Key })
        $question = Get-WinForgeSelectionQuestion -Verb "Remover" -Names @($chosen | ForEach-Object { [string]$_.Label }) -Many "aplicativos"
        $retired = @($chosen | Where-Object { -not $_.Reinstallable } | ForEach-Object { [string]$_.Label })

        # Os que a Microsoft aposentou não voltam pela Store: a confirmação repete o que a descrição deles já dizia.
        if ($retired.Count -gt 0) {
            Write-WinForgeStatus -Type Warning -Notice -Message "$(Join-WinForgeList -Items $retired) $(if ($retired.Count -eq 1) { 'não volta' } else { 'não voltam' }) pela Microsoft Store."
        }

        if (-not (Confirm-WinForgeAction -Message $question -DefaultKey "N")) {
            Write-WinForgeStatus -Type Warning -Message "Operação cancelada."
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Skipped -Detail "cancelado pelo usuário" -Title $title)
            return
        }

        $results = @()
        $position = 0

        try {
            foreach ($app in $chosen) {
                $position++
                Write-Progress -Activity "Removendo aplicativos" -Status "$position de $($chosen.Count): $($app.Label)" -PercentComplete ([int](($position - 1) * 100 / $chosen.Count))

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

                $result = $(if ($null -ne $failure) { $failure } elseif ($absent -eq @($app.FullNames).Count) { New-WinForgeResult -Kind Ok -Detail "já não estava instalado" } else { New-WinForgeResult -Kind Ok })
                $result.Etapa = $app.Label
                $results += $result
            }

            # A conferência: um aplicativo só conta como removido quando sai da lista de pacotes do Windows
            # (Get-WinForgeCheckedAppResults).
            Write-Progress -Activity "Removendo aplicativos" -Status "conferindo o que saiu"
            $results = @(Get-WinForgeCheckedAppResults -Apps $chosen -Results $results)
        }
        finally {
            Write-Progress -Activity "Removendo aplicativos" -Completed
        }

        foreach ($result in $results) {
            if ($result.Kind -eq "Ok") {
                Write-WinForgeStatus -Type Success -Message "$($result.Etapa): $(if ($result.Detail) { $result.Detail } else { 'removido' })."
            }
            else {
                Write-WinForgeStatus -Type Error -Message "$($result.Etapa): $($result.Detail)."
            }
        }

        # No console, a tabela junta tudo no fim; na janela, cada aplicativo já tem a sua linha no resumo.
        if ($results.Count -gt 1 -and -not (Test-WinForgeGuiMode)) {
            Write-WinForgeSection -Title "Resumo"
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
            if ($back.Count -gt 0) { $parts += "$(Format-WinForgeCount -Count $back.Count -One 'aplicativo removido' -Many 'aplicativos removidos'): $(Join-WinForgeList -Items $back) ($(if ($back.Count -eq 1) { 'volta' } else { 'voltam' }) pela Microsoft Store)" }
            if ($gone.Count -gt 0) { $parts += "$(Format-WinForgeCount -Count $gone.Count -One 'aplicativo removido' -Many 'aplicativos removidos'): $(Join-WinForgeList -Items $gone) ($(if ($gone.Count -eq 1) { 'aposentado pela Microsoft, não volta' } else { 'aposentados pela Microsoft, não voltam' }))" }
            [void](Add-WinForgeChange -Action "Aplicativos do Windows" -Text ($parts -join "; "))
            # A marca de "já instalado" das telas de instalar é lida de novo (Software.psm1, quando carregado).
            if (Get-Command -Name Clear-WinForgeInstalledWingetIdsCache -ErrorAction SilentlyContinue) { Clear-WinForgeInstalledWingetIdsCache }
        }

        if ($failed.Count -eq 0) {
            $detail = $(if ($results.Count -eq 1) { "1 aplicativo removido: $($results[0].Etapa)" } else { "$($results.Count) aplicativos removidos" })
            $final = New-WinForgeResult -Kind Ok -Detail $detail -Title $title

            # Na janela, o título diz quantos; a frase, quais e se voltam pela Microsoft Store.
            $storeNote = $(
                if ($gone.Count -eq 0) { "$(if ($back.Count -eq 1) { 'Volta' } else { 'Voltam' }) pela Microsoft Store, se precisar." }
                elseif ($back.Count -eq 0) { "$(if ($gone.Count -eq 1) { 'Não volta pela Microsoft Store: a Microsoft aposentou esse aplicativo' } else { 'Não voltam pela Microsoft Store: a Microsoft aposentou esses aplicativos' })." }
                else { "Só $(Join-WinForgeShortList -Items $back) $(if ($back.Count -eq 1) { 'volta' } else { 'voltam' }) pela Microsoft Store." }
            )
            [void](Set-WinForgeResultView -Result $final -Headline (Format-WinForgeCount -Count $removed.Count -One "aplicativo removido" -Many "aplicativos removidos") `
                    -Note "$(Join-WinForgeShortList -Items $removed). $storeNote")
        }
        elseif ($failed.Count -eq $results.Count) {
            $detail = $(if ($results.Count -eq 1) { "não foi possível remover $($names): $($failed[0].Detail)" } else { "nenhum aplicativo foi removido: $names" })
            $final = New-WinForgeResult -Kind Failed -Detail $detail -Title $title
        }
        else {
            $verbText = $(if ($failed.Count -eq 1) { "não foi removido" } else { "não foram removidos" })
            $final = New-WinForgeResult -Kind Warning -Detail "$($failed.Count) de $($results.Count) ${verbText}: $names" -Title $title
            $reason = $(if ($failed.Count -eq 1) { "o motivo está no resumo" } else { "o motivo de cada um está no resumo" })
            [void](Set-WinForgeResultView -Result $final -Headline "$($removed.Count) de $($results.Count) aplicativos removidos" `
                    -Note "$(Join-WinForgeShortList -Items @($failed | ForEach-Object { [string]$_.Etapa })) ${verbText}; $reason.")
        }
    }
    catch {
        Write-WinForgeStatus -Type Error -Message "Não foi possível remover os aplicativos: $($_.Exception.Message)"
        $final = New-WinForgeResult -Kind Failed -Detail $_.Exception.Message -Title $title
    }

    Exit-WinForgeAction -Result $final
}


Export-ModuleMember -Function *
