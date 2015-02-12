@echo off

REM =========================
REM Author:          Jon Zeolla (JZeolla)
REM Creation date:   2008-09-26
REM File Type:       Windows Batch File
REM Version:         1.0
REM Repository:      https://github.com/JZeolla
REM Description:     This is a batch file to help simplify running commands as Administrator
REM
REM Notes
REM - This is a simple example of choices in a Windows batch file
REM
REM =========================

:CLEAR
CLS

:NOCLEAR
ECHO 1.  cmd
ECHO 2.  regedit
ECHO 3.  control userpasswords2
ECHO 4.  *.msc
ECHO 5.  input
ECHO 6.  quit
ECHO.

SET CHOICE=
SET /P CHOICE=(1-6):  
IF NOT '%CHOICE%'=='' SET CHOICE=%CHOICE:~0,1%
IF '%CHOICE%' == '1' GOTO CMD
IF '%CHOICE%' == '2' GOTO REGEDIT
IF '%CHOICE%' == '3' GOTO CONTROL2
IF '%CHOICE%' == '4' GOTO MSC
IF '%CHOICE%' == '5' GOTO OTHER
IF '%CHOICE%' == '6' GOTO END
IF '%CHOICE%' == 'e' GOTO END
IF '%CHOICE%' == 'q' GOTO END
IF '%CHOICE%' == 'E' GOTO END
IF '%CHOICE%' == 'Q' GOTO END
IF '%CHOICE%' == 'C' GOTO CLEAR
IF '%CHOICE%' == 'c' GOTO CLEAR

:ERROR
CLS
ECHO Input or password is not valid.  
if %ERRORLEVEL%==0 GOTO CLEAR
ECHO.
GOTO NOCLEAR

:CMD
RUNAS /USER:Administrator /NOPROFILE "cmd.exe"
IF NOT %ERRORLEVEL%==0 GOTO ERROR
GOTO CLEAR

:REGEDIT
RUNAS /USER:Administrator /NOPROFILE "regedit.exe"
IF NOT %ERRORLEVEL%==0 GOTO ERROR
GOTO CLEAR

:CONTROL2
RUNAS /USER:Administrator /NOPROFILE "control userpasswords2"
IF NOT %ERRORLEVEL%==0 GOTO ERROR
GOTO CLEAR

:MSC
SET CHOICE=
SET /P CHOICE=(*.msc):  
RUNAS /USER:Administrator /NOPROFILE "MMC.EXE %WINDIR%\System32\%CHOICE%.msc"
IF NOT %ERRORLEVEL%==0 GOTO ERROR
GOTO CLEAR

:OTHER
ECHO.
ECHO Only commands located in the System32 folder work in this area.  
SET CHOICE=
SET /P CHOICE=Input:  
RUNAS /USER:Administrator /NOPROFILE "%WINDIR%\System32\%CHOICE%"
IF NOT %ERRORLEVEL%==0 GOTO ERROR
GOTO CLEAR

:END
EXIT
