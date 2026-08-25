#!/usr/bin/env python3
"""Sync tracked HarmonyOS native sources into Flutter's generated .ohos host."""

from pathlib import Path
import re
import shutil


ROOT = Path(__file__).resolve().parents[1]
SOURCE_APP = ROOT / "harmonyos" / "AppScope"
SOURCE_ENTRY = ROOT / "harmonyos" / "entry" / "src" / "main"
TARGET = ROOT / "harmonyos" / "wepei_module" / ".ohos"


def copy_file(source: Path, target: Path) -> None:
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, target)


def copy_tree(source: Path, target: Path) -> None:
    target.mkdir(parents=True, exist_ok=True)
    for item in source.iterdir():
        destination = target / item.name
        if item.is_dir():
            copy_tree(item, destination)
        else:
            copy_file(item, destination)


def sync() -> None:
    if not TARGET.is_dir():
        raise SystemExit("Missing generated host: run flutter build har first")

    copy_file(SOURCE_APP / "app.json5", TARGET / "AppScope" / "app.json5")
    copy_tree(
        SOURCE_APP / "resources" / "base" / "media",
        TARGET / "AppScope" / "resources" / "base" / "media",
    )

    copy_file(
        SOURCE_ENTRY / "ets" / "entryability" / "EntryAbility.ets",
        TARGET / "entry" / "src" / "main" / "ets" / "entryability" / "EntryAbility.ets",
    )
    copy_file(
        SOURCE_ENTRY / "ets" / "pages" / "Index.ets",
        TARGET / "entry" / "src" / "main" / "ets" / "pages" / "Index.ets",
    )

    module_source = (SOURCE_ENTRY / "module.json5").read_text()
    module_source = re.sub(
        r'\n    "extensionAbilities": \[.*?\n    \],\n    "abilities":',
        '\n    "abilities":',
        module_source,
        flags=re.DOTALL,
    )
    module_target = TARGET / "entry" / "src" / "main" / "module.json5"
    module_target.write_text(module_source)

    copy_tree(
        SOURCE_ENTRY / "resources" / "base" / "media",
        TARGET / "entry" / "src" / "main" / "resources" / "base" / "media",
    )
    copy_file(
        SOURCE_ENTRY / "resources" / "base" / "profile" / "start_window.json",
        TARGET / "entry" / "src" / "main" / "resources" / "base" / "profile" / "start_window.json",
    )

    stale_files = [
        TARGET / "entry" / "src" / "main" / "resources" / "base" / "media" / "icon.png",
    ]
    for stale_file in stale_files:
        stale_file.unlink(missing_ok=True)


if __name__ == "__main__":
    sync()
    print("Synced tracked HarmonyOS native sources into .ohos")
