import os
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class CompilerWrapperTests(unittest.TestCase):
    def test_explicit_compiler_and_sdk_with_spaces(self):
        with tempfile.TemporaryDirectory(prefix="ios wrapper ") as tmp:
            compiler = Path(tmp) / "fake clang"
            compiler.write_text('#!/bin/sh\nprintf "%s\\n" "$@"\n')
            compiler.chmod(0o755)
            sdk = str(Path(tmp) / "iPhoneOS test.sdk")
            env = dict(os.environ, IOS_SDK=sdk, IOS_CC=str(compiler))
            result = subprocess.run(
                ["bash", str(ROOT / "ios-clang.sh"), "-c", "input with spaces.c"],
                env=env, capture_output=True, text=True, check=True,
            )
            self.assertEqual(result.stdout.splitlines(), [
                "-target", "arm64-apple-ios15.5", "-isysroot", sdk,
                "-c", "input with spaces.c",
            ])

    def test_sdk_required(self):
        env = dict(os.environ)
        env.pop("IOS_SDK", None)
        result = subprocess.run(
            ["bash", str(ROOT / "ios-clang.sh"), "-c", "input.c"],
            env=env, capture_output=True, text=True,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Use build-macos.sh", result.stderr)


if __name__ == "__main__":
    unittest.main()
