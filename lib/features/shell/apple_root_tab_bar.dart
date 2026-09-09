import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../theme/tokens.dart';
import '../../ui/tp_glass_surface.dart';

/// 四個 root tabs；套件負責選取指示、點選與拖曳。
/// App 只整合品牌前景、媒體背景、無障礙與佔位，不隨捲動縮小。
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

  void _select(int index) {
    onSelected(index);
    // branch 的 Navigator 會先接手焦點；導覽完成後留在使用者剛操作的 tab，
    // 讓下一次 Tab／Shift-Tab 繼續走四個 root tabs。
    final node = focusNodes?[index];
    if (node != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (node.context != null) node.requestFocus();
      });
    }
  }

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
        child: _buildBar(context),
      ),
    );
  }

  Widget _buildBar(BuildContext context) {
    final theme = Theme.of(context);
    // 是不是在媒體背景上,由 root shell 依目前分支宣告,這裡只讀。
    final onMedia = TpMediaBackdropScope.of(context);
    final glassSettings = tpNavigationGlassSettings(
      context,
      recipe: onMedia
          ? TpNavigationGlassRecipe.platformView
          : TpNavigationGlassRecipe.regular,
    );
    final foreground = tpBarForeground(context, onMedia: onMedia);
    // ADR-0004：中性選取表面，品牌 tint 只用於字符與標籤。
    final selectedLabelStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.primary,
      fontWeight: FontWeight.w700,
      fontSize: TpRootTabGeometry.labelFontSize,
      height: TpRootTabGeometry.labelLineHeight,
    );
    final unselectedLabelStyle = theme.textTheme.labelSmall?.copyWith(
      color: foreground,
      fontWeight: FontWeight.w500,
      fontSize: TpRootTabGeometry.labelFontSize,
      height: TpRootTabGeometry.labelLineHeight,
    );
    final indicatorSettings = tpResolveGlassSettings(
      context,
      glassSettings,
      opaqueColor: theme.colorScheme.surfaceContainerHigh,
    );
    final tabs = [
      for (final destination in _destinations)
        GlassTab(
          icon: Icon(destination.icon),
          label: destination.label,
          semanticLabel: destination.label,
        ),
    ];
    final tabBar = inline
        ? GlassTabBar.inline(
            tabs: tabs,
            selectedIndex: selectedIndex,
            onTabSelected: _select,
            barHeight: TpRootTabGeometry.barHeight(context),
            barBorderRadius: 32,
            iconSize: TpRootTabGeometry.iconSize,
            iconLabelSpacing: TpRootTabGeometry.iconLabelSpacing,
            horizontalPadding: 0,
            verticalPadding: 0,
            settings: glassSettings,
            selectedIconColor: theme.colorScheme.primary,
            selectedLabelColor: theme.colorScheme.primary,
            unselectedIconColor: foreground,
            unselectedLabelColor: foreground,
            selectedLabelStyle: selectedLabelStyle,
            unselectedLabelStyle: unselectedLabelStyle,
            indicatorColor: theme.colorScheme.surfaceContainerHigh,
            indicatorSettings: indicatorSettings,
            quality: tpGlassQuality(context),
            platformViewBackdrop: onMedia,
          )
        : GlassTabBar.bottom(
            iconSize: TpRootTabGeometry.iconSize,
            iconLabelSpacing: TpRootTabGeometry.iconLabelSpacing,
            barHeight: TpRootTabGeometry.barHeight(context),
            tabs: tabs,
            selectedIndex: selectedIndex,
            onTabSelected: _select,
            horizontalPadding: 0,
            verticalPadding: 0,
            settings: glassSettings,
            selectedIconColor: theme.colorScheme.primary,
            selectedLabelColor: theme.colorScheme.primary,
            unselectedIconColor: foreground,
            unselectedLabelColor: foreground,
            selectedLabelStyle: selectedLabelStyle,
            unselectedLabelStyle: unselectedLabelStyle,
            indicatorColor: theme.colorScheme.surfaceContainerHigh,
            indicatorSettings: indicatorSettings,
            quality: tpGlassQuality(context),
            platformViewBackdrop: onMedia,
          );
    // 1.4.1 的 tab 內容把 onTap 傳成 null，鍵盤與讀屏啟用沒有回呼。
    // 只補可穿透指標的無障礙區域；點選與拖曳仍由底下的套件處理。
    return Stack(
      children: [
        ExcludeFocus(child: ExcludeSemantics(child: tabBar)),
        Positioned.fill(
          child: Row(
            children: [
              for (var index = 0; index < _destinations.length; index++)
                Expanded(
                  child: Semantics(
                    key: ValueKey(
                      inline
                          ? 'regular-root-tab-${_destinations[index].label}'
                          : 'root-tab-${_destinations[index].label}',
                    ),
                    label: _destinations[index].label,
                    selected: index == selectedIndex,
                    button: true,
                    onTap: () => _select(index),
                    child: IgnorePointer(
                      child: ExcludeSemantics(
                        child: TextButton(
                          style: TextButton.styleFrom(
                            minimumSize: const Size(44, 44),
                            padding: EdgeInsets.zero,
                            shape: const StadiumBorder(),
                          ),
                          focusNode: focusNodes?[index],
                          onPressed: () => _select(index),
                          child: const SizedBox.expand(),
                        ),
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
