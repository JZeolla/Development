@echo off

REM =========================
REM Author:          Jon Zeolla (JZeolla)
REM Last update:     2014-06-19
REM File Type:       Windows Batch File
REM Version:         1.0
REM Repository:      https://github.com/JonZeolla/Development
REM Description:     This is a batch file to configure Windows wireless interfaces using the 802.11 Ad Hoc mode
REM
REM Notes
REM - Anything that has a placeholder value is tagged with TODO
REM
REM =========================

:CLEAR
CLS

:NOCLEAR
ECHO 1.  Reconfigure and enable the Ad Hoc interface
ECHO 2.  Disable the Ad Hoc interface
ECHO 3.  Retrieve the Ad Hoc interface security details

:EVAL_CHOICES
SET CHOICE=
SET /P CHOICE=(1-5):  
IF NOT '%CHOICE%'=='' SET CHOICE=%CHOICE:~0,1%
IF '%CHOICE%' == '1' GOTO CONFIG_ADHOC_INTERFACE
IF '%CHOICE%' == '2' GOTO DISABLE_ADHOC_INTERFACE
IF '%CHOICE%' == '3' GOTO RETRIEVE_ADHOC_DETAILS
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

:CONFIG_ADHOC_INTERFACE
REM Reconfigure and enable the Ad Hoc interface
set /p ssid="Enter a SSID: "
set /p key="Enter a key (8-63 characters): "
ECHO.
netsh wlan set hostednetwork mode=allow ssid=%ssid% key=%key% keyUsage=persistent
set ERROR=%ERRORLEVEL%
IF NOT %ERROR%==0 GOTO ERROR
netsh wlan start hostednetwork
set ERROR=%ERRORLEVEL%
IF NOT %ERROR%==0 GOTO ERROR
ECHO.
ECHO Ad Hoc interface successfully configured and enabled.
GOTO NOCLEAR

:DISABLE_ADHOC_INTERFACE
REM Disable the Ad Hoc interface
ECHO Disabling the Ad Hoc interface...
netsh wlan set hostednetwork mode=disallow
set ERROR=%ERRORLEVEL%
IF NOT %ERROR%==0 GOTO ERROR
netsh wlan stop hostednetwork
set ERROR=%ERRORLEVEL%
IF NOT %ERROR%==0 GOTO ERROR
ECHO.
ECHO Ad Hoc interface successfully disabled.
ECHO.
ECHO.
GOTO NOCLEAR

:RETRIEVE_ADHOC_DETAILS
REM Retrieve the Ad Hoc interface security details
netsh wlan show hostednetwork setting=security
set ERROR=%ERRORLEVEL%
IF NOT %ERROR%==0 GOTO ERROR
ECHO.
ECHO.
GOTO NOCLEAR

:END
EXIT
