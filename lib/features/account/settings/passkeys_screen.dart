/// 帳號 → 安全性 → Passkey：白話說明、列表、新增、改名、撤銷（ADR-0016）。
///
/// 新增三步：問名稱 → `register/options` → 原生層建立 → `register/verify`。
/// 原生層取消或失敗時不會呼叫 verify，後端沒有任何東西被建立（挑戰逾時自動作廢）。
library;

import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/providers.dart';
import '../../../app/adaptive.dart';
import '../../../app/adaptive_content.dart';
import '../../../app/app_feedback.dart';
import '../../../app/app_loading_skeleton.dart';
import '../../../app/error_message.dart';
import '../../../app/irreversible_action.dart';
import '../../../app/passkey_login.dart' show markPasskeyLoginHint;
import '../../../app/passkey_platform.dart';
import '../../../models/display_format.dart';
import '../../../models/passkey.dart';
import '../../../theme/tokens.dart';
import '../../../ui/tp_app_bar.dart';
import '../../../ui/tp_content_surface.dart';
import '../../../ui/tp_settings_group.dart';

/// GET /account/passkeys。
final passkeysProvider = FutureProvider.autoDispose<List<Passkey>>(
  (ref) => ref.watch(passkeyRepositoryProvider).list(),
);

const _passkeyErrorByCode = {
  'PASSKEY_ALREADY_REGISTERED': '這組 passkey 已經註冊過，不需要重複新增',
  'PASSKEY_CHALLENGE_INVALID': '驗證已逾時，請再試一次',
  'PASSKEY_ORIGIN_MISMATCH': '無法驗證這個 App 的來源，請更新 App 後再試',
  'PASSKEY_UV_REQUIRED': '需要通過 Face ID、指紋或裝置密碼驗證，請再試一次',
  'PASSKEY_REGISTRATION_INVALID': '這組 passkey 無法註冊，請再試一次',
  'PASSKEY_NOT_FOUND': '找不到這組 passkey，可能已經移除',
};

class PasskeysScreen extends ConsumerStatefulWidget {
  const PasskeysScreen({super.key});

  @override
  ConsumerState<PasskeysScreen> createState() => _PasskeysScreenState();
}

class _PasskeysScreenState extends ConsumerState<PasskeysScreen> {
  bool _busy = false;

  String get _defaultName => defaultTargetPlatform == TargetPlatform.android
      ? '我的 Android 手機'
      : '我的 iPhone';

  /// 取名表單；回傳 null 代表使用者放棄。[allowEmpty] 時留空回空字串（交給呼叫端用預設名）。
  Future<String?> _askName({
    required String title,
    required String submitLabel,
    required String initial,
    required bool allowEmpty,
  }) async {
    var value = initial;
    final form = AppSheetFormController()
      ..attach(() async => true)
      ..update(canSubmit: allowEmpty || initial.trim().isNotEmpty);
    try {
      final submitted = await showAppFormSheet(
        context,
        title: title,
        submitLabel: submitLabel,
        submitKey: const ValueKey('passkey-name-submit'),
        controller: form,
        builder: (_) => _NameForm(
          initial: initial,
          onChanged: (text) {
            value = text;
            form.update(
              dirty: true,
              canSubmit: allowEmpty || text.trim().isNotEmpty,
            );
          },
          onSubmit: form.requestSubmit,
        ),
      );
      return (submitted ?? false) ? value.trim() : null;
    } finally {
      form.dispose();
    }
  }

  Future<void> _add() async {
    final asked = await _askName(
      title: '新增 passkey',
      submitLabel: '繼續',
      initial: _defaultName,
      allowEmpty: true,
    );
    if (asked == null || !mounted) return;
    final name = asked.isEmpty ? _defaultName : asked;

    setState(() => _busy = true);
    try {
      final repo = ref.read(passkeyRepositoryProvider);
      final options = await repo.registerOptions();
      final outcome = await ref.read(passkeyPlatformProvider).create(options);
      if (!mounted) return;
      switch (outcome) {
        case PasskeyCreated(:final credential):
          await repo.registerVerify(credential: credential, name: name);
          if (!mounted) return;
          ref.invalidate(passkeysProvider);
          // 登出後登入頁靠這個旗標顯示 passkey 入口（見 passkey_login.dart）。
          unawaited(markPasskeyLoginHint(ref.read(settingsStoreProvider)));
          showAppNotice(context, '已新增 passkey');
        case PasskeyCancelled():
          showAppNotice(context, '已取消新增 passkey');
        case PasskeyAlreadyOnDevice():
          showAppError(context, '這支裝置已經有這個帳號的 passkey，不需要重複新增');
        case PasskeyCreateFailed():
          showAppError(
            context,
            '無法建立 passkey，請確認這支裝置已設定螢幕鎖定（Face ID、指紋或裝置密碼）後再試',
            onRetry: () => unawaited(_add()),
          );
      }
    } on Exception catch (error) {
      if (!mounted) return;
      showAppError(
        context,
        userFacingApiError(
          error,
          fallback: '新增 passkey 失敗，請稍後再試',
          byCode: _passkeyErrorByCode,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rename(Passkey passkey) async {
    final name = await _askName(
      title: '重新命名',
      submitLabel: '儲存',
      initial: passkey.name,
      allowEmpty: false,
    );
    if (name == null || !mounted) return;
    try {
      await ref.read(passkeyRepositoryProvider).rename(passkey.id, name);
      if (!mounted) return;
      ref.invalidate(passkeysProvider);
    } on Exception catch (error) {
      if (!mounted) return;
      showAppError(
        context,
        userFacingApiError(
          error,
          fallback: '重新命名失敗，請稍後再試',
          byCode: _passkeyErrorByCode,
        ),
        onRetry: () => unawaited(_rename(passkey)),
      );
    }
  }

  Future<void> _revoke(Passkey passkey) {
    return confirmAndRunIrreversibleAction(
      context,
      source: TpDestructiveConfirmSource.direct,
      title: '撤銷「${passkey.name}」？',
      message: '撤銷後這組 passkey 就不能再用來登入，這項操作無法復原。其他裝置的登入狀態不受影響；需要時可以重新新增。',
      actionLabel: '撤銷',
      progressLabel: '正在撤銷…',
      successMessage: '已撤銷 passkey',
      failureMessage: '撤銷失敗，這組 passkey 仍然有效',
      action: () async {
        await ref.read(passkeyRepositoryProvider).revoke(passkey.id);
        return true;
      },
      onSuccess: () => ref.invalidate(passkeysProvider),
    );
  }

  @override
  Widget build(BuildContext context) {
    final passkeys = ref.watch(passkeysProvider);
    return Scaffold(
      appBar: const TpAppBar(role: TpAppBarRole.detail, title: Text('Passkey')),
      body: AppAdaptiveContent(
        maxWidth: AppContentWidth.form,
        child: passkeys.when(
          loading: () => const AppListLoadingSkeleton(
            key: ValueKey('passkeys-loading'),
            itemCount: 2,
          ),
          error: (error, stackTrace) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('無法載入 passkey'),
                TextButton(
                  key: const ValueKey('passkeys-retry'),
                  onPressed: () => ref.invalidate(passkeysProvider),
                  child: const Text('重試'),
                ),
              ],
            ),
          ),
          data: (items) => ListView(
            padding: const EdgeInsets.all(TpSpacing.s4),
            children: [
              const _Explainer(),
              const SizedBox(height: TpSpacing.s4),
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: TpSpacing.s4),
                  child: Center(child: Text('還沒有 passkey')),
                )
              else
                TpGroupedSurface(
                  separatorIndent: 0,
                  separatorEndIndent: 0,
                  children: [
                    for (final passkey in items)
                      _PasskeyTile(
                        passkey: passkey,
                        onRename: () => unawaited(_rename(passkey)),
                        onRevoke: () => unawaited(_revoke(passkey)),
                      ),
                  ],
                ),
              const SizedBox(height: TpSpacing.s4),
              FilledButton(
                key: const ValueKey('passkey-add'),
                onPressed: _busy ? null : () => unawaited(_add()),
                child: const Text('新增 passkey'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Explainer extends StatelessWidget {
  const _Explainer();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return TpContentSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('什麼是 passkey', style: textTheme.titleSmall),
          const SizedBox(height: TpSpacing.s2),
          const Text(
            'passkey 用裝置安全晶片裡的私鑰取代密碼：登入時用 Face ID、Touch ID 或指紋確認是你本人，網路上不會傳送任何密碼。',
          ),
          const SizedBox(height: TpSpacing.s2),
          const Text(
            '私鑰只留在你的裝置，可同步的 passkey 會存在 iCloud 鑰匙圈或 Google 密碼管理員；Tripline 的伺服器只保存公鑰。',
          ),
          const SizedBox(height: TpSpacing.s2),
          const Text('裝置沒有生物辨識時，會改用裝置密碼確認。原本的密碼登入仍然可以使用。'),
          const SizedBox(height: TpSpacing.s2),
          const Text('新增或撤銷 passkey 時，會寄通知信到你的信箱。'),
        ],
      ),
    );
  }
}

class _PasskeyTile extends StatelessWidget {
  const _PasskeyTile({
    required this.passkey,
    required this.onRename,
    required this.onRevoke,
  });

  final Passkey passkey;
  final VoidCallback onRename;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    final created = passkey.createdAt;
    final lastUsed = passkey.lastUsedAt;
    final subtitle = [
      if (created != null) '建立於 ${formatUtcTimestamp(created)}',
      lastUsed == null ? '尚未使用' : '最後使用 ${formatUtcTimestamp(lastUsed)}',
    ].join(' · ');
    return ListTile(
      key: ValueKey('passkey-row-${passkey.id}'),
      leading: const Icon(CupertinoIcons.person_crop_circle_badge_checkmark),
      title: Text(passkey.name),
      subtitle: Text(subtitle),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: ValueKey('passkey-rename-${passkey.id}'),
            tooltip: '重新命名 ${passkey.name}',
            icon: const Icon(CupertinoIcons.pencil),
            onPressed: onRename,
          ),
          IconButton(
            key: ValueKey('passkey-revoke-${passkey.id}'),
            tooltip: '撤銷 ${passkey.name}',
            icon: const Icon(CupertinoIcons.trash),
            onPressed: onRevoke,
          ),
        ],
      ),
    );
  }
}

class _NameForm extends StatefulWidget {
  const _NameForm({
    required this.initial,
    required this.onChanged,
    required this.onSubmit,
  });

  final String initial;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmit;

  @override
  State<_NameForm> createState() => _NameFormState();
}

class _NameFormState extends State<_NameForm> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(TpSpacing.s4),
    child: TextField(
      key: const ValueKey('passkey-name-field'),
      controller: _controller,
      autofocus: true,
      maxLength: 50,
      textInputAction: TextInputAction.done,
      decoration: const InputDecoration(
        labelText: '名稱',
        hintText: '例如：我的 iPhone、公司筆電',
      ),
      onChanged: widget.onChanged,
      onSubmitted: (_) => widget.onSubmit(),
    ),
  );
}
