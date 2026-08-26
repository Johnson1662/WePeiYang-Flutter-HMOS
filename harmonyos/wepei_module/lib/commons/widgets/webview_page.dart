import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:wepei_module/commons/channel/image_save/image_save.dart';
import 'package:wepei_module/commons/themes/template/wpy_theme_data.dart';
import 'package:wepei_module/commons/themes/wpy_theme.dart';
import 'package:wepei_module/commons/util/toast_provider.dart';
import 'package:wepei_module/commons/util/text_util.dart';
import 'package:wepei_module/commons/widgets/w_button.dart';

/// Open URL via InAppWebView (Flutter PlatformView, works on OHOS for most sites).
void openUrlInApp(BuildContext context, String url, {String? title}) {
  // For general URLs, use InAppWebView (WebViewPage)
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => WebViewPage(url: url, title: title),
    ),
  );
}

/// Open URL via ArkUI native WebView (CustomDialog).
/// Use for sites InAppWebView can't handle.
void openUrlInNativeApp(String url) {
  ImageSave.openWebView(url);
}

/// Flutter in-app WebView page using flutter_inappwebview (PlatformView).
class WebViewPage extends StatefulWidget {
  final String url;
  final String? title;
  final Color? backgroundColor;

  const WebViewPage({
    super.key,
    required this.url,
    this.title,
    this.backgroundColor,
  });

  @override
  State<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  InAppWebViewController? _controller;
  String _title = '';
  bool _loadError = false;
  late String _currentUrl;

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.url;
  }

  void _copyLink() {
    Clipboard.setData(ClipboardData(text: _currentUrl));
    ToastProvider.success('链接已复制');
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
    final appBarColor =
        WpyTheme.of(context).get(WpyColorKey.primaryBackgroundColor);
    final pageBackground = widget.backgroundColor ?? appBarColor;
    final body = _loadError
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
                const SizedBox(height: 16),
                const Text('加载失败',
                    style: TextStyle(color: Colors.grey, fontSize: 18)),
                const SizedBox(height: 8),
                Text(_currentUrl,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                    textAlign: TextAlign.center),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('重试'),
                      onPressed: () => setState(() {
                        _loadError = false;
                        _controller?.reload();
                      }),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('复制链接'),
                      onPressed: _copyLink,
                    ),
                  ],
                ),
              ],
            ),
          )
        : InAppWebView(
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
            onWebViewCreated: (controller) async {
              _controller = controller;
              await controller.loadUrl(
                  urlRequest: URLRequest(url: WebUri(widget.url)));
            },
            onTitleChanged: (controller, title) {
              if (widget.title == null && title != null && mounted) {
                setState(() => _title = title);
              }
            },
            onUpdateVisitedHistory: (controller, url, androidIsReload) {
              if (url != null) _currentUrl = url.toString();
            },
            onReceivedError: (controller, request, error) {
              if (mounted) setState(() => _loadError = true);
            },
          );

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        backgroundColor: pageBackground,
        appBar: AppBar(
        title: Text(
          _loadError
              ? '加载失败'
              : (widget.title ?? (_title.isNotEmpty ? _title : '加载中...')),
          style: TextUtil.base.bold.sp(16).blue52hz(context),
        ),
        elevation: 0,
        centerTitle: true,
        backgroundColor: appBarColor,
        leading: Padding(
          padding: const EdgeInsets.only(left: 15),
          child: WButton(
            child: Icon(
              Icons.arrow_back,
              color: WpyTheme.of(context)
                  .get(WpyColorKey.defaultActionColor),
              size: 32,
            ),
            onPressed: () {
              _handleBack();
            },
          ),
        ),
      ),
        body: body,
      ),
    );
  }

  @override
  void dispose() {
    _controller = null;
    super.dispose();
  }
}
