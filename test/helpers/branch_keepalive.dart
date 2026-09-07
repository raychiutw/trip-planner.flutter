/// StatefulShellRoute 分支保活的測試替身。
///
/// root tab 之間切換時,go_router 不會丟掉背景分支的 widget 樹,而是以
/// Offstage + TickerMode 保活。凡是「畫面在背景時該不該做某件事」的測試都需要
/// 重現這個拓樸,因此集中放在這裡供各 feature 測試共用。
library;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/widgets.dart';
import 'package:tripline/features/trip_detail/selected_day_provider.dart';

/// 模擬 StatefulShellRoute 的分支保活:前景／背景以 TickerMode 切換,
/// 且子樹 widget 實例不變(背景分支不會因切換而重建整棵樹)。
///
/// `active` 傳 null 代表不模擬分支,直接把 [child] 放進樹裡。
class MaybeBranch extends StatelessWidget {
  const MaybeBranch({super.key, required this.active, required this.child});

  final ValueListenable<bool>? active;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final listenable = active;
    if (listenable == null) return child;
    return ValueListenableBuilder<bool>(
      valueListenable: listenable,
      builder: (context, enabled, child) =>
          TickerMode(enabled: enabled, child: child!),
      child: child,
    );
  }
}

/// 以指定初始值起跳的共用選取日,用來驗證「查詢參數缺席時才採用共用狀態」。
class SeededSelectedDayController extends SelectedDayController {
  SeededSelectedDayController(this.seed);

  final SelectedDay? seed;

  @override
  SelectedDay? build() => seed;
}
