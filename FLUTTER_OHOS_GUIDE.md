# Flutter HarmonyOS NEXT 适配指南

> 基于 WePeiYang（微北洋）和 PiliPlus 两个项目的鸿蒙适配经验总结

---

## 一、前置条件

| 工具 | 版本/路径 |
|------|----------|
| Flutter SDK | `oh-3.41.9-dev` (Flutter 3.41.10, Dart 3.6.2+) |
| DevEco Studio | 5.0+ |
| Node.js | DevEco 内置 (`tools/node/node.exe`) |
| Java | JDK 21+ |
| 构建工具 | `devecocli`（DevEco CLI，包装 hvigor + ohpm + hdc） |
| 目标系统 | HarmonyOS NEXT (API 12+, compatibleSdkVersion 5.0.0) |

Flutter SDK 下载：[Flutter OHOS Releases](https://gitcode.com/openharmony-sig/flutter_ohos/releases)

---

## 二、项目结构

一个 Flutter 项目适配 OHOS 后，新增以下文件：

```
project/
├── harmonyos/                          # OHOS 原生工程根目录
│   ├── build-profile.json5             # 签名配置（DevEco Studio 生成）
│   ├── oh-package.json5                # OHPM 项目配置
│   ├── hvigor/
│   │   └── hvigor-config.json5         # 构建优化配置
│   ├── hvigorfile.ts                   # Hvigor 入口（注入 flutter-hvigor-plugin）
│   ├── hvigorconfig.ts                 # 构建时版本注入、DART_DEFINES
│   ├── AppScope/
│   │   ├── app.json5                   # 应用名、bundleName、版本、图标
│   │   └── resources/base/
│   │       ├── element/string.json     # app_name 等字符串
│   │       └── media/                  # app_icon.png, layered 图标
│   └── entry/                          # HAP 入口模块
│       ├── build-profile.json5         # 模块构建配置
│       ├── oh-package.json5            # 模块 OHPM 依赖
│       ├── libs/                       # 预编译 HAR (flutter_module.har)
│       └── src/main/
│           ├── module.json5            # 权限、设备类型、配置
│           ├── resources/
│           │   ├── base/profile/main_pages.json   # 页面路由
│           │   ├── base/element/string.json       # 权限理由等
│           │   └── rawfile/buildinfo.json5        # Flutter 引擎配置
│           └── ets/
│               ├── entryability/
│               │   └── EntryAbility.ets           # FlutterAbility 子类
│               ├── pages/
│               │   └── Index.ets                  # FlutterPage 宿主
│               └── plugins/
│                   ├── GeneratedPluginRegistrant.ets # 插件注册（自动生成）
│                   └── HarmonyChannel.ets           # 自定义插件（可选）
│
├── harmonyos/wepei_module/             # Flutter 模块（独立 pubspec）
│   ├── pubspec.yaml                    # 依赖 + dependency_overrides
│   ├── lib/                            # Dart 源码（与根 lib/ 同步）
│   │   └── ...
│   └── .ohos/                          # Hvigor 构建目录（⚠️ 会被 pub get 重置）
│       ├── build-profile.json5         # 签名配置（需手动恢复）
│       ├── hvigor/hvigor-config.json5  # 构建优化
│       └── ...
```

---

## 三、Flutter ↔ OHOS 桥梁

### 3.1 入口点

OHOS 入口继承 `FlutterAbility`，类似 Android 的 `FlutterActivity`：

```typescript
// EntryAbility.ets
export default class EntryAbility extends FlutterAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    super.onCreate(want, launchParam);
  }

  configureFlutterEngine(flutterEngine: FlutterEngine): void {
    super.configureFlutterEngine(flutterEngine);
    GeneratedPluginRegistrant.registerWith(flutterEngine);

    // 注册自定义 MethodChannel
    const channel = new MethodChannel(
      flutterEngine.getDartExecutor(),
      'com.example/app',       // 通道名
      StandardMethodCodec.INSTANCE
    );
    channel.setMethodCallHandler(new MyHandler(this.context));
  }
}
```

### 3.2 FlutterPage 集成

ArkUI 页面使用 `FlutterPage` 组件承载 Flutter 渲染：

```typescript
// Index.ets
import { FlutterPage } from '@ohos/flutter_ohos'

@Entry(storage)
@Component
struct Index {
  @LocalStorageLink('viewId') viewId: string = "";

  build() {
    Stack() {
      FlutterPage({ viewId: this.viewId })
        .width('100%')
        .height('100%')
      // 可以在此叠加其他 ArkUI 组件
    }
  }
}
```

### 3.3 MethodChannel 模式

所有 OHOS 原生功能都通过单个 MethodChannel 桥接：

**Flutter 端 (Dart)：**
```dart
static const _channel = MethodChannel('com.example/app');

static Future<dynamic> callNative(String method, [dynamic args]) async {
  try {
    return await _channel.invokeMethod(method, args);
  } catch (e) {
    debugPrint('[Native] $method failed: $e');
    return null;
  }
}
```

**OHOS 端 (ArkTS)：**
```typescript
class MyHandler implements MethodCallHandler {
  private context: common.UIAbilityContext;

  onMethodCall(call: MethodCall, result: MethodResult): void {
    switch (call.method) {
      case 'method1':
        this.method1(result);
        break;
      default:
        result.notImplemented();
    }
  }

  private method1(result: MethodResult): void {
    try {
      // ... native API calls ...
      result.success(returnValue);
    } catch (e) {
      console.warn(TAG, 'failed: ' + JSON.stringify(e));
      result.success(null);  // 永远不要挂起调用方
    }
  }
}
```

**重要规则：**
- 每个分支都必须调用 `result.success()` 或 `result.error()`
- `onMethodCall` 是同步的，但方法实现可以是 `async`
- 使用 `console.info/warn/error`（带 TAG 前缀）便于日志过滤

---

## 四、插件方案

### 4.1 三选一策略

每个 Flutter 插件在 OHOS 上按以下优先级选择实现方案：

```
方案 A：使用 pub 官方 OHOS 插件  ✅ 优先
方案 B：使用 dependency_overrides 的 OHOS Fork  ⚠️ 备选
方案 C：MethodChannel 自定义实现  🔧 最终手段
```

### 4.2 OHOS 插件清单

**方案 A — 现有 OHOS 插件（可直接添加 pub 依赖）：**

| Flutter 包 | OHOS 包 | 来源 |
|------------|---------|------|
| `image_picker` | `image_picker_ohos` | pub / git |
| `path_provider` | `path_provider_ohos` | git: openharmony-tpc |
| `permission_handler` | `permission_handler_ohos` | git: CPF-Flutter |
| `url_launcher` | `url_launcher_ohos` | git: openharmony-tpc |
| `share_plus` | `share_plus_ohos` | git: CPF-Flutter |
| `connectivity_plus` | `connectivity_plus_ohos` | git: CPF-Flutter |
| `device_info_plus` | `device_info_plus_ohos` | git: CPF-Flutter |
| `wakelock_plus` | `wakelock_plus_ohos` | git: CPF-Flutter |
| `screen_brightness` | `screen_brightness_ohos` | git: CPF-Flutter |
| `battery_plus` | `battery_plus_ohos` | git: CPF-Flutter |
| `app_links` | `app_links_ohos` | git: CPF-Flutter |
| `file_picker` | `file_picker_ohos` | git: openharmony-tpc |
| `saver_gallery` | `saver_gallery` | git: openharmony-tpc |
| `flutter_inappwebview` | `flutter_inappwebview_ohos` | git: CPF-Flutter |
| `image_cropper` | `image_cropper_ohos` | git: CPF-Flutter |
| `video_player` | `video_player_ohos` | git: openharmony-tpc |

**方案 C — 自定义 MethodChannel 实现（WePeiYang 方式）：**

| 功能 | Dart 调用 | Native 实现 |
|------|-----------|-------------|
| 选图 | `ImageSave.pickImagesFromGallery()` | `photoAccessHelper.PhotoViewPicker.select()` |
| 存图 | `ImageSave.saveImageFromBytes()` | `photoAccessHelper.showAssetsCreationDialog()` |
| 读剪贴板 | `ImageSave.getClipboardText()` | `pasteboard.getSystemPasteboard().getData()` |
| 写剪贴板 | `ImageSave.copyToClipboard(text)` | `pasteboard.createData() + setData()` |
| 打开网页 | `ImageSave.openWebView(url)` | `context.startAbility(want)` |

---

## 五、依赖配置

### 5.1 pubspec.yaml（Flutter 模块）

```yaml
name: wepei_module
environment:
  sdk: ">=3.6.2 <4.0.0"

# OHOS 插件依赖（依赖类型覆盖示例）
dependency_overrides:
  photo_manager: 3.6.4
  image_picker:
    git:
      url: https://gitcode.com/CPF-Flutter/flutter_packages.git
      path: packages/image_picker/image_picker
      ref: br_image_picker-v1.1.2_ohos

flutter:
  module:
    ohosBundleName: com.example.app   # 建议与签署证书一致
```

### 5.2 oh-package.json5（OHPM）

```json5
{
  "modelVersion": "5.1.0",
  // 避免添加 @ohos/hypium 等 devDependency（OHPM registry 502 问题）
  "dependencies": {},
  "devDependencies": {}
}
```

**模型版本一致性：** `oh-package.json5`、`entry/oh-package.json5`、`hvigor/hvigor-config.json5` 的 `modelVersion` 必须一致。

### 5.3 Dependency Override 来源

OHOS Flutter 插件的 Git 仓库来源：

| 组织 | 仓库地址 | 说明 |
|------|---------|------|
| openharmony-tpc | `https://gitcode.com/openharmony-tpc/flutter_packages.git` | 官方 TPC 包 |
| CPF-Flutter | `https://gitcode.com/CPF-Flutter/flutter_plus_plugins.git` | 社区维护 |
| Predidit | `https://github.com/Predidit/media-kit.git` | 媒体播放 |

---

## 六、权限管理

### 6.1 权限类型

| 类型 | 说明 | 安装时 | 运行时 |
|------|------|--------|--------|
| `normal` | 普通权限 | 自动授予 | 无需处理 |
| `user_grant` | 用户授权 | 不授予 | 需 `requestPermissionsFromUser()` |
| `restricted` | 受限权限 | ❌ 需 AGC Profile | 需显式申请 |

### 6.2 声明方式（module.json5）

```json5
{
  "module": {
    "requestPermissions": [
      { "name": "ohos.permission.INTERNET" },                              // normal
      {
        "name": "ohos.permission.READ_PASTEBOARD",                         // restricted
        "reason": "$string:reason_read_pasteboard",
        "usedScene": {
          "abilities": ["EntryAbility"],
          "when": "inuse"                                                   // 仅使用时请求
        }
      },
      {
        "name": "ohos.permission.WRITE_IMAGEVIDEO",                        // user_grant
        "reason": "$string:reason_write_imagevideo",
        "usedScene": { "abilities": ["EntryAbility"], "when": "inuse" }
      }
    ]
  }
}
```

### 6.3 运行时请求（ArkTS）

```typescript
import { abilityAccessCtrl, Permissions } from '@kit.AbilityKit';
import { BusinessError } from '@ohos.base';

const atManager = abilityAccessCtrl.createAtManager();
atManager.requestPermissionsFromUser(context, ['ohos.permission.READ_PASTEBOARD'])
  .then((data) => {
    if (data.authResults[0] === 0) {
      // 用户已授权 → 执行操作
    }
  })
  .catch((err: BusinessError) => {
    console.warn(TAG, 'permission denied: ' + JSON.stringify(err));
  });
```

### 6.4 已知限制

| 权限 | 问题 | 解决方案 |
|------|------|----------|
| `READ_PASTEBOARD` | 受限权限，无 AGC Profile 无法安装 | DevEco Studio 自动签名（自动处理） |
| `READ_IMAGEVIDEO` | user_grant，安装时自动授权失败 | 使用系统 API 内部处理（如 `PhotoViewPicker`） |
| 所有 user_grant | `devecocli run` / `hdc install` 可能失败 | 用 `hdc install -r`（跳过自动授权） |

---

## 七、构建配置

### 7.1 hvigor-config.json5（构建优化）

```json5
{
  "modelVersion": "5.1.0",
  "execution": {
    "daemon": false,      // daemon 端口 45000-45099 被占时禁用
    "incremental": true,
    "parallel": true,
    "optimizationStrategy": "performance"
  },
  "nodeOptions": {
    "maxOldSpaceSize": 8192
  }
}
```

### 7.2 build-profile.json5（签名）

```json5
{
  "app": {
    "signingConfigs": [
      {
        "name": "default",
        "material": {
          "storeFile": "C:\\Users\\xxx\\.ohos\\config\\xxx.p12",
          "storePassword": "0000...encrypted...",
          "keyAlias": "debugKey",
          "keyPassword": "0000...encrypted...",
          "profile": "C:\\Users\\xxx\\.ohos\\config\\xxx.p7b",
          "certpath": "C:\\Users\\xxx\\.ohos\\config\\xxx.cer",
          "signAlg": "SHA256withECDSA"
        }
      }
    ],
    "products": [{
      "name": "default",
      "signingConfig": "default",
      "compatibleSdkVersion": "5.0.0(12)",
      "runtimeOS": "HarmonyOS"
    }]
  }
}
```

签名配置由 **DevEco Studio → File → Project Structure → Signing Configs → Automatically generate signing** 生成。

### 7.3 构建命令

```bash
# 调试构建 + 安装 + 启动
cd harmonyos/wepei_module/.ohos
$env:PUB_CACHE = "D:\pub-cache"
devecocli run

# Release 构建
devecocli build --build-mode release

# 仅安装已有 HAP
devecocli run --skip-build

# 首次安装/签名变更时
devecocli run --uninstall

# 通过 hdc 安装（跳过 user_grant 自动授权）
cd entry/build/default/outputs/default
hdc -t <IP> install -r entry-default-signed.hap
```

### 7.4 Flutter 模块 HAR 构建

```bash
cd harmonyos/wepei_module
flutter build har --debug
```

### 7.5 构建时间

| 模式 | 时间 |
|------|------|
| debug 全量 | ~45s |
| debug skip-build | ~20s |
| release 全量 | ~2m20s |

---

## 八、图片加载

### 8.1 OHOS 图片加载方案

Flutter 的 `CachedNetworkImage` 依赖 `path_provider`（OHOS 不支持），需要替代方案：

```dart
// lib/commons/widgets/wpy_pic.dart
Widget _ohosNetwork = Container(
  child: FutureBuilder<Uint8List>(
    future: _ohosFuture,
    builder: (context, snapshot) {
      if (snapshot.hasData && snapshot.data!.isNotEmpty) {
        return Image.memory(snapshot.data!, fit: BoxFit.cover);
      }
      return _loadingWidget;
    },
  ),
);

// 使用 raw HttpClient + SSL 绕过
Future<Uint8List> _fetchOhosImage(String url) async {
  final client = HttpClient()
    ..badCertificateCallback = (_, _, _) => true;  // SSL 绕过
  final request = await client.getUrl(Uri.parse(url));
  final response = await request.close();
  return consolidateHttpClientResponseBytes(response);
}
```

### 8.2 内存缓存

```dart
static final Map<String, Uint8List> _ohosImageCache = {};
Future<Uint8List>? _ohosFuture;

void _loadOhosImage(String url) {
  if (_ohosImageCache.containsKey(url)) {
    _ohosFuture = Future.value(_ohosImageCache[url]!);
    return;
  }
  _ohosFuture = _fetchOhosImage(url).then((data) {
    _ohosImageCache[url] = data;
    return data;
  });
}
```

---

## 九、图片选取与保存

### 9.1 选取图片

```typescript
// EntryAbility.ets
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import fs from '@ohos.file.fs';

private async pickImages(result: MethodResult): void {
  try {
    const photoPicker = new photoAccessHelper.PhotoViewPicker();
    const options = new photoAccessHelper.PhotoSelectOptions();
    options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
    options.maxSelectNumber = 3;
    const res = await photoPicker.select(options);
    const uris = res.photoUris;
    
    // 复制到可访问路径
    const cacheDir = this.context.cacheDir + '/picker_temp';
    try { fs.mkdirSync(cacheDir); } catch (_) {}
    
    const paths: string[] = [];
    for (let i = 0; i < uris.length; i++) {
      const srcFile = fs.openSync(uris[i]);  // 支持 file:// URI
      const destPath = cacheDir + '/img_' + i + '.jpg';
      const destFile = fs.openSync(destPath, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY);
      fs.copyFileSync(srcFile.fd, destFile.fd);
      fs.closeSync(srcFile);
      fs.closeSync(destFile);
      paths.push(destPath);
    }
    result.success(paths);
  } catch (e) {
    console.warn(TAG, 'pick failed: ' + JSON.stringify(e));
    result.success([]);
  }
}
```

### 9.2 保存图片

```typescript
private async saveToAlbum(path: string, result: MethodResult): void {
  try {
    const helper = photoAccessHelper.getPhotoAccessHelper(this.context);
    const srcUri = fileIo.getUriFromPath(path);
    const desFileUris = await helper.showAssetsCreationDialog(
      [srcUri],
      [{ title: '微北洋', fileNameExtension: 'jpg',
         photoType: photoAccessHelper.PhotoType.IMAGE,
         subtype: photoAccessHelper.PhotoSubtype.DEFAULT }]
    );
    // 复制内容到目标
    if (desFileUris.length > 0) {
      const srcFile = await fileIo.open(srcUri, fileIo.OpenMode.READ_ONLY);
      const destFile = await fileIo.open(desFileUris[0], fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY);
      await fileIo.copyFile(srcFile.fd, destFile.fd);
      await fileIo.close(srcFile);
      await fileIo.close(destFile);
    }
    result.success(true);
  } catch (e) {
    console.warn(TAG, 'save failed: ' + JSON.stringify(e));
    result.success(false);
  }
}
```

---

## 十、剪贴板

### 10.1 读取剪贴板

```dart
// Dart 端：直接用 Flutter 框架 API（OHOS 上能正确读取完整多行文本）
final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
```

```typescript
// ArkTS 端（如果需要原生读取）
import pasteboard from '@ohos.pasteboard';

private readClipboard(result: MethodResult): void {
  const atManager = abilityAccessCtrl.createAtManager();
  atManager.requestPermissionsFromUser(context, ['ohos.permission.READ_PASTEBOARD'])
    .then((data) => {
      if (data.authResults[0] === 0) {
        const pb = pasteboard.getSystemPasteboard();
        const recordData = pb.getDataSync();          // 同步读取
        result.success(recordData.getPrimaryText());  // 返回完整文本
      } else {
        result.success(null);
      }
    });
}
```

### 10.2 写入剪贴板

```typescript
private writeClipboard(text: string): void {
  const pb = pasteboard.getSystemPasteboard();
  const data = pasteboard.createData({ mimeType: pasteboard.MIMETYPE_TEXT_PLAIN, value: text });
  pb.setData(data);
}
```

---

## 十一、平台适配清单

### 11.1 Flutter 端 Platform 分支模式

```dart
if (Platform.isAndroid) {
  // Android 特化
} else if (Platform.isIOS) {
  // iOS 特化
} else {
  // OHOS / Windows / Linux 兜底
}
```

### 11.2 需加 Platform 守卫的功能

| 功能 | Android/iOS | OHOS 处理 |
|------|------------|----------|
| `cached_network_image` | 使用 | 替换为 `_ohosNetwork` |
| `path_provider` | 使用 | 替换为 `Directory.systemTemp` |
| `shared_preferences` | 使用 | `MockSharedPreferences` 文件兜底 |
| `webview_flutter` | 使用 | 系统浏览器打开（`startAbility`） |
| `image_picker` | 使用 | `PhotoViewPicker` 自定义实现 |
| `gallery_saver` | 使用 | `showAssetsCreationDialog` |
| `permission_handler` | 使用 | `.catchError()` 静默失败 |
| `url_launcher` | 使用 | `.catchError()` 静默失败 |
| `share_plus` | 使用 | `.catchError()` 静默失败 |
| `connectivity_plus` | 使用 | `.catchError()` 静默失败 |
| `flutter_displaymode` | Android | `Platform.isAndroid` 守卫 |
| `window_manager` | Windows | `Platform.isWindows` 守卫 |
| 消息推送 (Getui) | Android/iOS | `.catchError()` 静默失败 |
| 应用更新 | Android/iOS | 跳过（`return`） |

---

## 十二、标志性差异：PiliPlus vs WePeiYang

| 方面 | PiliPlus | WePeiYang |
|------|----------|------------|
| 插件方案 | 22 个 OHOS 插件（全部方案 A） | 1 个 OHOS 插件 + 5 个自定义通道 |
| Flutter SDK | `oh-3.41.4+` | `oh-3.41.9-dev` (3.41.10) |
| 引擎渲染 | Impeller 启用 | Impeller 未启用 |
| 依赖管理 | 大量 git override | 最小 override + 自定义实现 |
| WebView | `flutter_inappwebview_ohos`（应用内） | 系统浏览器（外部） |
| 剪贴板 | 框架 `Clipboard` API | 框架 API + 原生 pasteboard 兜底 |
| 文件选择 | `file_picker` 插件 | 自定义 `PhotoViewPicker` |
| 后台播放 | `audio_service` 插件 | 不适用（非音视频应用） |
| 平台守卫 | 部分 `Platform` 分支 | 大量 `Platform` 分支 |

**关键差距：** PiliPlus 使用了更完整的 OHOS 插件生态（22 个），WePeiYang 走的是轻量化自定路径（维护成本低但功能受限）。

---

## 十三. `.ohos/` 目录维护

### 13.1 问题

`flutter pub get` 会重新生成 `harmonyos/wepei_module/.ohos/` 目录，以下文件会被重置：

| 文件 | 影响 | 恢复频率 |
|------|------|----------|
| `build-profile.json5` | 签名配置丢失 | 每次 pub get |
| `AppScope/app.json5` | bundleName/icon 重置 | 每次 pub get |
| `AppScope/string.json` | app_name 恢复默认 | 每次 pub get |
| `entry/module.json5` | 权限/icon 重置 | 每次 pub get |
| `hvigor/hvigor-config.json5` | 构建优化重置 | 每次 pub get |
| `oh-package.json5` | modelVersion + hypium | 每次 pub get |
| `flutter_module/GeneratedPluginRegistrant.ets` | 插件配置重置 | 每次 pub get |
| `entry/oh-package.json5` | modelVersion 重置 | 每次 pub get |

### 13.2 解决方案

编写恢复脚本或在 `pubspec.yaml` 中添加 post-get hook。手动恢复的步骤：

```bash
cp harmonyos/entry/src/main/ets/entryability/EntryAbility.ets \
   harmonyos/wepei_module/.ohos/entry/src/main/ets/entryability/EntryAbility.ets
# ... 以及所有其他被重置的文件
```

---

## 十四、自建 OHOS 插件开发

如果需要为你的 Flutter 包创建 OHOS 原生实现：

### 14.1 插件结构

```
flutter_package/
├── lib/                    # Dart 接口
├── ohos/                   # OHOS 原生代码
│   ├── src/main/
│   │   └── ets/plugin/
│   │       └── MyPlugin.ets
│   └── oh-package.json5    # OHPM 配置
└── pubspec.yaml            # Flutter 插件声明
```

### 14.2 插件注册

```typescript
// MyPlugin.ets
import { FlutterPlugin, MethodCallHandler, ... } from '@ohos/flutter_ohos';

export class MyPlugin implements FlutterPlugin, MethodCallHandler {
  private channel: MethodChannel | null = null;

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.channel = new MethodChannel(
      binding.getBinaryMessenger(), 'my_plugin', StandardMethodCodec.INSTANCE
    );
    this.channel.setMethodCallHandler(this);
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    this.channel?.setMethodCallHandler(null);
    this.channel = null;
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    // 处理调用
  }
}
```

### 14.3 在 GeneratedPluginRegistrant 中注册

```typescript
import { MyPlugin } from 'my_package_name';
flutterEngine.getPlugins()?.add(new MyPlugin());
```

---

## 十五、常见问题

### 编译错误

| 错误 | 原因 | 解决 |
|------|------|------|
| `arkts-no-any-unknown` | 使用 `any` 类型 | 显式类型声明或用 `as` 转换 |
| `Property 'xxx' does not exist` | API 版本不匹配 | 检查 `@kit.*` 导入路径 |
| `modelVersion` 不一致 | hvigor-config / oh-package 版本不同 | 统一设 `5.0.0` 或 `5.1.0` |
| `MissingPluginException` | 通道/方法未注册 | 检查 GeneratedPluginRegistrant / EntryAbility |
| `ohpm 502` | OHPM registry 不可用 | 移除 `@ohos/hypium` 依赖 |

### 运行时错误

| 错误 | 原因 | 解决 |
|------|------|------|
| `13900015 File exists` | `fileIo.mkdir` 不支持 recursive | 改用 `fs.mkdirSync()` + try/catch |
| `grant request permissions failed` | user_grant 安装时自动授权失败 | 用 `hdc install -r` 替代 |
| `RSUIContext is null` | Flutter OHOS 引擎版本过低 | 升级到 `oh-3.41.4+` |
| 剪贴板只有第一行 | `getPrimaryText()` 在 `\n` 处截断 | 改用 `Clipboard.getData()`（框架 API） |

---

## 十六、参考项目

| 项目 | 仓库 | Flutter 版本 | 特点 |
|------|------|------------|------|
| **PiliPlus** | [qinshah/PiliPlus](https://github.com/qinshah/PiliPlus) | oh-3.41.4+ | 22 个 OHOS 插件，完整插件生态 |
| **WePeiYang** | [twtstudio/WePeiYang-Flutter](https://github.com/twtstudio/WePeiYang-Flutter) | oh-3.41.9-dev | 轻量化，MethodChannel 为主 |
| **Flutter OHOS SDK** | [openharmony-sig/flutter_ohos](https://gitcode.com/openharmony-sig/flutter_ohos) | 最新 | 官方 SDK 与示例 |
| **OHOS 插件中心** | [openharmony-tpc/flutter_packages](https://gitcode.com/openharmony-tpc/flutter_packages) | 最新 | 官方 TPC 插件 |
