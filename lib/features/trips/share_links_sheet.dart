import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_client.dart';
import '../../api/api_error.dart';
import '../../api/providers.dart';
import '../../models/share.dart';
import '../../theme/tokens.dart';

enum _ShareExpiryPreset { never, sevenDays, thirtyDays }

const Map<String, String> _shareSectionLabels = {
  'flights': '航班',
  'lodgings': '住宿',
  'reservations': '預訂',
  'pretrip': '行前須知',
  'emergency': '緊急聯絡',
};

/// TripsList 用的公開分享連結管理 sheet。
class TripShareLinksSheet extends ConsumerStatefulWidget {
  const TripShareLinksSheet({
    required this.tripId,
    this.origin = kTriplineOrigin,
    super.key,
  });

  final String tripId;
  final String origin;

  @override
  ConsumerState<TripShareLinksSheet> createState() =>
      _TripShareLinksSheetState();
}

class _TripShareLinksSheetState extends ConsumerState<TripShareLinksSheet> {
  final _labelController = TextEditingController();
  final _editLabelController = TextEditingController();

  List<TripShareLink> _links = const [];
  CreatedTripShare? _created;
  Set<String> _sections = {...kDefaultShareSectionKeys};
  Set<String> _editSections = const <String>{};
  _ShareExpiryPreset _expiryPreset = _ShareExpiryPreset.never;
  _ShareExpiryPreset _editExpiryPreset = _ShareExpiryPreset.never;
  bool _anonymous = false;
  bool _editAnonymous = false;
  bool _loading = true;
  bool _busy = false;
  int? _editingId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadShares();
  }

  @override
  void dispose() {
    _labelController.dispose();
    _editLabelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeLinks = _links.where((link) => !link.isRevoked).toList();
    final revokedLinks = _links.where((link) => link.isRevoked).toList();
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: TpSpacing.s4,
          right: TpSpacing.s4,
          top: TpSpacing.s4,
          bottom: MediaQuery.viewInsetsOf(context).bottom + TpSpacing.s4,
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '分享這個行程',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '關閉',
                  icon: const Icon(Icons.close),
                  onPressed: _busy ? null : () => Navigator.of(context).pop(),
                ),
              ],
            ),
            Text(
              '建立公開唯讀連結，對方不用登入就能查看。連結網址只會在建立或重新產生時顯示一次。',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: TpSpacing.s4),
            _buildCreateBox(context),
            if (_created != null) ...[
              const SizedBox(height: TpSpacing.s3),
              _buildCreatedLink(context, _created!),
            ],
            if (_error != null) ...[
              const SizedBox(height: TpSpacing.s3),
              Text(
                _error!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: TpSpacing.s4),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else ...[
              if (activeLinks.isEmpty)
                Text(
                  '目前沒有使用中的分享連結。',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              else ...[
                Text(
                  '使用中的連結（${activeLinks.length}）',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: TpSpacing.s2),
                for (final link in activeLinks) ...[
                  _buildShareRow(context, link),
                  const SizedBox(height: TpSpacing.s2),
                ],
              ],
              if (revokedLinks.isNotEmpty) ...[
                const SizedBox(height: TpSpacing.s3),
                Text(
                  '已關閉的連結（${revokedLinks.length}）',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: TpSpacing.s2),
                for (final link in revokedLinks) ...[
                  _buildShareRow(context, link),
                  const SizedBox(height: TpSpacing.s2),
                ],
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCreateBox(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outline),
        borderRadius: const BorderRadius.all(Radius.circular(TpRadius.md)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(TpSpacing.s3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const ValueKey('share-link-label'),
              controller: _labelController,
              maxLength: 80,
              enabled: !_busy,
              decoration: const InputDecoration(
                labelText: '連結名稱（選填）',
                hintText: '例：給爸媽 / 給共遊旅伴',
                border: OutlineInputBorder(),
                counterText: '',
              ),
            ),
            const SizedBox(height: TpSpacing.s3),
            Text('要公開哪些筆記區塊', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: TpSpacing.s2),
            _buildSectionChips(
              selected: _sections,
              keyPrefix: 'share-section',
              onChanged: (next) => setState(() => _sections = next),
            ),
            const SizedBox(height: TpSpacing.s3),
            Text('有效期限', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: TpSpacing.s2),
            _buildExpirySelector(
              selected: _expiryPreset,
              onChanged: (value) => setState(() => _expiryPreset = value),
            ),
            const SizedBox(height: TpSpacing.s2),
            CheckboxListTile(
              key: const ValueKey('share-link-anonymous'),
              value: _anonymous,
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _anonymous = value ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              title: const Text('匿名分享（不顯示我的名字）'),
            ),
            FilledButton.icon(
              key: const ValueKey('share-link-create'),
              icon: _busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_link),
              label: const Text('建立分享連結'),
              onPressed: _busy ? null : _createShare,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreatedLink(BuildContext context, CreatedTripShare created) {
    final url = _absoluteShareUrl(created.url);
    return DecoratedBox(
      key: const ValueKey('share-link-created-box'),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: const BorderRadius.all(Radius.circular(TpRadius.md)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(TpSpacing.s3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('新連結（只顯示這一次）', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: TpSpacing.s2),
            Text(
              url,
              key: const ValueKey('share-link-created-url'),
              softWrap: true,
            ),
            const SizedBox(height: TpSpacing.s2),
            OutlinedButton.icon(
              key: const ValueKey('share-link-copy-url'),
              icon: const Icon(Icons.copy),
              label: const Text('複製連結'),
              onPressed: () => _copyUrl(url),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShareRow(BuildContext context, TripShareLink link) {
    final theme = Theme.of(context);
    final canMutate = !link.isRevoked && !link.isExpired;
    final isEditing = _editingId == link.id;

    return Card(
      key: ValueKey('share-link-row-${link.id}'),
      child: Padding(
        padding: const EdgeInsets.all(TpSpacing.s3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    link.displayLabel,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text('${link.viewCount} 次瀏覽'),
              ],
            ),
            const SizedBox(height: TpSpacing.s1),
            Text(
              [
                _createdAtText(link.createdAt),
                if (link.isAnonymous) '匿名',
                if (link.isRevoked) '已關閉',
                if (link.isExpired) '已過期',
              ].join(' · '),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: TpSpacing.s2),
            Wrap(
              spacing: TpSpacing.s1,
              runSpacing: TpSpacing.s1,
              children: [
                for (final section in link.visibleSectionKeys)
                  Chip(label: Text(_shareSectionLabels[section] ?? section)),
              ],
            ),
            const SizedBox(height: TpSpacing.s1),
            Text(_expiryText(link.expiresAt)),
            if (isEditing) ...[
              const Divider(height: TpSpacing.s5),
              TextField(
                key: ValueKey('share-link-edit-label-${link.id}'),
                controller: _editLabelController,
                maxLength: 80,
                enabled: !_busy,
                decoration: const InputDecoration(
                  labelText: '連結名稱',
                  border: OutlineInputBorder(),
                  counterText: '',
                ),
              ),
              const SizedBox(height: TpSpacing.s3),
              _buildSectionChips(
                selected: _editSections,
                keyPrefix: 'share-edit-section-${link.id}',
                onChanged: (next) => setState(() => _editSections = next),
              ),
              const SizedBox(height: TpSpacing.s3),
              _buildExpirySelector(
                selected: _editExpiryPreset,
                onChanged: (value) => setState(() => _editExpiryPreset = value),
              ),
              CheckboxListTile(
                key: ValueKey('share-link-edit-anonymous-${link.id}'),
                value: _editAnonymous,
                onChanged: _busy
                    ? null
                    : (value) =>
                          setState(() => _editAnonymous = value ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                title: const Text('匿名分享'),
              ),
              Wrap(
                spacing: TpSpacing.s2,
                children: [
                  FilledButton(
                    key: ValueKey('share-link-save-${link.id}'),
                    onPressed: _busy ? null : () => _saveEdit(link.id),
                    child: const Text('儲存'),
                  ),
                  TextButton(
                    onPressed: _busy ? null : _cancelEdit,
                    child: const Text('取消'),
                  ),
                ],
              ),
            ] else
              Wrap(
                spacing: TpSpacing.s2,
                runSpacing: TpSpacing.s1,
                children: [
                  if (canMutate)
                    TextButton.icon(
                      key: ValueKey('share-link-edit-${link.id}'),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('編輯'),
                      onPressed: _busy ? null : () => _startEdit(link),
                    ),
                  if (canMutate)
                    TextButton.icon(
                      key: ValueKey('share-link-rotate-${link.id}'),
                      icon: const Icon(Icons.refresh),
                      label: const Text('重新產生'),
                      onPressed: _busy ? null : () => _rotateShare(link.id),
                    ),
                  if (canMutate)
                    TextButton(
                      key: ValueKey('share-link-revoke-${link.id}'),
                      onPressed: _busy
                          ? null
                          : () => _mutate(
                              () => ref
                                  .read(tripRepositoryProvider)
                                  .revokeTripShare(widget.tripId, link.id),
                            ),
                      child: const Text('關閉'),
                    ),
                  TextButton.icon(
                    key: ValueKey('share-link-delete-${link.id}'),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('刪除'),
                    onPressed: _busy
                        ? null
                        : () => _mutate(
                            () => ref
                                .read(tripRepositoryProvider)
                                .deleteTripShare(widget.tripId, link.id),
                          ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionChips({
    required Set<String> selected,
    required String keyPrefix,
    required ValueChanged<Set<String>> onChanged,
  }) {
    return Wrap(
      spacing: TpSpacing.s2,
      runSpacing: TpSpacing.s1,
      children: [
        for (final section in kShareSectionKeys)
          FilterChip(
            key: ValueKey('$keyPrefix-$section'),
            label: Text(_shareSectionLabels[section] ?? section),
            selected: selected.contains(section),
            onSelected: _busy
                ? null
                : (value) {
                    final next = {...selected};
                    if (value) {
                      next.add(section);
                    } else {
                      next.remove(section);
                    }
                    onChanged(sanitizeShareSectionKeys(next).toSet());
                  },
          ),
      ],
    );
  }

  Widget _buildExpirySelector({
    required _ShareExpiryPreset selected,
    required ValueChanged<_ShareExpiryPreset> onChanged,
  }) {
    return SegmentedButton<_ShareExpiryPreset>(
      segments: const [
        ButtonSegment(value: _ShareExpiryPreset.never, label: Text('永久')),
        ButtonSegment(value: _ShareExpiryPreset.sevenDays, label: Text('7 天')),
        ButtonSegment(
          value: _ShareExpiryPreset.thirtyDays,
          label: Text('30 天'),
        ),
      ],
      selected: {selected},
      onSelectionChanged: _busy
          ? null
          : (selection) => onChanged(selection.single),
    );
  }

  Future<void> _loadShares() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final links = await ref
          .read(tripRepositoryProvider)
          .fetchTripShares(widget.tripId);
      if (!mounted) return;
      setState(() => _links = links);
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() => _error = _messageFor(error, '載入分享連結失敗'));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _createShare() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final created = await ref
          .read(tripRepositoryProvider)
          .createTripShare(
            widget.tripId,
            visibleSections: sanitizeShareSectionKeys(_sections),
            label: _labelController.text,
            expiresAt: _expiresAtFor(_expiryPreset),
            anonymous: _anonymous,
          );
      if (!mounted) return;
      setState(() {
        _created = created;
        _labelController.clear();
      });
      await _loadShares();
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() => _error = _messageFor(error, '建立失敗，請稍後重試'));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _rotateShare(int shareId) async {
    await _mutate(() async {
      final created = await ref
          .read(tripRepositoryProvider)
          .rotateTripShare(widget.tripId, shareId);
      if (!mounted) return;
      setState(() => _created = created);
    });
  }

  Future<void> _saveEdit(int shareId) async {
    await _mutate(() {
      return ref
          .read(tripRepositoryProvider)
          .updateTripShare(
            widget.tripId,
            shareId,
            visibleSections: sanitizeShareSectionKeys(_editSections),
            label: _editLabelController.text,
            expiresAt: _expiresAtFor(_editExpiryPreset),
            anonymous: _editAnonymous,
          );
    });
    _cancelEdit();
  }

  Future<void> _mutate(Future<void> Function() mutate) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await mutate();
      if (!mounted) return;
      await _loadShares();
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() => _error = _messageFor(error, '操作失敗，請稍後重試'));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _startEdit(TripShareLink link) {
    setState(() {
      _editingId = link.id;
      _editLabelController.text = link.label;
      _editSections = link.visibleSectionKeys.toSet();
      _editExpiryPreset = link.expiresAt == null
          ? _ShareExpiryPreset.never
          : _ShareExpiryPreset.thirtyDays;
      _editAnonymous = link.isAnonymous;
    });
  }

  void _cancelEdit() {
    if (!mounted) return;
    setState(() {
      _editingId = null;
      _editLabelController.clear();
      _editSections = const <String>{};
      _editExpiryPreset = _ShareExpiryPreset.never;
      _editAnonymous = false;
    });
  }

  Future<void> _copyUrl(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已複製分享連結')));
  }

  int? _expiresAtFor(_ShareExpiryPreset preset) {
    final now = DateTime.now();
    final expiresAt = switch (preset) {
      _ShareExpiryPreset.never => null,
      _ShareExpiryPreset.sevenDays => now.add(const Duration(days: 7)),
      _ShareExpiryPreset.thirtyDays => now.add(const Duration(days: 30)),
    };
    return expiresAt?.millisecondsSinceEpoch;
  }

  String _absoluteShareUrl(String rawUrl) {
    if (rawUrl.startsWith('http://') || rawUrl.startsWith('https://')) {
      return rawUrl;
    }
    final origin = widget.origin.endsWith('/')
        ? widget.origin.substring(0, widget.origin.length - 1)
        : widget.origin;
    final path = rawUrl.startsWith('/') ? rawUrl : '/$rawUrl';
    return '$origin$path';
  }

  String _expiryText(int? expiresAt) {
    if (expiresAt == null) return '永久有效';
    final date = DateTime.fromMillisecondsSinceEpoch(expiresAt).toLocal();
    return '有效至 ${_dateText(date)}';
  }

  String _createdAtText(String createdAt) {
    final date = DateTime.tryParse(createdAt);
    if (date == null) return '建立時間未知';
    return '建立於 ${_dateText(date.toLocal())}';
  }

  String _dateText(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _messageFor(Object error, String fallback) {
    if (error is ApiError) return error.detail ?? error.message;
    return fallback;
  }
}
