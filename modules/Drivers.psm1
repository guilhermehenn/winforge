# Drivers: procurar e instalar pelo Windows Update, aqui mesmo, e indicar a ferramenta oficial do fabricante.
#
# O Windows Update é a fonte mais segura de drivers: os fabricantes publicam ali os drivers testados para o Windows. Os
# recomendados vêm marcados; os opcionais (que o Windows só mostra na página de atualizações opcionais) vêm desmarcados,
# porque só valem a pena quando algum dispositivo está com problema. Placa de vídeo e BIOS costumam ter versões mais
# novas nas ferramentas dos próprios fabricantes; a segunda tela indica qual usar, pelo fabricante do PC e da placa.


function Get-WinForgeDriverSearchCriteria {
    return "IsInstalled=0 and IsHidden=0 and Type='Driver'"
}


function Get-WinForgeDriverRunDetail {
    # "3 drivers instalados", "2 drivers instalados (1 com erros)", "2 de 3 instalados; 1 falhou", "nenhum dos 2 drivers
    # foi instalado". Ok = instalados sem problema, Warned = instalados com erros (código 3 do Windows Update), Failed = não
    # instalados.
    param (
        [int]$Ok,
        [int]$Failed,
        [int]$Warned = 0
    )

    $installed = $Ok + $Warned
    $total = $installed + $Failed

    if ($installed -eq 0) {
        if ($total -eq 1) { return (Get-WinForgeText 'o driver não foi instalado') }
        return (Get-WinForgeText 'nenhum dos {0} drivers foi instalado' "$total")
    }

    if ($Failed -eq 0) {
        $text = Format-WinForgeCount -Count $installed -One (Get-WinForgeText 'driver instalado') -Many (Get-WinForgeText 'drivers instalados')
    }
    else {
        $text = $(if ($installed -eq 1) { (Get-WinForgeText '1 de {0} instalado' "$total") } else { (Get-WinForgeText '{0} de {1} instalados' "$installed" "$total") })
    }

    if ($Warned -gt 0) { $text += (Get-WinForgeText ' ({0} com erros)' "$Warned") }
    if ($Failed -gt 0) { $text += "; $(if ($Failed -eq 1) { (Get-WinForgeText '1 falhou') } else { (Get-WinForgeText '{0} falharam' "$Failed") })" }

    return $text
}


function Install-WinForgeDriverUpdates {
    $title = (Get-WinForgeText 'Atualizar drivers')

    Enter-WinForgeAction -Title $title

    $final = New-WinForgeResult -Kind Ok -Title $title

    try {
        if (-not (Test-WinForgeElevation -Reason (Get-WinForgeText 'Atualizar drivers exige privilégios de Administrador.'))) {
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Failed -Detail (Get-WinForgeText 'requer Administrador') -Title $title)
            return
        }

        # As mesmas conferências de Instalar atualizações do Windows: um driver também vem do Windows Update (e a pausa vale
        # para eles), e um de firmware (BIOS) interrompido por falta de bateria pode deixar o PC sem ligar.
        $stop = Confirm-WinForgeUpdateConditions -Title $title -Reboot (Get-WinForgeText 'Reiniciar antes evita que os drivers novos falhem.') -Battery (Get-WinForgeText 'Instalar drivers, principalmente de firmware (BIOS), não deve ser interrompido.') -Retry (Get-WinForgeText 'Atualizações > Atualizar drivers')

        if ($null -ne $stop) {
            Exit-WinForgeAction -Result $stop
            return
        }

        Write-Progress -Activity (Get-WinForgeText 'Procurando drivers') -Status (Get-WinForgeText 'o Windows Update pode levar alguns minutos para responder')

        try {
            $search = Find-WinForgeWindowsUpdates -Criteria (Get-WinForgeDriverSearchCriteria)
        }
        finally {
            Write-Progress -Activity (Get-WinForgeText 'Procurando drivers') -Completed
        }

        if ($null -eq $search.Updates) {
            Write-WinForgeStatus -Type Error -Message (Get-WinForgeText 'Não foi possível consultar o Windows Update: {0}.' "$($search.Problem)")
            Write-WinForgeWindowsUpdateSearchHelp -Problem $search.Problem
            Exit-WinForgeAction -Result (Set-WinForgeUpdateSearchView -Result (New-WinForgeResult -Kind Failed -Detail (Get-WinForgeText 'não foi possível consultar o Windows Update: {0}' "$($search.Problem)") -Title $title) -Problem $search.Problem)
            return
        }

        $drivers = @($search.Updates)

        if ($drivers.Count -eq 0) {
            Write-WinForgeStatus -Type Success -Message (Get-WinForgeText 'O Windows Update não tem drivers novos para este PC.')
            Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Placa de vídeo e BIOS podem ter versões mais novas no programa do fabricante: veja Atualizações > Ferramentas do fabricante.')
            Exit-WinForgeAction -Result (Set-WinForgeResultView -Result (New-WinForgeResult -Kind Ok -Detail (Get-WinForgeText 'nenhum driver novo') -Title $title) -Headline (Get-WinForgeText 'Nenhum driver novo') `
                    -Note (Get-WinForgeText 'Placa de vídeo e BIOS podem ter versões mais novas no programa do fabricante.') -Next "updates.vendor-tools" -NextLabel (Get-WinForgeText 'Ver as ferramentas do fabricante'))
            return
        }

        $recommended = @($drivers | Where-Object { -not $_.BrowseOnly })
        $optional = @($drivers | Where-Object { $_.BrowseOnly })

        Write-WinForgeKeyValue -Label (Get-WinForgeText 'Recomendados') -Value $recommended.Count
        Write-WinForgeKeyValue -Label (Get-WinForgeText 'Opcionais') -Value $optional.Count
        Write-Host ""

        if ($optional.Count -gt 0) {
            Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Os opcionais vêm desmarcados: instale um deles só se o dispositivo estiver com problema.')
        }

        Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Se um driver novo der problema, volte ao anterior em Diagnóstico > Gerenciador de Dispositivos (no aparelho: Propriedades, Driver, Reverter driver).')
        Write-Host ""

        # O título do Windows Update ("Intel - System - 10.1.1.44") se repete para aparelhos diferentes: a descrição diz
        # para que serve cada um ("vídeo: Intel(R) UHD Graphics 620").
        $options = @(
            foreach ($driver in @($recommended + $optional)) {
                $parts = @($(if ($driver.BrowseOnly) { (Get-WinForgeText 'opcional') } else { (Get-WinForgeText 'recomendado') }))
                $purpose = Get-WinForgeDriverPurposeText -Update $driver
                if ($purpose) { $parts += $purpose }
                $parts += Get-WinForgeUpdateSizeText -Update $driver
                @{ Key = $driver.Id; Label = [string]$driver.Title; Description = ($parts -join " · "); Selected = (-not $driver.BrowseOnly) }
            }
        )

        $picked = Read-WinForgeMultiSelect -Message (Get-WinForgeText 'Quais drivers instalar?') -Options $options

        if ($null -eq $picked -or @($picked).Count -eq 0) {
            Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'Operação cancelada.')
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Skipped -Detail (Get-WinForgeText 'cancelado pelo usuário') -Title $title)
            return
        }

        $chosen = @($drivers | Where-Object { @($picked) -contains $_.Id })
        $question = Get-WinForgeSelectionQuestion -Verb (Get-WinForgeText 'Instalar') -Names @($chosen | ForEach-Object { [string]$_.Title }) -Many (Get-WinForgeText 'drivers') -Limit 1

        Write-WinForgeFirmwareWarning -Updates $chosen

        $pendingBytes = [int64]0
        foreach ($driver in @($chosen | Where-Object { -not $_.Downloaded })) { $pendingBytes += [int64]$driver.Size }
        if (@($chosen | Where-Object { -not $_.Downloaded }).Count -gt 0) { Write-WinForgeMeteredWarning -Bytes $pendingBytes }

        # Com um firmware (BIOS) na escolha, o padrão é Não: um Enter a mais não manda gravar a BIOS.
        $hasFirmware = (@($chosen | Where-Object { Test-WinForgeFirmwareUpdate -Update $_ }).Count -gt 0)

        if (-not (Confirm-WinForgeAction -Message $question -DefaultKey $(if ($hasFirmware) { "N" } else { "S" }) -YesLabel (Get-WinForgeText 'Instalar') -NoLabel (Get-WinForgeText 'Cancelar'))) {
            Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'Operação cancelada.')
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Skipped -Detail (Get-WinForgeText 'cancelado pelo usuário') -Title $title)
            return
        }

        # Um ponto de restauração antes, quando o Windows deixa (ele limita a um por dia): é a volta mais simples se um
        # driver deixar o PC instável.
        Write-Progress -Activity $title -Status (Get-WinForgeText 'criando um ponto de restauração')

        # Um erro inesperado ao criar o ponto (o serviço de cópias de sombra, por exemplo) não impede os drivers: a tela diz
        # que segue sem ponto novo, como quando o Windows não o cria.
        try {
            $point = New-WinForgeRestorePoint -Description (Get-WinForgeText 'WinForge - antes dos drivers')
        }
        catch {
            $point = $null
        }
        finally {
            Write-Progress -Activity $title -Completed
        }

        if ($null -eq $point -or [string]$point.Kind -notin @("Ok", "Skipped")) { Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Seguindo sem ponto de restauração novo.') }

        $keepAwake = Set-WinForgeKeepAwake -Enabled $true

        try {
            $run = Invoke-WinForgeUpdateInstall -Ids @($chosen | ForEach-Object { $_.Id }) -Criteria (Get-WinForgeDriverSearchCriteria)
        }
        finally {
            if ($keepAwake) { [void](Set-WinForgeKeepAwake -Enabled $false) }
        }

        Write-Host ""

        # O mesmo desfecho das atualizações (Get-WinForgeUpdateRunResult): a tabela, o Histórico de mudanças e a faixa.
        $final = Get-WinForgeUpdateRunResult -Run $run -Chosen $chosen -Title $title -Drivers
        [void](Set-WinForgeInstallView -Result $final -One (Get-WinForgeText 'driver instalado') -Many (Get-WinForgeText 'drivers instalados') -Each (Get-WinForgeText 'cada um') -Partial (Get-WinForgeText '{0} de {1} drivers instalados') `
                -None $(if ($chosen.Count -eq 1) { (Get-WinForgeText 'O driver não foi instalado') } else { (Get-WinForgeText 'Nenhum driver instalado') }) `
                -OkNote (Get-WinForgeText 'Se algum der problema, volte ao driver anterior no Gerenciador de Dispositivos.'))

        [void](Set-WinForgeInstallErrorView -Result $final)

        if (Test-WinForgeResultFlag -Result $final -Name "RebootRequired") {
            Request-WinForgeInstallRestart -What (Get-WinForgeText 'os drivers') -Later (Get-WinForgeText 'Os drivers terminam de instalar quando você reiniciar o PC.')
        }
    }
    catch {
        # A mesma tradução dos erros do Windows Update (sem o embrulho do PowerShell, com o código).
        $problem = Get-WinForgeWindowsUpdateProblem -Message $_.Exception.Message -HResult $_.Exception.HResult
        Write-WinForgeStatus -Type Error -Message (Get-WinForgeText 'Não foi possível atualizar os drivers: {0}.' "$problem")
        $final = New-WinForgeResult -Kind Failed -Detail $problem -Title $title
    }

    Exit-WinForgeAction -Result $final
}


# ---------------------------------------------------------------------------
# Ferramentas dos fabricantes
# ---------------------------------------------------------------------------

function Get-WinForgeVendorToolCatalog {
    <#
    As ferramentas oficiais. WingetId = instalável pelo winget; Url = página oficial (abre no navegador) ou, com
    Store, a página do aplicativo na Microsoft Store; Open = o rótulo do botão quando não há winget; Target = o que abre,
    para a frase "Abrindo {0} no navegador". Cada fabricante tem uma ferramenta para a linha de PCs de empresa e outra
    para a de uso pessoal: a da linha errada diz que o PC não é compatível. A página da HP escolhe o país e o idioma
    sozinha; a do NVIDIA App vai no idioma da tela.
    #>
    $nvidia = switch (Get-WinForgeLanguage) { "pt" { "pt-br" } "es" { "es-la" } default { "en-us" } }

    return @(
        [PSCustomObject]@{ Id = "dell"; Name = "Dell Command | Update"; For = (Get-WinForgeText 'PCs Dell Pro, Latitude, OptiPlex, Precision, Vostro e XPS'); WingetId = "Dell.CommandUpdate"; Url = ""; Open = ""; Target = ""; Store = $false },
        [PSCustomObject]@{ Id = "dell-supportassist"; Name = (Get-WinForgeText 'Dell SupportAssist'); For = (Get-WinForgeText 'PCs Dell Inspiron, Alienware e G'); WingetId = ""; Url = "https://www.dell.com/support/kbdoc/000130387"; Open = (Get-WinForgeText 'Abrir a página do Dell SupportAssist'); Target = (Get-WinForgeText 'a página do Dell SupportAssist'); Store = $false },
        [PSCustomObject]@{ Id = "lenovo"; Name = "Lenovo System Update"; For = (Get-WinForgeText 'PCs Lenovo ThinkPad, ThinkCentre e ThinkStation'); WingetId = "Lenovo.SystemUpdate"; Url = ""; Open = ""; Target = ""; Store = $false },
        [PSCustomObject]@{ Id = "lenovo-vantage"; Name = "Lenovo Vantage"; For = (Get-WinForgeText 'PCs Lenovo IdeaPad, Yoga, Legion, ThinkBook e outros'); WingetId = ""; Url = "ms-windows-store://pdp/?ProductId=9WZDNCRFJ4MV"; Open = (Get-WinForgeText 'Abrir o Lenovo Vantage na Microsoft Store'); Target = ""; Store = $true },
        [PSCustomObject]@{ Id = "hp"; Name = (Get-WinForgeText 'Site de drivers da HP'); For = (Get-WinForgeText 'PCs HP'); WingetId = ""; Url = "https://support.hp.com/drivers"; Open = (Get-WinForgeText 'Abrir o site de drivers da HP'); Target = (Get-WinForgeText 'o site de drivers da HP'); Store = $false },
        [PSCustomObject]@{ Id = "intel"; Name = "Intel Driver & Support Assistant"; For = (Get-WinForgeText 'processador e vídeo Intel'); WingetId = "Intel.IntelDriverAndSupportAssistant"; Url = ""; Open = ""; Target = ""; Store = $false },
        [PSCustomObject]@{ Id = "nvidia"; Name = (Get-WinForgeText 'NVIDIA App'); For = (Get-WinForgeText 'placas de vídeo NVIDIA'); WingetId = ""; Url = "https://www.nvidia.com/$nvidia/software/nvidia-app/"; Open = (Get-WinForgeText 'Abrir a página do NVIDIA App'); Target = (Get-WinForgeText 'a página do NVIDIA App'); Store = $false },
        [PSCustomObject]@{ Id = "amd"; Name = (Get-WinForgeText 'AMD Adrenalin (detecção automática)'); For = (Get-WinForgeText 'processador e vídeo AMD'); WingetId = ""; Url = "https://www.amd.com/en/support/download/drivers.html"; Open = (Get-WinForgeText 'Abrir a página de drivers da AMD'); Target = (Get-WinForgeText 'a página de drivers da AMD'); Store = $false }
    )
}


function Test-WinForgeVendorText {
    # Se um texto de fabricante ou modelo diz alguma coisa: placas genéricas vêm com "To Be Filled By O.E.M." e afins.
    param ([string]$Text)

    $value = ([string]$Text).Trim()

    return ($value -and $value -notmatch '(?i)to be filled|default string|system product name|system manufacturer|not applicable|all series|^(none|x|0+|oem|notebook|laptop|desktop|pc)$')
}


function Get-WinForgeHardwareVendors {
    <#
    Fabricante, modelo e família do PC (a Lenovo põe o tipo de máquina, "21AH", no modelo, e o nome, "ThinkPad T14 Gen 3",
    na família), nomes das placas de vídeo e fabricante do processador. Campos vazios quando não lidos. SystemRead e
    GpuRead dizem se o Windows respondeu: "não consegui ler" não é o mesmo que "fabricante desconhecido".
    #>
    $system = $null
    $cpu = $null
    $gpus = @()
    $systemRead = $true
    $gpuRead = $true

    try { $system = Get-CimInstance -ClassName Win32_ComputerSystem -OperationTimeoutSec 15 -ErrorAction Stop } catch { $system = $null; $systemRead = $false }
    try { $cpu = @(Get-CimInstance -ClassName Win32_Processor -OperationTimeoutSec 15 -ErrorAction Stop) | Select-Object -First 1 } catch { $cpu = $null }
    try { $gpus = @(Get-CimInstance -ClassName Win32_VideoController -OperationTimeoutSec 15 -ErrorAction Stop | ForEach-Object { [string]$_.Name } | Where-Object { $_ }) } catch { $gpus = @(); $gpuRead = $false }

    return [PSCustomObject]@{
        Manufacturer = ([string](Get-WinForgeJsonValue -Object $system -Name "Manufacturer" -Default "")).Trim()
        Model        = ([string](Get-WinForgeJsonValue -Object $system -Name "Model" -Default "")).Trim()
        Family       = ([string](Get-WinForgeJsonValue -Object $system -Name "SystemFamily" -Default "")).Trim()
        Gpus         = @($gpus)
        CpuVendor    = ([string](Get-WinForgeJsonValue -Object $cpu -Name "Manufacturer" -Default "")).Trim()
        SystemRead   = $systemRead
        GpuRead      = $gpuRead
    }
}


function Get-WinForgeHardwareModelText {
    <#
    O modelo como a pessoa o conhece. Só a Lenovo põe no modelo um código de tipo de máquina ("21AH0026US"), com o nome
    na família: aí sai "ThinkPad T14 Gen 3 (21AH0026US)". Os outros fabricantes usam a família para códigos internos
    ("103C_5336AN HP ProBook"), e o modelo basta. Vazio sem nada.
    #>
    param ([Parameter(Mandatory)]$Hardware)

    $maker = [string](Get-WinForgeJsonValue -Object $Hardware -Name "Manufacturer" -Default "")
    $model = [string](Get-WinForgeJsonValue -Object $Hardware -Name "Model" -Default "")
    $family = [string](Get-WinForgeJsonValue -Object $Hardware -Name "Family" -Default "")

    if (-not (Test-WinForgeVendorText -Text $model)) { $model = "" }
    if (-not (Test-WinForgeVendorText -Text $family)) { $family = "" }

    if ($maker -match '(?i)lenovo' -and $family -and $model -match '^[0-9A-Z]{4}([0-9A-Z]{4,6})?$' -and $model -match '[0-9]') {
        return "$family ($model)"
    }

    return $(if ($model) { $model } else { $family })
}


function Get-WinForgeVendorTools {
    # As ferramentas que servem a este PC, na ordem: a do fabricante do PC (a da linha certa), depois as das placas de
    # vídeo e do processador.
    param ([Parameter(Mandatory)]$Hardware)

    $catalog = Get-WinForgeVendorToolCatalog
    $ids = New-Object System.Collections.ArrayList
    $maker = [string]$Hardware.Manufacturer
    $line = "$([string](Get-WinForgeJsonValue -Object $Hardware -Name 'Model' -Default '')) $([string](Get-WinForgeJsonValue -Object $Hardware -Name 'Family' -Default ''))"

    if ($maker -match '(?i)\bdell\b|alienware') {
        # Dell Command | Update só atende a linha empresarial (Dell Pro e Pro Max, que sucedem Latitude e Precision, e o
        # XPS); Inspiron, Alienware e G usam o SupportAssist.
        [void]$ids.Add($(if ($line -match '(?i)latitude|optiplex|precision|vostro|rugged|\bxps\b|\bdell pro\b|^\s*pro( max)?\b') { "dell" } else { "dell-supportassist" }))
    }
    elseif ($maker -match '(?i)lenovo') {
        # O Lenovo System Update só atende ThinkPad, ThinkCentre e ThinkStation (não o ThinkBook); o Lenovo Vantage atende
        # as outras linhas.
        [void]$ids.Add($(if ($line -match '(?i)\bthink(pad|centre|station)\b') { "lenovo" } else { "lenovo-vantage" }))
    }
    elseif ($maker -match '(?i)\bhp\b|hewlett') { [void]$ids.Add("hp") }

    $gpuText = (@($Hardware.Gpus) -join " | ")

    if ($gpuText -match '(?i)nvidia|geforce|quadro|rtx') { [void]$ids.Add("nvidia") }
    if ($gpuText -match '(?i)\bamd\b|radeon') { [void]$ids.Add("amd") }
    if ($gpuText -match '(?i)intel' -or [string]$Hardware.CpuVendor -match '(?i)intel') { [void]$ids.Add("intel") }
    if ([string]$Hardware.CpuVendor -match '(?i)amd' -and -not $ids.Contains("amd")) { [void]$ids.Add("amd") }

    return @(foreach ($id in $ids) { $catalog | Where-Object { $_.Id -eq $id } })
}


function Show-WinForgeVendorTools {
    $title = (Get-WinForgeText 'Ferramentas do fabricante')

    Enter-WinForgeAction -Title $title

    $final = New-WinForgeResult -Kind Ok -Title $title

    try {
        Write-Progress -Activity $title -Status (Get-WinForgeText 'lendo o fabricante do PC e da placa de vídeo')

        try {
            $hardware = Get-WinForgeHardwareVendors
        }
        finally {
            Write-Progress -Activity $title -Completed
        }

        # O Windows que não respondeu (WMI parado ou danificado) não é o mesmo que um fabricante desconhecido: a tela diz que
        # não leu, e a indicação pode estar incompleta.
        $systemRead = [bool](Get-WinForgeJsonValue -Object $hardware -Name "SystemRead" -Default $true)
        $gpuRead = [bool](Get-WinForgeJsonValue -Object $hardware -Name "GpuRead" -Default $true)
        $unread = @()
        if (-not $systemRead) { $unread += (Get-WinForgeText 'o fabricante do PC') }
        if (-not $gpuRead) { $unread += (Get-WinForgeText 'a placa de vídeo') }
        $unreadText = $(if ($unread.Count -gt 0) { (Get-WinForgeText 'não foi possível ler {0}' "$(Join-WinForgeList -Items $unread)") } else { "" })

        # A faixa de quando o Windows não respondeu: a lista (ou a falta dela) pode não valer para este PC.
        $unreadView = {
            param ($Result)
            Set-WinForgeResultView -Result $Result -Headline (Get-WinForgeText 'A indicação pode estar incompleta') -Note "$($unreadText.Substring(0, 1).ToUpper())$($unreadText.Substring(1))."
        }

        $modelText = Get-WinForgeHardwareModelText -Hardware $hardware

        Write-WinForgeKeyValue -Label (Get-WinForgeText 'Fabricante do PC') -Value $(if (Test-WinForgeVendorText -Text $hardware.Manufacturer) { $hardware.Manufacturer } elseif (-not $systemRead) { (Get-WinForgeText 'não foi possível ler') } else { (Get-WinForgeText 'não informado') })
        if ($modelText) { Write-WinForgeKeyValue -Label (Get-WinForgeText 'Modelo') -Value $modelText }
        Write-WinForgeKeyValue -Label (Get-WinForgeText 'Placa de vídeo') -Value $(if (@($hardware.Gpus).Count -gt 0) { Join-WinForgeList -Items @($hardware.Gpus) } elseif (-not $gpuRead) { (Get-WinForgeText 'não foi possível ler') } else { (Get-WinForgeText 'não informada') })
        Write-Host ""

        if ($unreadText) {
            Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'O Windows não respondeu: {0}. A indicação abaixo pode estar incompleta.' "$unreadText")
        }

        $tools = @(Get-WinForgeVendorTools -Hardware $hardware)

        if ($tools.Count -eq 0) {
            $where = $(if ($modelText) { (Get-WinForgeText 'pelo modelo {0}' "$modelText") } else { (Get-WinForgeText 'pelo modelo do PC') })

            if ($unreadText) {
                Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Procure, no site do fabricante do PC, a página de suporte {0}.' "$where")
            }
            else {
                Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'O WinForge não conhece a ferramenta deste fabricante. Procure, no site do fabricante, a página de suporte {0}.' "$where")
            }

            Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Os drivers que o Windows Update oferece estão em Atualizações > Atualizar drivers.')

            # Uma tela que só indica não tem veredito ("Tudo certo"): sem desfecho registrado, a janela termina sem faixa.
            $none = $(if ($unreadText) { & $unreadView (New-WinForgeResult -Kind Warning -Detail (Get-WinForgeText '{0}; nenhuma ferramenta indicada' "$unreadText") -Title $title) } else { $null })
            Exit-WinForgeAction -Result $none
            return
        }

        Write-WinForgeSection -Title (Get-WinForgeText 'Recomendadas para este PC')

        foreach ($tool in $tools) {
            Write-WinForgeKeyValue -Label $tool.Name -Value (Get-WinForgeText 'para {0}{1}' "$($tool.For)" "$(if ($tool.WingetId) { (Get-WinForgeText ' · instala pelo winget') } elseif ($tool.Store) { (Get-WinForgeText ' · na Microsoft Store') } else { (Get-WinForgeText ' · página oficial') })") -LabelWidth 34
        }

        Write-Host ""
        Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Essas ferramentas acham drivers de vídeo e de BIOS mais novos que os do Windows Update. Use uma por vez e siga as instruções dela.')
        Write-Host ""

        $options = @(
            for ($i = 0; $i -lt $tools.Count; $i++) {
                $tool = $tools[$i]
                @{ Key = [string]($i + 1); Label = $(if ($tool.WingetId) { (Get-WinForgeText 'Instalar {0}' "$($tool.Name)") } else { $tool.Open }); Description = (Get-WinForgeText 'para {0}' "$($tool.For)") }
            }
        )
        $options += @{ Key = "X"; Label = (Get-WinForgeText 'Concluir'); Exit = $true; Accent = $true }

        $answer = Read-WinForgeChoice -Message (Get-WinForgeText 'Quer usar alguma agora?') -Options $options -DefaultKey "X" -ShowMenu -TextPrompt (Get-WinForgeText 'Opção (número ou X; ENTER = concluir)')
        $index = 0

        if (-not [int]::TryParse([string]$answer, [ref]$index) -or $index -lt 1 -or $index -gt $tools.Count) {
            # Concluir sem usar nenhuma: a tela só indicou, e a lista é o conteúdo (sem faixa "Tudo certo").
            $indicated = Format-WinForgeCount -Count $tools.Count -One (Get-WinForgeText 'ferramenta indicada') -Many (Get-WinForgeText 'ferramentas indicadas')
            $done = $(if ($unreadText) { & $unreadView (New-WinForgeResult -Kind Warning -Detail "$indicated; $unreadText" -Title $title) } else { $null })
            Exit-WinForgeAction -Result $done
            return
        }

        $tool = $tools[$index - 1]

        if ($tool.WingetId) {
            if (-not (Initialize-WinForgeWinget)) {
                Exit-WinForgeAction -Result (Get-WinForgeWingetMissingResult -Title $title)
                return
            }

            $result = Get-WinForgeLastResult -Output (Invoke-WinForgeWingetPackages -Operation Install -Packages @([PSCustomObject]@{ Id = $tool.WingetId; Nome = $tool.Name }))
            $final = $(if ($null -ne $result) { $result } else { New-WinForgeResult -Kind Failed -Detail (Get-WinForgeText 'a instalação não devolveu resultado') })
            $final.Etapa = $title

            if ($final.Kind -eq "Ok") {
                [void](Set-WinForgeResultView -Result $final -Headline (Get-WinForgeText '{0} está instalado' "$($tool.Name)") -Note (Get-WinForgeText 'Abra-o pelo menu Iniciar e siga as instruções dele.'))
            }
        }
        else {
            # Sem navegador padrão (ou com a associação quebrada), o Windows recusa abrir o endereço com uma mensagem em
            # inglês: a tela diz o que houve e deixa o endereço para copiar.
            $opened = $true

            # Pelo explorer.exe, que entrega a abertura ao Explorador da sessão: o navegador (ou a Store) abre sem o
            # Administrador da janela; aberto direto daqui, ele herdaria a elevação.
            try { Start-Process -FilePath "explorer.exe" -ArgumentList "`"$($tool.Url)`"" -ErrorAction Stop } catch { $opened = $false }

            # "Abrindo a página do NVIDIA App", e não "aberta", porque o Windows só recebeu o pedido. Target vem traduzido do
            # catálogo: tirar o "Abrir " do rótulo do botão só funcionava em português.
            $target = [string]$tool.Target

            if ($opened -and $tool.Store) {
                Write-WinForgeStatus -Type Success -Message (Get-WinForgeText 'Abrindo o {0} na Microsoft Store.' "$($tool.Name)")
                $final = New-WinForgeResult -Kind Ok -Detail (Get-WinForgeText 'abrindo o {0} na Microsoft Store' "$($tool.Name)") -Title $title
            }
            elseif ($opened) {
                Write-WinForgeStatus -Type Success -Message (Get-WinForgeText 'Abrindo {0} no navegador.' "$target")
                $final = New-WinForgeResult -Kind Ok -Detail (Get-WinForgeText 'abrindo {0} no navegador' "$target") -Title $title
            }
            elseif ($tool.Store) {
                Write-WinForgeStatus -Type Error -Message (Get-WinForgeText 'O Windows não abriu a Microsoft Store. Abra-a e procure por {0}.' "$($tool.Name)")
                $final = New-WinForgeResult -Kind Failed -Detail (Get-WinForgeText 'o Windows não abriu a Microsoft Store; procure por {0} nela' "$($tool.Name)") -Title $title
                [void](Set-WinForgeResultView -Result $final -Headline (Get-WinForgeText 'A Microsoft Store não abriu') -Note (Get-WinForgeText 'Abra-a e procure por {0}.' "$($tool.Name)"))
            }
            else {
                Write-WinForgeStatus -Type Error -Message (Get-WinForgeText 'O Windows não abriu o navegador. Copie o endereço e abra-o no navegador: {0}' "$($tool.Url)")
                $final = New-WinForgeResult -Kind Failed -Detail (Get-WinForgeText 'o Windows não abriu o navegador; o endereço está no resumo') -Title $title
                [void](Set-WinForgeResultView -Result $final -Headline (Get-WinForgeText 'O navegador não abriu') -Note (Get-WinForgeText 'Copie o endereço que está no resumo e abra-o no navegador.'))
            }
        }
    }
    catch {
        Write-WinForgeStatus -Type Error -Message (Get-WinForgeText 'Não foi possível concluir: {0}.' "$($_.Exception.Message.TrimEnd('.'))")
        $final = New-WinForgeResult -Kind Failed -Detail $_.Exception.Message.TrimEnd('.') -Title $title
    }

    Exit-WinForgeAction -Result $final
}


Export-ModuleMember -Function *
