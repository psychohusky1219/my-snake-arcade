@echo off
setlocal
rem Execution policy applies to this process only; no system policy is changed.
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Publish-GitHub.ps1"
set "RESULT=%ERRORLEVEL%"
echo.
pause
exit /b %RESULT%
