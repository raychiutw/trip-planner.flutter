/// 分享連結管理:列出/建立/重產生/撤銷/刪除公開唯讀連結。建立後顯示完整 URL + 複製
/// (raw token 只回一次)。管理限有 write 權限者(否則提示)。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/api_client.dart' show kTriplineOrigin;
import '../../../models/trip_share.dart';
import '../../../theme/tokens.dart';
import 'share_controller.dart';

const _shareSectionOrder = [
  'flights',
  'lodgings',
  'reservations',
  'pretrip',
  'emergency',
];
const _shareSectionLabels = {
  'flights': '航班',
  'lodgings': '住宿',
  'reservations': '預訂',
  'pretrip': '行前須知',
  'emergency': '緊急聯絡',
};
const _defaultShareSections = {'flights', 'lodgings', 'pretrip'};

/// 管理單一行程的公開分享連結。
class ShareScreen extends ConsumerStatefulWidget {
  const ShareScreen({super.key, required this.tripId});

  /// 目標行程 ID。
  final String tripId;

  @override
  ConsumerState<ShareScreen> createState() => _ShareScreenState();
}

class _ShareScreenState extends ConsumerState<ShareScreen> {
  final _label = TextEditingController();
  final Set<String> _sections = {..._defaultShareSections};
  bool _anonymous = false;

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  ShareController get _ctrl =>
      ref.read(shareControllerProvider(widget.tripId).notifier);

  List<String> get _visibleSections =>
      _shareSectionOrder.where(_sections.contains).toList();

  void _toggleSection(String key, bool selected) {
    setState(() {
      if (selected) {
        _sections.add(key);
      } else {
        _sections.remove(key);
      }
    });
  }

  Future<bool> _confirm(
    String message, {
    required String title,
    required String confirmText,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _editShareLabel(TripShare share) async {
    final nextLabel = await showDialog<String>(
      context: context,
      builder: (ctx) => _EditShareLabelDialog(initialLabel: share.label),
    );
    if (!mounted || nextLabel == null) return;
    await _ctrl.update(share.id, label: nextLabel);
  }

  Future<void> _copy(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已複製連結')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(shareControllerProvider(widget.tripId));

    return Scaffold(
      appBar: AppBar(title: const Text('分享連結')),
      body: state.loading
          ? const Center(child: CircularProgressIndicator())
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
                const SizedBox(height: TpSpacing.s3),
                Text('公開區塊', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: TpSpacing.s1),
                Wrap(
                  spacing: TpSpacing.s1,
                  runSpacing: TpSpacing.s1,
                  children: [
                    for (final section in _shareSectionOrder)
                      FilterChip(
                        key: ValueKey('share-section-$section'),
                        label: Text(_shareSectionLabels[section] ?? section),
                        selected: _sections.contains(section),
                        onSelected: (selected) =>
                            _toggleSection(section, selected),
                      ),
                  ],
                ),
                CheckboxListTile(
                  key: const ValueKey('share-anonymous'),
                  value: _anonymous,
                  onChanged: (value) =>
                      setState(() => _anonymous = value ?? false),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  title: const Text('匿名分享'),
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
                          _ctrl.create(
                            _label.text,
                            visibleSections: _visibleSections,
                            anonymous: _anonymous,
                          );
                          _label.clear();
                        },
                  child: state.creating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
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
    final busy =
        state.rotatingId == s.id ||
        state.revokingId == s.id ||
        state.deletingId == s.id;
    return ListTile(
      key: ValueKey('share-${s.id}'),
      contentPadding: EdgeInsets.zero,
      title: Text(s.label.isEmpty ? '(無標籤)' : s.label),
      subtitle: Text('$status · 已被檢視 ${s.viewCount} 次'),
      trailing: Wrap(
        spacing: TpSpacing.s1,
        children: [
          if (s.isActive)
            _rowIconButton(
              key: ValueKey('share-edit-btn-${s.id}'),
              tooltip: '編輯',
              icon: Icons.edit_outlined,
              onPressed: busy ? null : () async => _editShareLabel(s),
            ),
          if (s.isActive)
            _rowIconButton(
              key: ValueKey('share-rotate-${s.id}'),
              tooltip: state.rotatingId == s.id ? '更新中' : '重產生',
              icon: Icons.refresh,
              onPressed: busy ? null : () async => _ctrl.rotate(s.id),
            ),
          if (s.isActive)
            _rowIconButton(
              key: ValueKey('share-revoke-${s.id}'),
              tooltip: '撤銷',
              icon: Icons.link_off_outlined,
              onPressed: busy
                  ? null
                  : () async {
                      if (await _confirm(
                        '此連結將立即失效,無法復原。',
                        title: '撤銷分享連結',
                        confirmText: '撤銷',
                      )) {
                        await _ctrl.revoke(s.id);
                      }
                    },
            ),
          _rowIconButton(
            key: ValueKey('share-delete-${s.id}'),
            tooltip: state.deletingId == s.id ? '刪除中' : '刪除',
            icon: Icons.delete_outline,
            onPressed: busy
                ? null
                : () async {
                    if (await _confirm(
                      '此連結與瀏覽統計會永久刪除,無法復原。',
                      title: '刪除分享連結',
                      confirmText: '刪除',
                    )) {
                      await _ctrl.delete(s.id);
                    }
                  },
          ),
        ],
      ),
    );
  }

  Widget _rowIconButton({
    required Key key,
    required String tooltip,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return IconButton(
      key: key,
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 40, height: 40),
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
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
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('複製連結'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditShareLabelDialog extends StatefulWidget {
  const _EditShareLabelDialog({required this.initialLabel});

  final String initialLabel;

  @override
  State<_EditShareLabelDialog> createState() => _EditShareLabelDialogState();
}

class _EditShareLabelDialogState extends State<_EditShareLabelDialog> {
  late final TextEditingController _label;

  @override
  void initState() {
    super.initState();
    _label = TextEditingController(text: widget.initialLabel);
  }

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('編輯分享連結'),
      content: TextField(
        key: const ValueKey('share-edit-label'),
        controller: _label,
        autofocus: true,
        maxLength: 80,
        decoration: const InputDecoration(
          labelText: '連結名稱',
          border: OutlineInputBorder(),
          isDense: true,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_label.text),
          child: const Text('儲存'),
        ),
      ],
    );
  }
}
