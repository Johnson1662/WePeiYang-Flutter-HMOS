import 'dart:convert';

import 'package:wepei_module/commons/channel/image_save/image_save.dart';
import 'package:wepei_module/commons/channel/remote_config/config/webview.dart';
import 'package:wepei_module/commons/channel/share/share.dart';
import 'package:wepei_module/commons/util/logger.dart';
import 'package:wepei_module/commons/util/toast_provider.dart';

class ShareChannel {
  static WebViewChannelConfig config(String page, {bool album = false}) {
    return WebViewChannelConfig('WbyShareChannel', (message) async {
      try {
        final bytes = base64.decode(message.split(',')[1]);
        final fileName = '$page${DateTime.now().millisecondsSinceEpoch}.jpg';
        final path = await ImageSave.saveImageFromBytes(
          bytes,
          fileName,
          album: album,
        );
        await ShareManager.shareImgToQQ(path);
      } catch (error, stack) {
        Logger.reportError(error, stack);
        ToastProvider.error('分享失败');
      }
    });
  }
}
