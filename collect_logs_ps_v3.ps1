# Initialize result object
$result = [ordered]@{
    ScriptName = "SupportToolkit Collection"
    StartTime  = (Get-Date).ToString("o")
    Steps      = @()
    Status     = "In Progress"
    EndTime    = $null
    Error      = $null
}

try {
    # Step 1: Create temp folder
    $step = [ordered]@{
        StepName = "Create Temp Folder"
        Status   = "Success"
        Message  = ""
    }

    $TempPath = "C:\temp"
    if (-not (Test-Path $TempPath)) {
        New-Item -Path $TempPath -ItemType Directory | Out-Null
    }

    $result.Steps += $step

    # Step 2: Remove existing SupportToolkit folder
    $step = [ordered]@{
        StepName = "Remove Existing SupportToolkit Folder"
        Status   = "Success"
        Message  = ""
    }

    $ExtractPath = "$TempPath\SupportToolkit"
    if (Test-Path $ExtractPath) {
        Remove-Item -Path $ExtractPath -Recurse -Force
        $step.Message = "Existing SupportToolkit folder deleted."
    }
    else {
        $step.Message = "No existing SupportToolkit folder found."
    }

    $result.Steps += $step

    # Step 3: Download zip
    $step = [ordered]@{
        StepName = "Download SupportToolkit.zip"
        Status   = "Success"
        Message  = ""
    }

    $ZipPath = "$TempPath\SupportToolkit.zip"
    $DownloadUrl = "https://forums.ivanti.com/s/sfsites/c/sfc/servlet.shepherd/document/download/069UL00000VYjLtYAL"

    Invoke-WebRequest -Uri $DownloadUrl -OutFile $ZipPath
    $result.Steps += $step

    # Step 4: Extract zip
    $step = [ordered]@{
        StepName = "Extract SupportToolkit"
        Status   = "Success"
        Message  = ""
    }

    Expand-Archive -Path $ZipPath -DestinationPath $ExtractPath -Force
    $result.Steps += $step

    # Step 5: Execute SupportToolkit
    $step = [ordered]@{
        StepName = "Execute SupportToolkit"
        Status   = "Success"
        Message  = ""
    }

    Start-Process -FilePath "$ExtractPath\SUPPORTTOOLKIT.exe" `
        -ArgumentList "/nogui /quiet /accepteula /out:$ExtractPath" `
        -Wait

    $result.Steps += $step
    $result.Status = "Completed"
}
catch {
    $result.Status = "Failed"
    $result.Error  = $_.Exception.Message

    $result.Steps += [ordered]@{
        StepName = "Error"
        Status   = "Failed"
        Message  = $_.Exception.Message
    }
}
finally {
    $result.EndTime = (Get-Date).ToString("o")

    # Direct JSON output to console / pipeline
    $result | ConvertTo-Json -Depth 5
}