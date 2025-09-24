@echo off
echo Pet Battle Level Up Monitor - Data Parser
echo ==========================================
echo.

REM Check if tempdata.lua exists
if not exist "tempdata.lua" (
    echo ERROR: tempdata.lua not found in current directory
    echo Please copy your tempdata.lua file to this folder first
    echo.
    pause
    exit /b 1
)

REM Check if Lua is available
lua -v >nul 2>&1
if errorlevel 1 (
    echo WARNING: Lua interpreter not found in PATH
    echo Trying to run with Windows Script Host instead...
    echo.

    REM Alternative: Try to run with cscript if available
    cscript //NoLogo parse_temp_data.vbs 2>nul
    if errorlevel 1 (
        echo ERROR: Neither Lua nor VBScript interpreter available
        echo Please install Lua or use the manual method
        echo.
        pause
        exit /b 1
    )
) else (
    echo Running Lua parser...
    echo.
    lua parse_temp_data.lua
)

echo.
if exist "savedData.lua" (
    echo ✅ Success! Generated savedData.lua
    echo You can now copy this data to your WoW SavedVariables
) else (
    echo ❌ Failed to generate savedData.lua
)

echo.
pause