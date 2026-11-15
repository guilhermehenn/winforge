# Histórico de mudanças: o diário do que o WinForge mudou no PC, com o desfazer de cada mudança que dá para desfazer.
#
# Cada ação que muda o Windows anota uma linha (o que foi feito, quando e, quando existe, como desfazer) com
# Add-WinForgeChange, que fica no Core: assim qualquer módulo anota sem depender deste. Aqui ficam o desfazer de cada
# tipo de mudança e a tela do histórico. O diário fica em %LOCALAPPDATA%\WinForge\changes.json (as 200 mais recentes).


# ---------------------------------------------------------------------------
# Desfazer
# ---------------------------------------------------------------------------

function Test-WinForgeStartupUndoItem {
    <#
    Se um item guardado no diário pode ser ligado ou desligado pelo desfazer: tarefas agendadas só se forem uma das que
    a tela Gerenciar inicialização mostra hoje (de outros fabricantes, que rodam ao entrar no Windows ou ao ligar o PC);
    os demais só se o liga/desliga for numa das chaves StartupApproved que o Windows usa para isso.
    #>
    param (
        [Parameter(Mandatory)]$Item,

        # As tarefas de inicialização já lidas (Get-WinForgeStartupTasks percorre o Agendador inteiro e leva segundos):
        # quem confere vários itens lê uma vez só.
        $Tasks = $null
    )

    $name = [string](Get-WinForgeJsonValue -Object $Item -Name "Name" -Default "")
    $source = [string](Get-WinForgeJsonValue -Object $Item -Name "Source" -Default "")

    if ([string]::IsNullOrWhiteSpace($name)) { return $false }

    if ($source -eq "Tarefa agendada") {
        $taskPath = [string](Get-WinForgeJsonValue -Object $Item -Name "TaskPath" -Default "")
        $taskName = [string](Get-WinForgeJsonValue -Object $Item -Name "TaskName" -Default "")

        if ([string]::IsNullOrWhiteSpace($taskName) -or $taskPath -like "\Microsoft\*") { return $false }

        if ($null -eq $Tasks) { $Tasks = @(Get-WinForgeStartupTasks) }

        return (@($Tasks | Where-Object { [string]$_.TaskPath -eq $taskPath -and [string]$_.TaskName -eq $taskName }).Count -gt 0)
    }

    # Aplicativo da Store: o liga/desliga é o State da tarefa de inicialização dele, numa chave SystemAppData da conta.
    if ($source -eq "Aplicativo da Store") {
        return (Test-WinForgeStartupAppPath -Path ([string](Get-WinForgeJsonValue -Object $Item -Name "ApprovedPath" -Default "")))
    }

    $approvedRoot = "Microsoft\Windows\CurrentVersion\Explorer\StartupApproved"
    $known = @(
        "HKCU:\Software\$approvedRoot\Run",
        "HKCU:\Software\$approvedRoot\StartupFolder",
        "HKLM:\SOFTWARE\$approvedRoot\Run",
        "HKLM:\SOFTWARE\$approvedRoot\Run32",
        "HKLM:\SOFTWARE\$approvedRoot\StartupFolder"
    )

    return ($known -contains [string](Get-WinForgeJsonValue -Object $Item -Name "ApprovedPath" -Default ""))
}


function Undo-WinForgeChange {
    # Desfaz uma mudança anotada e devolve um WinForge.Result (Etapa = o nome da mudança). Não marca como desfeita: quem
    # chama marca só o que deu certo.
    param (
        [Parameter(Mandatory)]$Change
    )

    $undo = $Change.Undo
    $kind = [string](Get-WinForgeJsonValue -Object $undo -Name "Kind" -Default "")

    # O diário fica em %LOCALAPPDATA%, onde qualquer programa da conta grava sem Administrador, e o desfazer pode rodar
    # como Administrador: o que vem dele é conferido antes de virar uma mudança no Windows (só os backups da pasta do
    # WinForge, só os itens de inicialização que o WinForge gerencia, só os recursos do catálogo).
    # Recursos do Windows e o DNS dos adaptadores só voltam com Administrador: sem ele, o motivo é dito com as palavras do
    # WinForge (e não com o texto cru do Windows), e a mudança continua na lista para depois.
    if ($kind -in @("feature", "dns") -and -not (Test-WinForgeAdministrator)) {
        return (New-WinForgeResult -Kind Failed -Detail "pede Administrador: abra o WinForge como Administrador e desfaça de novo")
    }

    switch ($kind) {
        "registry" {
            $file = [string](Get-WinForgeJsonValue -Object $undo -Name "File" -Default "")
            $values = [string](Get-WinForgeJsonValue -Object $undo -Name "Values" -Default "")

            if ([string]::IsNullOrWhiteSpace($file) -and [string]::IsNullOrWhiteSpace($values)) {
                return (New-WinForgeResult -Kind Failed -Detail "o backup do registro não foi encontrado")
            }

            foreach ($backup in @(@{ Path = $file; Extension = ".reg" }, @{ Path = $values; Extension = ".json" })) {
                # Um arquivo que não existe mais não é lido (vira um problema logo abaixo, só na parte dele).
                if ([string]::IsNullOrWhiteSpace($backup.Path) -or -not (Test-Path -LiteralPath $backup.Path)) { continue }

                # Um caminho fora da pasta de backups do WinForge recusa o desfazer inteiro: o diário pode ter sido mexido.
                if (-not (Test-WinForgeRegistryBackupFile -Path $backup.Path -Extension $backup.Extension)) {
                    return (New-WinForgeResult -Kind Failed -Detail "o backup do registro não está na pasta de backups do WinForge e não foi usado")
                }
            }

            if ($file -and (Test-Path -LiteralPath $file -PathType Leaf) -and -not (Test-WinForgeRegistryBackupKeys -Path $file)) {
                return (New-WinForgeResult -Kind Failed -Detail "o backup do registro mexe em chaves que a limpeza não toca e não foi usado")
            }

            # As duas partes rodam sempre, cada uma por si: um arquivo que sumiu ou estragou (um corte de energia no meio
            # da gravação) não impede a outra parte de voltar. Com qualquer falha, o desfazer não é dado como feito e
            # continua na lista: repetir é seguro (o .reg volta igual e só os valores que ainda faltam são recriados).
            $kept = 0
            $done = 0
            $problems = @()
            $gone = @()
            $admin = Test-WinForgeAdministrator

            if ($values) {
                if (-not (Test-Path -LiteralPath $values -PathType Leaf)) {
                    $gone += "os valores"
                }
                else {
                    try {
                        $restore = Restore-WinForgeRegistryValues -Path $values
                        $kept = [int]$restore.Kept
                        $done++

                        if (@($restore.Failed).Count -gt 0) {
                            $total = @($restore.Failed).Count + [int]$restore.Restored + $kept
                            $problems += "$(@($restore.Failed).Count) de $total valores não voltaram ($(Join-WinForgeList -Items @($restore.Failed)))"
                        }
                    }
                    catch {
                        $problems += "o backup dos valores não pôde ser lido ($(([string]$_.Exception.Message).TrimEnd('.')))"
                    }
                }
            }

            if ($file) {
                if (-not (Test-Path -LiteralPath $file -PathType Leaf)) {
                    $gone += "as chaves"
                }
                else {
                    $run = Invoke-WinForgeCapture -FilePath "reg" -Arguments @("import", $file)

                    if ($run.ExitCode -ne 0) {
                        $problems += $(if ($admin) { "o reg import terminou com o código $($run.ExitCode)" } else { "as chaves do backup não voltaram" })
                    }
                    else {
                        $done++
                    }
                }
            }

            # Um backup que não existe mais não volta tentando de novo: sem nenhuma parte restaurada, é falha; com a outra
            # parte de volta, a mudança é dada como desfeita, com o aviso do que não tinha como voltar.
            $goneText = $(if ($gone.Count -gt 0) { "o backup d$(if ($gone.Count -eq 2) { 'o registro' } elseif ($gone[0] -eq 'os valores') { 'os valores' } else { 'as chaves' }) não existe mais" } else { "" })

            if ($problems.Count -gt 0 -or $done -eq 0) {
                $all = @($problems) + @($(if ($goneText) { $goneText }))
                $detail = (Join-WinForgeList -Items $all) + $(if ($problems.Count -gt 0 -and -not $admin) { "; abra o WinForge como Administrador e tente de novo" } else { "" })
                return (New-WinForgeResult -Kind $(if ($done -gt 0) { "Warning" } else { "Failed" }) -Detail $detail)
            }

            # Um valor que já existe de novo (o programa voltou a gravá-lo) fica como está, com o dado de hoje.
            $detail = $(if ($kept -gt 0) { "entradas do registro devolvidas; $(Format-WinForgeCount -Count $kept -One 'valor já existia de novo e ficou' -Many 'valores já existiam de novo e ficaram') como está" } else { "entradas do registro devolvidas" })
            if ($goneText) { $detail += "; $goneText, então $($gone[0]) não têm como voltar" }

            return (New-WinForgeResult -Kind Ok -Detail $detail)
        }
        "startup" {
            $failed = 0
            $reason = ""
            $items = @(Get-WinForgeJsonValue -Object $undo -Name "Items" -Default @())
            $tasks = $null

            foreach ($item in $items) {
                try {
                    if ($null -eq $tasks -and [string](Get-WinForgeJsonValue -Object $item -Name "Source" -Default "") -eq "Tarefa agendada") {
                        $tasks = @(Get-WinForgeStartupTasks)
                    }

                    if (-not (Test-WinForgeStartupUndoItem -Item $item -Tasks $tasks)) {
                        throw "item de inicialização desconhecido"
                    }

                    Set-WinForgeStartupItemEnabled -Item $item -Enabled ([bool](Get-WinForgeJsonValue -Object $item -Name "Enabled" -Default $true))
                }
                catch {
                    $failed++

                    # O primeiro motivo vai junto (por exemplo, o item de todos os usuários que exige Administrador): sem
                    # ele, a pessoa não sabe o que fazer para desfazer.
                    if (-not $reason) { $reason = ([string]$_.Exception.Message).TrimEnd('.') }
                }
            }

            if ($failed -gt 0) {
                $what = $(if ($items.Count -eq 1) { "o item não voltou ao estado anterior" } elseif ($failed -eq 1) { "1 de $($items.Count) itens não voltou ao estado anterior" } else { "$failed de $($items.Count) itens não voltaram ao estado anterior" })
                return (New-WinForgeResult -Kind $(if ($failed -lt $items.Count) { "Warning" } else { "Failed" }) -Detail $(if ($reason) { "${what}: $reason" } else { $what }))
            }

            return (New-WinForgeResult -Kind Ok -Detail "inicialização como estava antes")
        }
        "tweak" {
            $tweak = Get-WinForgeTweakById -Id ([string](Get-WinForgeJsonValue -Object $undo -Name "Id" -Default ""))

            if ($null -eq $tweak) {
                return (New-WinForgeResult -Kind Failed -Detail "ajuste desconhecido")
            }

            # Com os valores originais guardados, o desfazer sempre os devolve: "não aplicado" pode ser parcial (uma atualização
            # do Windows voltou só um dos valores do ajuste), e "já estava desfeito" deixaria o resto como o WinForge pôs.
            $backup = Read-WinForgeTweakBackup -Status
            $saved = ($backup.Status -ne "Unreadable" -and $backup.Backup.Contains([string]$tweak.Id))

            if (-not $saved -and (Get-WinForgeTweakStatus -Tweak $tweak) -ne "Aplicado") {
                return (New-WinForgeResult -Kind Ok -Detail "o ajuste já estava desfeito")
            }

            try {
                $original = [bool](Invoke-WinForgeTweakRevert -Tweak $tweak)
            }
            catch {
                # Uma configuração que o Windows protege (UCPD): a mesma explicação de Ajustes do Windows, com onde desfazer.
                $help = Get-WinForgeTweakProtectedHelp -Tweak $tweak -Undo

                if ($null -ne $help -and (Test-WinForgeAccessDenied -Exception $_.Exception)) {
                    Write-WinForgeStatus -Type Warning -Message (Get-WinForgeTweakProtectedText -Help $help)
                    return (New-WinForgeResult -Kind Failed -Detail "o Windows protege esta configuração e não deixa o WinForge desfazê-la")
                }

                throw
            }

            return (New-WinForgeResult -Kind Ok -Detail $(if ($original) { "ajuste desfeito" } else { "ajuste desfeito com os padrões do Windows (os valores de antes não estavam guardados)" }))
        }
        "dns" {
            $read = Read-WinForgeDnsBackup -Status

            # Um backup que existe, mas não abriu agora (em uso, sem permissão), não é "nada a desfazer": fica para depois.
            if ($read.Status -eq "Unreadable") {
                return (New-WinForgeResult -Kind Failed -Detail "o backup do DNS de antes não pôde ser lido agora; tente de novo em instantes")
            }

            $backup = @($read.Entries)

            if ($backup.Count -eq 0) {
                return (New-WinForgeResult -Kind Ok -Detail "o DNS já estava como antes")
            }

            $undo = Restore-WinForgeDnsFromBackup -Backup $backup -Adapters @(Get-WinForgeDnsAdapters)
            $unknown = @(Get-WinForgeJsonValue -Object $undo -Name "Unknown" -Default @())

            if ($undo.Failed.Count -gt 0 -or $undo.Missing.Count -gt 0 -or $unknown.Count -gt 0) {
                return (New-WinForgeResult -Kind $(if ($undo.Restored -gt 0) { "Warning" } else { "Failed" }) -Detail "nem todos os adaptadores voltaram ao DNS de antes; use Rede > Desfazer a troca de DNS")
            }

            Remove-WinForgeDnsBackup
            Clear-DnsClientCache -ErrorAction SilentlyContinue

            # O backup guarda o DNS de antes da primeira troca: todas as trocas anotadas foram desfeitas de uma vez (como
            # em Rede > Desfazer a troca de DNS), e nenhuma fica na lista prometendo voltar a um DNS intermediário.
            Set-WinForgeChangesUndone -Kind "dns" -Key "Kind" -Value "dns"

            return (New-WinForgeResult -Kind Ok -Detail "DNS de antes da primeira troca restaurado")
        }
        "feature" {
            $name = [string](Get-WinForgeJsonValue -Object $undo -Name "Name" -Default "")
            $action = [string](Get-WinForgeJsonValue -Object $undo -Name "Action" -Default "")

            if ($action -notin @("Enable", "Disable")) {
                return (New-WinForgeResult -Kind Failed -Detail "mudança de recurso desconhecida")
            }

            # Só os recursos que a tela Recursos do Windows oferece: o nome vem do diário e não pode ligar qualquer recurso.
            if (@(Get-WinForgeFeatureCatalog | Where-Object { [string]$_.Name -eq $name }).Count -eq 0) {
                return (New-WinForgeResult -Kind Failed -Detail "recurso desconhecido")
            }

            $applied = Set-WinForgeOptionalFeature -Name $name -Action $action

            return (New-WinForgeResult -Kind Ok -Detail $(if ($action -eq "Enable") { "recurso ligado de novo" } else { "recurso desligado de novo" }) -Data @{ RebootRequired = [bool]$applied.RestartNeeded })
        }
    }

    return (New-WinForgeResult -Kind Failed -Detail "esta mudança não tem como ser desfeita")
}


# ---------------------------------------------------------------------------
# Tela
# ---------------------------------------------------------------------------

function Show-WinForgeChangeHistory {
    $title = "Histórico de mudanças"

    Enter-WinForgeAction -Title $title

    $final = New-WinForgeResult -Kind Ok -Title $title

    try {
        $read = Get-WinForgeChanges -Status
        $changes = @($read.Changes)

        # Um diário que existe, mas não abriu agora (preso por outro programa, sem permissão), não é "nada mudou": a
        # pessoa perderia de vista o que tem desfazer.
        if ($read.Status -eq "Unreadable") {
            Write-WinForgeStatus -Type Error -Message "Não foi possível ler o Histórico de mudanças agora (arquivo em uso ou sem permissão): tente de novo em instantes."
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Failed -Detail "não foi possível ler o histórico agora; tente de novo em instantes" -Title $title)
            return
        }

        # Só olhar o histórico não tem veredito: a tela termina sem a faixa de resultado (sem "Tudo certo" nem "Nada a
        # fazer"); a faixa fica para o que foi desfeito.
        if ($changes.Count -eq 0) {
            Write-WinForgeStatus -Type Info -Message "O WinForge ainda não mudou nada neste PC (ou o histórico foi apagado)."
            Exit-WinForgeAction
            return
        }

        # O desfazer vale para todas as mudanças guardadas: uma mudança antiga continua com o seu desfazer (a lista de
        # marcar mostra a data de cada uma). A lista de cima traz só as outras (sem volta por aqui, ou já desfeitas), para
        # nenhuma mudança aparecer duas vezes na tela.
        $undoable = @($changes | Where-Object { Test-WinForgeChangeUndoable -Change $_ })
        $others = @($changes | Where-Object { -not (Test-WinForgeChangeUndoable -Change $_) })
        $shown = @($others | Select-Object -First 30)

        if ($shown.Count -gt 0) {
            Write-WinForgeSection -Title $(if ($undoable.Count -gt 0) { "Mudanças sem desfazer por aqui" } else { "Últimas mudanças" })

            foreach ($change in $shown) {
                $suffix = $(if ($change.Undone) { " (desfeita)" } else { "" })
                Write-WinForgeKeyValue -Label (Format-WinForgeDateTime -When $change.At -Pattern "dd/MM HH:mm") -Value "$($change.Action): $($change.Text)$suffix" -LabelWidth 12
            }

            if ($others.Count -gt $shown.Count) {
                Write-WinForgeStatus -Type Info -Message "E mais $(Format-WinForgeCount -Count ($others.Count - $shown.Count) -One 'mudança mais antiga' -Many 'mudanças mais antigas')."
            }

            Write-Host ""
        }

        if ($undoable.Count -eq 0) {
            # Limpezas e desinstalações não têm volta.
            Write-WinForgeStatus -Type Info -Message "Nenhuma das mudanças anotadas pode ser desfeita por aqui; os ajustes saem em Ajustes do Windows > Desfazer ajustes do WinForge."
            Exit-WinForgeAction
            return
        }

        $options = @(
            foreach ($change in $undoable) {
                @{ Key = $change.Id; Label = "$($change.Action): $($change.Text)"; Description = (Format-WinForgeDateTime -When $change.At); Selected = $false }
            }
        )

        # Direto na lista: desfazer não apaga nada (volta ao que era), então marcar e confirmar basta, sem um Sim/Não a
        # mais. Cancelar (ou não marcar nada) é só ter olhado: a tela termina sem faixa de resultado.
        # Sem "marcar todos": desfazer tudo de uma vez, sem outra pergunta, inclui recursos do Windows e programas.
        $picked = Read-WinForgeMultiSelect -Message "O que desfazer?" -Options $options -NoSelectAll -ConfirmLabel "Desfazer"

        if ($null -eq $picked -or @($picked).Count -eq 0) {
            Write-WinForgeStatus -Type Info -Message "Nada foi desfeito."
            Exit-WinForgeAction
            return
        }

        $chosen = @($undoable | Where-Object { @($picked) -contains $_.Id })

        $results = @()
        $reboot = $false

        foreach ($change in $chosen) {
            try {
                $result = Undo-WinForgeChange -Change $change
            }
            catch {
                $result = New-WinForgeResult -Kind Failed -Detail $_.Exception.Message.TrimEnd('.')
            }

            $result.Etapa = "$($change.Action) de $(Format-WinForgeDateTime -When $change.At -Pattern 'dd/MM HH:mm')"

            if ($result.Kind -eq "Failed") {
                Write-WinForgeStatus -Type Error -Message "$($result.Etapa): $($result.Detail)."
            }
            elseif ($result.Kind -eq "Warning") {
                # Deu certo só em parte (um item da inicialização, um adaptador): a mudança continua na lista para tentar
                # de novo, o que é seguro (o que já voltou fica como está).
                Write-WinForgeStatus -Type Warning -Message "$($result.Etapa): $($result.Detail); a mudança continua na lista para tentar de novo."
            }
            else {
                Set-WinForgeChangeUndone -Id $change.Id
                [void](Add-WinForgeChange -Action "Desfeito" -Text "$($change.Action): $($change.Text)")
                Write-WinForgeStatus -Type Success -Message "$($result.Etapa): $($result.Detail)."
            }

            if (Test-WinForgeResultFlag -Result $result -Name "RebootRequired") { $reboot = $true }

            $results += $result
        }

        $failed = @($results | Where-Object { $_.Kind -eq "Failed" })
        # Desfeitas só em parte: não contam como desfeitas (continuam na lista), mas também não são falha completa.
        $partial = @($results | Where-Object { $_.Kind -eq "Warning" })
        $data = @{ RebootRequired = $reboot }

        if ($failed.Count -eq 0 -and $partial.Count -eq 0) {
            $final = New-WinForgeResult -Kind Ok -Detail (Format-WinForgeCount -Count $results.Count -One "mudança desfeita" -Many "mudanças desfeitas") -Title $title -Data $data
        }
        elseif ($failed.Count -eq $results.Count) {
            $final = New-WinForgeResult -Kind Failed -Detail $(if ($results.Count -eq 1) { $failed[0].Detail } else { "nenhuma mudança foi desfeita" }) -Title $title
        }
        elseif ($results.Count -eq 1) {
            $final = New-WinForgeResult -Kind Warning -Detail "$($partial[0].Detail); a mudança continua na lista para tentar de novo" -Title $title -Data $data
        }
        else {
            $final = New-WinForgeResult -Kind Warning -Detail "$($failed.Count + $partial.Count) de $($results.Count) não foram desfeitas por completo" -Title $title -Data $data
        }
    }
    catch {
        Write-WinForgeStatus -Type Error -Message "Não foi possível ler o histórico: $($_.Exception.Message)"
        $final = New-WinForgeResult -Kind Failed -Detail $_.Exception.Message -Title $title
    }

    Exit-WinForgeAction -Result $final
}


Export-ModuleMember -Function *
