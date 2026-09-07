@echo off
setlocal
title Emi Windows Dock - Instalador
cd /d "%~dp0"
chcp 65001 >nul

echo.
echo  ============================================
echo   Emi Liquid Glass Dock
echo   Instalador para Windows 10 y 11
echo  ============================================
echo.

if not exist "%~dp0scripts\Install-EmiDock.ps1" goto :notextracted
if not exist "%~dp0dist\emi-windows-dock.whdata" goto :notextracted

echo  No cierres esta ventana hasta que termine.
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Install-EmiDock.ps1"
set ERR=%ERRORLEVEL%
if not "%ERR%"=="0" goto :fail

echo.
echo  Instalacion lista.
echo  Windows 11: pasa el mouse por el centro inferior.
echo  Windows 10: dock de vidrio, iconos centrados y visibles.
echo.
pause
exit /b 0

:notextracted
echo  Extrae TODA la carpeta del ZIP antes de instalar.
echo  Clic derecho en el zip - Extraer todo - despues abre INSTALAR.bat
echo  desde la carpeta extraida, no desde dentro del zip.
echo.
pause
exit /b 1

:fail
echo.
echo  La instalacion fallo. Lee el mensaje de arriba.
echo  Log: %TEMP%\emi-dock-install.log
echo.
pause
exit /b 1
