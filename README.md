# Video Transcribe (macOS) `v0.11 alpha`

A premium, native macOS app built with SwiftUI that transcribes videos locally on your Mac using AI. Powered by `whisper.cpp` and `FFmpeg`.

## Features
- **100% Local & Private:** No cloud APIs. All processing stays on your machine.
- **Self-Contained (NEW):** Whisper, FFmpeg, and AI models are now bundled directly within the app. No manual setup required.
- **Reader Mode:** Pop-out transcripts into a dedicated window for a distraction-free reading experience.
- **Premium Aesthetics:** Clean SwiftUI interface with a persistent status bar, professional iconography, and glassmorphic design.
- **Native AI Acceleration:** Optimized for Apple Silicon (M1-M4) using Metal/CoreML.
- **Smart Formatting:** Export transcripts as Microsoft Word (.doc), Subtitles (.srt), JSON, or Plain Text.
- **Integrated Search:** Quickly find keywords within your transcripts using the built-in search functionality.

## Requirements
- macOS 14.0 or later (Optimized for macOS 15 Sequoia)
- Apple Silicon (M1, M2, M3, M4) recommended

## Installation

### 🚀 Zero-Setup Build
The app now automatically bundles its own dependencies during the build process. To create the standalone `.app` bundle:

1.  Clone the repository.
2.  Ensure you have `ffmpeg` and `whisper-cli` installed on your system *once* (the build script will grab them from your system and bundle them into the app for portability).
3.  Run the build script:
    ```bash
    ./build_app.sh
    ```
4.  Double-click **Video Transcribe.app** in the project root.

## What's New in v0.11 Alpha
- **Persistent Status Bar:** Real-time health monitoring of AI engines and transcription progress.
- **Action Bar:** Prominent "Copy to Clipboard" and "Save as Word" buttons with icons and text.
- **Reader Mode Window:** Separate window support for viewing transcripts with serif typography and integrated search.
- **Bundled Dependencies:** Fixed dynamic library linking issues (exit code 6) by embedding `.dylib` files directly into the bundle.
- **Clean UI:** Removed unnecessary timestamps for a more readable, document-like experience.

## Architecture
- **SwiftUI (`@Observable`):** Modern reactive state management.
- **`WhisperService`:** Manages local AI inference with real-time regex-based progress parsing.
- **`FFmpegService`:** Handles high-performance audio extraction and duration detection.
- **Bundled Resources:** Binaries and libraries are located in `Contents/Resources/bin` and `lib`.

## License
MIT
