import plistlib
import re
import struct
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from verify_macho import verify


def image(platform=2, minimum=(15 << 16) | (5 << 8), cpu=0x0100000C, signature=True):
    commands = struct.pack("<6I", 0x32, 24, platform, minimum, 0, 0)
    if signature:
        commands += struct.pack("<4I", 0x1D, 16, 32 + 40, 4)
    header = struct.pack("<8I", 0xFEEDFACF, cpu, 0, 2, 2 if signature else 1, len(commands), 0, 0)
    return header + commands + (b"test" if signature else b"")


class MachOTests(unittest.TestCase):
    def test_ios_device(self):
        self.assertIn("iOS 15.5.0", verify(image()))

    def test_old_minimum(self):
        self.assertIn("iOS 15.0.0", verify(image(minimum=15 << 16)))

    def test_wrong_platform(self):
        for platform in [1, 3, 6, 7]:
            with self.subTest(platform=platform), self.assertRaises(ValueError):
                verify(image(platform=platform))

    def test_newer_minimum(self):
        for version in [(15 << 16) | (5 << 8) | 1, 16 << 16, 17 << 16]:
            with self.subTest(version=version), self.assertRaises(ValueError):
                verify(image(minimum=version))

    def test_wrong_arch(self):
        with self.assertRaises(ValueError):
            verify(image(cpu=0x01000007))

    def test_unsigned(self):
        with self.assertRaises(ValueError):
            verify(image(signature=False))

    def test_truncated(self):
        for length in [0, 31, 32, 48, 70, 73]:
            with self.subTest(length=length), self.assertRaises(ValueError):
                verify(image()[:length])

    def test_zero_length_command(self):
        data = bytearray(image())
        struct.pack_into("<I", data, 36, 0)
        with self.assertRaises(ValueError):
            verify(data)

    def test_legacy_ios(self):
        commands = struct.pack("<4I", 0x25, 16, (15 << 16) | (5 << 8), 0)
        commands += struct.pack("<4I", 0x1D, 16, 64, 4)
        header = struct.pack("<8I", 0xFEEDFACF, 0x0100000C, 0, 2, 2, 32, 0, 0)
        self.assertIn("iOS 15.5.0", verify(header + commands + b"test"))


class PackagePolicyTests(unittest.TestCase):
    def setUp(self):
        self.job = plistlib.loads((ROOT / "local.syncthing.ios.plist").read_bytes())

    def test_unprivileged_service(self):
        self.assertEqual(self.job["UserName"], "mobile")
        self.assertEqual(self.job["GroupName"], "mobile")
        self.assertEqual(self.job["Umask"], 0o77)

    def test_localhost_and_explicit_state(self):
        args = self.job["ProgramArguments"]
        self.assertEqual(args[0], "/var/jb/usr/bin/syncthing-ios")
        self.assertIn("--gui-address=http://127.0.0.1:8384", args)
        self.assertIn("--home=/var/mobile/Library/Syncthing", args)
        self.assertEqual(self.job["EnvironmentVariables"]["HOME"], "/var/mobile")

    def test_no_subprocess_monitor_or_auto_upgrade(self):
        self.assertEqual(self.job["EnvironmentVariables"]["STMONITORED"], "1")
        for flag in ["--no-browser", "--no-restart", "--no-upgrade"]:
            self.assertIn(flag, self.job["ProgramArguments"])
        self.assertIn("stnoupgrade", (ROOT / "build-macos.sh").read_text())

    def test_no_broad_data_entitlements(self):
        entitlements = plistlib.loads((ROOT / "entitlements.plist").read_bytes())
        self.assertEqual(set(entitlements), {
            "platform-application", "com.apple.private.security.no-container",
        })

    def test_version_and_architecture_consistent(self):
        control = (ROOT / "packaging/control").read_text()
        build = (ROOT / "build-macos.sh").read_text()
        version = re.search(r"^PACKAGE_VERSION=(.+)$", build, re.M)[1]
        self.assertIn(f"Version: {version}\n", control)
        self.assertIn("Architecture: iphoneos-arm64\n", control)
        self.assertIn("GOOS=ios GOARCH=arm64", build)
        self.assertIn("-target arm64-apple-ios15.5", (ROOT / "ios-clang.sh").read_text())

    def test_scripts_non_destructive_and_rootless(self):
        for name in ["preinst", "postinst", "prerm"]:
            text = (ROOT / "packaging" / name).read_text()
            self.assertTrue(text.startswith("#!/var/jb/bin/sh\n"))
            self.assertNotRegex(text, r"(?m)^\s*rm\s")
            self.assertNotRegex(text, r"\b(?:chown|chmod)\s+-[rR]")


if __name__ == "__main__":
    unittest.main()
