/// 變更密碼:已登入、知道目前密碼 → POST /account/password → 回上一頁。
///
/// 成功後後端會登出其他裝置、保留這台。密碼只存在表單控制項與送出當下的請求,
/// 不寫入任何儲存(ADR-0014 對 App 內密碼表單的例外:只用來改密碼,不用來登入)。
/// 與「忘記密碼」(寄信重設)是兩件事。
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/providers.dart';
import '../../../app/adaptive.dart';
import '../../../app/error_message.dart';
import '../../../theme/tokens.dart';
import '../../../ui/tp_app_bar.dart';
import '../../../ui/tp_settings_group.dart';

/// 與後端 `MIN_PASSWORD_LEN` 一致。
const _minPasswordLength = 8;

/// 這個帳號有沒有 local 密碼(GET /account 的 `hasPassword`)。
///
/// 只用 Google 登入的帳號沒有密碼可改,設定頁據此決定要不要顯示「變更密碼」。
/// 取不到就當作沒有(不顯示入口,不影響其他設定)。
final accountHasPasswordProvider = FutureProvider<bool>((ref) async {
  final preview = await ref
      .watch(authRepositoryProvider)
      .fetchAccountDeletionPreview();
  return preview.hasPassword;
});

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  bool _obscureNext = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _current.addListener(_rebuild);
    _next.addListener(_rebuild);
  }

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    super.dispose();
  }

  void _rebuild() => setState(() => _error = null);

  /// 新密碼欄位的就地提示;空白時不提示(還沒開始填)。
  String? get _nextError {
    final value = _next.text;
    if (value.isEmpty) return null;
    if (value.length < _minPasswordLength) {
      return '新密碼至少 $_minPasswordLength 字元';
    }
    if (value == _current.text) return '新密碼不能和目前密碼相同';
    return null;
  }

  bool get _canSubmit =>
      !_submitting &&
      _current.text.isNotEmpty &&
      _next.text.isNotEmpty &&
      _nextError == null;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref
          .read(accountRepositoryProvider)
          .changePassword(
            currentPassword: _current.text,
            newPassword: _next.text,
          );
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = userFacingApiError(
          error,
          fallback: '無法變更密碼，請稍後再試',
          byCode: const {
            'CHANGE_PASSWORD_CURRENT_INVALID': '目前密碼不正確',
            'CHANGE_PASSWORD_RATE_LIMITED': '嘗試次數過多，請稍後再試',
            'CHANGE_PASSWORD_NO_PASSWORD': '此帳號以 Google 登入，沒有設定密碼',
          },
        );
      });
      return;
    }
    if (!mounted) return;
    HapticFeedback.lightImpact();
    showAppNotice(context, '密碼已更新，其他裝置已登出');
    final navigator = Navigator.of(context);
    if (navigator.canPop()) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TpAppBar(
        role: TpAppBarRole.modalForm,
        title: const Text('變更密碼'),
        onCancel: () => Navigator.of(context).maybePop(),
        primaryActionLabel: '變更',
        primaryActionKey: const ValueKey('change-password-submit'),
        primaryActionEnabled: _canSubmit,
        onPrimaryAction: _submit,
      ),
      body: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          TpSettingsGroup(
            title: '密碼',
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: TpSpacing.s4,
                  vertical: TpSpacing.s2,
                ),
                child: TextField(
                  key: const ValueKey('change-password-current'),
                  controller: _current,
                  obscureText: true,
                  enabled: !_submitting,
                  autofocus: true,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.password],
                  decoration: const InputDecoration(
                    labelText: '目前密碼',
                    border: InputBorder.none,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: TpSpacing.s4,
                  vertical: TpSpacing.s2,
                ),
                child: TextField(
                  key: const ValueKey('change-password-new'),
                  controller: _next,
                  obscureText: _obscureNext,
                  enabled: !_submitting,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.newPassword],
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: '新密碼',
                    helperText: '至少 $_minPasswordLength 字元。變更後其他裝置會登出,這台維持登入。',
                    border: InputBorder.none,
                    errorText: _nextError,
                    suffixIcon: IconButton(
                      key: const ValueKey('change-password-visibility-toggle'),
                      tooltip: _obscureNext ? '顯示密碼' : '隱藏密碼',
                      icon: Icon(
                        _obscureNext
                            ? CupertinoIcons.eye
                            : CupertinoIcons.eye_slash,
                      ),
                      onPressed: () =>
                          setState(() => _obscureNext = !_obscureNext),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: TpSpacing.s4),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
