@echo off
rem ===================================================================
rem  DSH Quick Launcher  (DeepSeek Harness Web UI)
rem
rem  What it does:
rem    1. opens a PowerShell window
rem    2. runs: npx @deepseek-ai/dsh web --port <PORT>
rem
rem  Usage:
rem    double-click this file, or the generated shortcut, or
rem    launch.bat --port 8080
rem
rem  IMPORTANT: this file is pure ASCII by design.
rem  This console runs code page 936 (GBK); any UTF-8 Chinese text
rem  inside a .bat gets mis-decoded and aborts the script instantly.
rem  All Chinese text and path names live in Launch-DSH.ps1 instead,
rem  which PowerShell reads as UTF-8.
rem ===================================================================
setlocal
set "PORT=3080"
title DSH Launcher

rem ---- optional: --port <n> -------------------------------------------------
if /i "%~1"=="--port" if not "%~2"=="" set "PORT=%~2"

echo [i] Starting PowerShell: npx @deepseek-ai/dsh web --port %PORT%
start "DSH - DeepSeek Harness" powershell.exe -NoLogo -NoExit -ExecutionPolicy Bypass -File "%~dp0Launch-DSH.ps1" -Port %PORT%
exit /b 0
