@{
    Severity     = @('Error', 'Warning')

    ExcludeRules = @(
        # A interface do WinForge é feita de Write-Host (cores, quadros); o host gráfico captura essa saída.
        'PSAvoidUsingWriteHost',

        # Várias funções devolvem coleções ("Get-WinForgeTweakCatalog", "Show-WinForgeDisks"): plural é intencional.
        'PSUseSingularNouns',

        # As ações pedem confirmação por conta própria (Confirm-WinForgeAction), não por -WhatIf/-Confirm.
        'PSUseShouldProcessForStateChangingFunctions',

        # Alguns "catch { }" vazios são deliberados: a falha de uma informação auxiliar não pode impedir uma tela.
        'PSAvoidUsingEmptyCatchBlock',

        # Os módulos compartilham o estado da janela e do console por variáveis globais ($global:WinForgeGuiMode...).
        'PSAvoidGlobalVars',

        'PSAvoidUsingPositionalParameters'
    )
}
