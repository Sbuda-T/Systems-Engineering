powershell
# ==============================================================================
# CDPE SESSION PERFORMANCE MONITOR v2.0
# Constraint-Driven Process Elimination Monitoring System
# 
# Purpose: Measure system performance impact of deep work sessions
#          Track top resource consumers to identify control targets
# 
# QoI Targets:
#   - RAM Free: ≥ 1000 MB
#   - RAM Used: < 1800 MB  
#   - CPU Load: < 50%
#   - Process Count: < 90
#   - Pages/sec: < 50
#   - Disk Idle: > 98%
# ==============================================================================

param(
    [ValidateSet('Log', 'Compare', 'View')]
    [string]$Mode = $null
)

# ==============================================================================
# CONFIGURATION
# ==============================================================================
$SESSION_FOLDER = ".\CDPE_Sessions"
$COMPARE_FOLDER = "$SESSION_FOLDER\Comparisons"
$PROCESS_FOLDER = "$SESSION_FOLDER\ProcessSnapshots"
$LOG_DURATION_MINUTES = 90
$LOG_INTERVAL_SECONDS = 15
$PROCESS_SNAPSHOT_INTERVAL = 5  # Minutes between process snapshots

# QoI Thresholds
$QOI_THRESHOLDS = @{
    RAM_FREE_MIN_MB = 1000
    RAM_USED_MAX_MB = 1800
    CPU_MAX_PCT = 50
    PROCESS_COUNT_MAX = 90
    PAGES_MAX = 50
    DISK_IDLE_MIN_PCT = 98
}

# Ensure folder structure exists
@($SESSION_FOLDER, $COMPARE_FOLDER, $PROCESS_FOLDER) | ForEach-Object {
    if (-not (Test-Path $_)) {
        New-Item -ItemType Directory -Path $_ | Out-Null
    }
}

# ==============================================================================
# FUNCTION: CAPTURE PROCESS SNAPSHOT
# ==============================================================================
function Get-ProcessSnapshot {
    param([string]$SnapshotName)
    
    $processes = Get-Process | Select-Object `
        ProcessName, `
        @{Name="RAM_MB"; Expression={[math]::Round($_.WorkingSet / 1MB, 1)}}, `
        @{Name="CPU_Sec"; Expression={[math]::Round($_.CPU, 1)}}, `
        Id, `
        Threads, `
        Handles, `
        Path | 
        Sort-Object RAM_MB -Descending
    
    $top5_ram = $processes | Select-Object -First 5
    $top5_cpu = $processes | Sort-Object CPU_Sec -Descending | Select-Object -First 5
    
    return @{
        All = $processes
        Top5RAM = $top5_ram
        Top5CPU = $top5_cpu
    }
}

# ==============================================================================
# FUNCTION: CHECK QOI COMPLIANCE
# ==============================================================================
function Test-QoICompliance {
    param(
        [double]$RAM_Free_MB,
        [double]$RAM_Used_MB,
        [double]$CPU_Pct,
        [int]$ProcessCount,
        [double]$Pages,
        [double]$DiskIdle_Pct
    )
    
    $violations = @()
    
    if ($RAM_Free_MB -lt $QOI_THRESHOLDS.RAM_FREE_MIN_MB) {
        $violations += "⚠️  RAM Free: $([math]::Round($RAM_Free_MB,0)) MB (Target: ≥ $($QOI_THRESHOLDS.RAM_FREE_MIN_MB) MB)"
    }
    
    if ($RAM_Used_MB -gt $QOI_THRESHOLDS.RAM_USED_MAX_MB) {
        $violations += "⚠️  RAM Used: $([math]::Round($RAM_Used_MB,0)) MB (Target: < $($QOI_THRESHOLDS.RAM_USED_MAX_MB) MB)"
    }
    
    if ($CPU_Pct -gt $QOI_THRESHOLDS.CPU_MAX_PCT) {
        $violations += "⚠️  CPU Load: $([math]::Round($CPU_Pct,1))% (Target: < $($QOI_THRESHOLDS.CPU_MAX_PCT)%)"
    }
    
    if ($ProcessCount -gt $QOI_THRESHOLDS.PROCESS_COUNT_MAX) {
        $violations += "⚠️  Processes: $ProcessCount (Target: < $($QOI_THRESHOLDS.PROCESS_COUNT_MAX))"
    }
    
    if ($Pages -gt $QOI_THRESHOLDS.PAGES_MAX) {
        $violations += "⚠️  Paging: $([math]::Round($Pages,1)) p/s (Target: < $($QOI_THRESHOLDS.PAGES_MAX))"
    }
    
    if ($DiskIdle_Pct -lt $QOI_THRESHOLDS.DISK_IDLE_MIN_PCT) {
        $violations += "⚠️  Disk Busy: $([math]::Round(100-$DiskIdle_Pct,1))% (Target: < $(100-$QOI_THRESHOLDS.DISK_IDLE_MIN_PCT)%)"
    }
    
    return $violations
}

# ==============================================================================
# FUNCTION: SHOW MAIN MENU
# ==============================================================================
function Show-MainMenu {
    Clear-Host
    Write-Host "╔════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║   CDPE SESSION PERFORMANCE MONITOR v2.0               ║" -ForegroundColor Cyan
    Write-Host "║   Constraint-Driven Process Elimination Testing       ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "📊 System Targets:" -ForegroundColor Yellow
    Write-Host "   RAM Free    : ≥ $($QOI_THRESHOLDS.RAM_FREE_MIN_MB) MB" -ForegroundColor Gray
    Write-Host "   RAM Used    : < $($QOI_THRESHOLDS.RAM_USED_MAX_MB) MB" -ForegroundColor Gray
    Write-Host "   CPU Load    : < $($QOI_THRESHOLDS.CPU_MAX_PCT)%" -ForegroundColor Gray
    Write-Host "   Processes   : < $($QOI_THRESHOLDS.PROCESS_COUNT_MAX)" -ForegroundColor Gray
    Write-Host "   Paging      : < $($QOI_THRESHOLDS.PAGES_MAX) p/s" -ForegroundColor Gray
    Write-Host "   Disk Idle   : > $($QOI_THRESHOLDS.DISK_IDLE_MIN_PCT)%" -ForegroundColor Gray
    Write-Host ""
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
    Write-Host "[1] Start Performance Log (90 minutes)" -ForegroundColor Yellow
    Write-Host "[2] Compare Two Sessions" -ForegroundColor Yellow
    Write-Host "[3] View All Sessions" -ForegroundColor Yellow
    Write-Host "[4] Exit" -ForegroundColor Yellow
    Write-Host ""
}

# ==============================================================================
# FUNCTION: START PERFORMANCE LOG
# ==============================================================================
function Start-PerformanceLog {
    Clear-Host
    Write-Host "╔════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║        START NEW PERFORMANCE LOG                      ║" -ForegroundColor Green
    Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Green
    
    # Prompt for test details
    Write-Host ""
    Write-Host "TEST CONFIGURATION" -ForegroundColor White
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor DarkGray
    Write-Host "  • Baseline (light work, email only)" -ForegroundColor DarkGray
    Write-Host "  • Video_Call_Heavy (Teams + VSCode + Chrome)" -ForegroundColor DarkGray
    Write-Host "  • DevMode_ON (with services disabled)" -ForegroundColor DarkGray
    Write-Host "  • Cloud_Computing (Docker + WSL + browsers)" -ForegroundColor DarkGray
    Write-Host ""
    
    $test_name = Read-Host "Test Name"
    
    if ([string]::IsNullOrWhiteSpace($test_name)) {
        Write-Host "❌ Test name cannot be empty." -ForegroundColor Red
        return
    }
    
    $test_name_clean = $test_name -replace '\s+', '_' -replace '[^a-zA-Z0-9_]', ''
    
    Write-Host ""
    $notes = Read-Host "What are you doing this session? (optional)"
    
    # Create filenames
    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $log_file = "$SESSION_FOLDER\CDPE_${test_name_clean}_${timestamp}.csv"
    $metadata_file = "$SESSION_FOLDER\CDPE_${test_name_clean}_${timestamp}_metadata.json"
    $process_log = "$PROCESS_FOLDER\Processes_${test_name_clean}_${timestamp}.csv"
    
    # ==============================================================================
    # CAPTURE INITIAL SYSTEM STATE
    # ==============================================================================
    Write-Host ""
    Write-Host "📊 Capturing system baseline..." -ForegroundColor Gray
    
    $total_ram_gb = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)
    
    $system_info = @{
        TestName = $test_name
        TestNotes = $notes
        StartTime = Get-Date -Format "o"
        Duration_Minutes = $LOG_DURATION_MINUTES
        Interval_Seconds = $LOG_INTERVAL_SECONDS
        Computer = $env:COMPUTERNAME
        User = $env:USERNAME
        OS = (Get-CimInstance Win32_OperatingSystem).Caption
        CPU_Name = (Get-CimInstance Win32_Processor).Name
        CPU_Cores = (Get-CimInstance Win32_Processor).NumberOfCores
        CPU_LogicalProcessors = (Get-CimInstance Win32_Processor).NumberOfLogicalProcessors
        RAM_Total_GB = $total_ram_gb
        RAM_Total_MB = $total_ram_gb * 1024
    }
    
    # Capture initial process snapshot
    Write-Host "📋 Capturing initial process snapshot..." -ForegroundColor Gray
    $initial_snapshot = Get-ProcessSnapshot -SnapshotName "Initial"
    
    # Save metadata
    $system_info | ConvertTo-Json | Out-File $metadata_file -Encoding utf8
    
    # ==============================================================================
    # INITIALIZE DATA COLLECTION
    # ==============================================================================
    "DateTime,Time,RAM_Available_MB,RAM_Committed_MB,RAM_InUse_MB,RAM_Usage_Pct,CPU_Load_Pct,Pages_Per_Sec,Disk_Idle_Pct,Process_Count,QoI_Violations" | 
        Out-File $log_file -Encoding utf8
    
    # Process snapshot header
    "Timestamp,ProcessName,RAM_MB,CPU_Sec,PID,Threads,Handles,Path" | 
        Out-File $process_log -Encoding utf8
    
    # Save initial snapshot
    foreach ($proc in $initial_snapshot.All) {
        "$($system_info.StartTime),$($proc.ProcessName),$($proc.RAM_MB),$($proc.CPU_Sec),$($proc.Id),$($proc.Threads),$($proc.Handles),$($proc.Path)" | 
            Out-File $process_log -Append -Encoding utf8
    }
    
    # ==============================================================================
    # DISPLAY START CONFIRMATION
    # ==============================================================================
    Clear-Host
    Write-Host "╔════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║      PERFORMANCE LOG STARTING IN 5 SECONDS            ║" -ForegroundColor Green
    Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
    Write-Host "📋 Test Configuration:" -ForegroundColor Cyan
    Write-Host "   Test Name    : $test_name" -ForegroundColor White
    Write-Host "   Notes        : $notes" -ForegroundColor White
    Write-Host "   Duration     : $LOG_DURATION_MINUTES minutes" -ForegroundColor White
    Write-Host "   Sample Rate  : Every $LOG_INTERVAL_SECONDS seconds" -ForegroundColor White
    Write-Host ""
    Write-Host "📂 Output Files:" -ForegroundColor Cyan
    Write-Host "   Metrics      : $log_file" -ForegroundColor Gray
    Write-Host "   Processes    : $process_log" -ForegroundColor Gray
    Write-Host "   Metadata     : $metadata_file" -ForegroundColor Gray
    Write-Host ""
    Write-Host "⏱️  BEGIN YOUR SESSION NOW (e.g., start video call)" -ForegroundColor Yellow
    Write-Host ""
    
    for ($i = 5; $i -gt 0; $i--) {
        Write-Host "Starting in $i..." -ForegroundColor Yellow
        Start-Sleep -Seconds 1
    }
    
    Write-Host ""
    Write-Host "✓ LOGGING ACTIVE - Do not close this window" -ForegroundColor Green
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
    Write-Host ""
    
    $start_time = Get-Date
    $end_time = $start_time.AddMinutes($LOG_DURATION_MINUTES)
    $last_process_snapshot = $start_time
    $sample_count = 0
    $error_count = 0
    $qoi_violation_count = 0
    
    # ==============================================================================
    # MAIN COLLECTION LOOP
    # ==============================================================================
    while ((Get-Date) -lt $end_time) {
        try {
            $now = Get-Date
            
            # Collect performance counters
            $ram_avail = (Get-Counter '\Memory\Available MBytes').CounterSamples.CookedValue
            $ram_comm  = (Get-Counter '\Memory\Committed Bytes').CounterSamples.CookedValue / 1MB
            $ram_used  = ($system_info.RAM_Total_MB) - $ram_avail
            $ram_pct   = ($ram_used / $system_info.RAM_Total_MB) * 100
            $cpu       = (Get-Counter '\Processor(_Total)\% Processor Time').CounterSamples.CookedValue
            $pages     = (Get-Counter '\Memory\Pages/sec').CounterSamples.CookedValue
            $disk_time = (Get-Counter '\PhysicalDisk(_Total)\% Disk Time').CounterSamples.CookedValue
            $disk_idle = 100 - $disk_time
            $procs     = (Get-Process).Count
            
            # Check QoI compliance
            $violations = Test-QoICompliance -RAM_Free_MB $ram_avail -RAM_Used_MB $ram_used -CPU_Pct $cpu -ProcessCount $procs -Pages $pages -DiskIdle_Pct $disk_idle
            
            if ($violations.Count -gt 0) {
                $qoi_violation_count++
            }
            
            # Write metrics row
            $row = "{0},{1},{2},{3},{4},{5},{6},{7},{8},{9},{10}" -f `
                $now.ToString("o"), `
                $now.ToString("HH:mm:ss"), `
                [math]::Round($ram_avail, 0), `
                [math]::Round($ram_comm, 0), `
                [math]::Round($ram_used, 0), `
                [math]::Round($ram_pct, 1), `
                [math]::Round($cpu, 1), `
                [math]::Round($pages, 1), `
                [math]::Round($disk_idle, 1), `
                $procs, `
                $violations.Count
            
            $row | Out-File $log_file -Append -Encoding utf8
            $sample_count++
            
            # Periodic process snapshot
            if (($now - $last_process_snapshot).TotalMinutes -ge $PROCESS_SNAPSHOT_INTERVAL) {
                $snapshot = Get-ProcessSnapshot -SnapshotName "Periodic"
                foreach ($proc in $snapshot.All) {
                    "$($now.ToString("o")),$($proc.ProcessName),$($proc.RAM_MB),$($proc.CPU_Sec),$($proc.Id),$($proc.Threads),$($proc.Handles),$($proc.Path)" | 
                        Out-File $process_log -Append -Encoding utf8
                }
                $last_process_snapshot = $now
            }
            
            # Progress indicator
            if ($sample_count % 20 -eq 0) {
                $elapsed = [math]::Round(((Get-Date) - $start_time).TotalMinutes, 1)
                $remaining = [math]::Round(($end_time - (Get-Date)).TotalMinutes, 1)
                $pct_complete = [math]::Round(($elapsed / $LOG_DURATION_MINUTES) * 100, 0)
                
                $status_color = if ($violations.Count -gt 0) { "Yellow" } else { "Gray" }
                $status_icon = if ($violations.Count -gt 0) { "⚠️ " } else { "" }
                
                Write-Host ("${status_icon}[${pct_complete}%] $elapsed / $LOG_DURATION_MINUTES min | RAM: {0}% | CPU: {1}% | Procs: {2}" -f `
                    [math]::Round($ram_pct,0), `
                    [math]::Round($cpu,0), `
                    $procs) -ForegroundColor $status_color
                
                if ($violations.Count -gt 0) {
                    foreach ($v in $violations) {
                        Write-Host "     $v" -ForegroundColor Yellow
                    }
                }
            }
        }
        catch {
            $error_count++
            Write-Warning "Sampling error #$error_count - $_"
        }
        
        Start-Sleep -Seconds $LOG_INTERVAL_SECONDS
    }
    
    # ==============================================================================
    # FINAL PROCESS SNAPSHOT
    # ==============================================================================
    Write-Host ""
    Write-Host "📊 Capturing final process snapshot..." -ForegroundColor Gray
    $final_snapshot = Get-ProcessSnapshot -SnapshotName "Final"
    
    foreach ($proc in $final_snapshot.All) {
        "$(Get-Date -Format "o"),$($proc.ProcessName),$($proc.RAM_MB),$($proc.CPU_Sec),$($proc.Id),$($proc.Threads),$($proc.Handles),$($proc.Path)" | 
            Out-File $process_log -Append -Encoding utf8
    }
    
    # ==============================================================================
    # ANALYSIS & SUMMARY
    # ==============================================================================
    Write-Host ""
    Write-Host "✓ LOGGING COMPLETE" -ForegroundColor Green
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Analyzing data..." -ForegroundColor Gray
    
    $data = Import-Csv $log_file
    
    $stats = @{
        EndTime = Get-Date -Format "o"
        TotalSamples = $sample_count
        ErrorCount = $error_count
        DataQuality = [math]::Round(($sample_count / ($LOG_DURATION_MINUTES * 60 / $LOG_INTERVAL_SECONDS)) * 100, 1)
        QoI_Violation_Count = $qoi_violation_count
        QoI_Compliance_Pct = [math]::Round((($sample_count - $qoi_violation_count) / $sample_count) * 100, 1)
        
        RAM_Avg_MB = [math]::Round(($data.RAM_InUse_MB | Measure-Object -Average).Average, 0)
        RAM_Min_MB = ($data.RAM_InUse_MB | Measure-Object -Minimum).Minimum
        RAM_Max_MB = ($data.RAM_InUse_MB | Measure-Object -Maximum).Maximum
        RAM_Avg_Pct = [math]::Round(($data.RAM_Usage_Pct | Measure-Object -Average).Average, 1)
        
        CPU_Avg_Pct = [math]::Round(($data.CPU_Load_Pct | Measure-Object -Average).Average, 1)
        CPU_Min_Pct = [math]::Round(($data.CPU_Load_Pct | Measure-Object -Minimum).Minimum, 1)
        CPU_Max_Pct = [math]::Round(($data.CPU_Load_Pct | Measure-Object -Maximum).Maximum, 1)
        
        Pages_Avg = [math]::Round(($data.Pages_Per_Sec | Measure-Object -Average).Average, 1)
        Pages_Max = [math]::Round(($data.Pages_Per_Sec | Measure-Object -Maximum).Maximum, 1)
        
        Disk_Avg_Idle = [math]::Round(($data.Disk_Idle_Pct | Measure-Object -Average).Average, 1)
        
        Process_Avg = [math]::Round(($data.Process_Count | Measure-Object -Average).Average, 0)
        Process_Min = ($data.Process_Count | Measure-Object -Minimum).Minimum
        Process_Max = ($data.Process_Count | Measure-Object -Maximum).Maximum
        
        Top5_RAM_Final = $final_snapshot.Top5RAM
        Top5_CPU_Final = $final_snapshot.Top5CPU
    }
    
    # Update metadata
    $combined = $system_info + $stats
    $combined | ConvertTo-Json -Depth 10 | Out-File $metadata_file -Encoding utf8
    
    # ==============================================================================
    # DISPLAY SUMMARY
    # ==============================================================================
    Clear-Host
    Write-Host "╔════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║              SESSION COMPLETE                         ║" -ForegroundColor Green
    Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Green
    
    Write-Host ""
    Write-Host "📊 DATA QUALITY" -ForegroundColor Cyan
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
    Write-Host "Samples Captured : $($stats.TotalSamples) / $([math]::Floor($LOG_DURATION_MINUTES * 60 / $LOG_INTERVAL_SECONDS)) ($($stats.DataQuality)%)" -ForegroundColor White
    Write-Host "QoI Compliance   : $($stats.QoI_Compliance_Pct)% ($($sample_count - $qoi_violation_count)/$sample_count samples within targets)" -ForegroundColor $(if($stats.QoI_Compliance_Pct -ge 90){'Green'}elseif($stats.QoI_Compliance_Pct -ge 70){'Yellow'}else{'Red'})
    
    Write-Host ""
    Write-Host "📈 PERFORMANCE METRICS" -ForegroundColor Cyan
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
    Write-Host ("RAM Usage (MB)   : Avg {0} | Peak {1} | Target < {2}" -f $stats.RAM_Avg_MB, $stats.RAM_Max_MB, $QOI_THRESHOLDS.RAM_USED_MAX_MB) -ForegroundColor $(if($stats.RAM_Avg_MB -lt $QOI_THRESHOLDS.RAM_USED_MAX_MB){'Green'}else{'Yellow'})
    Write-Host ("CPU Load (%)     : Avg {0} | Peak {1} | Target < {2}" -f $stats.CPU_Avg_Pct, $stats.CPU_Max_Pct, $QOI_THRESHOLDS.CPU_MAX_PCT) -ForegroundColor $(if($stats.CPU_Avg_Pct -lt $QOI_THRESHOLDS.CPU_MAX_PCT){'Green'}else{'Yellow'})
    Write-Host ("Paging (p/s)     : Avg {0} | Peak {1} | Target < {2}" -f $stats.Pages_Avg, $stats.Pages_Max, $QOI_THRESHOLDS.PAGES_MAX) -ForegroundColor $(if($stats.Pages_Avg -lt $QOI_THRESHOLDS.PAGES_MAX){'Green'}else{'Yellow'})
    Write-Host ("Disk Idle (%)    : Avg {0} | Target > {1}" -f $stats.Disk_Avg_Idle, $QOI_THRESHOLDS.DISK_IDLE_MIN_PCT) -ForegroundColor $(if($stats.Disk_Avg_Idle -gt $QOI_THRESHOLDS.DISK_IDLE_MIN_PCT){'Green'}else{'Yellow'})
    Write-Host ("Process Count    : Avg {0} | Range {1}-{2} | Target < {3}" -f $stats.Process_Avg, $stats.Process_Min, $stats.Process_Max, $QOI_THRESHOLDS.PROCESS_COUNT_MAX) -ForegroundColor $(if($stats.Process_Avg -lt $QOI_THRESHOLDS.PROCESS_COUNT_MAX){'Green'}else{'Yellow'})
    
    Write-Host ""
    Write-Host "🔝 TOP-5 RAM CONSUMERS (at session end)" -ForegroundColor Cyan
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
    foreach ($proc in $stats.Top5_RAM_Final) {
        Write-Host ("  {0,-30} {1,8} MB" -f $proc.ProcessName, $proc.RAM_MB) -ForegroundColor Yellow
    }
    
    Write-Host ""
    Write-Host "🔝 TOP-5 CPU CONSUMERS (at session end)" -ForegroundColor Cyan
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
    foreach ($proc in $stats.Top5_CPU_Final) {
        Write-Host ("  {0,-30} {1,8} sec" -f $proc.ProcessName, $proc.CPU_Sec) -ForegroundColor Yellow
    }
    
    Write-Host ""
    Write-Host "📂 OUTPUT FILES" -ForegroundColor Cyan
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
    Write-Host "✓ Metrics   : $log_file" -ForegroundColor Green
    Write-Host "✓ Processes : $process_log" -ForegroundColor Green
    Write-Host "✓ Metadata  : $metadata_file" -ForegroundColor Green
    
    Write-Host ""
    Write-Host "💡 NEXT STEPS" -ForegroundColor Cyan
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
    Write-Host "1. Use 'Compare Two Sessions' to measure control effectiveness" -ForegroundColor Gray
    Write-Host "2. Review process log to identify services for CDPE" -ForegroundColor Gray
    Write-Host "3. Run with DevMode ON to validate improvements" -ForegroundColor Gray
    Write-Host ""
}

# ==============================================================================
# FUNCTION: COMPARE TWO SESSIONS
# ==============================================================================
function Compare-Sessions {
    Clear-Host
    Write-Host "╔════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
    Write-Host "║        COMPARE TWO SESSIONS                           ║" -ForegroundColor Yellow
    Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Yellow
    
    $logs = Get-ChildItem "$SESSION_FOLDER\*.csv" -ErrorAction SilentlyContinue | 
        Where-Object { $_.Name -notlike "*metadata*" -and $_.Name -notlike "Processes_*" } |
        Sort-Object LastWriteTime -Descending
    
    if ($logs.Count -lt 2) {
        Write-Host ""
        Write-Host "❌ Need at least 2 sessions to compare. Found $($logs.Count)." -ForegroundColor Red
        Write-Host ""
        Write-Host "Run 'Start Performance Log' first to create baseline and treatment sessions." -ForegroundColor Yellow
        Write-Host ""
        return
    }
    
    Write-Host ""
    Write-Host "Available Sessions (newest first):" -ForegroundColor Cyan
    Write-Host ""
    
    for ($i = 0; $i -lt $logs.Count; $i++) {
        $age_hours = [math]::Round(((Get-Date) - $logs[$i].LastWriteTime).TotalHours, 1)
        $age_text = if ($age_hours -lt 1) { "$(([math]::Round(((Get-Date) - $logs[$i].LastWriteTime).TotalMinutes, 0))) min ago" } else { "$age_hours hours ago" }
        
        $meta_file = $logs[$i].FullName -replace '\.csv$', '_metadata.json'
        $meta = if (Test-Path $meta_file) { Get-Content $meta_file -Raw | ConvertFrom-Json } else { $null }
        
        $test_name = if ($meta) { $meta.TestName } else { "Unknown" }
        $test_notes = if ($meta) { $meta.TestNotes } else { "" }
        
        Write-Host "  [$i] $test_name" -ForegroundColor Yellow
        Write-Host "       Notes: $test_notes" -ForegroundColor Gray
        Write-Host "       Time: $age_text" -ForegroundColor Gray
        Write-Host ""
    }
    
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
    Write-Host "Select sessions to compare (baseline vs treatment):" -ForegroundColor White
    Write-Host ""
    [int]$baseline_idx = Read-Host "BASELINE session number (usually your control-OFF session)"
    [int]$treatment_idx = Read-Host "TREATMENT session number (your test session with changes)"
    
    if ($baseline_idx -lt 0 -or $baseline_idx -ge $logs.Count -or $treatment_idx -lt 0 -or $treatment_idx -ge $logs.Count) {
        Write-Host "❌ Invalid selection." -ForegroundColor Red
        return
    }
    
    $baseline_file = $logs[$baseline_idx].FullName
    $treatment_file = $logs[$treatment_idx].FullName
    
    Write-Host ""
    Write-Host "Analyzing..." -ForegroundColor Gray
    
    $b = Import-Csv $baseline_file
    $t = Import-Csv $treatment_file
    
    $baseline_meta = $baseline_file -replace '\.csv$', '_metadata.json'
    $treatment_meta = $treatment_file -replace '\.csv$', '_metadata.json'
    
    $baseline_info = if (Test-Path $baseline_meta) { Get-Content $baseline_meta -Raw | ConvertFrom-Json } else { @{TestName="Baseline"} }
    $treatment_info = if (Test-Path $treatment_meta) { Get-Content $treatment_meta -Raw | ConvertFrom-Json } else { @{TestName="Treatment"} }
    
    # Calculate statistics
    function Get-Stats($data, $column) {
        $values = $data.$column | Where-Object { $_ -ne $null -and $_ -ne "" } | ForEach-Object { [double]$_ }
        return @{
            Avg = [math]::Round(($values | Measure-Object -Average).Average, 1)
            Min = [math]::Round(($values | Measure-Object -Minimum).Minimum, 1)
            Max = [math]::Round(($values | Measure-Object -Maximum).Maximum, 1)
        }
    }
    
    $ram_b = Get-Stats $b 'RAM_InUse_MB'
    $ram_t = Get-Stats $t 'RAM_InUse_MB'
    $cpu_b = Get-Stats $b 'CPU_Load_Pct'
    $cpu_t = Get-Stats $t 'CPU_Load_Pct'
    $pages_b = Get-Stats $b 'Pages_Per_Sec'
    $pages_t = Get-Stats $t 'Pages_Per_Sec'
    $disk_b = Get-Stats $b 'Disk_Idle_Pct'
    $disk_t = Get-Stats $t 'Disk_Idle_Pct'
    $proc_b = Get-Stats $b 'Process_Count'
    $proc_t = Get-Stats $t 'Process_Count'
    
    $ram_delta = $ram_t.Avg - $ram_b.Avg
    $cpu_delta = $cpu_t.Avg - $cpu_b.Avg
    $pages_delta = $pages_t.Avg - $pages_b.Avg
    $disk_delta = $disk_t.Avg - $disk_b.Avg
    $proc_delta = $proc_t.Avg - $proc_b.Avg
    
    # Get process comparisons
    $baseline_processes_file = $baseline_file -replace 'CDPE_', 'Processes_' -replace '\.csv$', '.csv'
    $baseline_processes_file = $baseline_processes_file -replace '\\CDPE_Sessions\\', '\CDPE_Sessions\ProcessSnapshots\'
    
    $treatment_processes_file = $treatment_file -replace 'CDPE_', 'Processes_' -replace '\.csv$', '.csv'
    $treatment_processes_file = $treatment_processes_file -replace '\\CDPE_Sessions\\', '\CDPE_Sessions\ProcessSnapshots\'
    
    # ==============================================================================
    # DISPLAY COMPARISON
    # ==============================================================================
    Clear-Host
    Write-Host "╔════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║      CDPE CONTROL EFFECTIVENESS ANALYSIS              ║" -ForegroundColor Green
    Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Green
    
    Write-Host ""
    Write-Host "📊 SESSIONS COMPARED" -ForegroundColor Cyan
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
    Write-Host "BASELINE  : $($baseline_info.TestName)" -ForegroundColor White
    Write-Host "            $($baseline_info.TestNotes)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "TREATMENT : $($treatment_info.TestName)" -ForegroundColor White
    Write-Host "            $($treatment_info.TestNotes)" -ForegroundColor Gray
    
    Write-Host ""
    Write-Host "📈 PERFORMANCE IMPACT vs BASELINE" -ForegroundColor Cyan
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
    Write-Host "Metric              BASELINE   TREATMENT   DELTA        VERDICT      TARGET" -ForegroundColor White
    Write-Host "──────────────────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
    
    # RAM
    $ram_color = if ($ram_delta -gt 200) { "Red" } elseif ($ram_delta -gt 100) { "Yellow" } else { "Green" }
    $ram_arrow = if ($ram_delta -gt 0) { "↑" } else { "↓" }
    $ram_verdict = if ($ram_delta -gt 200) { "HIGH" } elseif ($ram_delta -gt 100) { "MEDIUM" } elseif ($ram_delta -gt 0) { "LOW" } else { "✓ BETTER" }
    $ram_target_met = $ram_t.Avg -lt $QOI_THRESHOLDS.RAM_USED_MAX_MB
    Write-Host ("RAM (MB)            {0,-10} {1,-11} {2,-12} {3,-12} {4}" -f `
        [math]::Round($ram_b.Avg,0), `
        [math]::Round($ram_t.Avg,0), `
        "$ram_arrow$([math]::Abs([math]::Round($ram_delta,0)))", `
        $ram_verdict, `
        $(if($ram_target_met){"✓ <$($QOI_THRESHOLDS.RAM_USED_MAX_MB)"}else{"⚠️  >$($QOI_THRESHOLDS.RAM_USED_MAX_MB)"})) -ForegroundColor $ram_color
    
    # CPU
    $cpu_color = if ($cpu_delta -gt 20) { "Red" } elseif ($cpu_delta -gt 10) { "Yellow" } else { "Green" }
    $cpu_arrow = if ($cpu_delta -gt 0) { "↑" } else { "↓" }
    $cpu_verdict = if ($cpu_delta -gt 20) { "HIGH" } elseif ($cpu_delta -gt 10) { "MEDIUM" } elseif ($cpu_delta -gt 0) { "LOW" } else { "✓ BETTER" }
    $cpu_target_met = $cpu_t.Avg -lt $QOI_THRESHOLDS.CPU_MAX_PCT
    Write-Host ("CPU (%)             {0,-10} {1,-11} {2,-12} {3,-12} {4}" -f `
        [math]::Round($cpu_b.Avg,1), `
        [math]::Round($cpu_t.Avg,1), `
        "$cpu_arrow$([math]::Abs([math]::Round($cpu_delta,1)))", `
        $cpu_verdict, `
        $(if($cpu_target_met){"✓ <$($QOI_THRESHOLDS.CPU_MAX_PCT)%"}else{"⚠️  >$($QOI_THRESHOLDS.CPU_MAX_PCT)%"})) -ForegroundColor $cpu_color
    
    # Paging
    $pages_color = if ($pages_delta -gt 10) { "Red" } elseif ($pages_delta -gt 5) { "Yellow" } else { "Green" }
    $pages_arrow = if ($pages_delta -gt 0) { "↑" } else { "↓" }
    $pages_verdict = if ($pages_delta -gt 10) { "PRESSURE" } elseif ($pages_delta -gt 5) { "MODERATE" } elseif ($pages_delta -gt 0) { "LOW" } else { "✓ BETTER" }
    $pages_target_met = $pages_t.Avg -lt $QOI_THRESHOLDS.PAGES_MAX
    Write-Host ("Paging (p/s)        {0,-10} {1,-11} {2,-12} {3,-12} {4}" -f `
        [math]::Round($pages_b.Avg,1), `
        [math]::Round($pages_t.Avg,1), `
        "$pages_arrow$([math]::Abs([math]::Round($pages_delta,1)))", `
        $pages_verdict, `
        $(if($pages_target_met){"✓ <$($QOI_THRESHOLDS.PAGES_MAX)"}else{"⚠️  >$($QOI_THRESHOLDS.PAGES_MAX)"})) -ForegroundColor $pages_color
    
    # Process Count
    $proc_color = if ($proc_delta -gt 10) { "Yellow" } elseif ($proc_delta -lt -10) { "Green" } else { "Gray" }
    $proc_arrow = if ($proc_delta -gt 0) { "↑" } else { "↓" }
    $proc_target_met = $proc_t.Avg -lt $QOI_THRESHOLDS.PROCESS_COUNT_MAX
    Write-Host ("Process Count       {0,-10} {1,-11} {2,-12} {3,-12} {4}" -f `
        [math]::Round($proc_b.Avg,0), `
        [math]::Round($proc_t.Avg,0), `
        "$proc_arrow$([math]::Abs([math]::Round($proc_delta,0)))", `
        $(if($proc_delta -lt -10){"✓ FEWER"}elseif($proc_delta -gt 10){"MORE"}else{"STABLE"}), `
        $(if($proc_target_met){"✓ <$($QOI_THRESHOLDS.PROCESS_COUNT_MAX)"}else{"⚠️  >$($QOI_THRESHOLDS.PROCESS_COUNT_MAX)"})) -ForegroundColor $proc_color
    
    # Disk
    $disk_color = if ($disk_delta -lt -20) { "Red" } elseif ($disk_delta -lt -10) { "Yellow" } else { "Green" }
    $disk_arrow = if ($disk_delta -gt 0) { "↑" } else { "↓" }
    $disk_target_met = $disk_t.Avg -gt $QOI_THRESHOLDS.DISK_IDLE_MIN_PCT
    Write-Host ("Disk Idle (%)       {0,-10} {1,-11} {2,-12} {3,-12} {4}" -f `
        [math]::Round($disk_b.Avg,1), `
        [math]::Round($disk_t.Avg,1), `
        "$disk_arrow$([math]::Abs([math]::Round($disk_delta,1)))", `
        $(if($disk_delta -lt -20){"BUSY"}elseif($disk_delta -lt 0){"OK"}else{"✓ IDLE"}), `
        $(if($disk_target_met){"✓ >$($QOI_THRESHOLDS.DISK_IDLE_MIN_PCT)%"}else{"⚠️  <$($QOI_THRESHOLDS.DISK_IDLE_MIN_PCT)%"})) -ForegroundColor $disk_color
    
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
    
    # ==============================================================================
    # TOP PROCESSES COMPARISON
    # ==============================================================================
    if ((Test-Path $baseline_processes_file) -and (Test-Path $treatment_processes_file)) {
        Write-Host ""
        Write-Host "🔝 TOP-5 RAM CONSUMERS (Treatment Session)" -ForegroundColor Cyan
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
        
        if ($treatment_info.Top5_RAM_Final) {
            foreach ($proc in $treatment_info.Top5_RAM_Final) {
                Write-Host ("  {0,-35} {1,8} MB" -f $proc.ProcessName, $proc.RAM_MB) -ForegroundColor Yellow
            }
        } else {
            Write-Host "  (Process snapshot data not available)" -ForegroundColor Gray
        }
        
        Write-Host ""
        Write-Host "💡 Control Opportunity: Review these processes for CDPE eligibility" -ForegroundColor Cyan
        Write-Host "   • Identify non-essential services from this list" -ForegroundColor Gray
        Write-Host "   • Target services consuming >100 MB RAM" -ForegroundColor Gray
        Write-Host "   • Re-test with these services disabled" -ForegroundColor Gray
    }
    
    # ==============================================================================
    # CONTROL EFFECTIVENESS ASSESSMENT
    # ==============================================================================
    Write-Host ""
    Write-Host "🎯 CONTROL EFFECTIVENESS ASSESSMENT" -ForegroundColor Cyan
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
    
    $targets_met = 0
    $targets_total = 5
    
    if ($ram_target_met) { $targets_met++ }
    if ($cpu_target_met) { $targets_met++ }
    if ($pages_target_met) { $targets_met++ }
    if ($proc_target_met) { $targets_met++ }
    if ($disk_target_met) { $targets_met++ }
    
    $effectiveness_pct = [math]::Round(($targets_met / $targets_total) * 100, 0)
    
    Write-Host ""
    Write-Host "QoI Targets Met  : $targets_met / $targets_total ($effectiveness_pct%)" -ForegroundColor $(if($effectiveness_pct -ge 80){'Green'}elseif($effectiveness_pct -ge 60){'Yellow'}else{'Red'})
    
    # Calculate control effectiveness score
    $control_score = 0
    
    # Negative deltas are good (resource reduction)
    if ($ram_delta -lt -100) { $control_score += 3 }
    elseif ($ram_delta -lt -50) { $control_score += 2 }
    elseif ($ram_delta -lt 0) { $control_score += 1 }
    
    if ($cpu_delta -lt -10) { $control_score += 3 }
    elseif ($cpu_delta -lt -5) { $control_score += 2 }
    elseif ($cpu_delta -lt 0) { $control_score += 1 }
    
    if ($proc_delta -lt -10) { $control_score += 2 }
    elseif ($proc_delta -lt 0) { $control_score += 1 }
    
    if ($pages_delta -lt -5) { $control_score += 2 }
    elseif ($pages_delta -lt 0) { $control_score += 1 }
    
    Write-Host "Control Score    : $control_score / 11 points" -ForegroundColor White
    Write-Host ""
    
    if ($control_score -ge 8) {
        Write-Host "✓ EXCELLENT CONTROL EFFECTIVENESS" -ForegroundColor Green
        Write-Host "  Treatment successfully reduces resource usage vs baseline." -ForegroundColor Green
        Write-Host "  Continue with current CDPE configuration." -ForegroundColor Gray
    }
    elseif ($control_score -ge 5) {
        Write-Host "✓ GOOD CONTROL EFFECTIVENESS" -ForegroundColor Green
        Write-Host "  Treatment shows resource savings vs baseline." -ForegroundColor Green
        Write-Host "  Consider additional service optimization for further gains." -ForegroundColor Gray
    }
    elseif ($control_score -ge 2) {
        Write-Host "→ MODERATE EFFECTIVENESS" -ForegroundColor Yellow
        Write-Host "  Some resource reduction vs baseline." -ForegroundColor Yellow
        Write-Host "  Review top-5 consumers above to identify additional targets." -ForegroundColor Gray
    }
    elseif ($ram_delta -gt 100 -or $cpu_delta -gt 10) {
        Write-Host "⚠️  PERFORMANCE REGRESSION DETECTED" -ForegroundColor Red
        Write-Host "  Treatment uses MORE resources than baseline." -ForegroundColor Red
        Write-Host "  Possible causes:" -ForegroundColor Yellow
        Write-Host "    • Different workload (video call vs baseline)" -ForegroundColor Gray
        Write-Host "    • Services re-enabled automatically" -ForegroundColor Gray
        Write-Host "    • Additional applications running" -ForegroundColor Gray
        Write-Host "  Review process logs to identify culprits." -ForegroundColor Gray
    }
    else {
        Write-Host "→ NO SIGNIFICANT CHANGE" -ForegroundColor Gray
        Write-Host "  Both sessions use similar resources." -ForegroundColor Gray
        Write-Host "  Controls may not be active, or workloads are equivalent." -ForegroundColor Gray
    }
    
    # ==============================================================================
    # SAVE COMPARISON REPORT
    # ==============================================================================
    Write-Host ""
    Write-Host "💾 Generating comparison report..." -ForegroundColor Gray
    
    $report_timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $report_file = "$COMPARE_FOLDER\Comparison_${report_timestamp}.txt"
    
    $report = @"
╔════════════════════════════════════════════════════════════════════════════╗
║          CDPE CONTROL EFFECTIVENESS ANALYSIS REPORT                       ║
╚════════════════════════════════════════════════════════════════════════════╝

Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

════════════════════════════════════════════════════════════════════════════
SESSIONS COMPARED
════════════════════════════════════════════════════════════════════════════

BASELINE SESSION:
  Name        : $($baseline_info.TestName)
  Description : $($baseline_info.TestNotes)
  File        : $baseline_file

TREATMENT SESSION:
  Name        : $($treatment_info.TestName)
  Description : $($treatment_info.TestNotes)
  File        : $treatment_file

════════════════════════════════════════════════════════════════════════════
PERFORMANCE METRICS COMPARISON
════════════════════════════════════════════════════════════════════════════

Metric              Baseline    Treatment   Delta       Target Met?
────────────────────────────────────────────────────────────────────────────
RAM Usage (MB)      $([math]::Round($ram_b.Avg,0))       $([math]::Round($ram_t.Avg,0))       $ram_arrow$([math]::Abs([math]::Round($ram_delta,0)))      $(if($ram_target_met){"✓ YES (<$($QOI_THRESHOLDS.RAM_USED_MAX_MB) MB)"}else{"✗ NO (>$($QOI_THRESHOLDS.RAM_USED_MAX_MB) MB)"})
CPU Load (%)        $([math]::Round($cpu_b.Avg,1))        $([math]::Round($cpu_t.Avg,1))        $cpu_arrow$([math]::Abs([math]::Round($cpu_delta,1)))      $(if($cpu_target_met){"✓ YES (<$($QOI_THRESHOLDS.CPU_MAX_PCT)%)"}else{"✗ NO (>$($QOI_THRESHOLDS.CPU_MAX_PCT)%)"})
Paging (p/s)        $([math]::Round($pages_b.Avg,1))        $([math]::Round($pages_t.Avg,1))        $pages_arrow$([math]::Abs([math]::Round($pages_delta,1)))      $(if($pages_target_met){"✓ YES (<$($QOI_THRESHOLDS.PAGES_MAX) p/s)"}else{"✗ NO (>$($QOI_THRESHOLDS.PAGES_MAX) p/s)"})
Process Count       $([math]::Round($proc_b.Avg,0))        $([math]::Round($proc_t.Avg,0))        $proc_arrow$([math]::Abs([math]::Round($proc_delta,0)))      $(if($proc_target_met){"✓ YES (<$($QOI_THRESHOLDS.PROCESS_COUNT_MAX))"}else{"✗ NO (>$($QOI_THRESHOLDS.PROCESS_COUNT_MAX))"})
Disk Idle (%)       $([math]::Round($disk_b.Avg,1))        $([math]::Round($disk_t.Avg,1))        $disk_arrow$([math]::Abs([math]::Round($disk_delta,1)))      $(if($disk_target_met){"✓ YES (>$($QOI_THRESHOLDS.DISK_IDLE_MIN_PCT)%)"}else{"✗ NO (<$($QOI_THRESHOLDS.DISK_IDLE_MIN_PCT)%)"})

════════════════════════════════════════════════════════════════════════════
PEAK VALUES
════════════════════════════════════════════════════════════════════════════
RAM Peak (MB)       $([math]::Round($ram_b.Max,0))       $([math]::Round($ram_t.Max,0))       $(if($ram_t.Max -lt $ram_b.Max){"↓ BETTER"}elseif($ram_t.Max -gt $ram_b.Max){"↑ WORSE"}else{"→ SAME"})
CPU Peak (%)        $([math]::Round($cpu_b.Max,1))        $([math]::Round($cpu_t.Max,1))        $(if($cpu_t.Max -lt $cpu_b.Max){"↓ BETTER"}elseif($cpu_t.Max -gt $cpu_b.Max){"↑ WORSE"}else{"→ SAME"})
Paging Peak (p/s)   $([math]::Round($pages_b.Max,1))        $([math]::Round($pages_t.Max,1))        $(if($pages_t.Max -lt $pages_b.Max){"↓ BETTER"}elseif($pages_t.Max -gt $pages_b.Max){"↑ WORSE"}else{"→ SAME"})

════════════════════════════════════════════════════════════════════════════
CONTROL EFFECTIVENESS ASSESSMENT
════════════════════════════════════════════════════════════════════════════

QoI Targets Met      : $targets_met / $targets_total ($effectiveness_pct%)
Control Score        : $control_score / 11 points

Overall Verdict:
$(if ($control_score -ge 8) {
"✓ EXCELLENT CONTROL EFFECTIVENESS
  Treatment successfully reduces resource usage vs baseline.
  CDPE controls are highly effective. Continue with current configuration."
}
elseif ($control_score -ge 5) {
"✓ GOOD CONTROL EFFECTIVENESS
  Treatment shows measurable resource savings vs baseline.
  CDPE controls are working. Consider additional optimization opportunities."
}
elseif ($control_score -ge 2) {
"→ MODERATE EFFECTIVENESS
  Some resource reduction vs baseline observed.
  Review top consumers to identify additional service optimization targets."
}
elseif ($ram_delta -gt 100 -or $cpu_delta -gt 10) {
"⚠️  PERFORMANCE REGRESSION DETECTED
  Treatment uses MORE resources than baseline.
  
  Possible causes:
    • Different workload intensity (video call vs idle)
    • Services automatically re-enabled
    • Additional applications running in treatment session
    • Windows background tasks activated
  
  Actions:
    1. Review process snapshots to identify resource hogs
    2. Verify service disable script ran successfully
    3. Ensure comparable workloads between sessions
    4. Consider scheduled task to enforce service state"
}
else {
"→ NO SIGNIFICANT CHANGE
  Both sessions use similar resources.
  Controls may not be active, or workloads are functionally equivalent."
})

════════════════════════════════════════════════════════════════════════════
TOP-5 RAM CONSUMERS (Treatment Session)
════════════════════════════════════════════════════════════════════════════
$(if ($treatment_info.Top5_RAM_Final) {
    ($treatment_info.Top5_RAM_Final | ForEach-Object { "  $($_.ProcessName.PadRight(40)) $($_.RAM_MB) MB" }) -join "`n"
} else {
    "  (Process snapshot data not available)"
})

════════════════════════════════════════════════════════════════════════════
RECOMMENDATIONS
════════════════════════════════════════════════════════════════════════════

$(if ($control_score -ge 5) {
"✓ Current controls are effective. Maintain configuration.
  
  Optional next steps:
    • Document effective service disable list
    • Create scheduled task to enforce service state
    • Test sustained 3-hour session to verify stability"
}
elseif ($ram_t.Avg -gt $QOI_THRESHOLDS.RAM_USED_MAX_MB -or $cpu_t.Avg -gt $QOI_THRESHOLDS.CPU_MAX_PCT) {
"⚠️  Performance targets not met. Additional optimization required.
  
  High-impact actions:
    1. Review top-5 RAM consumers above
    2. Identify non-essential services from process list
    3. Target services using >100 MB RAM for CDPE
    4. Common candidates:
       • Windows Search (WSearch) - 80-150 MB
       • Telemetry (DiagTrack, dmwappushservice)
       • Xbox services
       • OEM bloat (HP/Dell services)
    5. Re-test with expanded disable list"
}
else {
"→ Workloads may not be comparable.
  
  Ensure consistent testing:
    • Run baseline during similar time of day
    • Match application workload (video call duration, browser tabs, etc.)
    • Verify service state before each session
    • Allow 5 minutes for system to stabilize after boot"
})

════════════════════════════════════════════════════════════════════════════
FILES REFERENCED
════════════════════════════════════════════════════════════════════════════
Baseline CSV       : $baseline_file
Treatment CSV      : $treatment_file
Baseline Processes : $(if (Test-Path $baseline_processes_file) {$baseline_processes_file} else {"Not captured"})
Treatment Processes: $(if (Test-Path $treatment_processes_file) {$treatment_processes_file} else {"Not captured"})

This Report        : $report_file

════════════════════════════════════════════════════════════════════════════
END OF REPORT
════════════════════════════════════════════════════════════════════════════
"@
    
    $report | Out-File $report_file -Encoding utf8
    
    Write-Host ""
    Write-Host "✓ Full report saved: $report_file" -ForegroundColor Green
    Write-Host ""
}
