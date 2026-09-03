import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wepei_module/commons/util/platform.dart';
import 'package:wepei_module/commons/util/toast_provider.dart';
import 'package:wepei_module/commons/widgets/webview_page.dart';

/// OHOS 安全打开外链的统一入口。
///
/// 优先使用 url_launcher（已接 openharmony-tpc 的 OHOS 适配版）；若目标
/// 无法被系统处理（canLaunchUrl/launchUrl 抛异常或返回 false），OHOS 上
/// 回退为应用内 WebView，其余平台提示检查网络。
Future<void> launchUrlSafe(BuildContext context, String url) async {
  try {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
      return;
    }
  } catch (_) {
    // 无 OHOS 实现的场景会抛 MissingPluginException，走回退
  }
  if (kIsOhos) {
    openUrlInApp(context, url);
    return;
  }
  ToastProvider.error('请检查网络状态');
}
