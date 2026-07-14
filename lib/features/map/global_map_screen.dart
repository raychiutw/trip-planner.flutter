/// 全域地圖:把所有收藏 POI(GET /poi-favorites,跨行程)畫在地圖 adapter 上,
/// 依 poi_type 上色;點 marker → 顯示名稱/評分/所屬行程。
/// (web 的 /map 實為 dead code 導回單行程地圖;此處實作真正的跨行程地圖。)
library;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_loading_skeleton.dart';
import '../../models/poi_favorite.dart';
import '../../models/poi_type.dart';
import '../../theme/app_theme.dart';
import '../../theme/poi_tone.dart';
import '../../theme/tokens.dart';
import '../favorites/favorites_providers.dart';
import 'map_adapter.dart';
import 'map_layer_menu.dart';
import 'map_location.dart';

bool _hasCoords(PoiFavorite f) =>
    f.poiLat != null && f.poiLng != null && f.poiLat != 0 && f.poiLng != 0;

class GlobalMapScreen extends ConsumerStatefulWidget {
  const GlobalMapScreen({super.key, this.tileProvider, this.locationService});

  /// 測試注入(避免抓真 tile);prod 為 null → 走網路 OSM。
  final TripMapTileProvider? tileProvider;

  /// 測試注入點：production 用 geolocator，widget test 傳入 fake。
  final TripMapLocationService? locationService;

  @override
  ConsumerState<GlobalMapScreen> createState() => _GlobalMapScreenState();
}

class _GlobalMapScreenState extends ConsumerState<GlobalMapScreen> {
  final FlutterTripMapController _mapController = FlutterTripMapController();
  TripMapTilePreset _tilePreset = kTripMapTilePresets.first;
  TripMapPoint? _userLocation;
  bool _locating = false;
  int? _selectedId;
  String? _locationError;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final favsAsync = ref.watch(favoritesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('地圖')),
      body: favsAsync.when(
        loading: () =>
            const AppMapLoadingSkeleton(key: ValueKey('map-loading-skeleton')),
        error: (e, _) => const _Hint(title: '載入失敗', body: '無法取得收藏地點,請稍後再試。'),
        data: (favs) {
          final pins = favs.where(_hasCoords).toList();
          if (pins.isEmpty) {
            return const _Hint(
              title: '還沒有地點可顯示',
              body: '到「收藏」或「探索」收藏地點後,就會出現在這張地圖上。',
            );
          }
          PoiFavorite? selected;
          for (final f in pins) {
            if (f.id == _selectedId) {
              selected = f;
              break;
            }
          }
          return Stack(
            children: [
              _buildMap(context, pins),
              if (_locationError case final message?)
                Positioned(
                  left: TpSpacing.s4,
                  right: TpSpacing.s4 + TpSpacing.tapMin + TpSpacing.s3,
                  top: TpSpacing.s4,
                  child: _MapErrorBanner(
                    message: message,
                    onRetry: _locateMe,
                    onDismiss: () => setState(() => _locationError = null),
                  ),
                ),
              Positioned(
                top: TpSpacing.s4,
                right: TpSpacing.s4,
                child: TripMapLayerMenu(
                  keyPrefix: 'global-map',
                  selectedPreset: _tilePreset,
                  onSelected: (preset) => setState(() => _tilePreset = preset),
                ),
              ),
              Positioned(
                top: TpSpacing.s4 + TpSpacing.tapMin + TpSpacing.s2,
                right: TpSpacing.s4,
                child: TripMapLocateButton(
                  key: const ValueKey('global-map-locate-button'),
                  locating: _locating,
                  onPressed: _locateMe,
                ),
              ),
              if (selected != null)
                Positioned(
                  left: TpSpacing.s4,
                  right: TpSpacing.s4,
                  bottom: TpSpacing.s4,
                  child: _SelectedCard(
                    favorite: selected,
                    onClose: () => setState(() => _selectedId = null),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMap(BuildContext context, List<PoiFavorite> pins) {
    final tones = Theme.of(context).extension<TpTones>()!;
    final points = [for (final f in pins) TripMapPoint(f.poiLat!, f.poiLng!)];
    return FlutterMapCanvas(
      controller: _mapController,
      tilePreset: _tilePreset,
      initialFitPoints: points,
      initialPadding: const EdgeInsets.all(TpSpacing.s10),
      initialMaxZoom: 14,
      tileProvider: widget.tileProvider,
      onTap: (_) => setState(() => _selectedId = null),
      markers: [
        for (final f in pins)
          TripMapMarker(
            point: TripMapPoint(f.poiLat!, f.poiLng!),
            width: TpSpacing.tapMin,
            height: TpSpacing.tapMin,
            child: Semantics(
              button: true,
              selected: _selectedId == f.id,
              label: _markerSemanticsLabel(f),
              child: GestureDetector(
                key: ValueKey('map-fav-${f.id}'),
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _selectedId = f.id),
                child: Center(
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: resolvePoiTone(tones, f.poiType).base,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _selectedId == f.id
                            ? Theme.of(context).colorScheme.onSurface
                            : Colors.white,
                        width: 3,
                      ),
                    ),
                    child: Icon(
                      _markerIcon(f.poiType),
                      size: 13,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (_userLocation != null)
          buildTripMapUserLocationMarker(
            point: _userLocation!,
            key: const ValueKey('global-map-user-location'),
          ),
      ],
    );
  }

  Future<void> _locateMe() async {
    if (_locating) return;
    setState(() {
      _locating = true;
      _locationError = null;
    });
    try {
      final service =
          widget.locationService ?? const GeolocatorTripMapLocationService();
      final point = await service.currentLocation();
      if (!mounted) return;
      setState(() {
        _userLocation = point;
        _selectedId = null;
        _locationError = null;
      });
      _mapController.move(point, 15);
    } on TripMapLocationException catch (error) {
      if (!mounted) return;
      _showLocationError(error.message);
    } on Exception {
      if (!mounted) return;
      _showLocationError('無法取得目前位置');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _showLocationError(String message) {
    setState(() => _locationError = message);
  }
}

String _markerSemanticsLabel(PoiFavorite favorite) {
  final category = poiCategoryLabel(favorite.poiType);
  return category == null
      ? '地點：${favorite.displayName}'
      : '地點：${favorite.displayName}，$category';
}

IconData _markerIcon(String? type) {
  return switch (mapGooglePrimaryTypeToPoiType(type)) {
    'hotel' => Icons.bed_outlined,
    'restaurant' => Icons.restaurant_outlined,
    'shopping' => Icons.shopping_bag_outlined,
    'parking' => Icons.local_parking,
    'transport' => Icons.train_outlined,
    'activity' => Icons.local_activity_outlined,
    'other' => Icons.place_outlined,
    _ => Icons.attractions_outlined,
  };
}

class _MapErrorBanner extends StatelessWidget {
  const _MapErrorBanner({
    required this.message,
    required this.onRetry,
    required this.onDismiss,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      key: const ValueKey('global-map-location-error'),
      color: colors.errorContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(TpRadius.md),
        side: BorderSide(color: colors.error.withValues(alpha: 0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.only(left: TpSpacing.s3),
        child: Row(
          children: [
            Icon(Icons.location_off_outlined, color: colors.onErrorContainer),
            const SizedBox(width: TpSpacing.s2),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: colors.onErrorContainer),
              ),
            ),
            TextButton(onPressed: onRetry, child: const Text('重試')),
            IconButton(
              tooltip: '關閉錯誤訊息',
              onPressed: onDismiss,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    );
  }
}

/// 選中地點卡:名稱 + 評分 + 類型 + 所屬行程。
class _SelectedCard extends StatelessWidget {
  const _SelectedCard({required this.favorite, required this.onClose});

  final PoiFavorite favorite;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trips = favorite.usages.map((u) => u.tripName).toSet().toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(TpSpacing.s3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    favorite.poiName ?? '未命名地點',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(CupertinoIcons.xmark),
                  onPressed: onClose,
                ),
              ],
            ),
            if (favorite.poiRating != null)
              Padding(
                padding: const EdgeInsets.only(top: TpSpacing.s1),
                child: Text(
                  '★ ${favorite.poiRating!.toStringAsFixed(1)}',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: TpSpacing.s2),
              child: Text(
                trips.isEmpty ? '尚未用於任何行程' : '用於:${trips.join('、')}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(TpSpacing.s6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: TpSpacing.s2),
            Text(
              body,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
