@echo off

REM =========================
REM Author:          Jon Zeolla (JZeolla)
REM Last update:     2015-11-16
REM File Type:       Windows Batch File
REM Version:         1.0
REM Repository:      https://github.com/JonZeolla/Development
REM Description:     This is a batch file to retrieve Windows wireless profile passwords
REM
REM Notes
REM - Anything that has a placeholder value is tagged with TODO
REM
REM =========================

:CLEAR
CLS

:NOCLEAR
ECHO 1.  Retrieve the stored key of a profile
ECHO 2.  Show wireless profiles

:EVAL_CHOICES
SET CHOICE=
SET /P CHOICE=(1-2):  
IF NOT '%CHOICE%'=='' SET CHOICE=%CHOICE:~0,1%
IF '%CHOICE%' == '1' GOTO RETRIEVE_STORED_KEY
IF '%CHOICE%' == '2' GOTO SHOW_WIRELESS_PROFILES
IF '%CHOICE%' == 'e' GOTO END
IF '%CHOICE%' == 'E' GOTO END
IF '%CHOICE%' == 'q' GOTO END
IF '%CHOICE%' == 'Q' GOTO END
IF '%CHOICE%' == 'C' GOTO CLEAR
IF '%CHOICE%' == 'c' GOTO CLEAR

:ERROR
ECHO.
ECHO.
ECHO.
ECHO.
ECHO.
ECHO.
ECHO.
ECHO.
ECHO.
ECHO.
ECHO.
ECHO Error detected.
ECHO.
ECHO.
ECHO.
GOTO NOCLEAR

:RETRIEVE_STORED_KEY
REM Retrieve the stored key of a profile
set /p ssid="Enter the SSID to retrieve the key from: "
netsh wlan show profiles name=%ssid% key=clear
set ERROR=%ERRORLEVEL%
IF NOT %ERROR%==0 GOTO ERROR
GOTO NOCLEAR

:SHOW_WIRELESS_PROFILES
REM Show Wireless Profiles
netsh wlan show profiles
set ERROR=%ERRORLEVEL%
IF NOT %ERROR%==0 GOTO ERROR
ECHO.
GOTO NOCLEAR

:END
EXIT
