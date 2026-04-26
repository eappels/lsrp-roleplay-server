@echo off
setlocal

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0StartServer.ps1"
exit /b %ERRORLEVEL%