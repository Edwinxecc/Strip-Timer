# 🎗️ Strip Timer

A native, physics-based, elastic macOS menu bar timer inspired by *GesTimer*, built completely from scratch using **Swift**, **AppKit**, and **QuartzCore**.

Strip Timer lives entirely in your macOS Status Bar (Menu Bar). Setting a timer is as simple as clicking the status icon and **dragging your cursor downward** to stretch a rubber band.

---

## ✨ Features

- **Elastic Rubber Band**: A custom vector path drawn using quadratic Bezier curves with dynamic width thinning and accent color blending under tension.
- **Spring-Damper Physics**: Real-time simulation calculated on every screen refresh frame via `CVDisplayLink` (running up to 120Hz).
- **Tip Tooltip Indicator**: A sleek, translucent capsule pill displaying the snapped duration that dynamically follows the tip of the rubber band.
- **Accompanying Preferences**: A SwiftUI-based preferences window to customize spring physics stiffness/damping, alert sounds, and drag-to-time translation curves.
- **Zero Dock Presence**: Runs as an `.accessory` application to keep your Dock clean.
- **CLI Notification Fallback**: Automatically falls back to sending native macOS notification banners via AppleScript when executed as a raw binary, preventing bundle ID crashes.

---

## 🏎️ Physics Solver Math

The elasticity is driven by a dual-point spring-damper simulation:

1. **Physics Tip ($P_{tip}$)**: Attracted to the user's cursor position $C$ by a spring stiffness of $k$ and damping of $c$ loaded dynamically from preferences.
   $$a_{tip} = \frac{(C - P_{tip}) \cdot k - v_{tip} \cdot c}{m}$$
2. **Physics Midpoint ($P_{mid}$)**: Attracted to the geometric center between the menu bar anchor and the physics tip $P_{tip}$ with proportional stiffness ($k_{mid} = k \cdot 0.67$) and damping ($c_{mid} = c \cdot 0.67$) to preserve organic aesthetics.
   $$a_{mid} = \frac{(\frac{\text{Anchor} + P_{tip}}{2} - P_{mid}) \cdot k_{mid} - v_{mid} \cdot c_{mid}}{m}$$

This structural lag causes the rubber band to curve, bend, and oscillate when moving or stopping. The outline path is drawn by connecting the anchor and the tip with quadratic Bezier curves controlled by the lagging midpoint, offset by normal vectors to dictate dynamic thickness.

---

## 📈 Distance-to-Time Mappings

Choose between three drag translation curves in the preferences pane:
1. **Exponential (Default hybrid curve)**: Highly responsive for short ranges, quickly scaling up for long durations.
   $$T(d) = 20.0 + (d-80) \cdot 0.25 + (d-80)^2 \cdot 0.0038 \quad (\text{for } d > 80)$$
2. **Logarithmic**: Selects longer times (like 10-20 minutes) at short drag distances but tapers off so that large vertical drags do not result in excessively massive times.
   $$T(d) = 180 \cdot \ln(1 + \frac{d}{60})$$
3. **Linear**: Constant linear translation of 1 pixel = 1 second.
   $$T(d) = d \cdot 1.0$$

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

### Run Strip Timer
Start the compiled executable:
```bash
./.build/release/StripTimer
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
This project is licensed under the MIT License - see the LICENSE file for details.
