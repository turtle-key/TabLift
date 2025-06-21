# TabLift

**TabLift** is a lightweight macOS utility that restores minimized apps instantly when switching with `⌘+Tab`.

By default, macOS ignores minimized windows unless you hold the `Option` key.  
TabLift fixes this behavior, making app switching intuitive and seamless — no extra keys needed.

<p align="center">
  <img src="https://github.com/turtle-key/TabLift/blob/2d16a5d1632467252e0975ea9988131a819270b3/banner.png" alt="TabLift Banner" width="400"/>
</p>

---

## Features

- **Instantly restores minimized windows** when you switch to an app using `⌘+Tab`
- No need to press extra keys — just switch!
- **Native macOS experience** (built with Swift, SwiftUI, and AppKit)
- **Runs quietly in the background** with minimal resource usage
- **Open source** and privacy-friendly  
- Compatible with Mission Control, multiple desktops, and most macOS versions

---

## How It Works

TabLift uses public Apple APIs to monitor when you activate a different app (via [`NSWorkspace`](https://developer.apple.com/documentation/appkit/nsworkspace) notifications).  
As soon as an app is activated, TabLift checks for minimized windows via the Accessibility API (`AXUIElement`).  
If a minimized window is found, it is instantly restored for you.

**Technical flow:**

1. **Listening**: `AppMonitor` listens for app activation events.
2. **Restoring**: `WindowManager` inspects the app's window list. If any window is minimized, it sets the `AXMinimized` attribute to `false`.
3. **Permissions**: On first launch, `PermissionsService` prompts you to grant Accessibility permissions, which are required for window management.
4. **UI**: The About window (built in SwiftUI) provides quick links and info.

---

## Quick Start

### Option 1: Download Prebuilt App

1. [Download the latest release](https://github.com/turtle-key/TabLift/releases)
2. Move TabLift to your `/Applications` folder
3. Launch TabLift
4. **Grant Accessibility permission** when prompted

### Option 2: Build from Source

```bash
git clone https://github.com/turtle-key/TabLift.git
cd TabLift
open TabLift.xcodeproj
```
Then build and run in Xcode.  
You'll be prompted to grant Accessibility permission.

---

## Permissions

TabLift needs **Accessibility Access** to restore minimized windows.  
You'll be prompted on first launch, or you can enable it manually:

```
System Settings → Privacy & Security → Accessibility → Enable TabLift
```

---

## UI Preview

<p align="center">
  <img src="https://github.com/turtle-key/TabLift/blob/e267d33494e1bda72bc97ce73c35997fb1744f3d/app-screenshot.png" alt="App Screenshot" width="320"/>
</p>

TabLift has a simple About window with helpful links:

- [Know more about TabLift](https://tablift.mihai.sh)
- [Buy me a coffee](https://coff.ee/turtle.key)
- [Source code on GitHub](https://github.com/turtle-key/TabLift)
- [Email support](mailto:ghetumihaieduard@gmail.com)

---

## File Structure

```
TabLift/
├── Sources/
│   ├── TabLiftApp.swift          // Main app entry point and delegate
│   ├── AppMonitor.swift          // Listens for app switch events
│   ├── WindowManager.swift       // Restores minimized windows
│   ├── PermissionsService.swift  // Handles Accessibility permissions
│   └── AboutView.swift           // SwiftUI About & links window
├── Assets.xcassets/
├── Info.plist
└── TabLift.xcodeproj
```

---

## Tech Stack

| Component       | Technology                                   |
|-----------------|----------------------------------------------|
| Language        | Swift                                        |
| UI Framework    | SwiftUI (About window), AppKit (behavior)    |
| APIs Used       | Accessibility API (AXUIElement), NSWorkspace |
| Platform        | macOS 12.0 Monterey and later                |
| Packaging       | `.app` bundle (no kernel extensions)         |

---

## Contributing

Pull requests are welcome!  
If you have suggestions, bug reports, or want to help improve TabLift:

1. Fork the repo
2. Create a feature branch:
   ```bash
   git checkout -b feature/your-feature-name
   ```
3. Push and open a PR

---

## License

**MIT License**  
© Mihai-Eduard Ghețu – See [`LICENSE`](LICENSE) for details.

---

## Credits

Built for macOS power users frustrated with Apple's default app switching.  
Thanks to the accessibility community and everyone who contributed feedback.

---

> TabLift – *Lift your windows. Free your workflow.*
