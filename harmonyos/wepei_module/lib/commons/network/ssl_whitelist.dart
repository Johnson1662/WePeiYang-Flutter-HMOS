import 'dart:io';

/// SSL 证书放行白名单（仅限域名的自签/异常证书，OHOS 侧适配）。
///
/// 微北洋对接的多数域名（qnhd/qnhdpic/api/activity.twt.edu.cn 等）均持有有效证书，
/// 不应放行；仅天津大学图书馆系统（ic/user.lib.tju.edu.cn）使用自签证书，
/// 由 library_service 以 `SSL = false` 显式声明放行。
///
/// 所有 badCertificateCallback 必须经由 [shouldBypassSsl] 判断，
/// 禁止返回无条件 `true`。
const List<String> kSslBypassHostSuffixes = [
  '.lib.tju.edu.cn',
];

/// 该 host 的证书异常是否允许放行。
bool shouldBypassSsl(String host) =>
    kSslBypassHostSuffixes.any((suffix) => host.endsWith(suffix));
