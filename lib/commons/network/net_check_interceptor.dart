part of 'wpy_dio.dart';

class NetStatusListener {
  static final NetStatusListener _instance = NetStatusListener._();

  NetStatusListener._();

  factory NetStatusListener() => _instance;

  static void init() {
    try {
      final connectivity = Connectivity();
      connectivity.onConnectivityChanged.listen((result) {
        _instance._status = result;
      });
      unawaited(connectivity.checkConnectivity().then((result) {
        _instance._status = result;
      }).catchError((_) {
        // OHOS: connectivity_plus not available — assume network is OK
        _instance._status = [ConnectivityResult.wifi];
      }));
    } catch (_) {
      // OHOS: connectivity_plus not available — assume network is OK
      _instance._status = [ConnectivityResult.wifi];
    }
  }

  List<ConnectivityResult>? _status;

  bool get hasNetwork => _instance._status?.any((r) => r != ConnectivityResult.none) ?? true;
}

class NetCheckInterceptor extends InterceptorsWrapper {
  @override
  Future onRequest(options, handler) async {
    if (NetStatusListener().hasNetwork)
      return handler.next(options);
    else
      return handler.reject(WpyDioException(error: '网络未连接'));
  }
}
