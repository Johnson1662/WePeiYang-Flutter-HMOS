import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:shared_preferences_platform_interface/types.dart';
import 'package:wepei_module/commons/util/storage_util.dart';

/// In-memory implementation of SharedPreferences-like API for platforms
/// (like HarmonyOS) that don't have the native shared_preferences plugin.
/// Backed by a JSON file on disk so state survives app restarts.
/// 存放在持久化的 filesDir（非 cache），清后台/清理缓存不丢失登录态。
class MockSharedPreferences {
  static MockSharedPreferences? _instance;

  static File get _stateFile =>
      File('${StorageUtil.filesDir.path}/wepeiyang_prefs.json');

  /// 旧版本把 prefs 写在 cache 目录（Directory.systemTemp），
  /// 迁移到持久化 filesDir 后做一次性搬运。
  static File get _legacyStateFile =>
      File('${Directory.systemTemp.path}/wepeiyang_prefs.json');

  final Map<String, Object> _store = {};

  MockSharedPreferences._() {
    _migrateLegacyFile();
    _load();
  }

  void _migrateLegacyFile() {
    try {
      if (!_stateFile.existsSync() && _legacyStateFile.existsSync()) {
        _legacyStateFile.copySync(_stateFile.path);
      }
    } catch (_) {
      // Best-effort migration.
    }
  }

  static Future<MockSharedPreferences> getInstance() async {
    if (_instance == null) {
      _instance = MockSharedPreferences._();
    }
    return _instance!;
  }

  /// Loads persisted preferences from the JSON state file into [_store].
  void _load() {
    try {
      if (_stateFile.existsSync()) {
        final contents = _stateFile.readAsStringSync();
        if (contents.isNotEmpty) {
          final decoded = jsonDecode(contents);
          if (decoded is Map) {
            decoded.forEach((k, v) {
              _store[k.toString()] = v;
            });
          }
        }
      }
    } catch (_) {
      // Best-effort: start with an empty store if the file is corrupt.
    }
  }

  /// Writes the current [_store] to the JSON state file.
  ///
  /// 防抖合并写入：图片缓存等高频写（如滚动加载图片时逐条写 imageExpiresMap）
  /// 原本每次都是全量同步写盘，会阻塞 UI 线程导致卡顿。
  /// 现在 300ms 内合并为一次落盘，且不阻塞调用方。
  Timer? _saveTimer;

  void flush() {
    _saveTimer?.cancel();
    _saveTimer = null;
    try {
      final tmpFile = File('${_stateFile.path}.tmp');
      tmpFile.writeAsStringSync(jsonEncode(_store));
      tmpFile.renameSync(_stateFile.path);
    } catch (_) {
      // Best-effort persistence — never throw on write failure.
    }
  }

  void _save({bool immediate = false}) {
    if (immediate) {
      flush();
      return;
    }
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 300), () {
      flush();
    });
  }

  String? getString(String key) => _store[key] as String?;
  bool? getBool(String key) => _store[key] as bool?;
  int? getInt(String key) => _store[key] as int?;
  double? getDouble(String key) => _store[key] as double?;
  List<String>? getStringList(String key) {
    final value = _store[key];
    return value is List
        ? value.whereType<String>().toList(growable: false)
        : null;
  }

  Object? get(String key) => _store[key];

  Future<void> setString(String key, String value) async {
    _store[key] = value;
    _save();
  }

  Future<void> setBool(String key, bool value) async {
    _store[key] = value;
    _save();
  }

  Future<void> setInt(String key, int value) async {
    _store[key] = value;
    _save();
  }

  Future<void> setDouble(String key, double value) async {
    _store[key] = value;
    _save();
  }

  Future<void> setStringList(String key, List<String> value) async {
    _store[key] = value;
    _save(immediate: true);
  }

  Future<bool> remove(String key) async {
    _store.remove(key);
    _save(immediate: true);
    return true;
  }

  Future<bool> clear() async {
    _store.clear();
    _save(immediate: true);
    return true;
  }
}

/// Platform store adapter connecting Flutter's [SharedPreferences] to [MockSharedPreferences].
/// This ensures any call to [SharedPreferences.getInstance()] anywhere in the app
/// correctly reads from and writes to the persistent JSON file on HarmonyOS.
class MockSharedPreferencesStore extends SharedPreferencesStorePlatform {
  final MockSharedPreferences _mock;

  MockSharedPreferencesStore(this._mock);

  static const String _defaultPrefix = 'flutter.';

  @override
  Future<bool> clear() async {
    return clearWithParameters(
      ClearParameters(
        filter: PreferencesFilter(prefix: _defaultPrefix),
      ),
    );
  }

  @override
  Future<bool> clearWithPrefix(String prefix) async {
    return clearWithParameters(
      ClearParameters(
        filter: PreferencesFilter(prefix: prefix),
      ),
    );
  }

  @override
  Future<bool> clearWithParameters(ClearParameters parameters) async {
    final PreferencesFilter filter = parameters.filter;
    if (filter.allowList != null) {
      _mock._store.removeWhere((String key, _) =>
          key.startsWith(filter.prefix) && filter.allowList!.contains(key));
    } else {
      _mock._store.removeWhere((String key, _) => key.startsWith(filter.prefix));
    }
    _mock.flush();
    return true;
  }

  @override
  Future<Map<String, Object>> getAll() async {
    return getAllWithParameters(
      GetAllParameters(
        filter: PreferencesFilter(prefix: _defaultPrefix),
      ),
    );
  }

  @override
  Future<Map<String, Object>> getAllWithPrefix(String prefix) async {
    return getAllWithParameters(
      GetAllParameters(
        filter: PreferencesFilter(prefix: prefix),
      ),
    );
  }

  @override
  Future<Map<String, Object>> getAllWithParameters(
      GetAllParameters parameters) async {
    final PreferencesFilter filter = parameters.filter;
    final Map<String, Object> preferences = {};
    _mock._store.forEach((key, value) {
      if (!key.startsWith(filter.prefix)) return;
      if (filter.allowList != null && !filter.allowList!.contains(key)) return;
      if (value is List) {
        preferences[key] = value.whereType<String>().toList();
      } else {
        preferences[key] = value;
      }
    });
    return preferences;
  }

  @override
  Future<bool> remove(String key) async {
    _mock._store.remove(key);
    _mock.flush();
    return true;
  }

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (value is List<String>) {
      _mock._store[key] = value.toList();
    } else {
      _mock._store[key] = value;
    }
    _mock.flush();
    return true;
  }
}
