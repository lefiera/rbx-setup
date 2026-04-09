@echo off
setlocal enabledelayedexpansion

set "VERSION="
set "OUTPUT="

:parse
if "%~1"=="" goto endparse
if /i "%~1"=="--version" (
    set "VERSION=%~2"
    shift & shift
    goto parse
)
if /i "%~1"=="--output" (
    set "OUTPUT=%~2"
    shift & shift
    goto parse
)
shift
goto parse
:endparse

if "%VERSION%"=="" (
    echo [!] Error: --version is required.
    echo Usage: rdd.bat --version version-xxxxxxxxxxxxxxxx [--output C:\path\to\folder]
    exit /b 1
)

if "%OUTPUT%"=="" (
    set "OUTPUT=%~dp0%VERSION%"
) else (
    set "OUTPUT=%OUTPUT%\%VERSION%"
)

set "HOST=https://setup-aws.rbxcdn.com"
set "VERSION_PATH=%HOST%/%VERSION%-"
set "UA=RobloxPlayer/1.0 (Windows)"

echo [*] Fetching rbxPkgManifest for %VERSION% @ LIVE...

if exist "%OUTPUT%" rmdir /s /q "%OUTPUT%"
mkdir "%OUTPUT%"

set "MANIFEST_URL=%VERSION_PATH%rbxPkgManifest.txt"
set "MANIFEST_TMP=%TEMP%\rdd_manifest_%RANDOM%.txt"

curl -s -L -A "%UA%" -o "%MANIFEST_TMP%" "%MANIFEST_URL%"
if errorlevel 1 (
    echo [!] Failed to fetch rbxPkgManifest.
    exit /b 1
)

set /p FIRST_LINE=<"%MANIFEST_TMP%"
if not "%FIRST_LINE%"=="v0" (
    echo [!] Unknown manifest format: %FIRST_LINE%
    del "%MANIFEST_TMP%"
    exit /b 1
)

findstr /i "RobloxApp.zip" "%MANIFEST_TMP%" >nul
if errorlevel 1 (
    echo [!] RobloxApp.zip not found in manifest. Is this a WindowsPlayer version?
    del "%MANIFEST_TMP%"
    exit /b 1
)

set "PKGS="
set "PKG_COUNT=0"
for /f "usebackq tokens=*" %%L in ("%MANIFEST_TMP%") do (
    set "LINE=%%L"
    if "!LINE:~-4!"==".zip" (
        set "PKGS=!PKGS! %%L"
        set /a PKG_COUNT+=1
    )
)

echo [+] Found %PKG_COUNT% packages to download.
echo [+] Output directory: %OUTPUT%

(
echo ^<?xml version="1.0" encoding="UTF-8"?^>
echo ^<Settings^>
echo     ^<ContentFolder^>content^</ContentFolder^>
echo     ^<BaseUrl^>http://www.roblox.com^</BaseUrl^>
echo ^</Settings^>
) > "%OUTPUT%\AppSettings.xml"

del "%MANIFEST_TMP%"

set "IDX=0"
for %%P in (%PKGS%) do (
    set /a IDX+=1
    set "PKG=%%P"
    set "URL=%VERSION_PATH%%%P"
    set "TMP=%TEMP%\rdd_pkg_%RANDOM%_%%P"

    echo [+] Downloading %%P ^(!IDX!/%PKG_COUNT%^)...
    curl -L -A "%UA%" --progress-bar -o "!TMP!" "!URL!"
    if errorlevel 1 (
        echo [!] Failed to download %%P
        exit /b 1
    )

    set "EXTRACT_ROOT=__NONE__"

    if "%%P"=="RobloxApp.zip"                      set "EXTRACT_ROOT="
    if "%%P"=="redist.zip"                          set "EXTRACT_ROOT="
    if "%%P"=="WebView2.zip"                        set "EXTRACT_ROOT="
    if "%%P"=="shaders.zip"                         set "EXTRACT_ROOT=shaders"
    if "%%P"=="ssl.zip"                             set "EXTRACT_ROOT=ssl"
    if "%%P"=="WebView2RuntimeInstaller.zip"        set "EXTRACT_ROOT=WebView2RuntimeInstaller"
    if "%%P"=="content-avatar.zip"                  set "EXTRACT_ROOT=content\avatar"
    if "%%P"=="content-configs.zip"                 set "EXTRACT_ROOT=content\configs"
    if "%%P"=="content-fonts.zip"                   set "EXTRACT_ROOT=content\fonts"
    if "%%P"=="content-sky.zip"                     set "EXTRACT_ROOT=content\sky"
    if "%%P"=="content-sounds.zip"                  set "EXTRACT_ROOT=content\sounds"
    if "%%P"=="content-textures2.zip"               set "EXTRACT_ROOT=content\textures"
    if "%%P"=="content-models.zip"                  set "EXTRACT_ROOT=content\models"
    if "%%P"=="content-platform-fonts.zip"          set "EXTRACT_ROOT=PlatformContent\pc\fonts"
    if "%%P"=="content-platform-dictionaries.zip"   set "EXTRACT_ROOT=PlatformContent\pc\shared_compression_dictionaries"
    if "%%P"=="content-terrain.zip"                 set "EXTRACT_ROOT=PlatformContent\pc\terrain"
    if "%%P"=="content-textures3.zip"               set "EXTRACT_ROOT=PlatformContent\pc\textures"
    if "%%P"=="extracontent-luapackages.zip"        set "EXTRACT_ROOT=ExtraContent\LuaPackages"
    if "%%P"=="extracontent-translations.zip"       set "EXTRACT_ROOT=ExtraContent\translations"
    if "%%P"=="extracontent-models.zip"             set "EXTRACT_ROOT=ExtraContent\models"
    if "%%P"=="extracontent-textures.zip"           set "EXTRACT_ROOT=ExtraContent\textures"
    if "%%P"=="extracontent-places.zip"             set "EXTRACT_ROOT=ExtraContent\places"

    if "!EXTRACT_ROOT!"=="__NONE__" (
        echo [*] %%P not in extraction roots, copying to output root.
        copy /y "!TMP!" "%OUTPUT%\%%P" >nul
    ) else (
        if not "!EXTRACT_ROOT!"=="" (
            if not exist "%OUTPUT%\!EXTRACT_ROOT!" mkdir "%OUTPUT%\!EXTRACT_ROOT!"
        )
        echo [+] Extracting %%P...
        powershell -NoProfile -Command "Expand-Archive -LiteralPath '!TMP!' -DestinationPath '%OUTPUT%\!EXTRACT_ROOT!' -Force"
        echo [+] Extracted %%P
    )

    del "!TMP!" 2>nul
)

echo.
echo [+] Downloaded Roblox
