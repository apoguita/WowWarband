@echo off
rem Loads the whole WowWarband stack through Warband-Server.ps1, which starts the database,
rem the login server and the world server in order and waits until each one is actually ready.
rem Unload it again with Stop-WowWarband.bat, or inspect it with:
rem   powershell -NoProfile -ExecutionPolicy Bypass -File Warband-Server.ps1 status
setlocal EnableExtensions

set "ROOT=%~dp0"
set "CONTROL=%ROOT%Warband-Server.ps1"

if not exist "%CONTROL%" (
  echo Missing control script: %CONTROL%
  pause
  exit /b 1
)

rem Fresh item data on every launch: item stats (prices, requirements, the gold multiplier on sell
rem prices) are cached by the game client per item and kept on disk, and nothing the worldserver
rem sends can invalidate that cache. Clearing the WDB item cache here makes the first tooltip after
rem this start re-query the server instead of showing a stale number. A running client simply keeps
rem its current cache and the script says so.
if exist "%ROOT%Warband-ClearClientCaches.ps1" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%Warband-ClearClientCaches.ps1"
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%CONTROL%" start all
if errorlevel 1 (
  echo.
  echo Startup did not complete cleanly. The status table above shows what is running.
  pause
  exit /b 1
)

echo.
echo The stack is running. Unload it with Stop-WowWarband.bat.
timeout /t 10 /nobreak >nul
endlocal
