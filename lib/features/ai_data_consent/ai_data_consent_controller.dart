/// AI 資料同意的共用狀態：聊天、健檢、筆記與帳號設定都讀這一份，不各自存布林。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/ai_data_consent_repository.dart';
import '../../api/api_error.dart';
import '../../api/providers.dart';
import '../../models/ai_data_consent.dart';
import '../../models/user.dart';

/// 目前登入帳號的資料同意狀態；讀不到或不是同意狀態為 null（= 不強制）。
///
/// 依登入者重新取，換帳號不沿用上一個人的結果。
final aiDataConsentProvider =
    AsyncNotifierProvider<AiDataConsentController, AiDataConsent?>(
      AiDataConsentController.new,
    );

class AiDataConsentController extends AsyncNotifier<AiDataConsent?> {
  @override
  Future<AiDataConsent?> build() async {
    // 等認證解析完再讀：身分還在載入時不能把「還不知道」當成「不強制」。
    final UserInfo? user;
    try {
      user = await ref.watch(authStateProvider.future);
    } on Object {
      return null;
    }
    if (user == null) return null;
    return _fetchOrNull();
  }

  Future<AiDataConsent?> _fetchOrNull() async {
    try {
      return await ref.read(aiDataConsentRepositoryProvider).fetch();
    } on Exception {
      return null;
    }
  }

  /// 重讀 server 狀態並更新共用狀態。
  Future<AiDataConsent?> refresh() async {
    final fresh = await _fetchOrNull();
    if (ref.mounted) state = AsyncData(fresh);
    return fresh;
  }

  /// 同意目前看到的版本。版本已被更新（409）時重讀，讓畫面顯示新說明後再丟出。
  Future<void> accept() async {
    final shown = state.value;
    if (shown == null) throw StateError('沒有可同意的說明');
    try {
      final next = await ref
          .read(aiDataConsentRepositoryProvider)
          .accept(shown.currentVersion);
      if (ref.mounted) state = AsyncData(next);
    } on ApiError catch (e) {
      if (isAiConsentVersionMismatch(e)) await refresh();
      rethrow;
    }
  }

  /// 撤回同意。
  Future<void> withdraw() async {
    final next = await ref.read(aiDataConsentRepositoryProvider).withdraw();
    if (ref.mounted) state = AsyncData(next);
  }
}

/// 版本在使用者閱讀期間被更新（409）時顯示的提示。
const kAiConsentVersionChangedMessage = '說明已更新，請確認新版內容後再同意。';

/// 執行同意／撤回動作：成功回 null，失敗回可直接顯示的訊息。
/// 呼叫端只管 setState，不必各自重寫 try/catch 與固定字串。
Future<String?> aiConsentActionError(
  Future<void> Function() run, {
  required String failure,
}) async {
  try {
    await run();
    return null;
  } on Exception catch (e) {
    return isAiConsentVersionMismatch(e)
        ? kAiConsentVersionChangedMessage
        : failure;
  }
}
