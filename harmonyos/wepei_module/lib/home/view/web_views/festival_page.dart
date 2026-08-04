import 'package:flutter/material.dart';
import 'package:wepei_module/commons/preferences/common_prefs.dart';
import 'package:wepei_module/commons/token/lake_token_manager.dart';
import 'package:wepei_module/commons/widgets/loading.dart';
import 'package:wepei_module/commons/widgets/webview_page.dart';

class FestivalArgs {
  final String url;
  final String name;

  FestivalArgs(this.url, this.name);
}

class FestivalPage extends StatefulWidget {
  final FestivalArgs args;

  const FestivalPage(this.args, {Key? key}) : super(key: key);

  @override
  State<FestivalPage> createState() => _FestivalPageState();
}

class _FestivalPageState extends State<FestivalPage> {
  late final Future<String> _urlFuture = _resolveUrl();

  Future<String> _resolveUrl() async {
    var url = widget.args.url.replaceAll(
      '<token>',
      CommonPreferences.token.value,
    );
    if (url.contains('<laketoken>')) {
      final lakeToken = await LakeTokenManager()
          .refreshToken()
          .timeout(const Duration(seconds: 10));
      url = url.replaceAll('<laketoken>', lakeToken);
    }
    return url;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _urlFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: Loading()));
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return const Scaffold(
            body: Center(child: Text('页面加载失败，请稍后重试')),
          );
        }
        return WebViewPage(
          url: snapshot.data!,
          title: widget.args.name,
        );
      },
    );
  }
}
