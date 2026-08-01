# ⏱️ Strip Timer

A native, physics-based, elastic macOS menu bar timer inspired by *GesTimer*, built completely from scratch using **Swift**, **AppKit**, and **QuartzCore**.

Strip Timer lives entirely in your macOS Status Bar (Menu Bar). Setting a timer is as simple as clicking the status icon and **dragging your cursor downward** to stretch a rubber band.

---

## ✨ Features

- **Elastic Rubber Band**: A custom vector path drawn using quadratic Bezier curves with dynamic width thinning and accent color blending under tension.
- **Spring-Damper Physics**: Real-time simulation calculated on every screen refresh frame via `CVDisplayLink`.
- **Tip Tooltip Indicator**: A sleek, translucent capsule pill displaying the snapped duration that dynamically follows the tip of the rubber band.
- **Accompanying Preferences**: A SwiftUI-based preferences window to customize spring physics stiffness/damping, alert sounds, and drag-to-time translation curves.
- **Zero Dock Presence**: Runs as an `.accessory` application to keep your Dock clean.
- **CLI Notification Fallback**: Automatically falls back to sending native macOS notification banners via AppleScript when executed as a raw binary, preventing bundle ID crashes.

---

## 🛠️ Build & Installation

### Requirements
- macOS 14.0+
- Swift 5.10+ (Xcode or Swift Command Line Tools)

### Build the Target
To compile the package, navigate to the root directory and run:
```bash
swift build -c release
```

---

## 🎮 How to Use

1. **Set Timer**: Click and hold the stopwatch icon (`􀵔`) in the menu bar, then drag downward. Release the mouse button when you reach the desired duration.
2. **Cancel/Snapping**: Releasing the mouse at under 5 seconds cancels the timer and snaps the band back. Releasing at 5 seconds or more starts the countdown.
3. **Controls Menu**: Click the active countdown timer to Pause, Resume, Cancel, or access Preferences.
4. **Preferences Window**: Click **Preferences...** in the menu to configure:
   - **Tension & Damping**: Modify stiffness and damping values to make the rubber band feel more loose/gummy or tight/stiff in real time.
   - **Time Mappings**: Swap translation curves.
   - **Completion Sound**: Pick alert sounds (Morse, Glass, Ping, Hero).

---

## 📄 License
This project is licensed under the GPL v3 - see the LICENSE file for details.
