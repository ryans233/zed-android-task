@echo off
rem zed-android-task.cmd - Windows shim for the bash implementation.
rem
rem Works from cmd.exe, PowerShell and Zed tasks (Zed runs tasks through
rem PowerShell on Windows). Put this directory on PATH, or call the file by
rem full path. Requires Git for Windows (bash.exe).
rem
rem Override interpreter discovery with ZED_ANDROID_TASK_BASH=<path to bash.exe>.

setlocal EnableExtensions

set "SCRIPT=%~dp0zed-android-task"
set "BASH="

rem %ProgramFiles(x86)% contains parentheses, so expand it before any block.
set "PF86=%ProgramFiles(x86)%"
set "PF64=%ProgramFiles%"
set "GITLOCAL=%LOCALAPPDATA%\Programs\Git"

if defined ZED_ANDROID_TASK_BASH set "BASH=%ZED_ANDROID_TASK_BASH%"
if not defined BASH if exist "%PF64%\Git\bin\bash.exe" set "BASH=%PF64%\Git\bin\bash.exe"
if not defined BASH if exist "%PF86%\Git\bin\bash.exe" set "BASH=%PF86%\Git\bin\bash.exe"
if not defined BASH if exist "%GITLOCAL%\bin\bash.exe" set "BASH=%GITLOCAL%\bin\bash.exe"

rem Fallback: `where bash`, rejecting the WSL launcher in System32.
if not defined BASH (
    for /f "delims=" %%G in ('where bash 2^>nul') do (
        if not defined BASH (
            echo %%G | findstr /i /c:"\System32\bash.exe" >nul || set "BASH=%%G"
        )
    )
)

if not defined BASH (
    echo zed-android-task: Git Bash not found. 1>&2
    echo   Install Git for Windows, or set ZED_ANDROID_TASK_BASH to bash.exe. 1>&2
    exit /b 127
)

if not exist "%BASH%" (
    echo zed-android-task: bash not found at "%BASH%". 1>&2
    exit /b 127
)

"%BASH%" "%SCRIPT%" %*
exit /b %ERRORLEVEL%
