#!/bin/bash

# Exit on error
set -e

echo "🔨 Building Video Transcribe App..."

# Build the executable using Swift Package Manager
swift build -c release --disable-sandbox

# Find the executable path
EXECUTABLE_PATH=$(swift build -c release --disable-sandbox --show-bin-path)/VideoTranscribe

# Create the App bundle structure
APP_NAME="Video Transcribe"
APP_BUNDLE="${APP_NAME}.app"
APP_EXECUTABLE_DIR="${APP_BUNDLE}/Contents/MacOS"
APP_RESOURCES_DIR="${APP_BUNDLE}/Contents/Resources"

echo "📦 Creating App Bundle at ${APP_BUNDLE}..."

# Remove old bundle if exists
rm -rf "${APP_BUNDLE}"

# Create directories
mkdir -p "${APP_EXECUTABLE_DIR}"
mkdir -p "${APP_RESOURCES_DIR}"

# Create directories for dependencies
APP_BIN_DIR="${APP_RESOURCES_DIR}/bin"
APP_LIB_DIR="${APP_RESOURCES_DIR}/lib"
APP_MODELS_DIR="${APP_RESOURCES_DIR}/models"
mkdir -p "${APP_BIN_DIR}"
mkdir -p "${APP_LIB_DIR}"
mkdir -p "${APP_MODELS_DIR}"

# Download and package static dependencies
echo "📦 Fetching static dependencies..."

# 1. yt-dlp
echo "   ⬇️ Downloading yt-dlp..."
curl -L -s https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos -o "${APP_BIN_DIR}/yt-dlp"
chmod +x "${APP_BIN_DIR}/yt-dlp"

# 2. FFmpeg (static build from evermeet.cx)
echo "   ⬇️ Downloading FFmpeg static..."
curl -L -s https://evermeet.cx/ffmpeg/getrelease/zip -o /tmp/ffmpeg.zip
unzip -q -o /tmp/ffmpeg.zip -d /tmp/
cp /tmp/ffmpeg "${APP_BIN_DIR}/ffmpeg"
chmod +x "${APP_BIN_DIR}/ffmpeg"

# 3. Whisper-cli and its dynamic libraries
WHISPER_SRC=$(which whisper-cli || which whisper-cpp || which main || echo "")
if [ -n "$WHISPER_SRC" ]; then
    echo "🤖 Bundling Whisper and fixing library paths..."
    cp "$WHISPER_SRC" "${APP_BIN_DIR}/whisper-cli"
    
    # Copy required libraries (detected from otool)
    echo "📚 Bundling Whisper libraries..."
    cp /opt/homebrew/lib/libwhisper.*.dylib "${APP_LIB_DIR}/" 2>/dev/null || true
    cp /opt/homebrew/opt/ggml/lib/libggml*.dylib "${APP_LIB_DIR}/" 2>/dev/null || true
    cp /usr/local/lib/libwhisper.*.dylib "${APP_LIB_DIR}/" 2>/dev/null || true
    
    # Change rpath logic so whisper-cli looks inside the app bundle
    install_name_tool -change @rpath/libwhisper.1.dylib @executable_path/../lib/libwhisper.1.dylib "${APP_BIN_DIR}/whisper-cli" 2>/dev/null || true
    install_name_tool -change /opt/homebrew/opt/ggml/lib/libggml.0.dylib @executable_path/../lib/libggml.0.dylib "${APP_BIN_DIR}/whisper-cli" 2>/dev/null || true
    install_name_tool -change /opt/homebrew/opt/ggml/lib/libggml-base.0.dylib @executable_path/../lib/libggml-base.0.dylib "${APP_BIN_DIR}/whisper-cli" 2>/dev/null || true
    
    # Update libraries to point to bundled libggml files
    for lib in "${APP_LIB_DIR}/"*.dylib; do
        install_name_tool -change /opt/homebrew/opt/ggml/lib/libggml.0.dylib @loader_path/libggml.0.dylib "$lib" 2>/dev/null || true
        install_name_tool -change /opt/homebrew/opt/ggml/lib/libggml-base.0.dylib @loader_path/libggml-base.0.dylib "$lib" 2>/dev/null || true
        install_name_tool -change /opt/homebrew/opt/whisper-cpp/lib/libwhisper.1.dylib @loader_path/libwhisper.1.dylib "$lib" 2>/dev/null || true
    done
fi

# Copy models
echo "🧠 Bundling AI Models..."
# Copy models from App Support (where app downloads them)
cp "$HOME/Library/Application Support/VideoTranscribe/Models/"*.bin "${APP_MODELS_DIR}/" 2>/dev/null || true
# Copy from common Homebrew paths
cp /opt/homebrew/share/whisper/models/*.bin "${APP_MODELS_DIR}/" 2>/dev/null || true
cp /usr/local/share/whisper/models/*.bin "${APP_MODELS_DIR}/" 2>/dev/null || true

# Copy executable
cp "${EXECUTABLE_PATH}" "${APP_EXECUTABLE_DIR}/${APP_NAME}"

# Copy Icon if exists
if [ -f "AppIcon.icns" ]; then
    echo "🎨 Adding App Icon..."
    cp "AppIcon.icns" "${APP_RESOURCES_DIR}/"
    ICON_LINE="<key>CFBundleIconFile</key><string>AppIcon</string>"
else
    ICON_LINE=""
fi

# Create Info.plist
cat > "${APP_BUNDLE}/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>com.harshmishra.videotranscribe</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.1</string>
    <key>CFBundleVersion</key>
    <string>2</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    ${ICON_LINE}
</dict>
</plist>
EOF

echo "✅ App built successfully! You can find it at: ./${APP_BUNDLE}"
echo "🚀 You can now double-click '${APP_BUNDLE}' to open the app, or move it to your Applications folder."
