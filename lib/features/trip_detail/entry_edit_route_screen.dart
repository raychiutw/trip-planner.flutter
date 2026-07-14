import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_loading_skeleton.dart';
import '../../theme/tokens.dart';
import 'trip_providers.dart';
import 'widgets/entry_edit_sheet.dart';

/// Web 相容的停留點編輯頁，包裝既有 EntryEditSheet 表單。
class EntryEditRouteScreen extends ConsumerWidget {
  const EntryEditRouteScreen({
    super.key,
    required this.tripId,
    required this.entryId,
  });

  final String tripId;
  final int entryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entryAsync = ref.watch(
      entryDetailProvider((tripId: tripId, entryId: entryId)),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('編輯停留點')),
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
        data: (entry) => SingleChildScrollView(
          child: EntryEditSheet(tripId: tripId, args: EntryEditExisting(entry)),
        ),
      ),
    );
  }
}
