/// 收藏 feature providers。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/favorites_repository.dart';
import '../../api/providers.dart';
import '../../models/poi_favorite.dart';

final favoritesRepositoryProvider = Provider<FavoritesRepository>(
  (ref) => FavoritesRepository(client: ref.watch(apiClientProvider)),
);

/// Remains off until the owner-scoped soft-delete/restore API is deployed.
final favoriteRestoreEnabledProvider = Provider<bool>(
  (ref) => const bool.fromEnvironment('FAVORITE_RESTORE_ENABLED'),
);

/// 收藏清單（SWR:stale→fresh;取消收藏後 invalidate refresh）。
final favoritesProvider = StreamProvider<List<PoiFavorite>>(
  (ref) => ref.watch(favoritesRepositoryProvider).watchFavorites(),
);
