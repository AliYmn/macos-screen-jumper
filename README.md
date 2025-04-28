# Jumper

> A lightweight macOS utility for quickly moving your cursor between multiple displays using keyboard shortcuts.

<p align="center">
  <img src="https://res.cloudinary.com/aliyaman/image/upload/v1745871118/blag3l6tj4yjlq2x3v7y.png" alt="Jumper Screenshot" width="600"/>
</p>

## Overview

Jumper is a native macOS application built with Swift and SwiftUI that solves a simple problem: moving your cursor between multiple displays quickly. It sits in your menu bar and allows you to jump your cursor to any connected display with a keyboard shortcut.

## Features

- **Instant cursor movement** between multiple displays
- **Global keyboard shortcuts** (default: Control+Shift+Number)
- **Customizable visual effects** with three styles: Modern, Classic, and Minimal
- **Sound feedback** with five different sound options
- **Automatic screen detection** when displays are connected or disconnected
- **Low resource usage** with minimal CPU and memory footprint
- **Launch at login** option

<p align="center">
  <img src="https://res.cloudinary.com/aliyaman/image/upload/v1745865489/il0ktfmtocr5pyu7ico2.png" alt="Jumper Settings" width="600" />
</p>

## Project Details

### Technical Specifications

- **Built with**: Swift 5.9+ and SwiftUI with AppKit components
- **Minimum macOS**: 12.0 (Monterey)
- **Required Permissions**: Accessibility (for keyboard shortcuts and cursor movement)

### Main Components

- **jumperApp.swift**: Core application logic and menu bar integration
- **SettingsView.swift**: User interface for customizing preferences
- **ShortcutManager.swift**: Keyboard shortcut management system

### Key Features Implementation

- **Keyboard Shortcuts**: Global shortcut system using NSEvent monitoring
- **Multi-screen Support**: Screen detection and management with NSScreen
- **Visual Effects**: Custom animations with CAShapeLayer
- **Settings**: User preferences stored in UserDefaults

### Building From Source

```bash
# Clone the repository
git clone https://github.com/AliYmn/macos-jumper.git
cd macos-jumper

# Open in Xcode
open jumper.xcodeproj
```

## Installation

### For Users

1. Download the latest release from the [releases page](https://github.com/AliYmn/macos-jumper/releases)
2. Move Jumper.app to your Applications folder
3. Launch Jumper and grant Accessibility permissions when prompted

### From Source

1. Build the project in Xcode
2. Run the product or export a signed application

## Usage

1. Click the Jumper icon in your menu bar
2. Use the keyboard shortcuts shown next to each screen (⌃⇧1, ⌃⇧2, etc.)
3. Customize shortcuts and settings through the preferences window

<p align="center">
  <img src="https://res.cloudinary.com/aliyaman/image/upload/v1745865544/wlucueavub3phg9gcdtk.png" alt="Jumper Shortcuts" width="600" />
</p>

## Privacy & Permissions

Jumper requires Accessibility permissions to:
- Monitor global keyboard shortcuts
- Move the cursor between screens

The application operates entirely locally and does not collect or transmit any data.

## Contributing

Contributions are welcome! Feel free to submit issues or pull requests.

## License

MIT

---

© 2025 Ali Yaman
