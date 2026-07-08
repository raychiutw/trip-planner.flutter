import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/providers.dart';
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
  bool _submitting = false;

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
      return tripAsync.when(
        data: (trip) {
          _hydrateFromTrip(trip);
          return _buildScaffold(trip: trip);
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

  Widget _buildScaffold({Trip? trip}) {
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
                _ReadOnlyDateRange(trip: trip)
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

class _ReadOnlyDateRange extends StatelessWidget {
  const _ReadOnlyDateRange({required this.trip});

  final Trip? trip;

  @override
  Widget build(BuildContext context) {
    final start = trip?.startDate?.trim();
    final end = trip?.endDate?.trim();
    final label = start == null || start.isEmpty || end == null || end.isEmpty
        ? '日期未設定'
        : '$start - $end';
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outline),
        borderRadius: const BorderRadius.all(Radius.circular(TpRadius.md)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(TpSpacing.s3),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined, size: 18),
            const SizedBox(width: TpSpacing.s2),
            Expanded(child: Text(label)),
          ],
        ),
      ),
    );
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
