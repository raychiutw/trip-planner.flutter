/// 全平台共用 Apple HIG 產品語意的 UI helper。
///
/// 僅系統整合與平台原生能力可分流；日期、確認、動作選單、搜尋與通知
/// 在所有平台維持同一套互動契約。
library;

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../theme/tokens.dart';
import '../ui/tp_action_item.dart';
import '../ui/tp_app_bar.dart';

/// 全 App 的鍵盤收合規則：點欄位外或拖曳任何 scroll view 都只移除焦點。
/// [TextFieldTapRegion] 內的附屬控制仍由 Flutter 排除在 outside tap 之外。
class AppKeyboardDismissRegion extends StatelessWidget {
  const AppKeyboardDismissRegion({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Actions(
      actions: {
        EditableTextTapOutsideIntent:
            CallbackAction<EditableTextTapOutsideIntent>(
              onInvoke: (intent) {
                intent.focusNode.unfocus();
                return null;
              },
            ),
      },
      child: NotificationListener<ScrollStartNotification>(
        onNotification: (notification) {
          if (notification.dragDetails != null) {
            FocusManager.instance.primaryFocus?.unfocus();
          }
          return false;
        },
        child: child,
      ),
    );
  }
}

/// 使用 HIG sheet 與 calendar；取消時不回寫，日期範圍外無法選取。
Future<DateTime?> showAppDatePicker(
  BuildContext context, {
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  var selected = initialDate;
  return showCupertinoModalPopup<DateTime>(
    context: context,
    builder: (sheetContext) => Material(
      color: Theme.of(sheetContext).colorScheme.surface,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 410,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: TpSpacing.s2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      child: const Text('取消'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(sheetContext).pop(selected),
                      child: const Text('完成'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CalendarDatePicker(
                  initialDate: initialDate,
                  firstDate: firstDate,
                  lastDate: lastDate,
                  onDateChanged: (value) => selected = value,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// 以裝置 locale 顯示完整日期；資料層仍維持 date-only wire format。
String formatAppFullDate(BuildContext context, DateTime date) =>
    MaterialLocalizations.of(context).formatFullDate(date);

/// 以裝置 locale 與 12/24 小時偏好顯示日期時間。
String formatAppDateTime(BuildContext context, DateTime dateTime) =>
    '${formatAppFullDate(context, dateTime)} '
    '${TimeOfDay.fromDateTime(dateTime).format(context)}';

/// 全平台使用符合 iOS HIG 的底部 time wheel，固定五分鐘間隔。
Future<TimeOfDay?> showAppTimePicker(
  BuildContext context, {
  required TimeOfDay initialTime,
}) async {
  final pickerInitialTime = TimeOfDay(
    hour: initialTime.hour,
    minute: initialTime.minute - initialTime.minute % 5,
  );
  var selected = pickerInitialTime;
  return showCupertinoModalPopup<TimeOfDay>(
    context: context,
    builder: (sheetContext) => Material(
      color: Theme.of(sheetContext).colorScheme.surface,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 300,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: TpSpacing.s2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      child: const Text('取消'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(sheetContext).pop(selected),
                      child: const Text('完成'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  minuteInterval: 5,
                  use24hFormat: MediaQuery.alwaysUse24HourFormatOf(context),
                  initialDateTime: DateTime(
                    2000,
                    1,
                    1,
                    pickerInitialTime.hour,
                    pickerInitialTime.minute,
                  ),
                  onDateTimeChanged: (value) => selected = TimeOfDay(
                    hour: value.hour,
                    minute: value.minute,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// 顯示 HIG「確認 / 取消」對話框,回傳使用者是否確認。
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
  final result = await showCupertinoDialog<bool>(
    context: context,
    builder: (dialogContext) => CupertinoAlertDialog(
      title: Text(title),
      content: message == null ? null : Text(message),
      actions: [
        CupertinoDialogAction(
          isDefaultAction: isDestructive,
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

/// 顯示只有單一確認動作的 HIG 提示對話框。
Future<void> showAppAlert(
  BuildContext context, {
  required String title,
  required String message,
  String actionLabel = '好',
  Key? key,
}) {
  return showCupertinoDialog<void>(
    context: context,
    builder: (dialogContext) => CupertinoAlertDialog(
      key: key,
      title: Text(title),
      content: Text(message),
      actions: [
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(actionLabel),
        ),
      ],
    ),
  );
}

/// 顯示 HIG 動作選單,回傳使用者選擇的動作值(取消回傳 `null`)。
Future<T?> showAppActionSheet<T>(
  BuildContext context, {
  String? title,
  String? message,
  required List<TpActionItem<T>> actions,
  String cancelLabel = '取消',
}) {
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
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;
  final surface = theme.colorScheme.surface;
  return LiquidGlassSettings(
    glassColor: surface.withValues(alpha: isDark ? 0.70 : 0.78),
    thickness: isDark ? 28 : 24,
    blur: 24,
    chromaticAberration: isDark ? 0.003 : 0.004,
    lightIntensity: isDark ? 0.68 : 0.76,
    ambientStrength: isDark ? 0.08 : 0.14,
    refractiveIndex: 1.10,
    saturation: isDark ? 1.04 : 1.06,
    platformViewFallbackColor: surface.withValues(alpha: 0.95),
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
    // 保留同一個 child widget identity，避免系統外觀變更時重建 dialog page
    // 而把 sheet 內部 Navigator 的子頁退回帳號首頁。
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
    // 必須在 build 內依賴 Theme；系統外觀變更後 sheet 材質與內容才會同幀更新。
    final settings = _appLargeSheetSettings(context);
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
        expandedColor: Theme.of(context).colorScheme.surface,
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
  ValueListenable<bool>? dismissalLocked,
  ValueListenable<bool>? hasUnsavedChanges,
}) {
  return _showAppSheet<T>(
    context: context,
    initialState: GlassSheetState.full,
    mediumSize: 0.93,
    largeSize: 0.93,
    resizable: false,
    canDismiss: dismissalLocked == null && hasUnsavedChanges == null
        ? null
        : () async {
            if (dismissalLocked?.value ?? false) return false;
            if (!(hasUnsavedChanges?.value ?? false)) return true;
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
      child: Column(
        children: [
          TpSheetHeader(
            title: title,
            leading: dismissalLocked == null
                ? TpToolbarTextButton(
                    key: const ValueKey('app-selection-cancel'),
                    label: '取消',
                    onPressed: () => unawaited(close()),
                  )
                : AnimatedBuilder(
                    animation: dismissalLocked,
                    builder: (_, _) => TpToolbarTextButton(
                      key: const ValueKey('app-selection-cancel'),
                      label: '取消',
                      onPressed: dismissalLocked.value
                          ? null
                          : () => unawaited(close()),
                    ),
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
  final size = MediaQuery.sizeOf(context);
  if (size.width >= 720 && size.height >= 700) {
    return showDialog<T>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (_) => _RegularAppContentSheet<T>(
        title: title,
        contentBuilder: builder,
        navigatorKey: sheetNavigatorKey,
      ),
    );
  }
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

class _RegularAppContentSheet<T> extends StatefulWidget {
  const _RegularAppContentSheet({
    required this.title,
    required this.contentBuilder,
    required this.navigatorKey,
  });

  final String title;
  final WidgetBuilder contentBuilder;
  final GlobalKey<NavigatorState> navigatorKey;

  @override
  State<_RegularAppContentSheet<T>> createState() =>
      _RegularAppContentSheetState<T>();
}

class _RegularAppContentSheetState<T>
    extends State<_RegularAppContentSheet<T>> {
  bool _closing = false;
  bool _handlingBack = false;

  Future<void> _close([T? result]) async {
    if (_closing) return;
    setState(() => _closing = true);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop(result);
  }

  Future<void> _handleBack([T? result]) async {
    if (_closing || _handlingBack) return;
    _handlingBack = true;
    final handled = await widget.navigatorKey.currentState?.maybePop() ?? false;
    _handlingBack = false;
    if (!mounted || handled) return;
    await _close(result);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<T>(
      canPop: _closing,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_handleBack(result));
      },
      child: Dialog(
        insetPadding: const EdgeInsets.all(TpSpacing.s4),
        clipBehavior: Clip.antiAlias,
        backgroundColor: Theme.of(context).colorScheme.surface,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 720),
          child: SizedBox(
            key: const ValueKey('app-regular-content-sheet'),
            width: 560,
            height: 720,
            child: _AppContentSheet<T>(
              title: widget.title,
              contentBuilder: widget.contentBuilder,
              onClose: _close,
              navigatorKey: widget.navigatorKey,
            ),
          ),
        ),
      ),
    );
  }
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
/// [fieldKey] 直接掛在底層欄位上,widget test 以 `find.byKey` + `enterText` 操作
/// 各平台皆通。
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
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
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
}

/// 顯示頂部滑入橫幅（安全區內、約 2.5 秒後消失）。
void showAppNotice(BuildContext context, String message) {
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

/// 頂部通知橫幅:下一幀滑入、停留約 2.5 秒後滑出,結束時呼叫 [onDismissed]。
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
      child: IgnorePointer(
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
                child: Semantics(
                  container: true,
                  liveRegion: true,
                  label: widget.message,
                  excludeSemantics: true,
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
        ),
      ),
    );
  }
}
