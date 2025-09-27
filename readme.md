# WinDeck Nexus

WinDeck Nexus is a lightweight, native gaming utility for Windows written entirely in C++. It brings the fluid, controller-first experience of a gaming console to your PC with a beautiful, fully customizable frontend that emulates the Steam Deck's user interface.

When the frontend is closed, the application seamlessly transitions to a "Desktop Mode," enabling full mouse control with your gamepad.

## Features

* **Single C++ Executable**: Lightweight, portable, and self-contained with no external dependencies beyond standard Windows libraries.
* **Steam Deck UI Frontend**: A stunning, fullscreen UI built with web technologies (via WebView2) that mimics the Steam Deck's aesthetic. It's fully themeable by editing a simple CSS file.
* **Desktop Controller Navigation**: When the frontend is hidden, the app translates your controller inputs into mouse movements and clicks for seamless desktop control.
* **Game-Aware Profiles**: Automatically apply simple tweaks or show notifications when a specific game is detected.
* **System Tray Integration**: Hides in the system tray for easy access without cluttering your taskbar.

## How to Compile

### Prerequisites

1.  **Visual Studio Build Tools 2022**: You need the C++ compiler (`cl.exe`) and linker. You can get these by installing the "Desktop development with C++" workload in the Visual Studio Installer.
2.  **WebView2 SDK**: The simplest way to get this is via NuGet. Run the following command in PowerShell:
    ```powershell
    Invoke-WebRequest -Uri [https://global.vssps.visualstudio.com/DefaultCollection/_apis/nuget/v3/packages/microsoft.web.webview2/1.0.2210.55/content](https://global.vssps.visualstudio.com/DefaultCollection/_apis/nuget/v3/packages/microsoft.web.webview2/1.0.2210.55/content) -OutFile WebView2.zip
    Expand-Archive -Path WebView2.zip -DestinationPath WebView2SDK
    ```
    This will create a `WebView2SDK` folder containing the necessary `include` and `lib` files.

### Compilation Command

1.  Open the **Developer Command Prompt for VS 2022** from your Start Menu.
2.  Navigate to your project directory (e.g., `cd D:\Windeck`).
3.  Run the following commands in order:

    ```cmd
    :: 1. Compile the resource file (for the application icon)
    rc.exe resources.rc

    :: 2. Compile the C++ source code and link everything together
    cl.exe WinDeck-Nexus.cpp resources.res /std:c++17 /EHsc /I"WebView2SDK\build\native\include" /link /LIBPATH:"WebView2SDK\build\native\x64" user32.lib shell32.lib gdi32.lib XInput.lib WebView2Loader.lib /SUBSYSTEM:WINDOWS
    ```

This will produce `WinDeck-Nexus.exe` in the same directory.

**Note**: You must also have the **WebView2 Runtime** installed on any machine where you run the application. Most modern Windows 11/10 systems have it pre-installed.

## How to Use

* Run `WinDeck-Nexus.exe`. The application will launch directly into the fullscreen **Frontend Mode**.
* **To switch to Desktop Mode**: Press the `Esc` key on your keyboard or the 'B' button on your gamepad. The frontend will disappear, but the application will continue running in the system tray.
* **To return to Frontend Mode**: Left-click the WinDeck Nexus icon in the system tray, or right-click it and select "Show/Hide Frontend".

### Desktop Mode Controls

* **Left Stick**: Move the mouse cursor.
* **Right Trigger (RT)**: Left mouse click.
* **Left Trigger (LT)**: Right mouse click.

## How to Customize

The frontend UI is designed to be easily customized.

1.  Open the `ui/style.css` file in a text editor.
2.  At the very top of the file, you will find a `:root` block with several CSS variables.
3.  Change these color codes, fonts, and other values to create your own theme. Save the file and restart WinDeck Nexus to see your changes!

```css
:root {
  --primary-accent-color: #00aaff;
  --background-gradient-start: #1a2a3b;
  --background-gradient-end: #121c26;
  --font-family: 'Arial', sans-serif;
  --tile-border-radius: 12px;
}
```