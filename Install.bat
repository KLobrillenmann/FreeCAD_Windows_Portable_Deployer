@echo off
echo Installing FreeCAD Portable...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0script\Install-FreeCAD-Portable.ps1"
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo An error occurred during installation.
    pause
)
