import 'package:flutter/material.dart';
import 'package:tripline/features/map/map_adapter.dart';

Widget fakeTripMapBuilder(TripMapCanvasConfig config) {
  return _FakeTripMapCanvas(config: config);
}

class _FakeTripMapCanvas extends StatefulWidget {
  const _FakeTripMapCanvas({required this.config});

  final TripMapCanvasConfig config;

  @override
  State<_FakeTripMapCanvas> createState() => _FakeTripMapCanvasState();
}

class _FakeTripMapCanvasState extends State<_FakeTripMapCanvas> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.config.onMapReady?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: const ValueKey('fake-trip-map-canvas'),
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Stack(
        children: [
          Text(
            widget.config.tilePreset.label,
            key: ValueKey('map-style-${widget.config.tilePreset.style.name}'),
          ),
          for (final route in widget.config.routes)
            Text(route.id, key: ValueKey('map-route-${route.id}')),
          for (final marker in widget.config.markers)
            Align(
              alignment: Alignment(
                (marker.point.longitude % 2) - 1,
                (marker.point.latitude % 2) - 1,
              ),
              child: GestureDetector(
                key: ValueKey(marker.id),
                onTap: marker.onTap,
                child: const SizedBox.square(dimension: 32),
              ),
            ),
        ],
      ),
    );
  }
}
