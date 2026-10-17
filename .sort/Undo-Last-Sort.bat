@echo off
rem Undo: puts back the files moved by the latest real run.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Undo-Last-Sort.ps1"
echo.
pause
