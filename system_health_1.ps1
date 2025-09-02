# System_Utilization.ps1
# Output CPU, Memory, and Disk utilization in PRTG JSON format

Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process -Force
$ErrorActionPreference = "Stop"

# --- CPU Utilization ---
$cpuLoad = (Get-Counter '\Processor(_Total)\% Processor Time').CounterSamples.CookedValue
$cpuLoad = [math]::Round($cpuLoad, 2)

# --- Memory Utilization ---
$os = Get-CimInstance Win32_OperatingSystem
$totalMem = [math]::Round($os.TotalVisibleMemorySize / 1KB, 2)   # MB
$freeMem  = [math]::Round($os.FreePhysicalMemory / 1KB, 2)       # MB
$usedMem  = $totalMem - $freeMem
$memPct   = [math]::Round(($usedMem / $totalMem) * 100, 2)

# --- Disk Utilization ---
$disks = Get-CimInstance Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 }

$results = @()

# Add CPU
$results += @{
    channel = "CPU Utilization (%)"
    value   = $cpuLoad
    float   = 1
    unit    = "Percent"
}

# Add Memory
$results += @{
    channel = "Memory Utilization (%)"
    value   = $memPct
    float   = 1
    unit    = "Percent"
}

# Add Disk Info
foreach ($disk in $disks) {
    $sizeGB = [math]::Round($disk.Size / 1GB, 2)
    $freeGB = [math]::Round($disk.FreeSpace / 1GB, 2)
    $usedGB = $sizeGB - $freeGB
    $diskPct = if ($sizeGB -gt 0) { [math]::Round(($usedGB / $sizeGB) * 100, 2) } else { 0 }

    # Utilization %
    $results += @{
        channel = "Disk $($disk.DeviceID) Utilization (%)"
        value   = $diskPct
        float   = 1
        unit    = "Percent"
    }

    # Total GB
    $results += @{
        channel = "Disk $($disk.DeviceID) Total (GB)"
        value   = $sizeGB
        float   = 1
        unit    = "Custom"
    }

    # Free GB
    $results += @{
        channel = "Disk $($disk.DeviceID) Free (GB)"
        value   = $freeGB
        float   = 1
        unit    = "Custom"
    }
}

# Wrap in PRTG structure
$output = @{
    prtg = @{
        result = $results
        text   = "System Utilization collected successfully"
    }
}

# Convert to JSON (strict)
$json = $output | ConvertTo-Json -Depth 4 -Compress

# Output clean JSON
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Write-Output $json
