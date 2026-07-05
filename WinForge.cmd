@echo off
setlocal

chcp 65001 >nul
cd /d "%~dp0"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0WinForge.ps1"

set EXIT_CODE=%ERRORLEVEL%

if not "%EXIT_CODE%"=="0" (
    echo.
    echo WinForge finalizou com codigo %EXIT_CODE%.
    pause
)

endlocal
exit /b %EXIT_CODE%
