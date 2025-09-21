WinDeck Nexus: The Interactive Guide
====================================

Player's Guide
--------------

### What is WinDeck Nexus?

It's helpful to think of **WinDeck Nexus** by comparing it to the **Steam Deck**. Both aim for the same goal: to create a seamless, console-like gaming experience where everything is ready the moment you decide to play. However, they achieve this goal in different ways.

*   A **Steam Deck** replaces your desktop with a "Big Picture" style interface that launches games.
    
*   **WinDeck Nexus** works differently. It's a smart **automation engine** that runs silently in the background of your standard Windows desktop. It doesn't replace your desktop or your launchers; it enhances them.
    

The core of WinDeck Nexus is a single, powerful command (OnConnect.ps1) that is triggered whenever a game launch is detected. This command intelligently applies all your preferred settings, and a corresponding "cleanup" command (OnDisconnect.ps1) reverts everything when you're done. Because it's just a command, it can be integrated into virtually **any launcher or tool**—from a simple shortcut to a sophisticated streaming server like Apollo.

In essence, you continue to launch games from Steam, the Epic Games Store, or your desktop as you always have. WinDeck Nexus simply intercepts the launch, prepares your system, and then gets out of the way.

### Quick Start: Installation

Getting started is designed to be simple and safe.

1.  **Download:** Obtain the WinDeck-Nexus-Installer.exe file. 
    
2.  **Run:** Double-click the installer. It **does not** require administrator rights because it only installs into your personal user profile, never touching core system files.
    
3.  **Wizard:** A setup wizard will appear. Confirm the installation path (it defaults to %LOCALAPPDATA%\\WinDeck Nexus, a standard and safe location for applications).
    
4.  **Finish:** Click through the prompts. Once complete, the installer will start the System Tray icon for you.
    

You will now see the WinDeck Nexus icon in your System Tray, located in the corner of your taskbar near the clock.

### Mastering the Interface

#### The System Tray Icon: Your Command Post

The System Tray icon is your hub for quick actions. A **right-click** on the icon reveals its menu:

*   **Open Nexus Control Center:** Launches the full dashboard in your web browser where you can configure everything.
    
*   **Switch Profile >:** A sub-menu showing all your profiles. You can use this to manually change your _default_ profile on the fly.
    
*   **Check for Updates:** Checks for a new version of WinDeck Nexus.
    
*   **Exit WinDeck Nexus:** Completely shuts down the background tray application.
    

#### The Nexus Control Center: The Brains

This is the web-based UI where you'll fine-tune your settings.

*   **Profiles Tab:** A "Profile" is a saved collection of settings. For example, a "Max Performance" profile that sets your PC's power plan to "High Performance" and closes background apps, or a "Quiet Indie" profile that uses the "Balanced" power plan.
    
*   **Game-Aware Profiles Tab: Your Universal Library:** This is where you tell WinDeck Nexus how to handle every game you own, regardless of where it came from. You can add executables from any source (Steam, Epic Games, Roblox, Battle.net, etc.) and link them to a profile.
    
*   **Plugins Tab:** This is where you manage community-made add-ons. For your security, each plugin must declare what it needs to do (e.g., network.access).
    

### Remote Play: Apollo & Moonlight

This is the ultimate upgrade for your gaming setup. Stream games from your powerful gaming PC to another device with extremely low latency. WinDeck Nexus will fully automate the session on your host PC.

#### What are Apollo and Moonlight?

*   **Apollo (a Sunshine fork):** This is the **server** software you install on your main gaming PC. It "hosts" the stream.
    
*   **Moonlight:** This is the **client** software you install on the device you want to play on (e.g., your laptop, phone, or another PC).
    

#### Step 1: Install Apollo (Server)

1.  Go to the [Apollo Game Stream Host](https://github.com/ClassicOldSong/Apollo) project on GitHub and download the latest Windows installer from the "Releases" section.
    
2.  Run the installer on your gaming PC.
    
3.  Open your web browser and navigate to https://localhost:47990.
    
4.  Create a username and password, then log in.
    
5.  Navigate to the "PIN" tab and keep it open.
    

#### Step 2 & 3: Install Moonlight (Client) & Pair

1.  On your second device, search for the "Moonlight Game Streaming" project and install the official client for your device's operating system.
    
2.  Run the Moonlight client. It should automatically find your gaming PC on the network. Click it.
    
3.  Moonlight will show a 4-digit PIN. Enter this PIN into the Apollo Web UI on your gaming PC.
    

Tinkerer's Guide
----------------

### Architecture Explorer

WinDeck Nexus operates on a simple, elegant event-driven model. Click on any component below to learn about its role in the system.

Tray-Manager.ps1 (The Watcher)

This script runs silently in the background. Its only jobs are to provide the tray icon menu and watch config.json for any changes you make in the Control Center, so it can update the menu in real-time.

Dashboard.ps1 (The Server)

When you click "Open Nexus Control Center," this script starts a tiny, local-only web server. It serves the index.html file to your browser and provides the API that the webpage uses to read and write your settings back to the config.json file.

OnConnect.ps1 (The Conductor)

This is the heart of the automation. When a game launch is detected, this script is executed. It takes the game's executable name as an argument, determines the correct profile, saves the PC's current state, applies the new settings, and runs plugin hooks.

OnDisconnect.ps1 (The Cleanup Crew)

When the game session ends, this script is run. It reads the temporary state file created by OnConnect.ps1 and gracefully reverts all changes, restoring your system to exactly how it was.

### Building From Source

If you modify the source scripts or wish to compile the application yourself, follow these steps.

#### Prerequisites

*   PowerShell 7+
    
*   The ps2exe Module
    
*   Git
    

#### Step 1: Get The Source

`git clone [https://github.com/your-username/WinDeck-Nexus.git](https://github.com/your-username/WinDeck-Nexus.git)  cd WinDeck-Nexus   `

#### Step 2: Install Dependencies

`   Install-Module -Name ps2exe -Force   `

#### Step 3: Run the Build Script

`   .\Build-Installer.ps1   `

Upon completion, a new file, WinDeck-Nexus-Installer.exe, will be generated in the root of the project directory.

Creator's Guide
---------------

### Plugin Development

A great WinDeck Nexus plugin is small, focused, and secure. It should do one thing well and ask only for the permissions it absolutely needs.

#### Step 1: The Folder Structure

Navigate to your Source/Plugins/ directory. Create a new folder. The name must be a single word (no spaces) as it's used as an ID. Let's call it DiscordStatus.

#### Step 2: The Manifest (manifest.json)

This file is the plugin's "ID card"—it tells WinDeck Nexus what your plugin is, who made it, and what it needs to do.

`   {      "name": "Discord Status",      "version": "1.0.0",      "author": "Your Name",      "description": "Updates your Discord status via a webhook when a game is launched.",      "permissions": [          "network.access"      ]  }   `

#### Step 3: The Logic (onGameLaunch.ps1)

The filename is critical: naming it onGameLaunch.ps1 tells the engine to execute this script during the onGameLaunch event.

`   # This parameter is automatically passed by the OnConnect conductor.  param(      [string]$GameExecutable  )  # Failsafe: If the URL is missing, exit gracefully.  if (-not $webhookUrl) {       Write-Host "Webhook URL not configured."      exit   }  # Create the JSON payload that the Discord API expects.  $body = @{      content = "Now playing **$($GameExecutable -replace '.exe', '')**!"  } | ConvertTo-Json  # This action is only allowed because we declared "network.access"  Invoke-RestMethod -Uri $webhookUrl -Method Post -Body $body   `

### API Reference

#### Available Permissions

*   **network.access:** Allows use of Invoke-WebRequest and Invoke-RestMethod.
    
*   **filesystem.read:** Allows reading files outside the plugin's own directory.
    
*   **filesystem.write:** Allows writing files outside the plugin's own directory.
    
*   **process.control:** Allows starting or stopping processes.
    

#### Event Hooks

*   **onGameLaunch.ps1:** Executes after a profile has been activated. Receives -GameExecutable \[string\].
    
*   **onDisconnect.ps1:** Executes when the OnDisconnect.ps1 conductor is run. Useful for cleanup tasks.
    

Integration Guide
-----------------

### Connecting to Apollo

This is the final step to make remote play automated. We will tell Apollo to run the WinDeck Nexus commands for us.

1.  Go back to the Apollo Web UI on your gaming PC.
    
2.  Navigate to **Configuration > Command Preparations**.
    
3.  powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%localappdata%\\WinDeck Nexus\\Core\\OnConnect.ps1" -GameExecutable "{app.game.executable}"
    
4.  powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%localappdata%\\WinDeck Nexus\\Core\\OnDisconnect.ps1"
    
5.  Save your changes. You have now fully integrated WinDeck's automation with your remote streaming setup.#
