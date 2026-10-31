@echo off
cd /d "%~dp0"
net session >nul 2>nul
if errorlevel 1 (
  echo Asking for administrator rights...
  powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)
where node >nul 2>nul || (echo Install Node.js LTS from https://nodejs.org first. & pause & exit /b 1)
set ISCC=%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe
if not exist "%ISCC%" set ISCC=%ProgramFiles%\Inno Setup 6\ISCC.exe
if not exist "%ISCC%" set ISCC=%LOCALAPPDATA%\Programs\Inno Setup 6\ISCC.exe
if not exist "%ISCC%" (echo Install Inno Setup 6 from https://jrsoftware.org/isdl.php first. & pause & exit /b 1)
set CSC_IDENTITY_AUTO_DISCOVERY=false
rmdir /s /q "%LOCALAPPDATA%\electron-builder\Cache\winCodeSign" >nul 2>nul
echo Step 1/3: npm install...
call npm install
if errorlevel 1 (echo npm install failed & pause & exit /b 1)
echo Step 2/3: building the Electron app...
rmdir /s /q dist >nul 2>nul
call npm run pack
if errorlevel 1 (echo build failed & pause & exit /b 1)
rmdir /s /q installer\app >nul 2>nul
xcopy /e /i /y /q "dist\win-unpacked" "installer\app" >nul
echo Step 3/3: building the installer...
"%ISCC%" installer\MinoChat.iss
if errorlevel 1 (pause & exit /b 1)
echo.
echo DONE: installer\Output\MinoChat-Setup.exe  (installs the real Electron app)
start "" "%~dp0installer\Output"
pause
