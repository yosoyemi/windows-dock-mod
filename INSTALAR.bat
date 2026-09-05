@echo off
title Emi Windows Dock
cd /d "%~dp0"
echo.
echo  Emi Liquid Glass Dock
echo  Windows 11 + Windhawk
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Install-EmiDock.ps1"
if errorlevel 1 (
  echo.
  echo Install failed. Read the message above.
  pause
  exit /b 1
)
echo.
pause
