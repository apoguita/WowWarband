@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "ROOT=%~dp0"
set "ROOT=%ROOT:~0,-1%"
set "BUILD=%ROOT%\build"

if not exist "%BUILD%\CMakeCache.txt" (
  echo No existing CMake build configuration was found.
  echo Run Build-WowWarband.bat once to create the initial configured build tree.
  exit /b 1
)

if not "%~1"=="" goto usage

echo Configuring all discovered modules for dynamic linkage. This does not compile anything.
cmake -S "%ROOT%" -B "%BUILD%" -DMODULES=dynamic
if errorlevel 1 exit /b 1

echo.
echo Dynamic module configuration updated.
echo Next full build: Build-WowWarband.bat. Later module-only changes can use Build-WarbandModules.bat.
exit /b 0

:usage
echo Usage: Configure-WarbandModules.bat
echo This configures all discovered C++ modules for dynamic linkage.
exit /b 1
