#!/usr/bin/env python3
"""Bind the app-owned Swift bridge after reapplying a generated iOS scaffold.

Idempotent; preserve the rest of the Xcode project. No third-party modules.
"""
from pathlib import Path
import re
import sys

BUILD_ID = "C0A5A5500000000000000001"
FILE_ID = "C0A5A5500000000000000002"


def register(path: Path) -> None:
    text = path.read_text()
    if "CompassPlugin.swift in Sources" in text:
        if "path = CompassPlugin.swift;" not in text:
            raise ValueError("incomplete CompassPlugin.swift registration")
        return
    # Newer Xcode projects can automatically include every Swift file in Runner.
    if re.search(r"\{[^{}]*isa = PBXFileSystemSynchronizedRootGroup;[^{}]*path = Runner;", text):
        return
    if BUILD_ID in text or FILE_ID in text:
        raise ValueError("compass Xcode identifier collision")
    app_file = re.search(r"([A-F0-9]{24}) /\* AppDelegate.swift \*/ = \{isa = PBXFileReference;", text)
    app_build = re.search(r"([A-F0-9]{24}) /\* AppDelegate.swift in Sources \*/ = \{isa = PBXBuildFile;", text)
    if app_file is None or app_build is None:
        raise ValueError("cannot locate AppDelegate in this Xcode scaffold")
    text = text.replace("/* Begin PBXBuildFile section */", "/* Begin PBXBuildFile section */\n"
        f"\t\t{BUILD_ID} /* CompassPlugin.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {FILE_ID} /* CompassPlugin.swift */; }};", 1)
    text = text.replace("/* Begin PBXFileReference section */", "/* Begin PBXFileReference section */\n"
        f'\t\t{FILE_ID} /* CompassPlugin.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = CompassPlugin.swift; sourceTree = "<group>"; }};', 1)
    for existing, new_id, label in [
        (app_file.group(1), FILE_ID, "CompassPlugin.swift"),
        (app_build.group(1), BUILD_ID, "CompassPlugin.swift in Sources"),
    ]:
        text, count = re.subn(rf"(\t+{existing} /\* [^\n]+ \*/,)",
            lambda match: match.group(1) + f"\n\t\t\t\t{new_id} /* {label} */,", text, count=1)
        if count != 1:
            raise ValueError("cannot locate Runner group or Sources phase")
    path.write_text(text)


if __name__ == "__main__":
    try:
        register(Path(sys.argv[1]))
    except (IndexError, OSError, ValueError) as error:
        sys.exit(f"error registering native compass: {error}")
