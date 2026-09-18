@echo off
pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\copilot-profile.ps1" agency %*
exit /b %ERRORLEVEL%
