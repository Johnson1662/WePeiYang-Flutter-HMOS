import 'package:wepei_module/commons/webview/javascript_channels/img_save_channel.dart';
import 'package:wepei_module/commons/webview/javascript_channels/share_channel.dart';

typedef WebViewMessageHandler = Future<void> Function(String message);

class WebViewChannelConfig {
  final String name;
  final WebViewMessageHandler onMessageReceived;

  const WebViewChannelConfig(this.name, this.onMessageReceived);
}

class WebViewConfig {
  final String page;
  final String url;
  final List<WebViewChannelConfig> channels;

  WebViewConfig._(this.page, this.url, this.channels);

  factory WebViewConfig.fromJson(Map map) {
    final page = map['page'] ?? '';
    final url = map['url'] ?? '';
    final channels = <WebViewChannelConfig>[];

    for (final channel in '${map['channels']}'.split(',')) {
      if (channel == WebViewChannels.share.value) {
        channels.add(ShareChannel.config(page));
      } else if (channel == WebViewChannels.saveImg.value) {
        channels.add(ImgSaveChannel.config(page));
      }
    }

    return WebViewConfig._(page, url, channels);
  }
}

enum WebViewChannels { share, saveImg }

extension WebViewChannelsExt on WebViewChannels {
  String get value => ['share', 'saveImg'][index];
}
