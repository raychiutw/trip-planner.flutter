import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/auth_repository.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/trip_repository.dart';
import 'package:tripline/features/account/settings/profile_edit_screen.dart';
import 'package:tripline/models/user.dart';
import 'package:tripline/theme/app_theme.dart';

class _MockAuthRepo extends Mock implements AuthRepository {}

class _MockTripRepo extends Mock implements TripRepository {}

void main() {
  late _MockAuthRepo authRepo;
  late _MockTripRepo tripRepo;

  setUp(() {
    authRepo = _MockAuthRepo();
    tripRepo = _MockTripRepo();
    when(() => authRepo.currentUser()).thenAnswer(
      (_) async =>
          const UserInfo(id: '1', email: 'me@x.com', displayName: '舊名字'),
    );
  });

  Widget buildApp() {
    final router = GoRouter(
      initialLocation: '/settings/profile',
      routes: [
        GoRoute(
          path: '/settings/profile',
          builder: (_, _) => const ProfileEditScreen(),
        ),
      ],
    );
    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(authRepo),
        tripRepositoryProvider.overrideWithValue(tripRepo),
      ],
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    );
  }

  testWidgets('帶入目前名稱 + 改名儲存 → updateProfile', (tester) async {
    when(
      () => tripRepo.updateProfile(displayName: any(named: 'displayName')),
    ).thenAnswer(
      (_) async =>
          const UserInfo(id: '1', email: 'me@x.com', displayName: '新名字'),
    );

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    expect(find.text('舊名字'), findsOneWidget); // 帶入初值

    await tester.enterText(
      find.byKey(const ValueKey('profile-display-name')),
      '新名字',
    );
    await tester.tap(find.byKey(const ValueKey('profile-save')));
    await tester.pumpAndSettle();

    verify(() => tripRepo.updateProfile(displayName: '新名字')).called(1);
  });
}
