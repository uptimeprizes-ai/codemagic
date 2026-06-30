# UpTime Prizes — iOS

The iOS version of UpTime Prizes, a morning alarm app built around original music you cannot hear anywhere else.

## Build Requirements

- Xcode 15.4+
- iOS 17.0+ deployment target
- XcodeGen (installed via `brew install xcodegen`)

## Setup

```bash
# Generate the Xcode project from project.yml
xcodegen generate

# Open in Xcode
open UpTimePrizes.xcodeproj
```

## CI/CD

This project uses Codemagic for automated builds. The configuration is in `codemagic.yaml`.

## Architecture

- **SwiftUI** for all UI
- **SwiftData** for local persistence
- **StoreKit 2** for in-app purchases
- **AVFoundation** for audio playback
- **UNUserNotificationCenter** for alarm notifications

## Project Structure

```
UpTimePrizes/
├── App/                    # App entry point and root navigation
├── Data/                   # SwiftData models and database seeder
├── Domain/                 # Business logic (alarm engine, stage coordinator)
├── Platform/               # Platform services (audio, billing, notifications)
├── Presentation/           # SwiftUI views organized by feature
│   ├── DesignSystem/       # Colors, typography, shared components
│   ├── Welcome/            # Onboarding flow
│   ├── Home/               # Tab navigation
│   ├── Player/             # Music library and playback
│   ├── Discover/           # Journey purchase cards
│   ├── Settings/           # App settings and journey info
│   └── Debug/              # Debug tools (DEBUG builds only)
└── Resources/              # Assets, fonts, audio files, manifest
```
