import 'dart:convert';

import 'package:wepei_module/commons/channel/image_save/image_save.dart';
import 'package:wepei_module/commons/channel/remote_config/config/webview.dart';
import 'package:wepei_module/commons/util/logger.dart';
import 'package:wepei_module/commons/util/toast_provider.dart';

class ImgSaveChannel {
  static WebViewChannelConfig config(String page) {
    return WebViewChannelConfig('WbyImgSaveChannel', (message) async {
      try {
        final bytes = base64.decode(message.split(',')[1]);
        final fileName = '$page${DateTime.now().millisecondsSinceEpoch}.jpg';
        await ImageSave.saveImageFromBytes(bytes, fileName, album: true);
        ToastProvider.success('保存成功');
      } catch (error, stack) {
        Logger.reportError(error, stack);
        ToastProvider.error('图片保存失败');
      }
    });
  }
}
