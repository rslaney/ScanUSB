@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "CLAMAV=C:\Program Files\ClamAV"
set "DB=%LOCALAPPDATA%\ClamAV\Database"
if not exist "%DB%" mkdir "%DB%"

rem Store scan report on this computer
set "LOGDIR=%LOCALAPPDATA%\ClamAV"
if not exist "%LOGDIR%" mkdir "%LOGDIR%"

@REM  Get timestamp to keep log names separate
for /f %%T in ('powershell.exe -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss_fff"') do set "TIMESTAMP=%%T"
set "LOG=%LOGDIR%\USB-scan_%TIMESTAMP%.log"

echo Updating virus definitions...
"%CLAMAV%\freshclam.exe" --config-file="C:\Program Files\ClamAV\freshclam.conf" --datadir="%DB%" >nul 2>&1
if errorlevel 1 (
	echo Virus definition update failed. This just means that you don't have the latest info. 
	echo If you are not connected to the internet, connect and run this again. 
	echo If the issue persists, call the help desk. 
	@REM Help desk: remove the `>nul 2>&1` to get any error messages printed to screen
	@REM Help desk: if the issue persists, comment out the `exit` command below and run with stale virus definitions
	pause
	exit /b 2
) else (
	echo Virus definitions all up to date. 
	echo.
)


rem Find drive letters belonging to USB-connected ports.
set "DRIVES="
for /f "delims=" %%D in ('powershell.exe -NoProfile -Command "$ErrorActionPreference='Stop'; Get-Disk | Where-Object { $_.BusType -eq 'USB' } | Get-Partition | Where-Object { $_.DriveLetter} | Select-Object -ExpandProperty DriveLetter"') do (set "DRIVES=!DRIVES! %%D")

if not defined DRIVES (
	echo No USB drive letters found.
	pause
	exit /b 2
)

echo USB drives found: !DRIVES!

@REM  Track detections and errors across scanned drives
set "FOUND=0"
set "FAILED=0"

 for %%D in (!DRIVES!) do (
	echo.
	echo Scanning %%D:\ ...

	"%CLAMAV%\clamscan.exe" --database="%DB%" --recursive --infected --log="%LOG%" "%%D:\."

	set "RESULT=!ERRORLEVEL!"
	if "!RESULT!"=="1" set "FOUND=1"
	if not "!RESULT!"=="0" if not "!RESULT!"=="1" set "FAILED=1"
 )


echo.
if "!FOUND!"=="1" echo ---------- MALWARE DETECTED. Review the scan report ----------
if "!FOUND!"=="1" echo.
if "!FAILED!"=="1" echo Scan error detected. Review the output and scan report.
if "!FOUND!!FAILED!!"=="00" echo Scan finished: no malware detected.

@REM  @REM The following gives the option to open the log file. 
@REM  @REMSuppressing as current command line output mirrors log file contents
@REM  set "OPENLOG="
@REM  set /p "OPENLOG=Press Enter to open the scan log, or type N and press Enter to exit: "
@REM  if not defined OPENLOG (
@REM  	if exist "%LOG%" (
@REM  		start "" notepad.exe "%LOG%"
@REM  	) else (
@REM  		echo Log file not found: "%LOG%"
@REM  	)
@REM  )

set "EXITCODE=0"
if "!FOUND!"=="1" set "EXITCODE=1"
if "!FAILED!"=="1" set "EXITCODE=2"

echo Report: "%LOG%"
pause
echo Confirm that you have the results and log file location? 
pause
exit /b !EXITCODE!
