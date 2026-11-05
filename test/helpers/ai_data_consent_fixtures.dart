import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/ai_data_consent_repository.dart';
import 'package:tripline/models/ai_data_consent.dart';

class MockAiDataConsentRepo extends Mock implements AiDataConsentRepository {}

/// 對照 api#48 的 `ai-data-v1` 形狀；文字是測試用，不代表正式文案。
AiDataConsent aiConsentFixture(
  AiDataConsentStatus status, {
  bool enforced = true,
}) => AiDataConsent(
  status: status,
  currentVersion: 'ai-data-v1',
  acceptedVersion: status == AiDataConsentStatus.valid ? 'ai-data-v1' : null,
  acceptedAt: status == AiDataConsentStatus.valid
      ? '2026-10-01T02:03:04.000Z'
      : null,
  enforced: enforced,
  text: const AiDataConsentText(
    version: 'ai-data-v1',
    title: '使用 AI 助理前，請先了解',
    intro: '以下說明由 server 提供',
    sections: [
      AiDataConsentSection(heading: '會交給 AI 的資料', items: ['行程內容', '你的訊息']),
    ],
    withdrawal: [
      '撤回後，新的 AI 要求會立即被拒絕。',
      '排隊中、尚未開始的要求會被終結。',
      '已經開始的工作不保證能停止。',
      '已經交給 AI 處理的資料無法收回。',
    ],
  ),
);

/// 預設「讀不到狀態」＝不強制，既有畫面測試不受影響。
MockAiDataConsentRepo unenforcedConsentRepo() {
  final repo = MockAiDataConsentRepo();
  when(repo.fetch).thenAnswer((_) async => null);
  return repo;
}

const ownerGate = AiConsentRequiredException(
  party: AiConsentParty.owner,
  requiredVersion: 'ai-data-v1',
);
const submitterGate = AiConsentRequiredException(
  party: AiConsentParty.submitter,
  requiredVersion: 'ai-data-v1',
  status: AiDataConsentStatus.none,
);
