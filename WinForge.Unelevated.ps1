#requires -Version 5.1
<#
.SYNOPSIS
    Roda um programa com a conta de quem usa o PC, sem Administrador, para o WinForge aberto como Administrador.

.DESCRIPTION
    Não é para abrir à mão. O WinForge elevado cria uma tarefa de uma vez só no Agendador de Tarefas, com a conta de quem
    usa o PC e sem elevação, que roda este script (Invoke-WinForgeLimited, no Schedule.psm1). É o caminho para o que o
    Windows só deixa fazer sem Administrador: o winget recusa, de um processo elevado, desinstalar e atualizar programas
    instalados só para a conta da pessoa (erro 0x8A15007D).

    O pedido (a pasta da execução, o programa e os argumentos) chega em -Request. O script cria a pasta e grava nela:
    - pid.txt: o número deste processo, para o WinForge saber que ele começou e poder pará-lo;
    - output.txt: a saída do programa, linha a linha, enquanto ela chega;
    - exitcode.txt: por último, o código de saída do programa, ou "!" e o motivo, quando ele nem abriu.
    Nada aqui pede Administrador: o script e o programa têm os direitos de qualquer programa que a pessoa abre.

.PARAMETER Request
    O pedido em JSON (Folder, FilePath e Arguments), codificado em Base64 (UTF-8).
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [string]$Request
)

# Com "Stop", o Windows PowerShell 5.1 trataria como erro fatal a primeira linha que um programa escreve na saída de
# erros (2>&1): os erros daqui são tratados um a um.
$ErrorActionPreference = "Continue"
$utf8 = New-Object System.Text.UTF8Encoding $false

$order = ConvertFrom-Json -InputObject ($utf8.GetString([Convert]::FromBase64String($Request)))
$folder = [string]$order.Folder
$filePath = [string]$order.FilePath
$arguments = @($order.Arguments | ForEach-Object { [string]$_ })

[void](New-Item -ItemType Directory -Path $folder -Force -ErrorAction Stop)
[System.IO.File]::WriteAllText((Join-Path $folder "pid.txt"), [string]$PID, $utf8)

$writer = New-Object System.IO.StreamWriter ((Join-Path $folder "output.txt"), $false, $utf8)
$writer.AutoFlush = $true
$result = "!"

try {
    # A saída dos programas chega em UTF-8, como na janela do WinForge (Set-WinForgeConsoleEncoding).
    try {
        [Console]::OutputEncoding = $utf8
    }
    catch {
        Write-Verbose "O console não aceitou o UTF-8: $($_.Exception.Message)"
    }

    if ($null -eq (Get-Command -Name $filePath -ErrorAction SilentlyContinue)) {
        $result = "!$filePath"
    }
    else {
        $global:LASTEXITCODE = 0
        & $filePath @arguments 2>&1 | ForEach-Object { $writer.WriteLine((([string]$_) -replace "`0", "")) }
        $result = [string]$LASTEXITCODE
    }
}
catch {
    $result = "!" + ([string]$_.Exception.Message).Trim()
}
finally {
    $writer.Dispose()
}

# Por último: é este arquivo que diz ao WinForge que terminou.
[System.IO.File]::WriteAllText((Join-Path $folder "exitcode.txt"), $result, $utf8)

if ($result -match '^-?\d+$') { exit ([int]$result) }

exit 1
