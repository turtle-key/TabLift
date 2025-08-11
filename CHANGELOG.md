<style>
  h1:first-of-type {
    display: none;
  }
  .my-5 {
    margin: unset !important;
  }
  .markdown-body img {
    max-width: 50%;
  }
  @media (prefers-color-scheme: dark) {
    body {
      color-scheme: dark;
      color: white;
      background: transparent;
    }
    a, :link {
      color: #419cff;
    }
    a:active, link:active {
      color: #ff1919;
    }
  }
  .donation-link {
    position: relative;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    padding: 8px 16px;
    min-width: 180px;
    border-radius: 8px;
    background: linear-gradient(135deg, rgba(255,255,255,0.9) 0%, rgba(248,250,252,0.8) 100%);
    color: #000 !important;
    font-size: 0.9em;
    font-weight: bold;
    text-decoration: none;
    border: 1px solid rgba(209, 213, 219, 0.6);
    box-shadow: 
      0 4px 20px rgba(0,0,0,0.08),
      0 1px 3px rgba(0,0,0,0.1),
      inset 0 1px 0 rgba(255,255,255,0.6);
    overflow: hidden;
    transition: all 0.5s cubic-bezier(0.25, 0.46, 0.45, 0.94);
    backdrop-filter: blur(4px);
    letter-spacing: 0.025em;
  }
  .donation-link::before {
    content: '';
    position: absolute;
    top: 0; left: 0; right: 0; bottom: 0;
    background: linear-gradient(
      to bottom,
      #61BB46 0%,
      #61BB46 16.66%,
      #FDB827 16.66%,
      #FDB827 33.33%,
      #F5821F 33.33%,
      #F5821F 50%,
      #E03A3E 50%,
      #E03A3E 66.66%,
      #963D97 66.66%,
      #963D97 83.33%,
      #009DDC 83.33%,
      #009DDC 100%
    );
    transform: translateY(-100%);
    transition: transform 0.5s cubic-bezier(0.25, 0.46, 0.45, 0.94);
    z-index: 1;
    border-radius: inherit;
    opacity: 0.95;
  }
  .donation-link:hover::before {
    transform: translateY(0%);
  }
  .donation-link:not(:hover)::before {
    transform: translateY(100%);
  }
  .donation-link::after {
    content: '';
    position: absolute;
    top: -2px; left: -2px; right: -2px; bottom: -2px;
    background: linear-gradient(
      45deg,
      #61BB46,
      #FDB827,
      #F5821F,
      #E03A3E,
      #963D97,
      #009DDC
    );
    border-radius: inherit;
    z-index: -1;
    opacity: 0;
    filter: blur(8px);
    transition: opacity 0.5s ease;
  }
  .donation-link:hover::after {
    opacity: 0.3;
  }
  .donation-link:hover {
    transform: translateY(-1px);
    box-shadow: 
      0 8px 30px rgba(0,0,0,0.12),
      0 4px 12px rgba(0,0,0,0.08),
      inset 0 1px 0 rgba(255,255,255,0.2);
    border-color: rgba(209, 213, 219, 0.8);
    color: white !important;
  }
  .donation-link span {
    position: relative;
    z-index: 10;
    transition: all 0.5s cubic-bezier(0.25, 0.46, 0.45, 0.94);
  }
  .donation-link:hover span {
    filter: drop-shadow(0 1px 2px rgba(0,0,0,0.3));
  }
</style>
<div class="donation-link" target="_blank">❤️ Support turtle-key at https://buymeacoffee.com/turtle.key</div>

<a id="v1.9"></a>
# [TabLift v1.9](https://github.com/turtle-key/TabLift/releases/tag/v1.9) - 2025-08-05

# TabLift v1.9

## What’s Changed

- **Performance Profiles for Dock Previews:** Added customizable profiles to fine-tune how quickly Dock popups appear and fade out. Choose between Relaxed, Default, and Speedy to match your workflow.
- **Marquee Text in Dock Previews:** Window titles are now animated with smooth marquee text, ensuring even long titles are always visible and readable.
- **New Keyboard Shortcut:** Added ⌘⇧M to instantly minimize all windows of the frontmost app, making it easy to clear your workspace.
- **Settings & UI Improvements:**  
  - Settings window now supports sticky footers and improved ordering for options.
  - About and Support tabs are more visually appealing, with new icons and hover effects.
  - Added demo videos directly in settings to explain features.
  - Accessibility permission checks and fixes to ensure full compatibility.
  - Made the app automatically move itself to the Applications folder (if not already there), for a more native install experience.
  - Improved support window aesthetics and clarity.
- **Dock Popup Enhancements:**  
  - Dock popups now refresh continuously while hovered, so window previews are always up-to-date.
  - Window previews update themselves without closing when you hover over different icons.
  - Improved support for minimized indicators and filetype icons in window previews.
- **Menu Bar:**  
  - Menu bar icon now features hover effects and accessibility labels for VoiceOver.
  - Improved popover styling with blur, rounded corners, and accent color touches.
- **Bug Fixes & Refinements:**  
  - Fixed multiple accessibility API and permission issues.
  - Various layout and merge conflict resolutions.
  - Made sure settings changes apply instantly at first startup.
  - Fixed undercorrection and help menu issues.
  - Numerous minor UI and performance tweaks.

---

For a complete history of changes, see the [commit log](https://github.com/turtle-key/TabLift/commits/main).

<sub>Note: This summary includes only the most recent changes since the last release. For more details, visit the [TabLift repository](https://github.com/turtle-key/TabLift).</sub>

[Changes][v1.9]


<a id="v1.8"></a>
# [TabLift v1.8](https://github.com/turtle-key/TabLift/releases/tag/v1.8) - 2025-07-30

# TabLift v1.8

## What’s Changed

- Added beautiful Dock popups with live window previews and clear minimized indicators. Hovering a Dock icon now shows all open and minimized windows for that app, making it easier to jump to exactly the window you want.
- Fixed several UI layout issues and made Settings more responsive, especially when resizing.
- Various bug fixes and refinements to window restoration logic for better compatibility with more apps and mission control.

---

For a complete history of changes, see the [commit log](https://github.com/turtle-key/TabLift/commits/main).

<sub>Note: This summary includes only the most recent changes since the last release. For more details, visit the [TabLift repository](https://github.com/turtle-key/TabLift).</sub>

[Changes][v1.8]


<a id="v1.7"></a>
# [TabLift v1.7](https://github.com/turtle-key/TabLift/releases/tag/v1.7) - 2025-07-29

# TabLift v1.7

## What’s Changed

- Added a new toggle in General settings to show TabLift in the Dock.  
  by [@turtle-key](https://github.com/turtle-key) in [`f5ebdb5958`](https://github.com/turtle-key/TabLift/commit/f5ebdb595822a82806e6811ec794d70b66123cc6)

- Implemented automatic minimization of the previously focused window upon app switching for a cleaner workflow.  
  by [@turtle-key](https://github.com/turtle-key) in [`5048abde03`](https://github.com/turtle-key/TabLift/commit/5048abde0320b31b7f8c3c47faabd808bc808d2e)

- Enabled automatic window creation when switching to apps without open windows, improving accessibility.  
  by [@turtle-key](https://github.com/turtle-key) in [`3ccd64aed3`](https://github.com/turtle-key/TabLift/commit/3ccd64aed3528a6bf7985da8de7fd00b17543d05)

- Fixed a timing bug causing delays between Cmd+Tab press and window unminimization, smoothing out the switcher experience.  
  by [@turtle-key](https://github.com/turtle-key) in [`36f2e2d302`](https://github.com/turtle-key/TabLift/commit/36f2e2d30292b2dd0d2e85d79c689ab81616a091)


---

For a complete history of changes, see the [commit log](https://github.com/turtle-key/TabLift/commits/main).

<sub>Note: This summary includes only the most recent changes since the last release. For more details, visit the [TabLift repository](https://github.com/turtle-key/TabLift).</sub>

[Changes][v1.7]


<a id="v1.6.1"></a>
# [TabLift v1.6.1](https://github.com/turtle-key/TabLift/releases/tag/v1.6.1) - 2025-07-25

# TabLift v1.6.1

## What’s Changed

- Made the footer (license link and Quit button) stick to the bottom of the window in the General tab, so it remains static even when the form content is short.  
  by [@turtle-key](https://github.com/turtle-key) in [`d44899987c`](https://github.com/turtle-key/TabLift/commit/d44899987c436d2dbbd8bd2890acf38f9cfe65e9)

---

For a complete history of changes, see the [commit log](https://github.com/turtle-key/TabLift/commits/main).

<sub>Note: This summary includes only the most recent changes since the last release. For more details, visit the [TabLift repository](https://github.com/turtle-key/TabLift).</sub>

[Changes][v1.6.1]


<a id="v1.6"></a>
# [TabLift v1.6](https://github.com/turtle-key/TabLift/releases/tag/v1.6) - 2025-07-22

## What's Changed
* Improved detection of app switching via Cmd+Tab and Cmd+` to ensure minimized windows are restored accurately. by [@turtle-key](https://github.com/turtle-key) in [#15](https://github.com/turtle-key/TabLift/pull/15)
* Fixed NSPopover behavior to correctly dismiss when interacting with other menu bar items. by [@turtle-key](https://github.com/turtle-key) in [#16](https://github.com/turtle-key/TabLift/pull/16)

---

For a complete history of changes, see the [commit log](https://github.com/turtle-key/TabLift/commits/main).

<sub>Note: This summary includes only the most recent changes since the last release. For more details, visit the [TabLift repository](https://github.com/turtle-key/TabLift).</sub>

[Changes][v1.6]


<a id="v1.5"></a>
# [TabLift v1.5](https://github.com/turtle-key/TabLift/releases/tag/v1.5) - 2025-06-30

## What's Changed
* Added support for cmd+backtick with minimized windows & added a toggle for minimized windows to select between bringing all windows or just the last focused ones up. by [@turtle-key](https://github.com/turtle-key) in [#10](https://github.com/turtle-key/TabLift/pull/10)
* Menu Bar functionality added by [@turtle-key](https://github.com/turtle-key) in [#11](https://github.com/turtle-key/TabLift/pull/11)

---

For a complete history of changes, see the [commit log](https://github.com/turtle-key/TabLift/commits/main).

<sub>Note: This summary includes only the most recent changes since the last release. For more details, visit the [TabLift repository](https://github.com/turtle-key/TabLift).</sub>

[Changes][v1.5]


<a id="v1.4"></a>
# [TabLift v1.4](https://github.com/turtle-key/TabLift/releases/tag/v1.4) - 2025-06-30

## What’s New

### Accessibility Privilege Management:

You can now enable or manage Accessibility permissions directly from the General tab in the Settings window. This streamlines onboarding and makes it much easier to grant or check the necessary privileges for TabLift to function.

---

For a complete history of changes, see the [commit log](https://github.com/turtle-key/TabLift/commits/main).

<sub>Note: This summary includes only the most recent changes since the last release. For more details, visit the [TabLift repository](https://github.com/turtle-key/TabLift).</sub>

[Changes][v1.4]


<a id="v1.3"></a>
# [TabLift v1.3](https://github.com/turtle-key/TabLift/releases/tag/v1.3) - 2025-06-29

## What’s New

### Visual & UI Improvements

**New App Icon:**  
The app icon has been completely redesigned for a fresh look.

**Modern About & Settings Window:**  
- The About window is now part of a new tabbed Settings window with a cleaner design.
- The app version label in the About window is now clickable and links directly to the latest GitHub release.
- Added a clickable license link, and website and donation links.

**Accessibility Permission Flow:**  
- New Accessibility permission prompt window with clear instructions and helpful links for a smoother onboarding experience.

---

### Features & Enhancements

- Built-in update checker (using Sparkle, with configurable intervals and automatic update support).
- Improved permission management and onboarding screens for first-time users.
- Enhanced compatibility with modern versions of macOS (13+), including Apple Silicon support.

---

### Metadata & Packaging

- Updated Xcode project and bundle metadata to reflect the new version and icon.
- Internal refactoring and modularization (renamed and reorganized Swift files).
- Updated and expanded the included website (powered by SvelteKit) for better documentation, SEO, and visuals.
- Project now includes Open Graph & Twitter cards, FAQ, and privacy policy pages.

---

For a complete history of changes, see the [commit log](https://github.com/turtle-key/TabLift/commits/main).

<sub>Note: This summary includes only the most recent changes since the last release. For more details, visit the [TabLift repository](https://github.com/turtle-key/TabLift).</sub>

[Changes][v1.3]


<a id="v1.2"></a>
# [TabLift v1.2](https://github.com/turtle-key/TabLift/releases/tag/v1.2) - 2025-06-23

## What’s New

### Visual & UI Improvements
- **New App Icon:**  
  The app icon has been completely redesigned for a fresh look ([commit](https://github.com/turtle-key/TabLift/commit/e6579488966df0a98fe28397e15ba7f456522bf9), [commit](https://github.com/turtle-key/TabLift/commit/9d254500d7ef40de51e17ca5b40d66d4c046f102)).
- **About Window Enhancements:**  
  - The app version label in the About window is now clickable and links directly to the latest GitHub release ([commit](https://github.com/turtle-key/TabLift/commit/241e7824d4201196bb5f365890c48c38c2f41d98)).
  - Added a license link.

### Metadata & Packaging
- Updated Xcode project and bundle metadata to reflect the new version and icon ([commit](https://github.com/turtle-key/TabLift/commit/e192924bdcd59fb2eb8f7beec0cb3d9449868fd5)).
- Internal updates for app packaging.

---

**For a complete history of changes, see the [commit log](https://github.com/turtle-key/TabLift/commits/main).**  
_Note: This summary includes only the most recent changes since the last release. For more details, visit the repository._


[Changes][v1.2]


<a id="v1.1"></a>
# [TabLift v1.1](https://github.com/turtle-key/TabLift/releases/tag/v1.1) - 2025-06-21

## What’s New

### Features & Improvements

- **Quit Button Added:**  
  You can now quickly quit TabLift using a new, conveniently placed "Quit" button in the About window.  
  ([See commit](https://github.com/turtle-key/TabLift/commit/af25f4b4f8b5fb7cc7a766ceb3c45543485d6870))

- **Dynamic App Version Display:**  
  The About window now automatically displays the current app version and build number, fetching them from your app’s bundle info.  
  ([See commit](https://github.com/turtle-key/TabLift/commit/a7d99b76eeeae93b7d0d2d0513085909733b2a14))

###  Bug Fixes

- **UI Bug Fix:**  
  Fixed a bug where static colors did not adapt to the system appearance, ensuring consistent look across light and dark mode.  
  ([See commit](https://github.com/turtle-key/TabLift/commit/afec6908c3a5c13db720161394e13cf46d239cf6))
For a full list of changes and details, see the [commit history](https://github.com/turtle-key/TabLift/commits/main).

[Changes][v1.1]


<a id="v1.0"></a>
# [TabLift v1.0](https://github.com/turtle-key/TabLift/releases/tag/v1.0) - 2025-06-21

TabLift v1.0(1) is the first public release of this lightweight macOS utility. With TabLift, your minimized windows are instantly restored whenever you switch between apps using ⌘+Tab—no need to hold extra keys or hunt for hidden windows. 

**Key Features:**
- Automatically restores minimized app windows on app switch (⌘+Tab)
- Seamless, native integration with macOS (works with Mission Control and multiple desktops)
- Runs quietly in the background with minimal resource usage
- Simple setup: just launch the app and grant Accessibility permission
- Open source and privacy-friendly

Perfect for anyone who wants a more intuitive and efficient window management experience on macOS!

> TabLift – *Lift your windows. Free your workflow.*

[Changes][v1.0]


[v1.9]: https://github.com/turtle-key/TabLift/compare/v1.8...v1.9
[v1.8]: https://github.com/turtle-key/TabLift/compare/v1.7...v1.8
[v1.7]: https://github.com/turtle-key/TabLift/compare/v1.6.1...v1.7
[v1.6.1]: https://github.com/turtle-key/TabLift/compare/v1.6...v1.6.1
[v1.6]: https://github.com/turtle-key/TabLift/compare/v1.5...v1.6
[v1.5]: https://github.com/turtle-key/TabLift/compare/v1.4...v1.5
[v1.4]: https://github.com/turtle-key/TabLift/compare/v1.3...v1.4
[v1.3]: https://github.com/turtle-key/TabLift/compare/v1.2...v1.3
[v1.2]: https://github.com/turtle-key/TabLift/compare/v1.1...v1.2
[v1.1]: https://github.com/turtle-key/TabLift/compare/v1.0...v1.1
[v1.0]: https://github.com/turtle-key/TabLift/tree/v1.0

<!-- Generated by https://github.com/rhysd/changelog-from-release v3.9.0 -->
