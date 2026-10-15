# Ajustes do Windows orientados a dados: cada ajuste sabe se está aplicado (Test), guarda o valor original
# antes de mudar (Capture/Apply) e consegue desfazer (Revert), mesmo sem backup (valores padrão do Windows).
#
# Atenção: scriptblocks criados com GetNewClosure() não enxergam variáveis $script: deste módulo.
# Constantes usadas por eles ficam em funções (Get-WinForge...Guid) ou são capturadas em variáveis locais.

$script:WinForgeTweakCatalog = $null


function Get-WinForgeHighPerformancePlanGuid { return "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c" }
function Get-WinForgeBalancedPlanGuid { return "381b4222-f694-41f0-9685-ff5bb260df2e" }
function Get-WinForgeUltimatePerformancePlanGuid { return "e9a42b02-d5df-448d-aa00-03f14749eb61" }


# ---------------------------------------------------------------------------
# Avisos ao sistema (tema, tela de bloqueio)
# ---------------------------------------------------------------------------

function Send-WinForgeSettingChange {
    # Avisa janelas e o shell de que uma configuração do HKCU mudou. Falhar aqui não invalida o valor já gravado.
    param (
        [string]$Section = "ImmersiveColorSet"
    )

    try {
        if (-not ("WinForge.SettingsNative" -as [type])) {
            Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

namespace WinForge
{
    public static class SettingsNative
    {
        [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
        public static extern IntPtr SendMessageTimeout(
            IntPtr hWnd,
            uint message,
            UIntPtr wParam,
            string lParam,
            uint flags,
            uint timeout,
            out UIntPtr result);
    }
}
"@
        }

        $result = [UIntPtr]::Zero

        [void][WinForge.SettingsNative]::SendMessageTimeout([IntPtr]0xffff, 0x001A, [UIntPtr]::Zero, $Section, 0x0002, 5000, [ref]$result)
    }
    catch {
        # Alguns aplicativos só adotam o novo estado quando são reabertos.
    }
}


# ---------------------------------------------------------------------------
# Energia (powercfg). A leitura usa os valores hexadecimais do final da saída, que não dependem do idioma.
# ---------------------------------------------------------------------------

function Invoke-WinForgePowercfg {
    # Executa o powercfg sem mostrar a saída; falha com o texto do próprio comando.
    param (
        [Parameter(Mandatory)]
        [string[]]$Arguments
    )

    $run = Invoke-WinForgeCapture -FilePath "powercfg.exe" -Arguments $Arguments

    if ($run.ExitCode -ne 0) {
        throw "powercfg $($Arguments -join ' ') falhou (código $($run.ExitCode)): $($run.Text.Trim())"
    }

    return $run
}


function ConvertFrom-WinForgePowerQuery {
    param (
        [string[]]$Lines
    )

    $hexValues = @()

    foreach ($line in @($Lines)) {
        foreach ($match in [regex]::Matches([string]$line, "0x[0-9a-fA-F]{8}")) {
            $hexValues += [Convert]::ToInt64($match.Value.Substring(2), 16)
        }
    }

    if ($hexValues.Count -lt 2) {
        return $null
    }

    # As duas últimas linhas da consulta são o índice atual em CA (tomada) e CC (bateria).
    return [PSCustomObject]@{
        AC = [int64]$hexValues[$hexValues.Count - 2]
        DC = [int64]$hexValues[$hexValues.Count - 1]
    }
}


function Get-WinForgeActivePowerSchemeGuid {
    try {
        $run = Invoke-WinForgeCapture -FilePath "powercfg.exe" -Arguments @("/getactivescheme")
        $match = [regex]::Match($run.Text, "[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}")

        if ($match.Success) {
            return $match.Value.ToLowerInvariant()
        }
    }
    catch {
        # Sem informação de plano ativo.
    }

    return $null
}


function Test-WinForgePowerSchemeExists {
    param (
        [string]$Guid
    )

    if ([string]::IsNullOrWhiteSpace($Guid)) {
        return $false
    }

    try {
        $run = Invoke-WinForgeCapture -FilePath "powercfg.exe" -Arguments @("/list")
        return ($run.Text -match [regex]::Escape($Guid))
    }
    catch {
        return $false
    }
}


function Get-WinForgePowerSetting {
    param (
        [string]$Subgroup,
        [string]$Setting,
        [string]$Scheme = "SCHEME_CURRENT"
    )

    try {
        $run = Invoke-WinForgeCapture -FilePath "powercfg.exe" -Arguments @("/query", $Scheme, $Subgroup, $Setting)

        if ($run.ExitCode -ne 0) {
            return $null
        }

        return (ConvertFrom-WinForgePowerQuery -Lines $run.Lines)
    }
    catch {
        return $null
    }
}


function Set-WinForgePowerSetting {
    param (
        [string]$Subgroup,
        [string]$Setting,
        [int64]$AC,
        [int64]$DC,
        [string]$Scheme = "SCHEME_CURRENT"
    )

    [void](Invoke-WinForgePowercfg -Arguments @("/setacvalueindex", $Scheme, $Subgroup, $Setting, [string]$AC))
    [void](Invoke-WinForgePowercfg -Arguments @("/setdcvalueindex", $Scheme, $Subgroup, $Setting, [string]$DC))
}


function Update-WinForgeActivePowerScheme {
    # Reaplica o plano ativo para que os novos índices valham imediatamente.
    $guid = Get-WinForgeActivePowerSchemeGuid

    if ([string]::IsNullOrWhiteSpace($guid)) {
        $guid = "SCHEME_CURRENT"
    }

    [void](Invoke-WinForgePowercfg -Arguments @("/setactive", $guid))
}


# ---------------------------------------------------------------------------
# Backup dos valores originais (JSON em %LOCALAPPDATA%\WinForge)
# ---------------------------------------------------------------------------

function Get-WinForgeTweakBackupPath {
    return (Join-Path (Get-WinForgeDataPath) "tweak-backup.json")
}


function Read-WinForgeTweakBackup {
    $path = Get-WinForgeTweakBackupPath

    if (-not (Test-Path -LiteralPath $path)) {
        return [ordered]@{}
    }

    try {
        $raw = Get-Content -LiteralPath $path -Raw -Encoding UTF8

        if ([string]::IsNullOrWhiteSpace($raw)) {
            return [ordered]@{}
        }

        $parsed = $raw | ConvertFrom-Json

        # JSON válido mas que não é um objeto (por exemplo "[]" ou "abc") não é um backup nosso.
        if ($parsed -isnot [System.Management.Automation.PSCustomObject]) {
            throw "Formato de backup inesperado."
        }

        $result = [ordered]@{}

        foreach ($property in $parsed.PSObject.Properties) {
            $result[$property.Name] = $property.Value
        }

        return $result
    }
    catch {
        # Arquivo corrompido: guarda uma cópia para análise em vez de sobrescrevê-lo em silêncio no próximo salvamento.
        try {
            $corruptPath = "$path.corrupt-$((Get-Date).ToString('yyyyMMdd-HHmmss'))"
            Move-Item -LiteralPath $path -Destination $corruptPath -Force -ErrorAction Stop
            Write-WinForgeStatus -Type Warning -Message "O backup de ajustes estava corrompido e foi movido para: $corruptPath"
        }
        catch {
            # Sem permissão para mover: segue com um backup vazio.
        }

        return [ordered]@{}
    }
}


function Save-WinForgeTweakBackup {
    param (
        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Backup
    )

    $path = Get-WinForgeTweakBackupPath
    $temporaryPath = "$path.tmp"

    if ($Backup.Count -eq 0) {
        if (Test-Path -LiteralPath $path) {
            Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
        }

        return
    }

    # Grava em um arquivo temporário e troca: uma falha no meio não deixa o backup truncado.
    $json = $Backup | ConvertTo-Json -Depth 8
    Set-Content -LiteralPath $temporaryPath -Value $json -Encoding UTF8
    Move-Item -LiteralPath $temporaryPath -Destination $path -Force
}


# ---------------------------------------------------------------------------
# Construção do catálogo
# ---------------------------------------------------------------------------

function New-WinForgeTweak {
    param (
        [Parameter(Mandatory)][string]$Id,
        [Parameter(Mandatory)][string]$Category,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Description,
        [Parameter(Mandatory)][scriptblock]$Capture,
        [Parameter(Mandatory)][scriptblock]$Apply,
        [Parameter(Mandatory)][scriptblock]$Revert,
        [Parameter(Mandatory)][scriptblock]$Test,
        [switch]$Recommended,
        [switch]$LaptopRisk,
        [switch]$RequiresAdmin,
        [switch]$UserScope,
        [switch]$RestartExplorer,
        [switch]$Windows11Only,
        [string]$Warning = "",

        # Alterações de registro (Path, Name, Value, Default) quando o ajuste é só isso; vazio nos demais.
        [object[]]$Changes = @()
    )

    return [PSCustomObject]@{
        PSTypeName      = "WinForge.Tweak"
        Id              = $Id
        Category        = $Category
        Name            = $Name
        Description     = $Description
        Recommended     = [bool]$Recommended
        LaptopRisk      = [bool]$LaptopRisk
        RequiresAdmin   = [bool]$RequiresAdmin
        UserScope       = [bool]$UserScope
        RestartExplorer = [bool]$RestartExplorer
        Windows11Only   = [bool]$Windows11Only
        Warning         = $Warning
        Changes         = @($Changes)
        Capture         = $Capture
        Apply           = $Apply
        Revert          = $Revert
        Test            = $Test
    }
}


function New-WinForgeRegistryTweak {
    <#
    Ajuste feito só de valores DWORD. Changes: hashtables com Path, Name, Value e, opcionalmente, Default
    (valor do Windows usado ao desfazer sem backup; sem Default o valor é removido).
    #>
    param (
        [Parameter(Mandatory)][string]$Id,
        [Parameter(Mandatory)][string]$Category,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Description,
        [Parameter(Mandatory)][object[]]$Changes,
        [switch]$Recommended,
        [switch]$RestartExplorer,
        [switch]$Windows11Only,
        [scriptblock]$AfterChange = $null
    )

    $changeList = @($Changes)
    $after = $AfterChange

    $capture = {
        $snapshot = @()

        foreach ($change in $changeList) {
            $snapshot += [ordered]@{
                Path  = $change.Path
                Name  = $change.Name
                Value = (Get-WinForgeRegistryValueOrNull -Path $change.Path -Name $change.Name)
            }
        }

        return $snapshot
    }.GetNewClosure()

    $apply = {
        foreach ($change in $changeList) {
            Set-WinForgeRegistryDWord -Path $change.Path -Name $change.Name -Value ([int]$change.Value)
        }

        if ($null -ne $after) {
            & $after
        }
    }.GetNewClosure()

    $revert = {
        param($Saved)

        $entries = @($Saved | Where-Object { $null -ne $_ })

        if ($entries.Count -gt 0) {
            foreach ($entry in $entries) {
                if ($null -eq $entry.Value) {
                    Remove-WinForgeRegistryValue -Path $entry.Path -Name $entry.Name
                }
                else {
                    Set-WinForgeRegistryDWord -Path $entry.Path -Name $entry.Name -Value ([int]$entry.Value)
                }
            }
        }
        else {
            # Sem backup (ajuste feito fora do WinForge): volta ao padrão do Windows.
            foreach ($change in $changeList) {
                if ($null -eq $change.Default) {
                    Remove-WinForgeRegistryValue -Path $change.Path -Name $change.Name
                }
                else {
                    Set-WinForgeRegistryDWord -Path $change.Path -Name $change.Name -Value ([int]$change.Default)
                }
            }
        }

        if ($null -ne $after) {
            & $after
        }
    }.GetNewClosure()

    $test = {
        try {
            foreach ($change in $changeList) {
                $current = Get-WinForgeRegistryValueOrNull -Path $change.Path -Name $change.Name

                if ($null -eq $current -or [int]$current -ne [int]$change.Value) {
                    return $false
                }
            }

            return $true
        }
        catch {
            return $false
        }
    }.GetNewClosure()

    $requiresAdmin = (@($changeList | Where-Object { $_.Path -like "HKLM:*" }).Count -gt 0)
    $userScope = (@($changeList | Where-Object { $_.Path -like "HKCU:*" }).Count -gt 0)

    return (New-WinForgeTweak -Id $Id -Category $Category -Name $Name -Description $Description `
            -Capture $capture -Apply $apply -Revert $revert -Test $test `
            -Recommended:$Recommended -RestartExplorer:$RestartExplorer -Windows11Only:$Windows11Only `
            -RequiresAdmin:$requiresAdmin -UserScope:$userScope -Changes $changeList)
}


function Get-WinForgeTweakCategories {
    # Ordem de exibição: do que o usuário mais vê para o que mexe no hardware.
    return @("Explorador", "Aparência", "Privacidade e sugestões", "Jogos", "Energia e desempenho")
}


function Get-WinForgeTweakCatalog {
    if ($null -ne $script:WinForgeTweakCatalog) {
        return $script:WinForgeTweakCatalog
    }

    $advanced = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    $personalize = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
    $content = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
    $power = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power"

    $catalog = @()

    # --- Explorador ----------------------------------------------------------
    $catalog += New-WinForgeRegistryTweak -Id "file-extensions" -Category "Explorador" -Name "Mostrar extensões de arquivos" `
        -Description "Exibe .exe, .pdf, .png etc. no Explorador (ajuda a perceber arquivos disfarçados)." -Recommended -RestartExplorer `
        -Changes @(@{ Path = $advanced; Name = "HideFileExt"; Value = 0; Default = 1 })

    $catalog += New-WinForgeRegistryTweak -Id "hidden-files" -Category "Explorador" -Name "Mostrar arquivos e pastas ocultos" `
        -Description "Arquivos protegidos do sistema continuam ocultos." -RestartExplorer `
        -Changes @(@{ Path = $advanced; Name = "Hidden"; Value = 1; Default = 2 })

    $catalog += New-WinForgeRegistryTweak -Id "taskbar-left" -Category "Explorador" -Name "Barra de tarefas alinhada à esquerda" `
        -Description "Move o menu Iniciar e os ícones para a esquerda (somente Windows 11)." -RestartExplorer -Windows11Only `
        -Changes @(@{ Path = $advanced; Name = "TaskbarAl"; Value = 0; Default = 1 })

    # --- Aparência -----------------------------------------------------------
    $catalog += New-WinForgeRegistryTweak -Id "dark-mode" -Category "Aparência" -Name "Modo escuro" `
        -Description "Tema escuro para o Windows e para os aplicativos. Alguns programas precisam ser reabertos." `
        -Changes @(
            @{ Path = $personalize; Name = "AppsUseLightTheme"; Value = 0; Default = 1 },
            @{ Path = $personalize; Name = "SystemUsesLightTheme"; Value = 0; Default = 1 }
        ) `
        -AfterChange { Send-WinForgeSettingChange -Section "ImmersiveColorSet" }

    $catalog += New-WinForgeRegistryTweak -Id "no-transparency" -Category "Aparência" -Name "Desativar efeitos de transparência" `
        -Description "Menus e janelas sem transparência; pode melhorar a fluidez em PCs modestos." `
        -Changes @(@{ Path = $personalize; Name = "EnableTransparency"; Value = 0; Default = 1 }) `
        -AfterChange { Send-WinForgeSettingChange -Section "ImmersiveColorSet" }

    # --- Privacidade e sugestões --------------------------------------------
    $catalog += New-WinForgeRegistryTweak -Id "tips-suggestions" -Category "Privacidade e sugestões" -Name "Desativar dicas e sugestões do Windows" `
        -Description "Remove sugestões e telas de configuração sugerida." -Recommended `
        -Changes @(
            @{ Path = $content; Name = "SoftLandingEnabled"; Value = 0; Default = 1 },
            @{ Path = $content; Name = "SystemPaneSuggestionsEnabled"; Value = 0; Default = 1 },
            @{ Path = $content; Name = "SubscribedContent-338389Enabled"; Value = 0; Default = 1 },
            @{ Path = $content; Name = "SubscribedContent-353698Enabled"; Value = 0; Default = 1 },
            @{ Path = $content; Name = "SubscribedContent-310093Enabled"; Value = 0; Default = 1 },
            @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement"; Name = "ScoobeSystemSettingEnabled"; Value = 0; Default = 1 }
        )

    $catalog += New-WinForgeRegistryTweak -Id "lock-screen-tips" -Category "Privacidade e sugestões" -Name "Desativar dicas da tela de bloqueio" `
        -Description "Remove as dicas e curiosidades exibidas sobre a imagem da tela de bloqueio." `
        -Changes @(
            @{ Path = $content; Name = "RotatingLockScreenOverlayEnabled"; Value = 0; Default = 1 },
            @{ Path = $content; Name = "SubscribedContent-338387Enabled"; Value = 0; Default = 1 }
        ) `
        -AfterChange { Send-WinForgeSettingChange -Section "ContentDeliveryManager" }

    # --- Jogos ---------------------------------------------------------------
    $catalog += New-WinForgeRegistryTweak -Id "game-bar" -Category "Jogos" -Name "Desativar Xbox Game Bar e Game DVR" `
        -Description "Menos overlays e captura em segundo plano." -Recommended `
        -Changes @(
            @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR"; Name = "AppCaptureEnabled"; Value = 0; Default = 1 },
            @{ Path = "HKCU:\System\GameConfigStore"; Name = "GameDVR_Enabled"; Value = 0; Default = 1 },
            @{ Path = "HKCU:\Software\Microsoft\GameBar"; Name = "ShowStartupPanel"; Value = 0; Default = 1 },
            @{ Path = "HKCU:\Software\Microsoft\GameBar"; Name = "UseNexusForGameBarEnabled"; Value = 0; Default = 1 },
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR"; Name = "AllowGameDVR"; Value = 0 }
        ) `
        -AfterChange {
            Get-Process -Name "GameBar", "GameBarFTServer", "GameBarPresenceWriter" -ErrorAction SilentlyContinue |
                Stop-Process -Force -ErrorAction SilentlyContinue
        }

    # --- Energia e desempenho (a ordem importa: o plano vem antes dos ajustes feitos nele) --------------------
    $catalog += New-WinForgeRegistryTweak -Id "fast-startup" -Category "Energia e desempenho" -Name "Desativar Inicialização Rápida" `
        -Description "Evita problemas de driver e desligamento incompleto; o desligamento passa a ser completo." -Recommended `
        -Changes @(@{ Path = $power; Name = "HiberbootEnabled"; Value = 0; Default = 1 })

    $catalog += New-WinForgeTweak -Id "high-performance" -Category "Energia e desempenho" -Name "Plano de energia Alto desempenho" `
        -Description "Prioriza desempenho; em notebook reduz a autonomia." -Recommended -LaptopRisk -RequiresAdmin `
        -Warning "Em notebook, consome mais bateria e esquenta mais." `
        -Capture { return [ordered]@{ SchemeGuid = (Get-WinForgeActivePowerSchemeGuid) } } `
        -Apply { [void](Set-WinForgeHighPerformancePowerPlan -ThrowOnFailure) } `
        -Revert {
            param($Saved)

            # Volta ao plano que estava ativo antes; se ele não existe mais, usa o Equilibrado.
            $target = Get-WinForgeBalancedPlanGuid

            if ($null -ne $Saved -and -not [string]::IsNullOrWhiteSpace([string]$Saved.SchemeGuid) -and (Test-WinForgePowerSchemeExists -Guid ([string]$Saved.SchemeGuid))) {
                $target = [string]$Saved.SchemeGuid
            }

            [void](Invoke-WinForgePowercfg -Arguments @("/setactive", $target))
        } `
        -Test {
            $active = Get-WinForgeActivePowerSchemeGuid

            if ($active -eq (Get-WinForgeHighPerformancePlanGuid) -or $active -eq (Get-WinForgeUltimatePerformancePlanGuid)) {
                return $true
            }

            # Planos duplicados têm outro GUID; o nome (localizado) é a segunda checagem.
            $name = (Invoke-WinForgeCapture -FilePath "powercfg.exe" -Arguments @("/getactivescheme")).Text
            return [bool]($name -match "(?i)alto desempenho|high performance|desempenho m[aá]ximo|ultimate")
        }

    $catalog += New-WinForgeTweak -Id "pcie-aspm" -Category "Energia e desempenho" -Name "Desativar economia de energia PCI Express" `
        -Description "Útil em instabilidade de GPU/PCIe; aumenta o consumo." -Recommended -LaptopRisk -RequiresAdmin `
        -Warning "Em notebook, aumenta o consumo em repouso." `
        -Capture {
            $guid = Get-WinForgeActivePowerSchemeGuid
            $setting = Get-WinForgePowerSetting -Subgroup "SUB_PCIEXPRESS" -Setting "ASPM"

            return [ordered]@{
                SchemeGuid = $guid
                AC         = $(if ($setting) { $setting.AC } else { $null })
                DC         = $(if ($setting) { $setting.DC } else { $null })
            }
        } `
        -Apply {
            Set-WinForgePowerSetting -Subgroup "SUB_PCIEXPRESS" -Setting "ASPM" -AC 0 -DC 0
            Update-WinForgeActivePowerScheme
        } `
        -Revert {
            param($Saved)

            # Padrão do Windows: economia moderada (1). O plano é o mesmo em que o ajuste foi feito, se ainda existir.
            $ac = if ($null -ne $Saved -and $null -ne $Saved.AC) { [int64]$Saved.AC } else { 1 }
            $dc = if ($null -ne $Saved -and $null -ne $Saved.DC) { [int64]$Saved.DC } else { 1 }
            $scheme = "SCHEME_CURRENT"

            if ($null -ne $Saved -and (Test-WinForgePowerSchemeExists -Guid ([string]$Saved.SchemeGuid))) {
                $scheme = [string]$Saved.SchemeGuid
            }

            Set-WinForgePowerSetting -Subgroup "SUB_PCIEXPRESS" -Setting "ASPM" -AC $ac -DC $dc -Scheme $scheme
            Update-WinForgeActivePowerScheme
        } `
        -Test {
            $setting = Get-WinForgePowerSetting -Subgroup "SUB_PCIEXPRESS" -Setting "ASPM"
            return ($null -ne $setting -and $setting.AC -eq 0 -and $setting.DC -eq 0)
        }

    # Tempos em segundos. Default* são os padrões do Windows, usados ao desfazer sem backup.
    $timeoutSettings = @(
        @{ Subgroup = "SUB_VIDEO"; Setting = "VIDEOIDLE"; Key = "Monitor"; DefaultAC = 600; DefaultDC = 300 },
        @{ Subgroup = "SUB_SLEEP"; Setting = "STANDBYIDLE"; Key = "Standby"; DefaultAC = 1800; DefaultDC = 900 },
        @{ Subgroup = "SUB_SLEEP"; Setting = "HIBERNATEIDLE"; Key = "Hibernate"; DefaultAC = 10800; DefaultDC = 10800 }
    )

    $sleepCapture = {
        $snapshot = [ordered]@{ SchemeGuid = (Get-WinForgeActivePowerSchemeGuid) }

        foreach ($item in $timeoutSettings) {
            $setting = Get-WinForgePowerSetting -Subgroup $item.Subgroup -Setting $item.Setting
            $snapshot[$item.Key] = [ordered]@{
                AC = $(if ($setting) { $setting.AC } else { $null })
                DC = $(if ($setting) { $setting.DC } else { $null })
            }
        }

        return $snapshot
    }.GetNewClosure()

    $sleepApply = {
        foreach ($item in $timeoutSettings) {
            Set-WinForgePowerSetting -Subgroup $item.Subgroup -Setting $item.Setting -AC 0 -DC 0
        }

        Update-WinForgeActivePowerScheme
    }.GetNewClosure()

    $sleepRevert = {
        param($Saved)

        $scheme = "SCHEME_CURRENT"

        if ($null -ne $Saved -and (Test-WinForgePowerSchemeExists -Guid ([string]$Saved.SchemeGuid))) {
            $scheme = [string]$Saved.SchemeGuid
        }

        foreach ($item in $timeoutSettings) {
            $entry = $null

            if ($null -ne $Saved) { $entry = $Saved.($item.Key) }

            if ($null -ne $entry -and $null -ne $entry.AC -and $null -ne $entry.DC) {
                $ac = [int64]$entry.AC
                $dc = [int64]$entry.DC
            }
            else {
                $ac = [int64]$item.DefaultAC
                $dc = [int64]$item.DefaultDC
            }

            Set-WinForgePowerSetting -Subgroup $item.Subgroup -Setting $item.Setting -AC $ac -DC $dc -Scheme $scheme
        }

        Update-WinForgeActivePowerScheme
    }.GetNewClosure()

    $sleepTest = {
        foreach ($item in $timeoutSettings) {
            $setting = Get-WinForgePowerSetting -Subgroup $item.Subgroup -Setting $item.Setting

            if ($null -eq $setting -or $setting.AC -ne 0 -or $setting.DC -ne 0) {
                return $false
            }
        }

        return $true
    }.GetNewClosure()

    $catalog += New-WinForgeTweak -Id "no-sleep-timeouts" -Category "Energia e desempenho" -Name "Nunca desligar a tela nem suspender" `
        -Description "Tela, suspensão e hibernação automática em Nunca (tomada e bateria)." -Recommended -LaptopRisk -RequiresAdmin `
        -Warning "Em notebook, a tela fica ligada na bateria até você fechar a tampa ou desligar." `
        -Capture $sleepCapture -Apply $sleepApply -Revert $sleepRevert -Test $sleepTest

    $catalog += New-WinForgeTweak -Id "hibernation" -Category "Energia e desempenho" -Name "Desativar hibernação (remove hiberfil.sys)" `
        -Description "Libera espaço em disco; também desativa a Inicialização Rápida." -Recommended -LaptopRisk -RequiresAdmin `
        -Warning "Em notebook, você perde a hibernação (útil quando a bateria acaba)." `
        -Capture {
            return [ordered]@{
                Enabled = (Get-WinForgeRegistryValueOrNull -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Power" -Name "HibernateEnabled")
            }
        } `
        -Apply { [void](Invoke-WinForgePowercfg -Arguments @("/hibernate", "off")) } `
        -Revert {
            param($Saved)

            # Só deixa desligada se a hibernação já estava desligada antes do WinForge; sem informação, liga (padrão).
            if ($null -eq $Saved -or $null -eq $Saved.Enabled -or [int]$Saved.Enabled -ne 0) {
                [void](Invoke-WinForgePowercfg -Arguments @("/hibernate", "on"))
            }
        } `
        -Test {
            $value = Get-WinForgeRegistryValueOrNull -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Power" -Name "HibernateEnabled"
            return ($null -ne $value -and [int]$value -eq 0)
        }

    $script:WinForgeTweakCatalog = @($catalog)
    return $script:WinForgeTweakCatalog
}


function Get-WinForgeTweakById {
    param (
        [string]$Id
    )

    return (Get-WinForgeTweakCatalog | Where-Object { $_.Id -eq $Id } | Select-Object -First 1)
}


function Test-WinForgeTweakAvailable {
    param (
        [Parameter(Mandatory)]
        $Tweak
    )

    return -not ($Tweak.Windows11Only -and -not (Test-WinForgeWindows11))
}


function Get-WinForgeTweakStatus {
    param (
        [Parameter(Mandatory)]
        $Tweak
    )

    try {
        if (& $Tweak.Test) { return "Aplicado" }
        return "Padrão"
    }
    catch {
        return "Desconhecido"
    }
}


function Get-WinForgeTweakSwitchState {
    # Como a janela desenha a chave liga/desliga de um ajuste. IsOn = ajuste aplicado. "Desconhecido" aparece desligada
    # e com aviso: ligar a chave aplica o ajuste, como em "Padrão". Level = Ok | Warn | Muted (a janela escolhe a cor).
    param (
        [string]$Status
    )

    switch ($Status) {
        "Aplicado"     { return [PSCustomObject]@{ IsOn = $true;  Caption = "Aplicado";         Level = "Ok" } }
        "Desconhecido" { return [PSCustomObject]@{ IsOn = $false; Caption = "Não identificado"; Level = "Warn" } }
        default        { return [PSCustomObject]@{ IsOn = $false; Caption = "Padrão";           Level = "Muted" } }
    }
}


function Get-WinForgeTweakOverview {
    # Lista os ajustes disponíveis neste Windows, agrupados na ordem de exibição, com o estado atual.
    $session = Get-WinForgeSessionInfo
    $categories = @(Get-WinForgeTweakCategories)
    $catalog = @(Get-WinForgeTweakCatalog | Where-Object { Test-WinForgeTweakAvailable -Tweak $_ })

    return @(
        foreach ($category in $categories) {
            foreach ($tweak in @($catalog | Where-Object { $_.Category -eq $category })) {
                [PSCustomObject]@{
                    Id          = $tweak.Id
                    Category    = $tweak.Category
                    Name        = $tweak.Name
                    Description = $tweak.Description
                    Status      = (Get-WinForgeTweakStatus -Tweak $tweak)
                    LaptopNote  = $(if ($session.IsLaptop -and $tweak.LaptopRisk) { $tweak.Warning } else { "" })
                }
            }
        }
    )
}


# ---------------------------------------------------------------------------
# Aplicar e reverter
# ---------------------------------------------------------------------------

function Invoke-WinForgeTweakApply {
    param (
        [Parameter(Mandatory)]
        $Tweak
    )

    if (-not (Test-WinForgeTweakAvailable -Tweak $Tweak)) {
        throw "O ajuste '$($Tweak.Name)' não está disponível nesta versão do Windows."
    }

    if ($Tweak.RequiresAdmin -and -not (Test-WinForgeAdministrator)) {
        throw "O ajuste '$($Tweak.Name)' exige privilégios de Administrador."
    }

    $backup = Read-WinForgeTweakBackup
    $previousEntry = $null
    $hadEntry = $backup.Contains($Tweak.Id)

    if ($hadEntry) {
        $previousEntry = $backup[$Tweak.Id]
    }

    # O backup guarda o estado de antes do WinForge. Se o ajuste já está aplicado, o estado atual não é o original:
    # o backup existente continua valendo e, sem backup, desfazer usará os padrões do Windows. Se não está aplicado
    # (por exemplo, o usuário desfez manualmente), o estado atual é o novo "original".
    $alreadyApplied = ((Get-WinForgeTweakStatus -Tweak $Tweak) -eq "Aplicado")
    $snapshot = $null

    if (-not $alreadyApplied) {
        $snapshot = & $Tweak.Capture

        $backup[$Tweak.Id] = [ordered]@{
            AppliedAt = (Get-Date).ToString("s")
            Original  = $snapshot
        }

        Save-WinForgeTweakBackup -Backup $backup
    }

    try {
        [void](& $Tweak.Apply)
    }
    catch {
        $failure = $_

        # Desfaz o que a tentativa mudou e não deixa um backup de algo que não foi aplicado.
        if ($null -ne $snapshot) {
            try { [void](& $Tweak.Revert $snapshot) } catch { }

            $backup = Read-WinForgeTweakBackup

            if ($hadEntry) {
                $backup[$Tweak.Id] = $previousEntry
            }
            elseif ($backup.Contains($Tweak.Id)) {
                $backup.Remove($Tweak.Id)
            }

            try { Save-WinForgeTweakBackup -Backup $backup } catch { }
        }

        throw $failure
    }
}


function Invoke-WinForgeTweakRevert {
    # Desfaz um ajuste. Devolve $true se havia backup e $false se foram usados os padrões do Windows.
    param (
        [Parameter(Mandatory)]
        $Tweak
    )

    if ($Tweak.RequiresAdmin -and -not (Test-WinForgeAdministrator)) {
        throw "O ajuste '$($Tweak.Name)' exige privilégios de Administrador."
    }

    $backup = Read-WinForgeTweakBackup
    $saved = $null
    $hasBackup = $backup.Contains($Tweak.Id)

    if ($hasBackup) {
        $saved = $backup[$Tweak.Id].Original
    }

    [void](& $Tweak.Revert $saved)

    if ($hasBackup) {
        $backup.Remove($Tweak.Id)
        Save-WinForgeTweakBackup -Backup $backup
    }

    return ($null -ne $saved)
}


function Invoke-WinForgeTweakSet {
    <#
    Aplica uma lista de ajustes (por Id), um a um, sem perguntar nada. Um ajuste que falha não interrompe os demais.
    Devolve um resumo com os resultados (WinForge.Result) e se o Explorador precisa ser reiniciado.
    #>
    param (
        [Parameter(Mandatory)]
        [string[]]$Ids
    )

    $results = @()
    $needsExplorerRestart = $false
    $position = 0

    foreach ($id in $Ids) {
        $position++
        $tweak = Get-WinForgeTweakById -Id $id

        if ($null -eq $tweak) {
            $unknown = New-WinForgeResult -Kind Failed -Detail "ajuste desconhecido" -Title $id
            $results += $unknown
            Write-WinForgeStatus -Type Error -Message "Ajuste desconhecido: $id"
            continue
        }

        Write-WinForgeProgress -Current ($position - 1) -Total $Ids.Count -Label $tweak.Name

        try {
            if ((Get-WinForgeTweakStatus -Tweak $tweak) -eq "Aplicado") {
                $skipped = New-WinForgeResult -Kind Skipped -Detail "já estava aplicado" -Title $tweak.Name
                $results += $skipped
                Write-WinForgeStatus -Type Info -Message "$($tweak.Name): já estava aplicado."
                continue
            }

            Invoke-WinForgeTweakApply -Tweak $tweak

            if ((Get-WinForgeTweakStatus -Tweak $tweak) -eq "Aplicado") {
                $results += (New-WinForgeResult -Kind Ok -Title $tweak.Name)
                Write-WinForgeStatus -Type Success -Message "$($tweak.Name): aplicado."

                if ($tweak.RestartExplorer) { $needsExplorerRestart = $true }
            }
            else {
                $results += (New-WinForgeResult -Kind Warning -Detail "o Windows não manteve o valor" -Title $tweak.Name)
                Write-WinForgeStatus -Type Warning -Message "$($tweak.Name): o valor foi gravado, mas o Windows não o manteve (política da organização?)."
            }
        }
        catch {
            $results += (New-WinForgeResult -Kind Failed -Detail $_.Exception.Message -Title $tweak.Name)
            Write-WinForgeStatus -Type Error -Message "$($tweak.Name): $($_.Exception.Message)"
        }
    }

    return [PSCustomObject]@{
        Results              = $results
        NeedsExplorerRestart = $needsExplorerRestart
    }
}


# ---------------------------------------------------------------------------
# Ponto de restauração
# ---------------------------------------------------------------------------

function Get-WinForgeRestorePointSequence {
    # Maior número de sequência entre os pontos existentes; 0 se não há nenhum; -1 se não foi possível consultar.
    try {
        $points = @(Get-ComputerRestorePoint -ErrorAction Stop)

        if ($points.Count -eq 0) {
            return 0
        }

        return [int](($points | Measure-Object -Property SequenceNumber -Maximum).Maximum)
    }
    catch {
        return -1
    }
}


function New-WinForgeRestorePoint {
    <#
    Cria um ponto de restauração e confere se ele realmente existe: o Checkpoint-Computer apenas emite um aviso
    (sem erro) quando já há um ponto criado nas últimas 24 horas. Devolve um WinForge.Result.
    #>
    param (
        [string]$Description = "WinForge - antes dos ajustes"
    )

    if (-not (Get-Command Checkpoint-Computer -ErrorAction SilentlyContinue)) {
        Write-WinForgeStatus -Type Warning -Message "Checkpoint-Computer não está disponível neste PowerShell. Use o Windows PowerShell 5.1."
        return (New-WinForgeResult -Kind Warning -Detail "indisponível neste PowerShell" -Title "Criar ponto de restauração")
    }

    $before = Get-WinForgeRestorePointSequence
    $checkpointWarning = $null

    try {
        Checkpoint-Computer -Description $Description -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop -WarningAction SilentlyContinue -WarningVariable checkpointWarning
    }
    catch {
        $message = $_.Exception.Message
        Write-WinForgeStatus -Type Warning -Message "Não foi possível criar o ponto de restauração: $message"

        if ($message -match "(?i)disabled|desativ|desabilit") {
            Write-Host "      A Proteção do Sistema está desativada nesta unidade." -ForegroundColor DarkGray
        }

        # NotCreated: quem chama pode oferecer ativar a Proteção do Sistema e tentar de novo.
        return (New-WinForgeResult -Kind Warning -Detail "não criado" -Title "Criar ponto de restauração" -Data @{ NotCreated = $true })
    }

    $after = Get-WinForgeRestorePointSequence
    $warningText = (@($checkpointWarning) | ForEach-Object { [string]$_ }) -join " "

    if ($before -ge 0 -and $after -gt $before) {
        Write-WinForgeStatus -Type Success -Message "Ponto de restauração criado."
        return (New-WinForgeResult -Kind Ok -Title "Criar ponto de restauração")
    }

    if (-not [string]::IsNullOrWhiteSpace($warningText) -or ($before -ge 0 -and $after -eq $before)) {
        Write-WinForgeStatus -Type Warning -Message "O Windows não criou um novo ponto de restauração."
        Write-Host "      Ele limita a criação a 1 ponto a cada 24 horas, então um ponto recente já deve existir." -ForegroundColor DarkGray

        if (-not [string]::IsNullOrWhiteSpace($warningText)) {
            Write-Host "      Aviso do Windows: $warningText" -ForegroundColor DarkGray
        }

        return (New-WinForgeResult -Kind Warning -Detail "já havia um ponto recente" -Title "Criar ponto de restauração")
    }

    # Não foi possível consultar a lista de pontos, mas o comando terminou sem erro nem aviso.
    Write-WinForgeStatus -Type Success -Message "Ponto de restauração solicitado."
    return (New-WinForgeResult -Kind Ok -Title "Criar ponto de restauração")
}


function Request-WinForgeRestorePoint {
    <#
    Cria o ponto de restauração e, se ele não pôde ser criado, oferece ativar a Proteção do Sistema e tentar de novo.
    Faz perguntas: use só quando há alguém presente (dentro da Manutenção recomendada, chame New-WinForgeRestorePoint).
    Devolve um WinForge.Result.
    #>
    $result = New-WinForgeRestorePoint

    if (-not (Test-WinForgeResultFlag -Result $result -Name "NotCreated")) {
        return $result
    }

    Write-Host ""

    if (Confirm-WinForgeAction "Deseja ativar a Proteção do Sistema na unidade do Windows e tentar novamente?" -DefaultKey N) {
        try {
            Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction Stop
            Write-WinForgeStatus -Type Success -Message "Proteção do Sistema ativada."
            $result = New-WinForgeRestorePoint
        }
        catch {
            Write-WinForgeStatus -Type Error -Message "Não foi possível ativar a Proteção do Sistema: $($_.Exception.Message)"
        }
    }

    return $result
}


function Invoke-WinForgeRestorePoint {
    param (
        [switch]$Embedded,
        [switch]$PassThru
    )

    $title = "Criar ponto de restauração"

    Enter-WinForgeAction -Title $title -Embedded:$Embedded

    $result = $null

    if (-not (Test-WinForgeElevation -Reason "Criar um ponto de restauração exige privilégios de Administrador.")) {
        $result = New-WinForgeResult -Kind Failed -Detail "requer Administrador" -Title $title
    }
    elseif ($Embedded) {
        $result = New-WinForgeRestorePoint
    }
    else {
        $result = Request-WinForgeRestorePoint
    }

    if ($PassThru) { $result }
    Exit-WinForgeAction -Embedded:$Embedded
}


# ---------------------------------------------------------------------------
# Fluxos para o usuário
# ---------------------------------------------------------------------------

function Select-WinForgeRecommendedTweaks {
    <#
    Pergunta quais dos ajustes recomendados aplicar. Os que gastam bateria vêm desmarcados em notebook.
    Devolve os Ids marcados (pode ser vazio) ou $null se o usuário cancelar.
    #>
    $session = Get-WinForgeSessionInfo

    $candidates = @(
        Get-WinForgeTweakCatalog |
            Where-Object { $_.Recommended -and (Test-WinForgeTweakAvailable -Tweak $_) -and (Get-WinForgeTweakStatus -Tweak $_) -ne "Aplicado" }
    )

    if ($candidates.Count -eq 0) {
        Write-WinForgeStatus -Type Success -Message "Todos os ajustes recomendados já estão aplicados."
        return @()
    }

    if ($session.IsLaptop) {
        Write-WinForgeStatus -Type Info -Message "Notebook detectado: os ajustes de energia que reduzem a bateria vêm desmarcados."
        Write-Host ""
    }

    $options = @(
        foreach ($tweak in $candidates) {
            $risky = ($session.IsLaptop -and $tweak.LaptopRisk)
            $note = $tweak.Description

            if ($risky) { $note = "$($tweak.Description)  [notebook: $($tweak.Warning)]" }

            @{ Key = $tweak.Id; Label = $tweak.Name; Description = $note; Selected = (-not $risky) }
        }
    )

    $picked = Read-WinForgeMultiSelect -Message "Escolha os ajustes recomendados que deseja aplicar" -Options $options

    if ($null -eq $picked) {
        return $null
    }

    return @($picked)
}


function Invoke-WinForgeRecommendedTweaks {
    <#
    Aplica ajustes recomendados. Sozinha, pergunta quais, oferece o ponto de restauração e pergunta sobre o Explorador.
    Dentro da Manutenção recomendada (-Embedded), aplica os Ids já escolhidos e não pergunta nada.
    #>
    param (
        [string[]]$Ids,
        [switch]$Embedded,
        [switch]$PassThru
    )

    $title = "Aplicar ajustes recomendados"

    Enter-WinForgeAction -Title $title -Embedded:$Embedded

    $final = New-WinForgeResult -Kind Ok -Title $title

    try {
        if (-not $Embedded -and -not (Test-WinForgeElevation -Reason "Os ajustes de sistema exigem privilégios de Administrador.")) {
            $final = New-WinForgeResult -Kind Failed -Detail "requer Administrador" -Title $title
        }
        else {
            if (-not $PSBoundParameters.ContainsKey("Ids")) {
                $Ids = Select-WinForgeRecommendedTweaks
            }

            if ($null -eq $Ids -or @($Ids).Count -eq 0) {
                Write-WinForgeStatus -Type Info -Message "Nenhum ajuste a aplicar."
                $final = New-WinForgeResult -Kind Skipped -Detail "nada a aplicar" -Title $title
            }
            else {
                $proceed = $true

                if (-not $Embedded) {
                    Write-Host ""

                    if (Confirm-WinForgeAction "Criar um ponto de restauração antes de aplicar?" -DefaultKey S) {
                        $restorePoint = Request-WinForgeRestorePoint
                        Write-Host ""

                        # Sem o ponto de restauração a escolha é do usuário; padrão: não aplicar.
                        if ((Test-WinForgeResultFlag -Result $restorePoint -Name "NotCreated") -and
                            -not (Confirm-WinForgeAction "Os ajustes ainda podem ser desfeitos pelo WinForge. Deseja aplicá-los mesmo sem o ponto de restauração?" -DefaultKey N)) {
                            $proceed = $false
                        }
                    }
                }

                if (-not $proceed) {
                    Write-WinForgeStatus -Type Warning -Message "Ajustes não aplicados."
                    $final = New-WinForgeResult -Kind Skipped -Detail "sem ponto de restauração" -Title $title
                }
                else {
                    $summary = Invoke-WinForgeTweakSet -Ids @($Ids)
                    $failed = @($summary.Results | Where-Object { $_.Kind -in @("Failed", "Warning") })
                    $applied = @($summary.Results | Where-Object { $_.Kind -eq "Ok" })

                    Write-Host ""
                    Write-WinForgeStatus -Type Info -Message "$($applied.Count) ajuste(s) aplicado(s), $($failed.Count) com problema."
                    Write-WinForgeStatus -Type Info -Message "Todos podem ser desfeitos em Ajustes do Windows > Desfazer ajustes do WinForge."

                    if ($failed.Count -gt 0) {
                        $final = New-WinForgeResult -Kind Warning -Detail "$($failed.Count) de $(@($summary.Results).Count) com problema" -Title $title
                    }

                    if ($summary.NeedsExplorerRestart -and -not $Embedded) {
                        Write-Host ""

                        if (Confirm-WinForgeAction "Reiniciar o Explorador de Arquivos agora para ver as mudanças?" -DefaultKey S) {
                            Restart-WinForgeExplorerShell
                        }
                    }
                }
            }
        }
    }
    catch {
        Write-WinForgeStatus -Type Error -Message "Falha ao aplicar os ajustes: $($_.Exception.Message)"
        $final = New-WinForgeResult -Kind Failed -Detail $_.Exception.Message -Title $title
    }

    if ($PassThru) { $final }
    Exit-WinForgeAction -Embedded:$Embedded
}


function Invoke-WinForgeTweakToggle {
    # Aplica o ajuste se ele está no padrão e desfaz se já está aplicado.
    # -AlreadyConfirmed: na janela, ligar ou desligar a chave do ajuste já é a confirmação.
    # Em notebook, ajustes que gastam bateria continuam pedindo confirmação.
    param (
        [Parameter(Mandatory)]
        $Tweak,

        [switch]$AlreadyConfirmed
    )

    Enter-WinForgeAction -Title $Tweak.Name

    $status = Get-WinForgeTweakStatus -Tweak $Tweak
    $session = Get-WinForgeSessionInfo

    Write-WinForgeKeyValue -Label "Ajuste" -Value $Tweak.Name
    Write-WinForgeKeyValue -Label "Estado atual" -Value $(if ($status -eq "Aplicado") { "Aplicado" } elseif ($status -eq "Padrão") { "Padrão do Windows" } else { "Desconhecido" })
    Write-Host ""
    Write-Host "  $($Tweak.Description)" -ForegroundColor Yellow

    if ($session.IsLaptop -and $Tweak.LaptopRisk -and -not [string]::IsNullOrWhiteSpace($Tweak.Warning)) {
        Write-Host ""
        Write-WinForgeStatus -Type Warning -Message $Tweak.Warning
    }

    if ($Tweak.UserScope -and $session.UserMismatch) {
        Write-Host ""
        Write-WinForgeStatus -Type Warning -Message "O WinForge está elevado com outra conta: este ajuste afetará o perfil de $($session.User), não o do usuário logado."
    }

    if ($Tweak.RequiresAdmin -and -not (Test-WinForgeAdministrator)) {
        Write-Host ""
        [void](Test-WinForgeElevation -Reason "O ajuste '$($Tweak.Name)' exige privilégios de Administrador.")
        Exit-WinForgeAction
        return
    }

    Write-Host ""

    $reverting = ($status -eq "Aplicado")

    if ($reverting) {
        $question = "Este ajuste já está aplicado. Deseja desfazê-lo?"
    }
    else {
        $question = "Deseja aplicar este ajuste?"
    }

    $needsExtraConfirmation = ((-not $reverting) -and $session.IsLaptop -and $Tweak.LaptopRisk)
    $skipQuestion = ($AlreadyConfirmed -and -not $needsExtraConfirmation)

    if ((-not $skipQuestion) -and -not (Confirm-WinForgeAction $question -DefaultKey S)) {
        Write-Host ""
        Write-WinForgeStatus -Type Warning -Message "Operação cancelada."
        Exit-WinForgeAction
        return
    }

    try {
        Write-Host ""

        if ($reverting) {
            $hadBackup = Invoke-WinForgeTweakRevert -Tweak $Tweak

            if ((Get-WinForgeTweakStatus -Tweak $Tweak) -eq "Aplicado") {
                Write-WinForgeStatus -Type Warning -Message "O ajuste continua marcado como aplicado. Uma política ou outro programa pode estar impondo o valor."
            }
            else {
                Write-WinForgeStatus -Type Success -Message "Ajuste desfeito."
            }

            if (-not $hadBackup) {
                Write-WinForgeStatus -Type Info -Message "Não havia backup deste ajuste; foram usados os padrões do Windows."
            }
        }
        else {
            Invoke-WinForgeTweakApply -Tweak $Tweak

            if ((Get-WinForgeTweakStatus -Tweak $Tweak) -eq "Aplicado") {
                Write-WinForgeStatus -Type Success -Message "Ajuste aplicado. O valor original foi guardado; para desfazer, abra este ajuste de novo."
            }
            else {
                Write-WinForgeStatus -Type Warning -Message "O valor foi gravado, mas o Windows não o manteve. Uma política da organização pode estar impondo outro valor."
            }
        }

        if ($Tweak.RestartExplorer) {
            Write-Host ""

            if (Confirm-WinForgeAction "Reiniciar o Explorador de Arquivos agora para ver a mudança?" -DefaultKey S) {
                Restart-WinForgeExplorerShell
                Write-WinForgeStatus -Type Success -Message "Explorador reiniciado."
            }
        }
    }
    catch {
        Write-Host ""
        Write-WinForgeStatus -Type Error -Message "Falha ao alterar o ajuste: $($_.Exception.Message)"
    }

    Exit-WinForgeAction
}


function Invoke-WinForgeRevertAllTweaks {
    Enter-WinForgeAction -Title "Desfazer ajustes do WinForge"

    if (-not (Test-WinForgeElevation -Reason "Desfazer ajustes de sistema exige privilégios de Administrador.")) {
        Exit-WinForgeAction
        return
    }

    $backup = Read-WinForgeTweakBackup
    $ids = @($backup.Keys)

    if ($ids.Count -eq 0) {
        Write-WinForgeStatus -Type Info -Message "Não há ajustes do WinForge com backup para desfazer."
        Exit-WinForgeAction
        return
    }

    # Desfaz na ordem inversa da aplicação: ajustes feitos dentro de um plano de energia saem antes de o plano voltar.
    $catalogOrder = @(Get-WinForgeTweakCatalog | ForEach-Object { $_.Id })
    $known = @($catalogOrder | Where-Object { $ids -contains $_ })
    [array]::Reverse($known)
    $unknown = @($ids | Where-Object { $catalogOrder -notcontains $_ })

    if ($known.Count -eq 0) {
        Write-WinForgeStatus -Type Warning -Message "Os backups encontrados são de ajustes que esta versão do WinForge não conhece ($($unknown -join ', ')). Nada foi desfeito."
        Exit-WinForgeAction
        return
    }

    Write-Host "Serão desfeitos os ajustes que o WinForge aplicou neste PC:" -ForegroundColor Yellow
    Write-Host ""

    foreach ($id in $known) {
        Write-Host "  - $((Get-WinForgeTweakById -Id $id).Name)" -ForegroundColor Gray
    }

    Write-Host ""

    if ($unknown.Count -gt 0) {
        Write-WinForgeStatus -Type Warning -Message "Backups de ajustes desconhecidos serão mantidos (versão diferente do WinForge?): $($unknown -join ', ')"
        Write-Host ""
    }

    if (-not (Confirm-WinForgeAction "Deseja desfazer todos?" -DefaultKey N)) {
        Write-Host ""
        Write-WinForgeStatus -Type Warning -Message "Operação cancelada."
        Exit-WinForgeAction
        return
    }

    $needsExplorerRestart = $false
    $failures = 0

    foreach ($id in $known) {
        $tweak = Get-WinForgeTweakById -Id $id

        try {
            [void](Invoke-WinForgeTweakRevert -Tweak $tweak)
            Write-WinForgeStatus -Type Success -Message "$($tweak.Name): desfeito."

            if ($tweak.RestartExplorer) { $needsExplorerRestart = $true }
        }
        catch {
            $failures++
            Write-WinForgeStatus -Type Error -Message "$($tweak.Name): $($_.Exception.Message)"
        }
    }

    Write-Host ""

    if ($failures -gt 0) {
        Write-WinForgeStatus -Type Warning -Message "$failures ajuste(s) não puderam ser desfeitos; o backup deles foi mantido para uma nova tentativa."
    }
    else {
        Write-WinForgeStatus -Type Success -Message "$($known.Count) ajuste(s) desfeito(s)."
    }

    if ($needsExplorerRestart -and (Confirm-WinForgeAction "Reiniciar o Explorador de Arquivos agora?" -DefaultKey S)) {
        try {
            Restart-WinForgeExplorerShell
        }
        catch {
            Write-WinForgeStatus -Type Error -Message "Não foi possível reiniciar o Explorador: $($_.Exception.Message)"
        }
    }

    Exit-WinForgeAction
}


Export-ModuleMember -Function *
