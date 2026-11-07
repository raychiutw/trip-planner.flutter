/// 無密碼帳號的刪除對話框：確認影響 → 以 Google 重新驗證 → 伺服器確認 verified 才送刪除。
/// 開瀏覽器與等 https callback 沿用登入的 [AuthorizationLauncher]；callback 網址只是返回訊號，
/// 驗證是否成功一律以伺服器的 challenge 狀態為準。
library;

import 'package:flutter/cupertino.dart';

import '../../api/api_error.dart';
import '../../api/auth_repository.dart';
import '../../api/oauth/oauth_config.dart';
import '../../api/oauth/oauth_login_service.dart';
import '../../app/adaptive.dart' show tpDestructiveActionStyle;
import '../../theme/tokens.dart';

enum _Phase { confirm, working, failed }

class DeleteReauthDialog extends StatefulWidget {
  const DeleteReauthDialog({
    super.key,
    required this.preview,
    required this.repository,
    required this.launcher,
  });

  final AccountDeletionPreview preview;
  final AuthRepository repository;
  final AuthorizationLauncher launcher;

  @override
  State<DeleteReauthDialog> createState() => _DeleteReauthDialogState();
}

class _DeleteReauthDialogState extends State<DeleteReauthDialog> {
  _Phase _phase = _Phase.confirm;
  String _progress = '';
  String _error = '';

  /// 已 verified、尚未成功刪除的 challenge；刪除遇到網路錯誤時重試沿用它，不必再驗證一次。
  String? _verifiedId;

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _phase = _Phase.failed;
      _error = message;
    });
  }

  void _work(String message) => setState(() {
    _phase = _Phase.working;
    _progress = message;
  });

  Future<void> _run() async {
    if (_phase == _Phase.working) return;
    _work('正在開啟 Google 驗證…');
    try {
      var id = _verifiedId;
      if (id == null) {
        final challenge = await widget.repository.startDeleteReauth();
        id = challenge.challengeId;
        final Uri callback;
        try {
          callback = await widget.launcher.authorize(
            challenge.authorizeUrl,
            callbackHost: OAuthConfig.callbackHost,
            callbackPath: OAuthConfig.callbackPath,
          );
        } on OAuthLoginException catch (e) {
          await _cancelQuietly(id);
          _fail(e.cancelled ? '已取消驗證，沒有刪除任何資料。' : '無法開啟 Google 驗證，沒有刪除任何資料。');
          return;
        }
        if (!mounted) return;
        if (callback.queryParameters['challenge_id'] != id) {
          await _cancelQuietly(id);
          _fail('驗證結果與這次要求不符，沒有刪除任何資料。');
          return;
        }
        _work('正在確認驗證結果…');
        final status = await widget.repository.fetchDeleteReauthStatus(id);
        if (status != 'verified') {
          _fail(_statusMessage(status));
          return;
        }
        _verifiedId = id;
      }
      if (!mounted) return;
      _work('正在刪除帳號…');
      await widget.repository.deleteAccountWithReauth(challengeId: id);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiError catch (e) {
      if (e.code == 'ACCOUNT_DELETE_REAUTH_REQUIRED') {
        _verifiedId = null;
        _fail('驗證已失效，請重新驗證。沒有刪除任何資料。');
      } else {
        _fail('操作失敗，請稍後再試。若帳號仍在，可重試。');
      }
    } on Exception {
      _fail('網路異常，請檢查連線後重試。若帳號仍在，可重試。');
    }
  }

  Future<void> _cancelQuietly(String id) async {
    try {
      await widget.repository.cancelDeleteReauth(id);
    } on Exception {
      // 取消只是收尾；失敗不影響「沒刪除」的結論，challenge 也會自己過期。
    }
  }

  String _statusMessage(String status) => switch (status) {
    'failed' => 'Google 驗證未通過，沒有刪除任何資料。',
    'cancelled' => '驗證已取消，沒有刪除任何資料。',
    'expired' => '驗證已逾時，請重新驗證。沒有刪除任何資料。',
    'used' => '這次驗證已使用，請重新驗證。沒有刪除任何資料。',
    _ => '尚未完成 Google 驗證，沒有刪除任何資料。',
  };

  @override
  Widget build(BuildContext context) {
    final preview = widget.preview;
    final working = _phase == _Phase.working;
    return CupertinoAlertDialog(
      key: const ValueKey('delete-reauth-dialog'),
      title: const Text('永久刪除帳號？'),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: TpSpacing.s2),
          Text(
            '將一併刪除你擁有的 ${preview.tripsOwned} 個行程，'
            '並影響 ${preview.collaboratorsAffected} 位共編者。此操作無法復原。',
          ),
          const SizedBox(height: TpSpacing.s2),
          const Text('此帳號沒有密碼，需先以 Google 重新驗證；驗證成功後會立即刪除。'),
          if (working) ...[
            const SizedBox(height: TpSpacing.s3),
            const CupertinoActivityIndicator(),
            const SizedBox(height: TpSpacing.s2),
            Text(_progress, key: const ValueKey('delete-reauth-progress')),
          ],
          if (_phase == _Phase.failed) ...[
            const SizedBox(height: TpSpacing.s3),
            Text(_error, key: const ValueKey('delete-reauth-error')),
          ],
        ],
      ),
      actions: [
        // 安全選項是預設動作（粗體、Enter 觸發），破壞性動作不是。
        CupertinoDialogAction(
          key: const ValueKey('delete-reauth-cancel-button'),
          isDefaultAction: true,
          onPressed: working ? null : () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        CupertinoDialogAction(
          key: const ValueKey('delete-reauth-start-button'),
          isDestructiveAction: true,
          onPressed: working ? null : _run,
          child: Text(
            _phase == _Phase.failed ? '重試' : '以 Google 驗證並刪除',
            style: working ? null : tpDestructiveActionStyle(context),
          ),
        ),
      ],
    );
  }
}
