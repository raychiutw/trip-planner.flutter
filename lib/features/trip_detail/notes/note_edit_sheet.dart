import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/api_error.dart';
import '../../../api/providers.dart';
import '../../../models/note_section.dart';
import '../../../theme/tokens.dart';
import '../trip_providers.dart';
import 'note_field_spec.dart';

/// 以 modal bottom sheet 開啟筆記新增/編輯表單。
/// create：rowId 為 null;edit：帶 initialFields(來自 row.toEditFields)+ rowId + version。
Future<void> showNoteEditSheet(
  BuildContext context, {
  required String tripId,
  required NoteSection section,
  Map<String, dynamic>? initialFields,
  int? rowId,
  int? version,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
      ),
      child: NoteEditSheet(
        tripId: tripId,
        section: section,
        initialFields: initialFields,
        rowId: rowId,
        version: version,
      ),
    ),
  );
}

/// spec-driven 筆記表單：依 noteSectionSpecs[section] 渲染欄位,5 區共用一個 widget。
class NoteEditSheet extends ConsumerStatefulWidget {
  const NoteEditSheet({
    super.key,
    required this.tripId,
    required this.section,
    this.initialFields,
    this.rowId,
    this.version,
  });

  final String tripId;
  final NoteSection section;
  final Map<String, dynamic>? initialFields;
  final int? rowId;
  final int? version;

  bool get isEdit => rowId != null;

  @override
  ConsumerState<NoteEditSheet> createState() => _NoteEditSheetState();
}

class _NoteEditSheetState extends ConsumerState<NoteEditSheet> {
  late final List<NoteFieldSpec> _specs;
  final Map<String, TextEditingController> _ctrls = {};
  final Map<String, String> _enums = {};
  final Map<String, String> _dts = {};
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _specs = noteSectionSpecs[widget.section]!;
    for (final spec in _specs) {
      final initial =
          widget.initialFields?[spec.key]?.toString() ?? spec.defaultValue;
      switch (spec.type) {
        case NoteFieldType.enumChoice:
          _enums[spec.key] = initial.isEmpty ? spec.defaultValue : initial;
        case NoteFieldType.datetime:
          _dts[spec.key] = initial;
        case NoteFieldType.text:
        case NoteFieldType.multiline:
        case NoteFieldType.integer:
          final controller = TextEditingController(text: initial);
          if (spec.required) controller.addListener(_onRequiredChanged);
          _ctrls[spec.key] = controller;
      }
    }
  }

  void _onRequiredChanged() => setState(() {});

  /// 各區主要識別欄位（required）需非空才可送出,避免建立全空 row。
  bool get _canSubmit {
    if (_submitting) return false;
    for (final spec in _specs) {
      if (spec.required && (_ctrls[spec.key]?.text.trim().isEmpty ?? true)) {
        return false;
      }
    }
    return true;
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  static String _pad2(int n) => n.toString().padLeft(2, '0');

  Future<void> _pickDateTime(String key) async {
    final current = DateTime.tryParse(_dts[key] ?? '');
    final date = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: current == null
          ? const TimeOfDay(hour: 9, minute: 0)
          : TimeOfDay(hour: current.hour, minute: current.minute),
    );
    if (time == null) return;
    setState(
      () => _dts[key] =
          '${date.year}-${_pad2(date.month)}-${_pad2(date.day)}T${_pad2(time.hour)}:${_pad2(time.minute)}',
    );
  }

  Map<String, dynamic> _collect() {
    final out = <String, dynamic>{};
    for (final spec in _specs) {
      switch (spec.type) {
        case NoteFieldType.integer:
          out[spec.key] = int.tryParse(_ctrls[spec.key]!.text.trim()) ?? 0;
        case NoteFieldType.text:
        case NoteFieldType.multiline:
          out[spec.key] = _ctrls[spec.key]!.text.trim();
        case NoteFieldType.enumChoice:
          out[spec.key] = _enums[spec.key]!;
        case NoteFieldType.datetime:
          out[spec.key] = _dts[spec.key]!;
      }
    }
    return out;
  }

  Future<void> _submit() async {
    final fields = _collect();
    setState(() => _submitting = true);
    final repo = ref.read(tripRepositoryProvider);
    try {
      if (widget.isEdit) {
        await repo.updateNote(
          widget.section,
          tripId: widget.tripId,
          rowId: widget.rowId!,
          fields: fields,
          expectedVersion: widget.version,
        );
      } else {
        await repo.createNote(
          widget.section,
          tripId: widget.tripId,
          fields: fields,
        );
      }
      ref.invalidate(tripNotesProvider(widget.tripId));
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(widget.isEdit ? '已儲存' : '已新增')));
    } on ApiError catch (error) {
      if (!mounted) return;
      if (error.status == 409) {
        ref.invalidate(tripNotesProvider(widget.tripId));
        Navigator.of(context).pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('此筆記已更新，請重新編輯')));
        return;
      }
      setState(() => _submitting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('儲存失敗，請稍後再試')));
    } on Exception {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('儲存失敗，請稍後再試')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = noteSectionTitles[widget.section] ?? '筆記';
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(TpSpacing.s4),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.isEdit ? '編輯$title' : '新增$title',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: TpSpacing.s4),
              for (final spec in _specs) ...[
                _field(spec),
                const SizedBox(height: TpSpacing.s3),
              ],
              const SizedBox(height: TpSpacing.s2),
              FilledButton(
                key: const ValueKey('note-edit-submit'),
                onPressed: _canSubmit ? _submit : null,
                child: Text(
                  _submitting ? '處理中…' : (widget.isEdit ? '儲存' : '新增'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(NoteFieldSpec spec) {
    switch (spec.type) {
      case NoteFieldType.text:
        return TextField(
          key: ValueKey('note-field-${spec.key}'),
          controller: _ctrls[spec.key],
          decoration: InputDecoration(
            labelText: spec.required ? '${spec.label} *' : spec.label,
          ),
        );
      case NoteFieldType.multiline:
        return TextField(
          key: ValueKey('note-field-${spec.key}'),
          controller: _ctrls[spec.key],
          decoration: InputDecoration(labelText: spec.label),
          maxLines: 3,
        );
      case NoteFieldType.integer:
        return TextField(
          key: ValueKey('note-field-${spec.key}'),
          controller: _ctrls[spec.key],
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(labelText: spec.label),
        );
      case NoteFieldType.enumChoice:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(spec.label, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: TpSpacing.s1),
            Wrap(
              spacing: TpSpacing.s2,
              children: [
                for (final (value, label) in spec.options)
                  ChoiceChip(
                    key: ValueKey('note-enum-${spec.key}-$value'),
                    label: Text(label),
                    selected: _enums[spec.key] == value,
                    onSelected: (_) => setState(() => _enums[spec.key] = value),
                  ),
              ],
            ),
          ],
        );
      case NoteFieldType.datetime:
        final value = _dts[spec.key] ?? '';
        return Row(
          children: [
            Expanded(
              child: OutlinedButton(
                key: ValueKey('note-datetime-${spec.key}'),
                onPressed: () => _pickDateTime(spec.key),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('${spec.label}　${value.isEmpty ? '未設定' : value}'),
                ),
              ),
            ),
            if (value.isNotEmpty)
              IconButton(
                key: ValueKey('note-datetime-clear-${spec.key}'),
                tooltip: '清除',
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => setState(() => _dts[spec.key] = ''),
              ),
          ],
        );
    }
  }
}
