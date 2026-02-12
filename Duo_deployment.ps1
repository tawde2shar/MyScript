Write-Output "Starting Duo Windows Logon deployment..."

# =====================================================
# VARIABLES
# =====================================================
$TempDir = "C:\Temp"

$VcUrl       = "https://aka.ms/vc14/vc_redist.x64.exe"
$VcInstaller = "$TempDir\vc_redist.x64.exe"

$DuoUrl      = "https://dl.duosecurity.com/duo-win-login-latest.exe"
$DuoExe      = "$TempDir\duo-win-login-latest.exe"

$DuoRegPath  = "HKLM:\SOFTWARE\Duo Security\DuoCredProv"

$IKey    = "thisistestIkEyfordemo"
$SKey    = "thisistestskeyfordemo"
$DuoHost = "api-elevate.duosecurity.com"

# =====================================================
# STEP 0: ENSURE TEMP DIRECTORY
# =====================================================
if (-not (Test-Path $TempDir)) {
    New-Item -Path $TempDir -ItemType Directory -Force | Out-Null
}

# =====================================================
# STEP 1: VC++ REDISTRIBUTABLE (2015–2022 x64)
# =====================================================
Write-Output "Checking VC++ Redistributable..."

$VcInstalled = Get-ItemProperty `
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" `
    -ErrorAction SilentlyContinue |
    Where-Object {
        $_.DisplayName -match "Microsoft Visual C\+\+ 2015-2022 Redistributable \(x64\)"
    }

if (-not $VcInstalled) {

    Write-Output "Installing VC++ Redistributable..."

    Invoke-WebRequest -Uri $VcUrl -OutFile $VcInstaller -UseBasicParsing

    $vcProc = Start-Process -FilePath $VcInstaller `
        -ArgumentList "/install /quiet /norestart" `
        -Wait `
        -PassThru

    Write-Output "VC++ installer exit code: $($vcProc.ExitCode)"

    Remove-Item $VcInstaller -Force -ErrorAction SilentlyContinue
}
else {
    Write-Output "VC++ Redistributable already installed."
}

# =====================================================
# STEP 2: DUO WINDOWS LOGON (EXE INSTALLER)
# =====================================================
Write-Output "Checking Duo Windows Logon installation..."

$DuoInstalled = Test-Path "C:\Program Files\Duo Security\WindowsLogon\DuoCredProv.dll"

if (-not $DuoInstalled) {

    Write-Output "Downloading Duo installer..."
    Invoke-WebRequest -Uri $DuoUrl -OutFile $DuoExe -UseBasicParsing

    Write-Output "Installing Duo Windows Logon silently..."

    $duoProc = Start-Process -FilePath $DuoExe `
        -ArgumentList '/s /v"/qn /norestart"' `
        -Wait `
        -PassThru

    Write-Output "Duo installer exit code: $($duoProc.ExitCode)"

    if ($duoProc.ExitCode -ne 0 -and $duoProc.ExitCode -ne 3010) {
        Write-Output "ERROR: Duo installation failed."
        exit 1
    }

    Remove-Item $DuoExe -Force -ErrorAction SilentlyContinue
}
else {
    Write-Output "Duo Windows Logon already installed."
}

# =====================================================
# STEP 3: CONFIGURE DUO
# =====================================================
Write-Output "Configuring Duo Authentication..."

New-Item -Path $DuoRegPath -Force | Out-Null

Set-ItemProperty -Path $DuoRegPath -Name "IKey"     -Value $IKey
Set-ItemProperty -Path $DuoRegPath -Name "SKey"     -Value $SKey
Set-ItemProperty -Path $DuoRegPath -Name "Host"     -Value $DuoHost
Set-ItemProperty -Path $DuoRegPath -Name "AutoPush" -Value 1 -Type DWord
Set-ItemProperty -Path $DuoRegPath -Name "FailOpen" -Value 0 -Type DWord

Write-Output "Duo configuration completed."
Write-Output "Deployment finished successfully."
