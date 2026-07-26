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
    // 這一處是 `CONTEXT.md`「品牌柔褐不鋪成底色」的**明文例外**：root tab 是
    // 全 app 唯一的主導覽，選取指示需要最強的視覺分量。日期選擇器（篩選內容、
    // 不是切換功能）維持中性語意層，兩處刻意不同。
    final selectionTint = theme.colorScheme.primary.withValues(alpha: 0.68);
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
            // 字符坐在柔褐底上要反白；標籤在膠囊之外，維持品牌 tint。
            selectedIconColor: theme.colorScheme.onPrimary,
            selectedLabelColor: theme.colorScheme.primary,
            unselectedIconColor: theme.colorScheme.onSurfaceVariant,
            unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
            selectedLabelStyle: selectedLabelStyle,
            unselectedLabelStyle: unselectedLabelStyle,
            indicatorColor: indicatorColor,
            indicatorSettings: indicatorSettings,
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
            // 字符坐在柔褐底上要反白；標籤在膠囊之外，維持品牌 tint。
            selectedIconColor: theme.colorScheme.onPrimary,
            selectedLabelColor: theme.colorScheme.primary,
            unselectedIconColor: theme.colorScheme.onSurfaceVariant,
            unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
            selectedLabelStyle: selectedLabelStyle,
            unselectedLabelStyle: unselectedLabelStyle,
            indicatorColor: indicatorColor,
            indicatorSettings: indicatorSettings,
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
