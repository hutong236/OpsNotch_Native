#!/usr/bin/env python3
import importlib.util
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("release_version", ROOT / "scripts" / "release_version.py")
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(MODULE)

class ReleaseVersionTests(unittest.TestCase):
    def test_final_version(self):
        self.assertEqual(
            MODULE.parse("3.0.0"),
            {
                "tag_version": "3.0.0",
                "tag": "v3.0.0",
                "app_version": "3.0.0",
                "app_build": "300",
                "prerelease": "false",
                "stage": "final",
                "stage_number": "",
            },
        )

    def test_beta_version_keeps_bundle_numeric(self):
        values = MODULE.parse("3.0.0-beta.1")
        self.assertEqual(values["tag"], "v3.0.0-beta.1")
        self.assertEqual(values["app_version"], "3.0.0")
        self.assertEqual(values["app_build"], "300")
        self.assertEqual(values["prerelease"], "true")
        self.assertEqual(values["stage"], "beta")
        self.assertEqual(values["stage_number"], "1")

    def test_rc_version_keeps_bundle_numeric(self):
        values = MODULE.parse("3.0.0-rc.2")
        self.assertEqual(values["tag"], "v3.0.0-rc.2")
        self.assertEqual(values["app_version"], "3.0.0")
        self.assertEqual(values["app_build"], "300")
        self.assertEqual(values["prerelease"], "true")
        self.assertEqual(values["stage"], "rc")
        self.assertEqual(values["stage_number"], "2")

    def test_invalid_versions_are_rejected(self):
        invalid = [
            "v3.0.0",
            "3.0",
            "3.0.0-beta",
            "3.0.0-beta.0",
            "3.0.0-alpha.1",
            "3.0.0-rc",
            "03.0.0",
        ]
        for version in invalid:
            with self.subTest(version=version):
                with self.assertRaises(ValueError):
                    MODULE.parse(version)

if __name__ == "__main__":
    unittest.main()
