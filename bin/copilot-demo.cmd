@echo off
pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0copilot-profile-launch.ps1" demo %*
exit /b %ERRORLEVEL%
