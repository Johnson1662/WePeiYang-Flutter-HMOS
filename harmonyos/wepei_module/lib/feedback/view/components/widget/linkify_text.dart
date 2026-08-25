import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:wepei_module/commons/themes/wpy_theme.dart';
import 'package:wepei_module/commons/util/router_manager.dart';
import 'package:wepei_module/commons/util/text_util.dart';
import 'package:wepei_module/commons/util/toast_provider.dart';
import 'package:wepei_module/commons/widgets/webview_page.dart';
import 'package:wepei_module/feedback/network/feedback_service.dart';
import 'package:wepei_module/feedback/view/components/widget/post_rich_text.dart';

class LinkText extends StatefulWidget {
  final TextStyle style;
  final String text;
  final int maxLine;

  @override
  _LinkTextState createState() => _LinkTextState();

  LinkText({required this.style, required this.text, this.maxLine = 100});
}

class _LinkTextState extends State<LinkText> {
  final List<TapGestureRecognizer> _recognizers = [];

  bool checkBili(String url) {
    return url.contains('b23.tv') || url.contains('bilibili.com');
  }

  @override
  void initState() {
    super.initState();
    if (widget.text.contains('@uid:'))
      MentionNames.instance.addListener(_onMentionNames);
  }

  @override
  void didUpdateWidget(covariant LinkText old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) {
      final had = old.text.contains('@uid:');
      final has = widget.text.contains('@uid:');
      if (had != has) {
        if (has) {
          MentionNames.instance.addListener(_onMentionNames);
        } else {
          MentionNames.instance.removeListener(_onMentionNames);
        }
      }
    }
  }

  void _onMentionNames() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    MentionNames.instance.removeListener(_onMentionNames);
    for (final r in _recognizers) r.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    for (final r in _recognizers) r.dispose();
    _recognizers.clear();

    final textStyle = widget.style.NotoSansSC.w400.sp(16);
    final linkStyle = widget.style.link(context).w500.sp(16);
    final mentionStyle = textStyle.copyWith(
        color: WpyTheme.of(context).primary ?? linkStyle.color,
        fontWeight: FontWeight.w600);

    final res = PostRichText.build(context, widget.text,
        baseStyle: textStyle,
        linkStyle: linkStyle,
        mentionStyle: mentionStyle,
        recognizers: _recognizers,
        onLink: _onTap,
        onMention: (uid) => PostRichText.openPerson(context, uid));

    return RichText(
      text: TextSpan(style: textStyle, children: res.spans),
      maxLines: widget.maxLine,
      overflow: TextOverflow.ellipsis,
    );
  }

  void _onTap(String value) {
    if (PostRichText.isPostRef(value)) {
      checkPostId(PostRichText.postRefId(value));
    } else if (value.startsWith('http')) {
      checkUrl(value);
    } else if (value.startsWith('#')) {
      PostRichText.openTagSearch(context, value);
    } else {
      ToastProvider.error('无效的帖子编号！');
    }
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

  checkUrl(String url) async {
    openUrlInApp(context, url);
  }
}
