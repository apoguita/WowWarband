@echo off
setlocal EnableExtensions

rem Double-clickable wrapper for Package-WowWarband.ps1.
rem Windows opens .ps1 files in Notepad by default, so the script is invoked through powershell.exe
rem with the execution policy bypassed for this run only.
rem
rem Optional first argument is the version string, for example:
rem     Package-WowWarband.bat 0.6.0

set "ROOT=%~dp0"
set "ROOT=%ROOT:~0,-1%"

set "VERSION=%~1"

echo Building the WoW Warband release package...
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\Package-WowWarband.ps1" -Version "%VERSION%"
set "RESULT=%ERRORLEVEL%"

echo.
if not "%RESULT%"=="0" (
  echo Packaging failed with exit code %RESULT%.
  pause
  exit /b %RESULT%
)

echo Done. The release zip is in:
echo     %ROOT%\dist
echo.
echo Publish it by attaching the zip to a GitHub release. Never commit it: dist\ is gitignored
echo because the file is far over the 100 MB limit for files in a repository.
echo.
pause
