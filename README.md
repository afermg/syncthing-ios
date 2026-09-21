# syncthing-ios

Unofficial Syncthing daemon package for **rootless jailbroken iPadOS**.

This builds upstream Syncthing as a launchd daemon with the standard Syncthing
web UI at `http://127.0.0.1:8384`. It is **not** a home-screen app, Files
provider, Sushitrain replacement, or TrollStore app.

## Supported test target

- iPadOS 15.5
- Dopamine/rootless jailbreak with `/var/jb`
- `iphoneos-arm64` dpkg architecture
- Syncthing v2.1.5, package `2.1.5-1`

Other iPadOS versions or jailbreak layouts may work, but are untested.

## Install

Download the `.deb` from Releases and install it through the jailbreak, for
example in NewTerm/SSH:

```sh
sudo dpkg -i /var/mobile/local.syncthing.ios_2.1.5-1_iphoneos-arm64.deb
```

Then open Safari on the iPad:

```text
http://127.0.0.1:8384
```

Set a GUI username/password, add your other Syncthing device, and accept or add
folders with paths under:

```text
/var/mobile/Media/Syncthing
```

## Build

No paid Apple developer account is required. The no-account build uses Apple
Command Line Tools plus a pinned community iPhoneOS SDK checkout:

```sh
brew install go ldid dpkg python
xcode-select --install   # if Command Line Tools are missing
unset SDKROOT DEVELOPER_DIR
./build-no-account.sh
```

Full-Xcode builds are also supported:

```sh
unset SDKROOT DEVELOPER_DIR
./build-macos.sh
```

Output:

```text
dist/local.syncthing.ios_2.1.5-1_iphoneos-arm64.deb
dist/local.syncthing.ios_2.1.5-1_iphoneos-arm64.deb.sha256
```

## Important caveats

- Requires an active rootless jailbreak; TrollStore alone is not enough.
- The daemon runs as `mobile`; the web UI is localhost-only.
- `/var/mobile/Media/Syncthing` does not automatically appear in Apple's Files app.
- Syncthing discovery depends on both peers. If a peer has local/global discovery
  and relays disabled, `dynamic` addresses may stay disconnected; enable LAN
  discovery or set `tcp://DEVICE_IP:22000` manually.
- The iPad Safari UI may need a Syncthing restart after some config changes.
- Locked-device/background syncing, battery use, and post-reboot behavior must be
  tested on your own device.
- This is not an official Syncthing project release.

More detail: [CAVEATS.md](CAVEATS.md) and [VALIDATION.md](VALIDATION.md).

## Service management

Run as root on the iPad:

```sh
launchctl print system/local.syncthing.ios
tail -n 100 /var/mobile/Library/Syncthing/daemon.log

launchctl unload -w /var/jb/Library/LaunchDaemons/local.syncthing.ios.plist
launchctl load -w /var/jb/Library/LaunchDaemons/local.syncthing.ios.plist
```

## License

This repository is an unofficial build/package recipe. Syncthing itself is
MPL-2.0; upstream `LICENSE` and `AUTHORS` are included in the built package.
