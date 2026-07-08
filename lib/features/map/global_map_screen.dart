/// 全域地圖:把所有收藏 POI(GET /poi-favorites,跨行程)畫在地圖 adapter 上,
/// 依 poi_type 上色;點 marker → 顯示名稱/評分/所屬行程。
/// (web 的 /map 實為 dead code 導回單行程地圖;此處實作真正的跨行程地圖。)
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/poi_favorite.dart';
import '../../theme/app_theme.dart';
import '../../theme/poi_tone.dart';
import '../../theme/tokens.dart';
import '../favorites/favorites_providers.dart';
import 'map_adapter.dart';

bool _hasCoords(PoiFavorite f) =>
    f.poiLat != null && f.poiLng != null && f.poiLat != 0 && f.poiLng != 0;

class GlobalMapScreen extends ConsumerStatefulWidget {
  const GlobalMapScreen({super.key, this.tileProvider});

  /// 測試注入(避免抓真 tile);prod 為 null → 走網路 OSM。
  final TripMapTileProvider? tileProvider;

  @override
  ConsumerState<GlobalMapScreen> createState() => _GlobalMapScreenState();
}

class _GlobalMapScreenState extends ConsumerState<GlobalMapScreen> {
  final FlutterTripMapController _mapController = FlutterTripMapController();
  int? _selectedId;

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
        loading: () => const Center(child: CircularProgressIndicator()),
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
      tilePreset: kTripMapTilePresets.first,
      initialFitPoints: points,
      initialPadding: const EdgeInsets.all(TpSpacing.s10),
      initialMaxZoom: 14,
      tileProvider: widget.tileProvider,
      onTap: (_) => setState(() => _selectedId = null),
      markers: [
        for (final f in pins)
          TripMapMarker(
            point: TripMapPoint(f.poiLat!, f.poiLng!),
            width: 28,
            height: 28,
            child: GestureDetector(
              key: ValueKey('map-fav-${f.id}'),
              onTap: () => setState(() => _selectedId = f.id),
              child: Container(
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
              ),
            ),
          ),
      ],
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
                  icon: const Icon(Icons.close),
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
