@echo off
title Quitar Emi Windows Dock
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Uninstall-EmiDock.ps1"
pause
