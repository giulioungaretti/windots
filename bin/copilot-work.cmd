@echo off
pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0copilot-profile-launch.ps1" work %*
exit /b %ERRORLEVEL%
