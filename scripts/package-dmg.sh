#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/Info.plist")
if [[ -n "${PACKAGE_ARCHES:-}" ]]; then
    ARCHES=(${=PACKAGE_ARCHES})
else
    ARCHES=(arm64 x86_64)
fi

for ARCH in "${ARCHES[@]}"; do
    APP="$ROOT/.build/package-$ARCH/Better Traffic Lights.app"
    STAGE="$(mktemp -d "${TMPDIR:-/private/tmp}/btl-dmg-root-$ARCH.XXXXXX")"
    DMG="$ROOT/build/Better-Traffic-Lights-$VERSION-$ARCH.dmg"

    mkdir -p "$ROOT/build"
    rm -f "$DMG"
    TARGET_ARCH="$ARCH" APP_OUTPUT="$APP" "$ROOT/scripts/build-app.sh"

    ditto "$APP" "$STAGE/Better Traffic Lights.app"
    xattr -cr "$STAGE/Better Traffic Lights.app"
    codesign --verify --deep --strict "$STAGE/Better Traffic Lights.app"
    ln -s /Applications "$STAGE/Applications"

    hdiutil create \
        -volname "Better Traffic Lights ($ARCH)" \
        -srcfolder "$STAGE" \
        -format UDZO \
        -ov \
        "$DMG"

    rm -rf "$STAGE"
    echo "$DMG"
done
