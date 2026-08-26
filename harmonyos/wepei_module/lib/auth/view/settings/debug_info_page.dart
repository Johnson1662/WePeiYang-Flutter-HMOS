import 'dart:io';
import 'dart:ui';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wepei_module/commons/channel/image_save/image_save.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:screenshot/screenshot.dart';
import 'package:wepei_module/commons/environment/config.dart';
import 'package:wepei_module/commons/themes/template/wpy_theme_data.dart';
import 'package:wepei_module/commons/themes/wpy_theme.dart';
import 'package:wepei_module/commons/util/text_util.dart';
import 'package:wepei_module/commons/util/toast_provider.dart';

class _EndpointDef {
  final String label;
  final String url;

  const _EndpointDef(this.label, this.url);
}

const _endpointDefs = [
  _EndpointDef('微北洋 API', 'https://api.twt.edu.cn/api/semester'),
  _EndpointDef(
      '教务网', 'https://classes.tju.edu.cn/eams/courseTableForStd!index.action'),
  _EndpointDef('自习室', 'https://selfstudy.twt.edu.cn/campus'),
  _EndpointDef('青年湖底', 'https://qnhd.twt.edu.cn/api/v1/f/banners'),
  _EndpointDef('图片 CDN', 'https://qnhdpic.twt.edu.cn/download/'),
  _EndpointDef('海棠活动', 'https://haitang.twt.edu.cn/api/v1/banner'),
  _EndpointDef('升级服务', 'https://upgrade.twt.edu.cn/androidupdate/check/1'),
];

class DebugInfoPage extends StatefulWidget {
  const DebugInfoPage({super.key});

  @override
  State<DebugInfoPage> createState() => _DebugInfoPageState();
}

class _DebugInfoPageState extends State<DebugInfoPage> {
  static const _deviceChannel = MethodChannel('com.twt.service/device_info');

  PackageInfo? _appInfo = null;
  String _osVersion = 'Unknown';
  String _deviceModel = 'Unknown';
  String osType = 'HarmonyOS';
  String _connectivity = '检测中…';
  final Map<String, String> _endpointStatus = {};
  // AndroidDeviceInfo? _androidDeviceInfo;
  // IosDeviceInfo? _iosDeviceInfo;

  // Future<void> _initDeviceInfo() async {
  //   final PackageInfo info = await PackageInfo.fromPlatform();
  //   final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
  //   String deviceModel;
  //   String osVersion;
  //
  //   if (Theme.of(context).platform == TargetPlatform.iOS) {
  //     final iosDeviceInfo = await deviceInfo.iosInfo;
  //     deviceModel = iosDeviceInfo.model;
  //     osVersion = iosDeviceInfo.systemVersion;
  //     osType = "iOS";
  //     _iosDeviceInfo = iosDeviceInfo;
  //   } else {
  //     final androidDeviceInfo = await deviceInfo.androidInfo;
  //     androidDeviceInfo.display;
  //     deviceModel = androidDeviceInfo.model;
  //     osVersion = androidDeviceInfo.version.release;
  //     osType = "Android";
  //     _androidDeviceInfo = androidDeviceInfo;
  //   }
  //
  //   setState(() {
  //     _appInfo = info;
  //     _deviceModel = deviceModel;
  //     _osVersion = osVersion;
  //   });
  // }

  final screenshotController = ScreenshotController();

  @override
  void initState() {
    super.initState();
    _initDeviceInfo();
  }

  Future<void> _initDeviceInfo() async {
    try {
      if (mounted) {
        setState(() {
          for (final endpoint in _endpointDefs) {
            _endpointStatus[endpoint.label] = '检测中…';
          }
        });
      }
      final appInfo = await PackageInfo.fromPlatform();
      final connectivity = await Connectivity().checkConnectivity();
      Map<dynamic, dynamic>? nativeInfo;
      try {
        nativeInfo = await _deviceChannel
            .invokeMethod<Map>('getDeviceInfo')
            .timeout(const Duration(seconds: 3));
      } catch (_) {
        nativeInfo = null;
      }
      await Future.wait(_endpointDefs.map((endpoint) async {
        final status = await _checkEndpoint(endpoint);
        if (mounted) _endpointStatus[endpoint.label] = status;
      }));
      if (!mounted) return;
      setState(() {
        _appInfo = appInfo;
        _connectivity = connectivity.name;
        _osVersion = nativeInfo?['osVersion']?.toString() ??
            Platform.operatingSystemVersion;
        _deviceModel = nativeInfo?['model']?.toString() ?? 'Unknown';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _osVersion = Platform.operatingSystemVersion;
        _connectivity = '读取失败';
      });
    }
  }

  Future<String> _checkEndpoint(_EndpointDef endpoint) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
    try {
      final request = await client.getUrl(Uri.parse(endpoint.url));
      final response =
          await request.close().timeout(const Duration(seconds: 3));
      return '${response.statusCode}';
    } catch (_) {
      return '不可达';
    } finally {
      client.close(force: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          WpyTheme.of(context).get(WpyColorKey.primaryBackgroundColor),
      appBar: AppBar(
        title: Text('设备信息'),
        centerTitle: true,
        titleTextStyle: TextUtil.base.sp(18).primary(context),
        backgroundColor:
            WpyTheme.of(context).get(WpyColorKey.secondaryBackgroundColor),
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: WpyTheme.of(context).get(WpyColorKey.basicTextColor),
          ),
          onPressed: () => Navigator.pop(context),
          color: WpyTheme.of(context).get(WpyColorKey.basicTextColor),
        ),
        actions: [
          IconButton(
            onPressed: () {
              _initDeviceInfo();
            },
            icon: Icon(
              Icons.refresh,
              size: 28,
              color: WpyTheme.of(context).get(WpyColorKey.basicTextColor),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.camera_alt_outlined,
              size: 28,
            ),
            onPressed: () {
              screenshotController.captureAsUiImage().then((value) async {
                if (value == null) {
                  ToastProvider.error("图片保存失败");
                  return;
                }
                final bytes =
                    (await value.toByteData(format: ImageByteFormat.png))!
                        .buffer
                        .asUint8List();
                await ImageSave.saveImageFromBytes(bytes,
                    'wpy_debug_${DateTime.now().millisecondsSinceEpoch}.png',
                    album: true);
                ToastProvider.success("图片保存成功");
              }).onError((error, stackTrace) {
                ToastProvider.error("图片保存失败");
              });
            },
            color: WpyTheme.of(context).get(WpyColorKey.basicTextColor),
          ),
        ],
      ),
      body: ListView(children: [
        Screenshot(
          controller: screenshotController,
          child: ColoredBox(
            color:
                WpyTheme.of(context).get(WpyColorKey.secondaryBackgroundColor),
            child: Column(
              children: [
                Center(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Image.asset(
                          'assets/app_icon.png',
                          width: 100,
                          height: 100,
                        ),
                      ),
                      Text(
                        '微北洋 Flutter',
                        style: TextUtil.base.sp(22).bold.primary(context),
                      ),
                      Text(
                        'Powered By TWT Studio',
                        style: TextStyle(
                          color: WpyTheme.of(context)
                              .get(WpyColorKey.secondaryTextColor)
                              .withOpacity(0.8),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    ],
                  ),
                ),
                ListTile(
                  title: Text(
                    'Package Info',
                    style: TextStyle(
                      color:
                          WpyTheme.of(context).get(WpyColorKey.basicTextColor),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ListTile(
                  title: Text('Package Info'),
                  subtitle: Text(
                      "${EnvConfig.ENVIRONMENT} ${EnvConfig.VERSION}+${EnvConfig.VERSIONCODE}"),
                ),
                ListTile(
                  title: Text('App Version'),
                  subtitle: Text(_appInfo != null
                      ? "${_appInfo!.appName} ${_appInfo!.version}+${_appInfo!.buildNumber}"
                      : 'Unknown'),
                ),
                ListTile(
                  title: Text('Package Name'),
                  subtitle: Text(_appInfo?.packageName ?? 'Unknown'),
                ),
                ListTile(
                  title: Text('Build Signature'),
                  subtitle: Text(_appInfo?.buildSignature ?? 'Unknown'),
                ),
                ListTile(
                  title: Text('Installer Store'),
                  subtitle: Text(_appInfo?.installerStore ?? 'Unknown'),
                ),
                Divider(),
                ListTile(
                  title: Text(
                    'Device Info',
                    style: TextStyle(
                      color:
                          WpyTheme.of(context).get(WpyColorKey.basicTextColor),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ListTile(
                  title: Text('$osType Version'),
                  subtitle: Text("$osType $_osVersion"),
                  trailing: Icon(
                    Theme.of(context).platform == TargetPlatform.iOS
                        ? Icons.apple
                        : Icons.android,
                    size: 30,
                    color: WpyTheme.of(context)
                        .get(WpyColorKey.primaryActionColor),
                  ),
                ),
                ListTile(
                  title: Text('Device Model'),
                  subtitle: Text(_deviceModel),
                ),
                ListTile(
                  title: Text('Network'),
                  subtitle: Text(_connectivity),
                ),
                ExpansionTile(
                  title: Text('Endpoint Reachability'),
                  children: [
                    for (final endpoint in _endpointDefs)
                      ListTile(
                        dense: true,
                        title: Text(endpoint.label),
                        subtitle:
                            Text(_endpointStatus[endpoint.label] ?? '检测中…'),
                      ),
                  ],
                ),
                // ListTile(
                //   title: Text('Device ID'),
                //   subtitle: Text(
                //       Theme.of(context).platform == TargetPlatform.iOS
                //           ? _iosDeviceInfo?.identifierForVendor ?? 'Unknown'
                //           : _androidDeviceInfo?.fingerprint ?? 'Unknown'),
                // ),
                // ListTile(
                //   title: Text('Device Name'),
                //   subtitle: Text(
                //       Theme.of(context).platform == TargetPlatform.iOS
                //           ? _iosDeviceInfo?.name ?? 'Unknown'
                //           : _androidDeviceInfo?.device ?? 'Unknown'),
                // ),
                // ListTile(
                //   title: Text('Device Brand'),
                //   subtitle: Text(
                //       Theme.of(context).platform == TargetPlatform.iOS
                //           ? _iosDeviceInfo?.name ?? 'Unknown'
                //           : _androidDeviceInfo?.brand ?? 'Unknown'),
                // ),
                // ListTile(
                //   title: Text('Device Manufacturer'),
                //   subtitle: Text(
                //       Theme.of(context).platform == TargetPlatform.iOS
                //           ? _iosDeviceInfo?.name ?? 'Unknown'
                //           : _androidDeviceInfo?.manufacturer ?? 'Unknown'),
                // ),
                // ListTile(
                //   title: Text('Device Type'),
                //   subtitle: Text(
                //       Theme.of(context).platform == TargetPlatform.iOS
                //           ? _iosDeviceInfo?.name ?? 'Unknown'
                //           : _androidDeviceInfo?.type ?? 'Unknown'),
                // ),
                // ListTile(
                //   title: Text('Device System Name'),
                //   subtitle: Text(
                //       Theme.of(context).platform == TargetPlatform.iOS
                //           ? _iosDeviceInfo?.systemName ?? 'Unknown'
                //           : _androidDeviceInfo?.host ?? 'Unknown'),
                // ),
                // if (Theme.of(context).platform == TargetPlatform.android) ...[
                //   ListTile(
                //     title: Text('Supported ABIs'),
                //     subtitle: Text(
                //         _androidDeviceInfo?.supportedAbis.join("\n") ??
                //             'Unknown'),
                //   ),
                //   // is real device
                //   ListTile(
                //     title: Text('Is Real Device'),
                //     subtitle: Text(
                //         _androidDeviceInfo?.isPhysicalDevice.toString() ??
                //             'Unknown'),
                //   ),
                //   ListTile(
                //     title: Text('Android Serial Number'),
                //     subtitle:
                //         Text(_androidDeviceInfo?.serialNumber ?? 'Unknown'),
                //   ),
                //   ListTile(
                //     title: Text('Display Resolution'),
                //     subtitle: Text(
                //       _androidDeviceInfo != null
                //           ? "${_androidDeviceInfo!.displayMetrics.widthPx} x ${_androidDeviceInfo!.displayMetrics.heightPx}"
                //           : "Unknown",
                //     ),
                //   ),
                // ],
                Divider(),
                ListTile(
                  title: Text(
                    'Screen Info',
                    style: TextStyle(
                      color:
                          WpyTheme.of(context).get(WpyColorKey.basicTextColor),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ListTile(
                  title: Text('Screen Size'),
                  subtitle: Text(
                      "${MediaQuery.of(context).size.width} x ${MediaQuery.of(context).size.height}"),
                ),
                ListTile(
                  title: Text('Screen Pixel Ratio'),
                  subtitle:
                      Text(MediaQuery.of(context).devicePixelRatio.toString()),
                ),
                ListTile(
                  title: Text('Platform Brightness'),
                  subtitle: Text(
                      MediaQuery.of(context).platformBrightness.toString()),
                ),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}
