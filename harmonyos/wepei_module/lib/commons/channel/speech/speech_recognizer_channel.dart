import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

typedef OnSpeechResultCallback = void Function(String text, bool isFinal);
typedef OnSpeechErrorCallback = void Function(String error);
typedef OnSpeechCompleteCallback = void Function();

/// 鸿蒙原生 Core Speech Kit 语音识别通道封装 (com.twt.service/speech_recognizer)
class SpeechRecognizerChannel {
  SpeechRecognizerChannel._() {
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  static final SpeechRecognizerChannel instance = SpeechRecognizerChannel._();

  static const MethodChannel _channel =
      MethodChannel('com.twt.service/speech_recognizer');

  OnSpeechResultCallback? _onResult;
  OnSpeechErrorCallback? _onError;
  OnSpeechCompleteCallback? _onComplete;

  void setCallbacks({
    OnSpeechResultCallback? onResult,
    OnSpeechErrorCallback? onError,
    OnSpeechCompleteCallback? onComplete,
  }) {
    _onResult = onResult;
    _onError = onError;
    _onComplete = onComplete;
  }

  void clearCallbacks() {
    _onResult = null;
    _onError = null;
    _onComplete = null;
  }

  Future<void> _handleNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'onSpeechResult':
        if (call.arguments is Map) {
          final map = Map<String, dynamic>.from(call.arguments as Map);
          final text = map['text'] as String? ?? '';
          final isFinal = map['isFinal'] as bool? ?? false;
          _onResult?.call(text, isFinal);
        }
        break;
      case 'onSpeechError':
        if (call.arguments is Map) {
          final map = Map<String, dynamic>.from(call.arguments as Map);
          final msg = map['message'] as String? ?? '语音识别错误';
          _onError?.call(msg);
        }
        break;
      case 'onSpeechComplete':
        _onComplete?.call();
        break;
      default:
        break;
    }
  }

  /// 请求麦克风权限（动态弹窗申请）
  Future<bool> requestPermission() async {
    try {
      final res = await _channel.invokeMethod<bool>('requestPermission');
      return res ?? false;
    } catch (e) {
      debugPrint('SpeechRecognizerChannel requestPermission error: $e');
      return false;
    }
  }

  /// 启动实时麦克风语音识别
  Future<bool> startListening() async {
    try {
      final res = await _channel.invokeMethod<bool>('startListening');
      return res ?? false;
    } catch (e) {
      debugPrint('SpeechRecognizerChannel startListening error: $e');
      return false;
    }
  }

  /// 结束语音识别并等待最终结果
  Future<bool> stopListening() async {
    try {
      final res = await _channel.invokeMethod<bool>('stopListening');
      return res ?? false;
    } catch (e) {
      debugPrint('SpeechRecognizerChannel stopListening error: $e');
      return false;
    }
  }

  /// 取消当前语音识别
  Future<void> cancelListening() async {
    try {
      await _channel.invokeMethod<bool>('cancelListening');
    } catch (e) {
      debugPrint('SpeechRecognizerChannel cancelListening error: $e');
    }
  }
}
