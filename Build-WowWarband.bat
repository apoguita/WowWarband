@echo off
setlocal EnableExtensions

set "ROOT=%~dp0"
set "ROOT=%ROOT:~0,-1%"
set "BIN=%ROOT%\bin\RelWithDebInfo"
set "BUILD=%ROOT%\build"
set "BOOST_ROOT=C:\local\boost_1_83_0"
set "OPENSSL_ROOT_DIR=C:\Program Files\OpenSSL-Win64"
set "MYSQL_ROOT=C:\Program Files\MySQL\MySQL Server 8.4"

if not exist "%BOOST_ROOT%\boost\version.hpp" (
  echo Boost 1.83 is missing from %BOOST_ROOT%
  pause
  exit /b 1
)
if not exist "%OPENSSL_ROOT_DIR%\include\openssl\ssl.h" (
  echo OpenSSL is missing from %OPENSSL_ROOT_DIR%
  pause
  exit /b 1
)
if not exist "%MYSQL_ROOT%\lib\libmysql.dll" (
  echo MySQL 8.4 client files are missing from %MYSQL_ROOT%
  pause
  exit /b 1
)

echo Configuring the pinned WowWarband source tree...
cmake -S "%ROOT%" -B "%BUILD%" "-DCMAKE_INSTALL_PREFIX=%BIN%" -DCMAKE_BUILD_TYPE=RelWithDebInfo -DTOOLS_BUILD=all "-DBOOST_ROOT=%BOOST_ROOT%" "-DOPENSSL_ROOT_DIR=%OPENSSL_ROOT_DIR%" -DSCRIPTS=static -DMODULES=static
if errorlevel 1 goto failed

echo Building server, tools, and selected modules...
cmake --build "%BUILD%" --config RelWithDebInfo --target install --parallel 4
if errorlevel 1 goto failed

copy /Y "%MYSQL_ROOT%\lib\libmysql.dll" "%BIN%\libmysql.dll" >nul
copy /Y "%OPENSSL_ROOT_DIR%\bin\legacy.dll" "%BIN%\legacy.dll" >nul
copy /Y "%OPENSSL_ROOT_DIR%\bin\libcrypto-3-x64.dll" "%BIN%\libcrypto-3-x64.dll" >nul
copy /Y "%OPENSSL_ROOT_DIR%\bin\libssl-3-x64.dll" "%BIN%\libssl-3-x64.dll" >nul
if errorlevel 1 goto failed

echo.
echo WowWarband rebuild completed in %BIN%
pause
exit /b 0

:failed
echo.
echo Build failed. Keep this window open and review the first error above.
pause
exit /b 1
