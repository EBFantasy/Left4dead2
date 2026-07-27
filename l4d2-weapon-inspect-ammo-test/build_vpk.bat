@echo off
REM ============================================================================
REM  [TEST] Weapon Inspect Ammo Check -- Windows VPK build script
REM
REM  Produces  ebf_inspect_ammo_test.vpk  from the "addon" folder next to this
REM  script, then tells you where to copy it.
REM
REM  Usage: just double-click this file.
REM ============================================================================

setlocal enabledelayedexpansion

set "HERE=%~dp0"
set "SRC=%HERE%addon"

echo.
echo  [TEST] Weapon Inspect Ammo Check -- VPK builder
echo  ------------------------------------------------

if not exist "%SRC%\addoninfo.txt" (
	echo  ERROR: "%SRC%\addoninfo.txt" not found.
	echo  Run this script from inside the project folder.
	goto :fail
)

if not exist "%SRC%\scripts\vscripts\ebf_inspect_ammo.nut" (
	echo  ERROR: scripts\vscripts\ebf_inspect_ammo.nut is missing.
	goto :fail
)

if not exist "%SRC%\scripts\vscripts\mapspawn_addon.nut" (
	echo  ERROR: scripts\vscripts\mapspawn_addon.nut is missing.
	goto :fail
)

REM --- Locate vpk.exe -------------------------------------------------------
set "VPK="

for %%P in (
	"C:\Program Files (x86)\Steam\steamapps\common\Left 4 Dead 2\bin\vpk.exe"
	"C:\Program Files\Steam\steamapps\common\Left 4 Dead 2\bin\vpk.exe"
	"D:\Steam\steamapps\common\Left 4 Dead 2\bin\vpk.exe"
	"D:\SteamLibrary\steamapps\common\Left 4 Dead 2\bin\vpk.exe"
	"E:\Steam\steamapps\common\Left 4 Dead 2\bin\vpk.exe"
	"E:\SteamLibrary\steamapps\common\Left 4 Dead 2\bin\vpk.exe"
) do (
	if exist %%P set "VPK=%%~P"
)

if "%VPK%"=="" (
	echo  Could not find vpk.exe automatically.
	echo.
	set /p "VPK=Drag your Left 4 Dead 2\bin\vpk.exe here and press Enter: "
)

if not exist "%VPK%" (
	echo  ERROR: vpk.exe not found at "%VPK%".
	goto :fail
)

echo  Using vpk.exe : %VPK%
echo  Packing       : %SRC%
echo.

if exist "%HERE%addon.vpk" del /q "%HERE%addon.vpk"
if exist "%HERE%ebf_inspect_ammo_test.vpk" del /q "%HERE%ebf_inspect_ammo_test.vpk"

"%VPK%" "%SRC%"

if not exist "%HERE%addon.vpk" (
	echo.
	echo  ERROR: vpk.exe did not produce addon.vpk.
	goto :fail
)

ren "%HERE%addon.vpk" "ebf_inspect_ammo_test.vpk"

echo.
echo  ------------------------------------------------
echo   SUCCESS
echo.
echo   Built: %HERE%ebf_inspect_ammo_test.vpk
echo.
echo   Now copy that .vpk into:
echo     ...\Steam\steamapps\common\Left 4 Dead 2\left4dead2\addons\
echo.
echo   Then start the game, load a map, and hold E + tap R.
echo   Diagnostics in the developer console:
echo     script EBFInspectAmmo.Status()
echo  ------------------------------------------------
echo.
pause
exit /b 0

:fail
echo.
echo  Build failed. Nothing was written.
echo.
pause
exit /b 1
