import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:tripline/api/ai_data_consent_repository.dart';
import 'package:tripline/api/api_client.dart';
import 'package:tripline/api/api_error.dart';
import 'package:tripline/api/requests_repository.dart';
import 'package:tripline/api/trip_repository.dart';
import 'package:tripline/models/note_section.dart';
import 'package:tripline/models/ai_data_consent.dart';

Map<String, dynamic> _state(String status, {bool enforced = true}) => {
  'status': status,
  'currentVersion': 'ai-data-v1',
  'acceptedVersion': status == 'valid' ? 'ai-data-v1' : null,
  'acceptedAt': status == 'valid' ? '2026-10-01T02:03:04.000Z' : null,
  'text': {
    'version': 'ai-data-v1',
    'title': '標題',
    'intro': '簡介',
    'sections': <Object>[],
    'withdrawal': <Object>[],
  },
  'enforced': enforced,
};

Map<String, dynamic> _gateBody(String code, {String? status}) => {
  'error': {
    'code': code,
    'message': '訊息',
    'requiredVersion': 'ai-data-v1',
    'status': ?status,
  },
};

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late AiDataConsentRepository repo;

  setUp(() {
    dio = Dio();
    adapter = DioAdapter(dio: dio);
    repo = AiDataConsentRepository(client: ApiClient(dio: dio));
  });

  group('三個動作', () {
    test('fetch：GET /account/ai-data-consent', () async {
      adapter.onGet(
        '/account/ai-data-consent',
        (s) => s.reply(200, _state('stale')),
      );
      final consent = await repo.fetch();
      expect(consent?.status, AiDataConsentStatus.stale);
    });

    test('fetch：回應不是同意狀態 → null（讀不到＝不強制）', () async {
      adapter.onGet(
        '/account/ai-data-consent',
        (s) => s.reply(200, {'hello': 'world'}),
      );
      expect(await repo.fetch(), isNull);
    });

    test('accept：POST 帶使用者看到的版本，回新狀態', () async {
      adapter.onPost(
        '/account/ai-data-consent',
        (s) => s.reply(200, _state('valid')),
        data: {'version': 'ai-data-v1'},
      );
      final consent = await repo.accept('ai-data-v1');
      expect(consent.status, AiDataConsentStatus.valid);
    });

    test('accept：回應不是同意狀態 → 丟錯，不假裝已同意', () async {
      adapter.onPost(
        '/account/ai-data-consent',
        (s) => s.reply(200, {'ok': true}),
        data: {'version': 'ai-data-v1'},
      );
      expect(() => repo.accept('ai-data-v1'), throwsA(isA<FormatException>()));
    });

    test('accept：409 版本已更新 → 保留 ApiError 讓呼叫端重讀', () async {
      adapter.onPost(
        '/account/ai-data-consent',
        (s) => s.reply(409, {
          'error': {
            'code': 'AI_CONSENT_VERSION_MISMATCH',
            'message': 'm',
            'currentVersion': 'ai-data-v2',
          },
        }),
        data: {'version': 'ai-data-v1'},
      );
      expect(
        () => repo.accept('ai-data-v1'),
        throwsA(
          isA<ApiError>().having(
            (e) => e.code,
            'code',
            'AI_CONSENT_VERSION_MISMATCH',
          ),
        ),
      );
    });

    test('withdraw：DELETE，回 withdrawn 狀態', () async {
      adapter.onDelete(
        '/account/ai-data-consent',
        (s) => s.reply(200, _state('withdrawn')),
      );
      final consent = await repo.withdraw();
      expect(consent.status, AiDataConsentStatus.withdrawn);
    });
  });

  group('403 閘門錯誤碼 → 型別化例外', () {
    test('AI_CONSENT_REQUIRED：送出者，帶所需版本與送出者狀態', () {
      final gate = aiConsentGateFrom(
        ApiError.fromResponse(
          403,
          _gateBody('AI_CONSENT_REQUIRED', status: 'stale'),
        ),
      );
      expect(gate?.party, AiConsentParty.submitter);
      expect(gate?.requiredVersion, 'ai-data-v1');
      expect(gate?.status, AiDataConsentStatus.stale);
    });

    test('AI_CONSENT_OWNER_REQUIRED：行程 owner，不帶狀態', () {
      final gate = aiConsentGateFrom(
        ApiError.fromResponse(403, _gateBody('AI_CONSENT_OWNER_REQUIRED')),
      );
      expect(gate?.party, AiConsentParty.owner);
      expect(gate?.requiredVersion, 'ai-data-v1');
      expect(gate?.status, isNull);
    });

    test('其他 403（PERM_DENIED）或非 ApiError 都不是閘門', () {
      expect(
        aiConsentGateFrom(
          ApiError.fromResponse(403, {
            'error': {'code': 'PERM_DENIED', 'message': 'm'},
          }),
        ),
        isNull,
      );
      expect(aiConsentGateFrom(Exception('x')), isNull);
    });

    test('translateAiConsentGate：把閘門 ApiError 換成型別化例外，其餘原樣丟出', () async {
      await expectLater(
        translateAiConsentGate<void>(
          () async => throw ApiError.fromResponse(
            403,
            _gateBody('AI_CONSENT_OWNER_REQUIRED'),
          ),
        ),
        throwsA(isA<AiConsentRequiredException>()),
      );
      await expectLater(
        translateAiConsentGate<void>(
          () async => throw ApiError.fromResponse(500, null),
        ),
        throwsA(isA<ApiError>()),
      );
      expect(await translateAiConsentGate(() async => 7), 7);
    });
  });

  group('三個受管制入口的 mutation 邊界把 403 換成型別化例外', () {
    final ownerBody = _gateBody('AI_CONSENT_OWNER_REQUIRED');
    final submitterBody = _gateBody('AI_CONSENT_REQUIRED', status: 'none');

    test('POST /requests（聊天）', () async {
      adapter.onPost(
        '/requests',
        (s) => s.reply(403, submitterBody),
        data: {'tripId': 't1', 'message': 'hi'},
      );
      await expectLater(
        RequestsRepository(
          client: ApiClient(dio: dio),
        ).sendRequest(tripId: 't1', message: 'hi'),
        throwsA(
          isA<AiConsentRequiredException>().having(
            (e) => e.party,
            'party',
            AiConsentParty.submitter,
          ),
        ),
      );
    });

    test('POST /trips/:id/health-check（健檢）', () async {
      adapter.onPost('/trips/t1/health-check', (s) => s.reply(403, ownerBody));
      await expectLater(
        TripRepository(client: ApiClient(dio: dio)).startHealthCheck('t1'),
        throwsA(
          isA<AiConsentRequiredException>().having(
            (e) => e.party,
            'party',
            AiConsentParty.owner,
          ),
        ),
      );
    });

    test('POST /trips/:id/notes/:type/generate（筆記）', () async {
      adapter.onPost(
        '/trips/t1/notes/tips/generate',
        (s) => s.reply(403, submitterBody),
      );
      await expectLater(
        TripRepository(
          client: ApiClient(dio: dio),
        ).generateNotes(NoteGenerationType.tips, tripId: 't1'),
        throwsA(isA<AiConsentRequiredException>()),
      );
    });

    test('一般 403（PERM_DENIED）仍是 ApiError', () async {
      adapter.onPost(
        '/trips/t1/health-check',
        (s) => s.reply(403, {
          'error': {'code': 'PERM_DENIED', 'message': 'm'},
        }),
      );
      await expectLater(
        TripRepository(client: ApiClient(dio: dio)).startHealthCheck('t1'),
        throwsA(isA<ApiError>()),
      );
    });
  });
}
