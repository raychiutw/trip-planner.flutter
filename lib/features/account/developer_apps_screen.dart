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
import '../../app/adaptive.dart';
import '../../app/app_loading_skeleton.dart';
import '../../models/oauth.dart';
import '../../theme/tokens.dart';
import '../../ui/tp_app_bar.dart';

/// 開發者 OAuth apps 清單（GET /dev/apps）。
final developerAppsProvider = FutureProvider<List<DeveloperApp>>((ref) {
  return ref.watch(tripRepositoryProvider).fetchDeveloperApps();
});

/// 單一開發者 OAuth app，供編輯頁保留 loading/error 與返回出口。
final developerAppProvider = FutureProvider.family<DeveloperApp, String>((
  ref,
  clientId,
) {
  return ref.watch(tripRepositoryProvider).fetchDeveloperApp(clientId);
});

class DeveloperAppsScreen extends ConsumerWidget {
  const DeveloperAppsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appsAsync = ref.watch(developerAppsProvider);
    return Scaffold(
      appBar: TpAppBar(
        role: TpAppBarRole.detail,
        title: const Text('開發者應用'),
        actions: [
          TpToolbarIconButton(
            key: const Key('developer-apps-new'),
            tooltip: '新增 OAuth 應用',
            onPressed: () {
              if (TpLargeSheetNavigationScope.maybeOf(context) != null) {
                unawaited(
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const DeveloperAppNewScreen(),
                    ),
                  ),
                );
              } else {
                unawaited(
                  GoRouter.maybeOf(
                        context,
                      )?.push<void>('/settings/developer-apps/new') ??
                      Future<void>.value(),
                );
              }
            },
            icon: CupertinoIcons.add,
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
                        _DeveloperAppTile(
                          app: apps[index],
                          onTap: () => unawaited(
                            Navigator.of(context).push<void>(
                              MaterialPageRoute<void>(
                                builder: (_) => DeveloperAppEditScreen(
                                  clientId: apps[index].clientId,
                                ),
                              ),
                            ),
                          ),
                        ),
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

class DeveloperAppNewScreen extends _DeveloperAppFormScreen {
  const DeveloperAppNewScreen({super.key});
}

/// 載入並編輯既有 OAuth app；所有狀態都保留同一個 Account stack 出口。
class DeveloperAppEditScreen extends ConsumerWidget {
  const DeveloperAppEditScreen({super.key, required this.clientId});

  final String clientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appAsync = ref.watch(developerAppProvider(clientId));
    return appAsync.when(
      loading: () => const Scaffold(
        appBar: TpAppBar(role: TpAppBarRole.detail, title: Text('編輯 OAuth 應用')),
        body: AppListLoadingSkeleton(
          key: ValueKey('developer-app-edit-loading'),
          itemCount: 4,
        ),
      ),
      error: (error, stackTrace) => Scaffold(
        appBar: const TpAppBar(
          role: TpAppBarRole.detail,
          title: Text('編輯 OAuth 應用'),
        ),
        body: _DeveloperAppsLoadError(
          message: '無法載入應用程式',
          onRetry: () => ref.invalidate(developerAppProvider(clientId)),
        ),
      ),
      data: (app) => _DeveloperAppFormScreen(app: app),
    );
  }
}

class _DeveloperAppFormScreen extends ConsumerStatefulWidget {
  const _DeveloperAppFormScreen({super.key, this.app});

  final DeveloperApp? app;

  @override
  ConsumerState<_DeveloperAppFormScreen> createState() =>
      _DeveloperAppFormScreenState();
}

class _DeveloperAppFormScreenState
    extends ConsumerState<_DeveloperAppFormScreen> {
  final _dismissController = AppUnsavedChangesController();
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _homepageController;
  late final TextEditingController _redirectUrisController;
  final _nameFocusNode = FocusNode();
  final _descriptionFocusNode = FocusNode();
  final _homepageFocusNode = FocusNode();
  final _redirectUrisFocusNode = FocusNode();
  late final Set<String> _selectedScopes;
  late String _clientType;
  late DeveloperApp? _baselineApp;
  bool _isSubmitting = false;
  bool _isDeleting = false;
  bool _completed = false;
  String? _errorText;

  DeveloperApp? get _app => _baselineApp;

  String get _pendingLabel {
    if (_isDeleting) return '正在刪除應用程式';
    return _app == null ? '正在建立應用程式' : '正在儲存應用程式';
  }

  bool get _hasChanges {
    final app = _app;
    if (app == null) {
      return _nameController.text.isNotEmpty ||
          _descriptionController.text.isNotEmpty ||
          _homepageController.text.isNotEmpty ||
          _redirectUrisController.text.isNotEmpty ||
          _clientType != 'public' ||
          !_sameScopes(const {'openid', 'profile'});
    }
    return _nameController.text != app.appName ||
        _descriptionController.text != (app.appDescription ?? '') ||
        _homepageController.text != (app.homepageUrl ?? '') ||
        _redirectUrisController.text != app.redirectUris.join('\n') ||
        !_sameScopes(app.allowedScopes.toSet());
  }

  bool _sameScopes(Set<String> expected) =>
      _selectedScopes.length == expected.length &&
      _selectedScopes.containsAll(expected);

  @override
  void initState() {
    super.initState();
    _baselineApp = widget.app;
    final app = _app;
    _nameController = TextEditingController(text: app?.appName);
    _descriptionController = TextEditingController(text: app?.appDescription);
    _homepageController = TextEditingController(text: app?.homepageUrl);
    _redirectUrisController = TextEditingController(
      text: app?.redirectUris.join('\n'),
    );
    _selectedScopes = {
      ...?app?.allowedScopes,
      if (app == null) 'openid',
      if (app == null) 'profile',
    };
    _clientType = app?.clientType ?? 'public';
    for (final controller in [
      _nameController,
      _descriptionController,
      _homepageController,
      _redirectUrisController,
    ]) {
      controller.addListener(_formChanged);
    }
  }

  void _formChanged() => setState(() {});

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _homepageController.dispose();
    _redirectUrisController.dispose();
    _nameFocusNode.dispose();
    _descriptionFocusNode.dispose();
    _homepageFocusNode.dispose();
    _redirectUrisFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppUnsavedChangesGuard(
      controller: _dismissController,
      hasChanges: !_completed && _hasChanges,
      dismissalEnabled: !_isSubmitting,
      child: Scaffold(
        appBar: TpAppBar(
          role: TpAppBarRole.modalForm,
          title: Text(_app == null ? '新增 OAuth 應用' : '編輯 OAuth 應用'),
          onCancel: _dismissController.requestPop,
          primaryActionLabel: _app == null ? '建立' : '儲存',
          primaryActionKey: Key(
            _app == null
                ? 'developer-app-create-submit'
                : 'developer-app-edit-submit',
          ),
          primaryActionEnabled: !_isSubmitting && _hasChanges,
          onPrimaryAction: () => unawaited(_submit()),
        ),
        body: Column(
          children: [
            if (_isSubmitting)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  TpSpacing.s4,
                  TpSpacing.s4,
                  TpSpacing.s4,
                  0,
                ),
                child: Semantics(
                  key: const Key('developer-app-operation-progress'),
                  label: _pendingLabel,
                  container: true,
                  excludeSemantics: true,
                  liveRegion: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const LinearProgressIndicator(),
                      const SizedBox(height: TpSpacing.s2),
                      Text(_pendingLabel),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: Form(
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
                              focusNode: _nameFocusNode,
                              decoration: const InputDecoration(
                                labelText: '應用程式名稱',
                              ),
                              textInputAction: TextInputAction.next,
                              onFieldSubmitted: (_) {
                                _descriptionFocusNode.requestFocus();
                              },
                              validator: (value) {
                                final length = value?.trim().length ?? 0;
                                if (length < 2 || length > 80) {
                                  return '名稱需 2-80 字';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: TpSpacing.s3),
                            TextFormField(
                              key: const Key('developer-app-description'),
                              controller: _descriptionController,
                              focusNode: _descriptionFocusNode,
                              decoration: const InputDecoration(
                                labelText: '描述（選填）',
                              ),
                              maxLines: 2,
                              textInputAction: TextInputAction.next,
                              onFieldSubmitted: (_) {
                                _homepageFocusNode.requestFocus();
                              },
                            ),
                            const SizedBox(height: TpSpacing.s3),
                            TextFormField(
                              key: const Key('developer-app-homepage'),
                              controller: _homepageController,
                              focusNode: _homepageFocusNode,
                              decoration: const InputDecoration(
                                labelText: '首頁 URL（選填）',
                              ),
                              keyboardType: TextInputType.url,
                              textInputAction: TextInputAction.next,
                              onFieldSubmitted: (_) {
                                _redirectUrisFocusNode.requestFocus();
                              },
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
                              onSelectionChanged: _app != null
                                  ? null
                                  : (selection) {
                                      setState(() {
                                        _clientType = selection.single;
                                      });
                                    },
                            ),
                            const SizedBox(height: TpSpacing.s4),
                            TextFormField(
                              key: const Key('developer-app-redirect-uris'),
                              controller: _redirectUrisController,
                              focusNode: _redirectUrisFocusNode,
                              decoration: const InputDecoration(
                                labelText: 'Redirect URI',
                                helperText: '每行一個 URI',
                              ),
                              keyboardType: TextInputType.url,
                              minLines: 2,
                              maxLines: 4,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) {
                                _redirectUrisFocusNode.unfocus();
                              },
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
                    if (_app != null) ...[
                      const SizedBox(height: TpSpacing.s5),
                      FilledButton.icon(
                        key: const Key('developer-app-delete'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(TpSpacing.tapMin),
                          backgroundColor: theme.colorScheme.error,
                          foregroundColor: theme.colorScheme.onError,
                        ),
                        onPressed: _isSubmitting
                            ? null
                            : () => unawaited(_confirmDelete()),
                        icon: const Icon(CupertinoIcons.delete),
                        label: const Text('刪除應用程式'),
                      ),
                    ],
                    const SizedBox(height: TpSpacing.s5),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_isSubmitting || !_hasChanges) return;
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
      _isDeleting = false;
      _errorText = null;
    });
    try {
      final repository = ref.read(tripRepositoryProvider);
      final editingApp = _app;
      if (editingApp != null) {
        final description = _trimmedOrNull(_descriptionController.text);
        final homepage = _trimmedOrNull(_homepageController.text);
        final updated = await repository.updateDeveloperApp(
          clientId: editingApp.clientId,
          appName: _nameController.text.trim(),
          appDescription: description,
          clearAppDescription: description == null,
          homepageUrl: homepage,
          clearHomepageUrl: homepage == null,
          redirectUris: _redirectUris(_redirectUrisController.text),
          allowedScopes: allowedScopes,
        );
        if (!mounted) return;
        _baselineApp = updated;
        ref.invalidate(developerAppsProvider);
        final container = ProviderScope.containerOf(context, listen: false);
        HapticFeedback.lightImpact();
        showAppNotice(context, '已儲存 ${updated.appName}');
        setState(() {
          _isSubmitting = false;
          _completed = true;
        });
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted) return;
        await Navigator.of(context).maybePop();
        container.invalidate(developerAppProvider(editingApp.clientId));
        return;
      }

      final created = await repository.createDeveloperApp(
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
        _clientType = 'public';
        _selectedScopes
          ..clear()
          ..addAll(const {'openid', 'profile'});
      });
      for (final controller in [
        _nameController,
        _descriptionController,
        _homepageController,
        _redirectUrisController,
      ]) {
        controller.clear();
      }
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

  Future<void> _confirmDelete() async {
    final app = _app;
    if (app == null || _isSubmitting) return;
    final confirmed = await showAppConfirm(
      context,
      title: '刪除 ${app.appName}？',
      message: '這會停用 ${app.appName} 的 OAuth 憑證，所有既有連線都將失效。這項操作無法復原。',
      confirmLabel: '刪除',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _isSubmitting = true;
      _isDeleting = true;
      _errorText = null;
    });
    try {
      await ref.read(tripRepositoryProvider).suspendDeveloperApp(app.clientId);
      if (!mounted) return;
      ref.invalidate(developerAppsProvider);
      final container = ProviderScope.containerOf(context, listen: false);
      showAppNotice(context, '已刪除 ${app.appName}');
      setState(() {
        _isSubmitting = false;
        _completed = true;
      });
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      await Navigator.of(context).maybePop();
      container.invalidate(developerAppProvider(app.clientId));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorText = _deleteErrorMessage(error);
        _isSubmitting = false;
        _isDeleting = false;
      });
    }
  }

  Future<void> _showCreatedDialog(CreatedDeveloperApp app) async {
    await showAppContentSheet<void>(
      context,
      title: '應用建立成功',
      builder: (sheetContext) => ListView(
        padding: const EdgeInsets.all(TpSpacing.s4),
        children: [
          Text(
            app.clientSecret == null ? 'Client ID 已產生' : '請立即複製 client_secret',
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
              style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                color: Theme.of(sheetContext).colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: TpSpacing.s3),
          Text(app.statusLabel),
          const SizedBox(height: TpSpacing.s5),
          FilledButton(
            key: const Key('developer-app-secret-acknowledge'),
            onPressed: () => unawaited(closeAppRouteOrSheet(sheetContext)),
            child: const Text('我已複製，繼續'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (TpLargeSheetNavigationScope.maybeOf(context) != null) {
      await Navigator.of(context).maybePop();
    } else {
      GoRouter.maybeOf(context)?.go('/settings/developer-apps');
    }
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
    return _app == null ? '建立應用程式失敗，請稍後再試' : '儲存應用程式失敗，請稍後再試';
  }

  String _deleteErrorMessage(Object error) {
    if (error is ApiError) return error.detail ?? error.message;
    return '刪除應用程式失敗，請稍後再試';
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
  const _DeveloperAppTile({required this.app, required this.onTap});

  final DeveloperApp app;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      key: Key('developer-app-row-${app.clientId}'),
      onTap: onTap,
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
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StatusChip(label: app.statusLabel),
          const SizedBox(width: TpSpacing.s2),
          const Icon(CupertinoIcons.chevron_forward, size: 18),
        ],
      ),
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
  const _DeveloperAppsLoadError({
    this.message = '無法載入開發者應用',
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: const Key('developer-apps-load-error'),
      container: true,
      liveRegion: true,
      child: ListView(
        padding: const EdgeInsets.all(TpSpacing.s4),
        children: [
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(TpSpacing.s4),
              child: Row(
                children: [
                  Expanded(child: Text(message)),
                  TextButton(onPressed: onRetry, child: const Text('重試')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineErrorPanel extends StatelessWidget {
  const _InlineErrorPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Card(
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
