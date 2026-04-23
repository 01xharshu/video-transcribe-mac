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

# Copy executable
cp "${EXECUTABLE_PATH}" "${APP_EXECUTABLE_DIR}/${APP_NAME}"

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
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

echo "✅ App built successfully! You can find it at: ./${APP_BUNDLE}"
echo "🚀 You can now double-click '${APP_BUNDLE}' to open the app, or move it to your Applications folder."
