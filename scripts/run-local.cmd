@echo off
setlocal
cd /d %~dp0\..

echo Killing any process on port 5174...
for /f "tokens=5" %%a in ('netstat -ano ^| findstr :5174 ^| findstr LISTENING') do taskkill /PID %%a /F >nul 2>&1

echo Killing any running rightapply.exe (to avoid linker lock)...
taskkill /IM rightapply.exe /F >nul 2>&1

echo Starting local API server...
start "rightapply-api" cmd /k "cd /d %CD%\api && npm run dev"

echo Cleaning Flutter build artifacts (best-effort)...
rmdir /s /q build >nul 2>&1
call flutter clean
if errorlevel 1 echo flutter clean failed, continuing...

echo Restoring packages...
call flutter pub get
if errorlevel 1 echo flutter pub get failed, attempting to continue...

echo Building Flutter Windows app...
call flutter build windows
if errorlevel 1 echo flutter build failed, will try to run existing executable if present...

echo Launching app...
if exist build\windows\x64\runner\Release\rightapply.exe (
	start "" "build\windows\x64\runner\Release\rightapply.exe"
) else if exist build\windows\x64\runner\Debug\rightapply.exe (
	start "" "build\windows\x64\runner\Debug\rightapply.exe"
) else (
	echo ERROR: No Windows executable found. Please run: flutter build windows
)

endlocal
