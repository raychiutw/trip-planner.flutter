/// Connected OAuth apps settings screen.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_error.dart';
import '../../api/providers.dart';
import '../../app/adaptive.dart';
import '../../app/app_loading_skeleton.dart';
import '../../models/oauth.dart';
import '../../theme/tokens.dart';

/// 已授權 OAuth app 清單（GET /account/connected-apps）。
final connectedAppsProvider = FutureProvider<List<ConnectedApp>>((ref) {
  return ref.watch(tripRepositoryProvider).fetchConnectedApps();
});

/// 使用者管理已授權 app。
class ConnectedAppsScreen extends ConsumerStatefulWidget {
  const ConnectedAppsScreen({super.key});

  @override
  ConsumerState<ConnectedAppsScreen> createState() =>
      _ConnectedAppsScreenState();
}

class _ConnectedAppsScreenState extends ConsumerState<ConnectedAppsScreen> {
  String? _busyClientId;
  String? _mutationError;

  @override
  Widget build(BuildContext context) {
    final appsAsync = ref.watch(connectedAppsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('已連結的應用程式')),
      body: appsAsync.when(
        loading: () => const AppListLoadingSkeleton(
          key: ValueKey('connected-apps-loading'),
          itemCount: 3,
        ),
        error: (error, stackTrace) => _ConnectedAppsLoadError(
          onRetry: () => ref.invalidate(connectedAppsProvider),
        ),
        data: (apps) => RefreshIndicator.adaptive(
          onRefresh: () async => ref.invalidate(connectedAppsProvider),
          child: ListView(
            padding: const EdgeInsets.all(TpSpacing.s4),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              if (_mutationError != null) ...[
                _InlineErrorPanel(
                  message: _mutationError!,
                  onRetry: () => ref.invalidate(connectedAppsProvider),
                ),
                const SizedBox(height: TpSpacing.s4),
              ],
              if (apps.isEmpty)
                const _EmptyConnectedAppsState()
              else
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (var index = 0; index < apps.length; index++) ...[
                        _ConnectedAppTile(
                          app: apps[index],
                          isBusy: _busyClientId == apps[index].clientId,
                          onRevoke: () =>
                              unawaited(_confirmRevoke(apps[index])),
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

  Future<void> _confirmRevoke(ConnectedApp app) async {
    final shouldRevoke = await showAppConfirm(
      context,
      title: '撤銷 ${app.appName}？',
      message: '撤銷後，這個應用程式將無法再使用你的 Tripline 帳號存取資料。',
      confirmLabel: '撤銷',
      isDestructive: true,
    );
    if (!shouldRevoke || !mounted) return;

    setState(() {
      _busyClientId = app.clientId;
      _mutationError = null;
    });
    try {
      await ref.read(tripRepositoryProvider).revokeConnectedApp(app.clientId);
      if (!mounted) return;
      ref.invalidate(connectedAppsProvider);
      showAppNotice(context, '已撤銷 ${app.appName}');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _mutationError = _errorMessage(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _busyClientId = null;
        });
      }
    }
  }

  String _errorMessage(Object error) {
    if (error is ApiError) return error.detail ?? error.message;
    return '撤銷應用程式失敗，請稍後再試';
  }
}

class _ConnectedAppTile extends StatelessWidget {
  const _ConnectedAppTile({
    required this.app,
    required this.isBusy,
    required this.onRevoke,
  });

  final ConnectedApp app;
  final bool isBusy;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      key: Key('connected-app-row-${app.clientId}'),
      leading: const Icon(CupertinoIcons.square_grid_2x2, size: 22),
      title: Text(app.appName),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: TpSpacing.s1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (app.appDescription != null) Text(app.appDescription!),
            const SizedBox(height: TpSpacing.s2),
            Wrap(
              spacing: TpSpacing.s1,
              runSpacing: TpSpacing.s1,
              children: [
                for (final scope in app.scopes)
                  Chip(
                    label: Text(scope),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: TpSpacing.s1),
            Text(
              '${app.statusLabel} · 授權時間：${app.grantedAt}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      trailing: TextButton(
        key: Key('connected-app-revoke-${app.clientId}'),
        style: TextButton.styleFrom(
          foregroundColor: theme.colorScheme.error,
          shape: const StadiumBorder(),
        ),
        onPressed: isBusy ? null : onRevoke,
        child: isBusy
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator.adaptive(strokeWidth: 2),
              )
            : const Text('撤銷'),
      ),
    );
  }
}

class _ConnectedAppsLoadError extends StatelessWidget {
  const _ConnectedAppsLoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(TpSpacing.s4),
      children: [_InlineErrorPanel(message: '無法載入已連結的應用程式', onRetry: onRetry)],
    );
  }
}

class _InlineErrorPanel extends StatelessWidget {
  const _InlineErrorPanel({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
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
            TextButton(onPressed: onRetry, child: const Text('重試')),
          ],
        ),
      ),
    );
  }
}

class _EmptyConnectedAppsState extends StatelessWidget {
  const _EmptyConnectedAppsState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: TpSpacing.s8),
      child: Center(child: Text('目前沒有已連結的應用程式')),
    );
  }
}
