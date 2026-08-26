import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:wepei_module/commons/preferences/common_prefs.dart';
import 'package:wepei_module/commons/themes/wpy_theme.dart';
import 'package:wepei_module/commons/widgets/wpy_pic.dart';

import '../../../commons/themes/template/wpy_theme_data.dart';

class UserAvatarImage extends StatelessWidget {
  final double size;
  final Color iconColor;
  final String tempUrl;

  UserAvatarImage({
    required this.size,
    Color? iconColor,
    this.tempUrl = "",
    required BuildContext context,
  }) : this.iconColor = iconColor ??
            WpyTheme.of(context).get(WpyColorKey.oldThirdActionColor);

  @override
  Widget build(BuildContext context) {
    final avatar = CommonPreferences.avatar.value.trim();
    final avatarBoxUrl = tempUrl == ''
        ? CommonPreferences.avatarBoxMyUrl.value.trim()
        : tempUrl.trim();
    final avatarUrl = avatar.startsWith('http')
        ? avatar
        : 'https://qnhdpic.twt.edu.cn/download/origin/$avatar';
    final avatarSize = avatarBoxUrl.isEmpty ? size : 0.54 * size;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.all(Radius.circular(500.r)),
            child: WpyPic(
              avatar.isEmpty ? 'assets/images/default_image.png' : avatarUrl,
              withHolder: true,
              width: avatarSize,
              height: avatarSize,
            ),
          ),
          if (avatarBoxUrl != 'Error' && avatarBoxUrl.isNotEmpty)
            WpyPic(
              avatarBoxUrl,
              withHolder: false,
              width: size,
              height: size,
              fit: BoxFit.contain,
            ),
        ],
      ),
    );
  }
}
