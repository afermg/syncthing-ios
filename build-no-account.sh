#!/bin/bash
# Build on macOS using Command Line Tools and a pinned community iOS SDK.
# No Apple login, full Xcode, Theos scripts, or private-framework imports required.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")" && pwd)
SDK_REPO=https://github.com/theos/sdks.git
SDK_COMMIT=0222fd5413cf4b9af096f37b4621afa2688572f7
SDK_NAME=iPhoneOS15.6.sdk
SDK_CHECKOUT="$ROOT/build/theos-sdks"

fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ $(uname -s) == Darwin ]] || fail 'Run this on a Mac with Apple Command Line Tools.'
for tool in git go xcrun ldid dpkg-deb python3; do
    command -v "$tool" >/dev/null || fail "Missing $tool. See README.md."
done
# Do not inherit a stale Xcode SDK override; use the selected compiler tools.
unset SDKROOT
xcrun --find clang >/dev/null || fail 'Install Apple Command Line Tools: xcode-select --install'
mkdir -p "$ROOT/build"
if [[ ! -e "$SDK_CHECKOUT" ]]; then
    git init "$SDK_CHECKOUT"
    git -C "$SDK_CHECKOUT" remote add origin "$SDK_REPO"
    git -C "$SDK_CHECKOUT" config remote.origin.promisor true
    git -C "$SDK_CHECKOUT" config remote.origin.partialclonefilter blob:none
    git -C "$SDK_CHECKOUT" sparse-checkout init --cone
    git -C "$SDK_CHECKOUT" sparse-checkout set "$SDK_NAME"
    git -C "$SDK_CHECKOUT" fetch --depth 1 --filter=blob:none origin "$SDK_COMMIT"
    git -C "$SDK_CHECKOUT" checkout --detach FETCH_HEAD
fi
[[ $(git -C "$SDK_CHECKOUT" rev-parse HEAD) == "$SDK_COMMIT" ]] || fail 'SDK checkout is not at the pinned commit.'
[[ -z $(git -C "$SDK_CHECKOUT" status --porcelain --untracked-files=normal) ]] || fail 'SDK checkout has local changes; inspect it before building.'
export IOS_SDK="$SDK_CHECKOUT/$SDK_NAME"
export IOS_SDK_SOURCE="$SDK_REPO at $SDK_COMMIT ($SDK_NAME)"
[[ -f "$IOS_SDK/SDKSettings.plist" ]] || fail 'Pinned SDK is missing or its checkout is incomplete.'
printf 'Community SDK: %s\n' "$IOS_SDK_SOURCE"
printf 'SDK license: %s/LICENSE.md (Apple SDK agreement applies)\n' "$SDK_CHECKOUT"
exec "$ROOT/build-macos.sh"
