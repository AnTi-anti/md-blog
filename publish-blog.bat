@echo off
setlocal
chcp 65001 >nul
title GitHub Blog Publish

set "SCRIPT_DIR=%~dp0"
cd /d "%SCRIPT_DIR%"

echo.
echo ========================================
echo   GitHub Blog Manual Publish
echo ========================================
echo.
echo Project: %CD%
echo Time: %date% %time%
echo.
echo Running publish script...
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%scripts\publish-once.ps1"
set "EXIT_CODE=%ERRORLEVEL%"

echo.
if "%EXIT_CODE%"=="0" (
  echo Publish finished and push succeeded.
  echo If new changes were found, GitHub Pages will update in about 1-2 minutes.
) else (
  echo Publish failed with exit code %EXIT_CODE%.
  echo The commit or push did not complete correctly.
  echo Check the messages above for the exact error.
)

echo.
echo Press any key to close this window.
pause >nul
exit /b %EXIT_CODE%
