import 'package:flutter/material.dart';
import 'package:linkfy_text/linkfy_text.dart';
import 'package:wepei_module/commons/widgets/webview_page.dart';
import 'package:wepei_module/commons/themes/template/wpy_theme_data.dart';
import 'package:wepei_module/commons/themes/wpy_theme.dart';
import 'package:wepei_module/commons/util/dialog_provider.dart';
import 'package:wepei_module/commons/util/router_manager.dart';
import 'package:wepei_module/commons/util/text_util.dart';
import 'package:wepei_module/commons/util/toast_provider.dart';
import 'package:wepei_module/feedback/network/feedback_service.dart';

class LinkText extends StatefulWidget {
  final TextStyle style;
  final String text;
  final int maxLine;

  @override
  _LinkTextState createState() => _LinkTextState();

  LinkText({required this.style, required this.text, this.maxLine = 100});
}

class _LinkTextState extends State<LinkText> {
  static final _postRefPattern = RegExp(r'^#MP-?\d+$', caseSensitive: false);
  static final _httpUrlPattern = RegExp(r'^https?://', caseSensitive: false);

  bool checkBili(String url) {
    return url.contains('b23.tv') || url.contains('bilibili.com');
  }

  @override
  Widget build(BuildContext context) {
    return LinkifyText(
      widget.text,
      maxLines: widget.maxLine,
      linkTypes: [LinkType.url, LinkType.hashTag],
      overflow: TextOverflow.ellipsis,
      textStyle: widget.style.PingFangSC.w400.sp(16),
      linkStyle: widget.style.link(context).w500.sp(16),
      onTap: (link) async {
        final value = link.value?.trim() ?? '';
        if (_postRefPattern.hasMatch(value)) {
          checkPostId(value.substring(3));
        } else if (link.type == LinkType.url) {
          checkUrl(_normalizeUrl(value));
        } else {
          ToastProvider.error('无效的帖子编号！');
        }
      },
    );
  }

  checkPostId(String id) {
    FeedbackService.getPostById(
      id: int.parse(id),
      onResult: (post) {
        Navigator.pushNamed(
          context,
          FeedbackRouter.detail,
          arguments: post,
        );
      },
      onFailure: (e) {
        ToastProvider.error('无法找到对应帖子，报错信息：${e.error}');
        return;
      },
    );
  }

  String _normalizeUrl(String value) {
    final url = value.trim();
    return _httpUrlPattern.hasMatch(url) ? url : 'https://$url';
  }

  checkUrl(String url) async {
    openUrlInApp(context, url);
  }
}
