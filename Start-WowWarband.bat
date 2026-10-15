@echo off
setlocal EnableExtensions

set "ROOT=%~dp0"
set "BIN=%ROOT%bin\RelWithDebInfo"
set "MYSQL=C:\Program Files\MySQL\MySQL Server 8.4\bin"

if not exist "%BIN%\worldserver.exe" (
  echo WowWarband has not been built yet. Missing: %BIN%\worldserver.exe
  pause
  exit /b 1
)
if not exist "%ROOT%var\mysql\auto.cnf" (
  echo The new WowWarband database has not been initialized.
  echo Complete the setup before starting the server.
  pause
  exit /b 1
)

"%MYSQL%\mysqladmin.exe" --defaults-file="%ROOT%var\mysql-client.ini" --protocol=TCP --host=127.0.0.1 --port=3306 --connect-timeout=2 ping >nul 2>&1
if errorlevel 1 (
  echo Starting the local WowWarband database...
  start "WowWarband database" /min /D "%MYSQL%" "%MYSQL%\mysqld.exe" --no-defaults --basedir="C:\Program Files\MySQL\MySQL Server 8.4" --datadir="%ROOT%var\mysql" --port=3306 --bind-address=127.0.0.1 --mysqlx=0
)

echo Waiting for the local database...
for /L %%I in (1,1,60) do (
  "%MYSQL%\mysqladmin.exe" --defaults-file="%ROOT%var\mysql-client.ini" --protocol=TCP --host=127.0.0.1 --port=3306 --connect-timeout=1 ping >nul 2>&1
  if not errorlevel 1 goto database_ready
  timeout /t 1 /nobreak >nul
)
echo The database did not start. Check that port 3306 is available.
pause
exit /b 1

:database_ready
echo Starting the WowWarband login server...
start "WowWarband Login Server" /D "%BIN%" "%BIN%\authserver.exe" -c configs\authserver.conf
timeout /t 2 /nobreak >nul
echo Starting the WowWarband world server...
start "WowWarband World Server" /D "%BIN%" "%BIN%\worldserver.exe" -c configs\worldserver.conf
echo.
echo Both server consoles are open. Leave them running while you play.
echo To stop: close the world-server console, then the login-server console.
echo Close the minimized WowWarband database window to stop MySQL too.
endlocal
