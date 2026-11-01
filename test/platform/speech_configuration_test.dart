import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// speech_to_text 在 Android 11+ 需要 package visibility 宣告，否則
/// `isRecognitionAvailable()` 回 false，語音輸入在真機上靜默失效（#453）。
void main() {
  test('Android manifest 的 queries 宣告 RecognitionService', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final queries = RegExp(
      r'<queries>.*?</queries>',
      dotAll: true,
    ).firstMatch(manifest)?.group(0);

    expect(queries, isNotNull);
    expect(
      queries,
      contains('<action android:name="android.speech.RecognitionService"'),
    );
  });
}
