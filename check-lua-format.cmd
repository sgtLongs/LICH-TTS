@echo off
where stylua >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo StyLua is not installed or is not available on PATH.
    echo See https://github.com/JohnnyMorganz/StyLua#installation
    exit /b 1
)

if "%~1"=="" (
    echo Usage: check-lua-format.cmd ^<file-or-directory^> [...]
    echo Check only canonical, non-generated Lua files changed for the task.
    exit /b 2
)

stylua --check --respect-ignores %*
exit /b %ERRORLEVEL%
