@echo off
rem Real run: sorts the folder that contains this .sort folder.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Sort-Downloads.ps1"
echo.
pause
