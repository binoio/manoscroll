# ManoScroll

A macOS app that enables hands-free scrolling using hand gesture recognition via your webcam.

## Features

- **Hand Gesture Scrolling**: Use open palm (scroll up) and closed fist (scroll down) gestures to scroll
- **Background Operation**: Works while other apps are in focus—scroll in any application
- **Configurable Settings**: Fine-tune sensitivity, smoothing, dead zones, and detection thresholds
- **Menu Bar & Dock**: Choose to show the app in the menu bar, dock, or both
- **Camera Preview**: Optional live preview window to see what the camera detects
- **Native macOS**: Built with Swift and Apple's Vision framework—no Python dependencies

## Requirements

- macOS 14.0 (Sonoma) or later
- Mac with Apple Silicon or Intel processor
- Built-in or external webcam
- Xcode Command Line Tools (for building)

## Installation

### Download Release
Download the latest `ManoScroll.app` from the Releases page and drag it to your Applications folder.

### Build from Source
```bash
git clone <repository-url>
cd ManoScrollApp
./build.sh
open ManoScroll.app
```

## Permissions

ManoScroll requires two system permissions:

### Camera Access
Required for hand tracking. You'll be prompted automatically when starting tracking, or grant access in:
**System Settings → Privacy & Security → Camera**

### Accessibility Access
Required to inject scroll events into other applications. Grant access in:
**System Settings → Privacy & Security → Accessibility**

Add ManoScroll to the list of allowed apps. You may need to restart the app after granting permission.

## Usage

1. **Launch ManoScroll** — The app appears in your menu bar and/or dock
2. **Click "Start Tracking"** from the menu bar icon or dock menu
3. **Position your hand** in front of the camera
4. **Gesture to scroll**:
   - **Open palm** (4-5 fingers extended): Scroll up
   - **Closed fist** (0-1 fingers extended): Scroll down
   - **Neutral position**: No scrolling
5. **Click "Stop Tracking"** when done

## Settings

Access settings from the menu bar icon → Settings, or use `⌘,` when the app is focused.

### Scroll Control
| Setting | Description | Default |
|---------|-------------|---------|
| Scroll Speed | Multiplier for scroll velocity | 3.0 |
| Smoothing Factor | Lower = smoother, higher = more responsive | 0.3 |
| Scroll Threshold | Minimum gesture intensity to trigger scroll | 0.3 |
| Decay Rate | How quickly scrolling stops when hand is removed | 0.8 |
| Dead Zone | Neutral zone in center where no scroll occurs | 0.0 |
| Scroll Mode | Pixel (smooth) or Line (stepped) scrolling | Pixel |
| Invert Direction | Reverse scroll direction | Off |
| Acceleration | Enable faster scrolling for larger gestures | Off |

### Hand Detection
| Setting | Description | Default |
|---------|-------------|---------|
| Detection Confidence | Higher = more accurate, may miss gestures | 50% |
| Open Palm Threshold | Fingers needed for "open palm" gesture | 4 |
| Fist Threshold | Max fingers for "fist" gesture | 1 |
| Left Hand Mode | Optimize detection for left-handed users | Off |

### Display & Appearance
| Setting | Description | Default |
|---------|-------------|---------|
| Show Camera Preview | Display live camera feed window | On |
| Show in Dock | Show app icon in dock | On |
| Show in Menu Bar | Show app icon in menu bar | On |

## Troubleshooting

### Scrolling doesn't work
1. Ensure Accessibility permission is granted in System Settings
2. Restart ManoScroll after granting permissions
3. Try increasing Scroll Speed or decreasing Scroll Threshold

### Hand not detected
1. Ensure good lighting on your hand
2. Position hand clearly in camera view
3. Try lowering Detection Confidence
4. Enable camera preview to see what's being detected

### App crashes when stopping
This was fixed in v1.0. If you experience crashes, ensure you have the latest version.

---

# Developer Guide

## Project Structure

```
ManoScrollApp/
├── Package.swift              # Swift Package Manager manifest
├── build.sh                   # Build script for creating app bundle
├── ManoScrollApp/
│   ├── ManoScrollApp.swift    # App entry point, AppDelegate, menu bar
│   ├── HandTracker.swift      # Core hand tracking and scroll logic
│   ├── SettingsView.swift     # SwiftUI settings UI and AppSettings
│   ├── Info.plist             # App metadata
│   └── ManoScrollApp.entitlements
└── Tests/
    └── ManoScrollAppTests/
        └── HandTrackerTests.swift  # Unit tests
```

## Architecture

### HandTracker
The core class that:
- Manages `AVCaptureSession` for camera input
- Uses `VNDetectHumanHandPoseRequest` for hand detection
- Processes hand pose observations to detect gestures
- Posts `CGEvent` scroll events to the system

Key protocols for testability:
- `AccessibilityChecker` — Abstracts `AXIsProcessTrusted()`
- `ScrollEventPoster` — Abstracts `CGEvent` posting

### AppSettings
Singleton `ObservableObject` that:
- Persists all settings via `UserDefaults`
- Publishes changes for SwiftUI bindings
- Manages app presentation (dock/menu bar visibility)

### AppDelegate
- Creates and manages the menu bar status item
- Handles Start/Stop Tracking actions
- Opens Settings window

## Building

### Prerequisites
```bash
# Install Xcode Command Line Tools
xcode-select --install
```

### Build Commands
```bash
# Build release app bundle
./build.sh

# Build for debugging
swift build

# Run tests
swift test

# Clean build artifacts
swift package clean
rm -rf ManoScroll.app
```

### Build Script Details
The `build.sh` script:
1. Runs `swift build -c release`
2. Creates `ManoScroll.app` bundle structure
3. Copies the executable and Info.plist
4. Signs the app with ad-hoc signature

## Testing

```bash
swift test
```

### Test Coverage
- **Accessibility permission behavior**: Ensures scroll is blocked without permission
- **Scroll event posting**: Verifies correct scroll amounts are posted
- **Stop tracking safety**: Prevents crash regressions when stopping

### Adding Tests
Tests use mock implementations of `AccessibilityChecker` and `ScrollEventPoster` to avoid needing actual system permissions during testing.

## Code Style

- Swift 5.9+
- SwiftUI for UI components
- Combine for reactive updates
- No external dependencies—uses only Apple frameworks

## Key Frameworks

| Framework | Usage |
|-----------|-------|
| Vision | Hand pose detection |
| AVFoundation | Camera capture |
| CoreGraphics | Scroll event injection |
| SwiftUI | Settings UI |
| AppKit | Menu bar, window management |

## Contributing

1. Fork the repository
2. Create a feature branch
3. Ensure tests pass: `swift test`
4. Submit a pull request

## License

[Add your license here]
