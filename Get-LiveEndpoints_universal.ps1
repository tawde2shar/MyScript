# ================================
# Script: Get-LiveEndpoints.ps1
# Purpose: Find live endpoints by IP range, hostnames, or text file (auto-detect PS version)
# ================================

param(
    [string[]]$Hostnames,                   # e.g. "server1","server2","8.8.8.8"
    [string]$IPRange,                       # e.g. "192.168.1.1-192.168.1.254"
    [string]$InputFile,                     # Path to text file with endpoints (one per line)
    [int]$Timeout = 1000,                   # Timeout in ms
    [int]$ThrottleLimit = 50                # Parallel limit
)

function Get-IPRange {
    param([string]$Range)

    $parts = $Range -split "-"
    $startIP = [System.Net.IPAddress]::Parse($parts[0])
    $endIP   = [System.Net.IPAddress]::Parse($parts[1])

    $startBytes = $startIP.GetAddressBytes()
    $endBytes   = $endIP.GetAddressBytes()

    [Array]::Reverse($startBytes)
    [Array]::Reverse($endBytes)

    $start = [BitConverter]::ToUInt32($startBytes,0)
    $end   = [BitConverter]::ToUInt32($endBytes,0)

    for ($i=$start; $i -le $end; $i++) {
        $bytes = [BitConverter]::GetBytes($i)
        [Array]::Reverse($bytes)
        [System.Net.IPAddress]::new($bytes)
    }
}

# Collect targets
$Targets = @()

if ($Hostnames) { $Targets += $Hostnames }
if ($IPRange)   { $Targets += Get-IPRange -Range $IPRange }
if ($InputFile -and (Test-Path $InputFile)) {
    $Targets += Get-Content -Path $InputFile | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
}

if (-not $Targets -or $Targets.Count -eq 0) {
    Write-Host "Please specify -Hostnames, -IPRange, or -InputFile"
    exit
}

Write-Host "Scanning $($Targets.Count) endpoints..."

# Detect PS version
$PSMajor = $PSVersionTable.PSVersion.Major

if ($PSMajor -ge 7) {
    Write-Host "Using PowerShell 7+ parallel scanning..."
    $LiveEndpoints = $Targets | ForEach-Object -Parallel {
        try {
            if (Test-Connection -ComputerName $_ -Count 1 -Quiet -ErrorAction SilentlyContinue) {
                $_
            }
        } catch {}
    } -ThrottleLimit $using:ThrottleLimit
}
else {
    Write-Host "Using PowerShell 5.1 job-based scanning..."
    $Jobs = foreach ($Target in $Targets) {
        Start-Job -ScriptBlock {
            param($Target)
            if (Test-Connection -ComputerName $Target -Count 1 -Quiet -ErrorAction SilentlyContinue) {
                $Target
            }
        } -ArgumentList $Target
    }

    # Wait for all jobs to finish
    $null = Wait-Job -Job $Jobs
    $LiveEndpoints = $Jobs | Receive-Job | Where-Object { $_ }
    $Jobs | Remove-Job -Force
}

# Output only live endpoints
$LiveEndpoints
