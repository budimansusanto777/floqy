<div align="center">

# Floqy

**Your MacBook notch, evolved into a fast, native command hub.**

Built with native Swift, SwiftUI, and AppKit for macOS 14.0+ (Sonoma).

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)
[![macOS 14.0+](https://img.shields.io/badge/macOS-14.0%2B-black.svg)](#requirements)
[![Swift](https://img.shields.io/badge/Swift-5%20%2F%206-orange.svg)](#build-from-source)

</div>

---

## What is Floqy?

**Floqy** transforms the hardware notch on MacBook Pro and MacBook Air into a spring-animated productivity hub. It stays tucked into the camera bezel until you hover, press `⌘⇧Space`, or drop a file—expanding smoothly into six symmetrical workspace modules with customizable idle companions, themes, and hardware status cards.

## Module Matrix

| Wing | Tab | Core Capabilities |
| :--- | :--- | :--- |
| Left | **Home** | Spotify & Apple Music playback controls, Google/iCloud/Exchange Calendar + 1-click Join, Pomodoro & Todo overview |
| Left | **Shelf** | Smart Drag-and-Drop Tray, native AirDrop, image/PDF compression & WebP conversion, offline Vision OCR |
| Left | **Focus** | Interactive click-or-drag Pomodoro Focus Timer, 4-round session counter, persistent Todo list & local/Obsidian Markdown Notes |
| Right | **Clipboard** | Searchable clipboard history (`⌘⇧V`) with auto-type badges, pinning, clear unpinned, and instant paste |
| Right | **AI** | Antigravity, Gemini CLI, Claude Code & Claude Desktop hook status (`floqy://`), live activity equalizer, & quick launch |
| Right | **System** | Kernel-level Memory Pressure monitor, top RAM consumers, 1-click Quit/Purge, & local dev ports |
| Right | **Settings (`⚙`)** | Inline theme/wallpaper selector, idle companion (`Off`, `Eyes`, `Cat`, `Dog`, `Wave`, `Horizon`), hardware card toggles |

## Key Features

- **Hardware Status Cards** — Battery-aware Headphones connected & Charging ETA alert cards.
- **Idle Notch Companions** — Choose `Off`, contextual `Eyes`, `Wave` hairline, ambient `Horizon` pill, or right-wing 1-row `Cat` / `Dog`.
- **Expanded Themes & Custom Wallpaper** — Keeps the closed notch seamless Obsidian black, then opens in `Obsidian`, `Midnight`, `Pure White`, `Sakura Blush`, `Rose Velvet`, or a custom notch wallpaper image (`Dark` / `Light`).
- **Multi-Monitor & Launch at Login** — Select `Built-in Notch Display`, `Primary Display`, or `Follow Cursor`, and toggle `Start Floqy at login` via macOS `SMAppService`.

## Notch States

- **Idle** — Flush inside the hardware camera (`Off`), a `92pt` tapered mini-chin (`Eyes` / `Wave` / `Horizon`), or a single-row right wing (`Cat` / `Dog`).
- **Compact Live Activity** — Symmetrical Obsidian wings around the camera for Music, Focus timer, meeting alerts, AI activity, or RAM pressure.
- **Expanded Hub** — Clean zero-shadow workspace (`596pt` wide) with concave top ears and spring shell morphing.

## Permissions

| Permission | Used For | Required? |
| :--- | :--- | :--- |
| **Automation (AppleEvents)** | Controlling Spotify & Apple Music playback | Optional (Home tab) |
| **Calendars (EventKit)** | Reading upcoming macOS / Google Calendar events | Optional (Home tab) |
| **Folder Access (Security-Scoped)** | Saving notes to an Obsidian Vault or custom folder | Optional (Focus tab) |

## Requirements

- macOS 14.0 (Sonoma) or newer
- Swift 5.10+ / Xcode Command Line Tools (`xcode-select --install`)

## Build & Package

```bash
git clone https://github.com/budimansusanto777/floqy.git
cd floqy
./scripts/build-app.sh
open build/Floqy.app
```

Build an optimized release bundle and distributable `.dmg`:

```bash
./scripts/build-dmg.sh
open build/Floqy-1.0.0.dmg
```

## Roadmap

- [x] **Phase 0** — Repository setup, Core Notch Engine (`NSScreen` geometry, `NSPanel`, concave ears, spring states), global shortcut (`⌘⇧Space`), menu bar & Settings shell
- [x] **Phase 1** — Daily Flow Core (`Home`: Spotify/Apple Music, EventKit Calendar, Pomodoro & Todo)
- [x] **Phase 2** — Productivity Power Tools (`Shelf` Smart Tray, `Focus` Notes/Obsidian, `Clipboard` Manager)
- [x] **Phase 3** — Unified `System` Tab (Memory Monitor + Local Dev Ports)
- [x] **Phase 4** — AI Agent Notifications & Hooks (Antigravity, Gemini CLI, Claude Code + Claude Desktop quick launch)
- [x] **Phase 5** — Custom App Icon (`.icns`), Launch at Login (`SMAppService`), Multi-Monitor Display selection, `.dmg` distribution, & UI polish

## License

Floqy is free software licensed under the **GNU General Public License v3.0 (GPLv3)**. See [LICENSE](LICENSE) for details.

Copyright © 2026 [budimansusanto777](https://github.com/budimansusanto777/floqy).
