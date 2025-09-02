# USB_Device_Status.ps1
# Output each USB device as its own PRTG channel in JSON format

$ErrorActionPreference = "Stop"

# Get connected USB devices (USB only)
$usbDevices = Get-PnpDevice -PresentOnly | Where-Object { $_.InstanceId -match '^USB' }

# Build results
$results = @()

if ($usbDevices) {
    $index = 1
    foreach ($device in $usbDevices) {
        $name = $device.FriendlyName
        if ([string]::IsNullOrWhiteSpace($name)) { $name = $device.InstanceId }

        # Ensure uniqueness by appending index if duplicate
        $uniqueName = "$name [$index]"
        $results += @{ channel = $uniqueName; value = 1 }

        $index++
    }
} else {
    $results += @{ channel = "No USB Devices"; value = 0 }
}

# Count them
$deviceCount = ($usbDevices | Measure-Object).Count

# Wrap in PRTG structure with <text> message
$output = @{
    prtg = @{
        result = $results
        text   = "$deviceCount USB device(s) currently connected"
    }
}

# Convert to JSON exactly in PRTG format
$json = $output | ConvertTo-Json -Depth 4 -Compress

# Output clean JSON
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Write-Output $json
