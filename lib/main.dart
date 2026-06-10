/// Tripline app 進入點。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/router.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const ProviderScope(child: TriplineApp()));
}

/// 根 widget：套用 Tripline theme 與 go_router 路由。
class TriplineApp extends ConsumerWidget {
  const TriplineApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Tripline',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
