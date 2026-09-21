# Caveats and notes

## Accessing synced files from normal iPad apps

The default sync root is:

```text
/var/mobile/Media/Syncthing
```

This is convenient for Filza/NewTerm, but it does **not** automatically appear in
Apple's Files app or in ordinary sandboxed apps.

For a normal app to see files, sync into a folder that app already exposes to
Files, usually inside that app's `Documents` container. The safest workflow is:

1. In the normal app or Files app, create a dedicated folder such as
   `Syncthing/pdfs` under that app's **On My iPad** location.
2. In Filza, find that folder and copy its real path. It will usually look like:

   ```text
   /var/mobile/Containers/Data/Application/<UUID>/Documents/Syncthing/pdfs
   ```

3. Use that exact path as the Syncthing folder path on the iPad.
4. Prefer **Receive Only** until you confirm the app handles externally-created
   files correctly.

Do **not** sync an app's private database, caches, full container, or iCloud
library. Use a dedicated document subfolder only. Container UUIDs can change when
apps are reinstalled, so re-check the path after reinstalling the app.

## Discovery and connection caveats

This package leaves Syncthing's normal discovery behavior enabled on fresh iPad
configs. However, both peers participate in discovery. If your other Syncthing
instance has local/global discovery and relays disabled, `dynamic` addresses may
not work. In that case either enable LAN discovery on the other peer or set a
manual address such as:

```text
tcp://<peer-lan-ip>:22000
```

After changing device addresses or discovery settings, restart Syncthing if the
UI still shows disconnected.

## iPad web UI caveats

The standard Syncthing UI is not optimized for old iPad Safari/jailbreak WebKit
combinations. If a **Save** button appears to do nothing, restart the daemon and
try again, or make the same configuration change from another peer where possible.

Restart on the iPad as root:

```sh
launchctl unload -w /var/jb/Library/LaunchDaemons/local.syncthing.ios.plist
launchctl load -w /var/jb/Library/LaunchDaemons/local.syncthing.ios.plist
```

## Runtime caveats

- Requires a standard rootless jailbreak with `/var/jb`; TrollStore alone is not
  enough.
- Runs as `mobile`, not root.
- The GUI is forced to `127.0.0.1:8384`; do not expose it to Wi-Fi.
- Locked/asleep behavior, battery drain, heat, and file watcher reliability vary
  by device and folder size.
- After a full reboot, re-enable the semi-untethered jailbreak before expecting
  the daemon to run.
- This is an unofficial build, not a Syncthing project release.
