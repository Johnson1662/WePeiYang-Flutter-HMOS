#!/usr/bin/env python3
"""使用已授权 READ_PASTEBOARD ACL 的 HoKit 证书材料对 HAP 签名。"""

from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
HOKIT_DIR = Path.home() / ".config" / "ho-kit" / "sign"
SIGN_TOOL = HOKIT_DIR / "tools" / "hap-sign-tool.jar"
P12_FILE = HOKIT_DIR / "tools" / "ho-kit.p12"
CER_FILE = HOKIT_DIR / "certs" / "hokit_debug_2025025987451876928_20270825.cer"
P7B_FILE = HOKIT_DIR / "provisions" / "com.weipeiyang.cn_2025025987451876928_45323450.p7b"

DEFAULT_IN_HAP = (
    ROOT
    / "harmonyos"
    / "wepei_module"
    / ".ohos"
    / "entry"
    / "build"
    / "default"
    / "outputs"
    / "default"
    / "entry-default-unsigned.hap"
)
DEFAULT_OUT_HAP = (
    ROOT
    / "harmonyos"
    / "wepei_module"
    / ".ohos"
    / "entry"
    / "build"
    / "default"
    / "outputs"
    / "default"
    / "entry-default-signed.hap"
)


def sign(in_hap: Path = DEFAULT_IN_HAP, out_hap: Path = DEFAULT_OUT_HAP) -> None:
    if not in_hap.is_file():
        raise SystemExit(f"输入 HAP 文件不存在: {in_hap}")
    for f in (SIGN_TOOL, P12_FILE, CER_FILE, P7B_FILE):
        if not f.is_file():
            raise SystemExit(f"签名依赖材料缺失: {f}")

    cmd = [
        "java",
        "-jar",
        str(SIGN_TOOL),
        "sign-app",
        "-mode",
        "localSign",
        "-keyAlias",
        "hokit",
        "-keyPwd",
        "hokit9527",
        "-keystorePwd",
        "hokit9527",
        "-appCertFile",
        str(CER_FILE),
        "-profileFile",
        str(P7B_FILE),
        "-profileSigned",
        "1",
        "-inFile",
        str(in_hap),
        "-signAlg",
        "SHA256withECDSA",
        "-keystoreFile",
        str(P12_FILE),
        "-outFile",
        str(out_hap),
        "-signCode",
        "1",
    ]
    res = subprocess.run(cmd, check=True)
    print(f"\n[sign] 签名成功（含 READ_PASTEBOARD ACL 权限）-> {out_hap}")


if __name__ == "__main__":
    in_path = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_IN_HAP
    out_path = Path(sys.argv[2]) if len(sys.argv) > 2 else DEFAULT_OUT_HAP
    sign(in_path, out_path)
