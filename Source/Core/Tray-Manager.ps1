# WinDeck Nexus System Tray Manager
# Author: Your Name
# Version: 2.3
# Description: This script creates and manages the persistent System Tray icon for WinDeck Nexus,
# providing real-time status, context menu actions, and dynamic profile switching.

# --- INITIAL SETUP & ASSEMBLY LOADING ---
# Required for creating the graphical components like icons and menus.
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- GLOBAL VARIABLES ---
# Define paths relative to the script's location for robustness.
$scriptPath = $PSScript | Split-Path
$basePath = (Resolve-Path (Join-Path $scriptPath "..\")).Path
$configPath = Join-Path $basePath "config.json"
$iconPath = Join-Path $basePath "Assets\WinDeck.ico"
$dashboardScriptPath = Join-Path $basePath "Core\Dashboard.ps1"

# --- CORE FUNCTIONS ---

# NOTE: This function has been renamed from 'Build-ProfileSubMenu' to use the approved verb 'New'.
# This change adheres to PowerShell best practices (PSUseApprovedVerbs) for better discoverability and readability.
function New-ProfileSubMenu {
    <#
    .SYNOPSIS
        Reads the config.json file and constructs a dynamic submenu of available profiles.
    .DESCRIPTION
        This function is called on script start and whenever the config file changes. It reads the
        profiles and the currently active profile, then builds a menu object where the active profile
        is checked.
    .RETURNS
        A [System.Windows.Forms.ToolStripMenuItem] object containing the profile list.
    #>
    try {
        if (-not (Test-Path $configPath)) {
            Write-Warning "Configuration file not found at $configPath."
            return $null
        }

        # Read and parse the JSON configuration.
        $config = Get-Content -Path $configPath | ConvertFrom-Json
        $activeProfileName = $config.activeProfile

        # Create the parent menu item "Switch Profile >"
        $profileSubMenu = New-Object System.Windows.Forms.ToolStripMenuItem("Switch Profile")

        # Create a menu item for each profile found in the config.
        foreach ($profile in $config.profiles) {
            $profileMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem($profile.name)

            # Add a checkmark to the currently active profile.
            if ($profile.name -eq $activeProfileName) {
                $profileMenuItem.Checked = $true
            }

            # Define the action to perform when a profile is clicked: update config.json.
            $profileMenuItem.add_Click({
                Write-Host "Switching active profile to $($this.Text)..."
                # Read the config again to avoid overwriting other changes.
                $currentConfig = Get-Content -Path $configPath | ConvertFrom-Json
                $currentConfig.activeProfile = $this.Text
                # Write the updated object back to the JSON file with formatting.
                $currentConfig | ConvertTo-Json -Depth 5 | Set-Content -Path $configPath
            })

            # Add the new profile item to the submenu.
            $profileSubMenu.DropDownItems.Add($profileMenuItem) | Out-Null
        }

        return $profileSubMenu
    }
    catch {
        Write-Error "Failed to create profile submenu: $_"
        return $null
    }
}

# --- SCRIPT EXECUTION ---

# 1. Create the NotifyIcon (the object that lives in the System Tray).
$notifyIcon = New-Object System.Windows.Forms.NotifyIcon
$notifyIcon.Icon = New-Object System.Drawing.Icon($iconPath)
$notifyIcon.Text = "WinDeck Nexus: Idle" # Tooltip text on hover.
$notifyIcon.Visible = $true

# 2. Create the Right-Click Context Menu.
$contextMenu = New-Object System.Windows.Forms.ContextMenuStrip

# 3. Create and Add Standard Menu Items.
# "Open Nexus Control Center"
$openDashboardItem = New-Object System.Windows.Forms.ToolStripMenuItem("Open Nexus Control Center")
$openDashboardItem.add_Click({
    Write-Host "Launching Nexus Control Center..."
    # Start the dashboard server script in a new, hidden window.
    Start-Process powershell -ArgumentList "-NoProfile -WindowStyle Hidden -File `"$dashboardScriptPath`""
})
$contextMenu.Items.Add($openDashboardItem) | Out-Null

# Add a separator line.
$contextMenu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator)) | Out-Null

# 4. Create and Add the Dynamic Profile Submenu.
# This calls our corrected function.
$profileMenu = New-ProfileSubMenu
if ($profileMenu) {
    $contextMenu.Items.Add($profileMenu) | Out-Null
}

# Add another separator.
$contextMenu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator)) | Out-Null

# "Check for Updates" (Placeholder)
$updateItem = New-Object System.Windows.Forms.ToolStripMenuItem("Check for Updates")
$updateItem.add_Click({
    # In a real application, this would trigger an update check function.
    [System.Windows.Forms.MessageBox]::Show("You are running the latest version of WinDeck Nexus.", "Update Check")
})
$contextMenu.Items.Add($updateItem) | Out-Null

# "Exit WinDeck Nexus"
$exitItem = New-Object System.Windows.Forms.ToolStripMenuItem("Exit")
$exitItem.add_Click({
    Write-Host "Exiting WinDeck Nexus..."
    $notifyIcon.Dispose()
    # Cleanly stop the script and its background event monitoring.
    $script:runspace.Close()
    $script:runspace = $null
    Exit
})
$contextMenu.Items.Add($exitItem) | Out-Null

# 5. Link the Context Menu to the Tray Icon.
$notifyIcon.ContextMenuStrip = $contextMenu

# 6. Set up a FileSystemWatcher to monitor config.json for changes.
# This ensures the "Switch Profile" menu updates in real-time if a user
# changes the active profile via the Control Center.
$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = $basePath
$watcher.Filter = "config.json"
$watcher.EnableRaisingEvents = $true

# Define the action to take when the config file changes.
$action = {
    Write-Host "Config file changed. Rebuilding profile menu..."
    # Find the old profile menu and remove it.
    $oldProfileMenu = $notifyIcon.ContextMenuStrip.Items["Switch Profile"]
    if ($oldProfileMenu) {
        $notifyIcon.ContextMenuStrip.Items.Remove($oldProfileMenu)
    }
    # Create the new profile menu using our corrected function.
    $newProfileMenu = New-ProfileSubMenu
    if ($newProfileMenu) {
        # Insert the new menu at the correct position (index 2).
        $notifyIcon.ContextMenuStrip.Items.Insert(2, $newProfileMenu)
    }
}

# Register the action with the watcher's "Changed" event.
Register-ObjectEvent -InputObject $watcher -EventName "Changed" -Action $action | Out-Null

# --- KEEP SCRIPT ALIVE ---
# This loop prevents the script from exiting immediately, keeping the tray icon alive.
# The script is properly terminated via the "Exit" context menu item.
$script:runspace = [System.Management.Automation.Runspace]::DefaultRunspace
while ($script:runspace) {
    Start-Sleep -Seconds 1
}

