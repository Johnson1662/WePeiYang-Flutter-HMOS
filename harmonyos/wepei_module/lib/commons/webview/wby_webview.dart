import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';
import 'package:wepei_module/commons/channel/remote_config/config/webview.dart';
import 'package:wepei_module/commons/channel/remote_config/remote_config_manager.dart';
import 'package:wepei_module/commons/channel/statistics/umeng_statistics.dart';
import 'package:wepei_module/commons/util/text_util.dart';
import 'package:wepei_module/commons/util/toast_provider.dart';
import 'package:wepei_module/commons/widgets/loading.dart';

import '../themes/template/wpy_theme_data.dart';
import '../themes/wpy_theme.dart';
import '../widgets/w_button.dart';

class WbyWebView extends StatefulWidget {
  final String page;
  final bool fullPage;
  final WpyColorKey backgroundColor;

  const WbyWebView({
    super.key,
    required this.page,
    required this.fullPage,
    required this.backgroundColor,
  });

  @override
  WbyWebViewState createState() => WbyWebViewState();
}

enum _PageState { initUrl, initError, initWebView, showWebView }

class WbyWebViewState extends State<WbyWebView> {
  _PageState state = _PageState.initUrl;
  InAppWebViewController? _controller;

  @override
  void initState() {
    super.initState();
    UmengCommonSdk.onPageStart('webview/${widget.page}');
  }

  @override
  void dispose() {
    _controller = null;
    UmengCommonSdk.onPageEnd('webview/${widget.page}');
    super.dispose();
  }

  PreferredSizeWidget get appBar => AppBar(
        title: Text(
          widget.page,
          style: TextUtil.base.primary(context).sp(16),
        ),
        elevation: 0,
        toolbarHeight: 40,
        centerTitle: true,
        backgroundColor:
            WpyTheme.of(context).get(WpyColorKey.primaryBackgroundColor),
        leading: Padding(
          padding: const EdgeInsets.only(left: 15),
          child: WButton(
            child: Icon(
              Icons.arrow_back,
              color: WpyTheme.of(context).get(WpyColorKey.oldActionColor),
              size: 32,
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      );

  Future<String?> getInitialUrl(BuildContext context) async {
    return context.read<RemoteConfig>().webViews[widget.page]?.url;
  }

  List<WebViewChannelConfig> getJsChannels() {
    return context.read<RemoteConfig>().webViews[widget.page]?.channels ??
        const <WebViewChannelConfig>[];
  }

  void _registerChannels(InAppWebViewController controller) {
    for (final channel in getJsChannels()) {
      controller.addJavaScriptHandler(
        handlerName: channel.name,
        callback: (arguments) {
          final message = arguments.isEmpty ? '' : '${arguments.first ?? ''}';
          return channel.onMessageReceived(message);
        },
      );
    }
  }

  Future<void> _installLegacyChannelBridge(
      InAppWebViewController controller) async {
    final names = getJsChannels().map((channel) => channel.name).toList();
    if (names.isEmpty) return;

    try {
      final encodedNames = jsonEncode(names);
      await controller.evaluateJavascript(source: '''
(function(names) {
  names.forEach(function(name) {
    var channel = window[name] || {};
    channel.postMessage = function(message) {
      if (window.flutter_inappwebview &&
          window.flutter_inappwebview.callHandler) {
        return window.flutter_inappwebview.callHandler(name, message);
      }
      return null;
    };
    window[name] = channel;
  });
})($encodedNames);
''');
    } catch (_) {}
  }

  Future<void> initUrl() async {
    if (!mounted) return;
    if (state == _PageState.initError) {
      setState(() => state = _PageState.initUrl);
    }

    String? url;
    try {
      url = await getInitialUrl(context);
    } catch (_) {}
    if (!mounted) return;

    final controller = _controller;
    if (url == null || url.isEmpty || controller == null) {
      setState(() => state = _PageState.initError);
      return;
    }

    setState(() => state = _PageState.initWebView);
    try {
      await controller.loadUrl(
        urlRequest: URLRequest(url: WebUri(url)),
      );
    } catch (_) {
      if (mounted) setState(() => state = _PageState.initError);
    }
  }

  Future<void> _handleBack() async {
    final controller = _controller;
    if (controller != null && await controller.canGoBack()) {
      await controller.goBack();
      return;
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final top = state == _PageState.initError
        ? WButton(onPressed: initUrl, child: const Text('遇到错误请重试'))
        : const Loading();
    final body = Stack(
      fit: StackFit.expand,
      alignment: Alignment.center,
      children: [
        Opacity(
          opacity: state == _PageState.showWebView ? 1.0 : 0.0,
          child: InAppWebView(
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              javaScriptCanOpenWindowsAutomatically: true,
              domStorageEnabled: true,
              databaseEnabled: true,
              useWideViewPort: true,
              supportZoom: true,
              allowFileAccessFromFileURLs: true,
              allowUniversalAccessFromFileURLs: true,
              cacheEnabled: true,
              clearCache: false,
            ),
            onWebViewCreated: (controller) {
              _controller = controller;
              _registerChannels(controller);
              WidgetsBinding.instance.addPostFrameCallback((_) => initUrl());
            },
            onLoadStart: (controller, url) {
              if (mounted) setState(() => state = _PageState.initWebView);
            },
            onLoadStop: (controller, url) async {
              await _installLegacyChannelBridge(controller);
              if (mounted) setState(() => state = _PageState.showWebView);
            },
            onReceivedError: (controller, request, error) {
              if (request.isForMainFrame == true && mounted) {
                setState(() => state = _PageState.initError);
                ToastProvider.error('加载遇到了错误');
              }
            },
          ),
        ),
        Visibility(
          visible: state != _PageState.showWebView,
          child: top,
        ),
      ],
    );

    final page = widget.fullPage
        ? body
        : Scaffold(
            backgroundColor:
                WpyTheme.of(context).get(widget.backgroundColor),
            body: SafeArea(
              child: Column(
                children: [
                  appBar,
                  Expanded(child: body),
                ],
              ),
            ),
          );

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) _handleBack();
      },
      child: page,
    );
  }
}
