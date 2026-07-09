import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_error.dart';
import '../../api/providers.dart';
import '../../models/trip.dart';
import '../../theme/tokens.dart';
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

/// `GET /my-trips` 清單（SWR:stale→fresh;刪除後 invalidate refresh）。
final myTripsProvider = StreamProvider<List<TripSummary>>((ref) {
  return ref.watch(tripRepositoryProvider).watchMyTrips();
});

/// 行程清單（5-tab「行程」分頁）：AppBar「我的行程」+ 搜尋框 + 下拉更新 + 單欄卡片清單。
/// 點卡片進詳情；長按開 bottom sheet 刪除（AlertDialog 二次確認）。
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的行程'),
        actions: [
          IconButton(
            key: const ValueKey('trips-list-import-trigger'),
            tooltip: '匯入行程 JSON',
            icon: _isImporting
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.upload_file_outlined),
            onPressed: _isImporting ? null : _importTripFromJson,
          ),
          PopupMenuButton<TripSortOrder>(
            key: const ValueKey('trips-sort-button'),
            icon: const Icon(Icons.sort),
            tooltip: '排序',
            initialValue: _sortOrder,
            onSelected: (order) {
              setState(() {
                _sortOrder = order;
              });
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: TripSortOrder.defaultOrder,
                child: const Text('預設順序'),
              ),
              PopupMenuItem(
                value: TripSortOrder.nameAsc,
                child: const Text('名稱 A→Z'),
              ),
              PopupMenuItem(
                value: TripSortOrder.updatedDesc,
                child: const Text('最新編輯'),
              ),
              PopupMenuItem(
                value: TripSortOrder.startDateAsc,
                child: const Text('出發日'),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        key: const ValueKey('trips-create-fab'),
        onPressed: () => context.push('/new-trip'),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              TpSpacing.s4,
              TpSpacing.s2,
              TpSpacing.s4,
              TpSpacing.s2,
            ),
            child: TextField(
              key: const ValueKey('trips-search-field'),
              controller: _searchController,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: '搜尋行程',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
              ),
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
                ButtonSegment(value: TripFilter.shared, label: Text('共編')),
              ],
              selected: {_filterTab},
              onSelectionChanged: (selection) {
                setState(() {
                  _filterTab = selection.first;
                });
              },
            ),
          ),
          Expanded(
            child: myTripsAsync.when(
              data: (trips) {
                // 串接:filter(分頁) → search(關鍵字) → sort(排序)。
                final filtered = _sort(
                  _search(_filterByTab(trips, currentUserId)),
                );
                return RefreshIndicator(
                  onRefresh: () => ref.refresh(myTripsProvider.future),
                  child: trips.isEmpty
                      ? const _EmptyHero()
                      : filtered.isEmpty
                      ? _buildNoResults(theme)
                      : _buildTripList(context, filtered, currentUserId),
                );
              },
              error: (error, stackTrace) =>
                  _ErrorState(onRetry: () => ref.invalidate(myTripsProvider)),
              loading: () => const Center(child: CircularProgressIndicator()),
            ),
          ),
        ],
      ),
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildNoResults(ThemeData theme) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Text(
              '找不到符合的行程',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTripList(
    BuildContext context,
    List<TripSummary> trips,
    String? currentUserId,
  ) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(TpSpacing.s4),
      itemCount: trips.length,
      separatorBuilder: (context, index) =>
          const SizedBox(height: TpSpacing.s3),
      itemBuilder: (context, index) {
        final trip = trips[index];
        return TripCard(
          trip: trip,
          tone: TripCardTone.values[index % TripCardTone.values.length],
          currentUserId: currentUserId,
          onTap: () => context.go('/trips/${trip.tripId}'),
          onLongPress: () => _showTripActions(context, trip),
        );
      },
    );
  }

  /// 長按卡片 → bottom sheet（分享/共編/健檢/匯出/刪除）。
  Future<void> _showTripActions(BuildContext context, TripSummary trip) async {
    final selectedAction = await showModalBottomSheet<_TripListAction>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(TpRadius.xl)),
      ),
      builder: (sheetContext) {
        final destructiveColor = Theme.of(sheetContext).colorScheme.error;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: TpSpacing.s2),
              ListTile(
                leading: const Icon(Icons.ios_share),
                title: const Text('分享'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  context.push('/share-trip/${trip.tripId}');
                },
              ),
              ListTile(
                leading: const Icon(Icons.group_outlined),
                title: const Text('共編設定'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  context.push('/collab/${trip.tripId}');
                },
              ),
              ListTile(
                leading: const Icon(Icons.health_and_safety_outlined),
                title: const Text('AI 健檢'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  context.push(
                    '/trips/${Uri.encodeComponent(trip.tripId)}/health',
                  );
                },
              ),
              ListTile(
                key: ValueKey('trip-card-menu-export-${trip.tripId}'),
                leading: _exportingTripId == trip.tripId
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_outlined),
                title: const Text('匯出 JSON'),
                onTap: _exportingTripId == null
                    ? () => Navigator.of(
                        sheetContext,
                      ).pop(_TripListAction.exportJson)
                    : null,
              ),
              ListTile(
                leading: Icon(Icons.delete_outline, color: destructiveColor),
                title: Text(
                  '刪除行程',
                  style: TextStyle(
                    color: destructiveColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () =>
                    Navigator.of(sheetContext).pop(_TripListAction.delete),
              ),
              const SizedBox(height: TpSpacing.s2),
            ],
          ),
        );
      },
    );
    if (!context.mounted) return;
    switch (selectedAction) {
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
    final confirmedDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final dialogColorScheme = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(TpRadius.xl)),
          ),
          title: const Text('刪除行程'),
          content: Text('確定要刪除「${trip.displayTitle}」嗎？此動作無法復原。'),
          actions: [
            TextButton(
              style: TextButton.styleFrom(shape: const StadiumBorder()),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: dialogColorScheme.error,
                foregroundColor: dialogColorScheme.onError,
                shape: const StadiumBorder(),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('刪除'),
            ),
          ],
        );
      },
    );
    if (confirmedDelete != true || !context.mounted) return;

    try {
      await ref.read(tripRepositoryProvider).deleteTrip(trip.tripId);
      ref.invalidate(myTripsProvider);
    } on Exception {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('刪除失敗，請稍後再試')));
    }
  }
}

enum _TripListAction { exportJson, delete }

/// 空清單 hero 文案。
class _EmptyHero extends StatelessWidget {
  const _EmptyHero();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 包進 scrollable 讓空清單也能下拉更新
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('還沒有行程', style: theme.textTheme.titleLarge),
                const SizedBox(height: TpSpacing.s2),
                Text(
                  '建立第一趟旅程，開始規劃你的旅行。',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
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
    return Center(
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
    );
  }
}
