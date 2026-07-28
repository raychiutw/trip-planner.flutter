import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../theme/tokens.dart';
import 'tp_action_item.dart';
import 'tp_glass_surface.dart';

enum TpAppBarRole { standalone, detail, publicDetail, modalContent, modalForm }

/// The single typography owner for titles rendered inside compact headers.
class TpHeaderTitle extends StatelessWidget {
  const TpHeaderTitle({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => DefaultTextStyle.merge(
    style: Theme.of(context).textTheme.headlineSmall,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    child: child,
  );
}

/// The single spacing owner for one or more compact header actions.
class TpHeaderActionRow extends StatelessWidget {
  const TpHeaderActionRow({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    mainAxisAlignment: MainAxisAlignment.end,
    spacing: TpSpacing.s2,
    children: children,
  );
}

class TpToolbarTextButton extends StatelessWidget {
  const TpToolbarTextButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.prominent = false,
  });

  final String label;
  final VoidCallback? onPressed;

  /// 主要動作（儲存、完成）分離並著色。HIG 要求著色在**底色**而不是字符，
  /// 一列只能有一個，且置於尾端。
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: TpSpacing.tapMin,
        minHeight: TpSpacing.tapMin,
      ),
      child: TextButton(
        style: TextButton.styleFrom(
          minimumSize: const Size(TpSpacing.tapMin, TpSpacing.tapMin),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          backgroundColor: prominent ? scheme.primary : null,
          foregroundColor: prominent ? scheme.onPrimary : null,
          disabledBackgroundColor: prominent
              ? scheme.onSurface.withValues(alpha: 0.12)
              : null,
          shape: prominent ? const StadiumBorder() : null,
        ),
        onPressed: onPressed,
        child: Text(label, maxLines: 1),
      ),
    );
  }
}

/// 標記「目前在群組容器裡」，讓子按鈕不要再各自畫一片玻璃。
class _TpToolbarGroupScope extends InheritedWidget {
  const _TpToolbarGroupScope({required super.child});

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_TpToolbarGroupScope>() !=
      null;

  @override
  bool updateShouldNotify(_TpToolbarGroupScope oldWidget) => false;
}

/// 一列上相關的動作收在同一片玻璃裡，彼此只有間距。
///
/// **不畫分隔線** —— HIG Toolbars 只提間距（SwiftUI 也只有 `ToolbarSpacer`）；
/// 分隔線是選單語彙，選單內部的分組分隔線是另一回事，仍然正確。
/// 不相關的動作各自成一顆容器，一列最多約三組。
class TpToolbarActionGroup extends StatelessWidget {
  const TpToolbarActionGroup({super.key, required this.children})
    : assert(children.length >= 2, '單一動作不需要群組容器');

  final List<Widget> children;

  /// 群組內按鈕之間的間距，比群組與群組之間更窄。
  static const innerGap = TpSpacing.s1;

  static double widthFor(int count) =>
      count * TpSpacing.tapMin + (count - 1) * innerGap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widthFor(children.length),
      height: TpSpacing.tapMin,
      child: GlassContainer(
        key: const ValueKey('tp-toolbar-action-group'),
        useOwnLayer: true,
        quality: GlassQuality.premium,
        clipBehavior: Clip.antiAlias,
        shape: LiquidRoundedSuperellipse(
          borderRadius: 22,
          // 邊緣交還材質；只有提高對比才補實心邊。
          side: BorderSide(color: tpGlassEdgeColor(context)),
        ),
        settings: tpNavigationGlassSettings(context),
        child: _TpToolbarGroupScope(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var index = 0; index < children.length; index++) ...[
                if (index > 0) const SizedBox(width: innerGap),
                SizedBox.square(
                  dimension: TpSpacing.tapMin,
                  child: children[index],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 群組容器把更多選單包起來後，`action is TpMoreMenuButton` 的直接型別判斷
/// 就不成立了，改用這個會遞迴進群組的判斷。
bool tpActionsIncludeMoreMenu(Iterable<Widget> actions) => actions.any(
  (action) =>
      action is TpMoreMenuButton ||
      (action is TpToolbarActionGroup &&
          tpActionsIncludeMoreMenu(action.children)),
);

/// Header 共用的 44pt 圓形套件 Liquid Glass 按鈕。
class TpToolbarGlassButton extends StatelessWidget {
  const TpToolbarGlassButton({
    super.key,
    required this.tooltip,
    required this.onPressed,
    required this.child,
    this.platformViewBackdrop = false,
    this.glassSettings,
    this.rimColor,
  });

  final String tooltip;
  final VoidCallback? onPressed;
  final Widget child;
  final bool platformViewBackdrop;
  final LiquidGlassSettings? glassSettings;
  final Color? rimColor;

  @override
  Widget build(BuildContext context) {
    // 群組容器已經提供整片玻璃，這裡再畫一片就會玻璃疊玻璃。
    if (_TpToolbarGroupScope.of(context)) {
      return SizedBox.square(
        dimension: TpSpacing.tapMin,
        child: Tooltip(
          message: tooltip,
          excludeFromSemantics: true,
          child: Semantics(
            button: true,
            enabled: onPressed != null,
            label: tooltip,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onPressed,
              child: Center(child: child),
            ),
          ),
        ),
      );
    }
    final resolvedSettings = glassSettings == null
        ? tpNavigationGlassSettings(context)
        : tpResolveGlassSettings(context, glassSettings!);
    return SizedBox.square(
      dimension: TpSpacing.tapMin,
      child: Tooltip(
        message: tooltip,
        excludeFromSemantics: true,
        child: GlassButton.custom(
          key: const ValueKey('tp-toolbar-glass-button'),
          label: tooltip,
          width: TpSpacing.tapMin,
          height: TpSpacing.tapMin,
          enabled: onPressed != null,
          onTap: onPressed ?? () {},
          useOwnLayer: true,
          quality: GlassQuality.premium,
          platformViewBackdrop: platformViewBackdrop,
          interactionScale: 1.03,
          stretch: 0.12,
          shape: LiquidRoundedSuperellipse(
            borderRadius: 22,
            // 可覆寫的預設值：改預設運算式即可，呼叫端不需修改。
            side: BorderSide(color: rimColor ?? tpGlassEdgeColor(context)),
          ),
          settings: resolvedSettings,
          child: child,
        ),
      ),
    );
  }
}

/// 將開啟帳號 sheet 的動作提供給 App 內容頁 Header。
class TpAccountActionScope extends InheritedWidget {
  const TpAccountActionScope({
    super.key,
    required this.onOpen,
    required super.child,
  });

  final ValueChanged<BuildContext> onOpen;

  /// 取得最近一層提供的帳號開啟動作。
  static ValueChanged<BuildContext>? maybeOpenOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<TpAccountActionScope>()
          ?.onOpen;

  @override
  bool updateShouldNotify(TpAccountActionScope oldWidget) =>
      onOpen != oldWidget.onOpen;
}

/// 帳號入口的 44pt 玻璃按鈕：浮動 header 固定提供，
/// shell 外沒有 root tab bar 的路由改以 `TpAppBar.accountEntry` 明文提供。
class TpAccountAvatarButton extends StatelessWidget {
  const TpAccountAvatarButton({super.key, this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final openAccount = TpAccountActionScope.maybeOpenOf(context);
    return TpToolbarGlassButton(
      key: const ValueKey('account-avatar-button'),
      tooltip: '帳號',
      onPressed:
          onPressed ??
          (openAccount == null ? null : () => openAccount(context)),
      child: const Icon(CupertinoIcons.person_crop_circle, size: 22),
    );
  }
}

/// Marks routes that are pushed inside the near-full-height sheet navigator.
class TpLargeSheetNavigationScope extends InheritedWidget {
  const TpLargeSheetNavigationScope({
    super.key,
    required this.onClose,
    required super.child,
  });

  final VoidCallback onClose;

  static TpLargeSheetNavigationScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TpLargeSheetNavigationScope>();

  /// Close 可直接離開乾淨的 sheet；若目前 route 有 PopScope guard，
  /// 先交給 route 顯示未儲存確認，不可繞過後直接 pop root dialog。
  Future<void> requestClose(BuildContext context) async {
    final route = ModalRoute.of(context);
    if (route?.popDisposition == RoutePopDisposition.doNotPop) {
      await Navigator.of(context).maybePop();
      return;
    }
    onClose();
  }

  @override
  bool updateShouldNotify(TpLargeSheetNavigationScope oldWidget) => false;
}

/// Pops the current nested route, or closes its owning near-full-height sheet
/// when the nested navigator is already at its root page.
Future<void> closeAppRouteOrSheet(BuildContext context) async {
  final navigator = Navigator.of(context);
  if (await navigator.maybePop()) return;
  if (!context.mounted) return;
  TpLargeSheetNavigationScope.maybeOf(context)?.onClose();
}

abstract final class TpToolbarSlots {
  static double textActionWidth(
    BuildContext context,
    TpToolbarTextButton action,
  ) {
    final textStyle = Theme.of(context).textTheme.labelLarge;
    final painter = TextPainter(
      text: TextSpan(text: action.label, style: textStyle),
      maxLines: 1,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final intrinsicWidth = painter.width + 20;
    return intrinsicWidth < TpSpacing.tapMin
        ? TpSpacing.tapMin
        : intrinsicWidth;
  }

  static double sideWidth({
    required int actionCount,
    required bool hasLeading,
  }) {
    final slotCount = actionCount > (hasLeading ? 1 : 0)
        ? actionCount
        : (hasLeading ? 1 : 0);
    if (slotCount == 0) return 0;
    return slotCount * TpSpacing.tapMin + (slotCount - 1) * TpSpacing.s2;
  }

  static Widget? leading({required double width, Widget? action}) {
    if (width == 0) return null;
    return SizedBox(
      width: width,
      child: Align(alignment: Alignment.centerLeft, child: action),
    );
  }

  /// 群組容器佔一個 slot，但寬度是它包住的按鈕數量。
  static double slotWidth(BuildContext context, Widget child) =>
      switch (child) {
        TpToolbarTextButton() => textActionWidth(context, child),
        TpToolbarActionGroup() => TpToolbarActionGroup.widthFor(
          child.children.length,
        ),
        _ => TpSpacing.tapMin,
      };

  static double actionsWidth(BuildContext context, List<Widget> children) {
    if (children.isEmpty) return 0;
    return children.fold<double>(
          0,
          (width, child) => width + slotWidth(context, child),
        ) +
        (children.length - 1) * TpSpacing.s2;
  }

  static List<Widget> actions({
    required BuildContext context,
    required double width,
    required List<Widget> children,
  }) {
    if (width == 0) return const [];
    return [
      SizedBox(
        width: width,
        child: TpHeaderActionRow(
          children: [
            for (final child in children)
              if (child is TpToolbarTextButton)
                SizedBox(width: textActionWidth(context, child), child: child)
              else if (child is TpToolbarActionGroup)
                SizedBox(
                  width: TpToolbarActionGroup.widthFor(child.children.length),
                  child: child,
                )
              else
                SizedBox.square(dimension: TpSpacing.tapMin, child: child),
          ],
        ),
      ),
    ];
  }
}

class TpSheetHeader extends StatelessWidget {
  const TpSheetHeader({
    super.key,
    required this.title,
    this.titleKey,
    this.leading,
    this.trailing,
  });

  final String title;
  final Key? titleKey;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 88),
            child: TpHeaderTitle(key: titleKey, child: Text(title)),
          ),
          if (leading != null) Positioned(left: TpSpacing.s4, child: leading!),
          if (trailing != null)
            Positioned(right: TpSpacing.s4, child: trailing!),
        ],
      ),
    );
  }
}

class TpAppBar extends StatelessWidget implements PreferredSizeWidget {
  const TpAppBar({
    super.key,
    required this.title,
    required this.role,
    this.actions = const [],
    this.accountEntry,
    this.onBack,
    this.onCancel,
    this.primaryActionLabel,
    this.primaryActionKey,
    this.onPrimaryAction,
    this.primaryActionEnabled = true,
  }) : assert(
         role != TpAppBarRole.modalForm ||
             (onCancel != null &&
                 primaryActionLabel != null &&
                 onPrimaryAction != null),
         'modalForm requires Cancel and a primary action.',
       ),
       assert(
         (primaryActionLabel == null) == (onPrimaryAction == null),
         'primaryActionLabel and onPrimaryAction must be supplied together.',
       );

  final Widget title;
  final TpAppBarRole role;
  final List<Widget> actions;

  /// 帳號入口自成一組，不屬於本頁動作，因此不佔內容 Header 的動作額度。
  /// 只有 shell 外、沒有 root tab bar 的路由需要明文提供。
  final Widget? accountEntry;
  final VoidCallback? onBack;
  final VoidCallback? onCancel;
  final String? primaryActionLabel;
  final Key? primaryActionKey;
  final VoidCallback? onPrimaryAction;
  final bool primaryActionEnabled;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final largeSheetScope = TpLargeSheetNavigationScope.maybeOf(context);
    final leadingAction = _semanticLeading(context, largeSheetScope);
    // 內容 Header（固定 bar 的 detail 角色）只給一個直接動作，其餘進更多選單。
    final isContentHeader =
        largeSheetScope == null && role == TpAppBarRole.detail;
    assert(
      !actions.any((action) => action is TpAccountAvatarButton),
      'Account entry belongs in accountEntry, not actions.',
    );
    final pageActions = <Widget>[
      ...actions,
      if (primaryActionLabel != null)
        TpToolbarTextButton(
          key: primaryActionKey ?? const ValueKey('tp-app-bar-primary-action'),
          label: primaryActionLabel!,
          onPressed: primaryActionEnabled ? onPrimaryAction : null,
          prominent: true,
        ),
    ];
    assert(
      !isContentHeader ||
          (pageActions.length <= 2 &&
              (pageActions.length <= 1 ||
                  tpActionsIncludeMoreMenu(pageActions))),
      'Content headers support one direct action; extra actions use More.',
    );
    // 帳號入口在額度計算之後才併入，位置固定在最右側。
    final headerActions = <Widget>[...pageActions, ?accountEntry];
    final leadingWidth = leadingAction == null
        ? 0.0
        : role == TpAppBarRole.modalForm
        ? TpToolbarSlots.textActionWidth(
            context,
            leadingAction as TpToolbarTextButton,
          )
        : TpSpacing.tapMin;
    final actionsWidth = TpToolbarSlots.actionsWidth(context, headerActions);
    if (largeSheetScope != null) {
      final colors = Theme.of(context).colorScheme;
      final showsScopeClose = role != TpAppBarRole.modalForm;
      final sheetActionWidths = <double>[
        for (final action in actions)
          action is TpToolbarTextButton
              ? TpToolbarSlots.textActionWidth(context, action)
              : TpSpacing.tapMin,
        if (primaryActionLabel != null)
          TpToolbarSlots.textActionWidth(
            context,
            pageActions.last as TpToolbarTextButton,
          ),
        if (accountEntry != null) TpSpacing.tapMin,
        if (showsScopeClose) TpSpacing.tapMin,
      ];
      final sheetActionsWidth = sheetActionWidths.isEmpty
          ? 0.0
          : sheetActionWidths.reduce((sum, width) => sum + width) +
                (sheetActionWidths.length - 1) * TpSpacing.s2;
      return GlassAppBar(
        preferredSize: preferredSize,
        backgroundColor: Colors.transparent,
        centerTitle: true,
        leading: SizedBox(
          width: sheetActionsWidth + TpSpacing.s4,
          child: Padding(
            padding: const EdgeInsets.only(left: TpSpacing.s4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: leadingAction == null
                  ? null
                  : SizedBox(
                      key: const ValueKey('app-large-sheet-back'),
                      width: leadingWidth,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: IconTheme(
                          data: IconThemeData(color: colors.primary),
                          child: leadingAction,
                        ),
                      ),
                    ),
            ),
          ),
        ),
        title: TpHeaderTitle(
          key: const ValueKey('tp-app-bar-title'),
          child: title,
        ),
        actions: [
          SizedBox(
            width: sheetActionsWidth + TpSpacing.s4,
            child: Padding(
              padding: const EdgeInsets.only(right: TpSpacing.s4),
              child: TpHeaderActionRow(
                children: [
                  ...headerActions,
                  if (showsScopeClose)
                    KeyedSubtree(
                      key: const ValueKey('app-sheet-close'),
                      child: TpToolbarGlassButton(
                        key: const ValueKey('app-large-sheet-close'),
                        tooltip: MaterialLocalizations.of(
                          context,
                        ).closeButtonTooltip,
                        onPressed: () =>
                            unawaited(largeSheetScope.requestClose(context)),
                        child: Icon(
                          CupertinoIcons.xmark,
                          size: 19,
                          color: colors.primary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      );
    }
    return GlassAppBar(
      preferredSize: preferredSize,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      centerTitle: false,
      leading: TpToolbarSlots.leading(
        width: leadingWidth,
        action: leadingAction,
      ),
      title: TpHeaderTitle(
        key: const ValueKey('tp-app-bar-title'),
        child: title,
      ),
      actions: primaryActionLabel == null
          ? TpToolbarSlots.actions(
              context: context,
              width: actionsWidth,
              children: headerActions,
            )
          : headerActions,
    );
  }

  Widget? _semanticLeading(
    BuildContext context,
    TpLargeSheetNavigationScope? largeSheetScope,
  ) {
    switch (role) {
      case TpAppBarRole.standalone:
        return null;
      case TpAppBarRole.detail:
      case TpAppBarRole.publicDetail:
        return TpToolbarGlassButton(
          key: const ValueKey('tp-app-bar-back'),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: onBack ?? () => closeAppRouteOrSheet(context),
          child: const Icon(CupertinoIcons.back, size: 22),
        );
      case TpAppBarRole.modalContent:
        if (largeSheetScope != null) return null;
        return TpToolbarGlassButton(
          key: const ValueKey('tp-app-bar-close'),
          tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Icon(CupertinoIcons.xmark, size: 19),
        );
      case TpAppBarRole.modalForm:
        return TpToolbarTextButton(
          key: const ValueKey('tp-app-bar-cancel'),
          label: '取消',
          onPressed: onCancel,
        );
    }
  }
}

/// 需要由父元件（例如 PopupMenuButton）處理點擊時使用的共用 44pt glass 表面。
class TpToolbarActionSurface extends StatelessWidget {
  const TpToolbarActionSurface({super.key, this.icon, this.child})
    : assert(icon != null || child != null),
      assert(icon == null || child == null);

  final IconData? icon;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox.square(
      dimension: TpSpacing.tapMin,
      child: GlassContainer(
        key: const ValueKey('tp-toolbar-action-surface'),
        useOwnLayer: true,
        quality: GlassQuality.premium,
        shape: LiquidRoundedSuperellipse(
          borderRadius: 22,
          side: BorderSide(color: tpGlassEdgeColor(context)),
        ),
        settings: tpNavigationGlassSettings(context),
        child:
            child ?? Icon(icon, size: 20, color: theme.colorScheme.onSurface),
      ),
    );
  }
}

class TpToolbarIconButton extends StatelessWidget {
  const TpToolbarIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.plain = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  /// 已經坐在別人的玻璃裡時設 true —— 例如 root header 把返回鍵與標題併成
  /// 同一顆膠囊。玻璃疊玻璃正是 #162 消滅掉的東西(WWDC25:玻璃不取樣玻璃)。
  final bool plain;

  @override
  Widget build(BuildContext context) {
    if (plain) {
      return Semantics(
        button: true,
        label: tooltip,
        child: SizedBox.square(
          dimension: TpSpacing.tapMin,
          child: IconButton(
            onPressed: onPressed,
            icon: Icon(icon, size: 20),
            padding: EdgeInsets.zero,
            tooltip: tooltip,
          ),
        ),
      );
    }
    return TpToolbarGlassButton(
      tooltip: tooltip,
      onPressed: onPressed,
      child: Icon(icon, size: 20),
    );
  }
}

class TpMoreMenuButton<T> extends StatefulWidget {
  const TpMoreMenuButton({
    super.key,
    required this.items,
    required this.onSelected,
    this.enabled = true,
    this.tooltip = '更多',
    this.triggerChild,
    this.controller,
  });

  final List<TpActionItem<T>> items;
  final ValueChanged<T> onSelected;
  final bool enabled;
  final String tooltip;
  final Widget? triggerChild;

  /// 外部控制器：讓觸發鈕以外的入口（例如長按整張卡片）開**同一份**選單，
  /// 而不是各自組一份。省略時自行建立，行為與過去相同。
  final MenuController? controller;

  @override
  State<TpMoreMenuButton<T>> createState() => _TpMoreMenuButtonState<T>();
}

/// 選單面板的量測基準。
abstract final class _TpMenuMetrics {
  /// leading 字符 + 間距 + 尾端勾選欄位 + 左右內距。
  static const itemChromeWidth = 22.0 + 12 + 18 + 12 + 24 + 24;
  static const minWidth = 200.0;
  static const maxWidth = 320.0;
  static const panelPadding = TpSpacing.s3;
  static const gap = TpSpacing.s2;
}

class _TpMoreMenuButtonState<T> extends State<TpMoreMenuButton<T>> {
  final _ownMenuController = MenuController();

  MenuController get _menuController => widget.controller ?? _ownMenuController;

  /// 選擇的派發時機維持在**項目本身的回呼**。
  ///
  /// 不得移到 overlay 的關閉回呼 —— 框架文件明載 overlay 在 dispose 之後呼叫
  /// hide 是 no-op、不會觸發關閉回呼；時間軸每張卡片都掛一顆觸發鈕，清單重建
  /// 或捲出視窗時會讓點擊靜默消失。
  void _select(T value) {
    _menuController.close();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onSelected(value);
    });
  }

  /// 寬度依最長標籤量測，並保留 min/max 區間 —— 短標籤不撐出空白。
  double _panelWidth(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyLarge;
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    var widest = 0.0;
    for (final item in widget.items) {
      final painter = TextPainter(
        text: TextSpan(text: item.label, style: style),
        textScaler: scaler,
        textDirection: direction,
        maxLines: 1,
      )..layout();
      widest = math.max(widest, painter.width);
    }
    return (widest + _TpMenuMetrics.itemChromeWidth).clamp(
      _TpMenuMetrics.minWidth,
      _TpMenuMetrics.maxWidth,
    );
  }

  /// 估算高度，只用來決定往下展開還是往上翻 —— 往上翻以 `bottom` 定位，
  /// 所以不需要精確值。
  double _estimatedHeight(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final fontSize = Theme.of(context).textTheme.bodyLarge?.fontSize ?? 16;
    final rowHeight = math.max(TpSpacing.tapMin, scaler.scale(fontSize) + 20);
    final dividers = widget.items.where((item) => item.dividerBefore).length;
    return widget.items.length * rowHeight +
        dividers * TpSpacing.s4 +
        _TpMenuMetrics.panelPadding * 2;
  }

  /// 面板走中性語意層 —— 品牌柔褐不再當背景鋪滿。
  LiquidGlassSettings _panelSettings(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tint = theme.colorScheme.surfaceContainerHigh.withValues(
      alpha: isDark ? 0.62 : 0.68,
    );
    return LiquidGlassSettings(
      glassColor: tint,
      thickness: 22,
      blur: 22,
      chromaticAberration: 0,
      lightIntensity: isDark ? 0.62 : 0.72,
      ambientStrength: isDark ? 0.08 : 0.14,
      refractiveIndex: 1.08,
      saturation: 1.02,
      standardOpacityMultiplier: isDark ? 0.64 : 0.52,
      platformViewFallbackColor: theme.colorScheme.surfaceContainerHigh
          .withValues(alpha: isDark ? 0.84 : 0.90),
    );
  }

  @override
  Widget build(BuildContext context) {
    final triggerForeground = Theme.of(context).colorScheme.primary;
    return SizedBox.square(
      dimension: TpSpacing.tapMin,
      child: RawMenuAnchor(
        controller: _menuController,
        useRootOverlay: true,
        consumeOutsideTaps: true,
        overlayBuilder: (_, info) => _buildOverlay(context, info),
        builder: (menuContext, controller, _) => TpToolbarGlassButton(
          tooltip: widget.tooltip,
          onPressed: widget.enabled
              ? () => controller.isOpen ? controller.close() : controller.open()
              : null,
          // 觸發鈕本體與按壓高亮沿用中性導覽玻璃（不再傳品牌褐的 settings 與
          // rimColor）；品牌色只留給字符。
          child:
              widget.triggerChild ??
              Icon(CupertinoIcons.ellipsis, size: 22, color: triggerForeground),
        ),
      ),
    );
  }

  Widget _buildOverlay(BuildContext context, RawMenuOverlayInfo info) {
    final scheme = Theme.of(context).colorScheme;
    final width = _panelWidth(context);
    const gap = _TpMenuMetrics.gap;

    // 下方空間不夠、且上方更寬裕時往上翻。往上翻改以 bottom 定位，因此不需要
    // 事先量到面板的精確高度。
    final spaceBelow = info.overlaySize.height - info.anchorRect.bottom - gap;
    final spaceAbove = info.anchorRect.top - gap;
    final flipUp =
        _estimatedHeight(context) > spaceBelow && spaceAbove > spaceBelow;

    return TapRegion(
      groupId: info.tapRegionGroupId,
      consumeOutsideTaps: true,
      onTapOutside: (_) => _menuController.close(),
      child: Actions(
        actions: <Type, Action<Intent>>{
          DismissIntent: DismissMenuAction(controller: _menuController),
        },
        // 面板開啟時就把焦點收進來，方向鍵才有東西可以走 —— 方向鍵 traversal
        // 本身由框架預設提供，不需要自己再掛一組 shortcuts。
        child: FocusScope(
          autofocus: true,
          child: Stack(
            children: [
              Positioned(
                right: math.max(
                  0,
                  info.overlaySize.width - info.anchorRect.right,
                ),
                top: flipUp ? null : info.anchorRect.bottom + gap,
                bottom: flipUp
                    ? info.overlaySize.height - info.anchorRect.top + gap
                    : null,
                width: width,
                child: _TpMenuPanel(
                  flipUp: flipUp,
                  settings: _panelSettings(context),
                  children: [
                    for (final item in widget.items) ...[
                      if (item.dividerBefore)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Divider(
                            height: TpSpacing.s4,
                            // 選單內部的分組分隔線是選單語彙，HIG 明文允許 ——
                            // 與工具列動作群組不同。
                            color: scheme.onSurface.withValues(alpha: 0.18),
                          ),
                        ),
                      _TpMenuItem<T>(
                        key: item.key,
                        item: item,
                        onSelected: _select,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 面板本體：以錨點為原點 scale 加淡入。
class _TpMenuPanel extends StatefulWidget {
  const _TpMenuPanel({
    required this.flipUp,
    required this.settings,
    required this.children,
  });

  final bool flipUp;
  final LiquidGlassSettings settings;
  final List<Widget> children;

  @override
  State<_TpMenuPanel> createState() => _TpMenuPanelState();
}

class _TpMenuPanelState extends State<_TpMenuPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: TpMotion.normal,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else if (!_controller.isAnimating && _controller.value == 0) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(
      parent: _controller,
      curve: TpMotion.appleEase,
    );
    return ScaleTransition(
      scale: Tween<double>(begin: 0.92, end: 1).animate(curve),
      // 空間不足往上翻時，scale 原點必須跟著改成底部對齊，否則面板會從遠離
      // 觸發鈕的那一端長出來。時間軸卡片是最常觸發往上翻的呼叫點。
      alignment: widget.flipUp ? Alignment.bottomRight : Alignment.topRight,
      // 淡入只包內容，不包玻璃。玻璃被 opacity 包住時引擎會為它開一層
      // saveLayer，面板的兩個 backdrop filter 因此失去直接翻用 onscreen
      // target 的資格 —— 整段 250ms 玻璃讀到的是空背景，到最後一幀才突然
      // 變成毛玻璃。套件作者自己的 `GlassPopover` 也是只淡內容。
      child: TpGlassSurface(
        key: const ValueKey('tp-menu-panel'),
        borderRadius: const BorderRadius.all(Radius.circular(24)),
        padding: const EdgeInsets.all(_TpMenuMetrics.panelPadding),
        glassSettings: widget.settings,
        child: FadeTransition(
          opacity: curve,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: widget.children,
          ),
        ),
      ),
    );
  }
}

/// 選單項目。字符在前、標題在後 —— iOS 26 起系統選單就是這個方位
/// （iOS 18 以前才相反），不要改成靠右。
class _TpMenuItem<T> extends StatelessWidget {
  const _TpMenuItem({super.key, required this.item, required this.onSelected});

  final TpActionItem<T> item;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // 深色模式的項目文字用標籤色，不再是品牌褐。
    final foreground = item.role == TpActionRole.destructive
        ? scheme.error
        : scheme.onSurface;
    return Semantics(
      button: true,
      enabled: item.enabled,
      // 停用原因寫在 semanticLabel，停用時仍要被朗讀。
      label: item.semanticLabel ?? item.label,
      excludeSemantics: true,
      child: TextButton(
        onPressed: item.enabled ? () => onSelected(item.value) : null,
        style: TextButton.styleFrom(
          alignment: AlignmentDirectional.centerStart,
          minimumSize: const Size(0, TpSpacing.tapMin),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          foregroundColor: foreground,
          backgroundColor: Colors.transparent,
          disabledForegroundColor: foreground.withValues(alpha: 0.38),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: theme.textTheme.bodyLarge,
        ),
        child: Row(
          children: [
            Icon(item.icon, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // 選取態保留項目原本的字符，勾選另外顯示在尾端。
            if (item.selected) ...[
              const SizedBox(width: 12),
              const Icon(CupertinoIcons.check_mark, size: 18),
            ],
          ],
        ),
      ),
    );
  }
}
