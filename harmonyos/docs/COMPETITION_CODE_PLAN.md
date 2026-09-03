# 参赛代码改造执行计划

> **执行状态（2026-09-03 更新）**：Phase 0–5 代码部分已全部完成并完成真机拉起验证
> （`flutter analyze` 0 error、比对脚本 `--strict` 0 review、单测通过、
> `devecocli build --build-mode release` 产出 115MB Release 签名 HAP，真机 HUAWEI Pura 70 Pro 部署运行正常）。
> 修复了服务卡片点击直达路由 404 与冷启动冲刷时序，接入 HoKit 专用 ACL 签名放行 `READ_PASTEBOARD` 剪贴板权限，并将后台多任务标题对齐中文。待确认事项见文末「待确认与移交」。

本文档是 [`COMPETITION_READINESS.md`](./COMPETITION_READINESS.md) 中「可通过改代码完成」事项的**执行计划**。资质类事项（软著、APP 备案、校方授权、AGC 正式证书、分级评估）由其他人负责，不在本文范围。

构建与同步流程见 [`DEVELOPMENT_GUIDE.md`](./DEVELOPMENT_GUIDE.md)。**所有改动只落 `harmonyos/wepei_module/lib/` 镜像与 `harmonyos/` 原生侧；根 `lib/` 保持只读，仅作对照基线**（Android/iOS 是在网生产代码，不在本次范围内动）。由此产生的镜像新差异，必须同步登记进 `scripts/compare_ohos_flutter.py` 的 confirmed allowlist，否则 `--strict` 门禁会报。

## 0. 三条原则（由项目定）

1. **优先复用根 `lib/` 已有代码**：`lib/` 只读，仅作对照基线——非 OHOS 适配的漂移一律把镜像回退为 `lib/` 原版；OHOS 需要的能力优先看 `lib/` 是否已有实现可搬进镜像（如 WebView 打开外链、系统相册选图）。
2. **其次使用开源 OHOS 适配库**：优先 `OpenHarmony-TPC/flutter_packages`（AtomGit 主仓，GitCode/GitHub 镜像）、`OpenHarmony-SIG/flutter_plus_plugins`、`fluttertpc_*` 系列仓库；**必须 pin ref，禁止 `any`**。
3. **最后才手写 ArkTS**：以最小 MethodChannel 实现，遵循 DEVELOPMENT_GUIDE §5.3 的通道约束。

## 1. 对 COMPETITION_READINESS.md 的勘误

| 原条目 | 修正 |
| --- | --- |
| P0 #4「70MB HAR 入库」 | `entry/libs/` 是孤儿：唯一引用 `entry/oh-package.json5:9` 不被 `sync_ohos_native.py` 拷贝，真实构建走 `.ohos/entry/oh-package.json5:9` 的源码依赖。**删除零风险** |
| P0 #3「签名路径硬编码」 | 根 `harmonyos/build-profile.json5` **不参与构建**；构建用的 `.ohos/build-profile.json5` 是生成物，需脚本注入 |
| P0 #9「247/299 分叉」 | 240 个仅 import 包名不同；真实差异 94 个（A 类必要适配 66 + B 类漂移 26 + 边界） |
| 引用 `lib/commons/util/storage_util.dart:8` 等 | 该启发式 14 处**全部在镜像**，根 `lib/` 为 0 处；且本 fork `Platform` 无 `isOhos` |
| 资源「9 缺 1 余」 | 零风险：8 个缺失 PNG 在 OHOS 侧无引用；多出的 `.ttf` 被 `font_loader.dart:96` 正确引用 |

## 2. 基线数据（2026-08-31 实测）

- Dart：299 文件（根）/ 304（镜像）；206 字节级相同；240 仅包名差异；**94 真实差异**。
- 插件：仅 `photo_manager`（override 3.6.4）与 `flutter_inappwebview`（gitcode `br_v6.1.5_ohos`）有 OHOS 实现；ArkTS 自建 channel 仅 `com.twt.service/saveImg`。
- OHOS pubspec：除 2 个 override 外全部 `any`（解析到旧版，导致 B2 类 API 锁死，**不要随意升版**）。
- Flutter SDK：官方 `openharmony-tpc/flutter_flutter`，dev 分支 `oh-3.41.9-dev`；**release 前切 `oh-3.41.9-release` 并 pin commit**。

## 3. 执行顺序与依赖

```text
Phase 0 地基(2.5d) ──→ Phase 1 合规剔除(2d) ──→ Phase 3 插件补齐(5d) ──→ Phase 4 上架字段(1d) ──→ Phase 5 特色加分(2周)
                    └──→ Phase 2 漂移回退(3d) ──┘
```

Phase 0 先行：让后续所有改动都有「可复现构建」可验证。Phase 1 是上架硬门槛。Phase 2 与 Phase 3 可并行（不同文件面）。Phase 5 独立，时间富余才做（卡片增强优先，元服务按团队决定不做）。

---

## Phase 0｜地基：可复现构建 + 死代码清理（约 2.5 天）

### 0.1 删除孤儿 HAR（0.5d，纯删零风险）

- 删 `harmonyos/entry/libs/` 整目录（55MB+14MB+2 个小 HAR）。
- `harmonyos/entry/oh-package.json5:9` 的 `"flutter_module": "file:./libs/flutter_module.har"` 删除（保留 `@ohos/flutter` 相关如有）。若要保留「harmonyos/ 当独立 DevEco 工程打开」的能力，改为 `file:../wepei_module/build/ohos/har/debug/flutter_module.har`（不入库）。
- `.gitignore` 增加 `harmonyos/entry/libs/`、`*.har`。

**验收**：`rm -rf harmonyos/wepei_module/.ohos && flutter build har --debug && python3 scripts/sync_ohos_native.py && devecocli build --build-mode debug` 全链路通过；产物 HAP 功能不变。

### 0.2 删除死代码（0.5d）

| 删除对象 | 位置 | 依据 |
| --- | --- | --- |
| `ImagePickerPlugin.ets` | `entry/src/main/ets/plugins/` | 无注册点，功能已由 `EntryAbility.ets:149` PhotoViewPicker 覆盖 |
| `PickerAbility.ets` + `PickerPage.ets` + `main_pages.json:4` | `ets/pickerability/`、`ets/pages/` | Ability 未注册，`startAbility` 必失败 |
| `WebViewAbility.ets` + `WebPage.ets` + `main_pages.json:5` | `ets/webviewability/`、`ets/pages/` | 同上；WebView 已由 inappwebview fork 承担 |
| `harmonyos/sdcform/` 整目录 | — | 未注册进 modules，且与 entry 的 `SDCFormAbility` 同名冲突 |
| `ets/pages/SDCForm.ets`、`ets/pages/SDCFormCard.ets` | — | `form_widget_config.json:7` 只引用 `ets/widget/pages/` 下的正版 |
| `reason_read_imagevideo` / `reason_write_imagevideo` / `reason_camera` | `AppScope/resources/base/element/string.json:4,12,16` | 对应权限已删，孤儿文案 |

`EntryBackupAbility.ets` **不删**：在 `module.json5` 注册为 `extensionAbilities[type:"backup"]`（2 行），把已有 `backup_config.json` 变成显式可控，也是答辩点。

**验收**：`grep -rn "SDCForm\|PickerPage\|WebPage" harmonyos/entry/src/main/resources/` 无孤儿引用；`devecocli build` 通过；真机课表卡片正常。

### 0.3 版本号单点注入（0.5d）

- 扩展 `scripts/sync_ohos_native.py`：解析根 `pubspec.yaml` 的 `version: 4.6.2+195` → 写 `AppScope/app.json5`（`versionName: "4.6.2"`、`versionCode: 195`），并回写 `wepei_module/pubspec.yaml` 的 version 字段。三处版本只剩一个源。
- `AppScope/app.json5:4` `vendor: "example"` → 改为学校/团队名（待定后填）。

**验收**：改根 pubspec version → 跑 sync → 三处一致；`hdc shell bm dump -n com.weipeiyang.cn | grep versionName`。

### 0.4 签名外部化（1d）

- 新增 `scripts/configure_ohos_signing.py`：
  - 读环境变量 `OHOS_CERT_PATH / OHOS_PROFILE_PATH / OHOS_STORE_FILE / OHOS_KEY_ALIAS / OHOS_KEY_PWD / OHOS_STORE_PWD`；
  - 缺失时回落 DevEco 默认 `~/.ohos/config/default_harmonyos_*.{cer,p7b,p12}` 自动发现（本地零配置可用）；
  - 改写**生成物** `wepei_module/.ohos/build-profile.json5:7-15` 的 signingConfigs（json5 无环境变量插值，只能脚本注入）；
  - 同脚本顺带注入 `compatibleSdkVersion: "5.0.0(12)"` + 新增 `targetSdkVersion: "5.1.0(18)"`，消除与根 build-profile 的不一致。**注意先确认本机 deveco-clt 实际安装的 API 等级，不要盲改。**
- 挂进 `sync_ohos_native.py` 的 `sync()` 末尾（import 直调）。
- 提交 `harmonyos/build-profile.example.json5` 模板；删除根 `build-profile.json5:3-17` 里指向 `C:\Users\lneoo\...` 的死签名块。

**验收**：`env -i`（清空环境变量）跑全链路 → 回落逻辑生效；带正式证书 env → 注入成功；`devecocli build --build-mode release` 出签名包。

---

## Phase 1｜安全与合规剔除（约 2 天）

### 1.1 SSL 放行收敛（0.5d）｜只改镜像

- 镜像 `harmonyos/wepei_module/lib/commons/network/dio_abstract.dart:35` 改为：
  - `EnvConfig.env == Env.DEVELOP` 时才设置 `createHttpClient`，且 `badCertificateCallback` 按 host 白名单放行（`*.twt.edu.cn`）；
  - RELEASE 下不设置 `createHttpClient`。
- 镜像 `dio_abstract.dart:15` 的 `bool get SSL => false` 硬编码一并移除。
- 根 `lib/` **不动**（Android/iOS 行为不在本次范围）。

**验收**：RELEASE 包对自签/错误证书域名请求失败（抓包确认 TLS 拒绝）；DEVELOP 行为不变。

### 1.2 热更新物理剔除（0.5d）

只做运行时短路不够，代码仍在 HAP 内会被静态扫描命中。在**镜像**中：

- 删 `commons/channel/install/`（`install.dart`、`hotfix.dart`）；
- 删 `commons/update/dialog/update_hotfix_dialog.dart`、`update_install_dialog.dart`；
- 删 `commons/test/update_test_page.dart` 及 `test/test_router.dart:17-18` 的注册；
- 删 `update_manager.dart:93,152,231` 三处调用与 `InstallManager`/`HotFixManager` import。
- 根 `lib/` **不动**（Android/iOS 仍需要热修复）。

**验收**：`devecocli build` 后解包，对 `libapp.so` 全文 grep `hot_fix`、`hotfix`、`com.twt.service/install` **零命中**。

### 1.3 死通道调用剔除（0.5d）

- 镜像 `commons/channel/statistics/umeng_statistics.dart:12` 在 OHOS 上会真的 invoke 未注册 channel（被 catchError 吞掉）：改为 `if (kIsOhos) return;` 早退（依赖 Phase 2.1 的 `kIsOhos`，或本任务先内联判断）。
- 同法处理 `push_manager.dart` 中 OHOS 空转分支（`checkNotificationPermission` 只改内存态）：加注释明确「待 Push Kit 接入后替换」，不在本阶段展开。

### 1.4 入校码卡片下线（0.5d）｜默认执行，可否决

密钥用途是**加密请求冒充学校客户端**（`EntryQrService.ets:104-109`：3DES 加密 `method=getAccountQRcodeInfo&ID_NUMBER=<学号>`），非保护用户数据。校方授权落地前先下线：

- 删 `entry/src/main/ets/widget/EntryQrService.ets`、`EntryQrFormAbility`（`module.json5:42-54`）、`qr_form_widget_config.json`、`EntryQrFormCard.ets`；
- 镜像删 `widget_data_sync.dart:78-84` 的 `_triggerEntryQrFormUpdate` 及 `EntryAbility.ets:78-80,361-393` 对应分支；
- `string.json` 删 `form_name_entry_qr`。

**验收**：`grep -r neusofteducationplatform harmonyos/` 零命中；冷启动无卡片报错；课表卡片不受影响。

---

## Phase 2｜kIsOhos 统一 + 漂移回退（约 3 天）

### 2.1 统一平台判断（0.5d）｜只改镜像

- 新增**镜像侧** `harmonyos/wepei_module/lib/commons/util/platform.dart`（登记进比对脚本 allowlist）：

  ```dart
  import 'dart:io' show Platform;
  import 'package:flutter/foundation.dart' show kIsWeb;

  /// 本 fork 的 Platform 无 isOhos，统一在此判断
  const bool kIsOhos = !kIsWeb && (Platform.operatingSystem == 'ohos');
  ```

- 替换**镜像中 14 处** `!Platform.isAndroid && !Platform.isIOS` 启发式：
  `storage_util.dart:8`｜`image_cache_service.dart:178`｜`wpy_pic.dart:70,372`｜`common_prefs.dart:24,341`｜`push_manager.dart:126,166`｜`update_manager.dart:56`（Phase 1.2 后此处已删）｜`update_title.dart:25`｜`update_test_page.dart:41,65`（已删）｜`post_detail_page.dart:737-738`｜`normal_comment_card.dart:194`
- 替换 `wpy_page.dart:350` 的裸字符串判断。
- 修 Windows 误判 bug（`isWindows` 与 `_isOhos` 并存的 `home_page.dart:300` 等）。

### 2.2 B3 类漂移回退（1.5d）｜原则 1

| 处理 | 文件 | 说明 |
| --- | --- | --- |
| 成对回退 | `lake_notifier.dart:303-318` + `normal_sub_page.dart` | root 的 `LakePageController` 可空 + attach/detach 重构与去抖修复，必须一起迁 |
| 直接回退 | `feedback_router.dart:60` + `festival_page.dart` | `FestivalPage(args, context: context)` 新签名 |
| 直接回退 | `home_page.dart:175-180` | OHOS 的 `DateTime.tryParse(...)!` + try/catch 是错误写法 |
| 直接回退 | `remote_config_manager.dart:7-25` | root 的 `_loadFuture` 去重缓存版 |
| 合并（保留 OHOS 分支） | `toast_provider.dart` | **不直接覆盖**：root 用 fluttertoast（OHOS 无实现），OHOS 自造 Overlay 版。在镜像中保留现状，root 不动 |
| 保留 | `user_avatar_image.dart`、`summary_page.dart`+`wby_webview.dart`、`router_manager.dart`（`navigatorKey` 被依赖） | 必要降级/强耦合，不动 |

> 原计划中「OHOS 写法更好的 4 处（`file_log_output.dart:89` 等）反向回灌根 `lib/`」一项**取消**——根 `lib/` 本次保持只读。这些差异保留在镜像中并登记 allowlist 即可。

**不做**（被版本锁死，回退即编译失败）：B1 类 8 个（`MaterialStateProperty` 等老 API，SDK 旧）、B2 类 4 个（`onReorder`/`MasonryGridView`/`ConnectivityResult`，依赖解析到旧版）。

### 2.3 修比对脚本假阴性（0.5d）

`scripts/compare_ohos_flutter.py:275` 只要在文件**任意位置**出现 marker 就把全部普通 hunk 判为 `OHOS_CONTEXT`。改为：**差异行本身**含 marker 才算 OHOS 适配，否则标记 requiring review。修完后重跑 `--strict`，处理新暴露的 review 项（应与 2.2 的 B3 清单一致，作为交叉验证）。

---

## Phase 3｜插件补齐：消灭 MissingPluginException（约 5 天）

### 3.1 崩点清单（按崩溃面排序）

| 优先级 | 崩点 | 触发场景 | 包 |
| --- | --- | --- | --- |
| P0 | `lake_privacy_dialog.dart:74-75,92-93,110-111` | **首启隐私弹窗点协议链接必崩** | url_launcher |
| P0 | `speech_record_manager.dart:16,5,10` | 小天语音输入整体崩 | permission_handler + record |
| P1 | `avatar_crop_page.dart:94,47,97` | 换头像拍照/裁剪 | image_picker + image_cropper |
| P1 | `home_page.dart:631-632`（湖底 banner）、`activity_card.dart:61-62`、`open_the_box.dart:115` | 外链点击 | url_launcher |
| P2 | `image_view_page.dart:257` | 分享图片 | share_plus |
| P2 | `debug_info_page.dart:98` | 调试页 | package_info_plus |

已确认**有兜底不崩、无需处理**：其余全部 url_launcher 调用（`.catchError`）、`path_provider`（`storage_util.dart:20` 短路 + `image_save.dart:44` try/catch）、`shared_preferences`（`MockSharedPreferences`）、`connectivity_plus`（try/catch）、`cached_network_image`（`wpy_pic.dart:368` 已绕过）、`gallery_saver_plus`（仅 import）。

### 3.2 逐包方案（原则 1 → 2 → 3）

**url_launcher**（1d）
1. 原则 2：`OpenHarmony-TPC/flutter_packages` 有 ohos 分支（命名 `br_url_launcher-v*_ohos`），加 `dependency_overrides`（git + pin ref）。⚠️ 生态宣布「全面支持 3.27」，我们是 3.41.9 fork，**需逐个真机验证**。
2. 原则 1 兜底（不兼容时）：新建镜像侧薄封装 `commons/util/url_launcher_ohos.dart`，`kIsOhos` 时走已有 `webview_page.dart:12` 的 `openUrlInApp` / `EntryAbility` 的 `openLink`，批量替换 13 个调用文件。

**image_picker + image_cropper**（1.5d）
1. 原则 2：AtomGit `openharmony-sig/fluttertpc_image_picker`（`image_picker_ohos ^1.0.4`）、`openharmony-sig/fluttertpc_image_cropper`（path `./image_cropper/ohos`）。
2. 原则 1 兜底：`avatar_crop_page` 改用已有 `ImageSave.pickImagesFromGallery()`（`new_post_page.dart:1133` 现成范式，走系统 Picker 免权限），裁剪步骤降级为直接上传。

**permission_handler + record（小天语音）**（1.5d）
1. 原则 2：先查 `fluttertpc_permission_handler` 是否存在（AtomGit `openharmony-sig/` 下）。
2. `record` 大概率无 OHOS 适配 → 原则 3 手写：
   - ArkTS：`entry/src/main/ets/speech/SpeechRecordPlugin.ets`，注册 channel `com.twt.service/speech_record`，用 `@kit.MediaKit` 的 AVRecorder 实现 start/stop/isRecording，返回音频文件路径；麦克风权限走系统弹窗或 `requestPermissionsFromUser`（需在 `module.json5` 声明 `ohos.permission.MICROPHONE` + reason）。
   - Dart：镜像 `speech_record_manager.dart` 加 `kIsOhos` 分支走自建 channel。
   - 若时间不足：OHOS 上隐藏语音入口（改 `chat_widget.dart` 一处判断）。

**share_plus**（0.5d）
1. 原则 2：查 `OpenHarmony-SIG/flutter_plus_plugins` 是否含 share_plus ohos。
2. 原则 3 兜底：ArkTS 用 `systemShare`（`@kit.ShareKit`）实现 channel `com.twt.service/share`（Dart 侧 `commons/channel/share/` 已有骨架）。

**package_info_plus**（0.5d，低优先）
- 原则 2：`OpenHarmony-SIG/flutter_plus_plugins` 有 package_info_plus 适配（GUIDE_DOCUMENT 以它为例）。仅调试页用，可最后做或跳过。

**每个包的验收**：真机触发对应场景 + logcat 无 `MissingPluginException`；`flutter analyze` 通过；`.flutter-plugins-dependencies` 中该包出现 ohos 实现。

### 3.3 依赖接入约定

所有 git 依赖统一写入 `wepei_module/pubspec.yaml` 的 `dependency_overrides`，**必须 pin ref**（如 `ref: br_url_launcher-v6.3.0_ohos`），与现有 flutter_inappwebview 写法一致。禁止新增 `any`。

---

## Phase 4｜上架字段收口（约 1 天）

1. `entry/src/main/module.json5:8-11` `deviceTypes` 收为 `["phone"]`（sdcform 已在 Phase 0.2 删除；平板真适配是 8–15 天的独立工程，声明与实现不符是审核直接驳回点）。
2. 权限文案复核：READ_PASTEBOARD 的 reason + usedScene 已合规；确认无新增权限残留。
3. 隐私文案对齐：`harmonyos/wepei_module/privacy/` 与 `lib/auth/view/privacy/` 的第三方 SDK 清单改写为实际集成集（photo_manager、flutter_inappwebview_ohos、自建 MethodChannel、Phase 3 新增的插件），删除个推/友盟条目。
4. 新增 `NOTICE` / 第三方库许可证文件，挂「关于」页入口。
5. 切 `oh-3.41.9-release` 并 pin commit，全链路回归。

**验收门禁（上架前总检）**：对 release HAP 解包 grep：`neusofteducationplatform`、`hot_fix`、`hotfix`、`com.twt.service/install`、`umeng`、`getui` 全部**零命中**；真机回归 DEVELOPMENT_GUIDE §8 清单 + 隐私弹窗链接、换头像、语音输入、分享。

---

## Phase 5｜鸿蒙特色加分（时间富余才做，按性价比排序）

| # | 事项 | 工作量 | 要点 |
| --- | --- | --- | --- |
| 1 | 服务卡片增强 | 2–3d | 4×4：`form_widget_config.json:18` 的 `supportDimensions` 加 `"4*4"` + `@LocalStorageProp('formDimension')` 分档布局（已绑定 `SDCFormBinding`）；点击直达：`postCardAction(this, {action:'router', abilityName:'EntryAbility', params:{route:'schedule/course'}})`（已去除前导斜杠对齐 RouterManager）→ `onCreate/onNewWant` 增加 `extractCardRoute`（支持嵌套 JSON params）→ 通过 `com.twt.service/push` 通道推给 Flutter（冷启动延后至 `_navigateToEntry` 进入首页后压栈，彻底解决 900ms 定时器冲刷问题）。 |
| 2 | Push Kit | 3–5d | ArkTS：`PushService.ets`（`@hms.core.push.pushService` getToken），`EntryAbility.ets` 注册 channel `com.twt.service/push`（含 initPush/getToken/turnOn/turnOff）；Dart：`push_manager.dart` OHOS 分支真调；前置：AGC 开 Push 服务 + `module.json5` metadata 加 `client_id`（配置属资质侧） |

---

## 6. 时间汇总

| 阶段 | 工作量 | 产出 | 状态 |
| --- | --- | --- | --- |
| Phase 0 地基 | 2.5d | 可复现构建、仓库瘦身 70MB、死代码清零 | ✅ 完成 |
| Phase 1 合规 | 2d | HAP grep 门禁全绿（密钥/热修/安装通道清零） | ✅ 完成 |
| Phase 2 回退 | 3d | kIsOhos 统一、镜像与 lib 对齐、比对脚本收紧 | ✅ 完成 |
| Phase 3 插件 | 5d | url_launcher/package_info_plus 接 OHOS 适配包；语音/头像/分享崩溃点兜底 | ✅ 完成 |
| Phase 4 收口 | 1d | deviceTypes 收 phone、NOTICE、版本/签名单点注入 | ✅ 完成 |
| **合计（代码必做）** | **约 13.5 人日** | | |
| Phase 5 加分 | 10–16d | 卡片 4×4+点击直达 ✅、Push Kit 骨架 ✅（元服务按团队决定移除） | 部分 |

## 7. 待确认与移交（非代码事项）

1. **`vendor` / `bundleName` 主体**：`AppScope/app.json5` 的 `vendor: "example"` 需资质侧确认主体后填写；`com.weipeiyang.cn` 上架后不可改。
2. **SDK 版本取值**：当前 `compatibleSdkVersion: 5.1.0(18)`、未显式声明 `targetSdkVersion`；建议资质侧结合上架要求确认是否抬 `targetSdkVersion`（本机无法判定可编译最高 API）。
3. **入校码（应用内）**：ArkTS 卡片与硬编码 3DES 已下线；但 `cas_service.dart`（root 与镜像都有）仍用于**应用内**入校码功能——若校方授权落地，改服务端下发；否则考虑下线应用内入口。**决策待定。**
4. **隐私政策 SDK 清单**：`privacy/privacy_content.md` 罗列了 Android 版 SDK（友盟/个推/岳鹰等），OHOS 版未集成；文档为学校官方文本，**是否增补 OHOS 版差异由天外天确认**，未擅改。
5. **Push Kit**：ArkTS+Dart 骨架已接；需 AGC 开通 Push 服务、配 `client_id` 与 `agconnect-services.json` 后真机验证。
6. **通知权限文案**：Push 通知需在隐私政策补充说明（跟随第 4 项一并处理）。
7. **生态包验证**：`url_launcher`/`package_info_plus` 的 OHOS 适配包已编译进 Release HAP，并在真机 `HUAWEI Pura 70 Pro`（`HBN-AL00 6.1.0.135`）成功安装与拉起运行（PID: 29402）。

## 8. 遗留说明

- 比对脚本 `--strict` 通过；`cas_service.dart` 的入校码密钥属于**产品决策项**，比对脚本已按适配分类，不阻断门禁。
- `commons/util/log/log.dart`（OHOS 版 `Log`）与 root 的 `Logger` 并存：镜像内网络/网络层混用，已按各文件 root 原样对齐（`Log.e`），后续 root 若统一日志类需再同步。

