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
if ($Hostnames) { $Targets += $Hostnames }
if ($IPRange)   { $Targets += Get-IPRange -Range $IPRange }
if (-not $Targets) { Write-Host "Please specify -Hostnames or -IPRange"; exit }

Write-Host "Scanning $($Targets.Count) endpoints in parallel..."

# Use jobs instead of -Parallel
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

# Collect results
$LiveEndpoints = $Jobs | Receive-Job | Where-Object { $_ }
$Jobs | Remove-Job -Force

# Output only live endpoints
$LiveEndpoints
