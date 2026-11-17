#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
TARGET_ARCH="${TARGET_ARCH:-$(uname -m)}"
APP="${APP_OUTPUT:-$ROOT/build/Better Traffic Lights.app}"
ICONSET="$ROOT/.build/AppIcon.iconset"
ICON="$ROOT/Resources/AppIcon.icns"
SIGNING_IDENTITY="${SIGNING_IDENTITY:--}"

case "$TARGET_ARCH" in
    arm64|x86_64) ;;
    *)
        echo "Unsupported TARGET_ARCH: $TARGET_ARCH (expected arm64 or x86_64)" >&2
        exit 1
        ;;
esac

TRIPLE="$TARGET_ARCH-apple-macosx14.0"
SCRATCH="$ROOT/.build/$TARGET_ARCH"
APP_BINARY="$SCRATCH/release/TrafficLightsPlus"
RESOURCE_BUNDLE="$SCRATCH/release/TrafficLightsPlus_TrafficLightsPlus.bundle"
SPARKLE_FRAMEWORK="$SCRATCH/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
AD_HOC_ENTITLEMENTS="$ROOT/Resources/TrafficLightsPlus.ad-hoc.entitlements"

cd "$ROOT"
export CLANG_MODULE_CACHE_PATH="$ROOT/.build/ModuleCache"
export SWIFTPM_MODULECACHE_OVERRIDE="$ROOT/.build/ModuleCache"
swift build -c release \
    --disable-keychain --disable-netrc \
    --triple "$TRIPLE" \
    --scratch-path "$SCRATCH" \
    --disable-automatic-resolution \
    --disable-sandbox \
    --cache-path "$ROOT/.build/SwiftPMCache"

lipo "$APP_BINARY" -verify_arch "$TARGET_ARCH"
if [[ ! -d "$RESOURCE_BUNDLE" ]]; then
    echo "Missing localization resource bundle: $RESOURCE_BUNDLE" >&2
    exit 1
fi
if [[ ! -d "$SPARKLE_FRAMEWORK" ]]; then
    echo "Missing Sparkle framework: $SPARKLE_FRAMEWORK" >&2
    exit 1
fi
rm -rf "$ICONSET"
mkdir -p "$ICONSET" "$ROOT/Resources"
swift "$ROOT/scripts/generate-icon.swift" "$ICONSET" "$ICON"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"
cp "$APP_BINARY" "$APP/Contents/MacOS/TrafficLightsPlus"
cp "$ROOT/Info.plist" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :SUFeedURL https://github.com/drfcy/Better-Traffic-Lights/releases/latest/download/appcast-$TARGET_ARCH.xml" "$APP/Contents/Info.plist"
cp "$ICON" "$APP/Contents/Resources/AppIcon.icns"
ditto --norsrc "$RESOURCE_BUNDLE" "$APP/Contents/Resources/TrafficLightsPlus_TrafficLightsPlus.bundle"
ditto --norsrc "$SPARKLE_FRAMEWORK" "$APP/Contents/Frameworks/Sparkle.framework"
cp "$SCRATCH/artifacts/sparkle/Sparkle/LICENSE" "$APP/Contents/Resources/Sparkle-LICENSE"
cp -R "$ROOT/Sources/TrafficLightsPlus/Resources/zh-Hans.lproj" "$APP/Contents/Resources/"
cp -R "$ROOT/Sources/TrafficLightsPlus/Resources/en.lproj" "$APP/Contents/Resources/"
xattr -cr "$APP"
for target in "$APP" "$APP/Contents/Resources/TrafficLightsPlus_TrafficLightsPlus.bundle"; do
    xattr -d com.apple.FinderInfo "$target" 2>/dev/null || true
    xattr -d 'com.apple.fileprovider.fpfs#P' "$target" 2>/dev/null || true
done
# Sign nested helpers before the framework and app. Preserve the Downloader's
# sandbox entitlements, as required by Sparkle's manual distribution workflow.
SPARKLE="$APP/Contents/Frameworks/Sparkle.framework"
TIMESTAMP_FLAG="--timestamp"
[[ "$SIGNING_IDENTITY" == "-" ]] && TIMESTAMP_FLAG="--timestamp=none"
codesign --force --options runtime "$TIMESTAMP_FLAG" --sign "$SIGNING_IDENTITY" \
    "$SPARKLE/Versions/B/XPCServices/Installer.xpc"
codesign --force --options runtime "$TIMESTAMP_FLAG" --preserve-metadata=entitlements --sign "$SIGNING_IDENTITY" \
    "$SPARKLE/Versions/B/XPCServices/Downloader.xpc"
for target in "$SPARKLE/Versions/B/Autoupdate" "$SPARKLE/Versions/B/Updater.app" "$SPARKLE"; do
    codesign --force --options runtime "$TIMESTAMP_FLAG" --sign "$SIGNING_IDENTITY" "$target"
done
if [[ "$SIGNING_IDENTITY" == "-" ]]; then
    codesign --force --options runtime --timestamp=none \
        --entitlements "$AD_HOC_ENTITLEMENTS" --sign - \
        --requirements '=designated => identifier "app.trafficlightsplus.mac"' \
        "$APP"
else
    codesign --force --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$APP"
fi

lipo "$APP/Contents/MacOS/TrafficLightsPlus" -verify_arch "$TARGET_ARCH"
codesign --verify --deep --strict "$APP"

echo "$APP"
