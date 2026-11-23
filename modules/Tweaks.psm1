# Ajustes do Windows orientados a dados: cada ajuste sabe se está aplicado (Test), guarda o valor original
# antes de mudar (Capture/Apply) e consegue desfazer (Revert), mesmo sem backup (valores padrão do Windows).
#
# Atenção: scriptblocks criados com GetNewClosure() não enxergam variáveis $script: deste módulo.
# Constantes usadas por eles ficam em funções (Get-WinForge...Guid) ou são capturadas em variáveis locais.

$script:WinForgeTweakCatalog = $null

# Os ajustes do catálogo por Id (Get-WinForgeTweakById), montado junto com ele.
$script:WinForgeTweakIndex = $null

# Verdadeiro enquanto a chave de um ajuste desfaz (a pessoa pediu o estado oposto, Test-WinForgeTweakSwitchRevert); falso
# em Desfazer ajustes do WinForge e no Histórico, que só devolvem o que o WinForge mudou.
$script:WinForgeTweakSwitchRevert = $false


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


function Initialize-WinForgeUserPreferenceNative {
    # SystemParametersInfo, para as opções do teclado e do mouse valerem na hora (e não só depois de sair e entrar de
    # novo no Windows). Lança exceção onde não existe (fora do Windows); quem chama trata.
    if (-not ("WinForge.UserPreferenceNative" -as [type])) {
        Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

namespace WinForge
{
    public static class UserPreferenceNative
    {
        [DllImport("user32.dll", EntryPoint = "SystemParametersInfoW", SetLastError = true)]
        public static extern bool SystemParametersInfo(uint action, uint param, [In, Out] int[] data, uint winIni);

        [DllImport("user32.dll", EntryPoint = "SystemParametersInfoW", SetLastError = true)]
        public static extern bool SystemParametersInfo(uint action, uint param, IntPtr data, uint winIni);
    }
}
"@
    }
}


function Sync-WinForgeAccessibilityKeys {
    # Passa ao Windows, na hora, as opções das Teclas de Aderência, de Filtragem e de Alternância gravadas no registro
    # (Flags). A estrutura de cada uma é lida primeiro, e só o campo das opções muda.
    try {
        Initialize-WinForgeUserPreferenceNative
        $base = "HKCU:\Control Panel\Accessibility"

        # Chave, SPI_GET*, SPI_SET* e o tamanho da estrutura em inteiros (o primeiro é o tamanho em bytes).
        foreach ($entry in @(
                @{ Key = "StickyKeys"; Get = 0x003A; Set = 0x003B; Size = 2 },
                @{ Key = "Keyboard Response"; Get = 0x0032; Set = 0x0033; Size = 6 },
                @{ Key = "ToggleKeys"; Get = 0x0034; Set = 0x0035; Size = 2 }
            )) {
            $flags = Get-WinForgeRegistryValueOrNull -Path "$base\$($entry.Key)" -Name "Flags"
            if ($null -eq $flags) { continue }

            $data = New-Object int[] $entry.Size
            $data[0] = 4 * $entry.Size

            if (-not [WinForge.UserPreferenceNative]::SystemParametersInfo([uint32]$entry.Get, [uint32]$data[0], $data, [uint32]0)) { continue }

            $data[1] = [int]$flags
            [void][WinForge.UserPreferenceNative]::SystemParametersInfo([uint32]$entry.Set, [uint32]$data[0], $data, [uint32]2)
        }
    }
    catch {
        Write-Verbose "Opções do teclado: valem depois de sair e entrar de novo no Windows ($($_.Exception.Message))."
    }
}


function Get-WinForgeAccessibilityFlags {
    # As opções (Flags, texto) de uma das teclas de acessibilidade, como número; sem o valor, o padrão do Windows. Um texto
    # que não é número não vira um palpite: a leitura falha (a chave aparece "Não identificado").
    param (
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Default
    )

    $value = Get-WinForgeRegistryValueOrNull -Path $Path -Name "Flags"
    if ($null -eq $value) { $value = $Default }

    $number = 0
    if (-not [int]::TryParse(([string]$value).Trim(), [ref]$number)) { throw (Get-WinForgeText 'As opções das teclas de acessibilidade não se leem: ''{0}''.' "$value") }

    return $number
}


function Test-WinForgeTweakSwitchRevert {
    # Se quem desfaz agora é a chave de um ajuste (a pessoa pediu o estado oposto): aí o desfazer leva o recurso ao outro
    # estado mesmo quando o WinForge não foi quem o mudou (o plano ativo, a hibernação da Inicialização Rápida).
    return [bool]$script:WinForgeTweakSwitchRevert
}


function Sync-WinForgeMouseSettings {
    # Passa ao Windows, na hora, a aceleração do mouse gravada no registro (os dois limites e a velocidade).
    try {
        Initialize-WinForgeUserPreferenceNative
        $path = "HKCU:\Control Panel\Mouse"
        $values = @(foreach ($name in @("MouseThreshold1", "MouseThreshold2", "MouseSpeed")) { Get-WinForgeRegistryValueOrNull -Path $path -Name $name })

        # Faltando um dos três, o Windows segue com o que já usa (zerar o que falta mudaria a aceleração sem ninguém pedir).
        if (@($values | Where-Object { $null -eq $_ }).Count -gt 0) { return }

        $data = New-Object int[] 3
        for ($i = 0; $i -lt 3; $i++) { $data[$i] = [int]$values[$i] }
        [void][WinForge.UserPreferenceNative]::SystemParametersInfo([uint32]0x0004, [uint32]0, $data, [uint32]2)
    }
    catch {
        Write-Verbose "Mouse: vale depois de sair e entrar de novo no Windows ($($_.Exception.Message))."
    }
}


function Sync-WinForgeLanguageHotkey {
    # O Windows relê do registro as teclas de troca do idioma do teclado (SPI_SETLANGTOGGLE).
    try {
        Initialize-WinForgeUserPreferenceNative
        [void][WinForge.UserPreferenceNative]::SystemParametersInfo([uint32]0x005B, [uint32]0, [IntPtr]::Zero, [uint32]2)
    }
    catch {
        Write-Verbose "Idioma do teclado: vale depois de sair e entrar de novo no Windows ($($_.Exception.Message))."
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
        throw (Get-WinForgeText 'powercfg {0} falhou (código {1}): {2}' "$($Arguments -join ' ')" "$($run.ExitCode)" "$($run.Text.Trim())")
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


function Get-WinForgeActivePowerScheme {
    # O plano de energia ativo, de uma só consulta ao powercfg: Guid (minúsculo) e Text (a saída, que traz o nome
    # localizado do plano). Sem informação (powercfg ausente ou com erro): $null.
    try {
        $run = Invoke-WinForgeCapture -FilePath "powercfg.exe" -Arguments @("/getactivescheme")
        $match = [regex]::Match($run.Text, "[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}")

        if ($match.Success) {
            return [PSCustomObject]@{ Guid = $match.Value.ToLowerInvariant(); Text = [string]$run.Text }
        }
    }
    catch {
        # Sem informação de plano ativo.
    }

    return $null
}


function Get-WinForgeActivePowerSchemeGuid {
    $scheme = Get-WinForgeActivePowerScheme

    if ($null -eq $scheme) {
        return $null
    }

    return $scheme.Guid
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


function Get-WinForgePowerOriginals {
    <#
    Os valores de antes de um ajuste de energia, uma entrada por plano (SchemeGuid). Aceita o formato atual
    ({ Schemes = [...] }), o de versões anteriores (um plano só: { SchemeGuid, ... }) e uma captura recém-feita. Sem
    nada, lista vazia.
    #>
    param (
        $Saved
    )

    if ($null -eq $Saved) {
        return @()
    }

    $schemes = Get-WinForgeTweakField -Entry $Saved -Name "Schemes"

    if ($null -ne $schemes) {
        return @($schemes | Where-Object { $null -ne $_ })
    }

    return @($Saved)
}


function Merge-WinForgePowerOriginal {
    <#
    Junta a captura de agora (um plano) com os originais já guardados de um ajuste de energia. Cada plano tem a sua
    entrada, e a de outro plano nunca é trocada: aplicar de novo com outro plano ativo não perde os valores do primeiro.
    No mesmo plano, um valor que está no alvo do ajuste (0) foi gravado pelo WinForge e o original de antes continua
    valendo; um valor diferente do alvo (alguém mudou depois) passa a ser o original.
    Groups: onde ficam os pares AC/DC numa entrada ("" = na própria entrada; "Monitor" = dentro de Monitor...).
    #>
    param (
        $Previous,
        $Snapshot,
        [string[]]$Groups = @("")
    )

    $guid = ([string](Get-WinForgeTweakField -Entry $Snapshot -Name "SchemeGuid" -Default "")).ToLowerInvariant()
    $schemes = @()
    $found = $false

    foreach ($entry in @(Get-WinForgePowerOriginals -Saved $Previous)) {
        $entryGuid = ([string](Get-WinForgeTweakField -Entry $entry -Name "SchemeGuid" -Default "")).ToLowerInvariant()

        if ($found -or $entryGuid -ne $guid) {
            $schemes += , $entry
            continue
        }

        $found = $true
        $merged = [ordered]@{ SchemeGuid = (Get-WinForgeTweakField -Entry $Snapshot -Name "SchemeGuid") }

        foreach ($group in $Groups) {
            $before = $(if ($group) { Get-WinForgeTweakField -Entry $entry -Name $group } else { $entry })
            $now = $(if ($group) { Get-WinForgeTweakField -Entry $Snapshot -Name $group } else { $Snapshot })
            $pair = [ordered]@{}

            foreach ($side in @("AC", "DC")) {
                $current = Get-WinForgeTweakField -Entry $now -Name $side
                $old = Get-WinForgeTweakField -Entry $before -Name $side
                $pair[$side] = $(if ($null -ne $current -and [int64]$current -eq 0 -and $null -ne $old) { $old } else { $current })
            }

            if ($group) {
                $merged[$group] = $pair
            }
            else {
                $merged["AC"] = $pair["AC"]
                $merged["DC"] = $pair["DC"]
            }
        }

        $schemes += , $merged
    }

    if (-not $found) {
        $schemes += , $Snapshot
    }

    return [ordered]@{ Schemes = $schemes }
}


function Get-WinForgePowerRevertTargets {
    <#
    Onde desfazer um ajuste de energia: cada plano guardado que ainda existe, com os valores dele (Scheme e Entry). Sem
    backup, ou com um backup que não diz o plano, o plano ativo, com os valores da captura mais recente (ou nenhum: os
    padrões do Windows). Só GUIDs de verdade chegam ao powercfg.
    Se os planos guardados não existem mais (apagados, como a cópia do Alto desempenho que o próprio WinForge apaga ao
    desfazer), os valores deles foram junto, e o plano ativo nunca foi mudado por este ajuste: ele só é tocado quando
    está no alvo do ajuste (IsApplied, a chave aparece ligada), e então volta aos padrões do Windows. Antes, os valores
    da cópia apagada iam para o Equilibrado (por exemplo, "nunca suspender na tomada" do Alto desempenho).
    #>
    param (
        [AllowEmptyCollection()][object[]]$Entries = @(),
        [scriptblock]$IsApplied = $null
    )

    $targets = @()
    $planned = 0

    foreach ($entry in $Entries) {
        $guid = [string](Get-WinForgeTweakField -Entry $entry -Name "SchemeGuid" -Default "")

        if (-not (Test-WinForgeGuidText -Text $guid)) { continue }

        $planned++

        if (Test-WinForgePowerSchemeExists -Guid $guid) {
            $targets += [PSCustomObject]@{ Scheme = $guid.ToLowerInvariant(); Entry = $entry }
        }
    }

    if ($targets.Count -eq 0) {
        if ($planned -eq 0) {
            $latest = $(if ($Entries.Count -gt 0) { $Entries[$Entries.Count - 1] } else { $null })
            $targets += [PSCustomObject]@{ Scheme = "SCHEME_CURRENT"; Entry = $latest }
        }
        elseif ($null -eq $IsApplied -or [bool](& $IsApplied)) {
            $targets += [PSCustomObject]@{ Scheme = "SCHEME_CURRENT"; Entry = $null }
        }
    }
    elseif ((Test-WinForgeTweakSwitchRevert) -and $null -ne $IsApplied) {
        # A chave mostra o plano ativo. Se ele não é um dos guardados (a pessoa trocou de plano depois) e está no alvo, ele
        # também volta aos padrões do Windows, para a chave virar de verdade. Desfazer ajustes do WinForge não faz isso:
        # só devolve os planos que o WinForge mudou.
        $active = [string](Get-WinForgeActivePowerSchemeGuid)

        if ((Test-WinForgeGuidText -Text $active) -and @($targets | Where-Object { $_.Scheme -eq $active.ToLowerInvariant() }).Count -eq 0 -and [bool](& $IsApplied)) {
            $targets += [PSCustomObject]@{ Scheme = "SCHEME_CURRENT"; Entry = $null }
        }
    }

    return $targets
}


function Test-WinForgePowerValuesAtZero {
    <#
    Se uma opção do plano de energia ativo está em 0 (o alvo dos ajustes de energia), como as Configurações do Windows a
    mostram: num PC sem bateria, só o valor na tomada conta (as Configurações e o Painel de Controle só mostram esse);
    num notebook, os dois. Sem conseguir ler, não está.
    #>
    param (
        [Parameter(Mandatory)][string]$Subgroup,
        [Parameter(Mandatory)][string]$Setting
    )

    $value = Get-WinForgePowerSetting -Subgroup $Subgroup -Setting $Setting
    if ($null -eq $value -or $value.AC -ne 0) { return $false }

    # Sem saber se há bateria, os dois lados contam (o mais exigente).
    $battery = $true
    try { $battery = [bool](Get-WinForgeTweakField -Entry (Get-WinForgeSessionInfo) -Name "IsLaptop" -Default $true) } catch { $battery = $true }

    return ((-not $battery) -or $value.DC -eq 0)
}


function Test-WinForgeHighPerformanceActive {
    # Se o plano ativo é de alto desempenho: o Alto desempenho, o Desempenho Máximo ou uma cópia deles.
    $active = Get-WinForgeActivePowerScheme

    if ($null -eq $active) {
        return $false
    }

    if ($active.Guid -eq (Get-WinForgeHighPerformancePlanGuid) -or $active.Guid -eq (Get-WinForgeUltimatePerformancePlanGuid)) {
        return $true
    }

    # Planos duplicados têm outro GUID; o nome (localizado), que vem na mesma saída, é a segunda checagem.
    return [bool]($active.Text -match "(?i)alto desempenho|high performance|desempenho m[aá]ximo|ultimate|alto rendimiento|m[aá]ximo rendimiento")
}


function Remove-WinForgeCreatedPowerScheme {
    <#
    Apaga a cópia do Alto desempenho que o WinForge criou, ao desfazer o ajuste. Na dúvida, não apaga: o GUID vem do
    arquivo de backup, então só some um plano que existe, não é um dos planos do Windows, não está ativo e tem o nome do
    Alto desempenho. Uma falha aqui não desfaz a volta ao plano anterior.
    #>
    param (
        [AllowNull()][string]$Guid
    )

    if (-not (Test-WinForgeGuidText -Text $Guid)) {
        return
    }

    $Guid = $Guid.ToLowerInvariant()
    $builtIn = @((Get-WinForgeHighPerformancePlanGuid), (Get-WinForgeBalancedPlanGuid), (Get-WinForgeUltimatePerformancePlanGuid), "a1841308-3541-4fab-bc81-f71556f20b4a")

    if ($builtIn -contains $Guid -or $Guid -eq (Get-WinForgeActivePowerSchemeGuid)) {
        return
    }

    try {
        $list = Invoke-WinForgeCapture -FilePath "powercfg.exe" -Arguments @("/list")
        $line = @($list.Lines | Where-Object { ([string]$_).ToLowerInvariant().Contains($Guid) }) | Select-Object -First 1

        if ($null -ne $line -and [string]$line -match "(?i)alto desempenho|high performance|alto rendimiento") {
            [void](Invoke-WinForgeCapture -FilePath "powercfg.exe" -Arguments @("/delete", $Guid))
        }
    }
    catch {
        Write-Verbose "Não foi possível apagar a cópia do plano de energia: $($_.Exception.Message)"
    }
}


# ---------------------------------------------------------------------------
# Backup dos valores originais (JSON em %LOCALAPPDATA%\WinForge)
# ---------------------------------------------------------------------------
# O arquivo fica numa pasta que qualquer programa do usuário consegue alterar, e o WinForge desfaz ajustes com
# Administrador: ao desfazer, só o que o catálogo do ajuste prevê é gravado (caminhos e nomes vêm do catálogo; do arquivo
# vêm só os valores), e GUIDs de planos de energia só valem se tiverem o formato de GUID.

function Get-WinForgeTweakBackupPath {
    return (Join-Path (Get-WinForgeDataPath) "tweak-backup.json")
}


function Get-WinForgeTweakBackupUnreadableText {
    return (Get-WinForgeText 'Não foi possível ler o backup dos valores originais dos ajustes (o arquivo pode estar aberto em outro programa). Nada foi alterado; tente de novo.')
}


function Read-WinForgeTweakBackup {
    <#
    O backup como dicionário (Id do ajuste -> entrada com AppliedAt e Original). Com -Status devolve Status e Backup:
    quem vai gravar não grava quando o arquivo existe mas não pôde ser lido ("Unreadable"), porque gravar por cima
    apagaria os originais de todos os ajustes. Um arquivo estragado fica guardado ao lado e vale a cópia anterior
    (Read-WinForgeStateFile).
    #>
    param (
        [switch]$Status
    )

    $path = Get-WinForgeTweakBackupPath
    $read = [PSCustomObject]@{ Status = "Unreadable"; Document = $null }

    try { $read = Read-WinForgeStateFile -Path $path } catch { $read = [PSCustomObject]@{ Status = "Unreadable"; Document = $null } }

    $state = [string]$read.Status
    $document = $read.Document

    if ($null -ne $document -and $document -isnot [System.Management.Automation.PSCustomObject]) {
        # JSON válido que não é um objeto ("[]", "abc") não é um backup do WinForge: fica guardado ao lado, como um arquivo
        # estragado, e vale a cópia anterior se ela for um backup.
        $document = $null

        try {
            $stamp = (Get-Date).ToString("yyyyMMddHHmmss", [System.Globalization.CultureInfo]::InvariantCulture)
            Move-Item -LiteralPath $path -Destination "$path.corrompido-$stamp" -Force -ErrorAction Stop

            $previous = ConvertFrom-WinForgeStateText -Path "$path.bak"

            if ($previous -is [System.Management.Automation.PSCustomObject]) {
                $document = $previous
                $state = "Recovered"
            }
            else {
                $state = "Missing"
            }
        }
        catch {
            $state = "Unreadable"
        }
    }

    $backup = [ordered]@{}

    if ($null -ne $document) {
        foreach ($property in $document.PSObject.Properties) {
            $backup[$property.Name] = $property.Value
        }
    }

    # A 3.49 guardava o Modo de Jogo como valores do registro e o aplicava mesmo ativado de fábrica: esse original não diz
    # o que desfazer. Com ele desativado antes (0), vale como o de agora; sem isso, o WinForge não mudou nada, e a entrada
    # é esquecida (desfazer o desativaria).
    if ($backup.Contains("game-mode")) {
        $converted = ConvertFrom-WinForgeLegacyGameModeBackup -Entry $backup["game-mode"]
        if ($null -eq $converted) { $backup.Remove("game-mode") } else { $backup["game-mode"] = $converted }
    }

    if ($Status) {
        return [PSCustomObject]@{ Status = $state; Backup = $backup }
    }

    return $backup
}


function ConvertFrom-WinForgeLegacyGameModeBackup {
    # A entrada do Modo de Jogo no backup no formato de agora (Original com Exists, Kind e Value); $null para esquecê-la.
    param ($Entry)

    $original = Get-WinForgeTweakField -Entry $Entry -Name "Original"
    $items = @(@($original) | Where-Object { $null -ne $_ })
    $legacy = @($items | Where-Object { -not [string]::IsNullOrEmpty([string](Get-WinForgeTweakField -Entry $_ -Name "Path" -Default "")) })

    if ($legacy.Count -eq 0) { return $Entry }

    $auto = @($legacy | Where-Object { [string](Get-WinForgeTweakField -Entry $_ -Name "Name" -Default "") -eq "AutoGameModeEnabled" }) | Select-Object -First 1
    $value = Get-WinForgeTweakField -Entry $auto -Name "Value"

    if ($null -eq $value) { return $null }

    try { if ([int]$value -ne 0) { return $null } } catch { return $null }

    return [ordered]@{
        AppliedAt = Get-WinForgeTweakField -Entry $Entry -Name "AppliedAt" -Default ""
        Original  = [ordered]@{ Exists = $true; Kind = "DWord"; Value = 0 }
    }
}


function Save-WinForgeTweakBackup {
    # Grava o backup inteiro de forma atômica (a versão anterior fica em ".bak"). Quem lê, altera e grava faz isso dentro
    # de Invoke-WinForgeStateLock. Um backup vazio continua sendo um arquivo ("{}"): apagar o arquivo deixaria só a cópia
    # anterior, com entradas antigas que uma recuperação futura traria de volta.
    param (
        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Backup
    )

    Write-WinForgeStateJson -Path (Get-WinForgeTweakBackupPath) -InputObject $Backup -Depth 10
}


function Get-WinForgeTweakField {
    # Um campo de uma entrada do backup, que pode ser um objeto lido do JSON ou o dicionário de uma captura recém-feita.
    # Ausente (ou entrada que não é objeto) = $Default. Listas voltam inteiras, mesmo com um item só ou vazias.
    param (
        $Entry,
        [string]$Name,
        $Default = $null
    )

    if ($null -eq $Entry -or $Entry -is [string] -or $Entry -is [ValueType]) {
        return $Default
    }

    if ($Entry -is [System.Collections.IDictionary]) {
        if ($Entry.Contains($Name)) { return , $Entry[$Name] }
        return $Default
    }

    $property = $Entry.PSObject.Properties[$Name]

    if ($null -eq $property) {
        return $Default
    }

    return , $property.Value
}


function Set-WinForgeTweakOriginalValue {
    # Acrescenta um dado ao original guardado de um ajuste já anotado no backup (por exemplo, a cópia do plano de energia
    # que o WinForge criou, para reaproveitá-la e apagá-la ao desfazer). Sem a entrada, ou sem conseguir ler o arquivo,
    # não faz nada.
    param (
        [Parameter(Mandatory)][string]$Id,
        [Parameter(Mandatory)][string]$Name,
        $Value
    )

    [void](Invoke-WinForgeStateLock -ScriptBlock {
            $current = Read-WinForgeTweakBackup -Status

            if ($current.Status -eq "Unreadable" -or -not $current.Backup.Contains($Id)) { return }

            $original = Get-WinForgeTweakField -Entry $current.Backup[$Id] -Name "Original"

            if ($original -isnot [System.Management.Automation.PSCustomObject]) { return }

            $original | Add-Member -NotePropertyName $Name -NotePropertyValue $Value -Force
            Save-WinForgeTweakBackup -Backup $current.Backup
        })
}


function Test-WinForgeGuidText {
    # Se o texto é um GUID (o formato que o powercfg usa para planos de energia).
    param (
        [AllowNull()][string]$Text
    )

    return ([string]$Text -match '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
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

        # Junta a captura de agora com o original já guardado, quando o ajuste é aplicado de novo (param $Previous,
        # $Snapshot; devolve o novo original). Sem ele, a captura de agora substitui o original guardado.
        [scriptblock]$Merge = $null,

        # Entra em Aplicar ajustes recomendados. A aparência é gosto e nunca é recomendada: nunca junto de Cosmetic.
        [switch]$Recommended,

        # Só muda a aparência ou a arrumação da barra de tarefas, da área de trabalho ou das cores: é gosto de cada um. A
        # revisão do Otimizar não o oferece (Test-WinForgeTweakInReview). O jeito do Explorador e os widgets da tela de
        # bloqueio ficam na revisão: a pessoa os quer ali.
        [switch]$Cosmetic,

        # Ajuste de energia ou desempenho que muda o comportamento do PC; a janela o esconde em "Avançados".
        [switch]$Advanced,
        [switch]$LaptopRisk,
        [switch]$RequiresAdmin,
        [switch]$UserScope,
        [switch]$RestartExplorer,
        [switch]$Windows11Only,

        # Não existe nos PCs com Modern Standby (Test-WinForgeModernStandby): neles, a Microsoft só permite o plano
        # Equilibrado e os derivados dele.
        [switch]$NotOnModernStandby,

        # O ajuste só vale depois de reiniciar o PC: a faixa do resultado pede o reinício.
        [switch]$NeedsReboot,

        # Builds do Windows em que o ajuste faz efeito (0 = sem limite): o recurso chegou numa atualização (MinBuild) ou
        # deixou de existir (MaxBuild). Fora delas, o ajuste não aparece.
        [int]$MinBuild = 0,
        [int]$MaxBuild = 0,

        # Configuração que o Windows protege contra programas (UCPD): quando ele recusa, a tela diz onde mudar nas
        # Configurações. Shortcut (atalho da tabela de Shortcuts), Apply e Undo (o caminho, em cada sentido); com o sufixo 10,
        # o mesmo no Windows 10. Vazio nos demais ajustes.
        [hashtable]$Protected = @{},
        [string]$Warning = "",

        # Alterações de registro (Path, Name, Value, Default) quando o ajuste é só isso; vazio nos demais.
        [object[]]$Changes = @(),

        # O padrão do Windows já é o alvo do ajuste (o Modo de Jogo vem ativado): "aplicado" sem o WinForge ter feito nada.
        # Exportar ajustes aplicados só leva um desses quando foi o WinForge que o aplicou.
        [switch]$OnByDefault
    )

    return [PSCustomObject]@{
        PSTypeName      = "WinForge.Tweak"
        Id              = $Id
        Category        = $Category
        Name            = $Name
        Description     = $Description
        Recommended     = [bool]$Recommended
        Cosmetic        = [bool]$Cosmetic
        Advanced        = [bool]$Advanced
        LaptopRisk      = [bool]$LaptopRisk
        RequiresAdmin   = [bool]$RequiresAdmin
        UserScope       = [bool]$UserScope
        RestartExplorer = [bool]$RestartExplorer
        Windows11Only   = [bool]$Windows11Only
        NotOnModernStandby = [bool]$NotOnModernStandby
        NeedsReboot     = [bool]$NeedsReboot
        MinBuild        = $MinBuild
        MaxBuild        = $MaxBuild
        Protected       = $Protected
        Warning         = $Warning
        Changes         = @($Changes)
        OnByDefault     = [bool]$OnByDefault

        # Como a chave aparece (Get-WinForgeTweakSwitchLabels completa no catálogo): Feature é o recurso do Windows,
        # About diz o que ele é, Short é a frase da linha (até 60 letras), e Inverted diz que o ajuste desativa o recurso
        # (a chave fica ativada com o ajuste fora).
        Feature         = $Name
        About           = $Description
        Short           = ""
        Inverted        = $false
        Capture         = $Capture
        Apply           = $Apply
        Revert          = $Revert
        Test            = $Test
        Merge           = $Merge
    }
}


function Restore-WinForgeTweakRegistryValue {
    # Devolve um valor de registro ao que era antes do ajuste: Exists, Kind e Value, como a captura guardou. Backups de
    # versões anteriores só têm Value (e só guardavam DWORDs): Value nulo era "o valor não existia".
    param (
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Name,
        $Saved
    )

    $value = Get-WinForgeTweakField -Entry $Saved -Name "Value"
    $exists = [bool](Get-WinForgeTweakField -Entry $Saved -Name "Exists" -Default ($null -ne $value))
    $kind = [string](Get-WinForgeTweakField -Entry $Saved -Name "Kind" -Default "")

    if (-not $exists -or $null -eq $value) {
        Remove-WinForgeRegistryValue -Path $Path -Name $Name
    }
    elseif ([string]::IsNullOrWhiteSpace($kind) -or $kind -eq "DWord") {
        Set-WinForgeRegistryDWord -Path $Path -Name $Name -Value $value
    }
    else {
        Set-WinForgeRegistryValue -Path $Path -Name $Name -Kind $kind -Value $value
    }
}


function New-WinForgeTweakRevertReport {
    # O que um desfazer fez: Restored (valores que ainda estavam como o WinForge deixou e voltaram ao original) e Kept
    # (valores mudados depois, que ficaram como estão). Quem desfaz vários usa isso para não dizer "desfeito" à toa. Note:
    # algo a mais que a pessoa precisa saber (a hibernação ligada junto com a Inicialização Rápida).
    param (
        [int]$Restored = 0,
        [int]$Kept = 0,
        [string]$Note = ""
    )

    return [PSCustomObject]@{ PSTypeName = "WinForge.TweakRevert"; Restored = $Restored; Kept = $Kept; Note = $Note }
}


function Test-WinForgeTweakValueAtTarget {
    <#
    Se o valor de agora no registro tem o efeito de uma alteração do catálogo (Test-WinForgeTweakValueMatches: o valor, os
    outros do mesmo efeito e a ausência quando ela é o efeito). Um valor diferente foi mudado depois (pela pessoa, pelo
    Windows ou por outro programa): ao desfazer, ele fica como está, porque desfazer não passa por cima de uma escolha mais
    nova. Uma leitura que falha também não está no alvo: nada é gravado por cima dela.
    #>
    param ([Parameter(Mandatory)]$Change)

    try {
        return (Test-WinForgeTweakValueMatches -Current (Get-WinForgeRegistryValueOrNull -Path $Change.Path -Name $Change.Name) -Change $Change)
    }
    catch {
        return $false
    }
}


function Test-WinForgeTweakValueMatches {
    <#
    Se um valor lido do registro tem o efeito de uma alteração do catálogo: o próprio valor (texto igual, ou o mesmo
    número), um dos outros valores do mesmo efeito (Also: no compartilhamento de atualizações, 99 e 100 também não
    compartilham) ou, com AbsentIsTarget, a ausência do valor (o reconhecimento de fala vem desligado sem ele).
    #>
    param (
        $Current,
        [Parameter(Mandatory)]$Change
    )

    if ($null -eq $Current) { return [bool](Get-WinForgeTweakField -Entry $Change -Name "AbsentIsTarget" -Default $false) }

    $kind = Get-WinForgeTweakChangeKind $Change
    $also = Get-WinForgeTweakField -Entry $Change -Name "Also"
    $targets = @(@($Change.Value) + @($also) | Where-Object { $null -ne $_ })

    foreach ($target in $targets) {
        try {
            if ($kind -eq "String") {
                if ([string]$Current -ceq [string]$target) { return $true }
            }
            elseif ([int64]$Current -eq [int64]$target) {
                return $true
            }
        }
        catch {
            # Um valor de outro tipo (binário, lista) não é o do ajuste.
            Write-Verbose "Valor de outro tipo em $($Change.Name): $($_.Exception.Message)"
        }
    }

    return $false
}


function Test-WinForgeTweakChangeState {
    <#
    O estado de um valor para a chave: $true se ele tem o efeito do ajuste. Diferente do desfazer, uma leitura que falha não
    vira "não está no alvo": ela sobe, e a chave aparece "Não identificado". Com AbsentUnknown, a ausência do valor também
    (o agendamento de GPU: sem o valor, quem decide é o driver, e o WinForge não sabe o que ele escolheu).
    #>
    param ([Parameter(Mandatory)]$Change)

    $current = Get-WinForgeRegistryValueOrNull -Path $Change.Path -Name $Change.Name

    if ($null -eq $current -and [bool](Get-WinForgeTweakField -Entry $Change -Name "AbsentUnknown" -Default $false)) {
        throw (Get-WinForgeText 'Sem o valor {0}, o Windows decide sozinho, e o estado não se lê.' "$($Change.Name)")
    }

    return (Test-WinForgeTweakValueMatches -Current $current -Change $Change)
}


function Test-WinForgeTweakRegistryTarget {
    # Se o valor capturado é exatamente o que o ajuste grava (do mesmo tipo e com o valor do catálogo).
    param (
        $Entry,
        $Target,
        [string]$Kind = "DWord"
    )

    $value = Get-WinForgeTweakField -Entry $Entry -Name "Value"
    $captured = [string](Get-WinForgeTweakField -Entry $Entry -Name "Kind" -Default "")

    if ($null -eq $value -or ($captured -and $captured -ne $Kind)) {
        return $false
    }

    try {
        if ($Kind -eq "String") { return ([string]$value -ceq [string]$Target) }
        return ((ConvertTo-WinForgeRegistryDWord -Value $value) -eq (ConvertTo-WinForgeRegistryDWord -Value $Target))
    }
    catch {
        return $false
    }
}


function Get-WinForgeTweakChangeKind {
    # O tipo de um valor do catálogo: "String" quando a alteração diz Kind = "String"; DWORD nos demais.
    param ($Change)

    if ([string](Get-WinForgeTweakField -Entry $Change -Name "Kind" -Default "") -eq "String") { return "String" }
    return "DWord"
}


function New-WinForgeRegistryTweak {
    <#
    Ajuste feito só de valores do registro. Changes: hashtables com Path, Name, Value e, opcionalmente, Default (valor do
    Windows usado ao desfazer sem backup; sem Default o valor é removido) e Kind = "String" para um valor de texto (as
    opções do teclado e do mouse no Painel de Controle são texto); sem Kind, DWORD. Para a chave mostrar o estado de
    verdade: Also (outros valores com o mesmo efeito), AbsentIsTarget (sem o valor, o efeito já vale), AbsentUnknown (sem
    o valor, o estado não se lê) e State = $false (o valor é gravado, mas não decide o que a chave mostra).
    #>
    param (
        [Parameter(Mandatory)][string]$Id,
        [Parameter(Mandatory)][string]$Category,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Description,
        [Parameter(Mandatory)][object[]]$Changes,
        [switch]$Recommended,
        [switch]$Cosmetic,
        [switch]$Advanced,
        [switch]$RestartExplorer,
        [switch]$Windows11Only,
        [switch]$NeedsReboot,
        [int]$MinBuild = 0,
        [int]$MaxBuild = 0,
        [hashtable]$Protected = @{},
        [scriptblock]$AfterChange = $null,

        # O padrão do Windows já tem o efeito do ajuste (o reconhecimento de fala vem desligado): veja New-WinForgeTweak.
        [switch]$OnByDefault
    )

    $changeList = @($Changes)
    $after = $AfterChange

    $capture = {
        $snapshot = @()

        foreach ($change in $changeList) {
            # O tipo também é guardado: um texto "1" ou um QWORD voltam como eram, não como DWORD. Listas (binário e
            # multitexto) vão sempre como lista, mesmo vazias ou de um item só; bytes, como números, que o JSON guarda igual
            # em qualquer versão do PowerShell.
            $value = Get-WinForgeRegistryValueOrNull -Path $change.Path -Name $change.Name
            $kind = [string](Get-WinForgeRegistryValueKind -Path $change.Path -Name $change.Name)

            if ($kind -eq "Binary") { $value = @(@($value) | Where-Object { $null -ne $_ } | ForEach-Object { [int]$_ }) }
            elseif ($kind -eq "MultiString") { $value = @(@($value) | Where-Object { $null -ne $_ } | ForEach-Object { [string]$_ }) }

            $snapshot += [ordered]@{
                Path   = $change.Path
                Name   = $change.Name
                Exists = ($null -ne $value -or $kind -ne "")
                Kind   = $kind
                Value  = $value
            }
        }

        return $snapshot
    }.GetNewClosure()

    $merge = {
        param ($Previous, $Snapshot)

        # Reaplicar um ajuste que o Windows desfez em parte não pode trocar o original guardado pelo que o próprio WinForge
        # gravou: um valor que está no alvo do ajuste mantém o original de antes; um valor diferente (alguém mudou depois)
        # passa a ser o original.
        $previousByKey = @{}

        foreach ($entry in @($Previous | Where-Object { $null -ne $_ })) {
            $key = "$([string](Get-WinForgeTweakField -Entry $entry -Name 'Path' -Default ''))|$([string](Get-WinForgeTweakField -Entry $entry -Name 'Name' -Default ''))"
            $previousByKey[$key] = $entry
        }

        $merged = @()

        foreach ($change in $changeList) {
            $key = "$($change.Path)|$($change.Name)"
            $now = @($Snapshot | Where-Object { $null -ne $_ -and "$($_.Path)|$($_.Name)" -eq $key }) | Select-Object -First 1

            if ($previousByKey.ContainsKey($key) -and ($null -eq $now -or (Test-WinForgeTweakRegistryTarget -Entry $now -Target $change.Value -Kind (Get-WinForgeTweakChangeKind $change)))) {
                $merged += $previousByKey[$key]
            }
            elseif ($null -ne $now) {
                $merged += $now
            }
        }

        return , $merged
    }.GetNewClosure()

    $apply = {
        foreach ($change in $changeList) {
            if ((Get-WinForgeTweakChangeKind $change) -eq "String") {
                Set-WinForgeRegistryValue -Path $change.Path -Name $change.Name -Kind "String" -Value ([string]$change.Value)
            }
            else {
                Set-WinForgeRegistryDWord -Path $change.Path -Name $change.Name -Value ([int]$change.Value)
            }
        }

        if ($null -ne $after) {
            & $after
        }
    }.GetNewClosure()

    $revert = {
        param($Saved)

        # Só os valores deste ajuste no catálogo são gravados, cada um com o original guardado para o mesmo caminho e nome;
        # entradas a mais no arquivo de backup são ignoradas. Sem original guardado (ajuste feito fora do WinForge, ou
        # backup de outra versão), o valor volta ao padrão do Windows. Um valor que não está mais no alvo do ajuste foi
        # mudado depois e fica como está.
        $savedByKey = @{}

        foreach ($entry in @($Saved | Where-Object { $null -ne $_ })) {
            $key = "$([string](Get-WinForgeTweakField -Entry $entry -Name 'Path' -Default ''))|$([string](Get-WinForgeTweakField -Entry $entry -Name 'Name' -Default ''))"
            $savedByKey[$key] = $entry
        }

        $restored = 0
        $kept = 0

        foreach ($change in $changeList) {
            $key = "$($change.Path)|$($change.Name)"

            $kind = Get-WinForgeTweakChangeKind $change

            if (-not (Test-WinForgeTweakValueAtTarget -Change $change)) {
                $kept++
                continue
            }

            $restored++

            if ($savedByKey.ContainsKey($key)) {
                Restore-WinForgeTweakRegistryValue -Path $change.Path -Name $change.Name -Saved $savedByKey[$key]
            }
            elseif ($null -eq $change.Default) {
                Remove-WinForgeRegistryValue -Path $change.Path -Name $change.Name
            }
            elseif ($kind -eq "String") {
                Set-WinForgeRegistryValue -Path $change.Path -Name $change.Name -Kind "String" -Value ([string]$change.Default)
            }
            else {
                Set-WinForgeRegistryDWord -Path $change.Path -Name $change.Name -Value ([int]$change.Default)
            }
        }

        # Sem nada a voltar, nada a avisar (nem fechar a Game Bar).
        if ($null -ne $after -and $restored -gt 0) {
            & $after
        }

        return (New-WinForgeTweakRevertReport -Restored $restored -Kept $kept)
    }.GetNewClosure()

    # O estado da chave: só os valores que decidem o recurso (State, o que as Configurações do Windows gravam); os outros
    # são gravados e desfeitos junto, mas não mudam o que a chave mostra.
    $test = {
        foreach ($change in $changeList) {
            if ($false -eq (Get-WinForgeTweakField -Entry $change -Name "State" -Default $true)) { continue }
            if (-not (Test-WinForgeTweakChangeState -Change $change)) { return $false }
        }

        return $true
    }.GetNewClosure()

    # HKCU\Software\Policies é só leitura para quem não é Administrador, como o HKLM.
    $requiresAdmin = (@($changeList | Where-Object { $_.Path -like "HKLM:*" -or $_.Path -like "HKCU:\Software\Policies\*" }).Count -gt 0)
    $userScope = (@($changeList | Where-Object { $_.Path -like "HKCU:*" }).Count -gt 0)

    return (New-WinForgeTweak -Id $Id -Category $Category -Name $Name -Description $Description `
            -Capture $capture -Apply $apply -Revert $revert -Test $test -Merge $merge `
            -Recommended:$Recommended -Cosmetic:$Cosmetic -Advanced:$Advanced -RestartExplorer:$RestartExplorer -Windows11Only:$Windows11Only `
            -NeedsReboot:$NeedsReboot -MinBuild $MinBuild -MaxBuild $MaxBuild -Protected $Protected `
            -RequiresAdmin:$requiresAdmin -UserScope:$userScope -Changes $changeList -OnByDefault:$OnByDefault)
}


function Get-WinForgeTweakPages {
    # Em que página da janela fica cada categoria de ajuste, na ordem de exibição (a das páginas na barra lateral).
    # Ajustes do Windows: o comportamento, do que o usuário mais vê para o que mexe no hardware. Personalização: o visual
    # do Windows (barra de tarefas, área de trabalho, cores e tela de bloqueio).
    return [ordered]@{
        "tweaks"      = @((Get-WinForgeText 'Explorador'), (Get-WinForgeText 'Privacidade e sugestões'), "Windows Update", (Get-WinForgeText 'Notificações e teclado'), (Get-WinForgeText 'Jogos'), (Get-WinForgeText 'Energia e desempenho'))
        "personalize" = @((Get-WinForgeText 'Barra de tarefas e Iniciar'), (Get-WinForgeText 'Área de trabalho'), (Get-WinForgeText 'Cores e transparência'), (Get-WinForgeText 'Tela de bloqueio'))
    }
}


function Get-WinForgeTweakCategories {
    # As categorias na ordem de exibição: as de uma página (-Page) ou todas, página por página.
    param ([string]$Page = "")

    $pages = Get-WinForgeTweakPages

    if ($Page) {
        if (-not $pages.Contains($Page)) { return @() }
        return @($pages[$Page])
    }

    return @(foreach ($key in $pages.Keys) { $pages[$key] })
}


function Get-WinForgeTweakPageId {
    # A página em que um ajuste aparece (pela categoria dele).
    param ([Parameter(Mandatory)]$Tweak)

    $pages = Get-WinForgeTweakPages

    foreach ($key in $pages.Keys) {
        if (@($pages[$key]) -contains [string]$Tweak.Category) { return [string]$key }
    }

    return "tweaks"
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

    # --- Explorador (e, na Personalização, a barra de tarefas) -----------------
    $catalog += New-WinForgeRegistryTweak -Id "file-extensions" -Category (Get-WinForgeText 'Explorador') -Name (Get-WinForgeText 'Mostrar extensões de arquivos') `
        -Description (Get-WinForgeText 'Exibe .exe, .pdf, .png etc. no Explorador (ajuda a perceber arquivos disfarçados).') -Recommended -RestartExplorer `
        -Changes @(@{ Path = $advanced; Name = "HideFileExt"; Value = 0; Default = 1 })

    $catalog += New-WinForgeRegistryTweak -Id "hidden-files" -Category (Get-WinForgeText 'Explorador') -Name (Get-WinForgeText 'Mostrar arquivos e pastas ocultos') `
        -Description (Get-WinForgeText 'Arquivos protegidos do sistema continuam ocultos.') -RestartExplorer `
        -Changes @(@{ Path = $advanced; Name = "Hidden"; Value = 1; Default = 2 })

    $catalog += New-WinForgeRegistryTweak -Id "taskbar-left" -Category (Get-WinForgeText 'Barra de tarefas e Iniciar') -Name (Get-WinForgeText 'Barra de tarefas alinhada à esquerda') `
        -Description (Get-WinForgeText 'Move o menu Iniciar e os ícones para a esquerda, como no Windows 10.') -Cosmetic -RestartExplorer -Windows11Only `
        -Changes @(@{ Path = $advanced; Name = "TaskbarAl"; Value = 0; Default = 1 })

    $classicClsid = "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}"
    $classicKey = "$classicClsid\InprocServer32"

    $catalog += New-WinForgeTweak -Id "classic-context-menu" -Category (Get-WinForgeText 'Explorador') -Name (Get-WinForgeText 'Menu de contexto clássico') `
        -Description (Get-WinForgeText 'O clique direito mostra logo o menu completo, sem o passo extra de Mostrar mais opções.') -RestartExplorer -UserScope -Windows11Only `
        -Capture ({ return [ordered]@{ Existed = (Test-WinForgeRegistryKey -Path $classicKey) } }.GetNewClosure()) `
        -Apply ({ Set-WinForgeRegistryKeyDefault -Path $classicKey -Value "" }.GetNewClosure()) `
        -Revert ({
            param($Saved)

            # Sem informação do estado anterior, desfaz mesmo assim: a chave só existe por causa deste ajuste.
            $existed = Test-WinForgeRegistryKey -Path $classicKey
            Remove-WinForgeRegistryKey -Path $classicKey
            Remove-WinForgeRegistryKey -Path $classicClsid -OnlyIfEmpty

            return (New-WinForgeTweakRevertReport -Restored $(if ($existed) { 1 } else { 0 }) -Kept $(if ($existed) { 0 } else { 1 }))
        }.GetNewClosure()) `
        -Test ({ return (Test-WinForgeRegistryKey -Path $classicKey) }.GetNewClosure())

    $catalog += New-WinForgeRegistryTweak -Id "explorer-this-pc" -Category (Get-WinForgeText 'Explorador') -Name (Get-WinForgeText 'Abrir o Explorador em Este Computador') `
        -Description (Get-WinForgeText 'O Explorador abre mostrando as unidades e pastas do PC, em vez dos arquivos recentes.') `
        -Changes @(@{ Path = $advanced; Name = "LaunchTo"; Value = 1 })

    # A opção chegou com o Windows 11 23H2 (build 22631, atualização de novembro de 2023); antes dela, o valor não faz nada.
    $catalog += New-WinForgeRegistryTweak -Id "taskbar-end-task" -Category (Get-WinForgeText 'Barra de tarefas e Iniciar') -Name (Get-WinForgeText 'Finalizar tarefa pela barra de tarefas') `
        -Description (Get-WinForgeText 'O clique direito num programa travado na barra de tarefas ganha a opção Finalizar tarefa.') -Cosmetic -RestartExplorer -Windows11Only -MinBuild 22631 `
        -Changes @(@{ Path = "$advanced\TaskbarDeveloperSettings"; Name = "TaskbarEndTask"; Value = 1 })

    $catalog += New-WinForgeRegistryTweak -Id "taskbar-search" -Category (Get-WinForgeText 'Barra de tarefas e Iniciar') -Name (Get-WinForgeText 'Ocultar a pesquisa da barra de tarefas') `
        -Description (Get-WinForgeText 'Libera espaço na barra; para pesquisar, abra o Iniciar e comece a digitar.') -Cosmetic -RestartExplorer `
        -Protected @{
            Shortcut   = "Taskbar"
            Apply      = (Get-WinForgeText 'Nas Configurações do Windows, em Personalização, Barra de tarefas, escolha Ocultar em Pesquisa.')
            Undo       = (Get-WinForgeText 'Nas Configurações do Windows, em Personalização, Barra de tarefas, escolha como a pesquisa aparece em Pesquisa.')
            Apply10    = (Get-WinForgeText 'Clique com o botão direito na barra de tarefas, vá em Pesquisar e escolha Oculto.')
            Undo10     = (Get-WinForgeText 'Clique com o botão direito na barra de tarefas, vá em Pesquisar e escolha Mostrar caixa de pesquisa.')
            Shortcut10 = ""
        } `
        -Changes @(@{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"; Name = "SearchboxTaskbarMode"; Value = 0 })

    $catalog += New-WinForgeRegistryTweak -Id "task-view-button" -Category (Get-WinForgeText 'Barra de tarefas e Iniciar') -Name (Get-WinForgeText 'Ocultar o botão Visão de Tarefas') `
        -Description (Get-WinForgeText 'Tira o botão da barra de tarefas; a Visão de Tarefas continua no atalho Windows + Tab.') -Cosmetic -RestartExplorer `
        -Changes @(@{ Path = $advanced; Name = "ShowTaskViewButton"; Value = 0; Default = 1 })

    $catalog += New-WinForgeRegistryTweak -Id "autoplay-off" -Category (Get-WinForgeText 'Explorador') -Name (Get-WinForgeText 'Desativar a Reprodução Automática') `
        -Description (Get-WinForgeText 'Pendrives, cartões e celulares não abrem nada sozinhos ao conectar; mais seguro contra vírus.') `
        -Changes @(@{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\AutoplayHandlers"; Name = "DisableAutoplay"; Value = 1; Default = 0 })

    # As duas opções de Opções de Pasta, Geral, Privacidade: "Mostrar arquivos usados recentemente" e "Mostrar pastas
    # usadas com frequência". Sem os valores, as duas listas aparecem.
    $catalog += New-WinForgeRegistryTweak -Id "explorer-recent" -Category (Get-WinForgeText 'Explorador') -Name (Get-WinForgeText 'Não mostrar os recentes no Explorador') `
        -Description (Get-WinForgeText 'O Explorador para de listar os arquivos usados há pouco e as pastas mais usadas.') -RestartExplorer `
        -Changes @(
            @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer"; Name = "ShowRecent"; Value = 0; Default = 1 },
            @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer"; Name = "ShowFrequent"; Value = 0; Default = 1 }
        )

    # Opções de Pasta, Modo de Exibição: "Mostrar notificações do provedor de sincronização" (os avisos do OneDrive e do
    # Microsoft 365 no alto do Explorador). Sem o valor, eles aparecem.
    $catalog += New-WinForgeRegistryTweak -Id "explorer-sync-ads" -Category (Get-WinForgeText 'Explorador') -Name (Get-WinForgeText 'Desativar os anúncios no Explorador') `
        -Description (Get-WinForgeText 'O Explorador para de mostrar avisos de produtos da Microsoft, como o OneDrive e o Microsoft 365.') -RestartExplorer `
        -Changes @(@{ Path = $advanced; Name = "ShowSyncProviderNotifications"; Value = 0; Default = 1 })

    # --- Personalização: cores e barra de tarefas ------------------------------
    $catalog += New-WinForgeRegistryTweak -Id "dark-mode" -Category (Get-WinForgeText 'Cores e transparência') -Name (Get-WinForgeText 'Modo escuro') `
        -Description (Get-WinForgeText 'Tema escuro para o Windows e para os aplicativos. Alguns programas precisam ser reabertos.') -Cosmetic `
        -Changes @(
            @{ Path = $personalize; Name = "AppsUseLightTheme"; Value = 0; Default = 1 },
            @{ Path = $personalize; Name = "SystemUsesLightTheme"; Value = 0; Default = 1 }
        ) `
        -AfterChange { Send-WinForgeSettingChange -Section "ImmersiveColorSet" }

    $catalog += New-WinForgeRegistryTweak -Id "no-transparency" -Category (Get-WinForgeText 'Cores e transparência') -Name (Get-WinForgeText 'Desativar efeitos de transparência') `
        -Description (Get-WinForgeText 'Menus e janelas sem transparência; pode melhorar a fluidez em PCs modestos.') -Cosmetic `
        -Changes @(@{ Path = $personalize; Name = "EnableTransparency"; Value = 0; Default = 1 }) `
        -AfterChange { Send-WinForgeSettingChange -Section "ImmersiveColorSet" }

    $catalog += New-WinForgeRegistryTweak -Id "show-seconds" -Category (Get-WinForgeText 'Barra de tarefas e Iniciar') -Name (Get-WinForgeText 'Mostrar segundos no relógio da barra de tarefas') `
        -Description (Get-WinForgeText 'O relógio passa a mostrar os segundos; usa um pouco mais de processador.') -Cosmetic -RestartExplorer `
        -Changes @(@{ Path = $advanced; Name = "ShowSecondsInSystemClock"; Value = 1 })

    $catalog += New-WinForgeRegistryTweak -Id "hide-widgets" -Category (Get-WinForgeText 'Barra de tarefas e Iniciar') -Name (Get-WinForgeText 'Desativar os Widgets') `
        -Description (Get-WinForgeText 'Remove o painel de notícias e clima e o botão dele na barra; vale para todas as contas do PC.') -RestartExplorer -Windows11Only `
        -Protected @{
            Shortcut     = "Taskbar"
            Apply        = (Get-WinForgeText 'Para tirar o botão dos Widgets, desligue Widgets nas Configurações do Windows, em Personalização, Barra de tarefas.')
            Undo         = (Get-WinForgeText 'Com a política gravada, a chave dos Widgets nas Configurações fica travada; no Windows Pro, o Editor de Política de Grupo (gpedit.msc) a desfaz: em Configuração do Computador, Modelos Administrativos, Componentes do Windows, Widgets, deixe a política Permitir widgets como Não configurada.')
            UndoShortcut = ""
        } `
        -Changes @(@{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Dsh"; Name = "AllowNewsAndInterests"; Value = 0 })

    # Do Windows 11 24H2 (build 26100) em diante, o Copilot é um aplicativo comum, fixado na barra como qualquer outro, e
    # este botão não existe mais: o ajuste não faria nada.
    $catalog += New-WinForgeRegistryTweak -Id "hide-copilot" -Category (Get-WinForgeText 'Barra de tarefas e Iniciar') -Name (Get-WinForgeText 'Ocultar o botão do Copilot') `
        -Description (Get-WinForgeText 'Tira o botão do Copilot da barra de tarefas; o aplicativo continua instalado.') -Cosmetic -RestartExplorer -Windows11Only -MaxBuild 26099 `
        -Changes @(@{ Path = $advanced; Name = "ShowCopilotButton"; Value = 0; Default = 1 })

    # --- Personalização: barra de tarefas, área de trabalho, cores e tela de bloqueio ---------------------------------
    # Nunca agrupar: a opção voltou no Windows 11 23H2 (build 22631); antes dela, o valor não faz nada no Windows 11.
    $catalog += New-WinForgeRegistryTweak -Id "taskbar-never-combine" -Category (Get-WinForgeText 'Barra de tarefas e Iniciar') -Name (Get-WinForgeText 'Nunca agrupar os botões da barra de tarefas') `
        -Description (Get-WinForgeText 'Cada janela ganha o próprio botão, com o nome, em vez de juntar as do mesmo programa.') -Cosmetic -RestartExplorer -Windows11Only -MinBuild 22631 `
        -Changes @(
            @{ Path = $advanced; Name = "TaskbarGlomLevel"; Value = 2; Default = 0 },
            @{ Path = $advanced; Name = "MMTaskbarGlomLevel"; Value = 2; Default = 0; State = $false }
        )

    # Os ícones da área de trabalho ficam em HideDesktopIcons: 1 esconde, 0 mostra; sem o valor, vale o padrão do Windows
    # (a Lixeira aparece, Este Computador não).
    $desktopIcons = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel"

    $catalog += New-WinForgeRegistryTweak -Id "desktop-recycle-bin" -Category (Get-WinForgeText 'Área de trabalho') -Name (Get-WinForgeText 'Ocultar a Lixeira da área de trabalho') `
        -Description (Get-WinForgeText 'O ícone sai da área de trabalho; a Lixeira continua funcionando e abre pelo Explorador.') -Cosmetic -RestartExplorer `
        -Changes @(@{ Path = $desktopIcons; Name = "{645FF040-5081-101B-9F08-00AA002F954E}"; Value = 1 })

    $catalog += New-WinForgeRegistryTweak -Id "desktop-this-pc" -Category (Get-WinForgeText 'Área de trabalho') -Name (Get-WinForgeText 'Mostrar Este Computador na área de trabalho') `
        -Description (Get-WinForgeText 'Põe na área de trabalho o ícone que abre as unidades e as pastas do PC.') -Cosmetic -RestartExplorer `
        -Changes @(@{ Path = $desktopIcons; Name = "{20D04FE0-3AEA-1069-A2D8-08002B30309D}"; Value = 0 })

    $catalog += New-WinForgeRegistryTweak -Id "accent-taskbar" -Category (Get-WinForgeText 'Cores e transparência') -Name (Get-WinForgeText 'Cor de destaque no Iniciar e na barra de tarefas') `
        -Description (Get-WinForgeText 'Pinta o Iniciar e a barra de tarefas com a cor de destaque; só com o Windows no modo escuro.') -Cosmetic `
        -Changes @(@{ Path = $personalize; Name = "ColorPrevalence"; Value = 1; Default = 0 }) `
        -AfterChange { Send-WinForgeSettingChange -Section "ImmersiveColorSet" }

    $catalog += New-WinForgeRegistryTweak -Id "accent-titlebars" -Category (Get-WinForgeText 'Cores e transparência') -Name (Get-WinForgeText 'Cor de destaque nas barras de título') `
        -Description (Get-WinForgeText 'A barra de título e a borda das janelas ganham a cor de destaque.') -Cosmetic `
        -Changes @(@{ Path = "HKCU:\Software\Microsoft\Windows\DWM"; Name = "ColorPrevalence"; Value = 1; Default = 0 }) `
        -AfterChange { Send-WinForgeSettingChange -Section "ImmersiveColorSet" }

    # Os widgets da tela de bloqueio (Windows 11): o valor do usuário que a chave das Configurações grava, e não a política
    # (que trava a chave e só vale em algumas edições). O painel e o botão dos Widgets ficam.
    $catalog += New-WinForgeRegistryTweak -Id "lock-screen-widgets" -Category (Get-WinForgeText 'Tela de bloqueio') -Name (Get-WinForgeText 'Remover os widgets da tela de bloqueio') `
        -Description (Get-WinForgeText 'Tira o clima, as notícias e as cotações que aparecem com o PC bloqueado.') -Windows11Only `
        -Changes @(@{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Lock Screen"; Name = "LockScreenWidgetsEnabled"; Value = 0 })

    $catalog += New-WinForgeRegistryTweak -Id "lock-screen-notifications" -Category (Get-WinForgeText 'Tela de bloqueio') -Name (Get-WinForgeText 'Não mostrar notificações na tela de bloqueio') `
        -Description (Get-WinForgeText 'Avisos de mensagens e programas não aparecem com o PC bloqueado; mais privacidade.') `
        -Changes @(
            @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\PushNotifications"; Name = "LockScreenToastEnabled"; Value = 0; Default = 1; State = $false },
            @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings"; Name = "NOC_GLOBAL_SETTING_ALLOW_TOASTS_ABOVE_LOCK"; Value = 0 }
        )

    # --- Privacidade e sugestões --------------------------------------------
    $catalog += New-WinForgeRegistryTweak -Id "tips-suggestions" -Category (Get-WinForgeText 'Privacidade e sugestões') -Name (Get-WinForgeText 'Desativar dicas e sugestões do Windows') `
        -Description (Get-WinForgeText 'O Windows para de mostrar sugestões e a tela Vamos terminar de configurar o seu dispositivo.') -Recommended `
        -Changes @(
            @{ Path = $content; Name = "SoftLandingEnabled"; Value = 0; Default = 1; State = $false },
            @{ Path = $content; Name = "SystemPaneSuggestionsEnabled"; Value = 0; Default = 1; State = $false },
            @{ Path = $content; Name = "SubscribedContent-338389Enabled"; Value = 0; Default = 1 },
            @{ Path = $content; Name = "SubscribedContent-353698Enabled"; Value = 0; Default = 1; State = $false },
            @{ Path = $content; Name = "SubscribedContent-310093Enabled"; Value = 0; Default = 1; State = $false },
            @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement"; Name = "ScoobeSystemSettingEnabled"; Value = 0; Default = 1; State = $false }
        )

    $catalog += New-WinForgeRegistryTweak -Id "lock-screen-tips" -Category (Get-WinForgeText 'Tela de bloqueio') -Name (Get-WinForgeText 'Desativar dicas da tela de bloqueio') `
        -Description (Get-WinForgeText 'Remove as dicas e curiosidades exibidas sobre a imagem da tela de bloqueio.') -Recommended `
        -Changes @(
            @{ Path = $content; Name = "RotatingLockScreenOverlayEnabled"; Value = 0; Default = 1 },
            @{ Path = $content; Name = "SubscribedContent-338387Enabled"; Value = 0; Default = 1 }
        ) `
        -AfterChange { Send-WinForgeSettingChange -Section "ContentDeliveryManager" }

    $catalog += New-WinForgeRegistryTweak -Id "advertising-id" -Category (Get-WinForgeText 'Privacidade e sugestões') -Name (Get-WinForgeText 'Desativar o ID de publicidade') `
        -Description (Get-WinForgeText 'Os aplicativos deixam de usar um identificador seu para personalizar anúncios.') -Recommended `
        -Changes @(@{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo"; Name = "Enabled"; Value = 0; Default = 1 })

    $catalog += New-WinForgeRegistryTweak -Id "bing-start" -Category (Get-WinForgeText 'Privacidade e sugestões') -Name (Get-WinForgeText 'Desativar resultados da web na busca do Iniciar') `
        -Description (Get-WinForgeText 'A busca do Iniciar fica só no PC, sem o Bing; o Explorador deixa de sugerir as buscas recentes.') -RestartExplorer `
        -Changes @(@{ Path = "HKCU:\Software\Policies\Microsoft\Windows\Explorer"; Name = "DisableSearchBoxSuggestions"; Value = 1 })

    # O Recall chegou com o Windows 11 24H2 (build 26100), nos PCs Copilot+; antes dele, a política não tem o que desligar.
    # A política vale para o computador (HKLM) e para o usuário; a Microsoft a documenta nos dois.
    $catalog += New-WinForgeRegistryTweak -Id "recall" -Category (Get-WinForgeText 'Privacidade e sugestões') -Name (Get-WinForgeText 'Desativar o Recall') `
        -Description (Get-WinForgeText 'Impede o Windows de salvar instantâneos periódicos da tela nos PCs que têm o recurso.') -Windows11Only -MinBuild 26100 `
        -Changes @(@{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI"; Name = "DisableAIDataAnalysis"; Value = 1 })

    $catalog += New-WinForgeRegistryTweak -Id "start-recommendations" -Category (Get-WinForgeText 'Barra de tarefas e Iniciar') -Name (Get-WinForgeText 'Desativar recomendações do Iniciar') `
        -Description (Get-WinForgeText 'O Iniciar deixa de sugerir dicas, atalhos e aplicativos novos.') -RestartExplorer -Windows11Only `
        -Changes @(@{ Path = $advanced; Name = "Start_IrisRecommendations"; Value = 0; Default = 1 })

    $catalog += New-WinForgeRegistryTweak -Id "tailored-experiences" -Category (Get-WinForgeText 'Privacidade e sugestões') -Name (Get-WinForgeText 'Desativar experiências personalizadas') `
        -Description (Get-WinForgeText 'A Microsoft para de usar os dados de diagnóstico para mostrar dicas e anúncios sob medida.') `
        -Changes @(@{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy"; Name = "TailoredExperiencesWithDiagnosticDataEnabled"; Value = 0; Default = 1 })

    $catalog += New-WinForgeRegistryTweak -Id "feedback-requests" -Category (Get-WinForgeText 'Privacidade e sugestões') -Name (Get-WinForgeText 'Não pedir opinião sobre o Windows') `
        -Description (Get-WinForgeText 'O Windows para de abrir pesquisas pedindo a sua avaliação.') `
        -Changes @(@{ Path = "HKCU:\Software\Microsoft\Siuf\Rules"; Name = "NumberOfSIUFInPeriod"; Value = 0 })

    $catalog += New-WinForgeRegistryTweak -Id "activity-history" -Category (Get-WinForgeText 'Privacidade e sugestões') -Name (Get-WinForgeText 'Desativar o histórico de atividades') `
        -Description (Get-WinForgeText 'O Windows deixa de guardar e enviar a lista do que você abriu e fez no PC.') `
        -Changes @(
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"; Name = "PublishUserActivities"; Value = 0 },
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"; Name = "UploadUserActivities"; Value = 0 }
        )

    $catalog += New-WinForgeRegistryTweak -Id "diagnostic-data" -Category (Get-WinForgeText 'Privacidade e sugestões') -Name (Get-WinForgeText 'Enviar só os dados de diagnóstico obrigatórios') `
        -Description (Get-WinForgeText 'O Windows envia à Microsoft só o mínimo; nas Configurações, a opção aparece como gerenciada.') `
        -Changes @(@{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"; Name = "AllowTelemetry"; Value = 1; Also = @(0) })

    $catalog += New-WinForgeRegistryTweak -Id "app-tracking" -Category (Get-WinForgeText 'Privacidade e sugestões') -Name (Get-WinForgeText 'Não acompanhar os programas abertos') `
        -Description (Get-WinForgeText 'O Iniciar e a busca deixam de usar os programas que você mais abre para montar as listas.') -RestartExplorer `
        -Changes @(@{ Path = $advanced; Name = "Start_TrackProgs"; Value = 0; Default = 1 })

    $catalog += New-WinForgeRegistryTweak -Id "online-speech" -Category (Get-WinForgeText 'Privacidade e sugestões') -Name (Get-WinForgeText 'Desativar o reconhecimento de fala online') `
        -Description (Get-WinForgeText 'A voz não vai mais para a Microsoft; o ditado e outros recursos online podem parar.') -OnByDefault `
        -Changes @(@{ Path = "HKCU:\Software\Microsoft\Speech_OneCore\Settings\OnlineSpeechPrivacy"; Name = "HasAccepted"; Value = 0; Default = 1; AbsentIsTarget = $true })

    $catalog += New-WinForgeRegistryTweak -Id "inking-typing" -Category (Get-WinForgeText 'Privacidade e sugestões') -Name (Get-WinForgeText 'Não personalizar digitação e escrita à mão') `
        -Description (Get-WinForgeText 'O Windows deixa de montar um dicionário seu a partir do que você digita e escreve com a caneta.') `
        -Changes @(
            @{ Path = "HKCU:\Software\Microsoft\InputPersonalization"; Name = "RestrictImplicitInkCollection"; Value = 1; Default = 0 },
            @{ Path = "HKCU:\Software\Microsoft\InputPersonalization"; Name = "RestrictImplicitTextCollection"; Value = 1; Default = 0 },
            @{ Path = "HKCU:\Software\Microsoft\InputPersonalization\TrainedDataStore"; Name = "HarvestContacts"; Value = 0; Default = 1 }
        )

    # Configurações, Privacidade e segurança, Permissões de pesquisa: "Mostrar destaques da pesquisa" (datas, notícias e
    # ilustrações do dia na pesquisa). Chegou numa atualização de 2022 do Windows 10 21H2 e do Windows 11; sem o valor, ele
    # aparece.
    $catalog += New-WinForgeRegistryTweak -Id "search-highlights" -Category (Get-WinForgeText 'Privacidade e sugestões') -Name (Get-WinForgeText 'Desativar os destaques da pesquisa') `
        -Description (Get-WinForgeText 'A pesquisa do Windows para de mostrar datas comemorativas, notícias e ilustrações do dia.') -MinBuild 19044 `
        -Changes @(@{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings"; Name = "IsDynamicSearchBoxEnabled"; Value = 0; Default = 1 })

    # --- Windows Update -----------------------------------------------------------
    # A opção "Receba as atualizações mais recentes assim que estiverem disponíveis", na página do Windows Update nas
    # Configurações: sem o valor, ela vem desligada.
    $catalog += New-WinForgeRegistryTweak -Id "early-updates" -Category (Get-WinForgeText 'Windows Update') -Name (Get-WinForgeText 'Não receber as atualizações antes da hora') `
        -Description (Get-WinForgeText 'O Windows recebe as novidades no ritmo normal, junto com todo mundo, e não assim que saem.') -OnByDefault `
        -Changes @(@{ Path = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"; Name = "IsContinuousInnovationOptedIn"; Value = 0; Default = 1; AbsentIsTarget = $true })

    $catalog += New-WinForgeRegistryTweak -Id "delivery-peers" -Category (Get-WinForgeText 'Windows Update') -Name (Get-WinForgeText 'Não compartilhar atualizações com outros PCs') `
        -Description (Get-WinForgeText 'O Windows baixa as atualizações só da Microsoft, sem enviar partes delas a outros computadores.') `
        -Changes @(@{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization"; Name = "DODownloadMode"; Value = 0; Also = @(99, 100) })

    # --- Notificações e teclado --------------------------------------------------
    $catalog += New-WinForgeRegistryTweak -Id "notifications-off" -Category (Get-WinForgeText 'Notificações e teclado') -Name (Get-WinForgeText 'Desativar as notificações') `
        -Description (Get-WinForgeText 'Nenhum programa mostra avisos no canto da tela, nem o WinForge. Vale após sair e entrar.') `
        -Changes @(@{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\PushNotifications"; Name = "ToastEnabled"; Value = 0; Default = 1 })

    # As opções de acessibilidade do teclado são texto (Flags) com várias opções em bits; o do atalho é o 4: sem ele, Shift 5
    # vezes não liga as Teclas de Aderência, segurar o Shift direito não liga as de Filtragem e segurar o Num Lock não liga
    # as de Alternância. Só esse bit muda: as outras opções que a pessoa escolheu ficam como estão. A chave mostra o atalho
    # das Teclas de Aderência, o que as Configurações do Windows mostram. Sync-WinForgeAccessibilityKeys aplica na hora.
    $access = "HKCU:\Control Panel\Accessibility"
    $accessKeys = @(
        @{ Path = "$access\StickyKeys"; Default = "510" },
        @{ Path = "$access\Keyboard Response"; Default = "126" },
        @{ Path = "$access\ToggleKeys"; Default = "62" }
    )

    $catalog += New-WinForgeTweak -Id "sticky-keys-shortcut" -Category (Get-WinForgeText 'Notificações e teclado') -Name (Get-WinForgeText 'Desativar o atalho das Teclas de Aderência') `
        -Description (Get-WinForgeText 'Apertar o Shift 5 vezes ou segurar o Shift ou o Num Lock não abre mais o aviso de acessibilidade.') -UserScope `
        -Capture ({
            return @(foreach ($key in $accessKeys) {
                    $value = Get-WinForgeRegistryValueOrNull -Path $key.Path -Name "Flags"
                    [ordered]@{ Path = $key.Path; Name = "Flags"; Exists = ($null -ne $value); Kind = [string](Get-WinForgeRegistryValueKind -Path $key.Path -Name "Flags"); Value = $value }
                })
        }.GetNewClosure()) `
        -Apply ({
            foreach ($key in $accessKeys) {
                $flags = Get-WinForgeAccessibilityFlags -Path $key.Path -Default $key.Default
                Set-WinForgeRegistryValue -Path $key.Path -Name "Flags" -Kind "String" -Value ([string]($flags -band (-bnot 4)))
            }

            Sync-WinForgeAccessibilityKeys
        }.GetNewClosure()) `
        -Revert ({
            param($Saved)

            # Cada tecla ainda sem o atalho volta ao original guardado; sem ele, só o bit do atalho volta. Uma já com o atalho
            # (mudada depois) fica como está.
            $restored = 0
            $kept = 0

            foreach ($key in $accessKeys) {
                $flags = Get-WinForgeAccessibilityFlags -Path $key.Path -Default $key.Default

                if ($flags -band 4) { $kept++; continue }

                $restored++
                $entry = @(@($Saved) | Where-Object { $null -ne $_ -and [string](Get-WinForgeTweakField -Entry $_ -Name "Path" -Default "") -eq $key.Path }) | Select-Object -First 1

                if ($null -ne $entry) {
                    Restore-WinForgeTweakRegistryValue -Path $key.Path -Name "Flags" -Saved $entry
                }
                else {
                    Set-WinForgeRegistryValue -Path $key.Path -Name "Flags" -Kind "String" -Value ([string]($flags -bor 4))
                }
            }

            if ($restored -gt 0) { Sync-WinForgeAccessibilityKeys }

            return (New-WinForgeTweakRevertReport -Restored $restored -Kept $kept)
        }.GetNewClosure()) `
        -Test ({ return (-not ((Get-WinForgeAccessibilityFlags -Path $accessKeys[0].Path -Default $accessKeys[0].Default) -band 4)) }.GetNewClosure())

    $catalog += New-WinForgeRegistryTweak -Id "clipboard-history" -Category (Get-WinForgeText 'Notificações e teclado') -Name (Get-WinForgeText 'Ativar o histórico da área de transferência') `
        -Description (Get-WinForgeText 'Windows + V mostra o que você copiou antes, e não só o último item.') `
        -Changes @(@{ Path = "HKCU:\Software\Microsoft\Clipboard"; Name = "EnableClipboardHistory"; Value = 1 })

    # --- Jogos ---------------------------------------------------------------
    $catalog += New-WinForgeRegistryTweak -Id "game-bar" -Category (Get-WinForgeText 'Jogos') -Name (Get-WinForgeText 'Desativar Xbox Game Bar e Game DVR') `
        -Description (Get-WinForgeText 'Para a gravação de jogos em segundo plano e o botão Xbox do controle que abre a Game Bar.') `
        -Changes @(
            @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR"; Name = "AppCaptureEnabled"; Value = 0; Default = 1 },
            @{ Path = "HKCU:\System\GameConfigStore"; Name = "GameDVR_Enabled"; Value = 0; Default = 1 },
            @{ Path = "HKCU:\Software\Microsoft\GameBar"; Name = "ShowStartupPanel"; Value = 0; Default = 1; State = $false },
            @{ Path = "HKCU:\Software\Microsoft\GameBar"; Name = "UseNexusForGameBarEnabled"; Value = 0; Default = 1 },
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR"; Name = "AllowGameDVR"; Value = 0; State = $false }
        ) `
        -AfterChange {
            Get-Process -Name "GameBar", "GameBarFTServer", "GameBarPresenceWriter" -ErrorAction SilentlyContinue |
                Stop-Process -Force -ErrorAction SilentlyContinue
        }

    # O Modo de Jogo vem ativado no Windows: sem o valor AutoGameModeEnabled (o que a chave das Configurações grava), ele
    # está ativado. Aplicar grava 1 e guarda o que havia; desfazer grava 0 (o original guardado é sempre o desativado,
    # porque o ajuste só é aplicado com o Modo de Jogo desativado).
    $gameBar = "HKCU:\Software\Microsoft\GameBar"

    $catalog += New-WinForgeTweak -Id "game-mode" -Category (Get-WinForgeText 'Jogos') -Name (Get-WinForgeText 'Ativar o Modo de Jogo') `
        -Description (Get-WinForgeText 'Liga o Modo de Jogo, se algo o desligou: o Windows prioriza o jogo aberto.') -UserScope -OnByDefault `
        -Capture ({
            $kind = [string](Get-WinForgeRegistryValueKind -Path $gameBar -Name "AutoGameModeEnabled")
            $value = Get-WinForgeRegistryValueOrNull -Path $gameBar -Name "AutoGameModeEnabled"
            return [ordered]@{ Exists = ($null -ne $value); Kind = $kind; Value = $value }
        }.GetNewClosure()) `
        -Apply ({ Set-WinForgeRegistryDWord -Path $gameBar -Name "AutoGameModeEnabled" -Value 1 }.GetNewClosure()) `
        -Revert ({
            param($Saved)

            # Desfazer desativa o Modo de Jogo, com ou sem backup: o original guardado ao aplicar é sempre o desativado.
            Set-WinForgeRegistryDWord -Path $gameBar -Name "AutoGameModeEnabled" -Value 0
            return (New-WinForgeTweakRevertReport -Restored 1)
        }.GetNewClosure()) `
        -Test ({
            $value = Get-WinForgeRegistryValueOrNull -Path $gameBar -Name "AutoGameModeEnabled"
            return ($null -eq $value -or [int]$value -ne 0)
        }.GetNewClosure())

    # "Aumentar a precisão do ponteiro" do Painel de Controle: os três valores (texto) zerados a desligam. Sync-WinForgeMouseSettings
    # aplica na hora.
    $catalog += New-WinForgeRegistryTweak -Id "mouse-acceleration" -Category (Get-WinForgeText 'Jogos') -Name (Get-WinForgeText 'Desativar a aceleração do mouse') `
        -Description (Get-WinForgeText 'O ponteiro anda sempre na mesma proporção do mouse: a mira fica mais previsível nos jogos.') `
        -Changes @(
            @{ Path = "HKCU:\Control Panel\Mouse"; Name = "MouseSpeed"; Value = "0"; Default = "1"; Kind = "String" },
            @{ Path = "HKCU:\Control Panel\Mouse"; Name = "MouseThreshold1"; Value = "0"; Default = "6"; Kind = "String" },
            @{ Path = "HKCU:\Control Panel\Mouse"; Name = "MouseThreshold2"; Value = "0"; Default = "10"; Kind = "String" }
        ) `
        -AfterChange { Sync-WinForgeMouseSettings }

    # --- Energia e desempenho (a ordem importa: o plano vem antes dos ajustes feitos nele) --------------------
    # Configurações, Sistema, Armazenamento, Sensor de Armazenamento: com o padrão do Windows, ele roda quando o disco fica
    # com pouco espaço, apaga temporários dos aplicativos e o que está na Lixeira há mais de 30 dias (os Downloads, nunca).
    # Sem o valor, ele está desligado.
    $catalog += New-WinForgeRegistryTweak -Id "storage-sense" -Category (Get-WinForgeText 'Energia e desempenho') -Name (Get-WinForgeText 'Ativar o Sensor de Armazenamento') `
        -Description (Get-WinForgeText 'Com o disco cheio, o Windows apaga temporários e o que está há mais de 30 dias na Lixeira.') `
        -Changes @(@{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy"; Name = "01"; Value = 1; Default = 0 })

    # Configurações, Privacidade, Aplicativos em segundo plano: "Permitir que os aplicativos sejam executados em segundo
    # plano", a chave geral que só o Windows 10 tem (no 11, a escolha é por aplicativo). As Configurações gravam os dois
    # valores; o que decide é o GlobalUserDisabled.
    $catalog += New-WinForgeRegistryTweak -Id "background-apps" -Category (Get-WinForgeText 'Energia e desempenho') -Name (Get-WinForgeText 'Desativar os aplicativos em segundo plano') `
        -Description (Get-WinForgeText 'Poupa memória e bateria, mas os avisos e alarmes dos aplicativos da Store podem não chegar.') -MaxBuild 19045 `
        -Changes @(
            @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications"; Name = "GlobalUserDisabled"; Value = 1; Default = 0 },
            @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"; Name = "BackgroundAppGlobalToggle"; Value = 0; Default = 1; State = $false }
        )

    # A Inicialização Rápida precisa da hibernação: com a hibernação desligada, ela também está desligada, e a chave mostra
    # isso. Desativar grava HiberbootEnabled = 0. Desfazer devolve o valor de antes (sem ele, 1); pela chave, se a
    # hibernação estiver desligada, liga a hibernação também, senão a Inicialização Rápida continuaria desligada.
    $hibernateKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Power"

    $catalog += New-WinForgeTweak -Id "fast-startup" -Category (Get-WinForgeText 'Energia e desempenho') -Name (Get-WinForgeText 'Desativar Inicialização Rápida') `
        -Description (Get-WinForgeText 'O PC desliga por completo, o que evita problemas de driver; pode demorar um pouco mais para ligar.') -Advanced -RequiresAdmin `
        -Capture ({
            $value = Get-WinForgeRegistryValueOrNull -Path $power -Name "HiberbootEnabled"
            return [ordered]@{ Path = $power; Name = "HiberbootEnabled"; Exists = ($null -ne $value); Kind = [string](Get-WinForgeRegistryValueKind -Path $power -Name "HiberbootEnabled"); Value = $value }
        }.GetNewClosure()) `
        -Apply ({ Set-WinForgeRegistryDWord -Path $power -Name "HiberbootEnabled" -Value 0 }.GetNewClosure()) `
        -Revert ({
            param($Saved)

            $restored = 0
            $kept = 0
            $note = ""
            $now = Get-WinForgeRegistryValueOrNull -Path $power -Name "HiberbootEnabled"

            # Backups da 3.49 e de antes guardavam uma lista com um valor.
            $entry = @(@($Saved) | Where-Object { $null -ne $_ }) | Select-Object -First 1

            if ($null -ne $now -and [int]$now -eq 0) {
                $restored++

                if ($null -ne $entry) {
                    Restore-WinForgeTweakRegistryValue -Path $power -Name "HiberbootEnabled" -Saved $entry
                }
                else {
                    Set-WinForgeRegistryDWord -Path $power -Name "HiberbootEnabled" -Value 1
                }
            }
            else {
                $kept++
            }

            if (Test-WinForgeTweakSwitchRevert) {
                $hibernation = Get-WinForgeRegistryValueOrNull -Path $hibernateKey -Name "HibernateEnabled"

                if ($null -ne $hibernation -and [int]$hibernation -eq 0) {
                    [void](Invoke-WinForgePowercfg -Arguments @("/hibernate", "on"))
                    $note = (Get-WinForgeText 'A Inicialização Rápida precisa da hibernação: a hibernação foi ativada também.')
                    Write-WinForgeStatus -Type Info -Message $note
                    $restored++
                    if ($kept -gt 0) { $kept-- }
                }
            }

            return (New-WinForgeTweakRevertReport -Restored $restored -Kept $kept -Note $note)
        }.GetNewClosure()) `
        -Test ({
            $hibernation = Get-WinForgeRegistryValueOrNull -Path $hibernateKey -Name "HibernateEnabled"
            if ($null -ne $hibernation -and [int]$hibernation -eq 0) { return $true }

            $value = Get-WinForgeRegistryValueOrNull -Path $power -Name "HiberbootEnabled"
            return ($null -ne $value -and [int]$value -eq 0)
        }.GetNewClosure())

    # Nos PCs com Modern Standby, a Microsoft só permite o plano Equilibrado e os derivados dele: lá, o ajuste não aparece
    # (o modo de energia das Configurações do Windows é o caminho).
    $catalog += New-WinForgeTweak -Id "high-performance" -Category (Get-WinForgeText 'Energia e desempenho') -Name (Get-WinForgeText 'Plano de energia Alto desempenho') `
        -Description (Get-WinForgeText 'Prioriza o desempenho; o PC passa a gastar mais energia.') -Advanced -LaptopRisk -RequiresAdmin -NotOnModernStandby `
        -Warning (Get-WinForgeText 'Em notebook, consome mais bateria e esquenta mais.') `
        -Capture { return [ordered]@{ SchemeGuid = (Get-WinForgeActivePowerSchemeGuid) } } `
        -Merge {
            param ($Previous, $Snapshot)

            # O plano a que voltar é o de agora; a cópia do Alto desempenho criada antes continua anotada, para ser
            # reaproveitada (em vez de criar outra) e apagada ao desfazer.
            $merged = [ordered]@{ SchemeGuid = (Get-WinForgeTweakField -Entry $Snapshot -Name "SchemeGuid") }
            $created = [string](Get-WinForgeTweakField -Entry $Previous -Name "CreatedGuid" -Default "")

            if (Test-WinForgeGuidText -Text $created) { $merged["CreatedGuid"] = $created }

            return $merged
        } `
        -Apply {
            param($Saved)

            # Já num plano de alto desempenho, não há o que fazer (e nenhuma cópia nova do plano é criada).
            if (Test-WinForgeHighPerformanceActive) { return }

            $created = [string](Get-WinForgeTweakField -Entry $Saved -Name "CreatedGuid" -Default "")
            $plan = Set-WinForgeHighPerformancePowerPlan -ThrowOnFailure -PreferredGuid $created -PassThru

            if ($null -ne $plan -and $plan.Created) {
                Set-WinForgeTweakOriginalValue -Id "high-performance" -Name "CreatedGuid" -Value $plan.Guid
            }
        } `
        -Revert {
            param($Saved)

            # Volta ao plano que estava ativo antes; se ele não existe mais, usa o Equilibrado. Só se o plano ativo ainda é o
            # que o ajuste ativou (o Alto desempenho ou a cópia dele que o WinForge criou): se a pessoa trocou de plano
            # depois, até para o Desempenho Máximo, a escolha dela fica. Sem conseguir ler o plano ativo, nada muda e o erro
            # sobe (o backup fica, para uma nova tentativa).
            $active = Get-WinForgeActivePowerScheme

            if ($null -eq $active) { throw (Get-WinForgeText 'não foi possível ler o plano de energia ativo; nada foi alterado.') }

            $created = ([string](Get-WinForgeTweakField -Entry $Saved -Name "CreatedGuid" -Default "")).ToLowerInvariant()
            $ours = ($active.Guid -eq (Get-WinForgeHighPerformancePlanGuid) -or ((Test-WinForgeGuidText -Text $created) -and $active.Guid -eq $created))

            # Pela chave, a pessoa quer sair do alto desempenho, seja qual for (o Desempenho Máximo, uma cópia): o plano de
            # antes, ou o Equilibrado.
            if (-not $ours -and (Test-WinForgeTweakSwitchRevert) -and (Test-WinForgeHighPerformanceActive)) { $ours = $true }

            if ($ours) {
                $target = Get-WinForgeBalancedPlanGuid
                $previous = [string](Get-WinForgeTweakField -Entry $Saved -Name "SchemeGuid" -Default "")

                if ((Test-WinForgeGuidText -Text $previous) -and (Test-WinForgePowerSchemeExists -Guid $previous)) {
                    $target = $previous
                }

                [void](Invoke-WinForgePowercfg -Arguments @("/setactive", $target))
            }

            # A cópia do Alto desempenho que o WinForge criou só ocuparia a lista de planos.
            Remove-WinForgeCreatedPowerScheme -Guid $created

            return (New-WinForgeTweakRevertReport -Restored $(if ($ours) { 1 } else { 0 }) -Kept $(if ($ours) { 0 } else { 1 }))
        } `
        -Test { return (Test-WinForgeHighPerformanceActive) }

    $catalog += New-WinForgeTweak -Id "pcie-aspm" -Category (Get-WinForgeText 'Energia e desempenho') -Name (Get-WinForgeText 'Desativar economia de energia PCI Express') `
        -Description (Get-WinForgeText 'Pode resolver travamentos da placa de vídeo ou do SSD; o PC passa a gastar mais energia.') -Advanced -LaptopRisk -RequiresAdmin `
        -Warning (Get-WinForgeText 'Em notebook, aumenta o consumo em repouso.') `
        -Capture {
            $guid = Get-WinForgeActivePowerSchemeGuid
            $setting = Get-WinForgePowerSetting -Subgroup "SUB_PCIEXPRESS" -Setting "ASPM"

            return [ordered]@{
                SchemeGuid = $guid
                AC         = $(if ($setting) { $setting.AC } else { $null })
                DC         = $(if ($setting) { $setting.DC } else { $null })
            }
        } `
        -Merge {
            param ($Previous, $Snapshot)
            return (Merge-WinForgePowerOriginal -Previous $Previous -Snapshot $Snapshot)
        } `
        -Apply {
            Set-WinForgePowerSetting -Subgroup "SUB_PCIEXPRESS" -Setting "ASPM" -AC 0 -DC 0
            Update-WinForgeActivePowerScheme
        } `
        -Revert {
            param($Saved)

            # Cada plano em que o ajuste foi feito, se ainda existir, volta aos valores dele. Padrão do Windows: economia
            # moderada (1).
            $isApplied = { return (Test-WinForgePowerValuesAtZero -Subgroup "SUB_PCIEXPRESS" -Setting "ASPM") }

            $restored = 0
            $kept = 0

            foreach ($target in @(Get-WinForgePowerRevertTargets -Entries @(Get-WinForgePowerOriginals -Saved $Saved) -IsApplied $isApplied)) {
                $ac = Get-WinForgeTweakField -Entry $target.Entry -Name "AC"
                $dc = Get-WinForgeTweakField -Entry $target.Entry -Name "DC"
                $ac = $(if ($null -ne $ac) { [int64]$ac } else { 1 })
                $dc = $(if ($null -ne $dc) { [int64]$dc } else { 1 })

                # Um lado (tomada ou bateria) que não está mais em 0, o alvo do ajuste, foi mudado depois: fica como está.
                # Sem conseguir ler, volta ao original, como antes.
                $now = Get-WinForgePowerSetting -Subgroup "SUB_PCIEXPRESS" -Setting "ASPM" -Scheme $target.Scheme
                if ($null -ne $now -and $now.AC -ne 0) { $ac = $now.AC; $kept++ } else { $restored++ }
                if ($null -ne $now -and $now.DC -ne 0) { $dc = $now.DC; $kept++ } else { $restored++ }

                Set-WinForgePowerSetting -Subgroup "SUB_PCIEXPRESS" -Setting "ASPM" -AC $ac -DC $dc -Scheme $target.Scheme
            }

            Update-WinForgeActivePowerScheme

            return (New-WinForgeTweakRevertReport -Restored $restored -Kept $kept)
        } `
        -Test { return (Test-WinForgePowerValuesAtZero -Subgroup "SUB_PCIEXPRESS" -Setting "ASPM") }

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

    $sleepTest = {
        foreach ($item in $timeoutSettings) {
            if (-not (Test-WinForgePowerValuesAtZero -Subgroup $item.Subgroup -Setting $item.Setting)) { return $false }
        }

        return $true
    }.GetNewClosure()

    $sleepRevert = {
        param($Saved)

        # Cada plano em que o ajuste foi feito, se ainda existir, volta aos tempos dele.
        $restored = 0
        $kept = 0

        foreach ($target in @(Get-WinForgePowerRevertTargets -Entries @(Get-WinForgePowerOriginals -Saved $Saved) -IsApplied $sleepTest)) {
            foreach ($item in $timeoutSettings) {
                $entry = Get-WinForgeTweakField -Entry $target.Entry -Name $item.Key
                $ac = Get-WinForgeTweakField -Entry $entry -Name "AC"
                $dc = Get-WinForgeTweakField -Entry $entry -Name "DC"

                if ($null -eq $ac -or $null -eq $dc) {
                    $ac = $item.DefaultAC
                    $dc = $item.DefaultDC
                }

                # Um tempo que não está mais em Nunca (0) foi mudado depois: fica como está.
                $now = Get-WinForgePowerSetting -Subgroup $item.Subgroup -Setting $item.Setting -Scheme $target.Scheme
                if ($null -ne $now -and $now.AC -ne 0) { $ac = $now.AC; $kept++ } else { $restored++ }
                if ($null -ne $now -and $now.DC -ne 0) { $dc = $now.DC; $kept++ } else { $restored++ }

                Set-WinForgePowerSetting -Subgroup $item.Subgroup -Setting $item.Setting -AC ([int64]$ac) -DC ([int64]$dc) -Scheme $target.Scheme
            }
        }

        Update-WinForgeActivePowerScheme

        return (New-WinForgeTweakRevertReport -Restored $restored -Kept $kept)
    }.GetNewClosure()

    $sleepGroups = @($timeoutSettings | ForEach-Object { [string]$_.Key })

    $sleepMerge = {
        param ($Previous, $Snapshot)
        return (Merge-WinForgePowerOriginal -Previous $Previous -Snapshot $Snapshot -Groups $sleepGroups)
    }.GetNewClosure()

    $catalog += New-WinForgeTweak -Id "no-sleep-timeouts" -Category (Get-WinForgeText 'Energia e desempenho') -Name (Get-WinForgeText 'Nunca desligar a tela nem suspender') `
        -Description (Get-WinForgeText 'Tela, suspensão e hibernação automática em Nunca (tomada e bateria).') -Advanced -LaptopRisk -RequiresAdmin `
        -Warning (Get-WinForgeText 'Em notebook, a tela fica ligada na bateria até você fechar a tampa ou desligar.') `
        -Capture $sleepCapture -Apply $sleepApply -Revert $sleepRevert -Test $sleepTest -Merge $sleepMerge

    $catalog += New-WinForgeTweak -Id "hibernation" -Category (Get-WinForgeText 'Energia e desempenho') -Name (Get-WinForgeText 'Desativar hibernação') `
        -Description (Get-WinForgeText 'Apaga o arquivo de hibernação (hiberfil.sys) e libera espaço; desliga também a Inicialização Rápida.') -Advanced -LaptopRisk -RequiresAdmin `
        -Warning (Get-WinForgeText 'Em notebook, você perde a hibernação (útil quando a bateria acaba).') `
        -Capture {
            return [ordered]@{
                Enabled = (Get-WinForgeRegistryValueOrNull -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Power" -Name "HibernateEnabled")
            }
        } `
        -Apply { [void](Invoke-WinForgePowercfg -Arguments @("/hibernate", "off")) } `
        -Revert {
            param($Saved)

            # Só deixa desligada se a hibernação já estava desligada antes do WinForge; sem informação, liga (padrão). Já
            # ligada de novo (pela pessoa), não há o que fazer.
            $enabled = Get-WinForgeTweakField -Entry $Saved -Name "Enabled"
            $current = Get-WinForgeRegistryValueOrNull -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Power" -Name "HibernateEnabled"
            $offNow = ($null -ne $current -and [int]$current -eq 0)

            if ($offNow -and ($null -eq $enabled -or [string]$enabled -ne "0")) {
                [void](Invoke-WinForgePowercfg -Arguments @("/hibernate", "on"))
            }

            return (New-WinForgeTweakRevertReport -Restored $(if ($offNow) { 1 } else { 0 }) -Kept $(if ($offNow) { 0 } else { 1 }))
        } `
        -Test {
            $value = Get-WinForgeRegistryValueOrNull -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Power" -Name "HibernateEnabled"
            return ($null -ne $value -and [int]$value -eq 0)
        }

    $catalog += New-WinForgeRegistryTweak -Id "gpu-scheduling" -Category (Get-WinForgeText 'Energia e desempenho') -Name (Get-WinForgeText 'Agendamento de GPU acelerado por hardware') `
        -Description (Get-WinForgeText 'A placa de vídeo organiza a própria memória; pode reduzir atrasos em jogos. Vale após reiniciar.') -Advanced -NeedsReboot `
        -Changes @(@{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"; Name = "HwSchMode"; Value = 2; Default = 1; AbsentUnknown = $true })

    # Como cada ajuste aparece na lista (o recurso que a chave mostra); sem entrada na tabela, o próprio nome do ajuste.
    $labels = Get-WinForgeTweakSwitchLabels

    foreach ($tweak in $catalog) {
        if (-not $labels.ContainsKey([string]$tweak.Id)) { continue }

        $label = $labels[[string]$tweak.Id]
        $tweak.Feature = [string]$label.Feature
        $tweak.Inverted = [bool]$label.Inverted
        if (-not [string]::IsNullOrEmpty([string]$label.About)) { $tweak.About = [string]$label.About }
        $tweak.Short = [string]$label.Short
    }

    # Na ordem de exibição: página por página e categoria por categoria; dentro de cada categoria, na ordem acima. Uma
    # categoria fora da lista fica no fim (e não some).
    $categories = @(Get-WinForgeTweakCategories)
    $ordered = @()

    foreach ($category in $categories) {
        $ordered += @($catalog | Where-Object { $_.Category -eq $category })
    }

    $ordered += @($catalog | Where-Object { $categories -notcontains $_.Category })

    $index = @{}
    foreach ($tweak in $ordered) { if (-not $index.ContainsKey([string]$tweak.Id)) { $index[[string]$tweak.Id] = $tweak } }

    $script:WinForgeTweakIndex = $index
    $script:WinForgeTweakCatalog = @($ordered)
    return $script:WinForgeTweakCatalog
}


function Get-WinForgeTweakById {
    # Um ajuste do catálogo pelo Id, direto no índice (o desfazer, a importação e os perfis procuram um por um); $null
    # quando não existe.
    param (
        [string]$Id
    )

    if ($null -eq $script:WinForgeTweakIndex) { [void](Get-WinForgeTweakCatalog) }
    if ([string]::IsNullOrEmpty($Id) -or -not $script:WinForgeTweakIndex.ContainsKey($Id)) { return $null }

    return $script:WinForgeTweakIndex[$Id]
}


function Test-WinForgeTweakAvailable {
    param (
        [Parameter(Mandatory)]
        $Tweak
    )

    if ($Tweak.Windows11Only -and -not (Test-WinForgeWindows11)) { return $false }
    if ([bool](Get-WinForgeTweakField -Entry $Tweak -Name "NotOnModernStandby" -Default $false) -and (Test-WinForgeModernStandby)) { return $false }

    # Os limites de build só valem com a build conhecida: num Windows de verdade ela é 10240 ou mais, e uma leitura que
    # falhou não esconde nada.
    $min = [int](Get-WinForgeTweakField -Entry $Tweak -Name "MinBuild" -Default 0)
    $max = [int](Get-WinForgeTweakField -Entry $Tweak -Name "MaxBuild" -Default 0)

    if ($min -gt 0 -or $max -gt 0) {
        $build = Get-WinForgeWindowsBuild

        if ($build -ge 10240) {
            if ($min -gt 0 -and $build -lt $min) { return $false }
            if ($max -gt 0 -and $build -gt $max) { return $false }
        }
    }

    return $true
}


function Test-WinForgeAccessDenied {
    # Se um erro é uma recusa de acesso do Windows ao registro, pelo tipo ou pelo texto, em inglês ou português. A recusa de
    # um arquivo (o backup dos ajustes, por exemplo: "Access to the path ... is denied") não conta: não é a proteção do
    # Windows sobre a configuração.
    param ($Exception)

    for ($current = $Exception; $null -ne $current; $current = $current.InnerException) {
        if ([string]$current.Message -match '(?i)access to the path|acesso ao caminho') { return $false }
    }

    for ($current = $Exception; $null -ne $current; $current = $current.InnerException) {
        if ($current -is [System.UnauthorizedAccessException] -or $current -is [System.Security.SecurityException]) { return $true }
    }

    return ([string](Get-WinForgeTweakField -Entry $Exception -Name "Message" -Default "") -match '(?i)unauthorized operation|registry access is not allowed|access is denied|operação não autorizada|acesso ao registro solicitado|acesso negado|operaci.n no autorizada|acceso al registro solicitado|acceso denegado')
}


function Get-WinForgeTweakProtectedHelp {
    <#
    Para um ajuste que o Windows protege (UCPD), onde fazer a mudança: Hint (o caminho, no sentido pedido e no Windows
    desta máquina) e Shortcut (o atalho que abre a página das Configurações, ou vazio). Ao desfazer vale UndoShortcut, se
    houver: a política dos Widgets deixa a chave das Configurações travada, e abrir a página não adiantaria. $null para os
    outros ajustes.
    #>
    param (
        [Parameter(Mandatory)]$Tweak,
        [switch]$Undo
    )

    $info = Get-WinForgeTweakField -Entry $Tweak -Name "Protected" -Default @{}
    if ($info -isnot [System.Collections.IDictionary] -or $info.Count -eq 0) { return $null }

    $suffix = $(if (Test-WinForgeWindows11) { "" } else { "10" })
    $hintKey = "$(if ($Undo) { 'Undo' } else { 'Apply' })$suffix"
    $shortcutKey = "Shortcut$suffix"

    if (-not $info.Contains($hintKey)) { $hintKey = $(if ($Undo) { "Undo" } else { "Apply" }) }
    if (-not $info.Contains($shortcutKey)) { $shortcutKey = "Shortcut" }
    if ($Undo -and $info.Contains("UndoShortcut$suffix")) { $shortcutKey = "UndoShortcut$suffix" }
    elseif ($Undo -and $info.Contains("UndoShortcut")) { $shortcutKey = "UndoShortcut" }

    return [PSCustomObject]@{
        Hint     = $(if ($info.Contains($hintKey)) { [string]$info[$hintKey] } else { "" })
        Shortcut = $(if ($info.Contains($shortcutKey)) { [string]$info[$shortcutKey] } else { "" })
    }
}


function Get-WinForgeTweakProtectedText {
    # A frase de quando o Windows recusa um ajuste protegido, com o caminho nas Configurações quando há.
    param ($Help)

    $text = (Get-WinForgeText 'O Windows protege esta configuração e não deixa o WinForge mudá-la, nem como Administrador.')
    if ($null -ne $Help -and $Help.Hint) { $text = "$text $($Help.Hint)" }

    return $text
}


function Get-WinForgeTweakStatus {
    param (
        [Parameter(Mandatory)]
        $Tweak
    )

    try {
        # Códigos (a tela mostra Get-WinForgeTweakSwitchState): não se traduzem.
        if (& $Tweak.Test) { return "Aplicado" }
        return "Padrão"
    }
    catch {
        return "Desconhecido"
    }
}


function Get-WinForgeTweakSwitchState {
    <#
    Como a chave de um ajuste aparece: ela mostra o recurso do Windows como ele está agora, ativado ou desativado, lido
    do Windows a cada vez (Status vem de Get-WinForgeTweakStatus). Num ajuste que desativa o recurso (Inverted), a chave
    fica ativada com o ajuste fora, e desativada com ele aplicado. "Desconhecido" aparece desligada e com aviso.
    Level = Normal | Muted | Warn (a janela escolhe a cor; ativado não é "bom" nem "ruim", só o estado).
    #>
    param (
        [string]$Status,
        [bool]$Inverted = $false
    )

    if ($Status -eq "Desconhecido") {
        return [PSCustomObject]@{ IsOn = $false; Caption = (Get-WinForgeText 'Não identificado'); Level = "Warn" }
    }

    $on = (($Status -eq "Aplicado") -xor $Inverted)

    return [PSCustomObject]@{ IsOn = $on; Caption = $(if ($on) { (Get-WinForgeText 'Ativado') } else { (Get-WinForgeText 'Desativado') }); Level = $(if ($on) { "Normal" } else { "Muted" }) }
}


function Get-WinForgeTweakSwitchLabels {
    <#
    Como cada ajuste aparece na lista: o recurso do Windows que a chave mostra (Feature), o que ele é (About, até 100
    caracteres, na dica e no leitor de tela), a frase da linha (Short, até 60 letras nos três idiomas, como as das ações)
    e se o ajuste o desativa (Inverted: a chave fica ativada com o ajuste fora). O nome do ajuste (Name) e a
    descrição dele continuam valendo onde se fala da mudança (recomendados, perfis, Desfazer ajustes do WinForge,
    Histórico). Nas políticas do Windows, a chave diz "Permitir": ela mostra a política, não a opção das Configurações.
    #>
    return @{
        "file-extensions"           = @{ Feature = (Get-WinForgeText 'Mostrar extensões de arquivos'); Inverted = $false; About = ""; Short = (Get-WinForgeText 'Ajuda a perceber arquivos disfarçados') }
        "hidden-files"              = @{ Feature = (Get-WinForgeText 'Mostrar arquivos e pastas ocultos'); Inverted = $false; About = (Get-WinForgeText 'Mostra o que o Windows esconde; os arquivos protegidos do sistema continuam ocultos.'); Short = (Get-WinForgeText 'Os arquivos protegidos do sistema continuam ocultos') }
        "classic-context-menu"      = @{ Feature = (Get-WinForgeText 'Menu de contexto clássico'); Inverted = $false; About = ""; Short = (Get-WinForgeText 'O clique direito abre o menu completo de uma vez') }
        "explorer-this-pc"          = @{ Feature = (Get-WinForgeText 'Abrir o Explorador em Este Computador'); Inverted = $false; About = ""; Short = (Get-WinForgeText 'As unidades e pastas do PC, em vez dos recentes') }
        "explorer-recent"           = @{ Feature = (Get-WinForgeText 'Recentes no Explorador'); Inverted = $true; About = (Get-WinForgeText 'O Explorador lista os arquivos usados há pouco e as pastas que você mais usa.'); Short = (Get-WinForgeText 'Os arquivos usados há pouco e as pastas mais usadas') }
        "explorer-sync-ads"         = @{ Feature = (Get-WinForgeText 'Avisos de produtos no Explorador'); Inverted = $true; About = (Get-WinForgeText 'Avisos do OneDrive e do Microsoft 365 no alto do Explorador.'); Short = (Get-WinForgeText 'Avisos do OneDrive e do Microsoft 365 no alto') }
        "search-highlights"         = @{ Feature = (Get-WinForgeText 'Destaques da pesquisa'); Inverted = $true; About = (Get-WinForgeText 'Datas comemorativas, notícias e ilustrações do dia na pesquisa do Windows.'); Short = (Get-WinForgeText 'Datas, notícias e ilustrações do dia na pesquisa') }
        "storage-sense"             = @{ Feature = (Get-WinForgeText 'Sensor de Armazenamento'); Inverted = $false; About = (Get-WinForgeText 'Com o disco cheio, o Windows apaga temporários e o que está há mais de 30 dias na Lixeira.'); Short = (Get-WinForgeText 'Com o disco cheio, apaga temporários e a Lixeira antiga') }
        "background-apps"           = @{ Feature = (Get-WinForgeText 'Aplicativos em segundo plano'); Inverted = $true; About = (Get-WinForgeText 'Os aplicativos da Microsoft Store rodam escondidos para avisar, tocar alarmes e se atualizar.'); Short = (Get-WinForgeText 'Aplicativos da Store rodando escondidos') }
        "autoplay-off"              = @{ Feature = (Get-WinForgeText 'Reprodução Automática'); Inverted = $true; About = (Get-WinForgeText 'Pendrives, cartões e celulares abrem algo sozinhos ao conectar; desativá-la é mais seguro.'); Short = (Get-WinForgeText 'Pendrives e celulares abrem algo sozinhos ao conectar') }
        "tips-suggestions"          = @{ Feature = (Get-WinForgeText 'Dicas e sugestões do Windows'); Inverted = $true; About = (Get-WinForgeText 'Sugestões do Windows e a tela Vamos terminar de configurar o seu dispositivo.'); Short = (Get-WinForgeText 'Sugestões e a tela Vamos terminar de configurar') }
        "advertising-id"            = @{ Feature = (Get-WinForgeText 'ID de publicidade'); Inverted = $true; About = (Get-WinForgeText 'Um identificador seu que os aplicativos usam para personalizar anúncios.'); Short = (Get-WinForgeText 'Um identificador que os aplicativos usam para anúncios') }
        "bing-start"                = @{ Feature = (Get-WinForgeText 'Resultados da web na busca do Iniciar'); Inverted = $true; About = (Get-WinForgeText 'A busca do Iniciar traz sugestões do Bing; desativar tira também as buscas recentes do Explorador.'); Short = (Get-WinForgeText 'Sugestões do Bing e as buscas recentes do Explorador') }
        "recall"                    = @{ Feature = (Get-WinForgeText 'Permitir o Recall'); Inverted = $true; About = (Get-WinForgeText 'Nos PCs que têm o recurso, o Recall pode salvar instantâneos periódicos da tela.'); Short = (Get-WinForgeText 'Instantâneos da tela, nos PCs que têm o recurso') }
        "tailored-experiences"      = @{ Feature = (Get-WinForgeText 'Experiências personalizadas'); Inverted = $true; About = (Get-WinForgeText 'A Microsoft usa os dados de diagnóstico para mostrar dicas e anúncios sob medida.'); Short = (Get-WinForgeText 'Dicas e anúncios sob medida pelos dados de diagnóstico') }
        "feedback-requests"         = @{ Feature = (Get-WinForgeText 'Pedidos de opinião sobre o Windows'); Inverted = $true; About = (Get-WinForgeText 'O Windows abre pesquisas pedindo a sua avaliação.'); Short = (Get-WinForgeText 'Pesquisas do Windows pedindo a sua avaliação') }
        "activity-history"          = @{ Feature = (Get-WinForgeText 'Permitir o histórico de atividades'); Inverted = $true; About = (Get-WinForgeText 'O Windows pode guardar e enviar a lista do que você abriu e fez no PC.'); Short = (Get-WinForgeText 'A lista do que você abriu e fez no PC') }
        "diagnostic-data"           = @{ Feature = (Get-WinForgeText 'Permitir dados de diagnóstico opcionais'); Inverted = $true; About = (Get-WinForgeText 'Além do mínimo, o Windows pode enviar à Microsoft dados de uso; desativado, só o obrigatório.'); Short = (Get-WinForgeText 'Dados de uso além do mínimo obrigatório') }
        "app-tracking"              = @{ Feature = (Get-WinForgeText 'Acompanhar os programas abertos'); Inverted = $true; About = (Get-WinForgeText 'O Iniciar e a busca usam os programas que você mais abre para montar as listas.'); Short = (Get-WinForgeText 'O Iniciar e a busca listam o que você mais abre') }
        "online-speech"             = @{ Feature = (Get-WinForgeText 'Reconhecimento de fala online'); Inverted = $true; About = (Get-WinForgeText 'A voz vai para a Microsoft no ditado e em outros recursos online.'); Short = (Get-WinForgeText 'A voz vai para a Microsoft no ditado online') }
        "inking-typing"             = @{ Feature = (Get-WinForgeText 'Personalizar a digitação e a escrita à mão'); Inverted = $true; About = (Get-WinForgeText 'O Windows monta um dicionário seu a partir do que você digita e escreve com a caneta.'); Short = (Get-WinForgeText 'Um dicionário seu, do que você digita e escreve') }
        "delivery-peers"            = @{ Feature = (Get-WinForgeText 'Permitir atualizações entre PCs'); Inverted = $true; About = (Get-WinForgeText 'O Windows baixa partes das atualizações de outros computadores e envia partes a eles.'); Short = (Get-WinForgeText 'Partes das atualizações trocadas com outros PCs') }
        "early-updates"             = @{ Feature = (Get-WinForgeText 'Receber as atualizações assim que saem'); Inverted = $true; About = (Get-WinForgeText 'O Windows instala as novidades antes de chegarem a todos, e o PC pode reiniciar mais vezes por mês.'); Short = (Get-WinForgeText 'Novidades antes de todos; o PC pode reiniciar mais') }
        "notifications-off"         = @{ Feature = (Get-WinForgeText 'Notificações'); Inverted = $true; About = (Get-WinForgeText 'Os avisos dos programas no canto da tela, os do WinForge também. A troca vale após sair e entrar.'); Short = (Get-WinForgeText 'Os avisos dos programas, os do WinForge também') }
        "sticky-keys-shortcut"      = @{ Feature = (Get-WinForgeText 'Teclas de Aderência pelo Shift'); Inverted = $true; About = (Get-WinForgeText 'Apertar o Shift 5 vezes (ou segurar o Shift ou o Num Lock) abre o aviso de acessibilidade.'); Short = (Get-WinForgeText 'Shift cinco vezes abre o aviso de acessibilidade') }
        "clipboard-history"         = @{ Feature = (Get-WinForgeText 'Histórico da área de transferência'); Inverted = $false; About = ""; Short = (Get-WinForgeText 'Windows + V mostra o que você copiou antes') }
        "game-bar"                  = @{ Feature = (Get-WinForgeText 'Xbox Game Bar e gravação de jogos'); Inverted = $true; About = (Get-WinForgeText 'A gravação de jogos em segundo plano e o botão Xbox do controle que abre a Game Bar.'); Short = (Get-WinForgeText 'A gravação em segundo plano e o botão Xbox do controle') }
        "game-mode"                 = @{ Feature = (Get-WinForgeText 'Modo de Jogo'); Inverted = $false; About = (Get-WinForgeText 'O Windows prioriza o jogo aberto e segura atualizações e avisos. Vem ativado no Windows.'); Short = (Get-WinForgeText 'Prioriza o jogo aberto; vem ativado no Windows') }
        "mouse-acceleration"        = @{ Feature = (Get-WinForgeText 'Aceleração do mouse'); Inverted = $true; About = (Get-WinForgeText 'O ponteiro anda mais quando o mouse se move rápido; desativada, a mira fica mais previsível.'); Short = (Get-WinForgeText 'O ponteiro vai mais longe com o mouse rápido') }
        "fast-startup"              = @{ Feature = (Get-WinForgeText 'Inicialização Rápida'); Inverted = $true; About = (Get-WinForgeText 'O PC não desliga por completo, para ligar mais rápido; desativar evita problemas de driver.'); Short = (Get-WinForgeText 'Liga mais rápido; desativar evita problemas de driver') }
        "high-performance"          = @{ Feature = (Get-WinForgeText 'Plano de energia Alto desempenho'); Inverted = $false; About = ""; Short = (Get-WinForgeText 'Prioriza o desempenho e gasta mais energia') }
        "pcie-aspm"                 = @{ Feature = (Get-WinForgeText 'Economia de energia do PCI Express'); Inverted = $true; About = (Get-WinForgeText 'Poupa energia da placa de vídeo e do SSD; desativar pode resolver travamentos.'); Short = (Get-WinForgeText 'Poupa energia; desativar pode resolver travamentos') }
        "no-sleep-timeouts"         = @{ Feature = (Get-WinForgeText 'Tela e suspensão automáticas'); Inverted = $true; About = (Get-WinForgeText 'Depois de um tempo parado (na tomada ou na bateria), a tela desliga e o PC suspende ou hiberna.'); Short = (Get-WinForgeText 'Parado, o PC apaga a tela e depois suspende') }
        "hibernation"               = @{ Feature = (Get-WinForgeText 'Hibernação'); Inverted = $true; About = (Get-WinForgeText 'Guarda a memória no hiberfil.sys; desativar libera espaço e desliga a Inicialização Rápida.'); Short = (Get-WinForgeText 'Desativar libera espaço e desliga a Inicialização Rápida') }
        "gpu-scheduling"            = @{ Feature = (Get-WinForgeText 'Agendamento de GPU acelerado por hardware'); Inverted = $false; About = ""; Short = (Get-WinForgeText 'Pode reduzir atrasos em jogos; vale após reiniciar') }
        "taskbar-left"              = @{ Feature = (Get-WinForgeText 'Barra de tarefas alinhada à esquerda'); Inverted = $false; About = (Get-WinForgeText 'O menu Iniciar e os ícones à esquerda, como no Windows 10; desativada, ficam no centro.'); Short = (Get-WinForgeText 'O Iniciar e os ícones à esquerda, como no Windows 10') }
        "taskbar-end-task"          = @{ Feature = (Get-WinForgeText 'Finalizar tarefa pela barra de tarefas'); Inverted = $false; About = ""; Short = (Get-WinForgeText 'Finalizar tarefa no clique direito de um programa') }
        "taskbar-search"            = @{ Feature = (Get-WinForgeText 'Pesquisa na barra de tarefas'); Inverted = $true; About = (Get-WinForgeText 'A caixa ou o ícone de pesquisa na barra; sem ela, abra o Iniciar e comece a digitar.'); Short = (Get-WinForgeText 'A caixa ou o ícone; sem ela, digite no Iniciar') }
        "task-view-button"          = @{ Feature = (Get-WinForgeText 'Botão Visão de Tarefas'); Inverted = $true; About = (Get-WinForgeText 'O botão na barra de tarefas; a Visão de Tarefas continua no atalho Windows + Tab.'); Short = (Get-WinForgeText 'A Visão de Tarefas continua no Windows + Tab') }
        "show-seconds"              = @{ Feature = (Get-WinForgeText 'Segundos no relógio da barra de tarefas'); Inverted = $false; About = (Get-WinForgeText 'O relógio mostra os segundos; usa um pouco mais de processador.'); Short = (Get-WinForgeText 'Usa um pouco mais de processador') }
        "hide-widgets"              = @{ Feature = (Get-WinForgeText 'Permitir os Widgets'); Inverted = $true; About = (Get-WinForgeText 'O painel de notícias e clima e o botão dele na barra; a política vale para todas as contas do PC.'); Short = (Get-WinForgeText 'Notícias e clima na barra; vale para todas as contas') }
        "hide-copilot"              = @{ Feature = (Get-WinForgeText 'Botão do Copilot'); Inverted = $true; About = (Get-WinForgeText 'O botão na barra de tarefas; sem ele, o aplicativo continua instalado.'); Short = (Get-WinForgeText 'Sem ele, o aplicativo continua instalado') }
        "taskbar-never-combine"     = @{ Feature = (Get-WinForgeText 'Agrupar os botões da barra de tarefas'); Inverted = $true; About = (Get-WinForgeText 'Junta as janelas do mesmo programa num botão; desativado, cada uma tem o seu, com o nome.'); Short = (Get-WinForgeText 'Desativado, cada janela tem o seu botão, com o nome') }
        "start-recommendations"     = @{ Feature = (Get-WinForgeText 'Recomendações no Iniciar'); Inverted = $true; About = (Get-WinForgeText 'O Iniciar sugere dicas, atalhos e aplicativos novos.'); Short = (Get-WinForgeText 'Dicas, atalhos e aplicativos novos no Iniciar') }
        "desktop-recycle-bin"       = @{ Feature = (Get-WinForgeText 'Ícone da Lixeira na área de trabalho'); Inverted = $true; About = (Get-WinForgeText 'O ícone da Lixeira; sem ele, a Lixeira continua funcionando e abre pelo Explorador.'); Short = (Get-WinForgeText 'Sem ele, a Lixeira continua no Explorador') }
        "desktop-this-pc"           = @{ Feature = (Get-WinForgeText 'Ícone de Este Computador na área de trabalho'); Inverted = $false; About = (Get-WinForgeText 'O ícone que abre as unidades e as pastas do PC.'); Short = (Get-WinForgeText 'Abre as unidades e as pastas do PC') }
        "dark-mode"                 = @{ Feature = (Get-WinForgeText 'Modo escuro'); Inverted = $false; About = ""; Short = (Get-WinForgeText 'O Windows e os aplicativos no tema escuro') }
        "no-transparency"           = @{ Feature = (Get-WinForgeText 'Efeitos de transparência'); Inverted = $true; About = (Get-WinForgeText 'Menus e janelas translúcidos; desativar pode deixar PCs modestos mais fluidos.'); Short = (Get-WinForgeText 'Desativar pode deixar PCs modestos mais fluidos') }
        "accent-taskbar"            = @{ Feature = (Get-WinForgeText 'Cor de destaque no Iniciar e na barra de tarefas'); Inverted = $false; About = ""; Short = (Get-WinForgeText 'Só com o Windows no modo escuro') }
        "accent-titlebars"          = @{ Feature = (Get-WinForgeText 'Cor de destaque nas barras de título'); Inverted = $false; About = ""; Short = (Get-WinForgeText 'A barra de título e a borda das janelas') }
        "lock-screen-widgets"       = @{ Feature = (Get-WinForgeText 'Clima e notícias na tela de bloqueio'); Inverted = $true; About = (Get-WinForgeText 'Os widgets (clima, notícias e cotações) que aparecem com o PC bloqueado.'); Short = (Get-WinForgeText 'Os widgets que aparecem com o PC bloqueado') }
        "lock-screen-notifications" = @{ Feature = (Get-WinForgeText 'Notificações na tela de bloqueio'); Inverted = $true; About = (Get-WinForgeText 'Avisos de mensagens e programas com o PC bloqueado; desativar dá mais privacidade.'); Short = (Get-WinForgeText 'Desativar dá mais privacidade') }
        "lock-screen-tips"          = @{ Feature = (Get-WinForgeText 'Dicas na tela de bloqueio'); Inverted = $true; About = (Get-WinForgeText 'As dicas e curiosidades exibidas sobre a imagem da tela de bloqueio.'); Short = (Get-WinForgeText 'Curiosidades sobre a imagem da tela de bloqueio') }
    }
}


function Get-WinForgeTweaksForSession {
    <#
    Dos ajustes pedidos, os que esta sessão pode aplicar. Elevado com outra conta, o HKCU é o dessa conta: um ajuste do
    perfil do usuário mudaria o perfil errado, e o estado lido também seria o dela. Esses ficam de fora, com um aviso só
    (sem -Quiet), como na revisão do Otimizar; os de sistema (HKLM) seguem.
    #>
    param (
        [AllowEmptyCollection()][object[]]$Tweaks = @(),
        [switch]$Quiet
    )

    $session = Get-WinForgeSessionInfo
    if (-not [bool](Get-WinForgeTweakField -Entry $session -Name "UserMismatch" -Default $false)) { return @($Tweaks) }

    $mine = @($Tweaks | Where-Object { -not $_.UserScope })
    $hidden = @($Tweaks).Count - $mine.Count

    if ($hidden -gt 0 -and -not $Quiet) {
        Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'O WinForge está elevado com outra conta ({0}): {1} de fora, para não mudar o perfil dessa conta.' "$([string](Get-WinForgeTweakField -Entry $session -Name 'User' -Default ''))" "$(Format-WinForgeCount -Count $hidden -One (Get-WinForgeText 'ajuste do perfil do usuário ficou') -Many (Get-WinForgeText 'ajustes do perfil do usuário ficaram'))")
    }

    return $mine
}


function Get-WinForgeTweakOverview {
    # Lista os ajustes disponíveis neste Windows, agrupados na ordem de exibição, com o estado atual: os de uma página
    # (-Page "personalize" ou "tweaks") ou todos. OtherAccount: o ajuste vale para o perfil do usuário, e o WinForge está
    # elevado com outra conta (o estado lido seria o dessa conta, e a chave não o muda).
    param ([string]$Page = "")

    $session = Get-WinForgeSessionInfo
    $otherAccount = [bool](Get-WinForgeTweakField -Entry $session -Name "UserMismatch" -Default $false)
    $categories = @(Get-WinForgeTweakCategories -Page $Page)
    $catalog = @(Get-WinForgeTweakCatalog | Where-Object { Test-WinForgeTweakAvailable -Tweak $_ })

    return @(
        foreach ($category in $categories) {
            foreach ($tweak in @($catalog | Where-Object { $_.Category -eq $category })) {
                $detail = [string](Get-WinForgeTweakField -Entry $tweak -Name "About" -Default "")
                if ([string]::IsNullOrWhiteSpace($detail)) { $detail = [string]$tweak.Description }
                $short = [string](Get-WinForgeTweakField -Entry $tweak -Name "Short" -Default "")
                if ([string]::IsNullOrWhiteSpace($short)) { $short = $detail }

                [PSCustomObject]@{
                    Id            = $tweak.Id
                    Category      = $tweak.Category

                    # O que a lista mostra: o recurso do Windows (Feature) e a frase curta (Short); a inteira (About,
                    # ou a descrição do ajuste) fica em Detail, para a dica e o leitor de tela. Action é o nome do
                    # ajuste, para onde se fala da mudança.
                    Name          = [string](Get-WinForgeTweakField -Entry $tweak -Name "Feature" -Default $tweak.Name)
                    Description   = $short
                    Detail        = $detail
                    Action        = $tweak.Name
                    Inverted      = [bool](Get-WinForgeTweakField -Entry $tweak -Name "Inverted" -Default $false)
                    Advanced      = [bool]$tweak.Advanced
                    RequiresAdmin = [bool]$tweak.RequiresAdmin
                    Status        = (Get-WinForgeTweakStatus -Tweak $tweak)
                    LaptopNote    = $(if ($session.IsLaptop -and $tweak.LaptopRisk) { $tweak.Warning } else { "" })
                    OtherAccount  = ($otherAccount -and [bool]$tweak.UserScope)
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
        $Tweak,

        # O estado que quem chama acabou de ler (Get-WinForgeTweakStatus): evita ler de novo, o que nos ajustes de energia
        # é mais uma consulta ao powercfg.
        [string]$Status = ""
    )

    if (-not (Test-WinForgeTweakAvailable -Tweak $Tweak)) {
        throw (Get-WinForgeText 'O ajuste ''{0}'' não está disponível nesta versão do Windows.' "$($Tweak.Name)")
    }

    if ($Tweak.RequiresAdmin -and -not (Test-WinForgeAdministrator)) {
        throw (Get-WinForgeText 'O ajuste ''{0}'' exige privilégios de Administrador.' "$($Tweak.Name)")
    }

    $tweakId = [string]$Tweak.Id
    $merge = Get-WinForgeTweakField -Entry $Tweak -Name "Merge"

    # O backup guarda o estado de antes do WinForge. Se o ajuste já está aplicado, o estado atual não é o original:
    # o backup existente continua valendo e, sem backup, desfazer usará os padrões do Windows. Se não está aplicado
    # (por exemplo, o usuário desfez manualmente), o estado atual é o novo "original" — mas, se já havia um backup, o
    # Merge do ajuste mantém o original de antes para o que continua como o WinForge deixou.
    if ([string]::IsNullOrEmpty($Status)) { $Status = Get-WinForgeTweakStatus -Tweak $Tweak }

    $alreadyApplied = ($Status -eq "Aplicado")
    $snapshot = $null
    $record = $null

    if (-not $alreadyApplied) {
        $snapshot = & $Tweak.Capture

        $record = Invoke-WinForgeStateLock -ScriptBlock {
            $current = Read-WinForgeTweakBackup -Status

            # Gravar sem ter lido o arquivo apagaria os originais de todos os outros ajustes.
            if ($current.Status -eq "Unreadable") { throw (Get-WinForgeTweakBackupUnreadableText) }

            $hadEntry = $current.Backup.Contains($tweakId)
            $previousEntry = $null

            if ($hadEntry) { $previousEntry = $current.Backup[$tweakId] }

            $previousOriginal = Get-WinForgeTweakField -Entry $previousEntry -Name "Original"
            $original = $snapshot

            if ($null -ne $previousOriginal -and $null -ne $merge) {
                $original = & $merge $previousOriginal $snapshot
            }

            $current.Backup[$tweakId] = [ordered]@{
                AppliedAt = (Get-Date).ToString("s")
                Original  = $original
            }

            Save-WinForgeTweakBackup -Backup $current.Backup

            return [PSCustomObject]@{ HadEntry = $hadEntry; PreviousEntry = $previousEntry; Original = $original }
        }
    }

    $applyWith = $null

    if ($null -ne $record) {
        $applyWith = $record.Original
    }

    try {
        [void](& $Tweak.Apply $applyWith)
    }
    catch {
        $failure = $_

        # Desfaz o que a tentativa mudou e não deixa um backup de algo que não foi aplicado. Se nem o desfazer funcionou,
        # parte do ajuste pode ter ficado no PC: o backup com o valor de antes fica, para o desfazer de depois voltar a ele.
        if ($null -ne $record) {
            $undone = $false

            try {
                [void](& $Tweak.Revert $snapshot)
                $undone = $true
            }
            catch {
                Write-Verbose "Desfazer a tentativa de $($Tweak.Id): $($_.Exception.Message)"
                Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText '{0}: parte da tentativa pode ter ficado aplicada. O valor de antes continua guardado, e desfazer o ajuste volta a ele.' "$($Tweak.Name)")
            }

            if ($undone) {
                try {
                    [void](Invoke-WinForgeStateLock -ScriptBlock {
                            $current = Read-WinForgeTweakBackup -Status

                            if ($current.Status -eq "Unreadable") { return }

                            if ($record.HadEntry) {
                                $current.Backup[$tweakId] = $record.PreviousEntry
                            }
                            elseif ($current.Backup.Contains($tweakId)) {
                                $current.Backup.Remove($tweakId)
                            }

                            Save-WinForgeTweakBackup -Backup $current.Backup
                        })
                }
                catch {
                    Write-Verbose "Backup do ajuste $($Tweak.Id): $($_.Exception.Message)"
                }
            }
        }

        throw $failure
    }

    if (-not $alreadyApplied) {
        [void](Add-WinForgeChange -Action (Get-WinForgeText 'Ajuste aplicado') -Text $Tweak.Name -Undo @{ Kind = "tweak"; Id = $Tweak.Id })
    }
}


function Invoke-WinForgeTweakRevert {
    <#
    Desfaz um ajuste. Devolve $true se havia backup e $false se foram usados os padrões do Windows. Com -Detailed, devolve
    HadBackup, Restored e Kept (quantos valores voltaram e quantos ficaram por terem mudado depois; sem o relatório do
    ajuste, Restored = 1 e Kept = 0) e Note (o que o desfazer fez a mais, ou vazio).
    #>
    param (
        [Parameter(Mandatory)]
        $Tweak,

        [switch]$Detailed
    )

    if ($Tweak.RequiresAdmin -and -not (Test-WinForgeAdministrator)) {
        throw (Get-WinForgeText 'O ajuste ''{0}'' exige privilégios de Administrador.' "$($Tweak.Name)")
    }

    $tweakId = [string]$Tweak.Id
    $read = Read-WinForgeTweakBackup -Status

    # Sem conseguir ler o backup, desfazer com os padrões do Windows trocaria os originais guardados por outros valores.
    if ($read.Status -eq "Unreadable") {
        throw (Get-WinForgeTweakBackupUnreadableText)
    }

    # Uma entrada editada à mão ou de outra versão pode vir sem "Original": nesse caso valem os padrões do Windows.
    $saved = $null

    if ($read.Backup.Contains($tweakId)) {
        $saved = Get-WinForgeTweakField -Entry $read.Backup[$tweakId] -Name "Original"
    }

    # Se a volta falha (sem permissão, valor bloqueado), o erro sobe daqui: o backup e a anotação do Histórico ficam
    # como estão, para uma nova tentativa.
    $report = @(& $Tweak.Revert $saved | Where-Object { $null -ne $_ -and $_.PSObject.TypeNames -contains "WinForge.TweakRevert" }) | Select-Object -Last 1

    [void](Invoke-WinForgeStateLock -ScriptBlock {
            $current = Read-WinForgeTweakBackup -Status

            if ($current.Status -ne "Unreadable" -and $current.Backup.Contains($tweakId)) {
                $current.Backup.Remove($tweakId)
                Save-WinForgeTweakBackup -Backup $current.Backup
            }
        })

    # O ajuste voltou ao original: a anotação de quando foi aplicado não tem mais o que desfazer.
    Set-WinForgeChangesUndone -Kind "tweak" -Key "Id" -Value $Tweak.Id

    if ($Detailed) {
        return [PSCustomObject]@{
            HadBackup = ($null -ne $saved)
            Restored  = $(if ($null -ne $report) { [int]$report.Restored } else { 1 })
            Kept      = $(if ($null -ne $report) { [int]$report.Kept } else { 0 })
            Note      = [string](Get-WinForgeTweakField -Entry $report -Name "Note" -Default "")
        }
    }

    return ($null -ne $saved)
}


function Invoke-WinForgeTweakSet {
    <#
    Aplica uma lista de ajustes (por Id), um a um, sem perguntar nada. Um ajuste que falha não interrompe os demais.
    Devolve um resumo com os resultados (WinForge.Result), se o Explorador precisa ser reiniciado e se algum ajuste
    aplicado só vale depois de reiniciar o PC (NeedsReboot).
    #>
    param (
        [Parameter(Mandatory)]
        [string[]]$Ids
    )

    $results = @()
    $needsExplorerRestart = $false
    $needsReboot = $false
    $position = 0

    # Elevado com outra conta, o HKCU é o dessa conta: um ajuste do perfil do usuário mudaria o perfil errado, e o estado
    # lido também seria o dela. Em lote não há como perguntar a cada um: esses ficam de fora, com aviso; os de sistema
    # (HKLM) seguem.
    $session = Get-WinForgeSessionInfo
    $otherAccount = [bool](Get-WinForgeTweakField -Entry $session -Name "UserMismatch" -Default $false)
    $warnedOtherAccount = $false

    try {
        foreach ($id in $Ids) {
            $position++
            $tweak = Get-WinForgeTweakById -Id $id

            if ($null -eq $tweak) {
                $unknown = New-WinForgeResult -Kind Failed -Detail (Get-WinForgeText 'ajuste desconhecido') -Title $id
                $results += $unknown
                Write-WinForgeStatus -Type Error -Message (Get-WinForgeText 'Ajuste desconhecido: {0}' "$id")
                continue
            }

            # O andamento vai para a barra de progresso; no resumo fica uma linha por ajuste, a do resultado.
            Write-Progress -Activity (Get-WinForgeText 'Aplicando os ajustes') -Status (Get-WinForgeText '{0} de {1}: {2}' "$position" "$($Ids.Count)" "$($tweak.Name)") -PercentComplete ([int](100 * ($position - 1) / $Ids.Count))

            if ($otherAccount -and $tweak.UserScope) {
                if (-not $warnedOtherAccount) {
                    $warnedOtherAccount = $true
                    Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'O WinForge está elevado com outra conta ({0}): os ajustes do perfil do usuário ficam de fora, para não mudar o perfil dessa conta. Para aplicá-los, abra o WinForge sem trocar de conta no pedido de Administrador.' "$([string](Get-WinForgeTweakField -Entry $session -Name 'User' -Default ''))")
                }

                $results += (New-WinForgeResult -Kind Warning -Detail (Get-WinForgeText 'não aplicado: vale para o perfil do usuário, e o WinForge está elevado com outra conta') -Title $tweak.Name)
                Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText '{0}: não aplicado (vale para o perfil do usuário).' "$($tweak.Name)")
                continue
            }

            try {
                $before = Get-WinForgeTweakStatus -Tweak $tweak

                if ($before -eq "Aplicado") {
                    $skipped = New-WinForgeResult -Kind Skipped -Detail (Get-WinForgeText 'já estava aplicado') -Title $tweak.Name
                    $results += $skipped
                    Write-WinForgeStatus -Type Info -Message (Get-WinForgeText '{0}: já estava aplicado.' "$($tweak.Name)")
                    continue
                }

                Invoke-WinForgeTweakApply -Tweak $tweak -Status $before

                if ((Get-WinForgeTweakStatus -Tweak $tweak) -eq "Aplicado") {
                    $results += (New-WinForgeResult -Kind Ok -Title $tweak.Name)
                    Write-WinForgeStatus -Type Success -Message (Get-WinForgeText '{0}: aplicado.' "$($tweak.Name)")

                    if ($tweak.RestartExplorer) { $needsExplorerRestart = $true }
                    if (Get-WinForgeTweakField -Entry $tweak -Name "NeedsReboot" -Default $false) { $needsReboot = $true }
                }
                else {
                    $results += (New-WinForgeResult -Kind Warning -Detail (Get-WinForgeText 'o Windows não manteve o valor') -Title $tweak.Name)
                    Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText '{0}: o valor foi gravado, mas o Windows não o manteve (política da organização?).' "$($tweak.Name)")
                }
            }
            catch {
                $help = Get-WinForgeTweakProtectedHelp -Tweak $tweak

                if ($null -ne $help -and (Test-WinForgeAccessDenied -Exception $_.Exception)) {
                    $results += (New-WinForgeResult -Kind Warning -Detail (Get-WinForgeText 'o Windows protege esta configuração e não deixa o WinForge mudá-la') -Title $tweak.Name)
                    Write-WinForgeStatus -Type Warning -Message "$($tweak.Name): $(Get-WinForgeTweakProtectedText -Help $help)"
                }
                else {
                    $results += (New-WinForgeResult -Kind Failed -Detail $_.Exception.Message -Title $tweak.Name)
                    Write-WinForgeStatus -Type Error -Message "$($tweak.Name): $($_.Exception.Message)"
                }
            }
        }
    }
    finally {
        Write-Progress -Activity (Get-WinForgeText 'Aplicando os ajustes') -Completed
    }

    return [PSCustomObject]@{
        Results              = $results
        NeedsExplorerRestart = $needsExplorerRestart
        NeedsReboot          = $needsReboot
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


function ConvertFrom-WinForgeWmiDate {
    # A data no formato do WMI ("20261018123045.000000-180": ano, mês, dia, hora, minuto, segundo, microssegundos e a
    # diferença para o UTC em minutos) como horário local. Texto fora desse formato = $null.
    param ($Value)

    if ($Value -is [datetime]) {
        return $Value
    }

    $match = [regex]::Match([string]$Value, '^([0-9]{4})([0-9]{2})([0-9]{2})([0-9]{2})([0-9]{2})([0-9]{2})\.[0-9]+([+-][0-9]{3})$')

    if (-not $match.Success) {
        return $null
    }

    try {
        $local = [datetime]::new([int]$match.Groups[1].Value, [int]$match.Groups[2].Value, [int]$match.Groups[3].Value, [int]$match.Groups[4].Value, [int]$match.Groups[5].Value, [int]$match.Groups[6].Value)
        $offset = [TimeSpan]::FromMinutes([int]$match.Groups[7].Value)

        return ([DateTimeOffset]::new($local, $offset)).LocalDateTime
    }
    catch {
        return $null
    }
}


function Get-WinForgeRestorePolicy {
    <#
    O que a política do Windows (Diretiva de Grupo ou a empresa) diz da Restauração do Sistema: "DisableSR" quando ela
    está desligada pela política (nenhum ponto é criado), "DisableConfig" quando a pessoa não pode ligá-la nem
    configurá-la, ou "" sem política. Ler não falha: sem a chave, ou sem leitura, é "".
    #>
    try {
        $policy = Get-ItemProperty -LiteralPath "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\SystemRestore" -ErrorAction Stop

        if ([int](Get-WinForgeJsonValue -Object $policy -Name "DisableSR" -Default 0) -eq 1) { return "DisableSR" }
        if ([int](Get-WinForgeJsonValue -Object $policy -Name "DisableConfig" -Default 0) -eq 1) { return "DisableConfig" }
    }
    catch {
        Write-Verbose "Política da Restauração do Sistema: $($_.Exception.Message)"
    }

    return ""
}


function Test-WinForgeRestoreProtectionOffError {
    <#
    Se a falha do Checkpoint-Computer é a Proteção do Sistema desligada: o código 0x80070422 ("o serviço não pode ser
    iniciado porque está desabilitado"), lido no erro e no erro de dentro, e não no texto, que vem no idioma do Windows.
    O texto em inglês ou português fica só como reserva, para quando o código não vem.
    #>
    param ($Exception)

    $current = $Exception
    $depth = 0

    while ($null -ne $current -and $depth -lt 4) {
        if ($null -ne $current.PSObject.Properties["HResult"] -and [int64]$current.HResult -eq [int64]-2147023838) { return $true }

        $current = $(if ($null -ne $current.PSObject.Properties["InnerException"]) { $current.InnerException } else { $null })
        $depth++
    }

    $message = $(if ($null -ne $Exception -and $null -ne $Exception.PSObject.Properties["Message"]) { [string]$Exception.Message } else { "" })

    return ($message -match "(?i)disabled|desativ|desabilit|deshabilit|desactiv")
}


function Get-WinForgeLatestRestorePointTime {
    # Quando foi criado o ponto de restauração mais recente; $null se não há pontos ou não foi possível consultar.
    try {
        $points = @(Get-ComputerRestorePoint -ErrorAction Stop)

        if ($points.Count -eq 0) {
            return $null
        }

        $latest = $points | Sort-Object -Property SequenceNumber -Descending | Select-Object -First 1

        return (ConvertFrom-WinForgeWmiDate -Value $latest.CreationTime)
    }
    catch {
        return $null
    }
}


function Set-WinForgeRestorePointFrequency {
    <#
    Troca o intervalo mínimo entre pontos de restauração (SystemRestorePointCreationFrequency, em minutos; 0 = sem
    limite). Devolve o que havia antes (Existed e Value), para Restore-WinForgeRestorePointFrequency, ou $null quando não
    deu para trocar (aí o limite do Windows continua valendo). O original fica anotado nas preferências até voltar: se o
    WinForge for fechado no meio da criação, o próximo ponto pedido devolve o limite, em vez de deixá-lo em zero.
    #>
    param ([int]$Value)

    $key = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore"
    $name = "SystemRestorePointCreationFrequency"

    try {
        # Uma troca que ficou pela metade (o WinForge fechado no meio) já guardou o original de verdade: o valor de agora
        # é o zero que ela deixou.
        $pending = Get-WinForgeSetting -Name "RestorePointFrequencySaved" -Default $null

        if ($null -ne $pending) {
            $saved = [PSCustomObject]@{ Existed = [bool](Get-WinForgeJsonValue -Object $pending -Name "Existed" -Default $false); Value = (Get-WinForgeJsonValue -Object $pending -Name "Value" -Default $null) }
        }
        else {
            $current = Get-ItemProperty -LiteralPath $key -Name $name -ErrorAction SilentlyContinue
            $saved = [PSCustomObject]@{ Existed = ($null -ne $current); Value = $(if ($null -ne $current) { $current.$name } else { $null }) }
            [void](Set-WinForgeSetting -Name "RestorePointFrequencySaved" -Value @{ Existed = $saved.Existed; Value = $saved.Value })
        }

        [void](New-ItemProperty -LiteralPath $key -Name $name -Value $Value -PropertyType DWord -Force -ErrorAction Stop)

        return $saved
    }
    catch {
        Write-Verbose "Limite de pontos de restauração: $($_.Exception.Message)"
        return $null
    }
}


function Restore-WinForgeRestorePointFrequency {
    # Devolve o intervalo mínimo entre pontos ao que era (ou apaga o valor, se ele não existia). Devolve se conseguiu.
    param ([Parameter(Mandatory)]$Saved)

    $key = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore"
    $name = "SystemRestorePointCreationFrequency"

    try {
        # Um original que não é um número (gravado à mão) não volta como estava: sem o valor, vale o limite padrão.
        $number = 0
        $valid = ($Saved.Existed -and [int]::TryParse([string]$Saved.Value, [ref]$number))

        if ($valid) { [void](New-ItemProperty -LiteralPath $key -Name $name -Value $number -PropertyType DWord -Force -ErrorAction Stop) }
        elseif ($null -ne (Get-ItemProperty -LiteralPath $key -Name $name -ErrorAction SilentlyContinue)) { Remove-ItemProperty -LiteralPath $key -Name $name -ErrorAction Stop }

        [void](Set-WinForgeSetting -Name "RestorePointFrequencySaved" -Value $null)

        return $true
    }
    catch {
        Write-Verbose "Limite de pontos de restauração: $($_.Exception.Message)"
        return $false
    }
}


function New-WinForgeRestorePoint {
    <#
    Cria um ponto de restauração e confere se ele realmente existe: o Checkpoint-Computer apenas emite um aviso
    (sem erro) quando já há um ponto criado nas últimas 24 horas. Devolve um WinForge.Result; Data.NotCreated quando
    nenhum ponto foi criado e Data.ProtectionOff quando o motivo é a Proteção do Sistema desligada (só aí ligá-la ajuda).
    -IgnoreFrequency: o ponto pedido sozinho (antes de instalar um driver, por exemplo) não esbarra no limite de um por
    dia: o limite fica em zero só durante a criação (SystemRestorePointCreationFrequency, o valor que a Microsoft
    documenta para isso) e volta ao que era.
    #>
    param (
        [string]$Description = (Get-WinForgeText 'WinForge - antes dos ajustes'),
        [switch]$IgnoreFrequency
    )

    if (-not (Get-Command Checkpoint-Computer -ErrorAction SilentlyContinue)) {
        Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'Checkpoint-Computer não está disponível neste PowerShell. Use o Windows PowerShell 5.1.')

        # Nenhum ponto foi criado (quem aplica ajustes pergunta se segue sem ele), mas ligar a Proteção do Sistema não
        # resolveria: falta o comando, não a proteção.
        return (New-WinForgeResult -Kind Warning -Detail (Get-WinForgeText 'indisponível neste PowerShell') -Title (Get-WinForgeText 'Criar ponto de restauração') -Data @{ NotCreated = $true; Unavailable = $true })
    }

    # Desligada pela política (Diretiva de Grupo, a empresa): o Windows não cria pontos, e ligar a Proteção do Sistema
    # daqui não adianta; quem decide é quem administra o PC.
    $policy = Get-WinForgeRestorePolicy

    if ($policy -eq "DisableSR") {
        Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'A Restauração do Sistema está desligada por uma política deste PC (Diretiva de Grupo ou a empresa). Só quem administra o PC pode ligá-la.')
        return (New-WinForgeResult -Kind Warning -Detail (Get-WinForgeText 'não criado; desligado por uma política deste PC') -Title (Get-WinForgeText 'Criar ponto de restauração') -Data @{ NotCreated = $true; Policy = $true })
    }

    $before = Get-WinForgeRestorePointSequence
    $checkpointWarning = $null
    $frequency = $null

    if ($IgnoreFrequency) {
        $frequency = Set-WinForgeRestorePointFrequency -Value 0
    }
    else {
        # O limite que ficou em zero numa criação interrompida volta ao original agora.
        $pending = Get-WinForgeSetting -Name "RestorePointFrequencySaved" -Default $null
        if ($null -ne $pending) { [void](Restore-WinForgeRestorePointFrequency -Saved $pending) }
    }

    try {
        Write-Progress -Activity (Get-WinForgeText 'Criando o ponto de restauração') -Status (Get-WinForgeText 'o Windows está criando o ponto (pode levar um minuto)')
        Checkpoint-Computer -Description $Description -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop -WarningAction SilentlyContinue -WarningVariable checkpointWarning
    }
    catch {
        $message = ([string]$_.Exception.Message).Trim().TrimEnd(".")

        # Só a Proteção do Sistema desligada se resolve ligando-a; espaço cheio ou uma política do Windows, não. Com a
        # política que impede configurar (DisableConfig), ligar daqui também não é possível.
        $protectionOff = (Test-WinForgeRestoreProtectionOffError -Exception $_.Exception)

        if ($protectionOff) {
            Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'Não foi possível criar o ponto de restauração: a Proteção do Sistema está desligada no disco do Windows.')
            if ($policy -eq "DisableConfig") { Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Uma política deste PC impede ligá-la por aqui; só quem administra o PC pode fazer isso.') }
        }
        else {
            Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'Não foi possível criar o ponto de restauração: {0}.' "$message")
        }

        $reason = $(if ($protectionOff) { (Get-WinForgeText 'não criado; a Proteção do Sistema está desligada') } else { (Get-WinForgeText 'não criado; {0}' "$message") })

        return (New-WinForgeResult -Kind Warning -Detail $reason -Title (Get-WinForgeText 'Criar ponto de restauração') -Data @{ NotCreated = $true; ProtectionOff = ($protectionOff -and $policy -ne "DisableConfig"); Policy = ($policy -ne "") })
    }
    finally {
        Write-Progress -Activity (Get-WinForgeText 'Criando o ponto de restauração') -Completed
        if ($null -ne $frequency) { [void](Restore-WinForgeRestorePointFrequency -Saved $frequency) }
    }

    $after = Get-WinForgeRestorePointSequence
    $warningText = (@($checkpointWarning) | ForEach-Object { [string]$_ }) -join " "

    if ($before -ge 0 -and $after -gt $before) {
        # O que fazer com ele, se algo der errado: a pessoa não precisa saber onde a Restauração do Sistema fica.
        Write-WinForgeStatus -Type Success -Message (Get-WinForgeText 'Ponto de restauração criado. Para voltar a ele, use Manutenção > Restauração do Sistema.')
        return (New-WinForgeResult -Kind Ok -Detail (Get-WinForgeText 'ponto de restauração criado') -Title (Get-WinForgeText 'Criar ponto de restauração'))
    }

    if (-not [string]::IsNullOrWhiteSpace($warningText) -or ($before -ge 0 -and $after -eq $before)) {
        # O Windows cria no máximo um ponto por dia. Com um ponto de menos de 24 horas já existindo, a rede de segurança
        # está lá: não é um problema, e não deve aparecer como ressalva na manutenção nem no Início.
        $latestTime = Get-WinForgeLatestRestorePointTime

        if ($null -ne $latestTime) {
            $age = (Get-Date) - $latestTime

            if ($age.TotalHours -ge 0 -and $age.TotalHours -lt 24) {
                Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Já existe um ponto de restauração recente ({0}); o Windows cria no máximo um por dia.' "$(Format-WinForgeRelativeTime -When $latestTime)")
                return (New-WinForgeResult -Kind Skipped -Detail (Get-WinForgeText 'já havia um ponto recente') -Title (Get-WinForgeText 'Criar ponto de restauração'))
            }
        }

        Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'O Windows não criou um novo ponto de restauração.')

        # A lista foi lida e não tem nenhum ponto: dizer que "um ponto recente já deve existir" prometeria uma rede de
        # segurança que não existe. Fica "não criado", como a Proteção do Sistema desativada (quem aplica ajustes pergunta
        # se segue sem ele, e o ponto pedido sozinho não é concluído).
        if ($before -eq 0 -and $after -eq 0) {
            Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Não há nenhum ponto de restauração neste PC.')
            if (-not [string]::IsNullOrWhiteSpace($warningText)) { Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Aviso do Windows: {0}' "$warningText") }

            # Sem nenhum ponto e sem erro, o mais comum é a Proteção do Sistema desligada (o padrão em muitos PCs).
            return (New-WinForgeResult -Kind Warning -Detail (Get-WinForgeText 'não criado; não há nenhum ponto de restauração') -Title (Get-WinForgeText 'Criar ponto de restauração') -Data @{ NotCreated = $true; ProtectionOff = ($policy -ne "DisableConfig"); Policy = ($policy -ne "") })
        }

        # O ponto mais novo tem mais de um dia (ou a data dele não pôde ser lida): o limite de um por dia não explica a
        # recusa, e não há rede de segurança recente. É "não criado", como os outros casos (quem aplica ajustes pergunta
        # se segue sem ele, e o ponto pedido sozinho não é concluído).
        if ($null -ne $latestTime) { Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'O ponto mais novo é de {0} ({1}).' "$(Format-WinForgeDateTime -When $latestTime)" "$(Format-WinForgeRelativeTime -When $latestTime)") }
        if (-not [string]::IsNullOrWhiteSpace($warningText)) { Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Aviso do Windows: {0}' "$warningText") }

        return (New-WinForgeResult -Kind Warning -Detail (Get-WinForgeText 'não criado; o Windows não criou um novo ponto') -Title (Get-WinForgeText 'Criar ponto de restauração') -Data @{ NotCreated = $true })
    }

    # Não foi possível consultar a lista de pontos, mas o comando terminou sem erro nem aviso.
    Write-WinForgeStatus -Type Success -Message (Get-WinForgeText 'Ponto de restauração solicitado.')
    return (New-WinForgeResult -Kind Ok -Title (Get-WinForgeText 'Criar ponto de restauração'))
}


function Request-WinForgeRestorePoint {
    <#
    Cria o ponto de restauração e, se ele não pôde ser criado, oferece ativar a Proteção do Sistema e tentar de novo.
    Faz perguntas: use só quando há alguém presente (dentro do Otimizar, chame New-WinForgeRestorePoint).
    Description é o nome que o ponto terá na Restauração do Sistema. Devolve um WinForge.Result.
    #>
    param (
        [string]$Description = (Get-WinForgeText 'WinForge - antes dos ajustes'),
        [switch]$IgnoreFrequency,

        # O ponto é o objetivo inteiro (Criar ponto de restauração, pedido sozinho): ligar a Proteção do Sistema para
        # criá-lo vem com Sim como padrão. Antes de aplicar ajustes, o padrão continua Não.
        [switch]$ProtectionDefaultYes
    )

    $result = New-WinForgeRestorePoint -Description $Description -IgnoreFrequency:$IgnoreFrequency

    # Ligar a Proteção do Sistema só é oferecido quando é ela que falta: com outro motivo (disco cheio, política), a
    # proteção seria ligada à toa e a nova tentativa falharia igual.
    if (-not (Test-WinForgeResultFlag -Result $result -Name "ProtectionOff")) {
        return $result
    }

    Write-Host ""

    if (Confirm-WinForgeAction (Get-WinForgeText 'A Proteção do Sistema está desligada. Ligá-la (usa um pouco do disco) e criar o ponto?') -DefaultKey $(if ($ProtectionDefaultYes) { "S" } else { "N" }) -YesLabel (Get-WinForgeText 'Ligar e criar') -NoLabel (Get-WinForgeText 'Agora não')) {
        try {
            Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction Stop
            Write-WinForgeStatus -Type Success -Message (Get-WinForgeText 'Proteção do Sistema ativada.')
            $result = New-WinForgeRestorePoint -Description $Description -IgnoreFrequency:$IgnoreFrequency
        }
        catch {
            Write-WinForgeStatus -Type Error -Message (Get-WinForgeText 'Não foi possível ativar a Proteção do Sistema: {0}' "$($_.Exception.Message)")
        }
    }

    return $result
}


function Invoke-WinForgeRestorePoint {
    param (
        [switch]$Embedded,
        [switch]$PassThru,

        # O nome do ponto na Restauração do Sistema, que é o que a pessoa vê na hora de escolher para onde voltar.
        [string]$Description = (Get-WinForgeText 'WinForge - ponto criado manualmente'),

        # Dentro de um fluxo com a pessoa presente (o começo do Otimizar): sem a Proteção do Sistema, oferece ligá-la,
        # com Não como padrão, como antes de aplicar ajustes. Sem ele, dentro de um fluxo, não pergunta nada.
        [switch]$OfferProtection
    )

    $title = (Get-WinForgeText 'Criar ponto de restauração')

    Enter-WinForgeAction -Title $title -Embedded:$Embedded

    $result = $null

    if (-not (Test-WinForgeElevation -Reason (Get-WinForgeText 'Criar um ponto de restauração exige privilégios de Administrador.'))) {
        $result = New-WinForgeResult -Kind Failed -Detail (Get-WinForgeText 'requer Administrador') -Title $title
    }
    elseif ($Embedded -and $OfferProtection) {
        # O começo do Otimizar: o ponto é para agora, antes das mudanças desta execução. Um ponto de horas atrás (de uma
        # atualização do Windows, de um instalador) voltaria também o que mudou depois dele, então o limite de um por dia
        # do Windows não vale aqui.
        $result = Request-WinForgeRestorePoint -Description $Description -IgnoreFrequency
    }
    elseif ($Embedded) {
        $result = New-WinForgeRestorePoint -Description $Description
    }
    else {
        # Pedido sozinho, o ponto é para agora: o limite de um por dia do Windows não vale.
        $result = Request-WinForgeRestorePoint -Description $Description -IgnoreFrequency -ProtectionDefaultYes

        # Pedido sozinho, o ponto é o objetivo inteiro: se ele não existe no fim, a ação não foi concluída (dentro de um
        # fluxo, o mesmo caso é uma ressalva e o fluxo segue).
        if (Test-WinForgeResultFlag -Result $result -Name "NotCreated") {
            $reason = $(if (Test-WinForgeResultFlag -Result $result -Name "Unavailable") { (Get-WinForgeText 'o comando do ponto de restauração não existe neste PowerShell') } else { (Get-WinForgeText 'o ponto de restauração não foi criado') })
            # O motivo sem o "não criado;" do começo (no idioma da tela, como em Invoke-WinForgeRestorePoint).
            $why = [string]$result.Detail
            $prefix = (Get-WinForgeText 'não criado; {0}' "").Trim()
            if ($prefix -and $why.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) { $why = $why.Substring($prefix.Length).TrimStart() }
            $result = New-WinForgeResult -Kind Failed -Detail $reason -Title $title -Data @{ NotCreated = $true }

            # O título da faixa diz o que aconteceu; o motivo vem embaixo (desligado, política, recusa do Windows).
            if (-not [string]::IsNullOrWhiteSpace($why) -and $why -ne [string]$reason) {
                $note = "$($why.Substring(0, 1).ToUpperInvariant())$($why.Substring(1))."
                $result = Set-WinForgeResultView -Result $result -Headline (Get-WinForgeText 'O ponto de restauração não foi criado') -Note $note
            }
        }
        elseif ([string]$result.Kind -eq "Ok" -and [string]$result.Detail -eq (Get-WinForgeText 'ponto de restauração criado')) {
            # Só o ponto conferido na lista do Windows; o "solicitado" (lista ilegível) não afirma que ele existe.
            $result = Set-WinForgeResultView -Result $result -Headline (Get-WinForgeText 'Ponto de restauração criado') -Note (Get-WinForgeText 'Para voltar a ele, use Manutenção > Restauração do Sistema.')
        }
    }

    if ($PassThru) { $result }
    Exit-WinForgeAction -Embedded:$Embedded -Result $result
}


# ---------------------------------------------------------------------------
# Fluxos para o usuário
# ---------------------------------------------------------------------------

function Read-WinForgeTweakSelection {
    <#
    Lista ajustes (objetos do catálogo) com caixas de marcação. Em notebook, os que gastam bateria vêm desmarcados.
    Devolve os Ids marcados ou $null se o usuário cancelar ou não marcar nada.
    #>
    param (
        [Parameter(Mandatory)]
        [object[]]$Tweaks,

        [string]$Message = (Get-WinForgeText 'Escolha os ajustes que deseja aplicar')
    )

    $session = Get-WinForgeSessionInfo
    $candidates = @($Tweaks)

    if ($session.IsLaptop -and @($candidates | Where-Object { $_.LaptopRisk }).Count -gt 0) {
        Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Notebook detectado: os ajustes de energia que reduzem a bateria vêm desmarcados.')
        Write-Host ""
    }

    $options = @(
        foreach ($tweak in $candidates) {
            $risky = ($session.IsLaptop -and $tweak.LaptopRisk)
            $note = $tweak.Description

            # O aviso já diz que é do notebook ("Em notebook, consome mais bateria..."): vem logo depois da descrição.
            if ($risky) { $note = "$($tweak.Description) $($tweak.Warning)" }

            @{ Key = $tweak.Id; Label = $tweak.Name; Description = $note; Selected = (-not $risky) }
        }
    )

    $picked = Read-WinForgeMultiSelect -Message $Message -Options $options -ConfirmLabel (Get-WinForgeText 'Aplicar')

    if ($null -eq $picked) {
        return $null
    }

    return @($picked)
}


function Request-WinForgeExplorerRestart {
    <#
    Oferece reiniciar o Explorador de Arquivos para as mudanças aparecerem. Devolve "Restarted", "Declined" (a pessoa
    disse não) ou "Failed" (o reinício não deu certo: vira aviso, porque o ajuste já foi gravado).
    #>
    param (
        [Parameter(Mandatory)]
        [string]$Question,

        # Mais de um ajuste: "As mudanças aparecem...", em vez de "A mudança aparece...".
        [switch]$Many
    )

    # O reinício fecha as janelas de pastas abertas: uma cópia de arquivos em andamento nelas seria interrompida.
    Write-WinForgeStatus -Type Info -Notice -Message (Get-WinForgeText 'Reiniciar o Explorador fecha as janelas de pastas abertas e interrompe cópias de arquivos em andamento.')

    if (-not (Confirm-WinForgeAction $Question -DefaultKey S -YesLabel (Get-WinForgeText 'Reiniciar agora') -NoLabel (Get-WinForgeText 'Depois'))) {
        # Sem o reinício, nada muda na tela por enquanto: a pessoa precisa saber quando a mudança vai aparecer.
        Write-WinForgeStatus -Type Info -Message $(if ($Many) { (Get-WinForgeText 'As mudanças aparecem quando você sair e entrar de novo no Windows.') } else { (Get-WinForgeText 'A mudança aparece quando você sair e entrar de novo no Windows.') })
        return "Declined"
    }

    try {
        Restart-WinForgeExplorerShell
        Write-WinForgeStatus -Type Success -Message (Get-WinForgeText 'Explorador reiniciado.')
        return "Restarted"
    }
    catch {
        $reason = ([string]$_.Exception.Message).Trim().TrimEnd(".")
        Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'Não foi possível reiniciar o Explorador ({0}). Para ver as mudanças, saia do Windows e entre de novo.' "$reason")
        return "Failed"
    }
}


function Get-WinForgePendingTweaks {
    # Dos Ids pedidos, os ajustes que existem, servem para este Windows e ainda não estão aplicados.
    param (
        [string[]]$Ids
    )

    return @(
        foreach ($id in @($Ids)) {
            $tweak = Get-WinForgeTweakById -Id $id

            if ($null -ne $tweak -and (Test-WinForgeTweakAvailable -Tweak $tweak) -and (Get-WinForgeTweakStatus -Tweak $tweak) -ne "Aplicado") {
                $tweak
            }
        }
    )
}


function Select-WinForgeRecommendedTweaks {
    <#
    Pergunta quais dos ajustes recomendados aplicar. Os que gastam bateria vêm desmarcados em notebook; elevado com outra
    conta, os do perfil do usuário ficam de fora (Get-WinForgeTweaksForSession).
    Devolve os Ids marcados, uma lista vazia se não há o que aplicar ou $null se o usuário cancelar.
    #>
    $mine = @(Get-WinForgeTweaksForSession -Tweaks @(Get-WinForgeTweakCatalog | Where-Object { $_.Recommended -and (Test-WinForgeTweakAvailable -Tweak $_) }))
    $candidates = @($mine | Where-Object { (Get-WinForgeTweakStatus -Tweak $_) -ne "Aplicado" })

    if ($candidates.Count -eq 0) {
        Write-WinForgeStatus -Type Success -Message (Get-WinForgeText 'Todos os ajustes recomendados já estão aplicados.')
        # Uma lista vazia de verdade (e não $null, que é a desistência): o "return @()" chegaria a quem chama como $null.
        return , @()
    }

    return (Read-WinForgeTweakSelection -Tweaks $candidates -Message (Get-WinForgeText 'Escolha os ajustes recomendados que deseja aplicar'))
}


function Invoke-WinForgeTweakBatch {
    <#
    Aplica os Ajustes escolhidos e devolve o resultado (WinForge.Result): oferece o ponto de restauração antes e o
    reinício do Explorador depois. O ponto pede Administrador: sem ele (os recomendados, que só mudam o perfil do usuário,
    não pedem), fica de fora, e cada ajuste continua com o desfazer do WinForge.
    #>
    param (
        [Parameter(Mandatory)]
        [string[]]$Ids,

        [Parameter(Mandatory)]
        [string]$Title
    )

    $final = New-WinForgeResult -Kind Ok -Title $Title

    Write-Host ""

    if (-not (Test-WinForgeAdministrator)) {
        Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Sem Administrador, o ponto de restauração fica de fora; cada ajuste pode ser desfeito pela chave dele.')
    }
    elseif (Confirm-WinForgeAction (Get-WinForgeText 'Criar um ponto de restauração antes de aplicar?') -DefaultKey S -YesLabel (Get-WinForgeText 'Criar o ponto') -NoLabel (Get-WinForgeText 'Aplicar sem ele')) {
        # O ponto é para agora, antes destes ajustes: um de horas atrás (de uma atualização do Windows, de um
        # instalador) voltaria também o que mudou depois dele, então o limite de um por dia do Windows não vale aqui,
        # como no começo do Otimizar e no ponto pedido sozinho.
        $restorePoint = Request-WinForgeRestorePoint -IgnoreFrequency
        Write-Host ""

        # Sem o ponto de restauração a escolha é do usuário; padrão: não aplicar.
        if ((Test-WinForgeResultFlag -Result $restorePoint -Name "NotCreated") -and
            -not (Confirm-WinForgeAction (Get-WinForgeText 'Os ajustes ainda podem ser desfeitos pelo WinForge. Deseja aplicá-los mesmo sem o ponto de restauração?') -DefaultKey N -YesLabel (Get-WinForgeText 'Aplicar mesmo assim') -NoLabel (Get-WinForgeText 'Cancelar'))) {
            Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'Ajustes não aplicados.')
            return (New-WinForgeResult -Kind Skipped -Detail (Get-WinForgeText 'sem ponto de restauração') -Title $Title)
        }
    }

    $summary = Invoke-WinForgeTweakSet -Ids @($Ids)
    $failed = @($summary.Results | Where-Object { $_.Kind -in @("Failed", "Warning") })
    $applied = @($summary.Results | Where-Object { $_.Kind -eq "Ok" })

    Write-Host ""
    $appliedText = Format-WinForgeCount -Count $applied.Count -One (Get-WinForgeText 'ajuste aplicado') -Many (Get-WinForgeText 'ajustes aplicados')

    # Nada aplicado e tudo com problema: a frase diz isso, em vez de "0 ajustes aplicados, 4 com problema".
    $countText = $(if ($failed.Count -gt 0 -and $applied.Count -eq 0) { (Get-WinForgeText 'Nenhum ajuste foi aplicado.') } elseif ($failed.Count -gt 0) { (Get-WinForgeText '{0}, {1} com problema.' "$appliedText" "$($failed.Count)") } else { "$appliedText." })
    Write-WinForgeStatus -Type Info -Message $countText

    if ($applied.Count -gt 0) {
        Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Todos podem ser desfeitos em Ajustes do Windows > Desfazer ajustes do WinForge.')
    }

    if ($failed.Count -gt 0 -and $applied.Count -eq 0) {
        # Nada foi aplicado: não é "concluído com ressalvas".
        $final = New-WinForgeResult -Kind Failed -Detail (Get-WinForgeText 'nenhum ajuste foi aplicado ({0} com problema)' "$($failed.Count)") -Title $Title
    }
    elseif ($failed.Count -gt 0) {
        $final = New-WinForgeResult -Kind Warning -Detail (Get-WinForgeText '{0} de {1} com problema' "$($failed.Count)" "$(@($summary.Results).Count)") -Title $Title
    }

    # Um ajuste aplicado que só vale depois de reiniciar (o agendamento da placa de vídeo): a faixa pede o reinício.
    if ([bool](Get-WinForgeTweakField -Entry $summary -Name "NeedsReboot" -Default $false) -and $final.Kind -in @("Ok", "Warning")) {
        $final.Data["RebootRequired"] = $true
    }

    $restart = ""

    if ($summary.NeedsExplorerRestart) {
        Write-Host ""

        # Os ajustes já estão gravados: um Explorador que não reinicia é uma ressalva, não uma falha do lote.
        $restart = Request-WinForgeExplorerRestart -Question (Get-WinForgeText 'Reiniciar o Explorador de Arquivos agora para ver as mudanças?') -Many

        if ($restart -eq "Failed" -and $final.Kind -eq "Ok") {
            $final = New-WinForgeResult -Kind Warning -Detail (Get-WinForgeText 'o Explorador não reiniciou') -Title $Title
        }
    }

    # Na janela, o título diz quantos ajustes foram aplicados; a frase, quais (ou, com falhas, quais não foram) e, sem o
    # Explorador reiniciado, quando a mudança aparece. Um Explorador que não reiniciou fica com a faixa de sempre.
    $later = $(if ($restart -eq "Declined") { (Get-WinForgeText ' {0} quando você sair e entrar de novo no Windows.' "$(if ($applied.Count -eq 1) { (Get-WinForgeText 'A mudança aparece') } else { (Get-WinForgeText 'As mudanças aparecem') })") } else { "" })
    $names = @($applied | ForEach-Object { [string]$_.Etapa })
    $problems = @($failed | ForEach-Object { [string]$_.Etapa })

    if ($final.Kind -eq "Ok" -and $applied.Count -gt 0) {
        [void](Set-WinForgeResultView -Result $final -Headline (Format-WinForgeCount -Count $applied.Count -One (Get-WinForgeText 'ajuste aplicado') -Many (Get-WinForgeText 'ajustes aplicados')) `
                -Note "$(Join-WinForgeShortList -Items $names).$later")
    }
    elseif ($final.Kind -eq "Warning" -and $applied.Count -gt 0 -and $problems.Count -gt 0) {
        $verbText = $(if ($problems.Count -eq 1) { (Get-WinForgeText 'não foi aplicado; o motivo está no resumo') } else { (Get-WinForgeText 'não foram aplicados; o motivo de cada um está no resumo') })
        [void](Set-WinForgeResultView -Result $final -Headline (Get-WinForgeText '{0} de {1} ajustes aplicados' "$($applied.Count)" "$($applied.Count + $problems.Count)") `
                -Note "$(Join-WinForgeShortList -Items $problems) $verbText.$later")
    }
    elseif ($final.Kind -eq "Failed" -and $applied.Count -eq 0 -and $problems.Count -gt 0) {
        # Nenhum foi aplicado: o título diz isso, e a frase, onde está o motivo de cada um.
        [void](Set-WinForgeResultView -Result $final -Headline (Get-WinForgeText 'Nenhum ajuste foi aplicado') `
                -Note $(if ($problems.Count -eq 1) { (Get-WinForgeText 'O motivo está no resumo.') } else { (Get-WinForgeText 'O motivo de cada um está no resumo.') }))
    }
    elseif ($final.Kind -eq "Warning" -and $restart -eq "Failed" -and $applied.Count -gt 0) {
        # Os ajustes foram aplicados; só o Explorador não reiniciou: o título diz quantos, e a frase, quando eles aparecem.
        [void](Set-WinForgeResultView -Result $final -Headline (Format-WinForgeCount -Count $applied.Count -One (Get-WinForgeText 'ajuste aplicado') -Many (Get-WinForgeText 'ajustes aplicados')) `
                -Note $(if ($applied.Count -eq 1) { (Get-WinForgeText 'O Explorador não reiniciou; a mudança aparece quando você sair e entrar de novo no Windows.') } else { (Get-WinForgeText 'O Explorador não reiniciou; as mudanças aparecem quando você sair e entrar de novo no Windows.') }))
    }

    return $final
}


function Invoke-WinForgeRecommendedTweaks {
    <#
    Aplicar ajustes recomendados: pergunta quais, oferece o ponto de restauração (com Administrador) e pergunta sobre o
    Explorador. Os recomendados só mudam o perfil do usuário, como as Configurações do Windows: não pedem Administrador,
    e numa conta sem Administrador aplicam no perfil dela. Elevado com outra conta, eles mudariam o perfil dessa conta:
    a tela diz isso e para antes de perguntar qualquer coisa.
    #>
    $title = (Get-WinForgeText 'Aplicar ajustes recomendados')

    Enter-WinForgeAction -Title $title

    $final = New-WinForgeResult -Kind Ok -Title $title

    try {
        $recommended = @(Get-WinForgeTweakCatalog | Where-Object { $_.Recommended -and (Test-WinForgeTweakAvailable -Tweak $_) })

        if ($recommended.Count -gt 0 -and @(Get-WinForgeTweaksForSession -Tweaks $recommended -Quiet).Count -eq 0) {
            $user = [string](Get-WinForgeTweakField -Entry (Get-WinForgeSessionInfo) -Name "User" -Default "")
            Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'O WinForge está elevado com outra conta ({0}): os ajustes recomendados valem para o perfil do usuário e mudariam o perfil dessa conta, não o seu.' "$user")
            $final = Set-WinForgeResultView -Result (New-WinForgeResult -Kind Failed -Detail (Get-WinForgeText 'valem para o perfil do usuário, e o WinForge está elevado com outra conta') -Title $title) `
                -Headline (Get-WinForgeText 'Os ajustes recomendados valem para a sua conta') `
                -Note (Get-WinForgeText 'O WinForge está elevado com outra conta ({0}). Para aplicá-los, abra o WinForge de novo e recuse o pedido de Administrador.' "$user")
        }
        else {
            $Ids = Select-WinForgeRecommendedTweaks

            if ($null -eq $Ids) {
                # A lista fechada sem marcar nada (na janela, o Aplicar fica desligado sem marca) é desistência.
                Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'Operação cancelada.')
                $final = New-WinForgeResult -Kind Skipped -Detail (Get-WinForgeText 'cancelado pelo usuário') -Title $title
            }
            elseif (@($Ids).Count -eq 0) {
                # Todos já estão aplicados (Select-WinForgeRecommendedTweaks já disse): a faixa diz o mesmo.
                $final = Set-WinForgeResultView -Result (New-WinForgeResult -Kind Skipped -Detail (Get-WinForgeText 'nada a aplicar') -Title $title) `
                    -Headline (Get-WinForgeText 'Os ajustes recomendados já estão aplicados')
            }
            else {
                $final = Invoke-WinForgeTweakBatch -Ids @($Ids) -Title $title
            }
        }
    }
    catch {
        Write-WinForgeStatus -Type Error -Message (Get-WinForgeText 'Falha ao aplicar os ajustes: {0}' "$($_.Exception.Message)")
        $final = New-WinForgeResult -Kind Failed -Detail $_.Exception.Message -Title $title
    }

    Exit-WinForgeAction -Result $final
}


# ---------------------------------------------------------------------------
# Etapas do Otimizar
# ---------------------------------------------------------------------------

function Test-WinForgeTweakInReview {
    # Se a revisão do Otimizar oferece o ajuste. Ficam de fora a aparência (Cosmetic), que é gosto de cada um e não
    # manutenção, e o agendamento da placa de vídeo, que depende do hardware. As atualizações antecipadas entram, marcadas
    # conforme o Windows está: quem as ligou de propósito as mantém (antes, o Otimizar as desligava sozinho, a cada vez).
    param ([Parameter(Mandatory)]$Tweak)

    return (-not $Tweak.Cosmetic -and [string]$Tweak.Id -ne "gpu-scheduling")
}


function Get-WinForgeTweakReviewText {
    # A descrição de um ajuste na lista da revisão: a categoria, se ele está em uso agora e os avisos (notebook, avançado).
    param (
        [Parameter(Mandatory)]$Tweak,
        [string]$Status = "",
        [bool]$IsLaptop = $false
    )

    $parts = @([string]$Tweak.Category)
    $parts += $(if ($Status -eq "Aplicado") { (Get-WinForgeText 'em uso') } elseif ($Status -eq "Padrão") { (Get-WinForgeText 'não está em uso') } else { (Get-WinForgeText 'estado não identificado') })

    if ($IsLaptop -and $Tweak.LaptopRisk -and $Status -ne "Aplicado" -and -not [string]::IsNullOrWhiteSpace([string]$Tweak.Warning)) {
        # O aviso já começa com "Em notebook" (e vem no idioma da tela).
        $parts += ([string]$Tweak.Warning).Trim().TrimEnd(".")
    }

    if ($Tweak.Advanced) { $parts += (Get-WinForgeText 'avançado') }

    return ($parts -join " · ")
}


function Invoke-WinForgeTweakReview {
    <#
    A última etapa do Otimizar: os ajustes das páginas Ajustes do Windows e Personalização que não são gosto
    (Test-WinForgeTweakInReview), cada um marcado se já está em uso no Windows agora; os de fora ficam como estão. Marcar
    aplica; desmarcar um que está em uso o desfaz (com o valor de antes guardado ou, sem ele, os padrões do Windows), como a chave da página.
    Antes de mudar, a tela mostra o que vai ser aplicado e desfeito e pergunta. Data.ExplorerRestart: algum ajuste mudado
    só aparece depois de reiniciar o Explorador; Data.RebootRequired: algum só vale depois de reiniciar o PC.
    #>
    param (
        [switch]$Embedded,
        [switch]$PassThru
    )

    $title = (Get-WinForgeText 'Revisar os ajustes do Windows')

    Enter-WinForgeAction -Title $title -Embedded:$Embedded

    $final = $null

    try {
        $session = Get-WinForgeSessionInfo
        $isLaptop = [bool](Get-WinForgeTweakField -Entry $session -Name "IsLaptop" -Default $false)
        $catalog = @(Get-WinForgeTweakCatalog | Where-Object { (Test-WinForgeTweakInReview -Tweak $_) -and (Test-WinForgeTweakAvailable -Tweak $_) })

        # Com a política de conteúdo opcional do Windows Update (a da empresa), quem decide as atualizações antecipadas é
        # ela, e a chave da tela fica travada: marcar ou desmarcar não teria efeito, e a lista diria o que não é.
        if ([string](Get-WinForgeRegistryValueOrNull -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -Name "SetAllowOptionalContent") -eq "1") {
            $catalog = @($catalog | Where-Object { [string]$_.Id -ne "early-updates" })
        }

        # Elevado com outra conta, os ajustes do perfil do usuário mudariam o perfil dessa conta: ficam de fora, com aviso.
        $catalog = @(Get-WinForgeTweaksForSession -Tweaks $catalog)

        Write-Progress -Activity $title -Status (Get-WinForgeText 'lendo como o Windows está agora')

        try {
            $rows = @(foreach ($tweak in $catalog) { [PSCustomObject]@{ Tweak = $tweak; Status = [string](Get-WinForgeTweakStatus -Tweak $tweak) } })
        }
        finally {
            Write-Progress -Activity $title -Completed
        }

        # No menu de texto não há o que desmarcar: os números digitados são a lista inteira do que fica em uso (entre os da
        # lista; o que ela não traz, como a aparência, fica como está).
        if (Test-WinForgeGuiPrompts) {
            Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Marcado fica em uso. Desmarcar o que está em uso desfaz.')
        }
        else {
            Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Com * é o que está em uso. Digite os números de tudo o que deve ficar em uso; o resto é desfeito. P deixa como está.')
        }

        $options = @(
            foreach ($row in $rows) {
                @{ Key = [string]$row.Tweak.Id; Label = [string]$row.Tweak.Name; Description = (Get-WinForgeTweakReviewText -Tweak $row.Tweak -Status $row.Status -IsLaptop $isLaptop); Selected = ($row.Status -eq "Aplicado") }
            }
        )

        # Sem "Marcar todos": aplicaria de uma vez até os ajustes de energia que gastam a bateria do notebook. Desmarcar
        # tudo é uma resposta (desfazer todos os que estão em uso). Dentro do Otimizar, desistir da lista pula a etapa.
        $picked = Read-WinForgeMultiSelect -Message (Get-WinForgeText 'Ajustes do Windows: marcado fica em uso') -Options $options -NoSelectAll -AllowNone -CancelLabel $(if ($Embedded) { (Get-WinForgeText 'Pular') } else { "" })
        $toApply = @()
        $toRevert = @()

        if ($null -ne $picked) {
            $toApply = @($rows | Where-Object { @($picked) -contains [string]$_.Tweak.Id -and $_.Status -ne "Aplicado" })
            $toRevert = @($rows | Where-Object { @($picked) -notcontains [string]$_.Tweak.Id -and $_.Status -eq "Aplicado" })
        }

        if ($toApply.Count -eq 0 -and $toRevert.Count -eq 0) {
            Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Nada foi mudado: os ajustes ficaram como estavam.')
            $final = New-WinForgeResult -Kind Skipped -Detail (Get-WinForgeText 'você não mudou nada') -Title $title
        }
        else {
            Write-Host ""
            if ($toApply.Count -gt 0) { Write-WinForgeKeyValue -Label (Get-WinForgeText 'Aplicar') -Value (Join-WinForgeList -Items @($toApply | ForEach-Object { [string]$_.Tweak.Name })) }
            if ($toRevert.Count -gt 0) { Write-WinForgeKeyValue -Label (Get-WinForgeText 'Desfazer') -Value (Join-WinForgeList -Items @($toRevert | ForEach-Object { [string]$_.Tweak.Name })) }
            Write-Host ""

            $these = { param ([int]$Count) if ($Count -eq 1) { (Get-WinForgeText 'este ajuste') } else { (Get-WinForgeText 'estes {0} ajustes' "$Count") } }
            $question = $(if ($toRevert.Count -eq 0) { (Get-WinForgeText 'Aplicar {0}?' "$(& $these $toApply.Count)") } elseif ($toApply.Count -eq 0) { (Get-WinForgeText 'Desfazer {0}?' "$(& $these $toRevert.Count)") } elseif ($toRevert.Count -eq 1) { (Get-WinForgeText 'Aplicar {0} e desfazer 1 ajuste?' "$($toApply.Count)") } else { (Get-WinForgeText 'Aplicar {0} e desfazer {1} ajustes?' "$($toApply.Count)" "$($toRevert.Count)") })
            $verb = $(if ($toRevert.Count -eq 0) { (Get-WinForgeText 'Aplicar') } elseif ($toApply.Count -eq 0) { (Get-WinForgeText 'Desfazer') } else { (Get-WinForgeText 'Aplicar e desfazer') })

            # Com algo a desfazer, a resposta padrão é Não: um número trocado no menu de texto não desfaz a lista.
            if (-not (Confirm-WinForgeAction $question -DefaultKey $(if ($toRevert.Count -gt 0) { "N" } else { "S" }) -YesLabel $verb -NoLabel (Get-WinForgeText 'Deixar como está'))) {
                Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Nada foi mudado: os ajustes ficaram como estavam.')
                $final = New-WinForgeResult -Kind Skipped -Detail (Get-WinForgeText 'você não mudou nada') -Title $title
            }
            else {
                $final = Invoke-WinForgeTweakReviewChanges -Apply @($toApply | ForEach-Object { $_.Tweak }) -Revert @($toRevert | ForEach-Object { $_.Tweak }) -Title $title
            }
        }
    }
    catch {
        Write-WinForgeStatus -Type Error -Message (Get-WinForgeText 'Não foi possível revisar os ajustes: {0}.' "$($_.Exception.Message.TrimEnd('.'))")
        $final = New-WinForgeResult -Kind Failed -Detail $_.Exception.Message.TrimEnd('.') -Title $title
    }

    if ($PassThru) { $final }
    Exit-WinForgeAction -Embedded:$Embedded -Result $final
}


function Invoke-WinForgeTweakReviewChanges {
    # Aplica e desfaz o que a revisão do Otimizar pediu, sem perguntar, e devolve o WinForge.Result com a conta.
    param (
        [AllowEmptyCollection()][object[]]$Apply = @(),
        [AllowEmptyCollection()][object[]]$Revert = @(),
        [string]$Title = (Get-WinForgeText 'Revisar os ajustes do Windows')
    )

    $applied = 0
    $reverted = 0
    $problems = 0
    $explorer = $false
    $reboot = $false

    if (@($Apply).Count -gt 0) {
        $summary = Invoke-WinForgeTweakSet -Ids @($Apply | ForEach-Object { [string]$_.Id })
        $applied = @($summary.Results | Where-Object { $_.Kind -eq "Ok" }).Count
        $problems += @($summary.Results | Where-Object { $_.Kind -in @("Failed", "Warning") }).Count
        if ($summary.NeedsExplorerRestart) { $explorer = $true }
        if ([bool](Get-WinForgeTweakField -Entry $summary -Name "NeedsReboot" -Default $false)) { $reboot = $true }
    }

    foreach ($tweak in @($Revert)) {
        try {
            # Como a chave da página: o desfazer leva o recurso ao estado oposto mesmo no que o WinForge não mudou.
            $script:WinForgeTweakSwitchRevert = $true

            try { [void](Invoke-WinForgeTweakRevert -Tweak $tweak -Detailed) }
            finally { $script:WinForgeTweakSwitchRevert = $false }

            if ((Get-WinForgeTweakStatus -Tweak $tweak) -eq "Aplicado") {
                $problems++
                Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText '{0}: continua em uso. Uma política ou outro programa pode estar impondo o valor.' "$($tweak.Name)")
            }
            else {
                $reverted++
                Write-WinForgeStatus -Type Success -Message (Get-WinForgeText '{0}: desfeito.' "$($tweak.Name)")
                if ($tweak.RestartExplorer) { $explorer = $true }
                if ([bool](Get-WinForgeTweakField -Entry $tweak -Name "NeedsReboot" -Default $false)) { $reboot = $true }
            }
        }
        catch {
            $problems++
            Write-WinForgeStatus -Type Error -Message "$($tweak.Name): $($_.Exception.Message.TrimEnd('.'))."
        }
    }

    $parts = @()
    if ($applied -gt 0) { $parts += Format-WinForgeCount -Count $applied -One (Get-WinForgeText 'aplicado') -Many (Get-WinForgeText 'aplicados') }
    if ($reverted -gt 0) { $parts += Format-WinForgeCount -Count $reverted -One (Get-WinForgeText 'desfeito') -Many (Get-WinForgeText 'desfeitos') }
    if ($problems -gt 0) { $parts += Format-WinForgeCount -Count $problems -One (Get-WinForgeText 'com problema') -Many (Get-WinForgeText 'com problema') }

    $detail = $parts -join ", "
    $data = @{}
    if ($explorer) { $data.ExplorerRestart = $true }
    if ($reboot) { $data.RebootRequired = $true }

    # Cada ajuste pode ser mudado de novo pela chave dele, em Ajustes do Windows ou em Personalização.

    if ($problems -gt 0 -and $applied -eq 0 -and $reverted -eq 0) { return (New-WinForgeResult -Kind Failed -Detail $detail -Title $Title -Data $data) }
    if ($problems -gt 0) { return (New-WinForgeResult -Kind Warning -Detail $detail -Title $Title -Data $data) }

    return (New-WinForgeResult -Kind Ok -Detail $detail -Title $Title -Data $data)
}


# ---------------------------------------------------------------------------
# Perfis de ajustes
# ---------------------------------------------------------------------------

function Get-WinForgeTweakProfiles {
    # Conjuntos prontos de ajustes. Só citam ajustes do catálogo; o que não vale para este Windows é ignorado ao aplicar.
    return @(
        [PSCustomObject]@{
            Id          = "essential"
            Key         = "E"
            Label       = (Get-WinForgeText 'Essencial')
            Description = (Get-WinForgeText 'Extensões de arquivos visíveis e sem dicas, sugestões nem ID de publicidade')
            Ids         = @("file-extensions", "tips-suggestions", "lock-screen-tips", "advertising-id")
        },
        [PSCustomObject]@{
            Id          = "work"
            Key         = "T"
            Label       = (Get-WinForgeText 'Trabalho')
            # Os segundos no relógio não entram: são gosto, e o relógio que muda a cada segundo distrai e não deixa o
            # processador descansar.
            Description = (Get-WinForgeText 'O Essencial e menos distrações: sem Widgets e sem web na busca, menu de contexto clássico e, onde existe, sem o botão do Copilot')
            Ids         = @("file-extensions", "tips-suggestions", "lock-screen-tips", "advertising-id", "bing-start", "hide-widgets", "hide-copilot", "classic-context-menu")
        },
        [PSCustomObject]@{
            Id          = "gaming"
            Key         = "J"
            Label       = (Get-WinForgeText 'Jogos')
            Description = (Get-WinForgeText 'O Essencial e mais: Modo de Jogo, sem Game Bar, transparência, aceleração do mouse nem atalho das Teclas de Aderência, Alto desempenho e desligamento completo (em notebook, o Alto desempenho vem desmarcado)')
            Ids         = @("file-extensions", "tips-suggestions", "lock-screen-tips", "advertising-id", "game-bar", "game-mode", "mouse-acceleration", "sticky-keys-shortcut", "no-transparency", "fast-startup", "high-performance")
        },
        [PSCustomObject]@{
            Id          = "privacy"
            Key         = "P"
            Label       = (Get-WinForgeText 'Privacidade')
            Description = (Get-WinForgeText 'O Essencial e o mínimo de dados enviados: sem histórico de atividades, rastreamento, fala online, web na busca nem Recall')
            Ids         = @("file-extensions", "tips-suggestions", "lock-screen-tips", "advertising-id", "start-recommendations", "tailored-experiences", "feedback-requests", "activity-history", "diagnostic-data", "app-tracking", "online-speech", "inking-typing", "delivery-peers", "bing-start", "recall")
        },
        [PSCustomObject]@{
            Id          = "laptop"
            Key         = "N"
            Label       = (Get-WinForgeText 'Notebook')
            Description = (Get-WinForgeText 'O Essencial e mais: sem Widgets, sem transparência e sem web na busca; não mexe nos planos de energia')
            Ids         = @("file-extensions", "tips-suggestions", "lock-screen-tips", "advertising-id", "bing-start", "hide-widgets", "no-transparency")
        }
    )
}


function Invoke-WinForgeTweakProfile {
    $title = (Get-WinForgeText 'Perfis de ajustes')

    Enter-WinForgeAction -Title $title

    $final = New-WinForgeResult -Kind Ok -Title $title

    try {
        if (-not (Test-WinForgeElevation -Reason (Get-WinForgeText 'Os ajustes de sistema exigem privilégios de Administrador.'))) {
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Failed -Detail (Get-WinForgeText 'requer Administrador') -Title $title)
            return
        }

        $profiles = @(Get-WinForgeTweakProfiles)

        $options = @(
            foreach ($entry in $profiles) {
                @{ Key = $entry.Key; Label = $entry.Label; Description = $entry.Description }
            }
        )
        $options += @{ Key = "X"; Label = (Get-WinForgeText 'Cancelar'); Exit = $true }

        $answer = Read-WinForgeChoice -Message (Get-WinForgeText 'Qual perfil de ajustes?') -Options $options -DefaultKey "X" -ShowMenu `
            -TextPrompt (Get-WinForgeText 'Perfil (E, T, J, P, N ou X; ENTER = cancelar)')

        $chosen = @($profiles | Where-Object { $_.Key -ieq $answer }) | Select-Object -First 1

        if ($null -eq $chosen) {
            Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'Operação cancelada.')
            $final = New-WinForgeResult -Kind Skipped -Detail (Get-WinForgeText 'cancelado pelo usuário') -Title $title
        }
        else {
            $chosenTweaks = @(foreach ($id in @($chosen.Ids)) { $tweak = Get-WinForgeTweakById -Id $id; if ($null -ne $tweak -and (Test-WinForgeTweakAvailable -Tweak $tweak)) { $tweak } })
            $mine = @(Get-WinForgeTweaksForSession -Tweaks $chosenTweaks)
            $pending = @(Get-WinForgePendingTweaks -Ids @($mine | ForEach-Object { [string]$_.Id }))

            if ($chosenTweaks.Count -gt 0 -and $mine.Count -eq 0) {
                # Elevado com outra conta e só com ajustes do perfil do usuário (o Essencial): nada aqui é desta sessão.
                $final = Set-WinForgeResultView -Result (New-WinForgeResult -Kind Failed -Detail (Get-WinForgeText 'valem para o perfil do usuário, e o WinForge está elevado com outra conta') -Title $title) `
                    -Headline (Get-WinForgeText 'Os ajustes do perfil {0} valem para a sua conta' "$($chosen.Label)") `
                    -Note (Get-WinForgeText 'O WinForge está elevado com outra conta ({0}). Para aplicá-los, abra o WinForge de novo e recuse o pedido de Administrador: Aplicar ajustes recomendados e as chaves não o pedem.' "$([string](Get-WinForgeTweakField -Entry (Get-WinForgeSessionInfo) -Name 'User' -Default ''))")
            }
            elseif ($pending.Count -eq 0) {
                Write-WinForgeStatus -Type Success -Message (Get-WinForgeText 'Os ajustes do perfil {0} já estão aplicados (ou não valem para este Windows).' "$($chosen.Label)")
                $final = Set-WinForgeResultView -Result (New-WinForgeResult -Kind Skipped -Detail (Get-WinForgeText 'nada a aplicar') -Title $title) `
                    -Headline (Get-WinForgeText 'O perfil {0} já está aplicado' "$($chosen.Label)")
            }
            else {
                $picked = Read-WinForgeTweakSelection -Tweaks $pending -Message (Get-WinForgeText 'Perfil {0}: escolha os ajustes que deseja aplicar' "$($chosen.Label)")

                if ($null -eq $picked -or @($picked).Count -eq 0) {
                    Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'Operação cancelada.')
                    $final = New-WinForgeResult -Kind Skipped -Detail (Get-WinForgeText 'cancelado pelo usuário') -Title $title
                }
                else {
                    $final = Invoke-WinForgeTweakBatch -Ids @($picked) -Title $title
                }
            }
        }
    }
    catch {
        Write-WinForgeStatus -Type Error -Message (Get-WinForgeText 'Falha ao aplicar o perfil: {0}' "$($_.Exception.Message)")
        $final = New-WinForgeResult -Kind Failed -Detail $_.Exception.Message -Title $title
    }

    Exit-WinForgeAction -Result $final
}


# ---------------------------------------------------------------------------
# Exportar e importar ajustes
# ---------------------------------------------------------------------------

function Get-WinForgeTweakExportFolder {
    $documents = [Environment]::GetFolderPath("MyDocuments")

    if ([string]::IsNullOrWhiteSpace($documents)) {
        $documents = Get-WinForgeDataPath
    }

    return (Join-Path $documents "WinForge")
}


function Format-WinForgeTweakExportFolder {
    # A pasta da exportação como a pessoa a reconhece: "Documentos\WinForge", com o nome da pasta Documentos no idioma da
    # tela, quando é a pasta de sempre; senão, o caminho inteiro.
    param (
        [Parameter(Mandatory)][string]$Folder,
        [string]$Documents = [Environment]::GetFolderPath("MyDocuments")
    )

    if (-not [string]::IsNullOrWhiteSpace($Documents) -and $Folder -eq [System.IO.Path]::Combine($Documents, "WinForge")) {
        return "$(Get-WinForgeText 'Documentos')\WinForge"
    }

    return $Folder
}


function New-WinForgeTweakExport {
    # O conteúdo do arquivo: quais ajustes estão aplicados, para levar a outro PC.
    param (
        [string[]]$Ids,
        [datetime]$At = (Get-Date)
    )

    return [ordered]@{
        Format     = "WinForge.Tweaks"
        Version    = 1
        Build      = (Get-WinForgeBuild)
        ExportedAt = $At.ToString("o", [System.Globalization.CultureInfo]::InvariantCulture)
        Computer   = [Environment]::MachineName
        Applied    = @($Ids)
    }
}


function Read-WinForgeTweakExport {
    # Lê e valida um arquivo exportado. Devolve Ids (os que este WinForge conhece), Unknown, ExportedAt e Computer;
    # arquivo inválido gera um erro com mensagem clara.
    param (
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw (Get-WinForgeText 'O arquivo não foi encontrado: {0}' "$Path")
    }

    # Uma exportação tem poucos KB: um arquivo grande (escolhido por engano) não é lido inteiro para a memória.
    if ((Get-Item -LiteralPath $Path -ErrorAction Stop).Length -gt 1MB) {
        throw (Get-WinForgeText 'O arquivo não é uma exportação de ajustes do WinForge (é grande demais).')
    }

    try {
        $document = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        throw (Get-WinForgeText 'O arquivo não é um JSON válido.')
    }

    if ($null -eq $document -or [string](Get-WinForgeJsonValue -Object $document -Name "Format") -ne "WinForge.Tweaks") {
        throw (Get-WinForgeText 'O arquivo não é uma exportação de ajustes do WinForge.')
    }

    $applied = @(Get-WinForgeJsonValue -Object $document -Name "Applied" -Default @() | ForEach-Object { [string]$_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
    $known = @($applied | Where-Object { $null -ne (Get-WinForgeTweakById -Id $_) })

    # A data vem no formato ISO ("2026-11-01T14:30:00.0000000-03:00"); na tela, "01/11/2026 14:30", no horário daqui. O
    # PowerShell 7 já a lê como data.
    $exportedAt = Get-WinForgeJsonValue -Object $document -Name "ExportedAt" -Default ""
    $parsed = [DateTimeOffset]::MinValue

    if ($exportedAt -is [datetime]) {
        if ($exportedAt.Kind -eq [System.DateTimeKind]::Utc) { $exportedAt = $exportedAt.ToLocalTime() }
        $exportedText = Format-WinForgeDateTime -When $exportedAt
    }
    elseif ([DateTimeOffset]::TryParse([string]$exportedAt, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$parsed)) {
        $exportedText = Format-WinForgeDateTime -When $parsed.LocalDateTime
    }
    else {
        $exportedText = [string]$exportedAt
    }

    return [PSCustomObject]@{
        Ids        = $known
        Unknown    = @($applied | Where-Object { $known -notcontains $_ })
        ExportedAt = $exportedText
        Computer   = [string](Get-WinForgeJsonValue -Object $document -Name "Computer" -Default "")
    }
}


function Get-WinForgeTweakBackupIds {
    # Os Ids dos ajustes com o valor de antes guardado (os que o WinForge mudou); vazio se o backup não se lê.
    $read = Read-WinForgeTweakBackup -Status
    if ($read.Status -eq "Unreadable") { return @() }

    return @($read.Backup.Keys | ForEach-Object { [string]$_ })
}


function Get-WinForgeAppliedTweakIds {
    # Os Ids dos ajustes do WinForge que estão aplicados neste PC e valem para esta versão do Windows. Um ajuste que já é o
    # padrão do Windows (OnByDefault: o Modo de Jogo vem ativado) só conta quando foi o WinForge que o aplicou (há backup).
    # Elevado com outra conta, os do perfil do usuário ficam de fora, com aviso: o que se leria é o perfil dessa conta
    # (Exportar ajustes aplicados e o Backup antes de formatar levariam os ajustes dela).
    $backup = Read-WinForgeTweakBackup -Status
    $saved = $(if ($backup.Status -ne "Unreadable") { $backup.Backup } else { @{} })

    return @(
        Get-WinForgeTweaksForSession -Tweaks @(Get-WinForgeTweakCatalog | Where-Object { Test-WinForgeTweakAvailable -Tweak $_ }) |
            Where-Object { (Get-WinForgeTweakStatus -Tweak $_) -eq "Aplicado" } |
            Where-Object { -not [bool](Get-WinForgeTweakField -Entry $_ -Name "OnByDefault" -Default $false) -or $saved.Contains([string]$_.Id) } |
            ForEach-Object { $_.Id }
    )
}


function Export-WinForgeTweaks {
    $title = (Get-WinForgeText 'Exportar ajustes aplicados')

    Enter-WinForgeAction -Title $title

    $final = New-WinForgeResult -Kind Ok -Title $title

    try {
        $applied = @(Get-WinForgeAppliedTweakIds)

        if ($applied.Count -eq 0) {
            Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Nenhum ajuste do WinForge está aplicado neste PC; não há o que exportar.')
            $final = Set-WinForgeResultView -Result (New-WinForgeResult -Kind Skipped -Detail (Get-WinForgeText 'nada a exportar') -Title $title) `
                -Headline (Get-WinForgeText 'Nenhum ajuste para exportar') -Note (Get-WinForgeText 'Nenhum ajuste do WinForge está aplicado neste PC.')
        }
        else {
            $folder = Get-WinForgeTweakExportFolder
            [void](New-Item -ItemType Directory -Path $folder -Force -ErrorAction Stop)

            $name = (Get-WinForgeText 'WinForge-ajustes-{0}.json' "$((Get-Date).ToString('yyyy-MM-dd-HHmm', [System.Globalization.CultureInfo]::InvariantCulture))")
            $path = Join-Path $folder $name

            Set-Content -LiteralPath $path -Value (New-WinForgeTweakExport -Ids $applied | ConvertTo-Json -Depth 4) -Encoding UTF8 -ErrorAction Stop

            $exported = Format-WinForgeCount -Count $applied.Count -One (Get-WinForgeText 'ajuste exportado') -Many (Get-WinForgeText 'ajustes exportados')
            Write-WinForgeStatus -Type Success -Message "$exported."
            Write-WinForgeKeyValue -Label (Get-WinForgeText 'Arquivo') -Value $path
            Write-Host ""
            Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Copie o arquivo para o outro PC e, nele, use Ajustes do Windows > Importar ajustes.')
            $where = Format-WinForgeTweakExportFolder -Folder $folder
            $final = Set-WinForgeResultView -Result (New-WinForgeResult -Kind Ok -Detail (Get-WinForgeText '{0} para {1}' "$exported" "$where") -Title $title) -Headline $exported `
                -Note (Get-WinForgeText 'Salvo em {0}. No outro PC, use Ajustes do Windows > Importar ajustes.' "$where")
            Write-Host ""

            # Como em Verificar nova versão: a pasta abre com o arquivo já selecionado, pronto para copiar.
            if (Confirm-WinForgeAction -Message (Get-WinForgeText 'Mostrar o arquivo na pasta?') -DefaultKey S -YesLabel (Get-WinForgeText 'Mostrar') -NoLabel (Get-WinForgeText 'Agora não')) {
                try {
                    Start-Process -FilePath "explorer.exe" -ArgumentList "/select,`"$path`"" -ErrorAction Stop
                }
                catch {
                    Write-WinForgeStatus -Type Warning -Notice -Message (Get-WinForgeText 'Não foi possível abrir a pasta: {0}' "$($_.Exception.Message)")
                }
            }
        }
    }
    catch {
        Write-WinForgeStatus -Type Error -Message (Get-WinForgeText 'Não foi possível exportar: {0}' "$($_.Exception.Message)")
        $final = New-WinForgeResult -Kind Failed -Detail $_.Exception.Message -Title $title
    }

    Exit-WinForgeAction -Result $final
}


function Invoke-WinForgeTweakImportFile {
    # Mostra o conteúdo de um arquivo exportado, deixa escolher o que aplicar e aplica. Devolve o Result.
    # Quem chama cuida do Administrador e do Enter/Exit-WinForgeAction.
    param (
        [Parameter(Mandatory)]
        [string]$Path,

        [string]$Title = (Get-WinForgeText 'Importar ajustes')
    )

    $final = New-WinForgeResult -Kind Ok -Title $Title

    $export = Read-WinForgeTweakExport -Path $Path

    Write-WinForgeKeyValue -Label (Get-WinForgeText 'Arquivo') -Value $Path
    Write-WinForgeKeyValue -Label (Get-WinForgeText 'Exportado em') -Value $(if ($export.ExportedAt) { $export.ExportedAt } else { $null })
    Write-WinForgeKeyValue -Label (Get-WinForgeText 'Computador de origem') -Value $(if ($export.Computer) { $export.Computer } else { $null })

    if ($export.Unknown.Count -gt 0) {
        Write-Host ""
        Write-WinForgeStatus -Type Warning -Message "$(Format-WinForgeCount -Count $export.Unknown.Count -One (Get-WinForgeText 'ajuste de outra versão do WinForge será ignorado') -Many (Get-WinForgeText 'ajustes de outra versão do WinForge serão ignorados'))."
    }

    Write-Host ""

    $fileTweaks = @(foreach ($id in @($export.Ids)) { $tweak = Get-WinForgeTweakById -Id $id; if ($null -ne $tweak -and (Test-WinForgeTweakAvailable -Tweak $tweak)) { $tweak } })
    $pending = @(Get-WinForgePendingTweaks -Ids @(Get-WinForgeTweaksForSession -Tweaks $fileTweaks | ForEach-Object { [string]$_.Id }))

    if ($export.Ids.Count -eq 0) {
        # Arquivo sem ajustes (exportado sem nenhum aplicado) ou só com ajustes de outra versão: não é "já aplicado".
        Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'O arquivo não traz nenhum ajuste que esta versão do WinForge conheça.')
        $final = New-WinForgeResult -Kind Skipped -Detail (Get-WinForgeText 'o arquivo não traz ajustes conhecidos') -Title $Title
    }
    elseif ($pending.Count -eq 0) {
        Write-WinForgeStatus -Type Success -Message (Get-WinForgeText 'Nada a aplicar: os ajustes do arquivo já estão aplicados (ou não valem para este Windows).')
        $final = New-WinForgeResult -Kind Skipped -Detail (Get-WinForgeText 'nada a aplicar') -Title $Title
    }
    else {
        $picked = Read-WinForgeTweakSelection -Tweaks $pending -Message (Get-WinForgeText 'Escolha os ajustes do arquivo que deseja aplicar')

        if ($null -eq $picked -or @($picked).Count -eq 0) {
            Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'Operação cancelada.')
            $final = New-WinForgeResult -Kind Skipped -Detail (Get-WinForgeText 'cancelado pelo usuário') -Title $Title
        }
        else {
            $final = Invoke-WinForgeTweakBatch -Ids @($picked) -Title $Title
        }
    }

    return $final
}


function Import-WinForgeTweaks {
    $title = (Get-WinForgeText 'Importar ajustes')

    Enter-WinForgeAction -Title $title

    $final = New-WinForgeResult -Kind Ok -Title $title

    try {
        if (-not (Test-WinForgeElevation -Reason (Get-WinForgeText 'Os ajustes de sistema exigem privilégios de Administrador.'))) {
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Failed -Detail (Get-WinForgeText 'requer Administrador') -Title $title)
            return
        }

        $folder = Get-WinForgeTweakExportFolder
        $files = @()

        if (Test-Path -LiteralPath $folder -PathType Container) {
            # O nome do arquivo segue o idioma de quem exportou ("WinForge-ajustes-..." ou "WinForge-tweaks-...").
            $files = @(Get-ChildItem -LiteralPath $folder -Filter "WinForge-*.json" -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^WinForge-(ajustes|tweaks)-' } | Sort-Object LastWriteTime -Descending | Select-Object -First 6)
        }

        $options = @()
        $position = 0

        # Cada arquivo pelo que ele traz ("Exportado em 01/11/2026 14:30", "8 ajustes · PC-SALA"), e não pelo nome do
        # arquivo; um arquivo que não se lê aparece pelo nome, e a importação diz o problema.
        foreach ($file in $files) {
            $position++
            $label = $file.Name
            $description = Format-WinForgeDateTime -When $file.LastWriteTime

            try {
                $content = Read-WinForgeTweakExport -Path $file.FullName
                if ($content.ExportedAt) { $label = (Get-WinForgeText 'Exportado em {0}' "$($content.ExportedAt)") }
                $count = @($content.Ids).Count + @($content.Unknown).Count
                $description = (@((Format-WinForgeCount -Count $count -One (Get-WinForgeText 'ajuste') -Many (Get-WinForgeText 'ajustes')), $content.Computer) | Where-Object { $_ }) -join " · "
            }
            catch {
                $label = $file.Name
            }

            $options += @{ Key = [string]$position; Label = $label; Description = $description }
        }

        $options += @{ Key = "O"; Label = (Get-WinForgeText 'Outro arquivo'); Description = (Get-WinForgeText 'Informar o caminho completo de um arquivo exportado') }
        $options += @{ Key = "X"; Label = (Get-WinForgeText 'Cancelar'); Exit = $true }

        $answer = Read-WinForgeChoice -Message (Get-WinForgeText 'Qual arquivo importar?') -Options $options -DefaultKey "X" -ShowMenu `
            -TextPrompt (Get-WinForgeText 'Arquivo (número, O = outro, X = cancelar; ENTER = cancelar)')

        $path = ""

        if ($answer -ieq "O") {
            # Colado do Explorador ("Copiar como caminho") vem entre aspas; %USERPROFILE% e afins valem.
            $path = [Environment]::ExpandEnvironmentVariables((Read-WinForgeText -Message (Get-WinForgeText 'Caminho completo do arquivo .json')).Trim().Trim('"', "'"))
        }
        elseif ($answer -match "^[0-9]+$" -and [int]$answer -ge 1 -and [int]$answer -le $files.Count) {
            $path = $files[[int]$answer - 1].FullName
        }

        if ([string]::IsNullOrWhiteSpace($path)) {
            Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'Operação cancelada.')
            Exit-WinForgeAction -Result (New-WinForgeResult -Kind Skipped -Detail (Get-WinForgeText 'cancelado pelo usuário') -Title $title)
            return
        }

        $final = Invoke-WinForgeTweakImportFile -Path $path -Title $title
    }
    catch {
        Write-WinForgeStatus -Type Error -Message (Get-WinForgeText 'Não foi possível importar: {0}' "$($_.Exception.Message)")
        $final = New-WinForgeResult -Kind Failed -Detail $_.Exception.Message -Title $title

        # O título da faixa diz o que aconteceu; o motivo (um JSON inválido, outro tipo de arquivo) vem embaixo, legível
        # como no resumo (sem o embrulho do PowerShell, a recusa de acesso no idioma da tela).
        $why = (ConvertTo-WinForgeReadableError -Text ([string]$_.Exception.Message)).Trim()
        if ($why -and $why -notmatch '[.!?]$') { $why = "$why." }
        [void](Set-WinForgeResultView -Result $final -Headline (Get-WinForgeText 'O arquivo não foi importado') -Note $why)
    }

    Exit-WinForgeAction -Result $final
}


function Invoke-WinForgeTweakToggle {
    # Ativa ou desativa o recurso que a chave mostra, lido do Windows agora: aplica o ajuste se ele não está aplicado e
    # desfaz se está. -AlreadyConfirmed: na janela, ligar ou desligar a chave já é a confirmação. Pedem confirmação mesmo
    # assim o que gasta bateria num notebook e o que tem o estado não identificado (a chave não diz o que vai acontecer).
    # -Want: o estado que a pessoa pediu na chave ("On" ou "Off"). Se o Windows já está assim (a página estava velha: a
    # pessoa mudou nas Configurações depois de abrir), nada muda; sem isso, o clique faria o contrário do pedido.
    param (
        [Parameter(Mandatory)]
        $Tweak,

        [switch]$AlreadyConfirmed,

        [ValidateSet("", "On", "Off")]
        [string]$Want = ""
    )

    # O recurso do Windows que a chave mostra, e se o ajuste o desativa (a chave fica ativada com o ajuste fora).
    $feature = [string](Get-WinForgeTweakField -Entry $Tweak -Name "Feature" -Default $Tweak.Name)
    $about = [string](Get-WinForgeTweakField -Entry $Tweak -Name "About" -Default $Tweak.Description)
    $inverted = [bool](Get-WinForgeTweakField -Entry $Tweak -Name "Inverted" -Default $false)

    Enter-WinForgeAction -Title $feature

    # O estado é lido do Windows agora, e não do que o WinForge fez antes.
    $status = Get-WinForgeTweakStatus -Tweak $Tweak
    $session = Get-WinForgeSessionInfo

    $current = Get-WinForgeTweakSwitchState -Status $status -Inverted $inverted

    Write-WinForgeKeyValue -Label (Get-WinForgeText 'Recurso') -Value $feature
    Write-WinForgeKeyValue -Label (Get-WinForgeText 'Estado atual') -Value $current.Caption
    Write-WinForgeStatus -Type Info -Notice -Message $about

    if ($session.IsLaptop -and $Tweak.LaptopRisk -and -not [string]::IsNullOrWhiteSpace($Tweak.Warning)) {
        Write-Host ""
        Write-WinForgeStatus -Type Warning -Message $Tweak.Warning
    }

    if ($Tweak.UserScope -and $session.UserMismatch) {
        # Elevado com outra conta, o HKCU é o dessa conta: a chave mudaria o perfil errado (e o estado lido também é o dela).
        # Como nos perfis, na importação e nos recomendados, o ajuste fica de fora; antes, a chave aplicava e dizia "Tudo certo".
        Write-Host ""
        Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'O WinForge está elevado com outra conta ({0}): este ajuste vale para o perfil do usuário e mudaria o perfil dessa conta, não o seu. Para usá-lo, abra o WinForge sem trocar de conta no pedido de Administrador.' "$($session.User)")
        Exit-WinForgeAction -Result (New-WinForgeResult -Kind Failed -Detail (Get-WinForgeText 'vale para o perfil do usuário, e o WinForge está elevado com outra conta') -Title $feature)
        return
    }

    if ($Tweak.RequiresAdmin -and -not (Test-WinForgeAdministrator)) {
        Write-Host ""
        [void](Test-WinForgeElevation -Reason (Get-WinForgeText '''{0}'' exige privilégios de Administrador.' "$feature"))
        Exit-WinForgeAction -Result (New-WinForgeResult -Kind Failed -Detail (Get-WinForgeText 'requer Administrador') -Title $feature)
        return
    }

    Write-Host ""

    # Aplicado: a chave desfaz o ajuste; senão, aplica. Depois, o recurso fica ativado ou desativado conforme o sentido
    # do ajuste (num ajuste que desativa o recurso, aplicar desativa e desfazer ativa).
    $reverting = ($status -eq "Aplicado")
    $turnsOn = $(if ($reverting) { $inverted } else { -not $inverted })
    $verb = $(if ($turnsOn) { (Get-WinForgeText 'ativar') } else { (Get-WinForgeText 'desativar') })
    $done = $(if ($turnsOn) { (Get-WinForgeText 'ativado') } else { (Get-WinForgeText 'desativado') })

    $question = (Get-WinForgeText "Deseja {0} `"{1}`"?" "$verb" "$feature")
    $yesLabel = $(if ($turnsOn) { (Get-WinForgeText 'Ativar') } else { (Get-WinForgeText 'Desativar') })

    # Sem o estado lido, a chave não diz nada: a pergunta diz o que vai acontecer, mesmo vinda da janela.
    $unknown = ($status -notin @("Aplicado", "Padrão"))

    if ($unknown) {
        $question = (Get-WinForgeText "Não foi possível ler o estado atual. Deseja {0} `"{1}`"?" "$verb" "$feature")
    }
    elseif ($Want -and (($Want -eq "On") -eq $current.IsOn)) {
        # A página estava velha: o Windows já está como a pessoa pediu. Nada muda; a lista é lida de novo ao voltar.
        Write-WinForgeStatus -Type Info -Message (Get-WinForgeText '{0}: já está {1} no Windows (mudou depois que a página foi aberta). Nada foi alterado.' "$($feature)" "$($current.Caption.ToLowerInvariant())")
        Exit-WinForgeAction -Result (New-WinForgeResult -Kind Skipped -Detail (Get-WinForgeText 'já estava {0}' "$($current.Caption.ToLowerInvariant())") -Title $feature)
        return
    }

    $needsExtraConfirmation = ((-not $reverting) -and $session.IsLaptop -and $Tweak.LaptopRisk)
    $skipQuestion = ($AlreadyConfirmed -and -not $needsExtraConfirmation -and -not $unknown)

    # No notebook, o ajuste que gasta bateria pede uma confirmação própria, com Não como padrão.
    $defaultKey = "S"

    if ($needsExtraConfirmation) {
        $question = (Get-WinForgeText "No notebook, isto afeta a bateria (veja o aviso acima). Deseja {0} `"{1}`" mesmo assim?" "$verb" "$feature")
        $yesLabel = $(if ($turnsOn) { (Get-WinForgeText 'Ativar mesmo assim') } else { (Get-WinForgeText 'Desativar mesmo assim') })
        $defaultKey = "N"
    }

    if ((-not $skipQuestion) -and -not (Confirm-WinForgeAction $question -DefaultKey $defaultKey -YesLabel $yesLabel -NoLabel (Get-WinForgeText 'Cancelar'))) {
        Write-Host ""
        Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'Operação cancelada.')
        Exit-WinForgeAction -Result (New-WinForgeResult -Kind Skipped -Detail (Get-WinForgeText 'cancelado pelo usuário') -Title $feature)
        return
    }

    # O desfecho que a janela mostra: os avisos de antes da pergunta (notebook, outra conta) não o rebaixam.
    $final = New-WinForgeResult -Kind Ok -Detail $done -Title $feature

    # A frase da faixa: como voltar, ou a que valor voltou; e, sem o Explorador reiniciado, quando a mudança aparece.
    $note = ""

    # Quiet: além do novo estado, não há nada a ler, e a janela mostra o resultado na própria linha da chave. Algo a mais
    # (o que ficou como estava, a hibernação ligada junto, o que falta para aparecer) leva à tela de execução.
    $quiet = $true

    try {
        Write-Host ""

        if ($reverting) {
            # A chave pede o estado oposto: o desfazer leva o recurso até lá mesmo no que o WinForge não mudou (o plano ativo).
            $script:WinForgeTweakSwitchRevert = $true

            try { $report = Invoke-WinForgeTweakRevert -Tweak $Tweak -Detailed }
            finally { $script:WinForgeTweakSwitchRevert = $false }

            $hadBackup = $report.HadBackup

            if ($report.Restored -eq 0) {
                # O que está agora foi escolhido depois do WinForge (outro plano de alto desempenho, por exemplo): fica.
                Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Nada a desfazer: o que o WinForge mudou já foi alterado depois, e a escolha de agora foi mantida.')
                $final = New-WinForgeResult -Kind Skipped -Detail (Get-WinForgeText 'nada a desfazer; foi alterado depois') -Title $feature
            }
            elseif ((Get-WinForgeTweakStatus -Tweak $Tweak) -eq "Aplicado") {
                # A leitura de agora é a que vale: o Windows não aceitou a mudança.
                $still = (Get-WinForgeTweakSwitchState -Status "Aplicado" -Inverted $inverted).Caption.ToLowerInvariant()
                Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText '{0}: continua {1}. Uma política ou outro programa pode estar impondo o valor.' "$($feature)" "$still")
                $final = Set-WinForgeResultView -Result (New-WinForgeResult -Kind Warning -Detail (Get-WinForgeText 'continua {0}' "$still") -Title $feature) `
                    -Headline (Get-WinForgeText '{0}: nada mudou' "$feature") -Note (Get-WinForgeText 'Continua {0}. Uma política ou outro programa pode estar impondo o valor.' "$still")
            }
            elseif ($report.Kept -gt 0) {
                Write-WinForgeStatus -Type Success -Message (Get-WinForgeText '{0}: {1}; o que foi alterado depois foi mantido.' "$($feature)" "$done")
                $note = (Get-WinForgeText 'O que foi alterado depois do WinForge foi mantido.')
                $quiet = $false
            }
            else {
                Write-WinForgeStatus -Type Success -Message "$($feature): $done."
                $note = (Get-WinForgeText 'Voltou ao valor de antes do WinForge.')
            }

            # O valor de antes do WinForge não estava guardado (o ajuste já estava assim, ou foi feito fora do WinForge):
            # valem os padrões do Windows. O Modo de Jogo não tem padrão a usar: desfazer é desativá-lo.
            if (-not $hadBackup -and -not [bool](Get-WinForgeTweakField -Entry $Tweak -Name "OnByDefault" -Default $false)) {
                Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Não havia o valor de antes guardado; foram usados os padrões do Windows.')
                if ($report.Kept -eq 0) { $note = (Get-WinForgeText 'Não havia o valor de antes guardado; foram usados os padrões do Windows.') }
            }

            # O desfazer fez algo a mais que a pessoa precisa saber (a hibernação ligada junto com a Inicialização Rápida).
            $extra = [string](Get-WinForgeTweakField -Entry $report -Name "Note" -Default "")
            if ($extra -and $final.Kind -eq "Ok") { $note = "$note $extra".Trim(); $quiet = $false }
        }
        else {
            # Só um estado lido com certeza poupa a nova leitura: "Desconhecido" pede que a aplicação leia de novo.
            Invoke-WinForgeTweakApply -Tweak $Tweak -Status $(if ($status -in @("Aplicado", "Padrão")) { $status } else { "" })

            if ((Get-WinForgeTweakStatus -Tweak $Tweak) -eq "Aplicado") {
                $howToUndo = $(if (Test-WinForgeGuiMode) { (Get-WinForgeText 'use a chave de novo') } else { (Get-WinForgeText 'escolha este item de novo') })
                Write-WinForgeStatus -Type Success -Message (Get-WinForgeText '{0}: {1}. O valor de antes foi guardado; para voltar, {2}.' "$($feature)" "$done" "$howToUndo")
                $note = (Get-WinForgeText 'O valor de antes foi guardado; para voltar, {0}.' "$howToUndo")

                $hint = Get-WinForgeTweakApplyHint -Tweak $Tweak
                if ($hint) {
                    Write-WinForgeStatus -Type Info -Message $hint
                    $note = "$note $hint"
                    $quiet = $false
                }
            }
            else {
                Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'O valor foi gravado, mas o Windows não o manteve. Uma política da organização pode estar impondo outro valor.')
                $final = Set-WinForgeResultView -Result (New-WinForgeResult -Kind Warning -Detail (Get-WinForgeText 'o Windows não manteve o valor') -Title $feature) `
                    -Headline (Get-WinForgeText '{0}: nada mudou' "$feature") -Note (Get-WinForgeText 'O valor foi gravado, mas o Windows não o manteve. Uma política da organização pode estar impondo outro valor.')
            }
        }

        # O Explorador só é reiniciado quando algo mudou: com o valor que o Windows não manteve, ou com nada a desfazer,
        # fechar as janelas de pastas não mostraria nada novo.
        if ($Tweak.RestartExplorer -and $final.Kind -eq "Ok") {
            Write-Host ""
            $restart = Request-WinForgeExplorerRestart -Question (Get-WinForgeText 'Reiniciar o Explorador de Arquivos agora para ver a mudança?')

            if ($restart -eq "Failed") {
                # A mudança foi feita; só o Explorador não reiniciou: o título diz como o recurso ficou, e a frase, quando aparece.
                $final = Set-WinForgeResultView -Result (New-WinForgeResult -Kind Warning -Detail (Get-WinForgeText 'o Explorador não reiniciou') -Title $feature) `
                    -Headline "$($feature): $done" -Note (Get-WinForgeText 'O Explorador não reiniciou; a mudança aparece quando você sair e entrar de novo no Windows.')
            }
            elseif ($restart -eq "Declined") {
                $note = (Get-WinForgeText '{0} A mudança aparece quando você sair e entrar de novo no Windows.' "$note").Trim()
            }
        }

        # Um ajuste que só vale depois de reiniciar o PC (o agendamento da placa de vídeo), ao aplicar e ao desfazer: a
        # faixa pede o reinício, e ele não termina na própria linha.
        $reboot = ([bool](Get-WinForgeTweakField -Entry $Tweak -Name "NeedsReboot" -Default $false) -and $final.Kind -eq "Ok")

        # Na janela, o título diz o recurso e como ele ficou ("Modo escuro: ativado"); a frase, o resto.
        if ($final.Kind -eq "Ok") {
            [void](Set-WinForgeResultView -Result $final -Headline "$($feature): $done" -Note $note -Quiet:($quiet -and -not $reboot))
        }

        if ($reboot) { $final.Data["RebootRequired"] = $true }
    }
    catch {
        $help = Get-WinForgeTweakProtectedHelp -Tweak $Tweak -Undo:$reverting
        Write-Host ""

        if ($null -ne $help -and (Test-WinForgeAccessDenied -Exception $_.Exception)) {
            # A recusa é de propósito (UCPD): repetir não adianta; a dica diz onde a mudança é feita.
            Write-WinForgeStatus -Type Warning -Message (Get-WinForgeTweakProtectedText -Help $help)
            $final = Set-WinForgeResultView -Result (New-WinForgeResult -Kind Warning -Detail (Get-WinForgeText 'o Windows protege esta configuração e não deixa o WinForge mudá-la') -Title $feature) `
                -Headline (Get-WinForgeText '{0}: nada mudou' "$feature") -Note (Get-WinForgeTweakProtectedText -Help $help)

            if ($help.Shortcut) {
                Write-Host ""
                if (Confirm-WinForgeAction (Get-WinForgeText 'Abrir as Configurações da barra de tarefas agora?') -DefaultKey S -YesLabel (Get-WinForgeText 'Abrir') -NoLabel (Get-WinForgeText 'Agora não')) { [void](Open-WinForgeShortcut -Name $help.Shortcut) }
            }
        }
        else {
            Write-WinForgeStatus -Type Error -Message (Get-WinForgeText 'Falha ao alterar o ajuste: {0}' "$($_.Exception.Message)")
            $final = New-WinForgeResult -Kind Failed -Detail $_.Exception.Message -Title $feature

            # O título diz que o recurso ficou como estava; a frase, o motivo, legível como no resumo.
            $why = (ConvertTo-WinForgeReadableError -Text ([string]$_.Exception.Message)).Trim()
            if ($why) { $why = "$($why.Substring(0, 1).ToUpperInvariant())$($why.Substring(1))" }
            if ($why -and $why -notmatch '[.!?]$') { $why = "$why." }
            [void](Set-WinForgeResultView -Result $final -Headline (Get-WinForgeText '{0}: nada mudou' "$feature") -Note $why)
        }
    }

    Exit-WinForgeAction -Result $final
}


function Format-WinForgeTweakAppliedAt {
    # Quando o ajuste foi aplicado (AppliedAt, no backup) como "01/11/2026 14:30"; vazio sem a data ou com uma data que
    # não se lê.
    param ($Entry)

    $value = Get-WinForgeTweakField -Entry $Entry -Name "AppliedAt" -Default ""
    $when = [datetime]::MinValue

    # O PowerShell 7 já lê do JSON uma data; o Windows PowerShell 5.1, o texto ("2026-11-01T14:30:00").
    if ($value -is [datetime]) { return (Format-WinForgeDateTime -When $value) }

    if ([datetime]::TryParse([string]$value, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$when)) {
        return (Format-WinForgeDateTime -When $when)
    }

    return ""
}


function Invoke-WinForgeRevertAllTweaks {
    $title = (Get-WinForgeText 'Desfazer ajustes do WinForge')

    Enter-WinForgeAction -Title $title

    if (-not (Test-WinForgeElevation -Reason (Get-WinForgeText 'Desfazer ajustes de sistema exige privilégios de Administrador.'))) {
        Exit-WinForgeAction -Result (New-WinForgeResult -Kind Failed -Detail (Get-WinForgeText 'requer Administrador') -Title $title)
        return
    }

    $read = Read-WinForgeTweakBackup -Status

    if ($read.Status -eq "Unreadable") {
        Write-WinForgeStatus -Type Error -Message (Get-WinForgeTweakBackupUnreadableText)
        Exit-WinForgeAction -Result (New-WinForgeResult -Kind Failed -Detail (Get-WinForgeText 'não foi possível ler o backup dos ajustes') -Title $title)
        return
    }

    $ids = @($read.Backup.Keys)

    if ($ids.Count -eq 0) {
        Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Não há ajustes do WinForge com backup para desfazer.')
        Exit-WinForgeAction -Result (Set-WinForgeResultView -Result (New-WinForgeResult -Kind Skipped -Detail (Get-WinForgeText 'não há ajustes com backup para desfazer') -Title $title) `
                -Headline (Get-WinForgeText 'Nenhum ajuste do WinForge para desfazer'))
        return
    }

    # Desfaz na ordem inversa da aplicação: ajustes feitos dentro de um plano de energia saem antes de o plano voltar.
    $catalogOrder = @(Get-WinForgeTweakCatalog | ForEach-Object { $_.Id })
    $known = @($catalogOrder | Where-Object { $ids -contains $_ })
    [array]::Reverse($known)
    $unknown = @($ids | Where-Object { $catalogOrder -notcontains $_ })

    if ($known.Count -eq 0) {
        Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'Os backups encontrados são de ajustes que esta versão do WinForge não conhece ({0}). Nada foi desfeito.' "$($unknown -join ', ')")
        Exit-WinForgeAction -Result (New-WinForgeResult -Kind Skipped -Detail (Get-WinForgeText 'os backups são de ajustes que esta versão não conhece') -Title $title)
        return
    }

    # A lista do que vai ser desfeito, com a data de cada um. O que mudou depois só se sabe ao desfazer (a leitura de
    # agora vê o plano de energia ativo, não o plano em que o ajuste foi feito), e o resultado de cada um diz.
    Write-WinForgeSection -Title (Get-WinForgeText 'Serão desfeitos')

    # A coluna dos nomes cabe o maior deles, até 48 caracteres.
    $longest = [int](@($known | ForEach-Object { (Get-WinForgeTweakById -Id $_).Name.Length }) | Measure-Object -Maximum).Maximum
    $width = $(if ($longest -ge 48) { 48 } else { $longest + 1 })

    foreach ($id in $known) {
        $when = Format-WinForgeTweakAppliedAt -Entry $read.Backup[$id]
        Write-WinForgeKeyValue -Label (Get-WinForgeTweakById -Id $id).Name -Value $(if ($when) { (Get-WinForgeText 'aplicado em {0}' "$when") } else { (Get-WinForgeText 'aplicado pelo WinForge') }) -LabelWidth $width
    }

    Write-Host ""

    if ($unknown.Count -gt 0) {
        Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'Backups de ajustes desconhecidos serão mantidos (versão diferente do WinForge?): {0}' "$($unknown -join ', ')")
        Write-Host ""
    }

    if (-not (Confirm-WinForgeAction (Get-WinForgeText 'Desfazer todos agora?') -DefaultKey N -YesLabel (Get-WinForgeText 'Desfazer todos') -NoLabel (Get-WinForgeText 'Cancelar'))) {
        Write-Host ""
        Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'Operação cancelada.')
        Exit-WinForgeAction -Result (New-WinForgeResult -Kind Skipped -Detail (Get-WinForgeText 'cancelado pelo usuário') -Title $title)
        return
    }

    $needsExplorerRestart = $false
    $failures = 0
    $untouched = 0
    $position = 0
    $doneNames = @()
    $failedNames = @()

    try {
        foreach ($id in $known) {
            $tweak = Get-WinForgeTweakById -Id $id
            $position++
            Write-Progress -Activity (Get-WinForgeText 'Desfazendo os ajustes') -Status (Get-WinForgeText '{0} de {1}: {2}' "$position" "$($known.Count)" "$($tweak.Name)") -PercentComplete ([int](100 * ($position - 1) / $known.Count))

            try {
                $report = Invoke-WinForgeTweakRevert -Tweak $tweak -Detailed

                if ($report.Restored -eq 0) {
                    # Tudo dele foi alterado depois: nada voltou, e o backup saiu (não há mais o que desfazer).
                    $untouched++
                    Write-WinForgeStatus -Type Info -Message (Get-WinForgeText '{0}: nada a desfazer; foi alterado depois.' "$($tweak.Name)")
                }
                elseif ($report.Kept -gt 0) {
                    Write-WinForgeStatus -Type Success -Message (Get-WinForgeText '{0}: desfeito; o que foi alterado depois foi mantido.' "$($tweak.Name)")
                    $doneNames += [string]$tweak.Name
                }
                else {
                    Write-WinForgeStatus -Type Success -Message (Get-WinForgeText '{0}: desfeito.' "$($tweak.Name)")
                    $doneNames += [string]$tweak.Name
                }

                if ($tweak.RestartExplorer -and $report.Restored -gt 0) { $needsExplorerRestart = $true }
            }
            catch {
                $failures++
                $failedNames += [string]$tweak.Name
                $help = Get-WinForgeTweakProtectedHelp -Tweak $tweak -Undo

                if ($null -ne $help -and (Test-WinForgeAccessDenied -Exception $_.Exception)) {
                    Write-WinForgeStatus -Type Error -Message "$($tweak.Name): $(Get-WinForgeTweakProtectedText -Help $help)"
                }
                else {
                    Write-WinForgeStatus -Type Error -Message "$($tweak.Name): $($_.Exception.Message)"
                }
            }
        }
    }
    finally {
        Write-Progress -Activity (Get-WinForgeText 'Desfazendo os ajustes') -Completed
    }

    Write-Host ""

    $done = $known.Count - $failures - $untouched

    if ($failures -gt 0) {
        Write-WinForgeStatus -Type Warning -Message $(if ($failures -eq 1) { (Get-WinForgeText '1 ajuste não pôde ser desfeito; o backup dele foi mantido para uma nova tentativa.') } else { (Get-WinForgeText '{0} ajustes não puderam ser desfeitos; o backup deles foi mantido para uma nova tentativa.' "$failures") })

        if ($done -eq 0) {
            $final = New-WinForgeResult -Kind Failed -Detail (Get-WinForgeText 'nenhum ajuste pôde ser desfeito') -Title $title
        }
        else {
            $final = New-WinForgeResult -Kind Warning -Detail (Get-WinForgeText '{0} de {1} não puderam ser desfeitos' "$failures" "$($known.Count)") -Title $title
        }
    }
    elseif ($done -eq 0) {
        Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Nada foi desfeito: os ajustes já tinham sido alterados depois.')
        $final = New-WinForgeResult -Kind Skipped -Detail (Get-WinForgeText 'os ajustes já tinham sido alterados depois') -Title $title
    }
    else {
        $doneText = Format-WinForgeCount -Count $done -One (Get-WinForgeText 'ajuste desfeito') -Many (Get-WinForgeText 'ajustes desfeitos')
        Write-WinForgeStatus -Type Success -Message "$doneText."
        $final = New-WinForgeResult -Kind Ok -Detail $doneText -Title $title
    }

    $restart = ""

    if ($needsExplorerRestart) {
        $restart = Request-WinForgeExplorerRestart -Question (Get-WinForgeText 'Reiniciar o Explorador de Arquivos agora?')

        if ($restart -eq "Failed" -and $final.Kind -eq "Ok") {
            $final = New-WinForgeResult -Kind Warning -Detail (Get-WinForgeText 'o Explorador não reiniciou') -Title $title
        }
    }

    # Na janela, o título diz quantos foram desfeitos; a frase, quais (ou, com falhas, quais ficaram, com o backup mantido) e,
    # sem o Explorador reiniciado, quando a mudança aparece.
    $later = $(if ($restart -eq "Declined") { (Get-WinForgeText ' {0} quando você sair e entrar de novo no Windows.' "$(if ($done -eq 1) { (Get-WinForgeText 'A mudança aparece') } else { (Get-WinForgeText 'As mudanças aparecem') })") } else { "" })

    if ($final.Kind -eq "Ok" -and $done -gt 0) {
        [void](Set-WinForgeResultView -Result $final -Headline (Format-WinForgeCount -Count $done -One (Get-WinForgeText 'ajuste desfeito') -Many (Get-WinForgeText 'ajustes desfeitos')) `
                -Note "$(Join-WinForgeShortList -Items $doneNames).$later")
    }
    elseif ($final.Kind -eq "Warning" -and $done -gt 0 -and $failedNames.Count -gt 0) {
        $kept = $(if ($failedNames.Count -eq 1) { (Get-WinForgeText 'não pôde ser desfeito; o backup dele foi mantido para uma nova tentativa') } else { (Get-WinForgeText 'não puderam ser desfeitos; o backup deles foi mantido para uma nova tentativa') })
        [void](Set-WinForgeResultView -Result $final -Headline (Get-WinForgeText '{0} de {1} ajustes desfeitos' "$done" "$($known.Count)") -Note "$(Join-WinForgeShortList -Items $failedNames) $kept.$later")
    }
    elseif ($final.Kind -eq "Failed" -and $done -eq 0 -and $failedNames.Count -gt 0) {
        # Nenhum voltou: o título diz isso, e a frase, que o backup ficou e onde está o motivo.
        [void](Set-WinForgeResultView -Result $final -Headline (Get-WinForgeText 'Nenhum ajuste foi desfeito') `
                -Note $(if ($failedNames.Count -eq 1) { (Get-WinForgeText 'O backup foi mantido para uma nova tentativa; o motivo está no resumo.') } else { (Get-WinForgeText 'O backup foi mantido para uma nova tentativa; o motivo de cada um está no resumo.') }))
    }
    elseif ($final.Kind -eq "Warning" -and $restart -eq "Failed" -and $done -gt 0) {
        # Os ajustes voltaram; só o Explorador não reiniciou.
        [void](Set-WinForgeResultView -Result $final -Headline (Format-WinForgeCount -Count $done -One (Get-WinForgeText 'ajuste desfeito') -Many (Get-WinForgeText 'ajustes desfeitos')) `
                -Note $(if ($done -eq 1) { (Get-WinForgeText 'O Explorador não reiniciou; a mudança aparece quando você sair e entrar de novo no Windows.') } else { (Get-WinForgeText 'O Explorador não reiniciou; as mudanças aparecem quando você sair e entrar de novo no Windows.') }))
    }

    Exit-WinForgeAction -Result $final
}


# ---------------------------------------------------------------------------
# O desfazer das teclas que trocam o idioma do teclado
# ---------------------------------------------------------------------------

function Get-WinForgeChoiceSpec {
    <#
    Os valores que uma escolha grava, na ordem em que o Windows os grava: as teclas que trocam o idioma do teclado (Ajustes
    do Windows), todos de texto. O desfazer só devolve estes valores, com os caminhos daqui: o diário fica onde qualquer
    programa da conta grava, e dele só vêm os dados, conferidos pelo formato (Pattern). Identity marca os valores que
    dizem qual é a escolha de agora: se mudaram depois, o desfazer não passa por cima.
    #>
    param ([Parameter(Mandatory)][ValidateSet("keyboard-hotkeys")][string]$Kind)

    $toggle = "HKCU:\Keyboard Layout\Toggle"

    return @(
        [PSCustomObject]@{ Key = "Language"; Path = $toggle; Name = "Language Hotkey"; Pattern = '^[1-4]$'; Identity = $true }
        [PSCustomObject]@{ Key = "Hotkey"; Path = $toggle; Name = "Hotkey"; Pattern = '^[1-4]$'; Identity = $false }
        [PSCustomObject]@{ Key = "Layout"; Path = $toggle; Name = "Layout Hotkey"; Pattern = '^[1-4]$'; Identity = $true }
    )
}


function Read-WinForgeChoiceValues {
    # Os valores de uma escolha como estão agora (Key -> texto; $null quando não existe), para o diário.
    param ([Parameter(Mandatory)][ValidateSet("keyboard-hotkeys")][string]$Kind)

    $values = [ordered]@{}

    foreach ($spec in @(Get-WinForgeChoiceSpec -Kind $Kind)) {
        $value = Get-WinForgeRegistryValueOrNull -Path $spec.Path -Name $spec.Name
        $values[$spec.Key] = $(if ($null -eq $value) { $null } else { [string]$value })
    }

    return $values
}


function ConvertFrom-WinForgeChoiceValues {
    <#
    Os valores de uma escolha vindos do diário, conferidos pelo formato de cada um (Pattern). Só as chaves do Kind contam;
    uma ausente fica fora (Required: todas precisam estar, mesmo com $null). Devolve $null se algum valor não confere: o
    desfazer inteiro é recusado.
    #>
    param (
        [Parameter(Mandatory)][ValidateSet("keyboard-hotkeys")][string]$Kind,
        $Object,
        [switch]$Required
    )

    if ($null -eq $Object) { return $null }

    $values = [ordered]@{}

    foreach ($spec in @(Get-WinForgeChoiceSpec -Kind $Kind)) {
        $property = $Object.PSObject.Properties[$spec.Key]
        if ($Object -is [System.Collections.IDictionary]) { $property = $(if ($Object.Contains($spec.Key)) { @{ Value = $Object[$spec.Key] } } else { $null }) }

        if ($null -eq $property) {
            if ($Required) { return $null }
            continue
        }

        $value = $property.Value

        if ($null -eq $value) {
            $values[$spec.Key] = $null
            continue
        }

        if ([string]$value -notmatch $spec.Pattern) { return $null }
        $values[$spec.Key] = [string]$value
    }

    return $values
}


function Write-WinForgeChoiceValues {
    # Grava os valores dados de uma escolha (só os que vierem em Values), na ordem do Windows; $null remove o valor (ele não
    # existia antes).
    param (
        [Parameter(Mandatory)][ValidateSet("keyboard-hotkeys")][string]$Kind,
        [Parameter(Mandatory)][System.Collections.IDictionary]$Values
    )

    foreach ($spec in @(Get-WinForgeChoiceSpec -Kind $Kind)) {
        if (-not $Values.Contains($spec.Key)) { continue }

        $value = $Values[$spec.Key]

        if ($null -eq $value) { Remove-WinForgeRegistryValue -Path $spec.Path -Name $spec.Name }
        else { Set-WinForgeRegistryValue -Path $spec.Path -Name $spec.Name -Kind "String" -Value ([string]$value) }
    }
}


function Undo-WinForgeChoiceChange {
    <#
    Desfaz uma escolha anotada no Histórico de mudanças (Kind keyboard-hotkeys, com Before e After): volta o que a escolha
    gravou ao que era antes. Se a escolha de agora não é mais a que o WinForge gravou (a pessoa mudou nas Configurações,
    ou escolheu de novo), nada é gravado por cima. Devolve um WinForge.Result.
    #>
    param (
        [Parameter(Mandatory)][ValidateSet("keyboard-hotkeys")][string]$Kind,
        [Parameter(Mandatory)]$Undo
    )

    # Os valores ficam no perfil da conta: elevado com outra conta, o desfazer mudaria o perfil dela.
    if (Test-WinForgeUserContextMismatch) {
        return (New-WinForgeResult -Kind Failed -Detail (Get-WinForgeText 'o WinForge está elevado com outra conta; desfaça com a conta de quem usa o PC'))
    }

    $before = ConvertFrom-WinForgeChoiceValues -Kind $Kind -Object (Get-WinForgeJsonValue -Object $Undo -Name "Before" -Default $null) -Required
    $after = ConvertFrom-WinForgeChoiceValues -Kind $Kind -Object (Get-WinForgeJsonValue -Object $Undo -Name "After" -Default $null)

    if ($null -eq $before -or $null -eq $after -or $after.Count -eq 0) {
        return (New-WinForgeResult -Kind Failed -Detail (Get-WinForgeText 'esta mudança não tem como ser desfeita'))
    }

    $now = Read-WinForgeChoiceValues -Kind $Kind

    foreach ($spec in @(Get-WinForgeChoiceSpec -Kind $Kind | Where-Object { $_.Identity -and $after.Contains($_.Key) })) {
        if ([string]$now[$spec.Key] -cne [string]$after[$spec.Key]) {
            return (New-WinForgeResult -Kind Ok -Detail (Get-WinForgeText 'as teclas foram trocadas depois e ficaram como estão'))
        }
    }

    # Tudo volta ao que era antes, e não só o que a escolha gravou.
    Write-WinForgeChoiceValues -Kind $Kind -Values $before
    Sync-WinForgeLanguageHotkey

    return (New-WinForgeResult -Kind Ok -Detail (Get-WinForgeText 'as teclas de antes voltaram'))
}


function Get-WinForgeAccentTaskbarGaps {
    <#
    O que falta para a cor de destaque pintar o Iniciar e a barra de tarefas: o modo escuro do Windows (as Configurações só
    deixam ligar a cor ali com ele; com o modo claro, a opção fica cinza) e a própria opção. Devolve os nomes das chaves da
    Personalização que faltam, na ordem da lista; vazio quando não falta nada.
    #>
    $personalize = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
    $gaps = @()

    # Sem o valor, o Windows está no modo claro.
    $system = Get-WinForgeRegistryValueOrNull -Path $personalize -Name "SystemUsesLightTheme"
    if ($null -eq $system -or [int]$system -ne 0) {
        $gaps += [string](Get-WinForgeTweakField -Entry (Get-WinForgeTweakById -Id "dark-mode") -Name "Feature" -Default (Get-WinForgeText 'Modo escuro'))
    }

    $prevalence = Get-WinForgeRegistryValueOrNull -Path $personalize -Name "ColorPrevalence"
    if ($null -eq $prevalence -or [int]$prevalence -ne 1) {
        $gaps += [string](Get-WinForgeTweakField -Entry (Get-WinForgeTweakById -Id "accent-taskbar") -Name "Feature" -Default (Get-WinForgeText 'Cor de destaque no Iniciar e na barra de tarefas'))
    }

    return @($gaps)
}


function Get-WinForgeTweakApplyHint {
    # O que falta para um ajuste recém-aplicado aparecer na tela: a cor de destaque no Iniciar e na barra só aparece com o
    # modo escuro do Windows. Vazio quando não falta nada.
    param ([Parameter(Mandatory)]$Tweak)

    if ([string]$Tweak.Id -ne "accent-taskbar") { return "" }

    $dark = [string](Get-WinForgeTweakField -Entry (Get-WinForgeTweakById -Id "dark-mode") -Name "Feature" -Default (Get-WinForgeText 'Modo escuro'))
    if (@(Get-WinForgeAccentTaskbarGaps) -contains $dark) { return (Get-WinForgeText 'Só aparece com o {0}: ative-o também, aqui na Personalização.' "$($dark)") }

    return ""
}


function Get-WinForgeLanguageHotkeys {
    <#
    As teclas que trocam o idioma do teclado (HKCU\Keyboard Layout\Toggle, valores de texto): "Language Hotkey" troca o
    idioma, "Layout Hotkey" troca o teclado do mesmo idioma (ABNT2 e Internacional, por exemplo) e "Hotkey" é o nome
    antigo da primeira. 1 = Alt esquerdo + Shift, 2 = Ctrl + Shift, 3 = nenhuma. O Windows + Espaço troca sempre.
    #>
    return @(
        [PSCustomObject]@{ Key = "A"; Label = (Get-WinForgeText 'Alt + Shift e Ctrl + Shift'); Description = (Get-WinForgeText 'o padrão do Windows: Alt + Shift troca o idioma e Ctrl + Shift, o teclado do mesmo idioma'); Language = "1"; Layout = "2" }
        [PSCustomObject]@{ Key = "S"; Label = (Get-WinForgeText 'Só Alt + Shift'); Description = (Get-WinForgeText 'troca o idioma; o Ctrl + Shift deixa de trocar o teclado (ABNT2 e Internacional, por exemplo)'); Language = "1"; Layout = "3" }
        [PSCustomObject]@{ Key = "C"; Label = (Get-WinForgeText 'Só Ctrl + Shift'); Description = (Get-WinForgeText 'troca o idioma; o Alt + Shift deixa de trocar'); Language = "2"; Layout = "3" }
        [PSCustomObject]@{ Key = "N"; Label = (Get-WinForgeText 'Nenhuma'); Description = (Get-WinForgeText 'só o Windows + Espaço e o ícone do idioma na barra de tarefas trocam'); Language = "3"; Layout = "3" }
    )
}


function Get-WinForgeHotkeyKeysText {
    # O nome das teclas de um valor de Keyboard Layout\Toggle.
    param ([string]$Value)

    switch ($Value) {
        "1" { return (Get-WinForgeText 'Alt + Shift') }
        "2" { return (Get-WinForgeText 'Ctrl + Shift') }
        "3" { return (Get-WinForgeText 'nenhuma') }
        "4" { return (Get-WinForgeText 'acento grave (`)') }
        default { return (Get-WinForgeText 'não identificada') }
    }
}


function Get-WinForgeLanguageHotkeyState {
    # O atalho de agora: o nome da opção que bate com as duas teclas (idioma e teclado) ou, fora das opções, as duas
    # teclas por extenso. Sem os valores no registro, vale o padrão do Windows (Alt + Shift e Ctrl + Shift).
    $toggle = "HKCU:\Keyboard Layout\Toggle"
    $language = Get-WinForgeRegistryValueOrNull -Path $toggle -Name "Language Hotkey"
    if ($null -eq $language) { $language = Get-WinForgeRegistryValueOrNull -Path $toggle -Name "Hotkey" }
    if ($null -eq $language) { $language = "1" }
    $layout = Get-WinForgeRegistryValueOrNull -Path $toggle -Name "Layout Hotkey"
    if ($null -eq $layout) { $layout = "2" }

    $known = @(Get-WinForgeLanguageHotkeys | Where-Object { $_.Language -eq [string]$language -and $_.Layout -eq [string]$layout }) | Select-Object -First 1
    if ($null -ne $known) { return [string]$known.Label }

    return (Get-WinForgeText 'idioma: {0}; teclado: {1}' "$(Get-WinForgeHotkeyKeysText -Value ([string]$language))" "$(Get-WinForgeHotkeyKeysText -Value ([string]$layout))")
}


function Get-WinForgeTweakActionState {
    <#
    O que a linha de uma ação da página mostra embaixo do nome, como as chaves mostram o estado: as teclas que trocam o
    idioma de agora ("Agora: Alt + Shift e Ctrl + Shift"). Vazio para as outras ações e quando não deu para ler.
    #>
    param ([Parameter(Mandatory)][string]$Id)

    # Lê o perfil do usuário: elevado com outra conta, seria o dessa conta.
    if ([bool](Get-WinForgeTweakField -Entry (Get-WinForgeSessionInfo) -Name "UserMismatch" -Default $false)) { return "" }

    $state = switch ($Id) {
        "tweaks.keyboard-language" { Get-WinForgeLanguageHotkeyState }
        default { "" }
    }

    if ([string]::IsNullOrWhiteSpace([string]$state)) { return "" }
    return (Get-WinForgeText 'Agora: {0}' "$state")
}


function Get-WinForgeTweaksPageStatus {
    <#
    O resumo no alto das páginas de ajustes (Ajustes do Windows e Personalização), como o das outras páginas
    (New-GuiPageStatus), feito da lista que a página acabou de ler (Overview, de Get-WinForgeTweakOverview): em Ajustes do
    Windows, quantos recomendados estão em uso (a linha leva a Aplicar ajustes recomendados enquanto falta algum); nas
    duas, quantos ajustes da página o WinForge mudou e continuam como ele deixou (a linha leva ao Histórico de mudanças,
    onde cada um se desfaz). Elevado com outra conta, só uma linha, que diz que os do perfil do usuário ficam de fora: o
    perfil e o backup lidos seriam os dessa conta. Cada linha tem Label, Text, Level (Normal | Warn | Muted) e Opens.
    #>
    param (
        [Parameter(Mandatory)][string]$Page,
        [AllowEmptyCollection()][object[]]$Overview = @()
    )

    $session = Get-WinForgeSessionInfo

    if ([bool](Get-WinForgeTweakField -Entry $session -Name "UserMismatch" -Default $false)) {
        $user = [string](Get-WinForgeTweakField -Entry $session -Name "User" -Default "")
        return @([PSCustomObject]@{ Label = (Get-WinForgeText 'Outra conta'); Text = (Get-WinForgeText '{0}: os ajustes do perfil do usuário ficam de fora' "$user"); Level = "Warn"; Opens = "" })
    }

    $rows = @()

    if ($Page -eq "tweaks") {
        # O estado que a página leu; o recomendado de outra página (a Personalização) é lido aqui.
        $read = @{}
        foreach ($item in @($Overview)) { $read[[string]$item.Id] = [string]$item.Status }

        $recommended = @(Get-WinForgeTweakCatalog | Where-Object { $_.Recommended -and (Test-WinForgeTweakAvailable -Tweak $_) })
        $inUse = @($recommended | Where-Object { $(if ($read.ContainsKey([string]$_.Id)) { $read[[string]$_.Id] } else { Get-WinForgeTweakStatus -Tweak $_ }) -eq "Aplicado" }).Count

        if ($recommended.Count -gt 0) {
            $all = ($inUse -ge $recommended.Count)
            $rows += [PSCustomObject]@{
                Label = (Get-WinForgeText 'Recomendados')
                Text  = $(if ($all) { (Get-WinForgeText 'todos em uso') } else { (Get-WinForgeText '{0} de {1} em uso' "$inUse" "$($recommended.Count)") })
                Level = "Normal"
                Opens = $(if ($all) { "" } else { "tweaks.recommended" })
            }
        }
    }

    $saved = @(Get-WinForgeTweakBackupIds)
    $changed = @(@($Overview) | Where-Object { $_.Status -eq "Aplicado" -and $saved -contains [string]$_.Id }).Count

    $rows += [PSCustomObject]@{
        Label = (Get-WinForgeText 'Mudanças')
        Text  = $(if ($changed -gt 0) { (Format-WinForgeCount -Count $changed -One (Get-WinForgeText 'ajuste desta página mudado pelo WinForge') -Many (Get-WinForgeText 'ajustes desta página mudados pelo WinForge')) } else { (Get-WinForgeText 'nenhum ajuste desta página mudado pelo WinForge') })
        Level = $(if ($changed -gt 0) { "Normal" } else { "Muted" })
        Opens = $(if ($changed -gt 0) { "maintenance.changes" } else { "" })
    }

    return $rows
}


function Test-WinForgeTweakOtherAccount {
    # Elevado com outra conta, o HKCU é o dessa conta: uma opção do perfil do usuário mudaria o perfil errado. Avisa e
    # devolve $true (quem chama para ali).
    $session = Get-WinForgeSessionInfo
    if (-not [bool](Get-WinForgeTweakField -Entry $session -Name "UserMismatch" -Default $false)) { return $false }

    $user = [string](Get-WinForgeTweakField -Entry $session -Name "User" -Default "")
    Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'O WinForge está elevado com outra conta ({0}): esta opção vale para o perfil do usuário e mudaria o perfil dessa conta, não o seu. Para usá-la, abra o WinForge sem trocar de conta no pedido de Administrador.' "$user")
    return $true
}


function Set-WinForgeKeyboardLanguageHotkey {
    # Ajustes do Windows > Teclas que trocam o idioma do teclado: as teclas que trocam o idioma e o teclado.
    $title = (Get-WinForgeText 'Teclas que trocam o idioma do teclado')
    Enter-WinForgeAction -Title $title

    if (Test-WinForgeTweakOtherAccount) {
        Exit-WinForgeAction -Result (New-WinForgeResult -Kind Failed -Detail (Get-WinForgeText 'vale para o perfil do usuário, e o WinForge está elevado com outra conta') -Title $title)
        return
    }

    $final = New-WinForgeResult -Kind Ok -Title $title

    try {
        Write-WinForgeKeyValue -Label (Get-WinForgeText 'Teclas de agora') -Value (Get-WinForgeLanguageHotkeyState)
        Write-WinForgeStatus -Type Info -Notice -Message (Get-WinForgeText 'As teclas só fazem algo com mais de um idioma ou teclado instalado; o Windows + Espaço troca sempre.')

        $hotkeys = @(Get-WinForgeLanguageHotkeys)
        $options = @(foreach ($entry in $hotkeys) { @{ Key = $entry.Key; Label = $entry.Label; Description = $entry.Description } })
        $options += @{ Key = "X"; Label = (Get-WinForgeText 'Cancelar'); Exit = $true }

        $answer = Read-WinForgeChoice -Message (Get-WinForgeText 'Quais teclas trocam o idioma do teclado?') -Options $options -DefaultKey "X" -ShowMenu `
            -TextPrompt (Get-WinForgeText 'Opção (A, S, C, N ou X; ENTER = cancelar)')
        $chosen = @($hotkeys | Where-Object { $_.Key -ieq $answer }) | Select-Object -First 1

        if ($null -eq $chosen) {
            Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'Operação cancelada.')
            $final = New-WinForgeResult -Kind Skipped -Detail (Get-WinForgeText 'cancelado pelo usuário') -Title $title
        }
        else {
            $before = Read-WinForgeChoiceValues -Kind "keyboard-hotkeys"
            $after = [ordered]@{ Language = [string]$chosen.Language; Hotkey = [string]$chosen.Language; Layout = [string]$chosen.Layout }
            Write-WinForgeChoiceValues -Kind "keyboard-hotkeys" -Values $after
            Sync-WinForgeLanguageHotkey

            Write-WinForgeStatus -Type Success -Message (Get-WinForgeText 'Teclas que trocam o idioma do teclado: {0}.' "$($chosen.Label)")
            Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Se não mudar em algum programa já aberto, ele passa a valer quando você sair e entrar de novo no Windows.')
            $final = New-WinForgeResult -Kind Ok -Detail (Get-WinForgeText 'teclas que trocam o idioma: {0}' "$($chosen.Label)") -Title $title
            [void](Add-WinForgeChange -Action $title -Text ([string]$chosen.Label) -Undo @{ Kind = "keyboard-hotkeys"; Before = $before; After = $after })

            # Na janela, o título diz a escolha ("Nenhuma", sozinho, não diria nada); a frase, o que ela faz.
            $what = [string]$chosen.Description
            [void](Set-WinForgeResultView -Result $final -Headline $(if ($chosen.Language -eq "3") { (Get-WinForgeText 'Nenhuma tecla troca o idioma') } else { [string]$chosen.Label }) `
                    -Note "$($what.Substring(0, 1).ToUpperInvariant())$($what.Substring(1)).")
        }
    }
    catch {
        Write-WinForgeStatus -Type Error -Message (Get-WinForgeText 'Não foi possível trocar as teclas: {0}' "$($_.Exception.Message)")
        $final = New-WinForgeResult -Kind Failed -Detail $_.Exception.Message -Title $title
    }

    Exit-WinForgeAction -Result $final
}


Export-ModuleMember -Function *
