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
          .read(tripRepositoryProvider)
          .updateProfile(displayName: savedName);
      ref.invalidate(authStateProvider);
      HapticFeedback.lightImpact();
      if (mounted) {
        setState(() {
          _initialName = savedName;
          _draft = savedName;
          _saving = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已更新個人資料')));
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
      padding: const EdgeInsets.all(TpSpacing.s4),
      children: [
        TextFormField(
          key: const ValueKey('profile-display-name'),
          initialValue: _draft,
          decoration: const InputDecoration(
            labelText: '顯示名稱',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) => setState(() => _draft = value),
        ),
        const SizedBox(height: TpSpacing.s4),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: TpSpacing.s2),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        const SizedBox(height: TpSpacing.s2),
      ],
    );
  }
}
