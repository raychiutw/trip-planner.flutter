/// 個人資料編輯:改 display_name → PATCH /account/profile → invalidate authState → pop。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../api/providers.dart';
import '../../../theme/tokens.dart';

class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  String? _draft; // 首次有 user 資料時 seed
  String? _initialName;
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
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已更新個人資料')));
        if (context.canPop()) context.pop();
      }
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
        _ => const Center(child: CircularProgressIndicator.adaptive()),
      },
    );
  }

  Widget _form(BuildContext context, String currentName) {
    _initialName ??= currentName;
    _draft ??= currentName;
    final hasChanges = _draft!.trim() != _initialName!.trim();
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
        FilledButton(
          key: const ValueKey('profile-save'),
          onPressed: _saving || !hasChanges ? null : _save,
          child: _saving
              ? const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                    ),
                    SizedBox(width: TpSpacing.s2),
                    Text('儲存'),
                  ],
                )
              : const Text('儲存'),
        ),
      ],
    );
  }
}
