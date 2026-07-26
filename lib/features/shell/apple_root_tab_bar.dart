import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sficon/flutter_sficon.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../theme/tokens.dart';
import '../../ui/tp_glass_surface.dart';

/// Root tab bar：固定尺寸、恆顯 label。
///
/// 刻意不做 iOS 26 的 tab bar minimize —— Apple 的 minimize 語意綁定「tab bar
/// 底下是可捲動內容」，本 app 多數 root 畫面底下是固定版面，縮放只會讓導覽跳動。
/// 選取膠囊相對於欄位的內縮量。
///
/// 套件預設是往外擴 12pt；我們往內收，讓膠囊緊貼字符與標籤、左右留出明顯
/// 間隙（對齊 iOS 26 tab bar 約 70% 欄寬的比例）。
const _indicatorExpansion = EdgeInsets.symmetric(horizontal: -14, vertical: -2);

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
    (label: '行程', icon: SFIcons.sf_suitcase_fill),
    (label: '地圖', icon: CupertinoIcons.map_fill),
    (label: '收藏', icon: CupertinoIcons.heart_fill),
  ];

  @override
  Widget build(BuildContext context) {
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
    final tabs = [
      for (final destination in _destinations)
        GlassTab(
          // 兩態同一個實心字符，由 tint 區分選取；選取層是另一份 widget，
          // key 必須各自唯一，否則 finder 會抓到兩個。
          icon: Icon(
            destination.icon,
            key: ValueKey('root-tab-${destination.label}'),
          ),
          activeIcon: Icon(
            destination.icon,
            key: ValueKey('root-tab-active-${destination.label}'),
          ),
          label: destination.label,
          semanticLabel: destination.label,
          glowColor: theme.colorScheme.primary,
        ),
    ];
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
            indicatorColor: indicatorColor,
            indicatorSettings: indicatorSettings,
            // 套件預設是 `horizontal: 12`，指示器往兩側各外擴 12pt，膠囊因此
            // 比自己的欄位還寬（實測欄寬 275px、膠囊 341px = 124%），壓到
            // 左右鄰居。Apple 約 70%，所以改成往內收。
            indicatorExpansion: _indicatorExpansion,
            magnification: 1,
            blendAmount: 4,
            glowOpacity: 0.18,
            quality: GlassQuality.standard,
            platformViewBackdrop: selectedIndex == 2,
          )
        : GlassTabBar.bottom(
            tabs: tabs,
            selectedIndex: selectedIndex,
            onTabSelected: onSelected,
            horizontalPadding: 0,
            verticalPadding: 0,
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
            indicatorColor: indicatorColor,
            indicatorSettings: indicatorSettings,
            // 套件預設是 `horizontal: 12`，指示器往兩側各外擴 12pt，膠囊因此
            // 比自己的欄位還寬（實測欄寬 275px、膠囊 341px = 124%），壓到
            // 左右鄰居。Apple 約 70%，所以改成往內收。
            indicatorExpansion: _indicatorExpansion,
            magnification: 1,
            blendAmount: 4,
            glowOpacity: 0.18,
            quality: GlassQuality.standard,
            platformViewBackdrop: selectedIndex == 2,
          );
    return KeyedSubtree(
      key: const ValueKey('apple-root-tab-bar'),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          TpRootTabGeometry.horizontalMargin,
          0,
          TpRootTabGeometry.horizontalMargin,
          inline ? TpSpacing.s2 : TpRootTabGeometry.bottomOffset(context),
        ),
        child: inline
            ? Stack(
                children: [
                  ExcludeSemantics(child: tabBar),
                  Positioned.fill(
                    child: Row(
                      children: [
                        for (
                          var index = 0;
                          index < _destinations.length;
                          index++
                        )
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
              )
            : tabBar,
      ),
    );
  }
}
