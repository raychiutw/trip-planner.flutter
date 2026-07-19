/// 平台自適應 UI helper。
///
/// iOS/macOS 走 Cupertino 慣例、其餘平台走 Material。
/// 用 `Theme.of(context).platform`(而非 defaultTargetPlatform),
/// 方便測試以 `ThemeData(platform: ...)` override。
library;

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../theme/tokens.dart';
import '../ui/tp_action_item.dart';
import '../ui/tp_app_bar.dart';

/// 顯示自適應「確認 / 取消」對話框,回傳使用者是否確認。
///
/// - iOS/macOS → [CupertinoAlertDialog];破壞性操作([isDestructive])用紅字
///   destructive action。
/// - 其餘平台 → Material [AlertDialog];破壞性操作用 error 色 [FilledButton]。
///
/// 使用者關閉(點外部/返回)視同取消,回傳 `false`。
Future<bool> showAppConfirm(
  BuildContext context, {
  required String title,
  String? message,
  required String confirmLabel,
  String cancelLabel = '取消',
  bool isDestructive = false,
}) async {
  final platform = Theme.of(context).platform;
  final isApple =
      platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;

  if (isApple) {
    final result = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(title),
        content: message == null ? null : Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(cancelLabel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: isDestructive,
            isDefaultAction: !isDestructive,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  final scheme = Theme.of(context).colorScheme;
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: message == null ? null : Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          style: isDestructive
              ? FilledButton.styleFrom(
                  backgroundColor: scheme.error,
                  foregroundColor: scheme.onError,
                )
              : null,
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// 顯示自適應動作選單,回傳使用者選擇的動作值(取消回傳 `null`)。
///
/// - iOS/macOS → [CupertinoActionSheet](底部彈出、破壞性紅字、獨立取消鈕)。
/// - 其餘平台 → 附 drag handle 的 Material bottom sheet(ListTile 清單)。
Future<T?> showAppActionSheet<T>(
  BuildContext context, {
  String? title,
  String? message,
  required List<TpActionItem<T>> actions,
  String cancelLabel = '取消',
}) {
  final platform = Theme.of(context).platform;
  final isApple =
      platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;

  if (isApple) {
    return showCupertinoModalPopup<T>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: title == null ? null : Text(title),
        message: message == null ? null : Text(message),
        actions: [
          for (final action in actions)
            if (action.enabled)
              CupertinoActionSheetAction(
                isDestructiveAction: action.role == TpActionRole.destructive,
                onPressed: () => Navigator.of(sheetContext).pop(action.value),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (action.selected) ...[
                      const Icon(CupertinoIcons.check_mark, size: 18),
                      const SizedBox(width: 8),
                    ],
                    Text(action.label),
                  ],
                ),
              )
            else
              Semantics(
                button: true,
                enabled: false,
                label: action.label,
                child: ExcludeSemantics(
                  child: CupertinoActionSheetAction(
                    onPressed: () {},
                    child: Opacity(opacity: 0.45, child: Text(action.label)),
                  ),
                ),
              ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: Text(cancelLabel),
        ),
      ),
    );
  }

  return showModalBottomSheet<T>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      final error = Theme.of(sheetContext).colorScheme.error;
      return SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          children: [
            for (final action in actions) ...[
              if (action.dividerBefore) const Divider(height: 1),
              ListTile(
                key: action.key,
                enabled: action.enabled,
                leading: Icon(
                  action.selected ? CupertinoIcons.check_mark : action.icon,
                  color: action.role == TpActionRole.destructive ? error : null,
                ),
                title: Text(
                  action.label,
                  style: action.role == TpActionRole.destructive
                      ? TextStyle(color: error, fontWeight: FontWeight.w600)
                      : null,
                ),
                onTap: action.enabled
                    ? () => Navigator.of(sheetContext).pop(action.value)
                    : null,
              ),
            ],
          ],
        ),
      );
    },
  );
}

class AppSheetFormController extends ChangeNotifier {
  Future<bool> Function()? _submit;
  bool _dirty = false;
  bool _canSubmit = false;
  bool _submitting = false;

  bool get isDirty => _dirty;
  bool get canSubmit => _canSubmit && !_submitting && _submit != null;
  bool get isSubmitting => _submitting;

  void attach(Future<bool> Function() submit) {
    _submit = submit;
    notifyListeners();
  }

  void update({bool? dirty, bool? canSubmit, bool? submitting}) {
    _dirty = dirty ?? _dirty;
    _canSubmit = canSubmit ?? _canSubmit;
    _submitting = submitting ?? _submitting;
    notifyListeners();
  }

  Future<bool> submit() async {
    final callback = _submit;
    if (!canSubmit || callback == null) return false;
    update(submitting: true);
    try {
      return await callback();
    } finally {
      update(submitting: false);
    }
  }
}

/// Connects a routed form's explicit Cancel action to the shared dirty guard.
class AppUnsavedChangesController {
  Future<void> Function()? _requestPop;

  Future<void> requestPop() => _requestPop?.call() ?? Future<void>.value();
}

/// Protects routed task pages from losing edits through Cancel or system Back.
class AppUnsavedChangesGuard extends StatefulWidget {
  const AppUnsavedChangesGuard({
    super.key,
    required this.controller,
    required this.hasChanges,
    this.dismissalEnabled = true,
    required this.child,
  });

  final AppUnsavedChangesController controller;
  final bool hasChanges;
  final bool dismissalEnabled;
  final Widget child;

  @override
  State<AppUnsavedChangesGuard> createState() => _AppUnsavedChangesGuardState();
}

class _AppUnsavedChangesGuardState extends State<AppUnsavedChangesGuard> {
  bool _allowPop = false;
  Future<void>? _requestPopInFlight;

  @override
  void initState() {
    super.initState();
    widget.controller._requestPop = _requestPop;
  }

  @override
  void didUpdateWidget(covariant AppUnsavedChangesGuard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller._requestPop = null;
      widget.controller._requestPop = _requestPop;
    }
  }

  @override
  void dispose() {
    widget.controller._requestPop = null;
    super.dispose();
  }

  Future<void> _requestPop() => _requestPopInFlight ??= _performRequestPop()
      .whenComplete(() => _requestPopInFlight = null);

  Future<void> _performRequestPop() async {
    if (!widget.dismissalEnabled) return;
    if (!widget.hasChanges) {
      await _popOrCloseSheet();
      return;
    }
    final discard = await showAppConfirm(
      context,
      title: '捨棄未儲存的變更？',
      message: '離開後，本次修改不會保留。',
      confirmLabel: '捨棄',
      isDestructive: true,
    );
    if (!mounted || !discard) return;
    setState(() => _allowPop = true);
    await _popOrCloseSheet();
  }

  Future<void> _popOrCloseSheet() async {
    final navigator = Navigator.of(context);
    final sheetScope = TpLargeSheetNavigationScope.maybeOf(context);
    if (sheetScope != null &&
        (identical(navigator, Navigator.of(context, rootNavigator: true)) ||
            !navigator.canPop())) {
      sheetScope.onClose();
      return;
    }
    await navigator.maybePop();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: widget.dismissalEnabled && (_allowPop || !widget.hasChanges),
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) unawaited(_requestPop());
    },
    child: widget.child,
  );
}

typedef _AppSheetBuilder<T> =
    Widget Function(
      BuildContext context,
      Future<void> Function([T? result]) close,
    );

LiquidGlassSettings _appLargeSheetSettings(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return LiquidGlassSettings(
    glassColor: isDark ? const Color(0xB3121214) : const Color(0xC7FFFBF5),
    thickness: isDark ? 28 : 24,
    blur: 24,
    chromaticAberration: isDark ? 0.003 : 0.004,
    lightIntensity: isDark ? 0.68 : 0.76,
    ambientStrength: isDark ? 0.08 : 0.14,
    refractiveIndex: 1.10,
    saturation: isDark ? 1.04 : 1.06,
    platformViewFallbackColor: isDark
        ? const Color(0xF21C1C1E)
        : const Color(0xF2FFFBF5),
  );
}

Future<T?> _showAppSheet<T>({
  required BuildContext context,
  required _AppSheetBuilder<T> builder,
  required GlassSheetState initialState,
  required double mediumSize,
  required double largeSize,
  required bool resizable,
  Future<bool> Function()? canDismiss,
  Future<bool> Function()? onSystemBack,
}) {
  final controller = GlassModalSheetController();
  return showGeneralDialog<T>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.38),
    transitionDuration: const Duration(milliseconds: 300),
    transitionBuilder: (context, animation, secondaryAnimation, child) =>
        SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
              .animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutQuart),
              ),
          child: child,
        ),
    pageBuilder: (dialogContext, animation, secondaryAnimation) =>
        _ThemeAwareAppSheet<T>(
          controller: controller,
          initialState: initialState,
          mediumSize: mediumSize,
          largeSize: largeSize,
          resizable: resizable,
          canDismiss: canDismiss,
          onSystemBack: onSystemBack,
          onClosed: (value) =>
              Navigator.of(dialogContext, rootNavigator: true).pop(value),
          builder: builder,
        ),
  );
}

class _ThemeAwareAppSheet<T> extends StatefulWidget {
  const _ThemeAwareAppSheet({
    required this.controller,
    required this.initialState,
    required this.mediumSize,
    required this.largeSize,
    required this.resizable,
    required this.canDismiss,
    required this.onSystemBack,
    required this.onClosed,
    required this.builder,
  });

  final GlassModalSheetController controller;
  final GlassSheetState initialState;
  final double mediumSize;
  final double largeSize;
  final bool resizable;
  final Future<bool> Function()? canDismiss;
  final Future<bool> Function()? onSystemBack;
  final ValueChanged<T?> onClosed;
  final _AppSheetBuilder<T> builder;

  @override
  State<_ThemeAwareAppSheet<T>> createState() => _ThemeAwareAppSheetState<T>();
}

class _ThemeAwareAppSheetState<T> extends State<_ThemeAwareAppSheet<T>> {
  bool _isClosing = false;
  bool _checkingDismiss = false;
  bool _handlingSystemBack = false;
  Widget? _sheet;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 保留同一個 child widget identity，避免外觀切換重建 dialog page 時把
    // sheet 內部 Navigator 的子頁（例如「外觀」）退回帳號首頁。
    _sheet ??= widget.builder(context, _requestClose);
  }

  Future<void> _requestClose([T? result]) async {
    if (_isClosing || _checkingDismiss) return;
    _checkingDismiss = true;
    final allowed = await (widget.canDismiss?.call() ?? Future.value(true));
    _checkingDismiss = false;
    if (!mounted || !allowed) {
      widget.controller.snapToState(widget.initialState);
      return;
    }
    setState(() => _isClosing = true);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    widget.onClosed(result);
  }

  Future<void> _handleSystemBack([T? result]) async {
    if (_isClosing || _handlingSystemBack) return;
    _handlingSystemBack = true;
    final handled = await (widget.onSystemBack?.call() ?? Future.value(false));
    _handlingSystemBack = false;
    if (!mounted || handled) return;
    await _requestClose(result);
  }

  @override
  Widget build(BuildContext context) {
    // 必須在 build 內依賴 Theme；外觀切換後 sheet 材質與內容才會同一幀更新。
    final settings = _appLargeSheetSettings(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return PopScope<T>(
      canPop: _isClosing,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_handleSystemBack(result));
      },
      child: GlassModalSheetScaffold(
        controller: widget.controller,
        body: const SizedBox.expand(),
        sheet: _sheet!,
        initialState: widget.initialState,
        halfSize: widget.mediumSize,
        fullSize: widget.largeSize,
        settings: settings,
        halfSettings: settings,
        expandedColor: isDark
            ? const Color(0xFF1C1C1E)
            : const Color(0xFFFFFBF5),
        quality: GlassQuality.standard,
        // 定版近滿版 sheet 是「實色內容畫布＋玻璃控制元件」；只在進場時
        // 保留玻璃過渡，固定於 93% detent 後即使用完整 canvas 色，避免
        // 背後地圖穿透而降低文字與 grouped list 的對比。
        fillThreshold: 0.85,
        fillTransition: GlassFillTransition.gradual,
        topBorderRadius: 28,
        fullTopBorderRadius: 28,
        bottomBorderRadius: 0,
        fullBottomBorderRadius: 0,
        horizontalMargin: 0,
        bottomMargin: 0,
        padding: EdgeInsets.zero,
        showDragIndicator: widget.resizable,
        onStateChanged: (state) {
          if (state == GlassSheetState.hidden) {
            widget.controller.snapToState(widget.initialState, animate: false);
            unawaited(_requestClose());
          }
        },
      ),
    );
  }
}

Future<T?> showAppSelectionSheet<T>(
  BuildContext context, {
  required String title,
  required Widget Function(BuildContext, ValueChanged<T>) builder,
}) {
  return _showAppSheet<T>(
    context: context,
    initialState: GlassSheetState.full,
    mediumSize: 0.93,
    largeSize: 0.93,
    resizable: false,
    builder: (sheetContext, close) => Material(
      color: Colors.transparent,
      child: Column(
        children: [
          TpSheetHeader(
            title: title,
            leading: TpToolbarTextButton(
              label: '取消',
              onPressed: () => unawaited(close()),
            ),
          ),
          Expanded(
            child: builder(sheetContext, (value) => unawaited(close(value))),
          ),
        ],
      ),
    ),
  );
}

Future<T?> showAppContentSheet<T>(
  BuildContext context, {
  required String title,
  required WidgetBuilder builder,
}) {
  final sheetNavigatorKey = GlobalKey<NavigatorState>();
  return _showAppSheet<T>(
    context: context,
    initialState: GlassSheetState.full,
    mediumSize: 0.93,
    largeSize: 0.93,
    resizable: false,
    onSystemBack: () async {
      final navigator = sheetNavigatorKey.currentState;
      if (navigator == null) return false;
      return navigator.maybePop();
    },
    builder: (sheetContext, close) => _AppContentSheet<T>(
      title: title,
      contentBuilder: builder,
      onClose: close,
      navigatorKey: sheetNavigatorKey,
    ),
  );
}

Future<T?> showAppScreenSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  final sheetNavigatorKey = GlobalKey<NavigatorState>();
  return _showAppSheet<T>(
    context: context,
    initialState: GlassSheetState.full,
    mediumSize: 0.93,
    largeSize: 0.93,
    resizable: false,
    onSystemBack: () async {
      final navigator = sheetNavigatorKey.currentState;
      if (navigator == null) return false;
      return navigator.maybePop();
    },
    builder: (sheetContext, close) => _AppScreenSheet<T>(
      contentBuilder: builder,
      onClose: close,
      navigatorKey: sheetNavigatorKey,
    ),
  );
}

Future<bool?> showAppFormSheet(
  BuildContext context, {
  required String title,
  required String submitLabel,
  required AppSheetFormController controller,
  required WidgetBuilder builder,
  Key? submitKey,
  Key? titleKey,
  Key? cancelKey,
}) {
  return _showAppSheet<bool>(
    context: context,
    initialState: GlassSheetState.full,
    mediumSize: 0.62,
    largeSize: 0.93,
    resizable: true,
    canDismiss: () async {
      if (controller.isSubmitting) return false;
      if (!controller.isDirty) return true;
      return showAppConfirm(
        context,
        title: '捨棄未儲存的變更？',
        message: '離開後，本次修改不會保留。',
        confirmLabel: '捨棄',
        isDestructive: true,
      );
    },
    builder: (sheetContext, close) => Material(
      color: Colors.transparent,
      child: AnimatedBuilder(
        animation: controller,
        builder: (_, child) => Column(
          children: [
            TpSheetHeader(
              title: title,
              titleKey: titleKey,
              leading: TpToolbarTextButton(
                key: cancelKey,
                label: '取消',
                onPressed: controller.isSubmitting
                    ? null
                    : () => unawaited(close()),
              ),
              trailing: TpToolbarTextButton(
                key: submitKey,
                label: submitLabel,
                onPressed: controller.canSubmit
                    ? () async {
                        if (await controller.submit()) {
                          controller.update(dirty: false);
                          await close(true);
                        }
                      }
                    : null,
              ),
            ),
            Expanded(child: child!),
          ],
        ),
        child: builder(sheetContext),
      ),
    ),
  );
}

class _AppContentSheet<T> extends StatelessWidget {
  const _AppContentSheet({
    required this.title,
    required this.contentBuilder,
    required this.onClose,
    required this.navigatorKey,
  });

  final String title;
  final WidgetBuilder contentBuilder;
  final Future<void> Function([T? result]) onClose;
  final GlobalKey<NavigatorState> navigatorKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox.expand(
      key: const ValueKey('app-large-sheet'),
      child: Material(
        color: Colors.transparent,
        child: TpLargeSheetNavigationScope(
          onClose: onClose,
          child: Theme(
            data: theme.copyWith(scaffoldBackgroundColor: Colors.transparent),
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: Navigator(
                key: navigatorKey,
                onGenerateRoute: (_) => MaterialPageRoute<void>(
                  builder: (pageContext) => SafeArea(
                    top: false,
                    child: Column(
                      children: [
                        TpSheetHeader(
                          title: title,
                          trailing: KeyedSubtree(
                            key: const ValueKey('app-large-sheet-close'),
                            child: TpToolbarGlassButton(
                              key: const ValueKey('app-sheet-close'),
                              tooltip: MaterialLocalizations.of(
                                pageContext,
                              ).closeButtonTooltip,
                              onPressed: () => unawaited(onClose()),
                              child: const Icon(CupertinoIcons.xmark, size: 19),
                            ),
                          ),
                        ),
                        Expanded(child: contentBuilder(pageContext)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AppScreenSheet<T> extends StatelessWidget {
  const _AppScreenSheet({
    required this.contentBuilder,
    required this.onClose,
    required this.navigatorKey,
  });

  final WidgetBuilder contentBuilder;
  final Future<void> Function([T? result]) onClose;
  final GlobalKey<NavigatorState> navigatorKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox.expand(
      key: const ValueKey('app-large-screen-sheet'),
      child: Material(
        color: Colors.transparent,
        child: TpLargeSheetNavigationScope(
          onClose: () => unawaited(onClose()),
          child: Theme(
            data: theme.copyWith(scaffoldBackgroundColor: Colors.transparent),
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: Navigator(
                key: navigatorKey,
                onGenerateRoute: (_) => MaterialPageRoute<void>(
                  builder: (pageContext) => contentBuilder(pageContext),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 平台自適應搜尋輸入列。
///
/// - iOS/macOS → [CupertinoSearchTextField](灰底圓角、內建放大鏡與清除鈕)。
/// - 其餘平台 → Material [TextField](放大鏡 prefix;有字時顯示清除鈕)。
///
/// [fieldKey] 直接掛在底層欄位上,widget test 以 `find.byKey` + `enterText` 操作
/// 兩種平台皆通。
class AppSearchField extends StatefulWidget {
  const AppSearchField({
    super.key,
    this.fieldKey,
    required this.controller,
    required this.placeholder,
    this.onChanged,
    this.onSubmitted,
    this.debounce,
    this.autofocus = false,
    this.enabled = true,
    this.embedded = false,
  });

  /// 掛在底層 TextField/CupertinoSearchTextField 上的 key(供測試定位)。
  final Key? fieldKey;
  final TextEditingController controller;
  final String placeholder;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Duration? debounce;
  final bool autofocus;
  final bool enabled;
  final bool embedded;

  @override
  State<AppSearchField> createState() => _AppSearchFieldState();
}

class _AppSearchFieldState extends State<AppSearchField> {
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  /// 僅為 Material branch「有字才顯示清除鈕」重繪;iOS 自帶清除鈕。
  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  void _clear() {
    widget.controller.clear();
    _changed('');
  }

  void _changed(String value) {
    _debounceTimer?.cancel();
    final debounce = widget.debounce;
    if (debounce == null || value.isEmpty) {
      widget.onChanged?.call(value);
      return;
    }
    _debounceTimer = Timer(debounce, () => widget.onChanged?.call(value));
  }

  void _submitted(String value) {
    _debounceTimer?.cancel();
    widget.onSubmitted?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    final platform = Theme.of(context).platform;
    final isApple =
        platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;

    if (isApple) {
      return CupertinoSearchTextField(
        key: widget.fieldKey,
        controller: widget.controller,
        placeholder: widget.placeholder,
        onChanged: _changed,
        onSubmitted: _submitted,
        autofocus: widget.autofocus,
        enabled: widget.enabled,
        backgroundColor: widget.embedded ? Colors.transparent : null,
      );
    }

    return TextField(
      key: widget.fieldKey,
      controller: widget.controller,
      autofocus: widget.autofocus,
      enabled: widget.enabled,
      textInputAction: TextInputAction.search,
      onChanged: _changed,
      onSubmitted: _submitted,
      decoration: InputDecoration(
        hintText: widget.placeholder,
        isDense: true,
        prefixIcon: const Icon(CupertinoIcons.search),
        suffixIcon: widget.controller.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(CupertinoIcons.clear),
                onPressed: _clear,
              ),
        border: widget.embedded ? InputBorder.none : const OutlineInputBorder(),
      ),
    );
  }
}

/// 顯示短暫通知(取代 Material SnackBar 的跨平台一致 API)。
///
/// - iOS/macOS → 頂部滑入橫幅(安全區內、約 2.5 秒自動滑出消失),更貼近 iOS
///   系統通知,而非 Android 底部 SnackBar。
/// - 其餘平台 → Material [SnackBar]。
void showAppNotice(BuildContext context, String message) {
  final platform = Theme.of(context).platform;
  final isApple =
      platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;

  if (!isApple) {
    // 先清掉排隊中/顯示中的 SnackBar,讓最新訊息立即取代(避免 ScaffoldMessenger
    // 佇列造成後續訊息被延後顯示)。
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
    return;
  }

  final overlay = Overlay.of(context, rootOverlay: true);
  late OverlayEntry entry;
  var removed = false;
  entry = OverlayEntry(
    builder: (_) => _TopNoticeBanner(
      message: message,
      onDismissed: () {
        if (removed) return;
        removed = true;
        entry.remove();
      },
    ),
  );
  overlay.insert(entry);
}

/// 顯示可復原的單一動作通知。
///
/// Undo 必須在使用者仍可看到原畫面時立即操作，因此所有平台都使用固定在
/// Root tab 上方的浮動 SnackBar，而不使用無 action 的 iOS 頂部橫幅。
void showAppUndoNotice(
  BuildContext context, {
  required String message,
  required VoidCallback onUndo,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(
          TpSpacing.s4,
          0,
          TpSpacing.s4,
          TpRootTabGeometry.clearance(context) + TpSpacing.s2,
        ),
        duration: const Duration(seconds: 6),
        content: Text(message),
        action: SnackBarAction(label: '復原', onPressed: onUndo),
      ),
    );
}

/// iOS 頂部通知橫幅:下一幀滑入、停留約 2.5 秒後滑出,結束時呼叫 [onDismissed]。
class _TopNoticeBanner extends StatefulWidget {
  const _TopNoticeBanner({required this.message, required this.onDismissed});

  final String message;
  final VoidCallback onDismissed;

  @override
  State<_TopNoticeBanner> createState() => _TopNoticeBannerState();
}

class _TopNoticeBannerState extends State<_TopNoticeBanner> {
  bool _visible = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _visible = true);
    });
    _timer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) setState(() => _visible = false);
    });
  }

  /// 滑動動畫結束:僅在「滑出」結束(不可見)時移除 overlay entry。
  void _handleAnimationEnd() {
    if (!_visible) widget.onDismissed();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final slideDuration = TpMotion.resolve(context, TpMotion.normal);
    final fadeDuration = TpMotion.resolve(context, TpMotion.fast);
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.all(TpSpacing.s3),
          child: AnimatedSlide(
            duration: slideDuration,
            curve: TpMotion.appleEase,
            offset: _visible ? Offset.zero : const Offset(0, -1.6),
            onEnd: _handleAnimationEnd,
            child: AnimatedOpacity(
              duration: fadeDuration,
              opacity: _visible ? 1 : 0,
              child: Material(
                color: theme.colorScheme.inverseSurface,
                borderRadius: const BorderRadius.all(
                  Radius.circular(TpRadius.lg),
                ),
                elevation: 6,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: TpSpacing.s4,
                    vertical: TpSpacing.s3,
                  ),
                  child: Text(
                    widget.message,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onInverseSurface,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
