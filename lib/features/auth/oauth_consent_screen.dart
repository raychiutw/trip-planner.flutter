/// OAuth consent screen.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_error.dart';
import '../../api/providers.dart';
import '../../models/oauth.dart';
import '../../theme/tokens.dart';
import '../../ui/tp_app_bar.dart';

class OAuthConsentScreen extends ConsumerStatefulWidget {
  const OAuthConsentScreen({super.key, required this.request});

  final OAuthConsentRequest request;

  @override
  ConsumerState<OAuthConsentScreen> createState() => _OAuthConsentScreenState();
}

class _OAuthConsentScreenState extends ConsumerState<OAuthConsentScreen> {
  bool _isSubmitting = false;
  String? _clientName;
  OAuthConsentResult? _result;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    unawaited(_loadClientName());
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    return Scaffold(
      appBar: TpAppBar(
        role: TpAppBarRole.modalForm,
        title: const Text('授權請求'),
        onCancel: request.isComplete
            ? () => unawaited(_submit('deny'))
            : () => closeAppRouteOrSheet(context),
        primaryActionLabel: _isSubmitting ? '授權中…' : '同意',
        primaryActionKey: const Key('oauth-consent-allow'),
        onPrimaryAction: () => unawaited(_submit('allow')),
        primaryActionEnabled: request.isComplete && !_isSubmitting,
      ),
      body: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.all(TpSpacing.s4),
        children: [
          if (!request.isComplete) ...[
            const _ConsentErrorPanel(message: '授權請求缺少必要參數或 redirect URI 格式不正確'),
            const SizedBox(height: TpSpacing.s4),
          ],
          if (_errorText != null) ...[
            _ConsentErrorPanel(message: _errorText!),
            const SizedBox(height: TpSpacing.s4),
          ],
          if (_result != null) ...[
            _ConsentResultPanel(result: _result!),
            const SizedBox(height: TpSpacing.s4),
          ],
          Card(
            child: Padding(
              padding: const EdgeInsets.all(TpSpacing.s4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _clientName ?? '未知應用程式 (client_id=${request.clientId})',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: TpSpacing.s2),
                  Text('Redirect URI：${request.redirectUri}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: TpSpacing.s4),
          Text(
            '要求權限',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: TpSpacing.s2),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final scope in request.requestedScopes)
                  ListTile(
                    leading: Icon(
                      _isKnownScope(scope)
                          ? CupertinoIcons.checkmark_circle
                          : CupertinoIcons.exclamationmark_triangle,
                      size: 20,
                    ),
                    title: Text(oauthScopeLabel(scope)),
                    subtitle: Text(scope),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadClientName() async {
    try {
      final name = await ref
          .read(authRepositoryProvider)
          .fetchOAuthClientName(widget.request.clientId);
      if (mounted && name != null) setState(() => _clientName = name);
    } catch (_) {
      // 未知或停用的 client 保留明確的未驗證 fallback，不阻擋 consent。
    }
  }

  Future<void> _submit(String decision) async {
    if (_isSubmitting) return;
    setState(() {
      _isSubmitting = true;
      _result = null;
      _errorText = null;
    });
    try {
      final result = await ref
          .read(authRepositoryProvider)
          .submitOAuthConsent(widget.request, decision: decision);
      if (!mounted) return;
      setState(() {
        _result = result;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorText = _errorMessage(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  String _errorMessage(Object error) {
    if (error is ApiError) return error.detail ?? error.message;
    return '送出授權失敗，請稍後再試';
  }

  bool _isKnownScope(String scope) => oauthScopeLabel(scope) != scope;
}

class _ConsentResultPanel extends StatelessWidget {
  const _ConsentResultPanel({required this.result});

  final OAuthConsentResult result;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      key: const ValueKey('oauth-consent-result'),
      container: true,
      liveRegion: true,
      child: Card(
        color: colorScheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(TpSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '已送出授權',
                style: TextStyle(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: TpSpacing.s2),
              Text(result.redirectLocation ?? '沒有 redirect location'),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConsentErrorPanel extends StatelessWidget {
  const _ConsentErrorPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      key: const ValueKey('oauth-consent-error'),
      container: true,
      liveRegion: true,
      child: Card(
        color: colorScheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(TpSpacing.s4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                CupertinoIcons.exclamationmark_circle,
                color: colorScheme.onErrorContainer,
              ),
              const SizedBox(width: TpSpacing.s3),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(color: colorScheme.onErrorContainer),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
