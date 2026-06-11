/// 把 AI 回覆 markdown 裡的 web 深連結映射成 app 路由。
library;

/// web 路徑 `/trip/:id/:sub` → app 路徑 `/trips/:tripId/...`。
///
/// - 一律落在當前聊天的 [tripId](忽略 href 內的 id),防 AI 連到別的行程。
/// - sub ∈ {notes, map} → 對應分頁;其他(或無 sub)→ 退回時間軸 `/trips/:id`。
/// - 非站內 `/trip/` 連結(外部 http、mailto…)→ null,不在 app 內導航。
String? mapReplyLink(String href, String tripId) {
  final clean = href.split('?').first.split('#').first;
  if (!clean.startsWith('/trip/')) return null;
  final segments = clean
      .substring('/trip/'.length)
      .split('/')
      .where((s) => s.isNotEmpty)
      .toList();
  // segments[0] = href 內的 id(忽略);segments[1] = sub。
  final sub = segments.length >= 2 ? segments[1] : '';
  return switch (sub) {
    'notes' => '/trips/$tripId/notes',
    'map' => '/trips/$tripId/map',
    _ => '/trips/$tripId',
  };
}
