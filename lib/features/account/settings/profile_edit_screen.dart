/// 個人資料編輯:改 display_name → PATCH /account/profile → invalidate authState → pop。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../api/providers.dart';
import '../../../app/adaptive.dart';
import '../../../app/app_loading_skeleton.dart';
import '../../../theme/tokens.dart';
import '../../../ui/tp_app_bar.dart';
import '../../../ui/tp_settings_group.dart';

class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final _dismissController = AppUnsavedChangesController();
  String? _draft; // 首次有 user 資料時 seed
  String? _initialName;
  bool _saving = false;
  String? _error;

  bool get _hasChanges =>
      _initialName != null && (_draft ?? '').trim() != _initialName!.trim();

  Future<void> _save() async {
    final savedName = (_draft ?? '').trim();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(accountRepositoryProvider)
          .updateProfile(displayName: savedName);
      ref.invalidate(authStateProvider);
      HapticFeedback.lightImpact();
      if (mounted) {
        setState(() {
          _initialName = savedName;
          _draft = savedName;
          _saving = false;
        });
        showAppNotice(context, '已更新個人資料');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && context.canPop()) context.pop();
        });
      }
    } on Exception {
      if (mounted) setState(() => _error = '儲存失敗,請稍後再試');
    } finally {
      if (mounted && _saving) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    return AppUnsavedChangesGuard(
      controller: _dismissController,
      hasChanges: _hasChanges,
      dismissalEnabled: !_saving,
      child: Scaffold(
        appBar: TpAppBar(
          role: TpAppBarRole.modalForm,
          title: const Text('個人資料'),
          onCancel: _dismissController.requestPop,
          primaryActionLabel: '儲存',
          primaryActionKey: const ValueKey('profile-save'),
          primaryActionEnabled: _hasChanges && !_saving,
          onPrimaryAction: _save,
        ),
        body: switch (authState) {
          AsyncData(:final value?) => _form(context, value.displayName ?? ''),
          AsyncError() => const Center(child: Text('無法載入個人資料')),
          _ => const AppListLoadingSkeleton(
            key: ValueKey('profile-edit-loading'),
            itemCount: 2,
          ),
        },
      ),
    );
  }

  Widget _form(BuildContext context, String currentName) {
    _initialName ??= currentName;
    _draft ??= currentName;
    return ListView(
      children: [
        TpSettingsGroup(
          title: '個人資料',
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: TpSpacing.s4,
                vertical: TpSpacing.s2,
              ),
              child: TextFormField(
                key: const ValueKey('profile-display-name'),
                initialValue: _draft,
                autofocus: true,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: '顯示名稱',
                  border: InputBorder.none,
                ),
                onChanged: (value) => setState(() => _draft = value),
                onFieldSubmitted: (_) {
                  if (_hasChanges && !_saving) _save();
                },
              ),
            ),
          ],
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: TpSpacing.s4),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    );
  }
}
