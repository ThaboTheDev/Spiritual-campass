from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tool"))
from register_ios_compass import register


class PlatformConfigTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.project = Path(self.temp.name) / "Runner.xcodeproj" / "project.pbxproj"
        self.project.parent.mkdir(parents=True)
        current = (ROOT / "ios/Runner.xcodeproj/project.pbxproj").read_text()
        self.baseline = "\n".join(line for line in current.splitlines() if "CompassPlugin.swift" not in line) + "\n"
        self.project.write_text(self.baseline)

    def test_registers_existing_scaffold_and_is_idempotent(self):
        register(self.project)
        first = self.project.read_bytes()
        self.assertIn(b"CompassPlugin.swift in Sources", first)
        register(self.project)
        self.assertEqual(first, self.project.read_bytes())
        self.assertIn(b"SceneDelegate.swift", first)

    def test_preserves_project_on_unsupported_scaffold(self):
        self.project.write_text("unsupported project")
        with self.assertRaises(ValueError):
            register(self.project)
        self.assertEqual(self.project.read_text(), "unsupported project")

    def test_filesystem_synchronized_runner_needs_no_manual_entries(self):
        text = "{ isa = PBXFileSystemSynchronizedRootGroup; path = Runner; }"
        self.project.write_text(text)
        register(self.project)
        self.assertEqual(self.project.read_text(), text)

    def test_partial_registration_fails(self):
        self.project.write_text("CompassPlugin.swift in Sources")
        with self.assertRaises(ValueError):
            register(self.project)

    def test_apply_platform_config_binds_native_bridges_without_replacing_project(self):
        target = Path(self.temp.name) / "app"
        pbx = target / "ios/Runner.xcodeproj/project.pbxproj"
        pbx.parent.mkdir(parents=True)
        pbx.write_text(self.baseline)
        (target / "android/app").mkdir(parents=True)
        (target / "android/app/build.gradle").write_text("old Groovy scaffold")
        subprocess.run(["bash", str(ROOT / "tool/apply_platform_config.sh"), str(target)], check=True, capture_output=True)
        self.assertFalse((target / "android/app/build.gradle").exists())
        self.assertTrue((target / "android/app/src/main/kotlin/com/tshk/tshk_compass/CompassPlugin.kt").exists())
        self.assertTrue((target / "ios/Runner/CompassPlugin.swift").exists())
        self.assertIn("CompassPlugin.swift in Sources", pbx.read_text())
        first = pbx.read_bytes()
        subprocess.run(["bash", str(ROOT / "tool/apply_platform_config.sh"), str(target)], check=True, capture_output=True)
        self.assertEqual(first, pbx.read_bytes())


if __name__ == "__main__":
    unittest.main()
