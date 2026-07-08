/// 本機 JSON 離線快取。
library;

import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

abstract class OfflineCache {
  Future<dynamic> readJson(String key);

  Future<void> writeJson(String key, Object? value);
}

class NoopOfflineCache implements OfflineCache {
  const NoopOfflineCache();

  @override
  Future<dynamic> readJson(String key) async => null;

  @override
  Future<void> writeJson(String key, Object? value) async {}
}

class InMemoryOfflineCache implements OfflineCache {
  final Map<String, dynamic> _store = {};

  @override
  Future<dynamic> readJson(String key) async {
    final value = _store[key];
    if (value == null) return null;
    return _jsonClone(value);
  }

  @override
  Future<void> writeJson(String key, Object? value) async {
    if (value == null) {
      _store.remove(key);
      return;
    }
    _store[key] = _jsonClone(value);
  }
}

class FileOfflineCache implements OfflineCache {
  FileOfflineCache({this.namespace = 'api-v1'});

  final String namespace;

  @override
  Future<dynamic> readJson(String key) async {
    final file = await _fileForKey(key);
    if (!await file.exists()) return null;
    try {
      return jsonDecode(await file.readAsString());
    } on FormatException {
      return null;
    } on IOException {
      return null;
    }
  }

  @override
  Future<void> writeJson(String key, Object? value) async {
    final file = await _fileForKey(key);
    if (value == null) {
      if (await file.exists()) await file.delete();
      return;
    }
    await file.writeAsString(jsonEncode(value), flush: true);
  }

  Future<File> _fileForKey(String key) async {
    final supportDirectory = await getApplicationSupportDirectory();
    final cacheDirectory = Directory(
      '${supportDirectory.path}${Platform.pathSeparator}offline_cache${Platform.pathSeparator}$namespace',
    );
    await cacheDirectory.create(recursive: true);
    return File(
      '${cacheDirectory.path}${Platform.pathSeparator}${_fileNameForKey(key)}.json',
    );
  }

  String _fileNameForKey(String key) {
    return base64Url.encode(utf8.encode(key)).replaceAll('=', '');
  }
}

dynamic _jsonClone(Object value) {
  return jsonDecode(jsonEncode(value));
}
