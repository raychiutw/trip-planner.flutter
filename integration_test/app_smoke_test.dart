/// device smoke:app 啟動(未登入、完全不打 prod API)→ 停在登入頁。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/auth_repository.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/trip_repository.dart';
import 'package:tripline/features/auth/login_screen.dart';
import 'package:tripline/main.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockTripRepository extends Mock implements TripRepository {}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app 啟動 → 登入頁(未登入,不打 prod)', (tester) async {
    final mockAuth = _MockAuthRepository();
    final mockTrips = _MockTripRepository();
    when(() => mockAuth.currentUser()).thenAnswer((_) async => null);
    when(mockTrips.fetchMyTrips).thenAnswer((_) async => const []);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(mockAuth),
        tripRepositoryProvider.overrideWithValue(mockTrips),
      ],
      child: const TriplineApp(),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
