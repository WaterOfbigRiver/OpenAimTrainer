@echo off
setlocal
rem ============================================================
rem  Open Aim Trainer - one click launcher (runs the game)
rem  Edit GODOT_CUSTOM below if your Godot is in another place.
rem ============================================================

set "PROJ=%~dp0"
set "PROJ=%PROJ:~0,-1%"
set "GODOT="

rem 1) user-defined path (highest priority)
if exist "%GODOT_CUSTOM%" set "GODOT=%GODOT_CUSTOM%"

rem 2) common locations, checked in order
if not defined GODOT if exist "K:\Godot_v4.7-stable_win64\Godot.exe" set "GODOT=K:\Godot_v4.7-stable_win64\Godot.exe"
if not defined GODOT if exist "F:\Godot_v4.7-stable_win64\Godot_v4.7-stable_win64.exe" set "GODOT=F:\Godot_v4.7-stable_win64\Godot_v4.7-stable_win64.exe"
if not defined GODOT if exist "M:\下载\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe" set "GODOT=M:\下载\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe"

if not defined GODOT (
  echo [ERROR] Godot executable not found.
  echo Edit this file and set the correct path, for example:
  echo   set "GODOT=C:\path\to\Godot.exe"
  pause
  exit /b 1
)

echo Project : %PROJ%
echo Engine  : %GODOT%
echo Starting Open Aim Trainer ...
start "" "%GODOT%" --path "%PROJ%"
endlocal
