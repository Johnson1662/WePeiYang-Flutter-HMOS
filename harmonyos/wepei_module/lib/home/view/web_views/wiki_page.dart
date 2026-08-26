import 'package:flutter/material.dart';
import 'package:wepei_module/commons/widgets/webview_page.dart';

class WikiPage extends StatelessWidget {
  static const URL = 'https://wiki.tjubot.cn/';

  @override
  Widget build(BuildContext context) {
    return const WebViewPage(
      url: URL,
      title: '北洋维基',
    );
  }
}
