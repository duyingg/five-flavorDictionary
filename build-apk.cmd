@echo off
setlocal
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0build-apk.ps1" %*
set "buildExitCode=%ERRORLEVEL%"
if not "%buildExitCode%"=="0" (
    echo.
    echo Build script stopped with exit code %buildExitCode%. The error is shown above.
    if not defined CI pause
)
exit /b %buildExitCode%
