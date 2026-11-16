// 冷啟動讀受保護憑證（生物辨識登入）：通過即 refresh；憑證不能用就清除（ADR-0019、#647）。
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/api_client.dart';
import 'package:tripline/api/api_error.dart';
import 'package:tripline/api/dpop/proof_key_store.dart';
import 'package:tripline/api/oauth/oauth_config.dart';
import 'package:tripline/api/oauth/oauth_providers.dart';
import 'package:tripline/api/oauth/oauth_repository.dart';
import 'package:tripline/api/oauth/oauth_token_store.dart';
import 'package:tripline/api/oauth/stored_bearer_token_source.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/models/oauth_tokens.dart';

class _MockOAuthRepo extends Mock implements OAuthRepository {}

String _idToken() {
  String enc(Map<String, Object?> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  final exp =
      DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
      1000;
  return '${enc({'alg': 'none'})}.${enc({'sub': 'u1', 'email': 'ray@example.com', 'aud': OAuthConfig.clientId, 'exp': exp})}.sig';
}

OAuthTokens _tokens({String refresh = 'RT'}) => OAuthTokens(
  accessToken: 'AT',
  refreshToken: refresh,
  idToken: _idToken(),
  expiresAt: DateTime.now().add(const Duration(minutes: 15)),
);

/// 生物特徵變更：受保護讀取時系統回報項目失效，儲存層自行清掉憑證並回 null。
class _InvalidatedOnReadStore extends InMemoryOAuthTokenStore {
  bool invalidateNextRead = false;

  @override
  Future<OAuthTokens?> read() async {
    if (invalidateNextRead) {
      invalidateNextRead = false;
      await clear();
      return null;
    }
    return super.read();
  }
}

void main() {
  late _InvalidatedOnReadStore store;
  late _MockOAuthRepo repo;
  late InMemoryProofKeyStore keys;

  var refreshes = 0;

  void refreshAnswers(Future<OAuthTokens> Function() answer) =>
      when(
        () => repo.refresh(
          refreshToken: any(named: 'refreshToken'),
          clientId: any(named: 'clientId'),
          proofKey: any(named: 'proofKey'),
        ),
      ).thenAnswer((_) {
        refreshes++;
        return answer();
      });

  ProviderContainer make() {
    final c = ProviderContainer(
      overrides: [
        oauthTokenStoreProvider.overrideWithValue(store),
        oauthRepositoryProvider.overrideWithValue(repo),
        proofKeyStoreProvider.overrideWithValue(keys),
        apiClientProvider.overrideWithValue(ApiClient(dio: Dio())),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(() async {
    store = _InvalidatedOnReadStore();
    repo = _MockOAuthRepo();
    keys = InMemoryProofKeyStore();
    refreshes = 0;
    await store.write(_tokens());
    await store.setProtection(TokenProtection.biometric);
    refreshAnswers(() async => _tokens(refresh: 'RT2'));
  });

  group('冷啟動讀到受保護憑證', () {
    test('通過即 refresh 一次並進入已登入', () async {
      final c = make();

      final user = await c.read(authStateProvider.future);

      expect(user?.email, 'ray@example.com');
      expect(refreshes, 1);
      expect((await store.read())?.refreshToken, 'RT2');
    });

    test('refresh 被拒：清除憑證，回到未登入（不是「還沒解開」）', () async {
      refreshAnswers(
        () async => throw const ApiError(
          status: 400,
          code: 'invalid_grant',
          message: 'x',
        ),
      );
      final c = make();

      expect(await c.read(authStateProvider.future), isNull);
      expect(await store.read(), isNull);
      expect(c.read(authLockedProvider), isFalse);
    });

    test('refresh 遇到網路錯誤：憑證保留，照常進入已登入（離線也能用）', () async {
      refreshAnswers(
        () async => throw DioException(requestOptions: RequestOptions()),
      );
      final c = make();

      expect(
        (await c.read(authStateProvider.future))?.email,
        'ray@example.com',
      );
      expect((await store.read())?.refreshToken, 'RT');
    });

    test('refresh 拋出非預期錯誤：不當成失效，憑證保留、照常登入', () async {
      refreshAnswers(() async => throw StateError('unexpected'));
      final c = make();

      expect(
        (await c.read(authStateProvider.future))?.email,
        'ray@example.com',
      );
      expect((await store.read())?.refreshToken, 'RT');
    });

    test('一般保護（passcode）憑證：冷啟動不額外 refresh', () async {
      await store.setProtection(TokenProtection.passcode);
      final c = make();

      await c.read(authStateProvider.future);

      expect(refreshes, 0);
    });
  });

  group('冷啟動取消後按「登入」解鎖（unlock）', () {
    Future<ProviderContainer> cancelledColdStart() async {
      await store.lock();
      store.unlockSucceeds = false;
      final c = make();
      expect(await c.read(authStateProvider.future), isNull);
      expect(c.read(authLockedProvider), isTrue);
      store.unlockSucceeds = true;
      return c;
    }

    test('通過：refresh 並登入，回報憑證可用', () async {
      final c = await cancelledColdStart();

      final invalid = await c.read(authStateProvider.notifier).unlock();

      expect(invalid, isNull);
      expect(c.read(authStateProvider).value?.email, 'ray@example.com');
      expect(refreshes, 1);
    });

    test('refresh 被拒：清除憑證、未登入，回報 rejected（呼叫端改開 web 登入頁）', () async {
      final c = await cancelledColdStart();
      refreshAnswers(
        () async => throw const ApiError(
          status: 401,
          code: 'invalid_grant',
          message: 'x',
        ),
      );

      final invalid = await c.read(authStateProvider.notifier).unlock();

      expect(invalid, InvalidReason.rejected);
      expect(c.read(authStateProvider).value, isNull);
      expect(c.read(authStateProvider).hasError, isFalse);
      expect(await store.read(), isNull);
    });

    test('生物特徵變更使憑證失效：回報 keyLost、未登入、金鑰一併刪除', () async {
      final c = await cancelledColdStart();
      await keys.create();
      store.invalidateNextRead = true;

      final invalid = await c.read(authStateProvider.notifier).unlock();

      expect(invalid, InvalidReason.keyLost);
      expect(c.read(authStateProvider).value, isNull);
      expect(await keys.load(), isNull);
    });

    test('再次取消：仍是「還沒解開」，不回報失效、憑證保留', () async {
      final c = await cancelledColdStart();
      store.unlockSucceeds = false;
      await store.lock();

      final invalid = await c.read(authStateProvider.notifier).unlock();

      expect(invalid, isNull);
      expect(c.read(authLockedProvider), isTrue);
      store.unlockSucceeds = true;
      expect(await store.read(), isNotNull);
    });
  });
}
