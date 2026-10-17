@echo off
rem Preview: shows what would happen, changes nothing.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Sort-Downloads.ps1" -DryRun
echo.
pause
