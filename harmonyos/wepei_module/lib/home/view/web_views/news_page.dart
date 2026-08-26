import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:wepei_module/commons/network/classes_service.dart';
import 'package:wepei_module/commons/preferences/common_prefs.dart';
import 'package:wepei_module/commons/themes/template/wpy_theme_data.dart';
import 'package:wepei_module/commons/themes/wpy_theme.dart';
import 'package:wepei_module/commons/util/text_util.dart';
import 'package:wepei_module/commons/widgets/webview_page.dart';

class NewsPage extends StatefulWidget {
  static const URL = 'https://news.twt.edu.cn/';

  @override
  State<NewsPage> createState() => _NewsPageState();
}

class _NewsPageState extends State<NewsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted ||
          !CommonPreferences.showNewsNetwork.value ||
          await ClassesService.check(timeout: const Duration(seconds: 1))) {
        return;
      }
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (_) => const NewNetworkAlertDialog(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return const WebViewPage(
      url: NewsPage.URL,
      title: '天外天新闻网',
    );
  }
}

class NewNetworkAlertDialog extends StatelessWidget {
  const NewNetworkAlertDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final roundShape = MaterialStateProperty.all<RoundedRectangleBorder>(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
    );
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: WpyTheme.of(context).get(WpyColorKey.primaryBackgroundColor),
        ),
        child: Padding(
          padding: const EdgeInsets.only(left: 25, right: 25, top: 20, bottom: 15),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '新闻网提示',
                style: TextUtil.base.NotoSansSC.bold.primary(context).sp(20),
              ),
              SizedBox(height: 10.h),
              Text(
                '新闻网目前仅可在校园网环境下访问\n请确保已经连接校园网或使用VPN',
                style: TextUtil.base.NotoSansSC.normal.primary(context).sp(15),
              ),
              SizedBox(height: 10.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  TextButton(
                    style: ButtonStyle(shape: roundShape),
                    onPressed: () {
                      CommonPreferences.showNewsNetwork.value = false;
                      Navigator.pop(context);
                    },
                    child: Text(
                      '不再提示',
                      style: TextUtil.base.NotoSansSC.bold
                          .primaryAction(context)
                          .sp(12),
                    ),
                  ),
                  ElevatedButton(
                    style: ButtonStyle(
                      elevation: MaterialStateProperty.all<double>(3),
                      backgroundColor: MaterialStateProperty.all<Color>(
                        WpyTheme.of(context).get(WpyColorKey.primaryActionColor),
                      ),
                      shape: roundShape,
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      '确定',
                      style: TextUtil.base.NotoSansSC.bold.sp(14).bright(context),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
