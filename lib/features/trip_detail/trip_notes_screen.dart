import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/providers.dart';
import '../../models/notes.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import 'trip_providers.dart';

/// 行程筆記：5-section accordion（航班/住宿/預訂/行前須知/緊急聯絡）。
class TripNotesScreen extends ConsumerStatefulWidget {
  const TripNotesScreen({super.key, required this.tripId});

  final String tripId;

  @override
  ConsumerState<TripNotesScreen> createState() => _TripNotesScreenState();
}

class _TripNotesScreenState extends ConsumerState<TripNotesScreen> {
  static const _pollInterval = Duration(seconds: 3);

  String? _actionError;
  String? _savingKey;
  TripNoteAiGenerationJob? _aiJob;
  Timer? _pollTimer;
  bool _pollingNow = false;

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(tripNotesProvider(widget.tripId));
    return Scaffold(
      appBar: AppBar(title: const Text('行程筆記')),
      body: notesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(TpSpacing.s6),
            child: Text('載入失敗：$error', textAlign: TextAlign.center),
          ),
        ),
        data: (notes) => _buildSections(context, notes),
      ),
    );
  }

  Widget _buildSections(BuildContext context, TripNotes notes) {
    final tones = Theme.of(context).extension<TpTones>()!;
    return ListView(
      padding: const EdgeInsets.all(TpSpacing.s4),
      children: [
        if (_actionError != null) ...[
          _InlineError(message: _actionError!),
          const SizedBox(height: TpSpacing.s3),
        ],
        if (_aiJob != null) ...[
          _AiPendingBanner(docType: _aiJob!.docType),
          const SizedBox(height: TpSpacing.s3),
        ],
        _NotesSection(
          countKeySuffix: 'flights',
          icon: Icons.flight_takeoff,
          iconColor: tones.sageDeep,
          title: '航班',
          count: notes.flights.length,
          initiallyExpanded: true,
          actions: [
            _HeaderIconButton(
              key: const ValueKey('notes-add-flights'),
              tooltip: '新增航班',
              icon: Icons.add,
              onPressed: _savingKey == null ? _createFlight : null,
            ),
          ],
          rows: [
            for (final flight in notes.flights)
              _FlightRow(
                flight,
                onEdit: () => _editFlight(flight),
                onDelete: () => _confirmDelete(
                  section: TripNoteSection.flights,
                  rowId: flight.id,
                  label: '${flight.airline} ${flight.flightNo}'.trim(),
                ),
              ),
          ],
        ),
        _NotesSection(
          countKeySuffix: 'lodgings',
          icon: Icons.hotel_outlined,
          iconColor: tones.sageDeep,
          title: '住宿',
          count: notes.lodgings.length,
          actions: [
            _HeaderIconButton(
              key: const ValueKey('notes-add-lodgings'),
              tooltip: '新增住宿',
              icon: Icons.add,
              onPressed: _savingKey == null ? _createLodging : null,
            ),
          ],
          rows: [
            for (final lodging in notes.lodgings)
              _LodgingRow(
                lodging,
                onEdit: () => _editLodging(lodging),
                onDelete: () => _confirmDelete(
                  section: TripNoteSection.lodgings,
                  rowId: lodging.id,
                  label: lodging.name,
                ),
              ),
          ],
        ),
        _NotesSection(
          countKeySuffix: 'reservations',
          icon: Icons.confirmation_number_outlined,
          iconColor: tones.pinkDeep,
          title: '預訂',
          count: notes.reservations.length,
          actions: [
            _HeaderIconButton(
              key: const ValueKey('notes-add-reservations'),
              tooltip: '新增預訂',
              icon: Icons.add,
              onPressed: _savingKey == null ? _createReservation : null,
            ),
          ],
          rows: [
            for (final reservation in notes.reservations)
              _ReservationRow(
                reservation,
                onEdit: () => _editReservation(reservation),
                onDelete: () => _confirmDelete(
                  section: TripNoteSection.reservations,
                  rowId: reservation.id,
                  label: reservation.title,
                ),
              ),
          ],
        ),
        _NotesSection(
          countKeySuffix: 'pretrip',
          icon: Icons.checklist_outlined,
          iconColor: tones.accentDeep,
          title: '行前須知',
          count: notes.pretripNotes.length,
          actions: [
            _HeaderIconButton(
              key: const ValueKey('notes-ai-pretrip-tips'),
              tooltip: 'AI 生成一般行前須知',
              icon: Icons.auto_awesome,
              onPressed: _canStartAi ? () => _startAiGeneration('tips') : null,
            ),
            _HeaderIconButton(
              key: const ValueKey('notes-ai-pretrip-lodging'),
              tooltip: 'AI 生成住宿在地建議',
              icon: Icons.hotel_class_outlined,
              onPressed: _canStartAi && notes.lodgings.isNotEmpty
                  ? () => _startAiGeneration('lodging-tips')
                  : null,
            ),
            _HeaderIconButton(
              key: const ValueKey('notes-add-pretrip'),
              tooltip: '新增行前須知',
              icon: Icons.add,
              onPressed: _savingKey == null ? _createPretripNote : null,
            ),
          ],
          rows: [
            for (final pretripNote in notes.pretripNotes)
              _PretripNoteRow(
                pretripNote,
                onEdit: () => _editPretripNote(pretripNote),
                onDelete: () => _confirmDelete(
                  section: TripNoteSection.pretrip,
                  rowId: pretripNote.id,
                  label: pretripNote.title,
                ),
              ),
          ],
        ),
        _NotesSection(
          countKeySuffix: 'emergency',
          icon: Icons.support_agent_outlined,
          iconColor: tones.accentDeep,
          title: '緊急聯絡',
          count: notes.emergencyContacts.length,
          actions: [
            _HeaderIconButton(
              key: const ValueKey('notes-ai-emergency'),
              tooltip: 'AI 生成緊急聯絡',
              icon: Icons.auto_awesome,
              onPressed: _canStartAi
                  ? () => _startAiGeneration('emergency')
                  : null,
            ),
            _HeaderIconButton(
              key: const ValueKey('notes-add-emergency'),
              tooltip: '新增緊急聯絡',
              icon: Icons.add,
              onPressed: _savingKey == null ? _createEmergencyContact : null,
            ),
          ],
          rows: [
            for (final contact in notes.emergencyContacts)
              _EmergencyContactRow(
                contact,
                onEdit: () => _editEmergencyContact(contact),
                onDelete: () => _confirmDelete(
                  section: TripNoteSection.emergency,
                  rowId: contact.id,
                  label: contact.name,
                ),
              ),
          ],
        ),
      ],
    );
  }

  bool get _canStartAi => _aiJob == null && _savingKey == null;

  Future<void> _createFlight() async {
    final values = await _showNoteForm(
      title: '新增航班',
      fields: const [
        _NoteFormField(
          keyName: 'airline',
          valueKey: 'notes-flight-airline',
          label: '航空公司',
        ),
        _NoteFormField(
          keyName: 'flightNo',
          valueKey: 'notes-flight-no',
          label: '航班',
        ),
        _NoteFormField(
          keyName: 'departAirport',
          valueKey: 'notes-flight-depart-airport',
          label: '出發機場',
        ),
        _NoteFormField(
          keyName: 'arriveAirport',
          valueKey: 'notes-flight-arrive-airport',
          label: '抵達機場',
        ),
        _NoteFormField(keyName: 'departAt', label: '起飛時間'),
        _NoteFormField(keyName: 'arriveAt', label: '抵達時間'),
        _NoteFormField(keyName: 'note', label: '備註', maxLines: 3),
      ],
    );
    if (values == null) return;
    await _runMutation(
      key: 'create-flight',
      errorMessage: '新增航班失敗，請稍後再試',
      action: () async {
        await ref
            .read(tripRepositoryProvider)
            .createTripFlight(
              tripId: widget.tripId,
              airline: values['airline'],
              flightNo: values['flightNo'],
              departAirport: values['departAirport'],
              arriveAirport: values['arriveAirport'],
              departAt: values['departAt'],
              arriveAt: values['arriveAt'],
              note: values['note'],
            );
      },
    );
  }

  Future<void> _editFlight(TripFlight flight) async {
    final values = await _showNoteForm(
      title: '編輯航班',
      fields: [
        _NoteFormField(
          keyName: 'airline',
          valueKey: 'notes-flight-airline',
          label: '航空公司',
          initialValue: flight.airline,
        ),
        _NoteFormField(
          keyName: 'flightNo',
          valueKey: 'notes-flight-no',
          label: '航班',
          initialValue: flight.flightNo,
        ),
        _NoteFormField(
          keyName: 'departAirport',
          valueKey: 'notes-flight-depart-airport',
          label: '出發機場',
          initialValue: flight.departAirport,
        ),
        _NoteFormField(
          keyName: 'arriveAirport',
          valueKey: 'notes-flight-arrive-airport',
          label: '抵達機場',
          initialValue: flight.arriveAirport,
        ),
        _NoteFormField(
          keyName: 'departAt',
          label: '起飛時間',
          initialValue: flight.departAt,
        ),
        _NoteFormField(
          keyName: 'arriveAt',
          label: '抵達時間',
          initialValue: flight.arriveAt,
        ),
        _NoteFormField(
          keyName: 'note',
          label: '備註',
          initialValue: flight.note,
          maxLines: 3,
        ),
      ],
    );
    if (values == null) return;
    await _runMutation(
      key: 'edit-flight-${flight.id}',
      errorMessage: '航班儲存失敗，請稍後再試',
      action: () async {
        await ref
            .read(tripRepositoryProvider)
            .updateTripFlight(
              tripId: widget.tripId,
              rowId: flight.id,
              expectedVersion: flight.version,
              airline: values['airline'],
              flightNo: values['flightNo'],
              departAirport: values['departAirport'],
              arriveAirport: values['arriveAirport'],
              departAt: values['departAt'],
              arriveAt: values['arriveAt'],
              note: values['note'],
            );
      },
    );
  }

  Future<void> _createLodging() async {
    final values = await _showNoteForm(
      title: '新增住宿',
      fields: const [
        _NoteFormField(keyName: 'name', label: '飯店 / 民宿'),
        _NoteFormField(keyName: 'address', label: '地址'),
        _NoteFormField(keyName: 'checkInAt', label: '入住時間'),
        _NoteFormField(keyName: 'checkOutAt', label: '退房時間'),
        _NoteFormField(keyName: 'bookingNo', label: '訂房編號'),
        _NoteFormField(keyName: 'phone', label: '電話'),
        _NoteFormField(keyName: 'note', label: '備註', maxLines: 3),
      ],
    );
    if (values == null) return;
    await _runMutation(
      key: 'create-lodging',
      errorMessage: '新增住宿失敗，請稍後再試',
      action: () async {
        await ref
            .read(tripRepositoryProvider)
            .createTripLodging(
              tripId: widget.tripId,
              name: values['name'],
              address: values['address'],
              checkInAt: values['checkInAt'],
              checkOutAt: values['checkOutAt'],
              bookingNo: values['bookingNo'],
              phone: values['phone'],
              note: values['note'],
            );
      },
    );
  }

  Future<void> _editLodging(TripLodging lodging) async {
    final values = await _showNoteForm(
      title: '編輯住宿',
      fields: [
        _NoteFormField(
          keyName: 'name',
          label: '飯店 / 民宿',
          initialValue: lodging.name,
        ),
        _NoteFormField(
          keyName: 'address',
          label: '地址',
          initialValue: lodging.address,
        ),
        _NoteFormField(
          keyName: 'checkInAt',
          label: '入住時間',
          initialValue: lodging.checkInAt,
        ),
        _NoteFormField(
          keyName: 'checkOutAt',
          label: '退房時間',
          initialValue: lodging.checkOutAt,
        ),
        _NoteFormField(
          keyName: 'bookingNo',
          label: '訂房編號',
          initialValue: lodging.bookingNo,
        ),
        _NoteFormField(
          keyName: 'phone',
          label: '電話',
          initialValue: lodging.phone,
        ),
        _NoteFormField(
          keyName: 'note',
          label: '備註',
          initialValue: lodging.note,
          maxLines: 3,
        ),
      ],
    );
    if (values == null) return;
    await _runMutation(
      key: 'edit-lodging-${lodging.id}',
      errorMessage: '住宿儲存失敗，請稍後再試',
      action: () async {
        await ref
            .read(tripRepositoryProvider)
            .updateTripLodging(
              tripId: widget.tripId,
              rowId: lodging.id,
              expectedVersion: lodging.version,
              name: values['name'],
              address: values['address'],
              checkInAt: values['checkInAt'],
              checkOutAt: values['checkOutAt'],
              bookingNo: values['bookingNo'],
              phone: values['phone'],
              note: values['note'],
            );
      },
    );
  }

  Future<void> _createReservation() async {
    final values = await _showNoteForm(
      title: '新增預訂',
      fields: const [
        _NoteFormField(keyName: 'title', label: '名稱 / 標題'),
        _NoteFormField(
          keyName: 'kind',
          label: '類型',
          initialValue: 'restaurant',
        ),
        _NoteFormField(keyName: 'reservedAt', label: '預訂時間'),
        _NoteFormField(keyName: 'partySize', label: '人數'),
        _NoteFormField(keyName: 'reservationNo', label: '預訂編號'),
        _NoteFormField(keyName: 'phone', label: '電話'),
        _NoteFormField(keyName: 'note', label: '備註', maxLines: 3),
      ],
    );
    if (values == null) return;
    await _runMutation(
      key: 'create-reservation',
      errorMessage: '新增預訂失敗，請稍後再試',
      action: () async {
        await ref
            .read(tripRepositoryProvider)
            .createTripReservation(
              tripId: widget.tripId,
              title: values['title'],
              kind: values['kind'],
              reservedAt: values['reservedAt'],
              partySize: _intValue(values['partySize']),
              reservationNo: values['reservationNo'],
              phone: values['phone'],
              note: values['note'],
            );
      },
    );
  }

  Future<void> _editReservation(TripReservation reservation) async {
    final values = await _showNoteForm(
      title: '編輯預訂',
      fields: [
        _NoteFormField(
          keyName: 'title',
          label: '名稱 / 標題',
          initialValue: reservation.title,
        ),
        _NoteFormField(
          keyName: 'kind',
          label: '類型',
          initialValue: reservation.kind,
        ),
        _NoteFormField(
          keyName: 'reservedAt',
          label: '預訂時間',
          initialValue: reservation.reservedAt,
        ),
        _NoteFormField(
          keyName: 'partySize',
          label: '人數',
          initialValue: reservation.partySize == 0
              ? ''
              : '${reservation.partySize}',
        ),
        _NoteFormField(
          keyName: 'reservationNo',
          label: '預訂編號',
          initialValue: reservation.reservationNo,
        ),
        _NoteFormField(
          keyName: 'phone',
          label: '電話',
          initialValue: reservation.phone,
        ),
        _NoteFormField(
          keyName: 'note',
          label: '備註',
          initialValue: reservation.note,
          maxLines: 3,
        ),
      ],
    );
    if (values == null) return;
    await _runMutation(
      key: 'edit-reservation-${reservation.id}',
      errorMessage: '預訂儲存失敗，請稍後再試',
      action: () async {
        await ref
            .read(tripRepositoryProvider)
            .updateTripReservation(
              tripId: widget.tripId,
              rowId: reservation.id,
              expectedVersion: reservation.version,
              title: values['title'],
              kind: values['kind'],
              reservedAt: values['reservedAt'],
              partySize: _intValue(values['partySize']),
              reservationNo: values['reservationNo'],
              phone: values['phone'],
              note: values['note'],
            );
      },
    );
  }

  Future<void> _createPretripNote() async {
    final values = await _showNoteForm(
      title: '新增行前須知',
      fields: const [
        _NoteFormField(
          keyName: 'title',
          valueKey: 'notes-pretrip-title',
          label: '標題',
        ),
        _NoteFormField(
          keyName: 'content',
          valueKey: 'notes-pretrip-content',
          label: '內容',
          maxLines: 5,
        ),
      ],
    );
    if (values == null) return;
    await _runMutation(
      key: 'create-pretrip',
      errorMessage: '新增行前須知失敗，請稍後再試',
      action: () async {
        await ref
            .read(tripRepositoryProvider)
            .createTripPretripNote(
              tripId: widget.tripId,
              title: values['title'],
              content: values['content'],
            );
      },
    );
  }

  Future<void> _editPretripNote(TripPretripNote note) async {
    final values = await _showNoteForm(
      title: '編輯行前須知',
      fields: [
        _NoteFormField(
          keyName: 'title',
          valueKey: 'notes-pretrip-title',
          label: '標題',
          initialValue: note.title,
        ),
        _NoteFormField(
          keyName: 'content',
          valueKey: 'notes-pretrip-content',
          label: '內容',
          initialValue: note.content,
          maxLines: 5,
        ),
      ],
    );
    if (values == null) return;
    await _runMutation(
      key: 'edit-pretrip-${note.id}',
      errorMessage: '行前須知儲存失敗，請稍後再試',
      action: () async {
        await ref
            .read(tripRepositoryProvider)
            .updateTripPretripNote(
              tripId: widget.tripId,
              rowId: note.id,
              expectedVersion: note.version,
              title: values['title'],
              content: values['content'],
            );
      },
    );
  }

  Future<void> _createEmergencyContact() async {
    final values = await _showNoteForm(
      title: '新增緊急聯絡',
      fields: const [
        _NoteFormField(keyName: 'name', label: '名稱'),
        _NoteFormField(keyName: 'kind', label: '類型', initialValue: 'other'),
        _NoteFormField(keyName: 'relationship', label: '關係 / 用途'),
        _NoteFormField(keyName: 'phone', label: '電話'),
        _NoteFormField(keyName: 'email', label: 'Email'),
      ],
    );
    if (values == null) return;
    await _runMutation(
      key: 'create-emergency',
      errorMessage: '新增緊急聯絡失敗，請稍後再試',
      action: () async {
        await ref
            .read(tripRepositoryProvider)
            .createTripEmergencyContact(
              tripId: widget.tripId,
              name: values['name'],
              kind: values['kind'],
              relationship: values['relationship'],
              phone: values['phone'],
              email: values['email'],
            );
      },
    );
  }

  Future<void> _editEmergencyContact(TripEmergencyContact contact) async {
    final values = await _showNoteForm(
      title: '編輯緊急聯絡',
      fields: [
        _NoteFormField(
          keyName: 'name',
          label: '名稱',
          initialValue: contact.name,
        ),
        _NoteFormField(
          keyName: 'kind',
          label: '類型',
          initialValue: contact.kind,
        ),
        _NoteFormField(
          keyName: 'relationship',
          label: '關係 / 用途',
          initialValue: contact.relationship,
        ),
        _NoteFormField(
          keyName: 'phone',
          label: '電話',
          initialValue: contact.phone,
        ),
        _NoteFormField(
          keyName: 'email',
          label: 'Email',
          initialValue: contact.email,
        ),
      ],
    );
    if (values == null) return;
    await _runMutation(
      key: 'edit-emergency-${contact.id}',
      errorMessage: '緊急聯絡儲存失敗，請稍後再試',
      action: () async {
        await ref
            .read(tripRepositoryProvider)
            .updateTripEmergencyContact(
              tripId: widget.tripId,
              rowId: contact.id,
              expectedVersion: contact.version,
              name: values['name'],
              kind: values['kind'],
              relationship: values['relationship'],
              phone: values['phone'],
              email: values['email'],
            );
      },
    );
  }

  Future<Map<String, String>?> _showNoteForm({
    required String title,
    required List<_NoteFormField> fields,
  }) async {
    return showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => _NoteFormDialog(title: title, fields: fields),
    );
  }

  Future<void> _confirmDelete({
    required TripNoteSection section,
    required int rowId,
    required String label,
  }) async {
    final displayLabel = label.trim().isEmpty ? '這筆資料' : label.trim();
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('刪除筆記？'),
          content: Text('「$displayLabel」將被刪除，此操作無法復原。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              key: const ValueKey('notes-delete-confirm'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('刪除'),
            ),
          ],
        );
      },
    );
    if (shouldDelete != true) return;
    await _runMutation(
      key: 'delete-${section.pathSegment}-$rowId',
      errorMessage: '刪除筆記失敗，請稍後再試',
      action: () async {
        await ref
            .read(tripRepositoryProvider)
            .deleteTripNoteRow(
              tripId: widget.tripId,
              section: section,
              rowId: rowId,
            );
      },
    );
  }

  Future<void> _startAiGeneration(String docType) async {
    if (_aiJob != null || _savingKey != null) return;
    setState(() => _actionError = null);
    try {
      final job = await ref
          .read(tripRepositoryProvider)
          .generateTripNotes(tripId: widget.tripId, docType: docType);
      if (!mounted) return;
      setState(() => _aiJob = job);
      _startAiPolling(job.requestId);
    } on Exception {
      if (!mounted) return;
      setState(() => _actionError = 'AI 生成啟動失敗，請稍後再試');
    }
  }

  void _startAiPolling(int requestId) {
    _pollTimer?.cancel();
    unawaited(_pollAiJob(requestId));
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      unawaited(_pollAiJob(requestId));
    });
  }

  Future<void> _pollAiJob(int requestId) async {
    if (_pollingNow) return;
    _pollingNow = true;
    try {
      final request = await ref
          .read(tripRepositoryProvider)
          .fetchTripRequest(requestId);
      if (!mounted || _aiJob?.requestId != requestId) return;
      if (request.isCompleted) {
        _pollTimer?.cancel();
        _pollTimer = null;
        setState(() => _aiJob = null);
        ref.invalidate(tripNotesProvider(widget.tripId));
      } else if (request.isFailed) {
        _pollTimer?.cancel();
        _pollTimer = null;
        setState(() {
          _aiJob = null;
          _actionError = 'AI 生成失敗，請稍後再試';
        });
      }
    } on Exception {
      if (mounted) {
        setState(() => _actionError = '暫時無法更新 AI 生成狀態');
      }
    } finally {
      _pollingNow = false;
    }
  }

  Future<void> _runMutation({
    required String key,
    required String errorMessage,
    required Future<void> Function() action,
  }) async {
    if (_savingKey != null) return;
    setState(() {
      _savingKey = key;
      _actionError = null;
    });
    try {
      await action();
      if (!mounted) return;
      ref.invalidate(tripNotesProvider(widget.tripId));
      setState(() => _savingKey = null);
    } on Exception {
      if (!mounted) return;
      setState(() {
        _savingKey = null;
        _actionError = errorMessage;
      });
    }
  }

  int? _intValue(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return int.tryParse(trimmed);
  }
}

class _NoteFormField {
  const _NoteFormField({
    required this.keyName,
    required this.label,
    this.valueKey,
    this.initialValue = '',
    this.maxLines = 1,
  });

  final String keyName;
  final String label;
  final String? valueKey;
  final String initialValue;
  final int maxLines;
}

class _NoteFormDialog extends StatefulWidget {
  const _NoteFormDialog({required this.title, required this.fields});

  final String title;
  final List<_NoteFormField> fields;

  @override
  State<_NoteFormDialog> createState() => _NoteFormDialogState();
}

class _NoteFormDialogState extends State<_NoteFormDialog> {
  late final Map<String, TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = {
      for (final field in widget.fields)
        field.keyName: TextEditingController(text: field.initialValue),
    };
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final field in widget.fields) ...[
              TextField(
                key: ValueKey(field.valueKey ?? 'notes-${field.keyName}'),
                controller: _controllers[field.keyName],
                maxLines: field.maxLines,
                keyboardType: field.maxLines > 1
                    ? TextInputType.multiline
                    : TextInputType.text,
                decoration: InputDecoration(
                  labelText: field.label,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: TpSpacing.s3),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const ValueKey('notes-form-save'),
          onPressed: () {
            Navigator.of(context).pop({
              for (final entry in _controllers.entries)
                entry.key: entry.value.text.trim(),
            });
          },
          child: const Text('儲存'),
        ),
      ],
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon, size: 18),
      visualDensity: VisualDensity.compact,
      onPressed: onPressed,
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

class _AiPendingBanner extends StatelessWidget {
  const _AiPendingBanner({required this.docType});

  final String docType;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = docType == 'emergency' ? '緊急聯絡' : '行前須知';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: const BorderRadius.all(Radius.circular(TpRadius.md)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(TpSpacing.s3),
        child: Row(
          children: [
            const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: TpSpacing.s2),
            Expanded(
              child: Text(
                'AI 正在生成$label，完成後會自動重新整理。',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 單一 accordion section：hairline 卡片 + ExpansionTile header（icon/標題/count badge）。
class _NotesSection extends StatelessWidget {
  const _NotesSection({
    required this.countKeySuffix,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.count,
    required this.rows,
    this.actions = const [],
    this.initiallyExpanded = false,
  });

  final String countKeySuffix;
  final IconData icon;
  final Color iconColor;
  final String title;
  final int count;
  final List<Widget> rows;
  final List<Widget> actions;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tones = theme.extension<TpTones>()!;
    return Container(
      margin: const EdgeInsets.only(bottom: TpSpacing.s3),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: const BorderRadius.all(Radius.circular(TpRadius.lg)),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: TpSpacing.s4),
        childrenPadding: const EdgeInsets.fromLTRB(
          TpSpacing.s4,
          0,
          TpSpacing.s4,
          TpSpacing.s4,
        ),
        iconColor: theme.colorScheme.onSurfaceVariant,
        collapsedIconColor: theme.colorScheme.onSurfaceVariant,
        leading: Icon(icon, size: 20, color: iconColor),
        title: Row(
          children: [
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(fontSize: 16),
              ),
            ),
            const SizedBox(width: TpSpacing.s2),
            Container(
              key: ValueKey('notes-count-$countKeySuffix'),
              padding: const EdgeInsets.symmetric(
                horizontal: TpSpacing.s2,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: tones.accentSubtle,
                borderRadius: const BorderRadius.all(Radius.circular(999)),
              ),
              child: Text(
                '$count',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: tones.accentDeep,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const Spacer(),
            for (final action in actions) action,
          ],
        ),
        children: rows.isEmpty
            ? [
                Padding(
                  padding: const EdgeInsets.only(bottom: TpSpacing.s2),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '尚無資料',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ]
            : rows,
      ),
    );
  }
}

/// section 內的 row 卡片（hairline、radius md）。
class _NoteRowCard extends StatelessWidget {
  const _NoteRowCard({required this.children, required this.actions});

  final List<Widget> children;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: TpSpacing.s2),
      padding: const EdgeInsets.all(TpSpacing.s3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.all(Radius.circular(TpRadius.md)),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(spacing: TpSpacing.s1, children: actions),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _RowActionButtons extends StatelessWidget {
  const _RowActionButtons({
    required this.editKey,
    required this.deleteKey,
    required this.onEdit,
    required this.onDelete,
  });

  final String editKey;
  final String deleteKey;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          key: ValueKey(editKey),
          tooltip: '編輯',
          icon: const Icon(Icons.edit_outlined),
          onPressed: onEdit,
        ),
        IconButton(
          key: ValueKey(deleteKey),
          tooltip: '刪除',
          icon: const Icon(Icons.delete_outline),
          onPressed: onDelete,
        ),
      ],
    );
  }
}

/// 時間/日期文字（tabular figures）。
class _TimeText extends StatelessWidget {
  const _TimeText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

/// kind 小 chip（三色 tone）。
class _KindChip extends StatelessWidget {
  const _KindChip({required this.label, required this.bg, required this.fg});

  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TpSpacing.s2,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.all(Radius.circular(999)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: fg),
      ),
    );
  }
}

class _FlightRow extends StatelessWidget {
  const _FlightRow(this.flight, {required this.onEdit, required this.onDelete});

  final TripFlight flight;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final flightTitle = '${flight.airline} ${flight.flightNo}'.trim();
    return _NoteRowCard(
      actions: [
        _RowActionButtons(
          editKey: 'notes-edit-flights-${flight.id}',
          deleteKey: 'notes-delete-flights-${flight.id}',
          onEdit: onEdit,
          onDelete: onDelete,
        ),
      ],
      children: [
        if (flightTitle.isNotEmpty)
          Text(
            flightTitle,
            style: theme.textTheme.titleMedium?.copyWith(fontSize: 15),
          ),
        const SizedBox(height: TpSpacing.s1),
        Text(
          '${flight.departAirport} → ${flight.arriveAirport}',
          style: theme.textTheme.bodyMedium,
        ),
        if (flight.departAt.isNotEmpty) ...[
          const SizedBox(height: TpSpacing.s1),
          _TimeText(flight.departAt),
        ],
      ],
    );
  }
}

class _LodgingRow extends StatelessWidget {
  const _LodgingRow(
    this.lodging, {
    required this.onEdit,
    required this.onDelete,
  });

  final TripLodging lodging;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _NoteRowCard(
      actions: [
        _RowActionButtons(
          editKey: 'notes-edit-lodgings-${lodging.id}',
          deleteKey: 'notes-delete-lodgings-${lodging.id}',
          onEdit: onEdit,
          onDelete: onDelete,
        ),
      ],
      children: [
        Text(
          lodging.name,
          style: theme.textTheme.titleMedium?.copyWith(fontSize: 15),
        ),
        if (lodging.checkInAt.isNotEmpty || lodging.checkOutAt.isNotEmpty) ...[
          const SizedBox(height: TpSpacing.s1),
          _TimeText('${lodging.checkInAt} ~ ${lodging.checkOutAt}'),
        ],
        if (lodging.address.isNotEmpty) ...[
          const SizedBox(height: TpSpacing.s1),
          Text(
            lodging.address,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _ReservationRow extends StatelessWidget {
  const _ReservationRow(
    this.reservation, {
    required this.onEdit,
    required this.onDelete,
  });

  final TripReservation reservation;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  static const _kindLabels = {
    'restaurant': '餐廳',
    'experience': '體驗',
    'ticket': '票券',
    'transport': '交通',
    'other': '其他',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tones = theme.extension<TpTones>()!;
    final (chipBg, chipFg) = switch (reservation.kind) {
      'restaurant' => (tones.pinkBg, tones.pinkDeep),
      'transport' => (tones.sageBg, tones.sageDeep),
      _ => (tones.accentBg, tones.accentDeep),
    };
    return _NoteRowCard(
      actions: [
        _RowActionButtons(
          editKey: 'notes-edit-reservations-${reservation.id}',
          deleteKey: 'notes-delete-reservations-${reservation.id}',
          onEdit: onEdit,
          onDelete: onDelete,
        ),
      ],
      children: [
        Row(
          children: [
            _KindChip(
              label: _kindLabels[reservation.kind] ?? reservation.kind,
              bg: chipBg,
              fg: chipFg,
            ),
            const SizedBox(width: TpSpacing.s2),
            Expanded(
              child: Text(
                reservation.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(fontSize: 15),
              ),
            ),
          ],
        ),
        if (reservation.reservedAt.isNotEmpty) ...[
          const SizedBox(height: TpSpacing.s1),
          _TimeText(reservation.reservedAt),
        ],
      ],
    );
  }
}

class _PretripNoteRow extends StatelessWidget {
  const _PretripNoteRow(
    this.pretripNote, {
    required this.onEdit,
    required this.onDelete,
  });

  final TripPretripNote pretripNote;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _NoteRowCard(
      actions: [
        _RowActionButtons(
          editKey: 'notes-edit-pretrip-${pretripNote.id}',
          deleteKey: 'notes-delete-pretrip-${pretripNote.id}',
          onEdit: onEdit,
          onDelete: onDelete,
        ),
      ],
      children: [
        if (pretripNote.aiGenerated)
          _KindChip(
            label: 'AI 建議',
            bg: theme.colorScheme.primaryContainer,
            fg: theme.colorScheme.onPrimaryContainer,
          ),
        if (pretripNote.title.isNotEmpty) ...[
          const SizedBox(height: TpSpacing.s1),
          Text(
            pretripNote.title,
            style: theme.textTheme.titleMedium?.copyWith(fontSize: 15),
          ),
        ],
        if (pretripNote.content.isNotEmpty) ...[
          const SizedBox(height: TpSpacing.s1),
          Text(pretripNote.content, style: theme.textTheme.bodyMedium),
        ],
      ],
    );
  }
}

class _EmergencyContactRow extends StatelessWidget {
  const _EmergencyContactRow(
    this.contact, {
    required this.onEdit,
    required this.onDelete,
  });

  final TripEmergencyContact contact;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  static const _kindLabels = {
    'personal': '個人',
    'embassy': '大使館',
    'police': '警察',
    'medical': '醫療',
    'insurance': '保險',
    'hotel': '飯店',
    'other': '其他',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tones = theme.extension<TpTones>()!;
    return _NoteRowCard(
      actions: [
        _RowActionButtons(
          editKey: 'notes-edit-emergency-${contact.id}',
          deleteKey: 'notes-delete-emergency-${contact.id}',
          onEdit: onEdit,
          onDelete: onDelete,
        ),
      ],
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                contact.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(fontSize: 15),
              ),
            ),
            const SizedBox(width: TpSpacing.s2),
            _KindChip(
              label: _kindLabels[contact.kind] ?? contact.kind,
              bg: tones.accentBg,
              fg: tones.accentDeep,
            ),
          ],
        ),
        if (contact.phone.isNotEmpty) ...[
          const SizedBox(height: TpSpacing.s1),
          _TimeText(contact.phone),
        ],
      ],
    );
  }
}
