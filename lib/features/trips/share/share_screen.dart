/// 分享連結管理:列出/建立/撤銷公開唯讀連結。建立後顯示完整 URL + 複製
/// (raw token 只回一次)。管理限有 write 權限者(否則提示)。
library;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/api_client.dart' show kTriplineOrigin;
import '../../../app/adaptive.dart';
import '../../../models/trip_share.dart';
import '../../../theme/tokens.dart';
import 'share_controller.dart';

class ShareScreen extends ConsumerStatefulWidget {
  const ShareScreen({super.key, required this.tripId});

  final String tripId;

  @override
  ConsumerState<ShareScreen> createState() => _ShareScreenState();
}

class _ShareScreenState extends ConsumerState<ShareScreen> {
  final _label = TextEditingController();

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  ShareController get _ctrl =>
      ref.read(shareControllerProvider(widget.tripId).notifier);

  Future<bool> _confirm(String message) {
    return showAppConfirm(
      context,
      title: '撤銷分享連結',
      message: message,
      confirmLabel: '撤銷',
      isDestructive: true,
    );
  }

  Future<void> _copy(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (mounted) {
      showAppNotice(context, '已複製連結');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(shareControllerProvider(widget.tripId));

    return Scaffold(
      appBar: AppBar(title: const Text('分享連結')),
      body: state.loading
          ? const Center(child: CircularProgressIndicator.adaptive())
          : !state.canManage
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(TpSpacing.s6),
                child: Text('只有可編輯此行程的人能管理分享連結。', textAlign: TextAlign.center),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(TpSpacing.s4),
              children: [
                if (state.lastCreated != null)
                  _CreatedCard(
                    url: state.lastCreated!.fullUrl(kTriplineOrigin),
                    onCopy: _copy,
                  ),
                Text(
                  '現有連結（${state.shares.length}）',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: TpSpacing.s2),
                if (state.shares.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: TpSpacing.s2),
                    child: Text(
                      '還沒有分享連結。',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                for (final s in state.shares) _shareTile(s, state),
                const SizedBox(height: TpSpacing.s5),
                Text('建立新連結', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: TpSpacing.s2),
                TextField(
                  key: const ValueKey('share-label'),
                  controller: _label,
                  decoration: const InputDecoration(
                    labelText: '標籤（選填,如「給爸媽」）',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: TpSpacing.s2),
                if (state.error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: TpSpacing.s2),
                    child: Text(
                      state.error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                FilledButton(
                  key: const ValueKey('share-create'),
                  onPressed: state.creating
                      ? null
                      : () {
                          _ctrl.create(_label.text);
                          _label.clear();
                        },
                  child: state.creating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator.adaptive(
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('建立分享連結'),
                ),
              ],
            ),
    );
  }

  Widget _shareTile(TripShare s, ShareState state) {
    final status = s.isRevoked
        ? '已撤銷'
        : s.isExpired
        ? '已過期'
        : '有效';
    return ListTile(
      key: ValueKey('share-${s.id}'),
      contentPadding: EdgeInsets.zero,
      title: Text(s.label.isEmpty ? '(無標籤)' : s.label),
      subtitle: Text('$status · 已被檢視 ${s.viewCount} 次'),
      trailing: s.isActive
          ? TextButton(
              key: ValueKey('share-revoke-${s.id}'),
              onPressed: state.revokingId == s.id
                  ? null
                  : () async {
                      if (await _confirm('此連結將立即失效,無法復原。')) {
                        await _ctrl.revoke(s.id);
                      }
                    },
              child: const Text('撤銷'),
            )
          : null,
    );
  }
}

class _CreatedCard extends StatelessWidget {
  const _CreatedCard({required this.url, required this.onCopy});

  final String url;
  final Future<void> Function(String) onCopy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(TpSpacing.s3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('連結已建立(只顯示這一次)', style: theme.textTheme.titleSmall),
            const SizedBox(height: TpSpacing.s2),
            SelectableText(url, style: theme.textTheme.bodySmall),
            const SizedBox(height: TpSpacing.s2),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                key: const ValueKey('share-copy'),
                onPressed: () => onCopy(url),
                icon: const Icon(CupertinoIcons.doc_on_doc, size: 18),
                label: const Text('複製連結'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
