import 'package:flutter/material.dart';
import 'package:wepei_module/commons/preferences/common_prefs.dart';
import 'package:wepei_module/commons/widgets/webview_page.dart';

class FiftyTwoHzPage extends StatelessWidget {
  final String url =
      'https://52Hz.twt.edu.cn/#/?token=${CommonPreferences.token.value}';

  @override
  Widget build(BuildContext context) {
    return WebViewPage(
      url: url,
      title: '52赫兹',
    );
  }
}
