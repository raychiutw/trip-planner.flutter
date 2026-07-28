/// 筆記 5 區;`name` 即 CRUD API URL 段（flights/lodgings/reservations/pretrip/emergency）。
/// 注意:聚合 GET /notes 的 response key 是 pretripNotes/emergencyContacts,與此段名不同。
library;

enum NoteSection { flights, lodgings, reservations, pretrip, emergency }

/// AI 筆記生成類型;對應 web/backend `/notes/:type/generate` 支援的三種 doc type。
enum NoteGenerationType { tips, lodgingTips, emergency }

/// 把後端回的 `docType` 解成 [NoteGenerationType];未知或缺漏回 `null`。
///
/// 契約已凍結:後端 `NOTE_AI_DOC_TYPES = ['lodging-tips', 'tips', 'emergency']`
/// **一律 URL 形**,不會回 `lodgingTips`。enum 形保留純粹當防禦(多接一個值域外的
/// 字串不會讓解析變差),不是契約要求。
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

  /// 進行中面板與完成提示用的顯示名稱。
  ///
  /// 三種各自可辨識:行前須知底下有「一般」與「住宿」兩種生成,兩個同時在跑時
  /// 使用者要看得出哪一條是哪一種,所以不能兩者都只寫「行前須知」。
  String get pendingLabel => switch (this) {
    NoteGenerationType.tips => '行前須知（一般）',
    NoteGenerationType.lodgingTips => '行前須知（住宿）',
    NoteGenerationType.emergency => '緊急聯絡',
  };
}
