import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:tripline/api/api_client.dart';
import 'package:tripline/api/api_error.dart';
import 'package:tripline/api/passkey_repository.dart';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late PasskeyRepository repository;

  setUp(() {
    dio = Dio();
    adapter = DioAdapter(dio: dio);
    repository = PasskeyRepository(client: ApiClient(dio: dio));
  });

  const credential = {
    'id': 'cred-1',
    'rawId': 'cred-1',
    'type': 'public-key',
    'response': {
      'clientDataJSON': 'cd',
      'attestationObject': 'ao',
      'transports': ['internal'],
    },
  };

  test('list：GET /account/passkeys 取出 passkeys 陣列', () async {
    adapter.onGet(
      '/account/passkeys',
      (server) => server.reply(200, {
        'passkeys': [
          {
            'id': 'cred-1',
            'name': '我的 iPhone',
            'transports': ['internal'],
            'backupEligible': true,
            'createdAt': '2026-11-01 08:00:00',
            'lastUsedAt': null,
          },
        ],
      }),
    );

    final passkeys = await repository.list();

    expect(passkeys.single.name, '我的 iPhone');
  });

  test('list：沒有 passkey → 空清單', () async {
    adapter.onGet(
      '/account/passkeys',
      (server) => server.reply(200, {'passkeys': <dynamic>[]}),
    );

    expect(await repository.list(), isEmpty);
  });

  test(
    'registerOptions：POST /account/passkeys/register/options 原樣回傳選項',
    () async {
      adapter.onPost(
        '/account/passkeys/register/options',
        (server) => server.reply(200, {
          'challenge': 'ch',
          'rp': {'id': 'trip-planner-dby.pages.dev', 'name': 'Tripline'},
        }),
        data: <String, dynamic>{},
      );

      final options = await repository.registerOptions();

      expect(options['challenge'], 'ch');
    },
  );

  test('registerVerify：POST verify 帶 credential 與 name，回傳新 passkey', () async {
    adapter.onPost(
      '/account/passkeys/register/verify',
      (server) => server.reply(201, {
        'id': 'cred-1',
        'name': '我的 iPhone',
        'transports': ['internal'],
        'backupEligible': true,
        'createdAt': '2026-11-11 01:00:00',
      }),
      data: {'credential': credential, 'name': '我的 iPhone'},
    );

    final created = await repository.registerVerify(
      credential: credential,
      name: '我的 iPhone',
    );

    expect(created.id, 'cred-1');
    expect(created.name, '我的 iPhone');
  });

  test('registerVerify：沒有 name 就不送 name 欄位（交給後端用預設名稱）', () async {
    adapter.onPost(
      '/account/passkeys/register/verify',
      (server) => server.reply(201, {
        'id': 'cred-1',
        'name': 'Passkey',
        'transports': <String>[],
        'backupEligible': false,
        'createdAt': null,
      }),
      data: {'credential': credential},
    );

    final created = await repository.registerVerify(credential: credential);

    expect(created.name, 'Passkey');
  });

  test(
    'registerVerify：409 PASSKEY_ALREADY_REGISTERED 丟 ApiError 保留 code',
    () async {
      adapter.onPost(
        '/account/passkeys/register/verify',
        (server) => server.reply(409, {
          'error': {'code': 'PASSKEY_ALREADY_REGISTERED', 'message': 'dup'},
        }),
        data: {'credential': credential},
      );

      await expectLater(
        repository.registerVerify(credential: credential),
        throwsA(
          isA<ApiError>()
              .having((e) => e.status, 'status', 409)
              .having((e) => e.code, 'code', 'PASSKEY_ALREADY_REGISTERED'),
        ),
      );
    },
  );

  test('rename：PATCH /account/passkeys/:id 路徑參數有編碼', () async {
    adapter.onPatch(
      '/account/passkeys/a%2Fb',
      (server) => server.reply(200, {
        'id': 'a/b',
        'name': '公司筆電',
        'transports': <String>[],
        'backupEligible': false,
        'createdAt': 'x',
        'lastUsedAt': null,
      }),
      data: {'name': '公司筆電'},
    );

    final renamed = await repository.rename('a/b', '公司筆電');

    expect(renamed.name, '公司筆電');
  });

  test('revoke：DELETE /account/passkeys/:id', () async {
    adapter.onDelete(
      '/account/passkeys/cred-1',
      (server) => server.reply(200, {'ok': true, 'revoked_id': 'cred-1'}),
    );

    await repository.revoke('cred-1');
  });

  test('revoke：404 丟 ApiError', () async {
    adapter.onDelete(
      '/account/passkeys/gone',
      (server) => server.reply(404, {
        'error': {'code': 'PASSKEY_NOT_FOUND', 'message': '找不到'},
      }),
    );

    await expectLater(
      repository.revoke('gone'),
      throwsA(isA<ApiError>().having((e) => e.status, 'status', 404)),
    );
  });
}
