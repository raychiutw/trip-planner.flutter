/// 時間軸與地圖共用的「目前選取日」。
///
/// 移除兩個 header 上互相跳轉的 bar button 之後，改由 root tab 承擔切換；
/// 原本靠查詢參數帶過去的「第幾天」由這個狀態承接。四條約束寫在型別裡：
///
/// 1. **綁行程**：值一律是 `(tripId, dayNum)`，切換行程後不會殘留前一個行程的天數。
/// 2. **「全部」不進來**：地圖的空值意思是「全部」，時間軸的空值意思是
///    「未指定 → 第一天」；同一個空值兩種語意，因此 `select` 只收非空天數。
/// 3. **只有前景分支可寫入**：由呼叫端以 `TickerMode` 守門，這裡不做假設。
/// 4. **純記憶體不持久化**：時間軸每捲動換一天就寫一次，持久化等於每次捲動寫磁碟。
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 綁定行程的選取日。
@immutable
class SelectedTripDay {
  const SelectedTripDay({required this.tripId, required this.dayNum});

  final String tripId;
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

/// 讓呼叫端只問「這個行程現在是第幾天」，避免各自比對 tripId。
extension SelectedTripDayLookup on SelectedTripDay? {
  int? dayNumFor(String tripId) {
    final selected = this;
    return selected != null && selected.tripId == tripId
        ? selected.dayNum
        : null;
  }
}

class SelectedDayController extends Notifier<SelectedTripDay?> {
  @override
  SelectedTripDay? build() => null;

  /// 記下某個行程目前看的是第幾天。`tripId` 為空字串時忽略。
  void select({required String tripId, required int dayNum}) {
    if (tripId.isEmpty) return;
    final next = SelectedTripDay(tripId: tripId, dayNum: dayNum);
    if (state == next) return;
    state = next;
  }
}

/// 時間軸與地圖共用的目前選取日（純記憶體，不跨 app 啟動保留）。
final selectedDayProvider =
    NotifierProvider<SelectedDayController, SelectedTripDay?>(
      SelectedDayController.new,
    );
