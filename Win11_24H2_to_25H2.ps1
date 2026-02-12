# ================================
# COPY PATCHES FROM NETWORK SHARE
# (DO NOT MODIFY – AS REQUESTED)
# ================================

$Username = "india\ivantiadmin"
$Password = ConvertTo-SecureString "qazwsx@123" -AsPlainText -Force
$Credential = New-Object System.Management.Automation.PSCredential ($Username, $Password)

New-PSDrive -Name "X" -PSProvider FileSystem -Root "\\WIN11OFF\patch\25H2" -Credential $Credential

Copy-Item -Path "X:\*" -Destination "C:\25H2" -Recurse -Force

Remove-PSDrive X


# ================================
# INSTALL PATCHES SILENTLY
# ================================

$UpdatesPath = "C:\25H2"

$Patches = @(
    "windows11.0-kb5078127-x64.msu",
    "windows11.0-kb5054156-x64.msu"
)

foreach ($Patch in $Patches) {
    $FullPath = Join-Path $UpdatesPath $Patch

    if (Test-Path $FullPath) {
        Write-Host "Installing $Patch ..." -ForegroundColor Cyan

        $process = Start-Process -FilePath "wusa.exe" `
            -ArgumentList "`"$FullPath`" /quiet /norestart" `
            -Wait -PassThru -NoNewWindow

        switch ($process.ExitCode) {
            0 {
                Write-Host "$Patch installed successfully." -ForegroundColor Green
            }
            3010 {
                Write-Host "$Patch installed successfully. Reboot required." -ForegroundColor Yellow
            }
            2359302 {
                Write-Host "$Patch is already installed." -ForegroundColor Gray
            }
            default {
                Write-Host "Installation failed for $Patch. Exit Code: $($process.ExitCode)" -ForegroundColor Red
            }
        }
    }
    else {
        Write-Host "Patch not found: $FullPath" -ForegroundColor Red
    }
}

Write-Host "Patch installation process completed." -ForegroundColor Cyan
