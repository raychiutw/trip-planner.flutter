/// App 鎖的根層級外殼：鎖定畫面、登入後的詢問，以及回前景時機。
///
/// 放在 `MaterialApp.router` 的 builder 內、Navigator 之上，所以鎖定畫面會蓋住
/// 所有路由與 sheet。這一層沒有 Navigator／Overlay，`adaptive.dart` 的確認框與
/// `showAppNotice` 都用不了，對話框與提示因此直接畫在這裡（僅限此處，其餘畫面
/// 一律走共用 helper）。
library;

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/providers.dart';
import '../theme/tokens.dart';
import '../ui/tp_filled_button.dart';
import 'app_lock.dart';
import 'biometric_login.dart';

class AppLockHost extends ConsumerStatefulWidget {
  const AppLockHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppLockHost> createState() => _AppLockHostState();
}

class _AppLockHostState extends ConsumerState<AppLockHost> {
  late final AppLifecycleListener _lifecycle;
  Timer? _noticeTimer;
  bool _showDisabledNotice = false;

  /// 離開前景時蓋住內容，App 切換器的截圖才不會露出行程與旅伴資料。
  bool _inactive = false;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onInactive: () => setState(() => _inactive = true),
      onHide: () => ref
          .read(appLockProvider.notifier)
          .onHidden(ref.read(appLockClockProvider)()),
      onResume: () {
        setState(() => _inactive = false);
        unawaited(_resumed());
      },
    );
    // 冷啟動也對帳一次：關掉生物辨識的裝置不該卡在 App 鎖。
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_resumed()));
  }

  Future<void> _resumed() async {
    // 使用者可能剛去系統設定登錄或移除生物辨識，設定列與鎖定畫面要讀到新狀態。
    ref.invalidate(appLockKindProvider);
    final disabled = await ref
        .read(appLockProvider.notifier)
        .onResumed(ref.read(appLockClockProvider)());
    if (!disabled || !mounted) return;
    setState(() => _showDisabledNotice = true);
    _noticeTimer?.cancel();
    _noticeTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showDisabledNotice = false);
    });
  }

  @override
  void dispose() {
    _noticeTimer?.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = ref.watch(authStateProvider).value != null;
    final lock = ref.watch(appLockProvider);
    final showLock = lock.locked && signedIn;
    final scheme = Theme.of(context).colorScheme;

    return Stack(
      children: [
        Positioned.fill(
          child: ExcludeSemantics(
            key: const ValueKey('app-lock-content-semantics'),
            excluding: showLock,
            child: ExcludeFocus(
              excluding: showLock,
              child: IgnorePointer(
                key: const ValueKey('app-lock-content-guard'),
                ignoring: showLock,
                child: widget.child,
              ),
            ),
          ),
        ),
        if (showLock)
          const Positioned.fill(child: AppLockScreen())
        else if (_inactive && lock.enabled && signedIn)
          Positioned.fill(
            child: ColoredBox(
              key: const ValueKey('app-lock-privacy-cover'),
              color: scheme.surface,
              child: Center(
                child: Icon(
                  CupertinoIcons.lock_fill,
                  size: 48,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        if (lock.promptPending && signedIn && !showLock)
          Positioned.fill(child: _EnablePrompt()),
        if (ref.watch(biometricLoginProvider).promptPending &&
            signedIn &&
            !showLock &&
            !lock.promptPending)
          const Positioned.fill(child: _BiometricLoginPrompt()),
        if (_showDisabledNotice)
          Positioned(
            top: MediaQuery.paddingOf(context).top + TpSpacing.s2,
            left: TpSpacing.s4,
            right: TpSpacing.s4,
            child: Semantics(
              liveRegion: true,
              child: Material(
                color: scheme.inverseSurface,
                borderRadius: BorderRadius.circular(TpSpacing.s3),
                child: Padding(
                  padding: const EdgeInsets.all(TpSpacing.s3),
                  child: Text(
                    '此裝置已沒有可用的生物辨識或裝置密碼，已關閉 App 鎖。',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onInverseSurface,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// 沒有 Navigator 可用時的 iOS 提示框：scrim 加 [CupertinoAlertDialog]。
class _HostDialog extends StatelessWidget {
  const _HostDialog({
    required this.dialogKey,
    required this.title,
    required this.message,
    required this.cancelLabel,
    required this.confirmLabel,
    required this.onCancel,
    required this.onConfirm,
    this.destructive = false,
  });

  final Key dialogKey;
  final String title;
  final String message;
  final String cancelLabel;
  final String confirmLabel;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  final bool destructive;

  @override
  Widget build(BuildContext context) => Semantics(
    scopesRoute: true,
    explicitChildNodes: true,
    child: ColoredBox(
      color: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.4),
      child: Center(
        child: CupertinoAlertDialog(
          key: dialogKey,
          title: Text(title),
          content: Text(message),
          actions: [
            CupertinoDialogAction(
              key: const ValueKey('app-lock-dialog-cancel'),
              onPressed: onCancel,
              child: Text(cancelLabel),
            ),
            CupertinoDialogAction(
              key: const ValueKey('app-lock-dialog-confirm'),
              isDefaultAction: !destructive,
              isDestructiveAction: destructive,
              onPressed: onConfirm,
              child: Text(confirmLabel),
            ),
          ],
        ),
      ),
    ),
  );
}

class _EnablePrompt extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final label = ref.watch(appLockKindProvider).value.lockLabel;
    final controller = ref.read(appLockProvider.notifier);
    return _HostDialog(
      dialogKey: const ValueKey('app-lock-prompt'),
      title: '要用 $label 解鎖 Tripline 嗎？',
      message: '開啟後，每次打開 App 都要先通過 $label，別人拿到你的手機也看不到行程。之後可以在「帳號 → 安全性」變更。',
      cancelLabel: '稍後再說',
      confirmLabel: '開啟',
      onCancel: () => unawaited(controller.answerPrompt(enable: false)),
      onConfirm: () => unawaited(controller.answerPrompt(enable: true)),
    );
  }
}

/// 登入成功後詢問是否開啟生物辨識登入（排在 App 鎖的詢問之後）。
class _BiometricLoginPrompt extends ConsumerWidget {
  const _BiometricLoginPrompt();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final label = ref.watch(appLockKindProvider).value.lockLabel;
    final controller = ref.read(biometricLoginProvider.notifier);
    return _HostDialog(
      dialogKey: const ValueKey('bio-login-prompt'),
      title: '要用 $label 登入 Tripline 嗎？',
      message:
          '開啟後，登入憑證只能用 $label 解鎖，密碼不會存在這支手機。之後可以在「帳號 → 安全性」關閉。',
      cancelLabel: '稍後再說',
      confirmLabel: '開啟',
      onCancel: () => unawaited(controller.answerPrompt(enable: false)),
      onConfirm: () => unawaited(controller.answerPrompt(enable: true)),
    );
  }
}

class AppLockScreen extends ConsumerStatefulWidget {
  const AppLockScreen({super.key = const ValueKey('app-lock-screen')});

  @override
  ConsumerState<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends ConsumerState<AppLockScreen> {
  bool _confirmingLogout = false;
  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    // 一出現就喚起系統驗證；之後取消或失敗改由按鈕重試。
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  void _unlock() {
    if (mounted) unawaited(ref.read(appLockProvider.notifier).unlock());
  }

  Future<void> _askLogout() async {
    final pending = (await ref.read(cacheStoreProvider).readQueue()).length;
    if (!mounted) return;
    setState(() {
      _pendingCount = pending;
      _confirmingLogout = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = ref.watch(appLockKindProvider).value.lockLabel;
    return Stack(
      children: [
        Positioned.fill(
          child: Material(
            color: theme.colorScheme.surface,
            child: SafeArea(
              child: Center(
                // 最大字級下內容比螢幕高時改成可捲動，不溢出也不縮字。
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(TpSpacing.s6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        CupertinoIcons.lock_fill,
                        size: 48,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: TpSpacing.s4),
                      Text(
                        'Tripline 已鎖定',
                        style: theme.textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: TpSpacing.s2),
                      Text(
                        '解鎖後繼續使用',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: TpSpacing.s6),
                      TpFilledButton(label: '使用 $label 解鎖', onPressed: _unlock),
                      const SizedBox(height: TpSpacing.s2),
                      CupertinoButton(
                        minimumSize: const Size.square(TpSpacing.tapMin),
                        onPressed: () => unawaited(_askLogout()),
                        child: Text(
                          '登出',
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (_confirmingLogout)
          Positioned.fill(
            child: _HostDialog(
              dialogKey: const ValueKey('app-lock-logout-dialog'),
              title: '登出帳號',
              message: _pendingCount == 0
                  ? '確定要登出嗎？'
                  : '還有 $_pendingCount 筆變更尚未同步，登出後會遺失。確定要登出嗎？',
              cancelLabel: '取消',
              confirmLabel: '登出',
              destructive: true,
              onCancel: () => setState(() => _confirmingLogout = false),
              onConfirm: () {
                setState(() => _confirmingLogout = false);
                unawaited(ref.read(authStateProvider.notifier).logout());
              },
            ),
          ),
      ],
    );
  }
}
