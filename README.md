# EasyMacPromo

An easy Pomodoro app for Mac.

## Features

- Adds a "tomato" icon (🍅) to the menu bar.
- When clicked, a small panel shows up beneath.
- Shows 25 / 45 / 60 min countdown buttons.
- When any countdown button is clicked:
  - Menu icon turns red (🔴).
  - Starts counting down with live timer in the menu bar.
  - Countdown buttons are replaced with a single pause / resume button.
  - Turns on "Reduced Interruptions" Focus mode.
- When countdown ends:
  - Menu icon turns green (🟢).
  - Continues counting up.
  - Pause / resume button becomes the stop button.
  - Turns off "Reduced Interruptions" Focus mode.

## Requirements

- macOS 13 (Ventura) or later
- Xcode Command Line Tools (`xcode-select --install`)

## Build & Run

```bash
./build.sh
open EasyMacPromo.app
```

Or build manually:

```bash
swift build -c release
.build/release/EasyMacPromo
```

## Focus Mode Setup

To enable automatic "Reduced Interruptions" toggling, create two Shortcuts in the Shortcuts app:

1. **Start Reduced Interruptions** — Add a "Set Focus" action that turns on "Reduced Interruptions"
2. **Stop Reduced Interruptions** — Add a "Set Focus" action that turns off "Reduced Interruptions"

The app will call these shortcuts automatically when a timer starts and ends. If the shortcuts don't exist, the timer still works — Focus mode just won't toggle.
