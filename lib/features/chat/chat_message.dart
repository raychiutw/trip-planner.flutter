/// 聊天氣泡 view model;由 TripRequest 投影（1 row → 1~2 氣泡）。
/// 三方（自己/他人/AI）判斷由畫面用 submittedBy vs 當前 user email 決定。
library;

import '../../models/trip_request.dart';

enum ChatRole { user, assistant }

class ChatMessage {
  const ChatMessage({
    required this.key,
    required this.role,
    required this.text,
    this.isMarkdown = false,
    this.isFailed = false,
    this.pendingRequestId,
    this.submittedBy,
    this.senderName,
    this.createdAt,
  });

  final String key;
  final ChatRole role;
  final String text;

  /// assistant completed → 以 markdown 渲染。
  final bool isMarkdown;
  final bool isFailed;

  /// open/processing 的 placeholder 對應的 request id（續 poll 用）。
  final int? pendingRequestId;

  /// user 氣泡:送出者 email（畫面比對當前 user 判斷自己/他人）。
  final String? submittedBy;
  final String? senderName;
  final String? createdAt;
}

const Map<String, String> _prefixSummaries = {
  '[AI 健檢]': '已觸發 AI 行程健檢',
  '[行程筆記-lodging-tips]': '已觸發 AI 行程筆記生成（住宿在地建議）',
  '[行程筆記-tips]': '已觸發 AI 行程筆記生成（行前須知）',
  '[行程筆記-emergency]': '已觸發 AI 行程筆記生成（緊急聯絡）',
};

const String kGarbledPlaceholder = '訊息含編碼錯誤,無法顯示';

/// 連續 3+ Latin-1 補充區（U+0080–U+00FF）字元 → mojibake 特徵。
final RegExp _latin1Run = RegExp(r'[\u0080-\u00FF]{3,}');

/// C1 控制字元（U+0080–U+009F）→ 編碼壞掉。
final RegExp _c1Control = RegExp(r'[\u0080-\u009F]');

/// 鏡像 web detectGarbledText:U+FFFD / 連續 3+ Latin-1 補充 / C1 控制字元。
bool isGarbledText(String s) =>
    s.contains('�') || _latin1Run.hasMatch(s) || _c1Control.hasMatch(s);

String _displayUserText(String message) {
  for (final e in _prefixSummaries.entries) {
    if (message.startsWith(e.key)) return e.value;
  }
  return message.replaceFirst(RegExp(r'\s*\(req\s*#\d+\)\s*$'), '').trim();
}

/// 一筆 row → 1~2 個氣泡（message 非空 → user 氣泡;依 status → assistant 氣泡）。
List<ChatMessage> rowToMessages(TripRequest r) {
  final out = <ChatMessage>[];
  if (r.message.isNotEmpty) {
    final t = _displayUserText(r.message);
    out.add(
      ChatMessage(
        key: '${r.id}-u',
        role: ChatRole.user,
        text: isGarbledText(t) ? kGarbledPlaceholder : t,
        submittedBy: r.submittedBy,
        senderName: r.submittedByDisplayName,
        createdAt: r.createdAt,
      ),
    );
  }
  switch (r.status) {
    case RequestStatus.completed:
      final reply = r.reply ?? '';
      final bad = isGarbledText(reply);
      out.add(
        ChatMessage(
          key: '${r.id}-a',
          role: ChatRole.assistant,
          text: bad ? kGarbledPlaceholder : reply,
          isMarkdown: !bad,
          createdAt: r.updatedAt ?? r.createdAt,
        ),
      );
    case RequestStatus.failed:
      final reply = r.reply;
      out.add(
        ChatMessage(
          key: '${r.id}-a',
          role: ChatRole.assistant,
          text: (reply == null || reply.isEmpty)
              ? 'AI 處理失敗。'
              : (isGarbledText(reply) ? kGarbledPlaceholder : reply),
          isFailed: true,
          createdAt: r.updatedAt ?? r.createdAt,
        ),
      );
    case RequestStatus.open:
    case RequestStatus.processing:
      out.add(
        ChatMessage(
          key: '${r.id}-a',
          role: ChatRole.assistant,
          text: '思考中…',
          pendingRequestId: r.id,
          createdAt: r.createdAt,
        ),
      );
  }
  return out;
}
