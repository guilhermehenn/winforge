@echo off
rem WinForge - menu de texto no terminal. Aceita os parametros do script, por exemplo:
rem   WinForge-Console.cmd -Action Report -ReportDirectory "D:\Relatorios"
setlocal
chcp 65001 >nul
cd /d "%~dp0"

rem Remove a marca de "baixado da internet" dos arquivos extraidos (evita avisos de seguranca).
set "WINFORGE_ROOT=%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Get-ChildItem -LiteralPath $env:WINFORGE_ROOT -Recurse -File | Unblock-File" >nul 2>&1

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0WinForge.Console.ps1" %*

set "EXIT_CODE=%ERRORLEVEL%"

if not "%EXIT_CODE%"=="0" (
    echo.
    echo WinForge finalizou com codigo %EXIT_CODE%.
    pause
)

rem "endlocal & exit" na mesma linha: o valor e lido antes de a variavel ser descartada.
endlocal & exit /b %EXIT_CODE%
