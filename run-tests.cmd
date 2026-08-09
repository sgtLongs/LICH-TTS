@echo off
set "DOTNET_CLI_HOME=%TEMP%\LICH-TTS-dotnet"
set "DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1"
set "DOTNET_CLI_TELEMETRY_OPTOUT=1"
set "DOTNET_NOLOGO=1"
dotnet restore "%~dp0tests\runner\LichTts.TestRunner.csproj" --locked-mode
if %ERRORLEVEL% neq 0 exit /b %ERRORLEVEL%

dotnet run --project "%~dp0tests\runner\LichTts.TestRunner.csproj" --configuration Release --no-restore -- %*
exit /b %ERRORLEVEL%
