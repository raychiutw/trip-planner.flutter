/// App 外觀設定：跟隨系統、淺色與深色三選一。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/adaptive_content.dart';
import '../../../ui/tp_app_bar.dart';
import '../../../ui/tp_settings_group.dart';
import 'theme_mode_controller.dart';

String themeModeLabel(ThemeMode mode) => switch (mode) {
  ThemeMode.system => '跟隨系統',
  ThemeMode.light => '淺色',
  ThemeMode.dark => '深色',
};

class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});

  static const _modes = [ThemeMode.system, ThemeMode.light, ThemeMode.dark];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedMode = ref.watch(themeModeProvider);
    return Scaffold(
      key: const ValueKey('appearance-page'),
      appBar: const TpAppBar(role: TpAppBarRole.detail, title: Text('外觀')),
      body: AppAdaptiveContent(
        maxWidth: AppContentWidth.form,
        child: ListView(
          children: [
            TpSettingsGroup(
              title: 'App 外觀',
              children: [
                for (final mode in _modes)
                  TpSettingsRow(
                    key: ValueKey('theme-${mode.name}'),
                    title: themeModeLabel(mode),
                    selected: selectedMode == mode,
                    inMutuallyExclusiveGroup: true,
                    onTap: () => unawaited(
                      ref.read(themeModeProvider.notifier).setMode(mode),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
