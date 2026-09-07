import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 守住「repo 內每一條 markdown 相對連結都指向存在的路徑」。
///
/// 刪除文件時最容易留下的殘骸就是懸空連結：README 的文件索引、`CLAUDE.md` 與
/// `AGENTS.md` 的指標、ADR 之間的交叉引用，全都會指向已經不在的檔。人工檢查
/// 撐不住一次刪掉數十份文件的規模，所以交給測試。
///
/// 只驗證檔案是否存在，不驗證錨點（`#section`）—— 錨點會隨標題改寫漂移，
/// 守它的成本高於價值。外部連結（`http(s)://`、`mailto:`）也不驗證，那需要
/// 連網，測試不該依賴網路。
void main() {
  test('markdown 相對連結全部指向存在的路徑', () {
    final broken = <String>[];

    for (final file in _markdownFiles(Directory('.'))) {
      final source = file.path.replaceAll('\\', '/').replaceFirst('./', '');
      final dir = _parentOf(source);

      var insideFence = false;
      final lines = file.readAsLinesSync();
      for (var index = 0; index < lines.length; index++) {
        final line = lines[index];

        // 圍籬內的連結是範例，不是真的指標。
        if (_fencePattern.hasMatch(line)) {
          insideFence = !insideFence;
          continue;
        }
        if (insideFence) continue;

        for (final match in _linkPattern.allMatches(line)) {
          final target = _fileTargetOf(match.group(1)!);
          if (target == null) continue;

          final resolved = _normalize(
            target.startsWith('/')
                ? target.substring(1)
                : (dir.isEmpty ? target : '$dir/$target'),
          );
          if (resolved.isEmpty) continue;
          if (File(resolved).existsSync() || Directory(resolved).existsSync()) {
            continue;
          }
          broken.add('$source:${index + 1} → ${match.group(1)}');
        }
      }
    }

    expect(
      broken,
      isEmpty,
      reason:
          '以下 markdown 連結指向不存在的路徑（刪除文件後請一併修正指標）:\n'
          '${broken.join('\n')}',
    );
  });
}

/// `[顯示文字](路徑)` 或 `[顯示文字](路徑 "title")` 的路徑部分。
final _linkPattern = RegExp(r'\[[^\]]*\]\(\s*([^)\s]+)(?:\s+"[^"]*")?\s*\)');

final _fencePattern = RegExp(r'^\s{0,3}(?:```|~~~)');

/// 只掃 git 追蹤的 markdown:沒進版控的目錄(建置產物、`ios/.symlinks/` 這類
/// 套件符號連結)裡是第三方套件自己的 README,連結指向它們的 repo,不是本 repo 的
/// 文件,不該由這條測試守。`git ls-files` 拿不到(不在 git 內)就退回目錄掃描。
Iterable<File> _markdownFiles(Directory root) {
  final result = Process.runSync('git', [
    'ls-files',
    '-z',
    '--',
    '*.md',
  ], workingDirectory: root.path);
  if (result.exitCode != 0) return _walk(root);
  final paths = (result.stdout as String)
      .split('\u0000')
      .where((p) => p.isNotEmpty);
  return [for (final path in paths) File('${root.path}/$path')];
}

const _skippedDirectories = {
  '.dart_tool',
  '.git',
  '.gradle',
  '.idea',
  'build',
  'node_modules',
  'Pods',
};

Iterable<File> _walk(Directory root) sync* {
  for (final entity in root.listSync()) {
    if (entity is Directory) {
      final name = entity.path.replaceAll('\\', '/').split('/').last;
      if (_skippedDirectories.contains(name)) continue;
      yield* _walk(entity);
    } else if (entity is File && entity.path.endsWith('.md')) {
      yield entity;
    }
  }
}

/// 取連結的檔案部分；外部連結與純錨點回 `null`（不驗證）。
String? _fileTargetOf(String rawLink) {
  final link = rawLink.trim();
  if (link.startsWith('http://') ||
      link.startsWith('https://') ||
      link.startsWith('mailto:') ||
      link.startsWith('#')) {
    return null;
  }
  final target = link.split('#').first;
  return target.isEmpty ? null : Uri.decodeFull(target);
}

String _parentOf(String path) {
  final cut = path.lastIndexOf('/');
  return cut < 0 ? '' : path.substring(0, cut);
}

/// 收斂 `.` 與 `..`，讓比對不受寫法影響。
String _normalize(String path) {
  final segments = <String>[];
  for (final segment in path.split('/')) {
    if (segment.isEmpty || segment == '.') continue;
    if (segment == '..') {
      if (segments.isNotEmpty && segments.last != '..') {
        segments.removeLast();
      } else {
        segments.add(segment);
      }
      continue;
    }
    segments.add(segment);
  }
  return segments.join('/');
}
