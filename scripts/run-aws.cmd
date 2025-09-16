@echo off
setlocal
cd /d %~dp0\..

if "%API_BASE%"=="" (
  echo Usage: set API_BASE=https://<api-id>.execute-api.<region>.amazonaws.com/Prod && scripts\run-aws.cmd
  exit /b 1
)

echo Building Flutter Windows app for AWS API_BASE=%API_BASE% ...
echo Killing any running rightapply.exe (to avoid linker lock)...
taskkill /IM rightapply.exe /F >nul 2>&1

REM Give the OS a moment to release file locks, then try to delete the exe if it still exists
set _retries=5
:wait_unlock
if exist build\windows\x64\runner\Release\rightapply.exe (
  del /f /q build\windows\x64\runner\Release\rightapply.exe >nul 2>&1
  if exist build\windows\x64\runner\Release\rightapply.exe (
    timeout /t 1 >nul
    set /a _retries=%_retries%-1
    if %_retries% gtr 0 goto wait_unlock
  )
)

call flutter clean
call flutter pub get
call flutter build windows --dart-define=API_BASE=%API_BASE%

echo Launching app...
start "" "build\windows\x64\runner\Release\rightapply.exe"

endlocal
