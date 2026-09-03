import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:wepei_module/commons/channel/image_save/image_save.dart';
import 'package:wepei_module/commons/network/wpy_dio.dart';
import 'package:wepei_module/commons/util/platform.dart';

bool get _isOhos => kIsOhos;

class StorageUtil {
  static late Directory downloadDir;

  static late Directory filesDir;

  static late Directory tempDir;

  static late Directory photoDir;

  static Future<void> init() async {
    if (_isOhos) {
      downloadDir = Directory.systemTemp;
      tempDir = Directory.systemTemp;
      photoDir = Directory.systemTemp;
      // OHOS：系统Temp(=cache 目录) 在清后台/清理缓存时可能被清除，
      // 登录态等持久数据必须放 filesDir（context.filesDir）。
      filesDir = await _ohosFilesDir();
      return;
    }
    downloadDir = Platform.isAndroid
        ? (await getDownloadsDirectory() ??
            (await getExternalStorageDirectories(
                    type: StorageDirectory.downloads))!
                .first)
        : await getApplicationDocumentsDirectory();
    filesDir = await getApplicationSupportDirectory();
    tempDir = await getTemporaryDirectory();
    photoDir = Platform.isAndroid
        ? (await getExternalStorageDirectories(
                type: StorageDirectory.pictures))!
            .first
        : await getApplicationDocumentsDirectory();
  }

  static Future<Directory> _ohosFilesDir() async {
    try {
      final path = await ImageSave.getFilesDir();
      if (path != null && path.isNotEmpty) {
        final dir = Directory(path);
        if (!dir.existsSync()) dir.createSync(recursive: true);
        return dir;
      }
    } catch (_) {}
    // 通道不可用时回退 cache 目录（仍有修复 A 兜底，不丢登录态）
    return Directory.systemTemp;
  }

  static Future<String> saveTempFile(String filename, Uint8List bytes) async {
    final dir = photoDir;
    final file = await File("${dir.path}/$filename").writeAsBytes(bytes);
    return file.path;
  }

  static Future<String> saveTempFileFromNetwork(String url,
      {String filename = ''}) async {
    final res = await Dio()
        .get(url, options: Options(responseType: ResponseType.bytes));
    final dir = tempDir;
    if (filename.isEmpty) {
      filename = Uuid().v1();
    }
    final file = await File("${dir.path}/$filename").writeAsBytes(res.data);
    return file.path;
  }
}
