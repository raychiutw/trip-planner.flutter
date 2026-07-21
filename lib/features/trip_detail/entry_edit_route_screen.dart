import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/adaptive.dart';
import '../../app/app_loading_skeleton.dart';
import '../../theme/tokens.dart';
import '../../ui/tp_app_bar.dart';
import 'trip_providers.dart';
import 'widgets/entry_edit_sheet.dart';

/// Web 相容的停留點編輯頁，包裝既有 EntryEditSheet 表單。
class EntryEditRouteScreen extends ConsumerStatefulWidget {
  const EntryEditRouteScreen({
    super.key,
    required this.tripId,
    required this.entryId,
  });

  final String tripId;
  final int entryId;

  @override
  ConsumerState<EntryEditRouteScreen> createState() =>
      _EntryEditRouteScreenState();
}

class _EntryEditRouteScreenState extends ConsumerState<EntryEditRouteScreen> {
  final _dismissController = AppUnsavedChangesController();
  final _formController = AppSheetFormController();

  @override
  void dispose() {
    _formController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!await _formController.submit() || !mounted) return;
    _formController.update(dirty: false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/trips/${Uri.encodeComponent(widget.tripId)}');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final entryAsync = ref.watch(
      entryDetailProvider((tripId: widget.tripId, entryId: widget.entryId)),
    );
    return AnimatedBuilder(
      animation: _formController,
      builder: (context, _) => AppUnsavedChangesGuard(
        controller: _dismissController,
        hasChanges: _formController.isDirty,
        dismissalEnabled: !_formController.isSubmitting,
        child: Scaffold(
          appBar: TpAppBar(
            role: TpAppBarRole.modalForm,
            title: const Text('編輯停留點'),
            onCancel: _dismissController.requestPop,
            primaryActionLabel: '儲存',
            primaryActionKey: const ValueKey('entry-edit-submit'),
            primaryActionEnabled: _formController.canSubmit,
            onPrimaryAction: () => unawaited(_save()),
          ),
          body: entryAsync.when(
            loading: () => const AppListLoadingSkeleton(
              key: ValueKey('entry-edit-loading'),
              itemCount: 3,
            ),
            error: (error, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(TpSpacing.s6),
                child: Text('載入失敗：$error', textAlign: TextAlign.center),
              ),
            ),
            data: (entry) => EntryEditSheet(
              tripId: widget.tripId,
              args: EntryEditExisting(entry),
              formController: _formController,
            ),
          ),
        ),
      ),
    );
  }
}
