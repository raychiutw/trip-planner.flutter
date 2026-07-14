/// Developer OAuth apps screens.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_error.dart';
import '../../api/providers.dart';
import '../../app/app_loading_skeleton.dart';
import '../../models/oauth.dart';
import '../../theme/tokens.dart';

/// 開發者 OAuth apps 清單（GET /dev/apps）。
final developerAppsProvider = FutureProvider<List<DeveloperApp>>((ref) {
  return ref.watch(tripRepositoryProvider).fetchDeveloperApps();
});

class DeveloperAppsScreen extends ConsumerWidget {
  const DeveloperAppsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appsAsync = ref.watch(developerAppsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('開發者應用'),
        actions: [
          IconButton(
            key: const Key('developer-apps-new'),
            tooltip: '新增 OAuth 應用',
            onPressed: () =>
                GoRouter.maybeOf(context)?.go('/settings/developer-apps/new'),
            icon: const Icon(CupertinoIcons.add),
          ),
        ],
      ),
      body: appsAsync.when(
        loading: () => const AppListLoadingSkeleton(
          key: ValueKey('developer-apps-loading'),
          itemCount: 3,
        ),
        error: (error, stackTrace) => _DeveloperAppsLoadError(
          onRetry: () => ref.invalidate(developerAppsProvider),
        ),
        data: (apps) => RefreshIndicator.adaptive(
          onRefresh: () async => ref.invalidate(developerAppsProvider),
          child: ListView(
            padding: const EdgeInsets.all(TpSpacing.s4),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              if (apps.isEmpty)
                const _EmptyDeveloperAppsState()
              else
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (var index = 0; index < apps.length; index++) ...[
                        _DeveloperAppTile(app: apps[index]),
                        if (index != apps.length - 1)
                          Divider(
                            height: 1,
                            thickness: 1,
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class DeveloperAppNewScreen extends ConsumerStatefulWidget {
  const DeveloperAppNewScreen({super.key});

  @override
  ConsumerState<DeveloperAppNewScreen> createState() =>
      _DeveloperAppNewScreenState();
}

class _DeveloperAppNewScreenState extends ConsumerState<DeveloperAppNewScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _homepageController = TextEditingController();
  final _redirectUrisController = TextEditingController();
  final Set<String> _selectedScopes = {'openid', 'profile'};
  String _clientType = 'public';
  bool _isSubmitting = false;
  String? _errorText;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _homepageController.dispose();
    _redirectUrisController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('新增 OAuth 應用')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(TpSpacing.s4),
          children: [
            if (_errorText != null) ...[
              _InlineErrorPanel(message: _errorText!),
              const SizedBox(height: TpSpacing.s4),
            ],
            Text(
              '基本資料',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: TpSpacing.s2),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(TpSpacing.s4),
                child: Column(
                  children: [
                    TextFormField(
                      key: const Key('developer-app-name'),
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: '應用程式名稱'),
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        final length = value?.trim().length ?? 0;
                        if (length < 2 || length > 80) return '名稱需 2-80 字';
                        return null;
                      },
                    ),
                    const SizedBox(height: TpSpacing.s3),
                    TextFormField(
                      key: const Key('developer-app-description'),
                      controller: _descriptionController,
                      decoration: const InputDecoration(labelText: '描述（選填）'),
                      maxLines: 2,
                    ),
                    const SizedBox(height: TpSpacing.s3),
                    TextFormField(
                      key: const Key('developer-app-homepage'),
                      controller: _homepageController,
                      decoration: const InputDecoration(
                        labelText: '首頁 URL（選填）',
                      ),
                      keyboardType: TextInputType.url,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: TpSpacing.s4),
            Text(
              'OAuth 設定',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: TpSpacing.s2),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(TpSpacing.s4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'public',
                          icon: Icon(CupertinoIcons.globe),
                          label: Text('Public'),
                        ),
                        ButtonSegment(
                          value: 'confidential',
                          icon: Icon(CupertinoIcons.lock),
                          label: Text('Confidential'),
                        ),
                      ],
                      selected: {_clientType},
                      onSelectionChanged: (selection) {
                        setState(() {
                          _clientType = selection.single;
                        });
                      },
                    ),
                    const SizedBox(height: TpSpacing.s4),
                    TextFormField(
                      key: const Key('developer-app-redirect-uris'),
                      controller: _redirectUrisController,
                      decoration: const InputDecoration(
                        labelText: 'Redirect URI',
                        helperText: '每行一個 URI',
                      ),
                      keyboardType: TextInputType.url,
                      minLines: 2,
                      maxLines: 4,
                      validator: (value) {
                        if (_redirectUris(value ?? '').isEmpty) {
                          return '至少需要一個 Redirect URI';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: TpSpacing.s4),
                    Text(
                      'Scopes',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: TpSpacing.s1),
                    for (final scope in kDeveloperAllowedScopes)
                      CheckboxListTile(
                        key: Key('developer-app-scope-$scope'),
                        contentPadding: EdgeInsets.zero,
                        title: Text(scope),
                        subtitle: Text(oauthScopeLabel(scope)),
                        value: _selectedScopes.contains(scope),
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              _selectedScopes.add(scope);
                            } else {
                              _selectedScopes.remove(scope);
                            }
                          });
                        },
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: TpSpacing.s5),
            FilledButton.icon(
              key: const Key('developer-app-create-submit'),
              onPressed: _isSubmitting ? null : () => unawaited(_submit()),
              icon: _isSubmitting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                    )
                  : const Icon(CupertinoIcons.add),
              label: const Text('建立應用程式'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final allowedScopes = kDeveloperAllowedScopes
        .where(_selectedScopes.contains)
        .toList();
    if (allowedScopes.isEmpty) {
      setState(() {
        _errorText = '至少需要一個 scope';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });
    try {
      final created = await ref
          .read(tripRepositoryProvider)
          .createDeveloperApp(
            appName: _nameController.text.trim(),
            clientType: _clientType,
            redirectUris: _redirectUris(_redirectUrisController.text),
            allowedScopes: allowedScopes,
            appDescription: _trimmedOrNull(_descriptionController.text),
            homepageUrl: _trimmedOrNull(_homepageController.text),
          );
      if (!mounted) return;
      ref.invalidate(developerAppsProvider);
      HapticFeedback.lightImpact();
      setState(() {
        _isSubmitting = false;
      });
      await _showCreatedDialog(created);
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

  Future<void> _showCreatedDialog(CreatedDeveloperApp app) async {
    await showAdaptiveDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog.adaptive(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(TpRadius.xl)),
        ),
        title: const Text('應用建立成功'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              app.clientSecret == null
                  ? 'Client ID 已產生'
                  : '請立即複製 client_secret',
            ),
            const SizedBox(height: TpSpacing.s3),
            const Text('Client ID'),
            const SizedBox(height: TpSpacing.s1),
            _SecretValueRow(
              value: app.clientId,
              copyKey: const Key('developer-app-copy-client-id'),
              onCopy: () => unawaited(_copyToClipboard(app.clientId)),
            ),
            if (app.clientSecret != null) ...[
              const SizedBox(height: TpSpacing.s3),
              const Text('Client Secret'),
              const SizedBox(height: TpSpacing.s1),
              _SecretValueRow(
                value: app.clientSecret!,
                copyKey: const Key('developer-app-copy-client-secret'),
                onCopy: () => unawaited(_copyToClipboard(app.clientSecret!)),
              ),
              const SizedBox(height: TpSpacing.s2),
              Text(
                '此 secret 不會再顯示，請存到密碼管理器或環境變數。',
                style: Theme.of(dialogContext).textTheme.bodySmall?.copyWith(
                  color: Theme.of(dialogContext).colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: TpSpacing.s3),
            Text(app.statusLabel),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              GoRouter.maybeOf(context)?.go('/settings/developer-apps');
            },
            key: const Key('developer-app-secret-acknowledge'),
            child: const Text('我已複製，繼續'),
          ),
        ],
      ),
    );
  }

  Future<void> _copyToClipboard(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
  }

  List<String> _redirectUris(String value) {
    return value
        .split(RegExp(r'[\r\n]+'))
        .map((uri) => uri.trim())
        .where((uri) => uri.isNotEmpty)
        .toList();
  }

  String? _trimmedOrNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String _errorMessage(Object error) {
    if (error is ApiError) return error.detail ?? error.message;
    return '建立應用程式失敗，請稍後再試';
  }
}

class _SecretValueRow extends StatelessWidget {
  const _SecretValueRow({
    required this.value,
    required this.copyKey,
    required this.onCopy,
  });

  final String value;
  final Key copyKey;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: const BorderRadius.all(Radius.circular(TpRadius.md)),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: TpSpacing.s3,
          vertical: TpSpacing.s2,
        ),
        child: Row(
          children: [
            Expanded(
              child: SelectableText(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            IconButton(
              key: copyKey,
              tooltip: '複製',
              onPressed: onCopy,
              icon: const Icon(Icons.copy_outlined),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeveloperAppTile extends StatelessWidget {
  const _DeveloperAppTile({required this.app});

  final DeveloperApp app;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      key: Key('developer-app-row-${app.clientId}'),
      leading: const Icon(
        CupertinoIcons.chevron_left_slash_chevron_right,
        size: 22,
      ),
      title: Text(app.appName),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: TpSpacing.s1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(app.clientId),
            const SizedBox(height: TpSpacing.s1),
            Text(
              '${app.clientTypeLabel} · ${app.redirectUris.join(', ')}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      trailing: _StatusChip(label: app.statusLabel),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TpSpacing.s2,
        vertical: TpSpacing.s1,
      ),
      decoration: ShapeDecoration(
        color: colorScheme.secondaryContainer,
        shape: const StadiumBorder(),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }
}

class _DeveloperAppsLoadError extends StatelessWidget {
  const _DeveloperAppsLoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(TpSpacing.s4),
      children: [
        Card(
          color: Theme.of(context).colorScheme.errorContainer,
          child: Padding(
            padding: const EdgeInsets.all(TpSpacing.s4),
            child: Row(
              children: [
                const Expanded(child: Text('無法載入開發者應用')),
                TextButton(onPressed: onRetry, child: const Text('重試')),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _InlineErrorPanel extends StatelessWidget {
  const _InlineErrorPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      color: colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(TpSpacing.s4),
        child: Row(
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
    );
  }
}

class _EmptyDeveloperAppsState extends StatelessWidget {
  const _EmptyDeveloperAppsState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: TpSpacing.s8),
      child: Center(child: Text('目前沒有開發者應用')),
    );
  }
}
