@echo off
REM ============================================================================
REM  [TEST] Weapon Inspect Ammo Check -- Windows VPK build script
REM
REM  Packs the addon source folder into a .vpk and tells you where to copy it.
REM
REM  The source folder is auto-detected: it is whichever folder next to this
REM  script contains addoninfo.txt. So you may freely rename "addon" to
REM  anything you like (e.g. test_ammo_inspect) and this script still works.
REM  The resulting .vpk is named after that folder.
REM
REM  Usage: just double-click this file.
REM ============================================================================

setlocal enabledelayedexpansion

set "HERE=%~dp0"

echo.
echo  [TEST] Weapon Inspect Ammo Check -- VPK builder
echo  ------------------------------------------------

REM --- Locate the source folder (any subfolder holding addoninfo.txt) --------
set "SRC="
set "SRCNAME="
set "FOUNDCOUNT=0"

for /d %%D in ("%HERE%*") do (
	if exist "%%~fD\addoninfo.txt" (
		set /a FOUNDCOUNT+=1
		set "SRC=%%~fD"
		set "SRCNAME=%%~nxD"
	)
)

if %FOUNDCOUNT%==0 (
	echo  ERROR: No source folder found.
	echo  Expected a subfolder next to this script containing addoninfo.txt.
	goto :fail
)

if %FOUNDCOUNT% GTR 1 (
	echo  ERROR: Found %FOUNDCOUNT% folders containing addoninfo.txt.
	echo  Keep only one addon source folder next to this script.
	goto :fail
)

REM --- Sanity-check the required layout -------------------------------------
if not exist "%SRC%\scripts\vscripts\ebf_inspect_ammo.nut" (
	echo  ERROR: "%SRCNAME%\scripts\vscripts\ebf_inspect_ammo.nut" is missing.
	goto :fail
)

if not exist "%SRC%\scripts\vscripts\mapspawn_addon.nut" (
	echo  ERROR: "%SRCNAME%\scripts\vscripts\mapspawn_addon.nut" is missing.
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
echo  Source folder : %SRCNAME%
echo  Output        : %SRCNAME%.vpk
echo.

REM vpk.exe writes "<foldername>.vpk" into the PARENT of the packed folder,
REM which is this script's folder.
if exist "%HERE%%SRCNAME%.vpk" del /q "%HERE%%SRCNAME%.vpk"

"%VPK%" "%SRC%"

if not exist "%HERE%%SRCNAME%.vpk" (
	echo.
	echo  ERROR: vpk.exe did not produce "%SRCNAME%.vpk".
	goto :fail
)

echo.
echo  ------------------------------------------------
echo   SUCCESS
echo.
echo   Built: %HERE%%SRCNAME%.vpk
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
