@echo off
REM Double-click me whenever you add or remove photos in this folder.
REM Calls update-files.ps1 to regenerate the FILES array inside index.html.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0update-files.ps1"
echo.
pause
