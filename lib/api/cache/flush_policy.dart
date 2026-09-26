/// flush 時的兩個純決策:單筆失敗該怎麼辦、rebase 重送的 body 長什麼樣。
/// 不碰 store 也不碰網路,直接 unit test。
library;

import '../api_error.dart';
import 'optimistic_patchers.dart';
import 'rebase_merge.dart';

enum FlushErrorAction {
  /// 409 STALE_ENTRY 且型別可 rebase → 重抓 server 真相三方 merge。
  rebase,

  /// 5xx 暫時失敗、401/403 認證未就緒(如 session 過期、冷啟動 sync 早於重新登入)
  /// → 中止保留佇列、待重試,避免永久遺失離線編輯。
  retryLater,

  /// 其他 4xx(409 非 STALE / 400 / 404 等永久無效)→ 上報並移除。
  drop,
}

FlushErrorAction classifyFlushError(ApiError e, {required bool rebasable}) {
  if (e.status == 409 && e.code == 'STALE_ENTRY' && rebasable) {
    return FlushErrorAction.rebase;
  }
  if (e.status >= 500 || e.status == 401 || e.status == 403) {
    return FlushErrorAction.retryLater;
  }
  return FlushErrorAction.drop;
}

/// rebase 重送 body:真實 caller 送整包(full-form),只保留使用者改過的
/// (ours≠base)欄位 + 換新 expectedVersion;使用者沒改的欄位不送 → 保留 server
/// theirs,避免用離線舊值覆蓋協作者的變更。base==null(降級)→ 原 body 全送
/// (last-write-wins)。body 非 Map → 原樣。
///
/// body 欄位是 snake_case(entry: `start_time`、note: `flight_no`),dirty 集合
/// 是 camelCase,故以 [snakeToCamel] 對齊比對;`expectedVersion` 永遠保留並換新值。
Object? rebasedBody(
  Map<String, dynamic>? base,
  Map<String, dynamic> ours,
  Object? body,
  int? newVersion,
) {
  if (body is! Map) return body;
  final dirty = dirtyFields(base, ours);
  return {
    for (final e in body.entries)
      if (e.key == 'expectedVersion')
        e.key: newVersion ?? e.value
      else if (base == null || dirty.contains(snakeToCamel(e.key as String)))
        e.key: e.value,
  };
}
