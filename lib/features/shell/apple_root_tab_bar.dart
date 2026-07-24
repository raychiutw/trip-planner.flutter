import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sficon/flutter_sficon.dart';
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
    this.inline = false,
    this.focusNodes,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool inline;
  final List<FocusNode>? focusNodes;

  static const _destinations = [
    (
      label: '聊天',
      icon: CupertinoIcons.chat_bubble,
      selectedIcon: CupertinoIcons.chat_bubble_fill,
    ),
    (
      label: '行程',
      icon: SFIcons.sf_suitcase,
      selectedIcon: SFIcons.sf_suitcase_fill,
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
    final glassSettings = tpNavigationGlassSettings(
      context,
      recipe: selectedIndex == 2
          ? TpNavigationGlassRecipe.platformView
          : TpNavigationGlassRecipe.regular,
    );
    final selectionTint = isDark
        ? TpColorsDark.navigationSelection
        : TpColorsLight.navigationSelection;
    final tabs = [
      for (final destination in _destinations)
        GlassTab(
          icon: Icon(
            destination.icon,
            key: ValueKey('root-tab-${destination.label}'),
          ),
          activeIcon: Icon(destination.selectedIcon),
          label: destination.label,
          semanticLabel: destination.label,
          glowColor: tones.accentDeep,
        ),
    ];
    final selectedLabelStyle = theme.textTheme.labelSmall?.copyWith(
      fontWeight: FontWeight.w700,
    );
    final unselectedLabelStyle = theme.textTheme.labelSmall?.copyWith(
      fontWeight: FontWeight.w500,
    );
    final indicatorSettings = glassSettings.copyWith(
      glassColor: selectionTint.withValues(alpha: 0.68),
      platformViewFallbackColor: selectionTint.withValues(alpha: 0.68),
    );
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
            selectedIconColor: tones.accentDeep,
            selectedLabelColor: tones.accentDeep,
            unselectedIconColor: theme.colorScheme.onSurfaceVariant,
            unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
            selectedLabelStyle: selectedLabelStyle,
            unselectedLabelStyle: unselectedLabelStyle,
            indicatorColor: selectionTint.withValues(alpha: 0.68),
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
            selectedIconColor: tones.accentDeep,
            selectedLabelColor: tones.accentDeep,
            unselectedIconColor: theme.colorScheme.onSurfaceVariant,
            unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
            selectedLabelStyle: selectedLabelStyle,
            unselectedLabelStyle: unselectedLabelStyle,
            indicatorColor: selectionTint.withValues(alpha: 0.68),
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
