# Reparo e otimização: DISM, SFC, CHKDSK e otimização da unidade do sistema.
# Todas as ações aceitam -Embedded (sem cabeçalho, pergunta nem pausa, para uso dentro da Manutenção recomendada)
# e -PassThru (devolve um WinForge.Result em vez de não devolver nada).

$script:WinForgeChkdskRepairPending = $false


# ---------------------------------------------------------------------------
# Interpretação das saídas
# ---------------------------------------------------------------------------

function Test-WinForgeDismRepairNeeded {
    param (
        [int]$ExitCode,
        [string]$OutputText
    )

    # /CheckHealth só lê marcações já registradas pelo Windows; é rápido e evita um RestoreHealth desnecessário.
    if ($OutputText -match "(?i)no component store corruption|nenhuma corrup") {
        return $false
    }

    if ($OutputText -match "(?i)repairable|repar[aá]vel|corrupt|corromp") {
        return $true
    }

    return ($ExitCode -ne 0)
}


function Test-WinForgeChkdskRepairRequired {
    param (
        [int]$ExitCode,
        [string]$OutputText
    )

    # Códigos do CHKDSK: 0 = sem erros; 1 = erros encontrados e corrigidos;
    # 2 = limpeza/avisos sem /f (não exige reparo offline por si só); 3 = não foi possível verificar/reparar.
    if ($ExitCode -ge 3) {
        return $true
    }

    return (
        $OutputText -match "spotfix" -or
        $OutputText -match "offline repair" -or
        $OutputText -match "reparo offline" -or
        $OutputText -match "next restart" -or
        $OutputText -match "próxima reinicialização" -or
        $OutputText -match "proxima reinicializacao"
    )
}


function Get-WinForgeSfcResult {
    # O SFC devolve 0 mesmo quando encontra arquivos que não consegue reparar; a conclusão está no texto.
    param (
        [int]$ExitCode,
        [string]$OutputText
    )

    if ($OutputText -match "(?i)repair pending|reparo.{0,40}pendente|requires reboot|requer.{0,20}rein") {
        return (New-WinForgeResult -Kind Warning -Detail "há um reparo pendente: reinicie o Windows e repita" -Data @{ RebootRequired = $true })
    }

    if ($OutputText -match "(?i)unable to fix|n[ãa]o p[ôo]de corrigir|n[ãa]o foi poss[íi]vel (corrigir|reparar)") {
        return (New-WinForgeResult -Kind Warning -Detail "há arquivos corrompidos que não foram reparados; veja CBS.log")
    }

    if ($ExitCode -ne 0) {
        return (New-WinForgeResult -Kind Failed -Detail "código $ExitCode")
    }

    if ($OutputText -match "(?i)successfully repaired|reparou com [êe]xito|reparad[oa]s? com [êe]xito") {
        return (New-WinForgeResult -Kind Ok -Detail "arquivos corrompidos foram reparados")
    }

    return (New-WinForgeResult -Kind Ok)
}


function Get-WinForgeExitCodeResult {
    # Resultado padrão de ferramentas do sistema: 0 = OK; 3010 = OK, mas exige reinício; outros = falha.
    # OutputText existe só para ter a mesma assinatura dos demais analisadores de resultado (SFC): este não lê o texto.
    param (
        [int]$ExitCode,
        [string]$OutputText
    )

    if ($ExitCode -eq 0) {
        return (New-WinForgeResult -Kind Ok)
    }

    if ($ExitCode -eq 3010) {
        return (New-WinForgeResult -Kind Warning -Detail "concluído; reinicie o Windows para finalizar" -Data @{ RebootRequired = $true })
    }

    return (New-WinForgeResult -Kind Failed -Detail "código de saída $ExitCode")
}


# ---------------------------------------------------------------------------
# Executor comum
# ---------------------------------------------------------------------------

function Invoke-WinForgeTool {
    param (
        [Parameter(Mandatory)]
        [string]$Title,

        [Parameter(Mandatory)]
        [string]$FilePath,

        [string[]]$Arguments = @(),
        [string[]]$Description = @(),
        [string[]]$Warnings = @(),

        # Recebe ExitCode e OutputText e devolve um WinForge.Result. Padrão: Get-WinForgeExitCodeResult.
        [scriptblock]$ResultParser,

        [switch]$Embedded,
        [switch]$PassThru
    )

    Enter-WinForgeAction -Title $Title -Embedded:$Embedded

    $result = $null

    try {
        if (-not (Test-WinForgeElevation -Reason "Esta ação exige privilégios de Administrador.")) {
            $result = New-WinForgeResult -Kind Failed -Detail "requer Administrador"
        }
        elseif (-not (Get-Command $FilePath -ErrorAction SilentlyContinue)) {
            Write-WinForgeStatus -Type Error -Message "Comando não encontrado: $FilePath"
            $result = New-WinForgeResult -Kind Failed -Detail "comando não encontrado"
        }
        else {
            foreach ($line in $Description) { Write-Host $line -ForegroundColor Yellow }
            foreach ($line in $Warnings) { Write-Host $line -ForegroundColor Cyan }

            if ($Description.Count -gt 0 -or $Warnings.Count -gt 0) { Write-Host "" }

            Write-WinForgeCommand -Command "$FilePath $($Arguments -join ' ')"
            Write-Host ""

            if (-not $Embedded -and -not (Confirm-WinForgeAction "Deseja continuar?" -DefaultKey S)) {
                Write-WinForgeStatus -Type Warning -Message "Operação cancelada."
                $result = New-WinForgeResult -Kind Skipped -Detail "cancelado pelo usuário"
            }
            else {
                Write-WinForgeStatus -Type Running -Message "Executando. Não feche esta janela."
                Write-Host ""

                $run = Invoke-WinForgeCapture -FilePath $FilePath -Arguments $Arguments -Echo

                if ($null -ne $ResultParser) {
                    $result = & $ResultParser $run.ExitCode $run.Text
                }
                else {
                    $result = Get-WinForgeExitCodeResult -ExitCode $run.ExitCode -OutputText $run.Text
                }

                Write-Host ""

                $reason = ""
                if (-not [string]::IsNullOrWhiteSpace($result.Detail)) { $reason = ": $($result.Detail)" }

                switch ($result.Kind) {
                    "Ok"      { Write-WinForgeStatus -Type Success -Message "$Title concluído com sucesso." }
                    "Warning" { Write-WinForgeStatus -Type Warning -Message "$Title concluído com ressalvas$reason." }
                    default   { Write-WinForgeStatus -Type Error -Message "$Title não foi concluído$reason." }
                }
            }
        }
    }
    catch {
        Write-WinForgeStatus -Type Error -Message "Ocorreu um erro ao executar '$Title': $($_.Exception.Message)"
        $result = New-WinForgeResult -Kind Failed -Detail $_.Exception.Message
    }

    $result.Etapa = $Title
    Exit-WinForgeAction -Embedded:$Embedded

    if ($PassThru) {
        return $result
    }
}


# ---------------------------------------------------------------------------
# DISM e SFC
# ---------------------------------------------------------------------------

function Invoke-WinForgeDism {
    param (
        [switch]$Embedded,
        [switch]$PassThru
    )

    Invoke-WinForgeTool `
        -Title "Reparar imagem e componentes (DISM)" `
        -FilePath "dism.exe" `
        -Arguments @("/Online", "/Cleanup-Image", "/RestoreHealth") `
        -Description @("Repara a imagem de componentes usada pelo Windows.") `
        -Warnings @("Pode levar vários minutos e usa a internet (Windows Update) para obter arquivos. Arquivos pessoais não serão removidos.") `
        -Embedded:$Embedded -PassThru:$PassThru
}


function Invoke-WinForgeSfc {
    param (
        [switch]$Embedded,
        [switch]$PassThru
    )

    Invoke-WinForgeTool `
        -Title "Verificar arquivos do sistema (SFC)" `
        -FilePath "sfc.exe" `
        -Arguments @("/scannow") `
        -Description @("Verifica os arquivos protegidos do Windows e tenta reparar inconsistências.") `
        -Warnings @("Pode levar vários minutos. Arquivos pessoais não serão removidos.") `
        -ResultParser { param($ExitCode, $Text) Get-WinForgeSfcResult -ExitCode $ExitCode -OutputText $Text } `
        -Embedded:$Embedded -PassThru:$PassThru
}


function Invoke-WinForgeDismAndSfc {
    <#
    Reparo completo: DISM e depois SFC (o SFC usa a imagem que o DISM acabou de corrigir).
    Com -CheckFirst, o DISM só repara se o /CheckHealth indicar dano (usado na Manutenção recomendada).
    #>
    param (
        [switch]$CheckFirst,
        [switch]$Embedded,
        [switch]$PassThru
    )

    $title = "Reparar o Windows (DISM + SFC)"

    Enter-WinForgeAction -Title $title -Embedded:$Embedded

    $result = $null

    try {
        $proceed = $true

        if (-not (Test-WinForgeElevation -Reason "O reparo do Windows exige privilégios de Administrador.")) {
            $proceed = $false
            $result = New-WinForgeResult -Kind Failed -Detail "requer Administrador"
        }
        elseif (-not $Embedded) {
            Write-Host "Serão executados DISM e SFC, nesta ordem. Arquivos pessoais não serão removidos." -ForegroundColor Yellow
            Write-Host ""

            if (-not (Confirm-WinForgeAction "Deseja iniciar o reparo?" -DefaultKey S)) {
                $proceed = $false
                Write-WinForgeStatus -Type Warning -Message "Operação cancelada."
                $result = New-WinForgeResult -Kind Skipped -Detail "cancelado pelo usuário"
            }
        }

        if ($proceed) {
            $runDism = $true

            if ($CheckFirst) {
                Write-WinForgeSubStep "DISM /CheckHealth" "Verificando se o repositório de componentes foi marcado como danificado."
                $check = Invoke-WinForgeCapture -FilePath "dism.exe" -Arguments @("/Online", "/Cleanup-Image", "/CheckHealth") -Echo

                $runDism = Test-WinForgeDismRepairNeeded -ExitCode $check.ExitCode -OutputText $check.Text

                Write-Host ""

                if ($runDism) {
                    Write-WinForgeStatus -Type Warning -Message "Há indício de dano: executando DISM /RestoreHealth."
                }
                else {
                    Write-WinForgeStatus -Type Success -Message "Nenhum dano marcado: DISM /RestoreHealth não é necessário."
                }
            }

            $dism = $null

            if ($runDism) {
                $dism = Invoke-WinForgeDism -Embedded -PassThru

                if ($dism.Kind -eq "Failed") {
                    Write-Host ""
                    Write-WinForgeStatus -Type Warning -Message "O DISM falhou. O SFC será executado mesmo assim."
                }
            }

            $sfc = Invoke-WinForgeSfc -Embedded -PassThru

            Write-WinForgeSection -Title "Resumo do reparo"
            $summary = @()
            if ($null -ne $dism) { $summary += $dism }
            $summary += $sfc
            Write-WinForgeResultTable -Results $summary

            $kinds = @($summary | ForEach-Object { $_.Kind })

            # O pedido de reinício de uma das ferramentas vale para o reparo inteiro.
            $data = @{}
            if (@($summary | Where-Object { Test-WinForgeResultFlag -Result $_ -Name "RebootRequired" }).Count -gt 0) {
                $data["RebootRequired"] = $true
            }

            if ($kinds -contains "Failed") {
                $result = New-WinForgeResult -Kind Failed -Detail "DISM ou SFC falhou; revise a saída acima" -Data $data
            }
            elseif ($kinds -contains "Warning") {
                $result = New-WinForgeResult -Kind Warning -Detail "DISM ou SFC terminou com ressalvas; revise a saída acima" -Data $data
            }
            else {
                $result = New-WinForgeResult -Kind Ok -Data $data
            }
        }
    }
    catch {
        Write-WinForgeStatus -Type Error -Message "Ocorreu um erro durante o reparo: $($_.Exception.Message)"
        $result = New-WinForgeResult -Kind Failed -Detail $_.Exception.Message
    }

    $result.Etapa = $title
    Exit-WinForgeAction -Embedded:$Embedded

    if ($PassThru) {
        return $result
    }
}


# ---------------------------------------------------------------------------
# CHKDSK
# ---------------------------------------------------------------------------

function Test-WinForgeChkdskRepairPending {
    return [bool]$script:WinForgeChkdskRepairPending
}


function Set-WinForgeChkdskStartupRepair {
    # Marca o volume como "sujo" e agenda o Autochk para a próxima inicialização. Devolve $true se agendou.
    param (
        [string]$Drive = $env:SystemDrive
    )

    foreach ($command in @("fsutil.exe", "chkntfs.exe")) {
        if (-not (Get-Command $command -ErrorAction SilentlyContinue)) {
            throw "Comando não encontrado: $command"
        }
    }

    $mark = Invoke-WinForgeCapture -FilePath "fsutil.exe" -Arguments @("dirty", "set", $Drive)

    if ($mark.ExitCode -ne 0) {
        throw "Não foi possível marcar a unidade para reparo. Código: $($mark.ExitCode)."
    }

    $schedule = Invoke-WinForgeCapture -FilePath "chkntfs.exe" -Arguments @("/C", $Drive)

    if ($schedule.ExitCode -ne 0) {
        throw "Não foi possível agendar o CHKDSK. Código: $($schedule.ExitCode)."
    }

    $script:WinForgeChkdskRepairPending = $false
    return $true
}


function Invoke-WinForgeScheduleChkdskRepair {
    # Pergunta já feita pelo chamador; aqui só agenda e conta o que aconteceu.
    try {
        [void](Set-WinForgeChkdskStartupRepair -Drive $env:SystemDrive)
        Write-WinForgeStatus -Type Success -Message "Reparo agendado para a próxima reinicialização."
        return $true
    }
    catch {
        Write-WinForgeStatus -Type Error -Message "Não foi possível agendar o reparo: $($_.Exception.Message)"
        return $false
    }
}


function Start-WinForgeChkdsk {
    <#
    Verificação online do sistema de arquivos (chkdsk /scan). Se o Windows indicar que o reparo precisa ser feito
    na inicialização, pergunta se deve agendá-lo; com -DeferRepairPrompt a pergunta fica para o final da Manutenção.
    #>
    param (
        [switch]$DeferRepairPrompt,
        [switch]$Embedded,
        [switch]$PassThru
    )

    $script:WinForgeChkdskRepairPending = $false
    $title = "Verificar o sistema de arquivos (CHKDSK)"

    Enter-WinForgeAction -Title $title -Embedded:$Embedded

    $result = $null

    try {
        if (-not (Test-WinForgeElevation -Reason "O CHKDSK exige privilégios de Administrador.")) {
            $result = New-WinForgeResult -Kind Failed -Detail "requer Administrador"
        }
        elseif (-not (Get-Command "chkdsk.exe" -ErrorAction SilentlyContinue)) {
            Write-WinForgeStatus -Type Error -Message "Comando não encontrado: chkdsk.exe"
            $result = New-WinForgeResult -Kind Failed -Detail "comando não encontrado"
        }
        else {
            $drive = $env:SystemDrive
            $arguments = @($drive, "/scan")

            Write-WinForgeKeyValue -Label "Unidade" -Value $drive
            Write-WinForgeKeyValue -Label "Modo" -Value "Verificação online (não exige reiniciar)"
            Write-WinForgeCommand -Command "chkdsk.exe $($arguments -join ' ')"
            Write-Host ""

            if (-not $Embedded -and -not (Confirm-WinForgeAction "Deseja iniciar a verificação?" -DefaultKey S)) {
                Write-WinForgeStatus -Type Warning -Message "Operação cancelada."
                $result = New-WinForgeResult -Kind Skipped -Detail "cancelado pelo usuário"
            }
            else {
                $run = Invoke-WinForgeCapture -FilePath "chkdsk.exe" -Arguments $arguments -Echo

                Write-Host ""

                switch ($run.ExitCode) {
                    0 { Write-WinForgeStatus -Type Success -Message "Nenhum erro foi encontrado." }
                    1 { Write-WinForgeStatus -Type Success -Message "Erros foram encontrados e corrigidos." }
                    2 { Write-WinForgeStatus -Type Warning -Message "A verificação terminou com avisos (limpeza sugerida), sem exigir reparo offline por si só." }
                    3 { Write-WinForgeStatus -Type Warning -Message "A unidade não pôde ser verificada ou reparada completamente." }
                    default { Write-WinForgeStatus -Type Warning -Message "CHKDSK finalizou com código $($run.ExitCode)." }
                }

                $repairRequired = Test-WinForgeChkdskRepairRequired -ExitCode $run.ExitCode -OutputText $run.Text

                if (-not $repairRequired) {
                    if ($run.ExitCode -le 1) {
                        $result = New-WinForgeResult -Kind Ok
                    }
                    else {
                        $result = New-WinForgeResult -Kind Warning -Detail "avisos do CHKDSK (código $($run.ExitCode))"
                    }
                }
                else {
                    Write-Host ""
                    Write-WinForgeStatus -Type Warning -Message "O Windows precisa concluir o reparo durante a inicialização."
                    Write-Host "      O reparo offline roda antes do Windows iniciar e pode levar de minutos a horas (principalmente em HDD)." -ForegroundColor DarkGray
                    Write-Host ""

                    if ($DeferRepairPrompt) {
                        # Na Manutenção recomendada a decisão é pedida ao final, sem interromper as etapas.
                        $script:WinForgeChkdskRepairPending = $true
                        Write-WinForgeStatus -Type Info -Message "O agendamento do reparo será oferecido ao final da manutenção."
                        $result = New-WinForgeResult -Kind Warning -Detail "reparo offline pendente"
                    }
                    elseif (Confirm-WinForgeAction "Deseja agendar o reparo para a próxima reinicialização?" -DefaultKey N) {
                        if (Invoke-WinForgeScheduleChkdskRepair) {
                            $result = New-WinForgeResult -Kind Warning -Detail "reparo agendado para o próximo boot" -Data @{ RebootRequired = $true }
                        }
                        else {
                            $result = New-WinForgeResult -Kind Failed -Detail "não foi possível agendar o reparo"
                        }
                    }
                    else {
                        Write-WinForgeStatus -Type Warning -Message "Reparo não agendado."
                        $result = New-WinForgeResult -Kind Warning -Detail "reparo offline não agendado"
                    }
                }
            }
        }
    }
    catch {
        Write-WinForgeStatus -Type Error -Message "Erro ao executar o CHKDSK: $($_.Exception.Message)"
        $result = New-WinForgeResult -Kind Failed -Detail $_.Exception.Message
    }

    $result.Etapa = $title
    Exit-WinForgeAction -Embedded:$Embedded

    if ($PassThru) {
        return $result
    }
}


# ---------------------------------------------------------------------------
# Otimização da unidade
# ---------------------------------------------------------------------------

function Start-WinForgeDriveOptimization {
    param (
        [switch]$Embedded,
        [switch]$PassThru
    )

    $drive = $env:SystemDrive

    # /O delega ao Windows a escolha correta: retrim/otimização para SSD e desfragmentação para HDD.
    Invoke-WinForgeTool `
        -Title "Otimizar a unidade do sistema" `
        -FilePath "defrag.exe" `
        -Arguments @($drive, "/O", "/U", "/V") `
        -Description @("Unidade $drive : o Windows escolhe TRIM para SSD ou desfragmentação para HDD.") `
        -Warnings @("Em HDD pode levar bastante tempo; em SSD costuma ser rápido.") `
        -Embedded:$Embedded -PassThru:$PassThru
}


# ---------------------------------------------------------------------------
# Dispositivos e drivers
# ---------------------------------------------------------------------------

function Invoke-WinForgeDeviceScan {
    param (
        [switch]$Embedded,
        [switch]$PassThru
    )

    Invoke-WinForgeTool `
        -Title "Detectar dispositivos e drivers" `
        -FilePath "pnputil.exe" `
        -Arguments @("/scan-devices") `
        -Description @("Pede ao Windows que procure dispositivos conectados e instale os drivers que já estiverem disponíveis.") `
        -Embedded:$Embedded -PassThru:$PassThru
}


Export-ModuleMember -Function *
