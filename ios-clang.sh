#!/bin/bash
set -euo pipefail
: "${IOS_SDK:?Use build-macos.sh}"
# Resolve the compiler independently of the SDK, so Command Line Tools work too.
exec "${IOS_CC:-$(/usr/bin/xcrun --find clang)}" \
    -target arm64-apple-ios15.5 -isysroot "$IOS_SDK" "$@"
