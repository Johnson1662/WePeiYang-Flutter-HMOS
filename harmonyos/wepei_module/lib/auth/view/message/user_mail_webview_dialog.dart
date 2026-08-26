import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:wepei_module/commons/themes/template/wpy_theme_data.dart';

import '../../../commons/themes/wpy_theme.dart';

class UserMailDialog extends Dialog {
  final String url;

  UserMailDialog(this.url);

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Container(
            height: 500,
            width: 300,
            color: WpyTheme.of(context).get(WpyColorKey.primaryBackgroundColor),
            child: CustomWebView(url),
          ),
        ),
      ),
    );
  }
}

class CustomWebView extends StatefulWidget {
  final String url;

  CustomWebView(this.url);

  @override
  _CustomWebViewState createState() => _CustomWebViewState();
}

class _CustomWebViewState extends State<CustomWebView> {
  @override
  Widget build(BuildContext context) {
    return InAppWebView(
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        domStorageEnabled: true,
        databaseEnabled: true,
        useWideViewPort: true,
        supportZoom: true,
        cacheEnabled: true,
        clearCache: false,
      ),
      onWebViewCreated: (controller) async {
        await controller.loadUrl(
          urlRequest: URLRequest(url: WebUri(widget.url)),
        );
      },
    );
  }
}
