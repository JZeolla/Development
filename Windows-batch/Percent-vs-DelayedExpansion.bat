@echo off

REM =========================
REM Author:          Jon Zeolla (JZeolla)
REM Last update:     2013-12-02
REM File Type:       Windows Batch File
REM Version:         1.0
REM Repository:      https://github.com/JonZeolla/Development
REM Description:     This is a batch file to help organize my wife's music
REM
REM Notes
REM - I am saving this as an example of how to use delayed expansion versus percent expansion.  
REM   - When you enable delayed expansion and change or set a variable within a loop then the !variable! syntax allows you to use the variable within the loop
REM   - Percent interpolation is done when a line or parenthesis block is parsed, before the code is executed. 
REM   - Delayed interpolation is done only at execution time.
REM - Anything that has a placeholder value is tagged with TODO
REM
REM =========================

setlocal enabledelayedexpansion
for /d %%i in ("C:\Users\User\Music\Unknown artist\*") do (
cls
echo "%%i"
set /p album=Album name:  
rename "%%i" "!album!"
set /p artist=Artist name for !album!:  
mkdir "C:\Users\User\Music\!artist!\!album!"
robocopy "C:\Users\User\Music\Unknown artist\!album!" "C:\Users\User\Music\!artist!\!album!" /MOVE /NFL /NDL /NJH /NJS /nc /ns /np
cls
)
rmdir /s /q "C:\Users\User\Music\Unknown artist"
echo All done!
