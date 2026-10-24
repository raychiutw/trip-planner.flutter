import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tripline/api/api_error.dart';
import 'package:tripline/app/provider_retry.dart';
import 'package:tripline/features/trips/trips_list_screen.dart';

void main() {
  test('main.dart 的根 ProviderScope 使用 appProviderRetry', () {
    expect(
      File('lib/main.dart').readAsStringSync(),
      contains('retry: appProviderRetry'),
    );
  });

  group('appProviderRetry', () {
    test('暫時性錯誤最多重試兩次，間隔短', () {
      final error = Exception('offline');
      expect(appProviderRetry(0, error), const Duration(milliseconds: 500));
      expect(appProviderRetry(1, error), const Duration(seconds: 1));
      expect(appProviderRetry(2, error), isNull);
    });

    test('4xx 是確定的答案，不重試', () {
      const error = ApiError(status: 403, code: 'FORBIDDEN', message: 'no');
      expect(appProviderRetry(0, error), isNull);
    });

    test('5xx 與網路錯誤可重試', () {
      const error = ApiError(status: 503, code: 'UNAVAILABLE', message: 'x');
      expect(appProviderRetry(0, error), isNotNull);
    });
  });

  testWidgets('載入失敗後 5 秒內出現錯誤與重試（以產品實際重試政策）', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        retry: appProviderRetry,
        overrides: [
          myTripsProvider.overrideWith(
            (ref) => Stream.error(Exception('network down')),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const TripsListScreen(),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(find.text('重試'), findsOneWidget);
  });
}
