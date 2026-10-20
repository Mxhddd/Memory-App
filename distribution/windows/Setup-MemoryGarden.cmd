@echo off
rem Double-click to get this laptop ready for Memory Garden (opens a PowerShell helper).
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Setup-MemoryGarden.ps1"
if errorlevel 1 pause
