# ================================
# Script: Get-LiveEndpoints.ps1
# Purpose: Find live and unreachable endpoints by IP range, hostnames, or text file
# ================================

param(
    [string[]]$Hostnames,                   # e.g. "server1","server2","8.8.8.8"
    [string]$IPRange,                       # e.g. "192.168.1.1-192.168.1.254"
    [string]$InputFile,                     # Path to text file with endpoints (one per line)
    [int]$Timeout = 1000,                   # Timeout in ms (not directly used by Test-Connection in this script)
    [int]$ThrottleLimit = 50                # Parallel limit (PS7)
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
        [System.Net.IPAddress]::new($bytes).ToString()
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
    exit 1
}

Write-Host "Scanning $($Targets.Count) endpoints..."

# Detect PS version
$PSMajor = $PSVersionTable.PSVersion.Major

if ($PSMajor -ge 7) {
    Write-Host "Using PowerShell 7+ parallel scanning..."

    # Run parallel and return objects with Target and Status
    $Results = $Targets | ForEach-Object -Parallel {
        param($t)
        try {
            $alive = Test-Connection -ComputerName $t -Count 1 -Quiet -ErrorAction SilentlyContinue
        } catch {
            $alive = $false
        }
        [pscustomobject]@{
            Target = $t
            Status = if ($alive) { 'Live' } else { 'Unreachable' }
        }
    } -ArgumentList $_ -ThrottleLimit $ThrottleLimit

    # In some PS7 builds you may need to reference using: $using:ThrottleLimit
    # If above -ArgumentList syntax doesn't work, use:
    # $Results = $Targets | ForEach-Object -Parallel {
    #     $t = $_
    #     $alive = Test-Connection -ComputerName $t -Count 1 -Quiet -ErrorAction SilentlyContinue
    #     [pscustomobject]@{ Target = $t; Status = if ($alive) {'Live'} else {'Unreachable'} }
    # } -ThrottleLimit $using:ThrottleLimit

    $LiveEndpoints = $Results | Where-Object { $_.Status -eq 'Live' } | Select-Object -ExpandProperty Target
    $UnreachableEndpoints = $Results | Where-Object { $_.Status -eq 'Unreachable' } | Select-Object -ExpandProperty Target
}
else {
    Write-Host "Using PowerShell 5.1 job-based scanning..."
    $Jobs = foreach ($Target in $Targets) {
        Start-Job -ScriptBlock {
            param($t)
            try {
                $alive = Test-Connection -ComputerName $t -Count 1 -Quiet -ErrorAction SilentlyContinue
            } catch {
                $alive = $false
            }
            [pscustomobject]@{
                Target = $t
                Status = if ($alive) { 'Live' } else { 'Unreachable' }
            }
        } -ArgumentList $Target
    }

    # Wait for all jobs to finish
    $null = Wait-Job -Job $Jobs

    $Results = $Jobs | Receive-Job
    $Jobs | Remove-Job -Force

    $LiveEndpoints = $Results | Where-Object { $_.Status -eq 'Live' } | Select-Object -ExpandProperty Target
    $UnreachableEndpoints = $Results | Where-Object { $_.Status -eq 'Unreachable' } | Select-Object -ExpandProperty Target
}

# Output: both lists
Write-Host "---- Live endpoints ($($LiveEndpoints.Count)) ----"
$LiveEndpoints | ForEach-Object { Write-Host $_ }

Write-Host "---- Unreachable endpoints ($($UnreachableEndpoints.Count)) ----"
$UnreachableEndpoints | ForEach-Object { Write-Host $_ }

# Return objects as a hashtable for further automation (if caller wants to capture)
@{
    Live = $LiveEndpoints
    Unreachable = $UnreachableEndpoints
}
