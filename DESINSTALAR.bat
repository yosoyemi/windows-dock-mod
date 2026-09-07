@echo off
setlocal
title Emi Windows Dock - Desinstalar
cd /d "%~dp0"
chcp 65001 >nul
echo.
echo  Se va a desactivar el dock.
echo  Windhawk (si estaba) no se borra.
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Uninstall-EmiDock.ps1"
echo.
pause
