import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../theme/tokens.dart';
import 'tp_glass_surface.dart';
import 'tp_more_menu.dart';

export 'tp_more_menu.dart';
export 'tp_glass_surface.dart'
    show TpHeaderTitle, TpToolbarActionGroup, TpToolbarGlassButton;

enum TpAppBarRole { standalone, detail, publicDetail, modalContent, modalForm }

/// The single spacing owner for one or more compact header actions.
/// 固定 bar 與浮動 header(tp_root_scaffold)共用的動作列;只給這兩個檔用。
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

/// 群組容器把更多選單包起來後，`action is TpMoreMenuButton` 的直接型別判斷
/// 就不成立了，改用這個會遞迴進群組的判斷。
bool tpActionsIncludeMoreMenu(Iterable<Widget> actions) => actions.any(
  (action) =>
      action is TpMoreMenuButton ||
      (action is TpToolbarActionGroup &&
          tpActionsIncludeMoreMenu(action.children)),
);

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
    return TpNavigationGlassButton(
      key: const ValueKey('account-avatar-button'),
      role: TpNavigationGlassButtonRole.barButton,
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
    final barActions = <Widget>[
      ...headerActions,
      if (largeSheetScope != null && role != TpAppBarRole.modalForm)
        KeyedSubtree(
          key: const ValueKey('app-sheet-close'),
          child: TpToolbarGlassButton(
            key: const ValueKey('app-large-sheet-close'),
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            onPressed: () => unawaited(largeSheetScope.requestClose(context)),
            child: Icon(
              CupertinoIcons.xmark,
              size: 19,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
    ];
    // 公開 bar 會量測 leading 與 actions 的自然寬度，並替置中標題避讓。
    // App 只保留角色、sheet 導航和動作順序，不再反推兩側 slot 寬度。
    return GlassAppBar(
      toolbarHeight: preferredSize.height,
      padding: const EdgeInsets.symmetric(horizontal: TpSpacing.s4),
      backgroundColor: largeSheetScope != null
          ? Colors.transparent
          : Theme.of(context).scaffoldBackgroundColor,
      centerTitle: largeSheetScope != null,
      leading: leadingAction == null
          ? null
          : KeyedSubtree(
              key: const ValueKey('tp-app-bar-leading'),
              child: KeyedSubtree(
                key: largeSheetScope != null
                    ? const ValueKey('app-large-sheet-back')
                    : null,
                child: leadingAction,
              ),
            ),
      title: TpHeaderTitle(
        key: const ValueKey('tp-app-bar-title'),
        child: title,
      ),
      actions: [
        if (barActions.isNotEmpty)
          KeyedSubtree(
            key: const ValueKey('tp-app-bar-actions'),
            child: TpHeaderActionRow(children: barActions),
          ),
      ],
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
          child: Icon(
            CupertinoIcons.back,
            size: 22,
            color: largeSheetScope == null
                ? null
                : Theme.of(context).colorScheme.primary,
          ),
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
