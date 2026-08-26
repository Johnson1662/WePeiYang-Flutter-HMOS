import 'package:wepei_module/commons/util/logger.dart';

/// OHOS 日志门面（代替 talker）
/// talker_flutter 无法在 OHOS Flutter SDK 上编译
class Log {
  Log._();

  static void d(Object? msg, {String? tag}) =>
      Logger.write(tag == null ? '[D] $msg' : '[D][$tag] $msg');

  static void i(Object? msg, {String? tag}) =>
      Logger.write(tag == null ? '[I] $msg' : '[I][$tag] $msg');

  static void w(Object? msg, {String? tag}) =>
      Logger.write(tag == null ? '[W] $msg' : '[W][$tag] $msg');

  static void e(Object error, [StackTrace? stack, String? tag]) {
    Logger.write(tag == null ? '[E] $error' : '[E][$tag] $error');
    if (stack != null) Logger.write('[E] $stack');
  }
}
