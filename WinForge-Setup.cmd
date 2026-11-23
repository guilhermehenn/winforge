@echo off
rem WinForge - instala o WinForge em Arquivos de Programas (ou atualiza a copia instalada). Aberto da pasta instalada,
rem oferece desinstalar. A desinstalacao tambem fica em Configuracoes > Aplicativos.
setlocal
chcp 65001 >nul
cd /d "%~dp0"

rem Aberto de dentro do zip (o Explorador extrai so este arquivo) ou com a pasta extraida pela metade: avisa e para.
if not exist "%~dp0WinForge.Setup.ps1" goto faltam
if not exist "%~dp0modules\Modules.psd1" goto faltam

rem Remove a marca de "baixado da internet" dos arquivos extraidos (evita avisos de seguranca).
set "WINFORGE_ROOT=%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Get-ChildItem -LiteralPath $env:WINFORGE_ROOT -Recurse -File | Unblock-File" >nul 2>&1

rem O PowerShell de 64 bits: aberto por um programa de 32 bits, o Program Files seria o (x86) e o registro, o de 32 bits.
set "WINFORGE_PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if exist "%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe" set "WINFORGE_PS=%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe"

rem O script pede o Administrador sozinho (o aviso do Windows) e continua numa janela nova.
"%WINFORGE_PS%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0WinForge.Setup.ps1" %*

endlocal & exit /b %ERRORLEVEL%

:faltam
rem Ainda sem o PowerShell, o aviso sai nos tres idiomas do WinForge.
echo.
echo   Faltam arquivos do WinForge nesta pasta.
echo   Abra o WinForge.zip, clique em "Extrair tudo" e depois abra
echo   o WinForge-Setup.cmd que estiver na pasta nova.
echo.
echo   Some WinForge files are missing from this folder.
echo   Open WinForge.zip, click "Extract all" and then open
echo   WinForge-Setup.cmd from the new folder.
echo.
echo   Faltan archivos de WinForge en esta carpeta.
echo   Abre WinForge.zip, haz clic en "Extraer todo" y luego abre
echo   WinForge-Setup.cmd en la carpeta nueva.
echo.
pause
endlocal & exit /b 1
