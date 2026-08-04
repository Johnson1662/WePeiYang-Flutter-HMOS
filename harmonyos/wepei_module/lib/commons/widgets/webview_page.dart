import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:wepei_module/commons/channel/image_save/image_save.dart';
import 'package:wepei_module/commons/util/toast_provider.dart';

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
  double _progress = 0;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.backgroundColor,
      appBar: AppBar(
        backgroundColor: widget.backgroundColor,
        foregroundColor: widget.backgroundColor == Colors.white
            ? Colors.black87
            : null,
        surfaceTintColor:
            widget.backgroundColor == null ? null : Colors.transparent,
        title: Text(
          _loadError
              ? '加载失败'
              : (_title.isNotEmpty ? _title : (widget.title ?? '加载中...')),
          style: const TextStyle(fontSize: 16),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.mounted) Navigator.pop(context);
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.content_copy),
            tooltip: '复制链接',
            onPressed: _copyLink,
          ),
        ],
        bottom: _progress < 1.0 && !_loadError
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(value: _progress),
              )
            : null,
      ),
      body: _loadError
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('加载失败', style: TextStyle(color: Colors.grey, fontSize: 18)),
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
                          _progress = 0;
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
                // Load URL after controller is ready (more reliable on OHOS)
                await controller.loadUrl(urlRequest: URLRequest(url: WebUri(widget.url)));
              },
              onTitleChanged: (controller, title) {
                if (title != null && mounted) {
                  setState(() => _title = title);
                }
              },
              onProgressChanged: (controller, progress) {
                if (mounted) setState(() => _progress = progress / 100.0);
              },
              onUpdateVisitedHistory: (controller, url, androidIsReload) {
                if (url != null) _currentUrl = url.toString();
              },
              onReceivedError: (controller, request, error) {
                if (mounted) setState(() => _loadError = true);
              },
            ),
    );
  }

  @override
  void dispose() {
    _controller = null;
    super.dispose();
  }
}
