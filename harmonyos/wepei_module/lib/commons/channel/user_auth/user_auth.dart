import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:wepei_module/commons/util/platform.dart';

/// 鸿蒙原生 User Authentication Kit（生物特征人脸/指纹/锁屏密码认证）通道封装
class UserAuth {
  static const MethodChannel _channel =
      MethodChannel('com.twt.service/user_auth');

  /// 发起生物特征身份认证（指纹/人脸/锁屏PIN码）。
  /// 在非鸿蒙设备上直接返回 true（不拦截）；
  /// 在鸿蒙设备上拉起系统统一认证弹窗，认证成功返回 true，用户取消或认证失败返回 false。
  static Future<bool> authenticate({String title = '验证以查看个人成绩'}) async {
    if (!kIsOhos) return true;
    try {
      final res = await _channel.invokeMethod<bool>(
        'authenticate',
        {'title': title},
      ).timeout(const Duration(minutes: 1));
      return res ?? false;
    } catch (e) {
      debugPrint('[UserAuth] authenticate error: $e');
      return false;
    }
  }

  /// 检查设备是否具备生物认证能力
  static Future<bool> isBiometricAvailable() async {
    if (!kIsOhos) return false;
    try {
      final res =
          await _channel.invokeMethod<bool>('isBiometricAvailable');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }
}
