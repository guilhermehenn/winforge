@echo off
rem WinForge - abre a janela (interface grafica). Para o menu de texto, use WinForge-Console.cmd.
setlocal
cd /d "%~dp0"

rem Remove a marca de "baixado da internet" dos arquivos extraidos (evita avisos de seguranca).
rem O caminho vai por variavel de ambiente para funcionar mesmo com aspas simples no nome da pasta.
set "WINFORGE_ROOT=%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Get-ChildItem -LiteralPath $env:WINFORGE_ROOT -Recurse -File | Unblock-File" >nul 2>&1

rem A janela se reabre como Administrador sozinha; nenhum console fica visivel.
start "" powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File "%~dp0WinForge.Gui.ps1"

endlocal
exit /b 0
