import 'package:flutter/services.dart';

const _channel = MethodChannel('com.twt.service/saveImg');

/// 有新版时显示 AppGallery 官方升级弹窗；仅明确无新版时返回 false。
Future<bool> checkAppUpdate() async {
  final available = await _channel
      .invokeMethod<bool>('checkAppUpdate')
      .timeout(const Duration(seconds: 15));
  if (available == null) {
    throw StateError('应用市场未返回检查结果');
  }
  if (available) {
    // 升级弹窗由用户操作结束，不把交互等待计入版本查询超时。
    await _channel.invokeMethod<void>('showAppUpdateDialog');
  }
  return available;
}
