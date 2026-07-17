import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/features/chat/chat_link.dart';

void main() {
  group('mapReplyLink', () {
    test('/trip/:id/notes → /trips/:id/notes', () {
      expect(mapReplyLink('/trip/abc/notes', 'abc'), '/trips/abc/notes');
    });
    test('/trip/:id/map → map root branch', () {
      expect(mapReplyLink('/trip/abc/map', 'abc'), '/map?tripId=abc');
    });
    test('/trip/:id（無 sub）→ /trips/:id', () {
      expect(mapReplyLink('/trip/abc', 'abc'), '/trips/abc');
    });
    test('未對應 sub（health）→ 退回時間軸 /trips/:id', () {
      expect(mapReplyLink('/trip/abc/health', 'abc'), '/trips/abc');
    });
    test('外部連結 → null（不在 app 內導航）', () {
      expect(mapReplyLink('https://example.com', 'abc'), isNull);
    });
    test('一律落在當前 tripId（防 AI 連到別的行程）', () {
      expect(mapReplyLink('/trip/other/notes', 'abc'), '/trips/abc/notes');
    });
    test('帶 query 仍能解析 sub', () {
      expect(mapReplyLink('/trip/abc/map?z=1', 'abc'), '/map?tripId=abc');
    });
  });
}
