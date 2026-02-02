# CDPE-DCOM-Access-Repair.ps1
$AppID = "{15C20B67-12E7-4BB6-92BB-7AFF07997402}"

Write-Host "[!] Injecting Access Permissions for WscDataProtection..." -ForegroundColor Cyan

# We use the 'regini' tool (built into Windows) to force the permission change 
# without needing to restart the DCOM service.
$ReginiScript = @"
HKEY_CLASSES_ROOT\AppID\$AppID [1 5 17]
"@

$ReginiScript | regini.exe

Write-Host "[+] Registry ACLs updated. DCOM handshake should now clear." -ForegroundColor Green
