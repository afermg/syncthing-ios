# Release v2.1.5-1

Unofficial Syncthing v2.1.5 daemon package for rootless jailbroken iPadOS.

## Assets

- `local.syncthing.ios_2.1.5-1_iphoneos-arm64.deb`
- `local.syncthing.ios_2.1.5-1_iphoneos-arm64.deb.sha256`

SHA-256:

```text
54eb820350b37347e0cb0f0304b3a188a0b84172b53fef95b835aff5e9faa87e  local.syncthing.ios_2.1.5-1_iphoneos-arm64.deb
```

## Tested

- iPadOS 15.5
- Dopamine/rootless `/var/jb`
- Package install, launchd service, localhost web UI, peer pairing, and folder sync

## Caveats

- Requires a jailbreak package install route; TrollStore alone is not enough.
- This is not a stock iPadOS app and has no home-screen icon.
- If `dynamic` addresses stay disconnected, enable peer discovery or set a manual
  `tcp://DEVICE_IP:22000` address.
- Normal app access requires syncing into that app's exposed Documents folder;
  see `CAVEATS.md`.
- Long-term background, locked-device, battery, and post-reboot behavior remain
  device-specific.

This is an unofficial build, not a Syncthing project release.
