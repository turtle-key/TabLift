  <p align="center">
    <img src="https://bucket.tablift.dev/banner.png" alt="TabLift Banner" width="400"/>
  </p>
  
  <p align="center">
    <a href="https://hackclub.com/hackatime/">
      <img src="https://hackatime-badge.hackclub.com/U092L97H9LZ/TabLift" alt="Hackatime Badge" style="margin-right:4px;"/>
    </a>
    <a href="https://github.com/turtle-key/TabLift/blob/main/LICENSE">
      <img src="https://img.shields.io/github/license/turtle-key/TabLift?color=29c469&label=License" alt="License: MIT" style="margin-right:4px;"/>
    </a>
    <a href="https://github.com/turtle-key/TabLift/releases">
      <img src="https://img.shields.io/github/v/release/turtle-key/TabLift?color=007aff&label=Release" alt="Latest Release" style="margin-right:4px;"/>
    </a>
    <a href="https://github.com/turtle-key/TabLift/releases">
      <img src="https://img.shields.io/github/downloads/turtle-key/TabLift/total?label=Downloads" alt="Downloads"/>
    </a>
    <a href="https://github.com/turtle-key/TabLift/stargazers">
      <img src="https://img.shields.io/github/stars/turtle-key/TabLift" alt="Stars"/>
    </a>
  </p>
  <p align="center">
    <img src="https://img.shields.io/badge/macOS-000000?style=flat&logo=apple&logoColor=white" alt="macOS" style="margin-right:4px;"/>
    <img src="https://img.shields.io/badge/Swift-F05138?style=flat&logo=swift&logoColor=white" alt="Swift" style="margin-right:4px;"/>
    <img src="https://img.shields.io/badge/HTML5-E34F26?style=flat&logo=html5&logoColor=white" alt="HTML5" style="margin-right:4px;"/>
    <img src="https://img.shields.io/badge/Svelte-FF3E00?style=flat&logo=svelte&logoColor=white" alt="Svelte" style="margin-right:4px;"/>
    <img src="https://img.shields.io/badge/TypeScript-3178C6?style=flat&logo=typescript&logoColor=white" alt="TypeScript" style="margin-right:4px;"/>
    <img src="https://img.shields.io/badge/CSS-563d7c?&style=flat&logo=css3&logoColor=white" alt="CSS" style="margin-right:4px;"/>
  </p>
  
  <p align="center">
    TabLift is a lightweight macOS utility that restores minimized apps instantly when switching with <code>⌘ Tab</code> or <code>⌘ `</code>.<br>
    By default, macOS ignores minimized windows unless you hold the <code>Option</code> key.<br>
    TabLift fixes this behavior, making app switching intuitive and seamless — no extra keys needed.
  </p>
  
  <p align="center">
    <a href="https://tablift.dev"><b>🌐 Visit the TabLift website</b></a>
  </p>

---
## Features

- **Instantly restores minimized windows** when you switch to an app using <code>⌘ Tab</code> or <code>⌘ `</code>
- **Multiple settings** for customizing the window, dock & app management
- <img align="right" src="https://bucket.tablift.dev/tablift-accessibility.png" alt="Accessibility pop-up" width="320">
  <strong>Accessibility pop-up</strong> that warns the users when the macOS API is unavailable and what to do.
  <br clear="right">
- <img align="right" src="https://bucket.tablift.dev/tablift-dock.png" alt="Dock Window Preview" width="320">
  <strong>Dock pop-ups with live window previews:</strong> Shows a beautiful pop-up when you hover Dock icons, including a diamond indicator for minimized windows.
  <br clear="right">
- <img align="right" src="https://bucket.tablift.dev/tablift-tilda.png" alt="Dock Window Preview" width="320">
  <strong>App Window Switcher</strong> that displays the windows of the same app and is activated by the <code>⌘ `</code> shortcut
  <br clear="right">
- **Menu bar icon** with quick popover for access and control
- **Runs quietly in the background** with minimal resource usage
- **Compatible** with Mission Control, multiple desktops, and most macOS versions
- **Website** included in the repo, for documentation and SEO
---
  
  ## Quick Start
  
  ### Option 1: Download Prebuilt App
  
  1. [Download the latest release](https://github.com/turtle-key/TabLift/releases/latest)
  2. Open the .dmg file and move the app into the /Applications folder
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
  
  ### System Requirements
  - **macOS 13.0 Ventura** or later
  - **Apple Silicon & Intel** support
  
  ### Website
  
  The website sources are in the `website/` folder, powered by SvelteKit.  
  To run locally:
  
  ```bash
  cd website
  npm install
  npm run dev
  ```
  
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
    <img src="https://bucket.tablift.dev/tablift-about.png" alt="App About Tab" width="320"/>
    <img src="https://bucket.tablift.dev/tablift-general.png" alt="App General Tab" width="320"/>
    <img src="https://bucket.tablift.dev/tablift-support.png" alt="App Support Tab" width="320"/>
  </p>
  
  ---
  ## Star History
  
  [![Star History Chart](https://api.star-history.com/svg?repos=turtle-key/TabLift&type=Date)](https://www.star-history.com/#turtle-key/TabLift&Date)
  
  ## Contributing
  
  Pull requests are welcome!
  If you have suggestions, bug reports, or want to help improve TabLift:
  
  1. Fork the repo
  2. Create a feature branch:
     ```bash
     git checkout -b feature/your-feature-name
     ```
  3. Push and open a PR

  ### Support Development
- **[Buy me a coffee](https://www.buymeacoffee.com/turtle.key)** to fuel development
- **[Star the repo](https://github.com/turtle-key/TabLift)** to help others discover TabLift
---

## License

**AGPL-3.0 License**  
© Mihai-Eduard Ghețu – See [`LICENSE`](LICENSE) for details.

## Credits

Built for macOS power users frustrated with Apple's default app switching.  
Thanks to the accessibility community and everyone who contributed feedback.

---

> TabLift – *Lift your windows. Free your workflow.*
