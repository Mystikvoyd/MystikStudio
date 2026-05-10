@echo off
set SCRIPT_DIR=%~dp0
start "Story Dashboard Server" powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%Start-StoryDashboard.ps1" -Port 8787
timeout /t 1 /nobreak >nul
start "" "http://127.0.0.1:8787/"
