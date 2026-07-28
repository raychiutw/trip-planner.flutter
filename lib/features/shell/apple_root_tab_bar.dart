import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../theme/tokens.dart';
import '../../ui/tp_glass_surface.dart';

/// Root tab bar：固定尺寸、恆顯 label。
///
/// 刻意不做 iOS 26 的 tab bar minimize —— Apple 的 minimize 語意綁定「tab bar
/// 底下是可捲動內容」，本 app 多數 root 畫面底下是固定版面，縮放只會讓導覽跳動。
/// 拖曳中的指示器相對於欄位的擴張量。
///
/// **只在拖曳中生效**(#179):`AnimatedGlassIndicator` 的幾何是
/// `RelativeRect.lerp(RelativeRect.fill, expansion, thickness)`,靜止時
/// `thickness == 0` → `RelativeRect.fill`,整格欄位。靜止態的膠囊寬度由
/// `_restIndicatorWidthRatio` 自畫控制,與這個常數無關。
///
/// 套件預設是往外擴 12pt;這裡往內收,讓拖曳中的玻璃透鏡(欄寬 −28pt)貼近
/// 靜止態膠囊(欄寬 70%),兩態切換時不會突然放大。
const _indicatorExpansion = EdgeInsets.symmetric(horizontal: -14, vertical: -2);

/// 靜止態選取膠囊佔欄寬的比例(#179)。
///
/// 對照 iOS 26「電話」app 約 70%。套件靜止態畫的是整格欄位(實測 390pt 螢幕
/// 下膠囊 87.5pt / 欄寬 89.5pt = 98%),且沒有任何參數調得動 —— 0.23.0／0.24.3
/// 的 `AnimatedGlassIndicator` 仍是同一段 `RelativeRect.lerp`,`padding` 寫死
/// `EdgeInsets.all(4)`。所以膠囊改由本檔自畫,疊在選取態字符的底下。
const _restIndicatorWidthRatio = 0.70;

/// 靜止態膠囊上下各留的間隙。
///
/// 套件的選取層被 `JellyClipper` 裁成「欄位內縮 4pt」的膠囊,自畫膠囊必須完整
/// 落在裡面才不會被切角,所以取 5(> 4)。
const _restIndicatorVerticalInset = 5.0;

/// 套件 `GlassTabBar` 的標籤基準樣式(`labelFontSize` 預設 11)。
///
/// `selectedLabelStyle` 是**疊在**這份樣式上的(`BottomBarTabItem` 內部
/// `baseLabelStyle.merge(stateLabelStyle)`),量標籤高度時要用同一套合成順序,
/// 否則膠囊的垂直中心會算偏。算偏了有測試會紅(膠囊必須與玻璃列同心)。
const _packageLabelBaseStyle = TextStyle(
  fontSize: 11,
  fontWeight: FontWeight.w600,
);

/// 字符與標籤之間的間距，與傳給 `GlassTabBar` 的 `iconLabelSpacing` 同源
/// （兩個 constructor 都用套件預設 4）。
const _iconLabelSpacing = 4.0;

/// 字符與標籤那一排的左右內縮量(#170)。
///
/// `GlassTabBar` 內部有**兩個互相衝突的水平基準**:
///
/// - 字符／標籤那排住在「玻璃列寬度扣掉 `tabPadding`」的帶狀區裡,四欄均分;
/// - 選取膠囊住在「玻璃列寬度扣掉固定 4pt」的帶狀區裡 —— 那個 4pt 是
///   `TabIndicator` 寫死傳給 `AnimatedGlassIndicator` 的 `padding`,外部參數
///   碰不到(liquid_glass_widgets 0.22.1)。
///
/// 兩條帶子相差多少,第 i 欄的中心就差 `p × (1 − 2(i+0.5)/n)`,與螢幕寬度無關。
/// 套件預設 `.bottom` 是 4、`.inline` 是 8:
///
/// - 4pt(舊值):字符與膠囊同心,但整排被往玻璃列中心擠 3／1／−1／−3pt ——
///   真機量到的「字符被往 bar 中心拉」就是這個;
/// - 0pt:整排回到欄位中心,但膠囊反過來偏 3pt(已用測試確認會紅);
/// - 2pt:兩邊各分一半,任一項最大 1.5pt,都落在票上訂的 2pt 容差內。
///
/// 所以取 2。套件哪天讓 indicator padding 可設定(或升到 0.23.0 後確認可設),
/// 這裡就能改成 0 並讓兩個基準真正合一。
const _tabPadding = EdgeInsets.symmetric(horizontal: 2);

class AppleRootTabBar extends StatelessWidget {
  const AppleRootTabBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    this.inline = false,
    this.focusNodes,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool inline;
  final List<FocusNode>? focusNodes;

  /// 兩態都用實心字符，靠 tint 區分 —— outline↔filled 切換是 Material 作法，
  /// iOS 系統 app 的 tab bar 不這樣做。
  static const _destinations = [
    (label: '聊天', icon: CupertinoIcons.chat_bubble_fill),
    // 整排統一用 `CupertinoIcons`。`SFIcons` 的 glyph 墨跡沒有置中在字框裡
    // ——模擬器實測 60pt 下 `sf_suitcase_fill` 偏右 +9.7pt、`sf_suitcase`
    // +8.8pt,而三個 `CupertinoIcons` 都在 ±0.3pt 內;換算到 24pt 字符約偏
    // 4.8pt,與真機截圖量到的 5pt 吻合。混用兩個字型家族就會有一個對不齊。
    (label: '行程', icon: CupertinoIcons.briefcase_fill),
    (label: '地圖', icon: CupertinoIcons.map_fill),
    (label: '收藏', icon: CupertinoIcons.heart_fill),
  ];

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('apple-root-tab-bar'),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          TpRootTabGeometry.horizontalMargin,
          0,
          TpRootTabGeometry.horizontalMargin,
          inline ? TpSpacing.s2 : TpRootTabGeometry.bottomOffset(context),
        ),
        // 膠囊寬度是欄寬的比例，欄寬只有量到玻璃列本身才知道。
        child: LayoutBuilder(
          builder: (context, constraints) => _buildBar(context, constraints),
        ),
      ),
    );
  }

  Widget _buildBar(BuildContext context, BoxConstraints constraints) {
    final theme = Theme.of(context);
    final glassSettings = tpNavigationGlassSettings(
      context,
      recipe: selectedIndex == 2
          ? TpNavigationGlassRecipe.platformView
          : TpNavigationGlassRecipe.regular,
    );
    // iOS 26 的 tab bar 拿**強調色**當選取背景、前景反白（參考「電話」app 的
    // 通話記錄分頁：選取字符坐在實心強調色底上）。Tripline 用品牌柔褐取代
    // 系統藍 —— app 的 tint 本來就該是品牌色，Apple 的藍是「它的」強調色。
    //
    // 選取指示是「中性底 + tint 前景」，沒有例外。iOS 26「電話」app 實測：
    // 選取膠囊是 #363636 中性灰（比容器亮約 20 階），系統藍在字符與標籤上
    // —— 強調色在前景，不在背景。ADR-0003 曾主張相反，其事實論據經像素
    // 量測為錯誤，已由 ADR-0004 取代。
    final selectionTint = theme.colorScheme.surfaceContainerHighest.withValues(
      alpha: 0.72,
    );
    final selectedLabelStyle = theme.textTheme.labelSmall?.copyWith(
      fontWeight: FontWeight.w700,
    );
    final unselectedLabelStyle = theme.textTheme.labelSmall?.copyWith(
      fontWeight: FontWeight.w500,
    );
    final indicatorSettings = tpResolveGlassSettings(
      context,
      glassSettings.copyWith(
        glassColor: selectionTint,
        platformViewFallbackColor: selectionTint,
      ),
      opaqueColor: theme.colorScheme.surfaceContainerHigh,
    );
    final indicatorColor = indicatorSettings.glassColor;
    // 靜止態膠囊自畫（#179）：欄寬取自玻璃列本身，比例與垂直間隙見常數註解。
    final columnWidth = constraints.maxWidth / _destinations.length;
    final restIndicator = _RestIndicatorGeometry(
      width: columnWidth * _restIndicatorWidthRatio,
      height:
          TpRootTabGeometry.expandedBarHeight - _restIndicatorVerticalInset * 2,
      // 字符是 `Column` 的第一個孩子、標籤在下面；膠囊要與整組同心，就得從
      // 字符中心再往下挪半個「間距 + 標籤高」。
      dropBelowIcon:
          (_iconLabelSpacing +
              _measureLabelHeight(context, selectedLabelStyle)) /
          2,
      color: indicatorColor,
    );
    final tabs = [
      for (final destination in _destinations)
        GlassTab(
          // 兩態同一個實心字符，由 tint 區分選取；選取層是另一份 widget，
          // key 必須各自唯一，否則 finder 會抓到兩個。
          icon: Icon(
            destination.icon,
            key: ValueKey('root-tab-${destination.label}'),
          ),
          // 選取層的字符連膠囊一起畫。膠囊只能長在這裡 —— 套件把選取態內容
          // 疊在自己的指示器**之上**，外部塞不進中間那一層；長在字符底下才
          // 會被標籤與字符蓋住，而不是反過來蓋掉它們。
          activeIcon: _SelectedTabIcon(
            geometry: restIndicator,
            pillKey: ValueKey('root-tab-pill-${destination.label}'),
            icon: Icon(
              destination.icon,
              key: ValueKey('root-tab-active-${destination.label}'),
            ),
          ),
          label: destination.label,
          semanticLabel: destination.label,
          glowColor: theme.colorScheme.primary,
        ),
    ];
    final tabBar = inline
        ? GlassTabBar.inline(
            tabs: tabs,
            selectedIndex: selectedIndex,
            onTabSelected: onSelected,
            barHeight: 64,
            barBorderRadius: 32,
            iconSize: 24,
            horizontalPadding: 0,
            verticalPadding: 0,
            // 見 `_tabPadding`：字符／標籤那排與選取膠囊分屬兩個基準。
            tabPadding: _tabPadding,
            settings: glassSettings,
            // 品牌 tint 上在字符與標籤；未選兩者同色，靠「沒有膠囊」與
            // 「不是 tint」區分，不靠把字符調暗（先前字符中灰、標籤近白，
            // 同一顆 tab 內不一致）。
            selectedIconColor: theme.colorScheme.primary,
            selectedLabelColor: theme.colorScheme.primary,
            unselectedIconColor: theme.colorScheme.onSurface,
            unselectedLabelColor: theme.colorScheme.onSurface,
            selectedLabelStyle: selectedLabelStyle,
            unselectedLabelStyle: unselectedLabelStyle,
            // 套件靜止態的指示器是**整格欄位**，任何參數都收不動它（#179），
            // 所以讓它不上色、由 `_SelectedTabIcon` 自畫。這裡設透明不會關掉
            // 拖曳中的玻璃透鏡 —— 透鏡吃的是 `indicatorSettings`。
            indicatorColor: Colors.transparent,
            indicatorSettings: indicatorSettings,
            // 見 `_indicatorExpansion`：這條**只管拖曳中**的透鏡幾何。
            indicatorExpansion: _indicatorExpansion,
            magnification: 1,
            blendAmount: 4,
            glowOpacity: 0.18,
            quality: GlassQuality.premium,
            platformViewBackdrop: selectedIndex == 2,
          )
        : GlassTabBar.bottom(
            tabs: tabs,
            selectedIndex: selectedIndex,
            onTabSelected: onSelected,
            horizontalPadding: 0,
            verticalPadding: 0,
            // 見 `_tabPadding`：字符／標籤那排與選取膠囊分屬兩個基準。
            tabPadding: _tabPadding,
            settings: glassSettings,
            // 品牌 tint 上在字符與標籤；未選兩者同色，靠「沒有膠囊」與
            // 「不是 tint」區分，不靠把字符調暗（先前字符中灰、標籤近白，
            // 同一顆 tab 內不一致）。
            selectedIconColor: theme.colorScheme.primary,
            selectedLabelColor: theme.colorScheme.primary,
            unselectedIconColor: theme.colorScheme.onSurface,
            unselectedLabelColor: theme.colorScheme.onSurface,
            selectedLabelStyle: selectedLabelStyle,
            unselectedLabelStyle: unselectedLabelStyle,
            // 套件靜止態的指示器是**整格欄位**，任何參數都收不動它（#179），
            // 所以讓它不上色、由 `_SelectedTabIcon` 自畫。這裡設透明不會關掉
            // 拖曳中的玻璃透鏡 —— 透鏡吃的是 `indicatorSettings`。
            indicatorColor: Colors.transparent,
            indicatorSettings: indicatorSettings,
            // 見 `_indicatorExpansion`：這條**只管拖曳中**的透鏡幾何。
            indicatorExpansion: _indicatorExpansion,
            magnification: 1,
            blendAmount: 4,
            glowOpacity: 0.18,
            quality: GlassQuality.premium,
            platformViewBackdrop: selectedIndex == 2,
          );
    if (!inline) return tabBar;
    return Stack(
      children: [
        ExcludeSemantics(child: tabBar),
        Positioned.fill(
          child: Row(
            children: [
              for (var index = 0; index < _destinations.length; index++)
                Expanded(
                  child: Semantics(
                    label: _destinations[index].label,
                    selected: index == selectedIndex,
                    button: true,
                    onTap: () => onSelected(index),
                    child: ExcludeSemantics(
                      child: TextButton(
                        key: ValueKey(
                          'regular-root-tab-${_destinations[index].label}',
                        ),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(44, 44),
                          padding: EdgeInsets.zero,
                          shape: const StadiumBorder(),
                        ),
                        focusNode: focusNodes?[index],
                        onPressed: () => onSelected(index),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 靜止態選取膠囊的幾何與填色。
class _RestIndicatorGeometry {
  const _RestIndicatorGeometry({
    required this.width,
    required this.height,
    required this.dropBelowIcon,
    required this.color,
  });

  final double width;
  final double height;

  /// 膠囊中心相對於字符中心要往下挪多少，才會與「字符 + 標籤」整組同心。
  final double dropBelowIcon;
  final Color color;
}

/// 選取態的字符，底下疊一顆自畫的膠囊。
///
/// 膠囊超出字符的方框往外畫 —— 沿路的 `Stack`（本層與
/// `BottomBarTabItem` 的字符層）都是 `Clip.none`，`FittedBox` 預設也不裁，
/// 所以溢出的部分照樣畫得出來；能真正裁到它的只有套件選取層的
/// `JellyClipper`，而膠囊比那個範圍小（見 `_restIndicatorVerticalInset`）。
class _SelectedTabIcon extends StatelessWidget {
  const _SelectedTabIcon({
    required this.geometry,
    required this.pillKey,
    required this.icon,
  });

  final _RestIndicatorGeometry geometry;
  final Key pillKey;
  final Widget icon;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 先畫膠囊、再畫字符，標籤由套件在更外層的 `Column` 之後畫 ——
        // 三者的疊放順序就是「膠囊在最底下」。
        Positioned.fill(
          child: Center(
            child: Transform.translate(
              offset: Offset(0, geometry.dropBelowIcon),
              child: OverflowBox(
                minWidth: geometry.width,
                maxWidth: geometry.width,
                minHeight: geometry.height,
                maxHeight: geometry.height,
                child: DecoratedBox(
                  key: pillKey,
                  decoration: ShapeDecoration(
                    color: geometry.color,
                    // 純圓弧膠囊，不是 squircle —— Apple 的 pill 兩端是正圓，
                    // 套件 0.23.0 也已經把指示器改成 `LiquidRoundedRectangle`。
                    shape: LiquidRoundedRectangle(
                      borderRadius: geometry.height / 2,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        icon,
      ],
    );
  }
}

/// 量套件實際會畫出來的標籤高度。
double _measureLabelHeight(
  BuildContext context,
  TextStyle? selectedLabelStyle,
) {
  final painter = TextPainter(
    // 單行高度與字串內容無關，取任一個標籤即可。
    text: TextSpan(
      text: '行程',
      style: _packageLabelBaseStyle.merge(selectedLabelStyle),
    ),
    textScaler: MediaQuery.textScalerOf(context),
    textDirection: Directionality.of(context),
    maxLines: 1,
  )..layout();
  return painter.height;
}
