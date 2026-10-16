@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "ROOT=%~dp0"
set "ROOT=%ROOT:~0,-1%"
set "BUILD=%ROOT%\build"

if "%~1"=="" goto usage

if not exist "%BUILD%\CMakeCache.txt" (
  echo No existing CMake build configuration was found.
  echo Run Build-WowWarband.bat once to create the initial configured build tree.
  exit /b 1
)

findstr /X /C:"MODULES:STRING=dynamic" /C:"MODULES:UNINITIALIZED=dynamic" "%BUILD%\CMakeCache.txt" >nul
if errorlevel 1 (
  echo The existing CMake cache is not configured for dynamic modules.
  echo Run Configure-WarbandModules.bat first; it changes configuration but does not compile.
  exit /b 1
)

set "MODULE_TARGETS="

:next_module
if "%~1"=="" goto build

if not exist "%ROOT%\modules\%~1\src\" (
  echo Module "%~1" does not contain a src folder under modules.
  exit /b 1
)

set "MODULE_TARGETS=!MODULE_TARGETS! mod_%~1"
shift
goto next_module

:build
echo Building only the selected dynamic module DLLs...
cmake --build "%BUILD%" --config RelWithDebInfo --target !MODULE_TARGETS! --parallel 4
if errorlevel 1 exit /b 1

for %%T in (!MODULE_TARGETS!) do (
  echo Installing %%T...
  cmake --install "%BUILD%" --config RelWithDebInfo --component %%T
  if errorlevel 1 exit /b 1
)

echo.
echo Selected module DLL targets were built and installed.
echo Runtime discovery/loading is not yet verified; installation does not prove activation.
echo Module SQL, configuration, and client assets remain module-specific setup steps.
exit /b 0

:usage
echo Usage: Build-WarbandModules.bat module-folder [module-folder ...]
echo Example: Build-WarbandModules.bat mod-warband-unbound-loot
echo All modules are configured for dynamic linkage by the main build configuration.
exit /b 1
