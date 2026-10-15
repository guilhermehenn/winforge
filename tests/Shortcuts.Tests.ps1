# Atalhos para janelas do Windows. O Start-Process é substituído por um registro: nenhuma janela é aberta.

BeforeAll {
    . (Join-Path $PSScriptRoot "TestSetup.ps1")

    function script:Use-StartProcessStub {
        param ([switch]$Fail)

        $global:WfStarted = New-Object System.Collections.ArrayList
        $global:WfStartFails = [bool]$Fail

        Set-TestStub -Name "Start-Process" -Body {
            [CmdletBinding()]
            param ([Parameter(Position = 0)][string]$FilePath, [Parameter(Position = 1)][string[]]$ArgumentList)

            if ($global:WfStartFails) { throw "O sistema não pode encontrar o arquivo especificado." }

            [void]$global:WfStarted.Add([PSCustomObject]@{ File = $FilePath; Arguments = (@($ArgumentList) -join " ") })
        }
    }

    function script:Clear-StartProcessStub {
        Remove-Item Function:\global:Start-Process -ErrorAction SilentlyContinue
        Remove-Variable WfStarted, WfStartFails -Scope Global -ErrorAction SilentlyContinue
    }
}

AfterAll {
    Clear-StartProcessStub
    Remove-WinForgeTestData
}

Describe "Tabela de atalhos" {
    It "tem nomes únicos e todos têm título" {
        $names = @(Get-WinForgeShortcutNames)

        $names.Count | Should -BeGreaterThan 5
        @($names | Select-Object -Unique).Count | Should -Be $names.Count

        foreach ($name in $names) {
            Get-WinForgeShortcutTitle -Name $name | Should -Not -BeNullOrEmpty
        }
    }

    It "todo atalho da tabela é usado por algum item do menu lateral ou da manutenção (sem atalho esquecido)" {
        $used = @()

        foreach ($page in @(Get-WinForgeNavigation)) {
            $used += @($page.Items | Where-Object { $_.Kind -eq "Shortcut" } | ForEach-Object { $_.Shortcut })
        }

        $used += @(Get-WinForgeMaintenancePlanItems | Where-Object { $_.Shortcut } | ForEach-Object { $_.Shortcut })

        $unused = @(Get-WinForgeShortcutNames | Where-Object { $_ -notin $used })

        $unused | Should -HaveCount 0
    }

    It "o título de um atalho desconhecido lança erro claro" {
        { Get-WinForgeShortcutTitle -Name "Inventado" } | Should -Throw -ExpectedMessage "*Atalho desconhecido*"
    }

    It "todo atalho usado nas etapas manuais da manutenção existe" {
        $names = @(Get-WinForgeShortcutNames)

        foreach ($item in (Get-WinForgeMaintenancePlanItems)) {
            if ($item.Shortcut) { $names | Should -Contain $item.Shortcut }
        }
    }
}

Describe "Abrir atalhos" {
    It "painéis do Configurações abrem pelo endereço ms-settings, sem argumentos" {
        Use-StartProcessStub
        try {
            $text = Get-HostText { $script:Opened = Open-WinForgeShortcut -Name "WindowsUpdate" }

            $script:Opened | Should -BeTrue
            $global:WfStarted | Should -HaveCount 1
            $global:WfStarted[0].File | Should -Be "ms-settings:windowsupdate"
            $global:WfStarted[0].Arguments | Should -Be ""
            $text | Should -Match "Windows Update aberto"
        }
        finally { Clear-StartProcessStub }
    }

    It "Programas e Recursos e o Gerenciador de Dispositivos passam o argumento ao programa" {
        Use-StartProcessStub
        try {
            [void](Get-HostText { Open-WinForgeShortcut -Name "ProgramsAndFeatures" })
            [void](Get-HostText { Open-WinForgeShortcut -Name "DeviceManager" })

            $global:WfStarted[0].File | Should -Be "control.exe"
            $global:WfStarted[0].Arguments | Should -Be "appwiz.cpl"
            $global:WfStarted[1].File | Should -Be "mmc.exe"
            $global:WfStarted[1].Arguments | Should -Be "devmgmt.msc"
        }
        finally { Clear-StartProcessStub }
    }

    It "Restauração do Sistema, Segurança do Windows e Agendador de Tarefas abrem o programa certo" {
        Use-StartProcessStub
        try {
            [void](Get-HostText { Open-WinForgeShortcut -Name "SystemRestore" -Quiet })
            [void](Get-HostText { Open-WinForgeShortcut -Name "WindowsSecurity" -Quiet })
            [void](Get-HostText { Open-WinForgeShortcut -Name "TaskScheduler" -Quiet })

            $global:WfStarted[0].File | Should -Be "rstrui.exe"
            $global:WfStarted[0].Arguments | Should -Be ""
            $global:WfStarted[1].File | Should -Be "windowsdefender:"
            $global:WfStarted[2].File | Should -Be "mmc.exe"
            $global:WfStarted[2].Arguments | Should -Be "taskschd.msc"
        }
        finally { Clear-StartProcessStub }
    }

    It "a pasta de logs abre no Explorador, com o caminho entre aspas" {
        Use-StartProcessStub
        try {
            [void](Get-HostText { Open-WinForgeShortcut -Name "LogFolder" -Quiet })

            $global:WfStarted | Should -HaveCount 1
            $global:WfStarted[0].File | Should -Be "explorer.exe"
            $global:WfStarted[0].Arguments | Should -Be ('"' + (Get-WinForgeDataPath) + '"')
        }
        finally { Clear-StartProcessStub }
    }

    It "Downloads abre a pasta quando ela existe" {
        Use-StartProcessStub
        $folder = Join-Path $script:TestDataRoot "Downloads com espaço"
        New-Item -ItemType Directory -Path $folder -Force | Out-Null
        Set-TestStub -Name "Get-WinForgeDownloadsPath" -Body { $global:WfDownloadsFolder }
        $global:WfDownloadsFolder = $folder
        try {
            $opened = $null
            [void](Get-HostText { $script:Opened = Open-WinForgeShortcut -Name "Downloads" -Quiet })

            $script:Opened | Should -BeTrue
            $global:WfStarted[0].File | Should -Be "explorer.exe"
            $global:WfStarted[0].Arguments | Should -Be ('"' + $folder + '"')
        }
        finally { Clear-StartProcessStub; Remove-Variable WfDownloadsFolder -Scope Global -ErrorAction SilentlyContinue; Clear-TestStubs }
    }

    It "Downloads inexistente mostra o erro e devolve falso, sem abrir nada" {
        Use-StartProcessStub
        Set-TestStub -Name "Get-WinForgeDownloadsPath" -Body { Join-Path $global:WfDownloadsFolder "nao-existe" }
        $global:WfDownloadsFolder = $script:TestDataRoot
        try {
            $text = Get-HostText { $script:Opened = Open-WinForgeShortcut -Name "Downloads" }

            $script:Opened | Should -BeFalse
            $global:WfStarted | Should -HaveCount 0
            $text | Should -Match "Não foi possível abrir 'Pasta Downloads'"
            $text | Should -Match "não encontrada"
        }
        finally { Clear-StartProcessStub; Remove-Variable WfDownloadsFolder -Scope Global -ErrorAction SilentlyContinue; Clear-TestStubs }
    }

    It "falha do sistema ao abrir vira mensagem e falso, nunca exceção" {
        Use-StartProcessStub -Fail
        try {
            # Uma exceção aqui derrubaria o teste; o esperado é só a mensagem e o resultado falso.
            $text = Get-HostText { $script:Opened = Open-WinForgeShortcut -Name "Storage" }

            $script:Opened | Should -BeFalse
            $text | Should -Match "Não foi possível abrir 'Configurações de armazenamento'"
        }
        finally { Clear-StartProcessStub }
    }

    It "-Quiet não mostra a confirmação de sucesso" {
        Use-StartProcessStub
        try {
            $text = Get-HostText { [void](Open-WinForgeShortcut -Name "Reliability" -Quiet) }
            $text | Should -Not -Match "aberto"
        }
        finally { Clear-StartProcessStub }
    }

    It "atalho desconhecido lança erro (é erro de programação, não do usuário)" {
        { Open-WinForgeShortcut -Name "Inventado" } | Should -Throw -ExpectedMessage "*Atalho desconhecido*"
    }
}
