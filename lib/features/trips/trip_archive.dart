import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_error.dart';
import '../../api/providers.dart';
import '../../app/adaptive.dart';
import '../../app/app_feedback.dart';

/// 行程歸檔／取消歸檔：確認 → PUT／DELETE `/trips/:id/archive` → 回饋。
///
/// 歸檔只改清單分類，不是破壞性動作，所以確認鈕用一般樣式。線上限定（不進離線佇列），
/// 離線與其他錯誤一律顯示通用失敗訊息，不假裝成功。成功後呼叫 [onChanged]
/// 讓呼叫端刷新行程清單；文案與 Web 一致。
Future<void> confirmAndSetTripArchived(
  BuildContext context,
  WidgetRef ref, {
  required String tripId,
  required String title,

  /// 目前是否已歸檔：true 代表這次動作是「取消歸檔」。
  required bool archived,
  required VoidCallback onChanged,
}) async {
  final confirmed = await showAppConfirm(
    context,
    title: archived ? '取消歸檔行程？' : '歸檔行程？',
    message: archived
        ? '「$title」會回到所有旅伴的「全部」清單。'
        : '「$title」會移到所有旅伴的「已歸檔」；旅伴仍可開啟詳情。你正在閱讀的詳情會保持開啟。',
    confirmLabel: archived ? '取消歸檔' : '歸檔',
  );
  if (!confirmed || !context.mounted) return;
  await _apply(
    context,
    ref,
    tripId: tripId,
    title: title,
    archived: archived,
    onChanged: onChanged,
  );
}

Future<void> _apply(
  BuildContext context,
  WidgetRef ref, {
  required String tripId,
  required String title,
  required bool archived,
  required VoidCallback onChanged,
}) async {
  final repository = ref.read(tripRepositoryProvider);
  try {
    if (archived) {
      await repository.unarchiveTrip(tripId);
    } else {
      await repository.archiveTrip(tripId);
    }
  } on Object catch (error) {
    if (!context.mounted) return;
    final forbidden = error is ApiError && error.status == 403;
    showAppError(
      context,
      forbidden ? '只有行程擁有者能變更歸檔狀態。' : '更新歸檔狀態失敗，請再試一次。',
      onRetry: forbidden
          ? null
          : () => unawaited(
              _apply(
                context,
                ref,
                tripId: tripId,
                title: title,
                archived: archived,
                onChanged: onChanged,
              ),
            ),
    );
    return;
  }
  onChanged();
  if (!context.mounted) return;
  showAppNotice(context, archived ? '已取消歸檔「$title」' : '已歸檔「$title」');
}
