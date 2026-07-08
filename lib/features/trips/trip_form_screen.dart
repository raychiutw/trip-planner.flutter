import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_error.dart';
import '../../api/providers.dart';
import '../../models/day.dart';
import '../../models/trip.dart';
import '../../theme/tokens.dart';
import '../trip_detail/trip_providers.dart';
import 'trips_list_screen.dart';

class TripFormScreen extends ConsumerStatefulWidget {
  const TripFormScreen.create({super.key}) : tripId = null;

  const TripFormScreen.edit({super.key, required this.tripId});

  final String? tripId;

  bool get isEdit => tripId != null;

  @override
  ConsumerState<TripFormScreen> createState() => _TripFormScreenState();
}

class _TripFormScreenState extends ConsumerState<TripFormScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _startDateController = TextEditingController();
  final _endDateController = TextEditingController();
  final _destinations = <_DestinationDraft>[_DestinationDraft()];
  final _datePattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  bool _published = true;
  String _lang = 'zh-TW';
  String? _hydratedTripId;
  String? _submitError;
  String? _dayMutationError;
  bool _submitting = false;
  bool _daysMutating = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    for (final destination in _destinations) {
      destination.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isEdit) {
      final tripAsync = ref.watch(tripDetailProvider(widget.tripId!));
      final daysAsync = ref.watch(tripDaysProvider(widget.tripId!));
      return tripAsync.when(
        data: (trip) {
          _hydrateFromTrip(trip);
          return _buildScaffold(trip: trip, daysAsync: daysAsync);
        },
        error: (error, stackTrace) => Scaffold(
          appBar: AppBar(title: const Text('編輯行程')),
          body: _LoadErrorState(
            message: '無法載入行程',
            onRetry: () => ref.invalidate(tripDetailProvider(widget.tripId!)),
          ),
        ),
        loading: () => Scaffold(
          appBar: AppBar(title: const Text('編輯行程')),
          body: const Center(child: CircularProgressIndicator()),
        ),
      );
    }
    return _buildScaffold();
  }

  Widget _buildScaffold({Trip? trip, AsyncValue<List<TripDay>>? daysAsync}) {
    final title = widget.isEdit ? '編輯行程' : '新增行程';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(TpSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildDestinationFields(),
              const SizedBox(height: TpSpacing.s4),
              TextFormField(
                key: const ValueKey('trip-form-title'),
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: '行程名稱（選填）',
                  border: OutlineInputBorder(),
                ),
                enabled: !_submitting,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: TpSpacing.s3),
              if (widget.isEdit)
                _buildEditDaysSection(daysAsync)
              else
                _buildCreateDateFields(),
              const SizedBox(height: TpSpacing.s3),
              TextFormField(
                key: const ValueKey('trip-form-description'),
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: '描述（選填）',
                  border: OutlineInputBorder(),
                ),
                enabled: !_submitting,
                minLines: 3,
                maxLines: 5,
              ),
              const SizedBox(height: TpSpacing.s3),
              DropdownButtonFormField<String>(
                key: const ValueKey('trip-form-lang'),
                initialValue: _lang,
                decoration: const InputDecoration(
                  labelText: '顯示語言',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'zh-TW', child: Text('繁體中文')),
                  DropdownMenuItem(value: 'en', child: Text('English')),
                  DropdownMenuItem(value: 'ja', child: Text('日本語')),
                ],
                onChanged: _submitting
                    ? null
                    : (value) => setState(() {
                        _lang = value ?? 'zh-TW';
                        _submitError = null;
                      }),
              ),
              const SizedBox(height: TpSpacing.s2),
              SwitchListTile(
                key: const ValueKey('trip-form-published'),
                contentPadding: EdgeInsets.zero,
                title: const Text('上線'),
                value: _published,
                onChanged: _submitting
                    ? null
                    : (value) => setState(() {
                        _published = value;
                        _submitError = null;
                      }),
              ),
              if (_submitError != null) ...[
                const SizedBox(height: TpSpacing.s2),
                _InlineError(message: _submitError!),
              ],
              const SizedBox(height: TpSpacing.s4),
              FilledButton.icon(
                key: const ValueKey('trip-form-submit'),
                icon: _submitting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(widget.isEdit ? Icons.save_outlined : Icons.add),
                label: Text(widget.isEdit ? '儲存行程' : '建立行程'),
                onPressed: _submitting ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDestinationFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < _destinations.length; index++) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  key: ValueKey('trip-form-destination-$index'),
                  controller: _destinations[index].nameController,
                  decoration: InputDecoration(
                    labelText: index == 0 ? '目的地' : '目的地 ${index + 1}',
                    border: const OutlineInputBorder(),
                  ),
                  enabled: !_submitting,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => setState(() => _submitError = null),
                ),
              ),
              if (_destinations.length > 1) ...[
                const SizedBox(width: TpSpacing.s2),
                IconButton(
                  tooltip: '移除',
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: _submitting
                      ? null
                      : () => setState(() {
                          _destinations.removeAt(index).dispose();
                          _submitError = null;
                        }),
                ),
              ],
            ],
          ),
          if (index != _destinations.length - 1)
            const SizedBox(height: TpSpacing.s2),
        ],
        const SizedBox(height: TpSpacing.s2),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            key: const ValueKey('trip-form-add-destination'),
            icon: const Icon(Icons.add_location_alt_outlined),
            label: const Text('加入目的地'),
            onPressed: _submitting
                ? null
                : () => setState(() {
                    _destinations.add(_DestinationDraft());
                    _submitError = null;
                  }),
          ),
        ),
      ],
    );
  }

  Widget _buildCreateDateFields() {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            key: const ValueKey('trip-form-start-date'),
            controller: _startDateController,
            decoration: const InputDecoration(
              labelText: '出發日期',
              hintText: 'YYYY-MM-DD',
              border: OutlineInputBorder(),
            ),
            enabled: !_submitting,
            keyboardType: TextInputType.datetime,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9-]')),
            ],
            onChanged: (_) => setState(() => _submitError = null),
          ),
        ),
        const SizedBox(width: TpSpacing.s3),
        Expanded(
          child: TextFormField(
            key: const ValueKey('trip-form-end-date'),
            controller: _endDateController,
            decoration: const InputDecoration(
              labelText: '回程日期',
              hintText: 'YYYY-MM-DD',
              border: OutlineInputBorder(),
            ),
            enabled: !_submitting,
            keyboardType: TextInputType.datetime,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9-]')),
            ],
            onChanged: (_) => setState(() => _submitError = null),
          ),
        ),
      ],
    );
  }

  Widget _buildEditDaysSection(AsyncValue<List<TripDay>>? daysAsync) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outline),
        borderRadius: const BorderRadius.all(Radius.circular(TpRadius.md)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(TpSpacing.s3),
        child: daysAsync == null
            ? _buildDaysLoading()
            : daysAsync.when(
                data: _buildDaysData,
                error: (error, stackTrace) => _buildDaysError(),
                loading: _buildDaysLoading,
              ),
      ),
    );
  }

  Widget _buildDaysLoading() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildDaysHeader(summary: '載入中', onShift: null),
        const SizedBox(height: TpSpacing.s3),
        const Center(child: CircularProgressIndicator()),
      ],
    );
  }

  Widget _buildDaysError() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildDaysHeader(summary: '無法載入', onShift: null),
        const SizedBox(height: TpSpacing.s3),
        const _InlineError(message: '無法載入行程天數，請重新整理後再試'),
        const SizedBox(height: TpSpacing.s2),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('重試'),
            onPressed: () => ref.invalidate(tripDaysProvider(widget.tripId!)),
          ),
        ),
      ],
    );
  }

  Widget _buildDaysData(List<TripDay> days) {
    final sortedDays = _sortedDays(days);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildDaysHeader(
          summary: _dateRangeLabel(sortedDays),
          onShift: sortedDays.isEmpty || _daysMutating
              ? null
              : () => _openShiftDialog(sortedDays),
        ),
        if (_dayMutationError != null) ...[
          const SizedBox(height: TpSpacing.s3),
          _InlineError(message: _dayMutationError!),
        ],
        if (_daysMutating) ...[
          const SizedBox(height: TpSpacing.s3),
          const LinearProgressIndicator(),
        ],
        const SizedBox(height: TpSpacing.s3),
        Wrap(
          spacing: TpSpacing.s2,
          runSpacing: TpSpacing.s2,
          children: [
            OutlinedButton.icon(
              key: const ValueKey('trip-form-day-prepend'),
              icon: const Icon(Icons.first_page),
              label: const Text('前面加一天'),
              onPressed: _daysMutating
                  ? null
                  : () => _createTripDay(position: 'start'),
            ),
            OutlinedButton.icon(
              key: const ValueKey('trip-form-day-append'),
              icon: const Icon(Icons.add),
              label: const Text('最後加一天'),
              onPressed: _daysMutating
                  ? null
                  : () => _createTripDay(position: 'end'),
            ),
          ],
        ),
        const SizedBox(height: TpSpacing.s3),
        if (sortedDays.isEmpty)
          const Text('尚未建立行程日')
        else
          for (var index = 0; index < sortedDays.length; index++) ...[
            _buildDayRow(sortedDays[index], canDelete: sortedDays.length > 1),
            if (index < sortedDays.length - 1)
              for (final missingDate in _missingDatesBetween(
                sortedDays[index],
                sortedDays[index + 1],
              ))
                _buildMissingDateAction(missingDate),
            if (index != sortedDays.length - 1)
              const SizedBox(height: TpSpacing.s2),
          ],
      ],
    );
  }

  Widget _buildDaysHeader({
    required String summary,
    required VoidCallback? onShift,
  }) {
    return Row(
      children: [
        const Icon(Icons.calendar_today_outlined, size: 18),
        const SizedBox(width: TpSpacing.s2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('行程天數', style: Theme.of(context).textTheme.titleMedium),
              Text(summary, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
        IconButton(
          key: const ValueKey('trip-form-day-shift'),
          tooltip: '平移日期',
          icon: const Icon(Icons.date_range_outlined),
          onPressed: onShift,
        ),
      ],
    );
  }

  Widget _buildDayRow(TripDay day, {required bool canDelete}) {
    final entryCount = day.timeline.length;
    final dateLabel = [
      if (day.date != null && day.date!.isNotEmpty) day.date!,
      if (day.dayOfWeek != null && day.dayOfWeek!.isNotEmpty)
        '星期${day.dayOfWeek}',
    ].join(' ');
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: const BorderRadius.all(Radius.circular(TpRadius.md)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(TpSpacing.s3),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Day ${day.dayNum} · ${day.displayTitle}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: TpSpacing.s1),
                  Text(
                    [
                      if (dateLabel.isNotEmpty) dateLabel,
                      '$entryCount 個景點',
                    ].join(' · '),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            IconButton(
              key: ValueKey('trip-form-day-remove-${day.dayNum}'),
              tooltip: canDelete ? '刪除 Day ${day.dayNum}' : '至少保留一天',
              icon: const Icon(Icons.delete_outline),
              onPressed: canDelete && !_daysMutating
                  ? () => _confirmDeleteDay(day)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMissingDateAction(String missingDate) {
    return Padding(
      padding: const EdgeInsets.only(top: TpSpacing.s2),
      child: OutlinedButton.icon(
        key: ValueKey('trip-form-day-gap-$missingDate'),
        icon: const Icon(Icons.restore_outlined),
        label: Text('補上 $missingDate'),
        onPressed: _daysMutating
            ? null
            : () => _createTripDay(position: 'insert', date: missingDate),
      ),
    );
  }

  Future<void> _submit() async {
    final destinations = _destinationInputs();
    if (destinations.isEmpty) {
      setState(() => _submitError = '請至少輸入一個目的地');
      return;
    }

    if (!widget.isEdit && !_validateCreateDates()) return;

    setState(() {
      _submitting = true;
      _submitError = null;
    });
    try {
      final repository = ref.read(tripRepositoryProvider);
      final title = _nullableControllerText(_titleController);
      final description = _nullableControllerText(_descriptionController);
      final selectedTripId = widget.tripId;
      if (selectedTripId == null) {
        final name = destinations
            .map((destination) => destination.name)
            .join('、');
        final createdTripId = await repository.createTrip(
          id: _generateTripId(name),
          name: name,
          title: title,
          description: description,
          startDate: _startDateController.text.trim(),
          endDate: _endDateController.text.trim(),
          countries: 'JP',
          published: _published,
          lang: _lang,
          destinations: destinations,
        );
        ref.invalidate(myTripsProvider);
        if (mounted) {
          context.go('/trips?selected=${Uri.encodeComponent(createdTripId)}');
        }
      } else {
        await repository.updateTrip(
          id: selectedTripId,
          title: title,
          description: description,
          published: _published,
          lang: _lang,
          destinations: destinations,
        );
        ref.invalidate(myTripsProvider);
        ref.invalidate(tripDetailProvider(selectedTripId));
        if (mounted) {
          context.go('/trips?selected=${Uri.encodeComponent(selectedTripId)}');
        }
      }
    } on Exception {
      if (mounted) {
        setState(
          () => _submitError = widget.isEdit ? '儲存失敗，請稍後再試' : '建立失敗，請稍後再試',
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _createTripDay({required String position, String? date}) async {
    final tripId = widget.tripId;
    if (tripId == null) return;
    setState(() {
      _daysMutating = true;
      _dayMutationError = null;
    });
    try {
      await ref
          .read(tripRepositoryProvider)
          .createTripDay(tripId: tripId, position: position, date: date);
      _refreshTripDays(tripId);
      _showSnackBar(date == null ? '已新增行程日' : '已補上 $date');
    } on Exception catch (error) {
      if (mounted) {
        setState(
          () => _dayMutationError = _dayMutationErrorMessage(
            error,
            '新增行程日失敗，請稍後再試',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _daysMutating = false);
    }
  }

  Future<void> _confirmDeleteDay(TripDay day) async {
    final entryCount = day.timeline.length;
    final message = entryCount == 0
        ? '這會刪除 Day ${day.dayNum}，後續行程日會重新編號。'
        : '這會刪除 Day ${day.dayNum} 與 $entryCount 個景點，後續行程日會重新編號。';
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('刪除 Day ${day.dayNum}？'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const ValueKey('trip-form-day-delete-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('刪除'),
          ),
        ],
      ),
    );
    if (!mounted || shouldDelete != true) return;
    await _deleteTripDay(day);
  }

  Future<void> _deleteTripDay(TripDay day) async {
    final tripId = widget.tripId;
    if (tripId == null) return;
    setState(() {
      _daysMutating = true;
      _dayMutationError = null;
    });
    try {
      final result = await ref
          .read(tripRepositoryProvider)
          .deleteTripDay(tripId: tripId, dayNum: day.dayNum);
      _refreshTripDays(tripId);
      final removedCount = result.removedEntryCount;
      _showSnackBar(
        removedCount == 0 ? '已刪除 Day ${day.dayNum}' : '已刪除 $removedCount 個景點',
      );
    } on Exception catch (error) {
      if (mounted) {
        setState(
          () => _dayMutationError = _dayMutationErrorMessage(
            error,
            '刪除行程日失敗，請稍後再試',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _daysMutating = false);
    }
  }

  Future<void> _openShiftDialog(List<TripDay> days) async {
    final startDate = await showDialog<String>(
      context: context,
      builder: (dialogContext) => _ShiftDaysDialog(
        initialDate: _firstDayDate(days) ?? _startDateController.text.trim(),
      ),
    );
    if (!mounted || startDate == null) return;
    await _shiftTripDays(startDate);
  }

  Future<void> _shiftTripDays(String startDate) async {
    final tripId = widget.tripId;
    if (tripId == null) return;
    setState(() {
      _daysMutating = true;
      _dayMutationError = null;
    });
    try {
      final result = await ref
          .read(tripRepositoryProvider)
          .shiftTripDays(tripId: tripId, startDate: startDate);
      _refreshTripDays(tripId);
      final endDate = result.newEndDate;
      _showSnackBar(
        endDate == null || endDate.isEmpty
            ? '已平移至 ${result.newStartDate}'
            : '已平移至 ${result.newStartDate} - $endDate',
      );
    } on Exception catch (error) {
      if (mounted) {
        setState(
          () => _dayMutationError = _dayMutationErrorMessage(
            error,
            '平移行程日期失敗，請稍後再試',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _daysMutating = false);
    }
  }

  void _refreshTripDays(String tripId) {
    ref.invalidate(tripDaysProvider(tripId));
    ref.invalidate(tripDetailProvider(tripId));
    ref.invalidate(myTripsProvider);
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _dayMutationErrorMessage(Exception error, String fallback) {
    if (error is ApiError) return error.message;
    return fallback;
  }

  void _hydrateFromTrip(Trip trip) {
    if (_hydratedTripId == trip.id) return;
    _hydratedTripId = trip.id;
    _titleController.text = trip.title ?? '';
    _descriptionController.text = trip.description ?? '';
    _published = trip.published;
    _lang = switch (trip.lang) {
      'en' || 'ja' || 'zh-TW' => trip.lang!,
      _ => 'zh-TW',
    };
    _startDateController.text = trip.startDate ?? '';
    _endDateController.text = trip.endDate ?? '';
    for (final destination in _destinations) {
      destination.dispose();
    }
    _destinations
      ..clear()
      ..addAll(
        trip.destinations.isEmpty
            ? [_DestinationDraft()]
            : trip.destinations.map(
                (destination) => _DestinationDraft(
                  name: destination.name,
                  lat: destination.lat,
                  lng: destination.lng,
                  dayQuota: destination.dayQuota,
                  subAreas: destination.subAreas,
                ),
              ),
      );
  }

  List<TripDestinationInput> _destinationInputs() {
    return _destinations
        .map((destination) => destination.toInput())
        .where((destination) => destination.name.trim().isNotEmpty)
        .toList();
  }

  bool _validateCreateDates() {
    final startText = _startDateController.text.trim();
    final endText = _endDateController.text.trim();
    final startDate = _parseDate(startText);
    final endDate = _parseDate(endText);
    if (startDate == null || endDate == null) {
      setState(() => _submitError = '請輸入有效日期（YYYY-MM-DD）');
      return false;
    }
    if (endDate.isBefore(startDate)) {
      setState(() => _submitError = '回程日期不可早於出發日期');
      return false;
    }
    final totalDays = endDate.difference(startDate).inDays + 1;
    if (totalDays > 30) {
      setState(() => _submitError = '行程天數不可超過 30 天');
      return false;
    }
    return true;
  }

  DateTime? _parseDate(String value) {
    if (!_datePattern.hasMatch(value)) return null;
    return DateTime.tryParse('${value}T00:00:00Z');
  }

  List<TripDay> _sortedDays(List<TripDay> days) {
    return [...days]..sort((a, b) => a.dayNum.compareTo(b.dayNum));
  }

  String _dateRangeLabel(List<TripDay> days) {
    final firstDate = _firstDayDate(days);
    final lastDate = _lastDayDate(days);
    if (firstDate == null || lastDate == null) return '日期未設定';
    return '$firstDate - $lastDate';
  }

  String? _firstDayDate(List<TripDay> days) {
    if (days.isEmpty) return null;
    final date = days.first.date?.trim();
    return date == null || date.isEmpty ? null : date;
  }

  String? _lastDayDate(List<TripDay> days) {
    if (days.isEmpty) return null;
    final date = days.last.date?.trim();
    return date == null || date.isEmpty ? null : date;
  }

  List<String> _missingDatesBetween(TripDay before, TripDay after) {
    final beforeDate = _parseDate(before.date ?? '');
    final afterDate = _parseDate(after.date ?? '');
    if (beforeDate == null || afterDate == null) return const [];
    final gapDays = afterDate.difference(beforeDate).inDays;
    if (gapDays <= 1) return const [];
    return [
      for (var offset = 1; offset < gapDays; offset++)
        _formatDate(beforeDate.add(Duration(days: offset))),
    ];
  }

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  String? _nullableControllerText(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : value;
  }

  String _generateTripId(String name) {
    final slug = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final base = slug.isEmpty ? 'trip' : slug;
    final suffix = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    final id = '$base-$suffix';
    return id.length <= 100 ? id : id.substring(0, 100);
  }
}

class _DestinationDraft {
  _DestinationDraft({
    String name = '',
    this.lat,
    this.lng,
    this.dayQuota,
    List<String> subAreas = const [],
  }) : _initialName = name.trim(),
       nameController = TextEditingController(text: name),
       subAreas = List.unmodifiable(subAreas);

  final String _initialName;
  final TextEditingController nameController;
  final double? lat;
  final double? lng;
  final int? dayQuota;
  final List<String> subAreas;

  TripDestinationInput toInput() {
    final currentName = nameController.text.trim();
    final nameChanged = _initialName.isNotEmpty && currentName != _initialName;
    return TripDestinationInput(
      name: currentName,
      lat: nameChanged ? null : lat,
      lng: nameChanged ? null : lng,
      dayQuota: dayQuota,
      subAreas: subAreas,
    );
  }

  void dispose() => nameController.dispose();
}

class _ShiftDaysDialog extends StatefulWidget {
  const _ShiftDaysDialog({required this.initialDate});

  final String initialDate;

  @override
  State<_ShiftDaysDialog> createState() => _ShiftDaysDialogState();
}

class _ShiftDaysDialogState extends State<_ShiftDaysDialog> {
  final _datePattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialDate);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('平移行程日期'),
      content: TextField(
        key: const ValueKey('trip-form-day-shift-date'),
        controller: _controller,
        decoration: InputDecoration(
          labelText: '新的 Day 1 日期',
          hintText: 'YYYY-MM-DD',
          errorText: _errorText,
        ),
        keyboardType: TextInputType.datetime,
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9-]'))],
        autofocus: true,
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const ValueKey('trip-form-day-shift-confirm'),
          onPressed: _submit,
          child: const Text('套用'),
        ),
      ],
    );
  }

  void _submit() {
    final value = _controller.text.trim();
    if (!_datePattern.hasMatch(value) ||
        DateTime.tryParse('${value}T00:00:00Z') == null) {
      setState(() => _errorText = '請輸入 YYYY-MM-DD');
      return;
    }
    Navigator.of(context).pop(value);
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: const BorderRadius.all(Radius.circular(TpRadius.md)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(TpSpacing.s3),
        child: Text(
          message,
          style: TextStyle(color: colorScheme.onErrorContainer),
        ),
      ),
    );
  }
}

class _LoadErrorState extends StatelessWidget {
  const _LoadErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: TpSpacing.s3),
          FilledButton(onPressed: onRetry, child: const Text('重試')),
        ],
      ),
    );
  }
}
