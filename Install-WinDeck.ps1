# WinDeck Nexus - Installer
# Author: Gemini
# Version: 2.0 "Director's Cut"
# Description: This is the core logic for the WinDeck Nexus installer. It handles file
#              copying, shortcut creation, uninstaller registration, and startup task setup.
#              This script is meant to be compiled into an EXE using Build-Installer.ps1.

# --- PRE-FLIGHT CHECKS & CONFIG ---
$AppName = "WinDeck Nexus"
# Install to user's local app data, requiring no admin rights.
$InstallPath = Join-Path $env:LOCALAPPDATA $AppName
$StartMenuPath = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\$AppName"

# When bundled with ps2exe, the source files are available in a temp directory.
# The variable $ps2exe.bundle.dir contains the path to this directory.
$SourcePath = $ps2exe.bundle.dir

# --- WELCOME & CONFIRMATION ---
Add-Type -AssemblyName System.Windows.Forms
$welcomeResult = [System.Windows.Forms.MessageBox]::Show(
    "Welcome to the WinDeck Nexus Setup Wizard.`n`nThis will install WinDeck Nexus on your computer.`n`nInstall Location: $InstallPath`n`nDo you want to continue?",
    "WinDeck Nexus Setup",
    'YesNo',
    'Information'
)

if ($welcomeResult -ne 'Yes') {
    [System.Windows.Forms.MessageBox]::Show("Installation was cancelled by the user.", "Setup Cancelled")
    exit
}

# --- INSTALLATION PROCESS ---
Write-Host "Starting installation..."

# 1. Create Directories
if (Test-Path $InstallPath) {
    Write-Host "Existing installation found. Removing..."
    Remove-Item -Path $InstallPath -Recurse -Force
}
New-Item -Path $InstallPath -ItemType Directory | Out-Null
New-Item -Path $StartMenuPath -ItemType Directory | Out-Null

# 2. Copy Application Files
Write-Host "Copying application files from '$SourcePath' to '$InstallPath'..."
Copy-Item -Path "$SourcePath\*" -Destination $InstallPath -Recurse -Force

# 3. Create Startup Task for Tray Manager
$taskName = "WinDeck Nexus Tray Manager"
$taskAction = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$($InstallPath)\Core\Tray-Manager.ps1`""
$taskTrigger = New-ScheduledTaskTrigger -AtLogOn
$taskSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries

# Unregister any old task first
Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
# Register the new task for the current user
Register-ScheduledTask -TaskName $taskName -Action $taskAction -Trigger $taskTrigger -Settings $taskSettings -User $env:USERNAME -Force | Out-Null
Write-Host "Registered startup task: $taskName"

# 4. Create Start Menu Shortcuts
# Shortcut for the Control Center
$shortcutPath = Join-Path $StartMenuPath "Nexus Control Center.lnk"
$wshell = New-Object -ComObject WScript.Shell
$shortcut = $wshell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = "powershell.exe"
$shortcut.Arguments = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$($InstallPath)\Core\Dashboard.ps1`""
$shortcut.IconLocation = "$($InstallPath)\Assets\WinDeck.ico"
$shortcut.Description = "Open the WinDeck Nexus Control Center"
$shortcut.Save()

# Shortcut for the Uninstaller
$uninstallerPath = Join-Path $StartMenuPath "Uninstall WinDeck Nexus.lnk"
$shortcut = $wshell.CreateShortcut($uninstallerPath)
$shortcut.TargetPath = "powershell.exe"
$shortcut.Arguments = "-NoProfile -ExecutionPolicy Bypass -Command `"`& { & '$($InstallPath)\Core\Uninstall.ps1' }`""
$shortcut.IconLocation = "$($InstallPath)\Assets\WinDeck.ico"
$shortcut.Description = "Remove WinDeck Nexus from your computer"
$shortcut.Save()

# 5. Register Uninstaller in Control Panel
$registryPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\$AppName"
if (-not(Test-Path $registryPath)) {
    New-Item -Path $registryPath -Force | Out-Null
}
Set-ItemProperty -Path $registryPath -Name "DisplayName" -Value $AppName
Set-ItemProperty -Path $registryPath -Name "Publisher" -Value "CGR"
Set-ItemProperty -Path $registryPath -Name "DisplayIcon" -Value "$($InstallPath)\Assets\WinDeck.ico"
Set-ItemProperty -Path $registryPath -Name "UninstallString" -Value "powershell.exe -NoProfile -ExecutionPolicy Bypass -Command `"`& { & '$($InstallPath)\Core\Uninstall.ps1' }`""
Set-ItemProperty -Path $registryPath -Name "NoModify" -Value 1 -Type DWord
Set-ItemProperty -Path $registryPath -Name "NoRepair" -Value 1 -Type DWord

# --- FINALIZATION ---
[System.Windows.Forms.MessageBox]::Show(
    "WinDeck Nexus has been successfully installed.`n`nThe Tray Icon will appear the next time you log in, or you can start it manually from the installation folder.",
    "Installation Complete",
    'OK',
    'Information'
)

# Start the tray manager for the first time
Start-Process powershell -ArgumentList "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$($InstallPath)\Core\Tray-Manager.ps1`""

Write-Host "Installation complete."