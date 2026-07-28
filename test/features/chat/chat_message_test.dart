import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/features/chat/chat_message.dart';
import 'package:tripline/models/trip_request.dart';

TripRequest _req({
  int id = 1,
  String message = 'hi',
  String? reply,
  required RequestStatus status,
}) => TripRequest(
  id: id,
  tripId: 't',
  message: message,
  reply: reply,
  status: status,
);

void main() {
  group('rowToMessages', () {
    test('completed → user + assistant(markdown)', () {
      final msgs = rowToMessages(
        _req(message: '改午餐', reply: '**改好了**', status: RequestStatus.completed),
      );
      expect(msgs, hasLength(2));
      expect(msgs[0].role, ChatRole.user);
      expect(msgs[0].text, '改午餐');
      expect(msgs[1].role, ChatRole.assistant);
      expect(msgs[1].text, '**改好了**');
      expect(msgs[1].isMarkdown, isTrue);
    });

    test('failed → assistant isFailed', () {
      final msgs = rowToMessages(
        _req(reply: null, status: RequestStatus.failed),
      );
      expect(msgs.last.isFailed, isTrue);
      expect(msgs.last.text, 'AI 處理失敗。');
      expect(msgs.last.isMarkdown, isFalse);
    });

    test('failed 帶亂碼 reply → placeholder', () {
      final msgs = rowToMessages(
        _req(reply: 'x\uFFFDy', status: RequestStatus.failed),
      );
      expect(msgs.last.isFailed, isTrue);
      expect(msgs.last.text, kGarbledPlaceholder);
    });

    test('processing → 思考中 + pendingRequestId', () {
      final msgs = rowToMessages(_req(id: 9, status: RequestStatus.processing));
      expect(msgs.last.text, '思考中…');
      expect(msgs.last.pendingRequestId, 9);
    });

    test('message 空 → 只有 assistant 氣泡', () {
      final msgs = rowToMessages(
        _req(message: '', reply: 'hi', status: RequestStatus.completed),
      );
      expect(msgs, hasLength(1));
      expect(msgs.single.role, ChatRole.assistant);
    });

    test('特殊前綴 → user 顯示摘要', () {
      final msgs = rowToMessages(
        _req(
          message: '[AI 健檢] 一大坨 system prompt…',
          status: RequestStatus.processing,
        ),
      );
      expect(msgs.first.text, '已觸發 AI 行程健檢');
    });

    test('亂碼 reply → placeholder + 不渲染 markdown', () {
      final msgs = rowToMessages(
        _req(reply: 'good \uFFFD\uFFFD bad', status: RequestStatus.completed),
      );
      expect(msgs.last.text, kGarbledPlaceholder);
      expect(msgs.last.isMarkdown, isFalse);
    });
  });

  group('isGarbledText', () {
    test('正常中文/markdown → false', () {
      expect(isGarbledText('沖繩自由行 **粗體** [連結](/trip/x/notes)'), isFalse);
    });
    test('U+FFFD → true', () => expect(isGarbledText('a\uFFFDb'), isTrue));
    test('C1 控制字元 → true', () => expect(isGarbledText('a\u0085b'), isTrue));
  });

  group('終結原因驅動泡泡文案（ADR-0007）', () {
    TripRequest req(TerminalReason? reason, {String? reply}) => TripRequest(
      id: 1,
      tripId: 't',
      message: '問題',
      reply: reply,
      status: RequestStatus.failed,
      terminalReason: reason,
    );

    test('使用者自己停的:講清楚不是中止,行程仍可能被改', () {
      final msgs = rowToMessages(req(TerminalReason.cancelled));
      final assistant = msgs.last;
      expect(assistant.text, contains('已停止等待'));
      expect(
        assistant.text,
        contains('行程也可能已被更動'),
        reason: '取消不停 worker,這半句是 load-bearing 不能砍',
      );
      expect(assistant.text, isNot(contains('已中止')));
    });

    test('系統收屍:告訴使用者可以重送', () {
      final msgs = rowToMessages(req(TerminalReason.timedOut));
      expect(msgs.last.text, contains('可以重新送出'));
    });

    test('需要授權:講出問題在哪', () {
      final msgs = rowToMessages(req(TerminalReason.needsConsent));
      expect(msgs.last.text, contains('授權'));
    });

    test('後端有回 reply 時以 reply 為準,不用終結文案', () {
      final msgs = rowToMessages(
        req(TerminalReason.cancelled, reply: 'AI 遲到的回報'),
      );
      expect(msgs.last.text, 'AI 遲到的回報');
    });

    test('沒有終結原因就走既有的通用失敗文案', () {
      final msgs = rowToMessages(req(null));
      expect(msgs.last.text, 'AI 處理失敗。');
    });
  });
}
