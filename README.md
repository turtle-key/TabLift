# TabLift

**TabLift** is a lightweight macOS utility that restores minimized apps when switching with `⌘+Tab`.  
By default, macOS ignores minimized windows unless you hold the `Option` key.  
TabLift fixes this behavior, making app switching intuitive and seamless — no extra keys needed.

![TabLift Banner](https://tablift.mihai.sh)

---

## Features

-  Automatically restores minimized windows on app switch
-  Feels native and integrates smoothly with macOS
-  Runs quietly in the background with minimal resource usage
-  Built using public APIs with sandbox-safe practices
-  Compatible with multiple desktops and Mission Control

---

## Tech Stack

| Component       | Technology                                 |
|----------------|---------------------------------------------|
| Language        | Swift                                      |
| UI Framework    | SwiftUI (optional) / AppKit (for behavior) |
| APIs Used       | Accessibility API (AXUIElement), NSWorkspace |
| Platform        | macOS Monterey (12.0) and later            |
| Packaging       | `.app` bundle with LaunchAgent `.plist`    |

---

## Installation

### Option 1: Download Prebuilt App

1. [Download the latest release](https://github.com/turtle-key/TabLift/releases)
2. Move it to `/Applications`
3. Launch TabLift and grant Accessibility permission when prompted

### Option 2: Build from Source

```bash
git clone https://github.com/turtle-key/TabLift.git
cd tablift
open TabLift.xcodeproj
```

Then:
- Build and run using Xcode
- Accept any permission prompts

---

## How It Works

1. TabLift listens for app switch events (via `NSWorkspace` notifications).
2. If the target app is minimized, it:
   - Accesses the app’s window list via `AXUIElement`
   - Checks for `AXMinimized == true`
   - Sets `AXMinimized = false` to restore the window
3. Done instantly with no UI flicker.

No constant polling, only efficient event-based behavior.

---

## Permissions

To function correctly, TabLift requires:

- **Accessibility Access**

Prompted automatically on first launch.  
Or you can enable it manually:

```bash
System Settings → Privacy & Security → Accessibility → Enable TabLift
```

---

## 📁 File Structure

```
TabLift/
├── Sources/
│   ├── TabLiftApp.swift
│   ├── AppMonitor.swift
│   ├── WindowManager.swift
│   └── LaunchAgentInstaller.swift
├── Assets.xcassets/
├── Info.plist
└── TabLift.xcodeproj
```

---

## 🤝 Contributing

1. Fork the repo
2. Create a feature branch:
   ```bash
   git checkout -b feature/your-feature-name
   ```
3. Push and open a PR

Bug fixes, enhancements, and refactors are welcome!

---

## 📜 License

**MIT License**  
© [Mihai-Eduard Ghețu] – See [`LICENSE`](LICENSE) for details.

---

## 🌐 Credits

Built for macOS power users frustrated with app switching limitations.  
Thanks to the accessibility team docs and community insights!

---

> TabLift – *Lift your windows. Free your workflow.*
