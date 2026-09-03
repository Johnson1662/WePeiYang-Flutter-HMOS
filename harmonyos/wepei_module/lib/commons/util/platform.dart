import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// 当前是否运行在 OpenHarmony（HarmonyOS NEXT）上。
///
/// 本工程使用的 Flutter SDK 分支（openharmony-tpc/flutter_flutter）**没有**
/// `Platform.isOhos`，此前各处用 `!Platform.isAndroid && !Platform.isIOS` 判断，
/// 会把 Windows/macOS/Linux 桌面端误判为 OHOS。统一在此判断。
final bool kIsOhos = !kIsWeb && Platform.operatingSystem == 'ohos';
