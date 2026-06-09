#Requires -RunAsAdministrator

# Ask for confirmation
Write-Host "=== Windows Setup Automation Script ==="
$choice = Read-Host "This might take a while. Continue? (y/n)"
if ($choice -ne "y") { exit }

function Log($msg) {
    Write-Host ("[{0:HH:mm:ss}] {1}" -f (Get-Date), "$msg")
}

#Fix broken safemode
Log "Fixing broken safemode..."
bcdedit /set {default} bootmenupolicy legacy -ErrorAction -SilentlyContinue


# Install Firefox
if (!(Test-Path "C:\Program Files\Mozilla Firefox") -and (Test-Path ".\Tools\Firefox Installer.exe")) {
    Log "Installing Firefox..."
    Start-Process ".\Tools\Firefox Installer.exe" -ArgumentList "/S" -Wait
    Write-Verbose -Message ("[{0:HH:mm:ss}] {1}" -f (Get-Date), "Info: started Firefox Installer.exe.")
} else {
    Write-Host "Warning: Firefox installer not found, or firefox is already Installed, skipping." -f yellow
}

# Import preconfigured Firefox profile
Log "Preconfiguring Firefox profile..."
$ffPath = "$env:APPDATA\Mozilla\Firefox\Profiles"
New-Item -ItemType Directory -Path $ffPath -Force 
Copy-Item -Path ".\Firefox\Profile\*" -Destination "$ffPath\Profile.profile" -Recurse -Force
Write-Verbose -Message ("[{0:HH:mm:ss}] {1}" -f (Get-Date), "Info: Copied Profile to $ffPath .")

Log "Setting Firefox as default browser..."
Start-Process "cmd.exe" -ArgumentList '/c "start firefox.exe --make-default-browser"' -Wait

# Remove McAfee if present (forces system restart)
if (Test-Path "C:\Program Files (x86)\McAfee") {
    Log "Removing McAfee..."
    Write-Host "McAfee was detected on the system: starting McAfee removable tool." -f yellow
    Start-Process ".\Tools\MCPR.exe"
    Write-Verbose ("[{0:HH:mm:ss}] {1}" -f (Get-Date), "Info: starting .\Tools\MCPR.exe")
    Write-Host "This will mostlikely require a system restart. Please restart the Powershell script after finishing the McAfee uninstall." -f yellow
    Start-Sleep -Seconds 10
    exit
}

# Apply registry tweaks
Log "Applying registry tweaks..."

# Enable Dark Mode
Log "Enabling dark mode..."
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "AppsUseLightTheme" -Value 0
Write-Verbose -Message ("[{0:HH:mm:ss}] {1}" -f (Get-Date), "Info: set HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize\AppsUseLightTheme = 0")
Set-ItemProperty -Path "HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "SystemUsesLightTheme" -Value 0
Write-Verbose -Message ("[{0:HH:mm:ss}] {1}" -f (Get-Date), "Info: set HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize\SystemUsesLightTheme = 0")

# restore old context menue
Log "Enabling old context menue..."
reg add "HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}" /v InprocServer32 /f
Write-Verbose -Message ("[{0:HH:mm:ss}] {1}" -f (Get-Date), "Info: created HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32")

# Automatically force close stuborn apps at shutdown
$choice2 = Read-Host "Do you want to activate force close opon shutdown?`n WARNING: This might cause Dataloss! Do you still want to continue? (y/n)" -f red
if ($choice2 -eq "y") { 
    if ((Read-Host "Are you sure? (y/n)") -eq "y") {
        Log "Enabling automatic force close at shutdown..."
        reg add "HKCU\Control Panel\Desktop" /v "AutoEndTasks" /t REG_SZ /d 1 /f 
        Write-Verbose -Message ("[{0:HH:mm:ss}] {1}" -f (Get-Date), "Info: set HKCU\Control Panel\Desktop\AutoEndTasks = 1")
        reg add "HKCU\Control Panel\Desktop" /v "WaitToKillAppTimeout" /t REG_SZ /d 2000 /f
        Write-Verbose -Message ("[{0:HH:mm:ss}] {1}" -f (Get-Date), "Info: set HKCU\Control Panel\Desktop\WaitToKillAppTimeout = 2000")
        reg add "HKLM\SYSTEM\CurrentControlSet\Control" /v "WaitToKillServiceTimeout" /t REG_SZ /d 2000 /f
        Write-Verbose -Message ("[{0:HH:mm:ss}] {1}" -f (Get-Date), "Info: set HKLM\SYSTEM\CurrentControlSet\Control\WaitToKillServiceTimeout = 2000")
    }
} else {Log "Skipping automatic force close at shutdown. User denied."}

# 0 Click Lockscreen
Log ("Enabling 0 Click Lockscreen...")
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Personalization" /v "NoLockScreen" /t REG_DWORD /d 1 /f
Write-Verbose -Message ("[{0:HH:mm:ss}] {1}" -f (Get-Date), "Info: set HKLM\SOFTWARE\Policies\Microsoft\Windows\Personalization\NoLockScreen = 1")

# Enable verbose output on startup
$choice3 = Read-Host "Do you want to activate Verbose output on startup? (y/n)"
if ($choice3 -eq "y") {
    Log "Enabling verbose output on startup..."
    reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v "verbosestatus" /t REG_DWORD /d 1 /f
    Write-Verbose -Message ("[{0:HH:mm:ss}] {1}" -f (Get-Date), "Info: set HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\verbosestatus = 1")
} else {Log "Skipping Verbose output. User denied."}

# Show Seconds on system clock
Log "Enabling seconds on system clock..."
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "ShowSecondsInSystemClock" /t REG_DWORD /d 1 /f
Write-Verbose -Message ("[{0:HH:mm:ss}] {1}" -f (Get-Date), "Info: set HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\ShowSecondsInSystemClock = 1")

# Import remaining .reg files (I might outsource the ones present in this script too)
$regList = Get-ChildItem -Path ".\Registry tweaks\*" -Include "*.reg" -Recurse | Select-Object -ExpandProperty FullName
foreach ($regFile in $regList) {
        Write-Verbose -Message ("[{0:HH:mm:ss}] {1}" -f (Get-Date), "Info: importing '$regFile'.")
        Start-Process reg.exe -ArgumentList "import `"$regFile`"" -NoNewWindow -Wait
        Log "Successfully imported '$regFile'."
}

# Debloating Windows
Log "Removing Windows bloatware..."
$DebloatList = Get-Content ".\Debloat.txt" 

foreach ($pkg in $DebloatList) {
    Write-Verbose "Info: removing $pkg"
    try {Get-AppxPackage -Name $pkg -AllUsers | Remove-AppxPackage -ErrorAction Stop
    } catch {
        Write-Host "Error: could not find or remove AppxPackage: $pkg . Either Package is not present on the system or removalprocess failed unexpectedly" -f red
    }
    try {Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -eq $pkg } | Remove-AppxProvisionedPackage -Online -ErrorAction Stop
    } catch {
        Write-Host "Error: could not find or remove AppxProvisionedPackage: $pkg . Either Package is not present on system or removalprocess failed unexpectedly" -f red
    }
}

Read-Host "Setup Complete!`nPress Enter to reboot"
Restart-Computer -Force