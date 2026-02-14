#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# install.command — build ConvoCraft and install into ~/Applications
# - builds release with SwiftPM
# - creates a minimal .app bundle using the repository's Info.plist
# - moves the resulting ConvoCraft.app into ~/Applications

EXE_NAME="ConvoCraft"
BUILD_CONFIG="release"
BUILD_DIR=".build/${BUILD_CONFIG}"
BIN_PATH="$BUILD_DIR/$EXE_NAME"
PLIST_SRC="Info.plist"
APP_BUNDLE="${EXE_NAME}.app"
APP_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$APP_DIR/MacOS"
DEST_DIR="$HOME/Applications"
DEST_PATH="$DEST_DIR/$APP_BUNDLE"

echo "== ConvoCraft installer =="

# Platform check
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Error: This script must be run on macOS." >&2
  exit 1
fi

# Tooling check
if ! command -v swift >/dev/null 2>&1; then
  echo "Error: 'swift' not found in PATH. Install Xcode or the Swift toolchain." >&2
  exit 1
fi

# Build
echo "Building ${EXE_NAME} (${BUILD_CONFIG})..."
swift build -c "${BUILD_CONFIG}"

if [[ ! -f "${BIN_PATH}" ]]; then
  echo "Build failed: binary not found at ${BIN_PATH}" >&2
  exit 1
fi

# Create app bundle
echo "Creating app bundle: ${APP_BUNDLE}"
rm -rf "${APP_BUNDLE}"
mkdir -p "${MACOS_DIR}"
cp "${BIN_PATH}" "${MACOS_DIR}/${EXE_NAME}"
chmod +x "${MACOS_DIR}/${EXE_NAME}"

# Copy Info.plist if present and ensure CFBundleExecutable is set
if [[ -f "${PLIST_SRC}" ]]; then
  cp "${PLIST_SRC}" "${APP_DIR}/Info.plist"
  # Ensure CFBundleExecutable exists and matches the binary name
  /usr/libexec/plutil -replace CFBundleExecutable -string "${EXE_NAME}" "${APP_DIR}/Info.plist" >/dev/null 2>&1 || true
else
  cat > "${APP_DIR}/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>
  <string>${EXE_NAME}</string>
  <key>CFBundleExecutable</key>
  <string>${EXE_NAME}</string>
  <key>CFBundleIdentifier</key>
  <string>com.convocraft.app</string>
  <key>CFBundleVersion</key>
  <string>1.0</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
</dict>
</plist>
PLIST
fi

# Move to ~/Applications
mkdir -p "${DEST_DIR}"
if [[ -d "${DEST_PATH}" ]]; then
  read -r -p "${DEST_PATH} already exists — replace? [y/N]: " answer
  case "${answer}" in
    [Yy]*) rm -rf "${DEST_PATH}" ;;
    *) echo "Install cancelled."; exit 0 ;;
  esac
fi

mv "${APP_BUNDLE}" "${DEST_PATH}"

echo "Installed: ${DEST_PATH}"

# Reveal in Finder
if command -v open >/dev/null 2>&1; then
  open -R "${DEST_PATH}" || true
fi

echo "Done — you can launch ConvoCraft from Finder or: open \"${DEST_PATH}\""
exit 0
