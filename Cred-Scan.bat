@echo off
setlocal EnableDelayedExpansion
:: ============================================================
:: Nessus Credentialed Scan - Windows Prerequisites Script
:: WITH LOCAL ADMIN SCAN ACCOUNT CREATION  (v2 - no WMIC dependency)
:: Source: QCTPL Network VA Prerequisites Guide
:: Run as Administrator on EACH in-scope Windows target
:: ============================================================
::
:: >>> EDIT THESE TWO VALUES BEFORE DISTRIBUTING THIS SCRIPT <<<
set SCAN_USER=QCT_User
set SCAN_PASS=Qct@072026
:: ============================================================

set LOGFILE=%~dp0nessus_prereq_log_%COMPUTERNAME%.txt
echo ============================================== > "%LOGFILE%"
echo Nessus VA Prerequisite Setup (with account) - %COMPUTERNAME% >> "%LOGFILE%"
echo Run on: %DATE% %TIME% >> "%LOGFILE%"
echo ============================================== >> "%LOGFILE%"

net session >nul 2>&1
if %errorLevel% NEQ 0 (
    echo ERROR: This script must be run as Administrator.
    echo ERROR: Not run as Administrator >> "%LOGFILE%"
    pause
    exit /b 1
)

echo.
echo [1/10] Checking for existing scan account "%SCAN_USER%"...
echo [1/10] Account Check >> "%LOGFILE%"
net user %SCAN_USER% >nul 2>&1
if !errorlevel! EQU 0 (
    echo    Account "%SCAN_USER%" already exists - skipping creation.
    echo    Account already exists >> "%LOGFILE%"
) else (
    echo    Account not found - creating "%SCAN_USER%"...
    net user %SCAN_USER% "%SCAN_PASS%" /add /expires:never >> "%LOGFILE%" 2>&1
    net localgroup Administrators %SCAN_USER% /add >> "%LOGFILE%" 2>&1
    powershell -NoProfile -Command "Set-LocalUser -Name '%SCAN_USER%' -PasswordNeverExpires $true" >> "%LOGFILE%" 2>&1
    echo    Account "%SCAN_USER%" created and added to local Administrators group.
)

echo [2/10] Enabling Remote Registry service...
echo [2/10] Remote Registry >> "%LOGFILE%"
sc config RemoteRegistry start= auto >> "%LOGFILE%" 2>&1
sc start RemoteRegistry >> "%LOGFILE%" 2>&1

echo [3/10] Enabling WMI (winmgmt)...
echo [3/10] WMI >> "%LOGFILE%"
sc config winmgmt start= auto >> "%LOGFILE%" 2>&1
sc start winmgmt >> "%LOGFILE%" 2>&1

echo [4/10] Enabling SMB2 protocol...
echo [4/10] SMB2 >> "%LOGFILE%"
reg add HKLM\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters /v SMB2 /t REG_DWORD /d 1 /f >> "%LOGFILE%" 2>&1

echo [5/10] Setting LocalAccountTokenFilterPolicy (workgroup fix)...
echo [5/10] LocalAccountTokenFilterPolicy >> "%LOGFILE%"
reg add HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System /v LocalAccountTokenFilterPolicy /t REG_DWORD /d 1 /f >> "%LOGFILE%" 2>&1

echo [6/10] Enabling Administrative Shares (ADMIN$/C$)...
echo [6/10] Admin Shares >> "%LOGFILE%"

:: Detect Server vs Workstation using PowerShell (wmic is removed on newer Windows builds)
set PRODUCTTYPE=1
for /f %%i in ('powershell -NoProfile -Command "(Get-CimInstance Win32_OperatingSystem).ProductType"') do set PRODUCTTYPE=%%i

if "!PRODUCTTYPE!"=="1" (
    echo    Detected Workstation OS - using AutoShareWks
    echo    Detected Workstation OS >> "%LOGFILE%"
    reg add HKLM\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters /v AutoShareWks /t REG_DWORD /d 1 /f >> "%LOGFILE%" 2>&1
) else (
    echo    Detected Server OS - using AutoShareServer
    echo    Detected Server OS >> "%LOGFILE%"
    reg add HKLM\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters /v AutoShareServer /t REG_DWORD /d 1 /f >> "%LOGFILE%" 2>&1
)

echo [7/10] Restarting Server service (LanmanServer)...
echo [7/10] Restart LanmanServer >> "%LOGFILE%"
sc config LanmanServer start= auto >> "%LOGFILE%" 2>&1
sc stop LanmanServer >> "%LOGFILE%" 2>&1
timeout /t 3 /nobreak >nul
sc start LanmanServer >> "%LOGFILE%" 2>&1

echo [8/10] Enabling File and Printer Sharing firewall rules...
echo [8/10] Firewall Rules >> "%LOGFILE%"
netsh advfirewall firewall set rule group="File and Printer Sharing" new enable=Yes >> "%LOGFILE%" 2>&1

echo [9/10] Checking network connection profile...
echo [9/10] Network Profile >> "%LOGFILE%"
powershell -NoProfile -Command "Get-NetConnectionProfile | Format-Table -AutoSize" >> "%LOGFILE%" 2>&1
powershell -NoProfile -Command ^
  "$profiles = Get-NetConnectionProfile; foreach ($p in $profiles) { if ($p.NetworkCategory -eq 'Public') { Set-NetConnectionProfile -InterfaceIndex $p.InterfaceIndex -NetworkCategory Private; Write-Output ('Changed ' + $p.InterfaceAlias + ' from Public to Private') } }" >> "%LOGFILE%" 2>&1

echo [10/10] Verifying account, shares and services...
echo [10/10] Final Verification >> "%LOGFILE%"
echo. >> "%LOGFILE%"
echo --- net user %SCAN_USER% --- >> "%LOGFILE%"
net user %SCAN_USER% >> "%LOGFILE%" 2>&1
echo. >> "%LOGFILE%"
echo --- net share output --- >> "%LOGFILE%"
net share >> "%LOGFILE%" 2>&1
echo. >> "%LOGFILE%"
echo --- Service status --- >> "%LOGFILE%"
sc query RemoteRegistry | find "STATE" >> "%LOGFILE%"
sc query winmgmt | find "STATE" >> "%LOGFILE%"
sc query LanmanServer | find "STATE" >> "%LOGFILE%"

echo.
echo ==============================================
echo Done. Log saved to: %LOGFILE%
echo Scan account: %SCAN_USER%  (password as set in the script)
echo ==============================================
echo.
echo IMPORTANT SECURITY NOTES:
echo  - This creates a LOCAL ADMIN account with the SAME password
echo    on every machine you run this on. Treat that password like
echo    a master key: store it securely and rotate/delete it after
echo    the engagement (use the matching rollback script).
echo  - Consider using unique passwords per machine or a password
echo    vault/PAM tool instead of one shared credential if policy
echo    requires it.
echo.
pause
