@echo off
:: ============================================================
::  Jupyter Auto-Installer — Double-click to run
::  This is a wrapper that launches install.ps1
:: ============================================================

title Jupyter Auto-Installer
echo.
echo   ================================================
echo    Jupyter Auto-Installer
echo    Starting installation...
echo   ================================================
echo.

:: Check if running from repo (local install.ps1)
if exist "%~dp0install.ps1" (
    echo   [*] Running local install.ps1...
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1"
) else (
    echo   [*] Downloading and running from GitHub...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/sitaurs/jupyter-autoinstall/main/install.ps1 | iex"
)

if %ERRORLEVEL% neq 0 (
    echo.
    echo   [!] Installation encountered an error.
    echo   [!] Try running as Administrator.
    echo.
)

pause
