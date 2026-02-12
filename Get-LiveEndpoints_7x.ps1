# ================================
# Script: Get-LiveEndpoints.ps1
# Purpose: Find live endpoints by IP range or hostnames (parallel execution)
# ================================

param(
    [string[]]$Hostnames,                   # e.g. "server1","server2","8.8.8.8"
    [string]$IPRange,                       # e.g. "192.168.1.1-192.168.1.254"
    [int]$Timeout = 1000                    # Timeout in ms
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

if ($Hostnames) {
    $Targets += $Hostnames
}

if ($IPRange) {
    $Targets += Get-IPRange -Range $IPRange
}

if (-not $Targets) {
    Write-Host "Please specify -Hostnames or -IPRange"
    exit
}

Write-Host "Scanning $($Targets.Count) endpoints in parallel..."

# Run in parallel (requires PowerShell 7+)
$LiveEndpoints = $Targets | ForEach-Object -Parallel {
    try {
        if (Test-Connection -ComputerName $_ -Count 1 -Quiet -TimeoutSeconds 1) {
            $_
        }
    } catch {}
} -ThrottleLimit 50   # Adjust for performance

# Output only live endpoints
$LiveEndpoints
