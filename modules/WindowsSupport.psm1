# Suporte do Windows: até quando esta versão recebe atualizações de segurança e, no Windows 10, se o PC pode ir para o
# Windows 11.
#
# As datas vêm do catálogo (Catalog.psm1): a cópia embutida, ou a baixada quando for mais nova. A versão é a build do
# Windows; a data depende da edição (Home e Pro têm menos tempo que Enterprise e Education; LTSC tem o próprio prazo).


# ---------------------------------------------------------------------------
# Ciclo de vida
# ---------------------------------------------------------------------------

function Get-WinForgeWindowsEditionId {
    # O EditionID do registro ("Core", "Professional", "Enterprise", "EnterpriseS"...); "" sem leitura.
    $value = Get-WinForgeRegistryValueOrNull -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name "EditionID"

    return $(if ($null -eq $value) { "" } else { [string]$value })
}


function Get-WinForgeWindowsEditionClass {
    # Qual prazo vale para a edição: Consumer (Home, Pro e variantes), Enterprise (Enterprise e Education) ou Ltsc. É a
    # única regra do WinForge (a tela Suporte do Windows, o Início e a auditoria de segurança usam esta). Sem a edição
    # (""), vale Consumer: o prazo mais curto, para nunca prometer a um Windows Home a data do Enterprise.
    param (
        [AllowEmptyString()][string]$EditionId
    )

    if ($EditionId -match '^(IoT)?EnterpriseS') { return "Ltsc" }
    if ($EditionId -match '^(Enterprise|Education|IoTEnterprise|ServerRdsh)') { return "Enterprise" }

    return "Consumer"
}


function Get-WinForgeWindowsRevision {
    # A revisão da build instalada (UBR: o "6575" de 19045.6575), que sobe a cada atualização mensal; $null sem leitura.
    $value = Get-WinForgeRegistryValueOrNull -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name "UBR"
    $parsed = 0

    if ($null -ne $value -and [int]::TryParse(([string]$value).Trim(), [ref]$parsed) -and $parsed -ge 0) {
        return $parsed
    }

    return $null
}


function Get-WinForgeLastUpdateDate {
    # A data da atualização mais recente instalada (Win32_QuickFixEngineering); $null sem leitura.
    try {
        $dates = @(
            foreach ($fix in @(Get-CimInstance -ClassName Win32_QuickFixEngineering -ErrorAction Stop)) {
                $installed = Get-WinForgeJsonValue -Object $fix -Name "InstalledOn" -Default $null

                if ($installed -is [datetime]) {
                    $installed
                }
                elseif ($null -ne $installed) {
                    $parsed = [datetime]::MinValue
                    if ([datetime]::TryParse([string]$installed, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$parsed)) { $parsed }
                }
            }
        )
    }
    catch {
        return $null
    }

    if ($dates.Count -eq 0) { return $null }

    return ($dates | Sort-Object -Descending | Select-Object -First 1)
}


function Get-WinForgeSupportDaysText {
    # "daqui a 12 dias"; no último dia, "hoje" ("daqui a 0 dias" não se diz).
    param ([int]$Days)

    if ($Days -le 0) { return "hoje" }

    return "daqui a $(Format-WinForgeCount -Count $Days -One 'dia' -Many 'dias')"
}


function Get-WinForgeEsuText {
    # "atualizações estendidas (ESU) até 12/10/2027"; o ESU de empresas e escolas (pago pela organização, renovado a cada
    # ano) não tem uma data que o WinForge conheça.
    param ([Parameter(Mandatory)]$Status)

    $end = Get-WinForgeJsonValue -Object $Status -Name "EsuEnd" -Default $null

    if ($end -is [datetime]) { return "atualizações estendidas (ESU) até $(Format-WinForgeDateTime -When $end -Pattern 'dd/MM/yyyy')" }

    return "atualizações estendidas (ESU) da organização"
}


function ConvertFrom-WinForgeCatalogDateText {
    param ([Parameter(Mandatory)][string]$Text)

    return [datetime]::ParseExact($Text, "yyyy-MM-dd", [System.Globalization.CultureInfo]::InvariantCulture)
}


function Get-WinForgeWindowsSupportStatus {
    <#
    Até quando esta versão do Windows recebe atualizações de segurança. State: Supported, EndingSoon (90 dias ou menos),
    Esu (o Windows 10 já sem suporte, mas com uma atualização que só sai para o programa ESU instalada), EsuAvailable
    (sem suporte e sem atualização do ESU instalada, mas ainda dá para entrar), Ended ou Unknown (Windows 11 ou mais novo
    fora da lista, ou Windows Server). Level: Ok, Warn, Bad ou Normal. Text diz a situação; Advice, o que fazer.
    EsuChecked diz se deu para conferir o ESU (revisão da build lida e catálogo com a primeira revisão só do ESU).
    #>
    param (
        [int]$Build = (Get-WinForgeWindowsBuild),
        [AllowEmptyString()][string]$EditionId = (Get-WinForgeWindowsEditionId),

        # A revisão da build (UBR). Sem o parâmetro, é lida do Registro só quando decide algo (Windows 10 no período do
        # ESU); $null ou negativo = não foi possível ler.
        $Revision = $null,

        [datetime]$Today = (Get-Date).Date,
        $Catalog = (Get-WinForgeCatalog)
    )

    $class = Get-WinForgeWindowsEditionClass -EditionId $EditionId
    $entries = @($Catalog.WindowsLifecycle)

    # O Windows Server divide a build com o Windows de mesa (o Server 2025 é a 26100, a mesma do Windows 11 24H2) e tem
    # prazos próprios, que a lista não cobre: sem isto, um Server 2025 levaria a data do Windows 11 Home. "ServerRdsh" é
    # o Windows 10/11 Enterprise multissessão, que segue as datas do Enterprise.
    $isServer = ($EditionId -match '^Server' -and $EditionId -notmatch '^ServerRdsh')
    $entry = $(if ($isServer) { $null } else { @($entries | Where-Object { [int]$_.Build -eq $Build }) | Select-Object -First 1 })
    $isWindows11 = ($Build -ge 22000)
    $update22H2 = "Atualize para o Windows 10 22H2 em Atualizações > Windows Update (é grátis): é a versão que ainda pode receber as atualizações estendidas (ESU). Se o PC for compatível, o melhor é o Windows 11."

    $status = [ordered]@{
        Build      = $Build
        Revision   = $null
        Product    = ""
        Class      = $class
        IsServer   = $isServer
        EndDate    = $null
        EsuEnd     = $null
        EsuChecked = $false
        DaysLeft   = 0
        State      = "Unknown"
        Level      = "Normal"
        Text       = ""
        Advice     = ""
    }

    if ($null -eq $entry) {
        # Todas as versões do Windows 10 que ainda recebem atualizações estão na lista: uma build abaixo da do Windows 11
        # que não está nela (1909, 2004, 20H2, 21H1, 1703...) já saiu de suporte. O Windows Server fica sem data.
        if ($Build -gt 0 -and $Build -lt 22000 -and -not $isServer) {
            $status.Product = $(if ($Build -ge 10240) { "Windows 10 (build $Build)" } else { "Windows (build $Build)" })
            $status.State = "Ended"
            $status.Level = "Bad"
            $status.Text = "Esta versão do Windows não recebe mais atualizações de segurança."
            $status.Advice = $(if ($Build -ge 10240) { $update22H2 } else { "Instale uma versão atual do Windows." })
        }
        elseif ($isServer) {
            $status.Product = $(if ($Build -gt 0) { "Windows Server (build $Build)" } else { "Windows Server" })
            $status.Text = "O WinForge não tem as datas do Windows Server."
            $status.Advice = "Confira o prazo desta versão na página de ciclo de vida da Microsoft."
        }
        else {
            $status.Product = $(if ($Build -gt 0) { "Windows (build $Build)" } else { "Windows" })
            $status.Text = "Esta versão não está na lista de datas do WinForge."
            $status.Advice = "Use Sobre o WinForge > Conferir dados online para conferir."
        }

        return [PSCustomObject]$status
    }

    $status.Product = [string]$entry.Name
    # As edições IoT Enterprise LTSC têm prazo mais longo que o LTSC comum em algumas versões (21H2: 2032 contra 2027).
    $iotEnd = [string](Get-WinForgeJsonValue -Object $entry -Name "IotLtscEnd" -Default "")
    $endText = switch ($class) {
        "Ltsc" { $(if ($EditionId -match '^IoT' -and $iotEnd) { $iotEnd } elseif ($entry.LtscEnd) { $entry.LtscEnd } else { $entry.EnterpriseEnd }) }
        "Enterprise" { $entry.EnterpriseEnd }
        default { $entry.HomeEnd }
    }

    $end = ConvertFrom-WinForgeCatalogDateText -Text ([string]$endText)
    $status.EndDate = $end
    $endShown = Format-WinForgeDateTime -When $end -Pattern "dd/MM/yyyy"
    $upgradeAdvice = "Atualize para a versão mais nova do Windows 11 em Atualizações > Windows Update: é grátis e mantém seus arquivos e programas."

    if ($Today -le $end) {
        $status.DaysLeft = [int]($end - $Today).TotalDays

        if ($status.DaysLeft -le 90) {
            $status.State = "EndingSoon"
            $status.Level = "Warn"
            $status.Text = $(
                if ($status.DaysLeft -le 0) { "As atualizações de segurança desta versão terminam hoje ($endShown)." }
                else { "As atualizações de segurança desta versão acabam em $endShown ($(Get-WinForgeSupportDaysText -Days $status.DaysLeft))." }
            )
            $status.Advice = $(if ($isWindows11) { "$upgradeAdvice Faça isso antes da data." } else { "Planeje a troca de versão antes da data." })
        }
        else {
            $status.State = "Supported"
            $status.Level = "Ok"
            $status.Text = "Recebe atualizações de segurança até $endShown."
        }

        return [PSCustomObject]$status
    }

    $esuText = $(if ($class -eq "Consumer") { [string]$entry.EsuEnd } else { "" })

    if ($esuText) {
        $esuEnd = ConvertFrom-WinForgeCatalogDateText -Text $esuText
        $status.EsuEnd = $esuEnd

        if ($Today -le $esuEnd) {
            $esuShown = Format-WinForgeDateTime -When $esuEnd -Pattern "dd/MM/yyyy"

            # Quem está no ESU recebe atualizações que os outros PCs não recebem: a build instalada (19045.6575 ou mais
            # nova) prova a inscrição. A data da última instalação não prova: o PC fora do programa também instalou a
            # última atualização gratuita depois do fim do suporte.
            if (-not $PSBoundParameters.ContainsKey("Revision")) { $Revision = Get-WinForgeWindowsRevision }

            $firstEsu = [int](Get-WinForgeJsonValue -Object $entry -Name "EsuFirstRevision" -Default 0)
            $status.Revision = $Revision
            $status.EsuChecked = ($firstEsu -gt 0 -and $null -ne $Revision -and [int]$Revision -ge 0)

            if ($status.EsuChecked -and [int]$Revision -ge $firstEsu) {
                $status.State = "Esu"
                $status.Level = "Warn"
                $status.DaysLeft = [int]($esuEnd - $Today).TotalDays
                $status.Text = "Recebe as atualizações de segurança estendidas (ESU) até ${esuShown}: o suporte normal acabou em $endShown."
                $status.Advice = "O ESU é temporário. Se o PC for compatível, a saída definitiva é o Windows 11."
            }
            else {
                $status.State = "EsuAvailable"
                $status.Level = $(if ($status.EsuChecked) { "Bad" } else { "Warn" })
                $status.Text = $(
                    if ($status.EsuChecked) { "Não recebe mais atualizações de segurança gratuitas desde $endShown, e nenhuma atualização do programa ESU foi instalada." }
                    else { "Não recebe mais atualizações de segurança gratuitas desde $endShown. Não foi possível conferir se este PC recebe as atualizações estendidas (ESU)." }
                )
                $status.Advice = "Dá para receber as de segurança até $esuShown pelo programa ESU: inscreva-se em Configurações, Windows Update (atalho: Atualizações > Windows Update); se o PC já está inscrito, instale as atualizações pendentes por lá. Se o PC for compatível, a saída definitiva é o Windows 11."
            }

            return [PSCustomObject]$status
        }
    }

    # O ESU de empresas e escolas (Enterprise e Education) é pago por ano, até o fim que a lista dá (EsuOrgEnd); a build
    # instalada mostra quem está nele, como no ESU do consumidor. Só para essas edições e só até essa data: depois dela,
    # uma build do ESU instalada não quer dizer que ainda chegam atualizações. (Home e Pro já passaram pelo ESU do
    # consumidor acima; depois do fim dele, estão sem suporte.)
    $firstEsu = [int](Get-WinForgeJsonValue -Object $entry -Name "EsuFirstRevision" -Default 0)
    $orgEndText = [string](Get-WinForgeJsonValue -Object $entry -Name "EsuOrgEnd" -Default "")
    $orgEnd = $(if ($orgEndText) { ConvertFrom-WinForgeCatalogDateText -Text $orgEndText } else { $null })

    if ($firstEsu -gt 0 -and $class -eq "Enterprise" -and $null -ne $orgEnd -and $Today -le $orgEnd) {
        if (-not $PSBoundParameters.ContainsKey("Revision")) { $Revision = Get-WinForgeWindowsRevision }

        $status.Revision = $Revision
        $status.EsuChecked = ($null -ne $Revision -and [int]$Revision -ge 0)

        if ($status.EsuChecked -and [int]$Revision -ge $firstEsu) {
            $status.State = "Esu"
            $status.Level = "Warn"
            $status.Text = "Recebe as atualizações de segurança estendidas (ESU) contratadas pela organização: o suporte normal acabou em $endShown."
            $status.Advice = "O ESU de empresas e escolas é renovado a cada ano. Se o PC for compatível, a saída definitiva é o Windows 11."

            return [PSCustomObject]$status
        }
    }

    $status.State = "Ended"
    $status.Level = "Bad"
    $status.Text = "Não recebe mais atualizações de segurança desde $endShown."
    $status.Advice = $(
        if ($class -eq "Ltsc") { "Esta edição de longo prazo (LTSC) precisa ser trocada por uma versão com suporte; fale com quem administra o PC." }
        elseif ($isWindows11) { $upgradeAdvice }
        elseif ($firstEsu -gt 0 -and $class -eq "Enterprise" -and $null -ne $orgEnd -and $Today -le $orgEnd) { "Empresas e escolas podem contratar as atualizações estendidas (ESU) para este PC; fale com quem administra o PC. Se ele for compatível, a saída definitiva é o Windows 11." }
        elseif ($Build -lt 19045) { $update22H2 }
        else { "Se o PC for compatível, atualize para o Windows 11 em Atualizações > Windows Update." }
    )

    return [PSCustomObject]$status
}


function Get-WinForgeWindowsSupportIssue {
    # O ponto de atenção da nota de saúde para o suporte do Windows: grave sem atualizações de segurança, leve quando
    # elas acabam em breve ou vêm do ESU; $null quando está tudo em dia ou a versão não está na lista.
    param (
        [Parameter(Mandatory)]$Status
    )

    switch ([string]$Status.State) {
        "EsuAvailable" {
            # Sem conseguir conferir o ESU (revisão da build não lida), não afirma que o PC está sem atualizações.
            if (-not [bool](Get-WinForgeJsonValue -Object $Status -Name "EsuChecked" -Default $true)) {
                return (New-WinForgeHealthIssue -Id "windows-support" -Text "Não foi possível conferir se o $($Status.Product) ainda recebe atualizações de segurança" -Weight 10 -Target "diagnostics.windows-support" -ButtonText "Ver opções")
            }

            return (New-WinForgeHealthIssue -Id "windows-support" -Text "O $($Status.Product) não recebe mais atualizações de segurança" -Weight 20 -Target "diagnostics.windows-support" -ButtonText "Ver como resolver")
        }
        "Ended" {
            return (New-WinForgeHealthIssue -Id "windows-support" -Text "O $($Status.Product) não recebe mais atualizações de segurança" -Weight 20 -Target "diagnostics.windows-support" -ButtonText "Ver como resolver")
        }
        "EndingSoon" {
            $when = $(if ([int]$Status.DaysLeft -le 0) { "terminam hoje" } else { "acabam em $(Format-WinForgeCount -Count $Status.DaysLeft -One 'dia' -Many 'dias')" })
            return (New-WinForgeHealthIssue -Id "windows-support" -Text "As atualizações de segurança do $($Status.Product) $when" -Weight 8 -Target "diagnostics.windows-support" -ButtonText "Ver como resolver")
        }
        "Esu" {
            $text = $(if ($Status.EsuEnd -is [datetime]) { "O Windows 10 está nas atualizações estendidas (ESU), que acabam em $(Format-WinForgeDateTime -When $Status.EsuEnd -Pattern 'dd/MM/yyyy')" } else { "O Windows 10 está nas atualizações estendidas (ESU) da organização" })
            return (New-WinForgeHealthIssue -Id "windows-support" -Text $text -Weight 5 -Target "diagnostics.windows-support" -ButtonText "Ver opções")
        }
    }

    return $null
}


# ---------------------------------------------------------------------------
# Requisitos do Windows 11
# ---------------------------------------------------------------------------

# Quantos dias depois da atualização mensal registrada no catálogo um PC sem ela conta como atrasado: 35 dias é o máximo
# que o Windows Update deixa pausar nas edições Home e Pro. Um PC que atualiza normalmente instala a de cada mês em dias.
$script:WinForgeUpdateLagDays = 35


function Get-WinForgeWindowsUpdateLag {
    <#
    Se este Windows está parado numa atualização mensal antiga. O catálogo guarda, para cada versão, a revisão da build
    (o "7807" de 19045.7807) da atualização de segurança de um mês antes da data dele (UpdateRevision) e o dia em que ela
    saiu (UpdateDate). Devolve $true quando a revisão instalada é menor que essa e já passaram 35 dias desde então (o
    PC está sem pelo menos dois meses de correções); $false quando ela está lá (ou ainda no prazo); $null quando não dá
    para saber: Windows Server (outra linha de revisões), versão fora do catálogo, catálogo sem o dado (o guardado por
    uma versão anterior do WinForge) ou revisão não lida. Com o catálogo antigo, a conta só fica menos exigente; ela
    nunca acusa um PC em dia. As atualizações sem reinício (hotpatch) do Windows 11 24H2 Enterprise têm revisão menor
    que a atualização do mesmo mês, mas sempre maior que a do mês anterior, que é a que o catálogo guarda.
    #>
    param (
        [int]$Build = (Get-WinForgeWindowsBuild),
        [AllowEmptyString()][string]$EditionId = (Get-WinForgeWindowsEditionId),
        $Revision = $null,
        [datetime]$Today = (Get-Date).Date,
        $Catalog = (Get-WinForgeCatalog)
    )

    if ($Build -le 0 -or ($EditionId -match '^Server' -and $EditionId -notmatch '^ServerRdsh')) { return $null }

    $entry = @(@(Get-WinForgeJsonValue -Object $Catalog -Name "WindowsLifecycle" -Default @()) | Where-Object { [int]$_.Build -eq $Build }) | Select-Object -First 1
    if ($null -eq $entry) { return $null }

    $expected = [int](Get-WinForgeJsonValue -Object $entry -Name "UpdateRevision" -Default 0)
    $dateText = [string](Get-WinForgeJsonValue -Object $entry -Name "UpdateDate" -Default "")
    if ($expected -le 0 -or [string]::IsNullOrWhiteSpace($dateText)) { return $null }

    try {
        $released = ConvertFrom-WinForgeCatalogDateText -Text $dateText
    }
    catch {
        return $null
    }

    if ($null -eq $Revision) { $Revision = Get-WinForgeWindowsRevision }
    if ($null -eq $Revision -or [int]$Revision -lt 0) { return $null }

    if ([int]$Revision -ge $expected) { return $false }

    return ($Today -ge $released.Date.AddDays($script:WinForgeUpdateLagDays))
}


function Get-WinForgeWindows11CpuSupport {
    <#
    Se o processador está entre os aceitos pelo Windows 11, pelo nome: Intel Core da 8ª geração em diante, Core Ultra e
    Core 3/5/7 sem "i", AMD Ryzen da série 3000 em diante (e os Ryzen 2000 de mesa), Ryzen AI e Snapdragon. A 7ª geração
    da Intel tem exceções na lista; ela e os outros (Celeron, Pentium, Xeon, Ryzen 2000 móveis...) ficam como "não dá para
    saber pelo nome": a lista completa da Microsoft decide.
    #>
    param (
        [AllowEmptyString()][string]$Name
    )

    $text = ([string]$Name) -replace '\s+', ' '

    if ($text -match 'Core\(TM\) Ultra|Core Ultra|Ryzen AI|Core\(TM\) [3579] [0-9]{3}') { return "Ok" }

    # A primeira geração (2008 a 2010) tem três dígitos: "Core(TM) i7 CPU 920", "i5 CPU M 520", "i3-530".
    if ($text -match 'Core(\(TM\))? i[3579](-| CPU (?:[A-Z] )?)[0-9]{3}(?![0-9])') { return "Bad" }

    if ($text -match 'Core(\(TM\))? i[3579]-([0-9]{4,5})') {
        # i7-8550U (8ª), i7-1255U (12ª, quatro dígitos começando por 1), i7-12700K (12ª, cinco dígitos).
        $digits = $Matches[2]
        $generation = $(if ($digits.Length -eq 5 -or $digits.StartsWith("1")) { [int]$digits.Substring(0, 2) } else { [int]$digits.Substring(0, 1) })

        if ($generation -ge 8) { return "Ok" }
        if ($generation -eq 7) { return "Unknown" }

        return "Bad"
    }

    if ($text -match 'Ryzen (Threadripper )?[0-9]? ?(PRO )?([0-9])([0-9]{3})([A-Z]*)') {
        $series = [int]$Matches[3]
        $suffix = [string]$Matches[5]

        if ($series -ge 3) { return "Ok" }
        if ($series -eq 2 -and $suffix -notmatch '^(U|H|G|GE)') { return "Ok" }
        if ($series -eq 1) { return "Bad" }

        return "Unknown"
    }

    # O Snapdragon 835 (o primeiro do Windows em ARM) ficou fora da lista; os outros entraram.
    if ($text -match 'Snapdragon') { return $(if ($text -match 'Snapdragon(\s*\(TM\))?\s*835') { "Bad" } else { "Ok" }) }

    return "Unknown"
}


function Get-WinForgeTpmVersion {
    # A versão do TPM ("2.0", "1.2"), "" quando o PC não tem TPM e $null quando não foi possível ler. Sem Administrador o
    # Windows sempre nega a consulta; e qualquer erro dela fica como "não foi possível ler": o texto do erro muda com o
    # idioma do Windows, e tratá-lo como "sem TPM" diria que o PC não atende ao Windows 11 sem ter olhado.
    if (-not (Test-WinForgeAdministrator)) { return $null }

    try {
        $tpm = @(Get-CimInstance -Namespace "root/cimv2/Security/MicrosoftTpm" -ClassName Win32_Tpm -ErrorAction Stop) | Select-Object -First 1
    }
    catch {
        return $null
    }

    if ($null -eq $tpm) { return "" }

    $spec = [string](Get-WinForgeJsonValue -Object $tpm -Name "SpecVersion" -Default "")

    return ($spec -split ',')[0].Trim()
}


function Get-WinForgeWindows11Readiness {
    <#
    Confere os requisitos do Windows 11 com os dados dados (os padrões leem o PC). Devolve Checks (Name, State Ok/Bad/
    Unknown, Value) e State: Ok (atende a tudo), Bad (algo não atende) ou Unknown (nada falhou, mas algo não pôde ser
    conferido).
    #>
    param (
        $TpmVersion = (Get-WinForgeTpmVersion),
        [string]$SecureBootText = (Get-WinForgeSecureBootText),
        [double]$MemoryBytes = -1,
        [double]$DiskBytes = -1,
        [string]$CpuName = "",
        [int]$CpuCores = -1,
        [bool]$Is64Bit = [Environment]::Is64BitOperatingSystem
    )

    # A memória instalada (a soma dos módulos), como no script de requisitos da Microsoft: TotalPhysicalMemory desconta
    # o que o vídeo integrado e o firmware reservam, e um PC de 4 GB aparecia com 3,8. Sem os módulos (máquina virtual),
    # vale o total que o Windows vê, com essa folga.
    $memoryMinimum = 4GB

    if ($MemoryBytes -lt 0) {
        $modules = @(Get-WinForgeCimOrNull -ClassName Win32_PhysicalMemory)
        $installed = [double]0

        foreach ($module in $modules) { $installed += [double](Get-WinForgeJsonValue -Object $module -Name "Capacity" -Default 0) }

        if ($installed -gt 0) {
            $MemoryBytes = $installed
        }
        else {
            $system = @(Get-WinForgeCimOrNull -ClassName Win32_ComputerSystem) | Select-Object -First 1
            $MemoryBytes = [double](Get-WinForgeJsonValue -Object $system -Name "TotalPhysicalMemory" -Default 0)
            $memoryMinimum = 3.8GB
        }
    }

    if ($DiskBytes -lt 0) {
        $space = Get-WinForgeSystemDriveSpace
        $DiskBytes = [double](Get-WinForgeJsonValue -Object $space -Name "TotalBytes" -Default 0)
    }

    if ([string]::IsNullOrWhiteSpace($CpuName) -or $CpuCores -lt 0) {
        $cpu = @(Get-WinForgeCimOrNull -ClassName Win32_Processor) | Select-Object -First 1
        if ([string]::IsNullOrWhiteSpace($CpuName)) { $CpuName = [string](Get-WinForgeJsonValue -Object $cpu -Name "Name" -Default "") }
        if ($CpuCores -lt 0) { $CpuCores = [int](Get-WinForgeJsonValue -Object $cpu -Name "NumberOfCores" -Default 0) }
    }

    $checks = @()

    $tpmState = $(if ($null -eq $TpmVersion) { "Unknown" } elseif ([string]$TpmVersion -match '^2') { "Ok" } else { "Bad" })
    $tpmValue = $(if ($null -eq $TpmVersion) { $(if (Test-WinForgeAdministrator) { "não foi possível ler" } else { "não verificado (requer Administrador)" }) } elseif ([string]::IsNullOrWhiteSpace([string]$TpmVersion)) { "não encontrado ou desligado no firmware" } else { "TPM $TpmVersion" })
    $checks += [PSCustomObject]@{ Name = "TPM 2.0"; State = $tpmState; Value = $tpmValue }

    $uefiState = $(if ($SecureBootText -match '^(Ativado|Desativado)$') { "Ok" } elseif ($SecureBootText -match 'BIOS legado') { "Bad" } else { "Unknown" })
    $uefiValue = $(
        if ($SecureBootText -eq "Desativado") { "UEFI, Secure Boot desligado (dá para ligar no firmware)" }
        elseif ($SecureBootText -eq "Ativado") { "UEFI, Secure Boot ligado" }
        # O modo de inicialização, e não o que a placa suporta: muitos PCs com BIOS legado (CSM) têm UEFI, e o disco pode
        # ser convertido (MBR2GPT) sem reinstalar o Windows.
        elseif ($SecureBootText -match 'BIOS legado') { "o Windows iniciou no modo antigo (BIOS legado); trocar para UEFI exige preparar o disco antes, trabalho para um técnico" }
        else { $SecureBootText }
    )
    $checks += [PSCustomObject]@{ Name = "UEFI e Secure Boot"; State = $uefiState; Value = $uefiValue }

    $memoryState = $(if ($MemoryBytes -le 0) { "Unknown" } elseif ($MemoryBytes -ge $memoryMinimum) { "Ok" } else { "Bad" })
    $checks += [PSCustomObject]@{ Name = "Memória (4 GB)"; State = $memoryState; Value = $(if ($MemoryBytes -gt 0) { Format-WinForgeBytes -Bytes $MemoryBytes } else { "não lida" }) }

    # 64 GB, contados como no script de requisitos da Microsoft (HardwareReadiness.ps1): o tamanho da unidade do
    # Windows dividido por 1 GB e arredondado para inteiro.
    $diskState = $(if ($DiskBytes -le 0) { "Unknown" } elseif ([int]($DiskBytes / 1GB) -ge 64) { "Ok" } else { "Bad" })
    $checks += [PSCustomObject]@{ Name = "Disco do sistema (64 GB)"; State = $diskState; Value = $(if ($DiskBytes -gt 0) { Format-WinForgeBytes -Bytes $DiskBytes } else { "não lido" }) }

    $cpuState = Get-WinForgeWindows11CpuSupport -Name $CpuName
    if ($CpuCores -gt 0 -and $CpuCores -lt 2) { $cpuState = "Bad" }
    $cpuValue = $(if ([string]::IsNullOrWhiteSpace($CpuName)) { "não lido" } elseif ($cpuState -eq "Unknown") { "$($CpuName.Trim()) (confira na lista da Microsoft)" } else { $CpuName.Trim() })
    $checks += [PSCustomObject]@{ Name = "Processador"; State = $cpuState; Value = $cpuValue }

    # O Windows de 32 bits é uma linha à parte: o processador pode servir, mas o Windows 11 só existe em 64 bits, e a
    # troca pede uma instalação nova (a atualização pelo Windows Update não converte).
    if (-not $Is64Bit) {
        $checks += [PSCustomObject]@{ Name = "Windows de 64 bits"; State = "Bad"; Value = "este Windows é de 32 bits: o Windows 11 pede uma instalação nova, de 64 bits" }
    }

    $overall = $(if (@($checks | Where-Object { $_.State -eq "Bad" }).Count -gt 0) { "Bad" } elseif (@($checks | Where-Object { $_.State -eq "Unknown" }).Count -gt 0) { "Unknown" } else { "Ok" })

    return [PSCustomObject]@{ Checks = @($checks); State = $overall }
}


# ---------------------------------------------------------------------------
# Tela
# ---------------------------------------------------------------------------

function Show-WinForgeWindowsSupport {
    $title = "Suporte do Windows"

    Enter-WinForgeAction -Title $title

    $final = New-WinForgeResult -Kind Ok -Title $title

    try {
        Write-Progress -Activity $title -Status "conferindo a versão e as atualizações instaladas"

        try {
            $build = Get-WinForgeWindowsBuild
            $editionId = Get-WinForgeWindowsEditionId
            $catalog = Get-WinForgeCatalog
            $lastUpdate = $(if ($build -lt 22000) { Get-WinForgeLastUpdateDate } else { $null })
            $status = Get-WinForgeWindowsSupportStatus -Build $build -EditionId $editionId -Catalog $catalog
        }
        finally {
            Write-Progress -Activity $title -Completed
        }

        # "Windows 11 Pro 24H2 (build 26100)", como no cartão do Início; sem o nome, o da tabela de datas.
        $session = Get-WinForgeSessionInfo
        $name = [string](Get-WinForgeJsonValue -Object $session -Name "WindowsName" -Default "")
        $version = [string](Get-WinForgeJsonValue -Object $session -Name "WindowsVersion" -Default "")
        $windowsText = $(if ($name) { "$name$(if ($version) { " $version" }) (build $build)" } elseif ([string]$status.Product -match 'build') { [string]$status.Product } else { "$($status.Product) (build $build)" })

        Write-WinForgeSection -Title "Atualizações de segurança"
        Write-WinForgeKeyValue -Label "Windows" -Value $windowsText
        Write-WinForgeKeyValue -Label "Prazo da edição" -Value $(if ($editionId -match '^Server' -and $editionId -notmatch '^ServerRdsh') { "Windows Server" } else { switch ($status.Class) { "Ltsc" { $(if ($editionId -match '^IoT') { "IoT Enterprise LTSC (prazo longo)" } else { "LTSC (prazo longo)" }) } "Enterprise" { "Enterprise e Education" } default { "Home e Pro" } } })
        Write-WinForgeKeyValue -Label "Atualizações até" -Value $(if ($null -ne $status.EndDate) { Format-WinForgeDateTime -When $status.EndDate -Pattern "dd/MM/yyyy" } else { "não está na lista" }) -Level $(if ($status.Level -in "Ok", "Warn", "Bad") { $status.Level } else { "Normal" })
        if ($null -ne $status.EsuEnd) { Write-WinForgeKeyValue -Label "Atualizações estendidas (ESU)" -Value "até $(Format-WinForgeDateTime -When $status.EsuEnd -Pattern 'dd/MM/yyyy')" }
        if ($lastUpdate -is [datetime]) { Write-WinForgeKeyValue -Label "Última atualização instalada" -Value (Format-WinForgeDateTime -When $lastUpdate -Pattern "dd/MM/yyyy") }
        # É a build (e não a data acima) que mostra se o PC recebe o ESU: a 19045.6575 em diante só sai para quem se inscreveu.
        if ($null -ne $status.Revision) { Write-WinForgeKeyValue -Label "Build instalada" -Value "$build.$($status.Revision)" }
        Write-Host ""

        $statusType = switch ($status.Level) { "Ok" { "Success" } "Warn" { "Warning" } "Bad" { "Error" } default { "Info" } }
        Write-WinForgeStatus -Type $statusType -Message $status.Text
        if ($status.Advice) { Write-WinForgeStatus -Type Info -Message $status.Advice }

        # Os requisitos do Windows 11 são para o Windows 10 de mesa: o Windows Server não vai para o Windows 11.
        if ($build -lt 22000 -and -not [bool](Get-WinForgeJsonValue -Object $status -Name "IsServer" -Default $false)) {
            Write-Progress -Activity $title -Status "conferindo os requisitos do Windows 11"

            try {
                $readiness = Get-WinForgeWindows11Readiness
            }
            finally {
                Write-Progress -Activity $title -Completed
            }

            Write-WinForgeSection -Title "Requisitos do Windows 11"

            foreach ($check in $readiness.Checks) {
                $mark = switch ($check.State) { "Ok" { "atende" } "Bad" { "não atende" } default { "não verificado" } }
                Write-WinForgeKeyValue -Label $check.Name -Value "$mark · $($check.Value)" -LabelWidth 26 -Level $(if ($check.State -in "Ok", "Bad") { $check.State } else { "Normal" })
            }

            Write-Host ""

            switch ($readiness.State) {
                "Ok" { Write-WinForgeStatus -Type Success -Message "Este PC atende aos requisitos do Windows 11: a atualização é grátis, em Atualizações > Windows Update." }
                "Bad" { Write-WinForgeStatus -Type Warning -Message "Este PC não atende a todos os requisitos do Windows 11: o ESU é o caminho para continuar recebendo atualizações de segurança$(if ($build -lt 19045) { ', depois de atualizar para o Windows 10 22H2' })." }
                default { Write-WinForgeStatus -Type Info -Message "Parte dos requisitos não pôde ser conferida; o aplicativo Verificação de Integridade do PC dá a resposta final." }
            }

            if (@($readiness.Checks | Where-Object { $_.Name -eq "TPM 2.0" -and $_.State -eq "Unknown" }).Count -gt 0 -and -not (Test-WinForgeAdministrator)) {
                Write-WinForgeStatus -Type Info -Message "Abra o WinForge como Administrador para conferir o TPM."
            }
        }

        Write-WinForgeStatus -Type Info -Message "Datas publicadas pela Microsoft; dados de $(Format-WinForgeDateTime -When (ConvertFrom-WinForgeCatalogDateText -Text $catalog.Updated) -Pattern 'dd/MM/yyyy')."

        $final = switch ($status.State) {
            "Supported" { New-WinForgeResult -Kind Ok -Detail "atualizações de segurança até $(Format-WinForgeDateTime -When $status.EndDate -Pattern 'dd/MM/yyyy')" -Title $title }
            # Fora da lista (Windows 11 mais novo que ela, prévia do Insider, Windows Server): sem veredito, porque o
            # WinForge não sabe a data.
            "Unknown" { $null }
            "Esu" { New-WinForgeResult -Kind Warning -Detail (Get-WinForgeEsuText -Status $status) -Title $title }
            "EndingSoon" { New-WinForgeResult -Kind Warning -Detail $(if ($status.DaysLeft -le 0) { "as atualizações de segurança terminam hoje" } else { "as atualizações de segurança acabam em $(Format-WinForgeCount -Count $status.DaysLeft -One 'dia' -Many 'dias')" }) -Title $title }
            # Sem conseguir ler a build instalada, o PC pode estar no ESU: a faixa diz o que a tela diz, sem afirmar que
            # ele está sem atualizações (como no Início e no Verificar o PC).
            "EsuAvailable" {
                if ([bool]$status.EsuChecked) { New-WinForgeResult -Kind Warning -Detail "esta versão não recebe mais atualizações de segurança gratuitas" -Title $title }
                else { New-WinForgeResult -Kind Warning -Detail "não foi possível conferir se este PC recebe as atualizações estendidas (ESU)" -Title $title }
            }
            default { New-WinForgeResult -Kind Warning -Detail "esta versão não recebe mais atualizações de segurança" -Title $title }
        }
    }
    catch {
        Write-WinForgeStatus -Type Error -Message "Não foi possível conferir o suporte do Windows: $($_.Exception.Message)"
        $final = New-WinForgeResult -Kind Failed -Detail $_.Exception.Message -Title $title
    }

    Exit-WinForgeAction -Result $final
}


Export-ModuleMember -Function *
