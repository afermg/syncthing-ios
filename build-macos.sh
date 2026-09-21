#!/bin/bash
# Build an iOS executable, NOT a macOS/darwin executable.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")" && pwd)
VERSION=v2.1.5
COMMIT=2ca95cf1498104113fdfde46df4107f2450a0f71
PACKAGE_VERSION=2.1.5-1

fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ $(uname -s) == Darwin ]] || fail 'Run this on a Mac with Apple compiler tools and an iOS SDK.'
for tool in git go xcrun codesign ldid dpkg-deb python3; do
    command -v "$tool" >/dev/null || fail "Missing $tool. See README.md."
done
# Keep host-side Go generators runnable, even if the caller exports cross flags.
unset SDKROOT GOOS GOARCH CC CXX CGO_CFLAGS CGO_CPPFLAGS CGO_CXXFLAGS CGO_LDFLAGS GOFLAGS
export IOS_SDK IOS_CC
if [[ -z ${IOS_SDK:-} ]]; then
    IOS_SDK=$(xcrun --sdk iphoneos --show-sdk-path) || fail 'iOS SDK missing. Install Xcode or use ./build-no-account.sh.'
fi
[[ -f "$IOS_SDK/SDKSettings.plist" ]] || fail 'Invalid iPhoneOS SDK path.'
IOS_SDK=$(cd "$IOS_SDK" && pwd)
IOS_CC=${IOS_CC:-$(xcrun --find clang)}
[[ -x "$IOS_CC" ]] || fail 'Apple clang not found. Install the Command Line Tools.'
export GOTOOLCHAIN=go1.26.2
export CGO_ENABLED=1
mkdir -p "$ROOT/build" "$ROOT/dist"
WORK=$(mktemp -d "$ROOT/build/run.XXXXXX")
SRC="$WORK/source"
STAGE="$WORK/package"
BIN="$STAGE/var/jb/usr/bin/syncthing-ios"
DOC="$STAGE/var/jb/usr/share/doc/syncthing-ios"
OUT="$ROOT/dist/local.syncthing.ios_${PACKAGE_VERSION}_iphoneos-arm64.deb"
printf 'Build workspace: %s\n' "$WORK"

git clone --depth 1 --branch "$VERSION" https://github.com/syncthing/syncthing.git "$SRC"
[[ $(git -C "$SRC" rev-parse HEAD) == "$COMMIT" ]] || fail 'Upstream tag does not match the pinned commit.'
mkdir -p "$(dirname "$BIN")" "$DOC" "$STAGE/DEBIAN" "$STAGE/var/jb/Library/LaunchDaemons"
(
    cd "$SRC"
    go mod download
    go mod verify
    # Generate the web UI using HOST tools before switching to GOOS=ios.
    export SOURCE_DATE_EPOCH
    SOURCE_DATE_EPOCH=$(git show -s --format=%ct HEAD)
    go generate ./lib/api/auto
    test -s lib/api/auto/gui.files.go
    GOOS=ios GOARCH=arm64 CC="\"$ROOT/ios-clang.sh\"" \
        CGO_LDFLAGS='-framework CoreFoundation -framework Security' \
        go build -trimpath -tags 'stnoupgrade,timetzdata' \
        -ldflags "-s -w -linkmode external -X github.com/syncthing/syncthing/lib/build.Version=$VERSION -X github.com/syncthing/syncthing/lib/build.Stamp=$SOURCE_DATE_EPOCH -X github.com/syncthing/syncthing/lib/build.User=local -X github.com/syncthing/syncthing/lib/build.Host=macos" \
        -o "$BIN" ./cmd/syncthing
)

# A real ad-hoc signature, not an Apple certificate: no account or keychain needed.
# Dopamine must still allow its entitlements and trust it on the device.
/usr/bin/codesign --force --sign - --identifier local.syncthing.ios \
    --entitlements "$ROOT/entitlements.plist" --generate-entitlement-der "$BIN"
/usr/bin/codesign --verify --strict --verbose=2 "$BIN"
python3 "$ROOT/verify_macho.py" "$BIN"
ldid -e "$BIN" > "$DOC/entitlements.plist"
/usr/bin/plutil -lint "$DOC/entitlements.plist"
xcrun otool -L "$BIN" | sed '1s|.*|syncthing-ios:|' > "$DOC/linked-libraries.txt"
cp "$ROOT/packaging/"* "$STAGE/DEBIAN/"
cp "$ROOT/local.syncthing.ios.plist" "$STAGE/var/jb/Library/LaunchDaemons/"
cp "$ROOT/README.md" "$SRC/LICENSE" "$SRC/AUTHORS" "$DOC/"
{
    printf 'Source: https://github.com/syncthing/syncthing\nTag: %s\nCommit: %s\n' "$VERSION" "$COMMIT"
    printf 'Target: ios/arm64; minimum iOS: 15.5\nSigning: Apple codesign ad-hoc, with XML and DER entitlements; no identity\n'
    go version
    printf 'Developer tools: %s\nSDK: %s\nCompiler: %s\n' "$(xcode-select -p)" "$(basename "$IOS_SDK")" "$(basename "$IOS_CC")"
    "$IOS_CC" --version
    python3 -c 'import plistlib, sys; print("SDK metadata:", plistlib.load(open(sys.argv[1], "rb"))["Version"])' "$IOS_SDK/SDKSettings.plist"
    if [[ -n ${IOS_SDK_SOURCE:-} ]]; then
        printf 'SDK source: %s\n' "$IOS_SDK_SOURCE"
    fi
    if xcodebuild -version 2>/dev/null; then :; else
        printf 'Full Xcode: not selected (Command Line Tools / external SDK build)\n'
    fi
} > "$DOC/build-info.txt"
chmod 755 "$BIN" "$STAGE/DEBIAN/preinst" "$STAGE/DEBIAN/postinst" "$STAGE/DEBIAN/prerm"
chmod 644 "$STAGE/DEBIAN/control" "$STAGE/var/jb/Library/LaunchDaemons/local.syncthing.ios.plist"
/usr/bin/plutil -lint "$ROOT/local.syncthing.ios.plist"
# gzip works with older jailbreak dpkg versions; all archive owners are root.
dpkg-deb --root-owner-group -Zgzip --build "$STAGE" "$OUT"
dpkg-deb --info "$OUT"
dpkg-deb --contents "$OUT"
(cd "$ROOT/dist" && shasum -a 256 "$(basename "$OUT")" > "$(basename "$OUT").sha256")
printf '\nBuilt: %s\nNext: follow README.md for device installation and testing.\n' "$OUT"
