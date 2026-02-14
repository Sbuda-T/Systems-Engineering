# ============================================================
# NEXUS2026 FULL SYSTEM AUDIT & FORENSIC DATA CAPTURE SCRIPT
# Target Device: HP 15-dw1xxx
# Windows 10 Home 22H2
# ============================================================

$TimeStamp = Get-Date -Format "yyyyMMdd_HHmmss"
$BasePath = "$env:USERPROFILE\Desktop\NEXUS2026_SYSTEM_AUDIT_$TimeStamp"
New-Item -ItemType Directory -Path $BasePath -Force | Out-Null

# ------------------------------------------------------------
# SECTION 1 – SYSTEM IDENTITY
# ------------------------------------------------------------
msinfo32 /report "$BasePath\MSINFO32_Report.txt"
Get-ComputerInfo | Out-File "$BasePath\Get-ComputerInfo.txt"

# ------------------------------------------------------------
# SECTION 2 – CPU DETAILS
# ------------------------------------------------------------
Get-CimInstance Win32_Processor | 
Select-Object Name,NumberOfCores,NumberOfLogicalProcessors,MaxClockSpeed,VirtualizationFirmwareEnabled,VMMonitorModeExtensions |
Format-List | Out-File "$BasePath\CPU_Details.txt"

# ------------------------------------------------------------
# SECTION 3 – MEMORY DETAILS
# ------------------------------------------------------------
Get-CimInstance Win32_PhysicalMemory |
Select-Object Manufacturer,Capacity,Speed,ConfiguredClockSpeed |
Format-Table -AutoSize | Out-File "$BasePath\RAM_Modules.txt"

Get-CimInstance Win32_ComputerSystem |
Select-Object TotalPhysicalMemory |
Format-List | Out-File "$BasePath\RAM_Total.txt"

wmic memphysical get MaxCapacity,MemoryDevices /format:list > "$BasePath\RAM_MaxCapacity.txt"

# ------------------------------------------------------------
# SECTION 4 – STORAGE & DISK
# ------------------------------------------------------------
Get-PhysicalDisk | Format-List * | Out-File "$BasePath\PhysicalDisks.txt"
Get-Disk | Format-List * | Out-File "$BasePath\DiskInfo.txt"
Get-Volume | Format-List * | Out-File "$BasePath\Volumes.txt"

# ------------------------------------------------------------
# SECTION 5 – GPU
# ------------------------------------------------------------
Get-CimInstance Win32_VideoController |
Select-Object Name,DriverVersion,DriverDate,AdapterRAM |
Format-List | Out-File "$BasePath\GPU_Info.txt"

# ------------------------------------------------------------
# SECTION 6 – BIOS / TPM / SECURE BOOT
# ------------------------------------------------------------
Get-CimInstance Win32_BIOS |
Format-List * | Out-File "$BasePath\BIOS_Info.txt"

Confirm-SecureBootUEFI | Out-File "$BasePath\SecureBoot_Status.txt"

Get-Tpm | Format-List * | Out-File "$BasePath\TPM_Status.txt"

# ------------------------------------------------------------
# SECTION 7 – BATTERY HEALTH
# ------------------------------------------------------------
powercfg /batteryreport /output "$BasePath\Battery_Report.html"
powercfg /energy /output "$BasePath\Energy_Report.html"

# ------------------------------------------------------------
# SECTION 8 – DRIVER INVENTORY
# ------------------------------------------------------------
driverquery /v /fo csv > "$BasePath\DriverInventory.csv"
pnputil /enum-drivers > "$BasePath\PnP_Drivers.txt"

# ------------------------------------------------------------
# SECTION 9 – INSTALLED PROGRAMS
# ------------------------------------------------------------
Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* |
Select-Object DisplayName,DisplayVersion,Publisher,InstallDate |
Sort-Object DisplayName |
Out-File "$BasePath\InstalledPrograms.txt"

# ------------------------------------------------------------
# SECTION 10 – HP SERVICES & STARTUP
# ------------------------------------------------------------
Get-Service | Where-Object {$_.DisplayName -like "*HP*"} |
Format-Table Name,Status,StartType |
Out-File "$BasePath\HP_Services.txt"

Get-CimInstance Win32_StartupCommand |
Format-Table Name,Command,Location |
Out-File "$BasePath\Startup_Programs.txt"

# ------------------------------------------------------------
# SECTION 11 – PAGEFILE & MEMORY CONFIG
# ------------------------------------------------------------
wmic pagefile list /format:list > "$BasePath\Pagefile_Config.txt"

# ------------------------------------------------------------
# SECTION 12 – VIRTUALIZATION FEATURES
# ------------------------------------------------------------
Get-WindowsOptionalFeature -Online |
Where-Object {$_.FeatureName -like "*Hyper*"} |
Out-File "$BasePath\HyperV_Status.txt"

wsl --status 2>$null | Out-File "$BasePath\WSL_Status.txt"

# ------------------------------------------------------------
# SECTION 13 – NETWORK CONFIGURATION
# ------------------------------------------------------------
ipconfig /all > "$BasePath\IPConfig.txt"
netsh wlan show interfaces > "$BasePath\WiFi_Status.txt"

# ------------------------------------------------------------
# SECTION 14 – PROCESS SNAPSHOT
# ------------------------------------------------------------
Get-Process |
Sort-Object CPU -Descending |
Select-Object -First 50 |
Out-File "$BasePath\TopProcesses.txt"

# ------------------------------------------------------------
# SECTION 15 – EVENT LOG CAPTURE (CRITICAL)
# ------------------------------------------------------------

# Kernel Power 41 / Dirty Shutdowns
Get-WinEvent -FilterHashtable @{
    LogName='System'
    ID=41
} -MaxEvents 50 |
Format-List TimeCreated,Id,LevelDisplayName,Message |
Out-File "$BasePath\Event_KernelPower41.txt"

# DCOM 10016
Get-WinEvent -FilterHashtable @{
    LogName='System'
    ID=10016
} -MaxEvents 50 |
Out-File "$BasePath\Event_DCOM_10016.txt"

# MSI Installer Errors
Get-WinEvent -FilterHashtable @{
    LogName='Application'
    ID=10005
} -MaxEvents 50 |
Out-File "$BasePath\Event_MSI_10005.txt"

Get-WinEvent -FilterHashtable @{
    LogName='Application'
    ID=2753
} -MaxEvents 50 |
Out-File "$BasePath\Event_MSI_2753.txt"

# Secure Boot / TPM 1801
Get-WinEvent -FilterHashtable @{
    LogName='System'
    ID=1801
} -MaxEvents 50 |
Out-File "$BasePath\Event_SecureBoot_1801.txt"

# ------------------------------------------------------------
# SECTION 16 – WINDOWS UPDATE HISTORY
# ------------------------------------------------------------
Get-WindowsUpdateLog 2>$null
Get-HotFix | Out-File "$BasePath\Installed_Hotfixes.txt"

# ------------------------------------------------------------
# SECTION 17 – WINDOWS VERSION & LIFECYCLE
# ------------------------------------------------------------
Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" |
Out-File "$BasePath\Windows_Version.txt"

# ------------------------------------------------------------
# SECTION 18 – CONSOLIDATED MASTER REPORT
# ------------------------------------------------------------

$MasterReport = "$BasePath\MASTER_SYSTEM_SUMMARY.md"

"## NEXUS2026 SYSTEM AUDIT SUMMARY" | Out-File $MasterReport
"Generated: $(Get-Date)" | Out-File $MasterReport -Append
"" | Out-File $MasterReport -Append
Get-Content "$BasePath\CPU_Details.txt" | Out-File $MasterReport -Append
Get-Content "$BasePath\RAM_Total.txt" | Out-File $MasterReport -Append
Get-Content "$BasePath\GPU_Info.txt" | Out-File $MasterReport -Append
Get-Content "$BasePath\BIOS_Info.txt" | Out-File $MasterReport -Append
Get-Content "$BasePath\SecureBoot_Status.txt" | Out-File $MasterReport -Append

# ------------------------------------------------------------
# SECTION 19 – ZIP ARCHIVE
# ------------------------------------------------------------
Compress-Archive -Path "$BasePath\*" -DestinationPath "$env:USERPROFILE\Desktop\NEXUS2026_SYSTEM_AUDIT_$TimeStamp.zip"

Write-Host "================================================="
Write-Host "SYSTEM AUDIT COMPLETE"
Write-Host "Folder: $BasePath"
Write-Host "ZIP Archive created on Desktop."
Write-Host "================================================="
