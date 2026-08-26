import 'package:flutter/material.dart';
import 'package:wepei_module/commons/widgets/webview_page.dart';

class AboutTwtPage extends StatelessWidget {
  static const URL = 'https://www.twt.edu.cn/';

  const AboutTwtPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const WebViewPage(
      url: URL,
      title: '关于天外天',
    );
  }
}
