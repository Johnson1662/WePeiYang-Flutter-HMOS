import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'dart:convert';

import 'package:flutter/material.dart' hide Navigator;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show Navigator;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:wepei_module/commons/font/font_loader.dart';
import 'package:wepei_module/commons/themes/template/wpy_theme_data.dart';
import 'package:wepei_module/commons/token/lake_token_manager.dart';
import 'package:wepei_module/studyroom/model/studyroom_provider.dart';
import 'package:wepei_module/xiaotian/model/xiaotian_state.dart';

import 'auth/network/auth_service.dart';
import 'auth/network/message_service.dart';
import 'auth/view/message/message_router.dart';
import 'commons/channel/local_setting/local_setting.dart';
import 'commons/channel/push/push_manager.dart';
import 'commons/channel/widget_data_sync.dart';
import 'commons/channel/remote_config/remote_config_manager.dart';
import 'commons/environment/config.dart';
import 'commons/local/animation_provider.dart';
import 'commons/network/ssl_whitelist.dart';
import 'commons/network/wpy_dio.dart';
import 'commons/preferences/common_prefs.dart';
import 'commons/themes/wpy_theme.dart';
import 'commons/util/logger.dart';
import 'commons/util/navigator_observers.dart';
import 'commons/util/router_manager.dart';
import 'auth/network/splash_service.dart';
import 'commons/widgets/colored_icon.dart';
import 'commons/widgets/wpy_pic.dart';
import 'commons/util/storage_util.dart';
import 'commons/util/text_util.dart';
import 'feedback/model/feedback_providers.dart';
import 'feedback/network/post.dart';
import 'gpa/model/gpa_notifier.dart';
import 'lost_and_found/module/lost_and_found_providers.dart';
import 'message/model/message_provider.dart';
import 'schedule/model/course_provider.dart';
import 'package:wepei_module/schedule/model/exam_provider.dart';
import 'schedule/schedule_providers.dart';

final _stateFile = File('${Directory.systemTemp.path}/wepeiyang_state.json');

void main() async {
  // 全局 HttpClient 证书校验；仅 ssl_whitelist.dart 白名单域名（图书馆自签证书）放行
  HttpOverrides.global = _InsecureHttpOverrides();
  WidgetsFlutterBinding.ensureInitialized();
  EnvConfig.init();
  await StorageUtil.init();
  await Logger.init();
  await CommonPreferences.init();
  NetStatusListener.init();
  FlutterError.onError = (details) {
    Logger.reportError(details.exception, details.stack);
  };
  WpyTheme.init();
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark.copyWith(
    statusBarColor: Colors.transparent,
    statusBarBrightness: Brightness.light,
  ));
  _loadLoginState();
  debugPrint(
      '[FONT_DEBUG] Platform.isAndroid=${Platform.isAndroid} Platform.isIOS=${Platform.isIOS} Platform.OS=${Platform.operatingSystem}');
  debugPrint(
      '[FONT_DEBUG] TextUtil.base.fontFamily BEFORE loadFontFromList=${TextUtil.base.fontFamily}');
  await _loadHarmonyOSFonts();
  debugPrint(
      '[FONT_DEBUG] TextUtil.base.fontFamily AFTER loadFontFromList=${TextUtil.base.fontFamily}');
  // Initial sync of course data for OHOS service widget
  WidgetDataSync.syncCourseDataToFile();
  final now = DateTime.now().toLocal();
  final importantDates = [
    DateTime(now.year, 5, 12),
    DateTime(now.year, 12, 13),
  ];
  final isSpecialDate = importantDates.any((date) =>
      date.year == now.year && date.month == now.month && date.day == now.day);

  if (isSpecialDate) {
    runApp(
      ColorFiltered(
        colorFilter: ColorFilter.mode(Colors.white, BlendMode.color),
        child: const WePeiYangApp(),
      ),
    );
  } else {
    runApp(const WePeiYangApp());
  }
}

Future<void> _loadHarmonyOSFonts() async {
  // Fonts registered via pubspec.yaml 'fonts:' section (FontManifest.json) are already loaded by the Flutter framework.
  // No need for loadFontFromList — the OHOS engine reads FontManifest.json on startup.
  debugPrint(
      '[FONT_DEBUG] Fonts declared in pubspec fonts: section are loaded via FontManifest.json');
}

void _loadLoginState() {
  try {
    if (!_stateFile.existsSync()) return;
    final data =
        jsonDecode(_stateFile.readAsStringSync()) as Map<String, dynamic>;
    // 仅合入 state 文件中「非空」的字段，绝不把空值覆盖进 prefs。
    // 此前无条件覆盖（data['token'] ?? ''）会把登录态 token/account 清空，
    // 导致每次重启（含清后台）后都要重新登录。
    void restore(String key, void Function(String value) set) {
      final value = data[key];
      if (value is String && value.isNotEmpty) set(value);
    }

    restore('token', (v) => CommonPreferences.token.value = v);
    restore('account', (v) => CommonPreferences.account.value = v);
    restore('password', (v) => CommonPreferences.password.value = v);
    restore('nickname', (v) => CommonPreferences.nickname.value = v);
    restore('userNumber', (v) => CommonPreferences.userNumber.value = v);
    restore('avatar', (v) => CommonPreferences.avatar.value = v);
    restore('phone', (v) => CommonPreferences.phone.value = v);
    restore('email', (v) => CommonPreferences.email.value = v);
    restore('realName', (v) => CommonPreferences.realName.value = v);
    restore('tjuuname', (v) => CommonPreferences.tjuuname.value = v);
    restore('tjupasswd', (v) => CommonPreferences.tjupasswd.value = v);

    final token = data['token'];
    if (token is String && token.isNotEmpty) {
      CommonPreferences.isLogin.value = true;
    }
    CommonPreferences.syncTjuBindingState();
  } catch (_) {}
}

// OHOS 侧仅 com.twt.service/saveImg 与 com.twt.service/push 有原生实现，
// 其中 push 目前只作为接收端（setMethodCallHandler），见下方 _pushChannel 用法。
final _pushChannel = MethodChannel('com.twt.service/push');

class WePeiYangApp extends StatefulWidget {
  const WePeiYangApp({super.key});
  @override
  State<WePeiYangApp> createState() => _appState;
  static double screenWidth = 390;
  static double screenHeight = 844;
  static late NavigatorState navigatorState;
}

final _appState = WePeiYangAppState._();

class WePeiYangAppState extends State<WePeiYangApp>
    with WidgetsBindingObserver {
  WePeiYangAppState._();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WePeiYangApp.navigatorState =
          RouterManager.navigatorKey.currentState ?? Navigator.of(context);
      WbyFontLoader.initFonts();
      unawaited(const MethodChannel('com.twt.service/saveImg')
          .invokeMethod('flutterFirstFrame')
          .catchError((_) {}));
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      WpyTheme.updateAutoDarkTheme(context);
    }
  }

  @override
  void didChangePlatformBrightness() async {
    super.didChangePlatformBrightness();
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    WpyTheme.updateAutoDarkTheme(context);
  }

  void checkEventList() {}
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final mq = MediaQuery.of(context);
    WePeiYangApp.screenWidth = mq.size.width;
    WePeiYangApp.screenHeight = mq.size.height;
  }

  @override
  Widget build(BuildContext context) {
    // Set white background while Flutter initializes
    return ScreenUtilInit(
      designSize: const Size(390, 844),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => GPANotifier()),
            ...scheduleProviders,
            ChangeNotifierProvider(create: (_) => CampusProvider()),
            ChangeNotifierProvider(create: (_) => TimeProvider()),
            ChangeNotifierProvider(
              lazy: false,
              create: (_) {
                final messageProvider = MessageProvider()
                  ..refreshFeedbackCount();
                _pushChannel.setMethodCallHandler((call) async {
                  switch (call.method) {
                    case 'openRoute':
                      // 服务卡片点击直达：热启动场景直接跳转
                      final arguments = call.arguments;
                      if (arguments is Map && arguments['route'] is String) {
                        RouterManager.navigatorKey.currentState
                            ?.pushNamed(arguments['route'] as String);
                      }
                      return 'success';
                    case 'refreshFeedbackMessageCount':
                      await messageProvider.refreshFeedbackCount();
                      return 'success';
                    case 'showMessageDialogOnlyText':
                      final arguments = call.arguments;
                      if (arguments is Map && arguments['data'] is String) {
                        final content = arguments['data'] as String;
                        final dialogContext = RouterManager
                            .navigatorKey.currentState?.overlay?.context;
                        if (dialogContext != null && content.isNotEmpty) {
                          await showMessageDialog(dialogContext, content);
                        }
                      }
                      break;
                  }
                });
                return messageProvider;
              },
            ),
            ...feedbackProviders,
            ...lostAndFoundProviders,
            ChangeNotifierProvider(create: (_) => PushManager()),
            ChangeNotifierProvider(create: (_) => AnimationProvider()),
            ChangeNotifierProvider(create: (_) => xiaotianInputState()),
            ChangeNotifierProvider(
              lazy: false,
              create: (_) => RemoteConfig()..getRemoteConfig(),
            ),
            ChangeNotifierProvider(create: (_) => xiaotianChatState()),
          ],
          child: ListenableBuilder(
            listenable: globalTheme,
            builder: (context, _) => WpyTheme(
              themeData: globalTheme.value,
              child: RefreshConfiguration(
                springDescription: const SpringDescription(
                    mass: 1.0, stiffness: 364.72, damping: 35.2),
                child: MaterialApp(
                  navigatorKey: RouterManager.navigatorKey,
                  debugShowCheckedModeBanner: false,
                  title: 'WePeiYang',
                  theme: ThemeData.light().copyWith(
                    platform: TargetPlatform.android,
                    pageTransitionsTheme: const PageTransitionsTheme(
                      builders: {
                        TargetPlatform.android: ZoomPageTransitionsBuilder(),
                      },
                    ),
                  ),
                  home: const SplashScreen(),
                  navigatorObservers: [
                    AppRouteAnalysis(),
                    PageStackObserver(),
                    FlutterSmartDialog.observer,
                  ],
                  builder: FlutterSmartDialog.init(
                    toastBuilder: (String msg) => Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(8)),
                      child: Text(msg,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14)),
                    ),
                  ),
                  onGenerateRoute: RouterManager.create,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 启动页Widget（对齐其它系统）
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String? _remoteUrl;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _appInitProcess();
      _loadSplashIcon();
    });
  }

  Future<void> _loadSplashIcon() async {
    try {
      final banners =
          await SplashService.getBanner().timeout(const Duration(seconds: 3));
      if (!mounted || banners.isEmpty) return;

      final url = banners.first.picUrl.trim();
      if (url.isEmpty) return;

      await precacheImage(CachedNetworkImageProvider(url), context);
      if (!mounted) return;
      setState(() => _remoteUrl = url);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = WpyTheme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? Colors.black : Colors.white;

    final Widget content;
    if (_remoteUrl != null) {
      content = WpyPic(
        _remoteUrl!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        withHolder: false,
      );
    } else {
      final asset = isDarkMode
          ? 'assets/images/splash_screen_dark.png'
          : 'assets/images/splash_screen.png';
      content = Padding(
        padding: const EdgeInsets.all(30),
        child: Center(
          child: ColoredIcon(asset, color: WpyTheme.of(context).primary),
        ),
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: Container(
        key: ValueKey(_remoteUrl ?? 'local'),
        color: backgroundColor,
        constraints: const BoxConstraints.expand(),
        child: content,
      ),
    );
  }

  void _navigateHome() async {
    String? pendingRoute;
    try {
      pendingRoute = await const MethodChannel('com.twt.service/saveImg')
          .invokeMethod<String>('consumePendingRoute')
          .timeout(const Duration(seconds: 1));
    } catch (_) {}

    final didNavigate = _navigateOnce(
      (navigator) =>
          navigator.pushNamedAndRemoveUntil(HomeRouter.home, (route) => false),
    );
    if (!didNavigate) return;
    if (pendingRoute != null && pendingRoute.isNotEmpty) {
      RouterManager.navigatorKey.currentState?.pushNamed(pendingRoute);
    }
  }

  void _navigateLogin() {
    _navigateOnce(
        (navigator) => navigator.pushReplacementNamed(AuthRouter.login));
  }

  bool _navigateOnce(void Function(NavigatorState navigator) navigate) {
    if (!mounted || _hasNavigated) return false;
    final navigator = RouterManager.navigatorKey.currentState;
    if (navigator == null) return false;
    _hasNavigated = true;
    navigate(navigator);
    return true;
  }

  Future<void> _appInitProcess() async {
    unawaited(LocalSetting.changeSecurity(false).catchError((_) {}));

    if (CommonPreferences.updateTime.value == "") {
      CommonPreferences.updateTime.value = "20221019";
    } else if (CommonPreferences.updateTime.value != "20221019") {
      CommonPreferences.clearAllPrefs();
      _navigateLogin();
      return;
    }

    try { context.read<GPANotifier>().readPref(); } catch (_) {}
    try { context.read<ExamProvider>().readPref(); } catch (_) {}
    try { context.read<CourseProvider>().readPref(); } catch (_) {}

    if (CommonPreferences.isLogin.value &&
        CommonPreferences.token.value != '') {
      await Future.delayed(Duration.zero);
      if (!mounted || _hasNavigated) return;
      unawaited(LakeTokenManager().refreshToken().catchError((_) => ''));
      AuthService.getInfo(
        onSuccess: _navigateHome,
        onFailure: (_) {
          if (CommonPreferences.account.value != '' &&
              CommonPreferences.password.value != '') {
            AuthService.pwLogin(
              CommonPreferences.account.value,
              CommonPreferences.password.value,
              onResult: (_) {},
              onFailure: (_) {},
            );
          }
          _navigateHome();
        },
      );
    } else {
      /// 没登录过的话，多看一会的启动页再跳转到登录页
      await Future.delayed(const Duration(seconds: 1));
      _navigateLogin();
    }
  }
}

class _InsecureHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) =>
          shouldBypassSsl(host);
  }
}
