@echo off
rem Unloads the whole WowWarband stack through Warband-Server.ps1: world server, then login
rem server, then the database. Stops are graceful (characters are saved, InnoDB shuts down
rem cleanly) and any process left over from an earlier launch is reaped as well.
setlocal EnableExtensions

set "ROOT=%~dp0"
set "CONTROL=%ROOT%Warband-Server.ps1"

if not exist "%CONTROL%" (
  echo Missing control script: %CONTROL%
  pause
  exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%CONTROL%" stop all
echo.
pause
endlocal
