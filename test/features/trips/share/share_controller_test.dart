import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/api_error.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/share_repository.dart';
import 'package:tripline/features/trips/share/share_controller.dart';
import 'package:tripline/models/trip_share.dart';

class _MockShareRepo extends Mock implements ShareRepository {}

const _shares = [TripShare(id: 1, label: 'A', viewCount: 2)];

Future<void> _flush() async {
  for (var i = 0; i < 6; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late _MockShareRepo repo;
  setUp(() {
    repo = _MockShareRepo();
    when(() => repo.fetchShares(any())).thenAnswer((_) async => _shares);
  });

  ProviderContainer makeC() {
    final c = ProviderContainer(
      overrides: [shareRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<ShareController> loaded(ProviderContainer c) async {
    c.listen(shareControllerProvider('t'), (_, _) {});
    final ctrl = c.read(shareControllerProvider('t').notifier);
    await _flush();
    return ctrl;
  }

  test('載入清單', () async {
    final c = makeC();
    await loaded(c);
    final s = c.read(shareControllerProvider('t'));
    expect(s.loading, isFalse);
    expect(s.canManage, isTrue);
    expect(s.shares, hasLength(1));
  });

  test('403 → canManage false', () async {
    when(() => repo.fetchShares(any())).thenAnswer(
      (_) async =>
          throw const ApiError(status: 403, code: 'PERM', message: 'no'),
    );
    final c = makeC();
    await loaded(c);
    expect(c.read(shareControllerProvider('t')).canManage, isFalse);
  });

  test('create → 呼叫 + reload + lastCreated', () async {
    when(() => repo.createShare(any(), label: any(named: 'label'))).thenAnswer(
      (_) async =>
          const ShareLink(id: 7, token: 'tok', url: '/s/tok', label: 'A'),
    );
    final c = makeC();
    final ctrl = await loaded(c);
    await ctrl.create('A');

    verify(() => repo.createShare('t', label: 'A')).called(1);
    verify(() => repo.fetchShares('t')).called(2); // load + reload
    final s = c.read(shareControllerProvider('t'));
    expect(s.lastCreated!.token, 'tok');
    expect(s.creating, isFalse);
  });

  test('create options → 傳公開區塊與匿名設定', () async {
    when(
      () => repo.createShare(
        any(),
        label: any(named: 'label'),
        visibleSections: any(named: 'visibleSections'),
        anonymous: any(named: 'anonymous'),
      ),
    ).thenAnswer(
      (_) async =>
          const ShareLink(id: 8, token: 'tok2', url: '/s/tok2', label: 'B'),
    );
    final c = makeC();
    final ctrl = await loaded(c);
    await ctrl.create(
      'B',
      visibleSections: ['flights', 'pretrip'],
      anonymous: true,
    );

    final captured =
        verify(
              () => repo.createShare(
                't',
                label: 'B',
                visibleSections: captureAny(named: 'visibleSections'),
                anonymous: true,
              ),
            ).captured.single
            as List<String>;
    expect(captured, ['flights', 'pretrip']);
  });

  test('revoke → 呼叫 + reload', () async {
    when(() => repo.revokeShare(any(), any())).thenAnswer((_) async {});
    final c = makeC();
    final ctrl = await loaded(c);
    await ctrl.revoke(1);
    verify(() => repo.revokeShare('t', 1)).called(1);
    verify(() => repo.fetchShares('t')).called(2);
  });

  test('delete → 呼叫 + reload', () async {
    when(() => repo.deleteShare(any(), any())).thenAnswer((_) async {});
    final c = makeC();
    final ctrl = await loaded(c);
    await ctrl.delete(1);

    verify(() => repo.deleteShare('t', 1)).called(1);
    verify(() => repo.fetchShares('t')).called(2);
  });

  test('update label → 呼叫 + reload', () async {
    when(
      () => repo.updateShare(any(), any(), label: any(named: 'label')),
    ).thenAnswer((_) async {});
    final c = makeC();
    final ctrl = await loaded(c);
    await ctrl.update(1, label: '  旅伴  ');

    verify(() => repo.updateShare('t', 1, label: '旅伴')).called(1);
    verify(() => repo.fetchShares('t')).called(2);
    expect(c.read(shareControllerProvider('t')).updatingId, isNull);
  });

  test('rotate → 呼叫 + reload + lastCreated 顯示新連結', () async {
    when(() => repo.rotateShare(any(), any())).thenAnswer(
      (_) async => const RotatedShareLink(token: 'newtok', url: '/s/newtok'),
    );
    final c = makeC();
    final ctrl = await loaded(c);
    await ctrl.rotate(1);

    verify(() => repo.rotateShare('t', 1)).called(1);
    verify(() => repo.fetchShares('t')).called(2);
    final s = c.read(shareControllerProvider('t'));
    expect(s.lastCreated!.token, 'newtok');
    expect(s.lastCreated!.url, '/s/newtok');
  });
}
