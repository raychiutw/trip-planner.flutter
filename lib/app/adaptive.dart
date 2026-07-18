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
                child: Text(action.label),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final action in actions) ...[
              if (action.dividerBefore) const Divider(height: 1),
              ListTile(
                key: action.key,
                enabled: action.enabled,
                leading: Icon(
                  action.icon,
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

/// 顯示可共用的 HIG 近滿版下方視窗。
Future<T?> showAppLargeSheet<T>(
  BuildContext context, {
  required String title,
  required WidgetBuilder builder,
}) {
  final sheetNavigatorKey = GlobalKey<NavigatorState>();
  return _showThemeAwareAppLargeSheet<T>(
    context: context,
    sheetBuilder: (sheetContext, onClose) => _AppLargeSheetContent(
      title: title,
      contentBuilder: builder,
      onClose: onClose,
      navigatorKey: sheetNavigatorKey,
    ),
  );
}

/// 顯示自身已含 [TpAppBar] 的功能頁；共用 93% 高度、上滑動線與右上關閉。
///
/// 行程選單的筆記、資料、列印、異動、分享、共編與健檢皆走這個入口，
/// 不再以 `go()` 取代目前頁面而留下沒有出口的畫面。
Future<T?> showAppLargeScreenSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  return _showThemeAwareAppLargeSheet<T>(
    context: context,
    sheetBuilder: (sheetContext, onClose) =>
        _AppLargeScreenSheetContent(contentBuilder: builder, onClose: onClose),
  );
}

typedef _AppLargeSheetBuilder =
    Widget Function(BuildContext context, VoidCallback onClose);

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

Future<T?> _showThemeAwareAppLargeSheet<T>({
  required BuildContext context,
  required _AppLargeSheetBuilder sheetBuilder,
}) {
  final controller = GlassModalSheetController();
  return showGeneralDialog<T>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.38),
    transitionDuration: const Duration(milliseconds: 500),
    transitionBuilder: (context, animation, secondaryAnimation, child) =>
        SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
              .animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutQuart),
              ),
          child: child,
        ),
    pageBuilder: (dialogContext, animation, secondaryAnimation) =>
        _ThemeAwareAppLargeSheet(
          controller: controller,
          onClose: () => Navigator.of(dialogContext, rootNavigator: true).pop(),
          sheetBuilder: sheetBuilder,
        ),
  );
}

class _ThemeAwareAppLargeSheet extends StatefulWidget {
  const _ThemeAwareAppLargeSheet({
    required this.controller,
    required this.onClose,
    required this.sheetBuilder,
  });

  final GlassModalSheetController controller;
  final VoidCallback onClose;
  final _AppLargeSheetBuilder sheetBuilder;

  @override
  State<_ThemeAwareAppLargeSheet> createState() =>
      _ThemeAwareAppLargeSheetState();
}

class _ThemeAwareAppLargeSheetState extends State<_ThemeAwareAppLargeSheet> {
  var _isClosing = false;
  Widget? _sheet;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 保留同一個 child widget identity，避免外觀切換重建 dialog page 時把
    // sheet 內部 Navigator 的子頁（例如「外觀」）退回帳號首頁。
    _sheet ??= widget.sheetBuilder(context, _close);
  }

  void _close() {
    if (_isClosing) return;
    _isClosing = true;
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    // 必須在 build 內依賴 Theme；外觀切換後 sheet 材質與內容才會同一幀更新。
    final settings = _appLargeSheetSettings(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GlassModalSheetScaffold(
      controller: widget.controller,
      body: const SizedBox.expand(),
      sheet: _sheet!,
      initialState: GlassSheetState.full,
      halfSize: 0.93,
      fullSize: 0.93,
      settings: settings,
      halfSettings: settings,
      fullSettings: settings,
      expandedColor: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFFFFBF5),
      quality: GlassQuality.standard,
      fillThreshold: 1,
      fillTransition: GlassFillTransition.gradual,
      topBorderRadius: 28,
      fullTopBorderRadius: 28,
      bottomBorderRadius: 0,
      fullBottomBorderRadius: 0,
      horizontalMargin: 0,
      bottomMargin: 0,
      padding: EdgeInsets.zero,
      showDragIndicator: false,
      onStateChanged: (state) {
        if (state == GlassSheetState.hidden) _close();
      },
    );
  }
}

class _AppLargeSheetContent extends StatelessWidget {
  const _AppLargeSheetContent({
    required this.title,
    required this.contentBuilder,
    required this.onClose,
    required this.navigatorKey,
  });

  final String title;
  final WidgetBuilder contentBuilder;
  final VoidCallback onClose;
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
            child: Column(
              children: [
                // Drag indicator belongs to the sheet, not its first route. Keep
                // it visible when account/settings pushes a nested screen.
                SizedBox(
                  height: TpSpacing.s5,
                  child: Center(
                    child: Container(
                      key: const ValueKey('app-large-sheet-drag-indicator'),
                      width: 36,
                      height: 5,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.22,
                        ),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                ),
                Expanded(
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
                              SizedBox(
                                height: 56,
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                    left: TpSpacing.s5,
                                    right: TpSpacing.s3,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(pageContext)
                                              .textTheme
                                              .titleLarge
                                              ?.copyWith(
                                                fontSize: 20,
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                      ),
                                      TpToolbarGlassButton(
                                        key: const ValueKey(
                                          'app-large-sheet-close',
                                        ),
                                        tooltip: MaterialLocalizations.of(
                                          pageContext,
                                        ).closeButtonTooltip,
                                        onPressed: onClose,
                                        child: const Icon(
                                          CupertinoIcons.xmark,
                                          size: 19,
                                        ),
                                      ),
                                    ],
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AppLargeScreenSheetContent extends StatelessWidget {
  const _AppLargeScreenSheetContent({
    required this.contentBuilder,
    required this.onClose,
  });

  final WidgetBuilder contentBuilder;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox.expand(
      key: const ValueKey('app-large-screen-sheet'),
      child: Material(
        color: Colors.transparent,
        child: TpLargeSheetNavigationScope(
          onClose: onClose,
          child: Theme(
            data: theme.copyWith(scaffoldBackgroundColor: Colors.transparent),
            child: Column(
              children: [
                SizedBox(
                  height: TpSpacing.s5,
                  child: Center(
                    child: Container(
                      key: const ValueKey('app-large-sheet-drag-indicator'),
                      width: 36,
                      height: 5,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.22,
                        ),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: MediaQuery.removePadding(
                    context: context,
                    removeTop: true,
                    child: contentBuilder(context),
                  ),
                ),
              ],
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
    this.autofocus = false,
    this.enabled = true,
  });

  /// 掛在底層 TextField/CupertinoSearchTextField 上的 key(供測試定位)。
  final Key? fieldKey;
  final TextEditingController controller;
  final String placeholder;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final bool enabled;

  @override
  State<AppSearchField> createState() => _AppSearchFieldState();
}

class _AppSearchFieldState extends State<AppSearchField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  /// 僅為 Material branch「有字才顯示清除鈕」重繪;iOS 自帶清除鈕。
  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  void _clear() {
    widget.controller.clear();
    widget.onChanged?.call('');
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
        onChanged: widget.onChanged,
        onSubmitted: widget.onSubmitted,
        autofocus: widget.autofocus,
        enabled: widget.enabled,
      );
    }

    return TextField(
      key: widget.fieldKey,
      controller: widget.controller,
      autofocus: widget.autofocus,
      enabled: widget.enabled,
      textInputAction: TextInputAction.search,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
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
        border: const OutlineInputBorder(),
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
