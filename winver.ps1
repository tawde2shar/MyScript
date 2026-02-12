# Get Windows version details (same source as winver)
$cv = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"

$osName   = $cv.ProductName
$version  = $cv.DisplayVersion
$build    = $cv.CurrentBuild
$ubr      = $cv.UBR

# Check upgrade success
if ($version -eq "25H2") {
    $status  = "Success"
    $message = "Windows 11 upgraded successfully to $version"
} else {
    $status  = "Failed"
    $message = "Windows 11 upgrade failed or incomplete. Current version is $version"
}

# Prepare JSON output
$result = [ordered]@{
    Status        = $status
    Message       = $message
    ProductName   = $osName
    DisplayVersion= $version
    Build         = "$build.$ubr"
    Timestamp     = (Get-Date).ToString("o")
}

# Output JSON to console
$result | ConvertTo-Json -Depth 3
