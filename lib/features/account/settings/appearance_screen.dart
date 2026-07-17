/// 外觀設定:主題模式三選一(跟隨系統/淺色/深色)。
library;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../ui/tp_app_bar.dart';
import '../../../ui/tp_settings_group.dart';

import 'theme_mode_controller.dart';

class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});

  static const _options = [
    (ThemeMode.system, '跟隨系統'),
    (ThemeMode.light, '淺色'),
    (ThemeMode.dark, '深色'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return Scaffold(
      appBar: const TpAppBar(title: Text('外觀')),
      body: ListView(
        children: [
          TpSettingsGroup(
            children: [
              for (final (m, label) in _options)
                ListTile(
                  key: ValueKey('theme-${themeModeToString(m)}'),
                  title: Text(label),
                  trailing: mode == m
                      ? const Icon(CupertinoIcons.checkmark)
                      : null,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    ref.read(themeModeProvider.notifier).setMode(m);
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}
