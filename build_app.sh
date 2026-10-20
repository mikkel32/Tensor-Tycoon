#!/bin/zsh
# Builds "Tensor Tycoon.app" into ./build (release configuration, ad-hoc signed).
set -euo pipefail
cd "$(dirname "$0")"

# UNIVERSAL=1 ./build_app.sh builds for both Apple silicon and Intel.
if [[ "${UNIVERSAL:-0}" == "1" ]]; then
    swift build -c release --arch arm64 --arch x86_64
    BIN=".build/apple/Products/Release/TensorTycoon"
else
    swift build -c release
    BIN=".build/release/TensorTycoon"
fi

# Version comes from the VERSION file; the build number counts commits so it always increases.
VERSION="$(tr -d '[:space:]' < VERSION 2>/dev/null || echo 0.0.0)"
BUILD="$(git rev-list --count HEAD 2>/dev/null || echo 1)"

APP="build/Tensor Tycoon.app"
rm -rf "${APP:?}"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/Images"
cp "$BIN" "$APP/Contents/MacOS/TensorTycoon"
cp Resources/Images/* "$APP/Contents/Resources/Images/"
cp Resources/CREDITS.txt "$APP/Contents/Resources/CREDITS.txt"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Tensor Tycoon</string>
    <key>CFBundleDisplayName</key><string>Tensor Tycoon</string>
    <key>CFBundleIdentifier</key><string>com.tensortycoon.game</string>
    <key>CFBundleVersion</key><string>${BUILD}</string>
    <key>CFBundleShortVersionString</key><string>${VERSION}</string>
    <key>CFBundleExecutable</key><string>TensorTycoon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>LSMinimumSystemVersion</key><string>26.0</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.simulation-games</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP" >/dev/null 2>&1 || true
echo "Built: $PWD/$APP (version $VERSION, build $BUILD)"
