# WinDeck Nexus - OnConnect Conductor
# Author: Gemini
# Version: 2.0 "Director's Cut"
# Description: This script is the heart of the automated profile system. It activates
#              the correct profile, performs system prep, and triggers plugin hooks.
#
# USAGE:
#   .\OnConnect.ps1 -GameExecutable "eldenring.exe"

param(
    [string]$GameExecutable
)

# --- CONFIGURATION ---
$scriptPath = $PSScriptRoot
$mainAppPath = Join-Path $scriptPath ".."
$configPath = Join-Path $mainAppPath "config.json"
$pluginsPath = Join-Path $mainAppPath "Plugins"
$stateFilePath = Join-Path $env:TEMP "windeck_nexus_state.json"

Write-Host "WinDeck Nexus OnConnect starting..."
Write-Host "Game Detected: $GameExecutable"

# --- CORE FUNCTIONS ---
function Get-Config {
    if (Test-Path $configPath) {
        return Get-Content $configPath | ConvertFrom-Json
    }
    throw "Configuration file not found at $configPath"
}

function Save-CurrentState {
    $currentState = @{}
    
    # Save current power plan
    $powerPlan = powercfg /getactivescheme
    $guid = ($powerPlan | Select-String 'GUID:' | ForEach-Object { $_.ToString().Split(' ')[-2] })
    $currentState.powerPlanGuid = $guid
    
    # In a real app, you'd save wallpaper, volume, etc.
    # $currentState.wallpaper = ...
    
    $currentState | ConvertTo-Json -Depth 3 | Set-Content $stateFilePath
    Write-Host "Saved current system state to $stateFilePath"
}

function Get-PowerPlanGuid {
    param([string]$planName)
    $plans = powercfg /list
    $planLine = $plans | Select-String -Pattern $planName
    if ($planLine) {
        return $planLine.ToString().Split(' ')[3]
    }
    return $null
}

function Execute-PluginHook {
    param(
        [string]$pluginId,
        [string]$hookName, # e.g., "onGameLaunch"
        [string]$gameName
    )
    $pluginDir = Join-Path $pluginsPath $pluginId
    $hookScriptPath = Join-Path $pluginDir "$hookName.ps1"
    
    if (Test-Path $hookScriptPath) {
        Write-Host "Executing '$hookName' hook for plugin '$pluginId'..."
        try {
            # This is where permission enforcement would happen.
            # For this example, we directly execute. A real implementation
            # would require a sandboxed runspace.
            & $hookScriptPath -GameExecutable $gameName
        }
        catch {
            Write-Warning "Error executing hook for plugin '$pluginId': $_"
        }
    }
}


# --- MAIN LOGIC ---

# 1. Save current state for OnDisconnect to restore later
Save-CurrentState

# 2. Load Configuration
$config = Get-Config

# 3. Determine which profile to use
$profileNameToActivate = $config.activeProfile # Default
$gameProfile = $config.gameProfiles | Where-Object { $_.executable -eq $GameExecutable }
if ($gameProfile) {
    $profileNameToActivate = $gameProfile.profileName
    Write-Host "Game-specific profile found. Activating '$profileNameToActivate'."
} else {
    Write-Host "No specific profile found. Using default active profile '$profileNameToActivate'."
}

$activeProfile = $config.profiles | Where-Object { $_.name -eq $profileNameToActivate }
if (-not $activeProfile) {
    Write-Error "Profile '$profileNameToActivate' could not be found in config. Aborting."
    exit 1
}

# 4. Apply Profile Settings
Write-Host "Applying settings for profile '$($activeProfile.name)'..."

# a) Set Power Plan
$targetPlanGuid = Get-PowerPlanGuid -planName $activeProfile.powerPlan
if ($targetPlanGuid) {
    powercfg /setactive $targetPlanGuid
    Write-Host "  - Set power plan to '$($activeProfile.powerPlan)'"
} else {
    Write-Warning "  - Power plan '$($activeProfile.powerPlan)' not found."
}

# b) Close specified applications
if ($activeProfile.closeApps.Count -gt 0) {
    foreach ($appName in $activeProfile.closeApps) {
        if ($appName) {
            Get-Process $appName -ErrorAction SilentlyContinue | Stop-Process -Force
            Write-Host "  - Attempted to close process '$appName'"
        }
    }
}

# 5. Trigger Plugin Hooks
Write-Host "Executing plugin hooks..."
foreach ($pluginId in $config.enabledPlugins) {
    Execute-PluginHook -pluginId $pluginId -hookName "onGameLaunch" -gameName $GameExecutable
}

Write-Host "WinDeck Nexus OnConnect finished successfully."