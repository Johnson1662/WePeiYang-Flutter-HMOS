import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wepei_module/auth/view/login/login_page.dart';
import 'package:wepei_module/commons/channel/push/push_manager.dart';
import 'package:wepei_module/commons/environment/config.dart';
import 'package:wepei_module/commons/preferences/common_prefs.dart';
import 'package:wepei_module/commons/themes/wpy_theme.dart';
import 'package:wepei_module/commons/util/storage_util.dart';
import 'package:wepei_module/main.dart';
import 'package:wepei_module/schedule/page/course_page.dart';

void main() {
  testWidgets('widget launch initializes before navigation and stays responsive',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.platformDispatcher.defaultRouteNameTestValue = 'schedule/course';
    addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);
    final storage = Directory.systemTemp.createTempSync('wpy-card-test-');
    addTearDown(() => storage.deleteSync(recursive: true));
    StorageUtil.downloadDir = storage;
    StorageUtil.filesDir = storage;
    StorageUtil.tempDir = storage;
    StorageUtil.photoDir = storage;
    SharedPreferences.setMockInitialValues({'firstPrivacy': false});
    await CommonPreferences.init();
    EnvConfig.init();
    WpyTheme.init();

    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('com.twt.service/saveImg'),
      (_) async => true,
    );
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('com.twt.service/cloud_config'),
      (_) async => <Map<String, Object>>[],
    );

    await tester.pumpWidget(const WePeiYangApp());
    expect(tester.takeException(), isNull);
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byType(CoursePage), findsNothing);

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.byType(LoginHomeWidget), findsOneWidget);
    expect(find.byType(CoursePage), findsNothing);
    expect(tester.takeException(), isNull);

    // 首页会创建 PushManager；它不能覆盖卡片共用的原生事件接收器。
    final pushManager =
        tester.element(find.byType(LoginHomeWidget)).read<PushManager>();
    pushManager.openPush = true;
    tester.binding.channelBuffers.push(
      'com.twt.service/push',
      const StandardMethodCodec()
          .encodeMethodCall(const MethodCall('refreshPushPermission')),
      (_) {},
    );
    await tester.pump();
    expect(pushManager.openPush, isFalse);

    CommonPreferences.isLogin.value = true;
    CommonPreferences.isBindTju.value = true;
    tester.binding.channelBuffers.push(
      'com.twt.service/push',
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall('openRoute', {'route': 'schedule/course'}),
      ),
      (_) {},
    );
    await tester.pumpAndSettle();
    expect(find.byType(CoursePage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
