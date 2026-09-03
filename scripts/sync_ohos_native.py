#!/usr/bin/env python3
"""Sync tracked HarmonyOS native sources into Flutter's generated .ohos host.

职责：
1. 把受控的 harmonyos/AppScope 与 harmonyos/entry/src/main 同步到生成的 .ohos 宿主；
   其中 ets/ 树做镜像同步（删除生成目录里的陈旧文件），资源树只覆盖拷贝
   （.ohos 里有 flutter build har 生成的 color.json / en_US / zh_CN 等文件，不能删）。
2. 版本号单点注入：以根 pubspec.yaml 的 `version: X.Y.Z+N` 为唯一来源，
   写 harmonyos/AppScope/app.json5（versionName/versionCode）并回写
   harmonyos/wepei_module/pubspec.yaml。
3. 调用 configure_ohos_signing 注入签名与 SDK 版本（见该脚本说明）。
"""

from pathlib import Path
import json
import re
import shutil

import configure_ohos_signing


ROOT = Path(__file__).resolve().parents[1]
SOURCE_APP = ROOT / "harmonyos" / "AppScope"
SOURCE_ENTRY = ROOT / "harmonyos" / "entry" / "src" / "main"
TARGET = ROOT / "harmonyos" / "wepei_module" / ".ohos"
ROOT_PUBSPEC = ROOT / "pubspec.yaml"
OHOS_PUBSPEC = ROOT / "harmonyos" / "wepei_module" / "pubspec.yaml"
APP_JSON5 = SOURCE_APP / "app.json5"

_VERSION_RE = re.compile(r"^version:\s*(\S+)\s*$", re.MULTILINE)


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


def mirror_tree(source: Path, target: Path) -> None:
    """覆盖拷贝，并删除目标中源里已不存在的文件/目录（仅用于受控 ets 树）。"""
    target.mkdir(parents=True, exist_ok=True)
    source_names = {item.name for item in source.iterdir()}
    for item in target.iterdir():
        if item.name not in source_names:
            if item.is_dir():
                shutil.rmtree(item)
            else:
                item.unlink()
    for item in source.iterdir():
        destination = target / item.name
        if item.is_dir():
            mirror_tree(item, destination)
        else:
            copy_file(item, destination)


def read_root_version() -> tuple[str, int]:
    text = ROOT_PUBSPEC.read_text(encoding="utf-8")
    match = _VERSION_RE.search(text)
    if not match:
        raise SystemExit("Missing `version:` in pubspec.yaml")
    raw = match.group(1)
    name, _, build = raw.partition("+")
    if not build.isdigit():
        raise SystemExit(f"Unexpected version format in pubspec.yaml: {raw!r}")
    return name, int(build)


def sync_version(name: str, build: int) -> None:
    """以根 pubspec 为唯一版本来源，更新 AppScope/app.json5 与 OHOS pubspec。"""
    app = json.loads(APP_JSON5.read_text(encoding="utf-8"))
    app["app"]["versionName"] = name
    app["app"]["versionCode"] = build
    APP_JSON5.write_text(
        json.dumps(app, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )

    text = OHOS_PUBSPEC.read_text(encoding="utf-8")
    updated = _VERSION_RE.sub(f"version: {name}+{build}", text, count=1)
    if updated == text and f"version: {name}+{build}" not in text:
        raise SystemExit("Missing `version:` in wepei_module/pubspec.yaml")
    OHOS_PUBSPEC.write_text(updated, encoding="utf-8")


def sync() -> None:
    if not TARGET.is_dir():
        raise SystemExit("Missing generated host: run flutter build har first")

    name, build = read_root_version()
    sync_version(name, build)

    copy_file(SOURCE_APP / "app.json5", TARGET / "AppScope" / "app.json5")
    copy_tree(
        SOURCE_APP / "resources",
        TARGET / "AppScope" / "resources",
    )

    mirror_tree(
        SOURCE_ENTRY / "ets",
        TARGET / "entry" / "src" / "main" / "ets",
    )
    copy_file(
        SOURCE_ENTRY / "module.json5",
        TARGET / "entry" / "src" / "main" / "module.json5",
    )

    copy_tree(
        SOURCE_ENTRY / "resources",
        TARGET / "entry" / "src" / "main" / "resources",
    )

    stale_files = [
        TARGET / "entry" / "src" / "main" / "resources" / "base" / "media" / "icon.png",
    ]
    for stale_file in stale_files:
        stale_file.unlink(missing_ok=True)

    configure_ohos_signing.apply(TARGET)


if __name__ == "__main__":
    sync()
    print("Synced tracked HarmonyOS native sources into .ohos")
