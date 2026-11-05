import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

extension PopOrGoTrip on BuildContext {
  /// 關閉整頁 modal:有上一頁就返回,深連結直接進來(沒有上一頁)就回該行程。
  void popOrGoTrip(String tripId) {
    if (canPop()) {
      pop();
    } else {
      go('/trips/${Uri.encodeComponent(tripId)}');
    }
  }
}
