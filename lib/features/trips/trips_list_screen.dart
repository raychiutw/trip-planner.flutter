import 'dart:async';
import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_error.dart';
import '../../api/providers.dart';
import '../../app/adaptive.dart';
import '../../app/app_feedback.dart';
import '../../models/trip.dart';
import '../../theme/tokens.dart';
import '../../ui/tp_action_item.dart';
import '../../ui/tp_app_bar.dart';
import '../../ui/tp_root_scaffold.dart';
import '../../ui/swipe_to_delete.dart';
import 'current_trip_provider.dart';
import 'trip_card.dart';

const int _maxTripImportBytes = 512 * 1024;

/// 匯入 JSON 檔案選擇器；widget test 以 provider override 注入假檔案。
final tripImportFilePickerProvider = Provider<TripImportFilePicker>(
  (ref) => const FileSelectorTripImportFilePicker(),
);

/// 匯出 JSON 檔案寫入器；widget test 以 provider override 避免原生 save dialog。
final tripExportFileWriterProvider = Provider<TripExportFileWriter>(
  (ref) => const FileSelectorTripExportFileWriter(),
);

class TripImportFile {
  const TripImportFile({
    required this.name,
    required this.length,
    required this.content,
  });

  final String name;
  final int length;
  final String content;
}

abstract class TripImportFilePicker {
  const TripImportFilePicker();

  Future<TripImportFile?> pick();
}

class FileSelectorTripImportFilePicker implements TripImportFilePicker {
  const FileSelectorTripImportFilePicker();

  @override
  Future<TripImportFile?> pick() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'JSON',
          extensions: ['json'],
          mimeTypes: ['application/json'],
        ),
      ],
    );
    if (file == null) return null;
    return TripImportFile(
      name: file.name,
      length: await file.length(),
      content: await file.readAsString(),
    );
  }
}

abstract class TripExportFileWriter {
  const TripExportFileWriter();

  Future<bool> save({required String suggestedName, required String content});
}

class FileSelectorTripExportFileWriter implements TripExportFileWriter {
  const FileSelectorTripExportFileWriter();

  @override
  Future<bool> save({
    required String suggestedName,
    required String content,
  }) async {
    final location = await getSaveLocation(
      suggestedName: suggestedName,
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'JSON',
          extensions: ['json'],
          mimeTypes: ['application/json'],
        ),
      ],
    );
    if (location == null) return false;
    final file = XFile.fromData(
      Uint8List.fromList(utf8.encode(content)),
      mimeType: 'application/json',
      name: suggestedName,
    );
    await file.saveTo(location.path);
    return true;
  }
}

/// 行程清單排序方式。
enum TripSortOrder {
  /// 預設：保留伺服器回傳順序。
  defaultOrder,

  /// 名稱 A→Z：依 displayTitle 升冪排列。
  nameAsc,

  /// 最新編輯：updatedAt 由新到舊（缺漏排最後）。
  updatedDesc,

  /// 出發日：startDate 由近到遠（缺漏排最後）。
  startDateAsc,
}

/// 行程清單篩選分頁。
enum TripFilter {
  /// 全部行程。
  all,

  /// 我的：ownerUserId == 當前 user。
  mine,

  /// 共編：ownerUserId != 當前 user。
  shared,
}

enum _TripsToolbarAction {
  create,
  importJson,
  defaultOrder,
  nameAsc,
  updatedDesc,
  startDateAsc,
}

/// `GET /my-trips` 清單（SWR:stale→fresh;刪除後 invalidate refresh）。
final myTripsProvider = StreamProvider<List<TripSummary>>((ref) {
  return ref.watch(tripRepositoryProvider).watchMyTrips();
});

/// 行程清單（4-tab「行程」分頁）：inline 頁首「我的行程」+ 搜尋框 + 分段篩選
/// + 下拉更新 + 單欄卡片清單。搜尋/篩選置於大標題下方,隨內容捲動(Notes/Mail 慣例)。
/// 點卡片進詳情；長按開 action sheet(分享/共編/匯出/刪除,二次確認)。
class TripsListScreen extends ConsumerStatefulWidget {
  const TripsListScreen({super.key});

  @override
  ConsumerState<TripsListScreen> createState() => _TripsListScreenState();
}

class _TripsListScreenState extends ConsumerState<TripsListScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  TripSortOrder _sortOrder = TripSortOrder.defaultOrder;
  TripFilter _filterTab = TripFilter.all;
  bool _isImporting = false;
  String? _exportingTripId;
  final Set<String> _deletingTripIds = {};
  final Set<String> _hiddenTripIds = {};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _query = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// 篩選分頁:全部 / 我的(ownerUserId == 當前 user)/ 共編(ownerUserId != 當前 user)。
  /// currentUserId 為 null(未登入/載入中)時「我的/共編」皆回空,避免誤判。
  List<TripSummary> _filterByTab(
    List<TripSummary> trips,
    String? currentUserId,
  ) {
    switch (_filterTab) {
      case TripFilter.all:
        return trips;
      case TripFilter.mine:
        return trips
            .where(
              (t) => t.ownerUserId != null && t.ownerUserId == currentUserId,
            )
            .toList();
      case TripFilter.shared:
        return trips
            .where(
              (t) => t.ownerUserId != null && t.ownerUserId != currentUserId,
            )
            .toList();
    }
  }

  /// 關鍵字搜尋(displayTitle / name)。
  List<TripSummary> _search(List<TripSummary> trips) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return trips;
    return trips
        .where(
          (t) =>
              t.displayTitle.toLowerCase().contains(q) ||
              t.name.toLowerCase().contains(q),
        )
        .toList();
  }

  /// 在 filter + search 之後套用排序。
  List<TripSummary> _sort(List<TripSummary> trips) {
    if (_sortOrder == TripSortOrder.defaultOrder) return trips;
    final sorted = List<TripSummary>.from(trips);
    switch (_sortOrder) {
      case TripSortOrder.defaultOrder:
        break;
      case TripSortOrder.nameAsc:
        sorted.sort((a, b) => a.displayTitle.compareTo(b.displayTitle));
      case TripSortOrder.updatedDesc:
        // updatedAt 由新到舊;缺漏(null/空)排最後。
        sorted.sort((a, b) => _compareNullableDesc(a.updatedAt, b.updatedAt));
      case TripSortOrder.startDateAsc:
        // startDate 由近到遠;缺漏(null/空)排最後。
        sorted.sort((a, b) => _compareNullableAsc(a.startDate, b.startDate));
    }
    return sorted;
  }

  /// 字串升冪比較,null/空值一律排到最後。
  int _compareNullableAsc(String? a, String? b) {
    final aEmpty = a == null || a.isEmpty;
    final bEmpty = b == null || b.isEmpty;
    if (aEmpty && bEmpty) return 0;
    if (aEmpty) return 1;
    if (bEmpty) return -1;
    return a.compareTo(b);
  }

  /// 字串降冪比較,null/空值一律排到最後。
  int _compareNullableDesc(String? a, String? b) {
    final aEmpty = a == null || a.isEmpty;
    final bEmpty = b == null || b.isEmpty;
    if (aEmpty && bEmpty) return 0;
    if (aEmpty) return 1;
    if (bEmpty) return -1;
    return b.compareTo(a);
  }

  @override
  Widget build(BuildContext context) {
    final myTripsAsync = ref.watch(myTripsProvider);
    final currentUserId = ref.watch(authStateProvider).value?.id;
    final theme = Theme.of(context);

    return TpRootScaffold(
      showSoftEdge: true,
      header: TpRootHeaderConfig(
        title: const Text('我的行程'),
        actions: [
          TpMoreMenuButton<_TripsToolbarAction>(
            key: const ValueKey('trips-sort-button'),
            tooltip: '更多',
            enabled: !_isImporting,
            triggerChild: _isImporting
                ? SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator.adaptive(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(
                        theme.colorScheme.primary,
                      ),
                    ),
                  )
                : null,
            onSelected: _handleToolbarAction,
            items: [
              const TpActionItem(
                key: ValueKey('trips-create-button'),
                value: _TripsToolbarAction.create,
                icon: CupertinoIcons.add,
                label: '新增行程',
              ),
              const TpActionItem(
                key: ValueKey('trips-list-import-trigger'),
                value: _TripsToolbarAction.importJson,
                icon: CupertinoIcons.cloud_upload,
                label: '匯入行程 JSON',
                dividerBefore: true,
              ),
              _buildSortMenuAction(
                action: _TripsToolbarAction.defaultOrder,
                order: TripSortOrder.defaultOrder,
                label: '預設順序',
                dividerBefore: true,
              ),
              _buildSortMenuAction(
                action: _TripsToolbarAction.nameAsc,
                order: TripSortOrder.nameAsc,
                label: '名稱 A→Z',
              ),
              _buildSortMenuAction(
                action: _TripsToolbarAction.updatedDesc,
                order: TripSortOrder.updatedDesc,
                label: '最新編輯',
              ),
              _buildSortMenuAction(
                action: _TripsToolbarAction.startDateAsc,
                order: TripSortOrder.startDateAsc,
                label: '出發日',
              ),
            ],
          ),
        ],
      ),
      body: TpRootScrollView(
        onRefresh: () => ref.refresh(myTripsProvider.future),
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    TpSpacing.s4,
                    TpSpacing.s2,
                    TpSpacing.s4,
                    TpSpacing.s2,
                  ),
                  child: AppSearchField(
                    fieldKey: const ValueKey('trips-search-field'),
                    controller: _searchController,
                    placeholder: '搜尋行程',
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    TpSpacing.s4,
                    0,
                    TpSpacing.s4,
                    TpSpacing.s2,
                  ),
                  child: SegmentedButton<TripFilter>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: TripFilter.all, label: Text('全部')),
                      ButtonSegment(value: TripFilter.mine, label: Text('我的')),
                      ButtonSegment(
                        value: TripFilter.shared,
                        label: Text('共編'),
                      ),
                    ],
                    selected: {_filterTab},
                    onSelectionChanged: (selection) {
                      setState(() {
                        _filterTab = selection.first;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          ..._buildBodySlivers(context, myTripsAsync, currentUserId, theme),
        ],
      ),
    );
  }

  TpActionItem<_TripsToolbarAction> _buildSortMenuAction({
    required _TripsToolbarAction action,
    required TripSortOrder order,
    required String label,
    bool dividerBefore = false,
  }) {
    return TpActionItem(
      value: action,
      icon: _sortOrder == order
          ? CupertinoIcons.check_mark
          : CupertinoIcons.arrow_up_arrow_down,
      label: label,
      dividerBefore: dividerBefore,
    );
  }

  void _handleToolbarAction(_TripsToolbarAction action) {
    if (action == _TripsToolbarAction.create) {
      context.push('/new-trip');
      return;
    }
    if (action == _TripsToolbarAction.importJson) {
      _importTripFromJson();
      return;
    }
    final order = switch (action) {
      _TripsToolbarAction.defaultOrder => TripSortOrder.defaultOrder,
      _TripsToolbarAction.nameAsc => TripSortOrder.nameAsc,
      _TripsToolbarAction.updatedDesc => TripSortOrder.updatedDesc,
      _TripsToolbarAction.startDateAsc => TripSortOrder.startDateAsc,
      _TripsToolbarAction.create => throw StateError('Handled above'),
      _TripsToolbarAction.importJson => throw StateError('Handled above'),
    };
    setState(() => _sortOrder = order);
  }

  /// 依 async 狀態回傳 body sliver 清單(接在搜尋/篩選 sliver 之後)。
  List<Widget> _buildBodySlivers(
    BuildContext context,
    AsyncValue<List<TripSummary>> myTripsAsync,
    String? currentUserId,
    ThemeData theme,
  ) {
    return myTripsAsync.when(
      data: (trips) {
        final visibleTrips = trips
            .where((trip) => !_hiddenTripIds.contains(trip.tripId))
            .toList();
        // 串接:filter(分頁) → search(關鍵字) → sort(排序)。
        final filtered = _sort(
          _search(_filterByTab(visibleTrips, currentUserId)),
        );
        if (visibleTrips.isEmpty) {
          return const [
            SliverFillRemaining(hasScrollBody: false, child: _EmptyHero()),
          ];
        }
        if (filtered.isEmpty) {
          return [
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildNoResults(theme),
            ),
          ];
        }
        return [_buildTripListSliver(context, filtered, currentUserId)];
      },
      error: (error, stackTrace) => [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _ErrorState(onRetry: () => ref.invalidate(myTripsProvider)),
        ),
      ],
      loading: () => [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Semantics(
            key: const ValueKey('trips-loading-state'),
            liveRegion: true,
            label: '正在載入行程清單',
            child: const Center(child: CircularProgressIndicator.adaptive()),
          ),
        ),
      ],
    );
  }

  Future<void> _importTripFromJson() async {
    setState(() => _isImporting = true);
    try {
      final file = await ref.read(tripImportFilePickerProvider).pick();
      if (!mounted || file == null) return;
      if (file.length > _maxTripImportBytes) {
        _showActionMessage('檔案過大（上限 512KB）');
        return;
      }

      final decodedJson = jsonDecode(file.content);
      if (decodedJson is! Map || decodedJson['schemaVersion'] != 1) {
        _showActionMessage('不支援的匯出格式（需 schemaVersion 1）');
        return;
      }

      final tripId = await ref
          .read(tripRepositoryProvider)
          .importTripJson(file.content);
      if (!mounted) return;
      ref.invalidate(myTripsProvider);
      _showActionMessage('匯入成功');
      unawaited(ref.read(currentTripIdProvider.notifier).select(tripId));
      context.go('/trips/$tripId');
    } on FormatException {
      if (!mounted) return;
      _showActionMessage('不是有效的 JSON 檔');
    } on ApiError catch (error) {
      if (!mounted) return;
      _showActionMessage(error.detail ?? error.message);
    } on Exception {
      if (!mounted) return;
      _showActionMessage('匯入失敗，請稍後再試');
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  Future<void> _exportTripToJson(TripSummary trip) async {
    if (_exportingTripId != null) return;
    setState(() => _exportingTripId = trip.tripId);
    try {
      final export = await ref
          .read(tripRepositoryProvider)
          .exportTripJson(trip.tripId);
      final saved = await ref
          .read(tripExportFileWriterProvider)
          .save(suggestedName: export.fileName, content: export.content);
      if (!mounted) return;
      _showActionMessage(saved ? '匯出成功' : '已取消匯出');
    } on Exception {
      if (!mounted) return;
      _showActionMessage('匯出失敗，請稍後再試');
    } finally {
      if (mounted) {
        setState(() => _exportingTripId = null);
      }
    }
  }

  void _showActionMessage(String message) {
    showAppNotice(context, message);
  }

  Widget _buildNoResults(ThemeData theme) {
    return Center(
      child: Text(
        '找不到符合的行程',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildTripListSliver(
    BuildContext context,
    List<TripSummary> trips,
    String? currentUserId,
  ) {
    // 底部淨空由 TpRootScrollView 統一提供，這裡不再自行處理。
    return SliverPadding(
      padding: const EdgeInsets.all(TpSpacing.s4),
      sliver: SliverList.separated(
        itemCount: trips.length,
        separatorBuilder: (context, index) =>
            const SizedBox(height: TpSpacing.s3),
        itemBuilder: (context, index) {
          final trip = trips[index];
          final isDeleting = _deletingTripIds.contains(trip.tripId);
          return IgnorePointer(
            ignoring: isDeleting,
            child: SwipeToDelete(
              dismissKey: ValueKey('trip-dismiss-${trip.tripId}'),
              onDelete: () => _confirmAndDeleteTrip(context, trip),
              child: Stack(
                children: [
                  TripCard(
                    trip: trip,
                    currentUserId: currentUserId,
                    onTap: isDeleting
                        ? null
                        : () {
                            unawaited(
                              ref
                                  .read(currentTripIdProvider.notifier)
                                  .select(trip.tripId),
                            );
                            context.go('/trips/${trip.tripId}');
                          },
                    onLongPress: isDeleting
                        ? null
                        : () => _showTripActions(context, trip),
                    onMorePressed: isDeleting
                        ? null
                        : () => _showTripActions(context, trip),
                  ),
                  if (isDeleting)
                    Positioned.fill(
                      child: Semantics(
                        key: ValueKey('trip-delete-progress-${trip.tripId}'),
                        liveRegion: true,
                        label: '正在刪除「${trip.displayTitle}」',
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surface.withValues(alpha: 0.72),
                            borderRadius: BorderRadius.circular(TpRadius.md),
                          ),
                          child: const Center(
                            child: CircularProgressIndicator.adaptive(),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// 長按卡片 → 自適應 action sheet（分享/共編/健檢/匯出/刪除）。
  Future<void> _showTripActions(BuildContext context, TripSummary trip) async {
    final selectedAction = await showAppActionSheet<_TripListAction>(
      context,
      actions: [
        TpActionItem(
          label: '分享',
          value: _TripListAction.share,
          icon: CupertinoIcons.share,
        ),
        TpActionItem(
          label: '共編設定',
          value: _TripListAction.collab,
          icon: CupertinoIcons.person_2,
        ),
        TpActionItem(
          label: 'AI 健檢',
          value: _TripListAction.health,
          icon: CupertinoIcons.heart,
        ),
        if (_exportingTripId == null)
          TpActionItem(
            label: '匯出 JSON',
            value: _TripListAction.exportJson,
            icon: CupertinoIcons.cloud_download,
          ),
        TpActionItem(
          label: '刪除行程',
          value: _TripListAction.delete,
          dividerBefore: true,
          role: TpActionRole.destructive,
          icon: CupertinoIcons.delete,
        ),
      ],
    );
    if (!context.mounted) return;
    switch (selectedAction) {
      case _TripListAction.share:
        context.push('/share-trip/${trip.tripId}');
        return;
      case _TripListAction.collab:
        context.push('/collab/${trip.tripId}');
        return;
      case _TripListAction.health:
        context.push('/trips/${Uri.encodeComponent(trip.tripId)}/health');
        return;
      case _TripListAction.exportJson:
        await _exportTripToJson(trip);
        return;
      case _TripListAction.delete:
        await _confirmAndDeleteTrip(context, trip);
        return;
      case null:
        return;
    }
  }

  /// AlertDialog 二次確認 → deleteTrip → invalidate refresh。
  Future<void> _confirmAndDeleteTrip(
    BuildContext context,
    TripSummary trip,
  ) async {
    if (_deletingTripIds.contains(trip.tripId)) return;
    final confirmedDelete = await showAppConfirm(
      context,
      title: '刪除行程',
      message:
          '確定要刪除「${trip.displayTitle}」嗎？'
          '這會刪除其中所有行程日與景點。此動作無法復原。',
      confirmLabel: '刪除',
      isDestructive: true,
    );
    if (!confirmedDelete || !context.mounted) return;
    await _deleteTrip(context, trip);
  }

  Future<void> _deleteTrip(BuildContext context, TripSummary trip) async {
    if (_deletingTripIds.contains(trip.tripId)) return;
    setState(() => _deletingTripIds.add(trip.tripId));
    try {
      await ref.read(tripRepositoryProvider).deleteTrip(trip.tripId);
      if (!mounted) return;
      setState(() => _hiddenTripIds.add(trip.tripId));
      ref.invalidate(myTripsProvider);
      HapticFeedback.mediumImpact();
    } on Exception {
      if (!context.mounted) return;
      showAppError(
        context,
        '刪除「${trip.displayTitle}」失敗，請稍後再試',
        onRetry: () => unawaited(_deleteTrip(context, trip)),
      );
    } finally {
      if (mounted) {
        setState(() => _deletingTripIds.remove(trip.tripId));
      }
    }
  }
}

enum _TripListAction { share, collab, health, exportJson, delete }

/// 空清單 hero 文案。
class _EmptyHero extends StatelessWidget {
  const _EmptyHero();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 外層 SliverFillRemaining 已提供捲動(空清單仍可下拉更新),此處只給置中內容。
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('尚無行程', style: theme.textTheme.titleLarge),
          const SizedBox(height: TpSpacing.s2),
          Text(
            '建立第一趟旅程，開始規劃你的旅行。',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: TpSpacing.s4),
          FilledButton.icon(
            key: const ValueKey('trips-empty-create'),
            onPressed: () => context.push('/new-trip'),
            icon: const Icon(CupertinoIcons.add),
            label: const Text('建立第一趟行程'),
          ),
        ],
      ),
    );
  }
}

/// 載入失敗：文案 + 重試按鈕。
class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      key: const ValueKey('trips-error-state'),
      liveRegion: true,
      label: '行程清單載入失敗',
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('載入失敗', style: theme.textTheme.titleMedium),
            const SizedBox(height: TpSpacing.s2),
            Text(
              '無法取得行程清單，請檢查網路後再試一次。',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: TpSpacing.s4),
            FilledButton(onPressed: onRetry, child: const Text('重試')),
          ],
        ),
      ),
    );
  }
}
