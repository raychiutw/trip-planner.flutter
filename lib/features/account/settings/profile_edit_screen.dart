/// 個人資料編輯:改 display_name → PATCH /account/profile → invalidate authState → pop。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../api/providers.dart';
import '../../../app/app_loading_skeleton.dart';
import '../../../theme/tokens.dart';

class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  String? _draft; // 首次有 user 資料時 seed
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(tripRepositoryProvider)
          .updateProfile(displayName: (_draft ?? '').trim());
      ref.invalidate(authStateProvider);
      HapticFeedback.lightImpact();
      if (mounted && context.canPop()) context.pop();
    } on Exception {
      if (mounted) setState(() => _error = '儲存失敗,請稍後再試');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('個人資料')),
      body: switch (authState) {
        AsyncData(:final value?) => _form(context, value.displayName ?? ''),
        AsyncError() => const Center(child: Text('無法載入個人資料')),
        _ => const AppListLoadingSkeleton(
          key: ValueKey('profile-edit-loading'),
          itemCount: 2,
        ),
      },
    );
  }

  Widget _form(BuildContext context, String currentName) {
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
          onChanged: (v) => _draft = v,
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
        FilledButton(
          key: const ValueKey('profile-save'),
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                )
              : const Text('儲存'),
        ),
      ],
    );
  }
}
