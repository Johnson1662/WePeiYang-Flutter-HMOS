# HarmonyOS 开发向导

本目录是 HarmonyOS NEXT (API 12) 的开发和交接说明。规则速查见上级 [`AGENTS.md`](../AGENTS.md)；构建、同步、适配细节集中在本文。

## 1. 工程结构

```text
Flutter Dart / assets
        │
        │ flutter build har --debug
        ▼
harmonyos/wepei_module/build/ohos/har/debug/*.har
        │
        │ python3 scripts/sync_ohos_native.py
        ▼
harmonyos/wepei_module/.ohos/       # 生成的 OHOS 宿主工程
        │
        │ devecocli build
        ▼
entry-default-signed.hap
```

| 路径 | 用途 |
| --- | --- |
| `harmonyos/entry/src/main/ets/` | 受版本控制的 ArkTS 原生宿主和 MethodChannel |
| `harmonyos/entry/src/main/resources/` | 原生模块资源、启动页和配置 |
| `harmonyos/AppScope/` | 应用名、包名、图标等应用级配置 |
| `harmonyos/wepei_module/lib/` | OHOS Flutter Dart 镜像，包含平台适配 |
| `harmonyos/wepei_module/assets/` | OHOS Flutter 资源镜像 |
| `harmonyos/wepei_module/pubspec.yaml` | OHOS Flutter 依赖、资源和插件覆盖 |
| `harmonyos/wepei_module/.ohos/` | 生成目录，不是原生代码的来源 |
| `scripts/sync_ohos_native.py` | 将受控原生文件同步到 `.ohos` |
| `scripts/compare_ohos_flutter.py` | 比较 Dart 文件和 Flutter assets |

Flutter 负责页面、状态、网络和业务；ArkTS 宿主负责 Ability、系统能力、权限、MethodChannel、启动页和 HAP 签名。

## 2. Linux 环境

当前工作站使用：

- Flutter：`/media/johnson/Data/Development/flutter_flutter/bin/flutter`，OHOS 分支 `oh-3.41.9-dev`
- OHOS SDK：`HOS_SDK_HOME=/home/johnson/.local/share/deveco-clt/sdk`
- CLI：`devecocli`，优先于直接调用 Hvigor、OHPM 或 HDC
- 测试设备：HUAWEI Pura 70 Pro，设备序列号由 `devecocli device list` 返回

命令需要在仓库根目录执行时使用 `python3`；需要在 Flutter 模块执行时使用模块目录作为工作目录。

## 3. 标准构建与部署

### 3.1 修改 Dart 或资源后

```bash
cd /media/johnson/Data/Development/WePeiYang-Flutter/harmonyos/wepei_module
export HOS_SDK_HOME=/home/johnson/.local/share/deveco-clt/sdk
/media/johnson/Data/Development/flutter_flutter/bin/flutter build har --debug

cd ../..
python3 scripts/sync_ohos_native.py

cd wepei_module/.ohos
devecocli build --build-mode debug
```

输出位于：

```text
harmonyos/wepei_module/.ohos/entry/build/default/outputs/default/entry-default-unsigned.hap
harmonyos/wepei_module/.ohos/entry/build/default/outputs/default/entry-default-signed.hap
```

已有 HAP 部署到指定设备：

```bash
devecocli run --skip-build --device <device-serial>
```

检查设备和模拟器：

```bash
devecocli device list
devecocli emulator list
```

### 3.2 修改 ArkTS 原生代码后

原生代码只改受版本控制的目录：

```text
harmonyos/entry/src/main/ets/
harmonyos/entry/src/main/resources/
harmonyos/AppScope/
```

然后重新生成 HAR、同步原生文件，再执行 `devecocli build`。不要直接修改 `.ohos/entry/`；生成过程会覆盖它。

### 3.3 依赖变更

```bash
cd harmonyos/wepei_module
/media/johnson/Data/Development/flutter_flutter/bin/flutter pub get
```

`flutter pub get` 或 `flutter build har` 可能重新生成 `.ohos`。生成后必须运行 `python3 scripts/sync_ohos_native.py`，并重新检查签名、包名、应用名、图标和启动页。

## 4. 从其他系统版本同步新提交

根目录 `lib/` 和 `assets/` 是 Android/iOS 共享代码与资源的参考来源，但 OHOS 镜像不是自动同步的。处理其他系统版本的新提交时：

```bash
git show --stat <commit>
git diff <commit>^ <commit> -- lib assets
```

按以下顺序处理：

1. **先读原始实现和 OHOS 镜像的完整调用链**，不要直接覆盖 OHOS 文件。
2. 没有平台 API 或依赖差异时，按原始仓库代码同步到 `harmonyos/wepei_module/lib/` 和 `harmonyos/wepei_module/assets/`。
3. 原依赖没有 OHOS 实现时，先查 pub.dev、官方仓库、已有 OHOS 分支或项目已有插件覆盖；只有找不到可用实现时才新增 MethodChannel 或最小自有适配。
4. 保留必要的 OHOS 差异：文件系统、图片选择、WebView、缓存、字体、分享、权限和系统窗口行为。
5. 运行 Dart/assets 比对；只有人工确认后的差异才能加入比较脚本的 confirmed allowlist。
6. 修改原生能力时，改 `harmonyos/entry/`，再同步到 `.ohos`，不要把生成目录当作源目录。

### 地图·校历同步规则

地图和校历需要同时检查 Dart 调用和资源文件：

```text
lib/home/view/map_calendar_page.dart
harmonyos/wepei_module/lib/home/view/map_calendar_page.dart
assets/images/school_map/
harmonyos/wepei_module/assets/images/school_map/
assets/images/calender/
harmonyos/wepei_module/assets/images/calender/
```

根目录更新地图或校历时：

- 同步对应资源文件到 OHOS assets；
- 对照两个版本的 `LocalImageViewPageArgs` 参数和图片索引，不要盲目覆盖 OHOS 调用；
- 删除或确认 OHOS 独有的旧地图资源；
- 运行 `python3 scripts/compare_ohos_flutter.py --show-review`，检查缺失、额外和内容不同的资源。

## 5. 适配决策规范

### 5.1 代码优先级

1. 能直接使用原始仓库实现，就使用原始实现。
2. 依赖不支持 OHOS 时，先寻找已有 OHOS 适配包、官方替代包、Git 分支或本项目已有桥接。
3. 确实没有可用包时，写最小的 OHOS 原生适配，不新增只有一个实现的抽象层。
4. 修复共享调用链上的根因，不在每个调用方重复打补丁。

### 5.2 常见 OHOS 适配

| 能力 | OHOS 实现 |
| --- | --- |
| 图片选择 | `ImageSave.pickImagesFromGallery()` → `saveImg` MethodChannel → `PhotoViewPicker` |
| 保存图片 | `ImageSave.saveImageFromBytes()` / `saveToAlbum()` → `showAssetsCreationDialog` |
| 图片加载 | `WpyPic` 的 OHOS `HttpClient`、内存缓存和证书回调 |
| 本地偏好 | `MockSharedPreferences` 文件后端 |
| WebView | `flutter_inappwebview` OHOS fork；OHOS 模块不使用 `webview_flutter` |
| 动态字体 | `font_loader.dart` 从 assets 或网络加载 OHOS 可用字体格式 |
| 分享、推送、系统能力 | 优先使用已有 MethodChannel；未实现能力必须捕获异常并给出可接受的失败结果 |

### 5.3 原生 MethodChannel 约束

- 每条路径都必须调用 `result.success()`、`result.error()` 或 `result.notImplemented()`；不能让 Dart 调用永久等待。
- 原生异步 API 必须 `try/catch`，记录带 TAG 的日志，并返回明确的失败值。
- 内容 URI 使用 `@ohos.file.fs` 的 `fs.openSync()`，不要用 `fileIo.open()`。
- 图片选择使用 `PhotoViewPicker`；相册保存使用系统 `showAssetsCreationDialog`，不要重复申请系统弹窗已经处理的权限。
- Dart 侧 MethodChannel 调用设置超时并捕获 `MissingPluginException` 等平台异常。

## 6. WebView 规则

OHOS 模块中统一使用 `flutter_inappwebview` 的 OHOS fork，覆盖配置如下：

```yaml
dependency_overrides:
  flutter_inappwebview:
    git:
      url: https://gitcode.com/CPF-Flutter/flutter_inappwebview.git
      path: flutter_inappwebview
      ref: br_v6.1.5_ohos
```

- 普通页面复用 `commons/widgets/webview_page.dart`。
- 带远程配置和 JS 通道的页面使用 `commons/webview/wby_webview.dart`。
- `WbyShareChannel` 和 `WbyImgSaveChannel` 必须与页面配置一起维护。
- 旧页面的 `window.<channel>.postMessage` 由适配层桥接到 `callHandler`。
- 不要重新引入 `webview_flutter`；它在 OHOS 模块没有可用实现。

## 7. 比对脚本

默认同时比较：

- `lib/**/*.dart` 与 `harmonyos/wepei_module/lib/**/*.dart`；
- `assets/**/*` 与 `harmonyos/wepei_module/assets/**/*`；
- Dart 按统一 diff 和 OHOS marker 分类；资源按 SHA-256 检查缺失、额外和字节变化。

```bash
# 查看分类摘要
python3 scripts/compare_ohos_flutter.py

# 输出仍需人工处理的 Dart 或资源差异
python3 scripts/compare_ohos_flutter.py --show-review

# 作为同步门禁；有未分类差异时返回 1
python3 scripts/compare_ohos_flutter.py --strict

# 回归测试
PYTHONPATH=scripts python3 scripts/test_compare_ohos_flutter.py
```

`scripts/compare_ohos_flutter.py` 中的 `CONFIRMED_OHOS_PATHS` 和 confirmed asset 规则只允许记录已人工审查的适配。新文件、新资源和未知差异不能因为“同目录”自动跳过。

## 8. 验证与常见问题

### 最小验证集

```bash
# 受影响 Dart 文件
/media/johnson/Data/Development/flutter_flutter/bin/flutter analyze --no-pub <files...>

# 比对与测试
PYTHONPATH=scripts python3 scripts/test_compare_ohos_flutter.py
python3 scripts/compare_ohos_flutter.py --strict

# 最终产物
/media/johnson/Data/Development/flutter_flutter/bin/flutter build har --debug
python3 scripts/sync_ohos_native.py
cd harmonyos/wepei_module/.ohos
devecocli build --build-mode debug
```

真机验证至少覆盖：启动、登录、图片选择、图片保存、帖子/评论图片、WebView 页面、地图·校历、主题切换和系统返回键。

### 常见问题

- **HAP 不是最新代码**：确认先构建 HAR，再运行 `sync_ohos_native.py`，最后执行 `devecocli build`。
- **原生修改消失**：修改了 `.ohos`；把修改移回 `harmonyos/entry/` 后重新同步。
- **应用名或图标恢复默认**：检查 `.ohos/AppScope/` 是否被重新生成，并从受控的 `harmonyos/AppScope/` 同步。
- **签名失败**：检查 `bundleName` 与本机签名 profile 是否匹配；签名材料不要提交到仓库。
- **设备不可用**：先执行 `devecocli device list`；没有设备时不能声称部署成功。
- **asset 比对出现额外地图文件**：先确认是否仍被 Dart 引用；无引用的旧资源应删除，而不是加入 confirmed allowlist。
