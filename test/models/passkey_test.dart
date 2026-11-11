import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/models/passkey.dart';

void main() {
  test('fromJson：後端完整欄位', () {
    final passkey = Passkey.fromJson({
      'id': 'cred-1',
      'name': '我的 iPhone',
      'transports': ['internal', 'hybrid'],
      'backupEligible': true,
      'createdAt': '2026-11-01 08:00:00',
      'lastUsedAt': '2026-11-10 09:30:00',
    });

    expect(passkey.id, 'cred-1');
    expect(passkey.name, '我的 iPhone');
    expect(passkey.transports, ['internal', 'hybrid']);
    expect(passkey.backupEligible, isTrue);
    expect(passkey.createdAt, '2026-11-01 08:00:00');
    expect(passkey.lastUsedAt, '2026-11-10 09:30:00');
  });

  test('fromJson：沒用過（lastUsedAt null）、transports 缺漏 → []、旗標 0/1', () {
    final passkey = Passkey.fromJson({
      'id': 'cred-2',
      'name': 'Passkey',
      'backupEligible': 1,
      'createdAt': '2026-11-01 08:00:00',
      'lastUsedAt': null,
    });

    expect(passkey.lastUsedAt, isNull);
    expect(passkey.transports, isEmpty);
    expect(passkey.backupEligible, isTrue);
    expect(
      Passkey.fromJson({
        'id': 'c',
        'name': 'n',
        'backupEligible': 0,
        'createdAt': 'x',
      }).backupEligible,
      isFalse,
    );
  });

  test('fromJson：註冊 verify 回應沒有 lastUsedAt 欄位也能解析', () {
    final passkey = Passkey.fromJson({
      'id': 'cred-3',
      'name': 'Passkey',
      'transports': <String>[],
      'backupEligible': false,
      'createdAt': null,
    });

    expect(passkey.lastUsedAt, isNull);
    expect(passkey.createdAt, isNull);
  });
}
