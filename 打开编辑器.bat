@echo off
setlocal
rem ============================================================
rem  Open Aim Trainer - open the project in the Godot EDITOR
rem  (use this when you want to edit scenes / scripts, then F5)
rem ============================================================

set "PROJ=%~dp0"
set "PROJ=%PROJ:~0,-1%"
set "GODOT="

if exist "%GODOT_CUSTOM%" set "GODOT=%GODOT_CUSTOM%"
if not defined GODOT if exist "K:\Godot_v4.7-stable_win64\Godot.exe" set "GODOT=K:\Godot_v4.7-stable_win64\Godot.exe"
if not defined GODOT if exist "F:\Godot_v4.7-stable_win64\Godot_v4.7-stable_win64.exe" set "GODOT=F:\Godot_v4.7-stable_win64\Godot_v4.7-stable_win64.exe"
if not defined GODOT if exist "M:\下载\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe" set "GODOT=M:\下载\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe"

if not defined GODOT (
  echo [ERROR] Godot executable not found. Edit this file and set GODOT path.
  pause
  exit /b 1
)

echo Project : %PROJ%
echo Engine  : %GODOT%
echo Opening Godot editor ...
start "" "%GODOT%" -e --path "%PROJ%"
endlocal
