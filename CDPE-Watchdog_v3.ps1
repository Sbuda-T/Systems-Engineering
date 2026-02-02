<#
    PROJECT: Nexus2026 CDPE Architecture
    SCRIPT: CDPE-Watchdog_v3.ps1
    OBJECTIVE: Closed-Loop System State Regulation ($I_resp, $C_reg, $P_sync, $M_util)
    VERSION: 3.0 (Final Integration)
#>

# --- 1. SYSTEM CONSTANTS & EPISTEMOLOGY ---
$MaxRamThreshold = 80        # Reduced to 80% to protect DCOM ($C_reg)
$MaxCpuThreshold = 85        # CPU Regulation Trigger
$LogPath = "C:\CDPE_Scripts\Watchdog_Events.log"
$Interval = 20               # Check frequency in seconds

# Ensure Log Directory Exists
if (!(Test-Path "C:\CDPE_Scripts")) { New-Item -ItemType Directory -Path "C:\CDPE_Scripts" | Out-Null }

function Write-Log {
    param ($Message)
    $TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $Line = "[$TimeStamp] $Message"
    Add-Content -Path $LogPath -Value $Line
    Write-Host $Line -ForegroundColor Cyan
}

# --- 2. CONTROL FUNCTION: CPU REGULATOR ---
function Optimize-CpuState {
    # Get Global CPU Load (Requires 1-second sample)
    $CpuLoad = (Get-Counter '\Processor(_Total)\% Processor Time' -ErrorAction SilentlyContinue).CounterSamples.CookedValue
    
    if ($CpuLoad -ge $MaxCpuThreshold) {
        Write-Host "   [!] CPU Saturation Detected ($([math]::Round($CpuLoad))%)" -ForegroundColor Yellow
        
        # Find the Hog (Top 1 Process)
        $Hog = Get-Process | Sort-Object CPU -Descending | Select-Object -First 1
        
        if ($Hog.PriorityClass -ne 'Idle') {
            # Regulate: Lower Priority to save UI
            $Hog.PriorityClass = 'Idle'
            Write-Log "ACTION: Throttled CPU Hog '$($Hog.Name)' to IDLE priority to preserve UI ($I_resp)."
        }
    }
}

# --- 3. CONTROL FUNCTION: REGISTRY HEALTH ($C_reg) ---
function Test-RegistryHealth {
    # Check if DCOM/RPC are alive
    $Dcom = Get-Service "DcomLaunch" -ErrorAction SilentlyContinue
    if ($Dcom.Status -ne 'Running') {
        Write-Log "CRITICAL: DCOM Service DOWN. Optimization Paused."
        return $false
    }
    return $true
}

# --- 4. CONTROL FUNCTION: MEMORY CONSTRAINT ($M_util) ---
function Optimize-MemoryConstraints {
    # A. The Kill List (BLUETOOTH REMOVED per user request)
    $KillList = @(
        "SearchApp", "OneDrive", "XboxApp", "GameBar", 
        "YourPhone", "LockApp", "MicrosoftEdgeUpdate", 
        "CompatTelRunner", "DeviceCensus", "SmartScreen"
    )

    foreach ($App in $KillList) {
        Get-Process $App -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    }

    # B. Edge Trim (Surgical)
    Get-Process msedge -ErrorAction SilentlyContinue | ForEach-Object { $_.MinWorkingSet = [intptr]::Zero }
    
    Write-Log "ACTION: Enforced RAM Constraints (Kill List + Edge Trim)."
}

# --- 5. CONTROL FUNCTION: HARDWARE SECURITY ($H_sec) ---
function Test-TpmState {
    # Uses WMI to bypass 'Module not found' error
    try {
        $Tpm = Get-CimInstance -Namespace "root\cimv2\security\microsofttpm" -ClassName Win32_Tpm -ErrorAction Stop
        if (!$Tpm.IsReady_InitialValue) { Write-Host "   [!] TPM Not Ready (Expect Interrupts)" -ForegroundColor DarkGray }
    } catch {
        Write-Host "   [!] TPM WMI Unreachable" -ForegroundColor DarkGray
    }
}

# --- MAIN FEEDBACK LOOP ---
Clear-Host
Write-Log "=== CDPE WATCHDOG v3.0 STARTED ==="
Write-Log "Constraints: RAM > $MaxRamThreshold% | CPU > $MaxCpuThreshold%"

while ($true) {
    # 1. Measure System State
    $mem = Get-CimInstance Win32_OperatingSystem
    $RamUsage = (($mem.TotalVisibleMemorySize - $mem.FreePhysicalMemory) / $mem.TotalVisibleMemorySize) * 100
    
    Write-Host "Status: RAM $([math]::Round($RamUsage,1))%..." -NoNewline -ForegroundColor DarkGray

    # 2. Check Constraints
    if ($RamUsage -ge $MaxRamThreshold) {
        Write-Host " [ALERT]" -ForegroundColor Red
        if (Test-RegistryHealth) {
            Optimize-MemoryConstraints
        }
    } else {
        Write-Host " [OK]" -ForegroundColor Green
    }

    # 3. Regulate CPU ($I_resp)
    Optimize-CpuState

    # 4. Background Hardware Check (Passive)
    Test-TpmState

    Start-Sleep -Seconds $Interval
}
