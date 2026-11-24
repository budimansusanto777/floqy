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

**Floqy** transforms the hardware notch on MacBook Pro and MacBook Air into a spring-animated productivity hub. It stays tucked into the notch bezel until you hover, press `⌘⇧Space`, or drop a file—expanding smoothly into six symmetrical workspace modules.

## Module Matrix

| Wing | Tab | Core Capabilities |
| :--- | :--- | :--- |
| Left | **Home** | Spotify & Apple Music playback controls, Google Calendar upcoming meeting + 1-click Join, mini Pomodoro |
| Left | **Files** | Smart Drag-and-Drop Tray, native AirDrop, image/PDF compression & WebP conversion, offline OCR |
| Left | **Notes & Todo** | Obsidian Quick Note capture (append to Vault Markdown) + persistent Todo list & Focus Timer |
| Right | **Copy** | Searchable clipboard history (`⌘⇧V`) with auto-type badges, pinning, and AI handoff |
| Right | **AI** | BYOK (Gemini, OpenAI, Claude) & local Ollama agent with cross-module context and background orb |
| Right | **System** | Kernel-level Memory Pressure monitor, top RAM consumers, 1-click Kill/Purge, Dev Live Activity & local ports |

## Notch States

- **Idle** — Flush with the hardware notch (`196 × 32 pt`) or tucked cleanly at the top edge on external displays.
- **Compact Live Activity** — Symmetrical wings around the camera (`360–388 × 34 pt`) for Music, Dev Build progress, Pomodoro timer, AI status, or RAM alerts.
- **Expanded Hub** — Full interactive workspace (`560 × 228 pt` below camera clearance) with concave top ears and spring physics.

## CLI Preview (Phase 3)

Report build progress, test runs, or deployment status directly into the Compact Notch from any terminal or script:

```bash
floqy live "swift build -c release" --progress 68
floqy done "Floqy.app build finished in 3.2s"
```

## Permissions

| Permission | Used For | Required? |
| :--- | :--- | :--- |
| **Automation (AppleEvents)** | Controlling Spotify & Apple Music playback | Optional (Home tab) |
| **Calendars (EventKit)** | Reading upcoming macOS / Google Calendar events | Optional (Home tab) |
| **Folder Access (Security-Scoped)** | Appending notes to your Obsidian Vault | Optional (Notes tab) |
| **Keychain** | Securely storing BYOK AI API keys | Optional (AI tab) |

## Requirements

- macOS 14.0 (Sonoma) or newer
- Swift 5.10+ / Xcode Command Line Tools (`xcode-select --install`)

## Build from Source

```bash
git clone https://github.com/budimansusanto777/floqy.git
cd floqy
./scripts/build-app.sh
open build/Floqy.app
```

For a release build:

```bash
./scripts/build-app.sh release
open build/Floqy.app
```

## Roadmap

- [x] **Phase 0** — Repository setup, Core Notch Engine (`NSScreen` geometry, `NSPanel`, concave ears, spring states), global shortcut (`⌘⇧Space`), menu bar & Settings shell
- [ ] **Phase 1** — Daily Flow Core (`Home`: Spotify/Apple Music, EventKit Calendar, Pomodoro & Todo)
- [ ] **Phase 2** — Productivity Power Tools (`Files` Smart Tray, `Notes → Obsidian`, `Copy` Clipboard Manager)
- [ ] **Phase 3** — Unified `System` Tab (Memory Monitor + Dev Live Activity + `floqy` CLI)
- [ ] **Phase 4** — AI Agent Integration (BYOK + Ollama + Cross-Module Context)
- [ ] **Phase 5** — Polish, Launch at Login, multi-monitor & `.dmg` distribution

## License

Floqy is free software licensed under the **GNU General Public License v3.0 (GPLv3)**. See [LICENSE](LICENSE) for details.

Copyright © 2026 [budimansusanto777](https://github.com/budimansusanto777/floqy).
