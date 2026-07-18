import 'package:flutter/material.dart';

import 'map_adapter.dart';

Widget buildPlatformTripMapCanvas(TripMapCanvasConfig config) =>
    _TripMapWebFallback(config: config);

class _TripMapWebFallback extends StatefulWidget {
  const _TripMapWebFallback({required this.config});

  final TripMapCanvasConfig config;

  @override
  State<_TripMapWebFallback> createState() => _TripMapWebFallbackState();
}

class _TripMapWebFallbackState extends State<_TripMapWebFallback> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.config.onMapReady?.call();
    });
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    key: widget.config.mapKey,
    color: Theme.of(context).colorScheme.surfaceContainerLow,
    child: const Center(child: Text('請使用 Google 地圖查看完整地圖')),
  );
}
