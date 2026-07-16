/// Tripline app 進入點。
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'api/cache/cache_migration.dart';
import 'api/cache/drift_cache_store.dart';
import 'api/providers.dart';
import 'app/router.dart';
import 'features/account/settings/theme_mode_controller.dart';
import 'features/offline/offline_sync.dart';
import 'theme/app_theme.dart';

/// 現階段所有產品文案均為繁體中文；新增語系前須先完成整套字串在地化。
const kSupportedLocales = [Locale('zh', 'TW')];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 開永續離線快取 DB（目錄取 app documents），override 預設的記憶體版。
  // 開啟失敗(磁碟/權限/檔案損毀)時退回預設 InMemory,不阻擋 app 啟動。
  DriftCacheStore? cacheStore;
  try {
    final docsDir = await getApplicationDocumentsDirectory();
    cacheStore = DriftCacheStore(openCacheDatabase(docsDir.path));
    // 舊版是 sembast。既有使用者裝置上可能還躺著沒同步的離線編輯 —— 不搬就是
    // 永久遺失，所以先搬再讓 app 起來。失敗不擋啟動(舊檔留著,下次再試)。
    await migrateSembastCacheToDrift(
      directoryPath: docsDir.path,
      target: cacheStore,
    );
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
/// 啟動與每次回前景時嘗試把離線佇列同步回後端(線上才會真正排空)。
class TriplineApp extends ConsumerStatefulWidget {
  const TriplineApp({super.key});

  @override
  ConsumerState<TriplineApp> createState() => _TriplineAppState();
}

class _TriplineAppState extends ConsumerState<TriplineApp> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _syncOffline);
    // 冷啟動時也排空上次離線殘留的佇列。
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncOffline());
  }

  void _syncOffline() =>
      ref.read(offlineSyncControllerProvider.notifier).sync();

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Tripline',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ref.watch(themeModeProvider),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: kSupportedLocales,
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
