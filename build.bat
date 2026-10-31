@echo off
cd /d "%~dp0"
rem --- need administrator rights once: electron-builder unpacks tools that contain symbolic links ---
net session >nul 2>nul
if errorlevel 1 (
  echo Asking for administrator rights...
  powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)
where node >nul 2>nul || (echo Install Node.js LTS from https://nodejs.org first, then run this file again. & pause & exit /b 1)
set CSC_IDENTITY_AUTO_DISCOVERY=false
echo Cleaning broken cache from earlier attempts...
rmdir /s /q "%LOCALAPPDATA%\electron-builder\Cache\winCodeSign" >nul 2>nul
echo Step 1/2: installing (a few minutes, needs internet)...
call npm install
if errorlevel 1 (echo npm install failed & pause & exit /b 1)
echo Step 2/2: building MinoChat.exe ...
call npm run dist
if errorlevel 1 (echo build failed & pause & exit /b 1)
echo.
echo DONE. Files are in the "dist" folder:
echo   MinoChat-Setup-3.0.0.exe         - installer
echo   MinoChat-Portable-3.0.0.exe - runs without installing
start "" "%~dp0dist"
pause
