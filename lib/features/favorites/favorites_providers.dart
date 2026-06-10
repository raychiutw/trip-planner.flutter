/// 收藏 feature providers。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/favorites_repository.dart';
import '../../api/providers.dart';
import '../../models/poi_favorite.dart';

final favoritesRepositoryProvider = Provider<FavoritesRepository>(
  (ref) => FavoritesRepository(client: ref.watch(apiClientProvider)),
);

/// 收藏清單（本畫面專屬 scope；取消收藏後 invalidate refresh）。
final favoritesProvider = FutureProvider<List<PoiFavorite>>(
  (ref) => ref.watch(favoritesRepositoryProvider).fetchFavorites(),
);
