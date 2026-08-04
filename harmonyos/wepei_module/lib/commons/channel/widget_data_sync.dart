import 'dart:convert' show json;
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart';

import '../preferences/common_prefs.dart';

/// Syncs course schedule data from Flutter to a shared file that the OHOS
/// FormExtensionAbility (service widget) reads.
///
/// Writes directly to [Directory.systemTemp]/schedule_widget_data.json,
/// bypassing MethodChannel (which has Map serialization issues on OHOS).
class WidgetDataSync {
  /// Calculate the current academic week (1-24), same logic as CourseProvider.
  static int _calcCurrentWeek() {
    final termStart = CommonPreferences.termStart.value;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final diff = now - termStart;
    if (diff <= 0) return 1;
    final week = (diff / 604800).ceil();
    if (week > 24) return 24;
    return week;
  }

  /// Writes courseData and currentWeek to a JSON file that the OHOS
  /// FormExtensionAbility reads. Uses the same temp directory as
  /// MockSharedPreferences, so the file is accessible by the widget.
  static void syncCourseDataToFile() {
    try {
      final courseData = CommonPreferences.courseData.value;
      final currentWeek = _calcCurrentWeek();

      // Use the same temp directory as MockSharedPreferences
      final file = File('${Directory.systemTemp.path}/schedule_widget_data.json');

      final payload = <String, dynamic>{
        'courseData': courseData,
        'currentWeek': currentWeek,
        'lastUpdate': DateTime.now().millisecondsSinceEpoch,
      };
      file.writeAsStringSync(json.encode(payload));
      debugPrint('[WidgetDataSync] written to ${file.path} (${courseData.length} chars)');

      // Notify the widget to refresh immediately
      _triggerFormUpdate();
    } catch (e) {
      debugPrint('[WidgetDataSync] direct write failed: $e');
    }
  }

  static final _channel = MethodChannel('com.twt.service/saveImg');

  /// Triggers an immediate form update via MethodChannel.
  static void _triggerFormUpdate() {
    try {
      // Read form ID saved by SDCFormAbility.onAddForm
      final formIdFile = File('${Directory.systemTemp.path}/schedule_form_id.txt');
      if (!formIdFile.existsSync()) return;
      final formId = formIdFile.readAsStringSync().trim();
      if (formId.isEmpty) return;
      _channel.invokeMethod('triggerFormUpdate', formId).catchError((_) {});
      debugPrint('[WidgetDataSync] triggerFormUpdate: $formId');
    } catch (e) {
      debugPrint('[WidgetDataSync] triggerFormUpdate error: $e');
    }
  }
}
