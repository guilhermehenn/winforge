# Menus do console, montados a partir da tabela de Navigation.psm1.
# A janela gráfica não usa este módulo: ela desenha a barra lateral e os cartões com a mesma tabela.


function Read-WinForgeMenuKey {
    # Lê a opção de um menu. Devolve $null quando a entrada acaba (por exemplo, entrada redirecionada encerrada),
    # para que o menu saia em vez de repetir a pergunta para sempre.
    param (
        [Parameter(Mandatory)]
        [object[]]$Options,

        [switch]$ShowMenu
    )

    try {
        return (Read-WinForgeChoice -Message "Selecione uma opção" -Options $Options -ShowMenu:$ShowMenu)
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
        Write-Host "  $($Page.Summary)" -ForegroundColor DarkGray
        Write-Host ""

        $options = @()
        $position = 0

        foreach ($item in $Page.Items) {
            $position++
            $options += @{ Key = [string]$position; Label = $item.Label; Description = $item.Description; Accent = $item.Accent }
        }

        $options += @{ Key = "0"; Label = "Voltar"; Exit = $true }

        $choice = Read-WinForgeMenuKey -Options $options -ShowMenu

        if ($null -eq $choice -or $choice -eq "0") {
            return
        }

        Invoke-WinForgeNavItem -Item $Page.Items[[int]$choice - 1]
    }
}


function Show-WinForgeTweaksMenu {
    # Os ajustes são numerados; as ações da página (nomes vindos da tabela de navegação) têm teclas de letra.
    $page = Get-WinForgeNavPage -Id "tweaks"
    $letters = [ordered]@{ "tweaks.recommended" = "R"; "tweaks.restore-point" = "P"; "tweaks.revert-all" = "D" }

    while ($true) {
        Show-WinForgeHeader $page.Title

        $overview = @(Get-WinForgeTweakOverview)
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

            $badge = switch ($tweak.Status) {
                "Aplicado"     { "[ATIVO ]" }
                "Desconhecido" { "[  ?   ]" }
                default        { "[padrão]" }
            }

            $badgeColor = if ($tweak.Status -eq "Aplicado") { "Green" } else { "DarkGray" }

            Write-Host "  [" -ForegroundColor DarkGray -NoNewline
            Write-Host ([string]$position).PadLeft(2) -ForegroundColor Cyan -NoNewline
            Write-Host "] " -ForegroundColor DarkGray -NoNewline
            Write-Host "$badge " -ForegroundColor $badgeColor -NoNewline
            Write-Host $tweak.Name -ForegroundColor Gray -NoNewline

            if (-not [string]::IsNullOrWhiteSpace($tweak.LaptopNote)) {
                Write-Host "  (atenção: notebook)" -ForegroundColor Yellow -NoNewline
            }

            Write-Host ""
        }

        Write-Host ""
        foreach ($id in $letters.Keys) {
            $item = $page.Items | Where-Object { $_.Id -eq $id } | Select-Object -First 1
            Write-WinForgeMenuItem -Key $letters[$id] -Label $item.Label -Description $item.Description
            $options += @{ Key = $letters[$id]; Label = $item.Label }
        }

        Write-WinForgeMenuItem -Key "0" -Label "Voltar" -Exit
        Write-Host ""
        Write-Host "  Digite o número de um ajuste para aplicá-lo ou desfazê-lo." -ForegroundColor DarkGray
        Write-Host ""

        $options += @{ Key = "0"; Label = "Voltar" }

        $choice = Read-WinForgeMenuKey -Options $options

        if ($null -eq $choice -or $choice -eq "0") {
            return
        }

        try {
            $letterId = @($letters.Keys | Where-Object { $letters[$_] -eq $choice.ToUpperInvariant() }) | Select-Object -First 1

            if ($null -ne $letterId) {
                Invoke-WinForgeNavItem -Item ($page.Items | Where-Object { $_.Id -eq $letterId } | Select-Object -First 1)
            }
            else {
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

        foreach ($page in $pages) {
            $position++
            $options += @{ Key = [string]$position; Label = $page.Title; Description = $page.Summary; Accent = ($position -eq 1) }
        }

        $options += @{ Key = "0"; Label = "Sair"; Exit = $true }

        $choice = Read-WinForgeMenuKey -Options $options -ShowMenu

        if ($null -eq $choice -or $choice -eq "0") {
            Write-Host ""
            Write-Host "  Saindo do WinForge..." -ForegroundColor Yellow
            return
        }

        $page = $pages[[int]$choice - 1]

        if ($page.Kind -eq "Tweaks") {
            Show-WinForgeTweaksMenu
        }
        else {
            Show-WinForgePageMenu -Page $page
        }
    }
}


Export-ModuleMember -Function *
