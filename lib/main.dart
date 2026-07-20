/// Tripline app 進入點。
library;

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
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

/// App-level retry signal. Widget/integration tests override this with an empty
/// stream so they never depend on a registered platform plugin.
final appNetworkAvailabilityProvider = Provider<Stream<bool>>(
  (ref) => Connectivity().onConnectivityChanged.map(
    (results) => results.any((result) => result != ConnectivityResult.none),
  ),
);

const _triplineGlassTheme = GlassThemeData(
  light: GlassThemeVariant(
    settings: GlassThemeSettings(
      glassColor: Color(0x9EFFFBF5),
      thickness: 24,
      blur: 22,
      chromaticAberration: 0.006,
      lightIntensity: 0.82,
      ambientStrength: 0.18,
      refractiveIndex: 1.15,
      saturation: 1.10,
    ),
    quality: GlassQuality.standard,
    glowColors: GlassGlowColors(primary: Color(0xFFA97A4A), glowOpacity: 0.30),
  ),
  dark: GlassThemeVariant(
    settings: GlassThemeSettings(
      glassColor: Color(0x61121214),
      thickness: 28,
      blur: 22,
      chromaticAberration: 0.004,
      lightIntensity: 0.72,
      ambientStrength: 0.08,
      refractiveIndex: 1.15,
      saturation: 1.08,
    ),
    quality: GlassQuality.standard,
    glowColors: GlassGlowColors(primary: Color(0xFFCBA06E), glowOpacity: 0.24),
  ),
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LiquidGlassWidgets.initialize();
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
    LiquidGlassWidgets.wrap(
      theme: _triplineGlassTheme,
      adaptiveQuality: true,
      child: ProviderScope(
        overrides: [
          if (cacheStore != null)
            cacheStoreProvider.overrideWithValue(cacheStore),
        ],
        child: const TriplineApp(),
      ),
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
  late final StreamSubscription<bool> _connectivity;

  @override
  void initState() {
    super.initState();
    _connectivity = ref
        .read(appNetworkAvailabilityProvider)
        .listen(
          (isOnline) => ref
              .read(offlineSyncControllerProvider.notifier)
              .handleNetworkAvailability(isOnline),
          onError: (_) {},
        );
    _lifecycle = AppLifecycleListener(onResume: _syncOffline);
    // 冷啟動時也排空上次離線殘留的佇列。
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncOffline());
  }

  void _syncOffline() =>
      ref.read(offlineSyncControllerProvider.notifier).sync();

  @override
  void dispose() {
    unawaited(_connectivity.cancel());
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Tripline',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ref.watch(themeModeProvider),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: kSupportedLocales,
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
