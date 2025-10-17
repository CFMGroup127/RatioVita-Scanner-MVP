# RatioVita_v2

Cross-platform SwiftUI app for receipt scanning and OCR.

## Features
- **Platforms**: iOS and macOS
- **Architecture**: SwiftUI + SwiftData, protocol-based services
- **Scanning**: AVFoundation + Vision (iOS), with a PreviewScannerService for macOS/testing
- **Models**: Rich ScanResult with extracted data and processing metadata
- **Image handling**: Cross-platform RVImage bridge via Utilities/ImageBridge.swift

## Build

1. Open `RatioVita.xcodeproj` in Xcode (latest recommended).
2. Product → Clean Build Folder (Shift + Cmd + K).
3. Select target and build:
   - **iOS target**: includes camera capture (guarded with `#if os(iOS)`).
   - **macOS target**: builds without camera code.

## Notes

- **iOS-only files** are wrapped with `#if os(iOS)`:
  - `Views/Scanner/CameraCaptureView.swift`
  - `Views/Scanner/ScannerCoordinator.swift`
  - `Services/RealScannerService.swift`

- **Preview and sample data** are platform-safe:
  - `Services/PreviewScannerService.swift`
  - `Utilities/SampleData.swift`

- **Rich ScanResult model** in `Models/ScanResult.swift`.

## Tests

- Minimal Swift Testing in `Tests/ReceiptImageTests.swift` to verify JPEG encode/decode.

## Known Issues

- `RealScannerService` currently returns placeholder results until the full AVFoundation + Vision pipeline is wired into the app.
- If you see intermittent lstat errors:
  - Delete `~/Library/Developer/Xcode/DerivedData/RatioVita_v2`
  - Product → Clean Build Folder

## Repository

- **Remote**: https://github.com/CFMGroup127/RatioVita_v2-for-26
- **Default branch**: main
