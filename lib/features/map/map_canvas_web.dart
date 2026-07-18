import 'package:flutter/material.dart';

import 'google_maps_external_launcher.dart';
import 'map_adapter.dart';

Widget buildPlatformTripMapCanvas(TripMapCanvasConfig config) =>
    TripMapWebFallback(config: config);

class TripMapWebFallback extends StatefulWidget {
  const TripMapWebFallback({
    super.key,
    required this.config,
    this.launcher = const GoogleMapsExternalLauncher(),
  });

  final TripMapCanvasConfig config;
  final GoogleMapsExternalLauncher launcher;

  @override
  State<TripMapWebFallback> createState() => _TripMapWebFallbackState();
}

class _TripMapWebFallbackState extends State<TripMapWebFallback> {
  bool _opening = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.config.onMapReady?.call();
    });
  }

  Future<void> _open() async {
    final point =
        widget.config.initialCenter ??
        widget.config.initialFitPoints.firstOrNull ??
        const TripMapPoint(25.033, 121.5654);
    setState(() {
      _opening = true;
      _failed = false;
    });
    try {
      final opened = await widget.launcher.open(
        GoogleMapPoiSelection(placeId: '', name: '', point: point),
      );
      if (!opened && mounted) setState(() => _failed = true);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    key: widget.config.mapKey,
    color: Theme.of(context).colorScheme.surfaceContainerLow,
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('請使用 Google 地圖查看完整地圖'),
          TextButton.icon(
            style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
            onPressed: _opening ? null : _open,
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text('在 Google 地圖開啟'),
          ),
          if (_failed)
            Text(
              '無法開啟 Google 地圖，請稍後再試',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    ),
  );
}
