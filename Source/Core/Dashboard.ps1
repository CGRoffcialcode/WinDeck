# WinDeck Nexus - Control Center Backend
# Author: Gemini
# Version: 2.0 "Director's Cut"
# Description: A lightweight web server that serves the index.html Control Center
#              and provides a simple REST API for reading and writing configuration.

# --- CONFIGURATION ---
$scriptPath = $PSScriptRoot
$mainAppPath = Join-Path $scriptPath ".."
$configPath = Join-Path $mainAppPath "config.json"
$pluginsPath = Join-Path $mainAppPath "Plugins"
$indexPath = Join-Path $mainAppPath "index.html"
$port = 8090
$prefix = "http://localhost:$port/"

# --- SERVER INITIALIZATION ---
if (-not [System.Net.HttpListener]::IsSupported) {
    Write-Error "HttpListener is not supported on this system."
    exit 1
}

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add($prefix)

try {
    $listener.Start()
    Write-Host "WinDeck Nexus Control Center is running at $prefix"
    # Open the URL in the default browser
    Start-Process $prefix
}
catch {
    Write-Error "Failed to start listener. Is port $port already in use?"
    Write-Error $_.Exception.Message
    exit 1
}

# --- API HELPER FUNCTIONS ---
function Get-Config {
    if (-not(Test-Path $configPath)) {
        # Create a default config if it doesn't exist
        $defaultConfig = @{
            activeProfile = "Default"
            profiles = @(
                @{
                    name = "Default"
                    powerPlan = "High Performance"
                    closeApps = @("spotify", "chrome")
                }
            )
            gameProfiles = @(
                @{
                    executable = "eldenring.exe"
                    profileName = "Default"
                }
            )
            enabledPlugins = @("DiscordStatus")
            settings = @{
                discordWebhookUrl = ""
            }
        }
        $defaultConfig | ConvertTo-Json -Depth 5 | Set-Content $configPath
    }
    return Get-Content $configPath | ConvertFrom-Json
}

function Get-Plugins {
    $installedPlugins = @()
    if (Test-Path $pluginsPath) {
        Get-ChildItem -Path $pluginsPath -Directory | ForEach-Object {
            $manifestPath = Join-Path $_.FullName "manifest.json"
            if (Test-Path $manifestPath) {
                $manifestContent = Get-Content $manifestPath | ConvertFrom-Json
                $installedPlugins += @{
                    id = $_.Name
                    manifest = $manifestContent
                }
            }
        }
    }
    return $installedPlugins
}

# --- MAIN REQUEST LOOP ---
while ($listener.IsListening) {
    try {
        $context = $listener.GetContext()
        $request = $context.Request
        $response = $context.Response
        $endpoint = $request.Url.AbsolutePath

        # Add CORS headers to allow requests from the file:// protocol if opened directly
        $response.AddHeader("Access-Control-Allow-Origin", "*")
        $response.AddHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        $response.AddHeader("Access-Control-Allow-Headers", "Content-Type")

        # Handle pre-flight OPTIONS request for CORS
        if ($request.HttpMethod -eq "OPTIONS") {
            $response.StatusCode = 204 # No Content
            $response.Close()
            continue
        }

        # --- API ROUTING ---
        switch -Wildcard ($endpoint) {
            # Serve the main HTML file
            "/" {
                $response.ContentType = "text/html"
                $buffer = [System.Text.Encoding]::UTF8.GetBytes((Get-Content -Path $indexPath -Raw))
                $response.ContentLength64 = $buffer.Length
                $response.OutputStream.Write($buffer, 0, $buffer.Length)
            }
            # GET /config - Return current configuration
            "/config" {
                if ($request.HttpMethod -eq "GET") {
                    $config = Get-Config
                    $json = $config | ConvertTo-Json -Depth 5
                    $response.ContentType = "application/json"
                    $buffer = [System.Text.Encoding]::UTF8.GetBytes($json)
                    $response.ContentLength64 = $buffer.Length
                    $response.OutputStream.Write($buffer, 0, $buffer.Length)
                }
                elseif ($request.HttpMethod -eq "POST") {
                    $reader = New-Object System.IO.StreamReader($request.InputStream, $request.ContentEncoding)
                    $body = $reader.ReadToEnd()
                    $body | Set-Content -Path $configPath
                    $response.StatusCode = 200
                }
            }
            # GET /plugins - Return list of installed plugins
            "/plugins" {
                 $plugins = Get-Plugins
                 $json = $plugins | ConvertTo-Json -Depth 5
                 $response.ContentType = "application/json"
                 $buffer = [System.Text.Encoding]::UTF8.GetBytes($json)
                 $response.ContentLength64 = $buffer.Length
                 $response.OutputStream.Write($buffer, 0, $buffer.Length)
            }
            default {
                $response.StatusCode = 404
                $response.StatusDescription = "Not Found"
            }
        }
    }
    catch {
        Write-Warning "An error occurred during request processing: $($_.Exception.Message)"
        if ($response) {
            $response.StatusCode = 500
        }
    }
    finally {
        if ($response) {
            $response.Close()
        }
    }
}
