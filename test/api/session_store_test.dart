import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/api/session_store.dart';

void main() {
  group('InMemorySessionStore', () {
    test('初始狀態 read 回 null', () async {
      final sessionStore = InMemorySessionStore();

      expect(await sessionStore.read(), isNull);
    });

    test('write 後 read 回寫入的 token', () async {
      final sessionStore = InMemorySessionStore();

      await sessionStore.write('abc.def');

      expect(await sessionStore.read(), 'abc.def');
    });

    test('clear 後 read 回 null', () async {
      final sessionStore = InMemorySessionStore();

      await sessionStore.write('abc.def');
      await sessionStore.clear();

      expect(await sessionStore.read(), isNull);
    });

    test('是 SessionStore 的實作（可注入替身）', () {
      expect(InMemorySessionStore(), isA<SessionStore>());
    });
  });
}
