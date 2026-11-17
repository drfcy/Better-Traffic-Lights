#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
VERSION=$(plutil -extract CFBundleShortVersionString raw "$ROOT/Info.plist")
BUILD=$(plutil -extract CFBundleVersion raw "$ROOT/Info.plist")
ARCHES=(${=PACKAGE_ARCHES:-arm64 x86_64})
STAGE=$(mktemp -d "${TMPDIR:-/private/tmp}/btl-updates.XXXXXX")
trap 'rm -rf "$STAGE"' EXIT

for ARCH in "$ARCHES[@]"; do
    APP="$STAGE/$ARCH/Better Traffic Lights.app"
    TARGET_ARCH="$ARCH" APP_OUTPUT="$APP" "$ROOT/scripts/build-app.sh"
    TOOL_DIR="$ROOT/.build/$ARCH/artifacts/sparkle/Sparkle/bin"
    ARCHIVES="$STAGE/archives-$ARCH"
    mkdir -p "$ARCHIVES" "$ROOT/build"
    ZIP="$ARCHIVES/Better-Traffic-Lights-$VERSION-$ARCH.zip"
    ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
    "$ROOT/scripts/validate-release-asset.sh" "$ZIP" "$ARCH" "$VERSION" "$BUILD"

    KEY_ARGS=(--account app.trafficlightsplus.mac)
    if [[ -n "${SPARKLE_ED_KEY_FILE:-}" ]]; then
        KEY_ARGS=(--ed-key-file "$SPARKLE_ED_KEY_FILE")
    fi
    FEED="$ARCHIVES/appcast-$ARCH.xml"
    "$TOOL_DIR/generate_appcast" "${KEY_ARGS[@]}" \
        --maximum-deltas 0 --maximum-versions 1 \
        --download-url-prefix "https://github.com/drfcy/Better-Traffic-Lights/releases/download/v$VERSION/" \
        --link "https://github.com/drfcy/Better-Traffic-Lights/releases/tag/v$VERSION" \
        -o "$FEED" "$ARCHIVES"
    "$TOOL_DIR/sign_update" "${KEY_ARGS[@]}" --verify "$FEED"
    cp "$ZIP" "$FEED" "$ROOT/build/"
done

echo "Upload every ZIP and appcast XML from build/ to the same GitHub Release before making it the latest release."
