/// 分享連結管理:列出/建立/重產生/撤銷/刪除公開唯讀連結。建立後顯示完整 URL、
/// QR code + 複製(raw token 只回一次)。管理限有 write 權限者(否則提示)。
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr/qr.dart';
import 'package:share_plus/share_plus.dart';

import '../../../api/api_client.dart' show kTriplineOrigin;
import '../../../app/adaptive.dart';
import '../../../app/adaptive_content.dart';
import '../../../app/app_feedback.dart';
import '../../../app/app_loading_skeleton.dart';
import '../../../app/irreversible_action.dart';
import '../../../models/trip_share.dart';
import '../../../theme/tokens.dart';
import '../../../ui/tp_action_item.dart';
import '../../../ui/tp_app_bar.dart';
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
const _expiryPresets = {
  'never': null,
  '24h': Duration(hours: 24),
  '7d': Duration(days: 7),
  '30d': Duration(days: 30),
  'custom': null,
};
const _expiryLabels = {
  'never': '永久',
  '24h': '24 小時',
  '7d': '7 天',
  '30d': '30 天',
  'custom': '自訂',
};

/// 分享公開行程連結的 callback。
typedef ShareLinkInvoker = Future<void> Function(String url);

enum _ShareRowAction { edit, rotate, revoke, delete }

/// 呼叫系統分享面板分享公開行程連結。
Future<void> shareTripLink(String url) async {
  final uri = Uri.tryParse(url);
  await SharePlus.instance.share(
    uri != null && uri.hasScheme
        ? ShareParams(title: '行程分享', uri: uri)
        : ShareParams(title: '行程分享', text: url),
  );
}

/// 管理單一行程的公開分享連結。
class ShareScreen extends ConsumerStatefulWidget {
  const ShareScreen({super.key, required this.tripId, this.shareLink});

  /// 目標行程 ID。
  final String tripId;

  /// 分享新建立/重產生連結的 handler；預設呼叫系統分享面板。
  final ShareLinkInvoker? shareLink;

  @override
  ConsumerState<ShareScreen> createState() => _ShareScreenState();
}

class _ShareScreenState extends ConsumerState<ShareScreen> {
  final _label = TextEditingController();
  final Set<String> _sections = {..._defaultShareSections};
  String _expiryKey = 'never';
  DateTime? _customExpiryDate;
  bool _anonymous = false;
  bool _showRevoked = false;

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  ShareController get _ctrl =>
      ref.read(shareControllerProvider(widget.tripId).notifier);

  List<String> get _visibleSections =>
      _shareSectionOrder.where(_sections.contains).toList();

  int? get _expiresAt {
    if (_expiryKey == 'custom') {
      final date = _customExpiryDate;
      return date == null
          ? null
          : DateTime(
              date.year,
              date.month,
              date.day,
              23,
              59,
              59,
            ).millisecondsSinceEpoch;
    }
    final duration = _expiryPresets[_expiryKey];
    return duration == null
        ? null
        : DateTime.now().millisecondsSinceEpoch + duration.inMilliseconds;
  }

  String _customExpiryLabel(BuildContext context) {
    final date = _customExpiryDate;
    return date == null ? '選擇日期' : formatAppFullDate(context, date);
  }

  void _toggleSection(String key, bool selected) {
    setState(() {
      if (selected) {
        _sections.add(key);
      } else {
        _sections.remove(key);
      }
    });
  }

  Future<void> _pickCustomExpiryDate() async {
    final now = DateTime.now();
    final selected = await showAppDatePicker(
      context,
      initialDate: _customExpiryDate ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 5, 12, 31),
    );
    if (selected == null || !mounted) return;
    setState(() => _customExpiryDate = selected);
  }

  Future<void> _editShare(TripShare share) async {
    final formController = AppSheetFormController();
    try {
      await showAppFormSheet(
        context,
        title: '編輯分享連結',
        submitLabel: '儲存',
        submitKey: const ValueKey('share-edit-submit'),
        controller: formController,
        builder: (_) => _EditShareForm(
          share: share,
          formController: formController,
          onSubmit: (next) => _ctrl.update(
            share.id,
            label: next.label,
            visibleSections: next.visibleSections,
            expiresAt: next.expiresAt,
            clearExpiresAt: next.clearExpiresAt,
            anonymous: next.anonymous,
          ),
        ),
      );
    } finally {
      formController.dispose();
    }
  }

  Future<void> _runShareAction(_ShareRowAction action, TripShare share) async {
    switch (action) {
      case _ShareRowAction.edit:
        await _editShare(share);
      case _ShareRowAction.rotate:
        await _ctrl.rotate(share.id);
      case _ShareRowAction.revoke:
        await confirmAndRunIrreversibleAction(
          context,
          title: '撤銷「${share.label.isEmpty ? '無標籤連結' : share.label}」？',
          message: '這個分享連結將立即失效，且無法復原。',
          actionLabel: '撤銷',
          progressLabel: '正在撤銷…',
          successMessage: '已撤銷分享連結',
          failureMessage: '撤銷失敗，原連結已保留',
          action: () => _ctrl.revoke(share.id),
        );
      case _ShareRowAction.delete:
        await confirmAndRunIrreversibleAction(
          context,
          title: '刪除「${share.label.isEmpty ? '無標籤連結' : share.label}」？',
          message: '這個分享連結與瀏覽統計會永久刪除，且無法復原。',
          actionLabel: '刪除',
          progressLabel: '正在刪除…',
          successMessage: '已刪除分享連結',
          failureMessage: '刪除失敗，原連結已保留',
          action: () => _ctrl.delete(share.id),
        );
    }
  }

  Future<void> _createShare() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final succeeded = await _ctrl.create(
      _label.text,
      visibleSections: _visibleSections,
      expiresAt: _expiresAt,
      anonymous: _anonymous,
    );
    if (succeeded) _label.clear();
  }

  Future<void> _copy(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (mounted) {
      showAppNotice(context, '已複製連結');
    }
  }

  Future<void> _share(String url) async {
    try {
      await (widget.shareLink ?? shareTripLink)(url);
    } on Exception {
      if (!mounted) return;
      showAppError(context, '分享失敗，請改用複製連結');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(shareControllerProvider(widget.tripId));
    final activeShares = state.shares.where((s) => !s.isRevoked).toList();
    final revokedShares = state.shares.where((s) => s.isRevoked).toList();

    return Scaffold(
      // 本頁在 StatefulShellRoute 之外、沒有 root tab bar，
      // 帳號入口是這裡唯一的路徑，明文保留。
      appBar: const TpAppBar(
        role: TpAppBarRole.detail,
        title: Text('分享連結'),
        actions: [TpAccountAvatarButton()],
      ),
      body: AppAdaptiveContent(
        maxWidth: AppContentWidth.form,
        contentKey: const ValueKey('share-content'),
        child: state.loading
            ? const AppListLoadingSkeleton(key: ValueKey('share-loading'))
            : !state.canManage
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(TpSpacing.s6),
                  child: Text(
                    '只有可編輯此行程的人能管理分享連結。',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(TpSpacing.s4),
                children: [
                  if (state.lastCreated != null)
                    _CreatedCard(
                      url: state.lastCreated!.fullUrl(kTriplineOrigin),
                      onCopy: _copy,
                      onShare: _share,
                    ),
                  Text(
                    '使用中的連結（${activeShares.length}）',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: TpSpacing.s2),
                  if (activeShares.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: TpSpacing.s2,
                      ),
                      child: Text(
                        '目前沒有使用中的分享連結。',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  for (final s in activeShares) _shareTile(s, state),
                  if (revokedShares.isNotEmpty) ...[
                    const SizedBox(height: TpSpacing.s2),
                    TextButton.icon(
                      key: const ValueKey('share-revoked-toggle'),
                      onPressed: () =>
                          setState(() => _showRevoked = !_showRevoked),
                      icon: Icon(
                        _showRevoked
                            ? Icons.expand_less_outlined
                            : Icons.expand_more_outlined,
                      ),
                      label: Text('已關閉的連結（${revokedShares.length}）'),
                    ),
                    if (_showRevoked)
                      for (final s in revokedShares) _shareTile(s, state),
                  ],
                  const SizedBox(height: TpSpacing.s5),
                  Text('建立新連結', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: TpSpacing.s2),
                  AbsorbPointer(
                    key: const ValueKey('share-create-form'),
                    absorbing: state.creating,
                    child: ExcludeFocus(
                      excluding: state.creating,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
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
                          Text(
                            '公開區塊',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: TpSpacing.s1),
                          Wrap(
                            spacing: TpSpacing.s1,
                            runSpacing: TpSpacing.s1,
                            children: [
                              for (final section in _shareSectionOrder)
                                FilterChip(
                                  key: ValueKey('share-section-$section'),
                                  label: Text(
                                    _shareSectionLabels[section] ?? section,
                                  ),
                                  selected: _sections.contains(section),
                                  onSelected: (selected) =>
                                      _toggleSection(section, selected),
                                ),
                            ],
                          ),
                          const SizedBox(height: TpSpacing.s3),
                          Text(
                            '有效期限',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: TpSpacing.s1),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SegmentedButton<String>(
                              showSelectedIcon: false,
                              selected: {_expiryKey},
                              onSelectionChanged: (next) =>
                                  setState(() => _expiryKey = next.single),
                              segments: [
                                for (final key in _expiryPresets.keys)
                                  ButtonSegment(
                                    value: key,
                                    label: Text(_expiryLabels[key] ?? key),
                                  ),
                              ],
                            ),
                          ),
                          if (_expiryKey == 'custom') ...[
                            const SizedBox(height: TpSpacing.s2),
                            OutlinedButton.icon(
                              key: const ValueKey('share-custom-expiry-date'),
                              onPressed: _pickCustomExpiryDate,
                              icon: const Icon(Icons.event_outlined, size: 18),
                              label: Text(_customExpiryLabel(context)),
                            ),
                          ],
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
                            Semantics(
                              key: const ValueKey('share-error'),
                              liveRegion: true,
                              container: true,
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  bottom: TpSpacing.s2,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        state.error!,
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.error,
                                        ),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: _ctrl.retry,
                                      child: const Text('重試'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          FilledButton(
                            key: const ValueKey('share-create'),
                            onPressed: state.creating ? null : _createShare,
                            child: state.creating
                                ? Semantics(
                                    key: const ValueKey(
                                      'share-create-progress',
                                    ),
                                    liveRegion: true,
                                    label: '正在建立分享連結',
                                    child: const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator.adaptive(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  )
                                : const Text('建立分享連結'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
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
      trailing: TpMoreMenuButton<_ShareRowAction>(
        key: ValueKey('share-actions-${s.id}'),
        tooltip: '分享連結動作',
        enabled: !busy,
        items: [
          if (s.isActive) ...[
            TpActionItem(
              key: ValueKey('share-edit-btn-${s.id}'),
              value: _ShareRowAction.edit,
              label: '編輯',
              icon: Icons.edit_outlined,
            ),
            TpActionItem(
              key: ValueKey('share-rotate-${s.id}'),
              value: _ShareRowAction.rotate,
              label: '重新產生',
              icon: Icons.refresh,
            ),
            TpActionItem(
              key: ValueKey('share-revoke-${s.id}'),
              value: _ShareRowAction.revoke,
              label: '撤銷',
              icon: Icons.link_off_outlined,
              dividerBefore: true,
              role: TpActionRole.destructive,
            ),
          ],
          TpActionItem(
            key: ValueKey('share-delete-${s.id}'),
            value: _ShareRowAction.delete,
            label: '刪除',
            icon: Icons.delete_outline,
            dividerBefore: !s.isActive,
            role: TpActionRole.destructive,
          ),
        ],
        onSelected: (action) => _runShareAction(action, s),
      ),
    );
  }
}

class _CreatedCard extends StatefulWidget {
  const _CreatedCard({
    required this.url,
    required this.onCopy,
    required this.onShare,
  });

  final String url;
  final Future<void> Function(String) onCopy;
  final Future<void> Function(String) onShare;

  @override
  State<_CreatedCard> createState() => _CreatedCardState();
}

class _CreatedCardState extends State<_CreatedCard> {
  bool _showQr = false;

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
            SelectableText(widget.url, style: theme.textTheme.bodySmall),
            const SizedBox(height: TpSpacing.s2),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: TpSpacing.s1,
              runSpacing: TpSpacing.s1,
              children: [
                OutlinedButton.icon(
                  key: const ValueKey('share-qr-toggle'),
                  onPressed: () => setState(() => _showQr = !_showQr),
                  icon: Icon(
                    _showQr ? Icons.visibility_off_outlined : Icons.qr_code_2,
                    size: 18,
                  ),
                  label: Text(_showQr ? '隱藏 QR' : '顯示 QR'),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('share-native'),
                  onPressed: () => widget.onShare(widget.url),
                  icon: const Icon(Icons.ios_share_outlined, size: 18),
                  label: const Text('分享'),
                ),
                FilledButton.tonalIcon(
                  key: const ValueKey('share-copy'),
                  onPressed: () => widget.onCopy(widget.url),
                  icon: const Icon(CupertinoIcons.doc_on_doc, size: 18),
                  label: const Text('複製連結'),
                ),
              ],
            ),
            if (_showQr) ...[
              const SizedBox(height: TpSpacing.s3),
              Center(child: _ShareQrCode(url: widget.url)),
            ],
          ],
        ),
      ),
    );
  }
}

class _ShareQrCode extends StatelessWidget {
  const _ShareQrCode({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final qrImage = QrImage(
      QrCode.fromData(data: url, errorCorrectLevel: QrErrorCorrectLevel.M),
    );
    return Semantics(
      label: '分享連結 QR code',
      child: DecoratedBox(
        key: const ValueKey('share-qr-code'),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Theme.of(context).colorScheme.outline),
        ),
        child: Padding(
          padding: const EdgeInsets.all(TpSpacing.s2),
          child: CustomPaint(
            size: const Size.square(220),
            painter: _ShareQrPainter(
              image: qrImage,
              url: url,
              foreground: const Color(0xFF1D1813),
              background: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _ShareQrPainter extends CustomPainter {
  const _ShareQrPainter({
    required this.image,
    required this.url,
    required this.foreground,
    required this.background,
  });

  static const _quietZoneModules = 1;

  final QrImage image;
  final String url;
  final Color foreground;
  final Color background;

  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width, size.height);
    final fullModuleCount = image.moduleCount + (_quietZoneModules * 2);
    final moduleSize = side / fullModuleCount;
    final qrSide = moduleSize * fullModuleCount;
    final left = (size.width - qrSide) / 2;
    final top = (size.height - qrSide) / 2;

    canvas.drawRect(
      Rect.fromLTWH(left, top, qrSide, qrSide),
      Paint()..color = background,
    );

    final darkPaint = Paint()..color = foreground;
    for (var row = 0; row < image.moduleCount; row++) {
      for (var col = 0; col < image.moduleCount; col++) {
        if (!image.isDark(row, col)) continue;
        canvas.drawRect(
          Rect.fromLTWH(
            left + (col + _quietZoneModules) * moduleSize,
            top + (row + _quietZoneModules) * moduleSize,
            moduleSize,
            moduleSize,
          ),
          darkPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ShareQrPainter oldDelegate) {
    return oldDelegate.url != url ||
        oldDelegate.foreground != foreground ||
        oldDelegate.background != background;
  }
}

class _ShareEditSettings {
  const _ShareEditSettings({
    required this.label,
    required this.visibleSections,
    required this.expiresAt,
    required this.clearExpiresAt,
    required this.anonymous,
  });

  final String label;
  final List<String> visibleSections;
  final int? expiresAt;
  final bool clearExpiresAt;
  final bool anonymous;
}

class _EditShareForm extends StatefulWidget {
  const _EditShareForm({
    required this.share,
    required this.formController,
    required this.onSubmit,
  });

  final TripShare share;
  final AppSheetFormController formController;
  final Future<bool> Function(_ShareEditSettings settings) onSubmit;

  @override
  State<_EditShareForm> createState() => _EditShareFormState();
}

class _EditShareFormState extends State<_EditShareForm> {
  late final TextEditingController _label;
  late final Set<String> _sections;
  late String _expiryKey;
  DateTime? _customExpiryDate;
  late bool _anonymous;
  late final ({
    String label,
    List<String> visibleSections,
    String expiryKey,
    int? customExpiryDay,
    bool anonymous,
  })
  _initial;
  String? _error;

  @override
  void initState() {
    super.initState();
    _label = TextEditingController(text: widget.share.label);
    _sections = widget.share.visibleSections.toSet();
    _expiryKey = widget.share.expiresAt == null ? 'never' : 'custom';
    _customExpiryDate = widget.share.expiresAt == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(widget.share.expiresAt!);
    _anonymous = widget.share.anonymous;
    _initial = (
      label: widget.share.label,
      visibleSections: List.unmodifiable(_visibleSections),
      expiryKey: _expiryKey,
      customExpiryDay: _customExpiryDay,
      anonymous: widget.share.anonymous,
    );
    _label.addListener(_markChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.formController.attach(_submit);
      widget.formController.update(dirty: false, canSubmit: false);
    });
  }

  @override
  void dispose() {
    _label.removeListener(_markChanged);
    _label.dispose();
    super.dispose();
  }

  List<String> get _visibleSections =>
      _shareSectionOrder.where(_sections.contains).toList();

  int? get _expiresAt {
    if (_expiryKey == 'custom') {
      final date = _customExpiryDate;
      return date == null
          ? null
          : DateTime(
              date.year,
              date.month,
              date.day,
              23,
              59,
              59,
            ).millisecondsSinceEpoch;
    }
    final duration = _expiryPresets[_expiryKey];
    return duration == null
        ? null
        : DateTime.now().millisecondsSinceEpoch + duration.inMilliseconds;
  }

  bool get _clearExpiresAt =>
      _expiryKey == 'never' && widget.share.expiresAt != null;

  int? get _customExpiryDay {
    final date = _customExpiryDate;
    return date == null
        ? null
        : DateTime(date.year, date.month, date.day).millisecondsSinceEpoch;
  }

  bool get _isDirty =>
      _label.text != _initial.label ||
      !listEquals(_visibleSections, _initial.visibleSections) ||
      _expiryKey != _initial.expiryKey ||
      _customExpiryDay != _initial.customExpiryDay ||
      _anonymous != _initial.anonymous;

  String _customExpiryLabel(BuildContext context) {
    final date = _customExpiryDate;
    return date == null ? '選擇日期' : formatAppFullDate(context, date);
  }

  _ShareEditSettings get _settings => _ShareEditSettings(
    label: _label.text,
    visibleSections: _visibleSections,
    expiresAt: _expiresAt,
    clearExpiresAt: _clearExpiresAt,
    anonymous: _anonymous,
  );

  void _markChanged() {
    if (!mounted) return;
    setState(() => _error = null);
    _syncFormState();
  }

  void _syncFormState() {
    final dirty = _isDirty;
    widget.formController.update(dirty: dirty, canSubmit: dirty);
  }

  void _toggleSection(String key, bool selected) {
    setState(() {
      if (selected) {
        _sections.add(key);
      } else {
        _sections.remove(key);
      }
      _error = null;
    });
    _syncFormState();
  }

  Future<void> _pickCustomExpiryDate() async {
    final now = DateTime.now();
    final selected = await showAppDatePicker(
      context,
      initialDate: _customExpiryDate ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 5, 12, 31),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _customExpiryDate = selected;
      _error = null;
    });
    _syncFormState();
  }

  Future<bool> _submit() async {
    final succeeded = await widget.onSubmit(_settings);
    if (!succeeded && mounted) {
      setState(() => _error = '儲存失敗，輸入內容已保留，請重試。');
    }
    return succeeded;
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(TpSpacing.s4),
      children: [
        TextField(
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
        const SizedBox(height: TpSpacing.s2),
        Text('公開區塊', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: TpSpacing.s1),
        Wrap(
          spacing: TpSpacing.s1,
          runSpacing: TpSpacing.s1,
          children: [
            for (final section in _shareSectionOrder)
              FilterChip(
                key: ValueKey('share-edit-section-$section'),
                label: Text(_shareSectionLabels[section] ?? section),
                selected: _sections.contains(section),
                onSelected: (selected) => _toggleSection(section, selected),
              ),
          ],
        ),
        const SizedBox(height: TpSpacing.s2),
        Text('有效期限', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: TpSpacing.s1),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<String>(
            showSelectedIcon: false,
            selected: {_expiryKey},
            onSelectionChanged: (next) {
              setState(() {
                _expiryKey = next.single;
                _error = null;
              });
              _syncFormState();
            },
            segments: [
              for (final key in _expiryPresets.keys)
                ButtonSegment(
                  value: key,
                  label: Text(
                    _expiryLabels[key] ?? key,
                    key: ValueKey('share-edit-expiry-$key'),
                  ),
                ),
            ],
          ),
        ),
        if (_expiryKey == 'custom') ...[
          const SizedBox(height: TpSpacing.s2),
          OutlinedButton.icon(
            key: const ValueKey('share-edit-custom-expiry-date'),
            onPressed: _pickCustomExpiryDate,
            icon: const Icon(Icons.event_outlined, size: 18),
            label: Text(_customExpiryLabel(context)),
          ),
        ],
        CheckboxListTile(
          key: const ValueKey('share-edit-anonymous'),
          value: _anonymous,
          onChanged: (value) {
            setState(() {
              _anonymous = value ?? false;
              _error = null;
            });
            _syncFormState();
          },
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          dense: true,
          visualDensity: VisualDensity.compact,
          title: const Text('匿名分享'),
        ),
        if (_error != null)
          Semantics(
            liveRegion: true,
            child: Padding(
              padding: const EdgeInsets.only(top: TpSpacing.s2),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ),
      ],
    );
  }
}
