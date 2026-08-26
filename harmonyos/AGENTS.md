# Repository Guidelines — HarmonyOS

## Scope

`harmonyos/` is the HarmonyOS NEXT host for WePeiYang. Flutter Dart and assets are compiled into a HAR, linked by the generated OHOS host, and packaged as a signed HAP.

详细流程、目录说明、适配决策和排障见 [`docs/DEVELOPMENT_GUIDE.md`](docs/DEVELOPMENT_GUIDE.md)。本文只保留必须遵守的规则和命令速查。

## Project Overview

```text
lib/ + assets/
    └─ harmonyos/wepei_module/       # OHOS Dart/assets 镜像
        └─ flutter build har
            └─ .ohos/                # 生成的 OHOS 宿主
                └─ devecocli build
                    └─ entry-default-signed.hap
```

| Path | Responsibility |
| --- | --- |
| `harmonyos/entry/src/main/ets/` | 受控 ArkTS 原生宿主、Ability、MethodChannel |
| `harmonyos/entry/src/main/resources/` | 原生资源、启动页和模块配置 |
| `harmonyos/AppScope/` | 包名、应用名、图标 |
| `harmonyos/wepei_module/lib/` | OHOS Flutter Dart 源码和平台适配 |
| `harmonyos/wepei_module/assets/` | OHOS Flutter 资源 |
| `harmonyos/wepei_module/pubspec.yaml` | OHOS 依赖、资源声明和插件覆盖 |
| `harmonyos/wepei_module/.ohos/` | 生成目录；不可作为源目录编辑 |
| `scripts/sync_ohos_native.py` | 原生源文件 → `.ohos` 同步 |
| `scripts/compare_ohos_flutter.py` | Dart 和 assets 比对 |

## Standard Commands

Linux 当前环境：

```bash
export HOS_SDK_HOME=/home/johnson/.local/share/deveco-clt/sdk
export FLUTTER=/media/johnson/Data/Development/flutter_flutter/bin/flutter
```

完整构建：

```bash
cd /media/johnson/Data/Development/WePeiYang-Flutter/harmonyos/wepei_module
$FLUTTER build har --debug
cd ../..
python3 scripts/sync_ohos_native.py
cd wepei_module/.ohos
devecocli build --build-mode debug
```

部署已有 HAP：

```bash
devecocli device list
devecocli run --skip-build --device <device-serial>
```

HAP 输出：

```text
harmonyos/wepei_module/.ohos/entry/build/default/outputs/default/entry-default-signed.hap
```

Release：

```bash
devecocli build --build-mode release
devecocli run --skip-build --device <device-serial>
```

`devecocli` 是首选入口；不要绕过它直接调用 Hvigor、OHPM 或 HDC 完成构建、安装和启动。

## Synchronization Rules

根目录 `lib/`、`assets/` 是共享实现参考；`wepei_module/lib/`、`wepei_module/assets/` 是独立镜像，不会自动同步。

处理 Android/iOS 侧新提交：

```bash
git show --stat <commit>
git diff <commit>^ <commit> -- lib assets
```

1. 先读原始实现和 OHOS 调用链。
2. 没有平台差异时，按原始仓库同步代码和资源。
3. 根目录原生业务改动要同步到 OHOS 镜像；不要直接覆盖已存在的 OHOS 适配。
4. 修改 ArkTS 只改 `harmonyos/entry/` 或 `harmonyos/AppScope/`，然后运行 `python3 scripts/sync_ohos_native.py`。
5. `.ohos/` 是生成目录，任何手工修改都必须回写到受控源目录。
6. HAR 重新生成后重新检查包名、应用名、图标、签名和启动页。

### 地图·校历

地图·校历的 Dart 和资源必须成组同步：

```text
lib/home/view/map_calendar_page.dart
harmonyos/wepei_module/lib/home/view/map_calendar_page.dart
assets/images/school_map/
harmonyos/wepei_module/assets/images/school_map/
assets/images/calender/
harmonyos/wepei_module/assets/images/calender/
```

更新时同时检查图片索引、`LocalImageViewPageArgs` 参数、缺失资源和 OHOS 独有旧资源。

## Development Rules

1. **原版优先**：能使用原始仓库实现就不要重写。
2. **依赖优先找现成适配**：包未适配 OHOS 时，先查官方替代包、pub.dev、Git 分支、OHOS fork 和项目已有插件覆盖；都不可用时才写自有适配或 MethodChannel。
3. **最小适配**：不为单一实现新增工厂、接口或重复抽象；修共享调用链上的根因。
4. **平台边界**：图片选择/保存使用已有 `ImageSave` MethodChannel；图片显示使用 OHOS `WpyPic`；WebView 使用 `flutter_inappwebview` OHOS fork，不能重新引入 `webview_flutter`。
5. **原生通道不挂起**：每条 ArkTS 路径调用 `success`、`error` 或 `notImplemented`；异步调用必须捕获异常并记录带 TAG 的日志。Dart 侧设置超时并处理 `MissingPluginException`。
6. **内容 URI**：使用 `@ohos.file.fs` 的 `fs.openSync()`，不要用 `fileIo.open()`。
7. **不要误报完成**：没有设备时不能声称部署成功；构建、部署和真机冒烟分别报告。

## Comparison and QA

比较 Dart 和 Flutter assets：

```bash
python3 scripts/compare_ohos_flutter.py
python3 scripts/compare_ohos_flutter.py --show-review
python3 scripts/compare_ohos_flutter.py --strict
PYTHONPATH=scripts python3 scripts/test_compare_ohos_flutter.py
```

脚本按 SHA-256 检查资源的缺失、额外和内容变化。`CONFIRMED_OHOS_PATHS` 及 confirmed asset 规则只记录已经人工确认的适配；新文件和未知差异仍必须进入 review。

最小验证顺序：

```bash
$FLUTTER analyze --no-pub <changed-files>
python3 scripts/compare_ohos_flutter.py --strict
$FLUTTER build har --debug
python3 scripts/sync_ohos_native.py
devecocli build --build-mode debug
devecocli run --skip-build --device <device-serial>
```

真机至少检查启动、登录、图片选择/保存、帖子图片、WebView、地图·校历、主题切换和系统返回键。
