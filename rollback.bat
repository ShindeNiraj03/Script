@echo off
setlocal
:: ============================================================
:: Nessus Credentialed Scan - Windows POST-SCAN ROLLBACK Script (v2)
:: Matches: nessus_prereq_windows_v2.bat
:: Source: QCTPL Network VA Prerequisites Guide, Section 11
:: Run as Administrator on EACH target AFTER the scan window closes
:: ============================================================

set LOGFILE=%~dp0nessus_rollback_log_%COMPUTERNAME%.txt
echo ============================================== > "%LOGFILE%"
echo Nessus VA Rollback (v2) - %COMPUTERNAME% >> "%LOGFILE%"
echo Run on: %DATE% %TIME% >> "%LOGFILE%"
echo ============================================== >> "%LOGFILE%"

net session >nul 2>&1
if %errorLevel% NEQ 0 (
    echo ERROR: This script must be run as Administrator.
    pause
    exit /b 1
)

echo.
echo [1/5] Resetting LocalAccountTokenFilterPolicy...
echo [1/5] LocalAccountTokenFilterPolicy >> "%LOGFILE%"
reg add HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System /v LocalAccountTokenFilterPolicy /t REG_DWORD /d 0 /f >> "%LOGFILE%" 2>&1

echo [2/5] Disabling Remote Registry service...
echo [2/5] Remote Registry >> "%LOGFILE%"
:: Only do this if it was NOT running before your engagement - confirm against your own baseline notes
sc config RemoteRegistry start= disabled >> "%LOGFILE%" 2>&1
sc stop RemoteRegistry >> "%LOGFILE%" 2>&1

echo [3/5] Re-enabling Windows Firewall (if it had been disabled)...
echo [3/5] Windows Firewall >> "%LOGFILE%"
netsh advfirewall set allprofiles state on >> "%LOGFILE%" 2>&1

echo [4/5] Restoring File and Printer Sharing rule state...
echo [4/5] Firewall Rules >> "%LOGFILE%"
netsh advfirewall firewall set rule group="File and Printer Sharing" new enable=No >> "%LOGFILE%" 2>&1

echo [5/5] Disconnecting any lingering test sessions...
echo [5/5] Disconnect Sessions >> "%LOGFILE%"
net use * /delete /yes >> "%LOGFILE%" 2>&1

echo. >> "%LOGFILE%"
echo --- Final Service Status --- >> "%LOGFILE%"
sc query RemoteRegistry | find "STATE" >> "%LOGFILE%"
sc query winmgmt | find "STATE" >> "%LOGFILE%"
sc query LanmanServer | find "STATE" >> "%LOGFILE%"
echo. >> "%LOGFILE%"
echo --- net share output --- >> "%LOGFILE%"
net share >> "%LOGFILE%" 2>&1

echo.
echo ==============================================
echo Rollback complete. Log saved to: %LOGFILE%
echo Review the log and confirm settings match your
echo pre-engagement baseline (see Section 11 of the guide).
echo.
echo NOTE: This script does NOT remove any user account,
echo since nessus_prereq_windows_v2.bat did not create one.
echo If you also ran the account-creation script on this
echo machine, use nessus_rollback_with_account_windows.bat
echo instead to remove that account too.
echo ==============================================
pause
