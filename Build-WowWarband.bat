@echo off
setlocal EnableExtensions

set "ROOT=%~dp0"
set "ROOT=%ROOT:~0,-1%"
set "BIN=%ROOT%\bin\RelWithDebInfo"
set "BUILD=%ROOT%\build"
set "BOOST_ROOT=C:\local\boost_1_83_0"
set "OPENSSL_ROOT_DIR=C:\Program Files\OpenSSL-Win64"
set "MYSQL_ROOT=C:\Program Files\MySQL\MySQL Server 8.4"

set "CONFIGURE_ONLY=0"
if not "%~2"=="" goto usage
if /I "%~1"=="--configure" (
  set "CONFIGURE_ONLY=1"
) else if not "%~1"=="" (
  goto usage
)

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

if "%CONFIGURE_ONLY%"=="1" goto configure
if not exist "%BUILD%\CMakeCache.txt" (
  echo No configured build tree exists. Run Build-WowWarband.bat --configure after approval.
  pause
  exit /b 1
)

echo Incrementally building and installing using the existing CMake configuration...
echo CMake may regenerate if build definitions changed. Required dependencies are still checked.
cmake --build "%BUILD%" --config RelWithDebInfo --target install --parallel 4
if errorlevel 1 goto failed

copy /Y "%MYSQL_ROOT%\lib\libmysql.dll" "%BIN%\libmysql.dll" >nul
copy /Y "%OPENSSL_ROOT_DIR%\bin\legacy.dll" "%BIN%\legacy.dll" >nul
copy /Y "%OPENSSL_ROOT_DIR%\bin\libcrypto-3-x64.dll" "%BIN%\libcrypto-3-x64.dll" >nul
copy /Y "%OPENSSL_ROOT_DIR%\bin\libssl-3-x64.dll" "%BIN%\libssl-3-x64.dll" >nul
if errorlevel 1 goto failed

echo.
echo WowWarband incremental build completed in %BIN%
pause
exit /b 0

:configure
echo Configuring only. This does not compile or install the server.
if exist "%BUILD%\CMakeCache.txt" (
  rem Keep existing linkage, toolchain, and module choices.
  cmake -S "%ROOT%" -B "%BUILD%"
) else (
  cmake -S "%ROOT%" -B "%BUILD%" "-DCMAKE_INSTALL_PREFIX=%BIN%" ^
    -DCMAKE_BUILD_TYPE=RelWithDebInfo -DTOOLS_BUILD=all ^
    "-DBOOST_ROOT=%BOOST_ROOT%" "-DOPENSSL_ROOT_DIR=%OPENSSL_ROOT_DIR%" ^
    -DSCRIPTS=static -DMODULES=static
)
if errorlevel 1 goto failed
echo Configuration complete. Run Build-WowWarband.bat separately when the build is approved.
pause
exit /b 0

:usage
echo Usage: Build-WowWarband.bat [--configure]
echo Without arguments: incremental build and install using the existing configuration.
echo --configure: configure only, preserving existing cache options; no server build or install.
exit /b 1

:failed
echo.
echo Build failed. Keep this window open and review the first error above.
pause
exit /b 1
