# Contributing to RatioVita_v2

Thank you for your interest in contributing!

## Getting Started
- Open `RatioVita.xcodeproj` with the latest Xcode.
- Build targets:
  - **iOS target** includes camera capture (guarded by `#if os(iOS)`).
  - **macOS target** builds without camera code.
- Clean builds: Product → Clean Build Folder (Shift + Cmd + K).

## Branching & Commits
- Create feature branches: `feature/<short-description>`
- Use descriptive commit messages.
- Keep pull requests focused and small.

## Code Style
- Prefer Swift Concurrency (`async`/`await`) over GCD where practical.
- Keep platform conditionals (`#if os(iOS)`) for UIKit/AVFoundation code.
- Use `Utilities/ImageBridge.swift` for cross-platform images (`RVImage`).

## Tests
- Add Swift Testing tests in `Tests/`.
- Keep tests fast and deterministic.

## Pull Requests
- Rebase on `main` before opening a PR.
- Ensure the project builds for both iOS and macOS.
- CI must pass.

## Reporting Issues
- Include steps to reproduce, expected vs actual, and environment details.
