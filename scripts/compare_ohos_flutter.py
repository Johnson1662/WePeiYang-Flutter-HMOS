#!/usr/bin/env python3
"""Compare the original Flutter Dart and asset trees with their OHOS copies.

The script distinguishes direct OHOS hunks from generic hunks inside files
that also contain OHOS code, and hashes assets to find missing, extra, or
changed files. Only unclassified differences require review.
"""

from __future__ import annotations

import argparse
import difflib
import hashlib
import json
import re
import sys
from pathlib import Path
from typing import Iterable


OHOS_MARKERS = (
    "MockSharedPreferences",
    "mock_shared_prefs.dart",
    "WidgetDataSync",
    "widget_data_sync.dart",
    "ImageSave",
    "image_save.dart",
    "MethodChannel",
    "Platform.isAndroid",
    "Platform.isIOS",
    "Platform.operatingSystem",
    "TargetPlatform.android",
    "Platform.isOhos",
    "TargetPlatform.ohos",
    "flutter_inappwebview_ohos",
    "flutter_native_image",
    "webview_page.dart",
    "webview_flutter",
    "WebViewWidget",
    "Image.network",
    "logger.dart",
    "openUrlInApp",
    "IOHttpClientAdapter",
    "badCertificateCallback",
    "Directory.systemTemp",
    "DefaultCookieJar",
    "SharedPreferencesWithCache",
    "_isOhos",
    "hasTjuCredentials",
    "syncTjuBindingState",
    "wepeiyang_state.json",
    "_ohos",
    "OHOS",
    "HarmonyOS",
    "com.twt.service/",
)

OHOS_PATH_MARKERS = (
    "/commons/channel/",
    "/commons/preferences/mock_shared_prefs.dart",
    "/commons/util/logger.dart",
    "/harmonyos/",
)

OHOS_CONTEXT_PATH_MARKERS = (
    "/feedback/view/post_pic/post_detail_pic.dart",
    "/home/view/map_calendar_page.dart",
)

# Entire files manually audited as intentional OHOS adaptations. Keep this
# list explicit: a new file still needs normal marker-based classification.
CONFIRMED_OHOS_PATHS = frozenset(
    {
        "auth/view/info/unbind_dialogs.dart",
        "auth/view/settings/general_setting_page.dart",
        "auth/view/settings/toolbar_manage_page.dart",
        "auth/view/user/account_upgrade_dialog.dart",
        "auth/view/user/logout_dialog.dart",
        "auth/view/user/user_avatar_image.dart",
        "commons/network/net_check_interceptor.dart",
        "commons/util/log/file_log_output.dart",
        "commons/util/router_manager.dart",
        "commons/util/toast_provider.dart",
        "commons/webview/wby_webview.dart",
        "feedback/feedback_router.dart",
        "feedback/view/lake_home_page/home_page.dart",
        "feedback/view/lake_home_page/lake_notifier.dart",
        "feedback/view/lake_home_page/normal_sub_page.dart",
        "feedback/view/profile_page.dart",
        "feedback/view/reply_detail_page.dart",
        "feedback/view/search_page.dart",
        "home/view/cas_qr_page.dart",
        "home/view/home_page.dart",
        "home/view/web_views/summary_page.dart",
        "lost_and_found/view/lost_and_found_search_page.dart",
        "lost_and_found/view/lost_and_found_search_result_page.dart",
    }
)

CONFIRMED_OHOS_ASSET_PATHS = frozenset(
    {
        "fonts/zh/NotoSansSC-Medium.otf",
        "fonts/zh/NotoSansSC-Medium.ttf",
    }
)
CONFIRMED_OHOS_ASSET_PREFIXES = ("images/app_icons/",)

OHOS_MISSING_PATH_MARKERS = (
    "/home/view/web_views/course_review_page.dart",
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


def asset_files(root: Path) -> dict[str, Path]:
    return {
        path.relative_to(root).as_posix(): path
        for path in root.rglob("*")
        if path.is_file()
    }


def asset_digest(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def is_confirmed_ohos_asset(path: str) -> bool:
    return path in CONFIRMED_OHOS_ASSET_PATHS or any(
        path.startswith(prefix) for prefix in CONFIRMED_OHOS_ASSET_PREFIXES
    )


def compare_assets(original_root: Path, ohos_root: Path) -> tuple[dict, list[Finding]]:
    original_files = asset_files(original_root)
    ohos_files = asset_files(ohos_root)
    findings: list[Finding] = []

    missing = sorted(set(original_files) - set(ohos_files))
    extra = sorted(set(ohos_files) - set(original_files))
    for relative in missing:
        findings.append(
            Finding(
                kind="asset_missing",
                path=relative,
                category=(
                    "OHOS_ADAPTATION"
                    if is_confirmed_ohos_asset(relative)
                    else "REVIEW"
                ),
                diff="asset is missing from the HarmonyOS asset tree",
            )
        )
    for relative in extra:
        findings.append(
            Finding(
                kind="asset_extra",
                path=relative,
                category=(
                    "OHOS_ADAPTATION"
                    if is_confirmed_ohos_asset(relative)
                    else "REVIEW"
                ),
                diff="asset exists only in the HarmonyOS asset tree",
            )
        )

    changed: list[str] = []
    for relative in sorted(set(original_files) & set(ohos_files)):
        original_digest = asset_digest(original_files[relative])
        ohos_digest = asset_digest(ohos_files[relative])
        if original_digest == ohos_digest:
            continue
        changed.append(relative)
        findings.append(
            Finding(
                kind="asset_changed",
                path=relative,
                category=(
                    "OHOS_ADAPTATION"
                    if is_confirmed_ohos_asset(relative)
                    else "REVIEW"
                ),
                diff=(
                    "asset bytes differ: "
                    f"original={original_digest[:12]}, ohos={ohos_digest[:12]}"
                ),
            )
        )

    return (
        {
            "original_assets": len(original_files),
            "ohos_assets": len(ohos_files),
            "equal_assets": len(original_files) - len(missing) - len(changed),
            "changed_assets": len(changed),
            "missing_assets": missing,
            "extra_assets": extra,
        },
        findings,
    )


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


def classify_hunk(hunk: list[str], path: str, ohos_text: str) -> str:
    if path.lstrip("/") in CONFIRMED_OHOS_PATHS:
        return "OHOS_ADAPTATION"
    changed = "\n".join(changed_lines(hunk))
    if has_ohos_marker(changed):
        return "OHOS_ADAPTATION"
    if any(marker in f"/{path}" for marker in OHOS_PATH_MARKERS):
        return "OHOS_ADAPTATION"
    if any(marker in f"/{path}" for marker in OHOS_CONTEXT_PATH_MARKERS):
        return "OHOS_CONTEXT"
    if has_ohos_marker(ohos_text):
        return "OHOS_CONTEXT"
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
                category=classify_hunk(hunk, relative, "\n".join(ohos_lines)),
                diff=format_hunk(hunk),
            )
        )
    return findings


def classify_extra(path: Path, relative: str) -> str:
    if relative in CONFIRMED_OHOS_PATHS:
        return "OHOS_ADAPTATION"
    if any(marker in f"/{relative}" for marker in OHOS_PATH_MARKERS):
        return "OHOS_ADAPTATION"
    try:
        if has_ohos_marker(path.read_text(encoding="utf-8")):
            return "OHOS_ADAPTATION"
    except UnicodeDecodeError:
        pass
    return "REVIEW"


def classify_missing(path: Path, relative: str) -> str:
    if any(marker in f"/{relative}" for marker in OHOS_MISSING_PATH_MARKERS):
        return "OHOS_ADAPTATION"
    try:
        if has_ohos_marker(path.read_text(encoding="utf-8")):
            return "OHOS_CONTEXT"
    except UnicodeDecodeError:
        pass
    return "REVIEW"


def compare_trees(
    original_root: Path,
    ohos_root: Path,
    original_assets: Path | None = None,
    ohos_assets: Path | None = None,
) -> dict:
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
                category=classify_missing(original_files[relative], relative),
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

    if original_assets is None:
        original_assets = original_root.parent / "assets"
    if ohos_assets is None:
        ohos_assets = ohos_root.parent / "assets"
    asset_report = {
        "original_assets": 0,
        "ohos_assets": 0,
        "equal_assets": 0,
        "changed_assets": 0,
        "missing_assets": [],
        "extra_assets": [],
    }
    if original_assets.is_dir() and ohos_assets.is_dir():
        asset_report, asset_findings = compare_assets(original_assets, ohos_assets)
        findings.extend(asset_findings)

    adaptation = [f for f in findings if f["category"] == "OHOS_ADAPTATION"]
    context = [f for f in findings if f["category"] == "OHOS_CONTEXT"]
    review = [f for f in findings if f["category"] == "REVIEW"]
    missing_review = [
        f["path"] for f in findings if f["kind"] == "missing" and f["category"] == "REVIEW"
    ]
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
        "context_findings": len(context),
        "review_findings": len(review),
        "missing_files": missing,
        "missing_review_files": missing_review,
        "extra_files": extra,
        "findings": findings,
        **asset_report,
    }


def print_report(
    report: dict,
    show_adapted: bool,
    show_context: bool,
    show_review: bool,
    show_all: bool,
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
        f"{report['adaptation_findings']} OHOS-specific adaptations, "
        f"{report['context_findings']} hunks in adapted files, "
        f"{report['review_findings']} requiring review"
    )
    print(
        "assets:   "
        f"{report['original_assets']} original, {report['ohos_assets']} OHOS, "
        f"{report['equal_assets']} equal, {report['changed_assets']} changed, "
        f"{len(report['missing_assets'])} missing, {len(report['extra_assets'])} extra"
    )

    if not (show_adapted or show_context or show_review or show_all):
        grouped: dict[str, dict[str, int]] = {}
        for finding in report["findings"]:
            category = finding["category"]
            grouped.setdefault(category, {})[finding["path"]] = (
                grouped.setdefault(category, {}).get(finding["path"], 0) + 1
            )
        for category in ("REVIEW", "OHOS_CONTEXT", "OHOS_ADAPTATION"):
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
            if category == "OHOS_CONTEXT" and not (show_context or show_all):
                continue
            if category == "REVIEW" and not (show_review or show_all):
                continue
            print(f"\n[{category}] {finding['kind']}: {finding['path']}")
            print(finding["diff"])

    if report["review_findings"] == 0 and not report["missing_review_files"]:
        print("\nPASS: every detected difference is classified as OHOS code or adapted-file context.")
    else:
        print("\nFAIL: unclassified differences or missing files require review.")


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    repo = Path(__file__).resolve().parents[1]
    parser.add_argument("--original", type=Path, default=repo / "lib")
    parser.add_argument(
        "--ohos", type=Path, default=repo / "harmonyos" / "wepei_module" / "lib"
    )
    parser.add_argument("--original-assets", type=Path, default=repo / "assets")
    parser.add_argument(
        "--ohos-assets", type=Path, default=repo / "harmonyos" / "wepei_module" / "assets"
    )
    parser.add_argument("--json", action="store_true", help="emit JSON instead of text")
    parser.add_argument(
        "--show-adapted", action="store_true", help="print suspected OHOS adaptation hunks"
    )
    parser.add_argument(
        "--show-context",
        action="store_true",
        help="print generic hunks inside files that contain OHOS code",
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
    original_assets = args.original_assets.resolve()
    ohos_assets = args.ohos_assets.resolve()
    if not original_assets.is_dir():
        parser.error(f"original assets directory does not exist: {original_assets}")
    if not ohos_assets.is_dir():
        parser.error(f"OHOS assets directory does not exist: {ohos_assets}")

    report = compare_trees(original_root, ohos_root, original_assets, ohos_assets)
    if args.json:
        print(json.dumps(report, ensure_ascii=False, indent=2))
    else:
        print_report(
            report,
            args.show_adapted,
            args.show_context,
            args.show_review,
            args.all,
        )

    return 1 if args.strict and (report["review_findings"] or report["missing_review_files"]) else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
