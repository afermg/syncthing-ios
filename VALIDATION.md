# Validation status

## Final release artifact

Built on macOS using Apple Command Line Tools, a pinned community iPhoneOS SDK,
and no Apple account:

- `dist/local.syncthing.ios_2.1.5-1_iphoneos-arm64.deb`
- Size: 10,908,704 bytes
- SHA-256: `54eb820350b37347e0cb0f0304b3a188a0b84172b53fef95b835aff5e9faa87e`

Build inputs:

- Upstream Syncthing v2.1.5 at commit
  `2ca95cf1498104113fdfde46df4107f2450a0f71`; Go modules verified.
- Go 1.26.2, `GOOS=ios`, `GOARCH=arm64`, CGO enabled,
  `stnoupgrade,timetzdata` tags.
- Apple Command Line Tools, Apple clang 21.0.0, linker 1267.0.
- `https://github.com/theos/sdks` at
  `0222fd5413cf4b9af096f37b4621afa2688572f7`, `iPhoneOS15.6.sdk`; SDK metadata
  reports iOS 15.5.
- Native Apple ad-hoc `codesign --sign -`, with XML and DER entitlements; no
  certificate, keychain identity, or Apple account.

Checks passed:

- Python unit/policy tests.
- Bash/POSIX syntax checks and ShellCheck for build/package scripts.
- Plist validation.
- Full compile/link/sign/package through `./build-no-account.sh`.
- SHA-256 verification of the final package.
- Package extraction and strict macOS signature verification of the packaged
  binary.
- Mach-O metadata: baseline ARM64, iOS device platform, minimum iOS 15.5,
  SDK 15.5; not macOS or simulator.
- Go metadata: pinned upstream commit/toolchain, ios/arm64, CGO and expected
  tags.
- Entitlements exactly match `entitlements.plist`.
- Dynamic dependencies restricted to iOS system libraries/frameworks:
  libSystem, libresolv, CoreFoundation, Security.
- Archive root ownership and rootless `/var/jb` paths.
- Sanitization scan of publishable source and `.deb`: no local user paths,
  personal device IDs, local network IPs, hostnames, or private folder names.

Evidence retained locally but not intended for release:

- `build/no-account-sanitized-build.log`
- `build/sanitized-package-check.log`
- `build/run.f10rFr`

## Device validation

Tested on a rootless Dopamine iPad running iPadOS 15.5:

- Package installed through the jailbreak route.
- Service launched as a launchd daemon.
- Local web UI opened at `http://127.0.0.1:8384`.
- Paired with another Syncthing peer.
- A shared folder connected and began syncing after daemon restart.

Known observed caveat: if both peers stay disconnected while using `dynamic`
addresses, verify discovery settings on the other peer or set a manual
`tcp://DEVICE_IP:22000` address. Restarting Syncthing after configuration changes
may be necessary on iPad Safari.

Still not fully characterized:

- Long-duration locked-device/background syncing.
- Battery/thermal behavior with large folder sets.
- Behavior after full reboot and re-jailbreak.
- Other iPadOS versions, jailbreaks, RootHide, or rootful layouts.
