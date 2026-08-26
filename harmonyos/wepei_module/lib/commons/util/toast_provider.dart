import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:wepei_module/commons/themes/template/wpy_theme_data.dart';
import 'package:wepei_module/commons/themes/wpy_theme.dart';
import 'package:wepei_module/commons/util/router_manager.dart';
import 'package:wepei_module/commons/util/text_util.dart';

class ToastProvider {
  ToastProvider._();

  static NavigatorState? get _nav =>
      RouterManager.navigatorKey.currentState;

  static OverlayEntry? _currentEntry;

  static void unFocusAllAndHideKeyboard(BuildContext context) {
    // 获取当前的FocusScope节点
    final currentFocus = FocusScope.of(context);
    // 如果当前有焦点，则取消焦点并关闭键盘
    if (!currentFocus.hasPrimaryFocus && currentFocus.focusedChild != null) {
      // 这将关闭键盘并取消焦点
      FocusManager.instance.primaryFocus?.unfocus();
    }
  }

  static void _showOverlayToast({
    required String msg,
    required Color bgColor,
    required String svgAsset,
    Color? svgTint,
  }) {
    // Remove existing toast before showing a new one
    cancelCurrent();

    final nav = _nav;
    if (nav == null || nav.overlay == null) return;
    unFocusAllAndHideKeyboard(nav.context);

    OverlayEntry? entry;
    entry = OverlayEntry(builder: (context) {
      return _ToastFadeWidget(
        duration: const Duration(milliseconds: 250),
        onDismiss: () {
          if (_currentEntry == entry) _currentEntry = null;
          entry?.remove();
        },
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.only(left: 16, right: 16, bottom: 0.1.sh),
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.fromLTRB(15, 12, 15, 12),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (svgTint != null)
                      SvgPicture.asset(
                        svgAsset,
                        colorFilter:
                            ColorFilter.mode(svgTint, BlendMode.srcIn),
                        width: 15,
                      )
                    else
                      SvgPicture.asset(svgAsset, width: 15),
                    SizedBox(width: 10),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: 1.sw - 90),
                      child: Text(
                        msg,
                        style: TextUtil.base.NotoSansSC.regular
                            .sp(14)
                            .bright(context),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    });

    _currentEntry = entry;
    nav.overlay!.insert(entry);
  }

  /// 新版本的 error 调整了报错的底部弹窗的位置，还加入了图标
  static void error(String? msg) {
    final normalized = msg?.trim();
    final text = normalized == null || normalized.isEmpty || normalized == 'null'
        ? '请求失败'
        : normalized;
    _showOverlayToast(
      msg: text,
      bgColor: _nav?.context != null
          ? WpyTheme.of(_nav!.context).get(WpyColorKey.dangerousRed)
          : Colors.red,
      svgAsset: 'assets/svg_pics/lake_butt_icons/error_background.svg',
      svgTint: _nav?.context != null
          ? WpyTheme.of(_nav!.context).get(WpyColorKey.brightTextColor)
          : Colors.white,
    );
  }

  static void running(String msg) {
    _showOverlayToast(
      msg: msg,
      bgColor: _nav?.context != null
          ? WpyTheme.of(_nav!.context).get(WpyColorKey.infoStatusColor)
          : const Color(0xfff0ad4e),
      svgAsset: 'assets/svg_pics/lake_butt_icons/running_background.svg',
    );
  }

  static void success(String msg) {
    _showOverlayToast(
      msg: msg,
      bgColor: _nav?.context != null
          ? WpyTheme.of(_nav!.context).get(WpyColorKey.roomFreeColor)
          : Colors.green,
      svgAsset: 'assets/svg_pics/lake_butt_icons/success_background.svg',
    );
  }

  /// 取消当前正在显示的 Toast
  static void cancelCurrent() {
    _currentEntry?.remove();
    _currentEntry = null;
  }

  /// 取消队列中所有的 Toast，一般来说用这个比较好
  static void cancelAll() {
    _currentEntry?.remove();
    _currentEntry = null;
  }
}

class _ToastFadeWidget extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final VoidCallback onDismiss;

  const _ToastFadeWidget({
    required this.child,
    required this.duration,
    required this.onDismiss,
  });

  @override
  State<_ToastFadeWidget> createState() => _ToastFadeWidgetState();
}

class _ToastFadeWidgetState extends State<_ToastFadeWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    _controller.forward();
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      _controller.reverse().then((_) {
        if (mounted) widget.onDismiss();
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: widget.child,
    );
  }
}
