@ECHO OFF

REM =========================
REM Author:          Jon Zeolla (JZeolla)
REM Last update:     2015-09-19
REM File Type:       Windows Batch File
REM Version:         1.1
REM Repository:      https://github.com/JonZeolla/Development
REM Description:     This is a batch file to prompt for a back up of a USB drive as soon as it's plugged in
REM
REM Notes
REM - Anything that has a placeholder value is tagged with TODO
REM
REM =========================

ECHO Would you like to back up?  Y/N
ECHO.

SET CHOICE=
SET /P CHOICE=(Y/N):  
IF NOT '%CHOICE%'=='' SET CHOICE=%CHOICE:~0,1%
IF '%CHOICE%' == 'Y' GOTO START
IF '%CHOICE%' == 'y' GOTO START
IF '%CHOICE%' == 'N' GOTO END
IF '%CHOICE%' == 'n' GOTO END

:START
for /f "tokens=1* delims=" %%a in ('date /T') do set datestr=%%a
robocopy F: "X:\Portable\XYZ Backup\%datestr%" /MIR /XO /XF pagefile.sys /XD $* RECYCLER* system* /LOG:"X:\Portable\XYZ Backup\XYZ_Backup.log" /TEE

%SystemRoot%\explorer.exe "X:\Portable\XYZ Backup"
%SystemRoot%\explorer.exe "F:"

:END
EXIT
