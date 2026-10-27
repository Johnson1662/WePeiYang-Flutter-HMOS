import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wepei_module/auth/view/settings/setting_page.dart';
import 'package:wepei_module/commons/environment/config.dart';
import 'package:wepei_module/commons/preferences/common_prefs.dart';
import 'package:wepei_module/commons/themes/wpy_theme.dart';
import 'package:wepei_module/commons/util/router_manager.dart';
import 'package:wepei_module/commons/util/toast_provider.dart';

const _channel = MethodChannel('com.twt.service/saveImg');

Future<void> _openSettings(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({});
  await CommonPreferences.init();
  EnvConfig.init();
  WpyTheme.init();
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('com.twt.service/local_setting'),
    (_) async => '4.6.3',
  );
  addTearDown(() async {
    ToastProvider.cancelCurrent();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
  });
  await tester.pumpWidget(ScreenUtilInit(
    designSize: const Size(390, 844),
    builder: (_, child) => WpyTheme(
      themeData: globalTheme.value,
      child: MaterialApp(
        navigatorKey: RouterManager.navigatorKey,
        home: SettingPage(),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('pending update check rejects duplicate taps and reports no update',
      (tester) async {
    final query = Completer<bool>();
    var checks = 0;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      _channel,
      (_) {
        checks++;
        return query.future;
      },
    );
    await _openSettings(tester);
    await tester.tap(find.text('检查更新'));
    await tester.pump();
    expect(find.text('正在检查更新…'), findsOneWidget);
    await tester.tap(find.text('正在检查更新…'));
    await tester.pump();
    expect(checks, 1);
    query.complete(false);
    await tester.pumpAndSettle();
    expect(find.text('应用市场暂无更新版本'), findsOneWidget);
    expect(find.text('检查更新'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets('unavailable market does not claim latest and allows retry',
      (tester) async {
    var unavailable = true;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      _channel,
      (_) async {
        if (unavailable) {
          throw PlatformException(code: 'APP_UPDATE_UNAVAILABLE', details: '-1');
        }
        return false;
      },
    );
    await _openSettings(tester);
    await tester.tap(find.text('检查更新'));
    await tester.pumpAndSettle();
    expect(find.text('应用市场暂未提供该应用，无法检查更新'), findsOneWidget);
    expect(find.text('应用市场暂无更新版本'), findsNothing);
    unavailable = false;
    await tester.tap(find.text('检查更新'));
    await tester.pumpAndSettle();
    expect(find.text('应用市场暂无更新版本'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets('timed out market query reports timeout and releases the entry',
      (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      _channel,
      (_) => Completer<bool>().future,
    );
    await _openSettings(tester);
    await tester.tap(find.text('检查更新'));
    await tester.pump();
    expect(find.text('正在检查更新…'), findsOneWidget);
    await tester.pump(const Duration(seconds: 16));
    await tester.pumpAndSettle();
    expect(find.text('检查更新超时，请稍后重试'), findsOneWidget);
    expect(find.text('应用市场暂无更新版本'), findsNothing);
    expect(find.text('检查更新'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets('dialog failure is an error and a shown dialog is not no-update',
      (tester) async {
    var dialogFails = true;
    final dialog = Completer<void>();
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      _channel,
      (call) async {
        if (call.method == 'checkAppUpdate') return true;
        if (dialogFails) {
          throw PlatformException(code: 'APP_UPDATE_DIALOG_FAILED');
        }
        await dialog.future;
        return null;
      },
    );
    await _openSettings(tester);
    await tester.tap(find.text('检查更新'));
    await tester.pumpAndSettle();
    expect(find.text('暂无法检查更新，请稍后重试'), findsOneWidget);
    expect(find.text('应用市场暂无更新版本'), findsNothing);
    dialogFails = false;
    await tester.tap(find.text('检查更新'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 20));
    expect(find.text('正在检查更新…'), findsOneWidget);
    dialog.complete();
    await tester.pumpAndSettle();
    expect(find.text('检查更新'), findsOneWidget);
    expect(find.text('应用市场暂无更新版本'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
