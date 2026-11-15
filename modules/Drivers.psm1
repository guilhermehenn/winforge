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
        if ($total -eq 1) { return "o driver não foi instalado" }
        return "nenhum dos $total drivers foi instalado"
    }

    if ($Failed -eq 0) {
        $text = Format-WinForgeCount -Count $installed -One "driver instalado" -Many "drivers instalados"
    }
    else {
        $text = "$installed de $total $(if ($installed -eq 1) { 'instalado' } else { 'instalados' })"
    }

    if ($Warned -gt 0) { $text += " ($Warned com erros)" }
    if ($Failed -gt 0) { $text += "; $(if ($Failed -eq 1) { '1 falhou' } else { "$Failed falharam" })" }

    return $text
}


function Install-WinForgeDriverUpdates {
    $title = "Atualizar drivers"

    Enter-WinForgeAction -Title $title

    $final = New-WinForgeResult -Kind Ok -Title $title

    try {
        if (-not (Test-WinForgeElevation -Reason "Atualizar drivers exige privilégios de Administrador.")) {
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Failed -Detail "requer Administrador" -Title $title)
            return
        }

        # As mesmas conferências de Instalar atualizações do Windows: um driver também vem do Windows Update, e um de
        # firmware (BIOS) interrompido por falta de bateria pode deixar o PC sem ligar.
        if (-not (Confirm-WinForgeUpdateConditions -Reboot "Reiniciar antes evita que os drivers novos falhem." -Battery "Instalar drivers, principalmente de firmware (BIOS), não deve ser interrompido." -Retry "Atualizações > Atualizar drivers")) {
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Skipped -Detail "cancelado pelo usuário" -Title $title)
            return
        }

        Write-Progress -Activity "Procurando drivers" -Status "o Windows Update pode levar alguns minutos para responder"

        try {
            $search = Find-WinForgeWindowsUpdates -Criteria (Get-WinForgeDriverSearchCriteria)
        }
        finally {
            Write-Progress -Activity "Procurando drivers" -Completed
        }

        if ($null -eq $search.Updates) {
            Write-WinForgeStatus -Type Error -Message "Não foi possível consultar o Windows Update: $($search.Problem)."
            Write-WinForgeWindowsUpdateSearchHelp -Problem $search.Problem
            Exit-WinForgeAction -Result (Set-WinForgeUpdateSearchView -Result (New-WinForgeResult -Kind Failed -Detail "não foi possível consultar o Windows Update: $($search.Problem)" -Title $title) -Problem $search.Problem)
            return
        }

        $drivers = @($search.Updates)

        if ($drivers.Count -eq 0) {
            Write-WinForgeStatus -Type Success -Message "O Windows Update não tem drivers novos para este PC."
            Write-WinForgeStatus -Type Info -Message "Placa de vídeo e BIOS podem ter versões mais novas no programa do fabricante: veja Atualizações > Ferramentas do fabricante."
            Exit-WinForgeAction -Result (Set-WinForgeResultView -Result (New-WinForgeResult -Kind Ok -Detail "nenhum driver novo" -Title $title) -Headline "Nenhum driver novo" `
                    -Note "Placa de vídeo e BIOS podem ter versões mais novas no programa do fabricante." -Next "updates.vendor-tools" -NextLabel "Ver as ferramentas do fabricante")
            return
        }

        $recommended = @($drivers | Where-Object { -not $_.BrowseOnly })
        $optional = @($drivers | Where-Object { $_.BrowseOnly })

        Write-WinForgeKeyValue -Label "Recomendados" -Value $recommended.Count
        Write-WinForgeKeyValue -Label "Opcionais" -Value $optional.Count
        Write-Host ""

        if ($optional.Count -gt 0) {
            Write-WinForgeStatus -Type Info -Message "Os opcionais vêm desmarcados: instale um deles só se o dispositivo estiver com problema."
        }

        Write-WinForgeStatus -Type Info -Message "Se um driver novo der problema, volte ao anterior em Diagnóstico > Gerenciador de Dispositivos (no aparelho: Propriedades, Driver, Reverter driver)."
        Write-Host ""

        # O título do Windows Update ("Intel - System - 10.1.1.44") se repete para aparelhos diferentes: a descrição diz
        # para que serve cada um ("vídeo: Intel(R) UHD Graphics 620").
        $options = @(
            foreach ($driver in @($recommended + $optional)) {
                $parts = @($(if ($driver.BrowseOnly) { "opcional" } else { "recomendado" }))
                $purpose = Get-WinForgeDriverPurposeText -Update $driver
                if ($purpose) { $parts += $purpose }
                $parts += Get-WinForgeUpdateSizeText -Update $driver
                @{ Key = $driver.Id; Label = [string]$driver.Title; Description = ($parts -join " · "); Selected = (-not $driver.BrowseOnly) }
            }
        )

        $picked = Read-WinForgeMultiSelect -Message "Quais drivers instalar?" -Options $options

        if ($null -eq $picked -or @($picked).Count -eq 0) {
            Write-WinForgeStatus -Type Warning -Message "Operação cancelada."
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Skipped -Detail "cancelado pelo usuário" -Title $title)
            return
        }

        $chosen = @($drivers | Where-Object { @($picked) -contains $_.Id })
        $question = Get-WinForgeSelectionQuestion -Verb "Instalar" -Names @($chosen | ForEach-Object { [string]$_.Title }) -Many "drivers" -Limit 1

        Write-WinForgeFirmwareWarning -Updates $chosen

        $pendingBytes = [int64]0
        foreach ($driver in @($chosen | Where-Object { -not $_.Downloaded })) { $pendingBytes += [int64]$driver.Size }
        if (@($chosen | Where-Object { -not $_.Downloaded }).Count -gt 0) { Write-WinForgeMeteredWarning -Bytes $pendingBytes }

        # Com um firmware (BIOS) na escolha, o padrão é Não: um Enter a mais não manda gravar a BIOS.
        $hasFirmware = (@($chosen | Where-Object { Test-WinForgeFirmwareUpdate -Update $_ }).Count -gt 0)

        if (-not (Confirm-WinForgeAction -Message $question -DefaultKey $(if ($hasFirmware) { "N" } else { "S" }))) {
            Write-WinForgeStatus -Type Warning -Message "Operação cancelada."
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Skipped -Detail "cancelado pelo usuário" -Title $title)
            return
        }

        # Um ponto de restauração antes, quando o Windows deixa (ele limita a um por dia): é a volta mais simples se um
        # driver deixar o PC instável.
        Write-Progress -Activity $title -Status "criando um ponto de restauração"

        # Um erro inesperado ao criar o ponto (o serviço de cópias de sombra, por exemplo) não impede os drivers: a tela diz
        # que segue sem ponto novo, como quando o Windows não o cria.
        try {
            $point = New-WinForgeRestorePoint -Description "WinForge - antes dos drivers"
        }
        catch {
            $point = $null
        }
        finally {
            Write-Progress -Activity $title -Completed
        }

        if ($null -eq $point -or [string]$point.Kind -notin @("Ok", "Skipped")) { Write-WinForgeStatus -Type Info -Message "Seguindo sem ponto de restauração novo." }

        $keepAwake = Set-WinForgeKeepAwake -Enabled $true

        try {
            $run = Invoke-WinForgeUpdateInstall -Ids @($chosen | ForEach-Object { $_.Id }) -Criteria (Get-WinForgeDriverSearchCriteria)
        }
        finally {
            if ($keepAwake) { [void](Set-WinForgeKeepAwake -Enabled $false) }
        }

        Write-Host ""

        if ($run.TimedOut) {
            Write-WinForgeStatus -Type Warning -Message "O WinForge parou de acompanhar depois de muito tempo. O Windows pode continuar instalando: veja em Atualizações > Windows Update."
            $final = New-WinForgeResult -Kind Warning -Detail "tempo esgotado; a instalação pode continuar" -Title $title
        }
        elseif (-not [string]::IsNullOrWhiteSpace($run.Error) -and $run.Results.Count -eq 0) {
            Write-WinForgeStatus -Type Error -Message "Não foi possível instalar os drivers: $($run.Error.TrimEnd('.'))."
            $final = Set-WinForgeInstallErrorView -Result (New-WinForgeResult -Kind Failed -Detail $run.Error -Title $title)
        }
        else {
            $results = @()

            foreach ($item in $run.Results) {
                $outcome = Get-WinForgeUpdateOutcome -Code $item.Code -HResult $item.HResult

                # Código 3: o Windows instalou com erros. O texto de Get-WinForgeUpdateOutcome fala de "atualização"; aqui é
                # um driver, e ele não pode aparecer como "instalado" sem ressalva.
                if ($outcome.Kind -eq "Warning") {
                    $errorText = Format-WinForgeUpdateError -HResult $item.HResult
                    $outcome = New-WinForgeResult -Kind Warning -Detail $(if ($errorText) { "instalado com erros: $errorText" } else { "instalado com erros" })
                }

                $outcome.Etapa = $item.Title
                $results += $outcome
            }

            foreach ($id in @(@($run.NotDownloaded) + @($run.Missing))) {
                $outcome = New-WinForgeResult -Kind Failed -Detail $(if (@($run.Missing) -contains $id) { "não está mais disponível" } else { "não foi baixado" })
                $outcome.Etapa = Get-WinForgeUpdateTitleById -Updates $chosen -Id $id
                $results += $outcome
            }

            foreach ($result in $results) {
                if ($result.Kind -eq "Failed") { Write-WinForgeStatus -Type Error -Message "$($result.Etapa): $($result.Detail)." }
                elseif ($result.Kind -eq "Warning") { Write-WinForgeStatus -Type Warning -Message "$($result.Etapa): $($result.Detail)." }
                else { Write-WinForgeStatus -Type Success -Message "$($result.Etapa): instalado." }
            }

            $failed = @($results | Where-Object { $_.Kind -eq "Failed" })
            $warned = @($results | Where-Object { $_.Kind -eq "Warning" })
            $installed = @($results | Where-Object { $_.Kind -ne "Failed" })
            $reboot = [bool]$run.RebootRequired -and $installed.Count -gt 0

            if ($installed.Count -gt 0) {
                [void](Add-WinForgeChange -Action "Drivers instalados" -Text (Join-WinForgeList -Items @($installed | ForEach-Object { [string]$_.Etapa })))
            }

            $detail = Get-WinForgeDriverRunDetail -Ok ($installed.Count - $warned.Count) -Warned $warned.Count -Failed $failed.Count

            # As contas e os motivos, para a faixa da janela (Set-WinForgeInstallView).
            $data = @{
                RebootRequired = $reboot
                Installed      = $installed.Count
                Failed         = $failed.Count
                Warned         = $warned.Count
                Problems       = @(@($failed) + @($warned) | ForEach-Object { [string]$_.Detail } | Where-Object { $_ })
            }

            # Um erro depois de alguns drivers já terem resultado deixa o resumo incompleto: a tela e a faixa dizem qual foi
            # (sem isso, a faixa ficava amarela sem motivo à vista).
            $cutShort = -not [string]::IsNullOrWhiteSpace($run.Error)

            if ($cutShort) {
                Write-WinForgeStatus -Type Error -Message "A instalação foi interrompida por um erro: $($run.Error.TrimEnd('.'))."
                $detail = "$detail; erro durante a instalação: $($run.Error)"
            }

            if ($failed.Count -eq $results.Count) { $final = New-WinForgeResult -Kind Failed -Detail $detail -Title $title -Data $data }
            elseif ($failed.Count -gt 0 -or $warned.Count -gt 0 -or $cutShort) { $final = New-WinForgeResult -Kind Warning -Detail $detail -Title $title -Data $data }
            else { $final = New-WinForgeResult -Kind Ok -Detail $detail -Title $title -Data $data }

            [void](Set-WinForgeInstallView -Result $final -One "driver instalado" -Many "drivers instalados" -Noun "drivers" -Each "cada um" -DoneMany "instalados" `
                    -None $(if ($results.Count -eq 1) { "O driver não foi instalado" } else { "Nenhum driver instalado" }) `
                    -OkNote "Se algum der problema, volte ao driver anterior no Gerenciador de Dispositivos.")

            if ($reboot) {
                Request-WinForgeInstallRestart -What "os drivers" -Later "Os drivers terminam de instalar quando você reiniciar o PC."
            }
        }
    }
    catch {
        # A mesma tradução dos erros do Windows Update (sem o embrulho do PowerShell, com o código).
        $problem = Get-WinForgeWindowsUpdateProblem -Message $_.Exception.Message -HResult $_.Exception.HResult
        Write-WinForgeStatus -Type Error -Message "Não foi possível atualizar os drivers: $problem."
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
    Store, a página do aplicativo na Microsoft Store; Open = o rótulo do botão quando não há winget. Cada fabricante tem uma ferramenta
    para a linha de PCs de empresa e outra para a de uso pessoal: a da linha errada diz que o PC não é compatível.
    #>
    return @(
        [PSCustomObject]@{ Id = "dell"; Name = "Dell Command | Update"; For = "PCs Dell Pro, Latitude, OptiPlex, Precision, Vostro e XPS"; WingetId = "Dell.CommandUpdate"; Url = ""; Open = ""; Store = $false },
        [PSCustomObject]@{ Id = "dell-supportassist"; Name = "Dell SupportAssist"; For = "PCs Dell Inspiron, Alienware e G"; WingetId = ""; Url = "https://www.dell.com/support/kbdoc/000130387"; Open = "Abrir a página do Dell SupportAssist"; Store = $false },
        [PSCustomObject]@{ Id = "lenovo"; Name = "Lenovo System Update"; For = "PCs Lenovo ThinkPad, ThinkCentre e ThinkStation"; WingetId = "Lenovo.SystemUpdate"; Url = ""; Open = ""; Store = $false },
        [PSCustomObject]@{ Id = "lenovo-vantage"; Name = "Lenovo Vantage"; For = "PCs Lenovo IdeaPad, Yoga, Legion, ThinkBook e outros"; WingetId = ""; Url = "ms-windows-store://pdp/?ProductId=9WZDNCRFJ4MV"; Open = "Abrir o Lenovo Vantage na Microsoft Store"; Store = $true },
        [PSCustomObject]@{ Id = "hp"; Name = "Site de drivers da HP"; For = "PCs HP"; WingetId = ""; Url = "https://support.hp.com/br-pt/drivers"; Open = "Abrir o site de drivers da HP"; Store = $false },
        [PSCustomObject]@{ Id = "intel"; Name = "Intel Driver & Support Assistant"; For = "processador e vídeo Intel"; WingetId = "Intel.IntelDriverAndSupportAssistant"; Url = ""; Open = ""; Store = $false },
        [PSCustomObject]@{ Id = "nvidia"; Name = "NVIDIA App"; For = "placas de vídeo NVIDIA"; WingetId = ""; Url = "https://www.nvidia.com/pt-br/software/nvidia-app/"; Open = "Abrir a página do NVIDIA App"; Store = $false },
        [PSCustomObject]@{ Id = "amd"; Name = "AMD Adrenalin (detecção automática)"; For = "processador e vídeo AMD"; WingetId = ""; Url = "https://www.amd.com/en/support/download/drivers.html"; Open = "Abrir a página de drivers da AMD"; Store = $false }
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

    try { $system = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop } catch { $system = $null; $systemRead = $false }
    try { $cpu = @(Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop) | Select-Object -First 1 } catch { $cpu = $null }
    try { $gpus = @(Get-CimInstance -ClassName Win32_VideoController -ErrorAction Stop | ForEach-Object { [string]$_.Name } | Where-Object { $_ }) } catch { $gpus = @(); $gpuRead = $false }

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
    $title = "Ferramentas do fabricante"

    Enter-WinForgeAction -Title $title

    $final = New-WinForgeResult -Kind Ok -Title $title

    try {
        Write-Progress -Activity $title -Status "lendo o fabricante do PC e da placa de vídeo"

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
        if (-not $systemRead) { $unread += "o fabricante do PC" }
        if (-not $gpuRead) { $unread += "a placa de vídeo" }
        $unreadText = $(if ($unread.Count -gt 0) { "não foi possível ler $(Join-WinForgeList -Items $unread)" } else { "" })

        $modelText = Get-WinForgeHardwareModelText -Hardware $hardware

        Write-WinForgeKeyValue -Label "Fabricante do PC" -Value $(if (Test-WinForgeVendorText -Text $hardware.Manufacturer) { $hardware.Manufacturer } elseif (-not $systemRead) { "não foi possível ler" } else { "não informado" })
        if ($modelText) { Write-WinForgeKeyValue -Label "Modelo" -Value $modelText }
        Write-WinForgeKeyValue -Label "Placa de vídeo" -Value $(if (@($hardware.Gpus).Count -gt 0) { Join-WinForgeList -Items @($hardware.Gpus) } elseif (-not $gpuRead) { "não foi possível ler" } else { "não informada" })
        Write-Host ""

        if ($unreadText) {
            Write-WinForgeStatus -Type Warning -Message "O Windows não respondeu: $unreadText. A indicação abaixo pode estar incompleta."
        }

        $tools = @(Get-WinForgeVendorTools -Hardware $hardware)

        if ($tools.Count -eq 0) {
            $where = $(if ($modelText) { "pelo modelo $modelText" } else { "pelo modelo do PC" })

            if ($unreadText) {
                Write-WinForgeStatus -Type Info -Message "Procure, no site do fabricante do PC, a página de suporte $where."
            }
            else {
                Write-WinForgeStatus -Type Info -Message "O WinForge não conhece a ferramenta deste fabricante. Procure, no site do fabricante, a página de suporte $where."
            }

            Write-WinForgeStatus -Type Info -Message "Os drivers que o Windows Update oferece estão em Atualizações > Atualizar drivers."

            # Uma tela que só indica não tem veredito ("Tudo certo"): sem desfecho registrado, a janela termina sem faixa.
            $none = $(if ($unreadText) { New-WinForgeResult -Kind Warning -Detail "$unreadText; nenhuma ferramenta indicada" -Title $title } else { $null })
            Exit-WinForgeAction -Result $none
            return
        }

        Write-WinForgeSection -Title "Recomendadas para este PC"

        foreach ($tool in $tools) {
            Write-WinForgeKeyValue -Label $tool.Name -Value "para $($tool.For)$(if ($tool.WingetId) { ' · instala pelo winget' } elseif ($tool.Store) { ' · na Microsoft Store' } else { ' · página oficial' })" -LabelWidth 34
        }

        Write-Host ""
        Write-WinForgeStatus -Type Info -Message "Essas ferramentas acham drivers de vídeo e de BIOS mais novos que os do Windows Update. Use uma por vez e siga as instruções dela."
        Write-Host ""

        $options = @(
            for ($i = 0; $i -lt $tools.Count; $i++) {
                $tool = $tools[$i]
                @{ Key = [string]($i + 1); Label = $(if ($tool.WingetId) { "Instalar $($tool.Name)" } else { $tool.Open }); Description = "para $($tool.For)" }
            }
        )
        $options += @{ Key = "X"; Label = "Concluir"; Exit = $true; Accent = $true }

        $answer = Read-WinForgeChoice -Message "Quer usar alguma agora?" -Options $options -DefaultKey "X" -ShowMenu -TextPrompt "Opção (número ou X; ENTER = concluir)"
        $index = 0

        if (-not [int]::TryParse([string]$answer, [ref]$index) -or $index -lt 1 -or $index -gt $tools.Count) {
            # Concluir sem usar nenhuma: a tela só indicou, e a lista é o conteúdo (sem faixa "Tudo certo").
            $indicated = Format-WinForgeCount -Count $tools.Count -One "ferramenta indicada" -Many "ferramentas indicadas"
            $done = $(if ($unreadText) { New-WinForgeResult -Kind Warning -Detail "$indicated; $unreadText" -Title $title } else { $null })
            Exit-WinForgeAction -Result $done
            return
        }

        $tool = $tools[$index - 1]

        if ($tool.WingetId) {
            if (-not (Initialize-WinForgeWinget)) {
                Exit-WinForgeAction -Result (New-WinForgeResult -Kind Failed -Detail "winget não encontrado" -Title $title)
                return
            }

            $result = Get-WinForgeLastResult -Output (Invoke-WinForgeWingetPackages -Operation Install -Packages @([PSCustomObject]@{ Id = $tool.WingetId; Nome = $tool.Name }))
            $final = $(if ($null -ne $result) { $result } else { New-WinForgeResult -Kind Failed -Detail "a instalação não devolveu resultado" })
            $final.Etapa = $title
        }
        else {
            # Sem navegador padrão (ou com a associação quebrada), o Windows recusa abrir o endereço com uma mensagem em
            # inglês: a tela diz o que houve e deixa o endereço para copiar.
            $opened = $true

            # Pelo explorer.exe, que entrega a abertura ao Explorador da sessão: o navegador (ou a Store) abre sem o
            # Administrador da janela; aberto direto daqui, ele herdaria a elevação.
            try { Start-Process -FilePath "explorer.exe" -ArgumentList "`"$($tool.Url)`"" -ErrorAction Stop } catch { $opened = $false }

            # "Abrir a página do NVIDIA App" vira "a página do NVIDIA App": "Abrindo", e não "aberta", porque o Windows só
            # recebeu o pedido.
            $target = ([string]$tool.Open) -replace '^Abrir ', ''

            if ($opened -and $tool.Store) {
                Write-WinForgeStatus -Type Success -Message "Abrindo o $($tool.Name) na Microsoft Store."
                $final = New-WinForgeResult -Kind Ok -Detail "abrindo o $($tool.Name) na Microsoft Store" -Title $title
            }
            elseif ($opened) {
                Write-WinForgeStatus -Type Success -Message "Abrindo $target no navegador."
                $final = New-WinForgeResult -Kind Ok -Detail "abrindo $target no navegador" -Title $title
            }
            elseif ($tool.Store) {
                Write-WinForgeStatus -Type Error -Message "O Windows não abriu a Microsoft Store. Abra-a e procure por $($tool.Name)."
                $final = New-WinForgeResult -Kind Failed -Detail "o Windows não abriu a Microsoft Store; procure por $($tool.Name) nela" -Title $title
            }
            else {
                Write-WinForgeStatus -Type Error -Message "O Windows não abriu o navegador. Copie o endereço e abra-o no navegador: $($tool.Url)"
                $final = New-WinForgeResult -Kind Failed -Detail "o Windows não abriu o navegador; o endereço de $($tool.Name) está no resumo" -Title $title
            }
        }
    }
    catch {
        Write-WinForgeStatus -Type Error -Message "Não foi possível concluir: $($_.Exception.Message.TrimEnd('.'))."
        $final = New-WinForgeResult -Kind Failed -Detail $_.Exception.Message.TrimEnd('.') -Title $title
    }

    Exit-WinForgeAction -Result $final
}


Export-ModuleMember -Function *
