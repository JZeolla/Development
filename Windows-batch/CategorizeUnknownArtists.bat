@echo off
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
