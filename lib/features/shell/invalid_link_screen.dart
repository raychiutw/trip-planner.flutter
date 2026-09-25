/// 無效深連結的回復畫面，不顯示內部路由錯誤或請求無效資料。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme/tokens.dart';
import '../../ui/tp_app_bar.dart';

class InvalidLinkScreen extends ConsumerWidget {
  const InvalidLinkScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: const TpAppBar(
      role: TpAppBarRole.standalone,
      title: Text('無法開啟連結'),
    ),
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(TpSpacing.s6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                liveRegion: true,
                child: const Text(
                  '連結不完整或格式不正確，請重新確認連結。',
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: TpSpacing.s4),
              TextButton(
                onPressed: () => context.go('/trips'),
                child: const Text('返回行程列表'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
