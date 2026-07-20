/// 收藏 feature providers。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/favorites_repository.dart';
import '../../api/providers.dart';
import '../../models/poi_favorite.dart';

final favoritesRepositoryProvider = Provider<FavoritesRepository>(
  (ref) => FavoritesRepository(client: ref.watch(apiClientProvider)),
);

/// Local builds default off; signed release builds explicitly enable the
/// deployed owner-scoped soft-delete/restore API.
final favoriteRestoreEnabledProvider = Provider<bool>(
  (ref) => const bool.fromEnvironment('FAVORITE_RESTORE_ENABLED'),
);

/// 收藏清單（SWR:stale→fresh;取消收藏後 invalidate refresh）。
final favoritesProvider = StreamProvider<List<PoiFavorite>>(
  (ref) => ref.watch(favoritesRepositoryProvider).watchFavorites(),
);
