<div align="center">

<img src="Resources/AppIcon.png" alt="Floqy" width="84" />

# Floqy

**Your MacBook notch, evolved into a fast, native command hub.**

[Preview](#preview) · [Install](#install) · [Features](#features) · [Shortcuts](#shortcuts--permissions) · [FAQ](#faq)

<p align="center">
  <a href="https://github.com/budimansusanto777/floqy/releases/latest"><img src="https://img.shields.io/badge/Release-v1.3.1-38bdf8?style=flat-square" height="20" alt="Release v1.3.1" /></a>
  <a href="#requirements"><img src="https://img.shields.io/badge/macOS-14.0%2B-111827?style=flat-square&logo=apple&logoColor=white" height="20" alt="macOS 14.0+" /></a>
  <a href="#build-from-source"><img src="https://img.shields.io/badge/Swift-5%20%2F%206-F05138?style=flat-square&logo=swift&logoColor=white" height="20" alt="Swift 5 / 6" /></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-GPLv3-2563eb?style=flat-square" height="20" alt="License: GPLv3" /></a>
</p>

</div>

---

**Floqy** transforms the hardware notch on MacBook Pro and MacBook Air into a spring-animated productivity hub built with pure Swift, SwiftUI, and AppKit. It tucks cleanly into the camera bezel when idle, surfaces Live Activities when something needs your attention, and expands on hover, `⌘⇧Space`, or file drop into six symmetrical workspace modules with zero external dependencies.

## Preview

https://github.com/user-attachments/assets/98cdbd38-3984-4a02-bd0a-90da5fab0cf4

<p align="center">
  <sub>Walkthrough of all 5 idle companions, Compact Live Activities &amp; Alerts, 6 workspace modules, and 6 themes.</sub>
</p>

## Install

### Download DMG (Recommended)

1. Download **`Floqy-1.3.1.dmg`** from [Latest Releases](https://github.com/budimansusanto777/floqy/releases/latest).
2. Open the `.dmg` and drag **Floqy** to **Applications**.
3. On first launch, if macOS shows an unidentified-developer prompt (the release binary is ad-hoc signed), open **System Settings → Privacy & Security** and click **Open Anyway**.

### Build from source

```bash
git clone https://github.com/budimansusanto777/floqy.git
cd floqy
./scripts/build-app.sh
open build/Floqy.app
```

Build an optimized release bundle and distributable `.dmg`:

```bash
./scripts/build-dmg.sh
open build/Floqy-*.dmg
```

### Requirements

- **Running Floqy:** macOS 14.0 (Sonoma) or newer
- **Building from source:** Swift 5.10+ or Xcode Command Line Tools (`xcode-select --install`)

## Features

### Six Symmetrical Modules

| Wing | Tab | Core Capabilities |
| :--- | :--- | :--- |
| Left | **Home** | Spotify & Apple Music playback controls + quick-launch, EventKit Calendar with 1-click Join, Pomodoro & Todo overview |
| Left | **Shelf** | Smart Drag-and-Drop Tray, native AirDrop, image/PDF compression & WebP conversion, offline Vision OCR |
| Left | **Focus** | Interactive click-or-drag Pomodoro Focus Timer, 4-round session counter, persistent Todo list & local/Obsidian Markdown Notes |
| Right | **Board** | Searchable clipboard history (`⌘⇧V`) with auto-type badges, pinning, clear unpinned, and instant paste |
| Right | **AI** | Antigravity, Gemini CLI, Claude Code & Claude Desktop hook status (`floqy://`), live activity equalizer, token summary & quick launch |
| Right | **System** | Kernel-level Memory Pressure monitor, top RAM consumers, 1-click Quit/Purge, & local dev ports |
| Right | **Settings (`⚙`)** | Inline theme/wallpaper selector, idle companion switcher, & hardware card toggles |

### Companions, Live Activity & Themes

- **Idle Companions (5 modes + Off):** Contextual **Eyes** (perspective depth scaling, cursor proximity curiosity & double-blink), pointer-reactive **Wave** (calm hairline to dual acoustic waves), breathing **Horizon** pill, plus symmetrical left/right tunnel-walking **Dog** (Floqy Poodle) and **Cat** (Calico) that follow your cursor behind the camera bezel and settle smoothly when still.
- **Compact Live Activity & Alerts:** Surrounds the camera with live controls for **Music** (hover to reveal playback controls), **Pomodoro** countdown, **Meeting** heads-up (`in 3m` and `Starting now` + `Join`), **AI Agent** working/done celebrations, **Memory** warnings, and **Headphones / Charging ETA** cards.
- **Themes & Custom Wallpaper:** Keeps the closed notch seamless Obsidian black, then expands into `Obsidian`, `Midnight`, `Pure White`, `Sakura Blush`, `Rose Velvet`, or a custom notch wallpaper image (`Dark` / `Light`).
- **Multi-Monitor & Launch at Login:** Choose `Built-in Notch Display`, `Primary Display`, or `Follow Cursor`, and enable `Start Floqy at login` via macOS `SMAppService`.

## Shortcuts & Permissions

- `⌘⇧Space` · Toggle expanded notch
- `⌘⇧V` · Jump straight to **Board** (Clipboard history)
- `⌘1` – `⌘6` · Switch between `Home`, `Shelf`, `Focus`, `Board`, `AI`, and `System`
- `Esc` · Collapse notch

| Permission | Used For | Required? |
| :--- | :--- | :--- |
| **Automation (AppleEvents)** | Controlling & launching Spotify and Apple Music | Optional (Home tab) |
| **Calendars (EventKit)** | Reading upcoming macOS, Google, iCloud & Exchange events | Optional (Home tab) |
| **Folder Access (Security-Scoped)** | Saving notes to an Obsidian Vault or custom folder | Optional (Focus tab) |

## FAQ

**Why does macOS ask for confirmation on first launch?**
Floqy releases are ad-hoc signed without a paid Apple Developer ID certificate. Opening **System Settings → Privacy & Security → Open Anyway** once trusts your local copy.

**Does cursor tracking need Accessibility permission?**
No. Eye gaze, acoustic wave wake-up, and Calico/Poodle tunnel walks use standard AppKit pointer events (`NSEvent` global monitor) with zero Accessibility permissions required.

**Does Floqy work on external monitors without a hardware notch?**
Yes. Floqy adapts its geometry cleanly to external screens without a camera bezel and lets you pick `Built-in Notch Display`, `Primary Display`, or `Follow Cursor` in Settings.

**Is any data sent to external servers?**
No. Floqy runs 100% locally with no analytics or telemetry. **Board** automatically skips sensitive pasteboard types (`ConcealedType`, `TransientType`, `AutoGeneratedType`, and 1Password entries).

**How do AI agent hooks trigger the notch?**
Connect supported agents from the **AI** tab in one click, or trigger events locally via URL scheme (for example `floqy://ai?agent=claude&state=working` and `state=done`).

## License

Floqy is free software licensed under the **GNU General Public License v3.0 (GPLv3)**. See [LICENSE](LICENSE) for details. Changelog history is published on [Releases](https://github.com/budimansusanto777/floqy/releases).

Copyright © 2026 [budimansusanto777](https://github.com/budimansusanto777/floqy).
