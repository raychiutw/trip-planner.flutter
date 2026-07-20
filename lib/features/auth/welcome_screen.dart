import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../features/map/map_style.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, required this.onLogin});

  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tones = theme.extension<TpTones>()!;
    return Scaffold(
      key: const ValueKey('welcome-screen'),
      body: CustomScrollView(
        key: const ValueKey('welcome-scroll'),
        slivers: [
          SliverAppBar(
            pinned: true,
            automaticallyImplyLeading: false,
            toolbarHeight: 56,
            backgroundColor: theme.colorScheme.surface.withValues(alpha: 0.94),
            surfaceTintColor: Colors.transparent,
            scrolledUnderElevation: 0,
            titleSpacing: 18,
            title: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: 'Trip'),
                  TextSpan(
                    text: 'line',
                    style: TextStyle(color: tones.accentDeep),
                  ),
                ],
              ),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
            actions: [
              TextButton(
                key: const ValueKey('welcome-login-top'),
                onPressed: onLogin,
                style: TextButton.styleFrom(
                  foregroundColor: tones.accentDeep,
                  minimumSize: const Size(TpSpacing.tapMin, TpSpacing.tapMin),
                  padding: const EdgeInsets.symmetric(horizontal: TpSpacing.s4),
                ),
                child: const Text('登入'),
              ),
              const SizedBox(width: TpSpacing.s1),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Divider(
                height: 1,
                thickness: 1,
                color: theme.colorScheme.outlineVariant,
              ),
            ),
          ),
          SliverToBoxAdapter(child: _Hero(onLogin: onLogin)),
          const SliverToBoxAdapter(child: _Features()),
          SliverToBoxAdapter(child: _ClosingCallToAction(onLogin: onLogin)),
          const SliverToBoxAdapter(child: _Footer()),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.onLogin});

  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return _PageSection(
      mobilePadding: const EdgeInsets.fromLTRB(18, 36, 18, 12),
      desktopPadding: const EdgeInsets.fromLTRB(40, 72, 40, 24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 720;
          final copy = _HeroCopy(onLogin: onLogin);
          const art = _LandingArt(
            key: ValueKey('welcome-hero-art'),
            kind: _LandingArtKind.hero,
            semanticsLabel: '四個停留點由路線串起，並以一句話調整第二天下午的行程',
          );
          if (!wide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                copy,
                const SizedBox(height: TpSpacing.s7),
                art,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(flex: 11, child: copy),
              const SizedBox(width: 52),
              const Expanded(flex: 9, child: art),
            ],
          );
        },
      ),
    );
  }
}

class _HeroCopy extends StatelessWidget {
  const _HeroCopy({required this.onLogin});

  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tones = theme.extension<TpTones>()!;
    final width = MediaQuery.sizeOf(context).width;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '旅遊行程規劃',
          style: theme.textTheme.labelSmall?.copyWith(
            color: tones.accentDeep,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: TpSpacing.s3),
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: '行程排壞了，'),
              TextSpan(
                text: '講一句話就好',
                style: TextStyle(color: tones.accentDeep),
              ),
            ],
          ),
          key: const ValueKey('welcome-headline'),
          style: theme.textTheme.displaySmall?.copyWith(
            fontSize: width >= 760 ? 48 : 32,
            height: 1.2,
            fontWeight: FontWeight.w900,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: TpSpacing.s3),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Text(
            '「第二天下午排太趕」——說出來，行程自己調整，還會告訴你動了哪些點、車程差多少。不用一格一格拖。',
            style: theme.textTheme.bodyLarge?.copyWith(
              height: 1.65,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: TpSpacing.s6),
        _LoginButton(
          key: const ValueKey('welcome-login-hero'),
          onPressed: onLogin,
        ),
      ],
    );
  }
}

class _Features extends StatelessWidget {
  const _Features();

  static const _items = [
    (
      key: 'chat',
      kind: _LandingArtKind.chat,
      title: '說一句話就改好',
      body: '講「第三天太趕」，它會動點、重算車程，然後告訴你改了什麼。不用自己一格一格拖。',
      semantics: '一則使用者訊息與一則系統回覆',
    ),
    (
      key: 'map',
      kind: _LandingArtKind.map,
      title: '每天的路線一眼看完',
      body: '每日一色的路線圖，馬上看出哪天在繞路。可切一般圖或衛星圖。',
      semantics: '兩條不同顏色的每日路線',
    ),
    (
      key: 'health',
      kind: _LandingArtKind.health,
      title: '出發前先健檢',
      body: '時間排太緊、來回繞路、營業時間對不上——五個維度掃一遍，出發前就知道。',
      semantics: '三條健檢進度，其中一項需要注意',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _PageSection(
      mobilePadding: const EdgeInsets.fromLTRB(18, 44, 18, 20),
      desktopPadding: const EdgeInsets.fromLTRB(40, 72, 40, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '出發前你會反覆做的三件事',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: TpSpacing.s2),
          Text(
            '不是功能清單，是實際會發生的事。',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: TpSpacing.s6),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 720;
              final cards = [
                for (final item in _items)
                  _FeatureCard(
                    key: ValueKey('welcome-feature-${item.key}'),
                    kind: item.kind,
                    title: item.title,
                    body: item.body,
                    semanticsLabel: item.semantics,
                  ),
              ];
              if (!wide) {
                return Column(
                  children: [
                    for (var index = 0; index < cards.length; index++) ...[
                      cards[index],
                      if (index != cards.length - 1)
                        const SizedBox(height: TpSpacing.s4),
                    ],
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var index = 0; index < cards.length; index++) ...[
                    Expanded(child: cards[index]),
                    if (index != cards.length - 1)
                      const SizedBox(width: TpSpacing.s5),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    super.key,
    required this.kind,
    required this.title,
    required this.body,
    required this.semanticsLabel,
  });

  final _LandingArtKind kind;
  final String title;
  final String body;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(TpSpacing.s5),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(TpRadius.lg),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LandingArt(kind: kind, semanticsLabel: semanticsLabel),
          const SizedBox(height: TpSpacing.s4),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: TpSpacing.s2),
          Text(
            body,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.6,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ClosingCallToAction extends StatelessWidget {
  const _ClosingCallToAction({required this.onLogin});

  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _PageSection(
      mobilePadding: const EdgeInsets.fromLTRB(18, 24, 18, 44),
      desktopPadding: const EdgeInsets.fromLTRB(40, 40, 40, 64),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: TpSpacing.s6,
          vertical: TpSpacing.s8,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(TpRadius.xl),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Column(
          children: [
            Text(
              '行程還在 Google Docs 裡？',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: TpSpacing.s2),
            Text(
              '登入後就能開始排，也可以把既有行程用 JSON 匯入。',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: TpSpacing.s5),
            _LoginButton(
              key: const ValueKey('welcome-login-bottom'),
              onPressed: onLogin,
            ),
          ],
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, TpSpacing.s6, 18, TpSpacing.s8),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1160),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                '© 2026 Tripline',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginButton extends StatelessWidget {
  const _LoginButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(horizontal: 26),
        shape: const StadiumBorder(),
        textStyle: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
      child: const Text('登入後開始使用'),
    );
  }
}

class _PageSection extends StatelessWidget {
  const _PageSection({
    required this.mobilePadding,
    required this.desktopPadding,
    required this.child,
  });

  final EdgeInsets mobilePadding;
  final EdgeInsets desktopPadding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 761;
    return Padding(
      padding: wide ? desktopPadding : mobilePadding,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1160),
          child: child,
        ),
      ),
    );
  }
}

enum _LandingArtKind { hero, chat, map, health }

class _LandingArt extends StatelessWidget {
  const _LandingArt({
    super.key,
    required this.kind,
    required this.semanticsLabel,
  });

  final _LandingArtKind kind;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: semanticsLabel,
      child: ExcludeSemantics(
        child: AspectRatio(
          aspectRatio: kind == _LandingArtKind.hero ? 4 / 3 : 240 / 116,
          child: CustomPaint(
            painter: _LandingArtPainter(
              kind: kind,
              scheme: Theme.of(context).colorScheme,
              tones: Theme.of(context).extension<TpTones>()!,
            ),
          ),
        ),
      ),
    );
  }
}

class _LandingArtPainter extends CustomPainter {
  const _LandingArtPainter({
    required this.kind,
    required this.scheme,
    required this.tones,
  });

  final _LandingArtKind kind;
  final ColorScheme scheme;
  final TpTones tones;

  @override
  void paint(Canvas canvas, Size size) {
    switch (kind) {
      case _LandingArtKind.hero:
        _paintHero(canvas, size);
      case _LandingArtKind.chat:
        _paintChat(canvas, size);
      case _LandingArtKind.map:
        _paintMap(canvas, size);
      case _LandingArtKind.health:
        _paintHealth(canvas, size);
    }
  }

  void _paintHero(Canvas canvas, Size size) {
    final sx = size.width / 440;
    final sy = size.height / 330;
    canvas.save();
    canvas.scale(sx, sy);

    final route = Path()
      ..moveTo(46, 282)
      ..cubicTo(104, 282, 100, 214, 158, 210)
      ..cubicTo(214, 206, 232, 150, 288, 142)
      ..cubicTo(344, 134, 366, 82, 400, 66);
    _drawDashedPath(
      canvas,
      route,
      Paint()
        ..color = tones.accent.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 2.5,
    );

    final stops = [
      (const Offset(46, 282), dayPinColor(1), '1'),
      (const Offset(158, 210), dayPinColor(2), '2'),
      (const Offset(288, 142), dayPinColor(3), '3'),
      (const Offset(400, 66), dayPinColor(4), '4'),
    ];
    for (final (point, color, label) in stops) {
      canvas.drawCircle(point, 15, Paint()..color = color);
      _drawText(canvas, label, point, Colors.white, 13, FontWeight.w800);
    }

    final bubble = RRect.fromRectAndRadius(
      const Rect.fromLTWH(70, 24, 238, 62),
      const Radius.circular(20),
    );
    canvas.drawRRect(bubble, Paint()..color = tones.accentDeep);
    canvas.drawPath(
      Path()
        ..moveTo(96, 86)
        ..lineTo(110, 86)
        ..lineTo(96, 102)
        ..close(),
      Paint()..color = tones.accentDeep,
    );
    _drawText(
      canvas,
      '第二天下午\n排鬆一點',
      const Offset(92, 44),
      scheme.surface,
      15,
      FontWeight.w700,
      alignCenter: false,
      lineHeight: 1.45,
    );

    canvas.drawCircle(
      const Offset(222, 188),
      11,
      Paint()
        ..color = scheme.onSurfaceVariant.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final movePaint = Paint()
      ..color = scheme.onSurfaceVariant.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawLine(const Offset(232, 182), const Offset(272, 152), movePaint);
    canvas.drawPath(
      Path()
        ..moveTo(272, 152)
        ..lineTo(263, 153)
        ..lineTo(267, 159)
        ..close(),
      Paint()..color = movePaint.color,
    );
    canvas.restore();
  }

  void _paintChat(Canvas canvas, Size size) {
    final scale = size.width / 240;
    canvas.save();
    canvas.scale(scale, size.height / 116);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(12, 16, 132, 34),
        const Radius.circular(17),
      ),
      Paint()..color = scheme.surfaceContainerHighest,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(28, 29, 88, 8),
        const Radius.circular(4),
      ),
      Paint()..color = scheme.onSurfaceVariant.withValues(alpha: 0.45),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(96, 66, 132, 34),
        const Radius.circular(17),
      ),
      Paint()..color = tones.accentDeep,
    );
    for (final rect in const [
      Rect.fromLTWH(112, 79, 72, 8),
      Rect.fromLTWH(190, 79, 22, 8),
    ]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        Paint()..color = scheme.surface.withValues(alpha: 0.8),
      );
    }
    canvas.restore();
  }

  void _paintMap(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 240, size.height / 116);
    final routes = [
      (
        Path()
          ..moveTo(18, 94)
          ..cubicTo(62, 94, 58, 52, 102, 50)
          ..cubicTo(146, 48, 168, 26, 224, 32),
        dayPinColor(2),
      ),
      (
        Path()
          ..moveTo(18, 102)
          ..cubicTo(74, 102, 74, 74, 130, 74)
          ..cubicTo(186, 74, 194, 62, 224, 66),
        dayPinColor(3).withValues(alpha: 0.75),
      ),
    ];
    for (final (path, color) in routes) {
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5
          ..strokeCap = StrokeCap.round,
      );
    }
    for (final point in const [
      Offset(18, 94),
      Offset(102, 50),
      Offset(224, 32),
    ]) {
      canvas.drawCircle(point, 7, Paint()..color = dayPinColor(2));
    }
    canvas.drawCircle(
      const Offset(130, 74),
      6,
      Paint()..color = dayPinColor(3).withValues(alpha: 0.75),
    );
    canvas.restore();
  }

  void _paintHealth(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 240, size.height / 116);
    const rows = [
      (24.0, 150.0, true),
      (51.0, 78.0, false),
      (78.0, 176.0, true),
    ];
    for (final (top, value, healthy) in rows) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(24, top, 192, 14),
          const Radius.circular(7),
        ),
        Paint()..color = scheme.surfaceContainerHighest,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(24, top, value, 14),
          const Radius.circular(7),
        ),
        Paint()
          ..color = healthy
              ? tones.success
              : scheme.error.withValues(alpha: 0.8),
      );
    }
    canvas.restore();
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = math.min(distance + 8, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += 16;
      }
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset point,
    Color color,
    double fontSize,
    FontWeight weight, {
    bool alignCenter = true,
    double lineHeight = 1,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: weight,
          height: lineHeight,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      alignCenter
          ? point - Offset(painter.width / 2, painter.height / 2)
          : point,
    );
  }

  @override
  bool shouldRepaint(covariant _LandingArtPainter oldDelegate) {
    return oldDelegate.kind != kind ||
        oldDelegate.scheme != scheme ||
        oldDelegate.tones != tones;
  }
}
