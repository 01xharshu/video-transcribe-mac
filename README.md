# Video Transcribe (macOS)

A clean, native macOS app built with SwiftUI that transcribed videos locally on your Mac using `ffmpeg` and `whisper.cpp`.

## Features
- **100% Local & Private:** No cloud APIs. Maximum privacy.
- **Metal Accelerated:** Uses whisper.cpp with CoreML/Metal support for fast processing on Apple Silicon (M1-M5).
- **Native UI:** Clean SwiftUI interface with Dark Mode support and drop zones.
- **Format Support:** Drag and drop MP4, MOV, MKV, WebM, and more.
- **Timestamps:** Optional segment-level timestamps.
- **Exporting:** Copy to clipboard, export as Plain Text (.txt), Subtitles (.srt), or JSON (.json).

## Requirements
- macOS 14.0 or later (Optimized for macOS 15 Sequoia)
- Apple Silicon recommended for performance

## Installation

### Dependencies
The app requires `ffmpeg` to extract audio and `whisper.cpp` to run the transcription models. The app provides a setup guide on first run, but you can install them via Homebrew:

```bash
brew install ffmpeg
brew install whisper-cpp

# Download a high-quality transcription model
whisper-cpp-download-ggml-model large-v3-turbo
```

### Building the App
You can build the native macOS `.app` bundle using the included build script:

```bash
./build_app.sh
```

Alternatively, you can open the project directly in Xcode:
1. Open the `Package.swift` file in Xcode (`open Package.swift`)
2. Select the "VideoTranscribe" executable target.
3. Click Run (Cmd+R).

## Architecture
- **SwiftUI (`@Observable`):** Modern state management and reactive UI.
- **`FFmpegService`:** Extracts 16kHz mono audio tracks asynchronously via CLI.
- **`WhisperService`:** Executes the `whisper-cpp` binary locally, capturing stdout/stderr for real-time progress and JSON parsing.
- **`AppState`:** Orchestrates jobs, parsing queues, estimating transcription time, and managing dependencies.

## License
MIT
