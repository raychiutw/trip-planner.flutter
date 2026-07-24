library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/providers.dart';
import '../../models/trip.dart';

const _currentTripCacheKey = 'ui:last-map-trip';

/// Chat、Trips 與 Map 共用的目前行程狀態。
class CurrentTripController extends AsyncNotifier<String?> {
  String? _selectedDuringLoad;
  Future<void> _cacheWrites = Future.value();
  String? _authUserId;
  bool _hasAuthIdentity = false;
  int _authGeneration = 0;

  @override
  Future<String?> build() async {
    final authUserId = ref.watch(
      authStateProvider.select((auth) => auth.value?.id),
    );
    if (_hasAuthIdentity && _authUserId != authUserId) {
      _selectedDuringLoad = null;
      _authGeneration++;
    }
    _authUserId = authUserId;
    _hasAuthIdentity = true;
    try {
      final cached = await ref
          .read(cacheStoreProvider)
          .readResponse(_currentTripCacheKey);
      final value = cached?.data;
      return _selectedDuringLoad ??
          (value is String && value.isNotEmpty ? value : null);
    } catch (_) {
      return _selectedDuringLoad;
    }
  }

  /// 切換目前行程並保存下次啟動要恢復的選擇。
  Future<void> select(String tripId) async {
    if (tripId.isEmpty) return;
    _selectedDuringLoad = tripId;
    state = AsyncData(tripId);
    final store = ref.read(cacheStoreProvider);
    final authGeneration = _authGeneration;
    _cacheWrites = _cacheWrites.then((_) async {
      if (authGeneration != _authGeneration) return;
      try {
        await store.writeResponse(_currentTripCacheKey, tripId);
      } catch (_) {
        // 目前行程是 UI 狀態；偏好儲存失敗不可阻擋當次切換。
      }
    });
    await _cacheWrites;
  }
}

/// 應用程式目前顯示的行程。
final currentTripIdProvider =
    AsyncNotifierProvider<CurrentTripController, String?>(
      CurrentTripController.new,
    );

/// 以共享選擇解析目前行程；選擇失效時回到清單第一筆。
TripSummary? resolveCurrentTrip(
  List<TripSummary> trips,
  String? selectedTripId,
) {
  if (trips.isEmpty) return null;
  for (final trip in trips) {
    if (trip.tripId == selectedTripId) return trip;
  }
  return trips.first;
}
