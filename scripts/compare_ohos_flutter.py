#!/usr/bin/env python3
"""Compare the original Flutter Dart tree with the HarmonyOS module tree.

The script is deliberately conservative: only differences with an explicit
OHOS signal are classified as adaptations. Everything else requires review.
"""

from __future__ import annotations

import argparse
import difflib
import json
import re
import sys
from pathlib import Path
from typing import Iterable


OHOS_MARKERS = (
    "MockSharedPreferences",
    "WidgetDataSync",
    "ImageSave",
    "MethodChannel",
    "Platform.isAndroid",
    "Platform.isIOS",
    "Platform.operatingSystem",
    "flutter_inappwebview_ohos",
    "_ohos",
    "OHOS",
    "HarmonyOS",
    "com.twt.service/",
)

OHOS_PATH_MARKERS = (
    "/commons/channel/",
    "/commons/preferences/mock_shared_prefs.dart",
    "/harmonyos/",
)

PACKAGE_PREFIXES = (
    ("package:we_pei_yang_flutter/", "package:__APP__/"),
    ("package:wepei_module/", "package:__APP__/"),
)


class Finding(dict):
    """JSON-friendly comparison finding."""


def normalize_line(line: str) -> str:
    """Remove only CRLF noise and package-name differences."""
    line = line.rstrip("\r\n")
    for source, replacement in PACKAGE_PREFIXES:
        line = line.replace(source, replacement)
    return line


def read_dart(path: Path) -> list[str]:
    return [normalize_line(line) for line in path.read_text(encoding="utf-8").splitlines()]


def has_ohos_marker(text: str) -> bool:
    return any(marker in text for marker in OHOS_MARKERS)


def changed_lines(hunk: list[str]) -> list[str]:
    return [
        line[1:]
        for line in hunk
        if len(line) > 1 and line[0] in "+-" and not line.startswith(("+++", "---"))
    ]


def unified_hunks(original: list[str], ohos: list[str], path: str) -> list[list[str]]:
    diff = difflib.unified_diff(
        original,
        ohos,
        fromfile=f"original/{path}",
        tofile=f"ohos/{path}",
        n=2,
        lineterm="",
    )
    hunks: list[list[str]] = []
    current: list[str] | None = None
    for line in diff:
        if line.startswith("@@"):
            if current is not None:
                hunks.append(current)
            current = [line]
        elif current is not None:
            current.append(line)
    if current is not None:
        hunks.append(current)
    return hunks


def format_hunk(hunk: Iterable[str]) -> str:
    return "\n".join(hunk)


def classify_hunk(hunk: list[str], path: str) -> str:
    changed = "\n".join(changed_lines(hunk))
    if has_ohos_marker(changed):
        return "OHOS_ADAPTATION"
    if any(marker in f"/{path}" for marker in OHOS_PATH_MARKERS):
        return "OHOS_ADAPTATION"
    return "REVIEW"


def compare_file(original: Path, ohos: Path, relative: str) -> list[Finding]:
    original_lines = read_dart(original)
    ohos_lines = read_dart(ohos)
    if original_lines == ohos_lines:
        return []

    findings: list[Finding] = []
    for hunk in unified_hunks(original_lines, ohos_lines, relative):
        findings.append(
            Finding(
                kind="hunk",
                path=relative,
                category=classify_hunk(hunk, relative),
                diff=format_hunk(hunk),
            )
        )
    return findings


def classify_extra(path: Path, relative: str) -> str:
    if any(marker in f"/{relative}" for marker in OHOS_PATH_MARKERS):
        return "OHOS_ADAPTATION"
    try:
        if has_ohos_marker(path.read_text(encoding="utf-8")):
            return "OHOS_ADAPTATION"
    except UnicodeDecodeError:
        pass
    return "REVIEW"


def compare_trees(original_root: Path, ohos_root: Path) -> dict:
    original_files = {
        path.relative_to(original_root).as_posix(): path
        for path in original_root.rglob("*.dart")
    }
    ohos_files = {
        path.relative_to(ohos_root).as_posix(): path
        for path in ohos_root.rglob("*.dart")
    }

    findings: list[Finding] = []
    missing = sorted(set(original_files) - set(ohos_files))
    extra = sorted(set(ohos_files) - set(original_files))

    for relative in missing:
        findings.append(
            Finding(
                kind="missing",
                path=relative,
                category="REVIEW",
                diff="original file is missing from the HarmonyOS module",
            )
        )
    for relative in extra:
        findings.append(
            Finding(
                kind="extra",
                path=relative,
                category=classify_extra(ohos_files[relative], relative),
                diff="HarmonyOS module file has no original counterpart",
            )
        )

    common = sorted(set(original_files) & set(ohos_files))
    for relative in common:
        findings.extend(compare_file(original_files[relative], ohos_files[relative], relative))

    adaptation = [f for f in findings if f["category"] == "OHOS_ADAPTATION"]
    review = [f for f in findings if f["category"] == "REVIEW"]
    changed_files = {f["path"] for f in findings if f["kind"] == "hunk"}

    return {
        "original": str(original_root),
        "ohos": str(ohos_root),
        "original_files": len(original_files),
        "ohos_files": len(ohos_files),
        "common_files": len(common),
        "equal_files": len(common) - len(changed_files),
        "changed_files": len(changed_files),
        "adaptation_findings": len(adaptation),
        "review_findings": len(review),
        "missing_files": missing,
        "extra_files": extra,
        "findings": findings,
    }


def print_report(
    report: dict, show_adapted: bool, show_review: bool, show_all: bool
) -> None:
    print("OHOS Flutter Dart comparison")
    print(f"original: {report['original']}")
    print(f"ohos:     {report['ohos']}")
    print(
        "files:    "
        f"{report['original_files']} original, {report['ohos_files']} OHOS, "
        f"{report['equal_files']} equal, {report['changed_files']} changed"
    )
    print(
        "findings: "
        f"{report['adaptation_findings']} suspected OHOS adaptations, "
        f"{report['review_findings']} requiring review"
    )

    if not (show_adapted or show_review or show_all):
        grouped: dict[str, dict[str, int]] = {}
        for finding in report["findings"]:
            category = finding["category"]
            grouped.setdefault(category, {})[finding["path"]] = (
                grouped.setdefault(category, {}).get(finding["path"], 0) + 1
            )
        for category in ("REVIEW", "OHOS_ADAPTATION"):
            paths = grouped.get(category, {})
            if not paths:
                continue
            print(f"\n{category} paths:")
            for path, count in sorted(paths.items()):
                print(f"  {path} ({count} finding{'s' if count != 1 else ''})")
    else:
        for finding in report["findings"]:
            category = finding["category"]
            if category == "OHOS_ADAPTATION" and not (show_adapted or show_all):
                continue
            if category == "REVIEW" and not (show_review or show_all):
                continue
            print(f"\n[{category}] {finding['kind']}: {finding['path']}")
            print(finding["diff"])

    if report["review_findings"] == 0 and not report["missing_files"]:
        print("\nPASS: every detected difference is classified as an OHOS adaptation.")
    else:
        print("\nFAIL: unclassified differences or missing files require review.")


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    repo = Path(__file__).resolve().parents[1]
    parser.add_argument("--original", type=Path, default=repo / "lib")
    parser.add_argument(
        "--ohos", type=Path, default=repo / "harmonyos" / "wepei_module" / "lib"
    )
    parser.add_argument("--json", action="store_true", help="emit JSON instead of text")
    parser.add_argument(
        "--show-adapted", action="store_true", help="print suspected OHOS adaptation hunks"
    )
    parser.add_argument(
        "--show-review", action="store_true", help="print hunks that require review"
    )
    parser.add_argument("--all", action="store_true", help="print every finding")
    parser.add_argument(
        "--strict",
        action="store_true",
        help="return 1 when any difference is not classified as OHOS-specific",
    )
    args = parser.parse_args(argv)

    original_root = args.original.resolve()
    ohos_root = args.ohos.resolve()
    if not original_root.is_dir():
        parser.error(f"original directory does not exist: {original_root}")
    if not ohos_root.is_dir():
        parser.error(f"OHOS directory does not exist: {ohos_root}")

    report = compare_trees(original_root, ohos_root)
    if args.json:
        print(json.dumps(report, ensure_ascii=False, indent=2))
    else:
        print_report(report, args.show_adapted, args.show_review, args.all)

    return 1 if args.strict and report["review_findings"] else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
