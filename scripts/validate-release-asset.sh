#!/bin/zsh
set -euo pipefail

if [[ $# -ne 4 ]]; then
    echo "Usage: $0 <zip> <arm64|x86_64> <version> <build>" >&2
    exit 64
fi

ZIP="$1"
ARCH="$2"
EXPECTED_VERSION="$3"
EXPECTED_BUILD="$4"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

case "$ARCH" in
    arm64|x86_64) ;;
    *) echo "Unsupported architecture: $ARCH" >&2; exit 64 ;;
esac

ditto -x -k "$ZIP" "$TMP"
APP=$(find "$TMP" -maxdepth 2 -type d -name '*.app' -print -quit)
if [[ -z "$APP" ]]; then
    echo "No application bundle found in $ZIP" >&2
    exit 1
fi

INFO="$APP/Contents/Info.plist"
BINARY="$APP/Contents/MacOS/TrafficLightsPlus"

[[ "$(plutil -extract CFBundleShortVersionString raw "$INFO")" == "$EXPECTED_VERSION" ]]
[[ "$(plutil -extract CFBundleVersion raw "$INFO")" == "$EXPECTED_BUILD" ]]
[[ "$(plutil -extract LSMinimumSystemVersion raw "$INFO")" == "14.0" ]]
lipo "$BINARY" -verify_arch "$ARCH"
codesign --verify --deep --strict "$APP"

echo "Validated $ZIP ($ARCH, $EXPECTED_VERSION build $EXPECTED_BUILD)"
