import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import 'map_adapter.dart';

class TripMapLayerMenu extends StatelessWidget {
  const TripMapLayerMenu({
    super.key,
    required this.keyPrefix,
    required this.selectedPreset,
    required this.onSelected,
  });

  final String keyPrefix;
  final TripMapTilePreset selectedPreset;
  final ValueChanged<TripMapTilePreset> onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surface,
      elevation: 2,
      shadowColor: colorScheme.shadow.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(TpRadius.sm),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: PopupMenuButton<TripMapTileStyle>(
        key: ValueKey('$keyPrefix-layer-menu'),
        tooltip: '地圖圖層',
        initialValue: selectedPreset.style,
        position: PopupMenuPosition.under,
        onSelected: (style) => onSelected(_presetForStyle(style)),
        itemBuilder: (context) => [
          for (final preset in kTripMapTilePresets)
            PopupMenuItem<TripMapTileStyle>(
              key: ValueKey('$keyPrefix-layer-${preset.style.name}'),
              value: preset.style,
              child: _LayerMenuItem(
                preset: preset,
                selected: preset.style == selectedPreset.style,
              ),
            ),
        ],
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: TpSpacing.tapMin),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: TpSpacing.s3,
              vertical: TpSpacing.s2,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.layers_outlined,
                  size: 18,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: TpSpacing.s2),
                Text(
                  selectedPreset.label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colorScheme.onSurface,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  TripMapTilePreset _presetForStyle(TripMapTileStyle style) {
    return kTripMapTilePresets.firstWhere((preset) => preset.style == style);
  }
}

class _LayerMenuItem extends StatelessWidget {
  const _LayerMenuItem({required this.preset, required this.selected});

  final TripMapTilePreset preset;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: TpSpacing.tapMin,
      child: Row(
        children: [
          Icon(_iconForStyle(preset.style), size: 20),
          const SizedBox(width: TpSpacing.s3),
          Expanded(child: Text(preset.label)),
          if (selected) Icon(Icons.check, size: 18, color: colorScheme.primary),
        ],
      ),
    );
  }

  IconData _iconForStyle(TripMapTileStyle style) {
    return switch (style) {
      TripMapTileStyle.roadmap => Icons.map,
      TripMapTileStyle.terrain => Icons.landscape,
      TripMapTileStyle.satellite => Icons.satellite,
    };
  }
}
