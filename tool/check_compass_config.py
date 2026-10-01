#!/usr/bin/env python3
"""SDK-independent checks; these are not Flutter/native compilation tests."""
import json
from pathlib import Path
import plistlib
import re
import sys
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]


def check() -> None:
    overlay = ROOT / "platform_config"
    for source in overlay.rglob("*"):
        if source.is_file():
            destination = ROOT / source.relative_to(overlay)
            assert destination.is_file(), f"missing active platform file: {destination}"
            assert source.read_bytes() == destination.read_bytes(), f"platform overlay differs: {source}"
    translation_file = ROOT / "assets/translations.json"
    tables = json.loads(translation_file.read_text())
    assert translation_file.read_bytes() == (ROOT / "translations.json").read_bytes()
    keys = set(tables["zu"])
    used = set(re.findall(r"key: '([a-z0-9_]+)'", (ROOT / "lib/core/l10n/strings.dart").read_text()))
    assert used <= keys, f"missing translation keys: {used - keys}"
    placeholders = lambda value: set(re.findall(r"\{(\w+)\}", value))
    for language in ["pt", "ny", "bem"]:
        assert set(tables[language]) == keys, f"keys differ in {language}"
        for key in keys:
            assert placeholders(tables[language][key]) == placeholders(tables["zu"][key]), f"placeholders differ: {language}/{key}"
    plist = plistlib.loads((ROOT / "ios/Runner/Info.plist").read_bytes())
    assert plist["UISupportedInterfaceOrientations"] == ["UIInterfaceOrientationPortrait"]
    assert "UIApplicationSceneManifest" in plist
    for manifest in (ROOT / "android/app/src").glob("*/AndroidManifest.xml"):
        ET.parse(manifest)
    project = (ROOT / "ios/Runner.xcodeproj/project.pbxproj").read_text()
    assert "path = CompassPlugin.swift;" in project
    assert project.count("C0A5A5500000000000000001") == 2
    assert project.count("C0A5A5500000000000000002") == 3
    for file in ["pubspec.yaml", "pubspec.lock"]:
        assert "flutter_compass:" not in (ROOT / file).read_text()
    assert len(list((ROOT / "assets/fonts").glob("*.ttf"))) == 8
    print("Platform mirrors, iOS registration, orientation, translation keys/placeholders, dependency removal and fonts: OK")


if __name__ == "__main__":
    try:
        check()
    except (AssertionError, KeyError, OSError, ValueError) as error:
        sys.exit(f"configuration check failed: {error}")
