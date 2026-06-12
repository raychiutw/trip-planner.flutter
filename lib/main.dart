/// Tripline app 進入點。
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'api/cache/sembast_cache_store.dart';
import 'api/providers.dart';
import 'app/router.dart';
import 'features/account/settings/theme_mode_controller.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 開永續離線快取 DB（目錄取 app documents），override 預設的記憶體版。
  // 開啟失敗(磁碟/權限/檔案損毀)時退回預設 InMemory,不阻擋 app 啟動。
  SembastCacheStore? cacheStore;
  try {
    final docsDir = await getApplicationDocumentsDirectory();
    cacheStore = SembastCacheStore(await openCacheDatabase(docsDir.path));
  } catch (_) {
    cacheStore = null;
  }
  runApp(
    ProviderScope(
      overrides: [
        if (cacheStore != null)
          cacheStoreProvider.overrideWithValue(cacheStore),
      ],
      child: const TriplineApp(),
    ),
  );
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
      themeMode: ref.watch(themeModeProvider),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('zh', 'TW'), Locale('en'), Locale('ja')],
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
