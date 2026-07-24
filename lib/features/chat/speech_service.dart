/// 語音輸入的薄抽象層:把 speech_to_text 包成可測介面,
/// widget 只依賴 [SpeechService](測試 override mock),不碰真實 platform channel。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// 語音辨識服務介面。回傳的辨識文字交由 UI 回填輸入框。
abstract class SpeechService {
  /// 初始化(請求權限 / 確認裝置支援)。成功回 true,失敗或不支援回 false。
  Future<bool> init();

  /// 開始聆聽。每次有辨識結果(含 partial)就呼叫 [onResult] 帶上最新文字。
  Future<void> listen(void Function(String text) onResult);

  /// 停止聆聽。
  Future<void> stop();

  /// 開啟 App 的系統設定頁，讓使用者自行調整已拒絕的權限。
  Future<bool> openSettings();

  /// 是否可用(init 成功後為 true)。
  bool get isAvailable;
}

/// 以 speech_to_text 實作的 [SpeechService]。
class SpeechToTextService implements SpeechService {
  SpeechToTextService([SpeechToText? speech])
    : _speech = speech ?? SpeechToText();

  final SpeechToText _speech;

  @override
  bool get isAvailable => _speech.isAvailable;

  @override
  Future<bool> init() => _speech.initialize();

  @override
  Future<void> listen(void Function(String text) onResult) {
    return _speech.listen(
      onResult: (SpeechRecognitionResult result) {
        onResult(result.recognizedWords);
      },
    );
  }

  @override
  Future<void> stop() => _speech.stop();

  @override
  Future<bool> openSettings() => openAppSettings();
}

/// 預設真實作;測試 override 成 mock。
final speechServiceProvider = Provider<SpeechService>(
  (ref) => SpeechToTextService(),
);
