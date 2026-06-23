# Video Transcribe (macOS) `v1.1`

A premium, native macOS app built with SwiftUI that transcribes videos locally on your Mac using AI. Powered by `whisper.cpp` and `FFmpeg`.

## Features
- **100% Local & Private:** No cloud APIs. All processing stays on your machine.
- **Universal Binary:** Natively supports both modern Apple Silicon (M1/M2/M3/M4) and legacy Intel (x86_64) Macs.
- **Self-Contained Distribution:** Whisper, FFmpeg, yt-dlp, and AI models are bundled directly within the app. No manual setup required for end users.
- **Native macOS Experience:** Fully adheres to Apple's Human Interface Guidelines (HIG) with a minimalist sidebar, native Settings window, and unified toolbar.
- **Reader Mode:** Pop-out transcripts into a dedicated window for a distraction-free reading experience.
- **Premium Aesthetics:** Clean SwiftUI interface with professional iconography and squircle-masked app icons.
- **Smart Formatting:** Export transcripts as Microsoft Word (.doc), Subtitles (.srt), JSON, or Plain Text.

## Requirements
- macOS 14.0 or later (Optimized for macOS 15 Sequoia)
- Apple Silicon or Intel Mac

## Installation & Distribution

We provide a fully automated script that compiles the Swift code into a Universal Binary, fetches external dependencies (like FFmpeg and yt-dlp), injects the `whisper.cpp` binaries, and packages everything into a distributable DMG.

1. Clone the repository.
2. Ensure you have `ffmpeg` and `whisper-cli` installed via Homebrew for the initial packaging process:
   ```bash
   brew install ffmpeg whisper-cpp
   ```
3. Run the automated build script:
   ```bash
   ./build_app.sh
   ```
4. The script will generate a fully standalone `Video Transcribe.app` and wrap it into a `Video Transcribe.dmg` ready for distribution.

> **Note on Intel Compatibility:** While the Swift app is a Universal Binary, the packaged `whisper-cli` will be linked to the architecture of the machine running `build_app.sh`. To distribute to Intel Macs, either run the script on an Intel Mac, or manually bundle universal binaries of `whisper.cpp`.

## Architecture
- **SwiftUI (`@Observable`):** Modern reactive state management using `AppState`.
- **macOS Scenes:** Uses native `.WindowGroup` and `.Settings` scenes for proper multi-window management.
- **`WhisperService`:** Manages local AI inference with real-time regex-based progress parsing.
- **`FFmpegService`:** Handles high-performance audio extraction and duration detection.

## License
MIT
