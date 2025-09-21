# WinDeck Nexus Plugin: Discord Status
# Event Hook: onGameLaunch
# Description: Sends a notification to a Discord webhook.

param(
    [string]$GameExecutable
)

# --- CONFIGURATION ---
# The plugin script needs to find the main config file to get the webhook URL.
$configPath = Join-Path $PSScriptRoot "..\..\config.json"

function Get-WebhookUrl {
    if (Test-Path $configPath) {
        $config = Get-Content $configPath | ConvertFrom-Json
        return $config.settings.discordWebhookUrl
    }
    return $null
}

# --- PLUGIN LOGIC ---
$webhookUrl = Get-WebhookUrl

if (-not $webhookUrl -or $webhookUrl -eq "PASTE_YOUR_DISCORD_WEBHOOK_URL_HERE") {
    Write-Warning "[DiscordStatus Plugin] Webhook URL is not configured in the Nexus Control Center."
    exit
}

$gameNameFormatted = ($GameExecutable -replace '\.exe', '').ToUpper()

$body = @{
    username   = "WinDeck Nexus"
    avatar_url = "https://i.imgur.com/q3Yw5h8.png" # Placeholder icon
    content    = "Now playing **$gameNameFormatted**!"
} | ConvertTo-Json

try {
    # This action requires the "network.access" permission.
    # The Plugin Engine would verify this before executing.
    Invoke-RestMethod -Uri $webhookUrl -Method Post -ContentType 'application/json' -Body $body
    Write-Host "[DiscordStatus Plugin] Successfully sent notification to Discord."
}
catch {
    Write-Warning "[DiscordStatus Plugin] Failed to send notification: $_"
}
