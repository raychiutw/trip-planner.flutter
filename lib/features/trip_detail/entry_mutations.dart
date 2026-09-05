/// 停留點 mutation module:確認政策、交通重算範圍、快取失效表,只在這裡一份。
///
/// 畫面呼叫的是「設為正選」「重算交通」「宣告改了什麼」,不再各自決定要 invalidate
/// 哪幾個 provider、重算失敗要怎麼講、要不要先確認。交通重算的停滯狀態也住在這裡
/// (per trip 的 notifier 狀態),不再是 process-global 的 Set。
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_error.dart';
import '../../api/providers.dart';
import '../../app/adaptive.dart';
import '../../app/app_feedback.dart';
import '../../models/entry.dart';
import 'trip_providers.dart';

/// mutation 宣告自己改了什麼;失效表由 [EntryMutations.refreshAfter] 決定。
enum TripChange { detail, days, notes, segments, entry }

/// 交通重算的 per-trip 狀態。
@immutable
class TravelRecomputeState {
  const TravelRecomputeState({this.stalledDays = const {}});

  /// 自動重算失敗、等使用者再觸發的那幾天(顯示「車程待更新」)。
  final Set<int> stalledDays;

  TravelRecomputeState copyWith({Set<int>? stalledDays}) =>
      TravelRecomputeState(stalledDays: stalledDays ?? this.stalledDays);
}

class EntryMutations extends Notifier<TravelRecomputeState> {
  EntryMutations(this.tripId);

  final String tripId;

  /// 已經請求過自動重算的缺口組合;同一組只請求一次。純去重,不需要觀察,
  /// 所以不放進 state —— 畫面是在 build 期間發現缺口的,那時不能改 provider 狀態。
  final _requestedGaps = <String>{};

  /// container 已被丟掉(例如測試換整棵樹、或 app 登出重建)後,任何仍在飛的
  /// await 回來都不能再碰 ref。
  bool _disposed = false;

  @override
  TravelRecomputeState build() {
    ref.onDispose(() => _disposed = true);
    return const TravelRecomputeState();
  }

  /// 一張表:改了什麼 → 重抓什麼。
  void refreshAfter(Set<TripChange> changed, {int? entryId}) {
    if (_disposed) return;
    if (changed.contains(TripChange.detail)) {
      ref.invalidate(tripDetailProvider(tripId));
    }
    if (changed.contains(TripChange.days)) {
      ref.invalidate(tripDaysProvider(tripId));
    }
    if (changed.contains(TripChange.notes)) {
      ref.invalidate(tripNotesProvider(tripId));
    }
    if (changed.contains(TripChange.segments)) {
      ref.invalidate(tripSegmentsProvider(tripId));
    }
    if (changed.contains(TripChange.entry) && entryId != null) {
      ref.invalidate(entryDetailProvider((tripId: tripId, entryId: entryId)));
    }
  }

  /// 交通重算。**失敗可忽略** —— 主要 mutation 已經成功,交通資料會在下一次
  /// 刷新自行補齊;這條政策只在這裡一份。[auto] 失敗把該日標成停滯,成功清掉。
  /// 有 [dayNum] 就只重算那一天,沒有就整趟。
  Future<bool> recomputeTravel({int? dayNum, bool auto = false}) async {
    if (_disposed) return false;
    // await 之前就拿到 repository:回來時 container 可能已經沒了。
    final repository = ref.read(tripRepositoryProvider);
    try {
      await repository.recomputeTravel(
        tripId: tripId,
        day: dayNum?.toString() ?? 'all',
      );
      if (_disposed) return true;
      if (dayNum != null && state.stalledDays.contains(dayNum)) {
        state = state.copyWith(
          stalledDays: {...state.stalledDays}..remove(dayNum),
        );
      }
      return true;
    } on Object {
      // 連 Error 都吞:重算是次要修復,不能讓它把主流程打掛(原 sheet 也是 catch 全部)。
      if (auto && dayNum != null && !_disposed) {
        state = state.copyWith(stalledDays: {...state.stalledDays, dayNum});
      }
      return false;
    }
  }

  /// 畫面發現缺 segment 時的自動重算;同一組缺口只請求一次,完成後重抓 segments。
  void requestGapRecompute({required int dayNum, required String gapKey}) {
    if (!_requestedGaps.add('$dayNum:$gapKey')) return;
    // 可能在 build 期間被呼叫:所有狀態變更都排到下一個 microtask。
    unawaited(
      Future<void>.microtask(() async {
        if (_disposed) return;
        if (state.stalledDays.contains(dayNum)) {
          state = state.copyWith(
            stalledDays: {...state.stalledDays}..remove(dayNum),
          );
        }
        await recomputeTravel(dayNum: dayNum, auto: true);
        refreshAfter({TripChange.segments});
      }),
    );
  }

  /// 設為正選。確認政策(一律確認,跨區時附警告)、重算範圍(知道哪一天就只算那天)、
  /// 失效與提示,時間軸與 POI 畫面共用同一份。回傳是否真的設定成功。
  Future<bool> setMaster(
    BuildContext context, {
    required TimelineEntry entry,
    required EntryPoiInfo alternate,
    required List<TimelineEntry> sameDayEntries,
    required int? dayNum,
  }) async {
    final warning = crossRegionWarning(alternate, sameDayEntries, entry.id);
    final ok = await showAppConfirm(
      context,
      title: '設為正選？',
      message:
          '要將「${alternate.name ?? '未命名地點'}」設為此停留點的正選嗎？'
          '${warning == null ? '' : '\n\n$warning'}',
      confirmLabel: '設為正選',
    );
    if (!ok || !context.mounted) return false;
    try {
      await ref
          .read(tripRepositoryProvider)
          .setEntryMaster(
            tripId: tripId,
            entryId: entry.id,
            poiId: alternate.poiId,
            entryPoisVersion: entry.entryPoisVersion,
          );
    } on ApiError catch (error) {
      refreshAfter({TripChange.entry}, entryId: entry.id);
      if (context.mounted) {
        showAppError(
          context,
          error.status == 409 ? '地點已更新，已重新載入' : '設為正選失敗，請重新載入後再試',
        );
      }
      return false;
    } on Exception {
      if (context.mounted) showAppError(context, '設為正選失敗，請重新載入後再試');
      return false;
    }
    await recomputeTravel(dayNum: dayNum);
    refreshAfter({
      TripChange.days,
      TripChange.segments,
      TripChange.entry,
    }, entryId: entry.id);
    if (context.mounted) showAppNotice(context, '已設為正選');
    return true;
  }
}

final entryMutationsProvider =
    NotifierProvider.family<EntryMutations, TravelRecomputeState, String>(
      EntryMutations.new,
    );

/// 離線同步 / 衝突解決後不知道動到哪一趟:整個家族一起重抓。
/// [ref] 是 Ref 或 WidgetRef(兩者沒有共同的 invalidate 介面,所以收 dynamic)。
void invalidateTripFamilies(dynamic ref) {
  ref.invalidate(tripDetailProvider);
  ref.invalidate(tripDaysProvider);
  ref.invalidate(tripNotesProvider);
  ref.invalidate(tripSegmentsProvider);
  ref.invalidate(entryDetailProvider);
}

// ── 跨區警告(從 POI 畫面搬來,兩個畫面共用)──────────────────────────────

typedef _LatLng = ({double lat, double lng});

const _crossRegionThresholdM = 50000.0;
const _earthRadiusM = 6371000.0;

/// 新正選離本日其他停留點的重心超過 50 km 就提醒可能跨區;否則 null。
String? crossRegionWarning(
  EntryPoiInfo alternate,
  List<TimelineEntry> sameDayEntries,
  int entryId,
) {
  final lat = alternate.lat;
  final lng = alternate.lng;
  if (lat == null || lng == null) return null;

  final siblingCoords = <_LatLng>[
    for (final entry in sameDayEntries)
      if (entry.id != entryId &&
          entry.master?.lat != null &&
          entry.master?.lng != null)
        (lat: entry.master!.lat!, lng: entry.master!.lng!),
  ];
  final center = _avgLatLng(siblingCoords);
  if (center == null) return null;

  final distance = _haversineMeters((lat: lat, lng: lng), center);
  if (distance <= _crossRegionThresholdM) return null;

  final km = distance >= 100000
      ? (distance / 1000).round().toString()
      : (distance / 1000).toStringAsFixed(1);
  return '新正選距離本日其他點約 $km km，可能跨區，前後車程會誤算。確定要設為正選？';
}

_LatLng? _avgLatLng(List<_LatLng> points) {
  if (points.isEmpty) return null;
  var lat = 0.0;
  var lng = 0.0;
  for (final point in points) {
    lat += point.lat;
    lng += point.lng;
  }
  return (lat: lat / points.length, lng: lng / points.length);
}

double _haversineMeters(_LatLng a, _LatLng b) {
  final phi1 = _toRadians(a.lat);
  final phi2 = _toRadians(b.lat);
  final dPhi = _toRadians(b.lat - a.lat);
  final dLambda = _toRadians(b.lng - a.lng);
  final h =
      math.sin(dPhi / 2) * math.sin(dPhi / 2) +
      math.cos(phi1) *
          math.cos(phi2) *
          math.sin(dLambda / 2) *
          math.sin(dLambda / 2);
  return 2 * _earthRadiusM * math.atan2(math.sqrt(h), math.sqrt(1 - h));
}

double _toRadians(double degrees) => degrees * math.pi / 180;
