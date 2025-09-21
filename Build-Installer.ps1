# WinDeck Nexus Build Script
# Author: Your Name
# Version: 2.4 (Corrected)
# Description: This script compiles the WinDeck Nexus source files into a single,
#              distributable .exe installer using the ps2exe module.
#              It now correctly builds the installer to run WITHOUT admin privileges.

# --- Step 1: Administrator and Dependency Check ---
# This part is for the DEVELOPER (you) to be able to build the installer.
# It ensures the ps2exe compiler can be installed if it's missing.
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "This build script should be run as an Administrator to ensure it can install required modules."
    Write-Warning "Please re-launch your PowerShell terminal as an Administrator and run the script again."
    if ($Host.Name -eq "ConsoleHost") { Read-Host "Press Enter to exit" }; exit
}

Write-Host "Checking for ps2exe module..."
if (-not (Get-Module -ListAvailable -Name ps2exe)) {
    Write-Host "'ps2exe' module not found. Attempting to install it now..."
    try {
        Install-Module -Name ps2exe -Force -Scope AllUsers
        Write-Host "Successfully installed 'ps2exe' module." -ForegroundColor Green
    } catch {
        Write-Error "Failed to install 'ps2exe'. Please install it manually."
        if ($Host.Name -eq "ConsoleHost") { Read-Host "Press Enter to exit" }; exit
    }
} else {
    Write-Host "'ps2exe' module is already installed." -ForegroundColor Green
}

# --- Step 2: Define Project Structure and Parameters ---
$scriptRoot = $PSScriptRoot
$sourcePath = Join-Path $scriptRoot "Source"
$installerName = "WinDeck-Nexus-Installer.exe"
$finalInstallerPath = Join-Path $scriptRoot $installerName
$mainScript = Join-Path $scriptRoot "Install-WinDeck.ps1"

# --- Step 3: Compile the Executable ---
Write-Host "Starting the compilation process..."

# Parameters for the ps2exe compiler.
$ps2exeParams = @{
    inputFile   = $mainScript
    outputFile  = $finalInstallerPath
    # CRITICAL FIX: The line 'ps2exe_request_uac = $true' has been REMOVED.
    # The installer will now run as a standard user, which is the correct behavior.
    iconFile    = (Join-Path $sourcePath "Assets\WinDeck.ico")
    title       = "WinDeck Nexus Installer"
    description = "Installs the WinDeck Nexus gaming platform."
    company     = "WinDeck Nexus Community"
    product     = "WinDeck Nexus"
    version     = "2.4.0.0"
    noConsole   = $true # Run the installer GUI without a background console window.
}

try {
    # ps2exe requires a special parameter to bundle files, which isn't available
    # in Invoke-ps2exe. We must call it directly.
    ps2exe @ps2exeParams -bundle (Join-Path $sourcePath "*")

    Write-Host "----------------------------------------------------"
    Write-Host "Build successful!" -ForegroundColor Green
    Write-Host "Installer created at: $finalInstallerPath"
    Write-Host "----------------------------------------------------"
}
catch {
    Write-Error "An error occurred during compilation: $_"
}

if ($Host.Name -eq "ConsoleHost") {
    Read-Host "Press Enter to continue"
}
