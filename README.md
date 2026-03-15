# EasyMacPromo

A simple Pomodoro timer that lives in your Mac menu bar.

## How It Works

Click the tomato icon in your menu bar to open a small panel with three timer options: 15 seconds, 45 minutes, or 60 minutes.

When you start a timer:

- The menu bar icon turns red.
- The panel shows a live countdown with pause and reset buttons.
- Do Not Disturb turns on so you can concentrate.

When the countdown reaches zero:

- The icon turns green.
- The panel starts counting up so you can see how long you've been in the zone.
- The countdown buttons are replaced with a stop button.
- Do Not Disturb stays on until you press stop.

Click stop to turn off Do Not Disturb and reset everything back to the idle tomato icon.

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

The app toggles Do Not Disturb automatically using macOS Shortcuts. It expects two shortcuts:

- **Turn On Do Not Disturb**
- **Turn Off Do Not Disturb**

If these shortcuts don't exist, the timer works normally — Do Not Disturb just won't toggle.
