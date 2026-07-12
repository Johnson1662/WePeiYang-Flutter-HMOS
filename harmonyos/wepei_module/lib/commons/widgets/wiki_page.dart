import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wepei_module/commons/util/toast_provider.dart';

/// 北洋维基入口页。
/// 因 OHOS 上 InAppWebView 和 ArkUI CustomDialog 均无法加载该站点，
/// 改为复制链接到剪贴板并提示用户手动在浏览器中打开。
class WikiPage extends StatelessWidget {
  final String url;
  final String? title;

  const WikiPage({super.key, required this.url, this.title});

  @override
  Widget build(BuildContext context) {
    // Copy URL to clipboard
    Clipboard.setData(ClipboardData(text: url));
    // Show toast immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        ToastProvider.success('链接已复制，请在浏览器中打开');
        Navigator.pop(context);
      }
    });
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
