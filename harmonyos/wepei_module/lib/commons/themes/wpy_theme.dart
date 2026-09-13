import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:wepei_module/commons/preferences/common_prefs.dart';
import 'package:wepei_module/commons/themes/template/wpy_theme_data.dart';

class WpyTheme extends InheritedWidget {
  final WpyThemeData themeData;

  WpyTheme({required super.child, required this.themeData});

  static WpyTheme? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<WpyTheme>();
  }

  static WpyTheme of(BuildContext context) {
    final WpyTheme? result = maybeOf(context);
    assert(result != null, 'No WpyTheme found in context');
    return result!;
  }

  @override
  bool updateShouldNotify(covariant WpyTheme oldWidget) {
    return oldWidget.themeData.meta.themeId != themeData.meta.themeId;
  }

  static bool get isSystemDarkMode {
    return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
        Brightness.dark;
  }

  static Future<bool> isDarkMode([BuildContext? context]) async {
    if (Platform.isIOS) {
      // 使用iOS原生代码检测是否启用了暗黑模式
      bool isDarkModeEnabled = await iOSThemeService.isDarkModeEnabled();
      return isDarkModeEnabled;
    } else {
      // 权威系统亮度源，直接从 PlatformDispatcher 读取，无需 context，毫秒级响应
      return isSystemDarkMode;
    }
  }

  Color? get primary => themeData.data.primaryColor;

  String get name => themeData.meta.name;

  String get darkThemeId => themeData.meta.darkThemeId;

  Color get(WpyColorKey key) {
    return themeData.data.get(key);
  }

  List<Color> getColorSet(WpyColorSetKey key) {
    return themeData.data.getColorSet(key) as List<Color>;
  }

  Gradient getGradient(WpyColorSetKey key) {
    return themeData.data.getColorSet(key) as Gradient;
  }

  get isDarkTheme => themeData.meta.brightness == Brightness.dark;

  Brightness get brightness => themeData.meta.brightness;

  static void init() {
    final themeId = CommonPreferences.appThemeId.value;
    final darkThemeId = CommonPreferences.appDarkThemeId.value;
    int brightness = CommonPreferences.usingDarkTheme.value;
    // 若开启跟随系统，冷启动首帧直接对齐当前系统亮度，彻底解决深色下冷启动闪白
    if (CommonPreferences.autoDarkTheme.value) {
      brightness = isSystemDarkMode ? 1 : 0;
      CommonPreferences.usingDarkTheme.value = brightness;
    }
    final theme = WpyThemeData.themeList.firstWhere((element) {
      return element.meta.themeId == (brightness == 0 ? themeId : darkThemeId);
    }, orElse: () => WpyThemeData.themeList[0]);
    globalTheme.value = theme;
  }

  static WpyThemeData themeById(String themeId, {Brightness? brightness}) {
    return WpyThemeData.themeList.firstWhere((element) {
      return element.meta.themeId == themeId &&
          (brightness == null || element.meta.brightness == brightness);
    }, orElse: () {
      return brightness == Brightness.dark
          ? WpyThemeData.darkThemeList[0]
          : WpyThemeData.brightThemeList[0];
    });
  }

  static void applyStoredTheme({required Brightness brightness}) {
    final themeId = brightness == Brightness.dark
        ? CommonPreferences.appDarkThemeId.value
        : CommonPreferences.appThemeId.value;
    globalTheme.value = themeById(themeId, brightness: brightness);
    CommonPreferences.usingDarkTheme.value =
        brightness == Brightness.dark ? 1 : 0;
  }

  static Future<void> updateAutoDarkTheme([BuildContext? context]) async {
    if (!CommonPreferences.autoDarkTheme.value) return;

    if (await isDarkMode(context)) {
      if (globalTheme.value.meta.brightness == Brightness.light) {
        applyStoredTheme(brightness: Brightness.dark);
      }
    } else {
      if (globalTheme.value.meta.brightness == Brightness.dark) {
        applyStoredTheme(brightness: Brightness.light);
      }
    }
  }
}

extension BrightnessSystemUiOverlay on Brightness {
  get uiOverlay => this == Brightness.light
      ? SystemUiOverlayStyle.light
      : SystemUiOverlayStyle.dark;

  get reverseUiOverlay => this == Brightness.dark
      ? SystemUiOverlayStyle.light
      : SystemUiOverlayStyle.dark;
}

final globalTheme = ValueNotifier(WpyThemeData.themeList[0]);

class iOSThemeService {
  static const channel = MethodChannel('com.twt.service/theme');

  static Future<bool> isDarkModeEnabled() async {
    final bool isDarkMode = await channel.invokeMethod('isDarkMode');
    return isDarkMode;
  }
}
