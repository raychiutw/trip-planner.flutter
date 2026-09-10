import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:tripline/app/accessibility_scope.dart';
import 'package:tripline/theme/app_theme.dart';
import 'package:tripline/ui/tp_app_bar.dart';
import 'package:tripline/ui/tp_root_scaffold.dart';

const _bandKey = ValueKey('tp-root-header-band');
const _boundarySize = Size(390, 844);
const _topInset = 47.0;

/// 條紋高度：對比帶內外都用同一組黑白橫紋當「可辨識內容」的替身。
const _stripeHeight = 8.0;

/// 取像素而不是取 widget 參數 —— 這個專案已經因為「參數對、畫面錯」吃過四次虧。
class _Pixels {
  const _Pixels(this._raw, this._width);

  final ByteData _raw;
  final int _width;

  double lumaAt(int x, int y) {
    final offset = (y * _width + x) * 4;
    final r = _raw.getUint8(offset);
    final g = _raw.getUint8(offset + 1);
    final b = _raw.getUint8(offset + 2);
    return 0.299 * r + 0.587 * g + 0.114 * b;
  }

  /// 一整段垂直線上相鄰列的亮度落差總和 —— 內容越清晰數字越大，越糊越小。
  double verticalContrast(int x, int fromY, int toY) {
    var total = 0.0;
    for (var y = fromY; y < toY; y++) {
      total += (lumaAt(x, y) - lumaAt(x, y + 1)).abs();
    }
    return total;
  }

  double horizontalContrast(int y, int fromX, int toX) {
    var total = 0.0;
    for (var x = fromX; x < toX; x++) {
      total += (lumaAt(x, y) - lumaAt(x + 1, y)).abs();
    }
    return total;
  }
}

Future<_Pixels> _capture(WidgetTester tester, GlobalKey key) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  late ByteData raw;
  late int width;
  await tester.runAsync(() async {
    final layer = boundary.debugLayer! as OffsetLayer;
    final image = await layer.toImage(boundary.paintBounds);
    width = image.width;
    raw = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    image.dispose();
  });
  return _Pixels(raw, width);
}

Widget _scene({
  required GlobalKey boundaryKey,
  required ScrollController controller,
  bool packageReference = false,
  bool highContrast = false,
  bool reduceTransparency = false,
  List<Widget> actions = const <Widget>[],
}) {
  return AppAccessibilityScope(
    reduceTransparency: reduceTransparency,
    child: RepaintBoundary(
      key: boundaryKey,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: MediaQuery(
          data: MediaQueryData(
            size: _boundarySize,
            padding: const EdgeInsets.only(top: _topInset),
            highContrast: highContrast,
          ),
          child: Builder(
            builder: (context) {
              final body = TpRootScrollView(
                controller: controller,
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        for (var index = 0; index < 200; index++)
                          Container(
                            height: _stripeHeight,
                            color: index.isEven ? Colors.black : Colors.white,
                          ),
                      ],
                    ),
                  ),
                ],
              );
              if (packageReference) {
                return Scaffold(
                  body: Stack(
                    children: [
                      Positioned.fill(child: body),
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: TpRootGeometry.bandBottom(context),
                        child: GlassScrollEdgeEffect(
                          fadeBottom: false,
                          topFadeHeight: TpRootGeometry.bandBottom(context),
                          fadeColor: Theme.of(context).scaffoldBackgroundColor,
                          child: const ProgressiveBlur(),
                        ),
                      ),
                    ],
                  ),
                );
              }
              return TpRootScaffold(
                header: TpRootHeaderConfig(
                  title: const Text('京都五日行'),
                  actions: actions,
                ),
                body: body,
              );
            },
          ),
        ),
      ),
    ),
  );
}

/// 捲到內容整片穿過 header 帶為止。
Future<void> _scrollUnderBand(
  WidgetTester tester,
  ScrollController controller,
) async {
  controller.jumpTo(400);
  await tester.pump();
}

// flutter_tester 會實際柵格化 `BackdropFilter`（release artifact flow 早就在
// 這個環境把畫面寫成 PNG），所以模糊可以直接量像素，不必退回斷言 settings。
void main() {
  testWidgets('push 與 sheet 關閉後，pop 平移不模糊露出的上一頁', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = _boundarySize;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final boundaryKey = GlobalKey();
    final navigatorKey = GlobalKey<NavigatorState>();
    Widget stripes() => Column(
      children: [
        for (var i = 0; i < 106; i++)
          SizedBox(
            height: _stripeHeight,
            width: double.infinity,
            child: ColoredBox(color: i.isEven ? Colors.black : Colors.white),
          ),
      ],
    );
    var actions = 0;
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: MaterialApp(
          theme: AppTheme.light(),
          navigatorKey: navigatorKey,
          home: Scaffold(
            body: ClipRect(
              child: OverflowBox(
                alignment: Alignment.topCenter,
                maxHeight: 1000,
                child: stripes(),
              ),
            ),
          ),
        ),
      ),
    );
    navigatorKey.currentState!.push<void>(
      CupertinoPageRoute(
        builder: (_) => TpRootScaffold(
          header: TpRootHeaderConfig(
            title: const Text('第二頁'),
            actions: [
              TpToolbarIconButton(
                icon: CupertinoIcons.share,
                tooltip: '分享',
                onPressed: () => actions++,
              ),
            ],
          ),
          body: ClipRect(
            child: OverflowBox(
              alignment: Alignment.topCenter,
              maxHeight: 1000,
              child: stripes(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('分享'));
    await tester.pumpAndSettle();
    showCupertinoModalPopup<void>(
      context: tester.element(find.text('第二頁')),
      builder: (_) => const CupertinoActionSheet(title: Text('覆蓋中的 sheet')),
    );
    await tester.pumpAndSettle();
    expect(find.text('覆蓋中的 sheet'), findsOneWidget);
    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('分享'));
    await tester.pumpAndSettle();
    expect(actions, 2);
    navigatorKey.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final route = tester.getRect(find.byType(TpRootScaffold));
    expect(route.left, greaterThan(20), reason: '必須量測 pop 途中露出的上一頁');
    final pixels = await _capture(tester, boundaryKey);
    expect(
      pixels.verticalContrast(8, 8, 56),
      greaterThan(1000),
      reason: '新頁面的遮蔽不可跨出平移後的 route 邊界',
    );
    await tester.pumpAndSettle();
    expect(find.text('第二頁'), findsNothing);
  });

  testWidgets('帶狀遮蔽採公開預設的模糊與淡出呈現', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = _boundarySize;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final boundaryKey = GlobalKey();
    Future<_Pixels> paint(bool reference) async {
      await tester.pumpWidget(
        _scene(
          boundaryKey: boundaryKey,
          controller: controller,
          packageReference: reference,
        ),
      );
      await _scrollUnderBand(tester, controller);
      return _capture(tester, boundaryKey);
    }

    final actual = await paint(false);
    final reference = await paint(true);
    // 在控制項外的相同條紋取樣；預期來自獨立公開套件組裝，而非舊 sigma 配方。
    for (final y in [60, 80, 100, 116]) {
      expect(
        actual.lumaAt(8, y),
        closeTo(reference.lumaAt(8, y), 1),
        reason: 'y=$y 應採新版預設淡出與模糊',
      );
    }
  });

  testWidgets('膠囊縫隙底下的內容被糊掉並淡出，不會清晰地穿上來', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = _boundarySize;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final boundaryKey = GlobalKey();
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _scene(boundaryKey: boundaryKey, controller: controller),
    );
    await _scrollUnderBand(tester, controller);

    final title = tester.getRect(
      find.byKey(const ValueKey('tp-root-header-title')),
    );
    final avatar = tester.getRect(find.byType(TpAccountAvatarButton));
    final header = tester.getRect(
      find.byKey(const ValueKey('tp-root-glass-header')),
    );
    // 量在膠囊之間的縫隙 —— #167 真機回報「返回鍵旁漏出一個孤零零的 0」的位置。
    final gapX = ((title.right + avatar.left) / 2).round();
    expect(gapX, greaterThan(title.right.ceil()));
    expect(gapX, lessThan(avatar.left.floor()));

    final pixels = await _capture(tester, boundaryKey);
    final insideBand = pixels.verticalContrast(
      gapX,
      header.top.round() + 6,
      header.bottom.round() - 6,
    );
    final belowBand = pixels.verticalContrast(
      gapX,
      header.bottom.round() + 80,
      header.bottom.round() + 140,
    );

    // 非空測試的前提：帶外的同一批條紋必須真的清晰。
    expect(belowBand, greaterThan(400), reason: '對照組必須是清晰內容，否則這條測試恆真');
    expect(
      insideBand,
      lessThan(belowBand * 0.15),
      reason: '膠囊帶底下的內容必須糊掉並淡出，量到的是 $insideBand vs $belowBand',
    );
  });

  testWidgets('底部 root tab 帶底下的內容同樣被糊掉，不會清晰地穿上來', (tester) async {
    // 頂部有 `_TpRootHeaderBand`，底部原本什麼都沒有 —— 真機與模擬器都看得到
    // 「停留點 16」清晰地穿過 tab bar、與「行程」「地圖」的文字疊在一起。
    // tab bar 自己是玻璃，但玻璃只糊它自己蓋住的那一塊，且 shader 的模糊在
    // 模擬器上不渲染；帶狀遮蔽是內容側的處理，兩者不能互相取代。
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = _boundarySize;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final boundaryKey = GlobalKey();
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _scene(boundaryKey: boundaryKey, controller: controller),
    );
    await _scrollUnderBand(tester, controller);

    final band = tester.getRect(find.byKey(const ValueKey('tp-root-tab-band')));
    final pixels = await _capture(tester, boundaryKey);
    const x = 200;
    final insideBand = pixels.verticalContrast(
      x,
      band.top.round() + 6,
      band.bottom.round() - 6,
    );
    final aboveBand = pixels.verticalContrast(
      x,
      band.top.round() - 140,
      band.top.round() - 80,
    );

    expect(aboveBand, greaterThan(400), reason: '對照組必須是清晰內容，否則這條測試恆真');
    expect(
      insideBand,
      lessThan(aboveBand * 0.15),
      reason: 'root tab 帶底下的內容必須糊掉，量到的是 $insideBand vs $aboveBand',
    );
  });

  testWidgets('遮蔽是漸進的：越接近膠囊帶越糊', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = _boundarySize;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final boundaryKey = GlobalKey();
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _scene(boundaryKey: boundaryKey, controller: controller),
    );
    await _scrollUnderBand(tester, controller);

    final title = tester.getRect(
      find.byKey(const ValueKey('tp-root-header-title')),
    );
    final avatar = tester.getRect(find.byType(TpAccountAvatarButton));
    final header = tester.getRect(
      find.byKey(const ValueKey('tp-root-glass-header')),
    );
    final band = tester.getRect(find.byKey(_bandKey));
    final gapX = ((title.right + avatar.left) / 2).round();
    expect(header.bottom, lessThan(band.bottom), reason: '帶要延伸到膠囊下方才有羽化區可量');

    // 三個等長視窗，長度取條紋週期（黑白各一條）—— 相位一致，清晰值可直接比。
    const window = _stripeHeight * 2;
    final edge = band.bottom.round();
    final pixels = await _capture(tester, boundaryKey);
    double contrastFrom(double top) =>
        pixels.verticalContrast(gapX, top.round(), (top + window).round());
    final insideBand = contrastFrom(edge - window * 2);
    final straddling = contrastFrom(edge - window / 2);
    final outsideBand = contrastFrom(edge + window / 2);

    // 硬邊切斷會讓跨越帶底的視窗與帶外一樣清晰；漸進遮蔽則卡在中間。
    expect(outsideBand, greaterThan(300), reason: '對照組必須是清晰內容，否則這條測試恆真');
    expect(
      straddling,
      lessThan(outsideBand),
      reason: '帶底附近就要開始糊，量到的是 $straddling vs $outsideBand',
    );
    expect(
      insideBand,
      lessThan(straddling),
      reason: '越往帶內越糊，量到的是 $insideBand vs $straddling',
    );
  });

  testWidgets('遮蔽帶橫跨整個寬度並延伸到膠囊下方，膠囊本身不被糊到', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = _boundarySize;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final boundaryKey = GlobalKey();
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _scene(boundaryKey: boundaryKey, controller: controller),
    );
    await _scrollUnderBand(tester, controller);

    final band = tester.getRect(find.byKey(_bandKey));
    final context = tester.element(find.byKey(_bandKey));
    final header = tester.getRect(
      find.byKey(const ValueKey('tp-root-glass-header')),
    );
    expect(band.top, 0, reason: '狀態列那一段也在帶內');
    expect(band.left, 0);
    expect(band.width, _boundarySize.width, reason: '左右邊距的縫隙也要遮住');
    expect(band.bottom, greaterThan(header.bottom), reason: '要在膠囊下方留出羽化區');
    expect(
      band.bottom,
      lessThanOrEqualTo(TpRootGeometry.initialContentTop(context)),
      reason: '帶不能吃到內容的靜止起點，否則第一筆一開始就是糊的',
    );

    // 遮蔽層必須畫在膠囊**底下** —— 標題文字本身要維持清晰。
    final titleRect = tester.getRect(find.text('京都五日行'));
    final pixels = await _capture(tester, boundaryKey);
    expect(
      pixels.horizontalContrast(
        titleRect.center.dy.round(),
        titleRect.left.round(),
        titleRect.right.round(),
      ),
      greaterThan(200),
      reason: '標題不能被自己的遮蔽層糊掉',
    );
  });

  testWidgets('遮蔽帶不吃觸控：帶內仍可捲動、膠囊仍可點', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = _boundarySize;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var taps = 0;
    final boundaryKey = GlobalKey();
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _scene(
        boundaryKey: boundaryKey,
        controller: controller,
        actions: [
          TpToolbarIconButton(
            key: const ValueKey('band-action'),
            icon: Icons.share,
            tooltip: '分享',
            onPressed: () => taps++,
          ),
        ],
      ),
    );

    final band = tester.getRect(find.byKey(_bandKey));
    final title = tester.getRect(
      find.byKey(const ValueKey('tp-root-header-title')),
    );
    final action = tester.getRect(find.byKey(const ValueKey('band-action')));
    // 起手點落在遮蔽帶內、且不在任何膠囊上。
    final gapPoint = Offset((title.right + action.left) / 2, band.center.dy);
    await tester.dragFrom(gapPoint, const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(controller.offset, greaterThan(0), reason: '遮蔽帶內起手的拖曳要穿透到底下的內容');

    await tester.tap(find.byKey(const ValueKey('band-action')));
    await tester.pump();
    expect(taps, 1, reason: '膠囊仍要可點');
  });

  testWidgets('底部 root tab 帶不吃觸控:帶內仍可捲動', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = _boundarySize;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final boundaryKey = GlobalKey();
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _scene(boundaryKey: boundaryKey, controller: controller),
    );

    final band = tester.getRect(find.byKey(const ValueKey('tp-root-tab-band')));
    // 起手點落在帶的上緣附近(膠囊 tab bar 之上、帶之內)。
    final gapPoint = Offset(band.center.dx, band.top + 8);
    await tester.dragFrom(gapPoint, const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(controller.offset, greaterThan(0), reason: '底部帶內起手的拖曳要穿透到底下的內容');
  });

  for (final fallback in const [
    (label: '提高對比', highContrast: true, reduceTransparency: false),
    (label: '降低透明度', highContrast: false, reduceTransparency: true),
  ]) {
    testWidgets('${fallback.label}下遮蔽帶收斂成不透明，內容完全不透出', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = _boundarySize;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final boundaryKey = GlobalKey();
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _scene(
          boundaryKey: boundaryKey,
          controller: controller,
          highContrast: fallback.highContrast,
          reduceTransparency: fallback.reduceTransparency,
        ),
      );
      await _scrollUnderBand(tester, controller);

      final title = tester.getRect(
        find.byKey(const ValueKey('tp-root-header-title')),
      );
      final avatar = tester.getRect(find.byType(TpAccountAvatarButton));
      final header = tester.getRect(
        find.byKey(const ValueKey('tp-root-glass-header')),
      );
      final gapX = ((title.right + avatar.left) / 2).round();

      final pixels = await _capture(tester, boundaryKey);
      expect(
        pixels.verticalContrast(
          gapX,
          header.top.round() + 6,
          header.bottom.round() - 6,
        ),
        0,
        reason: '無障礙 fallback 下不做模糊，改用不透明帶，內容一格都不能透出',
      );
      // 底部 root tab 帶同一套 fallback:膠囊帶底下也一格都不透出。
      final band = tester.getRect(
        find.byKey(const ValueKey('tp-root-tab-band')),
      );
      expect(
        pixels.verticalContrast(
          200,
          band.top.round() + 6,
          band.bottom.round() - 6,
        ),
        0,
        reason:
            '底部帶在 fallback 下整條不透明(master 就是整條 ColoredBox),'
            'tab bar 上半段也不能透出',
      );
      // 羽化區照 master 仍淡出到 0(不是硬邊):帶內緣往內幾格要量得到內容。
      final featherEnd =
          header.bottom.round() + TpRootGeometry.bandFeather.round();
      expect(
        pixels.verticalContrast(
          gapX,
          header.bottom.round() + 1,
          featherEnd - 1,
        ),
        greaterThan(0),
        reason: 'fallback 只把帶做成不透明,羽化區仍淡出,不是硬邊',
      );
    });
  }
}
