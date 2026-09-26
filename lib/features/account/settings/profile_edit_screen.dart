/// 個人資料編輯:改 display_name → PATCH /account/profile → invalidate authState → pop。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/providers.dart';
import '../../../app/adaptive.dart';
import '../../../app/app_loading_skeleton.dart';
import '../../../app/draft_session.dart';
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
  DraftSession<String, void>? _session;

  @override
  void dispose() {
    _session?.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final session = _session;
    if (session == null) return;
    final saved = await session.submit();
    if (!mounted || saved == null) return;
    HapticFeedback.lightImpact();
    showAppNotice(context, session.dirty ? '已儲存先前的名稱，目前修改尚未儲存' : '已更新個人資料');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !session.canFinish(saved)) return;
      final navigator = Navigator.of(context);
      if (navigator.canPop()) navigator.pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    return AppUnsavedChangesGuard(
      controller: _dismissController,
      hasChanges: _session?.dirty ?? false,
      dismissalEnabled: !(_session?.submitting ?? false),
      child: Scaffold(
        appBar: TpAppBar(
          role: TpAppBarRole.modalForm,
          title: const Text('個人資料'),
          onCancel: _dismissController.requestPop,
          primaryActionLabel: '儲存',
          primaryActionKey: const ValueKey('profile-save'),
          primaryActionEnabled: _session?.canSubmit ?? false,
          onPrimaryAction: _save,
        ),
        body: authState.when(
          data: (user) => _form(context, user?.displayName ?? ''),
          error: (_, _) => _session == null
              ? Center(child: _loadError())
              : _form(context, _session!.draft, loadFailed: true),
          loading: () => _session == null
              ? const AppListLoadingSkeleton(
                  key: ValueKey('profile-edit-loading'),
                  itemCount: 2,
                )
              : _form(context, _session!.draft),
        ),
      ),
    );
  }

  Widget _loadError() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Semantics(liveRegion: true, child: const Text('無法載入個人資料')),
      TextButton(
        onPressed: () => ref.invalidate(authStateProvider),
        child: const Text('重試'),
      ),
    ],
  );

  Widget _form(
    BuildContext context,
    String currentName, {
    bool loadFailed = false,
  }) {
    final session = _session ??=
        DraftSession<String, void>(
          initial: currentName,
          equivalent: (a, b) => a.trim() == b.trim(),
          write: (snapshot) async {
            final name = snapshot.draft.trim();
            await ref
                .read(authStateProvider.notifier)
                .updateProfile(displayName: name);
            return DraftAccepted(draft: name, result: null);
          },
        )..addListener(() {
          if (mounted) setState(() {});
        });
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        if (loadFailed) _loadError(),
        if (session.submitting)
          Semantics(
            liveRegion: true,
            child: const Padding(
              padding: EdgeInsets.all(TpSpacing.s4),
              child: Text('儲存中…'),
            ),
          ),
        TpSettingsGroup(
          key: const ValueKey('profile-fields'),
          title: '個人資料',
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: TpSpacing.s4,
                vertical: TpSpacing.s2,
              ),
              child: TextFormField(
                key: const ValueKey('profile-display-name'),
                initialValue: session.draft,
                autofocus: true,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: '顯示名稱',
                  border: InputBorder.none,
                ),
                onChanged: session.edit,
                onFieldSubmitted: (_) {
                  _save();
                },
              ),
            ),
          ],
        ),
        if (session.error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: TpSpacing.s4),
            child: Semantics(
              liveRegion: true,
              child: Text(
                session.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ),
      ],
    );
  }
}
