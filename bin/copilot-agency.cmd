@echo off
pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0copilot-profile-launch.ps1" agency %*
exit /b %ERRORLEVEL%
