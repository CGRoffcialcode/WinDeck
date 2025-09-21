# WinDeck Nexus - Uninstaller
# Author: Gemini
# Version: 2.0 "Director's Cut"
# Description: Performs a complete and clean removal of WinDeck Nexus.

Add-Type -AssemblyName System.Windows.Forms

# --- CONFIRMATION ---
$confirmResult = [System.Windows.Forms.MessageBox]::Show(
    "Are you sure you want to completely remove WinDeck Nexus and all of its settings?",
    "Uninstall WinDeck Nexus",
    'YesNo',
    'Warning'
)

if ($confirmResult -ne 'Yes') {
    [System.Windows.Forms.MessageBox]::Show("Uninstall was cancelled.", "Uninstall Cancelled")
    exit
}

# --- UNINSTALLATION PROCESS ---
$AppName = "WinDeck Nexus"
$InstallPath = Join-Path $env:LOCALAPPDATA $AppName
$StartMenuPath = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\$AppName"
$taskName = "WinDeck Nexus Tray Manager"
$registryPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\$AppName"

# 1. Stop running processes (Tray Manager)
Get-Process | Where-Object { $_.Name -eq 'powershell' -and $_.Path -like "*Tray-Manager.ps1*" } | Stop-Process -Force -ErrorAction SilentlyContinue

# 2. Unregister Startup Task
Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue

# 3. Remove Start Menu Shortcuts
if (Test-Path $StartMenuPath) {
    Remove-Item -Path $StartMenuPath -Recurse -Force
}

# 4. Remove Control Panel entry
if (Test-Path $registryPath) {
    Remove-Item -Path $registryPath -Recurse -Force
}

# 5. Remove Installation Directory
if (Test-Path $InstallPath) {
    Remove-Item -Path $InstallPath -Recurse -Force
}

[System.Windows.Forms.MessageBox]::Show("WinDeck Nexus has been successfully uninstalled.", "Uninstall Complete")
