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

if !FOUNDCOUNT!==0 (
	echo  ERROR: No source folder found.
	echo  Expected a subfolder next to this script containing addoninfo.txt.
	goto :fail
)

if !FOUNDCOUNT! GTR 1 (
	echo  ERROR: Found !FOUNDCOUNT! folders containing addoninfo.txt.
	echo  Keep only one addon source folder next to this script.
	goto :fail
)

REM SRC/SRCNAME were also set inside the loop; promote them out of it.
set "SRC=!SRC!"
set "SRCNAME=!SRCNAME!"

REM --- Sanity-check the required layout -------------------------------------
if not exist "!SRC!\scripts\vscripts\ebf_inspect_ammo.nut" (
	echo  ERROR: "!SRCNAME!\scripts\vscripts\ebf_inspect_ammo.nut" is missing.
	goto :fail
)

if not exist "!SRC!\scripts\vscripts\mapspawn_addon.nut" (
	echo  ERROR: "!SRCNAME!\scripts\vscripts\mapspawn_addon.nut" is missing.
	goto :fail
)

REM --- Locate vpk.exe -------------------------------------------------------
set "VPK="

REM 1) Common Steam library locations on every drive letter.
for %%L in (C D E F G H I J K) do (
	for %%S in (
		"%%L:\Program Files (x86)\Steam"
		"%%L:\Program Files\Steam"
		"%%L:\Steam"
		"%%L:\SteamLibrary"
		"%%L:\Games\Steam"
		"%%L:\Games\SteamLibrary"
		"%%L:\SteamGames"
	) do (
		if not defined VPK (
			if exist "%%~S\steamapps\common\Left 4 Dead 2\bin\vpk.exe" (
				set "VPK=%%~S\steamapps\common\Left 4 Dead 2\bin\vpk.exe"
			)
		)
	)
)

REM 2) Ask Windows where Steam is installed, then read its library list.
if not defined VPK (
	for /f "tokens=2,*" %%A in (
		'reg query "HKCU\Software\Valve\Steam" /v SteamPath 2^>nul ^| find "SteamPath"'
	) do (
		set "STEAMPATH=%%B"
	)
)

if not defined VPK if defined STEAMPATH (
	set "STEAMPATH=!STEAMPATH:/=\!"
	if exist "!STEAMPATH!\steamapps\common\Left 4 Dead 2\bin\vpk.exe" (
		set "VPK=!STEAMPATH!\steamapps\common\Left 4 Dead 2\bin\vpk.exe"
	)
	REM Additional libraries are listed in libraryfolders.vdf.
	if not defined VPK if exist "!STEAMPATH!\steamapps\libraryfolders.vdf" (
		for /f "tokens=2 delims=	 " %%V in (
			'findstr /i "\"path\"" "!STEAMPATH!\steamapps\libraryfolders.vdf"'
		) do (
			set "LIB=%%~V"
			set "LIB=!LIB:\\=\!"
			if not defined VPK if exist "!LIB!\steamapps\common\Left 4 Dead 2\bin\vpk.exe" (
				set "VPK=!LIB!\steamapps\common\Left 4 Dead 2\bin\vpk.exe"
			)
		)
	)
)

REM 3) Last resort: ask the user, and validate what they give us.
if not defined VPK (
	echo  Could not find vpk.exe automatically.
	echo.
	echo  It lives in your Left 4 Dead 2 install, at:
	echo      ...\Left 4 Dead 2\bin\vpk.exe
	echo.
	echo  Tip: open that bin folder, then drag vpk.exe onto this window.
	echo  Do NOT drag this project folder - it must be vpk.exe itself.
	echo.
)

:askvpk
if not defined VPK (
	set "VPK="
	set /p "VPK=Path to vpk.exe (or press Enter to cancel): "

	REM Strip surrounding quotes that drag-and-drop may add.
	if defined VPK set "VPK=!VPK:"=!"

	if not defined VPK (
		echo.
		echo  Cancelled - no path given.
		goto :fail
	)

	REM If a folder was given, try to find vpk.exe inside it.
	if exist "!VPK!\" (
		if exist "!VPK!\vpk.exe" set "VPK=!VPK!\vpk.exe"
	)
	if exist "!VPK!\" (
		if exist "!VPK!\bin\vpk.exe" set "VPK=!VPK!\bin\vpk.exe"
	)
	if exist "!VPK!\" (
		echo.
		echo  That is a folder, not vpk.exe, and it contains no vpk.exe:
		echo    !VPK!
		echo  Please point at the vpk.exe file itself.
		echo.
		set "VPK="
		goto :askvpk
	)

	if not exist "!VPK!" (
		echo.
		echo  No such file:
		echo    !VPK!
		echo.
		set "VPK="
		goto :askvpk
	)

	REM Must actually be vpk.exe, not some other file.
	for %%F in ("!VPK!") do set "VPKNAME=%%~nxF"
	if /i not "!VPKNAME!"=="vpk.exe" (
		echo.
		echo  That is "!VPKNAME!", not vpk.exe.
		echo.
		set "VPK="
		goto :askvpk
	)
)

if not exist "!VPK!" (
	echo  ERROR: vpk.exe not found at "!VPK!".
	goto :fail
)

echo  Using vpk.exe : !VPK!
echo  Source folder : !SRCNAME!
echo  Output        : !SRCNAME!.vpk
echo.

REM vpk.exe writes "<foldername>.vpk" into the PARENT of the packed folder,
REM which is this script's folder.
if exist "%HERE%!SRCNAME!.vpk" del /q "%HERE%!SRCNAME!.vpk"

"!VPK!" "!SRC!"

if not exist "%HERE%!SRCNAME!.vpk" (
	echo.
	echo  ERROR: vpk.exe did not produce "!SRCNAME!.vpk".
	goto :fail
)

echo.
echo  ------------------------------------------------
echo   SUCCESS
echo.
echo   Built: %HERE%!SRCNAME!.vpk
echo.
echo   Now copy that .vpk into:
echo     ...\Steam\steamapps\common\Left 4 Dead 2\left4dead2\addons\
echo.
echo   Then start the game, load a map, and hold E + tap R.
echo   Diagnostics in the developer console:
echo     script EBFInspectAmmo.Status^(^)
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
