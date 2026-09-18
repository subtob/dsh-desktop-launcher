@echo off
rem ===================================================================
rem  ONE-CLICK INSTALLER - creates the DSH shortcut on your Desktop
rem  and in the Start Menu.
rem
rem  Just double-click this file. No administrator rights needed.
rem  If writing to the Desktop is denied, it will offer to retry with
rem  elevation (a UAC prompt appears - click Yes).
rem
rem  The window closes automatically when the work is done; the same
rem  information is appended to Install-Log.txt in this folder.
rem
rem  NOTE: this FILE NAME is Chinese for convenience, but its CONTENT
rem  must stay pure ASCII. This console runs code page 936 (GBK), and
rem  UTF-8 non-ASCII text inside a .bat corrupts quote pairing and
rem  aborts the script on line 1 with no error output. See launch.bat.
rem ===================================================================
setlocal
title Create DSH shortcut

echo.
echo   Creating the DSH shortcut on your Desktop and Start Menu...
echo.

rem  The window closes automatically when the work is done.
rem  Details are appended to Install-Log.txt in this folder if you need them.
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-Shortcut.ps1" -StartMenu
exit /b 0
