@echo off
setlocal
set "APP=%~dp0var\tools\Keira3\Keira-3.10.5.WINDOWS.exe"
if not exist "%APP%" (
  echo Keira3 is missing. Complete the local tool setup first.
  pause
  exit /b 1
)
start "Keira3 - WowWarband database editor" "%APP%"
endlocal
