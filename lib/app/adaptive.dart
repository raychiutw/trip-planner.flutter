/// 平台自適應 UI helper。
///
/// iOS/macOS 走 Cupertino 慣例、其餘平台走 Material。
/// 用 `Theme.of(context).platform`(而非 defaultTargetPlatform),
/// 方便測試以 `ThemeData(platform: ...)` override。
library;

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/tokens.dart';

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

/// 自適應 action sheet 的單一動作。
class AppSheetAction<T> {
  const AppSheetAction({
    required this.label,
    required this.value,
    this.isDestructive = false,
    this.icon,
  });

  /// 動作文字。
  final String label;

  /// 選中此動作時 [showAppActionSheet] 回傳的值。
  final T value;

  /// 破壞性動作(iOS 紅字;Android 紅色 icon/文字)。
  final bool isDestructive;

  /// Android 清單樣式的 leading icon(iOS 不顯示)。
  final IconData? icon;
}

/// 顯示自適應動作選單,回傳使用者選擇的動作值(取消回傳 `null`)。
///
/// - iOS/macOS → [CupertinoActionSheet](底部彈出、破壞性紅字、獨立取消鈕)。
/// - 其餘平台 → 附 drag handle 的 Material bottom sheet(ListTile 清單)。
Future<T?> showAppActionSheet<T>(
  BuildContext context, {
  String? title,
  String? message,
  required List<AppSheetAction<T>> actions,
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
            CupertinoActionSheetAction(
              isDestructiveAction: action.isDestructive,
              onPressed: () => Navigator.of(sheetContext).pop(action.value),
              child: Text(action.label),
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
            for (final action in actions)
              ListTile(
                leading: action.icon == null
                    ? null
                    : Icon(
                        action.icon,
                        color: action.isDestructive ? error : null,
                      ),
                title: Text(
                  action.label,
                  style: action.isDestructive
                      ? TextStyle(color: error, fontWeight: FontWeight.w600)
                      : null,
                ),
                onTap: () => Navigator.of(sheetContext).pop(action.value),
              ),
          ],
        ),
      );
    },
  );
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
    this.onSearch,
    this.searching = false,
    this.searchButtonKey,
    this.autofocus = false,
    this.enabled = true,
  });

  /// 掛在底層 TextField/CupertinoSearchTextField 上的 key(供測試定位)。
  final Key? fieldKey;
  final TextEditingController controller;
  final String placeholder;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onSearch;
  final bool searching;
  final Key? searchButtonKey;
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
        suffixIcon: const Icon(CupertinoIcons.search, size: 18),
        onSuffixTap: widget.searching ? null : widget.onSearch,
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
        suffixIcon: widget.onSearch != null
            ? IconButton(
                key: widget.searchButtonKey,
                tooltip: '搜尋地點',
                onPressed: widget.searching ? null : widget.onSearch,
                icon: widget.searching
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator.adaptive(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(CupertinoIcons.search),
              )
            : widget.controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: '清除搜尋',
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
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.all(TpSpacing.s3),
          child: AnimatedSlide(
            duration: reduceMotion ? Duration.zero : TpMotion.normal,
            curve: TpMotion.appleEase,
            offset: _visible ? Offset.zero : const Offset(0, -1.6),
            onEnd: _handleAnimationEnd,
            child: AnimatedOpacity(
              duration: reduceMotion ? Duration.zero : TpMotion.fast,
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

/// 平台自適應大標題 sliver(root 清單頁用)。
///
/// - iOS/macOS → [CupertinoSliverNavigationBar]:原生大標題,捲動平滑收合成置中
///   inline 標題 + 半透明模糊(scroll-under),對標 Apple 設定/Mail/Notes。
/// - 其餘平台 → Material [SliverAppBar.large]。
///
/// 只負責標題列;搜尋/篩選等放在此 sliver「之後」的 sliver(隨內容捲動)。
class SliverAdaptiveLargeTitle extends StatelessWidget {
  const SliverAdaptiveLargeTitle({
    super.key,
    required this.title,
    this.actions = const [],
    this.automaticallyImplyLeading = true,
  });

  final String title;
  final List<Widget> actions;
  final bool automaticallyImplyLeading;

  @override
  Widget build(BuildContext context) {
    final platform = Theme.of(context).platform;
    final isApple =
        platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;

    if (isApple) {
      // 收合後的小標(persistent middle)放大成 titleLarge(20/700),對齊 Material
      // AppBar(如 AI 助手)的標題大小;alwaysShowMiddle:false → 只在捲動收合時淡入,
      // 置頂時仍只顯示大標,維持 iOS 大標題的收合行為。
      final theme = Theme.of(context);
      final collapsedStyle = theme.textTheme.titleLarge?.copyWith(
        color: theme.colorScheme.onSurface,
      );
      return CupertinoSliverNavigationBar(
        largeTitle: Text(title),
        middle: Text(title, style: collapsedStyle),
        alwaysShowMiddle: false,
        automaticallyImplyLeading: automaticallyImplyLeading,
        trailing: actions.isEmpty
            ? null
            : Row(mainAxisSize: MainAxisSize.min, children: actions),
      );
    }

    return SliverAppBar.large(
      pinned: true,
      automaticallyImplyLeading: automaticallyImplyLeading,
      title: Text(title),
      actions: actions.isEmpty ? null : actions,
    );
  }
}
