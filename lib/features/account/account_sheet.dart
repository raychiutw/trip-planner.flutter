import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/adaptive.dart';
import 'account_screen.dart';
import 'account_sessions_screen.dart';
import 'connected_apps_screen.dart';
import 'developer_apps_screen.dart';
import 'settings/appearance_screen.dart';
import 'settings/notifications_screen.dart';
import 'settings/profile_edit_screen.dart';

/// 開啟帳號 Navigation Stack sheet，可停在根頁或舊版深連結指定的子頁。
Future<void> showAccountSheet(BuildContext context, {String? page}) async {
  await showAppContentSheet<void>(
    context,
    title: '帳號',
    builder: (_) => _AccountSheetContent(page: page),
  );
}

class _AccountSheetContent extends StatefulWidget {
  const _AccountSheetContent({this.page});

  final String? page;

  @override
  State<_AccountSheetContent> createState() => _AccountSheetContentState();
}

class _AccountSheetContentState extends State<_AccountSheetContent> {
  @override
  void initState() {
    super.initState();
    final page = _pageFor(widget.page);
    if (page == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        Navigator.of(
          context,
        ).push<void>(MaterialPageRoute<void>(builder: (_) => page)),
      );
    });
  }

  @override
  Widget build(BuildContext context) => const AccountScreen(embedded: true);

  Widget? _pageFor(String? page) => switch (page) {
    'appearance' => const AppearanceScreen(),
    'profile' => const ProfileEditScreen(),
    'notifications' => const NotificationsScreen(),
    'sessions' => const AccountSessionsScreen(),
    'connected-apps' => const ConnectedAppsScreen(),
    'developer-apps' => const DeveloperAppsScreen(),
    'developer-apps/new' => const DeveloperAppNewScreen(),
    _ => null,
  };
}
