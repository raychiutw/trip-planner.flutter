import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../theme/app_theme.dart';
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
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const _destinations = [
    (
      label: '聊天',
      icon: CupertinoIcons.chat_bubble,
      selectedIcon: CupertinoIcons.chat_bubble_fill,
    ),
    (
      label: '行程',
      icon: CupertinoIcons.house,
      selectedIcon: CupertinoIcons.house_fill,
    ),
    (
      label: '地圖',
      icon: CupertinoIcons.map,
      selectedIcon: CupertinoIcons.map_fill,
    ),
    (
      label: '收藏',
      icon: CupertinoIcons.heart,
      selectedIcon: CupertinoIcons.heart_fill,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tones = theme.extension<TpTones>()!;
    final isDark = theme.brightness == Brightness.dark;
    final glassSettings = tpNavigationGlassSettings(context);
    final selectionTint = isDark
        ? TpColorsDark.navigationSelection
        : TpColorsLight.navigationSelection;
    return KeyedSubtree(
      key: const ValueKey('apple-root-tab-bar'),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          TpRootTabGeometry.horizontalMargin,
          0,
          TpRootTabGeometry.horizontalMargin,
          TpRootTabGeometry.bottomOffset(context),
        ),
        child: GlassTabBar.bottom(
          tabs: [
            for (final destination in _destinations)
              GlassTab(
                icon: Icon(
                  destination.icon,
                  key: ValueKey('root-tab-${destination.label}'),
                ),
                activeIcon: Icon(
                  destination.selectedIcon,
                  key: ValueKey('root-tab-${destination.label}'),
                ),
                label: destination.label,
                semanticLabel: destination.label,
                glowColor: tones.accentDeep,
              ),
          ],
          selectedIndex: selectedIndex,
          onTabSelected: onSelected,
          horizontalPadding: 0,
          verticalPadding: 0,
          barHeight: TpRootTabGeometry.expandedBarHeight,
          barBorderRadius: 22,
          indicatorBorderRadius: 17,
          indicatorExpansion: EdgeInsets.zero,
          tabPadding: const EdgeInsets.symmetric(horizontal: 2),
          spacing: 0,
          iconSize: 20,
          iconLabelSpacing: 0,
          labelFontSize: 11,
          settings: glassSettings,
          selectedIconColor: tones.accentDeep,
          selectedLabelColor: tones.accentDeep,
          unselectedIconColor: theme.colorScheme.onSurfaceVariant,
          unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
          selectedLabelStyle: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w500,
          ),
          indicatorColor: selectionTint,
          indicatorSettings: glassSettings.copyWith(
            glassColor: selectionTint,
            platformViewFallbackColor: selectionTint,
          ),
          magnification: 1,
          blendAmount: 4,
          glowOpacity: 0.18,
          quality: GlassQuality.standard,
          platformViewBackdrop: selectedIndex == 2,
        ),
      ),
    );
  }
}
