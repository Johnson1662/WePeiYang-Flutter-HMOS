import 'package:wepei_module/commons/channel/image_save/image_save.dart';

/// 鸿蒙应用市场应用详情页。
///
/// OHOS 不允许应用内下载安装 APK 或替换 libapp.so 热更新，
/// 版本更新统一由系统应用市场承载，因此这里只负责把用户送到详情页。
/// 打开方式走 EntryAbility 的 `openInBrowser` 通道（系统浏览器），
/// 不依赖无 OHOS 实现的 url_launcher。
const String kAppMarketDetailUrl =
    'https://appgallery.huawei.com/app/detail?id=com.weipeiyang.cn';

Future<bool> openAppMarket() => ImageSave.openInBrowser(kAppMarketDetailUrl);
