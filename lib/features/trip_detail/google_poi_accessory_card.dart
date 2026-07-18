import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../map/map_adapter.dart';

class GooglePoiAccessoryCard extends StatelessWidget {
  const GooglePoiAccessoryCard({
    super.key,
    required this.selection,
    required this.onClose,
    required this.onOpen,
  });

  final GoogleMapPoiSelection selection;
  final VoidCallback onClose;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = selection.name.trim().isEmpty
        ? 'Google 地圖地點'
        : selection.name.trim();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: TpSpacing.s2),
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Icon(
                  CupertinoIcons.location_solid,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: TpSpacing.s2),
                Expanded(
                  child: Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  key: const ValueKey('google-poi-close'),
                  constraints: const BoxConstraints.tightFor(
                    width: TpSpacing.tapMin,
                    height: TpSpacing.tapMin,
                  ),
                  tooltip: '關閉 Google 地圖地點',
                  onPressed: onClose,
                  icon: const Icon(CupertinoIcons.xmark),
                ),
              ],
            ),
          ),
          SizedBox(
            height: TpSpacing.tapMin,
            child: Align(
              alignment: Alignment.centerRight,
              child: Semantics(
                button: true,
                label: '在 Google 地圖開啟$name，將離開 Tripline',
                excludeSemantics: true,
                child: TextButton.icon(
                  key: const ValueKey('google-poi-open'),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(TpSpacing.tapMin, TpSpacing.tapMin),
                    foregroundColor: theme.colorScheme.primary,
                  ),
                  onPressed: onOpen,
                  icon: const Icon(CupertinoIcons.arrow_up_right, size: 18),
                  label: const Text('在 Google 地圖開啟'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
