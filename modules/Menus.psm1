# Menus do console, montados a partir da tabela de Navigation.psm1.
# A janela gráfica não usa este módulo: ela desenha a barra lateral e os cartões com a mesma tabela.


function Read-WinForgeMenuKey {
    # Lê a opção de um menu. Devolve $null quando a entrada acaba (por exemplo, entrada redirecionada encerrada),
    # para que o menu saia em vez de repetir a pergunta para sempre.
    # -Hint: a linha de ajuda logo acima do pedido ("Digite o número e tecle Enter. 0 volta.").
    param (
        [Parameter(Mandatory)]
        [object[]]$Options,

        [switch]$ShowMenu,

        [string]$Hint = "Digite o número e tecle Enter. 0 volta."
    )

    try {
        return (Read-WinForgeChoice -Message $Hint -Options $Options -ShowMenu:$ShowMenu)
    }
    catch {
        return $null
    }
}


function Invoke-WinForgeNavItem {
    # Executa um item da navegação no console. Erros inesperados viram uma mensagem; o menu continua.
    param (
        [Parameter(Mandatory)]
        $Item
    )

    try {
        if ($Item.Kind -eq "Shortcut") {
            Show-WinForgeHeader $Item.Label
            [void](Open-WinForgeShortcut -Name $Item.Shortcut)
            Wait-WinForgeKey
        }
        else {
            # O desfecho que o fim da ação mostra é só o desta ação (Exit-WinForgeAction).
            Reset-WinForgeOutcome
            & $Item.Command
        }
    }
    catch {
        Write-Host ""
        Write-WinForgeStatus -Type Error -Message "Ocorreu um erro em '$($Item.Label)': $($_.Exception.Message)"
        Wait-WinForgeKey
    }
}


function Show-WinForgePageMenu {
    param (
        [Parameter(Mandatory)]
        $Page
    )

    while ($true) {
        Show-WinForgeHeader $Page.Title
        Write-WinForgeWrappedLine -Text $Page.Summary -Color DarkGray
        Write-Host ""

        $options = @()
        $position = 0
        $group = $null

        # As seções da página ("Liberar espaço", "Ferramentas do Windows") separam os itens, como na janela; a numeração
        # segue direto de uma seção para a outra.
        foreach ($item in $Page.Items) {
            $position++

            if ([string]$item.Group -and [string]$item.Group -ne $group) {
                if ($null -ne $group) { Write-Host "" }
                Write-Host "  $($item.Group)" -ForegroundColor DarkCyan
                $group = [string]$item.Group
            }

            Write-WinForgeMenuItem -Key ([string]$position) -Label $item.Label -Description $item.Description -Accent:$item.Accent -Recommended:$item.Accent
            $options += @{ Key = [string]$position; Label = $item.Label; Description = $item.Description; Accent = $item.Accent }
        }

        Write-Host ""
        Write-WinForgeMenuItem -Key "0" -Label "Voltar" -Exit
        Write-Host ""

        $options += @{ Key = "0"; Label = "Voltar"; Exit = $true }

        $choice = Read-WinForgeMenuKey -Options $options

        if ($null -eq $choice -or $choice -eq "0") {
            return
        }

        Invoke-WinForgeNavItem -Item $Page.Items[[int]$choice - 1]
    }
}


function Get-WinForgeTweaksMenuLetters {
    # A tecla de cada ação de uma página de ajustes (Ajustes do Windows ou Personalização), na ordem da tabela de navegação.
    param ([string]$PageId = "tweaks")

    $keys = @{
        "tweaks.recommended" = "A"; "tweaks.profiles" = "P"; "tweaks.keyboard-language" = "T"; "tweaks.notifications" = "N"
        "tweaks.restore-point" = "R"; "tweaks.export" = "E"; "tweaks.import" = "I"; "tweaks.revert-all" = "D"
        "personalize.accent-color" = "C"; "personalize.lock-screen" = "B"; "personalize.settings" = "P"
    }

    $page = Get-WinForgeNavPage -Id $PageId
    $letters = [ordered]@{}

    foreach ($item in @($page.Items)) {
        if ($keys.ContainsKey([string]$item.Id)) { $letters[[string]$item.Id] = $keys[[string]$item.Id] }
    }

    return $letters
}


function Show-WinForgeTweaksMenu {
    # Os ajustes são numerados; as ações da página (nomes vindos da tabela de navegação) têm uma letra como tecla.
    # Cada item mostra o recurso do Windows como a chave da janela: ativado ou desativado, lido do Windows agora.
    param ([string]$PageId = "tweaks")

    $page = Get-WinForgeNavPage -Id $PageId
    $letters = Get-WinForgeTweaksMenuLetters -PageId $PageId

    while ($true) {
        Show-WinForgeHeader $page.Title
        Write-WinForgeWrappedLine -Text $page.Summary -Color DarkGray
        Write-WinForgeWrappedLine -Text "Cada item mostra como o Windows está agora: ativado ou desativado (? = não identificado)." -Color DarkGray

        $overview = @(Get-WinForgeTweakOverview -Page $PageId)
        $options = @()
        $lastCategory = ""
        $position = 0

        foreach ($tweak in $overview) {
            if ($tweak.Category -ne $lastCategory) {
                Write-WinForgeSection -Title $tweak.Category
                $lastCategory = $tweak.Category
            }

            $position++
            $options += @{ Key = [string]$position; Label = $tweak.Name }

            $state = Get-WinForgeTweakSwitchState -Status $tweak.Status -Inverted ([bool]$tweak.Inverted)

            if ($tweak.Status -eq "Desconhecido") {
                $badge = "[    ?     ]"
                $badgeColor = "Yellow"
            }
            elseif ($state.IsOn) {
                $badge = "[ativado   ]"
                $badgeColor = "White"
            }
            else {
                $badge = "[desativado]"
                $badgeColor = "DarkGray"
            }

            Write-Host "  [" -ForegroundColor DarkGray -NoNewline
            Write-Host ([string]$position).PadLeft(2) -ForegroundColor Cyan -NoNewline
            Write-Host "] " -ForegroundColor DarkGray -NoNewline
            Write-Host "$badge " -ForegroundColor $badgeColor -NoNewline
            Write-Host $tweak.Name -ForegroundColor Gray -NoNewline

            if (-not [string]::IsNullOrWhiteSpace($tweak.LaptopNote)) {
                Write-Host "  (aviso para notebook ao escolher)" -ForegroundColor Yellow -NoNewline
            }

            Write-Host ""
        }

        Write-Host ""
        foreach ($id in $letters.Keys) {
            $item = $page.Items | Where-Object { $_.Id -eq $id } | Select-Object -First 1
            Write-WinForgeMenuItem -Key $letters[$id] -Label $item.Label -Description $item.Description -Accent:$item.Accent
            $options += @{ Key = $letters[$id]; Label = $item.Label }
        }

        Write-Host ""
        Write-WinForgeMenuItem -Key "0" -Label "Voltar" -Exit
        Write-Host ""

        $options += @{ Key = "0"; Label = "Voltar"; Exit = $true }

        $choice = Read-WinForgeMenuKey -Options $options -Hint "Digite o número de um item para ativar ou desativar, ou a letra de uma ação, e tecle Enter. 0 volta."

        if ($null -eq $choice -or $choice -eq "0") {
            return
        }

        try {
            $letterId = @($letters.Keys | Where-Object { $letters[$_] -eq $choice.ToUpperInvariant() }) | Select-Object -First 1

            if ($null -ne $letterId) {
                Invoke-WinForgeNavItem -Item ($page.Items | Where-Object { $_.Id -eq $letterId } | Select-Object -First 1)
            }
            else {
                Reset-WinForgeOutcome
                Invoke-WinForgeTweakToggle -Tweak (Get-WinForgeTweakById -Id $overview[[int]$choice - 1].Id)
            }
        }
        catch {
            Write-Host ""
            Write-WinForgeStatus -Type Error -Message "Ocorreu um erro: $($_.Exception.Message)"
            Wait-WinForgeKey
        }
    }
}


function Show-WinForgeMainMenu {
    while ($true) {
        Show-WinForgeHeader "WinForge"

        $pages = @(Get-WinForgeNavigation)
        $options = @()
        $position = 0
        $footer = $false

        foreach ($page in $pages) {
            $position++

            # A página do rodapé da barra lateral (Sobre o WinForge) fica separada das outras, como na janela.
            if ([string]$page.Placement -eq "Footer" -and -not $footer) {
                Write-Host ""
                $footer = $true
            }

            Write-WinForgeMenuItem -Key ([string]$position) -Label $page.Title -Description $page.Summary -Accent:($position -eq 1) -Recommended:($position -eq 1)
            $options += @{ Key = [string]$position; Label = $page.Title; Description = $page.Summary; Accent = ($position -eq 1) }
        }

        Write-Host ""
        Write-WinForgeMenuItem -Key "0" -Label "Sair" -Exit
        Write-Host ""

        $options += @{ Key = "0"; Label = "Sair"; Exit = $true }

        $choice = Read-WinForgeMenuKey -Options $options -Hint "Digite o número e tecle Enter. 0 sai do WinForge."

        if ($null -eq $choice -or $choice -eq "0") {
            Write-Host ""
            Write-Host "  Saindo do WinForge..." -ForegroundColor Yellow
            return
        }

        $page = $pages[[int]$choice - 1]

        if ($page.Kind -eq "Tweaks") {
            Show-WinForgeTweaksMenu -PageId $page.Id
        }
        else {
            Show-WinForgePageMenu -Page $page
        }
    }
}


Export-ModuleMember -Function *
