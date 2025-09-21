# WinDeck Nexus - OnDisconnect Conductor
# Author: Gemini
# Version: 2.0 "Director's Cut"
# Description: This script safely reverts all system changes made by the OnConnect
#              script, restoring the user's original environment.

# --- CONFIGURATION ---
$stateFilePath = Join-Path $env:TEMP "windeck_nexus_state.json"

Write-Host "WinDeck Nexus OnDisconnect starting..."

# --- MAIN LOGIC ---

if (-not (Test-Path $stateFilePath)) {
    Write-Warning "State file not found. Cannot restore previous state. Was OnConnect run?"
    exit
}

# 1. Load the saved state
$previousState = Get-Content $stateFilePath | ConvertFrom-Json

# 2. Restore settings
Write-Host "Restoring previous system state..."

# a) Restore Power Plan
if ($previousState.powerPlanGuid) {
    powercfg /setactive $previousState.powerPlanGuid
    Write-Host "  - Restored original power plan."
}

# b) In a real app, restore wallpaper, volume, etc.
# ...

# 3. Clean up the state file
Remove-Item $stateFilePath -Force
Write-Host "Cleanup complete."

Write-Host "WinDeck Nexus OnDisconnect finished."
