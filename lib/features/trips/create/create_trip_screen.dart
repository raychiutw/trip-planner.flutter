/// 建立行程:目的地優先(POI 搜尋 + 熱門 chips + 拖曳)→ 日期模式(固定/彈性)
/// → 每地天數(≥2 目的地)→ 想做什麼(description)→ 送出。
library;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/adaptive.dart';
import '../../../app/adaptive_content.dart';
import '../../../theme/tokens.dart';
import '../../../ui/tp_app_bar.dart';
import '../../account/ai_authorize_card.dart';
import '../trips_list_screen.dart';
import '../widgets/destination_picker.dart';
import 'create_trip_controller.dart';

class CreateTripScreen extends ConsumerStatefulWidget {
  const CreateTripScreen({super.key});

  @override
  ConsumerState<CreateTripScreen> createState() => _CreateTripScreenState();
}

class _CreateTripScreenState extends ConsumerState<CreateTripScreen> {
  final _desc = TextEditingController();
  final _dismissController = AppUnsavedChangesController();

  @override
  void dispose() {
    _desc.dispose();
    super.dispose();
  }

  CreateTripController get _ctrl =>
      ref.read(createTripControllerProvider.notifier);

  Future<void> _submit() async {
    final id = await _ctrl.submit();
    if (id != null && mounted) {
      HapticFeedback.lightImpact();
      ref.invalidate(myTripsProvider);
      context.go('/trips/$id');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(createTripControllerProvider);
    final basicsReady = state.destinations.isNotEmpty && state.totalDays > 0;

    return AppUnsavedChangesGuard(
      controller: _dismissController,
      hasChanges: _ctrl.hasChanges,
      dismissalEnabled: !state.submitting,
      child: Scaffold(
        appBar: TpAppBar(
          role: TpAppBarRole.modalForm,
          title: const Text('建立行程'),
          onCancel: _dismissController.requestPop,
          primaryActionLabel: '建立',
          primaryActionKey: const ValueKey('create-submit'),
          primaryActionEnabled: state.canSubmit,
          onPrimaryAction: _submit,
        ),
        body: AppAdaptiveContent(
          maxWidth: AppContentWidth.form,
          contentKey: const ValueKey('create-trip-content'),
          child: ListView(
            padding: const EdgeInsets.all(TpSpacing.s4),
            children: [
              _sectionTitle(context, '目的地'),
              DestinationPicker(
                destinations: state.destinations,
                onAdd: _ctrl.addDestination,
                onRemove: _ctrl.removeDestination,
                onReorder: _ctrl.reorderDestination,
              ),
              const SizedBox(height: TpSpacing.s5),
              _sectionTitle(context, '日期'),
              _DateModeSection(state: state, ctrl: _ctrl),
              if (state.destinations.length >= 2) ...[
                const SizedBox(height: TpSpacing.s5),
                _sectionTitle(context, '每地天數（共 ${state.totalDays} 天）'),
                _DayQuotaSection(state: state, ctrl: _ctrl),
              ],
              if (!basicsReady) ...[
                const SizedBox(height: TpSpacing.s4),
                Text(
                  '先選好目的地與日期，接著可補充偏好並設定 AI。',
                  key: const ValueKey('create-next-step-hint'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (basicsReady) ...[
                const SizedBox(height: TpSpacing.s5),
                ExpansionTile(
                  key: const ValueKey('create-more-needs'),
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: TpSpacing.s2),
                  title: Text(
                    '更多需求（選填）',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  subtitle: const Text('餐飲、購物或旅行節奏等偏好'),
                  children: [
                    TextField(
                      key: const ValueKey('create-desc'),
                      controller: _desc,
                      minLines: 2,
                      maxLines: 5,
                      maxLength: 2000,
                      decoration: const InputDecoration(
                        hintText: '例如：想吃道地拉麵、逛二手書店…',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: _ctrl.setDescription,
                    ),
                  ],
                ),
                const SizedBox(height: TpSpacing.s3),
                const AiAuthorizeCard(),
              ],
              if (state.error != null) ...[
                const SizedBox(height: TpSpacing.s3),
                Text(
                  state.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: TpSpacing.s4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String t) => Padding(
    padding: const EdgeInsets.only(bottom: TpSpacing.s2),
    child: Text(t, style: Theme.of(context).textTheme.titleMedium),
  );
}

class _DateModeSection extends StatelessWidget {
  const _DateModeSection({required this.state, required this.ctrl});

  final CreateTripState state;
  final CreateTripController ctrl;

  String _ymd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickFixed(BuildContext context, {required bool isStart}) async {
    final now = DateTime.now();
    final first = isStart
        ? now
        : (state.fixedStart != null ? DateTime.parse(state.fixedStart!) : now);
    final picked = await showDatePicker(
      context: context,
      initialDate: first,
      firstDate: first,
      lastDate: now.add(const Duration(days: 730)),
    );
    if (picked == null) return;
    if (isStart) {
      ctrl.setFixedStart(_ymd(picked));
    } else {
      ctrl.setFixedEnd(_ymd(picked));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<TripDateMode>(
          segments: const [
            ButtonSegment(value: TripDateMode.fixed, label: Text('固定日期')),
            ButtonSegment(value: TripDateMode.flexible, label: Text('大概時間')),
          ],
          selected: {state.dateMode},
          onSelectionChanged: (s) => ctrl.setDateMode(s.first),
        ),
        const SizedBox(height: TpSpacing.s3),
        if (state.dateMode == TripDateMode.fixed)
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const ValueKey('create-date-start'),
                  onPressed: () => _pickFixed(context, isStart: true),
                  child: Text(state.fixedStart ?? '開始日期'),
                ),
              ),
              const SizedBox(width: TpSpacing.s2),
              Expanded(
                child: OutlinedButton(
                  key: const ValueKey('create-date-end'),
                  onPressed: () => _pickFixed(context, isStart: false),
                  child: Text(state.fixedEnd ?? '結束日期'),
                ),
              ),
            ],
          )
        else
          _FlexibleDate(state: state, ctrl: ctrl),
      ],
    );
  }
}

class _FlexibleDate extends StatelessWidget {
  const _FlexibleDate({required this.state, required this.ctrl});

  final CreateTripState state;
  final CreateTripController ctrl;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final months = [
      for (var i = 0; i < 6; i++) DateTime(now.year, now.month + i),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('天數'),
            const Spacer(),
            IconButton(
              key: const ValueKey('create-flex-minus'),
              onPressed: () => ctrl.setFlexDayCount(state.flexDayCount - 1),
              icon: const Icon(CupertinoIcons.minus_circle),
            ),
            Text(
              '${state.flexDayCount}',
              key: const ValueKey('create-flex-count'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            IconButton(
              key: const ValueKey('create-flex-plus'),
              onPressed: () => ctrl.setFlexDayCount(state.flexDayCount + 1),
              icon: const Icon(CupertinoIcons.add_circled),
            ),
          ],
        ),
        Wrap(
          spacing: TpSpacing.s2,
          children: [
            for (final m in months)
              ChoiceChip(
                label: Text('${m.year}/${m.month}'),
                selected:
                    state.flexYear == m.year && state.flexMonth == m.month,
                onSelected: (_) => ctrl.setFlexMonth(m.year, m.month),
              ),
          ],
        ),
      ],
    );
  }
}

class _DayQuotaSection extends StatelessWidget {
  const _DayQuotaSection({required this.state, required this.ctrl});

  final CreateTripState state;
  final CreateTripController ctrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < state.destinations.length; i++)
          Row(
            children: [
              Expanded(child: Text(state.destinations[i].name)),
              IconButton(
                onPressed: () =>
                    ctrl.setQuota(i, (state.destinations[i].dayQuota ?? 1) - 1),
                icon: const Icon(CupertinoIcons.minus_circle),
              ),
              Text('${state.destinations[i].dayQuota ?? 1}'),
              IconButton(
                onPressed: () =>
                    ctrl.setQuota(i, (state.destinations[i].dayQuota ?? 1) + 1),
                icon: const Icon(CupertinoIcons.add_circled),
              ),
            ],
          ),
      ],
    );
  }
}
