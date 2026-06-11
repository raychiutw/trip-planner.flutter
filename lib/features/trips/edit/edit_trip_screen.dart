/// 編輯行程:目的地(可加/排序/移除)+ 標題 + 描述 + 語言 + 發布 + 明確儲存。
/// 不含日期/天數(日管理另案)。儲存成功 → pop。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/tokens.dart';
import '../widgets/destination_picker.dart';
import 'edit_trip_controller.dart';

const _langs = {'zh-TW': '繁體中文', 'en': 'English', 'ja': '日本語'};

class EditTripScreen extends ConsumerWidget {
  const EditTripScreen({super.key, required this.tripId});

  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(editTripControllerProvider(tripId));
    final ctrl = ref.read(editTripControllerProvider(tripId).notifier);

    // 儲存成功 → 返回。
    ref.listen(editTripControllerProvider(tripId), (prev, next) {
      if (next.saved && !(prev?.saved ?? false) && context.canPop()) {
        context.pop();
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('編輯行程')),
      body: state.loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(TpSpacing.s4),
                    children: [
                      _title(context, '目的地'),
                      DestinationPicker(
                        destinations: state.destinations,
                        onAdd: ctrl.addDestination,
                        onRemove: ctrl.removeDestination,
                        onReorder: ctrl.reorderDestination,
                      ),
                      const SizedBox(height: TpSpacing.s5),
                      _title(context, '行程標題'),
                      TextFormField(
                        key: const ValueKey('edit-title'),
                        initialValue: state.title,
                        decoration: const InputDecoration(
                          hintText: '例如:2026 沖繩自駕',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: ctrl.setTitle,
                      ),
                      const SizedBox(height: TpSpacing.s4),
                      _title(context, '描述（用於 SEO,選填）'),
                      TextFormField(
                        key: const ValueKey('edit-desc'),
                        initialValue: state.description,
                        minLines: 2,
                        maxLines: 5,
                        maxLength: 2000,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                        ),
                        onChanged: ctrl.setDescription,
                      ),
                      const SizedBox(height: TpSpacing.s4),
                      DropdownButtonFormField<String>(
                        key: const ValueKey('edit-lang'),
                        initialValue: state.lang,
                        decoration: const InputDecoration(
                          labelText: '顯示語言',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          for (final e in _langs.entries)
                            DropdownMenuItem(
                              value: e.key,
                              child: Text(e.value),
                            ),
                        ],
                        onChanged: (v) {
                          if (v != null) ctrl.setLang(v);
                        },
                      ),
                      const SizedBox(height: TpSpacing.s2),
                      SwitchListTile(
                        key: const ValueKey('edit-published'),
                        title: const Text('發布（公開上線）'),
                        contentPadding: EdgeInsets.zero,
                        value: state.published,
                        onChanged: ctrl.setPublished,
                      ),
                    ],
                  ),
                ),
                _SaveBar(
                  error: state.error,
                  saving: state.saving,
                  onSave: () => ctrl.save(),
                ),
              ],
            ),
    );
  }

  Widget _title(BuildContext context, String t) => Padding(
    padding: const EdgeInsets.only(bottom: TpSpacing.s2),
    child: Text(t, style: Theme.of(context).textTheme.titleMedium),
  );
}

class _SaveBar extends StatelessWidget {
  const _SaveBar({
    required this.error,
    required this.saving,
    required this.onSave,
  });

  final String? error;
  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          TpSpacing.s4,
          TpSpacing.s2,
          TpSpacing.s4,
          TpSpacing.s2,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: TpSpacing.s2),
                child: Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const ValueKey('edit-save'),
                onPressed: saving ? null : onSave,
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('儲存'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
