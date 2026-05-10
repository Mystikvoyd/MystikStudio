@echo off
set SCRIPT_DIR=%~dp0
start "Story Dashboard App" powershell -STA -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%Start-StoryDashboardApp.ps1"
