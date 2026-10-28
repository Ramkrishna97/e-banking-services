@echo off
setlocal
if /I "%~1"=="--check" goto check
if /I "%~1"=="-Stop" goto stop
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\start.ps1" %*
set "RESULT=%ERRORLEVEL%"
pause
exit /b %RESULT%
:check
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\start.ps1" -Check
exit /b %ERRORLEVEL%
:stop
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\start.ps1" -Stop
exit /b %ERRORLEVEL%
