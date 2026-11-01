import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/api/dpop/proof_key_store.dart';
import 'package:tripline/app/hardware_proof_key_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('tripline/proof-key');
  late List<MethodCall> calls;

  void handle(Future<Object?>? Function(MethodCall call) handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return handler(call);
        });
  }

  setUp(() => calls = []);
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  test('create：回硬體金鑰，公鑰 jwk 由原生回傳的 x、y 組成', () async {
    handle((_) async => {'x': 'XX', 'y': 'YY'});

    final key = await HardwareProofKeyStore().create();

    expect(key.kind, 'hardware');
    expect(key.publicJwk, {'kty': 'EC', 'crv': 'P-256', 'x': 'XX', 'y': 'YY'});
    expect(calls.single.method, 'create');
  });

  test('sign：把要簽的資料交給原生，回 64 bytes 簽章', () async {
    handle((call) async {
      if (call.method == 'create') return {'x': 'XX', 'y': 'YY'};
      return Uint8List.fromList(List.filled(64, 7));
    });
    final key = await HardwareProofKeyStore().create();

    final sig = await key.sign(Uint8List.fromList([1, 2, 3]));

    expect(sig, Uint8List.fromList(List.filled(64, 7)));
    final signCall = calls.last;
    expect(signCall.method, 'sign');
    expect((signCall.arguments as Map)['data'], Uint8List.fromList([1, 2, 3]));
  });

  test('load：沒有金鑰回 null；有就回硬體金鑰', () async {
    handle((_) async => null);
    expect(await HardwareProofKeyStore().load(), isNull);

    handle((_) async => {'x': 'XX', 'y': 'YY'});
    expect((await HardwareProofKeyStore().load())!.kind, 'hardware');
  });

  test('delete：呼叫原生 delete', () async {
    handle((_) async => null);

    await HardwareProofKeyStore().delete();

    expect(calls.single.method, 'delete');
  });

  group('不支援的環境一律回報 ProofKeyUnsupportedException（讓工廠退軟體）', () {
    test('原生回 unsupported', () async {
      handle((_) async => throw PlatformException(code: 'unsupported'));

      await expectLater(
        HardwareProofKeyStore().create(),
        throwsA(isA<ProofKeyUnsupportedException>()),
      );
    });

    test('沒有原生 channel（測試、桌面）', () async {
      // 沒有 handler → MissingPluginException。
      await expectLater(
        HardwareProofKeyStore().create(),
        throwsA(isA<ProofKeyUnsupportedException>()),
      );
    });

    test('原生建立失敗（任何 PlatformException）也退軟體，不擋登入', () async {
      handle(
        (_) async => throw PlatformException(code: 'key_generation_failed'),
      );

      await expectLater(
        HardwareProofKeyStore().create(),
        throwsA(isA<ProofKeyUnsupportedException>()),
      );
    });
  });

  test('load 遇到原生錯誤（金鑰失效等）回 null，不丟例外', () async {
    handle((_) async => throw PlatformException(code: 'key_invalidated'));

    expect(await HardwareProofKeyStore().load(), isNull);
  });

  test('delete 遇到沒有原生 channel 時不丟例外', () async {
    await HardwareProofKeyStore().delete();
  });

  test('sign 回來的簽章不是 64 bytes：視為失敗，不把壞簽章交給伺服器', () async {
    handle((call) async {
      if (call.method == 'create') return {'x': 'XX', 'y': 'YY'};
      return Uint8List.fromList(List.filled(70, 1)); // 像是沒轉換的 DER
    });
    final key = await HardwareProofKeyStore().create();

    await expectLater(
      key.sign(Uint8List(1)),
      throwsA(isA<PlatformException>()),
    );
  });

  test('sign 失敗時把錯誤往上丟（簽不出來不能假裝成功）', () async {
    handle((call) async {
      if (call.method == 'create') return {'x': 'XX', 'y': 'YY'};
      throw PlatformException(code: 'sign_failed');
    });
    final key = await HardwareProofKeyStore().create();

    await expectLater(
      key.sign(Uint8List(1)),
      throwsA(isA<PlatformException>()),
    );
  });
}
