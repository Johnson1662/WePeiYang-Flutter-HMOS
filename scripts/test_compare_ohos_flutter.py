#!/usr/bin/env python3
"""Small regression checks for OHOS comparator classification."""

from pathlib import Path
from tempfile import TemporaryDirectory

from compare_ohos_flutter import classify_hunk, compare_assets


def hunk(line: str) -> list[str]:
    return ["@@", line]


def main() -> None:
    assert classify_hunk(
        hunk("+import 'image_save.dart';"), "feature.dart", ""
    ) == "OHOS_ADAPTATION"
    assert classify_hunk(
        hunk("+import 'webview_page.dart';"), "feature.dart", ""
    ) == "OHOS_ADAPTATION"
    assert classify_hunk(
        hunk("+final path = Directory.systemTemp;"), "feature.dart", ""
    ) == "OHOS_ADAPTATION"
    assert classify_hunk(
        hunk("+import 'package:flutter_native_image/flutter_native_image.dart';"),
        "feature.dart",
        "",
    ) == "OHOS_ADAPTATION"
    assert classify_hunk(
        hunk("+final adapter = IOHttpClientAdapter();"),
        "feature.dart",
        "",
    ) == "OHOS_ADAPTATION"
    assert classify_hunk(
        hunk("+final label = 'updated';"),
        "feature.dart",
        "final path = ImageSave.takePhoto();",
    ) == "OHOS_CONTEXT"
    assert classify_hunk(
        hunk("+final label = 'updated';"), "feature.dart", ""
    ) == "REVIEW"
    assert classify_hunk(
        hunk("+final label = 'updated';"),
        "auth/view/settings/general_setting_page.dart",
        "",
    ) == "OHOS_ADAPTATION"

    with TemporaryDirectory() as directory:
        root = Path(directory)
        original = root / "original"
        ohos = root / "ohos"
        (original / "images/app_icons").mkdir(parents=True)
        ohos.mkdir()
        (original / "images/app_icons/ic_launcher.png").write_bytes(b"android")
        (original / "shared.txt").write_bytes(b"same")
        (original / "changed.txt").write_bytes(b"original")
        (ohos / "shared.txt").write_bytes(b"same")
        (ohos / "changed.txt").write_bytes(b"ohos")
        (ohos / "extra.txt").write_bytes(b"ohos")

        summary, findings = compare_assets(original, ohos)
        assert summary["equal_assets"] == 1
        assert summary["changed_assets"] == 1
        assert summary["missing_assets"] == ["images/app_icons/ic_launcher.png"]
        assert summary["extra_assets"] == ["extra.txt"]
        assert findings[0]["category"] == "OHOS_ADAPTATION"
        assert findings[1]["category"] == "REVIEW"
        assert findings[2]["kind"] == "asset_changed"


if __name__ == "__main__":
    main()
    print("comparator checks passed")
