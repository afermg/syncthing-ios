#!/usr/bin/env python3
"""Reject macOS/simulator binaries and deployment targets newer than iOS 15.5.

This checks metadata only, NOT runtime compatibility or signature trust.
"""
import struct
import sys
from pathlib import Path


def verify(data):
    if len(data) < 32:
        raise ValueError("truncated Mach-O header")
    magic, cpu, subtype, kind, ncmds, size, flags, reserved = struct.unpack_from("<8I", data)
    if (magic, cpu, kind) != (0xFEEDFACF, 0x0100000C, 2):
        raise ValueError("expected a thin little-endian ARM64 Mach-O executable")
    if subtype & 0xFFFFFF != 0:
        raise ValueError("expected baseline arm64, not arm64e")
    end = 32 + size
    if end > len(data):
        raise ValueError("truncated load commands")
    offset = 32
    versions = []
    signed = False
    for _ in range(ncmds):
        if offset + 8 > end:
            raise ValueError("truncated load command")
        cmd, length = struct.unpack_from("<2I", data, offset)
        if length < 8 or offset + length > end:
            raise ValueError("invalid load command length")
        if cmd == 0x32:  # LC_BUILD_VERSION
            if length < 24:
                raise ValueError("truncated LC_BUILD_VERSION")
            platform, minimum = struct.unpack_from("<2I", data, offset + 8)
            if platform != 2:  # PLATFORM_IOS, not MACOS=1 / IOSSIMULATOR=7
                raise ValueError(f"not an iOS device binary (platform={platform})")
            versions.append(minimum)
        elif cmd == 0x25:  # LC_VERSION_MIN_IPHONEOS (older linkers)
            if length < 16:
                raise ValueError("truncated LC_VERSION_MIN_IPHONEOS")
            versions.append(struct.unpack_from("<I", data, offset + 8)[0])
        elif cmd in (0x24, 0x2F, 0x30):
            raise ValueError("non-iOS deployment target")
        elif cmd == 0x1D:  # LC_CODE_SIGNATURE
            if length < 16:
                raise ValueError("truncated code signature command")
            start, count = struct.unpack_from("<2I", data, offset + 8)
            signed = count > 0 and start >= end and start + count <= len(data)
        offset += length
    if offset != end or not versions:
        raise ValueError("missing or inconsistent deployment metadata")
    if any(v > ((15 << 16) | (5 << 8)) for v in versions):
        raise ValueError("minimum iOS version exceeds 15.5")
    if not signed:
        raise ValueError("missing code signature")
    minimum = max(versions)
    return f"arm64 / iOS {minimum >> 16}.{(minimum >> 8) & 255}.{minimum & 255}; signature present"


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit("Usage: verify_macho.py PATH")
    try:
        print(verify(Path(sys.argv[1]).read_bytes()))
    except (ValueError, OSError) as exc:
        sys.exit(f"Binary validation failed: {exc}")
