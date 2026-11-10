import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 守住「文件不得宣稱舊入口（Pages Functions）為現行後端」。
///
/// 舊入口已退役，預設 API origin 是新 api（`kTriplineOrigin`）；網頁版網域
/// `trip-planner-dby.pages.dev` 仍存在，但那是 `kTriplineWebOrigin`，不是 API。
/// 只守四份現行指引文件；有日期的 ADR／研究／QA 文件是歷史紀錄，不在範圍。
void main() {
  const docs = [
    'CLAUDE.md',
    'AGENTS.md',
    'CODING_STANDARDS.md',
    'CONTRIBUTING.md',
  ];
  final forbidden = <String, RegExp>{
    '把網頁網域當 API 入口（dby.pages.dev/api）': RegExp(r'dby\.pages\.dev/api'),
    '宣稱後端是 Pages Functions API': RegExp(r'共用[^\n]{0,12}Pages Functions API'),
    '宣稱預設連 dby.pages.dev': RegExp(r'預設連正式站 `https://trip-planner-dby'),
    '把 dby.pages.dev 寫成 kTriplineOrigin 預設值': RegExp(
      r"defaultValue: 'https://trip-planner-dby",
    ),
    '仍說 master 要等新 api 切換': RegExp(r'新 api 切換前不可發版'),
  };

  for (final doc in docs) {
    test('$doc 不宣稱舊入口為現行後端', () {
      final text = File(doc).readAsStringSync();
      final hits = [
        for (final e in forbidden.entries)
          if (e.value.hasMatch(text)) e.key,
      ];
      expect(hits, isEmpty, reason: '$doc 含過時宣稱');
    });
  }
}
