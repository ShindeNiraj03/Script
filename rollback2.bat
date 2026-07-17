@echo off
setlocal
:: ============================================================
:: Nessus Credentialed Scan - Windows POST-SCAN ROLLBACK Script
:: Matches: nessus_prereq_with_account_windows_v2.bat
:: Removes the local admin scan account AND reverts all
:: prerequisite settings.
:: Source: QCTPL Network VA Prerequisites Guide, Section 11
:: Run as Administrator on EACH target AFTER the scan window closes
:: ============================================================
::
:: >>> MUST MATCH the username used in the prereq script <<<
:: Change this to whatever account you actually created on
:: this machine (e.g. nessus_scan, QCT_User, etc.)
set SCAN_USER=QCT_User
:: ============================================================

set LOGFILE=%~dp0nessus_rollback_log_%COMPUTERNAME%.txt
echo ============================================== > "%LOGFILE%"
echo Nessus VA Rollback (with account removal) - %COMPUTERNAME% >> "%LOGFILE%"
echo Run on: %DATE% %TIME% >> "%LOGFILE%"
echo Target account: %SCAN_USER% >> "%LOGFILE%"
echo ============================================== >> "%LOGFILE%"

net session >nul 2>&1
if %errorLevel% NEQ 0 (
    echo ERROR: This script must be run as Administrator.
    pause
    exit /b 1
)

echo.
echo [1/6] Removing scan account "%SCAN_USER%" if present...
echo [1/6] Account Removal >> "%LOGFILE%"
net user %SCAN_USER% >nul 2>&1
if !errorlevel! EQU 0 (
    net user %SCAN_USER% /delete >> "%LOGFILE%" 2>&1
    echo    Account "%SCAN_USER%" removed.
    echo    Removed successfully >> "%LOGFILE%"
) else (
    echo    Account "%SCAN_USER%" not found - nothing to remove.
    echo    ACCOUNT NOT FOUND - check SCAN_USER matches what was created >> "%LOGFILE%"
)

echo [2/6] Resetting LocalAccountTokenFilterPolicy...
echo [2/6] LocalAccountTokenFilterPolicy >> "%LOGFILE%"
reg add HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System /v LocalAccountTokenFilterPolicy /t REG_DWORD /d 0 /f >> "%LOGFILE%" 2>&1

echo [3/6] Disabling Remote Registry service...
echo [3/6] Remote Registry >> "%LOGFILE%"
:: Only do this if it was NOT running before your engagement - confirm against your own baseline notes
sc config RemoteRegistry start= disabled >> "%LOGFILE%" 2>&1
sc stop RemoteRegistry >> "%LOGFILE%" 2>&1

echo [4/6] Re-enabling Windows Firewall (if it had been disabled)...
echo [4/6] Windows Firewall >> "%LOGFILE%"
netsh advfirewall set allprofiles state on >> "%LOGFILE%" 2>&1

echo [5/6] Restoring File and Printer Sharing rule state...
echo [5/6] Firewall Rules >> "%LOGFILE%"
netsh advfirewall firewall set rule group="File and Printer Sharing" new enable=No >> "%LOGFILE%" 2>&1

echo [6/6] Disconnecting any lingering test sessions...
echo [6/6] Disconnect Sessions >> "%LOGFILE%"
net use * /delete /yes >> "%LOGFILE%" 2>&1

echo. >> "%LOGFILE%"
echo --- Verify account is gone --- >> "%LOGFILE%"
net user %SCAN_USER% >> "%LOGFILE%" 2>&1
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
echo Confirm the account is gone and settings match
echo your pre-engagement baseline (Section 11 of guide).
echo ==============================================
pause
