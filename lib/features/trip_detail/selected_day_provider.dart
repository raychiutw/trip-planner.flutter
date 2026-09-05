/// 時間軸與地圖共用的「目前選取日」。
///
/// 移除兩個 header 上互相跳轉的 bar button 之後，改由 root tab 承擔切換；
/// 原本靠查詢參數帶過去的「第幾天」由這個狀態承接。三條約束寫在型別裡：
///
/// 1. **綁行程**：值一律帶 `tripId`，切換行程後不會殘留前一個行程的天數。
/// 2. **三態**：指定某天（[SelectedTripDay]）、全部（[SelectedAllDays]）、
///    未指定（`null`）。地圖的「全部」有自己的型別，不再與時間軸的「未指定 →
///    第一天」共用一個空值。
/// 3. **只有前景分支可寫入**：[SelectedDayController.publish] 自己以 `TickerMode`
///    守門。riverpod 3 會在 `TickerMode` 關閉時暫停該畫面的訂閱，但「emit 落在
///    切到背景的同一批」時，畫面仍會以背景身分重建一次並處理到新資料，那一格
///    不得寫進來。
/// 4. **純記憶體不持久化**：時間軸每捲動換一天就寫一次，持久化等於每次捲動寫磁碟。
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 綁定行程的選取狀態。
@immutable
sealed class SelectedDay {
  const SelectedDay({required this.tripId});

  final String tripId;
}

/// 指定某一天。
final class SelectedTripDay extends SelectedDay {
  const SelectedTripDay({required super.tripId, required this.dayNum});

  final int dayNum;

  @override
  bool operator ==(Object other) =>
      other is SelectedTripDay &&
      other.tripId == tripId &&
      other.dayNum == dayNum;

  @override
  int get hashCode => Object.hash(tripId, dayNum);

  @override
  String toString() => 'SelectedTripDay($tripId, day $dayNum)';
}

/// 地圖的「全部」。
final class SelectedAllDays extends SelectedDay {
  const SelectedAllDays({required super.tripId});

  @override
  bool operator ==(Object other) =>
      other is SelectedAllDays && other.tripId == tripId;

  @override
  int get hashCode => Object.hash(SelectedAllDays, tripId);

  @override
  String toString() => 'SelectedAllDays($tripId)';
}

/// 讓呼叫端只問「這個行程現在是第幾天／是不是全部」，避免各自比對 tripId。
extension SelectedDayLookup on SelectedDay? {
  int? dayNumFor(String tripId) => switch (this) {
    SelectedTripDay(tripId: final t, :final dayNum) when t == tripId => dayNum,
    _ => null,
  };

  bool showsAllDaysFor(String tripId) => switch (this) {
    SelectedAllDays(tripId: final t) => t == tripId,
    _ => false,
  };
}

class SelectedDayController extends Notifier<SelectedDay?> {
  @override
  SelectedDay? build() => null;

  /// 記下某個行程目前看的是第幾天。`tripId` 為空字串時忽略。
  ///
  /// 不需要自己比對舊值：riverpod 的 Notifier 已用 `==` 去重，寫入相同的
  /// `(tripId, dayNum)` 不會通知 listener。
  void select({required String tripId, required int dayNum}) {
    if (tripId.isEmpty) return;
    state = SelectedTripDay(tripId: tripId, dayNum: dayNum);
  }

  /// 記下某個行程目前看的是「全部」（地圖）。
  void selectAll({required String tripId}) {
    if (tripId.isEmpty) return;
    state = SelectedAllDays(tripId: tripId);
  }

  /// 畫面寫回的唯一入口：只有前景分支（`TickerMode` 開啟）才寫；
  /// `dayNum` 為 null 表示「全部」。
  void publish(BuildContext context, {required String tripId, int? dayNum}) {
    if (!TickerMode.valuesOf(context).enabled) return;
    if (dayNum == null) {
      selectAll(tripId: tripId);
    } else {
      select(tripId: tripId, dayNum: dayNum);
    }
  }
}

/// 時間軸與地圖共用的目前選取日（純記憶體，不跨 app 啟動保留）。
final selectedDayProvider =
    NotifierProvider<SelectedDayController, SelectedDay?>(
      SelectedDayController.new,
    );
