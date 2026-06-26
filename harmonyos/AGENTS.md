# Repository Guidelines — HarmonyOS

## Project Overview

The `harmonyos/` directory contains the HarmonyOS NEXT (API 12) native build infrastructure for the WePeiYang Flutter app. It integrates the Flutter engine via `FlutterAbility`, provides OHOS-native MethodChannel handlers for image saving/picking, and houses the `devecocli`/`hvigor` build pipeline that produces the signed HAP package for deployment.

The project uses a Flutter module (`wepei_module/`) that Flutter compiles into a HAR, which the OHOS entry module links as a local dependency. Source files live under `harmonyos/entry/src/main/ets/` and must be manually synced to `.ohos/entry/` when the build directory is regenerated.

---

## Architecture & Data Flow

```
harmonyos/entry/src/main/ets/
  entryability/EntryAbility.ets    ← FlutterAbility subclass + SaveImgHandler
  pages/Index.ets                  ← FlutterPage host (legacy PickerDialog)
  plugins/                         ← GeneratedPluginRegistrant, ImagePickerPlugin (unused)

DataSource:
  Flutter MethodChannel('com.twt.service/saveImg')
    → SaveImgHandler.onMethodCall()
      ├─ 'savePictureToAlbum'  → showAssetsCreationDialog() → system album
      └─ 'pickImages'          → PhotoViewPicker.select() → cacheDir/picker_temp/
```

**Data flow:** Flutter → MethodChannel invoke → OHOS SaveImgHandler → System API → file URI → Flutter receives path list

---

## Key Directories

| Path | Purpose |
|------|---------|
| `harmonyos/entry/src/main/ets/entryability/` | EntryAbility (FlutterAbility + SaveImgHandler) |
| `harmonyos/entry/src/main/ets/pages/` | Index (FlutterPage host), PickerPage, FlutterPage |
| `harmonyos/entry/src/main/ets/plugins/` | ImagePickerPlugin (unused) |
| `harmonyos/entry/src/main/resources/` | Module resources (icons, strings, profiles, media) |
| `harmonyos/entry/src/test/` | Hypium unit tests |
| `harmonyos/entry/src/ohosTest/` | Hypium instrument tests |
| `harmonyos/AppScope/` | App-level resources (bundleName, icon, app_name) |
| `harmonyos/wepei_module/` | Flutter module (standalone pubspec, lib copy, assets) |
| `harmonyos/wepei_module/.ohos/` | Build directory (hvigor working dir) |
| `harmonyos/wepei_module/.ohos/entry/` | HAP entry module (build copy of harmonyos/entry/) |
| `harmonyos/wepei_module/.ohos/flutter_module/` | Flutter engine integration module |
| `harmonyos/wepei_module/.ohos/hvigor/` | Hvigor config (daemon, parallel, optimization) |
| `harmonyos/wepei_module/.ohos/oh_modules/` | OHPM resolved packages |
| `harmonyos/hvigor/` | Root hvigor config |
| `harmonyos/.hvigor/` | Hvigor cache/outputs |

---

## Development Commands

### Build & Deploy

```bash
# Full build + install + launch (debug, ~60s)
cd harmonyos\wepei_module\.ohos
$env:PUB_CACHE = "D:\pub-cache"
devecocli run

# Deploy existing HAP without rebuild (~20s)
devecocli run --skip-build

# Release build (~2m20s)
devecocli build --build-mode release
devecocli run --skip-build

# Build only (no install)
devecocli build

# Clean build
devecocli build clean
```

### Device Management

```bash
# Connect device (wireless)
"D:\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe" tconn 192.168.137.159:46715

# List devices
hdc list targets

# Install HAP
hdc -t <serial> install -r <path/to/unsigned.hap>

# View logs (filter by tag)
hdc shell "hilog -x | grep -E 'EntryAbility|ImageSave'"
```

### Flutter Module

```bash
# Build Flutter HAR for OHOS
cd harmonyos\wepei_module
flutter build har --debug

# Resolve Dart dependencies
cd harmonyos\wepei_module
flutter pub get
```

---

## Code Conventions & Common Patterns

### MethodChannel Handlers

All OHOS-native handlers follow the same pattern:

```typescript
class SaveImgHandler implements MethodCallHandler {
  private context: common.UIAbilityContext;

  onMethodCall(call: MethodCall, result: MethodResult): void {
    switch (call.method) {
      case 'methodName':
        this.methodName(result);
        break;
      default:
        result.notImplemented();
    }
  }

  private async methodName(result: MethodResult) {
    try {
      // ... native API calls ...
      result.success(returnValue);
    } catch (e) {
      console.warn(TAG, 'failed: ' + JSON.stringify(e));
      result.success(fallbackValue);  // never let the caller hang
    }
  }
}
```

Key rules:
- **Always call `result.success()` or `result.error()`** in every path — never leave the caller hanging
- **Wrap in try-catch** and return a fallback/default value on failure
- **Log with `TAG` prefix** for easy log filtering
- **`console.info`** for trace, **`console.warn`** for recoverable errors, **`console.error`** for unrecoverable

### PhotoViewPicker (image picking)

```typescript
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import fs from '@ohos.file.fs';

const photoPicker = new photoAccessHelper.PhotoViewPicker();
const options = new photoAccessHelper.PhotoSelectOptions();
options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
options.maxSelectNumber = 3;
const res = await photoPicker.select(options);
// res.photoUris are file:// content URIs → open with fs.openSync(uri)
const srcFile = fs.openSync(res.photoUris[0]);
```

Note: Do NOT use `fileIo.open()` for content URIs — use `fs.openSync()` from `@ohos.file.fs`.

### showAssetsCreationDialog (save to album)

```typescript
import { photoAccessHelper } from '@kit.MediaLibraryKit';

const helper = photoAccessHelper.getPhotoAccessHelper(this.context);
const desFileUris = await helper.showAssetsCreationDialog(
  [srcFileUri],
  [{ title, fileNameExtension, photoType: PhotoType.IMAGE, subtype: PhotoSubtype.DEFAULT }]
);
// Copy content from source to destination
```

No `ohos.permission.READ_IMAGEVIDEO` or `ohos.permission.WRITE_IMAGEVIDEO` required — the system dialog handles permissions internally.

### Plugin Registration

Flutter OHOS plugins are registered in `GeneratedPluginRegistrant.ets`:

```typescript
import PhotoManagerPlugin from 'photo_manager';

export class GeneratedPluginRegistrant {
  static registerWith(flutterEngine: FlutterEngine) {
    flutterEngine.getPlugins()?.add(new PhotoManagerPlugin());
  }
}
```

Only `photo_manager` is currently registered. Do NOT add `image_picker_ohos` — its ohpm dependency chain (`file:libs/flutter.har`) fails to resolve in the current build setup.

### FlutterAbility Lifecycle

```typescript
export default class EntryAbility extends FlutterAbility {
  configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine);
    GeneratedPluginRegistrant.registerWith(flutterEngine);
    // Register custom MethodChannels here
    const channel = new MethodChannel(
      flutterEngine.getDartExecutor(),
      'com.twt.service/saveImg',
      StandardMethodCodec.INSTANCE
    );
    channel.setMethodCallHandler(new SaveImgHandler(this.context));
  }
}
```

### File Synchronization

When `.ohos/` is regenerated by `flutter pub get`, source files must be manually synced:

```bash
cp harmonyos/entry/src/main/ets/entryability/EntryAbility.ets \
   harmonyos/wepei_module/.ohos/entry/src/main/ets/entryability/EntryAbility.ets
```

---

## Important Files

| File | Role |
|------|------|
| `entry/src/main/ets/entryability/EntryAbility.ets` | Main OHOS entry — FlutterAbility + SaveImgHandler |
| `entry/src/main/ets/pages/Index.ets` | FlutterPage host (legacy PickerDialog) |
| `entry/src/main/ets/plugins/ImagePickerPlugin.ets` | Custom FlutterPlugin (UNUSED — use SaveImgHandler instead) |
| `entry/src/main/module.json5` | Module config (abilities, permissions, deviceTypes) |
| `entry/src/main/resources/base/profile/main_pages.json` | Page routes (Index → FlutterPage) |
| `entry/build-profile.json5` | Entry module build config |
| `AppScope/app.json5` | App-level bundleName, icon, version |
| `AppScope/resources/base/element/string.json` | app_name ("微北洋") |
| `wepei_module/.ohos/build-profile.json5` | Signing config + product config |
| `wepei_module/.ohos/AppScope/app.json5` | Build copy of AppScope (bundleName, icon) |
| `wepei_module/.ohos/hvigor/hvigor-config.json5` | Build optimization settings |
| `wepei_module/.ohos/flutter_module/src/main/ets/plugins/GeneratedPluginRegistrant.ets` | Auto-generated plugin registrant |
| `wepei_module/pubspec.yaml` | Flutter dependencies + dependency_overrides |
| `wepei_module/lib/` | Flutter module Dart source (copy of root lib/) |
| `build-profile.json5` | Root OHOS project signing profile |
| `oh-package.json5` | Root OHPM dependencies |

---

## Runtime/Tooling Preferences

- **Flutter SDK:** `D:\Development\flutter_flutter` (branch `oh-3.41.9-dev`, Flutter 3.41.10)
- **Dart SDK:** ^3.6.2 (wepei_module)
- **DevEco Studio:** `D:\DevEco\Studio`
- **Hvigor/OHPM Node:** `D:\DevEco Studio\tools\node\node.exe`
- **Hvigor CLI:** `D:\DevEco Studio\tools\hvigor\bin\hvigorw.js`
- **OHPM CLI:** `D:\DevEco Studio\tools\ohpm\bin\pm-cli.js`
- **HDC:** `D:\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe`
- **SDK:** `D:\DevEco Studio\sdk\default\`
- **PUB_CACHE:** `D:\pub-cache` (set manually; avoids Windows cross-drive relative path issues)
- **Node_modules (flutter-hvigor-plugin):** Manually linked from SDK's `packages/flutter_tools/hvigor/`
- **Signing certs:** `C:\Users\lneoo\.ohos\config\default_harmonyos_*.p12`
- **Device:** HUAWEI Pura 70 Pro, wireless at `192.168.137.159:46715`
- **OHPM registry:** `https://ohpm.openharmony.cn/ohpm/` (frequent 502 errors — `@ohos/hypium` removed to avoid)
- **Proxy:** `HTTP_PROXY=127.0.0.1:7890`, `HTTPS_PROXY=127.0.0.1:7890`
- **Java:** JDK 21.0.10 at `D:\Program Files\Java\jdk-21.0.10`
- **Hvigor daemon:** Ports 45000-45099 (currently disabled due to TIME_WAIT saturation)
- **Preferred CLI:** `devecocli` over invoking `hvigorw`, `ohpm`, or `hdc` directly

### Build Mode Signing

Current setup uses `devecocli run` which auto-signs with DevEco Studio's debug certificate. Release builds with `--build-mode release` use the same signing config (`signingConfigs` in `build-profile.json5`).

---

## Testing & QA

- **Hypium unit tests:** `entry/src/test/LocalUnit.test.ets` (basic `describe/it/expect`)
- **Hypium instrument tests:** `entry/src/ohosTest/ets/test/Ability.test.ets`
- **Flutter module smoke test:** `wepei_module/test/widget_test.dart`
- **Linting:** ArkTS compiler built-in (warns about `arkts-no-any-unknown`, `arkts-no-classes-as-obj`, deprecated APIs)
- **QA flow:** Manual — build + deploy + test on physical device (Pura 70 Pro)
- **Log verification:** `hilog -x | grep EntryAbility` to trace native handler calls
- **No CI/CD:** All builds are manual via `devecocli` CLI

---

## OHOS-Specific UI Differences

### Login Screen

The OHOS login page (`harmonyos/wepei_module/lib/auth/view/login/login_page.dart`) has **intentional differences** from the root Android/iOS version (`lib/auth/view/login/login_page.dart`):

| Aspect | Android/iOS (root lib/) | OHOS (wepei_module/lib/) |
|--------|------------------------|--------------------------|
| Privacy dialog | Full `PrivacyDialog` with markdown loading + `showDialog` | **Removed entirely** — OHOS skips the native privacy consent flow |
| Umeng init | Called after privacy agreement | Called directly in `addPostFrameCallback` with `.catchError((_) {})` |
| Import prefix | `package:we_pei_yang_flutter/...` | `package:wepei_module/...` |

The login widget itself (`LoginHomeWidget` → build method) is **structurally identical** — same gradient background, same Welcome/微北洋 text, same 登录/注册 buttons, same hint text. Visual differences perceived by the user likely stem from:

- **Font rendering:** OHOS Flutter engine renders NotoSansSC differently than Android Skia/Impeller
- **Status bar / system UI chrome:** OHOS handles `SystemUiOverlayStyle` differently (navigation bar color, status bar icons)
- **Gradient rendering:** OHOS may render the `primaryGradientAllScreen` gradient with subtle color shifts
- **No privacy dialog on first launch:** OHOS skips the full-screen privacy consent dialog, making the first-launch experience appear different
- **Login loading indicator:** OHOS `login_pw_page.dart` had no "登录中" loading indicator (root version used `ToastProvider.running` in schedule refresh, but login path had none either). Added `ToastProvider.running("登录中...")` before login request + `ToastProvider.cancelCurrent()` in success/failure — matches the course schedule's `ToastProvider.running("刷新数据中……")` style
- **Login button style:** OHOS `login_pw_page.dart` used bare `TextButton`/`ElevatedButton` for the login buttons. Changed to `ElevatedButton` with `borderRadius: 24`, elevation 0, white background — matching the welcome page (`LoginHomeWidget`) button style. Both password login and SMS login buttons updated.

### Other OHOS-Specific Code Divergences (wepei_module/lib vs root lib/)

| File | Difference |
|------|-----------|
| `login/login_page.dart` | Privacy dialog removed, Umeng init catchError'd |
| `main.dart` | OHOS version at `wepei_module/lib/main.dart` may differ from root — check init order, provider list, splash handling |

The `wepei_module/lib/` directory was created as an **independent copy** of `lib/` for the OHOS Flutter module build. Changes made to the root `lib/` must be **manually synced** to `wepei_module/lib/`. Currently only `login_page.dart` and `image_save.dart` are known to diverge.

### Platform Feature Affecting Login/Auth

| Feature | Android/iOS | OHOS | File |
|---------|------------|------|------|
| Push init | `initGeTuiSdk()` via MethodChannel | `catchError` guards (channel not implemented) | `push_manager.dart:77` |
| Umeng stats | `initCommon()` via MethodChannel | Silent catch (no-op) | `umeng_statistics.dart:12` |
| High refresh rate | `FlutterDisplayMode.setHighRefreshRate()` | Guarded by `Platform.isAndroid` only | `main.dart:64` |
| Window manager | Desktop-only (`Platform.isWindows`) | Not called | `main.dart:70-101` |

### Image Loading (`lib/commons/widgets/wpy_pic.dart:260-271`)

```dart
// CachedNetworkImage depends on path_provider → MissingPluginException on OHOS
if (widget.withCache && (Platform.isAndroid || Platform.isIOS)) {
  return Container(child: cachedNetwork);
}
// OHOS: TWT API certificates not trusted by system — use HttpClient with SSL bypass
if (!Platform.isAndroid && !Platform.isIOS) {
  return Container(child: _ohosNetwork);
}
return Container(child: network);
```

**Three-way branching:**
- **Android/iOS:** `CachedNetworkImage` with disk cache (requires `path_provider`)
- **OHOS:** Raw `HttpClient` with `badCertificateCallback: (_, _, _) => true` + in-memory `static Map<String, Uint8List>` cache — avoids `MissingPluginException` from `path_provider` and bypasses untrusted TWT API SSL certs
- **Fallback:** Plain `Image.network` (no cache)

### Splash Screen & Startup

- **OHOS FlutterPage** uses `WhiteSplash` (a white background overlay) to cover the Flutter engine's pink background during initial engine load
- **EntryAbility** extends `FlutterAbility` which auto-manages the Flutter engine lifecycle — no custom splash widget in Dart code for OHOS
- **Release mode** removes the "Flutter" debug banner and loading animation automatically

### Platform Feature Gaps

| Feature | Android/iOS | OHOS workaround |
|---------|------------|----------------|
| `path_provider` | Full support | Replaced with `Directory.systemTemp` in image_cache_service, storage_util (committed code) |
| `shared_preferences` | Full support | `MockSharedPreferences` file-backed fallback for OHOS |
| `webview_flutter` | Full support | No OHOS plugin; WbyWebView guarded by `Platform.isAndroid` for SurfaceAndroidWebView only |
| `permission_handler` | Full support | MethodChannel calls wrapped in `.catchError()` (graceful degradation) |
| `url_launcher` | Full support | No OHOS plugin; calls guarded by `.catchError()` |
| `connectivity_plus` | Full support | No OHOS plugin; NetStatusListener may not fire |
| `share_plus` | Full support | No OHOS plugin; share calls silently fail |
| `image_picker` | Full support | Custom `SaveImgHandler.pickImages()` → `PhotoViewPicker.select()` |
| `gallery_saver` | Full support | Custom `SaveImgHandler.saveToAlbum()` → `showAssetsCreationDialog()` |
| `device_info_plus` | Full support | Debug info page uses fallback strings |
| `window_manager` | Desktop only | Not available on OHOS; guarded by `Platform.isWindows` |
| `flutter_displaymode` | Android only | Guarded by `Platform.isAndroid` |
| `fluttertoast` | Full support | Works on OHOS (uses Toast via MethodChannel — `SaveImgHandler`) |
| Push (Getui) | Android/iOS | MethodChannel calls return `MissingPluginException` (caught silently) |

### WebView (`lib/commons/webview/wby_webview.dart:41-43`)

```dart
if (Platform.isAndroid) {
  WebView.platform = SurfaceAndroidWebView();
}
```

Only sets `SurfaceAndroidWebView` for Android. OHOS falls through to default WebView implementation which **does not work** (no OHOS plugin for `webview_flutter`).

### Font Loading (`lib/commons/font/font_loader.dart:24`)

```dart
if (Platform.isAndroid) {
  DownloadManager.getInstance().downloads(tasks, ...);
} else {
  // iOS — download via Dio
}
```

OHOS falls to the iOS branch (download via Dio) since `!Platform.isAndroid`. Runtime font download from TWT servers works on OHOS.

### Storage (`lib/commons/util/storage_util.dart:18-29`)

```dart
downloadDir = Platform.isAndroid
    ? (await getDownloadsDirectory() ?? ...)
    : (await getApplicationDocumentsDirectory()).path;

photoDir = Platform.isAndroid
    ? (await getExternalStorageDirectories(...))!.first.path
    : (await getApplicationDocumentsDirectory()).path;
```

OHOS falls to the non-Android branch, using `getApplicationDocumentsDirectory()` which works via `path_provider`'s OHOS fallback.

---

> 以下内容为移植笔记/工作记录，保留原有内容：

# WePeiYang Flutter → HarmonyOS 移植笔记

Flutter SDK: `oh-3.41.9-dev` (Flutter 3.41.10, OpenHarmony 定制版)
Dart SDK: 3.6.2+
目标系统: HarmonyOS NEXT (API 12)
构建工具: `devecocli` (DevEco CLI, 包装 hvigor + ohpm + hdc)
设备: HUAWEI Pura 70 Pro (192.168.137.159:46715, 无线 hdc)

---

## ✅ 已完成

| 功能 | 状态 | 实现方式 |
|------|------|----------|
| 保存图片到相册 | ✅ | `showAssetsCreationDialog`（系统弹窗，无需权限） |
| 评论/帖子图片加载 | ✅ | WpyPic 内存缓存 + Dio SSL 绕过 |
| 发帖选图（打开相册） | ✅ | `PhotoViewPicker.select()` 返回 URI |
| 发帖选图（返回路径） | ✅ | `fs.openSync(uri)` 读取 URI → 拷贝到 cacheDir |
| Flutter SDK 3.27.4→3.41.10 | ✅ | hvigorconfig + PUB_CACHE + node_modules 手工链接 |
| 应用名"微北洋" | ✅ | AppScope string.json |
| 图标 | ✅ | `assets/app_icon.png` → AppScope media |
| Toast/动画/ScrollController | ✅ | 已修复 |

---

## 构建与部署

### 快速构建（debug）

```bash
cd harmonyos\wepei_module\.ohos
$env:PUB_CACHE = "D:\pub-cache"
devecocli build          # ~45s (no-daemon)
devecocli run            # build + install + launch
devecocli run --skip-build   # 仅安装已有 HAP (~20s)
```

### Release 构建

```bash
devecocli build --build-mode release   # ~2m20s
devecocli run --skip-build             # 部署 release HAP
```

### .ohos/ 目录被重置后的恢复清单

`flutter pub get` 或 `flutter build` 会重新生成 `.ohos/` 目录，以下文件会被覆盖：

| 文件 | 需恢复的内容 |
|------|-------------|
| `build-profile.json5` | signingConfigs（加密密码） |
| `AppScope/app.json5` | bundleName → `com.weipeiyang.cn`、icon → `$media:app_icon` |
| `AppScope/resources/base/element/string.json` | app_name → "微北洋" |
| `AppScope/resources/base/media/app_icon.png` | 从 `assets/app_icon.png` 复制 |
| `entry/src/main/module.json5` | icon/startWindowIcon → `$media:app_icon` |
| `flutter_module/src/main/ets/plugins/GeneratedPluginRegistrant.ets` | 去掉 `image_picker_ohos`（只用 `photo_manager`） |
| `entry/src/main/ets/entryability/EntryAbility.ets` | 从 `harmonyos/entry/...` 同步 |
| `hvigor/hvigor-config.json5` | execution 优化配置 |
| `oh-package.json5` | modelVersion → `5.1.0`（与 hvigor-config 一致） |
| `.ohpmrc` | `enable_unified_lockfile=true` + `enable_boost_extraction_speed=true` |
| `flutter_module/oh-package.json5` | modelVersion → `5.1.0` |
| `entry/oh-package.json5` | modelVersion → `5.1.0` |

建议恢复后用 `devecocli build` 验证编译通过。

---

## 架构

### 选图流程

```
用户点击"选图"
  → Flutter: ImageSave.pickImagesFromGallery()
    → MethodChannel('com.twt.service/saveImg').invokeMethod('pickImages')
      → OHOS: SaveImgHandler.onMethodCall('pickImages')
        → new photoAccessHelper.PhotoViewPicker().select(options)
          → 系统相册弹窗 → 用户选择 → 返回 URIs
        → fs.openSync(uri) → fs.copyFileSync() → cacheDir/picker_temp/
        → result.success([paths]) → Flutter 收到路径列表
```

### 保存图片流程

```
用户点击"保存"
  → Flutter: _channel.invokeMethod('savePictureToAlbum', {path})
    → SaveImgHandler.saveToAlbum()
      → Try 1: showAssetsCreationDialog（系统弹窗，保存到相册）
      → Try 2: 拷贝到 filesDir/微北洋/（兜底）
```

### 关键文件

| 路径 | 说明 |
|------|------|
| `harmonyos/entry/src/main/ets/entryability/EntryAbility.ets` | 源文件（修改入口） |
| `harmonyos/wepei_module/.ohos/entry/.../EntryAbility.ets` | 构建副本（需 cp 同步） |
| `lib/commons/channel/image_save/image_save.dart` | Flutter 端 MethodChannel（主项目） |
| `harmonyos/wepei_module/lib/.../image_save.dart` | Flutter 模块副本（必须同步！） |
| `harmonyos/wepei_module/pubspec.yaml` | 依赖 + dependency_overrides |
| `assets/app_icon.png` | 应用图标源文件 |

---

## 签名

使用 DevEco Studio 自动生成的 Debug 签名：
- 证书路径: `C:\Users\lneoo\.ohos\config\default_harmonyos_*.p12`
- bundleName: `com.weipeiyang.cn`（必须与 .p7b profile 一致）
- storePassword/keyPassword: 加密 hex 串（≥32 字符）

**证书与 bundleName 绑定**，如果改 bundleName 需要重新生成签名（DevEco Studio → File → Project Structure → Signing Configs → Automatically generate signing）。

---

## 编译速度优化

当前配置（`hvigor/hvigor-config.json5`）：
- `daemon: false`（端口 45000-45099 被 TIME_WAIT 占满，跳过重试省 15s）
- `incremental: true`、`parallel: true`
- `optimizationStrategy: "performance"`
- `maxOldSpaceSize: 8192`

`.ohpmrc`：
- `enable_unified_lockfile=true`
- `enable_boost_extraction_speed=true`

全量构建耗时：debug ~45s，release ~2m20s。

如果 daemon 端口被清空后把 `daemon` 改回 `true`，增量构建可更快。

---

## 常见问题

### 发帖选图报 MissingPluginException

Flutter 端 channel 名与 OHOS 端不一致。检查：
1. `lib/commons/channel/image_save/image_save.dart` 中 `_pickerChannel` 为 `com.twt.service/saveImg`
2. 同步到 `harmonyos/wepei_module/lib/.../image_save.dart`
3. OHOS 端 `EntryAbility.ets` 中 channel 为 `com.twt.service/saveImg`

### 选完图不显示（13900015 File exists）

`fileIo.mkdir()` 不支持 `recursive` 参数，目录已存在就抛异常。改用 `fs.mkdirSync(cacheDir)` + try/catch 忽略已存在。

### 应用名显示"wepei_module"

`.ohos/AppScope/resources/base/element/string.json` 被重置，需恢复 `app_name` → "微北洋"。

### 图标错误

`.ohos/AppScope/app.json5` 的 `icon` 引用和 AppScope media 目录被重置，需恢复。

### bundleName 不匹配导致签名失败

`.ohos/AppScope/app.json5` 的 bundleName 被重置为 `com.twtservice.wepeiyang`，需改回 `com.weipeiyang.cn`（与 .p7b profile 一致）。
