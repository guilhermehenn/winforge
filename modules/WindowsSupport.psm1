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
            foreach ($fix in @(Get-CimInstance -ClassName Win32_QuickFixEngineering -OperationTimeoutSec 30 -ErrorAction Stop)) {
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

    if ($Days -le 0) { return (Get-WinForgeText 'hoje') }

    return (Get-WinForgeText 'daqui a {0}' "$(Format-WinForgeCount -Count $Days -One (Get-WinForgeText 'dia') -Many (Get-WinForgeText 'dias'))")
}


function Get-WinForgeEsuText {
    # "atualizações estendidas (ESU) até 12/10/2027"; o ESU de empresas e escolas (pago pela organização, renovado a cada
    # ano) não tem uma data que o WinForge conheça.
    param ([Parameter(Mandatory)]$Status)

    $end = Get-WinForgeJsonValue -Object $Status -Name "EsuEnd" -Default $null

    if ($end -is [datetime]) { return (Get-WinForgeText 'atualizações estendidas (ESU) até {0}' "$(Format-WinForgeDateTime -When $end -Pattern 'dd/MM/yyyy')") }

    return (Get-WinForgeText 'atualizações estendidas (ESU) da organização')
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
    $update22H2 = (Get-WinForgeText 'Atualize para o Windows 10 22H2 em Atualizações > Windows Update (é grátis): é a versão que ainda pode receber as atualizações estendidas (ESU). Se o PC for compatível, o melhor é o Windows 11.')

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
            $status.Text = (Get-WinForgeText 'Esta versão do Windows não recebe mais atualizações de segurança.')
            $status.Advice = $(if ($Build -ge 10240) { $update22H2 } else { (Get-WinForgeText 'Instale uma versão atual do Windows.') })
        }
        elseif ($isServer) {
            $status.Product = $(if ($Build -gt 0) { "Windows Server (build $Build)" } else { "Windows Server" })
            $status.Text = (Get-WinForgeText 'O WinForge não tem as datas do Windows Server.')
            $status.Advice = (Get-WinForgeText 'Confira o prazo desta versão na página de ciclo de vida da Microsoft.')
        }
        else {
            $status.Product = $(if ($Build -gt 0) { "Windows (build $Build)" } else { "Windows" })
            $status.Text = (Get-WinForgeText 'Esta versão não está na lista de datas do WinForge.')
            $status.Advice = (Get-WinForgeText 'Use Sobre o WinForge > Conferir dados online para conferir.')
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
    $upgradeAdvice = (Get-WinForgeText 'Atualize para a versão mais nova do Windows 11 em Atualizações > Windows Update: é grátis e mantém seus arquivos e programas.')

    if ($Today -le $end) {
        $status.DaysLeft = [int]($end - $Today).TotalDays

        if ($status.DaysLeft -le 90) {
            $status.State = "EndingSoon"
            $status.Level = "Warn"
            $status.Text = $(
                if ($status.DaysLeft -le 0) { (Get-WinForgeText 'As atualizações de segurança desta versão terminam hoje ({0}).' "$endShown") }
                else { (Get-WinForgeText 'As atualizações de segurança desta versão acabam em {0} ({1}).' "$endShown" "$(Get-WinForgeSupportDaysText -Days $status.DaysLeft)") }
            )
            $status.Advice = $(if ($isWindows11) { (Get-WinForgeText '{0} Faça isso antes da data.' "$upgradeAdvice") } else { (Get-WinForgeText 'Planeje a troca de versão antes da data.') })
        }
        else {
            $status.State = "Supported"
            $status.Level = "Ok"
            $status.Text = (Get-WinForgeText 'Recebe atualizações de segurança até {0}.' "$endShown")
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
                $status.Text = (Get-WinForgeText 'Recebe as atualizações de segurança estendidas (ESU) até {0}: o suporte normal acabou em {1}.' "${esuShown}" "$endShown")
                $status.Advice = (Get-WinForgeText 'O ESU é temporário. Se o PC for compatível, a saída definitiva é o Windows 11.')
            }
            else {
                $status.State = "EsuAvailable"
                $status.Level = $(if ($status.EsuChecked) { "Bad" } else { "Warn" })
                $status.Text = $(
                    if ($status.EsuChecked) { (Get-WinForgeText 'Não recebe mais atualizações de segurança gratuitas desde {0}, e nenhuma atualização do programa ESU foi instalada.' "$endShown") }
                    else { (Get-WinForgeText 'Não recebe mais atualizações de segurança gratuitas desde {0}. Não foi possível conferir se este PC recebe as atualizações estendidas (ESU).' "$endShown") }
                )
                $status.Advice = (Get-WinForgeText 'Dá para receber as de segurança até {0} pelo programa ESU: inscreva-se em Configurações, Windows Update (atalho: Atualizações > Windows Update); se o PC já está inscrito, instale as atualizações pendentes por lá. Se o PC for compatível, a saída definitiva é o Windows 11.' "$esuShown")
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
            $status.Text = (Get-WinForgeText 'Recebe as atualizações de segurança estendidas (ESU) contratadas pela organização: o suporte normal acabou em {0}.' "$endShown")
            $status.Advice = (Get-WinForgeText 'O ESU de empresas e escolas é renovado a cada ano. Se o PC for compatível, a saída definitiva é o Windows 11.')

            return [PSCustomObject]$status
        }
    }

    $status.State = "Ended"
    $status.Level = "Bad"
    $status.Text = (Get-WinForgeText 'Não recebe mais atualizações de segurança desde {0}.' "$endShown")
    $status.Advice = $(
        if ($class -eq "Ltsc") { (Get-WinForgeText 'Esta edição de longo prazo (LTSC) precisa ser trocada por uma versão com suporte; fale com quem administra o PC.') }
        elseif ($isWindows11) { $upgradeAdvice }
        elseif ($firstEsu -gt 0 -and $class -eq "Enterprise" -and $null -ne $orgEnd -and $Today -le $orgEnd) { (Get-WinForgeText 'Empresas e escolas podem contratar as atualizações estendidas (ESU) para este PC; fale com quem administra o PC. Se ele for compatível, a saída definitiva é o Windows 11.') }
        elseif ($Build -lt 19045) { $update22H2 }
        else { (Get-WinForgeText 'Se o PC for compatível, atualize para o Windows 11 em Atualizações > Windows Update.') }
    )

    return [PSCustomObject]$status
}


function Get-WinForgeWindowsSupportShortText {
    <#
    O prazo do suporte em poucas palavras, para o cartão do Windows no Início e a faixa do alto das Atualizações:
    "suporte até 13/10/2026", "ESU até 12/10/2027", "ESU da organização", "suporte não conferido" (sem conseguir conferir
    o ESU) ou "sem suporte de segurança". Vazio quando a versão não está na lista do WinForge (ou é um Windows Server).
    #>
    param ([Parameter(Mandatory)]$Status)

    $endDate = Get-WinForgeJsonValue -Object $Status -Name "EndDate" -Default $null
    $esuEnd = Get-WinForgeJsonValue -Object $Status -Name "EsuEnd" -Default $null

    switch ([string]$Status.State) {
        { $_ -in @("Supported", "EndingSoon") } {
            if ($endDate -is [datetime]) { return (Get-WinForgeText 'suporte até {0}' "$(Format-WinForgeDateTime -When $endDate -Pattern 'dd/MM/yyyy')") }
            return ""
        }
        "Esu" {
            if ($esuEnd -is [datetime]) { return (Get-WinForgeText 'ESU até {0}' "$(Format-WinForgeDateTime -When $esuEnd -Pattern 'dd/MM/yyyy')") }
            return (Get-WinForgeText 'ESU da organização')
        }
        "EsuAvailable" {
            if (-not [bool](Get-WinForgeJsonValue -Object $Status -Name "EsuChecked" -Default $true)) { return (Get-WinForgeText 'suporte não conferido') }
            return (Get-WinForgeText 'sem suporte de segurança')
        }
        "Ended" { return (Get-WinForgeText 'sem suporte de segurança') }
    }

    return ""
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
                return (New-WinForgeHealthIssue -Id "windows-support" -Text (Get-WinForgeText 'Não foi possível conferir se o {0} ainda recebe atualizações de segurança' "$($Status.Product)") -Weight 10 -Target "diagnostics.windows-support" -ButtonText (Get-WinForgeText 'Ver opções'))
            }

            return (New-WinForgeHealthIssue -Id "windows-support" -Text (Get-WinForgeText 'O {0} não recebe mais atualizações de segurança' "$($Status.Product)") -Weight 20 -Target "diagnostics.windows-support" -ButtonText (Get-WinForgeText 'Ver como resolver'))
        }
        "Ended" {
            return (New-WinForgeHealthIssue -Id "windows-support" -Text (Get-WinForgeText 'O {0} não recebe mais atualizações de segurança' "$($Status.Product)") -Weight 20 -Target "diagnostics.windows-support" -ButtonText (Get-WinForgeText 'Ver como resolver'))
        }
        "EndingSoon" {
            $when = $(if ([int]$Status.DaysLeft -le 0) { (Get-WinForgeText 'terminam hoje') } else { (Get-WinForgeText 'acabam em {0}' "$(Format-WinForgeCount -Count $Status.DaysLeft -One (Get-WinForgeText 'dia') -Many (Get-WinForgeText 'dias'))") })
            return (New-WinForgeHealthIssue -Id "windows-support" -Text (Get-WinForgeText 'As atualizações de segurança do {0} {1}' "$($Status.Product)" "$when") -Weight 8 -Target "diagnostics.windows-support" -ButtonText (Get-WinForgeText 'Ver como resolver'))
        }
        "Esu" {
            $text = $(if ($Status.EsuEnd -is [datetime]) { (Get-WinForgeText 'O Windows 10 está nas atualizações estendidas (ESU), que acabam em {0}' "$(Format-WinForgeDateTime -When $Status.EsuEnd -Pattern 'dd/MM/yyyy')") } else { (Get-WinForgeText 'O Windows 10 está nas atualizações estendidas (ESU) da organização') })
            return (New-WinForgeHealthIssue -Id "windows-support" -Text $text -Weight 5 -Target "diagnostics.windows-support" -ButtonText (Get-WinForgeText 'Ver opções'))
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
        $tpm = @(Get-CimInstance -Namespace "root/cimv2/Security/MicrosoftTpm" -ClassName Win32_Tpm -OperationTimeoutSec 15 -ErrorAction Stop) | Select-Object -First 1
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
    $tpmValue = $(if ($null -eq $TpmVersion) { $(if (Test-WinForgeAdministrator) { (Get-WinForgeText 'não foi possível ler') } else { (Get-WinForgeText 'não verificado (requer Administrador)') }) } elseif ([string]::IsNullOrWhiteSpace([string]$TpmVersion)) { (Get-WinForgeText 'não encontrado ou desligado no firmware') } else { "TPM $TpmVersion" })
    $checks += [PSCustomObject]@{ Name = (Get-WinForgeText 'TPM 2.0'); State = $tpmState; Value = $tpmValue }

    # O texto vem de Get-WinForgeSecureBootText, já no idioma da tela.
    $legacyText = Get-WinForgeText 'Indisponível (o Windows iniciou no modo BIOS legado)'
    $uefiState = $(if ($SecureBootText -eq (Get-WinForgeText 'Ativado') -or $SecureBootText -eq (Get-WinForgeText 'Desativado')) { "Ok" } elseif ($SecureBootText -eq $legacyText) { "Bad" } else { "Unknown" })
    $uefiValue = $(
        if ($SecureBootText -eq (Get-WinForgeText 'Desativado')) { (Get-WinForgeText 'UEFI, Secure Boot desligado (dá para ligar no firmware)') }
        elseif ($SecureBootText -eq (Get-WinForgeText 'Ativado')) { (Get-WinForgeText 'UEFI, Secure Boot ligado') }
        # O modo de inicialização, e não o que a placa suporta: muitos PCs com BIOS legado (CSM) têm UEFI, e o disco pode
        # ser convertido (MBR2GPT) sem reinstalar o Windows.
        elseif ($SecureBootText -eq $legacyText) { (Get-WinForgeText 'o Windows iniciou no modo antigo (BIOS legado); trocar para UEFI exige preparar o disco antes, trabalho para um técnico') }
        else { $SecureBootText }
    )
    $checks += [PSCustomObject]@{ Name = (Get-WinForgeText 'UEFI e Secure Boot'); State = $uefiState; Value = $uefiValue }

    $memoryState = $(if ($MemoryBytes -le 0) { "Unknown" } elseif ($MemoryBytes -ge $memoryMinimum) { "Ok" } else { "Bad" })
    $checks += [PSCustomObject]@{ Name = (Get-WinForgeText 'Memória (4 GB)'); State = $memoryState; Value = $(if ($MemoryBytes -gt 0) { Format-WinForgeBytes -Bytes $MemoryBytes } else { (Get-WinForgeText 'não lida') }) }

    # 64 GB, contados como no script de requisitos da Microsoft (HardwareReadiness.ps1): o tamanho da unidade do
    # Windows dividido por 1 GB e arredondado para inteiro.
    $diskState = $(if ($DiskBytes -le 0) { "Unknown" } elseif ([int]($DiskBytes / 1GB) -ge 64) { "Ok" } else { "Bad" })
    $checks += [PSCustomObject]@{ Name = (Get-WinForgeText 'Disco do sistema (64 GB)'); State = $diskState; Value = $(if ($DiskBytes -gt 0) { Format-WinForgeBytes -Bytes $DiskBytes } else { (Get-WinForgeText 'não lido') }) }

    $cpuState = Get-WinForgeWindows11CpuSupport -Name $CpuName
    if ($CpuCores -gt 0 -and $CpuCores -lt 2) { $cpuState = "Bad" }
    $cpuValue = $(if ([string]::IsNullOrWhiteSpace($CpuName)) { (Get-WinForgeText 'não lido') } elseif ($cpuState -eq "Unknown") { (Get-WinForgeText '{0} (confira na lista da Microsoft)' "$($CpuName.Trim())") } else { $CpuName.Trim() })
    $checks += [PSCustomObject]@{ Name = (Get-WinForgeText 'Processador'); State = $cpuState; Value = $cpuValue }

    # O Windows de 32 bits é uma linha à parte: o processador pode servir, mas o Windows 11 só existe em 64 bits, e a
    # troca pede uma instalação nova (a atualização pelo Windows Update não converte).
    if (-not $Is64Bit) {
        $checks += [PSCustomObject]@{ Name = (Get-WinForgeText 'Windows de 64 bits'); State = "Bad"; Value = (Get-WinForgeText 'este Windows é de 32 bits: o Windows 11 pede uma instalação nova, de 64 bits') }
    }

    $overall = $(if (@($checks | Where-Object { $_.State -eq "Bad" }).Count -gt 0) { "Bad" } elseif (@($checks | Where-Object { $_.State -eq "Unknown" }).Count -gt 0) { "Unknown" } else { "Ok" })

    return [PSCustomObject]@{ Checks = @($checks); State = $overall }
}


# ---------------------------------------------------------------------------
# Tela
# ---------------------------------------------------------------------------

function Show-WinForgeWindowsSupport {
    $title = (Get-WinForgeText 'Suporte do Windows')

    Enter-WinForgeAction -Title $title

    $final = New-WinForgeResult -Kind Ok -Title $title

    try {
        Write-Progress -Activity $title -Status (Get-WinForgeText 'conferindo a versão e as atualizações instaladas')

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
        $windowsText = $(if ($name) { (Get-WinForgeText '{0}{1} (build {2})' "$name" "$(if ($version) { " $version" })" "$build") } elseif ([string]$status.Product -match 'build') { [string]$status.Product } else { (Get-WinForgeText '{0} (build {1})' "$($status.Product)" "$build") })

        Write-WinForgeSection -Title (Get-WinForgeText 'Atualizações de segurança')
        Write-WinForgeKeyValue -Label (Get-WinForgeText 'Windows') -Value $windowsText
        Write-WinForgeKeyValue -Label (Get-WinForgeText 'Prazo da edição') -Value $(if ($editionId -match '^Server' -and $editionId -notmatch '^ServerRdsh') { (Get-WinForgeText 'Windows Server') } else { switch ($status.Class) { "Ltsc" { $(if ($editionId -match '^IoT') { (Get-WinForgeText 'IoT Enterprise LTSC (prazo longo)') } else { (Get-WinForgeText 'LTSC (prazo longo)') }) } "Enterprise" { (Get-WinForgeText 'Enterprise e Education') } default { (Get-WinForgeText 'Home e Pro') } } })
        Write-WinForgeKeyValue -Label (Get-WinForgeText 'Atualizações até') -Value $(if ($null -ne $status.EndDate) { Format-WinForgeDateTime -When $status.EndDate -Pattern "dd/MM/yyyy" } else { (Get-WinForgeText 'não está na lista') }) -Level $(if ($status.Level -in "Ok", "Warn", "Bad") { $status.Level } else { "Normal" })
        if ($null -ne $status.EsuEnd) { Write-WinForgeKeyValue -Label (Get-WinForgeText 'Atualizações estendidas (ESU)') -Value (Get-WinForgeContextText 'data' 'até {0}' "$(Format-WinForgeDateTime -When $status.EsuEnd -Pattern 'dd/MM/yyyy')") }
        if ($lastUpdate -is [datetime]) { Write-WinForgeKeyValue -Label (Get-WinForgeText 'Última atualização instalada') -Value (Format-WinForgeDateTime -When $lastUpdate -Pattern "dd/MM/yyyy") }
        # É a build (e não a data acima) que mostra se o PC recebe o ESU: a 19045.6575 em diante só sai para quem se inscreveu.
        if ($null -ne $status.Revision) { Write-WinForgeKeyValue -Label (Get-WinForgeText 'Build instalada') -Value "$build.$($status.Revision)" }
        Write-Host ""

        $statusType = switch ($status.Level) { "Ok" { "Success" } "Warn" { "Warning" } "Bad" { "Error" } default { "Info" } }
        Write-WinForgeStatus -Type $statusType -Message $status.Text
        if ($status.Advice) { Write-WinForgeStatus -Type Info -Message $status.Advice }

        # Os requisitos do Windows 11 são para o Windows 10 de mesa: o Windows Server não vai para o Windows 11.
        if ($build -lt 22000 -and -not [bool](Get-WinForgeJsonValue -Object $status -Name "IsServer" -Default $false)) {
            Write-Progress -Activity $title -Status (Get-WinForgeText 'conferindo os requisitos do Windows 11')

            try {
                $readiness = Get-WinForgeWindows11Readiness
            }
            finally {
                Write-Progress -Activity $title -Completed
            }

            Write-WinForgeSection -Title (Get-WinForgeText 'Requisitos do Windows 11')

            foreach ($check in $readiness.Checks) {
                $mark = switch ($check.State) { "Ok" { (Get-WinForgeText 'atende') } "Bad" { (Get-WinForgeText 'não atende') } default { (Get-WinForgeText 'não verificado') } }
                Write-WinForgeKeyValue -Label $check.Name -Value "$mark · $($check.Value)" -LabelWidth 26 -Level $(if ($check.State -in "Ok", "Bad") { $check.State } else { "Normal" })
            }

            Write-Host ""

            switch ($readiness.State) {
                "Ok" { Write-WinForgeStatus -Type Success -Message (Get-WinForgeText 'Este PC atende aos requisitos do Windows 11: a atualização é grátis, em Atualizações > Windows Update.') }
                "Bad" { Write-WinForgeStatus -Type Warning -Message (Get-WinForgeText 'Este PC não atende a todos os requisitos do Windows 11: o ESU é o caminho para continuar recebendo atualizações de segurança{0}.' "$(if ($build -lt 19045) { (Get-WinForgeText ', depois de atualizar para o Windows 10 22H2') })") }
                default { Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Parte dos requisitos não pôde ser conferida; o aplicativo Verificação de Integridade do PC dá a resposta final.') }
            }

            if (@($readiness.Checks | Where-Object { $_.Name -eq (Get-WinForgeText 'TPM 2.0') -and $_.State -eq "Unknown" }).Count -gt 0 -and -not (Test-WinForgeAdministrator)) {
                Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Abra o WinForge como Administrador para conferir o TPM.')
            }
        }

        Write-WinForgeStatus -Type Info -Message (Get-WinForgeText 'Datas publicadas pela Microsoft; dados de {0}.' "$(Format-WinForgeDateTime -When (ConvertFrom-WinForgeCatalogDateText -Text $catalog.Updated) -Pattern 'dd/MM/yyyy')")

        $final = switch ($status.State) {
            "Supported" { New-WinForgeResult -Kind Ok -Detail (Get-WinForgeText 'atualizações de segurança até {0}' "$(Format-WinForgeDateTime -When $status.EndDate -Pattern 'dd/MM/yyyy')") -Title $title }
            # Fora da lista (Windows 11 mais novo que ela, prévia do Insider, Windows Server): sem veredito, porque o
            # WinForge não sabe a data.
            "Unknown" { $null }
            "Esu" { New-WinForgeResult -Kind Warning -Detail (Get-WinForgeEsuText -Status $status) -Title $title }
            "EndingSoon" { New-WinForgeResult -Kind Warning -Detail $(if ($status.DaysLeft -le 0) { (Get-WinForgeText 'as atualizações de segurança terminam hoje') } else { (Get-WinForgeText 'as atualizações de segurança acabam em {0}' "$(Format-WinForgeCount -Count $status.DaysLeft -One (Get-WinForgeText 'dia') -Many (Get-WinForgeText 'dias'))") }) -Title $title }
            # Sem conseguir ler a build instalada, o PC pode estar no ESU: a faixa diz o que a tela diz, sem afirmar que
            # ele está sem atualizações (como no Início e no Verificar o PC).
            "EsuAvailable" {
                if ([bool]$status.EsuChecked) { New-WinForgeResult -Kind Warning -Detail (Get-WinForgeText 'esta versão não recebe mais atualizações de segurança gratuitas') -Title $title }
                else { New-WinForgeResult -Kind Warning -Detail (Get-WinForgeText 'não foi possível conferir se este PC recebe as atualizações estendidas (ESU)') -Title $title }
            }
            default { New-WinForgeResult -Kind Warning -Detail (Get-WinForgeText 'esta versão não recebe mais atualizações de segurança') -Title $title }
        }
    }
    catch {
        Write-WinForgeStatus -Type Error -Message (Get-WinForgeText 'Não foi possível conferir o suporte do Windows: {0}' "$($_.Exception.Message)")
        $final = New-WinForgeResult -Kind Failed -Detail $_.Exception.Message -Title $title
    }

    Exit-WinForgeAction -Result $final
}


Export-ModuleMember -Function *
