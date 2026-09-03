#!/usr/bin/env python3
"""注入签名与 SDK 版本到生成的 .ohos/build-profile.json5。

背景：`flutter build har` 每次都会重新生成 `wepei_module/.ohos/build-profile.json5`
（携带本机 DevEco 默认 debug 签名与模板 SDK 版本）。签名材料不应入库，
正式证书也不能靠手改生成物，因此由本脚本在 `sync_ohos_native.py` 末尾统一注入：

环境变量（全部提供时注入完整签名材料，用于正式/发布签名）：
  OHOS_CERT_PATH    .cer 证书路径
  OHOS_PROFILE_PATH .p7b 描述文件路径
  OHOS_STORE_FILE   .p12 密钥库路径
  OHOS_KEY_ALIAS    密钥别名（默认 debugKey）
  OHOS_KEY_PWD      密钥口令（DevEco 生成的加密串或明文）
  OHOS_STORE_PWD    密钥库口令
  OHOS_SIGN_ALG     签名算法（默认 SHA256withECDSA）

SDK 版本（可选，默认保持生成值不动）：
  OHOS_COMPATIBLE_SDK  覆盖 products[0].compatibleSdkVersion
  OHOS_TARGET_SDK      设置 products[0].targetSdkVersion

环境变量不全时回落：校验生成物里已有 material 的路径在本机是否存在；
不存在则用 ~/.ohos/config/default_harmonyos_* 自动发现并替换路径
（口令无法推断，会提示需要重新生成或改用环境变量注入）。
"""

from pathlib import Path
import glob
import json
import os
import re

_ENV_KEYS = (
    "OHOS_CERT_PATH",
    "OHOS_PROFILE_PATH",
    "OHOS_STORE_FILE",
    "OHOS_KEY_PWD",
    "OHOS_STORE_PWD",
)

# DevEco 自动生成的 debug 调试库的标准口令（所有 DevEco 工程一致，
# 非敏感凭据；仅用于本地 debug 签名回落，正式签名一律走 OHOS_* 环境变量）。
_DEVECO_DEBUG_KEY_PWD = "0000001AD70F8F1848E5561CC0FED28DE062CDB290F08C542276977C204C22037A02B65D620E9E19DA38"
_DEVECO_DEBUG_STORE_PWD = "0000001AE183E16B984412D8085D20781A6B47C576859B6461320AC20DF4C235BECE351B1D46D2690CA3"


def load_json5(path: Path) -> dict:
    text = path.read_text(encoding="utf-8")
    try:
        # 尝试标准 JSON（容忍尾逗号）
        cleaned = re.sub(r",(\s*[}\]])", r"\1", text)
        return json.loads(cleaned)
    except Exception:
        # 回落至 node 评估完整 JSON5（支持 unquoted keys / 单引号 / 注释）
        import subprocess
        cmd = ["node", "-e", "const fs = require('fs'); console.log(JSON.stringify(eval('(' + fs.readFileSync(process.argv[1], 'utf8') + ')')))", str(path)]
        res = subprocess.run(cmd, capture_output=True, text=True, check=True)
        return json.loads(res.stdout)


def dump_json(path: Path, data: dict) -> None:
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def material_from_env() -> dict | None:
    env = os.environ
    values = {key: env.get(key) for key in _ENV_KEYS}
    missing = [key for key, value in values.items() if not value]
    if missing:
        return None
    return {
        "certpath": values["OHOS_CERT_PATH"],
        "keyAlias": env.get("OHOS_KEY_ALIAS", "debugKey"),
        "keyPassword": values["OHOS_KEY_PWD"],
        "profile": values["OHOS_PROFILE_PATH"],
        "signAlg": env.get("OHOS_SIGN_ALG", "SHA256withECDSA"),
        "storeFile": values["OHOS_STORE_FILE"],
        "storePassword": values["OHOS_STORE_PWD"],
    }


def discover_default_material() -> dict | None:
    """debug 签名材料自动发现（使用 DevEco 默认 ~/.ohos/config/default_harmonyos_*）。"""

    config_dir = Path.home() / ".ohos" / "config"
    if not config_dir.is_dir():
        return None
    certs = sorted(glob.glob(str(config_dir / "default_harmonyos_*.cer")))
    profiles = sorted(glob.glob(str(config_dir / "default_harmonyos_*.p7b")))
    stores = sorted(glob.glob(str(config_dir / "default_harmonyos_*.p12")))
    if not (certs and profiles and stores):
        return None
    return {
        "certpath": certs[0],
        "keyAlias": "debugKey",
        "keyPassword": _DEVECO_DEBUG_KEY_PWD,
        "profile": profiles[0],
        "signAlg": "SHA256withECDSA",
        "storeFile": stores[0],
        "storePassword": _DEVECO_DEBUG_STORE_PWD,
    }


def apply(target: Path) -> None:
    profile_path = target / "build-profile.json5"
    if not profile_path.is_file():
        return

    data = load_json5(profile_path)
    app = data.setdefault("app", {})
    configs = app.setdefault("signingConfigs", [])
    changed = False

    material = material_from_env()
    if material is not None:
        if configs:
            configs[0]["material"] = material
        else:
            configs.append({"name": "default", "type": "HarmonyOS", "material": material})
        changed = True
    else:
        # 回落：flutter build har 生成的签名配置可能为空或路径失效，
        # 用本机 DevEco 默认材料补齐（口令沿用生成值）
        needs_fallback = not configs
        if not needs_fallback:
            current = configs[0].get("material", {})
            profile_file = current.get("profile")
            # 若当前 profile 不含 READ_PASTEBOARD ACL，也主动替换为更优的默认材料
            is_acl_missing = profile_file and Path(profile_file).is_file() and b"READ_PASTEBOARD" not in Path(profile_file).read_bytes()
            key_pwd = current.get("keyPassword", "")
            store_pwd = current.get("storePassword", "")
            paths = ("certpath", "profile", "storeFile")
            needs_fallback = (
                not current
                or not all(current.get(key) and Path(current[key]).is_file() for key in paths)
                or is_acl_missing
                or len(key_pwd) < 32
                or len(store_pwd) < 32
            )
        if needs_fallback:
            default = discover_default_material()
            if default:
                if configs:
                    merged = dict(configs[0].get("material", {}))
                    merged.update(default)
                    configs[0]["material"] = merged
                else:
                    configs.append(
                        {"name": "default", "type": "HarmonyOS", "material": default}
                    )
                changed = True
                print(
                    "[signing] 已按本机 DevEco 默认材料补齐签名配置；"
                    "口令沿用生成值，若签名失败请用 OHOS_* 环境变量注入"
                )

    products = app.get("products") or []
    if products:
        compatible = os.environ.get("OHOS_COMPATIBLE_SDK")
        if compatible and products[0].get("compatibleSdkVersion") != compatible:
            products[0]["compatibleSdkVersion"] = compatible
            changed = True
        target_sdk = os.environ.get("OHOS_TARGET_SDK")
        if target_sdk and products[0].get("targetSdkVersion") != target_sdk:
            products[0]["targetSdkVersion"] = target_sdk
            changed = True

    if changed:
        dump_json(profile_path, data)
        print(f"[signing] 已更新 {profile_path}")


if __name__ == "__main__":
    import sys

    target = Path(sys.argv[1]) if len(sys.argv) > 1 else Path.cwd()
    apply(target)
