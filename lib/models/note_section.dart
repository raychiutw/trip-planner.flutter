/// 筆記 5 區;`name` 即 CRUD API URL 段（flights/lodgings/reservations/pretrip/emergency）。
/// 注意:聚合 GET /notes 的 response key 是 pretripNotes/emergencyContacts,與此段名不同。
library;

enum NoteSection { flights, lodgings, reservations, pretrip, emergency }

/// AI 筆記生成類型;對應 web/backend `/notes/:type/generate` 支援的三種 doc type。
enum NoteGenerationType { tips, lodgingTips, emergency }

/// 把後端回的 `docType` 解成 [NoteGenerationType];未知或缺漏回 `null`。
///
/// 契約未凍結:後端範例只給過 `"tips"`,而 `tips` 的 URL 形(`lodging-tips`)與
/// enum 形(`lodgingTips`)在這個值上同字,推導不出住宿型會回哪一種,因此兩形都接受。
/// 契約凍結後再收斂成單一形。
NoteGenerationType? parseNoteGenerationType(String? raw) => switch (raw) {
  'tips' => NoteGenerationType.tips,
  'lodging-tips' || 'lodgingTips' => NoteGenerationType.lodgingTips,
  'emergency' => NoteGenerationType.emergency,
  _ => null,
};

/// AI 筆記生成類型的 API path 與顯示文字。
extension NoteGenerationTypeX on NoteGenerationType {
  /// API URL path segment.
  String get pathSegment => switch (this) {
    NoteGenerationType.tips => 'tips',
    NoteGenerationType.lodgingTips => 'lodging-tips',
    NoteGenerationType.emergency => 'emergency',
  };

  /// Button label used inside the notes screen.
  String get label => switch (this) {
    NoteGenerationType.tips => '一般',
    NoteGenerationType.lodgingTips => '住宿',
    NoteGenerationType.emergency => 'AI',
  };

  /// User-facing section label used while a job is pending.
  String get pendingLabel => switch (this) {
    NoteGenerationType.emergency => '緊急聯絡',
    _ => '行前須知',
  };
}
