/// 外觀設定:主題模式三選一(跟隨系統/淺色/深色)。
library;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      appBar: AppBar(title: const Text('外觀')),
      body: ListView(
        children: [
          for (final (m, label) in _options)
            Semantics(
              key: ValueKey('theme-${themeModeToString(m)}-semantics'),
              label: label,
              button: true,
              selected: mode == m,
              onTap: () {
                HapticFeedback.selectionClick();
                ref.read(themeModeProvider.notifier).setMode(m);
              },
              child: ExcludeSemantics(
                child: ListTile(
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
              ),
            ),
        ],
      ),
    );
  }
}
