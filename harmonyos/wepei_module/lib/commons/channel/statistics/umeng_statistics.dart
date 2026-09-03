import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:wepei_module/commons/util/logger.dart';
import 'package:wepei_module/commons/util/platform.dart';

/// 友盟统计桥接。
///
/// OHOS 端**未集成**友盟 SDK（无 `com.twt.service/umeng_statistics` 原生实现），
/// 所有方法在 OHOS 上直接返回，避免向未注册的 MethodChannel 发起调用。
/// Android/iOS 实现见根 lib/ 同名文件。
class UmengCommonSdk {
  static const MethodChannel _channel =
      const MethodChannel('com.twt.service/umeng_statistics');

  static Future<void> initCommon() async {
    if (kIsOhos) return;
    if (!Platform.isIOS)
      await _channel.invokeMethod('initCommon').catchError(printError);
    // iOS自动初始化
  }

  static void onEvent(String event, Map<String, dynamic> properties) {
    if (kIsOhos) return;
    List<dynamic> args = [event, properties];
    _channel.invokeMethod('onEvent', args).catchError(printError);
  }

  static void onPageStart(String viewName) {
    if (kIsOhos) return;
    _channel
        .invokeMethod('onPageStart', {"page": viewName}).catchError(printError);
  }

  static void onPageEnd(String viewName) {
    if (kIsOhos) return;
    _channel
        .invokeMethod('onPageEnd', {"page": viewName}).catchError(printError);
  }

  static void reportError(String error) {
    if (kIsOhos) return;
    _channel
        .invokeMethod('reportError', {"error": error}).catchError(printError);
  }

  static void onProfileSignIn(String userID) {
    if (kIsOhos) return;
    _channel.invokeMethod(
        'onProfileSignIn', {"userID": userID}).catchError(printError);
  }

  static void onProfileSignOff() {
    if (kIsOhos) return;
    _channel.invokeMethod('onProfileSignOff').catchError(printError);
  }

  static void printError(e, s) => Logger.reportError(e, s);
}
