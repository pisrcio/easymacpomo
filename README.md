# EasyMacPromo

A simple Pomodoro timer that lives in your Mac menu bar.

## How It Works

Click the tomato (🍅) in your menu bar to open a small panel with three timer options: 25, 45, or 60 minutes.

When you start a timer:

- The menu bar icon turns red (🔴) and shows a live countdown.
- The panel switches to a pause/resume button.
- "Reduced Interruptions" Focus mode turns on so you can concentrate.

When the countdown reaches zero:

- The icon turns green (🟢) and starts counting up so you can see how long you've been in the zone.
- The pause button becomes a stop button.
- Focus mode turns off.

Click stop to reset everything back to the tomato.

## Requirements

- macOS 13 (Ventura) or later
- Xcode Command Line Tools

If you don't have the command line tools installed:

```bash
xcode-select --install
```

## Build & Run

The included build script compiles the project and packages it into a macOS app bundle:

```bash
./build.sh
open EasyMacPromo.app
```

This creates `EasyMacPromo.app` in the project root. You can drag it into your Applications folder to keep it around.

To build without creating the app bundle:

```bash
swift build -c release
.build/release/EasyMacPromo
```

Note: running the bare executable works for development, but the app bundle is needed for a proper menu bar experience (no dock icon, correct app identity).

## Focus Mode Setup

The app toggles "Reduced Interruptions" automatically using macOS Shortcuts. You need to create two shortcuts once:

1. Open **Shortcuts.app**.
2. Create a shortcut named **Start Reduced Interruptions**.
   - Add a "Set Focus" action and configure it to turn on "Reduced Interruptions".
3. Create a shortcut named **Stop Reduced Interruptions**.
   - Add a "Set Focus" action and configure it to turn off "Reduced Interruptions".

If these shortcuts don't exist, the timer works normally — Focus mode just won't toggle.
