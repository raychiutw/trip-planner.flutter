/// 三個受管制 AI 入口（聊天、行程健檢、AI 筆記）共用的就地同意流程。
///
/// 一律「資料同意先於操作」：本地已知未同意 → 先跳 sheet，同意前不發 AI mutation；
/// 本地不知道（讀不到、狀態過期）→ 讓 server 的 403 當最終關卡，再就地補同意，
/// 接續**同一個**使用者動作恰好一次。旗標關閉（server 不擋）時完全不介入。
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_feedback.dart';
import '../../models/ai_data_consent.dart';
import 'ai_data_consent_controller.dart';
import 'ai_data_consent_sheet.dart';

/// 讀不到說明文字、無法確認同意狀態時的錯誤訊息。
const kAiConsentUnavailableMessage = '暫時無法確認 AI 資料同意，請稍後再試。';

/// 第一次被 server 403 擋下並詢問之後，最多還能「再」詢問幾次。
///
/// 事前詢問（本地已知未同意）與第一次被擋後的詢問都不計入，所以單次操作最多出現
/// 1（事前）+ 1（第一次被擋）+ 本常數 次 sheet。升版是低頻事件，一次重問就足以涵蓋
/// 看 sheet 期間又升版的競態；超過仍被擋代表狀態不一致或後端異常，再問只會讓使用者
/// 陷入同意迴圈，改顯示「無法確認」。
const kAiConsentMaxReprompts = 1;

/// 執行 [action]（必須用 `translateAiConsentGate` 包過 mutation，被擋時丟
/// [AiConsentRequiredException]）。回傳 null = 使用者取消、owner 未同意、或同意後
/// [isCurrent] 已為 false（換行程／離頁），此時動作沒有（再）執行。
///
/// [keptMessage] 有值代表使用者輸入已被保留，sheet 會提示同意後會自動接續。
/// 重新讀不到說明文字時不猜（也不繞過閘門）：顯示「無法確認」錯誤並回 null，
/// 呼叫端不必另外處理 [AiConsentRequiredException]。
Future<T?> runWithAiDataConsent<T extends Object>(
  BuildContext context,
  WidgetRef ref, {
  required Future<T?> Function() action,
  String? keptMessage,
  bool Function()? isCurrent,
}) async {
  bool current() => isCurrent?.call() ?? true;
  final notifier = ref.read(aiDataConsentProvider.notifier);

  Future<bool> askConsent(AiDataConsent consent) async {
    final accepted = await showAiDataConsentSheet(
      context,
      initial: consent,
      keptMessage: keptMessage,
    );
    return accepted && context.mounted && current();
  }

  Future<T?> tellOwnerMissing() async {
    await showAiOwnerConsentMissingSheet(
      context,
      inputKept: keptMessage != null,
    );
    return null;
  }

  Future<T?> unavailable() async {
    if (context.mounted) showAppError(context, kAiConsentUnavailableMessage);
    return null;
  }

  final known = await ref.read(aiDataConsentProvider.future);
  if (!context.mounted || !current()) return null;
  if (known != null && known.needsConsent && !await askConsent(known)) {
    return null;
  }

  Future<T?> afterGate(AiConsentRequiredException gate, int reprompts) async {
    if (gate.party == AiConsentParty.owner) return tellOwnerMissing();
    if (reprompts > kAiConsentMaxReprompts) return unavailable();
    final fresh = await notifier.refresh();
    if (!context.mounted || !current()) return null;
    if (fresh == null) return unavailable();
    if (!await askConsent(fresh)) return null;
    try {
      return await action();
    } on AiConsentRequiredException catch (again) {
      if (!context.mounted) return null;
      return afterGate(again, reprompts + 1);
    }
  }

  try {
    return await action();
  } on AiConsentRequiredException catch (gate) {
    return afterGate(gate, 0);
  }
}
