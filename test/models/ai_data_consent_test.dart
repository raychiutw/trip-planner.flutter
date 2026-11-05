import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/models/ai_data_consent.dart';

/// 對照 api#48 的 wire 格式（GET /account/ai-data-consent）。
Map<String, dynamic> _json({
  String status = 'none',
  Object? acceptedVersion,
  Object? acceptedAt,
  Object? enforced = false,
}) => {
  'status': status,
  'currentVersion': 'ai-data-v1',
  'acceptedVersion': acceptedVersion,
  'acceptedAt': acceptedAt,
  'text': {
    'version': 'ai-data-v1',
    'title': '使用 AI 助理前，請先了解',
    'intro': '簡介',
    'sections': [
      {
        'heading': '會交給 AI 的資料',
        'items': ['行程內容', '你的訊息'],
      },
    ],
    'withdrawal': ['撤回後新的 AI 請求不再受理'],
  },
  'enforced': enforced,
};

void main() {
  group('AiDataConsent.tryParse', () {
    test('四種狀態都解析；未知狀態視為不是同意狀態（回 null）', () {
      for (final (raw, expected) in [
        ('none', AiDataConsentStatus.none),
        ('valid', AiDataConsentStatus.valid),
        ('stale', AiDataConsentStatus.stale),
        ('withdrawn', AiDataConsentStatus.withdrawn),
      ]) {
        expect(AiDataConsent.tryParse(_json(status: raw))?.status, expected);
      }
      expect(AiDataConsent.tryParse(_json(status: 'weird')), isNull);
      expect(AiDataConsent.tryParse(null), isNull);
      expect(AiDataConsent.tryParse(<String, dynamic>{}), isNull);
    });

    test('文字與版本照 server 給的；章節缺漏回空清單', () {
      final consent = AiDataConsent.tryParse(_json())!;
      expect(consent.currentVersion, 'ai-data-v1');
      expect(consent.text.title, '使用 AI 助理前，請先了解');
      expect(consent.text.sections.single.heading, '會交給 AI 的資料');
      expect(consent.text.sections.single.items, ['行程內容', '你的訊息']);
      expect(consent.text.withdrawal, ['撤回後新的 AI 請求不再受理']);
    });

    test('valid 帶已接受版本與時間；enforced 缺漏當 false', () {
      final consent = AiDataConsent.tryParse(
        _json(
          status: 'valid',
          acceptedVersion: 'ai-data-v1',
          acceptedAt: '2026-10-01T02:03:04.000Z',
          enforced: true,
        ),
      )!;
      expect(consent.acceptedVersion, 'ai-data-v1');
      expect(consent.acceptedAt, '2026-10-01T02:03:04.000Z');
      expect(consent.enforced, isTrue);
      final noFlag = _json()..remove('enforced');
      expect(AiDataConsent.tryParse(noFlag)!.enforced, isFalse);
    });

    test('needsConsent：旗標關一律不擋；旗標開時只有 valid 放行', () {
      for (final status in ['none', 'stale', 'withdrawn']) {
        expect(
          AiDataConsent.tryParse(_json(status: status))!.needsConsent,
          isFalse,
          reason: '旗標關（enforced=false）時 $status 也不能擋',
        );
        expect(
          AiDataConsent.tryParse(
            _json(status: status, enforced: true),
          )!.needsConsent,
          isTrue,
        );
      }
      expect(
        AiDataConsent.tryParse(
          _json(status: 'valid', enforced: true),
        )!.needsConsent,
        isFalse,
      );
    });
  });
}
