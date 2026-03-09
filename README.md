<!-- SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me> -->
<!-- SPDX-License-Identifier: GPL-3.0-or-later -->

> [!WARNING]
> **Pre-Alpha Software** - This project is under heavy development and not ready for production use.
> APIs may change without notice. Use at your own risk.

# Vauchi macOS

Native macOS desktop app for Vauchi — privacy-focused contact card exchange.

Built with SwiftUI + AppKit. Uses `vauchi-platform-swift` SPM package for core bindings (shared with iOS).

## Prerequisites

- macOS 14+
- Xcode 15+
- [xcodegen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

## Build

```bash
xcodegen generate
xcodebuild -scheme Vauchi -configuration Debug build
```

## Architecture

This app implements the core-driven UI contract:

- **ScreenRenderer** renders `ScreenModel` from core
- **14 component views** map to core's `Component` enum variants
- **ActionHandler** maps user input to `UserAction` enum
- **Platform chrome**: menu bar, system tray, keyboard shortcuts

All business logic lives in `vauchi-core` (Rust). This repo is a pure rendering layer.

## License

GPL-3.0-or-later
