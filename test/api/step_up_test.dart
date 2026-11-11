import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/api/account_repository.dart';
import 'package:tripline/api/api_client.dart';
import 'package:tripline/api/api_error.dart';
import 'package:tripline/api/auth_repository.dart';
import 'package:tripline/api/passkey_repository.dart';
import 'package:tripline/api/share_repository.dart';
import 'package:tripline/api/step_up.dart';
import 'package:tripline/api/trip_repository.dart';

/// 假的 api：記錄所有請求；敏感端點在 [enforce] 開啟時要求 `X-Step-Up-Proof == validProof`。
class _FakeServer implements HttpClientAdapter {
  bool enforce = true;
  String validProof = 'proof-1';
  final requests = <RequestOptions>[];
  final bodies = <String>[];

  /// 敏感端點（method + path）。
  static const sensitive = {
    'POST /api/account/password',
    'DELETE /api/trips/t1',
    'PATCH /api/trips/t1/shares/7',
    'DELETE /api/trips/t1/shares/7',
    'DELETE /api/account/passkeys/c1',
    'DELETE /api/account',
  };

  List<RequestOptions> to(String method, String path) => requests
      .where((r) => r.method == method && r.uri.path == path)
      .toList(growable: false);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    bodies.add(jsonEncode(options.data));
    final key = '${options.method} ${options.uri.path}';
    if (enforce &&
        sensitive.contains(key) &&
        options.headers['X-Step-Up-Proof'] != validProof) {
      return _json(403, {
        'error': {'code': 'REAUTH_REQUIRED', 'message': '需要重新驗證'},
      });
    }
    return ResponseBody.fromString('', 204);
  }

  static ResponseBody _json(int status, Object body) => ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}

class _FakePrompter implements StepUpPrompter {
  /// 依序消耗；耗盡後回最後一個。null = 取消。
  List<StepUpProof?> answers = [
    const StepUpProof(proof: 'proof-1', expiresIn: 300),
  ];
  int calls = 0;
  Completer<void>? hold;

  @override
  Future<StepUpProof?> prompt() async {
    final answer = answers[calls < answers.length ? calls : answers.length - 1];
    calls++;
    await hold?.future;
    return answer;
  }
}

void main() {
  late _FakeServer server;
  late _FakePrompter prompter;
  late StepUpProofStore store;
  late DateTime now;
  late StepUpGate gate;
  late ApiClient client;

  late TripRepository trips;
  late ShareRepository shares;
  late PasskeyRepository passkeys;
  late AccountRepository account;
  late AuthRepository auth;

  setUp(() {
    server = _FakeServer();
    prompter = _FakePrompter();
    now = DateTime(2026, 11, 11, 12);
    store = StepUpProofStore(now: () => now);
    gate = StepUpGate(store: store, prompter: prompter);
    client = ApiClient(dio: Dio()..httpClientAdapter = server);
    trips = TripRepository(client: client, stepUp: gate);
    shares = ShareRepository(client: client, stepUp: gate);
    passkeys = PasskeyRepository(client: client, stepUp: gate);
    account = AccountRepository(client: client, stepUp: gate);
    auth = AuthRepository(client: client, stepUp: gate);
  });

  // 五個敏感操作（刪除與撤銷分享算同一類，兩個端點都列）。
  final operations =
      <
        ({String name, String method, String path, Future<void> Function() run})
      >[
        (
          name: '變更密碼',
          method: 'POST',
          path: '/api/account/password',
          run: () => account.changePassword(
            currentPassword: 'old-pw',
            newPassword: 'new-pw-1234',
          ),
        ),
        (
          name: '刪除行程',
          method: 'DELETE',
          path: '/api/trips/t1',
          run: () => trips.deleteTrip('t1'),
        ),
        (
          name: '撤銷分享（PATCH revoke）',
          method: 'PATCH',
          path: '/api/trips/t1/shares/7',
          run: () => shares.revokeShare('t1', 7),
        ),
        (
          name: '刪除分享（DELETE）',
          method: 'DELETE',
          path: '/api/trips/t1/shares/7',
          run: () => shares.deleteShare('t1', 7),
        ),
        (
          name: '撤銷 passkey',
          method: 'DELETE',
          path: '/api/account/passkeys/c1',
          run: () => passkeys.revoke('c1'),
        ),
        (
          name: '刪除帳號',
          method: 'DELETE',
          path: '/api/account',
          run: () => auth.deleteAccount(password: 'pw'),
        ),
      ];

  for (final op in operations) {
    group(op.name, () {
      test('收到 REAUTH_REQUIRED → 問一次 → 成功後帶 X-Step-Up-Proof 重試一次', () async {
        await op.run();

        final sent = server.to(op.method, op.path);
        expect(sent, hasLength(2));
        expect(sent[0].headers.containsKey('X-Step-Up-Proof'), isFalse);
        expect(sent[1].headers['X-Step-Up-Proof'], 'proof-1');
        expect(prompter.calls, 1);
      });

      test('取消 → 丟 StepUpCancelledException，不重試', () async {
        prompter.answers = [null];

        await expectLater(op.run(), throwsA(isA<StepUpCancelledException>()));

        expect(server.to(op.method, op.path), hasLength(1));
        expect(store.valid, isNull);
      });

      test('沒收到 REAUTH_REQUIRED（api 未開強制）→ 一個請求、不帶標頭、不詢問', () async {
        server.enforce = false;

        await op.run();

        final sent = server.to(op.method, op.path);
        expect(sent, hasLength(1));
        expect(sent.single.headers.containsKey('X-Step-Up-Proof'), isFalse);
        expect(prompter.calls, 0);
      });
    });
  }

  group('證明的效期與重用', () {
    test('效期內第二個操作直接帶證明，不再詢問', () async {
      await trips.deleteTrip('t1');
      await passkeys.revoke('c1');

      final second = server.to('DELETE', '/api/account/passkeys/c1');
      expect(second, hasLength(1));
      expect(second.single.headers['X-Step-Up-Proof'], 'proof-1');
      expect(prompter.calls, 1);
    });

    test('過期後重新詢問', () async {
      await trips.deleteTrip('t1');
      now = now.add(const Duration(seconds: 301));
      server.validProof = 'proof-2';
      prompter.answers = [
        const StepUpProof(proof: 'proof-1', expiresIn: 300),
        const StepUpProof(proof: 'proof-2', expiresIn: 300),
      ];

      await passkeys.revoke('c1');

      expect(prompter.calls, 2);
      final sent = server.to('DELETE', '/api/account/passkeys/c1');
      expect(sent, hasLength(2));
      expect(sent.first.headers.containsKey('X-Step-Up-Proof'), isFalse);
      expect(sent.last.headers['X-Step-Up-Proof'], 'proof-2');
    });

    test('效期內但 api 已不認得（例如換 session）→ 清掉舊證明、重新詢問', () async {
      await trips.deleteTrip('t1');
      server.validProof = 'proof-2';
      prompter.answers = [
        const StepUpProof(proof: 'proof-1', expiresIn: 300),
        const StepUpProof(proof: 'proof-2', expiresIn: 300),
      ];

      await passkeys.revoke('c1');

      expect(prompter.calls, 2);
      final sent = server.to('DELETE', '/api/account/passkeys/c1');
      expect(sent.first.headers['X-Step-Up-Proof'], 'proof-1');
      expect(sent.last.headers['X-Step-Up-Proof'], 'proof-2');
    });

    test('store.clear（登出／換帳號）後不再帶舊證明', () async {
      await trips.deleteTrip('t1');
      store.clear();
      server.enforce = false;

      await passkeys.revoke('c1');

      final sent = server.to('DELETE', '/api/account/passkeys/c1');
      expect(sent.single.headers.containsKey('X-Step-Up-Proof'), isFalse);
    });

    test('重試後仍被要求重新驗證 → 丟原錯誤，不再重試第二次', () async {
      server.validProof = 'never-issued';

      await expectLater(
        trips.deleteTrip('t1'),
        throwsA(
          isA<ApiError>().having((e) => e.code, 'code', 'REAUTH_REQUIRED'),
        ),
      );

      expect(server.to('DELETE', '/api/trips/t1'), hasLength(2));
      expect(prompter.calls, 1);
    });

    test('兩個操作同時被要求 → 只問一次', () async {
      prompter.hold = Completer<void>();

      final first = trips.deleteTrip('t1');
      final second = passkeys.revoke('c1');
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      prompter.hold!.complete();
      await Future.wait([first, second]);

      expect(prompter.calls, 1);
    });
  });

  group('其他錯誤不誤判', () {
    test('403 但不是 REAUTH_REQUIRED（例如沒有權限）→ 不詢問、原樣丟出', () async {
      final adapter = _ForbiddenAdapter();
      final repo = TripRepository(
        client: ApiClient(dio: Dio()..httpClientAdapter = adapter),
        stepUp: gate,
      );

      await expectLater(
        repo.deleteTrip('t1'),
        throwsA(isA<ApiError>().having((e) => e.code, 'code', 'PERM_DENIED')),
      );

      expect(prompter.calls, 0);
      expect(adapter.count, 1);
    });

    test('沒有閘門（單元測試／未接線）→ 行為與以前完全相同', () async {
      server.enforce = false;
      await TripRepository(client: client).deleteTrip('t1');
      expect(
        server.to('DELETE', '/api/trips/t1').single.headers.keys,
        isNot(contains('X-Step-Up-Proof')),
      );
    });
  });

  group('StepUpRepository', () {
    late StepUpRepository repo;
    late _ReauthServer reauth;

    setUp(() {
      reauth = _ReauthServer();
      repo = StepUpRepository(
        client: ApiClient(dio: Dio()..httpClientAdapter = reauth),
      );
    });

    test('password：POST /account/reauth/password 帶 password，回證明與效期', () async {
      final proof = await repo.password('s3cret-pw');

      expect(proof.proof, 'issued-proof');
      expect(proof.expiresIn, 300);
      expect(reauth.last.uri.path, '/api/account/reauth/password');
      expect(reauth.last.data, {'password': 's3cret-pw'});
      expect(reauth.last.uri.query, isEmpty);
      expect('${reauth.last.headers}', isNot(contains('s3cret-pw')));
    });

    test('passkey：POST /account/reauth/passkey 帶 credential', () async {
      const credential = {'id': 'c1', 'response': <String, dynamic>{}};
      final proof = await repo.passkey(credential);

      expect(proof.proof, 'issued-proof');
      expect(reauth.last.uri.path, '/api/account/reauth/passkey');
      expect(reauth.last.data, {'credential': credential});
    });

    test('options：POST /account/reauth/options', () async {
      final options = await repo.options();

      expect(options['challenge'], 'ch');
      expect(reauth.last.uri.path, '/api/account/reauth/options');
    });

    test(
      'REAUTH_INVALID 是 403 ApiError：不會觸發 token refresh（不被當成登入過期）',
      () async {
        reauth.fail = (403, 'REAUTH_INVALID');
        final source = _CountingBearer();
        final failing = StepUpRepository(
          client: ApiClient(
            dio: Dio()..httpClientAdapter = reauth,
            bearerSource: source,
          ),
        );

        await expectLater(
          failing.password('x'),
          throwsA(
            isA<ApiError>()
                .having((e) => e.status, 'status', 403)
                .having((e) => e.code, 'code', 'REAUTH_INVALID'),
          ),
        );
        expect(source.refreshCalls, 0);
      },
    );

    test('429 REAUTH_RATE_LIMITED 轉成 ApiError(429)，且不自動重送', () async {
      reauth.fail = (429, 'REAUTH_RATE_LIMITED');

      await expectLater(
        repo.password('x'),
        throwsA(isA<ApiError>().having((e) => e.status, 'status', 429)),
      );
      expect(reauth.count, 1);
    });
  });

  test('密碼不落地：只出現在 reauth/password 的 body，證明重試與 store 都不含', () async {
    // 變更密碼（目前密碼 old-pw）觸發重新驗證；對話框用另一組密碼換證明。
    const typed = 'typed-reauth-pw';
    final reauth = _ReauthServer();
    final stepUpRepo = StepUpRepository(
      client: ApiClient(dio: Dio()..httpClientAdapter = reauth),
    );
    prompter.answers = [await stepUpRepo.password(typed)];
    server.validProof = 'issued-proof';

    await trips.deleteTrip('t1');

    final all = [
      ...server.bodies,
      ...server.requests.map((r) => '${r.headers}'),
    ];
    expect(all.any((s) => s.contains(typed)), isFalse);
    expect(reauth.bodies.where((b) => b.contains(typed)), hasLength(1));
    expect(store.valid, 'issued-proof');
  });
}

class _ForbiddenAdapter implements HttpClientAdapter {
  int count = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    count++;
    return ResponseBody.fromString(
      jsonEncode({
        'error': {'code': 'PERM_DENIED', 'message': '沒有權限'},
      }),
      403,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _ReauthServer implements HttpClientAdapter {
  (int, String)? fail;
  final requests = <RequestOptions>[];
  final bodies = <String>[];
  int get count => requests.length;
  RequestOptions get last => requests.last;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    bodies.add(jsonEncode(options.data));
    final failure = fail;
    final (status, body) = failure == null
        ? (
            200,
            options.uri.path.endsWith('/options')
                ? {'challenge': 'ch', 'allowCredentials': <dynamic>[]}
                : {'proof': 'issued-proof', 'expires_in': 300},
          )
        : (
            failure.$1,
            {
              'error': {'code': failure.$2, 'message': 'x'},
            },
          );
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _CountingBearer implements BearerTokenSource {
  int refreshCalls = 0;

  @override
  Future<String?> accessToken() async => 'AT';

  @override
  Future<bool> refresh() async {
    refreshCalls++;
    return true;
  }
}
